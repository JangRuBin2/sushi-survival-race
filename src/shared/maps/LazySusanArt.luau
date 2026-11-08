--!strict
-- "중식당 회전 원판"(lazy-susan, m6-06) 장식 데이터. Roblox API 없음.
-- 아트 디렉션: "붉은 등이 걸린 저녁 중식당 — 거대한 원탁 위 회전판에서 버텨요" (REFERENCE-map-art-direction 필수).
--   Art.decor() / courseVolume() / introCamera() / ringColor(ring, k) / BUDGET / LIGHTING / JUDGE_COLORS / TABLE_Y
-- 층: FG 고리 사이 금테·가운데 장식 뚜껑 / MG 원탁 위 큰 요리(딤섬 찜기·마파두부·볶음밥·춘권·찻주전자) /
--     BG 붉은 기둥·격자창·둥근 문·천장 붉은 등(빛)·바닥.
-- 고리 판정 조각 색은 ringColor(고리마다 두 가지 색 번갈아 — 도는 느낌), 곧 열릴 조각은 JUDGE_COLORS.warn(빨강).

local Layout = require(script.Parent.LazySusanLayout)
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
Art.TABLE_Y = -30 -- 원탁 윗면 (낙하선 -12보다 18 아래)
Art.TABLE_RADIUS = 120
Art.FLOOR_Y = -96
Art.ROOM_RADIUS = 230

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 색 (60 붉은 식탁보·짙은 나무 / 30 옥색·크림 도자기 / 10 금색·등불·음식) ─────────────────────
local CLOTH = MapKitLogic.shades(c(176, 36, 40))
local DARK_WOOD = MapKitLogic.shades(c(90, 46, 32))
local GOLD = c(222, 178, 82)
local JADE = MapKitLogic.shades(c(120, 186, 156))
local CREAM = MapKitLogic.shades(c(244, 232, 206))
local BAMBOO = MapKitLogic.shades(c(214, 176, 112))
local PORCELAIN = MapKitLogic.PALETTE.Porcelain
local BLUE = MapKitLogic.PALETTE.PorcelainRim
local LANTERN = c(230, 50, 44)
local LANTERN_LIGHT = c(255, 150, 110)
local WALL = MapKitLogic.shades(c(236, 222, 192))
local FLOOR = MapKitLogic.shades(c(110, 70, 50))

Art.JUDGE_COLORS = {
	center = c(214, 236, 240), -- 가운데 유리판
	warn = c(236, 56, 52), -- 곧 열릴 조각
	bowl = c(246, 240, 228), -- 반찬 그릇 (흰 도자기)
}

-- 고리 조각 색: 고리 1·3 크림, 2·4 옥색. 3조각마다 밝기를 번갈아 (돌아가는 게 보이게).
-- 어두운 색은 쓰지 않아요 — 어두운 조각은 열린 구멍처럼 보여요(렌더 비평 2회차).
function Art.ringColor(ring: number, k: number): RGB
	local base = if ring % 2 == 1 then CREAM else JADE
	return if math.floor((k - 1) / 3) % 2 == 0 then base.light else base.base
end

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

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
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

-- ── 회전판 테두리·받침 ────────────────────────────────────────────────
local function turntable(list: { DecorSpec })
	-- 고리 바깥 금테 (밟는 면 아래 0.6 ~ -2.6)
	for _, ring in Layout.RINGS do
		append(
			list,
			MapKitShapes.ring("RingTrim", ring.outer + 0.4, 0.8, 1.6, 36, GOLD, "Metal", v(0, Layout.FLOOR_Y - 1.6, 0))
		)
	end
	append(
		list,
		MapKitShapes.ring(
			"CenterTrim",
			Layout.CENTER_RADIUS + 0.3,
			0.6,
			1.2,
			24,
			GOLD,
			"Metal",
			v(0, Layout.FLOOR_Y - 1.4, 0)
		)
	)
	-- 가운데 받침 기둥 (유리판 밑 → 원탁)
	upright(
		list,
		"Spindle",
		Layout.FLOOR_Y - 2 - Art.TABLE_Y,
		10,
		DARK_WOOD.dark,
		"Wood",
		v(0, (Layout.FLOOR_Y - 2 + Art.TABLE_Y) / 2, 0)
	)
	upright(list, "SpindleCap", 1, 14, GOLD, "Metal", v(0, Layout.FLOOR_Y - 2.6, 0), { reflectance = 0.3 })
	-- 고리 밑 받침살 (8방향, 각 고리 아래 2.5)
	for k = 0, 7 do
		local a = k * 45
		local r = Layout.OUTER_RADIUS / 2 + 4
		put(
			list,
			"Spoke",
			"Block",
			v(Layout.OUTER_RADIUS - 8, 1.6, 2),
			DARK_WOOD.base,
			"Wood",
			v(math.cos(math.rad(a)) * r, Layout.FLOOR_Y - 4, math.sin(math.rad(a)) * r),
			v(0, -a, 0)
		)
	end
	-- 가운데 장식 뚜껑 위 문양 (유리판 아래 비치게)
	for k = 0, 7 do
		local a = math.rad(k * 45)
		put(
			list,
			"CenterPetal",
			"Ball",
			v(4, 0.4, 2),
			GOLD,
			"Metal",
			v(math.cos(a) * 5, Layout.FLOOR_Y - 2.4, math.sin(a) * 5),
			v(0, -k * 45, 0)
		)
	end
end

-- ── 원탁과 큰 요리 ────────────────────────────────────────────────────
local function tableAndDishes(list: { DecorSpec })
	upright(list, "TableTop", 4, Art.TABLE_RADIUS * 2, CLOTH.base, "Fabric", v(0, Art.TABLE_Y - 2, 0))
	-- 식탁보 드리운 자락 (가장자리 띠 24조각)
	append(
		list,
		MapKitShapes.ring(
			"TableSkirt",
			Art.TABLE_RADIUS + 0.6,
			1.2,
			30,
			24,
			CLOTH.dark,
			"Fabric",
			v(0, Art.TABLE_Y - 15, 0)
		)
	)
	append(
		list,
		MapKitShapes.ring("TableTassel", Art.TABLE_RADIUS + 1.2, 0.6, 2, 24, GOLD, "Fabric", v(0, Art.TABLE_Y - 30, 0))
	)
	-- 요리 6가지 (회전판 바깥 반지름 92쯤, 원탁 위)
	local dishes = { "Dimsum", "Mapo", "Rice", "Rolls", "Tea", "Dimsum" }
	for i, kind in dishes do
		local a = math.rad(i * 60 + 15)
		local x, z = math.cos(a) * 94, math.sin(a) * 94
		local y = Art.TABLE_Y
		if kind == "Dimsum" then
			for level = 0, 1 do
				upright(list, "Steamer", 10, 30, BAMBOO.base, "Wood", v(x, y + 5 + level * 10.4, z))
				upright(list, "SteamerBand", 1.4, 30.6, BAMBOO.dark, "Wood", v(x, y + 9 + level * 10.4, z))
			end
			upright(
				list,
				"SteamerLid",
				3,
				31,
				BAMBOO.light,
				"Wood",
				v(x, y + 22, z),
				{ particle = "Steam", particleRate = 5 }
			)
		elseif kind == "Mapo" then
			upright(list, "MapoBowl", 12, 30, PORCELAIN, "SmoothPlastic", v(x, y + 6, z))
			upright(list, "MapoBowlRim", 1.4, 30.6, BLUE, "SmoothPlastic", v(x, y + 11.4, z))
			upright(list, "MapoSauce", 1, 27, c(190, 60, 30), "SmoothPlastic", v(x, y + 11, z))
			for k = 0, 5 do
				put(
					list,
					"Tofu",
					"Block",
					v(4, 3, 4),
					c(250, 240, 220),
					"SmoothPlastic",
					v(x - 6 + (k % 3) * 6, y + 12, z - 3 + math.floor(k / 3) * 6),
					v(0, k * 17, 0)
				)
			end
		elseif kind == "Rice" then
			upright(list, "RicePlate", 2, 34, PORCELAIN, "SmoothPlastic", v(x, y + 1, z))
			put(list, "FriedRice", "Ball", v(26, 14, 26), c(232, 196, 110), "Sand", v(x, y + 6, z))
			for k = 0, 4 do
				put(
					list,
					"Pea",
					"Ball",
					v(2, 2, 2),
					c(110, 180, 70),
					"SmoothPlastic",
					v(x - 6 + k * 3, y + 12.4, z + (k % 2) * 3 - 1.5)
				)
			end
		elseif kind == "Rolls" then
			upright(list, "RollPlate", 2, 32, PORCELAIN, "SmoothPlastic", v(x, y + 1, z))
			for k = 0, 3 do
				put(
					list,
					"SpringRoll",
					"Cylinder",
					v(18, 5, 5),
					c(214, 150, 70),
					"Sand",
					v(x, y + 4.5 + (k % 2) * 4, z - 7 + k * 4.6),
					v(0, 20 + k * 5, 0)
				)
			end
		else
			put(
				list,
				"Teapot",
				"Ball",
				v(22, 18, 22),
				JADE.base,
				"SmoothPlastic",
				v(x, y + 9, z),
				nil,
				{ reflectance = 0.1 }
			)
			put(list, "TeapotLid", "Ball", v(10, 4, 10), JADE.dark, "SmoothPlastic", v(x, y + 18, z))
			put(
				list,
				"TeapotSpout",
				"Cylinder",
				v(12, 3.4, 3.4),
				JADE.base,
				"SmoothPlastic",
				v(x + 12, y + 11, z),
				v(0, 0, 35)
			)
			for k = -1, 1, 2 do
				upright(list, "TeaCup", 6, 7, PORCELAIN, "SmoothPlastic", v(x + k * 12, y + 3, z + 14))
			end
		end
	end
	-- 큰 젓가락 받침 위 젓가락 두 쌍
	for _, a in { 100, 280 } do
		local r = 108
		local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
		for k = -1, 1, 2 do
			put(
				list,
				"TableChopstick",
				"Block",
				v(1.6, 1.6, 44),
				c(170, 40, 40),
				"SmoothPlastic",
				v(x + k * 2, Art.TABLE_Y + 1.4, z),
				v(0, -a, 0)
			)
		end
	end
end

-- ── 방: 붉은 기둥·격자창·둥근 문·천장 등·바닥 ──────────────────────────
local function room(list: { DecorSpec })
	-- 바닥 (짙은 나무 판)
	local tile = 60
	for x = -240, 240, tile do
		for z = -240, 240, tile do
			if x * x + z * z <= (Art.ROOM_RADIUS + 30) ^ 2 then
				put(
					list,
					"Floor",
					"Block",
					v(tile - 0.5, 1, tile - 0.5),
					if (math.floor(x / tile) + math.floor(z / tile)) % 2 == 0 then FLOOR.base else FLOOR.dark,
					"WoodPlanks",
					v(x, Art.FLOOR_Y - 0.5, z)
				)
			end
		end
	end
	-- 원탁 다리
	upright(
		list,
		"TableLeg",
		Art.TABLE_Y - 4 - Art.FLOOR_Y,
		30,
		DARK_WOOD.dark,
		"Wood",
		v(0, (Art.TABLE_Y - 4 + Art.FLOOR_Y) / 2, 0)
	)
	-- 벽 12면 + 붉은 기둥 + 격자창 / 한 면은 둥근 문
	local height = 200
	for k = 0, 11 do
		local a = math.rad(k * 30 + 15)
		local x, z = math.cos(a) * Art.ROOM_RADIUS, math.sin(a) * Art.ROOM_RADIUS
		local yaw = -(k * 30 + 15) + 90
		put(
			list,
			"Wall",
			"Block",
			v(124, height, 4),
			WALL.base,
			"Plaster",
			v(x, Art.FLOOR_Y + height / 2, z),
			v(0, yaw, 0)
		)
		local pa = math.rad(k * 30)
		upright(
			list,
			"Pillar",
			height,
			12,
			CLOTH.base,
			"SmoothPlastic",
			v(math.cos(pa) * (Art.ROOM_RADIUS - 6), Art.FLOOR_Y + height / 2, math.sin(pa) * (Art.ROOM_RADIUS - 6)),
			{ reflectance = 0.08 }
		)
		upright(
			list,
			"PillarBand",
			4,
			13,
			GOLD,
			"Metal",
			v(math.cos(pa) * (Art.ROOM_RADIUS - 6), 30, math.sin(pa) * (Art.ROOM_RADIUS - 6))
		)
		local inner = Art.ROOM_RADIUS - 2.4
		local wx, wz = math.cos(a) * inner, math.sin(a) * inner
		if k == 3 then
			-- 둥근 문 (달문)
			append(
				list,
				MapKitShapes.ring("MoonDoor", 30, 3, 3, 24, DARK_WOOD.dark, "Wood", v(wx, 6, wz), v(90, yaw, 0))
			)
			put(
				list,
				"MoonDoorGlow",
				"Cylinder",
				v(0.6, 56, 56),
				c(236, 190, 140),
				"SmoothPlastic",
				v(wx, 6, wz),
				v(0, yaw + 90, 0),
				{
					light = { kind = "Surface", color = c(255, 200, 150), brightness = 0.7, range = 16, face = "Right" },
				}
			)
		else
			put(
				list,
				"LatticeWindow",
				"Block",
				v(60, 46, 0.6),
				c(250, 228, 190),
				"SmoothPlastic",
				v(wx, 14, wz),
				v(0, yaw, 0)
			)
			for m = -2, 2 do
				put(
					list,
					"LatticeV",
					"Block",
					v(1.2, 46, 0.8),
					DARK_WOOD.dark,
					"Wood",
					v(wx + math.cos(a + math.pi / 2) * m * 12, 14, wz + math.sin(a + math.pi / 2) * m * 12),
					v(0, yaw, 0)
				)
			end
			for m = -1, 1 do
				put(
					list,
					"LatticeH",
					"Block",
					v(60, 1.2, 0.8),
					DARK_WOOD.dark,
					"Wood",
					v(wx, 14 + m * 14, wz),
					v(0, yaw, 0)
				)
			end
		end
	end
	-- 벽 가로 나무띠 (눈높이 아래·창 위) + 천장 들보·판
	for _, y in { -6, 42, 100 } do
		append(
			list,
			MapKitShapes.ring("WallRail", Art.ROOM_RADIUS - 2.6, 1.6, 3, 24, DARK_WOOD.dark, "Wood", v(0, y, 0))
		)
	end
	upright(
		list,
		"Ceiling",
		2,
		Art.ROOM_RADIUS * 2 + 20,
		DARK_WOOD.base,
		"WoodPlanks",
		v(0, Art.FLOOR_Y + height + 1, 0)
	)
	for k = 0, 5 do
		put(
			list,
			"CeilingBeam",
			"Block",
			v(Art.ROOM_RADIUS * 2, 5, 6),
			DARK_WOOD.dark,
			"Wood",
			v(0, Art.FLOOR_Y + height - 2.5, 0),
			v(0, k * 30, 0)
		)
	end
	append(list, MapKitShapes.ring("CeilingMedallion", 30, 4, 3, 24, GOLD, "Metal", v(0, Art.FLOOR_Y + height - 2, 0)))

	-- 천장 붉은 등 (원 두 겹)
	local lit = 0
	for _, ringSpec in { { r = 40, n = 6, y = 64 }, { r = 110, n = 10, y = 72 } } do
		for k = 0, ringSpec.n - 1 do
			local a = math.rad(k * 360 / ringSpec.n)
			local x, z = math.cos(a) * ringSpec.r, math.sin(a) * ringSpec.r
			local useLight = lit < 12 and k % 2 == 0
			put(list, "RedLantern", "Ball", v(12, 14, 12), LANTERN, "SmoothPlastic", v(x, ringSpec.y, z), nil, {
				light = if useLight
					then { kind = "Point", color = LANTERN_LIGHT, brightness = 1.6, range = 50 }
					else nil,
				anim = { kind = "Sway", period = 5 + k % 3, amount = 3, axis = "X" },
			})
			if useLight then
				lit += 1
			end
			upright(list, "LanternCap", 2, 8, GOLD, "Metal", v(x, ringSpec.y + 7.6, z))
			upright(list, "LanternTassel", 6, 1.4, GOLD, "Fabric", v(x, ringSpec.y - 10, z))
			upright(list, "LanternCord", 40, 0.4, c(40, 20, 16), "Fabric", v(x, ringSpec.y + 28, z))
		end
	end
	-- 회전판을 내려 비추는 그림자 등 1개
	put(list, "CenterSpot", "Ball", v(8, 6, 8), GOLD, "Metal", v(0, 110, 0), nil, {
		light = {
			kind = "Spot",
			color = c(255, 226, 190),
			brightness = 1.8,
			range = 60,
			angle = 80,
			face = "Bottom",
			shadows = true,
		},
	})
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	turntable(list)
	tableAndDishes(list)
	room(list)
	return list
end

Art.LIGHTING = {
	ClockTime = 19.6,
	Brightness = 1.1,
	Ambient = c(118, 100, 104),
	OutdoorAmbient = c(100, 86, 92),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.6,
	ShadowSoftness = 0.4,
	Atmosphere = {
		Density = 0.25,
		Offset = 0.1,
		Color = c(170, 130, 120),
		Decay = c(90, 60, 56),
		Glare = 0.2,
		Haze = 1,
	},
	ColorCorrection = {
		Brightness = 0.03,
		Contrast = 0.14,
		Saturation = 0.12,
		TintColor = c(255, 244, 236),
	},
	Bloom = { Intensity = 0.55, Size = 24, Threshold = 1.05 },
} :: MapLighting.MapLighting

function Art.courseVolume(): { Bounds }
	local r = Layout.OUTER_RADIUS
	return { { min = v(-r, Layout.FLOOR_Y + 2, -r), max = v(r, Layout.FLOOR_Y + 12, r) } }
end

-- 소개: ① 붉은 등 사이 위에서 전체 → ② 바깥 고리 옆 낮게 → ③ 딤섬 찜기 너머 → ④ 가운데 유리판 위 → ⑤ 스폰 쪽
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-60, 46, 70), lookAt = v(0, 0, 0) },
		{ pos = v(84, 10, -30), lookAt = v(0, 0, 20) },
		{ pos = v(-40, 30, -100), lookAt = v(10, -10, 0) },
		{ pos = v(0, 40, 0.1), lookAt = v(0, 0, 30) },
		{ pos = v(30, 18, 60), lookAt = v(0, 2, 0) },
	}
end

return Art
