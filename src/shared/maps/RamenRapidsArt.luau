--!strict
-- "라멘 국물 급류"(m4-04) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙).
--   RamenRapidsArt.decor() -> { DecorSpec }       거대한 라멘 그릇·국물·떠다니는 파/김/달걀·젓가락 한 쌍·숟가락 출구
--   RamenRapidsArt.steamPoints() -> { Vec3 }       김(ParticleEmitter)을 붙일 자리 3곳
--   RamenRapidsArt.introCamera() -> { IntroPoint } 라운드 소개 경유점 4개
--   RamenRapidsArt.courseVolumes() -> { Bounds }   장식이 들어가면 안 되는 구간별 시야 상자 (바닥 위 2~12)
-- 장식은 MapKit.buildDecor로 만들어서 충돌·쿼리·터치가 없어요 (판정과 무관).

local Layout = require(script.Parent.RamenRapidsLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

local PALETTE = MapKitLogic.PALETTE
local BROTH: RGB = { r = 214, g = 140, b = 64 } -- 주황 갈색 국물
local SCALLION: RGB = { r = 96, g = 170, b = 72 }
local YOLK: RGB = { r = 250, g = 170, b = 40 }

local Art = {}

-- 그릇: 코스 가운데(z -150)를 중심으로 하는 큰 원
Art.BOWL_CENTER_Z = (Layout.START.front + Layout.FINISH.back) / 2
Art.BOWL_RADIUS = 178
Art.BOWL_SEGMENTS = 40
Art.BOWL_RIM_Y = 16
Art.BOWL_BOTTOM_Y = -80

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

local function bowl(list: { DecorSpec })
	local height = Art.BOWL_RIM_Y - Art.BOWL_BOTTOM_Y
	local midY = (Art.BOWL_RIM_Y + Art.BOWL_BOTTOM_Y) / 2
	local width = 2 * math.pi * Art.BOWL_RADIUS / Art.BOWL_SEGMENTS + 1
	for k = 0, Art.BOWL_SEGMENTS - 1 do
		local a = 2 * math.pi * k / Art.BOWL_SEGMENTS
		local cx, cz = math.cos(a), math.sin(a)
		-- CFrame.Angles(0, θ, 0)의 X축이 원의 접선이 되게: θ = -(a + 90°)
		local yaw = -math.deg(a) - 90
		add(list, {
			name = "BowlWall",
			shape = "Block",
			size = v(width, height, 3),
			color = PALETTE.Porcelain,
			material = "Marble",
			offset = v(cx * Art.BOWL_RADIUS, midY, Art.BOWL_CENTER_Z + cz * Art.BOWL_RADIUS),
			rotation = v(0, yaw, 0),
		})
		-- 바깥 빨간 무늬 띠 (번갈아 굵게)
		local outer = Art.BOWL_RADIUS + 1.8
		add(list, {
			name = "BowlPattern",
			shape = "Block",
			size = v(width, if k % 2 == 0 then 10 else 6, 0.6),
			color = PALETTE.Lacquer,
			material = "SmoothPlastic",
			offset = v(cx * outer, Art.BOWL_RIM_Y - 12, Art.BOWL_CENTER_Z + cz * outer),
			rotation = v(0, yaw, 0),
		})
		-- 테두리 (남색 띠)
		add(list, {
			name = "BowlRim",
			shape = "Block",
			size = v(width, 1.2, 3.4),
			color = PALETTE.PorcelainRim,
			material = "SmoothPlastic",
			offset = v(cx * Art.BOWL_RADIUS, Art.BOWL_RIM_Y + 0.6, Art.BOWL_CENTER_Z + cz * Art.BOWL_RADIUS),
			rotation = v(0, yaw, 0),
		})
	end
	-- 그릇 바닥 (탈락선보다 아래)
	add(list, {
		name = "BowlBottom",
		shape = "Cylinder",
		size = v(2, Art.BOWL_RADIUS * 2, Art.BOWL_RADIUS * 2),
		color = PALETTE.Porcelain,
		material = "Marble",
		offset = v(0, Art.BOWL_BOTTOM_Y, Art.BOWL_CENTER_Z),
		rotation = v(0, 0, 90),
	})
	-- 국물 수면 (반투명, 밟을 수 없어요 — 빠지면 아래로 떨어져 탈락)
	add(list, {
		name = "BrothSurface",
		shape = "Cylinder",
		size = v(1, (Art.BOWL_RADIUS - 1) * 2, (Art.BOWL_RADIUS - 1) * 2),
		color = BROTH,
		material = "Glass",
		offset = v(0, Layout.BROTH_Y - 0.5, Art.BOWL_CENTER_Z),
		rotation = v(0, 0, 90),
		transparency = 0.2,
	})
end

-- 국물 위에 떠 있는 토핑 (코스 밖, |x| >= 30)
local function floatingToppings(list: { DecorSpec })
	local surface = Layout.BROTH_Y
	-- 파: 작은 초록 고리 (얇은 원기둥)
	local scallions = {
		{ -34, -140 },
		{ -46, -158 },
		{ 38, -150 },
		{ 52, -172 },
		{ -40, -220 },
		{ 44, -236 },
		{ -58, -250 },
		{ 36, -268 },
		{ -36, -186 },
		{ 60, -200 },
		{ -70, -120 },
		{ 70, -130 },
	}
	for i, at in scallions do
		add(list, {
			name = "Scallion",
			shape = "Cylinder",
			size = v(0.6, 3.5, 3.5),
			color = SCALLION,
			material = "SmoothPlastic",
			offset = v(at[1], surface + 0.2, at[2]),
			rotation = v(0, i * 25, 90),
		})
	end
	-- 김: 국물에 비스듬히 꽂힌 검은 판
	local noris = { { -42, -132, 20 }, { 48, -190, -15 }, { -52, -240, 10 }, { 56, -262, -25 }, { -60, -170, 5 } }
	for _, at in noris do
		add(list, {
			name = "Nori",
			shape = "Block",
			size = v(10, 14, 0.4),
			color = PALETTE.Nori,
			material = "Fabric",
			offset = v(at[1], surface + 5, at[2]),
			rotation = v(-15, at[3], 0),
		})
	end
	-- 삶은 달걀 반쪽: 흰자 반구 + 노른자
	local eggs = { { -44, -205 }, { 46, -140 }, { 40, -284 }, { -48, -290 } }
	for _, at in eggs do
		add(list, {
			name = "EggWhite",
			shape = "Ball",
			size = v(9, 5, 11),
			color = PALETTE.Rice,
			material = "SmoothPlastic",
			offset = v(at[1], surface + 0.5, at[2]),
		})
		add(list, {
			name = "EggYolk",
			shape = "Ball",
			size = v(4.5, 2.4, 5.5),
			color = YOLK,
			material = "SmoothPlastic",
			offset = v(at[1], surface + 2.6, at[2]),
		})
	end
	-- 면발 더미: 국물 위로 드러난 노란 곡선 (코스 양옆)
	for i = 1, 8 do
		local side = if i % 2 == 0 then 1 else -1
		add(list, {
			name = "NoodleLoop",
			shape = "Cylinder",
			size = v(16, 1.2, 1.2),
			color = PALETTE.Egg,
			material = "SmoothPlastic",
			offset = v(side * (30 + i * 3), surface + 0.4, -120 - i * 18),
			rotation = v(0, i * 37, 0),
		})
	end
end

-- 그릇 위를 가로지르는 거대한 젓가락 한 쌍 (머리 위 20 이상)
local function giantChopsticks(list: { DecorSpec })
	for i, at in { { -4, 34 }, { 4, 37 } } do
		add(list, {
			name = "GiantChopstick",
			shape = "Cylinder",
			size = v(Art.BOWL_RADIUS * 2.3, 4, 4),
			color = PALETTE.Lacquer,
			material = "WoodPlanks",
			offset = v(0, at[2], Art.BOWL_CENTER_Z + at[1] * 6),
			rotation = v(0, 18 + i * 4, 0),
		})
	end
end

-- 결승 아래 숟가락 (렌게) 출구 느낌 + 출발 뒤 그릇 테두리 받침
local function spoonExit(list: { DecorSpec })
	local top = Layout.platformTop()
	local finishZ = (Layout.FINISH.front + Layout.FINISH.back) / 2
	add(list, {
		name = "SpoonBowl",
		shape = "Ball",
		size = v(34, 6, 40),
		color = PALETTE.Porcelain,
		material = "Marble",
		offset = v(0, top - Layout.FLOOR_THICKNESS - 2.5, finishZ),
	})
	add(list, {
		name = "SpoonHandle",
		shape = "Block",
		size = v(10, 2, 60),
		color = PALETTE.Porcelain,
		material = "Marble",
		offset = v(0, top - 6, Layout.FINISH.back - 34),
		rotation = v(-20, 0, 0),
	})
	add(list, {
		name = "SpoonStripe",
		shape = "Block",
		size = v(10.2, 2.2, 6),
		color = PALETTE.Lacquer,
		material = "SmoothPlastic",
		offset = v(0, top - 6, Layout.FINISH.back - 34),
		rotation = v(-20, 0, 0),
	})
	-- 출발대 받침: 그릇 가장자리에 걸친 나무 판 (바닥 아래)
	add(list, {
		name = "StartPier",
		shape = "Block",
		size = v(Layout.START_WIDTH + 4, 3, 30),
		color = PALETTE.Wood,
		material = "WoodPlanks",
		offset = v(0, -Layout.FLOOR_THICKNESS - 1.5, 10),
	})
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	bowl(list)
	floatingToppings(list)
	giantChopsticks(list)
	spoonExit(list)
	return list
end

-- 김 3곳: 국물 수면 바로 위, 코스 옆
function Art.steamPoints(): { Vec3 }
	local y = Layout.BROTH_Y + 1
	return { v(-34, y, -165), v(34, y, -230), v(-30, y, -280) }
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- 출발 위 → 차슈 건너기 → 회전 막대 → 끝점은 출발선 뒤 높이 12 (m4-02 공통 규칙)
function Art.introCamera(): { IntroPoint }
	local top = Layout.platformTop()
	return {
		{ pos = v(0, 40, 40), lookAt = v(0, -10, -90) },
		{ pos = v(32, top + 18, -150), lookAt = v(0, top, -170) },
		{ pos = v(-36, top + 22, -230), lookAt = v(0, top, -245) },
		{ pos = v(0, 12, 14), lookAt = v(0, 4, -20) },
	}
end

-- 구간별 시야 상자: 바닥(또는 발판) 위 2~12, 코스 폭 안쪽
function Art.courseVolumes(): { MapKitLogic.Bounds }
	local function box(halfX: number, minY: number, maxY: number, front: number, back: number): MapKitLogic.Bounds
		return { min = v(-halfX, minY, back), max = v(halfX, maxY, front) }
	end
	local rapidsLow = -Layout.rapidsDrop()
	local top = Layout.platformTop()
	local chashuHigh = Layout.BROTH_Y + Layout.CHASHU_LOW + Layout.CHASHU_RANGE
	local reachX = 0
	for _, chashu in Layout.CHASHUS do
		reachX = math.max(reachX, math.abs(chashu.x) + Layout.CHASHU_DIAMETER / 2)
	end
	return {
		box(Layout.START_WIDTH / 2, 2, 12, Layout.START.front, Layout.START.back),
		box(Layout.RAPIDS_WIDTH / 2, rapidsLow + 2, 12, Layout.RAPIDS.front, Layout.RAPIDS.back),
		box(reachX, Layout.BROTH_Y + 2, chashuHigh + 12, Layout.TOPPINGS.front, Layout.TOPPINGS.back),
		box(Layout.PLATFORM_DIAMETER / 2, top + 2, top + 12, Layout.SWEEPERS.front, Layout.SWEEPERS.back),
		box(Layout.FINISH_WIDTH / 2, top + 2, top + 12, Layout.FINISH.front, Layout.FINISH.back),
	}
end

return Art
