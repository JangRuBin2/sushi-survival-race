--!strict
-- 공격 연출 (m6-08). 서버 AttackFx를 받아 그 자리에 그려요 — 판정(튕김·넘어짐)은 이미 서버가 했어요.
-- 연출 스타일은 공격자 캐릭터의 AppearanceId로 AttackFxLogic.styleFor가 골라요 (스킨 id 분기는 그 표 하나).
--   RiceBurst 하얀 충격파 + 밥알 / Flame 불꽃 고리 + 감아 오르는 불꽃 용 띠 / Storm 회오리 고리 + 물보라 띠
--   StarRibbon(m6-09) 분홍 고리 + 분홍·노랑 별 조각이 번갈아 감아 오르는 리본
--   Missile·ShadowMissile 위로 휘며 맞은 사람을 쫓아가는(매 프레임 대상 위치로 다시 겨눔) 미사일 + 폭발
-- 파츠는 모두 이 클라이언트에만 있는 Anchored·충돌 없음이고, 동시 연출 Config.Attack.FxMaxConcurrent개·
-- 거리 Config.Attack.FxMaxDistance까지만 그려요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttackFxLogic = require(ReplicatedStorage.Shared.AttackFxLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Sfx = require(script.Parent.Parent.Sfx)

local FOLDER_NAME = "AttackFx"
local RING_HEIGHT = 0.4
local BAND_RADIUS = 5
local BAND_HEIGHT = 7

type Updater = (t: number) -> ()

local AttackFxController = {}

local folder: Folder
local active = 0
-- 지금 그리는 연출의 파츠를 담는 폴더 (play가 연출마다 만들고 끝나면 통째로 지워요)
local current: Folder

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function toVec(v: Vector3): AttackFxLogic.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function fromVec(v: AttackFxLogic.Vec3): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent or current
	return p
end

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number)
	-- 연출 폴더보다 오래 남아요 (조각이 다 날아갈 때까지) — 그래서 연출 폴더가 아니라 바깥 폴더에
	local holder = part({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) }, folder)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- 바닥에 퍼지는 고리 (얇은 원기둥, 옆으로 눕힘)
local function ring(origin: Vector3, info: AttackFxLogic.StyleInfo, spinTurns: number): Updater
	local flat = CFrame.new(origin - Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = part({
		Shape = Enum.PartType.Cylinder,
		Color = rgb(info.ring),
		Transparency = 0.25,
		Size = Vector3.new(RING_HEIGHT, 1, 1),
		CFrame = flat,
	})
	return function(t: number)
		local r = math.max(0.5, AttackFxLogic.ringRadius(t, Config.Attack.Radius))
		disc.Size = Vector3.new(RING_HEIGHT, r * 2, r * 2)
		disc.CFrame = flat * CFrame.Angles(t * spinTurns * math.pi * 2, 0, 0)
		disc.Transparency = 0.25 + 0.75 * AttackFxLogic.fade(t)
	end
end

-- 감아 오르는 띠 (불꽃 용 / 회오리). 머리 조각이 가장 크고 밝아요
local function band(origin: Vector3, info: AttackFxLogic.StyleInfo): Updater
	local n = AttackFxLogic.BAND_PIECES
	local pieces: { Part } = {}
	for i = 1, n do
		local scale = 0.6 + 1.4 * (i / n)
		table.insert(
			pieces,
			part({
				Shape = Enum.PartType.Ball,
				Color = rgb(AttackFxLogic.bandColor(info, i, n)),
				Size = Vector3.one * scale,
				Transparency = 0.2,
				CFrame = CFrame.new(origin),
			})
		)
	end
	local center = toVec(origin - Vector3.new(0, 1.5, 0))
	return function(t: number)
		local fade = AttackFxLogic.fade(t)
		for i, piece in pieces do
			local p = AttackFxLogic.helixPoint(center, i, n, t, BAND_RADIUS, BAND_HEIGHT, info.spin)
			piece.CFrame = CFrame.new(fromVec(p))
			piece.Transparency = 0.2 + 0.8 * fade
		end
	end
end

local function rootOf(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- 쫓아가는 미사일: 매 프레임 대상(맞은 사람)의 지금 위치로 끝점을 다시 잡아요 (자율비행 연출)
local function missiles(origin: Vector3, hits: { number }, info: AttackFxLogic.StyleInfo): Updater
	local hitRoots: { BasePart } = {}
	local hitPositions: { AttackFxLogic.Vec3 } = {}
	for _, id in hits do
		local root = rootOf(id)
		if root then
			table.insert(hitRoots, root)
			table.insert(hitPositions, toVec(root.Position))
		end
	end
	local from = toVec(origin + Vector3.new(0, 1.5, 0))
	local targets = AttackFxLogic.missileTargets(toVec(origin), hitPositions, Config.Attack.Radius)
	local list: { { body: Part, tip: Part, target: AttackFxLogic.Vec3, root: BasePart?, exploded: boolean } } = {}
	for i, target in targets do
		local body = part({
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(235, 238, 245),
			Size = Vector3.new(0.45, 0.45, 1.6),
			CFrame = CFrame.new(fromVec(from)),
		})
		local tip = part({ Color = rgb(info.accent), Size = Vector3.new(0.5, 0.5, 0.5), CFrame = body.CFrame })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0.15, 0, 0.8)
		a0.Parent = body
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(-0.15, 0, 0.8)
		a1.Parent = body
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(rgb(info.accent), rgb(info.particle))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = 0.8
		trail.Parent = body
		table.insert(list, { body = body, tip = tip, target = target, root = hitRoots[i], exploded = false })
	end
	local flight = AttackFxLogic.MISSILE_TIME / AttackFxLogic.info("Missile").duration
	return function(t: number)
		local u = math.clamp(t / flight, 0, 1)
		for _, m in list do
			if m.exploded then
				continue
			end
			local root = m.root
			if root and root.Parent then
				m.target = toVec(root.Position)
			end
			local p = AttackFxLogic.missilePoint(from, m.target, u, AttackFxLogic.MISSILE_ARC)
			local ahead = AttackFxLogic.missilePoint(from, m.target, math.min(1, u + 0.05), AttackFxLogic.MISSILE_ARC)
			local pos, next = fromVec(p), fromVec(ahead)
			local cf = if (next - pos).Magnitude > 1e-3 then CFrame.lookAt(pos, next) else CFrame.new(pos)
			m.body.CFrame = cf
			m.tip.CFrame = cf * CFrame.new(0, 0, -0.9)
			if u >= 1 then
				m.exploded = true
				m.body.Transparency = 1
				m.tip.Transparency = 1
				burst(pos, rgb(info.particle), 14, 18, 1.2)
				burst(pos, rgb(info.accent), 6, 8, 2)
			end
		end
	end
end

local function play(info: Types.AttackFxInfo)
	if typeof(info) ~= "table" or typeof(info.position) ~= "Vector3" or type(info.attacker) ~= "number" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - info.position).Magnitude > Config.Attack.FxMaxDistance then
		return
	end
	if active >= Config.Attack.FxMaxConcurrent then
		return
	end
	local hits: { number } = {}
	if type(info.hits) == "table" then
		for _, id in info.hits do
			if type(id) == "number" then
				table.insert(hits, id)
			end
		end
	end

	local attackerRoot = rootOf(info.attacker)
	local character = attackerRoot and attackerRoot.Parent
	local skinId = character and character:GetAttribute(Attributes.AppearanceId)
	local style = AttackFxLogic.styleFor(skinId)
	local styleInfo = AttackFxLogic.info(style)
	local origin = info.position

	current = Instance.new("Folder")
	current.Name = "Attack"
	current.Parent = folder
	Sfx.play("Attack", origin)
	burst(origin, rgb(styleInfo.particle), if styleInfo.missiles then 8 else 22, 22, 0.8)

	local updaters: { Updater } = { ring(origin, styleInfo, if styleInfo.ringSpin then styleInfo.spin else 0) }
	if styleInfo.band then
		table.insert(updaters, band(origin, styleInfo))
	end
	if styleInfo.missiles then
		table.insert(updaters, missiles(origin, hits, styleInfo))
	end

	active += 1
	local mine = current
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / styleInfo.duration
		for _, update in updaters do
			update(math.min(t, 1))
		end
		if t >= 1 then
			connection:Disconnect()
			active -= 1
			mine:Destroy()
		end
	end)
end

function AttackFxController.start(_gui: Instance)
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	Remotes.event("AttackFx").OnClientEvent:Connect(play)
end

return AttackFxController
