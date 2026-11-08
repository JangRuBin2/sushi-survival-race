--!strict
-- "팬트리 선반 대질주"(pantry-shelf-dash, m6-05) 장식 데이터. Roblox API 없음.
-- 아트 디렉션: "오후 햇살 드는 식료품 창고 — 작은 초밥이 거대한 선반 사이를 뛰어다녀요" (REFERENCE-map-art-direction 필수).
--   Art.decor() / courseVolume() / introCamera() / BUDGET / LIGHTING / JUDGE_COLORS / PANTRY_FLOOR_Y
-- 층: FG 선반 섬 앞 테두리·받침 기둥 / MG 양옆 큰 선반장(환풍기·유리병·쌀자루·간장병·통조림 탑·국수 묶음) /
--     BG 창문 햇살(먼지)·결승 아래 거대한 매실 유리병·팬트리 바닥.
-- 환풍기 날개는 Spin(클라이언트 장식). 바람이 켜졌는지는 서버 줄무늬(PantryWind)가 보여 줘요.

local Layout = require(script.Parent.PantryShelfDashLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local Art = {}

Art.BUDGET = "Large" :: MapKitLogic.BudgetTier
Art.PANTRY_FLOOR_Y = -70
Art.UNIT_X = 58 -- 양옆 선반장 안쪽 면 (x ±)
Art.BACK_Z = 30
Art.END_Z = -540

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 색 (60 소나무 선반·흰 벽 / 30 유리병·쌀자루 크림 / 10 매실 빨강·통조림 색 띠·간장) ───────────────
local PINE = MapKitLogic.shades(c(214, 172, 116))
local PINE_DARK = MapKitLogic.shades(c(150, 108, 66))
local WALL = MapKitLogic.shades(c(236, 228, 214))
local STEEL = MapKitLogic.shades(c(170, 176, 184))
local GLASS = c(206, 228, 236)
local UME = c(196, 50, 66)
local RICE_SACK = c(232, 218, 186)
local SOY = MapKitLogic.PALETTE.Soy
local NOODLE = c(244, 226, 170)
local CAN_BANDS = { c(206, 64, 56), c(60, 120, 180), c(240, 190, 60), c(80, 150, 90) }
local SUN = c(255, 226, 170)
local FLOOR = MapKitLogic.shades(c(150, 120, 92))
local GOLD_KNOB = c(214, 172, 78)

Art.JUDGE_COLORS = {
	start = c(244, 232, 206), -- 출발 선반 (크림 — 배경 소나무 선반장과 구분)
	shelf = c(248, 238, 214), -- 선반 섬 (밝은 크림 도마색)
	lid = c(214, 60, 52), -- 결승 병뚜껑 (빨강)
	wind = c(220, 240, 255), -- 바람 줄무늬
	canA = c(210, 70, 60),
	canB = c(70, 130, 190),
}

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

local function upright(
	list: { DecorSpec },
	name: string,
	height: number,
	diameter: number,
	color: RGB,
	material: string,
	pos: Vec3,
	extra: Extra?
)
	put(list, name, "Cylinder", v(height, diameter, diameter), color, material, pos, v(0, 0, 90), extra)
end

-- ── 선반 섬 받침 (기둥·앞 테두리) ──────────────────────────────────────
local function shelfSupports(list: { DecorSpec })
	for _, rect in Layout.floorRects() do
		local top = rect.top - Layout.FLOOR_THICKNESS
		local height = top - Art.PANTRY_FLOOR_Y
		for _, x in { rect.minX + 2, rect.maxX - 2 } do
			for _, z in { rect.maxZ - 2, rect.minZ + 2 } do
				put(
					list,
					"ShelfPost",
					"Block",
					v(2.4, height, 2.4),
					PINE_DARK.base,
					"Wood",
					v(x, Art.PANTRY_FLOOR_Y + height / 2, z)
				)
			end
		end
		-- 앞(+z)·뒤 테두리 띠 (밟는 면 바로 아래)
		for _, z in { rect.maxZ, rect.minZ } do
			put(
				list,
				"ShelfLip",
				"Block",
				v(rect.maxX - rect.minX, 1.2, 0.8),
				c(70, 160, 168), -- 청록 테두리: 밟는 섬의 가장자리가 잘 보이게
				"Wood",
				v((rect.minX + rect.maxX) / 2, rect.top - 1.4, z)
			)
		end
		-- 선반 밑 가로대
		put(
			list,
			"ShelfBrace",
			"Block",
			v(rect.maxX - rect.minX - 4, 1.6, 1.6),
			PINE_DARK.dark,
			"Wood",
			v((rect.minX + rect.maxX) / 2, top - 6, (rect.minZ + rect.maxZ) / 2)
		)
	end
end

-- ── 양옆 선반장 + 환풍기 ──────────────────────────────────────────────
local function sideUnits(list: { DecorSpec })
	local length = Art.BACK_Z - Art.END_Z
	local midZ = (Art.BACK_Z + Art.END_Z) / 2
	local height = 140
	for _, side in { -1, 1 } do
		local wallX = side * (Art.UNIT_X + 26)
		put(
			list,
			"PantryWall",
			"Block",
			v(4, height, length),
			WALL.base,
			"Plaster",
			v(wallX, Art.PANTRY_FLOOR_Y + height / 2, midZ)
		)
		-- 선반장 옆판(세로)·선반(가로) 격자
		for z = Art.BACK_Z, Art.END_Z, -60 do
			put(
				list,
				"UnitSide",
				"Block",
				v(24, height, 3),
				PINE.dark,
				"Wood",
				v(side * (Art.UNIT_X + 12), Art.PANTRY_FLOOR_Y + height / 2, z)
			)
		end
		for _, y in { -40, -14, 22, 44 } do
			put(
				list,
				"UnitShelf",
				"Block",
				v(24, 2, length),
				PINE.base,
				"WoodPlanks",
				v(side * (Art.UNIT_X + 12), y, midZ)
			)
		end
		-- 줄마다 환풍기 (선반장 앞면, 코스 높이)
		for _, row in Layout.ROWS do
			local z = (row.front + row.back) / 2
			local fx = side * (Art.UNIT_X + 1)
			put(
				list,
				"FanBox",
				"Block",
				v(4, 20, 22),
				STEEL.base,
				"Metal",
				v(fx + side * 1, 6, z),
				nil,
				{ reflectance = 0.15 }
			)
			put(list, "FanRim", "Cylinder", v(1.2, 18, 18), STEEL.dark, "Metal", v(fx - side * 1.4, 6, z)) -- 축 X: 코스 쪽을 봐요
			-- 날개 (원기둥 축을 x로 — 옆을 보며 돌아요)
			for k = 0, 2 do
				put(
					list,
					"FanBlade",
					"Block",
					v(0.6, 15, 3.4),
					STEEL.light,
					"Metal",
					v(fx - side * 2, 6, z),
					v(k * 60, 0, 0),
					{
						anim = { kind = "Spin", period = 0.8, axis = "X" },
					}
				)
			end
			put(list, "FanHub", "Ball", v(3, 3, 3), c(60, 64, 70), "Metal", v(fx - side * 2.4, 6, z))
			for k = -2, 2 do
				put(list, "FanGrill", "Block", v(0.4, 0.5, 17), STEEL.light, "Metal", v(fx - side * 3, 6 + k * 3.4, z))
			end
		end
		-- 위 선반 물건: 유리병·쌀자루·간장병·통조림 탑·국수 묶음
		local rng = MapKitShapes.rng(if side < 0 then 11 else 23)
		for z = Art.BACK_Z - 20, Art.END_Z + 20, -30 do
			local kind = math.floor(rng:range(0, 5))
			local x = side * (Art.UNIT_X + 12)
			local y = 23
			if kind == 0 then
				upright(list, "Jar", 16, 14, GLASS, "Glass", v(x, y + 8, z), { transparency = 0.45 })
				upright(list, "JarLid", 2, 14.6, c(214, 60, 52), "SmoothPlastic", v(x, y + 17, z))
				for k = 0, 3 do
					put(
						list,
						"JarUme",
						"Ball",
						v(4.4, 4.4, 4.4),
						UME,
						"SmoothPlastic",
						v(x + (k % 2) * 4 - 2, y + 3 + math.floor(k / 2) * 4, z + (k % 2) * 2 - 1)
					)
				end
			elseif kind == 1 then
				put(
					list,
					"RiceSack",
					"Block",
					v(14, 18, 14),
					RICE_SACK,
					"Fabric",
					v(x, y + 9, z),
					v(0, rng:range(-10, 10), 0)
				)
				put(list, "RiceSackTie", "Block", v(14.4, 2, 14.4), c(150, 60, 50), "Fabric", v(x, y + 15, z))
			elseif kind == 2 then
				for k = -1, 1 do
					upright(list, "SoyBottle", 16, 5, SOY, "Glass", v(x, y + 8, z + k * 6), { reflectance = 0.1 })
					upright(list, "SoyCap", 2, 3, c(220, 60, 50), "SmoothPlastic", v(x, y + 17, z + k * 6))
				end
			elseif kind == 3 then
				for k = 0, 2 do
					upright(
						list,
						"StackCan",
						7,
						8,
						STEEL.light,
						"Metal",
						v(x, y + 3.5 + k * 7.1, z),
						{ reflectance = 0.2 }
					)
					upright(
						list,
						"StackCanBand",
						3.4,
						8.2,
						CAN_BANDS[(k + math.floor(-z / 30)) % #CAN_BANDS + 1],
						"SmoothPlastic",
						v(x, y + 3.5 + k * 7.1, z)
					)
				end
			else
				for k = -1, 1 do
					put(
						list,
						"Noodles",
						"Block",
						v(4, 4, 18),
						NOODLE,
						"Fabric",
						v(x + k * 4.4, y + 2, z),
						v(0, k * 4, 0)
					)
				end
				put(list, "NoodleBand", "Block", v(13, 4.4, 2), c(80, 120, 190), "SmoothPlastic", v(x, y + 2, z))
			end
		end
	end
end

-- ── 창문 햇살·결승 아래 매실 유리병·바닥 ──────────────────────────────
local function backdrop(list: { DecorSpec })
	-- 왼쪽 위 창문 3개 (햇살·먼지)
	for k, z in { -60, -240, -420 } do
		local wx = -(Art.UNIT_X + 23.8)
		put(list, "Window", "Block", v(0.6, 30, 40), c(255, 246, 220), "Neon", v(wx, 70, z), nil, {
			light = if k <= 3
				then { kind = "Surface", color = SUN, brightness = 1.4, range = 16, face = "Right" }
				else nil,
		})
		put(list, "WindowFrame", "Block", v(1.2, 2, 42), PINE_DARK.dark, "Wood", v(wx + 0.6, 70, z))
		put(list, "WindowFrame", "Block", v(1.2, 32, 2), PINE_DARK.dark, "Wood", v(wx + 0.6, 70, z))
		put(list, "SunBeam", "Block", v(80, 10, 30), SUN, "SmoothPlastic", v(wx + 40, 50, z), v(0, 0, -28), {
			transparency = 0.9,
			castShadow = false,
			particle = "Dust",
			particleRate = 4,
		})
	end
	-- 결승 병뚜껑 아래 거대한 유리병 (매실이 가득)
	local jarZ = (Layout.FINISH.front + Layout.FINISH.back) / 2
	local jarTop = Layout.FLOOR_Y - Layout.FLOOR_THICKNESS - 6
	local jarH = jarTop - Art.PANTRY_FLOOR_Y
	upright(
		list,
		"GiantJar",
		jarH,
		84,
		GLASS,
		"Glass",
		v(0, Art.PANTRY_FLOOR_Y + jarH / 2, jarZ),
		{ transparency = 0.55 }
	)
	upright(list, "GiantJarNeck", 6, 76, GLASS, "Glass", v(0, jarTop + 3, jarZ), { transparency = 0.4 })
	local rng = MapKitShapes.rng(5)
	for k = 1, 30 do
		local a = rng:range(0, 2 * math.pi)
		local r = rng:range(0, 32)
		put(
			list,
			"GiantUme",
			"Ball",
			v(14, 13, 14),
			if k % 3 == 0 then c(170, 40, 56) else UME,
			"SmoothPlastic",
			v(math.cos(a) * r, Art.PANTRY_FLOOR_Y + 7 + (k % 6) * 11, jarZ + math.sin(a) * r)
		)
	end
	-- 병뚜껑 옆면 홈 (판정 뚜껑 아래 띠)
	for k = 0, 23 do
		local a = k * math.pi / 12
		put(
			list,
			"LidRidge",
			"Block",
			v(3, 3, 1.2),
			c(190, 46, 40),
			"SmoothPlastic",
			v(math.cos(a) * 45, Layout.FLOOR_Y - 3.6, jarZ + math.sin(a) * 41),
			v(0, -math.deg(a) + 90, 0)
		)
	end
	-- 앞뒤 끝 벽 (출발 뒤·결승 너머) + 결승 너머 팬트리 문
	for _, z in { Art.BACK_Z, Art.END_Z } do
		put(list, "EndWall", "Block", v(2 * Art.UNIT_X + 52, 140, 4), WALL.light, "Plaster", v(0, 0, z))
		put(
			list,
			"Baseboard",
			"Block",
			v(2 * Art.UNIT_X + 52, 6, 4.6),
			PINE_DARK.base,
			"Wood",
			v(0, Art.PANTRY_FLOOR_Y + 3, z)
		)
	end
	put(list, "PantryDoor", "Block", v(44, 70, 1.2), PINE.base, "Wood", v(0, 30, Art.END_Z + 2.6))
	for _, x in { -23, 23 } do
		put(list, "DoorFrame", "Block", v(3, 74, 2), PINE_DARK.dark, "Wood", v(x, 31, Art.END_Z + 3))
	end
	put(list, "DoorFrame", "Block", v(49, 3, 2), PINE_DARK.dark, "Wood", v(0, 66.5, Art.END_Z + 3))
	put(list, "DoorKnob", "Ball", v(3, 3, 3), GOLD_KNOB, "Metal", v(16, 28, Art.END_Z + 4), nil, { reflectance = 0.3 })
	for k = 0, 2 do
		put(list, "DoorPanel", "Block", v(34, 16, 0.6), PINE.light, "Wood", v(0, 50 - k * 20, Art.END_Z + 3.4))
	end
	-- 출발 뒤 벽 달력·걸이
	put(list, "Calendar", "Block", v(30, 36, 0.6), c(250, 248, 240), "SmoothPlastic", v(-40, 40, Art.BACK_Z - 2.4))
	put(list, "CalendarTop", "Block", v(30, 8, 0.8), c(206, 64, 56), "SmoothPlastic", v(-40, 60, Art.BACK_Z - 2.5))
	for k = 0, 3 do
		put(
			list,
			"Apron",
			"Block",
			v(14, 26, 0.6),
			if k % 2 == 0 then c(80, 120, 190) else c(240, 190, 60),
			"Fabric",
			v(30 + k * 16, 38, Art.BACK_Z - 2.4),
			nil,
			{
				anim = { kind = "Sway", period = 3 + k * 0.5, amount = 4, axis = "Z" },
			}
		)
	end

	-- 팬트리 바닥 타일
	local tile = 48
	for z = Art.BACK_Z + 10, Art.END_Z - 20, -tile do
		for x = -72, 72, tile do
			put(
				list,
				"PantryFloor",
				"Block",
				v(tile - 0.5, 1, tile - 0.5),
				if (math.floor(z / tile) + math.floor(x / tile)) % 2 == 0 then FLOOR.base else FLOOR.dark,
				"WoodPlanks",
				v(x, Art.PANTRY_FLOOR_Y - 0.5, z - tile / 2)
			)
		end
	end
	-- 결승 깃발 두 개 + 꽃가루, 위에서 비추는 등
	for _, x in { -Layout.FINISH_WIDTH / 2 - 3, Layout.FINISH_WIDTH / 2 + 3 } do
		put(
			list,
			"FinishFlagPole",
			"Block",
			v(1.4, 20, 1.4),
			STEEL.dark,
			"Metal",
			v(x, Layout.FLOOR_Y + 8, Layout.FINISH_LINE_Z)
		)
		put(
			list,
			"FinishFlag",
			"Block",
			v(0.4, 7, 10),
			c(240, 190, 60),
			"Fabric",
			v(x, Layout.FLOOR_Y + 14, Layout.FINISH_LINE_Z - 5),
			nil,
			{
				particle = "Confetti",
				particleRate = 6,
				anim = { kind = "Sway", period = 2, amount = 8, axis = "Y" },
			}
		)
	end
	put(list, "CeilingLamp", "Ball", v(10, 6, 10), c(255, 236, 200), "SmoothPlastic", v(0, 60, -240), nil, {
		light = {
			kind = "Spot",
			color = c(255, 236, 200),
			brightness = 1.6,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
	for _, z in { -60, -420 } do
		put(list, "CeilingLamp", "Ball", v(10, 6, 10), c(255, 236, 200), "SmoothPlastic", v(0, 60, z), nil, {
			light = { kind = "Point", color = c(255, 232, 196), brightness = 1, range = 60 },
		})
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	shelfSupports(list)
	sideUnits(list)
	backdrop(list)
	return list
end

Art.LIGHTING = {
	ClockTime = 15.5,
	Brightness = 1.6,
	Ambient = c(150, 140, 126),
	OutdoorAmbient = c(170, 158, 140),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.5,
	ShadowSoftness = 0.35,
	Atmosphere = {
		Density = 0.18,
		Offset = 0.08,
		Color = c(236, 214, 176),
		Decay = c(170, 140, 100),
		Glare = 0.2,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.08,
		TintColor = c(255, 246, 232),
	},
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.1 },
} :: MapLighting.MapLighting

-- 코스 전체 (선반 사이 틈 위를 뛰어 건너는 공간까지)
function Art.courseVolume(): { Bounds }
	return {
		{
			min = v(-Layout.SHELF_HALF, Layout.FLOOR_Y + 2, Layout.FINISH.back),
			max = v(Layout.SHELF_HALF, Layout.FLOOR_Y + 12, Layout.START.front),
		},
	}
end

-- 소개: ① 창문 쪽 위에서 전체 → ② 첫 선반 섬 → ③ 환풍기 옆 → ④ 통조림 줄과 병뚜껑 → ⑤ 출발 자리
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-30, 64, 22), lookAt = v(0, 0, -220) },
		{ pos = v(14, 18, -30), lookAt = v(0, 0, -100) },
		{ pos = v(40, 24, -170), lookAt = v(-10, 4, -230) },
		{ pos = v(-24, 30, -300), lookAt = v(0, 0, -470) },
		{ pos = v(0, 14, 24), lookAt = v(0, 3, -40) },
	}
end

return Art
