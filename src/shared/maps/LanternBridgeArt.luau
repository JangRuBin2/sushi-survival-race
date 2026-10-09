--!strict
-- "등불 다리 건너기"(lantern-bridge, m5-15) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙).
--   Art.decor() -> { DecorSpec }        축제 입구 도리이, 다리 난간 밧줄 + 종이 등불, 쉼터 담장·석등, 결승 작은 문
--   Art.introCamera() -> { IntroPoint } 라운드 소개 경유점 4개
--   Art.LANTERN                         PointLight를 붙일 장식 파츠 이름 (다리당 3개 = 12개, 조명 예산 안)
-- 장식은 MapKit.buildDecor로 만들어서 충돌·쿼리·터치가 없어요 (판정과 무관).

local Layout = require(script.Parent.LanternBridgeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

local PALETTE = MapKitLogic.PALETTE

local Art = {}

-- 조명이 붙는 등불 이름 (다리마다 왼쪽 3개 = 4 다리 x 3 = 12, LIGHT_BUDGET과 같아요)
Art.LANTERN = "Lantern"

local LANTERN_COLORS: { RGB } = {
	{ r = 206, g = 48, b = 44 }, -- 빨강
	{ r = 230, g = 140, b = 40 }, -- 주황
	{ r = 248, g = 246, b = 238 }, -- 흰색
}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

-- 축제 입구 도리이 (출발 뒤쪽, 로컬 +Z)
local function addTorii(list: { DecorSpec })
	local z = Layout.START.front - 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "ToriiPillar",
			shape = "Cylinder",
			size = v(1.4, 16, 1.4),
			color = PALETTE.Lacquer,
			material = "Wood",
			offset = v(side * 7, 8, z),
			rotation = v(0, 0, 90),
		})
	end
	add(list, {
		name = "ToriiBeamTop",
		shape = "Block",
		size = v(18, 1.4, 2.4),
		color = PALETTE.Lacquer,
		material = "Wood",
		offset = v(0, 15.5, z),
	})
	add(list, {
		name = "ToriiBeamMid",
		shape = "Block",
		size = v(15, 1, 1.6),
		color = PALETTE.Nori,
		material = "Wood",
		offset = v(0, 12, z),
	})
end

-- 다리 하나의 난간 밧줄 + 종이 등불(좌우, 사분위 3곳). 왼쪽만 조명(LANTERN), 오른쪽은 장식만(LanternPlain)
-- — 다리 4개 x 왼쪽 3개 = 12개로 MapKitLogic.LIGHT_BUDGET(12)을 꽉 채워요.
local function addBridgeDecor(list: { DecorSpec }, bridge: Layout.Bridge, order: number)
	local center = (bridge.front + bridge.back) / 2
	local length = bridge.front - bridge.back
	for _, side in { -1, 1 } do
		local x = side * bridge.halfWidth
		add(list, {
			name = "RailRope",
			shape = "Cylinder",
			size = v(length, 0.3, 0.3),
			color = PALETTE.Wood,
			material = "Fabric",
			offset = v(x, 1.6, center),
			rotation = v(0, 0, 90),
		})
		for k = 1, 3 do
			local z = bridge.front - length * (k / 4)
			local colorIndex = ((order + k - 1) % #LANTERN_COLORS) + 1
			local isLit = side < 0
			add(list, {
				name = if isLit then Art.LANTERN else "LanternPlain",
				shape = "Ball",
				size = v(2.2, 2.6, 2.2),
				color = LANTERN_COLORS[colorIndex],
				material = "Neon",
				offset = v(x, 0.9, z),
			})
			add(list, {
				name = "LanternCap",
				shape = "Cylinder",
				size = v(0.3, 1.4, 1.4),
				color = PALETTE.Nori,
				material = "SmoothPlastic",
				offset = v(x, 2.0, z),
				rotation = v(0, 0, 90),
			})
			add(list, {
				name = "LanternCord",
				shape = "Block",
				size = v(0.15, 0.6, 0.15),
				color = PALETTE.Nori,
				material = "SmoothPlastic",
				offset = v(x, 2.5, z),
			})
		end
	end
end

-- 쉼터 담장(나무 울타리) + 석등(토로) 하나
local function addRestDecor(list: { DecorSpec }, rest: Layout.RestZone)
	local center = (rest.front + rest.back) / 2
	local depth = rest.front - rest.back
	local halfWidth = rest.width / 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "RestFence",
			shape = "Block",
			size = v(0.6, 2.2, depth - 1),
			color = PALETTE.Wood,
			material = "WoodPlanks",
			offset = v(side * halfWidth, 1.1, center),
		})
	end
	local lampX, lampZ = halfWidth - 1.8, rest.front - 2.5
	add(list, {
		name = "StoneLanternBase",
		shape = "Cylinder",
		size = v(2.4, 2.2, 2.2),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 1.2, lampZ),
		rotation = v(0, 0, 90),
	})
	add(list, {
		name = "StoneLanternBox",
		shape = "Block",
		size = v(1.8, 1.8, 1.8),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 2.8, lampZ),
	})
	add(list, {
		name = "StoneLanternCap",
		shape = "Block",
		size = v(2.4, 0.8, 2.4),
		color = PALETTE.Iron,
		material = "Slate",
		offset = v(lampX, 3.9, lampZ),
	})
end

-- 결승 뒤 작은 문(도리이보다 낮고 소박해요)
local function addFinishGate(list: { DecorSpec })
	local z = Layout.FINISH.back + 2
	for _, side in { -1, 1 } do
		add(list, {
			name = "FinishPost",
			shape = "Block",
			size = v(1.4, 10, 1.4),
			color = PALETTE.Lacquer,
			material = "Wood",
			offset = v(side * 7, 5, z),
		})
	end
	add(list, {
		name = "FinishBeam",
		shape = "Block",
		size = v(16, 1.2, 1.6),
		color = PALETTE.Lacquer,
		material = "Wood",
		offset = v(0, 9.6, z),
	})
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addTorii(list)
	for order, bridge in Layout.BRIDGES do
		addBridgeDecor(list, bridge, order)
	end
	for _, rest in Layout.RESTS do
		addRestDecor(list, rest)
	end
	addFinishGate(list)
	return list
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- 출발 도리이 위 → 다리 1·2 → 가장 긴 다리 4(피날레) → 결승 (m4-02 공통 규칙)
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 30, 20), lookAt = v(0, 2, -30) },
		{ pos = v(14, 14, -50), lookAt = v(0, 2, -70) },
		{ pos = v(-16, 16, -115), lookAt = v(0, 2, -130) },
		{ pos = v(0, 10, -142), lookAt = v(0, 2, -152) },
	}
end

return Art
