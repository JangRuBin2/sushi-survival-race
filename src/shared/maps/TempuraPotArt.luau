--!strict
-- "튀김 냄비 탈출" 아트 데이터 (m5-05). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- PHASE A(게임플레이): 장식은 자리만 잡은 최소 버전(거대한 긴 젓가락 한 쌍)이에요. 냄비 테두리·손잡이,
-- 튀김옷 돌기, 기름 거품·김, 주방 배경은 새 비주얼 키트(m5-23)로 PHASE B에서 채워요.
-- 판정 지오메트리(냄비 벽·바구니·발판·기름)는 TempuraPotLayout 그대로이고, 여기는 충돌 없는 장식만 있어요.
--   TempuraPotArt.decor() -> { DecorSpec }
--   TempuraPotArt.introCamera() -> { IntroPoint }   냄비 전체 → 둘레 → 꼭대기 발판 → 출발 바구니
--   TempuraPotArt.COLORS                            판정 파츠 기본 색 (TempuraPot.build가 써요)

local Layout = require(script.Parent.TempuraPotLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local Art = {}

-- 판정 파츠 기본 색 (읽기 쉬운 색: 검은 무쇠 냄비, 금색 기름, 노릇한 튀김옷, 철망 바구니)
Art.COLORS = {
	pot = { r = 40, g = 40, b = 44 } :: RGB,
	oil = { r = 240, g = 186, b = 60 } :: RGB,
	basket = { r = 186, g = 170, b = 140 } :: RGB,
	shrimp = { r = 236, g = 170, b = 84 } :: RGB,
	sweetPotato = { r = 226, g = 150, b = 70 } :: RGB,
	shiso = { r = 214, g = 182, b = 96 } :: RGB,
	warn = { r = 255, g = 120, b = 30 } :: RGB,
	splash = { r = 255, g = 210, b = 90 } :: RGB,
}

local CHOPSTICK: RGB = { r = 150, g = 104, b = 64 }

local CX = Layout.POT_CENTER_X
local CZ = Layout.POT_CENTER_Z
local R = Layout.POT_INNER_RADIUS

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	-- 냄비 위로 비스듬히 걸친 거대한 긴 젓가락 한 쌍 (냄비 바깥 뒤쪽, 높이 50 이상, 충돌 없음)
	for i, dx in { -4, 4 } do
		local spec: DecorSpec = {
			name = `GiantChopstick{i}`,
			shape = "Cylinder",
			size = v(70, 2, 2),
			color = CHOPSTICK,
			material = "Wood",
			offset = v(CX + R + 24 + dx, Layout.POT_WALL_TOP_Y + 18, CZ - 10 + dx),
			rotation = v(0, 20, 60),
		}
		table.insert(list, spec)
	end
	return list
end

-- 냄비 전체(위에서) → 둘레를 돌며 나선 → 꼭대기 발판 → 출발 바구니
function Art.introCamera(): { IntroPoint }
	local topX, topZ = Layout.polar(Layout.TOP_ANGLE, Layout.TOP_RING_RADIUS)
	return {
		{ pos = v(CX, Layout.POT_WALL_TOP_Y + 45, CZ + R + 30), lookAt = v(CX, 10, CZ) },
		{ pos = v(CX + R + 12, Layout.POT_WALL_TOP_Y + 12, CZ), lookAt = v(CX, 15, CZ) },
		{ pos = v(topX + 10, 38, topZ + 10), lookAt = v(topX, 31, topZ) },
		{ pos = v(CX, Layout.BASKET_TOP_Y + 12, CZ + 26), lookAt = v(CX, Layout.BASKET_TOP_Y, CZ) },
	}
end

return Art
