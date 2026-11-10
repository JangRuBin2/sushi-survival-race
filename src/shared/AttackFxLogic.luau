--!strict
-- 공격 연출 순수 계산 (m6-08). Roblox API 없이 숫자만 다뤄요 (tests/m6-08-attack.spec.luau).
-- 공격 효과(범위·튕김·넘어짐·쿨다운)는 모두 같고 스킨은 이 연출만 바꿔요 (GDD 9.1). 스킨 id 분기는 STYLE_BY_SKIN 표 하나뿐이에요.
--   styleFor(skinId)                      연출 스타일 (모르는 id·nil은 "RiceBurst")
--   STYLES[style]                         색·길이 (클라이언트 AttackFxController가 그려요)
--   ringRadius(t, radius)                 충격파 고리 반지름 (0~1 시간 → 0~radius, 빨리 퍼지고 느려짐)
--   fade(t)                               투명도 0(보임)~1(사라짐), 끝 40%에서 사라져요
--   missileTargets(origin, hits, radius)  미사일 도착점: 맞은 사람 위치들, 없으면 바깥쪽 4방향
--   missilePoint(from, to, t, arc)        미사일 위치: 위로 휜 2차 베지어 (from → 위 → to)
--   helixPoint(center, i, n, t, radius, height, turns)  불꽃 용·회오리 띠의 i번째 조각 위치
--   bandColor(info, i, n)                 띠 i번째 조각 색 (머리 = accent, alternate면 번갈아)
--   maskPose(seconds)                     전투 마스크 내려옴·유지·올라감 (StyleInfo.mask가 있는 스타일, 사용자 요청 2026-11-10)
--   MASK_PARTS                            마스크 조각 (공격자 Body 기준 오프셋 — 콘셉트 몸 얼굴 아래쪽·입·볼을 덮어요)

local AttackFxLogic = {}

export type Style =
	"RiceBurst"
	| "Flame"
	| "Storm"
	| "Missile"
	| "ShadowMissile"
	| "StarRibbon"
	| "HolyHalo"
	| "DemonFlame"
export type Vec3 = { x: number, y: number, z: number }
export type Rgb = { number } -- {r, g, b} 0~255
export type StyleInfo = {
	duration: number, -- 연출 길이(초)
	ring: Rgb, -- 충격파 고리 색
	accent: Rgb, -- 띠·미사일 꼬리·폭발 색
	particle: Rgb, -- 튀는 조각 색
	band: boolean, -- 감아 오르는 띠(불꽃 용·회오리)를 그리나
	missiles: boolean, -- 쫓아가는 미사일을 쏘나
	spin: number, -- 띠가 도는 바퀴 수 (연출 동안)
	ringSpin: boolean?, -- 고리도 spin만큼 도나 (회오리)
	alternate: boolean?, -- 띠 조각 색을 ring·accent로 번갈아 (별빛 리본, m6-09)
	mask: MaskStyle?, -- 공격하는 동안 얼굴 아래를 덮는 전투 마스크 (제트기 2종, 사용자 요청 2026-11-10 "간지나게")
}

export type MaskStyle = {
	plate: Rgb, -- 가면 판 색
	trim: Rgb, -- 테두리·콧날·눈썹 색
	accent: Rgb, -- 빛나는 눈 구멍·숨구멍 색 (Neon)
}

export type MaskPart = {
	name: string,
	size: { number },
	offset: { number }, -- Body 기준 {x, y, z} (앞 = -Z). 내려온 자리
	color: "plate" | "trim" | "accent",
	neon: boolean?,
	roll: number?, -- 앞에서 볼 때 기울기(도, Z축) — 눈 구멍·눈썹을 사납게
}

-- 스킨 → 연출. 여기 없는 스킨(기본 계란초밥 포함)은 RiceBurst.
AttackFxLogic.STYLE_BY_SKIN = {
	["dragon-sushi"] = "Flame",
	["sky-dragon-sushi"] = "Storm",
	["jet-sushi"] = "Missile",
	["shadow-jet-sushi"] = "ShadowMissile",
	["magical-girl-sushi"] = "StarRibbon", -- m6-09
	["angel-sushi"] = "HolyHalo", -- m6-10
	["devil-sushi"] = "DemonFlame", -- m6-10
} :: { [string]: Style }

AttackFxLogic.STYLES = {
	RiceBurst = {
		duration = 0.6,
		ring = { 255, 250, 240 },
		accent = { 255, 255, 255 },
		particle = { 250, 246, 235 },
		band = false,
		missiles = false,
		spin = 0,
	},
	Flame = {
		duration = 0.9,
		ring = { 255, 150, 40 },
		accent = { 255, 205, 70 },
		particle = { 255, 120, 30 },
		band = true,
		missiles = false,
		spin = 1.25,
	},
	Storm = {
		duration = 0.9,
		ring = { 120, 190, 255 },
		accent = { 225, 245, 255 },
		particle = { 160, 215, 255 },
		band = true,
		missiles = false,
		spin = 2,
		ringSpin = true,
	},
	Missile = {
		duration = 0.9,
		ring = { 235, 240, 250 },
		accent = { 255, 90, 60 },
		particle = { 255, 170, 70 },
		band = false,
		missiles = true,
		spin = 0,
		mask = { plate = { 205, 210, 224 }, trim = { 54, 48, 124 }, accent = { 255, 60, 70 } }, -- 흰·남색 가면, 빨간 눈
	},
	-- m6-09 마법소녀 스시: 분홍 고리 + 분홍·노랑 별 조각이 번갈아 감아 오르는 리본 + 민트 별빛
	StarRibbon = {
		duration = 0.9,
		ring = { 255, 140, 200 },
		accent = { 255, 230, 120 },
		particle = { 170, 245, 220 },
		band = true,
		missiles = false,
		spin = 1.5,
		alternate = true,
	},
	-- m6-10 천사 스시: 금빛 고리(천천히 돎) + 금·흰 깃털빛 조각이 번갈아 감아 오름 + 금 별빛
	HolyHalo = {
		duration = 0.9,
		ring = { 255, 215, 110 },
		accent = { 255, 250, 235 },
		particle = { 255, 235, 150 },
		band = true,
		missiles = false,
		spin = 1,
		ringSpin = true,
		alternate = true,
	},
	-- m6-10 악마 스시: 보라 고리 + 보라 불꽃 띠(머리 빨강)가 빠르게 감아 오름 + 진보라 조각
	DemonFlame = {
		duration = 0.9,
		ring = { 150, 60, 210 },
		accent = { 255, 60, 90 },
		particle = { 90, 30, 140 },
		band = true,
		missiles = false,
		spin = 1.75,
	},
	ShadowMissile = {
		duration = 0.9,
		ring = { 150, 90, 220 },
		accent = { 170, 90, 255 },
		particle = { 120, 60, 200 },
		band = false,
		missiles = true,
		spin = 0,
		mask = { plate = { 52, 50, 64 }, trim = { 110, 56, 170 }, accent = { 255, 40, 60 } }, -- 건메탈·보라 가면, 빨간 눈
	},
} :: { [Style]: StyleInfo }

AttackFxLogic.MAX_MISSILES = 6 -- 맞은 사람이 많아도 미사일은 이만큼만 (가까운 순)
AttackFxLogic.EMPTY_MISSILES = 4 -- 맞은 사람이 없을 때 바깥쪽으로 쏘는 미사일 수
AttackFxLogic.MISSILE_TIME = 0.55 -- 미사일이 날아가는 시간(초)
AttackFxLogic.MISSILE_ARC = 6 -- 미사일이 위로 휘는 높이 (studs)
AttackFxLogic.BAND_PIECES = 12 -- 띠 조각 수

function AttackFxLogic.styleFor(skinId: unknown): Style
	if type(skinId) == "string" then
		local style = AttackFxLogic.STYLE_BY_SKIN[skinId]
		if style then
			return style
		end
	end
	return "RiceBurst"
end

function AttackFxLogic.info(style: Style): StyleInfo
	return AttackFxLogic.STYLES[style] or AttackFxLogic.STYLES.RiceBurst
end

-- 0~1 시간 → 고리 반지름. 처음에 빨리 퍼져요 (ease-out quad)
function AttackFxLogic.ringRadius(t: number, radius: number): number
	local u = math.clamp(t, 0, 1)
	return radius * (1 - (1 - u) * (1 - u))
end

-- 0~1 시간 → 투명도. 처음 60%는 보이고 끝 40%에서 사라져요
function AttackFxLogic.fade(t: number): number
	local u = math.clamp(t, 0, 1)
	if u <= 0.6 then
		return 0
	end
	return math.clamp((u - 0.6) / 0.4, 0, 1)
end

-- 미사일 도착점. 맞은 사람이 있으면 그 위치(최대 MAX_MISSILES), 없으면 origin 둘레 radius 거리 4방향.
function AttackFxLogic.missileTargets(origin: Vec3, hits: { Vec3 }, radius: number): { Vec3 }
	local out: { Vec3 } = {}
	for i, p in hits do
		if i > AttackFxLogic.MAX_MISSILES then
			break
		end
		table.insert(out, { x = p.x, y = p.y, z = p.z })
	end
	if #out > 0 then
		return out
	end
	local n = AttackFxLogic.EMPTY_MISSILES
	for i = 0, n - 1 do
		local angle = (i / n) * math.pi * 2 + math.pi / 4
		table.insert(out, {
			x = origin.x + math.cos(angle) * radius,
			y = origin.y,
			z = origin.z + math.sin(angle) * radius,
		})
	end
	return out
end

-- 미사일 위치: from → (가운데 위 arc) → to 2차 베지어. t는 0~1.
function AttackFxLogic.missilePoint(from: Vec3, to: Vec3, t: number, arc: number): Vec3
	local u = math.clamp(t, 0, 1)
	local cx = (from.x + to.x) / 2
	local cy = math.max(from.y, to.y) + arc
	local cz = (from.z + to.z) / 2
	local a, b, c = (1 - u) * (1 - u), 2 * (1 - u) * u, u * u
	return {
		x = a * from.x + b * cx + c * to.x,
		y = a * from.y + b * cy + c * to.y,
		z = a * from.z + b * cz + c * to.z,
	}
end

-- 전투 가면 (공격자 Body 기준, 콘셉트 몸: 앞면 z -1.35, 밥 y -1.0~1.0, 눈 x ±0.52·y -0.12, 입 y -0.42).
-- 얼굴 전체를 덮는 판(제트기 얼굴 위 띠 0.875 바로 아래까지) + 눈 자리의 빛나는 눈 구멍 + 콧날·숨구멍·테두리.
AttackFxLogic.MASK_PARTS = {
	{ name = "MaskFace", size = { 2.9, 1.5, 0.1 }, offset = { 0, -0.13, -1.43 }, color = "plate" },
	{ name = "MaskRimTop", size = { 2.96, 0.12, 0.14 }, offset = { 0, 0.62, -1.44 }, color = "trim" },
	{ name = "MaskRimBottom", size = { 2.4, 0.1, 0.14 }, offset = { 0, -0.88, -1.44 }, color = "trim" },
	{ name = "MaskRidge", size = { 0.16, 1.1, 0.08 }, offset = { 0, -0.22, -1.51 }, color = "trim" },
	{
		name = "MaskEyeL",
		size = { 0.6, 0.13, 0.04 },
		offset = { -0.55, -0.08, -1.5 },
		color = "accent",
		neon = true,
		roll = -12,
	},
	{
		name = "MaskEyeR",
		size = { 0.6, 0.13, 0.04 },
		offset = { 0.55, -0.08, -1.5 },
		color = "accent",
		neon = true,
		roll = 12,
	},
	{ name = "MaskBrowL", size = { 0.7, 0.1, 0.06 }, offset = { -0.55, 0.12, -1.5 }, color = "trim", roll = -16 },
	{ name = "MaskBrowR", size = { 0.7, 0.1, 0.06 }, offset = { 0.55, 0.12, -1.5 }, color = "trim", roll = 16 },
	{ name = "MaskVentL1", size = { 0.46, 0.06, 0.04 }, offset = { -0.6, -0.55, -1.5 }, color = "accent", neon = true },
	{ name = "MaskVentL2", size = { 0.46, 0.06, 0.04 }, offset = { -0.6, -0.68, -1.5 }, color = "accent", neon = true },
	{ name = "MaskVentR1", size = { 0.46, 0.06, 0.04 }, offset = { 0.6, -0.55, -1.5 }, color = "accent", neon = true },
	{ name = "MaskVentR2", size = { 0.46, 0.06, 0.04 }, offset = { 0.6, -0.68, -1.5 }, color = "accent", neon = true },
} :: { MaskPart }
AttackFxLogic.MASK_DOWN = 0.15 -- 내려오는 시간(초)
AttackFxLogic.MASK_HOLD = 1.1 -- 이때까지 쓰고 있어요(초, 공격 순간부터 — 연출 0.9초보다 조금 길게)
AttackFxLogic.MASK_UP = 0.2 -- 올라가며 사라지는 시간(초)
AttackFxLogic.MASK_RISE = 1.0 -- 숨어 있을 때 위로 올라가 있는 거리 (얼굴 위 띠 쪽에서 내려와요)

-- 공격 뒤 seconds초의 마스크: lift(0 = 제자리, MASK_RISE = 위에 숨음), alpha(1 보임 ~ 0 안 보임), done
function AttackFxLogic.maskPose(seconds: number): (number, number, boolean)
	local down, hold, up = AttackFxLogic.MASK_DOWN, AttackFxLogic.MASK_HOLD, AttackFxLogic.MASK_UP
	local rise = AttackFxLogic.MASK_RISE
	if seconds < 0 then
		return rise, 0, false
	elseif seconds < down then
		local u = seconds / down
		return rise * (1 - u) * (1 - u), math.clamp(u * 2, 0, 1), false -- 툭 내려와 딱 닫혀요 (ease-in)
	elseif seconds < hold then
		return 0, 1, false
	elseif seconds < hold + up then
		local u = (seconds - hold) / up
		return rise * u * u, 1 - u, false
	end
	return rise, 0, true
end

-- 띠 i번째(1..n) 조각 색: 머리(i = n)는 accent, alternate면 짝수 조각도 accent, 나머지는 ring
function AttackFxLogic.bandColor(info: StyleInfo, i: number, n: number): Rgb
	if i == n or (info.alternate == true and i % 2 == 0) then
		return info.accent
	end
	return info.ring
end

-- 띠(불꽃 용·회오리)의 i번째(1..n) 조각: 중심 둘레를 돌며 올라가요. 머리(i = n)가 가장 앞·위.
function AttackFxLogic.helixPoint(
	center: Vec3,
	i: number,
	n: number,
	t: number,
	radius: number,
	height: number,
	turns: number
): Vec3
	local u = math.clamp(t, 0, 1)
	local along = if n <= 1 then 1 else (i - 1) / (n - 1) -- 0 꼬리 ~ 1 머리
	local angle = (u * turns + along * 0.5) * math.pi * 2
	local r = radius * (0.55 + 0.45 * u)
	return {
		x = center.x + math.cos(angle) * r,
		y = center.y + height * (0.15 + 0.85 * along) * (0.4 + 0.6 * u),
		z = center.z + math.sin(angle) * r,
	}
end

return AttackFxLogic
