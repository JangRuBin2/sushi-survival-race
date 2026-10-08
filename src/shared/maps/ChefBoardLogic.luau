--!strict
-- "셰프의 도마"(chef-board, m4-05)의 순수 로직. Roblox API를 쓰지 않아요 (tests/map-chef-board.spec.luau).
--
-- 좌표는 도마 중심 기준 로컬 (x, z), 도마 윗면 = y 0. 격자 칸 (i, j)의 중심은 (i·8, j·8), i·j는 -4~4.
--   Logic.cells()                         도마 칸 목록 61개 (칸 중심이 CENTER_LIMIT 안)
--   Logic.isProtected(i, j)               가운데 3×3 (잘려 나가지 않아요)
--   Logic.spawnOffsets()                  스폰 24곳 (가운데 5×5 칸 중 정중앙 빼고)
--   Logic.lines()                         칼이 내려칠 수 있는 줄 18개 (Row = 같은 j, X축 방향 / Column = 같은 i, Z축 방향)
--   Logic.knifeInterval(t), warnTime(t)   경과 시간 t의 칼 주기·경고 시간
--   Logic.strikeTimes(duration)           경고가 시작되는 시각 목록
--   Logic.newBoard()                      남은 칸 상태
--   Logic.remainingOn(board, line)        그 줄에 남은 칸 수
--   Logic.pickLine(board, previous, rng)  다음 줄 (남은 칸 수 가중 랜덤, 같은 줄 연속 금지)
--   Logic.cutCells(board, line)           그 줄에서 잘려 나갈 칸 (양 끝에서 안쪽으로 첫 남은 칸, 보호 칸에서 멈춤)
--   Logic.removeCells(board, cells)
--   Logic.isOnLine(line, x, z)            칼 맞음 판정
--   Logic.knockDirection(line, x, z)      넉백 방향 (줄과 수직, 도마 중심에서 바깥쪽, 단위 벡터)
--   Logic.tiltPlan(rng)                   기울기 일정 (시작 시각 + 낮은 쪽 방향)
--   Logic.tiltCFrameParams(t, plan)       t에서의 기울기 각도(라디안)·회전축·낮은 쪽 방향·세기(0~1)
-- rng는 NextInteger(min, max)만 써요 (Random과 테스트용 가짜 rng 모두).

local ChefBoardLogic = {}

export type Cell = { i: number, j: number, x: number, z: number, key: string }
export type Axis = "Row" | "Column"
export type Line = { axis: Axis, index: number, key: string }
export type Board = { alive: { [string]: boolean } }
export type TiltEntry = { startAt: number, downX: number, downZ: number }
export type TiltParams = {
	angle: number, -- 라디안 (0 ~ TILT_MAX_DEG)
	axisX: number, -- 회전축 (수평, 단위)
	axisZ: number,
	downX: number, -- 낮은 쪽 방향 (수평, 단위)
	downZ: number,
	strength: number, -- 0~1 (각도 / 최대 각도)
}
type Rng = { NextInteger: (self: any, min: number, max: number) -> number }

-- 도마
ChefBoardLogic.BOARD_RADIUS = 36
ChefBoardLogic.BOARD_THICKNESS = 3
ChefBoardLogic.CELL_SIZE = 8
ChefBoardLogic.GRID_HALF = 4 -- 칸 번호 -4~4 (9×9)
-- 칸 중심이 이 거리 안이면 칸이 있어요. 도마 반지름 36에서 1 stud 여유 → 61칸 (스펙 결정 기록 참고)
ChefBoardLogic.CENTER_LIMIT = 35
ChefBoardLogic.PROTECTED_HALF = 1 -- |i|, |j| ≤ 1 은 보호 (가운데 3×3)
ChefBoardLogic.FALL_DEPTH = 30 -- 도마 윗면보다 이만큼 아래면 탈락

-- 칼
ChefBoardLogic.FIRST_STRIKE_AT = 3 -- 첫 경고 시각 (라운드 시작 뒤)
ChefBoardLogic.KNIFE_LENGTH = 80
ChefBoardLogic.HIT_MARGIN = 1.5 -- 줄 폭(8) 양쪽으로 캐릭터 몸 반쯤 더 맞아요
ChefBoardLogic.HIT_HEIGHT = 14 -- 도마 윗면 위 이 높이까지 맞아요 (점프해도 칼날 길이 안)
ChefBoardLogic.KNOCK_HORIZONTAL = 45
ChefBoardLogic.KNOCK_UP = 25
ChefBoardLogic.KNOCKDOWN_TIME = 1
ChefBoardLogic.CUT_SHAKE_TIME = 0.5

-- 기울기
ChefBoardLogic.TILT_TIMES = { 10, 20, 30, 40, 50 }
ChefBoardLogic.TILT_DURATION = 3
ChefBoardLogic.TILT_RAMP = 0.5 -- 기울어지고 돌아오는 데 걸리는 시간
ChefBoardLogic.TILT_MAX_DEG = 8
ChefBoardLogic.TILT_PUSH_SPEED = 6 -- 낮은 쪽으로 미는 최고 속도 (studs/s)
ChefBoardLogic.TILT_PUSH_ACCEL = 18

local function cellKey(i: number, j: number): string
	return `{i},{j}`
end
ChefBoardLogic.cellKey = cellKey

local function hasCell(i: number, j: number): boolean
	local size = ChefBoardLogic.CELL_SIZE
	local limit = ChefBoardLogic.CENTER_LIMIT
	return (i * size) ^ 2 + (j * size) ^ 2 <= limit * limit
end

function ChefBoardLogic.isProtected(i: number, j: number): boolean
	local h = ChefBoardLogic.PROTECTED_HALF
	return math.abs(i) <= h and math.abs(j) <= h
end

function ChefBoardLogic.cells(): { Cell }
	local list: { Cell } = {}
	local g = ChefBoardLogic.GRID_HALF
	local size = ChefBoardLogic.CELL_SIZE
	for j = -g, g do
		for i = -g, g do
			if hasCell(i, j) then
				table.insert(list, { i = i, j = j, x = i * size, z = j * size, key = cellKey(i, j) })
			end
		end
	end
	return list
end

-- 가운데 5×5 칸 중심 (정중앙 칸 제외) = 24곳
function ChefBoardLogic.spawnOffsets(): { { x: number, z: number } }
	local list = {}
	local size = ChefBoardLogic.CELL_SIZE
	for j = -2, 2 do
		for i = -2, 2 do
			if not (i == 0 and j == 0) then
				table.insert(list, { x = i * size, z = j * size })
			end
		end
	end
	return list
end

local function makeLine(axis: Axis, index: number): Line
	return { axis = axis, index = index, key = `{axis}{index}` }
end
ChefBoardLogic.makeLine = makeLine

function ChefBoardLogic.lines(): { Line }
	local list: { Line } = {}
	local g = ChefBoardLogic.GRID_HALF
	for index = -g, g do
		table.insert(list, makeLine("Row", index))
	end
	for index = -g, g do
		table.insert(list, makeLine("Column", index))
	end
	return list
end

-- 줄 위의 칸 (줄 방향 좌표 순, 도마에 원래 있는 칸만)
local function cellsOnLine(line: Line): { { i: number, j: number } }
	local list = {}
	local g = ChefBoardLogic.GRID_HALF
	for along = -g, g do
		local i = if line.axis == "Row" then along else line.index
		local j = if line.axis == "Row" then line.index else along
		if hasCell(i, j) then
			table.insert(list, { i = i, j = j })
		end
	end
	return list
end

---------------------------------------------------------------- 칼 일정

function ChefBoardLogic.knifeInterval(t: number): number
	if t < 20 then
		return 6
	elseif t < 40 then
		return 4.5
	end
	return 3
end

function ChefBoardLogic.warnTime(t: number): number
	return if t < 40 then 1.2 else 0.8
end

-- 경고 시작 시각들 (duration 전까지). 다음 경고 = 이번 경고 + 이번 시각의 주기.
function ChefBoardLogic.strikeTimes(duration: number): { number }
	local list = {}
	local t = ChefBoardLogic.FIRST_STRIKE_AT
	while t < duration do
		table.insert(list, t)
		t += ChefBoardLogic.knifeInterval(t)
	end
	return list
end

---------------------------------------------------------------- 남은 칸

function ChefBoardLogic.newBoard(): Board
	local alive = {}
	for _, cell in ChefBoardLogic.cells() do
		alive[cell.key] = true
	end
	return { alive = alive }
end

function ChefBoardLogic.isAlive(board: Board, i: number, j: number): boolean
	return board.alive[cellKey(i, j)] == true
end

function ChefBoardLogic.remainingOn(board: Board, line: Line): number
	local count = 0
	for _, c in cellsOnLine(line) do
		if board.alive[cellKey(c.i, c.j)] then
			count += 1
		end
	end
	return count
end

-- 남은 칸 수만큼 가중치를 줘서 고르고, 바로 전 줄(previousKey)과 남은 칸 0인 줄은 빼요.
-- 고를 줄이 없으면 nil (가운데 줄은 보호 칸이 있어서 실제로는 생기지 않아요).
function ChefBoardLogic.pickLine(board: Board, previousKey: string?, rng: Rng): Line?
	local candidates: { Line } = {}
	local weights: { number } = {}
	local total = 0
	for _, line in ChefBoardLogic.lines() do
		local remaining = ChefBoardLogic.remainingOn(board, line)
		if remaining > 0 and line.key ~= previousKey then
			table.insert(candidates, line)
			table.insert(weights, remaining)
			total += remaining
		end
	end
	if total == 0 then
		return nil
	end
	local roll = rng:NextInteger(1, total)
	for index, line in candidates do
		roll -= weights[index]
		if roll <= 0 then
			return line
		end
	end
	return candidates[#candidates]
end

-- 줄 양 끝에서 안쪽으로 걸어가며 처음 만나는 남은 칸 (보호 칸을 만나면 그쪽은 멈춤). 최대 2칸, 겹치면 1칸.
function ChefBoardLogic.cutCells(board: Board, line: Line): { Cell }
	local onLine = cellsOnLine(line)
	local picked: { Cell } = {}
	local seen: { [string]: boolean } = {}
	local size = ChefBoardLogic.CELL_SIZE
	local function walk(from: number, to: number, step: number)
		for index = from, to, step do
			local c = onLine[index]
			if ChefBoardLogic.isProtected(c.i, c.j) then
				return
			end
			local key = cellKey(c.i, c.j)
			if board.alive[key] then
				if not seen[key] then
					seen[key] = true
					table.insert(picked, { i = c.i, j = c.j, x = c.i * size, z = c.j * size, key = key })
				end
				return
			end
		end
	end
	walk(1, #onLine, 1)
	walk(#onLine, 1, -1)
	return picked
end

function ChefBoardLogic.removeCells(board: Board, cells: { Cell })
	for _, cell in cells do
		board.alive[cell.key] = nil
	end
end

---------------------------------------------------------------- 칼 맞음

-- 줄 중심선 좌표 (Row면 z, Column이면 x)
function ChefBoardLogic.lineOffset(line: Line): number
	return line.index * ChefBoardLogic.CELL_SIZE
end

function ChefBoardLogic.isOnLine(line: Line, x: number, z: number): boolean
	local across = if line.axis == "Row" then z else x
	local along = if line.axis == "Row" then x else z
	local halfWidth = ChefBoardLogic.CELL_SIZE / 2 + ChefBoardLogic.HIT_MARGIN
	return math.abs(across - ChefBoardLogic.lineOffset(line)) <= halfWidth
		and math.abs(along) <= ChefBoardLogic.KNIFE_LENGTH / 2
end

-- 줄과 수직이고 도마 중심에서 멀어지는 쪽. 가운데 줄(index 0)은 플레이어가 있는 쪽 (정확히 가운데면 +).
function ChefBoardLogic.knockDirection(line: Line, x: number, z: number): (number, number)
	local across = if line.axis == "Row" then z else x
	local sign: number
	if line.index ~= 0 then
		sign = if line.index > 0 then 1 else -1
	else
		sign = if across < 0 then -1 else 1
	end
	if line.axis == "Row" then
		return 0, sign
	end
	return sign, 0
end

---------------------------------------------------------------- 기울기

function ChefBoardLogic.tiltPlan(rng: Rng): { TiltEntry }
	local plan: { TiltEntry } = {}
	for _, startAt in ChefBoardLogic.TILT_TIMES do
		local angle = math.rad(rng:NextInteger(0, 359))
		table.insert(plan, { startAt = startAt, downX = math.cos(angle), downZ = math.sin(angle) })
	end
	return plan
end

-- 0~1: 0.5초 동안 기울어지고, 유지하다가, 마지막 0.5초 동안 돌아와요 (부드럽게).
local function tiltStrength(local_t: number): number
	local duration = ChefBoardLogic.TILT_DURATION
	local ramp = ChefBoardLogic.TILT_RAMP
	if local_t <= 0 or local_t >= duration then
		return 0
	end
	local a = math.min(local_t / ramp, (duration - local_t) / ramp, 1)
	return a * a * (3 - 2 * a) -- smoothstep
end

-- t에 기울어 있으면 각도·축·방향, 평평하면 nil.
-- 회전축 = 위(Y) × 낮은 쪽 = (downZ, 0, -downX): 이 축으로 angle만큼 돌리면 낮은 쪽 가장자리가 내려가요.
function ChefBoardLogic.tiltCFrameParams(t: number, plan: { TiltEntry }): TiltParams?
	for _, entry in plan do
		local strength = tiltStrength(t - entry.startAt)
		if strength > 0 then
			return {
				angle = math.rad(ChefBoardLogic.TILT_MAX_DEG) * strength,
				axisX = entry.downZ,
				axisZ = -entry.downX,
				downX = entry.downX,
				downZ = entry.downZ,
				strength = strength,
			}
		end
	end
	return nil
end

return ChefBoardLogic
