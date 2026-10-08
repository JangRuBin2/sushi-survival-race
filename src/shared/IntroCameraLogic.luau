--!strict
-- 라운드 소개 플라이스루 카메라 경로 (순수 로직, m3-04). Roblox API를 쓰지 않아요.
-- 위치·방향은 숫자 표 { x, y, z }예요. IntroController가 CFrame.lookAt(position, lookAt)으로 바꿔요.
--
--   IntroCameraLogic.autoPath(bounds, origin, kind) -> { Waypoint }
--       bounds = { center, size }: 맵 경계 상자 (월드 축 기준)
--       origin = { position, forward }: 출발 지점(스폰 쪽)과 코스 방향(맵 origin의 LookVector)
--       Race: 코스 끝(결승선 쪽) 위 → 코스 가운데 위 → 스폰 뒤쪽 위에서 코스 방향을 바라봐요.
--       Survival·Final: 맵 가운데를 바라보며 반 바퀴 돌고 스폰 쪽 위에서 끝나요.
--       모든 경유점은 경계 상자 꼭대기보다 높아요.
--   IntroCameraLogic.sample(path, t) -> Waypoint
--       t = 0~1. 전체에 가감속을 걸고, 경유점 사이는 이동 거리 비율로 이어서 앞으로만 가요.
--   IntroCameraLogic.ease(t)   0~1 가감속 (smoothstep)

export type Vec = { x: number, y: number, z: number }
export type Bounds = { center: Vec, size: Vec }
export type Origin = { position: Vec, forward: Vec }
export type Waypoint = { position: Vec, lookAt: Vec }
export type Kind = "Race" | "Survival" | "Final"

local IntroCameraLogic = {}

-- 경로 높이: 경계 상자 꼭대기에서 최소 이만큼 위
local MIN_CLEARANCE = 12
-- Race: 코스 길이에 비례한 높이와 시작·끝 지점의 바깥쪽 여유
local RACE_HEIGHT_RATIO = 0.18
local RACE_END_MARGIN = 15
local RACE_SPAWN_BACK = 28
local RACE_SPAWN_HEIGHT = 14 -- 마지막 점: 꼭대기 위 (캐릭터 뒤로 붙기 쉽게 낮게)
local RACE_LOOK_AHEAD = 45
-- Survival·Final: 반 바퀴 원 궤도
local ORBIT_POINTS = 7
local ORBIT_MARGIN = 20
local ORBIT_HEIGHT_RATIO = 0.6

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function add(a: Vec, b: Vec): Vec
	return vec(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function sub(a: Vec, b: Vec): Vec
	return vec(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function scale(a: Vec, s: number): Vec
	return vec(a.x * s, a.y * s, a.z * s)
end

local function length(a: Vec): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

local function lerp(a: Vec, b: Vec, alpha: number): Vec
	return vec(a.x + (b.x - a.x) * alpha, a.y + (b.y - a.y) * alpha, a.z + (b.z - a.z) * alpha)
end

-- 수평(XZ) 단위 벡터. 길이가 거의 0이면 fallback.
local function flatUnit(a: Vec, fallback: Vec): Vec
	local len = math.sqrt(a.x * a.x + a.z * a.z)
	if len < 1e-6 then
		return fallback
	end
	return vec(a.x / len, 0, a.z / len)
end

local function withY(a: Vec, y: number): Vec
	return vec(a.x, y, a.z)
end

function IntroCameraLogic.ease(t: number): number
	local c = math.clamp(t, 0, 1)
	return c * c * (3 - 2 * c)
end

local function racePath(bounds: Bounds, origin: Origin): { Waypoint }
	local center, size = bounds.center, bounds.size
	local top = center.y + size.y / 2
	local forward = flatUnit(origin.forward, vec(0, 0, -1))
	local start = origin.position

	-- 경계 상자를 forward 축에 투영했을 때 가장 먼 끝 (코스 끝, 결승선 쪽)
	local halfAlong = math.abs(size.x * forward.x) / 2 + math.abs(size.z * forward.z) / 2
	local centerAlong = (center.x - start.x) * forward.x + (center.z - start.z) * forward.z
	local farAlong = centerAlong + halfAlong
	local courseLength = math.max(farAlong, 1)
	local height = top + math.max(MIN_CLEARANCE, courseLength * RACE_HEIGHT_RATIO)

	local startFlat = withY(start, 0)
	local farPoint = add(startFlat, scale(forward, farAlong + RACE_END_MARGIN))
	local midPoint = add(startFlat, scale(forward, farAlong / 2))
	local spawnBack = add(startFlat, scale(forward, -RACE_SPAWN_BACK))
	local groundY = start.y

	return {
		{
			position = withY(farPoint, height),
			lookAt = withY(midPoint, groundY),
		},
		{
			position = withY(midPoint, (height + top + RACE_SPAWN_HEIGHT) / 2),
			lookAt = withY(startFlat, groundY),
		},
		{
			position = withY(spawnBack, top + RACE_SPAWN_HEIGHT),
			lookAt = withY(add(startFlat, scale(forward, RACE_LOOK_AHEAD)), groundY),
		},
	}
end

local function orbitPath(bounds: Bounds, origin: Origin): { Waypoint }
	local center, size = bounds.center, bounds.size
	local top = center.y + size.y / 2
	local radius = math.max(size.x, size.z) / 2 + ORBIT_MARGIN
	local height = top + math.max(MIN_CLEARANCE, radius * ORBIT_HEIGHT_RATIO)

	-- 끝나는 쪽: 가운데에서 스폰 쪽. 스폰이 가운데에 모여 있으면 forward의 반대쪽(코스 시작 쪽).
	local backward = scale(flatUnit(origin.forward, vec(0, 0, -1)), -1)
	local toSpawn = sub(origin.position, center)
	local endDir = if math.sqrt(toSpawn.x * toSpawn.x + toSpawn.z * toSpawn.z) > radius * 0.2
		then flatUnit(toSpawn, backward)
		else backward
	local endAngle = math.atan2(endDir.z, endDir.x)

	local path: { Waypoint } = {}
	for i = 0, ORBIT_POINTS - 1 do
		local angle = endAngle + math.pi * (1 - i / (ORBIT_POINTS - 1))
		local position = vec(center.x + math.cos(angle) * radius, height, center.z + math.sin(angle) * radius)
		table.insert(path, { position = position, lookAt = center })
	end
	return path
end

function IntroCameraLogic.autoPath(bounds: Bounds, origin: Origin, kind: Kind): { Waypoint }
	if kind == "Race" then
		return racePath(bounds, origin)
	end
	return orbitPath(bounds, origin)
end

local function copy(waypoint: Waypoint): Waypoint
	local p, l = waypoint.position, waypoint.lookAt
	return { position = vec(p.x, p.y, p.z), lookAt = vec(l.x, l.y, l.z) }
end

function IntroCameraLogic.sample(path: { Waypoint }, t: number): Waypoint
	assert(#path > 0, "IntroCameraLogic.sample: empty path")
	if #path == 1 then
		return copy(path[1])
	end

	-- 경유점 사이 거리 (같은 위치가 겹쳐도 멈추지 않게 아주 작은 값은 둬요)
	local lengths: { number } = {}
	local total = 0
	for i = 1, #path - 1 do
		local segment = math.max(length(sub(path[i + 1].position, path[i].position)), 1e-3)
		lengths[i] = segment
		total += segment
	end

	local distance = IntroCameraLogic.ease(t) * total
	for i = 1, #path - 1 do
		local segment = lengths[i]
		if distance <= segment or i == #path - 1 then
			local alpha = math.clamp(distance / segment, 0, 1)
			return {
				position = lerp(path[i].position, path[i + 1].position, alpha),
				lookAt = lerp(path[i].lookAt, path[i + 1].lookAt, alpha),
			}
		end
		distance -= segment
	end
	return copy(path[#path])
end

return IntroCameraLogic
