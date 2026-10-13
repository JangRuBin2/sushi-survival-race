--!strict
-- "연어알 폭탄 접시" 아트 데이터 (m5-04). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- PHASE A: 판정 지오메트리만 먼저 만들고 장식은 자리 잡기용 최소 목록이에요 (도자기 접시 몸통·굽·남색 테두리).
-- 본격 아트(가게 앞 부두·바다, 셰프 손, 고추냉이·생강, 등롱 조명, 칸 경계선)는 m5-23 비주얼 키트가 들어온 뒤 PHASE B.
-- 좌표는 전부 map origin(접시 중심, 칸 윗면 높이) 기준 로컬이에요.
--   IkuraBombsArt.decor() -> { DecorSpec }         접시 몸통·굽·테두리 (전부 충돌 없음)
--   IkuraBombsArt.introCamera() -> { IntroPoint }  접시 전체 → 숟가락 → 출발 자리
--   IkuraBombsArt.courseVolume() -> Bounds          장식이 가리면 안 되는 상자 (칸 윗면 위 2~12, 접시 안)
--   IkuraBombsArt.COLORS                            판정 파츠 기본 색 (IkuraBombs가 씀)

local Layout = require(script.Parent.IkuraBombsLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local IkuraBombsArt = {}

IkuraBombsArt.RIM_SEGMENTS = 30 -- 테두리 조각 수
IkuraBombsArt.RIM_INNER = Layout.RADIUS + 0.2 -- 칸 바깥에서 살짝 떨어져서 (충돌은 어차피 없음)
IkuraBombsArt.RIM_WIDTH = 1.6
IkuraBombsArt.RIM_TOP = 1 -- 테두리 윗면 높이 (시야 상자 y 2보다 낮게)
IkuraBombsArt.SIGHT_MIN = 2
IkuraBombsArt.SIGHT_MAX = 12

-- 판정 파츠 기본 색 (진한 간장 — 칸마다 두 톤 번갈아, 고리마다 살짝 다르게)
IkuraBombsArt.COLORS = {
	soyA = { r = 74, g = 38, b = 22 },
	soyB = { r = 92, g = 50, b = 28 },
	center = { r = 64, g = 32, b = 18 },
	crackLine = { r = 20, g = 12, b = 8 },
	warn = { r = 230, g = 40, b = 40 }, -- 꼬치 쇼다운 연장전 경고와 같은 빨강
	bombCircle = { r = 235, g = 50, b = 45 },
	roe = { r = 255, g = 110, b = 40 },
	spoon = { r = 205, g = 210, b = 218 },
	hand = { r = 250, g = 214, b = 180 },
} :: { [string]: RGB }

local PORCELAIN = MapKitLogic.PALETTE.Porcelain
local RIM = MapKitLogic.PALETTE.PorcelainRim

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로

function IkuraBombsArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	local r = Layout.RADIUS
	-- 접시 몸통 (칸 바로 아래, 칸보다 조금 넓게)
	table.insert(list, {
		name = "PlateBody",
		shape = "Cylinder" :: Shape,
		size = v(2, (r + 2) * 2, (r + 2) * 2),
		color = PORCELAIN,
		material = "Marble",
		offset = v(0, -Layout.THICKNESS - 1, 0),
		rotation = UPRIGHT,
	})
	-- 굽
	table.insert(list, {
		name = "PlateFoot",
		shape = "Cylinder" :: Shape,
		size = v(2, r * 1.2, r * 1.2),
		color = PORCELAIN,
		material = "Marble",
		offset = v(0, -Layout.THICKNESS - 3, 0),
		rotation = UPRIGHT,
	})
	-- 남색 테두리 (조각을 둘러 세운 고리)
	local n = IkuraBombsArt.RIM_SEGMENTS
	local mid = IkuraBombsArt.RIM_INNER + IkuraBombsArt.RIM_WIDTH / 2
	local outer = IkuraBombsArt.RIM_INNER + IkuraBombsArt.RIM_WIDTH
	local chord = 2 * outer * math.sin(math.pi / n) + 0.1
	local bottom = -Layout.THICKNESS - 1
	local height = IkuraBombsArt.RIM_TOP - bottom
	for i = 0, n - 1 do
		local deg = (i + 0.5) * 360 / n
		local a = math.rad(deg)
		table.insert(list, {
			name = "Rim",
			shape = "Block" :: Shape,
			size = v(IkuraBombsArt.RIM_WIDTH, height, chord),
			color = if i % 2 == 0 then RIM else PORCELAIN,
			material = "Marble",
			offset = v(mid * math.cos(a), bottom + height / 2, -mid * math.sin(a)),
			rotation = v(0, deg, 0),
		})
	end
	return list
end

-- 소개 카메라: 접시 전체(높은 사선) → 숟가락 높이 → 출발 자리(낮게)
function IkuraBombsArt.introCamera(): { IntroPoint }
	local center = v(0, 0, 0)
	local h = Layout.SPOON_HEIGHT
	return {
		{ pos = v(0, 46, 52), lookAt = center },
		{ pos = v(30, h + 4, 20), lookAt = v(0, h, 0) },
		{ pos = v(-36, 14, 24), lookAt = center },
		{ pos = v(-14, 6, 26), lookAt = v(0, 2, 13) },
	}
end

function IkuraBombsArt.courseVolume(): Bounds
	local r = Layout.RADIUS
	return {
		min = v(-r, IkuraBombsArt.SIGHT_MIN, -r),
		max = v(r, IkuraBombsArt.SIGHT_MAX, r),
	}
end

return IkuraBombsArt
