--!strict
-- "고양이 카페 캣타워" 아트 데이터 (m5-17). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정 지오메트리(선반·탈락 높이)는 CatCafeShelvesLayout 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   CatCafeShelvesArt.decor() -> { DecorSpec }   파스텔 카페 장식 (origin 기준 로컬, MapKit.buildDecor로 만들어요)
--   CatCafeShelvesArt.introCamera() -> { IntroPoint }  카페 전경 → 1단 스폰 → 타워 옆모습 → 꼭대기 캣방석
--   CatCafeShelvesArt.WINDOW_LIGHT, SUNBEAM       PointLight·ParticleEmitter를 붙일 장식 파츠 이름

local Layout = require(script.Parent.CatCafeShelvesLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local Art = {}

Art.WINDOW_LIGHT = "WindowLight" -- 창가 햇살 느낌 조명 (build가 PointLight를 붙여요)
Art.SUNBEAM = "Sunbeam" -- 창가 먼지 반짝임 (build가 ParticleEmitter를 붙여요)

local WALL: RGB = { r = 250, g = 222, b = 230 } -- 연분홍 벽
local WALL_TRIM: RGB = { r = 255, g = 244, b = 236 } -- 크림색 몰딩
local WOOD: RGB = { r = 196, g = 150, b = 102 } -- 바닥 느낌 나무
local PILLAR: RGB = { r = 176, g = 128, b = 88 }
local CUSHION_PINK: RGB = { r = 244, g = 170, b = 188 }
local CUSHION_CREAM: RGB = { r = 250, g = 236, b = 210 }
local BASKET: RGB = { r = 150, g = 104, b = 64 }
local YARN: RGB = { r = 232, g = 140, b = 150 }
local PAW_PAD: RGB = { r = 232, g = 180, b = 150 }
local GLASS: RGB = { r = 220, g = 240, b = 250 }
local SIGN: RGB = { r = 120, g = 70, b = 56 }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function part(
	list: { DecorSpec },
	name: string,
	shape: Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?,
	transparency: number?
)
	table.insert(list, {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
		transparency = transparency,
	})
end

-- 세운 원판(원기둥 축을 Y로): 원기둥은 축이 로컬 X라 Z로 90° 돌려요 (다른 맵 아트와 같은 관례)
local UPRIGHT = v(0, 0, 90)

local CX = Layout.TOWER_CENTER_X
local CZ = Layout.TOWER_CENTER_Z

-- 바닥·벽 (카페 배경, 판정과 무관)
local function addBackdrop(list: { DecorSpec })
	local half = Layout.TIER1_OUTER / 2 + 20
	part(list, "CafeFloor", "Block", v(half * 2, 2, half * 2), WOOD, "WoodPlanks", v(CX, Layout.ELIMINATION_Y - 20, CZ))
	part(
		list,
		"CafeWallBack",
		"Block",
		v(half * 2, 60, 2),
		WALL,
		"SmoothPlastic",
		v(CX, Layout.ELIMINATION_Y + 10, CZ - half)
	)
	for _, side in { -1, 1 } do
		part(
			list,
			"CafeWallSide",
			"Block",
			v(2, 60, half * 2),
			WALL,
			"SmoothPlastic",
			v(CX + side * half, Layout.ELIMINATION_Y + 10, CZ)
		)
		part(
			list,
			"CafeWallTrim",
			"Block",
			v(2, 2, half * 2),
			WALL_TRIM,
			"SmoothPlastic",
			v(CX + side * half, Layout.ELIMINATION_Y + 38, CZ)
		)
		-- 창문 (유리 + 햇살 조명·먼지)
		part(
			list,
			"Window",
			"Block",
			v(0.6, 14, 14),
			GLASS,
			"Glass",
			v(CX + side * (half - 0.3), Layout.TIER1_TOP_Y + 6, CZ - half + 24),
			nil,
			0.4
		)
		part(
			list,
			Art.WINDOW_LIGHT,
			"Block",
			v(0.4, 2, 2),
			{ r = 255, g = 240, b = 210 },
			"Neon",
			v(CX + side * (half - 1), Layout.TIER1_TOP_Y + 6, CZ - half + 24)
		)
		part(
			list,
			Art.SUNBEAM,
			"Block",
			v(0.2, 0.2, 0.2),
			{ r = 255, g = 250, b = 230 },
			"Neon",
			v(CX + side * (half - 2), Layout.TIER1_TOP_Y + 4, CZ - half + 28),
			nil,
			1
		)
	end
end

-- 캣타워 옆 장식 기둥 3개 (구조적으로 떠받치지 않아요, 순수 장식 — 캣타워처럼 보이게)
local function addPillars(list: { DecorSpec })
	local radius = Layout.TIER1_OUTER / 2 + 6
	local bottom = Layout.ELIMINATION_Y + 2
	local top = Layout.TIER3_TOP_Y + 18
	for i = 0, 2 do
		local angle = math.rad(90 + i * 120)
		local x = CX + math.cos(angle) * radius
		local z = CZ + math.sin(angle) * radius
		part(
			list,
			"TowerPillar",
			"Cylinder",
			v(top - bottom, 3, 3),
			PILLAR,
			"Wood",
			v(x, (top + bottom) / 2, z),
			UPRIGHT
		)
	end
end

-- 1단 테두리 바깥쪽 고양이 발자국 패턴 (선반 하나당 2개, 8개)
local function addPawPrints(list: { DecorSpec })
	local offsets = {
		{ x = CX - 10, z = CZ + 22 },
		{ x = CX + 10, z = CZ + 22 },
		{ x = CX - 10, z = CZ - 22 },
		{ x = CX + 10, z = CZ - 22 },
		{ x = CX + 22, z = CZ - 10 },
		{ x = CX + 22, z = CZ + 10 },
		{ x = CX - 22, z = CZ - 10 },
		{ x = CX - 22, z = CZ + 10 },
	}
	for _, at in offsets do
		part(
			list,
			"PawPrint",
			"Cylinder",
			v(0.05, 2.4, 2.4),
			PAW_PAD,
			"SmoothPlastic",
			v(at.x, Layout.TIER1_TOP_Y + 0.03, at.z),
			UPRIGHT,
			0.2
		)
	end
end

-- 1단 모서리 장난감 바구니(+실뭉치) 4개, 2단 작은 쿠션 4개
local function addShelfDecor(list: { DecorSpec })
	local tier1Edge = Layout.TIER1_OUTER / 2 - Layout.SHELF_WIDTH / 2
	local baskets = {
		{ x = CX + tier1Edge, z = CZ + tier1Edge },
		{ x = CX - tier1Edge, z = CZ + tier1Edge },
		{ x = CX + tier1Edge, z = CZ - tier1Edge },
		{ x = CX - tier1Edge, z = CZ - tier1Edge },
	}
	for _, at in baskets do
		part(
			list,
			"ToyBasket",
			"Cylinder",
			v(1.4, 1.6, 1.6),
			BASKET,
			"WoodPlanks",
			v(at.x, Layout.TIER1_TOP_Y + 0.7, at.z),
			UPRIGHT
		)
		part(list, "YarnBall", "Ball", v(1, 1, 1), YARN, "Fabric", v(at.x, Layout.TIER1_TOP_Y + 1.9, at.z))
	end

	local tier2Edge = Layout.TIER2_OUTER / 2 - Layout.SHELF_WIDTH / 2
	local cushions = {
		{ x = CX, z = CZ + tier2Edge },
		{ x = CX, z = CZ - tier2Edge },
		{ x = CX + tier2Edge, z = CZ },
		{ x = CX - tier2Edge, z = CZ },
	}
	for i, at in cushions do
		local color = if i % 2 == 0 then CUSHION_PINK else CUSHION_CREAM
		part(list, "Cushion", "Block", v(2.4, 0.8, 2.4), color, "Fabric", v(at.x, Layout.TIER2_TOP_Y + 0.4, at.z))
	end
end

-- 꼭대기(3단) 큰 캣방석
local function addCatBed(list: { DecorSpec })
	part(list, "CatBed", "Ball", v(8, 1.6, 8), CUSHION_PINK, "Fabric", v(CX, Layout.TIER3_TOP_Y + 0.8, CZ))
	part(
		list,
		"CatBedRim",
		"Cylinder",
		v(0.4, 4.4, 4.4),
		CUSHION_CREAM,
		"Fabric",
		v(CX, Layout.TIER3_TOP_Y + 1.5, CZ),
		UPRIGHT
	)
end

-- 카페 간판 (입구 쪽, 장식)
local function addSign(list: { DecorSpec })
	local half = Layout.TIER1_OUTER / 2 + 20
	part(list, "CafeSign", "Block", v(14, 4, 1), SIGN, "Wood", v(CX, Layout.TIER3_TOP_Y + 14, CZ - half + 2))
	part(
		list,
		"CafeSignPost",
		"Cylinder",
		v(10, 1, 1),
		SIGN,
		"Wood",
		v(CX, Layout.TIER3_TOP_Y + 9, CZ - half + 2),
		UPRIGHT
	)
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addBackdrop(list)
	addPillars(list)
	addPawPrints(list)
	addShelfDecor(list)
	addCatBed(list)
	addSign(list)
	return list
end

-- 카페 전경 → 1단 스폰 → 타워 옆모습(올려보기) → 꼭대기 캣방석
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(CX + 50, Layout.TIER2_TOP_Y + 30, CZ + 50), lookAt = v(CX, Layout.TIER2_TOP_Y, CZ) },
		{
			pos = v(CX + 18, Layout.TIER1_TOP_Y + 4, CZ - 18),
			lookAt = v(CX, Layout.TIER1_TOP_Y, CZ),
		},
		{
			pos = v(CX + 30, Layout.TIER1_TOP_Y - 4, CZ),
			lookAt = v(CX, Layout.TIER3_TOP_Y + 6, CZ),
		},
		{ pos = v(CX, Layout.TIER3_TOP_Y + 10, CZ + 14), lookAt = v(CX, Layout.TIER3_TOP_Y, CZ) },
	}
end

return Art
