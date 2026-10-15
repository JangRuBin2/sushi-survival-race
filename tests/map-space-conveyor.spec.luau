--!strict
-- m5-35 "우주 회전초밥"(space-conveyor): 코스 치수 약속, 방향 전환 레일, 저중력, 운석·바위 순수 계산, 장식 예산,
-- build 결과(진짜 인스턴스, 렌더러 Shims), start를 가짜 Heartbeat로 돌려 레일 속도·화살표·저중력 정리 확인.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.SpaceConveyorLayout)
local Logic = RobloxRequire.require(Shared.maps.SpaceConveyorLogic)
local Art = RobloxRequire.require(Shared.maps.SpaceConveyorArt)
local SpaceConveyor = RobloxRequire.require(Shared.maps.SpaceConveyor)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local EPS = 1e-6

type Bounds = MapKitLogic.Bounds

local function seededRng(seed: number): any
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self: any, min: number?, max: number?): number
			local lo, hi = min or 0, max or 1
			return lo + step() * (hi - lo)
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1))
		end,
	}
end

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

local function railsOf(group: string): { any }
	local out = {}
	for _, rail in Layout.rails() do
		if rail.group == group then
			table.insert(out, rail)
		end
	end
	return out
end

-- 레일 위 가운데쯤 레이서 위치 (루트 = 윗면 + 3)
local function riderOn(rail: any, along: number, lateral: number): any
	local p = Logic.railPoint(rail, along, lateral)
	return { x = p.x, y = p.y + 3, z = p.z }
end

local function builtModel(): any
	local map = RMaps.get("space-conveyor")
	return map.build(RCF.new())
end

---------------------------------------------------------------- start() 가짜 환경
-- SpaceConveyor.luau 소스를 가짜 game·task·Instance·os.clock으로 불러 start만 돌려요.

type Fake = { [string]: any }

local function fakeInstance(className: string): Fake
	local inst: Fake = { ClassName = className, Name = className, destroyed = false, attrs = {} }
	function inst:Destroy()
		self.destroyed = true
		self.Parent = nil
	end
	function inst:IsA(cls: string): boolean
		return self.ClassName == cls
			or (cls == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart"))
	end
	function inst:GetAttribute(name: string): any
		return self.attrs[name]
	end
	function inst:FindFirstChild(name: string): any
		return (self.children or {})[name]
	end
	function inst:FindFirstChildOfClass(cls: string): any
		for _, child in self.children or {} do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end
	return inst
end

type StartHarness = {
	now: number,
	fire: () -> (),
	created: { Fake },
	sfx: { string },
	railParts: { [number]: Fake },
	arrows: { Fake },
	ctx: any,
	racers: { any },
	passCheck: ((player: any) -> ())?,
}

local function startHarness(): StartHarness
	local h: StartHarness = {
		now = 0,
		fire = function() end,
		created = {},
		sfx = {},
		railParts = {},
		arrows = {},
		ctx = nil,
		racers = {},
		passCheck = nil,
	}
	local handlers = {}
	local heartbeat = {
		Connect = function(_self: any, fn: any)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
	}
	h.fire = function()
		for _, fn in handlers do
			fn(1 / 60)
		end
	end
	local origin = RCF.new(0, 300, 4000)
	-- 태그 파츠 (레일·화살표·저중력 구역)
	local tagged: { [string]: { Fake } } = { SpaceRail = {}, SpaceRailArrow = {}, SpaceGravityZone = {} }
	for _, rail in Layout.rails() do
		local a = origin:PointToWorldSpace(RV3.new(rail.x0, rail.y0, rail.z0))
		local b = origin:PointToWorldSpace(RV3.new(rail.x1, rail.y1, rail.z1))
		local part = fakeInstance("Part")
		part.CFrame = Shims.lookAt((a + b) / 2, b, RV3.new(0, 1, 0))
		part.AssemblyLinearVelocity = RV3.zero
		part.attrs.RailIndex = rail.index
		h.railParts[rail.index] = part
		table.insert(tagged.SpaceRail, part)
		for _, side in { -1, 1 } do
			local wedge = fakeInstance("WedgePart")
			wedge.CFrame = part.CFrame * RCF.new(side * 2, 1, 0) * RCF.Angles(0, 0, -side * math.pi / 2)
			wedge.attrs.RailIndex = rail.index
			wedge.attrs.ArrowSide = side
			wedge.Color = nil
			table.insert(tagged.SpaceRailArrow, wedge)
			table.insert(h.arrows, wedge)
		end
	end
	local g = Layout.GRAVITY_ZONE
	local zone = fakeInstance("Part")
	zone.CFrame = origin * RCF.new((g.minX + g.maxX) / 2, (g.minY + g.maxY) / 2, (g.minZ + g.maxZ) / 2)
	zone.Size = RV3.new(g.maxX - g.minX, g.maxY - g.minY, g.maxZ - g.minZ)
	table.insert(tagged.SpaceGravityZone, zone)

	local services = {
		RunService = { Heartbeat = heartbeat },
		TweenService = {},
		CollectionService = {
			GetTagged = function(_self: any, tag: string)
				return tagged[tag] or {}
			end,
		},
	}
	local fakeTask = {
		spawn = function(_fn: any, ...: any): any
			return { __thread = true } -- 운석 시간표는 돌리지 않아요 (레일·저중력만 봐요)
		end,
		delay = function(): any
			return { __thread = true }
		end,
		wait = function(): number
			return 0
		end,
	}
	local stubParent = {
		SpaceConveyorArt = "Art",
		SpaceConveyorLayout = "Layout",
		SpaceConveyorLogic = "Logic",
		MapKit = "MapKit",
		MapSfx = "MapSfx",
		MapTypes = "MapTypes",
		Parent = { Config = "Config", MoveExempt = "MoveExempt" },
	}
	local modules = {
		Art = Art,
		Layout = Layout,
		Logic = Logic,
		Config = Config,
		MapTypes = MapTypes,
		MoveExempt = { mark = function() end },
		MapSfx = {
			play = function(_part: any, cue: string)
				table.insert(h.sfx, cue)
			end,
		},
		MapKit = {
			makeEmitter = function()
				return fakeInstance("ParticleEmitter")
			end,
		},
	}
	local env = {
		script = { Parent = stubParent },
		require = function(name: any): any
			return modules[name]
		end,
		game = {
			GetService = function(_self: any, name: string)
				return services[name]
			end,
		},
		workspace = { Gravity = 196.2 },
		task = fakeTask,
		os = {
			clock = function(): number
				return h.now
			end,
		},
		Instance = {
			new = function(className: string): any
				local inst = fakeInstance(className)
				table.insert(h.created, inst)
				return inst
			end,
		},
		CFrame = RCF,
		Vector3 = RV3,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		PhysicalProperties = roblox.PhysicalProperties,
		TweenInfo = { new = function() end },
	}
	local source = fs.readFile("src/shared/maps/SpaceConveyor.luau")
	local map = luau.load(source, { debugName = "SpaceConveyor", environment = env })()

	local model = fakeInstance("Model")
	function model:IsAncestorOf(_inst: any): boolean
		return true
	end
	model.children = {}
	local ctx: any = {
		model = model,
		origin = origin,
		rng = seededRng(1),
		cleanup = { items = {} },
		active = true,
		passed = {},
		eliminated = {},
	}
	function ctx.cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		local list = {}
		for _, r in h.racers do
			table.insert(list, r)
		end
		return list
	end
	ctx.pass = function(player: any)
		if h.passCheck then
			(h.passCheck :: any)(player)
		end
		table.insert(ctx.passed, player.Name)
		local i = table.find(h.racers, player)
		if i then
			table.remove(h.racers, i)
		end
	end
	ctx.eliminate = function(player: any)
		if h.passCheck then
			(h.passCheck :: any)(player)
		end
		table.insert(ctx.eliminated, player.Name)
		local i = table.find(h.racers, player)
		if i then
			table.remove(h.racers, i)
		end
	end
	h.ctx = ctx
	map.start(ctx)
	return h
end

local function fakeRacer(h: StartHarness, name: string, x: number, y: number, z: number): any
	local root = fakeInstance("Part")
	root.AssemblyMass = 10
	local attachment = fakeInstance("Attachment")
	root.children = { RootAttachment = attachment }
	local humanoid = fakeInstance("Humanoid")
	local character = fakeInstance("Model")
	character.children = { HumanoidRootPart = root, Humanoid = humanoid }
	local player = { Name = name, Character = character, root = root }
	local function place(px: number, py: number, pz: number)
		root.Position = h.ctx.origin:PointToWorldSpace(RV3.new(px, py, pz))
	end
	place(x, y, z);
	(player :: any).place = place
	table.insert(h.racers, player)
	return player
end

-- 지금 살아 있는(Destroy 안 된) 저중력 힘 중 그 루트에 붙은 것
local function gravityOn(h: StartHarness, root: any): any
	for _, inst in h.created do
		if inst.ClassName == "VectorForce" and not inst.destroyed and inst.Parent == root then
			return inst
		end
	end
	return nil
end

local function liveForces(h: StartHarness): number
	local n = 0
	for _, inst in h.created do
		if inst.ClassName == "VectorForce" and not inst.destroyed then
			n += 1
		end
	end
	return n
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: validate 통과 Race, 이름·규칙 GDD 그대로, 풀에 있음, 맵 조명 = Art.LIGHTING",
		function()
			t.eq(MapTypes.validate(SpaceConveyor), nil)
			t.eq(Maps.get("space-conveyor"), SpaceConveyor)
			t.eq(SpaceConveyor.kind, "Race")
			t.eq(SpaceConveyor.displayName, "우주 회전초밥")
			t.eq(
				SpaceConveyor.rule,
				"방향이 바뀌는 우주 레일을 타고, 떨어지는 운석을 피해 결승까지!"
			)
			t.ok(SpaceConveyor.inPool == nil or SpaceConveyor.inPool == true, "inPool line removed")
			t.eq(SpaceConveyor.lighting, Art.LIGHTING)
			t.eq(SpaceConveyor.timeLimit, nil)
			t.eq(Maps.timeLimit(SpaceConveyor), Config.TimeLimit.Race)
			local pooled = false
			for _, info in Maps.infos() do
				if info.id == "space-conveyor" then
					pooled = true
				end
			end
			t.ok(pooled, "in the random pool")
		end
	)

	t.test("AC1: 스폰 24개가 A 발사대 위(가장자리 1 안쪽), 서로 3 이상", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, 24)
		local a = Layout.section("A")
		for i, p in spawns do
			t.ok(math.abs(p.x) + 1 <= Layout.START_WIDTH / 2, `spawn {i} x {p.x}`)
			t.ok(p.z <= a.front - 1 and p.z >= a.back + 1, `spawn {i} z {p.z}`)
			for j = i + 1, #spawns do
				local q = spawns[j]
				t.ok(math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) >= 3 - EPS, `spawns {i},{j}`)
			end
		end
	end)

	t.test(
		"AC1: build — 스폰 24개가 발사대 바로 위, FinishLine z −462 · y 10, 태그 파츠가 다 있어요",
		function()
			local model = builtModel()
			local spawns = model:FindFirstChild("Spawns")
			t.eq(#spawns:GetChildren(), 24)
			local pad = model:FindFirstChild("LaunchPad")
			for _, s in spawns:GetChildren() do
				local rel = pad.CFrame:PointToObjectSpace(s.CFrame.Position)
				t.ok(math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2, `{s.Name} over pad`)
				t.ok(math.abs(rel.Y - pad.Size.Y / 2 - 0.1) < 1e-3, `{s.Name} on pad top`)
			end
			local finish = model:FindFirstChild("FinishLine")
			t.ok(math.abs(finish.CFrame.Position.Z - Layout.FINISH_LINE_Z) < 1e-3, "finish z")
			t.ok(math.abs(finish.CFrame.Position.Y - (Layout.TOP_Y + 0.2)) < 1e-3, "finish y")
			t.eq(finish.CanCollide, false)
			local counts: { [string]: number } = {}
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					counts[tag] = (counts[tag] or 0) + 1
				end
			end
			t.eq(counts.SpaceRail, #Layout.rails())
			t.eq(counts.SpaceRailHub, #Layout.hubs())
			t.eq(counts.SpaceGravityZone, 1)
			t.ok((counts.SpaceRailArrow or 0) >= 4 * #Layout.rails(), "arrows on every rail")
			-- 화살표: Neon, 충돌·쿼리·터치 없음, 장식 폴더 밖(서버가 색을 바꿔요)
			for _, d in model:GetDescendants() do
				if d:HasTag("SpaceRailArrow") then
					t.eq(d.Material, roblox.Enum.Material.Neon)
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, "arrow no collide")
					t.ok(d.Parent.Name ~= "Decor", "arrow outside Decor")
				end
			end
		end
	)

	t.test(
		"AC1: build — 레일 조각 윗면이 Layout 끝점과 같고, 앞 방향이 다음 원판 쪽이에요",
		function()
			local model = builtModel()
			local rails = model:FindFirstChild("Rails")
			for _, rail in Layout.rails() do
				local part = rails:FindFirstChild(string.format("Rail%02d", rail.index))
				t.ok(part ~= nil, `rail {rail.index}`)
				local half = part.Size.Z / 2
				local back = part.CFrame:PointToWorldSpace(RV3.new(0, part.Size.Y / 2, half))
				local front = part.CFrame:PointToWorldSpace(RV3.new(0, part.Size.Y / 2, -half))
				t.ok((back - RV3.new(rail.x0, rail.y0, rail.z0)).Magnitude < 1e-3, `rail {rail.index} back end`)
				t.ok((front - RV3.new(rail.x1, rail.y1, rail.z1)).Magnitude < 1e-3, `rail {rail.index} front end`)
				t.eq(part.Size.X, rail.width)
				t.ok(part.CFrame.UpVector.Y > 0.99, `rail {rail.index} faces up`)
			end
		end
	)

	---------------------------------------------------------------- AC2
	t.test("AC2: 출발부터 따라가면 z가 줄기만 해요 (두 갈래 모두, 레일 조각마다)", function()
		for _, branch in { "L", "R" } do
			local points = Layout.path(branch)
			for i = 2, #points do
				t.ok(points[i].z < points[i - 1].z, `{branch} point {i} goes back ({points[i].z} >= {points[i - 1].z})`)
			end
		end
		for _, rail in Layout.rails() do
			t.ok(rail.z1 < rail.z0, `rail {rail.index} goes forward`)
		end
	end)

	t.test("AC2: 구간 7개가 표 z 범위·바닥과 같고 이어져요, FinishLine z −462", function()
		local expected = {
			{ "A", 0, -16, 0 },
			{ "B", -16, -100, 0 },
			{ "C", -100, -170, -2 },
			{ "D", -170, -270, 0 },
			{ "E", -270, -350, 10 },
			{ "F", -350, -440, 10 },
			{ "G", -440, -470, 10 },
		}
		t.eq(#Layout.SECTIONS, 7)
		for i, row in expected do
			local s = Layout.SECTIONS[i]
			t.eq(s.id, row[1])
			t.eq(s.front, row[2])
			t.eq(s.back, row[3])
			t.eq(s.floor, row[4])
			if i > 1 then
				t.eq(s.front, Layout.SECTIONS[i - 1].back)
			end
		end
		t.eq(Layout.FINISH_LINE_Z, -462)
		t.eq(Layout.totalLength(), 470)
		-- 이음매 원판이 구간 경계를 잇고(B 끝 → C, D 처음·끝), F·G 폭이 맞아요
		local hubs = Layout.hubs()
		t.eq(hubs[#Layout.B_HUBS].z - Layout.HUB_RADIUS, -100)
		t.eq(hubs[#Layout.B_HUBS + 1].z + Layout.HUB_RADIUS, -170)
		t.ok(math.abs(hubs[#hubs].z - Layout.HUB_RADIUS - -270) < 1e-9, "last D hub reaches E")
		t.eq(hubs[#hubs].y, 10)
	end)

	t.test("AC2: fallLineAt = 구간 바닥 − 25 (C −27, D는 0 → 10 보간), 진행도는 −z", function()
		t.eq(Logic.fallLineAt(-8), -25)
		t.eq(Logic.fallLineAt(-50), -25)
		t.eq(Logic.fallLineAt(-130), -27)
		t.eq(Logic.fallLineAt(-172), -25)
		t.ok(math.abs(Logic.fallLineAt(-263) - -15) < 1e-9, "D top")
		t.ok(Logic.fallLineAt(-220) > -25 and Logic.fallLineAt(-220) < -15, "D middle")
		t.eq(Logic.fallLineAt(-300), -15)
		t.eq(Logic.fallLineAt(-400), -15)
		t.eq(Logic.fallLineAt(-465), -15)
		t.eq(Logic.fallLineAt(-480), -15)
		t.eq(Logic.fallLineAt(5), -25)
		t.eq(Logic.finishProgress(), 462)
		-- 밟는 곳(소행성·원판 윗면)은 늘 낙하선보다 높아요
		for _, a in Layout.ASTEROIDS do
			t.ok(a.top - 3 > Logic.fallLineAt(a.z), `{a.name} above fall line`)
		end
		for _, hub in Layout.hubs() do
			t.ok(hub.y - 3 > Logic.fallLineAt(hub.z), "hub above fall line")
		end
	end)

	t.test("AC2: estimateClearTime 42~55초 (Layout 상수 기반)", function()
		local estimate = Logic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
		t.ok(Layout.pathLength("L") >= 440, `path {Layout.pathLength("L")}`)
	end)

	---------------------------------------------------------------- AC3
	t.test(
		"AC3: B·D 레일 조각 끝 모서리가 이음매 원판 안 (틈 없음), 수평 회전 ≤ 30°, D 경사 ≤ 6°",
		function()
			local hubs = Layout.hubs()
			local function insideSomeHub(x: number, z: number): boolean
				for _, hub in hubs do
					if (x - hub.x) ^ 2 + (z - hub.z) ^ 2 <= hub.radius * hub.radius + 1e-6 then
						return true
					end
				end
				return false
			end
			local b, d = railsOf("B"), railsOf("D")
			t.eq(#b, 5)
			t.eq(#d, 6)
			for _, rail in Layout.rails() do
				local geo = Layout.railGeometry(rail)
				t.ok(math.abs(geo.yawDeg) <= Layout.MAX_RAIL_YAW + EPS, `rail {rail.index} yaw {geo.yawDeg}`)
				if rail.group == "B" or rail.group == "D" then
					for _, along in { -geo.horizontal / 2, geo.horizontal / 2 } do
						for _, lateral in { -rail.width / 2, rail.width / 2 } do
							local p = Logic.railPoint(rail, along, lateral)
							t.ok(insideSomeHub(p.x, p.z), `rail {rail.index} corner ({p.x},{p.z}) outside hubs`)
						end
					end
				end
				if rail.group == "D" then
					t.ok(geo.slopeDeg <= Layout.MAX_RAIL_SLOPE + EPS, `D rail {rail.index} slope {geo.slopeDeg}`)
					t.ok(geo.slopeDeg > 0, "D goes up")
					t.eq(rail.width, 12)
				elseif rail.group == "B" then
					t.eq(rail.width, 14)
					t.ok(geo.horizontal >= 15 and geo.horizontal <= 21, `B rail length {geo.horizontal}`)
					t.eq(rail.y0, 0)
				end
			end
			-- 좌우 번갈아 (S자)
			for i = 2, #b do
				local prev, cur = Layout.railGeometry(b[i - 1]).yawDeg, Layout.railGeometry(b[i]).yawDeg
				t.ok(prev * cur < 0, `B rails {i - 1},{i} alternate`)
			end
			t.ok(math.abs(d[#d].y1 - 10) < EPS and d[1].y0 == 0, "D climbs 0 → 10")
		end
	)

	t.test("AC3: F 두 줄은 폭 9, 사이 빈틈 6, E 끝 → G 처음까지", function()
		local fl, fr = railsOf("FL")[1], railsOf("FR")[1]
		t.eq(fl.width, 9)
		t.eq(fr.width, 9)
		t.ok(math.abs((fr.x0 - fl.x0) - fl.width - 6) < EPS, "gap 6")
		t.eq(fl.z0, -350)
		t.eq(fl.z1, -440)
		t.ok(math.abs(fr.x0) + fr.width / 2 <= Layout.FINISH_WIDTH / 2, "lanes land on G pad")
		t.ok(math.abs(fr.x0) + fr.width / 2 <= Layout.FIELD_WIDTH / 2, "lanes start on E field")
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: railPhase 표 그대로, offset 3은 반대, 한 주기 평균 밀기 > 0", function()
		local function check(time: number, offset: number, state: string, push: number)
			local s, p = Logic.railPhase(time, offset)
			t.eq(s, state, `t {time} offset {offset}`)
			t.eq(p, push, `t {time} offset {offset} push`)
		end
		check(0, 0, "Forward", 9)
		check(2.59, 0, "Forward", 9)
		check(2.6, 0, "WarnBack", 0)
		check(2.7, 0, "WarnBack", 0)
		check(3.0, 0, "Back", -7)
		check(5.59, 0, "Back", -7)
		check(5.7, 0, "WarnForward", 0)
		check(6.0, 0, "Forward", 9)
		check(0, 3, "Back", -7)
		check(3, 3, "Forward", 9)
		check(60.1, 0, "Forward", 9)
		t.ok(Logic.averagePush() > 0, "average push forward")
		-- 수치 적분으로도 확인
		local sum = 0
		for i = 0, 5999 do
			local _, p = Logic.railPhase(i / 1000, 0)
			sum += p / 1000
		end
		t.ok(sum / 6 > 0, `integrated average {sum / 6}`)
		t.ok(math.abs(sum / 6 - Logic.averagePush()) < 0.02, "average matches")
	end)

	t.test("AC4: Warn 동안만 0.1초 간격 깜빡임", function()
		t.eq(Logic.blinkOn(1.0, 0), false)
		t.eq(Logic.blinkOn(4.0, 0), false)
		t.eq(Logic.blinkOn(2.62, 0), true)
		t.eq(Logic.blinkOn(2.72, 0), false)
		t.eq(Logic.blinkOn(2.82, 0), true)
		t.eq(Logic.blinkOn(5.65, 0), true)
		t.eq(Logic.blinkOn(5.75, 0), false)
	end)

	---------------------------------------------------------------- AC5
	t.test(
		"AC5: 보통 중력(틈 ≤ 8, 오름 ≤ 6)으로는 C를 못 건너고, 저중력(≤ 15, ≤ 11)이면 두 갈래 모두",
		function()
			t.eq(Logic.crossable(8, 6), false)
			t.eq(Logic.crossable(8, 6, "L"), false)
			t.eq(Logic.crossable(8, 6, "R"), false)
			t.eq(Logic.crossable(15, 11, "L"), true)
			t.eq(Logic.crossable(15, 11, "R"), true)
		end
	)

	t.test(
		"AC5: 소행성 8개(지름 9~13, 윗면 −2~+4), 갈래 안 틈 6~11, 갈래마다 틈 ≥ 9 하나 이상",
		function()
			t.eq(#Layout.ASTEROIDS, 8)
			local hubs = Layout.hubs()
			local entry, exit = hubs[#Layout.B_HUBS], hubs[#Layout.B_HUBS + 1]
			for _, branch in { "L", "R" } do
				local chain: { any } = { entry }
				for _, a in Layout.ASTEROIDS do
					t.ok(a.radius * 2 >= 9 and a.radius * 2 <= 13, `{a.name} diameter`)
					t.ok(a.top >= -2 and a.top <= 4, `{a.name} top`)
					t.ok(a.z <= -100 and a.z >= -170, `{a.name} inside C`)
					t.ok(Logic.inGravityZone(a.x, a.top + 3, a.z), `{a.name} in low gravity zone`)
					if a.branch == branch then
						table.insert(chain, a)
					end
				end
				table.insert(chain, exit)
				t.eq(#chain, 6)
				local wide = 0
				for i = 2, #chain do
					local gap = Logic.edgeGap(chain[i - 1], chain[i])
					t.ok(gap >= 6 - EPS and gap <= 11 + EPS, `{branch} gap {i - 1} = {gap}`)
					if gap >= 9 then
						wide += 1
					end
				end
				t.ok(wide >= 1, `{branch} has a wide gap`)
			end
			-- 저중력 구역이 C 전체(입구·출구 원판 가장자리 포함)를 덮어요
			local g = Layout.GRAVITY_ZONE
			t.eq({ g.minX, g.maxX, g.minY, g.maxY, g.minZ, g.maxZ }, { -32, 32, -30, 45, -172, -98 })
		end
	)

	---------------------------------------------------------------- AC6
	t.test("AC6: lowGravityForce·점프 높이·체공", function()
		t.ok(math.abs(Logic.lowGravityForce(10, 196.2, 0.5) - 981) <= 981 * 0.001, "981")
		t.eq(Logic.LOW_GRAVITY, 0.5)
		local height = Logic.jumpHeight(Logic.JUMP_POWER, Logic.GRAVITY, Logic.LOW_GRAVITY)
		local air = Logic.airTime(Logic.JUMP_POWER, Logic.GRAVITY, Logic.LOW_GRAVITY)
		t.ok(height >= 12 and height <= 13.5, `height {height}`)
		t.ok(air >= 0.95 and air <= 1.1, `air {air}`)
		local normal = Logic.jumpHeight(Logic.JUMP_POWER, Logic.GRAVITY, 1)
		t.ok(math.abs(normal - 6.37) < 0.01, `normal {normal}`)
		t.ok(Logic.inGravityZone(0, 0, -130) and not Logic.inGravityZone(0, 0, -60), "zone")
		t.ok(not Logic.inGravityZone(0, 0, -180), "zone ends before D")
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: meteorWave · fieldMeteorWave 시간표", function()
		t.eq(Logic.meteorWave(5.9), nil)
		t.eq(Logic.meteorWave(6), { count = 3, interval = 10 })
		t.eq(Logic.meteorWave(36), { count = 3, interval = 10 })
		t.eq(Logic.meteorWave(46), { count = 4, interval = 10 })
		t.eq(Logic.fieldMeteorWave(9.9), nil)
		t.eq(Logic.fieldMeteorWave(10), { count = 2, interval = 5 })
		t.eq(Logic.fieldMeteorWave(40), { count = 3, interval = 5 })
		-- 레일 운석 시각: 6, 16, 26, 36, 46 …
		local times = {}
		local at = Logic.METEOR_START
		while at <= 46 do
			table.insert(times, at)
			at += (Logic.meteorWave(at) :: any).interval
		end
		t.eq(times, { 6, 16, 26, 36, 46 })
	end)

	t.test(
		"AC7: pickMeteorTargets 1,000번 — 60%(±7%)가 레이서 기준, 전부 B·D·F 위, A·G에서 12, 원판 밖, 서로·바위와 10",
		function()
			local rails = Layout.rails()
			local rng = seededRng(7)
			local fromRacer, total = 0, 0
			local candidates = {}
			for _, rail in rails do
				-- 조각 가운데(원판 밖) 레이서
				table.insert(candidates, riderOn(rail, 0, 0))
			end
			for run = 1, 1000 do
				local racers = {}
				for _ = 1, 3 do
					table.insert(racers, candidates[rng:NextInteger(1, #candidates)])
				end
				local rocks = {}
				if run % 3 == 0 then
					table.insert(rocks, { x = 0, z = -60 })
					table.insert(rocks, { x = 8, z = -230 })
				end
				local targets = Logic.pickMeteorTargets(rng, racers, rails, rocks, 1)
				for _, target in targets do
					total += 1
					if target.fromRacer then
						fromRacer += 1
					end
					local rail = rails[target.rail]
					t.ok(rail ~= nil, "target on a rail")
					local along, lateral = Logic.railLocal(rail, target.x, target.z)
					local f = Logic.railFrame(rail)
					t.ok(math.abs(along) <= f.half + EPS and math.abs(lateral) <= f.halfWidth + EPS, "inside rail")
					t.ok(math.abs(target.y - Logic.railTopAt(rail, along)) < 1e-6, "on rail top")
					t.ok(target.z <= -16 - 12 and target.z >= -440 + 12, `ends clear {target.z}`)
					t.ok(not Logic.inHub(target.x, target.z), "not on a hub")
					for _, r in rocks do
						t.ok(math.abs(r.z - target.z) >= 10, "away from rocks")
					end
				end
			end
			t.ok(total >= 950, `picked {total}`)
			local ratio = fromRacer / total
			t.ok(ratio >= 0.53 and ratio <= 0.67, `racer ratio {ratio}`)
		end
	)

	t.test(
		"AC7: 한 묶음 운석끼리 z 10 이상, 레이서 기준은 레일 앞 8 근처, 레이서 없으면 무작위만",
		function()
			local rails = Layout.rails()
			local rng = seededRng(3)
			for _ = 1, 300 do
				local targets = Logic.pickMeteorTargets(rng, {}, rails, {}, 4)
				for i, a in targets do
					t.eq(a.fromRacer, false)
					for j = i + 1, #targets do
						t.ok(math.abs(a.z - targets[j].z) >= 10, "batch spacing")
					end
				end
			end
			-- F 왼쪽 줄 가운데 레이서 → 레일 앞 8 지점 (옆 위치 그대로)
			local fl = railsOf("FL")[1]
			local racer = riderOn(fl, 0, 1.5)
			local hits = 0
			for _ = 1, 200 do
				for _, target in Logic.pickMeteorTargets(rng, { racer }, rails, {}, 1) do
					if target.fromRacer then
						hits += 1
						t.ok(math.abs(target.z - (racer.z - 8)) < 1e-6, "8 ahead")
						t.ok(math.abs(target.x - racer.x) < 1e-6, "same lateral")
					end
				end
			end
			t.ok(hits > 80, `racer hits {hits}`)
			-- 원판 쪽으로 넘어가는 레이서 기준 점은 원판 밖으로 옮겨요
			local b1 = railsOf("B")[1]
			local edge = riderOn(b1, Logic.railFrame(b1).half - 7.5, 0)
			for _ = 1, 100 do
				for _, target in Logic.pickMeteorTargets(rng, { edge }, rails, {}, 1) do
					t.ok(not Logic.inHub(target.x, target.z), "settled off the hub")
				end
			end
		end
	)

	---------------------------------------------------------------- AC8
	t.test("AC8: rockOffset |옆| 3~5, 맞은 쪽, 반대쪽 빈 폭 ≥ 6 (폭 12·14), F 폭 9는 nil", function()
		local rng = seededRng(11)
		for _ = 1, 500 do
			for _, width in { 12, 14 } do
				for _, lateral in { -4, -1, 0, 0.1, 2, 5 } do
					local off = Logic.rockOffset(lateral, width, rng) :: number
					t.ok(off ~= nil, "rock on wide rail")
					t.ok(math.abs(off) >= 3 - EPS and math.abs(off) <= 5 + EPS, `offset {off}`)
					if math.abs(lateral) >= 0.25 then
						t.ok(off * lateral > 0, "same side as the hit")
					end
					t.ok(Logic.freeWidthBeside(off, width) >= 6, "free width")
				end
			end
			t.eq(Logic.rockOffset(2, 9, rng), nil)
		end
		local sides = { [-1] = 0, [1] = 0 }
		for _ = 1, 400 do
			local off = Logic.rockOffset(0, 14, rng) :: number
			sides[if off < 0 then -1 else 1] += 1
		end
		t.ok(sides[-1] > 120 and sides[1] > 120, "center hits pick either side")
		for _, rail in Layout.rails() do
			t.eq(rail.allowRock, rail.width >= 12, `rail {rail.index} allowRock`)
		end
	end)

	t.test("AC8: E 들판 60초 시뮬레이션 — 어느 z에서도 빈 폭 ≥ 10, 바위끼리 8 이상", function()
		local rng = seededRng(5)
		local e = Layout.section("E")
		local rocks: { { x: number, z: number, untilAt: number } } = {}
		local at = Logic.FIELD_START
		local waves = 0
		while at <= 60 do
			local wave = Logic.fieldMeteorWave(at) :: any
			for i = #rocks, 1, -1 do
				if rocks[i].untilAt <= at then
					table.remove(rocks, i)
				end
			end
			local racers = {}
			for _ = 1, 6 do
				table.insert(racers, { x = rng:NextNumber(-14, 14), y = 13, z = rng:NextNumber(e.back, e.front) })
			end
			local live = {}
			for _, r in rocks do
				table.insert(live, { x = r.x, z = r.z })
			end
			local targets = Logic.pickFieldTargets(rng, racers, live, wave.count)
			for _, target in targets do
				t.ok(math.abs(target.x) <= Layout.FIELD_WIDTH / 2, "on field x")
				t.ok(target.z <= e.front and target.z >= e.back, "on field z")
				table.insert(rocks, {
					x = target.x,
					z = target.z,
					untilAt = at + Logic.WARN_TIME + Logic.ROCK_DELAY + Logic.ROCK_LIFE + Logic.ROCK_CRUMBLE,
				})
			end
			local all = {}
			for _, r in rocks do
				table.insert(all, { x = r.x, z = r.z })
			end
			for i, a in all do
				for j = i + 1, #all do
					t.ok(math.sqrt((a.x - all[j].x) ^ 2 + (a.z - all[j].z) ^ 2) >= 8 - EPS, "rock spacing")
				end
			end
			local z = e.back
			while z <= e.front do
				t.ok(Logic.fieldFreeWidth(all, z) >= 10, `free width at {z}`)
				z += 0.5
			end
			waves += 1
			at += wave.interval
		end
		t.eq(waves, 11)
		-- 빈 폭 계산 자체
		t.eq(Logic.fieldFreeWidth({}, -300), 30)
		t.eq(Logic.fieldFreeWidth({ { x = 0, z = -300 } }, -300), 13)
		t.eq(Logic.fieldFreeWidth({ { x = -4, z = -300 }, { x = 4, z = -300 } }, -300), 9)
		t.eq(Logic.fieldFreeWidth({ { x = 0, z = -300 } }, -310), 30)
	end)

	t.test("AC8: F 두 줄은 늘 반대 위상, 넉백 상수 수평 30·위 20, 면제 1.5초", function()
		local fl, fr = railsOf("FL")[1], railsOf("FR")[1]
		for i = 0, 1200 do
			local time = i / 100
			local a = Logic.railPhase(time, fl.offset)
			local b = Logic.railPhase(time, fr.offset)
			if a == "Back" then
				t.ok(b == "Forward" or b == "WarnForward" or b == "WarnBack", `t {time}: {b}`)
			end
			if b == "Back" then
				t.ok(a == "Forward" or a == "WarnForward" or a == "WarnBack", `t {time}: {a}`)
			end
		end
		-- 레일 1과 레일 2도 반대
		t.eq(railsOf("B")[1].offset, 0)
		t.eq(railsOf("D")[1].offset, 3)
		t.eq(Logic.KNOCK_OUT, 30)
		t.eq(Logic.KNOCK_UP, 20)
		t.eq(Logic.EXEMPT_TIME, 1.5)
		local push = Logic.knockback(3, 4, 1, 0)
		t.ok(math.abs(push.x - 18) < EPS and math.abs(push.z - 24) < EPS and push.y == 20, "outward")
		local center = Logic.knockback(0, 0, 0, -1)
		t.ok(math.abs(center.z + 30) < EPS and center.y == 20, "fallback at center")
		t.ok(Logic.inImpact(5, 0) and not Logic.inImpact(5.1, 0), "radius 5")
		t.ok(Logic.inImpact(1, 5.9) and not Logic.inImpact(1, 6), "height 6")
		-- 넉백 속도는 이동 감시 면제 상한(수평 130·위 200)보다 작아요
		t.ok(Logic.KNOCK_OUT < 130 and Logic.KNOCK_UP < 200, "under guard caps")
	end)

	---------------------------------------------------------------- AC9
	t.test(
		"AC9: 장식 validate·Extended 예산, 밟는 면 시야 상자와 안 겹침, 배경 바닥은 낙하선보다 10 이상 아래",
		function()
			local specs = Art.decor()
			t.eq(MapKitLogic.validate(specs), nil)
			t.eq(Art.BUDGET, "Extended")
			t.eq(MapKitLogic.checkBudget(specs, "Extended"), nil)
			local count = MapKitLogic.count(specs)
			t.ok(count >= 700 and count <= 1300, `decor parts {count}`)
			for _, sight in Art.courseVolumes() do
				for _, spec in specs do
					local bounds = MapKitLogic.bounds({ spec }) :: Bounds
					t.ok(not overlaps(bounds, sight), `{spec.name} overlaps a sight box`)
				end
			end
			t.ok(Art.GROUND_Y <= -27 - 10, "background ground below the fall line")
			local ground = false
			for _, spec in specs do
				if spec.name == Art.GROUND then
					ground = true
					local b = MapKitLogic.bounds({ spec }) :: Bounds
					t.ok(b.max.y <= Art.GROUND_Y + 0.01, `{spec.name} top {b.max.y}`)
				end
				-- 판정 레일·화살표·운석·바위는 장식이 아니고, 움직이는 장식은 코스 밖이에요
				t.ok(spec.name ~= "Arrow" and spec.name ~= "Meteor" and spec.name ~= "MeteorRock", spec.name)
			end
			t.ok(ground, "background ground exists")
			t.ok(SpaceConveyor.inPool ~= false, "inPool")
			t.ok(#Art.introCamera() >= 4 and #Art.introCamera() <= 5, "intro 4~5 points")
		end
	)

	t.test(
		"AC9: 그림자 조명 ≤ 2, 빛마다 Neon 원인, 파티클 6~12, 움직임 ≥ 3, 빨강·주황 Neon 장식 없음",
		function()
			local specs = Art.decor()
			t.ok(MapKitLogic.countShadowedLights(specs) <= 2, "shadow lights")
			local particles = MapKitLogic.countParticles(specs)
			t.ok(particles >= 6 and particles <= 12, `particles {particles}`)
			t.ok(MapKitLogic.countAnimated(specs) >= 3, "anim")
			for _, spec in specs do
				if spec.light then
					t.ok(spec.material == "Neon" or spec.material == "Glass", `{spec.name} light has a glowing cause`)
					if spec.light.kind == "Surface" then
						t.ok(spec.light.range <= 16, `{spec.name} surface range`)
					end
				end
				if spec.material == "Neon" then
					local col = spec.color
					local warm = col.r > 200 and col.g < 150 and col.b < 120
					t.ok(not warm, `{spec.name} uses a warning colour as Neon`)
				end
			end
		end
	)

	---------------------------------------------------------------- start() — 레일·화살표·저중력
	t.test(
		"start: 레일 속도가 위상대로(레일 1·F왼쪽 = 0, 레일 2·F오른쪽 = 3), 화살표 색·방향, 경고 소리",
		function()
			local h = startHarness()
			h.now = 0.5
			h.fire()
			for _, rail in Layout.rails() do
				local part = h.railParts[rail.index]
				local _, push = Logic.railPhase(0.5, rail.offset)
				local expected = part.CFrame.LookVector * push
				t.ok((part.AssemblyLinearVelocity - expected).Magnitude < 1e-4, `rail {rail.index} velocity`)
			end
			local b1 = h.railParts[1]
			t.ok(b1.AssemblyLinearVelocity:Dot(b1.CFrame.LookVector) > 8.9, "B forward +9")
			local d1 = h.railParts[#railsOf("B") + 1]
			t.ok(d1.AssemblyLinearVelocity:Dot(d1.CFrame.LookVector) < -6.9, "D back −7")
			-- 화살표: B는 청록·앞, D는 주황·뒤
			local forwardCF: { [any]: any } = {}
			for _, arrow in h.arrows do
				local rail = Layout.rails()[arrow.attrs.RailIndex]
				if rail.group == "B" then
					t.eq(arrow.Color, roblox.Color3.fromRGB(63, 224, 240))
				elseif rail.group == "D" then
					t.eq(arrow.Color, roblox.Color3.fromRGB(255, 150, 40))
				end
				forwardCF[arrow] = arrow.CFrame
			end
			-- 경고: 2.65초 → B 경고(밀기 0, 깜빡임), 소리 RailSwitch
			h.now = 2.65
			h.fire()
			t.ok(b1.AssemblyLinearVelocity.Magnitude < 1e-6, "warn push 0")
			t.ok(table.find(h.sfx, "RailSwitch") ~= nil, "RailSwitch cue")
			-- 3.1초 → B 뒤로(−7) + 화살표 180° 뒤집힘(자리는 그대로), D는 앞으로
			h.now = 3.1
			h.fire()
			t.ok(b1.AssemblyLinearVelocity:Dot(b1.CFrame.LookVector) < -6.9, "B back")
			t.ok(d1.AssemblyLinearVelocity:Dot(d1.CFrame.LookVector) > 8.9, "D forward")
			for _, arrow in h.arrows do
				local rail = Layout.rails()[arrow.attrs.RailIndex]
				if rail.group == "B" then
					t.eq(arrow.Color, roblox.Color3.fromRGB(255, 150, 40))
					local before = forwardCF[arrow]
					t.ok(arrow.CFrame.LookVector:Dot(before.LookVector) < -0.99, "B arrow flipped")
				end
			end
			-- 정리하면 레일이 멈춰요
			for i = #h.ctx.cleanup.items, 1, -1 do
				local item = h.ctx.cleanup.items[i]
				if type(item) == "function" then
					item()
				end
			end
			t.ok(b1.AssemblyLinearVelocity.Magnitude < 1e-6, "cleanup stops rails")
		end
	)

	t.test(
		"start: 저중력 — 구역 안에서만 힘(질량 × g × 0.5), 나가면·탈락·통과 직전·캐릭터 교체·정리 때 지워요",
		function()
			local h = startHarness()
			h.now = 1
			local p1 = fakeRacer(h, "P1", 0, 3, -130) -- C 구역 안
			local p2 = fakeRacer(h, "P2", 0, 3, -60) -- B
			h.fire()
			local force = gravityOn(h, p1.root)
			t.ok(force ~= nil, "force in zone")
			t.eq(force.Name, "SpaceLowGravity")
			t.ok(math.abs(force.Force.Y - 10 * 196.2 * 0.5) < 1e-3, "lift = m g / 2")
			t.eq(force.Attachment0, p1.root.children.RootAttachment)
			t.eq(force.ApplyAtCenterOfMass, true)
			t.eq(gravityOn(h, p2.root), nil)
			-- 다음 틱에도 하나만
			h.fire()
			t.eq(liveForces(h), 1)
			-- 구역을 나가면 지워요
			p1.place(0, 3, -180)
			h.fire()
			t.eq(liveForces(h), 0)
			-- 다시 들어갔다가 떨어지면: eliminate 부르기 직전에 이미 없어요
			p1.place(0, 3, -130)
			h.fire()
			t.eq(liveForces(h), 1)
			h.passCheck = function(player: any)
				t.eq(gravityOn(h, player.root), nil, `{player.Name}: force removed before pass/eliminate`)
			end
			p1.place(0, -28, -130)
			h.fire()
			t.eq(h.ctx.eliminated, { "P1" })
			t.eq(liveForces(h), 0)
			-- 캐릭터 교체: 예전 루트의 힘을 지우고 새 루트에 하나
			local p3 = fakeRacer(h, "P3", 0, 3, -130)
			h.fire()
			local old = gravityOn(h, p3.root)
			t.ok(old ~= nil, "p3 force")
			local newRoot = fakeInstance("Part")
			newRoot.AssemblyMass = 12
			newRoot.children = { RootAttachment = fakeInstance("Attachment") }
			p3.Character.children.HumanoidRootPart = newRoot
			p3.root = newRoot
			p3.place = function(px: number, py: number, pz: number)
				newRoot.Position = h.ctx.origin:PointToWorldSpace(RV3.new(px, py, pz))
			end
			p3.place(0, 3, -130)
			h.fire()
			t.eq(old.destroyed, true)
			t.eq(liveForces(h), 1)
			t.ok(math.abs(gravityOn(h, newRoot).Force.Y - 12 * 196.2 * 0.5) < 1e-3, "new root lift")
			-- getRacers에서 빠지면(리셋·퇴장 등) 지워요
			table.remove(h.racers, table.find(h.racers, p3) :: number)
			h.fire()
			t.eq(liveForces(h), 0)
			-- 라운드 정리: 남은 힘 전부
			local p4 = fakeRacer(h, "P4", 5, 3, -120)
			h.fire()
			t.eq(liveForces(h), 1)
			for i = #h.ctx.cleanup.items, 1, -1 do
				local item = h.ctx.cleanup.items[i]
				if type(item) == "function" then
					item()
				end
			end
			t.eq(liveForces(h), 0)
			local _ = p4
			-- 결승 통과도 직전에 지워요 (구역 밖이라 원래 없지만 순서 확인)
			local h2 = startHarness()
			h2.passCheck = function(player: any)
				t.eq(gravityOn(h2, player.root), nil)
			end
			fakeRacer(h2, "Winner", 0, 13, -463)
			h2.fire()
			t.eq(h2.ctx.passed, { "Winner" })
		end
	)

	t.test("start: 낙하선은 origin 로컬 (아레나 슬롯), 끝난 라운드는 판정 없음", function()
		local h = startHarness()
		local safe = fakeRacer(h, "Safe", 0, -24.9, -50)
		local fell = fakeRacer(h, "Fell", 0, -25.1, -50)
		local high = fakeRacer(h, "High", 0, -14.9, -300)
		local low = fakeRacer(h, "Low", 0, -15.1, -300)
		h.fire()
		t.eq(h.ctx.eliminated, { "Fell", "Low" })
		local _ = safe and high and low
		h.ctx.active = false
		fakeRacer(h, "Late", 0, -100, -50)
		h.fire()
		t.eq(#h.ctx.eliminated, 2)
	end)
end
