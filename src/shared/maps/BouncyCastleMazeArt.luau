--!strict
-- "방방 미로" 아트 (m5-14): 장식·소개 카메라·색을 순수 데이터로 적어요 (Roblox API 없음 → lune 테스트).
--   BouncyCastleMazeArt.COLORS          판정 파츠(바닥·BounceFloor·벽·칸막이·관문·결승)에 칠할 색 { r, g, b }
--   BouncyCastleMazeArt.decor()         장식 DecorSpec 목록 (MapKit.buildDecor로 Decor 폴더에, 충돌·쿼리·터치 없음)
--   BouncyCastleMazeArt.introCamera()   소개 경유점 (입구 → 1번 레인 위에서 내려다보기 → 꺾이는 지점 → 결승 문)
-- 알록달록한 원색 파스텔 유원지 방방 미로 느낌: 체크무늬 바닥, 통통 튀는 비닐 느낌의 벽·칸막이·관문,
-- 테두리 공기 주입구·풍선·깃발, 색색의 조명. 코스 치수는 전부 BouncyCastleMazeLayout에서 읽어요
-- (판정 수치는 그쪽이 정해요. 장식은 충돌·쿼리·터치가 없어서 코스 판정에 영향을 주지 않아요).

local Layout = require(script.Parent.BouncyCastleMazeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local P = MapKitLogic.PALETTE

local BouncyCastleMazeArt = {}

-- 판정 파츠 색 (크기·위치·충돌은 BouncyCastleMaze가 그대로 둬요).
BouncyCastleMazeArt.COLORS = {
	floor = { r = 250, g = 240, b = 225 }, -- A·D·E 일반 바닥 (따뜻한 베이지)
	bounceFloor = { r = 255, g = 205, b = 130 }, -- B·C BounceFloor (말랑한 주황 매트)
	wall = { r = 255, g = 120, b = 156 }, -- 바깥 벽 (분홍 비닐)
	gate = { r = 255, g = 92, b = 92 }, -- 입구 문 (경고 빨강)
	partition1 = { r = 100, g = 176, b = 255 }, -- 1·2레인 칸막이 (파랑)
	partition2 = { r = 132, g = 220, b = 120 }, -- 2·3레인 칸막이 (초록)
	partition3 = { r = 206, g = 142, b = 255 }, -- 3·4레인 칸막이 (보라)
	spawn = { r = 246, g = 196, b = 70 },
	finish = { r = 255, g = 196, b = 40 },
} :: { [string]: RGB }

-- 칸막이 x 위치 순서(Layout.PARTITIONS와 같은 순서)와 1:1인 색 이름
BouncyCastleMazeArt.PARTITION_COLOR_KEYS = { "partition1", "partition2", "partition3" }

-- m5-14 파티클·조명 이름 상수
BouncyCastleMazeArt.LAMP = "CarnivalLamp"

local HALF = Layout.HALF_WIDTH
local UP: Vec3 = { x = 0, y = 0, z = 90 } -- Cylinder 축(X)을 세워요
local WHITE = P.Rice
local STRIPE_RED = { r = 220, g = 50, b = 60 }
local BALLOON_COLORS = {
	{ r = 255, g = 120, b = 140 },
	{ r = 120, g = 200, b = 255 },
	{ r = 255, g = 214, b = 110 },
	{ r = 150, g = 230, b = 140 },
}
-- 색색의 조명(아래 addLamps에서 사용, build가 CarnivalLamp 파츠마다 PointLight를 붙여요)
BouncyCastleMazeArt.LAMP_COLORS = {
	{ r = 255, g = 120, b = 140 },
	{ r = 120, g = 200, b = 255 },
	{ r = 255, g = 214, b = 110 },
	{ r = 150, g = 230, b = 140 },
	{ r = 220, g = 140, b = 255 },
}

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

-- 체크무늬 바닥 패턴: B·C 구간(BounceFloor) 위에 얇은 판, 판정 바닥과 분리된 장식 레이어.
local function addFloorChecker(list: { DecorSpec })
	local tile = 5
	local startZ = Layout.ANTEROOM.front -- -16
	local depth = startZ - Layout.MAZE.back -- 94
	local rows = math.floor(depth / tile)
	local cols = math.floor(Layout.WIDTH / tile)
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local color = if (row + col) % 2 == 0 then BouncyCastleMazeArt.COLORS.bounceFloor else WHITE
			part(
				list,
				"FloorChecker",
				"Block",
				v(tile - 0.3, 0.06, tile - 0.3),
				color,
				"SmoothPlastic",
				v(-HALF + tile / 2 + col * tile, 0.08, startZ - tile / 2 - row * tile)
			)
		end
	end
end

-- 입구 문 경고 줄무늬 (관문 위, 빨강-흰 사선 느낌의 블록들). 1번 레인이 벽에 붙어 있으면(왼쪽 폭 0)
-- 그쪽은 건너뛰고, 막힌 폭(보통 오른쪽)에만 줄무늬를 그려요.
local function addGateStripes(list: { DecorSpec })
	local gate = Layout.GATE
	local y = Layout.WALL_HEIGHT * 0.85
	local function stripeBlock(xMin: number, xMax: number)
		local blockWidth = xMax - xMin
		if blockWidth <= 0 then
			return
		end
		local centerX = (xMin + xMax) / 2
		local count = 4
		for i = 0, count - 1 do
			local color = if i % 2 == 0 then STRIPE_RED else WHITE
			part(
				list,
				"GateStripe",
				"Block",
				v(blockWidth / count, 1.4, 0.3),
				color,
				"SmoothPlastic",
				v(centerX - blockWidth / 2 + (i + 0.5) * (blockWidth / count), y, gate.z)
			)
		end
	end
	stripeBlock(Layout.BOUNDS.xMin, gate.openXMin)
	stripeBlock(gate.openXMax, Layout.BOUNDS.xMax)
end

-- 칸막이·벽 위 둥근 풍선 장식 (통통 튀는 느낌)
local function addBalloons(list: { DecorSpec })
	local y = Layout.WALL_HEIGHT + 1.4
	local count = 0
	for _, partition in Layout.PARTITIONS do
		for _, z in
			{ partition.blockedZHigh, (partition.blockedZHigh + partition.blockedZLow) / 2, partition.blockedZLow }
		do
			count += 1
			local color = BALLOON_COLORS[(count - 1) % #BALLOON_COLORS + 1]
			part(list, "PartitionBalloon", "Ball", v(1.8, 1.8, 1.8), color, "SmoothPlastic", v(partition.x, y, z))
		end
	end
	for _, side in { -1, 1 } do
		for i, z in { Layout.ANTEROOM.front, -45, -90, Layout.MAZE.back } do
			count += 1
			local color = BALLOON_COLORS[(count + i) % #BALLOON_COLORS + 1]
			part(list, "WallBalloon", "Ball", v(1.6, 1.6, 1.6), color, "SmoothPlastic", v(side * (HALF + 1), y, z))
		end
	end
end

-- 바깥 벽 위 삼각 깃발 줄 (Wedge 사용)
local function addFlags(list: { DecorSpec })
	local y = Layout.WALL_HEIGHT + 0.8
	local spacing = 12
	local colors = BALLOON_COLORS
	for _, side in { -1, 1 } do
		local z = Layout.START.front - 4
		local i = 0
		while z > Layout.FINISH.back + 4 do
			local color = colors[(i % #colors) + 1]
			part(
				list,
				"WallFlag",
				"Wedge",
				v(1.4, 1.6, 1),
				color,
				"Fabric",
				v(side * (HALF + 0.6), y, z),
				v(0, if side > 0 then 90 else -90, 0)
			)
			z -= spacing
			i += 1
		end
	end
end

-- 테두리 공기 주입구 (바운스 구간 바깥쪽 벽에 붙은 둥근 통풍구)
local function addAirVents(list: { DecorSpec })
	local y = 3
	for _, side in { -1, 1 } do
		for _, z in { Layout.ANTEROOM.front - 2, -65, Layout.MAZE.back + 2 } do
			disc(list, "AirVent", 1.2, 3, { r = 230, g = 230, b = 236 }, "Metal", side * (HALF - 0.6), y, z)
			disc(list, "AirVentRim", 0.3, 3.4, { r = 150, g = 150, b = 160 }, "Metal", side * (HALF - 0.6), y + 0.75, z)
		end
	end
end

-- 색색의 유원지 조명 기둥 (예산 12개 안에서 여러 색)
local function addLamps(list: { DecorSpec })
	local positions = { Layout.START.front - 6, -18, -55, -95, Layout.EXIT.front - 4, Layout.FINISH_LINE_Z - 4 }
	for i, z in positions do
		local x = if i % 2 == 0 then -(HALF - 3) else (HALF - 3)
		local color = BouncyCastleMazeArt.LAMP_COLORS[(i - 1) % #BouncyCastleMazeArt.LAMP_COLORS + 1]
		disc(list, "LampPost", 8, 0.6, { r = 210, g = 210, b = 216 }, "Metal", x, 0, z)
		part(list, BouncyCastleMazeArt.LAMP, "Ball", v(1.4, 1.4, 1.4), color, "Neon", v(x, 8.6, z))
	end
end

-- 결승 체크무늬 (결승선 위에 얇게)
local function addFinishChecker(list: { DecorSpec })
	local lineZ = Layout.finishLineZ()
	local y = 0.45
	local cols = Layout.WIDTH
	for row = 0, 1 do
		for col = 0, cols - 1 do
			local color = if (row + col) % 2 == 0 then WHITE else STRIPE_RED
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

function BouncyCastleMazeArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addFloorChecker(list)
	addGateStripes(list)
	addBalloons(list)
	addFlags(list)
	addAirVents(list)
	addLamps(list)
	addFinishChecker(list)
	return list
end

function BouncyCastleMazeArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 22, 8), lookAt = v(0, 4, -18) }, -- 입구 (출발 위에서 관문을 봐요)
		{ pos = v(-15, 34, -40), lookAt = v(-15, 2, -70) }, -- 1번 레인 위에서 내려다보기
		{ pos = v(2, 26, -32), lookAt = v(2, 4, -22) }, -- 꺾이는 지점(2·3레인 교차, 입구 쪽 틈)
		{ pos = v(0, 16, -126), lookAt = v(0, 3, -136) }, -- 결승 문
	}
end

return BouncyCastleMazeArt
