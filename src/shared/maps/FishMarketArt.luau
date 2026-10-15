--!strict
-- "수산시장"(fish-market, m5-37) 아트 데이터. Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정(상자 격자·얼음 블록·생선)은 FishMarketLayout/FishMarketLogic/FishMarket 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 map origin 기준 로컬 (격자 중심 (0, −50), 상자 윗면 y 0).
--   FishMarketArt.decor() -> { DecorSpec }          상자 립·수조·물·좌판·참치 크레인·간판·항구·시장 바닥
--   FishMarketArt.introCamera() -> { IntroPoint }   넓은 샷 → 얼음 블록 → 참치 올려다보기 → 격자 위 → 출발 자리
--   FishMarketArt.courseVolume() -> Bounds          장식이 가리면 안 되는 상자 (상자 윗면 위 ~ ⚠ 표지 위)
--   FishMarketArt.SIGN_BOARD                        "수산시장" 글씨를 붙일 간판 파츠 이름 (build가 SurfaceGui를 붙여요)
--   FishMarketArt.BUDGET / LIGHTING                 Extended 예산, 맵 조명 ("새벽에서 아침으로, 수산시장 얼음 수조")
--
-- 아트 디렉션 (docs/specs/m5-37-map-fish-market.md "아트"):
--   히어로 색 = 얼음물 청록 #3CC6D8 + 참치 은청 #5A6E8C. 60 = 젖은 나무 좌판·회색 콘크리트 바닥·하늘색 아침,
--   30 = 됫박 상자 꿀색 나무, 10 = 차양 주황(Neon 아님)·간판 빨강 글씨·⚠ 노랑(위험, 런타임).
--   스케일 1 stud ≈ 1 cm: 상자 10 = 나무 됫박, 좌판 높이 90, 매달린 참치 길이 180, 차양 높이 약 2 m.
--   층: FG = 상자 립·모서리 기둥, 물 위 얼음 조각(윗면 −2 이하)·부표, MG = 좌판 6곳(차양·진열 생선)·참치 크레인·간판,
--       BG = 시장 콘크리트 바닥(−93), 창고 벽, 부두·바다·고깃배·항구 크레인·먼 산.
--   상자·얼음 블록·생선·⚠ 표지에는 anim이 없어요 (판정 파츠와 같이 움직이는 장식 금지).

local Layout = require(script.Parent.FishMarketLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds
type Extra = {
	transparency: number?,
	reflectance: number?,
	castShadow: boolean?,
	light: MapKitLogic.LightSpec?,
	particle: string?,
	particleRate: number?,
	anim: MapKitLogic.AnimSpec?,
}

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local FishMarketArt = {}

FishMarketArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
FishMarketArt.SIGN_BOARD = "MarketSignBoard"

-- 높이 (origin 로컬). 상자 윗면 0, 낙하선 −6, 안전망 −40
FishMarketArt.WATER_Y = Layout.WATER_Y -- 물 표면 −4
FishMarketArt.RIM_TOP_Y = -3 -- 수조 테두리·좌판 윗면 (−3 이하)
FishMarketArt.TANK_FLOOR_Y = -60 -- 수조 바닥 (물 아래로 보여요)
FishMarketArt.FLOOR_Y = -93 -- 시장 콘크리트 바닥 (좌판 높이 90)
FishMarketArt.SEA_Y = -101 -- 부두 아래 바다
FishMarketArt.ICE_CHUNK_TOP_MAX = -2 -- 물 위 얼음 조각 윗면 상한 (밟을 데로 안 보이게)
FishMarketArt.TANK_HALF = 68 -- 수조 안쪽 반폭 (격자 반폭 42.5 + 25.5)
FishMarketArt.SIGHT_TOP = 36 -- ⚠ 표지(높이 30, 반 높이 5) 위까지

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 색
local WATER = c(60, 198, 216) -- 히어로 청록
local WATER_DEEP = c(30, 112, 132)
local TANK_TILE = c(150, 206, 214)
local TANK_TILE_DARK = c(104, 160, 172)
local TUNA = c(90, 110, 140) -- 히어로 은청
local TUNA_DARK = c(46, 58, 84)
local TUNA_BELLY = c(206, 214, 226)
local FINLET = c(222, 196, 84)
local CRATE_LIP = c(132, 92, 54)
local CRATE_POST = c(150, 106, 64)
local WET_WOOD = c(116, 90, 70)
local WET_WOOD_SHADES = MapKitLogic.shades(WET_WOOD)
local RIM_WOOD = c(146, 112, 80)
local CONCRETE = c(150, 154, 158)
local CONCRETE_WET = c(112, 118, 126)
local CONCRETE_LIGHT = c(176, 178, 180)
local AWNING_ORANGE = c(232, 126, 56)
local AWNING_WHITE = c(242, 236, 224)
local SIGN_WOOD = c(132, 90, 54)
local SIGN_FACE = c(244, 230, 200)
local SIGN_RED = c(184, 44, 40)
local STEEL = c(168, 174, 180)
local CRANE = c(58, 98, 122)
local CRANE_DARK = c(38, 62, 80)
local ROPE = c(176, 150, 104)
local ICE = c(206, 238, 248)
local SNOW = c(232, 244, 250)
local STYRO = c(240, 242, 238)
local BASKET_BLUE = c(52, 112, 196)
local BASKET_GREEN = c(72, 158, 96)
local BOOT = c(44, 66, 58)
local SEA = c(40, 112, 160)
local SEA_LIGHT = c(92, 160, 196)
local HILL = c(96, 120, 140)
local HULL = c(236, 238, 240)
local HULL_STRIPE = c(36, 50, 98)
local HULL_BOTTOM = c(44, 84, 74)
local WAREHOUSE = c(166, 176, 186)
local WAREHOUSE_ROOF = c(98, 120, 142)
local BULB = c(255, 214, 150)
local GULL = c(244, 244, 240)
local BUOY_ORANGE = c(236, 140, 60)
local OCTOPUS = c(178, 98, 112)
local CLAM = c(214, 204, 188)
local MACKEREL_BACK = c(58, 96, 118)
local BREAM = c(214, 140, 132)
local SILVER = c(196, 204, 214)
local BRASS = c(196, 160, 80)

-- 맵 조명: 이른 아침 수산시장 (ClockTime 7.5, 차가운 하늘빛 Ambient, 물안개 Haze)
FishMarketArt.LIGHTING = {
	ClockTime = 7.5,
	Brightness = 2.8,
	Ambient = c(150, 175, 200),
	OutdoorAmbient = c(140, 166, 196),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.8,
	ShadowSoftness = 0.3,
	ExposureCompensation = 0.05,
	Atmosphere = {
		Density = 0.28,
		Offset = 0.05,
		Color = c(196, 216, 232),
		Decay = c(132, 166, 204),
		Glare = 0.25,
		Haze = 0.9,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.14, TintColor = c(255, 246, 232) },
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 0.95 },
	SunRays = { Intensity = 0.05, Spread = 0.5 },
} :: MapLighting.LightingPreset

local function part(
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
		s.transparency = extra.transparency
		s.reflectance = extra.reflectance
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

-- 로컬 목록을 (offset, yaw)로 옮겨 붙여요
local function place(list: { DecorSpec }, localList: { DecorSpec }, offset: Vec3, yaw: number?)
	append(list, MapKitShapes.transform(localList, offset, if yaw then v(0, yaw, 0) else nil))
end

---------------------------------------------------------------- 상자 립·모서리 기둥 (FG)
local function crateTrim(list: { DecorSpec })
	local size = Layout.CRATE_SIZE
	local h = Layout.CRATE_HEIGHT
	for _, crate in Layout.crates() do
		local x, z = crate.centerX, crate.centerZ
		-- 윗면 테두리 립: 윗면보다 0.1 낮게, 바깥으로 0.4 (밟는 면 위로 안 올라와요)
		append(list, MapKitShapes.lipTrim("CrateLip", v(size, 0, size), 0.4, 0.5, CRATE_LIP, "Wood", v(x, -0.35, z)))
		-- 모서리 기둥 (짙은 나무, 윗면 아래) — 대각선 두 모서리만
		for _, sx in { -1, 1 } do
			for _, sz in { sx } do
				part(
					list,
					"CratePost",
					"Block",
					v(0.7, h - 1, 0.7),
					CRATE_POST,
					"Wood",
					v(x + sx * (size / 2 + 0.15), -h / 2 - 0.5, z + sz * (size / 2 + 0.15))
				)
			end
		end
	end
end

---------------------------------------------------------------- 수조·물·얼음 조각·부표 (FG)
local function tank(list: { DecorSpec })
	local cz = Layout.GRID_CENTER_Z
	local half = FishMarketArt.TANK_HALF
	local rimTop = FishMarketArt.RIM_TOP_Y
	local floorY = FishMarketArt.FLOOR_Y
	local tankFloor = FishMarketArt.TANK_FLOOR_Y
	local inner = half * 2

	-- 물 표면 1장 (큰 반투명 판은 이것 하나)
	part(
		list,
		"Water",
		"Block",
		v(inner, 0.4, inner),
		WATER,
		"Glass",
		v(0, FishMarketArt.WATER_Y - 0.2, cz),
		nil,
		{ transparency = 0.35, reflectance = 0.15, castShadow = false }
	)
	-- 수조 바닥 (물 아래, 짙은 청록 타일) + 배수구
	part(list, "TankFloor", "Block", v(inner, 2, inner), WATER_DEEP, "CeramicTiles", v(0, tankFloor - 1, cz))
	part(list, "TankDrain", "Cylinder", v(0.6, 10, 10), STEEL, "Metal", v(18, tankFloor + 0.1, cz - 20), v(0, 0, 90))
	-- 수조 안쪽 벽 (타일, 물 아래로 보여요) — 윗면 −3.6
	local wallH = rimTop - 0.6 - tankFloor
	local wallY = tankFloor + wallH / 2
	for _, side in { -1, 1 } do
		part(
			list,
			"TankWall",
			"Block",
			v(1, wallH, inner),
			TANK_TILE,
			"CeramicTiles",
			v(side * (half + 0.5), wallY, cz)
		)
		part(
			list,
			"TankWall",
			"Block",
			v(inner + 2, wallH, 1),
			TANK_TILE_DARK,
			"CeramicTiles",
			v(0, wallY, cz + side * (half + 0.5))
		)
	end
	-- 수조 테두리 = 젖은 나무 좌판 상판 (윗면 −3, 폭 12) + 앞 립
	local rimW = 12
	local outer = half + 1 + rimW
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.bevelBox(
				"TankRim",
				v(rimW, 1.2, outer * 2),
				RIM_WOOD,
				"WoodPlanks",
				v(side * (half + 1 + rimW / 2), rimTop - 0.6, cz),
				0.4
			)
		)
		append(
			list,
			MapKitShapes.bevelBox(
				"TankRim",
				v(inner + 2, 1.2, rimW),
				MapKitLogic.shade(RIM_WOOD, 0.92),
				"WoodPlanks",
				v(0, rimTop - 0.6, cz + side * (half + 1 + rimW / 2)),
				0.4,
				v(0, 0, 0)
			)
		)
	end
	-- 좌판 몸통 (바닥까지, 세로 모서리 둥글게)
	local bodyH = rimTop - 1.2 - floorY
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.roundedBox(
				"TankCounter",
				v(4, bodyH, outer * 2),
				WET_WOOD_SHADES.base,
				"WoodPlanks",
				v(side * (outer - 2), floorY + bodyH / 2, cz),
				{ style = "vertical", radius = 1.5 }
			)
		)
		append(
			list,
			MapKitShapes.roundedBox(
				"TankCounter",
				v(outer * 2, bodyH, 4),
				WET_WOOD_SHADES.dark,
				"WoodPlanks",
				v(0, floorY + bodyH / 2, cz + side * (outer - 2)),
				{ style = "vertical", radius = 1.5 }
			)
		)
		-- 좌판 앞 판자 띠 (밝은 나무 2줄)
		for k = 1, 2 do
			local y = floorY + bodyH * (0.35 + 0.3 * k)
			part(
				list,
				"CounterBand",
				"Block",
				v(0.5, 3, outer * 2 - 4),
				WET_WOOD_SHADES.light,
				"Wood",
				v(side * (outer + 0.1), y, cz)
			)
			part(
				list,
				"CounterBand",
				"Block",
				v(outer * 2 - 4, 3, 0.5),
				WET_WOOD_SHADES.light,
				"Wood",
				v(0, y, cz + side * (outer + 0.1))
			)
		end
	end

	-- 물 위 얼음 조각 무리: 코스 밖 가장자리 + 물길 가운데 (윗면 −2 이하, 반투명 작게)
	local chunkSpots: { Vec3 } = {}
	local rng = MapKitShapes.rng(3721)
	-- 바깥 물 (격자 가장자리 42.5 ~ 수조 벽 68)
	for i = 1, 22 do
		local angle = rng:range(0, 2 * math.pi)
		local radius = rng:range(50, 64)
		local x = math.clamp(math.cos(angle) * radius, -64, 64)
		local z = math.clamp(math.sin(angle) * radius, -64, 64)
		if math.abs(x) < 46 and math.abs(z) < 46 then
			x = if x < 0 then -52 else 52
		end
		table.insert(chunkSpots, v(x, 0, cz + z))
		local _ = i
	end
	-- 물길 가운데 (상자 사이 교차점 몇 곳)
	for _, cell in { { 0.5, 1.5 }, { 2.5, 3.5 }, { 4.5, 0.5 }, { 1.5, 4.5 }, { 3.5, 2.5 } } do
		table.insert(chunkSpots, v(Layout.colX(cell[1]), 0, Layout.rowZ(cell[2])))
	end
	for i, spot in chunkSpots do
		local s = rng:range(1.4, 2.8)
		local h = rng:range(0.8, 1.4)
		local top = FishMarketArt.WATER_Y + h * 0.45
		part(
			list,
			"IceChunk",
			if i % 3 == 0 then "Wedge" else "Block",
			v(s, h, s * rng:range(0.7, 1.2)),
			ICE,
			"Ice",
			v(spot.x, math.min(top, FishMarketArt.ICE_CHUNK_TOP_MAX) - h / 2, spot.z),
			v(rng:range(-12, 12), rng:range(0, 360), rng:range(-12, 12)),
			{ transparency = 0.15, castShadow = false }
		)
	end
	-- 물 위 부표 (코스 밖 가장자리, Bob)
	for i, spot in { v(-58, 0, cz - 58), v(60, 0, cz + 30), v(-56, 0, cz + 52) } do
		local anim: MapKitLogic.AnimSpec = { kind = "Bob", period = 3 + i * 0.4, amount = 0.4 }
		part(
			list,
			"Buoy",
			"Ball",
			v(3.4, 3.4, 3.4),
			BUOY_ORANGE,
			"SmoothPlastic",
			v(spot.x, FishMarketArt.WATER_Y + 0.6, spot.z),
			nil,
			{ anim = anim }
		)
	end
	-- 물안개 (가장자리 물 위, 낮게)
	for i, spot in { v(-58, 0, cz - 40), v(58, 0, cz + 40), v(40, 0, cz - 60), v(-40, 0, cz + 60) } do
		part(
			list,
			"MistSource",
			"Block",
			v(10, 0.2, 10),
			WATER,
			"SmoothPlastic",
			v(spot.x, FishMarketArt.WATER_Y + 0.3, spot.z),
			nil,
			{ transparency = 1, particle = "ColdMist", particleRate = 2 + (i % 2) }
		)
	end
	-- 물 아래 헤엄치는 물고기 그림자 (코스 밖 물 아래)
	for i, spot in { v(-55, -14, cz - 20), v(54, -18, cz + 10), v(10, -22, cz + 58), v(-20, -16, cz - 60) } do
		local fish: { DecorSpec } = {}
		part(fish, "TankFish", "Cylinder", v(7, 2.4, 2.4), MACKEREL_BACK, "SmoothPlastic", v(0, 0, 0))
		part(fish, "TankFish", "Ball", v(2.4, 2.4, 2.4), MACKEREL_BACK, "SmoothPlastic", v(3.5, 0, 0))
		part(fish, "TankFish", "Wedge", v(0.3, 2.2, 2), MACKEREL_BACK, "SmoothPlastic", v(-4.4, 0, 0), v(0, 90, 0))
		place(list, fish, spot, i * 70)
	end
end

---------------------------------------------------------------- 진열 생선 (좌판 위 소품)
-- 길이 len, 축 = 로컬 X, 머리 +X. 5파츠
local function fishProp(back: RGB, len: number): { DecorSpec }
	local d = len * 0.26
	local list: { DecorSpec } = {}
	part(
		list,
		"DisplayFish",
		"Cylinder",
		v(len * 0.55, d, d),
		back,
		"SmoothPlastic",
		v(0, 0, 0),
		nil,
		{ reflectance = 0.2 }
	)
	part(
		list,
		"DisplayFish",
		"Ball",
		v(d, d, d),
		back,
		"SmoothPlastic",
		v(len * 0.27, 0, 0),
		nil,
		{ reflectance = 0.2 }
	)
	part(list, "DisplayFish", "Ball", v(d * 0.7, d * 0.7, d * 0.7), SILVER, "SmoothPlastic", v(-len * 0.28, 0, 0))
	part(
		list,
		"DisplayFish",
		"Wedge",
		v(d * 0.2, d * 1.1, d * 0.9),
		back,
		"SmoothPlastic",
		v(-len * 0.42, 0, 0),
		v(0, 90, 0)
	)
	part(
		list,
		"DisplayFishEye",
		"Ball",
		v(d * 0.25, d * 0.25, d * 0.25),
		c(30, 30, 34),
		"SmoothPlastic",
		v(len * 0.33, d * 0.12, d * 0.36)
	)
	return list
end

-- 좌판 하나 (로컬: 앞 = −Z, 상판 윗면 y −3, 바닥 −93). hero면 진열·조명이 더 많아요.
local function stall(seed: number, hero: boolean, width: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local rng = MapKitShapes.rng(seed)
	local floorY = FishMarketArt.FLOOR_Y
	local topY = FishMarketArt.RIM_TOP_Y
	local depth = 64
	local bodyH = topY - floorY
	-- 몸통 + 상판 + 앞 판자
	append(
		list,
		MapKitShapes.roundedBox(
			"StallCounter",
			v(width, bodyH - 2, depth),
			WET_WOOD_SHADES.dark,
			"WoodPlanks",
			v(0, floorY + (bodyH - 2) / 2, 0),
			{ style = "vertical", radius = 2 }
		)
	)
	-- 상판 + 앞 립 (한 단 어두운 띠)
	part(list, "StallTop", "Block", v(width + 4, 2, depth + 4), WET_WOOD_SHADES.light, "WoodPlanks", v(0, topY - 1, 0))
	part(
		list,
		"StallTopLip",
		"Block",
		v(width + 5, 1, 1),
		WET_WOOD_SHADES.dark,
		"Wood",
		v(0, topY - 1.6, -depth / 2 - 2.4)
	)
	for k = 1, 3 do
		part(
			list,
			"StallPlank",
			"Block",
			v(width - 6, 6, 0.6),
			if k == 2 then WET_WOOD_SHADES.base else WET_WOOD_SHADES.light,
			"Wood",
			v(0, floorY + bodyH * k / 4, -depth / 2 - 0.3)
		)
	end
	-- 얼음 진열대 (흰 얼음 + 앞쪽 경사)
	part(
		list,
		"IceBed",
		"Block",
		v(width - 10, 3, depth - 14),
		SNOW,
		"Snow",
		v(0, topY + 1.5, 4),
		nil,
		if hero then { particle = "Frost", particleRate = 2 } else nil
	)
	part(list, "IceBed", "Wedge", v(width - 10, 3, 8), SNOW, "Snow", v(0, topY + 1.5, -depth / 2 + 7), v(0, 0, 0))
	-- 진열 생선 (얼음 위, 비스듬히 줄지어)
	local fishCount = if hero then 6 else 3
	for i = 1, fishCount do
		local len = rng:range(14, 22)
		local x = -width / 2 + 14 + (i - 1) * (width - 28) / math.max(fishCount - 1, 1)
		local back = if i % 3 == 0 then BREAM elseif i % 3 == 1 then MACKEREL_BACK else TUNA
		place(list, fishProp(back, len), v(x, topY + 3 + len * 0.13, rng:range(-6, 12)), rng:range(-110, -70))
	end
	if hero then
		-- 문어 (몸통 + 다리 4) · 조개 무리
		local ox, oz = width / 2 - 18, -4
		part(list, "Octopus", "Ball", v(13, 13, 13), OCTOPUS, "SmoothPlastic", v(ox, topY + 9, oz))
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			part(
				list,
				"OctopusLeg",
				"Cylinder",
				v(12, 3, 3),
				MapKitLogic.shade(OCTOPUS, 0.9),
				"SmoothPlastic",
				v(ox + math.cos(a) * 8, topY + 4, oz + math.sin(a) * 8),
				v(0, -k * 90 - 45, -8)
			)
		end
		for k = 1, 4 do
			part(
				list,
				"Clam",
				"Cylinder",
				v(1.6, 4.5, 4.5),
				CLAM,
				"SmoothPlastic",
				v(-width / 2 + 16 + k * 5, topY + 3.6, -14 + (k % 3) * 3),
				v(0, k * 40, 90 + (k % 2) * 12)
			)
		end
	end
	-- 가격표 막대 (흰 카드)
	for k = 1, if hero then 4 else 2 do
		local x = -width / 2 + 20 + (k - 1) * (width - 40) / math.max((if hero then 4 else 2) - 1, 1)
		part(
			list,
			"PriceStick",
			"Block",
			v(0.6, 10, 0.6),
			WET_WOOD_SHADES.dark,
			"Wood",
			v(x, topY + 5, -depth / 2 + 10)
		)
		part(
			list,
			"PriceCard",
			"Block",
			v(9, 5, 0.4),
			c(250, 248, 240),
			"SmoothPlastic",
			v(x, topY + 11, -depth / 2 + 10)
		)
		part(
			list,
			"PriceMark",
			"Block",
			v(5, 1.2, 0.5),
			SIGN_RED,
			"SmoothPlastic",
			v(x, topY + 11.4, -depth / 2 + 9.85)
		)
	end
	-- 뒤 낮은 선반(스티로폼 상자) + 기둥 4개 + 차양 (주황·흰 줄무늬, 앞으로 기울어짐). 뒤 판벽은 없어요(시야가 트이게)
	part(
		list,
		"StallShelf",
		"Block",
		v(width - 8, 26, 10),
		WET_WOOD_SHADES.base,
		"WoodPlanks",
		v(0, topY + 13, depth / 2 - 4)
	)
	part(list, "StallShelfBox", "Block", v(30, 12, 9), STYRO, "SmoothPlastic", v(-width / 4, topY + 32, depth / 2 - 4))
	part(
		list,
		"StallShelfBox",
		"Block",
		v(30, 12, 9),
		STYRO,
		"SmoothPlastic",
		v(width / 6, topY + 32, depth / 2 - 4),
		v(0, 4, 0)
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local postH = if sz < 0 then 88 else 104
			append(
				list,
				MapKitShapes.capsule(
					"StallPost",
					postH,
					3.4,
					STEEL,
					"Metal",
					v(sx * (width / 2 - 2), topY + postH / 2, sz * (depth / 2 + 2)),
					v(0, 0, 90)
				)
			)
		end
	end
	local stripes = math.max(4, math.floor(width / 24))
	local stripeW = width / stripes
	local awningY = topY + 96
	for k = 0, stripes - 1 do
		local x = -width / 2 + stripeW * (k + 0.5)
		local color = if k % 2 == 0 then AWNING_ORANGE else AWNING_WHITE
		part(list, "Awning", "Block", v(stripeW, 1.2, depth + 24), color, "Fabric", v(x, awningY, -6), v(-14, 0, 0))
		-- 차양 끝 늘어진 천 (주황 칸만 흔들려요)
		local flapExtra: Extra? = if k % 2 == 0
			then { anim = { kind = "Sway" :: "Sway", period = 4 + (k % 3) * 0.7, amount = 6, axis = "X" :: "X" } }
			else nil
		part(
			list,
			"AwningFlap",
			"Block",
			v(stripeW, 8, 0.6),
			color,
			"Fabric",
			v(x, awningY - 7.2, -depth / 2 - 15.6),
			nil,
			flapExtra
		)
	end
	-- 백열등 (차양 아래, hero만 빛)
	part(list, "StallBulbCord", "Block", v(0.4, 14, 0.4), c(40, 40, 40), "SmoothPlastic", v(0, awningY - 10, -6))
	part(
		list,
		"StallBulb",
		"Ball",
		v(4, 4, 4),
		BULB,
		"Neon",
		v(0, awningY - 18, -6),
		nil,
		if hero
			then {
				light = { kind = "Point", color = c(255, 196, 130), brightness = 1.6, range = 36 },
				particle = if seed == 105 then "Dust" else nil,
				particleRate = if seed == 105 then 1.5 else nil,
			}
			else nil
	)
	return list
end

---------------------------------------------------------------- 매달린 참치 + 크레인 (히어로 ①)
local UPRIGHT = v(0, 0, 90)

local function tuna(list: { DecorSpec }, at: Vec3)
	-- 꼬리·지느러미만 천천히 흔들려요 (anim은 파츠마다 제자리 회전이라 몸통 전체 흔들기는 못 해요 — 결정 기록 D8)
	local finSway: MapKitLogic.AnimSpec = { kind = "Sway", period = 7, amount = 3, axis = "Z" }
	local local_: { DecorSpec } = {}
	-- 몸통: 아래(머리, y −84) → 위(꼬리자루, y +80). 공을 촘촘히 겹쳐 방추형 실루엣을 만들어요.
	-- 등(짙은 남청)은 +X 쪽, 배(은빛)는 −X 쪽으로 비켜 겹친 공 줄이에요.
	local beads = 17
	for i = 0, beads - 1 do
		local t = i / (beads - 1)
		local y = -84 + t * 164
		-- 머리 쪽 1/3에서 가장 굵고(54) 꼬리 쪽으로 가늘어져요
		local profile = math.sin(math.pi * math.min(1, (t + 0.08) ^ 0.8))
		local d = math.max(12, 56 * profile ^ 0.75)
		part(local_, "Tuna", "Ball", v(d, d, d), TUNA, "SmoothPlastic", v(0, y, 0), nil, { reflectance = 0.25 })
		do
			local bd = d * 0.88
			part(
				local_,
				"TunaBelly",
				"Ball",
				v(bd, bd, bd),
				TUNA_BELLY,
				"SmoothPlastic",
				v(-d * 0.1, y, 0),
				nil,
				{ reflectance = 0.3 }
			)
			local kd = d * 0.8
			part(local_, "TunaBack", "Ball", v(kd, kd, kd), TUNA_DARK, "SmoothPlastic", v(d * 0.14, y, 0))
		end
	end
	-- 꼬리 지느러미 (초승달: 판 두 장이 V로)
	for _, s in { -1, 1 } do
		part(
			local_,
			"TunaTail",
			"Block",
			v(58, 12, 3),
			TUNA_DARK,
			"SmoothPlastic",
			v(s * 18, 102, 0),
			v(0, 0, s * 54),
			{ anim = finSway }
		)
	end
	-- 등지느러미·배지느러미·가슴지느러미
	part(
		local_,
		"TunaFin",
		"Wedge",
		v(3, 22, 14),
		TUNA_DARK,
		"SmoothPlastic",
		v(26, 14, 0),
		v(0, 90, 0),
		{ anim = finSway }
	)
	part(
		local_,
		"TunaFin",
		"Wedge",
		v(3, 16, 10),
		TUNA_DARK,
		"SmoothPlastic",
		v(-24, 20, 0),
		v(0, -90, 0),
		{ anim = finSway }
	)
	for _, s in { -1, 1 } do
		part(
			local_,
			"TunaFin",
			"Block",
			v(22, 6, 2),
			TUNA_DARK,
			"SmoothPlastic",
			v(4, -38, s * 22),
			v(0, 0, -60),
			{ anim = finSway }
		)
	end
	-- 노란 토막지느러미 (꼬리 쪽 등·배)
	for k = 0, 4 do
		local y = 44 + k * 8
		local r = 20 - k * 3
		part(local_, "TunaFinlet", "Wedge", v(1.5, 4, 3.5), FINLET, "SmoothPlastic", v(r, y, 0), v(0, 90, 0))
		part(local_, "TunaFinlet", "Wedge", v(1.5, 4, 3.5), FINLET, "SmoothPlastic", v(-r, y, 0), v(0, -90, 0))
	end
	-- 눈·입
	for _, s in { -1, 1 } do
		part(local_, "TunaEye", "Ball", v(10, 10, 10), c(236, 238, 240), "SmoothPlastic", v(4, -62, s * 15))
		part(local_, "TunaPupil", "Ball", v(6, 6, 6), c(20, 22, 30), "SmoothPlastic", v(4.5, -63, s * 18.5))
	end
	part(local_, "TunaMouth", "Block", v(14, 1.5, 22), TUNA_DARK, "SmoothPlastic", v(-2, -84, 0), v(0, 0, 18))
	-- 꼬리에 감은 밧줄 + 갈고리 + 줄
	append(local_, MapKitShapes.ring("TunaRope", 9, 2.2, 3, 10, ROPE, "Fabric", v(0, 80, 0)))
	part(local_, "HookShank", "Cylinder", v(26, 2.4, 2.4), STEEL, "Metal", v(0, 118, 0), UPRIGHT, { reflectance = 0.3 })
	append(local_, MapKitShapes.ring("Hook", 7, 2.2, 2.2, 10, STEEL, "Metal", v(0, 106, 0), v(90, 0, 0)))
	part(local_, "HookBlock", "Block", v(8, 12, 6), CRANE_DARK, "Metal", v(0, 136, 0))
	part(local_, "CraneCable", "Cylinder", v(58, 1.2, 1.2), c(50, 52, 56), "Metal", v(0, 171, 0), UPRIGHT)
	place(list, local_, at)
end

local function crane(list: { DecorSpec }, base: Vec3, tipX: number, armY: number)
	local floorY = FishMarketArt.FLOOR_Y
	local mastH = armY + 20 - floorY
	-- 기둥 (세로 모서리 둥근 상자 + 대각 보강재)
	append(
		list,
		MapKitShapes.roundedBox(
			"CraneMast",
			v(14, mastH, 14),
			CRANE,
			"Metal",
			v(base.x, floorY + mastH / 2, base.z),
			{ style = "vertical", radius = 2 }
		)
	)
	for k = 0, 5 do
		local y = floorY + 30 + k * (mastH - 60) / 5
		part(
			list,
			"CraneBrace",
			"Block",
			v(1.4, 26, 15),
			CRANE_DARK,
			"Metal",
			v(base.x + 7.3, y, base.z),
			v(if k % 2 == 0 then 32 else -32, 0, 0)
		)
	end
	-- 받침 + 운전실
	append(
		list,
		MapKitShapes.bevelBox("CraneBase", v(40, 10, 40), CRANE_DARK, "Metal", v(base.x, floorY + 5, base.z), 2)
	)
	append(
		list,
		MapKitShapes.roundedBox(
			"CraneCab",
			v(22, 18, 18),
			c(220, 224, 228),
			"Metal",
			v(base.x - 14, armY - 8, base.z),
			{ style = "vertical", radius = 2 }
		)
	)
	part(
		list,
		"CraneCabWindow",
		"Block",
		v(0.4, 8, 14),
		c(120, 170, 200),
		"Glass",
		v(base.x - 25.2, armY - 6, base.z),
		nil,
		{ reflectance = 0.3 }
	)
	-- 팔 (기둥 → 참치 위 끝까지) + 평형추
	local armLen = math.abs(base.x - tipX) + 30
	local armMid = (base.x + tipX) / 2 - 5
	append(list, MapKitShapes.bevelBox("CraneArm", v(armLen, 10, 10), CRANE, "Metal", v(armMid, armY, base.z), 1.2))
	for k = 0, 6 do
		part(
			list,
			"CraneArmRib",
			"Block",
			v(1.2, 11, 11),
			CRANE_DARK,
			"Metal",
			v(armMid - armLen / 2 + 10 + k * (armLen - 20) / 6, armY, base.z)
		)
	end
	append(
		list,
		MapKitShapes.roundedBox(
			"CraneWeight",
			v(26, 22, 20),
			c(70, 76, 84),
			"Concrete",
			v(base.x + 28, armY - 4, base.z),
			{ style = "vertical", radius = 2 }
		)
	)
	-- 팔 끝 도르래
	part(list, "CranePulley", "Cylinder", v(4, 12, 12), CRANE_DARK, "Metal", v(tipX, armY - 6, base.z), v(0, 90, 0))
end

---------------------------------------------------------------- 간판 "수산시장" (히어로 ②)
local function sign(list: { DecorSpec }, at: Vec3, yaw: number)
	local local_: { DecorSpec } = {}
	append(
		local_,
		MapKitShapes.bevelBox("SignBoardBack", v(120, 4, 30), SIGN_FACE, "Wood", v(0, 0, 0), 0.8, v(90, 0, 0))
	)
	-- 글씨판 (얇은 판, 윗면(Top)이 앞(+Z)을 봐요 — build가 이 면에 SurfaceGui "수산시장"을 붙여요)
	part(
		local_,
		FishMarketArt.SIGN_BOARD,
		"Block",
		v(108, 0.2, 24),
		SIGN_FACE,
		"SmoothPlastic",
		v(0, 0, 2.1),
		v(90, 0, 0)
	)
	-- 글씨판 위아래 빨간 띠 (시장 간판 느낌, 글씨는 SurfaceGui)
	for _, sy in { -1, 1 } do
		part(local_, "SignStripe", "Block", v(108, 1.4, 0.3), SIGN_RED, "SmoothPlastic", v(0, sy * 10.6, 2.3))
	end
	-- 간판 나무 테두리
	append(
		local_,
		MapKitShapes.lipTrim("SignFrame", v(120, 0, 30), 3, 5, SIGN_WOOD, "Wood", v(0, 0, -0.5), v(90, 0, 0))
	)
	-- 지붕 (작은 박공) + 다리
	part(local_, "SignRoof", "Wedge", v(130, 8, 7), SIGN_WOOD, "WoodPlanks", v(0, 19, -2), v(0, 180, 0))
	part(local_, "SignRoof", "Wedge", v(130, 8, 7), SIGN_WOOD, "WoodPlanks", v(0, 19, 3), v(0, 0, 0))
	-- 다리: 간판 아래에서 시장 바닥까지
	local legLen = at.y - 15 - FishMarketArt.FLOOR_Y
	for _, sx in { -1, 1 } do
		part(local_, "SignLeg", "Block", v(4, legLen, 4), SIGN_WOOD, "Wood", v(sx * 50, -15 - legLen / 2, -1))
	end
	place(list, local_, at, yaw)
end

---------------------------------------------------------------- 바닥·창고 벽 (BG)
local function ground(list: { DecorSpec })
	local floorY = FishMarketArt.FLOOR_Y
	-- 시장 콘크리트 바닥 (x ±900, z +700 ~ −260)
	part(list, "MarketFloor", "Block", v(1800, 4, 960), CONCRETE, "Concrete", v(0, floorY - 2, 220))
	-- 젖은 자국·배수로 (조금 어둡게, 바닥 위 0.1)
	local rng = MapKitShapes.rng(918)
	for i = 1, 9 do
		local x = rng:range(-260, 260)
		local z = rng:range(-240, 200)
		if math.abs(x) < 110 and z > -150 and z < 50 then
			x += if x < 0 then -120 else 120
		end
		part(
			list,
			"WetPatch",
			"Cylinder",
			v(0.2, rng:range(30, 70), rng:range(30, 70)),
			CONCRETE_WET,
			"Slate",
			v(x, floorY + 0.1, z),
			v(0, 0, 90)
		)
		local _ = i
	end
	for _, z in { -150, 60 } do
		part(list, "Drain", "Block", v(600, 0.3, 6), c(70, 74, 80), "DiamondPlate", v(0, floorY + 0.15, z))
	end
	-- 바닥 줄눈 (밝은 띠)
	for k = -3, 3 do
		part(list, "FloorSeam", "Block", v(2, 0.25, 960), CONCRETE_LIGHT, "Concrete", v(k * 120, floorY + 0.12, 220))
	end
	-- 창고 벽 (양옆·뒤, 셔터 + 지붕) — 수평 시야가 비지 않게
	local function warehouse(x: number, z: number, w: number, d: number, yaw: number, seed: number)
		local local_: { DecorSpec } = {}
		local h = 240
		append(
			local_,
			MapKitShapes.roundedBox(
				"Warehouse",
				v(w, h, d),
				WAREHOUSE,
				"Concrete",
				v(0, floorY + h / 2, 0),
				{ style = "vertical", radius = 4 }
			)
		)
		part(
			local_,
			"WarehouseRoof",
			"Wedge",
			v(w + 10, 40, d / 2 + 6),
			WAREHOUSE_ROOF,
			"CorrodedMetal",
			v(0, floorY + h + 20, -d / 4 - 1)
		)
		part(
			local_,
			"WarehouseRoof",
			"Wedge",
			v(w + 10, 40, d / 2 + 6),
			WAREHOUSE_ROOF,
			"CorrodedMetal",
			v(0, floorY + h + 20, d / 4 + 1),
			v(0, 180, 0)
		)
		local shutters = math.max(2, math.floor(w / 110))
		for k = 0, shutters - 1 do
			local sx = -w / 2 + w * (k + 0.5) / shutters
			part(
				local_,
				"Shutter",
				"Block",
				v(w / shutters - 30, 110, 1),
				MapKitLogic.shade(WAREHOUSE_ROOF, 1.1 + (k + seed) % 2 * 0.15),
				"DiamondPlate",
				v(sx, floorY + 55, -d / 2 - 0.5)
			)
		end
		part(
			local_,
			"WarehouseBand",
			"Block",
			v(w, 10, 1),
			c(64, 104, 140),
			"SmoothPlastic",
			v(0, floorY + h - 30, -d / 2 - 0.5)
		)
		place(list, local_, v(x, 0, z), yaw)
	end
	warehouse(-560, -40, 520, 120, -90, 1)
	warehouse(560, -40, 520, 120, 90, 2)
	warehouse(-300, 560, 560, 120, 180, 3)
	warehouse(300, 560, 560, 120, 180, 4)
end

---------------------------------------------------------------- 부두·바다·배·항구 크레인 (히어로 ③)
local function boat(list: { DecorSpec }, at: Vec3, yaw: number, scale: number, cabinColor: RGB)
	local l: { DecorSpec } = {}
	local L, W, H = 150 * scale, 44 * scale, 30 * scale
	-- 선체 (몸통 + 뱃머리 쐐기) + 줄무늬 + 바닥
	part(l, "BoatHull", "Block", v(L, H, W), HULL, "SmoothPlastic", v(0, 0, 0))
	part(l, "BoatHull", "Wedge", v(W, H, 40 * scale), HULL, "SmoothPlastic", v(L / 2 + 20 * scale, 0, 0), v(0, -90, 0))
	part(l, "BoatStripe", "Block", v(L + 1, 4 * scale, W + 1), HULL_STRIPE, "SmoothPlastic", v(0, H * 0.25, 0))
	part(l, "BoatBottom", "Block", v(L, 6 * scale, W + 0.6), HULL_BOTTOM, "SmoothPlastic", v(0, -H / 2 + 3 * scale, 0))
	-- 갑판실 + 창 + 돛대 + 깃발 + 부표 줄
	append(
		l,
		MapKitShapes.roundedBox(
			"BoatCabin",
			v(40 * scale, 28 * scale, 30 * scale),
			cabinColor,
			"SmoothPlastic",
			v(-L * 0.15, H / 2 + 14 * scale, 0),
			{ style = "vertical", radius = 2 * scale }
		)
	)
	part(
		l,
		"BoatWindow",
		"Block",
		v(0.6, 8 * scale, 24 * scale),
		c(80, 120, 150),
		"Glass",
		v(-L * 0.15 + 20.3 * scale, H / 2 + 18 * scale, 0),
		nil,
		{ reflectance = 0.3 }
	)
	part(
		l,
		"BoatMast",
		"Cylinder",
		v(90 * scale, 3 * scale, 3 * scale),
		c(230, 230, 226),
		"Metal",
		v(L * 0.2, H / 2 + 45 * scale, 0),
		UPRIGHT
	)
	part(
		l,
		"BoatBoom",
		"Cylinder",
		v(50 * scale, 2 * scale, 2 * scale),
		c(230, 230, 226),
		"Metal",
		v(L * 0.32, H / 2 + 60 * scale, 0),
		v(0, 0, 30)
	)
	part(
		l,
		"BoatFlag",
		"Block",
		v(14 * scale, 9 * scale, 0.5),
		BUOY_ORANGE,
		"Fabric",
		v(L * 0.2 - 7 * scale, H / 2 + 84 * scale, 0),
		nil,
		{ anim = { kind = "Sway", period = 3.5, amount = 8, axis = "Y" } }
	)
	for k = 0, 1 do
		part(
			l,
			"BoatFloat",
			"Ball",
			v(6 * scale, 6 * scale, 6 * scale),
			if k % 2 == 0 then BUOY_ORANGE else HULL,
			"SmoothPlastic",
			v(-L / 2 + 20 * scale + k * 16 * scale, H * 0.1, W / 2 + 2 * scale)
		)
	end
	place(list, l, at, yaw)
end

local function harbor(list: { DecorSpec })
	local floorY = FishMarketArt.FLOOR_Y
	local seaY = FishMarketArt.SEA_Y
	local quayZ = -260
	-- 부두 끝 벽 (바닥 −93 → 바다 −101) + 볼라드·타이어
	part(list, "QuayEdge", "Block", v(1800, 14, 8), CONCRETE_WET, "Concrete", v(0, floorY - 7, quayZ - 4))
	part(list, "QuayCurb", "Block", v(1800, 3, 6), c(214, 196, 120), "Concrete", v(0, floorY + 1.5, quayZ + 3))
	for k = -4, 4 do
		local x = k * 110
		part(list, "Bollard", "Cylinder", v(10, 8, 8), c(60, 64, 70), "Metal", v(x, floorY + 5, quayZ + 10), UPRIGHT)
		part(list, "Bollard", "Ball", v(9, 9, 9), c(60, 64, 70), "Metal", v(x, floorY + 10, quayZ + 10))
		part(
			list,
			"QuayTire",
			"Cylinder",
			v(5, 16, 16),
			c(34, 34, 36),
			"Rubber",
			v(x + 55, floorY - 8, quayZ - 10),
			v(0, 90, 0)
		)
	end
	-- 바다 (불투명) + 물결 띠 + 먼 산
	part(
		list,
		"Sea",
		"Block",
		v(1800, 2, 1400),
		SEA,
		"SmoothPlastic",
		v(0, seaY - 1, quayZ - 700),
		nil,
		{ reflectance = 0.15 }
	)
	local rng = MapKitShapes.rng(5150)
	for i = 1, 5 do
		part(
			list,
			"SeaWave",
			"Block",
			v(rng:range(60, 160), 0.3, 3),
			SEA_LIGHT,
			"SmoothPlastic",
			v(rng:range(-700, 700), seaY + 0.2, rng:range(quayZ - 80, quayZ - 900))
		)
		local _ = i
	end
	for k = -2, 2 do
		part(
			list,
			"FarHill",
			"Ball",
			v(700, 260, 300),
			MapKitLogic.shade(HILL, 1 + k * 0.04),
			"Grass",
			v(k * 380, seaY - 40, quayZ - 1300 - (k % 2) * 60)
		)
	end
	-- 파도 물보라 (부두 끝)
	for _, x in { -240, 260 } do
		part(
			list,
			"SpraySource",
			"Block",
			v(30, 1, 6),
			SEA,
			"SmoothPlastic",
			v(x, floorY - 6, quayZ - 12),
			nil,
			{ transparency = 1, particle = "SeaSpray", particleRate = 3 }
		)
	end
	-- 고깃배 3척
	boat(list, v(-150, seaY + 14, quayZ - 70), 8, 1.0, c(236, 240, 244))
	boat(list, v(140, seaY + 12, quayZ - 150), 172, 0.85, c(196, 220, 236))
	boat(list, v(-420, seaY + 10, quayZ - 260), -20, 0.7, c(232, 232, 220))
	-- 항구 갠트리 크레인 실루엣 2 + 창고 지붕 줄
	for _, x in { -330, 360 } do
		local z = quayZ - 520
		for _, sx in { -1, 1 } do
			part(list, "GantryLeg", "Block", v(10, 260, 10), c(84, 108, 130), "Metal", v(x + sx * 40, seaY + 130, z))
		end
		part(list, "GantryBeam", "Block", v(240, 14, 14), c(84, 108, 130), "Metal", v(x - 40, seaY + 262, z))
		part(list, "GantryCab", "Block", v(24, 20, 18), c(220, 224, 228), "Metal", v(x + 10, seaY + 244, z))
	end
	for k = 0, 3 do
		local shedColor = MapKitLogic.shade(WAREHOUSE, 0.92 + k * 0.03)
		part(list, "FarShed", "Block", v(160, 50, 60), shedColor, "Concrete", v(-520 + k * 360, seaY + 25, quayZ - 700))
		part(
			list,
			"FarShedRoof",
			"Wedge",
			v(166, 16, 64),
			WAREHOUSE_ROOF,
			"Metal",
			v(-520 + k * 360, seaY + 58, quayZ - 700)
		)
	end
	-- 갈매기 (Bob)
	for i, at in { v(-80, 120, -230), v(60, 150, -300), v(-200, 100, -330), v(150, 90, -190) } do
		local anim: MapKitLogic.AnimSpec = { kind = "Bob", period = 2.6 + i * 0.5, amount = 3 }
		part(list, "Gull", "Ball", v(5, 5, 5), GULL, "SmoothPlastic", at, v(0, i * 50, 0), { anim = anim })
		for _, s in { -1, 1 } do
			part(
				list,
				"GullWing",
				"Wedge",
				v(1, 3, 10),
				GULL,
				"SmoothPlastic",
				v(at.x + s * 6, at.y + 1, at.z),
				v(0, i * 50 + s * 90, s * 10),
				{ anim = anim }
			)
		end
	end
end

---------------------------------------------------------------- 시장 소품 무리 (⑤ 경매 종·장화·바구니·스티로폼)
local function props(list: { DecorSpec })
	local floorY = FishMarketArt.FLOOR_Y
	local rim = FishMarketArt.RIM_TOP_Y
	-- 테두리 위 소품 (코스와 25 떨어진 수조 테두리 위)
	-- 플라스틱 바구니 쌓기 (출발 쪽 왼쪽 모서리)
	for k = 0, 2 do
		local color = if k == 1 then BASKET_GREEN else BASKET_BLUE
		append(
			list,
			MapKitShapes.roundedBox(
				"Basket",
				v(10, 5, 8),
				color,
				"Plastic",
				v(-74 + (k % 2) * 0.8, rim + 2.5 + k * 5, 10 - k * 0.6),
				{ style = "vertical", radius = 0.8 }
			)
		)
	end
	-- 경매 종 (출발 쪽 오른쪽 모서리 기둥에 매달림, Sway)
	part(list, "BellPost", "Cylinder", v(40, 2.4, 2.4), WET_WOOD_SHADES.dark, "Wood", v(76, rim + 20, 14), UPRIGHT)
	part(list, "BellArm", "Block", v(10, 1.6, 1.6), WET_WOOD_SHADES.dark, "Wood", v(72, rim + 39, 14))
	part(
		list,
		"Bell",
		"Ball",
		v(7, 8, 7),
		BRASS,
		"Metal",
		v(68, rim + 33, 14),
		nil,
		{ reflectance = 0.35, anim = { kind = "Sway", period = 3.8, amount = 8, axis = "Z" } }
	)
	part(
		list,
		"BellLip",
		"Cylinder",
		v(1.2, 8.4, 8.4),
		MapKitLogic.shade(BRASS, 0.8),
		"Metal",
		v(68, rim + 29.5, 14),
		UPRIGHT,
		{ anim = { kind = "Sway", period = 3.8, amount = 8, axis = "Z" } }
	)
	-- 저울 (테두리 오른쪽)
	append(list, MapKitShapes.rimDisc("Scale", 12, 1, STEEL, "Metal", v(76, rim + 6, -40), { segments = 12 }))
	append(
		list,
		MapKitShapes.roundedBox(
			"ScaleBody",
			v(10, 5, 10),
			c(220, 222, 226),
			"SmoothPlastic",
			v(76, rim + 2.5, -40),
			{ style = "vertical", radius = 1 }
		)
	)
	-- 고무장화 한 쌍 + 장갑 (테두리 왼쪽)
	for _, s in { -1, 1 } do
		local x = -76 + s * 2.6
		part(list, "Boot", "Cylinder", v(12, 4.4, 4.4), BOOT, "Rubber", v(x, rim + 6, -70), UPRIGHT)
		part(list, "BootFoot", "Block", v(4.4, 2.4, 7), BOOT, "Rubber", v(x, rim + 1.2, -71.5))
	end
	part(list, "Glove", "Block", v(4, 0.8, 6), BUOY_ORANGE, "Rubber", v(-72, rim + 0.4, -60), v(0, 30, 0))
	-- 스티로폼 생선 상자 쌓기 (바닥, 수조 옆)
	local function styroStack(x: number, z: number, n: number, seed: number, size: Vec3)
		local rng = MapKitShapes.rng(seed)
		for k = 0, n - 1 do
			-- 상자 + 한 단 밝은 뚜껑 테두리 (2파츠)
			local at = v(x + rng:range(-2, 2), floorY + 6 + k * 14, z + rng:range(-2, 2))
			local yaw = v(0, rng:range(-6, 6), 0)
			part(list, "StyroBox", "Block", v(size.x, size.y - 2, size.z), STYRO, "SmoothPlastic", at, yaw)
			part(
				list,
				"StyroLid",
				"Block",
				v(size.x + 1, 2, size.z + 1),
				c(250, 250, 248),
				"SmoothPlastic",
				v(at.x, at.y + size.y / 2, at.z),
				yaw
			)
		end
		part(
			list,
			"StyroLabel",
			"Block",
			v(math.min(size.x, size.z) * 0.6, 6, 0.4),
			c(60, 120, 190),
			"SmoothPlastic",
			v(x, floorY + 7 + (n - 1) * 14, z - size.z / 2 - 0.2)
		)
	end
	styroStack(-97, 45, 4, 11, v(26, 14, 38))
	styroStack(97, -40, 5, 12, v(26, 14, 38))
	styroStack(50, 52, 3, 13, v(40, 14, 28))
	-- 손수레 (바닥)
	append(
		list,
		MapKitShapes.bevelBox("Cart", v(60, 4, 36), c(90, 110, 130), "DiamondPlate", v(150, floorY + 14, 150), 1)
	)
	for _, sx in { -1, 1 } do
		part(
			list,
			"CartWheel",
			"Cylinder",
			v(4, 16, 16),
			c(30, 30, 32),
			"Rubber",
			v(150 + sx * 22, floorY + 8, 150 - 20)
		)
		part(
			list,
			"CartWheel",
			"Cylinder",
			v(4, 16, 16),
			c(30, 30, 32),
			"Rubber",
			v(150 + sx * 22, floorY + 8, 150 + 20)
		)
	end
	-- 바구니 무리 (바닥)
	for k = 0, 2 do
		local color = if k % 2 == 0 then BASKET_BLUE else BASKET_GREEN
		append(
			list,
			MapKitShapes.roundedBox(
				"FloorBasket",
				v(36, 20, 28),
				color,
				"Plastic",
				v(-250 + k * 8, floorY + 10 + (k // 3) * 20, -230 + (k % 3) * 30),
				{ style = "vertical", radius = 2 }
			)
		)
	end
end

---------------------------------------------------------------- 줄 조명 (수조 위 전선 + 전구) · 그림자 조명
local function stringLights(list: { DecorSpec })
	local rim = FishMarketArt.RIM_TOP_Y
	local cz = Layout.GRID_CENTER_Z
	local wireY = 62
	-- 기둥 두 개 (수조 테두리 양옆) + 가로 전선
	for _, sx in { -1, 1 } do
		append(
			list,
			MapKitShapes.capsule(
				"LightPole",
				wireY + 6 - rim,
				2.6,
				STEEL,
				"Metal",
				v(sx * 76, (wireY + 6 + rim) / 2, cz),
				UPRIGHT
			)
		)
	end
	part(list, "LightWire", "Cylinder", v(152, 0.5, 0.5), c(40, 40, 42), "SmoothPlastic", v(0, wireY, cz))
	-- 늘어진 전구 줄 2개 (대각선)
	for _, line in { { z0 = cz - 50, z1 = cz + 50 }, { z0 = cz + 50, z1 = cz - 50 } } do
		for k = 0, 8 do
			local a = k / 8
			local x = -70 + 140 * a
			local z = line.z0 + (line.z1 - line.z0) * a
			local sag = 6 * math.sin(a * math.pi)
			local lit = (k % 2 == 1) and line.z0 < line.z1
			part(
				list,
				"StringBulb",
				"Ball",
				v(2.2, 2.2, 2.2),
				BULB,
				"Neon",
				v(x, wireY - 4 - sag, z),
				nil,
				if lit
					then { light = { kind = "Point", color = c(255, 200, 140), brightness = 1.2, range = 30 } }
					else nil
			)
		end
	end
	-- 펜던트 작업등 (전선에 매달림) — 아침 해를 대신하는 따뜻한 그림자 SpotLight 1개
	part(
		list,
		"PendantCord",
		"Cylinder",
		v(18, 0.4, 0.4),
		c(40, 40, 42),
		"SmoothPlastic",
		v(-6, wireY - 9, cz),
		UPRIGHT
	)
	part(
		list,
		"PendantShade",
		"Cylinder",
		v(4, 8, 8),
		CRANE_DARK,
		"Metal",
		v(-6, wireY - 20, cz),
		UPRIGHT,
		{ reflectance = 0.2 }
	)
	part(list, "PendantBulb", "Ball", v(4, 4, 4), BULB, "Neon", v(-6, wireY - 22.5, cz), nil, {
		light = {
			kind = "Spot",
			color = c(255, 214, 160),
			brightness = 2.2,
			range = 60,
			angle = 120,
			face = "Bottom",
			shadows = true,
		},
	})
end

function FishMarketArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	crateTrim(list)
	tank(list)
	ground(list)
	harbor(list)
	props(list)
	stringLights(list)

	-- 좌판 6곳: 왼쪽 2(+X를 봄), 오른쪽 2(−X를 봄), 출발 뒤 1(−Z를 봄), 뒤 왼쪽 1(+Z를 봄)
	local stallSpots = {
		{ x = -175, z = 10, yaw = -90, hero = false, width = 150 },
		{ x = -175, z = -150, yaw = -90, hero = true, width = 150 },
		{ x = 175, z = 40, yaw = 90, hero = true, width = 140 },
		{ x = 175, z = -110, yaw = 90, hero = false, width = 130 },
		{ x = -10, z = 150, yaw = 0, hero = true, width = 180 },
		{ x = -40, z = -230, yaw = 180, hero = false, width = 140 },
	}
	for i, spot in stallSpots do
		place(list, stall(100 + i, spot.hero, spot.width), v(spot.x, 0, spot.z), spot.yaw)
	end

	-- 참치 크레인 (뒤 오른쪽) + 간판 (뒤 왼쪽 좌판 위, 출발 쪽을 봐요)
	crane(list, v(170, 0, -200), 70, 300)
	tuna(list, v(70, 94, -200))
	sign(list, v(-40, 88, -168), 0)
	return list
end

-- 소개 카메라 (origin 로컬). 모두 판정 상자 + 40 안 (MapLightingLogic 들어가기 여유).
function FishMarketArt.introCamera(): { IntroPoint }
	local cz = Layout.GRID_CENTER_Z
	return {
		-- ① 출발 쪽 왼쪽 위에서 시장 전체 + 뒤의 참치 크레인·항구
		{ pos = v(-60, 46, 34), lookAt = v(30, 10, -160) },
		-- ② 줄 끝에서 기다리는 얼음 블록 클로즈업
		{ pos = v(-36, 9, Layout.rowZ(1) + 14), lookAt = v(-60, 0, Layout.rowZ(1)) },
		-- ③ 격자 먼 쪽 물 위에서 참치·⚠ 하늘을 올려다보는 반전 샷
		{ pos = v(30, 3, cz - 52), lookAt = v(70, 80, -200) },
		-- ④ 상자 격자 위
		{ pos = v(10, 46, cz + 20), lookAt = v(0, 0, cz - 10) },
		-- ⑤ 출발 자리 (플레이어가 곧 볼 방향)
		{ pos = v(0, 10, 4), lookAt = v(0, 2, cz) },
	}
end

-- 장식이 가리면 안 되는 상자: 상자 격자 윗면 위 ~ ⚠ 표지 위 (가장자리 1 여유)
function FishMarketArt.courseVolume(): Bounds
	local half = Layout.SPAN / 2 + 1
	return {
		min = v(Layout.GRID_CENTER_X - half, Layout.TOP_Y, Layout.GRID_CENTER_Z - half),
		max = v(Layout.GRID_CENTER_X + half, FishMarketArt.SIGHT_TOP, Layout.GRID_CENTER_Z + half),
	}
end

return FishMarketArt
