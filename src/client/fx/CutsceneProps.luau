--!strict
-- 탈락 연출 소품 (m3-03): 젓가락, 간장 종지, 손님 입, 셰프 손. 지금은 회색 박스에 색만 입혀요 (아트는 M4).
-- 모두 Anchored·충돌 없음. 만든 Model은 연출 Model 밑에 넣고, 연출이 끝나면 그 Model째 지워요.
--   chopsticks() + poseChopsticks(model, tip, open)   tip = 젓가락 끝(집는 점), open 0(닫힘)~1(벌림)
--   soyDish(at)                                       at = 종지 윗면 가운데
--   mouth() + poseMouth(model, cf, open)              cf.LookVector = 입이 벌어지는 쪽, open 0~1
--   chefHand() + poseChefHand(model, cf, grip)        cf = 손바닥 가운데(손등이 위), grip 0(편 손)~1(움켜쥠)
--   splash(parent, at, rng)                           간장 방울이 튀어요 (물리로 떨어짐)
--   anchor(at)                                        말풍선을 달 보이지 않는 파트

local CutsceneProps = {}

local WOOD = Color3.fromRGB(196, 150, 96)
local DISH = Color3.fromRGB(240, 240, 235)
local SOY = Color3.fromRGB(46, 24, 12)
local LIP = Color3.fromRGB(214, 84, 96)
local MOUTH_INSIDE = Color3.fromRGB(90, 20, 30)
local TONGUE = Color3.fromRGB(235, 120, 130)
local TOOTH = Color3.fromRGB(250, 250, 250)
local SKIN = Color3.fromRGB(242, 200, 160)
local SLEEVE = Color3.fromRGB(250, 250, 250)

local STICK_LENGTH = 10
local STICK_THICKNESS = 0.35
local JAW_DEPTH = 6
local FINGER_LENGTH = 5

local function part(name: string, size: Vector3, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function child(m: Model, name: string): BasePart
	return m:FindFirstChild(name) :: BasePart
end

-- 젓가락 ------------------------------------------------------------------

function CutsceneProps.chopsticks(): Model
	local m = model("Chopsticks")
	local size = Vector3.new(STICK_THICKNESS, STICK_THICKNESS, STICK_LENGTH)
	part("StickA", size, WOOD, m)
	part("StickB", size, WOOD, m)
	return m
end

-- 끝(tip)에서 위로 비스듬히 뻗은 두 막대. open이 크면 끝이 벌어져요.
function CutsceneProps.poseChopsticks(m: Model, tip: Vector3, open: number)
	local spread = 0.45 + open * 1.6
	for i, name in { "StickA", "StickB" } do
		local side = if i == 1 then -1 else 1
		local stickTip = tip + Vector3.new(side * spread, 0, 0)
		local top = tip + Vector3.new(side * 0.5, STICK_LENGTH * 0.92, STICK_LENGTH * 0.38)
		child(m, name).CFrame = CFrame.lookAt((stickTip + top) / 2, top)
	end
end

-- 간장 종지 ---------------------------------------------------------------

function CutsceneProps.soyDish(at: Vector3): Model
	local m = model("SoyDish")
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 축(X)을 위로
	local dish = part("Dish", Vector3.new(1, 6, 6), DISH, m)
	dish.Shape = Enum.PartType.Cylinder
	dish.CFrame = CFrame.new(at - Vector3.new(0, 0.5, 0)) * flat
	local soy = part("Soy", Vector3.new(0.2, 5, 5), SOY, m)
	soy.Shape = Enum.PartType.Cylinder
	soy.CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * flat
	m.PrimaryPart = dish
	return m
end

-- 손님 입 -----------------------------------------------------------------

function CutsceneProps.mouth(): Model
	local m = model("Mouth")
	part("UpperJaw", Vector3.new(6, 1.2, JAW_DEPTH), LIP, m)
	part("LowerJaw", Vector3.new(6, 1.2, JAW_DEPTH), LIP, m)
	part("UpperTeeth", Vector3.new(5, 0.5, 0.6), TOOTH, m)
	part("LowerTeeth", Vector3.new(5, 0.5, 0.6), TOOTH, m)
	part("Tongue", Vector3.new(3.6, 0.3, 3.6), TONGUE, m)
	part("Throat", Vector3.new(5.6, 0.2, 0.2), MOUTH_INSIDE, m)
	return m
end

-- 뒤쪽 경첩을 축으로 위턱은 위로, 아래턱은 아래로 벌어져요.
function CutsceneProps.poseMouth(m: Model, cf: CFrame, open: number)
	local hinge = cf * CFrame.new(0, 0, JAW_DEPTH / 2)
	local upper = hinge * CFrame.Angles(math.rad(48 * open), 0, 0)
	local lower = hinge * CFrame.Angles(-math.rad(28 * open), 0, 0)
	child(m, "UpperJaw").CFrame = upper * CFrame.new(0, 0.6, -JAW_DEPTH / 2)
	child(m, "LowerJaw").CFrame = lower * CFrame.new(0, -0.6, -JAW_DEPTH / 2)
	child(m, "UpperTeeth").CFrame = upper * CFrame.new(0, -0.1, -JAW_DEPTH + 0.4)
	child(m, "LowerTeeth").CFrame = lower * CFrame.new(0, 0.1, -JAW_DEPTH + 0.4)
	child(m, "Tongue").CFrame = lower * CFrame.new(0, 0.05, -JAW_DEPTH / 2)
	local throat = child(m, "Throat")
	throat.Size = Vector3.new(5.6, 0.2 + open * 4, 0.2)
	throat.CFrame = hinge * CFrame.new(0, open * 1.2, 0)
end

-- 셰프 손 -----------------------------------------------------------------

local FINGER_X = { -2.1, -0.7, 0.7, 2.1 }

function CutsceneProps.chefHand(): Model
	local m = model("ChefHand")
	part("Palm", Vector3.new(6, 1.4, 7), SKIN, m)
	part("Sleeve", Vector3.new(6.6, 6.6, 8), SLEEVE, m)
	for i = 1, #FINGER_X do
		part(`Finger{i}`, Vector3.new(1.3, 1.3, FINGER_LENGTH), SKIN, m)
	end
	part("Thumb", Vector3.new(1.4, 1.4, 4), SKIN, m)
	return m
end

function CutsceneProps.poseChefHand(m: Model, cf: CFrame, grip: number)
	child(m, "Palm").CFrame = cf
	child(m, "Sleeve").CFrame = cf * CFrame.new(0, 0.8, 7)
	local curl = -math.rad(85 * grip)
	for i, x in FINGER_X do
		local knuckle = cf * CFrame.new(x, 0, -3.5) * CFrame.Angles(curl, 0, 0)
		child(m, `Finger{i}`).CFrame = knuckle * CFrame.new(0, 0, -FINGER_LENGTH / 2)
	end
	local thumbBase = cf * CFrame.new(-3.2, -0.2, 1) * CFrame.Angles(0, math.rad(40), 0) * CFrame.Angles(curl, 0, 0)
	child(m, "Thumb").CFrame = thumbBase * CFrame.new(0, 0, -2)
end

-- 간장 방울 ---------------------------------------------------------------

function CutsceneProps.splash(parent: Instance, at: Vector3, rng: Random)
	for _ = 1, 8 do
		local drop = part("SoyDrop", Vector3.new(0.5, 0.5, 0.5), SOY, parent)
		drop.Shape = Enum.PartType.Ball
		drop.Anchored = false
		drop.Position = at + Vector3.new(rng:NextNumber(-1, 1), 0.5, rng:NextNumber(-1, 1))
		drop.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(14, 24), rng:NextNumber(-9, 9))
	end
end

-- 말풍선 자리 -------------------------------------------------------------

function CutsceneProps.anchor(at: Vector3): Part
	local p = part("SpeechAnchor", Vector3.new(0.2, 0.2, 0.2), DISH)
	p.Transparency = 1
	p.Position = at
	return p
end

return CutsceneProps
