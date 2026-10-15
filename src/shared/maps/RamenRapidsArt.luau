--!strict
-- "라멘 국물 급류"(m4-04) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙).
--   RamenRapidsArt.decor() -> { DecorSpec }       거대한 라멘 그릇·국물·떠다니는 파/김/달걀·젓가락 한 쌍·숟가락 출구
--                                                  + m5-24: 라멘집 카운터·벽·노렌·등롱·창, 그릇 위 소품, 면 커튼, 계란, 나루토 섬
--   RamenRapidsArt.steamPoints() -> { Vec3 }       김(ParticleEmitter)을 붙일 자리 3곳
--   RamenRapidsArt.introCamera() -> { IntroPoint } 라운드 소개 경유점 4개
--   RamenRapidsArt.courseVolumes() -> { Bounds }   장식이 들어가면 안 되는 구간별 시야 상자 (바닥 위 2~12)
--   RamenRapidsArt.BUDGET / LIGHTING               m5-24: Extended 예산, 맵 조명 분위기 ("김 자욱한 한낮")
-- 장식은 MapKit.buildDecor로 만들어서 충돌·쿼리·터치가 없어요 (판정과 무관).
--
-- 스케일 (m5-24, 가이드 1절): 이 맵은 판정 그릇이 지름 356이라 "그릇 스케일"이에요 — 기존 거대 젓가락(길이 409 ≈ 23 cm)
-- 기준으로 1 cm ≈ 17.8 studs. 카운터 위 찻잔·양념통·교자 접시·옆 그릇도 같은 비율로 맞췄어요(그릇 20 cm, 찻잔 8 cm).

local Layout = require(script.Parent.RamenRapidsLayout)
local Logic = require(script.Parent.RamenRapidsLogic)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

local PALETTE = MapKitLogic.PALETTE
local BROTH: RGB = { r = 214, g = 140, b = 64 } -- 주황 갈색 국물
local SCALLION: RGB = { r = 96, g = 170, b = 72 }
local YOLK: RGB = { r = 250, g = 170, b = 40 }
local KELP: RGB = { r = 48, g = 96, b = 58 } -- 다시마: 김과 다른 짙은 녹색 (m5-20 ②)
local SESAME: RGB = { r = 36, g = 30, b = 26 } -- 통깨 (m5-20 ②)
local FOG: RGB = { r = 200, g = 140, b = 60 } -- 국물 금빛 안개 (m5-20 ③)
-- m5-24 색
local NOODLE: RGB = { r = 246, g = 214, b = 120 }
local NARUTO_PINK: RGB = { r = 236, g = 110, b = 150 }
local PLASTER: RGB = { r = 232, g = 216, b = 186 } -- 가게 흙벽 (따뜻한 크림)
local BEAM: RGB = { r = 92, g = 60, b = 38 } -- 짙은 나무 기둥·보
local COUNTER: RGB = { r = 196, g = 150, b = 98 } -- 카운터 상판 나무
local WINDOW: RGB = { r = 178, g = 212, b = 250 } -- 창밖 한낮 하늘 (차가운 빛)
local LANTERN_RED: RGB = { r = 214, g = 58, b = 40 }
local TEA: RGB = { r = 132, g = 150, b = 70 }
local CELADON: RGB = { r = 150, g = 176, b = 160 }
local GYOZA: RGB = { r = 236, g = 200, b = 140 }
local GYOZA_CRISP: RGB = { r = 190, g = 120, b = 50 }

local Art = {}

Art.BUDGET = "Extended" :: MapKitLogic.BudgetTier

-- m5-24 맵 조명 (MapLighting.PRESETS["ramen-rapids"]에서 옮겨 와 다듬음). 금빛 한낮 김 + 창 쪽 차가운 빛.
Art.LIGHTING = {
	ClockTime = 12.5,
	Brightness = 2.4,
	Ambient = { r = 118, g = 104, b = 84 },
	OutdoorAmbient = { r = 160, g = 146, b = 120 },
	EnvironmentSpecularScale = 0.8,
	Atmosphere = {
		Density = 0.16,
		Offset = 0.15,
		Color = { r = 228, g = 196, b = 150 },
		Decay = { r = 150, g = 110, b = 70 },
		Glare = 0.1,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.1,
		TintColor = { r = 255, g = 248, b = 232 },
	},
	Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.3 },
	SunRays = { Intensity = 0.05, Spread = 0.7 },
} :: MapLighting.LightingPreset

-- m5-20 안개 패널 이름 상수
Art.FOG_PANEL = "FogPanel"

-- 그릇: 코스 가운데를 중심으로 하는 큰 원. m5-40: 코스가 300 → 446으로 길어져 그릇도 반지름 178 → 251로 키웠어요
-- (출발·결승 끝에서 그릇 벽까지 28은 그대로). 그릇 스케일은 1 cm ≈ 17.8 studs 그대로 — 큰 라멘 그릇(지름 약 28 cm)이에요.
Art.BOWL_CENTER_Z = (Layout.START.front + Layout.FINISH.back) / 2
Art.BOWL_RADIUS = (Layout.START.front - Layout.FINISH.back) / 2 + 28
Art.BOWL_SEGMENTS = 48
-- m5-24 때의 그릇 반지름·중심. 그릇 가장자리에 붙은 소품(김 판·렌게)은 이 기준에서 바깥으로 옮겨요.
local OLD_BOWL_RADIUS = 178
local OLD_BOWL_CENTER_Z = -150
Art.BOWL_RIM_Y = 16
Art.BOWL_BOTTOM_Y = -80

-- m5-24 배경: 카운터 상판 윗면(그릇 굽 아래, 가장 낮은 낙하선 -56보다 34 아래), 가게 벽 자리
Art.COUNTER_TOP_Y = -90
Art.SHOP_HALF_X = 820
Art.SHOP_BACK_Z = -780
Art.SHOP_FRONT_Z = 520
Art.SHOP_TOP_Y = 820

-- 움직이는 판정 파츠와 같이 움직이는 장식은 이 맵에 없어요 (차슈·막대는 판정 파츠 자체, 장식은 전부 고정 자리).

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, s in specs do
		table.insert(list, s)
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

-- 세운 원기둥 (Roblox 원기둥 축은 로컬 X → Z 90°로 세움). offset은 가운데.
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

local function bowl(list: { DecorSpec })
	local height = Art.BOWL_RIM_Y - Art.BOWL_BOTTOM_Y
	local midY = (Art.BOWL_RIM_Y + Art.BOWL_BOTTOM_Y) / 2
	local width = 2 * math.pi * Art.BOWL_RADIUS / Art.BOWL_SEGMENTS + 1
	local porcelain = MapKitLogic.shades(PALETTE.Porcelain)
	for k = 0, Art.BOWL_SEGMENTS - 1 do
		local a = 2 * math.pi * k / Art.BOWL_SEGMENTS
		local cx, cz = math.cos(a), math.sin(a)
		-- CFrame.Angles(0, θ, 0)의 X축이 원의 접선이 되게: θ = -(a + 90°)
		local yaw = -math.deg(a) - 90
		add(list, {
			name = "BowlWall",
			shape = "Block",
			size = v(width, height, 3),
			color = if k % 3 == 0 then MapKitLogic.shade(PALETTE.Porcelain, 0.95) else porcelain.base,
			material = "Marble",
			offset = v(cx * Art.BOWL_RADIUS, midY, Art.BOWL_CENTER_Z + cz * Art.BOWL_RADIUS),
			rotation = v(0, yaw, 0),
			reflectance = 0.06,
		})
		-- 바깥 번개무늬(라이몬) 띠 (m5-24): 위·아래 줄 + 칸마다 갈고리 (번갈아 위/아래에서 꺾여요)
		local outer = Art.BOWL_RADIUS + 1.8
		local function band(name: string, w: number, h: number, y: number, along: number)
			add(list, {
				name = name,
				shape = "Block",
				size = v(w, h, 0.6),
				color = PALETTE.Lacquer,
				material = "SmoothPlastic",
				offset = v(
					cx * outer - math.sin(a) * along * -1,
					y,
					Art.BOWL_CENTER_Z + cz * outer + math.cos(a) * along * -1
				),
				rotation = v(0, yaw, 0),
			})
		end
		local bandY = Art.BOWL_RIM_Y - 12
		band("BowlPattern", width, 1.6, bandY + 6, 0)
		band("BowlPattern", width, 1.6, bandY - 6, 0)
		local hook = if k % 2 == 0 then 1 else -1
		band("BowlPatternKey", 1.6, 8, bandY + hook * 1.4, -width * 0.18)
		band("BowlPatternKey", width * 0.42, 1.6, bandY + hook * 1.2, width * 0.05)
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
		-- 아래 가장자리 둥근 깎임 (m5-24): 바깥 아래 모서리에 비스듬한 판
		add(list, {
			name = "BowlBase",
			shape = "Block",
			size = v(width, 10, 3),
			color = porcelain.dark,
			material = "Marble",
			offset = v(
				cx * (Art.BOWL_RADIUS - 3),
				Art.BOWL_BOTTOM_Y - 3,
				Art.BOWL_CENTER_Z + cz * (Art.BOWL_RADIUS - 3)
			),
			rotation = v(-35, yaw, 0),
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
	-- 그릇 굽 (m5-24): 카운터에 닿는 고리
	addAll(
		list,
		MapKitShapes.ring(
			"BowlFoot",
			Art.BOWL_RADIUS * 0.73,
			8,
			Art.BOWL_BOTTOM_Y - Art.COUNTER_TOP_Y - 1,
			28,
			porcelain.dark,
			"Marble",
			v(0, (Art.BOWL_BOTTOM_Y - 1 + Art.COUNTER_TOP_Y) / 2, Art.BOWL_CENTER_Z)
		)
	)
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
	-- 국물 아래 진한 층 (m5-24): 반투명 수면 밑이 비어 보이지 않게 (불투명)
	add(list, {
		name = "BrothDepth",
		shape = "Cylinder",
		size = v(1, (Art.BOWL_RADIUS - 2) * 2, (Art.BOWL_RADIUS - 2) * 2),
		color = MapKitLogic.shade(BROTH, 0.62),
		material = "SmoothPlastic",
		offset = v(0, Layout.BROTH_Y - 9, Art.BOWL_CENTER_Z),
		rotation = v(0, 0, 90),
	})
	-- 국물 기름 띠 (안쪽 벽 바로 안, 수면 위 0.2): 금빛 고리
	addAll(
		list,
		MapKitShapes.ring(
			"BrothOilRing",
			Art.BOWL_RADIUS - 6,
			6,
			0.3,
			32,
			{ r = 246, g = 186, b = 80 },
			"SmoothPlastic",
			v(0, Layout.BROTH_Y + 0.1, Art.BOWL_CENTER_Z)
		)
	)
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
			color = if i % 3 == 0 then MapKitLogic.shade(SCALLION, 1.25) else SCALLION,
			material = "SmoothPlastic",
			offset = v(at[1], surface + 0.2, at[2]),
			rotation = v(0, i * 25, 90),
			anim = if i % 2 == 0 then { kind = "Bob", period = 3 + (i % 4) * 0.7, amount = 0.25 } else nil,
		})
	end
	-- 김: 국물에 비스듬히 꽂힌 검은 판
	local noris = { { -42, -132, 20 }, { 48, -190, -15 }, { -52, -240, 10 }, { 56, -262, -25 }, { -60, -170, 5 } }
	for i, at in noris do
		add(list, {
			name = "Nori",
			shape = "Block",
			size = v(10, 14, 0.4),
			color = MapKitLogic.shade(PALETTE.Nori, if i % 2 == 0 then 1.35 else 1.15),
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

-- 급류 양옆(|x| >= 30, 기존 floatingToppings과 같은 대역)에 다시마·통깨·젓가락 받침을 더해요
-- (m5-20 ②, 제안서 §2-2: 가장 단조로운 맵이라 작은 소품을 반복해 밀도를 보강).
local function floatingGarnish(list: { DecorSpec })
	local surface = Layout.BROTH_Y
	-- 다시마 12개: 김과 다른 짙은 녹색 띠
	for i = 1, 12 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * (34 + (i % 4) * 9)
		local z = -128 - i * 13
		add(list, {
			name = "Kombu",
			shape = "Block",
			size = v(9, 0.3, 3.5),
			color = KELP,
			material = "SmoothPlastic",
			offset = v(x, surface + 0.15, z),
			rotation = v(0, i * 31, 0),
		})
	end
	-- 통깨 20개: 작은 검은 공 (초저비용, 지름 0.3)
	for i = 1, 20 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * (32 + (i % 5) * 7)
		local z = -122 - i * 8
		add(list, {
			name = "SesameSeed",
			shape = "Ball",
			size = v(0.3, 0.3, 0.3),
			color = SESAME,
			material = "SmoothPlastic",
			offset = v(x, surface + 0.3, z),
		})
	end
	-- 젓가락 받침 6개: 작은 도자기 조각
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * (38 + i * 4)
		local z = -140 - i * 24
		add(list, {
			name = "ChopstickRest",
			shape = "Block",
			size = v(3, 0.8, 1.4),
			color = PALETTE.Porcelain,
			material = "SmoothPlastic",
			offset = v(x, surface + 0.4, z),
			rotation = v(0, i * 17, 0),
		})
	end
end

-- m5-20 ③ 국물 금빛 안개 패널. m5-24: QA m5-20 B2(그릇 밖으로 삐져나옴)·B5(Glass 뒤 투명 물체가 안 보임) 때문에
-- 국물 수면 아래(그릇 안, 불투명 BrothDepth 위)로 내려 국물 속 금빛 깊이로만 남겨요. 분위기는 Art.LIGHTING의 Atmosphere가 맡아요.
-- 패널은 모두 그릇 벽 안쪽(반지름 178)이고, 위 카메라에서 보면 언제나 국물 수면 뒤라 그 뒤에 가려질 투명 물체가 없어요.
local function addFogPanels(list: { DecorSpec })
	local centerZ = Art.BOWL_CENTER_Z
	local y = Layout.BROTH_Y - 5
	local function panel(x: number, z: number, sx: number, sz: number)
		add(list, {
			name = Art.FOG_PANEL,
			shape = "Block",
			size = v(sx, 6, sz),
			color = FOG,
			material = "Glass",
			offset = v(x, y, z),
			transparency = 0.88,
		})
	end
	-- m5-40: 그릇이 커진 만큼 늘려요 (여전히 그릇 벽 안쪽)
	local k = Art.BOWL_RADIUS / OLD_BOWL_RADIUS
	panel(-130 * k, centerZ, 2, 230 * k)
	panel(130 * k, centerZ, 2, 230 * k)
	panel(0, centerZ - 140 * k, 200 * k, 2)
end

-- 그릇 위를 가로지르는 거대한 젓가락 한 쌍 (머리 위 20 이상)
Art.CHOPSTICK_YAW = 22
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

-- m5-24 ④ 젓가락이 들어 올린 면 커튼: 오른쪽(x 66~104) 젓가락 아래로 국물까지 늘어진 면 가닥 + 위 집힌 뭉치
Art.NOODLE_CURTAIN = "NoodleStrand"
local function noodleCurtain(list: { DecorSpec })
	-- 첫 젓가락(z 중심 -174, yaw 22) 위의 점
	local yaw = math.rad(22)
	local function onStick(d: number): (number, number)
		return d * math.cos(yaw), Art.BOWL_CENTER_Z - 24 - d * math.sin(yaw)
	end
	local top = 32
	local bottom = Layout.BROTH_Y + 0.5
	local shades = MapKitLogic.shades(NOODLE)
	for i = 0, 13 do
		local d = 70 + i * 3 + (i % 3) * 0.8
		local x, z = onStick(d)
		local len = top - bottom - (i % 4) * 3
		local tilt = ((i * 37) % 9) - 4
		add(list, {
			name = Art.NOODLE_CURTAIN,
			shape = "Cylinder",
			size = v(len, 1.6, 1.6),
			color = if i % 3 == 0 then shades.light elseif i % 3 == 1 then shades.base else shades.dark,
			material = "SmoothPlastic",
			offset = v(x + (i % 2) * 1.5, top - len / 2, z + (i % 2) * 2),
			rotation = v(tilt, 0, 90),
			anim = { kind = "Sway", period = 4 + (i % 5) * 0.6, amount = 2.5, axis = "X" },
		})
	end
	-- 젓가락이 집은 면 뭉치 (가로로 감긴 고리)
	for i = 0, 5 do
		local x, z = onStick(82 + i * 4)
		add(
			list,
			part(
				"NoodleBundle",
				"Cylinder",
				v(16, 2, 2),
				if i % 2 == 0 then shades.base else shades.light,
				"SmoothPlastic",
				v(x, top + 1 + (i % 2), z),
				v(0, 22 + i * 30, 12)
			)
		)
	end
	-- 국물에 닿는 자리의 면 소용돌이 + 김
	local x, z = onStick(90)
	addAll(
		list,
		MapKitShapes.ring("NoodlePool", 9, 1.4, 1.2, 12, shades.dark, "SmoothPlastic", v(x, Layout.BROTH_Y + 0.4, z))
	)
	add(list, {
		name = "NoodleSteam",
		shape = "Block",
		size = v(10, 0.4, 10),
		color = BROTH,
		material = "SmoothPlastic",
		offset = v(x, Layout.BROTH_Y + 0.3, z),
		transparency = 1,
		particle = "SteamThick",
		particleRate = 3,
	})
	-- 그림자 조명: 면 커튼 위 매달린 등 (좁은 스폿, 고정 파츠)
	local lx, lz = onStick(88)
	add(list, upright("CurtainLampCord", 600, 1, BEAM, "SmoothPlastic", v(lx, 70 + 300, lz)))
	add(list, upright("CurtainLampShade", 14, 36, { r = 40, g = 36, b = 34 }, "Metal", v(lx, 74, lz)))
	add(list, {
		name = "CurtainLampBulb",
		shape = "Ball",
		size = v(12, 12, 12),
		color = { r = 255, g = 226, b = 160 },
		material = "Neon",
		offset = v(lx, 66, lz),
		light = {
			kind = "Spot",
			color = { r = 255, g = 222, b = 170 },
			brightness = 3,
			range = 60,
			angle = 70,
			face = "Bottom",
			shadows = true,
		},
	})
end

-- m5-24 ③ 반숙 계란 반쪽 둘: 흰자 단면 원판 + 테두리 + 노른자 (Glass 반사)
local function softEggs(list: { DecorSpec })
	for i, at in { { 96, -118, 0 }, { -104, -262, 0 } } do
		local x, z, tilt = at[1], at[2], at[3]
		local y = Layout.BROTH_Y + 2
		add(
			list,
			part(
				"SoftEggWhite",
				"Cylinder",
				v(5, 52, 52),
				PALETTE.Rice,
				"SmoothPlastic",
				v(x, y, z),
				v(0, i * 40, 90 + tilt)
			)
		)
		add(
			list,
			part(
				"SoftEggEdge",
				"Cylinder",
				v(3, 56, 56),
				PALETTE.RiceShade,
				"SmoothPlastic",
				v(x, y - 2.5, z),
				v(0, i * 40, 90 + tilt)
			)
		)
		add(list, {
			name = "SoftEggYolk",
			shape = "Ball",
			size = v(26, 26, 26),
			color = YOLK,
			material = "SmoothPlastic",
			offset = v(x, y - 1.5, z),
			reflectance = 0.2,
		})
		add(
			list,
			part(
				"SoftEggYolkRim",
				"Cylinder",
				v(1, 30, 30),
				PALETTE.EggDark,
				"SmoothPlastic",
				v(x, y + 2.2, z),
				v(0, 0, 90 + tilt)
			)
		)
	end
end

-- m5-24 ② 거대 나루토 소용돌이 섬 (코스 왼쪽 국물 위): 흰 원판 + 톱니 가장자리 + 분홍 소용돌이(고정) + 도는 막대 하나
local function narutoIsland(list: { DecorSpec })
	local cx, cz = -100, -175
	local top = Layout.BROTH_Y + 3
	add(list, upright("NarutoIsland", 6, 64, PALETTE.Rice, "SmoothPlastic", v(cx, top - 3, cz)))
	for k = 0, 17 do
		local a = 2 * math.pi * k / 18
		add(
			list,
			part(
				"NarutoIslandRidge",
				"Wedge",
				v(6, 5, 4),
				PALETTE.RiceShade,
				"SmoothPlastic",
				v(cx + math.cos(a) * 32.5, top - 3, cz + math.sin(a) * 32.5),
				v(0, -math.deg(a) + 90, 0)
			)
		)
	end
	-- 소용돌이: 바깥에서 안쪽으로 감기는 짧은 판들
	for k = 0, 21 do
		local a = k * 0.55
		local r = 27 - k * 1.15
		add(
			list,
			part(
				"NarutoIslandSwirl",
				"Block",
				v(r * 0.6 + 2.5, 0.3, 4),
				NARUTO_PINK,
				"SmoothPlastic",
				v(cx + math.cos(a) * r, top + 0.15, cz + math.sin(a) * r),
				v(0, -math.deg(a) - 90, 0)
			)
		)
	end
	add(list, {
		name = "NarutoIslandSpinner",
		shape = "Block",
		size = v(18, 0.4, 2.5),
		color = MapKitLogic.shade(NARUTO_PINK, 0.8),
		material = "SmoothPlastic",
		offset = v(cx, top + 0.35, cz),
		anim = { kind = "Spin", period = 20, amount = 0 },
	})
end

-- ── m5-40 새 구간 장식 (F 젓가락 다리 · G 렌게 계단 · H 두 번째 급류) ──────────────────────
-- 판정 파츠(뗏목·젓가락·받침·렌게 발판·급류 판)는 RamenRapids.luau에 있고, 장식은 그 윗면보다 아래나 코스 시야 상자 밖에만 둬요.
local RENGE_STRIPE: RGB = PALETTE.PorcelainRim
local function lengthSections(list: { DecorSpec })
	local top = Layout.platformTop()
	local surface = Layout.BROTH_Y
	-- F 유부 뗏목: 부푼 가장자리 (판정 윗면보다 0.2 아래, 옆으로 0.8 더 넓게)
	local raft = Layout.CHOP_RAFT
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RaftPuff",
			v(raft.width + 1.6, 2.4, raft.front - raft.back + 1.6),
			MapKitLogic.shade({ r = 226, g = 176, b = 92 }, 0.82),
			"Sand",
			v(0, top - 1.4, (raft.front + raft.back) / 2),
			{ radius = 0.9 }
		)
	)
	-- 젓가락: 손잡이 쪽 짙은 나무 띠(윗면 아래 옆면) + 국물에 닿는 자리 물결 고리
	for i, stick in Logic.chopsticks() do
		local dx, dz = stick.x1 - stick.x0, stick.z1 - stick.z0
		local length = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dx, -dz))
		local ux, uz = dx / length, dz / length
		for _, along in { 0.12, 0.2 } do
			add(
				list,
				part(
					"ChopstickBand",
					"Block",
					v(Layout.CHOPSTICK_WIDTH + 0.12, 0.5, 0.8),
					PALETTE.WoodDark,
					"Wood",
					v(stick.x0 + ux * length * along, top - 0.9, stick.z0 + uz * length * along),
					v(0, yaw, 0)
				)
			)
		end
		local mx, mz = stick.x0 + ux * length * 0.6, stick.z0 + uz * length * 0.6
		addAll(
			list,
			MapKitShapes.ring(
				"ChopstickRipple",
				2.4 + (i % 2) * 0.6,
				0.35,
				0.12,
				8,
				MapKitLogic.shade(BROTH, 1.18),
				"SmoothPlastic",
				v(mx, surface + 0.12, mz)
			)
		)
	end
	-- 젓가락 받침: 물고기 모양 도자기 (양끝 꼬리·머리, 남색 띠, 국물 속 다리)
	local rest = Layout.CHOP_REST
	local restZ = (rest.front + rest.back) / 2
	local restDepth = rest.front - rest.back
	local half = rest.width / 2
	add(
		list,
		part(
			"RestBand",
			"Block",
			v(rest.width + 0.2, 0.6, restDepth + 0.2),
			RENGE_STRIPE,
			"SmoothPlastic",
			v(0, top - 1.3, restZ)
		)
	)
	add(
		list,
		part(
			"RestTail",
			"Wedge",
			v(restDepth, 2, 3.4),
			PALETTE.Porcelain,
			"Marble",
			v(half + 1.7, top - 1.4, restZ),
			v(0, 90, 0)
		)
	)
	add(
		list,
		part(
			"RestTail",
			"Wedge",
			v(restDepth, 2, 3.4),
			PALETTE.Porcelain,
			"Marble",
			v(half + 1.7, top - 3.4, restZ),
			v(180, 90, 0)
		)
	)
	add(list, {
		name = "RestHead",
		shape = "Ball",
		size = v(5, 3.6, restDepth),
		color = PALETTE.Porcelain,
		material = "Marble",
		offset = v(-half - 0.6, top - 2, restZ),
	})
	add(
		list,
		part("RestEye", "Ball", v(0.9, 0.9, 0.9), RENGE_STRIPE, "SmoothPlastic", v(-half - 2.2, top - 1.6, restZ - 1.4))
	)
	for _, x in { -4.5, 4.5 } do
		add(
			list,
			part("RestFoot", "Block", v(3, 3, restDepth - 1.5), PALETTE.RiceShade, "Marble", v(x, top - 3.5, restZ))
		)
	end

	-- G 렌게 계단: 숟가락 몸통(윗면 아래 둥근 그릇) + 남색 띠 + 바깥으로 뻗은 손잡이 + 국물에서 받친 면 더미
	local noodle = MapKitLogic.shades(NOODLE)
	for i, step in Layout.RENGE_STEPS do
		local stepTop = Layout.rengeStepTop(i)
		local depth = step.front - step.back
		local z = (step.front + step.back) / 2
		add(list, {
			name = "RengeBowl",
			shape = "Ball",
			size = v(step.width + 1.6, 3, depth + 1.6),
			color = PALETTE.Porcelain,
			material = "Marble",
			offset = v(step.x, stepTop - 1.7, z),
			reflectance = 0.05,
		})
		add(
			list,
			part(
				"RengeBand",
				"Block",
				v(step.width + 0.24, 0.5, depth + 0.24),
				RENGE_STRIPE,
				"SmoothPlastic",
				v(step.x, stepTop - 1.35, z)
			)
		)
		local side = if i % 2 == 1 then 1 else -1
		local baseX = side * 8.4
		local handleLength = 15
		addAll(
			list,
			MapKitShapes.capsule(
				"RengeHandle",
				handleLength,
				2.6,
				PALETTE.Porcelain,
				"Marble",
				v(baseX + side * handleLength / 2, stepTop - 0.2, z),
				v(0, 0, side * 14)
			)
		)
		add(
			list,
			part(
				"RengeHandleStripe",
				"Block",
				v(3, 2.8, 2.8),
				RENGE_STRIPE,
				"SmoothPlastic",
				v(baseX + side * (handleLength - 2.5), stepTop + 2.6, z),
				v(0, 0, side * 14)
			)
		)
		-- 국물에서 올라온 면 더미가 숟가락을 받쳐요
		local moundTop = stepTop - 3.2
		local h = moundTop - (surface - 1)
		add(
			list,
			upright(
				"NoodleMound",
				h,
				step.width - 1,
				if i % 2 == 0 then noodle.base else noodle.light,
				"SmoothPlastic",
				v(step.x, surface - 1 + h / 2, z)
			)
		)
		add(
			list,
			part(
				"NoodleMoundLoop",
				"Cylinder",
				v(step.width + 3, 1.2, 1.2),
				noodle.dark,
				"SmoothPlastic",
				v(step.x, surface + h * 0.45, z + 1),
				v(0, 20 + i * 35, 0)
			)
		)
	end

	-- H 두 번째 급류: 미끄럼틀 아래 도자기 홈통(판 바로 밑) + 남색 줄
	local slope = Layout.RAPIDS_SLOPE_DEG
	local r2 = Layout.RAPIDS2
	local r2Depth = r2.front - r2.back
	local r2Center = r2.front - r2Depth / 2
	local r2Length = r2Depth / math.cos(math.rad(slope))
	local ny, nz = math.cos(math.rad(slope)), -math.sin(math.rad(slope)) -- 판 윗면 법선 (로컬)
	local function onSlide(z: number, depthBelow: number): Vec3
		return v(0, Layout.rapids2HeightAt(z) - ny * depthBelow, z - nz * depthBelow)
	end
	-- 홈통은 코스 시야 상자(경사 5칸)와 같은 5토막으로 — 기운 판 하나의 경계 상자가 위 칸 시야를 덮지 않게
	local pieces = 5
	for k = 0, pieces - 1 do
		local z = r2.front - (k + 0.5) * r2Depth / pieces
		add(
			list,
			part(
				"Rapids2Trough",
				"Block",
				v(Layout.RAPIDS2_WIDTH + 3, 2.4, r2Length / pieces - 0.05),
				PALETTE.Porcelain,
				"Marble",
				onSlide(z, 3.2),
				v(-slope, 0, 0)
			)
		)
	end
	for _, side in { -1, 1 } do
		local c = onSlide(r2Center, 3.2)
		add(
			list,
			part(
				"Rapids2Stripe",
				"Block",
				v(0.3, 0.7, r2Length - 1),
				RENGE_STRIPE,
				"SmoothPlastic",
				v(side * (Layout.RAPIDS2_WIDTH / 2 + 1.65), c.y, c.z),
				v(-slope, 0, 0)
			)
		)
	end

	-- 히어로: 오른쪽 위에서 국물을 붓는 거대한 국자 (28도 기울어 왼쪽 입술로 국물 줄기 — 급류 벽 밖 국물로, 김)
	local lx, lz = 30, -384
	local cupY = top + 30
	local tilt = math.rad(28)
	local ux, uy = -math.sin(tilt), math.cos(tilt) -- 기운 국자의 위 방향
	local px, py = math.cos(tilt), math.sin(tilt) -- 입술 평면에서 오른쪽(손잡이 쪽)
	local cupRadius = 11.5
	add(list, {
		name = "LadleCup",
		shape = "Cylinder",
		size = v(7, cupRadius * 2, cupRadius * 2),
		color = PALETTE.Steel,
		material = "Metal",
		offset = v(lx - ux * 3.5, cupY - uy * 3.5, lz),
		rotation = v(0, 0, 90 + 28),
		reflectance = 0.25,
	})
	add(list, {
		name = "LadleCupBottom",
		shape = "Ball",
		size = v(cupRadius * 1.7, 9, cupRadius * 1.7),
		color = MapKitLogic.shade(PALETTE.Steel, 0.9),
		material = "Metal",
		offset = v(lx - ux * 7, cupY - uy * 7, lz),
		rotation = v(0, 0, 28),
		reflectance = 0.25,
	})
	add(list, {
		name = "LadleCupRim",
		shape = "Cylinder",
		size = v(1.2, cupRadius * 2 + 1.2, cupRadius * 2 + 1.2),
		color = MapKitLogic.shade(PALETTE.Steel, 1.12),
		material = "Metal",
		offset = v(lx, cupY, lz),
		rotation = v(0, 0, 90 + 28),
		reflectance = 0.3,
	})
	add(list, {
		name = "LadleBroth",
		shape = "Cylinder",
		size = v(0.6, cupRadius * 2 - 2, cupRadius * 2 - 2),
		color = BROTH,
		material = "Glass",
		offset = v(lx + ux * 0.2, cupY + uy * 0.2 - 0.6, lz),
		rotation = v(0, 0, 90 + 28),
		transparency = 0.15,
	})
	-- 손잡이: 오른쪽 입술에서 바깥 위로 (그릇 테두리 너머)
	local hx, hy = lx + px * cupRadius, cupY + py * cupRadius
	local handleLength = 150
	addAll(
		list,
		MapKitShapes.capsule(
			"LadleHandle",
			handleLength,
			3.2,
			PALETTE.Steel,
			"Metal",
			v(hx + math.cos(math.rad(30)) * handleLength / 2, hy + math.sin(math.rad(30)) * handleLength / 2, lz),
			v(0, 0, 30)
		)
	)
	-- 왼쪽 입술에서 떨어지는 국물 줄기
	local sx, sy = lx - px * cupRadius, cupY - py * cupRadius
	local streamTop, streamBottom = sy, surface
	add(list, {
		name = "LadleStream",
		shape = "Cylinder",
		size = v(streamTop - streamBottom, 3.2, 3.2),
		color = MapKitLogic.shade(BROTH, 1.08),
		material = "Glass",
		offset = v(sx, (streamTop + streamBottom) / 2, lz),
		rotation = v(0, 0, 90),
		transparency = 0.2,
		anim = { kind = "Pulse", period = 0.9, amount = 0.06 },
	})
	addAll(
		list,
		MapKitShapes.ring(
			"LadleSplash",
			4.5,
			1,
			0.8,
			10,
			MapKitLogic.shade(BROTH, 1.25),
			"SmoothPlastic",
			v(sx, surface + 0.3, lz)
		)
	)
	add(list, {
		name = "LadleSteam",
		shape = "Block",
		size = v(8, 0.4, 8),
		color = BROTH,
		material = "SmoothPlastic",
		offset = v(sx, surface + 0.5, lz),
		transparency = 1,
		particle = "SteamThick",
		particleRate = 3,
	})

	-- 렌게 계단 위 종이 등 (따뜻한 빛의 원인, 흔들려요)
	local lanternX, lanternZ = 17, -350
	add(list, upright("StairLanternCord", 70, 0.5, BEAM, "SmoothPlastic", v(lanternX, top + 62, lanternZ)))
	add(list, {
		name = "StairLantern",
		shape = "Cylinder",
		size = v(12, 10, 10),
		color = { r = 255, g = 232, b = 196 },
		material = "Neon",
		offset = v(lanternX, top + 22, lanternZ),
		rotation = v(0, 0, 90),
		light = { kind = "Point", color = { r = 255, g = 196, b = 130 }, brightness = 1.6, range = 50 },
		anim = { kind = "Sway", period = 5, amount = 2, axis = "X" },
	})
	add(list, upright("StairLanternCap", 1.6, 7, PALETTE.Nori, "SmoothPlastic", v(lanternX, top + 28.5, lanternZ)))
	add(list, upright("StairLanternCap", 1.6, 7, PALETTE.Nori, "SmoothPlastic", v(lanternX, top + 15.5, lanternZ)))

	-- 새 구간 양옆 고명 (|x| >= 30, 국물 위): 파·멘마·어묵 조각·김
	local rng = MapKitShapes.rng(40)
	for i = 1, 16 do
		local sideX = if i % 2 == 0 then 1 else -1
		local x = sideX * (32 + rng:range(0, 44))
		local z = -300 - i * 8 + rng:range(-3, 3)
		local kind = i % 4
		if kind == 0 then
			add(
				list,
				part(
					"Menma",
					"Block",
					v(7, 1, 2.2),
					{ r = 196, g = 150, b = 80 },
					"Wood",
					v(x, surface + 0.4, z),
					v(0, i * 29, 0)
				)
			)
		elseif kind == 1 then
			add(
				list,
				part(
					"Scallion",
					"Cylinder",
					v(0.6, 3.5, 3.5),
					SCALLION,
					"SmoothPlastic",
					v(x, surface + 0.2, z),
					v(0, i * 25, 90)
				)
			)
		elseif kind == 2 then
			add(list, upright("FishCake", 1, 6, PALETTE.Rice, "SmoothPlastic", v(x, surface + 0.4, z)))
			add(list, upright("FishCakeSwirl", 1.1, 3, NARUTO_PINK, "SmoothPlastic", v(x, surface + 0.45, z)))
		else
			-- 차슈 조각 (지방 테 + 살코기)
			add(list, upright("ChashuSlice", 1.2, 9, { r = 150, g = 82, b = 56 }, "Slate", v(x, surface + 0.3, z)))
			add(
				list,
				upright(
					"ChashuFat",
					1.3,
					5,
					{ r = 236, g = 208, b = 176 },
					"SmoothPlastic",
					v(x + 1, surface + 0.35, z)
				)
			)
		end
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

-- m5-24 ⑤ 그릇 가장자리에 세워 꽂은 큰 김 판 (왼쪽) + 테두리에 걸친 렌게 숟가락 (오른쪽)
local function rimPropsAt(list: { DecorSpec })
	-- 김 판: 국물에서 테두리 위로, 바깥쪽으로 기울어요
	add(list, part("RimNori", "Block", v(70, 150, 1.5), PALETTE.Nori, "Fabric", v(-158, 30, -96), v(0, 70, -14)))
	add(
		list,
		part(
			"RimNoriEdge",
			"Block",
			v(70, 6, 1.7),
			MapKitLogic.shade(PALETTE.Nori, 1.4),
			"Fabric",
			v(-176, 101, -103),
			v(0, 70, -14)
		)
	)
	add(
		list,
		part("RimNoriSesame", "Block", v(8, 3, 1.8), PALETTE.Rice, "SmoothPlastic", v(-166, 62, -98), v(0, 70, -14))
	)
	-- 렌게: 머리(둥근 상자)는 국물 위, 손잡이는 테두리 너머로
	addAll(
		list,
		MapKitShapes.roundedBox(
			"RimRenge",
			v(54, 10, 70),
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(150, Layout.BROTH_Y + 6, -40),
			{ radius = 4, style = "vertical", rotation = v(0, 30, -8) }
		)
	)
	addAll(
		list,
		MapKitShapes.capsule(
			"RimRengeHandle",
			120,
			14,
			PALETTE.Porcelain,
			"SmoothPlastic",
			v(200, 4, -6),
			v(0, -60, 22)
		)
	)
	add(
		list,
		part("RimRengeStripe", "Block", v(16, 15, 15), PALETTE.Lacquer, "SmoothPlastic", v(232, 17, 13), v(0, -60, 22))
	)
end

-- m5-40: 그릇이 커지고 중심이 옮겨져서, 가장자리 소품 무리를 각자 바깥 방향(옛 중심 기준)으로 반지름 차이만큼 통째로 옮겨요
local function rimProps(list: { DecorSpec })
	local raw: { DecorSpec } = {}
	rimPropsAt(raw)
	local grow = Art.BOWL_RADIUS - OLD_BOWL_RADIUS
	local dropZ = Art.BOWL_CENTER_Z - OLD_BOWL_CENTER_Z
	for _, spec in raw do
		-- 김 판(왼쪽 무리)은 (-158, -96), 렌게(오른쪽 무리)는 (150, -40) 방향으로
		local left = spec.offset.x < 0
		local ax, az = if left then -158 else 150, if left then -96 else -40
		local rx, rz = ax, az - OLD_BOWL_CENTER_Z
		local len = math.sqrt(rx * rx + rz * rz)
		local moved = table.clone(spec)
		moved.offset = v(spec.offset.x + rx / len * grow, spec.offset.y, spec.offset.z + dropZ + rz / len * grow)
		table.insert(list, moved)
	end
end

-- m5-24 배경: 카운터 상판 (나무 판 여러 장, 결은 z 방향)
local function counter(list: { DecorSpec })
	local depth = Art.SHOP_FRONT_Z - Art.SHOP_BACK_Z
	local centerZ = (Art.SHOP_FRONT_Z + Art.SHOP_BACK_Z) / 2
	local planks = 8
	local width = Art.SHOP_HALF_X * 2 / planks
	local wood = MapKitLogic.shades(COUNTER)
	for i = 0, planks - 1 do
		local x = -Art.SHOP_HALF_X + width * (i + 0.5)
		local color = if i % 4 == 1
			then wood.light
			elseif i % 4 == 3 then MapKitLogic.shade(COUNTER, 0.86)
			else wood.base
		add(
			list,
			part(
				"CounterPlank",
				"Block",
				v(width - 1.5, 14, depth),
				color,
				"WoodPlanks",
				v(x, Art.COUNTER_TOP_Y - 7, centerZ)
			)
		)
		-- 판 사이 홈
		add(
			list,
			part(
				"CounterGroove",
				"Block",
				v(2, 13, depth),
				wood.dark,
				"Wood",
				v(-Art.SHOP_HALF_X + width * i, Art.COUNTER_TOP_Y - 7.2, centerZ)
			)
		)
	end
	-- 가게 바닥 (카운터 아래 멀리, 거의 안 보이지만 빈 공중 방지)
	add(
		list,
		part(
			"ShopFloor",
			"Block",
			v(Art.SHOP_HALF_X * 2, 4, depth),
			{ r = 70, g = 58, b = 50 },
			"Slate",
			v(0, Art.COUNTER_TOP_Y - 200, centerZ)
		)
	)
end

-- 가게 벽 한 면: 흙벽 + 기둥 + 보 (along = 벽이 뻗는 길이, 로컬 X)
local function shopWall(list: { DecorSpec }, name: string, center: Vec3, along: number, yaw: number, posts: number)
	local height = Art.SHOP_TOP_Y - Art.COUNTER_TOP_Y + 200
	local baseY = Art.COUNTER_TOP_Y - 200
	local wall = {}
	table.insert(wall, part(name, "Block", v(along, height, 10), PLASTER, "Plaster", v(0, baseY + height / 2, 0)))
	-- 아래 허리판 (짙은 나무) + 위 보 두 줄
	table.insert(
		wall,
		part(name .. "Wainscot", "Block", v(along, 140, 12), BEAM, "WoodPlanks", v(0, Art.COUNTER_TOP_Y + 70, -1))
	)
	table.insert(wall, part(name .. "Beam", "Block", v(along, 26, 18), BEAM, "Wood", v(0, 470, -4)))
	table.insert(
		wall,
		part(
			name .. "Beam",
			"Block",
			v(along, 30, 18),
			MapKitLogic.shade(BEAM, 0.8),
			"Wood",
			v(0, Art.SHOP_TOP_Y - 15, -4)
		)
	)
	for i = 0, posts do
		local x = -along / 2 + along * i / posts
		table.insert(
			wall,
			part(
				name .. "Post",
				"Block",
				v(26, height, 20),
				MapKitLogic.shade(BEAM, if i % 2 == 0 then 1 else 0.85),
				"Wood",
				v(x, baseY + height / 2, -5)
			)
		)
	end
	addAll(list, MapKitShapes.transform(wall, center, v(0, yaw, 0)))
end

-- 뒤쪽(결승 너머) 벽: 주방 창구(따뜻한 빛) + 노렌 + 나무 메뉴 패 + 붉은 등롱
local function backWall(list: { DecorSpec })
	local z = Art.SHOP_BACK_Z
	shopWall(list, "ShopBackWall", v(0, 0, z), Art.SHOP_HALF_X * 2, 0, 4)
	-- 주방 창구: 따뜻한 빛 (Neon은 안쪽 띠만)
	add(
		list,
		part("KitchenPass", "Block", v(700, 230, 6), { r = 255, g = 200, b = 130 }, "SmoothPlastic", v(0, 150, z + 6))
	)
	add(list, {
		name = "KitchenPassGlow",
		shape = "Block",
		size = v(660, 10, 6),
		color = { r = 255, g = 214, b = 150 },
		material = "Neon",
		offset = v(0, 255, z + 8),
		light = {
			kind = "Surface",
			color = { r = 255, g = 200, b = 140 },
			brightness = 2,
			range = 16,
			angle = 120,
			face = "Back",
		},
	})
	add(
		list,
		part("KitchenPassLedge", "Block", v(740, 14, 50), MapKitLogic.shade(BEAM, 1.15), "Wood", v(0, 30, z + 26))
	)
	-- 창구 안 실루엣: 큰 육수 냄비 둘 + 국자 + 김
	for i, x in { -220, 200 } do
		add(list, upright("KitchenPot", 120, 150, PALETTE.CastIron, "Metal", v(x, 100, z + 12)))
		add(list, upright("KitchenPotRim", 8, 160, PALETTE.Steel, "Metal", v(x, 162, z + 12)))
		add(list, {
			name = "KitchenPotSteam",
			shape = "Block",
			size = v(80, 2, 40),
			color = PALETTE.Steel,
			material = "Metal",
			offset = v(x, 168, z + 14),
			transparency = 1,
			particle = "SteamThick",
			particleRate = if i == 1 then 3 else 2,
		})
	end
	for i, x in { -40, 10, 60 } do
		add(
			list,
			part("KitchenLadle", "Block", v(6, 110, 6), PALETTE.Steel, "Metal", v(x, 200, z + 10), v(0, 0, (i - 2) * 6))
		)
		add(list, upright("KitchenLadleCup", 16, 30, PALETTE.Steel, "Metal", v(x, 140, z + 10)))
	end
	-- 노렌: 남색 천 5장, 가운데 흰 동그라미 표시
	local norenTop = 345
	for i = -2, 2 do
		local x = i * 142
		add(list, {
			name = "ShopNoren",
			shape = "Block",
			size = v(136, 200, 3),
			color = if i % 2 == 0 then PALETTE.Noren else MapKitLogic.shade(PALETTE.Noren, 1.12),
			material = "Fabric",
			offset = v(x, norenTop - 100, z + 40),
			anim = { kind = "Sway", period = 6 + (i + 2) * 0.4, amount = 1.2, axis = "X" },
		})
	end
	-- 가운데 흰 동그라미 (앞을 보는 원판) + 남색 획
	local markY = norenTop - 95
	add(
		list,
		part("ShopNorenMark", "Cylinder", v(4, 110, 110), PALETTE.Rice, "Fabric", v(0, markY, z + 43), v(0, 90, 0))
	)
	add(list, part("ShopNorenMark", "Block", v(64, 12, 4), PALETTE.Noren, "Fabric", v(0, markY + 22, z + 46)))
	add(
		list,
		part("ShopNorenMark", "Block", v(12, 56, 4), PALETTE.Noren, "Fabric", v(4, markY - 6, z + 46), v(0, 0, -12))
	)
	add(
		list,
		part("ShopNorenMark", "Block", v(40, 10, 4), PALETTE.Noren, "Fabric", v(-6, markY - 30, z + 46), v(0, 0, 18))
	)
	add(list, part("ShopNorenRod", "Cylinder", v(760, 10, 10), PALETTE.WoodDark, "Wood", v(0, norenTop + 4, z + 40)))
	-- 메뉴 패: 양옆에 세로 나무 패 (글씨 = 짙은 띠, 아래 빨간 값표)
	for side = -1, 1, 2 do
		for k = 0, 4 do
			local x = side * (470 + k * 66)
			local wood = if k % 2 == 0 then PALETTE.WoodLight else PALETTE.Wood
			add(
				list,
				part("MenuTag", "Block", v(56, 200, 6), wood, "Wood", v(x, 560, z + 12), v(0, 0, (k % 3 - 1) * 1.5))
			)
			for line = 0, 2 do
				add(
					list,
					part(
						"MenuTagText",
						"Block",
						v(10, 34 - line * 6, 7),
						PALETTE.SoyDark,
						"SmoothPlastic",
						v(x, 620 - line * 42, z + 12)
					)
				)
			end
			add(list, part("MenuTagPrice", "Block", v(40, 22, 7), PALETTE.Lacquer, "SmoothPlastic", v(x, 486, z + 12)))
		end
	end
	-- 붉은 등롱 둘 (주방 창구 양옆, 고정 걸이에 흔들림)
	for side = -1, 1, 2 do
		local x = side * 450
		add(list, upright("LanternHook", 120, 3, PALETTE.Nori, "Metal", v(x, 400, z + 70)))
		add(list, {
			name = "ShopLantern",
			shape = "Cylinder",
			size = v(130, 100, 100),
			color = LANTERN_RED,
			material = "Fabric",
			offset = v(x, 270, z + 70),
			rotation = v(0, 0, 90),
			light = { kind = "Point", color = { r = 255, g = 150, b = 90 }, brightness = 2, range = 60 },
			anim = { kind = "Sway", period = 5.5, amount = 2, axis = "X" },
		})
		add(list, upright("ShopLanternCap", 12, 70, PALETTE.Nori, "SmoothPlastic", v(x, 341, z + 70)))
		add(list, upright("ShopLanternCap", 12, 70, PALETTE.Nori, "SmoothPlastic", v(x, 199, z + 70)))
		add(list, part("ShopLanternText", "Block", v(14, 70, 101), PALETTE.Nori, "SmoothPlastic", v(x, 270, z + 70)))
	end
end

-- 오른쪽 벽: 큰 격자창 셋 (차가운 한낮 빛 — 따뜻한 등과 온도 대비)
local function windowWall(list: { DecorSpec })
	local x = Art.SHOP_HALF_X
	shopWall(
		list,
		"ShopSideWall",
		v(x, 0, (Art.SHOP_FRONT_Z + Art.SHOP_BACK_Z) / 2),
		Art.SHOP_FRONT_Z - Art.SHOP_BACK_Z,
		90,
		4
	)
	for i, z in { -560, -240, 80 } do
		local win = {}
		table.insert(
			win,
			{
				name = "ShopWindow",
				shape = "Block",
				size = v(280, 300, 4),
				color = WINDOW,
				material = "SmoothPlastic",
				offset = v(0, 250, 8),
				light = if i ~= 3
					then {
						kind = "Surface",
						color = { r = 200, g = 222, b = 255 },
						brightness = 1.5,
						range = 16,
						angle = 120,
						face = "Back",
					}
					else nil,
			} :: DecorSpec
		)
		-- 문살 격자
		for k = -2, 2 do
			table.insert(win, part("ShopWindowMullion", "Block", v(6, 300, 6), BEAM, "Wood", v(k * 56, 250, 10)))
		end
		for k = -2, 2 do
			table.insert(win, part("ShopWindowMullion", "Block", v(280, 6, 6), BEAM, "Wood", v(0, 250 + k * 60, 10)))
		end
		table.insert(
			win,
			part("ShopWindowFrame", "Block", v(304, 20, 14), MapKitLogic.shade(BEAM, 0.8), "Wood", v(0, 410, 12))
		)
		table.insert(
			win,
			part("ShopWindowFrame", "Block", v(320, 18, 30), MapKitLogic.shade(BEAM, 1.1), "Wood", v(0, 92, 16))
		)
		addAll(list, MapKitShapes.transform(win, v(x, 0, z), v(0, 90, 0)))
	end
end

-- 왼쪽 벽: 그릇 선반 (쌓인 그릇 무리) + 붉은 등롱 하나
local function shelfWall(list: { DecorSpec })
	local x = -Art.SHOP_HALF_X
	shopWall(
		list,
		"ShopSideWall",
		v(x, 0, (Art.SHOP_FRONT_Z + Art.SHOP_BACK_Z) / 2),
		Art.SHOP_FRONT_Z - Art.SHOP_BACK_Z,
		-90,
		4
	)
	local shelfX = x + 80
	for _, y in { 120, 330 } do
		add(list, part("BowlShelf", "Block", v(150, 14, 1100), PALETTE.WoodDark, "Wood", v(shelfX, y, -150)))
		add(
			list,
			part(
				"BowlShelfLip",
				"Block",
				v(6, 22, 1100),
				MapKitLogic.shade(PALETTE.WoodDark, 1.25),
				"Wood",
				v(shelfX + 76, y + 4, -150)
			)
		)
	end
	local colors = { PALETTE.Porcelain, PALETTE.Lacquer, PALETTE.Nori, CELADON }
	local rng = MapKitShapes.rng(24)
	for row, y in { 127, 337 } do
		for k = 0, 8 do
			local z = -650 + k * 115 + rng:range(-15, 15)
			local stack = 2 + (k + row) % 3
			local color = colors[1 + (k * 3 + row) % #colors]
			local d = 100 + rng:range(-12, 12)
			for s = 0, stack - 1 do
				add(list, upright("ShelfBowl", 30, d, color, "SmoothPlastic", v(shelfX, y + 15 + s * 26, z)))
				add(
					list,
					upright(
						"ShelfBowlRim",
						4,
						d + 4,
						PALETTE.PorcelainRim,
						"SmoothPlastic",
						v(shelfX, y + 29 + s * 26, z)
					)
				)
			end
		end
	end
	-- 선반 사이 붉은 등롱 (빛나는 원인, 왼쪽에 따뜻한 빛)
	add(list, {
		name = "ShopLantern",
		shape = "Cylinder",
		size = v(110, 90, 90),
		color = LANTERN_RED,
		material = "Fabric",
		offset = v(shelfX + 120, 560, -150),
		rotation = v(0, 0, 90),
		light = { kind = "Point", color = { r = 255, g = 150, b = 90 }, brightness = 2, range = 60 },
		anim = { kind = "Sway", period = 6.2, amount = 2, axis = "Z" },
	})
	add(list, upright("ShopLanternCap", 10, 64, PALETTE.Nori, "SmoothPlastic", v(shelfX + 120, 620, -150)))
	add(list, upright("ShopLanternCap", 10, 64, PALETTE.Nori, "SmoothPlastic", v(shelfX + 120, 500, -150)))
	add(list, upright("LanternHook", 180, 3, PALETTE.Nori, "Metal", v(shelfX + 120, 715, -150)))
end

-- 앞쪽(출발 뒤) 벽: 미닫이 문 + 기둥
local function frontWall(list: { DecorSpec })
	local z = Art.SHOP_FRONT_Z
	shopWall(list, "ShopFrontWall", v(0, 0, z), Art.SHOP_HALF_X * 2, 180, 4)
	for i = -1, 1, 2 do
		add(list, part("ShopDoor", "Block", v(220, 380, 6), PALETTE.WoodLight, "Wood", v(i * 112, 100, z - 8)))
		for k = 0, 3 do
			add(
				list,
				part("ShopDoorPane", "Block", v(170, 70, 7), WINDOW, "SmoothPlastic", v(i * 112, 220 - k * 80, z - 9))
			)
		end
	end
end

-- 카운터 위 그릇 스케일 소품: 찻잔·양념통 쟁반·교자 접시·젓가락 통·옆 손님 그릇
local function counterProps(list: { DecorSpec })
	local top = Art.COUNTER_TOP_Y
	-- 찻잔 (오른쪽 앞): 청자 몸통 + 짙은 띠 + 차 수면 + 김
	local cup = v(320, 0, 80)
	add(list, upright("TeaCup", 170, 150, CELADON, "SmoothPlastic", v(cup.x, top + 85, cup.z)))
	add(
		list,
		upright("TeaCupBand", 18, 152, MapKitLogic.shade(CELADON, 0.6), "SmoothPlastic", v(cup.x, top + 120, cup.z))
	)
	add(
		list,
		upright("TeaCupFoot", 12, 120, MapKitLogic.shade(CELADON, 0.8), "SmoothPlastic", v(cup.x, top + 6, cup.z))
	)
	add(list, {
		name = "TeaSurface",
		shape = "Cylinder",
		size = v(2, 138, 138),
		color = TEA,
		material = "SmoothPlastic",
		offset = v(cup.x, top + 166, cup.z),
		rotation = v(0, 0, 90),
		particle = "Steam",
		particleRate = 2,
	})
	-- 양념 쟁반 (왼쪽 앞): 간장병·고추기름 단지·후추통
	local tray = v(440, 0, -190) -- m5-40: 커진 그릇 밖으로 (옛 370)
	addAll(
		list,
		MapKitShapes.bevelBox(
			"CondimentTray",
			v(300, 22, 130),
			PALETTE.LacquerDark,
			"Wood",
			v(tray.x, top + 11, tray.z),
			6,
			v(0, 12, 0)
		)
	)
	add(list, upright("SoyCruet", 190, 64, PALETTE.SoyDark, "Glass", v(tray.x - 90, top + 117, tray.z + 10)))
	add(list, upright("SoyCruetCap", 30, 56, PALETTE.Lacquer, "SmoothPlastic", v(tray.x - 90, top + 226, tray.z + 10)))
	add(
		list,
		part(
			"SoyCruetSpout",
			"Cylinder",
			v(40, 10, 10),
			PALETTE.Lacquer,
			"SmoothPlastic",
			v(tray.x - 66, top + 236, tray.z + 10),
			v(0, 0, 30)
		)
	)
	add(list, upright("ChiliOilJar", 120, 80, { r = 168, g = 40, b = 26 }, "Glass", v(tray.x, top + 82, tray.z - 12)))
	add(list, upright("ChiliOilLid", 20, 84, PALETTE.Porcelain, "SmoothPlastic", v(tray.x, top + 150, tray.z - 12)))
	add(
		list,
		upright("PepperShaker", 150, 56, PALETTE.Porcelain, "SmoothPlastic", v(tray.x + 90, top + 97, tray.z + 18))
	)
	add(list, upright("PepperShakerTop", 26, 58, PALETTE.Steel, "Metal", v(tray.x + 90, top + 185, tray.z + 18)))
	-- 교자 접시 (오른쪽 뒤)
	local plate = v(400, 0, -520)
	addAll(
		list,
		MapKitShapes.rimDisc("GyozaPlate", 320, 10, PALETTE.Porcelain, "SmoothPlastic", v(plate.x, top + 5, plate.z), {
			rimColor = PALETTE.PorcelainRim,
			rimWidth = 16,
			rimHeight = 8,
			segments = 18,
		})
	)
	for i = 0, 4 do
		local a = math.rad(-40 + i * 20)
		local gx, gz = plate.x + math.sin(a) * 40 - 30, plate.z + math.cos(a) * 40
		addAll(
			list,
			MapKitShapes.capsule("Gyoza", 110, 46, GYOZA, "Plastic", v(gx, top + 30, gz), v(0, -math.deg(a) + 90, 0))
		)
		add(
			list,
			part(
				"GyozaCrisp",
				"Block",
				v(70, 6, 30),
				GYOZA_CRISP,
				"Plastic",
				v(gx, top + 10, gz),
				v(0, -math.deg(a) + 90, 0)
			)
		)
		for p = -1, 1 do
			add(
				list,
				part(
					"GyozaPleat",
					"Wedge",
					v(8, 10, 12),
					MapKitLogic.shade(GYOZA, 1.1),
					"Plastic",
					v(gx + math.cos(a) * p * 22, top + 54, gz - math.sin(a) * p * 22),
					v(0, -math.deg(a), 0)
				)
			)
		end
	end
	-- 젓가락 통 (왼쪽 뒤): 옻칠 상자에 젓가락 여러 짝
	local box = v(-380, 0, -470)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ChopstickBox",
			v(120, 160, 120),
			PALETTE.Lacquer,
			"SmoothPlastic",
			v(box.x, top + 80, box.z),
			{ radius = 10, style = "vertical" }
		)
	)
	add(
		list,
		part("ChopstickBoxBand", "Block", v(124, 14, 124), PALETTE.Egg, "SmoothPlastic", v(box.x, top + 130, box.z))
	)
	for i = 0, 6 do
		local ox, oz = ((i * 37) % 70) - 35, ((i * 53) % 70) - 35
		addAll(
			list,
			MapKitShapes.capsule(
				"SpareChopstick",
				300,
				12,
				if i % 2 == 0 then PALETTE.WoodLight else PALETTE.Wood,
				"Wood",
				v(box.x + ox, top + 200, box.z + oz),
				v(0, i * 50, 90 - ((i % 3) - 1) * 6)
			)
		)
	end
	-- 옆 손님 그릇 (먼 왼쪽 뒤, 반쯤만 보여요)
	local side = v(-600, 0, -620)
	add(list, upright("NeighborBowl", 150, 320, PALETTE.Nori, "SmoothPlastic", v(side.x, top + 75, side.z)))
	add(list, upright("NeighborBowlRim", 10, 326, PALETTE.Lacquer, "SmoothPlastic", v(side.x, top + 152, side.z)))
	add(
		list,
		upright("NeighborBroth", 4, 300, MapKitLogic.shade(BROTH, 0.85), "SmoothPlastic", v(side.x, top + 145, side.z))
	)
	add(list, {
		name = "NeighborSteam",
		shape = "Block",
		size = v(160, 2, 160),
		color = BROTH,
		material = "SmoothPlastic",
		offset = v(side.x, top + 150, side.z),
		transparency = 1,
		particle = "SteamThick",
		particleRate = 2,
	})
	-- 물수건·메뉴 세움판 (오른쪽 앞 무리)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"Oshibori",
			v(160, 30, 60),
			PALETTE.Rice,
			"Fabric",
			v(250, top + 15, 330),
			{ radius = 12, style = "full", rotation = v(0, -18, 0) }
		)
	)
	add(
		list,
		part(
			"MenuStand",
			"Wedge",
			v(150, 200, 80),
			PALETTE.Rice,
			"SmoothPlastic",
			v(-180, top + 100, 360),
			v(0, 180, 0)
		)
	)
	add(
		list,
		part("MenuStandPhoto", "Block", v(120, 80, 2), BROTH, "SmoothPlastic", v(-180, top + 120, 336), v(-21.8, 0, 0))
	)
	add(
		list,
		part(
			"MenuStandTitle",
			"Block",
			v(120, 24, 2),
			PALETTE.Lacquer,
			"SmoothPlastic",
			v(-180, top + 178, 314),
			v(-21.8, 0, 0)
		)
	)
end

-- 국물 위 공기: 기름 반짝임 + 가장자리 거품 + 김 (코스 밖)
local function brothAir(list: { DecorSpec })
	local y = Layout.BROTH_Y + 0.4
	local function anchor(name: string, x: number, z: number, preset: string, rate: number)
		add(list, {
			name = name,
			shape = "Block",
			size = v(14, 0.4, 14),
			color = BROTH,
			material = "SmoothPlastic",
			offset = v(x, y, z),
			transparency = 1,
			particle = preset,
			particleRate = rate,
		})
	end
	anchor("BrothGlint", 70, -250, "Sparkle", 2)
	anchor("BrothGlint", -70, -110, "Sparkle", 2)
	anchor("BrothBubble", -140, -150, "Bubbles", 4)
	anchor("BrothBubble", 140, -200, "Bubbles", 4)
	anchor("BrothSteam", -80, -290, "SteamThick", 2)
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	bowl(list)
	floatingToppings(list)
	floatingGarnish(list) -- m5-20 ②
	giantChopsticks(list)
	spoonExit(list)
	addFogPanels(list) -- m5-20 ③ (m5-24: 국물 아래로)
	-- m5-24
	noodleCurtain(list)
	softEggs(list)
	narutoIsland(list)
	rimProps(list)
	brothAir(list)
	counter(list)
	backWall(list)
	windowWall(list)
	shelfWall(list)
	frontWall(list)
	counterProps(list)
	lengthSections(list) -- m5-40
	return list
end

-- 김 3곳: 국물 수면 바로 위, 코스 옆
function Art.steamPoints(): { Vec3 }
	local y = Layout.BROTH_Y + 1
	return { v(-34, y, -165), v(34, y, -230), v(-32, y, -326) } -- m5-40: 셋째는 젓가락 다리 옆으로
end

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

-- m5-24: ① 그릇 밖 높은 곳에서 그릇·젓가락·주방 벽 전체 → ② 차슈 건너기 클로즈업 → ③ 결승 쪽에서 출발 쪽으로 반전
-- → ④ 출발선 뒤 높이 12 (m4-02 공통 규칙)
function Art.introCamera(): { IntroPoint }
	return {
		{ pos = v(56, 50, 38), lookAt = v(0, -28, -250) },
		{ pos = v(34, -8, -132), lookAt = v(0, -30, -172) },
		-- m5-40: 결승 너머에서 새 구간(두 번째 급류·렌게 계단·젓가락 다리 + 국자)을 거꾸로
		{ pos = v(-30, 8, -452), lookAt = v(0, -26, -346) },
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
	local volumes = {
		box(Layout.START_WIDTH / 2, 2, 12, Layout.START.front, Layout.START.back),
		box(Layout.RAPIDS_WIDTH / 2, rapidsLow + 2, 12, Layout.RAPIDS.front, Layout.RAPIDS.back),
		box(reachX, Layout.BROTH_Y + 2, chashuHigh + 12, Layout.TOPPINGS.front, Layout.TOPPINGS.back),
		box(Layout.PLATFORM_DIAMETER / 2, top + 2, top + 12, Layout.SWEEPERS.front, Layout.SWEEPERS.back),
		box(Layout.FINISH_WIDTH / 2, top + 2, top + 12, Layout.FINISH.front, Layout.FINISH.back),
	}
	-- m5-40 새 구간: 뗏목 · 젓가락 다리 · 렌게 발판 4개(발판마다) · 두 번째 급류(경사를 따라 5칸)
	local raft = Layout.CHOP_RAFT
	table.insert(volumes, box(raft.width / 2, top + 2, top + 12, Layout.CHOPSTICKS.front, raft.back))
	table.insert(volumes, box(Layout.CHOP_REST.width / 2, top + 2, top + 12, raft.back, Layout.CHOPSTICKS.back))
	for i, step in Layout.RENGE_STEPS do
		local stepTop = Layout.rengeStepTop(i)
		table.insert(volumes, {
			min = v(step.x - step.width / 2 - 1, stepTop + 2, step.back - 1),
			max = v(step.x + step.width / 2 + 1, stepTop + 12, step.front + 1),
		})
	end
	local r2 = Layout.RAPIDS2
	local pieces = 5
	local len = (r2.front - r2.back) / pieces
	for k = 0, pieces - 1 do
		local front, back = r2.front - k * len, r2.front - (k + 1) * len
		table.insert(
			volumes,
			box(
				Layout.RAPIDS2_WIDTH / 2,
				Layout.rapids2HeightAt(back) + 2,
				Layout.rapids2HeightAt(front) + 12,
				front,
				back
			)
		)
	end
	return volumes
end

return Art
