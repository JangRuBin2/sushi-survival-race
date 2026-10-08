--!strict
-- 우승 연출 장면 소품 (m3-05, 회색 박스): 초밥집 벽 + 문 2짝 + 간판 "스시집", 나무 부두, 바다, 물고기.
-- 클라이언트 로컬에만 만들어요 (서버는 모름). 배치 숫자는 Shared.VictoryCutsceneLogic.Layout과 같이 써요.
--   VictoryProps.build(origin)            장면 Model (origin = 문 가운데 바닥, 앞 = origin.LookVector)
--   VictoryProps.setDoorsOpen(props, a)   문 열림 0~1 (가운데에서 바깥(앞)으로 열려요)
--   VictoryProps.poseFish(fish, cf, clap) 물고기 한 마리 놓기, clap(-1~1)만큼 지느러미 "손"을 흔들어요

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VictoryCutsceneLogic = require(ReplicatedStorage.Shared.VictoryCutsceneLogic)

local Layout = VictoryCutsceneLogic.Layout

export type Door = {
	part: BasePart,
	hinge: CFrame, -- 경첩 (장면 기준 월드 CFrame)
	side: number, -- -1 = 왼쪽 문, 1 = 오른쪽 문
}

export type Fish = {
	model: Model,
	body: BasePart,
	tail: BasePart,
	finLeft: BasePart,
	finRight: BasePart,
}

export type Props = {
	model: Model,
	origin: CFrame,
	doors: { Door },
	fish: { Fish },
}

local VictoryProps = {}

local WOOD = Color3.fromRGB(150, 105, 65)
local DARK_WOOD = Color3.fromRGB(105, 70, 40)
local WALL = Color3.fromRGB(235, 225, 205)
local SEA = Color3.fromRGB(60, 140, 220)
local FISH_COLORS = { Color3.fromRGB(255, 150, 50), Color3.fromRGB(70, 130, 230) }
local FIN_SIZE = Vector3.new(0.3, 1.2, 0.8)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
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

local function buildShop(model: Model, origin: CFrame): { Door }
	local doorWidth = Layout.DoorWidth
	local doorHeight = Layout.DoorHeight
	local wallWidth = 28
	local wallHeight = 14
	local sideWidth = (wallWidth - doorWidth) / 2

	-- 벽 (문 구멍을 남기고 양옆 + 위), 가게 안 바닥
	for _, side in { -1, 1 } do
		local x = side * (doorWidth / 2 + sideWidth / 2)
		part(model, "Wall", Vector3.new(sideWidth, wallHeight, 1), origin * CFrame.new(x, wallHeight / 2, 0.5), WALL)
	end
	part(
		model,
		"WallTop",
		Vector3.new(doorWidth, wallHeight - doorHeight, 1),
		origin * CFrame.new(0, doorHeight + (wallHeight - doorHeight) / 2, 0.5),
		WALL
	)
	part(model, "ShopFloor", Vector3.new(wallWidth, 1, 12), origin * CFrame.new(0, -0.5, 6.5), DARK_WOOD)
	-- 노렌 느낌의 처마
	part(
		model,
		"Awning",
		Vector3.new(wallWidth + 2, 1, 3),
		origin * CFrame.new(0, wallHeight - 2, -1),
		Color3.fromRGB(200, 50, 50)
	)

	-- 간판 "스시집"
	local sign = part(model, "Sign", Vector3.new(12, 3, 0.6), origin * CFrame.new(0, wallHeight + 1.5, -0.2), DARK_WOOD)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "스시집"
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromRGB(255, 240, 200)
	text.Parent = surface

	-- 문 2짝: 경첩은 바깥 모서리, 가운데에서 바깥(앞, -Z)으로 열려요
	local doors: { Door } = {}
	local leafWidth = doorWidth / 2
	for _, side in { -1, 1 } do
		local hinge = origin * CFrame.new(side * doorWidth / 2, 0, 0)
		local leaf = part(
			model,
			if side < 0 then "DoorLeft" else "DoorRight",
			Vector3.new(leafWidth, doorHeight, 0.5),
			hinge * CFrame.new(-side * leafWidth / 2, doorHeight / 2, 0),
			WOOD
		)
		table.insert(doors, { part = leaf, hinge = hinge, side = side })
	end
	return doors
end

local function buildDock(model: Model, origin: CFrame)
	local length = Layout.DockLength
	local width = Layout.DockWidth
	-- 판자: 2 studs 폭으로 나눠서 나무 느낌
	local planks = math.floor(length / 2)
	for i = 1, planks do
		local z = -(i - 0.5) * (length / planks)
		local color = if i % 2 == 0 then WOOD else Color3.fromRGB(165, 118, 75)
		part(model, "Plank", Vector3.new(width, 1, length / planks - 0.15), origin * CFrame.new(0, -0.5, z), color)
	end
	-- 기둥
	for i = 0, 3 do
		local z = -i * (length - 1) / 3 - 0.5
		for _, side in { -1, 1 } do
			part(model, "Post", Vector3.new(1, 10, 1), origin * CFrame.new(side * (width / 2 - 0.5), -5, z), DARK_WOOD)
		end
	end
end

local function buildSea(model: Model, origin: CFrame)
	local sea = part(model, "Sea", Vector3.new(160, 1, 140), origin * CFrame.new(0, Layout.WaterY - 0.5, -50), SEA)
	sea.Material = Enum.Material.SmoothPlastic
	sea.Transparency = 0.15
	sea.Reflectance = 0.1
	-- 가게 땅 (바다 위로 가게·부두 시작점을 받쳐요)
	part(model, "Shore", Vector3.new(60, 6, 30), origin * CFrame.new(0, -3.5, 14), Color3.fromRGB(210, 190, 140))
end

local function buildFish(model: Model, index: number): Fish
	local fishModel = Instance.new("Model")
	fishModel.Name = `Fish{index}`
	fishModel.Parent = model
	local color = FISH_COLORS[(index - 1) % #FISH_COLORS + 1]
	local origin = CFrame.new()
	local body = part(fishModel, "Body", Vector3.new(1.6, 2.4, 1.2), origin, color)
	local tail = part(fishModel, "Tail", Vector3.new(0.4, 1.2, 1.4), origin, color:Lerp(Color3.new(1, 1, 1), 0.3))
	local finLeft = part(fishModel, "FinLeft", FIN_SIZE, origin, color:Lerp(Color3.new(0, 0, 0), 0.2))
	local finRight = part(fishModel, "FinRight", FIN_SIZE, origin, color:Lerp(Color3.new(0, 0, 0), 0.2))
	-- 눈 두 개
	for _, side in { -1, 1 } do
		local eye = part(fishModel, "Eye", Vector3.new(0.35, 0.35, 0.2), origin, Color3.new(0.05, 0.05, 0.05))
		eye:SetAttribute("Side", side)
	end
	fishModel.PrimaryPart = body
	return { model = fishModel, body = body, tail = tail, finLeft = finLeft, finRight = finRight }
end

function VictoryProps.build(origin: CFrame): Props
	local model = Instance.new("Model")
	model.Name = "VictoryCutscene"

	local doors = buildShop(model, origin)
	buildDock(model, origin)
	buildSea(model, origin)

	local fish: { Fish } = {}
	for i = 1, Layout.FishCount do
		local one = buildFish(model, i)
		table.insert(fish, one)
		-- 처음엔 물속에 숨겨둬요
		VictoryProps.poseFish(one, origin * CFrame.new(0, Layout.WaterY - 10, Layout.DiveLandZ), 0)
	end

	return { model = model, origin = origin, doors = doors, fish = fish }
end

function VictoryProps.setDoorsOpen(props: Props, amount: number)
	local angle = math.rad(100) * math.clamp(amount, 0, 1)
	for _, door in props.doors do
		local leafWidth = door.part.Size.X
		-- 바깥(-Z)으로 열리게: 왼쪽 문(경첩 -X)은 +각도, 오른쪽 문은 -각도로 Y축 회전
		door.part.CFrame = door.hinge
			* CFrame.Angles(0, door.side * -angle, 0)
			* CFrame.new(-door.side * leafWidth / 2, door.part.Size.Y / 2, 0)
	end
end

-- cframe = 물고기 몸 가운데 (LookVector = 바라보는 쪽, 보통 인형)
function VictoryProps.poseFish(fish: Fish, cframe: CFrame, clap: number)
	fish.body.CFrame = cframe
	fish.tail.CFrame = cframe * CFrame.new(0, -1.5, 0.3) * CFrame.Angles(math.rad(-20), 0, 0)
	-- 지느러미 "손": 몸 양옆에서 위아래로 흔들며 가운데로 모였다 벌어져요
	local lift = 0.5 + clap * 0.5
	local inward = math.rad(35) * (clap * 0.5 + 0.5)
	fish.finLeft.CFrame = cframe * CFrame.new(-1.05, lift, -0.3) * CFrame.Angles(0, 0, -inward)
	fish.finRight.CFrame = cframe * CFrame.new(1.05, lift, -0.3) * CFrame.Angles(0, 0, inward)
	for _, child in fish.model:GetChildren() do
		if child.Name == "Eye" and child:IsA("BasePart") then
			local side = child:GetAttribute("Side") :: number? or 1
			child.CFrame = cframe * CFrame.new(side * 0.4, 0.6, -0.65)
		end
	end
end

return VictoryProps
