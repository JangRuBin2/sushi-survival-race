--!strict
-- 탈의실·코인 해금 판단 (m4-13). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/shop-logic.spec.luau).
--   canEquip(skinId, ownedSkins, locked?) -> (ok, reason?)
--       카탈로그에 있고 보유 중이어야 해요. locked = 라운드 중·연출 중 (서버 ShopService가 판단해서 넘겨요).
--   canBuyWithCoins(skinId, profile, canSave?) -> Decision
--       코인 가격이 있는(일반·레어) 스킨, 미보유, 코인 ≥ 가격. canSave가 false면(실제 서버 로드 실패) 거절.
--   buyWithCoins(profile, skinId) -> Decision
--       DataService.update 안에서 부르는 것: 다시 판단하고 통과하면 차감 + 보유 + 장착을 한 번에 (중복·음수 방지).
--   grantSkin(profile, skinId, equip?) -> boolean   보유 목록에 넣어요 (로벅스 결제 m4-14). 새로 넣었으면 true.
--   message(reason, missing?) -> string              거절 이유 한국어 한 줄 (탈의실 결과 글씨)
--   cardState(skin, view, robux?) -> CardState       탈의실 카드 상태 (입는 중 / 입기 / 코인 해금 / 코인 부족 / 로벅스)
--       로벅스 버튼은 상품 id가 있거나 Studio 가짜 결제(robux.fake)일 때만 켜져요 (m4-14). 일반·레어 스킨은 코인 해금 옆에
--       로벅스 버튼이 하나 더 있어요 (robux·robuxEnabled → robuxButtonText).
--   robuxOpen(skin, fake?) / robuxPrice(skin, robux?)  로벅스 판매 여부 / 보여 줄 가격 (실제 상품 가격 우선)
--   cardButtonText(state) -> string · robuxButtonText(state) -> string?
-- 소유·착용·코인의 진실은 서버 프로필뿐이에요. 클라이언트는 cardState로 보여 주기만 해요.

local Skins = require(script.Parent.Skins)

export type Reason =
	"UnknownSkin"
	| "NotOwned"
	| "Locked"
	| "AlreadyOwned"
	| "NotForCoins"
	| "NotEnoughCoins"
	| "CannotSave"
	| "TooFast"
	| "NoProfile"
	| "PurchasePending"

export type Decision = {
	ok: boolean,
	reason: Reason?,
	price: number?, -- 코인 가격 (코인으로 살 수 있는 스킨일 때)
	missing: number?, -- NotEnoughCoins: 모자란 코인
}

-- 판단에 필요한 프로필 부분 (ProfileSchema.Profile이 이 모양을 가져요)
export type Wallet = {
	coins: number,
	ownedSkins: { [string]: boolean },
	equippedSkin: string,
}

export type CardKind = "Equipped" | "Equip" | "Unlock" | "NeedCoins" | "Robux"

export type CardState = {
	kind: CardKind,
	price: number?, -- Unlock·NeedCoins: 코인 가격, Robux: 로벅스 가격
	missing: number?, -- NeedCoins
	enabled: boolean, -- 누를 수 있는 버튼인지 (Robux는 상품 id가 있거나 Studio 가짜 결제일 때만)
	robux: number?, -- Unlock·NeedCoins: 로벅스로도 살 수 있는 가격 (일반·레어 스킨, m4-14)
	robuxEnabled: boolean?, -- 그 로벅스 버튼을 누를 수 있는지
}

-- 로벅스 표시 옵션 (클라이언트가 넘겨요, m4-14)
export type RobuxOptions = {
	fake: boolean?, -- Studio 가짜 결제 (Config.DEBUG.fakeRobuxInStudio + Studio)
	prices: { [string]: number }?, -- 스킨 id → 실제 상품 가격 (MarketplaceService:GetProductInfo), 없으면 카탈로그 값
}

-- 탈의실에서 보는 내 프로필 부분 (Types.ProfileView)
export type ViewLike = {
	coins: number,
	equippedSkin: string,
	ownedSkins: { string },
}

local ShopLogic = {}

-- Studio 가짜 로벅스 결제가 켜졌는가 (m4-14). persistDataInStudio와 같이 켜면 운영 저장소(PlayerData_v1·Purchases_v1)에
-- 가짜 기록·무료 스킨이 써지니 가짜 결제를 끄고 진짜 결제처럼 굴어요 (m4-14 QA R4). 서버·클라이언트가 같이 써요.
function ShopLogic.fakeRobuxActive(isStudio: boolean, fakeRobux: boolean?, persistInStudio: boolean?): boolean
	return isStudio and fakeRobux == true and persistInStudio ~= true
end

-- 로벅스로 살 수 있게 열렸는가 (m4-14): 기본 스킨이 아니고 가격이 있고, 상품 id가 있거나 Studio 가짜 결제
function ShopLogic.robuxOpen(skin: Skins.Skin, fake: boolean?): boolean
	if skin.id == Skins.DEFAULT_ID or skin.robux == nil then
		return false
	end
	return skin.productId ~= nil or fake == true
end

-- 보여 줄 로벅스 가격: 실제 상품 가격을 받았으면 그 값, 아니면 카탈로그 값
function ShopLogic.robuxPrice(skin: Skins.Skin, robux: RobuxOptions?): number?
	local prices = robux and robux.prices
	local real = prices and prices[skin.id]
	if type(real) == "number" and real > 0 then
		return real
	end
	return skin.robux
end

function ShopLogic.canEquip(skinId: unknown, ownedSkins: { [string]: boolean }, locked: boolean?): (boolean, Reason?)
	local skin = Skins.get(skinId)
	if skin == nil then
		return false, "UnknownSkin"
	end
	if ownedSkins[skin.id] ~= true then
		return false, "NotOwned"
	end
	if locked then
		return false, "Locked"
	end
	return true, nil
end

local function validCoins(value: unknown): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

function ShopLogic.canBuyWithCoins(skinId: unknown, wallet: Wallet, canSave: boolean?): Decision
	local skin = Skins.get(skinId)
	if skin == nil then
		return { ok = false, reason = "UnknownSkin" }
	end
	if wallet.ownedSkins[skin.id] == true then
		return { ok = false, reason = "AlreadyOwned" }
	end
	local price = skin.coins
	if price == nil then
		return { ok = false, reason = "NotForCoins" }
	end
	if canSave == false then
		return { ok = false, reason = "CannotSave", price = price }
	end
	local coins = validCoins(wallet.coins)
	if coins < price then
		return { ok = false, reason = "NotEnoughCoins", price = price, missing = price - coins }
	end
	return { ok = true, price = price }
end

-- 프로필을 바로 바꿔요. DataService.update(player, function(profile) ... end) 안에서 불러요.
function ShopLogic.buyWithCoins(wallet: Wallet, skinId: unknown, canSave: boolean?): Decision
	local decision = ShopLogic.canBuyWithCoins(skinId, wallet, canSave)
	if not decision.ok then
		return decision
	end
	local skin = Skins.get(skinId) :: Skins.Skin
	local price = decision.price :: number
	wallet.coins = validCoins(wallet.coins) - price
	wallet.ownedSkins[skin.id] = true
	wallet.equippedSkin = skin.id
	return decision
end

function ShopLogic.grantSkin(wallet: Wallet, skinId: unknown, equip: boolean?): boolean
	local skin = Skins.get(skinId)
	if skin == nil then
		return false
	end
	local isNew = wallet.ownedSkins[skin.id] ~= true
	wallet.ownedSkins[skin.id] = true
	if equip then
		wallet.equippedSkin = skin.id
	end
	return isNew
end

local MESSAGES: { [Reason]: string } = {
	UnknownSkin = "없는 스킨이에요",
	NotOwned = "아직 없는 스킨이에요",
	Locked = "매치가 끝나면 바꿀 수 있어요",
	AlreadyOwned = "이미 가진 스킨이에요",
	NotForCoins = "코인으로는 살 수 없어요",
	NotEnoughCoins = "코인이 모자라요",
	CannotSave = "저장이 안 되는 상태예요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	NoProfile = "프로필을 불러오는 중이에요",
	PurchasePending = "로벅스 결제가 끝날 때까지 기다려 주세요",
}

function ShopLogic.message(reason: Reason?, missing: number?): string
	if reason == "NotEnoughCoins" and missing then
		return `🍚 {missing}개 더 필요해요`
	end
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

function ShopLogic.cardState(skin: Skins.Skin, view: ViewLike, robux: RobuxOptions?): CardState
	if view.equippedSkin == skin.id then
		return { kind = "Equipped", enabled = false }
	end
	if table.find(view.ownedSkins, skin.id) or skin.id == Skins.DEFAULT_ID then
		return { kind = "Equip", enabled = true }
	end
	local open = ShopLogic.robuxOpen(skin, robux and robux.fake)
	local robuxPrice = ShopLogic.robuxPrice(skin, robux)
	if skin.coins then
		local coins = validCoins(view.coins)
		if coins >= skin.coins then
			return { kind = "Unlock", price = skin.coins, enabled = true, robux = robuxPrice, robuxEnabled = open }
		end
		return {
			kind = "NeedCoins",
			price = skin.coins,
			missing = skin.coins - coins,
			enabled = false,
			robux = robuxPrice,
			robuxEnabled = open,
		}
	end
	return { kind = "Robux", price = robuxPrice, enabled = open }
end

function ShopLogic.cardButtonText(state: CardState): string
	if state.kind == "Equipped" then
		return "입는 중"
	elseif state.kind == "Equip" then
		return "입기"
	elseif state.kind == "Unlock" then
		return `🍚 {state.price}으로 해금`
	elseif state.kind == "NeedCoins" then
		return `🍚 {state.missing}개 더 필요해요`
	end
	if state.enabled then
		return `R$ {state.price}`
	end
	return `R$ {state.price} — 곧 열려요`
end

-- 일반·레어 스킨의 두 번째 버튼 (코인 해금 옆 "로벅스로 사기"). 로벅스 가격이 없으면 nil (m4-14)
function ShopLogic.robuxButtonText(state: CardState): string?
	if state.robux == nil or (state.kind ~= "Unlock" and state.kind ~= "NeedCoins") then
		return nil
	end
	if state.robuxEnabled then
		return `R$ {state.robux}로 사기`
	end
	return `R$ {state.robux} — 곧 열려요`
end

return ShopLogic
