--!strict
-- 초밥 캐릭터 몸. 서버 캐릭터(AppearanceService)와 클라이언트 연출 인형(m3-03 탈락, m3-05 우승)이 같이 써요.
--   layout(appearanceId)  파츠 목록 (순수 함수, lune 테스트 가능). 모르는 id면 기본(tamago).
--   bounds(layout)        파츠 목록 전체 외곽 (순수 함수, Body 중심 기준 min/max)
--   build(appearanceId)   파츠를 만들고 Body에 용접한 Model. PrimaryPart = Body(Anchored). 원점에 있어요 → PivotTo로 옮겨요.
--   GROUND_OFFSET         Body 중심이 땅(발바닥)에서 몇 studs 위인지. 인형을 땅에 세울 때 써요.
--   MODEL_NAME / JOINT_NAME  캐릭터 아래 초밥 Model 이름, HumanoidRootPart에 붙이는 Motor6D 이름
--                         (서버 AppearanceService와 클라이언트 CharacterFxController가 같이 써요)
-- 좌표: Body 중심 기준, 앞 = -Z (눈이 있는 쪽), 위 = +Y. 크기는 지금 휴머노이드 히트박스(약 5 studs)에 맞춰요.
-- 초밥 파츠는 보이기만 해요 (Massless, 충돌·쿼리·터치 없음) — 판정은 휴머노이드 그대로.

local SushiBody = {}

SushiBody.MODEL_NAME = "SushiBody"
SushiBody.JOINT_NAME = "SushiJoint"

-- 파츠 하나. Roblox 자료형 대신 숫자 배열을 써요 (lune 테스트용).
export type PartSpec = {
	name: string,
	size: { number }, -- {x, y, z}
	color: { number }, -- {r, g, b} 0~255
	material: string, -- Enum.Material 이름
	offset: { number }, -- Body 중심 기준 위치 {x, y, z}
}

export type Bounds = {
	min: { number },
	max: { number },
}

local DEFAULT_ID = "tamago"

local RICE = { 246, 243, 232 }
local RICE_SHADE = { 228, 222, 206 }
local EGG = { 255, 204, 64 }
local NORI = { 28, 34, 30 }
local INK = { 20, 20, 24 }
local MOUTH = { 130, 45, 45 }

-- 세워진 계란초밥: 밥 몸통 + 위·등을 덮는 계란 + 가운데 김 띠 + 앞면 눈·입 + 짧은 발.
-- 바닥(발바닥) y = -2.3, 꼭대기(계란 위) y = 2.4 → 높이 4.7
local TAMAGO: { PartSpec } = {
	{ name = "Body", size = { 2.4, 3.2, 1.8 }, color = RICE, material = "SmoothPlastic", offset = { 0, 0, 0 } },
	{ name = "Egg", size = { 2.8, 0.8, 2.2 }, color = EGG, material = "SmoothPlastic", offset = { 0, 2.0, 0.2 } },
	{ name = "EggBack", size = { 2.6, 1.6, 0.3 }, color = EGG, material = "SmoothPlastic", offset = { 0, 0.9, 1.05 } },
	{ name = "Nori", size = { 2.5, 0.7, 1.9 }, color = NORI, material = "SmoothPlastic", offset = { 0, -0.3, 0 } },
	{
		name = "EyeLeft",
		size = { 0.35, 0.5, 0.1 },
		color = INK,
		material = "SmoothPlastic",
		offset = { -0.5, 1.0, -0.93 },
	},
	{
		name = "EyeRight",
		size = { 0.35, 0.5, 0.1 },
		color = INK,
		material = "SmoothPlastic",
		offset = { 0.5, 1.0, -0.93 },
	},
	{
		name = "Mouth",
		size = { 0.5, 0.12, 0.1 },
		color = MOUTH,
		material = "SmoothPlastic",
		offset = { 0, 0.55, -0.93 },
	},
	{
		name = "FootLeft",
		size = { 0.6, 0.7, 0.8 },
		color = RICE_SHADE,
		material = "SmoothPlastic",
		offset = { -0.6, -1.95, -0.1 },
	},
	{
		name = "FootRight",
		size = { 0.6, 0.7, 0.8 },
		color = RICE_SHADE,
		material = "SmoothPlastic",
		offset = { 0.6, -1.95, -0.1 },
	},
}

local LAYOUTS: { [string]: { PartSpec } } = {
	tamago = TAMAGO,
}

-- Body 중심에서 발바닥까지 (TAMAGO 바닥 y = -2.3)
SushiBody.GROUND_OFFSET = 2.3

local function copySpec(spec: PartSpec): PartSpec
	return {
		name = spec.name,
		size = table.clone(spec.size),
		color = table.clone(spec.color),
		material = spec.material,
		offset = table.clone(spec.offset),
	}
end

-- 파츠 목록 (복사본이라 고쳐도 원본은 안 바뀌어요)
function SushiBody.layout(appearanceId: string): { PartSpec }
	local source = LAYOUTS[appearanceId] or LAYOUTS[DEFAULT_ID]
	local list = {}
	for _, spec in source do
		table.insert(list, copySpec(spec))
	end
	return list
end

-- 회전 없는 상자들의 전체 외곽
function SushiBody.bounds(layout: { PartSpec }): Bounds
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, spec in layout do
		for axis = 1, 3 do
			local half = spec.size[axis] / 2
			lo[axis] = math.min(lo[axis], spec.offset[axis] - half)
			hi[axis] = math.max(hi[axis], spec.offset[axis] + half)
		end
	end
	return { min = lo, max = hi }
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

function SushiBody.build(appearanceId: string): Model
	local model = Instance.new("Model")
	model.Name = `SushiBody_{appearanceId}`

	local body: BasePart? = nil
	for _, spec in SushiBody.layout(appearanceId) do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = vec(spec.size)
		part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		part.Material = (Enum.Material :: any)[spec.material] :: Enum.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(vec(spec.offset))
		part.Anchored = spec.name == "Body"
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Parent = model
		if spec.name == "Body" then
			body = part
		end
	end
	assert(body, "SushiBody layout needs a Body part")

	for _, child in model:GetChildren() do
		if child ~= body and child:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
		end
	end

	model.PrimaryPart = body
	return model
end

return SushiBody
