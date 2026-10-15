--!strict
-- Race 맵 "우주 회전초밥" (m5-35, GDD §5.2·§5.3 v0.7). 별바다에 떠 있는 회전초밥 레일을 달려 행성 정거장까지 가요.
-- 손맛 세 가지:
--   1. 방향이 바뀌는 레일(태그 SpaceRail): 6초 주기로 앞으로 실어 줌(+9) ↔ 뒤로 밂(−7), 0.4초 전 화살표 깜빡임.
--      밀기는 레일 파츠의 AssemblyLinearVelocity(고정 파츠 컨베이어)라 걷기와 더해져요(앞 25 / 뒤 9).
--      연속 밀기라 MoveExempt를 달지 않아요. 화살표(태그 SpaceRailArrow)는 서버가 색·방향을 바꿔요.
--   2. C 소행성 징검다리의 저중력(태그 SpaceGravityZone): 구역 안 레이서 HumanoidRootPart에 VectorForce
--      "SpaceLowGravity"(중력 절반 상쇄). 구역을 나갈 때·통과/탈락 직전·캐릭터가 바뀔 때·라운드 정리 때 지워요.
--   3. 운석: 6초부터 10초마다 레일에 3개(40초부터 4개), E 들판에는 10초부터 5초마다 2개(40초부터 3개).
--      빨간 원 경고 1.6초 → 원 안 레이서 넉백(수평 30 + 위 20, MoveExempt 1.5초) → 바위(SpaceMeteorRock)가 6초.
-- 치수는 SpaceConveyorLayout, 순수 계산은 SpaceConveyorLogic, 장식·색·조명은 SpaceConveyorArt.
-- 상태는 전부 start 안의 지역 변수예요 (여러 방이 같은 맵을 동시에 돌려도 안 섞여요). 태그 파츠는 ctx.model 하위만.
-- id·kind·displayName·rule은 GDD §5.3(v0.7) 확정값이에요 (m5-33 테스트가 고정).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.SpaceConveyorArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.SpaceConveyorLayout)
local Logic = require(script.Parent.SpaceConveyorLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = Layout.ID
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]

local TAG_RAIL = "SpaceRail"
local TAG_HUB = "SpaceRailHub"
local TAG_ARROW = "SpaceRailArrow"
local TAG_GRAVITY = "SpaceGravityZone"
local TAG_METEOR = "SpaceMeteor"
local TAG_ROCK = "SpaceMeteorRock"
local LOW_GRAVITY_NAME = "SpaceLowGravity"

local T = Layout.FLOOR_THICKNESS
local ARROW_HALF = 0.6 -- 화살표 반쪽 쐐기 폭 (화살표 폭 1.2)
local ARROW_LENGTH = 1.6
local ARROW_THICK = 0.1
local ARROW_LIFT = 0.06 -- 레일 윗면 위
local ARROW_EDGE = 0.5 -- 레일 가장자리 안쪽
local ARROW_SPACING_F = 11.25 -- F 긴 레일 화살표 간격
local WARN_BLINK = 0.15
local METEOR_SIZE = 3.6
local METEOR_FROM = { x = 14, y = 55, z = 20 } -- 운석이 비스듬히 내려오는 출발점 (충돌점 기준)
local BURST_COUNT = 20

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function noCollide(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- 원기둥 축(로컬 X)을 위로 (모듈 맨 위에서 CFrame을 만들면 Lune require가 깨져서 함수로)
local function upright(): CFrame
	return CFrame.Angles(0, 0, math.rad(90))
end

-- 레일 조각 CFrame: 윗면 가운데 선이 (x0,y0,z0) → (x1,y1,z1), LookVector = 앞(진행) 방향
local function railCFrame(origin: CFrame, rail: Layout.Rail): (CFrame, number)
	local a = origin:PointToWorldSpace(Vector3.new(rail.x0, rail.y0, rail.z0))
	local b = origin:PointToWorldSpace(Vector3.new(rail.x1, rail.y1, rail.z1))
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b, origin.UpVector) * CFrame.new(0, -T / 2, 0)
	return cf, (b - a).Magnitude
end

-- 화살표 하나 = 쐐기 2개(왼쪽·오른쪽 반쪽 삼각형, 앞 −Z를 가리킴). arrowCF는 화살표 가운데.
local function buildArrow(parent: Instance, arrowCF: CFrame, railIndex: number)
	local CollectionService = game:GetService("CollectionService")
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Arrow"
		wedge.Anchored = true
		wedge.Size = Vector3.new(ARROW_THICK, ARROW_HALF, ARROW_LENGTH)
		wedge.CFrame = arrowCF * CFrame.new(side * ARROW_HALF / 2, 0, 0) * CFrame.Angles(0, 0, -side * math.pi / 2)
		wedge.Color = rgb(Art.COLORS.arrowForward)
		wedge.Material = Enum.Material.Neon
		wedge.CastShadow = false
		noCollide(wedge)
		wedge:SetAttribute("RailIndex", railIndex)
		wedge:SetAttribute("ArrowSide", side)
		CollectionService:AddTag(wedge, TAG_ARROW)
		wedge.Parent = parent
	end
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.COLORS
	local model = Instance.new("Model")
	model.Name = ID

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- A 출발 발사대
	local a = Layout.section("A")
	makePart({
		Name = "LaunchPad",
		Size = Vector3.new(Layout.START_WIDTH, T, a.front - a.back),
		CFrame = at(0, -T / 2, (a.front + a.back) / 2),
		Color = rgb(C.pad),
		Parent = model,
	})

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == MAX_PLAYERS, "spawn count must cover the largest room size")
	for i, pos in positions do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end

	-- 레일 조각 (B·D·F) + 화살표
	local rails = Instance.new("Folder")
	rails.Name = "Rails"
	rails.Parent = model
	local arrows = Instance.new("Folder")
	arrows.Name = "Arrows"
	arrows.Parent = model
	for _, rail in Layout.rails() do
		local cf, length = railCFrame(origin, rail)
		local part = makePart({
			Name = string.format("Rail%02d", rail.index),
			Size = Vector3.new(rail.width, T, length),
			CFrame = cf,
			Color = rgb(C.rail),
			Parent = rails,
		})
		part:SetAttribute("RailIndex", rail.index)
		part:SetAttribute("RailGroup", rail.group)
		CollectionService:AddTag(part, TAG_RAIL)
		-- 화살표: 양 가장자리 안쪽 0.5, 이음매 원판을 피해 조각 가운데 쪽에
		local alongs: { number } = {}
		if rail.hubStart then
			table.insert(alongs, -3)
			table.insert(alongs, 3)
		else
			local count = math.floor(length / ARROW_SPACING_F)
			for i = 1, count do
				table.insert(alongs, -length / 2 + (i - 0.5) * (length / count))
			end
		end
		local lateral = rail.width / 2 - ARROW_EDGE - ARROW_HALF
		for _, along in alongs do
			for _, side in { -1, 1 } do
				buildArrow(arrows, cf * CFrame.new(side * lateral, T / 2 + ARROW_LIFT, -along), rail.index)
			end
		end
	end

	-- 이음매 원판 (밀기 없음, 레일보다 HUB_SINK 낮게)
	for i, hub in Layout.hubs() do
		local disc = makePart({
			Name = string.format("Hub%02d", i),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(T, hub.radius * 2, hub.radius * 2),
			CFrame = at(hub.x, hub.y - Layout.HUB_SINK - T / 2, hub.z) * upright(),
			Color = rgb(C.hub),
			Parent = rails,
		})
		CollectionService:AddTag(disc, TAG_HUB)
	end

	-- C 소행성 징검다리
	for _, rock in Layout.ASTEROIDS do
		makePart({
			Name = "Asteroid" .. rock.name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.ASTEROID_THICKNESS, rock.radius * 2, rock.radius * 2),
			CFrame = at(rock.x, rock.top - Layout.ASTEROID_THICKNESS / 2, rock.z) * upright(),
			Color = rgb(C.asteroidTop),
			Material = Enum.Material.Slate,
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
	end
	local g = Layout.GRAVITY_ZONE
	local zone = makePart({
		Name = "GravityZone",
		Size = Vector3.new(g.maxX - g.minX, g.maxY - g.minY, g.maxZ - g.minZ),
		CFrame = at((g.minX + g.maxX) / 2, (g.minY + g.maxY) / 2, (g.minZ + g.maxZ) / 2),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})
	CollectionService:AddTag(zone, TAG_GRAVITY)

	-- E 운석 들판, G 결승 착륙장, FinishLine
	local e, gSection = Layout.section("E"), Layout.section("G")
	makePart({
		Name = "MeteorField",
		Size = Vector3.new(Layout.FIELD_WIDTH, T, e.front - e.back),
		CFrame = at(0, Layout.TOP_Y - T / 2, (e.front + e.back) / 2),
		Color = rgb(C.field),
		Parent = model,
	})
	makePart({
		Name = "LandingPad",
		Size = Vector3.new(Layout.FINISH_WIDTH, T, gSection.front - gSection.back),
		CFrame = at(0, Layout.TOP_Y - T / 2, (gSection.front + gSection.back) / 2),
		Color = rgb(C.pad),
		Parent = model,
	})
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
		CFrame = at(0, Layout.TOP_Y + 0.2, Layout.FINISH_LINE_Z),
		Color = rgb(C.finishLine),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	local meteors = Instance.new("Folder")
	meteors.Name = "Meteors"
	meteors.Parent = model

	-- 장식(충돌 없음) + 소개 카메라 + 사용자 Studio 아트 자리
	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
	return model
end

-- ctx.model 하위에 있는 태그 파츠만 (여러 방 동시 진행)
local function tagged(ctx: MapTypes.RoundContext, tag: string): { BasePart }
	local CollectionService = game:GetService("CollectionService")
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(list, instance)
		end
	end
	return list
end

type RacerRoot = { player: Player, root: BasePart, humanoid: Humanoid, at: Vector3 }

local function racerRoots(ctx: MapTypes.RoundContext): { RacerRoot }
	local list: { RacerRoot } = {}
	for _, player in ctx.getRacers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid then
			table.insert(
				list,
				{ player = player, root = root, humanoid = humanoid, at = ctx.origin:PointToObjectSpace(root.Position) }
			)
		end
	end
	return list
end

local function toPos(v: Vector3): Logic.Pos
	return { x = v.X, y = v.Y, z = v.Z }
end

type RailGroup = {
	offset: number,
	parts: { BasePart },
	arrows: { { part: BasePart, forward: CFrame, back: CFrame } },
	state: Logic.RailState?,
	color: Color3?,
}

type Taken = { x: number, z: number, untilAt: number }

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local origin = ctx.origin
	local C = Art.COLORS
	local startedAt = os.clock()
	local railDefs = Layout.rails()
	local meteorFolder = ctx.model:FindFirstChild("Meteors") or ctx.model

	-- ── 레일 묶음 (방향 전환 위상이 같은 조각끼리) ─────────────────────────────
	local groups: { [string]: RailGroup } = {}
	local railParts: { [number]: BasePart } = {}
	for _, part in tagged(ctx, TAG_RAIL) do
		local index = part:GetAttribute("RailIndex")
		local def = if type(index) == "number" then railDefs[index] else nil
		if def then
			railParts[def.index] = part
			local group = groups[def.group]
			if group == nil then
				local created: RailGroup = { offset = def.offset, parts = {}, arrows = {}, state = nil, color = nil }
				groups[def.group] = created
				group = created
			end
			table.insert((group :: RailGroup).parts, part)
		end
	end
	for _, wedge in tagged(ctx, TAG_ARROW) do
		local index = wedge:GetAttribute("RailIndex")
		local side = wedge:GetAttribute("ArrowSide")
		local def = if type(index) == "number" then railDefs[index] else nil
		if def and type(side) == "number" and groups[def.group] then
			-- 화살표 가운데 CFrame → 그 자리에서 180° 돌린 CFrame (뒤를 가리킴)
			local arrowCF = wedge.CFrame
				* CFrame.Angles(0, 0, side * math.pi / 2)
				* CFrame.new(-side * ARROW_HALF / 2, 0, 0)
			local flip = arrowCF * CFrame.Angles(0, math.pi, 0) * arrowCF:Inverse()
			table.insert(groups[def.group].arrows, { part = wedge, forward = wedge.CFrame, back = flip * wedge.CFrame })
		end
	end
	ctx.cleanup:add(function()
		for _, part in railParts do
			part.AssemblyLinearVelocity = Vector3.zero
		end
	end)

	local function updateRails(t: number)
		for _, group in groups do
			local state, push = Logic.railPhase(t, group.offset)
			if state ~= group.state then
				group.state = state
				for _, part in group.parts do
					part.AssemblyLinearVelocity = part.CFrame.LookVector * push
				end
				local pointBack = state == "Back" or state == "WarnForward"
				for _, arrow in group.arrows do
					arrow.part.CFrame = if pointBack then arrow.back else arrow.forward
				end
				if (state == "WarnBack" or state == "WarnForward") and group.parts[1] then
					MapSfx.play(group.parts[math.ceil(#group.parts / 2)], "RailSwitch")
				end
			end
			local blink = Logic.blinkOn(t, group.offset)
			local colorRgb
			if state == "Forward" then
				colorRgb = C.arrowForward
			elseif state == "Back" then
				colorRgb = C.arrowBack
			elseif state == "WarnBack" then
				colorRgb = if blink then C.arrowBack else C.arrowForward
			else
				colorRgb = if blink then C.arrowForward else C.arrowBack
			end
			local color = rgb(colorRgb)
			if color ~= group.color then
				group.color = color
				for _, arrow in group.arrows do
					arrow.part.Color = color
				end
			end
		end
	end

	-- ── 저중력 ─────────────────────────────────────────────────────────────
	local zones = tagged(ctx, TAG_GRAVITY)
	local forces: { [Player]: VectorForce } = {}

	local function clearGravity(player: Player)
		local force = forces[player]
		if force then
			forces[player] = nil
			force:Destroy()
		end
	end
	ctx.cleanup:add(function()
		for player in forces do
			clearGravity(player)
		end
	end)

	local function inZone(position: Vector3): boolean
		for _, z in zones do
			local rel = z.CFrame:PointToObjectSpace(position)
			local half = z.Size / 2
			if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
				return true
			end
		end
		return false
	end

	local function applyGravity(racer: RacerRoot)
		local force = forces[racer.player]
		if force and force.Parent ~= racer.root then
			clearGravity(racer.player) -- 캐릭터가 바뀌었어요
			force = nil
		end
		if force == nil then
			local attachment = racer.root:FindFirstChild("RootAttachment")
			if attachment == nil or not attachment:IsA("Attachment") then
				local created = Instance.new("Attachment")
				created.Name = "SpaceGravityAttachment"
				created.Parent = racer.root
				attachment = created
			end
			local created = Instance.new("VectorForce")
			created.Name = LOW_GRAVITY_NAME
			created.Attachment0 = attachment :: Attachment
			created.RelativeTo = Enum.ActuatorRelativeTo.World
			created.ApplyAtCenterOfMass = true
			created.Parent = racer.root
			forces[racer.player] = created
			force = created
		end
		local lift = Logic.lowGravityForce(racer.root.AssemblyMass, workspace.Gravity, Logic.LOW_GRAVITY);
		(force :: VectorForce).Force = Vector3.new(0, lift, 0)
	end

	-- ── 판정 Heartbeat ─────────────────────────────────────────────────────
	local finishProgress = Logic.finishProgress()
	local finishLine = ctx.model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		finishProgress = Logic.progress(origin:PointToObjectSpace(finishLine.Position).Z)
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		updateRails(os.clock() - startedAt)

		local racers = racerRoots(ctx)
		local alive: { [Player]: boolean } = {}
		for _, racer in racers do
			alive[racer.player] = true
		end
		for player in forces do
			if not alive[player] then
				clearGravity(player)
			end
		end

		for _, racer in racers do
			local rel = racer.at
			if Logic.progress(rel.Z) >= finishProgress then
				clearGravity(racer.player)
				ctx.pass(racer.player)
			elseif rel.Y < Logic.fallLineAt(rel.Z) then
				clearGravity(racer.player)
				ctx.eliminate(racer.player)
			elseif inZone(racer.root.Position) then
				applyGravity(racer)
			else
				clearGravity(racer.player)
			end
			if not ctx.isActive() then
				return -- 이 통과/탈락으로 라운드가 끝났어요
			end
		end
	end))

	-- ── 운석 ───────────────────────────────────────────────────────────────
	local railTaken: { Taken } = {}
	local fieldTaken: { Taken } = {}
	local lastHit: { [Player]: number } = {}

	local burstHolder = makePart({
		Name = "MeteorBurst",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin,
		Transparency = 1,
		Parent = meteorFolder,
	})
	noCollide(burstHolder)
	ctx.cleanup:add(burstHolder)
	local burst = MapKit.makeEmitter("Embers", 0)
	burst.Parent = burstHolder

	local function liveTaken(list: { Taken }): { Logic.Rock }
		local now = os.clock()
		for i = #list, 1, -1 do
			if list[i].untilAt <= now then
				table.remove(list, i)
			end
		end
		local out: { Logic.Rock } = {}
		for _, r in list do
			table.insert(out, { x = r.x, z = r.z })
		end
		return out
	end

	-- 충돌점의 윗면 CFrame (원기둥 원판이 그 면에 눕게 — 축이 면의 위 방향)
	local function surfaceCFrame(target: Logic.Target): CFrame
		local railPart = if target.rail then railParts[target.rail] else nil
		if railPart and target.rail then
			local def = railDefs[target.rail]
			local along = Logic.railLocal(def, target.x, target.z)
			return railPart.CFrame * CFrame.new(target.lateral, T / 2, -along)
		end
		return origin * CFrame.new(target.x, target.y, target.z)
	end

	local function launch(root: BasePart, velocity: Vector3)
		local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if attachment == nil then
			local created = Instance.new("Attachment")
			created.Name = "MeteorAttachment"
			created.Parent = root
			ctx.cleanup:add(created)
			attachment = created
		end
		local push = Instance.new("LinearVelocity")
		push.Name = "MeteorLaunch"
		push.Attachment0 = attachment :: Attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		push.VectorVelocity = velocity
		push.MaxForce = math.huge
		push.Parent = root
		root.AssemblyLinearVelocity = velocity
		ctx.cleanup:add(push)
		ctx.cleanup:add(task.delay(Logic.LAUNCH_HOLD, function()
			push:Destroy()
		end))
	end

	local function impact(target: Logic.Target, surface: CFrame)
		local now = os.clock()
		local fallbackX, fallbackZ = 1, 0
		if target.rail then
			local f = Logic.railFrame(railDefs[target.rail])
			local sign = if target.lateral < 0 then -1 else 1
			fallbackX, fallbackZ = f.rx * sign, f.rz * sign
		end
		for _, racer in racerRoots(ctx) do
			local dx, dz = racer.at.X - target.x, racer.at.Z - target.z
			local foot = racer.at.Y - Logic.FOOT_BELOW_ROOT - target.y
			if not Logic.inImpact(math.sqrt(dx * dx + dz * dz), foot) then
				continue
			end
			local last = lastHit[racer.player]
			if last and now - last < Logic.HIT_COOLDOWN then
				continue
			end
			lastHit[racer.player] = now
			local push = Logic.knockback(dx, dz, fallbackX, fallbackZ)
			local player, humanoid = racer.player, racer.humanoid
			humanoid.PlatformStand = true -- 넘어짐 (잡기도 풀려요)
			MoveExempt.mark(player.Character, Logic.EXEMPT_TIME) -- 서버가 튕긴 속도라 이동 감시에서 빼요
			launch(racer.root, origin:VectorToWorldSpace(Vector3.new(push.x, push.y, push.z)))
			ctx.cleanup:add(task.delay(Logic.KNOCKDOWN_TIME, function()
				if ctx.isActive() and humanoid.Parent and table.find(ctx.getRacers(), player) then
					humanoid.PlatformStand = false
				end
			end))
		end
		burstHolder.CFrame = surface * CFrame.new(0, 1, 0)
		burst:Emit(BURST_COUNT)
	end

	local function spawnRock(target: Logic.Target, rockCF: CFrame)
		local rock = makePart({
			Name = "MeteorRock",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Logic.ROCK_SIZE.y, Logic.ROCK_SIZE.x, Logic.ROCK_SIZE.z),
			CFrame = rockCF * CFrame.new(0, Logic.ROCK_SIZE.y / 2, 0) * upright(),
			Color = rgb(C.rock),
			Material = Enum.Material.Basalt,
		})
		rock.CanTouch = false
		local cap = makePart({
			Name = "MeteorRockCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.6, 3.6, 3.6),
			CFrame = rockCF * CFrame.new(0, Logic.ROCK_SIZE.y - 0.3, 0),
			Color = rgb(C.rockLight),
			Material = Enum.Material.Basalt,
		})
		noCollide(cap)
		local ember = makePart({
			Name = "MeteorRockEmber",
			Size = Vector3.new(4.2, 0.3, 0.5),
			CFrame = rockCF * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(35), 0),
			Color = rgb(C.meteor),
			Material = Enum.Material.Neon,
		})
		noCollide(ember)
		game:GetService("CollectionService"):AddTag(rock, TAG_ROCK)
		cap.Parent = rock
		ember.Parent = rock
		rock.Parent = meteorFolder
		ctx.cleanup:add(rock)
		ctx.cleanup:add(task.delay(Logic.ROCK_LIFE, function()
			rock.CanCollide = false
			local info = TweenInfo.new(Logic.ROCK_CRUMBLE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, p in { rock, cap, ember } do
				TweenService:Create(p, info, { Transparency = 1, Size = p.Size * 0.4 }):Play()
			end
			ctx.cleanup:add(task.delay(Logic.ROCK_CRUMBLE, function()
				rock:Destroy()
			end))
		end))
		local _ = target
	end

	-- 운석 하나: 빨간 원 경고(깜빡임) + 하늘에서 비스듬히 내려오는 운석 → 충돌 → (넓은 레일·들판이면) 바위
	local function runMeteor(target: Logic.Target, rockLateral: number?, leaveRock: boolean)
		local CollectionService = game:GetService("CollectionService")
		local surface = surfaceCFrame(target)
		local group = Instance.new("Model")
		group.Name = "Meteor"
		local d = Logic.IMPACT_RADIUS * 2
		local border = makePart({
			Name = "WarningBorder",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.16, d + 1, d + 1),
			CFrame = surface * CFrame.new(0, 0.09, 0) * upright(),
			Color = rgb(C.warnBorder),
			Parent = group,
		})
		noCollide(border)
		local circle = makePart({
			Name = "Warning",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, d, d),
			CFrame = surface * CFrame.new(0, 0.12, 0) * upright(),
			Color = rgb(C.warn),
			Parent = group,
		})
		noCollide(circle)
		local from = surface.Position
			+ origin:VectorToWorldSpace(Vector3.new(METEOR_FROM.x, METEOR_FROM.y, METEOR_FROM.z))
		local meteor = makePart({
			Name = "Meteor",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(METEOR_SIZE, METEOR_SIZE, METEOR_SIZE),
			CFrame = CFrame.new(from),
			Color = rgb(C.meteor),
			Material = Enum.Material.Neon,
			Parent = group,
		})
		noCollide(meteor)
		CollectionService:AddTag(meteor, TAG_METEOR)
		local tail = MapKit.makeEmitter("Embers", 40)
		tail.Parent = meteor
		group.Parent = meteorFolder
		ctx.cleanup:add(group)
		MapSfx.play(circle, "MeteorWarn")

		local bornAt = os.clock()
		local hitAt = bornAt + Logic.WARN_TIME
		local blinkOn = false
		local nextBlink = bornAt + WARN_BLINK
		while true do
			if not ctx.isActive() then
				group:Destroy()
				return
			end
			local now = os.clock()
			if now >= hitAt then
				break
			end
			if now >= nextBlink then
				blinkOn = not blinkOn
				circle.Color = rgb(if blinkOn then C.warnBlink else C.warn)
				nextBlink = now + WARN_BLINK
			end
			local alpha = math.clamp((now - bornAt) / Logic.WARN_TIME, 0, 1)
			meteor.CFrame = CFrame.new(from:Lerp(surface.Position, alpha * alpha))
			RunService.Heartbeat:Wait()
		end
		impact(target, surface)
		MapSfx.play(circle, "MeteorImpact")
		group:Destroy()
		if leaveRock then
			ctx.cleanup:add(task.delay(Logic.ROCK_DELAY, function()
				if ctx.isActive() then
					local rockCF = surface * CFrame.new((rockLateral or target.lateral) - target.lateral, 0, 0)
					spawnRock(target, rockCF)
				end
			end))
		end
	end

	local function racerPositions(): { Logic.Pos }
		local list = {}
		for _, racer in racerRoots(ctx) do
			table.insert(list, toPos(racer.at))
		end
		return list
	end

	local function holdUntil(hitTime: number, leaveRock: boolean): number
		return hitTime + (if leaveRock then Logic.ROCK_DELAY + Logic.ROCK_LIFE + Logic.ROCK_CRUMBLE else 0)
	end

	local function railWave(count: number)
		local targets = Logic.pickMeteorTargets(ctx.rng, racerPositions(), railDefs, liveTaken(railTaken), count)
		local hitTime = os.clock() + Logic.WARN_TIME
		for _, target in targets do
			local def = railDefs[target.rail :: number]
			local rockLateral = Logic.rockOffset(target.lateral, def.width, ctx.rng)
			local leaveRock = rockLateral ~= nil
			table.insert(railTaken, { x = target.x, z = target.z, untilAt = holdUntil(hitTime, leaveRock) })
			ctx.cleanup:add(task.spawn(runMeteor, target, rockLateral, leaveRock))
		end
	end

	local function fieldWave(count: number)
		local targets = Logic.pickFieldTargets(ctx.rng, racerPositions(), liveTaken(fieldTaken), count)
		local hitTime = os.clock() + Logic.WARN_TIME
		for _, target in targets do
			table.insert(fieldTaken, { x = target.x, z = target.z, untilAt = holdUntil(hitTime, true) })
			ctx.cleanup:add(task.spawn(runMeteor, target, target.lateral, true))
		end
	end

	local function schedule(firstAt: number, waveAt: (number) -> Logic.Wave?, fire: (number) -> ())
		ctx.cleanup:add(task.spawn(function()
			local nextAt = firstAt
			while ctx.isActive() do
				local elapsed = os.clock() - startedAt
				if elapsed < nextAt then
					task.wait(nextAt - elapsed)
					continue
				end
				local wave = waveAt(nextAt)
				if wave == nil then
					return
				end
				fire(wave.count)
				nextAt += wave.interval
			end
		end))
	end
	schedule(Logic.METEOR_START, Logic.meteorWave, railWave)
	schedule(Logic.FIELD_START, Logic.fieldMeteorWave, fieldWave)
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "우주 회전초밥",
	rule = "방향이 바뀌는 우주 레일을 타고, 떨어지는 운석을 피해 결승까지!",
	build = build,
	start = start,
	lighting = Art.LIGHTING,
}

return map
