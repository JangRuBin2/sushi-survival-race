--!strict
-- "초밥집 카운터 대횡단"(sushi-counter-crossing, m6-03) 코스 치수·튜닝 값 (Roblox API 없음).
-- 대형 맵(m6-02): 폭 72, 스폰 40, 12~40명. 좌표는 origin 기준 로컬 studs — x: 좌우(+가 RightVector), y: 위,
-- z: 0이 출발 끝이고 음수로 갈수록 결승.
--
-- 구간 (z)                       바닥 윗면 y   내용
--   A 출발 광장   0 ~ -40          0            폭 72, 스폰 40 (8 × 5)
--   B 갈림길      -40 ~ -200       0            폭 18 × 3줄, 줄 사이 틈 9 (빠지면 부활)
--                                               왼: 회전 레일(구간마다 앞/뒤로 밂, 5초마다 뒤바뀜)
--                                               가운데: 접시 징검다리 13개(지름 10, 틈 약 4.4)
--                                               오른: 나무 카운터 + 굴러오는 간장병(2.5초 간격)
--   C 합류 광장   -200 ~ -240      0            폭 72
--   D 젓가락 들판 -240 ~ -380      0            폭 72, 양옆 낮은 벽. 빨간 원 1.5초 뒤 젓가락이 쿡(넉백)
--   E 계산대 오르막 -380 ~ -500    0 → 12       폭 14 × 4줄(틈 4), -380 ~ -440 오르막, 그 뒤 평지 12
--                                               바깥 두 줄: 영수증이 뒤로 밂(느리지만 안전) / 안쪽 두 줄: 동전이 굴러옴
--   F 결승        -500 ~ -524      12           폭 72, FinishLine z -510

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number, top: number, name: string }
export type Plate = { index: number, x: number, z: number, radius: number, top: number }
export type RailSegment = { index: number, minZ: number, maxZ: number, base: number } -- base 1 = 결승 쪽(-z)으로 밂
export type Ramp = { index: number, x: number, kind: "Receipt" | "Coin" }
export type Point = { x: number, z: number }

local Layout = {}

Layout.WIDTH = 72
Layout.HALF = 36
Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 12 -- 그 자리 바닥보다 이만큼 아래면 탈락(→ Race 부활)
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이
Layout.WALK_SPEED = 16
Layout.CAPACITY = 40
Layout.MIN_PLAYERS = 12

Layout.LOW_Y = 0
Layout.HIGH_Y = 12 -- 계산대 위

Layout.START = { front = 0, back = -40 } :: Span
Layout.LANES = { front = -40, back = -200 } :: Span
Layout.MERGE = { front = -200, back = -240 } :: Span
Layout.FIELD = { front = -240, back = -380 } :: Span
Layout.RAMPS = { front = -380, back = -500 } :: Span
Layout.RAMP_SLOPE = { front = -380, back = -440 } :: Span -- 0 → 12 (약 11°)
Layout.FINISH = { front = -500, back = -524 } :: Span
Layout.FINISH_LINE_Z = -510
Layout.SECTION_NAMES = { "A", "B", "C", "D", "E", "F" }

function Layout.sections(): { Span }
	return { Layout.START, Layout.LANES, Layout.MERGE, Layout.FIELD, Layout.RAMPS, Layout.FINISH }
end

-- ── B 갈림길 ──────────────────────────────────────────────────────────
Layout.LANE_WIDTH = 18
Layout.LANE_X = { -27, 0, 27 } -- 왼 레일 / 가운데 접시 / 오른 간장병

-- 왼쪽 회전 레일: 40씩 4구간, 이웃끼리 반대. RAIL_PERIOD초마다 전부 뒤바뀌어요.
Layout.RAIL_SPEED = 10 -- 미는 목표 속도 (걷기 16 → 순방향 26 / 역방향 6)
Layout.RAIL_PERIOD = 5
Layout.RAIL_WARN = 0.4 -- 바뀌기 이만큼 전 RailSwitch 소리
Layout.PUSH_ACCEL = 24 -- 회전 벨트·설거지통 접시와 같아요
Layout.PUSH_ZONE_HEIGHT = 5 -- 발이 바닥 위 이 높이 안이면 밀어요
Layout.RAIL_SEGMENTS = {
	{ index = 1, maxZ = -40, minZ = -80, base = 1 },
	{ index = 2, maxZ = -80, minZ = -120, base = -1 },
	{ index = 3, maxZ = -120, minZ = -160, base = 1 },
	{ index = 4, maxZ = -160, minZ = -200, base = -1 },
} :: { RailSegment }

-- 가운데 접시 징검다리: 지름 10, z 12 간격, x ±4 지그재그 → 이웃 틈 √(12² + 8²) − 10 ≈ 4.4
Layout.PLATE_RADIUS = 5
Layout.PLATE_THICKNESS = 1.5
Layout.PLATE_STEP_Z = 12
Layout.PLATE_ZIGZAG = 4
Layout.PLATE_FIRST_Z = -46
Layout.PLATE_COUNT = 13

local function makePlates(): { Plate }
	local list: { Plate } = {}
	for i = 1, Layout.PLATE_COUNT do
		table.insert(list, {
			index = i,
			x = if i % 2 == 1 then -Layout.PLATE_ZIGZAG else Layout.PLATE_ZIGZAG,
			z = Layout.PLATE_FIRST_Z - (i - 1) * Layout.PLATE_STEP_Z,
			radius = Layout.PLATE_RADIUS,
			top = Layout.LOW_Y,
		})
	end
	return list
end
Layout.PLATES = makePlates()

-- 오른쪽 간장병: 결승 쪽 끝(z -198)에서 출발 쪽(+z)으로 굴러와 z -42에서 사라져요. 슬롯 5개를 돌려 써요.
Layout.BOTTLE_INTERVAL = 2.5
Layout.BOTTLE_SPEED = 14
Layout.BOTTLE_FROM_Z = -198
Layout.BOTTLE_TO_Z = -42
Layout.BOTTLE_LENGTH = 10 -- x 방향 (줄 18 중 10을 막아요 — 옆 8로 피하거나 점프)
Layout.BOTTLE_DIAMETER = 4
Layout.BOTTLE_X = { 23, 31 } -- 번갈아
Layout.BOTTLE_SLOTS = 5 -- 동시에 굴러가는 최대 개수 ((198 − 42) / 14 / 2.5 ≈ 4.5)
Layout.BOTTLE_START_DELAY = 1 -- 출발 뒤 첫 병까지

-- ── D 젓가락 들판 ─────────────────────────────────────────────────────
Layout.FIELD_WALL_HEIGHT = 4
Layout.FIELD_WALL_THICKNESS = 2
Layout.STRIKE_INTERVAL = 0.9 -- 새 경고 원 간격
Layout.STRIKE_WARN = 1.5 -- 원이 뜬 뒤 젓가락이 내려오기까지
Layout.STRIKE_SHOW = 0.6 -- 내려온 젓가락이 남아 있는 시간
Layout.STRIKE_RADIUS = 7
Layout.STRIKE_X = 30 -- 원 중심 x ∈ [-30, 30]
Layout.STRIKE_Z = { front = -246, back = -374 } :: Span
Layout.STRIKE_SLOTS = 4 -- 동시에 보이는 최대 개수 ((1.5 + 0.6) / 0.9 ≈ 2.3 → 여유)
Layout.STRIKE_START_DELAY = 6 -- 출발 뒤 첫 원 (빠른 사람이 들판에 닿기 전부터 돌아가요)
Layout.STRIKE_KNOCK_OUT = 34
Layout.STRIKE_KNOCK_UP = 16
Layout.STRIKE_EXEMPT = 1.2
Layout.STRIKE_DOWN = 0.5 -- PlatformStand

-- ── E 계산대 오르막 ───────────────────────────────────────────────────
Layout.RAMP_WIDTH = 14
Layout.RAMP_LIST = {
	{ index = 1, x = -27, kind = "Receipt" },
	{ index = 2, x = -9, kind = "Coin" },
	{ index = 3, x = 9, kind = "Coin" },
	{ index = 4, x = 27, kind = "Receipt" },
} :: { Ramp }
Layout.RECEIPT_SPEED = 5 -- 바깥 줄: 뒤로(+z) 미는 목표 속도
Layout.COIN_INTERVAL = 2.2
Layout.COIN_SPEED = 16
Layout.COIN_FROM_Z = -498
Layout.COIN_TO_Z = -382
Layout.COIN_DIAMETER = 5
Layout.COIN_LENGTH = 6 -- 동전 더미 (x 방향)
Layout.COIN_SIDE = 4 -- 줄 가운데 ± (번갈아)
Layout.COIN_SLOTS = 4 -- 줄마다 ((498 − 382) / 16 / 2.2 ≈ 3.3)
Layout.COIN_START_DELAY = 8

-- 맞음 (간장병·동전 공통)
Layout.HIT_PAD = 1 -- 판정 상자를 이만큼 늘려요
Layout.HIT_FOOT = 3.5 -- 발 높이(굴러가는 물체 바닥 기준)가 이보다 낮으면 맞음 (점프로 넘어요)
Layout.ROLL_KNOCK_BACK = 26 -- +z (뒤로)
Layout.ROLL_KNOCK_UP = 12
Layout.ROLL_EXEMPT = 1
Layout.ROLL_DOWN = 0.6
Layout.HIT_COOLDOWN = 0.8

-- 길이 추정 (빠른 사람): 직선 이동 + 구간별 지연(초)
Layout.SECTION_DELAY = { A = 1, B = 6, C = 0, D = 5, E = 6, F = 0 } :: { [string]: number }

-- ── 바닥 ──────────────────────────────────────────────────────────────
function Layout.floorRects(): { Rect }
	local h = Layout.HALF
	local list: { Rect } = {
		{
			name = "StartPlaza",
			minX = -h,
			maxX = h,
			minZ = Layout.START.back,
			maxZ = Layout.START.front,
			top = Layout.LOW_Y,
		},
		{
			name = "MergePlaza",
			minX = -h,
			maxX = h,
			minZ = Layout.MERGE.back,
			maxZ = Layout.MERGE.front,
			top = Layout.LOW_Y,
		},
		{
			name = "ChopstickField",
			minX = -h,
			maxX = h,
			minZ = Layout.FIELD.back,
			maxZ = Layout.FIELD.front,
			top = Layout.LOW_Y,
		},
		{
			name = "FinishPlaza",
			minX = -h,
			maxX = h,
			minZ = Layout.FINISH.back,
			maxZ = Layout.FINISH.front,
			top = Layout.HIGH_Y,
		},
	}
	local lw = Layout.LANE_WIDTH / 2
	-- 레일 줄은 구간마다 따로 (RailSegment 파츠)
	for _, seg in Layout.RAIL_SEGMENTS do
		table.insert(list, {
			name = string.format("Rail%d", seg.index),
			minX = Layout.LANE_X[1] - lw,
			maxX = Layout.LANE_X[1] + lw,
			minZ = seg.minZ,
			maxZ = seg.maxZ,
			top = Layout.LOW_Y,
		})
	end
	table.insert(list, {
		name = "BottleLane",
		minX = Layout.LANE_X[3] - lw,
		maxX = Layout.LANE_X[3] + lw,
		minZ = Layout.LANES.back,
		maxZ = Layout.LANES.front,
		top = Layout.LOW_Y,
	})
	-- 오르막 위 평지 (쐐기는 따로)
	for _, ramp in Layout.RAMP_LIST do
		table.insert(list, {
			name = string.format("RampTop%d", ramp.index),
			minX = ramp.x - Layout.RAMP_WIDTH / 2,
			maxX = ramp.x + Layout.RAMP_WIDTH / 2,
			minZ = Layout.RAMPS.back,
			maxZ = Layout.RAMP_SLOPE.back,
			top = Layout.HIGH_Y,
		})
	end
	return list
end

-- 스폰 40개: x 8칸(간격 8, ±28) × z 5줄(간격 7, -6 ~ -34)
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
