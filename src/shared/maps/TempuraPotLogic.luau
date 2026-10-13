--!strict
-- "튀김 냄비 탈출"(tempura-pot, m5-05) 순수 로직 (Roblox API 없음, tests/map-tempura-pot.spec.luau).
--   Logic.oilHeight(t)                   t초(출발 기준)의 기름 높이 (origin 로컬 y)
--   Logic.isFried(footY, oilY)            발이 기름보다 낮으면 true
--   Logic.splashInterval(t)               튀는 기름 간격(초), 아직 없으면 nil
--   Logic.splashKnockback(dx, dz)          원 중심 → 레이서 (dx, dz)로 밀 속도 {x, y, z}, 반경 밖이면 nil
--   Logic.pickSplashTarget(cands, rng)     후보 중 무작위 하나 (없으면 nil)
--   Logic.gap(a, b)                        두 발판 윗면 사이 수평 틈 (겹치면 0)
--   Logic.wallClearance(raft)              발판 가장자리 → 냄비 안쪽 벽 수평 거리
--   Logic.area(raft)                       윗면 넓이
--   Logic.climbGraph() / Logic.pathFrom(raft) / Logic.startsReachingTop()  경로 확인
--   Logic.isOnRaft(raft, x, z)             (x, z)가 발판 윗면 위인지

local Layout = require(script.Parent.TempuraPotLayout)

type Raft = Layout.Raft

export type Velocity = { x: number, y: number, z: number }
export type Rng = { NextInteger: (self: any, min: number, max: number) -> number }

local Logic = {}

-- 기름 (스펙 "기름")
Logic.OIL_START_Y = 0
Logic.OIL_GRACE = 6 -- 이 초까지는 그대로
Logic.OIL_RISE_SPEED = 0.4 -- studs/s
Logic.OIL_MAX_Y = 22
Logic.CHECK_INTERVAL = 0.1 -- 서버 탈락 확인 간격

-- 튀는 기름 (스펙 "튀는 기름")
Logic.SPLASH_SCHEDULE = {
	{ from = 10, interval = 3 },
	{ from = 30, interval = 2 },
	{ from = 45, interval = 1.5 },
}
Logic.SPLASH_RADIUS = 5
Logic.SPLASH_WARN_TIME = 1.2
Logic.SPLASH_KNOCK_HORIZONTAL = 35
Logic.SPLASH_KNOCK_UP = 25
Logic.SPLASH_KNOCKDOWN_TIME = 1 -- 넘어짐
Logic.SPLASH_MOVE_EXEMPT = 1.5 -- MoveExempt.mark 초
Logic.SPLASH_HOLD = 0.15 -- LinearVelocity로 붙잡는 시간 (그 뒤는 포물선)
Logic.SPLASH_COOLDOWN = 0.5 -- 같은 사람 다시 맞는 최소 간격
Logic.SPLASH_HEIGHT_RANGE = 6 -- 발판 윗면 위 이 높이 안의 발만 맞아요 (점프로 넘기 어렵게 넉넉히)

-- 경로 (스펙 AC4)
Logic.CLIMB_MAX_RISE = 4.5
Logic.CLIMB_MAX_GAP = 5
Logic.SAME_TIER_MAX_GAP = 6

function Logic.oilHeight(t: number): number
	local rising = math.max(0, t - Logic.OIL_GRACE)
	return math.min(Logic.OIL_START_Y + rising * Logic.OIL_RISE_SPEED, Logic.OIL_MAX_Y)
end

function Logic.isFried(footY: number, oilY: number): boolean
	return footY < oilY
end

function Logic.splashInterval(t: number): number?
	local result: number? = nil
	for _, row in Logic.SPLASH_SCHEDULE do
		if t >= row.from then
			result = row.interval
		end
	end
	return result
end

-- 원 중심에서 레이서까지 (dx, dz). 반경 안이면 바깥으로 수평 35 + 위 25. 중심과 거의 같으면 +X로 밀어요.
function Logic.splashKnockback(dx: number, dz: number): Velocity?
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > Logic.SPLASH_RADIUS then
		return nil
	end
	local ux, uz = 1, 0
	if dist > 1e-3 then
		ux, uz = dx / dist, dz / dist
	end
	return {
		x = ux * Logic.SPLASH_KNOCK_HORIZONTAL,
		y = Logic.SPLASH_KNOCK_UP,
		z = uz * Logic.SPLASH_KNOCK_HORIZONTAL,
	}
end

function Logic.pickSplashTarget<T>(candidates: { T }, rng: Rng): T?
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

---------------------------------------------------------------- 기하

type Point = { x: number, z: number }

-- Rect 발판의 네 꼭짓점 (yaw 규칙: 로컬 X → (cos, -sin), 로컬 Z → (sin, cos))
local function corners(raft: Raft): { Point }
	local rad = math.rad(raft.yaw)
	local c, s = math.cos(rad), math.sin(rad)
	local hx, hz = raft.length / 2, raft.width / 2
	local list: { Point } = {}
	for _, sign in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
		local lx, lz = sign[1] * hx, sign[2] * hz
		table.insert(list, { x = raft.x + lx * c + lz * s, z = raft.z - lx * s + lz * c })
	end
	return list
end
Logic.corners = corners

-- 월드 (x, z)를 Rect 발판 로컬 (lx, lz)로
local function toLocal(raft: Raft, x: number, z: number): (number, number)
	local rad = math.rad(raft.yaw)
	local c, s = math.cos(rad), math.sin(rad)
	local dx, dz = x - raft.x, z - raft.z
	return dx * c - dz * s, dx * s + dz * c
end

-- 점 → 발판 윗면(2D) 거리. 안에 있으면 0.
local function pointDistance(raft: Raft, x: number, z: number): number
	if raft.shape == "Disc" then
		local dx, dz = x - raft.x, z - raft.z
		return math.max(0, math.sqrt(dx * dx + dz * dz) - raft.radius)
	end
	local lx, lz = toLocal(raft, x, z)
	local ox = math.max(0, math.abs(lx) - raft.length / 2)
	local oz = math.max(0, math.abs(lz) - raft.width / 2)
	return math.sqrt(ox * ox + oz * oz)
end
Logic.pointDistance = pointDistance

function Logic.isOnRaft(raft: Raft, x: number, z: number): boolean
	return pointDistance(raft, x, z) <= 0
end

local function segmentPointDistance(a: Point, b: Point, p: Point): number
	local abx, abz = b.x - a.x, b.z - a.z
	local len2 = abx * abx + abz * abz
	local u = if len2 > 0 then math.clamp(((p.x - a.x) * abx + (p.z - a.z) * abz) / len2, 0, 1) else 0
	local qx, qz = a.x + abx * u - p.x, a.z + abz * u - p.z
	return math.sqrt(qx * qx + qz * qz)
end

local function segmentsCross(a: Point, b: Point, c: Point, d: Point): boolean
	local function cross(o: Point, p: Point, q: Point): number
		return (p.x - o.x) * (q.z - o.z) - (p.z - o.z) * (q.x - o.x)
	end
	local d1, d2 = cross(c, d, a), cross(c, d, b)
	local d3, d4 = cross(a, b, c), cross(a, b, d)
	return ((d1 > 0) ~= (d2 > 0)) and ((d3 > 0) ~= (d4 > 0))
end

-- 두 발판(위에서 본 모양) 사이 가장 가까운 틈. 겹치면 0.
function Logic.gap(a: Raft, b: Raft): number
	if a.shape == "Disc" and b.shape == "Disc" then
		local dx, dz = a.x - b.x, a.z - b.z
		return math.max(0, math.sqrt(dx * dx + dz * dz) - a.radius - b.radius)
	end
	if a.shape == "Disc" then
		return math.max(0, pointDistance(b, a.x, a.z) - a.radius)
	end
	if b.shape == "Disc" then
		return math.max(0, pointDistance(a, b.x, b.z) - b.radius)
	end
	-- 직사각형끼리: 한쪽 꼭짓점이 다른 쪽 안이거나 변이 교차하면 0, 아니면 꼭짓점-변 거리 최소
	local ca, cb = corners(a), corners(b)
	for _, p in ca do
		if pointDistance(b, p.x, p.z) <= 0 then
			return 0
		end
	end
	for _, p in cb do
		if pointDistance(a, p.x, p.z) <= 0 then
			return 0
		end
	end
	local best = math.huge
	for i = 1, 4 do
		local a1, a2 = ca[i], ca[i % 4 + 1]
		for j = 1, 4 do
			local b1, b2 = cb[j], cb[j % 4 + 1]
			if segmentsCross(a1, a2, b1, b2) then
				return 0
			end
			best = math.min(best, segmentPointDistance(a1, a2, b1), segmentPointDistance(b1, b2, a1))
		end
	end
	return best
end

-- 냄비 중심에서 가장 먼 윗면 점까지 거리
local function farthestFromPot(raft: Raft): number
	local cx, cz = Layout.POT_CENTER_X, Layout.POT_CENTER_Z
	if raft.shape == "Disc" then
		local dx, dz = raft.x - cx, raft.z - cz
		return math.sqrt(dx * dx + dz * dz) + raft.radius
	end
	local best = 0
	for _, p in corners(raft) do
		local dx, dz = p.x - cx, p.z - cz
		best = math.max(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

function Logic.wallClearance(raft: Raft): number
	return Layout.POT_INNER_RADIUS - farthestFromPot(raft)
end

function Logic.area(raft: Raft): number
	if raft.shape == "Disc" then
		return math.pi * raft.radius * raft.radius
	end
	return raft.length * raft.width
end

---------------------------------------------------------------- 경로 (AC4)

-- 이어짐 (스펙 AC4 "수직 ≤ 4.5 이고 수평 틈 ≤ 5"): 같은 높이(옆 발판으로 건너기)이거나 CLIMB_MAX_RISE 이하로
-- 올라가고, 수평 틈이 CLIMB_MAX_GAP 이하. 내려가는 쪽은 간선이 아니에요 (경로는 위로만 쌓여요).
function Logic.canClimb(from: Raft, to: Raft): boolean
	local rise = to.topY - from.topY
	return rise >= 0 and rise <= Logic.CLIMB_MAX_RISE and Logic.gap(from, to) <= Logic.CLIMB_MAX_GAP
end

-- 바구니 + 발판 전부, 위로 이어지는 간선
function Logic.climbGraph(): ({ Raft }, { [Raft]: { Raft } })
	local nodes = { Layout.basket() }
	for _, raft in Layout.rafts() do
		table.insert(nodes, raft)
	end
	local edges: { [Raft]: { Raft } } = {}
	for _, a in nodes do
		edges[a] = {}
		for _, b in nodes do
			if a ~= b and Logic.canClimb(a, b) then
				table.insert(edges[a], b)
			end
		end
	end
	return nodes, edges
end

-- raft에서 꼭대기(가장 높은 층)까지 위로만 가는 경로 (BFS). 없으면 nil.
function Logic.pathFrom(start: Raft): { Raft }?
	local _, edges = Logic.climbGraph()
	local topY = Layout.TIER_TOPS[#Layout.TIER_TOPS]
	-- climbGraph가 새 표를 만들어서 key로 시작점을 다시 찾아요
	local startNode: Raft? = nil
	for node in edges do
		if node.key == start.key then
			startNode = node
		end
	end
	if startNode == nil then
		return nil
	end
	local cameFrom: { [Raft]: Raft | boolean } = { [startNode] = true }
	local queue = { startNode }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		if current.topY >= topY then
			local path = { current }
			local previous = cameFrom[current]
			while type(previous) == "table" do
				table.insert(path, 1, previous)
				previous = cameFrom[previous]
			end
			return path
		end
		for _, nextRaft in edges[current] do
			if cameFrom[nextRaft] == nil then
				cameFrom[nextRaft] = current
				table.insert(queue, nextRaft)
			end
		end
	end
	return nil
end

-- 바구니에서 바로 올라탈 수 있고 꼭대기까지 이어지는 첫 층 발판들 (서로 다른 시작 발판 수 = 갈래 수)
function Logic.startsReachingTop(): { Raft }
	local basket = Layout.basket()
	local list: { Raft } = {}
	for _, raft in Layout.rafts() do
		if raft.tier == 1 and Logic.canClimb(basket, raft) and Logic.pathFrom(raft) ~= nil then
			table.insert(list, raft)
		end
	end
	return list
end

-- 같은 층 발판들이 틈 SAME_TIER_MAX_GAP 이하로 모두 이어지는지
function Logic.tierConnected(tier: number): boolean
	local members: { Raft } = {}
	for _, raft in Layout.rafts() do
		if raft.tier == tier then
			table.insert(members, raft)
		end
	end
	if #members <= 1 then
		return true
	end
	local seen = { [members[1]] = true }
	local queue = { members[1] }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, other in members do
			if not seen[other] and Logic.gap(current, other) <= Logic.SAME_TIER_MAX_GAP then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return #queue == #members
end

return Logic
