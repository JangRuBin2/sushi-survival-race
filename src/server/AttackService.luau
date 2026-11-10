--!strict
-- 공격 판정 (m6-08, GDD 6). 누가 맞았는지는 서버만 정해요.
--   AttackInput(): 클라이언트가 공격 버튼을 누르면 보내요(인자 없음). 서버가 요청 간격·레이서 여부·넘어짐·쿨다운을 보고
--   AttackLogic.pickTargets로 같은 방 레이서 중 반지름 안을 골라 바깥쪽으로 튕기고(LinearVelocity 잠깐) 넘어뜨려요
--   (PlatformStand Config.Attack.Stun초 — 클라이언트 CharacterFxController가 "@_@"). 넘어지면 잡기도 풀려요(GrabService.isDown).
--   모든 플레이어가 같은 공격이에요 — 스킨은 연출만 바꿔요(클라이언트 AttackFxController, GDD 9.1). 서버는 스킨을 보지 않아요.
--   쿨다운이 바뀌면 Player 속성 Attributes.AttackReadyAt(서버 시각)을 달아요 — 버튼 표시용, 판단은 AttackLogic 북으로만.
--   AttackFx는 같은 방 사람에게만 보내요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackLogic = require(ReplicatedStorage.Shared.AttackLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MoveExempt = require(ReplicatedStorage.Shared.MoveExempt)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RoomService = require(script.Parent.RoomService)
local RoundService = require(script.Parent.RoundService)

local PUSH_NAME = "AttackKnock"
local ATTACHMENT_NAME = "AttackKnockAttachment"

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
}

local AttackService = {}

local attackInputEvent: RemoteEvent
local attackFxEvent: RemoteEvent
local book = AttackLogic.newBook()
local lastPress: { [Player]: number } = {}
-- 넘어뜨린 Humanoid → 일으킬 시각. 그 사이 다른 공격·맵이 다시 넘어뜨리면 늦은 쪽만 일으켜요.
local standUntil: { [Humanoid]: number } = {}

local function bodyOf(player: Player): Body?
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root }
end

-- 넘어짐·젓가락에 잡힘·고정·죽음 (공격할 수도, 맞을 수도 없는 상태 — GrabService와 같은 기준)
local function isDown(body: Body): boolean
	local humanoid = body.humanoid
	return humanoid.Health <= 0 or humanoid.PlatformStand or humanoid.WalkSpeed <= 0 or body.root.Anchored
end

local function toVec(v: Vector3): AttackLogic.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function knock(body: Body, velocity: Vector3)
	local root = body.root
	MoveExempt.mark(body.character, Config.Attack.MoveExempt)
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
	task.delay(Config.Attack.KnockHold, function()
		if push.Parent then
			push:Destroy()
		end
	end)

	local humanoid = body.humanoid
	humanoid.PlatformStand = true
	local untilAt = os.clock() + Config.Attack.Stun
	standUntil[humanoid] = untilAt
	task.delay(Config.Attack.Stun, function()
		if standUntil[humanoid] ~= untilAt then
			return
		end
		standUntil[humanoid] = nil
		-- 그 사이 탈락 고정(Anchored + PlatformStand)이 됐으면 손대지 않아요
		if humanoid.Parent and not root.Anchored then
			humanoid.PlatformStand = false
		end
	end)
end

local function sendFx(roomId: string, info: Types.AttackFxInfo)
	for _, member in RoomService.getPlayers(roomId) do
		if member.Parent == Players then
			attackFxEvent:FireClient(member, info)
		end
	end
end

local function attack(player: Player)
	local now = os.clock()
	if not AttackLogic.canAttack(book, player.UserId, now) then
		return
	end
	local roomId = RoundService.activeRoomOf(player)
	if roomId == nil then
		return
	end
	local body = bodyOf(player)
	if body == nil or isDown(body) then
		return
	end

	local candidates: { AttackLogic.Candidate } = {}
	local bodies: { [number]: Body } = {}
	for _, other in Players:GetPlayers() do
		if other == player or RoundService.activeRoomOf(other) ~= roomId then
			continue
		end
		local otherBody = bodyOf(other)
		if otherBody == nil then
			continue
		end
		bodies[other.UserId] = otherBody
		table.insert(candidates, {
			userId = other.UserId,
			position = toVec(otherBody.root.Position),
			alive = otherBody.humanoid.Health > 0,
			down = isDown(otherBody),
			immune = AttackLogic.isImmune(book, other.UserId, now),
		})
	end

	local attacker: AttackLogic.Attacker = {
		userId = player.UserId,
		position = toVec(body.root.Position),
		look = toVec(body.root.CFrame.LookVector),
	}
	local hits = AttackLogic.pickTargets(attacker, candidates, Config.Attack)
	if not AttackLogic.record(book, player.UserId, hits, now, Config.Attack) then
		return
	end
	player:SetAttribute(Attributes.AttackReadyAt, workspace:GetServerTimeNow() + Config.Attack.Cooldown)

	for _, id in hits do
		local target = bodies[id]
		if target then
			local v = AttackLogic.knockFor(attacker, toVec(target.root.Position), Config.Attack)
			knock(target, Vector3.new(v.x, v.y, v.z))
		end
	end
	sendFx(roomId, { attacker = player.UserId, position = body.root.Position, hits = hits })
end

local function onInput(player: Player, ...: unknown)
	if select("#", ...) > 0 then
		return -- 인자 없는 요청만
	end
	local now = os.clock()
	local last = lastPress[player]
	if last ~= nil and now - last < Config.Attack.InputMinInterval then
		return
	end
	lastPress[player] = now
	attack(player)
end

local function onPlayerRemoving(player: Player)
	AttackLogic.removePlayer(book, player.UserId)
	lastPress[player] = nil
	local body = bodyOf(player)
	if body then
		standUntil[body.humanoid] = nil
	end
end

function AttackService.init()
	attackInputEvent = Remotes.event("AttackInput")
	attackFxEvent = Remotes.event("AttackFx")
end

function AttackService.start()
	attackInputEvent.OnServerEvent:Connect(onInput)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return AttackService
