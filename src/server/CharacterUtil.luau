--!strict
-- 캐릭터 이동/순간이동 도우미 (서비스가 아니라 init/start가 없어요).
-- 로비 스폰으로 보내기, 이동 값 되돌리기를 여러 서비스가 같은 방식으로 하게 한 곳에 모아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CharacterUtil = {}

local SPAWN_LIFT = Vector3.new(0, 3, 0)

-- 장애물이 바꿨을 수 있는 이동 값을 기본으로 돌려요 (젓가락은 WalkSpeed·JumpPower를 0으로 만들어요).
function CharacterUtil.resetMovement(humanoid: Humanoid)
	humanoid.WalkSpeed = Config.Character.WalkSpeed
	humanoid.JumpPower = Config.Character.JumpPower
	humanoid.PlatformStand = false
end

-- 캐릭터를 로비 스폰 위로 옮겨요. 캐릭터나 스폰이 없으면 아무 일도 안 해요.
function CharacterUtil.toLobby(player: Player)
	local character = player.Character
	local spawn = workspace:FindFirstChild("LobbySpawn")
	if character == nil or spawn == nil or not spawn:IsA("BasePart") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		CharacterUtil.resetMovement(humanoid)
	end
	character:PivotTo(spawn.CFrame + SPAWN_LIFT)
end

return CharacterUtil
