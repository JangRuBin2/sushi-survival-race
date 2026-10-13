--!strict
-- "등불 다리 건너기"(lantern-bridge, m5-15) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙).
--   Art.decor() -> { DecorSpec }        축제 입구 도리이, 다리 난간 밧줄 + 종이 등불, 쉼터 담장·석등, 결승 작은 문
--   Art.introCamera() -> { IntroPoint } 라운드 소개 경유점 4개
--   Art.LANTERN                         PointLight를 붙일 장식 파츠 이름 (다리당 3개 = 12개, 조명 예산 안)
-- 장식은 MapKit.buildDecor로 만들어서 충돌·쿼리·터치가 없어요 (판정과 무관).

local Layout = require(script.Parent.LanternBridgeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

local PALETTE = MapKitLogic.PALETTE

local Art = {}

-- 조명이 붙는 등불 이름 (다리마다 왼쪽 3개 = 4 다리 x 3 = 12, LIGHT_BUDGET과 같아요)
Art.LANTERN = "Lantern"

local LANTERN_COLORS: { RGB } = {
	{ r = 206, g = 48, b = 44 }, -- 빨강
	{ r = 230, g = 140, b = 40 }, -- 주황
	{ r = 248, g = 246, b = 238 }, -- 흰색
}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

-- 축제 입구 도리이 (출발 뒤쪽, 로컬 +Z)
local function addTorii(list: { DecorSpec })
	local z = Layout.START.front - 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "ToriiPillar",
			shape = "Cylinder",
			size = v(1.4, 16, 1.4),
			color = PALETTE.Lacquer,
			material = "Wood",
			offset = v(side * 7, 8, z),
			rotation = v(0, 0, 90),
		})
	end
	add(list, {
		name = "ToriiBeamTop",
		shape = "Block",
		size = v(18, 1.4, 2.4),
		color = PALETTE.Lacquer,
		material = "Wood",
		offset = v(0, 15.5, z),
	})
	add(list, {
		name = "ToriiBeamMid",
		shape = "Block",
		size = v(15, 1, 1.6),
		color = PALETTE.Nori,
		material = "Wood",
		offset = v(0, 12, z),
	})
end

-- 다리 하나의 난간 밧줄 + 종이 등불(좌우, 사분위 3곳). 왼쪽만 조명(LANTERN), 오른쪽은 장식만(LanternPlain)
-- — 다리 4개 x 왼쪽 3개 = 12개로 MapKitLogic.LIGHT_BUDGET(12)을 꽉 채워요.
local function addBridgeDecor(list: { DecorSpec }, bridge: Layout.Bridge, order: number)
	local center = (bridge.front + bridge.back) / 2
	local length = bridge.front - bridge.back
	for _, side in { -1, 1 } do
		local x = side * bridge.halfWidth
		add(list, {
			name = "RailRope",
			shape = "Cylinder",
			size = v(length, 0.3, 0.3),
			color = PALETTE.Wood,
			material = "Fabric",
			offset = v(x, 1.6, center),
			rotation = v(0, 0, 90),
		})
		for k = 1, 3 do
			local z = bridge.front - length * (k / 4)
			local colorIndex = ((order + k - 1) % #LANTERN_COLORS) + 1
			local isLit = side < 0
			add(list, {
				name = if isLit then Art.LANTERN else "LanternPlain",
				shape = "Ball",
				size = v(2.2, 2.6, 2.2),
				color = LANTERN_COLORS[colorIndex],
				material = "Neon",
				offset = v(x, 0.9, z),
			})
			add(list, {
				name = "LanternCap",
				shape = "Cylinder",
				size = v(0.3, 1.4, 1.4),
				color = PALETTE.Nori,
				material = "SmoothPlastic",
				offset = v(x, 2.0, z),
				rotation = v(0, 0, 90),
			})
			add(list, {
				name = "LanternCord",
				shape = "Block",
				size = v(0.15, 0.6, 0.15),
				color = PALETTE.Nori,
				material = "SmoothPlastic",
				offset = v(x, 2.5, z),
			})
		end
	end
end

-- 쉼터 담장(나무 울타리) + 석등(토로) 하나
local function addRestDecor(list: { DecorSpec }, rest: Layout.RestZone)
	local center = (rest.front + rest.back) / 2
	local depth = rest.front - rest.back
	local halfWidth = rest.width / 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "RestFence",
			shape = "Block",
			size = v(0.6, 2.2, depth - 1),
			color = PALETTE.Wood,
			material = "WoodPlanks",
			offset = v(side * halfWidth, 1.1, center),
		})
	end
	local lampX, lampZ = halfWidth - 1.8, rest.front - 2.5
	add(list, {
		name = "StoneLanternBase",
		shape = "Cylinder",
		size = v(2.4, 2.2, 2.2),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 1.2, lampZ),
		rotation = v(0, 0, 90),
	})
	add(list, {
		name = "StoneLanternBox",
		shape = "Block",
		size = v(1.8, 1.8, 1.8),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 2.8, lampZ),
	})
	add(list, {
		name = "StoneLanternCap",
		shape = "Block",
		size = v(2.4, 0.8, 2.4),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 3.9, lampZ),
	})
end

-- 결승 뒤 작은 문(도리이보다 낮고 소박해요)
local function addFinishGate(list: { DecorSpec })
	local z = Layout.FINISH.back + 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "FinishPost",
			shape = "Block",
			size = v(1.4, 10, 1.4),
			color = PALETTE.Lacquer,
			material = "Wood",
			offset = v(side * 7, 5, z),
		})
	end
	add(list, {
		name = "FinishBeam",
		shape = "Block",
		size = v(16, 1.2, 1.6),
		color = PALETTE.Lacquer,
		material = "Wood",
		offset = v(0, 9.6, z),
	})
end

----------------------------------------------------------------------------------------------------
-- m5-24 아트 패스 v2: "여름밤 축제의 흔들다리"
-- 층: FG 다리 끝 기둥·쉼터 석등(불씨)·난간 / MG 입구 도리이·바위 받침 기둥·강 위 등불 줄·떠내려가는 등롱 /
-- BG 계곡 절벽·절벽 위 축제 거리(노점·등)·강(낙하선 15 아래)·먼 신사·불꽃·산·달.
-- 다리 판자(LanternBridgePlank)는 서버가 CFrame을 바꾸며 흔들어요 — 그 위에 붙는 장식은 없고(전부 Decor 폴더, 고정),
-- anim은 고정된 기둥·줄·물 위 등롱에만 달아요(m5-24 절대 규칙).
----------------------------------------------------------------------------------------------------

Art.BUDGET = "Extended"

-- 여름밤 21시: 짙은 남색 밤 + 푸른 안개, 등불 주황이 돋보이게 Bloom 높게 (로비 14시와 분명히 다름)
Art.LIGHTING = {
	ClockTime = 21,
	Brightness = 1.4,
	Ambient = { r = 70, g = 72, b = 112 },
	OutdoorAmbient = { r = 82, g = 90, b = 140 },
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.32,
		Offset = 0.12,
		Color = { r = 64, g = 76, b = 128 },
		Decay = { r = 34, g = 30, b = 72 },
		Glare = 0,
		Haze = 1.4,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.12,
		TintColor = { r = 238, g = 240, b = 255 },
	},
	Bloom = { Intensity = 0.7, Size = 30, Threshold = 0.95 },
	SunRays = { Intensity = 0, Spread = 0.5 },
} :: MapLighting.LightingPreset

-- 강 수면 높이: 낙하선(-25)보다 15 아래
local WATER_Y = -Layout.FALL_MARGIN - 15
-- 절벽 위 축제 거리 높이 (다리보다 높아서 바닥으로 착각하지 않아요)
local STREET_Y = 14
local CLIFF_X = 56 -- 계곡 안쪽 절벽면
local BACK_Z = 22 -- 출발 뒤 절벽면
local FAR_Z = -186 -- 결승 너머 신사 언덕 앞면

local ROCK = MapKitLogic.shades({ r = 66, g = 70, b = 92 })
local WATER = { r = 18, g = 34, b = 62 }
local LANTERN_GLOW = { r = 255, g = 168, b = 84 }
local PAPER = { r = 255, g = 226, b = 170 }
local TORII = { r = 206, g = 52, b = 40 }
local DARK_WOOD = { r = 74, g = 48, b = 34 }
local PINE = MapKitLogic.shades({ r = 34, g = 70, b = 58 })

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

local UP = v(0, 0, 90)

local function column(
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
	put(list, name, "Cylinder", v(h, d, d), color, material, v(x, y0 + h / 2, z), UP, extra)
end

-- 강: 불투명한 큰 수면(반사) + 물결 띠 + 등불 빛 반영 줄
local function addRiver(list: { DecorSpec })
	put(list, "RiverWater", "Block", v(1500, 2, 1500), WATER, "SmoothPlastic", v(0, WATER_Y - 1, -80), nil, {
		reflectance = 0.25,
	})
	local rng = MapKitShapes.rng(91)
	for k = 1, 14 do
		local z = 10 - k * 14 + rng:range(-4, 4)
		local w = rng:range(20, 60)
		put(
			list,
			"RiverRipple",
			"Block",
			v(w, 0.1, 0.5),
			MapKitLogic.shade(WATER, 1.6),
			"SmoothPlastic",
			v(rng:range(-30, 30), WATER_Y + 0.05, z)
		)
	end
end

-- 절벽: 바위 덩어리를 비스듬히 겹쳐 쌓아요 (shade 3단)
local function rockRow(list: { DecorSpec }, seed: number, side: number, z0: number, z1: number)
	local rng = MapKitShapes.rng(seed)
	local z = z0
	local k = 0
	while z > z1 do
		local depth = rng:range(20, 32)
		local h = STREET_Y - WATER_Y + rng:range(-3, 6)
		local w = rng:range(26, 40)
		local color = if k % 3 == 0 then ROCK.base elseif k % 3 == 1 then ROCK.dark else ROCK.light
		put(
			list,
			"CliffRock",
			"Block",
			v(w, h, depth),
			color,
			"Slate",
			v(side * (CLIFF_X + w / 2 + rng:range(-3, 3)), WATER_Y - 2 + h / 2, z - depth / 2),
			v(0, rng:range(-8, 8), side * rng:range(0, 5))
		)
		-- 물가 바위 (아래쪽 튀어나온 덩어리)
		local bw = rng:range(10, 18)
		put(
			list,
			"CliffBoulder",
			"Block",
			v(bw, rng:range(8, 16), bw),
			ROCK.dark,
			"Basalt",
			v(side * (CLIFF_X + rng:range(-2, 4)), WATER_Y + 3, z - depth / 2 + rng:range(-6, 6)),
			v(rng:range(-15, 15), rng:range(0, 90), rng:range(-15, 15))
		)
		z -= depth * 0.85
		k += 1
	end
end

local function addValley(list: { DecorSpec })
	rockRow(list, 11, -1, BACK_Z + 30, FAR_Z - 20)
	rockRow(list, 23, 1, BACK_Z + 30, FAR_Z - 20)
	-- 출발 뒤 절벽 (가로)
	local rng = MapKitShapes.rng(37)
	for k = 0, 6 do
		local w = rng:range(24, 34)
		local x = -CLIFF_X - 10 + k * ((2 * CLIFF_X + 20) / 6)
		local color = if k % 2 == 0 then ROCK.base else ROCK.light
		put(
			list,
			"CliffRock",
			"Block",
			v(w, STREET_Y - WATER_Y + 2, 30),
			color,
			"Slate",
			v(x, (STREET_Y + WATER_Y) / 2, BACK_Z + 15),
			v(0, rng:range(-6, 6), 0)
		)
	end
	-- 절벽 위 땅 (축제 거리) 양옆 + 뒤
	local ground = { r = 92, g = 82, b = 76 }
	for _, side in { -1, 1 } do
		put(
			list,
			"StreetGround",
			"Block",
			v(640, 2, 900),
			ground,
			"Cobblestone",
			v(side * (CLIFF_X + 12 + 320), STREET_Y - 1, -80)
		)
		-- 거리 가장자리 나무 난간 (절벽 끝)
		put(
			list,
			"StreetRail",
			"Block",
			v(0.8, 2.4, 230),
			DARK_WOOD,
			"Wood",
			v(side * (CLIFF_X + 10), STREET_Y + 2.2, -82)
		)
		for k = 0, 11 do
			column(
				list,
				"StreetRailPost",
				side * (CLIFF_X + 10),
				STREET_Y,
				BACK_Z + 10 - k * 20,
				3.6,
				1,
				DARK_WOOD,
				"Wood"
			)
		end
	end
	put(
		list,
		"StreetGround",
		"Block",
		v(2 * CLIFF_X + 30, 2, 600),
		ground,
		"Cobblestone",
		v(0, STREET_Y - 1, BACK_Z + 300)
	)
	-- 결승 너머 신사 언덕 (앞면 바위 + 위 땅)
	for k = 0, 6 do
		local w = rng:range(24, 34)
		local x = -CLIFF_X - 10 + k * ((2 * CLIFF_X + 20) / 6)
		put(
			list,
			"CliffRock",
			"Block",
			v(w, STREET_Y - WATER_Y + 8, 30),
			if k % 2 == 0 then ROCK.dark else ROCK.base,
			"Slate",
			v(x, (STREET_Y + WATER_Y) / 2 + 3, FAR_Z - 15),
			v(0, rng:range(-6, 6), 0)
		)
	end
	put(
		list,
		"StreetGround",
		"Block",
		v(2 * CLIFF_X + 30, 2, 600),
		ground,
		"Cobblestone",
		v(0, STREET_Y + 5, FAR_Z - 320)
	)
end

-- 쉼터·출발·결승 아래 바위 받침 기둥 (판정 바닥 아랫면 -2보다 0.2 아래에서 물까지)
local function addSupports(list: { DecorSpec })
	local top = -Layout.FLOOR_THICKNESS - 0.2
	local h = top - WATER_Y + 2
	for _, rest in Layout.RESTS do
		local cz = (rest.front + rest.back) / 2
		column(list, "RestPillar", 0, WATER_Y - 2, cz, h, rest.width - 1, ROCK.base, "Slate")
		append(
			list,
			MapKitShapes.ring(
				"RestPillarBand",
				rest.width / 2 - 0.2,
				0.8,
				1.2,
				12,
				DARK_WOOD,
				"Wood",
				v(0, top - 1.2, cz)
			)
		)
		put(
			list,
			"RestPillarFoot",
			"Cylinder",
			v(4, rest.width + 4, rest.width + 4),
			ROCK.dark,
			"Basalt",
			v(0, WATER_Y + 1, cz),
			UP
		)
	end
	for _, span in
		{
			{ Layout.START.front, Layout.START.back, Layout.START_WIDTH },
			{ Layout.FINISH.front, Layout.FINISH.back, Layout.FINISH_WIDTH },
		}
	do
		local depth = span[1] - span[2]
		local cz = (span[1] + span[2]) / 2
		append(
			list,
			MapKitShapes.roundedBox(
				"PlatformBase",
				v(span[3] - 0.4, h, depth - 0.4),
				ROCK.light,
				"Slate",
				v(0, top - h / 2, cz),
				{
					radius = 1.4,
					style = "vertical",
				}
			)
		)
	end
end

-- 다리 끝 고정 기둥 (쉼터·출발·결승 가장자리, 판자 밖) + 기둥 위 작은 등 (Sway — 기둥은 고정)
local function addBridgePosts(list: { DecorSpec })
	for i, bridge in Layout.BRIDGES do
		for _, endZ in { bridge.front + 0.6, bridge.back - 0.6 } do
			for _, side in { -1, 1 } do
				local x = side * (bridge.halfWidth + 0.7)
				column(list, "BridgePost", x, -0.2, endZ, 4.2, 0.9, DARK_WOOD, "Wood")
				put(list, "BridgePostCap", "Ball", v(1.2, 1.2, 1.2), DARK_WOOD, "Wood", v(x, 4.1, endZ))
				put(
					list,
					"BridgePostLamp",
					"Ball",
					v(1, 1.3, 1),
					PAPER,
					"Neon",
					v(x, 3.2, endZ + (if endZ > bridge.front - 1 then 0.6 else -0.6)),
					nil,
					{
						anim = { kind = "Sway", period = 2.4 + (i % 3) * 0.3, amount = 8, axis = "X" },
					}
				)
			end
		end
	end
end

-- 강 위를 가로지르는 등불 줄 (높이 20, 양쪽 절벽 기둥에 묶음). 줄마다 가운데 등 하나에만 빛.
local function addLanternStrings(list: { DecorSpec })
	local colors = { LANTERN_GLOW, TORII, PAPER }
	for s, z in { -40, -72, -104, -136 } do
		local y = 22 + (s % 2) * 2
		put(list, "StringWire", "Block", v(2 * CLIFF_X + 20, 0.2, 0.2), DARK_WOOD, "Fabric", v(0, y + 1, z))
		for _, side in { -1, 1 } do
			column(list, "StringPole", side * (CLIFF_X + 10), STREET_Y, z, y + 3 - STREET_Y, 1.2, DARK_WOOD, "Wood")
		end
		for k = -6, 6 do
			local x = k * 9
			put(
				list,
				"StringLantern",
				"Ball",
				v(2.6, 3.2, 2.6),
				colors[(k + s) % 3 + 1],
				"Neon",
				v(x, y - 0.6, z),
				nil,
				{
					anim = { kind = "Sway", period = 3 + ((k + s) % 4) * 0.4, amount = 6, axis = "X" },
				}
			)
			put(
				list,
				"StringLanternCap",
				"Cylinder",
				v(0.3, 1.4, 1.4),
				MapKitLogic.PALETTE.Nori,
				"SmoothPlastic",
				v(x, y + 1.1, z),
				UP
			)
		end
	end
end

-- 떠내려가는 등롱 (Bob) + 물에 비친 빛 줄
local function addFloatingLanterns(list: { DecorSpec })
	local rng = MapKitShapes.rng(57)
	for k = 1, 22 do
		local x = rng:range(-44, 44)
		local z = 30 - k * 9 + rng:range(-3, 3)
		local bob = { anim = { kind = "Bob", period = 3 + rng:range(0, 2.5), amount = 0.5 } } :: Extra
		put(
			list,
			"TouroBase",
			"Block",
			v(3.4, 0.8, 3.4),
			DARK_WOOD,
			"Wood",
			v(x, WATER_Y + 0.4, z),
			v(0, rng:range(0, 90), 0),
			bob
		)
		put(
			list,
			"TouroPaper",
			"Block",
			v(2.6, 2.8, 2.6),
			if k % 4 == 0 then TORII else PAPER,
			"Neon",
			v(x, WATER_Y + 2.2, z),
			v(0, rng:range(0, 90), 0),
			bob
		)
		put(
			list,
			"TouroReflection",
			"Block",
			v(1.6, 0.06, 7),
			LANTERN_GLOW,
			"Neon",
			v(x, WATER_Y + 0.08, z + 4),
			nil,
			{ transparency = 0.55 }
		)
	end
end

-- 절벽 위 노점 (야타이): 판매대 + 줄무늬 차양 + 노렌 + 등 (노점마다 빛 하나)
local function addStall(list: { DecorSpec }, x: number, z: number, side: number, colorA: RGB)
	local parts: { DecorSpec } = {}
	append(
		parts,
		MapKitShapes.roundedBox(
			"StallCounter",
			v(14, 7, 6),
			DARK_WOOD,
			"Wood",
			v(0, STREET_Y + 3.5, 0),
			{ radius = 0.8, style = "vertical" }
		)
	)
	put(parts, "StallTop", "Block", v(15, 0.6, 7), MapKitLogic.PALETTE.WoodLight, "Wood", v(0, STREET_Y + 7.3, 0))
	for _, sx in { -1, 1 } do
		column(parts, "StallPost", sx * 6.8, STREET_Y, 3, 16, 0.8, DARK_WOOD, "Wood")
	end
	for k = 0, 6 do
		put(
			parts,
			"StallAwning",
			"Wedge",
			v(2.2, 2.6, 7),
			if k % 2 == 0 then colorA else PAPER,
			"Fabric",
			v(-6.6 + k * 2.2, STREET_Y + 17.3, -0.5),
			v(0, 180, 0)
		)
	end
	for k = -2, 2 do
		put(
			parts,
			"StallNoren",
			"Block",
			v(2.6, 4, 0.3),
			MapKitLogic.PALETTE.Noren,
			"Fabric",
			v(k * 2.8, STREET_Y + 14, -3.6)
		)
	end
	put(parts, "StallLantern", "Ball", v(3, 3.8, 3), LANTERN_GLOW, "Neon", v(-4, STREET_Y + 11.5, -4.2), nil, {
		light = { kind = "Point", color = LANTERN_GLOW, brightness = 1.6, range = 24 },
		anim = { kind = "Sway", period = 3.2, amount = 6, axis = "X" },
	})
	put(parts, "StallLanternB", "Ball", v(2.6, 3.2, 2.6), TORII, "Neon", v(4, STREET_Y + 11.6, -4.2), nil, {
		anim = { kind = "Sway", period = 2.8, amount = 6, axis = "X" },
	})
	-- 판매대 위 음식 (빙수·사과사탕·꼬치)
	put(
		parts,
		"StallFood",
		"Ball",
		v(2, 2, 2),
		{ r = 220, g = 40, b = 50 },
		"SmoothPlastic",
		v(-3, STREET_Y + 8.6, -1),
		nil,
		{ reflectance = 0.2 }
	)
	put(
		parts,
		"StallFood",
		"Ball",
		v(2, 2, 2),
		{ r = 220, g = 40, b = 50 },
		"SmoothPlastic",
		v(-0.6, STREET_Y + 8.6, -1),
		nil,
		{ reflectance = 0.2 }
	)
	put(
		parts,
		"StallFood",
		"Cylinder",
		v(2.4, 2.6, 2.6),
		{ r = 150, g = 210, b = 255 },
		"SmoothPlastic",
		v(3, STREET_Y + 8.8, -1),
		UP
	)
	-- side -1(왼쪽 절벽)이면 +X(강 쪽)를 보게
	append(list, MapKitShapes.transform(parts, v(x, 0, z), v(0, if side < 0 then -90 else 90, 0)))
end

local function addStreet(list: { DecorSpec })
	local colors = {
		TORII,
		{ r = 60, g = 110, b = 190 },
		{ r = 240, g = 150, b = 40 },
		{ r = 90, g = 160, b = 90 },
		{ r = 210, g = 90, b = 150 },
	}
	for k = 0, 4 do
		local z = 10 - k * 40
		addStall(list, -(CLIFF_X + 22), z, -1, colors[k % 5 + 1])
		addStall(list, CLIFF_X + 22, z - 20, 1, colors[(k + 2) % 5 + 1])
	end
	-- 노점 뒤 소나무 (원뿔 3단)
	local rng = MapKitShapes.rng(71)
	for k = 1, 14 do
		local side = if k % 2 == 0 then -1 else 1
		local x = side * (CLIFF_X + 46 + rng:range(0, 40))
		local z = 40 - k * 16 + rng:range(-5, 5)
		local s = rng:range(0.8, 1.3)
		column(list, "PineTrunk", x, STREET_Y, z, 14 * s, 2.6 * s, DARK_WOOD, "Wood")
		for t = 0, 2 do
			local d = (22 - t * 6) * s
			column(
				list,
				"PineLeaves",
				x,
				STREET_Y + (10 + t * 9) * s,
				z,
				10 * s,
				d,
				if t == 1 then PINE.light else PINE.base,
				"Grass"
			)
		end
	end
end

-- 먼 신사 (BG): 돌계단 + 빨간 기둥 + 큰 지붕 + 그 앞 도리이, 옆 불꽃 망루
local function addShrine(list: { DecorSpec })
	local baseY = STREET_Y + 6
	local z = FAR_Z - 110
	append(
		list,
		MapKitShapes.roundedBox(
			"ShrinePlinth",
			v(110, 10, 70),
			ROCK.light,
			"Slate",
			v(0, baseY + 5, z),
			{ radius = 2, style = "vertical" }
		)
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(list, "ShrinePillar", sx * 40, baseY + 10, z + sz * 22, 34, 4, TORII, "Wood")
		end
	end
	put(list, "ShrineHall", "Block", v(76, 30, 40), { r = 120, g = 40, b = 34 }, "Wood", v(0, baseY + 25, z))
	put(
		list,
		"ShrineHallLight",
		"Block",
		v(30, 12, 0.4),
		PAPER,
		"Neon",
		v(0, baseY + 22, z + 20.4),
		nil,
		{ transparency = 0.2 }
	)
	put(
		list,
		"ShrineRoof",
		"Wedge",
		v(120, 26, 40),
		{ r = 40, g = 44, b = 60 },
		"Slate",
		v(0, baseY + 57, z + 20),
		v(0, 180, 0)
	)
	put(list, "ShrineRoof", "Wedge", v(120, 26, 40), { r = 34, g = 38, b = 54 }, "Slate", v(0, baseY + 57, z - 20))
	put(list, "ShrineRoofEave", "Block", v(124, 3, 84), { r = 30, g = 32, b = 44 }, "Slate", v(0, baseY + 43, z))
	-- 신사 앞 큰 도리이
	local tz = FAR_Z - 50
	for _, sx in { -1, 1 } do
		column(list, "FarToriiPillar", sx * 22, baseY, tz, 46, 4, TORII, "Wood")
	end
	put(list, "FarToriiBeam", "Block", v(60, 4, 5), TORII, "Wood", v(0, baseY + 47, tz))
	put(list, "FarToriiBeam", "Block", v(50, 3, 3.6), MapKitLogic.PALETTE.Nori, "Wood", v(0, baseY + 39, tz))
	-- 돌계단 (언덕 앞면 → 신사)
	for k = 0, 5 do
		put(
			list,
			"ShrineStep",
			"Block",
			v(30, 1.2, 4),
			ROCK.light,
			"Slate",
			v(0, baseY - 5 + k * 1.2, FAR_Z - 32 - k * 3)
		)
	end
	-- 불꽃 망루 + 하늘의 불꽃 (정지 장면)
	local fx, fz = 120, FAR_Z - 160
	column(list, "FireworkTower", fx, baseY, fz, 70, 5, DARK_WOOD, "Wood")
	put(list, "FireworkTowerTop", "Block", v(14, 3, 14), DARK_WOOD, "Wood", v(fx, baseY + 71, fz))
	local bursts = {
		{ x = 60, y = 150, z = -420, c = { r = 255, g = 120, b = 160 } },
		{ x = -120, y = 175, z = -480, c = { r = 120, g = 220, b = 255 } },
		{ x = 170, y = 190, z = -520, c = { r = 255, g = 210, b = 90 } },
	}
	for b, burst in bursts do
		put(list, "FireworkCore", "Ball", v(8, 8, 8), burst.c, "Neon", v(burst.x, burst.y, burst.z), nil, {
			particle = "Sparkle",
			particleRate = 10,
			anim = { kind = "Pulse", period = 2 + b * 0.5, amount = 0.15 },
		})
		for k = 0, 11 do
			local a = math.rad(k * 30)
			local r = 28
			put(
				list,
				"FireworkStreak",
				"Block",
				v(r, 1.4, 1.4),
				burst.c,
				"Neon",
				v(burst.x + math.cos(a) * r * 0.75, burst.y + math.sin(a) * r * 0.75, burst.z),
				v(0, 0, k * 30)
			)
		end
	end
end

-- 먼 산 실루엣 + 달
local function addSky(list: { DecorSpec })
	local mountain = MapKitLogic.shades({ r = 30, g = 36, b = 66 })
	for k = 0, 15 do
		local a = math.rad(k * 22.5 + 5)
		local d = 300 + (k % 3) * 80
		local c = if k % 3 == 0 then mountain.base elseif k % 3 == 1 then mountain.dark else mountain.light
		put(
			list,
			"FarMountain",
			"Ball",
			v(d, d, d),
			c,
			"Rock",
			v(math.cos(a) * 760, STREET_Y - d * 0.2, -80 + math.sin(a) * 760)
		)
	end
	put(list, "Moon", "Ball", v(60, 60, 60), { r = 250, g = 244, b = 214 }, "Neon", v(-260, 320, -700))
end

-- 쉼터 석등 불씨 + 고정 SpotLight(그림자 1) + 반딧불
local function addRestGlow(list: { DecorSpec })
	for i, rest in Layout.RESTS do
		local lampX, lampZ = rest.width / 2 - 1.8, rest.front - 2.5
		put(list, "StoneLanternFire", "Block", v(1, 1, 1), LANTERN_GLOW, "Neon", v(lampX, 2.8, lampZ), nil, {
			particle = "Embers",
			particleRate = 3,
		})
		if i == 2 then
			put(list, "RestSpotLamp", "Block", v(0.6, 0.6, 0.6), LANTERN_GLOW, "Neon", v(lampX, 4.5, lampZ), nil, {
				light = {
					kind = "Spot",
					color = LANTERN_GLOW,
					brightness = 2.4,
					range = 30,
					angle = 100,
					face = "Bottom",
					shadows = true,
				},
			})
		end
		put(
			list,
			"Fireflies",
			"Block",
			v(0.3, 0.3, 0.3),
			{ r = 220, g = 255, b = 140 },
			"SmoothPlastic",
			v(-rest.width / 2 - 6, 3, (rest.front + rest.back) / 2),
			nil,
			{
				particle = "Sparkle",
				particleRate = 3,
				transparency = 1,
			}
		)
	end
end

-- 입구 도리이 보강: 기둥 아래 검은 받침 + 위 보 양끝 휘어진 끝(쐐기) + 현판
local function addToriiDetail(list: { DecorSpec })
	local z = Layout.START.front - 2
	for _, side in { -1, 1 } do
		column(list, "ToriiFoot", side * 7, 0, z, 1.4, 2, MapKitLogic.PALETTE.Nori, "Wood")
		put(
			list,
			"ToriiBeamTip",
			"Wedge",
			v(2.4, 1.2, 2.4),
			PALETTE.Lacquer,
			"Wood",
			v(side * 9.6, 16.8, z),
			v(0, side * 90, 0)
		)
	end
	put(list, "ToriiBeamCap", "Block", v(20, 0.8, 2.8), MapKitLogic.PALETTE.Nori, "Wood", v(0, 16.6, z))
	put(list, "ToriiPlaque", "Block", v(3, 3.6, 0.5), MapKitLogic.PALETTE.Nori, "Wood", v(0, 13.9, z + 0.9))
	put(
		list,
		"ToriiPlaqueText",
		"Block",
		v(2, 2.6, 0.2),
		{ r = 230, g = 190, b = 90 },
		"SmoothPlastic",
		v(0, 13.9, z + 1.2)
	)
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addTorii(list)
	for order, bridge in Layout.BRIDGES do
		addBridgeDecor(list, bridge, order)
	end
	for _, rest in Layout.RESTS do
		addRestDecor(list, rest)
	end
	addFinishGate(list)
	-- m5-24
	addToriiDetail(list)
	addRiver(list)
	addValley(list)
	addSupports(list)
	addBridgePosts(list)
	addLanternStrings(list)
	addFloatingLanterns(list)
	addStreet(list)
	addShrine(list)
	addSky(list)
	addRestGlow(list)
	return list
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- ① 출발 뒤 절벽 위 넓은 샷(도리이·계곡·등불 줄) ② 다리 2 흔들림 클로즈업 ③ 결승에서 돌아보는 반전 샷
-- ④ 출발 자리 뒤에서 도리이 너머 코스 방향 (경유점은 판정 경계 +40 안)
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(-10, 32, 36), lookAt = v(0, 0, -50) },
		{ pos = v(12, 9, -46), lookAt = v(0, 0, -64) },
		{ pos = v(-12, 14, -150), lookAt = v(0, -2, -112) },
		{ pos = v(0, 8, 12), lookAt = v(0, 3, -24) },
	}
end

return Art
