--!strict
-- "회전 꼬치 쇼다운" 아트 데이터 (m4-03). Roblox API를 쓰지 않아요 — lune 테스트(tests/map-art-arena.spec.luau)에서 바로 불러요.
-- 판정(무대 조각·꼬치·기둥·셰프 손 일정·낙하 높이)은 SkewerShowdownLogic/SkewerShowdown 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 무대 중심(origin, 윗면 높이 0) 기준 로컬이에요. 가게 문은 로컬 -Z 쪽 (우승 연출에서 초밥이 문을 박차고
-- 나가는 방향(장면 로컬 -Z)과 같아요).
--   SkewerShowdownArt.decor() -> { DecorSpec }          움직이지 않는 장식 (기둥 장식, 접시 굽, 가게 문, 아래 셰프)
--   SkewerShowdownArt.sliceDecor(index) -> { DecorSpec } 조각 하나에 붙는 장식 (금 선, 남색 테두리) — 조각 Model에 넣어 같이 사라져요
--   SkewerShowdownArt.skewerFood(spec) -> { DecorSpec }  꼬치에 꽂힌 닭·대파 (꼬치 로컬: X = 바깥쪽, 꼬치 가운데 = 0)
--   SkewerShowdownArt.skewerHitbox(spec) -> Bounds       꼬치 판정 상자 (꼬치 로컬). 음식 장식은 이 안에만 둬요
--   SkewerShowdownArt.skewerFoodWithinHitbox(specs, spec) -> (boolean, string?)
--   SkewerShowdownArt.handDecor() -> { DecorSpec }       셰프 손 장식 (손바닥 중심 로컬): 손끝, 소매
--   SkewerShowdownArt.introCamera() -> { IntroPoint }    가게 문 → 무대 한 바퀴 → 무대 바깥 끝점
--   SkewerShowdownArt.courseVolume() -> { Bounds }       장식이 들어가면 안 되는 상자 (무대 윗면 위 2~12, 반지름 안)
--   SkewerShowdownArt.LANTERN                            PointLight를 붙일 장식 파츠 이름
--   SkewerShowdownArt.BUDGET                             "Extended" (m5-24: 장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
--   SkewerShowdownArt.LIGHTING                           맵 조명 분위기 (m5-24: MapLighting.PRESETS 초안을 옮겨 다듬음)
--
-- m5-24 "축제 해 질 녘 꼬치 노점": 무대(거대 접시)는 축제 광장 위 높이 106에 떠 있고, 바로 밑에 숯불 화로(석쇠·숯·불티)가
-- 무대 기둥을 받쳐요. 광장 둘레에 노점 6개(바람개비·깃발), 등롱 줄 8개, 망루(야구라), 그 바깥에 거리 건물 정면 12채와
-- 불꽃놀이 탑. 가게 문은 돌 기단 위(그대로 -Z, 툇마루 높이 규칙 유지). 낙하선 -20, 광장 바닥 -106, 화로 윗면 -36.
-- 움직이는 장식은 전부 무대 밖 고정 장식에만 (조각·꼬치 음식·손 장식에는 anim 없음 — 판정 파츠와 같이 움직여요).

local Logic = require(script.Parent.SkewerShowdownLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE

local SkewerShowdownArt = {}

SkewerShowdownArt.LANTERN = "Lantern"
SkewerShowdownArt.BUDGET = "Extended"

-- 맵 조명 (m5-24): 축제 해 질 녘 — 자주-주황 Decay, Glare, 낮은 Ambient(등롱·숯불이 돋보이게)
SkewerShowdownArt.LIGHTING = {
	ClockTime = 18.2,
	Brightness = 1.5,
	Ambient = { r = 76, g = 62, b = 96 },
	OutdoorAmbient = { r = 110, g = 88, b = 124 },
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.15,
		Color = { r = 236, g = 160, b = 132 },
		Decay = { r = 104, g = 60, b = 118 },
		Glare = 0.4,
		Haze = 1.2,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.14,
		TintColor = { r = 255, g = 234, b = 224 },
	},
	Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.1 },
	SunRays = { Intensity = 0.08, Spread = 0.7 },
} :: MapLighting.LightingPreset

-- 축제 광장 (m5-24, 무대 중심 기준 로컬)
SkewerShowdownArt.GROUND_Y = -106 -- 광장 바닥 (낙하선 -20보다 86 아래, 셰프가 이 위에 서요)
SkewerShowdownArt.BRAZIER_TOP_Y = -36 -- 화로 테두리 (낙하선보다 16 아래)
SkewerShowdownArt.CHEF_Z = 72 -- 무대 아래 셰프 자리 (화로 뒤, 무대를 봐요)
SkewerShowdownArt.STALL_RADIUS = 96
SkewerShowdownArt.STRING_RADIUS = 62
SkewerShowdownArt.STREET_RADIUS = 168
SkewerShowdownArt.YAGURA_YAW = 140
SkewerShowdownArt.YAGURA_RADIUS = 112
SkewerShowdownArt.STAGE_LAMP = { x = 0, y = 40, z = 42 } -- 무대 그림자 SpotLight 자리 (+Z 바깥 위)
SkewerShowdownArt.SIGHT_MIN = 2
SkewerShowdownArt.SIGHT_MAX = 12
-- 가게 문 위치 (무대 앞쪽 = 로컬 -Z). QA B1 뒤로 M2 ShopDoor 자리(-40)보다 멀고 낮게 둬서
-- 점프+다이브(약 14 studs)로 닿는 무대 높이 장식이 없어요 (tests/map-art-arena "가짜 바닥").
SkewerShowdownArt.DOOR_Z = -(Logic.STAGE_RADIUS + 24)
-- 가게는 무대보다 이만큼 낮게 지어요 (QA B1: 툇마루가 무대 높이면 다이브로 닿는 가짜 바닥처럼 보임)
SkewerShowdownArt.DOOR_Y = -8

-- SkewerShowdown.luau의 무대 치수와 같아요 (판정 수치를 바꾸지 않으려고 여기서 다시 계산해요)
local STAGE_THICKNESS = 1.5
local STRIPS_PER_SLICE = 8
local SLICE_ANGLE = 2 * math.pi / Logic.SLICE_COUNT
local APOTHEM = Logic.STAGE_RADIUS * math.cos(SLICE_ANGLE / 2)
local EDGE_LENGTH = 2 * Logic.STAGE_RADIUS * math.sin(SLICE_ANGLE / 2)

local GOLD: RGB = { r = 214, g = 172, b = 64 }
local DARK_WOOD: RGB = { r = 104, g = 74, b = 50 }
local DOOR_WOOD: RGB = { r = 160, g = 118, b = 74 }
local PLASTER: RGB = { r = 236, g = 226, b = 200 }
local SKIN: RGB = { r = 240, g = 198, b = 166 }
local CHICKEN: RGB = { r = 170, g = 94, b = 44 }
local LEEK_WHITE: RGB = { r = 236, g = 240, b = 218 }
local LEEK_GREEN: RGB = { r = 108, g = 160, b = 60 }
local EXIT_GREEN: RGB = { r = 40, g = 160, b = 80 }
-- m5-24 색 (60 = 짙은 남색 저녁·검은 화로, 30 = 나무·무대, 10 = 등롱 빛·불티)
local shade = MapKitLogic.shade
local STONE: RGB = { r = 92, g = 88, b = 104 }
local CAST_IRON: RGB = { r = 40, g = 38, b = 40 }
local COAL: RGB = { r = 34, g = 30, b = 30 }
local EMBER: RGB = { r = 255, g = 150, b = 60 } -- 숯불 (판정 경고 빨강 230,40,40과 다르게 주황-노랑)
local EMBER_DEEP: RGB = { r = 232, g = 96, b = 36 }
local FACADE: RGB = { r = 92, g = 64, b = 50 }
local ROOF: RGB = { r = 56, g = 58, b = 72 }
local WINDOW_GLOW: RGB = { r = 255, g = 196, b = 120 }
local WINDOW_DIM: RGB = { r = 70, g = 60, b = 76 }
local LANTERN_ORANGE: RGB = { r = 255, g = 120, b = 60 }
local SHRIMP: RGB = { r = 255, g = 132, b = 92 }

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

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로
local FACING_Z = v(0, 90, 0) -- 원기둥 축을 Z로 (앞을 보는 원판)

-- 무대 중심 기준 각도 angle(꼬치 각도와 같은 기준) 방향으로 radial만큼 간 점
local function radial(angle: number, r: number, y: number): Vec3
	return v(r * math.cos(angle), y, -r * math.sin(angle))
end

-- 기둥 위 금 띠·뚜껑, 무대 밑 접시 굽
local function addPillarAndFoot(list: { DecorSpec })
	part(list, "PillarBand", "Cylinder", v(0.6, 5.6, 5.6), GOLD, "Metal", v(0, 14.5, 0), UPRIGHT)
	part(list, "PillarCap", "Cylinder", v(0.8, 6.2, 6.2), GOLD, "Metal", v(0, 16.4, 0), UPRIGHT)
	part(list, "PillarFinial", "Ball", v(2.4, 2.4, 2.4), GOLD, "Metal", v(0, 17.8, 0))
	part(list, "PlateFoot", "Cylinder", v(2, 18, 18), PALETTE.Porcelain, "SmoothPlastic", v(0, -2.6, 0), UPRIGHT)
	part(
		list,
		"PlateFootBand",
		"Cylinder",
		v(0.6, 18.4, 18.4),
		PALETTE.PorcelainRim,
		"SmoothPlastic",
		v(0, -2.4, 0),
		UPRIGHT
	)
end

-- 미닫이 문짝 하나 (나무 틀 + 창호지 창 2개 + 살)
local function addDoorLeaf(list: { DecorSpec }, x: number, z: number)
	part(list, "DoorLeaf", "Block", v(5.8, 14, 0.4), DOOR_WOOD, "Wood", v(x, 7, z))
	for _, y in { 4, 10 } do
		part(list, "DoorPaper", "Block", v(4.2, 5, 0.1), PALETTE.Rice, "SmoothPlastic", v(x, y, z + 0.25))
		part(list, "DoorBar", "Block", v(0.3, 5, 0.15), DARK_WOOD, "Wood", v(x, y, z + 0.32))
		part(list, "DoorBar", "Block", v(4.2, 0.3, 0.15), DARK_WOOD, "Wood", v(x, y, z + 0.32))
	end
end

-- 가게 문: 나무 미닫이 + 노렌 + 출구 판 + 등롱 + 가게 앞면
local function addShopDoor(list: { DecorSpec })
	local z = SkewerShowdownArt.DOOR_Z
	local first = #list + 1
	part(list, "Porch", "Block", v(32, 1, 10), PALETTE.Wood, "WoodPlanks", v(0, -0.5, z + 1))
	part(list, "ShopBody", "Block", v(46, 24, 18), DARK_WOOD, "WoodPlanks", v(0, 12, z - 10.5))
	for _, side in { -1, 1 } do
		part(list, "DoorPost", "Block", v(2, 16, 2), DARK_WOOD, "Wood", v(side * 7, 8, z))
		part(list, "ShopWall", "Block", v(15, 22, 1.5), PLASTER, "Plaster", v(side * 15, 11, z - 0.8))
		part(list, "ShopBeam", "Block", v(15, 2, 1.7), DARK_WOOD, "Wood", v(side * 15, 1, z - 0.7))
		part(list, "ShopBeam", "Block", v(2, 22, 1.7), DARK_WOOD, "Wood", v(side * 22.5, 11, z - 0.7))
		addDoorLeaf(list, side * 3, z)
		-- 등롱 (빨간 몸통 + 검은 뚜껑·받침). LANTERN 파츠에 PointLight가 붙어요.
		part(list, SkewerShowdownArt.LANTERN, "Ball", v(3, 3, 3), PALETTE.Lacquer, "Neon", v(side * 9.5, 12.5, z + 1.8))
		part(
			list,
			"LanternCap",
			"Cylinder",
			v(0.5, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 14.1, z + 1.8),
			UPRIGHT
		)
		part(
			list,
			"LanternCap",
			"Cylinder",
			v(0.5, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 10.9, z + 1.8),
			UPRIGHT
		)
		part(
			list,
			"LanternCord",
			"Block",
			v(0.2, 2.6, 0.2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 15.6, z + 1.8)
		)
	end
	part(list, "DoorLintel", "Block", v(16, 2, 2.5), DARK_WOOD, "Wood", v(0, 17, z))
	-- 노렌 3폭 + 가운데 흰 동그라미 문장
	for i = -1, 1 do
		part(list, "Noren", "Block", v(4.4, 4, 0.15), PALETTE.Noren, "Fabric", v(i * 4.6, 13.8, z + 1.3))
	end
	part(list, "NorenCrest", "Cylinder", v(0.05, 2, 2), PALETTE.Rice, "Fabric", v(0, 14.2, z + 1.4), FACING_Z)
	-- "출구" 느낌 초록 판 (흰 화살표)
	part(list, "ExitSign", "Block", v(6, 2, 0.4), EXIT_GREEN, "SmoothPlastic", v(0, 19.4, z + 0.6))
	part(list, "ExitArrow", "Block", v(3, 0.4, 0.1), PALETTE.Rice, "Neon", v(0.4, 19.4, z + 0.85))
	part(list, "ExitArrowHead", "Block", v(1, 1, 0.1), PALETTE.Rice, "Neon", v(-1.1, 19.4, z + 0.85), v(0, 0, 45))
	-- 기와 차양
	part(
		list,
		"DoorRoof",
		"Block",
		v(24, 0.8, 6),
		{ r = 70, g = 72, b = 84 },
		"ClayRoofTiles",
		v(0, 22.4, z + 1),
		v(20, 0, 0)
	)
	-- 가게 전체를 무대보다 DOOR_Y만큼 낮춰요
	for i = first, #list do
		local offset = list[i].offset
		list[i].offset = v(offset.x, offset.y + SkewerShowdownArt.DOOR_Y, offset.z)
	end
end

-- ── m5-24 축제 거리 (무대 바깥, 전부 고정 장식) ─────────────────────────────
local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, s in specs do
		table.insert(list, s)
	end
end

-- 마지막으로 넣은 장식 (조명·파티클·움직임을 달 때)
local function last(list: { DecorSpec }): DecorSpec
	return list[#list]
end

-- 큰 배경판은 그림자를 안 만들어요 (SkewerShowdown.build도 장식 그림자를 다 꺼요)
local function flat(list: { DecorSpec })
	last(list).castShadow = false
end

local GROUND_Y = SkewerShowdownArt.GROUND_Y

-- 광장 바닥: 돌판 격자 (shade 3개) + 거리 밖 먼 땅 (전체 뷰에서 빈 하늘이 안 보이게)
local function addPlaza(list: { DecorSpec })
	part(list, "OuterGround", "Block", v(1400, 4, 1400), shade(STONE, 0.6), "Asphalt", v(0, GROUND_Y - 5, 0))
	flat(list)
	-- 먼 마을 지붕선·산 실루엣 (반경 640, 안개 속 — 수평선이 비지 않게)
	local rng = MapKitShapes.rng(77)
	local count = 18
	for i = 0, count - 1 do
		local a = 2 * math.pi * i / count
		local h = rng:range(160, 300)
		local w = 2 * 640 * math.sin(math.pi / count) + 30
		part(
			list,
			"DistantSkyline",
			"Block",
			v(w, h, 40),
			shade(ROOF, rng:range(0.55, 0.8)),
			"SmoothPlastic",
			v(math.sin(a) * 640, GROUND_Y + h / 2, math.cos(a) * 640),
			v(0, math.deg(a), 0)
		)
		flat(list)
	end
	local tile = 80
	local n = 6
	local shades = { STONE, shade(STONE, 1.12), shade(STONE, 0.88) }
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			part(
				list,
				"PlazaStone",
				"Block",
				v(tile - 1, 4, tile - 1),
				shades[((i * 7 + j * 3) % 3) + 1],
				"Slate",
				v(-tile * n / 2 + tile * (i + 0.5), GROUND_Y - 2, -tile * n / 2 + tile * (j + 0.5))
			)
			flat(list)
		end
	end
end

-- 무대 아래 숯불 화로 (지름 76 무쇠 그릇 + 석쇠 + 숯, 붉은 빛·불티). 무대 기둥이 석쇠 가운데로 내려와요
local function addBrazier(list: { DecorSpec })
	local rimY = SkewerShowdownArt.BRAZIER_TOP_Y
	part(list, "BrazierBowl", "Cylinder", v(16, 76, 76), CAST_IRON, "Metal", v(0, rimY - 8, 0), UPRIGHT)
	last(list).reflectance = 0.1
	addAll(list, MapKitShapes.ring("BrazierRim", 37.5, 3, 3, 20, shade(CAST_IRON, 1.4), "Metal", v(0, rimY + 0.5, 0)))
	part(
		list,
		"BrazierBand",
		"Cylinder",
		v(2, 77, 77),
		PALETTE.LacquerDark,
		"SmoothPlastic",
		v(0, rimY - 6, 0),
		UPRIGHT
	)
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		part(
			list,
			"BrazierLeg",
			"Block",
			v(4, rimY - 16 - GROUND_Y, 4),
			CAST_IRON,
			"Metal",
			v(math.cos(a) * 30, (rimY - 16 + GROUND_Y) / 2, math.sin(a) * 30)
		)
		part(
			list,
			"BrazierFoot",
			"Ball",
			v(7, 7, 7),
			CAST_IRON,
			"Metal",
			v(math.cos(a) * 30, GROUND_Y + 2, math.sin(a) * 30)
		)
	end
	-- 숯: 어두운 덩어리 + 빛나는 덩어리 (호박-주황, 판정 경고 빨강과 다르게)
	local rng = MapKitShapes.rng(24)
	for i = 1, 26 do
		local a = rng:range(0, 2 * math.pi)
		local r = math.sqrt(rng:next()) * 32
		local d = rng:range(4, 7)
		local glow = i % 3 == 0
		part(
			list,
			if glow then "CoalGlow" else "Coal",
			"Ball",
			v(d, d, d),
			if glow then (if i % 2 == 0 then EMBER else EMBER_DEEP) else shade(COAL, rng:range(0.8, 1.3)),
			if glow then "Neon" else "Slate",
			v(math.cos(a) * r, rimY - 3 + rng:range(-0.5, 0.8), math.sin(a) * r)
		)
	end
	-- 숯 바닥 붉은 층
	part(list, "CoalBed", "Cylinder", v(1, 70, 70), EMBER_DEEP, "Neon", v(0, rimY - 5, 0), UPRIGHT)
	-- 석쇠 (가로 막대)
	for k = -4, 4 do
		local half = math.sqrt(math.max(37 ^ 2 - (k * 8) ^ 2, 1))
		part(list, "GrillBar", "Block", v(half * 2, 0.8, 0.8), shade(CAST_IRON, 1.6), "Metal", v(0, rimY - 0.5, k * 8))
	end
	-- 무대 기둥이 석쇠까지 내려와요 (기둥 판정은 -10까지, 그 아래는 장식)
	part(list, "PillarStem", "Cylinder", v(-10 - rimY, 3.5, 3.5), CAST_IRON, "Metal", v(0, (rimY - 10) / 2, 0), UPRIGHT)
	-- 빛·불티 (붉은 빛 하나 + 불티 둘)
	local core = part(list, "CoalCore", "Ball", v(3, 3, 3), EMBER, "Neon", v(0, rimY - 1, 22))
	core.light = { kind = "Point", color = { r = 255, g = 120, b = 50 }, brightness = 2.4, range = 55 }
	for i, at in { v(-18, rimY, -14), v(16, rimY, 10) } do
		part(list, "EmberVent", "Block", v(1, 0.2, 1), COAL, "Slate", at, nil, 1)
		last(list).particle = "Embers"
		last(list).particleRate = 4 + i
	end
end

-- 무대 아래 셰프 (m4-03 위치에서 화로 뒤 +Z로 옮겨 무대를 봐요). 셰프 파츠는 모두 y -20 아래
local function addChefBelow(list: { DecorSpec })
	local chef: { DecorSpec } = {}
	part(chef, "ChefTorso", "Block", v(34, 22, 16), PALETTE.Rice, "Fabric", v(0, -95, 0))
	part(chef, "ChefCollar", "Block", v(20, 2, 17), PALETTE.Noren, "Fabric", v(0, -83.5, 0))
	part(chef, "ChefScarf", "Block", v(8, 3, 2), PALETTE.Lacquer, "Fabric", v(0, -85, 8.6))
	part(chef, "ChefHead", "Ball", v(20, 20, 20), SKIN, "SmoothPlastic", v(0, -74, 0))
	part(chef, "ChefHat", "Cylinder", v(14, 18, 18), PALETTE.Rice, "Fabric", v(0, -60, 0), UPRIGHT)
	part(chef, "ChefHatPuff", "Ball", v(22, 22, 22), PALETTE.Rice, "Fabric", v(0, -50, 0))
	part(chef, "ChefHachimaki", "Cylinder", v(2.4, 20.4, 20.4), PALETTE.Noren, "Fabric", v(0, -68, 0), UPRIGHT)
	for _, side in { -1, 1 } do
		part(chef, "ChefEye", "Ball", v(2.4, 2.4, 2.4), PALETTE.Nori, "SmoothPlastic", v(side * 4, -72.5, 9.2))
		part(
			chef,
			"ChefBrow",
			"Block",
			v(4, 1, 1),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 4, -69.6, 9.4),
			v(0, 0, side * -10)
		)
		part(chef, "ChefMustache", "Block", v(4.5, 1.2, 1.5), PALETTE.Nori, "SmoothPlastic", v(side * 2.4, -77, 9.4))
		part(chef, "ChefArm", "Block", v(6, 26, 6), PALETTE.Rice, "Fabric", v(side * 22, -80, 0), v(0, 0, side * -20))
		part(chef, "ChefFist", "Ball", v(7, 7, 7), SKIN, "SmoothPlastic", v(side * 26.6, -66.5, 0))
	end
	addAll(list, MapKitShapes.transform(chef, v(0, 0, SkewerShowdownArt.CHEF_Z), v(0, 180, 0)))
	-- 셰프 앞 나무 카운터 (몸통 아래를 가려요)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"GrillCounter",
			v(70, 24, 14),
			DARK_WOOD,
			"WoodPlanks",
			v(0, GROUND_Y + 12, SkewerShowdownArt.CHEF_Z - 16),
			1.5
		)
	)
	part(
		list,
		"GrillCounterTop",
		"Block",
		v(74, 1.6, 16),
		DOOR_WOOD,
		"Wood",
		v(0, GROUND_Y + 24.8, SkewerShowdownArt.CHEF_Z - 16)
	)
end

-- 가게 문 밑 돌 기단 (가게가 광장보다 높은 길에 있어요). 윗면 -9.5 = 툇마루 바로 밑
local function addStoneBase(list: { DecorSpec })
	local z0 = SkewerShowdownArt.DOOR_Z + 4
	local depth = 80
	local top = SkewerShowdownArt.DOOR_Y - 1.5
	part(
		list,
		"StoneBase",
		"Block",
		v(90, top - GROUND_Y, depth),
		shade(STONE, 0.9),
		"Cobblestone",
		v(0, (top + GROUND_Y) / 2, z0 - depth / 2)
	)
	flat(list)
	-- 앞면 돌 쌓기 (어긋난 큰 돌)
	local rng = MapKitShapes.rng(7)
	for row = 0, 3 do
		local y = GROUND_Y + 12 + row * 24
		local x = -42 + (row % 2) * 8
		while x < 40 do
			local w = rng:range(16, 26)
			addAll(
				list,
				MapKitShapes.bevelBox(
					"StoneBlock",
					v(math.min(w, 44 - x), 21, 3),
					shade(STONE, rng:range(0.85, 1.2)),
					"Slate",
					v(x + math.min(w, 44 - x) / 2, y, z0 + 1),
					0.8
				)
			)
			x += w + 1
		end
	end
	-- 기단 위 가장자리 (가게 앞 돌 턱)
	part(list, "StoneCap", "Block", v(92, 2, 4), shade(STONE, 1.25), "Slate", v(0, top - 1, z0 + 1))
end

-- 축제 거리 건물 정면 (machiya): 1층 격자·노렌·불 켜진 창, 2층 격자창, 기와 처마
local function facade(seed: number, width: number, height: number): { DecorSpec }
	local f: { DecorSpec } = {}
	local rng = MapKitShapes.rng(seed)
	local wall = shade(FACADE, rng:range(0.85, 1.15))
	part(f, "FacadeWall", "Block", v(width, height, 12), wall, "WoodPlanks", v(0, GROUND_Y + height / 2, 0))
	f[#f].castShadow = false
	-- 1층 가게 (불빛 + 격자)
	part(f, "FacadeShopGlow", "Block", v(width - 16, 34, 1), shade(WINDOW_GLOW, 0.8), "Neon", v(0, GROUND_Y + 19, -6.2))
	for k = -3, 3 do
		part(
			f,
			"FacadeLattice",
			"Block",
			v(1.4, 34, 1.2),
			DARK_WOOD,
			"Wood",
			v(k * (width - 16) / 7, GROUND_Y + 19, -7)
		)
	end
	for k = -1, 1 do
		part(
			f,
			"FacadeNoren",
			"Block",
			v((width - 20) / 3 - 1, 12, 0.6),
			if seed % 2 == 0 then PALETTE.Noren else PALETTE.LacquerDark,
			"Fabric",
			v(k * (width - 20) / 3, GROUND_Y + 31, -7.6)
		)
	end
	-- 처마 밑 작은 등롱 3개 (거리 쪽 리듬, 빛 없음)
	for k = -1, 1 do
		part(
			f,
			"EaveLantern",
			"Ball",
			v(3.6, 3.6, 3.6),
			if (seed + k) % 2 == 0 then LANTERN_ORANGE else PALETTE.Rice,
			"Neon",
			v(k * width * 0.3, GROUND_Y + 37, -12)
		)
	end
	-- 1층 처마 (기와 경사)
	part(f, "FacadeEave", "Block", v(width + 6, 2, 14), ROOF, "ClayRoofTiles", v(0, GROUND_Y + 42, -8), v(-22, 0, 0))
	-- 위층 창 (층마다 2개, 격자)
	local floorY = GROUND_Y + 64
	while floorY < GROUND_Y + height - 16 do
		for _, sx in { -1, 1 } do
			local lit = rng:next() < 0.6
			part(
				f,
				"FacadeWindow",
				"Block",
				v(width * 0.3, 20, 1),
				if lit then WINDOW_GLOW else WINDOW_DIM,
				if lit then "Neon" else "SmoothPlastic",
				v(sx * width * 0.22, floorY, -6.2)
			)
			for k = -2, 2 do
				part(
					f,
					"FacadeWindowBar",
					"Block",
					v(0.8, 20, 0.8),
					DARK_WOOD,
					"Wood",
					v(sx * width * 0.22 + k * width * 0.06, floorY, -6.8)
				)
			end
		end
		part(f, "FacadeBand", "Block", v(width, 2, 1.4), DARK_WOOD, "Wood", v(0, floorY - 14, -6.4))
		floorY += 38
	end
	-- 지붕 (기와 + 용마루)
	part(
		f,
		"FacadeRoof",
		"Block",
		v(width + 8, 2.4, 26),
		ROOF,
		"ClayRoofTiles",
		v(0, GROUND_Y + height + 4, -2),
		v(-26, 0, 0)
	)
	part(f, "FacadeRidge", "Cylinder", v(width + 8, 3, 3), shade(ROOF, 0.7), "Slate", v(0, GROUND_Y + height + 9, 4))
	return f
end

local function addStreet(list: { DecorSpec })
	local count = 12
	local radius = SkewerShowdownArt.STREET_RADIUS
	for i = 0, count - 1 do
		local yaw = i * 360 / count + 15
		local a = math.rad(yaw)
		-- 가게 문(-Z) 쪽은 비워요 (돌 기단·가게가 그 자리)
		local x, z = math.sin(a) * radius, math.cos(a) * radius
		local rng = MapKitShapes.rng(100 + i)
		local height = rng:range(118, 160)
		-- 로컬 -Z(앞면)가 광장 가운데를 보게: Ry(yaw)가 -Z를 (-sin, -cos)로 돌려요
		addAll(
			list,
			MapKitShapes.transform(
				facade(i, 2 * radius * math.sin(math.pi / count) + 6, height),
				v(x, 0, z),
				v(0, yaw, 0)
			)
		)
	end
end

-- 노점 (yatai): 나무 수레 + 지붕 + 노렌 + 등롱 + 바람개비·깃발
local function stall(seed: number, kind: number): { DecorSpec }
	local s: { DecorSpec } = {}
	local top = GROUND_Y + 30
	addAll(s, MapKitShapes.bevelBox("StallCart", v(40, 30, 18), DOOR_WOOD, "WoodPlanks", v(0, GROUND_Y + 15, 0), 1.2))
	part(s, "StallCounter", "Block", v(42, 1.6, 20), shade(DOOR_WOOD, 1.2), "Wood", v(0, top + 0.8, 0))
	for _, sx in { -1, 1 } do
		part(s, "StallPost", "Block", v(2, 34, 2), DARK_WOOD, "Wood", v(sx * 19, top + 17, 8))
		part(s, "StallWheel", "Cylinder", v(2, 16, 16), DARK_WOOD, "Wood", v(sx * 21, GROUND_Y + 8, 0))
	end
	part(
		s,
		"StallRoof",
		"Block",
		v(48, 2, 28),
		if kind % 2 == 0 then PALETTE.Lacquer else PALETTE.Noren,
		"Fabric",
		v(0, top + 36, 2),
		v(-14, 0, 0)
	)
	for k = -1, 1 do
		part(s, "StallNoren", "Block", v(13, 9, 0.5), PALETTE.Rice, "Fabric", v(k * 13.6, top + 29, -11))
	end
	-- 진열 (꼬치구이·사과사탕·물풍선 중 하나)
	for k = -2, 2 do
		if kind == 0 then
			part(
				s,
				"StallSkewer",
				"Cylinder",
				v(10, 0.8, 0.8),
				PALETTE.Wood,
				"Wood",
				v(k * 6, top + 2.4, -4),
				v(0, 90, 20)
			)
			part(s, "StallSkewerMeat", "Block", v(2.4, 2.4, 6), SHRIMP, "SmoothPlastic", v(k * 6, top + 3.6, -6))
		elseif kind == 1 then
			part(s, "CandyApple", "Ball", v(4.4, 4.4, 4.4), PALETTE.Tuna, "Glass", v(k * 6, top + 3.8, -4))
			s[#s].reflectance = 0.25
			part(
				s,
				"CandyStick",
				"Cylinder",
				v(6, 0.5, 0.5),
				PALETTE.Rice,
				"SmoothPlastic",
				v(k * 6, top + 7.5, -4),
				UPRIGHT
			)
		else
			part(
				s,
				"WaterBalloon",
				"Ball",
				v(4, 4, 4),
				({ PALETTE.PastelPink, PALETTE.PastelSky, PALETTE.PastelYellow })[(k + 3) % 3 + 1],
				"SmoothPlastic",
				v(k * 6, top + 2.4, -4)
			)
		end
	end
	-- 등롱 2개 (지붕 앞)
	for _, sx in { -1, 1 } do
		part(s, "StallLantern", "Ball", v(5, 5, 5), PALETTE.Lacquer, "Neon", v(sx * 15, top + 24, -12))
		part(
			s,
			"StallLanternCap",
			"Cylinder",
			v(0.8, 3.4, 3.4),
			PALETTE.Nori,
			"SmoothPlastic",
			v(sx * 15, top + 26.8, -12),
			UPRIGHT
		)
	end
	-- 바람개비 (기둥 위, Spin)
	part(
		s,
		"Pinwheel",
		"Block",
		v(6, 6, 0.4),
		({ PALETTE.PastelPink, PALETTE.PastelSky, PALETTE.Egg })[seed % 3 + 1],
		"SmoothPlastic",
		v(19, top + 36, 8.8),
		v(0, 0, 45)
	)
	s[#s].anim = { kind = "Spin", period = 2 + seed % 3, axis = "Z" }
	-- 세로 깃발 (nobori, Sway)
	part(s, "NoboriPole", "Cylinder", v(56, 1.2, 1.2), DARK_WOOD, "Wood", v(-24, GROUND_Y + 28, -6), UPRIGHT)
	part(
		s,
		"Nobori",
		"Block",
		v(0.4, 30, 9),
		if seed % 2 == 0 then PALETTE.Egg else PALETTE.Rice,
		"Fabric",
		v(-24, GROUND_Y + 38, -1.4)
	)
	s[#s].anim = { kind = "Sway", period = 4 + seed % 3, amount = 4, axis = "Z" }
	return s
end

local function addStalls(list: { DecorSpec })
	local radius = SkewerShowdownArt.STALL_RADIUS
	local yaws = { 40, 85, 225, 265, 305, 345 }
	for i, yaw in yaws do
		local a = math.rad(yaw)
		local specs = stall(i, i % 3)
		addAll(list, MapKitShapes.transform(specs, v(math.sin(a) * radius, 0, math.cos(a) * radius), v(0, yaw, 0)))
	end
	-- 꼬치구이 노점 두 곳 김 (고정)
	for _, yaw in { 85, 265 } do
		local a = math.rad(yaw)
		local r = radius - 4
		part(
			list,
			"StallSteam",
			"Block",
			v(1, 0.2, 1),
			COAL,
			"Slate",
			v(math.sin(a) * r, GROUND_Y + 32, math.cos(a) * r),
			nil,
			1
		)
		last(list).particle = "Steam"
		last(list).particleRate = 2
	end
end

-- 등롱 줄: 광장 둘레 기둥 8개 사이에 늘어진 줄 + 등롱 (빛은 줄마다 하나)
local function addLanternStrings(list: { DecorSpec })
	local count = 8
	local radius = SkewerShowdownArt.STRING_RADIUS
	local topY = 58
	local poles: { Vec3 } = {}
	for i = 0, count - 1 do
		local a = math.rad(i * 360 / count + 22.5)
		local p = v(math.sin(a) * radius, topY, math.cos(a) * radius)
		table.insert(poles, p)
		part(
			list,
			"FestivalPole",
			"Cylinder",
			v(topY + 4 - GROUND_Y, 2.4, 2.4),
			DARK_WOOD,
			"Wood",
			v(p.x, (topY + 4 + GROUND_Y) / 2, p.z),
			UPRIGHT
		)
		part(list, "FestivalPoleCap", "Ball", v(3.4, 3.4, 3.4), GOLD, "Metal", v(p.x, topY + 5, p.z))
	end
	for i = 1, count do
		local a, b = poles[i], poles[i % count + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local sag = 5
		part(
			list,
			"LanternString",
			"Cylinder",
			v(len, 0.4, 0.4),
			PALETTE.Nori,
			"SmoothPlastic",
			v((a.x + b.x) / 2, topY - sag, (a.z + b.z) / 2),
			v(0, yaw, 0)
		)
		for k = 1, 5 do
			local t = k / 6
			local x, z = a.x + dx * t, a.z + dz * t
			local y = topY - sag - 4.5
			local warm = if (k + i) % 3 == 0 then PALETTE.Rice else LANTERN_ORANGE
			part(list, "FestivalLantern", "Ball", v(4, 4, 4), warm, "Neon", v(x, y, z))
			local lamp = last(list)
			if k == 3 then
				lamp.light = { kind = "Point", color = { r = 255, g = 168, b = 110 }, brightness = 1.4, range = 40 }
			elseif (k + i) % 2 == 0 then
				lamp.anim = { kind = "Sway", period = 5 + (k % 3), amount = 5, axis = "X" }
			end
			part(
				list,
				"FestivalLanternCap",
				"Cylinder",
				v(0.8, 2.6, 2.6),
				PALETTE.Nori,
				"SmoothPlastic",
				v(x, y + 2.3, z),
				UPRIGHT
			)
		end
	end
	-- 등롱 반짝임 둘
	for _, i in { 2, 6 } do
		local p = poles[i]
		part(list, "LanternSparkle", "Block", v(1, 0.2, 1), GOLD, "Metal", v(p.x * 0.92, topY - 8, p.z * 0.92), nil, 1)
		last(list).particle = "Sparkle"
		last(list).particleRate = 2
	end
end

-- 축제 망루 (야구라): 다리 4개 + 홍백 천 + 북 + 지붕 + 등롱
local function addYagura(list: { DecorSpec })
	local y: { DecorSpec } = {}
	local deck = GROUND_Y + 60
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				y,
				"YaguraLeg",
				"Block",
				v(3, deck + 40 - GROUND_Y, 3),
				DARK_WOOD,
				"Wood",
				v(sx * 16, (deck + 40 + GROUND_Y) / 2, sz * 16)
			)
		end
	end
	for _, yy in { GROUND_Y + 20, GROUND_Y + 40 } do
		part(y, "YaguraBrace", "Block", v(34, 2, 2), DARK_WOOD, "Wood", v(0, yy, -16))
		part(y, "YaguraBrace", "Block", v(2, 2, 34), DARK_WOOD, "Wood", v(-16, yy, 0))
		part(y, "YaguraBrace", "Block", v(2, 2, 34), DARK_WOOD, "Wood", v(16, yy, 0))
	end
	part(y, "YaguraDeck", "Block", v(40, 3, 40), DOOR_WOOD, "WoodPlanks", v(0, deck, 0))
	-- 홍백 천 (난간 둘레)
	for k = 0, 7 do
		part(
			y,
			"YaguraCloth",
			"Block",
			v(5, 10, 0.6),
			if k % 2 == 0 then PALETTE.Lacquer else PALETTE.Rice,
			"Fabric",
			v(-17.5 + k * 5, deck - 6.5, -20.4)
		)
	end
	part(y, "YaguraDrum", "Cylinder", v(10, 14, 14), PALETTE.Soy, "Wood", v(0, deck + 8, 0), v(0, 90, 0))
	part(y, "YaguraDrumHead", "Cylinder", v(10.4, 12, 12), PALETTE.Rice, "Leather", v(0, deck + 8, 0), v(0, 90, 0))
	part(y, "YaguraRoof", "Block", v(48, 3, 30), ROOF, "ClayRoofTiles", v(0, deck + 44, -10), v(-24, 0, 0))
	part(y, "YaguraRoof", "Block", v(48, 3, 30), ROOF, "ClayRoofTiles", v(0, deck + 44, 10), v(24, 0, 0))
	for _, sx in { -1, 1 } do
		part(y, "YaguraLantern", "Ball", v(6, 6, 6), LANTERN_ORANGE, "Neon", v(sx * 18, deck + 34, -18))
	end
	local a = math.rad(SkewerShowdownArt.YAGURA_YAW)
	local r = SkewerShowdownArt.YAGURA_RADIUS
	addAll(
		list,
		MapKitShapes.transform(y, v(math.sin(a) * r, 0, math.cos(a) * r), v(0, SkewerShowdownArt.YAGURA_YAW, 0))
	)
	last(list).light = { kind = "Point", color = { r = 255, g = 168, b = 110 }, brightness = 1.6, range = 50 }
end

-- 멀리 불꽃놀이 탑 실루엣 + 하늘의 불꽃 (거리 건물 뒤)
local function addFireworks(list: { DecorSpec })
	for i, at in { v(-200, 0, 210), v(230, 0, 150) } do
		local h = 200
		part(list, "FireworkTower", "Block", v(8, h, 8), shade(ROOF, 0.6), "Wood", v(at.x, GROUND_Y + h / 2, at.z))
		flat(list)
		for k = 1, 4 do
			part(
				list,
				"FireworkTowerBrace",
				"Block",
				v(20, 1.6, 1.6),
				shade(ROOF, 0.6),
				"Wood",
				v(at.x, GROUND_Y + k * 45, at.z),
				v(0, i * 30, 30)
			)
		end
		-- 터진 불꽃 (Neon 별 고리)
		local cy = GROUND_Y + h + 40
		local color = if i == 1 then { r = 255, g = 200, b = 120 } else { r = 255, g = 140, b = 190 }
		for k = 0, 9 do
			local a = k * math.pi / 5
			part(
				list,
				"FireworkStar",
				"Ball",
				v(3, 3, 3),
				color,
				"Neon",
				v(at.x + math.cos(a) * 18, cy + math.sin(a) * 18, at.z)
			)
		end
		part(list, "FireworkCore", "Ball", v(5, 5, 5), PALETTE.Rice, "Neon", v(at.x, cy, at.z))
		last(list).anim = { kind = "Pulse", period = 2.5 + i, amount = 0.15 }
	end
end

-- 무대 그림자 조명: 무대 +Z 바깥 등 기둥에 매단 좁은 SpotLight (꼬치 그림자가 무대에 — 점프 타이밍)
local function addStageLamp(list: { DecorSpec })
	local p = SkewerShowdownArt.STAGE_LAMP
	part(
		list,
		"StageLampPost",
		"Cylinder",
		v(p.y + 10 - GROUND_Y, 2.4, 2.4),
		DARK_WOOD,
		"Wood",
		v(0, (p.y + 10 + GROUND_Y) / 2, p.z + 10),
		UPRIGHT
	)
	part(list, "StageLampArm", "Block", v(1.6, 1.6, 11), DARK_WOOD, "Wood", v(0, p.y + 5, p.z + 4.5))
	local tilt = -math.deg(math.atan2(p.y, p.z))
	part(list, "StageLampShade", "Cylinder", v(4, 6, 6), CAST_IRON, "Metal", v(0, p.y + 1.6, p.z), UPRIGHT)
	part(list, "StageLamp", "Block", v(3, 3, 1), { r = 255, g = 236, b = 200 }, "Neon", v(0, p.y, p.z), v(tilt, 0, 0))
	last(list).light = {
		kind = "Spot",
		color = { r = 255, g = 226, b = 190 },
		brightness = 3,
		range = 60,
		angle = 70,
		face = "Front",
		shadows = true,
	}
end

function SkewerShowdownArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPillarAndFoot(list)
	addShopDoor(list)
	addChefBelow(list)
	-- m5-24 축제 광장
	addPlaza(list)
	addBrazier(list)
	addStoneBase(list)
	addStreet(list)
	addStalls(list)
	addLanternStrings(list)
	addYagura(list)
	addFireworks(list)
	addStageLamp(list)
	return list
end

-- 조각 index(1~SLICE_COUNT)에 붙는 장식: 앞쪽 경계의 얇은 금 선(윗면 위 0.05), 바깥 가장자리 남색 테두리.
function SkewerShowdownArt.sliceDecor(index: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local edge = (index - 1) * SLICE_ANGLE
	local bisector = (index - 0.5) * SLICE_ANGLE
	local inner = Logic.PILLAR_DIAMETER / 2 + 0.3
	local outer = APOTHEM - APOTHEM / STRIPS_PER_SLICE - 0.2 -- 남색 띠(바깥 줄) 앞에서 멈춰요
	local mid = (inner + outer) / 2
	part(
		list,
		"GoldLine",
		"Block",
		v(outer - inner, 0.06, 0.25),
		GOLD,
		"Metal",
		radial(edge, mid, 0.05),
		v(0, math.deg(edge), 0)
	)
	part(
		list,
		"RimLip",
		"Block",
		v(0.4, STAGE_THICKNESS, EDGE_LENGTH - 0.8),
		PALETTE.PorcelainRim,
		"SmoothPlastic",
		radial(bisector, APOTHEM + 0.2, -STAGE_THICKNESS / 2),
		v(0, math.deg(bisector), 0)
	)
	return list
end

local function skewerLength(spec: Logic.SkewerSpec): number
	return spec.outerReach - spec.innerReach
end

-- 꼬치에 꽂힌 닭(4)·대파(3) 조각. 단면은 꼬치 굵기(지름) 그대로라 판정 상자를 벗어나지 않아요.
function SkewerShowdownArt.skewerFood(spec: Logic.SkewerSpec): { DecorSpec }
	local list: { DecorSpec } = {}
	local thick = spec.radius * 2
	local chicken, leek, gap = 1.8, 1.2, 0.6
	local pieces = { "Chicken", "Leek", "Chicken", "Leek", "Chicken", "Leek", "Chicken" }
	local total = 0
	for i, kind in pieces do
		total += if kind == "Chicken" then chicken else leek
		if i > 1 then
			total += gap
		end
	end
	-- 바깥쪽으로 조금 치우쳐 꽂아요 (안쪽 손잡이 부분은 나무가 보이게)
	local x = -total / 2 + 1
	for _, kind in pieces do
		if kind == "Chicken" then
			part(
				list,
				"SkewerChicken",
				"Block",
				v(chicken, thick, thick),
				CHICKEN,
				"SmoothPlastic",
				v(x + chicken / 2, 0, 0)
			)
			x += chicken + gap
		else
			part(list, "SkewerLeek", "Block", v(0.7, thick, thick), LEEK_WHITE, "SmoothPlastic", v(x + 0.35, 0, 0))
			part(list, "SkewerLeek", "Block", v(0.5, thick, thick), LEEK_GREEN, "SmoothPlastic", v(x + 0.95, 0, 0))
			x += leek + gap
		end
	end
	assert(x - gap <= skewerLength(spec) / 2, "skewer food longer than skewer")
	return list
end

-- 꼬치 판정 상자 (꼬치 로컬). 서버는 몸통(반지름 Logic.BODY_RADIUS)이 꼬치 원기둥에 닿으면 맞음으로 봐요
-- (축에서 radius + BODY_RADIUS 안, 높이 ±radius와 몸통이 겹침). 그래서 원기둥을 감싸는 상자
-- (길이 × 지름 × 지름) 안의 장식은 "보이게 닿으면 맞는다"가 지켜져요.
function SkewerShowdownArt.skewerHitbox(spec: Logic.SkewerSpec): Bounds
	local half = skewerLength(spec) / 2
	return {
		min = v(-half, -spec.radius, -spec.radius),
		max = v(half, spec.radius, spec.radius),
	}
end

local EPSILON = 1e-6

function SkewerShowdownArt.skewerFoodWithinHitbox(specs: { DecorSpec }, spec: Logic.SkewerSpec): (boolean, string?)
	local box = SkewerShowdownArt.skewerHitbox(spec)
	for i, food in specs do
		local b = MapKitLogic.bounds({ food })
		if b == nil then
			continue
		end
		for _, axis in { "x", "y", "z" } do
			local lo, hi = (b.min :: any)[axis], (b.max :: any)[axis]
			if lo < (box.min :: any)[axis] - EPSILON or hi > (box.max :: any)[axis] + EPSILON then
				return false, `#{i} {food.name} sticks out on {axis}`
			end
		end
	end
	return true, nil
end

-- 셰프 손 장식 (손바닥 중심 로컬, SkewerShowdown.buildHand의 손가락 배치와 맞춰요): 둥근 손끝, 흰 조리복 소매
function SkewerShowdownArt.handDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	for i = 1, 4 do
		part(list, "Fingertip", "Ball", v(1.7, 1.7, 1.7), SKIN, "SmoothPlastic", v(-3.6 + (i - 1) * 2.4, -5.5, -3))
	end
	part(list, "Fingertip", "Ball", v(1.9, 1.9, 1.9), SKIN, "SmoothPlastic", v(0, -4.5, 3.6))
	part(list, "Knuckles", "Cylinder", v(9, 1.8, 1.8), SKIN, "SmoothPlastic", v(0, -0.6, -3))
	part(list, "Cuff", "Cylinder", v(1.2, 9.5, 9.5), PALETTE.Noren, "Fabric", v(0, 1.6, 0), UPRIGHT)
	part(list, "Sleeve", "Cylinder", v(10, 9, 9), PALETTE.Rice, "Fabric", v(0, 7.2, 0), UPRIGHT)
	return list
end

-- 가게 문 → 무대 오른쪽 → 뒤 → 왼쪽 → 무대 바깥 높이 16에서 무대 가운데를 보며 끝나요 (m3-04 B2: 끝점이 고정).
function SkewerShowdownArt.introCamera(): { IntroPoint }
	local center = v(0, 0, 0)
	local z = SkewerShowdownArt.DOOR_Z
	return {
		{ pos = v(14, 6, z + 20), lookAt = v(0, 9 + SkewerShowdownArt.DOOR_Y, z) },
		{ pos = v(36, 12, -16), lookAt = center },
		{ pos = v(18, 14, 34), lookAt = center },
		{ pos = v(-32, 12, 20), lookAt = center },
		{ pos = v(-28, 16, -22), lookAt = center },
	}
end

function SkewerShowdownArt.courseVolume(): { Bounds }
	local r = Logic.STAGE_RADIUS
	return {
		{
			min = v(-r, SkewerShowdownArt.SIGHT_MIN, -r),
			max = v(r, SkewerShowdownArt.SIGHT_MAX, r),
		},
	}
end

return SkewerShowdownArt
