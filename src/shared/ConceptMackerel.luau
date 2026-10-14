--!strict
-- 콘셉트 몸 토핑: 통고등어 한 마리 (m5-32 "고등어 초밥 [신선]", 사용자 시트 docs/고등어 초밥 캐릭터 시트.png).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요. 순수 데이터 (Roblox API 없음).
--   topping()  고등어 파츠 목록 (견본 PartSpec과 같은 모양)
--   PIVOTS     관절 경첩 (Body 좌표) — 렌더·테스트 설명용. 실제 값은 파츠의 pivot 칸에 있어요
-- 모양 (앞 = -Z, 위 = +Y): 고등어가 밥 위에 X축으로 가로 누워요. 머리 = +X(앞에서 보면 보는 사람 왼쪽), 꼬리 = -X.
--   몸통 단면 = 위(등, 청회색) 원기둥 + 그보다 조금 굵고 낮은 아래(배, 은백색) 원기둥. 두 원이 몸 높이의 위쪽 40%
--   쯤에서 비스듬히 만나 경계(옆줄)가 또렷하고, 배가 아래로 통통해요(시트처럼 은빛 배가 아래 절반 이상).
--   머리는 같은 짝의 공(둥근 주둥이), 몸은 앞 → 뒤로 가늘어지는 마디 셋(끝은 공으로 둥글게) + 꼬리자루.
--   등에는 짙은 남색 물결 줄무늬(등 원기둥을 감는 얇은 원판을 비스듬히 — 등 원기둥 쪽에만 보여서 옆줄 위까지),
--   윗옆구리에 젖은 윤기 띠·머리 반짝, 크게 튀어나온 눈(크림 공 + 검은 눈동자 공 + 흰 반짝), 벌린 입(어두운 분홍 + 혀),
--   아가미 선, 반투명 가슴지느러미, 등지느러미 둘, V자로 갈라진 꼬리지느러미(쐐기 둘, 물빛 반짝이).
--   김 띠가 꼬리 쪽 1/3(뒷마디)을 비스듬히 감고 앞·뒤로 밥 윗면 가장자리까지 늘어져요(밥엔 닿지 않아 움직여도 안 박혀요).
--   물방울 4개는 평소 앞몸 속에 숨어 있다가 팔딱할 때 관절 이동(reach)으로 튀어나와요.
-- 관절 (이름이 계약 — 클라이언트는 이름으로만 찾아요, docs/specs/m5-32-fresh-mackerel.md):
--   FishRoot(Body) → FishMid(FishRoot) → FishTail(FishMid), FishFinL/FishFinR(FishRoot), Splash1~4(Body)
--   붙는 파츠는 attach로 자기 관절 파츠를 따라가요. pivot = 경첩(Body 좌표), reach = 물방울이 튀는 거리(splash 1).

local PartMath = require(script.Parent.PartMath)

local ConceptMackerel = {}

type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
export type PartSpec = {
	name: string,
	size: { number },
	color: { number },
	material: string,
	offset: { number },
	shape: Shape?,
	rotation: { number }?,
	effect: ("Fire" | "Sparkles" | "Smoke" | "Glow")?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
	pivot: { number }?,
	reach: { number }?,
}

---------------------------------------------------------------- 색 (시트: 청회색 등 + 짙은 남색 물결 + 은백색 배)
local DORSAL = { 92, 106, 134 } -- 등 청회색
local STRIPE = { 54, 66, 98 } -- 짙은 남색 물결 줄무늬
local BELLY = { 214, 219, 228 } -- 배 은백색 (너무 하얗게 날아가지 않게 살짝 은회색)
local GILL = { 66, 82, 116 } -- 아가미 선 (등 쪽)
local FIN = { 96, 116, 154 } -- 등지느러미
local PECTORAL = { 116, 134, 166 } -- 가슴지느러미 (회청색 반투명 — 은빛 배 위에서 보여요)
local TAIL_FIN = { 72, 88, 120 } -- 꼬리지느러미
local EYE_CREAM = { 244, 234, 200 } -- 눈 크림색 테두리
local EYE_BLACK = { 18, 18, 24 }
local WHITE = { 255, 255, 255 }
local MOUTH = { 92, 28, 44 } -- 벌린 입 (어두운 분홍)
local TONGUE = { 236, 128, 146 } -- 입 안 분홍
local GLOSS = { 214, 232, 255 } -- 젖은 윤기 (Neon 반투명 — 조명과 상관없이 반짝 띠로 보여요)
local NORI = { 38, 46, 40 }
local SPLASH = { 130, 205, 255 } -- 물방울 (팔딱 순간 잘 보이게 조금 진하게)

---------------------------------------------------------------- 치수 (Body 기준: 밥 y -1~1, 앞면 z -1.35, 폭 x ±1.8)
-- 사용자 결정 2026-10-14 4차: 이 스킨만 이름표를 4.8로 올리고 고등어를 시트처럼 크게 (밥보다 높고, 밥 폭보다 길게).
-- 한도: 쉰 꼭대기 ≤ 4.4, 관절 한도 끝까지 팔딱해도 ≤ 4.8, 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25), 밥 윗면 − 0.2 위
local Y = 2.25 -- 몸통 중심선 (배 아래끝 0.88 — 밥 윗면 1.0에 묻혀 얹혀요, 등 꼭대기 3.55)

-- 마디 단면: 등 원기둥 (반지름 rd, 축 Y + up) + 배 원기둥 (반지름 rb, 축 Y - down). 위끝 = Y + up + rd, 아래끝 = Y - down - rb
type Section = { rd: number, up: number, rb: number, down: number }
local HEAD: Section = { rd = 1.06, up = 0.28, rb = 1.08, down = 0.3 } -- 머리 공 (높이 2.72 — 몸보다 조금 크고 둥글게)
local ROOT: Section = { rd = 1.0, up = 0.3, rb = 1.05, down = 0.32 } -- 앞몸 (높이 2.67, 폭 2.1)
local MID: Section = { rd = 0.8, up = 0.24, rb = 0.84, down = 0.26 } -- 뒷몸 앞마디 (꼬리 쪽으로 가늘어져요)
local REAR: Section = { rd = 0.56, up = 0.18, rb = 0.6, down = 0.18 } -- 뒷몸 뒷마디
local STALK: Section = { rd = 0.27, up = 0.07, rb = 0.29, down = 0.05 } -- 꼬리자루

local HEAD_X = 1.78 -- 머리 공 중심 (주둥이 끝 2.86)
local ROOT_X0, ROOT_X1 = 0.15, HEAD_X
local MID_X0, MID_X1 = -0.75, 0.5 -- 앞몸 속으로 겹쳐요 (휘어도 이음매가 벌어지지 않게)
local REAR_X0, REAR_X1 = -1.55, -0.6
local STALK_Y = 2.34 -- 꼬리는 몸통 중심선보다 위로 (시트처럼 꼬리가 들려요)
local STALK_X0, STALK_X1 = -2.3, -1.4

-- 관절 경첩 (Body 좌표)
local ROOT_PIVOT = { 0.2, Y, 0 } -- 앞몸 뒤끝: 들썩·아치·비틀림이 머리를 들어 올려요
local MID_PIVOT = { 0.2, Y, 0 }
local TAIL_PIVOT = { -1.5, STALK_Y, 0 }

ConceptMackerel.PIVOTS = {
	FishRoot = ROOT_PIVOT,
	FishMid = MID_PIVOT,
	FishTail = TAIL_PIVOT,
}

---------------------------------------------------------------- 도우미
type Extra = {
	shape: Shape?,
	rotation: { number }?,
	joint: boolean?,
	transparency: number?,
	attach: string?,
	pivot: { number }?,
	reach: { number }?,
	effect: ("Sparkles" | "Glow")?,
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
		transparency = extra and extra.transparency,
		joint = extra and extra.joint,
		attach = extra and extra.attach,
		pivot = extra and extra.pivot,
		reach = extra and extra.reach,
	}
end

local function ball(
	name: string,
	d: number,
	color: { number },
	at: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	e.shape = "Ball"
	return piece(name, { d, d, d }, color, at, material, e)
end

-- X축 원기둥 (x0~x1, 중심 높이 y, 반지름 r)
local function rod(
	name: string,
	x0: number,
	x1: number,
	y: number,
	r: number,
	color: { number },
	material: string?,
	extra: Extra?
): PartSpec
	local e: Extra = extra or {}
	e.shape = "Cylinder"
	return piece(name, { x1 - x0, 2 * r, 2 * r }, color, { (x0 + x1) / 2, y, 0 }, material, e)
end

-- 몸통 마디 하나 = 등 원기둥(prefix) + 배 원기둥(prefix.."Belly"). 배는 끝 마개가 같은 평면에서 겹치지 않게(z-fighting)
-- 양 끝을 조금 안으로 줄여요. top = 등 원기둥의 관절 칸(관절 파츠면 joint·pivot), 배는 등 원기둥(또는 attach)에 붙어요
local function segment(
	prefix: string,
	x0: number,
	x1: number,
	y: number,
	s: Section,
	attach: string?,
	top: Extra?
): { PartSpec }
	return {
		rod(prefix, x0, x1, y + s.up, s.rd, DORSAL, "SmoothPlastic", top or { attach = attach }),
		rod(`{prefix}Belly`, x0 + 0.012, x1 - 0.012, y - s.down, s.rb, BELLY, "Foil", { attach = attach or prefix }),
	}
end

-- 마디 끝을 둥글게 (같은 단면의 공 두 개)
local function cap(prefix: string, x: number, y: number, s: Section, attach: string): { PartSpec }
	return {
		ball(prefix, 2 * s.rd, DORSAL, { x, y + s.up, 0 }, nil, { attach = attach }),
		ball(`{prefix}Belly`, 2 * s.rb, BELLY, { x, y - s.down, 0 }, "Foil", { attach = attach }),
	}
end

-- 등 물결 줄무늬: 등 원기둥을 감는 얇은 원판을 Z축으로 기울여(위끝이 머리 쪽) 옆구리에서 비스듬히 보여요.
-- 기울이면 위끝이 원기둥 속으로 들어가서 반지름을 1/cos만큼 키워요 (위는 표면에 붙고 옆구리는 살짝 도드라져요).
-- 배 원기둥이 더 바깥인 아래쪽에서는 숨어서 옆줄 위까지만 보여요
local function stripe(
	name: string,
	x: number,
	y: number,
	s: Section,
	width: number,
	tilt: number,
	attach: string
): PartSpec
	local radius = (s.rd + 0.015) / math.cos(math.rad(tilt))
	return piece(name, { width, 2 * radius, 2 * radius }, STRIPE, { x, y + s.up, 0 }, nil, {
		shape = "Cylinder",
		rotation = { 0, 0, -tilt },
		attach = attach,
	})
end

-- 지느러미 쐐기. up = true면 윗변이 수평이고 끝이 뒤·위(꼬리 위 갈래·가슴지느러미), false면 아랫변이 수평이고
-- 끝이 뒤·아래. 앞쪽 수직변이 몸에 붙는 쪽(+X). 두께는 Z. 그다음 at을 중심으로 turn(도)만큼 더 돌려요
local function fin(
	name: string,
	size: { number },
	color: { number },
	at: { number },
	up: boolean,
	turn: { number }?,
	extra: Extra?
): PartSpec
	local base = if up then { 180, 90, 0 } else { 0, 90, 0 }
	local offset, rotation = at, base
	if turn then
		offset, rotation = PartMath.rotateAbout(at, base, at, turn)
	end
	local e: Extra = extra or {}
	e.shape = "Wedge"
	e.rotation = rotation
	return piece(name, size, color, offset, "SmoothPlastic", e)
end

-- pivot을 중심으로 돌린 판 (김 띠를 비스듬히)
local function tilted(spec: PartSpec, pivot: { number }, turn: { number }): PartSpec
	local offset, rotation = PartMath.rotateAbout(spec.offset, spec.rotation, pivot, turn)
	spec.offset = offset
	spec.rotation = rotation
	return spec
end

---------------------------------------------------------------- 김 띠 (뒷몸 앞마디를 비스듬히 감고 밥까지)
local NORI_X = -0.3 -- 가운데 (머리에서 약 60% — 굵기가 같은 뒷몸 앞마디 위라 띠가 몸에 딱 붙어요)
local NORI_W = 0.95
local NORI_TILT_DEG = 4 -- 위끝이 머리 쪽 (앞에서 보면 시트처럼 비스듬히)
local NORI_PIVOT = { NORI_X, Y, 0 }
-- 띠 자락 아래끝 (z, y): 밥 윗면 가장자리 바로 위. 밥 김(NoriWrap)이 거기서 이어받아요
local DRAPE_BOTTOM = { 0.98, 1.05 }
local NORI_WRAP_W = 0.86
local NORI_WRAP_FRONT = 0.86 -- 밥 김 앞면 아래끝 (얼굴 위끝 0.75보다 위)
local NORI_WRAP_BACK = 0.3 -- 밥 김 뒷면 아래끝 (뒷면엔 얼굴이 없어요)
-- 띠가 기운 만큼 밥 김도 꼬리 쪽으로 (자락 아래끝의 x)
local NORI_WRAP_X = NORI_X + (DRAPE_BOTTOM[2] - Y) * math.tan(math.rad(NORI_TILT_DEG))

local function noriBand(): { PartSpec }
	local tilt = { 0, 0, -NORI_TILT_DEG }
	local cos = math.cos(math.rad(NORI_TILT_DEG))
	-- 몸에 딱 붙는 띠 (기울면 원판이 몸 속으로 들어가서 반지름을 1/cos만큼)
	local up = (MID.rd + 0.03) / cos
	local low = (MID.rb + 0.03) / cos
	local list = {
		piece("FishNori", { NORI_W, 2 * up, 2 * up }, NORI, { NORI_X, Y + MID.up, 0 }, "Fabric", {
			shape = "Cylinder",
			attach = "FishMid",
		}),
		piece("FishNoriLow", { NORI_W, 2 * low, 2 * low }, NORI, { NORI_X, Y - MID.down, 0 }, "Fabric", {
			shape = "Cylinder",
			attach = "FishMid",
		}),
	}
	-- 앞·뒤 자락: 띠의 가장 넓은 옆구리에서 밥 윗면 가장자리까지 비스듬히 (고등어와 밥을 같이 감은 모양).
	-- 밥 윗면보다 위에서 끝나서 고등어가 흔들려도 밥에 박히지 않아요
	for _, side in { -1, 1 } do
		local top = { MID.rb - 0.02, Y - MID.down } -- (z, y) 띠 속
		local bottom = DRAPE_BOTTOM
		local dz, dy = bottom[1] - top[1], bottom[2] - top[2]
		local length = math.sqrt(dz * dz + dy * dy)
		local angle = math.deg(math.atan2(dz, -dy)) -- 세로에서 바깥으로 기운 각
		table.insert(
			list,
			piece(
				if side < 0 then "FishNoriFront" else "FishNoriBack",
				{ NORI_W, length + 0.04, 0.05 },
				NORI,
				{ NORI_X, (top[2] + bottom[2]) / 2, side * (top[1] + bottom[1]) / 2 },
				"Fabric",
				-- 위끝이 몸 쪽(안), 아래끝이 바깥: +Z 쪽은 X축으로 -각, -Z 쪽은 +각
				{ rotation = { -side * angle, 0, 0 }, attach = "FishMid" }
			)
		)
	end
	for i, spec in list do
		list[i] = tilted(spec, NORI_PIVOT, tilt)
	end
	-- 밥을 감는 김 (Body에 붙어 움직이지 않아요): 띠 자락이 이 김 윗면 가장자리에 내려앉아 밥 옆으로 이어져요.
	-- 앞면은 얼굴(땀·💢·눈썹 위끝 0.75)을 가리지 않게 가장자리만 짧게, 얼굴이 없는 뒷면(게임 뒤 카메라)은 길게
	table.insert(
		list,
		piece("NoriWrap", { NORI_WRAP_W, 1.03 - NORI_WRAP_FRONT, 2 * 1.35 + 0.08 }, NORI, {
			NORI_WRAP_X,
			(1.03 + NORI_WRAP_FRONT) / 2,
			0,
		}, "Fabric")
	)
	table.insert(
		list,
		piece("NoriWrapBack", { NORI_WRAP_W, 0.9 - NORI_WRAP_BACK, 0.07 }, NORI, {
			NORI_WRAP_X,
			(0.9 + NORI_WRAP_BACK) / 2,
			1.375,
		}, "Fabric")
	)
	return list
end

---------------------------------------------------------------- 머리
-- 눈 (side -1 = 앞 -Z, 1 = 뒤 +Z): 머리 옆에 크게 튀어나온 크림 공 + 검은 눈동자 공 + 흰 반짝
local EYE_X, EYE_Y = 2.0, Y + 0.24
local function fishEye(side: number): { PartSpec }
	local tag = if side < 0 then "F" else "B"
	return {
		ball(`FishEye{tag}`, 0.96, EYE_CREAM, { EYE_X, EYE_Y, side * 0.76 }, nil, { attach = "FishRoot" }),
		ball(`FishPupil{tag}`, 0.62, EYE_BLACK, { EYE_X, EYE_Y, side * 0.95 }, nil, { attach = "FishRoot" }),
		ball(
			`FishGlint{tag}`,
			0.19,
			WHITE,
			{ EYE_X + 0.12, EYE_Y + 0.15, side * 1.19 },
			"Neon",
			{ attach = "FishRoot" }
		),
	}
end

-- 젖은 윤기 띠: 등 원기둥 윗옆구리(위에서 30° 내려온 자리)에 붙은 얇고 긴 빛나는 판
local function gloss(name: string, x0: number, x1: number, side: number): PartSpec
	local a = math.rad(30)
	local radial = ROOT.rd + 0.035
	return piece(
		name,
		{ x1 - x0, 0.03, 0.26 },
		GLOSS,
		{ (x0 + x1) / 2, Y + ROOT.up + math.cos(a) * radial, side * math.sin(a) * radial },
		"Neon",
		{ rotation = { -side * 30, 0, 0 }, attach = "FishRoot", transparency = 0.35 }
	)
end

---------------------------------------------------------------- 고등어
function ConceptMackerel.topping(): { PartSpec }
	local list: { PartSpec } = {}
	local function add(group: { PartSpec })
		for _, spec in group do
			table.insert(list, spec)
		end
	end

	-- 앞몸 + 머리 (FishRoot 관절 파츠 = 앞몸 등 원기둥)
	add(segment("FishRoot", ROOT_X0, ROOT_X1, Y, ROOT, nil, { joint = true, pivot = ROOT_PIVOT }))
	add(cap("FishHead", HEAD_X, Y, HEAD, "FishRoot"))
	add({
		-- 앞몸 뒤끝을 둥글게 (등·배): 앞몸 → 뒷몸이 턱 없이 가늘어지고, 아치로 머리가 들려도 이음매가 안 보여요
		ball("FishRootEnd", 2 * ROOT.rd * 0.9, DORSAL, { ROOT_X0, Y + ROOT.up, 0 }, nil, { attach = "FishRoot" }),
		ball("FishRootEndBelly", 2 * ROOT.rb * 0.9, BELLY, { ROOT_X0, Y - ROOT.down, 0 }, "Foil", {
			attach = "FishRoot",
		}),
		-- 아가미 선 (머리와 몸 경계)
		rod("FishGill", 1.18, 1.25, Y + ROOT.up, ROOT.rd + 0.012, GILL, nil, { attach = "FishRoot" }),
		-- 벌린 입: 주둥이 끝 아래쪽을 Z로 가로지르는 짙은 틈(얇은 상자). 머리 공이 끝으로 갈수록 가늘어서
		-- 주둥이 끝 근처에서만 옆으로 드러나 "벌린 입 선"으로 보여요 (원판이 아니라서 빨간 코로 안 읽혀요).
		-- 그 아래 분홍 혀(얇은 상자)가 살짝 보여요
		piece("FishMouth", { 0.56, 0.26, 1.9 }, MOUTH, { 2.46, Y - 0.34, 0 }, nil, {
			rotation = { 0, 0, -10 },
			attach = "FishRoot",
		}),
		piece("FishTongue", { 0.42, 0.1, 1.84 }, TONGUE, { 2.44, Y - 0.47, 0 }, nil, {
			rotation = { 0, 0, -10 },
			attach = "FishRoot",
		}),
		-- 등지느러미 (앞)
		fin("FishDorsal", { 0.06, 0.26, 0.9 }, FIN, { 0.6, Y + ROOT.up + ROOT.rd + 0.06, 0 }, false, nil, {
			attach = "FishRoot",
		}),
		-- 윤기
		gloss("FishGlossF", 0.3, 1.6, -1),
		gloss("FishGlossB", 0.3, 1.6, 1),
		ball("FishShineF", 0.34, WHITE, { 2.12, Y + 1.12, -0.42 }, nil, { attach = "FishRoot", transparency = 0.1 }),
		ball("FishShineB", 0.34, WHITE, { 2.12, Y + 1.12, 0.42 }, nil, { attach = "FishRoot", transparency = 0.1 }),
	})
	add(fishEye(-1))
	add(fishEye(1))
	add({
		-- 물결 줄무늬: 기울기를 번갈아(크게·작게) 굵기·간격도 조금씩 달리해 출렁이는 물결처럼
		stripe("FishStripe1", 1.02, Y, ROOT, 0.08, 24, "FishRoot"),
		stripe("FishStripe2", 0.78, Y, ROOT, 0.07, 14, "FishRoot"),
		stripe("FishStripe3", 0.52, Y, ROOT, 0.09, 25, "FishRoot"),
		stripe("FishStripe4", 0.27, Y, ROOT, 0.07, 15, "FishRoot"),
	})
	-- 가슴지느러미 (관절, FishRoot에 매달려 팔랑): 앞쪽 수직변이 아가미 뒤 옆구리에
	for _, side in { -1, 1 } do
		local z = side * (ROOT.rb + 0.06)
		table.insert(
			list,
			fin(
				if side < 0 then "FishFinL" else "FishFinR",
				{ 0.05, 0.86, 1.08 },
				PECTORAL,
				{ 0.72, Y - 0.04, z },
				true,
				{ 0, side * 14, 0 },
				{
					joint = true,
					attach = "FishRoot",
					pivot = { 1.22, Y - 0.04, z },
					transparency = 0.2,
				}
			)
		)
	end

	-- 뒷몸 (FishMid 관절 파츠 = 앞마디 등 원기둥, 뒷마디·김 띠는 붙는 파츠)
	add(segment("FishMid", MID_X0, MID_X1, Y, MID, nil, { joint = true, attach = "FishRoot", pivot = MID_PIVOT }))
	add(segment("FishRear", REAR_X0, REAR_X1, Y, REAR, "FishMid"))
	add(cap("FishRearEnd", REAR_X0, Y, REAR, "FishMid"))
	add({
		stripe("FishStripe5", -1.2, Y, REAR, 0.06, 20, "FishMid"),
		stripe("FishStripe6", -0.92, Y, REAR, 0.06, 10, "FishMid"),
		fin("FishDorsal2", { 0.05, 0.26, 0.5 }, FIN, { -1.0, Y + REAR.up + REAR.rd + 0.07, 0 }, false, nil, {
			attach = "FishMid",
		}),
	})
	add(noriBand())

	-- 꼬리 (FishTail 관절 파츠 = 꼬리자루 등 원기둥) + 크게 V자로 갈라진 꼬리지느러미
	add({
		rod("FishTail", STALK_X0, STALK_X1, STALK_Y + STALK.up, STALK.rd, DORSAL, nil, {
			joint = true,
			attach = "FishMid",
			pivot = TAIL_PIVOT,
		}),
		rod(
			"FishTailBelly",
			STALK_X0 + 0.012,
			STALK_X1 - 0.012,
			STALK_Y - STALK.down,
			STALK.rb,
			BELLY,
			"Foil",
			{ attach = "FishTail" }
		),
		fin("FishTailTop", { 0.08, 1.02, 0.96 }, TAIL_FIN, { -2.39, STALK_Y + 0.42, 0 }, true, { 0, 0, -24 }, {
			attach = "FishTail",
			effect = "Sparkles",
			effectColor = { 150, 210, 255 },
		}),
		fin("FishTailLow", { 0.08, 1.02, 0.96 }, TAIL_FIN, { -2.39, STALK_Y - 0.38, 0 }, false, { 0, 0, 24 }, {
			attach = "FishTail",
		}),
	})

	-- 물방울: 평소엔 앞몸 속에 숨어 있다가 팔딱할 때 reach만큼 위·바깥으로 (Body 관절)
	local drops = {
		{ 0.4, { 0.9, Y, -0.2 }, { 1.0, 1.25, -1.3 } },
		{ 0.34, { 0.5, Y, 0.2 }, { -2.3, 0.8, 1.25 } },
		{ 0.32, { 0.7, Y, 0.1 }, { 0.6, 1.45, 1.25 } },
		{ 0.36, { 0.4, Y, -0.1 }, { -1.8, 1.0, -1.35 } },
	}
	for i, drop in drops do
		table.insert(
			list,
			ball(`Splash{i}`, drop[1] :: number, SPLASH, drop[2] :: { number }, "Glass", {
				joint = true,
				transparency = 0.2,
				reach = drop[3] :: { number },
			})
		)
	end
	return list
end

return ConceptMackerel
