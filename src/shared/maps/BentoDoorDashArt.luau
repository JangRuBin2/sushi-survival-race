--!strict
-- "도시락 뚜껑 대탈출"(bento-door-dash, m6-04) 장식 데이터. Roblox API 없음.
-- 아트 디렉션: "한낮 벚꽃 아래 피크닉 — 작은 초밥이 거대한 옻칠 도시락 가운데 칸을 달려요" (REFERENCE-map-art-direction 필수).
--   Art.decor() / courseVolume() / introCamera() / BUDGET / LIGHTING / JUDGE_COLORS / BLANKET_Y
-- 층: FG 칸막이 위 바란(초록 잎 칸막이)·금색 테두리 / MG 양옆 칸의 큰 반찬(달걀말이·주먹밥·우메보시·가라아게·문어 소시지·
--     브로콜리·방울토마토·상추) / BG 도시락 바깥 옻칠 벽·피크닉 돗자리·벚나무(꽃잎)·결승 너머 기대 놓은 뚜껑과 젓가락.
-- 코스(가운데 칸)는 높이 10 벽으로 둘러싸여 있고 양옆 칸 바닥은 4 낮아서 같은 바닥처럼 보이지 않아요.

local Layout = require(script.Parent.BentoDoorDashLayout)
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

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 치수 ────────────────────────────────────────────────────────────
Art.BOX_BACK_Z = 24 -- 도시락 상자 안쪽 끝 (출발 뒤)
Art.BOX_END_Z = -524
Art.BOX_INNER_X = 124 -- 상자 바깥 벽 안쪽 면 (x ±)
Art.BOX_WALL = 6
Art.BOX_TOP_Y = 24
Art.SIDE_FLOOR_Y = -4 -- 양옆 칸 바닥
Art.BOX_BOTTOM_Y = -30
Art.BLANKET_Y = -30 -- 돗자리 윗면 (낙하선 -12보다 18 아래)

-- ── 색 (60 옻칠 검정·빨강 + 밥 흰색 / 30 반찬 노랑·갈색·초록 / 10 금색·우메보시·벚꽃 분홍) ──────────────
local LACQUER_BLACK = MapKitLogic.shades(c(36, 30, 32))
local LACQUER_RED = MapKitLogic.shades(c(176, 40, 40))
local GOLD = c(214, 172, 78)
local RICE = MapKitLogic.shades(MapKitLogic.PALETTE.Rice)
local EGG = MapKitLogic.shades(MapKitLogic.PALETTE.Egg)
local KARAAGE = MapKitLogic.shades(c(196, 120, 52))
local SAUSAGE = c(230, 92, 70)
local BROCCOLI = MapKitLogic.shades(c(70, 140, 60))
local TOMATO = c(220, 46, 40)
local LETTUCE = c(140, 200, 90)
local BARAN = c(56, 160, 80)
local UME = c(196, 40, 60)
local NORI = MapKitLogic.PALETTE.Nori
local BLANKET_A = c(220, 70, 70)
local BLANKET_B = c(250, 244, 236)
local GRASS = MapKitLogic.shades(c(120, 176, 90))
local BARK = c(96, 66, 52)
local BLOSSOM = MapKitLogic.shades(c(255, 196, 214))
local CHOPSTICK = c(186, 140, 92)

-- 판정 파츠 색 (BentoDoorDash.build가 써요)
Art.JUDGE_COLORS = {
	floor = c(238, 230, 212), -- 가운데 칸 바닥 (따뜻한 밥 색 — 흰 문과 구분)
	sideWall = c(170, 36, 38), -- 안쪽 빨간 옻칠 벽
	divider = c(120, 84, 54), -- 문 위 가로대 (나무 칸막이)
	doorA = c(246, 196, 190), -- 종이 뚜껑 문 (연분홍·연노랑 번갈아 — 진짜·가짜는 같은 모양)
	doorB = c(246, 226, 160),
	soy = c(70, 38, 22), -- 간장 웅덩이
	hub = c(150, 110, 70), -- 막대 축
	bar = c(196, 150, 96), -- 회전 젓가락
	pad = c(150, 210, 80), -- 와사비 튕김판
	ball = c(190, 36, 58), -- 우메보시
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

-- ── 도시락 상자 (바깥 벽·바닥·금 테두리, 가운데 칸 벽 위 금줄) ──────────
local function box(list: { DecorSpec })
	local length = Art.BOX_BACK_Z - Art.BOX_END_Z
	local midZ = (Art.BOX_BACK_Z + Art.BOX_END_Z) / 2
	local height = Art.BOX_TOP_Y - Art.BOX_BOTTOM_Y
	for _, side in { -1, 1 } do
		local x = side * (Art.BOX_INNER_X + Art.BOX_WALL / 2)
		put(
			list,
			"BoxWall",
			"Block",
			v(Art.BOX_WALL, height, length + Art.BOX_WALL * 2),
			LACQUER_BLACK.base,
			"SmoothPlastic",
			v(x, Art.BOX_BOTTOM_Y + height / 2, midZ),
			nil,
			{ reflectance = 0.1 }
		)
		put(
			list,
			"BoxWallInner",
			"Block",
			v(0.4, height - 2, length),
			LACQUER_RED.base,
			"SmoothPlastic",
			v(side * (Art.BOX_INNER_X - 0.2), Art.BOX_BOTTOM_Y + height / 2, midZ),
			nil,
			{ reflectance = 0.08 }
		)
		put(
			list,
			"BoxRim",
			"Block",
			v(Art.BOX_WALL + 1, 1, length + Art.BOX_WALL * 2 + 1),
			GOLD,
			"Metal",
			v(x, Art.BOX_TOP_Y + 0.5, midZ),
			nil,
			{ reflectance = 0.25 }
		)
		-- 가운데 칸 벽(판정, 높이 10) 위 금줄과 바깥쪽 검정 판
		put(
			list,
			"LaneRim",
			"Block",
			v(2.4, 0.6, length - 48),
			GOLD,
			"Metal",
			v(side * (Layout.HALF + 1.4), Layout.SIDE_WALL_HEIGHT + 0.3, (Layout.COURSE.front + Layout.COURSE.back) / 2),
			nil,
			{ reflectance = 0.25 }
		)
		put(
			list,
			"LaneWallOuter",
			"Block",
			v(0.6, Layout.SIDE_WALL_HEIGHT - Art.SIDE_FLOOR_Y, length - 48),
			LACQUER_BLACK.light,
			"SmoothPlastic",
			v(
				side * (Layout.HALF + 2.3),
				(Layout.SIDE_WALL_HEIGHT + Art.SIDE_FLOOR_Y) / 2,
				(Layout.COURSE.front + Layout.COURSE.back) / 2
			)
		)
		-- 양옆 칸 바닥 (가운데보다 4 낮게)
		put(
			list,
			"SideFloor",
			"Block",
			v(Art.BOX_INNER_X - Layout.HALF - 3, 2, length),
			LACQUER_RED.dark,
			"SmoothPlastic",
			v(side * (Layout.HALF + 3 + (Art.BOX_INNER_X - Layout.HALF - 3) / 2), Art.SIDE_FLOOR_Y - 1, midZ)
		)
	end
	for _, z in { Art.BOX_BACK_Z + Art.BOX_WALL / 2, Art.BOX_END_Z - Art.BOX_WALL / 2 } do
		put(
			list,
			"BoxEnd",
			"Block",
			v(Art.BOX_INNER_X * 2, height, Art.BOX_WALL),
			LACQUER_BLACK.base,
			"SmoothPlastic",
			v(0, Art.BOX_BOTTOM_Y + height / 2, z),
			nil,
			{ reflectance = 0.1 }
		)
		put(
			list,
			"BoxEndRim",
			"Block",
			v(Art.BOX_INNER_X * 2, 1, Art.BOX_WALL + 1),
			GOLD,
			"Metal",
			v(0, Art.BOX_TOP_Y + 0.5, z),
			nil,
			{ reflectance = 0.25 }
		)
	end
	-- 가운데 칸 바닥 밑 몸통 (밥 칸 아래)
	put(
		list,
		"LaneBase",
		"Block",
		v(Layout.WIDTH + 4, -2 - Art.BOX_BOTTOM_Y, length),
		LACQUER_BLACK.dark,
		"SmoothPlastic",
		v(0, (Art.BOX_BOTTOM_Y - 2) / 2, midZ)
	)
	-- 칸막이(문 줄) 위 바란 (초록 잎 칸막이 — 가로대 위 14 ~ 19)
	for _, wallZ in Layout.DOOR_ROWS_Z do
		for k = 0, 9 do
			local x = -Layout.HALF + 4 + k * 8
			put(
				list,
				"Baran",
				"Wedge",
				v(7.6, 5, 0.6),
				BARAN,
				"SmoothPlastic",
				v(x, Layout.WALL_HEIGHT + 2.5, wallZ),
				nil,
				nil
			)
			put(
				list,
				"BaranTip",
				"Wedge",
				v(7.6, 5, 0.6),
				BARAN,
				"SmoothPlastic",
				v(x, Layout.WALL_HEIGHT + 2.5, wallZ),
				v(0, 180, 0)
			)
		end
		put(
			list,
			"DividerCap",
			"Block",
			v(Layout.WIDTH + 6, 0.8, 2.6),
			GOLD,
			"Metal",
			v(0, Layout.WALL_HEIGHT + 0.4, wallZ),
			nil,
			{ reflectance = 0.2 }
		)
	end
end

-- ── 양옆 칸 반찬 ──────────────────────────────────────────────────────
local function sideDishes(list: { DecorSpec })
	local floorY = Art.SIDE_FLOOR_Y
	-- 왼쪽: 주먹밥(김)·달걀말이 탑·우메보시 / 오른쪽: 가라아게·문어 소시지·브로콜리·방울토마토, 상추로 구역 나눔
	for z = Art.BOX_BACK_Z - 40, Art.BOX_END_Z + 40, -96 do
		-- 왼쪽 주먹밥 두 개
		for k = 0, 1 do
			local x = -70 - k * 30
			local zz = z - k * 20
			-- 둥근 세모: 아래 넓은 공 + 위 작은 공, 김은 아래 띠
			-- 공 세 개를 세모로 (아래 둘 + 위 하나)
			put(list, "Onigiri", "Ball", v(14, 14, 12), RICE.base, "SmoothPlastic", v(x - 5, floorY + 7, zz))
			put(list, "Onigiri", "Ball", v(14, 14, 12), RICE.base, "SmoothPlastic", v(x + 5, floorY + 7, zz))
			put(list, "Onigiri", "Ball", v(13, 13, 11.5), RICE.light, "SmoothPlastic", v(x, floorY + 15, zz))
			put(list, "OnigiriNori", "Block", v(13, 8, 13.6), NORI, "SmoothPlastic", v(x, floorY + 4, zz))
			put(list, "OnigiriUme", "Ball", v(5, 5, 3), UME, "SmoothPlastic", v(x, floorY + 18, zz + 5.6))
		end
		-- 왼쪽 달걀말이 탑 (3층)
		for k = 0, 2 do
			put(
				list,
				"Tamagoyaki",
				"Block",
				v(18, 9, 14),
				if k % 2 == 0 then EGG.base else EGG.light,
				"SmoothPlastic",
				v(-100, floorY + 4.5 + k * 9.2, z - 50),
				v(0, k * 8, 0)
			)
			put(
				list,
				"TamagoyakiSwirl",
				"Block",
				v(18.2, 1.2, 1),
				EGG.dark,
				"SmoothPlastic",
				v(-100, floorY + 6 + k * 9.2, z - 50),
				v(0, k * 8, 0)
			)
		end
		-- 상추 칸막이 (양쪽)
		for _, side in { -1, 1 } do
			for k = 0, 3 do
				put(
					list,
					"Lettuce",
					"Wedge",
					v(16, 12, 1.2),
					LETTUCE,
					"Grass",
					v(side * (58 + k * 16), floorY + 6, z - 76),
					v(0, 0, (k % 2) * 10 - 5)
				)
			end
		end
		-- 오른쪽 가라아게 더미
		local rng = MapKitShapes.rng(math.floor(-z))
		for k = 0, 6 do
			local px = 70 + rng:range(-12, 12)
			local pz = z + rng:range(-14, 14)
			put(
				list,
				"Karaage",
				"Ball",
				v(10, 8, 9),
				if k % 2 == 0 then KARAAGE.base else KARAAGE.dark,
				"Sand",
				v(px, floorY + 4 + (k % 3) * 3, pz),
				v(0, k * 40, 0)
			)
		end
		-- 문어 소시지
		for k = 0, 2 do
			local sx, sz = 98, z - 30 + k * 12
			upright(list, "Sausage", 9, 7, SAUSAGE, "SmoothPlastic", v(sx, floorY + 6, sz))
			for leg = 0, 5 do
				local a = leg * math.pi / 3
				put(
					list,
					"SausageLeg",
					"Block",
					v(1.4, 4, 1.4),
					SAUSAGE,
					"SmoothPlastic",
					v(sx + math.cos(a) * 3, floorY + 2, sz + math.sin(a) * 3),
					v(math.deg(math.sin(a)) * 0.4, 0, -math.deg(math.cos(a)) * 0.4)
				)
			end
			put(list, "SausageEye", "Ball", v(1.2, 1.2, 0.6), NORI, "SmoothPlastic", v(sx - 1.4, floorY + 8, sz + 3.4))
			put(list, "SausageEye", "Ball", v(1.2, 1.2, 0.6), NORI, "SmoothPlastic", v(sx + 1.4, floorY + 8, sz + 3.4))
		end
		-- 브로콜리와 방울토마토
		upright(list, "BroccoliStem", 8, 4, c(150, 190, 110), "SmoothPlastic", v(80, floorY + 4, z - 50))
		for k = 0, 4 do
			local a = k * 2 * math.pi / 5
			put(
				list,
				"BroccoliTop",
				"Ball",
				v(7, 6, 7),
				if k % 2 == 0 then BROCCOLI.base else BROCCOLI.dark,
				"Grass",
				v(80 + math.cos(a) * 3.5, floorY + 10, z - 50 + math.sin(a) * 3.5)
			)
		end
		put(list, "BroccoliTop", "Ball", v(8, 7, 8), BROCCOLI.light, "Grass", v(80, floorY + 12, z - 50))
		for k = 0, 1 do
			put(
				list,
				"Tomato",
				"Ball",
				v(8, 8, 8),
				TOMATO,
				"SmoothPlastic",
				v(104 - k * 10, floorY + 4, z - 58 - k * 6),
				nil,
				{ reflectance = 0.15 }
			)
			put(
				list,
				"TomatoStem",
				"Block",
				v(2, 0.6, 2),
				c(70, 140, 60),
				"SmoothPlastic",
				v(104 - k * 10, floorY + 8.2, z - 58 - k * 6),
				v(0, 45, 0)
			)
		end
	end
end

-- ── 바깥: 피크닉 돗자리·잔디·벚나무·결승 너머 뚜껑과 젓가락 ──────────────
local function outdoors(list: { DecorSpec })
	-- 돗자리 (빨강·흰 체크)
	local tile = 48
	for z = Art.BOX_BACK_Z + 72, Art.BOX_END_Z - 120, -tile do
		for x = -168, 168, tile do
			local even = (math.floor(z / tile) + math.floor(x / tile)) % 2 == 0
			put(
				list,
				"Blanket",
				"Block",
				v(tile, 1, tile),
				if even then BLANKET_A else BLANKET_B,
				"Fabric",
				v(x, Art.BLANKET_Y - 0.5, z - tile / 2)
			)
		end
	end
	-- 잔디 (돗자리 바깥 띠)
	for _, side in { -1, 1 } do
		put(list, "Grass", "Block", v(160, 1, 760), GRASS.base, "Grass", v(side * 272, Art.BLANKET_Y - 1.2, -250))
	end
	-- 벚나무 (양옆 멀리, 꽃잎 파티클)
	local petals = 0
	for _, tree in
		{
			{ x = -260, z = -60 },
			{ x = 260, z = -150 },
			{ x = -250, z = -330 },
			{ x = 270, z = -420 },
			{ x = -230, z = -560 },
			{ x = 210, z = -620 },
		}
	do
		local trunkH = 70
		put(
			list,
			"TreeTrunk",
			"Cylinder",
			v(trunkH, 12, 12),
			BARK,
			"Wood",
			v(tree.x, Art.BLANKET_Y + trunkH / 2, tree.z),
			v(0, 0, 90)
		)
		put(
			list,
			"TreeBranch",
			"Cylinder",
			v(40, 6, 6),
			BARK,
			"Wood",
			v(tree.x + 12, Art.BLANKET_Y + trunkH + 4, tree.z),
			v(0, 0, 50)
		)
		local crowns = { v(0, 86, 0), v(26, 80, 14), v(-24, 78, -10), v(8, 96, -20), v(-10, 92, 22) }
		for k, cpos in crowns do
			local usePetals = k == 1 and petals < 6
			put(
				list,
				"Blossom",
				"Ball",
				v(52, 40, 52),
				if k % 2 == 0 then BLOSSOM.light else BLOSSOM.base,
				"Grass",
				v(tree.x + cpos.x, Art.BLANKET_Y + cpos.y, tree.z + cpos.z),
				nil,
				{
					particle = if usePetals then "Petals" else nil,
					particleRate = if usePetals then 6 else nil,
					anim = if k == 1 then { kind = "Sway", period = 7, amount = 2, axis = "Z" } else nil,
				}
			)
			if usePetals then
				petals += 1
			end
		end
	end
	-- 결승 너머 기대 놓은 뚜껑과 젓가락 한 쌍
	local lidZ = Art.BOX_END_Z - 40
	put(
		list,
		"Lid",
		"Block",
		v(Art.BOX_INNER_X * 2 + 16, 8, 120),
		LACQUER_BLACK.base,
		"SmoothPlastic",
		v(0, 30, lidZ - 20),
		v(-62, 0, 0),
		{ reflectance = 0.12 }
	)
	put(
		list,
		"LidGold",
		"Block",
		v(Art.BOX_INNER_X * 2 + 17, 1, 8),
		GOLD,
		"Metal",
		v(0, 50, lidZ - 10),
		v(-62, 0, 0),
		{ reflectance = 0.3 }
	)
	for k = 0, 4 do
		put(
			list,
			"LidFlower",
			"Ball",
			v(14, 1, 14),
			if k % 2 == 0 then BLOSSOM.base else GOLD,
			"SmoothPlastic",
			v(-80 + k * 40, 34 + (k % 2) * 8, lidZ - 22 + (k % 2) * 4),
			v(-62, 0, 0)
		)
	end
	-- 상자 옆 돗자리 위에 놓인 큰 젓가락 한 쌍과 젓가락 받침
	for k, x in { 152, 162 } do
		put(
			list,
			"BigChopstick",
			"Block",
			v(4, 4, 300),
			CHOPSTICK,
			"Wood",
			v(x, Art.BLANKET_Y + 2, -250),
			v(0, (k - 1.5) * 3, 0)
		)
	end
	put(
		list,
		"ChopstickRest",
		"Block",
		v(30, 5, 8),
		c(110, 150, 190),
		"SmoothPlastic",
		v(157, Art.BLANKET_Y + 2.5, -380)
	)
	-- 결승: 축하 등 두 개 + 꽃가루
	for _, x in { -Layout.HALF - 6, Layout.HALF + 6 } do
		put(
			list,
			"FinishLamp",
			"Ball",
			v(8, 10, 8),
			c(255, 220, 160),
			"SmoothPlastic",
			v(x, Layout.SIDE_WALL_HEIGHT + 8, Layout.FINISH_LINE_Z),
			nil,
			{
				light = { kind = "Point", color = c(255, 210, 160), brightness = 1.2, range = 30 },
				particle = "Confetti",
				particleRate = 6,
			}
		)
		put(
			list,
			"FinishPole",
			"Block",
			v(1.6, 18, 1.6),
			LACQUER_RED.base,
			"SmoothPlastic",
			v(x, Layout.SIDE_WALL_HEIGHT - 1, Layout.FINISH_LINE_Z)
		)
	end
	put(
		list,
		"FinishBanner",
		"Block",
		v(Layout.WIDTH + 12, 4, 0.6),
		c(250, 240, 220),
		"Fabric",
		v(0, Layout.SIDE_WALL_HEIGHT + 12, Layout.FINISH_LINE_Z)
	)
	put(
		list,
		"FinishBannerBand",
		"Block",
		v(Layout.WIDTH + 12, 1, 0.7),
		LACQUER_RED.base,
		"Fabric",
		v(0, Layout.SIDE_WALL_HEIGHT + 10, Layout.FINISH_LINE_Z)
	)
	-- 해 그림자 스포트 1개 (도시락 가운데)
	put(list, "SunSpot", "Block", v(2, 2, 2), GOLD, "SmoothPlastic", v(0, 120, -250), nil, {
		transparency = 1,
		light = {
			kind = "Spot",
			color = c(255, 240, 220),
			brightness = 1.2,
			range = 60,
			angle = 60,
			face = "Bottom",
			shadows = true,
		},
	})
end

-- 가운데 칸 바닥의 밥알 무늬 (밟는 면 바로 위 0.1 — 시야 상자 아래, 충돌 없음)
local function riceGrains(list: { DecorSpec })
	local rng = MapKitShapes.rng(7)
	for z = Layout.COURSE.front - 6, Layout.COURSE.back + 6, -10 do
		for _ = 1, 4 do
			local x = rng:range(-Layout.HALF + 3, Layout.HALF - 3)
			local zz = z + rng:range(-4, 4)
			put(
				list,
				"RiceGrain",
				"Ball",
				v(1.6, 0.16, 3.4),
				if rng:next() < 0.5 then c(250, 246, 236) else c(224, 214, 192),
				"SmoothPlastic",
				v(x, Layout.FLOOR_Y + 0.08, zz),
				v(0, rng:range(0, 180), 0),
				{ castShadow = false }
			)
		end
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	box(list)
	riceGrains(list)
	sideDishes(list)
	outdoors(list)
	return list
end

Art.LIGHTING = {
	ClockTime = 13.2,
	Brightness = 1.7,
	Ambient = c(170, 160, 168),
	OutdoorAmbient = c(190, 180, 186),
	EnvironmentDiffuseScale = 0.8,
	EnvironmentSpecularScale = 0.6,
	ShadowSoftness = 0.25,
	Atmosphere = {
		Density = 0.15,
		Offset = 0.05,
		Color = c(255, 226, 236),
		Decay = c(200, 176, 196),
		Glare = 0.2,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0.03,
		Contrast = 0.1,
		Saturation = 0.12,
		TintColor = c(255, 248, 250),
	},
	Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.1 },
} :: MapLighting.MapLighting

function Art.courseVolume(): { Bounds }
	return {
		{
			min = v(-Layout.HALF, Layout.FLOOR_Y + 2, Layout.COURSE.back),
			max = v(Layout.HALF, Layout.FLOOR_Y + 12, Layout.COURSE.front),
		},
	}
end

-- 소개: ① 벚나무 너머 도시락 전체 → ② 첫 문 줄 → ③ 회전 막대 위 → ④ 와사비 판과 결승 → ⑤ 출발 자리
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-60, 70, 50), lookAt = v(0, 0, -220) },
		{ pos = v(10, 20, -30), lookAt = v(0, 6, -80) },
		{ pos = v(30, 36, -240), lookAt = v(0, 0, -282) },
		{ pos = v(-20, 30, -320), lookAt = v(0, 4, -470) },
		{ pos = v(0, 14, 24), lookAt = v(0, 3, -40) },
	}
end

return Art
