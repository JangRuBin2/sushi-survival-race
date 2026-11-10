--!strict
-- 공격 판정 (m6-08, GDD 6). 누가 맞았는지는 서버만 정해요.
--   AttackInput(): 클라이언트가 공격 버튼을 누르면 보내요(인자 없음). 서버가 요청 간격·레이서 여부·넘어짐·쿨다운을 보고
--   AttackLogic.pickTargets로 같은 방 레이서 중 반지름 안을 골라 바깥쪽으로 튕기고(LinearVelocity 잠깐) 넘어뜨려요
--   (PlatformStand Config.Attack.Stun초 — 클라이언트 CharacterFxController가 "@_@"). 넘어지면 잡기도 풀려요(GrabService.isDown).
--   모든 플레이어가 같은 공격이에요 — 스킨은 연출만 바꿔요(클라이언트 AttackFxController, GDD 9.1). 서버는 스킨을 보지 않아요.
--   쿨다운이 바뀌면 Player 속성 Attributes.AttackReadyAt(서버 시각)을 달아요 — 버튼 표시용, 판단은 AttackLogic 북으로만.
--   AttackFx는 같은 방 사람에게만 보내요.
--   m6-12: 다이너마이트를 들고 있으면 같은 입력이 점화예요(DynamiteService.tryLight). 넉백은 공용 Knockback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackLogic = require(ReplicatedStorage.Shared.AttackLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local DynamiteService = require(script.Parent.DynamiteService)
local Knockback = require(script.Parent.Knockback)
local RoomService = require(script.Parent.RoomService)
local RoundService = require(script.Parent.RoundService)

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
	Knockback.apply(body.character, body.humanoid, body.root, velocity, {
		hold = Config.Attack.KnockHold,
		stun = Config.Attack.Stun,
		exempt = Config.Attack.MoveExempt,
	})
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
	-- 다이너마이트를 들고 있으면 공격 대신 점화 (m6-12) — 공격 쿨다운은 쓰지 않아요
	if DynamiteService.tryLight(player) then
		return
	end
	attack(player)
end

local function onPlayerRemoving(player: Player)
	AttackLogic.removePlayer(book, player.UserId)
	lastPress[player] = nil
	local body = bodyOf(player)
	if body then
		Knockback.forget(body.humanoid)
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
