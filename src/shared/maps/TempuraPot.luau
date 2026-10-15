--!strict
-- Survival 맵 "튀김 냄비 탈출" (m5-05, GDD 5.3 "튀김 기름 점프"). 거대한 튀김 냄비 속에서 기름이 차올라요.
-- 가운데 튀김 바구니(출발 판)에서 둘레의 튀김 발판(새우·고구마·깻잎, 고정)을 밟고 나선을 따라 위로 올라가야
-- 살아요. 발이 기름보다 낮아지면 "튀겨짐" 탈락. 10초부터는 서 있는 레이서 한 명의 발밑에 주황 원이 뜨고,
-- 1.2초 뒤 기름이 솟구쳐 원 안 레이서를 바깥으로 밀어 넘어뜨려요. 23·27·31층은 60초까지 잠기지 않는
-- 안전 구역(좁아서 자리싸움). m5-40: 시간 제한 75초, 60초부터 서든데스 — 기름 상한 22 → 25(23층이 약 63.5초에
-- 잠기고 27·31층은 75초까지 안전), 튀는 기름 1.2초 간격. 결승선은 없고 통과자는 RoundService가 정해요
-- (남은 인원 ≤ 목표 또는 시간 종료).
--
-- 치수·발판 배치는 TempuraPotLayout, 기름 높이·튀김 판정·튀는 기름 일정·넉백·경로 계산은 TempuraPotLogic —
-- 둘 다 순수 로직이고 tests/map-tempura-pot.spec.luau가 확인해요. 장식은 TempuraPotArt → MapKit.buildDecor.
-- 발판·바구니 파츠는 태그 "TempuraRaft" + Attribute "RaftKey"(Layout의 key), 기름 표면은 태그 "HotOil"
-- (보여 주기만 — 판정은 숫자 Logic.oilHeight로 해요). start는 ctx.model 하위 태그 파츠만 찾아요 (M1 B10 (A)).
-- 넉백은 SoySwampHazards.launch와 같은 방식(LinearVelocity를 짧게 걸고 그 뒤는 포물선) + PlatformStand 1초,
-- MoveExempt.mark 1.5초. 상태(서 있는 발판, 쿨다운)는 start 지역 변수에 둬서 여러 방이 섞이지 않아요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.TempuraPotArt)
local Layout = require(script.Parent.TempuraPotLayout)
local Logic = require(script.Parent.TempuraPotLogic)
local MapKit = require(script.Parent.MapKit)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "tempura-pot"
local RAFT_TAG = "TempuraRaft"
local OIL_TAG = "HotOil"
local SPLASH_TAG = "OilSplash"
local OIL_NAME = "Oil"
local OIL_FOLLOWERS = "OilFollowers"
local OIL_THICKNESS = 0.4
local BASKET_THICKNESS = 2
local POT_FLOOR_THICKNESS = 2
local PROBE_LENGTH = 4.5 -- 루트 중심 → 발바닥(약 3)보다 길어서 서 있을 때만 닿아요 (HotPlate와 같은 관례)
local WARN_HEIGHT = 0.12 -- 경고 원을 윗면 위로 이만큼 띄워요 (z-fighting 방지)

-- Color3는 Roblox API라 함수 안에서만 만들어요 (모듈 최상위에서 만들면 Lune require가 실패해요).
local function color3(rgb: MapKitLogic.RGB): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function ghost(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- 세운 원기둥(축 Y): 원기둥 축이 로컬 X라 Z로 90° 돌려요
local UPRIGHT_Z = math.rad(90)

-- 윗면이 topY인 원판 CFrame (origin 로컬)
local function discCFrame(origin: CFrame, x: number, topY: number, z: number, thickness: number): CFrame
	return origin * CFrame.new(x, topY - thickness / 2, z) * CFrame.Angles(0, 0, UPRIGHT_Z)
end

-- 높은 층일수록 튀김옷을 한 shade씩 밝게 (Art.raftColor)
local function raftColor(raft: Layout.Raft): Color3
	return color3(Art.raftColor(raft.kind, raft.tier))
end

-- 발판 하나 (Disc → 세운 Cylinder, Rect → yaw만큼 돌린 Block). 튀김옷 느낌의 Sand 질감에 Plastic 물성.
local function buildRaft(raft: Layout.Raft, origin: CFrame, thickness: number): BasePart
	local CollectionService = game:GetService("CollectionService")
	local p: BasePart
	if raft.shape == "Disc" then
		p = part({
			Name = raft.key,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(thickness, raft.radius * 2, raft.radius * 2),
			CFrame = discCFrame(origin, raft.x, raft.topY, raft.z, thickness),
		})
	else
		p = part({
			Name = raft.key,
			Size = Vector3.new(raft.length, thickness, raft.width),
			CFrame = origin
				* CFrame.new(raft.x, raft.topY - thickness / 2, raft.z)
				* CFrame.Angles(0, math.rad(raft.yaw), 0),
		})
	end
	p.Color = raftColor(raft)
	if raft.kind == "Basket" then
		p.Material = Enum.Material.DiamondPlate
		p.Reflectance = 0.1
	else
		p.Material = Enum.Material.Plastic -- 오돌토돌 튀김옷 (가이드 5절)
	end
	p.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic) -- 재질이 물성을 바꾸지 않게
	p.CanCollide = true
	p:SetAttribute("RaftKey", raft.key)
	p:SetAttribute("RaftKind", raft.kind)
	CollectionService:AddTag(p, RAFT_TAG)
	return p
end

-- 냄비: 바닥 원판 + 세로 벽 조각(POT_WALL_SEGMENTS개, 안쪽 면이 반지름 POT_INNER_RADIUS)
local function buildPot(model: Model, origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Pot"
	local cx, cz = Layout.POT_CENTER_X, Layout.POT_CENTER_Z
	local inner = Layout.POT_INNER_RADIUS
	local wallT = Layout.POT_WALL_THICKNESS
	local outer = inner + wallT

	part({
		Name = "PotFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(POT_FLOOR_THICKNESS, outer * 2, outer * 2),
		CFrame = discCFrame(origin, cx, Layout.POT_FLOOR_Y, cz, POT_FLOOR_THICKNESS),
		Color = color3(Art.COLORS.pot),
		Material = Enum.Material.Metal,
		Parent = folder,
	})

	local count = Layout.POT_WALL_SEGMENTS
	local height = Layout.POT_WALL_TOP_Y - Layout.POT_FLOOR_Y
	local chord = 2 * outer * math.tan(math.pi / count) + 0.2 -- 바깥 반지름 기준 + 겹침
	for i = 0, count - 1 do
		local angle = i * 360 / count
		local x, z = Layout.polar(angle, inner + wallT / 2)
		part({
			Name = string.format("PotWall%02d", i + 1),
			Size = Vector3.new(chord, height, wallT),
			CFrame = origin
				* CFrame.new(x, Layout.POT_FLOOR_Y + height / 2, z)
				* CFrame.Angles(0, math.rad(angle + 90), 0),
			Color = color3(Art.COLORS.pot),
			Material = Enum.Material.Metal,
			Reflectance = 0.25, -- 무쇠 반사 하이라이트 (보여 주기만)
			Parent = folder,
		})
	end
	folder.Parent = model
end

-- 기름 표면을 따라 올라가는 보여주기 파츠 (OIL_FOLLOWERS 폴더): 한 겹 아래 짙은 기름(깊이감),
-- 주황 빛 PointLight 3 (Art.OIL_GLOWS — 빛의 원인은 기름 표면), 김 2종. start가 표면과 같이 옮겨요.
local function buildOilFollowers(model: Model, origin: CFrame, oilCFrame: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = OIL_FOLLOWERS
	local deep = part({
		Name = "OilDepth",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(OIL_THICKNESS, Layout.POT_INNER_RADIUS * 2 - 0.6, Layout.POT_INNER_RADIUS * 2 - 0.6),
		CFrame = oilCFrame * CFrame.new(-2.5, 0, 0), -- 세운 원판: 로컬 -X = 아래
		Color = color3(Art.COLORS.oilDeep),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	ghost(deep)
	deep.Parent = folder
	for i, glow in Art.OIL_GLOWS do
		local holder = part({
			Name = `OilGlow{i}`,
			Size = Vector3.new(1, 1, 1),
			CFrame = origin
				* CFrame.new(Layout.POT_CENTER_X + glow.x, Logic.oilHeight(0) + 1.5, Layout.POT_CENTER_Z + glow.z),
			Transparency = 1,
		})
		ghost(holder)
		MapKit.makeLight(Art.OIL_GLOW_LIGHT).Parent = holder
		holder.Parent = folder
	end
	local steam = part({
		Name = "OilSteam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 50, 50),
		CFrame = oilCFrame * CFrame.new(3, 0, 0),
		Transparency = 1,
	})
	ghost(steam)
	for _, pair in { { "Steam", 5 }, { "SteamThick", 2 } } do
		local name, rate = pair[1] :: string, pair[2] :: number
		local emitter = MapKit.makeEmitter(name, rate)
		emitter.EmissionDirection = Enum.NormalId.Right
		emitter.Parent = steam
	end
	steam.Parent = folder
	folder.Parent = model
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	buildPot(model, origin)

	local rafts = Instance.new("Folder")
	rafts.Name = "Rafts"
	buildRaft(Layout.basket(), origin, BASKET_THICKNESS).Parent = rafts
	for _, raft in Layout.rafts() do
		buildRaft(raft, origin, Layout.RAFT_THICKNESS).Parent = rafts
	end
	rafts.Parent = model

	-- 기름 표면 (보여 주기만, 충돌 없음). start가 Logic.oilHeight를 따라 올려요.
	local oil = part({
		Name = OIL_NAME,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(OIL_THICKNESS, Layout.POT_INNER_RADIUS * 2 - 0.2, Layout.POT_INNER_RADIUS * 2 - 0.2),
		CFrame = discCFrame(origin, Layout.POT_CENTER_X, Logic.oilHeight(0), Layout.POT_CENTER_Z, OIL_THICKNESS),
		Color = color3(Art.COLORS.oil),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Reflectance = 0.15,
	})
	ghost(oil)
	CollectionService:AddTag(oil, OIL_TAG)
	-- 보글보글 거품 (세운 원판이라 로컬 +X = 위 = NormalId.Right)
	for _, rate in { 14, 6 } do
		local bubbles = MapKit.makeEmitter("OilBubbles", rate)
		bubbles.EmissionDirection = Enum.NormalId.Right
		bubbles.Parent = oil
	end
	oil.Parent = model
	buildOilFollowers(model, origin, oil.CFrame)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Layout.spawnOffsets() do
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, Layout.BASKET_TOP_Y + 0.1, offset.z),
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	local decor = MapKit.decorFolder(model)
	MapKit.buildDecor(Art.decor(), origin, decor)
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

-- 서버가 root를 짧게(hold초) 강제 속도로 띄워요 (SoySwampHazards.launch와 같은 방식: 클라이언트 물리가
-- 그 뒤를 포물선으로 이어가요). ctx.cleanup에 Attachment·LinearVelocity·되돌리는 스레드를 넣어요.
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3, hold: number)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "TempuraPotAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "OilSplashLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(hold, function()
		push:Destroy()
	end))
end

local function start(ctx: MapTypes.RoundContext)
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")
	local origin = ctx.origin

	local raftByKey: { [string]: Layout.Raft } = { [Layout.basket().key] = Layout.basket() }
	for _, raft in Layout.rafts() do
		raftByKey[raft.key] = raft
	end

	-- 이 방 Model 안의 발판만 (다른 방의 같은 맵과 안 섞여요, M1 B10 (A))
	local probeTargets: { Instance } = {}
	for _, instance in CollectionService:GetTagged(RAFT_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(probeTargets, instance)
		end
	end
	local oil: BasePart? = nil
	for _, instance in CollectionService:GetTagged(OIL_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			oil = instance
		end
	end
	-- 기름 표면을 따라 움직일 보여주기 파츠: 지금 표면 기준 상대 CFrame
	local followers: { { part: BasePart, rel: CFrame } } = {}
	local followerFolder = ctx.model:FindFirstChild(OIL_FOLLOWERS)
	if oil and followerFolder then
		for _, child in followerFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(followers, { part = child, rel = oil.CFrame:ToObjectSpace(child.CFrame) })
			end
		end
	end

	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = probeTargets
	local down = Vector3.new(0, -PROBE_LENGTH, 0)

	local startedAt = os.clock()
	local function elapsed(): number
		return os.clock() - startedAt
	end

	local standingOn: { [Player]: string } = {} -- 마지막 확인 때 서 있던 발판 key
	local lastHitAt: { [Player]: number } = {}
	local sinceCheck = math.huge

	local function rootOf(player: Player): (BasePart?, Humanoid?)
		local character = player.Character
		if character == nil then
			return nil, nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") then
			return root, humanoid
		end
		return nil, humanoid
	end

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	-- 기름 높이 따라가기 + 튀김 탈락 + 서 있는 발판 기록 (CHECK_INTERVAL마다)
	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		sinceCheck += dt
		if sinceCheck < Logic.CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		local oilY = Logic.oilHeight(elapsed())
		if oil then
			local surface = discCFrame(origin, Layout.POT_CENTER_X, oilY, Layout.POT_CENTER_Z, OIL_THICKNESS)
			oil.CFrame = surface
			for _, follower in followers do
				follower.part.CFrame = surface * follower.rel
			end
		end

		local newStanding: { [Player]: string } = {}
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			if rel.Y < Layout.FALL_ELIMINATION_Y or Logic.isFried(rel.Y - Layout.FOOT_OFFSET, oilY) then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
				continue
			end
			local hit = workspace:Raycast(root.Position, down, probeParams)
			if hit then
				local key = hit.Instance:GetAttribute("RaftKey")
				if type(key) == "string" then
					newStanding[player] = key
				end
			end
		end
		standingOn = newStanding
	end))

	-- 원 안 레이서를 바깥으로 밀고 1초 넘어뜨려요
	local function knock(player: Player, root: BasePart, humanoid: Humanoid?, kx: number, ky: number, kz: number)
		lastHitAt[player] = os.clock()
		MoveExempt.mark(player.Character, Logic.SPLASH_MOVE_EXEMPT)
		if humanoid then
			humanoid.PlatformStand = true
			ctx.cleanup:add(task.delay(Logic.SPLASH_KNOCKDOWN_TIME, function()
				-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
				if ctx.isActive() and humanoid.Parent and isRacer(player) then
					humanoid.PlatformStand = false
				end
			end))
		end
		local velocity = origin:VectorToWorldSpace(Vector3.new(kx, 0, kz)) + Vector3.new(0, ky, 0)
		launch(ctx, root, velocity, Logic.SPLASH_HOLD)
	end

	-- 튀는 기름 한 번: 경고 원(그 자리 고정) → WARN_TIME 뒤 솟구침 → 원 안 레이서 넉백
	local function splash(raft: Layout.Raft, cx: number, cz: number)
		local warnDisc = part({
			Name = "OilSplashWarning",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, Logic.SPLASH_RADIUS * 2, Logic.SPLASH_RADIUS * 2),
			CFrame = discCFrame(origin, cx, raft.topY + WARN_HEIGHT, cz, 0.2),
			Color = color3(Art.COLORS.warn),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
		ghost(warnDisc)
		CollectionService:AddTag(warnDisc, SPLASH_TAG)
		warnDisc.Parent = ctx.model
		ctx.cleanup:add(warnDisc)

		local waited = 0
		while waited < Logic.SPLASH_WARN_TIME do
			waited += task.wait(0.15)
			if not ctx.isActive() then
				return
			end
			warnDisc.Transparency = if warnDisc.Transparency > 0.5 then 0.35 else 0.65 -- 깜빡임
		end
		warnDisc:Destroy()

		-- 솟구치는 기름 (보여 주기): 기름 방울 파티클 한 번
		local burst = part({
			Name = "OilSplashBurst",
			Size = Vector3.new(1, 1, 1),
			CFrame = origin * CFrame.new(cx, raft.topY + 0.5, cz),
			Transparency = 1,
		})
		ghost(burst)
		local drops = Instance.new("ParticleEmitter")
		drops.Name = "OilDrops"
		drops.Color = ColorSequence.new(color3(Art.COLORS.splash))
		drops.LightEmission = 0.4
		drops.Rate = 0
		drops.Lifetime = NumberRange.new(0.6, 1)
		drops.Speed = NumberRange.new(14, 22)
		drops.SpreadAngle = Vector2.new(35, 35)
		drops.Acceleration = Vector3.new(0, -40, 0)
		drops.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		drops.EmissionDirection = Enum.NormalId.Top
		drops.Parent = burst
		burst.Parent = ctx.model
		ctx.cleanup:add(burst)
		drops:Emit(40)
		MapSfx.play(burst, "OilSplash")
		ctx.cleanup:add(task.delay(1.5, function()
			burst:Destroy()
		end))

		local now = os.clock()
		for _, player in ctx.getRacers() do
			local root, humanoid = rootOf(player)
			if root == nil then
				continue
			end
			local last = lastHitAt[player]
			if last and now - last < Logic.SPLASH_COOLDOWN then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local above = (rel.Y - Layout.FOOT_OFFSET) - raft.topY
			if above < -1 or above > Logic.SPLASH_HEIGHT_RANGE then
				continue
			end
			local velocity = Logic.splashKnockback(rel.X - cx, rel.Z - cz)
			if velocity then
				knock(player, root, humanoid, velocity.x, velocity.y, velocity.z)
			end
		end
	end

	-- 일정: 10초부터 간격마다 기름 위에 서 있는 레이서 한 명을 골라요
	ctx.cleanup:add(task.spawn(function()
		local first = Logic.SPLASH_SCHEDULE[1].from
		task.wait(math.max(0, first - elapsed()))
		while ctx.isActive() do
			local oilY = Logic.oilHeight(elapsed())
			local candidates: { Player } = {}
			for _, player in ctx.getRacers() do
				local key = standingOn[player]
				local raft = if key then raftByKey[key] else nil
				if raft and raft.topY > oilY then
					table.insert(candidates, player)
				end
			end
			local target = Logic.pickSplashTarget(candidates, ctx.rng)
			if target then
				local root = rootOf(target)
				local raft = raftByKey[standingOn[target]]
				if root and raft then
					local rel = origin:PointToObjectSpace(root.Position)
					ctx.cleanup:add(task.spawn(splash, raft, rel.X, rel.Z))
				end
			end
			task.wait(Logic.splashInterval(elapsed()) or Logic.SPLASH_SCHEDULE[1].interval)
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "튀김 냄비 탈출",
	rule = "차오르는 기름을 피해 위로! 튀는 기름도 조심!",
	timeLimit = Logic.TIME_LIMIT, -- 75초 (m5-40 — Config.TimeLimit.Survival 60은 그대로), 60초부터 서든데스
	lighting = Art.LIGHTING, -- m5-23 맵 조명: 밤의 주방
	build = build,
	start = start,
}

return map
