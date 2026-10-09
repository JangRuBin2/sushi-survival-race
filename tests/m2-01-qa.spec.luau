--!strict
-- m2-01 QA(docs/qa/m2-01-foundation.md)에서 추가한 테스트.
-- 1) 실제 맵 풀(Maps.infos())로 라운드 구성 규칙 확인 (m2-07 AC2를 미리)
-- 2) m2-01~m2-07 스펙의 Studio 절차에 적힌 forceMapPlan 목록이 전부 실제 풀에서 풀리는지 (스펙 간 계약)
-- 3) 종류별 개수 상한이 무작위 풀에서도 지켜지는지 (충분하면 중복 0)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
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

return function(t: Test.Test)
	t.test(
		"실제 맵 풀: 3·4라운드 구성 500판씩 — 첫 Race, 끝 Final, 중복 0, 4라운드 Survival 1번 이상",
		function()
			local pool = Maps.infos()
			for _, roundCount in { 3, 4 } do
				for seed = 1, 500 do
					local plan = Rules.buildRoundPlan(roundCount, pool, fakeRng(seed))
					t.eq(#plan, roundCount, `seed {seed}`)
					t.eq(plan[1].kind, "Race", `{roundCount} seed {seed} first`)
					t.eq(plan[roundCount].kind, "Final", `{roundCount} seed {seed} last`)
					t.ok(not hasDuplicate(plan), `{roundCount} seed {seed} duplicate`)
					local survival = 0
					for i = 2, roundCount - 1 do
						t.ok(plan[i].kind == "Race" or plan[i].kind == "Survival", `{roundCount} seed {seed} middle`)
						if plan[i].kind == "Survival" then
							survival += 1
						end
					end
					if roundCount == 4 then
						t.ok(survival >= 1, `seed {seed}: no Survival`)
					end
				end
			end
		end
	)

	t.test(
		"실제 맵 풀: 결승은 언제나 등록된 Final 맵 중 하나 (m5-18 tug-of-war-platform·m5-19 claw-machine-prize도 합류)",
		function()
			local finals = { ["skewer-showdown"] = true, ["tug-of-war-platform"] = true, ["claw-machine-prize"] = true }
			for seed = 1, 100 do
				for _, roundCount in { 3, 4 } do
					local plan = Rules.buildRoundPlan(roundCount, Maps.infos(), fakeRng(seed))
					t.ok(finals[plan[roundCount].id], `seed {seed}: {plan[roundCount].id}`)
				end
			end
		end
	)

	t.test(
		"스펙 계약: m2-01~07 Studio 절차의 forceMapPlan 목록이 전부 실제 풀에서 그 순서로 풀려요",
		function()
			local plans = {
				{ "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }, -- m2-01 AC9
				{ "soy-swamp", "rotating-belt", "skewer-showdown" }, -- m2-02
				{ "rotating-belt", "hot-plate", "skewer-showdown" }, -- m2-03
				{ "hot-plate", "rotating-belt", "skewer-showdown" }, -- m2-03 AC8, m2-05 AC14 (Survival이 1라운드)
				{ "rotating-belt", "soy-swamp", "skewer-showdown" }, -- m2-04
				{ "rotating-belt", "soy-swamp", "hot-plate", "skewer-showdown" }, -- m2-07 AC4
			}
			for i, ids in plans do
				local plan, problem = Rules.resolveForcedPlan(ids, Maps.infos())
				t.eq(problem, nil, `plan {i}`)
				t.ok(plan ~= nil and #plan == #ids, `plan {i} length`)
				for k, id in ids do
					t.eq((plan :: { Rules.MapInfo })[k].id, id, `plan {i} round {k}`)
				end
			end
		end
	)

	t.test("스펙 계약: m2-01 AC10 예시(no-such-map)는 거절돼요", function()
		local plan, problem = Rules.resolveForcedPlan({ "no-such-map", "hot-plate", "skewer-showdown" }, Maps.infos())
		t.eq(plan, nil)
		t.ok(type(problem) == "string" and string.find(problem :: string, "no-such-map", 1, true) ~= nil)
	end)

	t.test(
		"강제 플랜(결승 건너뛰기 없음)에서 나올 수 있는 인원 1~24 × 라운드 수 3·4 — qualifyCount가 에러 없이 1 이상",
		function()
			for _, roundCount in { 3, 4 } do
				for round = 1, roundCount do
					for alive = 1, 24 do
						local ok, q = pcall(Rules.qualifyCount, alive, roundCount, round)
						t.ok(ok and type(q) == "number" and q >= 1, `{round}/{roundCount} alive {alive}`)
					end
				end
			end
		end
	)

	t.test("무작위 풀 2000개: 개수가 충분하면 중복 0, 종류 규칙은 항상 지켜요", function()
		local rngSeed = fakeRng(99)
		for case = 1, 2000 do
			local race = rngSeed:NextInteger(0, 3)
			local survival = rngSeed:NextInteger(0, 3)
			local final = rngSeed:NextInteger(0, 2)
			if race + survival + final == 0 then
				continue
			end
			local pool = {}
			for i = 1, race do
				table.insert(pool, { id = `r{i}`, kind = "Race" })
			end
			for i = 1, survival do
				table.insert(pool, { id = `s{i}`, kind = "Survival" })
			end
			for i = 1, final do
				table.insert(pool, { id = `f{i}`, kind = "Final" })
			end
			for _, roundCount in { 3, 4 } do
				local middle = roundCount - 2
				local enough = race >= 1
					and final >= 1
					and (race - 1) + survival >= middle
					and (roundCount < 4 or survival >= 1)
				local plan = Rules.buildRoundPlan(roundCount, pool, fakeRng(case))
				t.eq(#plan, roundCount, `case {case}`)
				if enough then
					t.ok(not hasDuplicate(plan), `case {case} R{race}S{survival}F{final} x{roundCount}: duplicate`)
					t.eq(plan[1].kind, "Race", `case {case} first`)
					t.eq(plan[roundCount].kind, "Final", `case {case} last`)
					if roundCount == 4 then
						local s = 0
						for _, m in plan do
							if m.kind == "Survival" then
								s += 1
							end
						end
						t.ok(s >= 1, `case {case}: no Survival`)
					end
				end
			end
		end
	end)
end
