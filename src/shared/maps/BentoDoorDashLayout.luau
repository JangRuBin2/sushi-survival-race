--!strict
-- "도시락 뚜껑 대탈출"(bento-door-dash, m6-04) 코스 치수·튜닝 값 (Roblox API 없음).
-- 대형 맵(m6-02): 폭 80, 스폰 40, 12~40명. 좌표는 origin 기준 로컬 studs — x: 좌우, y: 위, z: 0이 출발, 음수가 결승 쪽.
-- 바닥은 전부 높이 0이고 양옆에 도시락 벽(높이 10)이 있어 떨어질 곳이 없어요 — 문 줄과 줄 사이 방해로 겨뤄요.
--
-- 구간 (z)                     내용
--   출발         0 ~ -40         스폰 40 (8 × 5)
--   문 줄 1~5    -80 · -160 · -240 · -320 · -400   칸막이 벽(두께 2, 높이 14)에 종이 뚜껑 문 8칸(폭 10, 높이 12)
--                                진짜(깨지는) 문 수 5 → 4 → 4 → 3 → 3, 자리는 라운드마다 서버가 정해요(모두 같아요)
--   방해 1       -88 ~ -152      우메보시가 옆으로 굴러와요 (3줄, 1.6초 간격, 방향 번갈아)
--   방해 2       -168 ~ -232     간장 웅덩이 3개 (반지름 8, 들어가면 속도 9로 줄어요)
--   방해 3       -248 ~ -312     회전 젓가락 막대 (반지름 28, 4초에 한 바퀴, 높이 1.5 — 점프로 넘어요)
--   방해 4       -328 ~ -392     와사비 튕김판 6개 (밟으면 위·앞으로 튕겨요)
--   결승         -440 ~ -500     FinishLine z -480

export type Span = { front: number, back: number }
export type Point = { x: number, z: number }
export type Circle = { index: number, x: number, z: number, radius: number }

local Layout = {}

Layout.WIDTH = 80
Layout.HALF = 40
Layout.FLOOR_THICKNESS = 2
Layout.FLOOR_Y = 0
Layout.FALL_MARGIN = 12
Layout.FOOT_OFFSET = 3
Layout.WALK_SPEED = 16
Layout.CAPACITY = 40
Layout.MIN_PLAYERS = 12

Layout.SIDE_WALL_HEIGHT = 10 -- 점프(약 7.2)로 못 올라가요
Layout.SIDE_WALL_THICKNESS = 2

Layout.START = { front = 0, back = -40 } :: Span
Layout.COURSE = { front = 0, back = -500 } :: Span
Layout.FINISH = { front = -440, back = -500 } :: Span
Layout.FINISH_LINE_Z = -480

-- ── 문 줄 ─────────────────────────────────────────────────────────────
Layout.DOOR_ROWS_Z = { -80, -160, -240, -320, -400 }
Layout.REAL_DOORS = { 5, 4, 4, 3, 3 } -- 줄마다 깨지는 문 수
Layout.DOORS_PER_ROW = 8
Layout.DOOR_WIDTH = 10
Layout.DOOR_HEIGHT = 12
Layout.WALL_THICKNESS = 2
Layout.WALL_HEIGHT = 14 -- 점프(약 7)로 못 넘어요
Layout.DOOR_REACH = 3.5 -- 벽 면에서 루트까지 이 거리 안이면 문에 닿았다고 봐요
Layout.FAKE_KNOCK_BACK = 18
Layout.FAKE_KNOCK_UP = 8
Layout.FAKE_EXEMPT = 0.8
Layout.FAKE_COOLDOWN = 0.8

function Layout.doorX(door: number): number
	return -Layout.HALF + (door - 0.5) * Layout.DOOR_WIDTH
end

-- ── 방해 1: 우메보시 ────────────────────────────────────────────────────
Layout.BALL_ZONE = { front = -88, back = -152 } :: Span
Layout.BALL_Z = { -100, -120, -140 }
Layout.BALL_DIAMETER = 5
Layout.BALL_SPEED = 20
Layout.BALL_INTERVAL = 1.6
Layout.BALL_FROM_X = 44 -- 벽 밖에서 굴러 들어와요 (벽 위를 넘어오는 게 아니라 벽 아래 틈 — 보이기만)
Layout.BALL_SLOTS = 3 -- (88 / 20) / 1.6 ≈ 2.75
Layout.BALL_START_DELAY = 2
Layout.BALL_KNOCK_SIDE = 24
Layout.BALL_KNOCK_UP = 12
Layout.BALL_EXEMPT = 1
Layout.BALL_DOWN = 0.5

-- ── 방해 2: 간장 웅덩이 ─────────────────────────────────────────────────
Layout.SOY_ZONE = { front = -168, back = -232 } :: Span
Layout.PUDDLES = {
	{ index = 1, x = -22, z = -184, radius = 8 },
	{ index = 2, x = 14, z = -198, radius = 8 },
	{ index = 3, x = -4, z = -218, radius = 8 },
} :: { Circle }
Layout.SOY_MAX_SPEED = 9 -- 웅덩이 안 수평 속도 상한
Layout.SOY_ZONE_HEIGHT = 3 -- 발이 바닥 위 이 높이 안이면 웅덩이에 잠겨요

-- ── 방해 3: 회전 젓가락 막대 ────────────────────────────────────────────
Layout.BAR_ZONE = { front = -248, back = -312 } :: Span
Layout.BAR_CENTER = { x = 0, z = -280 } :: Point
Layout.BAR_RADIUS = 28
Layout.BAR_PERIOD = 4 -- 한 바퀴 (위에서 볼 때 시계 방향)
Layout.BAR_HEIGHT = 1.5 -- 막대 중심 높이 (바닥 위)
Layout.BAR_THICKNESS = 2
Layout.BAR_HIT_PAD = 1.2
Layout.BAR_HIT_FOOT = 2.6 -- 발이 바닥 위 이보다 낮으면 맞음
Layout.BAR_KNOCK = 22
Layout.BAR_KNOCK_UP = 12
Layout.BAR_EXEMPT = 1
Layout.BAR_DOWN = 0.5
Layout.BAR_COOLDOWN = 0.8
Layout.HUB_RADIUS = 3 -- 가운데 축 (밟을 수 있는 작은 원기둥)

-- ── 방해 4: 와사비 튕김판 ───────────────────────────────────────────────
Layout.PAD_ZONE = { front = -328, back = -392 } :: Span
Layout.PADS = {
	{ index = 1, x = -26, z = -342, radius = 3.5 },
	{ index = 2, x = 0, z = -340, radius = 3.5 },
	{ index = 3, x = 26, z = -342, radius = 3.5 },
	{ index = 4, x = -13, z = -370, radius = 3.5 },
	{ index = 5, x = 13, z = -370, radius = 3.5 },
	{ index = 6, x = 0, z = -384, radius = 3.5 },
} :: { Circle }
Layout.PAD_TOP = 0.4
Layout.PAD_LAUNCH_UP = 46
Layout.PAD_LAUNCH_FORWARD = 14 -- 결승 쪽(-z)
Layout.PAD_EXEMPT = 1.6
Layout.PAD_COOLDOWN = 1

-- 길이 추정 (빠른 사람): 직선 + 문 줄마다 1.6초 + 방해 구간 지연
Layout.DOOR_DELAY = 1.6
Layout.ZONE_DELAY = { Ball = 2, Soy = 3, Bar = 2, Pad = 0 } :: { [string]: number }

function Layout.spawnPositions(): { Point }
	local list: { Point } = {}
	for row = 1, 5 do
		for col = 1, 8 do
			table.insert(list, { x = -28 + (col - 1) * 8, z = -6 - (row - 1) * 7 })
		end
	end
	return list
end

return Layout
