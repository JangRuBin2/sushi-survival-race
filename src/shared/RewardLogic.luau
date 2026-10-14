--!strict
-- 밥알 코인 지급 규칙 (GDD 9.4, m4-08). 순수 로직이라 Roblox API를 쓰지 않아요. 값은 Config.Rewards.
--   forPass(isFinalRound) -> amount?              결승이 아닌 라운드의 Passed(구제 통과 포함) +10, 결승이면 nil
--   forRoundStart(roundIndex, roundCount) -> amount?  결승 출발 때 레이서 전원 +30 (건너뛴 결승 포함)
--   forWin() -> amount                            Won(부전승 포함) +100
--   dailyBonus(lastDay?, today) -> amount?        하루(UTC 날짜 번호) 첫 판 +50, 오늘 이미 받았으면 nil
--   dayNumber(unixTime) -> number                 UTC 날짜 번호 (ProfileSchema.lastDailyBonusDay와 같은 단위)
--   matchTotal(grants) -> number                  받은 지급의 합계 (클라이언트 매치 정산)
--   newTracker() / onRoundStart / onResult        방 하나의 매치 동안 지금 라운드를 기억해 지급 목록을 만들어요
--   simulate(events) -> (coins, tokens)           한 판 시나리오의 사람별 총 코인·이벤트 재화 (테스트용)
-- 이벤트 재화 (m5-07): 시즌 이벤트(Shared.Seasons)가 진행 중일 때만, 코인과 같은 순간에 Config.Events.Tokens만큼.
--   tokensFor(reason, now?) -> (tokens?, eventId?)    now가 nil이거나 진행 중 이벤트가 없으면 nil
--   onRoundStart / onResult의 마지막 인자 now?       nil이면 재화 없이 (예전 호출과 같아요)
--   matchEndPayout(lastDay?, today, now?) -> Payout?  매치 끝 한 번: 하루 첫 판이면 DailyFirstMatch(코인 50 + 재화
--       판 참가 1 + 하루 첫 판 3), 아니면 이벤트 중 MatchPlayed(코인 0 + 재화 1), 둘 다 아니면 nil
--   matchTokenTotal(grants) -> number             받은 지급의 재화 합계 (우승 화면 정산)
--   toastText(reason, amount, tokens?, icon?) · summaryText(total, coins, tokens?, icon?, tickets?)
-- 🎫 우승자 뽑기 티켓 (m5-31): Won 지급에 tickets = Config.Draw.TicketsPerWin (이벤트·VIP 배수 없음). 다른 결과엔 없어요.
--   simulate의 세 번째 반환값 = 사람별 받을 티켓 합계 (상한은 프로필에서 DrawLogic.addTickets가 잘라요)
--   matchTicketTotal(grants) -> number · ticketToastText(tickets, full?, max?) -> string?

local Config = require(script.Parent.Config)
local ProfileLogic = require(script.Parent.ProfileLogic)
local Seasons = require(script.Parent.Seasons)
local Types = require(script.Parent.Types)

export type Grant = {
	userId: number,
	reason: Types.RewardReason,
	amount: number, -- 코인
	tokens: number?, -- 이벤트 재화 (m5-07, 이벤트 중일 때만)
	eventId: string?, -- 재화의 이벤트 id
	tickets: number?, -- 🎫 뽑기 티켓 (m5-31, Win일 때만)
}

-- 매치 끝 지급 한 번 (m5-07)
export type Payout = {
	reason: Types.RewardReason, -- DailyFirstMatch | MatchPlayed
	amount: number, -- 코인 (MatchPlayed면 0)
	tokens: number?,
	eventId: string?,
	daily: boolean, -- 하루 첫 판 보너스를 줬는가 (lastDailyBonusDay를 오늘로 바꿔요)
}

-- 방 하나의 매치 상태: 지금 라운드 번호 (결승 여부 판단용)
export type Tracker = {
	roundIndex: number?,
	roundCount: number?,
}

export type ResultKind = "Passed" | "Eliminated" | "Won"

-- simulate 이벤트
--   { kind = "RoundStart", roundIndex, roundCount, userIds, now? }
--   { kind = "Result", userId, result, now? }
--   { kind = "MatchEnd", userIds (매치 끝 시점 방 멤버), participants? (있으면 userIds와 교집합만), today,
--     lastDays? ({ [userId]: day }), now? }
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
	now: number?, -- 이벤트 재화 판단 시각 (m5-07). 없으면 재화 없음
}

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

-- 이벤트 재화 (m5-07): now에 진행 중인 이벤트가 있으면 (Config.Events.Tokens[reason], 이벤트 id)
function RewardLogic.tokensFor(reason: string, now: number?): (number?, string?)
	if type(now) ~= "number" then
		return nil, nil
	end
	local event = Seasons.current(now)
	if event == nil then
		return nil, nil
	end
	local amount = (Config.Events.Tokens :: { [string]: number })[reason]
	if type(amount) ~= "number" or amount <= 0 then
		return nil, nil
	end
	return amount, event.id
end

-- 매치 끝 지급 (m5-07). 하루 첫 판이면 코인 + 재화(판 참가 + 하루 첫 판)를 한 번에, 아니면 판 참가 재화만
function RewardLogic.matchEndPayout(lastDay: number?, today: number, now: number?): Payout?
	local played, eventId = RewardLogic.tokensFor("MatchPlayed", now)
	local daily = RewardLogic.dailyBonus(lastDay, today)
	if daily then
		local bonus, bonusEvent = RewardLogic.tokensFor("DailyFirstMatch", now)
		local tokens: number? = nil
		if played ~= nil or bonus ~= nil then
			tokens = (played or 0) + (bonus or 0)
			eventId = eventId or bonusEvent
		end
		return { reason = "DailyFirstMatch", amount = daily, tokens = tokens, eventId = eventId, daily = true }
	end
	if played ~= nil then
		return { reason = "MatchPlayed", amount = 0, tokens = played, eventId = eventId, daily = false }
	end
	return nil
end

-- 하나로 모음: ProfileLogic.dayNumber (m4-07)
RewardLogic.dayNumber = ProfileLogic.dayNumber

function RewardLogic.matchTotal(grants: { read [number]: { read amount: number } }): number
	local total = 0
	for _, grant in grants do
		total += grant.amount
	end
	return total
end

-- 받은 지급의 이벤트 재화 합계 (m5-07). 이벤트 하나만 동시에 진행하니 id는 나누지 않아요
function RewardLogic.matchTokenTotal(grants: { read [number]: { read tokens: number? } }): number
	local total = 0
	for _, grant in grants do
		local tokens = grant.tokens
		if type(tokens) == "number" and tokens > 0 then
			total += tokens
		end
	end
	return total
end

RewardLogic.REASON_TEXT = {
	RoundPass = "라운드 통과",
	FinalQualify = "결승 진출",
	Win = "우승!",
	DailyFirstMatch = "오늘 첫 판",
	Code = "코드 보상", -- m5-10
	MatchPlayed = "판 참가", -- m5-07 (이벤트 재화)
} :: { [Types.RewardReason]: string }

local function hasTokens(tokens: number?): boolean
	return type(tokens) == "number" and tokens > 0
end

-- 지급 토스트 글씨: "+10 🍚 라운드 통과". 재화도 받으면 "+10 🍚 +1 🍬 라운드 통과", 재화만이면 "+1 🍬 판 참가" (m5-07)
function RewardLogic.toastText(reason: Types.RewardReason, amount: number, tokens: number?, icon: string?): string
	local label = RewardLogic.REASON_TEXT[reason] or reason
	if not hasTokens(tokens) then
		return `+{amount} 🍚 {label}`
	end
	local tokenText = `+{tokens} {icon or "🍬"}`
	if amount > 0 then
		return `+{amount} 🍚 {tokenText} {label}`
	end
	return `{tokenText} {label}`
end

-- 매치 정산 한 줄: "이번 판 +210 🍚 (총 1234)". 재화를 받았으면 "이번 판 +210 🍚 +8 🍬 (총 1234)" (m5-07),
-- 🎫 티켓을 받았으면 "이번 판 +210 🍚 🎫 +1 (총 1234)" (m5-31)
function RewardLogic.summaryText(
	matchTotal: number,
	coins: number,
	tokens: number?,
	icon: string?,
	tickets: number?
): string
	local text = `이번 판 +{matchTotal} 🍚`
	if hasTokens(tokens) then
		text ..= ` +{tokens} {icon or "🍬"}`
	end
	if hasTokens(tickets) then
		text ..= ` 🎫 +{tickets}`
	end
	return `{text} (총 {coins})`
end

-- 받은 지급의 🎫 티켓 합계 (m5-31, 우승 화면 정산)
function RewardLogic.matchTicketTotal(grants: { read [number]: { read tickets: number? } }): number
	local total = 0
	for _, grant in grants do
		local tickets = grant.tickets
		if type(tickets) == "number" and tickets > 0 then
			total += tickets
		end
	end
	return total
end

-- 티켓 토스트 (m5-31): "+1 🎫 우승 뽑기 티켓", 가득이면 "🎫 티켓이 가득 찼어요 (99장)", 둘 다 아니면 nil
function RewardLogic.ticketToastText(tickets: number?, full: boolean?, max: number?): string?
	if hasTokens(tickets) then
		return `+{tickets} 🎫 우승 뽑기 티켓`
	end
	if full == true then
		return `🎫 티켓이 가득 찼어요 ({max or Config.Draw.MaxTickets}장)`
	end
	return nil
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

-- 라운드 출발 (MatchEvents.onRoundStart). 결승이면 레이서 전원에게 FinalQualify (이벤트 중이면 재화도).
function RewardLogic.onRoundStart(
	tracker: Tracker,
	roundIndex: number,
	roundCount: number,
	userIds: { number },
	now: number?
): { Grant }
	tracker.roundIndex = roundIndex
	tracker.roundCount = roundCount
	local grants: { Grant } = {}
	local amount = RewardLogic.forRoundStart(roundIndex, roundCount)
	if amount then
		local tokens, eventId = RewardLogic.tokensFor("FinalQualify", now)
		for _, userId in userIds do
			local grant: Grant =
				{ userId = userId, reason = "FinalQualify", amount = amount, tokens = tokens, eventId = eventId }
			table.insert(grants, grant)
		end
	end
	return grants
end

-- PlayerResult 하나 (MatchEvents.onResult). Passed는 결승이 아닐 때만, Won은 언제나 (이벤트 중이면 재화도).
function RewardLogic.onResult(tracker: Tracker, userId: number, result: ResultKind, now: number?): { Grant }
	if result == "Won" then
		local tokens, eventId = RewardLogic.tokensFor("Win", now)
		return {
			{
				userId = userId,
				reason = "Win",
				amount = RewardLogic.forWin(),
				tokens = tokens,
				eventId = eventId,
				tickets = Config.Draw.TicketsPerWin, -- m5-31: 이벤트 기간·VIP여도 같아요
			},
		}
	elseif result == "Passed" then
		local amount = RewardLogic.forPass(RewardLogic.isFinalRound(tracker))
		if amount then
			local tokens, eventId = RewardLogic.tokensFor("RoundPass", now)
			return { { userId = userId, reason = "RoundPass", amount = amount, tokens = tokens, eventId = eventId } }
		end
	end
	return {}
end

function RewardLogic.simulate(events: { SimEvent }): ({ [number]: number }, { [number]: number }, { [number]: number })
	local totals: { [number]: number } = {}
	local tokenTotals: { [number]: number } = {}
	local ticketTotals: { [number]: number } = {} -- m5-31
	local tracker = RewardLogic.newTracker()
	local function add(grants: { Grant })
		for _, grant in grants do
			totals[grant.userId] = (totals[grant.userId] or 0) + grant.amount
			local tokens = grant.tokens
			if tokens then
				tokenTotals[grant.userId] = (tokenTotals[grant.userId] or 0) + tokens
			end
			local tickets = grant.tickets
			if tickets then
				ticketTotals[grant.userId] = (ticketTotals[grant.userId] or 0) + tickets
			end
		end
	end
	for _, event in events do
		if event.kind == "RoundStart" then
			add(
				RewardLogic.onRoundStart(
					tracker,
					event.roundIndex :: number,
					event.roundCount :: number,
					event.userIds or {},
					event.now
				)
			)
		elseif event.kind == "Result" then
			add(RewardLogic.onResult(tracker, event.userId :: number, event.result :: ResultKind, event.now))
		elseif event.kind == "MatchEnd" then
			local lastDays = event.lastDays or {}
			local recipients = event.userIds or {}
			if event.participants then
				recipients = RewardLogic.matchEndRecipients(event.participants, recipients)
			end
			for _, userId in recipients do
				local payout = RewardLogic.matchEndPayout(lastDays[userId], event.today :: number, event.now)
				if payout then
					add({
						{
							userId = userId,
							reason = payout.reason,
							amount = payout.amount,
							tokens = payout.tokens,
							eventId = payout.eventId,
						},
					})
				end
			end
		end
	end
	return totals, tokenTotals, ticketTotals
end

return RewardLogic
