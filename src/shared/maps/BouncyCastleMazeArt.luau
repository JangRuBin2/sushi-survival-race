--!strict
-- "방방 미로" 아트 (m5-14): 장식·소개 카메라·색을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   BouncyCastleMazeArt.COLORS          판정 파츠(바닥·BounceFloor·벽·칸막이·관문·결승)에 칠할 색 { r, g, b }
--   BouncyCastleMazeArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   BouncyCastleMazeArt.introCamera()   소개 경유점 (입구 → 1번 레인 위에서 내려다보기 → 꺾이는 지점 → 결승 문)
-- 알록달록한 원색 파스텔 유원지 방방 미로 느낌: 체크무늬 바닥, 통통 튀는 비닐 느낌의 벽·칸막이·관문,
-- 테두리 공기 주입구·풍선·깃발, 색색의 조명. 코스 치수는 전부 BouncyCastleMazeLayout에서 읽어요
-- (판정 수치는 그쪽이 정해요. 장식은 충돌·쿼리·터치가 없어서 코스 판정에 영향을 주지 않아요).

local Layout = require(script.Parent.BouncyCastleMazeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local P = MapKitLogic.PALETTE

local BouncyCastleMazeArt = {}

-- 판정 파츠 색 (크기·위치·충돌은 BouncyCastleMaze가 그대로 둬요).
BouncyCastleMazeArt.COLORS = {
	floor = { r = 250, g = 240, b = 225 }, -- A·D·E 일반 바닥 (따뜻한 베이지)
	bounceFloor = { r = 255, g = 205, b = 130 }, -- B·C BounceFloor (말랑한 주황 매트)
	wall = { r = 255, g = 120, b = 156 }, -- 바깥 벽 (분홍 비닐)
	gate = { r = 255, g = 92, b = 92 }, -- 입구 문 (경고 빨강)
	partition1 = { r = 100, g = 176, b = 255 }, -- 1·2레인 칸막이 (파랑)
	partition2 = { r = 132, g = 220, b = 120 }, -- 2·3레인 칸막이 (초록)
	partition3 = { r = 206, g = 142, b = 255 }, -- 3·4레인 칸막이 (보라)
	spawn = { r = 246, g = 196, b = 70 },
	finish = { r = 255, g = 196, b = 40 },
} :: { [string]: RGB }

-- 칸막이 x 위치 순서(Layout.PARTITIONS와 같은 순서)와 1:1인 색 이름
BouncyCastleMazeArt.PARTITION_COLOR_KEYS = { "partition1", "partition2", "partition3" }

-- m5-14 파티클·조명 이름 상수
BouncyCastleMazeArt.LAMP = "CarnivalLamp"

local HALF = Layout.HALF_WIDTH
-- m5-24: 성이 서 있는 잔디밭 높이 (낙하선 -40보다 16 아래 — 떨어지는 사람이 땅을 뚫고 지나가 보이지 않게)
local GROUND = -Layout.FALL_DEPTH - 16
local LAMP_TOP = 20
local UP: Vec3 = { x = 0, y = 0, z = 90 } -- Cylinder 축(X)을 세워요
local WHITE = P.Rice
local STRIPE_RED = { r = 220, g = 50, b = 60 }
local BALLOON_COLORS = {
	{ r = 255, g = 120, b = 140 },
	{ r = 120, g = 200, b = 255 },
	{ r = 255, g = 214, b = 110 },
	{ r = 150, g = 230, b = 140 },
}
-- 색색의 조명(아래 addLamps에서 사용, build가 CarnivalLamp 파츠마다 PointLight를 붙여요)
BouncyCastleMazeArt.LAMP_COLORS = {
	{ r = 255, g = 120, b = 140 },
	{ r = 120, g = 200, b = 255 },
	{ r = 255, g = 214, b = 110 },
	{ r = 150, g = 230, b = 140 },
	{ r = 220, g = 140, b = 255 },
}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function part(
	list: { DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
)
	table.insert(list, {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	})
end

-- 세운 원기둥 (높이 h, 지름 d, 바닥 y)
local function disc(
	list: { DecorSpec },
	name: string,
	h: number,
	d: number,
	color: RGB,
	material: string,
	x: number,
	y: number,
	z: number
)
	part(list, name, "Cylinder", v(h, d, d), color, material, v(x, y + h / 2, z), UP)
end

-- 체크무늬 바닥 패턴: B·C 구간(BounceFloor) 위에 얇은 판, 판정 바닥과 분리된 장식 레이어.
local function addFloorChecker(list: { DecorSpec })
	local tile = 5
	local startZ = Layout.ANTEROOM.front -- -16
	local depth = startZ - Layout.MAZE.back -- 94
	local rows = math.floor(depth / tile)
	local cols = math.floor(Layout.WIDTH / tile)
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local color = if (row + col) % 2 == 0 then BouncyCastleMazeArt.COLORS.bounceFloor else WHITE
			part(
				list,
				"FloorChecker",
				"Block",
				v(tile - 0.3, 0.06, tile - 0.3),
				color,
				"SmoothPlastic",
				v(-HALF + tile / 2 + col * tile, 0.08, startZ - tile / 2 - row * tile)
			)
		end
	end
end

-- 입구 문 경고 줄무늬 (관문 위, 빨강-흰 사선 느낌의 블록들). 1번 레인이 벽에 붙어 있으면(왼쪽 폭 0)
-- 그쪽은 건너뛰고, 막힌 폭(보통 오른쪽)에만 줄무늬를 그려요.
local function addGateStripes(list: { DecorSpec })
	local gate = Layout.GATE
	local y = Layout.WALL_HEIGHT * 0.85
	local function stripeBlock(xMin: number, xMax: number)
		local blockWidth = xMax - xMin
		if blockWidth <= 0 then
			return
		end
		local centerX = (xMin + xMax) / 2
		local count = 4
		for i = 0, count - 1 do
			local color = if i % 2 == 0 then STRIPE_RED else WHITE
			part(
				list,
				"GateStripe",
				"Block",
				v(blockWidth / count, 1.4, 0.3),
				color,
				"SmoothPlastic",
				v(centerX - blockWidth / 2 + (i + 0.5) * (blockWidth / count), y, gate.z)
			)
		end
	end
	stripeBlock(Layout.BOUNDS.xMin, gate.openXMin)
	stripeBlock(gate.openXMax, Layout.BOUNDS.xMax)
end

-- 칸막이·벽 위 둥근 풍선 장식 (통통 튀는 느낌)
local function addBalloons(list: { DecorSpec })
	local y = Layout.WALL_HEIGHT + 1.4
	local count = 0
	for _, partition in Layout.PARTITIONS do
		for _, z in
			{ partition.blockedZHigh, (partition.blockedZHigh + partition.blockedZLow) / 2, partition.blockedZLow }
		do
			count += 1
			local color = BALLOON_COLORS[(count - 1) % #BALLOON_COLORS + 1]
			part(list, "PartitionBalloon", "Ball", v(1.8, 1.8, 1.8), color, "SmoothPlastic", v(partition.x, y, z))
		end
	end
	for _, side in { -1, 1 } do
		for i, z in { Layout.ANTEROOM.front, -45, -90, Layout.MAZE.back } do
			count += 1
			local color = BALLOON_COLORS[(count + i) % #BALLOON_COLORS + 1]
			part(list, "WallBalloon", "Ball", v(1.6, 1.6, 1.6), color, "SmoothPlastic", v(side * (HALF + 1), y, z))
		end
	end
end

-- 바깥 벽 위 삼각 깃발 줄 (Wedge 사용)
local function addFlags(list: { DecorSpec })
	local y = Layout.WALL_HEIGHT + 0.8
	local spacing = 12
	local colors = BALLOON_COLORS
	for _, side in { -1, 1 } do
		local z = Layout.START.front - 4
		local i = 0
		while z > Layout.FINISH.back + 4 do
			local color = colors[(i % #colors) + 1]
			part(
				list,
				"WallFlag",
				"Wedge",
				v(1.4, 1.6, 1),
				color,
				"Fabric",
				v(side * (HALF + 0.6), y, z),
				v(0, if side > 0 then 90 else -90, 0)
			)
			z -= spacing
			i += 1
		end
	end
end

-- 테두리 공기 주입구 (바운스 구간 바깥쪽 벽에 붙은 둥근 통풍구)
local function addAirVents(list: { DecorSpec })
	local y = 3
	for _, side in { -1, 1 } do
		for _, z in { Layout.ANTEROOM.front - 2, -65, Layout.MAZE.back + 2 } do
			disc(list, "AirVent", 1.2, 3, { r = 230, g = 230, b = 236 }, "Metal", side * (HALF - 0.6), y, z)
			disc(list, "AirVentRim", 0.3, 3.4, { r = 150, g = 150, b = 160 }, "Metal", side * (HALF - 0.6), y + 0.75, z)
		end
	end
end

-- 색색의 유원지 조명 기둥 (예산 12개 안에서 여러 색)
local function addLamps(list: { DecorSpec })
	local positions = { Layout.START.front - 6, -18, -55, -95, Layout.EXIT.front - 4, Layout.FINISH_LINE_Z - 4 }
	for i, z in positions do
		-- m5-24: 레인 안(밟는 곳)에 서 있던 기둥을 성 바깥 땅으로 옮겼어요 (등 개수·이름·조명은 그대로)
		local x = if i % 2 == 0 then -(HALF + 8) else (HALF + 8)
		local color = BouncyCastleMazeArt.LAMP_COLORS[(i - 1) % #BouncyCastleMazeArt.LAMP_COLORS + 1]
		local postHeight = LAMP_TOP - GROUND
		disc(list, "LampPost", postHeight, 0.9, { r = 236, g = 236, b = 242 }, "Metal", x, GROUND, z)
		part(list, "LampPostBand", "Cylinder", v(1.4, 1.6, 1.6), color, "SmoothPlastic", v(x, LAMP_TOP - 2, z), UP)
		part(list, BouncyCastleMazeArt.LAMP, "Ball", v(2.2, 2.2, 2.2), color, "Neon", v(x, LAMP_TOP + 1.1, z))
	end
end

-- 결승 체크무늬 (결승선 위에 얇게)
local function addFinishChecker(list: { DecorSpec })
	local lineZ = Layout.finishLineZ()
	local y = 0.45
	local cols = Layout.WIDTH
	for row = 0, 1 do
		for col = 0, cols - 1 do
			local color = if (row + col) % 2 == 0 then WHITE else STRIPE_RED
			part(
				list,
				"FinishChecker",
				"Block",
				v(1, 0.05, 0.5),
				color,
				"SmoothPlastic",
				v(-HALF + 0.5 + col, y, lineZ + 0.25 - row * 0.5)
			)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- m5-24 아트 패스 v2: "맑은 한낮 가게 옆 유원지"
-- 층: FG 칸막이·벽 윗면 흰 파이핑, 바깥 벽을 덮는 공기 기둥 / MG 모서리 탑·입구 아치·결승 아치·송풍기·풍선
-- 다발 / BG 잔디밭(낙하선 16 아래)·대관람차·회전목마·서커스 텐트·나무·옆 초밥집 건물.
-- 판정 파츠(바닥·벽·칸막이·관문·결승선)는 하나도 안 바꿔요. 장식은 전부 충돌·쿼리·터치 없음.
----------------------------------------------------------------------------------------------------

BouncyCastleMazeArt.BUDGET = "Extended"

-- 맑은 한낮 (로비 14시 따뜻한 실내 톤과 달리 차갑고 파란 하늘, 채도 +0.15)
BouncyCastleMazeArt.LIGHTING = {
	ClockTime = 13,
	Brightness = 2.6,
	Ambient = { r = 128, g = 132, b = 146 },
	OutdoorAmbient = { r = 150, g = 162, b = 186 },
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.6,
	Atmosphere = {
		Density = 0.2,
		Offset = 0.05,
		Color = { r = 196, g = 222, b = 248 },
		Decay = { r = 140, g = 176, b = 220 },
		Glare = 0.1,
		Haze = 0.8,
	},
	ColorCorrection = {
		Brightness = 0.03,
		Contrast = 0.08,
		Saturation = 0.15,
		TintColor = { r = 255, g = 252, b = 246 },
	},
	Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.3 },
	SunRays = { Intensity = 0.05, Spread = 0.5 },
} :: MapLighting.LightingPreset

-- 원색 4색 + 흰 파이핑 (판정 벽 분홍·칸막이 파랑/초록/보라와 겹치지 않는 진한 원색)
local RED = { r = 226, g = 58, b = 66 }
local YELLOW = { r = 255, g = 204, b = 58 }
local BLUE = { r = 58, g = 128, b = 226 }
local GREEN = { r = 76, g = 182, b = 92 }
local PIPING = { r = 252, g = 252, b = 248 }
local GOLD = { r = 246, g = 190, b = 52 }
local GRASS = { r = 112, g = 186, b = 92 }
local PATH = { r = 230, g = 214, b = 176 }
local TRUNK = { r = 128, g = 92, b = 62 }

type Extra = {
	reflectance: number?,
	transparency: number?,
	castShadow: boolean?,
	light: MapKitLogic.LightSpec?,
	particle: string?,
	particleRate: number?,
	anim: MapKitLogic.AnimSpec?,
}

local function add(
	list: { DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?,
	extra: Extra?
)
	local s: DecorSpec = {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
	if extra then
		s.reflectance = extra.reflectance
		s.transparency = extra.transparency
		s.castShadow = extra.castShadow
		s.light = extra.light
		s.particle = extra.particle
		s.particleRate = extra.particleRate
		s.anim = extra.anim
	end
	table.insert(list, s)
end

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
end

-- 세운 원기둥 (바닥 y0부터 높이 h)
local function column(
	list: { DecorSpec },
	name: string,
	x: number,
	y0: number,
	z: number,
	h: number,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	add(list, name, "Cylinder", v(h, d, d), color, material, v(x, y0 + h / 2, z), UP, extra)
end

-- 원뿔 지붕: 원기둥을 점점 좁게 쌓아요 (줄무늬 색 번갈아)
local function cone(
	list: { DecorSpec },
	name: string,
	x: number,
	y0: number,
	z: number,
	baseD: number,
	height: number,
	steps: number,
	colors: { RGB }
)
	local h = height / steps
	for i = 0, steps - 1 do
		local d = baseD * (1 - i / steps) + 0.6
		column(list, name, x, y0 + i * h, z, h, d, colors[i % #colors + 1], "SmoothPlastic")
	end
end

-- 잔디밭 + 산책길 + 잔디 무늬 (배경 바닥)
local function addPark(list: { DecorSpec })
	add(list, "ParkGrass", "Block", v(1500, 2, 1500), GRASS, "Grass", v(0, GROUND - 1, -70))
	local shades = MapKitLogic.shades(GRASS)
	local area = { center = v(0, GROUND + 0.06, -70), size = v(700, 0, 700) }
	append(
		list,
		MapKitShapes.scatter(2414, 16, area, function(i, pos, rng)
			local d = rng:range(50, 130)
			local c = if i % 3 == 0
				then shades.light
				elseif i % 3 == 1 then shades.dark
				else MapKitLogic.mix(GRASS, YELLOW, 0.15)
			local patch: DecorSpec = {
				name = "GrassPatch",
				shape = "Cylinder",
				size = v(0.1, d, d),
				color = c,
				material = "Grass",
				offset = pos,
				rotation = UP,
			}
			return { patch }
		end)
	)
	-- 성을 두르는 모래색 산책길 (ㅁ자) + 입구 쪽 길
	local pathY = GROUND + 0.1
	for _, side in { -1, 1 } do
		add(list, "ParkPath", "Block", v(14, 0.2, 260), PATH, "Pavement", v(side * 52, pathY, -70))
		for _, edge in { -1, 1 } do
			add(
				list,
				"PathCurb",
				"Block",
				v(0.8, 0.6, 260),
				MapKitLogic.shade(PATH, 0.8),
				"Concrete",
				v(side * 52 + edge * 7.2, GROUND + 0.3, -70)
			)
		end
	end
	add(list, "ParkPath", "Block", v(118, 0.2, 14), PATH, "Pavement", v(0, pathY, 40))
	add(list, "ParkPath", "Block", v(118, 0.2, 14), PATH, "Pavement", v(0, pathY, -180))
	add(list, "ParkPath", "Block", v(14, 0.2, 300), PATH, "Pavement", v(0, pathY, 196))
end

-- 성 몸통: 바닥 아래 받침 + 바깥 벽을 덮는 공기 기둥(빨강·노랑 번갈아) + 바닥 둘레 파란 공기 띠
local function addCastleBody(list: { DecorSpec })
	local length = Layout.totalLength()
	local midZ = Layout.START.front - length / 2
	local bodyTop = -2.2 -- 판정 바닥 아랫면(-2)보다 조금 아래
	add(
		list,
		"CastleBase",
		"Block",
		v(Layout.WIDTH + 1, bodyTop - GROUND, length + 1),
		MapKitLogic.shade(RED, 0.7),
		"SmoothPlastic",
		v(0, (bodyTop + GROUND) / 2, midZ)
	)
	local tubeD = 3.6
	local tubeTop = Layout.WALL_HEIGHT - 1
	local outer = HALF + 0.5 + tubeD / 2 - 0.1
	local shine: Extra = { reflectance = 0.08 }
	local i = 0
	local z = Layout.START.front - 2
	while z > Layout.FINISH.back + 1 do
		local color = if i % 2 == 0 then RED else YELLOW
		for _, side in { -1, 1 } do
			column(list, "AirTube", side * outer, GROUND, z, tubeTop - GROUND, tubeD, color, "SmoothPlastic", shine)
			add(
				list,
				"AirTubeCap",
				"Ball",
				v(tubeD, tubeD, tubeD),
				color,
				"SmoothPlastic",
				v(side * outer, tubeTop, z),
				nil,
				shine
			)
		end
		z -= 4
		i += 1
	end
	-- 앞·뒤 벽 바깥 공기 기둥
	for _, endZ in { Layout.START.front + 0.5 + tubeD / 2 - 0.1, Layout.FINISH.back - 0.5 - tubeD / 2 + 0.1 } do
		local k = 0
		local x = -HALF + 2
		while x < HALF do
			local color = if k % 2 == 0 then YELLOW else RED
			column(list, "AirTube", x, GROUND, endZ, tubeTop - GROUND, tubeD, color, "SmoothPlastic", shine)
			add(
				list,
				"AirTubeCap",
				"Ball",
				v(tubeD, tubeD, tubeD),
				color,
				"SmoothPlastic",
				v(x, tubeTop, endZ),
				nil,
				shine
			)
			x += 4
			k += 1
		end
	end
	-- 바닥 둘레 파란 공기 띠 (캡슐 4개)
	local skirtY = GROUND + 2.6
	local sx = HALF + 4.6
	local alongZ = v(0, 90, 0)
	append(
		list,
		MapKitShapes.capsule("AirSkirt", length + 10, 5.2, BLUE, "SmoothPlastic", v(-sx, skirtY, midZ), alongZ)
	)
	append(list, MapKitShapes.capsule("AirSkirt", length + 10, 5.2, BLUE, "SmoothPlastic", v(sx, skirtY, midZ), alongZ))
	append(
		list,
		MapKitShapes.capsule(
			"AirSkirt",
			Layout.WIDTH + 10,
			5.2,
			BLUE,
			"SmoothPlastic",
			v(0, skirtY, Layout.START.front + 4.6)
		)
	)
	append(
		list,
		MapKitShapes.capsule(
			"AirSkirt",
			Layout.WIDTH + 10,
			5.2,
			BLUE,
			"SmoothPlastic",
			v(0, skirtY, Layout.FINISH.back - 4.6)
		)
	)
end

-- 칸막이·벽·관문 윗면 흰 파이핑 (둥근 테두리 — 판정 칸막이는 그대로, 그 위에 얹는 장식)
local function addPiping(list: { DecorSpec })
	local y = Layout.WALL_HEIGHT + 0.35
	local length = Layout.totalLength()
	local midZ = Layout.START.front - length / 2
	for _, side in { -1, 1 } do
		add(
			list,
			"WallPiping",
			"Cylinder",
			v(length + 1, 1.1, 1.1),
			PIPING,
			"SmoothPlastic",
			v(side * (HALF + 0.25), y, midZ),
			v(0, 90, 0)
		)
	end
	for _, endZ in { Layout.START.front + 0.25, Layout.FINISH.back - 0.25 } do
		add(list, "WallPiping", "Cylinder", v(Layout.WIDTH + 1.5, 1.1, 1.1), PIPING, "SmoothPlastic", v(0, y, endZ))
	end
	for _, partition in Layout.PARTITIONS do
		local depth = partition.blockedZHigh - partition.blockedZLow
		local mid = (partition.blockedZHigh + partition.blockedZLow) / 2
		append(
			list,
			MapKitShapes.capsule(
				"PartitionPiping",
				depth,
				1.3,
				PIPING,
				"SmoothPlastic",
				v(partition.x, y, mid),
				v(0, 90, 0)
			)
		)
	end
	local gate = Layout.GATE
	local gx0, gx1 = gate.openXMax, Layout.BOUNDS.xMax
	append(
		list,
		MapKitShapes.capsule("GatePiping", gx1 - gx0, 1.6, YELLOW, "SmoothPlastic", v((gx0 + gx1) / 2, y + 0.1, gate.z))
	)
end

-- 탑: 공기 원기둥(색 띠 3단) + 성가퀴 + 원뿔 지붕 + 깃발(Sway)
local function addTurret(
	list: { DecorSpec },
	x: number,
	z: number,
	d: number,
	top: number,
	roofColors: { RGB },
	flag: RGB
)
	local bandH = (top - GROUND) / 3
	for k = 0, 2 do
		local color = if k % 2 == 0 then RED else YELLOW
		column(list, "Turret", x, GROUND + k * bandH, z, bandH, d, color, "SmoothPlastic", { reflectance = 0.06 })
	end
	append(list, MapKitShapes.ring("TurretRim", d / 2 + 0.2, 1.4, 1.6, 10, PIPING, "SmoothPlastic", v(x, top + 0.8, z)))
	for k = 0, 7 do
		local a = math.rad(k * 45)
		add(
			list,
			"TurretMerlon",
			"Block",
			v(1.8, 2, 1.4),
			BLUE,
			"SmoothPlastic",
			v(x + math.cos(a) * d / 2, top + 2.4, z + math.sin(a) * d / 2),
			v(0, -k * 45, 0)
		)
	end
	cone(list, "TurretRoof", x, top + 1.6, z, d + 1.2, d * 1.3, 6, roofColors)
	local roofTop = top + 1.6 + d * 1.3
	column(list, "TurretFlagPole", x, roofTop, z, 6, 0.4, PIPING, "Metal")
	add(list, "TurretFlag", "Wedge", v(0.3, 2.4, 3.4), flag, "Fabric", v(x, roofTop + 4.6, z - 1.7), nil, {
		anim = { kind = "Sway", period = 2.6 + (math.abs(x) % 3) * 0.3, amount = 10, axis = "Y" },
	})
	-- 탑 둥근 창 (어두운 원판, 코스 바깥쪽)
	local face = if x < 0 then -1 else 1
	add(
		list,
		"TurretWindow",
		"Cylinder",
		v(0.3, d * 0.35, d * 0.35),
		MapKitLogic.shade(BLUE, 0.5),
		"SmoothPlastic",
		v(x + face * d / 2, top - bandH * 0.5, z)
	)
end

local function addTurrets(list: { DecorSpec })
	local roofA = { BLUE, PIPING }
	local roofB = { GREEN, PIPING }
	addTurret(list, -(HALF + 5), Layout.START.front + 5, 12, 24, roofA, YELLOW)
	addTurret(list, HALF + 5, Layout.START.front + 5, 12, 24, roofB, RED)
	addTurret(list, -(HALF + 5), Layout.FINISH.back - 5, 12, 26, roofB, GOLD)
	addTurret(list, HALF + 5, Layout.FINISH.back - 5, 12, 26, roofA, GOLD)
	addTurret(list, -(HALF + 4), -70, 8, 18, roofA, GREEN)
	addTurret(list, HALF + 4, -70, 8, 18, roofB, BLUE)
end

-- 입구 아치: 앞 탑 두 개를 잇는 굵은 공기 아치 + 노란 현판
local function addEntranceArch(list: { DecorSpec })
	local z = Layout.START.front + 5
	append(list, MapKitShapes.capsule("EntranceArch", 2 * HALF + 4, 4.4, RED, "SmoothPlastic", v(0, 25, z)))
	append(
		list,
		MapKitShapes.roundedBox(
			"EntranceSign",
			v(18, 5, 1.6),
			YELLOW,
			"SmoothPlastic",
			v(0, 29.4, z),
			{ radius = 0.7, style = "vertical" }
		)
	)
	for k, color in { RED, BLUE, GREEN } do
		add(list, "EntranceSignStar", "Ball", v(2.6, 2.6, 2.6), color, "SmoothPlastic", v(-12 + k * 6, 29.4, z + 0.9))
	end
end

-- 결승 아치: 벽 위에 선 두 기둥 + 체크 깃발 띠 + 금색 깃발 + 그림자 조명(SpotLight 1) + 꽃가루
local function addFinishArch(list: { DecorSpec })
	local z = Layout.finishLineZ()
	local base = Layout.WALL_HEIGHT + 0.8
	local top = 27
	local shine: Extra = { reflectance = 0.15 }
	for _, side in { -1, 1 } do
		column(list, "FinishArchPost", side * (HALF + 0.25), base, z, top - base, 2.2, GOLD, "SmoothPlastic", shine)
		add(
			list,
			"FinishArchKnob",
			"Ball",
			v(3, 3, 3),
			GOLD,
			"SmoothPlastic",
			v(side * (HALF + 0.25), top + 1, z),
			nil,
			shine
		)
	end
	append(list, MapKitShapes.capsule("FinishArchBar", 2 * HALF, 2.4, RED, "SmoothPlastic", v(0, top, z)))
	for k = 0, 9 do
		local color = if k % 2 == 0 then PIPING else { r = 34, g = 34, b = 40 }
		add(list, "FinishBanner", "Block", v(3.6, 3.4, 0.4), color, "Fabric", v(-18 + k * 4, top - 3, z))
	end
	for k = -2, 2 do
		add(list, "FinishFlag", "Wedge", v(0.3, 2.6, 3), GOLD, "Fabric", v(k * 7, top + 2.6, z - 1.5), nil, {
			anim = { kind = "Sway", period = 2.2 + (k + 2) * 0.25, amount = 12, axis = "Y" },
		})
	end
	add(
		list,
		"FinishSpotLamp",
		"Cylinder",
		v(1.4, 2.4, 2.4),
		{ r = 255, g = 246, b = 214 },
		"Neon",
		v(0, top - 1.6, z + 2),
		UP,
		{
			light = {
				kind = "Spot",
				color = { r = 255, g = 240, b = 210 },
				brightness = 3,
				range = 34,
				angle = 70,
				face = "Bottom",
				shadows = true,
			},
		}
	)
	add(list, "FinishConfetti", "Block", v(2, 0.4, 2), GOLD, "SmoothPlastic", v(0, top + 1.2, z), nil, {
		particle = "Confetti",
		particleRate = 6,
		transparency = 1,
	})
	add(list, "FinishSparkle", "Block", v(0.4, 0.4, 0.4), GOLD, "SmoothPlastic", v(-12, top, z), nil, {
		particle = "Sparkle",
		transparency = 1,
	})
end

-- 공기 송풍기 + 굵은 호스 (호스 Pulse — 바람이 들어가는 느낌). dir: 성에서 바깥쪽 x 부호
local function addBlower(list: { DecorSpec }, x: number, z: number, dir: number)
	local y = GROUND + 4.6
	append(list, MapKitShapes.roundedBox("Blower", v(10, 9, 9), RED, "SmoothPlastic", v(x, y, z), { radius = 1.2 }))
	add(
		list,
		"BlowerGrille",
		"Cylinder",
		v(0.6, 7, 7),
		{ r = 60, g = 62, b = 70 },
		"DiamondPlate",
		v(x + dir * 5.1, y, z),
		nil,
		{
			reflectance = 0.2,
		}
	)
	add(
		list,
		"BlowerFan",
		"Block",
		v(0.3, 6, 1.2),
		{ r = 200, g = 204, b = 212 },
		"Metal",
		v(x + dir * 5.5, y, z),
		nil,
		{
			anim = { kind = "Spin", period = 0.8, amount = 0, axis = "X" },
		}
	)
	add(list, "BlowerFeet", "Block", v(10.4, 1, 9.4), { r = 50, g = 50, b = 56 }, "Rubber", v(x, GROUND + 0.5, z))
	-- 호스: 송풍기 → 성 바닥 띠까지
	local hoseFrom = x - dir * 5
	local hoseTo = dir * (HALF + 6)
	local len = math.abs(hoseFrom - hoseTo)
	add(
		list,
		"BlowerHose",
		"Cylinder",
		v(len, 3.6, 3.6),
		YELLOW,
		"SmoothPlastic",
		v((hoseFrom + hoseTo) / 2, GROUND + 3, z),
		nil,
		{
			anim = { kind = "Pulse", period = 1.6, amount = 0.06 },
		}
	)
	for k = 1, 3 do
		local hx = hoseFrom + (hoseTo - hoseFrom) * k / 4
		add(
			list,
			"BlowerHoseRib",
			"Cylinder",
			v(0.6, 4.2, 4.2),
			MapKitLogic.shade(YELLOW, 0.8),
			"SmoothPlastic",
			v(hx, GROUND + 3, z)
		)
	end
end

-- 풍선 다발 (Bob) — 줄은 고정, 풍선만 둥실
local function addBalloonBunch(list: { DecorSpec }, x: number, z: number, top: number, seed: number)
	local rng = MapKitShapes.rng(seed)
	local colors = { RED, YELLOW, BLUE, GREEN, { r = 255, g = 140, b = 190 } }
	add(list, "BalloonWeight", "Block", v(2.4, 1.6, 2.4), GOLD, "SmoothPlastic", v(x, GROUND + 0.8, z))
	for k = 1, 5 do
		local bx = x + rng:range(-5, 5)
		local bz = z + rng:range(-5, 5)
		local by = top + rng:range(-4, 4)
		local d = rng:range(6, 8.5)
		add(
			list,
			"ParkBalloon",
			"Ball",
			v(d, d, d),
			colors[(k + seed) % #colors + 1],
			"SmoothPlastic",
			v(bx, by, bz),
			nil,
			{
				reflectance = 0.12,
				anim = { kind = "Bob", period = 3 + rng:range(0, 2), amount = 1.2 },
			}
		)
		-- 줄: 무게추 → 풍선 아래 (세로 원기둥 — 약간의 기울기는 생략)
		local len = (by - d / 2) - (GROUND + 1.6)
		add(
			list,
			"BalloonString",
			"Block",
			v(0.12, len, 0.12),
			PIPING,
			"SmoothPlastic",
			v(bx, GROUND + 1.6 + len / 2, bz)
		)
	end
end

-- 나무 한 그루 (줄기 + 잎 공 3개, shade 섞기)
local function addTree(list: { DecorSpec }, x: number, z: number, scale: number, seed: number)
	local leaf = MapKitLogic.shades({ r = 78, g = 160, b = 72 })
	local h = 40 * scale
	column(list, "ParkTreeTrunk", x, GROUND, z, h, 5 * scale, TRUNK, "Wood")
	local rng = MapKitShapes.rng(seed)
	for k = 1, 3 do
		local d = (30 + rng:range(-6, 8)) * scale
		local c = if k == 1 then leaf.base elseif k == 2 then leaf.light else leaf.dark
		local pos =
			v(x + rng:range(-9, 9) * scale, GROUND + h + rng:range(-4, 10) * scale, z + rng:range(-9, 9) * scale)
		add(list, "ParkTreeLeaves", "Ball", v(d, d, d), c, "Grass", pos)
	end
end

-- 대관람차 (BG): 다리 A자 + 바퀴 테두리 + 살 + 곤돌라, 가운데 별 모양 허브가 천천히 Spin
local function addFerrisWheel(list: { DecorSpec }, cx: number, cz: number, radius: number)
	local hubY = GROUND + radius + 30
	local steel = { r = 236, g = 238, b = 244 }
	for _, side in { -1, 1 } do
		for _, lean in { -1, 1 } do
			local spread = radius * 0.55
			local legLen = math.sqrt(spread ^ 2 + (hubY - GROUND) ^ 2)
			local angle = math.deg(math.atan2(spread, hubY - GROUND))
			add(
				list,
				"WheelLeg",
				"Block",
				v(4, legLen, 4),
				steel,
				"Metal",
				v(cx + lean * spread / 2, (hubY + GROUND) / 2, cz + side * 12),
				v(0, 0, lean * angle)
			)
		end
	end
	append(list, MapKitShapes.ring("WheelRim", radius, 3, 3, 28, steel, "Metal", v(cx, hubY, cz), v(90, 0, 0)))
	local colors = { RED, YELLOW, BLUE, GREEN }
	for k = 0, 11 do
		local a = k * 30
		local ar = math.rad(a)
		local cxk, cyk = cx + math.cos(ar) * radius, hubY + math.sin(ar) * radius
		add(
			list,
			"WheelSpoke",
			"Block",
			v(radius, 1.4, 1.4),
			steel,
			"Metal",
			v(cx + math.cos(ar) * radius / 2, hubY + math.sin(ar) * radius / 2, cz),
			v(0, 0, a)
		)
		append(
			list,
			MapKitShapes.roundedBox(
				"WheelGondola",
				v(12, 11, 10),
				colors[k % 4 + 1],
				"SmoothPlastic",
				v(cxk, cyk - 7, cz),
				{ radius = 2.5, style = "vertical" }
			)
		)
	end
	add(list, "WheelHub", "Cylinder", v(26, 14, 14), GOLD, "Metal", v(cx, hubY, cz), v(0, 90, 0), { reflectance = 0.2 })
	local spin = { anim = { kind = "Spin", period = 24, amount = 0, axis = "Z" } } :: Extra
	add(list, "WheelHubStar", "Block", v(40, 5, 5), RED, "SmoothPlastic", v(cx, hubY, cz + 13.5), nil, spin)
	add(list, "WheelHubStar", "Block", v(5, 40, 5), YELLOW, "SmoothPlastic", v(cx, hubY, cz + 14), nil, spin)
end

-- 회전목마 (BG): 받침 원판 + 기둥 + 줄무늬 원뿔 지붕 + 꼭대기 바람개비 Spin
local function addCarousel(list: { DecorSpec }, cx: number, cz: number, d: number)
	column(list, "CarouselBase", cx, GROUND, cz, 6, d, { r = 250, g = 236, b = 206 }, "SmoothPlastic")
	append(list, MapKitShapes.ring("CarouselRim", d / 2, 2, 6.4, 20, GOLD, "SmoothPlastic", v(cx, GROUND + 3.2, cz)))
	local colors = { RED, YELLOW, BLUE, GREEN }
	for k = 0, 9 do
		local a = math.rad(k * 36)
		local px, pz = cx + math.cos(a) * d * 0.4, cz + math.sin(a) * d * 0.4
		column(list, "CarouselPole", px, GROUND + 6, pz, 40, 1.6, GOLD, "Metal", { reflectance = 0.25 })
		append(
			list,
			MapKitShapes.roundedBox(
				"CarouselHorse",
				v(4, 7, 12),
				colors[k % 4 + 1],
				"SmoothPlastic",
				v(px, GROUND + 16, pz),
				{ radius = 1.5, style = "vertical", rotation = v(0, -k * 36, 0) }
			)
		)
	end
	column(list, "CarouselCenter", cx, GROUND + 6, cz, 40, d * 0.3, { r = 250, g = 120, b = 150 }, "SmoothPlastic")
	column(list, "CarouselValance", cx, GROUND + 44, cz, 6, d + 4, RED, "SmoothPlastic")
	cone(list, "CarouselRoof", cx, GROUND + 50, cz, d + 4, d * 0.45, 6, { PIPING, RED })
	add(list, "CarouselTopper", "Block", v(14, 2, 2), YELLOW, "SmoothPlastic", v(cx, GROUND + 54 + d * 0.45, cz), nil, {
		anim = { kind = "Spin", period = 6, amount = 0, axis = "Y" },
	})
end

-- 서커스 텐트 (BG)
local function addTent(list: { DecorSpec }, cx: number, cz: number, d: number)
	local stripes = 16
	for k = 0, stripes - 1 do
		local a = k * 360 / stripes
		local ar = math.rad(a)
		local w = math.pi * d / stripes * 1.05
		local color = if k % 2 == 0 then RED else PIPING
		local pos = v(cx + math.cos(ar) * d / 2, GROUND + 20, cz + math.sin(ar) * d / 2)
		add(list, "TentWall", "Block", v(w, 40, 2), color, "Fabric", pos, v(0, -a - 90, 0))
	end
	column(list, "TentInner", cx, GROUND, cz, 40, d - 3, MapKitLogic.shade(RED, 0.5), "Fabric")
	cone(list, "TentRoof", cx, GROUND + 40, cz, d + 6, d * 0.6, 7, { RED, PIPING })
	column(list, "TentPole", cx, GROUND + 40 + d * 0.6, cz, 14, 1.2, GOLD, "Metal")
	add(list, "TentFlag", "Wedge", v(0.4, 5, 8), YELLOW, "Fabric", v(cx, GROUND + 51 + d * 0.6, cz - 4), nil, {
		anim = { kind = "Sway", period = 3, amount = 10, axis = "Y" },
	})
end

-- 옆 초밥집 (BG, 세계관 연결): 건물 + 기와 지붕 + 노렌 + 빨간 등
local function addSushiShop(list: { DecorSpec }, cx: number, cz: number)
	local w, h, d = 260, 110, 60
	local front = cz + d / 2
	append(
		list,
		MapKitShapes.roundedBox(
			"ShopWall",
			v(w, h, d),
			{ r = 244, g = 232, b = 210 },
			"Plaster",
			v(cx, GROUND + h / 2, cz),
			{ radius = 3, style = "vertical" }
		)
	)
	add(list, "ShopBase", "Block", v(w + 4, 8, d + 4), { r = 120, g = 92, b = 72 }, "Wood", v(cx, GROUND + 4, cz))
	local roofSize = v(w + 20, 30, d / 2 + 10)
	add(
		list,
		"ShopRoof",
		"Wedge",
		roofSize,
		{ r = 70, g = 76, b = 92 },
		"ClayRoofTiles",
		v(cx, GROUND + h + 15, cz + d / 4 + 5),
		v(0, 180, 0)
	)
	add(
		list,
		"ShopRoof",
		"Wedge",
		roofSize,
		{ r = 60, g = 66, b = 82 },
		"ClayRoofTiles",
		v(cx, GROUND + h + 15, cz - d / 4 - 5)
	)
	add(list, "ShopBeam", "Block", v(w + 6, 6, d + 6), { r = 110, g = 70, b = 48 }, "Wood", v(cx, GROUND + h - 3, cz))
	-- 노렌 (가게 앞, 코스 쪽 = +Z면)
	for k = -2, 2 do
		add(
			list,
			"ShopNoren",
			"Block",
			v(18, 30, 0.6),
			MapKitLogic.PALETTE.Noren,
			"Fabric",
			v(cx + k * 19, GROUND + 52, front + 1),
			nil,
			{
				anim = { kind = "Sway", period = 4 + k * 0.2, amount = 3, axis = "X" },
			}
		)
	end
	add(list, "ShopDoor", "Block", v(100, 50, 0.8), { r = 70, g = 46, b = 34 }, "Wood", v(cx, GROUND + 33, front + 0.3))
	add(list, "ShopSign", "Block", v(80, 16, 2), { r = 120, g = 76, b = 48 }, "Wood", v(cx, GROUND + 82, front + 1.2))
	add(list, "ShopSignText", "Block", v(60, 8, 0.4), PIPING, "SmoothPlastic", v(cx, GROUND + 82, front + 2.4))
	for _, side in { -1, 1 } do
		add(
			list,
			"ShopLantern",
			"Ball",
			v(16, 16, 16),
			MapKitLogic.PALETTE.Lacquer,
			"SmoothPlastic",
			v(cx + side * 70, GROUND + 62, front + 10)
		)
		append(
			list,
			MapKitShapes.rimDisc(
				"ShopWindow",
				30,
				1,
				{ r = 150, g = 200, b = 230 },
				"Glass",
				v(cx + side * 100, GROUND + 50, front + 0.6),
				{ rimColor = { r = 110, g = 70, b = 48 }, rimWidth = 3, segments = 12, rotation = v(90, 0, 0) }
			)
		)
	end
end

-- 간식 수레 (MG): 솜사탕 수레 + 줄무늬 차양
local function addCart(list: { DecorSpec }, x: number, z: number, yaw: number)
	local parts: { DecorSpec } = {}
	append(
		parts,
		MapKitShapes.roundedBox(
			"SnackCart",
			v(14, 10, 8),
			{ r = 255, g = 236, b = 240 },
			"SmoothPlastic",
			v(0, GROUND + 7, 0),
			{
				radius = 1.4,
			}
		)
	)
	for _, sx in { -1, 1 } do
		add(
			parts,
			"SnackCartWheel",
			"Cylinder",
			v(1, 5, 5),
			{ r = 60, g = 60, b = 66 },
			"Rubber",
			v(sx * 5, GROUND + 2.5, 4.4)
		)
		column(parts, "SnackPole", sx * 6.4, GROUND + 12, -2, 10, 0.6, PIPING, "Metal")
	end
	for k = 0, 5 do
		local color = if k % 2 == 0 then RED else PIPING
		add(parts, "SnackAwning", "Wedge", v(2.5, 2.4, 5), color, "Fabric", v(-6.25 + k * 2.5, GROUND + 23, 0))
	end
	add(
		parts,
		"CottonCandy",
		"Ball",
		v(5, 5, 5),
		{ r = 255, g = 170, b = 210 },
		"SmoothPlastic",
		v(-3, GROUND + 14.5, 0)
	)
	add(
		parts,
		"CottonCandy",
		"Ball",
		v(4.4, 4.4, 4.4),
		{ r = 170, g = 210, b = 255 },
		"SmoothPlastic",
		v(2, GROUND + 14.2, 0)
	)
	append(list, MapKitShapes.transform(parts, v(x, 0, z), v(0, yaw, 0)))
end

-- 산울타리 + 꽃 (MG/BG 사이 밀도)
local function addHedges(list: { DecorSpec })
	local hedge = MapKitLogic.shades({ r = 62, g = 140, b = 64 })
	for _, side in { -1, 1 } do
		for k = 0, 5 do
			local z = 20 - k * 40
			local color = if k % 2 == 0 then hedge.base else hedge.dark
			append(
				list,
				MapKitShapes.roundedBox("Hedge", v(10, 9, 30), color, "Grass", v(side * 78, GROUND + 4.5, z), {
					radius = 3,
					style = "vertical",
				})
			)
			local flower = if k % 2 == 0 then YELLOW else { r = 255, g = 140, b = 190 }
			add(list, "HedgeFlower", "Ball", v(3, 3, 3), flower, "SmoothPlastic", v(side * 78 + 2, GROUND + 9.4, z + 6))
			add(
				list,
				"HedgeFlower",
				"Ball",
				v(2.6, 2.6, 2.6),
				PIPING,
				"SmoothPlastic",
				v(side * 78 - 2, GROUND + 9.3, z - 7)
			)
		end
	end
end

-- 바람개비 (움직임)
local function addPinwheel(list: { DecorSpec }, x: number, z: number, h: number, seed: number)
	column(list, "PinwheelStick", x, GROUND, z, h, 0.8, PIPING, "SmoothPlastic")
	local colors = { RED, YELLOW, BLUE, GREEN }
	local spin = { anim = { kind = "Spin", period = 2 + seed % 3, amount = 0, axis = "Z" } } :: Extra
	add(
		list,
		"Pinwheel",
		"Block",
		v(9, 2.6, 0.4),
		colors[seed % 4 + 1],
		"SmoothPlastic",
		v(x, GROUND + h, z + 0.6),
		nil,
		spin
	)
	add(
		list,
		"Pinwheel",
		"Block",
		v(2.6, 9, 0.4),
		colors[(seed + 1) % 4 + 1],
		"SmoothPlastic",
		v(x, GROUND + h, z + 0.7),
		nil,
		spin
	)
end

-- 입구 매표소 + 비눗방울 기계 (출발 쪽 밀도, 파티클 Bubbles)
local function addTicketBooth(list: { DecorSpec }, x: number, z: number)
	append(
		list,
		MapKitShapes.roundedBox(
			"TicketBooth",
			v(14, 16, 12),
			{ r = 255, g = 244, b = 214 },
			"SmoothPlastic",
			v(x, GROUND + 8, z),
			{
				radius = 1.6,
				style = "vertical",
			}
		)
	)
	add(
		list,
		"TicketWindow",
		"Block",
		v(8, 6, 0.4),
		{ r = 120, g = 170, b = 210 },
		"Glass",
		v(x, GROUND + 10, z - 6.1),
		nil,
		{
			reflectance = 0.2,
		}
	)
	for k = 0, 5 do
		local color = if k % 2 == 0 then BLUE else PIPING
		add(
			list,
			"TicketAwning",
			"Wedge",
			v(2.8, 3, 4),
			color,
			"Fabric",
			v(x - 7 + 1.4 + k * 2.8, GROUND + 17.5, z - 7),
			v(0, 180, 0)
		)
	end
	cone(list, "TicketRoof", x, GROUND + 16, z, 15, 8, 4, { YELLOW, RED })
	-- 비눗방울 기계
	append(
		list,
		MapKitShapes.roundedBox(
			"BubbleMachine",
			v(5, 4, 5),
			BLUE,
			"SmoothPlastic",
			v(x + 14, GROUND + 2, z - 4),
			{ radius = 0.8 }
		)
	)
	add(list, "BubbleNozzle", "Cylinder", v(2, 1.6, 1.6), PIPING, "SmoothPlastic", v(x + 14, GROUND + 5, z - 4), UP, {
		particle = "Bubbles",
		particleRate = 4,
	})
end

-- 입구 길 옆 꽃밭 + 피크닉 돗자리 (3/4 뷰 앞쪽 빈 잔디를 채우는 FG/MG 무리)
local function addPicnic(list: { DecorSpec })
	local flowers = { RED, YELLOW, PIPING, { r = 240, g = 120, b = 180 } }
	for b, bed in { { -40, 110, 34 }, { 46, 150, 26 } } do
		local bx, bz, d = bed[1], bed[2], bed[3]
		add(list, "FlowerBedRim", "Cylinder", v(1.6, d + 2, d + 2), PATH, "Concrete", v(bx, GROUND + 0.8, bz), UP)
		add(
			list,
			"FlowerBedSoil",
			"Cylinder",
			v(1.8, d, d),
			{ r = 108, g = 76, b = 52 },
			"Mud",
			v(bx, GROUND + 0.9, bz),
			UP
		)
		local rng = MapKitShapes.rng(300 + b)
		for k = 1, 12 do
			local a = rng:range(0, math.pi * 2)
			local r = rng:range(1, d / 2 - 2)
			local fs = rng:range(2.2, 3.4)
			add(
				list,
				"FlowerHead",
				"Ball",
				v(fs, fs, fs),
				flowers[k % #flowers + 1],
				"SmoothPlastic",
				v(bx + math.cos(a) * r, GROUND + 2.6 + rng:range(0, 1), bz + math.sin(a) * r)
			)
		end
	end
	-- 돗자리 (빨강·흰 체크 4칸) + 도시락 상자 + 주스 병
	local mats = { { -70, 70, 12 }, { 36, 96, -18 } }
	for m, mat in mats do
		local parts: { DecorSpec } = {}
		for i = 0, 1 do
			for j = 0, 1 do
				add(
					parts,
					"PicnicMat",
					"Block",
					v(8, 0.2, 8),
					if (i + j) % 2 == 0 then RED else PIPING,
					"Fabric",
					v(-4 + i * 8, GROUND + 0.2, -4 + j * 8)
				)
			end
		end
		append(
			parts,
			MapKitShapes.roundedBox(
				"PicnicBox",
				v(5, 2.4, 4),
				if m == 1 then BLUE else GREEN,
				"SmoothPlastic",
				v(-2, GROUND + 1.4, 1),
				{ radius = 0.5, style = "vertical" }
			)
		)
		add(parts, "PicnicBottle", "Cylinder", v(4, 1.4, 1.4), YELLOW, "Glass", v(3, GROUND + 2.2, -2), UP, {
			transparency = 0.2,
			reflectance = 0.15,
		})
		append(list, MapKitShapes.transform(parts, v(mat[1], 0, mat[2]), v(0, mat[3], 0)))
	end
end

function BouncyCastleMazeArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addFloorChecker(list)
	addGateStripes(list)
	addBalloons(list)
	addFlags(list)
	addAirVents(list)
	addLamps(list)
	addFinishChecker(list)
	-- m5-24
	addPark(list)
	addCastleBody(list)
	addPiping(list)
	addTurrets(list)
	addEntranceArch(list)
	addFinishArch(list)
	addBlower(list, 46, -40, 1)
	addBlower(list, -46, -104, -1)
	addBalloonBunch(list, -44, -24, 26, 3)
	addBalloonBunch(list, 42, -128, 30, 7)
	addBalloonBunch(list, 38, 24, 20, 11)
	addHedges(list)
	addCart(list, 64, -10, -20)
	addCart(list, -64, -150, 160)
	for k, p in { { -34, 30, 14 }, { 34, -60, 16 }, { -36, -150, 12 }, { 30, 36, 10 } } do
		addPinwheel(list, p[1], p[2], p[3], k)
	end
	addFerrisWheel(list, -230, -420, 130)
	addCarousel(list, 240, -300, 90)
	addTent(list, 300, 40, 110)
	addSushiShop(list, 40, -640)
	addTicketBooth(list, -30, 44)
	addPicnic(list)
	-- 먼 언덕 띠 (지평선 아래 빈 하늘이 안 보이게, 잔디밭 가장자리 바깥)
	local hill = MapKitLogic.shades({ r = 98, g = 168, b = 96 })
	for k = 0, 17 do
		local a = math.rad(k * 20 + 7)
		local d = 260 + (k % 3) * 50
		local c = if k % 3 == 0 then hill.base elseif k % 3 == 1 then hill.dark else hill.light
		add(
			list,
			"FarHill",
			"Ball",
			v(d, d, d),
			c,
			"Grass",
			v(math.cos(a) * 760, GROUND - d * 0.3, -70 + math.sin(a) * 760)
		)
	end
	local trees = {
		{ -140, -60, 1.2 },
		{ -170, -160, 1.4 },
		{ -190, 70, 1.1 },
		{ 150, -120, 1.3 },
		{ 140, 140, 1.1 },
		{ -230, 210, 1.3 },
		{ 120, -420, 1.6 },
		{ -420, -150, 1.8 },
		{ 420, -520, 1.7 },
		{ -380, 120, 1.5 },
		{ 100, 280, 1.2 },
		{ -90, -300, 1.4 },
	}
	for k, t in trees do
		addTree(list, t[1], t[2], t[3], k)
	end
	return list
end

-- 소개: ① 입구 앞 넓은 샷(성·탑·대관람차) ② 관문과 열린 1번 레인 ③ 미로 위에서 결승 쪽(S자) ④ 결승 아치
function BouncyCastleMazeArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-50, 40, 36), lookAt = v(0, 0, -50) },
		{ pos = v(14, 30, -4), lookAt = v(-14, 3, -30) },
		{ pos = v(0, 42, -42), lookAt = v(0, 0, -104) },
		{ pos = v(0, 20, -108), lookAt = v(0, 14, -140) },
	}
end

return BouncyCastleMazeArt
