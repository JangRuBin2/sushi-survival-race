--!strict
-- 스킨 카탈로그 (GDD 9.1, 9.2, m4-13). 순수 데이터 + 조회 함수라 Roblox API를 쓰지 않아요 (tests/skins.spec.luau).
--   Skins.LIST              전체 스킨 (order 오름차순). 시즌 한정·VIP 스킨은 m5-03 (생김새는 m5-07).
--   Skins.get(id)           id의 스킨, 없으면 nil (id가 문자열이 아니어도 nil)
--   Skins.TIERS             등급 순서 (기본 → 전설)
--   Skins.TIER_INFO[tier]   등급 이름·색 (탈의실 카드 테두리)
--   Skins.byTier(tier?)     그 등급 스킨 목록 (nil이면 전체), order 순
--   Skins.forProduct(productId)  개발자 상품 id → 스킨 (m4-14 결제가 써요)
--   Skins.validate(list)    카탈로그 검사: (ok, 문제 목록). 테스트와 서버 시작 때 한 번
--   Skins.isFree(id)        모두가 처음부터 가진 무료 스킨인가 (계란초밥만, m5-31). 보유 판단은 이걸로 해요
--   Skins.isDraw(id)        🎫 뽑기에서 나오는 스킨인가 (drawGrade가 있는가, m5-31)
--   Skins.isDrawOnly(id)    뽑기로만 얻는 스킨인가 (drawGrade + 다른 얻는 길 없음 — 특 9종)
--   Skins.DRAW_IDS          drawGrade를 달 수 있는 id (명시 목록, validate가 같은지 확인. m5-32가 fresh-mackerel을 더해요)
--   Skins.drawGradeOf(id)   그 스킨의 뽑기 등급 (없으면 nil)
--   Skins.DRAW_GRADES       뽑기 등급 순서 (전설 → 일반). 상점 등급(tier)과 별개예요
--   Skins.DRAW_GRADE_INFO   뽑기 등급 이름·영어 이름·색 (확률표·배지)
--   Skins.DRAW_INFO         탈의실 카드 구석 "🎫 특" 표시 이름·색 (뽑기 스킨)
--   Skins.CONCEPT_BODY_IDS  콘셉트 몸 스킨 id (m5-27 concept-salmon, m5-28 concept-tuna·shrimp·tamago·ikura, m5-29 unagi·uni·tako·inari,
--                           m5-32 fresh-mackerel). conceptBody = true(몸 모양 예외 — SushiBody.CONCEPT_BODY 파츠 상한·외곽 규칙)는
--                           여기 있는 id만 쓸 수 있어요. 콘셉트 몸은 등급과 무관해요(특 = Basic + 뽑기 전용, 고등어 = 전설 판매 + 뽑기)
-- 생김새는 Shared.SushiBody.layout(id), 탈락 말풍선은 speech → EliminationCutsceneLogic.SKIN_LINES.
-- 모든 스킨은 겉모습만 바꿔요 (GDD 9.1 Pay-to-Win 금지): 크기·판정·속도는 같아요.
-- 가격: 로벅스는 개발자 상품으로 팔아요 (m4-14). 사용자가 Creator Dashboard에서 만든 상품 id를 아래 각 스킨의
-- productId에 넣으면 그 스킨의 로벅스 버튼이 켜져요 (nil이면 "곧 열려요"). 계란초밥은 무료라 상품 없음.
-- 코인 해금은 일반·레어 등급만 (GDD 9.4).
-- 얻는 길 (m5-03): 기본 스킨이 아니면 robux·tokens·vipOnly 중 정확히 하나. 코인은 일반·레어에 추가로 가능(시즌 스킨은 안 됨).
-- 🎫 뽑기 (m5-31): drawGrade가 있으면 뽑기 풀에 들어가요(데이터로 정해요 — 목록 하드코딩 없음). 뽑기로만 얻는 스킨은
--   가격·시즌·VIP·상품 id 없이 내부 등급 Basic(화면에서는 "🎫 특" + 뽑기 등급 배지). 로벅스 스킨에 drawGrade를 달면
--   뽑기와 판매 둘 다 돼요(m5-32 고등어 [신선] 전설). 시즌·재화·VIP 스킨은 뽑기에 넣지 않아요. 보유는 저장된 ownedSkins.

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
	-- 콘셉트 몸 스킨 (m5-27, m5-32에서 지금 이름으로 바꿈): SushiBody.CONCEPT_BODY의 몸 모양 예외(자기 몸 모양,
	-- 파츠 상한)를 받아요. 몸 모양만 뜻하고 가격·얻는 길과는 무관해요 (특 9종 = 뽑기 전용, 고등어 = 전설 판매 + 뽑기)
	conceptBody: boolean?,
	-- 🎫 뽑기 등급 (m5-31). 있으면 뽑기 풀에 들어가요. 상점 등급(tier)과 별개
	drawGrade: DrawGrade?,
}

-- 뽑기 등급 (m5-31): 전설 Legendary / 영웅 Epic / 희귀 Rare / 고급 Uncommon / 일반 Common
export type DrawGrade = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type DrawGradeInfo = {
	displayName: string, -- "영웅"
	english: string, -- "Epic"
	color: { number }, -- {r, g, b} 확률표 줄·배지·왕관 색
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

-- 콘셉트 몸 스킨으로 허용하는 id (명시적 예외 목록 — SushiBody.CONCEPT_BODY와 같아야 해요)
-- m5-27 연어 + m5-28 참치·새우·계란·연어알 군함 + m5-29 장어·성게·문어·유부 (뽑기 전용 특 스킨) + m5-32 고등어 [신선]
Skins.CONCEPT_BODY_IDS = {
	["concept-salmon"] = true,
	["concept-tuna"] = true,
	["concept-shrimp"] = true,
	["concept-tamago"] = true,
	["concept-ikura"] = true,
	-- m5-29 장어·성게 군함·문어·유부
	["concept-unagi"] = true,
	["concept-uni"] = true,
	["concept-tako"] = true,
	["concept-inari"] = true,
	-- m5-32 판매 스킨도 콘셉트 몸을 써요
	["fresh-mackerel"] = true,
} :: { [string]: boolean }

-- 🎫 drawGrade가 있는 id (m5-31, 명시 목록 — validate가 카탈로그와 같은지 봐요). 특 9종 + m5-32 고등어 [신선]
Skins.DRAW_IDS = {
	["concept-salmon"] = true,
	["concept-tuna"] = true,
	["concept-shrimp"] = true,
	["concept-tamago"] = true,
	["concept-ikura"] = true,
	["concept-unagi"] = true,
	["concept-uni"] = true,
	["concept-tako"] = true,
	["concept-inari"] = true,
	["fresh-mackerel"] = true, -- m5-32 전설 (판매 + 뽑기)
} :: { [string]: boolean }

-- drawGrade + robux 스킨(m5-32 고등어)이 지켜야 하는 등급별 로벅스 가격 (가격 A안)
Skins.TIER_ROBUX = { Common = 29, Rare = 59, Epic = 99, Legendary = 199 } :: { [string]: number }

-- 🎫 뽑기 등급 순서 (높은 것부터, m5-31) — 확률은 Config.Draw.GradeWeights
Skins.DRAW_GRADES = { "Legendary", "Epic", "Rare", "Uncommon", "Common" } :: { DrawGrade }

Skins.DRAW_GRADE_INFO = {
	Legendary = { displayName = "전설", english = "Legendary", color = { 245, 180, 40 } },
	Epic = { displayName = "영웅", english = "Epic", color = { 160, 90, 225 } },
	Rare = { displayName = "희귀", english = "Rare", color = { 60, 130, 235 } },
	Uncommon = { displayName = "고급", english = "Uncommon", color = { 60, 170, 80 } },
	Common = { displayName = "일반", english = "Common", color = { 140, 140, 150 } },
} :: { [DrawGrade]: DrawGradeInfo }

-- 특 스킨 카드 테두리·표시 (등급 대신, m5-31). 내부 tier는 Basic 그대로예요
Skins.DRAW_INFO = { displayName = "🎫 특", color = { 255, 140, 30 } } :: TierInfo

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
	-- 스킨 1차 배치 10종 (m5-22, docs/proposals/skin-quality-and-variety.md §3)
	{
		id = "takoyaki",
		displayName = "타코야키",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "동글동글 타코야키~", "소스 범벅이 최고야!" },
		order = 22,
	},
	{
		id = "egg-toast",
		displayName = "에그토스트",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "폭신폭신 식빵 위에 반숙 노른자!", "한 입 베어 물면 사르르~" },
		order = 23,
	},
	{
		id = "slider-burger",
		displayName = "슬라이더 버거",
		tier = "Common",
		robux = 29,
		coins = COINS,
		speech = { "작아도 한 입 가득 든든해!", "패티 육즙이 살아있어~" },
		order = 24,
	},
	{
		id = "tonkatsu",
		displayName = "돈가스",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "바삭한 튀김옷이 일품!", "소스 듬뿍 찍어 먹자~" },
		order = 25,
	},
	{
		id = "cat-sushi",
		displayName = "고양이 초밥",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "야옹~ 잡아봐!", "수염도 쫑긋, 귀도 쫑긋!" },
		order = 26,
	},
	{
		id = "robo-roll",
		displayName = "로보 롤",
		tier = "Rare",
		robux = 59,
		coins = RARE_COINS,
		speech = { "삐빅, 시스템 가동 완료!", "레이더에 간장이 감지됨!" },
		order = 27,
	},
	{
		id = "galaxy-roll",
		displayName = "갤럭시 롤",
		tier = "Epic",
		robux = 99,
		speech = { "우주의 맛이 느껴져?", "별빛처럼 반짝반짝~" },
		order = 28,
	},
	{
		id = "softserve-roll",
		displayName = "소프트아이스크림 롤",
		tier = "Epic",
		robux = 99,
		speech = { "살살 녹는 소프트콘!", "체리 하나로 완성!" },
		order = 29,
	},
	{
		id = "crown-tuna",
		displayName = "크라운 참치",
		tier = "Legendary",
		robux = 199,
		speech = { "오늘의 왕은 나야!", "참치 중의 참치, 왕관을 쓰다" },
		order = 30,
	},
	{
		id = "unicorn-roll",
		displayName = "유니콘 롤",
		tier = "Legendary",
		robux = 199,
		speech = { "마법 같은 맛이지?", "무지갯빛 꿈을 싣고 달려!" },
		order = 31,
	},
	-- 🎫 뽑기 전용 특 스킨 (m5-31): 콘셉트 몸 9종 (m5-27 연어 — 사용자 콘셉트 시트)
	{
		id = "concept-salmon",
		displayName = "연어초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Epic", -- 뽑기 등급 (m5-31)
		speech = { "새 모습 어때?", "연어 돔이 말랑말랑~" },
		order = 32,
	},
	-- m5-28 콘셉트 몸 4종 (concept-salmon과 같은 밥·얼굴·팔다리, 토핑만 달라요)
	{
		id = "concept-tuna",
		displayName = "참치초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Uncommon", -- 뽑기 등급 (m5-31)
		speech = { "참치는 빨강이 생명!", "결 따라 데굴데굴~" },
		order = 33,
	},
	{
		id = "concept-shrimp",
		displayName = "새우초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Common", -- 뽑기 등급 (m5-31)
		speech = { "꼬리가 먼저 떨어졌어…", "탱글탱글 새우 출동!" },
		order = 34,
	},
	{
		id = "concept-tamago",
		displayName = "계란초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Common", -- 뽑기 등급 (m5-31)
		speech = { "폭신한 계란 착지 실패!", "김 띠 꽉 묶을걸…" },
		order = 35,
	},
	{
		id = "concept-ikura",
		displayName = "연어알 군함 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Rare", -- 뽑기 등급 (m5-31)
		speech = { "알이 다 쏟아졌어!", "톡톡 터지는 맛~" },
		order = 36,
	},
	-- m5-29 콘셉트 몸 2차 4종 (같은 밥·얼굴·팔다리, 유부만 밥 색이 유부)
	{
		id = "concept-unagi",
		displayName = "장어초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Uncommon", -- 뽑기 등급 (m5-31)
		speech = { "소스가 너무 미끄러웠어!", "지글지글 구운 장어~" },
		order = 37,
	},
	{
		id = "concept-uni",
		displayName = "성게 군함 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Rare", -- 뽑기 등급 (m5-31)
		speech = { "성게가 흘러내려…", "김 그릇 꽉 잡아!" },
		order = 38,
	},
	{
		id = "concept-tako",
		displayName = "문어초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Rare", -- 뽑기 등급 (m5-31)
		speech = { "빨판으로 붙어 볼걸…", "쫄깃쫄깃 문어 출동!" },
		order = 39,
	},
	{
		id = "concept-inari",
		displayName = "유부초밥 (특)",
		tier = "Basic",
		conceptBody = true,
		drawGrade = "Uncommon", -- 뽑기 등급 (m5-31)
		speech = { "주머니에서 밥이 샜어!", "달콤한 유부 속으로~" },
		order = 40,
	},
	-- m5-32 전설: 콘셉트 몸 위에 팔딱거리는 통고등어 (사용자 시트 docs/고등어 초밥 캐릭터 시트.png).
	-- 로벅스로 사도 되고 🎫 뽑기 전설(1%)로도 나와요 — 같은 보유(ownedSkins) 하나
	{
		id = "fresh-mackerel",
		displayName = "고등어 초밥 [신선]",
		tier = "Legendary",
		robux = 199,
		conceptBody = true,
		drawGrade = "Legendary", -- 뽑기 전설 (m5-32 2차 결정)
		speech = { "아직 팔딱팔딱 살아 있다고!", "오늘 아침에 잡힌 몸이야~" },
		order = 41,
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

-- 모두가 처음부터 가진 무료 스킨: 계란초밥만 (m5-31 — 콘셉트 몸 스킨은 이제 뽑기 전용)
function Skins.isFree(id: unknown): boolean
	return id == Skins.DEFAULT_ID
end

-- 🎫 뽑기 등급 (m5-31). 모르는 스킨·뽑기 아닌 스킨은 nil
function Skins.drawGradeOf(id: unknown): DrawGrade?
	local skin = Skins.get(id)
	local grade = if skin then skin.drawGrade else nil
	if grade ~= nil and Skins.DRAW_GRADE_INFO[grade] ~= nil then
		return grade
	end
	return nil
end

-- 🎫 뽑기에서 나오는 스킨인가 (m5-31)
function Skins.isDraw(id: unknown): boolean
	return Skins.drawGradeOf(id) ~= nil
end

-- 뽑기로만 얻는 스킨인가 (drawGrade가 있고 robux·coins·tokens·season·vipOnly가 없음 — 특 9종)
function Skins.isDrawOnly(id: unknown): boolean
	local skin = Skins.get(id)
	return skin ~= nil
		and Skins.isDraw(skin.id)
		and skin.robux == nil
		and skin.coins == nil
		and skin.tokens == nil
		and skin.season == nil
		and skin.vipOnly == nil
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
	-- 콘셉트 몸 외곽 기준 (m5-32): concept-salmon
	local conceptBounds = SushiBody.bounds(SushiBody.layout(SushiBody.CONCEPT_BOUNDS_BASE))
	local conceptExtents = {
		conceptBounds.max[1] - conceptBounds.min[1],
		conceptBounds.max[2] - conceptBounds.min[2],
		conceptBounds.max[3] - conceptBounds.min[3],
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
		local conceptBody = skin.conceptBody == true
		if skin.conceptBody ~= nil and skin.conceptBody ~= true then
			table.insert(problems, `{where}: conceptBody must be true or nil`)
		end
		if conceptBody and Skins.CONCEPT_BODY_IDS[skin.id] ~= true then
			table.insert(problems, `{where}: conceptBody only for Skins.CONCEPT_BODY_IDS`)
		end
		local grade = (skin :: any).drawGrade
		local draw = grade ~= nil
		if draw and Skins.DRAW_GRADE_INFO[grade] == nil then
			table.insert(problems, `{where}: unknown drawGrade {tostring(grade)}`)
		end
		if
			draw and (skin.season ~= nil or skin.tokens ~= nil or skin.vipOnly ~= nil or skin.id == Skins.DEFAULT_ID)
		then
			table.insert(problems, `{where}: drawGrade not for default, season, tokens or vipOnly skins`)
		end
		if draw ~= (Skins.DRAW_IDS[skin.id] == true) then
			table.insert(problems, `{where}: drawGrade and Skins.DRAW_IDS must match`)
		end
		if draw and skin.robux ~= nil and skin.robux ~= Skins.TIER_ROBUX[skin.tier] then
			table.insert(problems, `{where}: drawGrade + robux skin must use the tier robux price`)
		end
		if skin.id == Skins.DEFAULT_ID then
			hasDefault = true
			if skin.tier ~= "Basic" or skin.robux ~= nil or skin.coins ~= nil then
				table.insert(problems, `{where}: default skin must be Basic and free`)
			end
		elseif draw and skin.robux == nil then
			-- 🎫 뽑기로만 얻는 특 스킨 (m5-31): Basic 등급, 어떤 가격·시즌·VIP·상품 id도 없음
			if
				skin.tier ~= "Basic"
				or skin.robux ~= nil
				or skin.coins ~= nil
				or skin.tokens ~= nil
				or skin.vipOnly ~= nil
				or skin.season ~= nil
				or skin.productId ~= nil
			then
				table.insert(problems, `{where}: draw skin must be Basic with no other way to get it`)
			end
		else
			if skin.tier == "Basic" then
				table.insert(problems, `{where}: only the default skin and draw-only skins are Basic`)
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
				table.insert(problems, `{where}: needs a way to get it (robux, tokens, vipOnly or drawGrade)`)
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
			-- 콘셉트 몸 스킨은 자기 몸 모양이라 기준(계란초밥) 외곽 비교 대신 파츠 상한(SushiBody.CONCEPT_BODY)을 보고,
			-- boundsTolerance가 있으면(m5-32 고등어) concept-salmon 외곽보다 X·Z가 그 비율 넘게 크지 않은지 봐요
			local exception = if conceptBody then SushiBody.CONCEPT_BODY[skin.id] else nil
			if conceptBody and exception == nil then
				table.insert(problems, `{where}: concept body skin needs SushiBody.CONCEPT_BODY`)
			end
			if exception ~= nil and #layout > exception.partBudget then
				table.insert(problems, `{where}: parts {#layout} > concept body budget {exception.partBudget}`)
			end
			local conceptTolerance = if exception then exception.boundsTolerance else nil
			if conceptTolerance ~= nil then
				local bounds = SushiBody.bounds(layout)
				for _, axis in { 1, 3 } do
					local size = bounds.max[axis] - bounds.min[axis]
					local ratio = size / conceptExtents[axis]
					if ratio > 1 + conceptTolerance then
						table.insert(
							problems,
							`{where}: concept body bounds axis {axis} outside tolerance (ratio {ratio} vs {conceptTolerance})`
						)
					end
				end
			end
			local tolerance = if conceptBody then nil else SushiBody.BOUNDS_TOLERANCE[skin.tier]
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
