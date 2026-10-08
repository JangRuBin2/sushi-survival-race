--!strict
-- 밥알 코인 지급 규칙 (GDD 9.4, m4-08). 순수 로직이라 Roblox API를 쓰지 않아요. 값은 Config.Rewards.
--   forPass(isFinalRound) -> amount?              결승이 아닌 라운드의 Passed(구제 통과 포함) +10, 결승이면 nil
--   forRoundStart(roundIndex, roundCount) -> amount?  결승 출발 때 레이서 전원 +30 (건너뛴 결승 포함)
--   forWin() -> amount                            Won(부전승 포함) +100
--   dailyBonus(lastDay?, today) -> amount?        하루(UTC 날짜 번호) 첫 판 +50, 오늘 이미 받았으면 nil
--   dayNumber(unixTime) -> number                 UTC 날짜 번호 (ProfileSchema.lastDailyBonusDay와 같은 단위)
--   matchTotal(grants) -> number                  받은 지급의 합계 (클라이언트 매치 정산)
--   newTracker() / onRoundStart / onResult        방 하나의 매치 동안 지금 라운드를 기억해 지급 목록을 만들어요
--   simulate(events) -> { [userId]: coins }      한 판 시나리오의 사람별 총 코인 (테스트용)

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

export type Grant = {
	userId: number,
	reason: Types.RewardReason,
	amount: number,
}

-- 방 하나의 매치 상태: 지금 라운드 번호 (결승 여부 판단용)
export type Tracker = {
	roundIndex: number?,
	roundCount: number?,
}

export type ResultKind = "Passed" | "Eliminated" | "Won"

-- simulate 이벤트
--   { kind = "RoundStart", roundIndex, roundCount, userIds }
--   { kind = "Result", userId, result }
--   { kind = "MatchEnd", userIds (매치 끝 시점 방 멤버), participants? (있으면 userIds와 교집합만), today,
--     lastDays? ({ [userId]: day }) }
export type SimEvent = {
	kind: "RoundStart" | "Result" | "MatchEnd",
	roundIndex: number?,
	roundCount: number?,
	userIds: { number }?,
	participants: { number }?,
	userId: number?,
	result: ResultKind?,
	today: number?,
	lastDays: { [number]: number }?,
}

local SECONDS_PER_DAY = 86400

local RewardLogic = {}

function RewardLogic.forPass(isFinalRound: boolean): number?
	if isFinalRound then
		return nil
	end
	return Config.Rewards.RoundPass
end

function RewardLogic.forRoundStart(roundIndex: number, roundCount: number): number?
	if roundIndex == roundCount then
		return Config.Rewards.FinalQualify
	end
	return nil
end

function RewardLogic.forWin(): number
	return Config.Rewards.Win
end

function RewardLogic.dailyBonus(lastDay: number?, today: number): number?
	if lastDay == today then
		return nil
	end
	return Config.Rewards.DailyFirstMatch
end

function RewardLogic.dayNumber(unixTime: number): number
	return unixTime // SECONDS_PER_DAY
end

function RewardLogic.matchTotal(grants: { { amount: number } }): number
	local total = 0
	for _, grant in grants do
		total += grant.amount
	end
	return total
end

RewardLogic.REASON_TEXT = {
	RoundPass = "라운드 통과",
	FinalQualify = "결승 진출",
	Win = "우승!",
	DailyFirstMatch = "오늘 첫 판",
} :: { [Types.RewardReason]: string }

-- 지급 토스트 글씨: "+10 🍚 라운드 통과"
function RewardLogic.toastText(reason: Types.RewardReason, amount: number): string
	return `+{amount} 🍚 {RewardLogic.REASON_TEXT[reason] or reason}`
end

-- 매치 정산 한 줄: "이번 판 +210 🍚 (총 1234)"
function RewardLogic.summaryText(matchTotal: number, coins: number): string
	return `이번 판 +{matchTotal} 🍚 (총 {coins})`
end

-- 매치 끝 지급(하루 첫 판·matchesPlayed) 대상: 매치를 시작한 참가자 중 매치 끝 시점에 방에 남은 사람 (참가자 순서).
-- 방만 나가고 서버에 남은 사람은 빠져요 (m4-08 QA B1).
function RewardLogic.matchEndRecipients(participants: { number }, remainingUserIds: { number }): { number }
	local remaining: { [number]: boolean } = {}
	for _, userId in remainingUserIds do
		remaining[userId] = true
	end
	local out: { number } = {}
	for _, userId in participants do
		if remaining[userId] then
			table.insert(out, userId)
			remaining[userId] = nil -- 같은 사람을 두 번 넣지 않아요
		end
	end
	return out
end

function RewardLogic.newTracker(): Tracker
	return { roundIndex = nil, roundCount = nil }
end

function RewardLogic.isFinalRound(tracker: Tracker): boolean
	return tracker.roundIndex ~= nil and tracker.roundIndex == tracker.roundCount
end

-- 라운드 출발 (MatchEvents.onRoundStart). 결승이면 레이서 전원에게 FinalQualify.
function RewardLogic.onRoundStart(
	tracker: Tracker,
	roundIndex: number,
	roundCount: number,
	userIds: { number }
): { Grant }
	tracker.roundIndex = roundIndex
	tracker.roundCount = roundCount
	local grants: { Grant } = {}
	local amount = RewardLogic.forRoundStart(roundIndex, roundCount)
	if amount then
		for _, userId in userIds do
			table.insert(grants, { userId = userId, reason = "FinalQualify", amount = amount })
		end
	end
	return grants
end

-- PlayerResult 하나 (MatchEvents.onResult). Passed는 결승이 아닐 때만, Won은 언제나.
function RewardLogic.onResult(tracker: Tracker, userId: number, result: ResultKind): { Grant }
	if result == "Won" then
		return { { userId = userId, reason = "Win", amount = RewardLogic.forWin() } }
	elseif result == "Passed" then
		local amount = RewardLogic.forPass(RewardLogic.isFinalRound(tracker))
		if amount then
			return { { userId = userId, reason = "RoundPass", amount = amount } }
		end
	end
	return {}
end

function RewardLogic.simulate(events: { SimEvent }): { [number]: number }
	local totals: { [number]: number } = {}
	local tracker = RewardLogic.newTracker()
	local function add(grants: { Grant })
		for _, grant in grants do
			totals[grant.userId] = (totals[grant.userId] or 0) + grant.amount
		end
	end
	for _, event in events do
		if event.kind == "RoundStart" then
			add(
				RewardLogic.onRoundStart(
					tracker,
					event.roundIndex :: number,
					event.roundCount :: number,
					event.userIds or {}
				)
			)
		elseif event.kind == "Result" then
			add(RewardLogic.onResult(tracker, event.userId :: number, event.result :: ResultKind))
		elseif event.kind == "MatchEnd" then
			local lastDays = event.lastDays or {}
			local recipients = event.userIds or {}
			if event.participants then
				recipients = RewardLogic.matchEndRecipients(event.participants, recipients)
			end
			for _, userId in recipients do
				local amount = RewardLogic.dailyBonus(lastDays[userId], event.today :: number)
				if amount then
					add({ { userId = userId, reason = "DailyFirstMatch", amount = amount } })
				end
			end
		end
	end
	return totals
end

return RewardLogic
