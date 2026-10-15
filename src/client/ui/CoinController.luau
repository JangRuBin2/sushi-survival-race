--!strict
-- 밥알 코인 배지·지급 토스트·매치 정산 한 줄 (m4-08). ProfileStore·RewardGranted·MatchPhase를 써요.
--   배지: ProfileStore.changed로 코인 수와 "(저장 안 됨)"을 갱신해요. 로비·매치·관전 모두 보여요.
--   토스트: RewardGranted가 올 때마다 "+10 🍚 라운드 통과" (1.5초, 여러 개면 줄 세움).
--   정산: Victory가 오면 우승 연출(Config.Match.VictoryCutscene) 뒤 순위표 시간 동안
--     "이번 판 +{합계} 🍚 (총 {coins})". 합계는 이번 매치(Starting부터) 받은 RewardGranted의 합이에요.
--   이벤트 재화 (m5-07): 시즌 이벤트가 진행 중이면 배지 옆 "🍬 32"(이번 이벤트 재화, 없으면 숨김),
--     토스트 "+10 🍚 +1 🍬 라운드 통과"/"+1 🍬 판 참가" + 효과음 TokenGet, 정산에 "+M 🍬"(이번 판 합계).
--     지금 시각 = Seasons.now(Studio, Config.DEBUG.eventNow, workspace:GetServerTimeNow()), 1분마다 다시 봐요.
--   🎫 우승자 뽑기 티켓 (m5-31): 우승 지급에 tickets가 있으면 토스트 "+1 🎫 우승 뽑기권"(가득이면
--     "🎫 뽑기권이 가득 찼어요 (99장)"), 정산 줄에 "🎫 +1".
-- 표시만 해요 — 코인·재화·티켓은 서버(RewardService)만 지급해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardLogic = require(ReplicatedStorage.Shared.RewardLogic)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Types = require(ReplicatedStorage.Shared.Types)
local CoinScreen = require(script.Parent.CoinScreen)
local Loc = require(script.Parent.Parent.Loc)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local Sfx = require(script.Parent.Parent.Sfx)
local UiScaleController = require(script.Parent.UiScaleController)

local CoinController = {}

local EVENT_CHECK_INTERVAL = 60 -- 초: 이벤트가 시작·끝났는지 다시 봐요

local function currentEvent(): Seasons.Event?
	return Seasons.current(Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, workspace:GetServerTimeNow()))
end

local function iconOf(eventId: string?): string?
	local event = if eventId then Seasons.get(eventId) else nil
	return if event then event.token.icon else nil
end

function CoinController.start(_gui: Instance)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = CoinScreen.new(playerGui)
	for _, screenGui in screen.guis do
		UiScaleController.attach(screenGui)
	end

	local coins = 0
	local eventTokens: { [string]: number } = {}
	local matchGrants: { Types.RewardGrant } = {}
	local summaryShowing = false
	local summaryToken = 0

	local function refreshTokens()
		local event = currentEvent()
		if event == nil then
			screen:setTokens(nil)
			return
		end
		screen:setTokens(`{event.token.icon} {eventTokens[event.id] or 0}`)
	end

	local function refreshSummary()
		if summaryShowing then
			local tokens = RewardLogic.matchTokenTotal(matchGrants)
			local icon: string? = nil
			for _, grant in matchGrants do
				icon = iconOf(grant.eventId) or icon
			end
			local tickets = RewardLogic.matchTicketTotal(matchGrants)
			screen:showSummary(
				Loc.text(RewardLogic.summaryText(RewardLogic.matchTotal(matchGrants), coins, tokens, icon, tickets))
			)
		end
	end

	local function hideSummary()
		summaryToken += 1
		summaryShowing = false
		screen:hideSummary()
	end

	local function applyView(view: Types.ProfileView)
		coins = view.coins
		eventTokens = if type(view.eventTokens) == "table" then view.eventTokens else {}
		screen:setCoins(view.coins, view.persistent)
		refreshTokens()
		refreshSummary()
	end

	ProfileStore.changed(applyView)
	local current = ProfileStore.get()
	if current then
		applyView(current)
	else
		refreshTokens()
	end

	task.spawn(function()
		while true do
			task.wait(EVENT_CHECK_INTERVAL)
			refreshTokens()
		end
	end)

	Remotes.event("RewardGranted").OnClientEvent:Connect(function(grant: unknown)
		if type(grant) ~= "table" then
			return
		end
		local info = grant :: Types.RewardGrant
		if type(info.amount) ~= "number" or type(info.total) ~= "number" then
			return
		end
		local tokens = if type(info.tokens) == "number" and info.tokens > 0 then info.tokens else nil
		table.insert(matchGrants, info)
		coins = math.max(coins, info.total)
		local eventId = info.eventId
		if tokens and type(eventId) == "string" and type(info.tokenTotal) == "number" then
			eventTokens = table.clone(eventTokens)
			eventTokens[eventId] = math.max(eventTokens[eventId] or 0, info.tokenTotal)
			refreshTokens()
		end
		screen:toast(Loc.text(RewardLogic.toastText(info.reason, info.amount, tokens, iconOf(eventId))))
		if tokens then
			Sfx.play("TokenGet")
		end
		local ticketText = RewardLogic.ticketToastText(
			if type(info.tickets) == "number" then info.tickets else nil,
			info.ticketsFull == true
		)
		if ticketText then
			screen:toast(ticketText)
		end
		refreshSummary()
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if info.phase == "Starting" then
			table.clear(matchGrants)
			hideSummary()
		elseif info.phase == "Victory" then
			hideSummary()
			local token = summaryToken
			local showFor = Config.Match.VictoryDuration - Config.Match.VictoryCutscene
			task.delay(Config.Match.VictoryCutscene, function()
				if token ~= summaryToken then
					return
				end
				summaryShowing = true
				refreshSummary()
				task.delay(showFor, function()
					if token == summaryToken then
						hideSummary()
					end
				end)
			end)
		else
			hideSummary()
		end
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		if room == nil or room.state ~= "InMatch" then
			hideSummary()
		end
	end)
end

return CoinController
