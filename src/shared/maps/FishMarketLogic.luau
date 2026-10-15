--!strict
-- "수산시장"(fish-market, m5-37) 순수 로직: 얼음 블록 개수·위치·줄 옮기기, 얼음 맞음, 생선 낙하 일정,
-- 생선 과녁 고르기, 생선 넉백(철퍼덕·팔딱). Roblox API를 쓰지 않아서 lune에서 그대로 불러요.
-- 좌표는 전부 origin 기준 로컬 (x, z), 높이는 상자 윗면(y 0) 기준.
--
--   Logic.iceCount(t) -> number                         그 시각에 있어야 할 얼음 블록 수 (0·2·3·4)
--   Logic.travelTime(departAt) -> number                 한 줄을 끝에서 끝까지 미끄러지는 시간 (8 / 60초부터 6.7)
--   Logic.newIceBlock(row, dir, born) -> IceBlock        dir 1 = −X 끝에서 +X로 출발, born = 출발 시각 (그 전엔 끝에서 대기)
--   Logic.iceState(block, t) -> IceState                 지금 다리(leg)·단계(Wait/Move/Pause)·row·x·진행 방향
--   Logic.icePosition(block, t) -> (row, x)              row는 줄을 옮기는 동안 소수
--   Logic.newIceDirector() -> IceDirector                 서버 한 라운드의 얼음 상태 (ctx 지역 변수)
--   Logic.stepIce(director, t, rng) -> { IceEvent }      블록 추가·줄 옮기기 결정 (같은 줄에 2개 금지)
--   Logic.iceHit(dx, dz, footY) -> boolean               (dx, dz) = 레이서 − 블록 중심, footY = 발 높이
--   Logic.fishWave(t) -> FishWave?                       생선 간격·한 번에 마리 수 (8초 전은 nil)
--   Logic.cratePairs(crates) -> { Pair }                 이웃 상자 쌍 (가로·세로) 전부
--   Logic.pickFishTarget(rng, racers, crates, lying) -> Pair?   60% 레이서가 가장 많은 쌍, 40% 무작위
--   Logic.fishKnockback(axis, rel) -> Knock?             철퍼덕 순간 (과녁 상자 위 36 + 22, 몸에서 6 안 18 + 12)
--   Logic.flopKnockback(axis, rel) -> Knock?             누운 생선 팔딱 (몸에서 4 안, 위 포함, 16 + 16)

local Layout = require(script.Parent.FishMarketLayout)

local Logic = {}

export type Rng = {
	NextNumber: (self: any) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

export type IceBlock = {
	id: number,
	born: number, -- 첫 출발 시각 (그 전엔 출발 끝에서 경고와 함께 대기)
	startDir: number, -- 1 = −X 끝에서 +X로, −1 = 반대
	rows: { number }, -- rows[k] = k번째 다리의 줄. 다음 줄은 멈출 때 stepIce가 정해요
}
export type IcePhase = "Wait" | "Move" | "Pause"
export type IceState = {
	leg: number,
	phase: IcePhase,
	row: number, -- 줄을 옮기는 동안 소수
	x: number,
	dir: number, -- 이번 다리 진행 방향 (Move일 때 넉백 방향)
	legStart: number,
	pauseStart: number,
}
export type IceDirector = { blocks: { IceBlock }, nextId: number }
export type IceEvent = {
	kind: "Spawn" | "Shift",
	block: IceBlock,
	row: number, -- 경고를 띄울 줄
	side: number, -- 경고를 띄울 끝 (−1 = Col 0 쪽, 1 = Col 5 쪽)
	dir: number, -- 블록이 그 줄에서 나아갈 방향 (화살표 방향)
	at: number,
}

export type FishWave = { interval: number, count: number }
export type Cell = { row: number, col: number }
export type Pair = { a: Cell, b: Cell, axis: "X" | "Z", centerX: number, centerZ: number }
export type Point = { x: number, z: number }
export type Rel = { x: number, y: number, z: number }
export type Knock = { dirX: number, dirZ: number, horizontal: number, up: number }

---------------------------------------------------------------- 얼음 블록
Logic.ICE_SIZE = 8 -- 블록 가로·세로
Logic.ICE_HEIGHT = 7 -- 블록 높이 (점프 6.4보다 높아서 뛰어넘을 수 없어요)
Logic.JUMP_HEIGHT = 6.4 -- 걷기 점프 높이 근사 (JumpPower 50)
Logic.ICE_X_END = 50 -- 블록 중심이 미끄러지는 x 범위 ±50 (격자 반폭 42.5 밖에서 멈춰요)
Logic.ICE_SPEED = 12.5
Logic.ICE_SPEED_LATE = 15 -- 서든데스(60초~) 속도
Logic.LATE_AT = 60 -- 서든데스 시작
Logic.ICE_PAUSE = 2 -- 끝에서 멈추는 시간
Logic.ICE_WARN = 1.5 -- 새 줄 끝 상자의 파란 화살표 경고
Logic.ICE_SHIFT_START = 0.5 -- 멈춘 뒤 이만큼 있다가 옆 줄로 미끄러져 옮겨요
Logic.ICE_SHIFT_TIME = 1.0
Logic.ICE_SHIFT_CHANCE = 0.5 -- 멈출 때 옆 줄로 옮길 확률 (나머지는 그대로)
Logic.ICE_HIT_MARGIN = 1 -- 맞음 상자를 x·z로 이만큼 늘려요
Logic.ICE_KNOCK_HORIZONTAL = 30
Logic.ICE_KNOCK_UP = 12
Logic.ICE_MOVE_EXEMPT = 1.2
Logic.ICE_COOLDOWN = 0.8

---------------------------------------------------------------- 생선
Logic.FISH_START = 8
Logic.FISH_WARN = 2 -- ⚠ 표지·그림자 → 철퍼덕
Logic.FISH_SIGN_HEIGHT = 30 -- ⚠ 표지 높이 (상자 윗면 위)
Logic.FISH_DROP_HEIGHT = 60 -- 생선이 내려오기 시작하는 높이
Logic.FISH_LENGTH = 20
Logic.FISH_WIDTH = 6
Logic.FISH_HEIGHT = 5
Logic.FISH_LIE = 5 -- 누워 있는 시간
Logic.FISH_FLOP_AT = 2.5 -- 누운 뒤 팔딱 시각
Logic.FISH_COLLIDE_DELAY = 0.2 -- 철퍼덕 뒤 이만큼 있다가 CanCollide (밀려나는 사람과 겹치지 않게)
Logic.MAX_LYING = 2 -- 누워 있는 생선 최대 (넘치면 가장 오래된 것부터 먼저 가라앉아요)
Logic.RACER_CHANCE = 0.6 -- 레이서가 가장 많은 쌍을 노릴 확률
Logic.SLAM_HORIZONTAL = 36
Logic.SLAM_UP = 22
Logic.SPLASH_RADIUS = 6 -- 몸에서 이 안이면 약한 넉백
Logic.SPLASH_HORIZONTAL = 18
Logic.SPLASH_UP = 12
Logic.FLOP_RADIUS = 4
Logic.FLOP_HORIZONTAL = 16
Logic.FLOP_UP = 16
Logic.FISH_MOVE_EXEMPT = 1.5
Logic.FISH_COOLDOWN = 0.6

---------------------------------------------------------------- 넉백 공통
Logic.KNOCK_HOLD = 0.12 -- LinearVelocity를 거는 시간
Logic.PLATFORM_STAND = 0.8 -- 넘어지는 시간

function Logic.iceCount(t: number): number
	if t < 5 then
		return 0
	elseif t < 25 then
		return 2
	elseif t < 45 then
		return 3
	end
	return 4
end

function Logic.travelTime(departAt: number): number
	local speed = if departAt >= Logic.LATE_AT then Logic.ICE_SPEED_LATE else Logic.ICE_SPEED
	return 2 * Logic.ICE_X_END / speed
end

function Logic.newIceBlock(row: number, dir: number, born: number, id: number?): IceBlock
	return { id = id or 0, born = born, startDir = if dir < 0 then -1 else 1, rows = { row } }
end

local MAX_LEGS = 10000

function Logic.iceState(block: IceBlock, t: number): IceState
	local dir = block.startDir
	local row = block.rows[1]
	local x0 = -dir * Logic.ICE_X_END
	if t < block.born then
		return { leg = 1, phase = "Wait", row = row, x = x0, dir = dir, legStart = block.born, pauseStart = block.born }
	end
	local legStart = block.born
	for leg = 1, MAX_LEGS do
		row = block.rows[leg] or row
		local travel = Logic.travelTime(legStart)
		local moveEnd = legStart + travel
		local pauseEnd = moveEnd + Logic.ICE_PAUSE
		if t < moveEnd then
			local alpha = (t - legStart) / travel
			return {
				leg = leg,
				phase = "Move",
				row = row,
				x = -dir * Logic.ICE_X_END + dir * 2 * Logic.ICE_X_END * alpha,
				dir = dir,
				legStart = legStart,
				pauseStart = moveEnd,
			}
		elseif t < pauseEnd then
			local shownRow = row
			local nextRow = block.rows[leg + 1]
			if nextRow and nextRow ~= row then
				local alpha = math.clamp((t - moveEnd - Logic.ICE_SHIFT_START) / Logic.ICE_SHIFT_TIME, 0, 1)
				shownRow = row + (nextRow - row) * alpha
			end
			return {
				leg = leg,
				phase = "Pause",
				row = shownRow,
				x = dir * Logic.ICE_X_END,
				dir = dir,
				legStart = legStart,
				pauseStart = moveEnd,
			}
		end
		legStart = pauseEnd
		dir = -dir
	end
	return {
		leg = MAX_LEGS,
		phase = "Pause",
		row = row,
		x = dir * Logic.ICE_X_END,
		dir = dir,
		legStart = legStart,
		pauseStart = legStart,
	}
end

function Logic.icePosition(block: IceBlock, t: number): (number, number)
	local state = Logic.iceState(block, t)
	return state.row, state.x
end

function Logic.newIceDirector(): IceDirector
	return { blocks = {}, nextId = 1 }
end

-- 블록이 지금 쓰고 있거나 곧 옮겨 갈 줄 (다른 블록이 못 들어와요)
local function claimedRows(director: IceDirector, t: number, except: IceBlock?): { [number]: boolean }
	local claimed: { [number]: boolean } = {}
	for _, block in director.blocks do
		if block == except then
			continue
		end
		local state = Logic.iceState(block, t)
		local current = block.rows[state.leg] or block.rows[#block.rows]
		claimed[current] = true
		local nextRow = block.rows[state.leg + 1]
		if nextRow then
			claimed[nextRow] = true
		end
	end
	return claimed
end

local function pickFrom(rng: Rng, list: { number }): number
	return list[rng:NextInteger(1, #list)]
end

-- 한 틱: (1) 끝에서 멈춘 블록의 다음 줄을 정해요 (50% 빈 옆 줄, 아니면 그대로). (2) 개수가 모자라면 빈 줄 끝에
-- 새 블록을 둬요 (경고 ICE_WARN 뒤 출발). 같은 줄에 블록 2개가 동시에 있지 않아요.
function Logic.stepIce(director: IceDirector, t: number, rng: Rng): { IceEvent }
	local events: { IceEvent } = {}
	for _, block in director.blocks do
		local state = Logic.iceState(block, t)
		if state.phase ~= "Pause" or block.rows[state.leg + 1] ~= nil then
			continue
		end
		local row = block.rows[state.leg]
		local nextRow = row
		if rng:NextNumber() < Logic.ICE_SHIFT_CHANCE then
			local claimed = claimedRows(director, t, block)
			local options: { number } = {}
			for _, candidate in { row - 1, row + 1 } do
				if candidate >= 0 and candidate < Layout.GRID and not claimed[candidate] then
					table.insert(options, candidate)
				end
			end
			if #options > 0 then
				nextRow = pickFrom(rng, options)
			end
		end
		block.rows[state.leg + 1] = nextRow
		if nextRow ~= row then
			-- 블록은 이번 끝(state.dir 쪽)에서 반대 방향(−state.dir)으로 출발해요
			local shift: IceEvent = {
				kind = "Shift",
				block = block,
				row = nextRow,
				side = state.dir,
				dir = -state.dir,
				at = t,
			}
			table.insert(events, shift)
		end
	end
	local want = Logic.iceCount(t)
	while #director.blocks < want do
		local claimed = claimedRows(director, t, nil)
		local free: { number } = {}
		for row = 0, Layout.GRID - 1 do
			if not claimed[row] then
				table.insert(free, row)
			end
		end
		if #free == 0 then
			break
		end
		local row = pickFrom(rng, free)
		local dir = if rng:NextNumber() < 0.5 then 1 else -1
		local block = Logic.newIceBlock(row, dir, t + Logic.ICE_WARN, director.nextId)
		director.nextId += 1
		table.insert(director.blocks, block)
		local spawn: IceEvent = { kind = "Spawn", block = block, row = row, side = -dir, dir = dir, at = t }
		table.insert(events, spawn)
	end
	return events
end

function Logic.iceHit(dx: number, dz: number, footY: number): boolean
	local half = Logic.ICE_SIZE / 2 + Logic.ICE_HIT_MARGIN
	return math.abs(dx) <= half and math.abs(dz) <= half and footY < Logic.ICE_HEIGHT
end

---------------------------------------------------------------- 생선

function Logic.fishWave(t: number): FishWave?
	if t < Logic.FISH_START then
		return nil
	elseif t < 30 then
		return { interval = 8, count = 1 }
	elseif t < 45 then
		return { interval = 6, count = 1 }
	elseif t < Logic.LATE_AT then
		return { interval = 4.5, count = 2 }
	end
	return { interval = 4, count = 2 }
end

function Logic.cratePairs(crates: { Layout.Crate }): { Pair }
	local exists: { [string]: boolean } = {}
	for _, crate in crates do
		exists[Layout.crateKey(crate.row, crate.col)] = true
	end
	local pairs: { Pair } = {}
	for _, crate in crates do
		local r, c = crate.row, crate.col
		if exists[Layout.crateKey(r, c + 1)] then
			table.insert(pairs, {
				a = { row = r, col = c },
				b = { row = r, col = c + 1 },
				axis = "X" :: "X",
				centerX = (Layout.colX(c) + Layout.colX(c + 1)) / 2,
				centerZ = Layout.rowZ(r),
			})
		end
		if exists[Layout.crateKey(r + 1, c)] then
			table.insert(pairs, {
				a = { row = r, col = c },
				b = { row = r + 1, col = c },
				axis = "Z" :: "Z",
				centerX = Layout.colX(c),
				centerZ = (Layout.rowZ(r) + Layout.rowZ(r + 1)) / 2,
			})
		end
	end
	return pairs
end

-- racers = 레이서 로컬 위치(x, z), lying = 누워 있거나 떨어지는 중인 생선이 차지한 상자 key 집합.
-- 60% = 두 상자 위 레이서 수 합이 가장 큰 쌍(같으면 무작위), 40% = 무작위 쌍. 쓸 수 있는 쌍이 없으면 nil.
function Logic.pickFishTarget(
	rng: Rng,
	racers: { Point },
	crates: { Layout.Crate },
	lying: { [string]: boolean }
): Pair?
	local counts: { [string]: number } = {}
	for _, p in racers do
		local row, col = Layout.crateAt(p.x, p.z)
		if row and col then
			local key = Layout.crateKey(row, col)
			counts[key] = (counts[key] or 0) + 1
		end
	end
	local candidates: { Pair } = {}
	for _, pair in Logic.cratePairs(crates) do
		local ka, kb = Layout.crateKey(pair.a.row, pair.a.col), Layout.crateKey(pair.b.row, pair.b.col)
		if not lying[ka] and not lying[kb] then
			table.insert(candidates, pair)
		end
	end
	if #candidates == 0 then
		return nil
	end
	if rng:NextNumber() < Logic.RACER_CHANCE then
		local best = -1
		local bestList: { Pair } = {}
		for _, pair in candidates do
			local score = (counts[Layout.crateKey(pair.a.row, pair.a.col)] or 0)
				+ (counts[Layout.crateKey(pair.b.row, pair.b.col)] or 0)
			if score > best then
				best = score
				bestList = { pair }
			elseif score == best then
				table.insert(bestList, pair)
			end
		end
		return bestList[rng:NextInteger(1, #bestList)]
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function axisParts(axis: "X" | "Z", rel: Rel): (number, number)
	if axis == "X" then
		return rel.x, rel.z
	end
	return rel.z, rel.x
end

local function toWorldDir(axis: "X" | "Z", along: number, across: number): (number, number)
	local length = math.sqrt(along * along + across * across)
	if length < 1e-6 then
		along, across, length = 0, 1, 1
	end
	along, across = along / length, across / length
	if axis == "X" then
		return along, across
	end
	return across, along
end

local function sign(n: number): number
	return if n < 0 then -1 else 1
end

-- 철퍼덕. rel = 레이서 − 생선 중심 (x, z 로컬, y = 발 높이 − 상자 윗면). axis = 생선 긴 축.
-- 과녁 상자 두 개 위(긴 축 ±12.5, 옆 ±5) → 긴 축에 수직으로 멀어지게 36 + 22.
-- 생선 몸(20 × 6)에서 6 안 → 몸에서 멀어지게 18 + 12. 그 밖 nil.
function Logic.fishKnockback(axis: "X" | "Z", rel: Rel): Knock?
	local along, across = axisParts(axis, rel)
	local targetHalfAlong = Layout.PITCH / 2 + Layout.CRATE_SIZE / 2 -- 12.5
	local targetHalfAcross = Layout.CRATE_SIZE / 2 -- 5
	if math.abs(along) <= targetHalfAlong and math.abs(across) <= targetHalfAcross then
		local dx, dz = toWorldDir(axis, 0, sign(across))
		return { dirX = dx, dirZ = dz, horizontal = Logic.SLAM_HORIZONTAL, up = Logic.SLAM_UP }
	end
	local dAlong = math.max(math.abs(along) - Logic.FISH_LENGTH / 2, 0)
	local dAcross = math.max(math.abs(across) - Logic.FISH_WIDTH / 2, 0)
	if dAlong * dAlong + dAcross * dAcross <= Logic.SPLASH_RADIUS * Logic.SPLASH_RADIUS then
		local dx, dz = toWorldDir(axis, sign(along) * dAlong, sign(across) * dAcross)
		return { dirX = dx, dirZ = dz, horizontal = Logic.SPLASH_HORIZONTAL, up = Logic.SPLASH_UP }
	end
	return nil
end

-- 팔딱: 누운 생선 몸(20 × 6 × 높이 5, 윗면 위 포함)에서 4 안 → 몸에서 멀어지게 16 + 16 (몸 위·안이면 옆으로).
function Logic.flopKnockback(axis: "X" | "Z", rel: Rel): Knock?
	local along, across = axisParts(axis, rel)
	local dAlong = math.max(math.abs(along) - Logic.FISH_LENGTH / 2, 0)
	local dAcross = math.max(math.abs(across) - Logic.FISH_WIDTH / 2, 0)
	local dY = math.max(rel.y - Logic.FISH_HEIGHT, -rel.y, 0)
	if dAlong * dAlong + dAcross * dAcross + dY * dY > Logic.FLOP_RADIUS * Logic.FLOP_RADIUS then
		return nil
	end
	local dx, dz
	if dAlong == 0 and dAcross == 0 then
		dx, dz = toWorldDir(axis, 0, sign(across))
	else
		dx, dz = toWorldDir(axis, sign(along) * dAlong, sign(across) * dAcross)
	end
	return { dirX = dx, dirZ = dz, horizontal = Logic.FLOP_HORIZONTAL, up = Logic.FLOP_UP }
end

return Logic
