--!strict
-- 콘셉트 몸 토핑: 천사와 악마 (m6-10 전설 "천사 스시"·"악마 스시"). 순수 데이터 (Roblox API 없음).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요.
--   angel()  천사 스시: 밥 위 모서리를 두른 금빛 왕관 띠 + 앞 위 금빛 별(분홍 보석) + 작은 뾰족 장식 둘, 머리 위에 떠 있는
--            얇은 금빛 고리, 등 양옆에 흰 깃털 날개, 오른손에 금빛 별 홀(분홍 보석). 얼굴은 보통 귀여운 얼굴 그대로
--   devil()  악마 스시: 짙은 보라 투구(테두리 판 + 윗단 + 보라 보석) + 바깥으로 벌어진 뿔 둘, 얼굴 위(눈썹 위)의 검은
--            바이저 띠에 빨갛게 빛나는 눈 두 줄, 등 양옆에 보라 박쥐 날개, 오른손에 짙은 보라 삼지창(보석)
-- 일반적인 천사·악마 모양만 써요 (특정 작품의 캐릭터·문양 없음). 파츠 이름은 "Angel"·"Devil"로 시작해요 —
-- 얼굴(Eye·Mouth·Cheek·Brow…)·공유 몸(Body·Arm·Foot) 이름과 겹치지 않게.
-- 손에 든 홀·삼지창은 오른팔(ArmRight 관절)에 붙어서(attach) 팔 흔들기를 따라가요 — 관절은 늘지 않아요.
-- 한도 (테스트가 고정): 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면(z −1.35)보다 앞으로 안 나와요 — 왕관 띠·바이저는
-- y 0.76 위. 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25), 꼭대기 ≤ 이름표 − 0.4, 효과 2개(전설).

local PartMath = require(script.Parent.PartMath)

local ConceptAngelDevil = {}

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

local function columns(x: { number }, y: { number }, z: { number }): PartMath.Matrix
	return { { x[1], y[1], z[1] }, { x[2], y[2], z[2] }, { x[3], y[3], z[3] } }
end

-- frame 안의 자리(로컬 점 + 로컬 축 세 개)를 Body 좌표의 offset·rotation(도)으로
local function placed(frame: PartMath.Frame, at: { number }, x: { number }, y: { number }, z: { number })
	local world = PartMath.mul(frame, { p = at, r = columns(x, y, z) })
	return world.p, PartMath.toDegrees(world.r)
end

-- frame 안에 놓은 파츠 (로컬 자리·로컬 회전 도)
local function framed(
	frame: PartMath.Frame,
	name: string,
	size: { number },
	color: { number },
	at: { number },
	turn: { number }?,
	material: string?,
	extra: Extra?
): PartSpec
	local world = PartMath.mul(frame, PartMath.frame(at, turn))
	local spec = piece(name, size, color, world.p, material, extra)
	spec.rotation = PartMath.toDegrees(world.r)
	return spec
end

-- 두 점 사이 원기둥 (Roblox 원기둥 축 = 로컬 X)
local function segment(
	name: string,
	a: { number },
	b: { number },
	d: number,
	color: { number },
	material: string?,
	extra: Extra?
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
		effect = extra and extra.effect,
		effectColor = extra and extra.effectColor,
		attach = extra and extra.attach,
	})
end

-- 평면 삼각형 반쪽 (쐐기 한 장): frame의 로컬 XY 평면, 앞 = 로컬 Z. 직각 꼭짓점 = base, 뾰족한 끝 = base + h·u,
-- 밑변은 u에 수직으로 d만큼 — side가 +1이면 u를 왼쪽(반시계)으로 돌린 쪽의 반대로, −1이면 그쪽으로 퍼져요.
-- WedgePart 로컬: 두께 X, 직각 꼭짓점 (−Y, +Z), 뾰족한 끝 (+Y, +Z)
local function tri(
	frame: PartMath.Frame,
	name: string,
	base: { number },
	angle: number,
	h: number,
	d: number,
	side: number,
	thickness: number,
	color: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local theta = math.rad(angle)
	local u = { math.cos(theta), math.sin(theta), 0 }
	local n = { 0, 0, 1 }
	local p = cross(n, u)
	local x, z = scaled(n, side), scaled(p, side)
	local center = plus(plus(base, scaled(u, h / 2)), scaled(z, -d / 2))
	local at, rotation = placed(frame, center, x, u, z)
	return piece(name, { thickness, h, d }, color, at, material, {
		shape = "Wedge",
		rotation = rotation,
		effect = extra and extra.effect,
		effectColor = extra and extra.effectColor,
		attach = extra and extra.attach,
	})
end

-- 별 (frame 로컬 XY 평면, 앞 = 로컬 Z): 가운데 원판 + 끝 다섯 개(쐐기 두 장씩 이등변)
local STAR_INNER = 0.42
local function star(
	frame: PartMath.Frame,
	prefix: string,
	radius: number,
	thickness: number,
	color: { number },
	coreExtra: Extra?,
	attach: string?
): { PartSpec }
	local inner = radius * STAR_INNER
	local rb = inner * math.cos(math.rad(36))
	local w = inner * math.sin(math.rad(36))
	local at, rotation = placed(frame, { 0, 0, 0 }, { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 })
	local list: { PartSpec } = {
		piece(`{prefix}Core`, { thickness + 0.04, inner * 2, inner * 2 }, color, at, nil, {
			shape = "Cylinder",
			rotation = rotation,
			effect = coreExtra and coreExtra.effect,
			effectColor = coreExtra and coreExtra.effectColor,
			attach = attach,
		}),
	}
	for k = 0, 4 do
		local angle = 90 + 72 * k
		local u = { math.cos(math.rad(angle)), math.sin(math.rad(angle)), 0 }
		for _, s in { 1, -1 } do
			table.insert(
				list,
				tri(
					frame,
					`{prefix}Point{k + 1}{if s > 0 then "A" else "B"}`,
					scaled(u, rb),
					angle,
					radius - rb,
					w,
					s,
					thickness,
					color,
					nil,
					{ attach = attach }
				)
			)
		end
	end
	return list
end

-- 앞을 보는 마름모 보석 (45° 돌린 네모)
local function gem(
	frame: PartMath.Frame,
	name: string,
	size: number,
	depth: number,
	color: { number },
	at: { number },
	material: string?,
	extra: Extra?
): PartSpec
	return framed(frame, name, { size, size, depth }, color, at, { 0, 0, 45 }, material, extra)
end

---------------------------------------------------------------- 공통 치수 (밥: x ±1.8, y −1~1, z ±1.35, 앞 = −Z)
local HAND = { 2.0, -0.45, -0.4 } -- 오른손(ArmRight) 가운데 — 콘셉트 몸 팔 자리 (ARM_X·ARM_Y·ARM_Z)
local HELD_TILT = { -14, 0, -16 } -- 손에 든 홀·삼지창 기울기 (앞으로 14°, 바깥으로 16°)
local ARM = "ArmRight"

local function heldFrame(along: number): (PartMath.Frame, { number })
	local turn = PartMath.angles(HELD_TILT)
	local dir = { turn[1][2], turn[2][2], turn[3][2] }
	return PartMath.frame(plus(HAND, scaled(dir, along)), HELD_TILT), dir
end

-- 날개 자리: 등 옆(밥 옆면 뒤쪽)에서 바깥·위로. 날개 평면은 뒤로 비스듬히(앞·뒤 카메라 둘 다 보여요)
local WING_ROOT = { 1.72, 0.5, 0.85 }
local WING_SWEEP = 22 -- 날개 평면이 뒤로 젖혀진 각

local function wingFrame(side: number, sweep: number?, raise: number?): PartMath.Frame
	-- 로컬 X = 바깥(side), 로컬 Y = 위, 로컬 Z = 날개 앞면 법선
	local back = sweep or WING_SWEEP
	local y = WING_ROOT[2] + (raise or 0)
	local frame = PartMath.frame({ side * WING_ROOT[1], y, WING_ROOT[3] }, { 0, side * -back, 0 })
	if side < 0 then
		-- 왼쪽: 로컬 X가 바깥(−X)을 보게 Y축으로 뒤집어요
		frame = PartMath.mul(frame, PartMath.frame({ 0, 0, 0 }, { 0, 180, 0 }))
	end
	return frame
end

---------------------------------------------------------------- 천사
local GOLD = { 255, 200, 70 }
local GOLD_DEEP = { 236, 170, 48 }
local PINK_GEM = { 255, 120, 200 }
local FEATHER = { 255, 255, 255 }
local FEATHER_SHADE = { 246, 246, 252 }
local HALO_GLOW = { 255, 214, 120 }
local SPARKLE_GOLD = { 255, 242, 196 }

local ANGEL_SWEEP, ANGEL_RAISE = 12, 0.26 -- 천사 날개는 덜 젖히고 조금 높게 — 앞에서도 왕관 옆으로 보여요
local HALO_CENTER, HALO_R, HALO_D, HALO_TILT = { 0, 2.32, 0.1 }, 0.82, 0.12, { -12, 0, 0 }

local function angelCrown(): { PartSpec }
	-- 밥 위 모서리를 두른 금빛 띠 (앞·뒤·옆, 아래끝 y 0.96 — 얼굴 영역 위)
	local list: { PartSpec } = {
		piece("AngelBandFront", { 3.74, 0.24, 0.08 }, GOLD, { 0, 1.08, -1.39 }, "Metal"),
		piece("AngelBandBack", { 3.74, 0.24, 0.08 }, GOLD, { 0, 1.08, 1.39 }, "Metal"),
		piece("AngelBandLeft", { 0.08, 0.22, 2.7 }, GOLD, { -1.83, 1.08, 0 }, "Metal"),
		piece("AngelBandRight", { 0.08, 0.22, 2.7 }, GOLD, { 1.83, 1.08, 0 }, "Metal"),
	}
	-- 앞 위 가운데 큰 별 + 분홍 보석
	local front = PartMath.frame({ 0, 1.5, -1.32 })
	add(list, star(front, "AngelCrownStar", 0.44, 0.14, GOLD))
	table.insert(list, gem(front, "AngelCrownGem", 0.22, 0.08, PINK_GEM, { 0, 0, -0.11 }, "Glass"))
	-- 별 양옆 작은 뾰족 장식 (쐐기 두 장씩, 띠 위에 서요)
	local band = PartMath.frame({ 0, 0, -1.39 })
	for i, x in { -0.9, 0.9 } do
		for _, s in { 1, -1 } do
			table.insert(
				list,
				tri(
					band,
					`AngelCrownSpike{i}{if s > 0 then "A" else "B"}`,
					{ x, 1.18, 0 },
					90,
					0.3,
					0.13,
					s,
					0.08,
					GOLD_DEEP,
					"Metal"
				)
			)
		end
	end
	return list
end

local function halo(): { PartSpec }
	-- 머리 위 얇은 금빛 고리: 원기둥 여덟 개로 만든 팔각 고리 (서로 닿아 이어져요). 하나에 Glow
	local frame = PartMath.frame(HALO_CENTER, HALO_TILT)
	local list: { PartSpec } = {}
	local count = 8
	local stretch = HALO_D * 0.42 -- 모서리 틈을 메우는 여유
	for k = 1, count do
		local a0 = math.rad((k - 1) * 360 / count)
		local a1 = math.rad(k * 360 / count)
		local p0 = PartMath.point(frame, { HALO_R * math.cos(a0), 0, HALO_R * math.sin(a0) })
		local p1 = PartMath.point(frame, { HALO_R * math.cos(a1), 0, HALO_R * math.sin(a1) })
		local dir = sub(p1, p0)
		local len = math.sqrt(dir[1] * dir[1] + dir[2] * dir[2] + dir[3] * dir[3])
		local u = scaled(dir, stretch / len)
		table.insert(
			list,
			segment(`AngelHalo{k}`, sub(p0, u), plus(p1, u), HALO_D, GOLD, "Neon", {
				effect = if k == 1 then "Glow" else nil,
				effectColor = if k == 1 then HALO_GLOW else nil,
			})
		)
	end
	return list
end

local function angelWings(): { PartSpec }
	-- 작은 날개 = 둥근 위쪽(원판 둘, 날개 평면을 봐요) + 아래로 늘어진 깃털 끝 둘(쐐기, 아래 변이 톱니).
	-- 겹치는 면이 같은 평면에 오지 않게 조금씩 뒤로
	local list: { PartSpec } = {}
	local plumes = { { 0.3, 0.34, 0.84 }, { 0.78, 0.66, 0.58 } } -- {x, y, 지름}
	local feathers = { { 0.1, 0.12, -28, 0.78, 0.42 }, { 0.48, 0.42, -6, 0.7, 0.38 } } -- {x, y, 각, 길이, 폭}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local frame = wingFrame(side, ANGEL_SWEEP, ANGEL_RAISE)
		for i, plume in plumes do
			table.insert(
				list,
				framed(
					frame,
					`AngelWing{tag}{i}`,
					{ 0.14, plume[3], plume[3] },
					FEATHER,
					{ plume[1], plume[2], 0.04 * i },
					{ 0, 90, 0 },
					nil,
					{ shape = "Cylinder" }
				)
			)
		end
		for i, f in feathers do
			table.insert(
				list,
				tri(
					frame,
					`AngelFeather{tag}{i}`,
					{ f[1], f[2], -0.03 * i },
					f[3],
					f[4],
					f[5],
					1,
					0.12,
					if i == 1 then FEATHER_SHADE else FEATHER
				)
			)
		end
	end
	return list
end

local function scepter(): { PartSpec }
	local starFrame, dir = heldFrame(1.72)
	local list: { PartSpec } = {
		segment("AngelScepter", plus(HAND, scaled(dir, -0.5)), plus(HAND, scaled(dir, 1.32)), 0.15, GOLD, "Metal", {
			attach = ARM,
		}),
		ball("AngelScepterKnob", 0.24, GOLD_DEEP, plus(HAND, scaled(dir, -0.56)), "Metal"),
	}
	list[2].attach = ARM
	add(
		list,
		star(starFrame, "AngelScepterStar", 0.46, 0.14, GOLD, {
			effect = "Sparkles",
			effectColor = SPARKLE_GOLD,
		}, ARM)
	)
	table.insert(
		list,
		gem(starFrame, "AngelScepterGem", 0.24, 0.08, PINK_GEM, { 0, 0, -0.11 }, "Glass", { attach = ARM })
	)
	return list
end

function ConceptAngelDevil.angel(): { PartSpec }
	local list: { PartSpec } = {}
	add(list, angelCrown())
	add(list, halo())
	add(list, angelWings())
	add(list, scepter())
	return list
end

---------------------------------------------------------------- 악마
local HELM = { 62, 36, 92 } -- 짙은 보라 투구
local HELM_TOP = { 48, 28, 72 }
local HORN = { 74, 44, 110 }
local HORN_TIP = { 196, 110, 255 }
local VISOR = { 24, 20, 32 }
local RED_EYE = { 255, 40, 64 }
local PURPLE_GEM = { 186, 90, 255 }
local BAT_BONE = { 56, 30, 84 }
local BAT_SKIN = { 128, 64, 186 }
local TRIDENT = { 54, 32, 80 }
local SMOKE = { 110, 50, 160 }

local function devilHelmet(): { PartSpec }
	local list: { PartSpec } = {
		-- 테두리 판 두 장 (모서리를 깎은 십자, 밥 위끝을 덮어요) + 윗단
		piece("DevilHelm", { 3.72, 0.3, 2.0 }, HELM, { 0, 1.1, 0 }),
		piece("DevilHelmLong", { 2.9, 0.3, 2.84 }, HELM, { 0, 1.1, 0 }),
		piece("DevilHelmTop", { 2.1, 0.4, 1.86 }, HELM_TOP, { 0, 1.44, 0.05 }),
		-- 얼굴 위(눈썹 위) 검은 바이저 띠 (아래끝 y 0.77 — 얼굴 영역 위) + 빨갛게 빛나는 눈 두 줄 (안쪽이 내려가요)
		piece("DevilVisor", { 2.76, 0.2, 0.06 }, VISOR, { 0, 0.87, -1.37 }, nil, {
			effect = "Glow",
			effectColor = RED_EYE,
		}),
	}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		table.insert(
			list,
			piece(`DevilEye{tag}`, { 0.44, 0.08, 0.04 }, RED_EYE, { side * 0.55, 0.87, -1.405 }, "Neon", {
				rotation = { 0, 0, side * 10 },
			})
		)
	end
	-- 투구 앞 보라 보석 (윗단 앞면)
	local front = PartMath.frame({ 0, 1.42, -0.88 })
	table.insert(list, gem(front, "DevilGem", 0.34, 0.1, PURPLE_GEM, { 0, 0, -0.03 }, "Neon"))
	-- 뿔 둘: 윗단 옆에서 바깥·위로 (아래 굵고 위 가늘게) + 끝 빛 공
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		-- 뾰족한 삼각 뿔 (쐐기 두 장이 축을 맞대요, 앞을 봐요), 바깥으로 기울어요
		local horn = PartMath.frame({ side * 0.72, 1.58, 0.1 })
		local angle = 90 - side * 24
		for k, s in { 1, -1 } do
			table.insert(list, tri(horn, `DevilHorn{tag}{k}`, { 0, 0, 0 }, angle, 1.0, 0.24, s, 0.3, HORN, nil))
		end
	end
	return list
end

local function batWings(): { PartSpec }
	-- 뼈대(원기둥) + 막 셋: 막 하나 = 뼈대 마디 사이 직각삼각형(한 변은 뼈대, 한 변은 뼈대에 수직으로 아래) →
	-- 아래 가장자리가 톱니처럼 뾰족한 박쥐 날개
	local list: { PartSpec } = {}
	local reach, lift = 1.08, 38 -- 뼈대 길이·올라간 각
	local drops = { 0.82, 0.74, 0.56 } -- 마디마다 아래로 늘어진 길이
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local frame = wingFrame(side)
		local boneDir = { math.cos(math.rad(lift)), math.sin(math.rad(lift)), 0 }
		local a = PartMath.point(frame, { -0.1, 0, 0 })
		local b = PartMath.point(frame, scaled(boneDir, reach + 0.06))
		table.insert(list, segment(`DevilWingBone{tag}`, a, b, 0.14, BAT_BONE))
		local step = reach / #drops
		for i, drop in drops do
			local base = plus(scaled(boneDir, step * i), { 0, 0, 0.012 * i })
			table.insert(list, tri(frame, `DevilWing{tag}{i}`, base, lift - 90, drop, step + 0.04, 1, 0.08, BAT_SKIN))
		end
	end
	return list
end

local function trident(): { PartSpec }
	local headFrame, dir = heldFrame(1.3)
	local list: { PartSpec } = {
		segment("DevilTrident", plus(HAND, scaled(dir, -0.5)), plus(HAND, scaled(dir, 1.34)), 0.14, TRIDENT, "Metal", {
			attach = ARM,
		}),
		ball("DevilTridentKnob", 0.22, TRIDENT, plus(HAND, scaled(dir, -0.56)), "Metal"),
		-- 가로대 + 갈래 셋 (가운데가 길어요) + 갈래 끝 마름모
		framed(headFrame, "DevilTridentBar", { 0.66, 0.1, 0.12 }, TRIDENT, { 0, 0, 0 }, nil, "Metal"),
	}
	for i, x in { -0.28, 0, 0.28 } do
		local h = if x == 0 then 0.56 else 0.42
		table.insert(
			list,
			framed(headFrame, `DevilTridentProng{i}`, { 0.08, h, 0.08 }, TRIDENT, { x, h / 2, 0 }, nil, "Metal")
		)
		table.insert(
			list,
			framed(
				headFrame,
				`DevilTridentTip{i}`,
				{ 0.16, 0.16, 0.06 },
				HORN_TIP,
				{ x, h + 0.04, 0 },
				{ 0, 0, 45 },
				"Neon",
				{ effect = if i == 2 then "Smoke" else nil, effectColor = if i == 2 then SMOKE else nil }
			)
		)
	end
	table.insert(list, gem(headFrame, "DevilTridentGem", 0.2, 0.08, PURPLE_GEM, { 0, -0.02, -0.08 }, "Neon"))
	for _, spec in list do
		spec.attach = ARM
	end
	return list
end

function ConceptAngelDevil.devil(): { PartSpec }
	local list: { PartSpec } = {}
	add(list, devilHelmet())
	add(list, batWings())
	add(list, trident())
	return list
end

return ConceptAngelDevil
