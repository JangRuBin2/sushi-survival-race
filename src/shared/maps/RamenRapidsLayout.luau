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
--   F 젓가락 다리 -276 ~ -336 (m5-40) 유부 뗏목 → 나란한 각진 젓가락 2개(폭 1.6) → 젓가락 받침 → X자로 엇갈린 젓가락 2개
--   G 렌게 계단   -336 ~ -372 (m5-40) 고정 숟가락(렌게) 발판 4개 오르막, 마지막 발판이 두 번째 급류 꼭대기와 이어져요
--   H 두 번째 급류 -372 ~ -422 (m5-40) 길이 50, 12도 내리막 Broth 밀기 + 면발 줄기 2개 (소용돌이 없음)
--   E 결승        -422 ~ -446 폭 24, FinishLine
-- m5-40: 결승 구간을 맨 끝에 둔 채 D와 E 사이에 F·G·H를 끼웠어요. A~D의 치수·장애물 수치는 그대로예요.

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
Layout.CHOPSTICKS = { front = -276, back = -336 } :: Span -- m5-40 F
Layout.RENGE_STAIRS = { front = -336, back = -372 } :: Span -- m5-40 G
Layout.RAPIDS2 = { front = -372, back = -422 } :: Span -- m5-40 H
Layout.FINISH = { front = -422, back = -446 } :: Span

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
-- 앞으로 미는 목표 속도 (studs/s). 걷기(16)보다 빨라서 앞으로 달려도 더 밀려요 (QA R2).
-- 소용돌이 옆 밀기(10)를 합쳐도 약 22 studs/s라 이동 감시 상한(MovementGuard.MaxHorizontalSpeed)보다 한참 낮고,
-- 표시 없이도 감시 기준 안이라 밀기에는 MoveExempt.mark를 하지 않아요 (m4-10 QA B1: 면제 중엔 속도 조작이 안 잡혀요).
Layout.BROTH_PUSH_SPEED = 20
Layout.BROTH_PUSH_ACCEL = 40 -- 그 속도까지 올리는 가속도 (studs/s^2)
Layout.WHIRLPOOL_FORWARD_SPEED = 14 -- 소용돌이 안에서는 앞 밀기를 이만큼으로 줄여요 (옆으로 쏠리게, AC4)
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
-- 급류 끝 바로 아래 넓은 착지판 (나루토와 같은 높이, 급류보다 넓어요). 급류 끝선에서 걸어 나가도,
-- 점프해도 여기 떨어져요 (QA R1). 깊이는 밀기 최고 속도로 점프했을 때 비행 거리 + 여유.
Layout.LANDING = { front = -126, back = -142, width = 24 }
-- 3줄(왼쪽·가운데·오른쪽) 지그재그, 줄 간격 9. 나란한 차슈는 위상이 어긋나서 둘(셋)이 동시에 잠기지 않아요.
-- 착지판 → 차슈 2 → 나루토 → 차슈 3 → 나루토 → 차슈 2 → 나루토 → 차슈 2 → 회전 발판.
-- 첫 나루토(왼쪽)는 착지판 옆 갈림길이에요. 나루토끼리는 7보다 멀어서 차슈를 꼭 밟아야 해요.
Layout.NARUTOS = {
	{ x = -17, z = -147 },
	{ x = 0, z = -156 },
	{ x = 0, z = -174 },
	{ x = 0, z = -192 },
} :: { Disc }
Layout.CHASHUS = {
	{ x = -6, z = -147, phase = 0 },
	{ x = 6, z = -147, phase = 0.5 },
	{ x = -10, z = -165, phase = 0.15 },
	{ x = 0, z = -165, phase = 0.48 },
	{ x = 10, z = -165, phase = 0.81 },
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

-- E 결승: 발판과 같은 높이. 바닥은 앞 구간(m5-40부터 두 번째 급류 끝) 아래로 조금 겹치게 앞에서 시작해요.
Layout.FINISH_FLOOR_OVERLAP = 6

-- F 젓가락 다리 (m5-40). 높이는 전부 회전 발판과 같아요(platformTop). 젓가락은 윗면이 평평한 각진 막대(1.6 x 1.6)라
-- 원기둥보다 덜 미끄러지고, 좁아서 균형이 필요해요. 떨어지면 국물 아래로 → 낙하선.
-- 유부 뗏목: 마지막 회전 원판과 겹치게 시작 (예전 결승 바닥 자리). 회전 막대 끝(반지름 20)은 이 겹친 곳까지 와요.
Layout.CHOP_RAFT = { front = -270, back = -284, width = 24 }
Layout.CHOPSTICK_WIDTH = 1.6
Layout.CHOPSTICK_THICKNESS = 1.6
-- 첫 쌍: 나란한 두 줄 (가운데 사이 6 — 한 사람이 한 줄씩)
Layout.CHOP_PAIR1 = { front = -284, back = -308, xs = { -3, 3 } }
-- 젓가락 받침(하시오키): 쉬어 가는 도자기 받침
Layout.CHOP_REST = { front = -308, back = -314, width = 14 }
-- 둘째 쌍: X자로 엇갈려요 (앞 끝 x ±4.5 → 뒤 끝 x ∓4.5). 가운데에서 만나 줄을 바꿀 수 있어요.
Layout.CHOP_PAIR2 = { front = -314, back = -336, spread = 4.5 }

-- G 렌게 계단 (m5-40): 고정 숟가락 발판 4개, 한 칸마다 rapids2Drop() / 4씩 올라요(약 2.66 — 점프 높이 6.4의 절반 아래).
-- 앞뒤 틈 2, 좌우로 조금씩 엇갈려요. 마지막 발판은 넓고, 뒤 끝이 두 번째 급류 꼭대기(같은 높이)와 붙어 있어요.
export type RengeStep = { x: number, front: number, back: number, width: number }
Layout.RENGE_STEP_THICKNESS = 2
Layout.RENGE_STEPS = {
	{ x = 0, front = -338, back = -345, width = 8 },
	{ x = -3, front = -347, back = -354, width = 8 },
	{ x = 3, front = -356, back = -363, width = 8 },
	{ x = 0, front = -365, back = -372, width = 14 },
} :: { RengeStep }

-- H 두 번째 급류 (m5-40): 첫 급류와 같은 기울기·폭·밀기(BROTH_PUSH_SPEED 20), 짧게. 소용돌이는 없어요.
Layout.RAPIDS2_WIDTH = 20
Layout.RAPIDS2_NOODLE_ZS = { -388, -406 }

-- 길이 추정 (m5-40 AC1): 1번 줄 스폰 → 결승선을 걷기 16으로 + 구간별 지연(초, 빠른 사람 기준, Studio 실측으로 조정).
-- 급류는 밀기 20이 걷기보다 빨라서 지연이 음수예요.
Layout.WALK_SPEED = 16
Layout.SECTION_DELAY = {
	RAPIDS = -1.4, -- 110 studs를 20으로 (110/16 - 110/20)
	TOPPINGS = 7, -- 차슈 잠김 타이밍 기다림 + 점프 7~9번
	SWEEPERS = 3.5, -- 막대 두 개 피하기 (점프·기다림)
	CHOPSTICKS = 5, -- 좁은 젓가락 위 균형 (걷기를 늦춰요) + 쌍 사이 갈아타기
	RENGE_STAIRS = 2.5, -- 오르막 점프 4번
	RAPIDS2 = -0.6, -- 50 studs를 20으로
} :: { [string]: number }

-- 스폰 24개 (6열 × 4줄)
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_SPACING = 3.6

function Layout.sections(): { Span }
	return {
		Layout.START,
		Layout.RAPIDS,
		Layout.TOPPINGS,
		Layout.SWEEPERS,
		Layout.CHOPSTICKS,
		Layout.RENGE_STAIRS,
		Layout.RAPIDS2,
		Layout.FINISH,
	}
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

-- 두 번째 급류 높이차 (m5-40): 렌게 계단이 이만큼 오르고 급류가 이만큼 내려가 결승은 회전 발판 높이예요.
function Layout.rapids2Drop(): number
	return (Layout.RAPIDS2.front - Layout.RAPIDS2.back) * math.tan(math.rad(Layout.RAPIDS_SLOPE_DEG))
end

-- 두 번째 급류 위 로컬 z의 바닥 윗면 높이
function Layout.rapids2HeightAt(z: number): number
	local along = math.clamp(Layout.RAPIDS2.front - z, 0, Layout.RAPIDS2.front - Layout.RAPIDS2.back)
	return Layout.platformTop() + Layout.rapids2Drop() - along * math.tan(math.rad(Layout.RAPIDS_SLOPE_DEG))
end

-- 렌게 발판 i의 윗면 높이 (마지막 발판 = 두 번째 급류 꼭대기)
function Layout.rengeStepTop(i: number): number
	return Layout.platformTop() + Layout.rapids2Drop() * i / #Layout.RENGE_STEPS
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
