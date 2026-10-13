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

local FxCatalog = require(script.Parent.FxCatalog)
local Offers = require(script.Parent.Offers)
local Skins = require(script.Parent.Skins)

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
	ownedSkins: any,
	ownedFx: any?,
	boughtOffers: any?,
	vip: boolean?,
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
	return skinId == Skins.DEFAULT_ID or has(view.ownedSkins, skinId)
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

local MESSAGES: { [Reason]: string } = {
	Unknown = "없는 상품이에요",
	AlreadyBought = "이미 샀어요",
	OwnsSome = "이미 가진 스킨이 있어서 따로 사야 해요",
	AlreadyOwned = "이미 가진 연출이에요",
	AlreadyVip = "이미 VIP예요",
	NotForSale = "준비 중이에요",
	CannotSave = "저장이 안 되는 상태라 지금은 살 수 없어요",
	NoProfile = "프로필을 불러오는 중이에요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	BadSlot = "없는 연출 칸이에요",
	UnknownFx = "없는 연출이에요",
	WrongSlot = "그 칸에 입을 수 없는 연출이에요",
	NotOwned = "아직 없는 연출이에요",
	Locked = "매치가 끝나면 바꿀 수 있어요",
}

function OfferLogic.message(reason: Reason?): string
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

-- 묶음만: 스킨을 따로 살 때 로벅스 합 ("따로 사면 R$ 146")
function OfferLogic.valueText(offer: Offers.Offer): string?
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
	return `따로 사면 R$ {total}`
end

-- 카드에 보일 "주는 것" 줄들
function OfferLogic.contentLines(offer: Offers.Offer): { string }
	if offer.kind == "Bundle" then
		local names: { string } = {}
		for _, skinId in offer.skins or {} do
			local skin = Skins.get(skinId)
			table.insert(names, if skin then skin.displayName else skinId)
		end
		return { table.concat(names, " · ") }
	elseif offer.kind == "Fx" then
		local lines: { string } = {}
		if offer.blurb then
			table.insert(lines, offer.blurb)
		else
			for _, fxId in offer.fx or {} do
				local fx = FxCatalog.get(fxId)
				table.insert(lines, if fx then fx.displayName else fxId)
			end
		end
		return lines
	end
	return table.clone(offer.perks or {})
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

function OfferLogic.buttonText(state: CardState, price: number): string
	if state.kind == "Buy" then
		return `R$ {price}로 사기`
	elseif state.kind == "Soon" then
		return "곧 열려요"
	elseif state.kind == "Bought" then
		return "산 상품"
	end
	return ""
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

return OfferLogic
