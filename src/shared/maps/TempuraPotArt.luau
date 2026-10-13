--!strict
-- "튀김 냄비 탈출" 아트 데이터 (m5-05). Roblox API를 쓰지 않아요 — lune 테스트·렌더러에서 바로 불러요.
-- 아트 디렉션 "밤의 주방, 불 위의 무쇠 튀김 냄비" (스펙 "### 아트", docs/REFERENCE-map-art-direction.md).
-- 판정 지오메트리(냄비 벽·바구니·발판·기름)는 TempuraPotLayout 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   TempuraPotArt.decor() -> { DecorSpec }          Extended 예산 (BUDGET)
--   TempuraPotArt.introCamera() -> { IntroPoint }    카운터 높이 넓은 샷 → 꼭대기 발판 → 꼭대기에서 내려다보기 → 바구니
--   TempuraPotArt.LIGHTING                           맵 조명 프리셋 (밤 21시, 청색 Ambient, 따뜻한 연기)
--   TempuraPotArt.COLORS / raftColor(kind, tier)     판정 파츠 색 (TempuraPot.build가 써요, 높은 층일수록 밝게)
--   TempuraPotArt.OIL_GLOWS                          기름 표면을 따라 올라가는 주황 빛 자리 (build가 붙여요)
--
-- 층 (가이드 2절): FG = 냄비 림·손잡이·온도계, 발판 옆·아래 튀김옷 돌기·새우 꼬리·고구마 껍질·깻잎
--                 MG = 가스레인지(불꽃 고리·삼발이), 긴 조리 젓가락, 레인지 후드·램프, 튀김 접시·튀김 망
--                 BG = 주방 바닥(−108, 낙하 안전망 −15보다 한참 아래), 타일 벽·창문(밤하늘·달), 찬장·선반·냉장고
-- 좌표는 냄비 중심 기준으로 쓰고 P()로 origin 로컬로 옮겨요. 냄비 중심 = Layout.POT_CENTER_X/Z.

local Layout = require(script.Parent.TempuraPotLayout)
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

-- 색 (60 = 무쇠·청회색 주방, 30 = 금빛 기름·튀김, 10 = 불꽃·경고 주황 + 창빛 파랑)
local IRON = PAL.CastIron
local IRON_LIGHT = shade(PAL.CastIron, 1.45)
local IRON_DARK = shade(PAL.CastIron, 0.7)
local STEEL = PAL.Steel
local STEEL_DARK = shade(PAL.Steel, 0.62)
local STEEL_LIGHT = shade(PAL.Steel, 1.12)
local GOLD = PAL.TempuraGold
local BATTER = PAL.Batter
local WALL = c(66, 68, 84) -- 어두운 청회색 벽
local WALL_DARK = c(40, 46, 60)
local TILE_A = c(92, 112, 134)
local TILE_B = c(80, 98, 120)
local TILE_C = c(104, 124, 146)
local FLOOR_A = c(118, 84, 58) -- 따뜻한 나무 마루
local FLOOR_B = c(98, 68, 46)
local WOOD = shade(PAL.Wood, 0.85)
local WOOD_LIGHT = PAL.WoodLight
local WOOD_DARK = PAL.WoodDark
local CABINET = c(74, 86, 98)
local CABINET_DARK = c(56, 66, 78)
local FLAME_BLUE = c(90, 160, 255)
local FLAME_CORE = c(190, 230, 255)
local NIGHT = c(22, 30, 64)
local MOON = c(250, 244, 214)
local SHRIMP_TAIL = c(240, 130, 84)
local SKIN = c(104, 56, 100) -- 고구마 껍질 자주
local LEAF = PAL.Shiso
local PORCELAIN = PAL.Porcelain
local PAPER = c(246, 240, 226)

Art.COLORS = {
	pot = IRON,
	oil = c(240, 182, 52),
	oilDeep = c(176, 104, 24),
	basket = c(206, 190, 150), -- 놋쇠빛 철망 바구니
	shrimp = c(244, 186, 84),
	sweetPotato = c(236, 176, 80),
	shiso = mix(GOLD, BATTER, 0.25),
	warn = c(255, 96, 24),
	splash = c(255, 210, 90),
}

-- 발판 색: 층이 높을수록 한 shade씩 밝게 ("위가 안전"이 읽히게, 스펙 아트)
function Art.raftColor(kind: string, tier: number): RGB
	if kind == "Basket" then
		return Art.COLORS.basket
	end
	local base = if kind == "Shrimp"
		then Art.COLORS.shrimp
		elseif kind == "Shiso" then Art.COLORS.shiso
		else Art.COLORS.sweetPotato
	local factor = 0.98 + 0.035 * tier -- 1.015(7층) → 1.225(31층)
	return shade(base, factor)
end

-- 기름 표면을 따라 올라가는 주황 빛 (냄비 중심 기준 수평 자리, 표면 위 높이). build가 투명 파츠에 PointLight로.
Art.OIL_GLOWS = {
	{ x = 0, z = 0 },
	{ x = 18, z = 10 },
	{ x = -16, z = -12 },
}
Art.OIL_GLOW_LIGHT = { kind = "Point", color = c(255, 150, 50), brightness = 2.2, range = 40 } :: LightSpec

-- 맵 조명: 밤 21시, 낮은 청색 Ambient, 따뜻한 연기빛 Atmosphere, 기름·불꽃이 Bloom으로 번지게
Art.LIGHTING = {
	ClockTime = 21,
	Brightness = 1.6,
	Ambient = c(74, 68, 82),
	OutdoorAmbient = c(80, 84, 110),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.9,
	ExposureCompensation = 0.65,
	Atmosphere = {
		Density = 0.35,
		Offset = 0.05,
		Color = c(120, 100, 92),
		Decay = c(60, 52, 70),
		Glare = 0,
		Haze = 1.5,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.1, TintColor = c(255, 240, 222) },
	Bloom = { Intensity = 0.6, Size = 26, Threshold = 0.95 },
	SunRays = { Intensity = 0, Spread = 0.5 },
} :: MapLighting.LightingPreset

local CX, CZ = Layout.POT_CENTER_X, Layout.POT_CENTER_Z
local R = Layout.POT_INNER_RADIUS
local WALL_T = Layout.POT_WALL_THICKNESS
local RIM_Y = Layout.POT_WALL_TOP_Y

-- 주방 높이 (origin 로컬 y). 가스레인지 상판은 낙하 안전망(−15)보다 10 이상 아래.
local STOVE_TOP = -26
local FLOOR_Y = -108
local BACK_Z = -100 -- 냄비 중심 기준 뒤 벽
local SIDE_X = 320

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 냄비 중심 기준 → origin 로컬
local function P(x: number, y: number, z: number): Vec3
	return { x = CX + x, y = y, z = CZ + z }
end

-- 각도(도, +X에서 -Z 쪽으로)·반지름 → 냄비 중심 기준 (x, z)
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
	local spec: DecorSpec = {
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
	table.insert(list, spec)
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
			if extra.anim then
				s.anim = extra.anim
			end
		end
		table.insert(list, s)
	end
end

-- 기울어진 막대(캡슐)의 중심·회전: 냄비 중심 기준 a → b
local function stick(
	list: { DecorSpec },
	name: string,
	a: Vec3,
	b: Vec3,
	diameter: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local horizontal = math.sqrt(dx * dx + dz * dz)
	local length = math.sqrt(horizontal * horizontal + dy * dy)
	local yaw = math.deg(math.atan2(-dz, dx))
	local roll = math.deg(math.atan2(dy, horizontal))
	local specs = MapKitShapes.capsule(
		name,
		length,
		diameter,
		color,
		material,
		P((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2),
		v(0, yaw, roll)
	)
	addAll(list, specs, extra)
end

---------------------------------------------------------------- FG: 냄비

local function addPot(list: { DecorSpec })
	local mid = R + WALL_T / 2
	-- 두꺼운 무쇠 림 (벽 위) + 바깥 띠 두 줄 + 바닥 굽
	addAll(
		list,
		MapKitShapes.ring("PotRim", mid, WALL_T + 1.6, 1.8, 40, IRON_LIGHT, "Metal", P(0, RIM_Y + 0.9, 0)),
		{ reflectance = 0.2 }
	)
	addAll(
		list,
		MapKitShapes.ring("PotBand", R + WALL_T + 0.5, 1, 2.4, 28, IRON_DARK, "Metal", P(0, RIM_Y - 4, 0)),
		{ reflectance = 0.1 }
	)
	addAll(
		list,
		MapKitShapes.ring("PotBand", R + WALL_T + 0.5, 1, 2, 28, IRON_DARK, "Metal", P(0, 8, 0)),
		{ reflectance = 0.1 }
	)
	addAll(
		list,
		MapKitShapes.ring(
			"PotFoot",
			R + WALL_T - 1,
			3,
			1.6,
			32,
			IRON_DARK,
			"CorrodedMetal",
			P(0, Layout.POT_FLOOR_Y - 2.6, 0)
		)
	)
	-- 귀 손잡이 2개 (좌우): 무쇠 받침 + 나무 손잡이
	for _, side in { -1, 1 } do
		local x = side * (R + WALL_T + 5)
		for _, dz in { -6, 6 } do
			add(
				list,
				"PotEar",
				"Block",
				v(7, 2, 2),
				IRON,
				"Metal",
				P(side * (R + WALL_T + 2.5), RIM_Y - 7, dz),
				{ reflectance = 0.15 }
			)
		end
		addAll(list, MapKitShapes.capsule("PotHandle", 16, 3.2, WOOD_DARK, "Wood", P(x, RIM_Y - 7, 0), v(0, 90, 0)))
		add(
			list,
			"PotHandleRing",
			"Cylinder",
			v(0.6, 3.6, 3.6),
			IRON_DARK,
			"Metal",
			P(x, RIM_Y - 7, -6.6),
			{ rotation = v(0, 90, 0) }
		)
		add(
			list,
			"PotHandleRing",
			"Cylinder",
			v(0.6, 3.6, 3.6),
			IRON_DARK,
			"Metal",
			P(x, RIM_Y - 7, 6.6),
			{ rotation = v(0, 90, 0) }
		)
	end
	-- 튀김 온도계: 림에 꽂힌 집게 + 기름 속으로 내려가는 막대 + 둥근 눈금판 (앞 오른쪽, 바깥 줄 발판이 없는 각도)
	local ta = -62
	local tx, tz = pol(ta, R - 1.5)
	local ox, oz = pol(ta, R + WALL_T + 1)
	add(list, "ThermoClip", "Block", v(3, 4, 4.5), STEEL, "Metal", P((tx + ox) / 2, RIM_Y + 1, (tz + oz) / 2), {
		rotation = v(0, ta, 0),
		reflectance = 0.25,
	})
	addAll(
		list,
		MapKitShapes.capsule("ThermoProbe", 44, 0.8, STEEL_LIGHT, "Metal", P(tx, RIM_Y - 18, tz), UPRIGHT),
		{ reflectance = 0.3 }
	)
	addAll(
		list,
		MapKitShapes.rimDisc("ThermoDial", 9, 1, c(250, 248, 240), "SmoothPlastic", P(tx, RIM_Y + 8, tz), {
			rimColor = STEEL,
			rimWidth = 0.8,
			segments = 14,
			rotation = v(90, 0, ta + 90),
		})
	)
	add(list, "ThermoNeedle", "Block", v(0.4, 3.4, 0.3), c(40, 40, 46), "SmoothPlastic", P(tx, RIM_Y + 9, tz), {
		rotation = v(0, -ta - 90, 30),
	})
end

---------------------------------------------------------------- FG: 발판 튀김옷

local function bumpsAround(
	list: { DecorSpec },
	raft: Layout.Raft,
	count: number,
	size: number,
	y: number,
	inset: number
)
	for i = 0, count - 1 do
		local t = i / count
		local x: number, z: number
		if raft.shape == "Disc" then
			local a = t * 2 * math.pi + raft.topY * 0.37
			local r = raft.radius - inset
			x, z = raft.x + r * math.cos(a), raft.z + r * math.sin(a)
		else
			-- 직사각형 둘레를 따라 (로컬 → yaw)
			local hx, hz = raft.length / 2 - inset, raft.width / 2 - inset
			local perimeter = 4 * (hx + hz)
			local d = t * perimeter
			local lx: number, lz: number
			if d < 2 * hx then
				lx, lz = -hx + d, hz
			elseif d < 2 * hx + 2 * hz then
				lx, lz = hx, hz - (d - 2 * hx)
			elseif d < 4 * hx + 2 * hz then
				lx, lz = hx - (d - 2 * hx - 2 * hz), -hz
			else
				lx, lz = -hx, -hz + (d - 4 * hx - 2 * hz)
			end
			local rad = math.rad(raft.yaw)
			x = raft.x + lx * math.cos(rad) + lz * math.sin(rad)
			z = raft.z - lx * math.sin(rad) + lz * math.cos(rad)
		end
		local s = size * (0.85 + 0.3 * ((i * 7) % 5) / 4)
		local col = if i % 3 == 0 then BATTER elseif i % 3 == 1 then mix(BATTER, GOLD, 0.5) else shade(GOLD, 1.05)
		add(list, "BatterBump", "Ball", v(s, s, s), col, "Sand", v(x, y, z), { castShadow = false })
	end
end

local function addRaftDecor(list: { DecorSpec })
	local thick = Layout.RAFT_THICKNESS
	for _, raft in Layout.rafts() do
		local top = raft.topY
		local mid = top - thick / 2
		if raft.kind == "SweetPotato" then
			-- 자주색 껍질 테두리 (윗면보다 0.15 낮게, 바깥으로 0.4) + 아래쪽 튀김옷 돌기
			addAll(
				list,
				MapKitShapes.ring(
					"SweetPotatoSkin",
					raft.radius + 0.2,
					0.5,
					thick - 0.1,
					12,
					SKIN,
					"Plastic",
					v(raft.x, mid - 0.1, raft.z)
				),
				{ castShadow = false }
			)
			bumpsAround(
				list,
				raft,
				math.max(5, math.floor(raft.radius * 1.6)),
				1.2,
				top - thick - 0.2,
				raft.radius * 0.45
			)
		elseif raft.kind == "Shrimp" then
			bumpsAround(list, raft, 14, 1.25, mid - 0.1, -0.15)
			-- 꼬리: 접선 방향 한쪽 끝에서 비스듬히 아래로 (주황-빨강 부채 2장)
			local rad = math.rad(raft.yaw)
			local ex, ez = math.cos(rad), -math.sin(rad)
			local half = raft.length / 2
			for k, spread in { -18, 18 } do
				add(
					list,
					"ShrimpTail",
					"Wedge",
					v(1.2, 2, 2.6),
					if k == 1 then SHRIMP_TAIL else shade(SHRIMP_TAIL, 0.85),
					"SmoothPlastic",
					v(raft.x + ex * (half + 1.3), top - 1.1, raft.z + ez * (half + 1.3)),
					{ rotation = v(0, raft.yaw + 90 + spread, -20), castShadow = false }
				)
			end
		elseif raft.kind == "Shiso" then
			-- 튀김옷 아래로 삐죽 나온 깻잎 (밟는 윗면보다 1.75 낮게) + 옆면 돌기
			add(
				list,
				"ShisoLeaf",
				"Block",
				v(raft.length + 1.6, 0.25, raft.width + 1.2),
				LEAF,
				"Fabric",
				v(raft.x, top - thick - 0.2, raft.z),
				{ rotation = v(0, raft.yaw + 6, 0), castShadow = false }
			)
			bumpsAround(list, raft, 12, 1.2, mid - 0.1, -0.1)
		end
	end
	-- 바구니(철망 튀김 바구니): 테두리 고리 + 다리 4
	local basket = Layout.basket()
	addAll(
		list,
		MapKitShapes.ring(
			"BasketRim",
			basket.radius + 0.4,
			0.9,
			1.6,
			28,
			STEEL_LIGHT,
			"Metal",
			v(basket.x, basket.topY - 0.95, basket.z)
		),
		{ reflectance = 0.3 }
	)
	for i = 0, 3 do
		local x, z = pol(45 + i * 90, basket.radius * 0.7)
		add(
			list,
			"BasketLeg",
			"Cylinder",
			v(10.5, 1.2, 1.2),
			STEEL_DARK,
			"Metal",
			P(x, -3.8, z),
			{ rotation = UPRIGHT }
		)
	end
end

---------------------------------------------------------------- MG: 가스레인지·불꽃

local function addBurner(list: { DecorSpec }, x: number, z: number, radius: number, withLight: boolean, flames: number)
	local headY = STOVE_TOP + 1.5
	add(list, "BurnerHead", "Cylinder", v(3, radius * 1.7, radius * 1.7), IRON_DARK, "Metal", P(x, headY, z), {
		rotation = UPRIGHT,
		reflectance = 0.1,
	})
	addAll(
		list,
		MapKitShapes.ring(
			"BurnerCap",
			radius * 0.85,
			1.2,
			1,
			if radius > 15 then 14 else 8,
			STEEL_DARK,
			"Metal",
			P(x, headY + 1.8, z)
		)
	)
	for i = 0, flames - 1 do
		local a = i * 360 / flames
		local fx, fz = pol(a, radius * 0.95)
		local isLight = withLight and (i == 0 or i == math.floor(flames / 2))
		add(
			list,
			"Flame",
			"Ball",
			v(2.2, 2.2, 2.2),
			if i % 2 == 0 then FLAME_BLUE else FLAME_CORE,
			"Neon",
			P(x + fx, headY + 3.4, z + fz),
			{
				castShadow = false,
				light = if isLight
					then { kind = "Point", color = c(110, 170, 255), brightness = 2.5, range = 30 }
					else nil,
				anim = if i % 3 == 0 then { kind = "Pulse", period = 1.6 + (i % 4) * 0.3, amount = 0.12 } else nil,
			}
		)
	end
end

-- 삼발이: 바깥 고리 + 바큇살 6개 (윗면이 냄비 바닥 바로 밑)
local function addGrate(list: { DecorSpec }, x: number, z: number, outer: number, inner: number, topY: number)
	addAll(
		list,
		MapKitShapes.ring(
			"Grate",
			outer,
			2,
			2,
			if outer > 30 then 28 else 12,
			IRON,
			"CorrodedMetal",
			P(x, STOVE_TOP + 1.5, z)
		)
	)
	for i = 0, 5 do
		local a = i * 60 + 15
		local mx, mz = pol(a, (outer + inner) / 2)
		add(
			list,
			"GrateArm",
			"Block",
			v(outer - inner, 2, 2),
			IRON_LIGHT,
			"Metal",
			P(x + mx, topY - 1, z + mz),
			{ rotation = v(0, a, 0) }
		)
		local lx, lz = pol(a, outer)
		add(
			list,
			"GrateLeg",
			"Block",
			v(2, topY - STOVE_TOP, 2),
			IRON,
			"Metal",
			P(x + lx, (topY + STOVE_TOP) / 2, z + lz),
			{
				rotation = v(0, a, 0),
			}
		)
	end
end

local RANGE_X = 140
local RANGE_FRONT = 78
local RANGE_BACK = -96

local function addRange(list: { DecorSpec })
	local width = RANGE_X * 2
	local depth = RANGE_FRONT - RANGE_BACK
	local zc = (RANGE_FRONT + RANGE_BACK) / 2
	-- 상판 (스테인리스, 둥근 세로 모서리) + 몸통
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RangeTop",
			v(width, 4, depth),
			STEEL_DARK,
			"Metal",
			P(0, STOVE_TOP - 2, zc),
			{ radius = 1.6 }
		),
		{ reflectance = 0.25 }
	)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RangeBody",
			v(width - 4, STOVE_TOP - FLOOR_Y - 4, depth - 6),
			shade(STEEL, 0.8),
			"Metal",
			P(0, (STOVE_TOP - 4 + FLOOR_Y) / 2, zc - 2),
			{
				style = "vertical",
				radius = 2,
			}
		),
		{ reflectance = 0.15 }
	)
	-- 앞판: 손잡이 레일, 오븐 문 2개, 손잡이 노브 5개
	local front = RANGE_FRONT - 4.5
	addAll(
		list,
		MapKitShapes.capsule("RangeRail", width - 16, 2.4, STEEL_LIGHT, "Metal", P(0, STOVE_TOP - 9, front + 2), nil),
		{ reflectance = 0.35 }
	)
	for i, dx in { -60, 60 } do
		addAll(
			list,
			MapKitShapes.bevelBox(
				`OvenDoor{i}`,
				v(110, 46, 2),
				shade(STEEL, 0.92),
				"Metal",
				P(dx, -66, front + 0.6),
				0.8
			),
			{ reflectance = 0.2 }
		)
		add(
			list,
			"OvenWindow",
			"Block",
			v(70, 18, 0.4),
			c(30, 30, 36),
			"Glass",
			P(dx, -62, front + 1.8),
			{ reflectance = 0.3 }
		)
		addAll(
			list,
			MapKitShapes.capsule("OvenHandle", 80, 2, STEEL_LIGHT, "Metal", P(dx, -44, front + 3.4), nil),
			{ reflectance = 0.35 }
		)
	end
	for i = 0, 4 do
		local kx = -84 + i * 42
		add(
			list,
			"Knob",
			"Cylinder",
			v(2.4, 6, 6),
			c(30, 30, 34),
			"SmoothPlastic",
			P(kx, STOVE_TOP - 18, front + 1.6),
			{ rotation = v(0, 90, 0) }
		)
		add(
			list,
			"KnobTick",
			"Block",
			v(0.6, 2.4, 0.4),
			STEEL_LIGHT,
			"SmoothPlastic",
			P(kx, STOVE_TOP - 16.8, front + 2.9)
		)
	end
	-- 걸레받이 (바닥과 닿는 곳)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"RangeKick",
			v(width - 4, 1, depth - 6),
			1,
			6,
			c(30, 30, 34),
			"Metal",
			P(0, FLOOR_Y + 3, zc - 2)
		)
	)

	-- 가운데: 냄비 밑 큰 화구 + 삼발이 (냄비 테두리 밖으로 보이게 바깥 고리 44)
	addBurner(list, 0, 0, 24, true, 16)
	addGrate(list, 0, 0, 44, 14, Layout.POT_FLOOR_Y - 2)
	-- 왼쪽 화구: 김 오르는 작은 냄비
	addBurner(list, -98, -22, 12, false, 8)
	addGrate(list, -98, -22, 22, 6, STOVE_TOP + 7)
	local panX, panZ, panBottom = -98, -22, STOVE_TOP + 7
	addAll(
		list,
		MapKitShapes.roundedBox("SaucePan", v(34, 20, 34), shade(STEEL, 0.95), "Metal", P(panX, panBottom + 10, panZ), {
			style = "vertical",
			radius = 8,
		}),
		{ reflectance = 0.3 }
	)
	addAll(
		list,
		MapKitShapes.rimDisc("SaucePanLid", 34, 1.2, STEEL_LIGHT, "Metal", P(panX, panBottom + 20.8, panZ), {
			rimColor = STEEL_DARK,
			segments = 16,
		}),
		{ reflectance = 0.35 }
	)
	add(list, "SaucePanKnob", "Ball", v(4, 3, 4), c(30, 30, 34), "SmoothPlastic", P(panX, panBottom + 23.4, panZ), {
		particle = "Steam",
		particleRate = 4,
	})
	addAll(
		list,
		MapKitShapes.capsule(
			"SaucePanHandle",
			26,
			2.6,
			c(30, 30, 34),
			"SmoothPlastic",
			P(panX - 28, panBottom + 15, panZ + 4),
			v(0, -10, 8)
		)
	)
	-- 오른쪽 화구: 약불 + 불티
	addBurner(list, 98, -22, 12, true, 8)
	addGrate(list, 98, -22, 22, 6, STOVE_TOP + 7)
	add(list, "EmberSource", "Block", v(10, 0.4, 10), IRON_DARK, "Metal", P(98, STOVE_TOP + 3.4, -22), {
		transparency = 1,
		particle = "Embers",
		particleRate = 3,
		castShadow = false,
	})
end

---------------------------------------------------------------- MG: 젓가락·후드

local function addChopsticks(list: { DecorSpec })
	for i, da in { -3, 3 } do
		local a = 128 + da
		local x1, z1 = pol(a, 29)
		local x2, z2 = pol(a + da * 0.5, 74)
		stick(
			list,
			`CookingChopstick{i}`,
			v(x1, 30, z1),
			v(x2, 104, z2),
			1.8,
			if i == 1 then WOOD_LIGHT else WOOD,
			"Wood",
			{
				anim = { kind = "Sway", period = 6.5, amount = 1.5, axis = "Z" },
			}
		)
	end
end

local HOOD_Y = 80

local function addHood(list: { DecorSpec })
	local zc = -54
	-- 덮개 (둥근 상자) + 위로 좁아지는 쐐기 + 굴뚝
	addAll(
		list,
		MapKitShapes.roundedBox(
			"HoodCanopy",
			v(210, 16, 92),
			shade(STEEL, 0.8),
			"Metal",
			P(0, HOOD_Y + 8, zc),
			{ radius = 2.4 }
		),
		{ reflectance = 0.25 }
	)
	addAll(
		list,
		MapKitShapes.lipTrim("HoodLip", v(210, 1, 92), 1.2, 3, STEEL_DARK, "Metal", P(0, HOOD_Y + 1, zc)),
		{ reflectance = 0.2 }
	)
	add(
		list,
		"HoodSlope",
		"Wedge",
		v(210, 34, 46),
		shade(STEEL, 0.7),
		"Metal",
		P(0, HOOD_Y + 33, zc + 23),
		{ reflectance = 0.2 }
	)
	add(
		list,
		"HoodBack",
		"Block",
		v(210, 34, 46),
		shade(STEEL, 0.64),
		"Metal",
		P(0, HOOD_Y + 33, zc - 23),
		{ reflectance = 0.15 }
	)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"HoodChimney",
			v(80, 140, 46),
			shade(STEEL, 0.8),
			"Metal",
			P(0, HOOD_Y + 120, BACK_Z + 25),
			{
				style = "vertical",
				radius = 3,
			}
		),
		{ reflectance = 0.15 }
	)
	-- 아래 램프 2개: 하나는 냄비 안을 비추는 좁은 그림자 SpotLight (발판 그림자가 아래층에 떨어지게)
	for i, x in { 0, -38, 38 } do
		add(list, "HoodLamp", "Cylinder", v(0.8, 10, 10), c(255, 236, 190), "Neon", P(x, HOOD_Y - 0.3, -16), {
			rotation = UPRIGHT,
			castShadow = false,
			light = {
				kind = "Spot",
				color = c(255, 226, 170),
				brightness = if i == 1 then 7 else 5,
				range = 60,
				angle = if i == 1 then 80 else 110,
				face = "Left", -- 세운 원판: 로컬 -X가 아래
				shadows = i == 1,
			},
		})
		addAll(list, MapKitShapes.ring("HoodLampTrim", 5.4, 1, 1.2, 8, STEEL_DARK, "Metal", P(x, HOOD_Y + 0.2, -16)))
	end
	-- 필터 줄무늬
	for k = -4, 4 do
		add(
			list,
			"HoodFilter",
			"Block",
			v(3, 0.4, 60),
			STEEL_DARK,
			"Metal",
			P(k * 18 + 9, HOOD_Y + 0.05, zc - 6),
			{ castShadow = false }
		)
	end
end

---------------------------------------------------------------- BG: 방

local function addRoom(list: { DecorSpec })
	-- 바닥: 큰 판 + 두 톤 큰 타일 띠
	add(
		list,
		"KitchenFloor",
		"Block",
		v(SIDE_X * 2 + 40, 4, 520),
		FLOOR_A,
		"WoodPlanks",
		P(0, FLOOR_Y - 2, 150),
		{ castShadow = false }
	)
	for k = 0, 7 do
		add(
			list,
			"FloorBand",
			"Block",
			v(SIDE_X * 2 + 40, 4.2, 32),
			FLOOR_B,
			"WoodPlanks",
			P(0, FLOOR_Y - 2, BACK_Z + 20 + k * 64),
			{
				castShadow = false,
			}
		)
	end
	addAll(
		list,
		MapKitShapes.bevelBox(
			"FloorMat",
			v(200, 1.2, 60),
			c(54, 84, 72),
			"Fabric",
			P(0, FLOOR_Y + 0.6, RANGE_FRONT + 44),
			0.8
		)
	)
	-- 벽: 뒤·왼쪽·오른쪽 (불투명, 어두운 청회색) + 위 몰딩
	add(list, "WallBack", "Block", v(SIDE_X * 2 + 40, 380, 4), WALL, "Plaster", P(0, FLOOR_Y + 190, BACK_Z - 2))
	add(list, "WallLeft", "Block", v(4, 380, 520), WALL_DARK, "Plaster", P(-SIDE_X - 2, FLOOR_Y + 190, 160))
	add(list, "WallRight", "Block", v(4, 380, 520), WALL_DARK, "Plaster", P(SIDE_X + 2, FLOOR_Y + 190, 160))
	add(list, "Molding", "Block", v(SIDE_X * 2 + 40, 6, 6), shade(WALL, 1.3), "Wood", P(0, 230, BACK_Z + 1))
	-- 타일 벽 (카운터 높이 위 백스플래시): 20×20 타일, 3 shade
	local tile = 20
	for row = 0, 3 do
		for col = -14, 14 do
			if math.abs(col) <= 4 and row >= 3 then
				continue -- 후드 굴뚝 뒤는 비워요
			end
			local tint = (row * 7 + col * 3) % 5
			local color = if tint == 0 then TILE_C elseif tint < 3 then TILE_A else TILE_B
			add(
				list,
				"WallTile",
				"Block",
				v(tile - 1, tile - 1, 0.8),
				color,
				"CeramicTiles",
				P(col * tile, STOVE_TOP + tile / 2 + row * tile + 1, BACK_Z + 0.4),
				{ reflectance = 0.08, castShadow = false }
			)
		end
	end
end

local COUNTER_DEPTH = 70

local function addCounter(list: { DecorSpec }, x0: number, x1: number, name: string)
	local width = x1 - x0
	local xc = (x0 + x1) / 2
	local zc = BACK_Z + COUNTER_DEPTH / 2
	addAll(
		list,
		MapKitShapes.bevelBox(
			name .. "Top",
			v(width, 5, COUNTER_DEPTH + 4),
			WOOD,
			"WoodPlanks",
			P(xc, STOVE_TOP - 2.5, zc + 2),
			1.2
		)
	)
	addAll(
		list,
		MapKitShapes.lipTrim(
			name .. "TopEdge",
			v(width, 1, COUNTER_DEPTH + 4),
			0.6,
			2,
			WOOD_DARK,
			"Wood",
			P(xc, STOVE_TOP - 4, zc + 2)
		)
	)
	add(
		list,
		name .. "Body",
		"Block",
		v(width - 4, STOVE_TOP - FLOOR_Y - 5, COUNTER_DEPTH - 4),
		CABINET,
		"WoodPlanks",
		P(xc, (STOVE_TOP - 5 + FLOOR_Y) / 2, zc)
	)
	-- 문 + 손잡이
	local doors = math.max(2, math.floor(width / 40))
	local doorW = (width - 8) / doors
	for i = 0, doors - 1 do
		local dx = x0 + 4 + doorW * (i + 0.5)
		addAll(
			list,
			MapKitShapes.bevelBox(
				name .. "Door",
				v(doorW - 3, 64, 1.6),
				if i % 2 == 0 then CABINET_DARK else shade(CABINET, 0.9),
				"WoodPlanks",
				P(dx, -66, BACK_Z + COUNTER_DEPTH - 1),
				0.6
			)
		)
		add(
			list,
			name .. "Pull",
			"Block",
			v(1.2, 10, 1.4),
			STEEL,
			"Metal",
			P(dx + (if i % 2 == 0 then doorW / 2 - 5 else -doorW / 2 + 5), -46, BACK_Z + COUNTER_DEPTH + 0.8),
			{
				reflectance = 0.3,
			}
		)
	end
	add(
		list,
		name .. "Kick",
		"Block",
		v(width - 6, 6, 2),
		c(30, 30, 34),
		"SmoothPlastic",
		P(xc, FLOOR_Y + 3, BACK_Z + COUNTER_DEPTH - 6)
	)
end

-- 다 튀긴 튀김 접시 + 튀김 망 + 반죽 그릇 (오른쪽 카운터, 출발 쪽에서 잘 보이는 히어로 세트피스)
local function addTempuraPlate(list: { DecorSpec })
	local top = STOVE_TOP
	local px, pz = 200, -52
	addAll(
		list,
		MapKitShapes.rimDisc("ServePlate", 44, 1.4, PORCELAIN, "SmoothPlastic", P(px, top + 0.7, pz), {
			rimColor = PAL.PorcelainRim,
			rimWidth = 1.2,
			rimHeight = 1.2,
			segments = 20,
		}),
		{ reflectance = 0.08 }
	)
	add(
		list,
		"OilPaper",
		"Block",
		v(30, 0.3, 30),
		PAPER,
		"Fabric",
		P(px, top + 1.6, pz),
		{ rotation = v(0, 18, 0), castShadow = false }
	)
	-- 새우튀김 더미 (5개, 크기·각도 변형) + 꼬리
	local shrimp = {
		{ -6, -4, 10, 0 },
		{ 4, -6, -14, 0 },
		{ -2, 5, 30, 0 },
		{ 6, 4, -40, 0 },
		{ 0, 0, 5, 4.2 },
	}
	for i, s in shrimp do
		local len = 18 * (0.9 + 0.05 * i)
		local col = if i % 3 == 0 then shade(GOLD, 1.1) elseif i % 3 == 1 then GOLD else shade(GOLD, 0.88)
		local cx, cz, yaw, lift = s[1], s[2], s[3], s[4]
		addAll(
			list,
			MapKitShapes.capsule(
				"ServedShrimp",
				len,
				5,
				col,
				"Sand",
				P(px + cx, top + 4.2 + lift, pz + cz),
				v(0, yaw, if lift > 0 then 8 else 0)
			)
		)
		local rad = math.rad(yaw)
		add(
			list,
			"ServedTail",
			"Wedge",
			v(2, 3, 4),
			SHRIMP_TAIL,
			"SmoothPlastic",
			P(px + cx + math.cos(rad) * (len / 2 + 1.5), top + 4.6 + lift, pz + cz - math.sin(rad) * (len / 2 + 1.5)),
			{
				rotation = v(0, yaw + 90, -15),
			}
		)
	end
	-- 레몬 조각 + 무즙
	add(
		list,
		"Lemon",
		"Cylinder",
		v(1.6, 7, 7),
		c(250, 226, 90),
		"SmoothPlastic",
		P(px + 14, top + 3, pz + 9),
		{ rotation = v(0, 30, 70) }
	)
	add(list, "GratedRadish", "Ball", v(5, 3.4, 5), c(244, 242, 232), "Sand", P(px - 13, top + 3, pz + 10))
	-- 튀김 망(아미): 스테인리스 쟁반 + 격자
	local rx, rz = 262, -48
	addAll(
		list,
		MapKitShapes.rimDisc(
			"DrainTray",
			36,
			1.2,
			STEEL,
			"Metal",
			P(rx, top + 0.6, rz),
			{ rimColor = STEEL_DARK, rimWidth = 1, segments = 16 }
		),
		{
			reflectance = 0.3,
		}
	)
	for k = -3, 3 do
		add(
			list,
			"RackWire",
			"Block",
			v(28, 0.4, 0.4),
			STEEL_LIGHT,
			"Metal",
			P(rx, top + 3, rz + k * 4),
			{ castShadow = false }
		)
		add(
			list,
			"RackWire",
			"Block",
			v(0.4, 0.4, 28),
			STEEL_LIGHT,
			"Metal",
			P(rx + k * 4, top + 3.2, rz),
			{ castShadow = false }
		)
	end
	addAll(
		list,
		MapKitShapes.capsule(
			"RackShrimp",
			16,
			4.4,
			shade(GOLD, 0.95),
			"Sand",
			P(rx - 2, top + 5.6, rz - 3),
			v(0, 25, 0)
		)
	)
	addAll(
		list,
		MapKitShapes.capsule("RackKakiage", 9, 7, shade(GOLD, 0.8), "Pebble", P(rx + 6, top + 6.4, rz + 6), v(0, 70, 0))
	)
	-- 반죽 그릇 + 거품기
	local bx, bz = 150, -60
	addAll(
		list,
		MapKitShapes.rimDisc("BatterBowl", 24, 9, PORCELAIN, "SmoothPlastic", P(bx, top + 4.5, bz), {
			rimColor = PAL.PorcelainRim,
			rimWidth = 1,
			rimHeight = 1.4,
			segments = 18,
		}),
		{ reflectance = 0.08 }
	)
	add(
		list,
		"Batter",
		"Cylinder",
		v(0.4, 21, 21),
		BATTER,
		"SmoothPlastic",
		P(bx, top + 9.3, bz),
		{ rotation = UPRIGHT }
	)
	stick(list, "Whisk", v(bx - 8, top + 8, bz), v(bx - 22, top + 26, bz + 6), 1.4, STEEL_LIGHT, "Metal")
end

-- 왼쪽 카운터: 밀가루·빵가루 통, 도마 위 생새우, 기대어 둔 냄비 뚜껑
local function addPrepCounter(list: { DecorSpec })
	local top = STOVE_TOP
	for i, jar in
		{
			{ x = -280, z = -70, d = 16, h = 30, col = c(236, 232, 220) },
			{ x = -258, z = -76, d = 13, h = 24, col = c(214, 190, 140) },
			{ x = -240, z = -66, d = 10, h = 18, col = c(196, 214, 226) },
		}
	do
		local x, z, d, h, col = jar.x, jar.z, jar.d, jar.h, jar.col
		add(
			list,
			"Canister",
			"Cylinder",
			v(h, d, d),
			col,
			"SmoothPlastic",
			P(x, top + h / 2, z),
			{ rotation = UPRIGHT, reflectance = 0.05 }
		)
		add(
			list,
			"CanisterLid",
			"Cylinder",
			v(2, d + 1, d + 1),
			if i == 2 then WOOD_DARK else WOOD,
			"Wood",
			P(x, top + h + 1, z),
			{ rotation = UPRIGHT }
		)
	end
	addAll(
		list,
		MapKitShapes.bevelBox(
			"CuttingBoard",
			v(44, 3, 28),
			WOOD_LIGHT,
			"Wood",
			P(-200, top + 1.5, -58),
			0.6,
			v(0, -8, 0)
		)
	)
	for i = 0, 3 do
		addAll(
			list,
			MapKitShapes.capsule(
				"RawShrimp",
				13,
				3.6,
				c(240, 170, 160),
				"SmoothPlastic",
				P(-210 + i * 6, top + 4.8, -60 + (i % 2) * 3),
				v(0, 80 + i * 6, 0)
			)
		)
	end
	addAll(
		list,
		MapKitShapes.rimDisc("LeaningLid", 50, 1.4, IRON_LIGHT, "Metal", P(-170, top + 25, BACK_Z + 6), {
			rimColor = IRON_DARK,
			rimWidth = 1.2,
			segments = 20,
			rotation = v(78, 0, 0),
		}),
		{ reflectance = 0.2 }
	)
end

-- 뒤 벽 창문: 밤하늘 + 달 + 구름(Bob), 파란 SurfaceLight (온도 대비)
local function addWindow(list: { DecorSpec })
	local wx, wy, wz = -215, 50, BACK_Z + 1
	add(list, "WindowNight", "Block", v(96, 76, 0.6), NIGHT, "SmoothPlastic", P(wx, wy, wz), {
		light = { kind = "Surface", color = c(110, 150, 255), brightness = 3, range = 16, angle = 100, face = "Back" },
		castShadow = false,
	})
	addAll(list, MapKitShapes.bevelBox("WindowFrame", v(104, 4, 4), WOOD_DARK, "Wood", P(wx, wy + 40, wz + 1.5), 0.8))
	addAll(list, MapKitShapes.bevelBox("WindowFrame", v(104, 4, 4), WOOD_DARK, "Wood", P(wx, wy - 40, wz + 1.5), 0.8))
	addAll(list, MapKitShapes.bevelBox("WindowFrame", v(4, 80, 4), WOOD_DARK, "Wood", P(wx - 50, wy, wz + 1.5), 0.8))
	addAll(list, MapKitShapes.bevelBox("WindowFrame", v(4, 80, 4), WOOD_DARK, "Wood", P(wx + 50, wy, wz + 1.5), 0.8))
	add(list, "WindowMullion", "Block", v(2.4, 76, 2.4), WOOD_DARK, "Wood", P(wx, wy, wz + 1.5))
	add(list, "WindowSill", "Block", v(110, 2.4, 10), WOOD, "Wood", P(wx, wy - 42, wz + 5))
	add(
		list,
		"Moon",
		"Cylinder",
		v(0.6, 14, 14),
		MOON,
		"Neon",
		P(wx + 24, wy + 20, wz + 0.4),
		{ rotation = v(0, 90, 0), castShadow = false }
	)
	for i, s in { { -22, 18, 18 }, { -10, 22, 12 }, { 26, -12, 16 }, { 36, -8, 10 } } do
		add(
			list,
			"Cloud",
			"Cylinder",
			v(0.6, s[3] * 0.5, s[3]),
			c(70, 82, 120),
			"SmoothPlastic",
			P(wx + s[1], wy + s[2], wz + 0.6),
			{
				rotation = v(0, 90, 0),
				castShadow = false,
				anim = { kind = "Bob", period = 7 + i, amount = 1.5, axis = "X" },
			}
		)
	end
	for i = 0, 5 do
		add(
			list,
			"Star",
			"Block",
			v(1, 1, 0.4),
			c(220, 230, 255),
			"Neon",
			P(wx - 40 + i * 15, wy + 6 + ((i * 11) % 7) * 4, wz + 0.4),
			{ rotation = v(0, 0, 45), castShadow = false }
		)
	end
	-- 창가 화분 (바질)
	add(
		list,
		"SillPot",
		"Cylinder",
		v(9, 9, 9),
		c(170, 96, 60),
		"Plastic",
		P(wx - 30, wy - 36, wz + 5),
		{ rotation = UPRIGHT }
	)
	add(list, "SillHerb", "Ball", v(13, 10, 13), PAL.Matcha, "Grass", P(wx - 30, wy - 27, wz + 5))
end

-- 오른쪽 위 찬장 + 그 아래 걸이 레일(국자·뜰채·집게, Sway)
local function addCabinetAndRail(list: { DecorSpec })
	local cx0, cx1 = 150, 300
	local cxm = (cx0 + cx1) / 2
	addAll(
		list,
		MapKitShapes.roundedBox(
			"UpperCabinet",
			v(cx1 - cx0, 64, 40),
			CABINET,
			"WoodPlanks",
			P(cxm, 150, BACK_Z + 20),
			{ style = "vertical", radius = 2 }
		)
	)
	for i, dx in { -37, 37 } do
		addAll(
			list,
			MapKitShapes.bevelBox(
				"UpperDoor",
				v(70, 58, 1.4),
				if i == 1 then CABINET_DARK else shade(CABINET, 0.88),
				"WoodPlanks",
				P(cxm + dx, 150, BACK_Z + 40.6),
				0.6
			)
		)
		add(
			list,
			"UpperPull",
			"Block",
			v(8, 1.2, 1.4),
			STEEL,
			"Metal",
			P(cxm + dx, 126, BACK_Z + 41.6),
			{ reflectance = 0.3 }
		)
	end
	-- 찬장 아래 조명 띠 (따뜻한 빛, 보이는 원인)
	add(list, "UnderCabinetLight", "Block", v(130, 0.8, 3), c(255, 220, 160), "Neon", P(cxm, 117.6, BACK_Z + 34), {
		castShadow = false,
		light = { kind = "Spot", color = c(255, 210, 150), brightness = 2, range = 50, angle = 120, face = "Bottom" },
	})
	-- 걸이 레일 + 도구
	local railY = 66
	addAll(
		list,
		MapKitShapes.capsule("UtensilRail", 140, 1.6, STEEL_LIGHT, "Metal", P(cxm, railY, BACK_Z + 4), nil),
		{ reflectance = 0.35 }
	)
	local sway = function(i: number): AnimSpec
		return { kind = "Sway", period = 4 + i * 0.7, amount = 4, axis = "Z" }
	end
	-- 국자
	add(
		list,
		"LadleHandle",
		"Cylinder",
		v(30, 1.2, 1.2),
		STEEL_LIGHT,
		"Metal",
		P(170, railY - 15, BACK_Z + 5),
		{ rotation = UPRIGHT, reflectance = 0.35, anim = sway(1) }
	)
	add(
		list,
		"LadleBowl",
		"Ball",
		v(9, 6, 9),
		STEEL,
		"Metal",
		P(170, railY - 31, BACK_Z + 7),
		{ reflectance = 0.35, anim = sway(1) }
	)
	-- 뜰채 (둥근 망)
	add(
		list,
		"SkimmerHandle",
		"Cylinder",
		v(26, 1.2, 1.2),
		WOOD_DARK,
		"Wood",
		P(200, railY - 13, BACK_Z + 5),
		{ rotation = UPRIGHT, anim = sway(2) }
	)
	add(
		list,
		"SkimmerMesh",
		"Cylinder",
		v(0.6, 14, 14),
		STEEL_DARK,
		"DiamondPlate",
		P(200, railY - 33, BACK_Z + 5),
		{ rotation = v(0, 90, 0), reflectance = 0.2, anim = sway(2) }
	)
	-- 집게
	for k, dx in { -1, 1 } do
		add(list, "Tongs", "Block", v(1, 26, 1.6), STEEL_LIGHT, "Metal", P(230 + dx * 1.4, railY - 13, BACK_Z + 5), {
			rotation = v(0, 0, dx * 4),
			reflectance = 0.35,
			anim = sway(2 + k),
		})
	end
	-- 걸린 작은 프라이팬
	addAll(
		list,
		MapKitShapes.rimDisc("HangingPan", 22, 1.4, IRON, "Metal", P(262, railY - 22, BACK_Z + 4), {
			rimColor = IRON_LIGHT,
			segments = 16,
			rotation = v(90, 0, 0),
		}),
		{ anim = sway(5) }
	)
	add(
		list,
		"HangingPanHandle",
		"Cylinder",
		v(16, 2, 2),
		c(30, 30, 34),
		"SmoothPlastic",
		P(262, railY - 4, BACK_Z + 4),
		{ rotation = UPRIGHT, anim = sway(5) }
	)
end

-- 왼쪽 벽: 큰 업소용 냉장고 + 열린 선반(그릇·병 무리)
local function addLeftWall(list: { DecorSpec })
	local x = -SIDE_X + 40
	addAll(
		list,
		MapKitShapes.roundedBox(
			"Fridge",
			v(76, 210, 80),
			shade(STEEL, 0.9),
			"Metal",
			P(x, FLOOR_Y + 105, 40),
			{ style = "vertical", radius = 4 }
		),
		{ reflectance = 0.25 }
	)
	add(list, "FridgeSeam", "Block", v(1, 206, 1), STEEL_DARK, "Metal", P(x + 38.2, FLOOR_Y + 105, 40))
	for _, dz in { -14, 14 } do
		addAll(
			list,
			MapKitShapes.capsule(
				"FridgeHandle",
				60,
				2.4,
				STEEL_LIGHT,
				"Metal",
				P(x + 40.5, FLOOR_Y + 120, 40 + dz),
				UPRIGHT
			),
			{ reflectance = 0.4 }
		)
	end
	add(
		list,
		"FridgeLed",
		"Block",
		v(0.6, 4, 12),
		c(120, 200, 255),
		"Neon",
		P(x + 38.6, FLOOR_Y + 190, 40),
		{ castShadow = false }
	)
	-- 선반 2단 (냉장고 앞쪽)
	for k, y in { 30, 80 } do
		addAll(
			list,
			MapKitShapes.bevelBox("WallShelf", v(30, 3, 140), WOOD, "WoodPlanks", P(-SIDE_X + 15, y, 170), 0.6)
		)
		for j = 0, 4 do
			local z = 120 + j * 25 + (k * 7) % 9
			local h = 10 + ((j + k) % 3) * 5
			add(
				list,
				"ShelfJar",
				"Cylinder",
				v(h, 9, 9),
				if (j + k) % 3 == 0
					then c(170, 120, 70)
					elseif (j + k) % 3 == 1 then c(120, 150, 110)
					else c(196, 196, 186),
				"Glass",
				P(-SIDE_X + 15, y + 1.5 + h / 2, z),
				{
					rotation = UPRIGHT,
					reflectance = 0.15,
				}
			)
		end
	end
end

-- 오른쪽 벽: 노렌 걸린 출입구 + 접시 선반
local addPendants: (list: { DecorSpec }) -> ()

local function addRightWall(list: { DecorSpec })
	local x = SIDE_X - 1
	add(list, "Doorway", "Block", v(2, 150, 90), c(28, 30, 40), "SmoothPlastic", P(x, FLOOR_Y + 75, 120))
	addAll(list, MapKitShapes.bevelBox("DoorFrame", v(4, 6, 100), WOOD_DARK, "Wood", P(x - 1, FLOOR_Y + 153, 120), 0.8))
	for k = -2, 2 do
		add(
			list,
			"Noren",
			"Block",
			v(1, 46, 16),
			if k % 2 == 0 then PAL.Noren else PAL.NorenLight,
			"Fabric",
			P(x - 3, FLOOR_Y + 127, 120 + k * 17),
			{
				anim = { kind = "Sway", period = 5 + k * 0.4, amount = 3, axis = "Z" },
			}
		)
	end
	addAll(list, MapKitShapes.bevelBox("PlateShelf", v(26, 3, 120), WOOD, "WoodPlanks", P(SIDE_X - 13, 40, 10), 0.6))
	for j = 0, 6 do
		add(
			list,
			"StackedPlate",
			"Cylinder",
			v(6 + (j % 3) * 3, 18, 18),
			if j % 2 == 0 then PORCELAIN else c(214, 226, 236),
			"SmoothPlastic",
			P(SIDE_X - 13, 44 + (j % 3) * 1.5, -40 + j * 16),
			{
				rotation = UPRIGHT,
				reflectance = 0.08,
			}
		)
	end
end

-- 카운터 위 펜던트 등 2개 (따뜻한 빛 — 보이는 전구 + 갓 + 줄)
function addPendants(list: { DecorSpec })
	for i, x in { -215, 215 } do
		local y = 70
		add(list, "PendantCord", "Cylinder", v(150, 0.5, 0.5), c(30, 30, 34), "SmoothPlastic", P(x, y + 80, -60), {
			rotation = UPRIGHT,
			anim = { kind = "Sway", period = 7 + i, amount = 1.2, axis = "X" },
		})
		add(list, "PendantShade", "Cylinder", v(9, 18, 18), shade(PAL.CastIron, 1.6), "Metal", P(x, y + 4, -60), {
			rotation = UPRIGHT,
			reflectance = 0.15,
		})
		add(list, "PendantBulb", "Ball", v(6, 6, 6), c(255, 226, 170), "Neon", P(x, y - 1, -60), {
			castShadow = false,
			light = { kind = "Point", color = c(255, 196, 130), brightness = 2.4, range = 60 },
		})
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPot(list)
	addRaftDecor(list)
	addRange(list)
	addChopsticks(list)
	addHood(list)
	addRoom(list)
	addCounter(list, RANGE_X, SIDE_X, "RightCounter")
	addCounter(list, -SIDE_X, -RANGE_X, "LeftCounter")
	addTempuraPlate(list)
	addPrepCounter(list)
	addWindow(list)
	addCabinetAndRail(list)
	addLeftWall(list)
	addRightWall(list)
	addPendants(list)
	return list
end

-- 카운터 높이에서 불꽃 + 냄비 넓은 샷 → 꼭대기 발판 → 꼭대기에서 바구니를 내려다보는 반전 샷 → 출발 바구니
function Art.introCamera(): { IntroPoint }
	local topX, topZ = Layout.polar(Layout.TOP_ANGLE, Layout.TOP_RING_RADIUS)
	return {
		{ pos = P(62, -4, 74), lookAt = P(0, 10, 0) },
		{ pos = v(topX + 12, 40, topZ + 14), lookAt = v(topX, 30, topZ) },
		{ pos = v(topX + 2, 38, topZ + 3), lookAt = P(0, Layout.BASKET_TOP_Y, -4) },
		{ pos = P(0, Layout.BASKET_TOP_Y + 10, 24), lookAt = P(0, Layout.BASKET_TOP_Y + 2, -8) },
	}
end

return Art
