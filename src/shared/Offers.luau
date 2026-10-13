--!strict
-- 특별 상품 카탈로그 (m5-08, GDD 9.1·9.3·9.5). "🎁 상점"에서 파는 스킨 말고의 상품이에요. 전부 겉모습뿐 (능력치 없음).
-- 순수 데이터 + 검사라 Roblox API를 쓰지 않아요 (tests/offer-logic.spec.luau).
--   Bundle = 스킨 묶음 (개발자 상품, 계정당 1번, 안의 스킨을 하나도 안 가졌을 때만 — 판단은 Shared.OfferLogic)
--   Fx     = 탈락·우승 연출 (개발자 상품, 안 가졌을 때만. 연출 id는 Shared.FxCatalog, 모습은 m5-09)
--   Pass   = VIP 게임 패스 (전용 스킨·이름표 👑·채팅 [VIP]. 코인 배수 없음 — 스펙 결정 D1)
-- productId·gamePassId는 사용자가 Creator Hub에서 만들어 채워요 (nil이면 버튼 "곧 열려요").
--
--   Offers.LIST / Offers.get(id) / Offers.forProduct(productId) / Offers.forPass(passId)
--   Offers.validate(list, skins?) -> (ok, problems)   skins = 스킨 목록 (기본 Skins.LIST, 상품 id 겹침 검사용)

local FxCatalog = require(script.Parent.FxCatalog)
local Skins = require(script.Parent.Skins)

export type Kind = "Bundle" | "Fx" | "Pass"
export type Offer = {
	id: string,
	displayName: string,
	kind: Kind,
	robux: number, -- 카탈로그 가격 (실제 가격은 PriceCache가 받아 와요)
	productId: number?, -- 개발자 상품 id (Bundle·Fx)
	gamePassId: number?, -- 게임 패스 id (Pass)
	skins: { string }?, -- 주는 스킨
	fx: { string }?, -- 주는 연출
	perks: { string }?, -- 화면 글씨 (VIP 혜택)
	blurb: string?, -- 카드 한 줄 설명
	order: number,
}

local Offers = {}

Offers.LIST = {
	{
		id = "starter-pack",
		displayName = "스타터 팩",
		kind = "Bundle",
		robux = 79,
		productId = nil,
		skins = { "salmon", "tuna", "shrimp", "eel" },
		blurb = "처음 오신 분을 위한 묶음",
		order = 1,
	},
	{
		id = "epic-set",
		displayName = "에픽 세트",
		kind = "Bundle",
		robux = 249,
		productId = nil,
		skins = { "rainbow-roll", "aburi-salmon", "california-roll" },
		blurb = "에픽 스킨 3종",
		order = 2,
	},
	{
		id = "legendary-set",
		displayName = "전설 세트",
		kind = "Bundle",
		robux = 499,
		productId = nil,
		skins = { "golden-otoro", "diamond-uni", "dragon-roll" },
		blurb = "전설 스킨 3종",
		order = 3,
	},
	{
		id = "fx-cat-customer",
		displayName = "탈락 연출: 고양이 손님",
		kind = "Fx",
		robux = 59,
		productId = nil,
		fx = { "cat-customer" },
		blurb = "내가 먹힐 때 손님이 고양이로 바뀌어요",
		order = 4,
	},
	{
		id = "fx-fireworks",
		displayName = "우승 연출: 불꽃놀이",
		kind = "Fx",
		robux = 99,
		productId = nil,
		fx = { "fireworks" },
		blurb = "내가 우승할 때 불꽃놀이가 터져요",
		order = 5,
	},
	{
		id = "vip",
		displayName = "VIP 패스",
		kind = "Pass",
		robux = 149,
		gamePassId = nil,
		skins = { "vip-gold-tamago" },
		perks = { '전용 스킨 "금박 계란초밥"', "이름표 앞에 👑", "채팅에 [VIP] 태그" },
		blurb = "겉모습만 달라져요 (코인 배수 없음)",
		order = 6,
	},
} :: { Offer }

local byId: { [string]: Offer } = {}
for _, offer in Offers.LIST do
	byId[offer.id] = offer
end

function Offers.get(id: unknown): Offer?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Offers.forProduct(productId: unknown): Offer?
	if type(productId) ~= "number" then
		return nil
	end
	for _, offer in Offers.LIST do
		if offer.productId == productId then
			return offer
		end
	end
	return nil
end

function Offers.forPass(passId: unknown): Offer?
	if type(passId) ~= "number" then
		return nil
	end
	for _, offer in Offers.LIST do
		if offer.gamePassId == passId then
			return offer
		end
	end
	return nil
end

-- 연출의 칸 (Fx 상품이 장착할 칸). 없으면 nil
function Offers.fxSlot(offer: Offer): FxCatalog.Slot?
	local fxIds = offer.fx
	if fxIds == nil or fxIds[1] == nil then
		return nil
	end
	local fx = FxCatalog.get(fxIds[1])
	return if fx then fx.slot else nil
end

local function isPositiveInt(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value % 1 == 0 and value < math.huge
end

-- 규칙: id·order 겹침 없음, 상품·패스 id 겹침 없음(스킨 상품 id와도), 가격 양의 정수,
-- Bundle: 스킨 2개 이상·전부 카탈로그·시즌/VIP 전용/기본 스킨 아님·productId만(패스 없음),
-- Fx: 연출 1개 이상·전부 FxCatalog·productId만, Pass: productId 없음·스킨은 vipOnly만.
function Offers.validate(list: { any }, skins: { any }?): (boolean, { string })
	local problems: { string } = {}
	local ids: { [string]: boolean } = {}
	local orders: { [number]: boolean } = {}
	local products: { [number]: string } = {}
	local passes: { [number]: boolean } = {}
	for _, skin in skins or Skins.LIST do
		if type(skin) == "table" and type(skin.productId) == "number" then
			products[skin.productId] = `skin {tostring(skin.id)}`
		end
	end
	local function skinOf(id: unknown): any
		if skins == nil then
			return Skins.get(id)
		end
		for _, skin in skins do
			if type(skin) == "table" and skin.id == id then
				return skin
			end
		end
		return nil
	end

	for index, offer in list do
		if type(offer) ~= "table" or type(offer.id) ~= "string" or offer.id == "" then
			table.insert(problems, `#{index}: id must be a non-empty string`)
			continue
		end
		local where = offer.id
		if ids[where] then
			table.insert(problems, `{where}: duplicate id`)
		end
		ids[where] = true
		if type(offer.displayName) ~= "string" or offer.displayName == "" then
			table.insert(problems, `{where}: displayName missing`)
		end
		if type(offer.order) ~= "number" or offer.order % 1 ~= 0 then
			table.insert(problems, `{where}: order must be an integer`)
		elseif orders[offer.order] then
			table.insert(problems, `{where}: duplicate order {offer.order}`)
		else
			orders[offer.order] = true
		end
		if not isPositiveInt(offer.robux) then
			table.insert(problems, `{where}: robux must be a positive integer`)
		end
		if offer.productId ~= nil then
			if not isPositiveInt(offer.productId) then
				table.insert(problems, `{where}: bad productId`)
			elseif products[offer.productId] then
				table.insert(problems, `{where}: productId already used by {products[offer.productId]}`)
			else
				products[offer.productId] = `offer {where}`
			end
		end
		if offer.gamePassId ~= nil then
			if not isPositiveInt(offer.gamePassId) then
				table.insert(problems, `{where}: bad gamePassId`)
			elseif passes[offer.gamePassId] then
				table.insert(problems, `{where}: duplicate gamePassId`)
			else
				passes[offer.gamePassId] = true
			end
		end

		local kind = offer.kind
		local skinIds = offer.skins
		local fxIds = offer.fx
		if skinIds ~= nil and type(skinIds) ~= "table" then
			table.insert(problems, `{where}: skins must be a list`)
			skinIds = nil
		end
		if fxIds ~= nil and type(fxIds) ~= "table" then
			table.insert(problems, `{where}: fx must be a list`)
			fxIds = nil
		end
		if kind == "Bundle" then
			if offer.gamePassId ~= nil then
				table.insert(problems, `{where}: bundles are developer products (no gamePassId)`)
			end
			if skinIds == nil or #skinIds < 2 then
				table.insert(problems, `{where}: bundle needs at least 2 skins`)
			end
			if fxIds ~= nil and #fxIds > 0 then
				table.insert(problems, `{where}: bundle gives skins only`)
			end
			local seen: { [string]: boolean } = {}
			for _, skinId in skinIds or {} do
				local skin = skinOf(skinId)
				if skin == nil then
					table.insert(problems, `{where}: unknown skin {tostring(skinId)}`)
				elseif seen[skinId] then
					table.insert(problems, `{where}: duplicate skin {skinId}`)
				elseif skin.vipOnly or skin.season ~= nil or skin.robux == nil then
					table.insert(
						problems,
						`{where}: skin {skinId} is not a regular robux skin (season, VIP or default)`
					)
				end
				seen[skinId] = true
			end
		elseif kind == "Fx" then
			if offer.gamePassId ~= nil then
				table.insert(problems, `{where}: fx offers are developer products (no gamePassId)`)
			end
			if fxIds == nil or #fxIds < 1 then
				table.insert(problems, `{where}: fx offer needs an fx id`)
			end
			if skinIds ~= nil and #skinIds > 0 then
				table.insert(problems, `{where}: fx offer gives fx only`)
			end
			for _, fxId in fxIds or {} do
				if FxCatalog.get(fxId) == nil then
					table.insert(problems, `{where}: unknown fx {tostring(fxId)}`)
				end
			end
		elseif kind == "Pass" then
			if offer.productId ~= nil then
				table.insert(problems, `{where}: passes use gamePassId (no productId)`)
			end
			if fxIds ~= nil and #fxIds > 0 then
				table.insert(problems, `{where}: pass gives no fx`)
			end
			for _, skinId in skinIds or {} do
				local skin = skinOf(skinId)
				if skin == nil then
					table.insert(problems, `{where}: unknown skin {tostring(skinId)}`)
				elseif skin.vipOnly ~= true then
					table.insert(problems, `{where}: pass skin {skinId} must be vipOnly`)
				end
			end
		else
			table.insert(problems, `{where}: kind must be Bundle, Fx or Pass`)
		end
	end
	return #problems == 0, problems
end

return Offers
