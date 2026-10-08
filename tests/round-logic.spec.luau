--!strict
-- m2-05 라운드 판정·매치 순위 순수 로직 (src/shared/RoundLogic.luau)

local fs = require("@lune/fs")
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
	-- m2-07: 결승 진출 2명 보장 (m2-05 QA F1) -------------------------------------

	t.test(
		"m2-07 AC11: Race 목표 2, 4명이 차례로 떨어지면 1·2번째는 4·3등 탈락, 3·4번째는 구제 통과",
		function()
			local st = standingsFor(4)
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 2)
			local got: { [number]: string } = {}
			for _, id in { 1, 2, 3, 4 } do
				local out =
					RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = id, score = 0 } }, noScore))
				for k, v in summary(out) do
					got[k] = v
				end
			end
			t.eq(got, { [1] = "Eliminated:4", [2] = "Eliminated:3", [3] = "Passed:1", [4] = "Passed:2" })
			t.ok(round.ended, "구제된 2명이 다 통과하면 라운드가 끝나요")
			-- 다음은 결승, 아직 아무도 Won을 받지 않았어요
			t.eq(Rules.nextRound(1, 3, 2), 3)
			t.eq(RoundLogic.winnerOf(st), nil)
			local winner, needsWon = RoundLogic.decideWinner(st, { 3, 4 })
			t.eq(winner, nil)
			t.eq(needsWon, false)
		end
	)

	t.test(
		"m2-07 AC11: Race에서 같은 틱에 3명이 떨어지면 더 멀리 간 사람부터 구제해요",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 2)
			RoundLogic.eliminate(round, { { userId = 4, score = 0 } }, noScore)
			local out = RoundLogic.eliminate(round, {
				{ userId = 1, score = 5 },
				{ userId = 2, score = 30 },
				{ userId = 3, score = 20 },
			}, noScore)
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Passed:1", [3] = "Passed:2" })
			t.ok(round.ended)
		end
	)

	t.test(
		"m2-07 AC12: Survival 목표 3, 2명 탈락 뒤 남은 3명이 같은 틱에 떨어지면 높이 10·7 구제, 2 탈락",
		function()
			local st = standingsFor(5)
			local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
			-- 소개 중 2명 탈락 (종료 판정은 출발 뒤부터)
			RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 4, score = 0 } }, noScore))
			RoundLogic.applyOutcomes(st, RoundLogic.eliminate(round, { { userId = 5, score = 0 } }, noScore))
			RoundLogic.activate(round, 3)
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(round, {
					{ userId = 1, score = 2 },
					{ userId = 2, score = 10 },
					{ userId = 3, score = 7 },
				}, noScore)
			)
			t.eq(summary(out), { [1] = "Eliminated:3", [2] = "Passed:1", [3] = "Passed:2" })
			t.ok(round.ended)
			t.eq(Rules.nextRound(1, 3, 2), 3, "다음은 결승 (남은 2명)")
			t.eq(RoundLogic.winnerOf(st), nil)
		end
	)

	t.test(
		"m2-07 AC13: 결승 전 라운드에서 4명 중 3명 리셋 → 구제 없이 탈락, 3번째 리셋 순간 종료, 남은 1명 부전승 Won",
		function()
			local st = standingsFor(4)
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 2)
			local wonCount = 0
			local alive = { [1] = true, [2] = true, [3] = true, [4] = true }
			local function record(outcomes)
				for _, o in RoundLogic.applyOutcomes(st, outcomes) do
					if o.result == "Won" then
						wonCount += 1
					elseif o.result == "Eliminated" then
						alive[o.userId] = nil
					end
				end
			end
			for _, id in { 1, 2, 3 } do
				record(RoundLogic.eliminate(round, { { userId = id, score = -math.huge, cause = "Reset" } }, noScore))
			end
			t.eq(RoundLogic.placeOf(st, 1), 4)
			t.eq(RoundLogic.placeOf(st, 2), 3)
			t.eq(RoundLogic.placeOf(st, 3), 2)
			t.ok(round.ended, "결승선·시간 종료를 기다리지 않고 바로 끝나요")
			t.ok(not RoundLogic.isRacing(round, 4))
			t.eq(
				#RoundLogic.timeout(round, noScore),
				0,
				"이미 끝난 라운드라 시간 종료는 아무 일도 안 해요"
			)
			t.eq(wonCount, 0, "라운드 안에서는 Won이 나가지 않아요")

			local aliveIds = {}
			for id in alive do
				table.insert(aliveIds, id)
			end
			t.eq(aliveIds, { 4 })
			local winner, needsWon = RoundLogic.decideWinner(st, aliveIds)
			t.eq(winner, 4)
			t.eq(needsWon, true, "MatchService가 Won을 보내야 해요")
			wonCount += 1
			t.eq(RoundLogic.winnerOf(st), 4, "Victory 우승자 = Won 받은 사람")
			t.eq(RoundLogic.placeOf(st, 4), 1)
			-- 다시 물어도 Won을 또 보내지 않아요 (매치에서 Won은 한 번)
			local again, needsAgain = RoundLogic.decideWinner(st, aliveIds)
			t.eq(again, 4)
			t.eq(needsAgain, false)
			t.eq(wonCount, 1)
		end
	)

	t.test("m2-07: 리셋과 낙하가 한 묶음이면 낙하만 구제해요", function()
		local round = RoundLogic.newRound("Race", { 1, 2, 3 })
		RoundLogic.activate(round, 2)
		local out = RoundLogic.eliminate(round, {
			{ userId = 1, score = 50, cause = "Reset" },
			{ userId = 2, score = 10, cause = "Fall" },
			{ userId = 3, score = 1, cause = "Fall" },
		}, noScore)
		t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Passed:1", [3] = "Passed:2" })
	end)

	t.test("m2-07: 전원 리셋이면 우승자 없음 — 탈락 1등이 우승자로 나오지 않아요", function()
		local st = standingsFor(3)
		local round = RoundLogic.newRound("Survival", { 1, 2, 3 })
		RoundLogic.activate(round, 2)
		for _, id in { 1, 2, 3 } do
			RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(round, { { userId = id, score = 0, cause = "Reset" } }, noScore)
			)
		end
		t.eq(RoundLogic.winnerOf(st), nil)
		local winner, needsWon = RoundLogic.decideWinner(st, {})
		t.eq(winner, nil)
		t.eq(needsWon, false)
	end)

	t.test("m2-07: 결승의 우승(Won)은 그대로 우승자로 기록돼요", function()
		local st = standingsFor(2)
		local final = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(final, 1)
		RoundLogic.applyOutcomes(st, RoundLogic.eliminate(final, { { userId = 1, score = 0 } }, noScore))
		t.eq(RoundLogic.winnerOf(st), 2)
		local winner, needsWon = RoundLogic.decideWinner(st, { 2 })
		t.eq(winner, 2)
		t.eq(needsWon, false)
	end)
	-- m2-07 결정: 결승 전 라운드에서 혼자 남으면 즉시 종료 ---------------------------

	t.test(
		"m2-07 혼자 남음: Race(목표 2) 4명 중 3명 리셋 → 3번째 리셋 순간 종료, 남은 1명 통과",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 2)
			local last: { Outcome } = {}
			for _, id in { 1, 2, 3 } do
				t.ok(not round.ended, `리셋 {id} 전에는 진행 중`)
				last = RoundLogic.eliminate(round, { { userId = id, score = 0, cause = "Reset" } }, noScore)
			end
			t.eq(summary(last), { [3] = "Eliminated:nil", [4] = "Passed:1" })
			t.ok(round.ended)
		end
	)

	t.test(
		"m2-07 혼자 남음: 통과 1 + 레이서 1에서 레이서가 리셋 → 종료 (구제 없음)",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2, 3 })
			RoundLogic.activate(round, 2)
			RoundLogic.eliminate(round, { { userId = 3, score = 0, cause = "Reset" } }, noScore)
			RoundLogic.pass(round, 1, noScore)
			t.ok(not round.ended, "통과 1 + 레이서 1(합 2명)이면 계속 진행해요")
			local out = RoundLogic.eliminate(round, { { userId = 2, score = 0, cause = "Reset" } }, noScore)
			t.eq(summary(out), { [2] = "Eliminated:nil" })
			t.ok(round.ended)
			t.eq(round.passedCount, 1)
		end
	)

	t.test(
		"m2-07 혼자 남음: 통과 1 + 레이서 1에서 레이서가 떨어지면 구제로 둘 다 결승",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2, 3 })
			RoundLogic.activate(round, 2)
			RoundLogic.eliminate(round, { { userId = 3, score = 0, cause = "Reset" } }, noScore)
			RoundLogic.pass(round, 1, noScore)
			local out = RoundLogic.eliminate(round, { { userId = 2, score = 0 } }, noScore)
			t.eq(summary(out), { [2] = "Passed:2" })
			t.ok(round.ended)
		end
	)

	t.test(
		"m2-07 혼자 남음: Survival도 같아요, 결승은 이 규칙이 아니라 1명 남으면 Won",
		function()
			local survival = RoundLogic.newRound("Survival", { 1, 2, 3 })
			RoundLogic.activate(survival, 2)
			-- 목표 2라 한 명씩 빠지면 2명 남을 때 이미 끝나요. 같은 틱에 둘이 리셋하면 1명만 남아요.
			local out = RoundLogic.eliminate(survival, {
				{ userId = 1, score = 0, cause = "Reset" },
				{ userId = 2, score = 0, cause = "Reset" },
			}, noScore)
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Eliminated:nil", [3] = "Passed:1" })
			t.ok(survival.ended)

			local final = RoundLogic.newRound("Final", { 1, 2 })
			RoundLogic.activate(final, 1)
			local finalOut = RoundLogic.eliminate(final, { { userId = 1, score = 0, cause = "Reset" } }, noScore)
			t.eq(summary(finalOut), { [1] = "Eliminated:nil", [2] = "Won:1" })
		end
	)

	------------------------------------------------------------------------
	-- m5-01 결승 연장전: 일정과 결승 규칙 회귀

	local FINAL_TIMING = { CollapseDuration = 20, HardCapMargin = 40 }

	t.test(
		"m5-01 AC1: schedule — 결승은 연장전·붕괴·안전 상한, Race·Survival은 시간 제한만",
		function()
			t.eq(RoundLogic.schedule("Final", 90, FINAL_TIMING), { overtimeAt = 90, collapseAt = 110, hardCapAt = 150 })
			t.eq(RoundLogic.schedule("Race", 90, FINAL_TIMING), { hardCapAt = 90 })
			t.eq(RoundLogic.schedule("Survival", 60, FINAL_TIMING), { hardCapAt = 60 })
			t.eq(
				RoundLogic.schedule("Final", 90, FINAL_TIMING, 15),
				{ overtimeAt = 15, collapseAt = 35, hardCapAt = 75 }
			)
			-- 디버그 값은 결승에만 써요
			t.eq(RoundLogic.schedule("Survival", 60, FINAL_TIMING, 15), { hardCapAt = 60 })
		end
	)

	t.test("m5-01 AC2: clockPhase — 경계값", function()
		local final = RoundLogic.schedule("Final", 90, FINAL_TIMING)
		t.eq(RoundLogic.clockPhase(final, 0), "Normal")
		t.eq(RoundLogic.clockPhase(final, 89.9), "Normal")
		t.eq(RoundLogic.clockPhase(final, 90), "Overtime")
		t.eq(RoundLogic.clockPhase(final, 109.9), "Overtime")
		t.eq(RoundLogic.clockPhase(final, 110), "Collapsed")
		t.eq(RoundLogic.clockPhase(final, 149.9), "Collapsed")
		t.eq(RoundLogic.clockPhase(final, 150), "Expired")
		t.eq(RoundLogic.clockPhase(final, 1000), "Expired")
		local race = RoundLogic.schedule("Race", 90, FINAL_TIMING)
		t.eq(RoundLogic.clockPhase(race, 0), "Normal")
		t.eq(RoundLogic.clockPhase(race, 89.9), "Normal")
		t.eq(RoundLogic.clockPhase(race, 90), "Expired")
		local survival = RoundLogic.schedule("Survival", 60, FINAL_TIMING)
		for _, elapsed in { 0, 30, 59.9 } do
			t.eq(RoundLogic.clockPhase(survival, elapsed), "Normal")
		end
		t.eq(RoundLogic.clockPhase(survival, 60), "Expired")
	end)

	t.test(
		"m5-01 AC3: 결승 3명이 다른 묶음으로 떨어지면 두 번째 묶음에서 남은 1명 우승",
		function()
			local round = RoundLogic.newRound("Final", { 1, 2, 3 }, fakeRng(5))
			RoundLogic.activate(round, 1)
			local first = RoundLogic.eliminate(round, { { userId = 1, score = 2 } }, noScore)
			t.eq(summary(first), { [1] = "Eliminated:nil" })
			t.ok(not round.ended, "should continue with 2 left")
			local second = RoundLogic.eliminate(round, { { userId = 2, score = 7 } }, noScore)
			t.eq(summary(second), { [2] = "Eliminated:nil", [3] = "Won:1" })
			t.ok(round.ended, "should end")
			t.eq(#RoundLogic.timeout(round, noScore), 0)
		end
	)

	t.test(
		"m5-01 AC4: 결승 2명 같은 묶음 — 더 높이, 리셋은 더 나쁨, 둘 다 리셋이면 우승 없음",
		function()
			local round = RoundLogic.newRound("Final", { 1, 2 }, fakeRng(1))
			RoundLogic.activate(round, 1)
			local out = RoundLogic.eliminate(round, { { userId = 1, score = 5 }, { userId = 2, score = 8 } }, noScore)
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Won:1" })

			round = RoundLogic.newRound("Final", { 1, 2 }, fakeRng(2))
			RoundLogic.activate(round, 1)
			out = RoundLogic.eliminate(
				round,
				{ { userId = 1, score = 50, cause = "Reset" }, { userId = 2, score = 3, cause = "Fall" } },
				noScore
			)
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Won:1" })

			round = RoundLogic.newRound("Final", { 1, 2 }, fakeRng(3))
			RoundLogic.activate(round, 1)
			out = RoundLogic.eliminate(
				round,
				{ { userId = 1, score = 5, cause = "Reset" }, { userId = 2, score = 8, cause = "Reset" } },
				noScore
			)
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Eliminated:nil" })
			t.ok(round.ended, "should end without a winner")
		end
	)

	t.test(
		"m5-01 AC5: 결승 안전 상한(timeout) — 점수가 가장 큰 1명만 Won, 낮은 사람이 더 나쁜 등수",
		function()
			local round = RoundLogic.newRound("Final", { 1, 2, 3 }, fakeRng(4))
			RoundLogic.activate(round, 1)
			local standings = standingsFor(3)
			local out =
				RoundLogic.applyOutcomes(standings, RoundLogic.timeout(round, scores({ [1] = 3, [2] = 9, [3] = 5 })))
			t.eq(summary(out), { [1] = "Eliminated:3", [2] = "Won:1", [3] = "Eliminated:2" })
			t.eq(RoundLogic.winnerOf(standings), 2)

			for seed = 1, 30 do
				local tied = RoundLogic.newRound("Final", { 1, 2, 3, 4 }, fakeRng(seed))
				RoundLogic.activate(tied, 1)
				local won = 0
				for _, o in RoundLogic.timeout(tied, noScore) do
					if o.result == "Won" then
						won += 1
					end
				end
				t.eq(won, 1, `seed {seed}`)
			end
		end
	)

	t.test(
		"m5-01 AC6: 결승 혼자 — activate로는 안 끝나고 낙하면 Won, 리셋이면 우승 없음",
		function()
			local round = RoundLogic.newRound("Final", { 1 }, fakeRng(6))
			RoundLogic.activate(round, 1)
			t.ok(not round.ended, "solo final should keep running")
			local out = RoundLogic.eliminate(round, { { userId = 1, score = -30, cause = "Fall" } }, noScore)
			t.eq(summary(out), { [1] = "Won:1" })
			t.ok(round.ended, "should end")

			round = RoundLogic.newRound("Final", { 1 }, fakeRng(7))
			RoundLogic.activate(round, 1)
			out = RoundLogic.eliminate(round, { { userId = 1, score = 0, cause = "Reset" } }, noScore)
			t.eq(summary(out), { [1] = "Eliminated:nil" })
			t.ok(round.ended, "should end")
		end
	)

	-- m5-01 QA B1·B2 수정

	-- RoundService 대기 루프를 loopAction으로 흉내 내요 (0.2초 간격). 연장전 훅은 따로 도니까 루프는 훅을 기다리지 않아요.
	-- 끝난 시각과 연장전 시작 횟수를 돌려줘요.
	local function runLoop(schedule: any, isEnded: (elapsed: number) -> boolean): (number, number)
		local elapsed = 0
		local started = false
		local starts = 0
		while not isEnded(elapsed) do
			local action = RoundLogic.loopAction(schedule, elapsed, started)
			if action == "Expire" then
				break
			end
			if action == "StartOvertime" then
				started = true
				starts += 1
				-- 훅이 영원히 멈춰도(yield) 루프는 이어져요: 여기서 아무것도 기다리지 않아요
			end
			elapsed += 0.2
		end
		return elapsed, starts
	end

	t.test("m5-01 QA B1: 연장전 훅이 멈춰도 루프는 안전 상한(150초)에 끝나요", function()
		local schedule = RoundLogic.schedule("Final", 90, FINAL_TIMING)
		local endedAt, starts = runLoop(schedule, function()
			return false -- 아무도 안 떨어짐 (훅이 붕괴를 못 함)
		end)
		t.ok(math.abs(endedAt - 150) < 0.21, `ended at {endedAt}`)
		t.eq(starts, 1)
		t.eq(RoundLogic.loopAction(schedule, 89.9, false), "Wait")
		t.eq(RoundLogic.loopAction(schedule, 90, false), "StartOvertime")
		t.eq(RoundLogic.loopAction(schedule, 95, true), "Wait")
		t.eq(RoundLogic.loopAction(schedule, 120, false), "StartOvertime") -- 늦게 깨어나도 한 번은 시작
		t.eq(RoundLogic.loopAction(schedule, 150, false), "Expire")
		t.eq(RoundLogic.loopAction(schedule, 150, true), "Expire")
		-- RoundService는 훅을 루프 안에서 직접 pcall하지 않고 따로 스레드로 불러요
		local source = fs.readFile("src/server/RoundService.luau")
		t.ok(string.find(source, "RoundLogic.loopAction(", 1, true) ~= nil, "loop uses loopAction")
		t.ok(string.find(source, "cleanup:add(task.spawn(function()", 1, true) ~= nil, "hook runs in its own thread")
		t.ok(string.find(source, "pcall(overtimeHook", 1, true) == nil, "no direct pcall of the hook in the loop")
	end)

	t.test(
		"m5-01 QA B2: 결승 맵에 overtime 훅이 없으면 연장전 없이 시간 제한에 높이 순으로 끝나요",
		function()
			t.eq(RoundLogic.schedule("Final", 90, FINAL_TIMING, nil, false), { hardCapAt = 90 })
			t.eq(RoundLogic.schedule("Final", 90, FINAL_TIMING, 15, false), { hardCapAt = 90 })
			t.eq(
				RoundLogic.schedule("Final", 90, FINAL_TIMING, nil, true),
				{ overtimeAt = 90, collapseAt = 110, hardCapAt = 150 }
			)
			local schedule = RoundLogic.schedule("Final", 90, FINAL_TIMING, nil, false)
			local endedAt, starts = runLoop(schedule, function()
				return false
			end)
			t.ok(math.abs(endedAt - 90) < 0.21, `ended at {endedAt}`)
			t.eq(starts, 0) -- 연장전 표시(RoundProgress.overtime)를 보내지 않아요
			local round = RoundLogic.newRound("Final", { 1, 2 }, fakeRng(9))
			RoundLogic.activate(round, 1)
			local out = RoundLogic.timeout(round, scores({ [1] = 4, [2] = 12 }))
			t.eq(summary(out), { [1] = "Eliminated:nil", [2] = "Won:1" })
			-- RoundService는 훅이 있는지 schedule에 넘겨요
			local source = fs.readFile("src/server/RoundService.luau")
			t.ok(string.find(source, 'type(overtimeHook) == "function"', 1, true) ~= nil, "hook presence passed")
		end
	)

	t.test(
		"m5-01 QA B2: 강제 플랜의 마지막이 Final 맵이 아니면 경고만 (플랜은 그대로)",
		function()
			local pool = {
				{ id = "belt", kind = "Race" },
				{ id = "plate", kind = "Survival" },
				{ id = "skewer", kind = "Final" },
			}
			local plan = Rules.resolveForcedPlan({ "skewer", "plate", "belt" }, pool :: any)
			t.ok(plan ~= nil, "plan still resolves")
			t.ok(Rules.forcedPlanWarning(plan :: any) ~= nil, "warns when the last map is not Final")
			local good = Rules.resolveForcedPlan({ "belt", "plate", "skewer" }, pool :: any)
			t.eq(Rules.forcedPlanWarning(good :: any), nil)
			local source = fs.readFile("src/server/MatchService.luau")
			t.ok(string.find(source, "Rules.forcedPlanWarning(plan)", 1, true) ~= nil, "MatchService warns")
		end
	)
end
