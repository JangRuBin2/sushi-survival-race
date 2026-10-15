--!strict
-- "찻잎 정원" 아트 데이터 (m5-38, docs/REFERENCE-map-art-direction.md). Roblox API를 쓰지 않아요 — lune에서 바로 불러요.
-- 컨셉: 해 질 녘 벚꽃 아래 분재 차밭 정원. 1 stud ≈ 1 cm — 지름 94 정원 = 1 m 분재 정원 쟁반, 찻사발 지름 13,
-- 찻주전자 높이 30~40. 정원은 받침 기둥 위에 떠 있고, 아래(−40)는 이끼 땅·시냇물·다리·석등, 둘레에 벚꽃·찻주전자·정자.
-- 좌표는 map origin(정원 중심, 5단 윗면 = y 0) 기준 로컬. 낙하 탈락선 y −25, 배경 바닥(이끼 −41, 시냇물 −40.4)은 10 이상 아래.
--   TeaGardenArt.decor() -> { DecorSpec }                    정적 장식 전부 (충돌 없음)
--   TeaGardenArt.terraceDecor(ring, index) -> { DecorSpec }  차밭 조각 하나의 장식 (조각 Model 안 — 같이 무너져요, anim 없음)
--   TeaGardenArt.cupDecor() -> { DecorSpec }                 굴러가는 찻잔 무늬 (찻잔 중심 기준, 로컬 X = 찻잔 축, anim 없음)
--   TeaGardenArt.introCamera() -> { IntroPoint }             노을 넓은 샷 → 찻사발·찻잔 → 벚꽃 아래 반전 → 바깥 5단 → 출발 자리
--   TeaGardenArt.COLORS                                      판정 파츠·경고·찻잔 색 (TeaGarden이 씀)
--   TeaGardenArt.LIGHTING / BUDGET = "Extended"
--   TeaGardenArt.SIGHT_MIN / SIGHT_MAX                       단 윗면 위 이 높이 사이(밟는 면 시야)는 장식이 가리면 안 돼요

local Layout = require(script.Parent.TeaGardenLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type LightSpec = MapKitLogic.LightSpec
type AnimSpec = MapKitLogic.AnimSpec

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local TeaGardenArt = {}

TeaGardenArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
TeaGardenArt.SIGHT_MIN = 2
TeaGardenArt.SIGHT_MAX = 12
TeaGardenArt.GROUND_Y = -41 -- 이끼 땅 윗면 (낙하 탈락선 −25보다 16 아래)
TeaGardenArt.STREAM_Y = -40.4 -- 시냇물 윗면
TeaGardenArt.PREVIEW_CUP_ANGLE = math.rad(58) -- 소개 카메라에 보이게 1단에 세워 둔 찻잔 각도

local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 색 ───────────────────────────────────────────────────────────────
local TEA = c(95, 163, 74) -- 히어로: 녹차 초록 #5FA34A
local SAKURA = c(244, 198, 210) -- 히어로: 옅은 벚꽃 분홍 #F4C6D2
local SAKURA_DEEP = c(232, 168, 186)
local SAKURA_PALE = c(250, 226, 232)
local HEDGE = c(58, 112, 52) -- 차나무 이랑 (윗면보다 어둡게)
local HEDGE_DARK = c(40, 84, 40)
local SOIL = c(104, 82, 62)
local STONE = c(128, 122, 112)
local STONE_DARK = c(92, 88, 82)
local MOSS = c(70, 98, 56)
local MOSS_DARK = c(52, 76, 44)
local BARK = c(98, 72, 58)
local BARK_DARK = c(80, 58, 48)
local GLAZE = c(52, 122, 82) -- 찻사발 초록 유약
local GLAZE_LIGHT = c(118, 172, 108)
local GLAZE_DARK = c(44, 104, 76)
local POT = c(52, 112, 84) -- 찻주전자 짙은 초록 도자기
local POT_LIGHT = c(104, 162, 120)
local POT_DARK = c(30, 74, 58)
local MATCHA = c(140, 186, 72)
local FOAM = c(196, 220, 140)
local SHRINE_RED = c(150, 72, 62) -- 정자 빨강 (채도 중간, Neon 아님)
local SHRINE_RED_DARK = c(110, 52, 46)
local ROOF = c(58, 62, 66)
local WOOD = c(150, 112, 78)
local WOOD_DARK = c(106, 78, 54)
local WATER = c(76, 142, 156) -- 차가운 청록 시냇물
local WATER_DEEP = c(52, 108, 128)
local TRAY = c(52, 118, 128) -- 정원 쟁반 (청록 유약, 차가운 그늘색)
local LANTERN_GLOW = c(255, 196, 120)
local BRONZE = c(156, 116, 62)
local MOUNTAIN = c(132, 112, 146)
local MOUNTAIN_FAR = c(170, 140, 166)

-- 판정 파츠·경고·찻잔 색 (TeaGarden이 씀). 단 윗면은 안쪽일수록 밝아요 (계단이 읽히게).
TeaGardenArt.COLORS = {
	ringTop = {
		c(138, 200, 104),
		c(118, 186, 90),
		TEA,
		c(84, 146, 66),
		c(74, 132, 60),
	},
	warn = c(255, 90, 36), -- 무너짐 경고 주황-빨강
	warnBlink = c(255, 168, 92),
	warnBorder = c(255, 255, 255),
	cup = c(246, 247, 250), -- 흰 도자기 찻잔
	cupPattern = c(34, 52, 120), -- 진한 남색 무늬
	cupGlow = c(255, 222, 60), -- 단 옮기기 경고 노랑
	bowlGlow = c(255, 214, 120), -- 새 찻잔이 나오기 전 찻사발 아래 빛
}

-- 맵 조명: 황금 시간(17.3), 따뜻한 앰비언트, 복숭아-분홍 안개, 살짝 채도 올림
local LIGHTING: MapLighting.LightingPreset = {
	ClockTime = 17.3,
	Brightness = 2.3,
	Ambient = c(140, 120, 110),
	OutdoorAmbient = c(156, 132, 128),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.7,
	ShadowSoftness = 0.3,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.12,
		Color = c(255, 202, 186),
		Decay = c(150, 108, 140),
		Glare = 0.3,
		Haze = 1.4,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.08, Saturation = 0.08, TintColor = c(255, 244, 236) },
	Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.3 },
	SunRays = { Intensity = 0.05, Spread = 0.7 },
}
TeaGardenArt.LIGHTING = LIGHTING

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로

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
	local e: Extra = extra or {}
	table.insert(list, {
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
	})
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

local function ball(list: { DecorSpec }, name: string, d: number, color: RGB, material: string, p: Vec3, extra: Extra?)
	add(list, name, "Ball", v(d, d, d), color, material, p, extra)
end

-- 두 점 사이 원기둥 (축 = 로컬 X). CFrame.Angles(0, ry, rz): X → (cos rz·cos ry, sin rz, −cos rz·sin ry)
local function between(
	list: { DecorSpec },
	name: string,
	from: Vec3,
	to: Vec3,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	local rz = math.deg(math.asin(math.clamp(dy / length, -1, 1)))
	local ry = math.deg(math.atan2(-dz, dx))
	local e: Extra = extra or {}
	e.rotation = v(0, ry, rz)
	add(
		list,
		name,
		"Cylinder",
		v(length, d, d),
		color,
		material,
		v((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2),
		e
	)
end

local function polar(r: number, deg: number, y: number): Vec3
	local x, z = Layout.polar(r, math.rad(deg))
	return v(x, y, z)
end

-- ── 차밭 조각 장식 (조각 Model 안, 같이 무너져요) ─────────────────────────────
-- 조각 로컬(x = 이등분선 바깥, z = 접선)로 만들고 이등분선 각도만큼 돌려요.
function TeaGardenArt.terraceDecor(ring: number, index: number): { DecorSpec }
	local def = Layout.RINGS[ring]
	local half = Layout.SLICE_ANGLE / 2
	local near = def.inner * math.cos(half)
	local far = def.outer * math.cos(half)
	local width = 2 * def.outer * math.sin(half)
	local top = def.top
	local list: { DecorSpec } = {}
	local hedge = if index % 2 == 0 then HEDGE else mix(HEDGE, HEDGE_DARK, 0.35)
	-- 바깥 옆면 차나무 이랑: 둥근 덤불 3개 + 뒤 립 (윗면보다 0.15 낮게)
	add(list, "HedgeRib", "Cylinder", v(width * 0.98, 1.0, 1.0), HEDGE_DARK, "Grass", v(far + 0.2, top - 0.65, 0), {
		rotation = v(0, 90, 0),
	})
	for k = 0, 3 do
		local tint = if k % 2 == 0 then hedge else shade(hedge, 1.12)
		ball(list, "HedgeBush", 1.3, tint, "Grass", v(far + 0.3, top - 0.82, (k - 1.5) * width * 0.24))
	end
	if ring < Layout.RING_COUNT then
		-- 흙·돌 옆면 (바깥 단에 가려 있다가 그 단이 무너지면 보여요)
		local bandTop = top - Layout.STEP - 0.05
		local h = bandTop - Layout.BASE_Y
		add(
			list,
			"SoilBand",
			"Block",
			v(0.4, h, width * 0.99),
			if index % 2 == 0 then SOIL else shade(SOIL, 0.88),
			"Slate",
			v(far + 0.15, bandTop - h / 2, 0)
		)
	else
		-- 가장 바깥: 짙은 청록 유약 정원 쟁반 벽 + 테두리 립 (윗면보다 0.2 낮게)
		add(
			list,
			"TrayWall",
			"Block",
			v(0.8, 6.8, width * 1.0),
			if index % 2 == 0 then TRAY else shade(TRAY, 1.12),
			"SmoothPlastic",
			v(far + 0.45, -0.2 - 3.4, 0),
			{ reflectance = 0.08 }
		)
		-- 쟁반 물결 띠 (크림색 두 줄)
		for _, yy in { -2.4, -4.6 } do
			add(
				list,
				"TrayPattern",
				"Block",
				v(0.1, 0.45, width * 0.98),
				c(232, 222, 190),
				"SmoothPlastic",
				v(far + 0.9, yy, 0)
			)
		end
		add(
			list,
			"TrayLip",
			"Block",
			v(1.3, 0.4, width * 1.02),
			shade(TRAY, 0.8),
			"SmoothPlastic",
			v(far + 0.6, -0.4, 0),
			{
				reflectance = 0.1,
			}
		)
	end
	-- 윗면 이랑 줄 (윗면에 붙은 얇은 선, 무늬만)
	for _, f in { 0.36, 0.7 } do
		local x = near + (far - near) * f
		add(
			list,
			"RowLine",
			"Block",
			v(0.22, 0.05, 2 * x * math.tan(half) * 0.96),
			shade(TeaGardenArt.COLORS.ringTop[ring], 0.86),
			"Grass",
			v(x, top + 0.02, 0)
		)
	end
	local angle = Layout.sliceAngle(index)
	return MapKitShapes.transform(list, v(0, 0, 0), v(0, -math.deg(angle), 0))
end

-- ── 굴러가는 찻잔 무늬 (찻잔 중심 기준, 로컬 X = 축, +X = 입구가 정원 바깥) ──────────
function TeaGardenArt.cupDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local w, d = 4, 6
	local navy = TeaGardenArt.COLORS.cupPattern
	-- 남색 띠 두 줄 + 입구 테두리 + 안쪽 녹차 + 굽
	for _, x in { -0.9, 0.7 } do
		add(list, "CupBand", "Cylinder", v(0.35, d + 0.08, d + 0.08), navy, "SmoothPlastic", v(x, 0, 0), {
			reflectance = 0.08,
		})
	end
	add(list, "CupRim", "Cylinder", v(0.25, d + 0.12, d + 0.12), navy, "SmoothPlastic", v(w / 2 - 0.1, 0, 0))
	add(list, "CupTea", "Cylinder", v(0.06, d - 0.9, d - 0.9), MATCHA, "SmoothPlastic", v(w / 2 + 0.02, 0, 0))
	add(
		list,
		"CupFoot",
		"Cylinder",
		v(0.5, d * 0.62, d * 0.62),
		c(226, 222, 212),
		"SmoothPlastic",
		v(-w / 2 - 0.2, 0, 0)
	)
	-- 남색 점 무늬 (축 둘레 4개)
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		add(
			list,
			"CupDot",
			"Ball",
			v(0.8, 0.8, 0.8),
			navy,
			"SmoothPlastic",
			v(-0.1, math.cos(a) * (d / 2 - 0.15), math.sin(a) * (d / 2 - 0.15))
		)
	end
	return list
end

-- ── 정적 장식 ─────────────────────────────────────────────────────────

-- 가운데 초록 유약 찻사발 (지름 13 — 판정 심 반지름 7 안) + 받침 기둥
local function bowl(list: { DecorSpec })
	local y0 = Layout.RINGS[1].top
	column(list, "BowlFoot", 7, 1.0, c(196, 170, 130), "Sandstone", 0, y0, 0)
	-- 아래가 좁고 위가 넓은 찻사발 몸통 (원기둥 5단)
	type Row = { d: number, h: number, color: RGB }
	local rows: { Row } = {
		{ d = 8.0, h = 0.8, color = GLAZE_DARK },
		{ d = 10.2, h = 1.2, color = GLAZE_DARK },
		{ d = 11.8, h = 1.8, color = GLAZE },
		{ d = 12.7, h = 2.6, color = GLAZE },
		{ d = 13.0, h = 2.8, color = GLAZE_LIGHT },
	}
	local y = y0 + 1
	for _, row in rows do
		column(list, "BowlBody", row.d, row.h, row.color, "SmoothPlastic", 0, y, 0, { reflectance = 0.14 })
		y += row.h
	end
	append(
		list,
		MapKitShapes.ring("BowlRim", 6.15, 0.6, 0.6, 28, shade(GLAZE_LIGHT, 1.15), "SmoothPlastic", v(0, y0 + 10.2, 0))
	)
	-- 유약 흘러내림 (짧은 캡슐들)
	for k = 0, 7 do
		local a = k * 45 + 10
		local p = polar(6.45, a, y0 + 8.2)
		local len = 1.8 + (k % 3) * 0.6
		append(
			list,
			MapKitShapes.capsule("GlazeDrip", len, 0.7, shade(GLAZE_LIGHT, 1.1), "SmoothPlastic", p, v(0, 0, 90))
		)
	end
	-- 녹차 + 거품 (천천히 도는 소용돌이 — 고정 자리 장식이라 Spin 허용)
	column(list, "BowlTea", 11.4, 0.3, MATCHA, "SmoothPlastic", 0, y0 + 9.5, 0, { reflectance = 0.05 })
	add(list, "TeaSwirl", "Block", v(8.6, 0.12, 1.2), FOAM, "SmoothPlastic", v(0, y0 + 9.86, 0), {
		anim = { kind = "Spin", period = 9 },
	})
	add(list, "TeaSwirl", "Block", v(1.0, 0.1, 6.0), shade(FOAM, 1.08), "SmoothPlastic", v(0, y0 + 9.88, 0), {
		anim = { kind = "Spin", period = 13 },
	})
	ball(list, "TeaSteam", 1, FOAM, "SmoothPlastic", v(0, y0 + 10.5, 0), {
		transparency = 1,
		particle = "Steam",
		particleRate = 2,
	})
	-- 받침 기둥 (정원 아래, 판정 심 반지름 안) + 뿌리
	column(list, "Pedestal", 9, 34, BARK, "Wood", 0, TeaGardenArt.GROUND_Y, 0)
	column(list, "PedestalCap", 13, 2, STONE_DARK, "Slate", 0, Layout.BASE_Y - 2, 0)
	for k = 0, 4 do
		local a = k * 72 + 20
		between(
			list,
			"Root",
			polar(3, a, TeaGardenArt.GROUND_Y + 4),
			polar(14, a + 12, TeaGardenArt.GROUND_Y + 0.4),
			2.6,
			BARK_DARK,
			"Wood"
		)
	end
end

-- 찻주전자 (짙은 초록 도자기, 높이 약 34). 로컬로 만들고 transform으로 놓아요 (pour면 기울여 시냇물에 따라요).
local function teapot(list: { DecorSpec }, at: Vec3, yaw: number, tilt: number, pour: boolean)
	local local_: { DecorSpec } = {}
	-- 몸통: 큰 공 + 어깨 띠 + 굽
	ball(local_, "PotBody", 26, POT, "SmoothPlastic", v(0, 13, 0), { reflectance = 0.12 })
	column(local_, "PotFoot", 16, 2, POT_DARK, "SmoothPlastic", 0, 0, 0, { reflectance = 0.1 })
	append(local_, MapKitShapes.ring("PotBand", 12.3, 0.8, 1.6, 24, POT_LIGHT, "SmoothPlastic", v(0, 16, 0)))
	column(local_, "PotNeck", 13, 2.4, POT_DARK, "SmoothPlastic", 0, 24.6, 0, { reflectance = 0.1 })
	column(local_, "PotLid", 11, 1.6, POT_LIGHT, "SmoothPlastic", 0, 26.6, 0, { reflectance = 0.12 })
	ball(local_, "PotKnob", 3.4, shade(POT_LIGHT, 1.2), "SmoothPlastic", v(0, 29.4, 0), { reflectance = 0.15 })
	-- 주둥이 (+X 쪽으로 비스듬히)
	between(local_, "PotSpout", v(10, 10, 0), v(19, 19, 0), 3.6, POT, "SmoothPlastic", { reflectance = 0.12 })
	ball(local_, "PotSpout", 3.6, POT, "SmoothPlastic", v(19, 19, 0), { reflectance = 0.12 })
	-- 손잡이 (−X 쪽, 세운 고리 반)
	for k = 0, 6 do
		local a0 = math.rad(-75 + k * 25)
		local a1 = math.rad(-75 + (k + 1) * 25)
		between(
			local_,
			"PotHandle",
			v(-11 - math.cos(a0) * 6.5, 14 + math.sin(a0) * 7, 0),
			v(-11 - math.cos(a1) * 6.5, 14 + math.sin(a1) * 7, 0),
			2.2,
			POT_DARK,
			"SmoothPlastic",
			{ reflectance = 0.1 }
		)
	end
	-- 김 (주둥이 끝) — 숨 쉬듯 Pulse
	ball(local_, "PotSteam", 2.4, c(250, 246, 240), "SmoothPlastic", v(20.5, 21.5, 0), {
		transparency = 0.55,
		particle = "Steam",
		particleRate = 2,
		anim = { kind = "Pulse", period = 3.2, amount = 0.12 },
	})
	if pour then
		-- 찻물 줄기: 주둥이에서 시냇물까지 (반투명 차색)
		ball(local_, "PourDrop", 2.4, c(176, 160, 70), "Glass", v(21, 18.6, 0), { transparency = 0.25 })
	end
	append(list, MapKitShapes.transform(local_, at, v(0, yaw, tilt)))
end

local function teapots(list: { DecorSpec })
	-- 이끼 바위 받침 (땅에서 솟은 바위섬)
	-- 이끼 바위 받침: 땅에서 솟은 바위 기둥 + 살짝 기운 바위 판 (윗면 topY)
	local function rockIsland(x: number, z: number, topY: number, d: number)
		-- 큰 이끼 언덕 위에 앉은 바위 (땅에서 솟은 기둥 대신)
		ball(list, "RockHill", 72, MOSS_DARK, "Grass", v(x, topY - 4 - 36, z))
		append(
			list,
			MapKitShapes.bevelBox("RockSlab", v(d * 1.15, 4, d), STONE, "Rock", v(x, topY - 2.2, z), 1.2, v(4, 18, -3))
		)
		append(
			list,
			MapKitShapes.bevelBox(
				"RockSlab",
				v(d * 0.8, 5, d * 0.7),
				shade(STONE, 0.86),
				"Rock",
				v(x + d * 0.3, topY - 5.5, z - d * 0.25),
				1.2,
				v(-6, -24, 5)
			)
		)
		column(list, "RockMoss", d * 0.85, 0.8, MOSS, "Grass", x, topY - 0.4, z)
	end
	-- A: 서쪽, 정원 쪽으로 주둥이 (가만히 김)
	rockIsland(-80, 14, -10, 22)
	teapot(list, v(-80, -9, 14), -150, 0, false)
	-- B: 동쪽 뒤, 시냇물로 찻물을 붓는 모습 (기울임)
	rockIsland(76, -40, -12, 20)
	teapot(list, v(76, -11, -40), 120, -24, true)
	-- 찻물 줄기 → 시냇물
	between(list, "PourStream", v(62, 4, -18), v(60, TeaGardenArt.STREAM_Y, -10), 1.6, c(170, 152, 70), "Glass", {
		transparency = 0.3,
		reflectance = 0.1,
	})
end

-- 벚꽃나무 (분재 — 땅에서 50~60 높이). 줄기 2~3 마디 + 분홍 둥근 수관 무리 + 흔들리는 가지 끝
local function cherry(list: { DecorSpec }, base: Vec3, height: number, lean: number, seed: number)
	local rng = MapKitShapes.rng(seed)
	local a = math.rad(lean)
	local mid = v(base.x + math.cos(a) * 4, base.y + height * 0.55, base.z + math.sin(a) * 4)
	local topP = v(base.x + math.cos(a) * 9, base.y + height, base.z + math.sin(a) * 9)
	between(list, "Trunk", base, mid, 5.2, BARK, "Wood")
	between(list, "Trunk", mid, topP, 3.8, BARK_DARK, "Wood")
	ball(list, "TrunkKnot", 5.4, BARK, "Wood", mid)
	-- 가지 3개
	for k = 0, 2 do
		local ba = a + math.rad(-100 + k * 100 + rng:range(-15, 15))
		local tip = v(topP.x + math.cos(ba) * 11, topP.y + rng:range(-2, 4), topP.z + math.sin(ba) * 11)
		between(list, "Branch", topP, tip, 1.8, BARK_DARK, "Wood")
		-- 수관 덩어리
		ball(list, "Blossom", rng:range(10, 13), SAKURA, "SmoothPlastic", v(tip.x, tip.y + 2, tip.z), {
			anim = if k == 1 then { kind = "Bob", period = 5.5, amount = 0.35 } else nil,
		})
		ball(
			list,
			"Blossom",
			rng:range(7, 9),
			SAKURA_PALE,
			"SmoothPlastic",
			v(tip.x + rng:range(-3, 3), tip.y + 5.5, tip.z + rng:range(-3, 3))
		)
		ball(
			list,
			"Blossom",
			rng:range(6, 8),
			SAKURA_DEEP,
			"SmoothPlastic",
			v(tip.x + rng:range(-4, 4), tip.y - 2, tip.z + rng:range(-4, 4))
		)
		-- 흔들리는 가지 끝 잔가지 + 꽃송이 (잔가지만 Sway, 꽃은 그대로)
		local twigTip = v(tip.x + math.cos(ba) * 5, tip.y - 1.5, tip.z + math.sin(ba) * 5)
		add(
			list,
			"BlossomTwig",
			"Cylinder",
			v(5, 0.6, 0.6),
			BARK_DARK,
			"Wood",
			v((tip.x + twigTip.x) / 2, (tip.y + twigTip.y) / 2, (tip.z + twigTip.z) / 2),
			{
				rotation = v(0, -math.deg(ba), -17),
				anim = { kind = "Sway", period = 4.5 + k, amount = 6, axis = "Y" },
			}
		)
		ball(list, "Blossom", 3.6, SAKURA_DEEP, "SmoothPlastic", twigTip)
	end
	ball(list, "Blossom", 14, SAKURA, "SmoothPlastic", v(topP.x, topP.y + 5, topP.z), {
		particle = if seed % 2 == 1 then "Petals" else nil,
		particleRate = if seed % 2 == 1 then 3 else nil,
	})
	ball(list, "Blossom", 9, SAKURA_PALE, "SmoothPlastic", v(topP.x + 3, topP.y + 10, topP.z - 2))
end

local function cherries(list: { DecorSpec })
	local g = TeaGardenArt.GROUND_Y
	-- 다리 쪽(+Z) 무리
	cherry(list, v(48, g, 74), 50, 200, 1)
	cherry(list, v(70, g, 58), 44, 225, 2)
	-- 서쪽 찻주전자 옆
	cherry(list, v(-66, g, -46), 52, 40, 3)
	cherry(list, v(-62, g, 62), 46, -40, 5)
	-- 뒤 정자 옆
	cherry(list, v(34, g, -82), 56, 110, 7)
	-- 소개 ③용: 다리 옆에서 정원 쪽으로 기운 나무 (수관이 화면 위를 덮어요)
	cherry(list, v(66, g, 70), 50, 222, 9)
end

-- 붉은 정자 (뒤쪽 −Z 언덕 위) + 문
local function pavilion(list: { DecorSpec })
	local cx, cz = 0, -104
	local floorY = -14
	-- 언덕
	column(list, "Hill", 46, floorY - TeaGardenArt.GROUND_Y - 1, MOSS_DARK, "Grass", cx, TeaGardenArt.GROUND_Y, cz)
	column(list, "Hill", 60, 10, MOSS, "Grass", cx, TeaGardenArt.GROUND_Y, cz + 2)
	append(list, MapKitShapes.bevelBox("PavilionDeck", v(24, 2, 24), WOOD_DARK, "WoodPlanks", v(cx, floorY, cz), 0.6))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(
				list,
				"PavilionPillar",
				1.8,
				16,
				SHRINE_RED,
				"SmoothPlastic",
				cx + sx * 9.5,
				floorY + 1,
				cz + sz * 9.5
			)
		end
	end
	-- 보 (가로)
	for _, sz in { -1, 1 } do
		append(
			list,
			MapKitShapes.capsule(
				"PavilionBeam",
				23,
				1.4,
				SHRINE_RED_DARK,
				"SmoothPlastic",
				v(cx, floorY + 16.6, cz + sz * 9.5)
			)
		)
	end
	for _, sx in { -1, 1 } do
		append(
			list,
			MapKitShapes.capsule(
				"PavilionBeam",
				23,
				1.4,
				SHRINE_RED_DARK,
				"SmoothPlastic",
				v(cx + sx * 9.5, floorY + 16.6, cz),
				v(0, 90, 0)
			)
		)
	end
	-- 지붕: 쐐기 4장 + 용마루
	local roofY = floorY + 20
	-- 쐐기의 낮은 앞(−Z)이 바깥을 보게: { 바깥 x, 바깥 z, yaw }
	for _, side in { { 0, -1, 0 }, { 1, 0, -90 }, { 0, 1, 180 }, { -1, 0, 90 } } do
		add(
			list,
			"PavilionRoof",
			"Wedge",
			v(31, 5.5, 15.5),
			ROOF,
			"ClayRoofTiles",
			v(cx + side[1] * 7.75, roofY, cz + side[2] * 7.75),
			{ rotation = v(0, side[3], 0) }
		)
		-- 처마 끝 빨간 띠
		add(
			list,
			"PavilionEave",
			"Block",
			if side[1] == 0 then v(31, 0.8, 0.8) else v(0.8, 0.8, 31),
			SHRINE_RED_DARK,
			"SmoothPlastic",
			v(cx + side[1] * 15.4, roofY - 2.6, cz + side[2] * 15.4)
		)
	end
	add(list, "PavilionRidge", "Block", v(6, 1.4, 6), shade(ROOF, 0.8), "SmoothPlastic", v(cx, roofY + 3, cz))
	ball(list, "PavilionFinial", 2.2, BRONZE, "Metal", v(cx, roofY + 4.4, cz), { reflectance = 0.2 })
	-- 처마 등 (보이는 광원)
	for _, sx in { -1, 1 } do
		ball(list, "PavilionLantern", 2.6, LANTERN_GLOW, "Neon", v(cx + sx * 9.5, floorY + 14.2, cz + 10.5), {
			light = { kind = "Point", color = LANTERN_GLOW, brightness = 1.4, range = 18 },
			anim = { kind = "Bob", period = 4, amount = 0.15 },
		})
	end
	-- 문 (정자로 가는 길)
	local gz = -80
	for _, sx in { -1, 1 } do
		column(list, "GatePillar", 2.4, 44, SHRINE_RED, "SmoothPlastic", sx * 9, TeaGardenArt.GROUND_Y, gz)
	end
	-- 위 보는 양 끝이 살짝 들린 모양 (가운데 캡슐 + 끝 쐐기), 아래 보는 캡슐
	append(
		list,
		MapKitShapes.capsule(
			"GateBeam",
			24,
			2.2,
			SHRINE_RED_DARK,
			"SmoothPlastic",
			v(0, TeaGardenArt.GROUND_Y + 44.5, gz)
		)
	)
	for _, sx in { -1, 1 } do
		add(
			list,
			"GateBeamTip",
			"Wedge",
			v(2.4, 1.6, 3.6),
			SHRINE_RED_DARK,
			"SmoothPlastic",
			v(sx * 13.2, TeaGardenArt.GROUND_Y + 45.6, gz),
			{
				rotation = v(0, sx * 90, 0),
			}
		)
	end
	append(
		list,
		MapKitShapes.capsule("GateBeam", 20, 1.4, SHRINE_RED, "SmoothPlastic", v(0, TeaGardenArt.GROUND_Y + 40, gz))
	)
end

-- 석등 (높이 약 14)
local function stoneLantern(list: { DecorSpec }, at: Vec3, lit: boolean, sparkle: boolean)
	column(list, "LanternBase", 4.4, 1.2, STONE_DARK, "Granite", at.x, at.y, at.z)
	column(list, "LanternPost", 1.8, 6, STONE, "Granite", at.x, at.y + 1.2, at.z)
	column(list, "LanternTable", 4.0, 1, STONE, "Granite", at.x, at.y + 7.2, at.z)
	append(
		list,
		MapKitShapes.roundedBox("LanternBox", v(3.2, 3, 3.2), STONE, "Granite", v(at.x, at.y + 9.7, at.z), {
			style = "vertical",
			radius = 0.4,
		})
	)
	add(list, "LanternFire", "Block", v(2.2, 1.8, 3.4), LANTERN_GLOW, "Neon", v(at.x, at.y + 9.7, at.z), {
		light = if lit then { kind = "Point", color = LANTERN_GLOW, brightness = 1.6, range = 20 } else nil,
		particle = if sparkle then "Sparkle" else nil,
		particleRate = if sparkle then 2 else nil,
	})
	add(list, "LanternRoof", "Wedge", v(5.4, 1.6, 2.7), STONE_DARK, "Granite", v(at.x, at.y + 12, at.z - 1.35), {
		rotation = v(0, 180, 0),
	})
	add(list, "LanternRoof", "Wedge", v(5.4, 1.6, 2.7), STONE_DARK, "Granite", v(at.x, at.y + 12, at.z + 1.35))
	ball(list, "LanternTop", 1.4, STONE, "Granite", v(at.x, at.y + 13.3, at.z))
end

-- 시냇물 (+Z·+X 쪽을 휘감는 물길) + 돌 + 꽃잎
local function stream(list: { DecorSpec })
	local y = TeaGardenArt.STREAM_Y
	local pts = {
		v(60, y, -12),
		v(66, y, 10),
		v(62, y, 32),
		v(48, y, 52),
		v(28, y, 66),
		v(4, y, 72),
		v(-22, y, 70),
		v(-46, y, 74),
		v(-70, y, 86),
		v(-96, y, 104),
	}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		add(
			list,
			"Stream",
			"Block",
			v(len + 6, 0.6, 12),
			if i % 2 == 0 then WATER else WATER_DEEP,
			"Glass",
			v((a.x + b.x) / 2, y - 0.3, (a.z + b.z) / 2),
			{ rotation = v(0, yaw, 0), transparency = 0.15, reflectance = 0.2, castShadow = false }
		)
		-- 둑 돌
		local nx, nz = -dz / len, dx / len
		for _, side in { -1, 1 } do
			ball(
				list,
				"BankStone",
				2.2 + (i % 3) * 0.8,
				if side == 1 then STONE else STONE_DARK,
				"Rock",
				v((a.x + b.x) / 2 + nx * 7 * side, y + 0.2, (a.z + b.z) / 2 + nz * 7 * side)
			)
		end
		if i % 2 == 1 then
			-- 떠다니는 꽃잎
			add(
				list,
				"FloatPetal",
				"Cylinder",
				v(0.15, 1.6, 1.6),
				SAKURA_PALE,
				"SmoothPlastic",
				v(a.x + dx * 0.4, y + 0.1, a.z + dz * 0.4),
				{
					rotation = UPRIGHT,
					anim = { kind = "Bob", period = 3 + i * 0.3, amount = 0.15 },
				}
			)
		end
	end
end

-- 나무 다리 (+Z 시냇물 위, 아치) + 풍경
local function bridge(list: { DecorSpec })
	local cx, cz = 4, 72
	local y = TeaGardenArt.STREAM_Y
	for k = -4, 4 do
		local h = 3.6 - (k * k) * 0.18
		add(
			list,
			"BridgePlank",
			"Block",
			v(2.8, 0.5, 10),
			if k % 2 == 0 then WOOD else WOOD_DARK,
			"WoodPlanks",
			v(cx + k * 2.7, y + h, cz),
			{
				rotation = v(0, 0, -k * 4),
			}
		)
	end
	for _, side in { -1, 1 } do
		for k = -4, 4, 2 do
			local h = 3.6 - (k * k) * 0.18
			column(list, "BridgePost", 0.7, 3.4, SHRINE_RED, "SmoothPlastic", cx + k * 2.7, y + h, cz + side * 5)
		end
		between(
			list,
			"BridgeRail",
			v(cx - 11, y + 4.6, cz + side * 5),
			v(cx, y + 7.1, cz + side * 5),
			0.6,
			SHRINE_RED_DARK,
			"SmoothPlastic"
		)
		between(
			list,
			"BridgeRail",
			v(cx, y + 7.1, cz + side * 5),
			v(cx + 11, y + 4.6, cz + side * 5),
			0.6,
			SHRINE_RED_DARK,
			"SmoothPlastic"
		)
	end
	-- 풍경 (바람종): 다리 가운데 기둥에 매달린 종 + 종이
	add(list, "WindChime", "Cylinder", v(1.4, 1.4, 1.4), BRONZE, "Metal", v(cx, y + 6.0, cz + 5), {
		rotation = UPRIGHT,
		reflectance = 0.25,
		anim = { kind = "Sway", period = 2.6, amount = 10, axis = "X" },
	})
	add(list, "WindChimePaper", "Block", v(0.8, 2.2, 0.08), c(236, 228, 200), "Fabric", v(cx, y + 4.4, cz + 5), {
		anim = { kind = "Sway", period = 2.2, amount = 14, axis = "X" },
	})
end

-- 차 소품 섬: 차선(대나무 거품기)·차시(찻숟가락)가 놓인 돌판
local function teaTools(list: { DecorSpec })
	local x, z, topY = 58, 20, -14
	ball(list, "ToolHill", 56, MOSS, "Grass", v(x + 6, topY - 1.5 - 28, z))
	append(
		list,
		MapKitShapes.bevelBox("ToolRock", v(18, 5, 14), STONE_DARK, "Rock", v(x, topY - 2.5, z), 1.2, v(0, 12, 0))
	)
	append(list, MapKitShapes.bevelBox("ToolSlab", v(16, 1.2, 12), STONE, "Slate", v(x, topY + 0.6, z), 0.4))
	-- 차선: 손잡이 + 살 무리
	local cxw, czw = x - 3, z + 1
	column(list, "Chasen", 2.6, 4, c(206, 184, 130), "Wood", cxw, topY + 1.2, czw)
	for k = 0, 9 do
		local a = math.rad(k * 36)
		between(
			list,
			"ChasenTine",
			v(cxw + math.cos(a) * 0.9, topY + 5.2, czw + math.sin(a) * 0.9),
			v(cxw + math.cos(a) * 2.6, topY + 10.4, czw + math.sin(a) * 2.6),
			0.35,
			c(222, 204, 150),
			"Wood"
		)
	end
	-- 차시 (가늘고 긴 대나무 숟가락)
	between(list, "Chashaku", v(x + 1, topY + 1.5, z - 3), v(x + 7, topY + 1.9, z + 3), 0.9, c(196, 168, 112), "Wood")
	ball(list, "ChashakuTip", 1.4, c(196, 168, 112), "Wood", v(x + 7.2, topY + 2, z + 3.2))
	-- 대추(차통)
	column(list, "Natsume", 5, 4.6, c(40, 34, 32), "SmoothPlastic", x + 4, topY + 1.2, z - 2, { reflectance = 0.2 })
	column(list, "NatsumeLid", 5.2, 0.8, c(156, 120, 50), "Metal", x + 4, topY + 5.8, z - 2, { reflectance = 0.2 })
end

-- 땅·산·먼 배경
local function ground(list: { DecorSpec })
	local g = TeaGardenArt.GROUND_Y
	column(list, "Ground", 1300, 2, MOSS_DARK, "Grass", 0, g - 2, 0)
	column(list, "GroundMoss", 420, 0.6, MOSS, "Grass", 0, g - 0.4, 0)
	-- 이끼 덩어리·바위 무리 (정원 둘레)
	append(
		list,
		MapKitShapes.scatter(38, 22, { center = v(0, g, 0), size = v(220, 0, 220) }, function(i, pos, rng)
			local r = math.sqrt(pos.x * pos.x + pos.z * pos.z)
			if r < 20 then
				return {}
			end
			local d = rng:range(4, 10)
			local out: { DecorSpec } = {}
			add(
				out,
				"MossMound",
				"Ball",
				v(d, d, d),
				if i % 2 == 0 then MOSS else shade(MOSS, 1.12),
				"Grass",
				v(pos.x, g - d * 0.2, pos.z)
			)
			if i % 3 == 0 then
				add(
					out,
					"GardenRock",
					"Ball",
					v(d * 0.6, d * 0.6, d * 0.6),
					STONE,
					"Rock",
					v(pos.x + d * 0.4, g + 0.4, pos.z)
				)
			end
			return out
		end)
	)
	-- 먼 산 실루엣 (노을 안개에 묻힌 둥근 산, 차가운 보랏빛). 큰 공을 땅에 묻어 둥근 능선만 보여요.
	for k = 0, 11 do
		local a = k * 30 + 8
		local r = 430 + (k % 3) * 70
		local d = 260 + (k % 4) * 60
		local p = polar(r, a, g - d * 0.32)
		ball(list, "Mountain", d, if k % 2 == 0 then MOUNTAIN else MOUNTAIN_FAR, "Rock", p, { castShadow = false })
	end
	-- 중간 언덕 (정원 둘레를 채우는 이끼 언덕, 윗면 −14 ~ −24)
	for k = 0, 9 do
		local a = k * 36 + 18
		local r = 96 + (k % 3) * 18
		local d = 60 + (k % 2) * 24
		local topY = -16 - (k % 3) * 4
		ball(list, "Hill", d, if k % 2 == 0 then MOSS else MOSS_DARK, "Grass", polar(r, a, topY - d / 2))
	end
	-- 먼 벚꽃 숲 (땅에 앉은 분홍 덩어리 무리)
	for k = 0, 9 do
		local a = k * 36 + 22
		local r = 175 + (k % 3) * 35
		local d = 34 + (k % 3) * 10
		local p = polar(r, a, g + d * 0.3)
		ball(
			list,
			"FarBlossom",
			d,
			if k % 3 == 0 then SAKURA_DEEP else SAKURA,
			"SmoothPlastic",
			p,
			{ castShadow = false }
		)
		ball(list, "FarBlossom", d * 0.7, SAKURA_PALE, "SmoothPlastic", v(p.x + d * 0.4, g + d * 0.2, p.z - d * 0.3), {
			castShadow = false,
		})
		ball(list, "FarBlossom", d * 0.6, SAKURA, "SmoothPlastic", v(p.x - d * 0.45, g + d * 0.15, p.z + d * 0.2), {
			castShadow = false,
		})
	end
end

-- 정원 가장자리 찻잎 (약하게 상시) + 금빛 그림자 스폿 (긴 대나무 장대 등)
local function edgeFx(list: { DecorSpec })
	for _, a in { 30, 210 } do
		ball(list, "LeafDrift", 1, HEDGE, "SmoothPlastic", polar(50, a, -1.5), {
			transparency = 1,
			particle = "TeaLeaves",
			particleRate = 1,
		})
	end
	-- 장대 등: 낮게 비치는 금빛 해 대신 (그림자 SpotLight 1)
	local base = polar(58, 315, TeaGardenArt.GROUND_Y)
	local topP = polar(56, 315, 26)
	between(list, "BambooPole", base, topP, 1.6, c(128, 138, 88), "Wood")
	for k = 1, 4 do
		local p = polar(58 - k * 0.5, 315, TeaGardenArt.GROUND_Y + k * 14)
		column(list, "BambooNode", 1.9, 0.5, c(118, 128, 64), "Wood", p.x, p.y, p.z)
	end
	add(list, "SunLantern", "Ball", v(3.6, 3.6, 3.6), LANTERN_GLOW, "Neon", v(topP.x - 2, topP.y - 2, topP.z + 2), {
		light = {
			kind = "Spot",
			color = c(255, 206, 140),
			brightness = 2.2,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
end

function TeaGardenArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	bowl(list)
	teapots(list)
	cherries(list)
	pavilion(list)
	stream(list)
	bridge(list)
	teaTools(list)
	stoneLantern(list, v(-16, TeaGardenArt.GROUND_Y, 62), true, true)
	stoneLantern(list, v(24, TeaGardenArt.GROUND_Y, 82), true, false)
	stoneLantern(list, v(-14, TeaGardenArt.GROUND_Y, -82), true, true)
	stoneLantern(list, v(-60, TeaGardenArt.GROUND_Y, 24), false, false)
	ground(list)
	edgeFx(list)
	return list
end

-- ① 찻주전자 너머 정원 + 노을 → ② 찻사발과 굴러 나오는 찻잔 → ③ 벚꽃 아래에서 계단 올려다보기 → ④ 바깥 5단 → ⑤ 출발 자리
function TeaGardenArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-72, 30, 40), lookAt = v(0, 3, -6) },
		{ pos = v(16, 14, 20), lookAt = v(0, 8, 0) },
		{ pos = v(50, 5, 56), lookAt = v(0, 12, 0) },
		{ pos = v(-8, 12, -72), lookAt = v(-20, 0, -40) },
		{ pos = v(34, 15, 36), lookAt = v(-10, 2, -10) },
	}
end

return TeaGardenArt
