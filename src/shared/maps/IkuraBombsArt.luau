--!strict
-- "연어알 폭탄 접시" 아트 데이터 (m5-04, docs/REFERENCE-map-art-direction.md). Roblox API를 쓰지 않아요 — lune에서 바로 불러요.
-- 컨셉: 해 질 녘 바닷가 가게 앞, 부두 위에 뜬 거대한 간장 접시. 해는 -X(서쪽) 바다로 지고, +X·+Z는 가게 거리.
-- 좌표는 map origin(접시 중심, 칸 윗면 높이) 기준 로컬. 낙하 탈락선은 y −30, 배경 바닥(부두 −45, 바다 −62)은 그보다 10 이상 아래.
--   IkuraBombsArt.decor() -> { DecorSpec }            정적 장식 전부 (충돌 없음)
--   IkuraBombsArt.tileDecor(tileId) -> { DecorSpec }   칸 경계 얇은 선 (칸 Model 안 Decor 폴더, 칸과 같이 사라짐)
--   IkuraBombsArt.spoonDecor() -> { DecorSpec }        셰프 팔·손·은 숟가락 (숟가락 그릇 중심 기준 — 폭탄 쪽으로 움직여서 anim 없음)
--   IkuraBombsArt.introCamera() -> { IntroPoint }      바다 쪽 넓은 샷 → 숟가락 → 위에서 반전 → 출발 자리
--   IkuraBombsArt.courseVolume() -> Bounds              장식이 가리면 안 되는 상자 (칸 윗면 위 2~12, 접시 안)
--   IkuraBombsArt.COLORS                                판정 파츠·폭탄 색 (IkuraBombs가 씀)
--   IkuraBombsArt.LIGHTING                              맵 조명 프리셋 (MapLighting 모양)
--   IkuraBombsArt.BUDGET = "Extended"

local Layout = require(script.Parent.IkuraBombsLayout)
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

local IkuraBombsArt = {}

IkuraBombsArt.BUDGET = "Extended"
IkuraBombsArt.SIGHT_MIN = 2
IkuraBombsArt.SIGHT_MAX = 12
IkuraBombsArt.DECK_Y = -45 -- 부두 윗면 (낙하 탈락선 −30보다 15 아래)
IkuraBombsArt.SEA_Y = -62 -- 바다 윗면

local P = MapKitLogic.PALETTE
local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- 판정 파츠·폭탄 색. 칸은 장식보다 밝은 간장 캐러멜(가독성 위계 1), 원판은 한 단계 진하게.
IkuraBombsArt.COLORS = {
	soyA = c(156, 100, 58),
	soyB = c(138, 86, 48),
	center = c(116, 70, 40),
	seam = c(238, 214, 168), -- 칸 경계 선 (크림 금빛)
	crackLine = c(28, 16, 10),
	warn = c(230, 40, 40), -- 꼬치 쇼다운 연장전 경고와 같은 빨강
	bombCircle = c(232, 24, 36), -- 경고 원: 불투명 빨강 (연어알 주황과 구분)
	bombBlink = c(255, 92, 92), -- 깜빡일 때 밝은 빨강
	bombBorder = c(255, 255, 255), -- 경고 원 흰 테두리
	roe = P.Ikura,
} :: { [string]: RGB }

-- 맵 조명: 골든아워(해 −X 바다 쪽으로 낮게), 복숭아빛 안개 + 보랏빛 감쇠, 가게 등은 따뜻하게 / 바다는 차갑게
local LIGHTING: MapLighting.LightingPreset = {
	ClockTime = 17.8,
	Brightness = 2.4,
	Ambient = c(118, 92, 112),
	OutdoorAmbient = c(150, 116, 136),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.8,
	ShadowSoftness = 0.25,
	Atmosphere = {
		Density = 0.27,
		Offset = 0.1,
		Color = c(255, 196, 150),
		Decay = c(112, 84, 140),
		Glare = 0.3,
		Haze = 1.0,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.12, TintColor = c(255, 242, 232) },
	Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.3 },
	SunRays = { Intensity = 0.04, Spread = 0.6 },
}
IkuraBombsArt.LIGHTING = LIGHTING

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

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

-- 세운 원기둥 (높이 h, 지름 d, 아랫면 y)
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

-- ring 헬퍼 결과를 두 색으로 번갈아 칠해요 (도자기 남색 무늬)
local function stripedRing(
	name: string,
	radius: number,
	thickness: number,
	height: number,
	segments: number,
	colorA: RGB,
	colorB: RGB,
	material: string,
	offset: Vec3,
	every: number
): { DecorSpec }
	local parts = MapKitShapes.ring(name, radius, thickness, height, segments, colorA, material, offset)
	for i, s in parts do
		if (i - 1) % every == 0 then
			s.color = colorB
		end
		s.reflectance = 0.08
	end
	return parts
end

local function polar(r: number, deg: number): (number, number)
	return Layout.polar(r, deg)
end

-- ── 전경: 도자기 접시 ───────────────────────────────────────────────────────
local PORCELAIN = P.Porcelain
local PORCELAIN_SHADE = shade(P.Porcelain, 0.9)
local NAVY = P.PorcelainRim
local NAVY_LIGHT = P.NorenLight

local function plate(list: { DecorSpec })
	local r = Layout.RADIUS
	-- 칸 바로 바깥 남색 립: 윗면보다 0.12 낮게, 바깥으로 0.7 (가장자리 가독성, 밟는 면을 가리지 않음)
	append(list, MapKitShapes.ring("PlateLip", r + 0.35, 0.7, 0.4, 60, NAVY, "SmoothPlastic", v(0, -0.32, 0)))
	-- 바깥으로 내려가는 흰 테두리 (두 단, 무늬 줄) — 윗면이 칸보다 1 넘게 낮아서 바닥으로 안 보여요
	append(
		list,
		stripedRing("PlateRim", r + 1.6, 1.9, 1.0, 48, PORCELAIN, NAVY_LIGHT, "SmoothPlastic", v(0, -1.6, 0), 4)
	)
	append(
		list,
		stripedRing("PlateRimOuter", r + 3.0, 1.2, 1.6, 48, PORCELAIN_SHADE, NAVY, "SmoothPlastic", v(0, -2.5, 0), 2)
	)
	-- 테두리 윗면 남색 물결 점
	for i = 0, 23 do
		local x, z = polar(r + 1.6, i * 15 + 7.5)
		add(list, "RimDot", "Ball", v(1.1, 0.2, 1.1), NAVY, "SmoothPlastic", v(x, -1.13, z), { castShadow = false })
	end
	-- 접시 몸통·바닥·굽 (아래에서 볼 때 두께와 그릇 모양)
	column(list, "PlateBody", (r + 3) * 2, 2.2, PORCELAIN, "SmoothPlastic", 0, -3.6, 0, { reflectance = 0.06 })
	column(list, "PlateBelly", r * 2 - 4, 1.8, PORCELAIN_SHADE, "SmoothPlastic", 0, -5.2, 0, { reflectance = 0.06 })
	append(list, MapKitShapes.ring("PlateBand", r - 1, 0.6, 0.8, 32, NAVY, "SmoothPlastic", v(0, -4.1, 0)))
	append(list, MapKitShapes.ring("PlateFoot", 14, 1.4, 2, 24, PORCELAIN_SHADE, "SmoothPlastic", v(0, -6.2, 0)))
end

-- 접시 옆 작은 종지 위 와사비 산 + 생강 꽃잎 (r 31, 시야 상자 밖, 윗면 −2.5 — 바닥보다 확실히 낮게)
local function condimentDish(list: { DecorSpec }, deg: number, seed: number, withGinger: boolean)
	local rng = MapKitShapes.rng(seed)
	local cx, cz = polar(31, deg)
	append(
		list,
		MapKitShapes.rimDisc("Saucer", 11, 1, PORCELAIN, "SmoothPlastic", v(cx, -3.5, cz), {
			rimColor = NAVY,
			rimWidth = 0.7,
			rimHeight = 0.8,
			segments = 14,
		})
	)
	-- 와사비 산: 큰 덩이 + 위로 작은 덩이 (3 shade)
	local wasabi = MapKitLogic.shades(P.Wasabi)
	add(list, "Wasabi", "Ball", v(6.5, 4.6, 6), wasabi.base, "Sand", v(cx, -1.4, cz))
	add(list, "Wasabi", "Ball", v(4.2, 3.4, 4), wasabi.light, "Sand", v(cx + 0.6, 0.6, cz - 0.4))
	add(list, "Wasabi", "Ball", v(2.4, 2.2, 2.4), wasabi.dark, "Sand", v(cx - 0.4, 2.0, cz + 0.3))
	add(list, "Wasabi", "Ball", v(1.4, 1.4, 1.4), wasabi.light, "Sand", v(cx + 0.2, 3.0, cz))
	if withGinger then
		-- 생강 꽃잎: 얇은 분홍 조각을 부채꼴로
		local pink = c(250, 186, 186)
		for i = 0, 5 do
			local a = deg + 90 + (i - 2.5) * 18
			local gx, gz = polar(3.2, a)
			add(
				list,
				"Ginger",
				"Ball",
				v(3.4 * (0.85 + rng:next() * 0.3), 0.4, 2.2),
				if i % 2 == 0 then pink else shade(pink, 0.9),
				"SmoothPlastic",
				v(cx + gx, -2.4 + i * 0.12, cz + gz),
				{ rotation = v(rng:range(-12, 12), -a, 0), castShadow = false }
			)
		end
	end
end

-- ── 중경: 연어알 군함말이 탑 (폭탄 창고) ───────────────────────────────────
local function gunkanTower(list: { DecorSpec }, x: number, z: number)
	local deck = IkuraBombsArt.DECK_Y
	local d = 30
	local h = 66
	local top = deck + h
	local nori = MapKitLogic.shades(P.Nori)
	-- 밥 바닥 + 김 원통 + 김 겹친 이음매 띠 2줄
	column(list, "GunkanRice", d - 1, 8, P.Rice, "SmoothPlastic", x, deck, z)
	column(list, "GunkanNori", d, h - 4, nori.base, "Fabric", x, deck + 2, z)
	column(list, "GunkanNoriBand", d + 0.6, 4, nori.light, "Fabric", x, deck + 18, z)
	column(list, "GunkanNoriBand", d + 0.6, 3, nori.dark, "Fabric", x, top - 12, z)
	column(list, "GunkanNoriLip", d + 1, 1.5, nori.light, "Fabric", x, top - 3.5, z)
	-- 위로 넘치는 연어알 더미 (반투명 Glass, 3 shade)
	local roe = MapKitLogic.shades(P.Ikura)
	local rng = MapKitShapes.rng(404)
	local layers =
		{ { r = 11, n = 12, y = top - 1 }, { r = 7.5, n = 9, y = top + 2.4 }, { r = 4, n = 6, y = top + 5.4 } }
	for li, layer in layers do
		for i = 0, layer.n - 1 do
			local a = i * 360 / layer.n + li * 13
			local rx, rz = polar(layer.r + rng:range(-0.6, 0.6), a)
			local size = 4.6 + rng:range(-0.5, 0.7)
			local pick = if i % 4 == 0 then roe.light elseif i % 3 == 0 then roe.dark else roe.base
			local pulse: AnimSpec? = if li == 2 and i % 3 == 0
				then { kind = "Pulse", period = 2.6 + i * 0.2, amount = 0.08 }
				else nil
			add(list, "TowerRoe", "Ball", v(size, size, size), pick, "Glass", v(x + rx, layer.y, z + rz), {
				transparency = 0.2,
				reflectance = 0.15,
				castShadow = false,
				anim = pulse,
			})
		end
	end
	add(list, "TowerRoe", "Ball", v(5.6, 5.6, 5.6), roe.light, "Glass", v(x, top + 8.2, z), {
		transparency = 0.15,
		reflectance = 0.2,
		anim = { kind = "Pulse", period = 3.2, amount = 0.1 },
	})
	-- 밥 띠 (김 위로 살짝 보이는 흰 밥, 연어알 아래)
	column(list, "GunkanRiceTop", d - 1.6, 2.4, P.Rice, "SmoothPlastic", x, top - 2.6, z)
	-- 옆으로 흘러내린 연어알 줄기 (접시 쪽 = +X 면, 촘촘하게 겹쳐서 한 줄기로)
	for i = 0, 11 do
		local a = -14 + i * 2.2 + (if i % 2 == 0 then 0 else 3)
		local rx, rz = polar(d / 2 + 1.0, a)
		local s = 4.6 - i * 0.18
		add(
			list,
			"TowerDrip",
			"Ball",
			v(s, s, s),
			if i % 3 == 0 then roe.light elseif i % 2 == 0 then roe.base else roe.dark,
			"Glass",
			v(x + rx, top - 1.5 - i * 2.6, z + rz),
			{ transparency = 0.18, reflectance = 0.15, castShadow = false }
		)
	end
	for i = 0, 6 do
		local px, pz = polar(d / 2 + 4 + rng:range(0, 10), rng:range(-70, 60))
		local s = 4 + rng:range(-0.6, 0.8)
		add(
			list,
			"SpilledRoe",
			"Ball",
			v(s, s, s),
			if i % 2 == 0 then roe.base else roe.light,
			"Glass",
			v(x + px, deck + s / 2, z + pz),
			{ transparency = 0.2, reflectance = 0.15, castShadow = false }
		)
	end
	-- 작은 나무 표지판 "폭탄 창고"
	append(
		list,
		MapKitShapes.bevelBox(
			"TowerSign",
			v(2, 10, 16),
			P.WoodLight,
			"Wood",
			v(x + d / 2 + 6, deck + 22, z - 14),
			0.6,
			v(0, 0, 8)
		)
	)
	append(
		list,
		MapKitShapes.capsule("TowerSignPost", 26, 1.4, P.WoodDark, "Wood", v(x + d / 2 + 6, deck + 13, z - 14), UPRIGHT)
	)
end

-- ── 배경: 부두 ───────────────────────────────────────────────────────────────
local DECK_X0, DECK_X1 = -80, 150
local DECK_Z0, DECK_Z1 = -100, 240

local function pier(list: { DecorSpec })
	local deck = IkuraBombsArt.DECK_Y
	local wood = MapKitLogic.shades(mix(P.Wood, P.WoodDark, 0.35))
	local plankW = 10
	local i = 0
	local z = DECK_Z0
	while z < DECK_Z1 do
		local pick = if i % 5 == 1 then wood.light elseif i % 5 == 3 then wood.dark else wood.base
		add(
			list,
			"DeckPlank",
			"Block",
			v(DECK_X1 - DECK_X0, 2, plankW - 0.4),
			pick,
			"WoodPlanks",
			v((DECK_X0 + DECK_X1) / 2, deck - 1, z + plankW / 2),
			{ castShadow = false }
		)
		z += plankW
		i += 1
	end
	-- 부두 가장자리 들보 (바다 쪽 −X, −Z)
	add(
		list,
		"DeckBeam",
		"Block",
		v(3, 4, DECK_Z1 - DECK_Z0),
		wood.dark,
		"Wood",
		v(DECK_X0 - 1.5, deck - 2, (DECK_Z0 + DECK_Z1) / 2)
	)
	add(
		list,
		"DeckBeam",
		"Block",
		v(DECK_X1 - DECK_X0 + 3, 4, 3),
		wood.dark,
		"Wood",
		v((DECK_X0 + DECK_X1) / 2, deck - 2, DECK_Z0 - 1.5)
	)
	-- 말뚝 (바다로 내려가는 기둥 + 위로 조금 솟은 계류 기둥)
	local zz = DECK_Z0 + 10
	local k = 0
	while zz < DECK_Z1 do
		column(list, "Piling", 5, 22, wood.dark, "Wood", DECK_X0 - 1, IkuraBombsArt.SEA_Y - 4, zz, {
			particle = if k == 3 or k == 9 then "SeaSpray" else nil,
			particleRate = if k == 3 or k == 9 then 3 else nil,
		})
		if k % 3 == 0 then
			column(list, "Bollard", 4.4, 7, wood.base, "Wood", DECK_X0 + 3, deck, zz)
			add(list, "BollardCap", "Ball", v(4.8, 3, 4.8), wood.light, "Wood", v(DECK_X0 + 3, deck + 7, zz))
		end
		zz += 30
		k += 1
	end
	local xx = DECK_X0 + 20
	while xx < DECK_X1 do
		column(list, "Piling", 5, 22, wood.dark, "Wood", xx, IkuraBombsArt.SEA_Y - 4, DECK_Z0 - 1)
		xx += 35
	end
	-- 바다 쪽 유리 부표 등 (차가운 빛, 온도 대비)
	local glassBlue = c(150, 210, 255)
	for _, pos in { v(DECK_X0 + 3, deck + 9.5, -60), v(DECK_X0 + 3, deck + 9.5, 120) } do
		add(list, "FloatLamp", "Ball", v(4, 4, 4), glassBlue, "Neon", pos, {
			light = { kind = "Point", color = glassBlue, brightness = 2, range = 40 },
			anim = { kind = "Bob", period = 4.4, amount = 0.4 },
		})
	end
	-- 밧줄 사리
	for _, pos in { v(DECK_X0 + 10, deck + 1, 20), v(DECK_X0 + 14, deck + 1, -40) } do
		append(list, MapKitShapes.ring("RopeCoil", 3.2, 1.2, 1.2, 10, c(214, 186, 140), "Fabric", pos))
		append(
			list,
			MapKitShapes.ring("RopeCoil", 2.2, 1.1, 1.1, 8, c(196, 168, 124), "Fabric", v(pos.x, pos.y + 1, pos.z))
		)
	end
end

-- ── 배경: 바다·섬·등대·해 ────────────────────────────────────────────────────
local function seaAndHorizon(list: { DecorSpec })
	local sea = IkuraBombsArt.SEA_Y
	local deepSea = shade(P.Sea, 0.7)
	-- 큰 바다판 (불투명 + 반사): 멀리 짙게, 부두 근처 청록
	add(
		list,
		"Sea",
		"Block",
		v(1480, 2, 1480),
		deepSea,
		"SmoothPlastic",
		v(0, sea - 1, 0),
		{ reflectance = 0.18, castShadow = false }
	)
	-- 해 (지는 해, 보이는 광원)
	add(list, "Sun", "Ball", v(110, 110, 110), c(255, 196, 120), "Neon", v(-735, 18, 40), { castShadow = false })
	-- 먼 섬·산 실루엣 (보랏빛, 채도 낮게) — 수평선이 비지 않게 −X·−Z·+Z 쪽 둘레
	local hill = c(92, 74, 112)
	local hillDark = c(70, 58, 94)
	local rng = MapKitShapes.rng(77)
	local islands = {
		{ -700, -420, 260, 110 },
		{ -690, -150, 200, 70 },
		{ -700, 250, 240, 95 },
		{ -680, 480, 220, 80 },
		{ -420, -690, 300, 120 },
		{ -60, -700, 260, 90 },
		{ 300, -690, 320, 140 },
		{ 600, -620, 240, 110 },
		{ -380, 690, 260, 90 },
		{ 120, 700, 300, 120 },
	}
	for i, isl in islands do
		local w, h = isl[3], isl[4]
		local yaw = math.deg(math.atan2(-isl[2], isl[1])) + 90
		local tone = if i % 2 == 0 then hill else hillDark
		-- 낮고 넓은 몸통 + 어긋난 봉우리 2개 (반구 하나보다 섬 같은 실루엣)
		add(list, "Island", "Ball", v(w, h * 0.9, w * 0.5), tone, "Rock", v(isl[1], sea, isl[2]), {
			rotation = v(0, yaw, 0),
			castShadow = false,
		})
		for k = 1, 2 do
			local along = rng:range(-0.3, 0.3) * w
			local ox, oz = along * math.cos(math.rad(yaw)), -along * math.sin(math.rad(yaw))
			local pw = w * rng:range(0.25, 0.45)
			local ph = h * rng:range(1.1, 1.9) * (if k == 1 then 1 else 0.7)
			add(
				list,
				"IslandPeak",
				"Ball",
				v(pw, ph, pw * 0.8),
				mix(tone, c(150, 116, 150), 0.15 * k),
				"Rock",
				v(isl[1] + ox, sea, isl[2] + oz),
				{ rotation = v(0, yaw + rng:range(-20, 20), 0), castShadow = false }
			)
		end
	end
	-- 등대 (바위섬 위, 흰·남 띠 + 빛)
	local lx, lz = -430, -300
	add(list, "LighthouseRock", "Ball", v(90, 40, 70), hillDark, "Rock", v(lx, sea, lz), { castShadow = false })
	column(list, "Lighthouse", 18, 34, PORCELAIN, "SmoothPlastic", lx, sea + 12, lz)
	column(list, "Lighthouse", 15, 30, NAVY, "SmoothPlastic", lx, sea + 46, lz)
	column(list, "Lighthouse", 12, 24, PORCELAIN, "SmoothPlastic", lx, sea + 76, lz)
	add(list, "LighthouseLamp", "Ball", v(10, 10, 10), c(255, 236, 170), "Neon", v(lx, sea + 105, lz), {
		light = { kind = "Point", color = c(255, 230, 170), brightness = 3, range = 60 },
		anim = { kind = "Pulse", period = 3, amount = 0.12 },
	})
	append(list, MapKitShapes.capsule("LighthouseRoof", 16, 16, P.LacquerDark, "Metal", v(lx, sea + 114, lz), UPRIGHT))
	-- 작은 배와 부표 (Bob)
	local boats = { { -260, -80, 30 }, { -190, 210, -20 }, { -330, 120, 70 } }
	for i, b in boats do
		local hull = if i == 2 then c(70, 120, 170) else c(236, 232, 222)
		append(
			list,
			MapKitShapes.bevelBox("BoatHull", v(34, 7, 12), hull, "Wood", v(b[1], sea + 2, b[2]), 2.5, v(0, b[3], 0))
		)
		add(
			list,
			"BoatMast",
			"Cylinder",
			v(26, 1.2, 1.2),
			P.WoodDark,
			"Wood",
			v(b[1], sea + 18, b[2]),
			{ rotation = UPRIGHT }
		)
		add(list, "BoatSail", "Wedge", v(1, 20, 12), c(250, 244, 232), "Fabric", v(b[1], sea + 17, b[2] + 6), {
			rotation = v(0, b[3], 0),
			anim = { kind = "Sway", period = 6 + i, amount = 3, axis = "X" },
		})
	end
	for i, pos in { v(-120, sea + 1.5, -120), v(-140, sea + 1.5, 160), v(-210, sea + 1.5, 30), v(60, sea + 1.5, -170) } do
		add(list, "Buoy", "Ball", v(6, 6, 6), if i % 2 == 0 then P.Porcelain else P.SalmonLight, "SmoothPlastic", pos, {
			anim = { kind = "Bob", period = 3.5 + i * 0.4, amount = 0.8 },
		})
		add(list, "BuoyTop", "Cylinder", v(4, 1.2, 1.2), NAVY, "SmoothPlastic", v(pos.x, pos.y + 4, pos.z), {
			rotation = UPRIGHT,
			anim = { kind = "Bob", period = 3.5 + i * 0.4, amount = 0.8 },
		})
	end
	-- 갈매기 (높이 떠서 천천히 오르내림)
	for i, pos in { v(-160, 70, -40), v(-120, 86, 50), v(-210, 64, 110) } do
		local gull: AnimSpec = { kind = "Bob", period = 5 + i, amount = 3 }
		add(
			list,
			"Gull",
			"Ball",
			v(5, 2.4, 2.4),
			c(250, 250, 250),
			"SmoothPlastic",
			pos,
			{ anim = gull, castShadow = false }
		)
		add(
			list,
			"GullWing",
			"Block",
			v(1.6, 0.4, 8),
			c(236, 236, 240),
			"SmoothPlastic",
			v(pos.x, pos.y + 0.6, pos.z - 4),
			{
				rotation = v(-18, 0, 0),
				anim = gull,
				castShadow = false,
			}
		)
		add(
			list,
			"GullWing",
			"Block",
			v(1.6, 0.4, 8),
			c(236, 236, 240),
			"SmoothPlastic",
			v(pos.x, pos.y + 0.6, pos.z + 4),
			{
				rotation = v(18, 0, 0),
				anim = gull,
				castShadow = false,
			}
		)
	end
end

-- ── 배경: 가게 거리 (+X·+Z) ───────────────────────────────────────────────────
-- 가게 한 채: 정면이 faceDir 쪽("X" = −X를 봄, "Z" = −Z를 봄). 벽·지붕·노렌·초롱·불 켜진 창.
local function shop(
	list: { DecorSpec },
	x: number,
	z: number,
	width: number,
	height: number,
	faceZ: boolean,
	seed: number,
	lit: boolean
)
	local deck = IkuraBombsArt.DECK_Y
	local rng = MapKitShapes.rng(seed)
	local yaw = if faceZ then 0 else 90 -- 로컬 묶음은 −Z를 봐요. +90도 돌리면 −X를 봐요
	local local_: { DecorSpec } = {}
	local wallColor = mix(c(232, 210, 178), c(214, 182, 150), rng:next())
	local wood = MapKitLogic.shades(mix(P.Wood, P.WoodDark, 0.5))
	local depth = 24
	-- 벽 (세로 모서리 둥근) + 아래 나무 판벽 + 2층 띠
	append(
		local_,
		MapKitShapes.roundedBox(
			"ShopWall",
			v(width, height, depth),
			wallColor,
			"Plaster",
			v(0, height / 2, depth / 2),
			{
				style = "vertical",
				radius = 2,
			}
		)
	)
	add(
		local_,
		"ShopWainscot",
		"Block",
		v(width + 0.6, height * 0.35, 1),
		wood.dark,
		"WoodPlanks",
		v(0, height * 0.175, -0.4)
	)
	add(local_, "ShopBand", "Block", v(width + 1, 3, 2), wood.base, "Wood", v(0, height * 0.55, -0.6))
	-- 처마 지붕 (기와, 앞으로 기운 쐐기 + 위 지붕)
	local roof = mix(c(70, 72, 92), c(90, 70, 70), rng:next() * 0.5)
	add(
		local_,
		"ShopEave",
		"Wedge",
		v(width + 12, 10, 16),
		roof,
		"ClayRoofTiles",
		v(0, height * 0.55 + 6, -7),
		{ rotation = v(0, 180, 0) }
	)
	add(
		local_,
		"ShopRoof",
		"Wedge",
		v(width + 8, 26, depth / 2 + 4),
		shade(roof, 0.85),
		"ClayRoofTiles",
		v(0, height + 13, depth / 4 - 2),
		{
			rotation = v(0, 180, 0),
		}
	)
	add(
		local_,
		"ShopRoof",
		"Wedge",
		v(width + 8, 26, depth / 2 + 4),
		roof,
		"ClayRoofTiles",
		v(0, height + 13, depth * 0.75 + 2)
	)
	-- 입구 노렌 (남색 천 4장, 흔들림) + 문간 어두운 안쪽
	add(local_, "ShopDoor", "Block", v(width * 0.5, height * 0.4, 1), c(46, 34, 30), "Wood", v(0, height * 0.2, -0.2))
	for i = 0, 3 do
		local nx = (i - 1.5) * width * 0.13
		add(
			local_,
			"Noren",
			"Block",
			v(width * 0.12, height * 0.16, 0.4),
			if i % 2 == 0 then P.Noren else P.NorenLight,
			"Fabric",
			v(nx, height * 0.47, -1.2),
			{ anim = { kind = "Sway", period = 4 + i * 0.3, amount = 4, axis = "X" }, castShadow = false }
		)
	end
	-- 불 켜진 2층 창 (따뜻한 빛, 보이는 광원)
	local glow = c(255, 206, 140)
	for i = 0, 1 do
		local wx = (i - 0.5) * width * 0.45
		add(
			local_,
			"ShopWindow",
			"Block",
			v(width * 0.26, height * 0.16, 0.6),
			glow,
			"Neon",
			v(wx, height * 0.75, -0.3),
			{ castShadow = false }
		)
		add(
			local_,
			"ShopWindowFrame",
			"Block",
			v(width * 0.3, 1.2, 1.2),
			wood.dark,
			"Wood",
			v(wx, height * 0.75 - height * 0.08 - 0.6, -0.6)
		)
	end
	-- 초롱 2개 (흔들림, 하나만 빛)
	for i = 0, 1 do
		local lx = (i - 0.5) * width * 0.8
		add(local_, "Lantern", "Ball", v(7, 9, 7), c(255, 226, 170), "Neon", v(lx, height * 0.5, -5), {
			anim = { kind = "Sway", period = 5 + i, amount = 5, axis = "X" },
			light = if lit and i == 0
				then { kind = "Point", color = c(255, 190, 120), brightness = 2.2, range = 45 }
				else nil,
			particle = if lit and i == 1 then "Sparkle" else nil,
			particleRate = if lit and i == 1 then 2 else nil,
			castShadow = false,
		})
		add(
			local_,
			"LanternCap",
			"Cylinder",
			v(1.4, 5, 5),
			wood.dark,
			"Wood",
			v(lx, height * 0.5 + 5, -5),
			{ rotation = UPRIGHT }
		)
	end
	-- 간판
	append(
		local_,
		MapKitShapes.bevelBox("ShopSign", v(width * 0.5, 9, 2), wood.light, "Wood", v(0, height * 0.62 + 2, -2.2), 0.6)
	)
	append(list, MapKitShapes.transform(local_, v(x, deck, z), v(0, yaw, 0)))
end

local function street(list: { DecorSpec })
	local deck = IkuraBombsArt.DECK_Y
	-- 포장 길 (부두 끝 +X 쪽) — 큰 판 3장, shade 섞기
	local stone = MapKitLogic.shades(c(150, 136, 128))
	add(
		list,
		"Street",
		"Block",
		v(160, 2, 520),
		stone.base,
		"Cobblestone",
		v(DECK_X1 + 80, deck - 1.02, 60),
		{ castShadow = false }
	)
	add(list, "StreetCurb", "Block", v(4, 2.4, 520), stone.dark, "Concrete", v(DECK_X1 + 1, deck - 0.8, 60))
	add(
		list,
		"Street",
		"Block",
		v(380, 2, 140),
		stone.light,
		"Cobblestone",
		v(40, deck - 1.04, DECK_Z1 + 70),
		{ castShadow = false }
	)
	-- 가게들: +X 줄 (−X를 봄), +Z 줄 (−Z를 봄)
	local xRow = { { -150, 70, 150 }, { -75, 76, 190 }, { 0, 70, 165 }, { 80, 78, 210 } }
	for i, s in xRow do
		shop(list, 220, s[1], s[2], s[3], false, 10 + i, i % 2 == 1)
	end
	local zRow = { { -40, 70, 170 }, { 40, 70, 200 } }
	for i, s in zRow do
		shop(list, s[1], 300, s[2], s[3], true, 20 + i, i == 1)
	end
end

-- ── 중경: 출발 쪽 뒤 노점 (+X) ────────────────────────────────────────────────
local function stall(list: { DecorSpec })
	local deck = IkuraBombsArt.DECK_Y
	local local_: { DecorSpec } = {}
	local wood = MapKitLogic.shades(P.Wood)
	local lacquer = MapKitLogic.shades(mix(P.Noren, P.WoodDark, 0.35)) -- 남색 옻칠 (위험 빨강과 안 겹치게)
	-- 카운터 (둥근 상자, 위 판 트림)
	append(
		local_,
		MapKitShapes.roundedBox(
			"StallCounter",
			v(70, 40, 18),
			wood.base,
			"Wood",
			v(0, 20, 0),
			{ radius = 2.2, style = "vertical" }
		)
	)
	append(local_, MapKitShapes.bevelBox("StallTop", v(74, 3, 22), wood.light, "Wood", v(0, 41.5, -1), 1))
	add(local_, "StallKick", "Block", v(70.4, 6, 18.4), wood.dark, "WoodPlanks", v(0, 3, 0))
	-- 기둥 4개 + 지붕
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			append(
				local_,
				MapKitShapes.capsule("StallPost", 92, 3, lacquer.dark, "Wood", v(sx * 34, 46, sz * 9 + 2), UPRIGHT)
			)
		end
	end
	add(
		local_,
		"StallRoof",
		"Wedge",
		v(84, 14, 22),
		lacquer.base,
		"WoodPlanks",
		v(0, 98, -6),
		{ rotation = v(0, 180, 0) }
	)
	add(local_, "StallRoof", "Wedge", v(84, 14, 22), lacquer.light, "WoodPlanks", v(0, 98, 16))
	add(local_, "StallRidge", "Cylinder", v(88, 3, 3), lacquer.dark, "Wood", v(0, 105.5, 5))
	-- 노렌 5장 (남색, 흔들림)
	for i = 0, 4 do
		add(
			local_,
			"StallNoren",
			"Block",
			v(12.6, 20, 0.4),
			if i % 2 == 0 then P.Noren else P.NorenLight,
			"Fabric",
			v((i - 2) * 13.4, 78, -10.5),
			{ anim = { kind = "Sway", period = 4.5 + i * 0.25, amount = 5, axis = "X" }, castShadow = false }
		)
	end
	-- 초롱 3개 (따뜻한 빛)
	for i = 0, 2 do
		local lx = (i - 1) * 30
		add(local_, "StallLantern", "Ball", v(8, 11, 8), c(255, 220, 160), "Neon", v(lx, 64, -14), {
			light = { kind = "Point", color = c(255, 186, 110), brightness = 2.4, range = 40 },
			anim = { kind = "Sway", period = 5.2 + i * 0.4, amount = 6, axis = "X" },
			particle = if i == 1 then "Sparkle" else nil,
			particleRate = if i == 1 then 2 else nil,
			castShadow = false,
		})
		add(
			local_,
			"StallLanternCap",
			"Cylinder",
			v(1.5, 6, 6),
			lacquer.dark,
			"Wood",
			v(lx, 70.2, -14),
			{ rotation = UPRIGHT }
		)
	end
	-- 카운터 위 소품: 찻잔(김), 간장병, 초밥 접시 무리
	append(
		local_,
		MapKitShapes.rimDisc(
			"Teacup",
			8,
			7,
			c(140, 160, 120),
			"SmoothPlastic",
			v(-24, 46.5, -2),
			{ rimColor = c(110, 130, 96), rimHeight = 1, segments = 10 }
		)
	)
	add(local_, "TeaSteam", "Ball", v(1, 1, 1), c(255, 255, 255), "SmoothPlastic", v(-24, 50.5, -2), {
		transparency = 1,
		particle = "Steam",
		particleRate = 4,
		castShadow = false,
	})
	column(local_, "SoyBottle", 6, 12, c(40, 26, 20), "Glass", 22, 43, -1, { transparency = 0.15, reflectance = 0.2 })
	column(local_, "SoyBottleCap", 4.6, 3, P.Lacquer, "SmoothPlastic", 22, 55, -1)
	append(
		local_,
		MapKitShapes.rimDisc(
			"SushiPlate",
			18,
			1.2,
			PORCELAIN,
			"SmoothPlastic",
			v(2, 43.6, -2),
			{ rimColor = NAVY, segments = 14 }
		)
	)
	for i = 0, 2 do
		local sx = -4 + i * 6
		add(local_, "Nigiri", "Ball", v(5, 2.6, 3.2), P.Rice, "SmoothPlastic", v(sx, 45.4, -2))
		add(
			local_,
			"NigiriTop",
			"Ball",
			v(5.4, 1.2, 3.6),
			if i == 1 then P.Tuna else P.Salmon,
			"SmoothPlastic",
			v(sx, 46.6, -2)
		)
	end
	-- 노점 = +X 쪽, 정면(-Z 로컬)이 접시(−X)를 보게 −90도... 로컬 −Z를 −X로: yaw 90
	append(list, MapKitShapes.transform(local_, v(96, deck, 0), v(0, 90, 0)))
end

-- ── 그림자 조명: 접시 위 나무 기둥 등 (고정, 숟가락 그림자가 접시에 떨어지게) ─────────────
local function lampBoom(list: { DecorSpec })
	local deck = IkuraBombsArt.DECK_Y
	local px, pz = 40, 40
	local wood = MapKitLogic.shades(P.WoodDark)
	local topY = 66
	append(
		list,
		MapKitShapes.capsule("LampPost", topY - deck + 4, 4, wood.base, "Wood", v(px, (topY + deck) / 2, pz), UPRIGHT)
	)
	-- 대각선 팔 (기둥 꼭대기 → 접시 중심 위)
	local len = math.sqrt(px * px + pz * pz)
	append(
		list,
		MapKitShapes.capsule("LampArm", len + 4, 2.6, wood.light, "Wood", v(px / 2, topY, pz / 2), v(0, -45, 0))
	)
	-- 줄 + 갓 + 전구 (SpotLight 아래로, 그림자 1개)
	add(
		list,
		"LampCord",
		"Cylinder",
		v(8, 0.5, 0.5),
		c(40, 36, 34),
		"Fabric",
		v(0, topY - 4, 0),
		{ rotation = UPRIGHT, castShadow = false }
	)
	add(
		list,
		"LampShade",
		"Cylinder",
		v(3, 9, 9),
		shade(P.Steel, 0.6),
		"Metal",
		v(0, topY - 9, 0),
		{ rotation = UPRIGHT, reflectance = 0.2, castShadow = false }
	)
	add(list, "LampBulb", "Ball", v(4, 4, 4), c(255, 230, 180), "Neon", v(0, topY - 11, 0), {
		light = {
			kind = "Spot",
			color = c(255, 214, 160),
			brightness = 3,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
		castShadow = false,
	})
end

-- 부두 위 소품 무리: 술통·나무 상자·생선 바구니 (scatter로 무리 지어, 크기·회전·shade 변형)
local function deckProps(list: { DecorSpec })
	local deck = IkuraBombsArt.DECK_Y
	local wood = MapKitLogic.shades(P.Wood)
	local barrel = MapKitLogic.shades(c(176, 128, 82))
	local areas = {
		{ seed = 5, count = 7, area = { center = v(30, deck, -62), size = v(60, 0, 40) } },
		{ seed = 9, count = 6, area = { center = v(-10, deck, 72), size = v(60, 0, 36) } },
	}
	for _, a in areas do
		append(
			list,
			MapKitShapes.scatter(
				a.seed,
				a.count,
				a.area,
				function(i: number, pos: Vec3, rng: MapKitShapes.Rng): { DecorSpec }
					local out: { DecorSpec } = {}
					local k = 0.85 + rng:next() * 0.3
					local kind = i % 3
					if kind == 0 then
						-- 술통: 몸통 + 테 두 줄 + 뚜껑
						local h, d = 14 * k, 11 * k
						column(
							out,
							"Barrel",
							d,
							h,
							if i % 2 == 0 then barrel.base else barrel.light,
							"Wood",
							pos.x,
							pos.y,
							pos.z
						)
						column(out, "BarrelHoop", d + 0.5, 1, barrel.dark, "Metal", pos.x, pos.y + h * 0.18, pos.z)
						column(out, "BarrelHoop", d + 0.5, 1, barrel.dark, "Metal", pos.x, pos.y + h * 0.72, pos.z)
						column(out, "BarrelLid", d - 1, 0.6, P.WoodLight, "Wood", pos.x, pos.y + h, pos.z)
					elseif kind == 1 then
						-- 나무 상자 (깎은 모서리), 가끔 위에 작은 상자
						local sz = 12 * k
						append(
							out,
							MapKitShapes.bevelBox(
								"Crate",
								v(sz, sz * 0.8, sz),
								if i % 2 == 0 then wood.base else wood.dark,
								"WoodPlanks",
								v(pos.x, pos.y + sz * 0.4, pos.z),
								0.8,
								v(0, rng:range(-25, 25), 0)
							)
						)
						if rng:next() < 0.5 then
							append(
								out,
								MapKitShapes.bevelBox(
									"Crate",
									v(sz * 0.6, sz * 0.5, sz * 0.6),
									wood.light,
									"WoodPlanks",
									v(pos.x, pos.y + sz * 0.8 + sz * 0.25, pos.z),
									0.5,
									v(0, rng:range(-40, 40), 0)
								)
							)
						end
					else
						-- 생선 바구니: 대나무 바구니 + 은빛 생선 두 마리
						append(
							out,
							MapKitShapes.rimDisc(
								"Basket",
								14 * k,
								5,
								c(196, 170, 110),
								"WoodPlanks",
								v(pos.x, pos.y + 2.5, pos.z),
								{ rimColor = c(160, 132, 80), rimHeight = 2, segments = 12 }
							)
						)
						for f = 0, 1 do
							append(
								out,
								MapKitShapes.capsule(
									"Fish",
									9 * k,
									2.4,
									shade(P.Steel, 1 + f * 0.1),
									"SmoothPlastic",
									v(pos.x + (f - 0.5) * 3, pos.y + 6.2, pos.z),
									v(0, rng:range(-30, 30) + f * 40, 0)
								)
							)
						end
					end
					return out
				end
			)
		)
	end
end

function IkuraBombsArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	plate(list)
	condimentDish(list, 180, 31, true)
	condimentDish(list, 270, 47, false)
	gunkanTower(list, -64, 20)
	pier(list)
	seaAndHorizon(list)
	street(list)
	stall(list)
	lampBoom(list)
	deckProps(list)
	return list
end

-- 칸 경계 얇은 선 (윗면에 붙은 금빛 줄, 높이 0.04). 칸 Model 안 Decor 폴더 → 칸이 떨어지면 같이 사라져요.
function IkuraBombsArt.tileDecor(tileId: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local tile = Layout.tile(tileId)
	if tile == nil or tile.ring == 0 then
		return list
	end
	local color = IkuraBombsArt.COLORS.seam
	local rIn, rOut = Layout.ringInner(tile.ring), Layout.ringOuter(tile.ring)
	-- 시작 각도 쪽 지름 방향 선
	local mid = (rIn + rOut) / 2
	local x, z = polar(mid, tile.fromDeg)
	add(list, "Seam", "Block", v(rOut - rIn, 0.04, 0.3), color, "SmoothPlastic", v(x, 0.02, z), {
		rotation = v(0, tile.fromDeg, 0),
		castShadow = false,
	})
	-- 안쪽 고리 경계 (조각마다 현 하나)
	local half = math.rad(Layout.SLICE_DEG / 2)
	for _, slice in Layout.slices(tile.ring) do
		if slice.tileId == tileId then
			local sx, sz = polar(rIn * math.cos(half), slice.angleDeg)
			add(
				list,
				"Seam",
				"Block",
				v(0.3, 0.04, 2 * rIn * math.sin(half) + 0.06),
				color,
				"SmoothPlastic",
				v(sx, 0.02, sz),
				{
					rotation = v(0, slice.angleDeg, 0),
					castShadow = false,
				}
			)
		end
	end
	return list
end

-- 셰프 팔·손·은 숟가락. 기준(0,0,0) = 숟가락 그릇 중심 (IkuraBombs가 높이 SPOON_HEIGHT에서 폭탄 쪽으로 옮겨요).
-- 팔은 +Z(가게 쪽) 위로 뻗어요. 움직이는 묶음이라 anim·그림자 조명 없음.
function IkuraBombsArt.spoonDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local steel = MapKitLogic.shades(P.Steel)
	local skin = c(250, 214, 182)
	local sleeve = MapKitLogic.shades(c(246, 244, 240))
	-- 그릇 (첫 파츠 = 기준) + 테두리 + 담긴 연어알
	add(list, "SpoonBowl", "Ball", v(7, 2.4, 8), steel.base, "Metal", v(0, 0, 0), { reflectance = 0.3 })
	append(list, MapKitShapes.ring("SpoonRim", 3.3, 0.5, 0.5, 14, steel.light, "Metal", v(0, 0.9, 0)))
	add(
		list,
		"SpoonRoe",
		"Ball",
		v(3.6, 3.6, 3.6),
		P.Ikura,
		"Glass",
		v(0, 1.6, 0),
		{ transparency = 0.2, reflectance = 0.15 }
	)
	-- 손잡이 (위로 휜 캡슐 두 마디)
	append(list, MapKitShapes.capsule("SpoonHandle", 9, 1.1, steel.base, "Metal", v(0, 1.2, 7), v(-15, -90, 0)))
	append(list, MapKitShapes.capsule("SpoonHandle", 7, 1.3, steel.dark, "Metal", v(0, 3.4, 13.5), v(-30, -90, 0)))
	-- 손: 손바닥 + 손가락 셋 + 엄지
	add(list, "ChefPalm", "Ball", v(6, 5, 6.5), skin, "SmoothPlastic", v(0, 5.4, 15))
	for i = 0, 2 do
		append(
			list,
			MapKitShapes.capsule(
				"ChefFinger",
				4.2,
				1.5,
				shade(skin, 0.95),
				"SmoothPlastic",
				v((i - 1) * 1.6, 3.4, 13.2 - i * 0.2),
				v(70, 0, 90)
			)
		)
	end
	append(list, MapKitShapes.capsule("ChefThumb", 4, 1.6, skin, "SmoothPlastic", v(2.6, 5, 12.8), v(0, 30, -20)))
	-- 소매 커프(접힌 띠) + 흰 소매 (+Z 위로)
	add(list, "ChefCuff", "Cylinder", v(3, 8, 8), sleeve.light, "Fabric", v(0, 7.2, 19), { rotation = v(-20, -90, 0) })
	append(
		list,
		MapKitShapes.capsule(
			"ChefSleeve",
			64,
			7.2,
			sleeve.base,
			"Fabric",
			v(0, 7.2 + 32 * math.sin(math.rad(20)), 19 + 2 + 32 * math.cos(math.rad(20))),
			v(-20, -90, 0)
		)
	)
	add(
		list,
		"ChefSleeveFold",
		"Cylinder",
		v(2, 7.8, 7.8),
		sleeve.dark,
		"Fabric",
		v(0, 7.2 + 14 * math.sin(math.rad(20)), 21 + 14 * math.cos(math.rad(20))),
		{
			rotation = v(-20, -90, 0),
		}
	)
	return list
end

-- 소개 카메라 (모든 점은 판정 파츠 경계 상자 + 40 안 — 밖이면 클라이언트가 로비 조명을 써요): ① 바다 쪽에서 접시 + 군함 탑 넓은 샷 → ② 숟가락 클로즈업 → ③ 숟가락 위에서 내려다보는 반전 → ④ 출발 자리
function IkuraBombsArt.introCamera(): { IntroPoint }
	local h = Layout.SPOON_HEIGHT
	return {
		{ pos = v(-60, 20, -50), lookAt = v(8, -6, 18) },
		{ pos = v(18, h + 6, -20), lookAt = v(0, h, 2) },
		{ pos = v(10, h + 11, -8), lookAt = v(-2, 0, 2) },
		{ pos = v(34, 9, 5), lookAt = v(0, 2, 0) },
	}
end

function IkuraBombsArt.courseVolume(): Bounds
	local r = Layout.RADIUS
	return {
		min = v(-r, IkuraBombsArt.SIGHT_MIN, -r),
		max = v(r, IkuraBombsArt.SIGHT_MAX, r),
	}
end

return IkuraBombsArt
