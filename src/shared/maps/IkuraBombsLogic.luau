--!strict
-- "연어알 폭탄 접시"(m5-04) 순수 로직: 칸 찾기, 폭탄 시간표, 노릴 곳 고르기, 넉백, 금 가기, 정해진 낙하,
-- 연장전 고리 붕괴 일정. Roblox API를 쓰지 않아서 lune에서 그대로 불러요. 좌표는 전부 origin 기준 로컬 (x, z).
--   Logic.tileAt(x, z) -> number?                       그 점이 놓인 칸 id (반지름 24 밖은 nil)
--   Logic.bombWave(elapsed, overtimeAt?) -> Wave?        표대로 (interval, count, warn, radius). 3초 전은 nil
--   Logic.pickTargets(rng, racers, aliveIds, count) -> { Point }
--   Logic.knockback(dx, dz, radius, awayX?, awayZ?) -> Velocity?   (dx, dz) = 레이서 − 폭발 중심
--   Logic.inBlast(dx, dy, dz, radius) -> boolean
--   Logic.crack(ring, cracks) -> (cracks, drop)
--   Logic.scheduleMarks(untilTime) -> { number }         정해진 낙하를 확인할 시각 (40+6k, 60+6k)
--   Logic.scheduledDrops(elapsed, alive, rng?) -> { number }   그 시각에 떨어뜨릴 칸 id
--   Logic.overtimeRings(collapseDuration, warnTime) -> { RingStep }

local Layout = require(script.Parent.IkuraBombsLayout)

local Logic = {}

export type Wave = { interval: number, count: number, warn: number, radius: number }
export type Point = { x: number, z: number }
export type Velocity = { x: number, y: number, z: number }
export type AliveTile = { id: number, ring: number, cracks: number }
export type RingStep = { ring: number, warnAt: number, dropAt: number }

Logic.START_GRACE = 3 -- 출발 여유 (폭탄 없음)
Logic.RACER_CHANCE = 0.6 -- 폭탄이 레이서를 노릴 확률
Logic.RACER_JITTER = 3 -- 레이서 위치에서 이만큼 안쪽 무작위
Logic.MIN_SPACING = 6 -- 같은 묶음 폭탄 중심 간격
Logic.PICK_RETRIES = 5 -- 간격이 안 맞으면 다시 뽑는 횟수
Logic.EDGE_MARGIN = 0.5 -- 노리는 점이 칸 경계에서 떨어지는 거리
Logic.KNOCK_OUT = 50 -- 수평 넉백 (중심)
Logic.KNOCK_FALLOFF = 0.4 -- 가장자리에서 1 − 0.4 = 60%
Logic.KNOCK_UP = 30
Logic.BLAST_HEIGHT = 6 -- 높이 차 이하만 맞아요
Logic.CRACKS_TO_DROP = 2
Logic.OUTER_DROP_START = 40 -- 바깥 고리 정해진 낙하 시작
Logic.MIDDLE_DROP_START = 60 -- 가운데 고리 정해진 낙하 시작
Logic.DROP_STEP = 6
Logic.OUTER_KEEP = 3 -- 바깥 고리는 이만큼 남으면 정해진 낙하 멈춤
Logic.MIDDLE_KEEP = 2

-- 그 점이 놓인 칸 id. 반지름 < 8 원판, < 16 가운데 고리, ≤ 24 바깥 고리, 그 밖은 nil.
function Logic.tileAt(x: number, z: number): number?
	local r = math.sqrt(x * x + z * z)
	if r > Layout.RADIUS then
		return nil
	end
	if r < Layout.ringOuter(0) then
		return 0
	end
	local ring = if r < Layout.ringOuter(1) then 1 else 2
	local deg = math.deg(math.atan2(-z, x)) % 360
	local index = math.floor(deg / Layout.tileArc(ring)) % Layout.RING_TILES[ring]
	return Layout.tileId(ring, index)
end

-- 출발 기준 elapsed → 폭탄 간격·개수·경고·반경. overtimeAt이 있고 지났으면 연장전 값.
function Logic.bombWave(elapsed: number, overtimeAt: number?): Wave?
	if overtimeAt ~= nil and elapsed >= overtimeAt then
		return { interval = 1.0, count = 3, warn = 1.2, radius = 9 }
	end
	if elapsed < Logic.START_GRACE then
		return nil
	end
	if elapsed < 30 then
		return { interval = 2.5, count = 1, warn = 1.5, radius = 7 }
	end
	if elapsed < 60 then
		return { interval = 2.0, count = 2, warn = 1.5, radius = 7 }
	end
	return { interval = 1.5, count = 2, warn = 1.2, radius = 9 }
end

-- 각도 차 (−180, 180]
local function angleDelta(a: number, b: number): number
	local d = (a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

-- 칸 안(경계에서 EDGE_MARGIN 안쪽)으로 점을 옮긴 결과
local function clampToTile(tile: Layout.TileDef, x: number, z: number): Point
	local r = math.sqrt(x * x + z * z)
	if tile.ring == 0 then
		local maxR = Layout.ringOuter(0) - Logic.EDGE_MARGIN
		if r <= maxR then
			return { x = x, z = z }
		end
		return { x = x / r * maxR, z = z / r * maxR }
	end
	local rIn = Layout.ringInner(tile.ring) + Logic.EDGE_MARGIN
	local rOut = Layout.ringOuter(tile.ring) - Logic.EDGE_MARGIN
	local cr = math.clamp(r, rIn, rOut)
	local deg = if r > 1e-9 then math.deg(math.atan2(-z, x)) else (tile.fromDeg + tile.toDeg) / 2
	local mid = (tile.fromDeg + tile.toDeg) / 2
	local halfArc = (tile.toDeg - tile.fromDeg) / 2 - math.deg(Logic.EDGE_MARGIN / cr)
	local d = math.clamp(angleDelta(deg, mid), -halfArc, halfArc)
	local px, pz = Layout.polar(cr, mid + d)
	return { x = px, z = pz }
end

-- 남은 칸 위로 옮겨요. 이미 남은 칸 위면 그대로, 아니면 가장 가까운 남은 칸 안쪽 점.
function Logic.clampToAlive(x: number, z: number, aliveIds: { number }): Point
	local here = Logic.tileAt(x, z)
	if here ~= nil and table.find(aliveIds, here) then
		local tile = Layout.tile(here) :: Layout.TileDef
		return clampToTile(tile, x, z)
	end
	local best: Point = { x = x, z = z }
	local bestDist = math.huge
	for _, id in aliveIds do
		local tile = Layout.tile(id)
		if tile then
			local p = clampToTile(tile, x, z)
			local d = (p.x - x) ^ 2 + (p.z - z) ^ 2
			if d < bestDist then
				best, bestDist = p, d
			end
		end
	end
	return best
end

-- 칸 위 무작위 점 (면적에 비례하게 반지름은 sqrt 분포)
local function randomPointOnTile(rng: Random, tile: Layout.TileDef): Point
	local m = Logic.EDGE_MARGIN
	if tile.ring == 0 then
		local r = (Layout.ringOuter(0) - m) * math.sqrt(rng:NextNumber())
		local px, pz = Layout.polar(r, rng:NextNumber() * 360)
		return { x = px, z = pz }
	end
	local rIn = Layout.ringInner(tile.ring) + m
	local rOut = Layout.ringOuter(tile.ring) - m
	local r = math.sqrt(rIn * rIn + (rOut * rOut - rIn * rIn) * rng:NextNumber())
	local px, pz = Layout.polar(r, tile.fromDeg + (tile.toDeg - tile.fromDeg) * rng:NextNumber())
	return clampToTile(tile, px, pz)
end

local function drawOne(rng: Random, racers: { Point }, aliveIds: { number }): Point
	if #racers > 0 and rng:NextNumber() < Logic.RACER_CHANCE then
		local racer = racers[rng:NextInteger(1, #racers)]
		local r = Logic.RACER_JITTER * rng:NextNumber()
		local a = rng:NextNumber() * 2 * math.pi
		return Logic.clampToAlive(racer.x + r * math.cos(a), racer.z + r * math.sin(a), aliveIds)
	end
	local tile = Layout.tile(aliveIds[rng:NextInteger(1, #aliveIds)]) :: Layout.TileDef
	return randomPointOnTile(rng, tile)
end

-- 폭탄 count개의 중심. 60% 레이서 한 명(무작위) + 0~3 studs, 40% 남은 칸 위 무작위 점. 모두 남은 칸 위.
-- 같은 묶음끼리 MIN_SPACING 이상 떨어지게 최대 PICK_RETRIES번 다시 뽑고(이미 노린 레이서는 빼고), 그래도 안 되면
-- 마지막 것을 써요.
-- aliveIds가 비면 빈 목록.
function Logic.pickTargets(rng: Random, racers: { Point }, aliveIds: { number }, count: number): { Point }
	local out: { Point } = {}
	if #aliveIds == 0 then
		return out
	end
	local function tooClose(point: Point, reach: number): boolean
		for _, other in out do
			if (other.x - point.x) ^ 2 + (other.z - point.z) ^ 2 < reach * reach then
				return true
			end
		end
		return false
	end
	for _ = 1, count do
		local point = drawOne(rng, racers, aliveIds)
		if tooClose(point, Logic.MIN_SPACING) then
			-- 다시 뽑을 때는 이미 이 묶음이 노린 레이서(그 근처에 폭탄이 있음)는 빼요 — 레이서가 한 명이면
			-- 무작위 칸 점으로 다시 뽑게 돼서 같은 사람 위에 폭탄이 겹치지 않아요.
			local others: { Point } = {}
			for _, racer in racers do
				if not tooClose(racer, Logic.MIN_SPACING + Logic.RACER_JITTER) then
					table.insert(others, racer)
				end
			end
			for _ = 1, Logic.PICK_RETRIES do
				point = drawOne(rng, others, aliveIds)
				if not tooClose(point, Logic.MIN_SPACING) then
					break
				end
			end
		end
		table.insert(out, point)
	end
	return out
end

function Logic.inBlast(dx: number, dy: number, dz: number, radius: number): boolean
	return dx * dx + dz * dz <= radius * radius and math.abs(dy) <= Logic.BLAST_HEIGHT
end

-- 넉백 속도. (dx, dz) = 레이서 − 폭발 중심(수평). 반경 밖이면 nil. 중심에 딱 붙어 방향이 없으면
-- (awayX, awayZ)(보통 접시 중심 반대쪽 = 레이서 위치) 방향, 그것도 0이면 +X.
function Logic.knockback(dx: number, dz: number, radius: number, awayX: number?, awayZ: number?): Velocity?
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > radius then
		return nil
	end
	local ux, uz
	if dist > 0.01 then
		ux, uz = dx / dist, dz / dist
	else
		local ax, az = awayX or 0, awayZ or 0
		local m = math.sqrt(ax * ax + az * az)
		if m > 0.01 then
			ux, uz = ax / m, az / m
		else
			ux, uz = 1, 0
		end
	end
	local speed = Logic.KNOCK_OUT * (1 - Logic.KNOCK_FALLOFF * math.min(dist / radius, 1))
	return { x = ux * speed, y = Logic.KNOCK_UP, z = uz * speed }
end

-- 금 가기. 원판(Ring 0)은 금이 가지 않아요. drop = 이번에 CRACKS_TO_DROP에 닿음.
function Logic.crack(ring: number, cracks: number): (number, boolean)
	if ring == 0 then
		return cracks, false
	end
	local next = cracks + 1
	return next, next >= Logic.CRACKS_TO_DROP
end

-- 정해진 낙하를 확인할 시각 목록 (untilTime 미만, 정렬). 바깥 40+6k, 가운데 60+6k (겹치는 시각은 한 번).
function Logic.scheduleMarks(untilTime: number): { number }
	local marks: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, first in { Logic.OUTER_DROP_START, Logic.MIDDLE_DROP_START } do
		local t = first
		while t < untilTime do
			if not seen[t] then
				seen[t] = true
				table.insert(marks, t)
			end
			t += Logic.DROP_STEP
		end
	end
	table.sort(marks)
	return marks
end

local function isMark(elapsed: number, first: number): boolean
	if elapsed < first - 1e-3 then
		return false
	end
	local k = (elapsed - first) / Logic.DROP_STEP
	return math.abs(k - math.floor(k + 0.5)) * Logic.DROP_STEP < 1e-3
end

-- 한 고리에서 떨어뜨릴 칸: 금이 가장 많이 간 칸들 중 무작위 (rng 없으면 id가 가장 작은 칸)
local function pickDrop(candidates: { AliveTile }, rng: Random?): number
	local maxCracks = -1
	local best: { number } = {}
	for _, tile in candidates do
		if tile.cracks > maxCracks then
			maxCracks, best = tile.cracks, { tile.id }
		elseif tile.cracks == maxCracks then
			table.insert(best, tile.id)
		end
	end
	table.sort(best)
	if rng and #best > 1 then
		return best[rng:NextInteger(1, #best)]
	end
	return best[1]
end

-- elapsed가 정해진 낙하 시각이면 떨어뜨릴 칸 id 목록. alive = 아직 서 있는(경고 중 아님) 칸들.
-- 바깥 고리는 OUTER_KEEP칸, 가운데 고리는 MIDDLE_KEEP칸 남으면 멈춰요. 원판은 정해진 낙하가 없어요.
function Logic.scheduledDrops(elapsed: number, alive: { AliveTile }, rng: Random?): { number }
	local drops: { number } = {}
	local rules = {
		{ ring = 2, first = Logic.OUTER_DROP_START, keep = Logic.OUTER_KEEP },
		{ ring = 1, first = Logic.MIDDLE_DROP_START, keep = Logic.MIDDLE_KEEP },
	}
	for _, rule in rules do
		if isMark(elapsed, rule.first) then
			local candidates: { AliveTile } = {}
			for _, tile in alive do
				if tile.ring == rule.ring then
					table.insert(candidates, tile)
				end
			end
			if #candidates > rule.keep then
				table.insert(drops, pickDrop(candidates, rng))
			end
		end
	end
	return drops
end

-- 연장전 고리 붕괴 일정 (연장전 시작 기준). ring 2 → 1 → 0, dropAt = warn + (D − warn)·k/2,
-- 마지막 dropAt == collapseDuration, warnAt = dropAt − warn.
function Logic.overtimeRings(collapseDuration: number, warnTime: number): { RingStep }
	local warn = math.min(warnTime, collapseDuration)
	local steps: { RingStep } = {}
	for k = 0, 2 do
		local dropAt = warn + (collapseDuration - warn) * k / 2
		table.insert(steps, { ring = 2 - k, warnAt = dropAt - warn, dropAt = dropAt })
	end
	return steps
end

return Logic
