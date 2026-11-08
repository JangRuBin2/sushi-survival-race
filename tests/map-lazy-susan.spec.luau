--!strict
-- m6-06 "중식당 회전 원판"(lazy-susan): 대형 Survival(스폰 40). 고리 회전·구멍 예고/열림, 가운데 유리판 서든데스,
-- 밀기 방향, 그릇 자리, 장식 예산·시야 상자, build 태그, 서버 start(가짜 Heartbeat): 조각 열림·밀기·그릇 넉백·낙하.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local H = require("./lib/LargeMapHarness")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local Layout = RobloxRequire.require(Shared.maps.LazySusanLayout)
local Logic = RobloxRequire.require(Shared.maps.LazySusanLogic)
local Art = RobloxRequire.require(Shared.maps.LazySusanArt)
local Map = RobloxRequire.require(Shared.maps.LazySusan)

local RCF: any = roblox.CFrame
local EPS = 1e-6
local PATH = "src/shared/maps/LazySusan.luau"

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function harness(model: any): H.Harness
	return H.new(PATH, {
		LazySusanArt = Art,
		LazySusanLayout = Layout,
		LazySusanLogic = Logic,
		MapTypes = MapTypes,
	}, model)
end

local function segmentPart(model: any, ring: number, k: number): any
	return model:FindFirstChild("Rings"):FindFirstChild(string.format("Ring%d_%02d", ring, k))
end

-- t초에 ring에서 Open인 조각 하나
local function openSegment(ring: any, t: number): number?
	for k = 1, Layout.SEGMENTS do
		if Logic.segmentState(ring, k, t) == "Open" then
			return k
		end
	end
	return nil
end

return function(t: Test.Test)
	t.test("등록: 풀에 든 대형 Survival, capacity 40·minPlayers 12·75초", function()
		t.eq(MapTypes.validate(Map), nil)
		t.eq(Maps.get("lazy-susan"), Map)
		t.eq(Map.kind, "Survival")
		t.eq(Map.displayName, "중식당 회전 원판")
		t.eq(Map.timeLimit, 75)
		t.eq(Map.capacity, Config.Maps.LargeCapacity)
		t.eq(Map.minPlayers, Config.Maps.LargeMinPlayers)
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
	end)

	t.test("고리: 사이 틈 1.5, 번갈아 반대로 돌고, 바깥일수록 구멍이 많아요", function()
		t.eq(Layout.RINGS[1].inner - Layout.CENTER_RADIUS, 0.5)
		for i = 2, #Layout.RINGS do
			local a, b = Layout.RINGS[i - 1], Layout.RINGS[i]
			t.ok(near(b.inner - a.outer, 1.5, EPS), `gap {i}`)
			t.eq(a.dir, -b.dir)
			t.ok(#b.holes >= #a.holes)
		end
		t.eq(Layout.RINGS[#Layout.RINGS].outer, Layout.OUTER_RADIUS)
		-- 스폰 40개는 모두 고리 1~3 위
		local positions = Layout.spawnPositions()
		t.eq(#positions, 40)
		for i, p in positions do
			local ring = Logic.ringAt(p.x, Layout.FOOT_OFFSET, p.z)
			t.ok(ring ~= nil and ring.index <= 3, `spawn {i} on a ring`)
		end
	end)

	t.test(
		"구멍: 4초 전엔 없음, 4초 1개, 20초 전부, 60초 폭 70°, 언제나 고리마다 디딜 곳이 남아요",
		function()
			for _, ring in Layout.RINGS do
				t.eq(openSegment(ring, 3.9), nil)
				t.eq(#Logic.holeCenters(ring, 10), 1)
				t.eq(#Logic.holeCenters(ring, 25), #ring.holes)
			end
			t.eq(Logic.holeSpan(59), 40)
			t.eq(Logic.holeSpan(60), 70)
			for step = 0, 750 do
				local time = step * 0.1
				for _, ring in Layout.RINGS do
					local open = 0
					for k = 1, Layout.SEGMENTS do
						if Logic.segmentState(ring, k, time) == "Open" then
							open += 1
						end
					end
					t.ok(open <= Layout.SEGMENTS * 0.65, `ring {ring.index} t {time} open {open}`)
				end
			end
		end
	)

	t.test("예고: 열리는 조각은 그 직전 0.8초 안에 반드시 Warn을 거쳐요", function()
		for _, ring in Layout.RINGS do
			for k = 1, Layout.SEGMENTS do
				local prev = Logic.segmentState(ring, k, 0)
				for step = 1, 1500 do
					local time = step * 0.05
					local state = Logic.segmentState(ring, k, time)
					if state == "Open" and prev == "Solid" then
						-- Solid에서 바로 Open이면 안 돼요 (0.05초 간격으로 보면 Warn이 끼어 있어야)
						t.ok(false, `ring {ring.index} seg {k} opened without warning at {time}`)
					end
					prev = state
				end
			end
		end
	end)

	t.test("가운데 유리판: 서든데스 전 늘 Solid, 그 뒤 5초마다 Warn → Open 1.5초", function()
		for step = 0, 599 do
			t.eq(Logic.centerState(step * 0.1), "Solid")
		end
		t.eq(Logic.centerState(60), "Solid")
		t.eq(Logic.centerState(62.9), "Warn")
		t.eq(Logic.centerState(63.6), "Open")
		t.eq(Logic.centerState(64.9), "Open")
		t.eq(Logic.centerState(65.1), "Solid")
	end)

	t.test(
		"회전: 접선이 각도가 커지는 쪽(dir 1), 그릇은 고리 가운데를 따라 돌아요, 45초부터 1.4배",
		function()
			local a = math.rad(30)
			local tx, tz = Logic.tangent(math.cos(a) * 20, math.sin(a) * 20, 1)
			t.ok(near(tx, -math.sin(a), EPS) and near(tz, math.cos(a), EPS))
			local ring = Layout.RINGS[2]
			t.ok(near(Logic.ringAngle(ring, 46) - Logic.ringAngle(ring, 45), ring.dir * 360 / ring.period * 1.4, 1e-6))
			t.ok(near(Logic.pushSpeed(Layout.RINGS[1], 18, 10), 2 * math.pi / 19 * 18, 1e-6))
			t.eq(Logic.pushSpeed(Layout.RINGS[4], 70, 50), Layout.PUSH_CAP)
			for _, bowl in Layout.BOWLS do
				local r = Layout.RINGS[bowl.ring]
				for _, time in { 0, 13, 52 } do
					local x, z = Logic.bowlPosition(bowl, time)
					t.ok(near(math.sqrt(x * x + z * z), (r.inner + r.outer) / 2, 1e-6))
				end
			end
			t.ok(Logic.bowlHit(0, 0, 0))
			t.ok(not Logic.bowlHit(0, 0, 4), "jump clears")
			t.eq(Logic.ringAt(18, Layout.FOOT_OFFSET + 8, 0), nil, "in the air: no push")
		end
	)

	t.test("원탁은 낙하선보다 10 이상 아래", function()
		t.ok(Art.TABLE_Y <= Logic.fallLine() - 10)
	end)

	t.test("장식: validate·Large 예산·시야 상자 비움·소개 카메라는 방 안", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.eq(Art.BUDGET, "Large")
		t.eq(MapKitLogic.checkBudget(decor, "Large"), nil)
		t.ok(MapKitLogic.count(decor) >= 400)
		t.ok(MapKitLogic.countAnimated(decor) >= 10, "lanterns sway")
		for i, spec in decor do
			local b = MapKitLogic.bounds({ spec }) :: any
			for j, volume in Art.courseVolume() do
				local overlap = b.min.x < volume.max.x
					and b.max.x > volume.min.x
					and b.min.y < volume.max.y
					and b.max.y > volume.min.y
					and b.min.z < volume.max.z
					and b.max.z > volume.min.z
				t.ok(not overlap, `decor #{i} {spec.name} overlaps course volume #{j}`)
			end
		end
		for _, p in Art.introCamera() do
			t.ok(math.sqrt(p.pos.x ^ 2 + p.pos.z ^ 2) < Art.ROOM_RADIUS - 20, "intro inside the room")
			t.ok(math.abs(p.pos.x) <= Layout.OUTER_RADIUS + 40 and math.abs(p.pos.z) <= Layout.OUTER_RADIUS + 40)
			t.ok(p.pos.y > Layout.FLOOR_Y + 4 and p.pos.y < 60, "below the lanterns")
		end
	end)

	t.test(
		"build: 스폰 40, 조각 144(태그·속성), 그릇 6 충돌 없음, 가운데 유리판 태그",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = H.build("lazy-susan", origin)
			t.eq(#model:FindFirstChild("Spawns"):GetChildren(), 40)
			local tags: { [string]: number } = {}
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					tags[tag] = (tags[tag] or 0) + 1
				end
				if d:IsA("BasePart") and d:HasTag("SusanBowl") then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name)
				end
				if d:IsA("BasePart") and d:HasTag("SusanSegment") then
					t.ok(d.CanCollide, d.Name)
					t.ok(type(d:GetAttribute("Ring")) == "number" and type(d:GetAttribute("Segment")) == "number")
				end
			end
			t.eq(tags.SusanSegment, Layout.SEGMENTS * #Layout.RINGS)
			t.eq(tags.SusanBowl, #Layout.BOWLS)
			t.eq(tags.SusanCenter, 1)
			-- 조각은 그 각도 자리에: 가운데가 반지름 rMid
			local part = segmentPart(model, 3, 10)
			local rel = origin:PointToObjectSpace(part.CFrame.Position)
			local ring = Layout.RINGS[3]
			local a = math.rad(Layout.segmentAngle(10))
			t.ok(near(rel.X, math.cos(a) * (ring.inner + ring.outer) / 2, 1e-3))
			t.ok(near(rel.Z, math.sin(a) * (ring.inner + ring.outer) / 2, 1e-3))
		end
	)

	t.test(
		"서버 모듈: 태그는 ctx.model 하위만, 고리 밀기에는 MoveExempt 없음(그릇 넉백 한 곳)",
		function()
			local source = fs.readFile(PATH)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil)
			local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
			t.eq(marks, 1)
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function") then
					local ok = string.match(line, "= require%(") ~= nil
						or string.match(line, '= "[^"]*"$') ~= nil
						or string.match(line, "^local [%u_]+ = %-?[%d%.]+") ~= nil
						or string.match(line, "^local map: MapTypes") ~= nil
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	t.test(
		"start: 구멍 조각은 열리고(소리) 낙하는 탈락, 고리 위 사람은 접선으로 밀려요(면제 없음)",
		function()
			local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local model = H.build("lazy-susan", origin)
			local h = harness(model)
			local rider = H.fakeRacer(origin, 18, Layout.FOOT_OFFSET, 0)
			local falling = H.fakeRacer(origin, 40, Logic.fallLine() - 0.1, 0)
			local ctx = H.newCtx(model, origin, { rider, falling })
			h.setClock(0)
			h.map.start(ctx)
			h.setClock(10)
			h.fire(0.1)
			t.ok(ctx.eliminated[falling])
			local ring1 = Layout.RINGS[1]
			local k = openSegment(ring1, 10) :: number
			t.ok(k ~= nil)
			local part = segmentPart(model, 1, k)
			t.ok(not part.CanCollide and not part.CanQuery)
			t.ok(part.Transparency > 0.5)
			t.ok(table.find(h.sounds, "TileVanish") ~= nil)
			-- 다른 고리 조각 중 Solid인 건 그대로 충돌
			for kk = 1, Layout.SEGMENTS do
				if Logic.segmentState(ring1, kk, 10) == "Solid" then
					t.ok(segmentPart(model, 1, kk).CanCollide)
				end
			end
			local v = origin:VectorToObjectSpace(rider.root.AssemblyLinearVelocity)
			t.ok(near(v.Z, Layout.PUSH_ACCEL * 0.1, 1e-6), `pushed along the tangent {v.Z}`)
			t.ok(near(v.X, 0, 1e-6))
			t.eq(#h.marks, 0, "ring push has no MoveExempt")
		end
	)

	t.test("start: Warn 조각은 빨강, 서든데스에 가운데 유리판이 열려요", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("lazy-susan", origin)
		local h = harness(model)
		local ctx = H.newCtx(model, origin, {})
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(30)
		h.fire(1 / 60)
		local warnColor =
			roblox.Color3.fromRGB(Art.JUDGE_COLORS.warn.r, Art.JUDGE_COLORS.warn.g, Art.JUDGE_COLORS.warn.b)
		local seen = 0
		for _, ring in Layout.RINGS do
			for k = 1, Layout.SEGMENTS do
				if Logic.segmentState(ring, k, 30) == "Warn" then
					t.eq(segmentPart(model, ring.index, k).Color, warnColor)
					seen += 1
				end
			end
		end
		t.ok(seen > 0, "some tiles are warning at 30 s")
		local center = model:FindFirstChild("CenterGlass")
		t.ok(center.CanCollide)
		h.setClock(64)
		h.fire(1 / 60)
		t.ok(not center.CanCollide)
		h.setClock(65.5)
		h.fire(1 / 60)
		t.ok(center.CanCollide)
	end)

	t.test("start: 반찬 그릇에 닿으면 회전 방향으로 밀려 넘어지고 면제 0.8초", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("lazy-susan", origin)
		local h = harness(model)
		local bowl = Layout.BOWLS[1]
		local x, z = Logic.bowlPosition(bowl, 2)
		local racer = H.fakeRacer(origin, x, Layout.FOOT_OFFSET, z)
		local ctx = H.newCtx(model, origin, { racer })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(2)
		h.fire(1 / 60)
		t.eq(#h.marks, 1)
		t.eq(h.marks[1].seconds, Layout.BOWL_EXEMPT)
		local v = origin:VectorToObjectSpace(racer.root.AssemblyLinearVelocity)
		local tx, tz = Logic.tangent(x, z, Layout.RINGS[bowl.ring].dir)
		t.ok(near(v.X, tx * Layout.BOWL_KNOCK, 1e-3) and near(v.Z, tz * Layout.BOWL_KNOCK, 1e-3))
		t.ok(near(v.Y, Layout.BOWL_KNOCK_UP, 1e-3))
		t.ok(racer.humanoid.PlatformStand)
		-- 쿨다운 동안은 다시 안 맞아요
		h.fire(1 / 60)
		t.eq(#h.marks, 1)
	end)
end
