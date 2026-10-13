--!strict
-- "디저트 냉장고"(dessert-fridge, m5-06) 코스 치수·튜닝 값 (Roblox API 없음).
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(+가 origin.RightVector), y: 위,
-- z: 0이 출발 끝이고 음수로 갈수록 결승.
--
-- 구간 (z)                         바닥 윗면 y   내용
--   A 출발        0 ~ -16           0            일반 바닥 폭 24, 스폰 24개
--   B 얼음 쟁반   -16 ~ -96         0            얼음(Ice 태그) 폭 22, 얼음 큐브 8개 지그재그, 구멍 2개
--   C 젤리 계단   -96 ~ -136        0 → 12      일반 바닥 폭 30. 뒤쪽(z -124 ~ -136)은 위 칸 착지대(y 12, 통짜 블록).
--                                               착지대 바로 앞에 젤리 발판 3개(위로 튕김), 오른쪽에 쿠키 계단(디딤 3)
--   D 찬바람 선반 -136 ~ -216        12           얼음 폭 18, 송풍구 2개(옆으로 밂)
--   E 결승        -216 ~ -260        12           일반 바닥 폭 24, FinishLine z -250
--
-- 스펙 표의 C "바닥 높이 0 → 12"를 "앞쪽 바닥 y 0, 뒤쪽 착지대 y 12"로 나눴어요. 젤리(위 72, 앞 10)로
-- 착지대 앞면을 넘으려면 발판이 착지대 바로 앞에 붙어 있어야 해서(위로 오르는 0.3초 동안 앞으로 몇 studs만 가요)
-- 발판 3개를 착지대 앞에 한 줄로 두고, 그 폭을 위해 C만 폭 30이에요 (개발 메모 참고).

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Point = { x: number, z: number }
export type Step = { index: number, top: number, front: number, back: number }
export type Fan = {
	index: number,
	front: number, -- 밂 구역 z 시작 (출발 쪽)
	back: number, -- 밂 구역 z 끝 (결승 쪽)
	dirX: number, -- +1이면 +X로, -1이면 -X로 밀어요
	offset: number, -- 주기 어긋남 (초)
}

local Layout = {}

Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 25 -- 그 구간 바닥보다 이만큼 아래면 탈락
Layout.LOW_Y = 0 -- A·B·C 앞쪽 바닥 윗면
Layout.HIGH_Y = 12 -- C 착지대·D·E 바닥 윗면

Layout.START = { front = 0, back = -16 } :: Span
Layout.START_WIDTH = 24

Layout.ICE_TRAY = { front = -16, back = -96 } :: Span
Layout.ICE_TRAY_WIDTH = 22

Layout.JELLY_ZONE = { front = -96, back = -136 } :: Span
Layout.JELLY_ZONE_WIDTH = 30
-- 위 칸 착지대 (C 뒤쪽, y 0 ~ 12 통짜 블록 — 아래로 걸어 들어갈 틈이 없어요)
Layout.LANDING = { front = -124, back = -136 } :: Span

Layout.FAN_SHELF = { front = -136, back = -216 } :: Span
Layout.FAN_SHELF_WIDTH = 18

Layout.FINISH = { front = -216, back = -260 } :: Span
Layout.FINISH_WIDTH = 24
Layout.FINISH_LINE_Z = -250

-- B 구간 장애물 (로컬 x, z 중심)
Layout.CUBE_SIZE = 4 -- 얼음 큐브 4 x 4 x 4 (고정, 충돌 있음)
Layout.CUBES = {
	{ x = -6, z = -24 },
	{ x = 6, z = -32 },
	{ x = 5, z = -46 },
	{ x = -6, z = -54 },
	{ x = 6, z = -60 },
	{ x = -5, z = -76 },
	{ x = 6, z = -84 },
	{ x = -6, z = -90 },
} :: { Point }

Layout.HOLE_SIZE = 6 -- 6 x 6 구멍 (바닥이 없어요)
Layout.HOLES = {
	{ x = -5, z = -40 },
	{ x = 5, z = -70 },
} :: { Point }

-- C 구간 젤리 발판 (8 x 8, 윗면 y 1). 착지대 앞면(z -124)에 붙여 한 줄로 3개
Layout.JELLY_SIZE = 8
Layout.JELLY_TOP = 1
Layout.JELLIES = {
	{ x = -11, z = -120 },
	{ x = -3, z = -120 },
	{ x = 5, z = -120 },
} :: { Point }
Layout.JELLY_UP = 72 -- 튕김 위 속도 (studs/s) — g 196.2에서 약 13.2 studs
Layout.JELLY_FORWARD = 10 -- 진행 방향(-Z) 속도
Layout.JELLY_HOLD = 0.15 -- LinearVelocity를 거는 시간 (초)
Layout.JELLY_EXEMPT = 1.5 -- 이동 감시 면제 (초)
Layout.JELLY_COOLDOWN = 0.6 -- 같은 사람 다시 튕기기까지 (초)
Layout.JELLY_ZONE_HEIGHT = 4.5 -- 발판 윗면 위 이 높이 안에 HumanoidRootPart가 있으면 밟은 거예요

-- C 구간 오른쪽 쿠키 계단 (느린 길): 폭 6, 디딤 3씩, 마지막 디딤이 착지대(y 12)
Layout.COOKIE_MIN_X = 9
Layout.COOKIE_MAX_X = 15
Layout.COOKIE_STEP_RISE = 3
Layout.COOKIE_STEP_DEPTH = 4
Layout.COOKIE_STEPS = {
	{ index = 1, top = 3, front = -112, back = -116 },
	{ index = 2, top = 6, front = -116, back = -120 },
	{ index = 3, top = 9, front = -120, back = -124 },
} :: { Step }

-- D 구간 송풍구 (주기 4초: 0.5 경고 → 2 불기 → 1.5 쉼)
Layout.FAN_PERIOD = 4
Layout.FAN_WARN = 0.5
Layout.FAN_BLOW = 2
Layout.FAN_PUSH_SPEED = 14 -- 옆으로 이 속도까지
Layout.FAN_PUSH_ACCEL = 40 -- 가속도 (studs/s^2)
Layout.FAN_ZONE_HEIGHT = 8 -- 바닥 위 이 높이 안이면 바람을 맞아요
Layout.FANS = {
	{ index = 1, front = -150, back = -166, dirX = 1, offset = 0 },
	{ index = 2, front = -186, back = -202, dirX = -1, offset = 2 },
} :: { Fan }

-- 스폰 24개: 6열 x 4줄, 칸 사이 3.5 studs (출발 폭 24 안)
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_SPACING = 3.5

function Layout.spawnPositions(): { Point }
	local list = {}
	for row = 0, Layout.SPAWN_ROWS - 1 do
		for col = 0, Layout.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (Layout.SPAWN_COLUMNS - 1) / 2) * Layout.SPAWN_SPACING,
				z = Layout.START.front - 2.5 - row * Layout.SPAWN_SPACING,
			})
		end
	end
	return list
end

local function rectAround(p: Point, size: number): Rect
	return { minX = p.x - size / 2, maxX = p.x + size / 2, minZ = p.z - size / 2, maxZ = p.z + size / 2 }
end

function Layout.holeRects(): { Rect }
	local list = {}
	for _, hole in Layout.HOLES do
		table.insert(list, rectAround(hole, Layout.HOLE_SIZE))
	end
	return list
end

function Layout.cubeRects(): { Rect }
	local list = {}
	for _, cube in Layout.CUBES do
		table.insert(list, rectAround(cube, Layout.CUBE_SIZE))
	end
	return list
end

function Layout.jellyRects(): { Rect }
	local list = {}
	for _, jelly in Layout.JELLIES do
		table.insert(list, rectAround(jelly, Layout.JELLY_SIZE))
	end
	return list
end

-- B 얼음 쟁반 바닥 조각들 (구멍을 뺀 직사각형들). z 방향으로 띠를 나누고, 구멍이 걸친 띠는 x를 잘라요.
function Layout.iceTrayRects(): { Rect }
	local half = Layout.ICE_TRAY_WIDTH / 2
	local holes = Layout.holeRects()
	local cuts: { number } = { Layout.ICE_TRAY.front, Layout.ICE_TRAY.back }
	for _, hole in holes do
		table.insert(cuts, hole.maxZ)
		table.insert(cuts, hole.minZ)
	end
	table.sort(cuts, function(a: number, b: number): boolean
		return a > b
	end)
	local rects: { Rect } = {}
	for i = 1, #cuts - 1 do
		local maxZ, minZ = cuts[i], cuts[i + 1]
		if maxZ - minZ <= 1e-9 then
			continue
		end
		local midZ = (maxZ + minZ) / 2
		-- 이 띠에 걸친 구멍들의 x 구간을 빼요
		local blocked: { Rect } = {}
		for _, hole in holes do
			if midZ < hole.maxZ and midZ > hole.minZ then
				table.insert(blocked, hole)
			end
		end
		table.sort(blocked, function(a: Rect, b: Rect): boolean
			return a.minX < b.minX
		end)
		local x = -half
		for _, range in blocked do
			if range.minX > x then
				table.insert(rects, { minX = x, maxX = range.minX, minZ = minZ, maxZ = maxZ })
			end
			x = math.max(x, range.maxX)
		end
		if x < half then
			table.insert(rects, { minX = x, maxX = half, minZ = minZ, maxZ = maxZ })
		end
	end
	return rects
end

-- 구간 전체를 z 순서(출발 → 결승)로
function Layout.sections(): { Span }
	return { Layout.START, Layout.ICE_TRAY, Layout.JELLY_ZONE, Layout.FAN_SHELF, Layout.FINISH }
end

return Layout
