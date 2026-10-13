--!strict
-- 탈락 연출 소품 (m3-03): 젓가락, 간장 종지, 손님 입, 셰프 손 + 고양이 손님 팩(m5-09).
-- 모두 Anchored·충돌 없음. 만든 Model은 연출 Model 밑에 넣고, 연출이 끝나면 그 Model째 지워요.
--   chopsticks() + poseChopsticks(model, tip, open)   tip = 젓가락 끝(집는 점), open 0(닫힘)~1(벌림)
--   soyDish(at)                                       at = 종지 윗면 가운데
--   mouth() + poseMouth(model, cf, open)              cf.LookVector = 입이 벌어지는 쪽, open 0~1
--   chefHand() + poseChefHand(model, cf, grip)        cf = 손바닥 가운데(손등이 위), grip 0(편 손)~1(움켜쥠)
--   splash(parent, at, rng)                           간장 방울이 튀어요 (물리로 떨어짐)
--   anchor(at)                                        말풍선을 달 보이지 않는 파트
-- 고양이 손님 연출 팩 (m5-09) — 기본 소품과 같은 자리·같은 pose 인자로 바꿔 끼워요:
--   catChopsticks() + poseCatChopsticks(model, tip, open, t)  고양이 발(주황 털·분홍 발바닥)이 젓가락을 쥐어요
--   catHead() + poseCatHead(model, cf, open, t)                고양이 얼굴. cf·open은 poseMouth와 같아요
--   catPaw() + poseCatPaw(model, cf, grip, t)                  커다란 앞발. cf·grip은 poseChefHand와 같아요 (쥘 때 발톱)

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

-- 고양이 손님 (m5-09) ------------------------------------------------------
-- 기본 소품과 같은 자리·같은 pose 인자를 받아서 연출 코드는 소품만 바꿔 끼워요.
-- 파츠 수: 젓가락 세트 5(기본 2), 고양이 얼굴 23(기본 입 6), 앞발 18(기본 셰프 손 7) → 연출마다 기본 + 20 이하.

local CAT_FUR = Color3.fromRGB(255, 152, 64)
local CAT_FUR_DARK = Color3.fromRGB(226, 110, 38)
local CAT_CREAM = Color3.fromRGB(255, 238, 212)
local CAT_PINK = Color3.fromRGB(255, 148, 172)
local CAT_BEAN = Color3.fromRGB(255, 128, 160)
local CAT_NOSE = Color3.fromRGB(240, 100, 135)
local CAT_EYE = Color3.fromRGB(38, 28, 30)
local CAT_WHISKER = Color3.fromRGB(80, 56, 44)
local CAT_MOUTH = Color3.fromRGB(150, 38, 62)
local CAT_CLAW = Color3.fromRGB(255, 252, 245)

local CAT_JAW_DEPTH = 4.2
local CAT_HEAD = 8 -- 머리 지름
local CAT_HEAD_OFFSET = Vector3.new(0, 1.3, 1.7) -- 경첩에서 머리 가운데 (머리가 주둥이 뒤에)
local CAT_PAW_TOE_X = { -2.7, -0.9, 0.9, 2.7 }
local CAT_PAW_TOE = 2.6
local QUARTER = math.rad(90)

local function ball(name: string, diameter: number, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.one * diameter, color, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

-- 원기둥 (축 = 로컬 X)
local function cylinder(name: string, length: number, diameter: number, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.new(length, diameter, diameter), color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- 원기둥 축(X)이 axis 쪽을 향하게 at에 놓는 CFrame
local function along(at: Vector3, axis: Vector3): CFrame
	return CFrame.lookAt(at, at + axis) * CFrame.Angles(0, QUARTER, 0)
end

-- 고양이 발이 쥔 젓가락 -----------------------------------------------------

function CutsceneProps.catChopsticks(): Model
	local m = CutsceneProps.chopsticks()
	m.Name = "CatChopsticks"
	cylinder("Forearm", 7, 2.1, CAT_FUR, m)
	ball("Paw", 2.9, CAT_FUR, m)
	cylinder("Bean", 0.25, 1.3, CAT_BEAN, m)
	return m
end

-- poseChopsticks와 같고, 젓가락 위쪽을 고양이 발이 감싸 쥐어요. t는 팔을 살랑 흔드는 데 써요.
function CutsceneProps.poseCatChopsticks(m: Model, tip: Vector3, open: number, t: number)
	CutsceneProps.poseChopsticks(m, tip, open)
	local up = Vector3.new(0, STICK_LENGTH * 0.92, STICK_LENGTH * 0.38)
	local grip = tip + up * 0.72
	-- 팔은 젓가락보다 더 뒤로 눕혀 뻗어서 젓가락 연장선처럼 보이지 않게
	local armDir = Vector3.new(math.sin(t * 5) * 0.08, 0.62, 0.78).Unit
	child(m, "Paw").CFrame = CFrame.new(grip)
	child(m, "Forearm").CFrame = along(grip + armDir * 4.2, armDir)
	-- 분홍 발바닥은 앞(인형 쪽, -Z)으로
	local front = Vector3.new(0, -0.35, -1).Unit
	child(m, "Bean").CFrame = along(grip + front * 1.35, front)
end

-- 고양이 얼굴 --------------------------------------------------------------

function CutsceneProps.catHead(): Model
	local m = model("CatHead")
	ball("Head", CAT_HEAD, CAT_FUR, m)
	for _, side in { "L", "R" } do
		part(`Ear{side}`, Vector3.new(3, 3, 0.9), CAT_FUR, m)
		part(`EarInner{side}`, Vector3.new(1.8, 1.8, 0.4), CAT_PINK, m)
		ball(`Eye{side}`, 1.5, CAT_EYE, m)
		ball(`Shine{side}`, 0.5, Color3.new(1, 1, 1), m)
		cylinder(`Cheek{side}`, 0.15, 1.4, CAT_PINK, m).Transparency = 0.25
		part(`WhiskerUp{side}`, Vector3.new(0.12, 0.12, 3.4), CAT_WHISKER, m)
		part(`WhiskerDown{side}`, Vector3.new(0.12, 0.12, 3.4), CAT_WHISKER, m)
		ball(`Fang{side}`, 0.6, TOOTH, m)
	end
	-- 볼록한 주둥이 두 개 ("ω" 입) + 아래턱
	ball("MuzzleL", 2.4, CAT_CREAM, m)
	ball("MuzzleR", 2.4, CAT_CREAM, m)
	part("LowerJaw", Vector3.new(3.4, 0.8, 3.4), CAT_CREAM, m)
	part("Nose", Vector3.new(1, 0.6, 0.6), CAT_NOSE, m)
	part("Tongue", Vector3.new(2.2, 0.3, 2.4), CAT_PINK, m)
	part("Throat", Vector3.new(3.2, 0.2, 0.2), CAT_MOUTH, m)
	return m
end

-- cf = 입 가운데, LookVector = 입이 벌어지는 쪽 (poseMouth와 같아요). open 0~1, t = 귀 쫑긋·끄덕임.
function CutsceneProps.poseCatHead(m: Model, cf: CFrame, open: number, t: number)
	local hinge = cf * CFrame.new(0, 0, CAT_JAW_DEPTH / 2)
	-- 고양이처럼 주로 아래턱이 쩍 벌어지고, 주둥이는 살짝만 들려요 (얼굴을 가리지 않게)
	local upper = hinge * CFrame.Angles(math.rad(12 * open), 0, 0)
	local lower = hinge * CFrame.Angles(-math.rad(46 * open), 0, 0)
	child(m, "MuzzleL").CFrame = upper * CFrame.new(-0.95, 0.35, -CAT_JAW_DEPTH + 1.15)
	child(m, "MuzzleR").CFrame = upper * CFrame.new(0.95, 0.35, -CAT_JAW_DEPTH + 1.15)
	child(m, "Nose").CFrame = upper * CFrame.new(0, 1.35, -CAT_JAW_DEPTH + 0.8)
	child(m, "LowerJaw").CFrame = lower * CFrame.new(0, -0.75, -CAT_JAW_DEPTH / 2 - 0.2)
	child(m, "Tongue").CFrame = lower * CFrame.new(0, -0.4, -CAT_JAW_DEPTH / 2 - 0.3)
	-- 입속(어두운 분홍)이 벌린 만큼 드러나요
	local throat = child(m, "Throat")
	throat.Size = Vector3.new(3.2, 0.2 + open * 2.8, 0.2)
	throat.CFrame = hinge * CFrame.new(0, -0.2 - open * 1.3, -1.6)

	-- 입을 벌릴수록 머리를 살짝 젖혀요
	local head = hinge * CFrame.new(CAT_HEAD_OFFSET) * CFrame.Angles(math.rad(6 * open), 0, 0)
	child(m, "Head").CFrame = head
	local radius = CAT_HEAD / 2
	local function surface(x: number, y: number, z: number, inset: number): CFrame
		local dir = Vector3.new(x, y, z).Unit
		local at = dir * radius * inset
		return head * CFrame.lookAt(at, at + dir)
	end

	for i, side in { "L", "R" } do
		local sx = if i == 1 then -1 else 1
		-- 귀: 45도 돌린 네모의 위 절반만 머리 밖으로 나와 세모가 돼요. 가끔 쫑긋
		local twitch = math.max(0, math.sin(t * 3.1 + i * 1.7)) ^ 8 * 0.35
		local earBase = head
			* CFrame.new(sx * 2.25, 2.85, 0.4)
			* CFrame.Angles(0, 0, -sx * (0.38 + twitch))
			* CFrame.Angles(0, 0, math.rad(45))
		child(m, `Ear{side}`).CFrame = earBase
		child(m, `EarInner{side}`).CFrame = earBase * CFrame.new(0.35, 0.35, -0.5)

		local eye = surface(sx * 0.42, 0.42, -0.8, 0.9)
		child(m, `Eye{side}`).CFrame = eye
		child(m, `Shine{side}`).CFrame = eye * CFrame.new(sx * -0.2, 0.35, -0.6)
		child(m, `Cheek{side}`).CFrame = surface(sx * 0.62, -0.18, -0.76, 1.01) * CFrame.Angles(0, QUARTER, 0)

		-- 수염: 주둥이 양옆에서 바깥으로 두 가닥
		for j, name in { `WhiskerUp{side}`, `WhiskerDown{side}` } do
			local tilt = if j == 1 then 0.2 else -0.12
			local root = Vector3.new(sx * 1.9, 0.45, -CAT_JAW_DEPTH + 1.4)
			local dir = Vector3.new(sx, tilt, 0.25).Unit
			local center = root + dir * 1.5
			child(m, name).CFrame = upper * CFrame.lookAt(center, center + dir)
		end
		-- 둥근 송곳니 (윗턱 앞 양쪽)
		child(m, `Fang{side}`).CFrame = upper * CFrame.new(sx * 0.8, -0.75, -CAT_JAW_DEPTH + 1.05)
	end
end

-- 커다란 고양이 앞발 ------------------------------------------------------

function CutsceneProps.catPaw(): Model
	local m = model("CatPaw")
	cylinder("Palm", 2.2, 8, CAT_FUR, m)
	cylinder("Forearm", 9, 5.6, CAT_FUR, m)
	cylinder("Stripe1", 0.9, 5.9, CAT_FUR_DARK, m)
	cylinder("Stripe2", 0.9, 5.9, CAT_FUR_DARK, m)
	cylinder("Pad", 0.3, 3.6, CAT_BEAN, m)
	for i = 1, #CAT_PAW_TOE_X do
		ball(`Toe{i}`, CAT_PAW_TOE, CAT_FUR, m)
		cylinder(`Bean{i}`, 0.25, 1.3, CAT_BEAN, m)
		part(`Claw{i}`, Vector3.new(0.3, 0.3, 1), CAT_CLAW, m)
	end
	return m
end

-- cf = 손바닥 가운데(발등이 위), grip 0(편 발)~1(움켜쥠). poseChefHand와 같은 자리에 맞춰요.
function CutsceneProps.poseCatPaw(m: Model, cf: CFrame, grip: number, t: number)
	local flat = CFrame.Angles(0, 0, QUARTER) -- 원기둥 축(X)을 위로
	child(m, "Palm").CFrame = cf * flat
	child(m, "Pad").CFrame = cf * CFrame.new(0, -1.15, 0.6) * flat
	-- 팔은 하늘에서 거의 곧게 내려와요 (위로 들고 사라지는 움직임과 맞고, 비스듬히 위에서 보는 카메라를 덜 가려요)
	local wrist = cf.Position + cf:VectorToWorldSpace(Vector3.new(0, 0.6, 1.4))
	local armDir = cf:VectorToWorldSpace(Vector3.new(0, 0.95, 0.3).Unit)
	child(m, "Forearm").CFrame = along(wrist + armDir * 4.3, armDir)
	child(m, "Stripe1").CFrame = along(wrist + armDir * 3.2, armDir)
	child(m, "Stripe2").CFrame = along(wrist + armDir * 5.6, armDir)
	local curl = -math.rad(80 * grip)
	-- 발톱은 쥐는 끝 무렵 쏙 나와요
	local claw = math.clamp((grip - 0.45) / 0.4, 0, 1)
	for i, x in CAT_PAW_TOE_X do
		-- 편 발일 때 발가락마다 다른 박자로 꼼지락
		local wiggle = math.sin(t * 9 + i) * 0.06 * (1 - grip)
		local knuckle = cf * CFrame.new(x, 0.1, -3.2) * CFrame.Angles(curl + wiggle, 0, 0)
		local toe = knuckle * CFrame.new(0, 0, -1.25)
		child(m, `Toe{i}`).CFrame = toe
		child(m, `Bean{i}`).CFrame = toe * CFrame.new(0, -1.15, 0) * flat
		local clawPart = child(m, `Claw{i}`)
		clawPart.Size = Vector3.new(0.3, 0.3, 0.2 + claw * 1.1)
		clawPart.Transparency = if claw > 0 then 0 else 1
		clawPart.CFrame = toe * CFrame.new(0, -0.55, -1.0 - claw * 0.5) * CFrame.Angles(math.rad(-25), 0, 0)
	end
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
