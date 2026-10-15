--!strict
-- "우주 회전초밥" 아트 데이터 (m5-35, docs/REFERENCE-map-art-direction.md). Roblox API를 쓰지 않아요 — lune에서 바로 불러요.
-- 컨셉: 초밥집 테마파크의 우주관 — 별바다 위를 도는 네온 회전초밥 레일. 1 stud ≈ 1 cm라 행성·로켓은 큰 놀이 기구 크기.
-- 히어로 색: 네온 청록 레일 테두리(#3FE0F0) + 보라 성운(#7A4FD8). 60 = 짙은 남색·보라 하늘·행성 표면,
-- 30 = 밝은 라벤더-흰색 레일 상판·회전초밥 접시, 10 = 네온 청록·별빛, 위험 주황은 화살표 Back과 운석만.
-- 좌표는 map origin(출발선 가운데, 바닥 윗면) 기준 로컬. 낙하선은 −15~−27, 배경 행성 표면(GROUND_Y −60)은 그보다 33 아래.
--   SpaceConveyorArt.decor() -> { DecorSpec }          정적 장식 전부 (충돌 없음)
--   SpaceConveyorArt.introCamera() -> { IntroPoint }    고리 행성 너머 S자 레일 → 화살표 레일 → 소행성 올려다보기 → 정거장 → 발사대
--   SpaceConveyorArt.courseVolumes() -> { Bounds }       장식이 가리면 안 되는 상자들 (밟는 면 위 2~12)
--   SpaceConveyorArt.COLORS                              판정 파츠·화살표·운석·바위 색 (SpaceConveyor가 씀)
--   SpaceConveyorArt.LIGHTING                            맵 조명 프리셋 (한밤 우주)
--   SpaceConveyorArt.BUDGET = "Extended", GROUND / GROUND_Y   배경 행성 표면 이름·윗면 높이

local Layout = require(script.Parent.SpaceConveyorLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds
type LightSpec = MapKitLogic.LightSpec
type AnimSpec = MapKitLogic.AnimSpec

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local SpaceConveyorArt = {}

SpaceConveyorArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
SpaceConveyorArt.GROUND = "PlanetSurface"
SpaceConveyorArt.GROUND_Y = -60
SpaceConveyorArt.SIGHT_MIN = 2
SpaceConveyorArt.SIGHT_MAX = 12

local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 색 ─────────────────────────────────────────────────────────────────────
local CYAN = c(63, 224, 240) -- 히어로 1: 네온 청록 레일 테두리
local NEBULA = c(122, 79, 216) -- 히어로 2: 보라 성운
local NAVY = c(28, 24, 74)
local NAVY_DEEP = c(18, 16, 52)
local SURFACE = c(68, 56, 114) -- 배경 행성 표면
local LAVENDER = c(232, 228, 250) -- 레일 상판 (밟는 면, 가장 밝게)
local KEEL = c(84, 72, 146) -- 레일 아래 몸통
local ROCK = c(104, 92, 138)
local GOLD = c(255, 210, 120) -- 정거장 착륙등 (따뜻한 빛)
local STAR = c(240, 244, 255)

SpaceConveyorArt.COLORS = {
	rail = LAVENDER,
	hub = c(210, 202, 240),
	pad = c(222, 216, 246),
	field = c(186, 178, 214),
	asteroidTop = c(200, 192, 226),
	finishLine = c(255, 214, 90),
	arrowForward = CYAN,
	arrowBack = c(255, 150, 40),
	warn = c(232, 24, 36),
	warnBlink = c(255, 92, 92),
	warnBorder = c(255, 255, 255),
	meteor = c(255, 120, 40),
	rock = c(88, 78, 104),
	rockLight = c(118, 106, 136),
} :: { [string]: RGB }

-- 맵 조명: 한밤 우주. 낮은 보라 Ambient, 남보라 안개, 강한 블룸(네온이 번지게), 대비·채도 살짝.
SpaceConveyorArt.LIGHTING = {
	ClockTime = 0,
	Brightness = 2,
	Ambient = c(52, 42, 98),
	OutdoorAmbient = c(116, 100, 184),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.7,
	ShadowSoftness = 0.3,
	ExposureCompensation = 0.3,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.04,
		Color = c(70, 56, 128),
		Decay = c(32, 26, 76),
		Glare = 0,
		Haze = 1.2,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.1, TintColor = c(244, 240, 255) },
	Bloom = { Intensity = 0.9, Size = 26, Threshold = 1.1 },
	SunRays = { Intensity = 0.02, Spread = 0.5 },
} :: MapLighting.LightingPreset

-- ── 목록 도우미 ────────────────────────────────────────────────────────────
type Extra = {
	rotation: Vec3?,
	transparency: number?,
	reflectance: number?,
	castShadow: boolean?,
	light: LightSpec?,
	particle: string?,
	particleRate: number?,
	anim: AnimSpec?,
}

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로
local INTRO_LOW = v(44, -24, -90) -- 소개 ③ 카메라 자리 (introCamera와 같아요)

local function spec(
	name: string,
	shape: Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	extra: Extra?
): DecorSpec
	local e: Extra = extra or {}
	return {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = e.rotation,
		transparency = e.transparency,
		reflectance = e.reflectance,
		castShadow = e.castShadow,
		light = e.light,
		particle = e.particle,
		particleRate = e.particleRate,
		anim = e.anim,
	}
end

local function add(
	list: { DecorSpec },
	name: string,
	shape: Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	extra: Extra?
)
	table.insert(list, spec(name, shape, size, color, material, offset, extra))
end

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
end

-- 세운 원기둥 (지름 d, 높이 h, 아랫면 bottom)
local function column(
	list: { DecorSpec },
	name: string,
	d: number,
	h: number,
	color: RGB,
	material: string,
	x: number,
	bottom: number,
	z: number,
	extra: Extra?
)
	local e: Extra = extra or {}
	e.rotation = e.rotation or UPRIGHT
	add(list, name, "Cylinder", v(h, d, d), color, material, v(x, bottom + h / 2, z), e)
end

-- 눕힌 원판 (지름 d, 두께 h, 가운데 y)
local function disc(
	name: string,
	d: number,
	h: number,
	color: RGB,
	material: string,
	x: number,
	y: number,
	z: number,
	extra: Extra?
): DecorSpec
	local e: Extra = extra or {}
	e.rotation = e.rotation or UPRIGHT
	return spec(name, "Cylinder", v(h, d, d), color, material, v(x, y, z), e)
end

-- ── 밟는 면 시야 상자 ─────────────────────────────────────────────────────
local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Bounds
	return { min = v(minX, minY, minZ), max = v(maxX, maxY, maxZ) }
end

function SpaceConveyorArt.courseVolumes(): { Bounds }
	local lo, hi = SpaceConveyorArt.SIGHT_MIN, SpaceConveyorArt.SIGHT_MAX
	local list: { Bounds } = {}
	local a = Layout.section("A")
	table.insert(list, box(-Layout.START_WIDTH / 2, lo, a.back, Layout.START_WIDTH / 2, hi, a.front))
	-- 레일 조각은 8토막으로 나눠 토막마다 상자 (기울어진 조각의 상자가 이웃 조각 아래까지 덮지 않게)
	for _, rail in Layout.rails() do
		local hw = rail.width / 2
		local dx, dz = rail.x1 - rail.x0, rail.z1 - rail.z0
		local h = math.sqrt(dx * dx + dz * dz)
		local ex, ez = math.abs(dz / h) * hw, math.abs(dx / h) * hw
		local pieces = 8
		for k = 0, pieces - 1 do
			local t0, t1 = k / pieces, (k + 1) / pieces
			local ax, ay, az = rail.x0 + dx * t0, rail.y0 + (rail.y1 - rail.y0) * t0, rail.z0 + dz * t0
			local bx, by, bz = rail.x0 + dx * t1, rail.y0 + (rail.y1 - rail.y0) * t1, rail.z0 + dz * t1
			table.insert(
				list,
				box(
					math.min(ax, bx) - ex,
					math.min(ay, by) + lo,
					math.min(az, bz) - ez,
					math.max(ax, bx) + ex,
					math.max(ay, by) + hi,
					math.max(az, bz) + ez
				)
			)
		end
	end
	for _, hub in Layout.hubs() do
		local r = hub.radius
		table.insert(list, box(hub.x - r, hub.y + lo, hub.z - r, hub.x + r, hub.y + hi, hub.z + r))
	end
	for _, rock in Layout.ASTEROIDS do
		local r = rock.radius
		table.insert(list, box(rock.x - r, rock.top + lo, rock.z - r, rock.x + r, rock.top + hi, rock.z + r))
	end
	local top = Layout.TOP_Y
	for _, id in { "E", "G" } do
		local s = Layout.section(id)
		local hw = (if id == "E" then Layout.FIELD_WIDTH else Layout.FINISH_WIDTH) / 2
		table.insert(list, box(-hw, top + lo, s.back, hw, top + hi, s.front))
	end
	return list
end

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

-- 흩뿌린 소품 중 밟는 면 시야 상자에 걸리는 것은 빼요
local function keepClear(list: { DecorSpec }, more: { DecorSpec })
	local sights = SpaceConveyorArt.courseVolumes()
	for _, s in more do
		local b = MapKitLogic.bounds({ s }) :: Bounds
		local clear = true
		for _, sight in sights do
			if overlaps(b, sight) then
				clear = false
				break
			end
		end
		if clear then
			table.insert(list, s)
		end
	end
end

-- ── 전경: 레일 테두리·이음매 원판·발사대·들판·두 갈래·착륙장 ────────────────────
local function railTrim(list: { DecorSpec })
	for _, rail in Layout.rails() do
		local dx, dy, dz = rail.x1 - rail.x0, rail.y1 - rail.y0, rail.z1 - rail.z0
		local h = math.sqrt(dx * dx + dz * dz)
		local length = math.sqrt(h * h + dy * dy)
		local yaw = math.deg(math.atan2(-dx, -dz))
		local pitch = math.deg(math.atan2(dy, h))
		local hw = rail.width / 2
		local local_: { DecorSpec } = {}
		-- 네온 청록 립 (윗면보다 0.1 낮게, 바깥으로 0.35). 원판 위를 지나는 끝부분은 잘라요(원판 면과 겹치지 않게).
		local lateral = hw + 0.18
		local cut = if rail.hubStart and lateral < Layout.HUB_RADIUS
			then math.sqrt(Layout.HUB_RADIUS ^ 2 - lateral ^ 2) + 0.2
			else 0
		for _, side in { -1, 1 } do
			table.insert(
				local_,
				spec("RailRim", "Block", v(0.36, 0.5, length - 2 * cut), CYAN, "Neon", v(side * lateral, -0.35, 0))
			)
			-- 립 아래 짙은 띠 (두께감)
			table.insert(
				local_,
				spec(
					"RailSide",
					"Block",
					v(0.3, 1.4, length - 2 * cut),
					KEEL,
					"SmoothPlastic",
					v(side * (hw + 0.15), -1.3, 0)
				)
			)
		end
		-- 아래 몸통(용골) + 바닥 보라 빛 띠
		table.insert(
			local_,
			spec("RailKeel", "Block", v(rail.width - 4, 1.6, length - 2), KEEL, "SmoothPlastic", v(0, -2.8, 0))
		)
		table.insert(
			local_,
			spec("RailUnderGlow", "Block", v(1.2, 0.3, length - 4), c(150, 110, 240), "Neon", v(0, -3.7, 0))
		)
		local pitched = MapKitShapes.transform(local_, v(0, 0, 0), v(pitch, 0, 0))
		append(
			list,
			MapKitShapes.transform(
				pitched,
				v((rail.x0 + rail.x1) / 2, (rail.y0 + rail.y1) / 2, (rail.z0 + rail.z1) / 2),
				v(0, yaw, 0)
			)
		)
	end
end

local function hubTrim(list: { DecorSpec })
	for i, hub in Layout.hubs() do
		local flat = i <= #Layout.B_HUBS
		local ringTop = if flat then hub.y - 0.15 else hub.y - 0.85
		append(
			list,
			MapKitShapes.ring("HubRim", hub.radius + 0.2, 0.42, 0.5, 14, CYAN, "Neon", v(hub.x, ringTop - 0.25, hub.z))
		)
		-- 원판 아래 치마(두께감) + 가운데 보라 축
		table.insert(
			list,
			disc("HubSkirt", hub.radius * 2 - 1.5, 1.4, KEEL, "SmoothPlastic", hub.x, hub.y - 2.8, hub.z)
		)
		table.insert(list, disc("HubCore", 4, 1.2, NEBULA, "Neon", hub.x, hub.y - 3.9, hub.z))
	end
end

local function launchPad(list: { DecorSpec })
	local a = Layout.section("A")
	local w, d = Layout.START_WIDTH, a.front - a.back
	local cz = (a.front + a.back) / 2
	append(list, MapKitShapes.lipTrim("PadLip", v(w, 0, d), 0.45, 0.6, CYAN, "Neon", v(0, -0.4, cz)))
	append(
		list,
		MapKitShapes.lipTrim("PadSide", v(w + 0.9, 0, d + 0.9), 0.5, 1.6, KEEL, "SmoothPlastic", v(0, -1.6, cz))
	)
	-- 발사대 아래 둥근 받침 (넓은 원판 + 테두리) — 바닥보다 2.6 낮게
	append(
		list,
		MapKitShapes.rimDisc("PadBase", 34, 1.6, c(70, 60, 124), "SmoothPlastic", v(0, -3.6, cz + 2), {
			rimColor = c(110, 96, 176),
			rimWidth = 1.2,
			rimHeight = 0.8,
			segments = 18,
		})
	)
	table.insert(list, disc("PadThruster", 14, 3, c(46, 40, 90), "Metal", 0, -6.2, cz + 2, { reflectance = 0.2 }))
	table.insert(list, disc("PadThrusterGlow", 9, 0.6, c(140, 200, 255), "Neon", 0, -7.9, cz + 2))
	-- 양옆 발사 탑 (스폰 뒤 카메라를 가리지 않게 옆으로)
	for _, side in { -1, 1 } do
		local x = side * 26
		append(
			list,
			MapKitShapes.roundedBox(
				"Gantry",
				v(2, 26, 2),
				c(150, 140, 200),
				"Metal",
				v(x, 9, -12),
				{ style = "vertical", radius = 0.5 }
			)
		)
		append(
			list,
			MapKitShapes.roundedBox(
				"Gantry",
				v(2, 22, 2),
				shade(c(150, 140, 200), 0.85),
				"Metal",
				v(x + side * 4, 7, -6),
				{ style = "vertical", radius = 0.5 }
			)
		)
		for k = 0, 3 do
			add(
				list,
				"GantryBar",
				"Block",
				v(4.4, 0.6, 0.6),
				KEEL,
				"Metal",
				v(x + side * 2, 2 + k * 5.5, -9),
				{ rotation = v(0, 0, side * 20) }
			)
		end
		add(list, "GantryArm", "Block", v(4.5, 0.8, 0.8), c(150, 140, 200), "Metal", v(x - side * 2.6, 19, -12))
		add(list, "GantryLamp", "Ball", v(1.4, 1.4, 1.4), CYAN, "Neon", v(x, 22.6, -12), {
			light = { kind = "Point", color = CYAN, brightness = 1.4, range = 22 },
			anim = { kind = "Pulse", period = 1.8, amount = 0.12 },
		})
		add(list, "GantryCap", "Ball", v(2.6, 2.6, 2.6), c(190, 176, 240), "SmoothPlastic", v(x + side * 4, 18.4, -6))
	end
	add(list, "PadDust", "Block", v(2, 0.4, 2), c(70, 60, 124), "SmoothPlastic", v(0, -5.2, -12), {
		transparency = 1,
		particle = "Stardust",
		particleRate = 3,
	})
end

local function meteorField(list: { DecorSpec })
	local e = Layout.section("E")
	local w, d = Layout.FIELD_WIDTH, e.front - e.back
	local cz = (e.front + e.back) / 2
	local top = Layout.TOP_Y
	append(
		list,
		MapKitShapes.lipTrim("FieldLip", v(w, 0, d), 0.5, 0.7, c(130, 116, 186), "SmoothPlastic", v(0, top - 0.45, cz))
	)
	-- 판 아래 울퉁불퉁한 소행성 몸통 (3 shade)
	local rocks = MapKitLogic.shades(ROCK)
	-- { x, 윗면 높이, z, 지름, 색 } — 윗면은 판 바닥(top − 2)보다 1 이상 아래라 판 위로 안 뚫고 나와요
	local lumps = {
		{ 0, top - 3.5, cz, 34, rocks.base },
		{ -8, top - 3.2, cz + 26, 24, rocks.dark },
		{ 9, top - 3.2, cz - 24, 26, rocks.light },
		{ 3, top - 18, cz + 8, 26, rocks.dark },
		{ -5, top - 16, cz - 14, 22, rocks.base },
		{ 11, top - 4, cz + 16, 14, rocks.base },
		{ -12, top - 4, cz - 30, 12, rocks.light },
		{ 0, top - 28, cz - 4, 18, rocks.light },
	}
	for _, l in lumps do
		local s = l[4] :: number
		local topY = l[2] :: number
		add(list, "FieldRock", "Ball", v(s, s, s), l[5] :: RGB, "Rock", v(l[1] :: number, topY - s / 2, l[3] :: number))
	end
	-- 가장자리 바위 무리 (윗면 ≤ top − 2.5, 바닥처럼 안 보이게 어둡게)
	local rng = MapKitShapes.rng(3507)
	for i = 0, 13 do
		local side = if i % 2 == 0 then -1 else 1
		local z = e.front - 4 - i * 5.6 + rng:range(-1.5, 1.5)
		local s = rng:range(2.2, 4.2)
		add(
			list,
			"FieldEdgeRock",
			"Ball",
			v(s, s, s),
			if i % 3 == 0 then rocks.dark else rocks.base,
			"Rock",
			v(side * (w / 2 + s / 2 + 0.4), top - 2.6 - s / 2 + rng:range(-0.6, 0.4), z)
		)
	end
	-- 들판 모서리 네온 표지등 (청록·보라)
	for _, p in { { -1, e.front }, { 1, e.front }, { -1, e.back }, { 1, e.back } } do
		local x, z = p[1] * (w / 2 + 1.4), p[2]
		column(list, "FieldPost", 1.2, 4, c(150, 140, 200), "Metal", x, top - 3.5, z)
		add(
			list,
			"FieldBeacon",
			"Ball",
			v(1.6, 1.6, 1.6),
			if p[1] < 0 then CYAN else c(170, 120, 255),
			"Neon",
			v(x, top + 1.1, z)
		)
	end
	table.insert(
		list,
		spec("FieldBeaconLight", "Ball", v(1, 1, 1), CYAN, "Neon", v(-(w / 2 + 1.4), top + 1.1, cz), {
			light = { kind = "Point", color = c(150, 200, 255), brightness = 1.2, range = 30 },
		})
	)
end

local function twinRails(list: { DecorSpec })
	local f = Layout.section("F")
	local top = Layout.TOP_Y
	local cz = (f.front + f.back) / 2
	-- 두 줄 사이 아래 받침 기둥 (위로 안 올라오게 top − 4 아래)
	for k = 0, 3 do
		local z = f.front - 12 - k * 22
		append(
			list,
			MapKitShapes.roundedBox(
				"TwinStrut",
				v(18, 1.4, 2),
				KEEL,
				"Metal",
				v(0, top - 5, z),
				{ style = "vertical", radius = 0.6 }
			)
		)
		column(list, "TwinPylon", 2.2, 30, c(70, 60, 124), "Metal", 0, top - 36, z)
		add(list, "TwinPylonGlow", "Ball", v(1.6, 1.6, 1.6), c(170, 120, 255), "Neon", v(0, top - 5.8, z))
	end
	local _ = cz
end

local function landing(list: { DecorSpec })
	local g = Layout.section("G")
	local w, d = Layout.FINISH_WIDTH, g.front - g.back
	local cz = (g.front + g.back) / 2
	local top = Layout.TOP_Y
	append(list, MapKitShapes.lipTrim("PadGoldLip", v(w, 0, d), 0.45, 0.6, GOLD, "Neon", v(0, top - 0.4, cz)))
	append(
		list,
		MapKitShapes.lipTrim("PadSide", v(w + 0.9, 0, d + 0.9), 0.5, 1.6, KEEL, "SmoothPlastic", v(0, top - 1.6, cz))
	)
	-- 착륙등 (가장자리 바깥 금빛 점)
	for k = 0, 4 do
		local z = g.front - 3 - k * 6
		for _, side in { -1, 1 } do
			add(list, "LandingLight", "Block", v(0.8, 0.5, 1.4), GOLD, "Neon", v(side * (w / 2 + 1.0), top - 0.3, z))
		end
	end
end

-- ── 중경 ③: 행성 정거장 + 네온 FINISH 아치 ───────────────────────────────────
-- 블록 글자 (가로 3 × 세로 5 칸, 칸 크기 s) — 아치 앞면에 붙여요
local LETTERS: { [string]: { { number } } } = {
	F = { { 0, 0, 1, 5 }, { 1, 4, 2, 1 }, { 1, 2, 1.5, 1 } },
	I = { { 1, 0, 1, 5 }, { 0, 4, 3, 1 }, { 0, 0, 3, 1 } },
	N = { { 0, 0, 1, 5 }, { 2, 0, 1, 5 }, { 1, 1.5, 1, 2 } },
	S = { { 0, 4, 3, 1 }, { 0, 2, 3, 1 }, { 0, 0, 3, 1 }, { 0, 3, 1, 1 }, { 2, 1, 1, 1 } },
	H = { { 0, 0, 1, 5 }, { 2, 0, 1, 5 }, { 1, 2, 1, 1 } },
}

local function finishArch(list: { DecorSpec })
	local top = Layout.TOP_Y
	local z = Layout.FINISH_LINE_Z
	local half = Layout.FINISH_WIDTH / 2 + 2.2
	local frame = c(196, 188, 236)
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.roundedBox(
				"ArchPillar",
				v(2.6, 22, 3),
				frame,
				"Metal",
				v(side * half, top + 9, z),
				{ style = "vertical", radius = 0.6 }
			)
		)
		add(list, "ArchPillarGlow", "Block", v(0.4, 18, 0.4), CYAN, "Neon", v(side * (half - 1.35), top + 9, z + 1.2))
		column(list, "ArchFoot", 5, 2, KEEL, "Metal", side * half, top - 2.4, z)
	end
	-- 윗보 (y top+20 ~ top+26, 밟는 면 시야 위)
	append(
		list,
		MapKitShapes.roundedBox(
			"ArchBeam",
			v(half * 2 + 3, 6, 3.4),
			c(60, 46, 120),
			"SmoothPlastic",
			v(0, top + 23, z),
			{ radius = 1 }
		)
	)
	add(list, "ArchBeamRim", "Block", v(half * 2 + 3.4, 0.4, 0.5), CYAN, "Neon", v(0, top + 19.8, z + 1.5))
	add(list, "ArchBeamRim", "Block", v(half * 2 + 3.4, 0.4, 0.5), CYAN, "Neon", v(0, top + 26.2, z + 1.5))
	-- FINISH 글자 (금빛 네온, 앞면 = +Z 쪽에서 다가오는 사람을 봐요)
	local word = { "F", "I", "N", "I", "S", "H" }
	local s = 0.85
	local letterW = 3 * s
	local gap = 1.1
	local total = #word * letterW + (#word - 1) * gap
	for i, ch in word do
		local x0 = -total / 2 + (i - 1) * (letterW + gap)
		for _, stroke in LETTERS[ch] do
			local sx, sy, sw, sh = stroke[1], stroke[2], stroke[3], stroke[4]
			add(
				list,
				"FinishLetter",
				"Block",
				v(sw * s, sh * s, 0.4),
				c(255, 226, 140),
				"Neon",
				v(x0 + (sx + sw / 2) * s, top + 20.9 + (sy + sh / 2) * s, z + 1.85)
			)
		end
	end
	-- 착륙등 그림자 SpotLight (보 아래, 아래를 비춰요 — 그림자 조명 2)
	add(list, "ArchSpot", "Block", v(3, 0.6, 1.6), GOLD, "Neon", v(0, top + 19.6, z), {
		light = {
			kind = "Spot",
			color = c(255, 214, 150),
			brightness = 3,
			range = 34,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
end

local function station(list: { DecorSpec })
	local top = Layout.TOP_Y
	local g = Layout.section("G")
	local cz = (g.front + g.back) / 2
	local panel = MapKitLogic.shades(c(206, 200, 236))
	-- 작은 행성 위 정거장: 착륙장 아래 작은 행성 (윗면 < top − 3)
	add(list, "Planetoid", "Ball", v(64, 64, 64), c(92, 78, 140), "Rock", v(0, top - 36, cz - 2))
	add(list, "PlanetoidCap", "Ball", v(40, 40, 40), c(116, 100, 168), "Rock", v(-10, top - 25, cz + 6))
	add(list, "PlanetoidCap", "Ball", v(30, 30, 30), c(76, 64, 120), "Rock", v(14, top - 22, cz - 10))
	-- 뒤쪽 돔 + 받침
	local zb = g.back - 22
	column(list, "StationBase", 52, 8, panel.dark, "Metal", 0, top - 10, zb, { reflectance = 0.15 })
	append(list, MapKitShapes.ring("StationBaseRim", 26.3, 0.6, 0.6, 20, CYAN, "Neon", v(0, top - 2.1, zb)))
	add(
		list,
		"StationDome",
		"Ball",
		v(40, 40, 40),
		panel.light,
		"SmoothPlastic",
		v(0, top - 4, zb),
		{ reflectance = 0.1 }
	)
	add(
		list,
		"StationDomeBand",
		"Cylinder",
		v(2, 41, 41),
		panel.base,
		"SmoothPlastic",
		v(0, top + 4, zb),
		{ rotation = UPRIGHT }
	)
	-- 돔 창 (청록 유리 띠)
	for k = 0, 5 do
		local a = math.rad(-60 + k * 24)
		add(
			list,
			"DomeWindow",
			"Block",
			v(4, 2.4, 0.6),
			c(120, 220, 255),
			"Glass",
			v(math.sin(a) * 19.6, top + 7, zb + math.cos(a) * 19.6),
			{
				rotation = v(-18, math.deg(a), 0),
				transparency = 0.2,
				reflectance = 0.3,
			}
		)
	end
	-- 옆 탑 2개 (둥근 지붕) + 금빛 등
	for _, side in { -1, 1 } do
		local x = side * 30
		column(list, "StationTower", 10, 30, panel.base, "Metal", x, top - 14, zb + 6, { reflectance = 0.12 })
		column(list, "StationTowerBand", 10.6, 1.4, KEEL, "Metal", x, top + 4, zb + 6)
		add(list, "StationTowerCap", "Ball", v(10, 10, 10), panel.light, "SmoothPlastic", v(x, top + 16, zb + 6))
		add(list, "StationLamp", "Ball", v(2, 2, 2), GOLD, "Neon", v(x, top + 22, zb + 6), {
			light = { kind = "Point", color = GOLD, brightness = 1.5, range = 28 },
		})
	end
	-- 안테나 + 깜빡이는 등
	column(list, "Antenna", 1.2, 26, c(170, 160, 220), "Metal", 0, top + 14, zb)
	add(
		list,
		"AntennaDish",
		"Cylinder",
		v(1, 10, 10),
		panel.light,
		"Metal",
		v(0, top + 30, zb),
		{ rotation = v(0, 0, 70) }
	)
	add(list, "AntennaLight", "Ball", v(1.8, 1.8, 1.8), CYAN, "Neon", v(0, top + 41, zb), {
		anim = { kind = "Pulse", period = 1.4, amount = 0.15 },
	})
	add(list, "StationSparkle", "Block", v(30, 1, 6), panel.light, "SmoothPlastic", v(0, top + 18, zb), {
		transparency = 1,
		particle = "Sparkle",
		particleRate = 3,
	})
	-- 도킹 고리 (정거장 뒤 세워진 큰 고리)
	append(
		list,
		MapKitShapes.transform(
			MapKitShapes.ring("DockRing", 22, 2.4, 3, 20, c(150, 136, 210), "Metal", v(0, 0, 0)),
			v(0, top + 18, zb - 26),
			v(90, 0, 0)
		)
	)
	append(
		list,
		MapKitShapes.transform(
			MapKitShapes.ring("DockRingGlow", 22, 0.6, 3.4, 20, NEBULA, "Neon", v(0, 0, 0)),
			v(0, top + 18, zb - 25.8),
			v(90, 0, 0)
		)
	)
	add(list, "DockSparkle", "Block", v(20, 20, 1), panel.light, "SmoothPlastic", v(0, top + 18, zb - 26), {
		transparency = 1,
		particle = "Stardust",
		particleRate = 4,
	})
end

-- ── 중경 ①: 고리 달린 큰 행성 ──────────────────────────────────────────────
local function ringedPlanet(list: { DecorSpec })
	-- 오른쪽(+X) 뒤 하늘 — overview(왼쪽 뒤에서 봄)에서 코스를 가리지 않고, 출발 눈높이에서는 오른쪽 위에 보여요
	local center = v(150, 52, -205)
	local r = 46
	local tilt = v(0, 0, -12)
	local bands = { c(206, 150, 196), c(168, 128, 214), c(232, 188, 214), c(150, 110, 190) }
	local localParts: { DecorSpec } = {}
	table.insert(
		localParts,
		spec("RingPlanet", "Ball", v(r * 2, r * 2, r * 2), c(190, 140, 200), "SmoothPlastic", v(0, 0, 0))
	)
	for i, h in { -26, -10, 8, 24 } do
		local cr = math.sqrt(r * r - h * h)
		table.insert(localParts, disc("RingPlanetBand", cr * 2 + 0.8, 5, bands[i], "SmoothPlastic", 0, h, 0))
	end
	-- 도는 줄무늬 점 (행성 가운데를 지나는 막대 — 양 끝이 표면 위로 살짝 나와서 Spin이 보여요)
	table.insert(
		localParts,
		spec("RingPlanetStorm", "Block", v(r * 2 + 1.2, 6, 10), c(244, 206, 226), "SmoothPlastic", v(0, -4, 0), {
			anim = { kind = "Spin", period = 40 },
		})
	)
	table.insert(localParts, disc("PlanetRing", 210, 0.8, c(150, 120, 220), "SmoothPlastic", 0, 0, 0))
	table.insert(localParts, disc("PlanetRingInner", 160, 1.4, c(196, 176, 244), "SmoothPlastic", 0, 0, 0))
	table.insert(localParts, disc("PlanetRingGap", 132, 2, c(88, 70, 150), "SmoothPlastic", 0, 0, 0))
	append(list, MapKitShapes.transform(localParts, center, tilt))
	-- 고리 근처 작은 달 2개 (Bob)
	add(list, "Moon", "Ball", v(10, 10, 10), c(214, 206, 236), "SmoothPlastic", v(62, 84, -150), {
		anim = { kind = "Bob", period = 7, amount = 2 },
	})
	add(list, "Moon", "Ball", v(6, 6, 6), c(170, 156, 210), "SmoothPlastic", v(236, 20, -250), {
		anim = { kind = "Bob", period = 9, amount = 2.5 },
	})
end

-- ── 중경 ②: 보라 로켓 ─────────────────────────────────────────────────────
local function rocket(list: { DecorSpec })
	local x, base, z = -70, -36, -262
	local purple = MapKitLogic.shades(NEBULA)
	local lilac = c(196, 180, 246)
	local tiltR = v(0, 180, 8) -- 창문(로컬 −X)이 코스(+X) 쪽을 보게 돌리고 살짝 기울여요
	local parts: { DecorSpec } = {}
	local function col(name: string, d: number, h: number, color: RGB, material: string, bottom: number, extra: Extra?)
		column(parts, name, d, h, color, material, 0, bottom, 0, extra)
	end
	col("RocketBody", 16, 44, purple.base, "SmoothPlastic", 0, { reflectance = 0.08 })
	col("RocketBand", 16.6, 3, lilac, "SmoothPlastic", 8)
	col("RocketBand", 16.6, 3, lilac, "SmoothPlastic", 34)
	col("RocketNose", 13, 8, purple.light, "SmoothPlastic", 44)
	col("RocketNose", 9, 6, purple.light, "SmoothPlastic", 52)
	col("RocketNose", 5, 4, lilac, "SmoothPlastic", 58)
	table.insert(parts, spec("RocketTip", "Ball", v(4, 4, 4), CYAN, "Neon", v(0, 62.5, 0)))
	-- 창문 원판 3개 (코스 쪽 −X 면)
	for k, y in { 38, 27, 16 } do
		local d = if k == 1 then 7 else 5.4
		table.insert(
			parts,
			spec("RocketWindowRim", "Cylinder", v(0.8, d + 1.4, d + 1.4), lilac, "Metal", v(-8.0, y, 0))
		)
		table.insert(
			parts,
			spec("RocketWindow", "Cylinder", v(0.8, d, d), c(120, 230, 255), "Neon", v(-8.4, y, 0), {
				light = if k == 1
					then { kind = "Point", color = c(140, 230, 255), brightness = 1.2, range = 20 }
					else nil,
			})
		)
	end
	-- 날개 쐐기 4장
	for k = 0, 3 do
		local a = k * 90 + 45
		local rad = math.rad(a)
		table.insert(
			parts,
			spec(
				"RocketFin",
				"Wedge",
				v(1.4, 14, 10),
				purple.dark,
				"SmoothPlastic",
				v(math.cos(rad) * 11, 6, math.sin(rad) * 11),
				{
					rotation = v(0, -a + 90, 0),
				}
			)
		)
	end
	-- 엔진 + 차가운 청보라 불꽃 (위험 색이 아니에요)
	col("RocketEngine", 10, 4, c(70, 64, 110), "Metal", -4, { reflectance = 0.25 })
	col("RocketEngineBell", 13, 3, c(54, 48, 92), "Metal", -7)
	table.insert(
		parts,
		spec("RocketFlame", "Ball", v(8, 8, 8), c(150, 190, 255), "Neon", v(0, -11, 0), {
			anim = { kind = "Pulse", period = 0.9, amount = 0.15 },
			light = { kind = "Point", color = c(150, 180, 255), brightness = 2, range = 40 },
		})
	)
	table.insert(
		parts,
		spec("RocketExhaust", "Block", v(6, 2, 6), c(150, 190, 255), "SmoothPlastic", v(0, -15, 0), {
			transparency = 1,
			particle = "SteamThick",
			particleRate = 2,
		})
	)
	append(list, MapKitShapes.transform(parts, v(x, base, z), tiltR))
end

-- ── 중경 ④: 코스 밖 장식 회전초밥 레일 (접시 행렬) ─────────────────────────────
local function sushiLoop(list: { DecorSpec })
	-- 1 stud ≈ 1 cm: 회전초밥 접시 지름 10, 초밥 한 점 5.6 (캐릭터와 같은 크기), 레일 폭 12
	local cx, y, cz = -58, 2, -362
	local straight, radius, width = 60, 14, 12
	local track = c(200, 192, 236)
	-- 직선 2개 + 둥근 끝 2개 (조각 고리)
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.roundedBox(
				"LoopTrack",
				v(width, 1.6, straight),
				track,
				"SmoothPlastic",
				v(cx + side * radius, y, cz),
				{ style = "vertical", radius = 0.4 }
			)
		)
		add(
			list,
			"LoopRim",
			"Block",
			v(0.4, 0.5, straight),
			CYAN,
			"Neon",
			v(cx + side * (radius + width / 2 + 0.2), y + 0.55, cz)
		)
		add(
			list,
			"LoopRim",
			"Block",
			v(0.4, 0.5, straight),
			CYAN,
			"Neon",
			v(cx + side * (radius - width / 2 - 0.2), y + 0.55, cz)
		)
	end
	for _, endSign in { -1, 1 } do
		local ez = cz + endSign * straight / 2
		for k = 0, 6 do
			local a = math.rad(k * 30) -- 0..180
			local px, pz = cx + math.cos(a) * radius, ez + endSign * math.sin(a) * radius
			add(list, "LoopTrackCurve", "Block", v(width, 1.6, 7.8), track, "SmoothPlastic", v(px, y, pz), {
				rotation = v(0, -math.deg(a) * endSign, 0),
			})
		end
	end
	-- 레일 아래 받침 + 기둥
	append(
		list,
		MapKitShapes.roundedBox(
			"LoopDeck",
			v(radius * 2 + width + 2, 1.4, straight + 4),
			KEEL,
			"SmoothPlastic",
			v(cx, y - 2, cz),
			{ radius = 0.6 }
		)
	)
	for _, dz in { -18, 18 } do
		column(list, "LoopPylon", 3, 40, c(70, 60, 124), "Metal", cx, y - 42, cz + dz)
	end
	add(list, "LoopLamp", "Ball", v(1.4, 1.4, 1.4), CYAN, "Neon", v(cx, y + 0.3, cz), {
		light = { kind = "Point", color = c(150, 210, 255), brightness = 1.2, range = 26 },
	})
	-- 접시 + 초밥 (각각 한 파츠 — Spin 위상이 파츠 자리로 정해져서 접시·초밥을 따로 돌려요)
	local toppings =
		{ c(250, 128, 82), c(248, 208, 72), c(250, 150, 110), c(196, 40, 52), c(248, 246, 238), c(150, 196, 72) }
	local plates = { c(240, 242, 246), c(150, 120, 220), c(63, 200, 220), c(240, 242, 246) }
	local slots = {}
	for k = 0, 3 do
		table.insert(slots, { cx - radius, cz + straight / 2 - 8 - k * 14.5 })
		table.insert(slots, { cx + radius, cz - straight / 2 + 8 + k * 14.5 })
	end
	for i, s in slots do
		local px, pz = s[1], s[2]
		table.insert(
			list,
			disc(
				"LoopPlate",
				10,
				0.6,
				plates[(i - 1) % #plates + 1],
				"SmoothPlastic",
				px,
				y + 1.1,
				pz,
				{ reflectance = 0.08 }
			)
		)
		add(
			list,
			"LoopNigiri",
			"Block",
			v(3.2, 2.2, 5.6),
			toppings[(i - 1) % #toppings + 1],
			"SmoothPlastic",
			v(px, y + 2.5, pz),
			{
				anim = { kind = "Spin", period = 8 + (i % 3) },
			}
		)
	end
end

-- ── 중경 ⑤: 소행성 징검다리 주변 — 저중력 문, 작은 태양, 떠다니는 초밥 위성·소행성 ──────────
local function nigiri(
	list: { DecorSpec },
	name: string,
	x: number,
	y: number,
	z: number,
	scale: number,
	topping: RGB,
	yaw: number
)
	local parts: { DecorSpec } = {}
	append(
		parts,
		MapKitShapes.roundedBox(
			name .. "Rice",
			v(6 * scale, 3.4 * scale, 10 * scale),
			c(246, 244, 236),
			"SmoothPlastic",
			v(0, 0, 0),
			{ radius = 1.2 * scale }
		)
	)
	append(
		parts,
		MapKitShapes.roundedBox(
			name .. "Topping",
			v(6.6 * scale, 1.4 * scale, 11 * scale),
			topping,
			"SmoothPlastic",
			v(0, 2.3 * scale, 0),
			{ radius = 0.6 * scale, style = "vertical" }
		)
	)
	for _, dz in { -2.2, 2.2 } do
		table.insert(
			parts,
			spec(
				name .. "Stripe",
				"Block",
				v(6.8 * scale, 0.3 * scale, 0.7 * scale),
				shade(topping, 1.25),
				"SmoothPlastic",
				v(0, 3.05 * scale, dz * scale)
			)
		)
	end
	append(list, MapKitShapes.transform(parts, v(x, y, z), v(14, yaw, -10)))
end

local function asteroidBelt(list: { DecorSpec })
	local rocks = MapKitLogic.shades(ROCK)
	-- 판정 소행성 아래 몸통 + 윗면 가장자리 띠
	for i, a in Layout.ASTEROIDS do
		local d = a.radius * 2
		append(
			list,
			MapKitShapes.ring(
				"AsteroidLip",
				a.radius + 0.25,
				0.5,
				0.6,
				12,
				c(150, 136, 196),
				"SmoothPlastic",
				v(a.x, a.top - 0.45, a.z)
			)
		)
		add(
			list,
			"AsteroidBody",
			"Ball",
			v(d * 0.9, d * 0.9, d * 0.9),
			if i % 2 == 0 then rocks.light else rocks.base,
			"Rock",
			v(a.x, a.top - 3.0 - d * 0.3, a.z)
		)
		add(
			list,
			"AsteroidBody",
			"Ball",
			v(d * 0.5, d * 0.5, d * 0.5),
			rocks.base,
			"Rock",
			v(a.x + 1.5, a.top - 3.6 - d * 0.62, a.z - 1)
		)
		add(
			list,
			"AsteroidGlow",
			"Ball",
			v(1.4, 1.4, 1.4),
			c(170, 120, 255),
			"Neon",
			v(a.x - a.radius * 0.5, a.top - 3.4 - d * 0.62, a.z + 1)
		)
	end
	-- 저중력 문 (보라 빛 고리, 입구·출구) — 지나가는 길 위는 높이 12 위
	for _, gz in { -100, -170 } do
		append(
			list,
			MapKitShapes.transform(
				MapKitShapes.ring("GravityGate", 15, 1.0, 1.0, 22, c(168, 120, 255), "Neon", v(0, 0, 0)),
				v(0, 4, gz),
				v(90, 0, 0)
			)
		)
		append(
			list,
			MapKitShapes.transform(
				MapKitShapes.ring("GravityGateFrame", 15, 1.8, 0.6, 22, KEEL, "Metal", v(0, 0, 0)),
				v(0, 4, gz - 0.8),
				v(90, 0, 0)
			)
		)
		add(list, "GravityGateLamp", "Ball", v(1.6, 1.6, 1.6), c(190, 150, 255), "Neon", v(0, 19.6, gz), {
			light = { kind = "Point", color = c(170, 120, 255), brightness = 1.6, range = 34 },
		})
	end
	-- 작은 태양 (따뜻한 흰빛, 좁은 그림자 SpotLight — 소행성 그림자로 높이가 읽혀요)
	add(list, "TinySun", "Ball", v(7, 7, 7), c(255, 236, 196), "Neon", v(-4, 46, -136), {
		light = {
			kind = "Spot",
			color = c(255, 232, 196),
			brightness = 2.6,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
	add(list, "TinySunHalo", "Ball", v(10, 10, 10), c(255, 220, 170), "Glass", v(-4, 46, -136), { transparency = 0.6 })
	-- 별가루 (저중력 구역 안)
	for _, p in { v(-31, 10, -118), v(31, 6, -150) } do
		add(list, "ZoneDust", "Block", v(10, 6, 16), ROCK, "SmoothPlastic", p, {
			transparency = 1,
			particle = "Stardust",
			particleRate = 5,
		})
	end
	-- 떠다니는 초밥 위성
	nigiri(list, "SatSalmon", -44, 22, -118, 1.3, c(250, 128, 82), 30)
	nigiri(list, "SatTamago", 46, 30, -152, 1.5, c(248, 208, 72), -40)
	nigiri(list, "SatTuna", -38, -14, -186, 1.1, c(196, 40, 52), 70)
	-- 떠다니는 소행성 무리 (코스 주변, 무리 지어)
	local more: { DecorSpec } = {}
	append(
		more,
		MapKitShapes.scatter(3521, 34, { center = v(0, 8, -150), size = v(150, 0, 200) }, function(i, pos, rng)
			local s = rng:range(2, 9)
			local y = pos.y + rng:range(-26, 34)
			local col = if i % 3 == 0 then rocks.light elseif i % 3 == 1 then rocks.base else rocks.dark
			local anim: AnimSpec? = if i % 5 == 0 then { kind = "Bob", period = 5 + (i % 4), amount = 1.5 } else nil
			return { spec("FloatRock", "Ball", v(s, s, s), col, "Rock", v(pos.x, y, pos.z), { anim = anim }) }
		end)
	)
	append(
		more,
		MapKitShapes.scatter(3533, 22, { center = v(0, 14, -380), size = v(170, 0, 180) }, function(i, pos, rng)
			local s = rng:range(2, 8)
			local col = if i % 2 == 0 then rocks.base else rocks.dark
			return { spec("FloatRock", "Ball", v(s, s, s), col, "Rock", v(pos.x, pos.y + rng:range(-30, 30), pos.z)) }
		end)
	)
	-- 코스 바로 옆 길에서 너무 가까운 것(가운데 ±20)은 빼서 시야를 막지 않게
	-- 소개 ③(아래에서 올려다보기) 카메라 앞 30 안의 것도 빼요 (렌즈 앞을 막지 않게)
	local filtered: { DecorSpec } = {}
	local cam = INTRO_LOW
	for _, s in more do
		local o = s.offset
		local nearCam = (o.x - cam.x) ^ 2 + (o.y - cam.y) ^ 2 + (o.z - cam.z) ^ 2 < 30 * 30
		if not nearCam and (math.abs(o.x) > 22 or o.y < -12 or o.y > 30) then
			table.insert(filtered, s)
		end
	end
	keepClear(list, filtered)
	-- 소행성 구간 아래 보라 빛 (아래에서 올려다볼 때 바닥 실루엣이 읽히게)
	add(list, "BeltUnderGlow", "Ball", v(3, 3, 3), c(170, 120, 255), "Neon", v(0, -16, -138), {
		light = { kind = "Point", color = c(160, 110, 255), brightness = 2, range = 44 },
		anim = { kind = "Pulse", period = 3.2, amount = 0.1 },
	})
end

-- ── 배경: 행성 표면(배경 바닥), 크레이터, 우주 배경 판, 성운, 별 ─────────────────────
local function background(list: { DecorSpec })
	local gy = SpaceConveyorArt.GROUND_Y
	local surf = MapKitLogic.shades(SURFACE)
	-- 거대 행성 표면 (불투명, 낙하선 −27보다 33 아래)
	add(
		list,
		SpaceConveyorArt.GROUND,
		"Block",
		v(1300, 4, 1560),
		surf.base,
		"Slate",
		v(0, gy - 2, -260),
		{ castShadow = false }
	)
	-- 큰 크레이터 (rimDisc) + 작은 크레이터 (두 원판)
	for i, p in { { -60, -60, 70 }, { 70, -190, 90 }, { -80, -330, 80 }, { 60, -470, 64 } } do
		append(
			list,
			MapKitShapes.rimDisc(
				"Crater",
				p[3],
				0.6,
				if i % 2 == 0 then surf.dark else shade(SURFACE, 0.85),
				"Slate",
				v(p[1], gy + 0.3, p[2]),
				{
					rimColor = surf.light,
					rimWidth = 4,
					rimHeight = 2.4,
					segments = 14,
				}
			)
		)
	end
	local rng = MapKitShapes.rng(3541)
	for i = 0, 15 do
		local x = rng:range(-260, 260)
		local z = rng:range(-760, 200)
		if math.abs(x) < 40 then
			x += if x < 0 then -50 else 50
		end
		local d = rng:range(14, 36)
		table.insert(list, disc("SmallCrater", d, 0.8, surf.light, "Slate", x, gy + 0.4, z))
		table.insert(list, disc("SmallCraterBowl", d * 0.72, 0.9, surf.dark, "Slate", x, gy + 0.5, z))
		local _ = i
	end
	-- 표면의 둥근 바위 언덕 (멀리 실루엣, 반쯤 잠긴 큰 공 + 작은 공, 3 shade)
	local hills = {
		{ -190, -60, 90 },
		{ 210, -40, 100 },
		{ -230, -320, 110 },
		{ 250, -420, 80 },
		{ -170, -600, 120 },
		{ 190, -680, 96 },
	}
	for i, m in hills do
		local x, z, d = m[1], m[2], m[3]
		add(
			list,
			"Hill",
			"Ball",
			v(d, d, d),
			if i % 2 == 0 then surf.dark else surf.base,
			"Slate",
			v(x, gy - d * 0.22, z),
			{ castShadow = false }
		)
		local s2 = d * 0.55
		add(
			list,
			"Hill",
			"Ball",
			v(s2, s2, s2),
			surf.light,
			"Slate",
			v(x + d * 0.38, gy - s2 * 0.12, z + d * 0.2),
			{ castShadow = false }
		)
		local s3 = d * 0.3
		add(
			list,
			"HillRock",
			"Ball",
			v(s3, s3, s3),
			shade(SURFACE, 1.2),
			"Rock",
			v(x - d * 0.42, gy + s3 * 0.1, z - d * 0.25)
		)
	end
	-- 지평선 위로 떠오른 거대 행성 (결승 쪽 하늘, 표면에 반쯤 잠김)
	add(
		list,
		"HorizonPlanet",
		"Ball",
		v(440, 440, 440),
		c(66, 88, 156),
		"SmoothPlastic",
		v(140, -150, -900),
		{ castShadow = false }
	)
	add(
		list,
		"HorizonPlanetBand",
		"Cylinder",
		v(30, 444, 444),
		c(86, 110, 182),
		"SmoothPlastic",
		v(140, -10, -900),
		{ rotation = UPRIGHT, castShadow = false }
	)
	add(
		list,
		"HorizonPlanetBand",
		"Cylinder",
		v(18, 430, 430),
		c(58, 76, 140),
		"SmoothPlastic",
		v(140, -64, -900),
		{ rotation = UPRIGHT, castShadow = false }
	)
	-- 멀리 어두운 우주 배경 판 (불투명 남색, 안개가 멀리서 하늘과 이어줘요)
	local wallH = 560
	local wy = gy + wallH / 2 - 4
	add(
		list,
		"SpaceBackdrop",
		"Block",
		v(1320, wallH, 6),
		NAVY,
		"SmoothPlastic",
		v(0, wy, -1040),
		{ castShadow = false }
	)
	add(
		list,
		"SpaceBackdrop",
		"Block",
		v(1320, wallH, 6),
		NAVY_DEEP,
		"SmoothPlastic",
		v(0, wy, 520),
		{ castShadow = false }
	)
	add(
		list,
		"SpaceBackdrop",
		"Block",
		v(6, wallH, 1560),
		NAVY,
		"SmoothPlastic",
		v(-660, wy, -260),
		{ castShadow = false }
	)
	add(
		list,
		"SpaceBackdrop",
		"Block",
		v(6, wallH, 1560),
		NAVY_DEEP,
		"SmoothPlastic",
		v(660, wy, -260),
		{ castShadow = false }
	)
	-- 보라 성운 (배경 판 앞에 겹친 원판 무리, 불투명)
	local nebulaShades = { NEBULA, c(150, 100, 230), c(96, 64, 180), c(170, 96, 200), c(80, 70, 190) }
	local clouds = {
		{ -1034, -120, 140, 1 },
		{ -1034, 160, 190, -1 },
		{ -1034, 420, 120, 1 },
	}
	for ci, cl in clouds do
		local wz, cxv, cyv = cl[1], cl[2], cl[3]
		local crng = MapKitShapes.rng(3600 + ci)
		for k = 0, 8 do
			local d = crng:range(60, 150) * (if k == 0 then 1.4 else 1)
			local ox, oy = crng:range(-110, 110), crng:range(-50, 60)
			add(
				list,
				"Nebula",
				"Cylinder",
				v(1, d, d),
				nebulaShades[(k + ci) % #nebulaShades + 1],
				"SmoothPlastic",
				v(cxv + ox, cyv + oy, wz + k * 0.6),
				{ rotation = v(0, 90, 0), castShadow = false }
			)
		end
	end
	-- 옆 배경 판 성운 (왼쪽 고리 행성 뒤)
	local srng = MapKitShapes.rng(3651)
	for k = 0, 7 do
		local d = srng:range(70, 160)
		add(
			list,
			"Nebula",
			"Cylinder",
			v(1, d, d),
			nebulaShades[k % #nebulaShades + 1],
			"SmoothPlastic",
			v(-654 + k * 0.6, srng:range(40, 260), srng:range(-500, 0)),
			{ castShadow = false }
		)
	end
	-- 별 (작은 Neon 점, 무리 지어 — 몇 개는 깜빡여요)
	local starRng = MapKitShapes.rng(3667)
	for i = 0, 99 do
		local onSide = i % 4 == 0
		local x, y, z
		if onSide then
			x = if i % 8 == 0 then -650 else 650
			y = starRng:range(20, 480)
			z = starRng:range(-1000, 480)
		else
			x = starRng:range(-640, 640)
			y = starRng:range(30, 490)
			z = if i % 5 == 0 then 510 else -1030
		end
		local s = starRng:range(1.2, 3.4)
		local tint = if i % 7 == 0 then c(190, 230, 255) elseif i % 5 == 0 then c(220, 200, 255) else STAR
		local anim: AnimSpec? = if i % 17 == 0
			then { kind = "Pulse", period = 2 + (i % 5) * 0.4, amount = 0.15 }
			else nil
		add(list, "Star", "Ball", v(s, s, s), tint, "Neon", v(x, y, z), { castShadow = false, anim = anim })
	end
end

function SpaceConveyorArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	railTrim(list)
	hubTrim(list)
	launchPad(list)
	meteorField(list)
	twinRails(list)
	landing(list)
	finishArch(list)
	station(list)
	ringedPlanet(list)
	rocket(list)
	sushiLoop(list)
	asteroidBelt(list)
	background(list)
	local _ = mix
	return list
end

-- ① 고리 행성 너머로 S자 레일 전체 → ② 화살표가 바뀌는 레일 클로즈업 → ③ 소행성 구간을 아래에서 올려다보기
-- → ④ 정거장 결승 → ⑤ 출발 발사대. 전부 아레나 상자 + 40 안, 지오메트리를 뚫지 않게.
function SpaceConveyorArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-44, 36, 18), lookAt = v(30, 6, -120) },
		{ pos = v(14, 6, -38), lookAt = v(2, 0, -52) },
		{ pos = INTRO_LOW, lookAt = v(-4, 4, -146) },
		{ pos = v(24, 26, -412), lookAt = v(0, 18, -468) },
		{ pos = v(0, 12, 24), lookAt = v(0, 3, -40) },
	}
end

return SpaceConveyorArt
