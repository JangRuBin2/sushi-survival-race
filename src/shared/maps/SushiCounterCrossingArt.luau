--!strict
-- "초밥집 카운터 대횡단"(sushi-counter-crossing, m6-03) 장식 데이터. Roblox API 없음 — Lune 테스트에서 바로 불러요.
-- 아트 디렉션: "저녁 초밥집 카운터 — 작은 초밥이 거대한 히노키 카운터를 가로질러요" (REFERENCE-map-art-direction 필수).
--   Art.decor() -> { DecorSpec }        장식 전체 (충돌·쿼리·터치 없음 — MapKit.buildDecor)
--   Art.courseVolume() -> { Bounds }    장식이 들어가면 안 되는 코스 시야 상자 (밟는 면 위 2~12)
--   Art.introCamera() -> { IntroPoint } 라운드 소개 경유점 5개 (origin 로컬)
--   Art.BUDGET / LIGHTING / JUDGE_COLORS / KITCHEN_FLOOR_Y / STICK_LENGTH / STICK_HOVER
-- 층: FG 카운터 옻칠 테두리·접시 남색 테·젓가락 받침 / MG 요리사 쪽 재료 진열장·도마·손님 쪽 의자·찻잔·생강·와사비 /
--     BG 요리사 뒤 벽(술병 선반·노렌·메뉴 나무패)·천장 등불 줄·결승 너머 큰 계산대와 손 흔드는 복고양이.
-- 코스(밝은 히노키)는 공중에 뜬 판이고 양옆 장식은 높이가 달라요(요리사 쪽 +18, 손님 쪽 -22) — 걸을 수 있는 바닥처럼
-- 보이는 장식을 코스 옆 같은 높이에 두지 않아요(충돌 없는 장식에 속지 않게).

local Layout = require(script.Parent.SushiCounterCrossingLayout)
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
Art.STICK_LENGTH = 22 -- 내려찍는 젓가락 길이
Art.STICK_HOVER = 18 -- 경고 동안 젓가락 끝이 떠 있는 높이 (바닥 위)

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 치수 ────────────────────────────────────────────────────────────
Art.KITCHEN_FLOOR_Y = -70 -- 가게 바닥 (가장 낮은 낙하선 -12보다 58 아래)
Art.CHEF_LEDGE_Y = 18 -- 요리사 쪽 뒷선반 윗면 (점프로 못 올라가요)
Art.CHEF_X = -44 -- 뒷선반 안쪽 면
Art.BACK_WALL_X = -128
Art.STOOL_TOP_Y = -22 -- 손님 의자 윗면
Art.COURSE_BACK_Z = 30
Art.COURSE_END_Z = -560

-- ── 색 (60 히노키·짙은 나무 / 30 노렌 남색·도자기 흰색 / 10 옻칠 빨강·연어·계란·와사비) ───────────────
local HINOKI = MapKitLogic.shades(c(232, 196, 150))
local DARK_WOOD = MapKitLogic.shades(c(108, 72, 48))
local LACQUER = MapKitLogic.PALETTE.Lacquer
local LACQUER_DARK = MapKitLogic.PALETTE.LacquerDark
local NOREN = MapKitLogic.PALETTE.Noren
local NOREN_LIGHT = MapKitLogic.PALETTE.NorenLight
local PORCELAIN = MapKitLogic.PALETTE.Porcelain
local RIM = MapKitLogic.PALETTE.PorcelainRim
local PLASTER = MapKitLogic.shades(c(236, 226, 206))
local LANTERN = c(255, 214, 150)
local LANTERN_LIGHT = c(255, 196, 128)
local GLASS = c(210, 232, 240)
local SAKE_GREEN = c(70, 120, 84)
local SAKE_BROWN = c(120, 70, 40)
local SALMON = MapKitLogic.PALETTE.Salmon
local SALMON_LIGHT = MapKitLogic.PALETTE.SalmonLight
local TUNA = MapKitLogic.PALETTE.Tuna
local EGG = MapKitLogic.PALETTE.Egg
local RICE = MapKitLogic.PALETTE.Rice
local NORI = MapKitLogic.PALETTE.Nori
local WASABI = MapKitLogic.PALETTE.Wasabi
local GINGER = c(246, 186, 176)
local STOOL_RED = c(178, 52, 46)
local STEEL = c(150, 156, 164)
local FLOOR_TILE = MapKitLogic.shades(c(84, 70, 60))
local GOLD = c(222, 180, 80)

-- 판정 파츠 색 (SushiCounterCrossing.build가 써요). 밟는 곳이 가장 밝고 깨끗하게.
Art.JUDGE_COLORS = {
	counter = c(240, 214, 172), -- 광장·간장병 줄 (밝은 히노키)
	field = c(236, 208, 160), -- 젓가락 들판 (조금 진하게 — 빨간 원이 잘 보이게)
	railForward = c(92, 196, 184), -- 레일이 결승 쪽으로 밀 때 (청록)
	railBackward = c(240, 150, 110), -- 레일이 뒤로 밀 때 (연어색)
	plate = c(250, 250, 252), -- 접시 밟는 면
	register = c(228, 232, 238), -- 계산대 오르막·결승 (밝은 회백)
	receipt = c(244, 240, 228), -- 영수증 줄 쐐기
	receiptPaper = c(255, 254, 248), -- 영수증 종이 띠
	wall = c(150, 104, 66), -- 들판 낮은 벽
	bottle = c(70, 40, 28), -- 간장병 (짙은 갈색 유리)
	coin = c(232, 196, 92), -- 동전 더미
	warn = c(236, 52, 52), -- 젓가락 경고 원
	stick = c(196, 150, 96), -- 젓가락
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

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
end

-- 원기둥을 세워서 (축 Y)
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

-- ── FG: 카운터 몸통·옻칠 테두리 ─────────────────────────────────────
local function counterBody(list: { DecorSpec })
	-- 광장·들판·결승 아래 짙은 나무 몸통 (밟는 면 2 아래부터). 갈림길·오르막 사이 틈은 비워 둬서 아래가 보여요.
	local blocks = {
		{ name = "BodyStart", front = Layout.START.front + 8, back = Layout.START.back, top = Layout.LOW_Y },
		{ name = "BodyMerge", front = Layout.MERGE.front, back = Layout.FIELD.back, top = Layout.LOW_Y },
		{ name = "BodyFinish", front = Layout.FINISH.front, back = Layout.FINISH.back - 8, top = Layout.HIGH_Y },
	}
	for _, b in blocks do
		local depth = 30
		local top = b.top - Layout.FLOOR_THICKNESS
		put(
			list,
			b.name,
			"Block",
			v(Layout.WIDTH, depth, b.front - b.back),
			DARK_WOOD.base,
			"Wood",
			v(0, top - depth / 2, (b.front + b.back) / 2)
		)
		-- 옻칠 테두리 (밟는 면 바로 아래 앞뒤·양옆 띠)
		for _, side in { -1, 1 } do
			put(
				list,
				"LacquerEdge",
				"Block",
				v(1.2, 1.6, b.front - b.back),
				LACQUER,
				"SmoothPlastic",
				v(side * (Layout.HALF + 0.6), b.top - 1, (b.front + b.back) / 2),
				nil,
				{ reflectance = 0.12 }
			)
		end
		-- 몸통 옆면 나뭇결 판 (세로 줄무늬)
		local length = b.front - b.back
		local count = math.floor(length / 12)
		for i = 0, count - 1 do
			local z = b.front - 6 - i * 12
			for _, side in { -1, 1 } do
				put(
					list,
					"BodyPanel",
					"Block",
					v(0.6, depth - 6, 10.5),
					if i % 2 == 0 then DARK_WOOD.light else DARK_WOOD.base,
					"Wood",
					v(side * (Layout.HALF + 0.3), top - depth / 2, z)
				)
			end
		end
	end
	-- 갈림길 줄·오르막 줄 아래 받침 기둥 (가늘게, 낙하선보다 아래로 길게)
	local lw = Layout.LANE_WIDTH / 2
	for _, x in Layout.LANE_X do
		for z = Layout.LANES.front - 20, Layout.LANES.back + 20, -40 do
			put(list, "LaneBeam", "Block", v(lw * 2 - 2, 3, 3), DARK_WOOD.dark, "Wood", v(x, -4, z))
			upright(list, "LanePost", 60, 3, DARK_WOOD.base, "Wood", v(x, -36, z))
		end
	end
	for _, ramp in Layout.RAMP_LIST do
		for z = Layout.RAMPS.front - 30, Layout.RAMPS.back + 20, -40 do
			upright(list, "RampPost", 68, 3, DARK_WOOD.base, "Wood", v(ramp.x, -36, z)) -- 윗면 -2 (오르막 밑)
		end
	end
	-- 접시 남색 테 (판정 접시 바로 아래 얇은 링 — 밟는 면은 무늬 없이)
	for _, plate in Layout.PLATES do
		append(
			list,
			MapKitShapes.ring(
				"PlateRim",
				plate.radius + 0.3,
				0.6,
				0.4,
				12,
				RIM,
				"SmoothPlastic",
				v(plate.x, plate.top - 1.2, plate.z)
			)
		)
		upright(list, "PlateFoot", 10, 4, PORCELAIN, "SmoothPlastic", v(plate.x, plate.top - 7, plate.z))
	end
end

-- ── MG: 요리사 쪽 (왼쪽 높은 뒷선반 + 재료 진열장) ──────────────────────
local function chefSide(list: { DecorSpec })
	local ledgeDepth = 26
	local x0 = Art.CHEF_X - ledgeDepth / 2
	local length = Art.COURSE_BACK_Z - Art.COURSE_END_Z
	local midZ = (Art.COURSE_BACK_Z + Art.COURSE_END_Z) / 2
	-- 뒷선반 (윗면 18) + 몸통
	put(
		list,
		"ChefLedge",
		"Block",
		v(ledgeDepth, 4, length),
		HINOKI.dark,
		"WoodPlanks",
		v(x0, Art.CHEF_LEDGE_Y - 2, midZ)
	)
	put(
		list,
		"ChefCabinet",
		"Block",
		v(ledgeDepth, Art.CHEF_LEDGE_Y - 4 - Art.KITCHEN_FLOOR_Y, length),
		DARK_WOOD.base,
		"Wood",
		v(x0, (Art.CHEF_LEDGE_Y - 4 + Art.KITCHEN_FLOOR_Y) / 2, midZ)
	)
	-- 캐비닛 앞면 미닫이 문 (밝은 판 + 손잡이 홈) — 큰 어두운 면을 나눠요
	for z = Art.COURSE_BACK_Z - 15, Art.COURSE_END_Z + 15, -30 do
		put(list, "CabinetDoor", "Block", v(0.6, 40, 28), HINOKI.dark, "Wood", v(Art.CHEF_X + 0.3, -8, z))
		put(list, "CabinetPull", "Block", v(0.4, 6, 1.4), DARK_WOOD.dark, "Wood", v(Art.CHEF_X + 0.7, -8, z + 10))
	end
	-- 진열장 유리 + 그 안의 재료 (연어·참치·계란 덩어리, 얼음 깔개)
	for z = Art.COURSE_BACK_Z - 30, Art.COURSE_END_Z + 30, -60 do
		local cx = x0 + 2
		put(list, "NetaIce", "Block", v(16, 1, 52), c(220, 236, 244), "Ice", v(cx, Art.CHEF_LEDGE_Y + 0.5, z))
		local kinds = { SALMON, TUNA, EGG, SALMON_LIGHT }
		for k = 0, 3 do
			local color = kinds[(math.floor(-z / 60) + k) % #kinds + 1]
			put(
				list,
				"NetaBlock",
				"Block",
				v(10, 4, 9),
				color,
				"SmoothPlastic",
				v(cx, Art.CHEF_LEDGE_Y + 3, z + 18 - k * 12),
				v(0, (k % 2) * 6 - 3, 0)
			)
			put(
				list,
				"NetaStripe",
				"Block",
				v(10.2, 0.4, 1),
				c(255, 236, 220),
				"SmoothPlastic",
				v(cx, Art.CHEF_LEDGE_Y + 4.6, z + 18 - k * 12)
			)
		end
		put(
			list,
			"NetaGlass",
			"Block",
			v(0.4, 9, 56),
			GLASS,
			"Glass",
			v(Art.CHEF_X - 1, Art.CHEF_LEDGE_Y + 4.5, z),
			nil,
			{ transparency = 0.7, castShadow = false }
		)
		put(
			list,
			"NetaGlassTop",
			"Block",
			v(18, 0.4, 56),
			GLASS,
			"Glass",
			v(cx, Art.CHEF_LEDGE_Y + 9, z),
			v(0, 0, -8),
			{ transparency = 0.7, castShadow = false }
		)
		put(list, "NetaFrame", "Block", v(1, 9.5, 1), STEEL, "Metal", v(Art.CHEF_X - 1, Art.CHEF_LEDGE_Y + 4.7, z + 28))
		-- 도마와 큰 칼 (선반 위, 진열장 사이)
		put(
			list,
			"CuttingBoard",
			"Block",
			v(14, 1.6, 18),
			c(236, 220, 190),
			"Wood",
			v(x0 - 4, Art.CHEF_LEDGE_Y + 0.8, z - 30)
		)
		put(
			list,
			"KnifeBlade",
			"Block",
			v(2.4, 0.3, 14),
			c(214, 220, 226),
			"Metal",
			v(x0 - 4, Art.CHEF_LEDGE_Y + 1.8, z - 28),
			nil,
			{ reflectance = 0.35 }
		)
		put(
			list,
			"KnifeHandle",
			"Block",
			v(1.6, 1.2, 5),
			DARK_WOOD.dark,
			"Wood",
			v(x0 - 4, Art.CHEF_LEDGE_Y + 2.2, z - 37.5)
		)
	end
end

-- ── BG: 요리사 뒤 벽 (술병 선반·노렌·메뉴 나무패) ─────────────────────
local function backWall(list: { DecorSpec })
	local length = Art.COURSE_BACK_Z - Art.COURSE_END_Z
	local midZ = (Art.COURSE_BACK_Z + Art.COURSE_END_Z) / 2
	local height = 130
	put(
		list,
		"BackWall",
		"Block",
		v(4, height, length + 40),
		PLASTER.base,
		"Plaster",
		v(Art.BACK_WALL_X, Art.KITCHEN_FLOOR_Y + height / 2, midZ)
	)
	-- 나무 기둥과 가로 보 (벽을 칸으로 나눠요)
	for z = Art.COURSE_BACK_Z, Art.COURSE_END_Z, -80 do
		put(
			list,
			"WallPillar",
			"Block",
			v(5, height, 5),
			DARK_WOOD.dark,
			"Wood",
			v(Art.BACK_WALL_X + 3, Art.KITCHEN_FLOOR_Y + height / 2, z)
		)
	end
	for _, y in { 30, 52 } do
		put(list, "WallBeam", "Block", v(4, 3, length + 40), DARK_WOOD.base, "Wood", v(Art.BACK_WALL_X + 3, y, midZ))
	end
	-- 술병 선반 2단
	for i, shelfY in { 32, 54 } do
		put(list, "BottleShelf", "Block", v(10, 1.4, length), HINOKI.base, "Wood", v(Art.BACK_WALL_X + 7, shelfY, midZ))
		local z = Art.COURSE_BACK_Z - 10
		local k = 0
		while z > Art.COURSE_END_Z + 10 do
			local tall = (k + i) % 3 ~= 0
			local h = if tall then 14 else 9
			local color = if (k + i) % 2 == 0 then SAKE_GREEN else SAKE_BROWN
			upright(list, "SakeBottle", h, 4, color, "Glass", v(Art.BACK_WALL_X + 7, shelfY + 0.7 + h / 2, z), {
				reflectance = 0.15,
			})
			upright(list, "SakeNeck", 3, 1.6, color, "Glass", v(Art.BACK_WALL_X + 7, shelfY + 0.7 + h + 1.5, z))
			put(
				list,
				"SakeLabel",
				"Block",
				v(0.3, h * 0.45, 2.6),
				c(244, 236, 214),
				"SmoothPlastic",
				v(Art.BACK_WALL_X + 9.1, shelfY + 0.7 + h * 0.45, z)
			)
			z -= 7
			k += 1
		end
	end
	-- 노렌 (남색 천 3폭 + 흰 원 무늬), 메뉴 나무패
	for z = Art.COURSE_BACK_Z - 40, Art.COURSE_END_Z + 40, -80 do
		for k = -1, 1 do
			put(
				list,
				"Noren",
				"Block",
				v(0.5, 20, 9.2),
				if k == 0 then NOREN else NOREN_LIGHT,
				"Fabric",
				v(Art.BACK_WALL_X + 12, 74, z + k * 9.6),
				nil,
				{ anim = { kind = "Sway", period = 4 + k, amount = 3, axis = "Z" } }
			)
		end
		upright(list, "NorenMark", 0.3, 7, RICE, "SmoothPlastic", v(Art.BACK_WALL_X + 12.3, 76, z), nil)
		put(
			list,
			"NorenRod",
			"Cylinder",
			v(30, 1, 1),
			DARK_WOOD.dark,
			"Wood",
			v(Art.BACK_WALL_X + 12, 84.5, z),
			v(0, 90, 0)
		)
		for m = 0, 5 do
			put(
				list,
				"MenuPlaque",
				"Block",
				v(0.6, 12, 4),
				if m % 3 == 0 then c(236, 222, 190) else HINOKI.light,
				"Wood",
				v(Art.BACK_WALL_X + 2.4, 96, z - 22 + m * 6.5 + (if m >= 3 then 18 else 0))
			)
			put(
				list,
				"MenuInk",
				"Block",
				v(0.3, 8, 1),
				NORI,
				"SmoothPlastic",
				v(Art.BACK_WALL_X + 2.8, 96, z - 22 + m * 6.5 + (if m >= 3 then 18 else 0))
			)
		end
	end
end

-- ── 천장 등불 줄 (코스 위 높이 40 — 시야 상자보다 위) ──────────────────
local function lanterns(list: { DecorSpec })
	local lit = 0
	for z = Art.COURSE_BACK_Z - 30, Art.COURSE_END_Z + 30, -60 do
		for _, x in { -30, 30 } do
			local y = 50
			local useLight = lit < 18 and (math.floor(-z / 60) + (if x > 0 then 1 else 0)) % 2 == 0
			put(list, "Lantern", "Ball", v(9, 12, 9), LANTERN, "SmoothPlastic", v(x, y, z), nil, {
				light = if useLight
					then { kind = "Point", color = LANTERN_LIGHT, brightness = 1.6, range = 44 }
					else nil,
				anim = { kind = "Sway", period = 5 + (z % 3), amount = 3, axis = "X" },
			})
			if useLight then
				lit += 1
			end
			upright(list, "LanternCap", 1.4, 6, LACQUER_DARK, "SmoothPlastic", v(x, y + 6.4, z))
			upright(list, "LanternBase", 1.4, 6, LACQUER_DARK, "SmoothPlastic", v(x, y - 6.4, z))
			upright(list, "LanternCord", 30, 0.4, NORI, "Fabric", v(x, y + 22, z))
			upright(list, "LanternBand", 1.2, 9.3, LACQUER, "SmoothPlastic", v(x, y, z))
		end
	end
end

-- ── MG: 손님 쪽 (오른쪽 아래 — 빨간 의자·찻잔·생강·와사비) ─────────────
local function customerSide(list: { DecorSpec })
	local x = 62
	for z = Art.COURSE_BACK_Z - 20, Art.COURSE_END_Z + 20, -52 do
		upright(list, "StoolSeat", 4, 22, STOOL_RED, "Fabric", v(x, Art.STOOL_TOP_Y - 2, z))
		upright(list, "StoolRim", 1, 23, LACQUER_DARK, "SmoothPlastic", v(x, Art.STOOL_TOP_Y - 4.5, z))
		upright(
			list,
			"StoolLeg",
			Art.STOOL_TOP_Y - 5 - Art.KITCHEN_FLOOR_Y,
			4,
			STEEL,
			"Metal",
			v(x, (Art.STOOL_TOP_Y - 5 + Art.KITCHEN_FLOOR_Y) / 2, z),
			{ reflectance = 0.2 }
		)
		upright(list, "StoolFoot", 1.4, 16, STEEL, "Metal", v(x, Art.KITCHEN_FLOOR_Y + 0.7, z))
	end
	-- 손님 쪽 낮은 카운터 앞판 (코스 판 아래 -6 ~ -60, 코스 오른쪽 가장자리 너머 4)
	local length = Art.COURSE_BACK_Z - Art.COURSE_END_Z
	put(
		list,
		"CounterFront",
		"Block",
		v(3, 50, length),
		DARK_WOOD.base,
		"Wood",
		v(44, -32, (Art.COURSE_BACK_Z + Art.COURSE_END_Z) / 2)
	)
	-- 큰 찻잔(김) · 생강 · 와사비 · 간장 종지 — 의자 위 높이에 떠 있는 받침 접시 위
	local props = {
		{ z = -60, kind = "Tea" },
		{ z = -150, kind = "Ginger" },
		{ z = -260, kind = "Tea" },
		{ z = -330, kind = "Wasabi" },
		{ z = -430, kind = "Tea" },
	}
	for _, p in props do
		local px, py = 88, -16
		if p.kind == "Tea" then
			upright(list, "TeaCup", 16, 14, c(120, 140, 110), "SmoothPlastic", v(px, py, p.z))
			upright(list, "TeaCupBand", 2, 14.4, c(90, 104, 80), "SmoothPlastic", v(px, py + 5, p.z))
			upright(list, "Tea", 0.4, 12.4, c(150, 170, 70), "SmoothPlastic", v(px, py + 7.6, p.z), {
				particle = "Steam",
				particleRate = 4,
			})
		elseif p.kind == "Ginger" then
			upright(list, "GingerDish", 1.6, 22, PORCELAIN, "SmoothPlastic", v(px, py - 7, p.z))
			for k = 0, 5 do
				put(
					list,
					"GingerSlice",
					"Block",
					v(6, 0.6, 4),
					GINGER,
					"SmoothPlastic",
					v(px - 4 + k * 1.6, py - 5.6 + k * 0.5, p.z - 3 + (k % 3) * 2.5),
					v(0, k * 30, 10)
				)
			end
		else
			upright(list, "WasabiDish", 1.6, 18, PORCELAIN, "SmoothPlastic", v(px, py - 7, p.z))
			put(list, "WasabiMound", "Ball", v(10, 6, 8), WASABI, "SmoothPlastic", v(px, py - 4, p.z))
		end
	end
	-- 손님 쪽 창호지 벽 (빛이 은은하게 비쳐요)
	local wallX = 150
	local height = 110
	put(
		list,
		"ShojiWall",
		"Block",
		v(3, height, length + 40),
		PLASTER.light,
		"Plaster",
		v(wallX, Art.KITCHEN_FLOOR_Y + height / 2, (Art.COURSE_BACK_Z + Art.COURSE_END_Z) / 2)
	)
	local lamps = 0
	for z = Art.COURSE_BACK_Z - 30, Art.COURSE_END_Z + 30, -60 do
		local lit = lamps < 4 and math.floor(-z / 60) % 3 == 0
		put(list, "ShojiPanel", "Block", v(0.6, 36, 44), c(250, 244, 226), "SmoothPlastic", v(wallX - 1.8, 0, z), nil, {
			light = if lit
				then { kind = "Surface", color = c(255, 226, 180), brightness = 0.8, range = 16, face = "Left" }
				else nil,
		})
		if lit then
			lamps += 1
		end
		for k = -1, 1 do
			put(list, "ShojiBarV", "Block", v(0.8, 36, 0.8), DARK_WOOD.base, "Wood", v(wallX - 2.2, 0, z + k * 11))
			put(list, "ShojiBarH", "Block", v(0.8, 0.8, 44), DARK_WOOD.base, "Wood", v(wallX - 2.2, k * 9, z))
		end
		put(list, "ShojiFrame", "Block", v(1.2, 2, 46), DARK_WOOD.dark, "Wood", v(wallX - 2.2, 19, z))
		put(list, "ShojiFrame", "Block", v(1.2, 2, 46), DARK_WOOD.dark, "Wood", v(wallX - 2.2, -19, z))
	end

	-- 가게 바닥 타일
	local tile = 40
	for z = Art.COURSE_BACK_Z + 20, Art.COURSE_END_Z - 20, -tile do
		for x2 = -120, 140, tile do
			put(
				list,
				"FloorTile",
				"Block",
				v(tile - 0.4, 1, tile - 0.4),
				if (math.floor(z / tile) + math.floor(x2 / tile)) % 2 == 0 then FLOOR_TILE.base else FLOOR_TILE.dark,
				"Slate",
				v(x2, Art.KITCHEN_FLOOR_Y - 0.5, z - tile / 2)
			)
		end
	end
end

-- ── 들판 옆 젓가락 받침 · 결승 너머 큰 계산대 · 복고양이 ────────────────
local function landmarks(list: { DecorSpec })
	-- 들판 밖(벽 너머) 젓가락 받침과 쉬고 있는 젓가락 (요리사 쪽 선반 위)
	for _, z in { -270, -350 } do
		put(
			list,
			"Hashioki",
			"Block",
			v(6, 3, 10),
			c(110, 150, 180),
			"SmoothPlastic",
			v(Art.CHEF_X - 8, Art.CHEF_LEDGE_Y + 1.5, z)
		)
		put(
			list,
			"RestingStick",
			"Block",
			v(1.6, 1.6, 40),
			c(196, 150, 96),
			"Wood",
			v(Art.CHEF_X - 6, Art.CHEF_LEDGE_Y + 3.6, z - 6),
			v(0, 6, 0)
		)
		put(
			list,
			"RestingStick",
			"Block",
			v(1.6, 1.6, 40),
			c(196, 150, 96),
			"Wood",
			v(Art.CHEF_X - 10, Art.CHEF_LEDGE_Y + 3.6, z - 6),
			v(0, -6, 0)
		)
	end
	-- 큰 계산대 (결승 너머)
	local rz = Art.COURSE_END_Z + 6
	put(
		list,
		"Register",
		"Block",
		v(60, 34, 26),
		c(196, 60, 52),
		"SmoothPlastic",
		v(0, Layout.HIGH_Y + 17 - 2, rz),
		nil,
		{ reflectance = 0.08 }
	)
	put(
		list,
		"RegisterTop",
		"Wedge",
		v(60, 12, 26),
		c(170, 44, 40),
		"SmoothPlastic",
		v(0, Layout.HIGH_Y + 38, rz),
		v(0, 180, 0)
	)
	put(
		list,
		"RegisterScreen",
		"Block",
		v(30, 9, 1),
		c(40, 52, 60),
		"SmoothPlastic",
		v(0, Layout.HIGH_Y + 50, rz - 6),
		v(-10, 0, 0),
		{
			light = { kind = "Surface", color = c(140, 255, 180), brightness = 1.2, range = 12, face = "Back" },
		}
	)
	put(
		list,
		"RegisterDisplay",
		"Block",
		v(24, 4, 0.4),
		c(120, 240, 160),
		"Neon",
		v(0, Layout.HIGH_Y + 50, rz - 5.4),
		v(-10, 0, 0)
	)
	for row = 0, 2 do
		for col = 0, 4 do
			put(
				list,
				"RegisterKey",
				"Block",
				v(6, 2, 4),
				if (row + col) % 3 == 0 then GOLD else c(236, 230, 214),
				"SmoothPlastic",
				v(-14 + col * 7, Layout.HIGH_Y + 33 + row * 1.6, rz + 2 + row * 4.6),
				v(-24, 0, 0)
			)
		end
	end
	put(list, "CashDrawer", "Block", v(52, 8, 2), c(150, 40, 36), "SmoothPlastic", v(0, Layout.HIGH_Y + 5, rz + 13.2))
	-- 복고양이 (계산대 옆, 손 흔들기)
	local cx, cz = 42, rz + 4
	local by = Layout.HIGH_Y - 2
	put(list, "LuckyCatBody", "Ball", v(18, 22, 16), RICE, "SmoothPlastic", v(cx, by + 11, cz))
	put(list, "LuckyCatHead", "Ball", v(18, 16, 15), RICE, "SmoothPlastic", v(cx, by + 28, cz))
	for _, side in { -1, 1 } do
		put(
			list,
			"LuckyCatEar",
			"Wedge",
			v(1.4, 6, 5),
			RICE,
			"SmoothPlastic",
			v(cx + side * 5.5, by + 36.5, cz),
			v(0, 90, 0)
		)
		put(list, "LuckyCatEye", "Ball", v(1.6, 2.4, 1), NORI, "SmoothPlastic", v(cx + side * 3.4, by + 29, cz + 7.2))
		put(
			list,
			"LuckyCatEarInner",
			"Wedge",
			v(1, 4, 3),
			c(246, 170, 170),
			"SmoothPlastic",
			v(cx + side * 5.5, by + 35.8, cz + 0.8),
			v(0, 90, 0)
		)
		put(
			list,
			"LuckyCatCheek",
			"Ball",
			v(2.4, 1.6, 1),
			c(246, 170, 170),
			"SmoothPlastic",
			v(cx + side * 5.2, by + 26.4, cz + 6.6)
		)
	end
	put(list, "LuckyCatNose", "Ball", v(1.4, 1, 1), c(236, 120, 120), "SmoothPlastic", v(cx, by + 27, cz + 7.6))
	put(list, "LuckyCatCollar", "Cylinder", v(2, 15, 15), LACQUER, "SmoothPlastic", v(cx, by + 20.5, cz), v(0, 0, 90))
	put(
		list,
		"LuckyCatBell",
		"Ball",
		v(3.2, 3.2, 3.2),
		GOLD,
		"Metal",
		v(cx, by + 19, cz + 7.4),
		nil,
		{ reflectance = 0.3 }
	)
	put(list, "LuckyCatCoin", "Block", v(8, 10, 1.4), GOLD, "Metal", v(cx, by + 10, cz + 8), nil, { reflectance = 0.3 })
	put(list, "LuckyCatPaw", "Ball", v(5, 9, 5), RICE, "SmoothPlastic", v(cx - 9, by + 30, cz + 2), nil, {
		anim = { kind = "Sway", period = 1.6, amount = 14, axis = "Z" },
	})
	-- 결승 꽃가루
	for _, x in { -38, 38 } do
		put(
			list,
			"FinishPost",
			"Block",
			v(3, 18, 3),
			LACQUER,
			"SmoothPlastic",
			v(x, Layout.HIGH_Y + 9, Layout.FINISH_LINE_Z - 4),
			nil,
			{
				particle = "Confetti",
				particleRate = 6,
			}
		)
	end
	put(
		list,
		"FinishBanner",
		"Block",
		v(78, 4, 0.6),
		c(246, 236, 210),
		"Fabric",
		v(0, Layout.HIGH_Y + 16, Layout.FINISH_LINE_Z - 4)
	)
	put(
		list,
		"FinishBannerBand",
		"Block",
		v(78, 1, 0.7),
		LACQUER,
		"Fabric",
		v(0, Layout.HIGH_Y + 14.2, Layout.FINISH_LINE_Z - 4)
	)
end

-- ── 출발 뒤 노렌 문 (출발 광장 너머) ────────────────────────────────────
local function entrance(list: { DecorSpec })
	local z = Art.COURSE_BACK_Z
	put(list, "EntranceBeam", "Block", v(80, 4, 4), DARK_WOOD.dark, "Wood", v(0, 34, z))
	for _, x in { -38, 38 } do
		put(list, "EntrancePost", "Block", v(4, 40, 4), DARK_WOOD.dark, "Wood", v(x, 14, z))
	end
	for k = -3, 3 do
		put(
			list,
			"EntranceNoren",
			"Block",
			v(10.6, 14, 0.4),
			if k % 2 == 0 then NOREN else NOREN_LIGHT,
			"Fabric",
			v(k * 11, 25, z - 1),
			nil,
			{
				anim = { kind = "Sway", period = 3.5 + (k % 2), amount = 4, axis = "X" },
			}
		)
	end
	upright(list, "EntranceMark", 0.3, 10, RICE, "SmoothPlastic", v(0, 25, z - 1.4))
	put(list, "EntranceLamp", "Ball", v(6, 8, 6), LANTERN, "SmoothPlastic", v(-38, 34, z - 4), nil, {
		light = { kind = "Point", color = LANTERN_LIGHT, brightness = 1.4, range = 30 },
	})
	put(list, "EntranceLamp", "Ball", v(6, 8, 6), LANTERN, "SmoothPlastic", v(38, 34, z - 4), nil, {
		light = { kind = "Point", color = LANTERN_LIGHT, brightness = 1.4, range = 30 },
	})
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	counterBody(list)
	chefSide(list)
	backWall(list)
	lanterns(list)
	customerSide(list)
	landmarks(list)
	entrance(list)
	-- 그림자 조명 1개: 결승 계산대를 비추는 좁은 스포트 (천장)
	put(list, "RegisterSpot", "Block", v(4, 2, 4), NORI, "Metal", v(0, 60, Layout.FINISH_LINE_Z + 10), nil, {
		light = {
			kind = "Spot",
			color = c(255, 226, 180),
			brightness = 2,
			range = 60,
			angle = 50,
			face = "Bottom",
			shadows = true,
		},
	})
	return list
end

Art.LIGHTING = {
	ClockTime = 18.4,
	Brightness = 1.3,
	Ambient = c(150, 122, 104),
	OutdoorAmbient = c(160, 130, 112),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.6,
	ShadowSoftness = 0.4,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.1,
		Color = c(214, 176, 140),
		Decay = c(120, 80, 70),
		Glare = 0.2,
		Haze = 1.2,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.1,
		TintColor = c(255, 244, 232),
	},
	Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.1 },
} :: MapLighting.MapLighting

-- 장식이 들어가면 안 되는 코스 시야 상자 (밟는 면 위 2 ~ 12)
function Art.courseVolume(): { Bounds }
	local list: { Bounds } = {}
	local function box(minX: number, maxX: number, minZ: number, maxZ: number, floorY: number)
		table.insert(list, { min = v(minX, floorY + 2, minZ), max = v(maxX, floorY + 12, maxZ) })
	end
	for _, rect in Layout.floorRects() do
		box(rect.minX, rect.maxX, rect.minZ, rect.maxZ, rect.top)
	end
	for _, plate in Layout.PLATES do
		box(plate.x - plate.radius, plate.x + plate.radius, plate.z - plate.radius, plate.z + plate.radius, plate.top)
	end
	-- 가운데 줄 전체 (접시 사이로 뛰어다니는 공간)
	box(-Layout.LANE_WIDTH / 2, Layout.LANE_WIDTH / 2, Layout.LANES.back, Layout.LANES.front, Layout.LOW_Y)
	-- 오르막 (높은 쪽 기준)
	for _, ramp in Layout.RAMP_LIST do
		local w = Layout.RAMP_WIDTH / 2
		box(ramp.x - w, ramp.x + w, Layout.RAMP_SLOPE.back, Layout.RAMP_SLOPE.front, Layout.HIGH_Y)
		box(ramp.x - w, ramp.x + w, Layout.RAMP_SLOPE.back, Layout.RAMP_SLOPE.front, Layout.LOW_Y)
	end
	return list
end

-- 소개 카메라: ① 출발 문 너머 전체 → ② 세 갈래 길 → ③ 젓가락 들판 위 → ④ 계산대 오르막과 복고양이 → ⑤ 출발 자리
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-30, 60, 40), lookAt = v(0, 0, -200) },
		{ pos = v(0, 30, -30), lookAt = v(0, 0, -140) },
		{ pos = v(30, 40, -230), lookAt = v(0, 0, -320) },
		{ pos = v(8, 30, -436), lookAt = v(12, 22, -545) },
		{ pos = v(0, 14, 24), lookAt = v(0, 3, -40) },
	}
end

return Art
