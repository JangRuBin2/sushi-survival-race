--!strict
-- "우주 회전초밥"(space-conveyor, m5-35) 코스 치수·튜닝 값 (Roblox API 없음).
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(+가 origin.RightVector), y: 위, z: 0이 출발 끝이고 음수로 갈수록 결승.
-- 코스를 출발부터 따라가면 z가 줄기만 해요(S자로 휘어도 뒤로 돌아가지 않아요).
--
-- 구간 (z, 바닥 윗면 y)
--   A 출발           0 ~ -16     y 0       발사대, 폭 24, 스폰 24개(6 × 4)
--   B 레일 1        -16 ~ -100   y 0       직선 레일 조각 5개(폭 14, S자 ±30° 안) + 이음매 원판(지름 14)
--   C 소행성 징검다리 -100 ~ -170  y -2~+4  저중력 구역, 소행성 8개 = 왼쪽 4 + 오른쪽 4 (두 갈래가 D 첫 원판에서 합침)
--   D 레일 2       -170 ~ -270   y 0 → 10  오르막 레일 조각 6개(폭 12, 경사 ≤ 6°) + 이음매 원판
--   E 운석 들판     -270 ~ -350   y 10      넓은 소행성 판(폭 30, 밀기 없음) — 운석이 따로 더 떨어져요
--   F 두 갈래 레일  -350 ~ -440   y 10      나란한 레일 2줄(각 폭 9, 사이 6), 두 줄 방향 전환이 반대 위상
--   G 결승         -440 ~ -470   y 10      행성 정거장 착륙장, 폭 26, FinishLine z -462
--
-- 레일 조각은 이음매 원판 중심에서 시작해 다음 원판 중심에서 끝나요 → 조각 끝 모서리가 원판 위(틈 없음).
-- 원판 윗면은 레일보다 HUB_SINK만큼 낮아서(겹친 면이 깜빡이지 않게) 레일 위에서는 레일만 밟혀요.

export type Point = { x: number, y: number, z: number }
export type Section = { id: string, front: number, back: number, floor: number }
export type Hub = { x: number, y: number, z: number, radius: number }
-- 레일 조각 하나. (x0,y0,z0) → (x1,y1,z1)이 윗면 가운데 선(뒤 → 앞), group은 방향 전환 묶음
export type Rail = {
	index: number,
	group: string, -- "B" | "D" | "FL" | "FR"
	offset: number, -- 방향 전환 위상 (초)
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	width: number,
	allowRock: boolean, -- 운석 바위를 남길 수 있는 폭인지 (F 폭 9는 안 남겨요)
	hubStart: boolean, -- 시작점이 이음매 원판 중심인지
	hubEnd: boolean,
}
export type Asteroid = {
	name: string,
	branch: string, -- "L" | "R"
	x: number,
	z: number,
	top: number,
	radius: number,
}

local Layout = {}

Layout.ID = "space-conveyor"
Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 25 -- 구간 바닥보다 이만큼 아래면 탈락
Layout.WALK_SPEED = 16

-- ── 구간 ───────────────────────────────────────────────────────────────────
Layout.SECTIONS = {
	{ id = "A", front = 0, back = -16, floor = 0 },
	{ id = "B", front = -16, back = -100, floor = 0 },
	{ id = "C", front = -100, back = -170, floor = -2 }, -- 가장 낮은 소행성 윗면
	{ id = "D", front = -170, back = -270, floor = 0 }, -- 0 → 10 (Logic.floorAt이 보간)
	{ id = "E", front = -270, back = -350, floor = 10 },
	{ id = "F", front = -350, back = -440, floor = 10 },
	{ id = "G", front = -440, back = -470, floor = 10 },
} :: { Section }

Layout.START_WIDTH = 24
Layout.FIELD_WIDTH = 30
Layout.FINISH_WIDTH = 26
Layout.FINISH_LINE_Z = -462
Layout.TOP_Y = 10 -- D 끝·E·F·G 바닥

-- ── 레일 ───────────────────────────────────────────────────────────────────
Layout.RAIL_B_WIDTH = 14
Layout.RAIL_D_WIDTH = 12
Layout.RAIL_F_WIDTH = 9
Layout.RAIL_F_GAP = 6 -- 두 줄 사이 빈틈
Layout.HUB_RADIUS = 7 -- 이음매 원판 반지름 (지름 14)
Layout.HUB_SINK = 0.05 -- 원판 윗면을 레일보다 이만큼 낮게
Layout.MAX_RAIL_YAW = 30 -- 도
Layout.MAX_RAIL_SLOPE = 6 -- 도

-- B 레일 1: 이음매 원판 중심 (y 0). 첫 원판은 출발 판 끝, 마지막 원판은 C 입구.
Layout.B_HUBS = {
	{ x = 0, z = -16 },
	{ x = 7, z = -32 },
	{ x = -2, z = -48 },
	{ x = 6, z = -63 },
	{ x = -2, z = -78 },
	{ x = 0, z = -93 }, -- 앞 가장자리 z -100 = C 시작
}

-- D 레일 2: 이음매 원판 7개, 조각 6개 — 원판마다 10/6씩 올라가요 (지그재그 "나선" 오르막)
Layout.D_START_Z = -177 -- 첫 원판 중심 (뒤 가장자리 z -170 = D 시작)
Layout.D_END_Z = -263 -- 마지막 원판 중심 (앞 가장자리 z -270 = E 시작)
Layout.D_SWING_X = 8

-- F 두 갈래 레일: 가운데 x = ±(폭/2 + 사이/2)
Layout.F_OFFSET = { FL = 0, FR = 3 }

-- 방향 전환 위상 (초): 레일 1 = 0, 레일 2 = 3 (서로 반대)
Layout.RAIL_OFFSET = { B = 0, D = 3 }

-- ── C 소행성 ───────────────────────────────────────────────────────────────
-- 두 갈래(왼쪽 L·오른쪽 R)가 B 마지막 원판에서 갈라져 D 첫 원판에서 합쳐요.
-- 갈래마다 틈 ≥ 9인 곳이 하나(2번째 뜀) — 보통 중력(수평 약 8)으로는 못 건너고 저중력(약 16)이면 건너요.
Layout.ASTEROIDS = {
	{ name = "L1", branch = "L", x = -11, z = -108, top = 1, radius = 5 },
	{ name = "L2", branch = "L", x = -14, z = -127.5, top = 3, radius = 5 },
	{ name = "L3", branch = "L", x = -12, z = -144.5, top = 4, radius = 5.5 },
	{ name = "L4", branch = "L", x = -6, z = -160, top = 2, radius = 5 },
	{ name = "R1", branch = "R", x = 11, z = -108, top = 0, radius = 5 },
	{ name = "R2", branch = "R", x = 14, z = -127.5, top = -2, radius = 5 },
	{ name = "R3", branch = "R", x = 12, z = -144.5, top = 1, radius = 5.5 },
	{ name = "R4", branch = "R", x = 6, z = -160, top = 2, radius = 5 },
} :: { Asteroid }
Layout.ASTEROID_THICKNESS = 3

-- 저중력 구역 (C를 덮는 상자)
Layout.GRAVITY_ZONE = { minX = -32, maxX = 32, minY = -30, maxY = 45, minZ = -172, maxZ = -98 }

-- ── 스폰 ───────────────────────────────────────────────────────────────────
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_SPACING_X = 3.6
Layout.SPAWN_SPACING_Z = 3.4

function Layout.spawnPositions(): { { x: number, z: number } }
	local list = {}
	for row = 0, Layout.SPAWN_ROWS - 1 do
		for col = 0, Layout.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (Layout.SPAWN_COLUMNS - 1) / 2) * Layout.SPAWN_SPACING_X,
				z = -2.4 - row * Layout.SPAWN_SPACING_Z,
			})
		end
	end
	return list
end

-- ── 계산 ───────────────────────────────────────────────────────────────────
function Layout.section(id: string): Section
	for _, s in Layout.SECTIONS do
		if s.id == id then
			return s
		end
	end
	error(`unknown section {id}`)
end

local function dHubPoints(): { Point }
	local list: { Point } = {}
	local count = 6
	for i = 0, count do
		local t = i / count
		table.insert(list, {
			x = if i % 2 == 1 then Layout.D_SWING_X else 0,
			y = Layout.TOP_Y * t,
			z = Layout.D_START_Z + (Layout.D_END_Z - Layout.D_START_Z) * t,
		})
	end
	return list
end

-- 이음매 원판 전부 (B 6개 + D 7개). y는 레일 윗면 높이(원판 윗면은 여기서 HUB_SINK 아래).
function Layout.hubs(): { Hub }
	local list: { Hub } = {}
	for _, p in Layout.B_HUBS do
		table.insert(list, { x = p.x, y = 0, z = p.z, radius = Layout.HUB_RADIUS })
	end
	for _, p in dHubPoints() do
		table.insert(list, { x = p.x, y = p.y, z = p.z, radius = Layout.HUB_RADIUS })
	end
	return list
end

-- 레일 조각 전부: B 5개, D 6개, F 2줄 (출발 → 결승 순서)
function Layout.rails(): { Rail }
	local list: { Rail } = {}
	local function add(
		group: string,
		offset: number,
		a: Point,
		b: Point,
		width: number,
		allowRock: boolean,
		hubs: boolean
	)
		table.insert(list, {
			index = #list + 1,
			group = group,
			offset = offset,
			x0 = a.x,
			y0 = a.y,
			z0 = a.z,
			x1 = b.x,
			y1 = b.y,
			z1 = b.z,
			width = width,
			allowRock = allowRock,
			hubStart = hubs,
			hubEnd = hubs,
		})
	end
	for i = 1, #Layout.B_HUBS - 1 do
		local a, b = Layout.B_HUBS[i], Layout.B_HUBS[i + 1]
		add(
			"B",
			Layout.RAIL_OFFSET.B,
			{ x = a.x, y = 0, z = a.z },
			{ x = b.x, y = 0, z = b.z },
			Layout.RAIL_B_WIDTH,
			true,
			true
		)
	end
	local d = dHubPoints()
	for i = 1, #d - 1 do
		add("D", Layout.RAIL_OFFSET.D, d[i], d[i + 1], Layout.RAIL_D_WIDTH, true, true)
	end
	local f = Layout.section("F")
	local cx = Layout.RAIL_F_WIDTH / 2 + Layout.RAIL_F_GAP / 2
	for _, lane in { { "FL", -cx }, { "FR", cx } } do
		local group = lane[1] :: string
		local x = lane[2] :: number
		add(
			group,
			Layout.F_OFFSET[group],
			{ x = x, y = Layout.TOP_Y, z = f.front },
			{ x = x, y = Layout.TOP_Y, z = f.back },
			Layout.RAIL_F_WIDTH,
			false,
			false
		)
	end
	return list
end

-- 레일 조각의 수평 길이·전체 길이·방향(도)·경사(도)
function Layout.railGeometry(rail: Rail): { horizontal: number, length: number, yawDeg: number, slopeDeg: number }
	local dx, dy, dz = rail.x1 - rail.x0, rail.y1 - rail.y0, rail.z1 - rail.z0
	local horizontal = math.sqrt(dx * dx + dz * dz)
	return {
		horizontal = horizontal,
		length = math.sqrt(horizontal * horizontal + dy * dy),
		yawDeg = math.deg(math.atan2(dx, -dz)), -- 0 = 바로 앞(-Z), + = 오른쪽(+X)으로 틀어짐
		slopeDeg = math.deg(math.atan2(dy, horizontal)),
	}
end

-- 출발 → 결승 경로 (왼쪽 갈래 기준). AC2 "z가 줄기만" 확인용.
function Layout.path(branch: string?): { Point }
	local list: { Point } = { { x = 0, y = 0, z = -8 } }
	for _, p in Layout.B_HUBS do
		table.insert(list, { x = p.x, y = 0, z = p.z })
	end
	local b = branch or "L"
	for _, a in Layout.ASTEROIDS do
		if a.branch == b then
			table.insert(list, { x = a.x, y = a.top, z = a.z })
		end
	end
	for _, p in dHubPoints() do
		table.insert(list, p)
	end
	local e, f = Layout.section("E"), Layout.section("F")
	table.insert(list, { x = 0, y = Layout.TOP_Y, z = e.back })
	table.insert(list, { x = 0, y = Layout.TOP_Y, z = f.back })
	table.insert(list, { x = 0, y = Layout.TOP_Y, z = Layout.FINISH_LINE_Z })
	return list
end

function Layout.pathLength(branch: string?): number
	local total = 0
	local points = Layout.path(branch)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
	end
	return total
end

function Layout.totalLength(): number
	return Layout.SECTIONS[1].front - Layout.SECTIONS[#Layout.SECTIONS].back
end

return Layout
