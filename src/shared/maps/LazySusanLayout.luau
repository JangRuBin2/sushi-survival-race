--!strict
-- "중식당 회전 원판"(lazy-susan, m6-06) 치수·튜닝 값 (Roblox API 없음).
-- 대형 Survival(m6-02): 스폰 40, 12~40명, 75초(60초부터 서든데스). 좌표는 origin 기준 — 원판 중심이 (0, 0, 0).
--
-- 가운데 고정 유리판(반지름 10) + 고리 4개가 번갈아 반대로 돌아요. 고리 판정 파츠는 10°짜리 조각 36개로 고정이고,
-- 서버가 ① 고리 위 사람을 회전 방향으로 밀어(연속 밀기) 도는 느낌을 주고, ② 고리와 같이 도는 "구멍 구간"에 들어온
-- 조각을 0.8초 빨갛게 예고한 뒤 열어요(충돌 끔·투명). 구멍이 지나가면 조각이 다시 닫혀요 — 구멍이 고리를 따라 움직여요.
-- 고리 위 반찬 그릇(충돌 없음, 서버가 같이 돌려요)에 닿으면 회전 방향으로 밀려나요.
--
-- 진행: 4초부터 구멍 → 20초 고리마다 구멍 +1 → 45초 회전 1.4배 → 60초 서든데스(구멍 폭 40° → 70°)

export type Ring = { index: number, inner: number, outer: number, dir: number, period: number, holes: { number } }
export type Bowl = { index: number, ring: number, offset: number }
export type Point = { x: number, z: number }

local Layout = {}

Layout.CAPACITY = 40
Layout.MIN_PLAYERS = 12
Layout.TIME_LIMIT = 75
Layout.SUDDEN_DEATH_AT = 60
Layout.SPEED_UP_AT = 45
Layout.SPEED_UP = 1.4
Layout.MORE_HOLES_AT = 20
Layout.HOLES_START = 4

Layout.FLOOR_Y = 0
Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 12
Layout.FOOT_OFFSET = 3
Layout.CENTER_RADIUS = 10
Layout.SEGMENTS = 36 -- 고리마다 조각 수 (10°)
Layout.SEGMENT_DEG = 360 / 36

-- 고리: dir 1 = 위에서 볼 때 시계 방향. period = 한 바퀴(초, 빨라지기 전). holes = 구멍 처음 각도(도)들 — 앞 1개는 4초부터,
-- 나머지는 20초부터 열려요. 바깥 고리일수록 구멍이 많아요.
Layout.RINGS = {
	{ index = 1, inner = 10.5, outer = 26, dir = 1, period = 19, holes = { 200 } },
	{ index = 2, inner = 27.5, outer = 44, dir = -1, period = 32, holes = { 20, 200 } },
	{ index = 3, inner = 45.5, outer = 60, dir = 1, period = 42, holes = { 100, 280 } },
	{ index = 4, inner = 61.5, outer = 72, dir = -1, period = 47, holes = { 0, 120, 240 } },
} :: { Ring }
Layout.OUTER_RADIUS = 72

Layout.HOLE_SPAN = 40 -- 구멍 폭(도)
Layout.HOLE_SPAN_SUDDEN = 70
Layout.HOLE_WARN = 0.8 -- 열리기 이만큼 전부터 빨갛게

-- 가운데 유리판: 서든데스(60초)부터 5초마다 0.8초 빨갛게 → 1.5초 열려요 (가운데에 숨어 버티기 방지)
Layout.CENTER_CYCLE = 5
Layout.CENTER_OPEN = 1.5

Layout.PUSH_ACCEL = 18
Layout.PUSH_CAP = 12 -- 접선 목표 속도 상한
Layout.PUSH_ZONE_HEIGHT = 5

-- 반찬 그릇 (고리와 같이 돌아요): offset = 처음 각도(도)
Layout.BOWLS = {
	{ index = 1, ring = 2, offset = 110 },
	{ index = 2, ring = 3, offset = 10 },
	{ index = 3, ring = 3, offset = 190 },
	{ index = 4, ring = 4, offset = 60 },
	{ index = 5, ring = 4, offset = 180 },
	{ index = 6, ring = 4, offset = 300 },
} :: { Bowl }
Layout.BOWL_RADIUS = 3.5
Layout.BOWL_HIT_PAD = 1.5
Layout.BOWL_HIT_FOOT = 3
Layout.BOWL_KNOCK = 18
Layout.BOWL_KNOCK_UP = 8
Layout.BOWL_EXEMPT = 0.8
Layout.BOWL_DOWN = 0.4
Layout.BOWL_COOLDOWN = 0.8

-- 스폰 40개: 고리 1 반지름 18에 12개, 고리 2 반지름 36에 16개, 고리 3 반지름 53에 12개 (구멍은 4초 뒤부터)
function Layout.spawnPositions(): { Point }
	local list: { Point } = {}
	for _, ringSpec in { { r = 18, n = 12, off = 15 }, { r = 36, n = 16, off = 0 }, { r = 53, n = 12, off = 15 } } do
		for k = 0, ringSpec.n - 1 do
			local a = math.rad(ringSpec.off + k * 360 / ringSpec.n)
			table.insert(list, { x = math.cos(a) * ringSpec.r, z = math.sin(a) * ringSpec.r })
		end
	end
	return list
end

-- 조각 k(1..36)의 가운데 각도(도). 0°가 +x, 위에서 볼 때 시계 방향으로 커져요(+z 쪽).
function Layout.segmentAngle(k: number): number
	return (k - 0.5) * Layout.SEGMENT_DEG
end

return Layout
