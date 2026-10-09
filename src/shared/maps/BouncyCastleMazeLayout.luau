--!strict
-- "방방 미로" 코스 치수와 튜닝 값, 미로·바운스 판정에 쓰는 순수 계산 (Roblox API 없음, 스펙 m5-14).
-- BouncyCastleMaze.build가 이 표대로 회색 박스를 쌓고, tests/map-bouncy-castle-maze.spec.luau가 치수 약속을
-- 확인해요. 좌표는 origin 기준 로컬 studs예요. x: 좌우(-가 왼쪽), y: 위, z: 0이 출발 끝이고 음수로 갈수록 결승.
-- 바닥 윗면이 y = 0이에요 (A·D·E 구간의 일반 바닥과 B·C 구간의 BounceFloor 모두 같은 높이).
--
-- 코스: A 출발(0~-16, 일반) → B 대기실·관문(-16~-20, BounceFloor, 1번 레인만 열림) →
--       C 미로(-20~-110, BounceFloor, 레인 4개를 칸막이 3개가 S자로 갈라놓음) →
--       D 출구 통로(-110~-120, 일반) → E 결승(-120~-140, 일반, FinishLine -134).

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
Layout.FINISH = { front = -120, back = -140 } :: Span -- E: 결승
Layout.FINISH_LINE_Z = -134
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

Layout.BOUNDS = { xMin = -Layout.HALF_WIDTH, xMax = Layout.HALF_WIDTH } :: Bounds

-- 바운스: 위 속도만(수평 성분 없음). 서버가 BOUNCE_HOLD 동안 강제로 걸고 그다음은 포물선.
Layout.BOUNCE_UP_SPEED = 55
Layout.BOUNCE_HOLD = 0.08
Layout.BOUNCE_COOLDOWN = 0.45 -- 자유낙하 복귀시간(≈0.56초)보다 짧아 착지 즉시 재발동
Layout.BOUNCE_EXEMPT = 0.8 -- 이동 감시 면제(flightTime보다 넉넉하게)
Layout.BOUNCE_RAYCAST_LENGTH = 3.5 -- 발밑 레이캐스트 길이 (서 있을 때만 닿음)

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
