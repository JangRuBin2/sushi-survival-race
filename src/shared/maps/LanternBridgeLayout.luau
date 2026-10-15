--!strict
-- "등불 다리 건너기"(lantern-bridge, m5-15) 코스 치수·튜닝 값 (Roblox API 없음).
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(+가 origin.RightVector), y: 위,
-- z: 0이 출발 끝이고 음수로 갈수록 결승. 모든 구간은 평탄(바닥 윗면 y = 0) — 처짐은 장식 수준에서도 생략해요.
--
-- 구간 (z)
--   출발    0 ~ -14    폭 16, 스폰 24개, 축제 입구(도리이)
--   다리 1  -14 ~ -34  폭 8,  최대 흔들림 8도 (입문)
--   쉼터 1  -34 ~ -44  폭 10
--   다리 2  -44 ~ -68  폭 6,  최대 흔들림 6도
--   쉼터 2  -68 ~ -78  폭 10
--   다리 3  -78 ~ -98  폭 4(가장 좁음), 최대 흔들림 5.5도(1·2보다 낮지만 좁아서 위험도는 더 높아요 — LanternBridgeLogic.fallRisk)
--   쉼터 3  -98 ~ -108 폭 10
--   ── m5-40 길이 늘리기: 쉼터 3과 다리 4 사이에 끼운 구간 ──
--   다리 5  -108 ~ -168 폭 10(가장 넓음), 길이 60(가장 김), 최대 흔들림 9도 — 넓지만 오래 흔들려요
--   쉼터 4  -168 ~ -180 폭 12
--   다리 6  -180 ~ -196 폭 6, 길이 16(짧음), 최대 흔들림 7도
--   쉼터 5  -196 ~ -208 폭 12
--   다리 7  -208 ~ -238 폭 5, 길이 30, 최대 흔들림 6.5도 (3번 다음으로 좁아요)
--   개울    -238 ~ -338 징검돌 (고정 돌 발판, 앞뒤 둑 + 가운데 섬, 등불 줄 아래) — 흔들리지 않고 뛰어 건너요
--   다리 4  -338 ~ -368 폭 8, 길이 30, 최대 흔들림 10도(일곱 다리 중 가장 높음 — "피날레" 다리, 수치 그대로)
--   결승    -368 ~ -382 폭 16, FinishLine (-378)
--   (전: 다리 4 -108 ~ -138, 결승 -138 ~ -152. 다리 4의 폭·길이·흔들림은 그대로이고 자리만 뒤로 옮겼어요)
--
-- 다리는 좌우로(로컬 Z축 기준 roll) 흔들리고, 쉼터·출발·결승·징검돌은 흔들리지 않아요(고정).
-- 다리 폭 바깥은 바닥이 없어서(판정 파츠 자체가 그 폭만큼만 있어요) 걸어 나가거나 밀리면 자연히 떨어져요.
-- 다리 번호(index)는 BRIDGES 배열 자리와 같아요(서버가 BridgeIndex 속성으로 찾아요) — 1~4는 m5-15 번호 그대로,
-- 5~7은 m5-40에서 붙였어요. 코스 순서는 1 → 2 → 3 → 5 → 6 → 7 → (개울) → 4.

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)
export type Bridge = {
	index: number,
	front: number,
	back: number,
	width: number,
	halfWidth: number,
	length: number,
	maxSwayDeg: number,
	phase: number, -- 라디안, 다리마다 달라서 같이 안 흔들려요
}
export type RestZone = { name: string, front: number, back: number, width: number }

local Layout = {}

Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 25 -- 바닥(y = 0)보다 이만큼 아래로 내려가면 탈락
Layout.FINISH_LINE_INSET = 4 -- 결승선을 결승 평지 뒤쪽 끝보다 이만큼 앞에 둬요

Layout.START = { front = 0, back = -14 } :: Span
Layout.START_WIDTH = 16

Layout.FINISH = { front = -368, back = -382 } :: Span -- m5-40 (전: -138 ~ -152)
Layout.FINISH_WIDTH = 16

Layout.RESTS = {
	{ name = "Rest1", front = -34, back = -44, width = 10 },
	{ name = "Rest2", front = -68, back = -78, width = 10 },
	{ name = "Rest3", front = -98, back = -108, width = 10 },
	{ name = "Rest4", front = -168, back = -180, width = 12 }, -- m5-40
	{ name = "Rest5", front = -196, back = -208, width = 12 }, -- m5-40
} :: { RestZone }

-- ── m5-40 개울 징검돌 ────────────────────────────────────────────────────────────────
-- 다리 7과 다리 4 사이. 앞 둑(다리 7에서 내려서는 곳) → 돌 5개 → 가운데 섬(석등·등불 아래) → 돌 5개 →
-- 뒤 둑(다리 4로 올라서는 곳). 돌은 전부 윗면 y = 0으로 고정(흔들림·태그 없음)이고 좌우로 어긋나 있어서
-- 지그재그로 뛰어 건너요. 돌 사이 틈(가장자리 사이)은 STONE_GAP_MAX 이하라 걷기 + 점프(약 8 studs)로 넉넉히 닿아요.
-- 틈으로 떨어지면 다른 곳과 같은 낙하선(-FALL_MARGIN)에서 탈락이에요.
export type Stone = { name: string, x: number, z: number, radius: number }
Layout.STREAM = { front = -238, back = -338 } :: Span
Layout.STREAM_BANK_FRONT = { name = "BankFront", front = -238, back = -244, width = 12 } :: RestZone
Layout.STREAM_ISLAND = { name = "Island", front = -282, back = -290, width = 12 } :: RestZone
Layout.STREAM_BANK_BACK = { name = "BankBack", front = -328, back = -338, width = 12 } :: RestZone
Layout.STONE_GAP_MAX = 4 -- 이웃한 발판 가장자리 사이 최대 틈
Layout.STONE_GAP_MIN = 2 -- 걸어서 그냥 넘어가지 않을 만큼은 벌어져 있어요
Layout.STONE_HEIGHT = 2 -- 돌 판정 파츠 두께 (윗면 y = 0)
Layout.STONES = {
	-- 앞 둑(-244) → 섬(-282): 좌우 지그재그, 7 간격
	{ name = "Stone01", x = -2.25, z = -249, radius = 2.5 },
	{ name = "Stone02", x = 2.25, z = -256, radius = 2.5 },
	{ name = "Stone03", x = -2.25, z = -263, radius = 2.5 },
	{ name = "Stone04", x = 2.25, z = -270, radius = 2.5 },
	{ name = "Stone05", x = -2.25, z = -277, radius = 2.5 },
	-- 섬(-290) → 뒤 둑(-328): 반대로 지그재그, 두 번째는 작은 돌
	{ name = "Stone06", x = 2.25, z = -295, radius = 2.5 },
	{ name = "Stone07", x = -2.25, z = -302, radius = 2 },
	{ name = "Stone08", x = 2.25, z = -309, radius = 2.5 },
	{ name = "Stone09", x = -2.25, z = -316, radius = 2.5 },
	{ name = "Stone10", x = 2.25, z = -323, radius = 2.5 },
} :: { Stone }

-- 개울의 고정 발판 전부 (둑·섬은 사각, 돌은 원). 길 약속 테스트가 이 순서(출발 → 결승)로 이웃 틈을 재요.
export type Pad = { name: string, kind: "Rect" | "Stone", x: number, z: number, halfX: number, halfZ: number }
function Layout.streamPads(): { Pad }
	local list: { Pad } = {}
	local function rect(zone: RestZone)
		table.insert(list, {
			name = zone.name,
			kind = "Rect" :: "Rect",
			x = 0,
			z = (zone.front + zone.back) / 2,
			halfX = zone.width / 2,
			halfZ = (zone.front - zone.back) / 2,
		})
	end
	local function stone(s: Stone)
		table.insert(
			list,
			{ name = s.name, kind = "Stone" :: "Stone", x = s.x, z = s.z, halfX = s.radius, halfZ = s.radius }
		)
	end
	rect(Layout.STREAM_BANK_FRONT)
	for i = 1, 5 do
		stone(Layout.STONES[i])
	end
	rect(Layout.STREAM_ISLAND)
	for i = 6, #Layout.STONES do
		stone(Layout.STONES[i])
	end
	rect(Layout.STREAM_BANK_BACK)
	return list
end

-- 흔들림: 혼자여도 기본 흔들림이 있고, 인원이 늘수록(SWAY_PER_RIDER_DEG씩) 커지다가
-- SWAY_RIDER_CAP명부터는 더 안 늘어요(24명이 몰려도 과도하게 흔들리지 않게). 늘 그 다리의 maxSwayDeg 이하예요.
Layout.SWAY_BASE_DEG = 2
Layout.SWAY_PER_RIDER_DEG = 1.5
Layout.SWAY_RIDER_CAP = 8
Layout.SWAY_PERIOD = 2.6 -- 초 (한 바퀴)

-- 미는 힘: 다리가 기운 동안 낮은 쪽으로 계속 밀려요 (ChefBoard 기울기와 같은 분류 — 연속 밀기, MoveExempt 없음)
Layout.PLANK_PUSH_SPEED = 7 -- 가장 많이 기울었을 때 미는 최고 속도 (studs/s)
Layout.PLANK_PUSH_ACCEL = 20 -- 그 속도까지 올리는 가속도 (studs/s^2)

Layout.BRIDGES = {
	{ index = 1, front = -14, back = -34, width = 8, halfWidth = 4, length = 20, maxSwayDeg = 8, phase = 0 },
	{
		index = 2,
		front = -44,
		back = -68,
		width = 6,
		halfWidth = 3,
		length = 24,
		maxSwayDeg = 6,
		phase = math.pi / 2,
	},
	{
		index = 3,
		front = -78,
		back = -98,
		width = 4,
		halfWidth = 2,
		length = 20,
		maxSwayDeg = 5.5,
		phase = math.pi,
	},
	{
		index = 4,
		front = -338, -- m5-40: -108 → -338 (폭·길이·흔들림 그대로, 개울 뒤 피날레 자리로)
		back = -368,
		width = 8,
		halfWidth = 4,
		length = 30,
		maxSwayDeg = 10,
		phase = 3 * math.pi / 2,
	},
	-- m5-40 새 다리 3개 (코스 순서: 3 → 5 → 6 → 7 → 개울 → 4). 흔들림은 피날레 다리 4(10도)보다 낮고,
	-- 위험도(흔들림 ÷ 반폭)는 가장 좁은 다리 3보다 낮아요.
	{
		index = 5,
		front = -108,
		back = -168,
		width = 10, -- 가장 넓고 가장 긴 다리: 쉽지만 오래 흔들려서 사람이 몰리면 크게 출렁여요
		halfWidth = 5,
		length = 60,
		maxSwayDeg = 9,
		phase = math.pi / 4,
	},
	{
		index = 6,
		front = -180,
		back = -196,
		width = 6, -- 짧은 다리: 몇 걸음이지만 쉼터 사이에서 타이밍을 봐야 해요
		halfWidth = 3,
		length = 16,
		maxSwayDeg = 7,
		phase = 3 * math.pi / 4,
	},
	{
		index = 7,
		front = -208,
		back = -238,
		width = 5,
		halfWidth = 2.5,
		length = 30,
		maxSwayDeg = 6.5,
		phase = 5 * math.pi / 4,
	},
} :: { Bridge }

-- 스폰 24개: 5열 x 5줄 격자(마지막 1칸은 버려요), 칸 사이 3 studs(출발 폭 16 안에 들어가게)
Layout.SPAWN_COLUMNS = 5
Layout.SPAWN_ROWS = 5
Layout.SPAWN_SPACING = 3

function Layout.spawnPositions(): { { x: number, z: number } }
	local list = {}
	for row = 0, Layout.SPAWN_ROWS - 1 do
		for col = 0, Layout.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (Layout.SPAWN_COLUMNS - 1) / 2) * Layout.SPAWN_SPACING,
				z = Layout.START.front - 1 - row * Layout.SPAWN_SPACING,
			})
		end
	end
	while #list > 24 do
		table.remove(list)
	end
	return list
end

-- 구간 전체를 z 순서(출발 → 결승)로. AC9 겹침·순서 확인용.
-- m5-40: 출발·다리 7개·쉼터 5곳·개울·결승을 front가 큰 것부터(출발 → 결승) 정렬해요.
function Layout.sections(): { Span }
	local list: { Span } = {}
	local function add(front: number, back: number)
		table.insert(list, { front = front, back = back })
	end
	add(Layout.START.front, Layout.START.back)
	for _, bridge in Layout.BRIDGES do
		add(bridge.front, bridge.back)
	end
	for _, rest in Layout.RESTS do
		add(rest.front, rest.back)
	end
	add(Layout.STREAM.front, Layout.STREAM.back)
	add(Layout.FINISH.front, Layout.FINISH.back)
	table.sort(list, function(a: Span, b: Span): boolean
		return a.front > b.front
	end)
	return list
end

-- ── m5-40 완주 시간 추정 (빠른 사람, 걷기 16) ────────────────────────────────────────────
-- 걷는 길이 = 스폰 앞줄 → 결승선 직선 + 개울 지그재그 덤. 지연 = 다리마다(좁고 많이 흔들릴수록 길게) + 징검돌
-- 점프(돌마다 착지 맞추기). 상수는 여기, 계산은 LanternBridgeLogic.estimateClearTime.
Layout.WALK_SPEED = 16
Layout.STREAM_ZIGZAG_EXTRA = 8 -- 돌이 좌우 4.5씩 어긋나서 직선보다 더 걷는 길이
Layout.BRIDGE_DELAY = { 1.5, 2, 3, 3, 2, 1.5, 2.5 } :: { number } -- 다리 index 1~7 (균형 잡기·기다리기, 초)
Layout.STONE_DELAY = 0.6 -- 돌 하나마다 점프·착지 (초)
Layout.REST_DELAY = 0 -- 쉼터는 지나가기만 해요 (빠른 사람 기준)

function Layout.totalLength(): number
	return Layout.START.front - Layout.FINISH.back
end

function Layout.finishLineZ(): number
	return Layout.FINISH.back + Layout.FINISH_LINE_INSET
end

return Layout
