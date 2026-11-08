--!strict
-- "팬트리 선반 대질주"(pantry-shelf-dash, m6-05) 코스 치수·튜닝 값 (Roblox API 없음).
-- 대형 맵(m6-02): 폭 96(선반은 x ±45 안), 스폰 40, 12~40명. 좌표는 origin 기준 — z 0이 출발, 음수가 결승 쪽.
--
-- 흐름: 출발 선반 → 공중에 뜬 나무 선반 섬 5줄(줄 사이 틈 8 — 점프·다이브) → 큰 병뚜껑 결승.
--   줄마다 양옆 벽 환풍기가 옆바람(켜짐 4초 / 꺼짐 2초, 줄마다 반대 방향·어긋난 박자) — 켜질 때 바람 줄무늬가 보여요.
--   2·4번째 줄은 통조림이 결승 쪽 끝에서 출발 쪽(+z)으로 굴러와요.
-- 바닥 높이는 전부 0, 틈으로 떨어지면 낙하선 -12 → Race 부활.

export type Span = { front: number, back: number }
export type Point = { x: number, z: number }
export type Shelf = { index: number, row: number, x: number, width: number }
export type Row = { index: number, front: number, back: number, wind: number, phase: number, cans: boolean }
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number, top: number, name: string }

local Layout = {}

Layout.WIDTH = 96
Layout.HALF = 48
Layout.SHELF_HALF = 45 -- 선반이 놓이는 x 범위
Layout.FLOOR_Y = 0
Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 12
Layout.FOOT_OFFSET = 3
Layout.WALK_SPEED = 16
Layout.CAPACITY = 40
Layout.MIN_PLAYERS = 12

Layout.START = { front = 0, back = -40 } :: Span
Layout.FINISH = { front = -418, back = -500 } :: Span
Layout.FINISH_LINE_Z = -480
Layout.FINISH_WIDTH = 90

-- 줄: wind 1 = +x(오른쪽)로 밂, -1 = 왼쪽. phase = 박자 어긋남(초)
Layout.ROWS = {
	{ index = 1, front = -48, back = -118, wind = 1, phase = 0, cans = false },
	{ index = 2, front = -126, back = -186, wind = -1, phase = 2, cans = true },
	{ index = 3, front = -194, back = -264, wind = 1, phase = 4, cans = false },
	{ index = 4, front = -272, back = -338, wind = -1, phase = 1, cans = true },
	{ index = 5, front = -346, back = -410, wind = 1, phase = 3, cans = false },
} :: { Row }

-- 줄마다 선반 섬 (x 중심, 폭)
Layout.SHELVES = {
	{ index = 1, row = 1, x = -30, width = 26 },
	{ index = 2, row = 1, x = 0, width = 24 },
	{ index = 3, row = 1, x = 30, width = 26 },
	{ index = 4, row = 2, x = -22, width = 40 },
	{ index = 5, row = 2, x = 24, width = 36 },
	{ index = 6, row = 3, x = -34, width = 20 },
	{ index = 7, row = 3, x = 0, width = 30 },
	{ index = 8, row = 3, x = 34, width = 20 },
	{ index = 9, row = 4, x = -20, width = 46 },
	{ index = 10, row = 4, x = 26, width = 34 },
	{ index = 11, row = 5, x = -30, width = 30 },
	{ index = 12, row = 5, x = 6, width = 30 },
	{ index = 13, row = 5, x = 36, width = 18 },
} :: { Shelf }

-- ── 바람 ──────────────────────────────────────────────────────────────
Layout.WIND_PERIOD = 6
Layout.WIND_ON = 4 -- 한 주기 중 앞 4초 켜짐
Layout.WIND_SPEED = 10 -- 옆으로 미는 목표 속도
Layout.WIND_ACCEL = 20
Layout.WIND_HEIGHT = 14 -- 발이 바닥 위 이 높이 안이면 바람을 받아요 (점프 중에도)
Layout.WIND_START_DELAY = 3

-- ── 통조림 ────────────────────────────────────────────────────────────
Layout.CAN_INTERVAL = 2.4
Layout.CAN_SPEED = 14
Layout.CAN_DIAMETER = 5
Layout.CAN_LENGTH = 6 -- x 방향
Layout.CAN_SLOTS = 3 -- 줄·선반마다
Layout.CAN_START_DELAY = 4
Layout.CAN_KNOCK_BACK = 22
Layout.CAN_KNOCK_UP = 12
Layout.CAN_EXEMPT = 1
Layout.CAN_DOWN = 0.5
Layout.HIT_PAD = 1
Layout.HIT_FOOT = 3.5
Layout.HIT_COOLDOWN = 0.8

-- 길이 추정: 직선 + 줄마다 점프 지연 + 바람·통조림
Layout.ROW_DELAY = 1.8
Layout.EXTRA_DELAY = 7

function Layout.rowOf(index: number): Row
	return Layout.ROWS[index]
end

-- 판정 바닥 (출발·선반 섬·결승)
function Layout.floorRects(): { Rect }
	local list: { Rect } = {
		{
			name = "StartShelf",
			minX = -40,
			maxX = 40,
			minZ = Layout.START.back,
			maxZ = Layout.START.front,
			top = Layout.FLOOR_Y,
		},
		{
			name = "FinishLid",
			minX = -Layout.FINISH_WIDTH / 2,
			maxX = Layout.FINISH_WIDTH / 2,
			minZ = Layout.FINISH.back,
			maxZ = Layout.FINISH.front,
			top = Layout.FLOOR_Y,
		},
	}
	for _, shelf in Layout.SHELVES do
		local row = Layout.ROWS[shelf.row]
		table.insert(list, {
			name = string.format("Shelf%02d", shelf.index),
			minX = shelf.x - shelf.width / 2,
			maxX = shelf.x + shelf.width / 2,
			minZ = row.back,
			maxZ = row.front,
			top = Layout.FLOOR_Y,
		})
	end
	return list
end

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
