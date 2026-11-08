--!strict
-- m6-02 대형 맵 기반 (GDD v0.9 3.2·4.1·5.4): 방 32·40명, 25명 이상 통과 비율, 맵 capacity/minPlayers,
-- 판 계획 인원 맞춤, 텔레포트 40명, Large 예산.

local fs = require("@lune/fs")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local PlacePayload = RobloxRequire.require(Shared.PlacePayload)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function chain(startCount: number): { number }
	local roundCount = Rules.roundCount(startCount)
	local counts = { startCount }
	for i = 1, roundCount - 1 do
		counts[i + 1] = Rules.qualifyCount(counts[i], roundCount, i, startCount)
	end
	return counts
end

-- 기존 풀 모양(Race 8 · Survival 7 · Final 6) + 대형 Race 3 · Survival 2
local function pool(withLarge: boolean): { any }
	local list = {}
	for i = 1, 8 do
		table.insert(list, { id = `race{i}`, kind = "Race" })
	end
	for i = 1, 7 do
		table.insert(list, { id = `survival{i}`, kind = "Survival" })
	end
	for i = 1, 6 do
		table.insert(list, { id = `final{i}`, kind = "Final" })
	end
	if withLarge then
		for i = 1, 3 do
			table.insert(list, { id = `bigRace{i}`, kind = "Race", capacity = 40, minPlayers = 12 })
		end
		for i = 1, 2 do
			table.insert(list, { id = `bigSurvival{i}`, kind = "Survival", capacity = 40, minPlayers = 12 })
		end
	end
	return list
end

return function(t: Test.Test)
	t.test("Config: 방 인원 32·40, 대형 비율, 맵 인원 기본값", function()
		t.eq(Config.Room.MaxPlayerOptions, { 4, 8, 12, 16, 24, 32, 40 })
		t.eq(Config.Room.DefaultMaxPlayers, 12)
		t.eq(Config.Rules.LargeMinPlayers, 25)
		t.eq(Config.Rules.LargePassRatios, { 0.60, 0.45, 0.40 })
		t.eq(Config.Maps.StandardCapacity, 24)
		t.eq(Config.Maps.LargeCapacity, 40)
		t.eq(Config.Maps.LargeMinPlayers, 12)
		t.eq(PlacePayload.MAX_MEMBERS, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
	end)

	t.test("통과 인원: 25명 이상은 4라운드 그대로 0.60·0.45·0.40, 24명 이하는 그대로", function()
		t.eq(Rules.roundCount(40), 4)
		t.eq(Rules.roundCount(25), 4)
		t.eq(chain(40), { 40, 24, 11, 4 })
		t.eq(chain(32), { 32, 19, 9, 4 })
		t.eq(chain(25), { 25, 15, 7, 3 })
		t.eq(chain(24), { 24, 16, 9, 5 })
		t.eq(chain(8), { 8, 5, 3 })
		-- startCount 없이 부르면 예전 비율 (호환)
		t.eq(Rules.qualifyCount(40, 4, 1), 26)
		t.eq(Rules.passRatios(4, 40), Config.Rules.LargePassRatios)
		t.eq(Rules.passRatios(4, 24), Config.Rules.PassRatios[4])
		t.eq(Rules.passRatios(3, 40), Config.Rules.PassRatios[3])
		-- 결승은 항상 1명
		t.eq(Rules.qualifyCount(4, 4, 4, 40), 1)
	end)

	t.test(
		"roundCounts: Race는 목표만큼, Survival은 시간 종료면 그대로 넘어갈 수 있어요(upper)",
		function()
			local expected, upper = Rules.roundCounts(40, { "Race", "Survival", "Race", "Final" })
			t.eq(expected, { 40, 24, 11, 4 })
			t.eq(upper, { 40, 24, 24, 10 }) -- 3라운드 Race: 24 × 0.40 = 9.6 → 10
			local e2, u2 = Rules.roundCounts(24, { "Race", "Race", "Survival", "Final" })
			t.eq(e2, { 24, 16, 9, 5 })
			t.eq(u2, { 24, 16, 9, 9 })
		end
	)

	t.test("fitsCount: 스폰이 모자라면 안 되고, 대형 맵은 예상 12명 이상", function()
		local big = { id = "b", kind = "Race", capacity = 40, minPlayers = 12 }
		local small = { id = "s", kind = "Race" }
		t.eq(Rules.capacityOf(small), 24)
		t.ok(Rules.fitsCount(big, 40, 40))
		t.ok(Rules.fitsCount(big, 24, 12))
		t.ok(not Rules.fitsCount(big, 11, 11), "too few for a large map")
		t.ok(not Rules.fitsCount(small, 25, 25), "not enough spawns")
		t.ok(Rules.fitsCount(small, 24, 24))
	end)

	t.test(
		"buildRoundPlan: 25~40명이면 1라운드는 항상 대형 Race, 모든 라운드 스폰이 넉넉해요",
		function()
			for _, start in { 25, 32, 40 } do
				for seed = 1, 200 do
					local plan = Rules.buildRoundPlan(4, pool(true), fakeRng(seed), start)
					t.eq(#plan, 4)
					t.eq(plan[1].kind, "Race")
					t.eq(plan[1].capacity, 40, `start {start} seed {seed}: round 1 must be large`)
					t.eq(plan[4].kind, "Final")
					local kinds = {}
					local seen = {}
					for i, map in plan do
						kinds[i] = map.kind
						t.ok(not seen[map.id], `duplicate {map.id}`)
						seen[map.id] = true
					end
					local _, upper = Rules.roundCounts(start, kinds)
					for i, map in plan do
						t.ok(Rules.capacityOf(map) >= upper[i], `start {start} seed {seed} round {i} {map.id}`)
					end
				end
			end
		end
	)

	t.test(
		"buildRoundPlan: 작은 방(예상 12명 미만)에는 대형 맵이 안 나오고, 24명 방 1라운드에는 나올 수 있어요",
		function()
			for seed = 1, 300 do
				for _, start in { 4, 8, 11 } do
					for _, map in Rules.buildRoundPlan(Rules.roundCount(start), pool(true), fakeRng(seed), start) do
						t.eq(map.capacity, nil, `start {start} seed {seed} got {map.id}`)
					end
				end
			end
			local bigFirst = 0
			local bigLater = 0
			for seed = 1, 300 do
				local plan = Rules.buildRoundPlan(4, pool(true), fakeRng(seed), 24)
				if plan[1].capacity == 40 then
					bigFirst += 1
				end
				for i = 2, 4 do
					if plan[i].capacity == 40 then
						bigLater += 1
					end
				end
			end
			t.ok(bigFirst > 0, "large Race appears in round 1 of a 24 room")
			t.ok(bigLater > 0, "large maps also appear in round 2 (16 expected)")
		end
	)

	t.test(
		"buildRoundPlan: 대형 맵이 없는 풀이면 예전처럼 골라요(스폰은 RoundService가 돌려 써요)",
		function()
			local plan = Rules.buildRoundPlan(4, pool(false), fakeRng(7), 40)
			t.eq(#plan, 4)
			t.eq(plan[1].kind, "Race")
			t.eq(plan[4].kind, "Final")
			-- startCount 없이 부르면 인원을 보지 않아요 (예전 호출)
			local old = Rules.buildRoundPlan(4, pool(true), fakeRng(3))
			t.eq(#old, 4)
		end
	)

	t.test("MapTypes: capacity·minPlayers는 양의 정수, minPlayers ≤ capacity", function()
		local function base(extra: { [string]: any }): any
			local m: any = {
				id = "x",
				kind = "Race",
				displayName = "x",
				rule = "x",
				build = function() end,
				start = function() end,
			}
			for k, v in extra do
				m[k] = v
			end
			return m
		end
		t.eq(MapTypes.validate(base({})), nil)
		t.eq(MapTypes.validate(base({ capacity = 40, minPlayers = 12 })), nil)
		t.ok(MapTypes.validate(base({ capacity = 0 })) ~= nil)
		t.ok(MapTypes.validate(base({ capacity = 40.5 })) ~= nil)
		t.ok(MapTypes.validate(base({ minPlayers = "12" })) ~= nil)
		t.ok(MapTypes.validate(base({ minPlayers = 30 })) ~= nil, "minPlayers above the default 24")
		t.ok(MapTypes.validate(base({ capacity = 40, minPlayers = 41 })) ~= nil)
	end)

	t.test("Maps: 풀 정보에 capacity·minPlayers가 실려요, 기존 맵은 비어 있음(24)", function()
		for _, info in Maps.allInfos() do
			local map = Maps.get(info.id)
			t.eq(info.capacity, map.capacity)
			t.eq(info.minPlayers, map.minPlayers)
			t.ok(Rules.capacityOf(info) == 24 or Rules.capacityOf(info) == 40, info.id)
		end
	end)

	t.test(
		"MapKitLogic: Large 예산 (Extended보다 크고 2배를 넘지 않아요), 런타임 경고는 Large 기준",
		function()
			local large = MapKitLogic.budget("Large")
			local extended = MapKitLogic.budget("Extended")
			t.eq(large, { parts = 2200, particles = 20, lights = 32, shadowedLights = 2, anim = 120 })
			for key, value in large do
				t.ok(value >= (extended :: any)[key] and value <= 2 * (extended :: any)[key], key)
			end
			local kit = fs.readFile("src/shared/maps/MapKit.luau")
			t.ok(string.find(kit, 'MapKitLogic.checkBudget(specs, "Large")', 1, true) ~= nil)
		end
	)

	t.test("MatchService: 판 계획·통과 인원에 시작 인원을 넘겨요", function()
		local match = fs.readFile("src/server/MatchService.luau")
		t.ok(
			string.find(match, "Rules.buildRoundPlan, roundCount, Maps.infos(), Random.new(), startCount", 1, true)
				~= nil
		)
		t.ok(
			string.find(match, "Rules.qualifyCount(aliveCount(ctx), roundCount, roundIndex, startCount)", 1, true)
				~= nil
		)
	end)
end
