--!strict
-- 간장 늪 & 와사비 산 아트 (m4-02): 장식·소개 카메라·색을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   SoySwampArt.COLORS          판정 파츠(바닥·산·경사로·웅덩이·패드·날치알)에 칠할 색 { r, g, b }
--   SoySwampArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   SoySwampArt.introCamera()   라운드 소개 경유점 (출발 위 → 와사비 패드·절벽 → 날치알 내리막·결승 → 출발선 뒤)
--   SoySwampArt.courseVolume()  장식이 들어가면 안 되는 상자들 (구간마다 벽 안쪽, 그 구간 바닥 위 2~12)
-- 코스 치수는 전부 SoySwampLayout에서 읽어요 (판정 수치는 그쪽이 정해요).

local Layout = require(script.Parent.SoySwampLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local P = MapKitLogic.PALETTE

local SoySwampArt = {}

-- 판정 파츠 색 (크기·위치·충돌은 SoySwamp가 그대로 둬요). 바닥은 와사비 연두·간장과 헷갈리지 않게 채도를 낮춰요.
SoySwampArt.COLORS = {
	floor = { r = 172, g = 132, b = 92 }, -- 나무 바닥
	swamp = { r = 140, g = 118, b = 96 }, -- 늪 진흙 판
	soy = { r = 66, g = 32, b = 14 }, -- 간장 웅덩이
	mountain = { r = 118, g = 142, b = 92 }, -- 와사비 산 몸통 (패드보다 어둡고 탁하게)
	wasabi = { r = 150, g = 230, b = 70 }, -- 와사비 패드 (밝은 연두, Neon)
	ramp = P.Wood, -- 경사로 나무
	slope = { r = 214, g = 150, b = 104 }, -- 날치알 내리막 (따뜻한 주황 나무)
	wall = { r = 226, g = 232, b = 238 },
	spawn = { r = 246, g = 196, b = 70 },
	finish = { r = 255, g = 196, b = 40 },
	tobiko = { r = 255, g = 112, b = 28 }, -- 날치알 공
} :: { [string]: RGB }

SoySwampArt.SOY_REFLECTANCE = 0.25

local HALF = Layout.WIDTH / 2
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

-- 와사비 산 양옆 벽 바깥에 층층 언덕 (산이 벽 너머로 이어지는 느낌)
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
			part(
				list,
				"WasabiHill",
				"Block",
				v(layer.w, layer.h, layer.d),
				HILLS[(i - 1) % #HILLS + 1],
				"Sand",
				v(x, y, centerZ)
			)
		end
		-- 꼭대기 밥알 눈
		part(list, "HillRice", "Ball", v(5, 5, 5), WHITE, "Sand", v(side * (HALF + 3.75), 20.5, centerZ))
	end
end

-- 날치알 그릇: 내리막 꼭대기 옆(오른쪽 벽 바깥)에서 공이 굴러 나오는 것처럼
local function addTobikoBowl(list: { DecorSpec })
	local x, z = HALF + 9, Layout.BALL_SPAWN_Z - 2
	local y = Layout.SLOPE_HIGH
	disc(list, "TobikoBowl", 4, 12, P.Porcelain, "SmoothPlastic", x, y, z)
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
end

-- 거대한 간장병 (라벨 붉은 띠), 왼쪽 늪 바깥
local function addSoyBottle(list: { DecorSpec })
	local x, z = -(HALF + 22), -38
	disc(list, "SoyBottleBody", 34, 14, SOY_BOTTLE, "Glass", x, 0, z)
	part(list, "SoyBottleShoulder", "Ball", v(14, 14, 14), SOY_BOTTLE, "Glass", v(x, 34, z))
	disc(list, "SoyBottleNeck", 6, 6, SOY_BOTTLE, "Glass", x, 39, z)
	disc(list, "SoyBottleCap", 3, 7, P.Lacquer, "SmoothPlastic", x, 45, z)
	disc(list, "SoyBottleBand", 8, 14.4, P.Lacquer, "SmoothPlastic", x, 12, z)
	part(list, "SoyBottleLabel", "Block", v(0.3, 6, 5), WHITE, "SmoothPlastic", v(x + 7.3, 16, z))
end

-- 고추냉이 강판 + 와사비 덩이, 오른쪽 늪 바깥
local function addGrater(list: { DecorSpec })
	local x, z = HALF + 18, -30
	part(list, "GraterBoard", "Block", v(1.5, 24, 14), GRATER, "Metal", v(x, 12, z))
	part(list, "GraterHandle", "Block", v(1.5, 8, 4), P.Wood, "Wood", v(x, 28, z))
	for row = 0, 3 do
		for col = 0, 2 do
			part(
				list,
				"GraterTooth",
				"Ball",
				v(0.9, 0.9, 0.9),
				GRATER,
				"Metal",
				v(x - 0.9, 5 + row * 5, z - 4 + col * 4)
			)
		end
	end
	part(list, "WasabiRoot", "Ball", v(5, 5, 5), P.Wasabi, "Sand", v(x - 4, 2.5, z + 4))
	part(list, "GratedWasabi", "Ball", v(3, 3, 3), P.Wasabi, "Sand", v(x - 3, 1.5, z - 3))
end

-- 생강 더미 (분홍), 오른쪽 내리막 바깥
local function addGinger(list: { DecorSpec })
	local x, z = HALF + 16, -128
	local baseY = 8
	disc(list, "GingerDish", 1.5, 16, P.Porcelain, "SmoothPlastic", x, baseY, z)
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
			GINGER,
			"SmoothPlastic",
			v(x + ox, y, z + oz),
			v(8, angle, 6)
		)
	end
end

-- 결승선 체크무늬 (결승선 위에 얇게)
local function addFinishChecker(list: { DecorSpec })
	local lineZ = Layout.finishLineZ()
	local y = Layout.SLOPE_HIGH + 0.45
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
local function addLanterns(list: { DecorSpec })
	for _, z in { -24, -48 } do
		part(list, "Lantern", "Ball", v(3, 3, 3), P.Lacquer, "Fabric", v(LANTERN_X, 22, z))
		disc(list, "LanternCap", 0.4, 1.6, BLACK, "SmoothPlastic", LANTERN_X, 23.4, z)
	end
end

function SoySwampArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPuddleRims(list)
	addWasabiBumps(list)
	addHills(list)
	addTobikoBowl(list)
	addSoyBottle(list)
	addGrater(list)
	addGinger(list)
	addFinishChecker(list)
	addLanterns(list)
	return list
end

function SoySwampArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 16, 4), lookAt = v(0, 2, -30) }, -- 출발 위, 간장 늪
		{ pos = v(-4, 26, -50), lookAt = v(-4, 6, -72) }, -- 와사비 패드 → 절벽
		{ pos = v(0, 38, -128), lookAt = v(0, 20, -168) }, -- 날치알 내리막 → 결승
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
	return {
		-- 출발·늪·산 앞 평지 (바닥 0)
		box(-HALF, HALF, Layout.APPROACH.back, Layout.START.front, 0),
		-- 산 몸통 꼭대기 (바닥 12)
		box(-HALF, bodyRight, Layout.MOUNTAIN.back, Layout.MOUNTAIN.front, h),
		-- 오른쪽 경사로 + 지면 통로 (바닥 0 → 12)
		box(bodyRight, HALF, Layout.MOUNTAIN.back, Layout.MOUNTAIN.front, 0, h),
		-- 날치알 내리막 (바닥 12 → 20)
		box(-HALF, HALF, Layout.SLOPE.back, Layout.SLOPE.front, Layout.SLOPE_LOW, Layout.SLOPE_HIGH),
		-- 결승 (바닥 20)
		box(-HALF, HALF, Layout.FINISH.back, Layout.FINISH.front, Layout.SLOPE_HIGH),
	}
end

return SoySwampArt
