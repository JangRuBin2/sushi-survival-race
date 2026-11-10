--!strict
-- 콘셉트 몸 토핑: 용 두 마리 (m6-08 전설 "드래곤 스시"·"용 스시", 사용자 시트 docs/드래곤·용 스시 공격 시트.png).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요. 순수 데이터 (Roblox API 없음).
--   dragon()     드래곤 스시: 붉은 서양풍 용이 밥을 덮어요 — 앞 위에 금빛 뿔·수염의 사나운 머리, 등을 타고 뒤로
--                내려가 오른쪽 아래에서 말려 올라가는 꼬리(끝에 불꽃), 금빛 등가시·비늘, 밥 옆을 붙잡은 앞발
--   skyDragon()  용 스시: 파랑·흰색 동양풍 청룡 — 흰 갈기가 부채처럼 펼쳐진 둥근 파란 머리, 흰 뿔, 등을 S자로 감고
--                뒤로 내려가는 긴 뱀 몸(흰 털 등줄기), 꼬리 끝 흰 털 뭉치, 밥 아래 뒤쪽의 흰 구름
-- 일반적인 용 모양만 써요 (특정 작품의 캐릭터·문양 없음). 파츠 이름은 "Dragon"·"Sky"로 시작해요 —
-- 얼굴(Eye·Mouth·Cheek·Brow…)·공유 몸(Body·Arm·Foot) 이름과 겹치지 않게.
-- 한도 (테스트가 고정): 얼굴 높이(밥 앞면 y 0.75 아래)에서 밥 앞면보다 앞으로 안 나오고, 외곽은 concept-salmon × 1.25
-- (X ≤ 5.95, Z ≤ 3.7), 꼭대기 ≤ 이름표 − 0.4, 효과 2개(전설), 관절 없음(움직임은 공유 몸의 깜빡임·팔다리만).

local PartMath = require(script.Parent.PartMath)

local ConceptDragon = {}

type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
type Effect = "Fire" | "Sparkles" | "Smoke" | "Glow"
export type PartSpec = {
	name: string,
	size: { number },
	color: { number },
	material: string,
	offset: { number },
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
	pivot: { number }?,
	reach: { number }?,
}

type Extra = {
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
	transparency: number?,
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
	}
end

local function ball(
	name: string,
	d: number,
	color: { number },
	at: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	e.shape = "Ball"
	return piece(name, { d, d, d }, color, at, material, e)
end

-- 시작점에서 rotation(도)으로 돌린 파츠의 축 방향(shape Cylinder면 로컬 X, 그 밖은 로컬 Y)으로 length만큼 뻗는 막대.
-- 굵기 thick (정사각 단면). 뿔·수염·꼬리 마디처럼 "어디서 시작해 어느 쪽으로" 정하는 파츠
local function beam(
	name: string,
	start: { number },
	rotation: { number },
	length: number,
	thick: number,
	color: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	local m = PartMath.angles(rotation)
	local column = if e.shape == "Cylinder" then 1 else 2
	local dir = { m[1][column], m[2][column], m[3][column] }
	local size = if e.shape == "Cylinder" then { length, thick, thick } else { thick, length, thick }
	e.rotation = rotation
	return piece(name, size, color, {
		start[1] + dir[1] * length / 2,
		start[2] + dir[2] * length / 2,
		start[3] + dir[3] * length / 2,
	}, material, e)
end

-- beam의 끝점 (다음 마디의 시작)
local function tipOf(spec: PartSpec, cylinder: boolean?): { number }
	local m = PartMath.angles(spec.rotation)
	local column = if cylinder then 1 else 2
	local half = (if cylinder then spec.size[1] else spec.size[2]) / 2
	return {
		spec.offset[1] + m[1][column] * half,
		spec.offset[2] + m[2][column] * half,
		spec.offset[3] + m[3][column] * half,
	}
end

-- 두 점을 잇는 마디 (로컬 X축이 from → to). shape 없으면 Block(단면 thick × thick), Cylinder면 둥근 관
local function link(
	name: string,
	from: { number },
	to: { number },
	thick: number,
	color: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	-- R = Ry(b)·Rz(c): 로컬 X → (cos c·cos b, sin c, −cos c·sin b)
	local c = math.asin(dy / length)
	local b = math.atan2(-dz, dx)
	local e: Extra = extra or {}
	e.rotation = { 0, math.deg(b), math.deg(c) }
	return piece(name, { length, thick, thick }, color, {
		(from[1] + to[1]) / 2,
		(from[2] + to[2]) / 2,
		(from[3] + to[3]) / 2,
	}, material, e)
end

-- 쐐기 방향 (WedgePart: 높은 수직면이 로컬 +Z, 경사면이 앞(-Z)·위). 이름은 "꼭짓점이 어디를 보나"
-- 앞을 보는 판(두께 Z)에서 꼭짓점이 바깥·위: side 1 = +X 쪽, -1 = -X 쪽
local function frillRotation(side: number): { number }
	return { 180, -side * 90, 0 }
end

-- pivot을 중심으로 world 회전 turn(도)을 더해요
local function turned(spec: PartSpec, pivot: { number }, turn: { number }): PartSpec
	local offset, rotation = PartMath.rotateAbout(spec.offset, spec.rotation, pivot, turn)
	spec.offset = offset
	spec.rotation = rotation
	return spec
end

local function add(list: { PartSpec }, group: { PartSpec })
	for _, spec in group do
		table.insert(list, spec)
	end
end

-- 점들을 잇는 몸 (마디 + 굽이마다 공 — 꺾여도 이음매가 벌어지지 않게). 마디 i의 굵기 thick[i], 공은 그 굽이 앞 마디 굵기
-- knotColor가 있으면 굽이 공을 조금 크게 그 색으로 (마디마다 고리 무늬 — 뱀 몸이 관처럼 안 보이게)
local function chain(
	prefix: string,
	points: { { number } },
	thick: { number },
	color: { number },
	shape: Shape?,
	knotColor: { number }?
): { PartSpec }
	local list: { PartSpec } = {}
	for i = 1, #points - 1 do
		table.insert(list, link(`{prefix}{i}`, points[i], points[i + 1], thick[i], color, nil, { shape = shape }))
		if i > 1 then
			local d = if knotColor then thick[i] + 0.06 else thick[i]
			table.insert(list, ball(`{prefix}Knot{i}`, d, knotColor or color, points[i]))
		end
	end
	return list
end

---------------------------------------------------------------- 드래곤 스시 (붉은 용)
local RED = { 204, 38, 42 } -- 진홍 비늘
local RED_DEEP = { 168, 26, 34 } -- 그늘진 비늘 (꼬리 쪽)
local MAROON = { 96, 28, 30 } -- 이마 판·주둥이 (시트의 짙은 갈색빛 빨강)
local GOLD = { 255, 192, 58 } -- 등가시·비늘·갈기
local HORN = { 246, 220, 156 } -- 크림빛 금 뿔
local EYE_GOLD = { 255, 214, 50 }
local INK = { 24, 18, 20 }
local FANG = { 255, 250, 236 }

-- 머리 (사자탈처럼 크게): 밥 윗면 앞쪽에 얹혀 밥 앞면 위끝을 0.18 덮어요(아래끝 0.82 — 얼굴 위끝 0.75보다 위),
-- 앞면 z -1.37 (밥 앞면 -1.35보다 조금 앞)
local HEAD = { size = { 2.5, 1.15, 1.5 }, at = { 0, 1.395, -0.62 } }
local HEAD_FRONT = HEAD.at[3] - HEAD.size[3] / 2 -- -1.37
local HEAD_TOP = HEAD.at[2] + HEAD.size[2] / 2 -- 1.97
local HEAD_SIDE = HEAD.size[1] / 2 -- 1.25
local SNOUT_FRONT = HEAD_FRONT - 0.3 -- -1.67

local function dragonHead(): { PartSpec }
	local list: { PartSpec } = {
		piece("DragonHead", HEAD.size, RED, HEAD.at),
		-- 정수리 한 단 (머리 윤곽을 둥글게)
		piece("DragonCrown", { 1.9, 0.2, 1.15 }, RED, { 0, HEAD_TOP + 0.08, -0.6 }),
		-- 주둥이 (짙은 빨강) + 콧구멍 + 송곳니 (y 0.79~0.95, 얼굴 위끝 0.75보다 위)
		piece("DragonSnout", { 1.2, 0.5, 0.32 }, MAROON, { 0, 1.2, HEAD_FRONT - 0.15 }),
		-- 이마 판: 눈 사이 마름모 (시트의 짙은 V자 이마)
		piece("DragonForehead", { 0.52, 0.52, 0.05 }, MAROON, { 0, 1.72, HEAD_FRONT - 0.02 }, nil, {
			rotation = { 0, 0, 45 },
		}),
	}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		add(list, {
			piece(`DragonNostril{tag}`, { 0.16, 0.1, 0.04 }, INK, { side * 0.26, 1.34, SNOUT_FRONT - 0.01 }),
			piece(`DragonFang{tag}`, { 0.12, 0.16, 0.12 }, FANG, { side * 0.36, 0.87, SNOUT_FRONT + 0.1 }, nil, {
				shape = "Wedge",
				rotation = { 180, 0, 0 },
			}),
			-- 사나운 눈: 안쪽이 내려간 금빛 눈 + 세로 동공 + 짙은 눈썹
			piece(`DragonEye{tag}`, { 0.5, 0.28, 0.05 }, EYE_GOLD, { side * 0.66, 1.5, HEAD_FRONT - 0.02 }, "Neon", {
				rotation = { 0, 0, side * 14 },
			}),
			piece(`DragonPupil{tag}`, { 0.09, 0.24, 0.04 }, INK, { side * 0.66, 1.5, HEAD_FRONT - 0.045 }),
			piece(`DragonBrow{tag}`, { 0.64, 0.14, 0.06 }, MAROON, { side * 0.64, 1.76, HEAD_FRONT - 0.02 }, nil, {
				rotation = { 0, 0, side * 22 },
			}),
		})
		-- 뿔: 정수리에서 바깥·위·뒤로 + 가지 둘 (크림빛 금 사슴뿔)
		local horn = beam(
			`DragonHorn{tag}`,
			{ side * 0.62, HEAD_TOP + 0.1, -0.4 },
			{ 28, 0, -side * 14 },
			0.98,
			0.24,
			HORN
		)
		local hornTip = tipOf(horn)
		local mid = {
			(horn.offset[1] + hornTip[1]) / 2,
			(horn.offset[2] + hornTip[2]) / 2,
			(horn.offset[3] + hornTip[3]) / 2,
		}
		add(list, {
			horn,
			beam(`DragonHornFork{tag}`, mid, { 14, 0, -side * 62 }, 0.48, 0.16, HORN),
			beam(`DragonHornFork2{tag}`, horn.offset, { -10, 0, -side * 40 }, 0.4, 0.14, HORN),
		})
		-- 수염: 주둥이 옆에서 바깥·아래로 뻗다가 밥 모서리 바깥에서 아래로 늘어져요 (금빛, 얼굴 밖 x ≥ 1.45)
		local whisker = beam(
			`DragonWhisker{tag}`,
			{ side * 0.58, 1.12, SNOUT_FRONT + 0.12 },
			{ 0, 0, if side > 0 then -16 else 196 },
			1.05,
			0.08,
			GOLD,
			nil,
			{ shape = "Cylinder" }
		)
		local hang = beam(
			`DragonWhiskerTip{tag}`,
			tipOf(whisker, true),
			{ 0, 0, if side > 0 then -78 else 180 + 78 },
			0.5,
			0.07,
			GOLD,
			nil,
			{ shape = "Cylinder" }
		)
		add(list, { whisker, hang })
		-- 갈기 (금빛 불꽃 같은 판 셋): 머리 옆에서 꼭짓점이 바깥·위로, 위에서 아래로 작아져요
		for i, frill in { { 1.85, 1.0, 0.82, 18 }, { 1.4, 0.8, 0.7, -8 }, { 1.0, 0.56, 0.5, -30 } } do
			table.insert(
				list,
				turned(
					piece(
						`DragonFrill{tag}{i}`,
						{ 0.08, frill[2], frill[3] },
						if i == 2 then { 255, 150, 40 } else GOLD,
						{ side * (HEAD_SIDE + frill[3] / 2 - 0.08), frill[1], -0.62 },
						nil,
						{ shape = "Wedge", rotation = frillRotation(side) }
					),
					{ side * (HEAD_SIDE - 0.05), frill[1], -0.62 },
					{ 0, 0, side * frill[4] }
				)
			)
		end
	end
	return list
end

-- 몸통: 머리 뒤 목 → 밥 윗면 → 뒤 모서리를 넘어 등을 비스듬히 내려가 → 아래에서 오른쪽(+X)으로 말려 올라가요
local DRAGON_PATH = {
	{ 0, 1.2, -0.2 },
	{ -0.25, 1.32, 0.75 },
	{ -0.4, 0.95, 1.5 },
	{ 0.1, -0.05, 1.56 },
	{ 0.95, -0.62, 1.56 },
	{ 1.6, -0.2, 1.5 },
}
local DRAGON_THICK = { 0.8, 0.72, 0.6, 0.5, 0.4 }

local function dragonBody(): { PartSpec }
	local list = chain("DragonCoil", DRAGON_PATH, DRAGON_THICK, RED)
	-- 꼬리 끝: 들린 마디 + 금빛 불꽃 털 (Fire) — 꼬리 끝 마디가 따뜻한 빛(Glow)
	local last = DRAGON_PATH[#DRAGON_PATH]
	local tip = link("DragonTailTip", last, { last[1] + 0.2, last[2] + 0.55, last[3] - 0.05 }, 0.32, RED_DEEP, nil, {
		effect = "Glow",
		effectColor = { 255, 150, 60 },
	})
	add(list, {
		ball("DragonTailKnot", 0.4, RED_DEEP, last),
		tip,
		piece(
			"DragonTailFlame",
			{ 0.14, 0.7, 0.56 },
			GOLD,
			{ last[1] + 0.3, last[2] + 0.98, last[3] - 0.06 },
			"Neon",
			{
				shape = "Wedge",
				rotation = { 0, 90, -10 },
				effect = "Fire",
				effectColor = { 255, 150, 40 },
			}
		),
	})
	-- 등가시 (금빛 쐐기, 꼭짓점이 뒤): 목·윗면 위 셋, 뒤 모서리 하나
	local spine = { 0.12, 0.42, 0.46 }
	add(list, {
		piece("DragonSpine1", spine, GOLD, { -0.05, 1.79, 0.15 }, nil, { shape = "Wedge", rotation = { 0, 15, 0 } }),
		piece("DragonSpine2", spine, GOLD, { -0.2, 1.86, 0.62 }, nil, { shape = "Wedge", rotation = { 0, 15, 0 } }),
		turned(
			piece("DragonSpine3", { 0.12, 0.38, 0.42 }, GOLD, { -0.32, 1.6, 1.12 }, nil, { shape = "Wedge" }),
			{ -0.32, 1.3, 1.12 },
			{ 30, 0, 0 }
		),
		turned(
			piece("DragonSpine4", { 0.12, 0.32, 0.36 }, GOLD, { -0.4, 1.36, 1.42 }, nil, { shape = "Wedge" }),
			{ -0.4, 1.05, 1.4 },
			{ 40, 0, 0 }
		),
	})
	-- 금빛 비늘 무늬 (작은 마름모 판, 등 쪽 마디 뒷면에)
	for i, s in { { -0.12, 0.42 }, { 0.42, -0.32 }, { 1.05, -0.43 } } do
		table.insert(
			list,
			piece(`DragonScale{i}`, { 0.2, 0.2, 0.04 }, GOLD, { s[1], s[2], 1.84 }, nil, { rotation = { 0, 0, 45 } })
		)
	end
	return list
end

function ConceptDragon.dragon(): { PartSpec }
	local list = dragonHead()
	add(list, dragonBody())
	return list
end

---------------------------------------------------------------- 용 스시 (파란 청룡)
local BLUE = { 46, 104, 214 }
local BLUE_DEEP = { 28, 62, 150 } -- 비늘 무늬·코
local FUR = { 248, 250, 255 } -- 흰 갈기·털
local SKY_HORN = { 150, 205, 255 } -- 얼음빛 뿔
local SKY_EYE = { 214, 30, 52 }
local CLOUD = { 255, 255, 255 }

-- 둥근 큰 머리 (갈기가 둘레를 부채처럼 감싸요): 아래끝 0.86 (얼굴 위끝 0.75보다 위)
local SKY_HEAD = { size = { 2.0, 1.0, 1.4 }, at = { 0, 1.36, -0.66 } }
local SKY_FRONT = SKY_HEAD.at[3] - SKY_HEAD.size[3] / 2 -- -1.36
local SKY_TOP = SKY_HEAD.at[2] + SKY_HEAD.size[2] / 2 -- 1.86
local SKY_SNOUT_FRONT = SKY_FRONT - 0.32

local function skyHead(): { PartSpec }
	local list: { PartSpec } = {
		piece("SkyHead", SKY_HEAD.size, BLUE, SKY_HEAD.at),
		-- 둥근 정수리 (축 X 원기둥)
		piece("SkyHeadTop", { 1.8, 0.9, 0.9 }, BLUE, { 0, SKY_TOP - 0.2, -0.62 }, nil, { shape = "Cylinder" }),
		piece("SkySnout", { 1.1, 0.44, 0.32 }, BLUE, { 0, 1.14, SKY_FRONT - 0.14 }),
		piece("SkyNose", { 0.56, 0.14, 0.06 }, BLUE_DEEP, { 0, 1.3, SKY_SNOUT_FRONT + 0.01 }),
		-- 흰 콧수염 털 (주둥이 아래, 얼굴 위끝 0.75보다 위)
		piece("SkyBeard", { 0.9, 0.16, 0.22 }, FUR, { 0, 0.86, SKY_FRONT - 0.18 }),
		-- 이마 흰 털 (가운데 위로 솟은 판, 꼭짓점이 뒤)
		piece("SkyCrest", { 0.14, 0.62, 0.66 }, FUR, { 0, SKY_TOP + 0.4, -0.5 }, nil, { shape = "Wedge" }),
	}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		add(list, {
			piece(`SkyEye{tag}`, { 0.44, 0.3, 0.05 }, FUR, { side * 0.5, 1.52, SKY_FRONT - 0.02 }, nil, {
				rotation = { 0, 0, side * 10 },
			}),
			piece(`SkyIris{tag}`, { 0.18, 0.24, 0.04 }, SKY_EYE, { side * 0.45, 1.51, SKY_FRONT - 0.045 }, "Neon"),
			piece(`SkyBrow{tag}`, { 0.54, 0.13, 0.08 }, FUR, { side * 0.52, 1.74, SKY_FRONT - 0.02 }, nil, {
				rotation = { 0, 0, side * 16 },
			}),
		})
		-- 뿔: 뒤로 길게 누운 얼음빛 뿔 + 작은 가지
		local horn = beam(
			`SkyHorn{tag}`,
			{ side * 0.45, SKY_TOP + 0.05, -0.7 },
			{ 40, 0, -side * 14 },
			1.25,
			0.2,
			SKY_HORN
		)
		add(list, {
			horn,
			beam(`SkyHornFork{tag}`, horn.offset, { 30, 0, -side * 55 }, 0.42, 0.14, SKY_HORN),
		})
		-- 흰 갈기: 머리 옆에서 부채처럼 펼쳐진 큰 판 셋 (꼭짓점이 바깥)
		for i, fan in { { 1.82, 34, 1.0, 0.9 }, { 1.42, 4, 1.05, 0.95 }, { 1.0, -28, 0.8, 0.75 } } do
			table.insert(
				list,
				turned(
					piece(
						`SkyMane{tag}{i}`,
						{ 0.1, fan[3], fan[4] },
						FUR,
						{ side * (0.95 + fan[4] / 2), fan[1], -0.55 },
						nil,
						{ shape = "Wedge", rotation = frillRotation(side) }
					),
					{ side * 0.95, fan[1], -0.55 },
					{ 0, 0, side * fan[2] }
				)
			)
		end
		-- 수염: 주둥이 옆에서 바깥으로, 끝이 위로 말려요 (흰색)
		local whisker = beam(
			`SkyWhisker{tag}`,
			{ side * 0.5, 1.06, SKY_SNOUT_FRONT + 0.1 },
			{ 0, 0, if side > 0 then -6 else 186 },
			1.05,
			0.07,
			FUR,
			nil,
			{ shape = "Cylinder" }
		)
		local curl = beam(
			`SkyWhiskerTip{tag}`,
			tipOf(whisker, true),
			{ 0, 0, if side > 0 then 65 else 115 },
			0.42,
			0.06,
			FUR,
			nil,
			{ shape = "Cylinder" }
		)
		add(list, { whisker, curl })
	end
	return list
end

-- 뱀 몸: 머리 뒤에서 밥 윗면을 한 바퀴 감고(오른쪽 → 뒤 → 왼쪽) 왼쪽 뒤 모서리를 넘어 등으로 내려가, 아래에서
-- 오른쪽으로 → 흰 털 꼬리가 구름에 걸쳐요. 윗면 고리 위에는 흰 털 등줄기 (뒤 카메라는 위·뒤에서 내려다봐요)
local SKY_PATH = {
	{ 0.25, 1.3, -0.15 },
	{ 1.15, 1.34, 0.4 },
	{ 0.95, 1.38, 1.12 },
	{ -0.25, 1.4, 1.22 },
	{ -1.1, 1.3, 0.85 },
	{ -1.15, 0.85, 1.55 },
	{ -0.45, 0.0, 1.62 },
	{ 0.45, -0.48, 1.6 },
}
local SKY_THICK = { 0.72, 0.68, 0.64, 0.6, 0.54, 0.48, 0.42 }

local function skyBody(): { PartSpec }
	local list = chain("SkyCoil", SKY_PATH, SKY_THICK, BLUE, "Cylinder", BLUE_DEEP)
	list[1].effect = "Glow"
	list[1].effectColor = { 120, 180, 255 }
	local tailEnd = SKY_PATH[#SKY_PATH]
	add(list, {
		ball("SkyTailTuft", 0.6, FUR, { tailEnd[1] + 0.32, tailEnd[2] + 0.06, tailEnd[3] }, nil, {
			effect = "Sparkles",
			effectColor = { 170, 220, 255 },
		}),
		ball("SkyTailTuft2", 0.42, FUR, { tailEnd[1] + 0.64, tailEnd[2] + 0.26, tailEnd[3] - 0.04 }),
	})
	-- 흰 털 등줄기: 윗면 고리 마디마다 위에 선 쐐기 판 (마디 방향으로 누워 꼭짓점이 꼬리 쪽)
	for i = 1, 4 do
		local from, to = SKY_PATH[i], SKY_PATH[i + 1]
		local yaw = math.deg(math.atan2(to[1] - from[1], to[3] - from[3]))
		local top = (from[2] + to[2]) / 2 + SKY_THICK[i] / 2
		table.insert(
			list,
			piece(`SkyFur{i}`, { 0.14, 0.56, 0.72 }, FUR, {
				(from[1] + to[1]) / 2,
				top + 0.18,
				(from[3] + to[3]) / 2,
			}, nil, { shape = "Wedge", rotation = { 0, yaw, 0 } })
		)
	end
	-- 흰 구름: 꼬리가 올라탄 구름 한 무더기 (밥 뒤 오른쪽 아래) + 왼쪽 뒤 작은 구름
	add(list, {
		ball("SkyCloud1", 0.78, CLOUD, { 1.35, -0.72, 1.42 }),
		ball("SkyCloud2", 0.6, CLOUD, { 1.85, -0.62, 1.15 }),
		ball("SkyCloud3", 0.5, CLOUD, { 0.9, -0.86, 1.6 }),
		ball("SkyCloud4", 0.62, CLOUD, { -1.75, -0.78, 1.2 }),
	})
	return list
end

function ConceptDragon.skyDragon(): { PartSpec }
	local list = skyHead()
	add(list, skyBody())
	return list
end

return ConceptDragon
