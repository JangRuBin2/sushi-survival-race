--!strict
-- "뜨거운 철판" 아트 데이터 (m4-03). Roblox API를 쓰지 않아요 — lune 테스트(tests/map-art-arena.spec.luau)에서 바로 불러요.
-- 판정 지오메트리(타일·층·탈락 높이)는 HotPlateLogic 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   HotPlateArt.decor() -> { DecorSpec }        주방 철판 장식 (origin 기준 로컬, MapKit.buildDecor로 만들어요)
--   HotPlateArt.introCamera() -> { IntroPoint } 손으로 짠 소개 카메라 경로 (손님 얼굴 → 층 옆 → 위층 → 바깥 끝점)
--   HotPlateArt.courseVolume() -> { Bounds }    장식이 들어가면 안 되는 상자 (층마다 윗면 위 2~12, 철판 안쪽)
--   HotPlateArt.isGlowing(elapsed) -> boolean    달아오른 타일을 Neon으로 바꿀 때인지 (색 단계 시간은 그대로)
--   HotPlateArt.STEAM_VENT, HOOD_LAMP            ParticleEmitter·PointLight를 붙일 장식 파츠 이름

local HotPlateLogic = require(script.Parent.HotPlateLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE

local HotPlateArt = {}

HotPlateArt.STEAM_VENT = "SteamVent"
HotPlateArt.HOOD_LAMP = "HoodLamp"
-- 달아오름 진행도(0~1)가 이 이상이면 Neon으로 은은하게 빛나요 (단계·사라지는 시간은 HotPlateLogic 그대로)
HotPlateArt.GLOW_FROM = 0.6
-- 시야 상자: 층 윗면 위 이 높이 범위에는 장식을 두지 않아요
HotPlateArt.SIGHT_MIN = 2
HotPlateArt.SIGHT_MAX = 12

local STAINLESS: RGB = { r = 200, g = 204, b = 210 }
local OIL: RGB = { r = 236, g = 200, b = 90 }
local MOUTH_RED: RGB = { r = 200, g = 40, b = 52 }
local MOUTH_DARK: RGB = { r = 70, g = 12, b = 20 }
local TONGUE: RGB = { r = 232, g = 112, b = 132 }
local CHEEK: RGB = { r = 244, g = 150, b = 150 }
local SKINS: { RGB } = {
	{ r = 240, g = 200, b = 170 },
	{ r = 222, g = 176, b = 136 },
	{ r = 250, g = 214, b = 186 },
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

-- 세운 원판(원기둥 축을 Y로): 원기둥은 축이 로컬 X라 Z로 90° 돌려요
local UPRIGHT = v(0, 0, 90)

local function plateHalf(): number
	return HotPlateLogic.plateSize() / 2
end

-- 층 테두리(스테인리스)·기름 자국·김 나는 곳
local function addFrames(list: { DecorSpec })
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	for layer = 1, HotPlateLogic.LAYER_COUNT do
		local top = HotPlateLogic.layerTopY(layer)
		local y = top - 0.7 -- 높이 1.4 → 윗면이 타일과 같아요 (턱처럼 보이지 않게, m4-03 QA B3)
		for _, side in { -1, 1 } do
			part(list, "Frame", "Block", v(2, 1.4, half * 2 + 4), STAINLESS, "Metal", v(side * (half + 1), y, cz))
			part(list, "Frame", "Block", v(half * 2, 1.4, 2), STAINLESS, "Metal", v(0, y, cz + side * (half + 1)))
		end
		-- 기름 튄 자국 (테두리 위 얇은 노란 원판)
		local spots = {
			v(half + 1, top + 0.03, cz + 17 - 6 * layer),
			v(-(half + 1), top + 0.03, cz - 11 + 4 * layer),
			v(12 - 8 * layer, top + 0.03, cz - (half + 1)),
		}
		for i, at in spots do
			local d = 1.1 + 0.25 * ((i + layer) % 3)
			part(list, "OilSplatter", "Cylinder", v(0.06, d, d), OIL, "SmoothPlastic", at, UPRIGHT, 0.15)
		end
	end
	-- 김 나는 곳 (투명, HotPlate.build가 ParticleEmitter를 달아요). 타일 위가 아니라 테두리 위.
	for _, at in
		{
			v(half + 1, HotPlateLogic.layerTopY(1) + 0.1, cz + 11),
			v(-(half + 1), HotPlateLogic.layerTopY(1) + 0.1, cz - 13),
			v(half + 1, HotPlateLogic.layerTopY(2) + 0.1, cz - 15),
			v(-(half + 1), HotPlateLogic.layerTopY(2) + 0.1, cz + 15),
		}
	do
		part(list, HotPlateArt.STEAM_VENT, "Block", v(1, 0.2, 1), STAINLESS, "SmoothPlastic", at, nil, 1)
	end
end

-- 층 모서리 기둥 4개 (맨 아래층 밑부터 후드 아래까지)
local function addPillars(list: { DecorSpec })
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	local bottom = HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT) - 2
	local top = 26
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				list,
				"Pillar",
				"Cylinder",
				v(top - bottom, 2, 2),
				STAINLESS,
				"Metal",
				v(sx * (half + 1), (top + bottom) / 2, cz + sz * (half + 1)),
				UPRIGHT
			)
		end
	end
end

-- 위를 보고 입 벌린 거대 손님 얼굴 (맨 아래층 밑). 얼굴 앞면이 +Y, 턱이 +Z 쪽이에요.
local function addCustomerFace(list: { DecorSpec }, cx: number, cz: number, skin: RGB)
	local headY = -80
	local radius = 14
	local top = headY + radius
	part(list, "CustomerHead", "Ball", v(radius * 2, radius * 2, radius * 2), skin, "SmoothPlastic", v(cx, headY, cz))
	part(list, "CustomerLips", "Cylinder", v(3, 13, 13), MOUTH_RED, "SmoothPlastic", v(cx, top - 0.5, cz + 1), UPRIGHT)
	part(
		list,
		"CustomerMouth",
		"Cylinder",
		v(3.2, 10, 10),
		MOUTH_DARK,
		"SmoothPlastic",
		v(cx, top - 0.3, cz + 1),
		UPRIGHT
	)
	part(
		list,
		"CustomerTongue",
		"Cylinder",
		v(1, 4.5, 4.5),
		TONGUE,
		"SmoothPlastic",
		v(cx, top + 1.4, cz + 2.8),
		UPRIGHT
	)
	for i = -1, 1 do
		part(
			list,
			"CustomerTooth",
			"Block",
			v(1.4, 1.2, 1.2),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + i * 2.2, top + 1.6, cz - 3.2)
		)
		part(
			list,
			"CustomerTooth",
			"Block",
			v(1.4, 1.2, 1.2),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + i * 2.2, top + 1.6, cz + 5.2)
		)
	end
	for _, side in { -1, 1 } do
		part(
			list,
			"CustomerEye",
			"Ball",
			v(4, 4, 4),
			PALETTE.Rice,
			"SmoothPlastic",
			v(cx + side * 4.5, top - 3, cz - 8)
		)
		part(
			list,
			"CustomerPupil",
			"Ball",
			v(2, 2, 2),
			PALETTE.Nori,
			"SmoothPlastic",
			v(cx + side * 4.5, top - 1.2, cz - 8.4)
		)
		part(
			list,
			"CustomerCheek",
			"Cylinder",
			v(0.6, 3.5, 3.5),
			CHEEK,
			"SmoothPlastic",
			v(cx + side * 8, top - 2.6, cz + 3),
			UPRIGHT
		)
	end
end

-- Z축으로 tilt도 기운 물건의 부품 위치 (base 기준 로컬 (lx, ly)를 돌려요 — MapKitLogic 회전과 같은 방향)
local function tilted(base: Vec3, tilt: number, lx: number, ly: number): Vec3
	local c, s = math.cos(math.rad(tilt)), math.sin(math.rad(tilt))
	return v(base.x + lx * c - ly * s, base.y + lx * s + ly * c, base.z)
end

-- 철판 옆에 기대 세운 거대 주걱 (날 + 목 + 나무 손잡이)
local function addSpatula(list: { DecorSpec }, base: Vec3, tilt: number)
	part(list, "SpatulaBlade", "Block", v(0.6, 12, 10), STAINLESS, "Metal", tilted(base, tilt, 0, 0), v(0, 0, tilt))
	part(list, "SpatulaNeck", "Block", v(0.6, 3, 2), STAINLESS, "Metal", tilted(base, tilt, 0, 7.5), v(0, 0, tilt))
	part(
		list,
		"SpatulaHandle",
		"Cylinder",
		v(16, 2, 2),
		PALETTE.Wood,
		"Wood",
		tilted(base, tilt, 0, 17),
		v(0, 0, 90 + tilt)
	)
	part(list, "SpatulaRivet", "Ball", v(1, 1, 1), PALETTE.Nori, "Metal", tilted(base, tilt, 0, 9.5), nil)
end

-- 머리 위 환풍기 후드 (맨 위층보다 25 이상 높이)
local function addHood(list: { DecorSpec })
	local cz = HotPlateLogic.centerZ()
	local dark: RGB = { r = 64, g = 66, b = 70 }
	part(list, "HoodCanopy", "Block", v(40, 3, 40), STAINLESS, "Metal", v(0, 34, cz))
	part(list, "HoodCeiling", "Block", v(64, 0.4, 64), dark, "Metal", v(0, 30, cz))
	for _, side in { -1, 1 } do
		part(list, "HoodSkirt", "Block", v(66, 5, 1), STAINLESS, "Metal", v(0, 27.5, cz + side * 33))
		part(list, "HoodSkirt", "Block", v(1, 5, 66), STAINLESS, "Metal", v(side * 33, 27.5, cz))
		part(
			list,
			"HoodSlope",
			"Block",
			v(66, 1, 14),
			STAINLESS,
			"Metal",
			v(0, 32, cz + side * 26),
			v(side * -20, 0, 0)
		)
	end
	for i = -2, 2 do
		part(list, "HoodGrille", "Block", v(40, 0.3, 0.6), PALETTE.Nori, "Metal", v(0, 29.6, cz + i * 6))
	end
	part(list, "HoodDuct", "Cylinder", v(40, 10, 10), STAINLESS, "Metal", v(0, 55, cz), UPRIGHT)
	for _, side in { -1, 1 } do
		part(
			list,
			HotPlateArt.HOOD_LAMP,
			"Ball",
			v(2, 2, 2),
			{ r = 255, g = 230, b = 170 },
			"Neon",
			v(side * 14, 29, cz)
		)
	end
end

-- 철판 뒤 주방 벽 (흰 타일)
local function addKitchenWall(list: { DecorSpec })
	local wallZ = HotPlateLogic.centerZ() - 90 -- QA B2: 카메라 줌아웃에 걸리지 않게 멀리
	part(list, "KitchenWall", "Block", v(150, 140, 2), { r = 232, g = 236, b = 232 }, "CeramicTiles", v(0, -30, wallZ))
	part(list, "KitchenShelf", "Block", v(60, 1, 5), STAINLESS, "Metal", v(0, 14, wallZ + 3.5))
	-- 선반 위 소스 병·통
	part(list, "SauceBottle", "Cylinder", v(7, 3, 3), PALETTE.Soy, "Glass", v(-20, 18, wallZ + 3.5), UPRIGHT)
	part(list, "SauceBottle", "Cylinder", v(6, 3, 3), PALETTE.Egg, "Glass", v(-15, 17.5, wallZ + 3.5), UPRIGHT)
	part(list, "SauceBottle", "Cylinder", v(8, 3, 3), PALETTE.Tuna, "Glass", v(18, 18.5, wallZ + 3.5), UPRIGHT)
	part(list, "SaltTub", "Cylinder", v(3, 5, 5), PALETTE.Rice, "SmoothPlastic", v(8, 16, wallZ + 3.5), UPRIGHT)
end

function HotPlateArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	addFrames(list)
	addPillars(list)
	addCustomerFace(list, -15, cz + 13, SKINS[1])
	addCustomerFace(list, 15, cz + 5, SKINS[2])
	addCustomerFace(list, -2, cz - 19, SKINS[3])
	local spatulaBaseY = HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT) + 26
	addSpatula(list, v(-(half + 10), spatulaBaseY, cz + 11), -15)
	addSpatula(list, v(half + 10, spatulaBaseY, cz - 13), 15)
	addHood(list)
	addKitchenWall(list)
	return list
end

-- 손님 얼굴(아래) → 층 옆 → 맨 위층 → 맨 위층 바깥 앞쪽 끝점 (철판 가운데를 봐요)
function HotPlateArt.introCamera(): { IntroPoint }
	local cz = HotPlateLogic.centerZ()
	local bottom = HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT)
	return {
		{ pos = v(-55, bottom - 10, cz - 33), lookAt = v(0, bottom - 26, cz) },
		{ pos = v(55, -22, cz - 23), lookAt = v(0, -30, cz) },
		{ pos = v(50, 14, cz + 37), lookAt = v(0, 0, cz) },
		{ pos = v(0, 18, cz + 65), lookAt = v(0, 0, cz) },
	}
end

-- 층마다 윗면 위 SIGHT_MIN~SIGHT_MAX, 철판 안쪽 상자
function HotPlateArt.courseVolume(): { MapKitLogic.Bounds }
	local half = plateHalf()
	local cz = HotPlateLogic.centerZ()
	local boxes = {}
	for layer = 1, HotPlateLogic.LAYER_COUNT do
		local top = HotPlateLogic.layerTopY(layer)
		table.insert(boxes, {
			min = v(-half, top + HotPlateArt.SIGHT_MIN, cz - half),
			max = v(half, top + HotPlateArt.SIGHT_MAX, cz + half),
		})
	end
	return boxes
end

function HotPlateArt.isGlowing(elapsed: number): boolean
	return elapsed >= HotPlateLogic.HEAT_DURATION * HotPlateArt.GLOW_FROM
end

return HotPlateArt
