--!strict
-- "연회상 쟁반 쓸기"(banquet-sweep, m6-07) 순수 계산. Roblox API 없음.
--   schedule(rng)             판마다 벽 일정 (시각 순)
--   wallPos(sweep, t)         벽 위치(진행 축 좌표) 또는 nil
--   active(schedule, t)       지금 움직이는 벽들 { index, sweep, pos }
--   warnings(schedule, t)     변마다 곧 올 벽 { [Side]: Sweep }
--   wallHit(sweep, pos, along, perp, foot)
--   laneOf(c) / isGap(sweep, lane) / boardHalf(t) / edgeState(t) / fallLine()

local Layout = require(script.Parent.BanquetSweepLayout)

local Logic = {}

Logic.TIME_LIMIT = Layout.TIME_LIMIT
Logic.SUDDEN_DEATH_AT = Layout.SUDDEN_DEATH_AT

export type Axis = "X" | "Z"
export type Kind = "Low" | "High"
export type Side = "XNeg" | "XPos" | "ZNeg" | "ZPos"
export type TileState = "Solid" | "Warn" | "Open"
export type Sweep = { at: number, axis: Axis, dir: number, kind: Kind, gaps: { number } }
export type Active = { index: number, sweep: Sweep, pos: number }
export type Rng = {
	NextNumber: (self: any, lo: number, hi: number) -> number,
	NextInteger: (self: any, lo: number, hi: number) -> number,
}

function Logic.fallLine(): number
	return Layout.FLOOR_Y - Layout.FALL_MARGIN
end

function Logic.boardHalf(t: number): number
	return if t >= Layout.COLLAPSE_AT then Layout.INNER_HALF else Layout.HALF
end

-- 바깥 한 줄 타일 상태
function Logic.edgeState(t: number): TileState
	if t >= Layout.COLLAPSE_AT then
		return "Open"
	elseif t >= Layout.COLLAPSE_AT - Layout.COLLAPSE_WARN then
		return "Warn"
	end
	return "Solid"
end

-- 좌표 → 칸(1..8), 상 밖이면 nil
function Logic.laneOf(c: number): number?
	if c < -Layout.HALF or c > Layout.HALF then
		return nil
	end
	return math.clamp(math.floor((c + Layout.HALF) / Layout.TILE) + 1, 1, Layout.LANES)
end

-- 바깥 타일인가 (i, j = 1..8)
function Logic.isOuterTile(i: number, j: number): boolean
	return i == 1 or j == 1 or i == Layout.LANES or j == Layout.LANES
end

function Logic.isGap(sweep: Sweep, lane: number): boolean
	return sweep.kind == "High" and table.find(sweep.gaps, lane) ~= nil
end

function Logic.duration(kind: Kind): number
	return 2 * Layout.WALL_START / Layout.KINDS[kind].speed
end

Logic.MAX_DURATION = math.max(Logic.duration("Low"), Logic.duration("High"))

function Logic.wallPos(sweep: Sweep, t: number): number?
	local dt = t - sweep.at
	if dt < 0 or dt >= Logic.duration(sweep.kind) then
		return nil
	end
	return sweep.dir * (-Layout.WALL_START + Layout.KINDS[sweep.kind].speed * dt)
end

function Logic.sideOf(sweep: Sweep): Side
	if sweep.axis == "X" then
		return if sweep.dir > 0 then "XNeg" else "XPos"
	end
	return if sweep.dir > 0 then "ZNeg" else "ZPos"
end

local function phaseAt(t: number)
	local phase = Layout.PHASES[1]
	for _, p in Layout.PHASES do
		if t >= p.from then
			phase = p
		end
	end
	return phase
end

-- 빈 칸: 2개면 앞쪽(2..4)·뒤쪽(5..7)에서 하나씩 — 어느 칸에서든 가장 가까운 빈 칸이 3칸 안.
-- 1개(서든데스)면 3..6. 바깥 칸(1·8)은 무너지니 빈 칸으로 안 써요.
local function pickGaps(rng: Rng, count: number): { number }
	if count >= 2 then
		return { rng:NextInteger(2, 4), rng:NextInteger(5, 7) }
	end
	return { rng:NextInteger(3, 6) }
end

local function makeSweep(rng: Rng, at: number, axis: Axis, kind: Kind, gapCount: number): Sweep
	local dir = if rng:NextInteger(0, 1) == 0 then 1 else -1
	return {
		at = at,
		axis = axis,
		dir = dir,
		kind = kind,
		gaps = if kind == "High" then pickGaps(rng, gapCount) else {},
	}
end

-- 판마다 벽 일정. 한 번에 두 장이면 서로 수직(X 하나 · Z 하나), 한 장은 낮은 벽·한 장은 확률.
function Logic.schedule(rng: Rng): { Sweep }
	local list: { Sweep } = {}
	local t = Layout.FIRST_AT
	while t <= Layout.LAST_AT do
		local phase = phaseAt(t)
		local firstAxis: Axis = if rng:NextInteger(0, 1) == 0 then "X" else "Z"
		local firstKind: Kind = if rng:NextNumber(0, 1) < phase.highChance then "High" else "Low"
		table.insert(list, makeSweep(rng, t, firstAxis, firstKind, phase.gaps))
		if phase.walls >= 2 then
			local secondAxis: Axis = if firstAxis == "X" then "Z" else "X"
			local secondKind: Kind = if firstKind == "High" then "Low" else "High"
			table.insert(list, makeSweep(rng, t, secondAxis, secondKind, phase.gaps))
		end
		t += phase.interval
	end
	return list
end

function Logic.active(schedule: { Sweep }, t: number): { Active }
	local list: { Active } = {}
	for i, sweep in schedule do
		if sweep.at > t then
			break
		end
		local pos = Logic.wallPos(sweep, t)
		if pos then
			table.insert(list, { index = i, sweep = sweep, pos = pos })
		end
	end
	return list
end

-- 풀 자리: 일정 번호 순서대로 돌려 써요. 동시에 쓰는 자리가 POOL을 넘지 않는 건 테스트가 확인.
function Logic.slotOf(index: number): number
	return (index - 1) % Layout.POOL + 1
end

function Logic.warnings(schedule: { Sweep }, t: number): { [Side]: Sweep }
	local map: { [Side]: Sweep } = {}
	for _, sweep in schedule do
		if t >= sweep.at - Layout.WARN and t < sweep.at then
			map[Logic.sideOf(sweep)] = sweep
		end
	end
	return map
end

-- along = 벽 진행 축 좌표, perp = 수직 축 좌표, foot = 발 높이(바닥 기준)
function Logic.wallHit(sweep: Sweep, pos: number, along: number, perp: number, foot: number): boolean
	local kind = Layout.KINDS[sweep.kind]
	if math.abs(along - pos) > Layout.WALL_THICKNESS / 2 + kind.hitPad then
		return false
	end
	if foot >= kind.height then
		return false
	end
	local lane = Logic.laneOf(perp)
	if lane and Logic.isGap(sweep, lane) then
		-- 빈 칸 가운데 쪽(양옆 1.5 안쪽)만 안전 — 벽 끝에 걸치면 닿아요
		return math.abs(perp - Layout.laneCenter(lane)) > Layout.TILE / 2 - 1.5
	end
	return true
end

return Logic
