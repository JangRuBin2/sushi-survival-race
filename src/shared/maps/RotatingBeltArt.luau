--!strict
-- 회전 벨트 아트 (m4-02): 장식·소개 카메라·색을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   RotatingBeltArt.COLORS          판정 파츠(바닥·벽·종지·젓가락)에 칠할 색 { r, g, b }
--   RotatingBeltArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   RotatingBeltArt.introCamera()   라운드 소개 경유점 (출발 위 → 젓가락 → 결승 → 출발선 뒤 높이 12)
--   RotatingBeltArt.courseVolume()  장식이 들어가면 안 되는 상자들 (구간마다 벽 안쪽, 바닥 위 2~12)
-- 코스 치수는 RotatingBelt.luau의 값을 그대로 옮겨 적었어요 (판정 지오메트리는 그쪽이 정해요).
-- 좌표는 origin 기준 로컬: x 좌우, y 위(바닥 윗면 0), z 0이 출발선이고 -Z로 갈수록 결승.

local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }
export type Section = { name: string, front: number, back: number, half: number }

local P = MapKitLogic.PALETTE

local RotatingBeltArt = {}

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
RotatingBeltArt.SOY_DISH_X = 4.5 -- 병목 양옆 간장 종지 (판정 파츠) 중심 x
RotatingBeltArt.SOY_DISH_ZS = { -68, -60, -52 }

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

local UP: Vec3 = { x = 0, y = 0, z = 90 } -- Cylinder 축(X)을 세워요

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
)
	table.insert(list, {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	})
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
)
	part(list, name, "Cylinder", v(h, d, d), color, material, v(x, y + h / 2, z), UP)
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
		part(
			list,
			"WallRail",
			"Block",
			v(0.5, 0.4, depth),
			RAIL,
			"Metal",
			v(wallX, RotatingBeltArt.WALL_HEIGHT + 0.2, centerZ)
		)
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

-- 손님 카운터 + 카운터 위 소품(초밥 접시·간장병·찻잔) + 의자
local COUNTER_WIDTH = 5
local COUNTER_TOP = 2.5

local function counterInner(section: Section): number
	-- 병목은 간장 종지(판정 파츠) 바깥에 카운터를 둬요
	return if section.name == "Narrow" then RotatingBeltArt.SOY_DISH_X + 1.5 else section.half + 0.5
end

local function addCounterItem(list: { DecorSpec }, index: number, x: number, z: number)
	local kind = index % 3
	if kind == 0 then
		local plate = PLATE_COLORS[(index // 3) % #PLATE_COLORS + 1]
		local topping = TOPPINGS[(index // 3 + 1) % #TOPPINGS + 1]
		disc(list, "SushiPlate", 0.2, 2, plate, "SmoothPlastic", x, COUNTER_TOP, z)
		part(list, "NigiriRice", "Block", v(0.6, 0.45, 1.1), WHITE, "SmoothPlastic", v(x, COUNTER_TOP + 0.425, z))
		part(list, "NigiriTopping", "Block", v(0.7, 0.18, 1.25), topping, "SmoothPlastic", v(x, COUNTER_TOP + 0.74, z))
	elseif kind == 1 then
		disc(list, "SoyBottle", 1.6, 0.7, SOY_BOTTLE, "Glass", x, COUNTER_TOP, z)
		disc(list, "SoyBottleCap", 0.4, 0.45, P.Lacquer, "SmoothPlastic", x, COUNTER_TOP + 1.6, z)
	else
		disc(list, "Teacup", 0.8, 0.7, TEA, "SmoothPlastic", x, COUNTER_TOP, z)
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
			v(counterX, COUNTER_TOP - 1, centerZ)
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
local function addFace(list: { DecorSpec }, x: number, z: number)
	local d = if x < 0 then 1 else -1
	local cy = 8
	part(list, "FaceHead", "Ball", v(20, 20, 20), SKIN, "SmoothPlastic", v(x, cy, z))
	part(list, "FaceHair", "Block", v(16, 4, 18), BLACK, "Fabric", v(x - d * 1, cy + 9, z))
	for _, s in { -1, 1 } do
		part(list, "FaceEye", "Ball", v(2.4, 2.4, 2.4), BLACK, "SmoothPlastic", v(x + d * 8.6, cy + 3, z + s * 3.5))
		part(
			list,
			"FaceEyeShine",
			"Ball",
			v(0.8, 0.8, 0.8),
			WHITE,
			"SmoothPlastic",
			v(x + d * 9.7, cy + 3.4, z + s * 3.3)
		)
		part(
			list,
			"FaceBrow",
			"Block",
			v(0.6, 0.6, 3),
			BLACK,
			"SmoothPlastic",
			v(x + d * 8.2, cy + 5.6, z + s * 3.5),
			v(s * 15, 0, 0)
		)
		part(list, "FaceBlush", "Ball", v(2.5, 2.5, 2.5), BLUSH, "SmoothPlastic", v(x + d * 7.7, cy - 1, z + s * 6))
	end
	part(list, "FaceMouth", "Ball", v(6, 6, 6), MOUTH, "SmoothPlastic", v(x + d * 7.4, cy - 4.2, z))
	part(list, "FaceTongue", "Ball", v(3, 3, 3), TONGUE, "SmoothPlastic", v(x + d * 8.9, cy - 5.4, z))
end

-- 병목: 종지 테두리(남색)·간장 면 + 색 접시 더미
local function addNarrow(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * RotatingBeltArt.SOY_DISH_X
		for _, z in RotatingBeltArt.SOY_DISH_ZS do
			disc(list, "SoyDishRim", 0.15, 2.15, P.PorcelainRim, "SmoothPlastic", x, 1.88, z)
			disc(list, "SoyDishSauce", 0.05, 1.6, P.Soy, "Glass", x, 2.02, z)
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
		part(list, "GatePost", "Block", v(1, 16, 1), P.Lacquer, "Wood", v(side * 11.25, 8, gateZ))
	end
	part(list, "GateBeam", "Block", v(25, 1, 1.2), P.Lacquer, "Wood", v(0, 15.6, gateZ))
	for i = 0, 3 do
		local x = -7.5 + i * 5
		part(list, "Noren", "Block", v(4.8, 2.8, 0.2), P.Noren, "Fabric", v(x, 13.6, gateZ))
		part(list, "NorenMark", "Ball", v(1.4, 1.4, 1.4), WHITE, "Fabric", v(x, 13.8, gateZ + 0.2))
	end
end

-- 머리 위 종이 등 (바닥 위 20 이상)
local function addLanterns(list: { DecorSpec })
	for _, z in { -24, -60, -90 } do
		part(list, "Lantern", "Ball", v(3, 3, 3), P.Lacquer, "Fabric", v(0, 22, z))
		disc(list, "LanternCap", 0.4, 1.6, BLACK, "SmoothPlastic", 0, 23.4, z)
	end
end

function RotatingBeltArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local itemIndex = 0
	for _, section in RotatingBeltArt.SECTIONS do
		if section.name == "BeltA" or section.name == "BeltB" then
			addSlats(list, section)
		end
		addRails(list, section)
		itemIndex = addCounters(list, section, itemIndex)
	end
	addNarrow(list)
	addFinish(list)
	addLanterns(list)
	addFace(list, -32, -30)
	addFace(list, 32, -62)
	addFace(list, -32, -94)
	return list
end

function RotatingBeltArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 14, 6), lookAt = v(0, 2, -24) }, -- 출발 위
		{ pos = v(0, 17, -66), lookAt = v(0, 2, -88) }, -- 병목 → 젓가락 구간
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
