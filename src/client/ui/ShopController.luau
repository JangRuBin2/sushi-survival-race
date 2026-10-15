--!strict
-- 탈의실 (m4-13). ShopScreen에 내 프로필(ProfileStore)을 그리고 EquipSkin·BuyWithCoins를 서버에 요청해요.
-- 판정(보유·가격·코인·라운드 중 금지)은 서버 ShopService가 해요. 여기서는 보여 주기와 요청만.
--   "🍣 스킨" 버튼이 보이는 때: 로비·방 대기실, 매치 중이면 내가 달리지 않을 때(탈락해 관전 중, 통과해 대기석,
--   라운드 결과 사이). 시작 카운트다운·라운드 소개·달리는 중·우승 연출 동안은 숨기고 창도 닫아요.
--   매치 서버(m4-11)는 매치가 시작되기 전(연결 중 안내)에는 숨겨요.

--   로벅스 (m4-14): RequestRobuxPurchase → 서버가 Roblox 결제 창을 띄워요 (Studio 가짜 결제면 바로 처리).
--   지급은 서버 ProcessReceipt가 해요. 여기서는 요청한 스킨이 ProfileUpdated로 보유에 들어오면 "🎉 획득!" 한 줄.
--   상품 id가 있는 스킨은 PriceCache.product(실제 상품 가격, 지역 가격 준비 — m5-07)로 보여 줘요 (실패하면 카탈로그 값).
--   시즌 이벤트 (m5-07): 지금 시각 = Seasons.now(Studio, Config.DEBUG.eventNow, workspace:GetServerTimeNow()).
--   탈의실을 열면 ShopLogic.defaultTab(이벤트 중이면 이벤트 탭)이 먼저 선택돼요. 재화 스킨의 "🍬 80으로 받기"는
--   BuyWithTokens (판정은 서버 ShopService).
--   🎫 뽑기 (m5-31): 탈의실 머리줄 "🎫 뽑기" 또는 안 가진 특 스킨 카드 → DrawScreen. "뽑기 시작하기"는 DrawTicket
--   (인자 없음, 결과는 서버). 두근두근 연출(DrawScreen.SUSPENSE_TIME) 뒤 결과 창. 탈의실 버튼이 숨으면(라운드 중) 같이 닫혀요.
--   티켓이 있으면 "🍣 스킨" 버튼에 빨간 숫자 배지. Studio 전부 입기(view.studioUnlockAll)면 안 가진 스킨도 EquipSkin.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Types = require(ReplicatedStorage.Shared.Types)
local Loc = require(script.Parent.Parent.Loc)
local PriceCache = require(script.Parent.Parent.PriceCache)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local DrawLogic = require(ReplicatedStorage.Shared.DrawLogic)
local DrawScreen = require(script.Parent.DrawScreen)
local ShopScreen = require(script.Parent.ShopScreen)
local Sfx = require(script.Parent.Parent.Sfx)
local UiScaleController = require(script.Parent.UiScaleController)

local ShopController = {}

-- 시즌 판매 기간을 볼 "지금 시각" (서버와 같은 규칙: Studio면 Config.DEBUG.eventNow 우선)
local function eventNow(): number
	return Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, workspace:GetServerTimeNow())
end

function ShopController.start(_gui: Instance)
	local me = Players.LocalPlayer
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"

	local tabId = "all" -- ShopLogic.Tab.id
	local selected = Skins.DEFAULT_ID
	local busy = false
	local view: Types.ProfileView? = ProfileStore.get()
	local screen: ShopScreen.ShopScreen
	local drawScreen: DrawScreen.DrawScreen
	local drawing = false -- DrawTicket 요청~결과 연출 중
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
		local now = eventNow()
		local tabs = ShopLogic.tabs(now)
		local tab = tabs[1]
		for _, candidate in tabs do
			if candidate.id == tabId then
				tab = candidate
			end
		end
		tabId = tab.id -- 이벤트가 끝나 탭이 없어졌으면 맨 앞 탭으로
		local header: string? = nil
		local event = if tab.eventId then Seasons.get(tab.eventId) else nil
		if event then
			header = Loc.text(ShopLogic.eventHeader(event, now, ShopLogic.tokensOf(current, event.id)))
		end
		screen:render({
			view = current,
			tab = tab,
			tabs = tabs,
			selected = selected,
			robux = robux,
			now = now,
			eventHeader = header,
		})
		local tickets = current.drawTickets or 0
		screen:setTickets(tickets)
		if drawScreen then
			drawScreen:render({
				tickets = tickets,
				ownedSkins = current.ownedSkins,
				equippedSkin = current.equippedSkin,
				studioUnlockAll = current.studioUnlockAll == true,
				disabledReason = if tickets <= 0 then DrawLogic.message("NoTickets") else nil,
			})
		end
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
		if not visible and drawScreen and drawScreen:isOpen() then
			drawScreen:setOpen(false) -- 라운드 소개·달리는 중·연출 중에는 뽑기 화면도 닫아요 (서버도 Locked로 거절)
		end
	end

	local function request(name: string, skinId: string): (boolean, string?)
		local remote = Remotes.fn(name)
		local called, ok, err = pcall(remote.InvokeServer, remote, skinId)
		if not called then
			return false, Loc.t("common.err.connection")
		end
		local message = if err ~= nil then Loc.text(err) else ""
		return ok == true, if message ~= "" then message else nil
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
			screen:showResult(if robux.fake then Loc.t("shop.fakePaying") else Loc.t("shop.checkPrompt"), false)
		else
			screen:showResult(err or Loc.t("common.err.retry"), true)
		end
	end

	local function openDraw()
		if view == nil then
			return
		end
		render()
		drawScreen:setOpen(true)
	end

	-- 🎫 뽑기 (m5-31): 서버가 결과를 정해요. 두근두근을 최소 SUSPENSE_TIME 보여 준 뒤 결과
	local function runDraw()
		if drawing then
			return
		end
		drawing = true
		drawScreen:suspense()
		Sfx.play("ButtonClick")
		local started = os.clock()
		local remote = Remotes.fn("DrawTicket")
		local called, ok, err, result = pcall(remote.InvokeServer, remote)
		local left = DrawScreen.SUSPENSE_TIME - (os.clock() - started)
		if left > 0 then
			task.wait(left)
		end
		drawing = false
		if called and ok == true and type(result) == "table" then
			local drawResult = result :: Types.DrawResult
			Sfx.play(if drawResult.kind == "Skin" then "DrawWin" else "DrawReveal")
			drawScreen:reveal(drawResult)
		else
			local message = if not called
				then "서버와 연결이 불안정해요"
				elseif type(err) == "string" then err
				else "다시 해 주세요"
			drawScreen:showMessage(message, true)
		end
		render()
	end

	local function act(skinId: string)
		local current = view
		local skin = Skins.get(skinId)
		if busy or current == nil or skin == nil then
			return
		end
		local owned = table.find(current.ownedSkins, skinId) ~= nil
			or Skins.isFree(skinId)
			or current.studioUnlockAll == true -- Studio 전부 입기 (m5-31, 저장 안 함)
		if current.equippedSkin == skinId then
			return
		end
		if not owned and Skins.isDrawOnly(skinId) then
			openDraw() -- 특 스킨은 뽑기로만 (m5-31)
			return
		end
		local name = if owned
			then "EquipSkin"
			elseif skin.coins then "BuyWithCoins"
			elseif skin.tokens then "BuyWithTokens"
			else nil
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
			local skinName = Loc.skinName(skin.id)
			local done = if owned
				then Loc.t("shop.result.worn", { name = skinName })
				elseif name == "BuyWithTokens" then Loc.t("shop.result.gotTokens", { name = skinName })
				else Loc.t("shop.result.unlocked", { name = skinName })
			screen:showResult(done, false)
		else
			screen:showResult(err or Loc.t("common.err.retry"), true)
		end
	end

	screen = ShopScreen.new(me:WaitForChild("PlayerGui"), {
		open = function()
			if view == nil then
				return
			end
			selected = (view :: Types.ProfileView).equippedSkin
			tabId = ShopLogic.defaultTab(eventNow()).id -- 이벤트 중이면 이벤트 탭이 먼저
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
		tab = function(newTabId: string)
			tabId = newTabId
			render()
		end,
		openDraw = openDraw,
	})
	UiScaleController.attach(screen.gui)

	-- 🎫 뽑기 화면 (m5-31)
	drawScreen = DrawScreen.new(me:WaitForChild("PlayerGui"), {
		close = function()
			drawScreen:setOpen(false)
		end,
		draw = function()
			task.spawn(runDraw)
		end,
		wear = function(skinId: string)
			task.spawn(function()
				local ok, err = request("EquipSkin", skinId)
				if ok then
					local skin = Skins.get(skinId)
					drawScreen:showMessage(`{if skin then skin.displayName else skinId} 입었어요!`, false)
				else
					drawScreen:showMessage(err or "다시 해 주세요", true)
				end
			end)
		end,
		-- m5-32: 뽑기 + 판매 스킨(고등어 [신선]) 상세의 로벅스 구매 — 탈의실과 같은 흐름(RequestRobuxPurchase)
		buyRobux = function(skinId: string)
			task.spawn(buyRobux, skinId)
			drawScreen:showMessage(
				if robux.fake then "가짜 결제 처리 중…" else "결제 창을 확인해 주세요",
				false
			)
		end,
		robuxOpen = function(skinId: string): boolean
			local skin = Skins.get(skinId)
			return skin ~= nil and ShopLogic.robuxOpen(skin, robux.fake)
		end,
	})
	UiScaleController.attach(drawScreen.gui)

	UiScaleController.onChanged(function(m)
		screen:setLayout(m)
		drawScreen:setLayout(m)
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
					got = Loc.t("shop.result.got", { name = Loc.skinName(skin.id) })
				end
			end
		end
		render()
		refreshVisibility()
		if got then
			screen:showResult(got, false)
		end
	end)

	-- 실제 상품 가격 (상품 id가 있는 스킨만): PriceCache가 한 번 받아 오고, 받으면 다시 그려요 (m5-07)
	local function refreshPrices()
		local prices = robux.prices :: { [string]: number }
		for _, skin in Skins.LIST do
			local productId = skin.productId
			if productId ~= nil and skin.robux ~= nil then
				prices[skin.id] = PriceCache.product(productId, skin.robux)
			end
		end
	end
	refreshPrices()
	PriceCache.changed:Connect(function(kind: PriceCache.Kind)
		if kind == "Product" then
			refreshPrices()
			render()
		end
	end)

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
