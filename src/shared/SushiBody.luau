--!strict
-- 초밥 캐릭터 몸. 서버 캐릭터(AppearanceService)와 클라이언트 연출 인형(m3-03 탈락, m3-05 우승)이 같이 써요.
--   layout(appearanceId)  파츠 목록 (순수 함수, lune 테스트 가능). 모르는 id면 기본(tamago).
--   hasLayout(id)         그 id 전용 레이아웃이 있는지 (스킨 카탈로그 Shared.Skins와 맞추는 테스트용)
--   bounds(layout)        파츠 목록 전체 외곽 (순수 함수, Body 중심 기준 min/max, 회전 반영)
--   effectCount(layout)   효과(불꽃·반짝이) 개수
-- 스킨(m4-13): 모든 스킨이 같은 밥 몸통(Body)·눈·입·발을 쓰고 위 토핑만 달라요 (GDD 6). 외곽 상자는 계란초밥의
-- ±15% 안이라 이름표·연출 높이가 같아요 (tests/skins.spec.luau). 판정은 휴머노이드라 스킨과 무관해요.
--   build(appearanceId)   파츠를 만들고 Body에 용접한 Model. PrimaryPart = Body(Anchored). 원점에 있어요 → PivotTo로 옮겨요.
--   GROUND_OFFSET         Body 중심이 땅(발바닥)에서 몇 studs 위인지. 인형을 땅에 세울 때 써요.
--   MODEL_NAME / JOINT_NAME  캐릭터 아래 초밥 Model 이름, HumanoidRootPart에 붙이는 Motor6D 이름
--                         (서버 AppearanceService와 클라이언트 CharacterFxController가 같이 써요)
-- 좌표: Body 중심 기준, 앞 = -Z (눈이 있는 쪽), 위 = +Y. 크기는 지금 휴머노이드 히트박스(약 5 studs)에 맞춰요.
-- 초밥 파츠는 보이기만 해요 (Massless, 충돌·쿼리·터치 없음) — 판정은 휴머노이드 그대로.

local SushiBody = {}

SushiBody.MODEL_NAME = "SushiBody"
SushiBody.JOINT_NAME = "SushiJoint"

export type Shape = "Block" | "Ball" | "Cylinder"
export type Effect = "Fire" | "Sparkles"

-- 파츠 하나. Roblox 자료형 대신 숫자 배열을 써요 (lune 테스트용).
export type PartSpec = {
	name: string,
	size: { number }, -- {x, y, z}
	color: { number }, -- {r, g, b} 0~255
	material: string, -- Enum.Material 이름
	offset: { number }, -- Body 중심 기준 위치 {x, y, z}
	shape: Shape?, -- 없으면 Block. Ball은 크기 세 값이 같아야 해요, Cylinder는 X축 방향 (m4-13)
	rotation: { number }?, -- 도 단위 {x, y, z}, CFrame.Angles 순서 (m4-13)
	effect: Effect?, -- 이 파츠에 붙는 효과 (스킨당 1개 이하, m4-13)
	effectColor: { number }?, -- 효과 색 {r, g, b}
}

export type Bounds = {
	min: { number },
	max: { number },
}

local DEFAULT_ID = "tamago"

local RICE = { 246, 243, 232 }
local RICE_SHADE = { 228, 222, 206 }
local EGG = { 255, 204, 64 }
local NORI = { 28, 34, 30 }
local INK = { 20, 20, 24 }
local MOUTH = { 130, 45, 45 }

-- 세워진 계란초밥: 밥 몸통 + 위·등을 덮는 계란 + 가운데 김 띠 + 앞면 눈·입 + 짧은 발.
-- 바닥(발바닥) y = -2.3, 꼭대기(계란 위) y = 2.4 → 높이 4.7
local TAMAGO: { PartSpec } = {
	{ name = "Body", size = { 2.4, 3.2, 1.8 }, color = RICE, material = "SmoothPlastic", offset = { 0, 0, 0 } },
	{ name = "Egg", size = { 2.8, 0.8, 2.2 }, color = EGG, material = "SmoothPlastic", offset = { 0, 2.0, 0.2 } },
	{ name = "EggBack", size = { 2.6, 1.6, 0.3 }, color = EGG, material = "SmoothPlastic", offset = { 0, 0.9, 1.05 } },
	{ name = "Nori", size = { 2.5, 0.7, 1.9 }, color = NORI, material = "SmoothPlastic", offset = { 0, -0.3, 0 } },
	{
		name = "EyeLeft",
		size = { 0.35, 0.5, 0.1 },
		color = INK,
		material = "SmoothPlastic",
		offset = { -0.5, 1.0, -0.93 },
	},
	{
		name = "EyeRight",
		size = { 0.35, 0.5, 0.1 },
		color = INK,
		material = "SmoothPlastic",
		offset = { 0.5, 1.0, -0.93 },
	},
	{
		name = "Mouth",
		size = { 0.5, 0.12, 0.1 },
		color = MOUTH,
		material = "SmoothPlastic",
		offset = { 0, 0.55, -0.93 },
	},
	{
		name = "FootLeft",
		size = { 0.6, 0.7, 0.8 },
		color = RICE_SHADE,
		material = "SmoothPlastic",
		offset = { -0.6, -1.95, -0.1 },
	},
	{
		name = "FootRight",
		size = { 0.6, 0.7, 0.8 },
		color = RICE_SHADE,
		material = "SmoothPlastic",
		offset = { 0.6, -1.95, -0.1 },
	},
}

---------------------------------------------------------------- 스킨 (m4-13)
-- 계란초밥과 같은 Body·눈·입·발 위에 토핑만 바꿔요. 이름이 같은 파츠는 계란초밥과 같은 값이에요.

local SALMON = { 250, 128, 88 }
local SALMON_FAT = { 255, 236, 220 }
local TUNA = { 178, 30, 48 }
local SHRIMP = { 250, 232, 220 }
local SHRIMP_BAND = { 245, 110, 60 }
local SHRIMP_TAIL = { 230, 60, 40 }
local INARI = { 190, 128, 58 }
local CUCUMBER = { 60, 135, 55 }
local CUCUMBER_CORE = { 165, 210, 110 }
local EEL = { 120, 66, 32 }
local EEL_SAUCE = { 70, 36, 16 }
local UNI = { 245, 165, 40 }
local IKURA = { 255, 95, 30 }
local OCTOPUS = { 230, 180, 205 }
local OCTOPUS_RIM = { 200, 70, 90 }
local AVOCADO = { 130, 175, 70 }
local WHITE_FISH = { 245, 240, 230 }
local SEARED = { 225, 110, 62 }
local CHAR = { 70, 40, 25 }
local EMBER = { 255, 140, 40 }
local TOBIKO = { 255, 120, 40 }
local GOLD = { 255, 196, 60 }
local GOLD_FAT = { 255, 236, 170 }
local DIAMOND = { 150, 220, 255 }
local DRAGON = { 60, 140, 70 }
local DRAGON_DARK = { 35, 100, 50 }
local DRAGON_HORN = { 240, 220, 150 }
local DRAGON_EYE = { 255, 220, 60 }

type Extra = {
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
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
	}
end

-- 계란초밥에서 Body·눈·입·발만 (토핑 없는 밥)
local BASE_NAMES = { Body = true, EyeLeft = true, EyeRight = true, Mouth = true, FootLeft = true, FootRight = true }

local function withBase(toppings: { PartSpec }): { PartSpec }
	local list: { PartSpec } = {}
	for _, spec in TAMAGO do
		if BASE_NAMES[spec.name] then
			table.insert(list, spec)
		end
	end
	for _, spec in toppings do
		table.insert(list, spec)
	end
	return list
end

-- 계란초밥의 계란과 같은 모양: 위 판 + 등을 덮는 판
local function slab(color: { number }, material: string?): { PartSpec }
	return {
		piece("Topping", { 2.8, 0.8, 2.2 }, color, { 0, 2.0, 0.2 }, material),
		piece("ToppingBack", { 2.6, 1.6, 0.3 }, color, { 0, 0.9, 1.05 }, material),
	}
end

-- 계란초밥과 같은 가운데 김 띠
local function noriBelt(): PartSpec
	return piece("Nori", { 2.5, 0.7, 1.9 }, NORI, { 0, -0.3, 0 })
end

-- 토핑 위 비스듬한 줄 3개 (연어 지방, 참치 결)
local function stripes(color: { number }, angle: number, material: string?): { PartSpec }
	local list: { PartSpec } = {}
	for i, x in { -0.8, 0, 0.8 } do
		table.insert(
			list,
			piece(`Stripe{i}`, { 0.14, 0.04, 2.0 }, color, { x, 2.42, 0.2 }, material, { rotation = { 0, angle, 0 } })
		)
	end
	return list
end

-- 군함: 김 벽이 옆·뒤를 감싸고, 앞은 눈 위 테두리와 입 아래 띠만 (얼굴이 보이게)
local function gunkan(): { PartSpec }
	return {
		piece("GunkanBack", { 2.6, 3.9, 0.2 }, NORI, { 0, 0.35, 1.0 }),
		piece("GunkanLeft", { 0.2, 3.9, 2.0 }, NORI, { -1.3, 0.35, 0.1 }),
		piece("GunkanRight", { 0.2, 3.9, 2.0 }, NORI, { 1.3, 0.35, 0.1 }),
		piece("GunkanRim", { 2.6, 0.4, 0.2 }, NORI, { 0, 2.1, -1.0 }),
		piece("GunkanBand", { 2.6, 0.6, 0.2 }, NORI, { 0, -0.4, -1.0 }),
	}
end

-- 군함 위 알갱이 (Ball). positions = {x, z} 아래 층, top = 위 층
local function roe(
	prefix: string,
	color: { number },
	material: string,
	size: number,
	lower: { { number } },
	upper: { { number } }
): { PartSpec }
	local list: { PartSpec } = {}
	local lowerY = 1.6 + size / 2
	for i, xz in lower do
		table.insert(
			list,
			piece(`{prefix}{i}`, { size, size, size }, color, { xz[1], lowerY, xz[2] }, material, { shape = "Ball" })
		)
	end
	for i, xz in upper do
		table.insert(
			list,
			piece(
				`{prefix}Top{i}`,
				{ size, size, size },
				color,
				{ xz[1], lowerY + size * 0.6, xz[2] },
				material,
				{ shape = "Ball" }
			)
		)
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

-- 눕힌 원판: 위를 보는 단면 (Cylinder는 X축 방향이라 Z로 90도 돌려요)
local DISC = { 0, 0, 90 }

local LAYOUTS: { [string]: { PartSpec } } = {
	tamago = TAMAGO,

	-- 일반
	salmon = withBase(join(slab(SALMON), stripes(SALMON_FAT, 30))),
	tuna = withBase(join(slab(TUNA), stripes({ 196, 64, 80 }, -25))),
	shrimp = withBase(join(slab(SHRIMP), {
		piece("ToppingBand1", { 2.82, 0.05, 0.35 }, SHRIMP_BAND, { 0, 2.41, -0.5 }),
		piece("ToppingBand2", { 2.82, 0.05, 0.35 }, SHRIMP_BAND, { 0, 2.41, 0.2 }),
		piece("ToppingBand3", { 2.82, 0.05, 0.35 }, SHRIMP_BAND, { 0, 2.41, 0.9 }),
		piece("TailLeft", { 0.5, 0.6, 0.25 }, SHRIMP_TAIL, { -0.3, 2.35, 1.42 }, nil, { rotation = { 0, 0, 20 } }),
		piece("TailRight", { 0.5, 0.6, 0.25 }, SHRIMP_TAIL, { 0.3, 2.35, 1.42 }, nil, { rotation = { 0, 0, -20 } }),
	})),
	inari = withBase({
		piece("PouchTop", { 2.8, 0.7, 2.2 }, INARI, { 0, 1.95, 0.2 }, "Fabric"),
		piece("PouchBack", { 2.7, 3.2, 0.3 }, INARI, { 0, 0.3, 1.05 }, "Fabric"),
		piece("PouchLeft", { 0.2, 3.0, 1.9 }, INARI, { -1.3, 0.3, 0.1 }, "Fabric"),
		piece("PouchRight", { 0.2, 3.0, 1.9 }, INARI, { 1.3, 0.3, 0.1 }, "Fabric"),
		piece("PouchFold", { 2.0, 0.1, 0.15 }, { 160, 100, 40 }, { 0, 2.33, -0.5 }, "Fabric"),
	}),
	["kappa-maki"] = withBase({
		piece("NoriBack", { 2.6, 3.4, 0.2 }, NORI, { 0, 0.1, 1.0 }),
		piece("NoriLeft", { 0.2, 3.4, 2.0 }, NORI, { -1.3, 0.1, 0.1 }),
		piece("NoriRight", { 0.2, 3.4, 2.0 }, NORI, { 1.3, 0.1, 0.1 }),
		piece("RiceTop", { 2.4, 0.25, 1.8 }, RICE, { 0, 1.725, 0 }),
		piece("Cucumber", { 0.18, 1.2, 1.2 }, CUCUMBER, { 0, 1.88, 0 }, nil, { shape = "Cylinder", rotation = DISC }),
		piece(
			"CucumberCore",
			{ 0.2, 0.8, 0.8 },
			CUCUMBER_CORE,
			{ 0, 1.9, 0 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
	}),

	-- 레어
	eel = withBase(join(slab(EEL), {
		piece("Sauce", { 2.82, 0.06, 2.22 }, EEL_SAUCE, { 0, 2.43, 0.2 }, "Glass"),
		noriBelt(),
	})),
	uni = withBase(join(
		gunkan(),
		roe("Uni", UNI, "SmoothPlastic", 0.7, {
			{ -0.7, -0.45 },
			{ 0, -0.45 },
			{ 0.7, -0.45 },
			{ -0.7, 0.4 },
			{ 0, 0.4 },
			{ 0.7, 0.4 },
		}, { { -0.35, 0 }, { 0.35, 0 } })
	)),
	ikura = withBase(join(
		gunkan(),
		roe("Ikura", IKURA, "Glass", 0.5, {
			{ -0.75, -0.5 },
			{ -0.25, -0.5 },
			{ 0.25, -0.5 },
			{ 0.75, -0.5 },
			{ -0.75, 0.3 },
			{ -0.25, 0.3 },
			{ 0.25, 0.3 },
			{ 0.75, 0.3 },
		}, { { -0.5, -0.1 }, { 0, -0.1 }, { 0.5, -0.1 } })
	)),
	octopus = withBase(join(slab(OCTOPUS), {
		piece("ToppingRim", { 2.82, 0.2, 0.1 }, OCTOPUS_RIM, { 0, 2.0, -0.92 }),
		piece(
			"Sucker1",
			{ 0.08, 0.45, 0.45 },
			OCTOPUS_RIM,
			{ -0.8, 2.42, -0.3 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
		piece(
			"Sucker2",
			{ 0.08, 0.45, 0.45 },
			OCTOPUS_RIM,
			{ 0, 2.42, 0.3 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
		piece(
			"Sucker3",
			{ 0.08, 0.45, 0.45 },
			OCTOPUS_RIM,
			{ 0.8, 2.42, -0.3 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
		piece(
			"Sucker4",
			{ 0.08, 0.45, 0.45 },
			OCTOPUS_RIM,
			{ -0.4, 2.42, 0.9 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
		piece(
			"Sucker5",
			{ 0.08, 0.45, 0.45 },
			OCTOPUS_RIM,
			{ 0.5, 2.42, 0.9 },
			nil,
			{ shape = "Cylinder", rotation = DISC }
		),
		noriBelt(),
	})),

	-- 에픽
	["rainbow-roll"] = withBase({
		piece("Rainbow1", { 2.8, 0.8, 0.44 }, SALMON, { 0, 2.0, -0.68 }),
		piece("Rainbow2", { 2.8, 0.8, 0.44 }, TUNA, { 0, 2.0, -0.24 }),
		piece("Rainbow3", { 2.8, 0.8, 0.44 }, AVOCADO, { 0, 2.0, 0.2 }),
		piece("Rainbow4", { 2.8, 0.8, 0.44 }, WHITE_FISH, { 0, 2.0, 0.64 }),
		piece("Rainbow5", { 2.8, 0.8, 0.44 }, EGG, { 0, 2.0, 1.08 }),
		piece("ToppingBack", { 2.6, 1.6, 0.3 }, AVOCADO, { 0, 0.9, 1.05 }),
		noriBelt(),
	}),
	["aburi-salmon"] = withBase(join(slab(SEARED), {
		piece("Char1", { 0.5, 0.05, 0.4 }, CHAR, { -0.7, 2.42, -0.3 }),
		piece("Char2", { 0.4, 0.05, 0.5 }, CHAR, { 0.4, 2.42, 0.3 }),
		piece("Char3", { 0.6, 0.05, 0.3 }, CHAR, { -0.1, 2.42, 0.9 }),
		piece("Ember", { 0.3, 0.1, 0.3 }, EMBER, { 0.5, 2.45, -0.2 }, "Neon", { effect = "Fire", effectColor = EMBER }),
	})),
	["california-roll"] = withBase({
		piece("Topping", { 2.8, 0.8, 2.2 }, AVOCADO, { 0, 2.0, 0.2 }),
		piece("ToppingBack", { 2.6, 1.6, 0.3 }, TOBIKO, { 0, 0.9, 1.05 }, "Sand"),
		piece("Tobiko", { 2.8, 0.15, 0.4 }, TOBIKO, { 0, 2.47, 1.0 }, "Sand"),
	}),

	-- 전설
	["golden-otoro"] = withBase(join(slab(GOLD, "Foil"), stripes(GOLD_FAT, 30, "Foil"), {
		piece("Shine", { 0.3, 0.05, 0.3 }, GOLD_FAT, { 0, 2.43, 0.2 }, "Foil", {
			effect = "Sparkles",
			effectColor = { 255, 220, 90 },
		}),
	})),
	["diamond-uni"] = withBase(join(
		gunkan(),
		roe("Diamond", DIAMOND, "Glass", 0.7, {
			{ -0.7, -0.45 },
			{ 0, -0.45 },
			{ 0.7, -0.45 },
			{ -0.7, 0.4 },
			{ 0, 0.4 },
			{ 0.7, 0.4 },
		}, { { -0.35, 0 } }),
		{
			piece("DiamondTop2", { 0.7, 0.7, 0.7 }, DIAMOND, { 0.35, 1.95 + 0.42, 0 }, "Glass", {
				shape = "Ball",
				effect = "Sparkles",
				effectColor = { 180, 235, 255 },
			}),
		}
	)),
	["dragon-roll"] = withBase(join(slab(DRAGON), {
		piece("Scale1", { 0.5, 0.15, 0.5 }, DRAGON_DARK, { -0.7, 2.47, -0.3 }),
		piece("Scale2", { 0.5, 0.15, 0.5 }, DRAGON_DARK, { 0.7, 2.47, -0.3 }),
		piece("Scale3", { 0.5, 0.15, 0.5 }, DRAGON_DARK, { 0, 2.47, 0.4 }),
		piece("Scale4", { 0.5, 0.15, 0.5 }, DRAGON_DARK, { -0.7, 2.47, 1.0 }),
		piece("Scale5", { 0.5, 0.15, 0.5 }, DRAGON_DARK, { 0.7, 2.47, 1.0 }),
		piece("Head", { 1.0, 0.6, 0.4 }, DRAGON, { 0, 2.35, -0.8 }),
		piece("HeadEyeLeft", { 0.15, 0.15, 0.05 }, DRAGON_EYE, { -0.25, 2.45, -1.02 }, "Neon"),
		piece("HeadEyeRight", { 0.15, 0.15, 0.05 }, DRAGON_EYE, { 0.25, 2.45, -1.02 }, "Neon"),
		piece("HornLeft", { 0.12, 0.3, 0.12 }, DRAGON_HORN, { -0.3, 2.8, -0.75 }),
		piece("HornRight", { 0.12, 0.3, 0.12 }, DRAGON_HORN, { 0.3, 2.8, -0.75 }),
		piece("Tail", { 0.5, 0.4, 0.25 }, DRAGON_DARK, { 0, 1.9, 1.35 }),
		piece("TailTip", { 0.3, 0.3, 0.2 }, DRAGON, { 0, 2.2, 1.4 }),
	})),
}

-- Body 중심에서 발바닥까지 (TAMAGO 바닥 y = -2.3)
SushiBody.GROUND_OFFSET = 2.3

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
	}
end

-- 파츠 목록 (복사본이라 고쳐도 원본은 안 바뀌어요)
function SushiBody.layout(appearanceId: string): { PartSpec }
	local source = LAYOUTS[appearanceId] or LAYOUTS[DEFAULT_ID]
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

-- 효과 하나 (스킨당 1개 이하). 작게, 모바일 부담이 적게.
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
	end
end

function SushiBody.build(appearanceId: string): Model
	local model = Instance.new("Model")
	model.Name = `SushiBody_{appearanceId}`

	local body: BasePart? = nil
	for _, spec in SushiBody.layout(appearanceId) do
		local part = Instance.new("Part")
		part.Name = spec.name
		if spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Size = vec(spec.size)
		part.Color = rgb(spec.color)
		part.Material = (Enum.Material :: any)[spec.material] :: Enum.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local rotation = spec.rotation
		if rotation then
			part.CFrame = CFrame.new(vec(spec.offset))
				* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
		else
			part.CFrame = CFrame.new(vec(spec.offset))
		end
		part.Anchored = spec.name == "Body"
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Parent = model
		if spec.effect then
			addEffect(part, spec.effect, spec.effectColor)
		end
		if spec.name == "Body" then
			body = part
		end
	end
	assert(body, "SushiBody layout needs a Body part")

	for _, child in model:GetChildren() do
		if child ~= body and child:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
		end
	end

	model.PrimaryPart = body
	return model
end

-- 효과(불꽃·반짝이)를 켜고 꺼요. 탈락 연출이 진짜 캐릭터를 로컬로 숨길 때 효과도 같이 숨겨요 (m4-13).
function SushiBody.setEffectsEnabled(root: Instance, enabled: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") or item:IsA("Sparkles") or item:IsA("Fire") then
			(item :: any).Enabled = enabled
		end
	end
end

return SushiBody
