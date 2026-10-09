--!strict
-- "줄다리기 발판"(m5-18)의 순수 로직: 살아남은 인원의 로컬 X 위치로 기울기를 구하고(Logic.tilt),
-- 그 목표로 서서히 따라가고(Logic.approach), 결승 연장전 동안 강제로 흔드는 각도(Logic.overtimeAngle)를
-- 계산해요. Roblox API를 쓰지 않아서 Lune 테스트(tests/map-tug-of-war-platform.spec.luau)에서 그대로 불러요.
--
-- 좌표 약속: origin 기준 로컬 X (중심 0, 왼쪽 음수·오른쪽 양수, 발판 절반 길이가 끝).
-- 각도는 라디안, 양수면 로컬 +X(오른쪽) 끝이 아래로 내려가는 쪽이에요
-- (실제 CFrame에 적용할 때 부호를 뒤집어야 할 수 있어요 — TugOfWarPlatform.luau의 TILT_SIGN, Studio AC9로 확인).

local Logic = {}

-- 평상시 기울기 (무게 분포, GDD 기본값)
Logic.MAX_ANGLE = math.rad(30) -- 포화 각도 (끝에 3명이 뭉치면 여기까지)
Logic.SATURATION_TORQUE = 105 -- = 끝(35) * 3명
Logic.TORQUE_SCALE = Logic.MAX_ANGLE / Logic.SATURATION_TORQUE
Logic.TILT_RATE = math.rad(20) -- 초당 이만큼만 목표 쪽으로 움직여요 (무거운 저울 느낌)

-- 연장전 (m5-01 계약)
Logic.LETHAL_ANGLE = math.rad(90) -- 완전 수직. 마지막 꺾인점은 항상 이 크기예요 (기하학적 보장, 결정 기록 D2)

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

-- 살아남은 레이서의 로컬 X 위치 목록 -> 목표 기울기(라디안). 사람이 없거나 좌우가 같으면 0.
function Logic.tilt(positions: { number }): number
	local torque = 0
	for _, x in positions do
		torque += x
	end
	local angle = torque * Logic.TORQUE_SCALE
	return math.clamp(angle, -Logic.MAX_ANGLE, Logic.MAX_ANGLE)
end

-- current에서 target 쪽으로 maxDelta만큼만 움직여요 (target을 넘어서지 않아요, 둘 중 가까운 값).
function Logic.approach(current: number, target: number, maxDelta: number): number
	local delta = target - current
	if math.abs(delta) <= maxDelta then
		return target
	end
	return current + maxDelta * (if delta > 0 then 1 else -1)
end

-- 결승 연장전(m5-01): collapseDuration을 4등분한 시각마다 각도 크기가 MAX_ANGLE(30°)에서
-- LETHAL_ANGLE(90°)까지 균등 4등분(30→50→70→90)으로 커지고, 부호는 좌우로 번갈아요(+, -, +, -).
-- elapsed < 첫 꺾인점이면 startAngle에서 그 꺾인점까지 선형 보간, 그 뒤는 꺾인점끼리 선형 보간.
-- elapsed가 collapseDuration을 넘으면 마지막 꺾인점 각도로 clamp해요(에러 없음).
function Logic.overtimeAngle(elapsed: number, collapseDuration: number, startAngle: number): number
	if collapseDuration <= 0 then
		return -Logic.LETHAL_ANGLE
	end
	local clamped = math.clamp(elapsed, 0, collapseDuration)
	local step = collapseDuration / 4

	local function keyframe(i: number): number -- i = 1..4
		local magnitude = lerp(Logic.MAX_ANGLE, Logic.LETHAL_ANGLE, (i - 1) / 3)
		return if i % 2 == 1 then magnitude else -magnitude
	end

	if clamped <= step then
		local alpha = if step > 0 then clamped / step else 1
		return lerp(startAngle, keyframe(1), alpha)
	end
	for i = 1, 3 do
		local fromT, toT = i * step, (i + 1) * step
		if clamped <= toT then
			local alpha = (clamped - fromT) / (toT - fromT)
			return lerp(keyframe(i), keyframe(i + 1), alpha)
		end
	end
	return keyframe(4)
end

return Logic
