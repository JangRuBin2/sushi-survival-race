--!strict
-- "셰프의 도마"(chef-board, m4-05) 아트의 순수 데이터. Roblox 자료형을 쓰지 않아요 (lune 테스트).
-- 좌표는 도마 중심(origin) 기준 로컬, 도마 윗면 = y 0. 공통 규칙은 docs/specs/m4-02 "공통 규칙".
--   Art.decor()                 고정 장식 (손님 얼굴, 주방 배경, 조명) — MapKit.buildDecor(…, Decor 폴더)
--   Art.cellDecor(cell, board)  칸 하나에 붙는 칼자국 장식 (칸 파츠 자식으로 만들어 같이 기울고 떨어져요)
--   Art.cellColor(i, j)         칸 나무색 (가장자리 칸은 조금씩 달라요)
--   Art.introCamera()           IntroCamera 경유점 3개
--   Art.courseVolume()          장식이 들어가면 안 되는 시야 상자 (도마 윗면 위 2~12, 도마 반지름 안)
--   Art.KNIFE                   칼·팔 색 (ChefBoard.build가 써요)

local Logic = require(script.Parent.ChefBoardLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type RGB = MapKitLogic.RGB
type Vec3 = MapKitLogic.Vec3

local PALETTE = MapKitLogic.PALETTE

local Art = {}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 타입을 정한 인자로 넣어야 shape 같은 문자열이 리터럴 타입으로 잡혀요 (타입 검사)
local function add(specs: { DecorSpec }, spec: DecorSpec)
	table.insert(specs, spec)
end

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

Art.KNIFE = {
	blade = rgb(205, 210, 216),
	edge = rgb(240, 242, 246),
	handle = rgb(28, 28, 30),
	rivet = rgb(180, 180, 186),
	sleeve = PALETTE.Rice,
	skin = rgb(240, 200, 170),
	warn = rgb(230, 40, 40),
}

local GROOVE = rgb(122, 86, 52) -- 칼자국 (진한 나무)
local GROOVE_WIDTH = 0.35
local GROOVE_HEIGHT = 0.06

-- 칸 나무색: 밝은 나무, 가장자리 칸은 조각마다 조금 다른 결
function Art.cellColor(i: number, j: number): RGB
	local base = PALETTE.Wood
	local ring = math.max(math.abs(i), math.abs(j))
	local variant = (i * 7 + j * 13) % 3 -- 음수여도 Luau %는 0~2
	local shift = if ring >= 3 then (variant - 1) * 10 else 0
	local lighten = 28 - ring * 3
	local function clamp(n: number): number
		return math.clamp(n, 0, 255)
	end
	return rgb(clamp(base.r + lighten + shift), clamp(base.g + lighten + shift), clamp(base.b + lighten + shift // 2))
end

-- 칸 하나의 칼자국: 오른쪽(+X)·앞쪽(+Z)에 이웃 칸이 있으면 경계 홈, 몇몇 칸엔 비스듬한 긁힘 하나.
-- 오프셋은 도마 중심 기준 (칸 중심 + 칸 안 위치). 칸 윗면 바로 위 0.06 두께라 밟는 높이는 그대로예요.
function Art.cellDecor(cell: Logic.Cell, hasNeighbor: (i: number, j: number) -> boolean): { DecorSpec }
	local specs: { DecorSpec } = {}
	local size = Logic.CELL_SIZE
	local y = GROOVE_HEIGHT / 2
	if hasNeighbor(cell.i + 1, cell.j) then
		add(specs, {
			name = "Groove",
			shape = "Block",
			size = v(GROOVE_WIDTH, GROOVE_HEIGHT, size),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x + size / 2, y, cell.z),
		})
	end
	if hasNeighbor(cell.i, cell.j + 1) then
		add(specs, {
			name = "Groove",
			shape = "Block",
			size = v(size, GROOVE_HEIGHT, GROOVE_WIDTH),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x, y, cell.z + size / 2),
		})
	end
	if (cell.i * 3 + cell.j * 5) % 4 == 0 then
		add(specs, {
			name = "Scratch",
			shape = "Block",
			size = v(4.5, GROOVE_HEIGHT, 0.2),
			color = GROOVE,
			material = "Wood",
			offset = v(cell.x + 0.5, y, cell.z - 1),
			rotation = v(0, 25 + ((cell.i + cell.j) % 3) * 20, 0),
		})
	end
	return specs
end

-- 구 위의 한 점 (중심 c, 반지름 r, 방향 d — 정규화해요)
local function onSphere(c: Vec3, r: number, dx: number, dy: number, dz: number): Vec3
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	return v(c.x + dx / len * r, c.y + dy / len * r, c.z + dz / len * r)
end

-- 도마 아래에서 위를 보고 입을 벌린 손님 얼굴 (탈락 연출 "손님 입"과 같은 표현).
-- 머리 꼭대기가 탈락 높이(-30)보다 아래라 떨어지는 사람과 겹쳐도 판정과 무관해요 (장식은 충돌 없음).
local function customerFace(specs: { DecorSpec }, cx: number, cy: number, cz: number, skin: RGB)
	local radius = 11
	local c = v(cx, cy, cz)
	add(specs, {
		name = "CustomerHead",
		shape = "Ball",
		size = v(radius * 2, radius * 2, radius * 2),
		color = skin,
		material = "SmoothPlastic",
		offset = c,
	})
	local len = math.sqrt(cx * cx + cz * cz)
	local tx, tz = -cx / len, -cz / len -- 도마 중심 쪽 (수평 단위). 얼굴은 위를 보고 턱(입)이 이쪽
	local sx, sz = -tz, tx -- 얼굴 옆 방향
	for _, side in { -1, 1 } do
		local ex, ez = -tx * 0.45 + sx * side * 0.4, -tz * 0.45 + sz * side * 0.4
		add(specs, {
			name = "CustomerEye",
			shape = "Ball",
			size = v(3.4, 3.4, 3.4),
			color = PALETTE.Rice,
			material = "SmoothPlastic",
			offset = onSphere(c, radius - 0.8, ex, 1, ez),
		})
		add(specs, {
			name = "CustomerPupil",
			shape = "Ball",
			size = v(1.6, 1.6, 1.6),
			color = PALETTE.Nori,
			material = "SmoothPlastic",
			offset = onSphere(c, radius + 0.6, ex, 1, ez),
		})
		add(specs, {
			name = "CustomerCheek",
			shape = "Ball",
			size = v(3, 1.2, 3),
			color = rgb(240, 140, 140),
			material = "SmoothPlastic",
			offset = onSphere(c, radius - 0.3, tx * 0.3 + sx * side * 0.75, 1, tz * 0.3 + sz * side * 0.75),
		})
	end
	-- 벌린 입 (어두운 원판, 위를 봄) + 혀
	local mouth = onSphere(c, radius - 0.4, tx * 0.5, 1, tz * 0.5)
	add(specs, {
		name = "CustomerMouth",
		shape = "Cylinder",
		size = v(1, 8, 8),
		color = rgb(60, 18, 24),
		material = "SmoothPlastic",
		offset = mouth,
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "CustomerTongue",
		shape = "Ball",
		size = v(4, 1.4, 3.4),
		color = rgb(220, 90, 100),
		material = "SmoothPlastic",
		offset = v(mouth.x + tx * 1.5, mouth.y + 0.4, mouth.z + tz * 1.5),
	})
end

local function kitchen(specs: { DecorSpec })
	-- 아래 조리대 바닥 (멀리 보이는 주방 바닥)
	add(specs, {
		name = "Counter",
		shape = "Block",
		size = v(320, 4, 320),
		color = rgb(70, 72, 76),
		material = "Granite",
		offset = v(0, -72, 0),
	})
	-- 뒤쪽 타일 벽 (+Z)
	add(specs, {
		name = "Backsplash",
		shape = "Block",
		size = v(240, 130, 2),
		color = PALETTE.Porcelain,
		material = "CeramicTiles",
		offset = v(0, -5, 110),
	})
	-- 벽 아래 옻칠 띠
	add(specs, {
		name = "BacksplashTrim",
		shape = "Block",
		size = v(240, 4, 2.4),
		color = PALETTE.Lacquer,
		material = "Wood",
		offset = v(0, 20, 109),
	})

	-- 칼꽂이 (나무 블록 + 꽂힌 칼 손잡이 4개)
	add(specs, {
		name = "KnifeBlock",
		shape = "Block",
		size = v(16, 26, 12),
		color = PALETTE.Wood,
		material = "Wood",
		offset = v(-70, -15, 80),
		rotation = v(-15, 0, 0),
	})
	for k = 1, 4 do
		add(specs, {
			name = "KnifeBlockHandle",
			shape = "Block",
			size = v(2.4, 10, 2.4),
			color = Art.KNIFE.handle,
			material = "SmoothPlastic",
			offset = v(-76 + k * 3.6 - 1.8, 2, 80 + 2),
			rotation = v(-15, 0, 0),
		})
	end

	-- 생선 한 마리 (큰 접시 위 연어)
	add(specs, {
		name = "FishPlate",
		shape = "Cylinder",
		size = v(2, 44, 44),
		color = PALETTE.Porcelain,
		material = "SmoothPlastic",
		offset = v(72, -30, 70),
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "FishPlateRim",
		shape = "Cylinder",
		size = v(1.6, 46, 46),
		color = PALETTE.PorcelainRim,
		material = "SmoothPlastic",
		offset = v(72, -30.4, 70),
		rotation = v(0, 0, 90),
	})
	add(specs, {
		name = "FishBody",
		shape = "Ball",
		size = v(30, 9, 11),
		color = rgb(150, 160, 175),
		material = "SmoothPlastic",
		offset = v(72, -25, 70),
		rotation = v(0, 20, 0),
	})
	add(specs, {
		name = "FishBelly",
		shape = "Ball",
		size = v(24, 6, 9),
		color = PALETTE.Salmon,
		material = "SmoothPlastic",
		offset = v(72, -26.5, 70.5),
		rotation = v(0, 20, 0),
	})
	add(specs, {
		name = "FishTail",
		shape = "Wedge",
		size = v(1, 10, 8),
		color = rgb(130, 140, 155),
		material = "SmoothPlastic",
		offset = v(86.5, -25, 75.3),
		rotation = v(0, 110, 0),
	})
	add(specs, {
		name = "FishEye",
		shape = "Ball",
		size = v(2.2, 2.2, 2.2),
		color = PALETTE.Rice,
		material = "SmoothPlastic",
		offset = v(59, -23.5, 64.5),
	})
	add(specs, {
		name = "FishPupil",
		shape = "Ball",
		size = v(1.1, 1.1, 1.1),
		color = PALETTE.Nori,
		material = "SmoothPlastic",
		offset = v(58.6, -23.2, 64),
	})

	-- 머리 위 매달린 등 3개 (도마 위 높이 40 이상)
	for k = -1, 1 do
		local x = k * 26
		add(specs, {
			name = "LampCord",
			shape = "Block",
			size = v(0.4, 30, 0.4),
			color = PALETTE.Nori,
			material = "SmoothPlastic",
			offset = v(x, 60, 10),
		})
		add(specs, {
			name = "LampShade",
			shape = "Cylinder",
			size = v(4, 9, 9),
			color = PALETTE.Lacquer,
			material = "SmoothPlastic",
			offset = v(x, 44, 10),
			rotation = v(0, 0, 90),
		})
		add(specs, {
			name = "LampBulb",
			shape = "Ball",
			size = v(3.5, 3.5, 3.5),
			color = rgb(255, 232, 170),
			material = "Neon",
			offset = v(x, 41.5, 10),
		})
	end
end

function Art.decor(): { DecorSpec }
	local specs: { DecorSpec } = {}
	local skins = {
		rgb(240, 200, 170),
		rgb(214, 168, 130),
		rgb(250, 214, 186),
		rgb(176, 124, 92),
	}
	-- 머리 중심 높이 -43 ~ -47: 꼭대기(눈동자 포함)는 -30 아래, 턱은 -60 위
	customerFace(specs, 26, -44, 26, skins[1])
	customerFace(specs, -28, -46, 22, skins[2])
	customerFace(specs, -24, -43, -28, skins[3])
	customerFace(specs, 28, -47, -24, skins[4])
	kitchen(specs)
	return specs
end

-- 셀 장식 전체 (테스트·예산 계산용)
function Art.allCellDecor(): { DecorSpec }
	local board = Logic.newBoard()
	local function hasNeighbor(i: number, j: number): boolean
		return Logic.isAlive(board, i, j)
	end
	local specs: { DecorSpec } = {}
	for _, cell in Logic.cells() do
		for _, spec in Art.cellDecor(cell, hasNeighbor) do
			table.insert(specs, spec)
		end
	end
	return specs
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- 위에서 내려다봄 → 칼이 오는 옆 → 도마 바깥 높이 18에서 가운데를 봄
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 60, 75), lookAt = v(0, 0, 0) },
		{ pos = v(60, 22, -35), lookAt = v(0, 2, 0) },
		{ pos = v(0, 18, 52), lookAt = v(0, 2, 0) },
	}
end

function Art.courseVolume(): MapKitLogic.Bounds
	local r = Logic.BOARD_RADIUS
	return { min = v(-r, 2, -r), max = v(r, 12, r) }
end

return Art
