--!strict
-- "🎁 상점" (m5-08). OfferScreen에 내 프로필(ProfileStore)로 상품 카드·"내 연출"을 그리고
-- RequestOfferPurchase·EquipFx를 서버에 요청해요. 판단(보유·한 번만·VIP·잠금)과 지급은 서버(OfferService·RobuxShopService).
--   버튼이 보이는 때: 로비·방 대기실에서만 (매치 중·대기석·관전 중에는 숨기고 창도 닫아요 — 결제는 판 사이에만, 스펙 D6).
--   매치 서버(m4-11)에서는 늘 숨겨요.
--   가격: PriceCache.product / PriceCache.pass (실제 상품 가격, 없으면 카탈로그 값). 바뀌면 다시 그려요.
--   산 상품이 프로필에 들어오면 결과 줄에 "🎉 … 획득!" (묶음은 "탈의실에서 새 스킨을 입어 보세요"도 서버 Notice로 와요).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local FxCatalog = require(ReplicatedStorage.Shared.FxCatalog)
local OfferLogic = require(ReplicatedStorage.Shared.OfferLogic)
local Offers = require(ReplicatedStorage.Shared.Offers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local PriceCache = require(script.Parent.Parent.PriceCache)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local OfferScreen = require(script.Parent.OfferScreen)
local UiScaleController = require(script.Parent.UiScaleController)

local OfferController = {}

local SLOT_NAMES = { Elimination = "탈락 연출", Victory = "우승 연출" } :: { [string]: string }

local function priceOf(offer: Offers.Offer): number
	if offer.kind == "Pass" then
		local passId = offer.gamePassId
		return if passId then PriceCache.pass(passId, offer.robux) else offer.robux
	end
	local productId = offer.productId
	return if productId then PriceCache.product(productId, offer.robux) else offer.robux
end

function OfferController.start(_gui: Instance)
	local me = Players.LocalPlayer
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"
	local options: OfferLogic.ScreenOptions = {
		fake = ShopLogic.fakeRobuxActive(
			RunService:IsStudio(),
			Config.DEBUG.fakeRobuxInStudio,
			Config.DEBUG.persistDataInStudio
		),
		fakeVip = RunService:IsStudio() and Config.DEBUG.fakeVipInStudio == true,
	}

	local view: Types.ProfileView? = ProfileStore.get()
	local room: Types.RoomSnapshot? = nil
	local busy = false
	local pending: { [string]: boolean } = {} -- 결제를 요청한 상품 (받으면 획득 안내)
	local screen: OfferScreen.OfferScreen

	local function buildModel(current: Types.ProfileView): OfferScreen.Model
		local cards: { OfferScreen.CardModel } = {}
		for _, entry in OfferLogic.screenList(current, options) do
			local offer = entry.offer
			table.insert(cards, {
				id = offer.id,
				name = offer.displayName,
				lines = OfferLogic.contentLines(offer),
				value = OfferLogic.valueText(offer),
				buttonText = OfferLogic.buttonText(entry.state, priceOf(offer)),
				enabled = entry.state.enabled,
				bought = entry.state.kind == "Bought",
				order = offer.order,
			})
		end
		local fx: { OfferScreen.FxRowModel } = {}
		for _, item in FxCatalog.LIST do
			if table.find(current.ownedFx, item.id) == nil then
				continue
			end
			local equipped = (current.equippedFx :: any)[item.slot] == item.id
			table.insert(fx, {
				id = item.id,
				slot = item.slot,
				name = `{item.displayName} ({SLOT_NAMES[item.slot] or item.slot})`,
				equipped = equipped,
			})
		end
		return { cards = cards, fx = fx }
	end

	local function render()
		local current = view
		if current == nil or screen == nil then
			return
		end
		screen:render(buildModel(current))
	end

	local function canShow(): boolean
		if isMatchServer or view == nil then
			return false
		end
		return room == nil or room.state ~= "InMatch"
	end

	local function refreshVisibility()
		local visible = canShow()
		screen:setButtonVisible(visible)
		if not visible and screen:isOpen() then
			screen:setOpen(false)
		end
	end

	local function invoke(name: string, ...: any): (boolean, string?)
		local remote = Remotes.fn(name)
		local called, ok, err = pcall(remote.InvokeServer, remote, ...)
		if not called then
			return false, "서버와 연결이 불안정해요"
		end
		return ok == true, if type(err) == "string" then err else nil
	end

	local function buy(offerId: string)
		local current = view
		local offer = Offers.get(offerId)
		if busy or current == nil or offer == nil then
			return
		end
		if OfferLogic.cardState(offer, current, options).kind ~= "Buy" then
			return
		end
		busy = true
		screen:setBusy(true)
		local ok, err = invoke("RequestOfferPurchase", offerId)
		busy = false
		screen:setBusy(false)
		if ok then
			pending[offerId] = true
			local fake = if offer.kind == "Pass" then options.fakeVip else options.fake
			screen:showResult(
				if fake then "가짜 결제 처리 중…" else "결제 창을 확인해 주세요",
				false
			)
		else
			screen:showResult(err or "다시 해 주세요", true)
		end
	end

	local function equipFx(slot: string, fxId: string?)
		if busy or view == nil then
			return
		end
		busy = true
		screen:setBusy(true)
		local ok, err = invoke("EquipFx", slot, fxId)
		busy = false
		screen:setBusy(false)
		if ok then
			local fx = if fxId then FxCatalog.get(fxId) else nil
			screen:showResult(if fx then `{fx.displayName} 입었어요!` else "연출을 벗었어요", false)
		else
			screen:showResult(err or "다시 해 주세요", true)
		end
	end

	screen = OfferScreen.new(me:WaitForChild("PlayerGui"), {
		open = function()
			if view == nil then
				return
			end
			render()
			screen:setOpen(true)
		end,
		close = function()
			screen:setOpen(false)
		end,
		buy = buy,
		equipFx = equipFx,
	})
	UiScaleController.attach(screen.gui)
	UiScaleController.onChanged(function(m)
		screen:setLayout(m)
	end)

	-- 결제 창을 취소하면 기다리던 상품을 지워요
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, isPurchased: boolean)
			local offer = Offers.forProduct(productId)
			if userId == me.UserId and not isPurchased and offer then
				pending[offer.id] = nil
			end
		end
	)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, isPurchased: boolean)
			local offer = Offers.forPass(passId)
			if player == me and not isPurchased and offer then
				pending[offer.id] = nil
			end
		end
	)

	ProfileStore.changed(function(newView: Types.ProfileView)
		view = newView
		local got: string? = nil
		for offerId in table.clone(pending) do
			local offer = Offers.get(offerId)
			if offer and OfferLogic.delivered(offer, newView) then
				pending[offerId] = nil
				got = if offer.kind == "Bundle"
					then `🎉 {offer.displayName} 획득! 탈의실에서 새 스킨을 입어 보세요`
					else `🎉 {offer.displayName} 획득!`
			end
		end
		render()
		refreshVisibility()
		if got then
			screen:showResult(got, false)
		end
	end)

	PriceCache.changed:Connect(function()
		render()
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
		room = snapshot
		refreshVisibility()
	end)

	render()
	refreshVisibility()
end

return OfferController
