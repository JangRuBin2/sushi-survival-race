--!strict
-- "디저트 냉장고"(dessert-fridge, m5-06) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙).
--   Art.decor() -> { DecorSpec }        장식 (충돌·쿼리·터치 없음)
--   Art.introCamera() -> { IntroPoint } 라운드 소개 경유점 4개
-- PHASE A(게임플레이) 단계라 장식은 자리 표시용 최소한만 있어요: 결승 냉장고 문틀과 문짝.
-- 냉장고 벽·유리 선반·디저트 장식·조명은 아트 단계(m5-23 비주얼 키트 이후)에서 채워요.

local Layout = require(script.Parent.DessertFridgeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local FRIDGE_WHITE = { r = 236, g = 242, b = 248 }
local DOOR_GRAY = { r = 200, g = 210, b = 220 }

local Art = {}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local y = Layout.HIGH_Y
	local z = Layout.FINISH_LINE_Z - 2
	local half = Layout.FINISH_WIDTH / 2
	-- 냉장고 문틀 (결승선 뒤, 코스 폭 바깥 기둥 + 위 들보)
	for _, side in { -1, 1 } do
		add(list, {
			name = "DoorFramePost",
			shape = "Block",
			size = v(2, 18, 2),
			color = FRIDGE_WHITE,
			material = "SmoothPlastic",
			offset = v(side * (half + 1), y + 9, z),
		})
	end
	add(list, {
		name = "DoorFrameTop",
		shape = "Block",
		size = v(Layout.FINISH_WIDTH + 4, 2, 2),
		color = FRIDGE_WHITE,
		material = "SmoothPlastic",
		offset = v(0, y + 19, z),
	})
	-- 활짝 열린 문짝 (오른쪽 바깥으로 90도)
	add(list, {
		name = "FridgeDoor",
		shape = "Block",
		size = v(1.5, 18, Layout.FINISH_WIDTH),
		color = DOOR_GRAY,
		material = "SmoothPlastic",
		offset = v(half + 2.75, y + 9, z + Layout.FINISH_WIDTH / 2),
	})
	return list
end

function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 26, 18), lookAt = v(0, 0, -40) },
		{ pos = v(-22, 22, -90), lookAt = v(0, 4, -122) },
		{ pos = v(20, 26, -160), lookAt = v(0, 12, -190) },
		{ pos = v(0, 20, -228), lookAt = v(0, 14, -252) },
	}
end

return Art
