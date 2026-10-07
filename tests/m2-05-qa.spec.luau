--!strict
-- m2-05 QA 경계값 테스트 (RoundLogic: 동시 탈락, 이탈, 최대 인원 순위표, 동점)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Rules = RobloxRequire.require(Shared.Rules)

type Outcome = { userId: number, result: string, place: number? }

local noScore = function(_id: number): number
	return 0
end

local function scores(map: { [number]: number }): (number) -> number
	return function(id: number): number
		return map[id] or -math.huge
	end
end

local function standingsFor(count: number)
	local entries = {}
	for i = 1, count do
		table.insert(entries, { userId = i, name = `P{i}` })
	end
	return RoundLogic.newStandings(entries)
end

local function summary(outcomes: { Outcome }): { [number]: string }
	local out = {}
	for _, o in outcomes do
		out[o.userId] = `{o.result}:{o.place}`
	end
	return out
end

local function count(outcomes: { Outcome }, result: string): number
	local n = 0
	for _, o in outcomes do
		if o.result == result then
			n += 1
		end
	end
	return n
end

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
		"QA m2-05: 결승 3명 중 2명이 같은 틱에 탈락 → 남은 1명 우승, 묶음은 높이 순 2·3등",
		function()
			local st = standingsFor(3)
			local round = RoundLogic.newRound("Final", { 1, 2, 3 })
			RoundLogic.activate(round, 1)
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(round, { { userId = 1, score = 2 }, { userId = 2, score = 30 } }, noScore)
			)
			t.eq(summary(out), { [3] = "Won:1", [2] = "Eliminated:2", [1] = "Eliminated:3" })
			t.ok(round.ended)
		end
	)

	t.test(
		"QA m2-05: 결승 마지막 2명 — 한 명 이탈(-inf)과 한 명 낙하가 같은 틱 → 낙하한 사람 우승",
		function()
			local st = standingsFor(2)
			local round = RoundLogic.newRound("Final", { 1, 2 })
			RoundLogic.activate(round, 1)
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(
					round,
					{ { userId = 1, score = -math.huge }, { userId = 2, score = -40 } },
					noScore
				)
			)
			t.eq(summary(out), { [2] = "Won:1", [1] = "Eliminated:2" })
		end
	)

	t.test(
		"QA m2-05: 결승 시간 종료 높이 동점 → 무작위지만 우승자 정확히 1명, 나머지 빈틈없는 등수",
		function()
			for seed = 1, 30 do
				local st = standingsFor(4)
				local round = RoundLogic.newRound("Final", { 1, 2, 3, 4 }, fakeRng(seed))
				RoundLogic.activate(round, 1)
				local out = RoundLogic.applyOutcomes(st, RoundLogic.timeout(round, noScore))
				t.eq(count(out, "Won"), 1)
				t.eq(count(out, "Eliminated"), 3)
				local seen = {}
				for _, o in out do
					t.ok(not seen[o.place], "등수 중복 없음")
					seen[o.place :: number] = true
				end
				t.ok(seen[1] and seen[2] and seen[3] and seen[4], "1~4등")
			end
		end
	)

	t.test("QA m2-05: 결승이 끝난 뒤 들어온 탈락·통과·시간 종료는 모두 무시", function()
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		RoundLogic.eliminate(round, { { userId = 1, score = 0 } }, noScore)
		t.ok(round.ended)
		t.eq(#RoundLogic.eliminate(round, { { userId = 2, score = 0 } }, noScore), 0)
		t.eq(#RoundLogic.pass(round, 2, noScore), 0)
		t.eq(#RoundLogic.timeout(round, noScore), 0)
	end)

	t.test(
		"QA m2-05: Survival 같은 틱에 여러 명 탈락해 목표 아래로 내려가도 남은 사람 전원 통과",
		function()
			local st = standingsFor(6)
			local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5, 6 })
			RoundLogic.activate(round, 4)
			local out = RoundLogic.applyOutcomes(
				st,
				RoundLogic.eliminate(round, {
					{ userId = 1, score = 1 },
					{ userId = 2, score = 9 },
					{ userId = 3, score = 5 },
				}, noScore)
			)
			t.ok(round.ended)
			-- 낮은 사람부터 나쁜 등수: 1→6, 3→5, 2→4
			t.eq(summary(out), {
				[1] = "Eliminated:6",
				[3] = "Eliminated:5",
				[2] = "Eliminated:4",
				[4] = "Passed:1",
				[5] = "Passed:2",
				[6] = "Passed:3",
			})
		end
	)

	t.test(
		"QA m2-05: Survival 소개 중 탈락은 종료 판정 없이, 출발 뒤 첫 탈락에서 판정",
		function()
			local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4 })
			RoundLogic.eliminate(round, { { userId = 1, score = 0 }, { userId = 2, score = 0 } }, noScore)
			t.ok(not round.ended)
			RoundLogic.activate(round, 2) -- 출발 순간 2명 남았어도 바로 끝나지 않아요 (개발 메모)
			t.ok(not round.ended)
			local out = RoundLogic.timeout(round, noScore)
			t.eq(count(out, "Passed"), 2)
		end
	)

	t.test("QA m2-05: Race 같은 틱 탈락 묶음은 진행도 낮은 사람이 더 나쁜 등수", function()
		local st = standingsFor(5)
		local round = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5 })
		RoundLogic.activate(round, 3)
		local out = RoundLogic.applyOutcomes(
			st,
			RoundLogic.eliminate(round, { { userId = 4, score = 80 }, { userId = 5, score = 10 } }, noScore)
		)
		t.eq(summary(out), { [5] = "Eliminated:5", [4] = "Eliminated:4" })
		t.ok(not round.ended, "통과 0, 남은 3명 — 아직 진행")
	end)

	t.test(
		"QA m2-05: Race 통과 목표 = 남은 인원이면 마지막 사람 통과 순간 종료, 탈락 0",
		function()
			local round = RoundLogic.newRound("Race", { 1, 2 })
			RoundLogic.activate(round, 2)
			RoundLogic.pass(round, 1, noScore)
			local out = RoundLogic.pass(round, 2, noScore)
			t.ok(round.ended)
			t.eq(count(out, "Eliminated"), 0)
		end
	)

	t.test("QA m2-05: 24명 4라운드 매치 순위표 — 1~24등 빠짐없이, 받은 등수와 같음", function()
		local n = 24
		local st = standingsFor(n)
		local received: { [number]: number } = {}
		local function record(outcomes: { Outcome })
			for _, o in RoundLogic.applyOutcomes(st, outcomes) do
				if o.result ~= "Passed" then
					received[o.userId] = o.place :: number
				end
			end
		end
		local alive = {}
		for i = 1, n do
			table.insert(alive, i)
		end
		local roundCount = Rules.roundCount(n)
		t.eq(roundCount, 4)
		for roundIndex = 1, roundCount - 1 do
			local target = Rules.qualifyCount(#alive, roundCount, roundIndex)
			local mode = if roundIndex == 2 then "Survival" else "Race"
			local round = RoundLogic.newRound(mode, alive)
			RoundLogic.activate(round, target)
			if mode == "Race" then
				-- 앞사람부터 통과, 한 명은 라운드 중 이탈
				record(RoundLogic.eliminate(round, { { userId = alive[#alive], score = -math.huge } }, noScore))
				for i = 1, target do
					record(RoundLogic.pass(round, alive[i], noScore))
				end
			else
				local i = #alive
				while not round.ended do
					record(RoundLogic.eliminate(round, { { userId = alive[i], score = 0 } }, noScore))
					i -= 1
				end
			end
			t.ok(round.ended)
			alive = {}
			for id = 1, n do
				if received[id] == nil then
					table.insert(alive, id)
				end
			end
			t.eq(#alive, target, `R{roundIndex} 통과 인원 = 목표`)
		end
		local final = RoundLogic.newRound("Final", alive)
		RoundLogic.activate(final, 1)
		for i = #alive, 2, -1 do
			record(RoundLogic.eliminate(final, { { userId = alive[i], score = 0 } }, noScore))
		end
		t.ok(final.ended)
		local list = RoundLogic.standingsList(st)
		t.eq(#list, n)
		for i, row in list do
			t.eq(row.place, i)
			t.eq(received[row.userId], row.place)
		end
	end)

	t.test(
		"QA m2-05: standingsList는 등수가 없는 사람(비정상 종료)도 빈 등수로 채워 중복 없음",
		function()
			local st = standingsFor(4)
			RoundLogic.placeEliminated(st, 2) -- 4등
			RoundLogic.placeWinner(st, 3)
			local list = RoundLogic.standingsList(st)
			t.eq(#list, 4)
			local seen = {}
			for _, row in list do
				t.ok(not seen[row.place])
				seen[row.place] = true
			end
			t.eq(list[1].userId, 3)
			t.eq(list[4].userId, 2)
		end
	)

	t.test("QA m2-05: newRound는 중복 userId를 한 번만 레이서로", function()
		local round = RoundLogic.newRound("Race", { 5, 5, 6 })
		t.eq(RoundLogic.remainingCount(round), 2)
		t.eq(RoundLogic.racers(round), { 5, 6 })
	end)
end
