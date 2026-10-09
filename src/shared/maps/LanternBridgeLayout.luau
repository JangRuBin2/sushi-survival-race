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
--   다리 4  -108 ~ -138 폭 8(가장 길음, 30), 최대 흔들림 10도(네 다리 중 가장 높음 — "피날레" 다리)
--   결승    -138 ~ -152 폭 16, FinishLine
--
-- 다리는 좌우로(로컬 Z축 기준 roll) 흔들리고, 쉼터·출발·결승은 흔들리지 않아요(고정 평지).
-- 다리 폭 바깥은 바닥이 없어서(판정 파츠 자체가 그 폭만큼만 있어요) 걸어 나가거나 밀리면 자연히 떨어져요.

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

Layout.FINISH = { front = -138, back = -152 } :: Span
Layout.FINISH_WIDTH = 16

Layout.RESTS = {
	{ name = "Rest1", front = -34, back = -44, width = 10 },
	{ name = "Rest2", front = -68, back = -78, width = 10 },
	{ name = "Rest3", front = -98, back = -108, width = 10 },
} :: { RestZone }

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
		front = -108,
		back = -138,
		width = 8,
		halfWidth = 4,
		length = 30,
		maxSwayDeg = 10,
		phase = 3 * math.pi / 2,
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
function Layout.sections(): { Span }
	local list: { Span } = {}
	local function add(front: number, back: number)
		table.insert(list, { front = front, back = back })
	end
	add(Layout.START.front, Layout.START.back)
	add(Layout.BRIDGES[1].front, Layout.BRIDGES[1].back)
	add(Layout.RESTS[1].front, Layout.RESTS[1].back)
	add(Layout.BRIDGES[2].front, Layout.BRIDGES[2].back)
	add(Layout.RESTS[2].front, Layout.RESTS[2].back)
	add(Layout.BRIDGES[3].front, Layout.BRIDGES[3].back)
	add(Layout.RESTS[3].front, Layout.RESTS[3].back)
	add(Layout.BRIDGES[4].front, Layout.BRIDGES[4].back)
	add(Layout.FINISH.front, Layout.FINISH.back)
	return list
end

function Layout.totalLength(): number
	return Layout.START.front - Layout.FINISH.back
end

function Layout.finishLineZ(): number
	return Layout.FINISH.back + Layout.FINISH_LINE_INSET
end

return Layout
