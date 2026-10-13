--!strict
-- "줄다리기 발판" 아트 데이터 (m5-18 → m5-24 v2). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정(발판·낙하 깊이·스폰)은 TugOfWarPlatformLayout/TugOfWarPlatform 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 발판 중심(flatPivot = origin * CFrame.new(0, 0, Layout.CENTER_Z), 기울지 않은 상태의 윗면 = y 0)
-- 기준 로컬이에요.
--   TugOfWarPlatformArt.deckDecor() -> { DecorSpec }   발판과 같이 기울어지는 장식 (저울 접시·테두리 트림·동아줄·무게추)
--                                                       — 서버가 매 틱 같이 옮기므로 anim 금지, 개수도 적게
--   TugOfWarPlatformArt.decor() -> { DecorSpec }       기울지 않는 장식 (돌절구 받침대, 가게 마당 세계)
--   TugOfWarPlatformArt.introCamera() -> { IntroPoint } 마당 전체 → 받침대 → 저울 접시 → 출발 자리
--   TugOfWarPlatformArt.LANTERN                        PointLight를 붙일 장식 파츠 이름 (TugOfWarPlatform.build)
--   TugOfWarPlatformArt.BUDGET / LIGHTING / CODE_EXTRAS m5-24 Extended 예산, 맵 조명, build가 Instance.new로 붙이는 수
--
-- m5-24 세계 "가게 마당, 해 질 녘 대저울": 발판(시소)은 돌절구 + 나무통 받침 위에 있고, 그 아래(낙하선 -25보다
-- 15 아래) 돌바닥 마당. 뒤(-Z)는 가게 뒷벽·뒷문·기와 처마, 옆은 나무 담장, +X 쪽에 감나무, -X 쪽에 장독대.
-- 발판 위 나무 들보(가로대)에 매단 작업등이 그림자 SpotLight — 발판 기울기가 마당에 그림자로 읽혀요.
-- 연장전(발판이 90°까지 돌아요)에도 부딪혀 보이지 않게 고정 장식은 발판이 도는 원(반지름 37, |z| ≤ 12) 밖에 둬요
-- (받침대만 예외 — 축 바로 아래).

local Layout = require(script.Parent.TugOfWarPlatformLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE
local shade = MapKitLogic.shade

local TugOfWarPlatformArt = {}

TugOfWarPlatformArt.LANTERN = "Lantern"
TugOfWarPlatformArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
-- TugOfWarPlatform.build가 Lantern마다 PointLight를 하나씩 붙여요 (등 2개)
TugOfWarPlatformArt.CODE_EXTRAS = { lights = 2, particles = 0 }

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- 해 질 녘 가게 마당: 노을 주황 + 담장 그늘 청색 (로비 오후 2시와 다르게)
TugOfWarPlatformArt.LIGHTING = {
	ClockTime = 18,
	Brightness = 2,
	Ambient = c(92, 98, 132), -- 담장 그늘 청색
	OutdoorAmbient = c(128, 126, 156),
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.26,
		Offset = 0.15,
		Color = c(236, 186, 150),
		Decay = c(120, 84, 110),
		Glare = 0.35,
		Haze = 1.2,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.08, TintColor = c(255, 240, 226) },
	Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.2 },
	SunRays = { Intensity = 0.06, Spread = 0.6 },
} :: MapLighting.LightingPreset

local GOLD: RGB = c(214, 172, 64) -- 놋쇠
local GOLD_DARK: RGB = shade(GOLD, 0.7)
local DARK_WOOD: RGB = c(104, 74, 50)
local MID_WOOD: RGB = c(140, 100, 66)
local ROPE: RGB = c(206, 170, 108)
local RIBBON: RGB = c(196, 44, 40)
local PLASTER: RGB = c(226, 212, 186)
local YARD: RGB = c(146, 140, 134) -- 마당 돌바닥 (회색, 판정 발판 나무색보다 어둡고 차갑게)
local STONE: RGB = c(128, 122, 116)
local ROOF: RGB = c(70, 74, 82)
local ONGGI: RGB = c(84, 52, 34) -- 장독 갈색 유약
local PERSIMMON: RGB = c(255, 128, 36)
local LEAF: RGB = c(150, 120, 52) -- 늦가을 잎 (노란 올리브)
local LANTERN_GLOW: RGB = c(255, 168, 92)

TugOfWarPlatformArt.YARD_Y = -40 -- 마당 바닥 윗면 (낙하선 -25보다 15 아래)
local YARD_Y = TugOfWarPlatformArt.YARD_Y
local SWEEP_RADIUS = 37 -- 발판이 도는 원 (반 길이 35 + 여유)

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

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
end

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로 (세워서 접시·기둥 모양)

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
): DecorSpec
	return part(list, name, "Cylinder", v(h, d, d), color, material, v(x, y + h / 2, z), UPRIGHT)
end

local PLATFORM_TOP = 0 -- flatPivot 기준 발판 윗면 (기울지 않은 상태)
local PLATFORM_BOTTOM = -Layout.THICKNESS

---------------------------------------------------------------------------------- 발판과 같이 기우는 것

-- 저울 접시: 발판 양 끝 위 얕은 도자기 접시 + 놋쇠 테두리 (m5-18 그대로) + 발판 끝 아래 놋쇠 접시 받침(반사)
local function addPanRims(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * (Layout.HALF_LENGTH - 9)
		part(
			list,
			"PanDish",
			"Cylinder",
			v(1, 18, 18),
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(x, PLATFORM_TOP + 0.5, 0),
			UPRIGHT
		)
		-- m5-24: 꽉 찬 원판이 도자기 접시를 덮어 "떠 있는 바닥"처럼 보여서 얇은 테두리 고리로 (가짜 바닥 없음)
		append(list, MapKitShapes.ring("PanRimLip", 8.9, 0.8, 0.6, 16, GOLD, "Metal", v(x, PLATFORM_TOP + 1.1, 0)))
		-- m5-24: 발판 아래로 매달린 큰 놋쇠 저울 접시 (밑에서 보면 "대저울")
		local pan =
			part(list, "ScalePan", "Cylinder", v(1.2, 20, 20), GOLD, "Metal", v(x, PLATFORM_BOTTOM - 4, 0), UPRIGHT)
		pan.reflectance = 0.35
		append(
			list,
			MapKitShapes.ring("ScalePanRim", 9.6, 0.8, 1.6, 14, GOLD_DARK, "Metal", v(x, PLATFORM_BOTTOM - 3.2, 0))
		)
		for _, dz in { -6, 6 } do
			part(
				list,
				"ScalePanChain",
				"Cylinder",
				v(4, 0.4, 0.4),
				GOLD_DARK,
				"Metal",
				v(x, PLATFORM_BOTTOM - 2, dz),
				UPRIGHT
			)
		end
	end
end

-- 발판 테두리 트림: 윗면보다 0.2 아래, 바깥으로 0.6 — 두께감·가장자리 가독성 (발판 하위라 같이 기울어요)
local function addDeckTrim(list: { DecorSpec })
	append(
		list,
		MapKitShapes.lipTrim(
			"DeckTrim",
			v(Layout.LENGTH, 0, Layout.WIDTH),
			0.6,
			Layout.THICKNESS - 0.2,
			DARK_WOOD,
			"Wood",
			v(0, PLATFORM_TOP - 0.2 - (Layout.THICKNESS - 0.2) / 2, 0)
		)
	)
	-- 옆면 놋쇠 띠 무늬 (양 긴 변 중앙)
	for _, side in { -1, 1 } do
		part(
			list,
			"DeckBrassPlate",
			"Block",
			v(10, 1, 0.3),
			GOLD,
			"Metal",
			v(0, PLATFORM_TOP - 1.1, side * (Layout.HALF_WIDTH + 0.75))
		).reflectance =
			0.3
	end
end

-- 동아줄: 발판 양 끝 바깥으로 늘어진 굵은 줄 + 매듭 + 빨간 리본 (충돌 없음, 순수 장식, anim 없음)
local function addRopes(list: { DecorSpec })
	for _, side in { -1, 1 } do
		for _, z in { -6, 6 } do
			part(
				list,
				"Rope",
				"Cylinder",
				v(9, 1.2, 1.2),
				ROPE,
				"Fabric",
				v(side * (Layout.HALF_LENGTH + 3), PLATFORM_BOTTOM - 2.5, z),
				v(0, 0, side * -55)
			)
			part(
				list,
				"RopeKnot",
				"Ball",
				v(2, 2, 2),
				shade(ROPE, 0.85),
				"Fabric",
				v(side * (Layout.HALF_LENGTH + 5.6), PLATFORM_BOTTOM - 6.2, z)
			)
		end
		part(
			list,
			"RopeRibbon",
			"Block",
			v(0.3, 3, 2),
			RIBBON,
			"Fabric",
			v(side * (Layout.HALF_LENGTH + 0.4), PLATFORM_BOTTOM - 1.2, 0)
		)
	end
end

-- 발판 위 "추" 장식(간장통·초밥 접시 더미). 발판 Model 하위라 기울면 같이 미끄러질 듯 보여요(실제 물리는 충돌 없음).
local function addWeights(list: { DecorSpec })
	-- 접시 테두리(x ±17~±35) 바깥에 두지 않게 가운데 쪽(±12 이내)에만 둬요
	local positions = { -12, -4, 4, 12 }
	for i, x in positions do
		if i % 2 == 1 then
			part(
				list,
				"SoyBottle",
				"Cylinder",
				v(2.4, 1.4, 1.4),
				PALETTE.Soy,
				"Glass",
				v(x, PLATFORM_TOP + 1.2, 3),
				UPRIGHT
			)
			part(
				list,
				"SoyCap",
				"Cylinder",
				v(0.4, 0.6, 0.6),
				PALETTE.Nori,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 2.6, 3),
				UPRIGHT
			)
		else
			part(
				list,
				"PlateStack",
				"Cylinder",
				v(0.4, 6, 6),
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 0.4, -3),
				UPRIGHT
			)
			part(
				list,
				"PlateStack",
				"Cylinder",
				v(0.4, 6, 6),
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 0.9, -3),
				UPRIGHT
			)
			part(
				list,
				"PlateSushi",
				"Block",
				v(2, 0.8, 1.2),
				PALETTE.Salmon,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 1.5, -3)
			)
		end
	end
end

-- 기울어지는 장식 전부. anim은 하나도 없어요 (m5-24 스펙 "절대 규칙").
function TugOfWarPlatformArt.deckDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPanRims(list)
	addDeckTrim(list)
	addRopes(list)
	addWeights(list)
	return list
end

---------------------------------------------------------------------------------- 고정 장식

-- ① 받침대: 마당에서 솟은 돌절구 + 나무통 + 놋쇠 띠 + 축 덮개 (기울지 않아요)
local function addPedestal(list: { DecorSpec })
	part(
		list,
		"PedestalCap",
		"Cylinder",
		v(1.2, 12, 12),
		PALETTE.Porcelain,
		"SmoothPlastic",
		v(0, PLATFORM_BOTTOM - 0.6, 0),
		UPRIGHT
	)
	-- 나무통 (축 아래 -3.2 ~ -20)
	local barrelTop, barrelBottom = PLATFORM_BOTTOM - 1.2, -20
	disc(list, "PedestalBarrel", barrelTop - barrelBottom, 10, DARK_WOOD, "Wood", 0, barrelBottom, 0)
	for _, by in { -5, -12, -18 } do
		disc(list, "PedestalBand", 0.8, 10.4, GOLD, "Metal", 0, by, 0).reflectance = 0.3
	end
	-- 돌절구 (마당 바닥 ~ -20): 아래가 넓은 몸통 + 테두리 + 받침
	disc(list, "MortarFoot", 3, 30, shade(STONE, 0.8), "Granite", 0, YARD_Y, 0)
	disc(list, "MortarBody", 14, 24, STONE, "Granite", 0, YARD_Y + 3, 0)
	disc(list, "MortarWaist", 3, 20, shade(STONE, 0.9), "Granite", 0, YARD_Y + 17, 0)
	append(
		list,
		MapKitShapes.rimDisc(
			"MortarTop",
			26,
			3,
			shade(STONE, 1.1),
			"Granite",
			v(0, -20 - 1.5, 0),
			{ rimColor = shade(STONE, 0.75), rimWidth = 2, rimHeight = 1.2, segments = 16 }
		)
	)
end

-- 마당 바닥 + 판석 길 + 흙 자국 (BG)
local function addYard(list: { DecorSpec })
	local ground = part(list, "YardGround", "Block", v(900, 4, 900), YARD, "Cobblestone", v(0, YARD_Y - 2, -60))
	ground.castShadow = false
	-- 받침대 둘레 판석 원 (3 shade)
	for k = 0, 11 do
		local a = math.rad(k * 30 + 15)
		local r = 26
		part(
			list,
			"Flagstone",
			"Block",
			v(12, 0.6, 9),
			shade(STONE, 0.9 + (k % 3) * 0.1),
			"Slate",
			v(math.cos(a) * r, YARD_Y + 0.3, math.sin(a) * r),
			v(0, -k * 30 - 15, 0)
		).castShadow =
			false
	end
	-- 뒷문까지 판석 길
	for k = 0, 6 do
		part(
			list,
			"Flagstone",
			"Block",
			v(16, 0.6, 10),
			shade(STONE, 0.95 + (k % 2) * 0.1),
			"Slate",
			v((k % 2) * 3 - 1.5, YARD_Y + 0.3, -44 - k * 14),
			v(0, (k % 3 - 1) * 6, 0)
		).castShadow =
			false
	end
	-- 흙 자국 (색 판 몇 장 — 큰 면이 한 색이 아니게)
	local patches = { { 80, -10, 40 }, { -90, 10, 44 }, { 50, -100, 36 } }
	for _, p in patches do
		disc(list, "DirtPatch", 0.2, p[3], c(140, 128, 112), "Sand", p[1], YARD_Y, p[2]).castShadow = false
	end
	-- 마당 먼지 (해 질 녘 빛에 떠다님)
	local dust = part(list, "YardDust", "Block", v(80, 20, 40), YARD, "SmoothPlastic", v(0, YARD_Y + 14, 40))
	dust.transparency = 1
	dust.castShadow = false
	dust.particle = "Dust"
	dust.particleRate = 5
end

-- ⑤ 가게 뒷벽·뒷문·기와 처마 (-Z) + 풍경
local function addShopBack(list: { DecorSpec })
	local z = -150
	local h = 110
	local w = 360
	part(list, "ShopWall", "Block", v(w, h, 8), PLASTER, "Plaster", v(0, YARD_Y + h / 2, z)).castShadow = false
	-- 아래 돌 기단 + 나무 기둥·인방 (반목조 벽)
	part(list, "ShopPlinth", "Block", v(w + 4, 12, 12), shade(STONE, 0.85), "Cobblestone", v(0, YARD_Y + 6, z + 1))
	for k = -4, 4 do
		part(list, "ShopPost", "Block", v(5, h, 3), DARK_WOOD, "Wood", v(k * 42, YARD_Y + h / 2, z + 5))
	end
	for _, y in { 40, 80 } do
		part(list, "ShopBeam", "Block", v(w, 4, 3), DARK_WOOD, "Wood", v(0, YARD_Y + y, z + 5))
	end
	-- 기와 처마 (경사 쐐기 + 기와 줄)
	local eaveY = YARD_Y + h
	part(list, "ShopRoof", "Wedge", v(w + 30, 26, 40), ROOF, "ClayRoofTiles", v(0, eaveY + 13, z + 14), v(0, 180, 0))
	for k = 0, 16 do
		disc(list, "RoofTileEnd", 1.4, 5, shade(ROOF, 0.8), "Slate", -176 + k * 22, eaveY - 1.5, z + 34).rotation =
			v(90, 0, 0)
	end
	part(list, "ShopFascia", "Block", v(w + 30, 3, 3), DARK_WOOD, "Wood", v(0, eaveY + 0.5, z + 33))
	-- 뒷문 (짙은 나무 문틀 + 노렌 3장 + 문 안 따뜻한 빛)
	local dz = z + 5
	part(list, "BackDoorGlow", "Block", v(40, 54, 1), c(255, 196, 130), "Neon", v(0, YARD_Y + 27 + 6, z + 4.4))
	for _, s in { -1, 1 } do
		part(list, "BackDoorPost", "Block", v(5, 62, 5), DARK_WOOD, "Wood", v(s * 22, YARD_Y + 31 + 6, dz))
	end
	part(list, "BackDoorLintel", "Block", v(52, 6, 6), DARK_WOOD, "Wood", v(0, YARD_Y + 65, dz))
	for k = -1, 1 do
		local noren =
			part(list, "BackNoren", "Block", v(12.6, 22, 0.4), PALETTE.Noren, "Fabric", v(k * 13, YARD_Y + 51, dz + 2))
		noren.anim = { kind = "Sway", period = 4.5 + k * 0.4, amount = 4, axis = "X" }
	end
	part(list, "BackNorenMark", "Ball", v(6, 6, 0.6), PALETTE.Rice, "SmoothPlastic", v(0, YARD_Y + 52, dz + 2.4))
	-- 문 옆 등 (빛은 build의 PointLight — 이름 Lantern)
	for _, s in { -1, 1 } do
		local lx = s * 32
		part(list, "LanternBracket", "Block", v(1, 1, 8), DARK_WOOD, "Wood", v(lx, YARD_Y + 66, dz + 4))
		part(
			list,
			"LanternCord",
			"Cylinder",
			v(4, 0.3, 0.3),
			PALETTE.Nori,
			"SmoothPlastic",
			v(lx, YARD_Y + 64, dz + 8),
			UPRIGHT
		)
		local lantern = part(
			list,
			TugOfWarPlatformArt.LANTERN,
			"Ball",
			v(7, 9, 7),
			LANTERN_GLOW,
			"Neon",
			v(lx, YARD_Y + 58, dz + 8)
		)
		lantern.anim = { kind = "Sway", period = 3.6 + s * 0.3, amount = 5, axis = "X" }
		lantern.particle = "Sparkle"
		lantern.particleRate = 1
		disc(list, "LanternCap", 1.2, 5, PALETTE.Nori, "SmoothPlastic", lx, YARD_Y + 62.2, dz + 8)
		disc(list, "LanternCap", 1.2, 5, PALETTE.Nori, "SmoothPlastic", lx, YARD_Y + 52.6, dz + 8)
	end
	-- 처마 풍경 (물고기 모양 추가 흔들려요)
	for _, s in { -1, 1 } do
		local wx = s * 110
		part(
			list,
			"WindChimeCord",
			"Cylinder",
			v(10, 0.2, 0.2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(wx, eaveY - 6, z + 30),
			UPRIGHT
		)
		local bell = part(list, "WindChime", "Ball", v(5, 6, 5), GOLD, "Metal", v(wx, eaveY - 12, z + 30))
		bell.reflectance = 0.3
		bell.anim = { kind = "Sway", period = 2.8 + s * 0.2, amount = 10, axis = "X" }
		local fish = part(list, "WindChimeFish", "Block", v(0.3, 5, 3), RIBBON, "Fabric", v(wx, eaveY - 18, z + 30))
		fish.anim = { kind = "Sway", period = 2.4, amount = 12, axis = "X" }
	end
	-- 벽에 건 대저울 간판 (나무 판 + 놋쇠 저울 실루엣)
	append(list, MapKitShapes.bevelBox("ScaleSign", v(60, 30, 3), MID_WOOD, "Wood", v(-110, YARD_Y + 60, z + 6), 1))
	part(list, "ScaleSignBeam", "Block", v(40, 2, 1), GOLD, "Metal", v(-110, YARD_Y + 66, z + 8))
	part(list, "ScaleSignPost", "Block", v(2, 16, 1), GOLD, "Metal", v(-110, YARD_Y + 58, z + 8))
	for _, s in { -1, 1 } do
		part(
			list,
			"ScaleSignPan",
			"Cylinder",
			v(1, 10, 10),
			GOLD,
			"Metal",
			v(-110 + s * 18, YARD_Y + 58, z + 8),
			v(0, 90, 0)
		)
	end
end

-- 나무 담장 (±X, +Z) — 판자 3 shade + 기둥 + 위 지붕 띠
local function addFences(list: { DecorSpec })
	local h = 46
	local shades = { MID_WOOD, shade(MID_WOOD, 0.85), shade(MID_WOOD, 1.1) }
	local function fence(cx: number, cz: number, length: number, alongX: boolean)
		local boards = math.floor(length / 30)
		for k = 0, boards - 1 do
			local t = -length / 2 + 15 + k * 30
			local x = if alongX then cx + t else cx
			local z = if alongX then cz else cz + t
			part(
				list,
				"FenceBoard",
				"Block",
				if alongX then v(29, h, 2) else v(2, h, 29),
				shades[1 + k % 3],
				"WoodPlanks",
				v(x, YARD_Y + h / 2, z)
			).castShadow =
				false
			part(
				list,
				"FencePost",
				"Block",
				v(4, h + 6, 4),
				DARK_WOOD,
				"Wood",
				v(if alongX then x - 15 else x, YARD_Y + (h + 6) / 2, if alongX then z else z - 15)
			)
		end
		part(
			list,
			"FenceCap",
			"Wedge",
			v(length, 4, 6), -- 회전 전 크기 (길이 = 로컬 X), ±X 담장은 Y 90°로 돌려 Z 방향으로
			ROOF,
			"ClayRoofTiles",
			v(cx, YARD_Y + h + 2, cz),
			if alongX then v(0, 0, 0) else v(0, 90, 0)
		)
	end
	fence(-180, -20, 260, false)
	fence(180, -20, 260, false)
	fence(0, 110, 360, true)
end

-- ④ 감나무 (+X 앞, 고정) — 굽은 줄기 + 가지 + 잎 덩어리 + 주황 감, 가지 끝·감 몇 개만 Sway
local function addPersimmonTree(list: { DecorSpec })
	local tx, tz = 110, 50
	-- 줄기 (굵은 캡슐 두 마디, 살짝 기움)
	append(list, MapKitShapes.capsule("TreeTrunk", 70, 12, c(96, 70, 52), "Wood", v(tx, YARD_Y + 32, tz), v(0, 0, 80)))
	append(
		list,
		MapKitShapes.capsule("TreeTrunk", 50, 9, c(90, 64, 48), "Wood", v(tx - 10, YARD_Y + 76, tz - 4), v(20, 0, 62))
	)
	-- 뿌리 둔덕
	part(list, "TreeRoot", "Ball", v(30, 10, 30), c(110, 90, 70), "Sand", v(tx, YARD_Y, tz))
	-- 가지 3개
	local branches = {
		{ x = -24, y = 92, z = 8, rz = 30, ry = 20 },
		{ x = 16, y = 86, z = -12, rz = -35, ry = -30 },
		{ x = -6, y = 104, z = 18, rz = 10, ry = 70 },
	}
	for _, b in branches do
		append(
			list,
			MapKitShapes.capsule(
				"TreeBranch",
				36,
				4,
				c(88, 62, 46),
				"Wood",
				v(tx + b.x, YARD_Y + b.y, tz + b.z),
				v(0, b.ry, b.rz)
			)
		)
	end
	-- 잎 덩어리 (큰 것 1 + 중간 여럿, 3 shade)
	local clumps = {
		{ 0, 112, 0, 46 },
		{ -34, 100, 12, 32 },
		{ 30, 96, -16, 30 },
		{ -12, 124, 22, 28 },
		{ 14, 120, -30, 24 },
	}
	for i, cl in clumps do
		part(
			list,
			"TreeLeaves",
			"Ball",
			v(cl[4], cl[4] * 0.7, cl[4]),
			shade(LEAF, 0.85 + (i % 3) * 0.12),
			"Grass",
			v(tx + cl[1], YARD_Y + cl[2], tz + cl[3])
		)
	end
	-- 감 (주황 공 + 꼭지), 무리 지어
	local fruits = {
		{ -30, 88, 22 },
		{ -40, 92, 4 },
		{ -22, 84, 6 },
		{ 30, 84, -4 },
		{ 38, 88, -24 },
		{ 4, 96, 24 },
		{ -10, 98, -20 },
		{ 18, 108, 8 },
	}
	for i, f in fruits do
		local fruit = part(
			list,
			"Persimmon",
			"Ball",
			v(6, 5.4, 6),
			shade(PERSIMMON, 0.9 + (i % 3) * 0.08),
			"SmoothPlastic",
			v(tx + f[1], YARD_Y + f[2], tz + f[3])
		)
		fruit.reflectance = 0.08
		if i % 3 == 0 then
			fruit.anim = { kind = "Sway", period = 3 + i * 0.3, amount = 6, axis = "X" }
		end
		part(
			list,
			"PersimmonCalyx",
			"Cylinder",
			v(0.6, 3, 3),
			c(70, 90, 40),
			"SmoothPlastic",
			v(tx + f[1], YARD_Y + f[2] + 2.8, tz + f[3]),
			UPRIGHT
		)
	end
	-- 떨어지는 단풍 (나무 아래)
	local fall = part(list, "TreeLeafFall", "Block", v(70, 4, 60), LEAF, "SmoothPlastic", v(tx, YARD_Y + 96, tz))
	fall.transparency = 1
	fall.castShadow = false
	fall.particle = "Petals"
	fall.particleRate = 3
	-- 바닥 낙엽·떨어진 감 무리
	append(
		list,
		MapKitShapes.scatter(
			18,
			16,
			{ center = v(tx - 10, YARD_Y + 0.3, tz + 4), size = v(70, 0, 60) },
			function(i, pos, r)
				local s: DecorSpec = {
					name = if i % 5 == 0 then "FallenPersimmon" else "FallenLeaf",
					shape = if i % 5 == 0 then "Ball" else "Block",
					size = if i % 5 == 0 then v(5, 4.5, 5) else v(4, 0.3, 2.4),
					color = if i % 5 == 0 then PERSIMMON else shade(LEAF, r:range(0.8, 1.15)),
					material = "SmoothPlastic",
					offset = if i % 5 == 0 then v(pos.x, YARD_Y + 2.2, pos.z) else pos,
					rotation = v(0, r:range(0, 180), 0),
				}
				return { s }
			end
		)
	)
end

-- 장독대 (-X 뒤, 돌 단 + 크기 다른 옹기 6개 + 뚜껑)
local function addJangdokdae(list: { DecorSpec })
	local jx, jz = -110, -60
	append(
		list,
		MapKitShapes.bevelBox("JangStand", v(80, 6, 50), shade(STONE, 0.95), "Cobblestone", v(jx, YARD_Y + 3, jz), 1.5)
	)
	local jars = {
		{ -24, -10, 26 },
		{ 0, -12, 30 },
		{ 24, -8, 24 },
		{ -14, 12, 20 },
		{ 10, 12, 18 },
		{ 28, 14, 14 },
	}
	for i, j in jars do
		local x, z, d = jx + j[1], jz + j[2], j[3]
		local col = shade(ONGGI, 0.9 + (i % 3) * 0.1)
		local base = YARD_Y + 6
		local body = part(list, "Onggi", "Ball", v(d, d * 1.05, d), col, "SmoothPlastic", v(x, base + d * 0.5, z))
		body.reflectance = 0.12
		disc(list, "OnggiFoot", 2, d * 0.6, shade(col, 0.8), "SmoothPlastic", x, base, z)
		disc(list, "OnggiNeck", d * 0.12, d * 0.55, shade(col, 0.85), "SmoothPlastic", x, base + d * 0.98, z)
		append(
			list,
			MapKitShapes.rimDisc(
				"OnggiLid",
				d * 0.64,
				1.5,
				shade(col, 0.75),
				"SmoothPlastic",
				v(x, base + d * 1.1 + 0.75, z),
				{ rimColor = shade(col, 0.6), rimWidth = 0.6, rimHeight = 0.6, segments = 10 }
			)
		)
	end
	-- 장독대 옆 금줄 (새끼줄 + 빨간 고추 매듭)
	part(list, "Geumjul", "Cylinder", v(70, 0.6, 0.6), ROPE, "Fabric", v(jx, YARD_Y + 22, jz + 28), v(0, 0, 4))
	for k = 0, 4 do
		part(
			list,
			"GeumjulPepper",
			"Ball",
			v(1.2, 3, 1.2),
			RIBBON,
			"SmoothPlastic",
			v(jx - 28 + k * 14, YARD_Y + 20, jz + 28)
		)
	end
end

-- 마당 소품 무리: 놋쇠 추 더미(받침대 옆), 나무 상자·쌀가마 (출발 시점이 보는 +Z 쪽)
local function addYardProps(list: { DecorSpec })
	-- 놋쇠 추 피라미드 (받침대 앞, 발판 회전 원 밖)
	local wx, wz = -44, 26
	local weights = { { 0, 0, 12 }, { 13, 2, 10 }, { 6, 12, 8 }, { -10, 8, 7 } }
	for i, w in weights do
		local h = w[3] * 0.7
		disc(list, "BrassWeight", h, w[3], shade(GOLD, 0.9 + (i % 2) * 0.12), "Metal", wx + w[1], YARD_Y, wz + w[2]).reflectance =
			0.35
		disc(list, "BrassWeightKnob", 2, w[3] * 0.3, GOLD_DARK, "Metal", wx + w[1], YARD_Y + h, wz + w[2])
	end
	-- 나무 상자 둘 + 쌀가마 (+X +Z)
	append(
		list,
		MapKitShapes.bevelBox("WoodCrate", v(22, 18, 22), MID_WOOD, "WoodPlanks", v(54, YARD_Y + 9, 54), 1, v(0, 12, 0))
	)
	append(
		list,
		MapKitShapes.bevelBox(
			"WoodCrate",
			v(16, 14, 16),
			shade(MID_WOOD, 0.85),
			"WoodPlanks",
			v(60, YARD_Y + 25, 52),
			1,
			v(0, -8, 0)
		)
	)
	for k = 0, 1 do
		local sack = part(
			list,
			"RiceSack",
			"Ball",
			v(24, 14, 16),
			c(214, 196, 150),
			"Fabric",
			v(28 + k * 6, YARD_Y + 7 + k * 10, 66 - k * 2),
			v(0, k * 25, 0)
		)
		sack.castShadow = true
		part(
			list,
			"RiceSackTie",
			"Cylinder",
			v(1.5, 6, 6),
			ROPE,
			"Fabric",
			v(28 + k * 6 + 12, YARD_Y + 7 + k * 10, 66 - k * 2),
			v(0, k * 25, 0)
		)
	end
	-- 물 항아리 + 바가지 (-X +Z)
	disc(list, "WaterJar", 20, 22, shade(ONGGI, 1.1), "SmoothPlastic", -70, YARD_Y, 50).reflectance = 0.1
	local water = disc(list, "WaterJarWater", 0.4, 19, c(90, 120, 140), "Glass", -70, YARD_Y + 18, 50)
	water.transparency = 0.2
	water.reflectance = 0.25
	part(list, "Gourd", "Ball", v(10, 4, 8), c(214, 186, 120), "SmoothPlastic", v(-66, YARD_Y + 19, 46), v(0, 20, 0))
end

-- ③ 발판 위 나무 가로대 + 작업등(그림자 SpotLight) — 기둥은 발판이 도는 원 밖(x ±45)
local function addGantry(list: { DecorSpec })
	local topY = 58
	for _, s in { -1, 1 } do
		local x = s * 46
		disc(list, "GantryFoot", 4, 10, shade(STONE, 0.85), "Granite", x, YARD_Y, 0)
		append(
			list,
			MapKitShapes.roundedBox(
				"GantryPost",
				v(5, topY - YARD_Y, 5),
				DARK_WOOD,
				"Wood",
				v(x, (topY + YARD_Y) / 2, 0),
				{ radius = 1, style = "vertical" }
			)
		)
	end
	append(list, MapKitShapes.bevelBox("GantryBeam", v(110, 5, 6), DARK_WOOD, "Wood", v(0, topY + 2.5, 0), 1))
	part(list, "GantryBrace", "Block", v(16, 3, 3), DARK_WOOD, "Wood", v(-40, topY - 6, 0), v(0, 0, 45))
	part(list, "GantryBrace", "Block", v(16, 3, 3), DARK_WOOD, "Wood", v(40, topY - 6, 0), v(0, 0, -45))
	-- 가로대 위 빨간 리본 매듭 (가운데)
	part(list, "GantryRibbon", "Block", v(6, 4, 6.4), RIBBON, "Fabric", v(0, topY + 2.5, 0))
	-- 작업등 (고정 — 흔들리지 않아요, 그림자 조명은 고정 파츠에만)
	local lampY = 48
	part(
		list,
		"LampCord",
		"Cylinder",
		v(topY - lampY - 2, 0.4, 0.4),
		PALETTE.Nori,
		"SmoothPlastic",
		v(0, (topY + lampY + 2) / 2, 0),
		UPRIGHT
	)
	append(
		list,
		MapKitShapes.rimDisc(
			"LampShade",
			12,
			2,
			c(70, 60, 50),
			"Metal",
			v(0, lampY + 2.5, 0),
			{ rimColor = GOLD_DARK, rimWidth = 1, rimHeight = 2.5, segments = 14 }
		)
	)
	local bulb = part(list, "LampBulb", "Ball", v(4.5, 4.5, 4.5), c(255, 228, 180), "Neon", v(0, lampY, 0))
	bulb.castShadow = false
	bulb.light = {
		kind = "Spot",
		color = c(255, 226, 180),
		brightness = 2.6,
		range = 60,
		angle = 80,
		face = "Bottom",
		shadows = true,
	}
end

-- 기울지 않는 장식 전부
function TugOfWarPlatformArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPedestal(list)
	addYard(list)
	addShopBack(list)
	addFences(list)
	addPersimmonTree(list)
	addJangdokdae(list)
	addYardProps(list)
	addGantry(list)
	return list
end

TugOfWarPlatformArt.SWEEP_RADIUS = SWEEP_RADIUS

-- 마당 전체 → 받침대 → 저울 접시(오른쪽 끝) → 출발 자리(왼쪽) 순서.
function TugOfWarPlatformArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-10, 30, 70), lookAt = v(4, -8, -20) },
		{ pos = v(0, 2, 30), lookAt = v(0, -16, 0) },
		{ pos = v(Layout.HALF_LENGTH - 2, 10, Layout.HALF_WIDTH + 6), lookAt = v(Layout.HALF_LENGTH - 9, 0, 0) },
		{ pos = v(-Layout.HALF_LENGTH + 10, 7, Layout.HALF_WIDTH + 4), lookAt = v(-Layout.HALF_LENGTH + 8, 0, 0) },
	}
end

return TugOfWarPlatformArt
