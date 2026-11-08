--!strict
-- "연회상 쟁반 쓸기"(banquet-sweep, m6-07) 장식 데이터. Roblox API 없음.
-- 아트 디렉션: "종이 등이 켜진 저녁 연회장 — 거대한 옻칠 상 위 다다미에서 밀려오는 쟁반을 피해요"
--   Art.decor() / courseVolume() / introCamera() / tileColor(i, j) / BUDGET / LIGHTING / JUDGE_COLORS
-- 층: FG 상 테두리 옻칠·금박 모서리 / MG 상 다리·방석·술병·회 배·젓가락 / BG 장지문 벽·도코노마(족자·꽃꽂이)·
--     종이 등(빛)·천장 들보·다다미 방바닥.
-- 판정 색: 다다미 타일(바깥 한 줄은 조금 진하게 — 45초에 무너질 줄을 미리 알아보게), 낮은 벽 남색·높은 벽 붉은 옻칠,
--          예고 줄 노랑(벽)·초록(빈 칸), 무너지기 직전 바깥 줄 빨강.

local Layout = require(script.Parent.BanquetSweepLayout)
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
Art.ROOM_FLOOR_Y = -60 -- 방바닥 (낙하선 -12보다 48 아래)
Art.ROOM_HALF = 150
Art.WALL_HEIGHT = 140

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 색 (60 다다미·종이·나무 / 30 검은·붉은 옻칠 / 10 금박·등불·음식) ─────────────────────
local TATAMI = MapKitLogic.shades(c(216, 208, 140))
local TATAMI_OUTER = MapKitLogic.shades(c(184, 170, 104))
local TATAMI_EDGE = c(70, 92, 62) -- 다다미 테두리 천(짙은 녹색) — 검정이면 틈처럼 보여요(렌더 비평 1회차)
local LACQUER = MapKitLogic.shades(c(36, 26, 24))
local VERMILION = MapKitLogic.shades(c(178, 40, 36))
local GOLD = c(222, 180, 84)
local WOOD = MapKitLogic.shades(c(150, 104, 66))
local PAPER = MapKitLogic.shades(c(246, 236, 210))
local LAMP_LIGHT = c(255, 206, 150)
local PORCELAIN = MapKitLogic.PALETTE.Porcelain
local BLUE = MapKitLogic.PALETTE.PorcelainRim

Art.JUDGE_COLORS = {
	wallLow = c(52, 70, 150), -- 낮은 벽: 남색 옻칠 쟁반 (금색은 다다미와 섞여요 — 렌더 비평 2회차)
	wallHigh = c(186, 36, 36), -- 높은 벽: 붉은 옻칠 쟁반
	warnWall = c(255, 214, 50), -- 예고: 벽이 오는 칸
	warnGap = c(80, 226, 110), -- 예고: 빈 칸
	collapseWarn = c(226, 70, 52), -- 무너지기 직전 바깥 줄
}

-- 다다미: 칸마다 결 방향이 바뀌듯 밝기를 번갈아, 바깥 한 줄은 진하게
function Art.tileColor(i: number, j: number): RGB
	local outer = i == 1 or j == 1 or i == Layout.LANES or j == Layout.LANES
	local base = if outer then TATAMI_OUTER else TATAMI
	return if (i + j) % 2 == 0 then base.light else base.base
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

-- ── 상: 다다미 테두리 선·옻칠 테두리·다리 ──────────────────────────────
local function board(list: { DecorSpec })
	local h = Layout.HALF
	local y = Layout.FLOOR_Y
	-- 다다미 테두리 천(검은 띠) — 타일 이음새 아래로 살짝 보이게, 밟는 면보다 아래
	for k = 0, Layout.LANES do
		local p = -h + k * Layout.TILE
		put(list, "TatamiEdgeX", "Block", v(0.4, 0.3, h * 2), TATAMI_EDGE, "Fabric", v(p, y - 0.1, 0))
		put(list, "TatamiEdgeZ", "Block", v(h * 2, 0.3, 0.4), TATAMI_EDGE, "Fabric", v(0, y - 0.1, p))
	end
	-- 옻칠 상판 (타일 밑)
	put(list, "TableTop", "Block", v(h * 2 + 8, 6, h * 2 + 8), LACQUER.base, "SmoothPlastic", v(0, y - 5, 0), nil, {
		reflectance = 0.12,
	})
	-- 가장자리 붉은 띠·금박 모서리 (밟는 면 바로 아래)
	append(
		list,
		MapKitShapes.lipTrim(
			"TableRim",
			v(h * 2 + 8, 0, h * 2 + 8),
			1.2,
			3,
			VERMILION.base,
			"SmoothPlastic",
			v(0, y - 3, 0)
		)
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			put(list, "GoldCorner", "Block", v(6, 3.4, 6), GOLD, "Metal", v(sx * (h + 4), y - 3, sz * (h + 4)), nil, {
				reflectance = 0.3,
			})
		end
	end
	-- 상 다리 4개 (방바닥까지) + 가로대
	local legTop = y - 8
	local legLen = legTop - Art.ROOM_FLOOR_Y
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			put(
				list,
				"TableLeg",
				"Block",
				v(10, legLen, 10),
				LACQUER.base,
				"SmoothPlastic",
				v(sx * (h - 2), (legTop + Art.ROOM_FLOOR_Y) / 2, sz * (h - 2))
			)
			put(
				list,
				"LegFoot",
				"Block",
				v(14, 3, 14),
				GOLD,
				"Metal",
				v(sx * (h - 2), Art.ROOM_FLOOR_Y + 1.5, sz * (h - 2))
			)
		end
	end
	for _, s in { -1, 1 } do
		put(list, "Apron", "Block", v(h * 2 - 4, 4, 2), VERMILION.dark, "SmoothPlastic", v(0, y - 10, s * (h + 1)))
		put(list, "Apron", "Block", v(2, 4, h * 2 - 4), VERMILION.dark, "SmoothPlastic", v(s * (h + 1), y - 10, 0))
	end
end

-- ── 방바닥 위 소품: 방석·술병·잔·회 배·젓가락 ────────────────────────
local function floorProps(list: { DecorSpec })
	local fy = Art.ROOM_FLOOR_Y
	-- 방석 (상 둘레)
	for k = 0, 11 do
		local side = k % 4
		local t = (math.floor(k / 4) - 1) * 32
		local d = Layout.HALF + 24
		local x, z = 0, 0
		if side == 0 then
			x, z = t, -d
		elseif side == 1 then
			x, z = d, t
		elseif side == 2 then
			x, z = t, d
		else
			x, z = -d, t
		end
		put(
			list,
			"Zabuton",
			"Block",
			v(24, 4, 24),
			if k % 2 == 0 then VERMILION.base else c(70, 80, 140),
			"Fabric",
			v(x, fy + 2, z),
			v(0, k * 7, 0)
		)
		put(list, "ZabutonTuft", "Ball", v(2, 1.4, 2), GOLD, "Fabric", v(x, fy + 4.4, z))
	end
	-- 거대한 술병·잔 (앞 왼쪽)
	upright(list, "Tokkuri", 30, 22, PORCELAIN, "SmoothPlastic", v(-100, fy + 15, -96))
	upright(list, "TokkuriNeck", 12, 9, PORCELAIN, "SmoothPlastic", v(-100, fy + 36, -96))
	upright(list, "TokkuriBand", 3, 22.4, BLUE, "SmoothPlastic", v(-100, fy + 22, -96))
	for k = 0, 2 do
		upright(list, "SakeCup", 5, 10, PORCELAIN, "SmoothPlastic", v(-80 + k * 12, fy + 2.5, -112 + k * 6))
		upright(list, "SakeInside", 0.4, 8, c(240, 236, 220), "Glass", v(-80 + k * 12, fy + 5, -112 + k * 6), {
			transparency = 0.3,
		})
	end
	-- 회 배 (오른쪽 뒤): 배 몸통 + 회
	put(list, "BoatHull", "Block", v(60, 8, 20), WOOD.base, "Wood", v(100, fy + 4, 96))
	put(list, "BoatBow", "Wedge", v(20, 8, 16), WOOD.base, "Wood", v(138, fy + 4, 96), v(0, -90, 0))
	put(list, "BoatMast", "Block", v(2, 26, 2), WOOD.dark, "Wood", v(96, fy + 21, 96))
	put(list, "BoatSail", "Block", v(0.4, 16, 14), PAPER.base, "Fabric", v(96, fy + 24, 96))
	for k = 0, 5 do
		put(
			list,
			"Sashimi",
			"Block",
			v(7, 2, 5),
			if k % 2 == 0 then c(236, 120, 96) else c(240, 220, 210),
			"SmoothPlastic",
			v(80 + k * 7, fy + 9, 94 + (k % 2) * 4),
			v(0, 0, 18)
		)
	end
	put(list, "Shiso", "Wedge", v(1, 6, 8), c(90, 150, 70), "SmoothPlastic", v(114, fy + 10, 96), v(0, 90, 0))
	-- 젓가락·받침 (오른쪽 앞)
	put(list, "ChopRest", "Block", v(8, 3, 4), PORCELAIN, "SmoothPlastic", v(110, fy + 1.5, -84))
	for k = -1, 1, 2 do
		put(
			list,
			"Chopstick",
			"Block",
			v(1.6, 1.6, 56),
			VERMILION.dark,
			"SmoothPlastic",
			v(110 + k * 2, fy + 3.4, -60),
			v(0, 8, 0)
		)
	end
end

-- ── 방: 다다미 바닥·장지문 벽·도코노마·천장·종이 등 ───────────────────
local function room(list: { DecorSpec })
	local fy = Art.ROOM_FLOOR_Y
	local half = Art.ROOM_HALF
	-- 다다미 방바닥 (60 × 30 판, 결 번갈아)
	for x = -half + 30, half - 30, 60 do
		for z = -half + 15, half - 15, 30 do
			local alt = ((x + z) / 30) % 2 == 0
			put(
				list,
				"RoomTatami",
				"Block",
				v(59.4, 1, 29.4),
				if alt then TATAMI.dark else TATAMI.base,
				"Fabric",
				v(x, fy - 0.5, z)
			)
		end
	end
	-- 벽 4면: 아래 나무 띠 + 장지문(종이 + 격자) + 위 벽
	local h = Art.WALL_HEIGHT
	for side = 0, 3 do
		local yaw = side * 90
		local function at(along: number, y: number, inset: number): Vec3
			local d = half - inset
			if side == 0 then
				return v(along, y, -d)
			elseif side == 1 then
				return v(d, y, along)
			elseif side == 2 then
				return v(-along, y, d)
			end
			return v(-d, y, -along)
		end
		put(list, "Wall", "Block", v(half * 2, h, 4), PAPER.dark, "Plaster", at(0, fy + h / 2, -2), v(0, -yaw, 0))
		put(list, "Baseboard", "Block", v(half * 2, 8, 1.6), WOOD.dark, "Wood", at(0, fy + 4, 0.8), v(0, -yaw, 0))
		put(list, "Lintel", "Block", v(half * 2, 4, 2), WOOD.dark, "Wood", at(0, fy + 92, 1), v(0, -yaw, 0))
		-- 란마(문 위 나무 조각 띠): 짙은 판 + 세로살, 위 벽이 밋밋하지 않게
		put(list, "Ranma", "Block", v(half * 2, 26, 0.8), WOOD.dark, "Wood", at(0, fy + 108, 1.2), v(0, -yaw, 0))
		for m = -12, 12 do
			put(
				list,
				"RanmaSlat",
				"Block",
				v(1.4, 22, 1),
				PAPER.base,
				"Wood",
				at(m * 11.5, fy + 108, 1.8),
				v(0, -yaw, 0)
			)
		end
		put(list, "UpperRail", "Block", v(half * 2, 3, 2), WOOD.dark, "Wood", at(0, fy + 122, 1), v(0, -yaw, 0))
		if side == 2 then
			-- 도코노마: 움푹한 단 + 족자 + 꽃꽂이
			put(list, "TokonomaStep", "Block", v(80, 6, 30), WOOD.base, "Wood", at(0, fy + 3, 15), v(0, -yaw, 0))
			put(list, "Scroll", "Block", v(26, 70, 0.6), PAPER.light, "Fabric", at(0, fy + 50, 1.2), v(0, -yaw, 0))
			put(
				list,
				"ScrollInk",
				"Block",
				v(4, 40, 0.4),
				c(30, 30, 34),
				"SmoothPlastic",
				at(0, fy + 52, 1.6),
				v(0, -yaw, 0)
			)
			put(
				list,
				"ScrollSun",
				"Cylinder",
				v(0.4, 12, 12),
				VERMILION.base,
				"SmoothPlastic",
				at(-6, fy + 74, 1.6),
				v(0, -yaw + 90, 0)
			)
			put(list, "ScrollRod", "Cylinder", v(30, 1.6, 1.6), WOOD.dark, "Wood", at(0, fy + 15, 1.6), v(0, -yaw, 0))
			upright(list, "Vase", 14, 12, LACQUER.base, "SmoothPlastic", at(26, fy + 13, 15))
			for k = 0, 4 do
				local a = k * 72
				put(
					list,
					"Branch",
					"Cylinder",
					v(26, 0.8, 0.8),
					WOOD.dark,
					"Wood",
					at(26 + math.cos(math.rad(a)) * 5, fy + 30, 15 + math.sin(math.rad(a)) * 5),
					v(0, a, 70)
				)
				put(
					list,
					"Blossom",
					"Ball",
					v(5, 5, 5),
					c(244, 170, 190),
					"SmoothPlastic",
					at(26 + math.cos(math.rad(a)) * 11, fy + 42, 15 + math.sin(math.rad(a)) * 11)
				)
			end
		else
			-- 장지문 4짝 (불 켜진 종이)
			for door = -1.5, 1.5 do
				local along = door * 60
				put(
					list,
					"Shoji",
					"Block",
					v(56, 84, 0.6),
					PAPER.light,
					"SmoothPlastic",
					at(along, fy + 46, 1.2),
					v(0, -yaw, 0)
				)
				for m = -2, 2 do
					put(
						list,
						"ShojiV",
						"Block",
						v(1.2, 84, 1),
						WOOD.base,
						"Wood",
						at(along + m * 11, fy + 46, 1.6),
						v(0, -yaw, 0)
					)
				end
				for m = 0, 5 do
					put(
						list,
						"ShojiH",
						"Block",
						v(56, 1.2, 1),
						WOOD.base,
						"Wood",
						at(along, fy + 8 + m * 15, 1.6),
						v(0, -yaw, 0)
					)
				end
			end
		end
	end
	-- 천장 + 들보
	put(list, "Ceiling", "Block", v(half * 2, 2, half * 2), WOOD.dark, "WoodPlanks", v(0, fy + h + 1, 0))
	for k = -2, 2 do
		put(list, "CeilingBeam", "Block", v(half * 2, 6, 5), LACQUER.light, "Wood", v(0, fy + h - 3, k * 56))
		put(list, "CeilingBeam", "Block", v(5, 6, half * 2), LACQUER.light, "Wood", v(k * 56, fy + h - 3, 0))
	end
	-- 매단 종이 등 (상 위, 원형 두 겹) — 상 위 공간(바닥 + 12)보다 충분히 위
	local lit = 0
	for _, ring in { { r = 30, n = 4, y = 44 }, { r = 78, n = 8, y = 52 } } do
		for k = 0, ring.n - 1 do
			local a = math.rad(k * 360 / ring.n + 22.5)
			local x, z = math.cos(a) * ring.r, math.sin(a) * ring.r
			local useLight = lit < 8 and (ring.n == 4 or k % 2 == 0)
			put(list, "PaperLamp", "Ball", v(10, 13, 10), PAPER.light, "SmoothPlastic", v(x, ring.y, z), nil, {
				light = if useLight then { kind = "Point", color = LAMP_LIGHT, brightness = 1.4, range = 44 } else nil,
				anim = { kind = "Sway", period = 6 + k % 3, amount = 2, axis = "Z" },
			})
			if useLight then
				lit += 1
			end
			upright(list, "LampCap", 2, 7, LACQUER.base, "SmoothPlastic", v(x, ring.y + 7, z))
			upright(list, "LampBase", 2, 7, LACQUER.base, "SmoothPlastic", v(x, ring.y - 7, z))
			upright(
				list,
				"LampCord",
				Art.ROOM_FLOOR_Y + h - ring.y - 8,
				0.4,
				c(30, 24, 20),
				"Fabric",
				v(x, (ring.y + 8 + Art.ROOM_FLOOR_Y + h) / 2, z)
			)
		end
	end
	-- 바닥 등(안돈) 4개 — 방 모서리
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (half - 24), sz * (half - 24)
			put(list, "AndonFrame", "Block", v(12, 26, 12), WOOD.dark, "Wood", v(x, Art.ROOM_FLOOR_Y + 13, z))
			put(
				list,
				"AndonPaper",
				"Block",
				v(10.6, 22, 10.6),
				PAPER.light,
				"SmoothPlastic",
				v(x, Art.ROOM_FLOOR_Y + 14, z),
				nil,
				{
					light = { kind = "Point", color = LAMP_LIGHT, brightness = 1.2, range = 40 },
				}
			)
		end
	end
	-- 상을 내려 비추는 그림자 등 1개
	put(list, "TopSpot", "Ball", v(8, 6, 8), LACQUER.base, "SmoothPlastic", v(0, Art.ROOM_FLOOR_Y + h - 8, 0), nil, {
		light = {
			kind = "Spot",
			color = c(255, 232, 200),
			brightness = 1.6,
			range = 60,
			angle = 80,
			face = "Bottom",
			shadows = true,
		},
	})
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	board(list)
	floorProps(list)
	room(list)
	return list
end

Art.LIGHTING = {
	ClockTime = 19.2,
	Brightness = 1.3,
	Ambient = c(134, 122, 110),
	OutdoorAmbient = c(108, 98, 92),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.5,
	ShadowSoftness = 0.4,
	Atmosphere = {
		Density = 0.22,
		Offset = 0.1,
		Color = c(176, 150, 120),
		Decay = c(96, 76, 60),
		Glare = 0.1,
		Haze = 0.8,
	},
	ColorCorrection = {
		Brightness = 0.03,
		Contrast = 0.12,
		Saturation = 0.08,
		TintColor = c(255, 246, 232),
	},
	Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.05 },
} :: MapLighting.MapLighting

function Art.courseVolume(): { Bounds }
	local h = Layout.HALF
	return { { min = v(-h, Layout.FLOOR_Y + 2, -h), max = v(h, Layout.FLOOR_Y + 12, h) } }
end

-- 소개: ① 종이 등 사이 위에서 상 전체 → ② 상 모서리 낮게 → ③ 도코노마 쪽에서 → ④ 회 배 너머 → ⑤ 스폰 위
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-84, 30, -12), lookAt = v(0, 0, 0) },
		{ pos = v(56, 8, 56), lookAt = v(0, 2, 0) },
		{ pos = v(0, 26, 84), lookAt = v(0, 0, 0) },
		{ pos = v(80, 16, -40), lookAt = v(-10, 0, 0) },
		{ pos = v(0, 34, -50), lookAt = v(0, 0, 4) },
	}
end

return Art
