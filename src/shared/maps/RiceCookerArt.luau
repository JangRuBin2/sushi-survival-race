--!strict
-- "초대형 밥솥" 아트 데이터 (m5-36). Roblox API를 쓰지 않아요 — lune 테스트·렌더러에서 바로 불러요.
-- 아트 디렉션 "아침 햇살 드는 주방, 막 뚜껑을 연 업소용 밥솥" (스펙 "## 아트", docs/REFERENCE-map-art-direction.md).
-- 판정 지오메트리(밥 언덕 조각·밸브 노즐·타이머 판)는 RiceCooker.build가 만들고, 여기는 충돌 없는 장식만 있어요.
--   RiceCookerArt.decor() -> { DecorSpec }          Extended 예산 (BUDGET)
--   RiceCookerArt.introCamera() -> { IntroPoint }    창가 넓은 샷 → 타이머 → 증기 밸브·띠 → 주걱 위 반전 샷 → 출발 자리
--   RiceCookerArt.LIGHTING                           맵 조명 (아침 8시 반, 따뜻한 Ambient, 김 서린 크림색 안개)
--   RiceCookerArt.COLORS / riceColor(tier)           판정·경고 파츠 색 (RiceCooker가 써요)
--   RiceCookerArt.TIMER                              디지털 타이머 판 자리 (origin 로컬 pos, size, tilt 도)
--   RiceCookerArt.PADDLE                             나무 주걱 자리 (테스트가 반지름 40 밖인지 봐요)
--
-- 층 (가이드 2절): FG = 단 옆면 밥알(립 — 윗면 아래에만), 가장자리 넘친 밥알, 은색 테두리, 밸브
--                 MG = 열린 뚜껑(뒤), 나무 주걱(오른쪽 뒤), 타이머 패널(앞), 걸린 등, 쌀 포대·계량컵 무리
--                 BG = 나무 작업대(−30, 낙하선 −20보다 10 아래), 주방 바닥(−120), 타일 벽·창문(동쪽 +X)·선반
-- 좌표는 언덕 중심 기준으로 쓰고 P()로 origin 로컬로 옮겨요. 언덕 중심 = Layout.CENTER_X/Z.

local Layout = require(script.Parent.RiceCookerLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type LightSpec = MapKitLogic.LightSpec
type AnimSpec = MapKitLogic.AnimSpec

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local Art = {}

Art.BUDGET = "Extended" :: MapKitLogic.BudgetTier

local PAL = MapKitLogic.PALETTE
local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z

-- 언덕 중심 기준 → origin 로컬
local function P(x: number, y: number, z: number): Vec3
	return { x = CX + x, y = y, z = CZ + z }
end

-- 색 (60 = 크림 주방 벽·나무 작업대, 30 = 밥 흰빛 + 무쇠 솥 검정·은색 림, 10 = 빨간 타이머 숫자·주황 경고·초록 화분)
local RICE = c(255, 248, 236) -- #FFF8EC 히어로 (밟는 면)
local RICE_LOW = c(236, 222, 198)
local GRAIN_A = c(255, 252, 246)
local GRAIN_B = c(246, 238, 222)
local GRAIN_C = c(234, 224, 204)
local IRON = c(42, 42, 48) -- #2A2A30 검은 무쇠 솥
local IRON_LIGHT = c(70, 70, 80)
local IRON_DARK = c(26, 26, 30)
local SILVER = c(206, 210, 216)
local SILVER_DARK = c(150, 154, 162)
local STEEL = PAL.Steel
local BRASS = c(214, 172, 92)
local BRASS_DARK = c(156, 118, 58)
local CREAM = c(224, 208, 184) -- 주방 벽 (밥보다 한 단계 어둡게)
local CREAM_DARK = c(200, 182, 156)
local TILE_A = c(232, 224, 208)
local TILE_B = c(218, 206, 186)
local GROUT = c(188, 174, 152)
local WOOD = c(198, 152, 100) -- 작업대 (버터색 원목)
local WOOD_LIGHT = PAL.WoodLight
local WOOD_DARK = PAL.WoodDark
local PADDLE_WOOD = c(222, 184, 128)
local SAGE = c(150, 172, 150) -- 아래 찬장 (차분한 세이지)
local SAGE_DARK = c(116, 138, 118)
local FLOOR_A = c(176, 140, 104)
local FLOOR_B = c(156, 120, 88)
local SKY = c(176, 214, 248) -- 창밖 푸른 하늘
local SKY_LOW = c(214, 232, 250)
local SUN = c(255, 222, 160) -- 금빛 햇살
local LEAF = c(92, 150, 70)
local LEAF_DARK = c(62, 112, 52)
local TERRACOTTA = c(196, 120, 84)
local BURLAP = c(214, 190, 146)
local BURLAP_DARK = c(178, 152, 108)
local LABEL_NAVY = PAL.Noren
local PORCELAIN = PAL.Porcelain
local LAMP_GREEN = c(70, 110, 96) -- 걸린 등 갓 (짙은 초록 법랑)
local WARM_LIGHT = c(255, 214, 160)
local COOL_LIGHT = c(190, 220, 255)

Art.COLORS = {
	brass = BRASS,
	brassDark = BRASS_DARK,
	timerGlass = c(16, 14, 16),
	timerText = c(255, 46, 34),
	timerTextGlow = c(120, 0, 0),
	warn = c(255, 106, 0), -- 진한 주황 테두리 (흰 밥 위에서 보이게)
	warnFill = c(255, 176, 96), -- 안쪽 옅은 주황
	steamWhite = c(255, 255, 255),
	riceGrain = c(255, 252, 244),
}

-- 밥 언덕 단 색: 꼭대기가 가장 밝고 바깥으로 아주 조금씩 크림빛 ("위가 안전"이 읽히게)
function Art.riceColor(tier: number): RGB
	return mix(RICE, RICE_LOW, (tier - 1) / 4 * 0.7)
end

-- 맵 조명: 아침 8시 반, 따뜻한 Ambient, 김 서린 크림색 Atmosphere, 은은한 Bloom·SunRays
Art.LIGHTING = {
	ClockTime = 8.5,
	Brightness = 2.1,
	Ambient = c(150, 130, 110),
	OutdoorAmbient = c(160, 150, 140),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.8,
	ExposureCompensation = -0.25,
	Atmosphere = {
		Density = 0.32,
		Offset = 0.04,
		Color = c(226, 210, 188),
		Decay = c(196, 170, 140),
		Glare = 0.2,
		Haze = 1.6,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.15, Saturation = 0.08, TintColor = c(255, 246, 236) },
	Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.2 },
	SunRays = { Intensity = 0.06, Spread = 0.6 },
} :: MapLighting.LightingPreset

-- 높이 (origin 로컬 y)
local RIM_TOP = Layout.RIM_TOP_Y
local COUNTER_TOP = Layout.COUNTER_TOP_Y -- −30
local FLOOR_Y = -120
local WALL_TOP = 220
local BACK_Z = -230 -- 언덕 중심 기준 뒤 벽
local SIDE_X = 230 -- 오른쪽(+X, 동쪽 창) / 왼쪽 벽
local FRONT_Z = 230

-- 디지털 타이머 판 (RiceCooker.buildTimer가 이 자리에 SurfaceGui 판을 만들어요)
local PANEL_TILT = 18 -- 위로 젖힌 각도 (도)
local PANEL_CENTER = P(0, -11, Layout.POT_RADIUS + 1.6)
local PANEL_DEPTH = 3.4
do
	-- 판 앞면 중심 = 패널 중심 + Rx(−tilt)·(0, 0, depth/2) + 두께 0.2
	local t = math.rad(-PANEL_TILT)
	local ny, nz = -math.sin(t), math.cos(t)
	local half = PANEL_DEPTH / 2 + 0.2
	Art.TIMER = {
		pos = v(
			PANEL_CENTER.x,
			PANEL_CENTER.y + 1.1 * math.cos(t) + ny * half,
			PANEL_CENTER.z + 1.1 * math.sin(t) + nz * half
		),
		size = v(15, 5.4, 0.4),
		tilt = PANEL_TILT,
	}
end

-- 나무 주걱: 언덕 중심에서 각도(도, +X에서 −Z 쪽으로) · 반지름, 바깥으로 기운 각도
Art.PADDLE = { angle = 40, radius = 42, lean = 24, bottomY = -3.4 }

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로
local ALONG_Z = v(0, 90, 0) -- 원기둥 축을 Z로

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
	shape: MapKitLogic.Shape,
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

local function addAll(list: { DecorSpec }, specs: { DecorSpec }, extra: Extra?)
	for _, s in specs do
		if extra then
			if extra.reflectance then
				s.reflectance = extra.reflectance
			end
			if extra.castShadow ~= nil then
				s.castShadow = extra.castShadow
			end
			if extra.transparency then
				s.transparency = extra.transparency
			end
		end
		table.insert(list, s)
	end
end

-- 각도(도, +X에서 −Z 쪽으로)·반지름 → 언덕 중심 기준 (x, z)
local function pol(angle: number, radius: number): (number, number)
	local rad = math.rad(angle)
	return radius * math.cos(rad), -radius * math.sin(rad)
end

---------------------------------------------------------------- FG: 밥알 (단 옆면·가장자리)

-- 단 옆면(윗단과 아랫단 사이 높이 1)에 박힌 밥알 — 윗면보다 낮게, 바깥으로 0.2쯤만 튀어나와요
local function addRiserGrains(list: { DecorSpec })
	local rng = MapKitShapes.rng(3611)
	local grains = { GRAIN_A, GRAIN_B, GRAIN_C }
	for k = 1, #Layout.TIERS - 1 do
		local tier = Layout.TIERS[k]
		local below = Layout.TIERS[k + 1]
		local face = tier.outer * math.cos(math.pi / Layout.SEGMENTS[k]) + 0.1
		local count = math.floor(2 * math.pi * tier.outer / 2.1)
		for i = 0, count - 1 do
			local a = 360 * (i + rng:range(-0.3, 0.3)) / count
			local x, z = pol(a, face)
			local len = 0.66 * rng:range(0.85, 1.15)
			local y = rng:range(below.top + 0.24, tier.top - 0.42)
			add(list, "RiceGrain", "Cylinder", v(len, 0.34, 0.34), grains[1 + i % 3], "SmoothPlastic", P(x, y, z), {
				rotation = v(rng:range(-30, 30), a + 90 + rng:range(-35, 35), rng:range(-25, 25)),
				castShadow = false,
			})
		end
	end
end

-- 가장자리(반지름 40) 바깥 옆면을 타고 흘러내린 밥알 + 테두리 위에 흘린 밥알 무리
local function addEdgeGrains(list: { DecorSpec })
	local rng = MapKitShapes.rng(4721)
	local grains = { GRAIN_A, GRAIN_B, GRAIN_C }
	local outer = Layout.HILL_RADIUS
	local face = outer * math.cos(math.pi / Layout.SEGMENTS[#Layout.SEGMENTS]) + 0.1
	local count = math.floor(2 * math.pi * outer / 2.3)
	for i = 0, count - 1 do
		local a = 360 * (i + rng:range(-0.35, 0.35)) / count
		local x, z = pol(a, face)
		local y = rng:range(-2.6, -0.28)
		add(
			list,
			"RiceGrain",
			"Cylinder",
			v(0.7 * rng:range(0.85, 1.15), 0.36, 0.36),
			grains[1 + i % 3],
			"SmoothPlastic",
			P(x, y, z),
			{
				rotation = v(rng:range(-40, 40), a + 90 + rng:range(-50, 50), rng:range(-40, 40)),
				castShadow = false,
			}
		)
	end
	-- 은색 테두리 위로 넘친 밥 덩이 (작은 무리 7곳 — 밸브·주걱·타이머 자리는 피해요)
	for _, a in { 18, 62, 112, 150, 208, 238, 300, 332 } do
		local n = 4 + math.floor(rng:next() * 4)
		for j = 1, n do
			local r = Layout.RIM_INNER_RADIUS + rng:range(0.3, 2.6)
			local x, z = pol(a + rng:range(-2.5, 2.5), r)
			add(
				list,
				"RiceGrain",
				"Cylinder",
				v(0.7, 0.36, 0.36),
				grains[1 + j % 3],
				"SmoothPlastic",
				P(x, RIM_TOP + 0.12, z),
				{ rotation = v(0, rng:range(0, 180), rng:range(-10, 10)), castShadow = false }
			)
		end
	end
end

-- 밥 위 낮게 오르는 김 (단 옆면 밑에 묻힌 작은 파츠 — 윗면 위로 안 올라와요)
local function addHillSteam(list: { DecorSpec })
	for i, spot in { { 20, 2 }, { 140, 3 }, { 250, 4 }, { 320, 1 } } do
		local tier = Layout.TIERS[spot[2]]
		local x, z = pol(spot[1], tier.outer - 1)
		add(list, "HillSteam", "Block", v(2, 0.2, 2), RICE, "SmoothPlastic", P(x, tier.top - 0.3, z), {
			transparency = 1,
			castShadow = false,
			particle = "Steam",
			particleRate = if i % 2 == 0 then 1.4 else 1.8,
		})
	end
end

---------------------------------------------------------------- FG: 검은 솥 + 은색 테두리

local function addPot(list: { DecorSpec })
	-- 솥 안쪽 어둠 (밥 가장자리와 테두리 사이 틈으로 보여요)
	add(
		list,
		"PotInterior",
		"Cylinder",
		v(1, Layout.RIM_INNER_RADIUS * 2 + 0.4, Layout.RIM_INNER_RADIUS * 2 + 0.4),
		IRON_DARK,
		"SmoothPlastic",
		P(0, -3.7, 0),
		{ rotation = UPRIGHT }
	)
	-- 몸통 (−30 작업대 위 ~ −4) + 어깨·띠·굽
	local bodyTop, bodyBottom = -4, COUNTER_TOP + 1.6
	add(
		list,
		"PotBody",
		"Cylinder",
		v(bodyTop - bodyBottom, Layout.POT_RADIUS * 2, Layout.POT_RADIUS * 2),
		IRON,
		"Metal",
		P(0, (bodyTop + bodyBottom) / 2, 0),
		{ rotation = UPRIGHT, reflectance = 0.12 }
	)
	add(
		list,
		"PotShoulder",
		"Cylinder",
		v(2.2, Layout.POT_RADIUS * 2 + 1.6, Layout.POT_RADIUS * 2 + 1.6),
		IRON_LIGHT,
		"Metal",
		P(0, -5, 0),
		{ rotation = UPRIGHT, reflectance = 0.2 }
	)
	for _, y in { -15, -24 } do
		add(
			list,
			"PotBand",
			"Cylinder",
			v(1.1, Layout.POT_RADIUS * 2 + 1, Layout.POT_RADIUS * 2 + 1),
			IRON_DARK,
			"Metal",
			P(0, y, 0),
			{ rotation = UPRIGHT, reflectance = 0.15 }
		)
	end
	add(
		list,
		"PotFoot",
		"Cylinder",
		v(1.8, Layout.POT_RADIUS * 2 - 4, Layout.POT_RADIUS * 2 - 4),
		IRON_DARK,
		"CorrodedMetal",
		P(0, COUNTER_TOP + 0.9, 0),
		{ rotation = UPRIGHT }
	)
	-- 두꺼운 은색 테두리 (윗면 −2) + 안쪽 짙은 턱 + 바깥 밝은 모서리
	local mid = (Layout.RIM_INNER_RADIUS + Layout.RIM_OUTER_RADIUS) / 2
	addAll(
		list,
		MapKitShapes.ring(
			"PotRim",
			mid,
			Layout.RIM_OUTER_RADIUS - Layout.RIM_INNER_RADIUS,
			1.4,
			48,
			SILVER,
			"Metal",
			P(0, RIM_TOP - 0.7, 0)
		),
		{ reflectance = 0.35 }
	)
	addAll(
		list,
		MapKitShapes.ring(
			"PotRimLip",
			Layout.RIM_OUTER_RADIUS + 0.3,
			0.8,
			2.2,
			40,
			SILVER_DARK,
			"Metal",
			P(0, RIM_TOP - 1.7, 0)
		),
		{ reflectance = 0.3 }
	)
	-- 양옆 손잡이 (검은 베이클라이트, 밸브 아래)
	for _, side in { -1, 1 } do
		local x = side * (Layout.POT_RADIUS + 5)
		for _, dz in { -9, 9 } do
			add(
				list,
				"PotEar",
				"Block",
				v(7, 2.4, 2.4),
				IRON_LIGHT,
				"Metal",
				P(side * (Layout.POT_RADIUS + 2.2), -11, dz),
				{ reflectance = 0.2 }
			)
		end
		addAll(
			list,
			MapKitShapes.capsule("PotHandle", 22, 4, IRON_DARK, "SmoothPlastic", P(x, -11, 0), ALONG_Z),
			{ reflectance = 0.1 }
		)
	end
end

---------------------------------------------------------------- MG: 증기 밸브 2개 (놋쇠, 압력계)

local function addValves(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * Layout.VENT_X
		local back = side * (Layout.VENT_X + 2.2) -- 분배관 바깥쪽
		-- 솥 옆에서 올라오는 공급관 2개 + 받침 플랜지
		for _, z in { -7, 7 } do
			add(
				list,
				"ValveRiser",
				"Cylinder",
				v(12, 2.2, 2.2),
				BRASS_DARK,
				"Metal",
				P(back, -3, z),
				{ rotation = UPRIGHT, reflectance = 0.25 }
			)
			add(
				list,
				"ValveFlange",
				"Cylinder",
				v(0.8, 4, 4),
				BRASS,
				"Metal",
				P(side * (Layout.POT_RADIUS + 0.4), -8, z),
				{ rotation = v(0, 0, 0), reflectance = 0.2 }
			)
			add(
				list,
				"ValveElbow",
				"Ball",
				v(2.8, 2.8, 2.8),
				BRASS,
				"Metal",
				P(back, Layout.VENT_Y, z),
				{ reflectance = 0.25 }
			)
			add(
				list,
				"ValveBracket",
				"Block",
				v(2.4, 1.2, 3),
				IRON_LIGHT,
				"Metal",
				P(side * (Layout.POT_RADIUS + 1.4), -8, z)
			)
		end
		-- 분배관 양 끝 마개
		for _, z in { -18.4, 18.4 } do
			add(
				list,
				"ValveCap",
				"Ball",
				v(3.2, 3.2, 3.2),
				BRASS,
				"Metal",
				P(x, Layout.VENT_Y, z),
				{ reflectance = 0.25 }
			)
		end
		-- 띠마다 노즐 위 작은 고리 (분배관과 노즐 잇는 너트)
		for _, bz in Layout.BANDS do
			add(
				list,
				"ValveNut",
				"Cylinder",
				v(0.8, 3.2, 3.2),
				BRASS_DARK,
				"Metal",
				P(x - side * 1.1, Layout.VENT_Y, bz),
				{ reflectance = 0.2 }
			)
		end
		-- 압력계: 분배관 위 기둥 + 둥근 계기판(언덕 쪽을 봐요) + 바늘(흔들림)
		local gz = -7
		add(
			list,
			"GaugeStem",
			"Cylinder",
			v(3, 0.9, 0.9),
			BRASS_DARK,
			"Metal",
			P(x, Layout.VENT_Y + 2.6, gz),
			{ rotation = UPRIGHT }
		)
		local gy = Layout.VENT_Y + 6
		add(list, "GaugeBody", "Cylinder", v(1.6, 6, 6), BRASS, "Metal", P(x, gy, gz), { reflectance = 0.3 })
		add(
			list,
			"GaugeFace",
			"Cylinder",
			v(0.2, 5, 5),
			PORCELAIN,
			"SmoothPlastic",
			P(x - side * 0.82, gy, gz),
			{ castShadow = false }
		)
		for k = 0, 4 do
			local a = math.rad(-60 + k * 30)
			add(
				list,
				"GaugeTick",
				"Block",
				v(0.1, 0.5, 0.18),
				IRON_DARK,
				"SmoothPlastic",
				P(x - side * 0.95, gy + 1.9 * math.cos(a), gz + 1.9 * math.sin(a)),
				{ rotation = v(-math.deg(a), 0, 0), castShadow = false }
			)
		end
		add(list, "GaugeNeedle", "Block", v(0.12, 2, 0.24), IRON_DARK, "SmoothPlastic", P(x - side * 1, gy + 0.6, gz), {
			castShadow = false,
			anim = { kind = "Sway", period = 2.6 + side * 0.3, amount = 14, axis = "X" },
		})
		-- 핸들 바퀴 (놋쇠 고리 + 살) — 위로 눕혀서
		local wz = 7
		add(
			list,
			"WheelStem",
			"Cylinder",
			v(3, 1, 1),
			BRASS_DARK,
			"Metal",
			P(x, Layout.VENT_Y + 2.6, wz),
			{ rotation = UPRIGHT }
		)
		addAll(
			list,
			MapKitShapes.ring("ValveWheel", 2.4, 0.6, 0.6, 10, BRASS, "Metal", P(x, Layout.VENT_Y + 4.2, wz)),
			{ reflectance = 0.3 }
		)
		add(list, "WheelSpoke", "Block", v(4.8, 0.4, 0.5), BRASS_DARK, "Metal", P(x, Layout.VENT_Y + 4.2, wz))
		add(list, "WheelSpoke", "Block", v(0.5, 0.4, 4.8), BRASS_DARK, "Metal", P(x, Layout.VENT_Y + 4.2, wz))
		-- 안전 밸브 꼭지에서 가늘게 새는 김
		add(list, "ReliefCap", "Cylinder", v(1.6, 1.4, 1.4), BRASS, "Metal", P(back, Layout.VENT_Y + 2, 0), {
			rotation = UPRIGHT,
			particle = "Steam",
			particleRate = 1.2,
		})
	end
end

---------------------------------------------------------------- MG: 열린 뚜껑 (뒤쪽에 비스듬히)

local function addLid(list: { DecorSpec })
	local lean = 14 -- 수직에서 뒤로 기운 각도
	local radius = Layout.POT_RADIUS + 1
	local hingeY, hingeZ = RIM_TOP + 1, -(Layout.POT_RADIUS + 1.5)
	local ly, lz = math.cos(math.rad(lean)), -math.sin(math.rad(lean)) -- 뚜껑 면 안 "위" 방향
	local ny, nz = math.sin(math.rad(lean)), math.cos(math.rad(lean)) -- 안쪽 면(언덕 쪽) 법선
	local cy, cz = hingeY + radius * ly, hingeZ + radius * lz
	local disc = v(-lean, -90, 0) -- 원기둥 축(X)을 법선으로
	add(
		list,
		"LidShell",
		"Cylinder",
		v(3, radius * 2, radius * 2),
		IRON,
		"Metal",
		P(0, cy, cz),
		{ rotation = disc, reflectance = 0.14 }
	)
	add(
		list,
		"LidPlate",
		"Cylinder",
		v(0.6, radius * 2 - 9, radius * 2 - 9),
		STEEL,
		"Metal",
		P(0, cy + ny * 1.75, cz + nz * 1.75),
		{ rotation = disc, reflectance = 0.3 }
	)
	-- 안쪽 고무 패킹 고리 (연회색) — 링을 뚜껑 면으로 눕혀요 (Y → 법선: X축 90 − lean)
	addAll(
		list,
		MapKitShapes.ring(
			"LidGasket",
			radius - 3,
			2,
			0.8,
			36,
			c(214, 214, 210),
			"Rubber",
			P(0, cy + ny * 1.9, cz + nz * 1.9),
			v(90 - lean, 0, 0)
		)
	)
	addAll(
		list,
		MapKitShapes.ring("LidRim", radius + 0.2, 1, 3.6, 40, IRON_LIGHT, "Metal", P(0, cy, cz), v(90 - lean, 0, 0)),
		{ reflectance = 0.2 }
	)
	-- 안쪽 판에 맺힌 물방울
	local rng = MapKitShapes.rng(5303)
	for _ = 1, 22 do
		local a = rng:range(0, 2 * math.pi)
		local r = math.sqrt(rng:next()) * (radius - 8)
		local u, w = r * math.cos(a), r * math.sin(a) -- u = 가로(X), w = 면 안 위
		local d = rng:range(0.5, 1.1)
		add(
			list,
			"LidDroplet",
			"Ball",
			v(d, d, d),
			c(236, 244, 250),
			"Glass",
			P(u, cy + w * ly + ny * 2.15, cz + w * lz + nz * 2.15),
			{
				transparency = 0.25,
				reflectance = 0.3,
				castShadow = false,
			}
		)
	end
	-- 경첩 (뒤쪽 아래)
	addAll(
		list,
		MapKitShapes.capsule("LidHinge", 26, 4, IRON_LIGHT, "Metal", P(0, hingeY - 0.6, hingeZ - 0.6)),
		{ reflectance = 0.2 }
	)
	for _, x in { -9, 9 } do
		add(list, "HingeBracket", "Block", v(3, 6, 5), IRON_DARK, "Metal", P(x, hingeY - 3.4, hingeZ + 0.6))
	end
	-- 바깥쪽 둥근 손잡이 + 김 뿜는 꼭지 (숨 쉬듯)
	local oy, oz = cy - ny * 1.5, cz - nz * 1.5
	add(
		list,
		"LidKnobStem",
		"Cylinder",
		v(3, 4, 4),
		IRON_DARK,
		"Metal",
		P(0, oy - ny * 1.5 + ly * 4, oz - nz * 1.5 + lz * 4),
		{ rotation = disc }
	)
	add(
		list,
		"LidKnob",
		"Ball",
		v(8, 8, 8),
		IRON_LIGHT,
		"Metal",
		P(0, oy - ny * 4.5 + ly * 4, oz - nz * 4.5 + lz * 4),
		{ reflectance = 0.25 }
	)
	add(
		list,
		"LidSteamCap",
		"Cylinder",
		v(1.2, 2.6, 2.6),
		SILVER,
		"Metal",
		P(0, cy + ly * (radius - 6) + ny * 1.9, cz + lz * (radius - 6) + nz * 1.9),
		{
			rotation = disc,
			reflectance = 0.3,
			particle = "Steam",
			particleRate = 2,
			anim = { kind = "Pulse", period = 2.4, amount = 0.08 },
		}
	)
end

---------------------------------------------------------------- MG: 나무 주걱 (오른쪽 뒤 테두리에 기대)

local function addPaddle(list: { DecorSpec })
	local p = Art.PADDLE
	local local_: { DecorSpec } = {}
	-- 주걱 로컬: 아래 끝 = 원점, 위 = +Y, 폭 = X, 두께 = Z
	add(local_, "PaddleBlade", "Cylinder", v(1.3, 14, 14), PADDLE_WOOD, "Wood", v(0, 7, 0), { rotation = ALONG_Z })
	add(local_, "PaddleBlade", "Block", v(14, 8, 1.3), PADDLE_WOOD, "Wood", v(0, 11, 0))
	add(local_, "PaddleNeck", "Wedge", v(1.3, 6, 4.6), PADDLE_WOOD, "Wood", v(-4.7, 18, 0), { rotation = v(0, 90, 0) })
	add(local_, "PaddleNeck", "Wedge", v(1.3, 6, 4.6), PADDLE_WOOD, "Wood", v(4.7, 18, 0), { rotation = v(0, -90, 0) })
	add(local_, "PaddleNeck", "Block", v(4.8, 6, 1.3), PADDLE_WOOD, "Wood", v(0, 18, 0))
	addAll(
		local_,
		MapKitShapes.capsule("PaddleHandle", 38, 3.4, shade(PADDLE_WOOD, 0.92), "Wood", v(0, 39, 0), UPRIGHT)
	)
	add(
		local_,
		"PaddleGrain",
		"Block",
		v(0.2, 30, 0.1),
		shade(PADDLE_WOOD, 0.8),
		"Wood",
		v(-0.6, 39, 1.75),
		{ castShadow = false }
	)
	-- 날에 붙은 밥알
	local rng = MapKitShapes.rng(8117)
	for i = 1, 10 do
		local face = if i % 2 == 0 then 0.75 else -0.75
		add(
			local_,
			"RiceGrain",
			"Cylinder",
			v(0.7, 0.36, 0.36),
			if i % 3 == 0 then GRAIN_B else GRAIN_A,
			"SmoothPlastic",
			v(rng:range(-5, 5), rng:range(1.5, 9), face),
			{
				rotation = v(0, 0, rng:range(0, 180)),
				castShadow = false,
			}
		)
	end
	-- 바깥으로 기울이고(X축) → 바깥 방향으로 돌려요(Y축: 로컬 +Z가 바깥)
	local tilted = MapKitShapes.transform(local_, v(0, 0, 0), v(p.lean, 0, 0))
	local x, z = pol(p.angle, p.radius)
	local placed = MapKitShapes.transform(tilted, P(x, p.bottomY, z), v(0, 90 + p.angle, 0))
	addAll(list, placed)
end

---------------------------------------------------------------- MG: 디지털 타이머 패널 (앞 +Z)

local function addTimerPanel(list: { DecorSpec })
	local tilt = v(-PANEL_TILT, 0, 0)
	local cpos = PANEL_CENTER
	local function at(dx: number, dy: number, dz: number): Vec3
		local t = math.rad(-PANEL_TILT)
		return v(
			cpos.x + dx,
			cpos.y + dy * math.cos(t) - dz * math.sin(t),
			cpos.z + dy * math.sin(t) + dz * math.cos(t)
		)
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"TimerHousing",
			v(24, 12, PANEL_DEPTH),
			c(232, 232, 228),
			"SmoothPlastic",
			cpos,
			{ radius = 1.2, rotation = tilt }
		),
		{ reflectance = 0.06 }
	)
	-- 화면 테두리 (검은 베젤)
	add(
		list,
		"TimerBezel",
		"Block",
		v(16.4, 6.6, 0.3),
		IRON_DARK,
		"SmoothPlastic",
		at(0, 1.1, PANEL_DEPTH / 2 + 0.05),
		{ rotation = tilt }
	)
	-- 버튼 3개 + 작은 초록 표시등
	for i, bx in { -6.5, 0, 6.5 } do
		add(
			list,
			"TimerButton",
			"Cylinder",
			v(0.7, 2.4, 2.4),
			if i == 2 then c(206, 210, 216) else c(190, 196, 204),
			"SmoothPlastic",
			at(bx, -3.6, PANEL_DEPTH / 2 + 0.3),
			{
				rotation = v(-PANEL_TILT, -90, 0),
				castShadow = false,
			}
		)
		add(
			list,
			"TimerButtonLabel",
			"Block",
			v(2.4, 0.4, 0.1),
			c(110, 110, 116),
			"SmoothPlastic",
			at(bx, -5.3, PANEL_DEPTH / 2 + 0.06),
			{ rotation = tilt, castShadow = false }
		)
	end
	add(
		list,
		"TimerLed",
		"Ball",
		v(0.7, 0.7, 0.7),
		c(110, 230, 120),
		"Neon",
		at(10, 4, PANEL_DEPTH / 2 + 0.2),
		{ castShadow = false, light = { kind = "Point", color = c(140, 240, 150), brightness = 1, range = 6 } }
	)
	-- 패널을 솥에 붙이는 받침
	add(list, "TimerMount", "Block", v(20, 3, 3), IRON_LIGHT, "Metal", P(0, -6.2, Layout.POT_RADIUS + 0.2))
	add(list, "TimerMount", "Block", v(20, 3, 3), IRON_LIGHT, "Metal", P(0, -16, Layout.POT_RADIUS + 0.4))
end

---------------------------------------------------------------- MG: 걸린 등 (언덕 위, 그림자 SpotLight 1)

local function addLamp(list: { DecorSpec })
	local x, y, z = -14, 42, -6 -- 전구가 꼭대기 윗면에서 약 37 (Spot range 60 안, QA B2)
	local lampOpts: Extra = { rotation = UPRIGHT, reflectance = 0.15 }
	add(
		list,
		"LampCord",
		"Cylinder",
		v(WALL_TOP - y - 6, 0.5, 0.5),
		c(34, 34, 36),
		"SmoothPlastic",
		P(x, (WALL_TOP + y + 6) / 2, z),
		{ rotation = UPRIGHT }
	)
	add(
		list,
		"LampCap",
		"Cylinder",
		v(2, 3, 3),
		BRASS,
		"Metal",
		P(x, y + 7.2, z),
		{ rotation = UPRIGHT, reflectance = 0.2 }
	)
	add(list, "LampShade", "Cylinder", v(6, 11, 11), LAMP_GREEN, "SmoothPlastic", P(x, y + 4.4, z), lampOpts)
	add(list, "LampShade", "Cylinder", v(2.6, 19, 19), LAMP_GREEN, "SmoothPlastic", P(x, y + 1.3, z), lampOpts)
	addAll(list, MapKitShapes.ring("LampRim", 9.6, 0.6, 0.8, 16, BRASS, "Metal", P(x, y, z)), { reflectance = 0.3 })
	add(list, "LampBulb", "Ball", v(4, 4, 4), c(255, 236, 196), "Neon", P(x, y - 0.6, z), {
		castShadow = false,
		light = {
			kind = "Spot",
			color = WARM_LIGHT,
			brightness = 2.6,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
	-- 벽 조리대 위 작은 펜던트 등 2개 (그림자 없음)
	for i, px in { -110, 110 } do
		local py, pz = 40, BACK_Z + 44
		add(
			list,
			"PendantCord",
			"Cylinder",
			v(WALL_TOP - py, 0.4, 0.4),
			c(34, 34, 36),
			"SmoothPlastic",
			P(px, (WALL_TOP + py) / 2, pz),
			{ rotation = UPRIGHT }
		)
		add(
			list,
			"PendantShade",
			"Cylinder",
			v(5, 12, 12),
			if i == 1 then LAMP_GREEN else shade(LAMP_GREEN, 1.2),
			"SmoothPlastic",
			P(px, py, pz),
			{ rotation = UPRIGHT, reflectance = 0.12 }
		)
		add(list, "PendantBulb", "Ball", v(4, 4, 4), c(255, 236, 196), "Neon", P(px, py - 3, pz), {
			castShadow = false,
			light = { kind = "Point", color = WARM_LIGHT, brightness = 1.6, range = 40 },
		})
	end
end

---------------------------------------------------------------- BG: 작업대 · 바닥

local function addCounter(list: { DecorSpec })
	local w, d = 200, 170
	-- 원목 상판 (판자 5장, 3 shade) + 둥근 앞 모서리
	local planks = { WOOD, WOOD_LIGHT, WOOD, shade(WOOD, 0.9), WOOD_LIGHT }
	for i, color in planks do
		local z = -d / 2 + (i - 0.5) * d / #planks
		add(list, "CounterPlank", "Block", v(w, 5, d / #planks - 0.3), color, "WoodPlanks", P(0, COUNTER_TOP - 2.5, z))
	end
	add(list, "CounterSeam", "Block", v(w - 1, 4.6, d - 1), WOOD_DARK, "Wood", P(0, COUNTER_TOP - 2.6, 0))
	add(list, "CounterEdge", "Cylinder", v(w, 5, 5), shade(WOOD, 0.95), "Wood", P(0, COUNTER_TOP - 2.5, d / 2))
	add(
		list,
		"CounterEdge",
		"Cylinder",
		v(d, 5, 5),
		shade(WOOD, 0.95),
		"Wood",
		P(w / 2, COUNTER_TOP - 2.5, 0),
		{ rotation = ALONG_Z }
	)
	add(
		list,
		"CounterEdge",
		"Cylinder",
		v(d, 5, 5),
		shade(WOOD, 0.95),
		"Wood",
		P(-w / 2, COUNTER_TOP - 2.5, 0),
		{ rotation = ALONG_Z }
	)
	-- 아래 찬장 (세이지) + 문짝·손잡이 (앞 +Z, 오른쪽 +X 면)
	local h = COUNTER_TOP - 5 - FLOOR_Y
	add(list, "CounterBody", "Block", v(w - 12, h, d - 12), SAGE, "SmoothPlastic", P(0, FLOOR_Y + h / 2, 0))
	add(list, "CounterKick", "Block", v(w - 8, 6, d - 8), SAGE_DARK, "SmoothPlastic", P(0, FLOOR_Y + 3, 0))
	for k = 0, 5 do
		local x = -w / 2 + 6 + (k + 0.5) * (w - 12) / 6
		addAll(
			list,
			MapKitShapes.bevelBox(
				"CabinetDoor",
				v((w - 12) / 6 - 3, 1.2, h - 18),
				shade(SAGE, 1.08),
				"SmoothPlastic",
				P(x, FLOOR_Y + 9 + (h - 18) / 2, d / 2 - 5.4),
				0.5,
				v(90, 0, 0)
			)
		)
		add(
			list,
			"CabinetKnob",
			"Ball",
			v(2.2, 2.2, 2.2),
			BRASS,
			"Metal",
			P(x + (if k % 2 == 0 then 16 else -16), COUNTER_TOP - 18, d / 2 - 4.4),
			{ reflectance = 0.3 }
		)
	end
	for k = 0, 3 do
		local z = -d / 2 + 6 + (k + 0.5) * (d - 12) / 4
		add(
			list,
			"CabinetDoorSide",
			"Block",
			v(1.2, h - 18, (d - 12) / 4 - 3),
			shade(SAGE, 1.08),
			"SmoothPlastic",
			P(w / 2 - 5.4, FLOOR_Y + 9 + (h - 18) / 2, z)
		)
		add(
			list,
			"CabinetKnob",
			"Ball",
			v(2.2, 2.2, 2.2),
			BRASS,
			"Metal",
			P(w / 2 - 4.4, COUNTER_TOP - 18, z + (if k % 2 == 0 then 18 else -18)),
			{ reflectance = 0.3 }
		)
	end
	-- 주방 바닥 (따뜻한 나무 마루, 판 9장 2 shade)
	for i = -2, 2 do
		add(
			list,
			"KitchenFloor",
			"Block",
			v(96, 2, 470),
			if i % 2 == 0 then FLOOR_A else FLOOR_B,
			"WoodPlanks",
			P(i * 96, FLOOR_Y - 1, 0)
		)
	end
	add(list, "FloorRug", "Block", v(160, 0.6, 70), c(84, 104, 140), "Fabric", P(0, FLOOR_Y + 0.3, d / 2 + 60))
	add(list, "FloorRugBorder", "Block", v(168, 0.4, 78), c(232, 212, 170), "Fabric", P(0, FLOOR_Y + 0.2, d / 2 + 60))
end

---------------------------------------------------------------- BG: 벽 (뒤 타일·선반, 오른쪽 창, 왼쪽 걸이)

local function addBackWall(list: { DecorSpec })
	local z = BACK_Z
	local wallH = WALL_TOP - FLOOR_Y
	add(list, "BackWall", "Block", v(SIDE_X * 2, wallH, 4), CREAM, "Plaster", P(0, FLOOR_Y + wallH / 2, z - 2))
	-- 벽 쪽 조리대 (상판 −30) + 아래 찬장
	local depth = 70
	add(
		list,
		"BackCounterTop",
		"Block",
		v(SIDE_X * 2 - 8, 5, depth),
		shade(WOOD, 0.95),
		"WoodPlanks",
		P(0, COUNTER_TOP - 2.5, z + depth / 2)
	)
	add(list, "BackCounterEdge", "Cylinder", v(SIDE_X * 2 - 8, 5, 5), WOOD, "Wood", P(0, COUNTER_TOP - 2.5, z + depth))
	add(
		list,
		"BackCabinet",
		"Block",
		v(SIDE_X * 2 - 12, COUNTER_TOP - 5 - FLOOR_Y, depth - 6),
		SAGE_DARK,
		"SmoothPlastic",
		P(0, (COUNTER_TOP - 5 + FLOOR_Y) / 2, z + depth / 2 - 3)
	)
	-- 타일 띠 (조리대 위 −30 ~ 50): 큰 판 3 shade + 줄눈
	local tileTop = 50
	for i, color in { TILE_A, TILE_B, TILE_A, TILE_B, TILE_A } do
		local x = -SIDE_X + (i - 0.5) * SIDE_X * 2 / 5
		add(
			list,
			"BacksplashTile",
			"Block",
			v(SIDE_X * 2 / 5, tileTop - COUNTER_TOP, 1),
			color,
			"CeramicTiles",
			P(x, (tileTop + COUNTER_TOP) / 2, z + 0.5)
		)
	end
	for k = 1, 3 do
		add(
			list,
			"TileGrout",
			"Block",
			v(SIDE_X * 2, 0.4, 1.2),
			GROUT,
			"SmoothPlastic",
			P(0, COUNTER_TOP + k * 20, z + 0.6)
		)
	end
	add(list, "TileTrim", "Block", v(SIDE_X * 2, 2, 2), CREAM_DARK, "SmoothPlastic", P(0, tileTop + 1, z + 1))
	-- 윗 찬장 (위 70 ~ 140) + 문짝 + 아래 등 띠 (따뜻한 흰빛, SurfaceLight 아래로)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"UpperCabinet",
			v(SIDE_X * 2 - 40, 70, 34),
			shade(CREAM, 1.04),
			"SmoothPlastic",
			P(0, 105, z + 17),
			1.2
		)
	)
	for k = 0, 7 do
		local x = -SIDE_X + 20 + (k + 0.5) * (SIDE_X * 2 - 40) / 8
		add(
			list,
			"UpperDoor",
			"Block",
			v((SIDE_X * 2 - 40) / 8 - 4, 62, 1),
			shade(CREAM, 1.1),
			"SmoothPlastic",
			P(x, 105, z + 34.4)
		)
		add(
			list,
			"UpperKnob",
			"Ball",
			v(2, 2, 2),
			BRASS,
			"Metal",
			P(x + (if k % 2 == 0 then 24 else -24), 80, z + 35.4),
			{ reflectance = 0.3 }
		)
	end
	for _, x in { -150, 150 } do
		add(list, "UnderLight", "Block", v(100, 1, 3), c(255, 240, 210), "Neon", P(x, 69.4, z + 26), {
			castShadow = false,
			light = { kind = "Surface", color = WARM_LIGHT, brightness = 2, range = 16, angle = 120, face = "Bottom" },
		})
	end
	-- 조리대 위 소품 무리: 밥공기 쌓기, 간장병, 큰 냄비, 양념 통
	local px = -170
	for j = 0, 3 do
		add(
			list,
			"StackedBowl",
			"Cylinder",
			v(5, 18 - j, 18 - j),
			if j % 2 == 0 then PORCELAIN else c(220, 228, 236),
			"SmoothPlastic",
			P(px, COUNTER_TOP + 2.5 + j * 4.2, z + 30),
			{ rotation = UPRIGHT, reflectance = 0.08 }
		)
	end
	addAll(
		list,
		MapKitShapes.rimDisc(
			"StockPot",
			40,
			34,
			STEEL,
			"Metal",
			P(120, COUNTER_TOP + 17, z + 32),
			{ rimColor = shade(STEEL, 1.1), rimWidth = 1.2, segments = 20 }
		),
		{ reflectance = 0.25 }
	)
	for k = 0, 4 do
		add(
			list,
			"SpiceJar",
			"Cylinder",
			v(10, 6, 6),
			if k % 2 == 0 then c(236, 226, 206) else c(196, 130, 80),
			"Glass",
			P(-60 + k * 9, COUNTER_TOP + 5, z + 14),
			{ rotation = UPRIGHT, transparency = 0.15, reflectance = 0.15 }
		)
		add(
			list,
			"SpiceLid",
			"Cylinder",
			v(2, 6.4, 6.4),
			WOOD_DARK,
			"Wood",
			P(-60 + k * 9, COUNTER_TOP + 11, z + 14),
			{ rotation = UPRIGHT }
		)
	end
	-- 벽 시계 (윗 찬장 사이 빈 곳 위)
	add(
		list,
		"ClockFace",
		"Cylinder",
		v(1.5, 26, 26),
		PORCELAIN,
		"SmoothPlastic",
		P(0, 172, z + 1),
		{ rotation = ALONG_Z }
	)
	addAll(list, MapKitShapes.ring("ClockRim", 13, 2, 3, 20, WOOD_DARK, "Wood", P(0, 172, z + 1.5), v(90, 0, 0)))
	add(
		list,
		"ClockHand",
		"Block",
		v(1, 10, 0.4),
		IRON_DARK,
		"SmoothPlastic",
		P(1.5, 175, z + 2.2),
		{ rotation = v(0, 0, -30), castShadow = false }
	)
	add(
		list,
		"ClockHand",
		"Block",
		v(1, 7, 0.4),
		IRON_DARK,
		"SmoothPlastic",
		P(-2.8, 171, z + 2.3),
		{ rotation = v(0, 0, 110), castShadow = false }
	)
end

local function addWindowWall(list: { DecorSpec })
	local x = SIDE_X
	local wallH = WALL_TOP - FLOOR_Y
	-- 창 구멍 둘레 벽 (창 z −140 ~ 60, y 0 ~ 150)
	local wz0, wz1, wy0, wy1 = -140, 60, 0, 150
	add(
		list,
		"SideWall",
		"Block",
		v(4, wallH, BACK_Z * -1 + FRONT_Z),
		CREAM,
		"Plaster",
		P(x + 2, FLOOR_Y + wallH / 2, (BACK_Z + FRONT_Z) / 2),
		{ castShadow = false }
	)
	-- 창: 하늘(밝은 파랑) 판 — 벽보다 살짝 안쪽 (벽을 덮어 그려요)
	add(
		list,
		"WindowSky",
		"Block",
		v(1, wy1 - wy0, wz1 - wz0),
		SKY,
		"Neon",
		P(x - 0.6, (wy0 + wy1) / 2, (wz0 + wz1) / 2),
		{
			castShadow = false,
			transparency = 0.05,
		}
	)
	add(
		list,
		"WindowSkyLow",
		"Block",
		v(1, 40, wz1 - wz0),
		SKY_LOW,
		"Neon",
		P(x - 0.8, wy0 + 20, (wz0 + wz1) / 2),
		{ castShadow = false }
	)
	-- 먼 나무 실루엣 (창 아래쪽, 하늘 판에 붙은 납작한 원)
	for k = 0, 4 do
		local z = wz0 + 20 + k * 40
		add(
			list,
			"WindowTree",
			"Cylinder",
			v(0.4, 36, 36),
			if k % 2 == 0 then c(120, 170, 120) else c(100, 150, 104),
			"SmoothPlastic",
			P(x - 1.1, wy0 + 18.5, z),
			{ castShadow = false }
		)
	end
	-- 창틀 + 살 (원목)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"WindowFrame",
			v(6, 6, wz1 - wz0 + 12),
			WOOD_LIGHT,
			"Wood",
			P(x - 3, wy1 + 3, (wz0 + wz1) / 2),
			1,
			v(0, 0, 0)
		)
	)
	add(list, "WindowSill", "Block", v(18, 4, wz1 - wz0 + 16), WOOD, "Wood", P(x - 9, wy0 - 2, (wz0 + wz1) / 2))
	add(
		list,
		"WindowSillEdge",
		"Cylinder",
		v(wz1 - wz0 + 16, 4, 4),
		WOOD_LIGHT,
		"Wood",
		P(x - 18, wy0 - 2, (wz0 + wz1) / 2),
		{ rotation = ALONG_Z }
	)
	for _, z in { wz0 - 3, wz1 + 3 } do
		add(list, "WindowJamb", "Block", v(6, wy1 - wy0 + 6, 6), WOOD_LIGHT, "Wood", P(x - 3, (wy0 + wy1) / 2, z))
	end
	for k = 1, 3 do
		add(
			list,
			"WindowMullion",
			"Block",
			v(4, wy1 - wy0, 3),
			WOOD_LIGHT,
			"Wood",
			P(x - 2.5, (wy0 + wy1) / 2, wz0 + k * (wz1 - wz0) / 4)
		)
	end
	add(list, "WindowTransom", "Block", v(4, 3, wz1 - wz0), WOOD_LIGHT, "Wood", P(x - 2.5, wy0 + 100, (wz0 + wz1) / 2))
	-- 창빛 (차가운 하늘빛 SurfaceLight, 창 원인 파츠) + 금빛 햇살 줄기 (반투명, 그림자 없음)
	for _, z in { -90, 10 } do
		add(list, "WindowGlow", "Block", v(0.6, 60, 50), SKY_LOW, "Neon", P(x - 1.4, 70, z), {
			castShadow = false,
			transparency = 0.6,
			light = { kind = "Surface", color = COOL_LIGHT, brightness = 2.5, range = 16, angle = 120, face = "Left" },
		})
	end
	-- 창에서 비스듬히 들어오는 짧은 햇살 줄기 (창 근처에만 — 소개 카메라·언덕 시야를 가로지르지 않게)
	for k, spec in { { -100, 0.93 }, { -40, 0.94 }, { 20, 0.93 } } do
		add(list, "SunBeam", "Block", v(110, 6 + k, 10), SUN, "Neon", P(x - 58, 96 - k * 4, spec[1]), {
			rotation = v(0, 0, 24),
			transparency = spec[2],
			castShadow = false,
		})
	end
	-- 햇살 속 먼지
	for _, z in { -70, 0 } do
		add(list, "SunDust", "Block", v(40, 20, 30), SUN, "SmoothPlastic", P(x - 70, 60, z), {
			transparency = 1,
			castShadow = false,
			particle = "Dust",
			particleRate = 5,
		})
	end
	-- 창가 화분 3개 (테라코타 + 잎 흔들림)
	for i, z in { -110, -40, 30 } do
		local s = 1 + (i - 2) * 0.12
		local base = P(x - 10, wy0 + 0.2, z)
		add(
			list,
			"PlantPot",
			"Cylinder",
			v(10 * s, 10 * s, 10 * s),
			TERRACOTTA,
			"Plastic",
			v(base.x, base.y + 5 * s, base.z),
			{ rotation = UPRIGHT }
		)
		add(
			list,
			"PlantPotRim",
			"Cylinder",
			v(2 * s, 11.4 * s, 11.4 * s),
			shade(TERRACOTTA, 0.85),
			"Plastic",
			v(base.x, base.y + 10 * s, base.z),
			{ rotation = UPRIGHT }
		)
		for leaf = 0, 3 do
			local a = leaf * 90 + i * 20
			local lx, lz = math.cos(math.rad(a)) * 3 * s, -math.sin(math.rad(a)) * 3 * s
			add(
				list,
				"PlantLeaf",
				"Block",
				v(1, 12 * s, 4.5 * s),
				if leaf % 2 == 0 then LEAF else LEAF_DARK,
				"SmoothPlastic",
				v(base.x + lx, base.y + 16 * s, base.z + lz),
				{
					rotation = v(0, a, -18),
					castShadow = false,
					anim = { kind = "Sway", period = 4 + leaf * 0.7 + i * 0.3, amount = 6, axis = "X" },
				}
			)
		end
	end
	-- 커튼 (양옆, 살랑)
	for _, z in { wz0 - 10, wz1 + 10 } do
		add(list, "Curtain", "Block", v(1.4, 120, 16), c(250, 244, 232), "Fabric", P(x - 8, wy1 - 52, z), {
			castShadow = false,
			anim = { kind = "Sway", period = 6.5, amount = 2.5, axis = "X" },
		})
	end
	add(
		list,
		"CurtainRod",
		"Cylinder",
		v(wz1 - wz0 + 50, 2, 2),
		BRASS,
		"Metal",
		P(x - 8, wy1 + 10, (wz0 + wz1) / 2),
		{ rotation = ALONG_Z, reflectance = 0.3 }
	)
end

local function addLeftWall(list: { DecorSpec })
	local x = -SIDE_X
	local wallH = WALL_TOP - FLOOR_Y
	add(
		list,
		"SideWall",
		"Block",
		v(4, wallH, BACK_Z * -1 + FRONT_Z),
		CREAM,
		"Plaster",
		P(x - 2, FLOOR_Y + wallH / 2, (BACK_Z + FRONT_Z) / 2),
		{ castShadow = false }
	)
	-- 타일 띠
	add(list, "SideTile", "Block", v(1, 80, 420), TILE_B, "CeramicTiles", P(x + 0.5, COUNTER_TOP + 40, -60))
	add(list, "SideTileTrim", "Block", v(2, 2, 420), CREAM_DARK, "SmoothPlastic", P(x + 1, COUNTER_TOP + 81, -60))
	-- 벽 선반 2단 + 그릇·병
	for _, sy in { 70, 110 } do
		addAll(list, MapKitShapes.bevelBox("WallShelf", v(28, 3, 180), WOOD, "WoodPlanks", P(x + 14, sy, -60), 0.6))
		for k = 0, 5 do
			local z = -140 + k * 30
			if (k + sy // 10) % 3 == 0 then
				add(
					list,
					"ShelfJar",
					"Cylinder",
					v(14, 10, 10),
					c(236, 230, 214),
					"Glass",
					P(x + 12, sy + 8.5, z),
					{ rotation = UPRIGHT, transparency = 0.2, reflectance = 0.15 }
				)
				add(
					list,
					"ShelfJarRice",
					"Cylinder",
					v(9, 9, 9),
					GRAIN_B,
					"SmoothPlastic",
					P(x + 12, sy + 6, z),
					{ rotation = UPRIGHT }
				)
			else
				add(
					list,
					"ShelfBowl",
					"Cylinder",
					v(6, 16, 16),
					if k % 2 == 0 then PORCELAIN else c(200, 214, 230),
					"SmoothPlastic",
					P(x + 12, sy + 4.5, z),
					{ rotation = UPRIGHT, reflectance = 0.08 }
				)
			end
		end
	end
	-- 도구 걸이: 국자·뒤집개 (흔들림) + 행주
	add(
		list,
		"UtensilRail",
		"Cylinder",
		v(110, 1.6, 1.6),
		STEEL,
		"Metal",
		P(x + 6, 40, 45),
		{ rotation = ALONG_Z, reflectance = 0.3 }
	)
	for k = 0, 3 do
		local z = 4 + k * 26
		add(
			list,
			"UtensilHandle",
			"Block",
			v(1.2, 26, 2),
			if k % 2 == 0 then WOOD_DARK else STEEL,
			if k % 2 == 0 then "Wood" else "Metal",
			P(x + 6, 26, z),
			{
				anim = { kind = "Sway", period = 5 + k * 0.6, amount = 3, axis = "X" },
			}
		)
		add(list, "UtensilHead", "Cylinder", v(2, 8, 8), STEEL, "Metal", P(x + 7, 12, z), {
			rotation = UPRIGHT,
			reflectance = 0.3,
			anim = { kind = "Sway", period = 5 + k * 0.6, amount = 3, axis = "X" },
		})
	end
	for i, z in { 114, 126 } do
		add(
			list,
			"DishTowel",
			"Block",
			v(1, 30, 12),
			if i == 1 then c(236, 236, 230) else c(170, 204, 220),
			"Fabric",
			P(x + 6, 24, z),
			{
				castShadow = false,
				anim = { kind = "Sway", period = 7 + i, amount = 2, axis = "X" },
			}
		)
	end
	add(
		list,
		"TowelBar",
		"Cylinder",
		v(28, 1.2, 1.2),
		STEEL,
		"Metal",
		P(x + 6, 40, 120),
		{ rotation = ALONG_Z, reflectance = 0.3 }
	)
end

local function addFrontWall(list: { DecorSpec })
	local z = FRONT_Z
	local wallH = WALL_TOP - FLOOR_Y
	add(
		list,
		"FrontWall",
		"Block",
		v(SIDE_X * 2, wallH, 4),
		CREAM,
		"Plaster",
		P(0, FLOOR_Y + wallH / 2, z + 2),
		{ castShadow = false }
	)
	-- 앞 왼쪽 구석 원목 쌀통 (낮게 — 위에서 보는 카메라를 가리지 않게) + 뚜껑 + 됫박
	local bx, bz = -SIDE_X + 44, z - 52
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RiceBin",
			v(80, 56, 96),
			WOOD_DARK,
			"Wood",
			P(bx, FLOOR_Y + 28, bz),
			{ radius = 2.5, style = "vertical" }
		)
	)
	addAll(list, MapKitShapes.bevelBox("RiceBinLid", v(86, 5, 102), WOOD, "WoodPlanks", P(bx, FLOOR_Y + 58.5, bz), 1.2))
	for _, dz in { -30, 30 } do
		add(
			list,
			"RiceBinBand",
			"Block",
			v(81, 4, 2),
			IRON_LIGHT,
			"Metal",
			P(bx, FLOOR_Y + 40, bz + dz),
			{ reflectance = 0.2 }
		)
	end
	add(
		list,
		"RiceBinLabel",
		"Block",
		v(1, 18, 30),
		c(244, 238, 222),
		"Fabric",
		P(bx + 40.6, FLOOR_Y + 32, bz),
		{ castShadow = false }
	)
	add(
		list,
		"RiceBinLabelMark",
		"Block",
		v(1.2, 8, 8),
		LABEL_NAVY,
		"Fabric",
		P(bx + 40.8, FLOOR_Y + 33, bz),
		{ castShadow = false }
	)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RiceScoop",
			v(14, 8, 14),
			WOOD_LIGHT,
			"Wood",
			P(bx + 10, FLOOR_Y + 65, bz - 20),
			{ radius = 1, rotation = v(0, 20, 0) }
		)
	)
	add(list, "RiceScoopRice", "Ball", v(12, 5, 12), RICE, "SmoothPlastic", P(bx + 10, FLOOR_Y + 69, bz - 20))
	add(list, "Doorway", "Block", v(80, 150, 2), c(60, 56, 54), "SmoothPlastic", P(140, FLOOR_Y + 75, z - 1))
	for k = -1, 1 do
		add(
			list,
			"Noren",
			"Block",
			v(24, 50, 1),
			if k == 0 then PAL.NorenLight else PAL.Noren,
			"Fabric",
			P(140 + k * 25, FLOOR_Y + 124, z - 3),
			{
				anim = { kind = "Sway", period = 5.5 + k * 0.5, amount = 3, axis = "X" },
			}
		)
	end
end

-- 왼쪽 벽 조리대 + 가스레인지·주전자 (눈높이 시야의 왼쪽을 채워요)
local function addLeftCounter(list: { DecorSpec })
	local x0 = -SIDE_X
	local depth = 60
	local z0, z1 = BACK_Z + 4, 10
	local zl = z1 - z0
	add(
		list,
		"LeftCounterTop",
		"Block",
		v(depth, 5, zl),
		shade(WOOD, 0.95),
		"WoodPlanks",
		P(x0 + depth / 2, COUNTER_TOP - 2.5, (z0 + z1) / 2)
	)
	add(
		list,
		"LeftCounterEdge",
		"Cylinder",
		v(zl, 5, 5),
		WOOD,
		"Wood",
		P(x0 + depth, COUNTER_TOP - 2.5, (z0 + z1) / 2),
		{ rotation = ALONG_Z }
	)
	add(
		list,
		"LeftCabinet",
		"Block",
		v(depth - 6, COUNTER_TOP - 5 - FLOOR_Y, zl - 4),
		SAGE_DARK,
		"SmoothPlastic",
		P(x0 + depth / 2 - 3, (COUNTER_TOP - 5 + FLOOR_Y) / 2, (z0 + z1) / 2)
	)
	for k = 0, 3 do
		local z = z0 + (k + 0.5) * zl / 4
		add(
			list,
			"LeftCabinetDoor",
			"Block",
			v(1.2, 66, zl / 4 - 4),
			shade(SAGE, 1.08),
			"SmoothPlastic",
			P(x0 + depth - 5.4, FLOOR_Y + 9 + 33, z)
		)
		add(
			list,
			"CabinetKnob",
			"Ball",
			v(2.2, 2.2, 2.2),
			BRASS,
			"Metal",
			P(x0 + depth - 4.4, COUNTER_TOP - 18, z + (if k % 2 == 0 then 18 else -18)),
			{ reflectance = 0.3 }
		)
	end
	-- 가스레인지 (무쇠 상판 + 삼발이 + 푸른 불꽃 하나 꺼짐) + 주전자
	local rz = -150
	addAll(
		list,
		MapKitShapes.roundedBox(
			"Range",
			v(46, 4, 56),
			IRON_LIGHT,
			"Metal",
			P(x0 + 28, COUNTER_TOP + 2, rz),
			{ radius = 1, style = "vertical" }
		),
		{ reflectance = 0.15 }
	)
	for _, dz in { -14, 14 } do
		addAll(
			list,
			MapKitShapes.ring("RangeGrate", 7, 1, 1.2, 10, IRON_DARK, "Metal", P(x0 + 28, COUNTER_TOP + 4.6, rz + dz))
		)
	end
	addAll(
		list,
		MapKitShapes.capsule(
			"Kettle",
			16,
			14,
			c(72, 140, 138),
			"SmoothPlastic",
			P(x0 + 28, COUNTER_TOP + 12, rz - 14),
			UPRIGHT
		),
		{ reflectance = 0.15 }
	)
	add(
		list,
		"KettleHandle",
		"Block",
		v(10, 1.2, 1.6),
		IRON_DARK,
		"SmoothPlastic",
		P(x0 + 28, COUNTER_TOP + 21, rz - 14)
	)
	add(
		list,
		"KettleSpout",
		"Cylinder",
		v(8, 2.4, 2.4),
		c(72, 140, 138),
		"SmoothPlastic",
		P(x0 + 38, COUNTER_TOP + 12, rz - 14),
		{ rotation = v(0, 0, 35) }
	)
	add(
		list,
		"KettleSteam",
		"Ball",
		v(1.6, 1.6, 1.6),
		c(72, 140, 138),
		"SmoothPlastic",
		P(x0 + 41.5, COUNTER_TOP + 15, rz - 14),
		{
			particle = "Steam",
			particleRate = 1.5,
		}
	)
	-- 도마 + 무 (조리대 앞쪽)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"CuttingBoard",
			v(30, 2.4, 44),
			WOOD_LIGHT,
			"Wood",
			P(x0 + 30, COUNTER_TOP + 1.2, -70),
			{ radius = 0.8, rotation = v(0, 8, 0) }
		)
	)
	addAll(
		list,
		MapKitShapes.capsule(
			"Daikon",
			26,
			6,
			c(246, 244, 236),
			"SmoothPlastic",
			P(x0 + 30, COUNTER_TOP + 5.4, -72),
			v(0, 98, 0)
		)
	)
	add(
		list,
		"DaikonLeaf",
		"Block",
		v(1, 10, 6),
		LEAF,
		"SmoothPlastic",
		P(x0 + 32, COUNTER_TOP + 7, -88),
		{ rotation = v(70, 8, 0), castShadow = false }
	)
end

-- 앞 벽 칠판 메뉴판 + 그림 (눈높이 시야 뒤쪽을 채워요)
local function addFrontDetails(list: { DecorSpec })
	local z = FRONT_Z
	addAll(
		list,
		MapKitShapes.bevelBox("MenuBoardFrame", v(86, 2, 56), WOOD_DARK, "Wood", P(10, 70, z - 1), 0.8, v(90, 0, 0))
	)
	add(list, "MenuBoard", "Block", v(78, 48, 1), c(44, 66, 56), "Slate", P(10, 70, z - 2.4))
	for k = 0, 4 do
		add(
			list,
			"MenuChalk",
			"Block",
			v(34 + (k % 3) * 8, 1.4, 0.4),
			c(236, 236, 226),
			"SmoothPlastic",
			P(-2 + (k % 2) * 4, 86 - k * 8, z - 3),
			{ castShadow = false }
		)
		add(
			list,
			"MenuChalkPrice",
			"Block",
			v(8, 1.4, 0.4),
			c(250, 222, 150),
			"SmoothPlastic",
			P(38, 86 - k * 8, z - 3),
			{ castShadow = false }
		)
	end
	-- 초밥 그림 (작은 계란초밥 한 점 — 세계관)
	add(
		list,
		"MenuSushiRice",
		"Block",
		v(12, 4, 0.5),
		c(250, 248, 240),
		"SmoothPlastic",
		P(-24, 56, z - 3),
		{ castShadow = false }
	)
	add(
		list,
		"MenuSushiEgg",
		"Block",
		v(13, 3, 0.6),
		c(248, 208, 72),
		"SmoothPlastic",
		P(-24, 59.5, z - 3.1),
		{ castShadow = false }
	)
	add(
		list,
		"MenuSushiNori",
		"Block",
		v(3, 7.4, 0.7),
		c(30, 36, 32),
		"SmoothPlastic",
		P(-24, 57.5, z - 3.2),
		{ castShadow = false }
	)
	-- 벽 액자 (논과 산 그림)
	addAll(
		list,
		MapKitShapes.bevelBox("PictureFrame", v(44, 2, 32), WOOD, "Wood", P(-150, 130, z - 1), 0.6, v(90, 0, 0))
	)
	add(
		list,
		"PictureSky",
		"Block",
		v(38, 26, 0.6),
		SKY_LOW,
		"SmoothPlastic",
		P(-150, 130, z - 2.2),
		{ castShadow = false }
	)
	add(
		list,
		"PictureMountain",
		"Wedge",
		v(0.6, 14, 30),
		c(120, 150, 180),
		"SmoothPlastic",
		P(-150, 128, z - 2.4),
		{ rotation = v(0, 90, 0), castShadow = false }
	)
	add(
		list,
		"PicturePaddy",
		"Block",
		v(38, 7, 0.7),
		c(140, 190, 90),
		"SmoothPlastic",
		P(-150, 120.5, z - 2.6),
		{ castShadow = false }
	)
end

---------------------------------------------------------------- MG: 작업대 위 소품 (쌀 포대·계량컵·화분)

local function addTableProps(list: { DecorSpec })
	-- 쌀 포대 (왼쪽 앞): 마대 + 묶은 입구 + 남색 라벨, 앞에 흘린 쌀
	local sx, sz = -86, 40
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RiceSack",
			v(20, 24, 14),
			BURLAP,
			"Fabric",
			P(sx, COUNTER_TOP + 12, sz),
			{ radius = 4, rotation = v(0, 18, 0) }
		)
	)
	add(
		list,
		"RiceSackNeck",
		"Cylinder",
		v(6, 8, 8),
		BURLAP_DARK,
		"Fabric",
		P(sx, COUNTER_TOP + 27, sz),
		{ rotation = UPRIGHT }
	)
	add(
		list,
		"RiceSackTie",
		"Cylinder",
		v(1.4, 9, 9),
		c(52, 70, 120),
		"Fabric",
		P(sx, COUNTER_TOP + 26, sz),
		{ rotation = UPRIGHT }
	)
	add(list, "RiceSackTop", "Ball", v(8, 8, 8), BURLAP, "Fabric", P(sx, COUNTER_TOP + 31, sz))
	add(
		list,
		"RiceSackLabel",
		"Block",
		v(10, 9, 0.4),
		LABEL_NAVY,
		"Fabric",
		P(sx + 2.3, COUNTER_TOP + 12, sz + 7.0),
		{ rotation = v(0, 18, 0), castShadow = false }
	)
	add(
		list,
		"RiceSackLabelBand",
		"Block",
		v(8, 1.4, 0.5),
		c(244, 238, 222),
		"Fabric",
		P(sx + 2.3, COUNTER_TOP + 12, sz + 7.1),
		{ rotation = v(0, 18, 0), castShadow = false }
	)
	local rng = MapKitShapes.rng(9001)
	for i = 1, 24 do
		local gx, gz = sx + rng:range(-4, 18), sz + rng:range(8, 22)
		add(
			list,
			"RiceGrain",
			"Cylinder",
			v(0.7, 0.36, 0.36),
			if i % 2 == 0 then GRAIN_A else GRAIN_B,
			"SmoothPlastic",
			P(gx, COUNTER_TOP + 0.18, gz),
			{
				rotation = v(0, rng:range(0, 180), 0),
				castShadow = false,
			}
		)
	end
	-- 계량컵 3개 (스테인리스, 크기 다르게) + 손잡이
	for i, cup in { { -62, 58, 9 }, { -50, 64, 7 }, { -71, 70, 5.5 } } do
		local d = cup[3]
		addAll(
			list,
			MapKitShapes.rimDisc(
				"MeasuringCup",
				d,
				d * 0.8,
				STEEL,
				"Metal",
				P(cup[1], COUNTER_TOP + d * 0.4, cup[2]),
				{ rimWidth = 0.4, segments = 12, rimColor = shade(STEEL, 1.12) }
			),
			{ reflectance = 0.3 }
		)
		add(
			list,
			"CupHandle",
			"Block",
			v(d * 0.9, 0.6, 1.2),
			STEEL,
			"Metal",
			P(cup[1] + d * 0.85, COUNTER_TOP + d * 0.7, cup[2]),
			{ rotation = v(0, i * 25, 0), reflectance = 0.3 }
		)
	end
	-- 물 주전자 (오른쪽 앞) + 수건 접은 것
	addAll(
		list,
		MapKitShapes.capsule("WaterJug", 18, 12, c(214, 232, 244), "Glass", P(40, COUNTER_TOP + 9, 72), UPRIGHT),
		{ transparency = 0.25, reflectance = 0.2 }
	)
	add(
		list,
		"WaterJugLid",
		"Cylinder",
		v(2, 9, 9),
		c(70, 110, 96),
		"SmoothPlastic",
		P(40, COUNTER_TOP + 18.5, 72),
		{ rotation = UPRIGHT }
	)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"FoldedTowel",
			v(18, 3, 12),
			c(232, 224, 210),
			"Fabric",
			P(80, COUNTER_TOP + 1.5, 22),
			{ radius = 1, rotation = v(0, -12, 0) }
		)
	)
	-- 작은 허브 화분 (오른쪽 뒤)
	local hx, hz = 78, -60
	add(
		list,
		"PlantPot",
		"Cylinder",
		v(10, 10, 10),
		TERRACOTTA,
		"Plastic",
		P(hx, COUNTER_TOP + 5, hz),
		{ rotation = UPRIGHT }
	)
	for leaf = 0, 4 do
		local a = leaf * 72
		add(
			list,
			"PlantLeaf",
			"Block",
			v(1, 10, 4),
			if leaf % 2 == 0 then LEAF else LEAF_DARK,
			"SmoothPlastic",
			P(hx + math.cos(math.rad(a)) * 2.5, COUNTER_TOP + 15, hz - math.sin(math.rad(a)) * 2.5),
			{
				rotation = v(0, a, -16),
				castShadow = false,
				anim = { kind = "Sway", period = 3.6 + leaf * 0.5, amount = 5, axis = "X" },
			}
		)
	end
	-- 밥공기·젓가락 받침 (왼쪽 뒤)
	addAll(
		list,
		MapKitShapes.rimDisc(
			"RiceBowl",
			13,
			6,
			PORCELAIN,
			"SmoothPlastic",
			P(-74, COUNTER_TOP + 3, -66),
			{ rimColor = PAL.PorcelainRim, rimWidth = 0.6, segments = 14 }
		),
		{ reflectance = 0.08 }
	)
	add(list, "BowlRice", "Ball", v(11, 6, 11), RICE, "SmoothPlastic", P(-74, COUNTER_TOP + 6.4, -66))
	for k = 0, 1 do
		addAll(
			list,
			MapKitShapes.capsule(
				"Chopstick",
				23,
				0.8,
				WOOD_DARK,
				"Wood",
				P(-56, COUNTER_TOP + 0.5 + k * 0.1, -70 + k * 1.6),
				v(0, 70, 0)
			)
		)
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addRiserGrains(list)
	addEdgeGrains(list)
	addHillSteam(list)
	addPot(list)
	addValves(list)
	addLid(list)
	addPaddle(list)
	addTimerPanel(list)
	addLamp(list)
	addCounter(list)
	addBackWall(list)
	addWindowWall(list)
	addLeftWall(list)
	addFrontWall(list)
	addLeftCounter(list)
	addFrontDetails(list)
	addTableProps(list)
	return list
end

-- ① 창가에서 솥 전체 + 햇살 → ② 타이머 → ③ 오른쪽 밸브와 띠 → ④ 주걱 위에서 언덕을 내려다보는 반전 샷 → ⑤ 출발 자리
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = P(118, 46, 92), lookAt = P(0, -4, -8) },
		{ pos = P(10, -4, 74), lookAt = P(0, -10, 47) },
		{ pos = P(76, 16, 30), lookAt = P(30, 1, -2) },
		{ pos = P(44, 44, -38), lookAt = P(-2, 2, 8) },
		{ pos = P(0, 13, 44), lookAt = P(0, 3, -4) },
	}
end

return Art
