--!strict
-- 초밥 캐릭터 작은 움직임 (m5-25, 순수 — Roblox API 없음, lune 테스트). 클라이언트 CharacterFxController가
-- 프레임마다 pose(...)를 받아 SushiJoint(몸 전체)와 파츠 Motor6D(눈·감은 눈·발, SushiBody.PART_JOINT_NAME)의
-- Transform으로만 써요. 판정·서버와 무관하고 복제되지 않아요.
--   숨쉬기: 서 있을 때 몸이 천천히 위아래 (발은 땅에 그대로)
--   깜빡임: 2.2~5초마다 0.13초 눈을 밥 속으로 넣고 감은 눈 선을 꺼내요. 넘어진 동안은 계속 감아요.
--   점프: 올라가는 동안 몸이 살짝 늘어나고(몸 위로, 발은 아래로), 착지하면 0.22초 찌그러져요(몸이 발 쪽으로 내려앉음)
--   걷기: 발이 번갈아 들리고 앞뒤로 움직여요. 몸 통통 튀기(예전 그대로)만큼 발은 반대로 내려 땅에 붙어 보여요.
--   팔 흔들기 (m5-27): 팔이 있는 스킨(ArmLeft/ArmRight 관절, 실험 스킨 concept-salmon)만 — 걸음과 엇갈려 앞뒤로.
-- 크기 변형(스케일)은 쓰지 않아요 — Motor6D 이동만으로 늘어남·찌그러짐을 흉내 내요 (파츠 크기를 프레임마다 바꾸면
-- 24명에서 비싸고 용접이 흔들려요).

local CharacterAnimLogic = {}

CharacterAnimLogic.BLINK_MIN = 2.2 -- 깜빡임 간격 (초)
CharacterAnimLogic.BLINK_MAX = 5.0
CharacterAnimLogic.BLINK_DURATION = 0.13
CharacterAnimLogic.EYE_HIDE = 0.45 -- 깜빡일 때 눈을 뒤(+Z)로 넣는 거리
CharacterAnimLogic.LID_SHOW = 0.3 -- 감은 눈 선을 앞(-Z)으로 꺼내는 거리
CharacterAnimLogic.BREATH_RATE = 2 * math.pi * 0.45 -- rad/s (0.45 Hz)
CharacterAnimLogic.BREATH_HEIGHT = 0.05
CharacterAnimLogic.STEP_LIFT = 0.28 -- 걸을 때 발이 들리는 높이 (걷기 1배)
CharacterAnimLogic.STEP_STRIDE = 0.3 -- 걸을 때 발이 앞뒤로 움직이는 거리
CharacterAnimLogic.SQUASH_TIME = 0.22
CharacterAnimLogic.SQUASH_DEPTH = 0.32 -- 착지 찌그러짐 때 몸이 내려앉는 최대 거리
CharacterAnimLogic.SQUASH_MIN_FALL = 8 -- 이보다 느리게 내려오면 찌그러지지 않아요 (계단 등)
CharacterAnimLogic.STRETCH_RISE = 0.14 -- 올라갈 때 몸이 위로
CharacterAnimLogic.STRETCH_FEET = 0.25 -- 올라갈 때 발이 아래로 (매달림)
CharacterAnimLogic.STRETCH_SPEED = 30 -- 이 상승 속도에서 늘어남 1배
CharacterAnimLogic.FOOT_MIN = -0.35 -- 발 오프셋 한계 (몸에서 떨어져 보이지 않게)
CharacterAnimLogic.FOOT_MAX = 0.45 -- (몸 속으로 너무 들어가지 않게)
CharacterAnimLogic.ARM_SWING = math.rad(35) -- 걷기 1배일 때 팔 앞뒤 흔들기 최대 각 (m5-27)
CharacterAnimLogic.DETAIL_DISTANCE = 60 -- 카메라에서 이보다 멀면 작은 움직임은 끄고 기본 자세

export type Offset = { y: number, z: number }

export type Pose = {
	bodyY: number, -- SushiJoint에 더하는 위아래 (걷기 통통과 별개)
	eyesBack: number, -- 눈(테두리)을 뒤로 넣는 거리 (0 = 뜸)
	lidForward: number, -- 감은 눈 선을 앞으로 꺼내는 거리 (0 = 숨음)
	footLeft: Offset, -- Body 기준 발 이동
	footRight: Offset,
	armSwing: number, -- 오른팔이 앞으로 가는 각(rad, 왼팔은 반대). 왼발이 앞일 때 오른팔이 앞 (m5-27)
}

export type Input = {
	time: number, -- 계속 늘어나는 시계 (숨쉬기)
	idle: number, -- 0~1, 서 있는 정도 (1 = 가만히)
	walk: number, -- 0~1.3, 걷기 세기 (CharacterFxController의 walk)
	phase: number, -- 걷기 위상 (rad)
	bounce: number, -- 이번 프레임 걷기 통통 높이 (몸 전체가 올라간 양)
	blinking: boolean,
	knocked: boolean,
	riseSpeed: number, -- 올라가는 속도 (studs/s, 공중이고 올라갈 때만 양수, 아니면 0)
	landTime: number?, -- 착지 뒤 지난 시간 (찌그러짐 중이면), 아니면 nil
	landStrength: number, -- 0~1, 떨어지던 속도로 정한 찌그러짐 세기
}

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- 다음 깜빡임까지 기다릴 시간. r은 0~1 난수 (테스트에서 고정)
function CharacterAnimLogic.nextBlinkDelay(r: number): number
	local t = clamp(r, 0, 1)
	return CharacterAnimLogic.BLINK_MIN + (CharacterAnimLogic.BLINK_MAX - CharacterAnimLogic.BLINK_MIN) * t
end

-- 깜빡임 시작 뒤 elapsed초에 눈을 감고 있는지
function CharacterAnimLogic.blinkClosed(elapsed: number): boolean
	return elapsed >= 0 and elapsed < CharacterAnimLogic.BLINK_DURATION
end

-- 숨쉬기 몸 높이 (서 있는 정도 idle 0~1에 비례)
function CharacterAnimLogic.breath(time: number, idle: number): number
	return math.sin(time * CharacterAnimLogic.BREATH_RATE) * CharacterAnimLogic.BREATH_HEIGHT * clamp(idle, 0, 1)
end

-- 떨어지던 속도(아래로 양수) → 찌그러짐 세기 0~1
function CharacterAnimLogic.landStrength(fallSpeed: number): number
	if fallSpeed < CharacterAnimLogic.SQUASH_MIN_FALL then
		return 0
	end
	return clamp(fallSpeed / 40, 0.4, 1)
end

-- 착지 뒤 t초의 몸 내려앉음 (0 → 깊이 → 0, 빨리 내려가고 천천히 돌아와요)
function CharacterAnimLogic.squash(t: number, strength: number): number
	local T = CharacterAnimLogic.SQUASH_TIME
	if t < 0 or t >= T or strength <= 0 then
		return 0
	end
	local u = t / T
	local curve = if u < 0.3 then u / 0.3 else 1 - (u - 0.3) / 0.7
	return CharacterAnimLogic.SQUASH_DEPTH * clamp(strength, 0, 1) * curve * curve * (3 - 2 * curve)
end

-- 올라갈 때 늘어남 0~1
function CharacterAnimLogic.stretch(riseSpeed: number): number
	return clamp(riseSpeed / CharacterAnimLogic.STRETCH_SPEED, 0, 1)
end

function CharacterAnimLogic.pose(input: Input): Pose
	local A = CharacterAnimLogic
	local closed = input.blinking or input.knocked
	local stretch = A.stretch(input.riseSpeed)
	local squash = if input.landTime then A.squash(input.landTime, input.landStrength) else 0
	local breath = if input.knocked then 0 else A.breath(input.time, input.idle)
	local bodyY = breath + stretch * A.STRETCH_RISE - squash

	-- 발: 몸이 오르내린 만큼 반대로 (땅에 붙어 보이게) + 걷기 걸음. 공중이면 아래로 매달려요.
	local ground = -(input.bounce + bodyY)
	local walk = clamp(input.walk, 0, 1.3)
	local function foot(sign: number): Offset
		if input.knocked then
			return { y = 0, z = 0 }
		end
		local s = math.sin(input.phase) * sign
		local lift = math.max(0, s) * A.STEP_LIFT * walk
		local z = -math.cos(input.phase) * sign * A.STEP_STRIDE * walk
		local y = ground + lift - stretch * A.STRETCH_FEET
		return { y = clamp(y, A.FOOT_MIN, A.FOOT_MAX), z = z }
	end

	-- 팔: 왼발이 앞(z < 0, cos(phase) > 0)일 때 오른팔이 앞으로
	local armSwing = if input.knocked then 0 else math.cos(input.phase) * A.ARM_SWING * walk

	return {
		armSwing = armSwing,
		bodyY = bodyY,
		eyesBack = if closed then A.EYE_HIDE else 0,
		lidForward = if closed then A.LID_SHOW else 0,
		footLeft = foot(1),
		footRight = foot(-1),
	}
end

return CharacterAnimLogic
