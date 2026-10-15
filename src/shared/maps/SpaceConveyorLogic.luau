--!strict
-- "우주 회전초밥"(space-conveyor, m5-35) 순수 로직. Roblox API를 쓰지 않아서 lune에서 그대로 불러요.
-- 좌표는 전부 origin 기준 로컬 (x: 오른쪽 +, y: 위, z: 결승 쪽이 -). 치수는 SpaceConveyorLayout.
--   Logic.railPhase(t, offset) -> (state, push)          6초 주기 방향 전환 (Forward +9 / WarnBack 0 / Back −7 / WarnForward 0)
--   Logic.blinkOn(t, offset) -> boolean                  Warn 동안 0.1초 간격 깜빡임 (true = 다음 색)
--   Logic.floorAt(z) / fallLineAt(z) / progress(z)       구간 바닥, 낙하선(바닥 − 25), 진행도(−z)
--   Logic.inGravityZone(x, y, z) / lowGravityForce(mass, gravity, factor) / jumpHeight / airTime
--   Logic.edgeGap(a, b) / crossable(maxGap, maxRise, branch?)   C 소행성 그래프
--   Logic.meteorWave(t) / fieldMeteorWave(t) -> Wave?    운석 시간표 (레일 / E 들판)
--   Logic.railFrame(rail) / railLocal / railPoint / railAt / onRail / inHub
--   Logic.pickMeteorTargets(rng, racers, rails, rocks, count) -> { Target }
--   Logic.pickFieldTargets(rng, racers, rocks, count) -> { Target }
--   Logic.rockOffset(impactLateral, railWidth, rng) -> number?   바위 가운데의 옆 위치 (레일 폭 < 12면 nil)
--   Logic.fieldFreeWidth(rocks, z) / fieldMinFreeWidth(rocks)    E 들판 빈 폭
--   Logic.inImpact(horizontal, footAboveTop) / knockback(dx, dz, fallbackX, fallbackZ)
--   Logic.estimateClearTime()                            Layout 상수로 추정한 빠른 사람 기록 (초)

local Layout = require(script.Parent.SpaceConveyorLayout)

local Logic = {}

export type RailState = "Forward" | "WarnBack" | "Back" | "WarnForward"
export type Wave = { count: number, interval: number }
export type Pos = { x: number, y: number, z: number }
export type Rock = { x: number, z: number }
export type Target = { x: number, y: number, z: number, rail: number?, lateral: number, fromRacer: boolean }
export type Frame = {
	cx: number,
	cz: number,
	fx: number, -- 앞 방향 (수평 단위 벡터)
	fz: number,
	rx: number, -- 오른쪽 (수평 단위 벡터)
	rz: number,
	half: number, -- 수평 길이 / 2
	halfWidth: number,
}
export type Rng = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

-- ── 방향 전환 레일 ───────────────────────────────────────────────────────────
Logic.CYCLE = 6
Logic.FORWARD_END = 2.6
Logic.WARN_BACK_END = 3.0
Logic.BACK_END = 5.6
Logic.PUSH_FORWARD = 9 -- 앞으로 실어 줌 (걷기 16과 합쳐 25)
Logic.PUSH_BACK = -7 -- 뒤로 밂 (걸으면 9로 계속 전진)
Logic.BLINK = 0.1

local function cyclePos(t: number, offset: number): number
	return (t + offset) % Logic.CYCLE
end

function Logic.railPhase(t: number, offset: number): (RailState, number)
	local p = cyclePos(t, offset)
	if p < Logic.FORWARD_END then
		return "Forward", Logic.PUSH_FORWARD
	elseif p < Logic.WARN_BACK_END then
		return "WarnBack", 0
	elseif p < Logic.BACK_END then
		return "Back", Logic.PUSH_BACK
	end
	return "WarnForward", 0
end

-- Warn 동안 BLINK 간격으로 true(다음 색)/false(지금 색)를 번갈아요. Warn이 아니면 false.
function Logic.blinkOn(t: number, offset: number): boolean
	local p = cyclePos(t, offset)
	local warnStart: number
	if p >= Logic.FORWARD_END and p < Logic.WARN_BACK_END then
		warnStart = Logic.FORWARD_END
	elseif p >= Logic.BACK_END then
		warnStart = Logic.BACK_END
	else
		return false
	end
	return math.floor((p - warnStart) / Logic.BLINK + 1e-9) % 2 == 0
end

-- 한 주기 평균 밀기 (studs/s). 앞으로 가는 쪽이 조금 커요.
function Logic.averagePush(): number
	local forward = Logic.FORWARD_END * Logic.PUSH_FORWARD
	local back = (Logic.BACK_END - Logic.WARN_BACK_END) * Logic.PUSH_BACK
	return (forward + back) / Logic.CYCLE
end

-- ── 구간 · 낙하 ─────────────────────────────────────────────────────────────
function Logic.sectionAt(z: number): Layout.Section
	for _, s in Layout.SECTIONS do
		if z <= s.front and z > s.back then
			return s
		end
	end
	if z > Layout.SECTIONS[1].front then
		return Layout.SECTIONS[1]
	end
	return Layout.SECTIONS[#Layout.SECTIONS]
end

-- 그 z의 구간 바닥 높이. D는 첫 원판(0) → 마지막 원판(10) 사이를 보간해요.
function Logic.floorAt(z: number): number
	local s = Logic.sectionAt(z)
	if s.id == "D" then
		local t = math.clamp((Layout.D_START_Z - z) / (Layout.D_START_Z - Layout.D_END_Z), 0, 1)
		return Layout.TOP_Y * t
	end
	return s.floor
end

function Logic.fallLineAt(z: number): number
	return Logic.floorAt(z) - Layout.FALL_MARGIN
end

function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

-- ── 저중력 ─────────────────────────────────────────────────────────────────
Logic.LOW_GRAVITY = 0.5 -- 중력 배율 (너무 둥실하면 0.6)
Logic.JUMP_POWER = 50 -- Roblox 기본 점프력
Logic.GRAVITY = 196.2

function Logic.inGravityZone(x: number, y: number, z: number): boolean
	local g = Layout.GRAVITY_ZONE
	return x >= g.minX and x <= g.maxX and y >= g.minY and y <= g.maxY and z >= g.minZ and z <= g.maxZ
end

-- 위로 받쳐 주는 힘 = 질량 × 중력 × (1 − 배율)
function Logic.lowGravityForce(mass: number, gravity: number, factor: number): number
	return mass * gravity * (1 - factor)
end

function Logic.jumpHeight(jumpPower: number, gravity: number, factor: number): number
	return jumpPower * jumpPower / (2 * gravity * factor)
end

function Logic.airTime(jumpPower: number, gravity: number, factor: number): number
	return 2 * jumpPower / (gravity * factor)
end

-- ── C 소행성 그래프 ─────────────────────────────────────────────────────────
type Node = { name: string, x: number, z: number, top: number, radius: number }

local function asteroidNodes(branch: string?): { Node }
	local hubs = Layout.hubs()
	local entry = hubs[#Layout.B_HUBS]
	local exit = hubs[#Layout.B_HUBS + 1]
	local list: { Node } = {
		{ name = "Entry", x = entry.x, z = entry.z, top = entry.y, radius = entry.radius },
	}
	for _, a in Layout.ASTEROIDS do
		if branch == nil or a.branch == branch then
			table.insert(list, { name = a.name, x = a.x, z = a.z, top = a.top, radius = a.radius })
		end
	end
	table.insert(list, { name = "Exit", x = exit.x, z = exit.z, top = exit.y, radius = exit.radius })
	return list
end

-- 두 원판 가장자리 사이 수평 틈
function Logic.edgeGap(a: { x: number, z: number, radius: number }, b: { x: number, z: number, radius: number }): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) - a.radius - b.radius
end

-- 입구(B 마지막 원판) → 출구(D 첫 원판)로 갈 수 있는지. 한 번 뛰기 = 틈 ≤ maxGap이고 오르는 높이 ≤ maxRise.
-- branch를 주면 그 갈래 소행성만 써요.
function Logic.crossable(maxGap: number, maxRise: number, branch: string?): boolean
	local nodes = asteroidNodes(branch)
	local seen: { [number]: boolean } = { [1] = true }
	local queue = { 1 }
	while #queue > 0 do
		local i = table.remove(queue, 1) :: number
		if i == #nodes then
			return true
		end
		for j, b in nodes do
			if not seen[j] then
				local a = nodes[i]
				if Logic.edgeGap(a, b) <= maxGap and b.top - a.top <= maxRise then
					seen[j] = true
					table.insert(queue, j)
				end
			end
		end
	end
	return false
end

-- ── 운석 시간표 ─────────────────────────────────────────────────────────────
Logic.METEOR_START = 6
Logic.METEOR_INTERVAL = 10
Logic.METEOR_LATE = 40 -- 이때부터 한 번에 4개
Logic.FIELD_START = 10
Logic.FIELD_INTERVAL = 5
Logic.FIELD_LATE = 40 -- 이때부터 한 번에 3개

function Logic.meteorWave(t: number): Wave?
	if t < Logic.METEOR_START then
		return nil
	end
	return { count = if t < Logic.METEOR_LATE then 3 else 4, interval = Logic.METEOR_INTERVAL }
end

function Logic.fieldMeteorWave(t: number): Wave?
	if t < Logic.FIELD_START then
		return nil
	end
	return { count = if t < Logic.FIELD_LATE then 2 else 3, interval = Logic.FIELD_INTERVAL }
end

-- ── 레일 좌표 ───────────────────────────────────────────────────────────────
function Logic.railFrame(rail: Layout.Rail): Frame
	local dx, dz = rail.x1 - rail.x0, rail.z1 - rail.z0
	local h = math.sqrt(dx * dx + dz * dz)
	local fx, fz = dx / h, dz / h
	return {
		cx = (rail.x0 + rail.x1) / 2,
		cz = (rail.z0 + rail.z1) / 2,
		fx = fx,
		fz = fz,
		rx = -fz,
		rz = fx,
		half = h / 2,
		halfWidth = rail.width / 2,
	}
end

-- (x, z) → 조각 기준 (앞으로 along, 오른쪽 lateral)
function Logic.railLocal(rail: Layout.Rail, x: number, z: number): (number, number)
	local f = Logic.railFrame(rail)
	local px, pz = x - f.cx, z - f.cz
	return px * f.fx + pz * f.fz, px * f.rx + pz * f.rz
end

-- 그 along에서 레일 윗면 높이
function Logic.railTopAt(rail: Layout.Rail, along: number): number
	local f = Logic.railFrame(rail)
	local t = math.clamp((along + f.half) / (2 * f.half), 0, 1)
	return rail.y0 + (rail.y1 - rail.y0) * t
end

function Logic.railPoint(rail: Layout.Rail, along: number, lateral: number): Pos
	local f = Logic.railFrame(rail)
	return {
		x = f.cx + f.fx * along + f.rx * lateral,
		y = Logic.railTopAt(rail, along),
		z = f.cz + f.fz * along + f.rz * lateral,
	}
end

-- 이음매 원판 위인지 (수평)
function Logic.inHub(x: number, z: number): boolean
	for _, hub in Layout.hubs() do
		if (x - hub.x) ^ 2 + (z - hub.z) ^ 2 < hub.radius * hub.radius then
			return true
		end
	end
	return false
end

Logic.RIDE_BELOW = 2 -- 레일 윗면 아래 이만큼까지 (루트 기준)
Logic.RIDE_ABOVE = 8 -- 레일 윗면 위 이만큼까지 (루트 기준 — 발 + 5)

-- 레이서 루트(pos)가 그 레일 조각 위에 있는지 (원판 위는 아님)
function Logic.onRail(rail: Layout.Rail, pos: Pos): boolean
	local along, lateral = Logic.railLocal(rail, pos.x, pos.z)
	local f = Logic.railFrame(rail)
	if math.abs(along) > f.half or math.abs(lateral) > f.halfWidth then
		return false
	end
	if Logic.inHub(pos.x, pos.z) then
		return false
	end
	local dy = pos.y - Logic.railTopAt(rail, along)
	return dy >= -Logic.RIDE_BELOW and dy <= Logic.RIDE_ABOVE
end

function Logic.railAt(rails: { Layout.Rail }, pos: Pos): Layout.Rail?
	for _, rail in rails do
		if Logic.onRail(rail, pos) then
			return rail
		end
	end
	return nil
end

-- ── 운석 떨어질 곳 ───────────────────────────────────────────────────────────
Logic.RACER_CHANCE = 0.6
Logic.RACER_AHEAD = 8 -- 레이서 위치에서 레일 앞으로
Logic.FIELD_AHEAD = 6 -- E 들판: 레이서 발밑 앞
Logic.PICK_RETRIES = 5
Logic.END_CLEAR = 12 -- A·G에서 이만큼 떨어져요
Logic.MIN_SPACING = 10 -- 다른 운석·바위와 레일 따라 (z 거리)
Logic.LATERAL_MARGIN = 1 -- 노리는 점이 레일 가장자리에서 이만큼 안쪽

local function endsOk(z: number): boolean
	return z <= Layout.section("A").back - Logic.END_CLEAR and z >= Layout.section("G").front + Logic.END_CLEAR
end

local function spacingOk(z: number, taken: { Rock }): boolean
	for _, r in taken do
		if math.abs(r.z - z) < Logic.MIN_SPACING then
			return false
		end
	end
	return true
end

-- 레일 위 점을 원판 밖·가장자리 안쪽으로 옮겨요 (원판 중심에서 레일 가운데 쪽으로)
local function settleOnRail(rail: Layout.Rail, along: number, lateral: number): (number, number)
	local f = Logic.railFrame(rail)
	local l = math.clamp(lateral, -(f.halfWidth - Logic.LATERAL_MARGIN), f.halfWidth - Logic.LATERAL_MARGIN)
	local a = math.clamp(along, -f.half, f.half)
	local r = Layout.HUB_RADIUS
	if rail.hubStart or rail.hubEnd then
		local reach = math.sqrt(math.max(r * r - l * l, 0)) + 0.05
		local limit = f.half - reach
		if limit < 0 then
			limit = 0
		end
		if rail.hubEnd and a > limit then
			a = limit
		end
		if rail.hubStart and a < -limit then
			a = -limit
		end
	end
	return a, l
end

local function targetOk(p: Pos, taken: { Rock }): boolean
	return endsOk(p.z) and not Logic.inHub(p.x, p.z) and spacingOk(p.z, taken)
end

-- 레일 위 무작위 점 (조각 길이에 비례해 고르고, 원판 위는 다시)
local function randomRailPoint(rng: Rng, rails: { Layout.Rail }): (Layout.Rail?, number, number)
	local total = 0
	for _, rail in rails do
		total += 2 * Logic.railFrame(rail).half
	end
	if total <= 0 then
		return nil, 0, 0
	end
	local pick = rng:NextNumber(0, total)
	for _, rail in rails do
		local f = Logic.railFrame(rail)
		pick -= 2 * f.half
		if pick <= 0 then
			local m = f.halfWidth - Logic.LATERAL_MARGIN
			return rail, rng:NextNumber(-f.half, f.half), rng:NextNumber(-m, m)
		end
	end
	local last = rails[#rails]
	return last, 0, 0
end

-- 레일 운석 count개. racers는 레이서 루트 위치(로컬), rocks는 살아 있는 바위·떨어지는 중인 운석 자리.
-- 운석마다 60% = 레일 위 레이서 한 명의 레일 앞 8 지점, 40% = 레일 위 무작위. 안 맞으면 5번 다시, 그래도 안 되면 건너뜀.
function Logic.pickMeteorTargets(
	rng: Rng,
	racers: { Pos },
	rails: { Layout.Rail },
	rocks: { Rock },
	count: number
): { Target }
	local riders: { { pos: Pos, rail: Layout.Rail } } = {}
	for _, pos in racers do
		local rail = Logic.railAt(rails, pos)
		if rail then
			table.insert(riders, { pos = pos, rail = rail })
		end
	end
	local taken: { Rock } = table.clone(rocks)
	local out: { Target } = {}
	for _ = 1, count do
		local fromRacer = #riders > 0 and rng:NextNumber() < Logic.RACER_CHANCE
		for _ = 0, Logic.PICK_RETRIES do
			local rail: Layout.Rail?, along, lateral
			if fromRacer then
				local rider = riders[rng:NextInteger(1, #riders)]
				local ra, rl = Logic.railLocal(rider.rail, rider.pos.x, rider.pos.z)
				rail = rider.rail
				along, lateral = ra + Logic.RACER_AHEAD, rl
				-- 앞 8이 다음 조각이면 그 조각으로 (옆 위치는 그 조각 기준으로 다시)
				local f = Logic.railFrame(rider.rail)
				if along > f.half then
					local ahead = Logic.railPoint(rider.rail, f.half, rl)
					local fx, fz = ahead.x + f.fx * (along - f.half), ahead.z + f.fz * (along - f.half)
					for _, other in rails do
						local oa, ol = Logic.railLocal(other, fx, fz)
						local of = Logic.railFrame(other)
						if other ~= rider.rail and math.abs(oa) <= of.half and math.abs(ol) <= of.halfWidth then
							rail, along, lateral = other, oa, ol
							break
						end
					end
				end
			else
				rail, along, lateral = randomRailPoint(rng, rails)
			end
			if rail then
				local a, l = settleOnRail(rail, along, lateral)
				local p = Logic.railPoint(rail, a, l)
				if targetOk(p, taken) then
					table.insert(
						out,
						{ x = p.x, y = p.y, z = p.z, rail = rail.index, lateral = l, fromRacer = fromRacer }
					)
					table.insert(taken, { x = p.x, z = p.z })
					break
				end
			end
		end
	end
	return out
end

-- ── 바위 ───────────────────────────────────────────────────────────────────
Logic.ROCK_SIZE = { x = 4, y = 3, z = 4 }
Logic.ROCK_HALF = 2
Logic.ROCK_MIN_LATERAL = 3
Logic.ROCK_MAX_LATERAL = 5
Logic.ROCK_MIN_RAIL_WIDTH = 12 -- 이보다 좁은 레일(F 폭 9)에는 바위를 안 남겨요
Logic.ROCK_DELAY = 0.15
Logic.ROCK_LIFE = 6
Logic.ROCK_CRUMBLE = 0.5

-- 바위 가운데의 옆 위치: 맞은 쪽(중심이면 무작위 쪽)으로 3~5. 좁은 레일이면 nil.
function Logic.rockOffset(impactLateral: number, railWidth: number, rng: Rng): number?
	if railWidth < Logic.ROCK_MIN_RAIL_WIDTH then
		return nil
	end
	local side: number
	if math.abs(impactLateral) < 0.25 then
		side = if rng:NextNumber() < 0.5 then -1 else 1
	else
		side = if impactLateral < 0 then -1 else 1
	end
	return side * rng:NextNumber(Logic.ROCK_MIN_LATERAL, Logic.ROCK_MAX_LATERAL)
end

-- 바위 반대쪽 빈 폭 (바위 안쪽 모서리 → 반대쪽 레일 가장자리)
function Logic.freeWidthBeside(rockLateral: number, railWidth: number): number
	return railWidth / 2 + math.abs(rockLateral) - Logic.ROCK_HALF
end

-- ── E 운석 들판 ─────────────────────────────────────────────────────────────
Logic.FIELD_MIN_FREE = 10
Logic.FIELD_ROCK_SPACING = 8
Logic.FIELD_EDGE = 2.5 -- 노리는 점이 판 가장자리에서 이만큼 안쪽
Logic.FIELD_END_MARGIN = 4 -- 판 앞뒤 끝에서 이만큼 안쪽

-- 그 z에서 판 위에 남은 가장 넓은 빈 폭
function Logic.fieldFreeWidth(rocks: { Rock }, z: number): number
	local half = Layout.FIELD_WIDTH / 2
	local blocks: { { number } } = {}
	for _, r in rocks do
		if math.abs(r.z - z) < Logic.ROCK_HALF then
			table.insert(blocks, { r.x - Logic.ROCK_HALF, r.x + Logic.ROCK_HALF })
		end
	end
	table.sort(blocks, function(a: { number }, b: { number }): boolean
		return a[1] < b[1]
	end)
	local best, cursor = 0, -half
	for _, b in blocks do
		if b[1] > cursor then
			best = math.max(best, math.min(b[1], half) - cursor)
		end
		cursor = math.max(cursor, b[2])
	end
	if cursor < half then
		best = math.max(best, half - cursor)
	end
	return best
end

-- 바위들 앞뒤 모서리 근처 모든 z 중 가장 좁은 빈 폭
function Logic.fieldMinFreeWidth(rocks: { Rock }): number
	local worst = Layout.FIELD_WIDTH
	for _, r in rocks do
		local z = r.z - Logic.ROCK_HALF + 0.01
		while z < r.z + Logic.ROCK_HALF do
			worst = math.min(worst, Logic.fieldFreeWidth(rocks, z))
			z += 0.25
		end
	end
	return worst
end

local function onField(pos: Pos): boolean
	local e = Layout.section("E")
	return math.abs(pos.x) <= Layout.FIELD_WIDTH / 2
		and pos.z <= e.front
		and pos.z >= e.back
		and pos.y >= e.floor - Logic.RIDE_BELOW
		and pos.y <= e.floor + Logic.RIDE_ABOVE
end

local function fieldOk(x: number, z: number, taken: { Rock }): boolean
	for _, r in taken do
		if (r.x - x) ^ 2 + (r.z - z) ^ 2 < Logic.FIELD_ROCK_SPACING ^ 2 then
			return false
		end
	end
	local with = table.clone(taken)
	table.insert(with, { x = x, z = z })
	return Logic.fieldMinFreeWidth(with) >= Logic.FIELD_MIN_FREE
end

-- E 들판 운석 count개. rocks = 들판에 살아 있는 바위·떨어지는 중인 운석 자리 (바위는 운석 자리에 남아요).
function Logic.pickFieldTargets(rng: Rng, racers: { Pos }, rocks: { Rock }, count: number): { Target }
	local e = Layout.section("E")
	local maxX = Layout.FIELD_WIDTH / 2 - Logic.FIELD_EDGE
	local zFront, zBack = e.front - Logic.FIELD_END_MARGIN, e.back + Logic.FIELD_END_MARGIN
	local onPlate: { Pos } = {}
	for _, pos in racers do
		if onField(pos) then
			table.insert(onPlate, pos)
		end
	end
	local taken: { Rock } = table.clone(rocks)
	local out: { Target } = {}
	for _ = 1, count do
		local fromRacer = #onPlate > 0 and rng:NextNumber() < Logic.RACER_CHANCE
		for _ = 0, Logic.PICK_RETRIES do
			local x, z
			if fromRacer then
				local pos = onPlate[rng:NextInteger(1, #onPlate)]
				x, z = pos.x, pos.z - Logic.FIELD_AHEAD
			else
				x, z = rng:NextNumber(-maxX, maxX), rng:NextNumber(zBack, zFront)
			end
			x, z = math.clamp(x, -maxX, maxX), math.clamp(z, zBack, zFront)
			if fieldOk(x, z, taken) then
				table.insert(out, { x = x, y = e.floor, z = z, rail = nil, lateral = x, fromRacer = fromRacer })
				table.insert(taken, { x = x, z = z })
				break
			end
		end
	end
	return out
end

-- ── 충돌 ───────────────────────────────────────────────────────────────────
Logic.WARN_TIME = 1.6
Logic.IMPACT_RADIUS = 5
Logic.IMPACT_HEIGHT = 6 -- 발이 윗면 + 6 아래면 맞아요
Logic.IMPACT_BELOW = 3 -- 윗면 아래 3까지 (그보다 아래는 이미 떨어지는 중)
Logic.KNOCK_OUT = 30
Logic.KNOCK_UP = 20
Logic.LAUNCH_HOLD = 0.12
Logic.KNOCKDOWN_TIME = 0.8
Logic.EXEMPT_TIME = 1.5
Logic.HIT_COOLDOWN = 0.6
Logic.FOOT_BELOW_ROOT = 3 -- 루트 중심에서 발까지 (R15 근사)

function Logic.inImpact(horizontal: number, footAboveTop: number): boolean
	return horizontal <= Logic.IMPACT_RADIUS
		and footAboveTop < Logic.IMPACT_HEIGHT
		and footAboveTop >= -Logic.IMPACT_BELOW
end

-- 원 중심에서 바깥으로 수평 30 + 위 20. 거의 중심이면 (fallbackX, fallbackZ) 쪽으로.
function Logic.knockback(dx: number, dz: number, fallbackX: number, fallbackZ: number): Pos
	local len = math.sqrt(dx * dx + dz * dz)
	local ux, uz
	if len < 0.3 then
		local fl = math.sqrt(fallbackX * fallbackX + fallbackZ * fallbackZ)
		if fl < 1e-6 then
			ux, uz = 1, 0
		else
			ux, uz = fallbackX / fl, fallbackZ / fl
		end
	else
		ux, uz = dx / len, dz / len
	end
	return { x = ux * Logic.KNOCK_OUT, y = Logic.KNOCK_UP, z = uz * Logic.KNOCK_OUT }
end

-- ── 길이 추정 ───────────────────────────────────────────────────────────────
-- 경로 길이 ÷ 걷기 16 + 스펙 추정 지연(레일 뒤로 밀림 4, 저중력 점프 4, 운석·바위 피하기 5, 갈림길 고르기 2)
Logic.DELAY_RAIL_BACK = 4
Logic.DELAY_LOW_GRAVITY = 4
Logic.DELAY_METEORS = 5
Logic.DELAY_FORK = 2

function Logic.estimateClearTime(): number
	local walk = math.min(Layout.pathLength("L"), Layout.pathLength("R")) / Layout.WALK_SPEED
	return walk + Logic.DELAY_RAIL_BACK + Logic.DELAY_LOW_GRAVITY + Logic.DELAY_METEORS + Logic.DELAY_FORK
end

return Logic
