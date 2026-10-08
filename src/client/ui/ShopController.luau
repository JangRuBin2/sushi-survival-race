--!strict
-- 탈의실 (m4-13). ShopScreen에 내 프로필(ProfileStore)을 그리고 EquipSkin·BuyWithCoins를 서버에 요청해요.
-- 판정(보유·가격·코인·라운드 중 금지)은 서버 ShopService가 해요. 여기서는 보여 주기와 요청만.
--   "🍣 스킨" 버튼이 보이는 때: 로비·방 대기실, 매치 중이면 내가 달리지 않을 때(탈락해 관전 중, 통과해 대기석,
--   라운드 결과 사이). 시작 카운트다운·라운드 소개·달리는 중·우승 연출 동안은 숨기고 창도 닫아요.
--   매치 서버(m4-11)는 매치가 시작되기 전(연결 중 안내)에는 숨겨요.

--   로벅스 (m4-14): RequestRobuxPurchase → 서버가 Roblox 결제 창을 띄워요 (Studio 가짜 결제면 바로 처리).
--   지급은 서버 ProcessReceipt가 해요. 여기서는 요청한 스킨이 ProfileUpdated로 보유에 들어오면 "🎉 획득!" 한 줄.
--   상품 id가 있는 스킨은 MarketplaceService:GetProductInfo의 실제 가격을 받아 보여 줘요 (실패하면 카탈로그 값).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local ShopScreen = require(script.Parent.ShopScreen)
local UiScaleController = require(script.Parent.UiScaleController)

local ShopController = {}

function ShopController.start(_gui: Instance)
	local me = Players.LocalPlayer
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"

	local tier: Skins.Tier? = nil
	local selected = Skins.DEFAULT_ID
	local busy = false
	local view: Types.ProfileView? = ProfileStore.get()
	local screen: ShopScreen.ShopScreen
	local robux: ShopLogic.RobuxOptions = {
		fake = ShopLogic.fakeRobuxActive(
			RunService:IsStudio(),
			Config.DEBUG.fakeRobuxInStudio,
			Config.DEBUG.persistDataInStudio
		),
		prices = {},
	}
	local pending: { [string]: boolean } = {} -- 로벅스 결제를 요청한 스킨 (보유에 들어오면 획득 안내)

	-- 매치 상태 (버튼을 보일지)
	local room: Types.RoomSnapshot? = nil
	local phase: Types.MatchPhase? = nil
	local alive = true -- 이 매치에서 아직 탈락하지 않았는지
	local passed = false -- 이번 라운드를 통과해 대기석에 있는지
	local hiddenUntil = 0 -- os.clock(): 탈락 연출이 끝나는 시각 (그때까지 버튼 숨김)

	local function render()
		local current = view
		if current == nil or screen == nil then
			return
		end
		screen:render(current, tier, selected, robux)
	end

	local function canShow(): boolean
		local inMatch = room ~= nil and room.state == "InMatch"
		if not inMatch then
			return not isMatchServer
		end
		if phase == "Starting" or phase == "Victory" or phase == nil then
			return false
		end
		if not alive then
			-- 관전 중. 단 탈락 연출 동안은 서버가 장착을 잠가서 숨겨요 (m4-13 QA N1)
			return os.clock() >= hiddenUntil
		end
		if phase == "RoundResults" then
			return true -- 라운드 사이 대기석
		end
		return passed -- 라운드 소개·진행 중: 통과해서 대기석에 있을 때만
	end

	local function refreshVisibility()
		local visible = canShow() and view ~= nil
		screen:setButtonVisible(visible)
		if not visible and screen:isOpen() then
			screen:setOpen(false)
		end
	end

	local function request(name: string, skinId: string): (boolean, string?)
		local remote = Remotes.fn(name)
		local called, ok, err = pcall(remote.InvokeServer, remote, skinId)
		if not called then
			return false, "서버와 연결이 불안정해요"
		end
		return ok == true, if type(err) == "string" then err else nil
	end

	local function buyRobux(skinId: string)
		local current = view
		local skin = Skins.get(skinId)
		if busy or current == nil or skin == nil or table.find(current.ownedSkins, skinId) then
			return
		end
		if not ShopLogic.robuxOpen(skin, robux.fake) then
			return -- 상품 id가 아직 없어요 (버튼 비활성)
		end
		busy = true
		screen:setBusy(true)
		local ok, err = request("RequestRobuxPurchase", skinId)
		busy = false
		screen:setBusy(false)
		if ok then
			pending[skinId] = true
			screen:showResult(
				if robux.fake then "가짜 결제 처리 중…" else "결제 창을 확인해 주세요",
				false
			)
		else
			screen:showResult(err or "다시 해 주세요", true)
		end
	end

	local function act(skinId: string)
		local current = view
		local skin = Skins.get(skinId)
		if busy or current == nil or skin == nil then
			return
		end
		local owned = table.find(current.ownedSkins, skinId) ~= nil or skinId == Skins.DEFAULT_ID
		if current.equippedSkin == skinId then
			return
		end
		local name = if owned then "EquipSkin" elseif skin.coins then "BuyWithCoins" else nil
		if name == nil then
			buyRobux(skinId) -- 레어 이상: 행동 버튼이 로벅스 버튼
			return
		end
		busy = true
		screen:setBusy(true)
		local ok, err = request(name, skinId)
		busy = false
		screen:setBusy(false)
		if ok then
			screen:showResult(if owned then `{skin.displayName} 입었어요!` else `{skin.displayName} 해금!`, false)
		else
			screen:showResult(err or "다시 해 주세요", true)
		end
	end

	screen = ShopScreen.new(me:WaitForChild("PlayerGui"), {
		open = function()
			if view == nil then
				return
			end
			selected = (view :: Types.ProfileView).equippedSkin
			render()
			screen:setOpen(true)
		end,
		close = function()
			screen:setOpen(false)
		end,
		select = function(skinId: string)
			selected = skinId
			render()
		end,
		act = act,
		buyRobux = buyRobux,
		tab = function(newTier: Skins.Tier?)
			tier = newTier
			render()
		end,
	})
	UiScaleController.attach(screen.gui)
	UiScaleController.onChanged(function(m)
		screen:setLayout(m)
	end)

	-- 결제 창을 취소하면 기다리던 스킨을 지워요 (나중에 코인으로 해금해도 "획득!"이 안 나오게, m4-14 QA R3)
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, isPurchased: boolean)
			if userId ~= me.UserId or isPurchased then
				return
			end
			local skin = Skins.forProduct(productId)
			if skin then
				pending[skin.id] = nil
			end
		end
	)

	ProfileStore.changed(function(newView: Types.ProfileView)
		view = newView
		-- 로벅스로 산 스킨이 들어왔어요 (서버가 지급 + 장착)
		local got: string? = nil
		for skinId in table.clone(pending) do
			if table.find(newView.ownedSkins, skinId) then
				pending[skinId] = nil
				local skin = Skins.get(skinId)
				if skin then
					selected = skinId
					got = `🎉 {skin.displayName} 획득!`
				end
			end
		end
		render()
		refreshVisibility()
		if got then
			screen:showResult(got, false)
		end
	end)

	-- 실제 상품 가격 (상품 id가 있는 스킨만, 한 번)
	for _, skin in Skins.LIST do
		local productId = skin.productId
		if productId == nil then
			continue
		end
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
			end)
			local price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" and price > 0 then
				(robux.prices :: { [string]: number })[skin.id] = price
				render()
			end
		end)
	end

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
		local wasInMatch = room ~= nil and room.state == "InMatch"
		room = snapshot
		local inMatch = snapshot ~= nil and snapshot.state == "InMatch"
		if not inMatch or not wasInMatch then
			-- 매치 밖이거나 새 매치: 매치 상태를 처음으로
			phase = nil
			alive = true
			passed = false
		end
		refreshVisibility()
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if type(info) ~= "table" then
			return
		end
		phase = info.phase
		if info.phase == "Starting" then
			alive = true
			passed = false
		elseif info.phase == "RoundIntro" then
			passed = false
		end
		local ids = info.aliveUserIds
		if ids then
			alive = table.find(ids, me.UserId) ~= nil
		end
		refreshVisibility()
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if type(result) ~= "table" or result.userId ~= me.UserId then
			return
		end
		if result.result == "Eliminated" then
			alive = false
			if result.cause ~= "Left" then
				-- 서버 ShopService.isLocked와 같은 시간 (Config.Match.EliminationCutscene)
				hiddenUntil = os.clock() + Config.Match.EliminationCutscene
				task.delay(Config.Match.EliminationCutscene, refreshVisibility)
			end
		elseif result.result == "Passed" then
			passed = true
		end
		refreshVisibility()
	end)

	render()
	refreshVisibility()
end

return ShopController
