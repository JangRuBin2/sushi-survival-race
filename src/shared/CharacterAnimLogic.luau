--!strict
-- 초밥 캐릭터 작은 움직임 (m5-25, 순수 — Roblox API 없음, lune 테스트). 클라이언트 CharacterFxController가
-- 프레임마다 pose(...)를 받아 SushiJoint(몸 전체)와 파츠 Motor6D(눈·감은 눈·발, SushiBody.PART_JOINT_NAME)의
-- Transform으로만 써요. 판정·서버와 무관하고 복제되지 않아요.
--   숨쉬기: 서 있을 때 몸이 천천히 위아래 (발은 땅에 그대로)
--   깜빡임: 2.2~5초마다 0.13초 눈을 밥 속으로 넣고 감은 눈 선을 꺼내요. 넘어진 동안은 계속 감아요.
--   점프: 올라가는 동안 몸이 살짝 늘어나고(몸 위로, 발은 아래로), 착지하면 0.22초 찌그러져요(몸이 발 쪽으로 내려앉음)
--   걷기: 발이 번갈아 들리고 앞뒤로 움직여요. 몸 통통 튀기(예전 그대로)만큼 발은 반대로 내려 땅에 붙어 보여요.
--   팔 흔들기 (m5-27): 팔이 있는 스킨(ArmLeft/ArmRight 관절, 실험 스킨 concept-salmon)만 — 걸음과 엇갈려 앞뒤로.
--   물고기 팔딱 (m5-32, FISH·fishPose·fishMotion): 고등어 관절(FishRoot·FishMid·FishTail·FishFin*·Splash*)이 있는
--   스킨만 — 서 있으면 꼬리 살랑 + 가끔 팔딱(들썩·아치·꼬리 파닥·물방울), 달리면 걸음 2배로 꼬리, 점프하면 C자 아치,
--   착지하면 큰 팔딱, 넘어지면 빠르게 퍼덕. 인형(DollAnimator)은 mode로 Hurt·Victory·Preview. 관절 이름으로만 움직여요.
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

---------------------------------------------------------------- 물고기 팔딱 (m5-32)
-- 각도는 라디안, 거리는 studs. 값은 스펙 기본값 (m5-32 스펙 "팔딱 움직임"), 바꾼 값은 결정 기록에.
local rad = math.rad
local TAU = 2 * math.pi

export type FishMode = "Character" | "Idle" | "Hurt" | "Victory" | "Preview"

CharacterAnimLogic.FISH = {
	-- 서 있음: 꼬리 살랑 + 뒷몸이 반 박자 늦게
	SWAY_HZ = 1.2,
	SWAY_TAIL = rad(8),
	SWAY_MID = rad(3),
	SWAY_LAG = math.pi / 2,
	FIN_HZ = 2.4, -- 가슴지느러미 팔랑
	FIN_IDLE = rad(10),
	FIN_FLOP = rad(28),
	-- 가끔 팔딱 (flopTime 0 → FLOP_TIME)
	FLOP_TIME = 0.6,
	FLOP_HZ = 6,
	FLOP_TAIL = rad(35),
	FLOP_MID = rad(14),
	FLOP_LIFT = 0.4,
	FLOP_ROOT_ARCH = rad(16),
	FLOP_MID_ARCH = rad(8),
	FLOP_TAIL_ARCH = rad(9),
	FLOP_TWIST = rad(10),
	-- 달리기: 걸음 위상의 2배
	RUN_MIN_WALK = 0.2, -- 이보다 빨리 걸으면 새 팔딱을 시작하지 않아요
	RUN_TAIL = rad(22),
	RUN_MID = rad(9),
	RUN_LAG = 0.8,
	-- 점프 올라갈 때 C자 아치 (stretch에 비례)
	JUMP_ROOT_ARCH = rad(12),
	JUMP_MID_ARCH = rad(9),
	JUMP_TAIL_ARCH = rad(11),
	-- 착지 큰 팔딱 (착지 LAND_DELAY 뒤 LAND_TIME 동안, 꼬리 두 번 탁탁)
	LAND_DELAY = 0.08,
	LAND_TIME = 0.5,
	LAND_HZ = 4,
	LAND_TAIL = rad(40),
	LAND_MID = rad(14),
	LAND_LIFT = 0.45,
	LAND_ROOT_ARCH = rad(15),
	LAND_MID_ARCH = rad(8),
	LAND_TAIL_ARCH = rad(9),
	LAND_TWIST = rad(8),
	-- 넘어짐: 물 밖 물고기처럼
	KNOCK_HZ = 7,
	KNOCK_TAIL = rad(30),
	KNOCK_MID = rad(12),
	-- 탈락 인형: 축 처짐 + 가끔 약한 경련
	HURT_ROOT_ARCH = 0, -- 머리는 밥 위에 그대로 (처지면 밥 윗면 - 0.2 아래로 내려가요)
	HURT_MID_ARCH = rad(-4),
	HURT_TAIL_ARCH = rad(-6),
	HURT_SWAY = 0.25, -- 살랑 비율 (거의 멈춤)
	TWITCH_TIME = 0.3,
	TWITCH_HZ = 6,
	TWITCH_TAIL = rad(15),
	TWITCH_MID = rad(5),
	-- 한도
	MAX_TAIL = rad(40),
	MAX_MID = rad(16),
	MAX_ARCH = rad(20),
	MAX_LIFT = 0.45,
	MAX_TWIST = rad(12),
	MAX_HZ = 7,
	BLEND_TIME = 0.15, -- 넘어짐·공중 상태가 바뀔 때 섞는 시간
	-- 팔딱 간격 (초, r 0~1 → lo~hi)
	DELAYS = {
		Character = { 2.5, 6 },
		Idle = { 2.5, 6 },
		Victory = { 1.0, 1.6 },
		Preview = { 1.5, 3 },
		Hurt = { 1.5, 2.5 },
	} :: { [string]: { number } },
	-- 소리 (사용자 결정 3차): 같은 캐릭터당 이 간격 안에 다시 안 울려요
	SOUND_GAP = 0.25,
}

-- 섞기 상태 (넘어짐·공중 0~1). 프레임마다 fishBlend로 목표에 일정 속도로 다가가요
export type FishBlend = { knock: number, air: number }

export type FishInput = {
	time: number, -- 계속 늘어나는 시계 (살랑·퍼덕)
	walk: number, -- 0~1.3 (CharacterFxController의 walk, 이미 부드러움)
	phase: number, -- 걷기 위상 (rad)
	riseSpeed: number, -- 올라가는 속도 (공중이고 올라갈 때만 양수)
	airborne: boolean,
	landTime: number?, -- 착지 뒤 지난 시간 (LAND_DELAY + LAND_TIME 동안), 아니면 nil
	landStrength: number, -- 0~1 (CharacterAnimLogic.landStrength)
	knocked: boolean,
	flopTime: number?, -- 가끔 팔딱 시작 뒤 지난 시간 (팔딱 중이면), 아니면 nil
	mode: FishMode,
	blend: FishBlend?, -- 없으면 섞지 않고 지금 상태 그대로 (테스트·렌더 포즈)
}

export type FishPose = {
	rootLift: number, -- FishRoot 들썩 (위 +)
	rootArch: number, -- FishRoot Z축 (+면 머리가 위로)
	rootTwist: number, -- FishRoot X축 비틀림
	midYaw: number, -- FishMid Y축 (좌우)
	midArch: number, -- 뒷몸 휨 (+면 꼬리 쪽이 위로)
	tailYaw: number, -- FishTail Y축 (좌우 파닥)
	tailArch: number, -- 꼬리 휨 (+면 위로)
	finFlap: number, -- 가슴지느러미 벌림 (0 이상)
	splash: number, -- 물방울 0~1
}

local function smooth01(x: number): number
	local t = clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 한 번 팔딱의 모양 (u = 지난 시간 / 길이, 0~1): 앞 12%에 빠르게 차오르고 부드럽게 줄어 끝에서 0
function CharacterAnimLogic.flopCurve(u: number): number
	if u <= 0 or u >= 1 then
		return 0
	end
	local attack = 0.12
	if u < attack then
		return smooth01(u / attack)
	end
	return 1 - smooth01((u - attack) / (1 - attack))
end

-- 물방울 (u 0~1): 잠깐 숨어 있다가 빠르게 튀어나오고(첨벙) 천천히 돌아와요
function CharacterAnimLogic.splashCurve(u: number): number
	if u <= 0.05 or u >= 1 then
		return 0
	end
	if u < 0.35 then
		return smooth01((u - 0.05) / 0.3)
	end
	return 1 - smooth01((u - 0.35) / 0.65)
end

-- 들썩 (u 0~1): 앞 60% 동안 위로 한 번 (뛰었다 내려앉음)
local function hop(u: number): number
	if u <= 0 or u >= 0.6 then
		return 0
	end
	return math.sin(math.pi * u / 0.6)
end

-- 다음 팔딱까지 기다릴 시간 (r 0~1, 테스트에서 고정). 모르는 mode는 Character
function CharacterAnimLogic.nextFlopDelay(r: number, mode: string): number
	local range = CharacterAnimLogic.FISH.DELAYS[mode] or CharacterAnimLogic.FISH.DELAYS.Character
	return range[1] + (range[2] - range[1]) * clamp(r, 0, 1)
end

-- 팔딱 한 번의 길이 (Hurt는 짧은 경련)
function CharacterAnimLogic.flopDuration(mode: string): number
	local F = CharacterAnimLogic.FISH
	return if mode == "Hurt" then F.TWITCH_TIME else F.FLOP_TIME
end

-- 지금 새 팔딱을 시작해도 되는지 (달리기·넘어짐·공중이면 안 돼요)
function CharacterAnimLogic.canStartFlop(walk: number, airborne: boolean, knocked: boolean): boolean
	return walk <= CharacterAnimLogic.FISH.RUN_MIN_WALK and not airborne and not knocked
end

-- 섞기: 넘어짐·공중 정도를 BLEND_TIME 동안 일정 속도로 목표까지 (dt초)
function CharacterAnimLogic.fishBlend(prev: FishBlend?, input: FishInput, dt: number): FishBlend
	local F = CharacterAnimLogic.FISH
	local step = if F.BLEND_TIME > 0 then math.max(0, dt) / F.BLEND_TIME else 1
	local knockTarget = if input.knocked then 1 else 0
	local airTarget = if input.airborne then CharacterAnimLogic.stretch(input.riseSpeed) else 0
	local function toward(current: number, target: number): number
		if current < target then
			return math.min(target, current + step)
		end
		return math.max(target, current - step)
	end
	local p = prev or { knock = knockTarget, air = airTarget }
	return { knock = toward(p.knock, knockTarget), air = toward(p.air, airTarget) }
end

function CharacterAnimLogic.fishPose(input: FishInput): FishPose
	local F = CharacterAnimLogic.FISH
	local blend = input.blend
		or {
			knock = if input.knocked then 1 else 0,
			air = if input.airborne then CharacterAnimLogic.stretch(input.riseSpeed) else 0,
		}
	local k = smooth01(blend.knock)
	local air = smooth01(blend.air) * (1 - k)
	local walk = clamp(input.walk, 0, 1.3)
	local still = 1 - smooth01(walk / 0.3) -- 1 = 서 있음
	local t = input.time
	local hurt = input.mode == "Hurt"

	local tail, mid, lift, twist = 0, 0, 0, 0
	local rootArch, midArch, tailArch = 0, 0, 0
	local splash = 0

	-- 팔딱 (가끔): 진행 중이면 살랑을 그만큼 줄여요
	local flopEnv = 0
	local flopTime = input.flopTime
	if flopTime ~= nil then
		local duration = CharacterAnimLogic.flopDuration(input.mode)
		local u = flopTime / duration
		-- 겹친 상태(QA B1): 팔딱 중 점프·달리기면 공중 정도·달리기만큼 섞어 줄여요 (끊지 않아요 — 연속)
		flopEnv = CharacterAnimLogic.flopCurve(u) * (1 - k) * (1 - air) * still
		if flopEnv > 0 then
			local hz = if hurt then F.TWITCH_HZ else F.FLOP_HZ
			local beat = math.sin(TAU * hz * flopTime)
			if hurt then
				tail += F.TWITCH_TAIL * flopEnv * beat
				mid += F.TWITCH_MID * flopEnv * math.sin(TAU * hz * flopTime - F.RUN_LAG)
			else
				tail += F.FLOP_TAIL * flopEnv * beat
				mid += F.FLOP_MID * flopEnv * math.sin(TAU * hz * flopTime - F.RUN_LAG)
				lift += F.FLOP_LIFT * hop(u) * (1 - k) * (1 - air) * still
				rootArch += F.FLOP_ROOT_ARCH * flopEnv
				midArch += F.FLOP_MID_ARCH * flopEnv
				tailArch += F.FLOP_TAIL_ARCH * flopEnv
				twist += F.FLOP_TWIST * flopEnv * math.sin(TAU * 3 * flopTime)
				splash = math.max(splash, CharacterAnimLogic.splashCurve(u) * (1 - k) * (1 - air) * still)
			end
		end
	end

	-- 착지 큰 팔딱
	local landEnv = 0
	local landTime = input.landTime
	if landTime ~= nil and input.landStrength > 0 then
		local tl = landTime - F.LAND_DELAY
		local u = tl / F.LAND_TIME
		local strength = clamp(input.landStrength, 0, 1)
		-- 착지 팔딱 중 다시 점프하면 공중 정도만큼 줄여요 (QA B1)
		landEnv = CharacterAnimLogic.flopCurve(u) * (1 - k) * (1 - air)
		if landEnv > 0 then
			tail += F.LAND_TAIL * landEnv * math.sin(TAU * F.LAND_HZ * tl)
			mid += F.LAND_MID * landEnv * math.sin(TAU * F.LAND_HZ * tl - F.RUN_LAG)
			lift += F.LAND_LIFT * strength * hop(u) * (1 - k) * (1 - air)
			rootArch += F.LAND_ROOT_ARCH * landEnv
			midArch += F.LAND_MID_ARCH * landEnv
			tailArch += F.LAND_TAIL_ARCH * landEnv
			twist += F.LAND_TWIST * landEnv * math.sin(TAU * 3 * tl)
			splash = math.max(splash, CharacterAnimLogic.splashCurve(u) * (1 - k) * (1 - air))
		end
	end

	-- 서 있음 살랑 (팔딱·착지 중에는 줄어요)
	local busy = math.max(flopEnv, landEnv)
	local swayAmount = still * (1 - k) * (1 - air) * (1 - busy) * (if hurt then F.HURT_SWAY else 1)
	local sway = TAU * F.SWAY_HZ * t
	tail += F.SWAY_TAIL * swayAmount * math.sin(sway)
	mid += F.SWAY_MID * swayAmount * math.sin(sway - F.SWAY_LAG)

	-- 달리기: 걸음 위상의 2배 (걸음과 엇박이 나지 않게), 뒷몸은 RUN_LAG만큼 늦게
	local run = walk * (1 - k)
	tail += F.RUN_TAIL * run * math.sin(2 * input.phase)
	mid += F.RUN_MID * run * math.sin(2 * input.phase - F.RUN_LAG)

	-- 점프 C자 아치
	rootArch += F.JUMP_ROOT_ARCH * air
	midArch += F.JUMP_MID_ARCH * air
	tailArch += F.JUMP_TAIL_ARCH * air

	-- 넘어짐: 빠르게 퍼덕 (들썩 없음)
	local knockBeat = TAU * F.KNOCK_HZ * t
	tail += F.KNOCK_TAIL * k * math.sin(knockBeat)
	mid += F.KNOCK_MID * k * math.sin(knockBeat - 0.9)

	-- 탈락 인형: 축 처짐
	if hurt then
		rootArch += F.HURT_ROOT_ARCH
		midArch += F.HURT_MID_ARCH
		tailArch += F.HURT_TAIL_ARCH
	end

	-- 가슴지느러미: 평소 살짝, 팔딱 때 크게
	local finBeat = 0.5 + 0.5 * math.sin(TAU * F.FIN_HZ * t)
	local finFlap = F.FIN_IDLE * finBeat * (1 - busy) + F.FIN_FLOP * busy * (0.5 + 0.5 * math.sin(TAU * F.FLOP_HZ * t))

	-- 한도
	rootArch = clamp(rootArch, -F.MAX_ARCH, F.MAX_ARCH)
	local bend = midArch + tailArch
	if math.abs(bend) > F.MAX_ARCH then
		local scale = F.MAX_ARCH / math.abs(bend)
		midArch *= scale
		tailArch *= scale
	end
	return {
		rootLift = clamp(lift, 0, F.MAX_LIFT),
		rootArch = rootArch,
		rootTwist = clamp(twist, -F.MAX_TWIST, F.MAX_TWIST),
		midYaw = clamp(mid, -F.MAX_MID, F.MAX_MID),
		midArch = midArch,
		tailYaw = clamp(tail, -F.MAX_TAIL, F.MAX_TAIL),
		tailArch = tailArch,
		finFlap = clamp(finFlap, 0, F.FIN_FLOP),
		splash = clamp(splash, 0, 1),
	}
end

-- 관절 움직임 (SushiPose.Motion 모양: angles 라디안, move, reach). 관절 이름이 계약이에요.
--   FishRoot: 들썩(Y) + 비틀림(X) + 아치(Z, 머리 위로)
--   FishMid: 좌우(Y) + 휨(Z) — FishRoot의 아치를 되돌리고 꼬리 쪽을 들어 올려요 (C자)
--   FishTail: 좌우 파닥(Y) + 휨(Z), FishFinL(-Z 쪽)/FishFinR(+Z 쪽): 지느러미 끝이 바깥으로
--   Splash1~4: reach(파츠 속성)에 splash를 곱한 만큼 옮겨요
export type FishMotion = { angles: { number }?, move: { number }?, reach: number? }

CharacterAnimLogic.FISH_JOINTS =
	{ "FishRoot", "FishMid", "FishTail", "FishFinL", "FishFinR", "Splash1", "Splash2", "Splash3", "Splash4" }

function CharacterAnimLogic.fishMotion(pose: FishPose): { [string]: FishMotion }
	local motion: { [string]: FishMotion } = {
		FishRoot = { move = { 0, pose.rootLift, 0 }, angles = { pose.rootTwist, 0, pose.rootArch } },
		FishMid = { angles = { 0, pose.midYaw, -(pose.rootArch + pose.midArch) } },
		FishTail = { angles = { 0, pose.tailYaw, -pose.tailArch } },
		FishFinL = { angles = { 0, -pose.finFlap, 0 } },
		FishFinR = { angles = { 0, pose.finFlap, 0 } },
	}
	for i = 1, 4 do
		motion[`Splash{i}`] = { reach = pose.splash }
	end
	return motion
end

-- 이번 프레임(prev → now)에 울릴 소리. kind "Flop" = 가끔 팔딱(시작에 FishFlop, 물방울이 튀는 순간 FishSplash),
-- "Land" = 착지 팔딱(LAND_DELAY에 FishFlop + FishSplash). 경련(Hurt)·살랑은 소리 없음. prev가 nil이면 이번이 첫 프레임
function CharacterAnimLogic.fishCues(kind: "Flop" | "Land", mode: string, prev: number?, now: number): { string }
	local F = CharacterAnimLogic.FISH
	if mode == "Hurt" then
		return {}
	end
	local cues: { string } = {}
	local function crossed(at: number): boolean
		return now >= at and (prev == nil or prev < at)
	end
	if kind == "Flop" then
		if crossed(0) then
			table.insert(cues, "FishFlop")
		end
		if crossed(F.FLOP_TIME * 0.1) then
			table.insert(cues, "FishSplash")
		end
	elseif crossed(F.LAND_DELAY) then
		table.insert(cues, "FishFlop")
		table.insert(cues, "FishSplash")
	end
	return cues
end

local REST_POSE: FishPose = {
	rootLift = 0,
	rootArch = 0,
	rootTwist = 0,
	midYaw = 0,
	midArch = 0,
	tailYaw = 0,
	tailArch = 0,
	finFlap = 0,
	splash = 0,
}

local function withPose(changes: { [string]: number }): FishPose
	local pose = table.clone(REST_POSE)
	for key, value in changes do
		(pose :: any)[key] = value
	end
	return pose
end

-- 한 팔딱 안에서 key가 가장 큰 순간의 자세 (1/120초 간격으로 찾아요)
local function peakOf(key: string, make: (t: number) -> FishInput, duration: number): FishPose
	local best: FishPose = REST_POSE
	local bestValue = -math.huge
	local t = 0
	while t <= duration do
		local pose = CharacterAnimLogic.fishPose(make(t))
		local value = (pose :: any)[key] :: number
		if value > bestValue then
			bestValue = value
			best = pose
		end
		t += 1 / 120
	end
	return best
end

local function standing(overrides: { [string]: any }): FishInput
	local input: FishInput = {
		time = 0,
		walk = 0,
		phase = 0,
		riseSpeed = 0,
		airborne = false,
		landTime = nil,
		landStrength = 0,
		knocked = false,
		flopTime = nil,
		mode = "Character",
	}
	for key, value in overrides do
		(input :: any)[key] = value
	end
	return input
end

-- 대표 자세 (렌더 도구 --pose와 테스트 AC4가 같이 써요). 순서 = 렌더 -poses 칸 순서
--   Rest 쉰 자세 · TailLeft/TailRight 꼬리 최대 좌·우 · JumpArch 점프 아치 · LandPeak 착지 팔딱 최고점 ·
--   Knocked 넘어짐 최대 · Hurt 탈락 인형 처짐 · Splash 물방울 나온 순간
function CharacterAnimLogic.fishTestPoses(): { { name: string, pose: FishPose } }
	local F = CharacterAnimLogic.FISH
	local landPeak = peakOf("rootLift", function(t: number): FishInput
		return standing({ landTime = t, landStrength = 1 })
	end, F.LAND_DELAY + F.LAND_TIME)
	local splash = peakOf("splash", function(t: number): FishInput
		return standing({ flopTime = t })
	end, F.FLOP_TIME)
	local hurt = peakOf("tailYaw", function(t: number): FishInput
		return standing({ flopTime = t, mode = "Hurt" })
	end, F.TWITCH_TIME)
	return {
		{ name = "Rest", pose = REST_POSE },
		{ name = "TailLeft", pose = withPose({ tailYaw = F.MAX_TAIL, midYaw = F.MAX_MID }) },
		{ name = "TailRight", pose = withPose({ tailYaw = -F.MAX_TAIL, midYaw = -F.MAX_MID }) },
		{ name = "JumpArch", pose = CharacterAnimLogic.fishPose(standing({ airborne = true, riseSpeed = 60 })) },
		{ name = "LandPeak", pose = landPeak },
		{ name = "Knocked", pose = withPose({ tailYaw = F.KNOCK_TAIL, midYaw = F.KNOCK_MID }) },
		{ name = "Hurt", pose = hurt },
		{ name = "Splash", pose = splash },
	}
end

-- 착지 팔딱 0 → 끝을 frames칸으로 (렌더 -flop-strip)
function CharacterAnimLogic.fishLandStrip(frames: number): { { time: number, pose: FishPose } }
	local F = CharacterAnimLogic.FISH
	local list = {}
	local total = F.LAND_DELAY + F.LAND_TIME
	for i = 0, frames - 1 do
		local t = total * i / math.max(1, frames - 1)
		table.insert(
			list,
			{ time = t, pose = CharacterAnimLogic.fishPose(standing({ landTime = t, landStrength = 1 })) }
		)
	end
	return list
end

-- 같은 캐릭터 소리 간격 (SOUND_GAP): 마지막으로 울린 시각 last(없으면 nil) → 지금 울려도 되는지
function CharacterAnimLogic.fishSoundAllowed(last: number?, now: number): boolean
	return last == nil or now - last >= CharacterAnimLogic.FISH.SOUND_GAP
end

-- 이번 프레임에 실제로 울릴 소리만 골라요: 같은 캐릭터에서 같은 소리(FishFlop·FishSplash 각각)는 SOUND_GAP에 한 번
-- 이하. last(소리 이름 → 마지막으로 울린 시각)를 바꿔요. 팔딱과 첨벙은 짝이라 서로 막지 않아요
function CharacterAnimLogic.fishSoundFilter(last: { [string]: number }, cues: { string }, now: number): { string }
	local out: { string } = {}
	for _, cue in cues do
		if CharacterAnimLogic.fishSoundAllowed(last[cue], now) then
			last[cue] = now
			table.insert(out, cue)
		end
	end
	return out
end

return CharacterAnimLogic
