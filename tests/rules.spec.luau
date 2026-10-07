--!strict
-- Shared.Rules: 라운드 수, 통과 인원, 결승 건너뛰기, 라운드 구성 (GDD 3.3, 4.1, 5.1)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Rules = RobloxRequire.require(Shared.Rules)

-- 시드 고정 rng (Random:NextInteger와 같은 모양)
local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

-- 한 판 전체를 돌려서 라운드마다 남은 인원을 기록해요. 건너뛴 라운드는 기록하지 않아요.
local function simulate(startCount: number): { number }
	local roundCount = Rules.roundCount(startCount)
	local counts = { startCount }
	local alive = startCount
	local round: number? = 1
	while round do
		alive = Rules.qualifyCount(alive, roundCount, round)
		table.insert(counts, alive)
		round = Rules.nextRound(round, roundCount, alive)
	end
	return counts
end

local GDD_POOL = {
	{ id = "RotatingBelt", kind = "Race" },
	{ id = "SoySwamp", kind = "Race" },
	{ id = "RamenRapids", kind = "Race" },
	{ id = "ChefBoard", kind = "Survival" },
	{ id = "HotPlate", kind = "Survival" },
	{ id = "SkewerBridge", kind = "Final" },
}

return function(t: Test.Test)
	t.test("roundCount: 4~8명은 3라운드, 9~24명은 4라운드", function()
		for n = 4, 8 do
			t.eq(Rules.roundCount(n), 3, `start {n}`)
		end
		for n = 9, 24 do
			t.eq(Rules.roundCount(n), 4, `start {n}`)
		end
	end)

	t.test("GDD 4.1 예시: 24명 → 16 → 9 → 5 → 1", function()
		t.eq(simulate(24), { 24, 16, 9, 5, 1 })
	end)

	t.test("GDD 4.1 예시: 8명 → 5 → 3 → 1", function()
		t.eq(simulate(8), { 8, 5, 3, 1 })
	end)

	t.test("GDD 4.1 예시: 4명 → 2 → (R2 생략) 결승 → 1", function()
		t.eq(simulate(4), { 4, 2, 1 })
	end)

	t.test("결승 전 라운드는 최소 2명 통과, 최소 1명 탈락", function()
		for n = 4, 24 do
			local roundCount = Rules.roundCount(n)
			for round = 1, roundCount - 1 do
				for alive = 3, n do
					local q = Rules.qualifyCount(alive, roundCount, round)
					t.ok(q >= 2 and q <= alive - 1, `alive {alive}, round {round}/{roundCount}: {q}`)
				end
			end
		end
	end)

	t.test("결승은 항상 1명", function()
		t.eq(Rules.qualifyCount(5, 3, 3), 1)
		t.eq(Rules.qualifyCount(2, 4, 4), 1)
	end)

	t.test("모든 시작 인원에서 라운드 수 안에 우승자 1명으로 끝나요", function()
		for n = 4, 24 do
			local counts = simulate(n)
			t.eq(counts[#counts], 1, `start {n}`)
			t.ok(#counts - 1 <= Rules.roundCount(n), `start {n} played {#counts - 1} rounds`)
		end
	end)

	t.test("nextRound: 2명 이하면 결승으로, 결승 뒤에는 nil", function()
		t.eq(Rules.nextRound(1, 4, 5), 2)
		t.eq(Rules.nextRound(1, 3, 2), 3)
		t.eq(Rules.nextRound(2, 4, 2), 4)
		t.eq(Rules.nextRound(3, 3, 1), nil)
	end)

	t.test("비율이 없는 라운드 수는 에러", function()
		t.throws(function()
			Rules.qualifyCount(10, 5, 1)
		end)
	end)

	t.test("buildRoundPlan: 첫 Race, 끝 Final, 중복 없음, 4라운드면 Survival 1번 이상", function()
		for _, roundCount in { 3, 4 } do
			for seed = 1, 500 do
				local plan = Rules.buildRoundPlan(roundCount, GDD_POOL, fakeRng(seed))
				t.eq(#plan, roundCount)
				t.eq(plan[1].kind, "Race", `seed {seed} first`)
				t.eq(plan[roundCount].kind, "Final", `seed {seed} last`)
				local seen = {}
				local survivals = 0
				for i, map in plan do
					t.ok(not seen[map.id], `seed {seed}: {map.id} repeated`)
					seen[map.id] = true
					if i > 1 and i < roundCount then
						t.ok(map.kind == "Race" or map.kind == "Survival", `seed {seed}: middle {map.kind}`)
					end
					if map.kind == "Survival" then
						survivals += 1
					end
				end
				if roundCount == 4 then
					t.ok(survivals >= 1, `seed {seed}: no Survival`)
				end
			end
		end
	end)

	t.test("buildRoundPlan: 3라운드 가운데는 Race와 Survival이 둘 다 나와요", function()
		local kinds = {}
		for seed = 1, 100 do
			kinds[Rules.buildRoundPlan(3, GDD_POOL, fakeRng(seed))[2].kind] = true
		end
		t.ok(kinds.Race and kinds.Survival)
	end)

	t.test("buildRoundPlan: 맵이 모자라면 있는 맵으로 채워요 (개발 초기)", function()
		local pool = { { id = "RotatingBelt", kind = "Race" } }
		for _, roundCount in { 3, 4 } do
			local plan = Rules.buildRoundPlan(roundCount, pool, fakeRng(7))
			t.eq(#plan, roundCount)
			for _, map in plan do
				t.eq(map.id, "RotatingBelt")
			end
		end
	end)

	t.test("buildRoundPlan: 맵 풀이 비면 에러", function()
		t.throws(function()
			Rules.buildRoundPlan(3, {}, fakeRng(1))
		end)
	end)
	-- m2-01: 종류별 맵 개수를 넘지 않는 라운드 구성, 디버그 강제 플랜 ------------------

	local M2_POOL = {
		{ id = "rotating-belt", kind = "Race" },
		{ id = "soy-swamp", kind = "Race" },
		{ id = "hot-plate", kind = "Survival" },
		{ id = "skewer-showdown", kind = "Final" },
	}

	local function countKinds(plan: { Rules.MapInfo }): { [string]: number }
		local counts = {}
		for _, map in plan do
			counts[map.kind] = (counts[map.kind] or 0) + 1
		end
		return counts
	end

	local function hasDuplicate(plan: { Rules.MapInfo }): boolean
		local seen = {}
		for _, map in plan do
			if seen[map.id] then
				return true
			end
			seen[map.id] = true
		end
		return false
	end

	t.test(
		"m2-01 AC1: Race 2·Survival 1·Final 1 풀의 4라운드는 Race 첫·Final 끝·중복 0·Survival 1·Race 2",
		function()
			for seed = 1, 500 do
				local plan = Rules.buildRoundPlan(4, M2_POOL, fakeRng(seed))
				t.eq(#plan, 4, `seed {seed}`)
				t.eq(plan[1].kind, "Race", `seed {seed} first`)
				t.eq(plan[4].kind, "Final", `seed {seed} last`)
				t.ok(not hasDuplicate(plan), `seed {seed} duplicate`)
				local counts = countKinds(plan)
				t.eq(counts.Survival, 1, `seed {seed} survival`)
				t.eq(counts.Race, 2, `seed {seed} race`)
			end
		end
	)

	t.test(
		"m2-01 AC2: 같은 풀의 3라운드는 중복 0, 가운데가 Race인 판과 Survival인 판이 둘 다 나와요",
		function()
			local middle = {}
			for seed = 1, 500 do
				local plan = Rules.buildRoundPlan(3, M2_POOL, fakeRng(seed))
				t.ok(not hasDuplicate(plan), `seed {seed} duplicate`)
				t.eq(plan[1].kind, "Race", `seed {seed} first`)
				t.eq(plan[3].kind, "Final", `seed {seed} last`)
				middle[plan[2].kind] = true
			end
			t.ok(middle.Race, "middle Race never chosen")
			t.ok(middle.Survival, "middle Survival never chosen")
		end
	)

	t.test(
		"m2-01 AC3: 같은 풀의 4라운드에서 Survival이 2라운드인 판과 3라운드인 판이 둘 다 나와요",
		function()
			local survivalAt = {}
			for seed = 1, 500 do
				local plan = Rules.buildRoundPlan(4, M2_POOL, fakeRng(seed))
				for i, map in plan do
					if map.kind == "Survival" then
						survivalAt[i] = true
					end
				end
			end
			t.ok(survivalAt[2], "survival never in round 2")
			t.ok(survivalAt[3], "survival never in round 3")
		end
	)

	t.test("m2-01 roundKinds: 개수를 주면 종류별 개수를 넘지 않아요", function()
		for seed = 1, 200 do
			local kinds = Rules.roundKinds(4, fakeRng(seed), { Race = 3, Survival = 1, Final = 1 })
			local survival = 0
			for _, kind in kinds do
				if kind == "Survival" then
					survival += 1
				end
			end
			t.eq(survival, 1, `seed {seed}`)
		end
	end)

	t.test("m2-01 roundKinds: 개수가 모자라면 개수를 보지 않고 골라요 (fallback)", function()
		-- Survival 0개, 4라운드: GDD 규칙상 Survival 칸은 있어야 해서 개수를 넘겨요
		local kinds = Rules.roundKinds(4, fakeRng(3), { Race = 1, Final = 1 })
		local survival = 0
		for _, kind in kinds do
			if kind == "Survival" then
				survival += 1
			end
		end
		t.ok(survival >= 1, "4 rounds still need a Survival kind")
		t.eq(kinds[1], "Race")
		t.eq(kinds[4], "Final")
	end)

	t.test("m2-01 AC5: resolveForcedPlan은 그 순서의 MapInfo를 돌려줘요", function()
		local plan, problem = Rules.resolveForcedPlan({ "soy-swamp", "hot-plate", "skewer-showdown" }, M2_POOL)
		t.eq(problem, nil)
		t.eq(plan, {
			{ id = "soy-swamp", kind = "Race" },
			{ id = "hot-plate", kind = "Survival" },
			{ id = "skewer-showdown", kind = "Final" },
		})
		local four = Rules.resolveForcedPlan({ "hot-plate", "rotating-belt", "soy-swamp", "skewer-showdown" }, M2_POOL)
		t.eq(#(four :: { any }), 4)
		t.eq((four :: { any })[1].id, "hot-plate")
	end)

	t.test("m2-01 AC5: resolveForcedPlan은 길이 2·5, 모르는 id, 목록이 아닌 값을 거절해요", function()
		local cases: { any } = {
			{ "soy-swamp", "skewer-showdown" },
			{ "soy-swamp", "hot-plate", "rotating-belt", "soy-swamp", "skewer-showdown" },
			{ "soy-swamp", "no-such-map", "skewer-showdown" },
			{ "soy-swamp", 3, "skewer-showdown" },
			{},
			"soy-swamp",
		}
		for i, ids in cases do
			local plan, problem = Rules.resolveForcedPlan(ids, M2_POOL)
			t.eq(plan, nil, `case {i}`)
			t.ok(type(problem) == "string" and #problem > 0, `case {i} reason`)
		end
	end)
end
