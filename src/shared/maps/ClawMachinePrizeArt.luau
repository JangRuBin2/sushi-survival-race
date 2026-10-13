--!strict
-- "인형뽑기 기계 속" 아트 데이터 (m5-19, m4-02 공통 규칙). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 판정(칸 격자·집게 일정·상자 기울기)은 ClawMachinePrizeLogic/ClawMachinePrize 그대로이고, 여기는 장식만 있어요.
-- 좌표는 전부 map origin 기준 로컬이에요(가게·크레인·벽은). 칸 장식(tileDecor)만 그 칸 파츠 CFrame 기준 로컬이에요.
--   ClawMachinePrizeArt.decor() -> { DecorSpec }               유리벽 4면 + 천장, 크레인 레일(정적), 기계 외관, 오락실
--   ClawMachinePrizeArt.tileDecor(row, col) -> { DecorSpec }   칸 하나 위 저예산 인형 더미 2개(몸+머리)
--   ClawMachinePrizeArt.introCamera() -> { IntroPoint }        기계 앞 넓은 샷 → 천장 램프 아래 집게 → 올려다보기 → 출발 자리
--   ClawMachinePrizeArt.courseVolume() -> Bounds                장식이 가리면 안 되는 상자(칸 윗면 위, 천장 아래)
--   ClawMachinePrizeArt.NEON                                    PointLight를 붙일 네온 장식 파츠 이름 (build가 붙여요)
--   ClawMachinePrizeArt.BUDGET / LIGHTING                       m5-24: Extended 예산, 맵 조명 ("한밤 오락실 인형뽑기")
--
-- m5-24 아트 디렉션 (docs/specs/m5-24-map-art-pass-v2.md 그룹 C):
--   히어로 색 = 네온 자홍 + 청록. 60 = 어두운 오락실(짙은 보라·남색), 30 = 인형 더미 파스텔, 10 = 네온 간판·빨간 버튼.
--   층: FG = 유리 틀 금속 트림(유리 판은 그대로, 큰 반투명 판 추가 없음), MG = 기계 외관(빨간 몸체·기둥·머리 간판·
--       조작대·경품 출구)·옆 오락기 3대, BG = 오락실 카펫 바닥(−150, 낙하선 −25보다 한참 아래)·벽 네온 줄·경품 선반.
--   기계 몸통은 칸 격자 바로 아래를 비워 둬요(떨어지는 사람이 장식을 뚫고 지나가 보이지 않게) — 안쪽 경품 구덩이 바닥은
--   낙하선보다 10 이상 아래(−40).
--   움직임: 연장전에 ctx.model 전체(Decor 포함)가 PivotTo로 기울어요. MapDecorFxController의 Spin·Bob·Sway는 처음 본
--   CFrame을 기준으로 매 프레임 덮어써서 기운 상자와 어긋나므로, 이 맵은 CFrame을 안 건드리는 Pulse만 써요.
--   칸·인형·집게에는 anim이 없어요(칸 장식 tileDecor에도 없음).

local Layout = require(script.Parent.ClawMachinePrizeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Shape = MapKitLogic.Shape
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local ClawMachinePrizeArt = {}

ClawMachinePrizeArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
ClawMachinePrizeArt.NEON = "Neon"
ClawMachinePrizeArt.WALL_HEIGHT = 30 -- 유리 상자 벽 높이 (칸 윗면 변화폭 ±1보다 훨씬 커요)
ClawMachinePrizeArt.WALL_THICKNESS = 1
ClawMachinePrizeArt.RAIL_HEIGHT = ClawMachinePrizeArt.WALL_HEIGHT - 2 -- 천장 바로 아래 크레인 레일
ClawMachinePrizeArt.SIGHT_MIN = 2 -- 칸 윗면 변화폭(±1, m5-19 QA B3) 위, 시야를 가리면 안 되는 상자 바닥
ClawMachinePrizeArt.SIGHT_MAX = ClawMachinePrizeArt.RAIL_HEIGHT - 2 -- 레일 바로 아래까지

-- m5-24 배경 높이 (origin 로컬). 낙하선 −FALL_DEPTH(−25)
ClawMachinePrizeArt.FLOOR_Y = -150 -- 오락실 카펫
ClawMachinePrizeArt.PIT_Y = -40 -- 기계 안 경품 구덩이 바닥 (낙하선보다 15 아래)
ClawMachinePrizeArt.SHELL_TOP_Y = -4 -- 기계 몸통 윗면 (칸 윗면 −1~+1보다 3 이상 아래)

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- m5-24 맵 조명: 한밤 오락실 (ClockTime 0, 낮은 보라 Ambient, 네온 Bloom)
ClawMachinePrizeArt.LIGHTING = {
	ClockTime = 0,
	Brightness = 1,
	Ambient = c(84, 70, 118),
	OutdoorAmbient = c(70, 60, 110),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.9,
	ExposureCompensation = 0.45,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.05,
		Color = c(72, 52, 112),
		Decay = c(40, 30, 84),
		Glare = 0,
		Haze = 1.2,
	},
	ColorCorrection = { Brightness = 0.03, Contrast = 0.12, Saturation = 0.15, TintColor = c(250, 242, 255) },
	Bloom = { Intensity = 0.8, Size = 28, Threshold = 0.9 },
	SunRays = { Intensity = 0, Spread = 0.5 },
} :: MapLighting.LightingPreset

local GLASS: RGB = c(205, 232, 246)
local SILVER: RGB = c(196, 200, 208)
local RED_BUTTON: RGB = c(220, 50, 60)
local NEON_PINK: RGB = c(255, 110, 190)
local NEON_YELLOW: RGB = c(255, 220, 90)
local COIN_SLOT: RGB = c(90, 94, 104)
-- m5-24 색
local NEON_MAGENTA: RGB = c(255, 60, 200)
local NEON_TEAL: RGB = c(40, 230, 220)
local MACHINE_RED: RGB = c(196, 36, 72) -- 빨간 몸체 (자홍 쪽으로 — 경고 노랑과 다르게)
local MACHINE_RED_DARK: RGB = MapKitLogic.shade(MACHINE_RED, 0.68)
local MACHINE_RED_LIGHT: RGB = MapKitLogic.shade(MACHINE_RED, 1.14)
local CHROME: RGB = c(214, 218, 228)
local PIT: RGB = c(36, 28, 52)
local WALL: RGB = c(46, 34, 74) -- 짙은 보라 벽
local WALL_LOW: RGB = c(30, 26, 52)
local CARPET: RGB = c(34, 30, 66) -- 남색 카펫
local CABINET: { RGB } = { c(40, 46, 104), c(70, 36, 96), c(34, 70, 96) }
local SHELF_WOOD: RGB = c(96, 70, 60)

-- 저예산 인형 팔레트 (몸 색 6가지, 칸 index로 순환)
local PLUSH_PALETTE: { RGB } = {
	{ r = 250, g = 160, b = 170 }, -- 분홍
	{ r = 160, g = 210, b = 250 }, -- 하늘
	{ r = 250, g = 220, b = 130 }, -- 노랑
	{ r = 180, g = 230, b = 170 }, -- 연두
	{ r = 230, g = 180, b = 250 }, -- 라벤더
	{ r = 250, g = 190, b = 150 }, -- 살구
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

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, s in specs do
		table.insert(list, s)
	end
end

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로

local BOX = Layout.BOX_SIZE
local CZ = Layout.CENTER_Z
local WT = ClawMachinePrizeArt.WALL_THICKNESS
local WH = ClawMachinePrizeArt.WALL_HEIGHT
local SHELL = BOX / 2 + 7 -- 기계 몸통 바깥 반폭 (31)
local FLOOR = ClawMachinePrizeArt.FLOOR_Y

-- 유리벽 4면 + 천장. 전부 투명도 0.88 이상이라 시야를 거의 가리지 않아요. (m5-24: 그대로 — 더 큰 반투명 판 없음)
local function addGlassBox(list: { DecorSpec })
	local half = BOX / 2
	part(list, "GlassWallNorth", "Block", v(BOX, WH, WT), GLASS, "Glass", v(0, WH / 2, CZ - half), nil, 0.9)
	part(list, "GlassWallSouth", "Block", v(BOX, WH, WT), GLASS, "Glass", v(0, WH / 2, CZ + half), nil, 0.9)
	part(list, "GlassWallWest", "Block", v(WT, WH, BOX), GLASS, "Glass", v(-half, WH / 2, CZ), nil, 0.9)
	part(list, "GlassWallEast", "Block", v(WT, WH, BOX), GLASS, "Glass", v(half, WH / 2, CZ), nil, 0.9)
	part(list, "GlassCeiling", "Block", v(BOX, WT, BOX), GLASS, "Glass", v(0, WH, CZ), nil, 0.9)
end

-- FG: 유리 틀 금속 트림 (유리벽 바깥 아래·위 모서리 띠 — 상자 가장자리가 휴대폰에서도 읽히게)
local function addGlassTrim(list: { DecorSpec })
	local half = BOX / 2 + WT / 2 + 0.6
	for _, y in { -2.6, WH + 1.2 } do
		addAll(list, MapKitShapes.lipTrim("GlassTrim", v(BOX + 1, 0, BOX + 1), 1.2, 1.6, CHROME, "Metal", v(0, y, CZ)))
	end
	-- 바닥 쪽 네온 띠 (청록, 상자 둘레 — 칸 밖·아래)
	for _, side in { -1, 1 } do
		part(
			list,
			"BaseNeonStrip",
			"Block",
			v(BOX + 3, 0.6, 0.6),
			NEON_TEAL,
			"Neon",
			v(0, -3.4, CZ + side * (half + 1.4))
		)
		part(list, "BaseNeonStrip", "Block", v(0.6, 0.6, BOX + 3), NEON_TEAL, "Neon", v(side * (half + 1.4), -3.4, CZ))
	end
end

-- 크레인 레일(가로 1축 + 세로 1축 교차) + 받침 기둥. 전부 장식(충돌 없음) — 실제로 움직이는 집게
-- 발톱은 판정 쪽(ClawMachinePrize.luau)이 따로 모델로 만들어요.
local function addCrane(list: { DecorSpec })
	local y = ClawMachinePrizeArt.RAIL_HEIGHT
	-- 원기둥 축은 로컬 X. RailX는 회전 없이(축이 이미 X), RailZ는 Y로 90도 돌려 축을 Z로.
	add(list, {
		name = "RailX",
		shape = "Cylinder",
		size = v(BOX - 2, 1.4, 1.4),
		color = SILVER,
		material = "Metal",
		offset = v(0, y, CZ),
		reflectance = 0.3,
	})
	add(list, {
		name = "RailZ",
		shape = "Cylinder",
		size = v(BOX - 2, 1.4, 1.4),
		color = SILVER,
		material = "Metal",
		offset = v(0, y, CZ),
		rotation = v(0, 90, 0),
		reflectance = 0.3,
	})
	for _, side in { -1, 1 } do
		part(
			list,
			"RailPost",
			"Block",
			v(1.6, WH - y, 1.6),
			SILVER,
			"Metal",
			v(side * (BOX / 2 - 2), (WH + y) / 2, CZ - (BOX / 2 - 2))
		)
		part(
			list,
			"RailPost",
			"Block",
			v(1.6, WH - y, 1.6),
			SILVER,
			"Metal",
			v(side * (BOX / 2 - 2), (WH + y) / 2, CZ + (BOX / 2 - 2))
		)
		-- 레일 끝 받침 (작은 원판)
		part(list, "RailCap", "Cylinder", v(0.8, 2.4, 2.4), CHROME, "Metal", v(side * (BOX / 2 - 1.4), y, CZ))
		part(
			list,
			"RailCap",
			"Cylinder",
			v(0.8, 2.4, 2.4),
			CHROME,
			"Metal",
			v(0, y, CZ + side * (BOX / 2 - 1.4)),
			v(0, 90, 0)
		)
	end
	part(list, "RailHub", "Ball", v(2.6, 2.6, 2.6), SILVER, "Metal", v(0, y, CZ))
end

-- 천장 램프: 유리 천장 바로 아래 네 귀퉁이 LED 판 + 그림자 SpotLight 1개 (집게 그림자가 인형 더미에)
local function addCeilingLamps(list: { DecorSpec })
	local y = WH - WT / 2 - 0.35
	for k, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = corner[1] * 15, CZ + corner[2] * 15
		add(list, {
			name = "CeilingLamp",
			shape = "Block",
			size = v(8, 0.4, 3),
			color = c(255, 246, 236),
			material = "Neon",
			offset = v(x, y, z),
			light = if k == 4
				then {
					kind = "Spot",
					color = c(255, 240, 230),
					brightness = 3,
					range = 50,
					angle = 100,
					face = "Bottom",
					shadows = true,
				}
				else nil,
		})
	end
end

-- MG ① 기계 외관: 빨간 몸통(칸 아래는 비움) + 모서리 기둥 + 머리 간판 + 조작대 + 경품 출구
local function addMachine(list: { DecorSpec })
	local top = ClawMachinePrizeArt.SHELL_TOP_Y
	local half = BOX / 2
	local wall = SHELL - half - 0.6 -- 몸통 벽 두께 (칸 격자 바깥)
	local bodyH = top - FLOOR
	local midY = (top + FLOOR) / 2
	local inner = half + 0.6
	-- 몸통 벽 4면 (안쪽은 비어 있어요)
	for _, side in { -1, 1 } do
		addAll(
			list,
			MapKitShapes.roundedBox(
				"MachineBody",
				v(SHELL * 2, bodyH, wall),
				MACHINE_RED,
				"SmoothPlastic",
				v(0, midY, CZ + side * (inner + wall / 2)),
				{ style = "vertical", radius = 2 }
			)
		)
		addAll(
			list,
			MapKitShapes.roundedBox(
				"MachineBody",
				v(wall, bodyH, inner * 2),
				MACHINE_RED_DARK,
				"SmoothPlastic",
				v(side * (inner + wall / 2), midY, CZ),
				{ style = "vertical", radius = 1 }
			)
		)
	end
	-- 몸통 윗면 크롬 테두리 (윗면 −4: 칸 윗면보다 3 이상 아래, 색도 달라요)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"ShellTopTrim",
			v(SHELL * 2 - 2, 0, SHELL * 2 - 2),
			1,
			1,
			CHROME,
			"Metal",
			v(0, top + 0.5, CZ)
		)
	)
	-- 몸통 아래 받침 (검은 굽)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"MachinePlinth",
			v(SHELL * 2 + 4, 6, SHELL * 2 + 4),
			c(28, 24, 36),
			"SmoothPlastic",
			v(0, FLOOR + 3, CZ),
			1.5
		)
	)
	-- 옆면 장식 띠 (흰 줄 + 자홍 네온)
	for _, side in { -1, 1 } do
		part(
			list,
			"BodyStripe",
			"Block",
			v(0.4, 6, SHELL * 2 - 6),
			c(250, 236, 244),
			"SmoothPlastic",
			v(side * (SHELL + 0.2), -40, CZ)
		)
		part(
			list,
			"BodyNeon",
			"Block",
			v(0.4, 1, SHELL * 2 - 6),
			NEON_MAGENTA,
			"Neon",
			v(side * (SHELL + 0.3), -34, CZ)
		)
	end
	-- 안쪽 경품 구덩이 바닥 + 떨어진 인형 더미 (낙하선보다 10 이상 아래, 어둡게)
	part(list, "PitFloor", "Block", v(inner * 2, 2, inner * 2), PIT, "Fabric", v(0, ClawMachinePrizeArt.PIT_Y - 1, CZ))
	for k = 0, 11 do
		local a = k * 2.4
		local r = 6 + (k % 4) * 4.5
		local color = MapKitLogic.shade(PLUSH_PALETTE[k % #PLUSH_PALETTE + 1], 0.55)
		local x, z = math.cos(a) * r, CZ + math.sin(a) * r
		part(list, "PitPlush", "Ball", v(5, 4, 5), color, "Fabric", v(x, ClawMachinePrizeArt.PIT_Y + 2, z))
	end
	-- 모서리 기둥 4개 (유리벽 바깥, 몸통 위 → 머리 간판 아래)
	local postH = WH + 7 - top
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			addAll(
				list,
				MapKitShapes.roundedBox(
					"CornerPost",
					v(5, postH, 5),
					MACHINE_RED_LIGHT,
					"SmoothPlastic",
					v(sx * (half + 3.6), top + postH / 2, CZ + sz * (half + 3.6)),
					{ style = "vertical", radius = 1.4 }
				)
			)
			-- 기둥 안쪽 크롬 띠
			part(
				list,
				"CornerPostChrome",
				"Block",
				v(0.6, postH, 0.6),
				CHROME,
				"Metal",
				v(sx * (half + 1.3), top + postH / 2, CZ + sz * (half + 1.3))
			)
		end
	end
	-- 머리 간판 상자 (유리 천장 위)
	local headY = WH + 7 -- 유리 천장과 머리 간판 사이 틈 (천장 램프·집게가 보이게)
	local headH = 14
	addAll(
		list,
		MapKitShapes.roundedBox(
			"MachineHead",
			v(SHELL * 2, headH, SHELL * 2),
			MACHINE_RED,
			"SmoothPlastic",
			v(0, headY + headH / 2, CZ),
			{ radius = 2.5 }
		)
	)
	-- 앞(+Z)·옆 간판 네온: 자홍 테두리 + 청록 안쪽 줄 (앞 간판 하나에 build가 PointLight를 붙여요)
	local face = CZ + SHELL + 0.3
	part(
		list,
		"MarqueePanel",
		"Block",
		v(SHELL * 2 - 8, headH - 4, 0.4),
		c(30, 20, 44),
		"SmoothPlastic",
		v(0, headY + headH / 2, face)
	)
	addAll(
		list,
		MapKitShapes.lipTrim(
			"MarqueeNeonFrame",
			v(SHELL * 2 - 8, 0, headH - 4),
			0.8,
			0.5,
			NEON_MAGENTA,
			"Neon",
			v(0, headY + headH / 2, face + 0.2),
			v(90, 0, 0)
		)
	)
	part(
		list,
		ClawMachinePrizeArt.NEON,
		"Block",
		v(SHELL * 1.3, 2, 0.4),
		NEON_PINK,
		"Neon",
		v(0, headY + headH / 2 + 2, face + 0.3),
		nil,
		0.1
	)
	part(
		list,
		"MarqueeTrim",
		"Block",
		v(SHELL * 1.0, 1, 0.5),
		NEON_TEAL,
		"Neon",
		v(0, headY + headH / 2 - 2.4, face + 0.3),
		nil,
		0.1
	)
	-- 간판 별 4개 (노랑, 작게)
	for k = -2, 2 do
		if k ~= 0 then
			part(
				list,
				"MarqueeStar",
				"Ball",
				v(1.6, 1.6, 0.6),
				NEON_YELLOW,
				"Neon",
				v(k * 11, headY + headH / 2 - 0.2, face + 0.4)
			)
		end
	end
	-- 뒤(−Z) 간판: 같은 네온 띠 (eye·intro 뷰가 기계 안에서 볼 때도 간판이 보이게)
	local backFace = CZ - SHELL - 0.3
	part(
		list,
		"MarqueePanelBack",
		"Block",
		v(SHELL * 2 - 8, headH - 4, 0.4),
		c(30, 20, 44),
		"SmoothPlastic",
		v(0, headY + headH / 2, backFace)
	)
	part(
		list,
		"MarqueeBackNeon",
		"Block",
		v(SHELL * 1.3, 2, 0.4),
		NEON_TEAL,
		"Neon",
		v(0, headY + headH / 2, backFace - 0.3),
		nil,
		0.1
	)
	for _, side in { -1, 1 } do
		part(
			list,
			"HeadSideNeon",
			"Block",
			v(0.4, 1, SHELL * 2 - 6),
			NEON_TEAL,
			"Neon",
			v(side * (SHELL + 0.3), headY + headH / 2, CZ)
		)
	end
	-- 머리 꼭대기 둥근 지붕 띠 + 경광등 같은 공 (자홍, Pulse)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"MachineCrown",
			v(SHELL * 2 - 6, 3, SHELL * 2 - 6),
			MACHINE_RED_DARK,
			"SmoothPlastic",
			v(0, headY + headH + 1.5, CZ),
			1.4
		)
	)
	add(list, {
		name = "CrownBulb",
		shape = "Ball",
		size = v(6, 6, 6),
		color = NEON_MAGENTA,
		material = "Neon",
		offset = v(0, headY + headH + 5, CZ),
		light = { kind = "Point", color = NEON_MAGENTA, brightness = 1.6, range = 40 },
		anim = { kind = "Pulse", period = 1.6, amount = 0.12 },
	})

	-- 조작대 (앞 +Z, 유리 아래): 비스듬한 판 + 조이스틱 + 빨간 버튼 + 동전 투입구
	local deckZ = CZ + SHELL + 5
	local deckY = top - 8
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ControlDeck",
			v(SHELL * 2 - 4, 8, 10),
			MACHINE_RED_DARK,
			"SmoothPlastic",
			v(0, deckY, deckZ),
			{ radius = 1.6 }
		)
	)
	part(
		list,
		"ControlDeckTop",
		"Block",
		v(SHELL * 2 - 8, 0.4, 8.5),
		c(26, 22, 40),
		"SmoothPlastic",
		v(0, deckY + 4.1, deckZ),
		v(-8, 0, 0)
	)
	-- 조이스틱 (받침 원판 + 막대 + 빨간 공)
	part(list, "JoystickBase", "Cylinder", v(1, 5, 5), CHROME, "Metal", v(-12, deckY + 4.6, deckZ), UPRIGHT)
	part(list, "JoystickStick", "Cylinder", v(5, 0.9, 0.9), c(40, 40, 46), "Metal", v(-12, deckY + 7.4, deckZ), UPRIGHT)
	part(list, "JoystickKnob", "Ball", v(3, 3, 3), RED_BUTTON, "SmoothPlastic", v(-12, deckY + 10.4, deckZ))
	-- 빨간 버튼 (큰 것) + 크롬 테두리
	part(list, "GrabButtonRim", "Cylinder", v(0.8, 6, 6), CHROME, "Metal", v(10, deckY + 4.4, deckZ), UPRIGHT)
	part(
		list,
		"GrabButton",
		"Cylinder",
		v(1.6, 4.6, 4.6),
		RED_BUTTON,
		"SmoothPlastic",
		v(10, deckY + 5, deckZ),
		UPRIGHT
	)
	-- 동전 투입구 (앞면, 청록 LED Pulse)
	part(list, "CoinPlate", "Block", v(8, 9, 0.6), CHROME, "Metal", v(-18, deckY - 12, deckZ - 4.7))
	part(list, "CoinSlot", "Block", v(1, 4, 0.6), COIN_SLOT, "Metal", v(-18, deckY - 11, deckZ - 4.3))
	add(list, {
		name = "CoinLed",
		shape = "Block",
		size = v(5, 0.8, 0.4),
		color = NEON_TEAL,
		material = "Neon",
		offset = v(-18, deckY - 7.6, deckZ - 4.3),
		anim = { kind = "Pulse", period = 2.2, amount = 0.1 },
	})
	-- 경품 출구 (앞 오른쪽 아래): 상자 + 어두운 입 + 플랩 + 위 "PRIZE" 네온 띠 + 색종이
	local exitX, exitY = 16, FLOOR + 26
	addAll(
		list,
		MapKitShapes.roundedBox(
			"PrizeChute",
			v(16, 18, 6),
			MACHINE_RED_LIGHT,
			"SmoothPlastic",
			v(exitX, exitY, deckZ - 3),
			{ radius = 1.6 }
		)
	)
	part(
		list,
		"PrizeChuteMouth",
		"Block",
		v(12, 10, 0.6),
		c(18, 14, 26),
		"SmoothPlastic",
		v(exitX, exitY - 2, deckZ + 0.1)
	)
	part(
		list,
		"PrizeFlap",
		"Block",
		v(12, 5, 0.4),
		c(60, 60, 70),
		"Plastic",
		v(exitX, exitY + 0.6, deckZ + 0.5),
		v(-15, 0, 0)
	)
	add(list, {
		name = "PrizeSign",
		shape = "Block",
		size = v(12, 2, 0.4),
		color = NEON_YELLOW,
		material = "Neon",
		offset = v(exitX, exitY + 6.5, deckZ + 0.3),
		light = { kind = "Point", color = NEON_YELLOW, brightness = 1, range = 24 },
		anim = { kind = "Pulse", period = 1.2, amount = 0.08 },
	})
	add(list, {
		name = "PrizeConfetti",
		shape = "Block",
		size = v(10, 0.2, 4),
		color = NEON_YELLOW,
		material = "SmoothPlastic",
		offset = v(exitX, exitY + 2, deckZ + 2),
		transparency = 1,
		particle = "Confetti",
		particleRate = 1.5,
	})
	-- 출구에서 나온 인형 하나 (바닥 위)
	part(
		list,
		"PrizePlush",
		"Block",
		v(7, 5, 6),
		PLUSH_PALETTE[1],
		"Fabric",
		v(exitX + 2, FLOOR + 2.5, deckZ + 10),
		v(0, 20, 0)
	)
	part(list, "PrizePlushHead", "Ball", v(6, 6, 6), PLUSH_PALETTE[1], "Fabric", v(exitX + 2, FLOOR + 8, deckZ + 10))
	for _, side in { -1, 1 } do
		part(
			list,
			"PrizePlushEar",
			"Ball",
			v(2, 2.6, 1.4),
			PLUSH_PALETTE[1],
			"Fabric",
			v(exitX + 2 + side * 2.2, FLOOR + 11, deckZ + 10)
		)
		part(
			list,
			"PrizePlushEye",
			"Ball",
			v(0.9, 0.9, 0.9),
			c(30, 26, 34),
			"SmoothPlastic",
			v(exitX + 2 + side * 1.2, FLOOR + 8.6, deckZ + 12.9)
		)
	end
	-- 몸통 앞면 큰 스티커 패널 (흰 원 + 청록 하트 모양 공 두 개 + 쐐기)
	addAll(
		list,
		MapKitShapes.rimDisc(
			"BodyBadge",
			22,
			0.6,
			c(250, 236, 244),
			"SmoothPlastic",
			v(-10, -60, CZ + SHELL + 0.4),
			{ rimColor = NEON_TEAL, rimWidth = 1.2, rimHeight = 0.4, segments = 16, rotation = v(90, 0, 0) }
		)
	)
	for _, side in { -1, 1 } do
		part(
			list,
			"BadgeHeart",
			"Ball",
			v(6, 6, 1),
			NEON_MAGENTA,
			"SmoothPlastic",
			v(-10 + side * 2.4, -57.6, CZ + SHELL + 1.2)
		)
	end
	part(
		list,
		"BadgeHeart",
		"Wedge",
		v(1, 6.6, 6.6),
		NEON_MAGENTA,
		"SmoothPlastic",
		v(-10, -61.4, CZ + SHELL + 1.2),
		v(45, 90, 0)
	)
end

-- BG ① 오락실 바닥 카펫 + 무늬 (짙은 남색 위 작은 청록·자홍·노랑 모양)
local function addFloor(list: { DecorSpec })
	local cx, cz = 0, -40
	for k, at in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(
			list,
			"ArcadeCarpet",
			"Block",
			v(239, 4, 259),
			if k % 2 == 0 then CARPET else MapKitLogic.shade(CARPET, 1.08),
			"Carpet",
			v(cx + at[1] * 120, FLOOR - 2, cz + at[2] * 130)
		)
	end
	local rng = MapKitShapes.rng(1919)
	local colors = { NEON_TEAL, NEON_MAGENTA, NEON_YELLOW }
	for k = 1, 48 do
		local x = rng:range(-220, 220)
		local z = rng:range(-290, 210)
		if math.abs(x) < SHELL + 12 and math.abs(z - CZ) < SHELL + 22 then
			continue
		end
		local color = MapKitLogic.shade(colors[k % 3 + 1], 0.75)
		if k % 2 == 0 then
			part(list, "CarpetDot", "Cylinder", v(0.2, 7, 7), color, "SmoothPlastic", v(x, FLOOR + 0.1, z), UPRIGHT)
		else
			part(
				list,
				"CarpetZig",
				"Block",
				v(10, 0.2, 2),
				color,
				"SmoothPlastic",
				v(x, FLOOR + 0.1, z),
				v(0, rng:range(0, 180), 0)
			)
		end
	end
end

-- BG ② 벽 4면 (징두리 + 짙은 보라 벽 + 네온 띠 2줄)
local function addWalls(list: { DecorSpec })
	local hx, back, front = 240, -300, 220
	local h = 320
	local topY = FLOOR + h
	local walls = {
		{ size = v(hx * 2, 0, 6), at = v(0, 0, back) },
		{ size = v(hx * 2, 0, 6), at = v(0, 0, front) },
		{ size = v(6, 0, front - back), at = v(-hx, 0, (back + front) / 2) },
		{ size = v(6, 0, front - back), at = v(hx, 0, (back + front) / 2) },
	}
	for k, w in walls do
		part(
			list,
			"ArcadeWall",
			"Block",
			v(w.size.x, h - 60, w.size.z),
			WALL,
			"Plaster",
			v(w.at.x, FLOOR + 60 + (h - 60) / 2, w.at.z)
		)
		part(
			list,
			"ArcadeWainscot",
			"Block",
			v(w.size.x + 2, 60, w.size.z + 2),
			WALL_LOW,
			"WoodPlanks",
			v(w.at.x, FLOOR + 30, w.at.z)
		)
		-- 네온 띠 (벽마다 한 줄 청록 + 한 줄 자홍, 빛은 앞·뒤 벽 한 줄씩만)
		local along = if w.size.x > w.size.z then v(w.size.x - 20, 1.2, 1.2) else v(1.2, 1.2, w.size.z - 20)
		local inward = if w.size.x > w.size.z
			then v(0, 0, if w.at.z < 0 then 4 else -4)
			else v(if w.at.x < 0 then 4 else -4, 0, 0)
		add(list, {
			name = "WallNeonTeal",
			shape = "Block",
			size = along,
			color = NEON_TEAL,
			material = "Neon",
			offset = v(w.at.x + inward.x, FLOOR + 66, w.at.z + inward.z),
		})
		add(list, {
			name = "WallNeonMagenta",
			shape = "Block",
			size = along,
			color = NEON_MAGENTA,
			material = "Neon",
			offset = v(w.at.x + inward.x, FLOOR + 180, w.at.z + inward.z),
			light = if k <= 2 then { kind = "Point", color = NEON_MAGENTA, brightness = 1.2, range = 60 } else nil,
		})
	end
	-- 천장 트러스 (보만, 판 없음 — 위에서 보는 카메라가 막히지 않게)
	for k = -2, 2 do
		part(list, "CeilingTruss", "Block", v(hx * 2, 8, 6), c(26, 22, 40), "Metal", v(0, topY - 4, -40 + k * 100))
	end
end

-- MG ② 옆 오락기 3대 (몸체 + Neon 화면 Pulse + 간판 + 조작대 버튼)
local function addArcadeCabinet(list: { DecorSpec }, x: number, z: number, yaw: number, tone: number, screen: RGB)
	local body = CABINET[tone]
	local specs: { DecorSpec } = {}
	addAll(
		specs,
		MapKitShapes.roundedBox(
			"ArcadeCabinet",
			v(50, 170, 46),
			body,
			"SmoothPlastic",
			v(0, 85, 0),
			{ style = "vertical", radius = 3 }
		)
	)
	-- 옆면 네온 줄
	for _, side in { -1, 1 } do
		add(specs, {
			name = "CabinetSideNeon",
			shape = "Block",
			size = v(0.6, 150, 1),
			color = screen,
			material = "Neon",
			offset = v(side * 25.3, 85, -22),
		})
	end
	-- 화면 (앞 −Z쪽, 비스듬히) + 베젤
	add(specs, {
		name = "CabinetBezel",
		shape = "Block",
		size = v(42, 34, 1),
		color = c(16, 14, 22),
		material = "SmoothPlastic",
		offset = v(0, 118, -23.2),
		rotation = v(-10, 0, 0),
	})
	add(specs, {
		name = "CabinetScreen",
		shape = "Block",
		size = v(36, 28, 0.6),
		color = screen,
		material = "Neon",
		offset = v(0, 118, -23.9),
		rotation = v(-10, 0, 0),
		light = { kind = "Point", color = screen, brightness = 1.3, range = 45 },
		anim = { kind = "Pulse", period = 2.6 + tone * 0.5, amount = 0.04 },
	})
	-- 화면 속 픽셀 무늬 (밝은 블록 몇 개)
	for k = 0, 3 do
		add(specs, {
			name = "ScreenPixel",
			shape = "Block",
			size = v(4, 4, 0.4),
			color = MapKitLogic.shade(screen, 1.5),
			material = "Neon",
			offset = v(-12 + k * 8, 112 + (k % 2) * 8, -24.3),
			rotation = v(-10, 0, 0),
		})
	end
	-- 간판 (위)
	add(specs, {
		name = "CabinetMarquee",
		shape = "Block",
		size = v(46, 14, 2),
		color = MapKitLogic.shade(screen, 0.9),
		material = "Neon",
		offset = v(0, 158, -23.5),
		transparency = 0.15,
	})
	-- 조작대 (쐐기) + 버튼 3개
	add(specs, {
		name = "CabinetDeck",
		shape = "Wedge",
		size = v(50, 12, 18),
		color = MapKitLogic.shade(body, 0.8),
		material = "SmoothPlastic",
		offset = v(0, 90, -31),
		rotation = v(0, 180, 0),
	})
	for k = -1, 1 do
		add(specs, {
			name = "CabinetButton",
			shape = "Cylinder",
			size = v(1.2, 4, 4),
			color = if k == 0 then NEON_YELLOW else MapKitLogic.shade(screen, 1.2),
			material = "SmoothPlastic",
			offset = v(k * 9, 95.5, -30),
			rotation = v(0, 0, 90 - 34),
		})
	end
	addAll(list, MapKitShapes.transform(specs, v(x, FLOOR, z), v(0, yaw, 0)))
end

-- BG ③ 뒤 벽 경품 선반 (선반 3단 + 인형 줄)
local function addPrizeShelf(list: { DecorSpec })
	local z = -292
	local cx = 60
	addAll(
		list,
		MapKitShapes.roundedBox(
			"PrizeShelfBack",
			v(140, 130, 6),
			SHELF_WOOD,
			"Wood",
			v(cx, FLOOR + 85, z),
			{ radius = 1.5 }
		)
	)
	for k = 0, 2 do
		local y = FLOOR + 36 + k * 40
		part(
			list,
			"PrizeShelfBoard",
			"Block",
			v(140, 3, 18),
			MapKitLogic.shade(SHELF_WOOD, 1.15),
			"Wood",
			v(cx, y, z + 9)
		)
		part(
			list,
			"PrizeShelfNeon",
			"Block",
			v(136, 0.6, 0.6),
			if k % 2 == 0 then NEON_TEAL else NEON_MAGENTA,
			"Neon",
			v(cx, y - 1.6, z + 18)
		)
		for n = 0, 6 do
			local color = PLUSH_PALETTE[(n + k * 2) % #PLUSH_PALETTE + 1]
			local x = cx - 54 + n * 18
			local s = 1 + ((n + k) % 3) * 0.12
			part(list, "ShelfPlush", "Block", v(9 * s, 8 * s, 8 * s), color, "Fabric", v(x, y + 1.5 + 4 * s, z + 9))
			part(list, "ShelfPlushHead", "Ball", v(9 * s, 9 * s, 9 * s), color, "Fabric", v(x, y + 1.5 + 12 * s, z + 9))
		end
	end
end

-- BG ④ 천장 네온 간판 (앞쪽 벽 위, 자홍 고리 + 청록 별 막대) + 미러볼 (Spin 대신 반짝임 — 연장전 기울기와 안 싸우게)
local function addNeonSign(list: { DecorSpec })
	local sx, sy, sz = 0, 60, 205
	addAll(list, MapKitShapes.ring("NeonSignRing", 24, 1.6, 1.6, 20, NEON_MAGENTA, "Neon", v(sx, sy, sz), v(90, 0, 0)))
	part(list, "NeonSignBack", "Cylinder", v(1, 52, 52), c(24, 18, 36), "SmoothPlastic", v(sx, sy, sz + 2), v(0, 90, 0))
	for k = 0, 3 do
		part(list, "NeonSignStar", "Block", v(30, 1.6, 1.6), NEON_TEAL, "Neon", v(sx, sy, sz - 1), v(0, 0, k * 45))
	end
	add(list, {
		name = "NeonSignCore",
		shape = "Ball",
		size = v(8, 8, 3),
		color = NEON_YELLOW,
		material = "Neon",
		offset = v(sx, sy, sz - 1.5),
		light = { kind = "Point", color = NEON_MAGENTA, brightness = 1.5, range = 60 },
		particle = "Sparkle",
		particleRate = 3,
		anim = { kind = "Pulse", period = 1.8, amount = 0.12 },
	})
	-- 미러볼 (천장 줄에 매달림)
	local bx, by, bz = 90, 70, -120
	part(list, "MirrorBallCord", "Block", v(0.6, 34, 0.6), c(60, 60, 70), "Metal", v(bx, by + 25, bz))
	add(list, {
		name = "MirrorBall",
		shape = "Ball",
		size = v(16, 16, 16),
		color = CHROME,
		material = "Foil",
		offset = v(bx, by, bz),
		reflectance = 0.6,
		particle = "Sparkle",
		particleRate = 4,
	})
	-- 공중 먼지 (조명 속)
	add(list, {
		name = "ArcadeDust",
		shape = "Block",
		size = v(60, 0.2, 60),
		color = CHROME,
		material = "SmoothPlastic",
		offset = v(40, 70, 40),
		transparency = 1,
		particle = "Dust",
		particleRate = 3,
	})
end

-- MG ③ 오락실 소품: 동전 교환기·쓰레기통·의자 (무리로)
local function addProps(list: { DecorSpec })
	-- 동전 교환기 (오른쪽 앞)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ChangeMachine",
			v(30, 110, 24),
			c(196, 200, 210),
			"Metal",
			v(120, FLOOR + 55, 110),
			{ style = "vertical", radius = 2 }
		)
	)
	part(list, "ChangeMachinePanel", "Block", v(22, 30, 0.6), c(30, 30, 40), "SmoothPlastic", v(120, FLOOR + 80, 97.8))
	add(list, {
		name = "ChangeMachineLed",
		shape = "Block",
		size = v(16, 4, 0.4),
		color = NEON_TEAL,
		material = "Neon",
		offset = v(120, FLOOR + 88, 97.4),
	})
	-- 둥근 의자 3개 (높이·색 다르게)
	for k, at in { { -70, 70 }, { -48, 84 }, { 60, 140 } } do
		local h = 44 + k * 4
		part(list, "StoolLeg", "Cylinder", v(h, 3, 3), CHROME, "Metal", v(at[1], FLOOR + h / 2, at[2]), UPRIGHT)
		addAll(
			list,
			MapKitShapes.rimDisc(
				"StoolSeat",
				16,
				4,
				if k == 2 then NEON_MAGENTA else MACHINE_RED,
				"Leather",
				v(at[1], FLOOR + h + 2, at[2]),
				{ rimColor = MACHINE_RED_DARK, rimWidth = 1, rimHeight = 1, segments = 10 }
			)
		)
		part(list, "StoolBase", "Cylinder", v(1.5, 14, 14), CHROME, "Metal", v(at[1], FLOOR + 0.8, at[2]), UPRIGHT)
	end
	-- 쓰레기통 + 버려진 경품 봉투
	addAll(
		list,
		MapKitShapes.rimDisc(
			"TrashCan",
			22,
			40,
			c(60, 64, 80),
			"Metal",
			v(-130, FLOOR + 20, 120),
			{ rimColor = CHROME, rimWidth = 1.2, rimHeight = 1.5, segments = 12 }
		)
	)
	part(list, "PrizeBag", "Block", v(14, 18, 10), c(240, 236, 250), "Plastic", v(-104, FLOOR + 9, 128), v(0, 30, 6))
end

function ClawMachinePrizeArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addGlassBox(list)
	addGlassTrim(list)
	addCrane(list)
	addCeilingLamps(list)
	addMachine(list)
	addFloor(list)
	addWalls(list)
	addArcadeCabinet(list, -130, -60, -90, 1, NEON_TEAL)
	addArcadeCabinet(list, -60, -230, 180, 2, NEON_MAGENTA)
	addArcadeCabinet(list, 130, -110, 90, 3, c(110, 160, 255))
	addArcadeCabinet(list, 70, 150, 0, 1, NEON_MAGENTA)
	addPrizeShelf(list)
	addNeonSign(list)
	addProps(list)
	return list
end

-- 칸(row, col) 위 저예산 인형 더미 2개(몸 Block + 머리 Ball). 칸 파츠 CFrame 기준 로컬 오프셋이라
-- MapKit.buildDecor(…, tilePart.CFrame, tilePart)로 칸 파츠 아래 자식으로 넣으면 칸이 사라질 때 같이 사라져요.
-- (판정 칸과 같이 움직이므로 anim 없음 — m5-24 절대 규칙)
function ClawMachinePrizeArt.tileDecor(row: number, col: number): { DecorSpec }
	local list: { DecorSpec } = {}
	local index = (Layout.tileIndex(row, col) or 0)
	local topY = Layout.THICKNESS / 2
	for i, corner in { { -1, -1 }, { 1, 1 } } do
		local color = PLUSH_PALETTE[(index + i) % #PLUSH_PALETTE + 1]
		local dx, dz = corner[1] * 1.3, corner[2] * 1.3
		part(list, "Plush", "Block", v(2.2, 1.5, 2.2), color, "Fabric", v(dx, topY + 0.75, dz))
		part(list, "PlushHead", "Ball", v(1.5, 1.5, 1.5), color, "Fabric", v(dx, topY + 1.9, dz))
	end
	return list
end

-- ① 기계 앞 넓은 샷(기계 외관 + 간판 + 오락실) → ② 천장 램프 아래에서 집게·인형 더미 내려다보기 →
-- ③ 인형 더미 높이에서 집게·레일 올려다보기(반전) → ④ 출발 자리(격자 가운데, 낮은 각도). 전부 판정 경계 + 40 안.
function ClawMachinePrizeArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-40, 20, 20), lookAt = v(0, 2, CZ) },
		{ pos = v(6, 26, CZ - 18), lookAt = v(0, 8, CZ) },
		{ pos = v(18, 6, CZ + 18), lookAt = v(-2, 16, CZ - 4) },
		{ pos = v(0, 5, CZ + 14), lookAt = v(0, 0, CZ) },
	}
end

-- 장식이 들어가면 안 되는 상자: 칸 윗면 변화폭 위(SIGHT_MIN)부터 레일 바로 아래(SIGHT_MAX)까지, 격자 안쪽.
function ClawMachinePrizeArt.courseVolume(): Bounds
	local half = BOX / 2 - 0.5
	return {
		min = v(-half, ClawMachinePrizeArt.SIGHT_MIN, CZ - half),
		max = v(half, ClawMachinePrizeArt.SIGHT_MAX, CZ + half),
	}
end

return ClawMachinePrizeArt
