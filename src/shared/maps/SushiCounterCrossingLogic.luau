--!strict
-- "초밥집 카운터 대횡단"(sushi-counter-crossing, m6-03) 순수 계산. Roblox API 없음 — Lune 테스트에서 바로 불러요.
--   progress / finishProgress / sectionAt / floorAt / fallLineAt   코스 진행·바닥·낙하선
--   railDirection(seg, t) / railSwitchSoon(t)                       왼쪽 회전 레일 방향
--   plateAt(x, y, z) / railAt(x, y, z) / rampAt(x, y, z)            발밑 판정 구역 찾기
--   bottles(elapsed) / coins(elapsed)                               굴러오는 간장병·동전 자리 (시간만으로 정해져요)
--   rollHit(dx, dz, foot, length, diameter)                         굴러오는 것에 맞았나
--   strikeAt(rng) / strikeHit(dx, dz) / strikeKnock(dx, dz)          젓가락 들판
--   pushDelta(current, target, accel, dt)                           연속 밀기 (설거지통·회전 벨트와 같아요)
--   estimateClearTime()                                             빠른 사람 완주 추정 (초)

local Layout = require(script.Parent.SushiCounterCrossingLayout)

local Logic = {}

export type Roller = { slot: number, x: number, z: number, lane: number? }
export type Strike = { x: number, z: number }
export type Rng = { NextNumber: (self: any, min: number, max: number) -> number }

function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

function Logic.sectionAt(z: number): string
	for i, span in Layout.sections() do
		if z > span.back then
			return Layout.SECTION_NAMES[i]
		end
	end
	return "F"
end

-- 그 z의 바닥 높이: E 오르막까지 0, 오르막에서 0 → 12, 그 뒤 12
function Logic.floorAt(z: number): number
	local slope = Layout.RAMP_SLOPE
	if z > slope.front then
		return Layout.LOW_Y
	elseif z > slope.back then
		local t = (slope.front - z) / (slope.front - slope.back)
		return Layout.LOW_Y + (Layout.HIGH_Y - Layout.LOW_Y) * t
	end
	return Layout.HIGH_Y
end

function Logic.fallLineAt(z: number): number
	return Logic.floorAt(z) - Layout.FALL_MARGIN
end

-- ── 회전 레일 ─────────────────────────────────────────────────────────
-- 1 = 결승 쪽(-z)으로 밂, -1 = 출발 쪽(+z). RAIL_PERIOD초마다 모든 구간이 뒤바뀌어요.
function Logic.railDirection(segment: number, t: number): number
	local seg = Layout.RAIL_SEGMENTS[segment]
	local flips = math.floor(math.max(t, 0) / Layout.RAIL_PERIOD)
	return if flips % 2 == 0 then seg.base else -seg.base
end

-- 다음 뒤바뀜까지 RAIL_WARN초 안인가 (경고 소리)
function Logic.railSwitchSoon(t: number): boolean
	local into = math.max(t, 0) % Layout.RAIL_PERIOD
	return into >= Layout.RAIL_PERIOD - Layout.RAIL_WARN
end

local function footOn(y: number, top: number): boolean
	local h = y - Layout.FOOT_OFFSET - top
	return h >= -1 and h <= Layout.PUSH_ZONE_HEIGHT
end

-- 발이 레일 위면 그 구간 번호
function Logic.railAt(x: number, y: number, z: number): number?
	local lw = Layout.LANE_WIDTH / 2
	if math.abs(x - Layout.LANE_X[1]) > lw or not footOn(y, Layout.LOW_Y) then
		return nil
	end
	for _, seg in Layout.RAIL_SEGMENTS do
		if z <= seg.maxZ and z > seg.minZ then
			return seg.index
		end
	end
	return nil
end

function Logic.plateAt(x: number, y: number, z: number): Layout.Plate?
	for _, plate in Layout.PLATES do
		if footOn(y, plate.top) then
			local dx, dz = x - plate.x, z - plate.z
			if dx * dx + dz * dz <= plate.radius * plate.radius then
				return plate
			end
		end
	end
	return nil
end

-- 발이 오르막 줄(쐐기·평지) 위면 그 줄
function Logic.rampAt(x: number, y: number, z: number): Layout.Ramp?
	if z > Layout.RAMPS.front or z <= Layout.RAMPS.back then
		return nil
	end
	if not footOn(y, Logic.floorAt(z)) then
		return nil
	end
	for _, ramp in Layout.RAMP_LIST do
		if math.abs(x - ramp.x) <= Layout.RAMP_WIDTH / 2 then
			return ramp
		end
	end
	return nil
end

-- ── 굴러오는 것 (시간만으로 자리가 정해져요 — 모든 방·클라이언트가 같은 공식) ──────────
-- 간장병: n번째 병(n = 0, 1, …)은 출발 BOTTLE_START_DELAY + n × 간격에 z FROM에서 출발해 +z로 굴러요.
function Logic.bottles(elapsed: number): { Roller }
	local list: { Roller } = {}
	local t = elapsed - Layout.BOTTLE_START_DELAY
	if t < 0 then
		return list
	end
	local travel = (Layout.BOTTLE_TO_Z - Layout.BOTTLE_FROM_Z) / Layout.BOTTLE_SPEED
	local newest = math.floor(t / Layout.BOTTLE_INTERVAL)
	for n = newest, math.max(newest - Layout.BOTTLE_SLOTS + 1, 0), -1 do
		local age = t - n * Layout.BOTTLE_INTERVAL
		if age <= travel then
			table.insert(list, {
				slot = n % Layout.BOTTLE_SLOTS + 1,
				x = Layout.BOTTLE_X[n % #Layout.BOTTLE_X + 1],
				z = Layout.BOTTLE_FROM_Z + age * Layout.BOTTLE_SPEED,
			})
		end
	end
	return list
end

-- 동전: 안쪽 두 줄(Coin)마다. 줄끼리 간격의 반만큼 어긋나요. slot은 줄 안에서 1..COIN_SLOTS
function Logic.coins(elapsed: number): { Roller }
	local list: { Roller } = {}
	local travel = (Layout.COIN_TO_Z - Layout.COIN_FROM_Z) / Layout.COIN_SPEED
	local laneOrder = 0
	for _, ramp in Layout.RAMP_LIST do
		if ramp.kind ~= "Coin" then
			continue
		end
		local t = elapsed - Layout.COIN_START_DELAY - laneOrder * Layout.COIN_INTERVAL / 2
		laneOrder += 1
		if t < 0 then
			continue
		end
		local newest = math.floor(t / Layout.COIN_INTERVAL)
		for n = newest, math.max(newest - Layout.COIN_SLOTS + 1, 0), -1 do
			local age = t - n * Layout.COIN_INTERVAL
			if age <= travel then
				local side = if n % 2 == 0 then -Layout.COIN_SIDE else Layout.COIN_SIDE
				table.insert(list, {
					slot = n % Layout.COIN_SLOTS + 1,
					lane = ramp.index,
					x = ramp.x + side,
					z = Layout.COIN_FROM_Z + age * Layout.COIN_SPEED,
				})
			end
		end
	end
	return list
end

-- 굴러오는 것(중심 기준 dx, dz, 그 물체 바닥 기준 발 높이 foot)에 맞았나. 길이는 x, 지름은 z·높이.
function Logic.rollHit(dx: number, dz: number, foot: number, length: number, diameter: number): boolean
	return math.abs(dx) <= length / 2 + Layout.HIT_PAD
		and math.abs(dz) <= diameter / 2 + Layout.HIT_PAD
		and foot < math.min(Layout.HIT_FOOT, diameter - 0.5)
end

-- ── 젓가락 들판 ───────────────────────────────────────────────────────
function Logic.strikeAt(rng: Rng): Strike
	return {
		x = rng:NextNumber(-Layout.STRIKE_X, Layout.STRIKE_X),
		z = rng:NextNumber(Layout.STRIKE_Z.back, Layout.STRIKE_Z.front),
	}
end

function Logic.strikeHit(dx: number, dz: number): boolean
	return dx * dx + dz * dz <= Layout.STRIKE_RADIUS * Layout.STRIKE_RADIUS
end

-- 원 중심에서 바깥쪽 수평 단위 방향 (정중앙이면 출발 쪽 +z — 뒤로 밀려요)
function Logic.strikeKnock(dx: number, dz: number): (number, number)
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-3 then
		return 0, 1
	end
	return dx / d, dz / d
end

-- ── 연속 밀기 ─────────────────────────────────────────────────────────
function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

-- 원 둘 사이 틈 (중심 거리 − 반지름 합)
function Logic.circleGap(ax: number, az: number, ar: number, bx: number, bz: number, br: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) - ar - br
end

function Logic.estimateClearTime(): number
	local walk = (0 - Layout.FINISH_LINE_Z) / Layout.WALK_SPEED
	local delay = 0
	for _, value in Layout.SECTION_DELAY do
		delay += value
	end
	return walk + delay
end

return Logic
