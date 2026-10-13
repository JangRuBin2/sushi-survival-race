--!strict
-- "와르르 나무 블록"(giant-jenga, m5-16) 아트의 순수 데이터. Roblox 자료형을 쓰지 않아요 (lune 테스트).
-- 판정 지오메트리(칸 윗면·블록 3단)는 GiantJenga.build가 직접 만들고(기울기·제거로 움직이니까), 여기는
-- 고정 배경 장식과 색·소개 카메라·시야 상자만 있어요.
--   Art.blockColor(i, j, levelIndex)  바깥 기둥 블록 하나의 나무색 (레벨마다, 칸마다 조금씩 달라요)
--   Art.PEDESTAL_COLOR                가운데 3×3 받침대 색 (더 짙음)
--   Art.decor()                      고정 장식 — MapKit.buildDecor(…, Decor 폴더)
--   Art.introCamera()                IntroCamera 경유점 4개
--   Art.courseVolume()                장식이 들어가면 안 되는 시야 상자 (탑 꼭대기 위 2~12, 격자 안쪽)
--   Art.BUDGET / Art.LIGHTING         m5-24: Extended 예산, 맵 조명 ("저녁 목공소 작업등 아래 블록탑")
--
-- m5-24 아트 디렉션 (docs/specs/m5-24-map-art-pass-v2.md 그룹 C):
--   히어로 색 = 꿀색 나무 3 shade + 노랑-검정 안전 줄무늬. 60 = 어두운 목공소 벽·작업대, 30 = 나무 블록, 10 = 줄무늬·작업등.
--   층: MG = 블록을 뽑는 셰프 손·바이스·톱·상자·여분 블록 더미·손님 얼굴(기존), BG = 작업대 상판(낙하선 −30보다 26 아래)
--       ·목공소 바닥·벽(공구판·창·문·선반)·천장 보.
--   움직이는 판정 파츠(블록·칸 윗면)에는 장식을 달지 않아요 — 전부 Decor 폴더의 고정 장식이고, anim은 단일 파츠에만.
-- 스케일: 1 stud ≈ 1 cm (가이드 1절) — 작업대 높이 90, 망치 32, 톱 60, 페인트 통 지름 16.

local Layout = require(script.Parent.GiantJengaLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)

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

local function addAll(specs: { DecorSpec }, list: { DecorSpec })
	for _, s in list do
		table.insert(specs, s)
	end
end

local function part(
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): DecorSpec
	return {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
end

-- 세운 원기둥 (원기둥 축 로컬 X → Z 90°로 세움)
local function upright(
	name: string,
	height: number,
	diameter: number,
	color: RGB,
	material: string,
	at: Vec3
): DecorSpec
	return part(name, "Cylinder", v(height, diameter, diameter), color, material, at, v(0, 0, 90))
end

Art.BUDGET = "Extended" :: MapKitLogic.BudgetTier

-- m5-24 맵 조명: 해 질 녘 실내(19시), 따뜻한 작업등 vs 창밖 차가운 푸른빛
Art.LIGHTING = {
	ClockTime = 19,
	Brightness = 1.6,
	Ambient = rgb(96, 82, 74),
	OutdoorAmbient = rgb(92, 104, 140),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.7,
	ExposureCompensation = 0.35,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.05,
		Color = rgb(104, 86, 70),
		Decay = rgb(70, 74, 104),
		Glare = 0,
		Haze = 1.2,
	},
	ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.08, TintColor = rgb(255, 242, 226) },
	Bloom = { Intensity = 0.55, Size = 24, Threshold = 1 },
	SunRays = { Intensity = 0.02, Spread = 0.5 },
}

Art.PEDESTAL_COLOR = rgb(108, 74, 44) :: RGB -- 가운데 3×3, 더 두껍고 짙은 나무
Art.LAMP_BULB = "LampBulb"

-- 배경 높이·방 크기 (origin 로컬). 탈락선 −FALL_DEPTH(−30)보다 작업대 윗면이 26 아래.
Art.BENCH_TOP_Y = -56
Art.FLOOR_Y = -146
Art.ROOM_HALF_X = 250
Art.ROOM_BACK_Z = -250
Art.ROOM_FRONT_Z = 260
Art.ROOM_TOP_Y = 330

-- 색
local WOOD = MapKitLogic.shades(PALETTE.Wood) -- 꿀색 나무 3 shade (블록·여분 블록)
local HONEY: RGB = rgb(214, 160, 92)
local BENCH: RGB = rgb(132, 96, 62) -- 작업대 (블록보다 어둡고 채도 낮게)
local WALL: RGB = rgb(78, 66, 58) -- 어두운 목공소 벽
local WALL_PANEL: RGB = rgb(96, 80, 66)
local BEAM: RGB = rgb(52, 40, 32)
local FLOOR: RGB = rgb(70, 64, 58)
local PEGBOARD: RGB = rgb(168, 132, 92)
local IRON: RGB = rgb(58, 62, 68)
local STEEL: RGB = PALETTE.Steel
local STRIPE_YELLOW: RGB = rgb(244, 196, 40)
local STRIPE_BLACK: RGB = rgb(30, 30, 32)
local WINDOW_SKY: RGB = rgb(64, 92, 160) -- 해 질 녘 창밖 (차가운 빛)
local LAMP_WARM: RGB = rgb(255, 214, 150)
local SAWDUST: RGB = rgb(222, 196, 150)
local SLEEVE: RGB = rgb(244, 242, 236) -- 셰프 소매
local SKIN: RGB = rgb(240, 196, 160)
local TOOL_GREEN: RGB = rgb(70, 110, 88) -- 공구 손잡이 (위험 빨강과 다르게)
local TOOL_BLUE: RGB = rgb(58, 92, 150)

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

-- 위를 보고 입 벌린 거대 손님 얼굴 (탑 아래, Survival 낙하 "손님 입" 연출과 같은 표현). 작업대 뒤에서 고개만 내밀어요.
local function customerFace(specs: { DecorSpec }, cx: number, cy: number, cz: number, skin: RGB)
	local radius = 10
	add(
		specs,
		part("CustomerHead", "Ball", v(radius * 2, radius * 2, radius * 2), skin, "SmoothPlastic", v(cx, cy, cz))
	)
	local top = cy + radius
	add(
		specs,
		part(
			"CustomerMouth",
			"Cylinder",
			v(2.4, 8, 8),
			rgb(60, 18, 24),
			"SmoothPlastic",
			v(cx, top - 0.5, cz),
			v(0, 0, 90)
		)
	)
	add(
		specs,
		part("CustomerTongue", "Ball", v(3.6, 1.3, 3.2), rgb(220, 90, 100), "SmoothPlastic", v(cx, top + 1.2, cz + 1))
	)
	for _, side in { -1, 1 } do
		add(
			specs,
			part("CustomerEye", "Ball", v(3, 3, 3), PALETTE.Rice, "SmoothPlastic", v(cx + side * 4, cy + 4, cz - 7))
		)
		add(
			specs,
			part(
				"CustomerPupil",
				"Ball",
				v(1.4, 1.4, 1.4),
				PALETTE.Nori,
				"SmoothPlastic",
				v(cx + side * 4, cy + 4.6, cz - 8.3)
			)
		)
		-- m5-24: 볼 홍조 + 눈썹 (둥근 얼굴이 "손님"으로 읽히게)
		add(
			specs,
			part(
				"CustomerBlush",
				"Ball",
				v(3.2, 1.4, 2),
				rgb(240, 150, 140),
				"SmoothPlastic",
				v(cx + side * 6.5, cy + 0.5, cz - 7.6)
			)
		)
		add(
			specs,
			part(
				"CustomerBrow",
				"Block",
				v(3.4, 0.7, 0.8),
				rgb(70, 46, 34),
				"SmoothPlastic",
				v(cx + side * 4, cy + 6.8, cz - 7.6),
				v(0, 0, side * -12)
			)
		)
	end
end

-- BG ① 작업대 상판 (판자 6장, shade 섞기) + 앞 모서리 립 + 다리
local function workbench(specs: { DecorSpec })
	local top = Art.BENCH_TOP_Y
	local thick = 8
	local halfX, back, front = 210, -170, 170
	local planks = 6
	local depth = (front - back) / planks
	for k = 0, planks - 1 do
		local z = back + depth * (k + 0.5)
		local color = if k % 3 == 0
			then MapKitLogic.shade(BENCH, 1.08)
			elseif k % 3 == 1 then BENCH
			else MapKitLogic.shade(BENCH, 0.9)
		add(
			specs,
			part("BenchPlank", "Block", v(halfX * 2, thick, depth - 0.8), color, "WoodPlanks", v(0, top - thick / 2, z))
		)
	end
	-- 판자 사이 틈 (어두운 띠, 윗면보다 살짝 아래)
	for k = 1, planks - 1 do
		add(
			specs,
			part(
				"BenchSeam",
				"Block",
				v(halfX * 2, thick - 0.6, 1),
				MapKitLogic.shade(BENCH, 0.55),
				"Wood",
				v(0, top - thick / 2 - 0.4, back + depth * k)
			)
		)
	end
	-- 둘레 립 (두께감)
	addAll(
		specs,
		MapKitShapes.lipTrim(
			"BenchLip",
			v(halfX * 2, 0, front - back),
			2,
			thick + 2,
			MapKitLogic.shade(BENCH, 0.7),
			"Wood",
			v(0, top - thick / 2 - 1, 0)
		)
	)
	-- 다리 4개 + 아래 가로대
	local legH = top - thick - Art.FLOOR_Y
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			addAll(
				specs,
				MapKitShapes.roundedBox(
					"BenchLeg",
					v(14, legH, 14),
					MapKitLogic.shade(BENCH, 0.75),
					"Wood",
					v(sx * (halfX - 14), top - thick - legH / 2, sz * (front - 14)),
					{ style = "vertical", radius = 2 }
				)
			)
		end
		add(
			specs,
			part(
				"BenchRail",
				"Block",
				v(10, 8, front * 2 - 28),
				MapKitLogic.shade(BENCH, 0.65),
				"Wood",
				v(sx * (halfX - 14), Art.FLOOR_Y + 22, 0)
			)
		)
	end
end

-- BG ② 방 껍데기: 바닥·벽 4면·벽 기둥·천장 보
local function room(specs: { DecorSpec })
	local floorY, topY = Art.FLOOR_Y, Art.ROOM_TOP_Y
	local hx, back, front = Art.ROOM_HALF_X, Art.ROOM_BACK_Z, Art.ROOM_FRONT_Z
	local height = topY - floorY
	local midY = (topY + floorY) / 2
	-- 바닥: 콘크리트 판 4장 (shade)
	for k, at in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local w, d = hx, (front - back) / 2
		add(
			specs,
			part(
				"WorkshopFloor",
				"Block",
				v(w - 1, 4, d - 1),
				if k % 2 == 0 then FLOOR else MapKitLogic.shade(FLOOR, 1.1),
				"Concrete",
				v(at[1] * w / 2, floorY - 2, (back + front) / 2 + at[2] * d / 2)
			)
		)
	end
	-- 벽 4면 (아래 징두리 판 + 위 회벽)
	local wainscot = 120
	local walls = {
		{ name = "BackWall", size = v(hx * 2 + 12, 0, 6), at = v(0, 0, back - 3) },
		{ name = "FrontWall", size = v(hx * 2 + 12, 0, 6), at = v(0, 0, front + 3) },
		{ name = "SideWall", size = v(6, 0, front - back), at = v(-hx - 3, 0, (back + front) / 2) },
		{ name = "SideWall", size = v(6, 0, front - back), at = v(hx + 3, 0, (back + front) / 2) },
	}
	for _, w in walls do
		add(
			specs,
			part(
				w.name,
				"Block",
				v(w.size.x, height - wainscot, w.size.z),
				WALL,
				"Plaster",
				v(w.at.x, floorY + wainscot + (height - wainscot) / 2, w.at.z)
			)
		)
		add(
			specs,
			part(
				w.name .. "Panel",
				"Block",
				v(w.size.x + 2, wainscot, w.size.z + 2),
				WALL_PANEL,
				"WoodPlanks",
				v(w.at.x, floorY + wainscot / 2, w.at.z)
			)
		)
		-- 징두리 위 몰딩
		add(
			specs,
			part(
				"WallMolding",
				"Block",
				v(w.size.x + 4, 4, w.size.z + 4),
				BEAM,
				"Wood",
				v(w.at.x, floorY + wainscot, w.at.z)
			)
		)
	end
	-- 벽 기둥 (뒤·앞 벽 4개씩, 옆 벽 4개씩)
	for k = -1.5, 1.5 do
		local x = k * 130
		for _, z in { back + 4, front - 4 } do
			add(specs, part("WallPost", "Block", v(12, height, 8), BEAM, "Wood", v(x, midY, z)))
		end
	end
	for k = -1.5, 1.5 do
		local z = (back + front) / 2 + k * 130
		for _, x in { -hx + 4, hx - 4 } do
			add(specs, part("WallPost", "Block", v(8, height, 12), BEAM, "Wood", v(x, midY, z)))
		end
	end
	-- 천장 보 (판 대신 보만 — 위에서 보는 카메라가 막히지 않게)
	for k = -2, 2 do
		add(specs, part("CeilingBeam", "Block", v(hx * 2, 14, 12), BEAM, "Wood", v(0, topY - 7, k * 100)))
	end
	add(specs, part("CeilingBeam", "Block", v(12, 14, front - back), BEAM, "Wood", v(0, topY - 21, (back + front) / 2)))
end

-- BG ③ 뒤 벽 공구판 (구멍 격자 + 공구 실루엣 + 걸린 공구)
local function pegboard(specs: { DecorSpec })
	local z = Art.ROOM_BACK_Z + 2
	local cx, cy = 0, 30
	local w, h = 240, 130
	addAll(specs, MapKitShapes.roundedBox("Pegboard", v(w, h, 3), PEGBOARD, "Wood", v(cx, cy, z), { radius = 1.2 }))
	addAll(specs, MapKitShapes.lipTrim("PegboardFrame", v(w, 0, h), 3, 4, BEAM, "Wood", v(cx, cy, z + 1), v(90, 0, 0)))
	-- 구멍 격자
	for i = -7, 7 do
		for j = -3, 3 do
			add(
				specs,
				part(
					"PegHole",
					"Cylinder",
					v(0.6, 2, 2),
					MapKitLogic.shade(PEGBOARD, 0.45),
					"SmoothPlastic",
					v(cx + i * 15, cy + j * 16, z + 1.6),
					v(0, 90, 0)
				)
			)
		end
	end
	local front = z + 3.5
	-- 망치 (손잡이 + 머리)
	addAll(
		specs,
		MapKitShapes.capsule(
			"HammerHandle",
			32,
			3,
			MapKitLogic.shade(PALETTE.Wood, 0.85),
			"Wood",
			v(-90, 22, front),
			v(0, 0, 90)
		)
	)
	addAll(specs, MapKitShapes.roundedBox("HammerHead", v(14, 5, 5), IRON, "Metal", v(-90, 40, front), { radius = 1 }))
	-- 톱 (날 + 손잡이)
	add(specs, part("WallSawBlade", "Wedge", v(1, 18, 60), STEEL, "Metal", v(-40, 30, front), v(0, 90, 0)))
	addAll(
		specs,
		MapKitShapes.roundedBox("WallSawHandle", v(14, 14, 3), TOOL_GREEN, "Plastic", v(-4, 30, front), { radius = 2 })
	)
	-- 렌치 2개 (크기 다르게)
	for k, size in { 26, 20 } do
		local x = 30 + k * 16
		addAll(specs, MapKitShapes.capsule("Wrench", size, 3, STEEL, "Metal", v(x, 28, front), v(0, 0, 90)))
		add(
			specs,
			part("WrenchJaw", "Cylinder", v(2, 7, 7), STEEL, "Metal", v(x, 28 + size / 2 + 2, front), v(0, 90, 0))
		)
	end
	-- 드라이버 3개 (손잡이 색 shade)
	for k = 0, 2 do
		local x = 82 + k * 10
		addAll(
			specs,
			MapKitShapes.capsule(
				"DriverGrip",
				10,
				3.4,
				MapKitLogic.shade(TOOL_BLUE, 0.85 + k * 0.12),
				"Plastic",
				v(x, 44, front),
				v(0, 0, 90)
			)
		)
		add(specs, part("DriverShaft", "Cylinder", v(14, 1, 1), STEEL, "Metal", v(x, 32, front), v(0, 0, 90)))
	end
	-- 공구 자리 실루엣 (빈 자리 — 망치를 셰프가 가져갔어요)
	add(specs, part("ToolOutline", "Block", v(3, 30, 0.4), rgb(60, 46, 36), "SmoothPlastic", v(-70, 18, z + 1.7)))
	add(specs, part("ToolOutline", "Block", v(12, 4, 0.4), rgb(60, 46, 36), "SmoothPlastic", v(-70, 34, z + 1.7)))
	-- 걸린 줄자 띠 (단일 파츠 Bob)
	add(specs, {
		name = "TapeHang",
		shape = "Block",
		size = v(3, 40, 0.3),
		color = STRIPE_YELLOW,
		material = "SmoothPlastic",
		offset = v(112, 4, front + 1),
		anim = { kind = "Bob", period = 4.2, amount = 1.2 },
	})
	add(specs, part("TapeHangCase", "Cylinder", v(5, 12, 12), STRIPE_YELLOW, "Plastic", v(112, 26, front), v(0, 90, 0)))
	-- 공구판 위 작업 앞치마 (단일 파츠 Sway)
	add(specs, {
		name = "ApronHang",
		shape = "Block",
		size = v(30, 44, 1),
		color = rgb(120, 92, 64),
		material = "Fabric",
		offset = v(150, 6, Art.ROOM_BACK_Z + 6),
		anim = { kind = "Sway", period = 6.5, amount = 3, axis = "Z" },
	})
end

-- BG ④ 오른쪽 벽 창 2개 (해 질 녘 푸른 하늘 — 차가운 빛)
local function windows(specs: { DecorSpec })
	local x = Art.ROOM_HALF_X - 1
	for k, z in { -60, 80 } do
		local cy = 60
		add(specs, {
			name = "WindowSky",
			shape = "Block",
			size = v(2, 100, 80),
			color = WINDOW_SKY,
			material = "Neon",
			offset = v(x, cy, z),
			light = if k == 1
				then {
					kind = "Surface",
					color = rgb(150, 176, 240),
					brightness = 2,
					range = 16,
					angle = 120,
					face = "Left",
				}
				else nil,
		})
		-- 창 너머 지붕선 실루엣
		add(
			specs,
			part(
				"WindowRoofline",
				"Wedge",
				v(1, 26, 80),
				rgb(40, 48, 78),
				"SmoothPlastic",
				v(x - 1.4, cy - 37, z),
				v(0, 90, 0)
			)
		)
		-- 창틀 + 십자 살
		addAll(
			specs,
			MapKitShapes.lipTrim("WindowFrame", v(100, 0, 80), 4, 6, BEAM, "Wood", v(x - 2, cy, z), v(0, 0, 90))
		)
		add(specs, part("WindowMullion", "Block", v(4, 100, 3), BEAM, "Wood", v(x - 3, cy, z)))
		add(specs, part("WindowMullion", "Block", v(4, 3, 80), BEAM, "Wood", v(x - 3, cy, z)))
		add(
			specs,
			part("WindowSill", "Block", v(12, 4, 92), MapKitLogic.shade(BEAM, 1.3), "Wood", v(x - 6, cy - 52, z))
		)
	end
end

-- BG ⑤ 왼쪽 벽 선반 (페인트 통·나무 상자) + 기대 세운 목재
local function shelves(specs: { DecorSpec })
	local x = -Art.ROOM_HALF_X + 18
	for k, y in { -40, 30, 100 } do
		add(
			specs,
			part("ShelfBoard", "Block", v(30, 4, 200), MapKitLogic.shade(BENCH, 0.85), "WoodPlanks", v(x, y, -40))
		)
		add(specs, part("ShelfBracket", "Wedge", v(3, 14, 22), IRON, "Metal", v(x - 4, y - 9, -120), v(0, -90, 180)))
		add(specs, part("ShelfBracket", "Wedge", v(3, 14, 22), IRON, "Metal", v(x - 4, y - 9, 40), v(0, -90, 180)))
		-- 페인트 통 무리 (크기·색 다르게)
		local cans = { { -110, 18, PALETTE.Porcelain }, { -90, 14, TOOL_BLUE }, { -74, 16, TOOL_GREEN } }
		for n, can in cans do
			local d = can[2] * (1 + ((k + n) % 3) * 0.08)
			addAll(
				specs,
				MapKitShapes.rimDisc(
					"PaintCan",
					d,
					d * 1.1,
					MapKitLogic.shade(can[3], 0.9 + 0.05 * k),
					"Metal",
					v(x, y + 2 + d * 0.55, can[1] + k * 6),
					{ rimColor = STEEL, rimWidth = 0.8, rimHeight = 1, segments = 10 }
				)
			)
		end
		-- 나무 상자 2개
		for n = 0, 1 do
			local s = 22 - n * 4
			addAll(
				specs,
				MapKitShapes.bevelBox(
					"ShelfCrate",
					v(s, s * 0.8, s),
					WOOD[if n == 0 then "base" else "light"],
					"Wood",
					v(x, y + 2 + s * 0.4, 0 + n * 30 + k * 10),
					1.2,
					v(0, k * 9 - n * 6, 0)
				)
			)
		end
	end
	-- 벽에 기대 세운 긴 목재 (각도·shade 다르게)
	for n = 0, 4 do
		local z = 90 + n * 14
		local len = 230 - n * 12
		add(
			specs,
			part(
				"LeaningLumber",
				"Block",
				v(6, len, 12),
				if n % 3 == 0 then WOOD.light elseif n % 3 == 1 then WOOD.base else WOOD.dark,
				"Wood",
				v(x - 2 + n * 0.5, Art.FLOOR_Y + len / 2 * math.cos(math.rad(8)), z),
				v(8 + n, 0, -10)
			)
		)
		-- 바닥 쪽 짙은 띠 (맨 판 대신 두 shade — 손때·그늘)
		add(
			specs,
			part(
				"LeaningLumberBand",
				"Block",
				v(6.4, 18, 12.4),
				MapKitLogic.shade(WOOD.dark, 0.8),
				"Wood",
				v(x - 2 + n * 0.5, Art.FLOOR_Y + 9, z),
				v(8 + n, 0, -10)
			)
		)
	end
end

-- BG ⑥ 앞 벽: 문 + 벽시계(진자 Sway) + 선풍기(날 Spin)
local function frontWall(specs: { DecorSpec })
	local z = Art.ROOM_FRONT_Z - 2
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"Door",
			v(90, 200, 4),
			rgb(110, 78, 52),
			"WoodPlanks",
			v(-120, Art.FLOOR_Y + 100, z),
			{ radius = 1.5 }
		)
	)
	add(specs, part("DoorKnob", "Ball", v(6, 6, 6), PALETTE.Egg, "Metal", v(-90, Art.FLOOR_Y + 96, z - 4)))
	-- 벽시계
	addAll(
		specs,
		MapKitShapes.rimDisc(
			"WallClock",
			40,
			3,
			PALETTE.Cream,
			"SmoothPlastic",
			v(60, 140, z - 2),
			{ rimColor = BEAM, rimWidth = 3, rimHeight = 2, segments = 16, rotation = v(90, 0, 0) }
		)
	)
	add(specs, part("ClockHand", "Block", v(1.4, 14, 0.6), PALETTE.Nori, "SmoothPlastic", v(60, 146, z - 5)))
	add(specs, part("ClockHand", "Block", v(10, 1.4, 0.6), PALETTE.Nori, "SmoothPlastic", v(64, 140, z - 5)))
	add(specs, {
		name = "ClockPendulum",
		shape = "Block",
		size = v(3, 50, 1),
		color = PALETTE.EggDark,
		material = "Metal",
		offset = v(60, 92, z - 3),
		anim = { kind = "Sway", period = 2.4, amount = 8, axis = "Z" },
	})
	-- 선풍기 (받침 + 망 + 도는 날 2개 — 날은 같은 중심이라 같이 돌아요)
	local fx, fy = 170, Art.BENCH_TOP_Y + 40
	add(specs, upright("FanStand", 40, 4, IRON, "Metal", v(fx, Art.BENCH_TOP_Y + 20, 120)))
	add(specs, upright("FanBase", 3, 22, IRON, "Metal", v(fx, Art.BENCH_TOP_Y + 1.5, 120)))
	addAll(specs, MapKitShapes.ring("FanGuard", 18, 1.2, 1.2, 14, STEEL, "Metal", v(fx, fy, 120), v(0, -35, 90)))
	add(specs, part("FanHub", "Cylinder", v(6, 8, 8), IRON, "Metal", v(fx, fy, 120), v(0, 145, 0)))
	for k = 0, 1 do
		add(specs, {
			name = "FanBlade",
			shape = "Block",
			size = v(32, 5, 1),
			color = MapKitLogic.shade(TOOL_BLUE, 1.1),
			material = "SmoothPlastic",
			offset = v(fx, fy, 120),
			rotation = v(0, -125, k * 90),
			anim = { kind = "Spin", period = 1.2, axis = "Z" },
		})
	end
end

-- BG ⑦ 앞 벽 오른쪽: 따뜻한 벽등 + 막대 클램프 걸이 (eye 뷰 정면의 어두운 벽을 채워요)
local function clampRack(specs: { DecorSpec })
	local z = Art.ROOM_FRONT_Z - 4
	add(specs, part("ClampRackBar", "Block", v(130, 6, 6), BEAM, "Wood", v(150, 70, z)))
	for k = 0, 4 do
		local x = 100 + k * 25
		local len = 60 - (k % 2) * 14
		add(specs, part("BarClamp", "Block", v(2.4, len, 2.4), STEEL, "Metal", v(x, 70 - len / 2, z - 3)))
		local jaw = if k % 2 == 0 then MapKitLogic.shade(TOOL_BLUE, 1.05) else TOOL_GREEN
		add(specs, part("BarClampJaw", "Block", v(7, 4, 4), jaw, "Plastic", v(x + 3, 64, z - 3)))
		add(specs, part("BarClampJaw", "Block", v(7, 4, 4), jaw, "Plastic", v(x + 3, 72 - len, z - 3)))
	end
	-- 벽등 (갓 + 전구 Point 빛)
	add(specs, part("SconceArm", "Block", v(2, 2, 14), IRON, "Metal", v(150, 120, z - 7)))
	add(
		specs,
		part("SconceShade", "Cylinder", v(10, 14, 14), rgb(196, 150, 90), "Fabric", v(150, 116, z - 14), v(0, 0, 90))
	)
	add(specs, {
		name = "SconceBulb",
		shape = "Ball",
		size = v(5, 5, 5),
		color = LAMP_WARM,
		material = "Neon",
		offset = v(150, 110, z - 14),
		light = { kind = "Point", color = LAMP_WARM, brightness = 1.2, range = 50 },
	})
end

-- MG ① 블록을 뽑는 거대 셰프 손 (탑 왼쪽 −X). 뽑은 블록은 탑 바닥(−12)보다 아래 — 밟는 면처럼 보이지 않게.
local function chefHand(specs: { DecorSpec })
	local bx, by, bz = -42, -18, -8
	-- 뽑아 든 블록 (블록과 같은 꿀색 + 결 띠)
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"PulledBlock",
			v(9, 3.8, 9),
			HONEY,
			"WoodPlanks",
			v(bx, by, bz),
			{ radius = 0.5, rotation = v(0, 0, -8) }
		)
	)
	-- 손바닥·엄지·검지·중지
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"ChefPalm",
			v(10, 7, 13),
			SKIN,
			"SmoothPlastic",
			v(bx - 11, by + 1, bz),
			{ radius = 2.4, rotation = v(0, 0, -20) }
		)
	)
	addAll(
		specs,
		MapKitShapes.capsule("ChefThumb", 11, 3.6, SKIN, "SmoothPlastic", v(bx - 2, by - 3.2, bz + 4.5), v(0, 10, -8))
	)
	addAll(
		specs,
		MapKitShapes.capsule("ChefFinger", 12, 3.4, SKIN, "SmoothPlastic", v(bx - 1, by + 2.9, bz - 1), v(0, 0, -6))
	)
	addAll(
		specs,
		MapKitShapes.capsule("ChefFinger", 11, 3.4, SKIN, "SmoothPlastic", v(bx - 2, by + 3.1, bz - 4.6), v(0, -8, -2))
	)
	addAll(
		specs,
		MapKitShapes.capsule(
			"ChefFinger",
			9,
			3.2,
			MapKitLogic.shade(SKIN, 0.95),
			"SmoothPlastic",
			v(bx - 6, by + 2.6, bz + 2.6),
			v(0, 14, -30)
		)
	)
	-- 손톱 반짝 (작은 밝은 점)
	add(
		specs,
		part("ChefNail", "Ball", v(1.4, 0.8, 2), rgb(252, 226, 214), "SmoothPlastic", v(bx + 4.6, by + 3.6, bz - 1))
	)
	-- 소매 (손목 → 왼쪽 위로) + 소맷부리
	local wx, wy = bx - 17, by + 4
	local ex, ey = wx - 48, wy + 40
	local dx, dy = ex - wx, ey - wy
	local length = math.sqrt(dx * dx + dy * dy)
	local angle = math.deg(math.atan2(dy, dx))
	add(
		specs,
		part(
			"ChefSleeve",
			"Cylinder",
			v(length, 15, 15),
			SLEEVE,
			"Fabric",
			v((wx + ex) / 2, (wy + ey) / 2, bz),
			v(0, 0, angle)
		)
	)
	add(
		specs,
		part(
			"ChefCuff",
			"Cylinder",
			v(4, 16.5, 16.5),
			MapKitLogic.shade(SLEEVE, 0.86),
			"Fabric",
			v(wx - 1.6, wy + 1.3, bz),
			v(0, 0, angle)
		)
	)
	-- 소매 주름 띠 2개
	for k = 1, 2 do
		local t = 0.3 + k * 0.22
		add(
			specs,
			part(
				"ChefSleeveFold",
				"Cylinder",
				v(1.5, 15.6, 15.6),
				MapKitLogic.shade(SLEEVE, 0.92),
				"Fabric",
				v(wx + dx * t, wy + dy * t, bz),
				v(0, 0, angle)
			)
		)
	end
end

-- MG ② 작업대 위 바이스·톱·연필·줄자·머그 (오른쪽 +X)
local function benchTools(specs: { DecorSpec })
	local top = Art.BENCH_TOP_Y
	-- 바이스 (무쇠 받침 + 턱 2개 + 나사 + 손잡이) — 블록 하나를 물고 있어요
	local vx, vz = 92, 20
	addAll(specs, MapKitShapes.bevelBox("ViseBase", v(26, 7, 18), IRON, "Metal", v(vx, top + 3.5, vz), 1.2))
	for _, side in { -1, 1 } do
		addAll(
			specs,
			MapKitShapes.roundedBox(
				"ViseJaw",
				v(6, 14, 18),
				MapKitLogic.shade(TOOL_BLUE, 0.9),
				"Metal",
				v(vx + side * 9, top + 14, vz),
				{ radius = 1 }
			)
		)
		add(
			specs,
			part("ViseJawPlate", "Block", v(0.6, 6, 16), STEEL, "DiamondPlate", v(vx + side * 5.8, top + 17, vz))
		)
	end
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"ViseBlock",
			v(11, 9, 9),
			WOOD.light,
			"WoodPlanks",
			v(vx, top + 20, vz),
			{ radius = 0.5 }
		)
	)
	addAll(specs, MapKitShapes.capsule("ViseScrew", 30, 2.4, STEEL, "Metal", v(vx + 24, top + 12, vz), nil))
	addAll(specs, MapKitShapes.capsule("ViseHandle", 20, 1.8, STEEL, "Metal", v(vx + 38, top + 12, vz), v(0, 90, 0)))
	-- 탁상 작업등 (바이스 위, 따뜻한 Point 빛)
	add(specs, upright("DeskLampPole", 40, 2, IRON, "Metal", v(vx - 26, top + 20, vz - 24)))
	add(specs, upright("DeskLampBase", 3, 14, IRON, "Metal", v(vx - 26, top + 1.5, vz - 24)))
	add(
		specs,
		part("DeskLampArm", "Cylinder", v(28, 2, 2), IRON, "Metal", v(vx - 14, top + 44, vz - 14), v(0, -40, -20))
	)
	add(
		specs,
		part("DeskLampShade", "Cylinder", v(8, 12, 12), TOOL_GREEN, "Metal", v(vx - 2, top + 40, vz - 4), v(0, 0, 90))
	)
	add(specs, {
		name = "DeskLampBulb",
		shape = "Ball",
		size = v(5, 5, 5),
		color = LAMP_WARM,
		material = "Neon",
		offset = v(vx - 2, top + 35.5, vz - 4),
		light = { kind = "Point", color = LAMP_WARM, brightness = 1.4, range = 36 },
	})
	-- 톱 (작업대 위에 비스듬히 놓임)
	add(specs, part("BenchSawBlade", "Wedge", v(0.8, 16, 62), STEEL, "Metal", v(70, top + 0.5, -70), v(0, 30, 90)))
	add(specs, {
		name = "BenchSawGlint",
		shape = "Block",
		size = v(40, 0.2, 1.4),
		color = rgb(240, 244, 248),
		material = "Metal",
		offset = v(66, top + 0.95, -64),
		rotation = v(0, -60, 0),
		reflectance = 0.4,
	})
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"BenchSawHandle",
			v(14, 3, 14),
			TOOL_GREEN,
			"Plastic",
			v(97, top + 1.5, -86),
			{ radius = 1.2, rotation = v(0, 30, 0) }
		)
	)
	-- 목수 연필 + 줄자 (기존 이름 유지)
	addAll(
		specs,
		MapKitShapes.capsule(
			"CarpenterPencil",
			22,
			2.4,
			rgb(232, 150, 52),
			"Plastic",
			v(40, top + 1.2, 54),
			v(0, 70, 0)
		)
	)
	add(specs, upright("TapeMeasureBody", 6, 12, STRIPE_YELLOW, "SmoothPlastic", v(120, top + 3, -10)))
	add(
		specs,
		part("TapeMeasureTab", "Block", v(60, 0.6, 3), rgb(236, 200, 80), "Metal", v(84, top + 0.4, -18), v(0, -12, 0))
	)
	for k = 0, 5 do
		add(
			specs,
			part(
				"TapeTick",
				"Block",
				v(0.4, 0.7, 2),
				PALETTE.Nori,
				"SmoothPlastic",
				v(64 + k * 8, top + 0.6, -14 + k * 1.7),
				v(0, -12, 0)
			)
		)
	end
	-- 커피 머그 (김)
	addAll(
		specs,
		MapKitShapes.rimDisc(
			"CoffeeMug",
			10,
			12,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(140, top + 6, 40),
			{ rimColor = TOOL_BLUE, rimWidth = 0.8, rimHeight = 1, segments = 10 }
		)
	)
	add(specs, {
		name = "CoffeeSurface",
		shape = "Cylinder",
		size = v(0.4, 8.4, 8.4),
		color = PALETTE.Chocolate,
		material = "SmoothPlastic",
		offset = v(140, top + 11.6, 40),
		rotation = v(0, 0, 90),
		particle = "Steam",
		particleRate = 3,
	})
	add(
		specs,
		part(
			"CoffeeHandle",
			"Cylinder",
			v(1.6, 7, 7),
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(146, top + 6, 40),
			v(0, 90, 0)
		)
	)
end

-- MG ③ 톱밥 더미 무리 + 나무 상자 + 여분 블록 더미 (작업대 위, 탑 둘레 밖)
local function sawdustAndCrates(specs: { DecorSpec })
	local top = Art.BENCH_TOP_Y
	-- 톱밥 더미 3곳 (큰 것 1 + 작은 것 2, 납작한 공 겹치기)
	local piles = { { 60, 90, 1.0, true }, { -90, 70, 0.8, true }, { 30, -110, 0.7, false } }
	for _, pile in piles do
		local px, pz, s, dust = pile[1], pile[2], pile[3], pile[4]
		add(specs, part("Sawdust", "Ball", v(34 * s, 12 * s, 28 * s), SAWDUST, "Sand", v(px, top + 1, pz)))
		add(
			specs,
			part(
				"Sawdust",
				"Ball",
				v(18 * s, 8 * s, 16 * s),
				MapKitLogic.shade(SAWDUST, 1.1),
				"Sand",
				v(px + 14 * s, top + 0.5, pz + 9 * s)
			)
		)
		add(
			specs,
			part(
				"Sawdust",
				"Ball",
				v(12 * s, 5 * s, 12 * s),
				MapKitLogic.shade(SAWDUST, 0.88),
				"Sand",
				v(px - 12 * s, top + 0.3, pz - 8 * s)
			)
		)
		-- 나무 부스러기 몇 조각
		for k = 1, 4 do
			local a = k * 1.7
			add(
				specs,
				part(
					"WoodShaving",
					"Block",
					v(5, 0.4, 1.6),
					if k % 2 == 0 then WOOD.light else WOOD.base,
					"Wood",
					v(px + math.cos(a) * 24 * s, top + 0.25, pz + math.sin(a) * 20 * s),
					v(0, k * 47, 0)
				)
			)
		end
		if dust then
			add(specs, {
				name = "SawdustDust",
				shape = "Block",
				size = v(16 * s, 0.2, 16 * s),
				color = SAWDUST,
				material = "SmoothPlastic",
				offset = v(px, top + 6 * s, pz),
				transparency = 1,
				particle = "Dust",
				particleRate = 3,
			})
		end
	end
	-- 나무 상자 (네 모서리 바깥, 기존 이름 Crate — 띠 트림)
	local far = 120
	for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local cx, cz = corner[1] * far, corner[2] * far
		for n, size in { 24, 18 } do
			local x = cx + (n - 1) * corner[1] * -20
			local z = cz + (n - 1) * 10
			local y = top + size / 2
			local yaw = corner[1] * 12 + (n - 1) * corner[2] * 18
			add(
				specs,
				part(
					"Crate",
					"Block",
					v(size, size, size),
					if n == 1 then WOOD.base else WOOD.dark,
					"Wood",
					v(x, y, z),
					v(0, yaw, 0)
				)
			)
			for _, dy in { -size * 0.3, size * 0.3 } do
				add(
					specs,
					part(
						"CrateSlat",
						"Block",
						v(size + 0.6, 2, size + 0.6),
						MapKitLogic.shade(BENCH, 0.7),
						"Wood",
						v(x, y + dy, z),
						v(0, yaw, 0)
					)
				)
			end
		end
	end
	-- 여분 블록 더미 (탑과 같은 꿀색 3 shade, 서로 조금씩 어긋나게) — 앞 오른쪽
	local stack = {
		{ 70, 0, 50, 0, "base" },
		{ 82, 0, 52, 8, "light" },
		{ 74, 1, 49, -6, "dark" },
		{ 78, 2, 53, 11, "base" },
		{ 96, 0, 70, 30, "light" },
		{ 104, 0, 62, 52, "dark" },
	}
	for _, b in stack do
		local x, layer, z, yaw, tone = b[1], b[2], b[3], b[4], b[5]
		addAll(
			specs,
			MapKitShapes.roundedBox(
				"SpareBlock",
				v(10, 4, 10),
				WOOD[tone],
				"WoodPlanks",
				v(x, top + 2 + layer * 4, z),
				{ radius = 0.4, rotation = v(0, yaw, 0) }
			)
		)
	end
	-- 블록 상자 (안전 줄무늬 띠)
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"BlockBox",
			v(44, 26, 18),
			rgb(176, 136, 92),
			"Cardboard",
			v(-120, top + 13, -40),
			{ radius = 1.4, rotation = v(0, 18, 0) }
		)
	)
	for k = -3, 3 do
		add(
			specs,
			part(
				"BlockBoxStripe",
				"Block",
				v(5.6, 6, 18.6),
				if k % 2 == 0 then STRIPE_YELLOW else STRIPE_BLACK,
				"SmoothPlastic",
				v(-120 + math.cos(math.rad(18)) * k * 6, top + 6, -40 - math.sin(math.rad(18)) * k * 6),
				v(0, 18, 0)
			)
		)
	end
end

-- 10% 강조: 작업대 위 탑 그림자 자리를 두른 노랑-검정 안전 줄무늬 테이프 (탑 아래 −56, 밟는 면에서 56 아래)
local function safetyTape(specs: { DecorSpec })
	local half = 44
	local seg = 8
	local n = math.floor(half * 2 / seg)
	local y = Art.BENCH_TOP_Y + 0.2
	for side = 0, 3 do
		for k = 0, n - 1 do
			local along = -half + seg * (k + 0.5)
			local x, z, yaw
			if side == 0 then
				x, z, yaw = along, -half, 0
			elseif side == 1 then
				x, z, yaw = along, half, 0
			elseif side == 2 then
				x, z, yaw = -half, along, 90
			else
				x, z, yaw = half, along, 90
			end
			add(
				specs,
				part(
					"SafetyStripe",
					"Block",
					v(seg, 0.4, 3),
					if (k + side) % 2 == 0 then STRIPE_YELLOW else STRIPE_BLACK,
					"SmoothPlastic",
					v(x, y, z),
					v(0, yaw, 0)
				)
			)
		end
	end
	-- 작업대 앞 모서리 줄무늬 띠
	for k = -10, 10 do
		add(
			specs,
			part(
				"BenchEdgeStripe",
				"Block",
				v(20, 3, 0.6),
				if k % 2 == 0 then STRIPE_YELLOW else STRIPE_BLACK,
				"SmoothPlastic",
				v(k * 20, Art.BENCH_TOP_Y - 5, 173.2)
			)
		)
	end
end

-- 머리 위 작업등 (기존 LampBulb 3개 — build가 PointLight를 붙여요) + 레일 + 그림자 작업등 SpotLight 1
local function lamps(specs: { DecorSpec })
	add(specs, part("LampRail", "Block", v(100, 4, 4), IRON, "Metal", v(0, 72, 0)))
	add(
		specs,
		part("LampRailHanger", "Block", v(1, 300 - 72 - 7, 1), IRON, "Metal", v(-46, 72 + (300 - 79) / 2 + 2, 0))
	)
	add(specs, part("LampRailHanger", "Block", v(1, 300 - 72 - 7, 1), IRON, "Metal", v(46, 72 + (300 - 79) / 2 + 2, 0)))
	for k = -1, 1 do
		local x = k * 24
		add(specs, part("LampCord", "Block", v(0.4, 34, 0.4), PALETTE.Nori, "SmoothPlastic", v(x, 54, 0)))
		add(specs, part("LampShade", "Cylinder", v(4, 9, 9), rgb(60, 60, 64), "Metal", v(x, 36, 0), v(0, 0, 90)))
		add(
			specs,
			part("LampShadeRim", "Cylinder", v(0.8, 10.4, 10.4), STRIPE_YELLOW, "Metal", v(x, 34.2, 0), v(0, 0, 90))
		)
		add(specs, part(Art.LAMP_BULB, "Ball", v(3.2, 3.2, 3.2), rgb(255, 235, 180), "Neon", v(x, 33.5, 0)))
	end
	-- 그림자 작업등: 탑 위 고정 갓, 아래로 좁은 SpotLight (블록 빠진 자리 그림자 — "약한 곳"이 읽히게)
	local wx, wy, wz = 0, 50, -24
	add(specs, part("WorkLampCord", "Block", v(0.6, 22, 0.6), PALETTE.Nori, "SmoothPlastic", v(wx, wy + 13, wz)))
	add(specs, part("WorkLampHood", "Cylinder", v(8, 18, 18), rgb(48, 54, 50), "Metal", v(wx, wy, wz), v(0, 0, 90)))
	add(
		specs,
		part("WorkLampRim", "Cylinder", v(1, 19.6, 19.6), STRIPE_YELLOW, "Metal", v(wx, wy - 4, wz), v(0, 0, 90))
	)
	add(specs, {
		name = "WorkLampBulb",
		shape = "Cylinder",
		size = v(1, 12, 12),
		color = LAMP_WARM,
		material = "Neon",
		offset = v(wx, wy - 4.6, wz),
		rotation = v(0, 0, 90),
		light = {
			kind = "Spot",
			color = LAMP_WARM,
			brightness = 2.6,
			range = 60,
			angle = 80,
			face = "Left",
			shadows = true,
		},
	})
	-- 작업등 아래 떠도는 먼지 (코스 위가 아니라 옆)
	add(specs, {
		name = "LampDust",
		shape = "Block",
		size = v(24, 0.2, 12),
		color = LAMP_WARM,
		material = "SmoothPlastic",
		offset = v(0, 24, -38),
		transparency = 1,
		particle = "Sparkle",
		particleRate = 2,
	})
end

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
	workbench(specs)
	room(specs)
	pegboard(specs)
	windows(specs)
	shelves(specs)
	frontWall(specs)
	clampRack(specs)
	chefHand(specs)
	benchTools(specs)
	sawdustAndCrates(specs)
	safetyTape(specs)
	lamps(specs)
	return specs
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- ① 손이 블록을 뽑는 넓은 샷(탑 + 손 + 작업대 + 벽) → ② 작업대 높이에서 올려다보는 반전 샷 →
-- ③ 바깥 테두리 한 칸 클로즈업(옆) → ④ 가운데 안전지대(낮게, 가운데를 봐요). 전부 판정 경계 + 40 안.
function Art.introCamera(): { IntroPoint }
	local edge = (Layout.GRID_HALF + 0.5) * Layout.CELL_SIZE
	return {
		{ pos = v(-58, 38, 58), lookAt = v(-14, -10, -6) },
		{ pos = v(-62, -30, 30), lookAt = v(0, -2, -4) },
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
