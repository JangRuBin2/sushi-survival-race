--!strict
-- 잡기 입력·감속·표시 (m3-07). 잡기 성립·해제 판정은 서버(GrabService)가 해요.
--   입력: 마우스 왼쪽 / 게임패드 ButtonR2 / 모바일 GrabButton. 누르면 GrabInput(true), 떼면 GrabInput(false).
--     UI가 먹은 누름(gameProcessed)과 관전 중(카메라가 내 Humanoid를 보지 않음)에는 보내지 않아요.
--     누른 채로 창 포커스를 잃거나 캐릭터가 바뀌면 false를 보내요.
--   감속: 내 캐릭터에 GrabbedBy가 있으면 이동 입력 × TargetSpeedMultiplier, GrabbingUserId가 있으면
--     × GrabberSpeedMultiplier. 기본 조작 다음 렌더 단계에서 Humanoid:Move로 줄여요 (WalkSpeed는 안 건드려요).
--   표시: GrabbingUserId가 있는 모든 캐릭터에 잡는 사람 → 대상 흰 Beam("밥알 팔")과 대상 머리 위 "잡혔다!".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Sfx)
local GrabButton = require(script.Parent.GrabButton)

local RENDER_STEP_NAME = "GrabSlowdown"
local ARM_COLOR = Color3.fromRGB(255, 255, 255)

type Visual = {
	targetId: number,
	grabberRoot: BasePart,
	targetRoot: BasePart,
	instances: { Instance },
}

local GrabController = {}

local localPlayer = Players.LocalPlayer
local grabInputEvent: RemoteEvent
local holding = false
local visuals: { [number]: Visual } = {} -- 잡는 사람 userId → 표시

local function myHumanoid(): Humanoid?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function isSpectating(): boolean
	local camera = Workspace.CurrentCamera
	local humanoid = myHumanoid()
	return camera == nil or humanoid == nil or camera.CameraSubject ~= humanoid
end

local function press()
	if holding or isSpectating() then
		return
	end
	holding = true
	grabInputEvent:FireServer(true)
end

local function release()
	if not holding then
		return
	end
	holding = false
	grabInputEvent:FireServer(false)
end

local function isGrabInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
end

-- 감속 -------------------------------------------------------------------------

local function slowdown()
	local character = localPlayer.Character
	if character == nil then
		return
	end
	local multiplier = 1
	if character:GetAttribute(Attributes.GrabbedBy) ~= nil then
		multiplier *= Config.Grab.TargetSpeedMultiplier
	end
	if character:GetAttribute(Attributes.GrabbingUserId) ~= nil then
		multiplier *= Config.Grab.GrabberSpeedMultiplier
	end
	if multiplier >= 1 then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(humanoid.MoveDirection * multiplier, false)
	end
end

-- 표시 -------------------------------------------------------------------------

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function destroyVisual(grabberId: number)
	local visual = visuals[grabberId]
	if visual == nil then
		return
	end
	visuals[grabberId] = nil
	for _, instance in visual.instances do
		instance:Destroy()
	end
end

local function createVisual(grabberRoot: BasePart, targetRoot: BasePart, targetCharacter: Model): { Instance }
	local from = Instance.new("Attachment")
	from.Name = "GrabArmFrom"
	from.Position = Vector3.new(0, 0, -1)
	from.Parent = grabberRoot

	local to = Instance.new("Attachment")
	to.Name = "GrabArmTo"
	to.Parent = targetRoot

	local beam = Instance.new("Beam")
	beam.Name = "GrabArm"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(ARM_COLOR)
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 0
	beam.Parent = grabberRoot

	local head = targetCharacter:FindFirstChild("Head")
	local adornee = if head and head:IsA("BasePart") then head else targetRoot
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GrabbedTag"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(96, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "잡혔다!"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = targetRoot

	return { beam, from, to, billboard }
end

local function syncVisuals()
	local seen: { [number]: boolean } = {}
	for _, grabber in Players:GetPlayers() do
		local character = grabber.Character
		local targetId = character and character:GetAttribute(Attributes.GrabbingUserId)
		if typeof(targetId) ~= "number" then
			continue
		end
		local target = Players:GetPlayerByUserId(targetId)
		local grabberRoot = rootOf(character)
		local targetCharacter = target and target.Character
		local targetRoot = rootOf(targetCharacter)
		if grabberRoot == nil or targetRoot == nil or targetCharacter == nil then
			continue
		end
		seen[grabber.UserId] = true
		local visual = visuals[grabber.UserId]
		if
			visual
			and visual.targetId == targetId
			and visual.grabberRoot == grabberRoot
			and visual.targetRoot == targetRoot
		then
			continue
		end
		destroyVisual(grabber.UserId)
		visuals[grabber.UserId] = {
			targetId = targetId,
			grabberRoot = grabberRoot,
			targetRoot = targetRoot,
			instances = createVisual(grabberRoot, targetRoot, targetCharacter),
		}
	end
	for grabberId in visuals do
		if not seen[grabberId] then
			destroyVisual(grabberId)
		end
	end
end

-- 시작 -------------------------------------------------------------------------

function GrabController.start(_gui: Instance)
	grabInputEvent = Remotes.event("GrabInput")

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not isGrabInput(input) then
			return
		end
		press()
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if isGrabInput(input) then
			release()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(release)
	localPlayer.CharacterAdded:Connect(release)
	localPlayer.CharacterRemoving:Connect(release)

	local button = GrabButton.create(function(isHolding: boolean)
		if isHolding then
			press()
		else
			release()
		end
	end)

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Input.Value + 1, slowdown)

	-- 내 캐릭터 속성이 생길 때 소리, 잡는 동안 버튼 색
	local wasGrabbing = false
	local wasGrabbed = false
	RunService.Heartbeat:Connect(function()
		syncVisuals()

		local character = localPlayer.Character
		local grabbing = character ~= nil and character:GetAttribute(Attributes.GrabbingUserId) ~= nil
		local grabbed = character ~= nil and character:GetAttribute(Attributes.GrabbedBy) ~= nil
		local root = rootOf(character)
		if grabbing and not wasGrabbing then
			Sfx.play("GrabStart", root)
		end
		if grabbed and not wasGrabbed then
			Sfx.play("Grabbed", root)
		end
		if button and grabbing ~= wasGrabbing then
			button.setActive(grabbing)
		end
		wasGrabbing = grabbing
		wasGrabbed = grabbed
	end)
end

return GrabController
