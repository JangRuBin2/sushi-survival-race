--!strict
-- "고양이 카페 캣타워" 아트 데이터 (m5-17). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정 지오메트리(선반·탈락 높이)는 CatCafeShelvesLayout 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   CatCafeShelvesArt.decor() -> { DecorSpec }   파스텔 카페 장식 (origin 기준 로컬, MapKit.buildDecor로 만들어요)
--   CatCafeShelvesArt.introCamera() -> { IntroPoint }  카페 전경 → 1단 스폰 → 타워 옆모습 → 꼭대기 캣방석
--   CatCafeShelvesArt.WINDOW_LIGHT, SUNBEAM       PointLight·ParticleEmitter를 붙일 장식 파츠 이름

local Layout = require(script.Parent.CatCafeShelvesLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local Art = {}

Art.WINDOW_LIGHT = "WindowLight" -- 창가 햇살 느낌 조명 (build가 PointLight를 붙여요)
Art.SUNBEAM = "Sunbeam" -- 창가 먼지 반짝임 (build가 ParticleEmitter를 붙여요)

local WALL: RGB = { r = 250, g = 222, b = 230 } -- 연분홍 벽
local WALL_TRIM: RGB = { r = 255, g = 244, b = 236 } -- 크림색 몰딩
local WOOD: RGB = { r = 196, g = 150, b = 102 } -- 바닥 느낌 나무
local PILLAR: RGB = { r = 176, g = 128, b = 88 }
local CUSHION_PINK: RGB = { r = 244, g = 170, b = 188 }
local CUSHION_CREAM: RGB = { r = 250, g = 236, b = 210 }
local BASKET: RGB = { r = 150, g = 104, b = 64 }
local YARN: RGB = { r = 232, g = 140, b = 150 }
local PAW_PAD: RGB = { r = 232, g = 180, b = 150 }
local SIGN: RGB = { r = 120, g = 70, b = 56 }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function part(
	list: { DecorSpec },
	name: string,
	shape: Shape,
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

-- 세운 원판(원기둥 축을 Y로): 원기둥은 축이 로컬 X라 Z로 90° 돌려요 (다른 맵 아트와 같은 관례)
local UPRIGHT = v(0, 0, 90)

local CX = Layout.TOWER_CENTER_X
local CZ = Layout.TOWER_CENTER_Z

-- m5-24: 방 크기 (1 stud ≈ 1 cm — 카페 바닥은 탈락선 -11보다 19 아래, 벽은 타워 중심에서 60~150)
local FLOOR_Y = Layout.ELIMINATION_Y - 19 -- 바닥 윗면 -30
local BACK_Z = CZ - 60 -- 창문 벽 (그림자 SpotLight 범위 60 안에 타워가 들어오게)
local FRONT_Z = CZ + 150 -- 입구 벽
local SIDE_X = 150 -- 좌우 벽
local WALL_TOP = FLOOR_Y + 130
local WINDOW_Y = FLOOR_Y + 74 -- 창 가운데 높이

-- 바닥·벽 (카페 배경, 판정과 무관). 창가 햇살 조명·먼지(WINDOW_LIGHT·SUNBEAM)는 창문 벽 두 창에 하나씩.
local function addBackdrop(list: { DecorSpec })
	local floorShades = MapKitLogic.shades(WOOD)
	part(list, "CafeFloor", "Block", v(800, 2, 800), WOOD, "WoodPlanks", v(CX, FLOOR_Y - 1, CZ))
	-- 마루 판 결 (shade 3단 띠)
	for k = -7, 7 do
		local c = if k % 3 == 0 then floorShades.light elseif k % 3 == 1 then floorShades.dark else WOOD
		part(list, "FloorPlank", "Block", v(18, 0.1, 300), c, "WoodPlanks", v(CX + k * 20, FLOOR_Y + 0.05, CZ + 40))
	end
	local wallH = WALL_TOP - FLOOR_Y
	local wallY = FLOOR_Y + wallH / 2
	part(list, "CafeWallBack", "Block", v(SIDE_X * 2 + 4, wallH, 2), WALL, "Plaster", v(CX, wallY, BACK_Z - 1))
	part(list, "CafeWallFront", "Block", v(SIDE_X * 2 + 4, wallH, 2), WALL, "Plaster", v(CX, wallY, FRONT_Z + 1))
	for _, side in { -1, 1 } do
		part(
			list,
			"CafeWallSide",
			"Block",
			v(2, wallH, FRONT_Z - BACK_Z + 4),
			WALL,
			"Plaster",
			v(CX + side * (SIDE_X + 1), wallY, (FRONT_Z + BACK_Z) / 2)
		)
		-- 걸레받이 + 허리 몰딩 (크림)
		part(
			list,
			"CafeWallTrim",
			"Block",
			v(1.4, 8, FRONT_Z - BACK_Z),
			WALL_TRIM,
			"Wood",
			v(CX + side * SIDE_X, FLOOR_Y + 4, (FRONT_Z + BACK_Z) / 2)
		)
		part(
			list,
			"CafeWallTrim",
			"Block",
			v(1.4, 2, FRONT_Z - BACK_Z),
			WALL_TRIM,
			"Wood",
			v(CX + side * SIDE_X, FLOOR_Y + 60, (FRONT_Z + BACK_Z) / 2)
		)
		-- 허리 아래 벽판 (조금 진한 분홍 — 벽 2 shade)
		part(
			list,
			"CafeWainscot",
			"Block",
			v(0.8, 52, FRONT_Z - BACK_Z),
			MapKitLogic.shade(WALL, 0.92),
			"WoodPlanks",
			v(CX + side * (SIDE_X - 0.2), FLOOR_Y + 34, (FRONT_Z + BACK_Z) / 2)
		)
	end
	part(list, "CafeWallTrim", "Block", v(SIDE_X * 2, 8, 1.4), WALL_TRIM, "Wood", v(CX, FLOOR_Y + 4, BACK_Z))
	part(
		list,
		"CafeWainscot",
		"Block",
		v(SIDE_X * 2, 52, 0.8),
		MapKitLogic.shade(WALL, 0.92),
		"WoodPlanks",
		v(CX, FLOOR_Y + 34, BACK_Z + 0.2)
	)
	part(list, "CafeWallTrim", "Block", v(SIDE_X * 2, 2, 1.4), WALL_TRIM, "Wood", v(CX, FLOOR_Y + 60, BACK_Z))
	-- 창문 두 개 (창틀 + 하늘 판 + 창살) — 조명·먼지는 창 안쪽에
	for _, side in { -1, 1 } do
		local wx = CX + side * 48
		local wy = WINDOW_Y
		local wz = BACK_Z + 0.6
		part(list, "WindowSky", "Block", v(48, 44, 0.4), { r = 168, g = 212, b = 246 }, "SmoothPlastic", v(wx, wy, wz))
		part(
			list,
			"WindowSkyLow",
			"Block",
			v(48, 12, 0.3),
			{ r = 214, g = 236, b = 252 },
			"SmoothPlastic",
			v(wx, wy - 14, wz + 0.2)
		)
		for _, f in { -1, 1 } do
			part(list, "WindowFrame", "Block", v(3, 50, 2.4), WALL_TRIM, "Wood", v(wx + f * 25.5, wy, wz + 0.6))
			part(list, "WindowFrame", "Block", v(54, 3, 2.4), WALL_TRIM, "Wood", v(wx, wy + f * 23.5, wz + 0.6))
		end
		part(list, "WindowMullion", "Block", v(1.4, 44, 1.6), WALL_TRIM, "Wood", v(wx, wy, wz + 0.6))
		part(list, "WindowMullion", "Block", v(48, 1.4, 1.6), WALL_TRIM, "Wood", v(wx, wy + 4, wz + 0.6))
		part(list, "WindowSill", "Block", v(60, 2, 8), WALL_TRIM, "Wood", v(wx, wy - 25, wz + 3.5))
		part(
			list,
			Art.WINDOW_LIGHT,
			"Block",
			v(2, 2, 0.4),
			{ r = 255, g = 240, b = 210 },
			"Neon",
			v(wx + 20, wy + 18, wz + 0.5)
		)
		part(
			list,
			Art.SUNBEAM,
			"Block",
			v(0.2, 0.2, 0.2),
			{ r = 255, g = 250, b = 230 },
			"Neon",
			v(wx, wy - 10, wz + 14),
			nil,
			1
		)
		-- 바닥에 떨어진 햇살 무늬 (창 모양 4칸, 아주 밝은 크림 — 바닥보다 0.1 위, 탈락선 19 아래)
		for i = 0, 1 do
			for j = 0, 1 do
				part(
					list,
					"SunPatch",
					"Block",
					v(20, 0.1, 16),
					{ r = 255, g = 236, b = 190 },
					"SmoothPlastic",
					v(wx + (i - 0.5) * 23 + 6, FLOOR_Y + 0.12, BACK_Z + 30 + (j - 0.5) * 19),
					v(0, 8, 0)
				)
			end
		end
	end
end

-- 캣타워 옆 장식 기둥 3개 (구조적으로 떠받치지 않아요, 순수 장식 — 캣타워처럼 보이게)
-- m5-24: 카페 바닥까지 내리고 사이잘 밧줄 감김(Fabric 띠) + 꼭대기 작은 방석 받침
local SISAL: RGB = { r = 214, g = 188, b = 136 }
local SISAL_DARK: RGB = { r = 180, g = 152, b = 104 }

local function addPillars(list: { DecorSpec })
	local radius = Layout.TIER1_OUTER / 2 + 6
	local bottom = FLOOR_Y
	local top = Layout.TIER3_TOP_Y + 18
	for i = 0, 2 do
		local angle = math.rad(90 + i * 120)
		local x = CX + math.cos(angle) * radius
		local z = CZ + math.sin(angle) * radius
		part(
			list,
			"TowerPillar",
			"Cylinder",
			v(top - bottom, 3, 3),
			PILLAR,
			"Wood",
			v(x, (top + bottom) / 2, z),
			UPRIGHT
		)
		-- 사이잘 감김: 굵은 띠를 두 색 번갈아 쌓아요
		for k = 0, 8 do
			local y = FLOOR_Y + 4 + k * 4
			part(
				list,
				"SisalWrap",
				"Cylinder",
				v(3.6, 3.8, 3.8),
				if k % 2 == 0 then SISAL else SISAL_DARK,
				"Fabric",
				v(x, y + 1.8, z),
				UPRIGHT
			)
		end
		-- 기둥 발 + 꼭대기 받침 원판 + 방석
		part(list, "PillarFoot", "Cylinder", v(1.6, 7, 7), PILLAR, "Wood", v(x, FLOOR_Y + 0.8, z), UPRIGHT)
		part(list, "PillarPerch", "Cylinder", v(1.2, 9, 9), PILLAR, "Wood", v(x, top + 0.6, z), UPRIGHT)
		part(
			list,
			"PillarPerchCushion",
			"Ball",
			v(8, 1.8, 8),
			if i % 2 == 0 then CUSHION_PINK else CUSHION_CREAM,
			"Fabric",
			v(x, top + 1.8, z)
		)
	end
end

-- 1단 테두리 바깥쪽 고양이 발자국 패턴 (선반 하나당 2개, 8개)
local function addPawPrints(list: { DecorSpec })
	local offsets = {
		{ x = CX - 10, z = CZ + 22 },
		{ x = CX + 10, z = CZ + 22 },
		{ x = CX - 10, z = CZ - 22 },
		{ x = CX + 10, z = CZ - 22 },
		{ x = CX + 22, z = CZ - 10 },
		{ x = CX + 22, z = CZ + 10 },
		{ x = CX - 22, z = CZ - 10 },
		{ x = CX - 22, z = CZ + 10 },
	}
	for _, at in offsets do
		part(
			list,
			"PawPrint",
			"Cylinder",
			v(0.05, 2.4, 2.4),
			PAW_PAD,
			"SmoothPlastic",
			v(at.x, Layout.TIER1_TOP_Y + 0.03, at.z),
			UPRIGHT,
			0.2
		)
	end
end

-- 1단 모서리 장난감 바구니(+실뭉치) 4개, 2단 작은 쿠션 4개
local function addShelfDecor(list: { DecorSpec })
	local tier1Edge = Layout.TIER1_OUTER / 2 - Layout.SHELF_WIDTH / 2
	local baskets = {
		{ x = CX + tier1Edge, z = CZ + tier1Edge },
		{ x = CX - tier1Edge, z = CZ + tier1Edge },
		{ x = CX + tier1Edge, z = CZ - tier1Edge },
		{ x = CX - tier1Edge, z = CZ - tier1Edge },
	}
	for _, at in baskets do
		part(
			list,
			"ToyBasket",
			"Cylinder",
			v(1.4, 1.6, 1.6),
			BASKET,
			"WoodPlanks",
			v(at.x, Layout.TIER1_TOP_Y + 0.7, at.z),
			UPRIGHT
		)
		part(list, "YarnBall", "Ball", v(1, 1, 1), YARN, "Fabric", v(at.x, Layout.TIER1_TOP_Y + 1.9, at.z))
	end

	local tier2Edge = Layout.TIER2_OUTER / 2 - Layout.SHELF_WIDTH / 2
	local cushions = {
		{ x = CX, z = CZ + tier2Edge },
		{ x = CX, z = CZ - tier2Edge },
		{ x = CX + tier2Edge, z = CZ },
		{ x = CX - tier2Edge, z = CZ },
	}
	for i, at in cushions do
		local color = if i % 2 == 0 then CUSHION_PINK else CUSHION_CREAM
		part(list, "Cushion", "Block", v(2.4, 0.8, 2.4), color, "Fabric", v(at.x, Layout.TIER2_TOP_Y + 0.4, at.z))
	end
end

-- 꼭대기(3단) 큰 캣방석
local function addCatBed(list: { DecorSpec })
	part(list, "CatBed", "Ball", v(8, 1.6, 8), CUSHION_PINK, "Fabric", v(CX, Layout.TIER3_TOP_Y + 0.8, CZ))
	part(
		list,
		"CatBedRim",
		"Cylinder",
		v(0.4, 4.4, 4.4),
		CUSHION_CREAM,
		"Fabric",
		v(CX, Layout.TIER3_TOP_Y + 1.5, CZ),
		UPRIGHT
	)
end

-- 카페 간판 (m5-24: 창문 벽 두 창 사이에 걸어요 — 이전엔 작은 벽 앞 기둥)
local function addSign(list: { DecorSpec })
	local z = BACK_Z + 1
	part(list, "CafeSign", "Block", v(30, 10, 1.4), SIGN, "Wood", v(CX, WINDOW_Y + 10, z))
	part(list, "CafeSignPost", "Block", v(24, 1.4, 0.4), CUSHION_CREAM, "SmoothPlastic", v(CX, WINDOW_Y + 11, z + 0.8))
	-- 간판 위 고양이 귀 두 개
	for _, sx in { -1, 1 } do
		part(list, "CafeSignEar", "Wedge", v(1.4, 6, 6), SIGN, "Wood", v(CX + sx * 10, WINDOW_Y + 18, z))
	end
end

----------------------------------------------------------------------------------------------------
-- m5-24 아트 패스 v2: "오후 햇살 고양이 카페"
-- 층: FG 선반 가장자리 립·받침 기둥(사이잘) / MG 거대 치즈냥(앞발 들고 노려봄)·캣타워 기둥·창가 햇살·화분 /
-- BG 카페 마루(탈락선 19 아래)·분홍 벽·창·카운터·케이크 진열대·천장 들보·팬·잠자는 고양이들.
-- 선반(판정)·장난감 공(판정, 서버가 움직임)에는 장식을 붙이지 않아요. 장식은 전부 충돌·쿼리·터치 없음.
-- 치즈냥 색은 고양이 발 경고 주황(255,150,60)과 헷갈리지 않게 더 어둡고 갈색 쪽.
----------------------------------------------------------------------------------------------------

Art.BUDGET = "Extended"

-- 오후 4시 따뜻한 햇살 (로비 14시와 시간·안개 색이 달라요)
Art.LIGHTING = {
	ClockTime = 16,
	Brightness = 2.2,
	Ambient = { r = 150, g = 128, b = 122 },
	OutdoorAmbient = { r = 172, g = 150, b = 142 },
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.5,
	Atmosphere = {
		Density = 0.28,
		Offset = 0.1,
		Color = { r = 250, g = 222, b = 206 },
		Decay = { r = 236, g = 186, b = 160 },
		Glare = 0.15,
		Haze = 1.2,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.1,
		TintColor = { r = 255, g = 246, b = 238 },
	},
	Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.1 },
	SunRays = { Intensity = 0.06, Spread = 0.6 },
} :: MapLighting.LightingPreset

local CHEESE: RGB = { r = 206, g = 128, b = 72 } -- 치즈냥 (경고 주황보다 어둡고 갈색)
local CHEESE_DARK: RGB = { r = 156, g = 88, b = 48 }
local CREAM_FUR: RGB = { r = 250, g = 232, b = 204 }
local NOSE: RGB = { r = 232, g = 132, b = 140 }
local EYE: RGB = { r = 40, g = 44, b = 40 }
local LAMP_GLOW: RGB = { r = 255, g = 214, b = 160 }
local TERRACOTTA: RGB = { r = 196, g = 104, b = 72 }
local LEAF = MapKitLogic.shades({ r = 92, g = 156, b = 84 })

type Extra = {
	reflectance: number?,
	transparency: number?,
	castShadow: boolean?,
	light: MapKitLogic.LightSpec?,
	particle: string?,
	particleRate: number?,
	anim: MapKitLogic.AnimSpec?,
}

local function put(
	list: { DecorSpec },
	name: string,
	shape: Shape,
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
	for _, x in more do
		table.insert(list, x)
	end
end

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
	put(list, name, "Cylinder", v(h, d, d), color, material, v(x, y0 + h / 2, z), UPRIGHT, extra)
end

-- 선반 가장자리 립 (윗면보다 0.15 낮게, 바깥으로 0.4 — 두께감·가장자리 가독성. 선반 하위가 아니라 Decor)
local function addShelfLips(list: { DecorSpec })
	local edge = MapKitLogic.PALETTE.WoodDark
	for _, shelf in Layout.shelves() do
		local sx = if shelf.axis == "X" then shelf.length else shelf.width
		local sz = if shelf.axis == "X" then shelf.width else shelf.length
		append(
			list,
			MapKitShapes.lipTrim(
				"ShelfLip",
				v(sx, 0, sz),
				0.4,
				1.7,
				edge,
				"Wood",
				v(shelf.centerX, shelf.topY - 0.15 - 0.85, shelf.centerZ)
			)
		)
	end
end

-- 캣타워 받침: 1단·2단 네 귀퉁이 아래 사이잘 기둥, 3단 아래 굵은 몸통 (바닥에서 선반 아랫면 바로 밑까지)
local function addTowerSupports(list: { DecorSpec })
	local e1 = Layout.TIER1_OUTER / 2 - Layout.SHELF_WIDTH / 2
	local e2 = Layout.TIER2_OUTER / 2 - Layout.SHELF_WIDTH / 2
	for _, tier in { { e1, Layout.TIER1_TOP_Y - 2.2, 3 }, { e2, Layout.TIER2_TOP_Y - 2.2, 2.6 } } do
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x, z = CX + sx * tier[1], CZ + sz * tier[1]
				column(list, "TowerPost", x, FLOOR_Y, z, tier[2] - FLOOR_Y, tier[3], SISAL, "Fabric")
				for k = 0, 3 do
					column(list, "TowerPostBand", x, FLOOR_Y + 6 + k * 8, z, 1, tier[3] + 0.4, SISAL_DARK, "Fabric")
				end
			end
		end
	end
	column(list, "TowerTrunk", CX, FLOOR_Y, CZ, Layout.TIER3_TOP_Y - 2.2 - FLOOR_Y, 7, PILLAR, "Wood")
	-- 몸통 아래쪽 고양이 구멍 집 (둥근 상자 + 검은 입구)
	append(
		list,
		MapKitShapes.roundedBox(
			"TowerCondo",
			v(14, 12, 14),
			CUSHION_CREAM,
			"Fabric",
			v(CX, FLOOR_Y + 8, CZ),
			{ radius = 2.5 }
		)
	)
	put(list, "TowerCondoHole", "Cylinder", v(0.4, 7, 7), EYE, "Fabric", v(CX + 7.1, FLOOR_Y + 7, CZ))
	-- 바닥 받침 카펫 원판
	append(
		list,
		MapKitShapes.rimDisc("TowerRug", 70, 0.4, CUSHION_PINK, "Carpet", v(CX, FLOOR_Y + 0.2, CZ), {
			rimColor = MapKitLogic.shade(CUSHION_PINK, 0.82),
			rimWidth = 3,
			rimHeight = 0.6,
			segments = 20,
		})
	)
end

-- 거대 치즈냥 (MG 히어로): 타워 서쪽 바닥에 앉아 앞발 하나를 들어 선반을 노려봐요. 꼬리 Sway.
local function addGiantCat(list: { DecorSpec })
	local c: { DecorSpec } = {}
	local y = FLOOR_Y
	put(c, "CatBody", "Ball", v(34, 30, 30), CHEESE, "Fabric", v(6, y + 15, 0))
	put(c, "CatChest", "Ball", v(24, 30, 24), CHEESE, "Fabric", v(-4, y + 24, 0))
	put(c, "CatBelly", "Ball", v(10, 22, 16), CREAM_FUR, "Fabric", v(-12, y + 22, 0))
	for k = 0, 3 do
		for _, sz in { -1, 1 } do
			put(
				c,
				"CatStripe",
				"Block",
				v(3, 12, 1),
				CHEESE_DARK,
				"Fabric",
				v(10 - k * 6, y + 20, sz * 14.6),
				v(0, 0, 10 - k * 6)
			)
		end
	end
	local hy = y + 44
	put(c, "CatHead", "Ball", v(22, 19, 24), CHEESE, "Fabric", v(-8, hy, 0))
	put(c, "CatMuzzle", "Ball", v(7, 8, 12), CREAM_FUR, "Fabric", v(-18, hy - 4, 0))
	put(c, "CatNose", "Ball", v(1.6, 1.4, 2.4), NOSE, "SmoothPlastic", v(-21.6, hy - 1.8, 0))
	for _, sz in { -1, 1 } do
		put(c, "CatEye", "Ball", v(1.4, 5, 4), EYE, "SmoothPlastic", v(-18.4, hy + 2.4, sz * 5.2))
		put(c, "CatEyeShine", "Ball", v(0.6, 1.4, 1.4), CREAM_FUR, "SmoothPlastic", v(-19.1, hy + 3.6, sz * 4.6))
		put(c, "CatEar", "Wedge", v(3, 10, 9), CHEESE, "Fabric", v(-6, hy + 11, sz * 7), v(sz * 12, 0, 0))
		put(c, "CatEarInner", "Wedge", v(0.6, 6, 5), NOSE, "Fabric", v(-7.6, hy + 10, sz * 7), v(sz * 12, 0, 0))
		for w = 0, 1 do
			put(
				c,
				"CatWhisker",
				"Block",
				v(0.2, 0.2, 9),
				CREAM_FUR,
				"SmoothPlastic",
				v(-20, hy - 3 + w * 1.2, sz * 9),
				v(0, sz * (8 - w * 12), 0)
			)
		end
	end
	for k = -1, 1 do
		put(c, "CatHeadStripe", "Block", v(5, 0.8, 1.6), CHEESE_DARK, "Fabric", v(-10, hy + 9.2, k * 3.4))
	end
	column(c, "CatLeg", -12, y, -7, 18, 7, CHEESE, "Fabric")
	put(c, "CatPawRest", "Ball", v(9, 5, 9), CREAM_FUR, "Fabric", v(-14, y + 2.5, -7))
	put(c, "CatArm", "Cylinder", v(22, 7, 7), CHEESE, "Fabric", v(-20, y + 34, 8), v(0, 0, 28))
	put(c, "CatPawRaised", "Ball", v(8, 7, 8), CREAM_FUR, "Fabric", v(-30, y + 40, 8), nil, {
		anim = { kind = "Sway", period = 3.4, amount = 6, axis = "Z" },
	})
	for k = -1, 1 do
		put(c, "CatToeBean", "Ball", v(1, 1.8, 1.8), NOSE, "SmoothPlastic", v(-34, y + 40, 8 + k * 2.2))
	end
	for _, sz in { -1, 1 } do
		put(c, "CatHaunch", "Ball", v(18, 16, 10), CHEESE, "Fabric", v(10, y + 8, sz * 12))
		put(c, "CatHindPaw", "Ball", v(10, 4, 7), CREAM_FUR, "Fabric", v(0, y + 2, sz * 13))
	end
	-- 꼬리: 원기둥 하나 (Sway가 한 덩어리로 움직이게)
	put(c, "CatTail", "Cylinder", v(36, 6, 6), CHEESE, "Fabric", v(30, y + 14, -10), v(0, 30, 40), {
		anim = { kind = "Sway", period = 4.5, amount = 10, axis = "Y" },
	})
	append(list, MapKitShapes.transform(c, v(CX - 66, 0, CZ + 4), v(0, 180, 0))) -- 얼굴·든 앞발이 타워 쪽(+X)
end

-- 잠자는 고양이 (Pulse 숨쉬기): 몸·머리·귀·감은 눈·꼬리
local function addSleepingCat(list: { DecorSpec }, x: number, y: number, z: number, yaw: number, fur: RGB, s: number)
	local c: { DecorSpec } = {}
	put(c, "SleepCatBody", "Ball", v(14 * s, 8 * s, 10 * s), fur, "Fabric", v(0, 4 * s, 0), nil, {
		anim = { kind = "Pulse", period = 3.2 + s, amount = 0.06 },
	})
	put(c, "SleepCatHead", "Ball", v(7 * s, 6 * s, 7 * s), fur, "Fabric", v(-6 * s, 3.4 * s, 2 * s))
	for _, sz in { -1, 1 } do
		put(
			c,
			"SleepCatEar",
			"Wedge",
			v(1, 2.6 * s, 2.4 * s),
			fur,
			"Fabric",
			v(-6.4 * s, 6.8 * s, 2 * s + sz * 2 * s),
			v(0, 90, 0)
		)
	end
	put(c, "SleepCatEyes", "Block", v(0.2, 0.3, 3.4 * s), EYE, "SmoothPlastic", v(-9.4 * s, 3.8 * s, 2 * s))
	put(c, "SleepCatTail", "Cylinder", v(12 * s, 2.4 * s, 2.4 * s), fur, "Fabric", v(0, 1.4 * s, -5.4 * s), v(0, 10, 0))
	append(list, MapKitShapes.transform(c, v(x, y, z), v(0, yaw, 0)))
end

-- 카페 카운터 + 케이크 진열 + 커피 머신 + 메뉴판 + 펜던트 등 (BG, 입구 쪽 동쪽 구석)
local function addCounter(list: { DecorSpec })
	local c: { DecorSpec } = {}
	local y = FLOOR_Y
	append(
		c,
		MapKitShapes.roundedBox(
			"CafeCounter",
			v(24, 90, 110),
			MapKitLogic.PALETTE.WoodLight,
			"Wood",
			v(0, y + 45, 0),
			{ radius = 2, style = "vertical" }
		)
	)
	put(c, "CounterTop", "Block", v(28, 3, 114), { r = 240, g = 236, b = 228 }, "Marble", v(0, y + 91.5, 0))
	put(c, "CounterKick", "Block", v(25, 6, 111), MapKitLogic.PALETTE.WoodDark, "Wood", v(0, y + 3, 0))
	for k = -4, 4 do
		put(
			c,
			"CounterPanel",
			"Block",
			v(0.4, 70, 9),
			if k % 2 == 0 then MapKitLogic.PALETTE.Wood else MapKitLogic.PALETTE.WoodLight,
			"Wood",
			v(-12.2, y + 48, k * 11)
		)
	end
	local cakes: { { RGB } } = {
		{ CUSHION_PINK, { r = 220, g = 50, b = 70 } },
		{ { r = 120, g = 76, b = 52 }, { r = 250, g = 240, b = 230 } },
		{ { r = 246, g = 230, b = 170 }, { r = 220, g = 50, b = 70 } },
		{ { r = 200, g = 230, b = 190 }, { r = 250, g = 250, b = 245 } },
	}
	for k, cake in cakes do
		local cz = -40 + (k - 1) * 22
		put(
			c,
			"CakeStand",
			"Cylinder",
			v(1.2, 16, 16),
			{ r = 246, g = 246, b = 250 },
			"SmoothPlastic",
			v(0, y + 93.6, cz),
			UPRIGHT,
			{ reflectance = 0.08 }
		)
		put(c, "Cake", "Cylinder", v(9, 13, 13), cake[1], "SmoothPlastic", v(0, y + 98.6, cz), UPRIGHT)
		put(c, "CakeTopping", "Cylinder", v(1.6, 13.6, 13.6), cake[2], "SmoothPlastic", v(0, y + 103.4, cz), UPRIGHT)
		put(
			c,
			"CakeBerry",
			"Ball",
			v(3, 3, 3),
			{ r = 220, g = 40, b = 56 },
			"SmoothPlastic",
			v(0, y + 105.6, cz),
			nil,
			{ reflectance = 0.15 }
		)
	end
	append(
		c,
		MapKitShapes.roundedBox(
			"CoffeeMachine",
			v(18, 26, 22),
			{ r = 190, g = 194, b = 200 },
			"Metal",
			v(2, y + 106, 42),
			{ radius = 2 }
		)
	)
	put(
		c,
		"CoffeeCup",
		"Cylinder",
		v(7, 6, 6),
		{ r = 250, g = 250, b = 248 },
		"SmoothPlastic",
		v(-8, y + 96.5, 42),
		UPRIGHT
	)
	-- 펜던트 등 3개 (빛, 그림자 없음 — 고정이라 anim 없음)
	for k = -1, 1 do
		local lz = k * 34
		put(c, "PendantCord", "Block", v(0.3, 26, 0.3), EYE, "SmoothPlastic", v(-4, y + 152, lz))
		put(
			c,
			"PendantShade",
			"Ball",
			v(12, 7, 12),
			{ r = 60, g = 120, b = 110 },
			"Metal",
			v(-4, y + 139, lz),
			nil,
			{ reflectance = 0.15 }
		)
		put(c, "PendantBulb", "Ball", v(4.4, 4.4, 4.4), LAMP_GLOW, "Neon", v(-4, y + 135.6, lz), nil, {
			light = { kind = "Point", color = LAMP_GLOW, brightness = 1.4, range = 40 },
		})
	end
	append(list, MapKitShapes.transform(c, v(CX + 124, 0, CZ + 92), nil))
	-- 메뉴판 (동쪽 벽, 카운터 위)
	local mx = CX + SIDE_X - 0.6
	put(list, "MenuBoard", "Block", v(1, 30, 56), { r = 46, g = 52, b = 50 }, "Slate", v(mx, FLOOR_Y + 116, CZ + 92))
	put(
		list,
		"MenuFrame",
		"Block",
		v(1, 34, 60),
		MapKitLogic.PALETTE.WoodDark,
		"Wood",
		v(mx + 0.4, FLOOR_Y + 116, CZ + 92)
	)
	for k = 0, 4 do
		put(
			list,
			"MenuLine",
			"Block",
			v(0.2, 1.4, 20 + (k % 3) * 8),
			if k == 0 then CUSHION_PINK else { r = 236, g = 232, b = 220 },
			"SmoothPlastic",
			v(mx - 0.6, FLOOR_Y + 126 - k * 5, CZ + 86)
		)
	end
end

-- 천장 들보 + 팬 (Spin — 날개 두 장이 같은 중심이라 한 덩어리처럼 돌아요)
local function addCeiling(list: { DecorSpec })
	local y = WALL_TOP
	for k = -1, 0 do
		append(
			list,
			MapKitShapes.roundedBox(
				"CeilingBeam",
				v(SIDE_X * 2, 6, 6),
				MapKitLogic.PALETTE.WoodDark,
				"Wood",
				v(CX, y, CZ + 45 + k * 70),
				{ radius = 1 }
			)
		)
	end
	local fz = CZ + 45
	put(list, "FanRod", "Cylinder", v(18, 1.2, 1.2), EYE, "Metal", v(CX, y - 12, fz), UPRIGHT)
	put(list, "FanHub", "Cylinder", v(3, 6, 6), { r = 220, g = 214, b = 204 }, "Metal", v(CX, y - 22, fz), UPRIGHT)
	for k = 0, 1 do
		put(
			list,
			"FanBlade",
			"Block",
			v(46, 0.6, 6),
			MapKitLogic.PALETTE.WoodLight,
			"Wood",
			v(CX, y - 22, fz),
			v(0, k * 90, 0),
			{ anim = { kind = "Spin", period = 4 } }
		)
	end
end

-- 창가 화분(잎 Sway), 큰 화분, 장난감 쥐(Bob)·실뭉치, 바닥 발자국 길, 고양이 바구니 + 잠자는 고양이
local function addProps(list: { DecorSpec })
	local sillY = WINDOW_Y - 24
	for k, wx in { CX - 64, CX - 30, CX + 32, CX + 66 } do
		local s = 0.9 + (k % 3) * 0.12
		column(list, "PlantPot", wx, sillY, BACK_Z + 4, 7 * s, 8 * s, TERRACOTTA, "Sandstone")
		put(
			list,
			"PlantPotRim",
			"Cylinder",
			v(1.4, 9 * s, 9 * s),
			MapKitLogic.shade(TERRACOTTA, 0.85),
			"Sandstone",
			v(wx, sillY + 7 * s, BACK_Z + 4),
			UPRIGHT
		)
		for j = 0, 2 do
			put(
				list,
				"PlantLeaf",
				"Ball",
				v(7 * s, 9 * s, 7 * s),
				if j == 0 then LEAF.base elseif j == 1 then LEAF.light else LEAF.dark,
				"Grass",
				v(wx + (j - 1) * 3 * s, sillY + (11 + j * 2) * s, BACK_Z + 4 + (j % 2) * 2),
				v(0, 0, (j - 1) * 14),
				if j == 1 then { anim = { kind = "Sway", period = 5 + k * 0.5, amount = 5 } } else nil
			)
		end
	end
	for b, at in { { CX - 128, CZ - 40 }, { CX + 128, CZ - 40 } } do
		column(list, "BigPot", at[1], FLOOR_Y, at[2], 26, 22, TERRACOTTA, "Sandstone")
		put(
			list,
			"BigPotRim",
			"Cylinder",
			v(3, 25, 25),
			MapKitLogic.shade(TERRACOTTA, 0.85),
			"Sandstone",
			v(at[1], FLOOR_Y + 26, at[2]),
			UPRIGHT
		)
		column(list, "BigPlantStem", at[1], FLOOR_Y + 26, at[2], 22, 2, LEAF.dark, "Grass")
		for j = 0, 5 do
			local a = math.rad(j * 60 + b * 20)
			put(
				list,
				"BigLeaf",
				"Ball",
				v(24, 4, 14),
				if j % 3 == 0 then LEAF.base elseif j % 3 == 1 then LEAF.light else LEAF.dark,
				"Grass",
				v(at[1] + math.cos(a) * 12, FLOOR_Y + 44 + (j % 2) * 10, at[2] + math.sin(a) * 12),
				v(0, -math.deg(a), 25),
				if j == 0 then { anim = { kind = "Sway", period = 6, amount = 4 } } else nil
			)
		end
	end
	local mice = { { CX + 46, CZ + 20, 30 }, { CX + 40, CZ - 26, -60 }, { CX - 30, CZ + 46, 140 } }
	for k, m in mice do
		local mouse: { DecorSpec } = {}
		put(mouse, "ToyMouse", "Ball", v(8, 5, 5), { r = 170, g = 170, b = 180 }, "Fabric", v(0, 2.5, 0), nil, {
			anim = { kind = "Bob", period = 2.4 + k * 0.4, amount = 0.6 },
		})
		put(mouse, "ToyMouseEar", "Ball", v(1, 2.4, 2.4), NOSE, "Fabric", v(-2.6, 5, 1.6))
		put(mouse, "ToyMouseEar", "Ball", v(1, 2.4, 2.4), NOSE, "Fabric", v(-2.6, 5, -1.6))
		put(mouse, "ToyMouseTail", "Block", v(7, 0.4, 0.4), NOSE, "Fabric", v(7, 1, 0), v(0, 15, 0))
		append(list, MapKitShapes.transform(mouse, v(m[1], FLOOR_Y, m[2]), v(0, m[3], 0)))
	end
	local yarns: { { any } } = {
		{ CX + 54, CZ - 4, 9, YARN },
		{ CX + 60, CZ + 6, 6, { r = 120, g = 170, b = 230 } },
		{ CX + 50, CZ + 10, 5, CUSHION_CREAM },
	}
	for _, yarn in yarns do
		local d = yarn[3] :: number
		put(
			list,
			"FloorYarn",
			"Ball",
			v(d, d, d),
			yarn[4] :: RGB,
			"Fabric",
			v(yarn[1] :: number, FLOOR_Y + d / 2, yarn[2] :: number)
		)
	end
	put(list, "YarnThread", "Block", v(30, 0.3, 0.3), YARN, "Fabric", v(CX + 40, FLOOR_Y + 0.2, CZ - 14), v(0, 35, 0))
	for k = 0, 9 do
		local px = CX + 30 + k * 9
		local pz = CZ + 30 + k * 6 + (k % 2) * 4
		put(
			list,
			"FloorPawPrint",
			"Cylinder",
			v(0.1, 4, 4),
			CHEESE_DARK,
			"SmoothPlastic",
			v(px, FLOOR_Y + 0.08, pz),
			UPRIGHT
		)
		for t = -1, 1 do
			put(
				list,
				"FloorPawToe",
				"Cylinder",
				v(0.1, 1.4, 1.4),
				CHEESE_DARK,
				"SmoothPlastic",
				v(px - 3, FLOOR_Y + 0.08, pz + t * 1.8),
				UPRIGHT
			)
		end
	end
	append(
		list,
		MapKitShapes.rimDisc("CatBasket", 30, 4, BASKET, "WoodPlanks", v(CX - 100, FLOOR_Y + 2, CZ + 100), {
			rimColor = MapKitLogic.shade(BASKET, 0.8),
			rimWidth = 3,
			rimHeight = 8,
			segments = 14,
		})
	)
	put(
		list,
		"CatBasketPad",
		"Cylinder",
		v(1, 24, 24),
		CUSHION_PINK,
		"Fabric",
		v(CX - 100, FLOOR_Y + 4.4, CZ + 100),
		UPRIGHT
	)
	addSleepingCat(list, CX - 100, FLOOR_Y + 4.8, CZ + 100, 30, { r = 150, g = 150, b = 156 }, 1.3)
	addSleepingCat(list, CX - 48, sillY + 1, BACK_Z + 6, 0, { r = 52, g = 50, b = 54 }, 1)
	addSleepingCat(list, CX + 100, FLOOR_Y, CZ + 20, -120, { r = 246, g = 242, b = 236 }, 1.4)
end

-- 창문 햇살 그림자 조명 (고정, 창 위 — 선반 그림자가 바닥·타워에)
local function addSunSpot(list: { DecorSpec })
	put(
		list,
		"WindowSunSpot",
		"Block",
		v(6, 1, 1),
		{ r = 255, g = 244, b = 214 },
		"Neon",
		v(CX - 48, WINDOW_Y + 20, BACK_Z + 2),
		v(-35, 0, 0),
		{
			light = {
				kind = "Spot",
				color = { r = 255, g = 236, b = 200 },
				brightness = 3,
				range = 60,
				angle = 70,
				face = "Back",
				shadows = true,
			},
		}
	)
end

-- 카페 테이블 무리 (입구 쪽 바닥): 둥근 상판 + 기둥 + 의자 2개 + 컵(김) / 라테 아트 접시
local function addTables(list: { DecorSpec })
	local spots = { { CX + 20, CZ + 136, 0 }, { CX + 70, CZ + 40, 60 }, { CX - 110, CZ - 20, 70 } }
	for k, t in spots do
		local c: { DecorSpec } = {}
		local top = FLOOR_Y + 75
		column(c, "TableLeg", 0, FLOOR_Y, 0, 73, 4, MapKitLogic.PALETTE.WoodDark, "Wood")
		put(
			c,
			"TableFoot",
			"Cylinder",
			v(2, 22, 22),
			MapKitLogic.PALETTE.WoodDark,
			"Wood",
			v(0, FLOOR_Y + 1, 0),
			UPRIGHT
		)
		append(
			c,
			MapKitShapes.rimDisc("TableTop", 56, 2, CUSHION_CREAM, "Marble", v(0, top - 1, 0), {
				rimColor = MapKitLogic.PALETTE.WoodLight,
				rimWidth = 2,
				rimHeight = 2.6,
				segments = 16,
			})
		)
		for _, side in { -1, 1 } do
			local cx = side * 40
			append(
				c,
				MapKitShapes.roundedBox(
					"ChairSeat",
					v(30, 4, 30),
					if (k + side) % 2 == 0 then CUSHION_PINK else { r = 170, g = 210, b = 200 },
					"Fabric",
					v(cx, FLOOR_Y + 46, 0),
					{ radius = 1.5 }
				)
			)
			for _, lx in { -11, 11 } do
				for _, lz in { -11, 11 } do
					column(c, "ChairLeg", cx + lx, FLOOR_Y, lz, 44, 2.4, MapKitLogic.PALETTE.Wood, "Wood")
				end
			end
			put(
				c,
				"ChairBack",
				"Block",
				v(3, 34, 28),
				MapKitLogic.PALETTE.Wood,
				"Wood",
				v(cx + side * 14, FLOOR_Y + 65, 0)
			)
		end
		put(
			c,
			"TableCup",
			"Cylinder",
			v(9, 8, 8),
			{ r = 250, g = 250, b = 248 },
			"SmoothPlastic",
			v(-8, top + 4.5, 6),
			UPRIGHT,
			if k == 1 then { particle = "Steam", particleRate = 2 } else nil
		)
		put(
			c,
			"TableCoffee",
			"Cylinder",
			v(0.4, 7, 7),
			{ r = 150, g = 96, b = 60 },
			"SmoothPlastic",
			v(-8, top + 8.9, 6),
			UPRIGHT
		)
		append(
			c,
			MapKitShapes.rimDisc(
				"TablePlate",
				18,
				0.8,
				{ r = 250, g = 250, b = 248 },
				"SmoothPlastic",
				v(10, top + 0.4, -4),
				{
					rimColor = { r = 230, g = 200, b = 210 },
					rimWidth = 1.2,
					rimHeight = 1.2,
					segments = 10,
				}
			)
		)
		put(c, "TableCake", "Wedge", v(8, 6, 8), { r = 250, g = 236, b = 200 }, "SmoothPlastic", v(10, top + 4, -4))
		put(
			c,
			"TableBerry",
			"Ball",
			v(2.4, 2.4, 2.4),
			{ r = 220, g = 40, b = 56 },
			"SmoothPlastic",
			v(10, top + 7.4, -6)
		)
		append(list, MapKitShapes.transform(c, v(t[1], 0, t[2]), v(0, t[3], 0)))
	end
end

-- 서쪽 벽 고양이 액자 갤러리 (액자 틀 + 그림 속 고양이 얼굴 실루엣)
local function addGallery(list: { DecorSpec })
	local x = CX - SIDE_X + 0.8
	local frames = {
		{ z = 30, y = 96, w = 26, h = 20, c = CHEESE },
		{ z = 70, y = 104, w = 20, h = 26, c = { r = 60, g = 60, b = 66 } },
		{ z = 104, y = 92, w = 24, h = 18, c = { r = 220, g = 220, b = 224 } },
		{ z = 54, y = 74, w = 16, h = 14, c = CHEESE_DARK },
	} :: { { z: number, y: number, w: number, h: number, c: RGB } }
	for _, f in frames do
		local z, y, w, h = CZ + f.z, FLOOR_Y + f.y, f.w, f.h
		put(list, "FrameWood", "Block", v(1, h + 3, w + 3), MapKitLogic.PALETTE.WoodDark, "Wood", v(x, y, z))
		put(list, "FrameArt", "Block", v(1, h, w), { r = 250, g = 244, b = 226 }, "SmoothPlastic", v(x + 0.3, y, z))
		put(list, "FrameCatFace", "Ball", v(0.6, h * 0.5, h * 0.55), f.c, "SmoothPlastic", v(x + 0.6, y - h * 0.08, z))
		for _, sz in { -1, 1 } do
			put(
				list,
				"FrameCatEar",
				"Wedge",
				v(0.6, h * 0.22, h * 0.18),
				f.c,
				"SmoothPlastic",
				v(x + 0.6, y + h * 0.24, z + sz * h * 0.16)
			)
		end
	end
	-- 벽 선반 + 작은 고양이 인형들 (창문 벽 오른쪽 아래)
	put(
		list,
		"WallShelf",
		"Block",
		v(46, 2, 10),
		MapKitLogic.PALETTE.WoodLight,
		"Wood",
		v(CX + 100, FLOOR_Y + 70, BACK_Z + 5)
	)
	for k = 0, 4 do
		local fur = if k % 3 == 0 then CHEESE elseif k % 3 == 1 then CREAM_FUR else { r = 80, g = 80, b = 86 }
		local bx = CX + 84 + k * 8
		put(list, "ManekiBody", "Ball", v(6, 8, 6), fur, "SmoothPlastic", v(bx, FLOOR_Y + 75, BACK_Z + 5))
		put(list, "ManekiHead", "Ball", v(5, 5, 5), fur, "SmoothPlastic", v(bx, FLOOR_Y + 81, BACK_Z + 5))
	end
	-- 손 흔드는 마네키네코 하나 (Sway)
	put(list, "ManekiArm", "Ball", v(2, 4, 2), CREAM_FUR, "SmoothPlastic", v(CX + 87, FLOOR_Y + 81, BACK_Z + 7), nil, {
		anim = { kind = "Sway", period = 1.8, amount = 15, axis = "Z" },
	})
	-- 케이크 진열장 반짝임 (카운터 위)
	put(
		list,
		"CakeSparkle",
		"Block",
		v(0.4, 0.4, 0.4),
		{ r = 255, g = 250, b = 240 },
		"SmoothPlastic",
		v(CX + 124, FLOOR_Y + 108, CZ + 70),
		nil,
		{
			particle = "Sparkle",
			particleRate = 2,
			transparency = 1,
		}
	)
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addBackdrop(list)
	addPillars(list)
	addPawPrints(list)
	addShelfDecor(list)
	addCatBed(list)
	addSign(list)
	-- m5-24
	addShelfLips(list)
	addTowerSupports(list)
	addGiantCat(list)
	addCounter(list)
	addCeiling(list)
	addProps(list)
	addSunSpot(list)
	addTables(list)
	addGallery(list)
	return list
end

-- 카페 전경 → 1단 스폰 → 타워 옆모습(올려보기) → 꼭대기 캣방석
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(CX + 50, Layout.TIER2_TOP_Y + 30, CZ + 50), lookAt = v(CX, Layout.TIER2_TOP_Y, CZ) },
		-- m5-24: 타워 받침 기둥 사이를 피해 바깥 남동쪽에서 1단 스폰 선반을 내려다봐요
		{
			pos = v(CX + 36, Layout.TIER1_TOP_Y + 12, CZ - 34),
			lookAt = v(CX, Layout.TIER1_TOP_Y, CZ),
		},
		-- m5-24: 반전 샷 — 1단 아래 낮은 곳에서 창문 벽 쪽으로 올려다봐요 (하늘 대신 창·간판·치즈냥)
		{
			pos = v(CX + 30, Layout.TIER1_TOP_Y - 5, CZ + 46),
			lookAt = v(CX - 10, Layout.TIER3_TOP_Y + 8, CZ - 40),
		},
		{ pos = v(CX, Layout.TIER3_TOP_Y + 10, CZ + 14), lookAt = v(CX, Layout.TIER3_TOP_Y, CZ) },
	}
end

return Art
