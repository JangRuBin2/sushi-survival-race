--!strict
-- m5-05 Survival 맵 "튀김 냄비 탈출": 인터페이스·스폰, 기름 높이, 튀김 판정, 발판 경로·안전 구역·넓이,
-- 튀는 기름 일정·넉백, 장식 예산 (순수 로직)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.TempuraPotLayout)
local Logic = RobloxRequire.require(Shared.maps.TempuraPotLogic)
local Art = RobloxRequire.require(Shared.maps.TempuraPotArt)

local EPS = 1e-6

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function raftsOfTier(tier: number): { any }
	local list = {}
	for _, raft in Layout.rafts() do
		if raft.tier == tier then
			table.insert(list, raft)
		end
	end
	return list
end

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: tempura-pot은 인터페이스를 지키는 Survival 맵이고 풀에 들어가요", function()
		local map = Maps.get("tempura-pot")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "튀김 냄비 탈출")
		t.eq(map.timeLimit, nil) -- Config.TimeLimit.Survival
		t.ok(map.inPool ~= false, "inPool = false 줄이 지워졌어야 해요")
		local inPool = false
		for _, info in Maps.infos() do
			if info.id == "tempura-pot" then
				inPool = true
			end
		end
		t.ok(inPool, "random pool has tempura-pot")
	end)

	t.test("AC1: 스폰 24개가 바구니 위(가장자리 2 안쪽)에서 서로 3 이상", function()
		local spawns = Layout.spawnOffsets()
		t.eq(#spawns, 24)
		local basket = Layout.basket()
		for i, s in spawns do
			local dx, dz = s.x - basket.x, s.z - basket.z
			t.ok(math.sqrt(dx * dx + dz * dz) <= basket.radius - 2, `spawn {i} off basket`)
		end
		for a = 1, #spawns do
			for b = a + 1, #spawns do
				local dx, dz = spawns[a].x - spawns[b].x, spawns[a].z - spawns[b].z
				t.ok(math.sqrt(dx * dx + dz * dz) >= 3 - EPS, `spawn {a} and {b} too close`)
			end
		end
	end)

	t.test("무대: 냄비 반지름 36, 바닥 −10, 벽 40, 바구니 반지름 20 윗면 3, 층 7~31", function()
		t.eq(Layout.POT_INNER_RADIUS, 36)
		t.eq(Layout.POT_FLOOR_Y, -10)
		t.eq(Layout.POT_WALL_TOP_Y, 40)
		t.eq(Layout.BASKET_RADIUS, 20)
		t.eq(Layout.BASKET_TOP_Y, 3)
		t.eq(Layout.TIER_TOPS, { 7, 11, 15, 19, 23, 27, 31 })
	end)

	t.test(
		"발판 표: 7~19층 4~5개, 23층 지름 7 두 개, 27층 지름 6 두 개, 31층 지름 5 하나",
		function()
			for tier = 1, 4 do
				local n = #raftsOfTier(tier)
				t.ok(n >= 4 and n <= 5, `tier {tier}: {n} rafts`)
			end
			local expect = { [5] = { 2, 3.5 }, [6] = { 2, 3 }, [7] = { 1, 2.5 } }
			for tier, row in expect do
				local list = raftsOfTier(tier)
				t.eq(#list, row[1], `tier {tier} count`)
				for _, raft in list do
					t.eq(raft.shape, "Disc")
					t.ok(near(raft.radius, row[2]), `tier {tier} radius {raft.radius}`)
				end
			end
			-- 모양 3종이 다 쓰여요, 치수는 스펙 표 그대로
			local kinds: { [string]: boolean } = {}
			for _, raft in Layout.rafts() do
				kinds[raft.kind] = true
				if raft.kind == "Shrimp" then
					t.eq(raft.length, 12)
					t.eq(raft.width, 5)
				elseif raft.kind == "Shiso" then
					t.eq(raft.length, 10)
					t.eq(raft.width, 8)
				elseif raft.kind == "SweetPotato" and raft.tier <= 4 then
					t.ok(near(raft.radius, 4), "sweet potato diameter 8")
				end
			end
			t.ok(kinds.Shrimp and kinds.SweetPotato and kinds.Shiso, "all three tempura shapes")
			-- key가 겹치지 않아요
			local seen: { [string]: boolean } = {}
			for _, raft in Layout.rafts() do
				t.ok(not seen[raft.key], `duplicate key {raft.key}`)
				seen[raft.key] = true
			end
		end
	)

	t.test("발판은 전부 냄비 안(벽에서 0.5 이상), 바구니 바로 위(8 이내)와 안 겹침", function()
		local basket = Layout.basket()
		local all = Layout.rafts()
		for _, raft in all do
			t.ok(Logic.wallClearance(raft) >= 0.5, `{raft.key} touches the wall`)
			if raft.topY - basket.topY <= 8 then
				t.ok(Logic.gap(raft, basket) > 0, `{raft.key} overlaps the basket`)
			end
		end
		-- 바로 위층·두 층 위(높이 차 4·8)와 위에서 볼 때 안 겹쳐요 (점프할 때 머리가 안 닿게)
		for _, a in all do
			for _, b in all do
				local rise = b.topY - a.topY
				if rise == 4 or rise == 8 then
					t.ok(Logic.gap(a, b) > 0.3, `{a.key} under {b.key} (rise {rise})`)
				end
			end
		end
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: oilHeight 0·6초 0, 16초 4, 60초 21.6, 100초 22", function()
		t.eq(Logic.oilHeight(0), 0)
		t.eq(Logic.oilHeight(6), 0)
		t.ok(near(Logic.oilHeight(16), 4), `16s: {Logic.oilHeight(16)}`)
		t.ok(near(Logic.oilHeight(60), 21.6), `60s: {Logic.oilHeight(60)}`)
		t.eq(Logic.oilHeight(100), 22)
	end)

	t.test("AC2: oilHeight는 0~100초 0.1초 간격으로 줄어들지 않아요", function()
		local previous = Logic.oilHeight(0)
		for i = 1, 1000 do
			local h = Logic.oilHeight(i * 0.1)
			t.ok(h >= previous - EPS, `drops at {i * 0.1}`)
			previous = h
		end
	end)

	t.test("AC2: 바구니 13.5초, 7·11·15·19층 23.5·33.5·43.5·53.5초에 잠겨요", function()
		local function submergedAt(y: number): number
			local time = 0
			while Logic.oilHeight(time) <= y and time < 200 do
				time += 0.05
			end
			return time
		end
		local expected = { { 3, 13.5 }, { 7, 23.5 }, { 11, 33.5 }, { 15, 43.5 }, { 19, 53.5 } }
		for _, row in expected do
			t.ok(math.abs(submergedAt(row[1]) - row[2]) <= 0.06, `y {row[1]}: {submergedAt(row[1])}`)
		end
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: isFried — 발 < 기름이면 true, 같거나 높으면 false", function()
		t.eq(Logic.isFried(2.9, 3), true)
		t.eq(Logic.isFried(3, 3), false)
		t.eq(Logic.isFried(3.1, 3), false)
		t.eq(Logic.isFried(-10, 0), true)
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: 바구니 → 꼭대기 경로가 있고, 서로 다른 7층 시작 발판이 3개 이상", function()
		local starts = Logic.startsReachingTop()
		t.ok(#starts >= 3, `{#starts} starts`)
		local seen: { [string]: boolean } = {}
		for _, raft in starts do
			t.eq(raft.tier, 1)
			t.ok(not seen[raft.key], "distinct start")
			seen[raft.key] = true
			local path = Logic.pathFrom(raft)
			t.ok(path ~= nil, `{raft.key} reaches the top`)
			if path then
				t.eq(path[#path].topY, 31)
				-- 경로의 한 걸음은 같은 층(틈 ≤ 5) 또는 한 층 위(수직 4, 틈 ≤ 5)
				for i = 2, #path do
					local rise = path[i].topY - path[i - 1].topY
					t.ok(rise == 0 or rise == 4, `rise {rise}`)
					t.ok(Logic.gap(path[i - 1], path[i]) <= 5 + EPS, "gap ≤ 5")
				end
			end
		end
		t.ok(Logic.pathFrom(Layout.basket()) ~= nil, "basket reaches the top")
	end)

	t.test("AC4: 세 갈래 — 7층 발판 3개 이상이 11층으로 바로 올라가요", function()
		local direct = 0
		for _, low in raftsOfTier(1) do
			for _, high in raftsOfTier(2) do
				if Logic.canClimb(low, high) then
					direct += 1
					break
				end
			end
		end
		t.ok(direct >= 3, `{direct} tier-1 rafts climb straight up`)
	end)

	t.test(
		"AC4: 바구니에서 7층 발판으로 올라갈 수 있고, 층마다 다음 층으로 이어져요",
		function()
			local basket = Layout.basket()
			for _, raft in raftsOfTier(1) do
				t.ok(Logic.canClimb(basket, raft), `{raft.key} from basket`)
			end
			for tier = 1, 6 do
				local linked = false
				for _, low in raftsOfTier(tier) do
					for _, high in raftsOfTier(tier + 1) do
						if Logic.canClimb(low, high) then
							linked = true
						end
					end
				end
				t.ok(linked, `tier {tier} → {tier + 1}`)
			end
		end
	)

	t.test("AC4: 같은 층 발판끼리 틈 ≤ 6으로 모두 이어져요", function()
		for tier = 1, #Layout.TIER_TOPS do
			t.ok(Logic.tierConnected(tier), `tier {tier} connected`)
		end
	end)

	t.test("AC4: gap 기하 — 원판끼리, 원판-사각형, 사각형끼리(회전 포함)", function()
		local function disc(x: number, z: number, r: number): any
			return { shape = "Disc", x = x, z = z, radius = r, length = r * 2, width = r * 2, yaw = 0 }
		end
		local function rect(x: number, z: number, l: number, w: number, yaw: number): any
			return { shape = "Rect", x = x, z = z, radius = 0, length = l, width = w, yaw = yaw }
		end
		t.ok(near(Logic.gap(disc(0, 0, 2), disc(10, 0, 3)), 5), "disc-disc")
		t.eq(Logic.gap(disc(0, 0, 2), disc(3, 0, 3)), 0)
		t.ok(near(Logic.gap(rect(0, 0, 4, 2, 0), disc(7, 0, 1)), 4), "rect-disc along X")
		t.ok(near(Logic.gap(rect(0, 0, 4, 2, 90), disc(7, 0, 1)), 5), "rect rotated 90°")
		t.ok(near(Logic.gap(rect(0, 0, 4, 2, 0), rect(10, 0, 4, 2, 0)), 6), "rect-rect")
		t.eq(Logic.gap(rect(0, 0, 4, 4, 0), rect(1, 1, 4, 4, 45)), 0)
		t.ok(Logic.isOnRaft(rect(0, 0, 4, 2, 90), 0, 1.9), "inside rotated rect")
		t.ok(not Logic.isOnRaft(rect(0, 0, 4, 2, 90), 1.9, 0), "outside rotated rect")
	end)

	---------------------------------------------------------------- AC5
	t.test("AC5: 23·27·31층 윗면이 oilHeight(60)보다 1 이상 높아요", function()
		local oil60 = Logic.oilHeight(60)
		for _, tier in Layout.SAFE_TIERS do
			t.ok(Layout.TIER_TOPS[tier] - oil60 >= 1, `tier {Layout.TIER_TOPS[tier]}`)
		end
		-- 기름은 22에서 멈춰서 23층은 끝까지 안 잠겨요
		t.ok(Logic.oilHeight(1e6) < Layout.TIER_TOPS[5], "oil cap below tier 23")
	end)

	t.test("AC5: 꼭대기 가장자리 → 벽 수평 6 이상, 벽 높이 − 꼭대기 윗면 > 7", function()
		local top = raftsOfTier(7)[1]
		t.ok(Logic.wallClearance(top) >= 6, `top wall clearance {Logic.wallClearance(top)}`)
		t.ok(Layout.POT_WALL_TOP_Y - top.topY > 7, "wall height above top")
		-- 다른 안전 구역 발판도 벽에서 6 이상 (테두리로 못 넘어가게)
		for _, tier in Layout.SAFE_TIERS do
			for _, raft in raftsOfTier(tier) do
				t.ok(Logic.wallClearance(raft) >= 6, `{raft.key} wall clearance`)
			end
		end
	end)

	---------------------------------------------------------------- AC6
	t.test("AC6: 23·27·31층 윗면 넓이 합 ≤ 160", function()
		local total = 0
		for _, tier in Layout.SAFE_TIERS do
			for _, raft in raftsOfTier(tier) do
				total += Logic.area(raft)
			end
		end
		t.ok(total <= 160, `safe area {total}`)
		t.ok(total > 140, `safe area {total} (기본 배치 약 153)`)
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: splashInterval 9.9 → nil, 10 → 3, 30 → 2, 45 → 1.5", function()
		t.eq(Logic.splashInterval(0), nil)
		t.eq(Logic.splashInterval(9.9), nil)
		t.eq(Logic.splashInterval(10), 3)
		t.eq(Logic.splashInterval(29.9), 3)
		t.eq(Logic.splashInterval(30), 2)
		t.eq(Logic.splashInterval(44.9), 2)
		t.eq(Logic.splashInterval(45), 1.5)
		t.eq(Logic.splashInterval(60), 1.5)
		t.eq(Logic.SPLASH_WARN_TIME, 1.2)
		t.eq(Logic.SPLASH_RADIUS, 5)
		t.eq(Logic.SPLASH_COOLDOWN, 0.5)
		t.eq(Logic.SPLASH_MOVE_EXEMPT, 1.5)
		t.eq(Logic.SPLASH_KNOCKDOWN_TIME, 1)
	end)

	t.test("AC7: splashKnockback — 바깥 방향 수평 35·위 25, 반경 5 밖이면 nil", function()
		local v = Logic.splashKnockback(3, 4)
		t.ok(v ~= nil, "inside radius")
		if v then
			t.ok(near(v.x, 21) and near(v.z, 28), `direction {v.x}, {v.z}`)
			t.eq(v.y, 25)
			t.ok(near(math.sqrt(v.x * v.x + v.z * v.z), 35), "horizontal 35")
		end
		local edge = Logic.splashKnockback(0, -5)
		t.ok(edge ~= nil and near(edge.z, -35), "edge pushes outward")
		t.eq(Logic.splashKnockback(5.01, 0), nil)
		t.eq(Logic.splashKnockback(4, 4), nil)
		local center = Logic.splashKnockback(0, 0)
		t.ok(center ~= nil, "centre still knocks")
		if center then
			t.ok(near(math.sqrt(center.x * center.x + center.z * center.z), 35), "centre horizontal 35")
		end
	end)

	t.test("AC7: pickSplashTarget — 후보 중 하나, 없으면 nil", function()
		t.eq(Logic.pickSplashTarget({}, fakeRng(1)), nil)
		local candidates = { "a", "b", "c" }
		local hit: { [string]: boolean } = {}
		for seed = 1, 60 do
			local picked = Logic.pickSplashTarget(candidates, fakeRng(seed))
			t.ok(picked ~= nil and table.find(candidates, picked) ~= nil, "picked a candidate")
			if picked then
				hit[picked] = true
			end
		end
		t.ok(hit.a and hit.b and hit.c, "every candidate can be picked")
	end)

	---------------------------------------------------------------- AC8
	t.test("AC8: 장식이 MapKitLogic.validate 통과, 600개 이하, 젓가락 높이 50 이상", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, `decor {MapKitLogic.count(decor)}`)
		local bounds = MapKitLogic.bounds(decor)
		t.ok(bounds ~= nil and bounds.max.y >= 50, "giant chopsticks reach 50+")
	end)

	t.test("AC8: IntroCamera 4점", function()
		t.eq(#Art.introCamera(), 4)
	end)
end
