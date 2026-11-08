--!strict
-- "도시락 뚜껑 대탈출"(bento-door-dash, m6-04) 순수 계산. Roblox API 없음.
--   progress / finishProgress / fallLineAt                 진행·낙하선 (바닥은 전부 0)
--   pickRealDoors(rng) -> { { [number]: boolean } }        줄마다 진짜 문 자리 (라운드마다 한 번)
--   doorAt(x, z) -> (row?, door?)                          루트가 어느 문 앞(닿는 거리)인가
--   balls(elapsed) / ballHit(...)                          우메보시 자리·맞음
--   inPuddle(x, y, z) / slowVelocity(vx, vz)               간장 웅덩이
--   barAngle(t) / barHit(dx, dz, foot, angle) / barKnock   회전 젓가락 막대
--   padAt(x, y, z)                                         와사비 튕김판
--   estimateClearTime()

local Layout = require(script.Parent.BentoDoorDashLayout)

local Logic = {}

export type Rng = { NextInteger: (self: any, min: number, max: number) -> number }
export type Ball = { slot: number, x: number, z: number, dir: number }

function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

function Logic.fallLineAt(_z: number): number
	return Layout.FLOOR_Y - Layout.FALL_MARGIN
end

-- 줄마다 진짜 문 REAL_DOORS[row]개를 고르게 섞어 골라요 (피셔-예이츠). 결과[row][door] = true면 깨지는 문.
function Logic.pickRealDoors(rng: Rng): { { [number]: boolean } }
	local rows: { { [number]: boolean } } = {}
	for row, count in Layout.REAL_DOORS do
		local order: { number } = {}
		for d = 1, Layout.DOORS_PER_ROW do
			order[d] = d
		end
		for i = #order, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		local set: { [number]: boolean } = {}
		for k = 1, count do
			set[order[k]] = true
		end
		rows[row] = set
	end
	return rows
end

-- 루트(x, z)가 어떤 문 줄의 출발 쪽 면에 닿을 만큼 가까우면 (줄, 문 번호)
function Logic.doorAt(x: number, z: number): (number?, number?)
	if math.abs(x) > Layout.HALF then
		return nil, nil
	end
	for row, wallZ in Layout.DOOR_ROWS_Z do
		local face = wallZ + Layout.WALL_THICKNESS / 2 -- 출발 쪽 면
		if z >= face - 0.5 and z <= face + Layout.DOOR_REACH then
			local door = math.clamp(math.floor((x + Layout.HALF) / Layout.DOOR_WIDTH) + 1, 1, Layout.DOORS_PER_ROW)
			return row, door
		end
	end
	return nil, nil
end

-- ── 우메보시 ──────────────────────────────────────────────────────────
-- n번째 공은 BALL_START_DELAY + n × 간격에 BALL_Z[n % 3 + 1] 줄에서 출발, 짝수는 왼쪽→오른쪽(+x), 홀수는 반대.
function Logic.balls(elapsed: number): { Ball }
	local list: { Ball } = {}
	local t = elapsed - Layout.BALL_START_DELAY
	if t < 0 then
		return list
	end
	local travel = 2 * Layout.BALL_FROM_X / Layout.BALL_SPEED
	local newest = math.floor(t / Layout.BALL_INTERVAL)
	for n = newest, math.max(newest - Layout.BALL_SLOTS + 1, 0), -1 do
		local age = t - n * Layout.BALL_INTERVAL
		if age <= travel then
			local dir = if n % 2 == 0 then 1 else -1
			table.insert(list, {
				slot = n % Layout.BALL_SLOTS + 1,
				dir = dir,
				x = -dir * Layout.BALL_FROM_X + dir * Layout.BALL_SPEED * age,
				z = Layout.BALL_Z[n % #Layout.BALL_Z + 1],
			})
		end
	end
	return list
end

function Logic.ballHit(dx: number, dz: number, foot: number): boolean
	local r = Layout.BALL_DIAMETER / 2 + 1
	return dx * dx + dz * dz <= r * r and foot < Layout.BALL_DIAMETER - 1
end

-- ── 간장 웅덩이 ───────────────────────────────────────────────────────
function Logic.inPuddle(x: number, y: number, z: number): boolean
	local foot = y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
	if foot < -1 or foot > Layout.SOY_ZONE_HEIGHT then
		return false
	end
	for _, p in Layout.PUDDLES do
		local dx, dz = x - p.x, z - p.z
		if dx * dx + dz * dz <= p.radius * p.radius then
			return true
		end
	end
	return false
end

-- 수평 속도를 상한까지 줄여요 (상한 안이면 그대로)
function Logic.slowVelocity(vx: number, vz: number): (number, number)
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed <= Layout.SOY_MAX_SPEED or speed < 1e-6 then
		return vx, vz
	end
	local k = Layout.SOY_MAX_SPEED / speed
	return vx * k, vz * k
end

-- ── 회전 젓가락 막대 ──────────────────────────────────────────────────
-- 막대 각도(라디안, x축에서 위에서 볼 때 시계 방향). 막대는 중심을 지나는 선분 (−R ~ +R).
function Logic.barAngle(t: number): number
	return (math.max(t, 0) / Layout.BAR_PERIOD) * 2 * math.pi
end

-- 막대 방향 단위 벡터 (x, z). 위에서 볼 때 시계 방향 = 화면 위(-z)에서 오른쪽(+x)으로 → (cos, sin)으로 두면 +z가 아래라 시계 방향이에요
function Logic.barDirection(angle: number): (number, number)
	return math.cos(angle), math.sin(angle)
end

-- 중심 기준 (dx, dz)가 막대에 맞았나 (발 높이 foot = 바닥 위)
function Logic.barHit(dx: number, dz: number, foot: number, angle: number): boolean
	if foot >= Layout.BAR_HIT_FOOT then
		return false
	end
	local ux, uz = Logic.barDirection(angle)
	local along = dx * ux + dz * uz
	if math.abs(along) > Layout.BAR_RADIUS + Layout.BAR_HIT_PAD then
		return false
	end
	if math.abs(along) < Layout.HUB_RADIUS then
		return false -- 가운데 축 위는 안전
	end
	local perp = -dx * uz + dz * ux
	return math.abs(perp) <= Layout.BAR_THICKNESS / 2 + Layout.BAR_HIT_PAD
end

-- 막대가 미는 방향 (회전 접선, 단위). along이 +면 시계 방향 접선, -면 반대 쪽이 같은 회전이라 부호를 뒤집어요.
function Logic.barKnock(dx: number, dz: number, angle: number): (number, number)
	local ux, uz = Logic.barDirection(angle)
	local along = dx * ux + dz * uz
	local tx, tz = -uz, ux -- 각도가 늘어나는 방향
	if along < 0 then
		tx, tz = -tx, -tz
	end
	return tx, tz
end

-- ── 와사비 튕김판 ──────────────────────────────────────────────────────
function Logic.padAt(x: number, y: number, z: number): Layout.Circle?
	local foot = y - Layout.FOOT_OFFSET - (Layout.FLOOR_Y + Layout.PAD_TOP)
	if foot < -1 or foot > 1.2 then
		return nil
	end
	for _, pad in Layout.PADS do
		local dx, dz = x - pad.x, z - pad.z
		if dx * dx + dz * dz <= pad.radius * pad.radius then
			return pad
		end
	end
	return nil
end

function Logic.estimateClearTime(): number
	local walk = (0 - Layout.FINISH_LINE_Z) / Layout.WALK_SPEED
	local delay = #Layout.DOOR_ROWS_Z * Layout.DOOR_DELAY
	for _, value in Layout.ZONE_DELAY do
		delay += value
	end
	return walk + delay
end

return Logic
