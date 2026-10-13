--!strict
-- "인형뽑기 기계 속"(m5-19)의 순수 로직: 집게 주기·구역 크기·경고 시간표, 집게가 노릴 구역 고르기,
-- 들어 올리는 칸 목록(격자 잘림 포함), 연장전 상자 기울기 일정. Roblox API를 쓰지 않아서 lune에서 그대로 불러요.
--   ClawMachinePrizeLogic.clawWave(elapsed, overtimeAt?) -> Wave?     표대로 (interval, size, warnTime). 출발 5초 전은 nil
--   ClawMachinePrizeLogic.liftedTiles(centerRow, centerCol, size, gridSize) -> { Tile }
--     size가 짝수면 (centerRow, centerCol)이 왼쪽/위쪽 모서리(항상 격자 안에 들어오게 호출 쪽이 보장),
--     홀수면 (centerRow, centerCol)이 가운데 칸(격자 밖으로 나가는 부분은 잘려요).
--   ClawMachinePrizeLogic.pickClawTarget(rng, racerTiles, aliveTiles, size, gridSize?) -> { Tile }
--     70% 레이서가 가장 많이 모인 창(동점은 무작위), 30% 무작위 위치. 돌려주는 칸은 전부 aliveTiles 안의 것.
--   ClawMachinePrizeLogic.overtimeTilt(collapseDuration, warnTime, rows) -> { TiltStep }
--     낮은 쪽부터 rows줄, 각 줄 warnTime 경고 뒤 사라지고 마지막 줄이 collapseDuration에 사라져요.
--     tiltAngle은 그 시각의 상자 기울기(0~OVERTIME_MAX_TILT도, 단조 증가).
--   ClawMachinePrizeLogic.reserveTiles(aliveRacers) -> number     연장전 전 집게가 남겨 두는 최소 칸 수 (QA B2)
--   ClawMachinePrizeLogic.capGrab(chosen, aliveCount, aliveRacers, racerTiles) -> { Tile }
--     남은 칸이 reserveTiles 아래로 내려가지 않게 집을 칸을 줄여요(사람이 서 있는 칸 먼저 남겨 둬요). 0개면 그 차례 쉬어요.
--   ClawMachinePrizeLogic.tiltRotation(dim, sign, angleRad) -> (rx, rz)   CFrame.Angles(rx, 0, rz) 인자 (QA B1)
--   ClawMachinePrizeLogic.tiltedHeight(dim, sign, lateral, angleRad) -> number
--     격자 중심을 축으로 돌렸을 때 격자 면 위 한 점(줄 방향 오프셋 lateral)의 높이 변화
--   ClawMachinePrizeLogic.tiltLineOrder(dim, sign, gridSize) -> { number }   낮아지는 쪽부터 사라질 줄 번호(0~)

local Logic = {}

export type Tile = { row: number, col: number }
export type Wave = { interval: number, size: number, warnTime: number }
export type TiltStep = { row: number, warnAt: number, dropAt: number, tiltAngle: number }

Logic.DEFAULT_GRID_SIZE = 8
Logic.START_GRACE = 5 -- 출발 뒤 이 초까지는 집게가 쉬어요
Logic.PICK_RETRIES = 5 -- 창이 전부 이미 없는 칸이면 이만큼 더 무작위로 다시 골라요
Logic.CROWD_CHANCE = 0.7 -- 사람이 몰린 창을 고를 확률 (나머지는 무작위)
Logic.OVERTIME_MAX_TILT = 35 -- 연장전 끝(연장전 collapseDuration 시점)의 상자 기울기(도)

-- 출발 기준 elapsed(초) → 그 순간 집게 주기·구역 크기·경고 시간. overtimeAt(연장전 시작 초)이 있고
-- 지났으면 연장전 값. 아직 출발 5초 전이면 nil(집게가 안 움직여요).
function Logic.clawWave(elapsed: number, overtimeAt: number?): Wave?
	if overtimeAt ~= nil and elapsed >= overtimeAt then
		return { interval = 2.5, size = 3, warnTime = 1 }
	end
	if elapsed < Logic.START_GRACE then
		return nil
	end
	if elapsed < 30 then
		return { interval = 8, size = 2, warnTime = 2 }
	end
	if elapsed < 60 then
		return { interval = 6, size = 2, warnTime = 1.5 }
	end
	return { interval = 4, size = 3, warnTime = 1.2 }
end

-- size 크기 창의 칸 목록 (격자 밖은 잘려요). size가 짝수면 centerRow·centerCol이 창의 낮은 쪽 모서리,
-- 홀수면 가운데 칸이에요 (그래서 호출 쪽이 짝수 창을 항상 격자 안에 들어오게 고르면 절대 안 잘려요).
function Logic.liftedTiles(centerRow: number, centerCol: number, size: number, gridSize: number): { Tile }
	local tiles: { Tile } = {}
	if size <= 0 then
		return tiles
	end
	local rowLo, colLo
	if size % 2 == 0 then
		rowLo, colLo = centerRow, centerCol
	else
		local half = (size - 1) / 2
		rowLo, colLo = centerRow - half, centerCol - half
	end
	local rowHi, colHi = rowLo + size - 1, colLo + size - 1
	for row = math.max(0, rowLo), math.min(gridSize - 1, rowHi) do
		for col = math.max(0, colLo), math.min(gridSize - 1, colHi) do
			table.insert(tiles, { row = row, col = col })
		end
	end
	return tiles
end

local function tileKey(tile: Tile, gridSize: number): number
	return tile.row * gridSize + tile.col
end

-- aliveTiles 안의 칸만 걸러요.
local function filterAlive(tiles: { Tile }, aliveSet: { [number]: boolean }, gridSize: number): { Tile }
	local out: { Tile } = {}
	for _, tile in tiles do
		if aliveSet[tileKey(tile, gridSize)] then
			table.insert(out, tile)
		end
	end
	return out
end

local function countRacers(tiles: { Tile }, racerTiles: { Tile }): number
	local n = 0
	for _, tile in tiles do
		for _, racer in racerTiles do
			if racer.row == tile.row and racer.col == tile.col then
				n += 1
			end
		end
	end
	return n
end

-- 집게가 노릴 구역 고르기. 70% 레이서가 가장 많이 모인 창(동점은 무작위 하나), 30% 무작위 위치.
-- 고른 창이 aliveTiles와 안 겹치면(바닥이 거의 다 사라짐) 무작위로 최대 PICK_RETRIES번 다시 고르고,
-- 그래도 없으면 남은 칸 전부를 돌려줘요. 살아 있는 칸이 창 크기보다 적게 남으면 바로 남은 칸 전부.
function Logic.pickClawTarget(
	rng: Random,
	racerTiles: { Tile },
	aliveTiles: { Tile },
	size: number,
	gridSize: number?
): { Tile }
	local grid = gridSize or Logic.DEFAULT_GRID_SIZE
	if #aliveTiles <= size * size then
		return table.clone(aliveTiles)
	end
	local aliveSet: { [number]: boolean } = {}
	for _, tile in aliveTiles do
		aliveSet[tileKey(tile, grid)] = true
	end

	local lo: number, hi: number
	if size % 2 == 0 then
		lo, hi = 0, grid - size
	else
		lo, hi = 0, grid - 1
	end

	local function window(centerRow: number, centerCol: number): { Tile }
		return Logic.liftedTiles(centerRow, centerCol, size, grid)
	end

	local function pickCrowded(): Tile
		local best: { Tile } = {}
		local bestCount = -1
		for row = lo, hi do
			for col = lo, hi do
				local count = countRacers(window(row, col), racerTiles)
				if count > bestCount then
					bestCount, best = count, { { row = row, col = col } }
				elseif count == bestCount then
					table.insert(best, { row = row, col = col })
				end
			end
		end
		return best[rng:NextInteger(1, #best)]
	end

	local function pickRandom(): Tile
		return { row = rng:NextInteger(lo, hi), col = rng:NextInteger(lo, hi) }
	end

	local useCrowded = rng:NextNumber() < Logic.CROWD_CHANCE
	for attempt = 1, Logic.PICK_RETRIES do
		local center = if attempt == 1 and useCrowded then pickCrowded() else pickRandom()
		local result = filterAlive(window(center.row, center.col), aliveSet, grid)
		if #result > 0 then
			return result
		end
	end
	return table.clone(aliveTiles)
end

-- 연장전 전(시간 제한 90초까지) 집게가 남겨 두는 최소 칸 수 (QA B2, 메인 세션 결정).
Logic.RESERVE_MIN = 6
Logic.RESERVE_PER_RACER = 2
function Logic.reserveTiles(aliveRacers: number): number
	return math.max(Logic.RESERVE_MIN, Logic.RESERVE_PER_RACER * math.max(0, aliveRacers))
end

-- 고른 칸(chosen)을 들면 남은 칸(aliveCount, 아직 경고·들어 올리는 중이 아닌 칸 수)이 reserveTiles 아래로
-- 내려가면 그만큼만 들게 줄여요. 줄일 때는 사람이 서 있는 칸을 먼저 남겨 집고(집게가 노린 사람을 놓치지
-- 않게), 나머지는 chosen 순서대로예요. 여유가 없으면 빈 목록(그 차례 쉼).
function Logic.capGrab(chosen: { Tile }, aliveCount: number, aliveRacers: number, racerTiles: { Tile }?): { Tile }
	local allowed = aliveCount - Logic.reserveTiles(aliveRacers)
	if allowed <= 0 then
		return {}
	end
	if #chosen <= allowed then
		return chosen
	end
	local occupied: { Tile } = {}
	local empty: { Tile } = {}
	for _, tile in chosen do
		local hasRacer = false
		for _, racer in racerTiles or {} do
			if racer.row == tile.row and racer.col == tile.col then
				hasRacer = true
				break
			end
		end
		table.insert(if hasRacer then occupied else empty, tile)
	end
	local out: { Tile } = {}
	for _, list in { occupied, empty } do
		for _, tile in list do
			if #out >= allowed then
				return out
			end
			table.insert(out, tile)
		end
	end
	return out
end

-- 연장전 기울기 방향(dim = "row"면 로컬 X축, "col"이면 로컬 Z축 회전, sign = ±1)과 각도(라디안)
-- → CFrame.Angles(rx, 0, rz)에 넣을 값. 회전 중심은 격자 중심이에요(호출 쪽, QA B1).
function Logic.tiltRotation(dim: string, sign: number, angle: number): (number, number)
	if dim == "row" then
		return sign * angle, 0
	end
	return 0, sign * angle
end

-- 격자 중심을 축으로 tiltRotation만큼 돌렸을 때, 격자 면(높이 0) 위 한 점의 높이. lateral은 회전에 영향을
-- 받는 축의 격자 중심 기준 오프셋(row 방향이면 로컬 Z, col 방향이면 로컬 X). CFrame.Angles와 같은 공식:
-- X축 회전 rx: y' = y·cos − z·sin, Z축 회전 rz: y' = x·sin + y·cos.
function Logic.tiltedHeight(dim: string, sign: number, lateral: number, angle: number): number
	local rx, rz = Logic.tiltRotation(dim, sign, angle)
	if dim == "row" then
		return -lateral * math.sin(rx)
	end
	return lateral * math.sin(rz)
end

-- 그 방향으로 기울 때 실제로 내려가는 쪽부터 줄 번호(0 ~ gridSize-1) 순서. tiltedHeight 부호로 정해서
-- 회전 공식과 줄 순서가 어긋날 수 없어요.
function Logic.tiltLineOrder(dim: string, sign: number, gridSize: number): { number }
	local order: { number } = {}
	for i = 0, gridSize - 1 do
		table.insert(order, i)
	end
	local function heightOf(i: number): number
		return Logic.tiltedHeight(dim, sign, i - (gridSize - 1) / 2, math.rad(10))
	end
	table.sort(order, function(a, b)
		return heightOf(a) < heightOf(b)
	end)
	return order
end

-- 연장전 상자 기울기 일정 (m5-01 계약). rows줄(낮은 쪽부터 1~rows)이 순서대로 사라져요. 각 줄은
-- warnTime 동안 경고한 뒤 사라지고, 첫 줄 경고는 0초, 마지막 줄(가장 높은 쪽)은 collapseDuration에 사라져요.
-- tiltAngle은 그 줄이 사라지는 시각의 상자 기울기(0~OVERTIME_MAX_TILT, dropAt에 비례).
function Logic.overtimeTilt(collapseDuration: number, warnTime: number, rows: number): { TiltStep }
	local steps: { TiltStep } = {}
	if rows <= 0 or collapseDuration <= 0 then
		return steps
	end
	local warn = math.min(warnTime, collapseDuration / rows)
	local spacing = if rows > 1 then (collapseDuration - warn) / (rows - 1) else 0
	for i = 1, rows do
		local dropAt = if rows > 1 then warn + spacing * (i - 1) else collapseDuration
		local tiltAngle = Logic.OVERTIME_MAX_TILT * (dropAt / collapseDuration)
		table.insert(steps, { row = i, warnAt = dropAt - warn, dropAt = dropAt, tiltAngle = tiltAngle })
	end
	return steps
end

return Logic
