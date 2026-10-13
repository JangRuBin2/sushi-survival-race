--!strict
-- 얼음 위 관성 이동 (m5-06 디저트 냉장고, GDD 5.3·11.4). 판정 없는 클라이언트 물리 이동이라 서버·리모트·속성은 쓰지 않아요.
--   내 캐릭터가 땅에 닿아 있고 발밑(HumanoidRootPart에서 아래로 IceLogic.RAY_LENGTH) 파츠가 Ice 태그면 얼음 모드.
--   얼음 모드에서는 매 프레임(RunService.Stepped) 지금 실제 수평 속도에서 출발해 입력 목표(MoveDirection x WalkSpeed)로
--   천천히 다가간 속도(IceLogic.step)를 수평 LinearVelocity(내 캐릭터에만, 로컬 생성이라 복제 안 됨)로 걸어요.
--   Humanoid 기본 걷기는 바닥 마찰을 거의 무시해서 바로 멈추기 때문에, 이 제약이 걷기 힘을 이기게 해요.
--   그 밖(공중·일반 바닥·넘어짐·죽음)에서는 제약을 끄고 Roblox 기본 이동 그대로예요.
--   실제 속도에서 출발하니까 서버 밀기(송풍구)·젤리·다이브·넉백 속도도 얼음 위에서 천천히 줄어요.
--   얼음은 속도를 늘리지 않아요 (IceLogic: 결과 크기 <= max(|current|, WalkSpeed)) — 이동 감시 상한과 무관.
-- 로비·다른 맵에는 Ice 태그가 없어서 아무 일도 하지 않아요.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IceLogic = require(ReplicatedStorage.Shared.IceLogic)

local IceController = {}

local GLIDE_NAME = "IceGlide"
local GLIDE_ACCEL = 600 -- 제약 힘 = 질량 x 이 가속도 (걷기 힘을 이기되 벽·큐브 충돌은 물리가 풀게 유한하게)

local SKIP_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Flying] = true,
	[Enum.HumanoidStateType.Swimming] = true,
}

function IceController.start(_gui: Instance)
	local player = Players.LocalPlayer
	local glide: LinearVelocity? = nil
	local glideRoot: BasePart? = nil
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function disable()
		if glide then
			glide.Enabled = false
		end
	end

	local function destroyGlide()
		if glide then
			glide:Destroy()
		end
		glide = nil
		glideRoot = nil
	end

	local function ensureGlide(root: BasePart): LinearVelocity
		if glide and glideRoot == root and glide.Parent == root then
			return glide
		end
		destroyGlide()
		local attachment = root:FindFirstChild("IceGlideAttachment")
		if attachment == nil or not attachment:IsA("Attachment") then
			local created = Instance.new("Attachment")
			created.Name = "IceGlideAttachment"
			created.Parent = root
			attachment = created
		end
		local constraint = Instance.new("LinearVelocity")
		constraint.Name = GLIDE_NAME
		constraint.Attachment0 = attachment :: Attachment
		constraint.RelativeTo = Enum.ActuatorRelativeTo.World
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		constraint.PrimaryTangentAxis = Vector3.xAxis
		constraint.SecondaryTangentAxis = Vector3.zAxis
		constraint.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		constraint.Enabled = false
		constraint.Parent = root
		glide = constraint
		glideRoot = root
		return constraint
	end

	local function floorIsIce(character: Model, root: BasePart): boolean
		rayParams.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -IceLogic.RAY_LENGTH, 0), rayParams)
		return hit ~= nil and CollectionService:HasTag(hit.Instance, IceLogic.TAG)
	end

	RunService.Stepped:Connect(function(_time: number, dt: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if character == nil or humanoid == nil or root == nil or not character:IsDescendantOf(workspace) then
			destroyGlide()
			return
		end
		if glideRoot ~= nil and glideRoot ~= root then
			destroyGlide() -- 리스폰: 새 캐릭터
		end

		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local usable = humanoid.Health > 0
			and not humanoid.PlatformStand
			and not humanoid.Sit
			and not root.Anchored
			and not SKIP_STATES[humanoid:GetState()]
		if not usable or not IceLogic.isIceMode(grounded, floorIsIce(character, root)) then
			disable()
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local move = humanoid.MoveDirection * humanoid.WalkSpeed
		local nextVelocity = IceLogic.step(
			{ x = velocity.X, z = velocity.Z },
			{ x = move.X, z = move.Z },
			dt,
			humanoid.WalkSpeed
		)
		local constraint = ensureGlide(root)
		constraint.MaxForce = root.AssemblyMass * GLIDE_ACCEL
		constraint.PlaneVelocity = Vector2.new(nextVelocity.x, nextVelocity.z)
		constraint.Enabled = true
	end)
end

return IceController
