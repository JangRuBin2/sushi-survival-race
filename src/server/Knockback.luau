--!strict
-- 서버 넉백 한 번 (m6-08 공격·m6-12 다이너마이트가 같이 써요): 이동 감시 면제 → LinearVelocity를 hold초 → 넘어짐(PlatformStand) stun초.
-- 같은 사람을 겹쳐 넘어뜨리면 늦은 쪽만 일으켜요. 그 사이 탈락 고정(Anchored)이 되면 일으키지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveExempt = require(ReplicatedStorage.Shared.MoveExempt)

local PUSH_NAME = "KnockbackPush"
local ATTACHMENT_NAME = "KnockbackAttachment"

local Knockback = {}

local standUntil: { [Humanoid]: number } = {}

export type Options = { hold: number, stun: number, exempt: number }

function Knockback.apply(character: Model, humanoid: Humanoid, root: BasePart, velocity: Vector3, options: Options)
	MoveExempt.mark(character, options.exempt)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = ATTACHMENT_NAME
		created.Parent = root
		attachment = created
	end
	local old = root:FindFirstChild(PUSH_NAME)
	if old then
		old:Destroy()
	end
	local push = Instance.new("LinearVelocity")
	push.Name = PUSH_NAME
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	task.delay(options.hold, function()
		if push.Parent then
			push:Destroy()
		end
	end)

	humanoid.PlatformStand = true
	local untilAt = os.clock() + options.stun
	if (standUntil[humanoid] or 0) > untilAt then
		return -- 이미 더 길게 넘어져 있어요
	end
	standUntil[humanoid] = untilAt
	task.delay(options.stun, function()
		if standUntil[humanoid] ~= untilAt then
			return
		end
		standUntil[humanoid] = nil
		if humanoid.Parent and not root.Anchored then
			humanoid.PlatformStand = false
		end
	end)
end

function Knockback.forget(humanoid: Humanoid)
	standUntil[humanoid] = nil
end

return Knockback
