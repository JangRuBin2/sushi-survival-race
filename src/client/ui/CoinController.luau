--!strict
-- 밥알 코인 배지·지급 토스트·매치 정산 한 줄 (m4-08). ProfileStore·RewardGranted·MatchPhase를 써요.
--   배지: ProfileStore.changed로 코인 수와 "(저장 안 됨)"을 갱신해요. 로비·매치·관전 모두 보여요.
--   토스트: RewardGranted가 올 때마다 "+10 🍚 라운드 통과" (1.5초, 여러 개면 줄 세움).
--   정산: Victory가 오면 우승 연출(Config.Match.VictoryCutscene) 뒤 순위표 시간 동안
--     "이번 판 +{합계} 🍚 (총 {coins})". 합계는 이번 매치(Starting부터) 받은 RewardGranted의 합이에요.
-- 표시만 해요 — 코인은 서버(RewardService)만 지급해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardLogic = require(ReplicatedStorage.Shared.RewardLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local CoinScreen = require(script.Parent.CoinScreen)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local UiScaleController = require(script.Parent.UiScaleController)

local CoinController = {}

function CoinController.start(_gui: Instance)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = CoinScreen.new(playerGui)
	for _, screenGui in screen.guis do
		UiScaleController.attach(screenGui)
	end

	local coins = 0
	local matchGrants: { Types.RewardGrant } = {}
	local summaryShowing = false
	local summaryToken = 0

	local function refreshSummary()
		if summaryShowing then
			screen:showSummary(RewardLogic.summaryText(RewardLogic.matchTotal(matchGrants), coins))
		end
	end

	local function hideSummary()
		summaryToken += 1
		summaryShowing = false
		screen:hideSummary()
	end

	local function applyView(view: Types.ProfileView)
		coins = view.coins
		screen:setCoins(view.coins, view.persistent)
		refreshSummary()
	end

	ProfileStore.changed(applyView)
	local current = ProfileStore.get()
	if current then
		applyView(current)
	end

	Remotes.event("RewardGranted").OnClientEvent:Connect(function(grant: unknown)
		if type(grant) ~= "table" then
			return
		end
		local info = grant :: Types.RewardGrant
		if type(info.amount) ~= "number" or type(info.total) ~= "number" then
			return
		end
		table.insert(matchGrants, info)
		coins = math.max(coins, info.total)
		screen:toast(RewardLogic.toastText(info.reason, info.amount))
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
