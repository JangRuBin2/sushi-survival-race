--!strict
-- m4-02 Race 맵 아트: 장식 예산·코스 공간 침범 없음·소개 카메라 경로, 판정 치수 그대로,
-- 회전 벨트 태그 전환(M1 B10)이 폴더 순회와 같은 장애물을 찾는지, 이동 감시 면제 호출.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Layout = RobloxRequire.require(Shared.maps.SoySwampLayout)
local BeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)
local SwampArt = RobloxRequire.require(Shared.maps.SoySwampArt)
local Chopstick = RobloxRequire.require(Shared.maps.RotatingBeltChopstick)

local ARTS = {
	{ id = "rotating-belt", art = BeltArt },
	{ id = "soy-swamp", art = SwampArt },
}

local function stripComments(source: string): string
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(source, "%-%-[^\n]*", ""))
end

local function readSource(path: string): string
	return stripComments(fs.readFile(path))
end

-- 함수 본문 (local function name( ... 다음 최상위 local function 전까지)
local function functionBody(source: string, name: string): string
	local startAt = string.find(source, `local function {name}%(`)
	assert(startAt, `function {name} not found`)
	local nextAt = string.find(source, "\nlocal function ", startAt + 1)
		or string.find(source, "\nlocal [%w_]+: MapTypes", startAt + 1)
	return string.sub(source, startAt, (nextAt or #source + 1) - 1)
end

local function overlaps(a: MapKitLogic.Bounds, b: MapKitLogic.Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

---------------------------------------------------------------- 가짜 인스턴스 (태그 전환 테스트용)

local function newInstance(className: string, name: string, parent: any?): any
	local inst = { ClassName = className, Name = name, Parent = parent }
	function inst:IsA(class: string): boolean
		if class == "BasePart" then
			return self.ClassName == "Part"
		end
		return self.ClassName == class
	end
	function inst:IsDescendantOf(ancestor: any): boolean
		local node = self.Parent
		while node do
			if node == ancestor then
				return true
			end
			node = node.Parent
		end
		return false
	end
	return inst
end

local function newTags(): any
	local tagged: { [string]: { any } } = {}
	local tags = {}
	function tags:AddTag(inst: any, tag: string)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], inst)
	end
	function tags:GetTagged(tag: string): { any }
		return table.clone(tagged[tag] or {})
	end
	return tags
end

-- RotatingBelt.build와 같은 모양: Hazards/ChopstickStation(Zone 태그) × 2, Conveyors/ConveyorZone(태그) × 2
local function fakeBelt(tags: any, name: string): any
	local model = newInstance("Model", name, nil)
	local hazards = newInstance("Folder", "Hazards", model)
	local conveyors = newInstance("Folder", "Conveyors", model)
	local stations, zones = {}, {}
	for i = 1, 2 do
		local station = newInstance("Model", "ChopstickStation", hazards)
		local zone = newInstance("Part", "Zone", station)
		newInstance("Part", "Warning", station)
		tags:AddTag(zone, "Chopstick")
		table.insert(stations, station)
		local conveyor = newInstance("Part", `ConveyorZone{i}`, conveyors)
		tags:AddTag(conveyor, "Conveyor")
		table.insert(zones, conveyor)
	end
	return { model = model, hazards = hazards, conveyors = conveyors, stations = stations, zones = zones }
end

local function sameSet(t: Test.Test, actual: { any }, expected: { any }, label: string)
	t.eq(#actual, #expected, `{label}: count`)
	for _, item in expected do
		t.ok(table.find(actual, item) ~= nil, `{label}: missing {item.Name}`)
	end
end

return function(t: Test.Test)
	t.test("AC1: 두 맵 decor()가 MapKitLogic.validate를 통과하고 파츠 수 ≤ 600", function()
		for _, entry in ARTS do
			local specs = entry.art.decor()
			t.eq(MapKitLogic.validate(specs), nil, `{entry.id} decor valid`)
			local count = MapKitLogic.count(specs)
			t.ok(count > 0, `{entry.id} has decor`)
			t.ok(count <= MapKitLogic.DECOR_PART_BUDGET, `{entry.id} decor {count} parts over budget`)
		end
	end)

	t.test("AC2: 장식 외곽 상자가 코스 공간(바닥 위 2~12, 벽 안쪽)과 겹치지 않아요", function()
		for _, entry in ARTS do
			local volumes = entry.art.courseVolume()
			t.ok(#volumes > 0, `{entry.id} has course volume`)
			for _, volume in volumes do
				t.ok(volume.max.y - volume.min.y >= 10, `{entry.id} volume is at least 2~12 tall`)
			end
			for i, spec in entry.art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				for j, volume in volumes do
					t.ok(not overlaps(b, volume), `{entry.id} decor #{i} {spec.name} overlaps course volume #{j}`)
				end
			end
		end
	end)

	t.test("AC2: 코스 공간 상자가 실제 코스 폭·길이를 덮어요", function()
		-- 회전 벨트: 구간이 출발선(0)부터 끝 벽(-120)까지 빈틈없이 이어지고, 벽 안쪽 폭과 같아요
		local sections = BeltArt.SECTIONS
		t.eq(sections[1].front, 0)
		for i = 2, #sections do
			t.eq(sections[i].front, sections[i - 1].back, `belt section {i} continues`)
		end
		t.eq(sections[#sections].back, -120)
		t.eq(BeltArt.FINISH_LINE_Z, sections[#sections].back + 4)
		local belt = BeltArt.courseVolume()
		t.eq(#belt, #sections)
		-- 간장 늪: 출발 앞(0)부터 끝 벽까지 z를 덮고 폭은 코스 폭 전체
		local swamp = SwampArt.courseVolume()
		local minZ, maxZ = math.huge, -math.huge
		for _, volume in swamp do
			minZ = math.min(minZ, volume.min.z)
			maxZ = math.max(maxZ, volume.max.z)
			t.ok(volume.min.x >= -Layout.WIDTH / 2 and volume.max.x <= Layout.WIDTH / 2, "swamp volume inside walls")
		end
		t.eq(maxZ, Layout.START.front)
		t.eq(minZ, Layout.FINISH.back)
	end)

	t.test(
		"장식 공간: 와사비 공 장식은 패드 위 0.5 이하, 벨트 줄무늬는 바닥에 얇게",
		function()
			local padTop = Layout.PAD_THICKNESS
			local bumps = 0
			for _, spec in SwampArt.decor() do
				if spec.name == "WasabiBump" then
					bumps += 1
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					t.ok(b.max.y <= padTop + 0.5 + 1e-6, `bump top {b.max.y}`)
				end
			end
			t.ok(bumps > 0, "wasabi pad has bumps")
			local slats = 0
			for _, spec in BeltArt.decor() do
				if spec.name == "BeltSlat" then
					slats += 1
					t.ok(spec.size.y <= 0.05 + 1e-6, "slat is thin")
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					t.ok(b.min.y >= 0.05 - 1e-6 and b.max.y <= 0.2, `slat floats just above floor ({b.min.y})`)
				end
			end
			t.ok(slats > 0, "belt has slats")
		end
	)

	t.test("AC3: introCamera 경유점 3~5개, 마지막은 출발선 뒤(z > 0)·높이 8~20", function()
		for _, entry in ARTS do
			local points = entry.art.introCamera()
			t.ok(#points >= 3 and #points <= 5, `{entry.id} has {#points} points`)
			local last = points[#points]
			t.ok(last.pos.z > 0, `{entry.id} last point behind start line`)
			t.ok(last.pos.y >= 8 and last.pos.y <= 20, `{entry.id} last point height {last.pos.y}`)
			t.ok(last.lookAt.z < last.pos.z, `{entry.id} last point looks down the course`)
			for i, point in points do
				local dx, dy, dz =
					point.lookAt.x - point.pos.x, point.lookAt.y - point.pos.y, point.lookAt.z - point.pos.z
				t.ok(math.sqrt(dx * dx + dy * dy + dz * dz) > 1, `{entry.id} point {i} has a direction`)
			end
		end
	end)

	t.test("AC3: 소개 카메라 경유점은 장식 안에 묻히지 않아요", function()
		for _, entry in ARTS do
			for i, point in entry.art.introCamera() do
				for _, spec in entry.art.decor() do
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					local p = point.pos
					local inside = p.x > b.min.x
						and p.x < b.max.x
						and p.y > b.min.y
						and p.y < b.max.y
						and p.z > b.min.z
						and p.z < b.max.z
					t.ok(not inside, `{entry.id} camera point {i} inside {spec.name}`)
				end
			end
		end
	end)

	t.test("AC4: 판정 수치는 그대로 (간장 늪 Layout · 맵 인터페이스)", function()
		t.eq(Layout.WIDTH, 24)
		t.eq(Layout.WALL_HEIGHT, 48)
		t.eq(Layout.MOUNTAIN_HEIGHT, 12)
		t.eq(Layout.SLOPE_LOW, 12)
		t.eq(Layout.SLOPE_HIGH, 20)
		t.eq(Layout.totalLength(), 174)
		t.eq(Layout.finishLineZ(), -170)
		t.eq(Layout.BALL_DIAMETER, 5)
		t.eq(Layout.WASABI_UP, 80)
		t.eq(Layout.WASABI_FORWARD, 30)
		t.eq(Layout.SOY_SPEED_MULTIPLIER, 0.5)
		for _, entry in ARTS do
			local map = Maps.get(entry.id)
			t.eq(MapTypes.validate(map), nil, `{entry.id} still a valid map`)
			t.eq(map.kind, "Race")
		end
	end)

	t.test("AC4: 회전 벨트 코스 치수·장애물 타이밍 상수는 M3 그대로", function()
		local belt = fs.readFile("src/shared/maps/RotatingBelt.luau")
		for _, line in
			{
				"local WIDTH_NORMAL = 16",
				"local WIDTH_NARROW = 6",
				"local DEPTH_START = 14",
				"local DEPTH_BELT_A = 34",
				"local DEPTH_NARROW = 24",
				"local DEPTH_BELT_B = 34",
				"local DEPTH_FINISH = 14",
				"local WALL_HEIGHT = 6",
				"local PUSH_SPEED = 10",
				"local PUSH_ACCEL = 24",
				"local VOID_DROP = 40",
				"local FINISH_LINE_INSET = 4",
			}
		do
			t.ok(string.find(belt, line, 1, true) ~= nil, `RotatingBelt keeps {line}`)
		end
		local chop = fs.readFile("src/shared/maps/RotatingBeltChopstick.luau")
		for _, line in
			{
				"local WARN_DURATION = 1",
				"local GRAB_DURATION = 3",
				"local COOLDOWN_MIN = 2.5",
				"local COOLDOWN_MAX = 4.5",
				"local ZONE_WIDTH = 8",
				"local ZONE_DEPTH = 10",
				"local REST_HEIGHT = 10",
				"local DEPLOY_HEIGHT = 1.5",
			}
		do
			t.ok(string.find(chop, line, 1, true) ~= nil, `Chopstick keeps {line}`)
		end
		-- 아트 모듈이 옮겨 적은 구간 폭이 RotatingBelt 상수와 같아요
		t.eq(BeltArt.SECTIONS[2].half * 2, 16)
		t.eq(BeltArt.SECTIONS[3].half * 2, 6)
		t.eq(BeltArt.SECTIONS[1].half * 2, 16 + 4)
		t.eq(BeltArt.WALL_HEIGHT, 6)
	end)

	t.test(
		"스폰: 두 맵 모두 24개가 출발 바닥 위, 가장자리·뒤 벽에서 1 stud 이상 여유, 겹치지 않음",
		function()
			local MAX = 24
			local cases = {
				{
					id = "rotating-belt",
					positions = BeltArt.spawnPositions(),
					half = BeltArt.SPAWN_SIZE / 2,
					minX = -BeltArt.SECTIONS[1].half,
					maxX = BeltArt.SECTIONS[1].half,
					front = BeltArt.SECTIONS[1].front, -- 출발 바닥 뒤 끝 (뒤는 허공)
					back = BeltArt.SECTIONS[1].back,
				},
				{
					id = "soy-swamp",
					positions = Layout.spawnPositions(),
					half = 1.5,
					minX = -Layout.WIDTH / 2,
					maxX = Layout.WIDTH / 2,
					front = Layout.START.front, -- StartWall 안쪽 면
					back = Layout.START.back, -- 간장 늪 시작
				},
			}
			for _, c in cases do
				t.eq(#c.positions, MAX, `{c.id} spawn count`)
				local seen = {}
				for i, pos in c.positions do
					t.ok(pos.x - c.half >= c.minX + 1 and pos.x + c.half <= c.maxX - 1, `{c.id} spawn {i} x {pos.x}`)
					t.ok(pos.z + c.half <= c.front - 1 and pos.z - c.half >= c.back + 1, `{c.id} spawn {i} z {pos.z}`)
					local key = `{pos.x},{pos.z}`
					t.ok(not seen[key], `{c.id} duplicate spawn {key}`)
					seen[key] = true
				end
			end
			-- 회전 벨트 build가 이 위치표를 써요 (옛 row * 4 식이 남아 있지 않게)
			local source = readSource("src/shared/maps/RotatingBelt.luau")
			t.ok(
				string.find(functionBody(source, "build"), "Art.spawnPositions()", 1, true) ~= nil,
				"build uses spawnPositions"
			)
			t.ok(string.find(source, "row * 4", 1, true) == nil, "old spawn formula removed")
		end
	)

	t.test("AC5: RotatingBelt.start는 Hazards 폴더가 아니라 CollectionService 태그로 찾아요", function()
		local source = readSource("src/shared/maps/RotatingBelt.luau")
		local startBody = functionBody(source, "start")
		t.ok(string.find(startBody, '"Hazards"', 1, true) == nil, "start must not look up the Hazards folder")
		t.ok(string.find(startBody, '"Conveyors"', 1, true) == nil, "start must not look up the Conveyors folder")
		t.ok(string.find(startBody, "Chopstick.stationsIn(model)", 1, true) ~= nil, "start finds stations by tag")
		t.ok(
			string.find(startBody, "Chopstick.taggedIn(model, CONVEYOR_TAG)", 1, true) ~= nil,
			"start finds conveyors by tag"
		)
		t.ok(
			string.find(source, "CollectionService:AddTag(zone, CONVEYOR_TAG)", 1, true) ~= nil,
			"build tags conveyor zones"
		)
		local chop = readSource("src/shared/maps/RotatingBeltChopstick.luau")
		t.ok(string.find(chop, 'GetService("CollectionService")', 1, true) ~= nil, "Chopstick uses CollectionService")
		t.ok(string.find(chop, ":GetTagged(tag)", 1, true) ~= nil, "taggedIn uses GetTagged")
		t.ok(string.find(chop, ":IsDescendantOf(container)", 1, true) ~= nil, "taggedIn filters by ctx.model")
		t.ok(string.find(chop, "CollectionService:AddTag(zone, TAG)", 1, true) ~= nil, "station zone keeps the tag")
		t.eq(Chopstick.TAG, "Chopstick")
	end)

	t.test(
		"태그 전환: 폴더 순회와 같은 젓가락·벨트 구역을 찾고 다른 방 맵은 빼요 (M1 B10)",
		function()
			local tags = newTags()
			local roomA = fakeBelt(tags, "rotating-belt")
			local roomB = fakeBelt(tags, "rotating-belt")

			-- 옛 방식(폴더 순회)이 찾던 것과 같아요
			sameSet(t, Chopstick.stationsIn(roomA.model, tags), roomA.stations, "room A stations")
			sameSet(t, Chopstick.taggedIn(roomA.model, "Conveyor", tags), roomA.zones, "room A conveyors")
			sameSet(t, Chopstick.stationsIn(roomB.model, tags), roomB.stations, "room B stations")

			-- 폴더 구조와 상관없어요: station을 Hazards 밖으로 옮겨도 찾아요
			roomA.stations[1].Parent = roomA.model
			sameSet(t, Chopstick.stationsIn(roomA.model, tags), roomA.stations, "moved station")
			-- 맵에서 빠진 station은 안 찾아요
			roomA.stations[2].Parent = nil
			sameSet(t, Chopstick.stationsIn(roomA.model, tags), { roomA.stations[1] }, "removed station")
			-- 다른 방은 영향 없음
			sameSet(t, Chopstick.stationsIn(roomB.model, tags), roomB.stations, "room B unaffected")
		end
	)

	t.test("태그 전환: 같은 station의 Zone이 두 번 태그돼도 한 번만 돌려요", function()
		local tags = newTags()
		local room = fakeBelt(tags, "rotating-belt")
		local extraZone = newInstance("Part", "Zone2", room.stations[1])
		tags:AddTag(extraZone, "Chopstick")
		sameSet(t, Chopstick.stationsIn(room.model, tags), room.stations, "dedup")
	end)

	t.test(
		"MoveExempt: 젓가락·간장·와사비·날치알에서 이동 감시 면제를 달고, 벨트 밀기에는 달지 않아요",
		function()
			-- 설계 변경 (m4-10 QA B1, 2026-10-08): 벨트 밀기(최고 10)는 표시 없이도 감시 기준 안이고,
			-- 반복 면제를 달면 벨트 위 속도 조작이 안 잡혀서 뺐어요. 기준 안인지는 m4-02-qa·m4-10-qa가 고정해요.
			local belt = readSource("src/shared/maps/RotatingBelt.luau")
			t.eq(string.find(functionBody(belt, "start"), "MoveExempt.mark(", 1, true), nil, "no conveyor exempt")
			local chop = readSource("src/shared/maps/RotatingBeltChopstick.luau")
			t.ok(
				string.find(functionBody(chop, "grab"), "MoveExempt.mark(character, GRAB_DURATION + 1)", 1, true) ~= nil,
				"grab"
			)
			t.ok(string.find(functionBody(chop, "release"), "MoveExempt.mark(character)", 1, true) ~= nil, "release")
			local hazards = readSource("src/shared/maps/SoySwampHazards.luau")
			local _, soyMarks = string.gsub(hazards, "MoveExempt%.mark%(player%.Character%)", "")
			t.ok(soyMarks >= 2, "soy slow on/off")
			t.ok(string.find(hazards, "MoveExempt.mark(character, WASABI_EXEMPT)", 1, true) ~= nil, "wasabi launch")
			t.ok(
				string.find(
					functionBody(hazards, "knockDown"),
					"MoveExempt.mark(player.Character, Layout.KNOCKDOWN_DURATION + 1)",
					1,
					true
				) ~= nil,
				"tobiko knockdown"
			)
		end
	)

	t.test(
		"build: 장식·소개 카메라·Studio 아트 자리를 붙이고 재질을 바꿔도 물리는 M3 그대로",
		function()
			for _, path in { "src/shared/maps/RotatingBelt.luau", "src/shared/maps/SoySwamp.luau" } do
				local source = readSource(path)
				local body = functionBody(source, "build")
				t.ok(
					string.find(body, "MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))", 1, true)
						~= nil,
					`{path} decor`
				)
				t.ok(
					string.find(body, "MapKit.introCamera(model, Art.introCamera(), origin)", 1, true) ~= nil,
					`{path} intro camera`
				)
				t.ok(
					string.find(body, "MapKit.attachStudioArt(model, ID, origin)", 1, true) ~= nil,
					`{path} studio art`
				)
				t.ok(string.find(body, "CustomPhysicalProperties", 1, true) ~= nil, `{path} keeps physics`)
			end
			local hazards = readSource("src/shared/maps/SoySwampHazards.luau")
			t.ok(
				string.find(
					hazards,
					"ball.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic)",
					1,
					true
				) ~= nil,
				"tobiko ball rolls like M3"
			)
		end
	)

	t.test("색: 바닥은 와사비 패드·경고 빨강과 헷갈리지 않게 채도가 낮아요", function()
		local function saturation(c: MapKitLogic.RGB): number
			local maxC = math.max(c.r, c.g, c.b)
			local minC = math.min(c.r, c.g, c.b)
			return if maxC == 0 then 0 else (maxC - minC) / maxC
		end
		local pad = SwampArt.COLORS.wasabi
		for _, key in { "floor", "swamp", "mountain", "slope" } do
			t.ok(saturation(SwampArt.COLORS[key]) < saturation(pad), `soy-swamp {key} less saturated than wasabi pad`)
		end
		for _, key in { "woodFloor", "belt", "narrowFloor" } do
			t.ok(saturation(BeltArt.COLORS[key]) < 0.6, `rotating-belt {key} not vivid`)
		end
	end)
end
