--!strict
-- 다이너마이트 연출 (m6-12). 판정은 서버 DynamiteService가 해요 — 여기는 보이는 것·소리만.
--   들고 있음: Player 속성 HeldItem = "Dynamite"인 사람 머리 위에 작은 "🧨" (내가 주우면 소리 DynamitePickup)
--   불붙음: DynamiteFuseAt(서버 시각)인 사람 머리 위에 큰 "🧨 7" 카운트다운(마지막 3초 빨갛게 콩닥) + 1초마다 DynamiteFuse
--   폭발: DynamiteFx → 그 자리에 커지는 불덩이 + 고리 + 조각, 소리 DynamiteBoom.
--     들고 있던 사람이 다이너마이트 스시를 입었으면 더 크고 고리가 둘(스킨은 연출만, GDD 9.1 — AttackFxLogic.styleFor == "Kaboom")
-- 파츠·글씨는 모두 이 클라이언트 전용이에요. 머리 위 표시는 캐릭터 아래에 넣지 않고 Adornee로만 붙여요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttackFxLogic = require(ReplicatedStorage.Shared.AttackFxLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Sfx = require(script.Parent.Parent.Sfx)

local DynamiteFxController = {}

local localPlayer = Players.LocalPlayer
local folder: Folder
local tags: { [Player]: { gui: BillboardGui, label: TextLabel, root: BasePart } } = {}
local lastBeep: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function removeTag(player: Player)
	local tag = tags[player]
	if tag then
		tag.gui:Destroy()
		tags[player] = nil
	end
	lastBeep[player] = nil
end

local function tagFor(player: Player, root: BasePart): (BillboardGui, TextLabel)
	local tag = tags[player]
	if tag and tag.root == root and tag.gui.Parent then
		return tag.gui, tag.label
	end
	removeTag(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DynamiteTag"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(120, 48)
	gui.StudsOffset = Vector3.new(0, 6.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false -- 숫자·그림 문자만
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.1
	label.Parent = gui
	gui.Parent = folder
	tags[player] = { gui = gui, label = label, root = root }
	return gui, label
end

local function updateTags()
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local fuseAt = player:GetAttribute(Attributes.DynamiteFuseAt)
		local holding = player:GetAttribute(Attributes.HeldItem) == "Dynamite"
		if root == nil or (type(fuseAt) ~= "number" and not holding) then
			removeTag(player)
			continue
		end
		local gui, label = tagFor(player, root)
		if type(fuseAt) == "number" then
			local left = math.max(0, fuseAt - now)
			local seconds = math.ceil(left)
			label.Text = `🧨 {seconds}`
			local urgent = left <= 3
			label.TextColor3 = if urgent then Color3.fromRGB(255, 70, 60) else Color3.fromRGB(255, 220, 90)
			local pulse = if urgent then 1 + 0.15 * math.abs(math.sin(left * math.pi * 3)) else 1
			gui.Size = UDim2.fromOffset(math.floor(120 * pulse), math.floor(48 * pulse))
			if lastBeep[player] ~= seconds then
				lastBeep[player] = seconds
				Sfx.play("DynamiteFuse", root)
			end
		else
			label.Text = "🧨"
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			gui.Size = UDim2.fromOffset(60, 34)
		end
	end
	for player in tags do
		if player.Parent ~= Players then
			removeTag(player)
		end
	end
end

local function ball(position: Vector3, color: Color3, size: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(position)
	p.Parent = folder
	return p
end

local function explosion(info: Types.DynamiteFxInfo)
	if typeof(info) ~= "table" or typeof(info.position) ~= "Vector3" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - info.position).Magnitude > Config.Dynamite.FxMaxDistance then
		return
	end
	local carrier = if type(info.carrier) == "number" then Players:GetPlayerByUserId(info.carrier) else nil
	local character = carrier and carrier.Character
	local skin = character and character:GetAttribute(Attributes.AppearanceId)
	local fancy = AttackFxLogic.styleFor(skin) == "Kaboom" -- 다이너마이트 스시: 연출만 더 화려하게
	local radius = Config.Dynamite.Radius
	local position = info.position
	Sfx.play("DynamiteBoom", position)

	local fireball = ball(position, Color3.fromRGB(255, 170, 50), 2)
	local core = ball(position, Color3.fromRGB(255, 245, 190), 1.2)
	local grow = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local scale = if fancy then 1.35 else 1
	TweenService:Create(fireball, grow, { Size = Vector3.one * radius * 1.6 * scale, Transparency = 0.35 }):Play()
	TweenService:Create(core, grow, { Size = Vector3.one * radius * 0.9 * scale }):Play()
	task.delay(0.35, function()
		local fadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(fireball, fadeInfo, { Transparency = 1, Color = Color3.fromRGB(90, 80, 80) }):Play()
		TweenService:Create(core, fadeInfo, { Transparency = 1 }):Play()
	end)
	task.delay(0.85, function()
		fireball:Destroy()
		core:Destroy()
	end)

	-- 바닥 고리 (다이너마이트 스시는 둘)
	for k = 1, if fancy then 2 else 1 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = if k == 1 then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(255, 235, 120)
		ring.Transparency = 0.2
		ring.Size = Vector3.new(0.4, 2, 2)
		ring.CFrame = CFrame.new(position - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = folder
		local r = radius * 2 * (if k == 1 then 1.1 else 1.5)
		local tween = TweenService:Create(
			ring,
			TweenInfo.new(0.5 + 0.15 * k, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.4, r, r), Transparency = 1 }
		)
		tween:Play()
		task.delay(0.8, function()
			ring:Destroy()
		end)
	end

	-- 조각
	local holder = ball(position, Color3.new(1, 1, 1), 0.2)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 110, 110))
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(25, 45)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(if fancy then 60 else 36)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

function DynamiteFxController.start(_gui: Instance)
	folder = Instance.new("Folder")
	folder.Name = "DynamiteFx"
	folder.Parent = Workspace
	Remotes.event("DynamiteFx").OnClientEvent:Connect(explosion)

	local wasHolding = false
	RunService.Heartbeat:Connect(function()
		updateTags()
		local holding = localPlayer:GetAttribute(Attributes.HeldItem) == "Dynamite"
		if holding and not wasHolding then
			Sfx.play("DynamitePickup", rootOf(localPlayer))
		end
		wasHolding = holding
	end)
end

return DynamiteFxController
