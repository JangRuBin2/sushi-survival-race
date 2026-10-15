--!strict
-- "온천탕 인형뽑기" 아트 데이터 (m5-39). Roblox API를 쓰지 않아요 — lune 테스트·렌더러에서 바로 불러요.
-- 아트 디렉션 "해 질 녘 온천 여관 노천탕, 종이등과 김" (스펙 "## 아트", docs/REFERENCE-map-art-direction.md).
-- 판정 지오메트리(데크 조각·인형뽑기 몸체)는 OnsenClawLayout 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   Art.decor() -> { DecorSpec }               고정 장식 (Decor 폴더). Extended 예산 (BUDGET)
--   Art.deckDecor(deck) -> { DecorSpec }       데크 하나에 붙는 장식 (가장자리 판·받침 기둥) — build가 데크 Model 안에
--                                              넣어 데크와 같이 가라앉아요. 이름 RIM_NAME 판은 경고 때 깜빡여요. anim 없음
--   Art.clawRig() -> { DecorSpec }             움직이는 집게 (서버가 위아래로 옮김, anim 없음)
--   Art.slamLights() -> { DecorSpec }          기계 밑바닥 둘레 불빛 (서버가 경고 때 주황·흰색으로 깜빡임)
--   Art.introCamera() -> { IntroPoint }        여관 처마 → 인형뽑기 → 물 위 반전 → 바깥 1단 → 출발 자리
--   Art.LIGHTING / COLORS / deckColor(tier, k) / WATER_LIGHT
--
-- 층 (가이드 2절): FG = 데크 가장자리 판(윗면 −0.1)·받침 기둥, 탕 둘레 바위·돌벽
--                 MG = 분홍 탁상 인형뽑기 + 흰 고양이 인형, 나무통·목욕 의자·수건 탑·대나무 국자, 종이등 기둥,
--                      램프 걸이(위에서 기계를 비추는 그림자 램프), 물 위 초밥 쟁반이 떠 있는 돌 수반(탕 바깥)
--                 BG = 탕 바닥 돌판(−38, 안전망 −25보다 10 이상 아래), 마당 돌바닥(윗면 8), 여관 목조 건물·노렌·처마 등·
--                      ♨ 네온·"온천" 종이 간판, 대나무 울타리·대나무 숲, 석등
-- 좌표는 탕 중심 기준으로 쓰고 P()로 origin 로컬로 옮겨요 (탕 중심 = Layout.CENTER_X/Z). 북쪽(−Z) = 여관.

local Layout = require(script.Parent.OnsenClawLayout)
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
Art.RIM_NAME = "DeckRim" -- 데크 가장자리 판 (경고 때 깜빡)
Art.GROUND_Y = 8 -- 마당 돌바닥 윗면
Art.POOL_FLOOR_Y = -38 -- 탕 바닥 돌판 윗면 (안전망 −25보다 10 이상 아래)

local PAL = MapKitLogic.PALETTE
local shade = MapKitLogic.shade

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- 색 (60 = 짙은 나무·바위·저녁 남색, 30 = 꿀색 데크, 10 = 종이등 주황·♨·분홍 기계·흰 고양이)
local HONEY = c(226, 172, 98) -- 밟는 데크
local WOOD_DARK = c(92, 62, 44)
local WOOD_MID = c(132, 92, 60)
local HINOKI = c(214, 180, 128) -- 노송나무 통
local ROCK = c(118, 116, 120)
local ROCK_DARK = c(84, 84, 92)
local ROCK_MOSS = c(98, 120, 84)
local ROCK_LIGHT = c(150, 144, 138)
local STONE_PAVE = c(116, 112, 108)
local GRAVEL = c(96, 92, 90)
local PLASTER = c(196, 184, 160)
local ROOF = c(52, 56, 66)
local PAPER = c(255, 232, 186) -- 종이등·장지 불빛
local LANTERN_RED = c(206, 64, 52)
local NOREN = c(48, 64, 112)
local BAMBOO = c(150, 168, 92)
local BAMBOO_DARK = c(98, 120, 60)
local BAMBOO_FENCE = c(176, 150, 96)
local PINK = c(240, 140, 180) -- 인형뽑기 히어로 색 (#F08CB4)
local PINK_DARK = shade(PINK, 0.72)
local PINK_LIGHT = shade(PINK, 1.18)
local CAT = c(250, 248, 244)
local CAT_SHADE = c(226, 222, 218)
local GOLD = c(236, 196, 96)
local TOWEL_A = c(246, 244, 238)
local TOWEL_B = c(170, 206, 230)
local TOWEL_C = c(240, 196, 206)

Art.COLORS = {
	water = c(79, 201, 192), -- #4FC9C0
	waterDeep = c(22, 96, 104),
	body = PINK,
	warn = c(255, 128, 36),
	warnWhite = c(255, 252, 244),
	ringOuter = c(255, 252, 240), -- 충격파 고리 앞면 (흰색 비중 크게)
	ringInner = c(255, 142, 52),
	slamIdle = c(255, 214, 236), -- 밑바닥 불빛 평소
	rim = c(150, 104, 64),
	post = c(88, 60, 42),
}

-- 데크 색: 높은 단일수록 한 shade 밝게, 조각마다 조금씩 (결이 읽히게)
function Art.deckColor(tier: number, index: number, k: number): RGB
	local base = shade(HONEY, 0.9 + 0.05 * tier)
	-- 데크마다 번갈아 한 톤 (가라앉는 단위가 보이게), 조각마다 결 흔들림
	local deckTone = if index % 2 == 0 then 0.9 else 1.03
	local wobble = ({ 1, 0.96, 1.02, 0.98 })[(k - 1) % 4 + 1]
	return shade(shade(base, deckTone), wobble)
end

-- 물 표면에 붙는 청록 빛 (그림자 없음, SurfaceLight range ≤ 16) — build가 물 표면 파츠에 붙여요
Art.WATER_LIGHT = { kind = "Surface", color = c(110, 230, 220), brightness = 1.2, range = 14, angle = 120 } :: LightSpec

-- 맵 조명: 해 진 직후(19.3), 남보라 Ambient, 따뜻한 김 Atmosphere, 종이등이 Bloom으로 번지게
Art.LIGHTING = {
	ClockTime = 19.3,
	Brightness = 1.6,
	Ambient = c(60, 55, 95),
	OutdoorAmbient = c(96, 84, 128),
	EnvironmentDiffuseScale = 0.7,
	EnvironmentSpecularScale = 1,
	ExposureCompensation = 0.6,
	GeographicLatitude = 35,
	Atmosphere = {
		Density = 0.35,
		Offset = 0.08,
		Color = c(176, 150, 160),
		Decay = c(92, 74, 110),
		Glare = 0.2,
		Haze = 1.8,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.08, TintColor = c(255, 242, 232) },
	Bloom = { Intensity = 0.6, Size = 24, Threshold = 0.92 },
	SunRays = { Intensity = 0.05, Spread = 0.6 },
} :: MapLighting.LightingPreset

local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 탕 중심 기준 → origin 로컬
local function P(x: number, y: number, z: number): Vec3
	return { x = CX + x, y = y, z = CZ + z }
end

-- 각도(도, +X에서 −Z 쪽)·반지름 → 탕 중심 기준 (x, z)
local function pol(angle: number, radius: number): (number, number)
	local rad = math.rad(angle)
	return radius * math.cos(rad), -radius * math.sin(rad)
end

local UPRIGHT = v(0, 0, 90)

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
			s.reflectance = extra.reflectance or s.reflectance
			s.transparency = extra.transparency or s.transparency
			s.castShadow = if extra.castShadow ~= nil then extra.castShadow else s.castShadow
		end
		table.insert(list, s)
	end
end

-- 세운 원기둥 (밑면 y0, 높이 h)
local function post(
	list: { DecorSpec },
	name: string,
	x: number,
	y0: number,
	z: number,
	h: number,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	local e: Extra = extra or {}
	e.rotation = UPRIGHT
	add(list, name, "Cylinder", v(h, d, d), color, material, P(x, y0 + h / 2, z), e)
end

-- 세운 판(간판)의 테두리 4개 (판 앞면을 가리지 않게 가장자리 띠만). 판 크기 w×h, 깊이 d, 띠 두께 t
local function boardFrame(
	list: { DecorSpec },
	name: string,
	w: number,
	h: number,
	d: number,
	t: number,
	color: RGB,
	material: string,
	center: Vec3
)
	local cx, cy, cz = center.x, center.y, center.z
	add(list, name, "Block", v(w + 2 * t, t, d), color, material, v(cx, cy + h / 2 + t / 2, cz))
	add(list, name, "Block", v(w + 2 * t, t, d), color, material, v(cx, cy - h / 2 - t / 2, cz))
	add(list, name, "Block", v(t, h, d), color, material, v(cx - w / 2 - t / 2, cy, cz))
	add(list, name, "Block", v(t, h, d), color, material, v(cx + w / 2 + t / 2, cy, cz))
end

---------------------------------------------------------------- 데크 장식 (데크 Model 안, 같이 가라앉음)

function Art.deckDecor(deck: Layout.Deck): { DecorSpec }
	local list: { DecorSpec } = {}
	local segments = Layout.deckSegments(deck)
	for k, seg in segments do
		-- 바깥 가장자리 판: 윗면보다 0.1 낮게, 바깥으로 0.4 (두께감·경고 깜빡임)
		local rx, rz = pol(seg.angle, deck.outer + 0.2)
		add(
			list,
			Art.RIM_NAME,
			"Block",
			v(0.4, 1.7, seg.width + 0.08),
			if k % 2 == 0 then Art.COLORS.rim else shade(Art.COLORS.rim, 0.9),
			"Wood",
			P(rx, deck.top - 0.1 - 0.85, rz),
			{ rotation = v(0, seg.angle, 0) }
		)
	end
	-- 받침 기둥 2개 (데크 밑면 → 물속 깊이)
	local rMid = (deck.inner + deck.outer) / 2
	for _, f in { 0.3, 0.7 } do
		local px, pz = pol(deck.startAngle + deck.sweep * f, rMid)
		local bottom = deck.top - Layout.DECK_THICKNESS
		post(list, "DeckPost", px, -14, pz, bottom - -14, 1.1, Art.COLORS.post, "Wood", { castShadow = false })
	end
	return list
end

---------------------------------------------------------------- 인형뽑기 (움직이는 것)

local H = Layout.BODY_HALF
local CASE_BOTTOM = 10.5 -- 상품 바닥 (유리 상자 시작)
local CASE_TOP = 20.5
local HEADER_TOP = Layout.BODY_TOP_Y

Art.CLAW_REST_Y = 19.2 -- 집게 허브 높이 (평소)
Art.CLAW_DROP = 3.6 -- 경고 동안 내려가는 거리 (고양이 머리 위까지)

function Art.clawRig(): { DecorSpec }
	local list: { DecorSpec } = {}
	local y = Art.CLAW_REST_Y
	local steel = c(214, 216, 222)
	post(list, "ClawCable", 1.2, y + 0.6, -0.8, CASE_TOP - y - 0.4, 0.18, c(60, 60, 66), "Metal")
	add(
		list,
		"ClawHub",
		"Cylinder",
		v(0.9, 1.6, 1.6),
		GOLD,
		"Metal",
		P(1.2, y + 0.4, -0.8),
		{ rotation = UPRIGHT, reflectance = 0.25 }
	)
	add(list, "ClawHub", "Ball", v(1.1, 1.1, 1.1), PINK_LIGHT, "SmoothPlastic", P(1.2, y + 1.0, -0.8))
	for i = 0, 2 do
		local a = i * 120 + 30
		local dx, dz = pol(a, 0.9)
		add(list, "ClawProng", "Block", v(0.3, 2.2, 0.3), steel, "Metal", P(1.2 + dx, y - 0.8, -0.8 + dz), {
			rotation = v(0, a, 22),
			reflectance = 0.3,
		})
		local tx, tz = pol(a, 1.5)
		add(
			list,
			"ClawProng",
			"Ball",
			v(0.42, 0.42, 0.42),
			steel,
			"Metal",
			P(1.2 + tx, y - 1.9, -0.8 + tz),
			{ reflectance = 0.3 }
		)
	end
	return list
end

-- 기계 밑바닥 둘레 불빛 띠 (4단 데크 윗면 바로 위, 몸체 면에 0.1 붙어 나와요)
function Art.slamLights(): { DecorSpec }
	local list: { DecorSpec } = {}
	local y = Layout.TIERS[Layout.TOP_TIER].top + 1.4
	for i = 0, 3 do
		local yaw = i * 90
		local nx, nz = pol(yaw, H + 0.15)
		add(
			list,
			"SlamLight",
			"Block",
			v(0.3, 0.6, 2 * H - 1),
			Art.COLORS.slamIdle,
			"Neon",
			P(nx, y, nz),
			{ rotation = v(0, yaw, 0) }
		)
	end
	return list
end

---------------------------------------------------------------- 고정 장식

-- 인형뽑기 기계 (정적). 충돌 상자 ±H 안에 딱 맞게, 유리 상자 안에 흰 고양이 인형
local function clawMachine(list: { DecorSpec })
	-- 아래 몸통 (물속 −10 → 상품 바닥)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"MachineCabinet",
			v(2 * H, CASE_BOTTOM - Layout.BODY_BOTTOM_Y, 2 * H),
			PINK,
			"SmoothPlastic",
			P(0, (CASE_BOTTOM + Layout.BODY_BOTTOM_Y) / 2, 0),
			{ radius = 0.9, style = "vertical" }
		),
		{ reflectance = 0.08 }
	)
	-- 몸통 띠 (밝은 분홍·어두운 분홍 두 줄)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"MachineBand",
			v(2 * H - 0.4, 0, 2 * H - 0.4),
			0.3,
			0.7,
			PINK_LIGHT,
			"SmoothPlastic",
			P(0, 9.2, 0)
		)
	)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"MachineBand",
			v(2 * H - 0.4, 0, 2 * H - 0.4),
			0.3,
			0.5,
			PINK_DARK,
			"SmoothPlastic",
			P(0, 3.4, 0)
		)
	)
	-- 앞(남쪽, +Z) 조작판: 몸체 면에 붙은 가파른 판(76°, 0.15만 튀어나옴 — 올라설 선반처럼 안 보이게, QA P3-1)
	-- + 조이스틱 + 앞면 큰 버튼 + 동전 구멍 + 상품 문. 전부 충돌 없음, 충돌 몸체(±H) 밖으로 0.3 이하
	add(list, "ControlPanel", "Wedge", v(7, 2.4, 0.6), PINK_LIGHT, "SmoothPlastic", P(0, 9.3, H - 0.15), {
		rotation = v(0, 180, 0),
	})
	post(list, "Joystick", -1.8, 9.6, H - 0.3, 1.6, 0.25, c(60, 60, 70), "Metal")
	add(list, "JoystickKnob", "Ball", v(0.8, 0.8, 0.8), c(255, 90, 110), "SmoothPlastic", P(-1.8, 11.3, H - 0.3))
	add(list, "PushButton", "Cylinder", v(0.3, 1.2, 1.2), c(255, 230, 90), "Neon", P(1.6, 9.4, H + 0.1), {
		rotation = v(0, 90, 0),
	})
	add(list, "CoinSlot", "Block", v(1.4, 2, 0.2), c(60, 58, 64), "Metal", P(2.6, 7.4, H + 0.05), { reflectance = 0.2 })
	add(list, "PrizeDoor", "Block", v(3.6, 3, 0.2), PINK_DARK, "SmoothPlastic", P(-1.6, 6.9, H + 0.05))
	add(list, "PrizeDoorTrim", "Block", v(3.9, 0.3, 0.25), GOLD, "Metal", P(-1.6, 8.5, H + 0.05))
	-- 유리 상자: 네 귀퉁이 기둥 + 얇은 유리 4장 + 상품 바닥
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			post(
				list,
				"CasePost",
				sx * (H - 0.45),
				CASE_BOTTOM,
				sz * (H - 0.45),
				CASE_TOP - CASE_BOTTOM,
				0.9,
				PINK_LIGHT,
				"SmoothPlastic"
			)
		end
	end
	for i = 0, 3 do
		local yaw = i * 90
		local gx, gz = pol(yaw, H - 0.15)
		add(
			list,
			"CaseGlass",
			"Block",
			v(0.15, CASE_TOP - CASE_BOTTOM, 2 * H - 1.6),
			c(210, 236, 240),
			"Glass",
			P(gx, (CASE_BOTTOM + CASE_TOP) / 2, gz),
			{
				rotation = v(0, yaw, 0),
				transparency = 0.65,
				reflectance = 0.2,
				castShadow = false,
			}
		)
	end
	add(
		list,
		"PrizeFloor",
		"Block",
		v(2 * H - 0.8, 0.3, 2 * H - 0.8),
		c(250, 210, 228),
		"SmoothPlastic",
		P(0, CASE_BOTTOM + 0.15, 0)
	)
	-- 머리 상자 (분홍) + 전구 띠 + 위 "온천" 간판
	addAll(
		list,
		MapKitShapes.roundedBox(
			"MachineHeader",
			v(2 * H, HEADER_TOP - CASE_TOP, 2 * H),
			PINK,
			"SmoothPlastic",
			P(0, (CASE_TOP + HEADER_TOP) / 2, 0),
			{ radius = 0.6, style = "vertical" }
		),
		{ reflectance = 0.08 }
	)
	add(
		list,
		"HeaderGantry",
		"Block",
		v(2 * H - 1.2, 0.4, 0.5),
		c(200, 200, 210),
		"Metal",
		P(0, CASE_TOP - 0.3, -0.8),
		{ reflectance = 0.3 }
	)
	for i = 0, 3 do
		local yaw = i * 90
		for j = -2, 2 do
			local nx, nz = pol(yaw, H + 0.12)
			local tx, tz = pol(yaw + 90, j * 2.3)
			add(
				list,
				"MarqueeBulb",
				"Ball",
				v(0.55, 0.55, 0.55),
				c(255, 236, 180),
				"Neon",
				P(nx + tx, CASE_TOP + 1.8, nz + tz)
			)
		end
	end
	-- 간판: 흰 고양이 귀가 달린 분홍 테두리 판 ("온천") — 몸체 위, 올라설 수 없는 높이
	add(
		list,
		"SignBoard",
		"Block",
		v(9, 4.2, 0.8),
		c(255, 246, 236),
		"SmoothPlastic",
		P(0, HEADER_TOP + 2.6, 0),
		{ light = { kind = "Point", color = c(255, 170, 210), brightness = 1.4, range = 22 } }
	)
	boardFrame(list, "SignFrame", 9, 4.2, 1.2, 0.5, PINK_DARK, "SmoothPlastic", P(0, HEADER_TOP + 2.6, 0))
	add(list, "SignText", "Block", v(1.4, 2.4, 0.2), LANTERN_RED, "SmoothPlastic", P(-1.6, HEADER_TOP + 2.6, 0.45))
	add(list, "SignText", "Block", v(1.4, 2.4, 0.2), LANTERN_RED, "SmoothPlastic", P(1.6, HEADER_TOP + 2.6, 0.45))
	add(list, "SignText", "Block", v(1.4, 2.4, 0.2), LANTERN_RED, "SmoothPlastic", P(-1.6, HEADER_TOP + 2.6, -0.45))
	add(list, "SignText", "Block", v(1.4, 2.4, 0.2), LANTERN_RED, "SmoothPlastic", P(1.6, HEADER_TOP + 2.6, -0.45))
	for _, sx in { -1, 1 } do
		add(
			list,
			"SignEar",
			"Wedge",
			v(0.6, 1.6, 1.8),
			PINK,
			"SmoothPlastic",
			P(sx * 3.6, HEADER_TOP + 5.4, 0),
			{ rotation = v(0, 90, 0) }
		)
	end

	-- 흰 고양이 인형 (높이 약 10: 상품 바닥 10.5 → 귀 끝 약 20)
	local base = CASE_BOTTOM + 0.3
	add(list, "CatBody", "Ball", v(7.4, 6, 6.6), CAT, "SmoothPlastic", P(0, base + 2.8, 0.4))
	add(list, "CatHead", "Ball", v(7.6, 6.4, 6.4), CAT, "SmoothPlastic", P(0, base + 6.4, 0.6))
	for _, sx in { -1, 1 } do
		add(
			list,
			"CatEar",
			"Wedge",
			v(0.9, 2, 1.8),
			CAT,
			"SmoothPlastic",
			P(sx * 2.2, base + 9.6, 0.6),
			{ rotation = v(0, 90, sx * 12) }
		)
		add(
			list,
			"CatEarInner",
			"Wedge",
			v(0.3, 1.2, 1.1),
			c(255, 190, 206),
			"SmoothPlastic",
			P(sx * 2.2, base + 9.4, 1.0),
			{ rotation = v(0, 90, sx * 12) }
		)
		add(list, "CatEye", "Ball", v(0.7, 1, 0.5), c(40, 36, 44), "SmoothPlastic", P(sx * 1.5, base + 6.8, 3.6))
		add(list, "CatBlush", "Ball", v(1.2, 0.6, 0.3), c(255, 170, 190), "SmoothPlastic", P(sx * 2.4, base + 5.8, 3.4))
		add(list, "CatPaw", "Ball", v(1.8, 1.4, 1.8), CAT_SHADE, "SmoothPlastic", P(sx * 1.8, base + 0.8, 3.4))
		add(
			list,
			"CatWhisker",
			"Block",
			v(1.6, 0.1, 0.1),
			c(170, 170, 176),
			"SmoothPlastic",
			P(sx * 3.2, base + 6.1, 3.3),
			{ rotation = v(0, 0, sx * 8) }
		)
	end
	add(list, "CatNose", "Ball", v(0.5, 0.4, 0.4), c(255, 140, 160), "SmoothPlastic", P(0, base + 6.1, 3.8))
	addAll(
		list,
		MapKitShapes.capsule("CatTail", 4.6, 1.2, CAT_SHADE, "SmoothPlastic", P(3.3, base + 2.4, -1.6), v(0, 30, 50))
	)
	add(list, "CatBell", "Ball", v(1, 1, 1), GOLD, "Metal", P(0, base + 3.7, 3.7), { reflectance = 0.3 })
	add(
		list,
		"CatCollar",
		"Cylinder",
		v(0.5, 5.6, 5.6),
		c(232, 70, 100),
		"SmoothPlastic",
		P(0, base + 3.9, 0.6),
		{ rotation = UPRIGHT }
	)

	-- 섬: 기계 둘레 바위 (물속, 4단 윗면보다 낮게)
	for i = 0, 7 do
		local a = i * 45 + 20
		local rx, rz = pol(a, 8.2)
		local s = 3 + (i % 3) * 0.8
		add(
			list,
			"IslandRock",
			"Ball",
			v(s * 1.3, s, s),
			if i % 2 == 0 then ROCK else ROCK_MOSS,
			"Rock",
			P(rx, -4.5 + (i % 3) * 0.6, rz)
		)
	end
end

-- 탕 둘레: 돌벽 고리 + 큰 바위 무리 (충돌 없음, 1단 바깥 물 띠 너머)
local function poolRim(list: { DecorSpec })
	local R = Layout.POOL_RADIUS
	addAll(list, MapKitShapes.ring("PoolWall", R + 1, 2, 18, 24, ROCK_DARK, "Slate", P(0, -1, 0)))
	-- 큰 바위 고리: 크기·높이·색 3변형, 조금씩 기울여요
	local rng = MapKitShapes.rng(39)
	for i = 0, 31 do
		local a = i * (360 / 32) + rng:range(-3, 3)
		local r = R + 3.2 + rng:range(-0.6, 1.4)
		local rx, rz = pol(a, r)
		local s = rng:range(6, 10)
		local tint = ({ ROCK, ROCK_DARK, ROCK_MOSS, ROCK_LIGHT })[i % 4 + 1]
		add(
			list,
			"RimRock",
			"Ball",
			v(s * 1.4, s, s * 1.1),
			tint,
			"Rock",
			P(rx, Art.GROUND_Y - 1.5 + rng:range(-1, 1.5), rz),
			{
				rotation = v(rng:range(-10, 10), a, rng:range(-8, 8)),
			}
		)
		if i % 3 == 0 then
			local mx, mz = pol(a + 4, r + 4)
			add(
				list,
				"RimRock",
				"Ball",
				v(s, s * 0.8, s * 0.9),
				shade(tint, 0.85),
				"Rock",
				P(mx, Art.GROUND_Y + 1, mz),
				{ rotation = v(0, a, 6) }
			)
		end
	end
	-- 물속 바위 (물 띠 바닥, 물이 차오르기 전엔 보여요)
	for i = 0, 11 do
		local a = i * 30 + 12
		local rx, rz = pol(a, R - 3)
		add(list, "UnderRock", "Ball", v(5, 3.5, 4.4), ROCK_DARK, "Rock", P(rx, -5.5, rz), { rotation = v(0, a, 0) })
	end
	-- 탕 바닥 돌판 (안전망보다 10 이상 아래)
	add(
		list,
		"PoolFloor",
		"Cylinder",
		v(2, 2 * R + 6, 2 * R + 6),
		c(40, 64, 70),
		"Slate",
		P(0, Art.POOL_FLOOR_Y - 1, 0),
		{ rotation = UPRIGHT }
	)
end

-- 마당 돌바닥 (윗면 8): 탕을 둘러싼 정사각 구멍 + 귀퉁이 메움 + 먼 자갈
local function ground(list: { DecorSpec })
	local y = Art.GROUND_Y
	local hole = 58
	local far = 460
	local thick = 50
	local pave = { STONE_PAVE, shade(STONE_PAVE, 0.9), shade(STONE_PAVE, 1.08) }
	-- 북·남·서·동 판
	add(list, "Ground", "Block", v(2 * far, thick, far - hole), GRAVEL, "Slate", P(0, y - thick / 2, -(hole + far) / 2))
	add(list, "Ground", "Block", v(2 * far, thick, far - hole), GRAVEL, "Slate", P(0, y - thick / 2, (hole + far) / 2))
	add(
		list,
		"Ground",
		"Block",
		v(far - hole, thick, 2 * hole),
		GRAVEL,
		"Slate",
		P(-(hole + far) / 2, y - thick / 2, 0)
	)
	add(list, "Ground", "Block", v(far - hole, thick, 2 * hole), GRAVEL, "Slate", P((hole + far) / 2, y - thick / 2, 0))
	-- 귀퉁이 메움 (45° 돌린 판, 바위 무리가 덮어요)
	for i = 0, 3 do
		local a = 45 + i * 90
		local gx, gz = pol(a, 74)
		add(
			list,
			"GroundCorner",
			"Block",
			v(30, 4, 30),
			shade(GRAVEL, 0.95),
			"Slate",
			P(gx, y - 2.05, gz),
			{ rotation = v(0, a, 0) }
		)
	end
	-- 탕 둘레 디딤돌 길 (돌판 shade 3가지)
	local rng = MapKitShapes.rng(7)
	for i = 0, 35 do
		local a = i * 10 + rng:range(-2, 2)
		local r = 66 + rng:range(-1.5, 1.5)
		local sx, sz = pol(a, r)
		add(
			list,
			"PavingStone",
			"Block",
			v(9 + rng:range(-1, 2), 0.6, 7 + rng:range(-1, 1.5)),
			pave[i % 3 + 1],
			"Slate",
			P(sx, y + 0.2, sz),
			{
				rotation = v(0, a + rng:range(-8, 8), 0),
			}
		)
	end
end

-- 종이등 기둥 (andon): 나무 기둥 + 종이 상자 + 지붕. light는 종이에
local function andon(list: { DecorSpec }, x: number, z: number, lit: boolean, sparkle: boolean)
	local y = Art.GROUND_Y
	post(list, "AndonPost", x, y, z, 16, 1, WOOD_DARK, "Wood")
	add(list, "AndonBase", "Block", v(3.4, 0.8, 3.4), WOOD_DARK, "Wood", P(x, y + 0.4, z))
	add(list, "AndonPaper", "Block", v(3.8, 5.4, 3.8), c(250, 176, 104), "Neon", P(x, y + 19, z), {
		light = if lit then { kind = "Point", color = c(255, 176, 96), brightness = 1.6, range = 34 } else nil,
		particle = if lit and sparkle then "Sparkle" else nil,
		particleRate = if lit and sparkle then 0.6 else nil,
	})
	-- 종이등 나무 살 (불빛을 격자로 나눠요)
	for _, fx in { -1, 1 } do
		for _, fz in { -1, 1 } do
			add(
				list,
				"AndonLattice",
				"Block",
				v(0.45, 5.8, 0.45),
				WOOD_DARK,
				"Wood",
				P(x + fx * 1.95, y + 19, z + fz * 1.95)
			)
		end
	end
	add(list, "AndonLattice", "Block", v(4.1, 0.3, 4.1), WOOD_DARK, "Wood", P(x, y + 21.7, z))
	addAll(list, MapKitShapes.lipTrim("AndonFrame", v(4.4, 0, 4.4), 0.35, 0.5, WOOD_DARK, "Wood", P(x, y + 16.2, z)))
	add(list, "AndonRoof", "Block", v(5.6, 0.7, 5.6), ROOF, "Slate", P(x, y + 22.4, z))
	add(list, "AndonRoofTop", "Ball", v(1.2, 1.2, 1.2), ROOF, "Slate", P(x, y + 23.2, z))
end

-- 나무통 (hinoki oke, 지름 12): 원통 + 테 두 줄 + 손잡이 귀
local function bucket(
	list: { DecorSpec },
	x: number,
	z: number,
	d: number,
	h: number,
	yaw: number,
	tilt: number,
	tint: number
)
	local y = Art.GROUND_Y
	local col = shade(HINOKI, tint)
	add(list, "Bucket", "Cylinder", v(h, d, d), col, "Wood", P(x, y + h / 2, z), { rotation = v(tilt, yaw, 90) })
	for _, fy in { 0.22, 0.78 } do
		add(list, "BucketHoop", "Cylinder", v(0.45, d + 0.3, d + 0.3), c(176, 150, 96), "Metal", P(x, y + h * fy, z), {
			rotation = v(tilt, yaw, 90),
			reflectance = 0.2,
		})
	end
	add(list, "BucketWater", "Cylinder", v(0.2, d - 0.9, d - 0.9), Art.COLORS.water, "Glass", P(x, y + h - 0.6, z), {
		rotation = v(tilt, yaw, 90),
		transparency = 0.2,
		reflectance = 0.15,
	})
end

-- 목욕 의자 (나무, 폭 18·높이 10)
local function stool(list: { DecorSpec }, x: number, z: number, yaw: number)
	local y = Art.GROUND_Y
	addAll(
		list,
		MapKitShapes.bevelBox("StoolSeat", v(18, 1.4, 10), HINOKI, "Wood", P(x, y + 9.3, z), 0.5, v(0, yaw, 0))
	)
	for _, sx in { -1, 1 } do
		local lx, lz = pol(-yaw, sx * 7.4)
		add(
			list,
			"StoolLeg",
			"Block",
			v(1.2, 8.6, 9),
			shade(HINOKI, 0.85),
			"Wood",
			P(x + lx, y + 4.3, z + lz),
			{ rotation = v(0, yaw, 0) }
		)
	end
end

-- 수건 탑 (접은 수건 3색 쌓기, 조금씩 어긋나게)
local function towels(list: { DecorSpec }, x: number, z: number)
	local y = Art.GROUND_Y
	local cols = { TOWEL_A, TOWEL_B, TOWEL_C, TOWEL_A, TOWEL_B }
	for i, col in cols do
		addAll(
			list,
			MapKitShapes.roundedBox(
				"Towel",
				v(11, 2.2, 7),
				col,
				"Fabric",
				P(x + (i % 2) * 0.6, y + 1.1 + (i - 1) * 2.15, z - (i % 3) * 0.4),
				{
					radius = 0.9,
					style = "vertical",
					rotation = v(0, (i - 3) * 4, 0),
				}
			)
		)
	end
end

-- 대나무 국자 (손잡이 캡슐 + 컵)
local function ladle(list: { DecorSpec }, x: number, y: number, z: number, yaw: number)
	addAll(list, MapKitShapes.capsule("LadleHandle", 18, 0.8, BAMBOO, "Wood", P(x, y, z), v(0, yaw, 14)))
	local hx, hz = pol(-yaw, 9)
	add(
		list,
		"LadleCup",
		"Cylinder",
		v(3, 3.2, 3.2),
		shade(BAMBOO, 0.9),
		"Wood",
		P(x + hx, y + 1.2, z + hz),
		{ rotation = UPRIGHT }
	)
end

-- 샴푸병 (분홍·흰)
local function bottle(list: { DecorSpec }, x: number, z: number, h: number, col: RGB)
	local y = Art.GROUND_Y
	addAll(
		list,
		MapKitShapes.roundedBox(
			"Bottle",
			v(4, h, 3),
			col,
			"SmoothPlastic",
			P(x, y + h / 2, z),
			{ radius = 1, style = "vertical" }
		),
		{ reflectance = 0.1 }
	)
	add(
		list,
		"BottlePump",
		"Cylinder",
		v(2.2, 1, 1),
		c(240, 240, 244),
		"SmoothPlastic",
		P(x, y + h + 1.1, z),
		{ rotation = UPRIGHT }
	)
	add(list, "BottleNozzle", "Block", v(2, 0.5, 0.6), c(240, 240, 244), "SmoothPlastic", P(x + 0.8, y + h + 2.1, z))
end

-- 소품 무리 (가장자리 MG): 탕 둘레 땅 위, 고르게 흩뿌리지 않고 무리로
local function props(list: { DecorSpec })
	-- 남동 무리: 나무통 3 + 의자 + 국자 (출발 자리 뒤쪽에서 보이는 큰 무리)
	bucket(list, 50, 50, 12, 9, 0, 0, 1)
	bucket(list, 62, 42, 10, 8, 20, 0, 0.92)
	bucket(list, 58, 56, 9, 7, 40, 0, 1.06)
	stool(list, 70, 58, 30)
	ladle(list, 46, Art.GROUND_Y + 0.6, 60, 120)
	-- 남서 무리: 수건 탑 + 샴푸병 2 + 작은 통
	towels(list, -58, 48)
	bottle(list, -46, 56, 9, PINK_LIGHT)
	bottle(list, -42, 52, 7, c(244, 244, 246))
	bucket(list, -68, 38, 8, 6, 0, 0, 0.96)
	-- 북서 무리 (여관 쪽): 의자 + 통 + 국자 걸이
	stool(list, -62, -52, -20)
	bucket(list, -50, -60, 12, 9, 0, 0, 1.04)
	ladle(list, -44, Art.GROUND_Y + 0.6, -50, 30)
	-- 북동 무리: 수건 + 병
	towels(list, 56, -56)
	bottle(list, 46, -62, 8, c(170, 220, 230))
end

-- 물 위 초밥 쟁반이 떠 있는 돌 수반 (탕 바깥 남쪽, 정적인 물 — 쟁반은 Bob)
local function trayBasin(list: { DecorSpec })
	local y = Art.GROUND_Y
	local bx, bz = 0, 86
	local w, d = 70, 22
	addAll(list, MapKitShapes.lipTrim("BasinRim", v(w, 0, d), 2.4, 2.4, shade(ROCK, 1.1), "Slate", P(bx, y + 0.6, bz)))
	add(
		list,
		"BasinWater",
		"Block",
		v(w, 0.4, d),
		Art.COLORS.water,
		"Glass",
		P(bx, y - 0.2, bz),
		{ transparency = 0.15, reflectance = 0.15, particle = "Steam", particleRate = 1.2 }
	)
	add(list, "BasinBed", "Block", v(w, 1, d), Art.COLORS.waterDeep, "Slate", P(bx, y - 2, bz))
	-- 초밥 쟁반 3개 (나무 게타 + 초밥 2~3점), 위아래로 둥실
	for i, tray in
		{
			{ x = -20, z = 0, yaw = 12, period = 4.2 },
			{ x = 4, z = 3, yaw = -8, period = 5 },
			{ x = 24, z = -2, yaw = 20, period = 4.6 },
		}
	do
		local tx, tz = bx + tray.x, bz + tray.z
		local bob = { kind = "Bob", period = tray.period, amount = 0.35 } :: AnimSpec
		add(
			list,
			"SushiTray",
			"Block",
			v(14, 1.2, 7),
			c(176, 112, 64),
			"Wood",
			P(tx, y + 0.5, tz),
			{ rotation = v(0, tray.yaw, 0), anim = bob }
		)
		local toppings = { PAL.Salmon, PAL.Tuna, PAL.Egg }
		for j = -1, 1 do
			local ox, oz = pol(-tray.yaw, j * 4)
			add(
				list,
				"TrayRice",
				"Block",
				v(3.4, 1.8, 2.6),
				PAL.Rice,
				"SmoothPlastic",
				P(tx + ox, y + 2, tz + oz),
				{ rotation = v(0, tray.yaw, 0), anim = bob }
			)
			add(
				list,
				"TrayTopping",
				"Block",
				v(3.8, 0.7, 2.9),
				toppings[(i + j) % 3 + 1],
				"SmoothPlastic",
				P(tx + ox, y + 3.2, tz + oz),
				{
					rotation = v(0, tray.yaw, 0),
					anim = bob,
				}
			)
		end
	end
	-- 떠 있는 작은 나무통 (Bob)
	add(list, "FloatBucket", "Cylinder", v(5, 8, 8), HINOKI, "Wood", P(bx - 30, y + 1.5, bz + 3), {
		rotation = UPRIGHT,
		anim = { kind = "Bob", period = 3.8, amount = 0.3 },
	})
end

-- 램프 걸이: 탕을 가로지르는 나무 보 두 기둥 + 매달린 램프 (그림자 SpotLight로 기계·4단을 비춤)
local function lampGantry(list: { DecorSpec })
	local top = 78
	for _, sx in { -1, 1 } do
		post(list, "GantryPost", sx * 66, Art.GROUND_Y, -6, top - Art.GROUND_Y, 3, WOOD_DARK, "Wood")
		add(list, "GantryFoot", "Block", v(6, 2, 6), ROCK_DARK, "Slate", P(sx * 66, Art.GROUND_Y + 1, -6))
	end
	addAll(list, MapKitShapes.bevelBox("GantryBeam", v(140, 3, 3.4), WOOD_DARK, "Wood", P(0, top + 1.5, -6), 0.6))
	-- 램프: 보 → 줄 → 갓 (기계 바로 위)
	post(list, "LampCord", 0, 52, -6, top - 52, 0.25, c(40, 36, 34), "Fabric")
	add(
		list,
		"LampShade",
		"Cylinder",
		v(3, 8, 8),
		c(60, 52, 48),
		"Metal",
		P(0, 51, -6),
		{ rotation = UPRIGHT, reflectance = 0.15 }
	)
	add(list, "LampBulb", "Ball", v(3, 3, 3), PAPER, "Neon", P(0, 49.4, -6), {
		light = {
			kind = "Spot",
			color = c(255, 214, 160),
			brightness = 2.4,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
end

-- 여관 (북쪽 BG): 목조 벽·장지창(따뜻한 빛)·툇마루·처마·기와 지붕·노렌·처마 등·♨ 네온·"온천" 종이 간판
-- 마당 채우기 (탕과 울타리 사이 빈 자갈밭이 안 보이게): 다듬은 소나무 2, 철쭉 덤불 무리, 여관 가는 디딤돌 길,
-- 바깥 종이등 고리, 나무 평상
local function garden(list: { DecorSpec })
	local y = Art.GROUND_Y
	local pine = c(52, 86, 58)
	-- 다듬은 소나무 (줄기 기울기 + 구름 모양 잎 덩어리)
	for i, spot in { { x = -150, z = -64, lean = 10 }, { x = 132, z = -44, lean = -8 } } do
		post(list, "PineTrunk", spot.x, y, spot.z, 90, 9, c(88, 64, 50), "Wood")
		addAll(
			list,
			MapKitShapes.capsule(
				"PineBranch",
				50,
				5,
				c(88, 64, 50),
				"Wood",
				P(spot.x + spot.lean * 2, y + 74, spot.z),
				v(0, i * 40, spot.lean)
			)
		)
		for k, cloud in
			{
				{ 0, 98, 0, 74 },
				{ 34, 84, 10, 56 },
				{ -36, 78, -8, 52 },
				{ 8, 116, -6, 50 },
				{ -14, 92, 26, 44 },
			}
		do
			-- 납작한 잎 판 (원기둥) + 위 둥근 혹 — Ball은 가장 짧은 변 지름이라 납작한 공을 못 만들어요
			local col = shade(pine, 0.9 + k * 0.06)
			local px, py, pz = spot.x + cloud[1], y + cloud[2], spot.z + cloud[3]
			add(list, "PineCloud", "Cylinder", v(cloud[4] * 0.3, cloud[4], cloud[4]), col, "Grass", P(px, py, pz), {
				rotation = UPRIGHT,
				castShadow = false,
			})
			add(
				list,
				"PineCloud",
				"Ball",
				v(cloud[4] * 0.55, cloud[4] * 0.55, cloud[4] * 0.55),
				shade(col, 1.08),
				"Grass",
				P(px, py + cloud[4] * 0.12, pz),
				{
					castShadow = false,
				}
			)
		end
	end
	-- 철쭉 덤불 무리 (분홍 꽃점 조금)
	local rng = MapKitShapes.rng(17)
	for _, cl in { { x = -150, z = -110 }, { x = 116, z = 112 }, { x = -96, z = 150 }, { x = 110, z = 150 } } do
		for k = 1, 5 do
			local sz = rng:range(14, 24)
			add(
				list,
				"Shrub",
				"Ball",
				v(sz * 1.2, sz * 0.8, sz),
				shade(c(62, 104, 66), rng:range(0.85, 1.1)),
				"Grass",
				P(cl.x + rng:range(-18, 18), y + sz * 0.3, cl.z + rng:range(-14, 14)),
				{
					castShadow = false,
				}
			)
			if k % 2 == 0 then
				add(
					list,
					"ShrubFlower",
					"Ball",
					v(4, 3, 4),
					c(236, 130, 170),
					"SmoothPlastic",
					P(cl.x + rng:range(-12, 12), y + sz * 0.62, cl.z + rng:range(-8, 8))
				)
			end
		end
	end
	-- 디딤돌 길 (탕 북쪽 → 여관 입구)
	for k = 0, 6 do
		local zz = -80 - k * 9.5
		add(
			list,
			"PathStone",
			"Block",
			v(12 + (k % 2) * 2, 0.8, 7),
			({ STONE_PAVE, shade(STONE_PAVE, 1.1), shade(STONE_PAVE, 0.92) })[k % 3 + 1],
			"Slate",
			P((k % 2) * 3 - 1.5, y + 0.3, zz),
			{
				rotation = v(0, (k % 3 - 1) * 6, 0),
			}
		)
	end
	-- 바깥 종이등 고리 (빛 2개)
	for i, a in { 60, 120, 200, 250, 290, 340 } do
		local x, z = pol(a, 128)
		andon(list, x, z, i == 2 or i == 5, false)
	end
	-- 나무 평상 (서쪽, 실제 크기 — 작은 초밥 눈엔 거대한 가구)
	addAll(list, MapKitShapes.bevelBox("Bench", v(46, 4, 120), WOOD_MID, "WoodPlanks", P(170, y + 40, 20), 1))
	for _, bz in { -54, 54 } do
		for _, bx in { -19, 19 } do
			add(list, "BenchLeg", "Block", v(4, 38, 4), WOOD_DARK, "Wood", P(170 + bx, y + 19, 20 + bz))
		end
	end
	add(list, "BenchTowel", "Block", v(30, 2, 24), TOWEL_B, "Fabric", P(170, y + 43, 50), { rotation = v(0, 8, 0) })
end

local function inn(list: { DecorSpec })
	local zf = -150 -- 정면 벽 z
	local y = Art.GROUND_Y
	local wallH = 240
	-- 벽 (회벽 + 나무 기둥)
	add(list, "InnWall", "Block", v(420, wallH, 6), PLASTER, "Plaster", P(0, y + wallH / 2, zf - 3))
	add(list, "InnWallBase", "Block", v(424, 40, 8), WOOD_DARK, "WoodPlanks", P(0, y + 20, zf - 2))
	for i = -5, 5 do
		add(list, "InnPillar", "Block", v(7, wallH, 7), WOOD_MID, "Wood", P(i * 40, y + wallH / 2, zf + 1))
	end
	add(list, "InnBeam", "Block", v(424, 8, 8), WOOD_MID, "Wood", P(0, y + 130, zf + 1))
	-- 장지창 (아래층 따뜻한 빛, 위층 어두운 것 섞어서)
	for i = -4, 4 do
		if i == 0 then
			continue
		end
		local lit = i % 2 ~= 0 or math.abs(i) == 4
		local x = i * 40 + 20 * (if i > 0 then -1 else 1)
		local lowColor = if lit then c(228, 150, 84) else shade(PAPER, 0.5)
		add(
			list,
			"ShojiLow",
			"Block",
			v(30, 60, 1),
			lowColor,
			if lit then "Neon" else "SmoothPlastic",
			P(x, y + 80, zf + 0.6),
			{
				light = if lit and math.abs(i) == 1
					then { kind = "Surface", color = c(255, 180, 110), brightness = 2, range = 16, face = "Back" }
					else nil,
			}
		)
		-- 장지 살: 가로 3줄 + 세로 3줄
		for _, my in { -15, 0, 15 } do
			add(list, "ShojiMullion", "Block", v(30, 1.1, 1.4), WOOD_DARK, "Wood", P(x, y + 80 + my, zf + 1))
		end
		for _, mx in { -7.5, 0, 7.5 } do
			add(list, "ShojiMullion", "Block", v(1.1, 60, 1.4), WOOD_DARK, "Wood", P(x + mx, y + 80, zf + 1))
		end
		local highLit = i % 3 == 0
		local highColor = if highLit then c(214, 140, 80) else shade(PAPER, 0.42)
		add(
			list,
			"ShojiHigh",
			"Block",
			v(26, 40, 1),
			highColor,
			if highLit then "Neon" else "SmoothPlastic",
			P(x, y + 180, zf + 0.6)
		)
		add(list, "ShojiMullion", "Block", v(1.1, 40, 1.4), WOOD_DARK, "Wood", P(x, y + 180, zf + 1))
	end
	-- 입구 (가운데): 어두운 문 + 노렌 3장 (Sway)
	add(list, "InnDoor", "Block", v(44, 90, 1), c(40, 30, 26), "Wood", P(0, y + 45, zf + 0.6))
	for k = -1, 1 do
		add(list, "Noren", "Block", v(13.6, 34, 0.6), NOREN, "Fabric", P(k * 14.2, y + 72, zf + 6), {
			anim = { kind = "Sway", period = 4.8 + k * 0.4, amount = 4, axis = "X" },
		})
	end
	add(list, "NorenRod", "Cylinder", v(48, 1.4, 1.4), WOOD_DARK, "Wood", P(0, y + 89.5, zf + 6))
	add(list, "NorenMark", "Ball", v(7, 7, 0.4), c(250, 250, 250), "Fabric", P(0, y + 70, zf + 6.4))
	-- 툇마루 (나무, 땅 위 40) + 디딤돌
	add(list, "Engawa", "Block", v(400, 4, 28), WOOD_MID, "WoodPlanks", P(0, y + 38, zf + 16))
	add(list, "EngawaEdge", "Block", v(402, 3, 3), WOOD_DARK, "Wood", P(0, y + 37.5, zf + 30))
	for i = -9, 9 do
		add(list, "EngawaPost", "Block", v(4, 36, 4), WOOD_DARK, "Wood", P(i * 22, y + 18, zf + 28))
	end
	add(list, "StepStone", "Block", v(30, 14, 14), shade(ROCK, 1.15), "Slate", P(0, y + 7, zf + 38))
	-- 처마 + 기와 지붕 (경사 쐐기)
	add(list, "Eave", "Block", v(440, 6, 60), ROOF, "Slate", P(0, y + 246, zf + 14))
	add(list, "EaveFascia", "Block", v(442, 8, 3), WOOD_DARK, "Wood", P(0, y + 243, zf + 44))
	add(
		list,
		"Roof",
		"Wedge",
		v(440, 70, 90),
		ROOF,
		"ClayRoofTiles",
		P(0, y + 284, zf - 30),
		{ rotation = v(0, 180, 0) }
	)
	-- 처마 종이등 (빨강·주황 초롱, Sway) — 4개, 빛 2개 + 입구 그림자 Spot 1
	for i, x in { -120, -40, 40, 120 } do
		local lantern = if i % 2 == 0 then LANTERN_RED else c(255, 176, 90)
		local yy = y + 214
		add(list, "EaveLanternCord", "Block", v(0.6, 22, 0.6), c(40, 34, 30), "Fabric", P(x, yy + 18, zf + 40))
		add(list, "EaveLantern", "Ball", v(14, 20, 14), lantern, "Neon", P(x, yy, zf + 40), {
			light = if i == 2 or i == 3
				then { kind = "Point", color = c(255, 150, 80), brightness = 2, range = 60 }
				else nil,
			anim = { kind = "Sway", period = 5 + i * 0.4, amount = 3, axis = "X" },
		})
		add(
			list,
			"EaveLanternCap",
			"Cylinder",
			v(2, 8, 8),
			c(30, 28, 28),
			"Wood",
			P(x, yy + 10.5, zf + 40),
			{ rotation = UPRIGHT }
		)
		add(
			list,
			"EaveLanternCap",
			"Cylinder",
			v(2, 8, 8),
			c(30, 28, 28),
			"Wood",
			P(x, yy - 10.5, zf + 40),
			{ rotation = UPRIGHT }
		)
	end
	-- 입구 처마 아래 그림자 등 (노렌·디딤돌에 그림자)
	add(list, "EntranceLamp", "Cylinder", v(4, 10, 10), PAPER, "Neon", P(0, y + 120, zf + 26), {
		rotation = UPRIGHT,
		light = {
			kind = "Spot",
			color = c(255, 196, 130),
			brightness = 3,
			range = 60,
			angle = 80,
			face = "Left",
			shadows = true,
		},
	})
	-- ♨ 네온 간판 (분홍빛 Pulse): 그릇(반 고리) + 김 세 줄
	local sx, sy, sz = 84, y + 84, zf + 3
	add(list, "OnsenBoard", "Block", v(70, 70, 3), c(36, 30, 44), "Wood", P(sx, sy, sz))
	boardFrame(list, "OnsenBoardFrame", 70, 70, 4, 2.4, WOOD_MID, "Wood", P(sx, sy, sz))
	local neon = c(255, 110, 150)
	local pulse = { kind = "Pulse", period = 2.6, amount = 0.06 } :: AnimSpec
	for i = 0, 6 do
		local a = 200 + i * 23.3
		local ux, uy = math.cos(math.rad(a)), math.sin(math.rad(a))
		add(list, "OnsenNeon", "Block", v(9, 2.6, 1.2), neon, "Neon", P(sx + ux * 22, sy - 8 + uy * 14, sz + 2.2), {
			rotation = v(0, 0, a + 90),
			anim = pulse,
			light = if i == 3 then { kind = "Point", color = neon, brightness = 1.6, range = 40 } else nil,
		})
	end
	for k = -1, 1 do
		for j = 0, 2 do
			add(
				list,
				"OnsenNeon",
				"Block",
				v(2.6, 9, 1.2),
				neon,
				"Neon",
				P(sx + k * 13 + (if j == 1 then 3 else -1), sy + 2 + j * 8, sz + 2.2),
				{
					rotation = v(0, 0, if j == 1 then -22 else 22),
					anim = pulse,
				}
			)
		end
	end
	-- "온천" 종이 간판 (세로 초롱 모양, 입구 왼쪽)
	add(list, "OnsenLanternSign", "Block", v(30, 80, 4), c(250, 226, 190), "Neon", P(-84, y + 84, zf + 4))
	add(list, "OnsenSignChar", "Block", v(16, 22, 1), LANTERN_RED, "SmoothPlastic", P(-84, y + 100, zf + 6.4))
	add(list, "OnsenSignChar", "Block", v(16, 22, 1), LANTERN_RED, "SmoothPlastic", P(-84, y + 70, zf + 6.4))
	boardFrame(list, "OnsenSignFrame", 30, 80, 5, 2.4, WOOD_DARK, "Wood", P(-84, y + 84, zf + 4))
end

-- 대나무 울타리 (서·동·남, 높이 180) + 뒤 대나무 숲 + 석등
local function fenceAndGrove(list: { DecorSpec })
	local y = Art.GROUND_Y
	local h = 130
	local dist = 200
	-- 울타리 판 3면 (판 + 가로 대 + 세로 대나무)
	local sides = {
		{ x = -dist, z = 0, yaw = 90, len = 2 * dist },
		{ x = dist, z = 0, yaw = 90, len = 2 * dist },
		{ x = 0, z = dist, yaw = 0, len = 2 * dist },
	}
	for si, side in sides do
		local col = if si % 2 == 0 then BAMBOO_FENCE else shade(BAMBOO_FENCE, 0.92)
		add(
			list,
			"FencePanel",
			"Block",
			v(side.len, h, 3),
			col,
			"WoodPlanks",
			P(side.x, y + h / 2, side.z),
			{ rotation = v(0, side.yaw, 0) }
		)
		for _, fy in { 0.3, 0.75 } do
			add(
				list,
				"FenceRail",
				"Cylinder",
				v(side.len, 3.2, 3.2),
				BAMBOO_DARK,
				"Wood",
				P(
					side.x + (if side.yaw == 90 then (if side.x < 0 then 2.5 else -2.5) else 0),
					y + h * fy,
					side.z + (if side.yaw == 0 then -2.5 else 0)
				),
				{
					rotation = v(0, side.yaw, 0),
				}
			)
		end
		for k = -10, 10 do
			local along = k * 20
			local px = side.x + (if side.yaw == 90 then 0 else along)
			local pz = side.z + (if side.yaw == 90 then along else 0)
			post(list, "FencePole", px, y, pz, h + 12, 5, if k % 2 == 0 then BAMBOO else BAMBOO_DARK, "Wood")
		end
	end
	-- 대나무 숲 (울타리 뒤 실루엣, 키 큰 줄기 + 잎 덩어리)
	local rng = MapKitShapes.rng(91)
	for i = 1, 24 do
		local side = sides[(i - 1) % 3 + 1]
		local along = rng:range(-190, 190)
		local back = rng:range(30, 90)
		local px = if side.yaw == 90 then side.x + (if side.x < 0 then -back else back) else along
		local pz = if side.yaw == 90 then along else side.z + back
		local hh = rng:range(260, 380)
		post(list, "BambooStalk", px, y, pz, hh, rng:range(5, 8), if i % 2 == 0 then BAMBOO else BAMBOO_DARK, "Wood")
		add(
			list,
			"BambooLeaves",
			"Ball",
			v(60, 46, 60),
			shade(c(70, 104, 62), rng:range(0.85, 1.1)),
			"Grass",
			P(px, y + hh - 10, pz),
			{
				castShadow = false,
				particle = if i == 5 then "Sparkle" else nil,
				particleRate = if i == 5 then 1.5 else nil,
			}
		)
	end
	-- 석등 (북동·북서, 키 150, 불 켜진 창)
	for _, sx in { -1, 1 } do
		local x, z = sx * 108, -104
		add(list, "ToroBase", "Block", v(30, 10, 30), shade(ROCK, 1.2), "Slate", P(x, y + 5, z))
		post(list, "ToroPillar", x, y + 10, z, 70, 14, shade(ROCK, 1.25), "Slate")
		add(list, "ToroFirebox", "Block", v(26, 26, 26), shade(ROCK, 1.2), "Slate", P(x, y + 93, z))
		add(list, "ToroWindow", "Block", v(14, 14, 27), PAPER, "Neon", P(x, y + 93, z), {
			light = if sx > 0 then { kind = "Point", color = c(255, 170, 90), brightness = 1.6, range = 50 } else nil,
		})
		add(
			list,
			"ToroRoof",
			"Block",
			v(46, 8, 46),
			shade(ROCK, 1.05),
			"Slate",
			P(x, y + 110, z),
			{ rotation = v(0, 45, 0) }
		)
		add(list, "ToroCap", "Ball", v(14, 14, 14), shade(ROCK, 1.05), "Slate", P(x, y + 120, z))
	end
end

-- 탕 위·가장자리의 김 (화면을 가리지 않게 가장자리에서 낮은 Rate)
local function steam(list: { DecorSpec })
	for i, a in { 20, 110, 200, 290 } do
		local sx, sz = pol(a, Layout.POOL_RADIUS - 2)
		add(list, "SteamVent", "Block", v(6, 0.4, 6), ROCK_DARK, "Rock", P(sx, Art.GROUND_Y - 2, sz), {
			transparency = 1,
			particle = if i % 2 == 0 then "SteamThick" else "Steam",
			particleRate = if i % 2 == 0 then 1.4 else 2.4,
		})
	end
end

-- 작은 온천 디테일: 대나무 물대롱(가케히) + 떨어지는 물줄기·김, 바위 위 고무 오리, 램프 보에 매단 초롱 2개
local function details(list: { DecorSpec })
	local y = Art.GROUND_Y
	-- 가케히 (북동, 탕 가장자리 바위 위에서 탕 쪽으로)
	local kx, kz = pol(52, 60)
	local ix, iz = pol(52, 49)
	post(list, "KakehiPost", kx, y, kz, 16, 2.4, BAMBOO_DARK, "Wood")
	local yaw = -52 + 180
	addAll(
		list,
		MapKitShapes.capsule(
			"KakehiPipe",
			14,
			1.8,
			BAMBOO,
			"Wood",
			P((kx + ix) / 2, y + 15, (kz + iz) / 2),
			v(0, yaw, -8)
		)
	)
	add(list, "KakehiStream", "Block", v(0.8, 15, 0.8), c(170, 236, 232), "Glass", P(ix, y + 6, iz), {
		transparency = 0.35,
		reflectance = 0.2,
		particle = "Steam",
		particleRate = 1.6,
	})
	-- 고무 오리 (남동 바위 위, 노랑 — 위험 색 아님)
	local dx, dz = pol(300, 57)
	add(list, "DuckBody", "Ball", v(5, 4, 6), c(255, 214, 70), "SmoothPlastic", P(dx, y + 4.4, dz))
	add(list, "DuckHead", "Ball", v(3.4, 3.4, 3.4), c(255, 214, 70), "SmoothPlastic", P(dx, y + 7.4, dz + 1.6))
	add(list, "DuckBeak", "Block", v(1.6, 0.6, 1.4), c(255, 150, 50), "SmoothPlastic", P(dx, y + 7.1, dz + 3.4))
	for _, sx in { -1, 1 } do
		add(
			list,
			"DuckEye",
			"Ball",
			v(0.5, 0.6, 0.4),
			c(30, 30, 34),
			"SmoothPlastic",
			P(dx + sx * 0.9, y + 7.9, dz + 3)
		)
	end
	-- 램프 보에 매단 초롱 (Sway, 빛 1개)
	for i, x in { -36, 36 } do
		add(list, "BeamLanternCord", "Block", v(0.3, 8, 0.3), c(40, 34, 30), "Fabric", P(x, 72, -6))
		add(
			list,
			"BeamLantern",
			"Ball",
			v(6, 8, 6),
			if i == 1 then LANTERN_RED else c(255, 170, 90),
			"Neon",
			P(x, 64, -6),
			{
				light = if i == 2
					then { kind = "Point", color = c(255, 160, 90), brightness = 1.4, range = 40 }
					else nil,
				anim = { kind = "Sway", period = 4.4 + i * 0.5, amount = 4, axis = "X" },
			}
		)
	end
	-- 돌 탑 (작은 무리)
	for k = 0, 3 do
		local sx, sz = pol(235, 62)
		add(
			list,
			"StoneStack",
			"Ball",
			v(5 - k, 1.6, 4 - k * 0.8),
			({ ROCK_LIGHT, ROCK, ROCK_MOSS, ROCK_LIGHT })[k + 1],
			"Rock",
			P(sx + k * 0.2, y + 0.8 + k * 1.5, sz),
			{
				rotation = v(0, k * 30, 0),
			}
		)
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	clawMachine(list)
	poolRim(list)
	ground(list)
	steam(list)
	-- 종이등 기둥: 탕 둘레 땅 위 6개 (데크 위에는 두지 않아요), 빛 4개
	for i, a in { 0, 60, 120, 180, 240, 300 } do
		local x, z = pol(a + 15, 72)
		andon(list, x, z, i % 3 ~= 0, i % 3 == 1)
	end
	props(list)
	trayBasin(list)
	lampGantry(list)
	details(list)
	garden(list)
	inn(list)
	fenceAndGrove(list)
	return list
end

---------------------------------------------------------------- 소개 카메라

-- ① 여관 쪽 높은 데서 탕 전체 + 종이등 → ② 인형뽑기·고양이 클로즈업 → ③ 물 위 낮은 데서 계단 데크 올려다보기
-- → ④ 바깥 1단(먼저 가라앉음) → ⑤ 출발 자리. 전부 탕 중심 기준.
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = P(-8, 46, -96), lookAt = P(2, 2, 8) },
		{ pos = P(9, 17, 22), lookAt = P(0, 15, 0) },
		{ pos = P(30, 2.5, 38), lookAt = P(0, 12, 0) },
		{ pos = P(-46, 17, 34), lookAt = P(-24, 0, 16) },
		{ pos = P(5, 12, 40), lookAt = P(0, 5, 4) },
	}
end

return Art
