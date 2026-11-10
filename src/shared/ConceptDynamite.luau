--!strict
-- 콘셉트 몸 토핑: 다이너마이트 묶음 (m6-11 전설 "다이너마이트 스시"). 순수 데이터 (Roblox API 없음).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요.
--   topping()  얼굴 없이 다이너마이트로만 채운 묶음 (사용자 결정 2026-11-10 "얼굴도 없이 다이너마이트만"): 빨간 막대가
--              앞 줄 5·뒤 줄 5·옆 2(+ 팔 위 짧은 막대 2)로 밥 둘레를 통처럼 빈틈없이 감싸고(서로 닿아요), 위에서는
--              안쪽 막대 끝 4개가 보여요.
--              막대 끝은 한 단 좁은 밝은 빨강 마개라 살짝 깎인 모양. 막대 뒤에는 짙은 빨강 판(앞·양옆·위)이 밥을 통째로
--              덮어서, 막대 사이 틈으로도 흰 밥·얼굴이 안 보여요. 짙은 숯빛 띠 두 줄(위·아래)이 앞·뒤·양옆을 모두 감아요.
--              위 판 가운데 앞에 작은 짙은 갈색 마개, 거기서 꼰 심지(마디 넷, 두 색이 번갈아)가 옆으로 휘어 올라가고,
--              끝에 노랑·주황 Neon 불꽃(공 + 빛살 셋). 흰 팔·다리는 그대로 보여요.
-- 일반적인 만화 다이너마이트 모양만 써요 (특정 작품의 캐릭터·문양 없음). 파츠 이름은 "Dynamite"로 시작해요 —
-- 얼굴(Eye·Mouth·Cheek·Brow…)·공유 몸(Body·Arm·Foot) 이름과 겹치지 않게. 공유 얼굴 파츠는 그대로 있지만 앞 판·앞 줄 막대
-- 뒤에 숨어요 — 얼굴을 가려도 되는 예외는 SushiBody.CONCEPT_BODY 규칙 표의 faceHidden (테스트가 고정).
-- 한도: 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25 — 앞·뒤 줄과 띠를 합쳐 Z 3.67), 꼭대기 ≤ 이름표 − 0.4, 효과 2개(전설:
-- 불꽃 Sparkles + 심지 끝 Smoke), 파츠 ≤ 80. 팔(x 1.67~2.33, z −0.77~−0.03)과 겹치지 않게 옆 막대는 팔 뒤에 서요.

local PartMath = require(script.Parent.PartMath)

local ConceptDynamite = {}

type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
type Effect = "Fire" | "Sparkles" | "Smoke" | "Glow"
export type PartSpec = {
	name: string,
	size: { number },
	color: { number },
	material: string,
	offset: { number },
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
	pivot: { number }?,
	reach: { number }?,
}

type Extra = {
	shape: Shape?,
	rotation: { number }?,
	effect: Effect?,
	effectColor: { number }?,
}

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
		effect = extra and extra.effect,
		effectColor = extra and extra.effectColor,
	}
end

local UPRIGHT = { 0, 0, 90 } -- 원기둥 축 Y

-- 세운 원기둥 (아래끝 y0 ~ 위끝 y1)
local function upright(
	name: string,
	x: number,
	z: number,
	y0: number,
	y1: number,
	d: number,
	color: { number },
	material: string?
): PartSpec
	return piece(name, { y1 - y0, d, d }, color, { x, (y0 + y1) / 2, z }, material, {
		shape = "Cylinder",
		rotation = UPRIGHT,
	})
end

local function sub(a: { number }, b: { number }): { number }
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function scaled(v: { number }, k: number): { number }
	return { v[1] * k, v[2] * k, v[3] * k }
end

local function plus(a: { number }, b: { number }): { number }
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

-- 두 점 사이 원기둥 (Roblox 원기둥 축 = 로컬 X). 양 끝을 grow만큼 늘려 이웃 마디와 겹쳐요 (꺾인 자리 틈 메움)
local function segment(
	name: string,
	a: { number },
	b: { number },
	d: number,
	color: { number },
	material: string?,
	extra: Extra?,
	grow: number?
): PartSpec
	local delta = sub(b, a)
	local length = math.sqrt(delta[1] * delta[1] + delta[2] * delta[2] + delta[3] * delta[3])
	local u = scaled(delta, 1 / length)
	-- X → u 로 보내는 회전: CFrame.Angles(0, ry, rz)의 X축 = (cos rz·cos ry, sin rz, −cos rz·sin ry)
	local rz = math.deg(math.asin(math.clamp(u[2], -1, 1)))
	local ry = math.deg(math.atan2(-u[3], u[1]))
	return piece(name, { length + 2 * (grow or 0), d, d }, color, scaled(plus(a, b), 0.5), material, {
		shape = "Cylinder",
		rotation = { 0, ry, rz },
		effect = extra and extra.effect,
		effectColor = extra and extra.effectColor,
	})
end

---------------------------------------------------------------- 색
local STICK = { 214, 36, 40 } -- 다이너마이트 빨강
local STICK_END = { 242, 92, 78 } -- 막대 끝 마개 (밝은 빨강 — 깎인 모서리처럼 보여요)
local PLATE = { 150, 22, 28 } -- 막대 뒤 판 (짙은 빨강 — 막대 사이 틈에서 그림자처럼 보여요)
local STRAP = { 56, 56, 62 } -- 숯빛 띠
local FUSE_CAP = { 92, 56, 34 } -- 심지 받침 (짙은 갈색)
local FUSE_A = { 222, 182, 118 } -- 꼰 심지 밝은 마디
local FUSE_B = { 168, 120, 66 } -- 꼰 심지 어두운 마디
local SPARK = { 255, 222, 70 } -- 불꽃 가운데 (노랑)
local SPARK_RAY = { 255, 150, 36 } -- 불꽃 빛살 (주황)
local SPARKLE = { 255, 214, 120 } -- Sparkles 색
local SMOKE = { 210, 210, 214 } -- 옅은 회색 연기

---------------------------------------------------------------- 치수 (밥: x ±1.8, y −1~1, z ±1.35, 앞 = −Z)
local STICK_D = 0.86 -- 막대 지름 (통통한 만화 다이너마이트, 이웃 막대와 닿아요)
local STICK_BOTTOM = -1.32 -- 막대 아래끝 (밥 아래 받침까지 가려요, 판 아래끝과 다른 평면)
local END_INSET, END_H = 0.14, 0.1 -- 끝 마개: 지름이 막대보다 이만큼 좁고, 높이 (한 단 깎인 모양)
local ROW_X = { -1.62, -0.81, 0, 0.81, 1.62 } -- 앞·뒤 줄 x (간격 0.81 < 지름 — 이웃 막대가 살짝 겹쳐 틈이 없어요)
-- 앞 줄·뒤 줄 z. 뒤 줄은 밥 뒷면(1.35)에서 이웃 막대가 거의 닿아(틈 0.004) 흰 밥이 안 보이고, 앞 줄 틈으로는 앞 판이 보여요
local FRONT_Z, BACK_Z = -1.42, 1.31
local SIDE_X, SIDE_Z = 1.62, 0.42 -- 옆 막대 (모서리 막대와 같은 x, 팔 뒤 — 팔 z −0.77~−0.03)
-- 팔 위 짧은 막대: 앞 모서리 막대와 옆 막대 사이(팔 자리) 위쪽을 채워요. 아래끝이 팔 위(기울어진 팔 위끝 −0.04)라 팔은 다 보여요
local SHOULDER_X, SHOULDER_Z, SHOULDER_BOTTOM, SHOULDER_TOP = 1.5, -0.54, 0, 1.24
local STRAP_T = 0.08 -- 띠 두께 (막대 바깥면에 반쯤 묻혀요)
local OUTER_X = SIDE_X + STICK_D / 2 -- 옆 바깥 (2.05 — 팔 끝 2.33이 앞에서도 보여요)

-- 막대 판: 밥(받침 포함)을 앞·옆·위에서 감싸는 짙은 빨강 껍질 (뒤는 뒤 줄 막대가 바로 덮어요)
local PLATE_X0, PLATE_X1 = 1.8, 1.84 -- 옆 판 x
local PLATE_Z0, PLATE_Z1 = -1.64, 1.4 -- 앞 판 앞면·옆·위 판 뒤끝 z (앞 판은 땀방울(z −1.57)보다 앞)
local PLATE_Y0, PLATE_Y1 = -1.295, 1.0 -- 판 아래·위 (받침 아래끝 −1.29까지, 막대 아래끝 −1.32와 다른 평면)
local PLATE_TOP = 1.06 -- 위 판 윗면

-- 막대 자리 {이름, x, z, 위끝 y}. 앞 줄은 조금 낮게, 뒤 줄은 높게 (들쭉날쭉한 묶음)
type Stick = { name: string, x: number, z: number, top: number }
local FRONT_TOPS = { 1.4, 1.5, 1.36, 1.48, 1.42 }
local BACK_TOPS = { 1.58, 1.7, 1.6, 1.66, 1.54 }
local STICKS: { Stick } = {}
for i, x in ROW_X do
	table.insert(STICKS, { name = `Front{i}`, x = x, z = FRONT_Z, top = FRONT_TOPS[i] })
end
for i, x in ROW_X do
	table.insert(STICKS, { name = `Back{i}`, x = x, z = BACK_Z, top = BACK_TOPS[i] })
end
table.insert(STICKS, { name = "SideLeft", x = -SIDE_X, z = SIDE_Z, top = 1.52 })
table.insert(STICKS, { name = "SideRight", x = SIDE_X, z = SIDE_Z, top = 1.46 })

-- 위에서 보이는 안쪽 막대 끝 {x, z, 위끝 y} (위 판에 묻힌 짧은 원기둥). 가운데 앞(0, −0.62)에는 심지 받침이 서요
type Inner = { x: number, z: number, top: number }
local INNER: { Inner } = {
	{ x = -1.29, z = -0.62, top = 1.22 },
	{ x = 1.29, z = -0.62, top = 1.26 },
	{ x = -0.64, z = 0.36, top = 1.28 },
	{ x = 0.64, z = 0.36, top = 1.2 },
}
local FUSE_BASE = { x = 0, z = -0.62, top = PLATE_TOP } -- 심지 받침이 서는 자리 (위 판 위)

-- 띠 두 줄 {이름, 아래 y, 위 y}
type Strap = { name: string, y0: number, y1: number }
local STRAPS: { Strap } = {
	{ name = "Upper", y0 = 0.62, y1 = 0.96 },
	{ name = "Lower", y0 = -1.12, y1 = -0.84 },
}

local function sticks(): { PartSpec }
	local list: { PartSpec } = {}
	for _, s in STICKS do
		table.insert(list, upright(`DynamiteStick{s.name}`, s.x, s.z, STICK_BOTTOM, s.top, STICK_D, STICK))
		-- 끝 마개: 위끝에 0.02 묻혀 한 단 좁게 (같은 평면 겹침 없음)
		table.insert(
			list,
			upright(
				`DynamiteStickEnd{s.name}`,
				s.x,
				s.z,
				s.top - 0.02,
				s.top + END_H - 0.02,
				STICK_D - END_INSET,
				STICK_END
			)
		)
	end
	for _, side in { -1, 1 } do
		table.insert(
			list,
			upright(
				`DynamiteStickShoulder{if side < 0 then "Left" else "Right"}`,
				side * SHOULDER_X,
				SHOULDER_Z,
				SHOULDER_BOTTOM,
				SHOULDER_TOP,
				STICK_D,
				STICK
			)
		)
	end
	for i, inner in INNER do
		table.insert(
			list,
			upright(`DynamiteInnerEnd{i}`, inner.x, inner.z, PLATE_TOP - 0.1, inner.top, STICK_D - END_INSET, STICK_END)
		)
	end
	return list
end

local function plates(): { PartSpec }
	local width = 2 * PLATE_X1
	local height = PLATE_Y1 - PLATE_Y0
	local y = (PLATE_Y0 + PLATE_Y1) / 2
	local depth = PLATE_Z1 - PLATE_Z0
	local t = PLATE_X1 - PLATE_X0
	local list: { PartSpec } = {
		piece("DynamitePlateFront", { width, height, t }, PLATE, { 0, y, PLATE_Z0 + t / 2 }),
		piece(
			"DynamitePlateTop",
			{ width, PLATE_TOP - PLATE_Y1, depth },
			PLATE,
			{ 0, (PLATE_Y1 + PLATE_TOP) / 2, (PLATE_Z0 + PLATE_Z1) / 2 }
		),
	}
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		table.insert(
			list,
			piece(
				`DynamitePlate{tag}`,
				{ t, height, depth },
				PLATE,
				{ side * (PLATE_X0 + PLATE_X1) / 2, y, (PLATE_Z0 + PLATE_Z1) / 2 }
			)
		)
	end
	return list
end

local function straps(): { PartSpec }
	local list: { PartSpec } = {}
	local r = STICK_D / 2
	local frontZ = FRONT_Z - r -- 앞 줄 바깥면에 반쯤 묻혀요
	local backZ = BACK_Z + r
	local sideX = OUTER_X
	local span = 2 * (sideX + STRAP_T / 2) -- 모서리는 네모로 만나요 (서로 겹쳐요)
	local sideFront, sideBack = frontZ - STRAP_T / 2, backZ + STRAP_T / 2
	for _, band in STRAPS do
		local h = band.y1 - band.y0
		local y = (band.y0 + band.y1) / 2
		table.insert(
			list,
			piece(`DynamiteStrap{band.name}Front`, { span, h, STRAP_T }, STRAP, { 0, y, frontZ }, "Fabric")
		)
		table.insert(
			list,
			piece(`DynamiteStrap{band.name}Back`, { span, h, STRAP_T }, STRAP, { 0, y, backZ }, "Fabric")
		)
		for _, side in { -1, 1 } do
			local tag = if side < 0 then "Left" else "Right"
			table.insert(
				list,
				piece(
					`DynamiteStrap{band.name}{tag}`,
					{ STRAP_T, h, sideBack - sideFront },
					STRAP,
					{ side * sideX, y, (sideFront + sideBack) / 2 },
					"Fabric"
				)
			)
		end
	end
	return list
end

-- 심지: 가운데 앞 안쪽 막대 위 갈색 받침에서 꼰 심지가 오른쪽(+X)으로 휘어 올라가고, 끝에 불꽃
local CAP_TOP = FUSE_BASE.top + 0.3
local FUSE_D = 0.18
local FUSE_PATH = {
	{ FUSE_BASE.x, CAP_TOP - 0.04, FUSE_BASE.z },
	{ FUSE_BASE.x + 0.02, CAP_TOP + 0.32, FUSE_BASE.z - 0.02 },
	{ FUSE_BASE.x + 0.2, CAP_TOP + 0.66, FUSE_BASE.z - 0.06 },
	{ FUSE_BASE.x + 0.5, CAP_TOP + 0.86, FUSE_BASE.z - 0.1 },
	{ FUSE_BASE.x + 0.86, CAP_TOP + 0.88, FUSE_BASE.z - 0.15 },
}
local SPARK_D = 0.46
local RAY_LEN = 0.96

local function fuse(): { PartSpec }
	local list: { PartSpec } = {
		upright("DynamiteFuseCap", FUSE_BASE.x, FUSE_BASE.z, FUSE_BASE.top - 0.04, CAP_TOP, 0.62, FUSE_CAP, "Wood"),
	}
	for i = 1, #FUSE_PATH - 1 do
		local last = i == #FUSE_PATH - 1
		table.insert(
			list,
			segment(
				`DynamiteFuse{i}`,
				FUSE_PATH[i],
				FUSE_PATH[i + 1],
				FUSE_D,
				if i % 2 == 1 then FUSE_A else FUSE_B,
				"Fabric",
				if last then { effect = "Smoke", effectColor = SMOKE } else nil,
				0.04
			)
		)
	end
	-- 불꽃: 노란 공 + 주황 빛살 셋(앞을 보는 별, 60°마다)
	local tip = plus(FUSE_PATH[#FUSE_PATH], { 0.14, 0.02, -0.01 })
	table.insert(
		list,
		piece("DynamiteSpark", { SPARK_D, SPARK_D, SPARK_D }, SPARK, tip, "Neon", {
			shape = "Ball",
			effect = "Sparkles",
			effectColor = SPARKLE,
		})
	)
	for k = 1, 3 do
		local spec = piece(`DynamiteSparkRay{k}`, { RAY_LEN, 0.07, 0.07 }, SPARK_RAY, tip, "Neon")
		local frame = PartMath.frame(tip, { 0, 0, 30 + 60 * (k - 1) })
		spec.offset = frame.p
		spec.rotation = PartMath.toDegrees(frame.r)
		table.insert(list, spec)
	end
	return list
end

function ConceptDynamite.topping(): { PartSpec }
	local list: { PartSpec } = {}
	for _, group in { sticks(), plates(), straps(), fuse() } do
		for _, spec in group do
			table.insert(list, spec)
		end
	end
	return list
end

return ConceptDynamite
