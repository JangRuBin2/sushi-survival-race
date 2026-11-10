--!strict
-- 공격 입력 (m6-08, GDD 6). 맞았는지·쿨다운은 서버(AttackService)가 정해요.
--   입력: F / 게임패드 ButtonL2 / 모바일 AttackButton. 누르는 순간 AttackInput 한 번.
--     UI가 먹은 누름(gameProcessed)과 관전 중(카메라가 내 Humanoid를 보지 않음)에는 보내지 않아요.
--     서버가 단 Player 속성 AttackReadyAt이 아직 안 지났으면 보내지 않아요(표시와 같은 기준 — 서버가 다시 검증해요).
--   쿨다운 표시: 모바일 버튼에 남은 초 (AttackReadyAt − 서버 시각, 올림).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AttackButton = require(script.Parent.AttackButton)

local ATTACK_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.F] = true,
	[Enum.KeyCode.ButtonL2] = true,
}

local AttackController = {}

local localPlayer = Players.LocalPlayer
local attackInputEvent: RemoteEvent
local lastSent = -math.huge

local function isSpectating(): boolean
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return camera == nil or humanoid == nil or camera.CameraSubject ~= humanoid
end

-- 남은 쿨다운(초, 0이면 준비됨)
local function remaining(): number
	local readyAt = localPlayer:GetAttribute(Attributes.AttackReadyAt)
	if type(readyAt) ~= "number" then
		return 0
	end
	return math.max(0, readyAt - Workspace:GetServerTimeNow())
end

local function press()
	if isSpectating() or remaining() > 0 then
		return
	end
	local now = os.clock()
	if now - lastSent < Config.Attack.InputMinInterval then
		return
	end
	lastSent = now
	attackInputEvent:FireServer()
end

function AttackController.start(_gui: Instance)
	attackInputEvent = Remotes.event("AttackInput")

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessed: boolean)
		if gameProcessed or not ATTACK_KEYS[inputObject.KeyCode] then
			return
		end
		press()
	end)

	local button = AttackButton.create(press)
	if button then
		local shown: number? = nil
		RunService.Heartbeat:Connect(function()
			local left = remaining()
			local seconds = if left > 0 then math.ceil(left) else nil
			if seconds ~= shown then
				shown = seconds
				button.setCooldown(seconds)
			end
		end)
	end
end

return AttackController
