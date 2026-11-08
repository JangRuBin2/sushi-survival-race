--!strict
-- "중식당 회전 원판"(lazy-susan, m6-06) 순수 계산. Roblox API 없음.
--   ringAngle(ring, t)          고리가 지금까지 돈 각도(도, 빨라지기 반영)
--   holeCenters(ring, t)        지금 열린 구멍들의 가운데 각도(도) — 시간에 따라 개수가 늘어요
--   segmentState(ring, k, t)    조각 상태 "Solid" | "Warn" | "Open"
--   centerState(t)              가운데 유리판 상태 (서든데스부터 깜빡 열려요)
--   ringAt(x, y, z)             발밑 고리 (밀기)
--   tangent(x, z, dir)          회전 접선 단위 방향
--   bowlPosition(bowl, t)       그릇 자리
--   fallLine() / heightScore(y)

local Layout = require(script.Parent.LazySusanLayout)

local Logic = {}

Logic.TIME_LIMIT = Layout.TIME_LIMIT
Logic.SUDDEN_DEATH_AT = Layout.SUDDEN_DEATH_AT

export type SegmentState = "Solid" | "Warn" | "Open"

function Logic.fallLine(): number
	return Layout.FLOOR_Y - Layout.FALL_MARGIN
end

-- 빨라진 시간: 45초 뒤로는 1.4배로 흘러요 (각도 = 진행 시간 × 각속도)
function Logic.spinTime(t: number): number
	local s = math.max(t, 0)
	if s <= Layout.SPEED_UP_AT then
		return s
	end
	return Layout.SPEED_UP_AT + (s - Layout.SPEED_UP_AT) * Layout.SPEED_UP
end

function Logic.ringAngle(ring: Layout.Ring, t: number): number
	return ring.dir * 360 * Logic.spinTime(t) / ring.period
end

local function wrap(deg: number): number
	return deg % 360
end

-- 두 각도 차이(0~180)
function Logic.angleDiff(a: number, b: number): number
	local d = math.abs(wrap(a) - wrap(b))
	return if d > 180 then 360 - d else d
end

-- t초에 열려 있는 구멍 개수 (4초부터 1개, 20초부터 전부)
function Logic.holeCount(ring: Layout.Ring, t: number): number
	if t < Layout.HOLES_START then
		return 0
	elseif t < Layout.MORE_HOLES_AT then
		return math.min(1, #ring.holes)
	end
	return #ring.holes
end

function Logic.holeSpan(t: number): number
	return if t >= Layout.SUDDEN_DEATH_AT then Layout.HOLE_SPAN_SUDDEN else Layout.HOLE_SPAN
end

function Logic.holeCenters(ring: Layout.Ring, t: number): { number }
	local list: { number } = {}
	local spin = Logic.ringAngle(ring, t)
	for i = 1, Logic.holeCount(ring, t) do
		table.insert(list, wrap(ring.holes[i] + spin))
	end
	return list
end

function Logic.inHole(ring: Layout.Ring, angle: number, t: number): boolean
	local half = Logic.holeSpan(t) / 2
	for _, center in Logic.holeCenters(ring, t) do
		if Logic.angleDiff(angle, center) <= half then
			return true
		end
	end
	return false
end

-- 조각 상태: 지금 구멍 안이면 Open, HOLE_WARN초 안에 구멍에 들어가면 Warn(빨강), 아니면 Solid.
-- 구멍은 계속 움직이니 t + HOLE_WARN 한 점만 보면, 새 구멍이 생기거나(4·20초) 폭이 넓어지는(60초) 순간 구멍 뒤쪽 끝에
-- 걸린 조각이 예고 없이 열려요(테스트가 잡은 경우). 그래서 그 사이 "구멍 일" 시각도 같이 봐요.
local HOLE_EVENTS = { Layout.HOLES_START, Layout.MORE_HOLES_AT, Layout.SUDDEN_DEATH_AT }

function Logic.segmentState(ring: Layout.Ring, k: number, t: number): SegmentState
	local angle = Layout.segmentAngle(k)
	if Logic.inHole(ring, angle, t) then
		return "Open"
	elseif Logic.inHole(ring, angle, t + Layout.HOLE_WARN) then
		return "Warn"
	end
	for _, at in HOLE_EVENTS do
		if at > t and at <= t + Layout.HOLE_WARN and Logic.inHole(ring, angle, at) then
			return "Warn"
		end
	end
	return "Solid"
end

-- 가운데 유리판 상태: 서든데스 전에는 늘 Solid. 그 뒤로 주기 끝 CENTER_OPEN초가 Open, 그 앞 HOLE_WARN초가 Warn.
function Logic.centerState(t: number): SegmentState
	if t < Layout.SUDDEN_DEATH_AT then
		return "Solid"
	end
	local phase = (t - Layout.SUDDEN_DEATH_AT) % Layout.CENTER_CYCLE
	local openFrom = Layout.CENTER_CYCLE - Layout.CENTER_OPEN
	if phase >= openFrom then
		return "Open"
	elseif phase >= openFrom - Layout.HOLE_WARN then
		return "Warn"
	end
	return "Solid"
end

-- 발밑 고리 (반지름·발 높이로)
function Logic.ringAt(x: number, y: number, z: number): Layout.Ring?
	local foot = y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
	if foot < -1 or foot > Layout.PUSH_ZONE_HEIGHT then
		return nil
	end
	local r = math.sqrt(x * x + z * z)
	for _, ring in Layout.RINGS do
		if r >= ring.inner and r <= ring.outer then
			return ring
		end
	end
	return nil
end

-- 회전 접선 단위 방향 (dir 1 = 위에서 볼 때 시계 방향 = 각도가 커지는 쪽)
function Logic.tangent(x: number, z: number, dir: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	if r < 1e-6 then
		return 0, 0
	end
	local ux, uz = x / r, z / r
	return -uz * dir, ux * dir
end

-- 고리 위 반지름 r에서 미는 목표 속도 (각속도 × r, 상한)
function Logic.pushSpeed(ring: Layout.Ring, r: number, t: number): number
	local omega = 2 * math.pi / ring.period * (if t > Layout.SPEED_UP_AT then Layout.SPEED_UP else 1)
	return math.min(omega * r, Layout.PUSH_CAP)
end

function Logic.bowlPosition(bowl: Layout.Bowl, t: number): (number, number)
	local ring = Layout.RINGS[bowl.ring]
	local a = math.rad(bowl.offset + Logic.ringAngle(ring, t))
	local r = (ring.inner + ring.outer) / 2
	return math.cos(a) * r, math.sin(a) * r
end

function Logic.bowlHit(dx: number, dz: number, foot: number): boolean
	local r = Layout.BOWL_RADIUS + Layout.BOWL_HIT_PAD
	return dx * dx + dz * dz <= r * r and foot < Layout.BOWL_HIT_FOOT
end

function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

return Logic
