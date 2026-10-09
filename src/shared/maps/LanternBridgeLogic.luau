--!strict
-- "등불 다리 건너기"(lantern-bridge, m5-15)의 순수 로직: 흔들림 진폭·각도, 미는 속도, 낙하선, 진행도,
-- 다리 찾기, 위험도. Roblox API를 쓰지 않아서 Lune 테스트에서 그대로 불러요. 치수는 LanternBridgeLayout에 있어요.
-- 좌표는 origin 기준 로컬 (x: 오른쪽 +, y: 위, z: 결승 쪽이 -)이에요.

local Layout = require(script.Parent.LanternBridgeLayout)

local Logic = {}

-- 다리 위 인원수 → 흔들림 진폭(도). 혼자여도 기본 흔들림(SWAY_BASE_DEG)이 있고, 인원이 늘수록
-- SWAY_PER_RIDER_DEG씩 커지다가 SWAY_RIDER_CAP명부터는 더 안 늘고, 항상 그 다리의 maxDeg를 넘지 않아요.
function Logic.swayAmplitudeDeg(riders: number, maxDeg: number): number
	local capped = math.min(math.max(riders, 0), Layout.SWAY_RIDER_CAP)
	local amplitude = Layout.SWAY_BASE_DEG + Layout.SWAY_PER_RIDER_DEG * capped
	return math.min(amplitude, maxDeg)
end

-- 사인파 좌우(roll, 로컬 Z축 기준) 흔들림 각도(라디안). period마다 한 바퀴, phase로 다리마다 어긋나요.
function Logic.swayAngle(t: number, amplitudeDeg: number, period: number, phase: number): number
	return math.rad(amplitudeDeg) * math.sin((2 * math.pi / period) * t + phase)
end

-- 다리가 angleRad만큼 기운 동안 낮은 쪽으로 미는 목표 속도(studs/s). 0도에서 0, maxDeg에서 최고 속도이고
-- 부호는 angleRad와 같아요(기운 방향으로 밀어요).
function Logic.pushSpeedFor(angleRad: number, maxDeg: number): number
	local maxRad = math.rad(maxDeg)
	if maxRad <= 0 then
		return 0
	end
	local ratio = math.clamp(angleRad / maxRad, -1, 1)
	return Layout.PLANK_PUSH_SPEED * ratio
end

-- 한 축 밀기: 지금 속도(current)를 목표(target) 쪽으로 이번 프레임에 더할 양.
-- 이미 목표보다 빠르면(같은 방향) 더하지 않고, 반대로 줄이지도 않아요(기존 맵들과 같은 계약).
function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

-- 다리 폭의 절반(halfWidth)을 넘어 로컬 X로 벗어났는지. 경계(±halfWidth)는 아직 벗어난 게 아니에요.
function Logic.isOffPlank(localX: number, halfWidth: number): boolean
	return math.abs(localX) > halfWidth
end

-- 바닥은 전부 평탄(y = 0)이라 탈락선은 어디서나 같아요.
function Logic.fallLineAt(_z: number): number
	return -Layout.FALL_MARGIN
end

-- 진행도(로컬 -Z). 시간 종료 때 순위도 이 축이에요.
function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.finishLineZ())
end

-- z가 속한 다리 (쉼터·출발·결승이면 nil)
function Logic.bridgeAt(z: number): Layout.Bridge?
	for _, bridge in Layout.BRIDGES do
		if z <= bridge.front and z >= bridge.back then
			return bridge
		end
	end
	return nil
end

-- 위험도: 흔들림 진폭을 다리 반폭으로 나눈 값. 폭이 좁을수록(halfWidth가 작을수록) 같은 흔들림이라도
-- 위험도가 커져요 — "좁을수록 덜 흔들려도 더 쉽게 떨어진다"의 수치 표현.
function Logic.fallRisk(amplitudeDeg: number, halfWidth: number): number
	return amplitudeDeg / halfWidth
end

return Logic
