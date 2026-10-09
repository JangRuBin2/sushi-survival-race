--!strict
-- "와르르 나무 블록"(giant-jenga, m5-16) 아트의 순수 데이터. Roblox 자료형을 쓰지 않아요 (lune 테스트).
-- 판정 지오메트리(칸 윗면·블록 3단)는 GiantJenga.build가 직접 만들고(기울기·제거로 움직이니까), 여기는
-- 고정 배경 장식(공사장 느낌, 손님 얼굴)과 색·소개 카메라·시야 상자만 있어요.
--   Art.blockColor(i, j, levelIndex)  바깥 기둥 블록 하나의 나무색 (레벨마다, 칸마다 조금씩 달라요)
--   Art.PEDESTAL_COLOR                가운데 3×3 받침대 색 (더 짙음)
--   Art.decor()                      고정 장식 (공사장 배경, 손님 얼굴, 조명) — MapKit.buildDecor(…, Decor 폴더)
--   Art.introCamera()                IntroCamera 경유점 3개 (탑 전체 → 바깥 테두리 클로즈업 → 가운데 안전지대)
--   Art.courseVolume()                장식이 들어가면 안 되는 시야 상자 (탑 꼭대기 위 2~12, 격자 안쪽)

local Layout = require(script.Parent.GiantJengaLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type RGB = MapKitLogic.RGB
type Vec3 = MapKitLogic.Vec3

local PALETTE = MapKitLogic.PALETTE

local Art = {}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function add(specs: { DecorSpec }, spec: DecorSpec)
	table.insert(specs, spec)
end

Art.PEDESTAL_COLOR = rgb(108, 74, 44) :: RGB -- 가운데 3×3, 더 두껍고 짙은 나무

-- 바깥 기둥 블록 하나의 색. 칸마다(i, j) 살짝 다른 결, 레벨이 낮을수록(더 안쪽 블록일수록) 살짝 어두워요.
function Art.blockColor(i: number, j: number, levelIndex: number): RGB
	local base = PALETTE.Wood
	local variant = (i * 7 + j * 13) % 3 -- 0~2, 음수여도 Luau %는 0~2
	local shift = (variant - 1) * 8
	local darken = (Layout.LEVEL_MAX - levelIndex) * 10 -- 아래쪽(레벨1) 블록이 조금 더 어두워요
	local function clamp(n: number): number
		return math.clamp(n, 0, 255)
	end
	return rgb(clamp(base.r + shift - darken), clamp(base.g + shift - darken), clamp(base.b + shift - darken))
end

-- 위를 보고 입 벌린 거대 손님 얼굴 (탑 아래 30~60, Survival 낙하 "손님 입" 연출과 같은 표현)
local function customerFace(specs: { DecorSpec }, cx: number, cy: number, cz: number, skin: RGB)
	local radius = 10
	add(specs, {
		name = "CustomerHead",
		shape = "Ball",
		size = v(radius * 2, radius * 2, radius * 2),
		color = skin,
		material = "SmoothPlastic",
		offset = v(cx, cy, cz),
	})
	local top = cy + radius
	add(specs, {
		name = "CustomerMouth",
		shape = "Cylinder",
		size = v(2.4, 8, 8),
		color = rgb(60, 18, 24),
		material = "SmoothPlastic",
		offset = v(cx, top - 0.5, cz),
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "CustomerTongue",
		shape = "Ball",
		size = v(3.6, 1.3, 3.2),
		color = rgb(220, 90, 100),
		material = "SmoothPlastic",
		offset = v(cx, top + 1.2, cz + 1),
	})
	for _, side in { -1, 1 } do
		add(specs, {
			name = "CustomerEye",
			shape = "Ball",
			size = v(3, 3, 3),
			color = PALETTE.Rice,
			material = "SmoothPlastic",
			offset = v(cx + side * 4, cy + 4, cz - 7),
		})
		add(specs, {
			name = "CustomerPupil",
			shape = "Ball",
			size = v(1.4, 1.4, 1.4),
			color = PALETTE.Nori,
			material = "SmoothPlastic",
			offset = v(cx + side * 4, cy + 4.6, cz - 8.3),
		})
	end
end

-- 목공소/공사장 배경: 톱밥 더미, 나무 상자, 줄자, 머리 위 작업등
local function workshop(specs: { DecorSpec })
	local far = 95
	-- 바닥 (멀리 보이는 작업장 바닥)
	add(specs, {
		name = "WorkshopFloor",
		shape = "Block",
		size = v(300, 4, 300),
		color = rgb(150, 128, 92),
		material = "WoodPlanks",
		offset = v(0, -70, 0),
	})
	-- 나무 상자 더미 (네 모서리 바깥)
	for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local cx, cz = corner[1] * far, corner[2] * far
		add(specs, {
			name = "Crate",
			shape = "Block",
			size = v(14, 14, 14),
			color = PALETTE.Wood,
			material = "Wood",
			offset = v(cx, -55, cz),
			rotation = v(0, corner[1] * 12, 0),
		})
		add(specs, {
			name = "Crate",
			shape = "Block",
			size = v(11, 11, 11),
			color = rgb(166, 124, 80),
			material = "Wood",
			offset = v(cx + 9, -56.5, cz - 6),
			rotation = v(0, -corner[2] * 18, 0),
		})
	end
	-- 톱밥 더미 (연한 나무색 원뿔 느낌 — Cylinder로 뭉툭하게)
	for _, at in { { far * 0.4, -far * 0.9 }, { -far * 0.9, far * 0.3 }, { far * 0.7, far * 0.6 } } do
		add(specs, {
			name = "Sawdust",
			shape = "Cylinder",
			size = v(5, 13, 13),
			color = rgb(214, 186, 140),
			material = "Sand",
			offset = v(at[1], -66, at[2]),
			rotation = v(0, 0, 90),
		})
	end
	-- 줄자 (노란 띠 + 검은 눈금)
	add(specs, {
		name = "TapeMeasureBody",
		shape = "Cylinder",
		size = v(6, 10, 10),
		color = rgb(236, 196, 48),
		material = "SmoothPlastic",
		offset = v(far * 0.6, -58, -far * 0.6),
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "TapeMeasureTab",
		shape = "Block",
		size = v(60, 1, 3),
		color = rgb(40, 40, 42),
		material = "Metal",
		offset = v(far * 0.6 - 30, -62, -far * 0.6 + 5.5),
		rotation = v(0, -20, 0),
	})
	-- 머리 위 작업등 3개
	for k = -1, 1 do
		local x = k * 24
		add(specs, {
			name = "LampCord",
			shape = "Block",
			size = v(0.4, 34, 0.4),
			color = PALETTE.Nori,
			material = "SmoothPlastic",
			offset = v(x, 54, 0),
		})
		add(specs, {
			name = "LampShade",
			shape = "Cylinder",
			size = v(4, 9, 9),
			color = rgb(60, 60, 64),
			material = "Metal",
			offset = v(x, 36, 0),
			rotation = v(0, 0, 90),
		})
		add(specs, {
			name = Art.LAMP_BULB,
			shape = "Ball",
			size = v(3.2, 3.2, 3.2),
			color = rgb(255, 235, 180),
			material = "Neon",
			offset = v(x, 33.5, 0),
		})
	end
end

Art.LAMP_BULB = "LampBulb"

function Art.decor(): { DecorSpec }
	local specs: { DecorSpec } = {}
	local skins = {
		rgb(240, 200, 170),
		rgb(214, 168, 130),
		rgb(250, 214, 186),
	}
	-- 탈락 높이(30) 아래, 머리 꼭대기도 거기 아래 (손님 입 연출과 겹치지 않게 충분히 아래)
	customerFace(specs, 22, -46, 22, skins[1])
	customerFace(specs, -24, -48, -20, skins[2])
	customerFace(specs, -20, -44, 24, skins[3])
	workshop(specs)
	return specs
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- 탑 전체 조망(위) → 바깥 테두리 한 칸 클로즈업(옆) → 가운데 안전지대(낮게, 가운데를 봐요)
function Art.introCamera(): { IntroPoint }
	local edge = (Layout.GRID_HALF + 0.5) * Layout.CELL_SIZE
	return {
		{ pos = v(0, 55, 0), lookAt = v(0, -4, 0) },
		{ pos = v(edge + 14, 6, edge * 0.6), lookAt = v(edge * 0.75, -2, edge * 0.45) },
		{ pos = v(10, 10, 14), lookAt = v(0, 0, 0) },
	}
end

-- 탑 꼭대기(y 0) 위 2~12, 격자 반경 안쪽 (칸 바깥 가장자리까지)
function Art.courseVolume(): MapKitLogic.Bounds
	local half = (Layout.GRID_HALF + 0.5) * Layout.CELL_SIZE
	return { min = v(-half, 2, -half), max = v(half, 12, half) }
end

return Art
