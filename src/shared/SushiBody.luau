--!strict
-- 초밥 캐릭터 몸. 서버 캐릭터(AppearanceService)와 클라이언트 연출 인형(m3-03 탈락, m3-05 우승, 단상, 탈의실)이 같이 써요.
--   layout(appearanceId, expression?)  파츠 목록 (순수 함수, lune 테스트 가능). 모르는 id면 기본(tamago).
--   hasLayout(id)         그 id 전용 레이아웃이 있는지 (스킨 카탈로그 Shared.Skins와 맞추는 테스트용)
--   bounds(layout)        파츠 목록 전체 외곽 (순수 함수, Body 중심 기준 min/max, 회전 반영)
--   effectCount(layout)   효과(불꽃·반짝이·연기·빛) 개수
--   EFFECT_BUDGET[tier]   등급별 효과 개수 상한 (m5-21). 상한 강제는 호출부(Skins.validate, 테스트)의 몫.
--   BOUNDS_TOLERANCE[tier]  등급별 외곽 상자 허용 비율 (m5-21). 비교도 호출부의 몫 — bounds() 자체는 그대로.
--   BASE_NAMES            모든 스킨이 계란초밥과 똑같이 가지는 기준 파츠 이름 (밥 몸·눈·입·볼·발, m5-25)
--   PART_BUDGET           스킨 하나의 파츠 수 상한 (m5-25, 24명·모바일 기준)
--   build(appearanceId, expression?)   파츠를 만든 Model. expression은 표정이 있는 실험 스킨(concept-*)만 봐요
--                         ("Default"·"Happy"·"Flustered"·"Hurt", 인형 연출용 — 나머지 스킨은 무시). PrimaryPart = Body(Anchored). 원점에 있어요 → PivotTo로 옮겨요.
--   GROUND_OFFSET         Body 중심이 땅(발바닥)에서 몇 studs 위인지. 인형을 땅에 세울 때 써요.
--   NAME_TAG_HEIGHT       Body 중심에서 이름표까지 (CharacterFxController, 렌더러)
--   MODEL_NAME / JOINT_NAME  캐릭터 아래 초밥 Model 이름, HumanoidRootPart에 붙이는 Motor6D 이름
--   PART_JOINT_NAME       움직이는 파츠(눈·감은 눈·발)를 Body에 붙이는 Motor6D 이름 (m5-25, 클라이언트가 Transform만 바꿔요)
--   CONCEPT_BODY[id]      실험 스킨의 명시적 예외 (m5-27·m5-28·m5-29 concept-* 9종): 기준 몸(BASE_NAMES)·외곽 허용치 대신
--                         자기 모양을 쓰고, 파츠 상한은 partBudget. 발바닥은 모든 스킨과 같은 GROUND_OFFSET이에요.
--
-- m5-25 기준 몸 (사용자 확정 2026-10-13): 넓고 낮고 둥근 밥 덩어리. 위에서 보면 알약(가운데 상자 + 양 끝 원기둥) 모양,
-- 앞(-Z)에 큰 눈(테두리·흰자·눈동자·하이라이트)과 웃는 입·볼, 아래에 둥근 발 2개. 스킨은 같은 "가족 문법"을 따라요:
--   ① 앞의 흰 밥 얼굴은 모두 같고, ② 위 토핑(Topping), ③ 등·옆을 덮는 토핑 자락(ToppingBack — 뒤에서 보는 내 화면용),
--   ④ 머리 위 실루엣 한 가지(귀·꼬리·왕관·뿔 등), ⑤ 발 색. 크기·모양 규칙은 docs/specs/m5-25-character-quality.md.
-- 판정은 휴머노이드라 스킨·모양과 무관해요. 초밥 파츠는 보이기만 해요 (Massless, 충돌·쿼리·터치 없음).
-- 좌표: Body 중심 기준, 앞 = -Z (눈이 있는 쪽), 위 = +Y. 발바닥 y = -2.2, 기본 꼭대기 y = 2.3 (높이 4.5).

local SushiConceptSample = require(script.Parent.SushiConceptSample)

local SushiBody = {}

SushiBody.MODEL_NAME = "SushiBody"
SushiBody.JOINT_NAME = "SushiJoint"
SushiBody.PART_JOINT_NAME = "PartJoint"

export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
export type Effect = "Fire" | "Sparkles" | "Smoke" | "Glow"

-- 파츠 하나. Roblox 자료형 대신 숫자 배열을 써요 (lune 테스트용).
export type PartSpec = {
	name: string,
	size: { number }, -- {x, y, z}
	color: { number }, -- {r, g, b} 0~255
	material: string, -- Enum.Material 이름
	offset: { number }, -- Body 중심 기준 위치 {x, y, z}
	shape: Shape?, -- 없으면 Block. Ball은 크기 세 값이 같아야 해요, Cylinder는 X축 방향, Wedge는 쐐기 (m4-13, Wedge는 m5-21)
	rotation: { number }?, -- 도 단위 {x, y, z}, CFrame.Angles 순서 (m4-13)
	effect: Effect?, -- 이 파츠에 붙는 효과 (등급별 예산 이하, m4-13·m5-21)
	effectColor: { number }?, -- 효과 색 {r, g, b}
	transparency: number?, -- 0~1, 없으면 0 (m5-07 유령 천)
	joint: boolean?, -- true면 WeldConstraint 대신 Motor6D(PART_JOINT_NAME)로 Body에 붙어요 — 클라이언트 움직임용 (m5-25)
	attach: string?, -- 이 이름의 파츠에 용접 (없으면 Body). 눈동자·하이라이트가 눈 테두리를 따라 움직이게 (m5-25)
	-- joint + attach면 Motor6D의 Part0이 그 파츠예요 — 관절 사슬 (m5-32 고등어 FishRoot → FishMid → FishTail)
	pivot: { number }?, -- 관절 경첩 (Body 좌표, m5-32). Motor6D 속성 "Pivot"으로 복사돼요 (없으면 파츠 중심)
	reach: { number }?, -- 물방울 관절이 splash 1일 때 옮겨 가는 거리 (Body 축, m5-32). Motor6D 속성 "Reach"
}

export type Bounds = {
	min: { number },
	max: { number },
}

local DEFAULT_ID = "tamago"
-- 콘셉트 몸 실험 스킨 (m5-27 concept-salmon + m5-28 참치·새우·계란·연어알 군함 + m5-29 장어·성게·문어·유부, Skins.CONCEPT_BODY_IDS와 같은 id)
local CONCEPT_IDS: { [string]: boolean } = {}
for _, id in SushiConceptSample.SKIN_IDS do
	CONCEPT_IDS[id] = true
end

---------------------------------------------------------------- 치수 (m5-25)
local RICE_W, RICE_H, RICE_D = 3.6, 2.4, 2.4 -- 밥 몸 (위에서 보면 알약, y -1.2~1.2)
local BASE_Y = -1.32 -- 밥 아래 한 단 좁은 받침 (아래 모서리가 둥글어 보이게, y -1.47~-1.17)
local TOP_Y, TOP_H, TOP_W, TOP_D, TOP_Z = 1.575, 0.9, 3.8, 2.7, 0.1 -- 위 토핑 판 (y 1.125~2.025, 앞 -1.25·뒤 1.45)
local TOP_SURFACE = TOP_Y + TOP_H / 2 -- 2.025 (기본 꼭대기)
local BACK_Z, BACK_D = 0.2, 2.46 -- 토핑 자락은 뒤로 밀린 알약이라 앞(얼굴)에서는 밥 속에 숨어요 (뒤 1.43, 토핑 뒤 1.45보다 살짝 안)
local FOOT_Y, FOOT_D = -1.8, 0.9 -- 발 공 (발바닥 y -2.25)

---------------------------------------------------------------- 색
local RICE = { 247, 243, 232 }
local FOOT = { 226, 206, 178 }
local EGG = { 255, 204, 64 }
local NORI = { 34, 42, 38 }
local INK = { 28, 24, 30 }
local PUPIL = { 40, 30, 36 }
local WHITE = { 255, 255, 255 }
local MOUTH = { 150, 50, 60 }
local CHEEK = { 255, 158, 166 }

local SALMON = { 250, 128, 88 }
local SALMON_FAT = { 255, 236, 220 }
local TUNA = { 196, 32, 52 }
local TUNA_LINE = { 236, 96, 112 }
local SHRIMP_BAND = { 245, 110, 60 }
local SHRIMP_PALE = { 255, 212, 188 }
local SHRIMP_TAIL = { 230, 60, 40 }
local INARI = { 186, 120, 52 }
local INARI_DARK = { 150, 92, 36 }
local CUCUMBER = { 60, 135, 55 }
local CUCUMBER_CORE = { 175, 220, 120 }
local EEL = { 120, 66, 32 }
local EEL_SAUCE = { 70, 36, 16 }
local SESAME_WHITE = { 250, 245, 230 }
local UNI = { 245, 165, 40 }
local UNI_DEEP = { 230, 130, 30 }
local IKURA = { 255, 90, 30 }
local LEAF_GREEN = { 90, 170, 70 }
local OCTOPUS = { 240, 196, 214 }
local OCTOPUS_RIM = { 176, 56, 96 }
local AVOCADO = { 130, 175, 70 }
local AVOCADO_DARK = { 70, 120, 40 }
local WHITE_FISH = { 245, 240, 230 }
local SEARED = { 236, 104, 56 }
local CHAR = { 60, 34, 22 }
local EMBER = { 255, 140, 40 }
local TOBIKO = { 255, 120, 40 }
local GOLD = { 255, 196, 60 }
local GOLD_FAT = { 255, 236, 170 }
local DIAMOND = { 150, 220, 255 }
local SILVER = { 210, 220, 232 }
local DRAGON = { 60, 150, 72 }
local DRAGON_DARK = { 30, 96, 48 }
local DRAGON_HORN = { 240, 220, 150 }
local DRAGON_EYE = { 255, 220, 60 }

-- m5-07: 시즌 한정
local PUMPKIN = { 245, 135, 35 }
local PUMPKIN_DARK = { 200, 96, 24 }
local PUMPKIN_STEM = { 90, 110, 40 }
local PUMPKIN_LEAF = { 80, 150, 60 }
local GHOST_SHEET = { 250, 250, 255 }
local GHOST_GLOW = { 235, 240, 255 }
local SANTA_RED = { 210, 35, 45 }
local SANTA_FUR = { 250, 250, 250 }
local TREE_GREEN = { 40, 120, 60 }
local ORNAMENT_RED = { 220, 40, 50 }
local STAR_YELLOW = { 255, 215, 60 }

-- m5-22: 스킨 1차 배치 10종
local TAKOYAKI_BROWN = { 196, 136, 84 }
local TAKOYAKI_SAUCE = { 96, 52, 28 }
local BONITO = { 214, 160, 120 }
local AONORI = { 90, 140, 50 }
local MAYO_WHITE = { 255, 250, 235 }
local BREAD = { 242, 214, 160 }
local CRUST = { 176, 112, 52 }
local EGG_WHITE = { 255, 255, 250 }
local YOLK_YELLOW = { 255, 186, 30 }
local SLIDER_BUN = { 214, 136, 62 }
local PATTY_BROWN = { 92, 56, 36 }
local LETTUCE_GREEN = { 110, 190, 70 }
local CHEESE = { 255, 200, 40 }
local TONKATSU_GOLD = { 204, 140, 52 }
local TONKATSU_RIDGE = { 160, 100, 36 }
local CABBAGE_GREEN = { 170, 225, 130 }
local SAUCE_BROWN = { 80, 46, 24 }
local CAT_CREAM = { 252, 244, 232 }
local CAT_GINGER = { 240, 150, 70 }
local CAT_TABBY = { 196, 104, 40 }
local CAT_EAR_INNER = { 255, 176, 196 }
local CAT_NOSE = { 255, 110, 150 }
local ROBO_GRAY = { 150, 158, 170 }
local ROBO_DARK = { 70, 76, 88 }
local VISOR_NEON = { 60, 220, 255 }
local ANTENNA_TIP = { 255, 60, 90 }
local GALAXY_NAVY = { 34, 28, 84 }
local GALAXY_PURPLE = { 90, 50, 150 }
local GALAXY_STAR_WHITE = { 245, 245, 255 }
local GALAXY_STAR_TEAL = { 90, 220, 210 }
local PLANET = { 255, 170, 90 }
local SOFTSERVE_CREAM = { 255, 248, 235 }
local SOFTSERVE_PINK = { 255, 196, 214 }
local CHERRY_RED = { 200, 30, 40 }
local CONE_TAN = { 214, 160, 90 }
local CONE_DARK = { 176, 120, 60 }
local CROWN_TUNA_RED = { 160, 24, 44 }
local CROWN_GOLD = { 255, 205, 70 }
local CROWN_JEWEL = { 70, 140, 255 }
local CAPE_VELVET = { 110, 24, 80 }
local UNICORN_WHITE = { 255, 250, 252 }
local MANE_PINK = { 255, 160, 206 }
local MANE_LILAC = { 196, 164, 255 }
local MANE_MINT = { 150, 228, 206 }
local MANE_YELLOW = { 255, 230, 140 }
local HORN_GOLD = { 255, 215, 120 }
local HORN_GOLD_LIGHT = { 255, 238, 190 }

---------------------------------------------------------------- 도우미
type Extra = {
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
}

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
		effect = extra and extra.effect,
		effectColor = extra and extra.effectColor,
		transparency = extra and extra.transparency,
		joint = extra and extra.joint,
		attach = extra and extra.attach,
	}
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

-- 세운 원기둥(축 Y)과 앞을 보는 원판(축 Z): Cylinder는 X축 방향이라 돌려요
local UPRIGHT = { 0, 0, 90 }
local FACING = { 0, 90, 0 }

type PillOpts = { material: string?, transparency: number?, tilt: number? }

-- 알약 판: 위에서 보면 양 끝이 둥근 상자 (가운데 Block + 양 끝 세운 원기둥). 이름 name, name.."L", name.."R".
-- 세 파츠는 색·재질이 같아서 위·아래 면이 같은 평면이어도 깜빡임이 안 보여요 (LayoutCheck는 같은 겉모습 쌍을 빼요).
-- tilt(도): X축으로 기울여요 (+면 뒤쪽이 내려가요). 세 파츠가 같은 X선 위라 각자 돌려도 한 덩어리로 기울어요.
local function pill(
	name: string,
	center: { number },
	w: number,
	h: number,
	d: number,
	color: { number },
	opts: PillOpts?
): { PartSpec }
	assert(w > d, `pill {name}: width must exceed depth`)
	local material = opts and opts.material
	local transparency = opts and opts.transparency
	local tilt = opts and opts.tilt or 0
	local half = (w - d) / 2
	local cx, cy, cz = center[1], center[2], center[3]
	local blockRotation = if tilt ~= 0 then { tilt, 0, 0 } else nil
	return {
		piece(name, { w - d, h, d }, color, { cx, cy, cz }, material, {
			rotation = blockRotation,
			transparency = transparency,
		}),
		piece(`{name}L`, { h, d, d }, color, { cx - half, cy, cz }, material, {
			shape = "Cylinder",
			rotation = { tilt, 0, 90 },
			transparency = transparency,
		}),
		piece(`{name}R`, { h, d, d }, color, { cx + half, cy, cz }, material, {
			shape = "Cylinder",
			rotation = { tilt, 0, 90 },
			transparency = transparency,
		}),
	}
end

-- 세운 원판 (위에서 보는 단면, 축 Y)
local function disc(
	name: string,
	diameter: number,
	height: number,
	color: { number },
	offset: { number },
	material: string?
): PartSpec
	return piece(
		name,
		{ height, diameter, diameter },
		color,
		offset,
		material,
		{ shape = "Cylinder", rotation = UPRIGHT }
	)
end

local function ball(
	name: string,
	diameter: number,
	color: { number },
	offset: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	e.shape = "Ball"
	return piece(name, { diameter, diameter, diameter }, color, offset, material, e)
end

-- 눈 하나 (side -1 = 왼쪽, 1 = 오른쪽): 잉크 테두리(움직이는 파츠) + 흰자 + 눈동자 + 하이라이트, 그리고 감은 눈 선.
-- 감은 눈 선(Lid)은 평소 밥 속에 숨어 있다가 깜빡일 때 클라이언트가 앞으로 꺼내요 (눈은 그때 밥 속으로 들어가요).
local EYE_X, EYE_Y, EYE_Z = 0.62, 0.45, -1.13
local function eye(side: number, prefix: string): { PartSpec }
	local x = side * EYE_X
	local rim = `Eye{prefix}`
	return {
		piece(
			rim,
			{ 0.24, 0.98, 0.98 },
			INK,
			{ x, EYE_Y, EYE_Z },
			nil,
			{ shape = "Cylinder", rotation = FACING, joint = true }
		),
		piece(
			`EyeWhite{prefix}`,
			{ 0.05, 0.84, 0.84 },
			WHITE,
			{ x, EYE_Y, -1.255 },
			nil,
			{ shape = "Cylinder", rotation = FACING, attach = rim }
		),
		piece(
			`Pupil{prefix}`,
			{ 0.04, 0.56, 0.56 },
			PUPIL,
			{ x - side * 0.04, EYE_Y - 0.06, -1.29 },
			nil,
			{ shape = "Cylinder", rotation = FACING, attach = rim }
		),
		-- 하이라이트는 두 눈 모두 왼쪽 위 (빛이 한쪽에서 오는 것처럼)
		piece(`Shine{prefix}`, { 0.2, 0.2, 0.2 }, WHITE, { x - 0.13, EYE_Y + 0.14, -1.3 }, "Neon", {
			shape = "Ball",
			attach = rim,
		}),
		piece(`Lid{prefix}`, { 0.8, 0.12, 0.1 }, INK, { x, EYE_Y - 0.08, -0.97 }, nil, { joint = true }),
	}
end

-- 볼: 둥근 옆면을 따라 바깥으로 27° 돌린 분홍 원판
local function cheek(side: number, prefix: string, color: { number }, material: string?): PartSpec
	local angle = math.rad(27)
	return piece(
		`Cheek{prefix}`,
		{ 0.04, 0.38, 0.38 },
		color,
		{ side * ((RICE_W - RICE_D) / 2 + 1.2 * math.sin(angle)), -0.2, -1.2 * math.cos(angle) },
		material,
		{ shape = "Cylinder", rotation = { 0, 90 - side * 27, 0 } }
	)
end

type BaseOpts = { foot: { number }?, footMaterial: string?, cheek: { number }?, cheekMaterial: string? }

-- 기준 몸: 밥(알약) + 눈 2 + 입 + 볼 2 + 발 2. 모든 스킨이 크기·위치가 같아요 (색만 발·볼을 바꿀 수 있어요).
local function base(opts: BaseOpts?): { PartSpec }
	local foot = opts and opts.foot or FOOT
	local footMaterial = opts and opts.footMaterial
	local cheekColor = opts and opts.cheek or CHEEK
	local cheekMaterial = opts and opts.cheekMaterial
	return join(
		pill("Body", { 0, 0, 0 }, RICE_W, RICE_H, RICE_D, RICE),
		pill("BodyBase", { 0, BASE_Y, 0 }, 3.3, 0.3, 2.1, RICE),
		eye(-1, "Left"),
		eye(1, "Right"),
		{
			piece(
				"Mouth",
				{ 0.1, 0.5, 0.5 },
				MOUTH,
				{ 0, -0.12, -1.17 },
				nil,
				{ shape = "Cylinder", rotation = FACING }
			),
			-- 입 위쪽 반을 덮는 밥 → 아래 반원만 보이는 웃는 입
			piece("MouthCover", { 0.58, 0.27, 0.04 }, RICE, { 0, 0.015, -1.22 }),
			cheek(-1, "Left", cheekColor, cheekMaterial),
			cheek(1, "Right", cheekColor, cheekMaterial),
			ball("FootLeft", FOOT_D, foot, { -0.8, FOOT_Y, -0.15 }, footMaterial, { joint = true }),
			ball("FootRight", FOOT_D, foot, { 0.8, FOOT_Y, -0.15 }, footMaterial, { joint = true }),
		}
	)
end

-- 위 토핑: 밥보다 조금 넓은 알약 판 (앞 0.05·뒤 0.25 튀어나와 밥을 덮어요)
local function top(color: { number }, opts: PillOpts?): { PartSpec }
	return pill("Topping", { 0, TOP_Y, TOP_Z }, TOP_W, TOP_H, TOP_D, color, opts)
end

-- 토핑 자락: 뒤로 밀린 알약이라 등·옆(뒤에서 보는 내 화면)을 덮고 앞 얼굴에서는 밥 속에 숨어요
-- 위끝은 토핑 판 속에 숨고, 아래끝은 bottom(기본 -0.2).
local function back(color: { number }, opts: PillOpts?, bottom: number?): { PartSpec }
	local lo = bottom or -0.2
	local hi = TOP_Y - 0.05
	return pill("ToppingBack", { 0, (lo + hi) / 2, BACK_Z }, TOP_W, hi - lo, BACK_D, color, opts)
end

-- 허리 김 띠 (계란초밥의 상징, 몸을 한 바퀴)
local function belt(color: { number }?, material: string?): { PartSpec }
	return pill("Nori", { 0, -0.75, 0 }, RICE_W + 0.1, 0.55, RICE_D + 0.12, color or NORI, { material = material })
end

-- 토핑 위 비스듬한 줄 (연어 지방, 참치 결) — 게임 거리에서 보이게 폭 0.24
local function stripes(color: { number }, angle: number, material: string?): { PartSpec }
	local list: { PartSpec } = {}
	for i, x in { -0.8, 0, 0.8 } do
		table.insert(
			list,
			piece(
				`Stripe{i}`,
				{ 0.24, 0.06, 2.1 },
				color,
				{ x, TOP_SURFACE + 0.02, 0 },
				material,
				{ rotation = { 0, angle, 0 } }
			)
		)
	end
	return list
end

-- 위·등을 세로로 감는 끈 (계란초밥 김 끈): 토핑 윗면 앞쪽부터 등 아래 자락 끝까지
local function strap(color: { number }, material: string?): { PartSpec }
	local backZ = TOP_Z + TOP_D / 2 + 0.03
	local lo = -0.2
	return {
		piece("Strap", { 0.62, 0.06, TOP_D - 0.34 }, color, { 0, TOP_SURFACE + 0.02, TOP_Z + 0.15 }, material),
		piece(
			"StrapBack",
			{ 0.62, TOP_SURFACE + 0.05 - lo, 0.1 },
			color,
			{ 0, (TOP_SURFACE + 0.05 + lo) / 2, backZ },
			material
		),
	}
end

-- 군함·마키 김 벽: 등·옆을 밥 아래부터 위까지 감싸고 위로 솟아 알갱이를 담는 그릇이 돼요
local function noriWall(topY: number): { PartSpec }
	local lo = -1.1
	return pill("Wall", { 0, (lo + topY) / 2, BACK_Z }, TOP_W, topY - lo, BACK_D, NORI)
end

-- 군함 위 알갱이 (Ball). points = {x, y, z}
local function roe(
	prefix: string,
	color: { number },
	material: string,
	size: number,
	points: { { number } }
): { PartSpec }
	local list: { PartSpec } = {}
	for i, p in points do
		table.insert(list, ball(`{prefix}{i}`, size, color, p, material))
	end
	return list
end

local function withBase(opts: BaseOpts?, ...: { PartSpec }): { PartSpec }
	return join(base(opts), ...)
end

---------------------------------------------------------------- 레이아웃 (m5-25에서 31종 모두 새 몸에 맞춰 다시 배치)
-- 자주 쓰는 높이·깊이 (m5-25)
local ON_TOP = TOP_SURFACE + 0.02 -- 토핑 윗면에 얹는 얇은 장식 중심
local BACK_FACE = BACK_Z + BACK_D / 2 -- 토핑 자락 뒷면 z (1.45), 평평한 폭 |x| ≤ 0.65
local WALL_TOP = 1.75 -- 군함·마키 김 벽 윗면

-- 토핑 자락 뒷면(평평한 가운데)에 붙이는 판. size[3]이 두께
local function onBack(
	name: string,
	size: { number },
	color: { number },
	y: number,
	material: string?,
	extra: Extra?
): PartSpec
	return piece(name, size, color, { 0, y, BACK_FACE + size[3] / 2 - 0.01 }, material, extra)
end

-- 세모 쐐기를 앞에서 보이게 세워요 (side -1: 높은 쪽이 +X(안쪽), 1: 높은 쪽이 -X(안쪽)). size = {두께, 높이, 폭}
local function triangle(
	name: string,
	size: { number },
	color: { number },
	offset: { number },
	side: number,
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	e.shape = "Wedge"
	e.rotation = { 0, -side * 90, 0 }
	return piece(name, size, color, offset, material, e)
end

local LAYOUTS: { [string]: { PartSpec } } = {
	-- 기본: 노란 계란 + 등 자락 + 허리 김 띠
	tamago = withBase(nil, top(EGG), back(EGG), belt(), strap(NORI)),

	---------------------------------------------------------------- 일반
	salmon = withBase(nil, top(SALMON), back(SALMON), stripes(SALMON_FAT, 30), {
		onBack("BackStripe1", { 0.22, 1.0, 0.06 }, SALMON_FAT, 0.45, nil, { rotation = { 0, 0, 30 } }),
	}),
	tuna = withBase({ foot = TUNA_LINE }, top(TUNA), back(TUNA), stripes(TUNA_LINE, -25), {
		onBack("BackStripe1", { 0.22, 1.0, 0.06 }, TUNA_LINE, 0.45, nil, { rotation = { 0, 0, -25 } }),
	}),
	-- 새우: 흰 바탕 + 주황 줄 3개(위·등까지) + 등 위로 솟는 빨간 꼬리 부채 (실루엣)
	shrimp = withBase(nil, top(SHRIMP_PALE), back(SHRIMP_PALE), {
		piece("Band1", { 0.42, 0.06, 2.0 }, SHRIMP_BAND, { -1.0, ON_TOP, TOP_Z }),
		piece("Band2", { 0.42, 0.06, 2.6 }, SHRIMP_BAND, { 0, ON_TOP, TOP_Z }),
		piece("Band3", { 0.42, 0.06, 2.0 }, SHRIMP_BAND, { 1.0, ON_TOP, TOP_Z }),
		onBack("BackBand1", { 1.3, 0.3, 0.06 }, SHRIMP_BAND, 0.75),
		onBack("BackBand2", { 1.3, 0.3, 0.06 }, SHRIMP_BAND, 0.15),
		piece("TailLeft", { 0.26, 0.7, 0.6 }, SHRIMP_TAIL, { -0.28, TOP_SURFACE + 0.28, 1.15 }, nil, {
			shape = "Wedge",
			rotation = { 0, 180, 20 },
		}),
		piece("TailRight", { 0.26, 0.7, 0.6 }, SHRIMP_TAIL, { 0.28, TOP_SURFACE + 0.28, 1.15 }, nil, {
			shape = "Wedge",
			rotation = { 0, 180, -20 },
		}),
	}),
	-- 유부: 튀긴 두부 주머니가 위·등·옆을 길게 감싸요 (천 재질), 위에 접힌 주름
	inari = withBase(
		{ foot = INARI_DARK },
		top(INARI, { material = "Fabric" }),
		back(INARI, { material = "Fabric" }, -0.95),
		pill("Fold", { 0, TOP_SURFACE + 0.08, 0.4 }, 2.6, 0.2, 0.6, INARI_DARK, { material = "Fabric" })
	),
	-- 오이마키: 김 벽 + 위에서 보면 흰 밥 원 안의 초록 오이 (마키 단면)
	["kappa-maki"] = withBase(nil, noriWall(WALL_TOP), {
		disc("RiceTop", 2.3, 0.1, RICE, { 0, WALL_TOP + 0.04, 0.1 }),
		disc("Cucumber", 1.3, 0.12, CUCUMBER, { 0, WALL_TOP + 0.1, 0.1 }),
		disc("CucumberCore", 0.75, 0.12, CUCUMBER_CORE, { 0, WALL_TOP + 0.14, 0.1 }),
	}),
	-- 타코야키: 갈색 소스 자락 + 위에 둥근 볼 4개(실루엣) + 마요·가쓰오부시·파래
	takoyaki = withBase(
		{ foot = TAKOYAKI_SAUCE },
		back(TAKOYAKI_SAUCE),
		pill("Topping", { 0, 1.35, 0.1 }, 3.8, 0.3, 2.6, TAKOYAKI_SAUCE),
		{
			ball("Ball1", 1.2, TAKOYAKI_BROWN, { -0.7, 1.85, -0.45 }),
			ball("Ball2", 1.2, TAKOYAKI_BROWN, { 0.7, 1.85, -0.45 }),
			ball("Ball3", 1.2, TAKOYAKI_BROWN, { -0.65, 1.85, 0.6 }),
			ball("Ball4", 1.2, TAKOYAKI_BROWN, { 0.65, 1.85, 0.6 }),
			piece("Mayo1", { 2.4, 0.1, 0.16 }, MAYO_WHITE, { 0, 2.42, -0.45 }, nil, { rotation = { 0, 8, 0 } }),
			piece("Mayo2", { 2.4, 0.1, 0.16 }, MAYO_WHITE, { 0, 2.42, 0.6 }, nil, { rotation = { 0, -8, 0 } }),
			piece("Bonito1", { 0.5, 0.06, 0.34 }, BONITO, { -0.65, 2.45, 0.05 }, nil, { rotation = { 0, 35, 12 } }),
			piece("Bonito2", { 0.5, 0.06, 0.34 }, BONITO, { 0.6, 2.45, 0.05 }, nil, { rotation = { 0, -25, -10 } }),
			ball("Aonori", 0.22, AONORI, { 0, 2.34, 0.08 }),
		}
	),
	-- 에그토스트: 연한 빵 + 진한 빵 껍질 자락 + 흰 달걀 프라이 원판 + 노른자 돔 (실루엣)
	["egg-toast"] = withBase({ foot = CRUST }, top(BREAD), back(CRUST), {
		disc("EggWhite", 2.2, 0.12, EGG_WHITE, { -0.15, TOP_SURFACE + 0.04, TOP_Z }),
		ball("Yolk", 0.9, YOLK_YELLOW, { 0.05, TOP_SURFACE + 0.15, TOP_Z }),
	}),
	-- 슬라이더 버거: 갈색 패티·초록 상추가 이마를 한 바퀴, 노란 치즈 끝이 앞으로 늘어지고, 두툼한 번 + 참깨, 등은 번 색 자락
	["slider-burger"] = withBase(
		{ foot = PATTY_BROWN },
		pill("Patty", { 0, 1.25, 0.05 }, 3.84, 0.34, 2.66, PATTY_BROWN),
		pill("Lettuce", { 0, 1.45, 0.05 }, 3.94, 0.12, 2.78, LETTUCE_GREEN),
		{ piece("Cheese", { 2.0, 0.08, 2.0 }, CHEESE, { 0, 1.53, 0 }, nil, { rotation = { 0, 45, 0 } }) },
		pill("Topping", { 0, 1.82, 0.05 }, 3.7, 0.6, 2.6, SLIDER_BUN),
		pill("ToppingBack", { 0, 0.45, BACK_Z }, TOP_W, 1.3, BACK_D, SLIDER_BUN),
		{
			ball("Sesame1", 0.2, SESAME_WHITE, { -0.6, 2.17, -0.3 }),
			ball("Sesame2", 0.2, SESAME_WHITE, { 0.5, 2.17, 0.3 }),
			ball("Sesame3", 0.2, SESAME_WHITE, { -0.1, 2.17, 0.5 }),
			ball("Sesame4", 0.2, SESAME_WHITE, { 0.3, 2.17, -0.5 }),
		}
	),

	---------------------------------------------------------------- 레어
	-- 장어: 갈색 + 윤기 소스 + 허리 김 띠 + 참깨
	eel = withBase(nil, top(EEL), back(EEL), belt(), {
		piece("Sauce", { 2.2, 0.06, 2.0 }, EEL_SAUCE, { 0, ON_TOP, TOP_Z }, "Glass"),
		ball("Sesame1", 0.18, SESAME_WHITE, { -0.5, TOP_SURFACE + 0.07, -0.3 }),
		ball("Sesame2", 0.18, SESAME_WHITE, { 0.4, TOP_SURFACE + 0.07, 0.4 }),
		ball("Sesame3", 0.18, SESAME_WHITE, { -0.1, TOP_SURFACE + 0.07, 0.8 }),
	}),
	-- 성게: 김 벽 그릇 + 위에 주황 성게 덩어리 6개 (두 가지 주황)
	uni = withBase(nil, noriWall(WALL_TOP), {
		ball("Uni1", 0.8, UNI, { -0.8, WALL_TOP + 0.2, -0.45 }),
		ball("Uni2", 0.8, UNI_DEEP, { 0, WALL_TOP + 0.25, -0.5 }),
		ball("Uni3", 0.8, UNI, { 0.8, WALL_TOP + 0.2, -0.45 }),
		ball("Uni4", 0.8, UNI_DEEP, { -0.75, WALL_TOP + 0.25, 0.45 }),
		ball("Uni5", 0.8, UNI, { 0, WALL_TOP + 0.3, 0.4 }),
		ball("Uni6", 0.8, UNI_DEEP, { 0.75, WALL_TOP + 0.25, 0.45 }),
	}),
	-- 연어알: 김 벽 그릇 + 작은 유리 알이 수북 + 초록 잎 (성게와 알 크기·색·잎으로 구분)
	ikura = withBase(
		nil,
		noriWall(WALL_TOP),
		roe("Ikura", IKURA, "Glass", 0.52, {
			{ -1.0, WALL_TOP + 0.12, -0.4 },
			{ -0.5, WALL_TOP + 0.12, -0.5 },
			{ 0.0, WALL_TOP + 0.12, -0.5 },
			{ 0.5, WALL_TOP + 0.12, -0.45 },
			{ 1.0, WALL_TOP + 0.12, -0.3 },
			{ -0.9, WALL_TOP + 0.12, 0.45 },
			{ -0.4, WALL_TOP + 0.12, 0.35 },
			{ 0.15, WALL_TOP + 0.12, 0.4 },
			{ 0.7, WALL_TOP + 0.12, 0.5 },
			{ -0.6, WALL_TOP + 0.42, 0 },
			{ -0.05, WALL_TOP + 0.47, 0.05 },
			{ 0.5, WALL_TOP + 0.42, 0 },
		}),
		{
			piece("Leaf", { 0.12, 0.6, 0.9 }, LEAF_GREEN, { -1.05, WALL_TOP + 0.3, 0.8 }, nil, {
				shape = "Wedge",
				rotation = { 0, 30, 20 },
			}),
		}
	),
	-- 문어: 연분홍 + 앞 가장자리 진분홍 테 + 큰 빨판 + 진분홍 자락 + 허리 김 띠
	octopus = withBase(nil, top(OCTOPUS), back(OCTOPUS_RIM), belt(), {
		piece("Rim", { 1.0, 0.24, 0.1 }, OCTOPUS_RIM, { 0, TOP_Y - 0.22, TOP_Z - TOP_D / 2 - 0.04 }),
		disc("Sucker1", 0.55, 0.08, OCTOPUS_RIM, { -0.85, ON_TOP, -0.3 }),
		disc("Sucker2", 0.55, 0.08, OCTOPUS_RIM, { 0, ON_TOP, 0.2 }),
		disc("Sucker3", 0.55, 0.08, OCTOPUS_RIM, { 0.85, ON_TOP, -0.3 }),
		disc("Sucker4", 0.45, 0.08, OCTOPUS_RIM, { -0.5, ON_TOP, 0.85 }),
		disc("Sucker5", 0.45, 0.08, OCTOPUS_RIM, { 0.55, ON_TOP, 0.85 }),
	}),
	-- 돈가스: 바삭한 금갈색 + 진한 결 + 등 위 양배추 더미(실루엣) + 소스
	tonkatsu = withBase(
		{ foot = TONKATSU_RIDGE },
		top(TONKATSU_GOLD),
		back(TONKATSU_RIDGE),
		stripes(TONKATSU_RIDGE, 60),
		{
			piece("Sauce", { 2.4, 0.08, 0.3 }, SAUCE_BROWN, { 0, TOP_SURFACE + 0.05, -0.55 }, nil, {
				rotation = { 0, -6, 0 },
			}),
			ball("Cabbage1", 0.8, CABBAGE_GREEN, { -0.45, TOP_SURFACE + 0.15, 0.9 }),
			ball("Cabbage2", 0.8, CABBAGE_GREEN, { 0.4, TOP_SURFACE + 0.15, 0.95 }),
			ball("Cabbage3", 0.66, LETTUCE_GREEN, { 0, TOP_SURFACE + 0.26, 0.8 }),
		}
	),
	-- 고양이: 크림색 + 생강색 무늬·자락 + 위로 솟은 세모 귀(실루엣) + 코 + 수염 + 등 뒤 꼬리
	["cat-sushi"] = withBase({ foot = CAT_CREAM, cheek = CAT_EAR_INNER }, top(CAT_CREAM), back(CAT_GINGER), {
		piece("Patch1", { 1.1, 0.06, 0.9 }, CAT_GINGER, { 0, ON_TOP, 0.75 }, nil, { rotation = { 0, 10, 0 } }),
		triangle("EarLeft", { 0.36, 0.7, 0.8 }, CAT_GINGER, { -1.0, TOP_SURFACE + 0.25, -0.3 }, -1),
		triangle("EarRight", { 0.36, 0.7, 0.8 }, CAT_GINGER, { 1.0, TOP_SURFACE + 0.25, -0.3 }, 1),
		triangle("EarInnerLeft", { 0.06, 0.45, 0.5 }, CAT_EAR_INNER, { -0.85, TOP_SURFACE + 0.125, -0.5 }, -1),
		triangle("EarInnerRight", { 0.06, 0.45, 0.5 }, CAT_EAR_INNER, { 0.85, TOP_SURFACE + 0.125, -0.5 }, 1),
		ball("Nose", 0.22, CAT_NOSE, { 0, 0.12, -1.24 }),
		piece("WhiskerLeft", { 0.6, 0.06, 0.06 }, INK, { -1.3, 0.02, -0.8 }, nil, { rotation = { 0, -40, 8 } }),
		piece("WhiskerRight", { 0.6, 0.06, 0.06 }, INK, { 1.3, 0.02, -0.8 }, nil, { rotation = { 0, 40, -8 } }),
		onBack("Tabby1", { 1.2, 0.2, 0.06 }, CAT_TABBY, 0.85),
		onBack("Tabby2", { 1.2, 0.2, 0.06 }, CAT_TABBY, 0.45),
		piece("Tail", { 0.9, 0.32, 0.32 }, CAT_GINGER, { 0.55, -0.75, 1.42 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 0, 60 },
		}),
		ball("TailTip", 0.4, CAT_TABBY, { 0.78, -0.36, 1.42 }),
	}),
	-- 로보: 금속 회색 + 진한 등판 + 옆 볼트 귀 + 안테나(빛) + 하늘색 LED 볼
	["robo-roll"] = withBase(
		{ foot = ROBO_DARK, footMaterial = "Metal", cheek = VISOR_NEON, cheekMaterial = "Neon" },
		top(ROBO_GRAY, { material = "Metal" }),
		back(ROBO_DARK, { material = "Metal" }),
		{
			piece("PanelLine", { 3.0, 0.08, 0.12 }, ROBO_DARK, { 0, ON_TOP, -0.2 }),
			piece("BoltLeft", { 0.3, 0.6, 0.6 }, ROBO_DARK, { -1.95, 0.6, 0.15 }, "Metal", { shape = "Cylinder" }),
			piece("BoltRight", { 0.3, 0.6, 0.6 }, ROBO_DARK, { 1.95, 0.6, 0.15 }, "Metal", { shape = "Cylinder" }),
			piece("AntennaRod", { 0.4, 0.1, 0.1 }, ROBO_DARK, { 0, TOP_SURFACE + 0.18, 0.6 }, "Metal", {
				shape = "Cylinder",
				rotation = UPRIGHT,
			}),
			ball("AntennaTip", 0.26, ANTENNA_TIP, { 0, TOP_SURFACE + 0.48, 0.6 }, "Neon", {
				effect = "Glow",
				effectColor = { 255, 60, 90 },
			}),
		}
	),

	---------------------------------------------------------------- 에픽
	-- 무지개 롤: 다섯 색 띠 + 아보카도 자락 + 허리 김 띠
	["rainbow-roll"] = withBase(nil, top(AVOCADO), back(AVOCADO), belt(), {
		piece("Rainbow1", { 2.0, 0.08, 0.44 }, SALMON, { 0, ON_TOP, TOP_Z - 0.88 }),
		piece("Rainbow2", { 2.4, 0.08, 0.44 }, TUNA, { 0, ON_TOP, TOP_Z - 0.44 }),
		piece("Rainbow3", { 2.4, 0.08, 0.44 }, WHITE_FISH, { 0, ON_TOP, TOP_Z }),
		piece("Rainbow4", { 2.4, 0.08, 0.44 }, EGG, { 0, ON_TOP, TOP_Z + 0.44 }),
		piece("Rainbow5", { 2.0, 0.08, 0.44 }, IKURA, { 0, ON_TOP, TOP_Z + 0.88 }),
	}),
	-- 불꽃 연어: 그을린 주황 + 큰 탄 자국 + 불꽃 + 탄 발
	["aburi-salmon"] = withBase({ foot = CHAR }, top(SEARED), back(SEARED), {
		piece("Char1", { 0.7, 0.06, 0.5 }, CHAR, { -0.75, ON_TOP, -0.25 }, nil, { rotation = { 0, 20, 0 } }),
		piece("Char2", { 0.6, 0.06, 0.6 }, CHAR, { 0.5, ON_TOP, 0.4 }, nil, { rotation = { 0, -30, 0 } }),
		piece("Char3", { 0.8, 0.06, 0.4 }, CHAR, { -0.2, ON_TOP, 0.95 }, nil, { rotation = { 0, 10, 0 } }),
		onBack("CharBack", { 1.0, 0.5, 0.06 }, CHAR, 0.5),
		piece("Ember", { 0.36, 0.12, 0.36 }, EMBER, { 0.6, TOP_SURFACE + 0.05, -0.3 }, "Neon", {
			effect = "Fire",
			effectColor = EMBER,
		}),
	}),
	-- 캘리포니아롤: 초록 아보카도 조각 부채 + 주황 날치알 자락(모래 재질)
	["california-roll"] = withBase({ foot = TOBIKO }, top(AVOCADO_DARK), back(TOBIKO, { material = "Sand" }), {
		piece("Slice1", { 0.8, 0.12, 2.2 }, AVOCADO, { -0.9, TOP_SURFACE + 0.04, TOP_Z }, nil, {
			rotation = { 0, 12, 0 },
		}),
		piece("Slice2", { 0.8, 0.12, 2.4 }, AVOCADO, { 0, TOP_SURFACE + 0.07, TOP_Z }),
		piece("Slice3", { 0.8, 0.12, 2.2 }, AVOCADO, { 0.9, TOP_SURFACE + 0.04, TOP_Z }, nil, {
			rotation = { 0, -12, 0 },
		}),
		piece("Tobiko", { 2.4, 0.16, 0.36 }, TOBIKO, { 0, TOP_SURFACE + 0.14, 1.1 }, "Sand"),
	}),
	-- 갤럭시 롤: 남색 + 보라 자락 + 별 + 위에 고리 행성(실루엣), 반짝이 + 은은한 빛
	["galaxy-roll"] = withBase({ foot = GALAXY_NAVY }, top(GALAXY_NAVY), back(GALAXY_PURPLE), {
		ball("Star1", 0.22, GALAXY_STAR_WHITE, { -0.9, TOP_SURFACE + 0.04, -0.35 }, "Neon"),
		ball("Star2", 0.22, GALAXY_STAR_WHITE, { 0.95, TOP_SURFACE + 0.04, 0.15 }, "Neon"),
		ball("Star3", 0.22, GALAXY_STAR_TEAL, { -0.35, TOP_SURFACE + 0.04, 0.9 }, "Neon"),
		ball("Star4", 0.22, GALAXY_STAR_WHITE, { 0.55, TOP_SURFACE + 0.04, -0.8 }, "Neon"),
		ball("Planet", 0.8, PLANET, { -0.15, TOP_SURFACE + 0.35, 0.25 }, nil, {
			effect = "Sparkles",
			effectColor = { 120, 230, 220 },
		}),
		piece("PlanetRing", { 0.06, 1.4, 1.4 }, GALAXY_STAR_TEAL, { -0.15, TOP_SURFACE + 0.35, 0.25 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 20, 70 },
		}),
		ball("Star5", 0.2, GALAXY_STAR_TEAL, { 0.4, 0.75, BACK_FACE + 0.05 }, "Neon"),
		ball("GlowCore", 0.26, GALAXY_STAR_WHITE, { -0.3, 0.35, BACK_FACE + 0.06 }, "Neon", {
			effect = "Glow",
			effectColor = { 200, 200, 255 },
		}),
	}),
	-- 소프트아이스크림: 와플 콘 자락 + 위로 쌓인 크림 소용돌이(실루엣) + 체리
	["softserve-roll"] = withBase(
		{ foot = CONE_DARK },
		back(CONE_TAN),
		{
			onBack("ConeLine1", { 0.12, 1.1, 0.06 }, CONE_DARK, 0.45, nil, { rotation = { 0, 0, 35 } }),
			onBack("ConeLine2", { 0.12, 1.1, 0.06 }, CONE_DARK, 0.45, nil, { rotation = { 0, 0, -35 } }),
		},
		top(SOFTSERVE_CREAM),
		{
			disc("Swirl1", 2.6, 0.36, SOFTSERVE_PINK, { 0, TOP_SURFACE + 0.16, TOP_Z }),
			disc("Swirl2", 1.9, 0.34, SOFTSERVE_CREAM, { 0, TOP_SURFACE + 0.49, TOP_Z }),
			disc("Swirl3", 1.2, 0.3, SOFTSERVE_PINK, { 0, TOP_SURFACE + 0.8, TOP_Z }),
			ball("Cherry", 0.3, CHERRY_RED, { 0.1, TOP_SURFACE + 0.91, TOP_Z }),
		}
	),
	-- 호박 초밥: 주황 호박(골) + 앞 잭오랜턴 얼굴 + 꼭지·잎 + 김 띠
	["pumpkin-sushi"] = withBase(
		{ foot = PUMPKIN_DARK },
		belt(),
		back(PUMPKIN_DARK),
		pill("Topping", { 0, 1.62, TOP_Z }, TOP_W, 1.0, TOP_D, PUMPKIN),
		{
			piece("Rib1", { 0.14, 0.06, 2.3 }, PUMPKIN_DARK, { -0.6, 2.12, TOP_Z }),
			piece("Rib2", { 0.14, 0.06, 2.6 }, PUMPKIN_DARK, { 0, 2.12, TOP_Z }),
			piece("Rib3", { 0.14, 0.06, 2.3 }, PUMPKIN_DARK, { 0.6, 2.12, TOP_Z }),
			triangle("JackEyeLeft", { 0.12, 0.38, 0.4 }, INK, { -0.42, 1.72, TOP_Z - TOP_D / 2 - 0.04 }, -1),
			triangle("JackEyeRight", { 0.12, 0.38, 0.4 }, INK, { 0.42, 1.72, TOP_Z - TOP_D / 2 - 0.04 }, 1),
			piece("JackMouth", { 1.0, 0.14, 0.08 }, INK, { 0, 1.36, TOP_Z - TOP_D / 2 - 0.03 }),
			disc("Stem", 0.36, 0.42, PUMPKIN_STEM, { 0, 2.32, TOP_Z }),
			piece("Leaf", { 0.6, 0.08, 0.34 }, PUMPKIN_LEAF, { 0.4, 2.16, 0.35 }, nil, { rotation = { 0, -25, 10 } }),
		}
	),
	-- 산타 새우: 새우 + 흰 털 테두리 빨간 모자(끝이 옆으로 접혀 방울이 달랑) + 빨간 자락.
	-- 시즌 스킨이라 외곽은 등급 허용치보다 좁은 계란초밥 ±15% 안 (m5-07 AC6) → 모자가 낮게 접혀요
	["santa-shrimp"] = withBase(nil, top(SHRIMP_PALE), back(SANTA_RED, { material = "Fabric" }), {
		piece("Band1", { 0.32, 0.06, 2.2 }, SHRIMP_BAND, { -1.0, ON_TOP, TOP_Z }),
		piece("Band3", { 0.32, 0.06, 2.2 }, SHRIMP_BAND, { 1.0, ON_TOP, TOP_Z }),
		disc("HatBrim", 2.0, 0.26, SANTA_FUR, { 0, TOP_SURFACE + 0.1, TOP_Z }, "Fabric"),
		disc("HatBase", 1.5, 0.3, SANTA_RED, { 0, TOP_SURFACE + 0.36, TOP_Z }, "Fabric"),
		disc("HatMid", 0.9, 0.18, SANTA_RED, { 0.1, TOP_SURFACE + 0.58, TOP_Z }, "Fabric"),
		piece("HatTip", { 0.6, 0.34, 0.34 }, SANTA_RED, { 0.75, TOP_SURFACE + 0.42, TOP_Z }, "Fabric", {
			shape = "Cylinder",
			rotation = { 0, 0, -20 },
		}),
		ball("HatPompom", 0.4, SANTA_FUR, { 1.15, TOP_SURFACE + 0.3, TOP_Z }, "Fabric"),
	}),

	---------------------------------------------------------------- 레어 시즌·VIP
	-- 유령 계란초밥: 계란초밥 위에 반투명 흰 천(위·등)과 둥근 검은 눈, 은은한 흰 빛
	["ghost-tamago"] = withBase(
		nil,
		top(EGG),
		back(EGG),
		belt(),
		pill("Sheet", { 0, TOP_SURFACE + 0.12, TOP_Z }, 4.0, 0.26, 2.92, GHOST_SHEET, {
			material = "Fabric",
			transparency = 0.25,
		}),
		pill("SheetBack", { 0, 0.82, BACK_Z + 0.05 }, 4.0, 2.1, 2.7, GHOST_SHEET, {
			material = "Fabric",
			transparency = 0.25,
		}),
		{
			disc("GhostEyeLeft", 0.44, 0.06, INK, { -0.55, TOP_SURFACE + 0.26, -0.5 }),
			disc("GhostEyeRight", 0.44, 0.06, INK, { 0.55, TOP_SURFACE + 0.26, -0.5 }),
			ball("GhostGlow", 0.2, GHOST_GLOW, { 0, TOP_SURFACE + 0.28, 0.6 }, "Neon", {
				effect = "Glow",
				effectColor = GHOST_GLOW,
			}),
		}
	),
	-- 트리 마키: 오이마키 위 초록 원뿔 트리 3층 + 빨간 방울 + 노란 별(반짝이)
	["tree-maki"] = withBase(nil, noriWall(WALL_TOP), {
		disc("RiceTop", 2.3, 0.1, RICE, { 0, WALL_TOP + 0.04, 0.1 }),
		disc("TreeLayer1", 1.9, 0.2, CUCUMBER, { 0, 1.94, 0.1 }),
		disc("TreeLayer2", 1.35, 0.2, TREE_GREEN, { 0, 2.12, 0.1 }),
		disc("TreeLayer3", 0.8, 0.2, CUCUMBER, { 0, 2.3, 0.1 }),
		ball("Ornament1", 0.24, ORNAMENT_RED, { -0.75, 1.96, -0.45 }),
		ball("Ornament2", 0.24, ORNAMENT_RED, { 0.5, 2.14, -0.4 }),
		ball("Ornament3", 0.2, STAR_YELLOW, { -0.3, 2.32, -0.15 }),
		piece("StarA", { 0.2, 0.2, 0.1 }, STAR_YELLOW, { 0, 2.48, 0.1 }, "Neon", {
			rotation = { 0, 0, 45 },
			effect = "Sparkles",
			effectColor = STAR_YELLOW,
		}),
		piece("StarB", { 0.18, 0.18, 0.12 }, STAR_YELLOW, { 0, 2.48, 0.1 }, "Neon"),
	}),

	---------------------------------------------------------------- 전설
	-- 황금 참치 뱃살: 온통 금박(위·등·발) + 연한 금 지방 줄 + 반짝이
	["golden-otoro"] = withBase(
		{ foot = GOLD, footMaterial = "Foil" },
		top(GOLD, { material = "Foil" }),
		back(GOLD, { material = "Foil" }),
		stripes(GOLD_FAT, 30, "Foil"),
		{
			onBack("BackStripe1", { 0.22, 1.0, 0.06 }, GOLD_FAT, 0.45, "Foil", { rotation = { 0, 0, 30 } }),
			ball("Shine", 0.3, GOLD_FAT, { 0, TOP_SURFACE + 0.1, TOP_Z }, "Foil", {
				effect = "Sparkles",
				effectColor = { 255, 220, 90 },
			}),
		}
	),
	-- 다이아 성게: 은테 김 벽 그릇 + 하늘색 보석 알 + 가운데 큰 다이아(실루엣) + 반짝이
	["diamond-uni"] = withBase({ foot = SILVER, footMaterial = "Foil" }, noriWall(WALL_TOP), {
		onBack("Rim", { 1.2, 0.2, 0.08 }, SILVER, WALL_TOP - 0.15, "Foil"),
		ball("Diamond1", 0.7, DIAMOND, { -0.9, WALL_TOP + 0.18, -0.4 }, "Glass"),
		ball("Diamond2", 0.7, DIAMOND, { 0.9, WALL_TOP + 0.18, -0.4 }, "Glass"),
		ball("Diamond3", 0.7, DIAMOND, { -0.85, WALL_TOP + 0.18, 0.55 }, "Glass"),
		ball("Diamond4", 0.7, DIAMOND, { 0.85, WALL_TOP + 0.18, 0.55 }, "Glass"),
		ball("Diamond5", 0.7, DIAMOND, { 0, WALL_TOP + 0.18, 0.8 }, "Glass"),
		piece("Gem", { 0.8, 0.8, 0.8 }, DIAMOND, { 0, WALL_TOP + 0.55, -0.1 }, "Glass", {
			rotation = { 45, 0, 45 },
			effect = "Sparkles",
			effectColor = { 180, 235, 255 },
		}),
	}),
	-- 용 롤: 초록 + 등줄기 가시(실루엣) + 앞 머리·뿔·노란 눈 + 엉덩이 꼬리
	["dragon-roll"] = withBase({ foot = DRAGON_DARK }, top(DRAGON), back(DRAGON_DARK), {
		piece("Spike1", { 0.3, 0.55, 0.5 }, DRAGON_DARK, { 0, TOP_SURFACE + 0.2, 0.05 }, nil, { shape = "Wedge" }),
		piece("Spike2", { 0.3, 0.5, 0.45 }, DRAGON_DARK, { 0, TOP_SURFACE + 0.18, 0.6 }, nil, { shape = "Wedge" }),
		piece("Spike3", { 0.3, 0.45, 0.4 }, DRAGON_DARK, { 0, TOP_SURFACE + 0.15, 1.1 }, nil, { shape = "Wedge" }),
		piece("Head", { 1.2, 0.6, 0.6 }, DRAGON, { 0, TOP_SURFACE + 0.22, -0.75 }),
		piece("Snout", { 0.8, 0.36, 0.3 }, DRAGON, { 0, TOP_SURFACE + 0.1, -1.15 }),
		piece("HeadEyeLeft", { 0.2, 0.2, 0.06 }, DRAGON_EYE, { -0.32, TOP_SURFACE + 0.32, -1.07 }, "Neon"),
		piece("HeadEyeRight", { 0.2, 0.2, 0.06 }, DRAGON_EYE, { 0.32, TOP_SURFACE + 0.32, -1.07 }, "Neon"),
		piece("HornLeft", { 0.2, 0.5, 0.4 }, DRAGON_HORN, { -0.42, TOP_SURFACE + 0.72, -0.6 }, nil, {
			shape = "Wedge",
			rotation = { 0, 180, 15 },
		}),
		piece("HornRight", { 0.2, 0.5, 0.4 }, DRAGON_HORN, { 0.42, TOP_SURFACE + 0.72, -0.6 }, nil, {
			shape = "Wedge",
			rotation = { 0, 180, -15 },
		}),
		piece("Tail", { 0.5, 0.6, 0.8 }, DRAGON_DARK, { 0.5, -0.75, 1.5 }, nil, {
			shape = "Wedge",
			rotation = { 90, 0, 0 },
		}),
	}),
	-- 금박 계란초밥 (VIP): 계란초밥 + 금박 두 장 + 금 허리띠 + 금 발, 반짝이
	["vip-gold-tamago"] = withBase(
		{ foot = GOLD, footMaterial = "Foil" },
		top(EGG),
		back(EGG),
		belt(GOLD, "Foil"),
		strap(GOLD, "Foil"),
		{
			piece("GoldLeaf1", { 1.0, 0.06, 1.0 }, GOLD_FAT, { -1.05, ON_TOP, -0.1 }, "Foil", {
				rotation = { 0, 15, 0 },
				effect = "Sparkles",
				effectColor = GOLD,
			}),
			piece("GoldLeaf2", { 0.8, 0.06, 0.7 }, GOLD_FAT, { 1.05, ON_TOP, 0.6 }, "Foil", {
				rotation = { 0, -20, 0 },
			}),
		}
	),
	-- 크라운 참치: 진홍 참치 + 금관(띠 + 가시 5 + 보석) + 벨벳 망토 자락(길게) + 흰 털 + 반짝이·빛
	["crown-tuna"] = withBase(
		{ foot = CROWN_GOLD, footMaterial = "Foil" },
		top(CROWN_TUNA_RED),
		back(CAPE_VELVET, { material = "Fabric" }, -1.05),
		{
			disc("CrownBand", 1.9, 0.36, CROWN_GOLD, { 0, TOP_SURFACE + 0.13, TOP_Z }, "Foil"),
			piece("CrownSpike1", { 0.4, 0.55, 0.36 }, CROWN_GOLD, { 0, TOP_SURFACE + 0.58, TOP_Z - 0.75 }, "Foil", {
				shape = "Wedge",
			}),
			piece(
				"CrownSpike2",
				{ 0.4, 0.55, 0.36 },
				CROWN_GOLD,
				{ -0.713, TOP_SURFACE + 0.58, TOP_Z - 0.232 },
				"Foil",
				{ shape = "Wedge", rotation = { 0, 72, 0 } }
			),
			piece(
				"CrownSpike3",
				{ 0.4, 0.55, 0.36 },
				CROWN_GOLD,
				{ 0.713, TOP_SURFACE + 0.58, TOP_Z - 0.232 },
				"Foil",
				{ shape = "Wedge", rotation = { 0, -72, 0 } }
			),
			piece(
				"CrownSpike4",
				{ 0.4, 0.55, 0.36 },
				CROWN_GOLD,
				{ -0.44, TOP_SURFACE + 0.58, TOP_Z + 0.607 },
				"Foil",
				{ shape = "Wedge", rotation = { 0, 144, 0 } }
			),
			piece(
				"CrownSpike5",
				{ 0.4, 0.55, 0.36 },
				CROWN_GOLD,
				{ 0.44, TOP_SURFACE + 0.58, TOP_Z + 0.607 },
				"Foil",
				{ shape = "Wedge", rotation = { 0, -144, 0 } }
			),
			ball("Jewel", 0.32, CROWN_JEWEL, { 0, TOP_SURFACE + 0.13, TOP_Z - 0.95 }, "Glass", {
				effect = "Sparkles",
				effectColor = { 255, 225, 140 },
			}),
			onBack("Ermine", { 1.2, 0.3, 0.1 }, SANTA_FUR, -0.95, "Fabric", {
				effect = "Glow",
				effectColor = { 160, 60, 120 },
			}),
		}
	),
	-- 유니콘 롤: 흰색 + 앞 금빛 나선 뿔(실루엣) + 등줄기 파스텔 갈기 + 라일락 발·분홍 볼, 반짝이·빛
	["unicorn-roll"] = withBase({ foot = MANE_LILAC, cheek = MANE_PINK }, top(UNICORN_WHITE), back(MANE_LILAC), {
		disc("HornBase", 0.5, 0.4, HORN_GOLD, { 0, TOP_SURFACE + 0.18, -0.55 }),
		disc("HornMid", 0.34, 0.4, HORN_GOLD_LIGHT, { 0, TOP_SURFACE + 0.55, -0.57 }),
		piece("HornTip", { 0.36, 0.18, 0.18 }, HORN_GOLD, { 0, TOP_SURFACE + 0.88, -0.59 }, nil, {
			shape = "Cylinder",
			rotation = UPRIGHT,
			effect = "Sparkles",
			effectColor = { 255, 210, 245 },
		}),
		piece("Mane1", { 0.34, 0.55, 0.6 }, MANE_PINK, { 0, TOP_SURFACE + 0.22, 0.15 }, nil, { shape = "Wedge" }),
		piece("Mane2", { 0.34, 0.5, 0.55 }, MANE_MINT, { 0, TOP_SURFACE + 0.2, 0.75 }, nil, { shape = "Wedge" }),
		piece("Mane3", { 0.34, 0.6, 0.5 }, MANE_PINK, { 0, 0.8, BACK_FACE + 0.25 }, nil, {
			shape = "Wedge",
			rotation = { 90, 0, 0 },
		}),
		piece("Mane4", { 0.34, 0.6, 0.5 }, MANE_YELLOW, { 0, 0.25, BACK_FACE + 0.25 }, nil, {
			shape = "Wedge",
			rotation = { 90, 0, 0 },
			effect = "Glow",
			effectColor = { 200, 170, 255 },
		}),
	}),
}

-- 실험 스킨 (m5-27·m5-28): 사용자 콘셉트 시트를 따른 콘셉트 몸. 다른 모양 문법(돔·팔)이라 기준 몸을 공유하지 않아요.
-- 밥·얼굴·팔다리는 모두 같고 토핑만 달라요 (SushiConceptSample).
for id in CONCEPT_IDS do
	LAYOUTS[id] = SushiConceptSample.gameLayout("Default", id)
end

-- Body 중심에서 발바닥까지 (발 공 아래 y = -2.25)
SushiBody.GROUND_OFFSET = 2.25
assert(SushiConceptSample.GAME_GROUND_OFFSET == SushiBody.GROUND_OFFSET, "concept skin feet must match GROUND_OFFSET")

-- 콘셉트 몸 스킨의 명시적 예외 (m5-27·m5-28, m5-32에서 이름을 바꿈). 여기 있는 id만 BASE_NAMES 검사를 건너뛰고,
-- 파츠 상한은 partBudget. 외곽은 boundsTolerance가 있으면 concept-salmon 외곽과 비교해요(m5-32 고등어 — 전설 ±25%),
-- 없으면 비교하지 않아요(특 9종). 효과 예산·발바닥(GROUND_OFFSET)·충돌 없음은 다른 스킨과 똑같아요.
-- 콘셉트 몸 스킨(SushiConceptSample.SKIN_IDS)만 들어가요.
export type ConceptBodyRule = { partBudget: number, expressions: { string }, boundsTolerance: number? }
local conceptBody: { [string]: ConceptBodyRule } = {}
for id in CONCEPT_IDS do
	-- 파츠 상한 70 (m5-30, 사용자 결정 2026-10-14: 토핑 디테일을 위해 47 → 70)
	conceptBody[id] = { partBudget = 70, expressions = SushiConceptSample.EXPRESSIONS :: any }
end
-- m5-32 고등어 [신선]: 파츠 상한 80 (사용자 결정 2026-10-14 3차 — 이 스킨만), 전설 외곽 ±25% (concept-salmon 기준)
conceptBody["fresh-mackerel"] = {
	partBudget = 80,
	expressions = SushiConceptSample.EXPRESSIONS :: any,
	boundsTolerance = 0.25,
}
SushiBody.CONCEPT_BOUNDS_BASE = "concept-salmon" -- boundsTolerance 비교 기준 스킨
SushiBody.CONCEPT_BODY = conceptBody
-- Body 중심에서 이름표까지 (기본 꼭대기 2.07 + 여유, 에픽·전설 장식(최대 약 3.15) 위로도 떠요)
SushiBody.NAME_TAG_HEIGHT = 3.6

-- 모든 스킨이 계란초밥과 크기·위치·회전까지 같은 기준 파츠 (m5-25). 발·볼은 색만 바꿀 수 있어요.
SushiBody.BASE_NAMES = {
	"Body",
	"BodyL",
	"BodyR",
	"BodyBase",
	"BodyBaseL",
	"BodyBaseR",
	"EyeLeft",
	"EyeWhiteLeft",
	"PupilLeft",
	"ShineLeft",
	"LidLeft",
	"EyeRight",
	"EyeWhiteRight",
	"PupilRight",
	"ShineRight",
	"LidRight",
	"Mouth",
	"MouthCover",
	"CheekLeft",
	"CheekRight",
	"FootLeft",
	"FootRight",
}

-- 스킨 하나의 파츠 수 상한 (m5-25: 24명 × 40 = 960, 숨긴 아바타 파츠와 합쳐도 모바일에서 감당할 범위)
SushiBody.PART_BUDGET = 40

-- 등급별 효과(이펙트) 개수 상한 (m5-21). 문자열 키라 Skins.Tier 타입을 몰라도 돼요.
-- 강제는 여기서 안 해요 — effectCount(layout) vs 이 테이블을 비교하는 쪽(Skins.validate, 테스트)의 몫.
SushiBody.EFFECT_BUDGET = {
	Basic = 0,
	Common = 1,
	Rare = 1,
	Epic = 2,
	Legendary = 2,
} :: { [string]: number }

-- 등급별 외곽 상자 허용 비율 (m5-21). bounds() 결과(extents)와 비교하는 쪽의 몫.
SushiBody.BOUNDS_TOLERANCE = {
	Basic = 0,
	Common = 0.15,
	Rare = 0.15,
	Epic = 0.25,
	Legendary = 0.25,
} :: { [string]: number }

-- Glow(점광) 범위·밝기: 캐릭터만 은은하게, 바닥은 덜 물들게 (m5-25, 예전 범위 8·밝기 2)
SushiBody.GLOW_RANGE = 4
SushiBody.GLOW_BRIGHTNESS = 1.2

local function copyList(value: { number }?): { number }?
	return if value then table.clone(value) else nil
end

local function copySpec(spec: PartSpec): PartSpec
	return {
		name = spec.name,
		size = table.clone(spec.size),
		color = table.clone(spec.color),
		material = spec.material,
		offset = table.clone(spec.offset),
		shape = spec.shape,
		rotation = copyList(spec.rotation),
		effect = spec.effect,
		effectColor = copyList(spec.effectColor),
		transparency = spec.transparency,
		joint = spec.joint,
		attach = spec.attach,
		pivot = copyList(spec.pivot),
		reach = copyList(spec.reach),
	}
end

-- 파츠 목록 (복사본이라 고쳐도 원본은 안 바뀌어요)
function SushiBody.layout(appearanceId: string, expression: string?): { PartSpec }
	local source = LAYOUTS[appearanceId] or LAYOUTS[DEFAULT_ID]
	if CONCEPT_IDS[appearanceId] and expression ~= nil then
		source = SushiConceptSample.gameLayout(expression, appearanceId)
	end
	local list = {}
	for _, spec in source do
		table.insert(list, copySpec(spec))
	end
	return list
end

function SushiBody.hasLayout(appearanceId: string): boolean
	return LAYOUTS[appearanceId] ~= nil
end

function SushiBody.effectCount(layout: { PartSpec }): number
	local count = 0
	for _, spec in layout do
		if spec.effect ~= nil then
			count += 1
		end
	end
	return count
end

-- CFrame.Angles(rx, ry, rz) 회전 행렬 = Rx · Ry · Rz (도 단위 입력)
local function rotationMatrix(rotation: { number }?): { { number } }
	if rotation == nil then
		return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	end
	local a, b, c = math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3])
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	return {
		{ cb * cc, -cb * sc, sb },
		{ ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
		{ sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
	}
end

-- 상자들의 전체 외곽 (회전한 파츠는 돌린 상자를 감싸는 축 정렬 상자로)
function SushiBody.bounds(layout: { PartSpec }): Bounds
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, spec in layout do
		local m = rotationMatrix(spec.rotation)
		for axis = 1, 3 do
			local row = m[axis]
			local half = (
				math.abs(row[1]) * spec.size[1]
				+ math.abs(row[2]) * spec.size[2]
				+ math.abs(row[3]) * spec.size[3]
			) / 2
			lo[axis] = math.min(lo[axis], spec.offset[axis] - half)
			hi[axis] = math.max(hi[axis], spec.offset[axis] + half)
		end
	end
	return { min = lo, max = hi }
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

local function angles(rotation: { number }?): CFrame
	if rotation == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

-- 효과 하나 (등급별 예산 이하, m5-21). 작게, 모바일 부담이 적게.
local function addEffect(target: BasePart, effect: Effect, color: { number }?)
	if effect == "Sparkles" then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "SkinEffect"
		sparkles.SparkleColor = rgb(color or { 255, 255, 255 })
		sparkles.Parent = target
	elseif effect == "Fire" then
		-- 작은 불꽃: Fire 오브젝트는 최소 크기(2)가 커서 파티클로 만들어요
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SkinEffect"
		emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
		emitter.Color = ColorSequence.new(rgb(color or { 255, 140, 40 }), Color3.fromRGB(255, 220, 90))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.5, 0.1)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(0.3, 0.5)
		emitter.Rate = 12
		emitter.Speed = NumberRange.new(1.5, 2.5)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = target
	elseif effect == "Smoke" then
		-- 작은 연기: Smoke 오브젝트는 최소 크기가 커서 Fire처럼 파티클로 만들어요 (m5-21)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SkinEffect"
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(rgb(color or { 200, 200, 200 }))
		emitter.LightEmission = 0
		emitter.Size = NumberSequence.new(0.6, 1.4)
		emitter.Transparency = NumberSequence.new(0.4, 1)
		emitter.Lifetime = NumberRange.new(0.6, 1.0)
		emitter.Rate = 10
		emitter.Speed = NumberRange.new(0.8, 1.4)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = target
	elseif effect == "Glow" then
		-- 은은한 빛: 범위를 줄여 캐릭터 둘레만 (m5-25 — 예전엔 바닥을 크게 물들였어요)
		local light = Instance.new("PointLight")
		light.Name = "SkinEffect"
		light.Color = rgb(color or { 255, 255, 255 })
		light.Range = SushiBody.GLOW_RANGE
		light.Brightness = SushiBody.GLOW_BRIGHTNESS
		light.Parent = target
	end
end

-- 레이아웃(파츠 목록)으로 Model을 만들어요. build가 쓰고, 렌더 도구가 포즈를 적용한 레이아웃(posed)을 그릴 때도 써요
function SushiBody.buildLayout(layout: { PartSpec }, modelName: string): Model
	local model = Instance.new("Model")
	model.Name = modelName

	local parts: { [string]: BasePart } = {}
	local specs: { [string]: PartSpec } = {}
	for _, spec in layout do
		specs[spec.name] = spec
		-- 먼저 어떤 클래스를 만들지 나누고(Wedge는 WedgePart, 나머지는 Part), 그다음 Ball/Cylinder만
		-- Enum.PartType .Shape 속성을 설정해요 (m5-21 — WedgePart에는 .Shape가 없어요)
		local part: BasePart
		if spec.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local basePart = Instance.new("Part")
			if spec.shape == "Ball" then
				basePart.Shape = Enum.PartType.Ball
			elseif spec.shape == "Cylinder" then
				basePart.Shape = Enum.PartType.Cylinder
			end
			part = basePart
		end
		part.Name = spec.name
		part.Size = vec(spec.size)
		part.Color = rgb(spec.color)
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
		-- 얼굴 작은 파츠(테두리 안쪽)는 그림자를 안 드리워요 — 눈 위에 지저분한 그림자 방지
		part.CastShadow = spec.attach == nil
		part.Parent = model
		if spec.effect then
			addEffect(part, spec.effect, spec.effectColor)
		end
		parts[spec.name] = part
	end
	local body = parts.Body
	assert(body, "SushiBody layout needs a Body part")

	-- 붙이기: joint면 Motor6D(Body 기준, 클라이언트가 Transform만 바꿔요), attach면 그 파츠에, 나머지는 Body에 용접
	for _, spec in layout do
		local part = parts[spec.name]
		if part == body then
			continue
		end
		if spec.joint then
			-- 관절 사슬 (m5-32): attach가 있으면 그 파츠가 Part0 (없으면 Body)
			local parent = (spec.attach and parts[spec.attach]) or body
			local motor = Instance.new("Motor6D")
			motor.Name = SushiBody.PART_JOINT_NAME
			motor.Part0 = parent
			motor.Part1 = part
			-- C0 = 부모 기준 파츠 자리(회전 포함), C1 = 원점 → Transform이 identity면 레이아웃 자리 그대로.
			-- Transform은 파츠 축 기준이라, 클라이언트는 Body 축 이동을 C0:VectorToObjectSpace로 바꿔 넣어요
			-- (CharacterFxController). Body가 부모면 C0 = 파츠 자리(예전 그대로)
			-- 사슬 부모(고등어 FishRoot·FishMid)는 회전이 없어서 C0 = 위치 차이 · 자기 회전이에요 (회전한 부모면 일반식)
			local parentSpec = if spec.attach then specs[spec.attach] else nil
			motor.C0 = if parent == body
				then part.CFrame
				elseif parentSpec and parentSpec.rotation == nil then CFrame.new(vec({
					spec.offset[1] - parentSpec.offset[1],
					spec.offset[2] - parentSpec.offset[2],
					spec.offset[3] - parentSpec.offset[3],
				})) * angles(spec.rotation)
				else parent.CFrame:Inverse() * part.CFrame
			motor.C1 = CFrame.identity
			-- 경첩·물방울 거리는 속성으로 (클라이언트 FishRig가 읽어요). 테스트용 가짜 Instance에는 SetAttribute가 없을 수 있어요
			if spec.pivot then
				pcall(motor.SetAttribute, motor, "Pivot", vec(spec.pivot))
			end
			if spec.reach then
				pcall(motor.SetAttribute, motor, "Reach", vec(spec.reach))
			end
			motor.Parent = part
		else
			local anchor = (spec.attach and parts[spec.attach]) or body
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.PrimaryPart = body
	return model
end

function SushiBody.build(appearanceId: string, expression: string?): Model
	return SushiBody.buildLayout(SushiBody.layout(appearanceId, expression), `SushiBody_{appearanceId}`)
end

-- 효과(불꽃·반짝이)를 켜고 꺼요. 탈락 연출이 진짜 캐릭터를 로컬로 숨길 때 효과도 같이 숨겨요 (m4-13).
function SushiBody.setEffectsEnabled(root: Instance, enabled: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") or item:IsA("Sparkles") or item:IsA("Fire") or item:IsA("PointLight") then
			(item :: any).Enabled = enabled
		end
	end
end

return SushiBody
