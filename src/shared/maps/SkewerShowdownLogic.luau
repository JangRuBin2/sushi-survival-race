--!strict
-- "회전 꼬치 쇼다운"(m2-04)의 순수 로직: 시간에 따른 꼬치 속도, 셰프 손이 조각을 가져가는 일정,
-- 꼬치에 맞았는지 판정하는 기하 계산. Roblox API를 쓰지 않아서 Lune 테스트에서 그대로 불러요.
-- 수치는 전부 초기값이에요 (스펙 표, 플레이테스트로 조정).
--
-- 좌표 약속: 무대 중심 기준 로컬 (dx, dz), 높이는 무대 윗면 기준 y.
-- 꼬치 각도 θ는 CFrame.Angles(0, θ, 0)이 로컬 X축을 돌린 방향이에요 → 방향 벡터 (cos θ, -sin θ).
-- 그래서 점 (dx, dz)의 각도는 atan2(-dz, dx)예요 (angleOf).

local Logic = {}

local TAU = 2 * math.pi

-- 시간 일정 (초)
Logic.HIGH_SKEWER_AT = 10 -- 높은 꼬치 등장
Logic.HAND_START_AT = 20 -- 셰프 손 첫 등장
Logic.HAND_INTERVAL = 8 -- 서든데스 전 손 간격
Logic.SUDDEN_DEATH_AT = 60 -- 서든데스 시작
Logic.SUDDEN_DEATH_INTERVAL = 3 -- 서든데스 손 간격
Logic.SLICES_BEFORE_SUDDEN_DEATH = 2 -- 서든데스 전에는 이만큼 남을 때까지만 가져가요
Logic.SLICES_AT_END = 1 -- 서든데스에서는 이만큼 남을 때까지
Logic.SLICE_COUNT = 8

-- 꼬치 속도 (도/초). 낮은 꼬치: 45 → (10~60초 동안 서서히) 100 → 서든데스 150.
-- 높은 꼬치: 10초에 30으로 등장 → 80 → 서든데스 120. 두 꼬치 속도가 달라서 겹치는 각도가 계속 바뀌어요.
Logic.LOW_SPEED_START = 45
Logic.LOW_SPEED_RAMP_END = 100
Logic.LOW_SPEED_MAX = 150
Logic.HIGH_SPEED_START = 30
Logic.HIGH_SPEED_RAMP_END = 80
Logic.HIGH_SPEED_MAX = 120

-- 캐릭터 몸통 범위 (HumanoidRootPart 중심 기준, R15/R6 기본 체형 근사)
Logic.BODY_BELOW_ROOT = 3 -- 발바닥까지
Logic.BODY_ABOVE_ROOT = 2.3 -- 머리 끝까지
Logic.BODY_RADIUS = 1 -- 수평 반지름

export type SkewerSpec = {
	height: number, -- 무대 윗면에서 꼬치 중심까지 높이
	radius: number, -- 꼬치 굵기의 반
	innerReach: number, -- 중심에서 꼬치가 시작하는 거리 (기둥 반지름)
	outerReach: number, -- 중심에서 꼬치 끝까지 거리
}

export type Speeds = { low: number, high: number }

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * math.clamp(alpha, 0, 1)
end

-- 경과 시간 → 꼬치 속도 (도/초). 높은 꼬치는 등장 전에는 0이에요.
function Logic.speeds(elapsed: number): Speeds
	if elapsed >= Logic.SUDDEN_DEATH_AT then
		return { low = Logic.LOW_SPEED_MAX, high = Logic.HIGH_SPEED_MAX }
	end
	if elapsed < Logic.HIGH_SKEWER_AT then
		return { low = Logic.LOW_SPEED_START, high = 0 }
	end
	local alpha = (elapsed - Logic.HIGH_SKEWER_AT) / (Logic.SUDDEN_DEATH_AT - Logic.HIGH_SKEWER_AT)
	return {
		low = lerp(Logic.LOW_SPEED_START, Logic.LOW_SPEED_RAMP_END, alpha),
		high = lerp(Logic.HIGH_SPEED_START, Logic.HIGH_SPEED_RAMP_END, alpha),
	}
end

function Logic.highSkewerActive(elapsed: number): boolean
	return elapsed >= Logic.HIGH_SKEWER_AT
end

-- 경과 시간 → 다음 손까지 간격(초). 손이 아직 안 나오는 시간이면 nil.
function Logic.handInterval(elapsed: number): number?
	if elapsed < Logic.HAND_START_AT then
		return nil
	end
	if elapsed >= Logic.SUDDEN_DEATH_AT then
		return Logic.SUDDEN_DEATH_INTERVAL
	end
	return Logic.HAND_INTERVAL
end

-- 그 시간에 남겨 둬야 하는 최소 조각 수
function Logic.minSlices(elapsed: number): number
	if elapsed >= Logic.SUDDEN_DEATH_AT then
		return Logic.SLICES_AT_END
	end
	return Logic.SLICES_BEFORE_SUDDEN_DEATH
end

-- 조각 sliceCount개에서 시작할 때 손이 조각을 "고르는"(경고 시작) 시각 목록.
-- 20초부터 8초마다, 2조각이 남으면 서든데스(60초)까지 기다렸다가 3초마다 1조각이 남을 때까지.
function Logic.grabTimes(sliceCount: number): { number }
	local times = {}
	local remaining = sliceCount
	local t = Logic.HAND_START_AT
	while remaining > Logic.SLICES_AT_END do
		if remaining <= Logic.minSlices(t) then
			t = math.max(t, Logic.SUDDEN_DEATH_AT)
			continue
		end
		table.insert(times, t)
		remaining -= 1
		t += Logic.handInterval(t) :: number
	end
	return times
end

-- 무대 중심 기준 점 (dx, dz)의 각도 (라디안, 꼬치 각도와 같은 기준)
function Logic.angleOf(dx: number, dz: number): number
	return math.atan2(-dz, dx)
end

-- 각도 phi가 from → to(증가 방향)로 쓸고 지나간 구간에 margin만큼 넓혀서 들어가는지.
-- 한 프레임에 한 바퀴 넘게 돌면(멈칫 뒤 큰 dt) 전 구간으로 봐요.
function Logic.angleSwept(phi: number, from: number, to: number, margin: number): boolean
	local sweep = to - from
	if sweep < 0 then
		from, to = to, from
		sweep = -sweep
	end
	if sweep + 2 * margin >= TAU then
		return true
	end
	local offset = (phi - (from - margin)) % TAU
	return offset <= sweep + 2 * margin
end

-- 꼬치가 이번 프레임에 from → to 각도로 돌면서 이 캐릭터에 닿았는지.
-- dx, dz: 무대 중심 기준 HumanoidRootPart 수평 위치, rootY: 무대 윗면 기준 HumanoidRootPart 높이.
function Logic.isHit(dx: number, dz: number, rootY: number, from: number, to: number, skewer: SkewerSpec): boolean
	-- 높이: 몸통(발~머리)과 꼬치 굵기가 겹쳐야 해요. 서 있으면 낮은 꼬치만, 높이 뛰면 높은 꼬치에 닿아요.
	local feet = rootY - Logic.BODY_BELOW_ROOT
	local head = rootY + Logic.BODY_ABOVE_ROOT
	if feet > skewer.height + skewer.radius or head < skewer.height - skewer.radius then
		return false
	end
	-- 거리: 꼬치가 닿는 반지름 범위 안이어야 해요.
	local distance = math.sqrt(dx * dx + dz * dz)
	local reach = skewer.radius + Logic.BODY_RADIUS
	if distance > skewer.outerReach + reach or distance < skewer.innerReach - reach then
		return false
	end
	-- 각도: 이번 프레임에 꼬치가 쓸고 지나간 각도 범위 안에 몸통이 걸쳐 있어야 해요.
	local margin = math.min(reach / math.max(distance, 0.001), math.pi)
	return Logic.angleSwept(Logic.angleOf(dx, dz), from, to, margin)
end

return Logic
