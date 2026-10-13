--!strict
-- 사용자 콘셉트 시트(2026-10-13)를 따른 연어초밥 캐릭터 견본 (m5-27). **렌더 확인용 견본이라 게임에서는 안 써요** —
-- 게임 캐릭터(SushiBody·AppearanceService·스킨 31종)는 그대로예요. 모양이 정해지면 SushiBody로 옮길지 따로 정해요.
--   layout(expression?, pose?)  파츠 목록 (순수 함수, SushiBody.PartSpec과 같은 모양 — lune 테스트·LayoutCheck 가능)
--   build(expression?, pose?)   파츠를 만든 Model. PrimaryPart = Body(Anchored). 원점 = 밥 중심 → PivotTo로 옮겨요.
--   EXPRESSIONS                 "Default"(기본) · "Happy"(신남 ^ ^) · "Flustered"(당황 o + 땀) · "Hurt"(아픔 x x + 반창고)
--   POSES                       "Stand"(서 있기) · "Run"(달리기: 팔 앞뒤, 한 발 앞)
--   GROUND_OFFSET               밥 중심에서 발바닥까지
-- 모양 (앞 = -Z, 위 = +Y, 메시 없이 Block·Ball·Cylinder만):
--   밥: 세로 모서리가 둥근 넓은 덩어리(Salt 재질 = 밥알 결) + 아래 한 단 좁은 받침
--   연어: 밥보다 넓은 "베개"(모든 모서리 둥근 판)가 앞·뒤·옆으로 늘어지고, 위에 둥근 등성이(캡슐)가 솟아 돔처럼.
--         밝은 지방 줄은 등성이·앞 늘어짐을 가로지르는 얇은 원판 조각
--   김 띠: 가운데를 앞에서 뒤로 — 앞 늘어짐 위에서 시작해 등성이를 넘어 등 아래까지 (뒤에서 가운데 세로 띠)
--   얼굴: 밥 앞면에 작은 타원 눈(원판 두 개를 겹친 캡슐) + 하이라이트, 작게 벌린 웃는 입(진한 입 + 분홍 혀), 분홍 볼
--   팔: 옆에 작은 네모 흰 손(벙어리장갑), 다리: 짧은 네모 흰 발 두 개. 팔·다리는 Motor6D(나중에 흔들 수 있게)

local SushiBody = require(script.Parent.SushiBody)

local SushiConceptSample = {}

export type Expression = "Default" | "Happy" | "Flustered" | "Hurt"
export type Pose = "Stand" | "Run"
type PartSpec = SushiBody.PartSpec

SushiConceptSample.EXPRESSIONS = { "Default", "Happy", "Flustered", "Hurt" } :: { Expression }
SushiConceptSample.POSES = { "Stand", "Run" } :: { Pose }

---------------------------------------------------------------- 치수
local RICE_W, RICE_H, RICE_D, RICE_R = 3.6, 2.0, 2.7, 0.45 -- 밥 (y -1.0~1.0, 세로 모서리 반지름)
local FRONT = -RICE_D / 2 -- 밥 앞면 z (-1.35)
local BASE_H = 0.3 -- 아래 받침 (y -1.3~-1.0)
local LEG_W, LEG_H, LEG_D, LEG_X = 0.72, 1.0, 0.78, 0.8 -- 다리 (위끝은 받침 속)
local SOLE = -2.0 -- 발바닥

local TOP_W, TOP_D, TOP_T = 3.86, 2.9, 0.6 -- 연어 늘어진 가장자리 판: 폭·깊이·두께 (모서리 반지름 = 두께/2)
local TOP_Y = 0.85 -- 판 중심 (y 0.55~1.15 → 밥 위끝 1.0보다 0.45 아래까지 늘어져요)
-- 돔 = 큰 캡슐(축 X): 판 대부분을 덮고 솟아 앞뒤·좌우로 둥글게 내려와요. 판은 돔 아래로 0.17쯤 삐져나온
-- 늘어진 입술(가장자리)로만 보여요 — 모자 챙처럼 수평으로 튀어나오지 않게.
-- 아래쪽은 밥 속에 숨어요 (판 아래끝 높이에서 앞뒤 1.339 < 밥 1.35, 좌우 1.759 < 밥 1.8)
local RIDGE_D, RIDGE_HALF, RIDGE_Y = 2.7, 0.44, 0.62 -- 지름, 가운데 원기둥 반길이, 중심 (꼭대기 1.97)
local EDGE_Z = (TOP_D - TOP_T) / 2 -- 판 앞뒤 둥근 모서리 원기둥 z (±1.3)

---------------------------------------------------------------- 색
local RICE = { 250, 248, 242 }
local SALMON = { 255, 122, 64 }
local SALMON_FAT = { 255, 196, 160 }
local NORI = { 38, 46, 40 }
local INK = { 30, 22, 24 }
local WHITE = { 255, 255, 255 }
local MOUTH = { 110, 30, 40 }
local TONGUE = { 255, 120, 140 }
local CHEEK = { 255, 170, 180 }
local SWEAT = { 140, 210, 255 }
local BANDAGE = { 250, 214, 170 }
local BANDAGE_PAD = { 236, 180, 140 }

---------------------------------------------------------------- 도우미
type Extra = { shape: SushiBody.Shape?, rotation: { number }?, joint: boolean?, transparency: number? }

local function piece(
	name: string,
	size: { number },
	color: { number },
	offset: { number },
	material: string?,
	extra: Extra?
): PartSpec
	return {
		name = name,
		size = size,
		color = color,
		material = material or "SmoothPlastic",
		offset = offset,
		shape = extra and extra.shape,
		rotation = extra and extra.rotation,
		joint = extra and extra.joint,
		transparency = extra and extra.transparency,
	}
end

local UPRIGHT = { 0, 0, 90 } -- 원기둥 축 Y
local FACING = { 0, 90, 0 } -- 원기둥 축 Z (앞을 보는 원판)
local ALONG_Z = { 0, 90, 0 }

local function ball(name: string, d: number, color: { number }, offset: { number }, material: string?): PartSpec
	return piece(name, { d, d, d }, color, offset, material, { shape = "Ball" })
end

-- 앞을 보는 얇은 원판 (얼굴 장식). z는 앞면 위에 얹는 중심
local function faceDisc(name: string, d: number, color: { number }, x: number, y: number, z: number): PartSpec
	return piece(name, { 0.06, d, d }, color, { x, y, z }, nil, { shape = "Cylinder", rotation = FACING })
end

-- 세로 모서리가 둥근 덩어리 (위에서 보면 모서리 둥근 직사각형): 상자 2 + 세운 원기둥 4
local function roundedPrism(
	prefix: string,
	center: { number },
	w: number,
	h: number,
	d: number,
	r: number,
	color: { number },
	material: string?
): { PartSpec }
	local cx, cy, cz = center[1], center[2], center[3]
	local list = {
		piece(prefix, { w - 2 * r, h, d }, color, { cx, cy, cz }, material),
		piece(`{prefix}Wide`, { w, h, d - 2 * r }, color, { cx, cy, cz }, material),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			table.insert(
				list,
				piece(
					`{prefix}Corner{i}`,
					{ h, 2 * r, 2 * r },
					color,
					{ cx + sx * (w / 2 - r), cy, cz + sz * (d / 2 - r) },
					material,
					{ shape = "Cylinder", rotation = UPRIGHT }
				)
			)
		end
	end
	return list
end

-- 모든 모서리가 둥근 판 ("베개"): 가운데 상자 + 앞뒤 원기둥(축 X) + 옆 원기둥(축 Z) + 구석 공 4. 반지름 = 두께/2
local function pillow(
	prefix: string,
	center: { number },
	w: number,
	t: number,
	d: number,
	color: { number },
	material: string?
): { PartSpec }
	local cx, cy, cz = center[1], center[2], center[3]
	local ex, ez = (w - t) / 2, (d - t) / 2
	local list = {
		piece(prefix, { w - t, t, d - t }, color, { cx, cy, cz }, material),
		piece(`{prefix}Front`, { w - t, t, t }, color, { cx, cy, cz - ez }, material, { shape = "Cylinder" }),
		piece(`{prefix}Back`, { w - t, t, t }, color, { cx, cy, cz + ez }, material, { shape = "Cylinder" }),
		piece(`{prefix}Left`, { d - t, t, t }, color, { cx - ex, cy, cz }, material, {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
		piece(`{prefix}Right`, { d - t, t, t }, color, { cx + ex, cy, cz }, material, {
			shape = "Cylinder",
			rotation = ALONG_Z,
		}),
	}
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			table.insert(list, ball(`{prefix}Corner{i}`, t, color, { cx + sx * ex, cy, cz + sz * ez }, material))
		end
	end
	return list
end

local function join(...: { PartSpec }): { PartSpec }
	local list: { PartSpec } = {}
	for _, group in { ... } do
		for _, spec in group do
			table.insert(list, spec)
		end
	end
	return list
end

---------------------------------------------------------------- 몸 (표정·자세와 무관)
local function body(): { PartSpec }
	return join(
		roundedPrism("Body", { 0, 0, 0 }, RICE_W, RICE_H, RICE_D, RICE_R, RICE, "Salt"),
		{
			-- 아래 한 단 좁은 받침: 바닥 모서리가 둥글어 보이게 (상자 두 개를 엇갈려 모서리를 깎아요)
			piece("BodyBase", { RICE_W - 0.9, BASE_H, RICE_D - 0.3 }, RICE, { 0, -1.0 - BASE_H / 2 + 0.01, 0 }, "Salt"),
			piece(
				"BodyBaseWide",
				{ RICE_W - 0.3, BASE_H, RICE_D - 0.9 },
				RICE,
				{ 0, -1.0 - BASE_H / 2 + 0.01, 0 },
				"Salt"
			),
		},
		-- 연어: 늘어진 베개 + 돔 등성이
		pillow("Topping", { 0, TOP_Y, 0 }, TOP_W, TOP_T, TOP_D, SALMON),
		{
			piece(
				"Ridge",
				{ 2 * RIDGE_HALF, RIDGE_D, RIDGE_D },
				SALMON,
				{ 0, RIDGE_Y, 0 },
				nil,
				{ shape = "Cylinder" }
			),
			ball("RidgeLeft", RIDGE_D, SALMON, { -RIDGE_HALF, RIDGE_Y, 0 }),
			ball("RidgeRight", RIDGE_D, SALMON, { RIDGE_HALF, RIDGE_Y, 0 }),
		}
	)
end

-- 지방 줄: 등성이와 앞 늘어짐을 가로지르는 얇은 원판 조각 (같은 축이라 표면을 따라 휘어 보여요)
local STRIPE_X = { -0.95, 0.5, 1.12 }
local function stripes(): { PartSpec }
	local list: { PartSpec } = {}
	for i, x in STRIPE_X do
		-- 등성이 끝(공 부분)에서는 그 자리 단면 지름에 맞춰요
		local over = math.max(0, math.abs(x) - RIDGE_HALF)
		local r = RIDGE_D / 2
		local d = 2 * math.sqrt(r * r - over * over) + 0.04
		table.insert(
			list,
			piece(`Stripe{i}`, { 0.12, d, d }, SALMON_FAT, { x, RIDGE_Y, 0 }, nil, {
				shape = "Cylinder",
			})
		)
		table.insert(
			list,
			piece(`StripeFront{i}`, { 0.12, TOP_T + 0.04, TOP_T + 0.04 }, SALMON_FAT, { x, TOP_Y, -EDGE_Z }, nil, {
				shape = "Cylinder",
			})
		)
	end
	return list
end

-- 김 띠 (가운데, 앞 늘어짐 → 등성이 → 뒤 늘어짐 → 등 아래)
local NORI_W = 0.7
local function nori(): { PartSpec }
	return {
		piece("NoriRidge", { NORI_W, RIDGE_D + 0.06, RIDGE_D + 0.06 }, NORI, { 0, RIDGE_Y, 0 }, "Fabric", {
			shape = "Cylinder",
		}),
		piece("NoriFront", { NORI_W, TOP_T + 0.06, TOP_T + 0.06 }, NORI, { 0, TOP_Y, -EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece("NoriBack", { NORI_W, TOP_T + 0.06, TOP_T + 0.06 }, NORI, { 0, TOP_Y, EDGE_Z }, "Fabric", {
			shape = "Cylinder",
		}),
		piece(
			"NoriBackStrip",
			{ NORI_W, TOP_Y - 0.1 + 0.97, 0.06 },
			NORI,
			{ 0, (TOP_Y - 0.1 - 0.97) / 2, RICE_D / 2 + 0.02 },
			"Fabric"
		),
	}
end

---------------------------------------------------------------- 얼굴
local EYE_X, EYE_Y = 0.52, -0.12
local EYE_D, EYE_STRETCH = 0.4, 0.07 -- 원판 지름, 위아래로 벌린 거리 (타원 = 0.4 × 0.54)
local MOUTH_Y = -0.42
local CHEEK_X, CHEEK_Y = 0.98, -0.42
local FACE_Z = FRONT - 0.03 -- 얼굴 원판 중심 (두께 0.06, 밥 앞면에 반쯤 묻혀요)

local function openEyes(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		table.insert(list, faceDisc(`Eye{name}`, EYE_D, INK, x, EYE_Y + EYE_STRETCH, FACE_Z))
		table.insert(list, faceDisc(`EyeLow{name}`, EYE_D, INK, x, EYE_Y - EYE_STRETCH, FACE_Z))
		-- 하이라이트: 두 눈 모두 왼쪽 위
		table.insert(list, ball(`Shine{name}`, 0.14, WHITE, { x - 0.07, EYE_Y + 0.15, FACE_Z - 0.03 }, "Neon"))
	end
	return list
end

-- 가느다란 막대 (표정 선: ^ ^, x x, 눈썹). angle = 앞에서 본 기울기(도)
local function stroke(name: string, length: number, x: number, y: number, angle: number, color: { number }?): PartSpec
	return piece(name, { length, 0.09, 0.06 }, color or INK, { x, y, FACE_Z }, nil, { rotation = { 0, 0, angle } })
end

local function happyEyes(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		table.insert(list, stroke(`Eye{name}`, 0.3, x - 0.1, EYE_Y + 0.02, 40))
		table.insert(list, stroke(`EyeLow{name}`, 0.3, x + 0.1, EYE_Y + 0.02, -40))
	end
	return list
end

local function crossEyes(): { PartSpec }
	local list: { PartSpec } = {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local x = side * EYE_X
		table.insert(list, stroke(`Eye{name}`, 0.42, x, EYE_Y, 45))
		table.insert(list, stroke(`EyeLow{name}`, 0.42, x, EYE_Y, -45))
	end
	return list
end

-- 작게 벌린 웃는 입: 진한 원판 위 반을 밥 색 판이 덮고, 아래에 분홍 혀
local function smile(size: number): { PartSpec }
	return {
		-- 입 원판은 밥에 거의 묻고(앞으로 0.03), 얇은 덮개가 윗변보다 0.04 위까지 덮어요 → 위에서 봐도
		-- 원판 윗변이 안 비치고, 덮개 옆면(두께 0.03)도 선으로 안 보여요
		piece("Mouth", { 0.04, size, size }, MOUTH, { 0, MOUTH_Y, FRONT - 0.01 }, nil, {
			shape = "Cylinder",
			rotation = FACING,
		}),
		piece(
			"MouthCover",
			{ size + 0.08, size / 2 + 0.04, 0.03 },
			RICE,
			{ 0, MOUTH_Y + size / 4 + 0.02, FRONT - 0.045 },
			"Salt"
		),
		piece("Tongue", { 0.03, size * 0.5, size * 0.5 }, TONGUE, { 0, MOUTH_Y - size * 0.2, FRONT - 0.035 }, nil, {
			shape = "Cylinder",
			rotation = FACING,
		}),
	}
end

local function cheeks(): { PartSpec }
	return {
		faceDisc("CheekLeft", 0.34, CHEEK, -CHEEK_X, CHEEK_Y, FACE_Z),
		faceDisc("CheekRight", 0.34, CHEEK, CHEEK_X, CHEEK_Y, FACE_Z),
	}
end

local function face(expression: Expression): { PartSpec }
	if expression == "Happy" then
		return join(happyEyes(), smile(0.5), cheeks())
	elseif expression == "Flustered" then
		return join(openEyes(), cheeks(), {
			faceDisc("Mouth", 0.24, MOUTH, 0, MOUTH_Y - 0.02, FACE_Z),
			stroke("BrowLeft", 0.3, -EYE_X, EYE_Y + 0.45, 15),
			stroke("BrowRight", 0.3, EYE_X, EYE_Y + 0.45, -15),
			-- 땀방울: 앞에서 봐서 오른쪽 이마 옆 (캐릭터의 -X) (공 + 위로 뾰족한 마름모)
			ball("Sweat", 0.28, SWEAT, { -1.2, 0.45, FRONT - 0.08 }, "Glass"),
			piece("SweatTip", { 0.18, 0.18, 0.1 }, SWEAT, { -1.2, 0.62, FRONT - 0.08 }, "Glass", {
				rotation = { 0, 0, 45 },
			}),
		})
	elseif expression == "Hurt" then
		return join(crossEyes(), cheeks(), {
			piece("Mouth", { 0.34, 0.08, 0.06 }, MOUTH, { 0, MOUTH_Y, FACE_Z }),
			-- 반창고: 앞에서 봐서 오른쪽 볼 위 비스듬히 (천 + 가운데 패드)
			piece("Bandage", { 0.56, 0.2, 0.05 }, BANDAGE, { -1.0, -0.12, FRONT - 0.04 }, "Fabric", {
				rotation = { 0, 0, -30 },
			}),
			piece("BandagePad", { 0.18, 0.16, 0.05 }, BANDAGE_PAD, { -1.0, -0.12, FRONT - 0.07 }, "Fabric", {
				rotation = { 0, 0, -30 },
			}),
		})
	end
	return join(openEyes(), smile(0.42), cheeks())
end

---------------------------------------------------------------- 팔·다리
local ARM_SIZE = { 0.66, 0.74, 0.74 }
local ARM_X, ARM_Y, ARM_Z = RICE_W / 2 + 0.2, -0.45, -0.4

local function limbs(pose: Pose): { PartSpec }
	local run = pose == "Run"
	local swing = if run then 35 else 0
	local legY = SOLE + LEG_H / 2
	return {
		-- 팔: 몸 옆에 붙은 네모 손. 달리면 앞뒤로 엇갈려 흔들어요 (오른팔 앞 = 왼발 앞)
		piece("ArmLeft", ARM_SIZE, RICE, { -ARM_X, ARM_Y, ARM_Z + (if run then 0.35 else 0) }, "Salt", {
			rotation = { swing, 0, -8 },
			joint = true,
		}),
		piece("ArmRight", ARM_SIZE, RICE, { ARM_X, ARM_Y, ARM_Z - (if run then 0.35 else 0) }, "Salt", {
			rotation = { -swing, 0, 8 },
			joint = true,
		}),
		-- 다리: 짧은 네모 발. 달리면 왼발이 앞으로 들려요
		piece(
			"LegLeft",
			{ LEG_W, LEG_H, LEG_D },
			RICE,
			{ -LEG_X, if run then legY + 0.18 else legY, if run then -0.3 else 0 },
			"Salt",
			{ rotation = if run then { -20, 0, 0 } else nil, joint = true }
		),
		piece(
			"LegRight",
			{ LEG_W, LEG_H, LEG_D },
			RICE,
			{ LEG_X, if run then legY + 0.09 else legY, if run then 0.25 else 0 },
			"Salt",
			{ rotation = if run then { 15, 0, 0 } else nil, joint = true }
		),
	}
end

---------------------------------------------------------------- 공개 함수
SushiConceptSample.GROUND_OFFSET = -SOLE

function SushiConceptSample.layout(expression: Expression?, pose: Pose?): { PartSpec }
	return join(body(), stripes(), nori(), face(expression or "Default"), limbs(pose or "Stand"))
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function angles(rotation: { number }?): CFrame
	if rotation == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

function SushiConceptSample.build(expression: Expression?, pose: Pose?): Model
	local model = Instance.new("Model")
	model.Name = "SushiConceptSample"
	local layout = SushiConceptSample.layout(expression, pose)
	local parts: { [string]: BasePart } = {}
	for _, spec in layout do
		local part = Instance.new("Part")
		if spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Name = spec.name
		part.Size = vec(spec.size)
		part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		part.Material = (Enum.Material :: any)[spec.material] :: Enum.Material
		part.Transparency = spec.transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(vec(spec.offset)) * angles(spec.rotation)
		part.Anchored = spec.name == "Body"
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
		parts[spec.name] = part
	end
	local root = parts.Body
	assert(root, "concept sample needs a Body part")
	for _, spec in layout do
		local part = parts[spec.name]
		if part == root then
			continue
		end
		if spec.joint then
			local motor = Instance.new("Motor6D")
			motor.Part0 = root
			motor.Part1 = part
			motor.C0 = part.CFrame
			motor.Parent = part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.PrimaryPart = root
	return model
end

return SushiConceptSample
