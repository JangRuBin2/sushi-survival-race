--!strict
-- "방방 미로" 코스 치수와 튜닝 값, 미로·바운스 판정에 쓰는 순수 계산 (Roblox API 없음, 스펙 m5-14).
-- BouncyCastleMaze.build가 이 표대로 회색 박스를 쌓고, tests/map-bouncy-castle-maze.spec.luau가 치수 약속을
-- 확인해요. 좌표는 origin 기준 로컬 studs예요. x: 좌우(-가 왼쪽), y: 위, z: 0이 출발 끝이고 음수로 갈수록 결승.
-- 바닥 윗면이 y = 0이에요 (A·D·E 구간의 일반 바닥과 B·C 구간의 BounceFloor 모두 같은 높이).
--
-- 코스: A 출발(0~-16, 일반) → B 대기실·관문(-16~-20, BounceFloor, 1번 레인만 열림) →
--       C 미로(-20~-110, BounceFloor, 레인 4개를 칸막이 3개가 S자로 갈라놓음) →
--       D 출구 통로(-110~-120, 일반) →
--       F 두 번째 미로(-120~-176, BounceFloor, 레인 3개 — 오른쪽으로 들어가 왼쪽으로 나가요, m5-40) →
--       G 쉼 통로(-176~-182, 일반) → H 풍선 기둥 숲(-182~-226, BounceFloor, 기둥 줄 4개 지그재그, m5-40) →
--       E 결승(-226~-246, 일반, FinishLine -240).

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)

-- 칸막이: x 위치에서 z [blockedZLow, blockedZHigh] 구간만 막혀 있어요(그 밖은 틈).
export type Partition = {
	x: number,
	thickness: number,
	blockedZHigh: number, -- 막힌 구간의 입구 쪽 끝(0에 더 가까운, 더 큰 값)
	blockedZLow: number, -- 막힌 구간의 결승 쪽 끝(더 작은 값)
}

-- 관문(입구 문): z = gate.z 부근(두께만큼)에서 x가 [openXMin, openXMax] 밖이면 막혀요.
export type Gate = {
	z: number,
	thickness: number,
	openXMin: number,
	openXMax: number,
}

export type Bounds = { xMin: number, xMax: number }

local Layout = {}

-- 공통
Layout.WIDTH = 40 -- 코스 폭 (스펙 고정값)
Layout.HALF_WIDTH = Layout.WIDTH / 2
Layout.FLOOR_THICKNESS = 2
Layout.WALL_HEIGHT = 14 -- 바운스 정점(≈7.7)의 1.5배 이상 (칸막이 뛰어넘기 방지)
Layout.FALL_DEPTH = 40 -- origin보다 이만큼 아래로 떨어지면 탈락 (전 구간 동일)

-- 구간 (z 범위)
Layout.START = { front = 0, back = -16 } :: Span -- A: 일반 바닥, 스폰 24개
Layout.ANTEROOM = { front = -16, back = -20 } :: Span -- B: 대기실(관문), BounceFloor 시작
Layout.MAZE = { front = -20, back = -110 } :: Span -- C: 미로, BounceFloor
Layout.EXIT = { front = -110, back = -120 } :: Span -- D: 출구 통로, 일반 바닥(튕김 끝)
-- m5-40 길이 늘리기: D 뒤에 F·G·H를 끼우고 결승(E)을 뒤로 밀었어요 (전: 결승 -120~-140, FinishLine -134)
Layout.MAZE2 = { front = -120, back = -176 } :: Span -- F: 두 번째 미로, BounceFloor
Layout.LANDING = { front = -176, back = -182 } :: Span -- G: 쉼 통로, 일반 바닥(튕김 잠깐 끝)
Layout.FOREST = { front = -182, back = -226 } :: Span -- H: 풍선 기둥 숲, BounceFloor
Layout.FINISH = { front = -226, back = -246 } :: Span -- E: 결승
Layout.FINISH_LINE_Z = -240
Layout.FINISH_LINE_INSET = Layout.FINISH.front - Layout.FINISH_LINE_Z -- 결승 구간 안, 넘은 뒤 서 있을 자리

function Layout.totalLength(): number
	return Layout.START.front - Layout.FINISH.back
end

function Layout.finishLineZ(): number
	return Layout.FINISH_LINE_Z
end

-- 레인 4개 (x 중심), 레인 폭은 전부 LANE_WIDTH
Layout.LANE_WIDTH = 10
Layout.LANES = { -15, -5, 5, 15 }

-- 칸막이 3개: 1·2레인 사이(x -10, 틈은 출구 쪽 z -100~-110),
-- 2·3레인 사이(x 0, 틈은 입구 쪽 z -20~-30), 3·4레인 사이(x 10, 틈은 출구 쪽 z -100~-110).
Layout.PARTITION_THICKNESS = 1
Layout.PARTITIONS = {
	{ x = -10, thickness = Layout.PARTITION_THICKNESS, blockedZHigh = -20, blockedZLow = -100 },
	{ x = 0, thickness = Layout.PARTITION_THICKNESS, blockedZHigh = -30, blockedZLow = -110 },
	{ x = 10, thickness = Layout.PARTITION_THICKNESS, blockedZHigh = -20, blockedZLow = -100 },
} :: { Partition }

-- 관문: 대기실(B)과 미로(C)의 경계(z -20)에서 1번 레인(x -20~-10)만 열려 있어요.
Layout.GATE_THICKNESS = 2
Layout.GATE = {
	z = Layout.MAZE.front, -- -20
	thickness = Layout.GATE_THICKNESS,
	openXMin = Layout.LANES[1] - Layout.LANE_WIDTH / 2, -- -20
	openXMax = Layout.LANES[1] + Layout.LANE_WIDTH / 2, -- -10
} :: Gate

-- 출구 벽(m5-14 B1): 미로(C)와 출구 통로(D)의 경계(z -110)에서 4번 레인(x 10~20)만 열려 있어요.
-- 이게 없으면 1·2·3번 레인 끝도 D로 이어져 1번 레인 직진으로 결승에 가요.
Layout.EXIT_GATE = {
	z = Layout.MAZE.back, -- -110
	thickness = Layout.GATE_THICKNESS,
	openXMin = Layout.LANES[4] - Layout.LANE_WIDTH / 2, -- 10
	openXMax = Layout.LANES[4] + Layout.LANE_WIDTH / 2, -- 20
} :: Gate

Layout.BOUNDS = { xMin = -Layout.HALF_WIDTH, xMax = Layout.HALF_WIDTH } :: Bounds

-- ── m5-40 F: 두 번째 미로 (레인 3개, 첫 미로와 반대 방향) ─────────────────────────────
-- 첫 미로는 왼쪽(1번 레인)으로 들어가 오른쪽(4번)으로 나가요. 두 번째 미로는 오른쪽 레인(x 7~20)으로 들어가
-- 끝에서 가운데 레인(x -7~7)으로 건너 입구 쪽으로 되돌아온 다음, 왼쪽 레인(x -20~-7)으로 건너 끝으로 나가요.
-- 레인이 넓어서(13~14) 첫 미로보다 빨리 달리지만 되돌아오는 구간이 있어요. 벽 높이·두께는 첫 미로와 같아요.
Layout.MAZE2_LANES = { 13.5, 0, -13.5 } -- 오른쪽 → 가운데 → 왼쪽 (진행 순서)
Layout.MAZE2_PARTITIONS = {
	-- 오른쪽·가운데 사이: 틈은 끝 쪽(z -164~-174)
	{ x = 7, thickness = Layout.PARTITION_THICKNESS, blockedZHigh = -120, blockedZLow = -164 },
	-- 가운데·왼쪽 사이: 틈은 입구 쪽(z -122~-132)
	{ x = -7, thickness = Layout.PARTITION_THICKNESS, blockedZHigh = -132, blockedZLow = -176 },
} :: { Partition }
-- 입구 문: 출구 통로(D)에서 오른쪽 레인만 열려 있어요 (z -120~-122, 첫 미로 출구가 오른쪽이라 바로 이어져요)
Layout.MAZE2_GATE = {
	z = Layout.MAZE2.front - Layout.GATE_THICKNESS / 2, -- -121
	thickness = Layout.GATE_THICKNESS,
	openXMin = 7,
	openXMax = Layout.HALF_WIDTH,
} :: Gate
-- 출구 문: 왼쪽 레인만 열려 있어요 (z -174~-176)
Layout.MAZE2_EXIT_GATE = {
	z = Layout.MAZE2.back + Layout.GATE_THICKNESS / 2, -- -175
	thickness = Layout.GATE_THICKNESS,
	openXMin = -Layout.HALF_WIDTH,
	openXMax = -7,
} :: Gate

-- ── m5-40 H: 풍선 기둥 숲 (BounceFloor 위 고정 기둥 줄 4개) ───────────────────────────
-- 줄마다 기둥이 거의 붙어 서 있고(틈 0.6 — 몸이 못 지나가요) 한쪽 끝만 9 studs 열려 있어요. 열린 쪽이
-- 왼쪽 → 오른쪽 → 왼쪽 → 오른쪽으로 번갈아서 튕기면서 좌우로 지그재그해요. 기둥 높이는 벽과 같아
-- 바운스(정점 ≈ 7.7)로 못 넘어요.
export type Pillar = { x: number, z: number, radius: number }
export type ForestRow = { z: number, open: "Left" | "Right" }
Layout.PILLAR_DIAMETER = 4
Layout.PILLAR_PITCH = 4.6 -- 기둥 중심 간격 (틈 0.6)
Layout.FOREST_OPENING = 9 -- 줄마다 열린 폭
Layout.FOREST_ROWS = {
	{ z = -188, open = "Left" },
	{ z = -198, open = "Right" },
	{ z = -208, open = "Left" },
	{ z = -218, open = "Right" },
} :: { ForestRow }

-- 기둥 목록: 줄마다 열린 쪽 벽에서 FOREST_OPENING 떨어진 곳부터 반대쪽 벽에 닿을 때까지 PITCH 간격
function Layout.pillars(): { Pillar }
	local list: { Pillar } = {}
	local r = Layout.PILLAR_DIAMETER / 2
	local count = math.ceil((Layout.WIDTH - Layout.FOREST_OPENING - 2 * r) / Layout.PILLAR_PITCH) + 1 -- 7
	for _, row in Layout.FOREST_ROWS do
		for k = 0, count - 1 do
			local offset = Layout.FOREST_OPENING + r + k * Layout.PILLAR_PITCH
			local x = if row.open == "Left" then -Layout.HALF_WIDTH + offset else Layout.HALF_WIDTH - offset
			table.insert(list, { x = x, z = row.z, radius = r })
		end
	end
	return list
end

-- ── m5-40 완주 시간 추정 (빠른 사람, 걷기 16) ────────────────────────────────────────────
-- 구간마다 "실제로 걷는 길이"(미로·지그재그는 직선보다 길어요)와 지연(꺾기·관문·튕김 착지) 상수.
-- 걷는 길이는 레인 중심선을 따라 잰 대략값이에요(tests/m5-40-l3가 격자 최단 경로와 크게 다르지 않은지 확인해요).
Layout.WALK_SPEED = 16
Layout.SECTION_WALK = {
	Start = 14, -- 스폰 앞줄(-2.5) → 대기실
	Anteroom = 4,
	Maze = 330, -- 1번 레인 ↓ + 건너기 + 2번 ↑ + 건너기 + 3번 ↓ + 건너기 + 4번 → 출구
	Exit = 10,
	Maze2 = 165, -- 오른쪽 ↓ 48 + 건너기 13 + 가운데 ↑ 42 + 건너기 13 + 왼쪽 ↓ 49
	Landing = 6,
	Forest = 136, -- 기둥 줄 4개를 좌우로 지그재그 (줄마다 약 30 옆으로 + 10 앞으로)
	Finish = 14,
} :: { [string]: number }
Layout.SECTION_DELAY = {
	Anteroom = 0.5, -- 관문으로 몰림
	Maze = 2.5, -- 꺾기 4번(되돌아 서기 2번 포함)
	Maze2 = 1.5, -- 꺾기 3번(되돌아 서기 1번)
	Forest = 2, -- 튕기는 중 좁은 틈 맞추기
} :: { [string]: number }
Layout.SECTION_ORDER = { "Start", "Anteroom", "Maze", "Exit", "Maze2", "Landing", "Forest", "Finish" }

-- 출발 → 결승 순서의 구간 표 (z가 단조 감소하는지 테스트가 확인해요)
function Layout.sections(): { Span }
	return {
		Layout.START,
		Layout.ANTEROOM,
		Layout.MAZE,
		Layout.EXIT,
		Layout.MAZE2,
		Layout.LANDING,
		Layout.FOREST,
		Layout.FINISH,
	}
end

-- 바운스: 위 속도만(수평 성분 없음). 서버가 BOUNCE_HOLD 동안 강제로 걸고 그다음은 포물선.
Layout.BOUNCE_UP_SPEED = 55
Layout.BOUNCE_HOLD = 0.08
Layout.BOUNCE_COOLDOWN = 0.45 -- 자유낙하 복귀시간(≈0.56초)보다 짧아 착지 즉시 재발동
Layout.BOUNCE_EXEMPT = 0.8 -- 이동 감시 면제(flightTime보다 넉넉하게)
Layout.BOUNCE_RAYCAST_LENGTH = 4.5 -- 발밑 레이캐스트 길이: 서 있을 때 루트 높이 3 + 여유 1.5 (m5-14 B5), 정점 근처에서는 안 닿음

-- 스폰 24개 (6열 × 4줄, SoySwamp와 같은 격자). 전부 A 구간(일반 바닥) 안.
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_COLUMN_SPACING = 6
Layout.SPAWN_ROW_SPACING = 3.6
Layout.SPAWN_Z_INSET = 2.5 -- 출발 끝(z 0)에서 이만큼 뒤에 첫 줄

function Layout.spawnPositions(): { { x: number, z: number } }
	local list = {}
	for row = 0, Layout.SPAWN_ROWS - 1 do
		for col = 0, Layout.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (Layout.SPAWN_COLUMNS - 1) / 2) * Layout.SPAWN_COLUMN_SPACING,
				z = Layout.START.front - Layout.SPAWN_Z_INSET - row * Layout.SPAWN_ROW_SPACING,
			})
		end
	end
	return list
end

return Layout
