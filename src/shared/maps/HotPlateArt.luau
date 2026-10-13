--!strict
-- "뜨거운 철판" 아트 데이터 (m4-03). Roblox API를 쓰지 않아요 — lune 테스트(tests/map-art-arena.spec.luau)에서 바로 불러요.
-- 판정 지오메트리(타일·층·탈락 높이)는 HotPlateLogic 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   HotPlateArt.decor() -> { DecorSpec }        주방 철판 장식 (origin 기준 로컬, MapKit.buildDecor로 만들어요)
--   HotPlateArt.introCamera() -> { IntroPoint } 손으로 짠 소개 카메라 경로 (손님 얼굴 → 층 옆 → 위층 → 바깥 끝점)
--   HotPlateArt.courseVolume() -> { Bounds }    장식이 들어가면 안 되는 상자 (층마다 윗면 위 2~12, 철판 안쪽)
--   HotPlateArt.isGlowing(elapsed) -> boolean    달아오른 타일을 Neon으로 바꿀 때인지 (색 단계 시간은 그대로)
--   HotPlateArt.STEAM_VENT, HOOD_LAMP            김(ParticleEmitter)을 붙일 파츠, 후드 램프 (m5-24: 조명은 DecorSpec.light)
--   HotPlateArt.BUDGET                           "Extended" (m5-24: 장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
--   HotPlateArt.LIGHTING                         맵 조명 분위기 (m5-24: MapLighting.PRESETS 초안을 옮겨 다듬음)
--
-- m5-24 "밤의 철판구이, 열기": 철판 탑은 거대한 철판구이 카운터(무쇠 상판, 옻칠 나무 테두리) 한가운데 서 있고,
-- 카운터 가운데 구멍으로 손님 얼굴 셋이 입을 벌리고 올려다봐요. 카운터 상판 y -96 = 낙하선(-55)보다 41 아래.
-- 방: 뒤 = 흰 타일 벽 + 양념 선반, 옆 = 어두운 판벽 + 메뉴판, 앞 = 밤 거리 창(차가운 파랑) + 노렌 입구, 천장 + 후드 덕트.
-- 열기 주황(장식)은 호박-노랑 쪽(HEAT_*), 판정 HotTile 경고 색(HotPlateLogic 주황 → 빨강)과 다르게 둬요.

local HotPlateLogic = require(script.Parent.HotPlateLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE

local HotPlateArt = {}

HotPlateArt.BUDGET = "Extended"

-- 맵 조명 (m5-24): 밤 8시 반, 낮은 청색 Ambient + 따뜻한 색 보정 — 후드 램프·열기 주황과 창밖 파란 밤의 대비
HotPlateArt.LIGHTING = {
	ClockTime = 20.5,
	Brightness = 1.2,
	Ambient = { r = 84, g = 82, b = 112 },
	OutdoorAmbient = { r = 92, g = 96, b = 140 },
	EnvironmentSpecularScale = 0.9,
	Atmosphere = {
		Density = 0.28,
		Offset = 0.08,
		Color = { r = 120, g = 92, b = 96 },
		Decay = { r = 60, g = 46, b = 78 },
		Glare = 0,
		Haze = 0.9,
	},
	ColorCorrection = {
		Brightness = 0.04,
		Contrast = 0.12,
		Saturation = 0.1,
		TintColor = { r = 255, g = 234, b = 210 },
	},
	Bloom = { Intensity = 0.7, Size = 28, Threshold = 1 },
	SunRays = { Intensity = 0, Spread = 0.5 },
} :: MapLighting.LightingPreset

HotPlateArt.STEAM_VENT = "SteamVent"
HotPlateArt.HOOD_LAMP = "HoodLamp"
HotPlateArt.SAUCE_BOTTLE = "SauceBottle" -- m5-20 ④: 선반 위 병, 클라이언트가 좌우로 흔들어요
-- 달아오름 진행도(0~1)가 이 이상이면 Neon으로 은은하게 빛나요 (단계·사라지는 시간은 HotPlateLogic 그대로)
HotPlateArt.GLOW_FROM = 0.6
-- 시야 상자: 층 윗면 위 이 높이 범위에는 장식을 두지 않아요
HotPlateArt.SIGHT_MIN = 2
HotPlateArt.SIGHT_MAX = 12

local STAINLESS: RGB = { r = 200, g = 204, b = 210 }
local OIL: RGB = { r = 236, g = 200, b = 90 }
local MOUTH_RED: RGB = { r = 200, g = 40, b = 52 }
local MOUTH_DARK: RGB = { r = 70, g = 12, b = 20 }
local TONGUE: RGB = { r = 232, g = 112, b = 132 }
local CHEEK: RGB = { r = 244, g = 150, b = 150 }
local shade = MapKitLogic.shade
-- m5-24 색 (60 = 짙은 철·검은 후드·어두운 나무, 30 = 철판 회색·스테인리스, 10 = 열기 호박색 Neon·파란 가스불)
local CAST_IRON: RGB = { r = 46, g = 44, b = 46 } -- 철판 카운터 상판
local IRON_SHADES: { RGB } = { shade(CAST_IRON, 1.18), CAST_IRON, shade(CAST_IRON, 0.85) }
local DARK_WOOD: RGB = { r = 78, g = 52, b = 38 }
local WOOD_SHADES: { RGB } = { shade(DARK_WOOD, 1.2), DARK_WOOD, shade(DARK_WOOD, 0.82) }
local COUNTER_WOOD: RGB = { r = 150, g = 100, b = 62 } -- 카운터 테두리·손님 테이블 (히노키보다 짙게)
local LACQUER = PALETTE.LacquerDark
local TILE_WHITE: RGB = { r = 214, g = 216, b = 214 }
local HOOD_DARK: RGB = { r = 40, g = 42, b = 46 }
local HEAT: RGB = { r = 255, g = 168, b = 60 } -- 장식 열기 (HotTile 경고 주황 232,100,24·빨강과 다르게 노란 쪽)
local HEAT_DEEP: RGB = { r = 240, g = 120, b = 40 }
local GAS_BLUE: RGB = { r = 80, g = 150, b = 255 }
local LAMP_PAPER: RGB = { r = 255, g = 214, b = 150 }
local LAMP_LIGHT: RGB = { r = 255, g = 176, b = 100 }
local NIGHT_SKY: RGB = { r = 26, g = 40, b = 92 }
local NIGHT_LOW: RGB = { r = 52, g = 60, b = 120 }
local STREET: RGB = { r = 18, g = 20, b = 40 }
local WINDOW_GLOW: RGB = { r = 255, g = 200, b = 120 }
local BUTTER: RGB = { r = 255, g = 226, b = 120 }
local HAIR: RGB = { r = 40, g = 30, b = 28 }
local SHRIMP: RGB = { r = 255, g = 132, b = 92 }
local ONION: RGB = { r = 236, g = 226, b = 190 }
local PEPPER_GREEN: RGB = { r = 70, g = 140, b = 60 }

-- 방 껍데기 (m5-24): 카운터 상판 윗면, 바닥, 벽·천장 자리 (origin 기준 로컬)
HotPlateArt.COUNTER_TOP_Y = -95 -- 낙하선(-55)보다 40 아래
HotPlateArt.FLOOR_Y = -185 -- 카운터 높이 90 (1 stud ≈ 1 cm)
HotPlateArt.CEILING_Y = 130
HotPlateArt.SIDE_WALL_X = 220
HotPlateArt.BACK_WALL_DZ = -180 -- 철판 중심 z 기준 (뒤 = 양념 선반 벽)
HotPlateArt.FRONT_WALL_DZ = 240 -- 철판 중심 z 기준 (앞 = 밤 거리 창, 스폰 눈높이 뷰가 보는 쪽)

local SKINS: { RGB } = {
	{ r = 240, g = 200, b = 170 },
	{ r = 222, g = 176, b = 136 },
	{ r = 250, g = 214, b = 186 },
}

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
): DecorSpec
	local spec: DecorSpec = {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
		transparency = transparency,
	}
	table.insert(list, spec)
	return spec
end

local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, s in specs do
		table.insert(list, s)
	end
end

-- 큰 배경판 (그림자 없음 — HotPlate.build도 장식 그림자를 다 꺼요)
local function backdrop(
	list: { DecorSpec },
	name: string,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): DecorSpec
	local spec = part(list, name, "Block", size, color, material, offset, rotation)
	spec.castShadow = false
	return spec
end

-- 세운 원판(원기둥 축을 Y로): 원기둥은 축이 로컬 X라 Z로 90° 돌려요
local UPRIGHT = v(0, 0, 90)

local function plateHalf(): number
	return HotPlateLogic.plateSize() / 2
end

-- 층 테두리(스테인리스)·기름 자국·김 나는 곳
local function addFrames(list: { DecorSpec })
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	for layer = 1, HotPlateLogic.LAYER_COUNT do
		local top = HotPlateLogic.layerTopY(layer)
		local y = top - 0.7 -- 높이 1.4 → 윗면이 타일과 같아요 (턱처럼 보이지 않게, m4-03 QA B3)
		for _, side in { -1, 1 } do
			part(list, "Frame", "Block", v(2, 1.4, half * 2 + 4), STAINLESS, "Metal", v(side * (half + 1), y, cz))
			part(list, "Frame", "Block", v(half * 2, 1.4, 2), STAINLESS, "Metal", v(0, y, cz + side * (half + 1)))
		end
		-- 기름 튄 자국 (테두리 위 얇은 노란 원판)
		local spots = {
			v(half + 1, top + 0.03, cz + 17 - 6 * layer),
			v(-(half + 1), top + 0.03, cz - 11 + 4 * layer),
			v(12 - 8 * layer, top + 0.03, cz - (half + 1)),
		}
		for i, at in spots do
			local d = 1.1 + 0.25 * ((i + layer) % 3)
			part(list, "OilSplatter", "Cylinder", v(0.06, d, d), OIL, "SmoothPlastic", at, UPRIGHT, 0.15)
		end
	end
	-- 김 나는 곳 (투명, HotPlate.build가 ParticleEmitter를 달아요). 타일 위가 아니라 테두리 위.
	for _, at in
		{
			v(half + 1, HotPlateLogic.layerTopY(1) + 0.1, cz + 11),
			v(-(half + 1), HotPlateLogic.layerTopY(1) + 0.1, cz - 13),
			v(half + 1, HotPlateLogic.layerTopY(2) + 0.1, cz - 15),
			v(-(half + 1), HotPlateLogic.layerTopY(2) + 0.1, cz + 15),
		}
	do
		part(list, HotPlateArt.STEAM_VENT, "Block", v(1, 0.2, 1), STAINLESS, "SmoothPlastic", at, nil, 1)
	end
end

-- 층 모서리 기둥 4개 (맨 아래층 밑부터 후드 아래까지)
local function addPillars(list: { DecorSpec })
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	-- m5-24: 기둥이 카운터 상판까지 내려가 탑이 카운터 위에 서 있어요 (밑에 둥근 받침, 층마다 고리)
	local bottom = HotPlateArt.COUNTER_TOP_Y
	local top = 26
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				list,
				"Pillar",
				"Cylinder",
				v(top - bottom, 2, 2),
				STAINLESS,
				"Metal",
				v(sx * (half + 1), (top + bottom) / 2, cz + sz * (half + 1)),
				UPRIGHT
			).reflectance =
				0.2
			part(
				list,
				"PillarFoot",
				"Cylinder",
				v(2, 5, 5),
				CAST_IRON,
				"Metal",
				v(sx * (half + 1), bottom + 1, cz + sz * (half + 1)),
				UPRIGHT
			)
			for layer = 1, HotPlateLogic.LAYER_COUNT do
				part(
					list,
					"PillarCollar",
					"Cylinder",
					v(1, 2.8, 2.8),
					HOOD_DARK,
					"Metal",
					v(sx * (half + 1), HotPlateLogic.layerTopY(layer) - 2.2, cz + sz * (half + 1)),
					UPRIGHT
				)
			end
		end
	end
end

-- 위를 보고 입 벌린 거대 손님 얼굴 (맨 아래층 밑). 얼굴 앞면이 +Y, 턱이 +Z 쪽이에요.
local function addCustomerFace(list: { DecorSpec }, cx: number, cz: number, skin: RGB)
	local headY = -80
	local radius = 14
	local top = headY + radius
	part(list, "CustomerHead", "Ball", v(radius * 2, radius * 2, radius * 2), skin, "SmoothPlastic", v(cx, headY, cz))
	part(list, "CustomerLips", "Cylinder", v(3, 13, 13), MOUTH_RED, "SmoothPlastic", v(cx, top - 0.5, cz + 1), UPRIGHT)
	part(
		list,
		"CustomerMouth",
		"Cylinder",
		v(3.2, 10, 10),
		MOUTH_DARK,
		"SmoothPlastic",
		v(cx, top - 0.3, cz + 1),
		UPRIGHT
	)
	part(
		list,
		"CustomerTongue",
		"Cylinder",
		v(1, 4.5, 4.5),
		TONGUE,
		"SmoothPlastic",
		v(cx, top + 1.4, cz + 2.8),
		UPRIGHT
	)
	for i = -1, 1 do
		part(
			list,
			"CustomerTooth",
			"Block",
			v(1.4, 1.2, 1.2),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + i * 2.2, top + 1.6, cz - 3.2)
		)
		part(
			list,
			"CustomerTooth",
			"Block",
			v(1.4, 1.2, 1.2),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + i * 2.2, top + 1.6, cz + 5.2)
		)
	end
	for _, side in { -1, 1 } do
		part(
			list,
			"CustomerEye",
			"Ball",
			v(4, 4, 4),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + side * 4.5, top - 3, cz - 8)
		)
		part(
			list,
			"CustomerPupil",
			"Ball",
			v(2, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(cx + side * 4.5, top - 1.2, cz - 8.4)
		)
		part(
			list,
			"CustomerCheek",
			"Cylinder",
			v(0.6, 3.5, 3.5),
			CHEEK,
			"SmoothPlastic",
			v(cx + side * 8, top - 2.6, cz + 3),
			UPRIGHT
		)
		-- m5-24: 눈썹·귀 (얼굴이 위를 봐서 귀는 옆, 눈썹은 눈 위쪽 = -Z)
		part(
			list,
			"CustomerBrow",
			"Block",
			v(3.6, 0.8, 1),
			HAIR,
			"SmoothPlastic",
			v(cx + side * 4.6, top - 0.6, cz - 11),
			v(0, side * 12, 0)
		)
		part(
			list,
			"CustomerEar",
			"Ball",
			v(5, 5, 5),
			shade(skin, 0.92),
			"SmoothPlastic",
			v(cx + side * 13.6, headY + 2, cz)
		)
	end
	-- m5-24: 머리카락 (정수리 = -Z 쪽) + 카운터 구멍 테두리 (얼굴이 카운터에서 솟아요)
	part(list, "CustomerHair", "Ball", v(24, 24, 24), HAIR, "SmoothPlastic", v(cx, headY - 5, cz - 6))
	addAll(
		list,
		MapKitShapes.ring(
			"CustomerCollar",
			radius + 1.2,
			2,
			1.6,
			14,
			LACQUER,
			"SmoothPlastic",
			v(cx, HotPlateArt.COUNTER_TOP_Y + 0.8, cz)
		)
	)
end

-- Z축으로 tilt도 기운 물건의 부품 위치 (base 기준 로컬 (lx, ly)를 돌려요 — MapKitLogic 회전과 같은 방향)
local function tilted(base: Vec3, tilt: number, lx: number, ly: number): Vec3
	local c, s = math.cos(math.rad(tilt)), math.sin(math.rad(tilt))
	return v(base.x + lx * c - ly * s, base.y + lx * s + ly * c, base.z)
end

-- 철판 옆에 기대 세운 거대 주걱 (날 + 목 + 나무 손잡이)
local function addSpatula(list: { DecorSpec }, base: Vec3, tilt: number)
	part(list, "SpatulaBlade", "Block", v(0.6, 12, 10), STAINLESS, "Metal", tilted(base, tilt, 0, 0), v(0, 0, tilt))
	part(list, "SpatulaNeck", "Block", v(0.6, 3, 2), STAINLESS, "Metal", tilted(base, tilt, 0, 7.5), v(0, 0, tilt))
	part(
		list,
		"SpatulaHandle",
		"Cylinder",
		v(16, 2, 2),
		PALETTE.Wood,
		"Wood",
		tilted(base, tilt, 0, 17),
		v(0, 0, 90 + tilt)
	)
	part(list, "SpatulaRivet", "Ball", v(1, 1, 1), PALETTE.Nori, "Metal", tilted(base, tilt, 0, 9.5), nil)
end

-- 머리 위 환풍기 후드 (맨 위층보다 25 이상 높이). m5-24: 깎은 모서리·둥근 트림·리벳, 램프 갓, 덕트가 천장까지
local function addHood(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	addAll(list, MapKitShapes.bevelBox("HoodCanopy", v(40, 3, 40), HOOD_DARK, "Metal", v(0, 34, cz), 1.2))
	part(list, "HoodCeiling", "Block", v(64, 0.4, 64), shade(HOOD_DARK, 0.7), "Metal", v(0, 30, cz))
	for _, side in { -1, 1 } do
		part(list, "HoodSkirt", "Block", v(66, 5, 1), STAINLESS, "Metal", v(0, 27.5, cz + side * 33)).reflectance = 0.25
		part(list, "HoodSkirt", "Block", v(1, 5, 66), STAINLESS, "Metal", v(side * 33, 27.5, cz)).reflectance = 0.25
		-- 아래 둥근 테두리 (트림)
		part(list, "HoodTrim", "Cylinder", v(67, 1.4, 1.4), HOOD_DARK, "Metal", v(0, 25, cz + side * 33))
		part(list, "HoodTrim", "Cylinder", v(67, 1.4, 1.4), HOOD_DARK, "Metal", v(side * 33, 25, cz), v(0, 90, 0))
		part(
			list,
			"HoodSlope",
			"Block",
			v(66, 1, 14),
			STAINLESS,
			"Metal",
			v(0, 32, cz + side * 26),
			v(side * -20, 0, 0)
		)
		part(
			list,
			"HoodSlope",
			"Block",
			v(14, 1, 66),
			shade(STAINLESS, 0.88),
			"Metal",
			v(side * 26, 32, cz),
			v(0, 0, side * 20)
		)
		-- 리벳 줄
		for k = -5, 5 do
			part(list, "HoodRivet", "Ball", v(0.8, 0.8, 0.8), HOOD_DARK, "Metal", v(k * 6, 28.6, cz + side * 33.6))
		end
	end
	for i = -2, 2 do
		part(list, "HoodGrille", "Block", v(40, 0.3, 0.6), PALETTE.Nori, "Metal", v(0, 29.6, cz + i * 6))
	end
	-- 덕트: 후드에서 천장까지, 이음매 띠
	local ductTop = HotPlateArt.CEILING_Y
	part(
		list,
		"HoodDuct",
		"Cylinder",
		v(ductTop - 35, 12, 12),
		STAINLESS,
		"Metal",
		v(0, (35 + ductTop) / 2, cz),
		UPRIGHT
	).reflectance =
		0.2
	local y = 50
	while y < ductTop - 6 do
		part(list, "HoodDuctBand", "Cylinder", v(1.2, 13, 13), HOOD_DARK, "Metal", v(0, y, cz), UPRIGHT)
		y += 22
	end
	-- 램프 2개: 갓 + 전구 + 아래로 비추는 SpotLight. 왼쪽 램프만 그림자 (위층 타일 그림자로 아래층 높이가 읽혀요)
	for _, side in { -1, 1 } do
		part(list, "HoodLampShade", "Cylinder", v(2.4, 5, 5), HOOD_DARK, "Metal", v(side * 14, 30.6, cz), UPRIGHT)
		local lamp = part(
			list,
			HotPlateArt.HOOD_LAMP,
			"Ball",
			v(2, 2, 2),
			{ r = 255, g = 230, b = 170 },
			"Neon",
			v(side * 14, 29, cz)
		)
		lamp.light = {
			kind = "Spot",
			color = { r = 255, g = 222, b = 170 },
			brightness = 3,
			range = 60,
			angle = 80,
			face = "Bottom",
			shadows = side < 0,
		}
	end
end

-- 층 밑 가스 버너 (파란 불꽃): 각 층 판 바로 아래 (윗면 - 2 아래 — 판·시야 상자와 안 겹쳐요)
local function addBurners(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local half = plateHalf()
	for layer = 1, HotPlateLogic.LAYER_COUNT do
		local t = HotPlateLogic.layerTopY(layer)
		for row = -1, 1 do
			local z = cz + row * 16
			part(list, "BurnerPipe", "Cylinder", v(half * 2 - 6, 1.2, 1.2), HOOD_DARK, "Metal", v(0, t - 4, z))
			for k = -2, 2 do
				part(list, "BurnerFlame", "Wedge", v(0.9, 1, 0.9), GAS_BLUE, "Neon", v(k * 9 + row * 2, t - 2.9, z))
			end
		end
		-- 층마다 파란 빛 하나 (가운데 버너)
		local core = part(list, "BurnerGlow", "Ball", v(1.2, 1.2, 1.2), GAS_BLUE, "Neon", v(0, t - 3.2, cz))
		core.light = { kind = "Point", color = GAS_BLUE, brightness = 1.2, range = 22 }
	end
end

-- 층 가장자리 불티 (테두리 바깥 귀퉁이 아래, 위로 올라가요)
local function addEmbers(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local half = plateHalf()
	for i, at in
		{
			v(-(half + 1), HotPlateLogic.layerTopY(2) - 1.6, cz - (half + 1)),
			v(half + 1, HotPlateLogic.layerTopY(2) - 1.6, cz + (half + 1)),
			v(half + 1, HotPlateLogic.layerTopY(3) - 1.6, cz - (half + 1)),
		}
	do
		local e = part(list, "EmberVent", "Block", v(0.6, 0.2, 0.6), CAST_IRON, "Metal", at, nil, 1)
		e.particle = "Embers"
		e.particleRate = 2 + i
	end
end

-- 큰 철판구이 카운터: 무쇠 상판(낙하선보다 40 아래) + 옻칠 테두리 + 나무 몸통 + 손님 쪽 나무 턱
local COUNTER_X = 110
local COUNTER_Z0, COUNTER_Z1 = -92, 92 -- 철판 중심 z 기준

local function addCounter(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local top = HotPlateArt.COUNTER_TOP_Y
	local floor = HotPlateArt.FLOOR_Y
	local depth = COUNTER_Z1 - COUNTER_Z0
	local midZ = cz + (COUNTER_Z0 + COUNTER_Z1) / 2
	-- 상판: 띠 4장, shade를 섞어요
	local stripW = COUNTER_X * 2 / 4
	for i = 0, 3 do
		backdrop(
			list,
			"GriddleTop",
			v(stripW, 3, depth),
			IRON_SHADES[(i % 3) + 1],
			"Metal",
			v(-COUNTER_X + stripW * (i + 0.5), top - 1.5, midZ)
		).reflectance =
			0.12
	end
	for i = 1, 3 do
		part(
			list,
			"GriddleSeam",
			"Block",
			v(0.4, 0.1, depth),
			shade(CAST_IRON, 0.6),
			"Metal",
			v(-COUNTER_X + stripW * i, top + 0.03, midZ)
		)
	end
	-- 탑 발치 열기: 달궈진 상판 호박색 번짐 (판정 경고 주황·빨강보다 노란 쪽, 낙하선 40 아래)
	-- (불투명 원판 3장 — 큰 반투명 판은 휴대폰에서 비싸요. 가운데만 Neon)
	for i, d in { 100, 76, 50 } do
		local glow = part(
			list,
			"HeatHalo",
			"Cylinder",
			v(0.1, d, d),
			if i == 3 then HEAT_DEEP else MapKitLogic.mix(CAST_IRON, HEAT_DEEP, 0.2 + 0.25 * i),
			if i == 3 then "Neon" else "Metal",
			v(0, top + 0.02 + i * 0.03, cz),
			UPRIGHT
		)
		glow.castShadow = false
	end
	-- 옻칠 테두리 (상판 둘레 띠)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"GriddleRim",
			v(COUNTER_X * 2, 0, depth),
			3,
			4,
			LACQUER,
			"SmoothPlastic",
			v(0, top - 0.5, midZ)
		)
	)
	-- 손님 쪽 나무 턱 (+Z 앞, ±X 옆): 접시·손을 올려요
	local ledgeY = top + 3
	part(
		list,
		"CounterLedge",
		"Block",
		v(COUNTER_X * 2 + 54, 4, 24),
		COUNTER_WOOD,
		"Wood",
		v(0, ledgeY, cz + COUNTER_Z1 + 15)
	)
	part(
		list,
		"CounterLedgeLip",
		"Cylinder",
		v(COUNTER_X * 2 + 54, 2.4, 2.4),
		shade(COUNTER_WOOD, 0.75),
		"Wood",
		v(0, ledgeY + 1, cz + COUNTER_Z1 + 27)
	)
	for _, side in { -1, 1 } do
		part(
			list,
			"CounterLedge",
			"Block",
			v(24, 4, depth + 6),
			shade(COUNTER_WOOD, 0.92),
			"Wood",
			v(side * (COUNTER_X + 15), ledgeY, midZ)
		)
		part(
			list,
			"CounterLedgeLip",
			"Cylinder",
			v(depth + 6, 2.4, 2.4),
			shade(COUNTER_WOOD, 0.75),
			"Wood",
			v(side * (COUNTER_X + 27), ledgeY + 1, midZ),
			v(0, 90, 0)
		)
	end
	-- 나무 몸통 (세로 판 shade 3개) + 발판 봉
	local bodyH = top - 3 - floor
	local panels = 10
	local panelW = (COUNTER_X * 2 + 50) / panels
	for i = 0, panels - 1 do
		backdrop(
			list,
			"CounterBody",
			v(panelW, bodyH, 3),
			WOOD_SHADES[(i % 3) + 1],
			"WoodPlanks",
			v(-(COUNTER_X + 25) + panelW * (i + 0.5), floor + bodyH / 2, cz + COUNTER_Z1 + 22)
		)
	end
	for _, side in { -1, 1 } do
		backdrop(
			list,
			"CounterBody",
			v(3, bodyH, depth + 44),
			WOOD_SHADES[2],
			"WoodPlanks",
			v(side * (COUNTER_X + 25), floor + bodyH / 2, midZ + 8)
		)
	end
	part(
		list,
		"CounterFootRail",
		"Cylinder",
		v(COUNTER_X * 2 + 50, 4, 4),
		HOOD_DARK,
		"Metal",
		v(0, floor + 22, cz + COUNTER_Z1 + 28)
	).reflectance =
		0.2
	-- 셰프 쪽(-Z) 스테인리스 작업대
	backdrop(
		list,
		"ChefStation",
		v(COUNTER_X * 2, top - floor - 1, 30),
		shade(STAINLESS, 0.7),
		"Metal",
		v(0, (top - 1 + floor) / 2, cz + COUNTER_Z0 - 15)
	)
end

-- 손님 (사람 크기, 1 stud ≈ 1 cm): 의자 + 몸 + 얼굴 + 팔·젓가락. 로컬은 -Z(철판 쪽)를 봐요
local function guest(seed: number, skin: RGB, shirt: RGB): { DecorSpec }
	local g: { DecorSpec } = {}
	local top = HotPlateArt.COUNTER_TOP_Y
	local floor = HotPlateArt.FLOOR_Y
	local seatY = floor + 62
	part(g, "GuestStoolSeat", "Cylinder", v(4, 30, 30), LACQUER, "SmoothPlastic", v(0, seatY, 4), UPRIGHT)
	part(
		g,
		"GuestStoolLeg",
		"Cylinder",
		v(seatY - floor, 4, 4),
		HOOD_DARK,
		"Metal",
		v(0, (seatY + floor) / 2, 4),
		UPRIGHT
	)
	addAll(
		g,
		MapKitShapes.roundedBox(
			"GuestBody",
			v(38, 54, 22),
			shirt,
			"Fabric",
			v(0, seatY + 29, 6),
			{ style = "vertical" }
		)
	)
	local headY = seatY + 72
	part(g, "GuestHead", "Ball", v(26, 26, 26), skin, "SmoothPlastic", v(0, headY, 4))
	part(g, "GuestHair", "Ball", v(27.5, 27.5, 27.5), HAIR, "SmoothPlastic", v(0, headY + 3, 7.5))
	for _, side in { -1, 1 } do
		part(g, "GuestEar", "Ball", v(6, 6, 6), shade(skin, 0.92), "SmoothPlastic", v(side * 13, headY, 5))
		part(g, "GuestEyeDot", "Ball", v(3, 3, 3), PALETTE.Nori, "SmoothPlastic", v(side * 5, headY + 2, -8.6))
		part(
			g,
			"GuestBlush",
			"Cylinder",
			v(0.6, 4, 4),
			CHEEK,
			"SmoothPlastic",
			v(side * 7.5, headY - 3, -8.2),
			v(0, 90 - side * 30, 0)
		)
		-- 팔: 어깨 → 카운터 턱 위 손
		part(g, "GuestArm", "Block", v(9, 9, 30), shirt, "Fabric", v(side * 16, top + 14, -6), v(-35, 0, 0))
		part(g, "GuestHand", "Ball", v(8, 8, 8), skin, "SmoothPlastic", v(side * 13, top + 9, -20))
	end
	part(g, "GuestNose", "Ball", v(4, 4, 4), shade(skin, 0.95), "SmoothPlastic", v(0, headY - 1, -10.6))
	part(g, "GuestMouth", "Block", v(5, 1.2, 1), MOUTH_DARK, "SmoothPlastic", v(0, headY - 6, -10.4))
	-- 젓가락 (오른손)
	local stickTilt = if seed % 2 == 0 then 10 else -10
	part(
		g,
		"GuestChopstick",
		"Block",
		v(0.8, 0.8, 23),
		PALETTE.Wood,
		"Wood",
		v(13, top + 10, -30),
		v(-15, stickTilt, 0)
	)
	part(
		g,
		"GuestChopstick",
		"Block",
		v(0.8, 0.8, 23),
		PALETTE.Wood,
		"Wood",
		v(15, top + 9, -30),
		v(-12, stickTilt + 4, 0)
	)
	return g
end

local function addGuests(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local shirts: { RGB } = {
		{ r = 60, g = 84, b = 130 },
		{ r = 150, g = 60, b = 56 },
		{ r = 70, g = 110, b = 80 },
		{ r = 196, g = 168, b = 120 },
		{ r = 90, g = 70, b = 110 },
	}
	-- 앞(+Z) 손님 3명, 오른쪽(+X) 2명
	local seats = {
		{ x = -60, z = cz + COUNTER_Z1 + 46, yaw = 0 },
		{ x = 6, z = cz + COUNTER_Z1 + 48, yaw = 0 },
		{ x = 72, z = cz + COUNTER_Z1 + 46, yaw = 0 },
		{ x = COUNTER_X + 46, z = cz + 40, yaw = 90 },
		{ x = COUNTER_X + 48, z = cz - 30, yaw = 90 },
	}
	for i, seat in seats do
		addAll(
			list,
			MapKitShapes.transform(
				guest(i, SKINS[(i % #SKINS) + 1], shirts[i]),
				v(seat.x, 0, seat.z),
				v(0, seat.yaw, 0)
			)
		)
	end
end

-- 카운터 위 소품: 손님 앞 접시·찻잔(김), 철판 위 버터·계란 껍데기·새우·양파·피망, 소금·후추 그라인더, 거대 헤라
local function addCounterProps(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local top = HotPlateArt.COUNTER_TOP_Y
	local ledge = top + 5
	for i, x in { -60, 6, 72 } do
		addAll(
			list,
			MapKitShapes.rimDisc(
				"GuestPlate",
				20,
				0.8,
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(x - 12, ledge + 0.4, cz + COUNTER_Z1 + 14),
				{ rimColor = PALETTE.PorcelainRim, rimWidth = 1.2, segments = 12 }
			)
		)
		local cup = part(
			list,
			"Teacup",
			"Cylinder",
			v(8, 8, 8),
			if i % 2 == 0 then { r = 120, g = 150, b = 90 } else { r = 186, g = 120, b = 80 },
			"SmoothPlastic",
			v(x + 14, ledge + 4, cz + COUNTER_Z1 + 14),
			UPRIGHT
		)
		if i ~= 2 then
			cup.particle = "Steam"
			cup.particleRate = 1.5
		end
	end
	-- 녹는 버터 블록 (접시 위, 거품) + 깨진 계란 껍데기
	local bx, bz = -62, cz + 46
	addAll(
		list,
		MapKitShapes.rimDisc(
			"ButterDish",
			26,
			1,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(bx, top + 0.5, bz),
			{ rimColor = PALETTE.PorcelainRim, segments = 12 }
		)
	)
	local butter = part(list, "Butter", "Block", v(11, 6, 7), BUTTER, "SmoothPlastic", v(bx, top + 4, bz), v(0, 14, 0))
	butter.particle = "Bubbles"
	butter.particleRate = 3
	butter.anim = { kind = "Pulse", period = 5, amount = 0.04 }
	part(
		list,
		"ButterPuddle",
		"Cylinder",
		v(0.2, 16, 16),
		shade(BUTTER, 0.92),
		"Glass",
		v(bx + 2, top + 1.1, bz),
		UPRIGHT,
		0.25
	)
	for k, at in { v(-36, 0, 54), v(-44, 0, 64) } do
		part(
			list,
			"EggShell",
			"Ball",
			v(6, 6, 6),
			{ r = 246, g = 236, b = 214 },
			"SmoothPlastic",
			v(at.x, top + 1.2, cz + at.z),
			v(0, k * 40, 0)
		)
	end
	part(list, "EggYolk", "Cylinder", v(1, 7, 7), PALETTE.Egg, "SmoothPlastic", v(-28, top + 0.5, cz + 62), UPRIGHT)
	part(
		list,
		"EggWhite",
		"Cylinder",
		v(0.6, 14, 14),
		PALETTE.Rice,
		"SmoothPlastic",
		v(-28, top + 0.3, cz + 62),
		UPRIGHT
	)
	-- 철판 위 새우·양파 고리·피망 (앞 오른쪽 무리)
	for i = 0, 3 do
		addAll(
			list,
			MapKitShapes.capsule(
				"Shrimp",
				10,
				3.4,
				SHRIMP,
				"SmoothPlastic",
				v(46 + i * 7, top + 1.7, cz + 50 + (i % 2) * 6),
				v(0, 30 + i * 25, 0)
			)
		)
	end
	for i = 0, 2 do
		addAll(
			list,
			MapKitShapes.ring(
				"OnionRing",
				4,
				1.2,
				1.2,
				10,
				ONION,
				"SmoothPlastic",
				v(70 + i * 9, top + 0.6, cz + 66 - i * 4)
			)
		)
	end
	for i = 0, 2 do
		part(
			list,
			"PepperSlice",
			"Cylinder",
			v(1.2, 5, 5),
			PEPPER_GREEN,
			"SmoothPlastic",
			v(40 + i * 6, top + 0.6, cz + 70),
			UPRIGHT
		)
	end
	part(list, "FoodSteam", "Block", v(1, 0.2, 1), CAST_IRON, "Metal", v(56, top + 0.2, cz + 56), nil, 1).particle =
		"Steam"
	-- 소금·후추 그라인더 (카운터 오른쪽 뒤, 위 손잡이 Spin)
	for k, x in { 78, 90 } do
		local color = if k == 1 then { r = 236, g = 232, b = 222 } else { r = 60, g = 44, b = 34 }
		part(list, "Grinder", "Cylinder", v(20, 7, 7), color, "Wood", v(x, top + 10, cz - 60), UPRIGHT)
		part(list, "GrinderBand", "Cylinder", v(1, 7.6, 7.6), STAINLESS, "Metal", v(x, top + 14, cz - 60), UPRIGHT)
		part(list, "GrinderCap", "Ball", v(7, 7, 7), color, "Wood", v(x, top + 20, cz - 60))
		part(list, "GrinderKnob", "Block", v(1.2, 2, 6), STAINLESS, "Metal", v(x, top + 24, cz - 60)).anim =
			{ kind = "Spin", period = 4 + k, axis = "Y" }
	end
	-- 셰프 쪽 교차한 거대 헤라 두 개 (통에 꽂힘, 살짝 흔들림)
	for _, side in { -1, 1 } do
		local base = v(side * 6 - 40, top + 22, cz - 74)
		local tilt = side * 18
		local blade = part(
			list,
			"BigSpatulaBlade",
			"Block",
			v(0.8, 14, 12),
			STAINLESS,
			"Metal",
			tilted(base, tilt, 0, 12),
			v(0, 0, tilt)
		)
		blade.reflectance = 0.3
		blade.anim = { kind = "Sway", period = 7 + side, amount = 2, axis = "X" }
		part(
			list,
			"BigSpatulaNeck",
			"Block",
			v(0.8, 4, 2.4),
			STAINLESS,
			"Metal",
			tilted(base, tilt, 0, 3),
			v(0, 0, tilt)
		)
		part(
			list,
			"BigSpatulaHandle",
			"Cylinder",
			v(16, 2.6, 2.6),
			DARK_WOOD,
			"Wood",
			tilted(base, tilt, 0, -7),
			v(0, 0, 90 + tilt)
		)
	end
	part(list, "UtensilHolder", "Cylinder", v(14, 10, 10), HOOD_DARK, "Metal", v(-40, top + 7, cz - 74), UPRIGHT)
end

-- 창 하나 (밤 거리 — 차가운 파랑). along "Z": 벽이 X 쪽에 있고 창이 Z로 뻗어요. "X": 벽이 Z 쪽
local function addWindow(list: { DecorSpec }, at: Vec3, along: string, inward: number, seed: number)
	local w, h = 80, 70
	local function p(name: string, sz: Vec3, color: RGB, material: string, dx: number, dy: number, depth: number)
		local size = if along == "Z" then v(sz.z, sz.y, sz.x) else sz
		local off = if along == "Z"
			then v(at.x + depth * inward, at.y + dy, at.z + dx)
			else v(at.x + dx, at.y + dy, at.z + depth * inward)
		return backdrop(list, name, size, color, material, off)
	end
	-- 벽 안쪽 면에 붙인 "창밖" (벽을 뚫지 않고 그 앞에 얇게 — depth는 방 안쪽으로)
	p("NightSky", v(w, h * 0.6, 0.6), NIGHT_SKY, "Neon", 0, h * 0.2, 0.3)
	p("NightLow", v(w, h * 0.4, 0.6), NIGHT_LOW, "Neon", 0, -h * 0.3, 0.3)
	local rng = MapKitShapes.rng(seed)
	local bx = -w / 2 + 6
	while bx < w / 2 - 6 do
		local bw = rng:range(10, 18)
		local bh = rng:range(20, 46)
		local cx = math.min(bx + bw / 2, w / 2 - bw / 2)
		p(
			"StreetBuilding",
			v(bw, bh, 0.4),
			shade(STREET, rng:range(0.8, 1.4)),
			"SmoothPlastic",
			cx,
			-h / 2 + bh / 2,
			0.8
		)
		for row = 0, 2 do
			if rng:next() < 0.55 and 6 + row * 9 < bh - 4 then
				p(
					"StreetLitWindow",
					v(2.6, 3, 0.4),
					WINDOW_GLOW,
					"Neon",
					cx + rng:range(-bw / 4, bw / 4),
					-h / 2 + 6 + row * 9,
					1.1
				)
			end
		end
		bx += bw + rng:range(1, 4)
	end
	for _, e in { -1, 1 } do
		p("WindowFrame", v(4, h + 8, 4), DARK_WOOD, "Wood", e * (w / 2 + 2), 0, 2)
		p("WindowFrame", v(w + 8, 4, 4), DARK_WOOD, "Wood", 0, e * (h / 2 + 2), 2)
	end
	p("WindowMullion", v(2, h, 2), shade(DARK_WOOD, 1.3), "Wood", 0, 0, 2)
	p("WindowMullion", v(w, 2, 2), shade(DARK_WOOD, 1.3), "Wood", 0, 10, 2)
end

-- 방: 바닥·천장·벽 (뒤 = 흰 타일 + 양념 선반, 왼쪽 = 판벽 + 메뉴판, 오른쪽·앞 = 밤 거리 창)
local function addRoom(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local floor = HotPlateArt.FLOOR_Y
	local ceil = HotPlateArt.CEILING_Y
	local wx = HotPlateArt.SIDE_WALL_X
	local z0, z1 = cz + HotPlateArt.BACK_WALL_DZ, cz + HotPlateArt.FRONT_WALL_DZ
	local depth, midZ = z1 - z0, (z0 + z1) / 2
	local height = ceil - floor
	-- 바닥: 짙은 나무 띠 6장
	for i = 0, 5 do
		local w = wx * 2 / 6
		backdrop(
			list,
			"Floor",
			v(w, 4, depth),
			WOOD_SHADES[(i % 3) + 1],
			"WoodPlanks",
			v(-wx + w * (i + 0.5), floor - 2, midZ)
		)
	end
	-- 천장 + 대들보
	backdrop(list, "Ceiling", v(wx * 2, 4, depth), shade(DARK_WOOD, 0.8), "WoodPlanks", v(0, ceil + 2, midZ))
	for k = 0, 6 do
		backdrop(list, "CeilingBeam", v(wx * 2, 8, 8), DARK_WOOD, "Wood", v(0, ceil - 4, z0 + 20 + k * 60))
	end
	-- 뒤 벽: 아래 판벽 + 위 흰 타일, 타일 줄눈 띠
	backdrop(list, "BackWainscot", v(wx * 2, 60, 4), WOOD_SHADES[3], "WoodPlanks", v(0, floor + 30, z0))
	backdrop(
		list,
		"KitchenWall",
		v(wx * 2, height - 60, 4),
		TILE_WHITE,
		"CeramicTiles",
		v(0, floor + 60 + (height - 60) / 2, z0)
	)
	for k = 1, 5 do
		backdrop(
			list,
			"TileBand",
			v(wx * 2, 1.2, 1),
			shade(TILE_WHITE, 0.82),
			"SmoothPlastic",
			v(0, floor + 60 + k * 50, z0 + 2.4)
		)
	end
	-- 양념 선반 2단 (병 3개는 Wobble, m5-20)
	local shelfZ = z0 + 14
	for row, y in { -40, 0 } do
		addAll(list, MapKitShapes.bevelBox("KitchenShelf", v(140, 2, 24), STAINLESS, "Metal", v(0, y, shelfZ), 0.5))
		for _, x in { -64, 64 } do
			part(list, "ShelfBracket", "Block", v(1.4, 10, 20), HOOD_DARK, "Metal", v(x, y - 6, shelfZ - 1))
		end
		if row == 2 then
			for k, b in
				{
					{ x = -40, h = 15, c = PALETTE.Soy },
					{ x = -30, h = 13, c = PALETTE.Egg },
					{ x = 36, h = 16, c = PALETTE.Tuna },
				}
			do
				local bottle = part(
					list,
					HotPlateArt.SAUCE_BOTTLE,
					"Cylinder",
					v(b.h, 6, 6),
					b.c,
					"Glass",
					v(b.x, y + 1 + b.h / 2, shelfZ),
					UPRIGHT
				)
				bottle.reflectance = 0.15 + k * 0.02
				part(
					list,
					"BottleCap",
					"Cylinder",
					v(2, 3, 3),
					HOOD_DARK,
					"SmoothPlastic",
					v(b.x, y + 2 + b.h, shelfZ),
					UPRIGHT
				)
			end
			part(
				list,
				"SaltTub",
				"Cylinder",
				v(10, 12, 12),
				PALETTE.Rice,
				"SmoothPlastic",
				v(8, y + 6, shelfZ),
				UPRIGHT
			)
		else
			for i = 0, 4 do
				part(
					list,
					"SpiceJar",
					"Cylinder",
					v(9, 7, 7),
					if i % 2 == 0 then { r = 180, g = 70, b = 40 } else { r = 120, g = 120, b = 60 },
					"Glass",
					v(-50 + i * 12, y + 5.5, shelfZ),
					UPRIGHT
				)
			end
			for i = 0, 2 do
				addAll(
					list,
					MapKitShapes.rimDisc(
						"StackedPlate",
						22,
						1,
						PALETTE.Porcelain,
						"SmoothPlastic",
						v(30, y + 1.5 + i * 1.4, shelfZ),
						{ rimColor = PALETTE.PorcelainRim, segments = 10 }
					)
				)
			end
		end
	end
	-- 왼쪽(-X) 벽: 판벽 + 메뉴판 줄 + 노렌
	backdrop(
		list,
		"SideWall",
		v(4, height, depth),
		shade(DARK_WOOD, 1.1),
		"WoodPlanks",
		v(-wx, floor + height / 2, midZ)
	)
	backdrop(list, "SideWainscot", v(5, 60, depth), WOOD_SHADES[3], "WoodPlanks", v(-wx + 1, floor + 30, midZ))
	for k = 0, 7 do
		local z = z0 + 60 + k * 36
		part(list, "MenuBoard", "Block", v(1.4, 40, 24), { r = 214, g = 186, b = 140 }, "Wood", v(-wx + 3.5, 30, z))
		part(list, "MenuInk", "Block", v(0.3, 26, 3), PALETTE.Nori, "SmoothPlastic", v(-wx + 4.4, 32, z + 4))
		part(list, "MenuPrice", "Block", v(0.3, 4, 10), PALETTE.Tuna, "SmoothPlastic", v(-wx + 4.4, 14, z - 3))
	end
	part(list, "MenuRail", "Block", v(3, 3, depth - 80), DARK_WOOD, "Wood", v(-wx + 4, 52, midZ))
	for k = -1, 1 do
		local cloth =
			part(list, "Noren", "Block", v(1, 40, 26), PALETTE.Noren, "Fabric", v(-wx + 5, -30, cz + 150 + k * 28))
		cloth.anim = { kind = "Sway", period = 6 + k, amount = 3, axis = "Z" }
	end
	-- 오른쪽(+X) 벽: 회벽 + 밤 거리 창 3개 (차가운 파랑)
	local wallColor = { r = 70, g = 58, b = 54 }
	backdrop(list, "SideWall", v(4, height, depth), wallColor, "Plaster", v(wx, floor + height / 2, midZ))
	backdrop(list, "SideWainscot", v(5, 60, depth), WOOD_SHADES[3], "WoodPlanks", v(wx - 1, floor + 30, midZ))
	for i, z in { cz - 110, cz, cz + 110 } do
		addWindow(list, v(wx - 2, -20, z), "Z", -1, 40 + i) -- inward = -X
	end
	-- 앞(+Z) 벽: 회벽 + 창 2개
	backdrop(list, "FrontWall", v(wx * 2, height, 4), wallColor, "Plaster", v(0, floor + height / 2, z1))
	backdrop(list, "FrontWainscot", v(wx * 2, 60, 5), WOOD_SHADES[3], "WoodPlanks", v(0, floor + 30, z1 - 1))
	for i, x in { -100, 100 } do
		addWindow(list, v(x, -20, z1 - 2), "X", -1, 50 + i)
	end
	-- 벽 기둥 (모서리·창 사이)
	for _, x in { -wx + 4, 0, wx - 4 } do
		backdrop(list, "WallPost", v(8, height, 8), DARK_WOOD, "Wood", v(x, floor + height / 2, z1 - 4))
	end
	for _, z in { z0 + 4, cz - 55, cz + 55 } do
		backdrop(list, "WallPost", v(8, height, 8), DARK_WOOD, "Wood", v(wx - 4, floor + height / 2, z))
	end
end

-- 종이 등 (천장에서 매달림, Sway). 빛은 둘에 하나.
local function addLanterns(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local spots = {
		v(-150, 70, cz - 90),
		v(-150, 80, cz),
		v(-150, 70, cz + 90),
		v(150, 80, cz - 90),
		v(150, 70, cz),
		v(150, 80, cz + 90),
	}
	for i, at in spots do
		local lamp = part(list, "PaperLantern", "Ball", v(12, 12, 12), LAMP_PAPER, "Neon", at)
		lamp.anim = { kind = "Sway", period = 6 + (i % 3), amount = 3, axis = "X" }
		part(
			list,
			"PaperLanternCap",
			"Cylinder",
			v(2, 7, 7),
			LACQUER,
			"SmoothPlastic",
			v(at.x, at.y + 6.5, at.z),
			UPRIGHT
		)
		part(
			list,
			"PaperLanternCap",
			"Cylinder",
			v(2, 7, 7),
			LACQUER,
			"SmoothPlastic",
			v(at.x, at.y - 6.5, at.z),
			UPRIGHT
		)
		local cordLen = HotPlateArt.CEILING_Y - (at.y + 7.5)
		part(
			list,
			"PaperLanternCord",
			"Cylinder",
			v(cordLen, 0.6, 0.6),
			HOOD_DARK,
			"SmoothPlastic",
			v(at.x, at.y + 7.5 + cordLen / 2, at.z),
			UPRIGHT
		)
		if i % 2 == 1 then
			lamp.light = { kind = "Point", color = LAMP_LIGHT, brightness = 1.6, range = 50 }
		end
	end
	-- 천장 선풍기 2대 (날개 Spin)
	for _, x in { -110, 110 } do
		local y = HotPlateArt.CEILING_Y - 20
		part(list, "FanRod", "Cylinder", v(16, 1.6, 1.6), HOOD_DARK, "Metal", v(x, y + 10, cz + 120), UPRIGHT)
		part(list, "FanHub", "Cylinder", v(4, 7, 7), HOOD_DARK, "Metal", v(x, y, cz + 120), UPRIGHT)
		part(list, "FanBlade", "Block", v(60, 0.6, 7), DARK_WOOD, "Wood", v(x, y - 1, cz + 120)).anim =
			{ kind = "Spin", period = 3, axis = "Y" }
	end
end

function HotPlateArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	addFrames(list)
	addPillars(list)
	addCustomerFace(list, -15, cz + 13, SKINS[1])
	addCustomerFace(list, 15, cz + 5, SKINS[2])
	addCustomerFace(list, -2, cz - 19, SKINS[3])
	local spatulaBaseY = HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT) + 26
	addSpatula(list, v(-(half + 10), spatulaBaseY, cz + 11), -15)
	addSpatula(list, v(half + 10, spatulaBaseY, cz - 13), 15)
	addHood(list)
	addBurners(list)
	addEmbers(list)
	addCounter(list)
	addGuests(list)
	addCounterProps(list)
	addRoom(list)
	addLanterns(list)
	return list
end

-- 손님 얼굴(아래) → 층 옆 → 맨 위층 → 맨 위층 바깥 앞쪽 끝점 (철판 가운데를 봐요)
function HotPlateArt.introCamera(): { IntroPoint }
	local cz = HotPlateLogic.centerZ()
	local bottom = HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT)
	return {
		{ pos = v(-55, bottom - 10, cz - 33), lookAt = v(0, bottom - 26, cz) },
		{ pos = v(55, -22, cz - 23), lookAt = v(0, -30, cz) },
		{ pos = v(50, 14, cz + 37), lookAt = v(0, 0, cz) },
		{ pos = v(0, 18, cz + 65), lookAt = v(0, 0, cz) },
	}
end

-- 층마다 윗면 위 SIGHT_MIN~SIGHT_MAX, 철판 안쪽 상자
function HotPlateArt.courseVolume(): { MapKitLogic.Bounds }
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	local boxes = {}
	for layer = 1, HotPlateLogic.LAYER_COUNT do
		local top = HotPlateLogic.layerTopY(layer)
		table.insert(boxes, {
			min = v(-half, top + HotPlateArt.SIGHT_MIN, cz - half),
			max = v(half, top + HotPlateArt.SIGHT_MAX, cz + half),
		})
	end
	return boxes
end

function HotPlateArt.isGlowing(elapsed: number): boolean
	return elapsed >= HotPlateLogic.HEAT_DURATION * HotPlateArt.GLOW_FROM
end

return HotPlateArt
