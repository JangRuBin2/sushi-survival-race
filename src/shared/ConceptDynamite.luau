--!strict
-- 콘셉트 몸 토핑: 다이너마이트 묶음 (m6-11 전설 "다이너마이트 스시"). 순수 데이터 (Roblox API 없음).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요.
--   topping()  빨간 다이너마이트 막대 9개가 밥 둘레를 통처럼 둘러싸요 (뒤 5·옆 2는 통통하게 서로 닿고, 앞 모서리 2는
--              가늘게 — 팔이 앞에서도 보여요. 위끝은 밥 위로 삐죽, 끝은 한 단 좁은 밝은 빨강 마개라 살짝 깎인 모양).
--              짙은 숯빛 띠 두 줄(위·아래)이 묶음을 가로로 묶어요 — 앞에서는 얼굴 위(이마 위끝)와 얼굴 아래(밥 아래끝)로만
--              지나가고, 앞 모서리 막대는 띠 고리가 감아요. 밥 위 가운데에 작은 짙은 갈색 마개, 거기서 꼰 심지(마디 넷,
--              두 색이 번갈아)가 옆으로 휘어 올라가고, 끝에 노랑·주황 Neon 불꽃(공 + 빛살 셋).
-- 일반적인 만화 다이너마이트 모양만 써요 (특정 작품의 캐릭터·문양 없음). 파츠 이름은 "Dynamite"로 시작해요 —
-- 얼굴(Eye·Mouth·Cheek·Brow…)·공유 몸(Body·Arm·Foot) 이름과 겹치지 않게. 얼굴은 보통 귀여운 얼굴 그대로.
-- 한도 (테스트가 고정): 얼굴 높이에서 밥 앞면(z −1.35)보다 앞으로 안 나와요 — 앞 모서리 막대는 x 1.4 바깥이고 밥 앞면
-- 뒤, 앞 띠·띠 고리는 y 0.76 위·y −0.8 아래. 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25), 꼭대기 ≤ 이름표 − 0.4,
-- 효과 2개(전설: 불꽃 Sparkles + 심지 끝 Smoke). 팔(x 1.67~2.33, z −0.77~−0.03)과 겹치지 않게 옆 막대는 팔 뒤에 서요.

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
local STRAP = { 56, 56, 62 } -- 숯빛 띠
local FUSE_CAP = { 92, 56, 34 } -- 심지 받침 (짙은 갈색)
local FUSE_A = { 222, 182, 118 } -- 꼰 심지 밝은 마디
local FUSE_B = { 168, 120, 66 } -- 꼰 심지 어두운 마디
local SPARK = { 255, 222, 70 } -- 불꽃 가운데 (노랑)
local SPARK_RAY = { 255, 150, 36 } -- 불꽃 빛살 (주황)
local SPARKLE = { 255, 214, 120 } -- Sparkles 색
local SMOKE = { 210, 210, 214 } -- 옅은 회색 연기

---------------------------------------------------------------- 치수 (밥: x ±1.8, y −1~1, z ±1.35, 앞 = −Z)
local STICK_D = 0.8 -- 뒤·옆 막대 지름 (통통한 만화 다이너마이트, 뒤 다섯 개가 서로 닿아요)
local FRONT_D = 0.56 -- 앞 모서리 막대 지름 (가늘게 — 팔이 앞에서도 반쯤 보여요)
local STICK_BOTTOM = -1.1 -- 막대 아래끝 (밥 아래 받침 옆)
local END_INSET, END_H = 0.14, 0.1 -- 끝 마개: 지름이 막대보다 이만큼 좁고, 높이 (한 단 깎인 모양)
local BACK_X, BACK_Z = 1.6, 1.35 -- 뒤 줄 바깥 막대 x, 뒤 줄 z (밥 뒷면에 반쯤 묻혀요)
local SIDE_X, SIDE_Z = 1.58, 0.45 -- 옆 막대 (팔 뒤 — 팔 z −0.77~−0.03, 바깥 x 1.98)
-- 앞 모서리 막대: 얼굴 영역 x 1.4 바깥(1.7 − 0.28 = 1.42)이고, 얼굴 높이에서 밥 앞면(z −1.35)보다 앞으로 안 나와요
-- (−1.07 − 0.28 = −1.35 — m5-28 얼굴 검사). 둥근 밥 모서리에 반쯤 묻혀요
local FRONT_X, FRONT_Z = 1.7, -1.06
local STRAP_T = 0.08 -- 띠 두께
local OUTER_X = SIDE_X + STICK_D / 2 -- 옆 막대 바깥 (1.98) — 앞 모서리 막대 바깥과 같아요

-- 막대 자리. 뒤 다섯(모서리 포함)·옆 둘·앞 모서리 둘. 위끝 높이를 조금씩 달리해 묶음처럼, 앞 모서리는 낮게
type Stick = { name: string, x: number, z: number, d: number, top: number, collar: boolean }
local STICKS: { Stick } = {
	{ name = "BackLeft", x = -BACK_X, z = BACK_Z, d = STICK_D, top = 1.5, collar = false },
	{ name = "BackInLeft", x = -0.8, z = BACK_Z, d = STICK_D, top = 1.62, collar = false },
	{ name = "BackMid", x = 0, z = BACK_Z, d = STICK_D, top = 1.54, collar = false },
	{ name = "BackInRight", x = 0.8, z = BACK_Z, d = STICK_D, top = 1.66, collar = false },
	{ name = "BackRight", x = BACK_X, z = BACK_Z, d = STICK_D, top = 1.46, collar = false },
	{ name = "SideLeft", x = -SIDE_X, z = SIDE_Z, d = STICK_D, top = 1.56, collar = false },
	{ name = "SideRight", x = SIDE_X, z = SIDE_Z, d = STICK_D, top = 1.42, collar = false },
	{ name = "FrontLeft", x = -FRONT_X, z = FRONT_Z, d = FRONT_D, top = 1.4, collar = true },
	{ name = "FrontRight", x = FRONT_X, z = FRONT_Z, d = FRONT_D, top = 1.46, collar = true },
}

-- 띠 두 줄 {이름, 아래 y, 위 y}: 위 띠는 얼굴 영역 위(아래끝 ≥ 0.76), 아래 띠는 얼굴 영역 아래(위끝 ≤ −0.8)
type Strap = { name: string, y0: number, y1: number }
local STRAPS: { Strap } = {
	{ name = "Upper", y0 = 0.78, y1 = 1.12 },
	{ name = "Lower", y0 = -1.08, y1 = -0.82 },
}

local function sticks(): { PartSpec }
	local list: { PartSpec } = {}
	for _, s in STICKS do
		table.insert(list, upright(`DynamiteStick{s.name}`, s.x, s.z, STICK_BOTTOM, s.top, s.d, STICK))
		-- 끝 마개: 위끝에 0.02 묻혀 한 단 좁게 (같은 평면 겹침 없음)
		table.insert(
			list,
			upright(
				`DynamiteStickEnd{s.name}`,
				s.x,
				s.z,
				s.top - 0.02,
				s.top + END_H - 0.02,
				s.d - END_INSET,
				STICK_END
			)
		)
	end
	return list
end

local function straps(): { PartSpec }
	local list: { PartSpec } = {}
	local backZ = BACK_Z + STICK_D / 2 + STRAP_T / 2 - 0.01 -- 뒤 막대 바깥에 닿아요
	local sideX = OUTER_X + STRAP_T / 2 - 0.01 -- 옆 막대·앞 모서리 막대 바깥
	local frontZ = -1.35 - STRAP_T / 2 -- 앞은 밥 앞면 위로 (얼굴 위·아래로만)
	for _, band in STRAPS do
		local h = band.y1 - band.y0
		local y = (band.y0 + band.y1) / 2
		-- 뒤 모서리는 네모로 만나요 (뒤 띠·옆 띠가 모서리에서 서로 겹쳐요)
		table.insert(
			list,
			piece(
				`DynamiteStrap{band.name}Back`,
				{ 2 * (sideX + STRAP_T / 2), h, STRAP_T },
				STRAP,
				{ 0, y, backZ },
				"Fabric"
			)
		)
		table.insert(
			list,
			piece(`DynamiteStrap{band.name}Front`, { 2 * FRONT_X, h, STRAP_T }, STRAP, { 0, y, frontZ }, "Fabric")
		)
		local sideFront, sideBack = FRONT_Z, backZ + STRAP_T / 2
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
		-- 앞 모서리 막대를 감는 고리 (앞 띠·옆 띠 끝이 여기로 들어가요)
		for _, s in STICKS do
			if s.collar then
				table.insert(
					list,
					upright(
						`DynamiteStrap{band.name}Collar{s.name}`,
						s.x,
						s.z,
						band.y0,
						band.y1,
						s.d + 2 * STRAP_T,
						STRAP,
						"Fabric"
					)
				)
			end
		end
	end
	return list
end

-- 심지: 밥 위 가운데 갈색 받침에서 꼰 심지가 오른쪽(+X)으로 휘어 올라가고, 끝에 불꽃
local FUSE_D = 0.18
local FUSE_PATH = {
	{ 0, 1.2, 0.1 },
	{ 0.02, 1.56, 0.08 },
	{ 0.2, 1.9, 0.03 },
	{ 0.5, 2.1, -0.02 },
	{ 0.86, 2.12, -0.08 },
}
local SPARK_D = 0.46
local RAY_LEN = 0.96

local function fuse(): { PartSpec }
	local list: { PartSpec } = {
		upright("DynamiteFuseCap", 0, 0.1, 0.92, 1.24, 0.66, FUSE_CAP, "Wood"),
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
	for _, group in { sticks(), straps(), fuse() } do
		for _, spec in group do
			table.insert(list, spec)
		end
	end
	return list
end

return ConceptDynamite
