--!strict
-- 스킨 카탈로그 (GDD 9.1, 9.2, m4-13). 순수 데이터 + 조회 함수라 Roblox API를 쓰지 않아요 (tests/skins.spec.luau).
--   Skins.LIST              전체 스킨 (order 오름차순). 시즌 한정·VIP 스킨은 m5-03 (생김새는 m5-07).
--   Skins.get(id)           id의 스킨, 없으면 nil (id가 문자열이 아니어도 nil)
--   Skins.TIERS             등급 순서 (기본 → 전설)
--   Skins.TIER_INFO[tier]   등급 이름·색 (탈의실 카드 테두리)
--   Skins.byTier(tier?)     그 등급 스킨 목록 (nil이면 전체), order 순
--   Skins.forProduct(productId)  개발자 상품 id → 스킨 (m4-14 결제가 써요)
--   Skins.validate(list)    카탈로그 검사: (ok, 문제 목록). 테스트와 서버 시작 때 한 번
-- 생김새는 Shared.SushiBody.layout(id), 탈락 말풍선은 speech → EliminationCutsceneLogic.SKIN_LINES.
-- 모든 스킨은 겉모습만 바꿔요 (GDD 9.1 Pay-to-Win 금지): 크기·판정·속도는 같아요.
-- 가격: 로벅스는 개발자 상품으로 팔아요 (m4-14). 사용자가 Creator Dashboard에서 만든 상품 id를 아래 각 스킨의
-- productId에 넣으면 그 스킨의 로벅스 버튼이 켜져요 (nil이면 "곧 열려요"). 계란초밥은 무료라 상품 없음.
-- 코인 해금은 일반·레어 등급만 (GDD 9.4).
-- 얻는 길 (m5-03): 기본 스킨이 아니면 robux·tokens·vipOnly 중 정확히 하나. 코인은 일반·레어에 추가로 가능(시즌 스킨은 안 됨).

export type Tier = "Basic" | "Common" | "Rare" | "Epic" | "Legendary"

export type Skin = {
	id: string,
	displayName: string,
	tier: Tier,
	robux: number?, -- 로벅스 가격 (기본 스킨은 nil)
	coins: number?, -- 밥알 코인 해금 가격 (일반·레어 등급만, 나머지는 nil)
	season: string?, -- 시즌 한정 이벤트 id (Shared.Seasons, m5-03). 있으면 그 이벤트 기간에만 팔아요
	tokens: number?, -- 이벤트 재화 가격 (season 필수, m5-07 교환)
	vipOnly: boolean?, -- VIP 게임 패스가 있으면 받는 스킨 (m5-08)
	productId: number?, -- 개발자 상품 id (사용자가 상품을 만든 뒤 채워요, USER-TODO C3). 예: productId = 1234567890,
	speech: { string }, -- 탈락 말풍선 대사 1~2줄
	order: number, -- 탈의실 정렬 순서
}

export type TierInfo = {
	displayName: string,
	color: { number }, -- {r, g, b} 0~255
}

local Config = require(script.Parent.Config)
local Seasons = require(script.Parent.Seasons)
local SushiBody = require(script.Parent.SushiBody)

local Skins = {}

Skins.DEFAULT_ID = Config.Appearance.Default -- "tamago"
Skins.COMMON_COINS = 300 -- 일반 스킨 코인 해금 가격 (GDD 9.4)
Skins.RARE_COINS = 900 -- 레어 스킨 코인 해금 가격 (GDD 9.4)

Skins.TIERS = { "Basic", "Common", "Rare", "Epic", "Legendary" } :: { Tier }

Skins.TIER_INFO = {
	Basic = { displayName = "기본", color = { 200, 190, 170 } },
	Common = { displayName = "일반", color = { 120, 180, 110 } },
	Rare = { displayName = "레어", color = { 80, 150, 230 } },
	Epic = { displayName = "에픽", color = { 170, 100, 220 } },
	Legendary = { displayName = "전설", color = { 240, 170, 40 } },
} :: { [Tier]: TierInfo }

local COINS = Skins.COMMON_COINS
local RARE_COINS = Skins.RARE_COINS

Skins.LIST = {
	{
		id = "tamago",
		displayName = "계란초밥",
		tier = "Basic",
		speech = { "계란초밥은 역시 달달해", "폭신폭신 계란 최고!" },
		order = 1,
	},
	{
		id = "salmon",
		displayName = "연어",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "연어는 언제나 옳아!", "기름기가 살살 녹네~" },
		order = 2,
	},
	{
		id = "tuna",
		displayName = "참치",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "참치는 빨개야 제맛!", "쫄깃쫄깃 참치~" },
		order = 3,
	},
	{
		id = "shrimp",
		displayName = "새우",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "꼬리까지 바삭!", "탱글탱글 새우다!" },
		order = 4,
	},
	{
		id = "inari",
		displayName = "유부",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "달콤한 유부 주머니~", "속이 꽉 찼네!" },
		order = 5,
	},
	{
		id = "kappa-maki",
		displayName = "오이마키",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "아삭아삭 오이!", "상큼하다~" },
		order = 6,
	},
	{
		id = "eel",
		displayName = "장어",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "소스가 끝내줘!", "장어 먹고 힘내자~" },
		order = 7,
	},
	{
		id = "uni",
		displayName = "성게",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "바다 향이 가득해", "고소한 성게 최고!" },
		order = 8,
	},
	{
		id = "ikura",
		displayName = "연어알 군함",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "톡톡 터지는 맛!", "알알이 반짝반짝~" },
		order = 9,
	},
	{
		id = "octopus",
		displayName = "문어",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "빨판이 쫀득해!", "문어는 씹는 맛이지~" },
		order = 10,
	},
	{
		id = "rainbow-roll",
		displayName = "무지개 롤",
		tier = "Epic",
		robux = 99,
		speech = { "한 입에 일곱 가지 맛!", "알록달록 예쁘다~" },
		order = 11,
	},
	{
		id = "aburi-salmon",
		displayName = "불꽃 연어",
		tier = "Epic",
		robux = 99,
		speech = { "앗 뜨거, 불맛 최고!", "살짝 그을려서 더 맛있어" },
		order = 12,
	},
	{
		id = "california-roll",
		displayName = "아보카도 캘리포니아롤",
		tier = "Epic",
		robux = 99,
		speech = { "아보카도가 부드러워~", "날치알이 톡톡!" },
		order = 13,
	},
	{
		id = "golden-otoro",
		displayName = "황금 참치 뱃살",
		tier = "Legendary",
		robux = 199,
		speech = { "황금빛 뱃살이라니!", "입에서 사르르 녹아~" },
		order = 14,
	},
	{
		id = "diamond-uni",
		displayName = "다이아 성게",
		tier = "Legendary",
		robux = 199,
		speech = { "반짝반짝 보석 같아!", "이건 정말 귀한 맛이야" },
		order = 15,
	},
	{
		id = "dragon-roll",
		displayName = "용 롤",
		tier = "Legendary",
		robux = 199,
		speech = { "용을 먹다니 대단해!", "불을 뿜을 것 같은 맛!" },
		order = 16,
	},
	-- 시즌 한정 (m5-03 데이터, 생김새·교환은 m5-07). 유료 한정은 기간 중에만 결제 창이 열려요 (ReceiptLogic.canRequest)
	{
		id = "pumpkin-sushi",
		displayName = "호박 초밥",
		tier = "Epic",
		robux = 99,
		season = "halloween-2026",
		speech = { "호박 맛이 달콤해~", "트릭 오어 트릿!" },
		order = 17,
	},
	{
		id = "ghost-tamago",
		displayName = "유령 계란초밥",
		tier = "Rare",
		tokens = 80,
		season = "halloween-2026",
		speech = { "부우~ 놀랐지?", "계란도 유령이 될 수 있어" },
		order = 18,
	},
	{
		id = "santa-shrimp",
		displayName = "산타 새우",
		tier = "Epic",
		robux = 99,
		season = "christmas-2026",
		speech = { "메리 크리스마스!", "선물 배달 왔어요~" },
		order = 19,
	},
	{
		id = "tree-maki",
		displayName = "트리 마키",
		tier = "Rare",
		tokens = 80,
		season = "christmas-2026",
		speech = { "반짝반짝 트리 마키!", "오이가 트리가 됐어" },
		order = 20,
	},
	-- VIP 전용 (m5-08이 게임 패스 확인 뒤 지급)
	{
		id = "vip-gold-tamago",
		displayName = "금박 계란초밥",
		tier = "Legendary",
		vipOnly = true,
		speech = { "반짝이는 VIP 계란!", "금박이 살살 녹아~" },
		order = 21,
	},
} :: { Skin }

table.sort(Skins.LIST, function(a: Skin, b: Skin): boolean
	return a.order < b.order
end)

local byId: { [string]: Skin } = {}
for _, skin in Skins.LIST do
	byId[skin.id] = skin
end

function Skins.get(id: unknown): Skin?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Skins.byTier(tier: Tier?): { Skin }
	local list: { Skin } = {}
	for _, skin in Skins.LIST do
		if tier == nil or skin.tier == tier then
			table.insert(list, skin)
		end
	end
	return list
end

function Skins.forProduct(productId: unknown): Skin?
	if type(productId) ~= "number" then
		return nil
	end
	for _, skin in Skins.LIST do
		if skin.productId == productId then
			return skin
		end
	end
	return nil
end

local function isPrice(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value % 1 == 0 and value < math.huge
end

-- 카탈로그 규칙: id·순서 겹침 없음, 등급 유효, 기본 스킨은 무료, 코인은 일반·레어 등급만, 대사 1~2줄,
-- 전용 레이아웃이 있는 스킨은 등급별 효과 예산(SushiBody.EFFECT_BUDGET)·박스 허용치(SushiBody.BOUNDS_TOLERANCE)
-- 를 지켜요 (m5-21). 레이아웃이 없는(SushiBody.hasLayout == false) 가짜 id는 이 기하 검사를 건너뛰어요 —
-- "validate가 잘못된 카탈로그를 잡아요" 같은 테스트가 가짜 id를 쓰기 때문.
function Skins.validate(list: { Skin }): (boolean, { string })
	local problems: { string } = {}
	local ids: { [string]: boolean } = {}
	local orders: { [number]: boolean } = {}
	local products: { [number]: boolean } = {}
	local hasDefault = false
	local baseBounds = SushiBody.bounds(SushiBody.layout(Skins.DEFAULT_ID))
	local baseExtents = {
		baseBounds.max[1] - baseBounds.min[1],
		baseBounds.max[2] - baseBounds.min[2],
		baseBounds.max[3] - baseBounds.min[3],
	}
	for index, skin in list do
		local where = `#{index} {tostring(skin.id)}`
		if type(skin.id) ~= "string" or skin.id == "" then
			table.insert(problems, `{where}: id must be a non-empty string`)
		elseif ids[skin.id] then
			table.insert(problems, `{where}: duplicate id`)
		end
		ids[skin.id] = true
		if type(skin.displayName) ~= "string" or skin.displayName == "" then
			table.insert(problems, `{where}: displayName missing`)
		end
		if Skins.TIER_INFO[skin.tier] == nil then
			table.insert(problems, `{where}: unknown tier {tostring(skin.tier)}`)
		end
		if orders[skin.order] then
			table.insert(problems, `{where}: duplicate order {skin.order}`)
		end
		orders[skin.order] = true
		if skin.id == Skins.DEFAULT_ID then
			hasDefault = true
			if skin.tier ~= "Basic" or skin.robux ~= nil or skin.coins ~= nil then
				table.insert(problems, `{where}: default skin must be Basic and free`)
			end
		else
			if skin.tier == "Basic" then
				table.insert(problems, `{where}: only the default skin is Basic`)
			end
			-- 얻는 길은 robux·tokens·vipOnly 중 정확히 하나 (m5-03)
			local ways = 0
			if skin.robux ~= nil then
				ways += 1
				if not isPrice(skin.robux) then
					table.insert(problems, `{where}: bad robux price`)
				end
			end
			if skin.tokens ~= nil then
				ways += 1
				if not isPrice(skin.tokens) then
					table.insert(problems, `{where}: bad tokens price`)
				end
				if skin.season == nil then
					table.insert(problems, `{where}: tokens need a season`)
				end
			end
			if skin.vipOnly ~= nil then
				if skin.vipOnly ~= true then
					table.insert(problems, `{where}: vipOnly must be true or nil`)
				else
					ways += 1
					if skin.season ~= nil or skin.coins ~= nil or skin.robux ~= nil then
						table.insert(problems, `{where}: vipOnly skins have no season, coins or robux`)
					end
				end
			end
			if ways == 0 then
				table.insert(problems, `{where}: needs a way to get it (robux, tokens or vipOnly)`)
			elseif ways > 1 then
				table.insert(problems, `{where}: only one of robux, tokens or vipOnly`)
			end
		end
		if skin.coins ~= nil and ((skin.tier ~= "Common" and skin.tier ~= "Rare") or not isPrice(skin.coins)) then
			table.insert(problems, `{where}: coin price only for Common and Rare skins`)
		end
		if skin.season ~= nil then
			if type(skin.season) ~= "string" or Seasons.get(skin.season) == nil then
				table.insert(problems, `{where}: unknown season {tostring(skin.season)}`)
			end
			if skin.coins ~= nil then
				table.insert(problems, `{where}: season skins have no coin price`)
			end
		end
		if skin.productId ~= nil and skin.robux == nil then
			table.insert(problems, `{where}: productId only for robux skins`)
		end
		if skin.productId ~= nil then
			if not isPrice(skin.productId) then
				table.insert(problems, `{where}: bad productId`)
			elseif products[skin.productId] then
				table.insert(problems, `{where}: duplicate productId`)
			else
				products[skin.productId] = true
			end
		end
		if SushiBody.hasLayout(skin.id) then
			local layout = SushiBody.layout(skin.id)
			local budget = SushiBody.EFFECT_BUDGET[skin.tier]
			if budget ~= nil then
				local count = SushiBody.effectCount(layout)
				if count > budget then
					table.insert(
						problems,
						`{where}: effect budget exceeded ({count} > {budget} for tier {tostring(skin.tier)})`
					)
				end
			end
			local tolerance = SushiBody.BOUNDS_TOLERANCE[skin.tier]
			if tolerance ~= nil then
				local bounds = SushiBody.bounds(layout)
				for axis = 1, 3 do
					local size = bounds.max[axis] - bounds.min[axis]
					local ratio = size / baseExtents[axis]
					if ratio < 1 - tolerance or ratio > 1 + tolerance then
						local tierName = tostring(skin.tier)
						table.insert(
							problems,
							`{where}: bounds axis {axis} outside tolerance (ratio {ratio} vs tier {tierName} tolerance {tolerance})`
						)
					end
				end
			end
		end
		local speech = skin.speech
		if type(speech) ~= "table" or #speech < 1 or #speech > 2 then
			table.insert(problems, `{where}: speech must have 1~2 lines`)
		else
			for _, line in speech do
				if type(line) ~= "string" or line == "" then
					table.insert(problems, `{where}: empty speech line`)
				end
			end
		end
	end
	if not hasDefault then
		table.insert(problems, `default skin {Skins.DEFAULT_ID} missing`)
	end
	return #problems == 0, problems
end

return Skins
