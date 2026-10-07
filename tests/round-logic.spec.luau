--!strict
-- m2-05 라운드 판정·매치 순위 순수 로직 (src/shared/RoundLogic.luau)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Rules = RobloxRequire.require(Shared.Rules)

type Outcome = { userId: number, result: string, place: number? }

local function scores(map: { [number]: number }): (number) -> number
	return function(id: number): number
		return map[id] or -math.huge
	end
end

local noScore = function(_id: number): number
	return 0
end

local function standingsFor(count: number)
	local entries = {}
	for i = 1, count do
		table.insert(entries, { userId = i, name = `P{i}` })
	end
	return RoundLogic.newStandings(entries)
end

-- 결과를 userId → "Result:place"로
local function summary(outcomes: { Outcome }): { [number]: string }
	local out = {}
	for _, o in outcomes do
		out[o.userId] = `{o.result}:{o.place}`
	end
	return out
end

local function concat(a: { Outcome }, b: { Outcome }): { Outcome }
	local out = table.clone(a)
	for _, o in b do
		table.insert(out, o)
	end
	return out
end

-- 시드 고정 가짜 rng (동점 무작위용)
local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_self: any, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

return function(t: Test.Test)
	t.test(
		"m2-05 AC1: Race 목표 2, 2명째 통과 → 종료, 남은 3명은 진행도 큰 순으로 3·4·5등",
		function()
			local st = standingsFor(5)
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(round, 2)
			local progress = scores({ [3] = 10, [4] = 30, [5] = 20 })
			local first = RoundLogic.applyOutcomes(st, RoundLogic.pass(round, 1, progress))
			t.eq(summary(first), { [1] = "Passed:1" })
			t.ok(not round.ended, "1명 통과로는 안 끝나요")
			local second = RoundLogic.applyOutcomes(st, RoundLogic.pass(round, 2, progress))
			t.ok(round.ended, "2명째 통과로 종료")
			t.eq(
				summary(second),
				{ [2] = "Passed:2", [4] = "Eliminated:3", [5] = "Eliminated:4", [3] = "Eliminated:5" }
			)
		end
	)

	t.test(
		"m2-05 AC2: Race 시간 종료, 목표 3, 통과 1, 남은 4명 → 진행도 상위 2명 통과, 2명 진행도 순 탈락",
		function()
			local st = standingsFor(5)
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(round, 3)
			RoundLogic.applyOutcomes(st, RoundLogic.pass(round, 1, noScore))
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.timeout(round, scores({ [2] = 5, [3] = 40, [4] = 25, [5] = 1 }))
			)
			t.eq(summary(out), { [3] = "Passed:2", [4] = "Passed:3", [2] = "Eliminated:4", [5] = "Eliminated:5" })
			t.ok(round.ended)
		end
	)

	t.test("m2-05 AC3: Survival 목표 3, 남은 인원이 3이 되는 순간 종료, 3명 전원 통과", function()
		local st = standingsFor(5)
		local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
		RoundLogic.activate(round, 3)
		local a = RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 1, score = 0 } }, noScore))
		t.eq(summary(a), { [1] = "Eliminated:5" })
		t.ok(not round.ended)
		local b = RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 2, score = 0 } }, noScore))
		t.ok(round.ended, "3명 남으면 종료")
		t.eq(summary(b), { [2] = "Eliminated:4", [3] = "Passed:1", [4] = "Passed:2", [5] = "Passed:3" })
	end)

	t.test("m2-05 AC4: Survival 시간 종료, 목표 3, 남은 5명 → 5명 전원 통과, 탈락 0", function()
		local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
		RoundLogic.activate(round, 3)
		local out = RoundLogic.timeout(round, noScore)
		t.eq(#out, 5)
		for _, o in out do
			t.eq(o.result, "Passed")
		end
	end)

	t.test(
		"m2-05 AC4: Survival 혼자(목표 2) → 시작해도 안 끝나고, 시간 종료에 1명 통과",
		function()
			local round = RoundLogic.newRound("Survival", { 7 })
			RoundLogic.activate(round, 2)
			t.ok(not round.ended)
			t.eq(summary(RoundLogic.timeout(round, noScore)), { [7] = "Passed:1" })
		end
	)

	t.test(
		"m2-05 AC5: 결승 4명 중 한 명씩 3명 탈락 → 3번째에 종료, 남은 1명 우승, 2·3·4등",
		function()
			local st = standingsFor(4)
			local round = RoundLogic.newRound("Final", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 1)
			local all = {}
			for _, id in { 2, 4 } do
				all = concat(
					all,
					RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = id, score = 0 } }, noScore))
				)
				t.ok(not round.ended)
			end
			all = concat(
				all,
				RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 1, score = 0 } }, noScore))
			)
			t.ok(round.ended, "1명 남는 순간 종료")
			t.eq(summary(all), { [2] = "Eliminated:4", [4] = "Eliminated:3", [1] = "Eliminated:2", [3] = "Won:1" })
		end
	)

	t.test("m2-05 AC6: 결승 남은 2명이 같은 틱에 탈락(A=12, B=5) → A 우승, B 2등", function()
		local st = standingsFor(4)
		local round = RoundLogic.newRound("Final", { 1, 2, 3, 4 })
		RoundLogic.activate(round, 1)
		RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 3, score = 0 } }, noScore))
		RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 4, score = 0 } }, noScore))
		local out = RoundLogic.applyOutcomes(
			st,
			RoundLogic.eliminate(round, { { userId = 2, score = 5 }, { userId = 1, score = 12 } }, noScore)
		)
		t.eq(summary(out), { [1] = "Won:1", [2] = "Eliminated:2" })
		t.ok(round.ended)
	end)

	t.test("m2-05 AC6: 결승 남은 3명이 같은 틱에 탈락 → 높이 순 1·2·3등", function()
		local st = standingsFor(3)
		local round = RoundLogic.newRound("Final", { 1, 2, 3 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.applyOutcomes(
			st,
			RoundLogic.eliminate(round, {
				{ userId = 1, score = 3 },
				{ userId = 2, score = 20 },
				{ userId = 3, score = 7 },
			}, noScore)
		)
		t.eq(summary(out), { [2] = "Won:1", [3] = "Eliminated:2", [1] = "Eliminated:3" })
	end)

	t.test("m2-05 AC6: 높이까지 같으면 무작위지만 우승자는 정확히 1명", function()
		local winners: { [number]: boolean } = {}
		for seed = 1, 50 do
			local st = standingsFor(2)
			local round = RoundLogic.newRound("Final", { 1, 2 }, fakeRng(seed))
			RoundLogic.activate(round, 1)
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(round, { { userId = 1, score = 4 }, { userId = 2, score = 4 } }, noScore)
			)
			local won = 0
			for _, o in out do
				if o.result == "Won" then
					won += 1
					winners[o.userId] = true
				end
			end
			t.eq(won, 1)
		end
		t.ok(winners[1] and winners[2], "시드에 따라 둘 다 우승할 수 있어요")
	end)

	t.test("m2-05 AC7: 결승 시간 종료, 남은 3명(높이 4, 9, 1) → 9 우승, 4 2등, 1 3등", function()
		local st = standingsFor(3)
		local round = RoundLogic.newRound("Final", { 1, 2, 3 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.applyOutcomes(st, RoundLogic.timeout(round, scores({ [1] = 4, [2] = 9, [3] = 1 })))
		t.eq(summary(out), { [2] = "Won:1", [1] = "Eliminated:2", [3] = "Eliminated:3" })
	end)

	t.test("m2-05 AC8: 결승 혼자 시작 → 떨어지면 우승", function()
		local st = standingsFor(1)
		local round = RoundLogic.newRound("Final", { 1 })
		RoundLogic.activate(round, 1)
		t.ok(not round.ended, "혼자라고 시작하자마자 끝나지 않아요")
		local out = RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 1, score = -50 } }, noScore))
		t.eq(summary(out), { [1] = "Won:1" })
	end)

	t.test("m2-05 AC8: 결승 혼자 시작 → 시간 종료에 우승", function()
		local st = standingsFor(1)
		local round = RoundLogic.newRound("Final", { 1 })
		RoundLogic.activate(round, 1)
		t.eq(summary(RoundLogic.applyOutcomes(st, RoundLogic.timeout(round, noScore))), { [1] = "Won:1" })
	end)

	t.test(
		"m2-05: 결승에서 맵이 pass를 부르면(fallback) 첫 통과자 우승, 나머지 진행도 순 탈락",
		function()
			local st = standingsFor(3)
			local round = RoundLogic.newRound("Final", { 1, 2, 3 })
			RoundLogic.activate(round, 1)
			local out = RoundLogic.applyOutcomes(st, RoundLogic.pass(round, 3, scores({ [1] = 10, [2] = 50 })))
			t.eq(summary(out), { [3] = "Won:1", [2] = "Eliminated:2", [1] = "Eliminated:3" })
		end
	)

	t.test(
		"m2-05: 소개 중(activate 전) 탈락은 종료 판정 없이 처리되고, 결과 뒤 pass/timeout은 무시",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2, 3 })
			RoundLogic.eliminate(round, { { userId = 1, score = 0 }, { userId = 2, score = 0 } }, noScore)
			t.ok(not round.ended, "목표가 없으니 안 끝나요")
			t.eq(RoundLogic.racers(round), { 3 })
			RoundLogic.activate(round, 1)
			RoundLogic.pass(round, 3, noScore)
			t.ok(round.ended)
			t.eq(#RoundLogic.timeout(round, noScore), 0)
			t.eq(#RoundLogic.eliminate(round, { { userId = 3, score = 0 } }, noScore), 0)
		end
	)

	t.test("m2-05: 결승 소개 중 2명 중 1명이 나가면 남은 사람이 우승", function()
		local st = standingsFor(2)
		local round = RoundLogic.newRound("Final", { 1, 2 })
		local out =
			RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 1, score = -math.huge } }, noScore))
		t.eq(summary(out), { [1] = "Eliminated:2", [2] = "Won:1" })
	end)

	t.test("m2-05: 같은 사람이 묶음에 두 번 들어와도 한 번만 탈락", function()
		local round = RoundLogic.newRound("Race", { 1, 2, 3 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, { { userId = 1, score = 0 }, { userId = 1, score = 0 } }, noScore)
		t.eq(#out, 1)
	end)

	t.test("m2-05: 모드 결정 — 마지막 라운드면 맵 종류와 상관없이 Final", function()
		t.eq(RoundLogic.modeFor("Race", true), "Final")
		t.eq(RoundLogic.modeFor("Survival", true), "Final")
		t.eq(RoundLogic.modeFor("Race", false), "Race")
		t.eq(RoundLogic.modeFor("Survival", false), "Survival")
		t.eq(RoundLogic.modeFor("Final", false), "Survival")
	end)

	t.test(
		"m2-05 AC9: 8명 매치(R1 Race 3 탈락 → R2 Survival 2 탈락 → 결승 3명) 순위표 1~8 빠짐없이",
		function()
			local ids = { 1, 2, 3, 4, 5, 6, 7, 8 }
			local st = standingsFor(8)
			local received: { [number]: number } = {}
			local function record(outcomes: { Outcome })
				for _, o in RoundLogic.applyOutcomes(st, outcomes) do
					if o.result ~= "Passed" then
						received[o.userId] = o.place :: number
					end
				end
			end

			-- R1 Race: 목표 = qualifyCount(8, 3, 1) = 5
			local target1 = Rules.qualifyCount(8, 3, 1)
			t.eq(target1, 5)
			local r1 = RoundLogic.newRound("Race", ids)
			RoundLogic.activate(r1, target1)
			for _, id in { 1, 2, 3, 4, 5 } do
				record(RoundLogic.pass(r1, id, scores({ [6] = 3, [7] = 2, [8] = 1 })))
			end
			t.ok(r1.ended)

			-- R2 Survival: 목표 = qualifyCount(5, 3, 2) = 3. 2번은 라운드 중 나가요 (나간 사람이 그 라운드 탈락자).
			local target2 = Rules.qualifyCount(5, 3, 2)
			t.eq(target2, 3)
			local r2 = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(r2, target2)
			record(RoundLogic.eliminate(r2, { { userId = 2, score = -math.huge } }, noScore))
			record(RoundLogic.eliminate(r2, { { userId = 5, score = 0 } }, noScore))
			t.ok(r2.ended)

			-- 결승 3명: 4 탈락 → 1 탈락 → 3 우승
			local r3 = RoundLogic.newRound("Final", { 1, 3, 4 })
			RoundLogic.activate(r3, 1)
			record(RoundLogic.eliminate(r3, { { userId = 4, score = 0 } }, noScore))
			record(RoundLogic.eliminate(r3, { { userId = 1, score = 0 } }, noScore))
			t.ok(r3.ended)

			local list = RoundLogic.standingsList(st)
			t.eq(#list, 8)
			for i, row in list do
				t.eq(row.place, i, "1~8등이 한 번씩")
				t.eq(received[row.userId], row.place, `P{row.userId}이 받은 등수와 순위표가 같아요`)
				t.eq(row.name, `P{row.userId}`)
			end
			t.eq(list[1].userId, 3)
			t.eq(RoundLogic.winnerOf(st), 3)
		end
	)

	t.test(
		"m2-05 AC9: 라운드 밖(결과 단계·통과 후)에서 나간 사람도 남은 가장 나쁜 등수를 받아 겹치지 않아요",
		function()
			local st = standingsFor(6)
			local r1 = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5, 6 })
			RoundLogic.activate(r1, 4)
			local placed = {}
			for _, o in RoundLogic.applyOutcomes(st, RoundLogic.pass(r1, 1, noScore)) do
				placed[o.userId] = o.place
			end
			-- 통과한 1번이 라운드 도중 나가요
			t.eq(RoundLogic.placeEliminated(st, 1), 6)
			for _, id in { 2, 3, 4 } do
				RoundLogic.applyOutcomes(st, RoundLogic.pass(r1, id, scores({ [5] = 2, [6] = 1 })))
			end
			t.eq(RoundLogic.placeOf(st, 6), 5)
			t.eq(RoundLogic.placeOf(st, 5), 4)
			-- 결과 단계에서 2번이 나가요
			t.eq(RoundLogic.placeEliminated(st, 2), 3)
			t.eq(RoundLogic.placeEliminated(st, 2), 3, "두 번 불러도 같은 등수")
			local final = RoundLogic.newRound("Final", { 3, 4 })
			RoundLogic.activate(final, 1)
			RoundLogic.applyOutcomes(st, RoundLogic.eliminate(final, { { userId = 4, score = 0 } }, noScore))
			local seen = {}
			for _, row in RoundLogic.standingsList(st) do
				t.ok(not seen[row.place], `등수 {row.place} 중복`)
				seen[row.place] = true
			end
			t.eq(RoundLogic.winnerOf(st), 3)
			t.eq(RoundLogic.placeOf(st, 4), 2)
		end
	)
end
