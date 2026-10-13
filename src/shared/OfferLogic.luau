--!strict
-- 특별 상품 판단 (m5-08). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/offer-logic.spec.luau).
-- view는 클라이언트의 Types.ProfileView(목록: ownedSkins = { "salmon", ... })와 서버 프로필(맵: ownedSkins.salmon = true)
-- 둘 다 받아요 (has 헬퍼). 계란초밥(기본 스킨)은 항상 가진 것으로 봐요.
--
--   OfferLogic.visible(offer, view) -> boolean            상점에 살 수 있는 카드로 보일지
--       Bundle: 계정당 1번(boughtOffers) + 안의 스킨을 하나도 안 가졌을 때. Fx: 그 연출이 없을 때. Pass: VIP가 아닐 때.
--   OfferLogic.canRequest(offerId, view?, opts) -> (ok, Reason?)   RequestOfferPurchase 검사 (TooFast는 서버가)
--   OfferLogic.grantsFor(offer, owned) -> { skins, fx }   아직 없는 것만
--   OfferLogic.ownedParts(offer, owned) -> { string }      이미 가진 것 (묶음 영수증 note용)
--   OfferLogic.delivered(offer, owned) -> boolean          이 상품을 이미 받은 상태인가 (영수증 owns)
--   OfferLogic.applyGrant(profile, offer, equip, now) -> { skins, fx }   DataService.update 안에서: 지급 + 기록
--       Bundle: 남은 스킨 + boughtOffers[id] = now (장착 안 함). Fx: ownedFx (+ equip이면 equippedFx[칸]). Pass: 스킨만.
--   OfferLogic.canEquipFx(slot, fxId, owned, locked) -> (ok, Reason?)   EquipFx 검사 (fxId nil·""면 벗기)
--   OfferLogic.message(reason) / valueText(offer) / contentLines(offer)
--   OfferLogic.cardState(offer, view, opts) / buttonText(state, price) / screenList(view, opts)   상점 화면
-- 화면 문구는 m5-26부터 LocText (키). 클라이언트가 Loc.text로 풀어요.

local FxCatalog = require(script.Parent.FxCatalog)
local LocalizeLogic = require(script.Parent.LocalizeLogic)
local Offers = require(script.Parent.Offers)
local Skins = require(script.Parent.Skins)
local Types = require(script.Parent.Types)

type LocText = Types.LocText

export type Reason =
	"Unknown"
	| "AlreadyBought"
	| "OwnsSome"
	| "AlreadyOwned"
	| "AlreadyVip"
	| "NotForSale"
	| "CannotSave"
	| "NoProfile"
	| "TooFast"
	-- EquipFx (m5-08)
	| "BadSlot"
	| "UnknownFx"
	| "WrongSlot"
	| "NotOwned"
	| "Locked"

-- 판단에 필요한 프로필 부분. 목록이든 맵이든 돼요 (Types.ProfileView / ProfileSchema.Profile)
export type ViewLike = {
	read ownedSkins: any,
	read ownedFx: any?,
	read boughtOffers: any?,
	read vip: boolean?,
}

export type RequestOptions = {
	canSave: boolean, -- DataService.canPersist
	fake: boolean, -- Studio 가짜 결제 (ShopLogic.fakeRobuxActive)
	fakeVip: boolean?, -- Studio 가짜 VIP (Config.DEBUG.fakeVipInStudio + Studio)
}

export type Grants = { skins: { string }, fx: { string } }

-- 상점 카드 상태: Buy 살 수 있음 / Soon 상품 id 없음(비활성) / Bought 산 상품(회색, 아래) / Hidden 안 보임
export type CardKind = "Buy" | "Soon" | "Bought" | "Hidden"
export type CardState = { kind: CardKind, enabled: boolean }
export type ScreenOptions = { fake: boolean?, fakeVip: boolean? }
export type ScreenEntry = { offer: Offers.Offer, state: CardState }

-- 프로필이 쓰는 모양 (applyGrant)
export type ProfileLike = {
	ownedSkins: { [string]: boolean },
	ownedFx: { [string]: boolean },
	equippedFx: { Elimination: string?, Victory: string? },
	boughtOffers: { [string]: number },
}

local OfferLogic = {}

-- VIP 패스를 산 뒤(PromptGamePassPurchaseFinished) 영구 스킨을 주기 전에 UserOwnsGamePassAsync로 다시 묻는 간격(초,
-- 누적 아님: 차례로 기다려요). 끝까지 확인이 안 되면 다음 접속의 확인이 줘요 (m5-08 QA B1)
OfferLogic.VIP_PURCHASE_RECHECK = { 0, 2, 5, 10 }

-- Notice 종류 (m5-08 QA B2): 두 번째 인자. "success"면 클라이언트가 오류색을 쓰지 않아요
export type NoticeKind = "success" | "error" | "info"

-- Studio 가짜 VIP가 켜졌는가. 진짜 저장소를 쓰는 동안(persistDataInStudio)은 꺼요 —
-- VIP 스킨이 진짜 프로필에 저장되지 않게 (ShopLogic.fakeRobuxActive와 같은 규칙, m5-08 QA B3)
function OfferLogic.fakeVipActive(isStudio: boolean, fakeVip: boolean?, persistInStudio: boolean?): boolean
	return isStudio and fakeVip == true and persistInStudio ~= true
end

local function has(collection: any, id: string): boolean
	if type(collection) ~= "table" then
		return false
	end
	local value = collection[id]
	if value ~= nil and value ~= false then
		return true
	end
	return table.find(collection, id) ~= nil
end

local function ownsSkin(view: ViewLike, skinId: string): boolean
	return Skins.isFree(skinId) or has(view.ownedSkins, skinId)
end

local function ownsFx(view: ViewLike, fxId: string): boolean
	return has(view.ownedFx, fxId)
end

function OfferLogic.ownedParts(offer: Offers.Offer, view: ViewLike): { string }
	local parts: { string } = {}
	for _, skinId in offer.skins or {} do
		if ownsSkin(view, skinId) then
			table.insert(parts, skinId)
		end
	end
	for _, fxId in offer.fx or {} do
		if ownsFx(view, fxId) then
			table.insert(parts, fxId)
		end
	end
	return parts
end

function OfferLogic.grantsFor(offer: Offers.Offer, view: ViewLike): Grants
	local grants: Grants = { skins = {}, fx = {} }
	for _, skinId in offer.skins or {} do
		if not ownsSkin(view, skinId) then
			table.insert(grants.skins, skinId)
		end
	end
	for _, fxId in offer.fx or {} do
		if not ownsFx(view, fxId) then
			table.insert(grants.fx, fxId)
		end
	end
	return grants
end

local function allFxOwned(offer: Offers.Offer, view: ViewLike): boolean
	local fxIds = offer.fx or {}
	for _, fxId in fxIds do
		if not ownsFx(view, fxId) then
			return false
		end
	end
	return #fxIds > 0
end

-- 영수증 판단용: 이 상품을 이미 받은 상태인가. 묶음은 산 기록(boughtOffers), 연출은 연출 보유, 패스는 VIP.
function OfferLogic.delivered(offer: Offers.Offer, view: ViewLike): boolean
	if offer.kind == "Bundle" then
		return has(view.boughtOffers, offer.id)
	elseif offer.kind == "Fx" then
		return allFxOwned(offer, view)
	end
	return view.vip == true
end

function OfferLogic.visible(offer: Offers.Offer, view: ViewLike): boolean
	if offer.kind == "Bundle" then
		return not has(view.boughtOffers, offer.id) and #OfferLogic.ownedParts(offer, view) == 0
	elseif offer.kind == "Fx" then
		return not allFxOwned(offer, view)
	end
	return view.vip ~= true
end

function OfferLogic.canRequest(offerId: unknown, view: ViewLike?, opts: RequestOptions): (boolean, Reason?)
	local offer = Offers.get(offerId)
	if offer == nil then
		return false, "Unknown"
	end
	if view == nil then
		return false, "NoProfile"
	end
	if offer.kind == "Bundle" then
		if has(view.boughtOffers, offer.id) then
			return false, "AlreadyBought"
		end
		if #OfferLogic.ownedParts(offer, view) > 0 then
			return false, "OwnsSome"
		end
	elseif offer.kind == "Fx" then
		if allFxOwned(offer, view) then
			return false, "AlreadyOwned"
		end
	else
		if view.vip == true then
			return false, "AlreadyVip"
		end
		-- 게임 패스: 지급은 Roblox가 해요 (프로필 저장과 상관없음). 스킨은 접속·확인 때 넣어요
		if opts.fakeVip then
			return true, nil
		end
		if offer.gamePassId == nil then
			return false, "NotForSale"
		end
		return true, nil
	end
	if opts.fake then
		return true, nil -- Studio 가짜 결제: 상품 id·저장 가능 여부와 상관없이 (메모리에 저장)
	end
	if offer.productId == nil then
		return false, "NotForSale"
	end
	if not opts.canSave then
		return false, "CannotSave"
	end
	return true, nil
end

-- DataService.update 안에서 불러요. 이번에 새로 넣은 것을 돌려줘요.
function OfferLogic.applyGrant(profile: ProfileLike, offer: Offers.Offer, equip: boolean, now: number): Grants
	local grants = OfferLogic.grantsFor(offer, profile :: any)
	for _, skinId in grants.skins do
		if Skins.get(skinId) ~= nil then
			profile.ownedSkins[skinId] = true
		end
	end
	for _, fxId in grants.fx do
		if FxCatalog.get(fxId) ~= nil then
			profile.ownedFx[fxId] = true
		end
	end
	if offer.kind == "Bundle" and profile.boughtOffers[offer.id] == nil then
		profile.boughtOffers[offer.id] = math.max(0, math.floor(now))
	end
	if offer.kind == "Fx" and equip then
		for _, fxId in offer.fx or {} do
			local fx = FxCatalog.get(fxId)
			if fx and profile.ownedFx[fx.id] then
				(profile.equippedFx :: any)[fx.slot] = fx.id
			end
		end
	end
	return grants
end

function OfferLogic.canEquipFx(slot: unknown, fxId: unknown, view: ViewLike?, locked: boolean): (boolean, Reason?)
	if not FxCatalog.isSlot(slot) then
		return false, "BadSlot"
	end
	if view == nil then
		return false, "NoProfile"
	end
	if fxId ~= nil and fxId ~= "" then
		if type(fxId) ~= "string" then
			return false, "UnknownFx"
		end
		local fx = FxCatalog.get(fxId)
		if fx == nil then
			return false, "UnknownFx"
		end
		if fx.slot ~= slot then
			return false, "WrongSlot"
		end
		if not ownsFx(view, fx.id) then
			return false, "NotOwned"
		end
	end
	if locked then
		return false, "Locked"
	end
	return true, nil
end

local MESSAGES: { [Reason]: LocText } = {
	Unknown = { key = "offer.err.Unknown" },
	AlreadyBought = { key = "offer.err.AlreadyBought" },
	OwnsSome = { key = "offer.err.OwnsSome" },
	AlreadyOwned = { key = "offer.err.AlreadyOwned" },
	AlreadyVip = { key = "offer.err.AlreadyVip" },
	NotForSale = { key = "offer.err.NotForSale" },
	CannotSave = { key = "offer.err.CannotSave" },
	NoProfile = { key = "offer.err.NoProfile" },
	TooFast = { key = "offer.err.TooFast" },
	BadSlot = { key = "offer.err.BadSlot" },
	UnknownFx = { key = "offer.err.UnknownFx" },
	WrongSlot = { key = "offer.err.WrongSlot" },
	NotOwned = { key = "offer.err.NotOwned" },
	Locked = { key = "offer.err.Locked" },
}
OfferLogic.REASONS = {} :: { Reason }
for reason in MESSAGES do
	table.insert(OfferLogic.REASONS, reason)
end
table.sort(OfferLogic.REASONS)

-- 거절 문구. reason이 nil이면 nil
function OfferLogic.message(reason: Reason?): LocText?
	if reason == nil then
		return nil
	end
	return MESSAGES[reason] or LocalizeLogic.text("common.err.retry")
end

-- 묶음만: 스킨을 따로 살 때 로벅스 합 ("따로 사면 R$ 146")
function OfferLogic.valueText(offer: Offers.Offer): LocText?
	if offer.kind ~= "Bundle" then
		return nil
	end
	local total = 0
	for _, skinId in offer.skins or {} do
		local skin = Skins.get(skinId)
		if skin == nil or skin.robux == nil then
			return nil
		end
		total += skin.robux
	end
	if total <= 0 then
		return nil
	end
	return LocalizeLogic.text("offer.value", { total = total })
end

-- 카드에 보일 "주는 것" 줄들. 줄 하나 = 조각 목록 (화면이 " · "로 이어 붙여요, m5-26)
function OfferLogic.contentLines(offer: Offers.Offer): { { LocText } }
	if offer.kind == "Bundle" then
		local names: { LocText } = {}
		for _, skinId in offer.skins or {} do
			if Skins.get(skinId) then
				table.insert(names, LocalizeLogic.text(LocalizeLogic.skinNameKey(skinId)))
			end
		end
		return { names }
	elseif offer.kind == "Fx" then
		local lines: { { LocText } } = {}
		if offer.blurb then
			table.insert(lines, { LocalizeLogic.text(LocalizeLogic.offerBlurbKey(offer.id)) })
		else
			for _, fxId in offer.fx or {} do
				if FxCatalog.get(fxId) then
					table.insert(lines, { LocalizeLogic.text(LocalizeLogic.fxNameKey(fxId)) })
				end
			end
		end
		return lines
	end
	local lines: { { LocText } } = {}
	for index in offer.perks or {} do
		table.insert(lines, { LocalizeLogic.text(LocalizeLogic.offerPerkKey(offer.id, index)) })
	end
	return lines
end

local function forSale(offer: Offers.Offer, opts: ScreenOptions): boolean
	if offer.kind == "Pass" then
		return offer.gamePassId ~= nil or opts.fakeVip == true
	end
	return offer.productId ~= nil or opts.fake == true
end

function OfferLogic.cardState(offer: Offers.Offer, view: ViewLike, opts: ScreenOptions?): CardState
	local options: ScreenOptions = opts or {}
	if OfferLogic.visible(offer, view) then
		local open = forSale(offer, options)
		return { kind = if open then "Buy" else "Soon", enabled = open }
	end
	if OfferLogic.delivered(offer, view) then
		return { kind = "Bought", enabled = false } -- 산 상품: 회색으로 아래
	end
	return { kind = "Hidden", enabled = false } -- 조건이 안 맞는 묶음 (일부 스킨을 이미 가짐)
end

function OfferLogic.buttonText(state: CardState, price: number): LocText?
	if state.kind == "Buy" then
		return LocalizeLogic.text("offer.btn.buy", { price = price })
	elseif state.kind == "Soon" then
		return LocalizeLogic.text("offer.btn.soon")
	elseif state.kind == "Bought" then
		return LocalizeLogic.text("offer.btn.bought")
	end
	return nil
end

-- 상점에 보일 카드 순서: 살 수 있는 것(order 순) 다음 산 상품(order 순). Hidden은 빼요.
function OfferLogic.screenList(view: ViewLike, opts: ScreenOptions?, list: { Offers.Offer }?): { ScreenEntry }
	local open: { ScreenEntry } = {}
	local bought: { ScreenEntry } = {}
	for _, offer in list or Offers.LIST do
		local state = OfferLogic.cardState(offer, view, opts)
		if state.kind == "Hidden" then
			continue
		end
		table.insert(if state.kind == "Bought" then bought else open, { offer = offer, state = state })
	end
	local function byOrder(a: ScreenEntry, b: ScreenEntry): boolean
		return a.offer.order < b.offer.order
	end
	table.sort(open, byOrder)
	table.sort(bought, byOrder)
	for _, entry in bought do
		table.insert(open, entry)
	end
	return open
end

-- 상품을 새로 받았을 때 보낼 안내 (문구, 종류). 늘 성공 안내예요
function OfferLogic.grantNotice(offer: Offers.Offer): (LocText, NoticeKind)
	if offer.kind == "Bundle" then
		return LocalizeLogic.text("offer.notice.bundle"), "success"
	end
	return LocalizeLogic.text("offer.notice.got", { name = LocalizeLogic.text(LocalizeLogic.offerNameKey(offer.id)) }),
		"success"
end

return OfferLogic
