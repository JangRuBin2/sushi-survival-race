--!strict
-- 사용자 콘셉트 시트(2026-10-13)를 따른 연어초밥 캐릭터 견본 (m5-27).
-- 렌더 견본(layout/build)과, 무료 실험 스킨 "concept-salmon"용 게임 레이아웃(gameLayout)을 같이 가져요.
-- 게임에서는 SushiBody만 이 모듈을 불러요 (SushiBody.layout/build("concept-salmon") → gameLayout) — 다른 게임 코드는
-- 계속 SushiBody만 써요. 순환을 피하려고 이 모듈은 SushiBody를 require하지 않아요 (PartSpec은 같은 모양으로 따로 정의).
--   layout(expression?, pose?)  견본 파츠 목록 (순수 함수, SushiBody.PartSpec과 같은 모양 — lune 테스트·LayoutCheck 가능)
--   build(expression?, pose?)   견본 파츠를 만든 Model. PrimaryPart = Body(Anchored). 원점 = 밥 중심 → PivotTo로 옮겨요.
--   gameLayout(expression?)     게임 스킨용 (서기 자세): 발바닥을 SushiBody 기준(GAME_GROUND_OFFSET = 2.25)에 맞추려고 다리가
--                               0.25 내려가고 위끝은 밥 속까지 길어요. 다리 이름은 FootLeft/FootRight, 눈은 깜빡임 관절(EyeLeft/Right + 감은 눈 LidLeft/Right),
--                               팔(ArmLeft/Right)·발은 Motor6D(joint) — m5-25 CharacterFxController가 그대로 움직여요.
--                               앞 지방 줄 조각 3개는 빼서 파츠를 줄였어요 (기본 44).
--   EXPRESSIONS                 "Default"(기본) · "Happy"(신남 ^ ^) · "Flustered"(당황 o + 땀) · "Hurt"(아픔 x x + 반창고)
--   POSES                       "Stand"(서 있기) · "Run"(달리기: 팔 앞뒤, 한 발 앞)
--   GROUND_OFFSET               밥 중심에서 발바닥까지
-- 모양 (앞 = -Z, 위 = +Y, 메시 없이 Block·Ball·Cylinder만):
--   밥: 세로 모서리가 둥근 넓은 덩어리(Salt 재질 = 밥알 결) + 아래 한 단 좁은 받침
--   연어: 밥보다 넓은 "베개"(모든 모서리 둥근 판)가 앞·뒤·옆으로 늘어지고, 위에 둥근 등성이(캡슐)가 솟아 돔처럼.
--         밝은 지방 줄은 등성이·앞 늘어짐을 가로지르는 얇은 원판 조각
--   김 띠: 가운데를 앞에서 뒤로 — 앞 늘어짐 위에서 시작해 등성이를 넘어 등 아래까지 (뒤에서 가운데 세로 띠)
--   얼굴: 밥 앞면에 작은 타원 눈(원판 두 개를 겹친 캡슐) + 하이라이트, 작게 벌린 웃는 입(진한 입 + 분홍 혀), 분홍 볼
--   팔: 옆에 작은 네모 흰 손(벙어리장갑), 다리: 짧은 네모 흰 발 두 개. 팔·다리는 Motor6D(나중에 흔들 수 있게)

local ConceptMackerel = require(script.Parent.ConceptMackerel)

local SushiConceptSample = {}

export type Expression = "Default" | "Happy" | "Flustered" | "Hurt" | "Angry" | "Sad"
export type Pose = "Stand" | "Run"
type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
-- SushiBody.PartSpec과 같은 모양 (구조 타입이라 SushiBody가 그대로 받아요)
export type PartSpec = {
	name: string,
	size: { number },
	color: { number },
	material: string,
	offset: { number },
	shape: Shape?,
	rotation: { number }?,
	effect: ("Fire" | "Sparkles" | "Smoke" | "Glow")?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
	pivot: { number }?, -- 관절 경첩 (Body 좌표, m5-32 고등어)
	reach: { number }?, -- 물방울 관절이 splash 1일 때 옮겨 가는 거리 (m5-32)
}

-- m5-32 (사용자 결정 2026-10-14 3차): 화남·슬픔을 더해 6종. 앞 4종 레이아웃은 그대로예요
SushiConceptSample.EXPRESSIONS = { "Default", "Happy", "Flustered", "Hurt", "Angry", "Sad" } :: { Expression }
SushiConceptSample.POSES = { "Stand", "Run" } :: { Pose }
-- 이 몸을 쓰는 실험 스킨 (m5-27 연어 + m5-28 참치·새우·계란·연어알 군함 + m5-29 장어·성게 군함·문어·유부).
-- 밥·얼굴·팔다리는 같고 토핑만 달라요 (유부만 밥 색·재질을 바꿔요 — 스펙 "inari 예외")
local SALMON_ID = "concept-salmon"
SushiConceptSample.SKIN_IDS = {
	SALMON_ID,
	"concept-tuna",
	"concept-shrimp",
	"concept-tamago",
	"concept-ikura",
	"concept-unagi",
	"concept-uni",
	"concept-tako",
	"concept-inari",
	-- m5-32 전설 판매 스킨 (뽑기 전설에서도 나와요): 밥 위에 통고등어 한 마리
	"fresh-mackerel",
} :: { string }

---------------------------------------------------------------- 치수
local RICE_W, RICE_H, RICE_D, RICE_R = 3.6, 2.0, 2.7, 0.45 -- 밥 (y -1.0~1.0, 세로 모서리 반지름)
local FRONT = -RICE_D / 2 -- 밥 앞면 z (-1.35)
local BASE_H = 0.3 -- 아래 받침 (y -1.3~-1.0)
local LEG_W, LEG_H, LEG_D, LEG_X = 0.72, 1.0, 0.78, 0.8 -- 다리 (위끝은 받침 속)
local SOLE = -2.0 -- 발바닥 (견본)
local GAME_SOLE = -2.25 -- 발바닥 (게임 스킨: SushiBody.GROUND_OFFSET과 같게 다리를 늘려요)
local GAME_LEG_TOP = -0.8 -- 게임 스킨 다리 위끝 (밥·받침 속, 지방 줄 원판 아래끝 -0.75보다 아래 — 겹면 방지)

-- 만들기 선택 (견본 = 기본값, 게임 = gameLayout)
type Variant = { game: boolean }
local SAMPLE: Variant = { game = false }
local GAME: Variant = { game = true }

local TOP_W, TOP_D, TOP_T = 3.86, 2.9, 0.6 -- 연어 늘어진 가장자리 판: 폭·깊이·두께 (모서리 반지름 = 두께/2)
local TOP_Y = 0.85 -- 판 중심 (y 0.55~1.15 → 밥 위끝 1.0보다 0.45 아래까지 늘어져요)
-- 돔 = 큰 캡슐(축 X): 판 대부분을 덮고 솟아 앞뒤·좌우로 둥글게 내려와요. 판은 돔 아래로 0.17쯤 삐져나온
-- 늘어진 입술(가장자리)로만 보여요 — 모자 챙처럼 수평으로 튀어나오지 않게.
-- 아래쪽은 밥 속에 숨어요 (판 아래끝 높이에서 앞뒤 1.339 < 밥 1.35, 좌우 1.759 < 밥 1.8)
local RIDGE_D, RIDGE_HALF, RIDGE_Y = 2.7, 0.44, 0.62 -- 지름, 가운데 원기둥 반길이, 중심 (꼭대기 1.97)
local EDGE_Z = (TOP_D - TOP_T) / 2 -- 판 앞뒤 둥근 모서리 원기둥 z (±1.3)

---------------------------------------------------------------- 색
local RICE = { 250, 248, 242 }
local SALMON = { 255, 122, 64 }
local SALMON_FAT = { 255, 196, 160 }
local NORI = { 38, 46, 40 }
local INK = { 30, 22, 24 }
local WHITE = { 255, 255, 255 }
local MOUTH = { 110, 30, 40 }
local TONGUE = { 255, 120, 140 }
local CHEEK = { 255, 170, 180 }
local SWEAT = { 140, 210, 255 }
local BANDAGE = { 250, 214, 170 }
local BANDAGE_PAD = { 236, 180, 140 }
-- m5-28 콘셉트 스킨 토핑 색
local TUNA = { 186, 26, 48 } -- 진한 참치 빨강
local TUNA_MARBLE = { 238, 118, 132 } -- 밝은 결 (힘줄·지방)
local SHRIMP = { 255, 236, 222 } -- 익힌 새우 흰 바탕
local SHRIMP_BAND = { 250, 112, 52 } -- 주황 줄
local SHRIMP_TAIL = { 226, 52, 36 } -- 꼬리 부채
local SHRIMP_RIM = { 255, 178, 132 } -- 늘어진 가장자리 (익은 새우 옆면의 주황빛)
local EGG = { 255, 208, 64 } -- 계란말이
local EGG_LAYER = { 196, 120, 30 } -- 겹 사이 갈색 줄
local IKURA = { 255, 92, 28 } -- 연어알 (Glass)
local CUCUMBER = { 92, 170, 70 } -- 연어알 군함 오이 조각
local IKURA_BED = { 236, 96, 30 } -- 알 아래 깔린 주황 (김 그릇 윗면을 덮어요)
-- m5-29 콘셉트 스킨 2차 토핑 색
-- m5-29·m5-30 콘셉트 스킨 2차 토핑 색 (m5-30: 단색 덩어리 대신 결·두 톤·껍질로 진짜 음식처럼)
local UNAGI_GLAZE = { 92, 46, 18 } -- 타레 소스가 고인 등 (진한 갈색, Glass = 윤기)
local UNAGI_FLESH = { 182, 104, 46 } -- 구운 살 옆면 (호박빛 — 소스 아래로 보이는 가장자리)
local UNAGI_CHAR = { 58, 28, 12 } -- 석쇠 자국
local SESAME = { 244, 228, 186 } -- 흰 참깨
local UNI_DEEP = { 222, 100, 18 } -- 성게 진한 주황
local UNI = { 240, 128, 26 } -- 성게 주황
local UNI_LIGHT = { 250, 164, 48 } -- 성게 밝은 겨자빛
local UNI_BED = { 196, 84, 18 } -- 성게 사이 골 (그릇 바닥)
local SHISO = { 70, 150, 60 } -- 시소 잎
local SHISO_DARK = { 46, 112, 44 } -- 시소 잎맥
local TAKO = { 246, 238, 236 } -- 문어 흰 살
local TAKO_CUT = { 232, 214, 214 } -- 물결 썰기 결 (분홍빛 그림자)
local TAKO_SKIN = { 128, 30, 52 } -- 적갈·보라 껍질 (양 끝·가장자리)
local TAKO_SUCKER = { 240, 196, 204 } -- 빨판 (분홍빛 흰색)
local TAKO_SUCKER_IN = { 196, 120, 140 } -- 빨판 가운데 오목한 곳
local INARI_POUCH = { 214, 146, 62 } -- 유부 주머니 (공유 밥 파츠 색)
local INARI_RIM = { 192, 120, 46 } -- 주머니 입구 말린 테두리 (조금 진하게)
local INARI_CREASE = { 192, 126, 52 } -- 유부 주름
local SESAME_BLACK = { 40, 34, 30 } -- 검은 참깨

---------------------------------------------------------------- 도우미
type Extra = { shape: Shape?, rotation: { number }?, joint: boolean?, transparency: number?, attach: string? }

local function piece(
	name: string,
	size: { number },
	color: { number },
	offset: { number },
	material: string?,
	extra: Extra?
): PartSpec
	return {
		name = name,
		size = size,
		color = color,
		material = material or "SmoothPlastic",
		offset = offset,
		shape = extra and extra.shape,
		rotation = extra and extra.rotation,
		joint = extra and extra.joint,
		transparency = extra and extra.transparency,
		attach = extra and extra.attach,
	}
end

local UPRIGHT = { 0, 0, 90 } -- 원기둥 축 Y
local FACING = { 0, 90, 0 } -- 원기둥 축 Z (앞을 보는 원판)
local ALONG_Z = { 0, 90, 0 }

local function ball(name: string, d: number, color: { number }, offset: { number }, material: string?): PartSpec
	return piece(name, { d, d, d }, color, offset, material, { shape = "Ball" })
end

-- 앞을 보는 얇은 원판 (얼굴 장식). z는 앞면 위에 얹는 중심
local function faceDisc(name: string, d: number, color: { number }, x: number, y: number, z: number): PartSpec
	return piece(name, { 0.06, d, d }, color, { x, y, z }, nil, { shape = "Cylinder", rotation = FACING })
end

-- 세로 모서리가 둥근 덩어리 (위에서 보면 모서리 둥근 직사각형): 상자 2 + 세운 원기둥 4
local function roundedPrism(
	prefix: string,
	center: { number },
	w: number,
	h: number,
	d: number,
	r: number,
	color: { number },
	material: string?
): { PartSpec }
	local cx, cy, cz = center[1], center[2], center[3]
	local list = {
		piece(prefix, { w - 2 * r, h, d }, color, { cx, cy, cz }, material),
		piece(`{prefix}Wide`, { w, h, d - 2 * r }, color, { cx, cy, cz }, material),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			table.insert(
				list,
				piece(
					`{prefix}Corner{i}`,
					{ h, 2 * r, 2 * r },
					color,
					{ cx + sx * (w / 2 - r), cy, cz + sz * (d / 2 - r) },
					material,
					{ shape = "Cylinder", rotation = UPRIGHT }
				)
			)
		end
	end
	return list
end

-- 모든 모서리가 둥근 판 ("베개"): 가운데 상자 + 앞뒤 원기둥(축 X) + 옆 원기둥(축 Z) + 구석 공 4. 반지름 = 두께/2
local function pillow(
	prefix: string,
	center: { number },
	w: number,
	t: number,
	d: number,
	color: { number },
	material: string?
): { PartSpec }
	local cx, cy, cz = center[1], center[2], center[3]
	local ex, ez = (w - t) / 2, (d - t) / 2
	local list = {
		piece(prefix, { w - t, t, d - t }, color, { cx, cy, cz }, material),
		piece(`{prefix}Front`, { w - t, t, t }, color, { cx, cy, cz - ez }, material, { shape = "Cylinder" }),
		piece(`{prefix}Back`, { w - t, t, t }, color, { cx, cy, cz + ez }, material, { shape = "Cylinder" }),
		piece(`{prefix}Left`, { d - t, t, t }, color, { cx - ex, cy, cz }, material, {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
		piece(`{prefix}Right`, { d - t, t, t }, color, { cx + ex, cy, cz }, material, {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			table.insert(list, ball(`{prefix}Corner{i}`, t, color, { cx + sx * ex, cy, cz + sz * ez }, material))
		end
	end
	return list
end

local function join(...: { PartSpec }): { PartSpec }
	local list: { PartSpec } = {}
	for _, group in { ... } do
		for _, spec in group do
			table.insert(list, spec)
		end
	end
	return list
end

---------------------------------------------------------------- 몸 (표정·자세·토핑과 무관 — 모든 콘셉트 스킨이 같아요)
-- 공유 밥·받침 파츠의 색·재질만 스킨이 바꿀 수 있어요 (m5-29 유부 — 크기·위치는 그대로). 받침도 같이 바꿔요:
-- 밥과 받침이 0.01 겹쳐 옆면이 같은 평면이라 색이 다르면 z-fighting 검사에 걸리고, 다리가 흰색이라 발은 그대로 구분돼요
type RiceLook = { color: { number }, material: string }
local RICE_LOOK: { [string]: RiceLook } = {
	["concept-inari"] = { color = INARI_POUCH, material = "Sand" },
}

local function rice(skinId: string?): { PartSpec }
	local look = RICE_LOOK[skinId or SALMON_ID]
	local bodyColor = if look then look.color else RICE
	local bodyMaterial = if look then look.material else "Salt"
	return join(roundedPrism("Body", { 0, 0, 0 }, RICE_W, RICE_H, RICE_D, RICE_R, bodyColor, bodyMaterial), {
		-- 아래 한 단 좁은 받침: 바닥 모서리가 둥글어 보이게 (상자 두 개를 엇갈려 모서리를 깎아요)
		piece(
			"BodyBase",
			{ RICE_W - 0.9, BASE_H, RICE_D - 0.3 },
			bodyColor,
			{ 0, -1.0 - BASE_H / 2 + 0.01, 0 },
			bodyMaterial
		),
		piece(
			"BodyBaseWide",
			{ RICE_W - 0.3, BASE_H, RICE_D - 0.9 },
			bodyColor,
			{ 0, -1.0 - BASE_H / 2 + 0.01, 0 },
			bodyMaterial
		),
	})
end

---------------------------------------------------------------- 토핑: 늘어진 베개 + 돔 (연어·참치·새우가 같이 써요)
-- rimColor: 늘어진 가장자리(베개) 색 — 없으면 돔과 같아요 (새우는 가장자리가 주황빛)
local function dome(color: { number }, material: string?, rimColor: { number }?): { PartSpec }
	return join(pillow("Topping", { 0, TOP_Y, 0 }, TOP_W, TOP_T, TOP_D, rimColor or color, material), {
		piece(
			"Ridge",
			{ 2 * RIDGE_HALF, RIDGE_D, RIDGE_D },
			color,
			{ 0, RIDGE_Y, 0 },
			material,
			{ shape = "Cylinder" }
		),
		ball("RidgeLeft", RIDGE_D, color, { -RIDGE_HALF, RIDGE_Y, 0 }, material),
		ball("RidgeRight", RIDGE_D, color, { RIDGE_HALF, RIDGE_Y, 0 }, material),
	})
end

-- 돔을 앞뒤로 가로지르는 줄 하나 (돔과 같은 축의 얇은 원판 조각 — 표면을 따라 휘어 보여요).
-- 돔 끝(공 부분)에서는 그 자리 단면 지름에 맞춰요. lift = 돔 표면 위로 나오는 두께
local function domeBand(name: string, x: number, width: number, color: { number }, lift: number?): PartSpec
	local over = math.max(0, math.abs(x) - RIDGE_HALF)
	local r = RIDGE_D / 2
	local d = 2 * math.sqrt(r * r - over * over) + 2 * (lift or 0.02)
	return piece(name, { width, d, d }, color, { x, RIDGE_Y, 0 }, nil, { shape = "Cylinder" })
end

-- 지방 줄: 등성이와 앞 늘어짐을 가로지르는 얇은 원판 조각 (같은 축이라 표면을 따라 휘어 보여요)
local STRIPE_X = { -0.95, 0.5, 1.12 }
local function stripes(variant: Variant): { PartSpec }
	local list: { PartSpec } = {}
	for i, x in STRIPE_X do
		table.insert(list, domeBand(`Stripe{i}`, x, 0.12, SALMON_FAT))
		if variant.game then
			continue -- 게임 스킨은 파츠를 줄여요 (앞 늘어짐의 줄 조각은 작고 뒤 카메라에서 안 보여요)
		end
		table.insert(
			list,
			piece(`StripeFront{i}`, { 0.12, TOP_T + 0.04, TOP_T + 0.04 }, SALMON_FAT, { x, TOP_Y, -EDGE_Z }, nil, {
				shape = "Cylinder",
			})
		)
	end
	return list
end

-- 김 띠 (가운데, 앞 늘어짐 → 등성이 → 뒤 늘어짐 → 등 아래)
local NORI_W = 0.7
local function nori(): { PartSpec }
	return {
		piece("NoriRidge", { NORI_W, RIDGE_D + 0.06, RIDGE_D + 0.06 }, NORI, { 0, RIDGE_Y, 0 }, "Fabric", {
			shape = "Cylinder",
		}),
		piece("NoriFront", { NORI_W, TOP_T + 0.06, TOP_T + 0.06 }, NORI, { 0, TOP_Y, -EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece("NoriBack", { NORI_W, TOP_T + 0.06, TOP_T + 0.06 }, NORI, { 0, TOP_Y, EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece(
			"NoriBackStrip",
			{ NORI_W, TOP_Y - 0.1 + 0.97, 0.06 },
			NORI,
			{ 0, (TOP_Y - 0.1 - 0.97) / 2, RICE_D / 2 + 0.02 },
			"Fabric"
		),
	}
end

---------------------------------------------------------------- 스킨별 토핑 (m5-28) — 밥·얼굴·팔다리·깜빡임 관절은 모두 같아요
-- 토핑은 얼굴(밥 앞면 y 0.8 아래)을 가리지 않고, 발바닥·관절 이름은 건드리지 않아요. 상한: 가장 많은 표정(당황 27) + 토핑 ≤ 47 → 토핑 ≤ 20.

-- 연어 (m5-27 그대로): 돔 + 지방 줄 + 가운데 김 띠
local function salmonTopping(variant: Variant): { PartSpec }
	return join(dome(SALMON), stripes(variant), nori())
end

-- 참치: 진한 빨강 돔 + 가늘고 간격이 고르지 않은 밝은 결 4줄 (김 띠 없음 — 뒤에서 연어와 바로 구분)
local TUNA_MARBLE_X = { -1.1, -0.38, 0.32, 1.02 }
local TUNA_MARBLE_W = { 0.17, 0.24, 0.14, 0.2 }
local function tunaTopping(_variant: Variant): { PartSpec }
	local list = dome(TUNA)
	for i, x in TUNA_MARBLE_X do
		table.insert(list, domeBand(`Marble{i}`, x, TUNA_MARBLE_W[i], TUNA_MARBLE))
	end
	return list
end

-- 새우: 흰 돔 + 굵은 주황 줄 4개 + 주황빛 가장자리 + 뒤로 솟은 빨간 꼬리 부채 3장 (뒤 카메라 실루엣)
local SHRIMP_BAND_X = { -1.12, -0.38, 0.38, 1.12 }
local function shrimpTopping(_variant: Variant): { PartSpec }
	local list = dome(SHRIMP, nil, SHRIMP_RIM)
	for i, x in SHRIMP_BAND_X do
		table.insert(list, domeBand(`Band{i}`, x, 0.3, SHRIMP_BAND))
	end
	-- 꼬리 부채: 돔 뒤 꼭대기에서 위·뒤로 펼쳐져요 (가운데 + 양옆으로 기울인 쐐기)
	for _, fan in { { "TailLeft", -1 }, { "TailMid", 0 }, { "TailRight", 1 } } do
		local side = fan[2] :: number
		table.insert(
			list,
			piece(fan[1] :: string, { 0.22, 1.15, 0.78 }, SHRIMP_TAIL, { side * 0.34, 2.0, 1.22 }, nil, {
				shape = "Wedge",
				rotation = { -25, 180, side * 28 },
			})
		)
	end
	return list
end

-- 계란초밥: 모서리가 모두 둥근 두툼한 노란 계란말이 (폭신한 베개) + 앞·뒤 겹 줄 + 가운데 김 띠 (위 → 앞 / 위 → 등 아래)
local EGG_W, EGG_T, EGG_D = 3.96, 1.1, 2.98 -- 폭·두께·깊이 (모서리 반지름 = 두께/2)
local EGG_Y = 1.38 -- 중심 (y 0.83~1.93, 밥 위끝 1.0 아래로 0.17 늘어져요 — 꼭대기가 연어 돔(1.97)과 비슷)
local EGG_TOP = EGG_Y + EGG_T / 2
local EGG_EDGE_Z = (EGG_D - EGG_T) / 2 -- 앞뒤 둥근 모서리 원기둥 z
local function tamagoTopping(_variant: Variant): { PartSpec }
	local band = NORI_W
	return join(pillow("Topping", { 0, EGG_Y, 0 }, EGG_W, EGG_T, EGG_D, EGG), {
		-- 겹 줄: 앞·뒤 둥근 모서리의 가장 튀어나온 곳에 얇은 선 (김 띠가 가운데를 덮어요)
		piece(
			"LayerFront",
			{ EGG_W - EGG_T - 0.06, 0.1, 0.04 },
			EGG_LAYER,
			{ 0, EGG_Y - 0.08, -EGG_EDGE_Z - EGG_T / 2 + 0.01 }
		),
		piece(
			"LayerBack",
			{ EGG_W - EGG_T - 0.06, 0.1, 0.04 },
			EGG_LAYER,
			{ 0, EGG_Y - 0.08, EGG_EDGE_Z + EGG_T / 2 - 0.01 }
		),
		-- 김 띠: 평평한 윗면 + 앞뒤 둥근 모서리를 감싸는 같은 축 원기둥 조각 + 등 아래
		piece("NoriTop", { band, 0.06, EGG_D - EGG_T + 0.04 }, NORI, { 0, EGG_TOP + 0.02, 0 }, "Fabric"),
		piece("NoriFront", { band, EGG_T + 0.06, EGG_T + 0.06 }, NORI, { 0, EGG_Y, -EGG_EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece("NoriBack", { band, EGG_T + 0.06, EGG_T + 0.06 }, NORI, { 0, EGG_Y, EGG_EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece(
			"NoriBackStrip",
			{ band, EGG_Y - 0.1 + 0.97, 0.06 },
			NORI,
			{ 0, (EGG_Y - 0.1 - 0.97) / 2, RICE_D / 2 + 0.02 },
			"Fabric"
		),
	})
end

-- 연어알 군함: 김 벽이 등·옆을 감싸고(앞은 밥 속으로 숨어 얼굴이 보여요) 밥보다 높이 솟아 그릇이 되고,
-- 위에 주황 바닥 + 큰 연어알 몇 알 (파츠를 아끼려고 알을 크게)
local WALL_W, WALL_D, WALL_R, WALL_Z = 3.72, 2.62, 0.5, 0.12 -- 앞 -1.19 (밥 앞면 -1.35 뒤), 뒤 1.43
local WALL_BOTTOM, WALL_TOP = -0.94, 1.4
local ROE_D = 0.68
local ROE = {
	{ -1.15, -0.45 },
	{ -0.4, -0.55 },
	{ 0.4, -0.5 },
	{ 1.15, -0.4 },
	{ -1.05, 0.6 },
	{ -0.3, 0.55 },
	{ 0.45, 0.65 },
	{ 1.15, 0.6 },
}
local ROE_TOP = { { -0.75, 0.05 }, { 0.05, 0.0 }, { 0.8, 0.1 } } -- 두 번째 층 (가운데가 볼록)
local function ikuraTopping(_variant: Variant): { PartSpec }
	local list = roundedPrism(
		"Wall",
		{ 0, (WALL_BOTTOM + WALL_TOP) / 2, WALL_Z },
		WALL_W,
		WALL_TOP - WALL_BOTTOM,
		WALL_D,
		WALL_R,
		NORI,
		"Fabric"
	)
	local bedTop = WALL_TOP + 0.08
	table.insert(list, piece("RoeBed", { WALL_W - 0.36, 0.2, WALL_D - 0.36 }, IKURA_BED, { 0, bedTop - 0.1, WALL_Z }))
	for i, p in ROE do
		table.insert(list, ball(`Roe{i}`, ROE_D, IKURA, { p[1], bedTop + 0.12, WALL_Z + p[2] }, "Glass"))
	end
	for i, p in ROE_TOP do
		table.insert(list, ball(`RoeTop{i}`, ROE_D, IKURA, { p[1], bedTop + 0.5, WALL_Z + p[2] }, "Glass"))
	end
	-- 오이 한 조각: 뒤 왼쪽 구석에 비스듬히 꽂혀 초록 포인트 (뒤 카메라에서도 보여요)
	table.insert(
		list,
		piece("Cucumber", { 0.12, 0.62, 0.62 }, CUCUMBER, { -1.35, bedTop + 0.3, WALL_Z + 0.85 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 35, 60 },
		})
	)
	return list
end

---------------------------------------------------------------- m5-29 토핑 (장어·성게 군함·문어·유부) — m5-30 퀄리티 패스
-- 장어·성게는 사용자 캐릭터 시트(docs/귀여운 우니와 장어 초밥 캐릭터 시트.png)를 따라요: 둘 다 몸 위쪽을 김 띠가
-- 한 바퀴 두르고(당황 눈썹 위 y 0.46부터 — 얼굴·팔은 띠 아래), 그 위에 토핑. m5-30(파츠 상한 70)에서 단색 덩어리 대신
-- 결·두 톤·껍질을 넣었어요. 비평은 docs/developer/m5-29-concept-skins-2.md, docs/developer/m5-30-concept-topping-quality.md

-- 몸 위쪽을 두르는 김 띠 (앞·옆·뒤 모두 밥 바깥으로 0.08). 아래끝 0.46 = 당황 눈썹 위끝(0.4)보다 위 (m5-29 QA B1)
local BAND_W, BAND_D, BAND_R = 3.72, 2.86, 0.5
local BAND_BOTTOM = 0.46
local function band(top: number): { PartSpec }
	return roundedPrism(
		"Band",
		{ 0, (BAND_BOTTOM + top) / 2, 0 },
		BAND_W,
		top - BAND_BOTTOM,
		BAND_D,
		BAND_R,
		NORI,
		"Fabric"
	)
end

-- 장어: 김 띠 위에 넓적하게 늘어진 구운 장어 살(호박빛 옆면) + 그 위에 한 겹 작은 진한 타레 소스 층(Glass 윤기 —
-- 가장자리에 구운 살이 테두리로 보여요) + 소스 위 석쇠 자국 마디 + 흰 참깨 + 가운데 세로 김 띠(판 모서리를 따라 휘어요)
-- 등 쪽 세로 김은 띠 아래에서 밥 등면에 붙어요 (m5-29 QA B2: 떠 있던 판)
local EEL_W, EEL_T, EEL_D = 3.96, 0.62, 3.0
local EEL_Y = 1.0 + EEL_T / 2 - 0.05 -- 판 중심 (아래끝 0.95 — 띠 위끝 1.02 속)
local EEL_EDGE_Z = (EEL_D - EEL_T) / 2 -- 판 앞뒤 둥근 모서리 원기둥 z
local GLAZE_T = 0.26 -- 소스 층 두께
local GLAZE_Y = EEL_Y + EEL_T / 2 + GLAZE_T / 2 - 0.1 -- 판 윗면에 0.1 묻혀요
local GLAZE_TOP = GLAZE_Y + GLAZE_T / 2
local GRILL_X = { -1.3, -0.78, 0.78, 1.3 }
local SESAME_AT = { { -1.05, -0.5 }, { -0.55, 0.45 }, { 0.6, -0.35 }, { 1.1, 0.4 }, { -1.45, 0.15 }, { 1.5, -0.6 } }
local function unagiTopping(_variant: Variant): { PartSpec }
	local wrap = EEL_T + 0.08
	local face = EEL_D / 2 + 0.04 -- 판 앞뒤 끝(1.5)보다 바깥
	local list = join(
		band(1.02),
		pillow("Eel", { 0, EEL_Y, 0 }, EEL_W, EEL_T, EEL_D, UNAGI_FLESH, "SmoothPlastic"),
		pillow("Glaze", { 0, GLAZE_Y, 0 }, EEL_W - 0.4, GLAZE_T, EEL_D - 0.4, UNAGI_GLAZE, "Glass")
	)
	for i, x in GRILL_X do
		table.insert(list, piece(`Grill{i}`, { 0.1, 0.04, EEL_D - 0.9 }, UNAGI_CHAR, { x, GLAZE_TOP + 0.01, 0 }))
	end
	for i, p in SESAME_AT do
		table.insert(list, ball(`Sesame{i}`, 0.15, SESAME, { p[1], GLAZE_TOP + 0.03, p[2] }))
	end
	local noriTop = GLAZE_TOP + 0.04
	return join(list, {
		piece("NoriTop", { NORI_W, 0.08, 2 * EEL_EDGE_Z + 0.1 }, NORI, { 0, noriTop - 0.04, 0 }, "Fabric"),
		piece(
			"NoriFrontEdge",
			{ NORI_W, wrap, wrap },
			NORI,
			{ 0, EEL_Y, -EEL_EDGE_Z },
			"Fabric",
			{ shape = "Cylinder" }
		),
		piece("NoriBackEdge", { NORI_W, wrap, wrap }, NORI, { 0, EEL_Y, EEL_EDGE_Z }, "Fabric", { shape = "Cylinder" }),
		piece(
			"NoriFront",
			{ NORI_W, EEL_Y - BAND_BOTTOM, 0.1 },
			NORI,
			{ 0, (EEL_Y + BAND_BOTTOM) / 2, -face },
			"Fabric"
		),
		-- 판 끝 바깥(1.54)에서 띠 바깥(1.43) 쪽으로 내려오다가 띠 아래에서는 밥 등면(1.35)에 붙어요
		piece("NoriBack", { NORI_W, EEL_Y - BAND_BOTTOM, 0.1 }, NORI, { 0, (EEL_Y + BAND_BOTTOM) / 2, face }, "Fabric"),
		piece(
			"NoriBackLow",
			{ NORI_W, BAND_BOTTOM + 0.97, 0.06 },
			NORI,
			{ 0, (BAND_BOTTOM - 0.97) / 2, RICE_D / 2 + 0.02 },
			"Fabric"
		),
	})
end

-- 성게 군함: 몸 위쪽 김 띠가 밥보다 높이 솟아 그릇이 되고(연어알 군함과 달리 등·옆 아래는 밥이 보여요), 위에
-- 작은 혀 모양 조각 10개가 두 줄 + 가운데 위 두 개로 겹겹이 쌓여요(앞줄은 앞으로 흘러내리고 뒷줄은 뒤로 기대요).
-- 진한 주황·주황·밝은 겨자빛이 섞이고 사이 골은 진한 바닥이 보여요. 맨 위 시소 잎. 둥근 알·오이는 없어요
local UNI_CUP_TOP = 1.45
type Tongue = { x: number, z: number, lift: number, yaw: number, pitch: number, color: { number } }
local TONGUES: { Tongue } = {
	{ x = -1.24, z = -0.6, lift = 0.0, yaw = 8, pitch = -14, color = UNI },
	{ x = -0.41, z = -0.64, lift = 0.06, yaw = -5, pitch = -12, color = UNI_LIGHT },
	{ x = 0.42, z = -0.62, lift = 0.04, yaw = 6, pitch = -15, color = UNI_DEEP },
	{ x = 1.24, z = -0.58, lift = 0.0, yaw = -8, pitch = -12, color = UNI },
	{ x = -1.22, z = 0.56, lift = 0.0, yaw = -6, pitch = 12, color = UNI_DEEP },
	{ x = -0.4, z = 0.6, lift = 0.08, yaw = 4, pitch = 10, color = UNI },
	{ x = 0.43, z = 0.58, lift = 0.06, yaw = -7, pitch = 13, color = UNI_LIGHT },
	{ x = 1.23, z = 0.55, lift = 0.0, yaw = 7, pitch = 11, color = UNI },
	{ x = -0.42, z = 0.0, lift = 0.36, yaw = 10, pitch = 0, color = UNI_LIGHT },
	{ x = 0.42, z = 0.02, lift = 0.36, yaw = -10, pitch = 0, color = UNI },
}
local TONGUE_D, TONGUE_LEN = 0.74, 0.55 -- 굵기, 가운데 원기둥 길이 (끝 공까지 1.29)
local function uniTopping(_variant: Variant): { PartSpec }
	local list = band(UNI_CUP_TOP)
	table.insert(list, piece("UniBed", { BAND_W - 0.3, 0.12, BAND_D - 0.3 }, UNI_BED, { 0, UNI_CUP_TOP + 0.05, 0 }))
	local y0 = UNI_CUP_TOP + 0.22
	local top = 0
	for i, tongue in TONGUES do
		local y = y0 + tongue.lift
		-- 축 X 원기둥을 CFrame.Angles(pitch, 90 + yaw, 0)로 돌리면 축 방향 = (-sin yaw, sin pitch cos yaw, -cos pitch cos yaw)
		local yaw, pitch = math.rad(tongue.yaw), math.rad(tongue.pitch)
		local dx, dy, dz = -math.sin(yaw), math.sin(pitch) * math.cos(yaw), -math.cos(pitch) * math.cos(yaw)
		local h = TONGUE_LEN / 2
		top = math.max(top, y + math.abs(dy) * h + TONGUE_D / 2)
		table.insert(
			list,
			piece(`Lobe{i}`, { TONGUE_LEN, TONGUE_D, TONGUE_D }, tongue.color, { tongue.x, y, tongue.z }, nil, {
				shape = "Cylinder",
				rotation = { tongue.pitch, 90 + tongue.yaw, 0 },
			})
		)
		table.insert(
			list,
			ball(`Lobe{i}Front`, TONGUE_D, tongue.color, { tongue.x + dx * h, y + dy * h, tongue.z + dz * h })
		)
		table.insert(
			list,
			ball(`Lobe{i}Back`, TONGUE_D, tongue.color, { tongue.x - dx * h, y - dy * h, tongue.z - dz * h })
		)
	end
	-- 맨 위 시소 잎 (가운데 두 조각 사이 골에 꽂혀 벌어져요) + 잎맥
	for i, sx in { -1, 1 } do
		table.insert(
			list,
			piece(`Leaf{i}`, { 0.66, 0.08, 0.36 }, SHISO, { sx * 0.24, top - 0.02, 0.05 }, nil, {
				rotation = { 0, sx * 20, sx * 38 },
			})
		)
	end
	table.insert(
		list,
		piece("LeafMid", { 0.08, 0.5, 0.3 }, SHISO_DARK, { 0, top + 0.06, 0.05 }, nil, { rotation = { 12, 0, 0 } })
	)
	return list
end

-- 문어: 흰 살 돔 + 적갈·보라 껍질(늘어진 가장자리와 돔 양 끝 — 끝에서 솟는 공이 껍질), 껍질 위 분홍빛 빨판(가운데
-- 오목한 점까지), 흰 살에 물결 썰기 결, 가운데 김 띠
local SKIN_X, SKIN_D = 1.2, 1.6 -- 껍질 공 중심(돔 끝 공 0.44보다 바깥)·지름 → 돔 양 끝 윗부분에서 솟아요
local SKIN_Y = RIDGE_Y + 0.4 -- 위로 올려 몸 옆으로 혹처럼 삐져나오지 않게
type Sucker = { side: number, dir: { number } }
local SUCKERS: { Sucker } = {
	{ side = 1, dir = { 0.6, 0.75, 0.3 } },
	{ side = 1, dir = { 0.75, 0.55, -0.35 } },
	{ side = 1, dir = { 0.9, 0.35, 0.25 } },
	{ side = -1, dir = { -0.6, 0.75, -0.3 } },
	{ side = -1, dir = { -0.75, 0.55, 0.35 } },
	{ side = -1, dir = { -0.9, 0.35, -0.25 } },
}
local CUT_X = { -1.05, -0.62, 0.62, 1.05 }
local function sucker(name: string, d: number, color: { number }, at: { number }, n: { number }): PartSpec
	-- 원기둥 축(X)을 법선으로: CFrame.Angles(a, 0, phi) * X = (cos phi, sin phi cos a, sin phi sin a)
	local phi = math.deg(math.acos(n[1]))
	local a = math.deg(math.atan2(n[3], n[2]))
	return piece(name, { 0.06, d, d }, color, at, nil, { shape = "Cylinder", rotation = { a, 0, phi } })
end
local function takoTopping(_variant: Variant): { PartSpec }
	local list = dome(TAKO, nil, TAKO_SKIN)
	for i, x in CUT_X do
		table.insert(list, domeBand(`Cut{i}`, x, 0.08, TAKO_CUT, 0.015))
	end
	table.insert(list, ball("SkinLeft", SKIN_D, TAKO_SKIN, { -SKIN_X, SKIN_Y, 0 }))
	table.insert(list, ball("SkinRight", SKIN_D, TAKO_SKIN, { SKIN_X, SKIN_Y, 0 }))
	local r = SKIN_D / 2
	for i, s in SUCKERS do
		local d = s.dir
		local len = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
		local n = { d[1] / len, d[2] / len, d[3] / len }
		local cx = s.side * SKIN_X
		local inner = r + 0.03
		table.insert(list, sucker(`Sucker{i}`, 0.32, TAKO_SUCKER, { cx + n[1] * r, SKIN_Y + n[2] * r, n[3] * r }, n))
		table.insert(
			list,
			sucker(`Sucker{i}In`, 0.14, TAKO_SUCKER_IN, { cx + n[1] * inner, SKIN_Y + n[2] * inner, n[3] * inner }, n)
		)
	end
	return join(list, nori())
end

-- 유부: 공유 밥·받침 파츠가 유부 색(RICE_LOOK, 재질 Sand = 튀긴 두부 결) — 몸 전체가 주머니. 위에 말린 입구 테두리
-- (앞뒤·옆 원기둥 + 구석 공), 입구 안에 흰 밥과 밥알·참깨, 옆·등에 주머니 주름. 테두리 앞은 밥 앞면보다 0.02 안쪽
-- (얼굴 높이보다 위), 주름은 옆·등에만 있어 얼굴을 안 가려요
local LIP_T = 0.4 -- 테두리 굵기
local LIP_Y = RICE_H / 2 + 0.04 -- 테두리 중심 (꼭대기 1.24)
local LIP_X = RICE_W / 2 - RICE_R -- 앞뒤 테두리 반길이 (1.35)
local LIP_Z = RICE_D / 2 - RICE_R -- 옆 테두리 반길이 (0.9)
type Grain = { x: number, z: number, d: number }
local GRAINS: { Grain } = {
	{ x = -0.85, z = -0.3, d = 0.4 },
	{ x = -0.3, z = -0.45, d = 0.34 },
	{ x = 0.3, z = -0.35, d = 0.38 },
	{ x = 0.9, z = -0.2, d = 0.34 },
	{ x = -0.6, z = 0.3, d = 0.36 },
	{ x = 0.0, z = 0.1, d = 0.42 },
	{ x = 0.6, z = 0.35, d = 0.36 },
	{ x = 1.05, z = 0.4, d = 0.3 },
}
type Seed = { x: number, z: number, color: { number } }
local SEEDS: { Seed } = {
	{ x = -0.5, z = -0.1, color = SESAME_BLACK },
	{ x = 0.42, z = 0.05, color = SESAME_BLACK },
	{ x = -0.05, z = 0.5, color = SESAME_BLACK },
	{ x = 0.8, z = -0.5, color = SESAME },
}
-- 주름: 면("Back" = 등, "Left"/"Right" = 옆), 가로 위치, 기울기(도), 길이
type Crease = { face: string, at: number, tilt: number, length: number }
local CREASES: { Crease } = {
	{ face = "Back", at = -0.85, tilt = 8, length = 1.2 },
	{ face = "Back", at = 0.05, tilt = -6, length = 1.0 },
	{ face = "Back", at = 0.9, tilt = 10, length = 1.15 },
	{ face = "Left", at = -0.45, tilt = -9, length = 1.0 },
	{ face = "Left", at = 0.4, tilt = 7, length = 1.1 },
	{ face = "Right", at = -0.4, tilt = 8, length = 1.05 },
	{ face = "Right", at = 0.45, tilt = -8, length = 1.0 },
}
local function inariTopping(_variant: Variant): { PartSpec }
	local lipZ = RICE_D / 2 - LIP_T / 2 - 0.02
	local lipX = RICE_W / 2 - LIP_T / 2 - 0.02
	local corner = (RICE_R - LIP_T / 2 - 0.02) / math.sqrt(2)
	local list: { PartSpec } = {
		piece("LipFront", { 2 * LIP_X + 0.1, LIP_T, LIP_T }, INARI_RIM, { 0, LIP_Y, -lipZ }, "Sand", {
			shape = "Cylinder",
		}),
		piece("LipBack", { 2 * LIP_X + 0.1, LIP_T, LIP_T }, INARI_RIM, { 0, LIP_Y, lipZ }, "Sand", {
			shape = "Cylinder",
		}),
		piece("LipLeft", { 2 * LIP_Z + 0.1, LIP_T, LIP_T }, INARI_RIM, { -lipX, LIP_Y, 0 }, "Sand", {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
		piece("LipRight", { 2 * LIP_Z + 0.1, LIP_T, LIP_T }, INARI_RIM, { lipX, LIP_Y, 0 }, "Sand", {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			table.insert(
				list,
				ball(`LipCorner{i}`, LIP_T, INARI_RIM, { sx * (LIP_X + corner), LIP_Y, sz * (LIP_Z + corner) }, "Sand")
			)
		end
	end
	-- 입구 안 흰 밥 + 밥알 덩어리 + 참깨
	local riceTop = RICE_H / 2 + 0.18
	table.insert(list, piece("InariRice", { 2.9, 0.2, 2.0 }, RICE, { 0, RICE_H / 2 + 0.08, 0 }, "Salt"))
	for k, g in GRAINS do
		table.insert(list, ball(`InariGrain{k}`, g.d, RICE, { g.x, riceTop - 0.04 + g.d * 0.2, g.z }, "Salt"))
	end
	for k, s in SEEDS do
		-- 흰 밥 판 윗면(1.18)에 반쯤 묻혀요
		table.insert(list, ball(`InariSeed{k}`, 0.12, s.color, { s.x, RICE_H / 2 + 0.2, s.z }))
	end
	-- 주머니 주름 (밥 평평한 옆면·등면에 반쯤 묻힌 얇은 띠)
	for k, c in CREASES do
		if c.face == "Back" then
			table.insert(
				list,
				piece(
					`InariCrease{k}`,
					{ 0.12, c.length, 0.04 },
					INARI_CREASE,
					{ c.at, 0.15, RICE_D / 2 + 0.01 },
					"Sand",
					{
						rotation = { 0, 0, c.tilt },
					}
				)
			)
		else
			local sx = if c.face == "Left" then -1 else 1
			table.insert(
				list,
				piece(
					`InariCrease{k}`,
					{ 0.04, c.length, 0.12 },
					INARI_CREASE,
					{ sx * (RICE_W / 2 + 0.01), 0.15, c.at },
					"Sand",
					{ rotation = { c.tilt, 0, 0 } }
				)
			)
		end
	end
	return list
end

local TOPPINGS: { [string]: (Variant) -> { PartSpec } } = {
	["concept-salmon"] = salmonTopping,
	["concept-tuna"] = tunaTopping,
	["concept-shrimp"] = shrimpTopping,
	["concept-tamago"] = tamagoTopping,
	["concept-ikura"] = ikuraTopping,
	["concept-unagi"] = unagiTopping,
	["concept-uni"] = uniTopping,
	["concept-tako"] = takoTopping,
	["concept-inari"] = inariTopping,
	["fresh-mackerel"] = function(_variant: Variant): { PartSpec }
		return ConceptMackerel.topping()
	end,
}

---------------------------------------------------------------- 얼굴
local EYE_X, EYE_Y = 0.52, -0.12
local EYE_D, EYE_STRETCH = 0.4, 0.07 -- 원판 지름, 위아래로 벌린 거리 (타원 = 0.4 × 0.54)
local MOUTH_Y = -0.42
local CHEEK_X, CHEEK_Y = 0.98, -0.42
local FACE_Z = FRONT - 0.03 -- 얼굴 원판 중심 (두께 0.06, 밥 앞면에 반쯤 묻혀요)

-- 감은 눈 선을 밥 속에 숨겨 두는 깊이 (CharacterAnimLogic.LID_SHOW만큼 앞으로 나오면 얼굴 면)
local LID_HIDE = 0.3

local function openEyes(variant: Variant): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		local eye = faceDisc(`Eye{name}`, EYE_D, INK, x, EYE_Y + EYE_STRETCH, FACE_Z)
		local low = faceDisc(`EyeLow{name}`, EYE_D, INK, x, EYE_Y - EYE_STRETCH, FACE_Z)
		-- 하이라이트: 두 눈 모두 왼쪽 위
		local shine = ball(`Shine{name}`, 0.14, WHITE, { x - 0.07, EYE_Y + 0.15, FACE_Z - 0.03 }, "Neon")
		if variant.game then
			-- 깜빡임 (m5-25): 위 원판이 관절, 아래 원판·하이라이트는 위 원판에 붙어 같이 밥 속으로 들어가요
			eye.joint = true
			low.attach = eye.name
			shine.attach = eye.name
		end
		table.insert(list, eye)
		table.insert(list, low)
		table.insert(list, shine)
		if variant.game then
			-- 감은 눈 선: 평소엔 밥 속, 깜빡일 때 앞으로 나와요
			table.insert(
				list,
				piece(`Lid{name}`, { 0.42, 0.09, 0.06 }, INK, { x, EYE_Y, FACE_Z + LID_HIDE }, nil, { joint = true })
			)
		end
	end
	return list
end

-- 가느다란 막대 (표정 선: ^ ^, x x, 눈썹). angle = 앞에서 본 기울기(도)
local function stroke(name: string, length: number, x: number, y: number, angle: number, color: { number }?): PartSpec
	return piece(name, { length, 0.09, 0.06 }, color or INK, { x, y, FACE_Z }, nil, { rotation = { 0, 0, angle } })
end

local function happyEyes(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		table.insert(list, stroke(`Eye{name}`, 0.3, x - 0.1, EYE_Y + 0.02, 40))
		table.insert(list, stroke(`EyeLow{name}`, 0.3, x + 0.1, EYE_Y + 0.02, -40))
	end
	return list
end

local function crossEyes(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		table.insert(list, stroke(`Eye{name}`, 0.42, x, EYE_Y, 45))
		table.insert(list, stroke(`EyeLow{name}`, 0.42, x, EYE_Y, -45))
	end
	return list
end

-- 작게 벌린 웃는 입: 진한 원판 위 반을 밥 색 판이 덮고, 아래에 분홍 혀
local function smile(size: number): { PartSpec }
	return {
		-- 입 원판은 밥에 거의 묻고(앞으로 0.03), 얇은 덮개가 윗변보다 0.04 위까지 덮어요 → 위에서 봐도
		-- 원판 윗변이 안 비치고, 덮개 옆면(두께 0.03)도 선으로 안 보여요
		piece("Mouth", { 0.04, size, size }, MOUTH, { 0, MOUTH_Y, FRONT - 0.01 }, nil, {
			shape = "Cylinder",
			rotation = FACING,
		}),
		piece(
			"MouthCover",
			{ size + 0.08, size / 2 + 0.04, 0.03 },
			RICE,
			{ 0, MOUTH_Y + size / 4 + 0.02, FRONT - 0.045 },
			"Salt"
		),
		piece("Tongue", { 0.03, size * 0.5, size * 0.5 }, TONGUE, { 0, MOUTH_Y - size * 0.2, FRONT - 0.035 }, nil, {
			shape = "Cylinder",
			rotation = FACING,
		}),
	}
end

local function cheeks(): { PartSpec }
	return {
		faceDisc("CheekLeft", 0.34, CHEEK, -CHEEK_X, CHEEK_Y, FACE_Z),
		faceDisc("CheekRight", 0.34, CHEEK, CHEEK_X, CHEEK_Y, FACE_Z),
	}
end

-- 화남 💢 (m5-32): 앞에서 봐서 오른쪽(캐릭터의 -X) 이마, 눈썹 높이. 네 획이 마름모를 그려요 {dx, dy, 기울기}
local ANGER = { 230, 60, 60 }
local ANGER_X, ANGER_Y = -1.18, 0.24
local ANGER_MARK = { { -0.07, 0.07, 45 }, { 0.07, 0.07, -45 }, { -0.07, -0.07, -45 }, { 0.07, -0.07, 45 } }

local function face(expression: Expression, variant: Variant): { PartSpec }
	if expression == "Happy" then
		return join(happyEyes(), smile(0.5), cheeks())
	elseif expression == "Flustered" then
		return join(openEyes(variant), cheeks(), {
			faceDisc("Mouth", 0.24, MOUTH, 0, MOUTH_Y - 0.02, FACE_Z),
			stroke("BrowLeft", 0.3, -EYE_X, EYE_Y + 0.45, 15),
			stroke("BrowRight", 0.3, EYE_X, EYE_Y + 0.45, -15),
			-- 땀방울: 앞에서 봐서 오른쪽 이마 옆 (캐릭터의 -X) (공 + 위로 뾰족한 마름모)
			ball("Sweat", 0.28, SWEAT, { -1.2, 0.45, FRONT - 0.08 }, "Glass"),
			piece("SweatTip", { 0.18, 0.18, 0.1 }, SWEAT, { -1.2, 0.62, FRONT - 0.08 }, "Glass", {
				rotation = { 0, 0, 45 },
			}),
		})
	elseif expression == "Hurt" then
		return join(crossEyes(), cheeks(), {
			piece("Mouth", { 0.34, 0.08, 0.06 }, MOUTH, { 0, MOUTH_Y, FACE_Z }),
			-- 반창고: 앞에서 봐서 오른쪽 볼 위 비스듬히 (천 + 가운데 패드)
			piece("Bandage", { 0.56, 0.2, 0.05 }, BANDAGE, { -1.0, -0.12, FRONT - 0.04 }, "Fabric", {
				rotation = { 0, 0, -30 },
			}),
			piece("BandagePad", { 0.18, 0.16, 0.05 }, BANDAGE_PAD, { -1.0, -0.12, FRONT - 0.07 }, "Fabric", {
				rotation = { 0, 0, -30 },
			}),
		})
	elseif expression == "Angry" then
		-- 화남 (m5-32, 시트): 안쪽이 내려간 눈썹 + 작게 다문 입 + 앞에서 봐서 오른쪽 이마의 빨간 💢 (마름모 네 획)
		local list = join(openEyes(variant), cheeks(), {
			piece("Mouth", { 0.24, 0.08, 0.06 }, MOUTH, { 0, MOUTH_Y + 0.02, FACE_Z }),
			stroke("BrowLeft", 0.32, -EYE_X + 0.02, EYE_Y + 0.36, -22),
			stroke("BrowRight", 0.32, EYE_X - 0.02, EYE_Y + 0.36, 22),
		})
		for i, mark in ANGER_MARK do
			table.insert(list, stroke(`BrowVein{i}`, 0.15, ANGER_X + mark[1], ANGER_Y + mark[2], mark[3], ANGER))
		end
		return list
	elseif expression == "Sad" then
		-- 슬픔 (m5-32, 시트): 안쪽이 올라간 처진 눈썹 + 아래로 굽은 작은 입 + 앞에서 봐서 오른쪽 눈 밑 눈물 한 방울
		return join(openEyes(variant), cheeks(), {
			stroke("Mouth", 0.22, 0, MOUTH_Y - 0.02, 0),
			stroke("MouthCornerLeft", 0.1, -0.13, MOUTH_Y - 0.05, 35),
			stroke("MouthCornerRight", 0.1, 0.13, MOUTH_Y - 0.05, -35),
			stroke("BrowLeft", 0.28, -EYE_X, EYE_Y + 0.34, 20),
			stroke("BrowRight", 0.28, EYE_X, EYE_Y + 0.34, -20),
			ball("EyeTear", 0.16, SWEAT, { -EYE_X - 0.06, EYE_Y - 0.4, FRONT - 0.05 }, "Glass"),
			piece("EyeTearTip", { 0.1, 0.1, 0.06 }, SWEAT, { -EYE_X - 0.06, EYE_Y - 0.31, FRONT - 0.05 }, "Glass", {
				rotation = { 0, 0, 45 },
			}),
		})
	end
	return join(openEyes(variant), smile(0.42), cheeks())
end

---------------------------------------------------------------- 팔·다리
local ARM_SIZE = { 0.66, 0.74, 0.74 }
local ARM_X, ARM_Y, ARM_Z = RICE_W / 2 + 0.2, -0.45, -0.4

local function limbs(pose: Pose, variant: Variant): { PartSpec }
	local run = pose == "Run"
	local swing = if run then 35 else 0
	-- 게임 스킨은 발바닥을 0.25 내리고(SushiBody 기준), 위끝을 밥 속 y = -0.8까지 올려요 — 걸음·숨쉬기로 발이
	-- 0.35(CharacterAnimLogic.FOOT_MIN)까지 내려가도 몸과 떨어져 보이지 않게 (밥이 넓어 위쪽은 안 보여요)
	local sole = if variant.game then GAME_SOLE else SOLE
	local legH = if variant.game then GAME_LEG_TOP - GAME_SOLE else LEG_H
	local legY = sole + legH / 2
	local legLeft = if variant.game then "FootLeft" else "LegLeft"
	local legRight = if variant.game then "FootRight" else "LegRight"
	return {
		-- 팔: 몸 옆에 붙은 네모 손. 달리면 앞뒤로 엇갈려 흔들어요 (오른팔 앞 = 왼발 앞)
		piece("ArmLeft", ARM_SIZE, RICE, { -ARM_X, ARM_Y, ARM_Z + (if run then 0.35 else 0) }, "Salt", {
			rotation = { swing, 0, -8 },
			joint = true,
		}),
		piece("ArmRight", ARM_SIZE, RICE, { ARM_X, ARM_Y, ARM_Z - (if run then 0.35 else 0) }, "Salt", {
			rotation = { -swing, 0, 8 },
			joint = true,
		}),
		-- 다리: 짧은 네모 발. 달리면 왼발이 앞으로 들려요
		piece(
			legLeft,
			{ LEG_W, legH, LEG_D },
			RICE,
			{ -LEG_X, if run then legY + 0.18 else legY, if run then -0.3 else 0 },
			"Salt",
			{ rotation = if run then { -20, 0, 0 } else nil, joint = true }
		),
		piece(
			legRight,
			{ LEG_W, legH, LEG_D },
			RICE,
			{ LEG_X, if run then legY + 0.09 else legY, if run then 0.25 else 0 },
			"Salt",
			{ rotation = if run then { 15, 0, 0 } else nil, joint = true }
		),
	}
end

---------------------------------------------------------------- 공개 함수
SushiConceptSample.GROUND_OFFSET = -SOLE
SushiConceptSample.GAME_GROUND_OFFSET = -GAME_SOLE

local function isExpression(value: unknown): boolean
	return type(value) == "string" and table.find(SushiConceptSample.EXPRESSIONS, value :: any) ~= nil
end

local function toppingOf(skinId: string?): (Variant) -> { PartSpec }
	local id = skinId or SALMON_ID
	local topping = TOPPINGS[id]
	assert(topping ~= nil, `unknown concept skin {id}`)
	return topping
end

-- 견본 (렌더용, 자세 포함). skinId 없으면 연어 (m5-27 그대로)
-- 입 덮개(MouthCover)는 밥 앞면과 같은 색이어야 입 원판 윗변을 가려요 → 밥 색을 바꾼 스킨(유부)은 덮개도 따라가요
local function maskWithRice(list: { PartSpec }, skinId: string?): { PartSpec }
	local look = RICE_LOOK[skinId or SALMON_ID]
	if look then
		for _, spec in list do
			if spec.name == "MouthCover" then
				spec.color = look.color
				spec.material = look.material
			end
		end
	end
	return list
end

function SushiConceptSample.layout(expression: Expression?, pose: Pose?, skinId: string?): { PartSpec }
	return maskWithRice(
		join(
			rice(skinId),
			toppingOf(skinId)(SAMPLE),
			face(expression or "Default", SAMPLE),
			limbs(pose or "Stand", SAMPLE)
		),
		skinId
	)
end

-- 게임 스킨 (서기 자세). skinId 없으면 "concept-salmon". 모르는 표정 이름이면 기본 표정이에요 (오류 없음),
-- 모르는 skinId는 오류 (SushiBody가 SKIN_IDS만 넘겨요)
function SushiConceptSample.gameLayout(expression: string?, skinId: string?): { PartSpec }
	local chosen: Expression = if isExpression(expression) then expression :: any else "Default"
	return maskWithRice(join(rice(skinId), toppingOf(skinId)(GAME), face(chosen, GAME), limbs("Stand", GAME)), skinId)
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function angles(rotation: { number }?): CFrame
	if rotation == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

function SushiConceptSample.build(expression: Expression?, pose: Pose?, skinId: string?): Model
	local model = Instance.new("Model")
	model.Name = "SushiConceptSample"
	local layout = SushiConceptSample.layout(expression, pose, skinId)
	local parts: { [string]: BasePart } = {}
	for _, spec in layout do
		local part = Instance.new("Part")
		if spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Name = spec.name
		part.Size = vec(spec.size)
		part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		part.Material = (Enum.Material :: any)[spec.material] :: Enum.Material
		part.Transparency = spec.transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(vec(spec.offset)) * angles(spec.rotation)
		part.Anchored = spec.name == "Body"
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
		parts[spec.name] = part
	end
	local root = parts.Body
	assert(root, "concept sample needs a Body part")
	for _, spec in layout do
		local part = parts[spec.name]
		if part == root then
			continue
		end
		if spec.joint then
			local motor = Instance.new("Motor6D")
			motor.Part0 = root
			motor.Part1 = part
			motor.C0 = part.CFrame
			motor.Parent = part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.PrimaryPart = root
	return model
end

return SushiConceptSample
