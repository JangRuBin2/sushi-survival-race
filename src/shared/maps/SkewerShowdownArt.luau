--!strict
-- "회전 꼬치 쇼다운" 아트 데이터 (m4-03). Roblox API를 쓰지 않아요 — lune 테스트(tests/map-art-arena.spec.luau)에서 바로 불러요.
-- 판정(무대 조각·꼬치·기둥·셰프 손 일정·낙하 높이)은 SkewerShowdownLogic/SkewerShowdown 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 무대 중심(origin, 윗면 높이 0) 기준 로컬이에요. 가게 문은 로컬 -Z 쪽 (우승 연출에서 초밥이 문을 박차고
-- 나가는 방향(장면 로컬 -Z)과 같아요).
--   SkewerShowdownArt.decor() -> { DecorSpec }          움직이지 않는 장식 (기둥 장식, 접시 굽, 가게 문, 아래 셰프)
--   SkewerShowdownArt.sliceDecor(index) -> { DecorSpec } 조각 하나에 붙는 장식 (금 선, 남색 테두리) — 조각 Model에 넣어 같이 사라져요
--   SkewerShowdownArt.skewerFood(spec) -> { DecorSpec }  꼬치에 꽂힌 닭·대파 (꼬치 로컬: X = 바깥쪽, 꼬치 가운데 = 0)
--   SkewerShowdownArt.skewerHitbox(spec) -> Bounds       꼬치 판정 상자 (꼬치 로컬). 음식 장식은 이 안에만 둬요
--   SkewerShowdownArt.skewerFoodWithinHitbox(specs, spec) -> (boolean, string?)
--   SkewerShowdownArt.handDecor() -> { DecorSpec }       셰프 손 장식 (손바닥 중심 로컬): 손끝, 소매
--   SkewerShowdownArt.introCamera() -> { IntroPoint }    가게 문 → 무대 한 바퀴 → 무대 바깥 끝점
--   SkewerShowdownArt.courseVolume() -> { Bounds }       장식이 들어가면 안 되는 상자 (무대 윗면 위 2~12, 반지름 안)
--   SkewerShowdownArt.LANTERN                            PointLight를 붙일 장식 파츠 이름

local Logic = require(script.Parent.SkewerShowdownLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE

local SkewerShowdownArt = {}

SkewerShowdownArt.LANTERN = "Lantern"
SkewerShowdownArt.SIGHT_MIN = 2
SkewerShowdownArt.SIGHT_MAX = 12
-- 가게 문 위치 (무대 앞쪽 = 로컬 -Z, 뛰어서 닿지 않는 거리. M2 ShopDoor와 같은 자리)
SkewerShowdownArt.DOOR_Z = -(Logic.STAGE_RADIUS + 18)

-- SkewerShowdown.luau의 무대 치수와 같아요 (판정 수치를 바꾸지 않으려고 여기서 다시 계산해요)
local STAGE_THICKNESS = 1.5
local STRIPS_PER_SLICE = 8
local SLICE_ANGLE = 2 * math.pi / Logic.SLICE_COUNT
local APOTHEM = Logic.STAGE_RADIUS * math.cos(SLICE_ANGLE / 2)
local EDGE_LENGTH = 2 * Logic.STAGE_RADIUS * math.sin(SLICE_ANGLE / 2)

local GOLD: RGB = { r = 214, g = 172, b = 64 }
local DARK_WOOD: RGB = { r = 104, g = 74, b = 50 }
local DOOR_WOOD: RGB = { r = 160, g = 118, b = 74 }
local PLASTER: RGB = { r = 236, g = 226, b = 200 }
local SKIN: RGB = { r = 240, g = 198, b = 166 }
local CHICKEN: RGB = { r = 170, g = 94, b = 44 }
local LEEK_WHITE: RGB = { r = 236, g = 240, b = 218 }
local LEEK_GREEN: RGB = { r = 108, g = 160, b = 60 }
local EXIT_GREEN: RGB = { r = 40, g = 160, b = 80 }

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

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로
local FACING_Z = v(0, 90, 0) -- 원기둥 축을 Z로 (앞을 보는 원판)

-- 무대 중심 기준 각도 angle(꼬치 각도와 같은 기준) 방향으로 radial만큼 간 점
local function radial(angle: number, r: number, y: number): Vec3
	return v(r * math.cos(angle), y, -r * math.sin(angle))
end

-- 기둥 위 금 띠·뚜껑, 무대 밑 접시 굽
local function addPillarAndFoot(list: { DecorSpec })
	part(list, "PillarBand", "Cylinder", v(0.6, 5.6, 5.6), GOLD, "Metal", v(0, 14.5, 0), UPRIGHT)
	part(list, "PillarCap", "Cylinder", v(0.8, 6.2, 6.2), GOLD, "Metal", v(0, 16.4, 0), UPRIGHT)
	part(list, "PillarFinial", "Ball", v(2.4, 2.4, 2.4), GOLD, "Metal", v(0, 17.8, 0))
	part(list, "PlateFoot", "Cylinder", v(2, 18, 18), PALETTE.Porcelain, "SmoothPlastic", v(0, -2.6, 0), UPRIGHT)
	part(
		list,
		"PlateFootBand",
		"Cylinder",
		v(0.6, 18.4, 18.4),
		PALETTE.PorcelainRim,
		"SmoothPlastic",
		v(0, -2.4, 0),
		UPRIGHT
	)
end

-- 미닫이 문짝 하나 (나무 틀 + 창호지 창 2개 + 살)
local function addDoorLeaf(list: { DecorSpec }, x: number, z: number)
	part(list, "DoorLeaf", "Block", v(5.8, 14, 0.4), DOOR_WOOD, "Wood", v(x, 7, z))
	for _, y in { 4, 10 } do
		part(list, "DoorPaper", "Block", v(4.2, 5, 0.1), PALETTE.Rice, "SmoothPlastic", v(x, y, z + 0.25))
		part(list, "DoorBar", "Block", v(0.3, 5, 0.15), DARK_WOOD, "Wood", v(x, y, z + 0.32))
		part(list, "DoorBar", "Block", v(4.2, 0.3, 0.15), DARK_WOOD, "Wood", v(x, y, z + 0.32))
	end
end

-- 가게 문: 나무 미닫이 + 노렌 + 출구 판 + 등롱 + 가게 앞면
local function addShopDoor(list: { DecorSpec })
	local z = SkewerShowdownArt.DOOR_Z
	part(list, "Porch", "Block", v(32, 1, 10), PALETTE.Wood, "WoodPlanks", v(0, -0.5, z + 1))
	part(list, "ShopBody", "Block", v(46, 24, 18), DARK_WOOD, "WoodPlanks", v(0, 12, z - 10.5))
	for _, side in { -1, 1 } do
		part(list, "DoorPost", "Block", v(2, 16, 2), DARK_WOOD, "Wood", v(side * 7, 8, z))
		part(list, "ShopWall", "Block", v(15, 22, 1.5), PLASTER, "Plaster", v(side * 15, 11, z - 0.8))
		part(list, "ShopBeam", "Block", v(15, 2, 1.7), DARK_WOOD, "Wood", v(side * 15, 1, z - 0.7))
		part(list, "ShopBeam", "Block", v(2, 22, 1.7), DARK_WOOD, "Wood", v(side * 22.5, 11, z - 0.7))
		addDoorLeaf(list, side * 3, z)
		-- 등롱 (빨간 몸통 + 검은 뚜껑·받침). LANTERN 파츠에 PointLight가 붙어요.
		part(list, SkewerShowdownArt.LANTERN, "Ball", v(3, 3, 3), PALETTE.Lacquer, "Neon", v(side * 9.5, 12.5, z + 1.8))
		part(
			list,
			"LanternCap",
			"Cylinder",
			v(0.5, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 14.1, z + 1.8),
			UPRIGHT
		)
		part(
			list,
			"LanternCap",
			"Cylinder",
			v(0.5, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 10.9, z + 1.8),
			UPRIGHT
		)
		part(
			list,
			"LanternCord",
			"Block",
			v(0.2, 2.6, 0.2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 9.5, 15.6, z + 1.8)
		)
	end
	part(list, "DoorLintel", "Block", v(16, 2, 2.5), DARK_WOOD, "Wood", v(0, 17, z))
	-- 노렌 3폭 + 가운데 흰 동그라미 문장
	for i = -1, 1 do
		part(list, "Noren", "Block", v(4.4, 4, 0.15), PALETTE.Noren, "Fabric", v(i * 4.6, 13.8, z + 1.3))
	end
	part(list, "NorenCrest", "Cylinder", v(0.05, 2, 2), PALETTE.Rice, "Fabric", v(0, 14.2, z + 1.4), FACING_Z)
	-- "출구" 느낌 초록 판 (흰 화살표)
	part(list, "ExitSign", "Block", v(6, 2, 0.4), EXIT_GREEN, "SmoothPlastic", v(0, 19.4, z + 0.6))
	part(list, "ExitArrow", "Block", v(3, 0.4, 0.1), PALETTE.Rice, "Neon", v(0.4, 19.4, z + 0.85))
	part(list, "ExitArrowHead", "Block", v(1, 1, 0.1), PALETTE.Rice, "Neon", v(-1.1, 19.4, z + 0.85), v(0, 0, 45))
	-- 기와 차양
	part(
		list,
		"DoorRoof",
		"Block",
		v(24, 0.8, 6),
		{ r = 70, g = 72, b = 84 },
		"ClayRoofTiles",
		v(0, 22.4, z + 1),
		v(20, 0, 0)
	)
end

-- 무대 아래 깊은 곳에서 올려다보는 셰프 상체 (모자) — 떨어지면 셰프에게 간다는 느낌
local function addChefBelow(list: { DecorSpec })
	local cz = 6
	part(list, "ChefTorso", "Block", v(34, 22, 16), PALETTE.Rice, "Fabric", v(0, -95, cz))
	part(list, "ChefCollar", "Block", v(20, 2, 17), PALETTE.Noren, "Fabric", v(0, -83.5, cz))
	part(list, "ChefScarf", "Block", v(8, 3, 2), PALETTE.Lacquer, "Fabric", v(0, -85, cz + 8.6))
	part(list, "ChefHead", "Ball", v(20, 20, 20), SKIN, "SmoothPlastic", v(0, -74, cz))
	part(list, "ChefHat", "Cylinder", v(14, 18, 18), PALETTE.Rice, "Fabric", v(0, -60, cz), UPRIGHT)
	part(list, "ChefHatPuff", "Ball", v(22, 22, 22), PALETTE.Rice, "Fabric", v(0, -50, cz))
	for _, side in { -1, 1 } do
		part(list, "ChefEye", "Ball", v(2.4, 2.4, 2.4), PALETTE.Nori, "SmoothPlastic", v(side * 4, -67.5, cz + 6.5))
		part(
			list,
			"ChefMustache",
			"Block",
			v(4.5, 1.2, 1.5),
			PALETTE.Nori,
			"SmoothPlastic",
			v(side * 2.4, -72, cz + 9.4)
		)
		part(list, "ChefArm", "Block", v(6, 26, 6), PALETTE.Rice, "Fabric", v(side * 22, -80, cz), v(0, 0, side * -20))
		part(list, "ChefFist", "Ball", v(7, 7, 7), SKIN, "SmoothPlastic", v(side * 26.6, -66.5, cz))
	end
end

function SkewerShowdownArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPillarAndFoot(list)
	addShopDoor(list)
	addChefBelow(list)
	return list
end

-- 조각 index(1~SLICE_COUNT)에 붙는 장식: 앞쪽 경계의 얇은 금 선(윗면 위 0.05), 바깥 가장자리 남색 테두리.
function SkewerShowdownArt.sliceDecor(index: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local edge = (index - 1) * SLICE_ANGLE
	local bisector = (index - 0.5) * SLICE_ANGLE
	local inner = Logic.PILLAR_DIAMETER / 2 + 0.3
	local outer = APOTHEM - APOTHEM / STRIPS_PER_SLICE - 0.2 -- 남색 띠(바깥 줄) 앞에서 멈춰요
	local mid = (inner + outer) / 2
	part(
		list,
		"GoldLine",
		"Block",
		v(outer - inner, 0.06, 0.25),
		GOLD,
		"Metal",
		radial(edge, mid, 0.05),
		v(0, math.deg(edge), 0)
	)
	part(
		list,
		"RimLip",
		"Block",
		v(0.4, STAGE_THICKNESS + 0.2, EDGE_LENGTH - 0.8),
		PALETTE.PorcelainRim,
		"SmoothPlastic",
		radial(bisector, APOTHEM + 0.2, -STAGE_THICKNESS / 2 + 0.1),
		v(0, math.deg(bisector), 0)
	)
	return list
end

local function skewerLength(spec: Logic.SkewerSpec): number
	return spec.outerReach - spec.innerReach
end

-- 꼬치에 꽂힌 닭(4)·대파(3) 조각. 단면은 꼬치 굵기(지름) 그대로라 판정 상자를 벗어나지 않아요.
function SkewerShowdownArt.skewerFood(spec: Logic.SkewerSpec): { DecorSpec }
	local list: { DecorSpec } = {}
	local thick = spec.radius * 2
	local chicken, leek, gap = 1.8, 1.2, 0.6
	local pieces = { "Chicken", "Leek", "Chicken", "Leek", "Chicken", "Leek", "Chicken" }
	local total = 0
	for i, kind in pieces do
		total += if kind == "Chicken" then chicken else leek
		if i > 1 then
			total += gap
		end
	end
	-- 바깥쪽으로 조금 치우쳐 꽂아요 (안쪽 손잡이 부분은 나무가 보이게)
	local x = -total / 2 + 1
	for _, kind in pieces do
		if kind == "Chicken" then
			part(
				list,
				"SkewerChicken",
				"Block",
				v(chicken, thick, thick),
				CHICKEN,
				"SmoothPlastic",
				v(x + chicken / 2, 0, 0)
			)
			x += chicken + gap
		else
			part(list, "SkewerLeek", "Block", v(0.7, thick, thick), LEEK_WHITE, "SmoothPlastic", v(x + 0.35, 0, 0))
			part(list, "SkewerLeek", "Block", v(0.5, thick, thick), LEEK_GREEN, "SmoothPlastic", v(x + 0.95, 0, 0))
			x += leek + gap
		end
	end
	assert(x - gap <= skewerLength(spec) / 2, "skewer food longer than skewer")
	return list
end

-- 꼬치 판정 상자 (꼬치 로컬). 서버는 몸통(반지름 Logic.BODY_RADIUS)이 꼬치 원기둥에 닿으면 맞음으로 봐요
-- (축에서 radius + BODY_RADIUS 안, 높이 ±radius와 몸통이 겹침). 그래서 원기둥을 감싸는 상자
-- (길이 × 지름 × 지름) 안의 장식은 "보이게 닿으면 맞는다"가 지켜져요.
function SkewerShowdownArt.skewerHitbox(spec: Logic.SkewerSpec): Bounds
	local half = skewerLength(spec) / 2
	return {
		min = v(-half, -spec.radius, -spec.radius),
		max = v(half, spec.radius, spec.radius),
	}
end

local EPSILON = 1e-6

function SkewerShowdownArt.skewerFoodWithinHitbox(specs: { DecorSpec }, spec: Logic.SkewerSpec): (boolean, string?)
	local box = SkewerShowdownArt.skewerHitbox(spec)
	for i, food in specs do
		local b = MapKitLogic.bounds({ food })
		if b == nil then
			continue
		end
		for _, axis in { "x", "y", "z" } do
			local lo, hi = (b.min :: any)[axis], (b.max :: any)[axis]
			if lo < (box.min :: any)[axis] - EPSILON or hi > (box.max :: any)[axis] + EPSILON then
				return false, `#{i} {food.name} sticks out on {axis}`
			end
		end
	end
	return true, nil
end

-- 셰프 손 장식 (손바닥 중심 로컬, SkewerShowdown.buildHand의 손가락 배치와 맞춰요): 둥근 손끝, 흰 조리복 소매
function SkewerShowdownArt.handDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	for i = 1, 4 do
		part(list, "Fingertip", "Ball", v(1.7, 1.7, 1.7), SKIN, "SmoothPlastic", v(-3.6 + (i - 1) * 2.4, -5.5, -3))
	end
	part(list, "Fingertip", "Ball", v(1.9, 1.9, 1.9), SKIN, "SmoothPlastic", v(0, -4.5, 3.6))
	part(list, "Knuckles", "Cylinder", v(9, 1.8, 1.8), SKIN, "SmoothPlastic", v(0, -0.6, -3))
	part(list, "Cuff", "Cylinder", v(1.2, 9.5, 9.5), PALETTE.Noren, "Fabric", v(0, 1.6, 0), UPRIGHT)
	part(list, "Sleeve", "Cylinder", v(10, 9, 9), PALETTE.Rice, "Fabric", v(0, 7.2, 0), UPRIGHT)
	return list
end

-- 가게 문 → 무대 오른쪽 → 뒤 → 왼쪽 → 무대 바깥 높이 16에서 무대 가운데를 보며 끝나요 (m3-04 B2: 끝점이 고정).
function SkewerShowdownArt.introCamera(): { IntroPoint }
	local center = v(0, 0, 0)
	local z = SkewerShowdownArt.DOOR_Z
	return {
		{ pos = v(14, 8, z + 16), lookAt = v(0, 9, z) },
		{ pos = v(36, 12, -16), lookAt = center },
		{ pos = v(18, 14, 34), lookAt = center },
		{ pos = v(-32, 12, 20), lookAt = center },
		{ pos = v(-28, 16, -22), lookAt = center },
	}
end

function SkewerShowdownArt.courseVolume(): { Bounds }
	local r = Logic.STAGE_RADIUS
	return {
		{
			min = v(-r, SkewerShowdownArt.SIGHT_MIN, -r),
			max = v(r, SkewerShowdownArt.SIGHT_MAX, r),
		},
	}
end

return SkewerShowdownArt
