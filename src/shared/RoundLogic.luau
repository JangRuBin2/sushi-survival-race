--!strict
-- 라운드 판정과 매치 순위의 순수 로직 (GDD 4.1, 5.1, 5.2). Roblox API에 의존하지 않아요.
-- RoundService가 "무슨 일이 있었는지"(통과, 탈락 묶음, 시간 종료)를 넘기면 결과(Outcome) 목록을
-- 돌려주고, Standings가 그 결과에 매치 등수를 매겨요. tests/round-logic.spec.luau에서 돌려요.
--
-- 라운드 방식(Mode)
--   Race      결승선 통과. 통과자가 목표에 닿거나 남은 사람이 없으면 끝, 남은 사람은 진행도 순으로 탈락.
--             시간 종료면 진행도 상위로 빈 자리를 채우고 나머지는 탈락.
--   Survival  중간 생존 라운드. (통과 + 남은 인원)이 목표 이하가 되면 끝나고 남은 사람 전원 통과.
--             시간 종료면 버틴 사람 전원 통과 (목표보다 많아도 잘라내지 않아요, Q1).
--   Final     마지막 라운드(생존형 결승). 떨어질 때마다 탈락, 1명이 남는 순간 그 사람 우승.
--             같은 묶음(판정 틱)에 떨어져 0명이 되면 그 묶음에서 점수(높이)가 가장 큰 사람이 우승.
--             시간 종료면 점수가 가장 큰 사람이 우승. 맵이 pass를 부르면 첫 통과자가 우승(fallback).
-- 점수(score)는 클수록 잘한 거예요: Race는 진행도, Survival·Final은 높이(HumanoidRootPart Y).
--
-- 결승 진출 2명 보장 (m2-07, m2-05 QA F1, GDD 4.1 "최소 2명은 결승에 가요")
--   결승이 아닌 라운드에서 탈락 묶음 때문에 이번 라운드에서 살아남을 수 있는 인원(통과 + 남은 레이서)이
--   2명 아래로 내려가면, 그 묶음의 낙하(cause "Fall") 중 점수가 큰 사람부터 2명이 찰 때까지
--   탈락 대신 통과(구제)시켜요. 리셋·사망·퇴장(cause "Reset")은 구제하지 않아요.
--   매치 우승자는 Won을 받은 사람만이에요 (Standings.winnerUserId, decideWinner).

local Rules = require(script.Parent.Rules)

local RoundLogic = {}

export type Mode = "Race" | "Survival" | "Final"
export type Result = "Passed" | "Eliminated" | "Won"

-- place: Passed는 이번 라운드 통과 순서, Won은 1, Eliminated는 Standings가 매치 등수로 채워요.
export type Outcome = {
	userId: number,
	result: Result,
	place: number?,
}

-- 탈락 사유. Fall = 맵이 판정한 낙하(구제 대상), Reset = 리셋·사망·퇴장·캐릭터 없음(구제 안 함).
export type FallCause = "Fall" | "Reset"

export type Fall = {
	userId: number,
	score: number, -- 탈락 순간의 점수 (Final·Survival은 높이)
	cause: FallCause?, -- 없으면 "Fall"
}

-- 결승 전 라운드에서 살아남아야 하는 최소 인원 (GDD 4.1 결승 진출 최소 인원)
local MIN_FINALISTS = 2

export type Round = {
	mode: Mode,
	target: number?, -- activate 전에는 nil (소개 중)
	active: boolean,
	ended: boolean,
	order: { number }, -- 처음 레이서 순서 (결과를 결정적으로 만들려고)
	remaining: { [number]: boolean },
	passedCount: number,
	rng: Rules.Rng?,
}

export type Standing = {
	userId: number,
	name: string,
	place: number,
}

export type Standings = {
	entries: { { userId: number, name: string } },
	places: { [number]: number },
	nextWorst: number,
	winnerUserId: number?, -- Won을 받은 사람 (매치에서 많아야 1명)
}

------------------------------------------------------------------------
-- 라운드

function RoundLogic.modeFor(mapKind: Rules.MapKind, isFinal: boolean): Mode
	if isFinal then
		return "Final"
	end
	if mapKind == "Race" then
		return "Race"
	end
	-- Survival 맵, 또는 디버그 강제 플랜으로 중간에 놓인 Final 맵은 버티기 라운드예요.
	return "Survival"
end

function RoundLogic.newRound(mode: Mode, racerIds: { number }, rng: Rules.Rng?): Round
	local remaining = {}
	local order = {}
	for _, id in racerIds do
		if not remaining[id] then
			remaining[id] = true
			table.insert(order, id)
		end
	end
	return {
		mode = mode,
		target = nil,
		active = false,
		ended = false,
		order = order,
		remaining = remaining,
		passedCount = 0,
		rng = rng,
	}
end

-- 소개가 끝나고 실제로 출발할 때 목표 인원을 정해요. 이때 바로 종료 판정은 하지 않아요
-- (디버그 혼자 Survival·결승은 떨어지거나 시간이 끝날 때까지 돌아요).
function RoundLogic.activate(round: Round, target: number)
	if round.ended then
		return
	end
	round.target = target
	round.active = true
end

function RoundLogic.isRacing(round: Round, userId: number): boolean
	return round.remaining[userId] == true
end

-- 아직 통과/탈락하지 않은 사람 (처음 순서대로)
function RoundLogic.racers(round: Round): { number }
	local list = {}
	for _, id in round.order do
		if round.remaining[id] then
			table.insert(list, id)
		end
	end
	return list
end

function RoundLogic.remainingCount(round: Round): number
	local n = 0
	for _ in round.remaining do
		n += 1
	end
	return n
end

-- 점수 순 정렬. ascending이면 못한 사람부터. 점수가 같으면 rng가 있으면 무작위, 없으면 입력 순서.
local function rank<T>(items: { T }, scoreOf: (T) -> number, ascending: boolean, rng: Rules.Rng?): { T }
	local keyed = {}
	for i, item in items do
		local tie = if rng then rng:NextInteger(1, 2 ^ 30) else i
		table.insert(keyed, { item = item, score = scoreOf(item), tie = tie, index = i })
	end
	table.sort(keyed, function(a, b)
		if a.score ~= b.score then
			if ascending then
				return a.score < b.score
			end
			return a.score > b.score
		end
		if a.tie ~= b.tie then
			return a.tie < b.tie
		end
		return a.index < b.index
	end)
	local out = {}
	for _, k in keyed do
		table.insert(out, k.item)
	end
	return out
end

local function addPassed(round: Round, out: { Outcome }, id: number)
	round.remaining[id] = nil
	round.passedCount += 1
	table.insert(out, { userId = id, result = "Passed", place = round.passedCount })
end

local function addEliminated(round: Round, out: { Outcome }, id: number)
	round.remaining[id] = nil
	table.insert(out, { userId = id, result = "Eliminated" })
end

local function addWon(round: Round, out: { Outcome }, id: number)
	round.remaining[id] = nil
	table.insert(out, { userId = id, result = "Won", place = 1 })
end

-- 라운드를 끝내고 남은 사람을 정리해요.
local function settle(round: Round, out: { Outcome }, scoreOf: (number) -> number, isTimeout: boolean)
	round.ended = true
	round.active = false
	local leftover = RoundLogic.racers(round)
	if #leftover == 0 then
		return
	end

	if round.mode == "Survival" then
		for _, id in leftover do
			addPassed(round, out, id)
		end
	elseif round.mode == "Race" then
		local target = round.target or 0
		local openSlots = if isTimeout then target - round.passedCount else 0
		-- settleLeftover: 통과는 잘 간 순, 탈락은 못 간 사람부터 → 더 멀리 간 탈락자가 더 좋은 등수
		local toPass, toEliminate = Rules.settleLeftover(leftover, scoreOf, openSlots)
		for _, id in toPass do
			addPassed(round, out, id)
		end
		for _, id in toEliminate do
			addEliminated(round, out, id)
		end
	else -- Final
		local worstFirst = rank(leftover, scoreOf, true, round.rng)
		local winner: number? = nil
		if isTimeout then
			winner = table.remove(worstFirst) -- 점수가 가장 큰 사람
		end
		for _, id in worstFirst do
			addEliminated(round, out, id)
		end
		if winner then
			addWon(round, out, winner)
		end
	end
end

-- 소개 중이 아니고(목표가 정해졌고) 아직 안 끝났을 때, 종료 조건을 봐요 (Race·Survival).
local function checkEnd(round: Round, out: { Outcome }, scoreOf: (number) -> number)
	if not round.active or round.ended then
		return
	end
	local target = round.target :: number
	local left = RoundLogic.remainingCount(round)
	local done = left == 0
		or (round.mode == "Race" and round.passedCount >= target)
		or (round.mode == "Survival" and round.passedCount + left <= target)
	if done then
		settle(round, out, scoreOf, false)
	end
end

-- 결승선 통과. scoreOf는 라운드가 끝날 때 남은 사람을 정리하는 데 써요.
function RoundLogic.pass(round: Round, userId: number, scoreOf: (number) -> number): { Outcome }
	local out: { Outcome } = {}
	if round.ended or not round.remaining[userId] then
		return out
	end
	if round.mode == "Final" then
		-- fallback: Race 맵이 결승으로 쓰이면 첫 통과자가 우승하고 나머지는 진행도 순 탈락
		addWon(round, out, userId)
		settle(round, out, scoreOf, false)
		return out
	end
	addPassed(round, out, userId)
	checkEnd(round, out, scoreOf)
	return out
end

-- 같은 판정 틱(한 프레임)에 들어온 탈락 묶음. 점수가 낮은 사람부터 탈락 처리해서
-- 묶음 안에서는 더 잘 버틴 사람이 더 좋은 등수를 받아요.
function RoundLogic.eliminate(round: Round, falls: { Fall }, scoreOf: (number) -> number): { Outcome }
	local out: { Outcome } = {}
	if round.ended then
		return out
	end
	local seen: { [number]: boolean } = {}
	local batch: { Fall } = {}
	for _, fall in falls do
		if round.remaining[fall.userId] and not seen[fall.userId] then
			seen[fall.userId] = true
			table.insert(batch, fall)
		end
	end
	if #batch == 0 then
		return out
	end

	local worstFirst = rank(batch, function(f: Fall)
		return f.score
	end, true, round.rng)

	if round.mode == "Final" then
		local left = RoundLogic.remainingCount(round) - #worstFirst
		local winner: number? = nil
		if left == 0 then
			winner = (table.remove(worstFirst) :: Fall).userId -- 묶음에서 가장 높이 있던 사람
		end
		for _, fall in worstFirst do
			addEliminated(round, out, fall.userId)
		end
		if winner == nil and left == 1 then
			winner = RoundLogic.racers(round)[1]
		end
		if winner then
			addWon(round, out, winner)
			round.ended = true
			round.active = false
		end
		return out
	end

	-- 결승 진출 2명 보장: 이 묶음을 다 빼면 살아남을 사람이 2명 아래인지 봐요.
	local survivableAfter = round.passedCount + RoundLogic.remainingCount(round) - #worstFirst
	local rescueSlots = math.max(MIN_FINALISTS - survivableAfter, 0)
	local rescued: { [number]: boolean } = {}
	if rescueSlots > 0 then
		for i = #worstFirst, 1, -1 do -- 점수가 큰 사람부터
			local fall = worstFirst[i]
			if rescueSlots == 0 then
				break
			end
			if (fall.cause or "Fall") == "Fall" then
				rescued[fall.userId] = true
				rescueSlots -= 1
			end
		end
	end

	for _, fall in worstFirst do
		if not rescued[fall.userId] then
			addEliminated(round, out, fall.userId)
		end
	end
	for i = #worstFirst, 1, -1 do -- 구제는 점수가 큰 사람이 먼저 통과한 순서
		local fall = worstFirst[i]
		if rescued[fall.userId] then
			addPassed(round, out, fall.userId)
		end
	end
	checkEnd(round, out, scoreOf)
	return out
end

-- 시간 종료
function RoundLogic.timeout(round: Round, scoreOf: (number) -> number): { Outcome }
	local out: { Outcome } = {}
	if round.ended then
		return out
	end
	settle(round, out, scoreOf, true)
	return out
end

------------------------------------------------------------------------
-- 매치 순위

-- 매치를 시작한 모든 플레이어 (이름은 매치 시작 때 저장)
function RoundLogic.newStandings(entries: { { userId: number, name: string } }): Standings
	local copy = {}
	for _, e in entries do
		table.insert(copy, { userId = e.userId, name = e.name })
	end
	return { entries = copy, places = {}, nextWorst = #copy }
end

function RoundLogic.placeOf(standings: Standings, userId: number): number?
	return standings.places[userId]
end

-- 탈락(또는 매치 중 이탈): 아직 비어 있는 가장 나쁜 등수를 줘요. 이미 등수가 있으면 그대로.
function RoundLogic.placeEliminated(standings: Standings, userId: number): number
	local existing = standings.places[userId]
	if existing then
		return existing
	end
	local place = math.max(standings.nextWorst, 1)
	standings.places[userId] = place
	standings.nextWorst = place - 1
	return place
end

function RoundLogic.placeWinner(standings: Standings, userId: number): number
	local existing = standings.places[userId]
	if existing then
		return existing
	end
	standings.places[userId] = 1
	standings.winnerUserId = userId
	return 1
end

-- 우승자(Won을 받은 사람) userId. 없으면 nil. 탈락 등수가 1까지 내려간 사람은 우승자가 아니에요.
function RoundLogic.winnerOf(standings: Standings): number?
	return standings.winnerUserId
end

-- 매치가 끝날 때 우승자를 정해요. 이미 Won을 받은 사람이 있으면 그 사람(새로 보낼 필요 없음).
-- 없고 생존자가 정확히 1명이면 그 사람이 부전승 우승이고 Won을 새로 보내야 해요 (needsWon = true,
-- 이때 Standings에 1등으로 기록해요). 생존자가 0명이거나 2명 이상이면 우승자 없음.
function RoundLogic.decideWinner(standings: Standings, aliveUserIds: { number }): (number?, boolean)
	if standings.winnerUserId then
		return standings.winnerUserId, false
	end
	if #aliveUserIds == 1 then
		local userId = aliveUserIds[1]
		RoundLogic.placeWinner(standings, userId)
		return userId, true
	end
	return nil, false
end

-- 라운드 결과에 매치 등수를 채워서 돌려줘요 (Eliminated·Won만 Standings에 기록).
function RoundLogic.applyOutcomes(standings: Standings, outcomes: { Outcome }): { Outcome }
	local out = {}
	for _, o in outcomes do
		local place = o.place
		if o.result == "Eliminated" then
			place = RoundLogic.placeEliminated(standings, o.userId)
		elseif o.result == "Won" then
			place = RoundLogic.placeWinner(standings, o.userId)
		end
		table.insert(out, { userId = o.userId, result = o.result, place = place })
	end
	return out
end

-- 최종 순위표 (1등부터). 혹시 등수가 없는 사람이 있으면(비정상 종료 등) 빈 등수를 앞에서부터 채워요.
function RoundLogic.standingsList(standings: Standings): { Standing }
	local taken: { [number]: boolean } = {}
	for _, place in standings.places do
		taken[place] = true
	end
	local list: { Standing } = {}
	local nextFree = 1
	for _, e in standings.entries do
		local place = standings.places[e.userId]
		if place == nil then
			while taken[nextFree] do
				nextFree += 1
			end
			place = nextFree
			taken[nextFree] = true
		end
		table.insert(list, { userId = e.userId, name = e.name, place = place :: number })
	end
	table.sort(list, function(a, b)
		if a.place ~= b.place then
			return a.place < b.place
		end
		return a.userId < b.userId
	end)
	return list
end

return RoundLogic
