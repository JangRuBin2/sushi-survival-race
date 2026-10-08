--!strict
-- 다이브 입력과 움직임 (m3-06). 판정 없는 클라이언트 물리 이동이라 서버·리모트·속성은 쓰지 않아요.
--   입력: Shift / E / 게임패드 X / 모바일 다이브 버튼 (DiveButton)
--   조건·속도·상태 흐름은 Shared.DiveLogic(순수)이 정하고, 여기서는 캐릭터에 적용만 해요.
--   엎드린 자세는 HumanoidRootPart 기울기(로컬 AlignOrientation)라 다른 사람 화면에도 복제돼요.
--   Humanoid.PlatformStand·WalkSpeed·JumpPower는 서버 값이라 건드리지 않아요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DiveLogic = require(ReplicatedStorage.Shared.DiveLogic)
local Sfx = require(script.Parent.Parent.Sfx)
local DiveButton = require(script.Parent.DiveButton)
local GrabController = require(script.Parent.GrabController)

local DiveController = {}

local DIVE_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.ButtonX] = true,
}

local PRONE_PITCH = -math.rad(Config.Dive.ProneAngle) -- 앞으로 엎드린 각도
local STUN_BIND_NAME = "DiveStun"
-- m3-07 잡기 감속(Input + 1)보다 나중이라 경직이 이겨요
local STUN_PRIORITY = Enum.RenderPriority.Input.Value + 2

-- 다이브 중에 꺼 두는 상태: 기울인 자세 때문에 넘어짐/일어서기로 빠지지 않게
local TIP_STATES = {
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp,
}

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
}

function DiveController.start(_gui: Instance)
	local player = Players.LocalPlayer

	local state = DiveLogic.newState()
	local flightVelocity: Vector3? = nil -- Flying 동안 유지하는 수평 속도
	local facing = Vector3.new(0, 0, -1) -- 다이브 방향 (수평, 정규화)
	local diving: Body? = nil -- 자세를 바꿔 둔 캐릭터
	local align: AlignOrientation? = nil
	local attachment: Attachment? = nil
	local stunBound = false
	local jumpDisabled: Humanoid? = nil
	local jumpWasEnabled = true -- 경직 전 Jumping 상태 (끝나면 이 값으로 되돌려요, m3-06 QA B4)
	-- 다이브 전 AutoRotate·넘어짐 상태 (끝나면 원래 값으로 되돌려요 — 다른 코드가 꺼 둔 걸 켜 버리지 않게)
	local savedAutoRotate = true
	local savedTipStates: { [Enum.HumanoidStateType]: boolean } = {}

	local function currentBody(): Body?
		local character = player.Character
		if not character then
			return nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not humanoid or not root or not character:IsDescendantOf(workspace) then
			return nil
		end
		return { character = character, humanoid = humanoid, root = root }
	end

	local function isGrounded(humanoid: Humanoid): boolean
		return humanoid.FloorMaterial ~= Enum.Material.Air
	end

	-- 카메라가 내 캐릭터를 따라가고 있지 않으면 (관전·연출) 다이브하지 않아요
	local function isSpectating(humanoid: Humanoid): boolean
		local camera = workspace.CurrentCamera
		if not camera then
			return true
		end
		return camera.CameraSubject ~= humanoid or camera.CameraType == Enum.CameraType.Scriptable
	end

	local function setStun(body: Body?, on: boolean)
		if on and not stunBound then
			stunBound = true
			RunService:BindToRenderStep(STUN_BIND_NAME, STUN_PRIORITY, function()
				local current = currentBody()
				if current then
					current.humanoid:Move(Vector3.zero)
				end
			end)
		elseif not on and stunBound then
			stunBound = false
			RunService:UnbindFromRenderStep(STUN_BIND_NAME)
		end

		if on and body then
			if jumpDisabled ~= body.humanoid then
				jumpWasEnabled = body.humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
			end
			jumpDisabled = body.humanoid
			body.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		elseif not on and jumpDisabled then
			if jumpDisabled.Parent then
				jumpDisabled:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpWasEnabled)
			end
			jumpDisabled = nil
		end
	end

	local function prone(body: Body, direction: Vector3)
		diving = body
		savedAutoRotate = body.humanoid.AutoRotate
		body.humanoid.AutoRotate = false
		for _, stateType in TIP_STATES do
			savedTipStates[stateType] = body.humanoid:GetStateEnabled(stateType)
			body.humanoid:SetStateEnabled(stateType, false)
		end

		local att = Instance.new("Attachment")
		att.Name = "DiveAttachment"
		att.Parent = body.root
		attachment = att

		local orientation = Instance.new("AlignOrientation")
		orientation.Name = "DiveAlign"
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = att
		orientation.RigidityEnabled = true
		orientation.CFrame = CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(PRONE_PITCH, 0, 0)
		orientation.Parent = body.root
		align = orientation
	end

	-- 자세를 바로 세워요. snap이면 루트를 수평 방향으로 곧바로 돌려 놓아요.
	local function standUp(snap: boolean)
		if align then
			align:Destroy()
			align = nil
		end
		if attachment then
			attachment:Destroy()
			attachment = nil
		end
		local body = diving
		diving = nil
		if not body or not body.humanoid.Parent then
			return
		end
		body.humanoid.AutoRotate = savedAutoRotate
		for _, stateType in TIP_STATES do
			local enabled = savedTipStates[stateType]
			body.humanoid:SetStateEnabled(stateType, if enabled == nil then true else enabled)
		end
		table.clear(savedTipStates)
		local root = body.root
		-- 서버가 고정·넘어뜨린 상태면 자세는 서버·m3-02 연출 몫이라 손대지 않아요
		if snap and root.Parent and not root.Anchored and not body.humanoid.PlatformStand then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
		end
	end

	local function finish(snap: boolean)
		flightVelocity = nil
		setStun(nil, false)
		standUp(snap)
	end

	local function tryDive()
		local now = os.clock()
		local body = currentBody()
		local canDive = DiveLogic.canDive({
			hasCharacter = body ~= nil,
			health = if body then body.humanoid.Health else 0,
			anchored = if body then body.root.Anchored else true,
			sitting = if body then body.humanoid.Sit else false,
			walkSpeed = if body then body.humanoid.WalkSpeed else 0,
			platformStand = if body then body.humanoid.PlatformStand else false,
			spectating = if body then isSpectating(body.humanoid) else true,
			state = state,
			now = now,
		})
		if not canDive or not body then
			return
		end

		local humanoid, root = body.humanoid, body.root
		local grounded = isGrounded(humanoid)
		local move = humanoid.MoveDirection
		local look = root.CFrame.LookVector
		local velocity = root.AssemblyLinearVelocity
		local launch = DiveLogic.launch({
			moveX = move.X,
			moveZ = move.Z,
			lookX = look.X,
			lookZ = look.Z,
			walkSpeed = humanoid.WalkSpeed,
			grounded = grounded,
			jumpPower = humanoid.JumpPower,
			vy = velocity.Y,
		})

		state = DiveLogic.begin(state, now)
		local horizontal = Vector3.new(launch.vx, 0, launch.vz)
		if horizontal.Magnitude > 1e-3 then
			facing = horizontal.Unit
		else
			facing = Vector3.new(look.X, 0, look.Z).Unit
		end
		flightVelocity = horizontal

		prone(body, facing)
		GrabController.cancelHold() -- 잡는 중에 다이브하면 놓아요 (m3-09 기본값)
		root.AssemblyLinearVelocity = Vector3.new(launch.vx, launch.vy, launch.vz)
		if grounded and launch.vy > 0 then
			-- 바닥에 붙잡혀 있지 않게 공중 상태로 보내요 (Jumping은 JumpPower를 덮어써서 쓰지 않아요)
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		Sfx.play("Dive", root)
	end

	local button = DiveButton.create(tryDive)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if DIVE_KEYS[input.KeyCode] then
			tryDive()
		end
	end)

	-- 물리 계산 전에 상태를 진행하고, 날아가는 동안 수평 속도를 유지해요
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		if button then
			button:setCooldown(DiveLogic.cooldownLeft(state, now) / Config.Dive.Cooldown)
		end
		if state.phase == "Ready" then
			return
		end

		local body = currentBody()
		local interrupted = true
		local grounded = false
		if body and diving and body.character == diving.character then
			local humanoid = body.humanoid
			interrupted = humanoid.Health <= 0
				or humanoid.PlatformStand
				or humanoid.WalkSpeed <= 0
				or humanoid.Sit
				or body.root.Anchored
			grounded = isGrounded(humanoid)
		end

		local previous = state.phase
		state = DiveLogic.step(state, now, grounded, interrupted)

		if state.phase == "Ready" then
			finish(true)
			return
		end
		if previous == "Flying" and state.phase == "Stunned" and body then
			flightVelocity = nil
			setStun(body, true)
			Sfx.play("DiveLand", body.root)
			return
		end
		if state.phase == "Flying" and body and flightVelocity then
			local current = body.root.AssemblyLinearVelocity
			body.root.AssemblyLinearVelocity = Vector3.new(flightVelocity.X, current.Y, flightVelocity.Z)
		end
	end)

	-- 리스폰하면 이전 다이브는 끝내요 (쿨다운은 그대로)
	player.CharacterAdded:Connect(function()
		if state.phase ~= "Ready" then
			state = DiveLogic.step(state, os.clock(), false, true)
		end
		finish(false)
	end)
end

return DiveController
