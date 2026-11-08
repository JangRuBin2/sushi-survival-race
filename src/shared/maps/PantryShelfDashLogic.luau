--!strict
-- "팬트리 선반 대질주"(pantry-shelf-dash, m6-05) 순수 계산. Roblox API 없음.
--   progress / finishProgress / fallLineAt / rowAt(z)        진행·낙하선·지금 줄
--   windOn(row, t) / windTarget(row, t)                      줄 바람 (켜짐 여부·목표 옆 속도)
--   cans(elapsed) -> { Can }                                  통조림 자리 (2·4번째 줄, 선반마다)
--   rollHit(dx, dz, foot) / pushDelta / estimateClearTime

local Layout = require(script.Parent.PantryShelfDashLayout)

local Logic = {}

export type Can = { slot: number, shelf: number, x: number, z: number }

function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

function Logic.fallLineAt(_z: number): number
	return Layout.FLOOR_Y - Layout.FALL_MARGIN
end

-- z가 어느 줄(선반 섬 사이 틈 포함 — 앞 줄 끝 ~ 이번 줄 끝) 안인지
function Logic.rowAt(z: number): Layout.Row?
	for i, row in Layout.ROWS do
		local front = if i == 1 then row.front else Layout.ROWS[i - 1].back
		if z <= front and z > row.back then
			return row
		end
	end
	return nil
end

function Logic.windOn(row: Layout.Row, t: number): boolean
	local s = t - Layout.WIND_START_DELAY - row.phase
	if s < 0 then
		return false
	end
	return s % Layout.WIND_PERIOD < Layout.WIND_ON
end

-- 그 줄 바람의 목표 옆 속도 (+x / -x), 꺼져 있으면 0
function Logic.windTarget(row: Layout.Row, t: number): number
	return if Logic.windOn(row, t) then row.wind * Layout.WIND_SPEED else 0
end

-- 통조림: cans 줄의 선반마다, n번째 깡통은 START_DELAY + n × 간격(선반마다 반 간격 어긋남)에 줄 끝(back)에서 출발해 +z로.
function Logic.cans(elapsed: number): { Can }
	local list: { Can } = {}
	local k = 0
	for _, shelf in Layout.SHELVES do
		local row = Layout.ROWS[shelf.row]
		if not row.cans then
			continue
		end
		local t = elapsed - Layout.CAN_START_DELAY - k * Layout.CAN_INTERVAL / 2
		k += 1
		if t < 0 then
			continue
		end
		local from = row.back + Layout.CAN_DIAMETER / 2
		local to = row.front - Layout.CAN_DIAMETER / 2
		local travel = (to - from) / Layout.CAN_SPEED
		local newest = math.floor(t / Layout.CAN_INTERVAL)
		for n = newest, math.max(newest - Layout.CAN_SLOTS + 1, 0), -1 do
			local age = t - n * Layout.CAN_INTERVAL
			if age <= travel then
				local side = if n % 2 == 0 then -1 else 1
				local room = math.max(shelf.width / 2 - Layout.CAN_LENGTH / 2 - 1, 0)
				table.insert(list, {
					slot = n % Layout.CAN_SLOTS + 1,
					shelf = shelf.index,
					x = shelf.x + side * math.min(room, 6),
					z = from + age * Layout.CAN_SPEED,
				})
			end
		end
	end
	return list
end

function Logic.rollHit(dx: number, dz: number, foot: number): boolean
	return math.abs(dx) <= Layout.CAN_LENGTH / 2 + Layout.HIT_PAD
		and math.abs(dz) <= Layout.CAN_DIAMETER / 2 + Layout.HIT_PAD
		and foot < Layout.HIT_FOOT
end

function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

function Logic.estimateClearTime(): number
	return (0 - Layout.FINISH_LINE_Z) / Layout.WALK_SPEED + #Layout.ROWS * Layout.ROW_DELAY + Layout.EXTRA_DELAY
end

return Logic
