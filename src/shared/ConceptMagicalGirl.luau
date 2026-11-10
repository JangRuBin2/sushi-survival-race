--!strict
-- 콘셉트 몸 토핑: 오리지널 마법소녀 (m6-09 전설 "마법소녀 스시"). 순수 데이터 (Roblox API 없음).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요.
--   topping()  딸기우유색 분홍 머리(둥근 머리 + 앞머리 + 얼굴 옆 머리카락)가 밥 위를 덮고, 양옆 위에서 민트 리본으로
--              묶은 트윈테일이 어깨 밖으로 늘어져요. 정수리에 작은 노란 별 핀. 등·어깨에는 흰·민트 프릴 짧은 망토(케이프),
--              앞 아래(얼굴 아래)에 분홍 하트 브로치. 오른손(+X)에 별 지팡이 — 노란 별 + 작은 흰 날개 둘 + 분홍 손잡이.
-- 독창 디자인 (스펙 m6-09): 장르(마법소녀)만 가져와요. 특정 작품의 머리 모양·이마 장식·달 모양 지팡이·큰 옷깃·
-- 가슴 큰 리본은 쓰지 않아요 (테스트가 이름을 막아요).
-- 지팡이는 오른팔(ArmRight 관절)에 붙어서(attach) 걷기·숨쉬기 팔 흔들기를 따라가요 — 관절은 늘지 않아요.
-- 파츠 이름은 "Magic"으로 시작해요 — 얼굴(Eye·Mouth·Cheek·Brow…)·공유 몸(Body·Arm·Foot) 이름과 겹치지 않게.
-- 한도 (테스트가 고정): 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면(z −1.35)보다 앞으로 안 나와요 — 앞머리는 y 0.76 위,
-- 옆 머리카락은 x 1.4 바깥, 하트는 y −0.8 아래. 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25), 꼭대기 ≤ 이름표 − 0.4,
-- 효과 2개(전설: 지팡이 별 Glow + 별 끝 Sparkles).

local PartMath = require(script.Parent.PartMath)

local ConceptMagicalGirl = {}

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
		attach = extra and extra.attach,
	}
end

local function ball(name: string, d: number, color: { number }, offset: { number }, material: string?): PartSpec
	return piece(name, { d, d, d }, color, offset, material, { shape = "Ball" })
end

local function add(list: { PartSpec }, group: { PartSpec })
	for _, spec in group do
		table.insert(list, spec)
	end
end

local function sub(a: { number }, b: { number }): { number }
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function scaled(v: { number }, k: number): { number }
	return { v[1] * k, v[2] * k, v[3] * k }
end

local function plus(a: { number }, b: { number }): { number }
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- 축 세 개(열)로 만든 회전 행렬 (행 우선, PartMath.Frame.r과 같은 모양)
local function columns(x: { number }, y: { number }, z: { number }): PartMath.Matrix
	return { { x[1], y[1], z[1] }, { x[2], y[2], z[2] }, { x[3], y[3], z[3] } }
end

-- frame 안의 자리(로컬 점 + 로컬 축 세 개)를 Body 좌표의 offset·rotation(도)으로
local function placed(frame: PartMath.Frame, at: { number }, x: { number }, y: { number }, z: { number })
	local world = PartMath.mul(frame, { p = at, r = columns(x, y, z) })
	return world.p, PartMath.toDegrees(world.r)
end

-- 두 점 사이 원기둥 (Roblox 원기둥 축 = 로컬 X)
local function segment(
	name: string,
	a: { number },
	b: { number },
	d: number,
	color: { number },
	material: string?,
	attach: string?
): PartSpec
	local delta = sub(b, a)
	local length = math.sqrt(delta[1] * delta[1] + delta[2] * delta[2] + delta[3] * delta[3])
	local u = scaled(delta, 1 / length)
	-- X → u 로 보내는 회전: CFrame.Angles(0, ry, rz)의 X축 = (cos rz·cos ry, sin rz, −cos rz·sin ry)
	local rz = math.deg(math.asin(math.clamp(u[2], -1, 1)))
	local ry = math.deg(math.atan2(-u[3], u[1]))
	return piece(name, { length, d, d }, color, scaled(plus(a, b), 0.5), material, {
		shape = "Cylinder",
		rotation = { 0, ry, rz },
		attach = attach,
	})
end

---------------------------------------------------------------- 별 (지팡이·핀)
-- 별 평면 = frame의 로컬 XY, 앞(보는 쪽) = 로컬 Z. 가운데 원판 + 뾰족한 끝 5개.
-- 끝 하나 = 쐐기(WedgePart) 두 장이 축을 맞대 이등변 삼각형 (symmetric), 또는 쐐기 한 장(작은 핀, 바람개비처럼).
-- WedgePart 로컬: 두께 X, 직각 꼭짓점 (−Y, +Z), 뾰족한 끝 (+Y, +Z) → Y = 끝 방향, Z = 옆 방향(반쪽은 −Z 쪽으로 퍼져요)
type StarStyle = {
	prefix: string,
	radius: number, -- 끝까지
	thickness: number,
	color: { number },
	symmetric: boolean,
	effect: Effect?, -- 가운데 원판 효과
	effectColor: { number }?,
	tipEffect: Effect?, -- 위쪽 끝 효과
	tipEffectColor: { number }?,
	attach: string?,
}

local STAR_INNER = 0.42 -- 골짜기 반지름 비율

local function star(frame: PartMath.Frame, style: StarStyle): { PartSpec }
	local r = style.radius
	local inner = r * STAR_INNER
	local rb = inner * math.cos(math.rad(36)) -- 끝 밑변까지 거리
	local w = inner * math.sin(math.rad(36)) -- 끝 밑변 반폭
	local h = r - rb
	local n = { 0, 0, 1 }
	local list: { PartSpec } = {}
	-- 가운데 원판 (축 = 별 앞), 끝보다 조금 두꺼워 앞뒤 면이 끝과 겹치지 않아요
	local at, rotation = placed(frame, { 0, 0, 0 }, n, { 1, 0, 0 }, { 0, 1, 0 })
	table.insert(
		list,
		piece(`{style.prefix}Core`, { style.thickness + 0.04, inner * 2, inner * 2 }, style.color, at, nil, {
			shape = "Cylinder",
			rotation = rotation,
			effect = style.effect,
			effectColor = style.effectColor,
			attach = style.attach,
		})
	)
	for k = 0, 4 do
		local theta = math.rad(90 + 72 * k)
		local u = { math.cos(theta), math.sin(theta), 0 }
		local p = cross(n, u)
		local halves = if style.symmetric then { 1, -1 } else { 1 }
		for index, s in halves do
			local x, z = scaled(n, s), scaled(p, s)
			local d = if style.symmetric then w else w * 2
			-- 직각 꼭짓점 B = 밑변 가운데 (한 장이면 밑변 한쪽 끝으로 옮겨 밑변 전체를 덮어요)
			local base = if style.symmetric then scaled(u, rb) else plus(scaled(u, rb), scaled(p, w))
			local center = plus(plus(base, scaled(u, h / 2)), scaled(z, -d / 2))
			local spot, turn = placed(frame, center, x, u, z)
			local tip = k == 0 and index == 1
			table.insert(
				list,
				piece(
					`{style.prefix}Point{k + 1}{if style.symmetric then (if s > 0 then "A" else "B") else ""}`,
					{ style.thickness, h, d },
					style.color,
					spot,
					nil,
					{
						shape = "Wedge",
						rotation = turn,
						effect = if tip then style.tipEffect else nil,
						effectColor = if tip then style.tipEffectColor else nil,
						attach = style.attach,
					}
				)
			)
		end
	end
	return list
end

-- 별 옆 작은 날개: 쐐기 한 장 (별 평면, 별보다 조금 뒤). 위 변이 축(바깥·위로), 아래 변이 비스듬한 깃
local function wing(frame: PartMath.Frame, name: string, side: number, color: { number }, attach: string?): PartSpec
	local angle = math.rad(if side > 0 then 38 else 142)
	local u = { math.cos(angle), math.sin(angle), 0 }
	local n = { 0, 0, 1 }
	local p = cross(n, u)
	-- 반쪽이 아래(−Y)로 퍼지게: Z = s·p, 퍼지는 쪽 = −Z
	local s = if p[2] > 0 then 1 else -1
	local x, z = scaled(n, s), scaled(p, s)
	local length, width, thick = 0.5, 0.3, 0.07
	local base = plus(scaled(u, 0.2), { 0, -0.04, -0.06 })
	local center = plus(plus(base, scaled(u, length / 2)), scaled(z, -width / 2))
	local at, rotation = placed(frame, center, x, u, z)
	return piece(name, { thick, length, width }, color, at, nil, {
		shape = "Wedge",
		rotation = rotation,
		attach = attach,
	})
end

---------------------------------------------------------------- 색
local HAIR = { 255, 168, 200 } -- 딸기우유 분홍
local HAIR_TAIL = { 250, 150, 190 } -- 트윈테일 (조금 진하게 — 머리와 구분)
local HAIR_BANG = { 252, 156, 194 } -- 앞머리 갈래 (테두리보다 살짝 진해 V가 읽혀요)
local MINT = { 128, 224, 194 }
local CAPE = { 246, 251, 252 } -- 흰 망토 (밥보다 차가운 흰색)
local STAR = { 255, 214, 64 }
local WING = { 255, 255, 255 }
local HANDLE = { 255, 120, 172 }
local HEART = { 255, 82, 150 }
local SPARKLE = { 255, 150, 214 } -- 분홍 별빛
local STAR_GLOW = { 255, 226, 140 }

---------------------------------------------------------------- 치수 (밥: x ±1.8, y −1~1, z ±1.35, 앞 = −Z)
local DOME_D, DOME_HALF, DOME_Y = 2.7, 0.44, 0.62 -- 둥근 머리 (콘셉트 연어 돔과 같은 캡슐, 꼭대기 1.97)
local RIM_Y, RIM_T = 1.06, 0.24 -- 머리 테두리 판 (밥 위 모서리를 덮어요)
local HAND = { 2.0, -0.45, -0.4 } -- 오른손(ArmRight) 가운데 — 콘셉트 몸 팔 자리 (ARM_X·ARM_Y·ARM_Z)
local WAND_TILT = { -14, 0, -16 } -- 지팡이 기울기 (앞으로 14°, 바깥으로 16°) — 별이 얼굴 옆 앞쪽에 와요
-- 앞머리 갈래: 세로 변 x, 퍼지는 쪽(side: +1이면 −X 쪽으로 퍼져요)
local BANG_TOP, BANG_H, BANG_W, BANG_Z = 1.34, 0.56, 0.66, -1.45
local BANGS = {
	{ x = -0.66, side = 1 },
	{ x = -0.66, side = -1 },
	{ x = 0.66, side = 1 },
	{ x = 0.66, side = -1 },
}

local function hair(): { PartSpec }
	local list: { PartSpec } = {
		-- 테두리 판 두 장 (모서리를 깎은 십자): 밥 위끝을 덮어 머리숱처럼 살짝 넘쳐요
		piece("MagicHairRim", { 3.72, RIM_T, 2.0 }, HAIR, { 0, RIM_Y, 0 }),
		piece("MagicHairRimLong", { 2.9, RIM_T, 2.84 }, HAIR, { 0, RIM_Y, 0 }),
		-- 둥근 머리 (축 X 캡슐)
		piece("MagicHairDome", { DOME_HALF * 2, DOME_D, DOME_D }, HAIR, { 0, DOME_Y, 0 }, nil, { shape = "Cylinder" }),
		ball("MagicHairDomeL", DOME_D, HAIR, { -DOME_HALF, DOME_Y, 0 }),
		ball("MagicHairDomeR", DOME_D, HAIR, { DOME_HALF, DOME_Y, 0 }),
	}
	-- 앞머리: 아래로 뾰족한 머리카락 두 갈래 (쐐기 넷, 둘씩 세로 변을 맞대 V 두 개). 아래끝 y 0.78 — 얼굴 영역 위
	-- 쐐기 로컬: Y = 아래(끝 방향), Z = 옆, X = 앞뒤 두께. 직각 꼭짓점 = 위 (세로 변 쪽)
	local front = PartMath.frame({ 0, 0, 0 })
	for i, spike in BANGS do
		local z = { spike.side, 0, 0 }
		local down = { 0, -1, 0 }
		local top = { spike.x, BANG_TOP, BANG_Z }
		local center = plus(plus(top, scaled(down, BANG_H / 2)), scaled(z, -BANG_W / 2))
		local at, rotation = placed(front, center, cross(down, z), down, z)
		table.insert(
			list,
			piece(
				`MagicBang{i}`,
				{ 0.06, BANG_H, BANG_W },
				HAIR_BANG,
				at,
				nil,
				{ shape = "Wedge", rotation = rotation }
			)
		)
	end
	-- 얼굴 옆 머리카락 (밥 앞 모서리, x 1.44 바깥 — 얼굴을 안 가려요)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		table.insert(list, piece(`MagicLock{tag}`, { 0.28, 1.24, 0.32 }, HAIR, { side * 1.6, 0.44, -1.18 }))
	end
	return list
end

local function twinTails(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local root = { side * 1.45, 1.5, 0.25 }
		local bend = { side * 2.24, 0.78, 0.32 }
		local tip = { side * 2.3, -0.42, 0.62 }
		add(list, {
			segment(`MagicTail{tag}1`, root, bend, 0.58, HAIR_TAIL),
			ball(`MagicTail{tag}2`, 0.58, HAIR_TAIL, bend),
			segment(`MagicTail{tag}3`, bend, tip, 0.44, HAIR_TAIL),
		})
		-- 민트 리본: 묶은 자리 바깥에 고리 둘 (앞·뒤로 벌어진 나비 모양)
		for k, dz in { -1, 1 } do
			table.insert(
				list,
				piece(
					`MagicRibbon{tag}{k}`,
					{ 0.16, 0.4, 0.56 },
					MINT,
					{ side * 1.68, 1.48, 0.25 + dz * 0.24 },
					nil,
					{ rotation = { dz * 30, side * 30, side * 20 } }
				)
			)
		end
	end
	return list
end

local function starClip(): { PartSpec }
	-- 정수리 앞 왼쪽(−X)에 선 작은 별 핀 (앞을 봐요)
	return star(PartMath.frame({ -0.62, 1.92, -0.2 }, { 0, 0, 8 }), {
		prefix = "MagicClip",
		radius = 0.26,
		thickness = 0.1,
		color = STAR,
		symmetric = false,
	})
end

local CAPE_PIVOT = { 0, 0.86, 1.39 } -- 망토가 옷깃에서 뒤로 살짝 퍼져요 (아래가 뒤로)
local CAPE_FLARE = { -8, 0, 0 }

local function flared(spec: PartSpec): PartSpec
	local offset, rotation = PartMath.rotateAbout(spec.offset, spec.rotation, CAPE_PIVOT, CAPE_FLARE)
	spec.offset, spec.rotation = offset, rotation
	return spec
end

local function cape(): { PartSpec }
	local list: { PartSpec } = {
		-- 등 판 (흰 천, 짧은 망토) + 위 민트 옷깃 띠 (머리 테두리 바로 아래)
		flared(piece("MagicCape", { 3.4, 1.16, 0.1 }, CAPE, { 0, 0.3, 1.39 })),
		piece("MagicCapeTrim", { 3.5, 0.16, 0.16 }, MINT, { 0, 0.86, 1.4 }),
	}
	-- 아래 프릴: 민트 반원 셋 — 원판 위 반은 등 판 속에 숨고 아래 반만 나와 물결 단이 돼요
	for i, x in { -1.12, 0, 1.12 } do
		table.insert(
			list,
			flared(
				piece(
					`MagicCapeFrill{i}`,
					{ 0.08, 1.1, 1.1 },
					MINT,
					{ x, -0.26, 1.39 },
					"Fabric",
					{ shape = "Cylinder", rotation = { 0, 90, 0 } }
				)
			)
		)
	end
	-- 어깨를 덮는 옆 자락 (팔 위, 등 쪽 절반)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		table.insert(list, piece(`MagicCapeSide{tag}`, { 0.1, 0.66, 1.5 }, CAPE, { side * 1.84, 0.55, 0.64 }, "Fabric"))
	end
	return list
end

local function brooch(): { PartSpec }
	-- 분홍 하트: 45° 돌린 네모 + 위 둥근 원판 둘. 얼굴 아래 (위끝 y −0.81)
	local y = -1.03
	return {
		piece("MagicHeart", { 0.26, 0.26, 0.08 }, HEART, { 0, y, -1.38 }, nil, { rotation = { 0, 0, 45 } }),
		piece("MagicHeartL", { 0.1, 0.26, 0.26 }, HEART, { -0.092, y + 0.092, -1.38 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
		}),
		piece("MagicHeartR", { 0.1, 0.26, 0.26 }, HEART, { 0.092, y + 0.092, -1.38 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
		}),
	}
end

local function wand(): { PartSpec }
	local turn = PartMath.angles(WAND_TILT)
	local dir = { turn[1][2], turn[2][2], turn[3][2] } -- 기운 Y축
	local bottom = plus(HAND, scaled(dir, -0.5))
	local top = plus(HAND, scaled(dir, 1.3))
	local starCenter = plus(HAND, scaled(dir, 1.7))
	local frame = PartMath.frame(starCenter, WAND_TILT)
	local list: { PartSpec } = {
		segment("MagicWandHandle", bottom, top, 0.14, HANDLE, nil, "ArmRight"),
	}
	add(
		list,
		star(frame, {
			prefix = "MagicWandStar",
			radius = 0.5,
			thickness = 0.14,
			color = STAR,
			symmetric = true,
			effect = "Glow",
			effectColor = STAR_GLOW,
			tipEffect = "Sparkles",
			tipEffectColor = SPARKLE,
			attach = "ArmRight",
		})
	)
	table.insert(list, wing(frame, "MagicWandWingL", -1, WING, "ArmRight"))
	table.insert(list, wing(frame, "MagicWandWingR", 1, WING, "ArmRight"))
	return list
end

function ConceptMagicalGirl.topping(): { PartSpec }
	local list: { PartSpec } = {}
	add(list, hair())
	add(list, twinTails())
	add(list, starClip())
	add(list, cape())
	add(list, brooch())
	add(list, wand())
	return list
end

return ConceptMagicalGirl
