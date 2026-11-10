--!strict
-- 콘셉트 몸 토핑: 귀여운 전투기 두 대 (m6-08 전설 "제트기 스시"·"섀도 제트 스시"). 순수 데이터 (Roblox API 없음).
-- 콘셉트 몸 견본 모듈이 이 토핑을 콘셉트 몸(밥·얼굴·팔다리) 위에 얹어요.
--   jet()        제트기 스시: 흰·밝은 회색 동체 판이 밥 위를 덮고, 위 앞에 짙은 유리 조종석, 얼굴 위(눈썹 위)를 가로지르는
--                빨간 바이저 띠, 양옆 뒤로 젖힌 날개, 뒤 위에 남보라 꼬리날개 둘, 등 아래 제트 노즐(보랏빛 불빛·연기)
--   shadowJet()  섀도 제트 스시: 같은 기체의 악당 버전 — 건메탈 회색 + 짙은 보라·검정 판, 짙은 바이저에 빨갛게 빛나는
--                눈 두 줄과 찌푸린 눈썹 판, 더 날카롭고 크게 벌어진 꼬리날개, 아래로 처진 날개, 보라 연기
-- 독창 디자인: 특정 작품의 로봇·문장을 쓰지 않아요. 날개 표시는 번개 모양 V자(일반 도형)예요.
-- 두 기체가 같은 틀(JetStyle)을 써서 "한 가족"으로 보여요. 파츠 이름은 "Jet"로 시작해요 — 얼굴(Eye·Mouth·Brow…)·
-- 공유 몸(Body·Arm·Foot) 이름과 겹치지 않게.
-- 한도 (테스트가 고정): 바이저 띠는 얼굴 위끝(y 0.75, 당황 땀방울) 위, 날개는 얼굴 높이 위(y ≥ 0.36)라 얼굴을 안 가려요.
-- 외곽 X ≤ 5.95·Z ≤ 3.7 (concept-salmon × 1.25), 꼭대기 ≤ 이름표 − 0.4, 효과 2개(전설), 관절 없음.

local PartMath = require(script.Parent.PartMath)

local ConceptJet = {}

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
	transparency: number?,
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
	}
end

local function add(list: { PartSpec }, group: { PartSpec })
	for _, spec in group do
		table.insert(list, spec)
	end
end

-- 쐐기의 꼭짓점 쪽 끝을 같은 모양으로 잘라 낸 작은 쐐기 (날개 끝·꼬리날개 끝 색 띠). f = 잘라 낸 높이 비율(0~1).
-- WedgePart 꼭짓점은 로컬 (+Y, +Z) 모서리, 직각은 (-Y, +Z) 모서리예요. 잘라 낸 삼각형을 내심 기준으로 조금 키워서
-- (세 변이 TIP_MARGIN만큼 바깥) 원래 쐐기의 뒷면·경사면과 같은 평면에 겹치지 않게 해요 (Roblox 깜빡임 방지)
local TIP_MARGIN = 0.015
local function wedgeTip(base: PartSpec, name: string, f: number, color: { number }, material: string?): PartSpec
	local t, h, d = base.size[1], base.size[2], base.size[3]
	local a, b = h * (1 - f), d * (1 - f) -- 잘라 낸 삼각형의 두 변 (높이·깊이)
	local r = (a + b - math.sqrt(a * a + b * b)) / 2 -- 내접원 반지름
	local scale = 1 + TIP_MARGIN / r
	local cornerY, cornerZ = -h / 2 + f * h - TIP_MARGIN, d / 2 + TIP_MARGIN -- 키운 삼각형의 직각 꼭짓점
	local sizeY, sizeZ = a * scale, b * scale
	local localCenter = { 0, cornerY + sizeY / 2, cornerZ - sizeZ / 2 }
	local m = PartMath.angles(base.rotation)
	local world = {
		base.offset[1] + m[1][1] * localCenter[1] + m[1][2] * localCenter[2] + m[1][3] * localCenter[3],
		base.offset[2] + m[2][1] * localCenter[1] + m[2][2] * localCenter[2] + m[2][3] * localCenter[3],
		base.offset[3] + m[3][1] * localCenter[1] + m[3][2] * localCenter[2] + m[3][3] * localCenter[3],
	}
	return piece(name, { t + 0.03, sizeY, sizeZ }, color, world, material, {
		shape = "Wedge",
		rotation = base.rotation and table.clone(base.rotation),
	})
end

---------------------------------------------------------------- 기체 틀
type JetStyle = {
	hull: { number }, -- 동체 판 (밥 위)
	panel: { number }, -- 옆·등 판 (밥 옆면·등면을 덮는 동체 옆구리)
	intake: { number }, -- 공기 흡입구
	stripe: { number }?, -- 옆 판의 띠 (바이저에서 이어져요)
	spine: { number }, -- 가운데 등줄기
	canopy: { number }, -- 조종석 유리
	canopyFrame: { number },
	visor: { number }, -- 얼굴 위 띠
	wing: { number },
	wingTip: { number },
	mark: { number }, -- 날개 번개 V자
	fin: { number },
	finTip: { number },
	nozzle: { number },
	nozzleRim: { number },
	flame: { number }, -- 노즐 안 빛 (Neon)
	smoke: { number }, -- Smoke 효과 색
	glow: { number }, -- Glow 효과 색
	glowOnVisor: boolean, -- Glow를 바이저에 (섀도: 붉은 눈빛), 아니면 노즐에
	finSize: { number }, -- 꼬리날개 쐐기 {두께, 높이, 깊이}
	finTilt: number, -- 꼬리날개가 바깥으로 기운 각
	wingSize: { number }, -- 날개 쐐기 {두께, 폭(바깥으로), 깊이(앞뒤)}
	wingDroop: number, -- 날개가 아래로 처진 각 (섀도 +, 제트기는 위로 −)
	pod: { number }, -- 날개 아래 미사일 포드 몸 (사용자 요청 2026-11-10 "날개 키워줘")
	podTip: { number }, -- 포드 앞 머리
	visorEyes: { number }?, -- 바이저 위 빛나는 눈 (섀도)
	visorBrow: { number }?, -- 바이저 위 찌푸린 눈썹 판 (섀도)
}

local HULL_Y = 1.14 -- 동체 판 중심 (y 0.97~1.31, 밥 윗면 1.0에 묻혀요)
local HULL_T = 0.34
local HULL_TOP = HULL_Y + HULL_T / 2
local SPINE_TOP = HULL_TOP + 0.26
local WING_Y = 0.9 -- 어깨 높이 (2026-11-10 날개 키움: 정면 윤곽에서 팔 위로 보이게, 옛 0.62)
local WING_ROOT_X = 1.55 -- 날개 뿌리 (밥 옆면 1.8 속 — 뒤 모서리가 둥글어도 뿌리가 밥에 묻혀요)
local WING_Z = 0.25
local SIDE_X = 1.82 -- 옆 판 중심 (밥 옆면 1.8에 반쯤 묻혀요)
local PANEL_BOTTOM, PANEL_TOP = 0.22, 0.99 -- 옆 판 높이 (팔 위끝 -0.03보다 위)
local NOZZLE_Y, NOZZLE_Z = 0.34, 1.6

local function jet(style: JetStyle): { PartSpec }
	local list: { PartSpec } = {
		-- 동체 판: 모서리를 깎은 판 두 장 (밥의 둥근 모서리를 따라요)
		piece("JetHull", { 3.4, HULL_T, 1.9 }, style.hull, { 0, HULL_Y, 0.04 }),
		piece("JetHullLong", { 2.6, HULL_T, 2.68 }, style.hull, { 0, HULL_Y, 0.04 }),
		piece("JetSpine", { 1.3, 0.3, 2.1 }, style.spine, { 0, HULL_TOP + 0.11, 0.25 }),
		-- 옆구리·등 판: 밥 옆면(평평한 곳)과 등면 위쪽을 덮어 밥이 동체로 보여요. 앞면(얼굴)은 그대로 흰 밥
		piece("JetSideL", { 0.06, PANEL_TOP - PANEL_BOTTOM, 1.76 }, style.panel, {
			-SIDE_X,
			(PANEL_TOP + PANEL_BOTTOM) / 2,
			0,
		}),
		piece("JetSideR", { 0.06, PANEL_TOP - PANEL_BOTTOM, 1.76 }, style.panel, {
			SIDE_X,
			(PANEL_TOP + PANEL_BOTTOM) / 2,
			0,
		}),
		piece("JetBackPlate", { 2.66, 1.25, 0.06 }, style.panel, { 0, 0.37, 1.37 }),
		-- 조종석: 앞뒤로 누운 유리 관(축 Z) + 앞 둥근 끝 + 가운데 틀
		piece("JetCanopy", { 1.3, 0.96, 0.96 }, style.canopy, { 0, SPINE_TOP - 0.04, -0.25 }, "Glass", {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
			transparency = 0.08,
		}),
		piece("JetCanopyNose", { 0.96, 0.96, 0.96 }, style.canopy, { 0, SPINE_TOP - 0.04, -0.9 }, "Glass", {
			shape = "Ball",
			transparency = 0.08,
		}),
		piece("JetCanopyFrame", { 0.08, 1.0, 1.0 }, style.canopyFrame, { 0, SPINE_TOP - 0.04, -0.5 }, nil, {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
		}),
		-- 바이저 띠: 얼굴 위끝(0.75) 위, 밥 앞면에 반쯤 묻혀요
		piece("JetVisor", { 2.76, 0.2, 0.06 }, style.visor, { 0, 0.875, -1.37 }, nil, {
			effect = if style.glowOnVisor then "Glow" else nil,
			effectColor = if style.glowOnVisor then style.glow else nil,
		}),
	}
	if style.visorEyes then
		-- 바이저 위 빛나는 눈 두 줄 (Neon) + 찌푸린 눈썹 판 (안쪽이 내려가요)
		for _, side in { -1, 1 } do
			local tag = if side < 0 then "L" else "R"
			add(list, {
				piece(
					`JetVisorEye{tag}`,
					{ 0.42, 0.08, 0.04 },
					style.visorEyes,
					{ side * 0.55, 0.86, -1.405 },
					"Neon",
					{
						rotation = { 0, 0, side * 8 },
					}
				),
			})
			if style.visorBrow then
				table.insert(
					list,
					piece(
						`JetVisorBrow{tag}`,
						{ 0.7, 0.12, 0.08 },
						style.visorBrow,
						{ side * 0.48, 1.02, -1.36 },
						nil,
						{
							rotation = { 0, 0, side * 14 },
						}
					)
				)
			end
		end
	end
	-- 공기 흡입구 (옆 판 앞쪽, 날개 아래) + 옆 판 띠 (바이저 띠가 옆으로 이어져요)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		table.insert(
			list,
			piece(`JetIntake{tag}`, { 0.1, 0.26, 0.5 }, style.intake, { side * (SIDE_X + 0.03), 0.38, -0.55 })
		)
		if style.stripe then
			table.insert(
				list,
				piece(`JetStripe{tag}`, { 0.04, 0.2, 1.7 }, style.stripe, { side * (SIDE_X + 0.04), 0.875, 0 })
			)
		end
	end
	-- 날개 (WedgePart를 Z축으로 ±90° 돌린 납작한 삼각형: 뿌리 = 밥 옆, 끝 = 바깥·뒤) + 날개 끝 색 + 번개 V자
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local span = style.wingSize[2]
		local wing = piece(
			`JetWing{tag}`,
			style.wingSize,
			style.wing,
			{ side * (WING_ROOT_X + span / 2), WING_Y, WING_Z },
			nil,
			{ shape = "Wedge", rotation = { 0, 0, -side * 90 } }
		)
		if style.wingDroop ~= 0 then
			local offset, rotation = PartMath.rotateAbout(
				wing.offset,
				wing.rotation,
				{ side * WING_ROOT_X, WING_Y, WING_Z },
				{ 0, 0, -side * style.wingDroop }
			)
			wing.offset, wing.rotation = offset, rotation
		end
		add(list, { wing, wedgeTip(wing, `JetWingTip{tag}`, 0.62, style.wingTip) })
		-- 미사일 포드: 날개 아래 가운데쯤, 앞(-Z)을 향한 원기둥 + 둥근 머리 (정면에서 날개가 두툼해 보여요)
		local podX = side * (WING_ROOT_X + span * 0.5)
		local podY = WING_Y - style.wingSize[1] / 2 - 0.13 - math.sin(math.rad(style.wingDroop)) * span * 0.5
		local podZ = WING_Z + 0.1
		table.insert(
			list,
			piece(`JetPod{tag}`, { 1.25, 0.28, 0.28 }, style.pod, { podX, podY, podZ }, "Metal", {
				shape = "Cylinder",
				rotation = { 0, 90, 0 },
			})
		)
		table.insert(
			list,
			piece(`JetPodTip{tag}`, { 0.3, 0.3, 0.3 }, style.podTip, { podX, podY, podZ - 0.66 }, nil, {
				shape = "Ball",
			})
		)
		-- 번개 V자: 날개 윗면에 얇은 막대 둘 (꼭짓점이 바깥)
		local mx, mz = side * (WING_ROOT_X + span * 0.32), 0.62
		local markY = WING_Y + style.wingSize[1] / 2 + 0.01 - math.sin(math.rad(style.wingDroop)) * span * 0.32
		for k, turn in { 35, -35 } do
			local mark = piece(`JetMark{tag}{k}`, { 0.36, 0.03, 0.09 }, style.mark, {
				mx - side * 0.13,
				markY,
				mz + (if k == 1 then -0.1 else 0.1),
			}, "Neon", { rotation = { 0, side * turn, -side * style.wingDroop } })
			table.insert(list, mark)
		end
	end
	-- 꼬리날개 둘 (뒤 위, 바깥으로 기울어요) + 끝 색
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local size = style.finSize
		local fin = piece(
			`JetFin{tag}`,
			size,
			style.fin,
			{ side * 0.6, SPINE_TOP - 0.22 + size[2] / 2, 1.32 - size[3] / 2 },
			nil,
			{ shape = "Wedge", rotation = { 0, 0, -side * style.finTilt } }
		)
		add(list, { fin, wedgeTip(fin, `JetFinTip{tag}`, 0.6, style.finTip) })
		-- 수평 꼬리날개 (작은 날개, 동체 판 뒤 옆)
		table.insert(
			list,
			piece(
				`JetTailWing{tag}`,
				{ 0.1, 0.62, 0.72 },
				style.wing,
				{ side * (1.62 + 0.31), HULL_Y, 0.95 },
				nil,
				{ shape = "Wedge", rotation = { 0, 0, -side * 90 } }
			)
		)
	end
	-- 노즐 (축 Z 원기둥, 밥 등면에 붙어요) + 테 + 안쪽 빛 (Neon, 연기)
	add(list, {
		piece("JetNozzle", { 0.5, 1.0, 1.0 }, style.nozzle, { 0, NOZZLE_Y, NOZZLE_Z }, "Metal", {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
			effect = if style.glowOnVisor then nil else "Glow",
			effectColor = if style.glowOnVisor then nil else style.glow,
		}),
		piece("JetNozzleRim", { 0.1, 1.12, 1.12 }, style.nozzleRim, { 0, NOZZLE_Y, NOZZLE_Z + 0.22 }, "Metal", {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
		}),
		piece("JetFlame", { 0.06, 0.74, 0.74 }, style.flame, { 0, NOZZLE_Y, NOZZLE_Z + 0.27 }, "Neon", {
			shape = "Cylinder",
			rotation = { 0, 90, 0 },
			effect = "Smoke",
			effectColor = style.smoke,
		}),
	})
	return list
end

---------------------------------------------------------------- 두 기체
local PURPLE_GLOW = { 180, 120, 255 }

ConceptJet.STYLES = {
	jet = {
		hull = { 226, 230, 238 },
		panel = { 188, 196, 212 },
		intake = { 70, 74, 90 },
		stripe = { 222, 40, 52 },
		spine = { 246, 247, 250 },
		canopy = { 40, 44, 92 },
		canopyFrame = { 176, 182, 198 },
		visor = { 222, 40, 52 },
		wing = { 236, 238, 244 },
		wingTip = { 222, 40, 52 },
		mark = { 255, 196, 50 },
		fin = { 54, 48, 124 },
		finTip = { 222, 40, 52 },
		nozzle = { 92, 96, 110 },
		nozzleRim = { 150, 156, 172 },
		flame = { 196, 140, 255 },
		smoke = { 190, 150, 255 },
		glow = PURPLE_GLOW,
		glowOnVisor = false,
		finSize = { 0.2, 1.05, 1.15 },
		finTilt = 12,
		wingSize = { 0.32, 1.38, 2.75 }, -- 날개 키움 (2026-11-10): 폭은 외곽 한도라 거의 그대로, 앞뒤·두께·들림을 키워요
		wingDroop = -14,
		pod = { 240, 242, 248 },
		podTip = { 222, 40, 52 },
	} :: JetStyle,
	shadow = {
		hull = { 82, 86, 100 },
		panel = { 62, 64, 76 },
		intake = { 24, 22, 30 },
		stripe = { 110, 56, 170 },
		spine = { 60, 36, 96 },
		canopy = { 74, 30, 116 },
		canopyFrame = { 40, 38, 50 },
		visor = { 30, 28, 40 },
		wing = { 74, 78, 92 },
		wingTip = { 96, 52, 150 },
		mark = { 170, 90, 255 },
		fin = { 46, 30, 76 },
		finTip = { 150, 70, 230 },
		nozzle = { 44, 44, 54 },
		nozzleRim = { 96, 52, 150 },
		flame = { 200, 90, 255 },
		smoke = { 130, 70, 200 },
		glow = { 255, 50, 60 },
		glowOnVisor = true,
		finSize = { 0.2, 1.3, 1.2 },
		finTilt = 22,
		wingSize = { 0.32, 1.38, 2.8 }, -- 날개 키움 (2026-11-10, 제트기와 같게)
		wingDroop = 12,
		pod = { 52, 50, 64 },
		podTip = { 170, 90, 255 },
		visorEyes = { 255, 40, 56 },
		visorBrow = { 60, 36, 96 },
	} :: JetStyle,
}

function ConceptJet.jet(): { PartSpec }
	return jet(ConceptJet.STYLES.jet)
end

function ConceptJet.shadowJet(): { PartSpec }
	return jet(ConceptJet.STYLES.shadow)
end

return ConceptJet
