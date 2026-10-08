--!strict
-- 잡기 판정 (m3-07). 누가 누구를 잡았는지는 서버만 정해요.
--   GrabInput(holding: boolean): 클라이언트가 버튼을 누르면 true, 떼면 false.
--   누르고 있는 동안 0.1초마다 대상을 찾아(GrabLogic.pickTarget) 잡고, 잡힌 동안 0.1초마다
--   끝낼지(GrabLogic.shouldEnd) 봐요. 잡힌 동안 두 캐릭터에 Attributes.GrabbedBy/GrabbingUserId를 달아요.
--   감속은 각 클라이언트가 자기 이동 입력을 줄여서 해요 — 서버는 WalkSpeed를 건드리지 않아요.
--   잡을 수 있는 건 출발한 라운드에서 같은 방(RoundService.activeRoomOf) 레이서끼리만이에요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local GrabLogic = require(ReplicatedStorage.Shared.GrabLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundService = require(script.Parent.RoundService)

local TICK = 0.1

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
}

type Active = {
	roomId: string,
	grabberCharacter: Model,
	targetCharacter: Model,
	target: Player,
}

local GrabService = {}

local grabInputEvent: RemoteEvent
local book = GrabLogic.newBook()
local holding: { [Player]: boolean } = {}
-- 버튼을 새로 누른 뒤 아직 잡기를 하지 않았으면 true. 한 번 잡기가 끝나면 다시 눌러야 해요.
local armed: { [Player]: boolean } = {}
local lastPress: { [Player]: number } = {}
local active: { [Player]: Active } = {} -- 잡는 사람 → 잡기 정보

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

-- 넘어짐·젓가락에 잡힘·고정·죽음 (잡을 수도, 잡힐 수도 없는 상태)
local function isDown(body: Body): boolean
	local humanoid = body.humanoid
	return humanoid.Health <= 0 or humanoid.PlatformStand or humanoid.WalkSpeed <= 0 or body.root.Anchored
end

local function toVec(v: Vector3): GrabLogic.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function clearAttribute(character: Model, name: string, expected: number)
	if character:GetAttribute(name) == expected then
		character:SetAttribute(name, nil)
	end
end

local function endGrab(grabber: Player, now: number)
	local info = active[grabber]
	active[grabber] = nil
	armed[grabber] = false
	GrabLogic.finish(book, grabber.UserId, now, Config.Grab)
	if info then
		clearAttribute(info.grabberCharacter, Attributes.GrabbingUserId, info.target.UserId)
		clearAttribute(info.targetCharacter, Attributes.GrabbedBy, grabber.UserId)
	end
end

local function playerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function updateActive(grabber: Player, info: Active, now: number)
	local grab = GrabLogic.grabOf(book, grabber.UserId)
	local grabberBody = bodyOf(grabber)
	local targetBody = bodyOf(info.target)
	local grabberOk = grabberBody ~= nil and grabberBody.character == info.grabberCharacter
	local targetOk = targetBody ~= nil and targetBody.character == info.targetCharacter
	local distance = math.huge
	if grabberBody and targetBody then
		distance = (grabberBody.root.Position - targetBody.root.Position).Magnitude
	end
	local finished = grab == nil
		or GrabLogic.shouldEnd({
			holding = holding[grabber] == true,
			elapsed = now - grab.startedAt,
			distance = distance,
			grabberRacing = RoundService.activeRoomOf(grabber) == info.roomId,
			targetRacing = RoundService.activeRoomOf(info.target) == info.roomId,
			grabberDown = not grabberOk or isDown(grabberBody :: Body),
			targetDown = not targetOk or isDown(targetBody :: Body),
		}, Config.Grab)
	if finished then
		endGrab(grabber, now)
	end
end

local function tryStart(grabber: Player, now: number)
	if not GrabLogic.canStart(book, grabber.UserId, now) then
		return
	end
	local roomId = RoundService.activeRoomOf(grabber)
	if roomId == nil then
		return
	end
	local body = bodyOf(grabber)
	if body == nil or isDown(body) then
		return
	end

	local candidates: { GrabLogic.Candidate } = {}
	local bodies: { [number]: Body } = {}
	for _, other in Players:GetPlayers() do
		if other == grabber or RoundService.activeRoomOf(other) ~= roomId then
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
			grabbed = GrabLogic.isGrabbed(book, other.UserId),
			immune = GrabLogic.isImmune(book, other.UserId, now),
		})
	end

	local targetId = GrabLogic.pickTarget({
		userId = grabber.UserId,
		position = toVec(body.root.Position),
		look = toVec(body.root.CFrame.LookVector),
	}, candidates, Config.Grab)
	if targetId == nil then
		return
	end
	local target = playerByUserId(targetId)
	local targetBody = bodies[targetId]
	if target == nil or targetBody == nil or not GrabLogic.begin(book, grabber.UserId, targetId, now) then
		return
	end

	armed[grabber] = false
	active[grabber] = {
		roomId = roomId,
		grabberCharacter = body.character,
		targetCharacter = targetBody.character,
		target = target,
	}
	body.character:SetAttribute(Attributes.GrabbingUserId, targetId)
	targetBody.character:SetAttribute(Attributes.GrabbedBy, grabber.UserId)
end

local function tick()
	local now = os.clock()
	for grabber, info in active do
		updateActive(grabber, info, now)
	end
	for player, isHolding in holding do
		if isHolding and armed[player] and active[player] == nil then
			tryStart(player, now)
		end
	end
end

local function onInput(player: Player, value: unknown)
	if typeof(value) ~= "boolean" then
		return
	end
	if value then
		local now = os.clock()
		local last = lastPress[player]
		if last ~= nil and now - last < Config.Grab.InputMinInterval then
			return
		end
		lastPress[player] = now
		if not holding[player] then
			holding[player] = true
			armed[player] = true
		end
	else
		-- 놓기는 항상 처리해요 (씹히지 않게)
		holding[player] = nil
		armed[player] = nil
		if active[player] then
			endGrab(player, os.clock())
		end
	end
end

local function onPlayerRemoving(player: Player)
	local now = os.clock()
	if active[player] then
		endGrab(player, now)
	end
	for grabber, info in active do
		if info.target == player then
			endGrab(grabber, now)
		end
	end
	GrabLogic.removePlayer(book, player.UserId, now, Config.Grab)
	holding[player] = nil
	armed[player] = nil
	lastPress[player] = nil
end

function GrabService.init()
	grabInputEvent = Remotes.event("GrabInput")
end

function GrabService.start()
	grabInputEvent.OnServerEvent:Connect(onInput)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		tick()
	end)
end

return GrabService
