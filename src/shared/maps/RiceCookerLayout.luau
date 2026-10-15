--!strict
-- "초대형 밥솥"(rice-cooker, m5-36) 치수 (Roblox API 없음, tests/map-rice-cooker.spec.luau).
--
-- 뚜껑을 연 업소용 밥솥 위, 고봉으로 솟은 원형 계단 밥 언덕(5단, 가운데가 높아요). 좌표는 origin 로컬,
-- 언덕 중심은 (CENTER_X, CENTER_Z) — 코스는 origin 앞쪽(로컬 -Z). 반지름 40 밖에는 판정 바닥이 없어요.
--   단  반지름     윗면 y
--   1   0 ~ 12     4   (꼭대기)
--   2   12 ~ 20    3
--   3   20 ~ 28    2
--   4   28 ~ 34    1
--   5   34 ~ 40    0   (가장자리)
--
-- 판정 바닥은 단마다 반지름 방향으로 누운 Block 조각(SEGMENTS개)을 둘러서 만들어요 (Y축 회전만 — 윗면이 평평하고,
-- m5-33 스폰 검사처럼 "파츠 로컬 상자 위"가 그대로 "바닥 위"예요). 조각 바깥 꼭짓점이 반지름 R_out 원 위에
-- 오는 내접 다각형이라 반지름 40 밖으로 나가는 충돌 파츠가 없어요. 조각은 안쪽으로 OVERLAP만큼 더 들어가서
-- 윗단 밑에 묻히고(단 사이 틈 없음), 모두 BASE_Y까지 내려가는 꽉 찬 덩어리예요.
--
--   Layout.TIERS                          단 표 { inner, outer, top }
--   Layout.tierAt(r) -> number?           언덕 중심에서 수평 거리 r의 단 번호 (반지름 40 밖이면 nil)
--   Layout.surfaceAt(r) -> number?        그 자리 윗면 y (반지름 40 밖이면 nil)
--   Layout.surfaceAtXZ(x, z) -> number?   origin 로컬 (x, z)의 윗면 y
--   Layout.segments() -> { Segment }      판정 바닥 조각 전부
--   Layout.spawnOffsets() -> { {x, z} }   스폰 24개 (origin 로컬, 2·3단 위)
--   Layout.BANDS                          증기 띠 중심 z (언덕 중심 기준) 3개

export type Tier = { inner: number, outer: number, top: number }

export type Segment = {
	key: string,
	tier: number,
	x: number, -- 조각 중심 (origin 로컬)
	z: number,
	topY: number,
	length: number, -- 반지름 방향 (Block 로컬 X)
	width: number, -- 둘레 방향 (Block 로컬 Z)
	height: number,
	yaw: number, -- 도. CFrame.Angles(0, rad(yaw), 0): 로컬 X → (cos, 0, -sin)
}

export type Point = { x: number, z: number }

local Layout = {}

-- 언덕 중심 (origin 로컬)
Layout.CENTER_X = 0
Layout.CENTER_Z = -40

Layout.TIERS = {
	{ inner = 0, outer = 12, top = 4 },
	{ inner = 12, outer = 20, top = 3 },
	{ inner = 20, outer = 28, top = 2 },
	{ inner = 28, outer = 34, top = 1 },
	{ inner = 34, outer = 40, top = 0 },
} :: { Tier }

Layout.HILL_RADIUS = 40
Layout.BASE_Y = -3 -- 판정 조각 밑면 (밥솥 안쪽, 테두리 −2보다 낮게 보이는 흰 밥 옆면)
Layout.SEGMENTS = { 20, 28, 36, 40, 48 } -- 단마다 조각 수 (바깥일수록 많아 둘레가 매끈)
Layout.OVERLAP = 1.5 -- 조각이 윗단 밑으로 더 들어가는 길이

-- 밥솥 (장식 기준)
Layout.RIM_TOP_Y = -2 -- 은색 테두리 윗면 (밥 가장자리 0보다 낮게, 가이드 9절)
Layout.RIM_INNER_RADIUS = 41.5
Layout.RIM_OUTER_RADIUS = 45
Layout.POT_RADIUS = 45 -- 몸통 바깥 반지름
Layout.COUNTER_TOP_Y = -30 -- 밥솥이 놓인 작업대 윗면 (낙하선 −20보다 10 아래)

-- 탈락
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이
Layout.FALL_ELIMINATION_Y = -20 -- 루트 로컬 y가 이보다 낮으면 탈락

-- 증기 띠 (언덕 중심 기준 z, 폭 BAND_HALF_WIDTH × 2, x는 ±BAND_HALF_LENGTH)
Layout.BANDS = { -14, 0, 14 }
Layout.BAND_HALF_WIDTH = 5
Layout.BAND_HALF_LENGTH = 42
Layout.VENT_X = 46 -- 증기 밸브 노즐 (언덕 중심 기준 ±x)
Layout.VENT_Y = 3

-- 스폰: 2단(반지름 16)에 8개, 3단(반지름 24)에 16개
Layout.SPAWN_RINGS = { { radius = 16, count = 8, phase = 22.5 }, { radius = 24, count = 16, phase = 0 } }

function Layout.tierAt(r: number): number?
	if r < 0 or r > Layout.HILL_RADIUS then
		return nil
	end
	for i, tier in Layout.TIERS do
		if r < tier.outer then
			return i
		end
	end
	return #Layout.TIERS
end

function Layout.surfaceAt(r: number): number?
	local i = Layout.tierAt(r)
	return if i then Layout.TIERS[i].top else nil
end

-- origin 로컬 (x, z) → 언덕 중심 기준 수평 거리
function Layout.radiusOf(x: number, z: number): number
	local dx, dz = x - Layout.CENTER_X, z - Layout.CENTER_Z
	return math.sqrt(dx * dx + dz * dz)
end

function Layout.surfaceAtXZ(x: number, z: number): number?
	return Layout.surfaceAt(Layout.radiusOf(x, z))
end

function Layout.segments(): { Segment }
	local list: { Segment } = {}
	for tierIndex, tier in Layout.TIERS do
		local n = Layout.SEGMENTS[tierIndex]
		local half = math.pi / n
		local outerFace = tier.outer * math.cos(half) -- 내접 다각형: 꼭짓점이 반지름 outer 위
		local halfWidth = tier.outer * math.sin(half)
		local innerFace = math.max(0, tier.inner - Layout.OVERLAP)
		local length = outerFace - innerFace
		local mid = (outerFace + innerFace) / 2
		local height = tier.top - Layout.BASE_Y
		for i = 0, n - 1 do
			local angle = 360 * i / n
			local rad = math.rad(angle)
			table.insert(list, {
				key = string.format("Rice%d_%02d", tierIndex, i + 1),
				tier = tierIndex,
				x = Layout.CENTER_X + mid * math.cos(rad),
				z = Layout.CENTER_Z - mid * math.sin(rad),
				topY = tier.top,
				length = length,
				width = halfWidth * 2,
				height = height,
				yaw = angle,
			})
		end
	end
	return list
end

-- 조각 윗면 위인지 (origin 로컬 x, z). Y축 회전만 있는 Block이라 로컬 상자로 봐요.
function Layout.onSegment(seg: Segment, x: number, z: number): boolean
	local rad = math.rad(seg.yaw)
	local c, s = math.cos(rad), math.sin(rad)
	local dx, dz = x - seg.x, z - seg.z
	-- 로컬 X = (cos, -sin), 로컬 Z = (sin, cos)
	local lx = dx * c - dz * s
	local lz = dx * s + dz * c
	return math.abs(lx) <= seg.length / 2 and math.abs(lz) <= seg.width / 2
end

-- 조각 꼭짓점 4개 (origin 로컬)
function Layout.segmentCorners(seg: Segment): { Point }
	local rad = math.rad(seg.yaw)
	local c, s = math.cos(rad), math.sin(rad)
	local out: { Point } = {}
	for _, sign in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
		local lx, lz = sign[1] * seg.length / 2, sign[2] * seg.width / 2
		table.insert(out, { x = seg.x + lx * c + lz * s, z = seg.z - lx * s + lz * c })
	end
	return out
end

function Layout.spawnOffsets(): { Point }
	local list: { Point } = {}
	for _, ring in Layout.SPAWN_RINGS do
		for i = 0, ring.count - 1 do
			local rad = math.rad(ring.phase + 360 * i / ring.count)
			table.insert(list, {
				x = Layout.CENTER_X + ring.radius * math.cos(rad),
				z = Layout.CENTER_Z - ring.radius * math.sin(rad),
			})
		end
	end
	return list
end

return Layout
