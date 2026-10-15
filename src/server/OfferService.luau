--!strict
-- 특별 상품 상점 (m5-08, GDD 9.1·9.3·9.5). 카탈로그 Shared.Offers, 판단 Shared.OfferLogic (순수).
-- 리모트 (RemoteFunction, 반환 ok: boolean, err: LocText?):
--   RequestOfferPurchase(offerId)  간격 Config.Shop.PurchaseRequestCooldown → OfferLogic.canRequest →
--       묶음·연출(개발자 상품): MarketplaceService:PromptProductPurchase (Studio 가짜 결제면 RobuxShopService.fakeOfferReceipt)
--       VIP(게임 패스): MarketplaceService:PromptGamePassPurchase (Studio 가짜 VIP면 바로 VIP)
--       결제 창 중에 묶음 안의 스킨을 코인으로 해금하는 것은 막지 않아요 (스펙 D5) — 영수증 때 가진 것을 빼고 지급 + warn.
--   EquipFx(slot, fxId?)  간격 Config.Shop.RequestCooldown → OfferLogic.canEquipFx (칸·카탈로그·보유·라운드/연출 잠금
--       ShopService.isLocked) → profile.equippedFx[slot] 저장 + Player 속성 EliminationFx/VictoryFx. fxId nil·""면 벗기.
-- 영수증: ProcessReceipt는 RobuxShopService 하나뿐이에요. 여기는 setOfferPort로 "상품이 무엇을 주는지"만 등록해요
--   (지급 = OfferLogic.applyGrant: 묶음은 남은 스킨 + boughtOffers, 장착 안 함 / 연출은 보유 + 그 칸 장착).
--   묶음을 새로 받으면 Notice "탈의실에서 새 스킨을 입어 보세요".
-- VIP: 접속할 때 UserOwnsGamePassAsync (실패하면 VIP_RETRY초 뒤 한 번 더, 그래도 실패면 이번 접속은 VIP 아님 + warn),
--   Studio + Config.DEBUG.fakeVipInStudio면 VIP (persistDataInStudio와 같이 켜면 꺼지고 warn, QA B3).
--   PromptGamePassPurchaseFinished(산 경우)는 이번 접속 표시(👑·[VIP]·보기 vip)만 바로 켜고, 영구 스킨은
--   UserOwnsGamePassAsync가 true를 줄 때만 넣어요 (OfferLogic.VIP_PURCHASE_RECHECK 간격으로 다시 묻기, QA B1).
--   끝까지 확인이 안 되면 다음 접속의 확인이 넣어요.
--   VIP면 Player 속성 Vip = true, DataService.setViewExtra({ vip = true }), 프로필이 있으면 VIP 전용 스킨 지급(장착 안 함,
--   저장 요청). 한 번 받은 스킨은 패스가 없어져도 남아요. 코인 배수 없음 (스펙 D1).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local OfferLogic = require(ReplicatedStorage.Shared.OfferLogic)
local Offers = require(ReplicatedStorage.Shared.Offers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)
local RobuxShopService = require(script.Parent.RobuxShopService)
local ShopService = require(script.Parent.ShopService)

local OfferService = {}

local VIP_RETRY = 5 -- UserOwnsGamePassAsync 실패 뒤 다시 묻기까지(초)

local lastPurchaseAt: { [Player]: number } = {}
local lastEquipAt: { [Player]: number } = {}
local vipOf: { [Player]: boolean } = {} -- 이번 접속 VIP 표시 (👑·[VIP]·보기 vip)
local vipConfirmed: { [Player]: boolean } = {} -- 패스 보유가 Roblox 확인으로 확정됨 → 영구 스킨 지급 가능

local function fakeMode(): boolean
	return ShopLogic.fakeRobuxActive(
		RunService:IsStudio(),
		Config.DEBUG.fakeRobuxInStudio,
		Config.DEBUG.persistDataInStudio
	)
end

local function fakeVip(): boolean
	return OfferLogic.fakeVipActive(
		RunService:IsStudio(),
		Config.DEBUG.fakeVipInStudio,
		Config.DEBUG.persistDataInStudio
	)
end

local function vipOffer(): Offers.Offer?
	for _, offer in Offers.LIST do
		if offer.kind == "Pass" then
			return offer
		end
	end
	return nil
end

-- 판단용 보기: 서버 프로필(맵) + VIP
local function viewOf(player: Player): OfferLogic.ViewLike?
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	return {
		ownedSkins = profile.ownedSkins,
		ownedFx = profile.ownedFx,
		boughtOffers = profile.boughtOffers,
		vip = vipOf[player] == true,
	}
end

local function notice(player: Player, message: Types.LocText, kind: OfferLogic.NoticeKind)
	if player.Parent == Players then
		Remotes.event("Notice"):FireClient(player, message, kind)
	end
end

-- Player 속성 EliminationFx·VictoryFx를 프로필대로 (없으면 속성 제거)
local function applyFxAttributes(player: Player)
	local profile = DataService.get(player)
	local equipped = if profile then profile.equippedFx else nil
	player:SetAttribute(Attributes.EliminationFx, if equipped then equipped.Elimination else nil)
	player:SetAttribute(Attributes.VictoryFx, if equipped then equipped.Victory else nil)
end

---------------------------------------------------------------- VIP

-- VIP 전용 스킨을 넣어요 (장착 안 함). 프로필이 없으면 나중에 onLoaded에서
local function grantVipSkins(player: Player)
	if not vipConfirmed[player] then
		return
	end
	local offer = vipOffer()
	local profile = DataService.get(player)
	if offer == nil or profile == nil then
		return
	end
	local missing = OfferLogic.grantsFor(offer, profile :: any).skins
	if #missing == 0 then
		return
	end
	DataService.update(player, function(p)
		for _, skinId in missing do
			ShopLogic.grantSkin(p, skinId, false)
		end
	end)
	print(`[Offer] {player.Name} VIP skins granted: {table.concat(missing, ", ")}`)
	if DataService.canPersist(player) then
		task.spawn(DataService.saveNow, player)
	end
end

-- 이번 접속 표시만 (구매 이벤트로 바로 켜도 돼요)
local function showVip(player: Player)
	if player.Parent ~= Players or vipOf[player] then
		return
	end
	vipOf[player] = true
	player:SetAttribute(Attributes.Vip, true)
	DataService.setViewExtra(player, { vip = true })
end

-- Roblox 소유 확인(또는 Studio 가짜 VIP)이 끝났어요: 표시 + 영구 스킨
local function confirmVip(player: Player)
	if player.Parent ~= Players then
		return
	end
	showVip(player)
	if vipConfirmed[player] then
		return
	end
	vipConfirmed[player] = true
	grantVipSkins(player)
end

local function ownsPass(player: Player, passId: number): boolean?
	local ok, result = pcall(function(): boolean
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		return result == true
	end
	warn(`[Offer] UserOwnsGamePassAsync failed for {player.Name}: {result}`)
	return nil
end

local function checkVip(player: Player)
	if fakeVip() then
		confirmVip(player)
		return
	end
	local offer = vipOffer()
	local passId = if offer then offer.gamePassId else nil
	if passId == nil or player.UserId <= 0 then
		return
	end
	local owned = ownsPass(player, passId)
	if owned == nil then
		task.wait(VIP_RETRY)
		if player.Parent ~= Players then
			return
		end
		owned = ownsPass(player, passId)
		if owned == nil then
			warn(`[Offer] could not check VIP pass for {player.Name}, not VIP for this session`)
			return
		end
	end
	if owned then
		confirmVip(player)
	end
end

-- 산 직후: 표시는 바로, 스킨은 확인될 때까지 몇 번 다시 물어요 (UserOwnsGamePassAsync는 산 직후 캐시로 false일 수 있어요)
local function confirmPurchasedVip(player: Player, passId: number)
	showVip(player)
	for _, delay in OfferLogic.VIP_PURCHASE_RECHECK do
		if delay > 0 then
			task.wait(delay)
		end
		if player.Parent ~= Players or vipConfirmed[player] then
			return
		end
		if ownsPass(player, passId) == true then
			confirmVip(player)
			return
		end
	end
	warn(`[Offer] VIP pass purchase by {player.Name} not confirmed yet, skin will be granted on next join`)
end

---------------------------------------------------------------- 영수증 port (RobuxShopService)

local function bundleOrFx(offerId: string): Offers.Offer?
	local offer = Offers.get(offerId)
	if offer == nil or offer.kind == "Pass" then
		return nil
	end
	return offer
end

local offerPort: RobuxShopService.OfferPort = {
	offerFor = function(productId: number): string?
		local offer = Offers.forProduct(productId)
		return if offer and offer.kind ~= "Pass" then offer.id else nil
	end,
	productOf = function(offerId: string): number?
		local offer = bundleOrFx(offerId)
		if offer == nil then
			return nil
		end
		return offer.productId or 0
	end,
	owns = function(player: Player, offerId: string): boolean
		local offer = bundleOrFx(offerId)
		local view = viewOf(player)
		return offer ~= nil and view ~= nil and OfferLogic.delivered(offer, view)
	end,
	ownedParts = function(player: Player, offerId: string): { string }
		local offer = bundleOrFx(offerId)
		local view = viewOf(player)
		if offer == nil or view == nil then
			return {}
		end
		return OfferLogic.ownedParts(offer, view)
	end,
	grant = function(player: Player, offerId: string, equip: boolean): boolean
		local offer = bundleOrFx(offerId)
		if offer == nil then
			return false
		end
		-- 연출은 바로 그 칸에 입어요 (라운드·연출 중이면 보유만). 묶음은 OfferLogic이 장착하지 않아요.
		local wear = equip and not ShopService.isLocked(player)
		local updated = DataService.update(player, function(p)
			OfferLogic.applyGrant(p, offer, wear, os.time())
		end)
		if updated then
			applyFxAttributes(player)
		end
		return updated
	end,
	onGranted = function(player: Player, offerId: string)
		local offer = Offers.get(offerId)
		if offer == nil then
			return
		end
		local message, kind = OfferLogic.grantNotice(offer)
		notice(player, message, kind)
	end,
}

---------------------------------------------------------------- 리모트

local function onRequestOffer(player: Player, offerId: unknown): (boolean, Types.LocText?)
	local now = os.clock()
	local last = lastPurchaseAt[player]
	if last and now - last < Config.Shop.PurchaseRequestCooldown then
		return false, OfferLogic.message("TooFast")
	end
	lastPurchaseAt[player] = now
	local fake = fakeMode()
	local ok, reason = OfferLogic.canRequest(offerId, viewOf(player), {
		canSave = DataService.canPersist(player),
		fake = fake,
		fakeVip = fakeVip(),
	})
	if not ok then
		return false, OfferLogic.message(reason)
	end
	local offer = Offers.get(offerId) :: Offers.Offer
	if offer.kind == "Pass" then
		if fakeVip() then
			confirmVip(player)
			return true, nil
		end
		MarketplaceService:PromptGamePassPurchase(player, offer.gamePassId :: number)
		return true, nil
	end
	if fake then
		task.spawn(RobuxShopService.fakeOfferReceipt, player, offer.id)
		return true, nil
	end
	MarketplaceService:PromptProductPurchase(player, offer.productId :: number)
	return true, nil
end

local function onEquipFx(player: Player, slot: unknown, fxId: unknown): (boolean, Types.LocText?)
	local now = os.clock()
	local last = lastEquipAt[player]
	if last and now - last < Config.Shop.RequestCooldown then
		return false, OfferLogic.message("TooFast")
	end
	lastEquipAt[player] = now
	local ok, reason = OfferLogic.canEquipFx(slot, fxId, viewOf(player), ShopService.isLocked(player))
	if not ok then
		return false, OfferLogic.message(reason)
	end
	local value: string? = if type(fxId) == "string" and fxId ~= "" then fxId else nil
	DataService.update(player, function(p)
		(p.equippedFx :: any)[slot :: string] = value
	end)
	applyFxAttributes(player)
	return true, nil
end

function OfferService.init()
	local valid, problems = Offers.validate(Offers.LIST)
	if not valid then
		warn(`[Offer] offer catalog problems: {table.concat(problems, "; ")}`)
	end
	RobuxShopService.setOfferPort(offerPort)
	if RunService:IsStudio() and Config.DEBUG.fakeVipInStudio and Config.DEBUG.persistDataInStudio then
		warn(
			"[Offer] fakeVipInStudio is ignored while persistDataInStudio is on (would save the VIP skin to the real store)"
		)
	end
	Remotes.fn("RequestOfferPurchase").OnServerInvoke = function(
		player: Player,
		offerId: unknown
	): (boolean, Types.LocText?)
		local ok, success, err = pcall(onRequestOffer, player, offerId)
		if not ok then
			warn(`[Offer] RequestOfferPurchase failed for {player.Name}: {success}`)
			return false, LocalizeLogic.text("common.err.retry")
		end
		return success, err
	end
	Remotes.fn("EquipFx").OnServerInvoke = function(
		player: Player,
		slot: unknown,
		fxId: unknown
	): (boolean, Types.LocText?)
		local ok, success, err = pcall(onEquipFx, player, slot, fxId)
		if not ok then
			warn(`[Offer] EquipFx failed for {player.Name}: {success}`)
			return false, LocalizeLogic.text("common.err.retry")
		end
		return success, err
	end
end

function OfferService.start()
	DataService.onLoaded(function(player: Player)
		applyFxAttributes(player)
		grantVipSkins(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local offer = vipOffer()
			if purchased and offer ~= nil and offer.gamePassId == passId then
				task.spawn(confirmPurchasedVip, player, passId) -- 표시는 바로, 스킨은 확인 뒤 (QA B1)
			end
		end
	)
	local function onPlayer(player: Player)
		task.spawn(checkVip, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPurchaseAt[player] = nil
		lastEquipAt[player] = nil
		vipOf[player] = nil
		vipConfirmed[player] = nil
	end)
end

-- 지금 VIP인가 (이번 접속에서 확인된 것)
function OfferService.isVip(player: Player): boolean
	return vipOf[player] == true
end

return OfferService
