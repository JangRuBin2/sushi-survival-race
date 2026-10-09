--!strict
-- "와르르 나무 블록"(giant-jenga, m5-16)의 동적 로직 — 보드 상태, 블록 제거 일정·고르기·적용, 국소 기울기 계산.
-- 치수(격자, 보호 칸, 이웃)는 GiantJengaLayout. Roblox API를 쓰지 않아요 (tests/map-giant-jenga.spec.luau).
--
--   Logic.newBoard()                              레벨 25개(전부 LEVEL_MAX)
--   Logic.removalWave(elapsed)                     경과 시간의 제거 간격·개수 (표는 스펙 참고), 없으면 nil
--   Logic.removalTimes(duration)                   제거가 일어나는 시각 목록 (FIRST_REMOVAL_AT부터)
--   Logic.pickColumns(board, previousKeys, count, rng)  이번에 뽑을 칸들 (바깥·레벨 > 0만, 가중 랜덤)
--   Logic.applyRemoval(board, columns)             고른 칸의 레벨을 1씩 줄여요 (보호 칸은 그대로)
--   Logic.tiltFor(board, i, j)                     그 칸의 기울기 (이웃과의 "가라앉은 정도" 차이, 보호 칸은 항상 nil)
--   Logic.heightOf(board, i, j)                    그 칸 윗면의 로컬 y (레벨 3/2/1/0 → 0/-4/-8/-12)
-- rng는 NextInteger(min, max)·NextNumber()만 써요 (Random과 테스트용 가짜 rng 모두).

local Layout = require(script.Parent.GiantJengaLayout)

local GiantJengaLogic = {}

export type Board = { levels: { [string]: number } }
export type Wave = { interval: number, count: number }
export type TiltParams = {
	angle: number, -- 라디안 (0 ~ MAX_TILT_DEG)
	axisX: number, -- 회전축 (수평, 단위)
	axisZ: number,
	downX: number, -- 낮은 쪽 방향 (수평, 단위)
	downZ: number,
	strength: number, -- 0~1 (각도 / 최대 각도)
}
type Rng = { NextInteger: (self: any, min: number, max: number) -> number }

-- 제거 일정
GiantJengaLogic.FIRST_REMOVAL_AT = 6 -- 출발 여유 (초)
GiantJengaLogic.CREAK_TIME = 0.8 -- 뽑히는 경고(그 기둥만 흔들림)
GiantJengaLogic.VANISH_SHAKE_TIME = 0.5 -- 레벨 0이 되기 전 추가 흔들림
GiantJengaLogic.SINK_TIME = 0.3 -- 윗면이 가라앉는 데 걸리는 시간 (부드럽게)

-- 기울기 밀기 (연속 밀기라 MoveExempt 없음 — ChefBoardLogic.TILT_PUSH_* 와 같은 값)
GiantJengaLogic.TILT_PUSH_SPEED = 6
GiantJengaLogic.TILT_PUSH_ACCEL = 18

-- 기울기 각도
GiantJengaLogic.DEG_PER_UNIT = 6 -- "가라앉은 정도" 차이 1단위당 기우는 각도
GiantJengaLogic.MAX_TILT_DEG = 18

function GiantJengaLogic.newBoard(): Board
	local levels: { [string]: number } = {}
	for _, column in Layout.columns() do
		levels[column.key] = Layout.LEVEL_MAX
	end
	return { levels = levels }
end

-- 경과 시간 elapsed의 제거 간격·한 번에 뽑는 개수. 아직 시작 전이면 nil.
function GiantJengaLogic.removalWave(elapsed: number): Wave?
	if elapsed < 6 then
		return nil
	elseif elapsed < 18 then
		return { interval = 5.0, count = 1 }
	elseif elapsed < 34 then
		return { interval = 3.5, count = 1 }
	elseif elapsed < 48 then
		return { interval = 2.5, count = 2 }
	end
	return { interval = 1.5, count = 2 }
end

-- 제거가 일어나는 시각들 (duration 전까지). 다음 시각 = 이번 시각 + 이번 시각의 간격.
function GiantJengaLogic.removalTimes(duration: number): { number }
	local list = {}
	local t = GiantJengaLogic.FIRST_REMOVAL_AT
	while t < duration do
		table.insert(list, t)
		local wave = GiantJengaLogic.removalWave(t)
		if wave == nil then
			break
		end
		t += wave.interval
	end
	return list
end

-- 아직 뽑을 블록이 남은(레벨 > 0) 바깥(보호 아닌) 칸 중 남은 레벨이 많은 칸을 우선(가중 랜덤) 고르되,
-- 대안이 있으면 previousKeys는 피해요. 최대 count개, 중복 없이. 후보가 모자라면 있는 만큼만 돌려줘요.
function GiantJengaLogic.pickColumns(
	board: Board,
	previousKeys: { string }?,
	count: number,
	rng: Rng
): { Layout.Column }
	local previous: { [string]: boolean } = {}
	if previousKeys then
		for _, k in previousKeys do
			previous[k] = true
		end
	end

	local pool: { Layout.Column } = {}
	for _, column in Layout.columns() do
		if not Layout.isProtected(column.i, column.j) then
			local level = board.levels[column.key] or 0
			if level > 0 then
				table.insert(pool, column)
			end
		end
	end

	local candidates: { Layout.Column } = {}
	for _, column in pool do
		if not previous[column.key] then
			table.insert(candidates, column)
		end
	end
	if #candidates == 0 then
		candidates = pool -- 대안이 없으면 어쩔 수 없이 previousKeys도 다시 고려해요
	end

	local picked: { Layout.Column } = {}
	for _ = 1, count do
		if #candidates == 0 then
			break
		end
		local total = 0
		local weights: { number } = {}
		for _, column in candidates do
			local w = board.levels[column.key] or 0
			table.insert(weights, w)
			total += w
		end
		local chosenIndex = #candidates
		if total > 0 then
			local roll = rng:NextInteger(1, total)
			for index, w in weights do
				roll -= w
				if roll <= 0 then
					chosenIndex = index
					break
				end
			end
		end
		table.insert(picked, candidates[chosenIndex])
		table.remove(candidates, chosenIndex)
	end
	return picked
end

-- 고른 칸의 레벨을 1씩 줄여요 (0 밑으로는 안 내려가요). 보호 칸에 적용을 시도하면 바뀌지 않아요(방어적 동작).
function GiantJengaLogic.applyRemoval(board: Board, columns: { Layout.Column })
	for _, column in columns do
		if not Layout.isProtected(column.i, column.j) then
			local level = board.levels[column.key] or 0
			board.levels[column.key] = math.max(level - 1, 0)
		end
	end
end

-- 레벨 3/2/1/0 → 윗면(또는 완전히 뚫렸을 때 "있었을 자리")의 로컬 y
function GiantJengaLogic.heightOf(board: Board, i: number, j: number): number
	local level = board.levels[Layout.key(i, j)]
	if level == nil then
		level = Layout.LEVEL_MAX
	end
	return -(Layout.LEVEL_MAX - level) * Layout.LEVEL_DROP
end

-- 뚫린(레벨 0) 이웃은 레벨만으로 계산한 것보다 더 "가라앉은" 것으로 쳐요 (그래야 레벨 2 이웃보다 더 크게 기울어요).
local function sunkOf(level: number): number
	if level <= 0 then
		return Layout.LEVEL_MAX + 1
	end
	return Layout.LEVEL_MAX - level
end

-- (i, j)의 기울기: 존재하는 이웃마다 "가라앉은 정도" 차이를 그 방향 벡터로 더해서, 합이 가리키는 쪽이 낮은 쪽.
-- 평평하거나(합이 0) 보호 칸이거나 그 칸 자체가 이미 뚫렸으면 nil.
function GiantJengaLogic.tiltFor(board: Board, i: number, j: number): TiltParams?
	if Layout.isProtected(i, j) then
		return nil
	end
	local selfLevel = board.levels[Layout.key(i, j)]
	if selfLevel == nil or selfLevel <= 0 then
		return nil
	end
	local selfSunk = sunkOf(selfLevel)
	local dx, dz = 0, 0
	for _, neighbor in Layout.neighborsOf(i, j) do
		local neighborLevel = board.levels[Layout.key(neighbor.i, neighbor.j)] or Layout.LEVEL_MAX
		local diff = sunkOf(neighborLevel) - selfSunk
		dx += diff * (neighbor.i - i)
		dz += diff * (neighbor.j - j)
	end
	local magnitude = math.sqrt(dx * dx + dz * dz)
	if magnitude < 1e-6 then
		return nil
	end
	local downX, downZ = dx / magnitude, dz / magnitude
	local angleDeg = math.min(magnitude * GiantJengaLogic.DEG_PER_UNIT, GiantJengaLogic.MAX_TILT_DEG)
	return {
		angle = math.rad(angleDeg),
		-- 위(Y) × 낮은 쪽 = (downZ, 0, -downX): 이 축으로 angle만큼 돌리면 낮은 쪽 가장자리가 내려가요.
		axisX = downZ,
		axisZ = -downX,
		downX = downX,
		downZ = downZ,
		strength = angleDeg / GiantJengaLogic.MAX_TILT_DEG,
	}
end

return GiantJengaLogic
