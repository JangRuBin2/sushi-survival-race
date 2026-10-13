--!strict
-- 코드 보상 판단 (m5-10, GDD 9.3·9.4). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/code-logic.spec.luau).
-- 코드 목록은 여기 없어요 — 서버 전용 src/server/CodeConfig.luau(로더)가 읽어서 CodeService에 넘겨요.
--   CodeLogic.normalize(raw) -> string?             앞뒤 공백 제거 → 대문자 → [A-Z0-9] 3~MaxLength자, 아니면 nil
--   CodeLogic.check(code?, entry?, now, redeemed, failures, failNow?) -> (ok, reason, countsAsFailure)
--       순서: Locked → Invalid(+1) → Unknown(+1) → NotStarted → Expired → AlreadyRedeemed
--       now는 코드 기간용 "지금"(Studio면 DEBUG.eventNow), failNow는 실패 기록용 실제 시각(없으면 now)
--   CodeLogic.recordFailure(list, now, window) -> number   창 밖 실패를 지우고 지금을 추가, 창 안 실패 수
--   CodeLogic.isLocked(list, now, window, max) -> boolean  창 안 실패가 max 이상
--   CodeLogic.rewardFor(entry, now, isActive?) -> Reward   이벤트 재화는 그 이벤트가 진행 중일 때만
--   CodeLogic.message(reason) -> string                    실패 문구 (한국어)
--   CodeLogic.successMessage(reward) -> string             "🍚 200 받았어요!" / "🍚 100 + 🍬 10 받았어요!"
--   CodeLogic.validateConfig(codes) -> (valid, problems)   형식·범위·중복 검사, 문제 있는 코드만 빼요

local Config = require(script.Parent.Config)
local Seasons = require(script.Parent.Seasons)

-- src/server/CodeConfig.luau의 CodeEntry와 같은 모양
export type CodeEntry = {
	code: string,
	coins: number,
	tokens: number?,
	eventId: string?,
	startsAt: number?,
	expiresAt: number?,
}

export type Reason =
	"Ok"
	| "Cooldown"
	| "Locked"
	| "Invalid"
	| "Unknown"
	| "NotStarted"
	| "Expired"
	| "AlreadyRedeemed"
	| "NoProfile"
	| "NotSaved"
	| "Error"

export type Reward = {
	coins: number,
	tokens: number?,
	eventId: string?,
}

local CodeLogic = {}

CodeLogic.MIN_LENGTH = 3
CodeLogic.MAX_COINS = 300 -- GDD 9.3
CodeLogic.MIN_TOKENS = 1
CodeLogic.MAX_TOKENS = 30
CodeLogic.MAX_RAW_LENGTH = 100 -- 이보다 긴 입력은 다듬기 전에 버려요 (서버 부담 방지)

local MESSAGES: { [Reason]: string } = {
	Ok = "받았어요!",
	Cooldown = "잠시 뒤에 다시 해 주세요",
	Locked = "잠시 뒤에 다시 해 주세요",
	Invalid = "없는 코드예요",
	Unknown = "없는 코드예요",
	NotStarted = "아직 쓸 수 없는 코드예요",
	Expired = "기간이 끝난 코드예요",
	AlreadyRedeemed = "이미 받은 코드예요",
	NoProfile = "프로필을 불러오는 중이에요",
	NotSaved = "저장이 안 되는 상태라 지금은 쓸 수 없어요",
	Error = "다시 해 주세요",
}

local function maxLength(): number
	return Config.Codes.MaxLength
end

local function isCodeShape(value: string): boolean
	return #value >= CodeLogic.MIN_LENGTH and #value <= maxLength() and string.match(value, "^[A-Z0-9]+$") ~= nil
end

function CodeLogic.normalize(raw: unknown): string?
	if type(raw) ~= "string" or #raw > CodeLogic.MAX_RAW_LENGTH then
		return nil
	end
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	local upper = string.upper(trimmed)
	if not isCodeShape(upper) then
		return nil
	end
	return upper
end

local function countRecent(list: { number }, now: number, window: number): number
	local count = 0
	for _, at in list do
		if now - at < window then
			count += 1
		end
	end
	return count
end

function CodeLogic.isLocked(list: { number }, now: number, window: number, max: number): boolean
	return countRecent(list, now, window) >= max
end

-- 창(window) 밖의 실패를 지우고 now를 추가해요. 돌려주는 값은 추가한 뒤 창 안 실패 수.
function CodeLogic.recordFailure(list: { number }, now: number, window: number): number
	for i = #list, 1, -1 do
		if now - list[i] >= window then
			table.remove(list, i)
		end
	end
	table.insert(list, now)
	return countRecent(list, now, window)
end

function CodeLogic.check(
	code: string?,
	entry: CodeEntry?,
	now: number,
	redeemed: { [string]: number },
	failures: { number },
	failNow: number?
): (boolean, Reason, boolean)
	local settings = Config.Codes
	if CodeLogic.isLocked(failures, failNow or now, settings.FailureWindow, settings.MaxFailures) then
		return false, "Locked", false
	end
	if code == nil then
		return false, "Invalid", true
	end
	if entry == nil or entry.code ~= code then
		return false, "Unknown", true
	end
	if entry.startsAt ~= nil and now < entry.startsAt then
		return false, "NotStarted", false
	end
	if entry.expiresAt ~= nil and now >= entry.expiresAt then
		return false, "Expired", false
	end
	if redeemed[code] ~= nil then
		return false, "AlreadyRedeemed", false
	end
	return true, "Ok", false
end

function CodeLogic.rewardFor(entry: CodeEntry, now: number, isActive: ((id: string, now: number) -> boolean)?): Reward
	local reward: Reward = { coins = entry.coins }
	local eventId = entry.eventId
	local tokens = entry.tokens
	if eventId ~= nil and tokens ~= nil and tokens > 0 then
		local active = (isActive or Seasons.isActive)(eventId, now)
		if active then
			reward.tokens = tokens
			reward.eventId = eventId
		end
	end
	return reward
end

function CodeLogic.message(reason: Reason): string
	return MESSAGES[reason] or MESSAGES.Error
end

function CodeLogic.successMessage(reward: Reward): string
	local parts: { string } = {}
	local tokens = reward.tokens
	local eventId = reward.eventId
	if reward.coins > 0 or tokens == nil then
		table.insert(parts, `🍚 {reward.coins}`)
	end
	if tokens ~= nil and eventId ~= nil then
		local event = Seasons.get(eventId)
		local icon = if event then event.token.icon else "🎟"
		table.insert(parts, `{icon} {tokens}`)
	end
	return `{table.concat(parts, " + ")} 받았어요!`
end

local function isInteger(value: any, low: number, high: number): boolean
	return type(value) == "number" and value == value and math.floor(value) == value and value >= low and value <= high
end

local function optionalTime(value: any): boolean
	return value == nil or (type(value) == "number" and value == value and math.abs(value) ~= math.huge)
end

-- 서버 시작 때 한 번. 문제가 있는 코드는 빼고 (valid에 안 넣고) 이유를 problems에 적어요. 중복은 처음 것만 남겨요.
function CodeLogic.validateConfig(codes: { any }): ({ CodeEntry }, { string })
	local valid: { CodeEntry } = {}
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}
	for index, entry in codes do
		if type(entry) ~= "table" then
			table.insert(problems, `#{index}: not a table`)
			continue
		end
		local code = entry.code
		if type(code) ~= "string" then
			table.insert(problems, `#{index}: code must be a string`)
			continue
		end
		local label = `#{index} ({code})`
		local folded = string.upper(code)
		local bad: { string } = {}
		if seen[folded] then
			table.insert(bad, "duplicate code (case-insensitive)")
		end
		if not isCodeShape(code) then
			table.insert(bad, `code must be A-Z/0-9 only, {CodeLogic.MIN_LENGTH}~{maxLength()} chars`)
		end
		if not isInteger(entry.coins, 0, CodeLogic.MAX_COINS) then
			table.insert(bad, `coins must be an integer 0~{CodeLogic.MAX_COINS}`)
		end
		if entry.tokens ~= nil then
			if not isInteger(entry.tokens, CodeLogic.MIN_TOKENS, CodeLogic.MAX_TOKENS) then
				table.insert(bad, `tokens must be an integer {CodeLogic.MIN_TOKENS}~{CodeLogic.MAX_TOKENS}`)
			end
			if entry.eventId == nil then
				table.insert(bad, "tokens need an eventId")
			end
		end
		if entry.eventId ~= nil and (type(entry.eventId) ~= "string" or Seasons.get(entry.eventId) == nil) then
			table.insert(bad, `unknown eventId {tostring(entry.eventId)}`)
		end
		if not optionalTime(entry.startsAt) or not optionalTime(entry.expiresAt) then
			table.insert(bad, "startsAt/expiresAt must be numbers (UTC unix seconds) or nil")
		elseif entry.startsAt ~= nil and entry.expiresAt ~= nil and entry.startsAt >= entry.expiresAt then
			table.insert(bad, "startsAt must be before expiresAt")
		end
		seen[folded] = true
		if #bad > 0 then
			table.insert(problems, `{label}: {table.concat(bad, ", ")}`)
			continue
		end
		table.insert(valid, {
			code = code,
			coins = entry.coins,
			tokens = entry.tokens,
			eventId = entry.eventId,
			startsAt = entry.startsAt,
			expiresAt = entry.expiresAt,
		})
	end
	return valid, problems
end

return CodeLogic
