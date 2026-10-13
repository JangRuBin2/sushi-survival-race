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
-- 시즌 이벤트 (m5-07):
--   canBuyWithTokens(skinId, wallet, now, canSave?, locked?) -> Decision   이벤트 재화로 무료 한정 스킨 받기
--       순서: 카탈로그(tokens) → 이벤트 진행 중 → 미보유 → 잠금 → 저장 가능 → 재화 ≥ 가격
--   buyWithTokens(wallet, skinId, now, canSave?, locked?) -> Decision      update 안에서: 재화 차감 + 보유 + 장착
--   tokensOf(wallet, eventId) -> number · isLimited(skin) -> boolean · onSale(skin, now?) -> boolean
--   cardState(skin, view, robux?, now?)   now가 있으면 시즌 판매 기간을 봐요 (nil이면 안 봐요 — 예전 호출)
--   tabs(now) -> { Tab }      진행 중 이벤트가 있으면 이벤트 탭이 맨 앞 ("🎃 할로윈"), 그다음 전체·일반·레어·에픽·전설
--   defaultTab(now) -> Tab    탈의실을 열 때 먼저 고를 탭 (이벤트 탭, 없으면 전체)
--   visibleSkins(view, tab?, now?) -> { Skin }   기간 끝 + 미보유 한정 스킨은 어느 탭에도 안 보여요.
--       이벤트 탭은 그 이벤트 스킨만, 등급 탭은 한정 스킨을 가진 것만(받기 전에는 이벤트 탭·전체에서), 전체는 보이는 것 모두
--   eventHeader(event, now, tokens?) -> string   "할로윈 초밥 축제 · 11월 5일까지 · 🍬 32" (날짜로만, D4)
--   lastDayText(event) -> string                 마지막 날 = endsAt − 1초의 UTC 날짜 "11월 5일"
-- 소유·착용·코인의 진실은 서버 프로필뿐이에요. 클라이언트는 cardState로 보여 주기만 해요.

local Seasons = require(script.Parent.Seasons)
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
	| "NotForTokens" -- m5-07: 이벤트 재화로 받는 스킨이 아니에요
	| "EventEnded" -- m5-07: 그 이벤트가 진행 중이 아니에요
	| "NeedTokens" -- m5-07: 재화가 모자라요

export type Decision = {
	ok: boolean,
	reason: Reason?,
	price: number?, -- 코인 가격 (코인으로 살 수 있는 스킨일 때)
	missing: number?, -- NotEnoughCoins: 모자란 코인, NeedTokens: 모자란 재화
	eventId: string?, -- 재화 판단 (m5-07): 그 스킨의 이벤트 id
}

-- 판단에 필요한 프로필 부분 (ProfileSchema.Profile이 이 모양을 가져요)
export type Wallet = {
	coins: number,
	ownedSkins: { [string]: boolean },
	equippedSkin: string,
	eventTokens: { [string]: number }, -- 이벤트 id → 재화 (m5-07, 프로필에는 항상 있어요)
}

-- Soon: 아직 얻을 길이 탈의실에 없는 스킨 (m5-03). m5-07: Tokens(재화로 받기)·NeedTokens(재화 부족)·
-- Vip(VIP 전용, 미보유)·OffSale(시즌 판매 기간 밖 — 목록에서 숨기지만 혹시 보이면 비활성)
export type CardKind =
	"Equipped"
	| "Equip"
	| "Unlock"
	| "NeedCoins"
	| "Robux"
	| "Soon"
	| "Tokens"
	| "NeedTokens"
	| "Vip"
	| "OffSale"

export type CardState = {
	kind: CardKind,
	price: number?, -- Unlock·NeedCoins: 코인 가격, Robux: 로벅스 가격
	missing: number?, -- NeedCoins
	enabled: boolean, -- 누를 수 있는 버튼인지 (Robux는 상품 id가 있거나 Studio 가짜 결제일 때만)
	robux: number?, -- Unlock·NeedCoins: 로벅스로도 살 수 있는 가격 (일반·레어 스킨, m4-14)
	robuxEnabled: boolean?, -- 그 로벅스 버튼을 누를 수 있는지
	tokens: number?, -- Tokens·NeedTokens: 지금 가진 재화 (price = 재화 가격, m5-07)
	icon: string?, -- Tokens·NeedTokens: 재화 아이콘 (🍬/⭐)
	limited: boolean?, -- 보유한 한정(시즌) 스킨: 카드 구석에 "한정" (m5-07)
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
	eventTokens: { [string]: number }, -- m5-07 (Types.ProfileView에는 항상 있어요)
}

-- 탈의실 탭 (m5-07): id "event"·"all"·등급 이름
export type Tab = {
	id: string,
	label: string,
	tier: Skins.Tier?, -- 등급 탭
	eventId: string?, -- 이벤트 탭
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
	if ownedSkins[skin.id] ~= true and not Skins.isFree(skin.id) then
		return false, "NotOwned" -- 무료 스킨(계란초밥·실험 스킨)은 저장된 목록에 없어도 가져요 (m5-27)
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
	if wallet.ownedSkins[skin.id] == true or Skins.isFree(skin.id) then
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

---------------------------------------------------------------- 시즌 이벤트 (m5-07)

-- 한정(시즌) 스킨인가
function ShopLogic.isLimited(skin: Skins.Skin): boolean
	return skin.season ~= nil
end

-- 지금 팔거나 받을 수 있는가. now가 nil이면 기간을 보지 않아요 (예전 호출)
function ShopLogic.onSale(skin: Skins.Skin, now: number?): boolean
	if now == nil then
		return true
	end
	return Seasons.skinOnSale(skin, now)
end

-- 그 이벤트 재화 (잘못된 값은 0)
function ShopLogic.tokensOf(wallet: { read eventTokens: { [string]: number }? }, eventId: string?): number
	local map = wallet.eventTokens
	if map == nil or eventId == nil then
		return 0
	end
	return validCoins(map[eventId])
end

function ShopLogic.canBuyWithTokens(
	skinId: unknown,
	wallet: Wallet,
	now: number,
	canSave: boolean?,
	locked: boolean?
): Decision
	local skin = Skins.get(skinId)
	if skin == nil then
		return { ok = false, reason = "UnknownSkin" }
	end
	local price = skin.tokens
	local eventId = skin.season
	if price == nil or eventId == nil then
		return { ok = false, reason = "NotForTokens" }
	end
	if not Seasons.isActive(eventId, now) then
		return { ok = false, reason = "EventEnded", price = price, eventId = eventId }
	end
	if wallet.ownedSkins[skin.id] == true then
		return { ok = false, reason = "AlreadyOwned", price = price, eventId = eventId }
	end
	if locked then
		return { ok = false, reason = "Locked", price = price, eventId = eventId }
	end
	if canSave == false then
		return { ok = false, reason = "CannotSave", price = price, eventId = eventId }
	end
	local have = ShopLogic.tokensOf(wallet, eventId)
	if have < price then
		return { ok = false, reason = "NeedTokens", price = price, missing = price - have, eventId = eventId }
	end
	return { ok = true, price = price, eventId = eventId }
end

-- 프로필을 바로 바꿔요. DataService.update 안에서 불러요: 다시 판단하고 재화 차감 + 보유 + 장착을 한 번에.
function ShopLogic.buyWithTokens(
	wallet: Wallet,
	skinId: unknown,
	now: number,
	canSave: boolean?,
	locked: boolean?
): Decision
	local decision = ShopLogic.canBuyWithTokens(skinId, wallet, now, canSave, locked)
	if not decision.ok then
		return decision
	end
	local skin = Skins.get(skinId) :: Skins.Skin
	local eventId = decision.eventId :: string
	local left = ShopLogic.tokensOf(wallet, eventId) - (decision.price :: number)
	local map: { [string]: number }? = wallet.eventTokens
	if map == nil then
		wallet.eventTokens = { [eventId] = left } -- 옛 모양 지갑 방어 (프로필은 ProfileLogic이 채워요)
	else
		map[eventId] = left
	end
	wallet.ownedSkins[skin.id] = true
	wallet.equippedSkin = skin.id
	return decision
end

-- 이벤트 탭 이름 (없는 이벤트면 재화 아이콘 + 이벤트 이름)
ShopLogic.EVENT_TAB_LABEL = {
	["halloween-2026"] = "🎃 할로윈",
	["christmas-2026"] = "🎄 크리스마스",
} :: { [string]: string }

-- 이벤트 탭 머리줄 아래 작은 안내 (D4: 압박하지 않는 문구)
ShopLogic.EVENT_NOTE = "이벤트가 끝나면 받을 수 없어요. 다음 해에 다시 올 수도 있어요."

local TIER_TABS: { Tab } = {
	{ id = "all", label = "전체" },
	{ id = "Common", label = "일반", tier = "Common" },
	{ id = "Rare", label = "레어", tier = "Rare" },
	{ id = "Epic", label = "에픽", tier = "Epic" },
	{ id = "Legendary", label = "전설", tier = "Legendary" },
}

function ShopLogic.eventTab(event: Seasons.Event): Tab
	local label = ShopLogic.EVENT_TAB_LABEL[event.id] or `{event.token.icon} {event.name}`
	return { id = "event", label = label, eventId = event.id }
end

function ShopLogic.tabs(now: number?): { Tab }
	local list: { Tab } = {}
	local event = if now then Seasons.current(now) else nil
	if event then
		table.insert(list, ShopLogic.eventTab(event))
	end
	for _, tab in TIER_TABS do
		table.insert(list, table.clone(tab))
	end
	return list
end

function ShopLogic.defaultTab(now: number?): Tab
	return ShopLogic.tabs(now)[1]
end

local function owns(view: ViewLike, skin: Skins.Skin): boolean
	return Skins.isFree(skin.id) or table.find(view.ownedSkins, skin.id) ~= nil
end

function ShopLogic.visibleSkins(view: ViewLike, tab: Tab?, now: number?): { Skins.Skin }
	local list: { Skins.Skin } = {}
	for _, skin in Skins.LIST do
		local owned = owns(view, skin)
		local limited = ShopLogic.isLimited(skin)
		if limited and not owned and not ShopLogic.onSale(skin, now) then
			continue -- 기간이 끝난 미보유 한정 스킨은 어디에도 안 보여요
		end
		local show = true -- 전체 탭(또는 탭 없음)
		if tab ~= nil and tab.eventId ~= nil then
			show = skin.season == tab.eventId
		elseif tab ~= nil and tab.tier ~= nil then
			show = skin.tier == tab.tier and (not limited or owned)
		end
		if show then
			table.insert(list, skin)
		end
	end
	return list
end

-- UTC 날짜 번호(1970-01-01 = 0) → 년, 월, 일 (os.date 없이, 순수. Howard Hinnant civil_from_days)
local function civilFromDays(days: number): (number, number, number)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

-- 마지막 날 (endsAt은 제외라서 endsAt − 1초의 UTC 날짜): "11월 5일"
function ShopLogic.lastDayText(event: Seasons.Event): string
	local _, month, day = civilFromDays((event.endsAt - 1) // 86400)
	return `{month}월 {day}일`
end

-- 이벤트 탭 머리줄: "할로윈 초밥 축제 · 11월 5일까지" (+ tokens가 있으면 " · 🍬 32"). 초 단위 카운트다운 없음 (D4)
function ShopLogic.eventHeader(event: Seasons.Event, _now: number?, tokens: number?): string
	local text = `{event.name} · {ShopLogic.lastDayText(event)}까지`
	if tokens ~= nil then
		text ..= ` · {event.token.icon} {tokens}`
	end
	return text
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
	NotForTokens = "이벤트 재화로는 받을 수 없어요",
	EventEnded = "이벤트 기간이 아니에요",
	NeedTokens = "이벤트 재화가 모자라요",
}

-- icon: NeedTokens의 재화 아이콘 (없으면 🍬)
function ShopLogic.message(reason: Reason?, missing: number?, icon: string?): string
	if reason == "NotEnoughCoins" and missing then
		return `🍚 {missing}개 더 필요해요`
	end
	if reason == "NeedTokens" and missing then
		return `{icon or "🍬"} {missing}개 더 필요해요`
	end
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

function ShopLogic.cardState(skin: Skins.Skin, view: ViewLike, robux: RobuxOptions?, now: number?): CardState
	local limited = if ShopLogic.isLimited(skin) then true else nil
	if view.equippedSkin == skin.id then
		return { kind = "Equipped", enabled = false, limited = limited }
	end
	if owns(view, skin) then
		return { kind = "Equip", enabled = true, limited = limited }
	end
	if skin.vipOnly then
		return { kind = "Vip", enabled = false }
	end
	if not ShopLogic.onSale(skin, now) then
		return { kind = "OffSale", enabled = false }
	end
	local price = skin.tokens
	local event = if skin.season then Seasons.get(skin.season) else nil
	if price ~= nil and event ~= nil then
		local have = ShopLogic.tokensOf(view, event.id)
		local kind: CardKind = if have >= price then "Tokens" else "NeedTokens"
		return { kind = kind, price = price, tokens = have, icon = event.token.icon, enabled = kind == "Tokens" }
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
	if robuxPrice == nil then
		return { kind = "Soon", enabled = false }
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
	elseif state.kind == "Soon" then
		return "곧 열려요"
	elseif state.kind == "Tokens" then
		return `{state.icon or "🍬"} {state.price}으로 받기`
	elseif state.kind == "NeedTokens" then
		return `{state.icon or "🍬"} {state.tokens or 0} / {state.price}`
	elseif state.kind == "Vip" then
		return "👑 VIP 전용"
	elseif state.kind == "OffSale" then
		return "판매 기간이 아니에요"
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
