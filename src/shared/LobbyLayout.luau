--!strict
-- 로비 회전초밥집 배치 (GDD 3.1, 8, m4-06). 순수 데이터·순수 함수라 Roblox API를 쓰지 않아요.
-- 좌표는 월드 좌표 그대로예요 (로비 원점 = Baseplate 가운데 = LobbySpawn 바닥, 앞쪽 = -Z, 바닥 윗면 y = 0).
--   LobbyLayout.STRUCTURE      충돌 있는 건물 파츠 DecorSpec (벽·기둥·카운터·레일·단상)
--   LobbyLayout.DECOR          충돌 없는 장식 DecorSpec (들보·등·메뉴판·노렌·셰프·의자·수조)
--   LobbyLayout.LIGHTS         PointLight를 넣을 장식 파츠 이름과 빛 설정 (최대 8개)
--   LobbyLayout.RAIL           타원 레일 (가운데, 반지름 a(X)·b(Z), 속도, 접시 수)
--   LobbyLayout.railLength()   레일 가운데 선 둘레 (studs)
--   LobbyLayout.period()       한 바퀴 시간 = 둘레 / 속도 (초)
--   LobbyLayout.pointAtArc(s)  레일 위 호 길이 s 지점 { x, y, z, yaw } (yaw: 라디안, 진행 방향이 로컬 -Z)
--   LobbyLayout.plateArc(i, t) 접시 i(1~16)의 시각 t(서버 시각, 초) 호 길이 위치
--   LobbyLayout.plateAt(i, t)  접시 i의 시각 t 자리 { x, y, z, yaw }
--   LobbyLayout.plateName(i)   "Plate01" …
--   LobbyLayout.plateParts(i)  접시 하나의 파츠 (접시 가운데 기준 로컬 DecorSpec)
--   LobbyLayout.platePartsAt(i, t)  위 파츠를 시각 t 자리로 옮긴 월드 DecorSpec (테스트용)
--   LobbyLayout.allSpecs(t)    시각 t의 로비 파츠 전체 (STRUCTURE + DECOR + 접시)
--   LobbyLayout.PODIUM         우승자 단상 (가운데 단 윗면, 인형 크기·방향, 이름표 높이)
--   LobbyLayout.WINNER_ATTRS   단상 폴더 속성 이름 (서버가 달고 클라이언트가 인형을 세워요)
--   LobbyLayout.CLEAR_ZONES    비워 둘 상자 (스폰, 스폰 → 카운터 통로)
--   LobbyLayout.LIMITS         로비 전체 한계 (원점 반지름, 높이)
--   LobbyLayout.FLOOR          Baseplate 색·재질 (런타임에 바꿔요)
--   LobbyLayout.LIGHTING       조명 프리셋 (서버가 Lighting에 적용)

local MapKitLogic = require(script.Parent.maps.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type Pose = { x: number, y: number, z: number, yaw: number }
export type Box = { name: string, min: Vec3, max: Vec3 }
export type LightSpec = { part: string, color: RGB, range: number, brightness: number }

local P = MapKitLogic.PALETTE

local LobbyLayout = {}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function part(
	list: { DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?,
	transparency: number?
)
	table.insert(list, {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
		transparency = transparency,
	})
end

-- 색 (팔레트에 없는 것만)
local DARK_WOOD = rgb(110, 72, 44)
local FLOOR_WOOD = rgb(176, 128, 82)
local PLASTER = rgb(238, 226, 204)
local SKIN = rgb(246, 210, 170)
local GOLD = rgb(232, 186, 64)
local PLATE_RED = rgb(214, 58, 58)
local PLATE_BLUE = rgb(58, 108, 206)
local SHRIMP = rgb(255, 150, 110)
local WATER = rgb(70, 150, 230)
local SEAWEED = rgb(60, 150, 80)
local LANTERN_LIGHT = rgb(255, 196, 140)

-- ── 한계와 비워 둘 영역 ──────────────────────────────────────────────

LobbyLayout.SPAWN = v(0, 0, 0)

LobbyLayout.LIMITS = {
	radius = 128, -- 원점에서 수평 거리
	height = 60,
}

LobbyLayout.CLEAR_ZONES = {
	-- 스폰 주변 반지름 10 (상자로 감싸요)
	{ name = "Spawn", min = v(-10, 0, -10), max = v(10, 12, 10) },
	-- 스폰 → 카운터 통로 (카운터 앞면 z = -28 바로 앞까지)
	{ name = "Corridor", min = v(-5, 0, -27.5), max = v(5, 12, -10) },
} :: { Box }

LobbyLayout.FLOOR = { color = FLOOR_WOOD, material = "WoodPlanks" }

-- ── 레일 (타원) ──────────────────────────────────────────────────────

local COUNTER_HEIGHT = 3.5
local RAIL_THICKNESS = 0.3
local PLATE_THICKNESS = 0.3

LobbyLayout.COUNTER = {
	center = v(0, 0, -40),
	length = 60, -- 긴 쪽 (X)
	depth = 24, -- 짧은 쪽 (Z)
	height = COUNTER_HEIGHT,
	width = 4, -- 카운터 상판 폭 (가운데 선 기준 바깥·안쪽 2씩)
	segments = 32,
}

LobbyLayout.RAIL = {
	center = v(0, COUNTER_HEIGHT + RAIL_THICKNESS + PLATE_THICKNESS / 2, -40), -- 접시 가운데 높이
	a = 28, -- X 반지름 (카운터 가운데 선)
	b = 10, -- Z 반지름
	speed = 3, -- studs/초
	plateCount = 16,
}

local RAIL = LobbyLayout.RAIL
local ARC_SAMPLES = 720

-- 호 길이 표: arc[k] = θ = 2π(k-1)/N 까지의 길이 (k = 1..N+1)
local arcTable: { number } = { 0 }
do
	local prevX, prevZ = RAIL.a, 0
	for k = 1, ARC_SAMPLES do
		local theta = 2 * math.pi * k / ARC_SAMPLES
		local x, z = RAIL.a * math.cos(theta), RAIL.b * math.sin(theta)
		arcTable[k + 1] = arcTable[k] + math.sqrt((x - prevX) ^ 2 + (z - prevZ) ^ 2)
		prevX, prevZ = x, z
	end
end
local RAIL_LENGTH = arcTable[ARC_SAMPLES + 1]

function LobbyLayout.railLength(): number
	return RAIL_LENGTH
end

function LobbyLayout.period(): number
	return RAIL_LENGTH / RAIL.speed
end

-- 호 길이 s → 타원 매개변수 θ (표에서 이분 탐색 + 선형 보간)
local function thetaAtArc(s: number): number
	s = s % RAIL_LENGTH
	local lo, hi = 1, ARC_SAMPLES + 1
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if arcTable[mid] <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local span = arcTable[hi] - arcTable[lo]
	local f = if span > 0 then (s - arcTable[lo]) / span else 0
	return 2 * math.pi * (lo - 1 + f) / ARC_SAMPLES
end

-- 타원 위 점과 진행 방향. yaw는 CFrame.Angles(0, yaw, 0)의 로컬 -Z가 진행 방향이 되는 값.
local function poseAtTheta(theta: number, center: Vec3): Pose
	local x = center.x + RAIL.a * math.cos(theta)
	local z = center.z + RAIL.b * math.sin(theta)
	local dx, dz = -RAIL.a * math.sin(theta), RAIL.b * math.cos(theta)
	return { x = x, y = center.y, z = z, yaw = math.atan2(-dx, -dz) }
end

function LobbyLayout.pointAtArc(s: number): Pose
	return poseAtTheta(thetaAtArc(s), RAIL.center)
end

function LobbyLayout.plateArc(index: number, t: number): number
	local spacing = RAIL_LENGTH / RAIL.plateCount
	return ((index - 1) * spacing + RAIL.speed * t) % RAIL_LENGTH
end

function LobbyLayout.plateAt(index: number, t: number): Pose
	return LobbyLayout.pointAtArc(LobbyLayout.plateArc(index, t))
end

function LobbyLayout.plateName(index: number): string
	return string.format("Plate%02d", index)
end

-- 접시 색 3가지 × 니기리 4가지 (16개가 골고루 섞이게)
local PLATE_COLORS = {
	{ color = PLATE_RED, material = "SmoothPlastic" },
	{ color = PLATE_BLUE, material = "SmoothPlastic" },
	{ color = GOLD, material = "Foil" },
}
local TOPPINGS = { P.Salmon, P.Tuna, P.Egg, SHRIMP }

function LobbyLayout.plateParts(index: number): { DecorSpec }
	local plate = PLATE_COLORS[(index - 1) % #PLATE_COLORS + 1]
	local topping = TOPPINGS[(index - 1) % #TOPPINGS + 1]
	local list: { DecorSpec } = {}
	-- 원기둥은 X축이 길이라 Z로 90도 돌려 세워요
	part(list, "Plate", "Cylinder", v(PLATE_THICKNESS, 3, 3), plate.color, plate.material, v(0, 0, 0), v(0, 0, 90))
	part(list, "Rice", "Block", v(1.0, 0.6, 1.6), P.Rice, "SmoothPlastic", v(0, 0.45, 0))
	part(list, "Topping", "Block", v(1.15, 0.25, 1.8), topping, "SmoothPlastic", v(0, 0.875, 0))
	if topping == P.Egg then
		part(list, "NoriBand", "Block", v(1.2, 0.95, 0.35), P.Nori, "SmoothPlastic", v(0, 0.6, 0))
	end
	return list
end

-- 접시 파츠를 시각 t 자리로 (로컬 회전은 Z축만 쓰므로 Ry(yaw)·Rz = Angles(0, yaw, z))
function LobbyLayout.platePartsAt(index: number, t: number): { DecorSpec }
	local pose = LobbyLayout.plateAt(index, t)
	local c, s = math.cos(pose.yaw), math.sin(pose.yaw)
	local list: { DecorSpec } = {}
	for _, spec in LobbyLayout.plateParts(index) do
		local o = spec.offset
		local rotation = spec.rotation or v(0, 0, 0)
		local moved = table.clone(spec)
		moved.offset = v(pose.x + o.x * c + o.z * s, pose.y + o.y, pose.z - o.x * s + o.z * c)
		moved.rotation = v(rotation.x, rotation.y + math.deg(pose.yaw), rotation.z)
		table.insert(list, moved)
	end
	return list
end

-- ── 건물 (충돌 있음) ──────────────────────────────────────────────────

local ROOM = 88 -- 안쪽 벽면까지 (모서리 바깥이 반지름 128 안에 들어가게)
local WALL_HEIGHT = 14
local WALL_THICK = 2
local PILLAR_HEIGHT = 16

LobbyLayout.ROOM = ROOM

local STRUCTURE: { DecorSpec } = {}
local DECOR: { DecorSpec } = {}

do
	local wallCenter = ROOM + WALL_THICK / 2
	local span = 2 * (ROOM + WALL_THICK)
	-- 벽 4면
	part(STRUCTURE, "WallNorth", "Block", v(span, WALL_HEIGHT, WALL_THICK), PLASTER, "Plaster", v(0, 7, -wallCenter))
	part(STRUCTURE, "WallSouth", "Block", v(span, WALL_HEIGHT, WALL_THICK), PLASTER, "Plaster", v(0, 7, wallCenter))
	part(STRUCTURE, "WallWest", "Block", v(WALL_THICK, WALL_HEIGHT, span), PLASTER, "Plaster", v(-wallCenter, 7, 0))
	part(STRUCTURE, "WallEast", "Block", v(WALL_THICK, WALL_HEIGHT, span), PLASTER, "Plaster", v(wallCenter, 7, 0))

	-- 기둥: 모서리 4, 남·북 벽 문 옆 4, 동·서 벽 가운데 2
	local pillarSpots = {
		v(-86, 0, -86),
		v(86, 0, -86),
		v(-86, 0, 86),
		v(86, 0, 86),
		v(-10, 0, -86),
		v(10, 0, -86),
		v(-10, 0, 86),
		v(10, 0, 86),
		v(-86, 0, 0),
		v(86, 0, 0),
	}
	for i, spot in pillarSpots do
		part(
			STRUCTURE,
			`Pillar{i}`,
			"Block",
			v(3, PILLAR_HEIGHT, 3),
			DARK_WOOD,
			"Wood",
			v(spot.x, PILLAR_HEIGHT / 2, spot.z)
		)
	end

	-- 카운터와 레일: 타원 가운데 선을 호 길이로 똑같이 나눈 마디
	local counter = LobbyLayout.COUNTER
	local n = counter.segments
	for k = 0, n - 1 do
		local p0 = LobbyLayout.pointAtArc(k * RAIL_LENGTH / n)
		local p1 = LobbyLayout.pointAtArc((k + 1) * RAIL_LENGTH / n)
		local dx, dz = p1.x - p0.x, p1.z - p0.z
		local length = math.sqrt(dx * dx + dz * dz) + 0.6 -- 마디 사이 틈이 안 보이게 조금 겹쳐요
		local yawDeg = math.deg(math.atan2(-dx, -dz))
		local mx, mz = (p0.x + p1.x) / 2, (p0.z + p1.z) / 2
		part(
			STRUCTURE,
			`Counter{k + 1}`,
			"Block",
			v(counter.width, COUNTER_HEIGHT, length),
			P.Wood,
			"Wood",
			v(mx, COUNTER_HEIGHT / 2, mz),
			v(0, yawDeg, 0)
		)
		part(
			STRUCTURE,
			`Rail{k + 1}`,
			"Block",
			v(2.8, RAIL_THICKNESS, length),
			P.Iron,
			"Metal",
			v(mx, COUNTER_HEIGHT + RAIL_THICKNESS / 2, mz),
			v(0, yawDeg, 0)
		)
	end
end

-- ── 우승자 단상 (충돌 있음) ────────────────────────────────────────────

LobbyLayout.PODIUM = {
	center = v(30, 0, 0), -- 가운데 단 바닥 가운데 (스폰 오른쪽 +X 30)
	topY = 5, -- 가운데 단 윗면 높이
	scale = 1.5, -- 인형 크기
	facingYawDeg = 90, -- 인형 앞(-Z)이 스폰 쪽(-X)을 보게
	labelHeight = 15, -- 이름표(BillboardGui) 높이. 아래 끝(12.75)이 인형 머리(12.05) 위라 줄이 가리지 않아요 (m4-06 QA L1)
	emptyText = "다음 우승자는 누구?",
}

-- 서버가 Workspace.Lobby.Podium 폴더에 다는 우승자 속성 (클라이언트가 이걸 보고 인형을 세워요).
-- serial은 우승 발표마다 1씩 늘어요 (같은 사람이 또 이겨도 다시 세우게).
LobbyLayout.WINNER_ATTRS = {
	userId = "WinnerUserId",
	appearanceId = "WinnerAppearanceId",
	serial = "WinnerSerial",
}

do
	local c = LobbyLayout.PODIUM.center
	local steps = {
		{ name = "PodiumFirst", height = 5, z = 0 },
		{ name = "PodiumSecond", height = 3, z = 8 },
		{ name = "PodiumThird", height = 2, z = -8 },
	}
	for _, step in steps do
		part(
			STRUCTURE,
			step.name,
			"Block",
			v(8, step.height, 8),
			P.Lacquer,
			"SmoothPlastic",
			v(c.x, step.height / 2, step.z)
		)
		-- 금색 테두리: 윗면 둘레 띠 (장식)
		part(
			DECOR,
			`{step.name}TrimFront`,
			"Block",
			v(0.3, 0.5, 8.2),
			GOLD,
			"Foil",
			v(c.x - 4.1, step.height - 0.25, step.z)
		)
		part(
			DECOR,
			`{step.name}TrimBack`,
			"Block",
			v(0.3, 0.5, 8.2),
			GOLD,
			"Foil",
			v(c.x + 4.1, step.height - 0.25, step.z)
		)
		part(DECOR, `{step.name}TrimTop`, "Block", v(7.6, 0.1, 7.6), GOLD, "Foil", v(c.x, step.height + 0.05, step.z))
	end
end

-- ── 장식 (충돌 없음) ──────────────────────────────────────────────────

LobbyLayout.LIGHTS = {} :: { LightSpec }

do
	-- 들보: 기둥 위를 잇는 나무 (Z 방향 3개, X 방향 2개)
	local beamY = PILLAR_HEIGHT + 0.75
	for i, x in { -44, 0, 44 } do
		part(DECOR, `BeamZ{i}`, "Block", v(2, 1.5, 2 * ROOM), DARK_WOOD, "Wood", v(x, beamY, 0))
	end
	for i, z in { -44, 44 } do
		part(DECOR, `BeamX{i}`, "Block", v(2 * ROOM, 1.5, 2), DARK_WOOD, "Wood", v(0, beamY + 1.5, z))
	end

	-- 벽 아래 걸레받이와 위쪽 옻칠 띠
	local edge = ROOM - 0.2
	local trims = {
		{ "North", v(2 * ROOM, 1, 0.4), v(0, 0.5, -edge), v(0, 12.5, -edge) },
		{ "South", v(2 * ROOM, 1, 0.4), v(0, 0.5, edge), v(0, 12.5, edge) },
		{ "West", v(0.4, 1, 2 * ROOM), v(-edge, 0.5, 0), v(-edge, 12.5, 0) },
		{ "East", v(0.4, 1, 2 * ROOM), v(edge, 0.5, 0), v(edge, 12.5, 0) },
	}
	for _, trim in trims do
		local name, size, low, high = trim[1] :: string, trim[2] :: Vec3, trim[3] :: Vec3, trim[4] :: Vec3
		part(DECOR, `Baseboard{name}`, "Block", size, DARK_WOOD, "Wood", low)
		part(DECOR, `Stripe{name}`, "Block", size, P.Lacquer, "SmoothPlastic", high)
	end

	-- 종이 등 8개 (들보에 매달림, PointLight 8)
	local n = 0
	for _, x in { -44, 44 } do
		for _, z in { -64, -20, 20, 64 } do
			n += 1
			part(DECOR, `LanternCord{n}`, "Block", v(0.15, 2.6, 0.15), P.Nori, "SmoothPlastic", v(x, 15.4, z))
			part(DECOR, `Lantern{n}`, "Ball", v(2.6, 2.6, 2.6), P.Lacquer, "Neon", v(x, 12.9, z), nil, 0.1)
			part(
				DECOR,
				`LanternCap{n}`,
				"Cylinder",
				v(0.5, 1.4, 1.4),
				P.Nori,
				"SmoothPlastic",
				v(x, 14.2, z),
				v(0, 0, 90)
			)
			table.insert(LobbyLayout.LIGHTS, {
				part = `Lantern{n}`,
				color = LANTERN_LIGHT,
				range = 22,
				brightness = 1.4,
			})
		end
	end

	-- 메뉴판 4장 (뒤쪽 북쪽 벽), 판마다 초밥 그림 3칸
	local menuZ = -ROOM + 0.3
	for i, x in { -56, -32, 32, 56 } do
		part(DECOR, `Menu{i}`, "Block", v(12, 5, 0.4), DARK_WOOD, "WoodPlanks", v(x, 9, menuZ))
		for j, color in { P.Salmon, P.Tuna, P.Egg } do
			part(
				DECOR,
				`Menu{i}Item{j}`,
				"Block",
				v(2.6, 2.6, 0.2),
				color,
				"SmoothPlastic",
				v(x - 7.5 + j * 3.75, 9, menuZ + 0.3)
			)
		end
	end

	-- 노렌: 주방 문(북쪽 벽 가운데, 남색)과 입구(남쪽 벽 가운데, 빨강)
	local function noren(prefix: string, z: number, facing: number, color: RGB)
		part(DECOR, `{prefix}Door`, "Block", v(10, 11, 0.3), DARK_WOOD, "Wood", v(0, 5.5, z))
		part(DECOR, `{prefix}Rod`, "Cylinder", v(12, 0.4, 0.4), DARK_WOOD, "Wood", v(0, 11.2, z + facing * 0.6))
		for k = 1, 4 do
			part(
				DECOR,
				`{prefix}Noren{k}`,
				"Block",
				v(2.3, 4.5, 0.15),
				color,
				"Fabric",
				v(-3.75 + (k - 1) * 2.5, 8.8, z + facing * 0.7)
			)
		end
	end
	noren("Kitchen", -ROOM + 0.2, 1, P.Noren)
	noren("Entrance", ROOM - 0.2, -1, P.Lacquer)

	-- 셰프 (카운터 안쪽, 스폰 쪽 +Z를 봐요)
	local cx, cz = 0, -43
	part(DECOR, "ChefLegLeft", "Block", v(0.9, 2.2, 0.9), P.Nori, "SmoothPlastic", v(cx - 0.6, 1.1, cz))
	part(DECOR, "ChefLegRight", "Block", v(0.9, 2.2, 0.9), P.Nori, "SmoothPlastic", v(cx + 0.6, 1.1, cz))
	part(DECOR, "ChefBody", "Block", v(2.6, 2.8, 1.4), P.Rice, "SmoothPlastic", v(cx, 3.6, cz))
	part(DECOR, "ChefApron", "Block", v(2.0, 2.0, 0.1), P.Noren, "Fabric", v(cx, 3.2, cz + 0.75))
	part(DECOR, "ChefArmLeft", "Block", v(0.8, 2.4, 0.8), P.Rice, "SmoothPlastic", v(cx - 1.7, 3.7, cz + 0.3))
	part(DECOR, "ChefArmRight", "Block", v(0.8, 2.4, 0.8), P.Rice, "SmoothPlastic", v(cx + 1.7, 3.7, cz + 0.3))
	part(DECOR, "ChefHead", "Block", v(1.8, 1.8, 1.6), SKIN, "SmoothPlastic", v(cx, 5.9, cz))
	part(DECOR, "ChefEyeLeft", "Block", v(0.25, 0.35, 0.1), P.Nori, "SmoothPlastic", v(cx - 0.4, 6.1, cz + 0.82))
	part(DECOR, "ChefEyeRight", "Block", v(0.25, 0.35, 0.1), P.Nori, "SmoothPlastic", v(cx + 0.4, 6.1, cz + 0.82))
	part(DECOR, "ChefHatBand", "Cylinder", v(0.5, 2.0, 2.0), P.Rice, "SmoothPlastic", v(cx, 7.05, cz), v(0, 0, 90))
	part(DECOR, "ChefHat", "Ball", v(2.6, 2.0, 2.6), P.Rice, "SmoothPlastic", v(cx, 7.9, cz))
	part(DECOR, "CuttingBoard", "Block", v(5, 0.4, 2), P.Wood, "Wood", v(cx, 3.0, cz + 4))
	part(DECOR, "CuttingTable", "Block", v(5.4, 2.8, 2.2), DARK_WOOD, "Wood", v(cx, 1.4, cz + 4))

	-- 의자: 카운터 둘레 바깥 (통로 앞 하나는 비워요)
	local stool = 0
	for k = 0, 15 do
		local theta = k * 2 * math.pi / 16
		local x = 33 * math.cos(theta)
		local z = -40 + 15 * math.sin(theta)
		if not (math.abs(x) < 8 and z > -40) then
			stool += 1
			part(DECOR, `StoolLeg{stool}`, "Cylinder", v(2.3, 0.6, 0.6), DARK_WOOD, "Wood", v(x, 1.15, z), v(0, 0, 90))
			part(
				DECOR,
				`StoolSeat{stool}`,
				"Cylinder",
				v(0.5, 2.4, 2.4),
				P.Lacquer,
				"SmoothPlastic",
				v(x, 2.55, z),
				v(0, 0, 90)
			)
		end
	end

	-- 수조 (입구 왼쪽): 나무 받침 + 반투명 물 + 물고기·수초
	local ax, az = -34, 76
	part(DECOR, "TankStand", "Block", v(16, 2.5, 7), DARK_WOOD, "Wood", v(ax, 1.25, az))
	part(DECOR, "TankWater", "Block", v(15, 6, 6), WATER, "Glass", v(ax, 5.5, az), nil, 0.55)
	part(DECOR, "TankRim", "Block", v(15.6, 0.4, 6.6), DARK_WOOD, "Wood", v(ax, 8.7, az))
	local fishes = {
		{ v(ax - 4, 5, az - 1), P.Salmon },
		{ v(ax + 1, 6.5, az + 1), P.Egg },
		{ v(ax + 5, 4.5, az), P.Tuna },
		{ v(ax - 1, 4, az + 1.5), P.Salmon },
	}
	for i, fish in fishes do
		local at, color = fish[1] :: Vec3, fish[2] :: RGB
		part(DECOR, `Fish{i}`, "Ball", v(1.6, 0.9, 0.7), color, "SmoothPlastic", at)
		part(
			DECOR,
			`FishTail{i}`,
			"Wedge",
			v(0.2, 0.8, 0.6),
			color,
			"SmoothPlastic",
			v(at.x + 1.0, at.y, at.z),
			v(0, 90, 0)
		)
	end
	for i, x in { ax - 6, ax - 2.5, ax + 3, ax + 6.5 } do
		part(
			DECOR,
			`Seaweed{i}`,
			"Block",
			v(0.4, 3 + (i % 2), 0.4),
			SEAWEED,
			"SmoothPlastic",
			v(x, 4 + (i % 2) / 2, az - 1.5)
		)
	end
end

LobbyLayout.STRUCTURE = STRUCTURE
LobbyLayout.DECOR = DECOR

-- 시각 t의 로비 파츠 전체 (테스트: 예산·영역 확인)
function LobbyLayout.allSpecs(t: number): { DecorSpec }
	local list = table.clone(STRUCTURE)
	for _, spec in DECOR do
		table.insert(list, spec)
	end
	for i = 1, RAIL.plateCount do
		for _, spec in LobbyLayout.platePartsAt(i, t) do
			table.insert(list, spec)
		end
	end
	return list
end

-- ── 조명 ─────────────────────────────────────────────────────────────
-- Technology는 건드리지 않아요 (Studio 설정). 한 플레이스 모드라 아레나에도 같이 적용돼요.

LobbyLayout.LIGHTING = {
	ClockTime = 14,
	Brightness = 2.2,
	Ambient = rgb(112, 94, 80),
	OutdoorAmbient = rgb(150, 130, 110),
	Atmosphere = {
		Density = 0.22, -- 0.3 이하: 먼 아레나를 보는 관전 화면이 뿌옇지 않게
		Offset = 0.1,
		Color = rgb(255, 228, 198),
		Decay = rgb(150, 118, 96),
		Glare = 0,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.06,
		Saturation = 0.05,
		TintColor = rgb(255, 246, 234),
	},
	Bloom = {
		Intensity = 0.35,
		Size = 24,
		Threshold = 1.4,
	},
}

return LobbyLayout
