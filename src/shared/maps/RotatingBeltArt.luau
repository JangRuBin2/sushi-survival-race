--!strict
-- 회전 벨트 아트 (m4-02 → m5-20 → m5-24): 장식·소개 카메라·색·조명을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   RotatingBeltArt.COLORS          판정 파츠(바닥·벽·종지·젓가락)에 칠할 색 { r, g, b }
--   RotatingBeltArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   RotatingBeltArt.introCamera()   라운드 소개 경유점 (출발 위 → 젓가락 → 병목 반전 → 결승 → 출발선 뒤 높이 12)
--   RotatingBeltArt.courseVolume()  장식이 들어가면 안 되는 상자들 (구간마다 벽 안쪽, 바닥 위 2~12)
--   RotatingBeltArt.BUDGET          "Extended" (m5-24: 장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
--   RotatingBeltArt.LIGHTING        맵 조명 분위기 (m5-24: MapLighting.PRESETS 초안을 옮겨 다듬음)
--   RotatingBeltArt.GUEST_EYE       새 손님 눈 (FACE_EYE처럼 깜빡여요 — 기존 FACE_EYE 6개 수는 그대로)
-- 코스 치수는 RotatingBelt.luau의 값을 그대로 옮겨 적었어요 (판정 지오메트리는 그쪽이 정해요).
-- 좌표는 origin 기준 로컬: x 좌우, y 위(바닥 윗면 0), z 0이 출발선이고 -Z로 갈수록 결승.
--
-- m5-24 "저녁 손님 몰리는 회전초밥집 카운터": 코스(벨트)는 가게 한가운데 카운터 높이에 떠 있고, 아래 92 studs(=92 cm,
-- 카운터 높이)에 마루 바닥, 양옆에 손님 카운터·손님, 끝에 셰프 작업대·진열 케이스·메뉴판 벽, 옆 벽 창밖은 해 질 녘
-- 파란 거리, 천장 대들보와 종이등. 낙하선(origin - 40)보다 마루가 52 아래예요. 벽·천장은 그림자를 만들지 않아요
-- (castShadow = false — 해가 창빛처럼 코스를 비추게).

local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }
export type Section = { name: string, front: number, back: number, half: number }

local P = MapKitLogic.PALETTE
local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local RotatingBeltArt = {}

RotatingBeltArt.BUDGET = "Extended"

-- RotatingBelt.build와 같은 구간 (half = 벽 안쪽 폭의 절반)
RotatingBeltArt.SECTIONS = {
	{ name = "Start", front = 0, back = -14, half = 10 },
	{ name = "BeltA", front = -14, back = -48, half = 8 },
	{ name = "Narrow", front = -48, back = -72, half = 3 },
	{ name = "BeltB", front = -72, back = -106, half = 8 },
	{ name = "Finish", front = -106, back = -120, half = 10 },
} :: { Section }
RotatingBeltArt.WALL_HEIGHT = 6
RotatingBeltArt.FINISH_LINE_Z = -116
-- 스폰 (6열 × 4줄 = 24). 출발 바닥(z 0 ~ -14, x ±10) 안에 스폰 판(3×3) 가장자리가 1 stud 이상 여유.
-- M1~M3에서는 z = +3, +7 줄(Spawn13~24)이 출발 바닥 뒤 허공이었고 x ±10 열은 판 절반이 바닥 밖이었어요 (m4-02에서 고침).
RotatingBeltArt.SPAWN_SIZE = 3
RotatingBeltArt.SPAWN_COLUMNS = 6
RotatingBeltArt.SPAWN_ROWS = 4
RotatingBeltArt.SPAWN_SPACING = 3

function RotatingBeltArt.spawnPositions(): { { x: number, z: number } }
	local start = RotatingBeltArt.SECTIONS[1]
	local list = {}
	for row = 0, RotatingBeltArt.SPAWN_ROWS - 1 do
		for col = 0, RotatingBeltArt.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (RotatingBeltArt.SPAWN_COLUMNS - 1) / 2) * RotatingBeltArt.SPAWN_SPACING,
				z = start.front - 2.5 - row * RotatingBeltArt.SPAWN_SPACING,
			})
		end
	end
	return list
end

RotatingBeltArt.SOY_DISH_X = 4.5 -- 병목 양옆 간장 종지 (판정 파츠) 중심 x
RotatingBeltArt.SOY_DISH_ZS = { -68, -60, -52 }

-- m5-20 파티클·조명·애니메이션 이름 상수
RotatingBeltArt.LANTERN = "Lantern"
RotatingBeltArt.FACE_EYE = "FaceEye"
RotatingBeltArt.SOY_GLINT = "SoyGlint"
-- m5-24: 새 손님 눈도 깜빡여요 (RotatingBelt.build가 같은 태그를 달아요)
RotatingBeltArt.GUEST_EYE = "GuestEye"
-- 병목 맨 앞(출발에 가장 가까운) 간장 종지 위치. 좌우 2곳에 반짝이는 파티클이 붙어요.
RotatingBeltArt.SOY_GLINT_Z = -52

-- 가게 껍데기 (m5-24): 마루 바닥 윗면 높이, 벽·천장 자리
RotatingBeltArt.FLOOR_Y = -92 -- 낙하선 -40보다 52 아래 (카운터 높이 92 cm)
RotatingBeltArt.CEILING_Y = 200 -- 방 높이 2.9 m
RotatingBeltArt.SIDE_WALL_X = 250
RotatingBeltArt.END_WALL_Z = -330
RotatingBeltArt.BACK_Z = 190 -- 바닥·천장이 출발 뒤로 이만큼 (벽은 없어요 — 전체 뷰 카메라가 이쪽에 있어요)

-- 판정 파츠 색 (크기·위치·충돌은 RotatingBelt가 그대로 둬요)
RotatingBeltArt.COLORS = {
	woodFloor = { r = 168, g = 126, b = 84 }, -- 출발·결승 나무 바닥 (채도 낮춤)
	belt = { r = 54, g = 54, b = 60 }, -- 벨트 고무
	narrowFloor = { r = 140, g = 108, b = 76 }, -- 병목 나무 바닥
	wall = { r = 214, g = 220, b = 228 }, -- 은빛 유리 벽
	soyDish = P.Porcelain, -- 간장 종지 (흰 도자기)
	stickRed = P.Lacquer,
	stickBlack = { r = 28, g = 24, b = 24 },
	stickTip = P.Wood,
	finishLine = { r = 255, g = 196, b = 40 },
} :: { [string]: RGB }

-- 맵 조명 (m5-24): 저녁 5시 반 가게 안 — 호박색 Ambient, 복숭아색 안개, 창밖 푸른 거리와 온도 대비
RotatingBeltArt.LIGHTING = {
	ClockTime = 17.5,
	Brightness = 2.2,
	Ambient = { r = 128, g = 96, b = 72 },
	OutdoorAmbient = { r = 150, g = 116, b = 96 },
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.24,
		Offset = 0.05,
		Color = { r = 214, g = 176, b = 150 },
		Decay = { r = 110, g = 82, b = 96 },
		Glare = 0.1,
		Haze = 0.7,
	},
	ColorCorrection = {
		Brightness = 0.03,
		Contrast = 0.1,
		Saturation = 0.12,
		TintColor = { r = 255, g = 238, b = 220 },
	},
	Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.15 },
	SunRays = { Intensity = 0.05, Spread = 0.6 },
} :: MapLighting.LightingPreset

local SLAT = { r = 84, g = 84, b = 94 }
local RAIL = { r = 196, g = 200, b = 208 }
local HANDRAIL = { r = 150, g = 104, b = 62 }
local COUNTER = P.Wood
local SKIN = { r = 242, g = 204, b = 168 }
local MOUTH = { r = 96, g = 24, b = 32 }
local TONGUE = { r = 232, g = 110, b = 120 }
local BLUSH = { r = 246, g = 160, b = 160 }
local TEA = { r = 120, g = 150, b = 90 }
local SOY_BOTTLE = { r = 48, g = 26, b = 16 }
local PLATE_COLORS = { P.Tuna, P.PorcelainRim, { r = 214, g = 170, b = 60 } } -- 빨강·파랑·금색 가격표 접시
local TOPPINGS = { P.Salmon, P.Tuna, P.Egg }
local WHITE = P.Rice
local BLACK = P.Nori

-- m5-24 가게 색 (60 = 따뜻한 나무, 30 = 크림·흰 도자기, 10 = 옻칠 빨강·노렌 남색·등빛)
local MARU = { r = 150, g = 104, b = 66 } -- 마루 바닥
local MARU_SHADES = { shade(MARU, 1.08), MARU, shade(MARU, 0.86), shade(MARU, 0.95) }
local PLASTER = { r = 226, g = 206, b = 176 } -- 벽 회벽 (따뜻한 크림)
local BEAM = { r = 92, g = 60, b = 40 } -- 대들보·기둥 (짙은 나무)
local BEAM_LIGHT = shade(BEAM, 1.25)
local CEILING = { r = 112, g = 78, b = 52 }
local CABINET = { r = 128, g = 86, b = 54 } -- 손님 카운터 몸통
local COUNTER_TOP = { r = 206, g = 162, b = 108 } -- 손님 카운터 상판 (밝은 히노키)
local DUSK_SKY = { r = 44, g = 74, b = 150 } -- 창밖 해 질 녘 하늘
local DUSK_LOW = { r = 132, g = 98, b = 150 } -- 창 아래쪽 노을빛
local STREET = { r = 30, g = 36, b = 66 } -- 창밖 건물 실루엣
local WINDOW_GLOW = { r = 255, g = 206, b = 120 } -- 창밖 건물 불빛
local LAMP_PAPER = { r = 255, g = 236, b = 196 } -- 종이등
local LAMP_LIGHT = { r = 255, g = 178, b = 110 }
local CHEF_WHITE = { r = 244, g = 242, b = 236 }
local TUNA_BLOCK = { r = 178, g = 34, b = 52 }

local UP: Vec3 = { x = 0, y = 0, z = 90 } -- Cylinder 축(X)을 세워요
local ALONG_Z: Vec3 = { x = 0, y = 90, z = 0 } -- Cylinder 축을 Z로

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

local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, s in specs do
		table.insert(list, s)
	end
end

-- 큰 배경판: 그림자를 만들지 않아요 (해가 창빛처럼 코스를 비추게)
local function backdrop(
	list: { DecorSpec },
	name: string,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): DecorSpec
	local spec = part(list, name, "Block", size, color, material, offset, rotation)
	spec.castShadow = false
	return spec
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

local function sectionCenter(section: Section): number
	return (section.front + section.back) / 2
end

local function sectionDepth(section: Section): number
	return section.front - section.back
end

-- 벨트 위 슬랫 줄무늬: 진행 방향과 수직, 바닥에 0.05 띄운 얇은 판
local function addSlats(list: { DecorSpec }, section: Section)
	local z = section.front - 1
	while z > section.back + 0.5 do
		part(list, "BeltSlat", "Block", v(section.half * 2 - 0.4, 0.05, 0.4), SLAT, "SmoothPlastic", v(0, 0.075, z))
		z -= 2
	end
end

-- 벽 위 은색 레일 + 나무 손잡이 (벽 바로 위·바깥, 코스 공간 밖)
local function addRails(list: { DecorSpec }, section: Section)
	local depth = sectionDepth(section)
	local centerZ = sectionCenter(section)
	for _, side in { -1, 1 } do
		local wallX = side * (section.half + 0.25)
		local rail = part(
			list,
			"WallRail",
			"Block",
			v(0.5, 0.4, depth),
			RAIL,
			"Metal",
			v(wallX, RotatingBeltArt.WALL_HEIGHT + 0.2, centerZ)
		)
		rail.reflectance = 0.2
		part(
			list,
			"Handrail",
			"Block",
			v(0.6, 0.5, depth),
			HANDRAIL,
			"Wood",
			v(side * (section.half + 0.35), RotatingBeltArt.WALL_HEIGHT + 0.65, centerZ)
		)
	end
end

-- m5-24: 판정 바닥(두께 2) 아래 옻칠 띠 — 코스 가장자리에 두께감, 밟는 면보다 2 이상 낮아요
local function addUnderTrim(list: { DecorSpec }, section: Section)
	local half = section.half + 0.5 -- 벽(0.5) 바깥까지
	part(
		list,
		"CourseUnderTrim",
		"Block",
		v(half * 2 + 0.6, 0.8, sectionDepth(section)),
		P.LacquerDark,
		"SmoothPlastic",
		v(0, -2.4, sectionCenter(section))
	)
	part(
		list,
		"CourseUnderGold",
		"Block",
		v(half * 2 + 0.8, 0.25, sectionDepth(section)),
		{ r = 196, g = 156, b = 72 },
		"Metal",
		v(0, -2.05, sectionCenter(section))
	).reflectance =
		0.25
end

-- 손님 카운터 + 카운터 위 소품(초밥 접시·간장병·찻잔) + 의자
local COUNTER_WIDTH = 5
local COUNTER_TOP_Y = 2.5

local function counterInner(section: Section): number
	-- 병목은 간장 종지(판정 파츠) 바깥에 카운터를 둬요
	return if section.name == "Narrow" then RotatingBeltArt.SOY_DISH_X + 1.5 else section.half + 0.5
end

local function addCounterItem(list: { DecorSpec }, index: number, x: number, z: number)
	local kind = index % 3
	if kind == 0 then
		local plate = PLATE_COLORS[(index // 3) % #PLATE_COLORS + 1]
		local topping = TOPPINGS[(index // 3 + 1) % #TOPPINGS + 1]
		disc(list, "SushiPlate", 0.2, 2, plate, "SmoothPlastic", x, COUNTER_TOP_Y, z)
		part(list, "NigiriRice", "Block", v(0.6, 0.45, 1.1), WHITE, "SmoothPlastic", v(x, COUNTER_TOP_Y + 0.425, z))
		part(
			list,
			"NigiriTopping",
			"Block",
			v(0.7, 0.18, 1.25),
			topping,
			"SmoothPlastic",
			v(x, COUNTER_TOP_Y + 0.74, z)
		)
	elseif kind == 1 then
		disc(list, "SoyBottle", 1.6, 0.7, SOY_BOTTLE, "Glass", x, COUNTER_TOP_Y, z).reflectance = 0.15
		disc(list, "SoyBottleCap", 0.4, 0.45, P.Lacquer, "SmoothPlastic", x, COUNTER_TOP_Y + 1.6, z)
	else
		disc(list, "Teacup", 0.8, 0.7, TEA, "SmoothPlastic", x, COUNTER_TOP_Y, z)
	end
end

local function addCounters(list: { DecorSpec }, section: Section, itemIndex: number): number
	local depth = sectionDepth(section)
	local centerZ = sectionCenter(section)
	local inner = counterInner(section)
	for _, side in { -1, 1 } do
		local counterX = side * (inner + COUNTER_WIDTH / 2)
		part(
			list,
			"Counter",
			"Block",
			v(COUNTER_WIDTH, 2, depth),
			COUNTER,
			"WoodPlanks",
			v(counterX, COUNTER_TOP_Y - 1, centerZ)
		)
		-- m5-24: 상판 바깥 모서리 밝은 띠 + 앞판 짙은 띠 (맨 상자 대신)
		part(
			list,
			"CounterEdge",
			"Block",
			v(0.5, 0.4, depth),
			shade(COUNTER, 1.2),
			"Wood",
			v(side * (inner + COUNTER_WIDTH + 0.25), COUNTER_TOP_Y - 0.2, centerZ)
		)
		part(
			list,
			"CounterApron",
			"Block",
			v(COUNTER_WIDTH + 0.5, 0.6, depth),
			P.WoodDark,
			"Wood",
			v(side * (inner + COUNTER_WIDTH / 2 + 0.25), COUNTER_TOP_Y - 2.3, centerZ)
		)
		local z = section.front - 2.5
		while z > section.back + 1.5 do
			itemIndex += 1
			addCounterItem(list, itemIndex, side * (inner + 1.6), z)
			z -= 5
		end
		-- 의자: 카운터 바깥쪽 (출발·결승 구간은 비워요)
		if section.name ~= "Start" and section.name ~= "Finish" then
			local stoolX = side * (inner + COUNTER_WIDTH + 1.4)
			local sz = section.front - 3
			while sz > section.back + 1.5 do
				disc(list, "StoolLeg", 1.6, 0.4, BLACK, "Metal", stoolX, 0, sz)
				disc(list, "StoolSeat", 0.5, 2.2, P.Lacquer, "Leather", stoolX, 1.6, sz)
				sz -= 6
			end
		end
	end
	return itemIndex
end

-- 거대한 손님 얼굴: 벽 너머에서 입을 벌리고 코스를 내려다봐요. d = 코스 쪽 방향(+1/-1)
-- m5-24: 둥근 머리카락(헬멧처럼 덮는 공 + 앞머리), 귀·코, 볼 홍조, 어깨·옷·팔. 눈 반짝임(흰 점)은 눈이 깜빡일 때
-- 혼자 떠 보여서(m5-20 QA B1) 빼고, 대신 눈에 광택(reflectance)을 줘요.
local SHIRTS = { P.Noren, { r = 120, g = 72, b = 60 }, { r = 74, g = 96, b = 74 }, { r = 150, g = 110, b = 70 } }
local HAIRS = { BLACK, { r = 64, g = 40, b = 28 }, { r = 40, g = 34, b = 30 } }

local function addFace(
	list: { DecorSpec },
	x: number,
	z: number,
	eyeName: string,
	look: number,
	skin: RGB,
	shirt: RGB,
	hair: RGB
)
	local d = if x < 0 then 1 else -1
	local cy = 8
	part(list, "FaceHead", "Ball", v(20, 20, 20), skin, "SmoothPlastic", v(x, cy, z))
	-- 머리카락: 머리보다 조금 큰 공을 뒤·위로 밀어 둥근 덮개 + 앞머리 세 가닥
	part(list, "FaceHair", "Ball", v(21, 21, 21), hair, "SmoothPlastic", v(x - d * 2.2, cy + 3.2, z))
	for i = -1, 1 do
		part(
			list,
			"FaceBangs",
			"Ball",
			v(6, 6, 6),
			hair,
			"SmoothPlastic",
			v(x + d * 5.6, cy + 8.2 - math.abs(i) * 0.8, z + i * 4.6)
		)
	end
	for _, s in { -1, 1 } do
		local eye = part(
			list,
			eyeName,
			"Ball",
			v(2.4, 2.4, 2.4),
			BLACK,
			"SmoothPlastic",
			v(x + d * 8.6, cy + 3, z + s * 3.5 + look)
		)
		eye.reflectance = 0.35
		part(
			list,
			"FaceBrow",
			"Block",
			v(0.6, 0.6, 3),
			hair,
			"SmoothPlastic",
			v(x + d * 8.2, cy + 5.6, z + s * 3.5),
			v(s * 15, 0, 0)
		)
		part(list, "FaceBlush", "Ball", v(2.5, 2.5, 2.5), BLUSH, "SmoothPlastic", v(x + d * 7.7, cy - 1, z + s * 6))
		part(
			list,
			"FaceEar",
			"Ball",
			v(4, 4, 4),
			shade(skin, 0.94),
			"SmoothPlastic",
			v(x - d * 0.5, cy + 0.5, z + s * 9.6)
		)
	end
	part(list, "FaceNose", "Ball", v(2.6, 2.6, 2.6), shade(skin, 0.95), "SmoothPlastic", v(x + d * 9.6, cy + 0.6, z))
	part(list, "FaceMouth", "Ball", v(6, 6, 6), MOUTH, "SmoothPlastic", v(x + d * 7.4, cy - 4.2, z))
	part(list, "FaceTongue", "Ball", v(3, 3, 3), TONGUE, "SmoothPlastic", v(x + d * 8.9, cy - 5.4, z))
	-- 목·어깨·몸통 (손님 카운터 너머에 앉아 있어요)
	local bx = x - d * 3
	part(list, "GuestNeck", "Cylinder", v(6, 8, 8), shade(skin, 0.9), "SmoothPlastic", v(bx, cy - 11, z), UP)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"GuestBody",
			v(16, 34, 30),
			shirt,
			"Fabric",
			v(bx - d * 1, cy - 30, z),
			{ radius = 5, style = "vertical" }
		)
	)
	part(list, "GuestCollar", "Block", v(8, 2, 12), shade(shirt, 1.3), "Fabric", v(bx + d * 4.5, cy - 13.6, z))
	for _, s in { -1, 1 } do
		part(list, "GuestShoulder", "Ball", v(13, 13, 13), shirt, "Fabric", v(bx - d * 1, cy - 16.5, z + s * 11))
		-- 팔: 카운터 위로 뻗어 젓가락을 든 손
		addAll(
			list,
			MapKitShapes.capsule(
				"GuestArm",
				20,
				7,
				shade(shirt, 0.9),
				"Fabric",
				v(bx + d * 8, cy - 20, z + s * 11),
				v(0, 0, if d > 0 then -30 else 210)
			)
		)
		part(list, "GuestHand", "Ball", v(6, 6, 6), skin, "SmoothPlastic", v(bx + d * 17, cy - 15.5, z + s * 11))
	end
	addAll(
		list,
		MapKitShapes.capsule(
			"GuestChopstick",
			16,
			0.8,
			P.Lacquer,
			"Wood",
			v(bx + d * 20, cy - 13, z + 13),
			v(0, d * 20, if d > 0 then -15 else 195)
		)
	)
end

-- 병목: 종지 테두리(남색)·간장 면 + 색 접시 더미
local function addNarrow(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * RotatingBeltArt.SOY_DISH_X
		for _, z in RotatingBeltArt.SOY_DISH_ZS do
			disc(list, "SoyDishRim", 0.15, 2.15, P.PorcelainRim, "SmoothPlastic", x, 1.88, z)
			disc(list, "SoyDishSauce", 0.05, 1.6, P.Soy, "Glass", x, 2.02, z).reflectance = 0.2
		end
		for _, z in { -64, -56 } do
			for layer = 0, 5 do
				local color = PLATE_COLORS[(layer + (if side > 0 then 1 else 0)) % #PLATE_COLORS + 1]
				disc(list, "PlateStack", 0.3, 2.4, color, "SmoothPlastic", side * 4.6, layer * 0.35, z)
			end
		end
	end
end

-- 결승: 체크무늬 결승선 + 노렌 걸린 문틀
local function addFinish(list: { DecorSpec })
	local lineZ = RotatingBeltArt.FINISH_LINE_Z
	for row = 0, 1 do
		for col = 0, 19 do
			local color = if (row + col) % 2 == 0 then WHITE else BLACK
			part(
				list,
				"FinishChecker",
				"Block",
				v(1, 0.05, 0.5),
				color,
				"SmoothPlastic",
				v(-9.5 + col, 0.45, lineZ + 0.25 - row * 0.5)
			)
		end
	end
	local gateZ = lineZ + 3
	for _, side in { -1, 1 } do
		part(list, "GatePost", "Block", v(1, 19, 1), P.Lacquer, "Wood", v(side * 11.25, 9.5, gateZ))
		-- m5-24: 기둥 받침·금 장식
		part(list, "GatePostFoot", "Block", v(1.6, 1, 1.6), BLACK, "Metal", v(side * 11.25, 0.5, gateZ))
		part(
			list,
			"GatePostCap",
			"Ball",
			v(1.6, 1.6, 1.6),
			{ r = 214, g = 172, b = 64 },
			"Metal",
			v(side * 11.25, 20, gateZ)
		)
	end
	part(list, "GateBeam", "Block", v(25, 1, 1.2), P.Lacquer, "Wood", v(0, 18.6, gateZ))
	for i = 0, 3 do
		local x = -7.5 + i * 5
		local noren = part(list, "Noren", "Block", v(4.8, 2.8, 0.2), P.Noren, "Fabric", v(x, 16.6, gateZ))
		noren.anim = { kind = "Sway", period = 4 + i * 0.4, amount = 4, axis = "X" }
		part(list, "NorenMark", "Ball", v(1.4, 1.4, 1.4), WHITE, "Fabric", v(x, 16.8, gateZ + 0.2))
	end
	-- 결승 노렌을 비추는 좁은 그림자 SpotLight (고정 등 파츠 — 노렌 위 천장 쪽에서 아래로)
	local spot = part(
		list,
		"FinishSpotLamp",
		"Cylinder",
		v(1.2, 2.4, 2.4),
		LAMP_PAPER,
		"Neon",
		v(0, 34, gateZ + 10),
		v(0, 0, 90)
	)
	spot.light = {
		kind = "Spot",
		color = { r = 255, g = 214, b = 160 },
		brightness = 4,
		range = 44,
		angle = 50,
		face = "Left",
		shadows = true,
	}
	part(list, "FinishSpotHousing", "Cylinder", v(2.4, 3, 3), BLACK, "Metal", v(0, 35.8, gateZ + 10), v(0, 0, 90))
end

-- 머리 위 종이 등 (바닥 위 20 이상)
local function addLanterns(list: { DecorSpec })
	for _, z in { -24, -60, -90 } do
		local lantern = part(list, RotatingBeltArt.LANTERN, "Ball", v(3, 3, 3), P.Lacquer, "Fabric", v(0, 22, z))
		lantern.anim = { kind = "Sway", period = 5, amount = 5, axis = "X" }
		disc(list, "LanternCap", 0.4, 1.6, BLACK, "SmoothPlastic", 0, 23.4, z)
		disc(list, "LanternFoot", 0.4, 1.6, BLACK, "SmoothPlastic", 0, 20.2, z)
	end
end

-- 병목 맨 앞 간장 종지 위, 좌우 2곳에 반짝이는 파티클이 붙을 투명 앵커 (m5-20 ①)
-- SoyDishSauce는 병목 세 자리 전부에 쓰여서(겹쳐서) 새 이름을 써요.
local function addSoyGlints(list: { DecorSpec })
	for _, side in { -1, 1 } do
		part(
			list,
			RotatingBeltArt.SOY_GLINT,
			"Block",
			v(0.4, 0.1, 0.4),
			P.Soy,
			"SmoothPlastic",
			v(side * RotatingBeltArt.SOY_DISH_X, 2.05, RotatingBeltArt.SOY_GLINT_Z)
		)
	end
end

---------------------------------------------------------------------------- m5-24 가게 환경

local FLOOR_Y = RotatingBeltArt.FLOOR_Y
local CEIL_Y = RotatingBeltArt.CEILING_Y
local WALL_X = RotatingBeltArt.SIDE_WALL_X
local END_Z = RotatingBeltArt.END_WALL_Z
local BACK_Z = RotatingBeltArt.BACK_Z
local ROOM_MID_Z = (BACK_Z + END_Z) / 2
local ROOM_DEPTH = BACK_Z - END_Z

-- 마루 바닥: 긴 널 9장(3 shade) + 짙은 줄눈, 천장 판 + 대들보
local function addRoomShell(list: { DecorSpec })
	local boards = 9
	local boardW = (WALL_X * 2) / boards
	for i = 0, boards - 1 do
		local x = -WALL_X + boardW * (i + 0.5)
		backdrop(
			list,
			"MaruBoard",
			v(boardW - 0.6, 4, ROOM_DEPTH),
			MARU_SHADES[i % #MARU_SHADES + 1],
			"WoodPlanks",
			v(x, FLOOR_Y - 2, ROOM_MID_Z)
		)
	end
	backdrop(
		list,
		"MaruUnder",
		v(WALL_X * 2, 2, ROOM_DEPTH),
		shade(MARU, 0.55),
		"Wood",
		v(0, FLOOR_Y - 3.5, ROOM_MID_Z)
	)
	-- 천장 (짙은 나무) + 가로 대들보 + 세로 도리
	backdrop(list, "Ceiling", v(WALL_X * 2, 4, ROOM_DEPTH), CEILING, "WoodPlanks", v(0, CEIL_Y + 2, ROOM_MID_Z))
	local z = BACK_Z - 40
	while z > END_Z + 20 do
		backdrop(list, "CeilingBeam", v(WALL_X * 2, 10, 8), BEAM, "Wood", v(0, CEIL_Y - 5, z))
		z -= 70
	end
	for _, x in { -150, -60, 60, 150 } do
		backdrop(list, "CeilingRafter", v(7, 6, ROOM_DEPTH), BEAM_LIGHT, "Wood", v(x, CEIL_Y - 13, ROOM_MID_Z))
	end
end

-- 마루 위 테이블 자리 (배경 중경): 둥근 모서리 상판 + 다리 + 방석 의자 + 찻잔·접시 무리. 위치·크기를 조금씩 다르게.
local function addDiningTables(list: { DecorSpec })
	local spots = {
		{ -110, -20, 0 },
		{ -170, -150, 6 },
		{ 115, -40, -4 },
		{ 175, -170, 3 },
		{ -120, -250, -3 },
		{ 120, -260, 5 },
	}
	for i, s in spots do
		local x, z, turn = s[1], s[2], s[3]
		local top = FLOOR_Y + 70 + (i % 2) * 2
		local wood = MARU_SHADES[i % #MARU_SHADES + 1]
		addAll(
			list,
			MapKitShapes.roundedBox(
				"DiningTop",
				v(70, 4, 50),
				shade(wood, 1.15),
				"Wood",
				v(x, top - 2, z),
				{ radius = 2, style = "vertical", rotation = v(0, turn, 0) }
			)
		)
		part(
			list,
			"DiningLeg",
			"Block",
			v(40, top - 4 - FLOOR_Y, 6),
			BEAM,
			"Wood",
			v(x, (top - 4 + FLOOR_Y) / 2, z),
			v(0, turn, 0)
		)
		for _, e in { -1, 1 } do
			local cx = x + e * 46 * math.cos(math.rad(turn))
			local cz = z - e * 46 * math.sin(math.rad(turn))
			disc(list, "DiningStool", 44, 26, P.LacquerDark, "SmoothPlastic", cx, FLOOR_Y, cz)
			disc(
				list,
				"DiningCushion",
				6,
				30,
				if i % 2 == 0 then P.Noren else { r = 140, g = 60, b = 50 },
				"Fabric",
				cx,
				FLOOR_Y + 44,
				cz
			)
		end
		disc(list, "DiningPlate", 1.4, 26, WHITE, "SmoothPlastic", x - 12, top, z + 4).reflectance = 0.06
		disc(list, "DiningPlateRim", 1.6, 27, P.PorcelainRim, "SmoothPlastic", x - 12, top - 0.2, z + 4)
		disc(list, "DiningCup", 9, 8, { r = 104, g = 120, b = 88 }, "SmoothPlastic", x + 18, top, z - 8)
		disc(list, "DiningSoyBottle", 15, 6, SOY_BOTTLE, "Glass", x + 22, top, z + 10).reflectance = 0.15
		disc(list, "DiningSoyCap", 3, 4, P.Lacquer, "SmoothPlastic", x + 22, top + 15, z + 10)
	end
end

-- 코스를 받치는 옻칠 기둥 (코스 가운데 아래, 떨어지는 사람이 지나가는 가장자리와 안 겹쳐요)
local function addCourseSupports(list: { DecorSpec })
	for _, z in { -8, -40, -80, -112 } do
		local h = -3 - FLOOR_Y
		part(
			list,
			"CourseLeg",
			"Cylinder",
			v(h, 3.4, 3.4),
			P.LacquerDark,
			"SmoothPlastic",
			v(0, FLOOR_Y + h / 2, z),
			UP
		)
		disc(list, "CourseLegFoot", 1.2, 6, BLACK, "Metal", 0, FLOOR_Y, z)
		disc(list, "CourseLegBand", 0.6, 4, { r = 196, g = 156, b = 72 }, "Metal", 0, -14, z)
	end
end

-- 손님 카운터(코스 양옆 너머): 밝은 히노키 상판 + 옻칠 앞판 + 몸통이 마루까지, 위에 반대 방향 장식 레인과 색 접시 줄
local GUEST_IN = 16.5
local GUEST_OUT = 33
local GUEST_TOP = -6
local LANE_X = 21.8
local function addGuestCounters(list: { DecorSpec })
	local front, back = 2, -124
	local depth = front - back
	local cz = (front + back) / 2
	local width = GUEST_OUT - GUEST_IN
	for _, side in { -1, 1 } do
		local cx = side * (GUEST_IN + GUEST_OUT) / 2
		part(list, "GuestCounterTop", "Block", v(width, 2, depth), COUNTER_TOP, "Wood", v(cx, GUEST_TOP - 1, cz))
		part(
			list,
			"GuestCounterLip",
			"Block",
			v(0.8, 2.6, depth),
			P.Lacquer,
			"SmoothPlastic",
			v(side * (GUEST_IN - 0.4), GUEST_TOP - 1.1, cz)
		).reflectance =
			0.12
		backdrop(
			list,
			"GuestCabinet",
			v(width - 2, (GUEST_TOP - 2) - FLOOR_Y, depth - 2),
			CABINET,
			"WoodPlanks",
			v(cx + side * 1, (GUEST_TOP - 2 + FLOOR_Y) / 2, cz)
		)
		backdrop(list, "GuestKick", v(width - 1, 6, depth - 1), BEAM, "Wood", v(cx + side * 1.5, FLOOR_Y + 3, cz))
		-- 카운터 앞판 세로 살 (나무 결 리듬)
		local pz = front - 10
		while pz > back + 4 do
			part(
				list,
				"GuestPanelSlat",
				"Block",
				v(0.6, 40, 1.2),
				shade(CABINET, 0.8),
				"Wood",
				v(side * (GUEST_IN + 0.7), -30, pz)
			)
			pz -= 14
		end
		-- 반대 방향으로 도는 장식 레인 (스테인리스 테두리 + 크림 벨트) — 접시 지름 8 (실제 회전초밥 접시 비율)
		part(
			list,
			"DecoLane",
			"Block",
			v(8.6, 0.3, depth - 2),
			{ r = 236, g = 226, b = 204 },
			"SmoothPlastic",
			v(side * LANE_X, GUEST_TOP + 0.15, cz)
		)
		for _, e in { -1, 1 } do
			part(
				list,
				"DecoLaneRail",
				"Block",
				v(0.4, 0.8, depth - 2),
				RAIL,
				"Metal",
				v(side * LANE_X + e * 4.5, GUEST_TOP + 0.4, cz)
			).reflectance =
				0.3
		end
		-- 색 접시 줄 (접시 색 = 가격): 7개씩 반복, 크기·토핑을 조금씩 바꿔요
		local colors =
			{ P.Tuna, P.PorcelainRim, { r = 214, g = 170, b = 60 }, WHITE, P.Lacquer, { r = 60, g = 120, b = 70 } }
		local toppings = { P.Salmon, P.Tuna, P.Egg, { r = 240, g = 150, b = 120 }, { r = 250, g = 120, b = 60 } }
		local i = 0
		local z = front - 5
		while z > back + 3 do
			i += 1
			local px = side * LANE_X
			local plateColor = colors[(i + (if side > 0 then 2 else 0)) % #colors + 1]
			disc(list, "LanePlate", 0.6, 7.6, plateColor, "SmoothPlastic", px, GUEST_TOP + 0.3, z).reflectance = 0.08
			disc(list, "LanePlateWell", 0.1, 5.6, WHITE, "SmoothPlastic", px, GUEST_TOP + 0.9, z)
			if i % 4 ~= 0 then
				local top = toppings[(i * 3 + (if side > 0 then 1 else 0)) % #toppings + 1]
				local turn = 8 * side + (i % 3) * 7
				part(
					list,
					"LaneRice",
					"Block",
					v(2.4, 1.8, 4.2),
					WHITE,
					"SmoothPlastic",
					v(px, GUEST_TOP + 1.9, z),
					v(0, turn, 0)
				)
				part(
					list,
					"LaneTopping",
					"Block",
					v(2.8, 0.7, 4.8),
					top,
					"SmoothPlastic",
					v(px, GUEST_TOP + 3.1, z),
					v(0, turn, 0)
				)
			end
			z -= 9.5
		end
		-- 손님 앞 소품 무리: 찻잔(김) · 간장 종지 · 생강 · 젓가락 받침
		for k, gz in { -14, -46, -78, -108 } do
			local gx = side * 29.5
			disc(list, "GuestTeacup", 3, 3.4, { r = 104, g = 120, b = 88 }, "SmoothPlastic", gx, GUEST_TOP, gz)
			disc(list, "GuestTea", 0.1, 2.8, { r = 160, g = 176, b = 90 }, "Glass", gx, GUEST_TOP + 2.9, gz)
			disc(list, "GuestSoyDish", 0.8, 3, WHITE, "SmoothPlastic", gx, GUEST_TOP, gz - 4.5)
			disc(list, "GuestSoy", 0.1, 2.3, P.Soy, "Glass", gx, GUEST_TOP + 0.8, gz - 4.5).reflectance = 0.25
			for g = 0, 2 do
				part(
					list,
					"GuestGinger",
					"Ball",
					v(1.2, 1.2, 1.2),
					{ r = 246, g = 180, b = 170 },
					"SmoothPlastic",
					v(gx - side * 1 + g * 0.4, GUEST_TOP + 0.5 + (g % 2) * 0.4, gz - 7.5 - g * 0.5)
				)
			end
			if k % 2 == 1 then
				local steam = part(
					list,
					"TeaSteam",
					"Block",
					v(0.6, 0.2, 0.6),
					WHITE,
					"SmoothPlastic",
					v(gx, GUEST_TOP + 3.2, gz)
				)
				steam.transparency = 1
				steam.particle = "Steam"
				steam.particleRate = 1.2
			end
		end
	end
end

-- 손님 위 옻칠 선반 레일 + 종이등 줄 (레일은 코스 밖, 등은 손님 카운터 위)
local function addOverheadRails(list: { DecorSpec })
	local front, back = 6, -126
	local railY = 58
	for _, side in { -1, 1 } do
		part(
			list,
			"OverheadRail",
			"Block",
			v(2, 2.4, front - back),
			P.LacquerDark,
			"SmoothPlastic",
			v(side * 28, railY, (front + back) / 2)
		)
		-- 매단 봉: 양 끝 둘만, 굵게(1.4) 옻칠 — 가는 검은 선 여럿이 overview에서 "철사 숲"처럼 보였어요 (반복 4)
		for _, z in { front - 2, back + 2 } do
			part(
				list,
				"OverheadPost",
				"Cylinder",
				v(CEIL_Y - 17 - railY, 1.4, 1.4),
				P.LacquerDark,
				"SmoothPlastic",
				v(side * 28, (railY + CEIL_Y - 17) / 2, z),
				UP
			)
		end
		local lit = 0
		local z = -6
		while z > -120 do
			local y = 36 + ((z // 18) % 2) * 3
			local lamp = part(list, "PaperLamp", "Ball", v(4.4, 4.4, 4.4), LAMP_PAPER, "Neon", v(side * 28, y, z))
			lamp.anim = { kind = "Sway", period = 6 + (z % 3), amount = 3, axis = "Z" }
			part(
				list,
				"PaperLampCap",
				"Cylinder",
				v(0.6, 2.4, 2.4),
				BLACK,
				"SmoothPlastic",
				v(side * 28, y + 2.4, z),
				UP
			)
			part(
				list,
				"PaperLampCord",
				"Block",
				v(0.2, railY - y - 2.6, 0.2),
				BLACK,
				"SmoothPlastic",
				v(side * 28, (railY + y + 2.6) / 2, z)
			)
			if lit < 3 and (z // 18) % 2 == 0 then
				lit += 1
				lamp.light = { kind = "Point", color = LAMP_LIGHT, brightness = 1.4, range = 30 }
			end
			z -= 18
		end
	end
	-- 등(Lantern)을 매단 가로대 (코스 위 높이 58 — 소개 카메라 경로보다 훨씬 위)
	for _, z in { -24, -60, -90 } do
		part(list, "LanternBar", "Block", v(58, 1.2, 1.2), P.LacquerDark, "SmoothPlastic", v(0, railY, z))
	end
end

-- 옆 벽: 회벽 + 나무 기둥·인방 + 아래 판벽, 창 3개 (해 질 녘 파란 거리 — 건물 실루엣과 불 켜진 창)
local function addWindow(list: { DecorSpec }, side: number, z: number, seed: number)
	local x = side * (WALL_X - 3)
	local inward = -side
	local winW, winH, winY = 70, 70, 40
	-- 창밖 (벽 바로 바깥, 불투명): 하늘 그라데이션 2장 + 건물 실루엣 + 불빛 창
	-- 창밖 하늘은 스스로 빛나는 면(Neon, 어둡게) — 가게 안 호박색과 온도 대비
	backdrop(list, "DuskSky", v(1, winH * 0.55, winW), DUSK_SKY, "Neon", v(x - inward * 2, winY + winH * 0.225, z))
	backdrop(list, "DuskGlow", v(1, winH * 0.45, winW), DUSK_LOW, "Neon", v(x - inward * 2, winY - winH * 0.275, z))
	local rng = MapKitShapes.rng(seed)
	local bz = z - winW / 2 + 6
	while bz < z + winW / 2 - 4 do
		local w = rng:range(9, 16)
		local h = rng:range(18, 44)
		local cz = math.min(bz + w / 2, z + winW / 2 - w / 2)
		backdrop(
			list,
			"StreetBuilding",
			v(1, h, w),
			shade(STREET, rng:range(0.85, 1.25)),
			"SmoothPlastic",
			v(x - inward * 1.4, winY - winH / 2 + h / 2, cz)
		)
		for row = 0, 2 do
			if rng:next() < 0.55 and 6 + row * 9 < h - 4 then
				part(
					list,
					"StreetLitWindow",
					"Block",
					v(0.4, 3, 2.6),
					WINDOW_GLOW,
					"Neon",
					v(x - inward * 0.9, winY - winH / 2 + 6 + row * 9, cz + rng:range(-w / 4, w / 4))
				)
			end
		end
		bz += w + rng:range(1, 4)
	end
	-- 창틀 (짙은 나무) + 가운데 살
	for _, e in { -1, 1 } do
		part(list, "WindowFrame", "Block", v(3, winH + 6, 3), BEAM, "Wood", v(x, winY, z + e * (winW / 2 + 1.5)))
		part(list, "WindowFrame", "Block", v(3, 3, winW + 6), BEAM, "Wood", v(x, winY + e * (winH / 2 + 1.5), z))
	end
	part(list, "WindowMullion", "Block", v(1.6, winH, 1.6), BEAM_LIGHT, "Wood", v(x, winY, z))
	part(list, "WindowMullion", "Block", v(1.6, 1.6, winW), BEAM_LIGHT, "Wood", v(x, winY + 8, z))
	-- 창 아래 노렌 짧은 가림막
	for k = -1, 1 do
		local cloth = part(
			list,
			"WindowNoren",
			"Block",
			v(0.6, 16, winW / 3 - 1.5),
			P.Noren,
			"Fabric",
			v(x + inward * 2.2, winY + winH / 2 - 9, z + k * winW / 3)
		)
		cloth.anim = { kind = "Sway", period = 7 + k, amount = 2, axis = "Z" }
	end
end

local function addSideWalls(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * WALL_X
		local wallH = CEIL_Y - FLOOR_Y
		-- 회벽은 창 자리를 비우려고 위·아래·창 사이 판으로 나눠요
		backdrop(
			list,
			"SideWallLow",
			v(4, 5 - FLOOR_Y, ROOM_DEPTH),
			PLASTER,
			"Plaster",
			v(x + side * 2, (5 + FLOOR_Y) / 2, ROOM_MID_Z)
		)
		backdrop(
			list,
			"SideWallHigh",
			v(4, CEIL_Y - 75, ROOM_DEPTH),
			PLASTER,
			"Plaster",
			v(x + side * 2, (75 + CEIL_Y) / 2, ROOM_MID_Z)
		)
		backdrop(
			list,
			"SideWainscot",
			v(3, 50, ROOM_DEPTH),
			shade(CABINET, 0.85),
			"WoodPlanks",
			v(x - side * 0.5, FLOOR_Y + 25, ROOM_MID_Z)
		)
		backdrop(list, "SideWainscotRail", v(4, 3, ROOM_DEPTH), BEAM, "Wood", v(x - side * 1, FLOOR_Y + 51, ROOM_MID_Z))
		local windows = { 60, -60, -180 }
		local edges = { BACK_Z, 60 + 38, 60 - 38, -60 + 38, -60 - 38, -180 + 38, -180 - 38, END_Z }
		for k = 1, #edges, 2 do
			local a, b = edges[k], edges[k + 1]
			if a - b > 0.5 then
				backdrop(list, "SideWallPier", v(4, 70, a - b), PLASTER, "Plaster", v(x + side * 2, 40, (a + b) / 2))
			end
		end
		-- 기둥 (창 사이) + 위 인방
		for _, pz in { 120, 0, -120, -240 } do
			backdrop(list, "WallPost", v(6, wallH, 6), BEAM, "Wood", v(x - side * 2, (FLOOR_Y + CEIL_Y) / 2, pz))
		end
		backdrop(list, "WallLintel", v(5, 6, ROOM_DEPTH), BEAM, "Wood", v(x - side * 1.5, 112, ROOM_MID_Z))
		for i, z in windows do
			addWindow(list, side, z, 17 + i * 13 + (if side > 0 then 101 else 0))
		end
	end
end

-- 끝 벽: 회벽 + 기둥, 나무 메뉴판 줄, 가운데 큰 노렌 출입구, 술병 선반
local function addEndWall(list: { DecorSpec })
	local z = END_Z
	local width = WALL_X * 2
	backdrop(list, "EndWall", v(width, CEIL_Y - FLOOR_Y, 4), PLASTER, "Plaster", v(0, (CEIL_Y + FLOOR_Y) / 2, z - 2))
	backdrop(list, "EndWainscot", v(width, 50, 3), shade(CABINET, 0.85), "WoodPlanks", v(0, FLOOR_Y + 25, z + 1))
	backdrop(list, "EndWainscotRail", v(width, 3, 4), BEAM, "Wood", v(0, FLOOR_Y + 51, z + 1.5))
	for _, x in { -190, -110, 110, 190 } do
		backdrop(list, "EndPost", v(7, CEIL_Y - FLOOR_Y, 6), BEAM, "Wood", v(x, (CEIL_Y + FLOOR_Y) / 2, z + 2))
	end
	backdrop(list, "EndLintel", v(width, 7, 6), BEAM, "Wood", v(0, 64, z + 2.5))
	-- 메뉴판 줄 (나무 판 + 검은 글씨 줄 + 빨간 가격 도장), 크기·높이를 조금씩 다르게
	local rng = MapKitShapes.rng(907)
	local x = -WALL_X + 30
	local n = 0
	while x < WALL_X - 30 do
		n += 1
		local w = 16 + (n % 3) * 2
		local tilt = rng:range(-2, 2)
		local y = 92 + (n % 2) * 2
		part(
			list,
			"MenuBoard",
			"Block",
			v(w, 34, 1.4),
			mix(P.WoodLight, P.Wood, (n % 3) / 3),
			"Wood",
			v(x, y, z + 4),
			v(0, 0, tilt)
		)
		for line = 0, 1 do
			part(
				list,
				"MenuText",
				"Block",
				v(1.6, 20 - line * 6, 0.3),
				BLACK,
				"SmoothPlastic",
				v(x + 3 - line * 5, y + 2 + line * 3, z + 4.9),
				v(0, 0, tilt)
			)
		end
		-- 판 위 짙은 테 (맨 판이 아니게)
		part(list, "MenuBoardCap", "Block", v(w + 1, 1.6, 2), BEAM, "Wood", v(x, y + 17.6, z + 4.2), v(0, 0, tilt))
		part(list, "MenuPrice", "Block", v(3, 3, 0.3), P.Lacquer, "SmoothPlastic", v(x - 5, y - 12, z + 4.9))
		x += w + 4
	end
	part(list, "MenuRail", "Block", v(width - 40, 2, 3), BEAM, "Wood", v(0, 112, z + 4))
	-- 출입구: 짙은 문틀 + 큰 노렌 3폭 (흰 문장) + 양쪽 큰 빨간 초롱
	part(list, "DoorFrame", "Block", v(8, 140, 8), BEAM, "Wood", v(-46, FLOOR_Y + 70, z + 4))
	part(list, "DoorFrame", "Block", v(8, 140, 8), BEAM, "Wood", v(46, FLOOR_Y + 70, z + 4))
	part(list, "DoorFrame", "Block", v(100, 8, 8), BEAM, "Wood", v(0, FLOOR_Y + 140, z + 4))
	backdrop(list, "DoorDark", v(84, 132, 1), { r = 40, g = 30, b = 30 }, "SmoothPlastic", v(0, FLOOR_Y + 66, z + 1))
	for k = -1, 1 do
		local cloth =
			part(list, "EntranceNoren", "Block", v(27, 52, 0.8), P.Noren, "Fabric", v(k * 28, FLOOR_Y + 108, z + 8.5))
		cloth.anim = { kind = "Sway", period = 6 + k * 0.7, amount = 2.5, axis = "X" }
		part(
			list,
			"EntranceCrest",
			"Cylinder",
			v(0.4, 12, 12),
			WHITE,
			"Fabric",
			v(k * 28, FLOOR_Y + 112, z + 9.2),
			ALONG_Z
		)
	end
	for _, s in { -1, 1 } do
		-- 초롱: 옻칠 천(Fabric) + 안쪽 따뜻한 빛 띠(Neon — 빛의 원인). 빨간 Neon은 위험 색이라 장식에 안 써요.
		part(list, "DoorChochin", "Ball", v(18, 18, 18), P.Lacquer, "Fabric", v(s * 64, FLOOR_Y + 112, z + 14))
		local glow = part(
			list,
			"DoorChochinGlow",
			"Cylinder",
			v(5, 18.6, 18.6),
			{ r = 255, g = 196, b = 120 },
			"Neon",
			v(s * 64, FLOOR_Y + 112, z + 14),
			UP
		)
		glow.light = { kind = "Point", color = { r = 255, g = 150, b = 96 }, brightness = 2, range = 50 }
		part(
			list,
			"DoorChochinCap",
			"Cylinder",
			v(3, 10, 10),
			BLACK,
			"SmoothPlastic",
			v(s * 64, FLOOR_Y + 122.5, z + 14),
			UP
		)
		part(
			list,
			"DoorChochinCap",
			"Cylinder",
			v(3, 10, 10),
			BLACK,
			"SmoothPlastic",
			v(s * 64, FLOOR_Y + 101.5, z + 14),
			UP
		)
	end
	-- 술병 선반 (벽 왼쪽·오른쪽 아래)
	for _, s in { -1, 1 } do
		local sx = s * 150
		part(list, "SakeShelf", "Block", v(70, 2.4, 14), BEAM_LIGHT, "Wood", v(sx, 10, z + 8))
		part(list, "SakeShelf", "Block", v(70, 2.4, 14), BEAM_LIGHT, "Wood", v(sx, 40, z + 8))
		for row, sy in { 11.2, 41.2 } do
			for k = 0, 6 do
				local h = 22 + ((k + row) % 3) * 4
				local bottle = { r = 40, g = 90, b = 60 }
				if (k + row) % 3 == 1 then
					bottle = { r = 120, g = 60, b = 30 }
				elseif (k + row) % 3 == 2 then
					bottle = { r = 230, g = 226, b = 210 }
				end
				local bx = sx - 30 + k * 10
				disc(list, "SakeBottle", h, 6, bottle, "Glass", bx, sy, z + 8).reflectance = 0.2
				disc(list, "SakeLabel", 8, 6.2, WHITE, "SmoothPlastic", bx, sy + h * 0.35, z + 8)
				disc(list, "SakeNeck", 5, 2.6, bottle, "Glass", bx, sy + h, z + 8)
			end
		end
	end
end

-- 셰프 작업대(결승 너머): 카운터 + 유리 진열 케이스 속 참치·연어·새우, 거대 셰프(모자·팔·칼), 마네키네코, 회전 진열대
local function addChefStation(list: { DecorSpec })
	local cz = -150
	-- 작업대 (손님 카운터와 같은 높이 계열, 결승 끝 벽 너머)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ChefCounter",
			v(120, 18, 24),
			COUNTER_TOP,
			"Wood",
			v(0, -8, cz + 6),
			{ radius = 3, style = "vertical" }
		)
	)
	backdrop(list, "ChefCabinet", v(116, -17 - FLOOR_Y, 20), CABINET, "WoodPlanks", v(0, (-17 + FLOOR_Y) / 2, cz + 6))
	part(list, "ChefCounterLip", "Block", v(120, 1.6, 1), P.Lacquer, "SmoothPlastic", v(0, 1.4, cz + 18.5))
	-- 진열 케이스 (얇은 유리 앞판 하나 + 스테인리스 틀 + 얼음 위 생선)
	local caseZ = cz + 12
	part(list, "NetaCaseBase", "Block", v(56, 2, 9), { r = 210, g = 214, b = 220 }, "Metal", v(0, 2, caseZ)).reflectance =
		0.25
	part(list, "NetaIce", "Block", v(52, 1.2, 7), { r = 226, g = 240, b = 248 }, "Ice", v(0, 3.6, caseZ))
	-- 유리 앞판은 빼요 (큰 반투명 판 = 휴대폰 비용 + 결승 뒤 시야를 흐림). 기울어진 금속 테만 둬요.
	part(list, "NetaCaseRim", "Block", v(56, 0.6, 0.6), { r = 196, g = 200, b = 206 }, "Metal", v(0, 12.4, caseZ + 2.6)).reflectance =
		0.3
	for _, e in { -1, 1 } do
		part(list, "NetaCaseEnd", "Block", v(0.8, 10, 9), { r = 196, g = 200, b = 206 }, "Metal", v(e * 28, 8, caseZ)).reflectance =
			0.3
	end
	part(list, "NetaCaseTop", "Block", v(57, 0.8, 6), { r = 196, g = 200, b = 206 }, "Metal", v(0, 13, caseZ - 1)).reflectance =
		0.3
	-- 참치 덩어리 (둥근 큰 덩어리 + 지방 줄), 연어 필레, 새우
	addAll(
		list,
		MapKitShapes.roundedBox(
			"TunaBlock",
			v(16, 6, 6),
			TUNA_BLOCK,
			"SmoothPlastic",
			v(-14, 7, caseZ),
			{ radius = 1.6 }
		)
	)
	for k = -1, 1 do
		part(
			list,
			"TunaFat",
			"Block",
			v(0.3, 5, 6.2),
			{ r = 236, g = 150, b = 156 },
			"SmoothPlastic",
			v(-14 + k * 4, 7, caseZ)
		)
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"SalmonFillet",
			v(14, 4, 5.5),
			P.Salmon,
			"SmoothPlastic",
			v(4, 6.2, caseZ),
			{ radius = 1.4 }
		)
	)
	for k = -1, 1 do
		part(
			list,
			"SalmonStripe",
			"Block",
			v(0.4, 4.2, 5.7),
			P.SalmonLight,
			"SmoothPlastic",
			v(4 + k * 3.5, 6.2, caseZ),
			v(0, 20, 0)
		)
	end
	for k = 0, 2 do
		addAll(
			list,
			MapKitShapes.capsule(
				"Shrimp",
				6,
				2.2,
				{ r = 255, g = 150, b = 110 },
				"SmoothPlastic",
				v(17 + k * 2.6, 5.6, caseZ),
				v(0, 70, 10)
			)
		)
	end
	-- 도마 + 칼
	part(list, "ChefBoard", "Block", v(30, 2.2, 12), P.WoodLight, "Wood", v(0, 2.1, cz - 1))
	addAll(list, MapKitShapes.capsule("KnifeHandle", 8, 1.6, BEAM, "Wood", v(16, 5.5, cz - 3), v(0, -15, 25)))
	part(
		list,
		"KnifeBlade",
		"Block",
		v(18, 2.2, 0.3),
		{ r = 214, g = 220, b = 228 },
		"Metal",
		v(5, 3.5, cz - 1),
		v(0, -15, 25)
	).reflectance =
		0.45
	-- 거대 셰프 (머리가 결승 문 위로 보여요 — 목표 표지)
	local sx, sz = 0, cz - 26
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ChefTorso",
			v(48, 40, 24),
			CHEF_WHITE,
			"Fabric",
			v(sx, 6, sz),
			{ radius = 8, style = "vertical" }
		)
	)
	part(list, "ChefApron", "Block", v(30, 30, 1), P.Noren, "Fabric", v(sx, 2, sz + 12.4))
	part(list, "ChefCollar", "Block", v(18, 3, 25), shade(CHEF_WHITE, 0.9), "Fabric", v(sx, 27, sz))
	part(list, "ChefHead", "Ball", v(26, 26, 26), SKIN, "SmoothPlastic", v(sx, 40, sz))
	part(list, "ChefHatBand", "Cylinder", v(6, 25, 25), CHEF_WHITE, "Fabric", v(sx, 52, sz), UP)
	part(list, "ChefHat", "Ball", v(30, 30, 30), CHEF_WHITE, "Fabric", v(sx, 62, sz))
	part(list, "ChefHachimaki", "Cylinder", v(2.4, 26.4, 26.4), P.Noren, "Fabric", v(sx, 48.6, sz), UP)
	for _, s in { -1, 1 } do
		part(list, "ChefEye", "Ball", v(3, 3, 3), BLACK, "SmoothPlastic", v(sx + s * 5, 43, sz + 11.2)).reflectance =
			0.35
		part(
			list,
			"ChefBrow",
			"Block",
			v(5, 1, 1),
			BLACK,
			"SmoothPlastic",
			v(sx + s * 5, 46.4, sz + 11.6),
			v(0, 0, s * -12)
		)
		part(list, "ChefCheek", "Ball", v(4, 4, 4), BLUSH, "SmoothPlastic", v(sx + s * 8, 37.5, sz + 9.6))
		addAll(
			list,
			MapKitShapes.capsule(
				"ChefArm",
				26,
				10,
				CHEF_WHITE,
				"Fabric",
				v(sx + s * 27, 8, sz + 12),
				v(0, s * 60, -40 * s)
			)
		)
		part(list, "ChefHand", "Ball", v(9, 9, 9), SKIN, "SmoothPlastic", v(sx + s * 20, 4, sz + 24))
	end
	part(list, "ChefNose", "Ball", v(4, 4, 4), shade(SKIN, 0.94), "SmoothPlastic", v(sx, 40, sz + 12.4))
	part(list, "ChefSmile", "Block", v(7, 1.2, 1), MOUTH, "SmoothPlastic", v(sx, 35, sz + 12.2))
	-- 마네키네코 (오른쪽 받침 위, 팔이 흔들려요)
	local mx, mz = 46, cz + 4
	part(list, "NekoStand", "Block", v(14, 2, 12), P.Lacquer, "SmoothPlastic", v(mx, 2, mz))
	part(list, "NekoBody", "Ball", v(10, 10, 10), WHITE, "SmoothPlastic", v(mx, 7.5, mz))
	part(list, "NekoHead", "Ball", v(8.4, 8.4, 8.4), WHITE, "SmoothPlastic", v(mx, 14.5, mz + 0.5))
	for _, s in { -1, 1 } do
		part(list, "NekoEar", "Wedge", v(1, 2.6, 2.4), WHITE, "SmoothPlastic", v(mx + s * 2.6, 19, mz + 0.5))
		part(list, "NekoEye", "Ball", v(1.2, 1.2, 1.2), BLACK, "SmoothPlastic", v(mx + s * 1.6, 15, mz + 4.4))
	end
	part(list, "NekoBib", "Cylinder", v(1, 5, 5), P.Lacquer, "SmoothPlastic", v(mx, 10.8, mz + 3.6), ALONG_Z)
	part(list, "NekoBell", "Ball", v(1.6, 1.6, 1.6), { r = 230, g = 190, b = 60 }, "Metal", v(mx, 10, mz + 5.2)).reflectance =
		0.4
	local arm = part(list, "NekoArm", "Ball", v(3.4, 3.4, 3.4), WHITE, "SmoothPlastic", v(mx - 5, 16, mz + 2))
	arm.anim = { kind = "Sway", period = 1.6, amount = 18, axis = "Z" }
	part(list, "NekoCoin", "Cylinder", v(0.6, 4, 4), { r = 230, g = 190, b = 60 }, "Metal", v(mx, 7, mz + 5.2), ALONG_Z).reflectance =
		0.4
	-- 계산대 위 회전 진열대 (왼쪽, 접시 셋이 천천히 돌아요)
	local rx, rz = -46, cz + 4
	disc(list, "TurntableBase", 3, 8, BLACK, "Metal", rx, 1, rz)
	local turntable = disc(list, "Turntable", 1, 16, P.Lacquer, "SmoothPlastic", rx, 4, rz)
	turntable.anim = { kind = "Spin", period = 9, amount = 0 }
	local spin = disc(list, "TurntablePlates", 2.4, 13, WHITE, "SmoothPlastic", rx, 5, rz)
	spin.anim = { kind = "Spin", period = 9, amount = 0 }
	-- 셰프 쪽 김 (밥통)
	disc(list, "RiceTub", 10, 18, { r = 150, g = 100, b = 60 }, "Wood", -26, 2, cz - 6)
	disc(list, "RiceTubBand", 1.4, 18.6, { r = 196, g = 156, b = 72 }, "Metal", -26, 6, cz - 6)
	local rice = disc(list, "RiceTubRice", 1, 16, WHITE, "SmoothPlastic", -26, 11.6, cz - 6)
	rice.particle = "Steam"
	rice.particleRate = 1.5
	-- 작업대 위 따뜻한 등 (빛 원인)
	local hood = part(list, "ChefLamp", "Cylinder", v(2, 10, 10), LAMP_PAPER, "Neon", v(0, 84, cz), UP)
	hood.light = { kind = "Point", color = LAMP_LIGHT, brightness = 1.8, range = 50 }
	part(list, "ChefLampShade", "Cylinder", v(5, 14, 14), P.LacquerDark, "SmoothPlastic", v(0, 87, cz), UP)
	part(list, "ChefLampCord", "Block", v(0.4, CEIL_Y - 89, 0.4), BLACK, "SmoothPlastic", v(0, (CEIL_Y + 89) / 2, cz))
end

function RotatingBeltArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local itemIndex = 0
	for _, section in RotatingBeltArt.SECTIONS do
		if section.name == "BeltA" or section.name == "BeltB" then
			addSlats(list, section)
		end
		addRails(list, section)
		addUnderTrim(list, section)
		itemIndex = addCounters(list, section, itemIndex)
	end
	addNarrow(list)
	addSoyGlints(list) -- m5-20 ①
	addFinish(list)
	addLanterns(list)
	addFace(list, -32, -30, RotatingBeltArt.FACE_EYE, 0, SKIN, SHIRTS[1], HAIRS[1])
	addFace(list, 32, -62, RotatingBeltArt.FACE_EYE, 0.6, { r = 236, g = 192, b = 156 }, SHIRTS[2], HAIRS[2])
	addFace(list, -32, -94, RotatingBeltArt.FACE_EYE, -0.4, { r = 248, g = 212, b = 182 }, SHIRTS[3], HAIRS[3])
	-- m5-24: 손님 둘 더 (저녁 손님 몰림)
	addFace(list, 32, -8, RotatingBeltArt.GUEST_EYE, -0.6, { r = 226, g = 178, b = 140 }, SHIRTS[4], HAIRS[1])
	addFace(list, 32, -110, RotatingBeltArt.GUEST_EYE, 0.4, SKIN, P.Lacquer, HAIRS[3])
	-- m5-24 가게 환경
	addRoomShell(list)
	addCourseSupports(list)
	addDiningTables(list)
	addGuestCounters(list)
	addOverheadRails(list)
	addSideWalls(list)
	addEndWall(list)
	addChefStation(list)
	return list
end

function RotatingBeltArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 14, 6), lookAt = v(0, 2, -24) }, -- 출발 위
		{ pos = v(0, 17, -66), lookAt = v(0, 2, -88) }, -- 병목 → 젓가락 구간
		{ pos = v(0, 26, -62), lookAt = v(0, 1, -68) }, -- m5-20 ⑤: 병목 바로 위 반전 샷 (내려다봄, 등 사이로 지나가요)
		{ pos = v(0, 18, -96), lookAt = v(0, 3, -118) }, -- 결승 노렌
		{ pos = v(0, 12, 10), lookAt = v(0, 3, -20) }, -- 출발선 뒤 (내 자리)
	}
end

function RotatingBeltArt.courseVolume(): { Bounds }
	local boxes: { Bounds } = {}
	for _, section in RotatingBeltArt.SECTIONS do
		table.insert(boxes, {
			min = v(-section.half, 2, section.back),
			max = v(section.half, 12, section.front),
		})
	end
	return boxes
end

return RotatingBeltArt
