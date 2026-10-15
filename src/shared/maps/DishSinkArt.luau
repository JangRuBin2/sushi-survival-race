--!strict
-- "깨끗하게! 설거지통"(dish-sink, m5-34) 장식 데이터. Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 아트 디렉션: "한낮 업소용 주방, 햇살 드는 스테인리스 개수대" (스펙 아트 절, REFERENCE-map-art-direction 필수).
--   Art.decor() -> { DecorSpec }           장식 전체 (충돌·쿼리·터치 없음 — MapKit.buildDecor)
--   Art.spongeSpecs(sponge) -> { DecorSpec } 수세미 하나의 파츠 (수세미 중심 기준). 서버가 통째로 옮겨서 anim 금지
--   Art.SPONGE_BODY                        수세미 몸통 파츠 이름 (서버가 태그·번호를 달아요)
--   Art.courseVolume() -> { Bounds }       장식이 들어가면 안 되는 코스 시야 상자 (밟는 면 위 2~12)
--   Art.introCamera() -> { IntroPoint }    라운드 소개 경유점 5개 (origin 로컬)
--   Art.BUDGET / LIGHTING / JUDGE_COLORS   Extended 예산, 맵 조명, 판정 파츠 색
--   Art.SINK_FLOOR_Y                       개수대 바닥 (가장 깊은 배경 바닥, 낙하선보다 10 이상 아래)
-- 층: FG 접시 파란 테·회전 무늬 링, 칸막이 트림, 거품 무리 / MG 수도꼭지·거름망·접시 탑·세제통·고무장갑·건조대 /
--     BG 개수대 벽·조리대·타일 벽·창문(햇살)·선반·주방 바닥.
-- 접시 회전 무늬(PlateSpin)는 판정 접시와 따로 둔 고정 장식이라 anim(Spin)을 달아도 돼요 (판정 파츠는 움직이지 않아요).

local Layout = require(script.Parent.DishSinkLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local DishSinkArt = {}

DishSinkArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier
DishSinkArt.SPONGE_BODY = "SpongeBody"

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- ── 치수 ────────────────────────────────────────────────────────────
DishSinkArt.SINK_X = 32 -- 개수대 안쪽 벽 (x ±)
DishSinkArt.SINK_WALL = 4
DishSinkArt.RIM_Y = 14 -- 조리대 윗면 = 개수대 테두리
DishSinkArt.SINK_FLOOR_Y = -24 -- 개수대 바닥 (B 낙하선 -12보다 12 아래)
DishSinkArt.SINK_BACK_Z = 30 -- 출발 뒤 개수대 끝 벽 안쪽 면
DishSinkArt.SINK_END_Z = -462 -- 건조대 너머 개수대 끝 벽 안쪽 면
DishSinkArt.DIVIDER_Z = -256.5 -- 두 개수대 칸 사이 칸막이 (D 끝 ~ E 첫 접시 사이)
DishSinkArt.KITCHEN_FLOOR_Y = -76 -- 주방 바닥 (조리대 높이 90)
DishSinkArt.LEFT_WALL_X = -124 -- 왼쪽 타일 벽 (선반·수건)
DishSinkArt.RIGHT_COUNTER_X = 124 -- 오른쪽 조리대 끝 (서랍장 면)
DishSinkArt.BACK_WALL_Z = -486 -- 결승 너머 창문 벽
DishSinkArt.RIGHT_WALL_X = 330

-- ── 색 (60 스테인리스 회색-하늘 / 30 흰 도자기 + 파란 테 / 10 수세미 노랑·연두, 세제 주황, 장갑 분홍) ──────
local STEEL = MapKitLogic.shades(c(158, 172, 188))
local STEEL_DARK = MapKitLogic.shades(c(120, 132, 146))
local CHROME = c(214, 224, 234)
local WATER = c(96, 188, 204)
local PORCELAIN = c(244, 246, 250)
local BLUE_RIM = c(52, 102, 186)
local BLUE_LIGHT = c(120, 168, 230)
local SPONGE_YELLOW = c(242, 210, 60)
local SPONGE_GREEN = c(155, 203, 78)
local SPONGE_GREEN_DARK = c(86, 140, 40)
local DETERGENT = c(236, 132, 56)
local GLOVE = c(224, 150, 170) -- 채도 낮은 분홍 (위험 색 아님)
local TILE = MapKitLogic.shades(c(206, 220, 230))
local GROUT = c(176, 190, 202)
local WOOD = MapKitLogic.shades(c(196, 156, 108))
local FLOOR_TILE = MapKitLogic.shades(c(176, 158, 138))
local SUN = c(255, 222, 170)
local FOAM = c(246, 250, 255)
local STAIN = c(150, 104, 66)
local MUTED_YELLOW = c(222, 206, 120) -- 장식 수세미 (위험 수세미보다 채도 낮게)

-- 판정 파츠 색 (DishSink.build가 써요). 밟는 곳이 장식보다 밝고 깨끗하게.
DishSinkArt.JUDGE_COLORS = {
	counter = c(238, 234, 226), -- 출발 조리대 끝 (밝은 돌)
	steelTop = c(226, 232, 240), -- 칸막이·다리·복도 윗면 (가장 밝은 스테인리스)
	plate = c(252, 252, 254), -- 접시 밟는 면 (무늬 없는 흰색)
	cupA = c(206, 236, 224), -- 민트 컵
	cupB = c(248, 236, 212), -- 크림 밥공기
	rack = c(244, 246, 250), -- 건조대 (흰 플라스틱)
}

type Extra = {
	reflectance: number?,
	transparency: number?,
	castShadow: boolean?,
	light: MapKitLogic.LightSpec?,
	particle: string?,
	particleRate: number?,
	anim: MapKitLogic.AnimSpec?,
}

local function put(
	list: { DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?,
	extra: Extra?
)
	local s: DecorSpec = {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
	if extra then
		s.reflectance = extra.reflectance
		s.transparency = extra.transparency
		s.castShadow = extra.castShadow
		s.light = extra.light
		s.particle = extra.particle
		s.particleRate = extra.particleRate
		s.anim = extra.anim
	end
	table.insert(list, s)
end

local function append(list: { DecorSpec }, more: { DecorSpec }, extra: Extra?)
	for _, s in more do
		if extra then
			if extra.reflectance then
				s.reflectance = extra.reflectance
			end
			if extra.transparency then
				s.transparency = extra.transparency
			end
			if extra.castShadow ~= nil then
				s.castShadow = extra.castShadow
			end
		end
		table.insert(list, s)
	end
end

local UP = v(0, 0, 90) -- 원기둥 축(X)을 세워요
local FLIP_UP = v(180, 0, 90) -- 세운 원기둥을 뒤집어요 (Spin 방향이 반대가 돼요)

-- 세운 원판·원기둥 (중심 x, y, z, 높이 h, 지름 d)
local function disc(
	list: { DecorSpec },
	name: string,
	x: number,
	y: number,
	z: number,
	h: number,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	put(list, name, "Cylinder", v(h, d, d), color, material, v(x, y, z), UP, extra)
end

-- 바닥 y0에서 높이 h로 솟은 기둥
local function column(
	list: { DecorSpec },
	name: string,
	x: number,
	y0: number,
	z: number,
	h: number,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	disc(list, name, x, y0 + h / 2, z, h, d, color, material, extra)
end

-- 두 점 사이 원기둥 (파이프·막대). 축 = 로컬 X를 a→b로 돌려요.
local function rod(
	list: { DecorSpec },
	name: string,
	a: Vec3,
	b: Vec3,
	d: number,
	color: RGB,
	material: string,
	extra: Extra?
)
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local yaw = math.deg(math.atan2(-dz, dx)) -- Ry: X → (cos, 0, -sin)
	local horiz = math.sqrt(dx * dx + dz * dz)
	local pitch = math.deg(math.atan2(dy, horiz)) -- Rz: X를 위로
	put(
		list,
		name,
		"Cylinder",
		v(len, d, d),
		color,
		material,
		v((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2),
		v(0, yaw, pitch),
		extra
	)
end

----------------------------------------------------------------------------------------------------
-- 수세미 (판정 쪽 물체 — 서버가 통째로 옮겨요. anim 금지)
----------------------------------------------------------------------------------------------------
function DishSinkArt.spongeSpecs(sponge: Layout.Sponge): { DecorSpec }
	local list: { DecorSpec } = {}
	local sx, sy, sz = sponge.sizeX, sponge.sizeY, sponge.sizeZ
	local scrub = 1.6
	local bodyH = sy - scrub
	-- 노란 스펀지 몸통 (오돌토돌 Sand)
	put(list, DishSinkArt.SPONGE_BODY, "Block", v(sx, bodyH, sz), SPONGE_YELLOW, "Sand", v(0, -scrub / 2, 0))
	-- 연두 수세미 면 (위)
	put(list, "SpongeScrub", "Block", v(sx - 0.4, scrub, sz - 0.4), SPONGE_GREEN, "Fabric", v(0, sy / 2 - scrub / 2, 0))
	-- 진한 연두 테두리 (수세미 면과 몸통 사이 띠)
	append(
		list,
		MapKitShapes.lipTrim(
			"SpongeEdge",
			v(sx - 0.4, 0, sz - 0.4),
			0.35,
			0.5,
			SPONGE_GREEN_DARK,
			"Fabric",
			v(0, sy / 2 - scrub, 0)
		)
	)
	-- 옆면 구멍(기공) 몇 개
	local pores = { { -0.3, -0.25 }, { 0.15, 0.1 }, { 0.32, -0.3 } }
	for _, p in pores do
		put(
			list,
			"SpongePore",
			"Ball",
			v(0.9, 0.7, 0.4),
			c(214, 176, 40),
			"Sand",
			v(p[1] * sx, p[2] * bodyH - scrub / 2, sz / 2)
		)
		put(
			list,
			"SpongePore",
			"Ball",
			v(0.9, 0.7, 0.4),
			c(214, 176, 40),
			"Sand",
			v(-p[1] * sx, p[2] * bodyH - scrub / 2, -sz / 2)
		)
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- 맵 조명: 오전 10:30 햇살, 차가운 높은 Ambient, 흰-하늘 안개 (로비 14시 중립과 분명히 달라요)
----------------------------------------------------------------------------------------------------
DishSinkArt.LIGHTING = {
	ClockTime = 10.5,
	Brightness = 1.9,
	Ambient = c(170, 190, 210),
	OutdoorAmbient = c(184, 202, 220),
	EnvironmentDiffuseScale = 0.7,
	EnvironmentSpecularScale = 1,
	ShadowSoftness = 0.3,
	Atmosphere = {
		Density = 0.25,
		Offset = 0.05,
		Color = c(218, 232, 244),
		Decay = c(176, 202, 228),
		Glare = 0,
		Haze = 1,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.15,
		Saturation = 0.08,
		TintColor = c(250, 252, 255),
	},
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.05 },
	SunRays = { Intensity = 0.05, Spread = 0.4 },
} :: MapLighting.LightingPreset

----------------------------------------------------------------------------------------------------
-- 장식
----------------------------------------------------------------------------------------------------

-- 접시 FG: 밟는 면 아래 파란 테(립), 회전 무늬 링(Spin, 방향 = 미는 방향), 굽, 물에 비친 그림자 거품
local function addPlates(list: { DecorSpec })
	for _, plate in Layout.PLATES do
		local r = plate.kind.radius
		local top = plate.top
		local period = if plate.kind == Layout.BIG_PLATE then 4 else Layout.PLATE_SPIN_PERIOD
		-- 파란 테 립: 밟는 면보다 0.1 낮게, 바깥으로 0.6
		append(
			list,
			MapKitShapes.ring(
				"PlateRim",
				r + 0.3,
				0.6,
				0.5,
				if plate.kind == Layout.BIG_PLATE then 30 else 24,
				BLUE_RIM,
				"SmoothPlastic",
				v(plate.x, top - 0.35, plate.z)
			),
			{ reflectance = 0.08 }
		)
		-- 회전 무늬: 접시 지름보다 조금 긴 막대 2개가 접시 밑에서 돌아요 (양 끝 파란 점만 테 밖으로 보여요)
		local rot = if plate.dir > 0 then FLIP_UP else UP -- 양의 Spin = 위에서 반시계 → 시계(1)는 뒤집어요
		for k = 0, 1 do
			put(
				list,
				"PlateSpin",
				"Block",
				v(0.5, 2 * r + 2.2, 0.9),
				if k == 0 then BLUE_LIGHT else BLUE_RIM,
				"SmoothPlastic",
				v(plate.x, top - 0.95, plate.z),
				v(rot.x, rot.y + k * 90, rot.z),
				{ anim = { kind = "Spin", period = period, axis = "X" } }
			)
		end
		-- 굽 (아래 고리) + 물에 닿는 그림자 원
		disc(list, "PlateFoot", plate.x, top - 2.1, plate.z, 0.8, r * 1.3, c(222, 226, 234), "SmoothPlastic")
		-- 거품 고리 (물 위, 접시 아래쪽 둘레에 듬성듬성)
		local waterY = if plate.top > 0 then Layout.WATER_HIGH_Y else Layout.WATER_LOW_Y
		for k = 0, 5 do
			local a = (k / 6) * 2 * math.pi + plate.index * 0.7
			local rr = r * 0.95
			local size = 1.6 + (k % 3) * 0.6
			put(
				list,
				"PlateFoam",
				"Ball",
				v(size, size * 0.6, size),
				FOAM,
				"SmoothPlastic",
				v(plate.x + math.cos(a) * rr, waterY + 0.2, plate.z + math.sin(a) * rr)
			)
		end
	end
end

-- 컵·밥공기 FG: 입구 테, 손잡이, 무늬 띠
local function addCups(list: { DecorSpec })
	for _, cup in Layout.CUP_LIST do
		local d = cup.radius * 2
		local isMug = cup.index % 2 == 0
		local bottom = cup.top - Layout.CUP_HEIGHT
		-- 윗면 테(굽): 밟는 면 바로 아래 바깥 고리
		append(
			list,
			MapKitShapes.ring(
				"CupFootRing",
				cup.radius + 0.25,
				0.5,
				0.6,
				16,
				if isMug then c(150, 200, 184) else c(214, 190, 150),
				"SmoothPlastic",
				v(cup.x, cup.top - 0.45, cup.z)
			)
		)
		-- 무늬 띠 (중간)
		disc(
			list,
			"CupBand",
			cup.x,
			cup.top - 3.5,
			cup.z,
			0.8,
			d + 0.3,
			if isMug then c(90, 160, 150) else BLUE_RIM,
			"SmoothPlastic"
		)
		-- 물에 닿는 입구 테 (엎어 둔 컵이라 입구가 아래)
		disc(list, "CupMouth", cup.x, bottom + 0.4, cup.z, 0.8, d + 1, c(236, 238, 242), "SmoothPlastic")
		if isMug then
			-- 손잡이 (바깥쪽, 코스 밖으로)
			local side = if cup.x < 0 then -1 elseif cup.x > 0 then 1 else -1
			put(
				list,
				"CupHandle",
				"Block",
				v(1, 4, 1),
				c(150, 200, 184),
				"SmoothPlastic",
				v(cup.x + side * (cup.radius + 1.2), cup.top - 4.5, cup.z)
			)
			put(
				list,
				"CupHandle",
				"Block",
				v(1.6, 0.9, 1),
				c(150, 200, 184),
				"SmoothPlastic",
				v(cup.x + side * (cup.radius + 0.5), cup.top - 2.8, cup.z)
			)
			put(
				list,
				"CupHandle",
				"Block",
				v(1.6, 0.9, 1),
				c(150, 200, 184),
				"SmoothPlastic",
				v(cup.x + side * (cup.radius + 0.5), cup.top - 6.2, cup.z)
			)
		end
	end
end

-- 칸막이·다리·복도·출발 FG: 가장자리 트림 + 물속으로 내려가는 몸통
local function addLedges(list: { DecorSpec })
	for _, rect in Layout.floorRects() do
		local w, d = rect.maxX - rect.minX, rect.maxZ - rect.minZ
		local cx, cz = (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
		if rect.name == "DryingRack" then
			continue
		end
		-- 가장자리 트림: 윗면보다 0.15 낮게, 바깥으로 0.5
		append(
			list,
			MapKitShapes.lipTrim("LedgeTrim", v(w, 0, d), 0.5, 0.6, STEEL.dark, "Metal", v(cx, rect.top - 0.45, cz)),
			{ reflectance = 0.2 }
		)
		-- 몸통 (판정 바닥 아래 ~ 개수대 바닥)
		local bodyTop = rect.top - 2
		local bodyH = bodyTop - DishSinkArt.SINK_FLOOR_Y
		put(
			list,
			"LedgeBody",
			"Block",
			v(w - 0.6, bodyH, d - 0.6),
			STEEL.base,
			"Metal",
			v(cx, DishSinkArt.SINK_FLOOR_Y + bodyH / 2, cz),
			nil,
			{ reflectance = 0.15 }
		)
	end
	-- 건조대 오르막·평지 아래 받침 (흰 플라스틱 다리)
	for _, x in { -8, 8 } do
		for _, z in { -400, -420, -440 } do
			local top = if z < -415 then Layout.FINISH_Y - 2 else Layout.HIGH_Y - 2
			column(
				list,
				"RackLeg",
				x,
				DishSinkArt.SINK_FLOOR_Y,
				z,
				top - DishSinkArt.SINK_FLOOR_Y,
				2,
				c(226, 230, 236),
				"SmoothPlastic"
			)
		end
	end
end

-- 개수대 (BG·MG): 바닥, 벽, 둥근 테두리, 물 2장, 칸 사이 칸막이, 배수구 거름망
local function addSink(list: { DecorSpec })
	local X, W = DishSinkArt.SINK_X, DishSinkArt.SINK_WALL
	local floorY, rimY = DishSinkArt.SINK_FLOOR_Y, DishSinkArt.RIM_Y
	local backZ, endZ = DishSinkArt.SINK_BACK_Z, DishSinkArt.SINK_END_Z
	local length = backZ - endZ
	local midZ = (backZ + endZ) / 2
	local wallH = rimY - floorY
	-- 바닥 (두 칸 다른 shade)
	put(
		list,
		"SinkFloor",
		"Block",
		v(2 * X, 2, backZ - DishSinkArt.DIVIDER_Z),
		STEEL_DARK.base,
		"Metal",
		v(0, floorY - 1, (backZ + DishSinkArt.DIVIDER_Z) / 2),
		nil,
		{ reflectance = 0.2 }
	)
	put(
		list,
		"SinkFloor",
		"Block",
		v(2 * X, 2, DishSinkArt.DIVIDER_Z - endZ),
		STEEL_DARK.light,
		"Metal",
		v(0, floorY - 1, (DishSinkArt.DIVIDER_Z + endZ) / 2),
		nil,
		{ reflectance = 0.2 }
	)
	-- 옆벽 (안쪽 면 ±X), 끝벽
	for _, side in { -1, 1 } do
		put(
			list,
			"SinkWall",
			"Block",
			v(W, wallH, length + 2 * W),
			if side < 0 then STEEL.base else STEEL.light,
			"Metal",
			v(side * (X + W / 2), floorY + wallH / 2, midZ),
			nil,
			{ reflectance = 0.2 }
		)
		-- 둥글게 말린 테두리 (트림)
		put(
			list,
			"SinkRimRoll",
			"Cylinder",
			v(length + 2 * W, 2.4, 2.4),
			CHROME,
			"Metal",
			v(side * (X + 0.6), rimY - 0.4, midZ),
			v(0, 90, 0),
			{ reflectance = 0.3 }
		)
		-- 벽 아래 모서리 둥근 받침 (물속 코너)
		put(
			list,
			"SinkCove",
			"Cylinder",
			v(length, 3, 3),
			STEEL_DARK.dark,
			"Metal",
			v(side * (X - 0.5), floorY + 0.5, midZ),
			v(0, 90, 0),
			{ reflectance = 0.15 }
		)
	end
	for _, z in { backZ + W / 2, endZ - W / 2 } do
		put(
			list,
			"SinkEndWall",
			"Block",
			v(2 * X, wallH, W),
			STEEL.dark,
			"Metal",
			v(0, floorY + wallH / 2, z),
			nil,
			{ reflectance = 0.2 }
		)
		put(
			list,
			"SinkRimRoll",
			"Cylinder",
			v(2 * X + 2 * W, 2.4, 2.4),
			CHROME,
			"Metal",
			v(0, rimY - 0.4, z + (if z > 0 then -W / 2 + 0.6 else W / 2 - 0.6)),
			nil,
			{ reflectance = 0.3 }
		)
	end
	-- 두 칸 사이 칸막이 (물 높이가 달라요: 첫 칸 -5, 둘째 칸 -1)
	put(
		list,
		"SinkDivider",
		"Block",
		v(2 * X, Layout.WATER_HIGH_Y + 0.2 - floorY, 2),
		STEEL.base,
		"Metal",
		v(0, (floorY + Layout.WATER_HIGH_Y + 0.2) / 2, DishSinkArt.DIVIDER_Z),
		nil,
		{ reflectance = 0.2 }
	)
	put(
		list,
		"SinkDividerRoll",
		"Cylinder",
		v(2 * X, 1.4, 1.4),
		CHROME,
		"Metal",
		v(0, Layout.WATER_HIGH_Y + 0.2, DishSinkArt.DIVIDER_Z),
		nil,
		{ reflectance = 0.3 }
	)
	-- 설거지물 2장 (칸마다 한 장 — 큰 반투명 판은 이 둘뿐)
	put(
		list,
		"SinkWater",
		"Block",
		v(2 * X, 0.4, backZ - DishSinkArt.DIVIDER_Z),
		WATER,
		"Glass",
		v(0, Layout.WATER_LOW_Y, (backZ + DishSinkArt.DIVIDER_Z) / 2),
		nil,
		{ transparency = 0.35, reflectance = 0.15, castShadow = false }
	)
	put(
		list,
		"SinkWater",
		"Block",
		v(2 * X, 0.4, DishSinkArt.DIVIDER_Z - endZ),
		WATER,
		"Glass",
		v(0, Layout.WATER_HIGH_Y, (DishSinkArt.DIVIDER_Z + endZ) / 2),
		nil,
		{ transparency = 0.35, reflectance = 0.15, castShadow = false }
	)
	-- 배수구 거름망 (첫 칸 바닥, C 칸막이 오른쪽 물속 + 둘째 칸)
	for _, d in { { x = 19, z = -150 }, { x = -19, z = -372 } } do
		append(
			list,
			MapKitShapes.rimDisc(
				"DrainStrainer",
				10,
				0.6,
				c(196, 206, 216),
				"Metal",
				v(d.x, floorY + 0.3, d.z),
				{ rimColor = CHROME, rimWidth = 0.8, rimHeight = 0.8, segments = 16 }
			),
			{ reflectance = 0.25 }
		)
		append(
			list,
			MapKitShapes.ring("DrainMesh", 2.8, 0.3, 0.5, 12, STEEL_DARK.dark, "Metal", v(d.x, floorY + 0.8, d.z))
		)
		disc(list, "DrainHole", d.x, floorY + 0.75, d.z, 0.4, 2.6, c(60, 66, 74), "Metal")
		put(list, "DrainBubbles", "Ball", v(1, 1, 1), FOAM, "SmoothPlastic", v(d.x, floorY + 1.4, d.z), nil, {
			particle = "Bubbles",
			particleRate = 3,
			transparency = 0.5,
		})
	end
end

-- 조리대 (BG): 개수대를 둘러싼 스테인리스 상판 + 앞판 서랍 + 주방 바닥
local function addCounter(list: { DecorSpec })
	local X, W = DishSinkArt.SINK_X, DishSinkArt.SINK_WALL
	local rimY = DishSinkArt.RIM_Y
	local outer = X + W
	local backZ, endZ = DishSinkArt.SINK_BACK_Z + W, DishSinkArt.SINK_END_Z - W
	local farZ, nearZ = DishSinkArt.BACK_WALL_Z, 140
	local leftX, rightX = DishSinkArt.LEFT_WALL_X, DishSinkArt.RIGHT_COUNTER_X
	local thick = 4
	local function slab(name: string, minX: number, maxX: number, minZ: number, maxZ: number, color: RGB)
		put(
			list,
			name,
			"Block",
			v(maxX - minX, thick, maxZ - minZ),
			color,
			"Metal",
			v((minX + maxX) / 2, rimY - thick / 2, (minZ + maxZ) / 2),
			nil,
			{ reflectance = 0.18 }
		)
	end
	slab("CounterTop", leftX, -outer, farZ, nearZ, STEEL.light)
	slab("CounterTop", outer, rightX, farZ, nearZ, STEEL.light)
	slab("CounterTop", -outer, outer, backZ, nearZ, STEEL.base)
	slab("CounterTop", -outer, outer, farZ, endZ, STEEL.base)
	-- 상판 앞 모서리 둥근 트림 (오른쪽 끝, 앞 끝)
	put(
		list,
		"CounterEdge",
		"Cylinder",
		v(nearZ - farZ, 4, 4),
		CHROME,
		"Metal",
		v(rightX, rimY - 2, (nearZ + farZ) / 2),
		v(0, 90, 0),
		{
			reflectance = 0.3,
		}
	)
	put(
		list,
		"CounterEdge",
		"Cylinder",
		v(rightX - leftX, 4, 4),
		CHROME,
		"Metal",
		v((rightX + leftX) / 2, rimY - 2, nearZ),
		nil,
		{
			reflectance = 0.3,
		}
	)
	-- 조리대 몸통 + 서랍장 (오른쪽 면·앞면)
	local bodyH = rimY - 4 - DishSinkArt.KITCHEN_FLOOR_Y
	local bodyY = DishSinkArt.KITCHEN_FLOOR_Y + bodyH / 2
	-- 개수대 아래(개수대 바닥 -26 아래)는 통짜, 그 위는 개수대를 비워 두고 둘레만
	local sinkBottom = DishSinkArt.SINK_FLOOR_Y - 2
	local lowH = sinkBottom - DishSinkArt.KITCHEN_FLOOR_Y
	put(
		list,
		"CounterBody",
		"Block",
		v(rightX - leftX - 6, lowH, nearZ - farZ - 6),
		STEEL_DARK.light,
		"Metal",
		v((rightX + leftX) / 2 - 3, DishSinkArt.KITCHEN_FLOOR_Y + lowH / 2, (nearZ + farZ) / 2 - 3),
		nil,
		{ reflectance = 0.12 }
	)
	local upTop = rimY - 4
	local upH = upTop - sinkBottom
	local upY = sinkBottom + upH / 2
	local function upper(minX: number, maxX: number, minZ: number, maxZ: number)
		put(
			list,
			"CounterBody",
			"Block",
			v(maxX - minX, upH, maxZ - minZ),
			STEEL_DARK.light,
			"Metal",
			v((minX + maxX) / 2, upY, (minZ + maxZ) / 2),
			nil,
			{ reflectance = 0.12 }
		)
	end
	upper(leftX, -outer, farZ, nearZ - 6)
	upper(outer, rightX - 6, farZ, nearZ - 6)
	upper(-outer, outer, backZ, nearZ - 6)
	upper(-outer, outer, farZ, endZ)
	for i = 0, 9 do
		local z = nearZ - 30 - i * 60
		append(
			list,
			MapKitShapes.roundedBox(
				"CabinetDoor",
				v(1, bodyH - 16, 52),
				if i % 2 == 0 then STEEL.base else STEEL.light,
				"Metal",
				v(rightX - 2.5, bodyY - 2, z),
				{ style = "vertical", radius = 1.2 }
			),
			{ reflectance = 0.15 }
		)
		put(
			list,
			"CabinetHandle",
			"Cylinder",
			v(18, 1.4, 1.4),
			CHROME,
			"Metal",
			v(rightX - 1.5, bodyY + 18, z),
			v(0, 90, 0),
			{
				reflectance = 0.35,
			}
		)
	end
	-- 주방 바닥 (큰 판 3장 shade)
	local fy = DishSinkArt.KITCHEN_FLOOR_Y
	put(list, "KitchenFloor", "Block", v(1130, 4, 1290), FLOOR_TILE.base, "CeramicTiles", v(-235, fy - 2, 159))
	for i = 0, 5 do
		put(
			list,
			"KitchenFloorStripe",
			"Block",
			v(1130, 0.4, 40),
			if i % 2 == 0 then FLOOR_TILE.light else FLOOR_TILE.dark,
			"CeramicTiles",
			v(-235, fy + 0.2, 700 - i * 200)
		)
	end
end

-- 벽 (BG): 왼쪽 타일 벽(선반·수건 걸이), 결승 너머 창문 벽(햇살), 오른쪽 먼 벽
local function addWalls(list: { DecorSpec })
	local fy = DishSinkArt.KITCHEN_FLOOR_Y
	local lx = DishSinkArt.LEFT_WALL_X
	local bz = DishSinkArt.BACK_WALL_Z
	local rimY = DishSinkArt.RIM_Y
	-- 왼쪽 벽 (조리대 위 타일 + 위쪽 페인트)
	put(list, "TileWall", "Block", v(4, 120, 660), TILE.base, "CeramicTiles", v(lx - 2, rimY + 60, -180))
	for i = 0, 4 do
		put(list, "TileBand", "Block", v(0.6, 1.2, 660), GROUT, "SmoothPlastic", v(lx + 0.3, rimY + 12 + i * 24, -180))
	end
	-- 결승 너머 벽 + 큰 창문 (따뜻한 햇살)
	put(list, "BackWall", "Block", v(1130, 140, 4), TILE.base, "CeramicTiles", v(-235, rimY + 70, bz - 2))
	put(list, "BackWallTop", "Block", v(1130, 280, 4), TILE.dark, "Plaster", v(-235, rimY + 280, bz - 2))
	for i = 0, 2 do
		put(list, "TileBand", "Block", v(1130, 1.2, 0.6), GROUT, "SmoothPlastic", v(-235, rimY + 12 + i * 24, bz + 0.3))
	end
	local winY, winW, winH = 62, 90, 56
	-- 창틀 (나무, 둥근 모서리)
	append(
		list,
		MapKitShapes.roundedBox(
			"WindowFrame",
			v(winW + 8, 4, 3),
			WOOD.light,
			"Wood",
			v(0, winY - winH / 2 - 2, bz + 1),
			{ radius = 1 }
		)
	)
	append(
		list,
		MapKitShapes.roundedBox(
			"WindowFrame",
			v(winW + 8, 4, 3),
			WOOD.light,
			"Wood",
			v(0, winY + winH / 2 + 2, bz + 1),
			{ radius = 1 }
		)
	)
	for _, x in { -winW / 2 - 2, 0, winW / 2 + 2 } do
		put(list, "WindowMullion", "Block", v(3, winH, 3), WOOD.base, "Wood", v(x, winY, bz + 1))
	end
	put(list, "WindowSill", "Block", v(winW + 14, 2, 10), WOOD.dark, "Wood", v(0, winY - winH / 2 - 4, bz + 5))
	-- 유리 (햇빛 = 빛나는 원인). 왼쪽 판에 그림자 Spot (결승을 비춰요 — "저 밝은 데로")
	put(list, "WindowPane", "Block", v(winW / 2 - 2, winH, 0.6), SUN, "Neon", v(-winW / 4, winY, bz + 0.4), nil, {
		light = {
			kind = "Spot",
			color = c(255, 214, 160),
			brightness = 3,
			range = 60,
			angle = 120,
			face = "Back",
			shadows = true,
		},
	})
	put(list, "WindowPane", "Block", v(winW / 2 - 2, winH, 0.6), SUN, "Neon", v(winW / 4, winY, bz + 0.4), nil, {
		light = { kind = "Surface", color = c(255, 220, 170), brightness = 2, range = 16, angle = 90, face = "Back" },
	})
	-- 창가 화분 (초록 작은 무리)
	for i, x in { -30, -22, 26 } do
		column(list, "WindowPot", x, winY - winH / 2 - 3, bz + 5, 5, 5 + i, c(196, 120, 84), "Plastic")
		put(list, "WindowPlant", "Ball", v(7 + i, 6, 7 + i), c(96, 160, 90), "Grass", v(x, winY - winH / 2 + 4, bz + 5))
	end
	-- 오른쪽 먼 벽
	put(list, "FarWall", "Block", v(4, 500, 1290), TILE.dark, "Plaster", v(DishSinkArt.RIGHT_WALL_X, fy + 250, 159))
	put(
		list,
		"FarWallTile",
		"Block",
		v(4.4, 90, 1290),
		TILE.base,
		"CeramicTiles",
		v(DishSinkArt.RIGHT_WALL_X - 0.2, fy + 45, 159)
	)
end

-- 선반·수건 (BG·MG): 왼쪽 벽 선반 2단 + 그릇·병, 매달린 행주(Sway)
local function addShelves(list: { DecorSpec })
	local lx = DishSinkArt.LEFT_WALL_X
	local rimY = DishSinkArt.RIM_Y
	for _, shelf in { { y = rimY + 70, z0 = -40, z1 = -200 }, { y = rimY + 100, z0 = -260, z1 = -420 } } do
		local len = shelf.z0 - shelf.z1
		local cz = (shelf.z0 + shelf.z1) / 2
		append(list, MapKitShapes.bevelBox("WallShelf", v(18, 2, len), WOOD.base, "Wood", v(lx + 9, shelf.y, cz), 0.6))
		for _, z in { shelf.z0 - 10, shelf.z1 + 10 } do
			put(
				list,
				"ShelfBracket",
				"Wedge",
				v(2, 10, 12),
				WOOD.dark,
				"Wood",
				v(lx + 6, shelf.y - 6, z),
				v(0, -90, 180)
			)
		end
		-- 그릇 탑·병 무리
		local items = { 12, 30, 46, 70, 96, 118, 140 }
		for i, dz in items do
			local z = shelf.z0 - dz
			if z < shelf.z1 + 4 then
				continue
			end
			local kind = i % 3
			if kind == 0 then
				for k = 0, 2 do
					disc(
						list,
						"ShelfBowl",
						lx + 9,
						shelf.y + 2 + k * 2.4,
						z,
						2.2,
						14 - k,
						if k % 2 == 0 then PORCELAIN else c(220, 232, 244),
						"SmoothPlastic"
					)
				end
			elseif kind == 1 then
				column(
					list,
					"ShelfJar",
					lx + 9,
					shelf.y + 1,
					z,
					16,
					9,
					c(190, 220, 214),
					"Glass",
					{ transparency = 0.25 }
				)
				column(list, "ShelfJarLid", lx + 9, shelf.y + 17, z, 2, 10, WOOD.dark, "Wood")
			else
				column(list, "ShelfBottle", lx + 9, shelf.y + 1, z, 20, 6, c(214, 120, 80), "SmoothPlastic")
				column(list, "ShelfBottleCap", lx + 9, shelf.y + 21, z, 3, 3.5, c(240, 240, 240), "SmoothPlastic")
			end
		end
	end
	-- 수건 걸이 + 행주 (Sway)
	local z = -300
	put(
		list,
		"TowelBar",
		"Cylinder",
		v(40, 1.4, 1.4),
		CHROME,
		"Metal",
		v(lx + 4, rimY + 40, z),
		v(0, 90, 0),
		{ reflectance = 0.3 }
	)
	for i, dz in { -12, 6 } do
		put(
			list,
			"Towel",
			"Block",
			v(1, 26, 14),
			if i == 1 then c(150, 196, 230) else c(236, 228, 210),
			"Fabric",
			v(lx + 4.5, rimY + 27, z + dz),
			nil,
			{ anim = { kind = "Sway", period = 4.5 + i, amount = 4, axis = "Z" } }
		)
		-- 가운데 줄무늬 (같은 중심·같은 움직임이라 행주와 함께 흔들려요)
		put(
			list,
			"TowelStripe",
			"Block",
			v(1.3, 26, 2.4),
			if i == 1 then c(70, 120, 190) else c(200, 120, 110),
			"Fabric",
			v(lx + 4.5, rimY + 27, z + dz),
			nil,
			{ anim = { kind = "Sway", period = 4.5 + i, amount = 4, axis = "Z" } }
		)
	end
end

-- 히어로 ① 거대한 크롬 수도꼭지 + 물줄기 + 물방울(Bob) + 그림자 Spot 램프
local function addFaucet(list: { DecorSpec })
	local bx, bz = -44, -70
	local rimY = DishSinkArt.RIM_Y
	local topY = 74
	local headX = -24
	-- 받침 + 세로 관
	disc(list, "FaucetBase", bx, rimY + 1.5, bz, 3, 14, CHROME, "Metal", { reflectance = 0.35 })
	column(list, "FaucetPipe", bx, rimY + 3, bz, topY - rimY - 3, 5, CHROME, "Metal", { reflectance = 0.35 })
	-- 구스넥 (반원 아치를 관 6토막으로)
	local cx, cy = (bx + headX) / 2, topY
	local radius = (headX - bx) / 2
	local prev = v(bx, topY, bz)
	for k = 1, 6 do
		local a = math.pi - (k / 6) * math.pi
		local p = v(cx + math.cos(a) * radius, cy + math.sin(a) * radius, bz)
		rod(list, "FaucetNeck", prev, p, 5, CHROME, "Metal", { reflectance = 0.35 })
		put(list, "FaucetJoint", "Ball", v(5, 5, 5), CHROME, "Metal", p, nil, { reflectance = 0.35 })
		prev = p
	end
	-- 내려오는 끝 + 노즐
	column(list, "FaucetSpout", headX, topY - 10, bz, 10, 5, CHROME, "Metal", { reflectance = 0.35 })
	column(list, "FaucetNozzle", headX, topY - 13, bz, 3, 6.4, c(170, 180, 192), "Metal", { reflectance = 0.3 })
	-- 손잡이 2개 (십자)
	for _, dz in { -12, 12 } do
		column(list, "FaucetValve", bx, rimY, bz + dz, 4, 4, CHROME, "Metal", { reflectance = 0.35 })
		put(
			list,
			"FaucetHandle",
			"Block",
			v(9, 1.4, 1.4),
			if dz < 0 then c(90, 150, 210) else c(236, 238, 244),
			"SmoothPlastic",
			v(bx, rimY + 4.6, bz + dz)
		)
		put(
			list,
			"FaucetHandle",
			"Block",
			v(1.4, 1.4, 9),
			if dz < 0 then c(90, 150, 210) else c(236, 238, 244),
			"SmoothPlastic",
			v(bx, rimY + 4.6, bz + dz)
		)
	end
	-- 물줄기 (얇은 유리 기둥) + 물보라 + 물방울
	local waterY = Layout.WATER_LOW_Y
	column(list, "FaucetStream", headX, waterY, bz, topY - 13 - waterY, 2.2, c(200, 236, 246), "Glass", {
		transparency = 0.45,
		castShadow = false,
	})
	put(list, "StreamSplash", "Ball", v(6, 1.2, 6), FOAM, "SmoothPlastic", v(headX, waterY + 0.3, bz), nil, {
		particle = "SeaSpray",
		particleRate = 4,
	})
	for k = 0, 2 do
		put(
			list,
			"WaterDrop",
			"Ball",
			v(1.4, 1.8, 1.4),
			c(200, 236, 250),
			"Glass",
			v(headX + 2.5, topY - 20 - k * 12, bz + 2),
			nil,
			{
				transparency = 0.3,
				anim = { kind = "Bob", period = 1.6 + k * 0.4, amount = 3 },
			}
		)
	end
	-- 램프 (집게 스탠드, 수도꼭지 뒤 왼쪽 위) — 수도꼭지 그림자를 접시 위로 (그림자 Spot 2번째)
	local lx, lz = -60, -76
	disc(list, "LampClamp", lx, rimY + 1, lz, 2, 7, c(70, 76, 84), "Metal")
	column(list, "LampPole", lx, rimY + 2, lz, 30, 1.6, c(70, 76, 84), "Metal")
	rod(list, "LampArm", v(lx, rimY + 32, lz), v(-50, 46, lz), 1.4, c(70, 76, 84), "Metal")
	put(list, "LampShade", "Cylinder", v(5, 9, 9), c(80, 120, 150), "Metal", v(-50, 45, lz), v(0, 0, 40), {
		reflectance = 0.2,
	})
	put(list, "LampBulb", "Ball", v(5, 5, 5), c(255, 246, 226), "Neon", v(-49, 43.6, lz), v(0, 0, 40), {
		light = {
			kind = "Spot",
			color = c(255, 244, 226),
			brightness = 2.5,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
end

-- 히어로 ③ 쌓인 더러운 접시 탑·컵 (오른쪽 조리대), ④ 세제통·고무장갑·솔 (왼쪽 조리대)
local function addClutter(list: { DecorSpec })
	local rimY = DishSinkArt.RIM_Y
	-- ③ 접시 탑 2개 (조금씩 어긋나고 기울게)
	for t, tower in { { x = 60, z = -70, n = 9 }, { x = 54, z = -118, n = 6 } } do
		for k = 0, tower.n - 1 do
			local dx = math.sin(k * 1.7 + t) * 1.2
			local dz = math.cos(k * 1.3 + t) * 1.2
			local d = 26 - (k % 3) * 1.5
			disc(
				list,
				"DirtyPlate",
				tower.x + dx,
				rimY + 1 + k * 2.1,
				tower.z + dz,
				1.6,
				d,
				if k % 2 == 0 then PORCELAIN else c(232, 236, 242),
				"SmoothPlastic",
				{ reflectance = 0.05 }
			)
			disc(
				list,
				"DirtyPlateRim",
				tower.x + dx,
				rimY + 1 + k * 2.1,
				tower.z + dz,
				1.2,
				d + 1,
				BLUE_RIM,
				"SmoothPlastic"
			)
		end
		-- 맨 위 소스 얼룩 + 젓가락
		local topY = rimY + 1 + tower.n * 2.1
		disc(list, "SauceStain", tower.x + 2, topY - 1, tower.z - 3, 0.3, 7, STAIN, "SmoothPlastic")
		disc(list, "SauceStain", tower.x - 5, topY - 1, tower.z + 4, 0.3, 4, c(190, 120, 70), "SmoothPlastic")
	end
	-- 컵 무리
	for i, cup in { { x = 76, z = -96, d = 9 }, { x = 84, z = -82, d = 8 }, { x = 72, z = -138, d = 10 } } do
		column(
			list,
			"DirtyCup",
			cup.x,
			rimY,
			cup.z,
			11 - i,
			cup.d,
			if i == 2 then c(206, 236, 224) else PORCELAIN,
			"SmoothPlastic"
		)
		disc(list, "DirtyCupBand", cup.x, rimY + 6, cup.z, 1, cup.d + 0.3, BLUE_RIM, "SmoothPlastic")
	end
	-- 젓가락 한 쌍 (탑 옆)
	for k = 0, 1 do
		append(
			list,
			MapKitShapes.capsule(
				"Chopstick",
				23,
				0.9,
				c(160, 112, 70),
				"Wood",
				v(66 + k * 1.6, rimY + 0.5, -104),
				v(0, 30, 0)
			)
		)
	end
	-- ④ 세제통 (주황, 펌프) + 고무장갑 + 솔 (출발 왼쪽 조리대)
	local dx, dz = -52, -14
	append(
		list,
		MapKitShapes.roundedBox(
			"DetergentBottle",
			v(10, 24, 7),
			DETERGENT,
			"SmoothPlastic",
			v(dx, rimY + 12, dz),
			{ radius = 2.5, style = "vertical" }
		)
	)
	put(list, "DetergentLabel", "Block", v(7, 9, 0.4), c(250, 244, 220), "SmoothPlastic", v(dx, rimY + 11, dz + 3.6))
	column(list, "DetergentNeck", dx, rimY + 24, dz, 3, 4, c(240, 240, 244), "SmoothPlastic")
	put(list, "DetergentPump", "Block", v(6, 1.4, 1.6), c(240, 240, 244), "SmoothPlastic", v(dx + 2, rimY + 28, dz))
	-- 펌프 입구 거품 (Pulse)
	put(list, "DetergentFoam", "Ball", v(3.2, 2.4, 3.2), FOAM, "SmoothPlastic", v(dx + 5, rimY + 28.6, dz), nil, {
		anim = { kind = "Pulse", period = 2.6, amount = 0.12 },
	})
	-- 두 번째 작은 세제통
	append(
		list,
		MapKitShapes.roundedBox(
			"DetergentBottle",
			v(7, 16, 5),
			c(120, 190, 220),
			"SmoothPlastic",
			v(dx - 10, rimY + 8, dz + 8),
			{ radius = 1.8, style = "vertical" }
		)
	)
	-- 고무장갑 (테두리에 걸쳐 놓은 손 모양: 손바닥 + 손가락 4 + 엄지 + 소매)
	local gx, gz = -36.5, -40
	append(
		list,
		MapKitShapes.roundedBox(
			"GlovePalm",
			v(9, 1.8, 8),
			GLOVE,
			"Rubber",
			v(gx - 4, DishSinkArt.RIM_Y + 0.9, gz),
			{ radius = 0.8, rotation = v(0, 10, -6) }
		)
	)
	for f = 0, 3 do
		append(
			list,
			MapKitShapes.capsule(
				"GloveFinger",
				6,
				1.8,
				GLOVE,
				"Rubber",
				v(gx + 2.6, DishSinkArt.RIM_Y - 0.6, gz - 3 + f * 2.1),
				v(0, 6, -40)
			)
		)
	end
	append(
		list,
		MapKitShapes.capsule(
			"GloveThumb",
			4.5,
			2,
			GLOVE,
			"Rubber",
			v(gx - 4, DishSinkArt.RIM_Y + 1.2, gz + 5),
			v(0, -60, 0)
		)
	)
	put(
		list,
		"GloveCuff",
		"Cylinder",
		v(9, 6, 6),
		c(206, 132, 152),
		"Rubber",
		v(gx - 12, DishSinkArt.RIM_Y + 2.4, gz - 1),
		v(0, 12, 0)
	)
	-- 솔 (손잡이 + 털)
	append(
		list,
		MapKitShapes.capsule(
			"BrushHandle",
			16,
			2.2,
			c(90, 150, 200),
			"SmoothPlastic",
			v(-62, rimY + 1.2, -36),
			v(0, -25, 0)
		)
	)
	put(
		list,
		"BrushBristles",
		"Block",
		v(7, 3, 4.5),
		c(236, 226, 196),
		"Fabric",
		v(-54.5, rimY + 1.6, -39.5),
		v(0, -25, 0)
	)
	-- 비누 받침 + 장식 수세미 (채도 낮은 노랑)
	append(
		list,
		MapKitShapes.roundedBox(
			"SoapDish",
			v(14, 2, 10),
			c(220, 230, 240),
			"SmoothPlastic",
			v(-50, rimY + 1, -110),
			{ radius = 0.8 }
		)
	)
	put(list, "SpareSponge", "Block", v(9, 3, 6), MUTED_YELLOW, "Sand", v(-50, rimY + 3.5, -110), v(0, 15, 0))
	put(list, "SpareSpongeTop", "Block", v(9, 1, 6), c(150, 180, 110), "Fabric", v(-50, rimY + 5.5, -110), v(0, 15, 0))
end

-- 히어로 ⑤ 결승 건조대: 세워 둔 깨끗한 접시 줄 + 철사 받침 + "FINISH" 나무 간판 + 반짝이
local FONT: { [string]: { string } } = {
	F = { "111", "100", "110", "100", "100" },
	I = { "111", "010", "010", "010", "111" },
	N = { "101", "111", "111", "111", "101" },
	S = { "111", "100", "111", "001", "111" },
	H = { "101", "101", "111", "101", "101" },
}

local function addFinish(list: { DecorSpec })
	local fy = Layout.FINISH_Y
	-- 양옆 접시 받침 (철사 레일) + 세워 둔 접시
	for _, side in { -1, 1 } do
		local x = side * 21
		for _, h in { fy - 1, fy + 5 } do
			put(
				list,
				"RackRail",
				"Cylinder",
				v(70, 0.8, 0.8),
				CHROME,
				"Metal",
				v(x, h, -420),
				v(0, 90, 0),
				{ reflectance = 0.3 }
			)
			put(
				list,
				"RackRail",
				"Cylinder",
				v(70, 0.8, 0.8),
				CHROME,
				"Metal",
				v(x + side * 6, h + 2, -420),
				v(0, 90, 0),
				{ reflectance = 0.3 }
			)
		end
		for k = 0, 8 do
			local z = -392 - k * 6.4
			local floor = if z > Layout.RAMP.back
				then Layout.HIGH_Y + (Layout.FINISH_Y - Layout.HIGH_Y) * ((Layout.RAMP.front - z) / 20)
				else fy
			local d = 18 - (k % 2) * 1.5
			local cy = floor - 1 + d / 2
			-- 세운 접시 (건조대 칸마다 하나, 면이 코스 진행 방향을 봐요): 원판 + 뒤에 파란 테 원판
			local lean = v(10 + (k % 3) * 3, 90, 0)
			put(
				list,
				"CleanPlate",
				"Cylinder",
				v(0.8, d, d),
				PORCELAIN,
				"SmoothPlastic",
				v(x + side * 1.5, cy, z),
				lean,
				{ reflectance = 0.12 }
			)
			put(
				list,
				"CleanPlateRim",
				"Cylinder",
				v(0.5, d + 1, d + 1),
				BLUE_RIM,
				"SmoothPlastic",
				v(x + side * 1.5, cy - 0.1, z - 0.5),
				lean
			)
		end
		for _, z in { -390, -420, -450 } do
			column(
				list,
				"RackPost",
				x,
				DishSinkArt.SINK_FLOOR_Y,
				z,
				fy + 6 - DishSinkArt.SINK_FLOOR_Y,
				1.2,
				CHROME,
				"Metal",
				{ reflectance = 0.3 }
			)
		end
	end
	-- FINISH 아치: 나무 기둥 2 + 나무 간판 + 블록 글자
	local z = Layout.FINISH_LINE_Z - 1.5
	local postX = Layout.FINISH_WIDTH / 2 + 2
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.roundedBox(
				"FinishPost",
				v(2.4, 20, 2.4),
				WOOD.base,
				"Wood",
				v(side * postX, fy + 10, z),
				{ style = "vertical", radius = 0.6 }
			)
		)
		put(list, "FinishPostCap", "Ball", v(3.4, 3.4, 3.4), WOOD.dark, "SmoothPlastic", v(side * postX, fy + 20.8, z))
	end
	append(
		list,
		MapKitShapes.bevelBox("FinishBoard", v(2 * postX + 4, 6, 1.6), WOOD.light, "Wood", v(0, fy + 17, z), 0.5)
	)
	put(list, "FinishBoardTrim", "Block", v(2 * postX + 5, 0.8, 1.8), WOOD.dark, "Wood", v(0, fy + 13.8, z))
	local word = "FINISH"
	local px = 0.8
	local totalW = #word * 4 * px - px
	for i = 1, #word do
		local glyph = FONT[string.sub(word, i, i)]
		local gx0 = -totalW / 2 + (i - 1) * 4 * px
		for row, line in glyph do
			for col = 1, 3 do
				if string.sub(line, col, col) == "1" then
					put(
						list,
						"FinishLetter",
						"Block",
						v(px, px, 0.4),
						c(56, 92, 170),
						"SmoothPlastic",
						v(gx0 + (col - 1) * px + px / 2, fy + 19 - row * px, z + 1)
					)
				end
			end
		end
	end
	-- 반짝이 (뽀득) + 따뜻한 전구 2개
	for _, side in { -1, 1 } do
		put(list, "FinishSparkle", "Ball", v(1, 1, 1), c(255, 250, 220), "Neon", v(side * 18, fy + 14, -430), nil, {
			particle = "Sparkle",
			particleRate = 4,
		})
		put(
			list,
			"FinishBulb",
			"Ball",
			v(1.6, 1.6, 1.6),
			c(255, 232, 170),
			"Neon",
			v(side * postX, fy + 15, z + 1.2),
			nil,
			{
				light = { kind = "Point", color = c(255, 220, 160), brightness = 1.5, range = 18 },
			}
		)
	end
end

-- 물 위 거품 무리 (FG, 코스 밖) + 비눗방울(Bob) + 청록 물빛(SurfaceLight)
local function addFoam(list: { DecorSpec })
	local clusters = {
		{ x = -27, z = -20, y = Layout.WATER_LOW_Y },
		{ x = 26, z = -45, y = Layout.WATER_LOW_Y },
		{ x = -26, z = -110, y = Layout.WATER_LOW_Y },
		{ x = 24, z = -170, y = Layout.WATER_LOW_Y },
		{ x = -20, z = -230, y = Layout.WATER_LOW_Y },
		{ x = 25, z = -290, y = Layout.WATER_HIGH_Y },
		{ x = -26, z = -340, y = Layout.WATER_HIGH_Y },
		{ x = 22, z = -380, y = Layout.WATER_HIGH_Y },
	}
	for i, cl in clusters do
		local rng = MapKitShapes.rng(100 + i)
		for k = 1, 7 do
			local s = rng:range(1.4, 4)
			local ox, oz = rng:range(-4, 4), rng:range(-6, 6)
			put(
				list,
				"FoamBall",
				"Ball",
				v(s, s * 0.7, s),
				if k % 3 == 0 then c(232, 244, 252) else FOAM,
				"SmoothPlastic",
				v(cl.x + ox, cl.y + s * 0.2, cl.z + oz)
			)
		end
		-- 떠다니는 비눗방울 (Bob)
		put(
			list,
			"SoapBubble",
			"Ball",
			v(2.6, 2.6, 2.6),
			c(220, 236, 255),
			"Glass",
			v(cl.x, cl.y + 4 + (i % 3), cl.z + 2),
			nil,
			{
				transparency = 0.45,
				reflectance = 0.3,
				anim = { kind = "Bob", period = 3 + (i % 4) * 0.7, amount = 1.6 },
			}
		)
		if i % 2 == 1 then
			put(list, "FoamPuff", "Ball", v(3, 1.4, 3), FOAM, "SmoothPlastic", v(cl.x, cl.y + 0.6, cl.z - 3), nil, {
				particle = "SoapFoam",
				particleRate = 2,
			})
		end
		if i % 2 == 0 then
			-- 물빛 (그림자 없음, range ≤ 16)
			put(
				list,
				"WaterGlow",
				"Cylinder",
				v(0.2, 7, 7),
				c(170, 230, 236),
				"Glass",
				v(cl.x, cl.y + 0.25, cl.z + 4),
				UP,
				{
					transparency = 0.4,
					light = {
						kind = "Surface",
						color = c(150, 226, 236),
						brightness = 1.2,
						range = 14,
						angle = 120,
						face = "Right",
					},
				}
			)
		end
	end
end

-- 조리대 위 MG 소품 무리: 큰 들통·도마·소쿠리·그릇 탑(오른쪽), 철사 바구니·양념통(왼쪽)
local function addCounterProps(list: { DecorSpec })
	local rimY = DishSinkArt.RIM_Y
	-- 큰 스테인리스 들통 (지름 46, 높이 38) + 손잡이 + 기울여 세운 뚜껑
	local px, pz = 84, -252
	column(list, "StockPot", px, rimY, pz, 38, 46, STEEL.light, "Metal", { reflectance = 0.25 })
	append(
		list,
		MapKitShapes.ring("StockPotLip", 23, 1.4, 1.6, 20, CHROME, "Metal", v(px, rimY + 38.6, pz)),
		{ reflectance = 0.3 }
	)
	disc(list, "StockPotBand", px, rimY + 6, pz, 1.4, 46.6, STEEL.dark, "Metal", { reflectance = 0.2 })
	for _, side in { -1, 1 } do
		append(
			list,
			MapKitShapes.capsule("StockPotHandle", 10, 2, CHROME, "Metal", v(px, rimY + 32, pz + side * 24.5)),
			{ reflectance = 0.3 }
		)
	end
	put(
		list,
		"StockPotLid",
		"Cylinder",
		v(1.6, 44, 44),
		STEEL.base,
		"Metal",
		v(px + 26, rimY + 21, pz - 30),
		v(0, 20, 72),
		{
			reflectance = 0.25,
		}
	)
	put(list, "StockPotKnob", "Ball", v(4, 4, 4), c(60, 64, 70), "SmoothPlastic", v(px + 26.5, rimY + 22, pz - 30))
	-- 도마 + 칼 + 파 몇 토막
	append(
		list,
		MapKitShapes.roundedBox(
			"CuttingBoard",
			v(34, 2.4, 52),
			WOOD.light,
			"Wood",
			v(82, rimY + 1.2, -186),
			{ radius = 1, rotation = v(0, 8, 0) }
		)
	)
	put(list, "KnifeBlade", "Wedge", v(0.4, 5, 22), c(206, 214, 222), "Metal", v(76, rimY + 2.8, -176), v(0, 8, 90), {
		reflectance = 0.35,
	})
	append(
		list,
		MapKitShapes.capsule(
			"KnifeHandle",
			12,
			2.4,
			c(50, 46, 44),
			"SmoothPlastic",
			v(77.5, rimY + 3.6, -194),
			v(0, 98, 0)
		)
	)
	for k = 0, 3 do
		column(
			list,
			"GreenOnion",
			90 + k * 2.6,
			rimY + 2.4,
			-200 + (k % 2) * 3,
			4,
			2.2,
			c(130, 190, 90),
			"SmoothPlastic"
		)
	end
	-- 소쿠리 (반구 + 테) + 삶은 달걀 (빨강은 위험 색이라 장식에 안 써요)
	local cx, cz = 76, -332
	put(list, "Colander", "Ball", v(30, 16, 30), STEEL.light, "Metal", v(cx, rimY + 2, cz), nil, { reflectance = 0.25 })
	append(
		list,
		MapKitShapes.ring("ColanderRim", 15, 1.2, 1.2, 18, CHROME, "Metal", v(cx, rimY + 9.6, cz)),
		{ reflectance = 0.3 }
	)
	for k = 0, 4 do
		local a = k * 1.25
		put(
			list,
			"BoiledEgg",
			"Ball",
			v(4, 5, 4),
			c(250, 244, 228),
			"SmoothPlastic",
			v(cx + math.cos(a) * 6, rimY + 10, cz + math.sin(a) * 6)
		)
	end
	-- 그릇 탑 (오른쪽 끝)
	for k = 0, 4 do
		disc(
			list,
			"BowlStack",
			70 + (k % 2) * 0.6,
			rimY + 2 + k * 3,
			-414,
			3,
			18 - k * 0.6,
			if k % 2 == 0 then PORCELAIN else c(214, 230, 244),
			"SmoothPlastic"
		)
	end
	-- 왼쪽: 철사 바구니 + 컵 (건조대 결승 옆)
	local bx, bz = -82, -420
	append(
		list,
		MapKitShapes.lipTrim("WireBasket", v(36, 0, 46), 0.8, 10, CHROME, "Metal", v(bx, rimY + 5, bz)),
		{ reflectance = 0.3 }
	)
	put(list, "WireBasketFloor", "Block", v(36, 0.8, 46), STEEL.base, "DiamondPlate", v(bx, rimY + 0.4, bz))
	for k = 0, 3 do
		local cupX, cupZ = bx - 9 + (k % 2) * 16, bz - 12 + math.floor(k / 2) * 22
		column(
			list,
			"BasketCup",
			cupX,
			rimY + 0.8,
			cupZ,
			10 - k,
			9,
			if k % 2 == 0 then c(206, 236, 224) else PORCELAIN,
			"SmoothPlastic"
		)
		disc(list, "BasketCupBand", cupX, rimY + 6, cupZ, 1, 9.3, BLUE_RIM, "SmoothPlastic")
	end
	-- 왼쪽: 양념통 무리 (벽 앞)
	for k = 0, 5 do
		local h = 14 + (k % 3) * 4
		column(
			list,
			"SpiceJar",
			-110 + (k % 2) * 7,
			rimY,
			-200 - k * 8,
			h,
			6,
			if k % 3 == 0 then c(214, 160, 90) elseif k % 3 == 1 then c(150, 120, 90) else c(200, 200, 186),
			"Glass",
			{ transparency = 0.15 }
		)
		column(list, "SpiceLid", -110 + (k % 2) * 7, rimY + h, -200 - k * 8, 2, 6.4, c(70, 76, 84), "SmoothPlastic")
	end
end

function DishSinkArt.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addPlates(list)
	addCups(list)
	addLedges(list)
	addSink(list)
	addCounter(list)
	addWalls(list)
	addShelves(list)
	addFaucet(list)
	addClutter(list)
	addFinish(list)
	addFoam(list)
	addCounterProps(list)
	return list
end

-- 장식이 들어가면 안 되는 코스 시야 상자: 밟는 면 위 2~12
function DishSinkArt.courseVolume(): { Bounds }
	local list: { Bounds } = {}
	local function box(minX: number, maxX: number, minZ: number, maxZ: number, floorY: number)
		table.insert(list, { min = v(minX, floorY + 2, minZ), max = v(maxX, floorY + 12, maxZ) })
	end
	for _, rect in Layout.floorRects() do
		box(rect.minX, rect.maxX, rect.minZ, rect.maxZ, rect.top)
	end
	for _, plate in Layout.PLATES do
		local r = plate.kind.radius
		box(plate.x - r, plate.x + r, plate.z - r, plate.z + r, plate.top)
	end
	for _, cup in Layout.CUP_LIST do
		box(cup.x - cup.radius, cup.x + cup.radius, cup.z - cup.radius, cup.z + cup.radius, cup.top)
	end
	-- 오르막 (높은 쪽 기준)
	local half = Layout.FINISH_WIDTH / 2
	box(-half, half, Layout.RAMP.back, Layout.RAMP.front, Layout.HIGH_Y)
	return list
end

-- 소개 카메라: ① 수도꼭지 너머 개수대 전체 → ② 도는 접시 → ③ 칸막이 위 수세미 반전 샷 → ④ 건조대 결승 → ⑤ 출발 자리
function DishSinkArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(-34, 50, 14), lookAt = v(6, -6, -150) },
		{ pos = v(-20, 11, -36), lookAt = v(-8, -1, -60) },
		{ pos = v(10, 30, -196), lookAt = v(0, 0, -140) },
		{ pos = v(5, 25, -398), lookAt = v(0, 13, -442) },
		{ pos = v(0, 12, 22), lookAt = v(0, 3, -40) },
	}
end

return DishSinkArt
