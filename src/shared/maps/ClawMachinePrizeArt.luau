--!strict
-- "인형뽑기 기계 속" 아트 데이터 (m5-19, m4-02 공통 규칙). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정(칸 격자·집게 일정·상자 기울기)은 ClawMachinePrizeLogic/ClawMachinePrize 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 map origin 기준 로컬이에요(가게·크레인·벽은). 칸 장식(tileDecor)만 그 칸 파츠 CFrame 기준 로컬이에요.
--   ClawMachinePrizeArt.decor() -> { DecorSpec }               유리벽 4면 + 천장, 크레인 레일(정적), 오락실 네온
--   ClawMachinePrizeArt.tileDecor(row, col) -> { DecorSpec }   칸 하나 위 저예산 인형 더미 2개(몸+머리)
--   ClawMachinePrizeArt.introCamera() -> { IntroPoint }        상자 전체 → 집게 레일 → 인형 더미 → 출발 자리
--   ClawMachinePrizeArt.courseVolume() -> Bounds                장식이 가리면 안 되는 상자(칸 윗면 위, 천장 아래)
--   ClawMachinePrizeArt.NEON                                    PointLight를 붙일 네온 장식 파츠 이름

local Layout = require(script.Parent.ClawMachinePrizeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local ClawMachinePrizeArt = {}

ClawMachinePrizeArt.NEON = "Neon"
ClawMachinePrizeArt.WALL_HEIGHT = 30 -- 유리 상자 벽 높이 (칸 윗면 변화폭 ±1.5보다 훨씬 커요)
ClawMachinePrizeArt.WALL_THICKNESS = 1
ClawMachinePrizeArt.RAIL_HEIGHT = ClawMachinePrizeArt.WALL_HEIGHT - 2 -- 천장 바로 아래 크레인 레일
ClawMachinePrizeArt.SIGHT_MIN = 2 -- 칸 윗면 변화폭(±1.5) 위, 시야를 가리면 안 되는 상자 바닥
ClawMachinePrizeArt.SIGHT_MAX = ClawMachinePrizeArt.RAIL_HEIGHT - 2 -- 레일 바로 아래까지

local GLASS: RGB = { r = 205, g = 232, b = 246 }
local SILVER: RGB = { r = 196, g = 200, b = 208 }
local RED_BUTTON: RGB = { r = 220, g = 50, b = 60 }
local MARQUEE: RGB = { r = 60, g = 40, b = 90 }
local NEON_PINK: RGB = { r = 255, g = 110, b = 190 }
local NEON_YELLOW: RGB = { r = 255, g = 220, b = 90 }
local COIN_SLOT: RGB = { r = 90, g = 94, b = 104 }

-- 저예산 인형 팔레트 (몸 색 6가지, 칸 index로 순환)
local PLUSH_PALETTE: { RGB } = {
	{ r = 250, g = 160, b = 170 }, -- 분홍
	{ r = 160, g = 210, b = 250 }, -- 하늘
	{ r = 250, g = 220, b = 130 }, -- 노랑
	{ r = 180, g = 230, b = 170 }, -- 연두
	{ r = 230, g = 180, b = 250 }, -- 라벤더
	{ r = 250, g = 190, b = 150 }, -- 살구
}

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

local BOX = Layout.BOX_SIZE
local CZ = Layout.CENTER_Z
local WT = ClawMachinePrizeArt.WALL_THICKNESS
local WH = ClawMachinePrizeArt.WALL_HEIGHT

-- 유리벽 4면 + 천장. 전부 투명도 0.88 이상이라 시야를 거의 가리지 않아요.
local function addGlassBox(list: { DecorSpec })
	local half = BOX / 2
	part(list, "GlassWallNorth", "Block", v(BOX, WH, WT), GLASS, "Glass", v(0, WH / 2, CZ - half), nil, 0.9)
	part(list, "GlassWallSouth", "Block", v(BOX, WH, WT), GLASS, "Glass", v(0, WH / 2, CZ + half), nil, 0.9)
	part(list, "GlassWallWest", "Block", v(WT, WH, BOX), GLASS, "Glass", v(-half, WH / 2, CZ), nil, 0.9)
	part(list, "GlassWallEast", "Block", v(WT, WH, BOX), GLASS, "Glass", v(half, WH / 2, CZ), nil, 0.9)
	part(list, "GlassCeiling", "Block", v(BOX, WT, BOX), GLASS, "Glass", v(0, WH, CZ), nil, 0.9)
end

-- 크레인 레일(가로 1축 + 세로 1축 교차) + 받침 기둥. 전부 장식(충돌 없음) — 실제로 움직이는 집게
-- 발톱은 판정 쪽(ClawMachinePrize.luau)이 따로 모델로 만들어요.
local function addCrane(list: { DecorSpec })
	local y = ClawMachinePrizeArt.RAIL_HEIGHT
	-- 원기둥 축은 로컬 X. RailX는 회전 없이(축이 이미 X), RailZ는 Y로 90도 돌려 축을 Z로.
	part(list, "RailX", "Cylinder", v(BOX - 2, 1.4, 1.4), SILVER, "Metal", v(0, y, CZ))
	part(list, "RailZ", "Cylinder", v(BOX - 2, 1.4, 1.4), SILVER, "Metal", v(0, y, CZ), v(0, 90, 0))
	for _, side in { -1, 1 } do
		part(
			list,
			"RailPost",
			"Block",
			v(1.6, WH - y, 1.6),
			SILVER,
			"Metal",
			v(side * (BOX / 2 - 2), (WH + y) / 2, CZ - (BOX / 2 - 2))
		)
		part(
			list,
			"RailPost",
			"Block",
			v(1.6, WH - y, 1.6),
			SILVER,
			"Metal",
			v(side * (BOX / 2 - 2), (WH + y) / 2, CZ + (BOX / 2 - 2))
		)
	end
	part(list, "RailHub", "Ball", v(2.6, 2.6, 2.6), SILVER, "Metal", v(0, y, CZ))
end

-- 상자 밖 오락실 간판·동전 투입구 (네온 PointLight는 ClawMachinePrize.luau가 NEON 이름 파츠에 붙여요)
local function addArcadeFront(list: { DecorSpec })
	local z = CZ + BOX / 2 + 3
	part(list, "CabinetBody", "Block", v(BOX * 0.7, 14, 4), MARQUEE, "Plastic", v(0, 7, z))
	part(
		list,
		ClawMachinePrizeArt.NEON,
		"Block",
		v(BOX * 0.55, 3, 0.4),
		NEON_PINK,
		"Neon",
		v(0, 15.5, z - 1.9),
		nil,
		0.1
	)
	part(list, "MarqueeTrim", "Block", v(BOX * 0.6, 1, 0.5), NEON_YELLOW, "Neon", v(0, 13.3, z - 2), nil, 0.2)
	part(list, "CoinSlot", "Block", v(2, 3, 0.6), COIN_SLOT, "Metal", v(-BOX * 0.2, 2, z - 1.7))
	part(
		list,
		"JoystickBase",
		"Cylinder",
		v(1, 2.4, 2.4),
		RED_BUTTON,
		"SmoothPlastic",
		v(BOX * 0.2, 1.2, z - 1.6),
		UPRIGHT
	)
	part(list, "JoystickKnob", "Ball", v(1.4, 1.4, 1.4), RED_BUTTON, "Neon", v(BOX * 0.2, 2.5, z - 1.6))
end

function ClawMachinePrizeArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addGlassBox(list)
	addCrane(list)
	addArcadeFront(list)
	return list
end

-- 칸(row, col) 위 저예산 인형 더미 2개(몸 Block + 머리 Ball). 칸 파츠 CFrame 기준 로컬 오프셋이라
-- MapKit.buildDecor(…, tilePart.CFrame, tilePart)로 칸 파츠 아래 자식으로 넣으면 칸이 사라질 때 같이 사라져요.
function ClawMachinePrizeArt.tileDecor(row: number, col: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local index = (Layout.tileIndex(row, col) or 0)
	local topY = Layout.THICKNESS / 2
	for i, corner in { { -1, -1 }, { 1, 1 } } do
		local color = PLUSH_PALETTE[(index + i) % #PLUSH_PALETTE + 1]
		local dx, dz = corner[1] * 1.3, corner[2] * 1.3
		part(list, "Plush", "Block", v(2.2, 1.5, 2.2), color, "Fabric", v(dx, topY + 0.75, dz))
		part(list, "PlushHead", "Ball", v(1.5, 1.5, 1.5), color, "Fabric", v(dx, topY + 1.9, dz))
	end
	return list
end

-- 상자 앞(가게 쪽) → 집게 레일 → 인형 더미 → 출발 자리(격자 가운데, 낮은 각도)
function ClawMachinePrizeArt.introCamera(): { IntroPoint }
	local half = BOX / 2
	return {
		{ pos = v(half + 10, 18, CZ + half + 6), lookAt = v(0, 4, CZ) },
		{
			pos = v(0, ClawMachinePrizeArt.RAIL_HEIGHT + 2, CZ - half + 6),
			lookAt = v(0, ClawMachinePrizeArt.RAIL_HEIGHT, CZ),
		},
		{ pos = v(half - 6, 6, CZ + half - 6), lookAt = v(0, 1, CZ) },
		{ pos = v(0, 5, CZ + 14), lookAt = v(0, 0, CZ) },
	}
end

-- 장식이 들어가면 안 되는 상자: 칸 윗면 변화폭 위(SIGHT_MIN)부터 레일 바로 아래(SIGHT_MAX)까지, 격자 안쪽.
function ClawMachinePrizeArt.courseVolume(): Bounds
	local half = BOX / 2 - 0.5
	return {
		min = v(-half, ClawMachinePrizeArt.SIGHT_MIN, CZ - half),
		max = v(half, ClawMachinePrizeArt.SIGHT_MAX, CZ + half),
	}
end

return ClawMachinePrizeArt
