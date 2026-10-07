--!strict
-- m2-07 QA(docs/qa/m2-07-full-match-integration.md)에서 추가한 통합 불변식 테스트.
-- MatchService.runMatch의 루프(roundToPlay → 라운드 → 혼자 남음 break → nextRound → decideWinner)를
-- 순수 로직(Rules, RoundLogic, 실제 맵 풀)으로 흉내 내고, 무작위 통과·낙하·리셋·같은 틱 묶음으로
-- 한 판을 수천 번 돌려 불변식을 확인해요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Rules = RobloxRequire.require(Shared.Rules)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Maps = RobloxRequire.require(Shared.maps)

local function lcg(seed: number)
	local state = seed
	local rng = {}
	function rng.int(min: number, max: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return min + state % (max - min + 1)
	end
	function rng.chance(p: number): boolean
		return rng.int(0, 9999) < p * 10000
	end
	function rng.NextInteger(_: any, min: number, max: number): number
		return rng.int(min, max)
	end
	return rng
end

type MatchLog = {
	startCount: number,
	wonUsers: { number },
	eliminatedSet: { [number]: boolean },
	winner: number?,
	needsWon: boolean,
	standings: { RoundLogic.Standing },
	finalistsCount: number?, -- 결승을 시작한 인원 (결승을 안 했으면 nil)
	anyReset: boolean,
	playedFinal: boolean,
}

-- allowReset=false면 탈락은 전부 맵 낙하(Fall)예요.
local function simulateMatch(seed: number, allowReset: boolean): MatchLog
	local rng = lcg(seed)
	local startCount = rng.int(2, 24)
	local ids, entries = {}, {}
	for i = 1, startCount do
		table.insert(ids, i)
		table.insert(entries, { userId = i, name = `p{i}` })
	end
	local standings = RoundLogic.newStandings(entries)
	local alive: { [number]: boolean } = {}
	for _, id in ids do
		alive[id] = true
	end
	local function aliveList(): { number }
		local list = {}
		for id in alive do
			table.insert(list, id)
		end
		table.sort(list)
		return list
	end

	local log: MatchLog = {
		startCount = startCount,
		wonUsers = {},
		eliminatedSet = {},
		winner = nil,
		needsWon = false,
		standings = {},
		finalistsCount = nil,
		anyReset = false,
		playedFinal = false,
	}
	local function record(outcomes: { RoundLogic.Outcome })
		for _, o in RoundLogic.applyOutcomes(standings, outcomes) do
			if o.result == "Won" then
				table.insert(log.wonUsers, o.userId)
			elseif o.result == "Eliminated" then
				log.eliminatedSet[o.userId] = true
				alive[o.userId] = nil
			end
		end
	end

	local roundCount = Rules.roundCount(math.max(startCount, 4))
	local plan = Rules.buildRoundPlan(roundCount, Maps.infos(), rng)
	local roundIndex: number? = 1
	local guard = 0
	while roundIndex and #aliveList() >= 2 do
		guard += 1
		assert(guard < 20, "match loop runaway")
		roundIndex = Rules.roundToPlay(roundIndex :: number, roundCount, #aliveList())
		local index = roundIndex :: number
		local isFinal = index == roundCount
		local kind = plan[index].kind
		local mode = RoundLogic.modeFor(kind, isFinal)
		local racers = aliveList()
		if isFinal then
			log.playedFinal = true
			log.finalistsCount = #racers
		end
		local round = RoundLogic.newRound(mode, racers, rng)
		RoundLogic.activate(round, Rules.qualifyCount(#racers, roundCount, index))
		local scores: { [number]: number } = {}
		for _, id in racers do
			scores[id] = rng.int(0, 100)
		end
		local function scoreOf(id: number): number
			return scores[id] or -math.huge
		end

		local steps = 0
		while not round.ended and steps < 60 and rng.chance(0.93) do
			steps += 1
			local current = RoundLogic.racers(round)
			if #current == 0 then
				break
			end
			-- Race 맵만 결승선(pass)이 있어요. 결승 맵(skewer-showdown)·Survival은 낙하만.
			if kind == "Race" and rng.chance(0.4) then
				record(RoundLogic.pass(round, current[rng.int(1, #current)], scoreOf))
			else
				local batch = {}
				local size = rng.int(1, math.min(3, #current))
				for _ = 1, size do
					local id = current[rng.int(1, #current)]
					local cause: RoundLogic.FallCause = if allowReset and rng.chance(0.25) then "Reset" else "Fall"
					if cause == "Reset" then
						log.anyReset = true
					end
					table.insert(batch, { userId = id, score = rng.int(0, 100), cause = cause })
				end
				record(RoundLogic.eliminate(round, batch, scoreOf))
			end
		end
		record(RoundLogic.timeout(round, scoreOf))

		if not isFinal and #aliveList() <= 1 then
			break -- MatchService: 결승 전 라운드 뒤 혼자(또는 0명)면 결과 단계 없이 부전승 판정
		end
		roundIndex = Rules.nextRound(index, roundCount, #aliveList())
	end

	local winner, needsWon = RoundLogic.decideWinner(standings, aliveList())
	if winner and needsWon then
		table.insert(log.wonUsers, winner) -- MatchService가 EliminationService.won을 보내요
	end
	log.winner = winner
	log.needsWon = needsWon
	log.standings = RoundLogic.standingsList(standings)
	return log
end

return function(t: Test.Test)
	t.test(
		"무작위 한 판 3000번 (리셋 포함): Won ≤ 1, Victory 우승자 = Won 받은 사람, 탈락자는 우승 못 함",
		function()
			for seed = 1, 3000 do
				local log = simulateMatch(seed, true)
				t.ok(#log.wonUsers <= 1, `seed {seed}: Won sent {#log.wonUsers} times`)
				if log.winner then
					t.eq(log.wonUsers[1], log.winner, `seed {seed}: Victory winner differs from Won`)
					t.ok(not log.eliminatedSet[log.winner], `seed {seed}: eliminated player {log.winner} won`)
				else
					t.eq(#log.wonUsers, 0, `seed {seed}: Won without a Victory winner`)
				end
			end
		end
	)

	t.test(
		"무작위 한 판 3000번: 순위표는 시작 인원만큼, 등수 중복 없음, 우승자가 있으면 1등 = 우승자",
		function()
			for seed = 1, 3000 do
				local log = simulateMatch(seed, true)
				t.eq(#log.standings, log.startCount, `seed {seed}: standings rows`)
				local seenPlace = {}
				for _, row in log.standings do
					t.ok(not seenPlace[row.place], `seed {seed}: place {row.place} twice`)
					seenPlace[row.place] = true
					t.ok(row.place >= 1 and row.place <= log.startCount, `seed {seed}: place {row.place} out of range`)
				end
				if log.winner then
					t.eq(log.standings[1].userId, log.winner, `seed {seed}: 1st place is not the winner`)
					t.eq(log.standings[1].place, 1)
				end
			end
		end
	)

	t.test(
		"무작위 한 판 3000번 (리셋 없음, 낙하만): 결승은 항상 2명 이상으로 시작하고 반드시 우승자가 나와요",
		function()
			local finals = 0
			for seed = 1, 3000 do
				local log = simulateMatch(seed, false)
				t.ok(log.playedFinal, `seed {seed}: no final without resets`)
				if log.finalistsCount then
					finals += 1
					t.ok(log.finalistsCount >= 2, `seed {seed}: final started with {log.finalistsCount}`)
				end
				t.ok(log.winner ~= nil, `seed {seed}: no winner without resets`)
				t.ok(not log.needsWon, `seed {seed}: walkover without resets`)
			end
			t.ok(finals > 0)
		end
	)
end
