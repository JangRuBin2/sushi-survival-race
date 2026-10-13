--!strict
-- 코드 보상 서비스 (m5-10, GDD 9.3·9.4·11.4). 판단은 순수 Shared.CodeLogic, 지급은 여기서 DataService.update 한 번.
--   RedeemCode(code)  코드 보상 받기 → (ok, 문구)
-- 코드 목록은 서버 전용 CodeConfig.load()(로컬 CodeList.luau, 커밋 안 함)에서 시작 때 한 번 읽고
-- CodeLogic.validateConfig로 걸러요 (문제 있는 코드만 빼고 warn). 목록은 클라이언트로 보내지 않아요.
-- 남용 방지 (플레이어별 서버 메모리, 나가면 지움):
--   요청 간격 Config.Codes.RequestCooldown(실패로 안 셈), FailureWindow 안 실패 MaxFailures번이면 잠금.
--   실패로 세는 것은 형식 오류·없는 코드뿐 (진짜 코드의 시작 전·만료·이미 받음은 안 셈, 결정 D2).
-- 코드 기간·이벤트 재화는 Seasons.now(Studio면 Config.DEBUG.eventNow), 실패 기록·redeemedCodes 시각은 실제 os.time().
-- 로그: 성공 `[Code] 이름(UserId) redeemed CODE +200`, 잠금 순간 `[Code] 이름(UserId) locked after 8 failures`
-- (실패 로그에는 코드 문자열을 남기지 않아요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CodeLogic = require(ReplicatedStorage.Shared.CodeLogic)
local Config = require(ReplicatedStorage.Shared.Config)
local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Types = require(ReplicatedStorage.Shared.Types)

local CodeConfig = require(script.Parent.CodeConfig)
local DataService = require(script.Parent.DataService)

type State = {
	lastAt: number, -- os.clock() 마지막 요청
	failures: { number }, -- os.time() 실패 시각
}

local CodeService = {}

local byCode: { [string]: CodeLogic.CodeEntry } = {}
local count = 0
local states: { [Player]: State } = {}
local rewardGrantedEvent: RemoteEvent

local function who(player: Player): string
	return `{player.Name}({player.UserId})`
end

local function stateOf(player: Player): State
	local state = states[player]
	if state == nil then
		state = { lastAt = -math.huge, failures = {} }
		states[player] = state
	end
	return state
end

local function fail(
	player: Player,
	state: State,
	reason: CodeLogic.Reason,
	counts: boolean,
	realNow: number
): (boolean, Types.LocText)
	if counts then
		local settings = Config.Codes
		local recent = CodeLogic.recordFailure(state.failures, realNow, settings.FailureWindow)
		if recent == settings.MaxFailures then
			print(`[Code] {who(player)} locked after {recent} failures`)
		end
	end
	return false, CodeLogic.message(reason)
end

local function redeem(player: Player, raw: unknown): (boolean, Types.LocText)
	local state = stateOf(player)
	local clock = os.clock()
	if clock - state.lastAt < Config.Codes.RequestCooldown then
		return false, CodeLogic.message("Cooldown")
	end
	state.lastAt = clock

	local isStudio = RunService:IsStudio()
	local realNow = os.time()
	local now = Seasons.now(isStudio, Config.DEBUG.eventNow, realNow)
	local code = CodeLogic.normalize(raw)
	local entry = if code then byCode[code] else nil
	local profile = DataService.get(player)
	local redeemed = if profile then profile.redeemedCodes else {}

	local ok, reason, counts = CodeLogic.check(code, entry, now, redeemed, state.failures, realNow)
	if not ok or code == nil or entry == nil then
		return fail(player, state, reason, counts, realNow)
	end
	if profile == nil then
		return false, CodeLogic.message("NoProfile")
	end
	local persist = DataService.canPersist(player)
	if not persist and not isStudio then
		return false, CodeLogic.message("NotSaved")
	end

	local reward = CodeLogic.rewardFor(entry, now)
	local granted = false
	local total = 0
	local tokenTotal: number? = nil
	local updated = DataService.update(player, function(p)
		if p.redeemedCodes[code] ~= nil then
			return -- 같은 틱에 두 번 들어온 경우 방어
		end
		p.redeemedCodes[code] = realNow
		p.coins += reward.coins
		local eventId, tokens = reward.eventId, reward.tokens
		if eventId ~= nil and tokens ~= nil then
			local sum = (p.eventTokens[eventId] or 0) + tokens
			p.eventTokens[eventId] = sum
			tokenTotal = sum
		end
		total = p.coins
		granted = true
	end)
	if not updated then
		return false, CodeLogic.message("NoProfile")
	end
	if not granted then
		return false, CodeLogic.message("AlreadyRedeemed")
	end
	if persist then
		task.spawn(DataService.saveNow, player)
	end

	local grant: Types.RewardGrant = {
		reason = "Code",
		amount = reward.coins,
		total = total,
		tokens = reward.tokens,
		tokenTotal = tokenTotal,
		eventId = reward.eventId,
	}
	if player.Parent ~= nil then
		rewardGrantedEvent:FireClient(player, grant)
	end
	local extra = if reward.tokens then ` +{reward.tokens} {reward.eventId}` else ""
	print(`[Code] {who(player)} redeemed {code} +{reward.coins}{extra}`)
	return true, CodeLogic.successMessage(reward)
end

function CodeService.init()
	local valid, problems = CodeLogic.validateConfig(CodeConfig.load())
	for _, problem in problems do
		warn(`[Code] CodeList entry skipped: {problem}`)
	end
	table.clear(byCode) -- 코드 목록 크기로 정해진 표 (서버 시작 때 한 번 채움)
	for _, entry in valid do
		byCode[entry.code] = entry
	end
	count = #valid
	rewardGrantedEvent = Remotes.event("RewardGranted")
	Remotes.fn("RedeemCode").OnServerInvoke = function(player: Player, raw: unknown): (boolean, Types.LocText)
		local called, ok, text = pcall(redeem, player, raw)
		if not called then
			warn(`[Code] redeem failed for {who(player)}: {ok}`)
			return false, CodeLogic.message("Error")
		end
		return ok, text
	end
end

function CodeService.start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

-- 읽은 (검사를 통과한) 코드 수 — 디버그용
function CodeService.count(): number
	return count
end

return CodeService
