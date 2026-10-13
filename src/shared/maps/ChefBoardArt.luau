--!strict
-- "셰프의 도마"(chef-board, m4-05) 아트의 순수 데이터. Roblox 자료형을 쓰지 않아요 (lune 테스트).
-- 좌표는 도마 중심(origin) 기준 로컬, 도마 윗면 = y 0. 공통 규칙은 docs/specs/m4-02 "공통 규칙".
--   Art.decor()                 고정 장식 (손님 얼굴, 주방 배경, 조명) — MapKit.buildDecor(…, Decor 폴더)
--   Art.cellDecor(cell, board)  칸 하나에 붙는 칼자국 장식 (칸 파츠 자식으로 만들어 같이 기울고 떨어져요)
--   Art.cellColor(i, j)         칸 나무색 (가장자리 칸은 조금씩 달라요)
--   Art.introCamera()           IntroCamera 경유점 3개
--   Art.courseVolume()          장식이 들어가면 안 되는 시야 상자 (도마 윗면 위 2~12, 도마 반지름 안)
--   Art.KNIFE                   칼·팔 색 (ChefBoard.build가 써요)
--   Art.BUDGET / Art.LIGHTING   m5-24 Extended 예산, 맵 조명 (ChefBoard.lighting)
--   Art.CODE_EXTRAS             ChefBoard.build가 Instance.new로 붙이는 조명·파티클 수 (예산 검사용)

local Logic = require(script.Parent.ChefBoardLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type RGB = MapKitLogic.RGB
type Vec3 = MapKitLogic.Vec3

local PALETTE = MapKitLogic.PALETTE

local Art = {}

Art.BUDGET = "Extended" :: MapKitLogic.BudgetTier -- m5-24 (장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
-- ChefBoard.build가 Instance.new로 따로 붙이는 것: LampBulb PointLight 3, 칼날 불꽃(one-shot) 1
Art.CODE_EXTRAS = { lights = 3, particles = 1 }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 타입을 정한 인자로 넣어야 shape 같은 문자열이 리터럴 타입으로 잡혀요 (타입 검사)
local function add(specs: { DecorSpec }, spec: DecorSpec)
	table.insert(specs, spec)
end

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

Art.KNIFE = {
	blade = rgb(205, 210, 216),
	edge = rgb(240, 242, 246),
	handle = rgb(28, 28, 30),
	rivet = rgb(180, 180, 186),
	sleeve = PALETTE.Rice,
	skin = rgb(240, 200, 170),
	warn = rgb(230, 40, 40),
}

-- 아침 손질 시간 (m5-23 PRESETS["chef-board"]에서 시작): 차가운 청회색 창빛 + 따뜻한 등 3개
Art.LIGHTING = {
	ClockTime = 9,
	Brightness = 2.2,
	Ambient = { r = 98, g = 108, b = 122 },
	OutdoorAmbient = { r = 136, g = 148, b = 166 },
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.2,
		Offset = 0.05,
		Color = { r = 196, g = 210, b = 222 },
		Decay = { r = 120, g = 132, b = 150 },
		Glare = 0.1,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.02,
		TintColor = { r = 242, g = 248, b = 255 },
	},
	Bloom = { Intensity = 0.35, Size = 22, Threshold = 1.4 },
	SunRays = { Intensity = 0.05, Spread = 0.6 },
} :: MapLighting.LightingPreset

-- m5-20 파티클·조명·안개 이름 상수
Art.LAMP_BULB = "LampBulb"
Art.KNIFE_SPARK = "KnifeSpark"
Art.FOG_PANEL = "FogPanel"
local FOG: RGB = { r = 150, g = 170, b = 190 } -- 주방 차가운 청회색 (m5-20 ③)

local GROOVE = rgb(122, 86, 52) -- 칼자국 (진한 나무)
local EDGE_TRIM = rgb(140, 96, 58) -- 도마 옆면 트림 (m5-24)
local GROOVE_WIDTH = 0.35
local GROOVE_HEIGHT = 0.06

-- 칸 나무색: 밝은 나무, 가장자리 칸은 조각마다 조금 다른 결
function Art.cellColor(i: number, j: number): RGB
	local base = PALETTE.Wood
	local ring = math.max(math.abs(i), math.abs(j))
	local variant = (i * 7 + j * 13) % 3 -- 음수여도 Luau %는 0~2
	local shift = if ring >= 3 then (variant - 1) * 10 else 0
	local lighten = 28 - ring * 3
	local function clamp(n: number): number
		return math.clamp(n, 0, 255)
	end
	return rgb(clamp(base.r + lighten + shift), clamp(base.g + lighten + shift), clamp(base.b + lighten + shift // 2))
end

-- 칸 하나의 칼자국: 오른쪽(+X)·앞쪽(+Z)에 이웃 칸이 있으면 경계 홈, 몇몇 칸엔 비스듬한 긁힘 하나.
-- 오프셋은 도마 중심 기준 (칸 중심 + 칸 안 위치). 칸 윗면 바로 위 0.06 두께라 밟는 높이는 그대로예요.
function Art.cellDecor(cell: Logic.Cell, hasNeighbor: (i: number, j: number) -> boolean): { DecorSpec }
	local specs: { DecorSpec } = {}
	local size = Logic.CELL_SIZE
	local y = GROOVE_HEIGHT / 2
	if hasNeighbor(cell.i + 1, cell.j) then
		add(specs, {
			name = "Groove",
			shape = "Block",
			size = v(GROOVE_WIDTH, GROOVE_HEIGHT, size),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x + size / 2, y, cell.z),
		})
	end
	if hasNeighbor(cell.i, cell.j + 1) then
		add(specs, {
			name = "Groove",
			shape = "Block",
			size = v(size, GROOVE_HEIGHT, GROOVE_WIDTH),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x, y, cell.z + size / 2),
		})
	end
	-- m5-24: 바깥 칸의 옆면 트림 (짙은 나무 띠, 칸 자식이라 같이 기울고 떨어져요 — anim 없음).
	-- 윗면보다 0.3 아래, 바깥으로 0.25 — 밟는 면은 그대로이고 도마 두께가 읽혀요.
	local half = size / 2
	local thick = Logic.BOARD_THICKNESS
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if not hasNeighbor(cell.i + d[1], cell.j + d[2]) then
			local alongX = d[2] ~= 0
			add(specs, {
				name = "EdgeTrim",
				shape = "Block",
				size = if alongX then v(size, thick - 0.6, 0.5) else v(0.5, thick - 0.6, size),
				color = EDGE_TRIM,
				material = "Wood",
				offset = v(cell.x + d[1] * (half + 0.25), -0.3 - (thick - 0.6) / 2, cell.z + d[2] * (half + 0.25)),
			})
		end
	end
	if (cell.i * 3 + cell.j * 5) % 4 == 0 then
		add(specs, {
			name = "Scratch",
			shape = "Block",
			size = v(4.5, GROOVE_HEIGHT, 0.2),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x + 0.5, y, cell.z - 1),
			rotation = v(0, 25 + ((cell.i + cell.j) % 3) * 20, 0),
		})
	end
	return specs
end

-- 구 위의 한 점 (중심 c, 반지름 r, 방향 d — 정규화해요)
local function onSphere(c: Vec3, r: number, dx: number, dy: number, dz: number): Vec3
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	return v(c.x + dx / len * r, c.y + dy / len * r, c.z + dz / len * r)
end

-- 도마 아래에서 위를 보고 입을 벌린 손님 얼굴 (탈락 연출 "손님 입"과 같은 표현).
-- 머리 꼭대기가 탈락 높이(-30)보다 아래라 떨어지는 사람과 겹쳐도 판정과 무관해요 (장식은 충돌 없음).
local function customerFace(specs: { DecorSpec }, cx: number, cy: number, cz: number, skin: RGB)
	local radius = 11
	local c = v(cx, cy, cz)
	add(specs, {
		name = "CustomerHead",
		shape = "Ball",
		size = v(radius * 2, radius * 2, radius * 2),
		color = skin,
		material = "SmoothPlastic",
		offset = c,
	})
	local len = math.sqrt(cx * cx + cz * cz)
	local tx, tz = -cx / len, -cz / len -- 도마 중심 쪽 (수평 단위). 얼굴은 위를 보고 턱(입)이 이쪽
	local sx, sz = -tz, tx -- 얼굴 옆 방향
	for _, side in { -1, 1 } do
		local ex, ez = -tx * 0.45 + sx * side * 0.4, -tz * 0.45 + sz * side * 0.4
		add(specs, {
			name = "CustomerEye",
			shape = "Ball",
			size = v(3.4, 3.4, 3.4),
			color = PALETTE.Rice,
			material = "SmoothPlastic",
			offset = onSphere(c, radius - 0.8, ex, 1, ez),
		})
		add(specs, {
			name = "CustomerPupil",
			shape = "Ball",
			size = v(1.6, 1.6, 1.6),
			color = PALETTE.Nori,
			material = "SmoothPlastic",
			offset = onSphere(c, radius + 0.6, ex, 1, ez),
		})
		add(specs, {
			name = "CustomerCheek",
			shape = "Ball",
			size = v(3, 1.2, 3),
			color = rgb(240, 140, 140),
			material = "SmoothPlastic",
			offset = onSphere(c, radius - 0.3, tx * 0.3 + sx * side * 0.75, 1, tz * 0.3 + sz * side * 0.75),
		})
	end
	-- m5-24: 머리만 떠 있지 않게 어깨 (이름이 "Customer"로 시작하지 않아요 — 얼굴 높이 테스트는 머리만)
	local yaw = math.deg(math.atan2(-cz, cx)) + 90 -- 캡슐 축(X)이 얼굴 옆 방향으로
	for _, spec in
		MapKitShapes.capsule(
			"DinerShoulders",
			30,
			14,
			rgb(70, 86, 110),
			"Fabric",
			v(cx * 1.12, -63, cz * 1.12),
			v(0, yaw, 0)
		)
	do
		add(specs, spec)
	end
	-- 벌린 입 (어두운 원판, 위를 봄) + 혀
	local mouth = onSphere(c, radius - 0.4, tx * 0.5, 1, tz * 0.5)
	add(specs, {
		name = "CustomerMouth",
		shape = "Cylinder",
		size = v(1, 8, 8),
		color = rgb(60, 18, 24),
		material = "SmoothPlastic",
		offset = mouth,
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "CustomerTongue",
		shape = "Ball",
		size = v(4, 1.4, 3.4),
		color = rgb(220, 90, 100),
		material = "SmoothPlastic",
		offset = v(mouth.x + tx * 1.5, mouth.y + 0.4, mouth.z + tz * 1.5),
	})
end

---------------------------------------------------------------------------------- m5-24 세계
-- 도마는 나무 받침 기둥 위에 있고, 그 아래(낙하선 -30보다 40 아래) 스테인리스 작업대가 방을 채워요.
-- 방은 청회색 타일 벽(±ROOM) + -Z 벽의 큰 창(차가운 아침빛) + 선반·시계·주문표. 히어로: ① 칼(판정, 그대로)
-- ② 반쯤 손질된 거대 연어(생선 상자 위) ③ 칼꽂이·숫돌 ④ 매달린 등 3개(LampBulb) ⑤ 창문 + 허브 화분.

local function part(
	specs: { DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): DecorSpec
	local spec: DecorSpec = {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
	table.insert(specs, spec)
	return spec
end

local function append(specs: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(specs, s)
	end
end

local UP: Vec3 = { x = 0, y = 0, z = 90 } -- 원기둥 축(X)을 세워요

-- 세운 원기둥 (높이 h, 지름 d, 바닥 y)
local function disc(
	specs: { DecorSpec },
	name: string,
	h: number,
	d: number,
	color: RGB,
	material: string,
	x: number,
	y: number,
	z: number
): DecorSpec
	return part(specs, name, "Cylinder", v(h, d, d), color, material, v(x, y + h / 2, z), UP)
end

Art.TABLE_Y = -70 -- 스테인리스 작업대 윗면 (낙하선 -30보다 40 아래)
local TABLE_Y = Art.TABLE_Y
Art.ROOM = 300 -- 방 벽까지 (도마 중심 기준, 가이드 2절 배경 벽 150~400)
local ROOM = Art.ROOM
local CEILING_Y = 220
local STEEL: RGB = rgb(138, 146, 154) -- 작업대 스테인리스 (도마보다 어둡게 — 바닥 가독성)
local TILE: RGB = rgb(150, 170, 184) -- 차가운 청회색 타일
local PLASTER: RGB = rgb(200, 206, 210)
local WOOD_DARK = PALETTE.WoodDark
local TERRACOTTA: RGB = rgb(188, 104, 70)
local HERB: RGB = rgb(84, 150, 70)
local WINDOW_LIGHT: RGB = rgb(214, 232, 248)
local WINDOW = { x = -40, y = 80, w = 220, h = 140 }

-- 작업대 + 방 벽 + 창 (BG)
local function room(specs: { DecorSpec })
	-- 작업대 상판: 판 세 장, shade 셋, 살짝 반사
	local slabShades = { STEEL, MapKitLogic.shade(STEEL, 0.9), MapKitLogic.shade(STEEL, 1.08) }
	local w = 2 * ROOM / 3
	for i = 0, 2 do
		local slab = part(
			specs,
			"SteelTable",
			"Block",
			v(w, 6, 2 * ROOM),
			slabShades[i + 1],
			"Metal",
			v(-ROOM + w / 2 + i * w, TABLE_Y - 3, 0)
		)
		slab.reflectance = 0.18
		slab.castShadow = false
		if i > 0 then
			part(
				specs,
				"SteelSeam",
				"Block",
				v(0.6, 0.2, 2 * ROOM),
				MapKitLogic.shade(STEEL, 0.6),
				"Metal",
				v(-ROOM + i * w, TABLE_Y + 0.05, 0)
			).castShadow =
				false
		end
	end
	-- 벽: 아래 타일 + 위 회반죽 + 스테인리스 가로대 + 짙은 타일 띠
	local tileTop = 40
	local function wall(x: number, z: number, sx: number, sz: number, tint: number)
		local along = sx > sz
		local tileH = tileTop - (TABLE_Y - 10)
		part(
			specs,
			"TileWall",
			"Block",
			v(sx, tileH, sz),
			MapKitLogic.shade(TILE, tint),
			"CeramicTiles",
			v(x, TABLE_Y - 10 + tileH / 2, z)
		).castShadow =
			false
		local plasterH = CEILING_Y - tileTop
		part(
			specs,
			"PlasterWall",
			"Block",
			v(sx, plasterH, sz),
			MapKitLogic.shade(PLASTER, tint),
			"Plaster",
			v(x, tileTop + plasterH / 2, z)
		).castShadow =
			false
		local inX = if along then x else x - math.sign(x) * 3.5
		local inZ = if along then z - math.sign(z) * 3.5 else z
		part(
			specs,
			"WallRail",
			"Block",
			v(if along then sx else 3, 3, if along then 3 else sz),
			STEEL,
			"Metal",
			v(inX, tileTop, inZ)
		).reflectance =
			0.25
		part(
			specs,
			"TileBand",
			"Block",
			v(if along then sx else 1, 6, if along then 1 else sz),
			MapKitLogic.shade(TILE, tint * 0.7),
			"CeramicTiles",
			v(if along then x else x - math.sign(x) * 3, TABLE_Y + 8, if along then z - math.sign(z) * 3 else z)
		).castShadow =
			false
	end
	wall(0, -ROOM, 2 * ROOM, 6, 1)
	wall(0, ROOM, 2 * ROOM, 6, 0.92)
	wall(-ROOM, 0, 6, 2 * ROOM, 0.96)
	wall(ROOM, 0, 6, 2 * ROOM, 0.88)
	-- 천장 들보 (등·작업등·냄비 걸이 줄이 매달린 곳). 천장 판은 없어요 — overview가 위에서 보니까
	for _, bz in { -30, 10, 30 } do
		append(
			specs,
			MapKitShapes.bevelBox(
				"CeilingBeam",
				v(2 * ROOM, 10, 8),
				PALETTE.WoodDark,
				"Wood",
				v(0, CEILING_Y + 5, bz),
				1,
				v(180, 0, 0)
			)
		)
	end
	-- -Z 벽 큰 창 (차가운 아침빛, Neon) + 나무 틀 + 창살
	local wz = -ROOM + 3.5
	local wx, wy, ww, wh = WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h
	part(specs, "Window", "Block", v(ww, wh, 1), WINDOW_LIGHT, "Neon", v(wx, wy, wz)).castShadow = false
	part(specs, "WindowFrame", "Block", v(ww + 10, 5, 3), WOOD_DARK, "Wood", v(wx, wy + wh / 2 + 2.5, wz + 1))
	part(specs, "WindowFrame", "Block", v(ww + 10, 5, 3), WOOD_DARK, "Wood", v(wx, wy - wh / 2 - 2.5, wz + 1))
	part(specs, "WindowFrame", "Block", v(5, wh, 3), WOOD_DARK, "Wood", v(wx - ww / 2 - 2.5, wy, wz + 1))
	part(specs, "WindowFrame", "Block", v(5, wh, 3), WOOD_DARK, "Wood", v(wx + ww / 2 + 2.5, wy, wz + 1))
	part(specs, "WindowMullion", "Block", v(3, wh, 3), WOOD_DARK, "Wood", v(wx, wy, wz + 1.5))
	part(specs, "WindowMullion", "Block", v(ww, 3, 3), WOOD_DARK, "Wood", v(wx, wy, wz + 1.5))
	-- 창틀 아래 선반 (허브 화분이 올라가요)
	append(
		specs,
		MapKitShapes.bevelBox(
			"WindowSill",
			v(ww + 20, 4, 18),
			PALETTE.WoodLight,
			"Wood",
			v(wx, wy - wh / 2 - 7, wz + 9),
			1.2
		)
	)
	-- 작업대 위 판 몇 장 (큰 평면이 한 색으로 보이지 않게, 소품 무리 밑받침): 고무 도마 매트·쟁반
	local mats = {
		{ x = -84, z = -60, sx = 70, sz = 60, c = rgb(96, 120, 104), r = 6 },
		{ x = 84, z = 100, sx = 90, sz = 70, c = rgb(112, 120, 128), r = -4 },
		{ x = -120, z = 80, sx = 150, sz = 90, c = rgb(104, 110, 116), r = 0 },
	}
	for _, m in mats do
		part(specs, "TableMat", "Block", v(m.sx, 0.3, m.sz), m.c, "Rubber", v(m.x, TABLE_Y + 0.15, m.z), v(0, m.r, 0)).castShadow =
			false
	end
	-- 창빛 먼지 (햇살 Dust 두 덩이)
	for k = 0, 1 do
		local dust = part(
			specs,
			"WindowDust",
			"Block",
			v(60, 50, 30),
			WINDOW_LIGHT,
			"SmoothPlastic",
			v(wx - 35 + k * 70, wy, wz + 34)
		)
		dust.transparency = 1
		dust.castShadow = false
		dust.particle = "Dust"
		dust.particleRate = 6
	end
end

-- ⑤ 허브 화분 3개 (창틀 위, 잎이 살랑)
local function herbs(specs: { DecorSpec })
	local sillTop = WINDOW.y - WINDOW.h / 2 - 5
	local z = -ROOM + 12
	for k = 0, 2 do
		local x = WINDOW.x - 55 + k * 55
		local h = 16 + (k % 2) * 4
		append(
			specs,
			MapKitShapes.rimDisc(
				"HerbPot",
				16 - k,
				h,
				MapKitLogic.shade(TERRACOTTA, 0.9 + k * 0.08),
				"Plastic",
				v(x, sillTop + h / 2, z),
				{ rimColor = MapKitLogic.shade(TERRACOTTA, 0.7), rimWidth = 1.2, rimHeight = 2, segments = 12 }
			)
		)
		disc(specs, "HerbSoil", 0.6, 13 - k, rgb(70, 50, 36), "Sand", x, sillTop + h - 0.4, z)
		for leaf = 0, 4 do
			local a = math.rad(leaf * 72 + k * 20)
			local spec = part(
				specs,
				"HerbLeaf",
				"Ball",
				v(5, 9 + (leaf % 2) * 3, 3),
				MapKitLogic.shade(HERB, 0.85 + (leaf % 3) * 0.12),
				"SmoothPlastic",
				v(x + math.cos(a) * 3.5, sillTop + h + 5 + (leaf % 2) * 2, z + math.sin(a) * 3.5),
				v(0, leaf * 72, (leaf % 2) * 14 - 7)
			)
			if leaf < 2 then
				spec.anim = { kind = "Sway", period = 4 + k * 0.7 + leaf, amount = 7 }
			end
		end
	end
end

-- 도마 받침 기둥 (도마가 떠 있지 않게). 지름 16·덮개 22 — 가운데 3×3(보호 칸, ±12) 안이라 잘린 칸 자리로 안 보여요.
local function boardStand(specs: { DecorSpec })
	local top = -Logic.BOARD_THICKNESS - 3 -- 기울어도 (반지름 11 × sin 8° ≈ 1.5) 도마 밑면에 안 닿게
	disc(specs, "BoardStand", top - 2 - (TABLE_Y + 4), 16, WOOD_DARK, "Wood", 0, TABLE_Y + 4, 0)
	append(
		specs,
		MapKitShapes.rimDisc(
			"BoardStandCap",
			22,
			2,
			PALETTE.WoodLight,
			"Wood",
			v(0, top - 1, 0),
			{ rimColor = WOOD_DARK, rimWidth = 1, rimHeight = 0.6, segments = 14 }
		)
	)
	append(
		specs,
		MapKitShapes.rimDisc(
			"BoardStandFoot",
			34,
			4,
			MapKitLogic.shade(WOOD_DARK, 0.85),
			"Wood",
			v(0, TABLE_Y + 2, 0),
			{ rimColor = STEEL, rimWidth = 1, rimHeight = 1, segments = 16 }
		)
	)
	disc(specs, "BoardStandBand", 3, 16.8, Art.KNIFE.rivet, "Metal", 0, -30, 0).reflectance = 0.3
end

-- ② 반쯤 손질된 거대 연어 (흰 생선 상자 + 얼음 위)
local function salmon(specs: { DecorSpec })
	local cx, cz = 92, -58
	local boxTop = TABLE_Y + 30
	append(
		specs,
		MapKitShapes.roundedBox(
			"FishCrate",
			v(96, 30, 52),
			rgb(236, 242, 246),
			"SmoothPlastic",
			v(cx, TABLE_Y + 15, cz),
			{ radius = 3, rotation = v(0, 8, 0) }
		)
	)
	part(
		specs,
		"FishCrateBand",
		"Block",
		v(97, 3, 53),
		PALETTE.PorcelainRim,
		"SmoothPlastic",
		v(cx, boxTop - 5, cz),
		v(0, 8, 0)
	)
	-- 얼음 (작은 반투명 덩어리, 무리)
	append(
		specs,
		MapKitShapes.scatter(24, 18, { center = v(cx, boxTop + 1, cz), size = v(84, 0, 40) }, function(_i, pos, r)
			local s = r:range(3, 6)
			local ice: DecorSpec = {
				name = "FishIce",
				shape = "Block",
				size = v(s, s * 0.7, s),
				color = PALETTE.IceBlue,
				material = "Glass",
				offset = pos,
				rotation = v(r:range(0, 40), r:range(0, 90), r:range(0, 40)),
				transparency = 0.35,
				reflectance = 0.15,
			}
			return { ice }
		end)
	)
	-- 연어: 은빛 몸통(캡슐) + 등(짙은 캡슐) + 손질해 드러난 주황 살(빗각 판) + 흰 지방 줄 + 머리·꼬리.
	-- Ball은 가장 짧은 변이 지름이라 길쭉한 몸은 캡슐·판으로 만들어요.
	local yaw = v(0, 8, 0)
	local function at(dx: number, dy: number, dz: number): Vec3
		local r = math.rad(8)
		return v(cx + dx * math.cos(r) + dz * math.sin(r), boxTop + dy, cz - dx * math.sin(r) + dz * math.cos(r))
	end
	for _, spec in MapKitShapes.capsule("SalmonSkin", 84, 20, rgb(160, 172, 186), "Metal", at(0, 10, 0), yaw) do
		spec.reflectance = 0.2
		table.insert(specs, spec)
	end
	for _, spec in MapKitShapes.capsule("SalmonBack", 70, 12, rgb(78, 92, 112), "SmoothPlastic", at(2, 15, -6), yaw) do
		table.insert(specs, spec)
	end
	append(
		specs,
		MapKitShapes.bevelBox("SalmonFillet", v(56, 4, 18), PALETTE.Salmon, "SmoothPlastic", at(-6, 18.5, 3), 1.5, yaw)
	)
	for k = 0, 5 do
		part(
			specs,
			"SalmonFat",
			"Block",
			v(0.8, 0.4, 14),
			rgb(255, 226, 206),
			"SmoothPlastic",
			at(-26 + k * 9, 20.6, 3),
			v(0, 8 + 25, 0)
		)
	end
	part(specs, "SalmonHead", "Ball", v(22, 22, 22), rgb(146, 158, 172), "Metal", at(44, 11, 0)).reflectance = 0.2
	part(specs, "SalmonEye", "Ball", v(5, 5, 5), PALETTE.Rice, "SmoothPlastic", at(49, 15, -8.5))
	part(specs, "SalmonPupil", "Ball", v(2.6, 2.6, 2.6), PALETTE.Nori, "SmoothPlastic", at(50, 15.4, -10.4))
	part(specs, "SalmonGill", "Block", v(1, 14, 18), rgb(110, 120, 136), "SmoothPlastic", at(36, 11, 0), yaw)
	for _, sgn in { -1, 1 } do
		part(
			specs,
			"SalmonTail",
			"Wedge",
			v(2, 16, 18),
			rgb(120, 132, 148),
			"SmoothPlastic",
			at(-50, 10 + sgn * 6, 0),
			v(sgn * 35, 98, 0)
		)
	end
	local y = boxTop + 10
	-- 비늘 반짝임
	local glint = part(
		specs,
		"SalmonGlint",
		"Block",
		v(40, 2, 10),
		rgb(220, 230, 240),
		"SmoothPlastic",
		v(cx + 10, y + 8, cz - 8)
	)
	glint.transparency = 1
	glint.castShadow = false
	glint.particle = "Sparkle"
	glint.particleRate = 3
	-- 옆에 썰어 둔 연어 접시
	local px, pz = 40, -96
	append(
		specs,
		MapKitShapes.rimDisc(
			"SashimiPlate",
			34,
			2,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(px, TABLE_Y + 1, pz),
			{ rimColor = PALETTE.PorcelainRim, rimWidth = 1.5, rimHeight = 1.5, segments = 16 }
		)
	)
	for k = 0, 4 do
		part(
			specs,
			"SashimiSlice",
			"Block",
			v(10, 2.4, 5),
			if k % 2 == 0 then PALETTE.Salmon else PALETTE.SalmonLight,
			"SmoothPlastic",
			v(px - 8 + k * 4, TABLE_Y + 4, pz + (k % 2) * 1.5),
			v(0, 20, 14)
		)
	end
	part(
		specs,
		"SashimiShiso",
		"Ball",
		v(12, 1, 7),
		PALETTE.Shiso,
		"SmoothPlastic",
		v(px + 6, TABLE_Y + 3, pz - 7),
		v(0, 30, 0)
	)
end

-- ③ 칼꽂이 블록 + 숫돌 + 물그릇
local function knifeBlock(specs: { DecorSpec })
	local x, z = -100, -70
	local tilt = v(-14, 20, 0)
	append(
		specs,
		MapKitShapes.bevelBox("KnifeBlock", v(28, 40, 20), PALETTE.Wood, "Wood", v(x, TABLE_Y + 20, z), 2, tilt)
	)
	for k = 0, 4 do
		append(
			specs,
			MapKitShapes.transform(
				MapKitShapes.capsule(
					"KnifeBlockHandle",
					16 - (k % 2) * 3,
					3.4,
					if k == 2 then PALETTE.WoodDark else Art.KNIFE.handle,
					"SmoothPlastic",
					v(-10 + k * 5, 26 + (k % 2) * 2, 2),
					v(0, 0, 90)
				),
				v(x, TABLE_Y + 20, z),
				tilt
			)
		)
	end
	-- 숫돌 (두 색 돌 + 나무 받침) + 물그릇
	local sx, sz = -58, -110
	append(
		specs,
		MapKitShapes.bevelBox(
			"WhetBase",
			v(34, 4, 14),
			PALETTE.WoodDark,
			"Wood",
			v(sx, TABLE_Y + 2, sz),
			0.8,
			v(0, 18, 0)
		)
	)
	part(specs, "WhetStone", "Block", v(30, 4, 10), rgb(90, 110, 126), "Slate", v(sx, TABLE_Y + 6, sz), v(0, 18, 0))
	part(specs, "WhetStone", "Block", v(30, 2, 10), rgb(196, 120, 80), "Sandstone", v(sx, TABLE_Y + 9, sz), v(0, 18, 0))
	append(
		specs,
		MapKitShapes.rimDisc(
			"WhetBowl",
			18,
			6,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(sx - 22, TABLE_Y + 3, sz + 20),
			{ rimColor = PALETTE.PorcelainRim, rimWidth = 1, rimHeight = 2, segments = 12 }
		)
	)
	local water = disc(specs, "WhetWater", 0.4, 16, rgb(150, 190, 210), "Glass", sx - 22, TABLE_Y + 5.6, sz + 20)
	water.transparency = 0.3
	water.reflectance = 0.2
end

-- 개수대 + 수도꼭지(김·물방울) + 조리도구 통
local function sink(specs: { DecorSpec })
	local x, z = 118, 112
	append(
		specs,
		MapKitShapes.lipTrim(
			"SinkRim",
			v(70, 0, 56),
			4,
			2,
			MapKitLogic.shade(STEEL, 1.1),
			"Metal",
			v(x, TABLE_Y + 1, z)
		)
	)
	part(specs, "SinkBasin", "Block", v(70, 0.4, 56), rgb(70, 78, 86), "Metal", v(x, TABLE_Y + 0.25, z)).reflectance =
		0.3
	-- 수도꼭지: 뒤에서 솟아 앞으로 구부러짐
	local fz = z + 34
	disc(specs, "Faucet", 56, 6, STEEL, "Metal", x, TABLE_Y, fz).reflectance = 0.35
	part(specs, "Faucet", "Ball", v(7, 7, 7), STEEL, "Metal", v(x, TABLE_Y + 56, fz)).reflectance = 0.35
	part(specs, "Faucet", "Cylinder", v(26, 5, 5), STEEL, "Metal", v(x, TABLE_Y + 56, fz - 13), v(0, 90, 0)).reflectance =
		0.35
	disc(specs, "FaucetSpout", 8, 5, STEEL, "Metal", x, TABLE_Y + 48, fz - 26).reflectance = 0.35
	for _, s in { -1, 1 } do
		disc(specs, "FaucetHandle", 6, 4, PALETTE.NorenLight, "SmoothPlastic", x + s * 9, TABLE_Y, fz)
	end
	local drop =
		part(specs, "FaucetDrop", "Ball", v(2.4, 3.2, 2.4), rgb(180, 214, 236), "Glass", v(x, TABLE_Y + 44, fz - 26))
	drop.transparency = 0.25
	drop.anim = { kind = "Bob", period = 1.6, amount = 2 }
	local steam =
		part(specs, "SinkSteam", "Block", v(40, 2, 30), rgb(255, 255, 255), "SmoothPlastic", v(x, TABLE_Y + 2, z))
	steam.transparency = 1
	steam.castShadow = false
	steam.particle = "Steam"
	steam.particleRate = 3
	local cx, cz = x - 56, z + 26
	disc(specs, "UtensilCrock", 26, 16, PALETTE.Porcelain, "SmoothPlastic", cx, TABLE_Y, cz)
	disc(specs, "UtensilCrockBand", 4, 16.4, PALETTE.PorcelainRim, "SmoothPlastic", cx, TABLE_Y + 18, cz)
	for k = 0, 2 do
		local a = math.rad(k * 120)
		part(
			specs,
			"UtensilHandle",
			"Cylinder",
			v(30, 1.6, 1.6),
			if k == 1 then PALETTE.WoodDark else STEEL,
			"Metal",
			v(cx + math.cos(a) * 2, TABLE_Y + 34, cz + math.sin(a) * 2),
			v(0, k * 120, 80)
		)
	end
end

-- 매달린 냄비 걸이 + 국자·행주 (+Z 쪽, 도마 뒤 배경)
local function potRack(out: { DecorSpec })
	-- 로컬로 만든 뒤 +X 쪽(소개 overview 카메라 반대편)으로 돌려 옮겨요 — 도마를 가리지 않게
	local specs: { DecorSpec } = {}
	local z, y = 0, 96
	append(specs, MapKitShapes.capsule("PotRack", 150, 3, STEEL, "Metal", v(0, y, z)))
	for _, sx in { -70, 70 } do
		part(
			specs,
			"PotRackChain",
			"Cylinder",
			v(CEILING_Y - y, 0.8, 0.8),
			PALETTE.Iron,
			"Metal",
			v(sx, (y + CEILING_Y) / 2, z),
			UP
		)
	end
	for k = 0, 2 do
		local x = -50 + k * 32
		local d = 30 - k * 5
		part(specs, "HangingPanHook", "Cylinder", v(8, 0.8, 0.8), PALETTE.Iron, "Metal", v(x, y - 4, z), UP)
		append(
			specs,
			MapKitShapes.rimDisc(
				"HangingPan",
				d,
				3,
				MapKitLogic.shade(rgb(184, 112, 70), 0.9 + k * 0.08),
				"Metal",
				v(x, y - 8 - d / 2, z),
				{
					rimColor = rgb(150, 86, 52),
					rimWidth = 1.2,
					rimHeight = 1.5,
					segments = 14,
					rotation = v(90, 0, 0),
				}
			)
		)
	end
	-- 국자 2개 (흔들림)
	for k = 0, 1 do
		local x = 46 + k * 14
		local handle = part(specs, "LadleHandle", "Cylinder", v(30, 1.4, 1.4), STEEL, "Metal", v(x, y - 16, z), UP)
		handle.reflectance = 0.3
		local bowl = part(specs, "LadleBowl", "Ball", v(9, 6, 9), STEEL, "Metal", v(x, y - 33, z))
		bowl.reflectance = 0.3
		bowl.anim = { kind = "Sway", period = 3.5 + k, amount = 4, axis = "X" }
	end
	-- 행주 (살랑)
	for k = 0, 1 do
		local tx = -80 + k * 160
		local towel = part(
			specs,
			"HangingTowel",
			"Block",
			v(16, 26, 1),
			if k == 0 then rgb(236, 236, 228) else PALETTE.NorenLight,
			"Fabric",
			v(tx, y - 14, z + 2)
		)
		towel.anim = { kind = "Sway", period = 5 + k, amount = 5, axis = "X" }
		part(specs, "TowelStripe", "Block", v(16.2, 2, 1.2), PALETTE.Noren, "Fabric", v(tx, y - 20, z + 2))
	end
	append(out, MapKitShapes.transform(specs, v(150, 0, 30), v(0, 90, 0)))
end

-- 소스병 무리 (연어 상자 옆) + 와사비·생강 종지 (칼꽂이 옆) — 큰 것 1 + 중간 2 + 작은 것 여럿
local function condiments(specs: { DecorSpec })
	local bx, bz = -6, -128
	local bottles = {
		{ dx = 0, dz = 0, h = 34, d = 12, c = rgb(60, 30, 18) },
		{ dx = 13, dz = 6, h = 26, d = 10, c = rgb(232, 220, 190) },
		{ dx = -6, dz = 14, h = 22, d = 9, c = rgb(196, 120, 60) },
		{ dx = 15, dz = -9, h = 18, d = 8, c = rgb(214, 160, 40) },
	}
	for _, b in bottles do
		local x, z = bx + b.dx, bz + b.dz
		disc(specs, "SauceBottle", b.h, b.d, b.c, "SmoothPlastic", x, TABLE_Y, z).reflectance = 0.12
		part(specs, "SauceBottleShoulder", "Ball", v(b.d, b.d, b.d), b.c, "SmoothPlastic", v(x, TABLE_Y + b.h, z)).reflectance =
			0.12
		disc(specs, "SauceBottleCap", 5, b.d * 0.45, PALETTE.Nori, "SmoothPlastic", x, TABLE_Y + b.h + b.d * 0.4, z)
		part(
			specs,
			"SauceLabel",
			"Block",
			v(0.4, b.h * 0.35, b.d * 0.6),
			PALETTE.Rice,
			"SmoothPlastic",
			v(x - b.d / 2, TABLE_Y + b.h * 0.5, z)
		)
	end
	-- 와사비·생강 종지 (칼꽂이 옆)
	local dishes = {
		{ x = -70, z = -34, d = 16, c = PALETTE.Wasabi },
		{ x = -56, z = -44, d = 12, c = rgb(244, 170, 172) },
		{ x = -78, z = -52, d = 10, c = rgb(92, 50, 28) },
	}
	for _, d in dishes do
		append(
			specs,
			MapKitShapes.rimDisc(
				"SmallDish",
				d.d,
				3,
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(d.x, TABLE_Y + 1.5, d.z),
				{ rimColor = PALETTE.PorcelainRim, rimWidth = 0.8, rimHeight = 1, segments = 10 }
			)
		)
		part(
			specs,
			"SmallDishFill",
			"Ball",
			v(d.d * 0.6, d.d * 0.3, d.d * 0.6),
			d.c,
			"SmoothPlastic",
			v(d.x, TABLE_Y + 3.6, d.z)
		)
	end
end

-- 가스 화구 + 냄비 (뒤 -X 쪽, 파란 불꽃 = 차가운 빛, 김)
local function stove(specs: { DecorSpec })
	local x, z = -150, 60
	append(
		specs,
		MapKitShapes.roundedBox(
			"StoveBody",
			v(80, 12, 60),
			rgb(52, 56, 60),
			"Metal",
			v(x, TABLE_Y + 6, z),
			{ radius = 2 }
		)
	)
	for k = 0, 1 do
		local gx = x - 18 + k * 36
		append(
			specs,
			MapKitShapes.ring("StoveGrate", 9, 1.2, 1.2, 8, PALETTE.CastIron, "Metal", v(gx, TABLE_Y + 12.6, z))
		)
		local flame = part(
			specs,
			"StoveFlame",
			"Cylinder",
			v(0.6, 12, 12),
			rgb(90, 150, 255),
			"Neon",
			v(gx, TABLE_Y + 12.4, z),
			UP
		)
		flame.castShadow = false
		if k == 0 then
			flame.light = { kind = "Point", color = rgb(110, 160, 255), brightness = 1.2, range = 18 }
		end
	end
	-- 왼쪽 화구 위 육수 냄비 (김)
	local px = x - 18
	append(
		specs,
		MapKitShapes.rimDisc(
			"StockPot",
			30,
			28,
			STEEL,
			"Metal",
			v(px, TABLE_Y + 13 + 14, z),
			{ rimColor = MapKitLogic.shade(STEEL, 1.15), rimWidth = 1.2, rimHeight = 1.5, segments = 16 }
		)
	)
	for _, s in { -1, 1 } do
		part(specs, "StockPotHandle", "Block", v(4, 3, 8), PALETTE.CastIron, "Metal", v(px + s * 17, TABLE_Y + 36, z))
	end
	local broth = disc(specs, "StockPotBroth", 0.4, 27, rgb(214, 170, 96), "SmoothPlastic", px, TABLE_Y + 40, z)
	broth.particle = "Steam"
	broth.particleRate = 4
	broth.castShadow = false
	-- 오른쪽 화구 위 프라이팬 (손잡이 바깥)
	local fx = x + 18
	append(
		specs,
		MapKitShapes.rimDisc(
			"FryPan",
			26,
			2,
			PALETTE.CastIron,
			"Metal",
			v(fx, TABLE_Y + 14, z),
			{ rimColor = rgb(70, 70, 72), rimWidth = 1, rimHeight = 2.5, segments = 14 }
		)
	)
	append(
		specs,
		MapKitShapes.capsule("FryPanHandle", 26, 3, PALETTE.WoodDark, "Wood", v(fx, TABLE_Y + 16, z + 24), v(0, 90, 8))
	)
end

-- 밥통 (나무 한기리) + 주걱 — 셰프 작업대의 "초밥집" 표시 (+Z 왼쪽)
local function riceTub(specs: { DecorSpec })
	local x, z = -84, 96
	append(
		specs,
		MapKitShapes.rimDisc(
			"Hangiri",
			48,
			10,
			PALETTE.WoodLight,
			"Wood",
			v(x, TABLE_Y + 5, z),
			{ rimColor = PALETTE.Wood, rimWidth = 2, rimHeight = 2, segments = 18 }
		)
	)
	for _, by in { 2.5, 8 } do
		append(
			specs,
			MapKitShapes.ring("HangiriBand", 24.2, 0.8, 1.2, 18, Art.KNIFE.rivet, "Metal", v(x, TABLE_Y + by, z))
		)
	end
	part(specs, "HangiriRice", "Ball", v(42, 8, 42), PALETTE.Rice, "SmoothPlastic", v(x, TABLE_Y + 11, z))
	append(
		specs,
		MapKitShapes.bevelBox(
			"RicePaddle",
			v(10, 1.2, 26),
			PALETTE.WoodLight,
			"Wood",
			v(x + 10, TABLE_Y + 16, z - 6),
			0.4,
			v(20, 30, 0)
		)
	)
	-- 젖은 행주 (접힌 천)
	append(
		specs,
		MapKitShapes.bevelBox(
			"FoldedCloth",
			v(20, 3, 14),
			rgb(236, 236, 228),
			"Fabric",
			v(x + 36, TABLE_Y + 1.5, z + 18),
			0.6,
			v(0, -15, 0)
		)
	)
end

-- 벽 선반·병 + 시계 + 주문표 (+X·+Z 벽)
local function wallProps(specs: { DecorSpec })
	local jarColors = {
		rgb(92, 50, 28),
		rgb(214, 196, 150),
		rgb(150, 196, 72),
		rgb(240, 236, 226),
		rgb(196, 120, 60),
	}
	for k = 0, 1 do
		local y = 20 + k * 56
		local x = ROOM - 14
		append(
			specs,
			MapKitShapes.roundedBox(
				"WallShelf",
				v(22, 4, 220),
				PALETTE.WoodLight,
				"Wood",
				v(x, y, 10 - k * 30),
				{ radius = 1.5, style = "vertical" }
			)
		)
		for b = 0, 6 do
			local h = 16 + ((b * 5 + k * 3) % 4) * 5
			local d = 10 + ((b + k) % 3) * 3
			local col = jarColors[1 + (b + k) % #jarColors]
			local jz = -80 - k * 30 + b * 30 + (b % 2) * 4
			disc(specs, "ShelfJar", h, d, col, "SmoothPlastic", x, y + 2, jz).reflectance = 0.08
			disc(specs, "ShelfJarLid", 3, d * 0.7, MapKitLogic.shade(col, 0.6), "SmoothPlastic", x, y + 2 + h, jz)
		end
	end
	-- 벽시계 (+Z 벽)
	append(
		specs,
		MapKitShapes.rimDisc(
			"WallClock",
			40,
			3,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(60, 120, ROOM - 5),
			{ rimColor = WOOD_DARK, rimWidth = 3, rimHeight = 2, segments = 16, rotation = v(90, 0, 0) }
		)
	)
	part(specs, "ClockHand", "Block", v(1.4, 14, 1), PALETTE.Nori, "SmoothPlastic", v(60, 125, ROOM - 7.5))
	part(
		specs,
		"ClockHand",
		"Block",
		v(10, 1.4, 1),
		PALETTE.Nori,
		"SmoothPlastic",
		v(56, 120, ROOM - 7.5),
		v(0, 0, -30)
	)
	-- 주문표 줄 (+Z 벽, 하얀 종이 무리)
	append(specs, MapKitShapes.capsule("TicketRail", 120, 2, STEEL, "Metal", v(-60, 70, ROOM - 6)))
	for k = 0, 5 do
		part(
			specs,
			"OrderTicket",
			"Block",
			v(9, 14 + (k % 3) * 2, 0.4),
			MapKitLogic.shade(PALETTE.Rice, 0.94 + (k % 2) * 0.05),
			"SmoothPlastic",
			v(-108 + k * 18 + (k % 2) * 3, 61 - (k % 3), ROOM - 6.5),
			v(0, 0, (k % 3 - 1) * 4)
		)
	end
end

-- 창문 쪽 작업등 (좁은 그림자 SpotLight — 칼 그림자가 도마에 떨어져 줄이 읽히게, 도마에서 60 안)
local function workLamp(specs: { DecorSpec })
	local x, y, z = -34, 54, -30
	part(
		specs,
		"WorkLampCord",
		"Cylinder",
		v(CEILING_Y - y - 4, 0.5, 0.5),
		PALETTE.Nori,
		"SmoothPlastic",
		v(x, (y + 4 + CEILING_Y) / 2, z),
		UP
	)
	append(
		specs,
		MapKitShapes.rimDisc(
			"WorkLampShade",
			14,
			2,
			rgb(60, 72, 80),
			"Metal",
			v(x, y + 3, z),
			{ rimColor = rgb(40, 48, 56), rimWidth = 1, rimHeight = 3, segments = 14 }
		)
	)
	part(specs, "WorkLampTop", "Ball", v(12, 7, 12), rgb(60, 72, 80), "Metal", v(x, y + 5, z)).reflectance = 0.25
	local bulb = part(specs, "WorkLampBulb", "Ball", v(5, 5, 5), rgb(255, 244, 222), "Neon", v(x, y, z))
	bulb.castShadow = false
	bulb.light = {
		kind = "Spot",
		color = rgb(255, 240, 214),
		brightness = 2.4,
		range = 60,
		angle = 75,
		face = "Bottom",
		shadows = true,
	}
end

local function kitchen(specs: { DecorSpec })
	room(specs)
	herbs(specs)
	boardStand(specs)
	salmon(specs)
	knifeBlock(specs)
	sink(specs)
	potRack(specs)
	condiments(specs)
	stove(specs)
	riceTub(specs)
	wallProps(specs)
	workLamp(specs)

	-- ④ 머리 위 매달린 등 3개 (m5-20 LampBulb, 빛은 ChefBoard.build가 PointLight로)
	for k = -1, 1 do
		local x = k * 26
		part(
			specs,
			"LampCord",
			"Block",
			v(0.4, CEILING_Y - 46, 0.4),
			PALETTE.Nori,
			"SmoothPlastic",
			v(x, (46 + CEILING_Y) / 2, 10)
		)
		append(
			specs,
			MapKitShapes.rimDisc(
				"LampShade",
				10,
				4,
				PALETTE.Noren,
				"SmoothPlastic",
				v(x, 44, 10),
				{ rimColor = rgb(214, 172, 64), rimWidth = 0.8, rimHeight = 1, segments = 12 }
			)
		)
		part(specs, Art.LAMP_BULB, "Ball", v(3.5, 3.5, 3.5), rgb(255, 232, 170), "Neon", v(x, 41.5, 10))
	end
end

-- 맵 바깥 멀리 아주 크고 옅은 반투명 색 패널 (m5-20 ③, 도마 시야 상자와 안 겹치는 자리)
local function addFogPanels(specs: { DecorSpec })
	local function panel(x: number, y: number, z: number, sx: number, sy: number, sz: number)
		add(specs, {
			name = Art.FOG_PANEL,
			shape = "Block",
			size = v(sx, sy, sz),
			color = FOG,
			material = "Glass",
			offset = v(x, y, z),
			transparency = 0.92,
		})
	end
	-- m5-24: 지우지 않고 방 벽(±ROOM) 바깥으로 옮겨요 — 방 안이 뿌옇지 않게, 분위기는 Art.LIGHTING (결정 기록 D5)
	local d = ROOM + 12
	panel(-d, -10, 0, 2, 220, 260)
	panel(d, -10, 0, 2, 220, 260)
	panel(0, -10, d, 260, 220, 2)
	panel(0, -10, -d, 260, 220, 2)
end

function Art.decor(): { DecorSpec }
	local specs: { DecorSpec } = {}
	local skins = {
		rgb(240, 200, 170),
		rgb(214, 168, 130),
		rgb(250, 214, 186),
		rgb(176, 124, 92),
	}
	-- 머리 중심 높이 -43 ~ -47: 꼭대기(눈동자 포함)는 -30 아래, 턱은 -60 위
	customerFace(specs, 26, -44, 26, skins[1])
	customerFace(specs, -28, -46, 22, skins[2])
	customerFace(specs, -24, -43, -28, skins[3])
	customerFace(specs, 28, -47, -24, skins[4])
	kitchen(specs)
	addFogPanels(specs) -- m5-20 ③
	return specs
end

-- 셀 장식 전체 (테스트·예산 계산용)
function Art.allCellDecor(): { DecorSpec }
	local board = Logic.newBoard()
	local function hasNeighbor(i: number, j: number): boolean
		return Logic.isAlive(board, i, j)
	end
	local specs: { DecorSpec } = {}
	for _, cell in Logic.cells() do
		for _, spec in Art.cellDecor(cell, hasNeighbor) do
			table.insert(specs, spec)
		end
	end
	return specs
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- 위에서 내려다봄 → 칼이 오는 옆 → 도마 바깥 높이 18에서 가운데를 봄
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 60, 75), lookAt = v(0, 0, 0) },
		{ pos = v(60, 22, -35), lookAt = v(0, 2, 0) },
		{ pos = v(0, 18, 52), lookAt = v(0, 2, 0) },
	}
end

function Art.courseVolume(): MapKitLogic.Bounds
	local r = Logic.BOARD_RADIUS
	return { min = v(-r, 2, -r), max = v(r, 12, r) }
end

return Art
