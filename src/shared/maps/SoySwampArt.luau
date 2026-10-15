--!strict
-- 간장 늪 & 와사비 산 아트 (m4-02 → m5-20 → m5-24 v2): 장식·소개 카메라·색·조명을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   SoySwampArt.COLORS          판정 파츠(바닥·산·경사로·웅덩이·패드·날치알)에 칠할 색 { r, g, b }
--   SoySwampArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   SoySwampArt.introCamera()   라운드 소개 경유점 (출발 위 → 와사비 패드·절벽 → 산 위 반전 샷 → 뒷부분 넓은 샷(m5-40) → 출발선 뒤)
--   SoySwampArt.courseVolume()  장식이 들어가면 안 되는 상자들 (구간마다 벽 안쪽, 그 구간 바닥 위 2~12)
--   SoySwampArt.BUDGET          "Extended" (m5-24 — 장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
--   SoySwampArt.LIGHTING        맵 조명 분위기 (m5-23 PRESETS["soy-swamp"]에서 시작해 다듬음)
--   SoySwampArt.CODE_EXTRAS     SoySwamp.build가 Instance.new로 따로 붙이는 조명·파티클 수 (예산 검사용)
-- 코스 치수는 전부 SoySwampLayout에서 읽어요 (판정 수치는 그쪽이 정해요).
--
-- m5-24 세계: 코스는 다리 달린 나무 게타(초밥 판) 위에 놓여 있고, 그 아래(낙하선 40보다 10 더 아래)는
-- 거대한 간장 접시에 고인 간장 호수예요. 호수 둘레는 도자기 접시 테두리, 그 바깥은 어두운 나무 주방 카운터와
-- 타일 벽·창문·병 선반. 히어로: ① 와사비 산(호수에서 솟은 Pebble 덩어리) ② 쓰러져 간장을 쏟는 거대 간장병
-- ③ 반쯤 잠긴 젓가락·연근 조각 ④ 강판(오로시가네) 절벽 ⑤ 결승 쪽 날치알 언덕.

local Layout = require(script.Parent.SoySwampLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local P = MapKitLogic.PALETTE
local shade = MapKitLogic.shade

local SoySwampArt = {}

SoySwampArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier

-- SoySwamp.build가 Instance.new로 붙이는 것: HillRice 빛 2, 웅덩이 거품 파티클 3 (m5-20)
SoySwampArt.CODE_EXTRAS = { lights = 2, particles = 3 }

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- 흐린 오후, 간장 안개 (m5-23 프리셋에서: 안개를 조금 걷어 배경 실루엣이 보이게, 따뜻한 등 + 창빛 대비)
SoySwampArt.LIGHTING = {
	ClockTime = 15,
	Brightness = 1.8,
	Ambient = c(98, 92, 72),
	OutdoorAmbient = c(132, 126, 100),
	EnvironmentSpecularScale = 0.7,
	Atmosphere = {
		Density = 0.32,
		Offset = 0.15,
		Color = c(176, 160, 122),
		Decay = c(98, 76, 50),
		Glare = 0,
		Haze = 1.3,
	},
	ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = -0.04, TintColor = c(248, 244, 228) },
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.25 },
	SunRays = { Intensity = 0.03, Spread = 0.5 },
} :: MapLighting.LightingPreset

-- 판정 파츠 색 (크기·위치·충돌은 SoySwamp가 그대로 둬요). 바닥은 와사비 연두·간장과 헷갈리지 않게 채도를 낮춰요.
SoySwampArt.COLORS = {
	floor = { r = 172, g = 132, b = 92 }, -- 나무 바닥
	swamp = { r = 140, g = 118, b = 96 }, -- 늪 진흙 판
	soy = { r = 66, g = 32, b = 14 }, -- 간장 웅덩이
	mountain = { r = 118, g = 142, b = 92 }, -- 와사비 산 몸통 (패드보다 어둡고 탁하게)
	wasabi = { r = 150, g = 230, b = 70 }, -- 와사비 패드 (밝은 연두, Neon)
	ramp = P.Wood, -- 경사로 나무
	slope = { r = 214, g = 150, b = 104 }, -- 날치알 내리막 (따뜻한 주황 나무)
	wall = { r = 206, g = 214, b = 220 }, -- m5-24 반복 3: 유리벽 색만 조금 어둡게 (투명도·크기는 그대로)
	spawn = { r = 246, g = 196, b = 70 },
	finish = { r = 255, g = 196, b = 40 },
	tobiko = { r = 255, g = 112, b = 28 }, -- 날치알 공
	stone = { r = 228, g = 220, b = 198 }, -- m5-40 징검다리 발판 윗면 (군함말이 밥 — 간장 강 위에서 가장 밝게)
	nori = { r = 40, g = 56, b = 44 }, -- m5-40 징검다리 발판 기둥 (군함말이 김)
} :: { [string]: RGB }

SoySwampArt.SOY_REFLECTANCE = 0.25

-- m5-20 파티클·조명·안개 이름 상수
SoySwampArt.HILL_RICE = "HillRice"
SoySwampArt.PUDDLE_BUBBLE = "SoyBubble"
SoySwampArt.FOG_PANEL = "FogPanel"
local FOG: RGB = { r = 90, g = 55, b = 30 } -- 간장·나무 톤 갈색-호박색 (m5-20 ③)

local HALF = Layout.WIDTH / 2
local CZ = (Layout.START.front + Layout.FINISH.back) / 2 -- 코스 가운데 z (m5-40: -204.5)
local UP: Vec3 = { x = 0, y = 0, z = 90 } -- Cylinder 축(X)을 세워요
local WASABI_BUMP = { r = 120, g = 182, b = 56 }
local HILLS = {
	{ r = 112, g = 150, b = 70 },
	{ r = 132, g = 170, b = 80 },
	{ r = 150, g = 188, b = 92 },
}
local SOY_BOTTLE = { r = 48, g = 26, b = 16 }
local GRATER = { r = 170, g = 176, b = 182 }
local GINGER = { r = 244, g = 170, b = 172 }
local WHITE = P.Rice
local BLACK = P.Nori

-- m5-24 세계 색 (60 = 간장 갈색·어두운 나무, 30 = 밥 흰·도자기, 10 = 와사비 연두·날치알 주황)
SoySwampArt.LAKE_Y = -50 -- 간장 호수 윗면 (낙하선 -40보다 10 아래)
local LAKE_Y = SoySwampArt.LAKE_Y
local LAKE: RGB = c(58, 30, 16)
local COUNTER_Y = -60 -- 카운터 윗면
local WALL_DIST = 640 -- 방 벽까지 (코스 가운데 기준)
local WALL_H = 420
local PLASTER: RGB = c(150, 130, 104)
local TILE: RGB = c(170, 166, 150)
local WOOD_DARK = P.WoodDark
local WOOD_MID: RGB = c(146, 104, 66)
local MOUNTAIN_SHADES = {
	c(96, 132, 58),
	c(116, 152, 66),
	c(136, 170, 80),
	c(84, 116, 52),
}
local TOBIKO_SHADES = { c(255, 112, 28), c(240, 92, 22), c(255, 140, 56) }
local LOTUS: RGB = c(236, 222, 190)
local LOTUS_HOLE: RGB = c(110, 76, 44)
local NORI_GREEN: RGB = c(36, 48, 36)
local SCALLION: RGB = c(120, 176, 70)

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function part(
	list: { DecorSpec },
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
	table.insert(list, spec)
	return spec
end

local function append(list: { DecorSpec }, more: { DecorSpec })
	for _, s in more do
		table.insert(list, s)
	end
end

-- 세운 원기둥 (높이 h, 지름 d, 바닥 y)
local function disc(
	list: { DecorSpec },
	name: string,
	h: number,
	d: number,
	color: RGB,
	material: string,
	x: number,
	y: number,
	z: number
): DecorSpec
	return part(list, name, "Cylinder", v(h, d, d), color, material, v(x, y + h / 2, z), UP)
end

-- 간장 웅덩이 가장자리: 흰 도자기 종지 테두리 + 남색 줄 (낮고 얇게, 밟아도 걸리지 않음)
local function addPuddleRims(list: { DecorSpec })
	local top = 0.1 + Layout.PUDDLE_DEPTH -- 웅덩이 윗면
	for _, box in Layout.PUDDLES do
		local halfW, halfD = box.width / 2, box.depth / 2
		local edges = {
			{ size = v(box.width + 0.5, 0.25, 0.5), x = box.x, z = box.z + halfD },
			{ size = v(box.width + 0.5, 0.25, 0.5), x = box.x, z = box.z - halfD },
			{ size = v(0.5, 0.25, box.depth + 0.5), x = box.x - halfW, z = box.z },
			{ size = v(0.5, 0.25, box.depth + 0.5), x = box.x + halfW, z = box.z },
		}
		for _, edge in edges do
			part(list, "SoyRim", "Block", edge.size, P.Porcelain, "SmoothPlastic", v(edge.x, top + 0.125, edge.z))
			local line = v(edge.size.x * 0.98, 0.05, edge.size.z * 0.98)
			if edge.size.x > edge.size.z then
				line.z = 0.18
			else
				line.x = 0.18
			end
			part(list, "SoyRimLine", "Block", line, P.PorcelainRim, "SmoothPlastic", v(edge.x, top + 0.275, edge.z))
		end
	end
end

-- 와사비 패드 위 울퉁불퉁한 작은 공 (패드 위로 0.5 이하)
local function addWasabiBumps(list: { DecorSpec })
	for _, pad in Layout.WASABI_PADS do
		local top = Layout.PAD_THICKNESS
		for i = 0, 5 do
			for j = 0, 1 do
				local d = if (i + j) % 2 == 0 then 0.8 else 0.6
				local x = pad.x - pad.width / 2 + 1 + i * ((pad.width - 2) / 5)
				local z = pad.z - pad.depth / 4 + j * (pad.depth / 2) + (if i % 2 == 0 then 0.3 else -0.3)
				part(list, "WasabiBump", "Ball", v(d, d, d), WASABI_BUMP, "Sand", v(x, top + 0.45 - d / 2, z))
			end
		end
	end
end

-- ① 와사비 산: 양옆 벽 바깥 층층 언덕(m4-02, 모서리를 깎은 상자로) + 호수에서 솟은 큰 Pebble 덩어리
local function addHills(list: { DecorSpec })
	local centerZ = (Layout.MOUNTAIN.front + Layout.MOUNTAIN.back) / 2
	local layers = {
		{ w = 18, h = 5, d = 44 },
		{ w = 14, h = 5, d = 36 },
		{ w = 10, h = 5, d = 28 },
		{ w = 6, h = 5, d = 18 },
	}
	for _, side in { -1, 1 } do
		for i, layer in layers do
			local inner = HALF + 0.75
			local x = side * (inner + layer.w / 2)
			local y = (i - 1) * layer.h + layer.h / 2
			append(
				list,
				MapKitShapes.bevelBox(
					"WasabiHill",
					v(layer.w, layer.h, layer.d),
					HILLS[(i - 1) % #HILLS + 1],
					"Pebble",
					v(x, y, centerZ),
					1.2
				)
			)
		end
		-- 꼭대기 밥알 눈
		part(list, SoySwampArt.HILL_RICE, "Ball", v(5, 5, 5), WHITE, "Sand", v(side * (HALF + 3.75), 20.5, centerZ))
		-- 밥알 눈 흘러내림 (작은 흰 공 무리)
		for k = 0, 3 do
			local d = 2.2 - k * 0.3
			part(
				list,
				"HillRiceDrip",
				"Ball",
				v(d, d, d),
				P.RiceShade,
				"Sand",
				v(side * (HALF + 5 + k * 1.6), 19.2 - k * 1.4, centerZ + (if k % 2 == 0 then 3 else -3.5))
			)
		end
		-- 산 아래 덩어리: 호수(LAKE_Y)에서 솟아 층층 언덕을 받쳐요. 윗면은 둥글고 코스 벽보다 바깥.
		local masses = {
			{ d = 34, x = 31, y = -17, z = centerZ + 6, s = 1 },
			{ d = 40, x = 44, y = -26, z = centerZ - 16, s = 2 },
			{ d = 46, x = 38, y = -32, z = centerZ + 26, s = 3 },
			{ d = 56, x = 62, y = -30, z = centerZ + 2, s = 4 },
			{ d = 30, x = 54, y = -10, z = centerZ - 4, s = 2 },
			{ d = 36, x = 34, y = -38, z = centerZ - 36, s = 1 },
			{ d = 24, x = 20, y = -12.5, z = centerZ - 10, s = 3 },
			{ d = 24, x = 20, y = -12.5, z = centerZ + 14, s = 1 },
		}
		for _, m in masses do
			part(
				list,
				"WasabiMass",
				"Ball",
				v(m.d, m.d * 0.9, m.d),
				MOUNTAIN_SHADES[m.s],
				"Pebble",
				v(side * m.x, m.y, m.z)
			)
		end
		-- 강판 자국 같은 가로 결 (Pebble 위 밝은 줄)
		for k = 0, 2 do
			part(
				list,
				"WasabiRidge",
				"Ball",
				v(22 - k * 4, 3, 10),
				MOUNTAIN_SHADES[3],
				"Pebble",
				v(side * (36 + k * 6), -2 - k * 3, centerZ - 6 + k * 9),
				v(0, 20 * side + k * 15, 8)
			)
		end
	end
	-- 정상 반짝임 (Sparkle) — 양쪽 밥알 눈 옆 투명 앵커
	for _, side in { -1, 1 } do
		local s = part(
			list,
			"WasabiSparkle",
			"Block",
			v(4, 1, 8),
			P.Wasabi,
			"SmoothPlastic",
			v(side * (HALF + 8), 16, centerZ)
		)
		s.transparency = 1
		s.particle = "Sparkle"
		s.particleRate = 3
		s.castShadow = false
	end
end

-- 간장 웅덩이마다 표면 보글거림 파티클이 붙을 투명 앵커 (m5-20 ①)
local function addPuddleBubbles(list: { DecorSpec })
	local top = 0.1 + Layout.PUDDLE_DEPTH
	for _, box in Layout.PUDDLES do
		part(
			list,
			SoySwampArt.PUDDLE_BUBBLE,
			"Block",
			v(0.4, 0.05, 0.4),
			P.Soy,
			"SmoothPlastic",
			v(box.x, top + 0.03, box.z)
		)
	end
end

-- m5-20 ③ 안개 패널: 지우지 않아요(m5-24 D3). m5-24부터 방 벽 바깥에 세워 두어 코스 화면을 뿌옇게 하지 않고,
-- 분위기는 LIGHTING의 Atmosphere가 맡아요 (m5-24 그룹 B 결정 기록 D5).
local function addFogPanels(list: { DecorSpec })
	local outside = WALL_DIST + 40
	local function panel(x: number, z: number, sizeX: number, sizeZ: number)
		part(list, SoySwampArt.FOG_PANEL, "Block", v(sizeX, 170, sizeZ), FOG, "Glass", v(x, 65, z))
		list[#list].transparency = 0.9
	end
	local span = Layout.totalLength() + 80
	panel(-outside, CZ, 2, span)
	panel(outside, CZ, 2, span)
	panel(0, CZ + outside, 220, 2)
	panel(0, CZ - outside, 220, 2)
end

-- 날치알 그릇: 내리막 꼭대기 옆(오른쪽 벽 바깥)에서 공이 굴러 나오는 것처럼. m5-24: 호수에서 올라온 받침 위에.
local function addTobikoBowl(list: { DecorSpec })
	local x, z = HALF + 9, Layout.BALL_SPAWN_Z - 2
	local y = Layout.SLOPE_HIGH
	disc(list, "TobikoBowl", 4, 12, P.Porcelain, "SmoothPlastic", x, y, z).reflectance = 0.08
	disc(list, "TobikoBowlRim", 0.4, 12.4, P.PorcelainRim, "SmoothPlastic", x, y + 3.8, z)
	part(list, "TobikoHeap", "Ball", v(10, 10, 10), SoySwampArt.COLORS.tobiko, "Sand", v(x, y + 3, z))
	for i = 0, 3 do
		part(
			list,
			"TobikoSpill",
			"Ball",
			v(1.6, 1.6, 1.6),
			SoySwampArt.COLORS.tobiko,
			"Sand",
			v(HALF + 2 + i * 0.9, y + 0.8 - i * 0.6, z + 3 + i * 1.5)
		)
	end
	-- 받침 (굽 달린 도자기 기둥)
	disc(list, "TobikoStand", y - LAKE_Y - 3, 5, P.RiceShade, "SmoothPlastic", x, LAKE_Y + 3, z)
	disc(list, "TobikoStandFoot", 3, 14, P.Porcelain, "SmoothPlastic", x, LAKE_Y, z)
	disc(list, "TobikoStandBand", 1, 5.6, P.PorcelainRim, "SmoothPlastic", x, y - 6, z)
end

-- ② 거대 간장병: 하나는 호수에 서 있고(m4-02 병을 키워 내림), 하나는 쓰러져 코스 옆으로 간장을 쏟아요.
local function addSoyBottle(list: { DecorSpec })
	-- 선 병 (왼쪽 산 뒤)
	local x, z = -(HALF + 46), -122
	local base = LAKE_Y - 1
	disc(list, "SoyBottleBody", 58, 22, SOY_BOTTLE, "SmoothPlastic", x, base, z).reflectance = 0.15
	part(list, "SoyBottleShoulder", "Ball", v(22, 22, 22), SOY_BOTTLE, "SmoothPlastic", v(x, base + 58, z)).reflectance =
		0.15
	disc(list, "SoyBottleNeck", 8, 8, SOY_BOTTLE, "SmoothPlastic", x, base + 66, z)
	disc(list, "SoyBottleCap", 4, 10, P.Lacquer, "SmoothPlastic", x, base + 74, z)
	disc(list, "SoyBottleBand", 12, 22.6, P.Lacquer, "SmoothPlastic", x, base + 30, z)
	part(list, "SoyBottleLabel", "Block", v(0.6, 9, 8), WHITE, "SmoothPlastic", v(x + 11.2, base + 36, z))
	part(list, "SoyBottleLabelInk", "Block", v(0.7, 5, 1.2), BLACK, "SmoothPlastic", v(x + 11.3, base + 36, z))

	-- 쓰러진 병: 바닥은 호수에, 입구는 코스 왼쪽 벽 쪽으로 들려 있고 간장이 쏟아져요
	-- m5-24 반복 3: eye 뷰 왼쪽 아래를 덜 가리게 더 바깥·뒤로 옮기고 조금 작게
	local angle = 22
	local rad = math.rad(angle)
	local dx, dy = math.cos(rad), math.sin(rad)
	local cx, cy, cz = -112, -38, -84
	local len, dia = 54, 22
	local rot = v(0, 0, angle)
	local function along(t: number): Vec3
		return v(cx + dx * t, cy + dy * t, cz)
	end
	part(list, "ToppledBottle", "Cylinder", v(len, dia, dia), SOY_BOTTLE, "SmoothPlastic", along(0), rot).reflectance =
		0.15
	part(
		list,
		"ToppledBottleBase",
		"Cylinder",
		v(2, dia + 0.6, dia + 0.6),
		shade(SOY_BOTTLE, 0.7),
		"SmoothPlastic",
		along(-len / 2),
		rot
	)
	part(list, "ToppledBottleBand", "Cylinder", v(14, dia + 0.6, dia + 0.6), P.Lacquer, "SmoothPlastic", along(-6), rot)
	part(list, "ToppledBottleShoulder", "Ball", v(dia, dia, dia), SOY_BOTTLE, "SmoothPlastic", along(len / 2)).reflectance =
		0.15
	part(list, "ToppledBottleNeck", "Cylinder", v(12, 10, 10), SOY_BOTTLE, "SmoothPlastic", along(len / 2 + 18), rot)
	part(
		list,
		"ToppledBottleLip",
		"Cylinder",
		v(2, 11.5, 11.5),
		shade(SOY_BOTTLE, 1.3),
		"SmoothPlastic",
		along(len / 2 + 24),
		rot
	)
	-- 빠진 빨간 뚜껑 (호수 위에 떠 있음)
	disc(list, "ToppledBottleCap", 3, 9, P.Lacquer, "SmoothPlastic", -58, LAKE_Y - 0.5, -44)
	-- 쏟아지는 간장 줄기 (작은 반투명 — 큰 판 아님)
	local mouth = along(len / 2 + 25)
	local streamTop = mouth.y - 2
	local streamLen = streamTop - LAKE_Y
	local stream = part(
		list,
		"SoyStream",
		"Cylinder",
		v(streamLen, 4, 4),
		c(84, 40, 18),
		"Glass",
		v(mouth.x + 1.5, LAKE_Y + streamLen / 2, cz),
		UP
	)
	stream.transparency = 0.25
	stream.reflectance = 0.2
	local lip = part(list, "SoyStreamLip", "Ball", v(5, 4, 5), c(84, 40, 18), "Glass", v(mouth.x + 0.5, streamTop, cz))
	lip.transparency = 0.25
	-- 떨어지는 자리 물결 고리 + 거품
	append(
		list,
		MapKitShapes.ring(
			"SoySplash",
			5,
			1.2,
			0.6,
			10,
			c(96, 52, 26),
			"SmoothPlastic",
			v(mouth.x + 1.5, LAKE_Y + 0.3, cz)
		)
	)
	local splash =
		part(list, "SoySplashFx", "Block", v(4, 0.4, 4), LAKE, "SmoothPlastic", v(mouth.x + 1.5, LAKE_Y + 0.4, cz))
	splash.transparency = 1
	splash.particle = "Bubbles"
	splash.particleRate = 8
end

-- ④ 강판(오로시가네) 절벽: 오른쪽 늪 바깥, 호수에서 솟아 바깥으로 기운 금속 판 + 이빨 + 나무 손잡이
local function addGrater(list: { DecorSpec })
	local local_: { DecorSpec } = {}
	local W, H, T = 44, 92, 3
	-- 판 (로컬: 두께 X, 높이 Y, 폭 Z). 이빨은 -X 면(코스 쪽).
	part(local_, "GraterBoard", "Block", v(T, H, W), GRATER, "Metal", v(0, 0, 0)).reflectance = 0.3
	append(
		local_,
		MapKitShapes.lipTrim("GraterFrame", v(T + 0.4, 0, W), 0.8, 1, shade(GRATER, 0.8), "Metal", v(0, H / 2 - 0.5, 0))
	)
	-- 판 테두리 세로 띠
	for _, sz in { -1, 1 } do
		part(
			local_,
			"GraterEdge",
			"Block",
			v(T + 0.8, H, 1.2),
			shade(GRATER, 0.75),
			"Metal",
			v(0, 0, sz * (W / 2 + 0.6))
		)
	end
	for row = 0, 7 do
		for col = 0, 5 do
			local zz = -W / 2 + 4 + col * ((W - 8) / 5) + (if row % 2 == 0 then 0 else 3)
			if zz < W / 2 - 2 then
				part(
					local_,
					"GraterTooth",
					"Ball",
					v(1.8, 1.8, 1.8),
					shade(GRATER, 1.1),
					"Metal",
					v(-T / 2 - 0.3, -H / 2 + 46 + row * 5.5, zz)
				)
			end
		end
	end
	-- 손잡이 (위쪽, 나무 둥근 상자)
	append(
		local_,
		MapKitShapes.roundedBox(
			"GraterHandle",
			v(T + 2, 18, 14),
			P.Wood,
			"Wood",
			v(0, H / 2 + 9, 0),
			{ radius = 2, style = "vertical" }
		)
	)
	append(list, MapKitShapes.transform(local_, v(HALF + 34, -6, -34), v(0, 8, -14)))
	-- 판 아래 갈린 와사비 더미 (호수 위)
	part(list, "GratedWasabi", "Ball", v(18, 10, 16), P.Wasabi, "Pebble", v(HALF + 22, LAKE_Y + 2, -30))
	part(list, "GratedWasabi", "Ball", v(10, 6, 9), MOUNTAIN_SHADES[3], "Pebble", v(HALF + 16, LAKE_Y + 1.5, -40))
	append(
		list,
		MapKitShapes.capsule(
			"WasabiRoot",
			26,
			9,
			MOUNTAIN_SHADES[2],
			"Pebble",
			v(HALF + 30, LAKE_Y + 3, -18),
			v(0, 30, 10)
		)
	)
	-- 뿌리 잎 줄기
	for k = 0, 2 do
		part(
			list,
			"WasabiStem",
			"Cylinder",
			v(14, 1.2, 1.2),
			SCALLION,
			"SmoothPlastic",
			v(HALF + 42 + k * 2, LAKE_Y + 8 + k, -12 + k * 2),
			v(0, 30 + k * 12, 40 + k * 10)
		).anim =
			{ kind = "Sway", period = 4 + k, amount = 4 }
	end
end

-- 생강 더미 (분홍), 오른쪽 내리막 바깥. m5-24: 굽 달린 받침 위에.
local function addGinger(list: { DecorSpec })
	local x, z = HALF + 16, -128
	local baseY = 8
	disc(list, "GingerDish", 1.5, 16, P.Porcelain, "SmoothPlastic", x, baseY, z)
	disc(list, "GingerDishRim", 0.4, 16.4, P.PorcelainRim, "SmoothPlastic", x, baseY + 1.3, z)
	for i = 0, 7 do
		local y = baseY + 1.8 + i * 0.7
		local spread = 4 - i * 0.4
		local angle = i * 47
		local ox = math.cos(math.rad(angle)) * spread
		local oz = math.sin(math.rad(angle)) * spread
		part(
			list,
			"GingerSlice",
			"Block",
			v(6 - i * 0.4, 0.5, 4 - i * 0.3),
			if i % 3 == 0 then shade(GINGER, 1.1) else GINGER,
			"SmoothPlastic",
			v(x + ox, y, z + oz),
			v(8, angle, 6)
		)
	end
	disc(list, "GingerStand", baseY - LAKE_Y - 3, 4, P.RiceShade, "SmoothPlastic", x, LAKE_Y + 3, z)
	disc(list, "GingerStandFoot", 3, 12, P.Porcelain, "SmoothPlastic", x, LAKE_Y, z)
end

-- 결승선 체크무늬 (결승선 위에 얇게)
local function addFinishChecker(list: { DecorSpec })
	local lineZ = Layout.finishLineZ()
	local y = Layout.SLOPE2_HIGH + 0.45
	local cols = Layout.WIDTH
	for row = 0, 1 do
		for col = 0, cols - 1 do
			local color = if (row + col) % 2 == 0 then WHITE else BLACK
			part(
				list,
				"FinishChecker",
				"Block",
				v(1, 0.05, 0.5),
				color,
				"SmoothPlastic",
				v(-HALF + 0.5 + col, y, lineZ + 0.25 - row * 0.5)
			)
		end
	end
end

local LANTERN_X = 6
-- 늪 위 높은 곳의 종이 등. 소개 카메라 경로(x 0 근처)를 비켜 x 6에 둬요 (m4-02 QA Q1).
-- m5-24: 벽 위에 걸친 나무 들보에 줄로 매달리고, 따뜻한 빛을 내요 (보이는 광원).
local function addLanterns(list: { DecorSpec })
	local beamY = Layout.WALL_HEIGHT + 1
	local function lantern(x: number, y: number, z: number)
		local ball = part(list, "Lantern", "Ball", v(3, 3.4, 3), c(214, 96, 54), "Fabric", v(x, y, z))
		ball.light = { kind = "Point", color = c(255, 176, 96), brightness = 1.6, range = 26 }
		disc(list, "LanternCap", 0.4, 1.6, BLACK, "SmoothPlastic", x, y + 1.4, z)
		disc(list, "LanternCap", 0.4, 1.6, BLACK, "SmoothPlastic", x, y - 1.8, z)
		local cordLen = beamY - 1 - (y + 1.8)
		part(
			list,
			"LanternCord",
			"Cylinder",
			v(cordLen, 0.2, 0.2),
			BLACK,
			"SmoothPlastic",
			v(x, y + 1.8 + cordLen / 2, z),
			UP
		)
		append(
			list,
			MapKitShapes.roundedBox(
				"LanternBeam",
				v(Layout.WIDTH + 6, 2, 2),
				WOOD_DARK,
				"Wood",
				v(0, beamY, z),
				{ radius = 0.5, style = "vertical" }
			)
		)
	end
	lantern(LANTERN_X, 22, -24)
	lantern(LANTERN_X, 22, -48)
	lantern(-LANTERN_X, 36, -140)
end

-- 결승 문: 코스 벽 바깥 기둥 둘 + 벽 위 가로대 + 노렌 + 등불 (어디서든 보이는 높은 표지)
local function addFinishGate(list: { DecorSpec })
	local z = Layout.finishLineZ()
	local topY = Layout.SLOPE2_HIGH + 26 -- m5-40: 결승 단(40) 위 시야 상자(+12)보다 노렌 아래 끝이 높게
	for _, side in { -1, 1 } do
		local x = side * (HALF + 3)
		append(
			list,
			MapKitShapes.roundedBox(
				"FinishPillar",
				v(3, topY - LAKE_Y, 3),
				P.Lacquer,
				"Wood",
				v(x, (topY + LAKE_Y) / 2, z),
				{ radius = 0.6, style = "vertical" }
			)
		)
		local lamp = part(list, "FinishLamp", "Ball", v(3.4, 3.4, 3.4), c(255, 214, 120), "Neon", v(x, topY + 3, z))
		lamp.light = { kind = "Point", color = c(255, 200, 110), brightness = 2, range = 30 }
	end
	append(
		list,
		MapKitShapes.roundedBox(
			"FinishBeam",
			v(Layout.WIDTH + 12, 2.4, 3),
			P.LacquerDark,
			"Wood",
			v(0, topY, z),
			{ radius = 0.6 }
		)
	)
	append(
		list,
		MapKitShapes.roundedBox(
			"FinishBeam",
			v(Layout.WIDTH + 8, 1.6, 2.4),
			P.Lacquer,
			"Wood",
			v(0, topY - 3, z),
			{ radius = 0.5 }
		)
	)
	-- 노렌 (가로대 아래, 벽 위 높이 — 코스 공간 위)
	for i = 0, 4 do
		local x = -10 + i * 5
		part(
			list,
			"FinishNoren",
			"Block",
			v(4.6, 6, 0.3),
			if i % 2 == 0 then P.Noren else P.NorenLight,
			"Fabric",
			v(x, topY - 7.5, z)
		).anim =
			{ kind = "Sway", period = 3.5 + i * 0.3, amount = 3, axis = "X" }
	end
	part(list, "FinishNorenMark", "Ball", v(3, 3, 0.2), WHITE, "SmoothPlastic", v(0, topY - 7, z - 0.25))
end

---------------------------------------------------------------------------------- m5-24 세계

-- 간장 호수 + 접시 테두리 + 주방 카운터 + 방 벽 (BG)
local function addRoom(list: { DecorSpec })
	-- 호수 (불투명, 반사로 간장 광택)
	local lake = part(list, "SoyLake", "Cylinder", v(2, 860, 860), LAKE, "SmoothPlastic", v(0, LAKE_Y - 1, CZ), UP)
	lake.reflectance = 0.18
	lake.castShadow = false
	-- 호수 위 옅은 밝은 결 (간장 표면 반사 띠)
	for k = 0, 5 do
		local r = 40 + k * 55
		local glint = part(
			list,
			"SoyLakeGlint",
			"Cylinder",
			v(0.2, 18 + k * 6, 3 + k),
			c(120, 70, 36),
			"SmoothPlastic",
			v((if k % 2 == 0 then -1 else 1) * r, LAKE_Y + 0.05, CZ - 60 + k * 30),
			v(0, 30 * k, 90)
		)
		glint.castShadow = false
	end
	-- 도자기 접시 테두리 (호수를 담은 거대 간장 접시)
	append(list, MapKitShapes.ring("DishRim", 436, 22, 26, 36, P.Porcelain, "SmoothPlastic", v(0, LAKE_Y + 4, CZ)))
	append(
		list,
		MapKitShapes.ring("DishRimLine", 436, 10, 2, 36, P.PorcelainRim, "SmoothPlastic", v(0, LAKE_Y + 17.5, CZ))
	)
	append(list, MapKitShapes.ring("DishFoot", 452, 14, 12, 36, P.RiceShade, "SmoothPlastic", v(0, COUNTER_Y + 6, CZ)))
	-- 카운터 (어두운 나무, 판 세 장 shade)
	local counterShades = { WOOD_DARK, WOOD_MID, shade(WOOD_DARK, 0.85) }
	for i = 0, 2 do
		local w = 2 * WALL_DIST / 3
		part(
			list,
			"Counter",
			"Block",
			v(w, 8, 2 * WALL_DIST),
			counterShades[i + 1],
			"WoodPlanks",
			v(-WALL_DIST + w / 2 + i * w, COUNTER_Y - 4, CZ)
		).castShadow =
			false
	end
	-- 방 벽: 회반죽 + 아래 타일 띠
	local wallY = COUNTER_Y + WALL_H / 2
	local function wall(x: number, z: number, sx: number, sz: number, tint: number)
		part(list, "RoomWall", "Block", v(sx, WALL_H, sz), shade(PLASTER, tint), "Plaster", v(x, wallY, z)).castShadow =
			false
		local tx, tz = x - math.sign(x) * 3, z - math.sign(z) * 3
		part(
			list,
			"RoomTile",
			"Block",
			v(if sx < 20 then 4 else sx, 110, if sz < 20 then 4 else sz),
			shade(TILE, tint),
			"CeramicTiles",
			v(if sx < 20 then tx else x, COUNTER_Y + 55, if sz < 20 then tz else z)
		).castShadow =
			false
	end
	wall(0, CZ - WALL_DIST, 2 * WALL_DIST, 10, 1)
	wall(0, CZ + WALL_DIST, 2 * WALL_DIST, 10, 0.9)
	wall(-WALL_DIST, CZ, 10, 2 * WALL_DIST, 0.95)
	wall(WALL_DIST, CZ, 10, 2 * WALL_DIST, 0.85)
	-- 왼쪽 벽 창문 (차가운 오후 하늘빛 — 따뜻한 등과 온도 대비)
	for k = 0, 1 do
		local z = CZ - 160 + k * 260
		local x = -WALL_DIST + 6
		part(list, "Window", "Block", v(2, 150, 180), c(196, 222, 240), "Neon", v(x, 140, z)).castShadow = false
		append(list, MapKitShapes.lipTrim("WindowFrame", v(4, 0, 180), 8, 8, WOOD_DARK, "Wood", v(x + 2, 69, z)))
		part(list, "WindowFrame", "Block", v(6, 8, 196), WOOD_DARK, "Wood", v(x + 2, 219, z))
		part(list, "WindowFrame", "Block", v(6, 150, 6), WOOD_DARK, "Wood", v(x + 2, 140, z))
		part(list, "WindowFrame", "Block", v(6, 6, 180), WOOD_DARK, "Wood", v(x + 2, 140, z))
	end
	-- 뒤 벽 선반 + 병 실루엣 (안개 속)
	local shelfZ = CZ - WALL_DIST + 30
	for k = 0, 1 do
		local y = 60 + k * 110
		append(
			list,
			MapKitShapes.roundedBox(
				"WallShelf",
				v(700, 6, 50),
				WOOD_MID,
				"Wood",
				v(-60, y, shelfZ),
				{ radius = 2, style = "vertical" }
			)
		)
		for b = 0, 6 do
			local bx = -380 + b * 105 + (k * 40)
			local h = 50 + ((b * 37 + k * 13) % 4) * 12
			local d = 22 + ((b + k) % 3) * 6
			local col = if (b + k) % 3 == 0
				then SOY_BOTTLE
				elseif (b + k) % 3 == 1 then c(70, 96, 52)
				else c(160, 120, 70)
			disc(list, "ShelfBottle", h, d, col, "SmoothPlastic", bx, y + 3, shelfZ)
			disc(list, "ShelfBottle", 12, d * 0.4, col, "SmoothPlastic", bx, y + 3 + h, shelfZ)
		end
	end
	-- 멀리 호수 밖 거대한 병 실루엣 (오른쪽 앞·왼쪽 뒤)
	local silhouettes = {
		{ x = 330, z = CZ - 300, h = 220, d = 80 },
		{ x = -360, z = CZ - 330, h = 180, d = 70 },
		{ x = 380, z = CZ + 160, h = 160, d = 64 },
	}
	for _, s in silhouettes do
		disc(list, "FarBottle", s.h, s.d, SOY_BOTTLE, "SmoothPlastic", s.x, COUNTER_Y, s.z).castShadow = false
		part(list, "FarBottle", "Ball", v(s.d, s.d, s.d), SOY_BOTTLE, "SmoothPlastic", v(s.x, COUNTER_Y + s.h, s.z)).castShadow =
			false
		disc(
			list,
			"FarBottle",
			s.d * 0.5,
			s.d * 0.35,
			SOY_BOTTLE,
			"SmoothPlastic",
			s.x,
			COUNTER_Y + s.h + s.d * 0.3,
			s.z
		)
		disc(
			list,
			"FarBottleCap",
			s.d * 0.2,
			s.d * 0.42,
			P.LacquerDark,
			"SmoothPlastic",
			s.x,
			COUNTER_Y + s.h + s.d * 0.8,
			s.z
		)
	end
	-- 오른쪽 멀리 밥공기·찻잔 (카운터 위)
	append(
		list,
		MapKitShapes.rimDisc(
			"FarBowl",
			120,
			50,
			P.Porcelain,
			"SmoothPlastic",
			v(-300, COUNTER_Y + 25, CZ + 260),
			{ rimColor = P.PorcelainRim, rimWidth = 4, rimHeight = 4, segments = 20 }
		)
	)
	disc(list, "FarTeaCup", 80, 80, c(120, 140, 110), "SmoothPlastic", 300, COUNTER_Y, CZ + 330)
end

-- 코스를 받친 나무 게타(판 + 다리) + 판 가장자리 립 (FG 두께감)
local function addGeta(list: { DecorSpec })
	local length = Layout.totalLength()
	local midZ = Layout.START.front - length / 2
	append(
		list,
		MapKitShapes.roundedBox(
			"GetaBoard",
			v(Layout.WIDTH + 4, 5, length + 4),
			WOOD_DARK,
			"WoodPlanks",
			v(0, -Layout.FLOOR_THICKNESS - 2.5, midZ),
			{ radius = 1, style = "vertical" }
		)
	)
	-- 판 가장자리 밝은 립 (판정 바닥 윗면보다 0.15 낮게, 벽 바깥)
	append(
		list,
		MapKitShapes.lipTrim(
			"GetaLip",
			v(Layout.WIDTH + 1, 0, length + 1),
			0.8,
			1.6,
			P.WoodLight,
			"Wood",
			v(0, -0.95, midZ)
		)
	)
	-- 다리 (호수 속으로)
	for _, z in { -10, -66, -122, -166, -228, -290, -350, -404 } do
		append(
			list,
			MapKitShapes.roundedBox(
				"GetaLeg",
				v(Layout.WIDTH + 8, -Layout.FLOOR_THICKNESS - 5 - LAKE_Y + 4, 8),
				shade(WOOD_DARK, 0.9),
				"WoodPlanks",
				v(0, (LAKE_Y - 4 - Layout.FLOOR_THICKNESS - 5) / 2, z),
				{ radius = 1.2, style = "vertical" }
			)
		)
		-- 다리가 호수에 닿는 물결
		append(
			list,
			MapKitShapes.ring("GetaRipple", 18, 1, 0.4, 10, c(92, 54, 30), "SmoothPlastic", v(0, LAKE_Y + 0.2, z))
		)
	end
	-- 판 옆면 밥알 무리 (흰 캡슐 몇 개, 벽 바깥 판 위)
	local rng = MapKitShapes.rng(24)
	for k = 0, 17 do
		local side = if k % 2 == 0 then -1 else 1
		local z = -6 - k * 22 + rng:range(-2, 2) -- m5-40: 길어진 판 전체에 듬성듬성
		append(
			list,
			MapKitShapes.capsule(
				"RiceGrain",
				2.2,
				1,
				if k % 3 == 0 then P.RiceShade else WHITE,
				"SmoothPlastic",
				v(side * (HALF + 1.6), -1.4, z),
				v(0, rng:range(0, 180), 0)
			)
		)
	end
end

-- ③ 반쯤 잠긴 젓가락 + 연근 조각 + 떠 있는 김·파 (호수 MG/FG)
local function addLakeProps(list: { DecorSpec })
	-- 젓가락 쌍 (호수에 비스듬히 꽂힘)
	local sticks = {
		{ x = 30, z = -4, ry = 20, rz = 62 },
		{ x = -34, z = -150, ry = -30, rz = 58 },
		{ x = 40, z = -112, ry = 150, rz = 66 },
	}
	for i, s in ipairs(sticks) do
		for k = 0, 1 do
			append(
				list,
				MapKitShapes.capsule(
					"Chopstick",
					52,
					1.6,
					if k == 0 then P.WoodLight else P.Wood,
					"Wood",
					v(s.x + k * 2.4, LAKE_Y + 18, s.z + k * 1.5),
					v(0, s.ry + k * 6, s.rz - k * 4)
				)
			)
		end
		-- 젓가락 끝 옻칠 (호수 위쪽 끝)
		local rad = math.rad(s.rz)
		local ry = math.rad(s.ry)
		local tipX = s.x + math.cos(rad) * 24 * math.cos(ry)
		local tipY = LAKE_Y + 18 + math.sin(rad) * 24
		local tipZ = s.z - math.cos(rad) * 24 * math.sin(ry)
		part(
			list,
			"ChopstickTip",
			"Ball",
			v(2, 2, 2),
			if i == 2 then P.Lacquer else P.LacquerDark,
			"SmoothPlastic",
			v(tipX, tipY, tipZ)
		)
		append(
			list,
			MapKitShapes.ring(
				"ChopstickRipple",
				4,
				0.8,
				0.3,
				8,
				c(96, 56, 30),
				"SmoothPlastic",
				v(s.x - 9, LAKE_Y + 0.2, s.z)
			)
		)
	end
	-- 연근 조각 (구멍 7개, 반쯤 잠김)
	local lotus = {
		{ x = -40, z = -10, d = 22, tilt = 14 },
		{ x = 42, z = -150, d = 26, tilt = -10 },
		{ x = -46, z = -30, d = 16, tilt = 8 },
	}
	for _, l in lotus do
		local local_: { DecorSpec } = {}
		append(
			local_,
			MapKitShapes.rimDisc(
				"LotusSlice",
				l.d,
				3,
				LOTUS,
				"SmoothPlastic",
				v(0, 0, 0),
				{ rimColor = shade(LOTUS, 0.85), rimWidth = 1.2, rimHeight = 0.8, segments = 14 }
			)
		)
		part(
			local_,
			"LotusHole",
			"Cylinder",
			v(3.3, l.d * 0.16, l.d * 0.16),
			LOTUS_HOLE,
			"SmoothPlastic",
			v(0, 0.05, 0),
			UP
		)
		for k = 0, 5 do
			local a = math.rad(k * 60 + 15)
			local r = l.d * 0.3
			part(
				local_,
				"LotusHole",
				"Cylinder",
				v(3.3, l.d * 0.18, l.d * 0.18),
				LOTUS_HOLE,
				"SmoothPlastic",
				v(math.cos(a) * r, 0.05, math.sin(a) * r),
				UP
			)
		end
		append(list, MapKitShapes.transform(local_, v(l.x, LAKE_Y + 0.4, l.z), v(l.tilt, 0, l.tilt * 0.5)))
	end
	-- 떠 있는 김 조각 (Bob)
	local nori = {
		{ -22, -20 },
		{ 24, -48 },
		{ -26, -92 },
		{ 22, -78 },
		{ -20, -132 },
		{ 26, -170 },
		{ -24, 4 },
		{ 18, 10 },
	}
	for i, n in ipairs(nori) do
		part(
			list,
			"NoriFlake",
			"Block",
			v(8 + (i % 3) * 2, 0.4, 6 + (i % 2) * 2),
			if i % 2 == 0 then NORI_GREEN else BLACK,
			"Fabric",
			v(n[1], LAKE_Y + 0.4, n[2]),
			v(0, i * 37, 0)
		).anim =
			{ kind = "Bob", period = 4 + (i % 3), amount = 0.5 }
	end
	-- 파 줄기 (호수에서 솟아 흔들림)
	local scallions = { { -24, -26 }, { 22, -64 }, { -22, -112 }, { 24, -140 }, { -26, -170 }, { 26, -18 } }
	for i, s in ipairs(scallions) do
		local h = 26 + (i % 3) * 6
		part(
			list,
			"Scallion",
			"Cylinder",
			v(h, 1.8, 1.8),
			if i % 2 == 0 then SCALLION else shade(SCALLION, 0.8),
			"SmoothPlastic",
			v(s[1], LAKE_Y + h / 2, s[2]),
			v(0, i * 50, 90 + (if i % 2 == 0 then 8 else -8))
		).anim =
			{ kind = "Sway", period = 5 + (i % 3), amount = 3, axis = "X" }
		part(
			list,
			"ScallionRing",
			"Cylinder",
			v(0.6, 3, 3),
			c(220, 236, 196),
			"SmoothPlastic",
			v(s[1], LAKE_Y + 0.3, s[2]),
			UP
		)
	end
	-- 호수 위 낮은 김 (Steam, 코스 가장자리 밖)
	for k, z in { -30, -100, -160 } do
		local fx = part(
			list,
			"LakeSteam",
			"Block",
			v(10, 1, 10),
			LAKE,
			"SmoothPlastic",
			v((if k % 2 == 0 then 1 else -1) * 30, LAKE_Y + 1, z)
		)
		fx.transparency = 1
		fx.particle = "Steam"
		fx.particleRate = 2
		fx.castShadow = false
	end
end

-- ⑤ 결승 쪽 날치알 언덕 (호수에서 솟은 주황 둔덕 + 알 무리, 몇 개는 숨 쉬듯 Pulse)
local function addTobikoHills(list: { DecorSpec })
	local mounds = {
		{ x = -34, y = -16, z = -164, d = 40 },
		{ x = -48, y = -26, z = -146, d = 36 },
		{ x = 40, y = -20, z = -176, d = 38 },
		{ x = 54, y = -28, z = -158, d = 34 },
		{ x = -30, y = -30, z = -186, d = 30 },
	}
	local rng = MapKitShapes.rng(77)
	local pulses = 0
	for i, m in ipairs(mounds) do
		part(
			list,
			"TobikoMound",
			"Ball",
			v(m.d, m.d * 0.85, m.d),
			TOBIKO_SHADES[(i - 1) % 3 + 1],
			"Sand",
			v(m.x, m.y, m.z)
		)
		local r = m.d / 2
		local topY = m.y + r * 0.85
		for k = 0, 9 do
			local a = rng:range(0, math.pi * 2)
			local rr = rng:range(0, r * 0.7)
			local h = math.sqrt(math.max(1 - (rr / r) ^ 2, 0))
			local d = rng:range(2.2, 3.4)
			local egg = part(
				list,
				"TobikoEgg",
				"Ball",
				v(d, d, d),
				TOBIKO_SHADES[(k % 3) + 1],
				"Glass",
				v(m.x + math.cos(a) * rr, m.y + (topY - m.y) * h + d * 0.2, m.z + math.sin(a) * rr)
			)
			egg.reflectance = 0.15
			egg.transparency = 0.1
			egg.castShadow = false
			if k % 4 == 0 and pulses < 12 then
				pulses += 1
				egg.anim = { kind = "Pulse", period = 2.5 + (k % 3) * 0.6, amount = 0.08 }
			end
		end
	end
end

-- 와사비 산 정상 위 셰프 주방 등 (좁은 그림자 SpotLight — 산 실루엣이 길에 그림자)
local function addPendantLamp(list: { DecorSpec })
	local x, y, z = -34, 62, -84
	part(list, "PendantCord", "Cylinder", v(160, 0.6, 0.6), BLACK, "SmoothPlastic", v(x, y + 82, z), UP)
	append(
		list,
		MapKitShapes.rimDisc(
			"PendantShade",
			16,
			2,
			c(60, 70, 64),
			"Metal",
			v(x, y + 3, z),
			{ rimColor = c(40, 46, 42), rimWidth = 1, rimHeight = 3, segments = 14 }
		)
	)
	part(list, "PendantShadeTop", "Ball", v(14, 8, 14), c(60, 70, 64), "Metal", v(x, y + 5, z)).reflectance = 0.25
	local bulb = part(list, "PendantBulb", "Ball", v(6, 6, 6), c(255, 236, 190), "Neon", v(x, y, z))
	bulb.light = {
		kind = "Spot",
		color = c(255, 232, 196),
		brightness = 3,
		range = 60,
		angle = 70,
		face = "Bottom",
		shadows = true,
	}
	bulb.castShadow = false
end

---------------------------------------------------------------------------------- m5-40 새 구간

-- 김 징검다리 발판(판정: 김 기둥 + 밥 판) 발치 물결
local function addStoneWraps(list: { DecorSpec })
	local bed = Layout.RIVER_BED_Y
	for _, stone in Layout.STONES do
		local w, d = stone.width, stone.depth
		-- 강물에 닿는 자리 물결 (얇은 고리)
		part(
			list,
			"StoneRipple",
			"Block",
			v(w + 1.6, 0.1, d + 1.6),
			c(96, 54, 28),
			"SmoothPlastic",
			v(stone.x, bed + 0.36, stone.z)
		)
	end
end

-- 간장 강이 벽 밖으로 넘쳐 호수로 떨어지는 폭포 줄기 둘
local function addRiverBanks(list: { DecorSpec })
	-- 강물이 벽 밖 게타 가장자리로 넘쳐 호수로 떨어지는 줄기 (양옆, 작은 반투명 원기둥)
	local bed = Layout.RIVER_BED_Y
	for k, z in { -190, -222 } do
		local side = if k == 1 then -1 else 1
		local x = side * (HALF + 3)
		local len = bed - LAKE_Y
		local stream =
			part(list, "RiverFall", "Cylinder", v(len, 3, 3), c(84, 40, 18), "Glass", v(x, LAKE_Y + len / 2, z), UP)
		stream.transparency = 0.25
		stream.reflectance = 0.2
		local lip =
			part(list, "RiverFallLip", "Ball", v(4, 3, 4), c(84, 40, 18), "Glass", v(x - side * 0.6, bed + 0.5, z))
		lip.transparency = 0.25
		append(
			list,
			MapKitShapes.ring("RiverFallSplash", 4, 1, 0.5, 10, c(96, 52, 26), "SmoothPlastic", v(x, LAKE_Y + 0.3, z))
		)
	end
	local foam =
		part(list, "RiverFallFx", "Block", v(3, 0.4, 3), LAKE, "SmoothPlastic", v(HALF + 3, LAKE_Y + 0.4, -222))
	foam.transparency = 1
	foam.particle = "Bubbles"
	foam.particleRate = 5
end

-- 와사비 산 2: 산 1과 반대로 오른쪽(+x) 벽 바깥이 높은 층층 언덕 + 호수에서 솟은 덩어리
local function addHills2(list: { DecorSpec })
	local centerZ = (Layout.MOUNTAIN2.front + Layout.MOUNTAIN2.back) / 2
	local base = Layout.MOUNTAIN2_BASE
	local layers = {
		{ w = 20, h = 5, d = 52 },
		{ w = 15, h = 5, d = 42 },
		{ w = 10, h = 5, d = 30 },
		{ w = 6, h = 4, d = 18 },
	}
	for i, layer in layers do
		local inner = HALF + 0.75
		append(
			list,
			MapKitShapes.bevelBox(
				"WasabiHill",
				v(layer.w, layer.h, layer.d),
				HILLS[(i - 1) % #HILLS + 1],
				"Pebble",
				v(inner + layer.w / 2, base + (i - 1) * 5 + layer.h / 2, centerZ - 2),
				1.2
			)
		)
	end
	-- 왼쪽 벽 바깥은 낮은 언덕 두 단 (느린 길 쪽)
	for i = 1, 2 do
		local layer = layers[i + 1]
		append(
			list,
			MapKitShapes.bevelBox(
				"WasabiHill",
				v(layer.w, layer.h, layer.d),
				HILLS[i],
				"Pebble",
				v(-(HALF + 0.75 + layer.w / 2), base + (i - 1) * 5 + layer.h / 2, centerZ + 6),
				1.2
			)
		)
	end
	part(list, "HillRiceCap", "Ball", v(6, 6, 6), WHITE, "Sand", v(HALF + 3.75, base + 21, centerZ - 2))
	for k = 0, 3 do
		local d = 2.4 - k * 0.3
		part(
			list,
			"HillRiceDrip",
			"Ball",
			v(d, d, d),
			P.RiceShade,
			"Sand",
			v(HALF + 5 + k * 1.6, base + 19.6 - k * 1.4, centerZ + (if k % 2 == 0 then 3 else -3.5))
		)
	end
	-- 받침 덩어리 (호수에서 솟아 언덕을 받쳐요)
	local masses = {
		{ d = 40, x = 32, y = 0, z = centerZ + 8, s = 1 },
		{ d = 46, x = 46, y = -12, z = centerZ - 18, s = 2 },
		{ d = 54, x = 40, y = -26, z = centerZ + 28, s = 4 },
		{ d = 30, x = 58, y = 6, z = centerZ - 2, s = 3 },
		{ d = 28, x = 22, y = 8, z = centerZ - 14, s = 1 },
		{ d = 34, x = -30, y = -8, z = centerZ + 14, s = 4 },
		{ d = 26, x = -22, y = 6, z = centerZ - 6, s = 2 },
	}
	for _, m in masses do
		part(list, "WasabiMass", "Ball", v(m.d, m.d * 0.9, m.d), MOUNTAIN_SHADES[m.s], "Pebble", v(m.x, m.y, m.z))
	end
	local s =
		part(list, "WasabiSparkle", "Block", v(4, 1, 8), P.Wasabi, "SmoothPlastic", v(HALF + 8, base + 16, centerZ))
	s.transparency = 1
	s.particle = "Sparkle"
	s.particleRate = 3
	s.castShadow = false
	-- 패드 위 울퉁불퉁한 와사비 공 (패드 위로 0.5 이하)
	for _, pad in Layout.WASABI_PADS_2 do
		local top = base + Layout.PAD_THICKNESS
		for i = 0, 2 do
			for j = 0, 1 do
				local d = if (i + j) % 2 == 0 then 0.8 else 0.6
				local x = pad.x - pad.width / 2 + 0.8 + i * ((pad.width - 1.6) / 2)
				local z = pad.z - pad.depth / 4 + j * (pad.depth / 2)
				part(list, "WasabiPadBump", "Ball", v(d, d, d), WASABI_BUMP, "Sand", v(x, top + 0.45 - d / 2, z))
			end
		end
	end
end

-- 히어로: 내리막 2 꼭대기 양옆의 거대 군함말이 두 개 — 위에 날치알이 수북하고, 두 레인으로 공이 굴러 나오는 원인.
-- 실제 군함 지름 4 cm → 40 (작은 초밥 눈에는 탑). 김 띠 + 밥 + 날치알 산 + 흘러내린 알.
local function addGunkanTowers(list: { DecorSpec })
	local topY = Layout.SLOPE2_HIGH
	for k, side in { -1, 1 } do
		local x = side * (HALF + 24)
		local z = Layout.BALL_SPAWN_Z_2 + 6
		local base = LAKE_Y
		local h = topY + 8 - base -- 받침 기둥 위 밥 윗면이 결승 단보다 8 높게
		-- 도자기 굽 받침
		disc(list, "GunkanStand", 4, 44, P.Porcelain, "SmoothPlastic", x, base, z).reflectance = 0.06
		disc(list, "GunkanStandRim", 1, 45, P.PorcelainRim, "SmoothPlastic", x, base + 4, z)
		-- 김 띠 (원기둥) + 위 테두리 밝은 김
		disc(list, "GunkanNori", h - 5, 40, NORI_GREEN, "Fabric", x, base + 5, z)
		disc(list, "GunkanNoriEdge", 1.2, 41, shade(NORI_GREEN, 1.4), "Fabric", x, base + h - 1.2, z)
		disc(list, "GunkanRice", 2, 37, WHITE, "Sand", x, base + h - 2.2, z)
		-- 날치알 산 (주황 공 무리) + 반짝임
		part(list, "GunkanTobiko", "Ball", v(40, 13, 40), TOBIKO_SHADES[k], "Sand", v(x, base + h + 1, z))
		-- 김 이음매 (코스 쪽 면에 짙은 세로 띠)
		part(
			list,
			"GunkanNoriSeam",
			"Block",
			v(1.2, h - 6, 3),
			shade(NORI_GREEN, 0.7),
			"Fabric",
			v(x - side * 19.8, base + 5 + (h - 6) / 2, z)
		)
		local rng = MapKitShapes.rng(400 + k)
		for e = 0, 17 do
			local a = rng:range(0, math.pi * 2)
			local rr = rng:range(3, 17)
			local d = rng:range(2.6, 3.8)
			local egg = part(
				list,
				"TobikoEgg",
				"Ball",
				v(d, d, d),
				TOBIKO_SHADES[(e % 3) + 1],
				"Glass",
				v(
					x + math.cos(a) * rr,
					base + h + 1 + 6.5 * math.sqrt(math.max(1 - (rr / 20) ^ 2, 0)),
					z + math.sin(a) * rr
				)
			)
			egg.reflectance = 0.15
			egg.transparency = 0.1
			egg.castShadow = false
			if e % 5 == 0 then
				egg.anim = { kind = "Pulse", period = 2.4 + e * 0.15, amount = 0.08 }
			end
		end
		-- 코스 쪽으로 흘러내린 알 줄기 (벽 바깥, 결승 단 높이 근처)
		for e = 0, 3 do -- 벽(x 12) 바깥에서 멈춰요
			part(
				list,
				"TobikoSpill",
				"Ball",
				v(2.2, 2.2, 2.2),
				TOBIKO_SHADES[(e % 3) + 1],
				"Sand",
				v(x - side * (16 + e * 1.4), base + h - 1 - e * 1.6, z + 4 - e * 1.2)
			)
		end
		-- 군함 옆 오이 조각 장식 (색 대비 — 와사비와 다른 진녹)
		part(
			list,
			"GunkanCucumber",
			"Cylinder",
			v(1.6, 12, 12),
			c(70, 120, 60),
			"SmoothPlastic",
			v(x + side * 4, base + h + 9, z - 8),
			v(20, 0, 70)
		)
	end
	-- 결승 문 뒤 날치알 빛 (따뜻한 주황 — 보이는 원인: 결승 위 등)
end

-- 뒷부분 위 종이 등. 징검다리 위는 옛 등처럼 벽 위 들보(49)에, 내리막 2 위는 바닥이 높아서(시야 상자 위 끝 44~52)
-- 벽 위에 세운 짧은 기둥이 받친 더 높은 들보(60)에 매달려요. 소개 카메라 경로(x 0)를 비켜 x ±6.
local function addBackLanterns(list: { DecorSpec })
	local spots = {
		{ x = 6, y = 36, z = -205, beamY = Layout.WALL_HEIGHT + 1, lit = true }, -- 징검다리 위
		{ x = 6, y = 57, z = -352, beamY = 64, lit = true }, -- 내리막 2 위
	}
	for _, sp in spots do
		local ball = part(list, "Lantern", "Ball", v(3.6, 4, 3.6), c(214, 96, 54), "Fabric", v(sp.x, sp.y, sp.z))
		if sp.lit then
			ball.light = { kind = "Point", color = c(255, 176, 96), brightness = 1.6, range = 28 }
		end
		disc(list, "LanternCap", 0.5, 1.8, BLACK, "SmoothPlastic", sp.x, sp.y + 1.6, sp.z)
		disc(list, "LanternCap", 0.5, 1.8, BLACK, "SmoothPlastic", sp.x, sp.y - 2.1, sp.z)
		local cordLen = sp.beamY - 1 - (sp.y + 2.1)
		part(
			list,
			"LanternCord",
			"Cylinder",
			v(cordLen, 0.2, 0.2),
			BLACK,
			"SmoothPlastic",
			v(sp.x, sp.y + 2.1 + cordLen / 2, sp.z),
			UP
		)
		append(
			list,
			MapKitShapes.roundedBox(
				"LanternBeam",
				v(Layout.WIDTH + 6, 2, 2),
				WOOD_DARK,
				"Wood",
				v(0, sp.beamY, sp.z),
				{ radius = 0.5, style = "vertical" }
			)
		)
		if sp.beamY > Layout.WALL_HEIGHT + 1 then
			for _, side in { -1, 1 } do
				part(
					list,
					"LanternPost",
					"Block",
					v(1.6, sp.beamY - Layout.WALL_HEIGHT, 1.6),
					WOOD_DARK,
					"Wood",
					v(side * (HALF + 2), (sp.beamY + Layout.WALL_HEIGHT) / 2, sp.z)
				)
			end
		end
	end
end

-- 뒷부분 호수 소품: 떠 있는 김 조각·파 줄기·연근 (코스 벽 바깥 20~60)
local function addBackLakeProps(list: { DecorSpec })
	local nori = { { -24, -196 }, { 22, -236 }, { -26, -268 }, { 24, -318 }, { -22, -350 }, { 26, -392 } }
	for i, n in ipairs(nori) do
		part(
			list,
			"NoriFlake",
			"Block",
			v(8 + (i % 3) * 2, 0.4, 6 + (i % 2) * 2),
			if i % 2 == 0 then NORI_GREEN else BLACK,
			"Fabric",
			v(n[1], LAKE_Y + 0.4, n[2]),
			v(0, i * 41, 0)
		).anim =
			{ kind = "Bob", period = 4 + (i % 3), amount = 0.5 }
	end
	local scallions = { { 24, -206 }, { -26, -330 }, { 22, -372 } }
	for i, sc in ipairs(scallions) do
		local h = 30 + (i % 2) * 6
		part(
			list,
			"Scallion",
			"Cylinder",
			v(h, 1.8, 1.8),
			if i % 2 == 0 then SCALLION else shade(SCALLION, 0.8),
			"SmoothPlastic",
			v(sc[1], LAKE_Y + h / 2, sc[2]),
			v(0, i * 50, 90 + (if i % 2 == 0 then 8 else -8))
		).anim =
			{ kind = "Sway", period = 5 + i, amount = 3, axis = "X" }
	end
	local lotus = { { x = -44, z = -232, d = 24, tilt = 10 }, { x = 46, z = -340, d = 20, tilt = -12 } }
	for _, l in lotus do
		local local_: { DecorSpec } = {}
		append(
			local_,
			MapKitShapes.rimDisc(
				"LotusSlice",
				l.d,
				3,
				LOTUS,
				"SmoothPlastic",
				v(0, 0, 0),
				{ rimColor = shade(LOTUS, 0.85), rimWidth = 1.2, rimHeight = 0.8, segments = 14 }
			)
		)
		part(
			local_,
			"LotusHole",
			"Cylinder",
			v(3.3, l.d * 0.16, l.d * 0.16),
			LOTUS_HOLE,
			"SmoothPlastic",
			v(0, 0.05, 0),
			UP
		)
		for k = 0, 5 do
			local a = math.rad(k * 60 + 15)
			local r = l.d * 0.3
			part(
				local_,
				"LotusHole",
				"Cylinder",
				v(3.3, l.d * 0.18, l.d * 0.18),
				LOTUS_HOLE,
				"SmoothPlastic",
				v(math.cos(a) * r, 0.05, math.sin(a) * r),
				UP
			)
		end
		append(list, MapKitShapes.transform(local_, v(l.x, LAKE_Y + 0.4, l.z), v(l.tilt, 0, l.tilt * 0.5)))
	end
end

function SoySwampArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPuddleRims(list)
	addPuddleBubbles(list) -- m5-20 ①
	addWasabiBumps(list)
	addHills(list)
	addTobikoBowl(list)
	addSoyBottle(list)
	addGrater(list)
	addGinger(list)
	addFinishChecker(list)
	addLanterns(list)
	addFogPanels(list) -- m5-20 ③ (m5-24: 방 벽 바깥)
	-- m5-24
	addRoom(list)
	addGeta(list)
	addLakeProps(list)
	addTobikoHills(list)
	addFinishGate(list)
	addPendantLamp(list)
	-- m5-40 길이 늘리기: 새 구간
	addStoneWraps(list)
	addRiverBanks(list)
	addHills2(list)
	addGunkanTowers(list)
	addBackLanterns(list)
	addBackLakeProps(list)
	return list
end

function SoySwampArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 16, 4), lookAt = v(0, 2, -30) }, -- 출발 위, 간장 늪
		{ pos = v(-4, 26, -50), lookAt = v(-4, 6, -72) }, -- 와사비 패드 → 절벽
		-- m5-20 ⑤ 와사비 산 정상 위 반전 샷. m5-24 (m5-20 QA B3): 바로 아래를 보면 lookAt이 퇴화해 굴러갈 수 있어
		-- 앞(-Z)으로 조금 기울여요 (수평 방향이 계속 앞이라 m5-20 QA AC12도 그대로).
		{ pos = v(0, 36, -86), lookAt = v(0, 12, -96) },
		-- m5-40: 쉼터 위 높은 곳에서 새 뒷부분(김 징검다리 → 와사비 산 2 → 내리막 2 → 결승 문)을 한 번에
		{ pos = v(0, 64, -150), lookAt = v(0, 30, -262) },
		{ pos = v(0, 12, 10), lookAt = v(0, 4, -30) }, -- 출발선 뒤 (내 자리)
	}
end

local function box(minX: number, maxX: number, back: number, front: number, floorY: number, topFloorY: number?): Bounds
	return {
		min = v(minX, floorY + 2, back),
		max = v(maxX, (topFloorY or floorY) + 12, front),
	}
end

function SoySwampArt.courseVolume(): { Bounds }
	local h = Layout.MOUNTAIN_HEIGHT
	local body = Layout.MOUNTAIN_BODY
	local bodyRight = body.x + body.width / 2
	local body2 = Layout.MOUNTAIN2_BODY
	local body2Left = body2.x - body2.width / 2
	local top2 = Layout.MOUNTAIN2_BASE + Layout.MOUNTAIN2_HEIGHT
	return {
		-- 출발·늪·산 앞 평지 (바닥 0)
		box(-HALF, HALF, Layout.APPROACH.back, Layout.START.front, 0),
		-- 산 몸통 꼭대기 (바닥 12)
		box(-HALF, bodyRight, Layout.MOUNTAIN.back, Layout.MOUNTAIN.front, h),
		-- 오른쪽 경사로 + 지면 통로 (바닥 0 → 12)
		box(bodyRight, HALF, Layout.MOUNTAIN.back, Layout.MOUNTAIN.front, 0, h),
		-- 날치알 내리막 (바닥 12 → 20)
		box(-HALF, HALF, Layout.SLOPE.back, Layout.SLOPE.front, Layout.SLOPE_LOW, Layout.SLOPE_HIGH),
		-- m5-40 쉼터 (바닥 20)
		box(-HALF, HALF, Layout.LANDING.back, Layout.LANDING.front, Layout.SLOPE_HIGH),
		-- m5-40 김 징검다리 (강바닥 16 ~ 발판 20)
		box(-HALF, HALF, Layout.RIVER.back, Layout.RIVER.front, Layout.RIVER_BED_Y, Layout.SLOPE_HIGH),
		-- m5-40 산 2 앞 평지 (바닥 20)
		box(-HALF, HALF, Layout.APPROACH2.back, Layout.APPROACH2.front, Layout.MOUNTAIN2_BASE),
		-- m5-40 산 2 몸통 꼭대기 (바닥 32) + 왼쪽 경사로·통로 (20 → 32)
		box(body2Left, HALF, Layout.MOUNTAIN2.back, Layout.MOUNTAIN2.front, top2),
		box(-HALF, body2Left, Layout.MOUNTAIN2.back, Layout.MOUNTAIN2.front, Layout.MOUNTAIN2_BASE, top2),
		-- m5-40 날치알 내리막 2 (바닥 32 → 40)
		box(-HALF, HALF, Layout.SLOPE2.back, Layout.SLOPE2.front, Layout.SLOPE2_LOW, Layout.SLOPE2_HIGH),
		-- 결승 (바닥 40)
		box(-HALF, HALF, Layout.FINISH.back, Layout.FINISH.front, Layout.SLOPE2_HIGH),
	}
end

return SoySwampArt
