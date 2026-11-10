--!strict
-- 다이너마이트 맵 아이템 (m6-12, GDD 6). 누구나 줍는 아이템이고 판정은 전부 서버예요. 스킨과 무관해요(GDD 9.1).
--   유니크 라운드만: 결승 아닌 Race에서 UniqueChance(10%)로 "🧨 다이너마이트 라운드"가 되면(RoundService.modifierOf) 그 라운드에서만,
--   출발하면 방 사람에게 Notice 한 줄. 라운드 중 방마다 Config.Dynamite.FirstDelay초 뒤부터 Interval초마다, 땅에 선 레이서 근처에 하나 떨어뜨려요(방에 MaxPerRoom개까지).
--   PickupRadius 안에 오면 자동으로 주워요(손에 하나만) → Player 속성 HeldItem = "Dynamite"(공격 버튼이 🧨 점화로).
--   AttackInput이 오면 AttackService가 먼저 tryLight를 불러요: 들고 있으면 점화 → DynamiteFuseAt(서버 시각) → Fuse초 뒤 폭발.
--   폭발: 들고 있던 사람 + 반지름 안 레이서. Race 부활 라운드면 출발점으로(RoundService.sendToStart, 낙하와 같은 흐름),
--   아니면(Survival·결승) 크게 튕겨 넘어뜨려요(Knockback). 연출은 같은 방 사람에게 DynamiteFx.
--   라운드가 끝나거나 방을 나가면 바닥 아이템·들고 있음·불붙음을 모두 지워요(터지지 않아요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local DynamiteLogic = require(ReplicatedStorage.Shared.DynamiteLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local Knockback = require(script.Parent.Knockback)
local RoomService = require(script.Parent.RoomService)
local RoundService = require(script.Parent.RoundService)

local TICK = 0.2
local ITEM_NAME = "DynamitePickup"
local HELD = "Dynamite"

type Body = { character: Model, humanoid: Humanoid, root: BasePart }
type FloorItem = { roomId: string, model: Model, position: Vector3, spawnedAt: number }
type Lit = { roomId: string, litAt: number, lastPosition: Vector3 }

local DynamiteService = {}

local fxEvent: RemoteEvent
local noticeEvent: RemoteEvent
local folder: Folder
local rng = Random.new()
local rooms: { [string]: DynamiteLogic.RoomState } = {}
local items: { FloorItem } = {}
local held: { [Player]: string } = {} -- 들고 있는 사람 → 방
local lit: { [Player]: Lit } = {}

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

local function isDown(body: Body): boolean
	local humanoid = body.humanoid
	return humanoid.Health <= 0 or humanoid.PlatformStand or humanoid.WalkSpeed <= 0 or body.root.Anchored
end

local function toVec(v: Vector3): DynamiteLogic.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function clearPlayer(player: Player)
	held[player] = nil
	lit[player] = nil
	if player.Parent then
		player:SetAttribute(Attributes.HeldItem, nil)
		player:SetAttribute(Attributes.DynamiteFuseAt, nil)
	end
end

-- 바닥 아이템 모양: 빨간 막대 셋 + 검은 띠 + 심지 + 불빛 (Anchored, 충돌·쿼리·터치 없음)
local function buildPickup(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = ITEM_NAME
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local base = CFrame.new(position + Vector3.new(0, 1.1, 0))
	local red = Color3.fromRGB(220, 46, 40)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 축(X)을 세워요
	for i, dx in { -0.55, 0, 0.55 } do
		part(
			`Stick{i}`,
			Vector3.new(1.8, 0.6, 0.6),
			base * CFrame.new(dx, 0, if i == 2 then -0.35 else 0.2) * upright,
			red,
			nil,
			Enum.PartType.Cylinder
		)
	end
	part("Band", Vector3.new(1.8, 0.28, 1.25), base, Color3.fromRGB(52, 50, 56), Enum.Material.Metal)
	part("Fuse", Vector3.new(0.12, 0.7, 0.12), base * CFrame.new(0, 1.15, 0), Color3.fromRGB(120, 84, 52))
	local spark = part(
		"Spark",
		Vector3.one * 0.4,
		base * CFrame.new(0, 1.55, 0),
		Color3.fromRGB(255, 220, 90),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 80)
	light.Range = 10
	light.Brightness = 2
	light.Parent = spark
	model.PrimaryPart = spark
	return model
end

local function roomCount(roomId: string): number
	local n = 0
	for _, item in items do
		if item.roomId == roomId then
			n += 1
		end
	end
	for _, r in held do
		if r == roomId then
			n += 1
		end
	end
	for _, l in lit do
		if l.roomId == roomId then
			n += 1
		end
	end
	return n
end

local function sendFx(roomId: string, info: Types.DynamiteFxInfo)
	for _, member in RoomService.getPlayers(roomId) do
		if member.Parent == Players then
			fxEvent:FireClient(member, info)
		end
	end
end

local function explode(carrier: Player, info: Lit, racers: { [Player]: Body })
	lit[carrier] = nil
	if carrier.Parent then
		carrier:SetAttribute(Attributes.DynamiteFuseAt, nil)
	end
	local carrierBody = racers[carrier]
	local center = if carrierBody then carrierBody.root.Position else info.lastPosition
	local list: { DynamiteLogic.Racer } = {}
	local byId: { [number]: Player } = {}
	for player, body in racers do
		byId[player.UserId] = player
		table.insert(list, {
			userId = player.UserId,
			position = toVec(body.root.Position),
			grounded = true,
			holding = false,
			down = player ~= carrier and isDown(body),
		})
	end
	local hits = DynamiteLogic.blastTargets(toVec(center), carrier.UserId, list, Config.Dynamite)
	local anyHome = false
	for _, id in hits do
		local player = byId[id]
		local body = player and racers[player]
		if player == nil or body == nil then
			continue
		end
		if RoundService.sendToStart(player) then
			anyHome = true
		else
			local v = DynamiteLogic.knockFor(toVec(center), toVec(body.root.Position), Config.Dynamite)
			Knockback.apply(body.character, body.humanoid, body.root, Vector3.new(v.x, v.y, v.z), {
				hold = Config.Dynamite.KnockHold,
				stun = Config.Dynamite.Stun,
				exempt = Config.Dynamite.MoveExempt,
			})
		end
	end
	sendFx(info.roomId, {
		carrier = if carrier.Parent then carrier.UserId else nil,
		position = center,
		hits = hits,
		effect = if anyHome then "Home" else "Knock",
	})
end

local function tick()
	local now = os.clock()
	-- 방별 레이서
	local byRoom: { [string]: { [Player]: Body } } = {}
	for _, player in Players:GetPlayers() do
		local roomId = RoundService.activeRoomOf(player)
		local body = roomId and bodyOf(player)
		if roomId and body then
			byRoom[roomId] = byRoom[roomId] or {}
			byRoom[roomId][player] = body
		end
	end

	-- 라운드가 끝난 방·나간 사람 정리 (터지지 않아요)
	for roomId in rooms do
		if byRoom[roomId] == nil then
			rooms[roomId] = nil
		end
	end
	for i = #items, 1, -1 do
		local item = items[i]
		if byRoom[item.roomId] == nil or now - item.spawnedAt >= Config.Dynamite.Lifetime then
			item.model:Destroy()
			table.remove(items, i)
		end
	end
	for player, roomId in held do
		if byRoom[roomId] == nil or byRoom[roomId][player] == nil then
			clearPlayer(player)
		end
	end

	-- 불붙은 것: 위치 기억, 시간이 되면 폭발 (들고 있던 사람이 부활 대기·탈락이면 마지막 자리에서 터져요)
	for player, info in lit do
		local racers = byRoom[info.roomId]
		if racers == nil then
			clearPlayer(player)
			continue
		end
		local body = racers[player]
		if body then
			info.lastPosition = body.root.Position
		end
		if DynamiteLogic.fuseLeft(info.litAt, now, Config.Dynamite) <= 0 then
			explode(player, info, racers)
		end
	end

	if not Config.Dynamite.Enabled then
		return
	end
	for roomId, racers in byRoom do
		-- 유니크 라운드(다이너마이트 라운드)에서만 (사용자 결정 2026-11-10)
		if RoundService.modifierOf(roomId) ~= "Dynamite" then
			continue
		end
		local room = rooms[roomId]
		if room == nil then
			room = DynamiteLogic.newRoom(now)
			rooms[roomId] = room
			for _, member in RoomService.getPlayers(roomId) do
				if member.Parent == Players then
					noticeEvent:FireClient(member, LocalizeLogic.text("round.dynamite.notice"), "info")
				end
			end
		end
		local list: { DynamiteLogic.Racer } = {}
		local byId: { [number]: Player } = {}
		local count = 0
		for player, body in racers do
			count += 1
			byId[player.UserId] = player
			table.insert(list, {
				userId = player.UserId,
				position = toVec(body.root.Position),
				grounded = body.humanoid.FloorMaterial ~= Enum.Material.Air,
				holding = held[player] ~= nil or lit[player] ~= nil,
				down = isDown(body),
			})
		end
		-- 줍기
		for i = #items, 1, -1 do
			local item = items[i]
			if item.roomId ~= roomId then
				continue
			end
			local id = DynamiteLogic.pickupBy({ position = toVec(item.position) }, list, Config.Dynamite)
			local player = id and byId[id]
			if player then
				item.model:Destroy()
				table.remove(items, i)
				held[player] = roomId
				player:SetAttribute(Attributes.HeldItem, HELD)
				for _, r in list do
					if r.userId == id then
						r.holding = true
					end
				end
			end
		end
		-- 떨어뜨리기
		if DynamiteLogic.shouldSpawn(room, now, roomCount(roomId), count, Config.Dynamite) then
			local spot = DynamiteLogic.dropSpot(list, function()
				return rng:NextNumber()
			end, Config.Dynamite)
			if spot then
				room.lastSpawnAt = now
				local position = Vector3.new(spot.x, spot.y - 2.25, spot.z) -- 루트 높이 → 발밑 근처
				local model = buildPickup(position)
				model.Parent = folder
				table.insert(
					items,
					{ roomId = roomId, model = model, position = position + Vector3.new(0, 1.1, 0), spawnedAt = now }
				)
			end
		end
	end
end

-- AttackService가 공격 입력마다 먼저 불러요. 들고 있으면 점화하고 true (공격은 하지 않아요).
function DynamiteService.tryLight(player: Player): boolean
	local roomId = held[player]
	if roomId == nil then
		return false
	end
	if RoundService.activeRoomOf(player) ~= roomId then
		clearPlayer(player)
		return false
	end
	local body = bodyOf(player)
	if body == nil then
		return false
	end
	held[player] = nil
	lit[player] = { roomId = roomId, litAt = os.clock(), lastPosition = body.root.Position }
	player:SetAttribute(Attributes.HeldItem, nil)
	player:SetAttribute(Attributes.DynamiteFuseAt, workspace:GetServerTimeNow() + Config.Dynamite.Fuse)
	return true
end

function DynamiteService.init()
	fxEvent = Remotes.event("DynamiteFx")
	noticeEvent = Remotes.event("Notice")
	folder = Instance.new("Folder")
	folder.Name = "DynamiteItems"
	folder.Parent = Workspace
end

function DynamiteService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		held[player] = nil
		lit[player] = nil
	end)
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

return DynamiteService
