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

-- 무대·꼬치 치수 (studs)
Logic.STAGE_RADIUS = 22 -- 지름 44 (팔각형 근사: 조각마다 직사각형 띠를 이어 붙여요)
Logic.PILLAR_DIAMETER = 5
local SKEWER_RADIUS = 0.6 -- 굵기 1.2
Logic.LOW_SKEWER = {
	height = 1.75,
	radius = SKEWER_RADIUS,
	innerReach = Logic.PILLAR_DIAMETER / 2,
	outerReach = Logic.STAGE_RADIUS,
} :: SkewerSpec
Logic.HIGH_SKEWER = {
	height = 6.8,
	radius = SKEWER_RADIUS,
	innerReach = Logic.PILLAR_DIAMETER / 2,
	outerReach = Logic.STAGE_RADIUS,
} :: SkewerSpec

-- 시작 각도. 꼬치는 각도가 커지는 방향으로 돌아요.
Logic.LOW_START_ANGLE = 0
Logic.HIGH_START_ANGLE = math.pi -- 낮은 꼬치와 반대쪽 (10초에 등장)

-- 스폰: 반지름 SPAWN_RADIUS 원 위. 낮은 꼬치 시작 각도 바로 앞(회전 방향) SPAWN_CLEAR_ARC는 비워 둬서
-- 어느 스폰에 서 있어도 시작 직후 바로 맞지 않아요 (QA B1: 반 칸 7.5°만 비켜서 0.017초에 맞았음).
-- 45°/s에서 90° 비우면 가장 먼저 맞는 스폰도 약 2초 뒤에 꼬치가 와요.
Logic.SPAWN_RADIUS = 14
Logic.SPAWN_CLEAR_ARC = math.rad(90)
-- 시작 각도 바로 뒤도 조금 비워요 (맞음 판정 여유 약 6.5° 안이면 첫 프레임에 맞아요)
Logic.SPAWN_CLEAR_BEHIND = math.rad(15)
-- 앞 번호부터 써도 고르게 흩어지는 칸 순서 (2명 → 반대편쯤, 4명 → 4등분, 8명 → 8등분)
Logic.SPAWN_SLOT_ORDER = {
	0,
	12,
	6,
	18,
	3,
	15,
	9,
	21,
	1,
	13,
	7,
	19,
	4,
	16,
	10,
	22,
	2,
	14,
	8,
	20,
	5,
	17,
	11,
	23,
}

-- 스폰 이름순(Spawn01, Spawn02, ...)의 각도 목록. count는 SPAWN_SLOT_ORDER 길이(24) 이하.
-- 칸은 비워 둔 앞쪽 90°·뒤쪽 15°를 뺀 나머지(255°)를 24칸으로 고르게 나눈 것이에요.
function Logic.spawnAngles(count: number): { number }
	local slots = #Logic.SPAWN_SLOT_ORDER
	assert(count <= slots, "not enough spawn slots")
	local usable = TAU - Logic.SPAWN_CLEAR_ARC - Logic.SPAWN_CLEAR_BEHIND
	local angles = {}
	for i = 1, count do
		local slot = Logic.SPAWN_SLOT_ORDER[i]
		table.insert(angles, Logic.LOW_START_ANGLE + Logic.SPAWN_CLEAR_ARC + (slot + 0.5) * usable / slots)
	end
	return angles
end

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
