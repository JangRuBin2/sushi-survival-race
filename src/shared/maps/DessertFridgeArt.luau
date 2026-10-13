--!strict
-- "디저트 냉장고"(dessert-fridge, m5-06) 장식 데이터 (Roblox 자료형 없음, m4-02 공통 규칙 + m5-23 비주얼 키트).
--   Art.BUDGET = "Extended"               예산 단계 (장식 1500·조명 24(그림자 2)·파티클 16·움직임 80)
--   Art.LIGHTING                          맵 조명 프리셋 (차가운 냉장고 안 + 문밖 따뜻한 주방)
--   Art.decor() -> { DecorSpec }          장식 (충돌·쿼리·터치 없음)
--   Art.courseVolume() -> { Bounds }      장식이 들어가면 안 되는 코스 시야 상자 (각 바닥 위 2~12)
--   Art.introCamera() -> { IntroPoint }   라운드 소개 경유점 4개
-- 아트 디렉션(스펙 "### 아트", docs/REFERENCE-map-art-direction.md): "차가운 업소용 냉장고 속 디저트 칸, 끝에 따뜻한 주방".
--   세계: 코스(로컬 z 0 → -260)가 거대한 냉장고(안쪽 폭 124·높이 122·깊이 308) 한가운데 선반 높이에 떠 있고,
--         끝(z -264)은 활짝 열린 양문 너머 따뜻한 주방이에요. 1 stud ≈ 1 cm.
--   층: FG = 얼음 쟁반 림·구멍 안쪽(남색 + 흰 림)·코스 받침 기둥·케이크 단 옆면 / MG = 양옆 유리 선반 위 디저트
--       (푸딩·딸기 쇼트케이크·우유팩 + 계란판·마카롱 탑·젤리) / BG = 냉장고 벽·천장 LED·뒷벽 LED 패널과 송풍구,
--       아래 칸 채소 서랍(낙하 탈락선보다 10 이상 아래), 열린 문의 문 선반(병·아이스크림 콘 탑), 문 너머 주방.
--   히어로 색 민트-얼음 파랑, 60 차가운 흰색 벽 / 30 얼음 하늘색 / 10 디저트 강조.
-- 판정 파츠(바닥·큐브·젤리·쿠키 계단·송풍구)는 DessertFridge.luau에 있고 여기서 크기·위치를 바꾸지 않아요.

local Layout = require(script.Parent.DessertFridgeLayout)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapKitShapes = require(script.Parent.MapKitShapes)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB
type Bounds = MapKitLogic.Bounds
type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local P = MapKitLogic.PALETTE
local shade = MapKitLogic.shade
local mix = MapKitLogic.mix

local Art = {}

Art.BUDGET = "Extended"

-- 냉장고 치수 (로컬). 안쪽 벽면 x = ±IN_X, 바닥 윗면 FLOOR_Y, 천장 아랫면 CEIL_Y, 뒷벽 안쪽 z = BACK_Z, 앞면 z = FRONT_Z
Art.IN_X = 62
Art.WALL = 4
Art.FLOOR_Y = -48
Art.CEIL_Y = 74
Art.BACK_Z = 44
Art.FRONT_Z = -264
Art.KITCHEN_FLOOR_Y = -62
Art.LOW_SHELF_Y = -10 -- 양옆 아래 유리 선반 윗면
Art.HIGH_SHELF_Y = 44 -- 양옆 위 유리 선반 윗면
Art.SHELF_INNER_X = 30 -- 아래 선반 안쪽 끝 (코스 가장자리 ±15에서 15 이상 떨어져 "밟을 수 있는 곳"으로 안 보여요)
Art.DRAWER_TOP_Y = -37 -- 채소 서랍 윗면 (B·C 낙하선 -25보다 12 아래)

-- 색
local LINER = { r = 212, g = 224, b = 236 } -- 냉장고 안쪽 흰 플라스틱 (약간 푸른 기)
local LINER_SHADE = shade(LINER, 0.93)
local LINER_DARK = shade(LINER, 0.82)
local TRIM = mix(P.Mint, P.IceBlue, 0.4) -- 민트-얼음 파랑 히어로 트림
local TRIM_DARK = shade(TRIM, 0.72)
local GLASS = mix(P.IceBlue, P.Frost, 0.45)
local NAVY = { r = 22, g = 34, b = 70 }
local STEEL = P.Steel
local STEEL_DARK = shade(P.Steel, 0.7)
local LED = { r = 236, g = 248, b = 255 }
local LED_COLD = { r = 200, g = 230, b = 255 }
local WARM = { r = 255, g = 178, b = 102 }
local WARM_DEEP = { r = 255, g = 140, b = 70 }
local SPONGE = { r = 250, g = 222, b = 150 }
local CARDBOARD = { r = 214, g = 196, b = 160 }
local EGG_SHELL = { r = 252, g = 242, b = 224 }
local KITCHEN_WALL = { r = 236, g = 192, b = 146 }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function add(list: { DecorSpec }, spec: DecorSpec)
	table.insert(list, spec)
end

local function addAll(list: { DecorSpec }, specs: { DecorSpec })
	for _, spec in specs do
		table.insert(list, spec)
	end
end

local function block(name: string, size: Vec3, color: RGB, material: string, offset: Vec3, rotation: Vec3?): DecorSpec
	return {
		name = name,
		shape = "Block",
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
end

local function ball(name: string, d: number, color: RGB, material: string, offset: Vec3): DecorSpec
	return { name = name, shape = "Ball", size = v(d, d, d), color = color, material = material, offset = offset }
end

-- 세운 원기둥 (축 = 세로)
local function post(name: string, d: number, h: number, color: RGB, material: string, offset: Vec3): DecorSpec
	return {
		name = name,
		shape = "Cylinder",
		size = v(h, d, d),
		color = color,
		material = material,
		offset = offset,
		rotation = v(0, 0, 90),
	}
end

-- z 방향으로 누운 원기둥
local function rodZ(name: string, d: number, length: number, color: RGB, material: string, offset: Vec3): DecorSpec
	return {
		name = name,
		shape = "Cylinder",
		size = v(length, d, d),
		color = color,
		material = material,
		offset = offset,
		rotation = v(0, 90, 0),
	}
end

-- ── 1. 냉장고 몸통 ─────────────────────────────────────────────────────
local function addShell(list: { DecorSpec })
	local X, W = Art.IN_X, Art.WALL
	local bottom, ceil = Art.FLOOR_Y, Art.CEIL_Y
	local back, front = Art.BACK_Z, Art.FRONT_Z
	local depth = back - front
	local midZ = (back + front) / 2
	local wallBottom, wallTop = bottom - W, ceil + W + 2
	local wallH = wallTop - wallBottom
	-- 바닥·천장
	add(
		list,
		block(
			"FridgeFloor",
			v(2 * (X + W), W, depth + W),
			LINER_SHADE,
			"SmoothPlastic",
			v(0, bottom - W / 2, midZ + W / 2)
		)
	)
	add(
		list,
		block(
			"FridgeCeiling",
			v(2 * (X + W), W + 2, depth + W),
			LINER,
			"SmoothPlastic",
			v(0, ceil + (W + 2) / 2, midZ + W / 2)
		)
	)
	-- 뒷벽
	add(
		list,
		block(
			"FridgeBackWall",
			v(2 * (X + W), wallH, W),
			LINER_SHADE,
			"SmoothPlastic",
			v(0, (wallBottom + wallTop) / 2, back + W / 2)
		)
	)
	-- 옆벽: 5칸으로 나눠 칸마다 shade를 조금씩 (큰 면을 한 색으로 칠하지 않게) + 칸 사이 둥근 이음매
	local segments = 5
	local segLen = depth / segments
	local tones = { LINER, LINER_SHADE, LINER, shade(LINER, 0.96), LINER_SHADE }
	for _, side in { -1, 1 } do
		for i = 1, segments do
			local z = back - (i - 0.5) * segLen
			add(
				list,
				block(
					"FridgeSideWall",
					v(W, wallH, segLen),
					tones[i],
					"SmoothPlastic",
					v(side * (X + W / 2), (wallBottom + wallTop) / 2, z)
				)
			)
			if i < segments then
				add(
					list,
					post(
						"WallSeam",
						1.4,
						ceil - bottom,
						LINER_DARK,
						"SmoothPlastic",
						v(side * (X - 0.2), (ceil + bottom) / 2, back - i * segLen)
					)
				)
			end
		end
		-- 둥근 안쪽 모서리 (벽-천장, 벽-바닥): 플라스틱 내장재의 굴린 모서리
		add(list, rodZ("WallCove", 6, depth, LINER, "SmoothPlastic", v(side * (X - 0.5), ceil - 0.5, midZ)))
		add(list, rodZ("WallCove", 6, depth, LINER_SHADE, "SmoothPlastic", v(side * (X - 0.5), bottom + 0.5, midZ)))
		-- 선반 받침 레일 (벽에 붙은 가로 홈)
		for _, y in { Art.LOW_SHELF_Y - 1.6, Art.HIGH_SHELF_Y - 1.6, 20, 62 } do
			add(list, rodZ("ShelfRail", 1.8, depth - 4, LINER_DARK, "SmoothPlastic", v(side * (X - 0.4), y, midZ)))
		end
	end
	-- 바깥 스테인리스 겉판 (밖에서 보면 업소용 냉장고: 윗면·옆면)
	add(list, {
		name = "FridgeSkinTop",
		shape = "Block",
		size = v(2 * (X + W) + 1, 0.6, depth + W + 1),
		color = STEEL,
		material = "Metal",
		offset = v(0, ceil + W + 2.3, midZ + W / 2),
		reflectance = 0.2,
	})
	for _, side in { -1, 1 } do
		add(list, {
			name = "FridgeSkinSide",
			shape = "Block",
			size = v(0.6, wallH, depth + W + 1),
			color = shade(STEEL, 0.95),
			material = "Metal",
			offset = v(side * (X + W + 0.3), (wallBottom + wallTop) / 2, midZ + W / 2),
			reflectance = 0.2,
		})
	end
	-- 앞 테두리(문틀) — 열린 문 둘레의 두꺼운 흰 테 + 회색 고무 패킹
	local frameZ = front - 3
	for _, side in { -1, 1 } do
		addAll(
			list,
			MapKitShapes.roundedBox(
				"FridgeFrontPost",
				v(10, wallH + 12, 6),
				LINER,
				"SmoothPlastic",
				v(side * (X + 3), (wallBottom + wallTop) / 2 - 2, frameZ),
				{ style = "vertical", radius = 1.6 }
			)
		)
		add(
			list,
			block(
				"DoorGasket",
				v(1.2, ceil - bottom, 1.2),
				STEEL_DARK,
				"Rubber",
				v(side * (X - 0.4), (ceil + bottom) / 2, front + 0.4)
			)
		)
	end
	addAll(
		list,
		MapKitShapes.bevelBox(
			"FridgeFrontTop",
			v(2 * (X + 8), 10, 6),
			LINER,
			"SmoothPlastic",
			v(0, ceil + 5, frameZ),
			1.4
		)
	)
	add(list, block("DoorGasket", v(2 * X, 1.2, 1.2), STEEL_DARK, "Rubber", v(0, ceil - 0.4, front + 0.4)))
	-- 앞 아래: 걸레받이(어두운 회색) + 바닥 앞 테
	add(
		list,
		block(
			"FridgeKickPlate",
			v(2 * (X + 8), bottom - W - Art.KITCHEN_FLOOR_Y, 5),
			shade(P.Steel, 0.45),
			"Metal",
			v(0, (bottom - W + Art.KITCHEN_FLOOR_Y) / 2, frameZ + 1)
		)
	)
	add(list, block("FridgeFrontSill", v(2 * (X + 8), 6, 6), LINER, "SmoothPlastic", v(0, bottom - 1, frameZ)))
	-- 냉장고 옆면 아래 받침 (바깥에서 볼 때 바닥에 서 있게)
	for _, side in { -1, 1 } do
		add(
			list,
			block(
				"FridgePlinth",
				v(W + 2, bottom - W - Art.KITCHEN_FLOOR_Y, depth),
				shade(P.Steel, 0.5),
				"Metal",
				v(side * (X + W / 2), (bottom - W + Art.KITCHEN_FLOOR_Y) / 2, midZ)
			)
		)
	end
end

-- ── 2. 천장 LED 띠 + 젤리 계단 위 매달린 램프 + 뒷벽 LED 패널·송풍구 (히어로 ①) ─────
local function addLights(list: { DecorSpec })
	local ceil = Art.CEIL_Y
	-- LED 띠: 천장 양쪽 두 줄, 각 3칸 (칸마다 SurfaceLight 하나)
	local zs = { -10, -100, -190 }
	for _, side in { -1, 1 } do
		add(list, rodZ("LedHousing", 4, 280, LINER_DARK, "SmoothPlastic", v(side * 36, ceil - 1, -86)))
		for _, z in zs do
			add(list, {
				name = "LedStrip",
				shape = "Block",
				size = v(2.2, 0.6, 70),
				color = LED,
				material = "Neon",
				offset = v(side * 36, ceil - 2.8, z),
				castShadow = false,
				-- 띠 전체가 빛의 원인. SurfaceLight는 Range 16이 한계라 아래 코스까지 닿는 PointLight로
				light = { kind = "Point", color = LED_COLD, brightness = 1.1, range = 60 },
			})
		end
	end
	-- 젤리 계단 위 매달린 LED 램프 (그림자 조명 1/2: 좁은 SpotLight가 젤리·케이크 단을 비춰요)
	local lampZ = -114
	add(list, post("LampRod", 0.8, ceil - 58, STEEL, "Metal", v(0, (ceil + 58) / 2, lampZ)))
	addAll(
		list,
		MapKitShapes.roundedBox("LampShade", v(10, 3, 10), LINER, "SmoothPlastic", v(0, 57.5, lampZ), { radius = 1.2 })
	)
	add(list, {
		name = "LampBulb",
		shape = "Cylinder",
		size = v(0.6, 8, 8),
		color = LED,
		material = "Neon",
		offset = v(0, 55.8, lampZ),
		rotation = v(0, 0, 90),
		castShadow = false,
		light = { kind = "Spot", color = LED, brightness = 4, range = 60, angle = 70, face = "Left", shadows = true },
	})
	-- 뒷벽 (출발 뒤): 큰 LED 패널 + 온도 표시 + 송풍구 그릴 (게임플레이 송풍구와 같은 철판 + 민트 테)
	local wallZ = Art.BACK_Z - 0.6
	addAll(
		list,
		MapKitShapes.roundedBox(
			"BackPanelFrame",
			v(56, 20, 2),
			TRIM,
			"SmoothPlastic",
			v(0, 50, wallZ),
			{ radius = 0.9 }
		)
	)
	add(list, {
		name = "BackLedPanel",
		shape = "Block",
		size = v(50, 14, 0.6),
		color = LED,
		material = "Neon",
		offset = v(0, 50, wallZ - 1.2),
		castShadow = false,
		light = { kind = "Surface", color = LED_COLD, brightness = 2, range = 16, angle = 120, face = "Front" },
	})
	add(list, block("TempDisplay", v(12, 5, 0.6), NAVY, "SmoothPlastic", v(0, 36, wallZ - 0.4)))
	for i = -1, 1 do
		add(list, {
			name = "TempDigit",
			shape = "Block",
			size = v(2.4, 3, 0.3),
			color = P.Mint,
			material = "Neon",
			offset = v(i * 3.4, 36, wallZ - 0.8),
			castShadow = false,
		})
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"BackVentFrame",
			v(60, 26, 3),
			TRIM_DARK,
			"SmoothPlastic",
			v(0, 12, wallZ),
			{ radius = 1.2 }
		)
	)
	add(list, block("BackVentHole", v(54, 21, 0.4), NAVY, "SmoothPlastic", v(0, 12, wallZ - 1.4)))
	for i = 0, 6 do
		add(list, block("BackVentSlat", v(54, 1, 2.4), STEEL, "Metal", v(0, 3 + i * 3, wallZ - 2), v(-25, 0, 0)))
	end
	for _, x in { -18, 18 } do
		add(list, {
			name = "BackVentMist",
			shape = "Block",
			size = v(4, 0.4, 1),
			color = STEEL_DARK,
			material = "Metal",
			offset = v(x, 0, wallZ - 2.6),
			particle = "ColdMist",
			particleRate = 4,
		})
	end
end

-- ── 3. 양옆 유리 선반 (아래 y -10, 위 y 44) ────────────────────────────
local function addShelves(list: { DecorSpec })
	local back, front = Art.BACK_Z - 4, Art.FRONT_Z + 2
	local length = back - front
	local segs = 3
	local segLen = length / segs
	for _, side in { -1, 1 } do
		for _, shelf in { { y = Art.LOW_SHELF_Y, inner = Art.SHELF_INNER_X }, { y = Art.HIGH_SHELF_Y, inner = 34 } } do
			local width = Art.IN_X - shelf.inner
			local cx = side * (shelf.inner + width / 2)
			for i = 1, segs do
				local z = back - (i - 0.5) * segLen
				add(list, {
					name = "GlassShelf",
					shape = "Block",
					size = v(width, 0.8, segLen - 0.6),
					color = GLASS,
					material = "Glass",
					offset = v(cx, shelf.y - 0.4, z),
					transparency = 0.2,
					reflectance = 0.15,
					castShadow = false,
				})
				-- 앞 테(코스 쪽): 진한 민트 띠로 모양이 읽히게
				add(
					list,
					rodZ(
						"ShelfEdge",
						1.6,
						segLen - 0.6,
						TRIM_DARK,
						"SmoothPlastic",
						v(side * (shelf.inner + 0.4), shelf.y - 0.5, z)
					)
				)
			end
		end
	end
end

-- ── 4. 아래 칸 채소 서랍 (배경 바닥, 낙하 탈락선보다 10 이상 아래) ───────────
local function addCrisper(list: { DecorSpec })
	local top, bottom = Art.DRAWER_TOP_Y, Art.FLOOR_Y
	local h = top - bottom
	local back, front = Art.BACK_Z - 6, -226
	local length = back - front
	local midZ = (back + front) / 2
	for _, side in { -1, 1 } do
		local inner, outer = 4, 58
		local cx = side * (inner + outer) / 2
		local width = outer - inner
		-- 반투명 벽 4장 (얇게) + 앞 손잡이
		add(list, {
			name = "DrawerWall",
			shape = "Block",
			size = v(1, h, length),
			color = GLASS,
			material = "Glass",
			offset = v(side * (inner + 0.5), bottom + h / 2, midZ),
			transparency = 0.3,
			castShadow = false,
		})
		add(list, {
			name = "DrawerWall",
			shape = "Block",
			size = v(1, h, length),
			color = GLASS,
			material = "Glass",
			offset = v(side * (outer - 0.5), bottom + h / 2, midZ),
			transparency = 0.3,
			castShadow = false,
		})
		add(list, block("DrawerFront", v(width, h + 2, 1.6), TRIM, "SmoothPlastic", v(cx, bottom + (h + 2) / 2, front)))
		add(list, {
			name = "DrawerWall",
			shape = "Block",
			size = v(width, h, 1),
			color = GLASS,
			material = "Glass",
			offset = v(cx, bottom + h / 2, back),
			transparency = 0.3,
			castShadow = false,
		})
		addAll(list, MapKitShapes.capsule("DrawerHandle", 26, 2.2, LINER, "SmoothPlastic", v(cx, top - 2, front - 1.8)))
		add(list, block("DrawerRim", v(width, 1, 1.2), TRIM_DARK, "SmoothPlastic", v(cx, top + 0.5, front)))
		-- 채소: 양상추·양배추(큰 공) 무리, 오이(캡슐), 브로콜리 — 전부 녹색·연노랑 계열 (위험 색 없음)
		local greens = { P.Shiso, mix(P.Lime, P.Shiso, 0.4), mix(P.Lime, P.Cream, 0.5), P.Matcha }
		addAll(
			list,
			MapKitShapes.scatter(
				side == 1 and 61 or 17,
				16,
				{ center = v(side * 37, bottom, midZ), size = v(34, 0, length - 16) },
				function(i: number, pos: Vec3, rng): { DecorSpec }
					local kind = i % 4
					if kind == 0 then
						local length2 = rng:range(22, 30)
						return MapKitShapes.capsule(
							"Cucumber",
							length2,
							5,
							shade(P.Shiso, 0.8),
							"SmoothPlastic",
							v(pos.x, bottom + 2.5, pos.z),
							v(0, rng:range(0, 180), 0)
						)
					elseif kind == 1 then
						local d = rng:range(5, 7)
						return {
							post(
								"BroccoliStem",
								2.4,
								6,
								mix(P.Lime, P.Cream, 0.4),
								"SmoothPlastic",
								v(pos.x, bottom + 3, pos.z)
							),
							ball("Broccoli", d, shade(P.Shiso, 0.85), "Pebble", v(pos.x, bottom + 6 + d / 3, pos.z)),
							ball("Broccoli", d * 0.8, P.Shiso, "Pebble", v(pos.x + d * 0.45, bottom + 6, pos.z + 1)),
							ball(
								"Broccoli",
								d * 0.8,
								shade(P.Shiso, 0.9),
								"Pebble",
								v(pos.x - d * 0.4, bottom + 6, pos.z - 1)
							),
						}
					end
					local d = rng:range(14, 20)
					local color = greens[1 + (i % #greens)]
					return {
						ball("Lettuce", d, color, "SmoothPlastic", v(pos.x, bottom + d / 2 - 1, pos.z)),
						ball(
							"LettuceLeaf",
							d * 0.7,
							shade(color, 1.12),
							"SmoothPlastic",
							v(pos.x + d * 0.2, bottom + d * 0.75, pos.z - d * 0.15)
						),
					}
				end
			)
		)
	end
end

-- ── 5. 코스 꾸미기 (판정 바닥은 그대로, 바깥·아래에만) ────────────────────
local function lip(
	list: { DecorSpec },
	name: string,
	x: number,
	front: number,
	back: number,
	topY: number,
	color: RGB,
	material: string
)
	add(list, block(name, v(0.6, 1.4, front - back), color, material, v(x, topY - 0.1 - 0.7, (front + back) / 2)))
end

local function supportPost(list: { DecorSpec }, x: number, z: number, topY: number)
	local bottom = Art.DRAWER_TOP_Y + 1
	local h = topY - bottom
	add(list, post("SupportRod", 1.8, h, STEEL, "Metal", v(x, bottom + h / 2, z)))
	add(list, post("SupportCap", 3.2, 0.8, STEEL_DARK, "Metal", v(x, topY - 0.4, z)))
	add(list, post("SupportFoot", 4, 0.8, STEEL_DARK, "Metal", v(x, bottom + 0.4, z)))
end

local function addCourse(list: { DecorSpec })
	local low, high = Layout.LOW_Y, Layout.HIGH_Y
	local t = Layout.FLOOR_THICKNESS
	-- A 출발: 흰 케이크 받침 판 (판정 바닥 아래) + 민트 립
	local sh = Layout.START_WIDTH / 2
	local sLen = Layout.START.front - Layout.START.back
	local sMid = (Layout.START.front + Layout.START.back) / 2
	addAll(
		list,
		MapKitShapes.roundedBox(
			"StartBoard",
			v(Layout.START_WIDTH + 1.6, 3, sLen + 1.6),
			P.Porcelain,
			"SmoothPlastic",
			v(0, low - t - 1.4, sMid + 0.8),
			{ radius = 1.2 }
		)
	)
	lip(list, "StartLip", -(sh + 0.3), Layout.START.front, Layout.START.back, low, TRIM, "SmoothPlastic")
	lip(list, "StartLip", sh + 0.3, Layout.START.front, Layout.START.back, low, TRIM, "SmoothPlastic")
	add(
		list,
		block(
			"StartLip",
			v(Layout.START_WIDTH + 1.2, 1.4, 0.6),
			TRIM,
			"SmoothPlastic",
			v(0, low - 0.8, Layout.START.front + 0.3)
		)
	)
	supportPost(list, -8, -8, low - t - 2.9)
	supportPost(list, 8, -8, low - t - 2.9)

	-- B 얼음 쟁반: 바닥 아래 두꺼운 쟁반 몸통, 흰 립, 구멍 안쪽 남색 우물 + 흰 림
	local th = Layout.ICE_TRAY_WIDTH / 2
	for _, rect in Layout.iceTrayRects() do
		add(
			list,
			block(
				"IceTrayBody",
				v(rect.maxX - rect.minX, 3, rect.maxZ - rect.minZ),
				shade(P.IceBlue, 0.78),
				"SmoothPlastic",
				v((rect.minX + rect.maxX) / 2, low - t - 1.5, (rect.minZ + rect.maxZ) / 2)
			)
		)
	end
	for _, side in { -1, 1 } do
		add(
			list,
			block(
				"IceTrayWall",
				v(1.2, 5.6, Layout.ICE_TRAY.front - Layout.ICE_TRAY.back),
				P.Frost,
				"SmoothPlastic",
				v(side * (th + 0.6), low - 2.9, (Layout.ICE_TRAY.front + Layout.ICE_TRAY.back) / 2)
			)
		)
	end
	for _, hole in Layout.holeRects() do
		local cx, cz = (hole.minX + hole.maxX) / 2, (hole.minZ + hole.maxZ) / 2
		local sx, sz = hole.maxX - hole.minX, hole.maxZ - hole.minZ
		local wellTop, wellBottom = low - 1.0, low - t - 4
		local wh = wellTop - wellBottom
		-- 남색 우물 벽 4장
		add(list, block("HoleWell", v(sx, wh, 0.4), NAVY, "SmoothPlastic", v(cx, wellBottom + wh / 2, hole.maxZ - 0.2)))
		add(list, block("HoleWell", v(sx, wh, 0.4), NAVY, "SmoothPlastic", v(cx, wellBottom + wh / 2, hole.minZ + 0.2)))
		add(
			list,
			block("HoleWell", v(0.4, wh, sz - 0.8), NAVY, "SmoothPlastic", v(hole.minX + 0.2, wellBottom + wh / 2, cz))
		)
		add(
			list,
			block("HoleWell", v(0.4, wh, sz - 0.8), NAVY, "SmoothPlastic", v(hole.maxX - 0.2, wellBottom + wh / 2, cz))
		)
		-- 흰 림 (윗면 바로 아래, 구멍 안쪽 둘레)
		local rimH, rimY = 0.9, low - 0.08 - 0.45
		add(list, block("HoleRim", v(sx, rimH, 0.5), P.Rice, "SmoothPlastic", v(cx, rimY, hole.maxZ - 0.25)))
		add(list, block("HoleRim", v(sx, rimH, 0.5), P.Rice, "SmoothPlastic", v(cx, rimY, hole.minZ + 0.25)))
		add(list, block("HoleRim", v(0.5, rimH, sz - 1), P.Rice, "SmoothPlastic", v(hole.minX + 0.25, rimY, cz)))
		add(list, block("HoleRim", v(0.5, rimH, sz - 1), P.Rice, "SmoothPlastic", v(hole.maxX - 0.25, rimY, cz)))
	end
	-- 얼음 반짝임 (쟁반 벽 위 작은 얼음 결정에서)
	for i, z in { -30, -78 } do
		add(list, {
			name = "IceCrystal",
			shape = "Ball",
			size = v(1, 1, 1),
			color = P.Frost,
			material = "Ice",
			offset = v((if i == 1 then 1 else -1) * (th + 0.6), low - 0.4, z),
			particle = "Sparkle",
			particleRate = 3,
		})
	end
	for _, p in { { -6, -36 }, { 6, -36 }, { -6, -84 }, { 6, -84 } } do
		supportPost(list, p[1], p[2], low - t - 3)
	end

	-- C 젤리 계단: 앞 바닥 립 + 케이크 단(착지대) 옆면 층 무늬 + 바닥 받침
	local ch = Layout.JELLY_ZONE_WIDTH / 2
	for _, side in { -1, 1 } do
		lip(
			list,
			"JellyFloorLip",
			side * (ch + 0.3),
			Layout.JELLY_ZONE.front,
			Layout.LANDING.front,
			low,
			P.Chocolate,
			"SmoothPlastic"
		)
		-- 착지대 옆면: 스펀지 / 크림 / 딸기잼 층
		local lz = (Layout.LANDING.front + Layout.LANDING.back) / 2
		local ll = Layout.LANDING.front - Layout.LANDING.back
		local layers = {
			{ y0 = low - t, y1 = 2.5, c = SPONGE },
			{ y0 = 2.5, y1 = 4, c = P.Cream },
			{ y0 = 4, y1 = 5.2, c = P.Strawberry },
			{ y0 = 5.2, y1 = 9.2, c = SPONGE },
			{ y0 = 9.2, y1 = high - 0.1, c = P.Cream },
		}
		for _, layer in layers do
			add(
				list,
				block(
					"CakeLayer",
					v(0.4, layer.y1 - layer.y0, ll),
					layer.c,
					"SmoothPlastic",
					v(side * (ch + 0.2), (layer.y0 + layer.y1) / 2, lz)
				)
			)
		end
		-- 위 가장자리 휘핑 크림 (옆면 바깥쪽, 윗면보다 낮게)
		for k = 0, 3 do
			add(
				list,
				ball(
					"CreamDollop",
					2.2,
					P.Cream,
					"SmoothPlastic",
					v(side * (ch + 0.9), high - 1.2, Layout.LANDING.front - 1.5 - k * 3)
				)
			)
		end
	end
	add(
		list,
		block(
			"JellyFloorBoard",
			v(Layout.JELLY_ZONE_WIDTH + 1, 2, Layout.JELLY_ZONE.front - Layout.LANDING.front),
			P.Chocolate,
			"SmoothPlastic",
			v(0, low - t - 1, (Layout.JELLY_ZONE.front + Layout.LANDING.front) / 2)
		)
	)
	supportPost(list, -10, -110, low - t - 2)
	supportPost(list, 10, -110, low - t - 2)
	-- 쿠키 계단 옆면 초코칩
	for _, step in Layout.COOKIE_STEPS do
		local z = (step.front + step.back) / 2
		add(
			list,
			ball("ChocoChip", 0.9, P.Chocolate, "SmoothPlastic", v(Layout.COOKIE_MAX_X + 0.2, step.top - 1.2, z - 0.8))
		)
		add(
			list,
			ball(
				"ChocoChip",
				0.7,
				shade(P.Chocolate, 0.8),
				"SmoothPlastic",
				v(Layout.COOKIE_MAX_X + 0.2, step.top - 2.2, z + 1)
			)
		)
	end

	-- D 찬바람 선반: 유리 받침 + 금속 립 + 송풍구 하우징(민트 테, 냉기, 파란 LED)
	local dh = Layout.FAN_SHELF_WIDTH / 2
	local dLen = Layout.FAN_SHELF.front - Layout.FAN_SHELF.back
	local dMid = (Layout.FAN_SHELF.front + Layout.FAN_SHELF.back) / 2
	add(list, {
		name = "ShelfGlass",
		shape = "Block",
		size = v(Layout.FAN_SHELF_WIDTH + 1.6, 0.8, dLen),
		color = GLASS,
		material = "Glass",
		offset = v(0, high - t - 0.4, dMid),
		transparency = 0.3,
		reflectance = 0.2,
		castShadow = false,
	})
	for _, side in { -1, 1 } do
		add(list, block("ShelfLip", v(0.6, 1.4, dLen), STEEL, "Metal", v(side * (dh + 0.3), high - 0.8, dMid)))
	end
	for _, z in { -150, -200 } do
		supportPost(list, -6, z, high - t - 0.8)
		supportPost(list, 6, z, high - t - 0.8)
	end
	for _, fan in Layout.FANS do
		local x = -fan.dirX
		local z = (fan.front + fan.back) / 2
		local len = fan.front - fan.back
		addAll(
			list,
			MapKitShapes.roundedBox(
				"FanHousing",
				v(4, 10, len + 4),
				TRIM,
				"SmoothPlastic",
				v(x * (dh + 3.2), high + 3.6, z),
				{ radius = 1 }
			)
		)
		add(
			list,
			block("FanFrameTop", v(1, 0.8, len + 1), TRIM_DARK, "SmoothPlastic", v(x * (dh + 1.2), high + 6.4, z))
		)
		add(
			list,
			block(
				"FanFrameEnd",
				v(1, 6.6, 0.8),
				TRIM_DARK,
				"SmoothPlastic",
				v(x * (dh + 1.2), high + 3, fan.front + 0.4)
			)
		)
		add(
			list,
			block(
				"FanFrameEnd",
				v(1, 6.6, 0.8),
				TRIM_DARK,
				"SmoothPlastic",
				v(x * (dh + 1.2), high + 3, fan.back - 0.4)
			)
		)
		add(list, {
			name = "FanLed",
			shape = "Ball",
			size = v(1.2, 1.2, 1.2),
			color = LED_COLD,
			material = "Neon",
			offset = v(x * (dh + 3.2), high + 9.2, z),
			light = { kind = "Point", color = LED_COLD, brightness = 1.5, range = 14 },
		})
		add(list, {
			name = "FanMist",
			shape = "Block",
			size = v(2, 0.4, len),
			color = TRIM_DARK,
			material = "SmoothPlastic",
			offset = v(x * (dh + 3.2), high - 1.6, z),
			particle = "ColdMist",
			particleRate = 3,
		})
	end

	-- E 결승: 립 + 크림 받침 판 + 높은 표지 (양쪽 마카롱 탑 + 위를 잇는 막대 과자 리본)
	local eh = Layout.FINISH_WIDTH / 2
	local eLen = Layout.FINISH.front - Layout.FINISH.back
	local eMid = (Layout.FINISH.front + Layout.FINISH.back) / 2
	for _, side in { -1, 1 } do
		lip(
			list,
			"FinishLip",
			side * (eh + 0.3),
			Layout.FINISH.front,
			Layout.FINISH.back,
			high,
			P.Cream,
			"SmoothPlastic"
		)
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"FinishBoard",
			v(Layout.FINISH_WIDTH + 1.6, 3, eLen + 1),
			P.Porcelain,
			"SmoothPlastic",
			v(0, high - t - 1.4, eMid),
			{ radius = 1.2 }
		)
	)
	supportPost(list, -8, -240, high - t - 2.9)
	supportPost(list, 8, -240, high - t - 2.9)
end

-- 마카롱 하나 (껍질 2 + 크림)
local function macaron(list: { DecorSpec }, x: number, y: number, z: number, d: number, color: RGB, anim: boolean?)
	local shell: DecorSpec = {
		name = "MacaronShell",
		shape = "Cylinder",
		size = v(d * 0.3, d, d),
		color = color,
		material = "SmoothPlastic",
		offset = v(x, y + d * 0.15, z),
		rotation = v(0, 0, 90),
	}
	add(list, shell)
	add(list, post("MacaronCream", d * 0.92, d * 0.16, P.Cream, "SmoothPlastic", v(x, y + d * 0.38, z)))
	local top = table.clone(shell)
	top.offset = v(x, y + d * 0.61, z)
	top.color = shade(color, 1.06)
	if anim then
		top.anim = { kind = "Spin", period = 6, amount = 0, axis = "X" }
	end
	add(list, top)
end

-- ── 6. 선반 위 디저트 (히어로 ②·④, 무리 지어) ─────────────────────────────
local function addDesserts(list: { DecorSpec })
	local shelf = Art.LOW_SHELF_Y
	local high = Art.HIGH_SHELF_Y

	-- 오른쪽 출발 옆: 우유팩 + 계란판 (히어로 ④ — 계란초밥 오마주)
	local mx, mz = 44, -24
	addAll(
		list,
		MapKitShapes.roundedBox(
			"MilkCarton",
			v(14, 30, 14),
			P.Rice,
			"SmoothPlastic",
			v(mx, shelf + 15, mz),
			{ style = "vertical", radius = 0.8 }
		)
	)
	add(list, block("MilkLabel", v(14.3, 9, 14.3), mix(P.IceBlue, P.Sea, 0.35), "SmoothPlastic", v(mx, shelf + 13, mz)))
	add(list, block("MilkLabelStripe", v(14.4, 1.4, 14.4), P.Mint, "SmoothPlastic", v(mx, shelf + 18.6, mz)))
	add(list, {
		name = "MilkGable",
		shape = "Wedge",
		size = v(14, 6, 7),
		color = P.Rice,
		material = "SmoothPlastic",
		offset = v(mx, shelf + 33, mz - 3.5),
		rotation = v(0, 180, 0),
	})
	add(list, {
		name = "MilkGable",
		shape = "Wedge",
		size = v(14, 6, 7),
		color = shade(P.Rice, 0.94),
		material = "SmoothPlastic",
		offset = v(mx, shelf + 33, mz + 3.5),
	})
	add(list, block("MilkFin", v(14, 2, 0.8), P.Rice, "SmoothPlastic", v(mx, shelf + 37, mz)))
	add(list, post("MilkCap", 3.4, 1.6, P.Sea, "SmoothPlastic", v(mx + 3, shelf + 34.6, mz - 3)))
	-- 계란판 + 계란 2 x 4 (하나는 김 띠를 두른 계란 — 계란초밥 캐릭터 오마주)
	local ex, ez = 42, -50
	addAll(list, MapKitShapes.bevelBox("EggTray", v(14, 3, 26), CARDBOARD, "Cardboard", v(ex, shelf + 1.5, ez), 0.8))
	for row = 0, 3 do
		for col = 0, 1 do
			local x = ex - 3.2 + col * 6.4
			local z = ez - 9.6 + row * 6.4
			add(list, post("EggCup", 5, 1.2, shade(CARDBOARD, 0.85), "Cardboard", v(x, shelf + 3.4, z)))
			add(list, {
				name = "Egg",
				shape = "Ball",
				size = v(5.6, 5.6, 5.6),
				color = if (row + col) % 3 == 0 then shade(EGG_SHELL, 0.95) else EGG_SHELL,
				material = "SmoothPlastic",
				offset = v(x, shelf + 6.2, z),
			})
		end
	end
	add(list, post("EggNori", 5.8, 1.2, P.Nori, "Fabric", v(ex + 3.2, shelf + 6.2, ez + 9.6)))
	-- 요거트 컵 무리
	for i, p in { { 52, -64, P.PastelPink }, { 56, -71, P.PastelYellow }, { 50, -74, P.PastelLavender } } do
		add(list, post("YogurtCup", 7, 8, P.Rice, "SmoothPlastic", v(p[1], shelf + 4, p[2])))
		add(list, post("YogurtLid", 7.6, 0.6, p[3], "Foil", v(p[1], shelf + 8.3, p[2])))
		if i == 1 then
			add(list, post("YogurtLabel", 7.2, 3, p[3], "SmoothPlastic", v(p[1], shelf + 4, p[2])))
		end
	end

	-- 오른쪽 젤리 계단 옆: 커스터드 푸딩 (캐러멜이 흘러내림, 반사) + 체리 (히어로 ②)
	local px, pz = 40, -112
	addAll(
		list,
		MapKitShapes.rimDisc(
			"PuddingPlate",
			26,
			1,
			P.Porcelain,
			"SmoothPlastic",
			v(px, shelf + 0.5, pz),
			{ rimColor = TRIM_DARK, rimWidth = 1, rimHeight = 0.8, segments = 14 }
		)
	)
	add(list, post("Pudding", 16, 10, P.Egg, "SmoothPlastic", v(px, shelf + 6, pz)))
	add(list, post("PuddingTop", 13, 3, shade(P.Egg, 1.05), "SmoothPlastic", v(px, shelf + 12.5, pz)))
	add(list, {
		name = "Caramel",
		shape = "Cylinder",
		size = v(1.2, 13.4, 13.4),
		color = P.Caramel,
		material = "Glass",
		offset = v(px, shelf + 14.4, pz),
		rotation = v(0, 0, 90),
		reflectance = 0.2,
	})
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		local len = 3 + (k % 3) * 1.6
		add(list, {
			name = "CaramelDrip",
			shape = "Cylinder",
			size = v(len, 1.6, 1.6),
			color = P.Caramel,
			material = "Glass",
			offset = v(px + math.cos(a) * 7.4, shelf + 14 - len / 2, pz + math.sin(a) * 7.4),
			rotation = v(0, 0, 90),
			reflectance = 0.2,
		})
	end
	add(list, ball("Whip", 5, P.Cream, "SmoothPlastic", v(px, shelf + 16.4, pz)))
	add(list, {
		name = "Cherry",
		shape = "Ball",
		size = v(3.6, 3.6, 3.6),
		color = P.TunaDark,
		material = "Glass",
		offset = v(px, shelf + 20, pz),
		reflectance = 0.25,
		anim = { kind = "Bob", period = 3.2, amount = 0.6 },
	})
	add(list, {
		name = "CherryStem",
		shape = "Block",
		size = v(0.3, 3, 0.3),
		color = P.WasabiDark,
		material = "SmoothPlastic",
		offset = v(px + 0.6, shelf + 22.6, pz),
		rotation = v(0, 0, -20),
	})

	-- 왼쪽 젤리 계단 옆: 딸기 쇼트케이크 조각 (스펀지·크림 층, 딸기, 체리)
	local cx, cz = -42, -114
	addAll(
		list,
		MapKitShapes.rimDisc(
			"CakePlate",
			30,
			1,
			P.Porcelain,
			"SmoothPlastic",
			v(cx, shelf + 0.5, cz),
			{ rimColor = TRIM_DARK, rimWidth = 1, rimHeight = 0.8, segments = 14 }
		)
	)
	local sliceLayers = {
		{ y0 = 1, y1 = 5, c = SPONGE },
		{ y0 = 5, y1 = 6.5, c = P.Cream },
		{ y0 = 6.5, y1 = 7.6, c = P.Strawberry },
		{ y0 = 7.6, y1 = 11.6, c = SPONGE },
		{ y0 = 11.6, y1 = 14, c = P.Cream },
	}
	for _, layer in sliceLayers do
		-- 위에서 본 삼각형 조각: Wedge를 Z축으로 90° 눕혀 높이 = size.x
		add(list, {
			name = "CakeSlice",
			shape = "Wedge",
			size = v(layer.y1 - layer.y0, 14, 22),
			color = layer.c,
			material = "SmoothPlastic",
			offset = v(cx, shelf + (layer.y0 + layer.y1) / 2, cz),
			rotation = v(0, 30, 90),
		})
	end
	add(
		list,
		block(
			"CakeFrosting",
			v(14.6, 14, 1),
			P.Cream,
			"SmoothPlastic",
			v(cx + 5.5 * 0.5, shelf + 7.5, cz - 9.53),
			v(0, 30, 0)
		)
	)
	for k = 0, 2 do
		add(
			list,
			ball("CakeStrawberry", 4, P.Strawberry, "SmoothPlastic", v(cx - 1 + k * 2.6, shelf + 16, cz - 4 + k * 1.2))
		)
	end
	add(list, ball("CakeCream", 3.4, P.Cream, "SmoothPlastic", v(cx + 3, shelf + 15.4, cz - 6)))
	add(list, {
		name = "Cherry",
		shape = "Ball",
		size = v(3, 3, 3),
		color = P.TunaDark,
		material = "Glass",
		offset = v(cx + 3, shelf + 18.4, cz - 6),
		reflectance = 0.25,
		anim = { kind = "Bob", period = 2.8, amount = 0.5 },
	})

	-- 왼쪽 출발 옆: 잼 병 무리 (딸기·자두·살구) + 버터 상자
	for i, p in { { -46, -22, P.Strawberry, 10, 12 }, { -54, -30, P.Plum, 8, 10 }, { -40, -34, P.Caramel, 7, 9 } } do
		local d, h = p[4], p[5]
		add(list, {
			name = "JamJar",
			shape = "Cylinder",
			size = v(h, d, d),
			color = p[3],
			material = "Glass",
			offset = v(p[1], shelf + h / 2, p[2]),
			rotation = v(0, 0, 90),
			transparency = 0.15,
			reflectance = 0.2,
		})
		add(
			list,
			post(
				"JamLid",
				d + 0.6,
				2,
				if i == 1 then P.PastelPink else P.Rice,
				"SmoothPlastic",
				v(p[1], shelf + h + 1, p[2])
			)
		)
		add(list, post("JamLabel", d + 0.2, h * 0.35, P.Cream, "SmoothPlastic", v(p[1], shelf + h * 0.45, p[2])))
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"ButterBox",
			v(16, 6, 9),
			P.PastelYellow,
			"SmoothPlastic",
			v(-46, shelf + 3, -52),
			{ radius = 0.8 }
		)
	)
	add(list, block("ButterBand", v(16.3, 1.4, 9.3), P.Sea, "SmoothPlastic", v(-46, shelf + 3, -52)))

	-- 왼쪽 구멍 옆: 젤리 컵 무리 (출렁 Pulse — 장식 젤리만, 판정 젤리는 고정)
	local jellyColors = { P.Strawberry, P.Lime, mix(P.Mint, P.IceBlue, 0.3), P.Strawberry, P.Lime }
	for i, p in { { -38, -64 }, { -46, -70 }, { -40, -78 }, { -52, -82 }, { -36, -90 } } do
		local d = 8 + (i % 3)
		local color = jellyColors[i]
		add(list, post("JellyCup", d + 1, 2, P.Rice, "SmoothPlastic", v(p[1], shelf + 1, p[2])))
		add(list, {
			name = "DecorJelly",
			shape = "Cylinder",
			size = v(d * 0.7, d, d),
			color = color,
			material = "Glass",
			offset = v(p[1], shelf + 2 + d * 0.35, p[2]),
			rotation = v(0, 0, 90),
			transparency = 0.25,
			reflectance = 0.15,
			anim = { kind = "Pulse", period = 2.2 + i * 0.3, amount = 0.08 },
		})
		add(list, {
			name = "DecorJellyTop",
			shape = "Ball",
			size = v(d * 0.8, d * 0.8, d * 0.8),
			color = shade(color, 1.1),
			material = "Glass",
			offset = v(p[1], shelf + 2 + d * 0.7, p[2]),
			transparency = 0.25,
			reflectance = 0.15,
			anim = { kind = "Pulse", period = 2.2 + i * 0.3, amount = 0.08 },
		})
	end

	-- 오른쪽 찬바람 선반 옆: 초콜릿 판 (기울여 세움) + 마카롱 진열 (Spin)
	for k = 0, 1 do
		add(
			list,
			block(
				"ChocolateBar",
				v(2, 18, 28),
				shade(P.Chocolate, 1 - k * 0.12),
				"SmoothPlastic",
				v(48 + k * 4, shelf + 9, -150 - k * 6),
				v(0, 10, -10 + k * 6)
			)
		)
		for r = 0, 3 do
			add(
				list,
				block(
					"ChocolateRidge",
					v(0.6, 0.5, 27),
					shade(P.Chocolate, 0.8),
					"SmoothPlastic",
					v(48 + k * 4 - 1.1, shelf + 3 + r * 4, -150 - k * 6),
					v(0, 10, -10 + k * 6)
				)
			)
		end
	end
	addAll(
		list,
		MapKitShapes.rimDisc(
			"MacaronStand",
			24,
			1.2,
			P.Porcelain,
			"SmoothPlastic",
			v(40, shelf + 0.6, -190),
			{ rimColor = TRIM_DARK, rimWidth = 0.8, rimHeight = 0.8, segments = 12 }
		)
	)
	local pastels = { P.PastelPink, P.Mint, P.PastelYellow, P.PastelLavender, P.PastelSky, P.Matcha }
	for i = 1, 6 do
		local a = (i - 1) * math.pi / 3
		macaron(list, 40 + math.cos(a) * 7, shelf + 1.2, -190 + math.sin(a) * 7, 6, pastels[i], i % 2 == 0)
	end
	macaron(list, 40, shelf + 1.2, -190, 7, P.Strawberry, true)

	-- 왼쪽 찬바람 선반 옆: 아이스크림 통 + 스쿱
	addAll(
		list,
		MapKitShapes.roundedBox(
			"IceCreamTub",
			v(20, 12, 16),
			P.PastelSky,
			"SmoothPlastic",
			v(-44, shelf + 6, -170),
			{ radius = 1.2 }
		)
	)
	add(list, block("TubLabel", v(20.3, 4, 16.3), P.Rice, "SmoothPlastic", v(-44, shelf + 6, -170)))
	for k, c in { P.PastelPink, P.Cream, P.Chocolate } do
		add(list, ball("TubScoop", 7, c, "SmoothPlastic", v(-50 + k * 4, shelf + 13, -170 + (k % 2) * 3)))
	end
	addAll(list, MapKitShapes.capsule("Spoon", 16, 1.6, STEEL, "Metal", v(-40, shelf + 15, -168), v(0, 20, 30)))

	-- 결승 양옆: 마카롱 탑 (높은 표지) + 위를 잇는 막대 과자 + 따뜻한 전구
	local fz = Layout.FINISH_LINE_Z
	for _, side in { -1, 1 } do
		local x = side * 35
		for k = 0, 7 do
			macaron(list, x, shelf + k * 6.2, fz, 9, pastels[1 + (k + (if side > 0 then 2 else 0)) % #pastels])
		end
		add(list, ball("TowerCherry", 4, P.TunaDark, "Glass", v(x, shelf + 55, fz)))
	end
	addAll(
		list,
		MapKitShapes.capsule("PockyStick", 74, 2.4, P.Chocolate, "SmoothPlastic", v(0, Art.LOW_SHELF_Y + 51.5, fz))
	)
	addAll(
		list,
		MapKitShapes.capsule("PockyBiscuit", 10, 2.6, P.Caramel, "SmoothPlastic", v(38, Art.LOW_SHELF_Y + 51.5, fz))
	)
	for k = -3, 3 do
		local bulb: DecorSpec = {
			name = "FinishBulb",
			shape = "Ball",
			size = v(1.6, 1.6, 1.6),
			color = WARM,
			material = "Neon",
			offset = v(k * 8, Art.LOW_SHELF_Y + 49, fz),
			castShadow = false,
		}
		if k == -2 or k == 2 then
			bulb.light = { kind = "Point", color = WARM, brightness = 1.2, range = 22 }
		end
		add(list, bulb)
	end

	-- 위 선반: 병·통 무리 (BG 디테일, 적게)
	for i, p in
		{
			{ -48, -40, P.Sea },
			{ -54, -46, P.Mint },
			{ 50, -130, P.PastelPink },
			{ 46, -138, P.Rice },
			{ -50, -200, P.Matcha },
		}
	do
		local h = 14 + (i % 3) * 3
		add(list, {
			name = "UpperJar",
			shape = "Cylinder",
			size = v(h, 9, 9),
			color = p[3],
			material = "Glass",
			offset = v(p[1], high + h / 2, p[2]),
			rotation = v(0, 0, 90),
			transparency = 0.2,
			reflectance = 0.15,
		})
		add(list, post("UpperJarLid", 9.6, 2, P.Rice, "SmoothPlastic", v(p[1], high + h + 1, p[2])))
	end
	addAll(
		list,
		MapKitShapes.roundedBox(
			"CakeBox",
			v(22, 14, 22),
			P.PastelPink,
			"Cardboard",
			v(48, high + 7, -60),
			{ radius = 0.6 }
		)
	)
	add(list, block("CakeBoxRibbon", v(22.3, 14.3, 2), P.Strawberry, "Fabric", v(48, high + 7, -60)))
	addAll(
		list,
		MapKitShapes.roundedBox(
			"CheeseBlock",
			v(18, 10, 14),
			P.PastelYellow,
			"SmoothPlastic",
			v(-46, high + 5, -110),
			{ radius = 1 }
		)
	)
end

-- ── 7. 열린 양문 (히어로 ③·⑤): 문 선반에 병·소스·아이스크림 콘 탑 ──────────────
local function addDoors(list: { DecorSpec })
	local X, front = Art.IN_X, Art.FRONT_Z
	local doorW, doorT = 66, 8
	local bottom, top = Art.FLOOR_Y - 4, Art.CEIL_Y + 6
	local doorH = top - bottom
	local midY = (bottom + top) / 2
	for _, side in { -1, 1 } do
		local hingeX = side * (X + 4)
		local dz = front - doorW / 2 - 2
		local outerX = hingeX + side * doorT / 2
		addAll(
			list,
			MapKitShapes.roundedBox(
				"FridgeDoor",
				v(doorT, doorH, doorW),
				P.Frost,
				"SmoothPlastic",
				v(outerX, midY, dz),
				{ radius = 1.6 }
			)
		)
		-- 안쪽 면(코스 쪽): 살짝 들어간 내장재 + 패킹
		local innerX = hingeX - side * 0.3
		add(list, block("DoorLiner", v(0.6, doorH - 8, doorW - 8), LINER_SHADE, "SmoothPlastic", v(innerX, midY, dz)))
		add(
			list,
			block(
				"DoorGasketV",
				v(0.8, doorH - 4, 1.2),
				STEEL_DARK,
				"Rubber",
				v(innerX - side * 0.2, midY, dz - doorW / 2 + 2.6)
			)
		)
		add(
			list,
			block(
				"DoorGasketV",
				v(0.8, doorH - 4, 1.2),
				STEEL_DARK,
				"Rubber",
				v(innerX - side * 0.2, midY, dz + doorW / 2 - 2.6)
			)
		)
		-- 바깥 손잡이 + 자석
		addAll(
			list,
			MapKitShapes.capsule(
				"DoorHandle",
				50,
				2.4,
				STEEL,
				"Metal",
				v(outerX + side * 5, midY + 6, dz - doorW / 2 + 5),
				v(0, 0, 90)
			)
		)
		for k, c in { P.Strawberry, P.PastelYellow, P.Mint, P.PastelSky } do
			add(
				list,
				post(
					"FridgeMagnet",
					4,
					1,
					c,
					"SmoothPlastic",
					v(outerX + side * 4.5, midY + 20 - k * 7, dz + 10 - (k % 2) * 8)
				)
			)
		end
		-- 문 선반 3칸
		for b, y in { -18, 14, 42 } do
			local binIn = 11
			local bx = hingeX - side * binIn / 2
			add(list, block("DoorBinFloor", v(binIn, 1, doorW - 10), LINER, "SmoothPlastic", v(bx, y, dz)))
			add(list, {
				name = "DoorBinFront",
				shape = "Block",
				size = v(0.8, 7, doorW - 10),
				color = TRIM,
				material = "Glass",
				offset = v(hingeX - side * (binIn - 0.4), y + 3, dz),
				transparency = 0.3,
				castShadow = false,
			})
			add(
				list,
				block(
					"DoorBinRim",
					v(1.2, 1, doorW - 10),
					TRIM_DARK,
					"SmoothPlastic",
					v(hingeX - side * (binIn - 0.4), y + 6.8, dz)
				)
			)
			if side > 0 and b == 2 then
				-- 아이스크림 콘 탑 (히어로 ③): 콘 2개 + 스쿱 3단
				for c = 0, 1 do
					local cxz = dz - 8 + c * 16
					local ccx = bx + 0.5
					for s = 0, 3 do
						local d = 6.4 - s * 1.4
						add(
							list,
							post(
								"IceCreamCone",
								d,
								3,
								if s % 2 == 0 then P.Caramel else shade(P.Caramel, 0.85),
								"Pebble",
								v(ccx, y + 5 + (3 - s) * 3, cxz)
							)
						)
					end
					local scoops = if c == 0 then { P.PastelPink, P.Mint } else { P.Cream, P.PastelLavender }
					for s, color in scoops do
						add(
							list,
							ball(
								"IceCreamScoop",
								8 - s * 0.6,
								color,
								"SmoothPlastic",
								v(ccx, y + 17 + (s - 1) * 6, cxz)
							)
						)
					end
					add(list, {
						name = "Cherry",
						shape = "Ball",
						size = v(2.6, 2.6, 2.6),
						color = P.TunaDark,
						material = "Glass",
						offset = v(ccx, y + 26.5, cxz),
						reflectance = 0.25,
						anim = { kind = "Bob", period = 3.6 + c, amount = 0.5 },
					})
				end
			else
				-- 병·소스: 간장병(초밥집 오마주)·머스터드·우유·라임 소다
				local bottles = { P.SoyDark, P.Egg, P.Rice, P.Lime }
				for n = 0, 3 do
					local color = bottles[1 + (n + b + (if side > 0 then 1 else 0)) % #bottles]
					local h = 14 + ((n + b) % 3) * 3
					local bz = dz - 22 + n * 14
					local glass = color == P.Lime or color == P.SoyDark
					local body: DecorSpec = {
						name = "Bottle",
						shape = "Cylinder",
						size = v(h, 6, 6),
						color = color,
						material = if glass then "Glass" else "SmoothPlastic",
						offset = v(bx, y + 0.5 + h / 2, bz),
						rotation = v(0, 0, 90),
						reflectance = if glass then 0.2 else nil,
					}
					if n == 1 then
						body.anim = { kind = "Sway", period = 4.2 + b * 0.5, amount = 3, axis = "X" }
					end
					add(list, body)
					add(
						list,
						post(
							"BottleNeck",
							3,
							4,
							color,
							if glass then "Glass" else "SmoothPlastic",
							v(bx, y + 0.5 + h + 2, bz)
						)
					)
					add(
						list,
						post(
							"BottleCap",
							3.4,
							1.4,
							if color == P.SoyDark then P.Lacquer else P.Rice,
							"SmoothPlastic",
							v(bx, y + 0.5 + h + 4.6, bz)
						)
					)
					add(
						list,
						post(
							"BottleLabel",
							6.3,
							h * 0.35,
							if color == P.SoyDark then P.Rice else P.Cream,
							"SmoothPlastic",
							v(bx, y + 0.5 + h * 0.45, bz)
						)
					)
				end
			end
		end
		-- 문 가장자리 서리 (차가운 공기가 따뜻한 주방으로)
		add(list, {
			name = "DoorFrost",
			shape = "Block",
			size = v(1, 2, 2),
			color = P.Frost,
			material = "Ice",
			offset = v(hingeX - side * 2, Art.CEIL_Y - 4, front - 2),
			particle = "Frost",
			particleRate = 3,
		})
	end
end

-- ── 8. 문 너머 따뜻한 주방 (히어로 ⑤의 배경, 온도 대비) ─────────────────────
local function addKitchen(list: { DecorSpec })
	local floorY = Art.KITCHEN_FLOOR_Y
	local front = Art.FRONT_Z
	-- 마루 바닥 (냉장고 밑까지 넓게) — 줄마다 shade
	local planks = { P.WoodLight, P.Wood, shade(P.Wood, 0.9), P.WoodLight, shade(P.Wood, 0.95) }
	for i = 1, 5 do
		local w = 160
		add(
			list,
			block(
				"KitchenFloor",
				v(w, 4, 900),
				shade(planks[i], 0.9),
				"WoodPlanks",
				v(-400 + (i - 0.5) * w, floorY - 2, -200)
			)
		)
	end
	-- 뒷벽 (냉장고 앞 300)
	local wallZ = front - 300
	add(list, block("KitchenWall", v(800, 380, 6), KITCHEN_WALL, "Plaster", v(0, floorY + 190, wallZ)))
	add(
		list,
		block(
			"KitchenWallTile",
			v(800, 50, 1),
			shade(KITCHEN_WALL, 1.12),
			"CeramicTiles",
			v(0, floorY + 118, wallZ + 3.5)
		)
	)
	-- 아래장 + 상판 + 위장
	local counterTop = floorY + 90
	for k = -3, 3 do
		addAll(
			list,
			MapKitShapes.roundedBox(
				"BaseCabinet",
				v(78, 86, 58),
				if k % 2 == 0 then P.WoodDark else shade(P.WoodDark, 1.1),
				"Wood",
				v(k * 80, floorY + 43, wallZ + 34),
				{ style = "vertical", radius = 2 }
			)
		)
		add(list, block("CabinetKnob", v(8, 2, 2), STEEL, "Metal", v(k * 80, floorY + 76, wallZ + 64)))
		if math.abs(k) >= 2 then
			addAll(
				list,
				MapKitShapes.roundedBox(
					"WallCabinet",
					v(78, 70, 36),
					shade(P.WoodDark, 1.05),
					"Wood",
					v(k * 80, floorY + 210, wallZ + 22),
					{ style = "vertical", radius = 2 }
				)
			)
		end
	end
	addAll(
		list,
		MapKitShapes.bevelBox(
			"Countertop",
			v(570, 5, 64),
			mix(P.Porcelain, KITCHEN_WALL, 0.3),
			"Marble",
			v(0, counterTop + 2.5, wallZ + 34),
			1.4
		)
	)
	-- 창: 노을빛 (따뜻한 빛의 원인) + 나무 틀
	local winY = floorY + 180
	add(list, {
		name = "KitchenWindow",
		shape = "Block",
		size = v(150, 90, 1),
		color = WARM_DEEP,
		material = "Neon",
		offset = v(0, winY, wallZ + 3.6),
		castShadow = false,
		light = { kind = "Point", color = WARM, brightness = 2.5, range = 60 },
	})
	addAll(
		list,
		MapKitShapes.lipTrim("WindowFrame", v(150, 0, 90), 6, 4, P.Wood, "Wood", v(0, winY, wallZ + 6), v(90, 0, 0))
	)
	add(list, block("WindowMullion", v(4, 90, 4), P.Wood, "Wood", v(0, winY, wallZ + 6)))
	-- 매달린 등 2개 (따뜻한 빛)
	for _, x in { -90, 90 } do
		add(list, post("PendantCord", 0.8, 120, P.Nori, "Fabric", v(x, floorY + 260, wallZ + 80)))
		add(list, {
			name = "PendantShade",
			shape = "Ball",
			size = v(26, 26, 26),
			color = WARM_DEEP,
			material = "SmoothPlastic",
			offset = v(x, floorY + 200, wallZ + 80),
		})
		add(list, {
			name = "PendantBulb",
			shape = "Ball",
			size = v(14, 14, 14),
			color = WARM,
			material = "Neon",
			offset = v(x, floorY + 188, wallZ + 80),
			castShadow = false,
			light = { kind = "Point", color = WARM, brightness = 3, range = 60 },
		})
	end
	-- 상판 위 소품 실루엣: 주전자·도마·초밥 접시
	addAll(
		list,
		MapKitShapes.roundedBox(
			"Kettle",
			v(30, 26, 26),
			P.Lacquer,
			"SmoothPlastic",
			v(-170, counterTop + 18, wallZ + 34),
			{ radius = 6 }
		)
	)
	addAll(
		list,
		MapKitShapes.bevelBox("CuttingBoard", v(70, 4, 40), P.WoodLight, "Wood", v(150, counterTop + 7, wallZ + 34), 1)
	)
	addAll(
		list,
		MapKitShapes.rimDisc(
			"SushiPlate",
			36,
			2,
			P.Porcelain,
			"SmoothPlastic",
			v(40, counterTop + 6, wallZ + 34),
			{ rimColor = P.PorcelainRim, rimWidth = 1.4 }
		)
	)
	for k = 0, 2 do
		add(list, block("SushiRice", v(8, 5, 5), P.Rice, "SmoothPlastic", v(32 + k * 8, counterTop + 9.5, wallZ + 34)))
		add(
			list,
			block(
				"SushiTopping",
				v(9, 1.6, 5.6),
				if k == 1 then P.Egg else P.Salmon,
				"SmoothPlastic",
				v(32 + k * 8, counterTop + 12.6, wallZ + 34)
			)
		)
	end
	-- 문 바로 앞 주방 스포트라이트 (그림자 조명 2/2): 위 들보에 매단 등이 따뜻한 빛을 열린 문 안 결승 쪽으로 비춰요
	local lampZ = front - 8
	add(
		list,
		post("KitchenLampRod", 1.2, Art.CEIL_Y + 10 - 58, STEEL_DARK, "Metal", v(0, (Art.CEIL_Y + 10 + 58) / 2, lampZ))
	)
	addAll(
		list,
		MapKitShapes.roundedBox(
			"KitchenLampShade",
			v(9, 6, 9),
			WARM_DEEP,
			"SmoothPlastic",
			v(0, 57, lampZ),
			{ radius = 1.4 }
		)
	)
	add(list, {
		name = "KitchenSpot",
		shape = "Block",
		size = v(6, 1, 6),
		color = WARM,
		material = "Neon",
		offset = v(0, 53.6, lampZ),
		rotation = v(-40, 0, 0),
		castShadow = false,
		light = { kind = "Spot", color = WARM, brightness = 6, range = 60, angle = 80, face = "Back", shadows = true },
	})
	-- 문가 따뜻한 빛 먼지
	for _, x in { -30, 30 } do
		add(list, {
			name = "WarmDustSource",
			shape = "Block",
			size = v(1, 1, 1),
			color = WARM,
			material = "SmoothPlastic",
			offset = v(x, 30, front - 6),
			particle = "Dust",
			particleRate = 2,
			transparency = 0.6,
		})
	end
end

function Art.decor(): { DecorSpec }
	local list: { DecorSpec } = {}
	addShell(list)
	addLights(list)
	addShelves(list)
	addCrisper(list)
	addCourse(list)
	addDesserts(list)
	addDoors(list)
	addKitchen(list)
	return list
end

-- 각 바닥 위 2~12: 장식이 들어가면 안 되는 코스 시야 상자
function Art.courseVolume(): { Bounds }
	local low, high = Layout.LOW_Y, Layout.HIGH_Y
	local function box(halfX: number, floorY: number, front: number, back: number): Bounds
		return { min = v(-halfX, floorY + 2, back), max = v(halfX, floorY + 12, front) }
	end
	return {
		box(Layout.START_WIDTH / 2, low, Layout.START.front, Layout.START.back),
		box(Layout.ICE_TRAY_WIDTH / 2, low, Layout.ICE_TRAY.front, Layout.ICE_TRAY.back),
		box(Layout.JELLY_ZONE_WIDTH / 2, low, Layout.JELLY_ZONE.front, Layout.LANDING.front),
		box(Layout.JELLY_ZONE_WIDTH / 2, high, Layout.LANDING.front, Layout.LANDING.back),
		box(Layout.FAN_SHELF_WIDTH / 2, high, Layout.FAN_SHELF.front, Layout.FAN_SHELF.back),
		box(Layout.FINISH_WIDTH / 2, high, Layout.FINISH.front, Layout.FINISH.back),
	}
end

-- 맵 조명: 차가운 냉장고 안 (흰-파랑 냉기, 높은 차가운 Ambient) — 따뜻한 빛은 문밖 주방 조명이 맡아요
Art.LIGHTING = {
	ClockTime = 13,
	Brightness = 1.2,
	Ambient = { r = 154, g = 180, b = 220 },
	OutdoorAmbient = { r = 170, g = 192, b = 220 },
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.8,
	ShadowSoftness = 0.35,
	ExposureCompensation = 0,
	Atmosphere = {
		Density = 0.22,
		Offset = 0.04,
		Color = { r = 214, g = 230, b = 244 },
		Decay = { r = 176, g = 198, b = 226 },
		Glare = 0,
		Haze = 0.6,
	},
	ColorCorrection = {
		Brightness = 0,
		Contrast = 0.14,
		Saturation = 0.14,
		TintColor = { r = 240, g = 247, b = 255 },
	},
	Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.1 },
	SunRays = { Intensity = 0, Spread = 0.5 },
} :: MapLighting.MapLighting

function Art.introCamera(): { IntroPoint }
	return {
		-- ① 문 쪽에서 코스 전체를 거꾸로 (냉장고 안 + 뒷벽 LED 패널)
		{ pos = v(22, 54, -256), lookAt = v(0, 0, -80) },
		-- ② 얼음 구멍·큐브
		{ pos = v(-18, 20, -22), lookAt = v(0, -1, -58) },
		-- ③ 젤리 계단을 위에서 내려다보는 샷 (젤리 3개·쿠키 계단·케이크 단, 양옆 푸딩·쇼트케이크)
		{ pos = v(-16, 30, -96), lookAt = v(0, 2, -124) },
		-- ④ 출발 자리 (멀리 결승 문빛)
		{ pos = v(0, 14, 24), lookAt = v(0, 8, -80) },
	}
end

return Art
