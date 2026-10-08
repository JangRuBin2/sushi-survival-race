--!strict
-- 캐릭터 외형을 입히는 유일한 곳 (CLAUDE.md "applyAppearance").
--   applyAppearance(character, appearanceId?)  원래 몸·얼굴·액세서리를 숨기고 SushiBody를 HumanoidRootPart에 붙여요.
-- 초밥 파츠는 보이기만 해요 (Massless, 충돌·쿼리·터치 없음) — 히트박스·물리·맵 판정은 휴머노이드 그대로.
-- 스킨·상점이 붙으면 여기서 플레이어의 스킨 id를 골라요 (지금은 모두 Config.Appearance.Default).
-- 클라이언트 연출(CharacterFxController)은 Body의 `SushiJoint`(Motor6D).Transform을 로컬로 흔들어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)

local AppearanceService = {}

-- 캐릭터 아래 초밥 Model 이름과 HumanoidRootPart에 붙이는 관절 이름 (CharacterFxController가 같은 이름을 써요)
AppearanceService.MODEL_NAME = "SushiBody"
AppearanceService.JOINT_NAME = "SushiJoint"

local ROOT_WAIT = 5

-- 캐릭터마다 "새로 붙는 아바타 파츠 숨기기" 연결 (다시 입히면 바꿔 끼워요)
local hideConnections: { [Model]: RBXScriptConnection } = {}

local function isSushiPart(character: Model, inst: Instance): boolean
	local sushi = character:FindFirstChild(AppearanceService.MODEL_NAME)
	return sushi ~= nil and (inst == sushi or inst:IsDescendantOf(sushi))
end

local function hide(inst: Instance)
	-- BasePart(몸·액세서리 Handle)와 Decal(얼굴·옷 무늬)
	if inst:IsA("BasePart") or inst:IsA("Decal") then
		(inst :: any).Transparency = 1
	end
end

local function hideOriginal(character: Model)
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("face")
	if face and face:IsA("Decal") then
		face:Destroy()
	end
	for _, inst in character:GetDescendants() do
		if not isSushiPart(character, inst) then
			hide(inst)
		end
	end

	local old = hideConnections[character]
	if old then
		old:Disconnect()
	end
	-- 아바타 액세서리·옷은 CharacterAdded 뒤에 늦게 붙을 수 있어요
	hideConnections[character] = character.DescendantAdded:Connect(function(inst)
		if not isSushiPart(character, inst) then
			hide(inst)
		end
	end)
end

-- HumanoidRootPart 중심에서 땅(발바닥)까지 거리
local function groundBelowRoot(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return root.Size.Y / 2 + 2 -- R6: 다리 2 studs
end

function AppearanceService.applyAppearance(character: Model, appearanceId: string?)
	local id = appearanceId or Config.Appearance.Default
	character:SetAttribute(Attributes.AppearanceId, id)

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		warn(`[AppearanceService] {character.Name} has no HumanoidRootPart`)
		return
	end

	local existing = character:FindFirstChild(AppearanceService.MODEL_NAME)
	if existing then
		existing:Destroy()
	end
	hideOriginal(character)

	local sushi = SushiBody.build(id)
	sushi.Name = AppearanceService.MODEL_NAME
	local body = sushi.PrimaryPart :: BasePart
	local offset = CFrame.new(0, SushiBody.GROUND_OFFSET - groundBelowRoot(character, root), 0)
	sushi:PivotTo(root.CFrame * offset)
	body.Anchored = false

	local joint = Instance.new("Motor6D")
	joint.Name = AppearanceService.JOINT_NAME
	joint.Part0 = root
	joint.Part1 = body
	joint.C0 = offset
	joint.Parent = body

	sushi.Parent = character
end

local function onCharacterAdded(character: Model)
	if character:WaitForChild("HumanoidRootPart", ROOT_WAIT) == nil then
		return
	end
	if character.Parent == nil then
		return
	end
	AppearanceService.applyAppearance(character, nil)
end

local function watchPlayer(player: Player)
	-- 아바타 체형·옷을 불러오지 않아요: 모든 플레이어가 같은 기본 체형(같은 히트박스)으로 시작해요 (GDD 6)
	player.CanLoadCharacterAppearance = false
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(onCharacterAdded, character)
	end)
	player.CharacterRemoving:Connect(function(character: Model)
		local conn = hideConnections[character]
		if conn then
			conn:Disconnect()
			hideConnections[character] = nil
		end
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function AppearanceService.init()
	StarterPlayer.LoadCharacterAppearance = false
end

function AppearanceService.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character and hideConnections[character] then
			hideConnections[character]:Disconnect()
			hideConnections[character] = nil
		end
	end)
end

return AppearanceService
