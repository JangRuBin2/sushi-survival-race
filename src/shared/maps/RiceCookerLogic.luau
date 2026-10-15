--!strict
-- "초대형 밥솥"(rice-cooker, m5-36) 순수 로직 (Roblox API 없음, tests/map-rice-cooker.spec.luau).
--   Logic.burstWave(t) -> { interval, count }?      밥알 끓어오름 일정 (5초 전이면 nil)
--   Logic.pickBurstSpots(rng, racers, count) -> { Spot }   곳 고르기 (언덕 중심 기준 x, z)
--   Logic.burstKnockback(dx, dz, rng) -> Velocity?  원 중심 → 레이서 (dx, dz). 원 밖이면 nil
--   Logic.steamSchedule(t) -> { interval, count }?  증기 분사 일정 (12초 전이면 nil)
--   Logic.steamTimes(limit) -> { number }           분사 경고가 시작되는 시각들 (12, 24, 36, 44, …)
--   Logic.steamBands(t, rng, last) -> { Jet }        이번 분사 띠·밸브 (last = 바로 전 차례 띠 번호들)
--   Logic.inBand(z, band) -> boolean                언덕 중심 기준 z가 띠 안인지
--   Logic.steamKnockback(side) -> Velocity          밸브(side) → 반대쪽으로 밀 속도
--   Logic.formatTimer(seconds) -> "mm:ss"           솥 앞 디지털 타이머 글자
-- 속도·좌표는 origin 로컬 축(x, y, z)이에요. rng는 Roblox Random처럼 NextInteger·NextNumber를 가져요.

local Layout = require(script.Parent.RiceCookerLayout)

export type Velocity = { x: number, y: number, z: number }
export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
	NextNumber: (self: any) -> number,
}
export type Wave = { interval: number, count: number }
export type Spot = { x: number, z: number, targeted: boolean }
export type Point = { x: number, z: number }
export type Jet = { band: number, side: number } -- side 1 = +X 밸브(−X로 밀어요), −1 = −X 밸브

local Logic = {}

Logic.TIME_LIMIT = 75 -- 맵 timeLimit (스펙 D5, Config.TimeLimit.Survival 60보다 15초 길게)
Logic.CHECK_INTERVAL = 0.1 -- 서버 낙하·분사 확인 간격

-- 밥알 끓어오름 (스펙 표)
Logic.BURST_SCHEDULE = {
	{ from = 5, interval = 7, count = 1 },
	{ from = 20, interval = 5.5, count = 2 },
	{ from = 40, interval = 4.5, count = 3 },
	{ from = 60, interval = 3.5, count = 3 },
}
Logic.BURST_RADIUS = 6
Logic.BURST_WARN_TIME = 1.5
Logic.BURST_TARGET_CHANCE = 0.6 -- 레이서 발밑을 고를 확률
Logic.BURST_TARGET_JITTER = 2 -- 레이서 발밑 ± 이만큼
Logic.BURST_SPOT_RADIUS = 36 -- 곳은 언덕 중심에서 이 반지름 안
Logic.BURST_MIN_SEPARATION = 12 -- 같은 차례 곳끼리 중심 거리
Logic.BURST_PICK_TRIES = 12
Logic.BURST_UP = 45
Logic.BURST_OUT = 22
Logic.BURST_HEIGHT_RANGE = 5 -- 발 < 윗면 + 이 값이면 맞아요
Logic.BURST_HOLD = 0.12 -- LinearVelocity로 붙잡는 시간
Logic.BURST_KNOCKDOWN_TIME = 0.8 -- PlatformStand
Logic.BURST_MOVE_EXEMPT = 1.5
Logic.BURST_COOLDOWN = 0.6

-- 증기 분사 (스펙 표)
Logic.STEAM_SCHEDULE = {
	{ from = 12, interval = 12, count = 1 },
	{ from = 36, interval = 8, count = 2 },
	{ from = 60, interval = 6, count = 2 },
}
Logic.STEAM_WARN_TIME = 2
Logic.STEAM_BLAST_TIME = 1.2
Logic.STEAM_PUSH = 34
Logic.STEAM_UP = 10
Logic.STEAM_HEIGHT_RANGE = 8 -- 발 < 윗면 + 이 값이면 맞아요 (점프 높이 약 6.4보다 커서 점프로 못 피함)
Logic.STEAM_HOLD = 0.12
Logic.STEAM_KNOCKDOWN_TIME = 0.6
Logic.STEAM_MOVE_EXEMPT = 1.2

local function row(schedule: { { from: number, interval: number, count: number } }, t: number): Wave?
	local found: Wave? = nil
	for _, entry in schedule do
		if t >= entry.from then
			found = { interval = entry.interval, count = entry.count }
		end
	end
	return found
end

function Logic.burstWave(t: number): Wave?
	return row(Logic.BURST_SCHEDULE, t)
end

function Logic.steamSchedule(t: number): Wave?
	return row(Logic.STEAM_SCHEDULE, t)
end

local function dist(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- 반지름 limit 안으로 당겨요
local function clampRadius(x: number, z: number, limit: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	if r <= limit then
		return x, z
	end
	return x * limit / r, z * limit / r
end

local function randomPoint(rng: Rng, radius: number): (number, number)
	local r = radius * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber() * 2 * math.pi
	return r * math.cos(a), r * math.sin(a)
end

-- racers: 살아 있는 레이서 발 위치 (언덕 중심 기준 x, z). 곳마다 60% 레이서 한 명 발밑 ± 2, 40% 언덕 위 무작위.
-- 같은 차례 곳끼리 중심 거리 ≥ 12 — 몇 번 다시 뽑아도 안 되면 그 곳은 빼요 (count보다 적을 수 있어요).
function Logic.pickBurstSpots(rng: Rng, racers: { Point }, count: number): { Spot }
	local spots: { Spot } = {}
	for _ = 1, count do
		for _ = 1, Logic.BURST_PICK_TRIES do
			local x, z
			local targeted = #racers > 0 and rng:NextNumber() < Logic.BURST_TARGET_CHANCE
			if targeted then
				local racer = racers[rng:NextInteger(1, #racers)]
				local jx, jz = randomPoint(rng, Logic.BURST_TARGET_JITTER)
				x, z = clampRadius(racer.x + jx, racer.z + jz, Logic.BURST_SPOT_RADIUS)
			else
				x, z = randomPoint(rng, Logic.BURST_SPOT_RADIUS)
			end
			local candidate: Spot = { x = x, z = z, targeted = targeted }
			local ok = true
			for _, other in spots do
				if dist(candidate, other) < Logic.BURST_MIN_SEPARATION then
					ok = false
					break
				end
			end
			if ok then
				table.insert(spots, candidate)
				break
			end
		end
	end
	return spots
end

-- 원 안(수평 ≤ 6)이면 위 45 + 원 중심에서 바깥으로 22. 중심이면 무작위 수평 방향.
function Logic.burstKnockback(dx: number, dz: number, rng: Rng): Velocity?
	local d = math.sqrt(dx * dx + dz * dz)
	if d > Logic.BURST_RADIUS then
		return nil
	end
	local ux, uz
	if d < 1e-3 then
		local a = rng:NextNumber() * 2 * math.pi
		ux, uz = math.cos(a), math.sin(a)
	else
		ux, uz = dx / d, dz / d
	end
	return { x = ux * Logic.BURST_OUT, y = Logic.BURST_UP, z = uz * Logic.BURST_OUT }
end

-- 분사 경고가 시작되는 시각 (limit 전까지): 12, 24, 36, 44, 52, 60, 66, 72
function Logic.steamTimes(limit: number): { number }
	local times: { number } = {}
	local t = Logic.STEAM_SCHEDULE[1].from
	while t < limit do
		table.insert(times, t)
		local wave = Logic.steamSchedule(t)
		if wave == nil then
			break
		end
		t += wave.interval
	end
	return times
end

function Logic.inBand(z: number, band: number): boolean
	local center = Layout.BANDS[band]
	if center == nil then
		return false
	end
	return math.abs(z - center) <= Layout.BAND_HALF_WIDTH
end

-- 띠 고르기. 1개면 바로 전 띠들과 다른 띠, 한쪽 밸브(무작위). 2개면 서로 다른 띠 + 양쪽 밸브,
-- 바로 전 차례에 없던 띠가 적어도 하나. 3개 중 1개는 늘 비어 있어요.
function Logic.steamBands(t: number, rng: Rng, last: { number }?): { Jet }
	local wave = Logic.steamSchedule(t)
	if wave == nil then
		return {}
	end
	local previous: { [number]: boolean } = {}
	for _, band in last or {} do
		previous[band] = true
	end
	local fresh: { number } = {}
	for band = 1, #Layout.BANDS do
		if not previous[band] then
			table.insert(fresh, band)
		end
	end
	if #fresh == 0 then
		fresh = { 1, 2, 3 }
	end
	local firstBand = fresh[rng:NextInteger(1, #fresh)]
	local firstSide = if rng:NextInteger(0, 1) == 0 then 1 else -1
	local jets: { Jet } = { { band = firstBand, side = firstSide } }
	if wave.count >= 2 then
		local others: { number } = {}
		for band = 1, #Layout.BANDS do
			if band ~= firstBand then
				table.insert(others, band)
			end
		end
		table.insert(jets, { band = others[rng:NextInteger(1, #others)], side = -firstSide })
	end
	return jets
end

-- side 1(+X 밸브)이면 −X로, −1이면 +X로 수평 34 + 위 10
function Logic.steamKnockback(side: number): Velocity
	return { x = -side * Logic.STEAM_PUSH, y = Logic.STEAM_UP, z = 0 }
end

function Logic.formatTimer(seconds: number): string
	local s = if seconds ~= seconds then 0 else math.max(0, math.ceil(seconds - 1e-9))
	return string.format("%02d:%02d", s // 60, s % 60)
end

return Logic
