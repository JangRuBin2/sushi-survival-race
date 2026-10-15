--!strict
-- "깨끗하게! 설거지통"(dish-sink, m5-34) 코스 치수·튜닝 값 (Roblox API 없음).
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(+가 origin.RightVector), y: 위, z: 0이 출발 끝이고 음수로 갈수록 결승.
--
-- 구간 (z)                          바닥 윗면 y   내용
--   A 출발           0 ~ -16          0            조리대 가장자리 폭 24, 스폰 24개
--   B 회전 접시 1    -16 ~ -111       0            접시 8개(지름 20) 2줄 x 4행, 틈 3, 이웃끼리 반대로 밂
--   C 칸막이 선반    -111 ~ -195      0            폭 12 (앞 4 studs는 폭 28 "칸막이 머리"), 수세미 3개
--   D 엎어 둔 컵     -195 ~ -255      0 → 4        컵·밥공기 7개(지름 9~10), 두 갈래 (X 모양)
--   E 큰 접시        -255 ~ -335      4            큰 접시 2개(지름 26) + 선반 다리 2개(폭 10), 둘째 다리에 수세미
--   F 두 수세미 복도 -335 ~ -395      4            폭 16, 큰 수세미 2개가 엇갈려 왕복
--   G 건조대 결승    -395 ~ -445      4 → 10       -395 ~ -415 오르막, 그 뒤 평지 10, FinishLine z -436
--
-- 스펙과 다른 점 (개발 결정 기록 D5·D6):
--   C 칸막이 앞 4 studs를 폭 28로 — 접시 4행(x ±11.5)에서 폭 12 칸막이까지 실제 틈이 4.1이라, 스펙 "4행→C 틈 3"을 지키려고.
--   E 큰 접시는 2개 — 지름 26 접시 3개 + 다리 2개 + 틈 3은 E 길이 80에 안 들어가요(최소 약 100).
--     수세미 다리(둘째 다리)는 z -327 ~ -335라 수세미가 z -331이에요(스펙 -305).

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)
export type PlateKind = { radius: number, omega: number, cap: number }
export type Plate = {
	index: number,
	row: number,
	lane: number,
	x: number,
	z: number,
	top: number,
	kind: PlateKind,
	dir: number, -- 1 = 위에서 볼 때 시계 방향, -1 = 반시계
}
export type Cup = { index: number, x: number, z: number, radius: number, top: number, branch: string }
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number, top: number, name: string }
export type Sponge = {
	index: number,
	section: string,
	z: number,
	amplitude: number, -- x 중심이 -amplitude ↔ +amplitude
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	offset: number, -- 주기 어긋남 (초)
	floorY: number, -- 그 자리 바닥 윗면
}
export type Point = { x: number, z: number }

local Layout = {}

Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 12 -- 그 구간 바닥보다 이만큼 아래면 탈락
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이
Layout.WALK_SPEED = 16 -- 길이 추정용 (Config.Character.WalkSpeed와 같아요)

Layout.LOW_Y = 0 -- A·B·C 윗면
Layout.HIGH_Y = 4 -- E·F 윗면
Layout.FINISH_Y = 10 -- G 평지 윗면

-- 물 표면(장식, 충돌 없음) = 그 구간 바닥 − 5 (B·C) / E·F는 −1 (둘째 개수대 칸이 높아요)
Layout.WATER_LOW_Y = -5
Layout.WATER_HIGH_Y = -1

-- 구간
Layout.START = { front = 0, back = -16 } :: Span
Layout.PLATES_B = { front = -16, back = -111 } :: Span
Layout.PARTITION = { front = -111, back = -195 } :: Span
Layout.CUPS = { front = -195, back = -255 } :: Span
Layout.BIG_PLATES = { front = -255, back = -335 } :: Span
Layout.CORRIDOR = { front = -335, back = -395 } :: Span
Layout.FINISH = { front = -395, back = -445 } :: Span

Layout.SECTION_NAMES = { "A", "B", "C", "D", "E", "F", "G" }

Layout.START_WIDTH = 24
Layout.PARTITION_WIDTH = 12
Layout.PARTITION_HEAD = { front = -111, back = -115 } :: Span -- 칸막이 머리 (접시에서 뛰어내리는 자리)
Layout.PARTITION_HEAD_WIDTH = 28
Layout.BRIDGE_WIDTH = 10
Layout.CORRIDOR_WIDTH = 16
Layout.FINISH_WIDTH = 20
Layout.RAMP = { front = -395, back = -415 } :: Span -- 4 → 10 (약 17°)
Layout.FINISH_LINE_Z = -436

-- ── 회전 접시 ───────────────────────────────────────────────────────
Layout.PLATE_THICKNESS = 1.5
Layout.SMALL_PLATE = { radius = 10, omega = 2 * math.pi / 5, cap = 8 } :: PlateKind
Layout.BIG_PLATE = { radius = 13, omega = 2 * math.pi / 4, cap = 10 } :: PlateKind
Layout.EDGE_FRACTION = 0.7 -- r > 0.7R이면 바깥으로도 밂
Layout.EDGE_PUSH = 2.5
Layout.PLATE_ZONE_HEIGHT = 5 -- 접시 윗면 위 이 높이 안(발 기준)이면 접시 위
Layout.PUSH_ACCEL = 24 -- 회전 벨트(RotatingBelt PUSH_ACCEL)와 같아요
Layout.PLATE_SPIN_PERIOD = 5 -- 테두리 장식 한 바퀴 (B). E는 4

Layout.LANE_X = { -11.5, 11.5 }
Layout.ROW_Z = { -29, -52, -75, -98 }

-- (행 + 줄)이 짝수면 시계 방향(1), 홀수면 반시계(-1) — 이웃 접시끼리 항상 반대
function Layout.plateDirection(row: number, lane: number): number
	return if (row + lane) % 2 == 0 then 1 else -1
end

local function makePlates(): { Plate }
	local list: { Plate } = {}
	for row, z in Layout.ROW_Z do
		for lane, x in Layout.LANE_X do
			table.insert(list, {
				index = #list + 1,
				row = row,
				lane = lane,
				x = x,
				z = z,
				top = Layout.LOW_Y,
				kind = Layout.SMALL_PLATE,
				dir = Layout.plateDirection(row, lane),
			})
		end
	end
	-- E 큰 접시 2개 (지그재그 x -5 / +5). 행 5·6, 줄 1로 이어 세면 방향이 서로 반대예요.
	local big = { { x = -5, z = -271 }, { x = 5, z = -311 } }
	for i, p in big do
		local row = 4 + i
		table.insert(list, {
			index = #list + 1,
			row = row,
			lane = 1,
			x = p.x,
			z = p.z,
			top = Layout.HIGH_Y,
			kind = Layout.BIG_PLATE,
			dir = Layout.plateDirection(row, 1),
		})
	end
	return list
end

Layout.PLATES = makePlates()

-- ── 엎어 둔 컵 (D, 고정, 윗면 0 → 4). 갈래: S 시작 · L 왼쪽 · R 오른쪽 · M 가운데(합류) · E 끝 ─────
Layout.CUP_LIST = {
	{ index = 1, x = 0, z = -203.5, radius = 5, top = 0, branch = "S" },
	{ index = 2, x = -6, z = -215, radius = 4.5, top = 1.5, branch = "L" },
	{ index = 3, x = 6, z = -215, radius = 4.5, top = 1.5, branch = "R" },
	{ index = 4, x = 0, z = -227, radius = 5, top = 3, branch = "M" },
	{ index = 5, x = -6, z = -238.5, radius = 4.5, top = 3.5, branch = "L" },
	{ index = 6, x = 6, z = -238.5, radius = 4.5, top = 3.5, branch = "R" },
	{ index = 7, x = 0, z = -250, radius = 5, top = 4, branch = "E" },
} :: { Cup }
Layout.CUP_HEIGHT = 9 -- 컵 몸통 높이 (물속으로 내려가요)

-- ── 직사각형 바닥 (판정) ───────────────────────────────────────────────
Layout.BRIDGES = {
	{ minX = -5, maxX = 5, minZ = -295, maxZ = -287, top = 4, name = "Bridge1" },
	{ minX = -5, maxX = 5, minZ = -335, maxZ = -327, top = 4, name = "Bridge2" },
} :: { Rect }

function Layout.floorRects(): { Rect }
	local half = Layout.START_WIDTH / 2
	local headHalf = Layout.PARTITION_HEAD_WIDTH / 2
	local partHalf = Layout.PARTITION_WIDTH / 2
	local corrHalf = Layout.CORRIDOR_WIDTH / 2
	local finHalf = Layout.FINISH_WIDTH / 2
	local list: { Rect } = {
		{
			minX = -half,
			maxX = half,
			minZ = Layout.START.back,
			maxZ = Layout.START.front,
			top = 0,
			name = "StartCounter",
		},
		{
			minX = -headHalf,
			maxX = headHalf,
			minZ = Layout.PARTITION_HEAD.back,
			maxZ = Layout.PARTITION_HEAD.front,
			top = 0,
			name = "PartitionHead",
		},
		{
			minX = -partHalf,
			maxX = partHalf,
			minZ = Layout.PARTITION.back,
			maxZ = Layout.PARTITION_HEAD.back,
			top = 0,
			name = "Partition",
		},
	}
	for _, b in Layout.BRIDGES do
		table.insert(list, b)
	end
	table.insert(list, {
		minX = -corrHalf,
		maxX = corrHalf,
		minZ = Layout.CORRIDOR.back,
		maxZ = Layout.CORRIDOR.front,
		top = Layout.HIGH_Y,
		name = "Corridor",
	})
	table.insert(list, {
		minX = -finHalf,
		maxX = finHalf,
		minZ = Layout.FINISH.back,
		maxZ = Layout.RAMP.back,
		top = Layout.FINISH_Y,
		name = "DryingRack",
	})
	return list
end

-- ── 수세미 (주기 8초: +A 1.5초 멈춤 → 2.5초 이동 → -A 1.5초 멈춤 → 2.5초 이동) ──────────────
Layout.SPONGE_PERIOD = 8
Layout.SPONGE_HOLD = 1.5
Layout.SPONGE_MOVE = 2.5
Layout.SPONGE_HIT_PAD_X = 1.5 -- 판정 상자를 x로 이만큼 늘려요
Layout.SPONGE_HIT_PAD_Z = 1
Layout.SPONGE_HIT_FOOT = 6 -- 발 높이(바닥 기준)가 이보다 낮으면 맞음
Layout.SPONGE_KNOCK_SIDE = 30
Layout.SPONGE_KNOCK_UP = 14
Layout.SPONGE_KNOCK_HOLD = 0.12 -- LinearVelocity 거는 시간
Layout.SPONGE_KNOCKDOWN = 0.8 -- PlatformStand
Layout.SPONGE_EXEMPT = 1.2 -- MoveExempt
Layout.SPONGE_COOLDOWN = 0.6

Layout.SPONGES = {
	{ index = 1, section = "C", z = -127, amplitude = 12, sizeX = 9, sizeY = 6, sizeZ = 7, offset = 0, floorY = 0 },
	{ index = 2, section = "C", z = -153, amplitude = 12, sizeX = 9, sizeY = 6, sizeZ = 7, offset = 2.7, floorY = 0 },
	{ index = 3, section = "C", z = -179, amplitude = 12, sizeX = 9, sizeY = 6, sizeZ = 7, offset = 5.3, floorY = 0 },
	{ index = 4, section = "E", z = -331, amplitude = 11, sizeX = 9, sizeY = 6, sizeZ = 7, offset = 0, floorY = 4 },
	{ index = 5, section = "F", z = -352, amplitude = 14, sizeX = 11, sizeY = 6, sizeZ = 7, offset = 0, floorY = 4 },
	{ index = 6, section = "F", z = -375, amplitude = 14, sizeX = 11, sizeY = 6, sizeZ = 7, offset = 4, floorY = 4 },
} :: { Sponge }

-- ── 스폰 24개: 6열 x 4줄, 칸 사이 3.5 studs (출발 폭 24 안) ──────────────────
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

-- 구간 전체를 z 순서(출발 → 결승)로
function Layout.sections(): { Span }
	return {
		Layout.START,
		Layout.PLATES_B,
		Layout.PARTITION,
		Layout.CUPS,
		Layout.BIG_PLATES,
		Layout.CORRIDOR,
		Layout.FINISH,
	}
end

-- 길이 추정용 구간별 지연 (초): 접시 점프·밀림, 수세미 기다림, 컵 점프 (m5-40 측정 기준 — Studio 실측으로 조정)
Layout.SECTION_DELAY = {
	A = 0,
	B = 7, -- 접시 4개 점프 + 밀림 거슬러 가기
	C = 4.5, -- 수세미 3개 x 평균 1.5초
	D = 3, -- 컵 4번 점프
	E = 4.5, -- 큰 접시 2개 밀림 + 수세미 1개
	F = 3, -- 수세미 2개
	G = 0,
} :: { [string]: number }

return Layout
