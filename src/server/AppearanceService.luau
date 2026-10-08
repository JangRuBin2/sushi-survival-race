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

-- 캐릭터 아래 초밥 Model 이름과 HumanoidRootPart에 붙이는 관절 이름 (공용 상수 Shared.SushiBody, m3-09)
AppearanceService.MODEL_NAME = SushiBody.MODEL_NAME
AppearanceService.JOINT_NAME = SushiBody.JOINT_NAME

local ROOT_WAIT = 5

-- 캐릭터마다 "새로 붙는 아바타 파츠 숨기기" 연결 (다시 입히면 바꿔 끼워요)
local hideConnections: { [Model]: RBXScriptConnection } = {}

-- 숨기지 않을 것: 초밥 Model 안, 또는 자신이나 캐릭터 아래 조상에 KeepVisible = true가 달린 것 (m3-02 QA B3).
-- 다른 기능이 캐릭터에 보이는 파츠를 붙일 때는 KeepVisible을 달거나 SushiBody 아래·캐릭터 밖에 둬요.
local function isSushiPart(character: Model, inst: Instance): boolean
	local sushi = character:FindFirstChild(AppearanceService.MODEL_NAME)
	if sushi ~= nil and (inst == sushi or inst:IsDescendantOf(sushi)) then
		return true
	end
	local current: Instance? = inst
	while current ~= nil and current ~= character do
		if current:GetAttribute(Attributes.KeepVisible) == true then
			return true
		end
		current = current.Parent
	end
	return false
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
