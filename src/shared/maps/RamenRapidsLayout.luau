--!strict
-- "라멘 국물 급류"(m4-04) 코스 치수·튜닝 값 (Roblox API 없음).
-- RamenRapids.build가 이 표대로 회색 박스를 쌓고, RamenRapidsLogic이 판정 계산에 쓰고,
-- tests/map-ramen-rapids.spec.luau가 치수 약속을 확인해요. 수치는 전부 기본값이에요 (플레이테스트로 조정).
--
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(+가 오른쪽 = origin.RightVector), y: 위,
-- z: 0이 출발 끝이고 음수로 갈수록 결승. 출발 바닥 윗면이 y = 0이에요.
--
-- 구간 (z)
--   A 출발        0 ~ -16    폭 24 평지, 스폰 24개
--   B 급류        -16 ~ -126 폭 20, 12도 내리막, 양옆 낮은 벽(3). 바닥이 Broth 태그(앞으로 밀기),
--                            소용돌이 3곳(벽 쪽으로 밀기), 면발 줄기 4개(점프로 넘기)
--   C 토핑        -126 ~ -206 바닥 없음. 가라앉는 차슈 9개 + 고정 나루토 4개
--   D 회전 막대   -206 ~ -276 원형 발판(지름 40) 2개, 가운데 축에서 젓가락 막대가 돌아요
--   E 결승        -276 ~ -300 폭 24, FinishLine

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)
export type Disc = { x: number, z: number } -- 원판 중심
export type Chashu = { x: number, z: number, phase: number } -- phase: 주기 중 위상 (0~1)
export type Whirlpool = { x: number, z: number }
export type Sweeper = { z: number, speed: number, startAngle: number } -- speed: 도/초 (부호 = 방향)

local Layout = {}

-- 구간
Layout.START = { front = 0, back = -16 } :: Span
Layout.RAPIDS = { front = -16, back = -126 } :: Span
Layout.TOPPINGS = { front = -126, back = -206 } :: Span
Layout.SWEEPERS = { front = -206, back = -276 } :: Span
Layout.FINISH = { front = -276, back = -300 } :: Span

-- 공통
Layout.START_WIDTH = 24
Layout.RAPIDS_WIDTH = 20
Layout.FINISH_WIDTH = 24
Layout.FLOOR_THICKNESS = 2
Layout.LOW_WALL_HEIGHT = 3 -- 급류·출발·결승 양옆 벽 (낮아서 옆으로 크게 밀리면 넘어가요)
Layout.END_WALL_HEIGHT = 14 -- 출발 뒤·결승 끝 벽 (넘어가지 않게)
Layout.FALL_MARGIN = 25 -- 그 구간 바닥보다 이만큼 아래로 떨어지면 탈락
Layout.FINISH_LINE_INSET = 4 -- 결승선을 끝 벽보다 이만큼 앞에 둬요

-- B 급류 미끄럼틀
Layout.RAPIDS_SLOPE_DEG = 12
Layout.BROTH_PUSH_SPEED = 14 -- 앞으로 미는 목표 속도 (studs/s)
Layout.BROTH_PUSH_ACCEL = 30 -- 그 속도까지 올리는 가속도 (studs/s^2)
Layout.BROTH_ZONE_HEIGHT = 5 -- 바닥 윗면 위 이 높이 안에 HumanoidRootPart가 있으면 국물 위예요
Layout.WHIRLPOOL_DIAMETER = 8
Layout.WHIRLPOOL_PUSH_SPEED = 10 -- 소용돌이가 벽 쪽으로 미는 목표 속도
Layout.WHIRLPOOL_PUSH_ACCEL = 40
-- 좌우 번갈아 (x 부호 = 미는 벽 쪽)
Layout.WHIRLPOOLS = {
	{ x = 5, z = -42 },
	{ x = -5, z = -72 },
	{ x = 5, z = -100 },
} :: { Whirlpool }
Layout.NOODLE_HEIGHT = 1.5 -- 면발 줄기 굵기 (점프로 넘어요)
Layout.NOODLE_ZS = { -28, -57, -86, -114 }

-- C 토핑 건너기
Layout.BROTH_Y = -31 -- 국물 수면 높이 (C·D·E 구간)
Layout.CHASHU_DIAMETER = 9
Layout.CHASHU_THICKNESS = 1.5
Layout.CHASHU_PERIOD = 6 -- 가라앉았다 떠오르는 주기 (초)
Layout.CHASHU_RANGE = 3 -- 위아래 폭
Layout.CHASHU_LOW = -0.5 -- 가장 낮을 때 윗면 = 수면 + 이 값 (잠김)
Layout.NARUTO_DIAMETER = 7
Layout.NARUTO_THICKNESS = 1.5
Layout.NARUTO_TOP = 1 -- 나루토 윗면 = 수면 + 이 값 (고정)
Layout.NARUTO_SPIN_SPEED = 20 -- 장식 소용돌이 회전 (도/초, 밟는 원판은 고정)
Layout.MAX_JUMP_GAP = 7 -- 건너는 길에서 발판 사이 가로 거리 상한 (AC2)
-- 3줄(왼쪽·가운데·오른쪽) 지그재그. 나란한 차슈는 위상이 어긋나서 둘(셋)이 동시에 잠기지 않아요.
Layout.NARUTOS = {
	{ x = 0, z = -131 },
	{ x = 0, z = -151 },
	{ x = 0, z = -173 },
	{ x = 0, z = -193 },
} :: { Disc }
Layout.CHASHUS = {
	{ x = -6, z = -141, phase = 0 },
	{ x = 6, z = -141, phase = 0.5 },
	{ x = -10, z = -162, phase = 0.15 },
	{ x = 0, z = -162, phase = 0.48 },
	{ x = 10, z = -162, phase = 0.81 },
	{ x = -6, z = -183, phase = 0.3 },
	{ x = 6, z = -183, phase = 0.8 },
	{ x = -6, z = -201, phase = 0.6 },
	{ x = 6, z = -201, phase = 0.1 },
} :: { Chashu }

-- D 회전 젓가락 막대
Layout.PLATFORM_DIAMETER = 40
Layout.PLATFORM_TOP = 1 -- 발판 윗면 = 수면 + 이 값
Layout.HUB_DIAMETER = 4 -- 가운데 축 (높아서 올라설 수 없어요)
Layout.HUB_HEIGHT = 8
Layout.SWEEPER_THICKNESS = 2.5 -- 젓가락 두 짝을 위아래로 겹친 높이
Layout.SWEEPER_CENTER = 1.5 -- 바닥 위 막대 중심 높이
Layout.SWEEPER_LIST = {
	{ z = -226, speed = 40, startAngle = 0 },
	{ z = -256, speed = -55, startAngle = math.pi },
} :: { Sweeper }
Layout.KNOCK_OUTWARD = 32 -- 맞았을 때 바깥으로 (studs/s)
Layout.KNOCK_UP = 20
Layout.KNOCK_HOLD = 0.1 -- 넉백 속도를 강제로 거는 시간 (초)
Layout.KNOCKDOWN_TIME = 1 -- 넘어져 있는 시간 = 같은 플레이어 재피격 쿨다운

-- E 결승: 발판과 같은 높이. 바닥은 마지막 원판과 겹치게 조금 앞에서 시작해요.
Layout.FINISH_FLOOR_OVERLAP = 6

-- 스폰 24개 (6열 × 4줄)
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_SPACING = 3.6

-- 이동 감시 예외 표시 간격 (밀기는 매 프레임이라 속성을 매번 쓰지 않게)
Layout.EXEMPT_REFRESH = 0.5

function Layout.sections(): { Span }
	return { Layout.START, Layout.RAPIDS, Layout.TOPPINGS, Layout.SWEEPERS, Layout.FINISH }
end

function Layout.totalLength(): number
	return Layout.START.front - Layout.FINISH.back
end

function Layout.finishLineZ(): number
	return Layout.FINISH.back + Layout.FINISH_LINE_INSET
end

-- 급류 끝(가장 낮은 곳) 높이
function Layout.rapidsDrop(): number
	return (Layout.RAPIDS.front - Layout.RAPIDS.back) * math.tan(math.rad(Layout.RAPIDS_SLOPE_DEG))
end

-- 급류 위 로컬 z의 바닥 윗면 높이
function Layout.rapidsHeightAt(z: number): number
	local along = math.clamp(Layout.RAPIDS.front - z, 0, Layout.RAPIDS.front - Layout.RAPIDS.back)
	return -along * math.tan(math.rad(Layout.RAPIDS_SLOPE_DEG))
end

function Layout.platformTop(): number
	return Layout.BROTH_Y + Layout.PLATFORM_TOP
end

function Layout.narutoTop(): number
	return Layout.BROTH_Y + Layout.NARUTO_TOP
end

-- 스폰 위치 (로컬 x, z). 출발 구간 안에 6열 × 4줄.
function Layout.spawnPositions(): { { x: number, z: number } }
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

return Layout
