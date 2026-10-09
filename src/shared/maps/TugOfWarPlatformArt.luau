--!strict
-- "줄다리기 발판" 아트 데이터 (m5-18). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정(발판·낙하 깊이·스폰)은 TugOfWarPlatformLayout/TugOfWarPlatform 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 발판 중심(flatPivot = origin * CFrame.new(0, 0, Layout.CENTER_Z), 기울지 않은 상태의 윗면 = y 0)
-- 기준 로컬이에요.
--   TugOfWarPlatformArt.deckDecor() -> { DecorSpec }   발판과 같이 기울어지는 장식 (저울 접시 테두리, 동아줄, 무게추)
--   TugOfWarPlatformArt.decor() -> { DecorSpec }       기울지 않는 장식 (받침대, 가게 마당 배경)
--   TugOfWarPlatformArt.introCamera() -> { IntroPoint } 발판 전체 → 받침대 → 저울 접시 → 출발 자리
--   TugOfWarPlatformArt.LANTERN                        PointLight를 붙일 장식 파츠 이름

local Layout = require(script.Parent.TugOfWarPlatformLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local PALETTE = MapKitLogic.PALETTE

local TugOfWarPlatformArt = {}

TugOfWarPlatformArt.LANTERN = "Lantern"

local GOLD: RGB = { r = 214, g = 172, b = 64 }
local DARK_WOOD: RGB = { r = 104, g = 74, b = 50 }
local ROPE: RGB = { r = 196, g = 158, b = 92 }
local PLASTER: RGB = { r = 236, g = 226, b = 200 }

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

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로 (세워서 접시·기둥 모양)

local PLATFORM_TOP = 0 -- flatPivot 기준 발판 윗면 (기울지 않은 상태)
local PLATFORM_BOTTOM = -Layout.THICKNESS

-- 저울 접시 모양 테두리: 발판 양 끝(바깥쪽) 위에 얕은 받침 접시 + 테두리 턱.
-- 발판 Model 하위에 두어 기울 때 같이 따라가요 (이 함수가 돌려주는 전부가 TugOfWarPlatform의 moving 그룹에 들어가요).
local function addPanRims(list: { DecorSpec })
	for _, side in { -1, 1 } do
		local x = side * (Layout.HALF_LENGTH - 9)
		part(
			list,
			"PanDish",
			"Cylinder",
			v(1, 18, 18),
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(x, PLATFORM_TOP + 0.5, 0),
			UPRIGHT
		)
		part(list, "PanRimLip", "Cylinder", v(0.5, 18.6, 18.6), GOLD, "Metal", v(x, PLATFORM_TOP + 1.05, 0), UPRIGHT)
	end
end

-- 동아줄: 발판 양 끝 바깥으로 늘어진 모양(충돌 없음, 순수 장식). 폭 축으로 2가닥씩 둬서 "줄다리기" 느낌.
local function addRopes(list: { DecorSpec })
	for _, side in { -1, 1 } do
		for _, z in { -6, 6 } do
			part(
				list,
				"Rope",
				"Block",
				v(7, 0.7, 0.7),
				ROPE,
				"Fabric",
				v(side * (Layout.HALF_LENGTH + 2.5), PLATFORM_BOTTOM - 1.5, z),
				v(0, 0, side * 55)
			)
		end
	end
end

-- 발판 위 "추" 장식(간장통·초밥 접시 더미). 발판 Model 하위라 기울면 같이 미끄러질 듯 보여요(실제 물리는 충돌 없음).
local function addWeights(list: { DecorSpec })
	-- 접시 테두리(x ±17~±35) 바깥에 두지 않게 가운데 쪽(±12 이내)에만 둬요
	local positions = { -12, -4, 4, 12 }
	for i, x in positions do
		if i % 2 == 1 then
			part(
				list,
				"SoyBottle",
				"Cylinder",
				v(2.4, 1.4, 1.4),
				PALETTE.Soy,
				"Glass",
				v(x, PLATFORM_TOP + 1.2, 3),
				UPRIGHT
			)
			part(
				list,
				"SoyCap",
				"Cylinder",
				v(0.4, 0.6, 0.6),
				PALETTE.Nori,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 2.6, 3),
				UPRIGHT
			)
		else
			part(
				list,
				"PlateStack",
				"Cylinder",
				v(0.4, 6, 6),
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 0.4, -3),
				UPRIGHT
			)
			part(
				list,
				"PlateStack",
				"Cylinder",
				v(0.4, 6, 6),
				PALETTE.Porcelain,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 0.9, -3),
				UPRIGHT
			)
			part(
				list,
				"PlateSushi",
				"Block",
				v(2, 0.8, 1.2),
				PALETTE.Salmon,
				"SmoothPlastic",
				v(x, PLATFORM_TOP + 1.5, -3)
			)
		end
	end
end

-- 기울어지는 장식 전부: 저울 접시 테두리 + 동아줄 + 무게추.
function TugOfWarPlatformArt.deckDecor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPanRims(list)
	addRopes(list)
	addWeights(list)
	return list
end

-- 가운데 받침대: 발판 아래에서 피벗을 시각적으로 보여줘요 (충돌 없음, 기울지 않아요).
local function addPedestal(list: { DecorSpec })
	part(
		list,
		"PedestalCap",
		"Cylinder",
		v(1.2, 12, 12),
		PALETTE.Porcelain,
		"SmoothPlastic",
		v(0, PLATFORM_BOTTOM - 0.6, 0),
		UPRIGHT
	)
	part(list, "PedestalBarrel", "Cylinder", v(7, 9, 9), DARK_WOOD, "Wood", v(0, PLATFORM_BOTTOM - 4.7, 0), UPRIGHT)
	part(list, "PedestalBand", "Cylinder", v(0.8, 9.3, 9.3), GOLD, "Metal", v(0, PLATFORM_BOTTOM - 4.7, 0), UPRIGHT)
	part(list, "PedestalBase", "Cylinder", v(1.5, 11, 11), DARK_WOOD, "Wood", v(0, PLATFORM_BOTTOM - 9, 0), UPRIGHT)
end

-- 가게 마당 배경(등불·포렴): 발판 폭 축 바깥(뒤쪽)에 작은 문 틀. 고정, 기울지 않아요.
local function addYardBackdrop(list: { DecorSpec })
	local z = Layout.HALF_WIDTH + 9
	for _, side in { -1, 1 } do
		part(list, "ArchPost", "Block", v(1.6, 10, 1.6), DARK_WOOD, "Wood", v(side * 6, 4, z))
		part(
			list,
			TugOfWarPlatformArt.LANTERN,
			"Ball",
			v(2.6, 2.6, 2.6),
			PALETTE.Lacquer,
			"Neon",
			v(side * 6, 7.5, z + 1.2)
		)
	end
	part(list, "ArchBeam", "Block", v(14, 1.2, 1.6), DARK_WOOD, "Wood", v(0, 9.3, z))
	part(list, "YardWall", "Block", v(20, 8, 1.2), PLASTER, "Plaster", v(0, 3, z + 1))
	for i = -1, 1 do
		part(list, "Noren", "Block", v(4, 3.6, 0.15), PALETTE.Noren, "Fabric", v(i * 4.4, 6.6, z + 0.6))
	end
end

-- 기울지 않는 장식 전부: 받침대 + 가게 마당 배경.
function TugOfWarPlatformArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPedestal(list)
	addYardBackdrop(list)
	return list
end

-- 발판 전체 조감 → 받침대 → 저울 접시(오른쪽 끝) → 출발 자리(왼쪽) 순서.
function TugOfWarPlatformArt.introCamera(): { IntroPoint }
	local center = v(0, 2, 0)
	return {
		{ pos = v(0, 26, Layout.HALF_WIDTH + 30), lookAt = center },
		{ pos = v(0, 4, Layout.HALF_WIDTH + 6), lookAt = v(0, PLATFORM_BOTTOM - 4, 0) },
		{ pos = v(Layout.HALF_LENGTH - 2, 10, Layout.HALF_WIDTH + 4), lookAt = v(Layout.HALF_LENGTH - 9, 2, 0) },
		{ pos = v(-Layout.HALF_LENGTH + 10, 7, Layout.HALF_WIDTH + 2), lookAt = v(-Layout.HALF_LENGTH + 8, 0, 0) },
	}
end

return TugOfWarPlatformArt
