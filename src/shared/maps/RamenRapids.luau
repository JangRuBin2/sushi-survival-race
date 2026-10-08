--!strict
-- Race 맵 "라멘 국물 급류" (GDD 5.2 ③, 스펙 m4-04).
-- 출발 → 급류 미끄럼틀(앞으로 밀기, 소용돌이가 벽 쪽으로 밀기, 면발 줄기) → 토핑 건너기(가라앉는 차슈,
-- 고정 나루토) → 회전 젓가락 막대 원판 2개 → 결승.
-- 치수는 RamenRapidsLayout, 계산(차슈 높이·막대 각도·밀기·낙하선)은 RamenRapidsLogic, 장식은 RamenRapidsArt.
-- 장애물은 태그(Broth, Chashu, NoodleSweeper)를 달고 start에서 ctx.model 하위의 태그 파츠만 움직여요.
-- 상태는 전부 start 안의 지역 변수에 둬서 여러 방이 같은 맵을 동시에 돌려도 섞이지 않아요.
-- id·kind·displayName·rule은 m4-01에서 확정이에요 (바꾸지 않아요).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.RamenRapidsArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.RamenRapidsLayout)
local Logic = require(script.Parent.RamenRapidsLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "ramen-rapids"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]

local TAG_BROTH = "Broth"
local TAG_CHASHU = "Chashu"
local TAG_SWEEPER = "NoodleSweeper"

-- 색은 Color3(Roblox API)라서 build 안에서 만들어요
local function palette()
	return {
		floor = Color3.fromRGB(222, 206, 184),
		broth = Color3.fromRGB(196, 120, 52),
		whirl = Color3.fromRGB(150, 84, 34),
		wall = Color3.fromRGB(240, 242, 246),
		noodle = Color3.fromRGB(246, 214, 120),
		chashu = Color3.fromRGB(150, 82, 56),
		naruto = Color3.fromRGB(248, 246, 238),
		narutoSwirl = Color3.fromRGB(236, 110, 150),
		platform = Color3.fromRGB(240, 236, 226),
		hub = Color3.fromRGB(170, 30, 36),
		sweeper = Color3.fromRGB(186, 140, 92),
		spawn = Color3.fromRGB(246, 196, 70),
		finish = Color3.fromRGB(255, 196, 40),
	}
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

-- 원판 (원기둥 축을 세워요). center는 윗면 가운데.
local function discCFrame(origin: CFrame, x: number, top: number, z: number, thickness: number): CFrame
	return origin * CFrame.new(x, top - thickness / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
end

-- 막대 CFrame: 발판 중심(윗면) hubTop에서 angle 방향으로 축~끝 사이 가운데
local function sweeperCFrame(hubTop: CFrame, angle: number): CFrame
	local spec = Logic.sweeperSpec()
	return hubTop * CFrame.Angles(0, angle, 0) * CFrame.new((spec.innerReach + spec.outerReach) / 2, spec.height, 0)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local COLORS = palette()
	local model = Instance.new("Model")
	model.Name = ID

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local function sideWalls(width: number, centerZ: number, depth: number, baseY: number)
		for _, side in { -1, 1 } do
			makePart({
				Name = "Wall",
				Size = Vector3.new(0.5, Layout.LOW_WALL_HEIGHT, depth),
				CFrame = at(side * (width / 2 + 0.25), baseY + Layout.LOW_WALL_HEIGHT / 2, centerZ),
				Color = COLORS.wall,
				Material = Enum.Material.Marble,
				Parent = model,
			})
		end
	end

	-- A. 출발
	local startDepth = Layout.START.front - Layout.START.back
	local startCenter = Layout.START.front - startDepth / 2
	makePart({
		Name = "StartFloor",
		Size = Vector3.new(Layout.START_WIDTH, Layout.FLOOR_THICKNESS, startDepth),
		CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, startCenter),
		Color = COLORS.floor,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	sideWalls(Layout.START_WIDTH, startCenter, startDepth, 0)
	makePart({
		Name = "StartWall",
		Size = Vector3.new(Layout.START_WIDTH + 1, Layout.END_WALL_HEIGHT, 0.5),
		CFrame = at(0, Layout.END_WALL_HEIGHT / 2, Layout.START.front + 0.25),
		Color = COLORS.wall,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
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
			Size = Vector3.new(3, 0.2, 3),
			CFrame = at(pos.x, 0.1, pos.z),
			Color = COLORS.spawn,
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end

	-- B. 급류 미끄럼틀: 기울인 판 하나(Broth 태그). 높은 쪽이 +Z라서 Rx(-각도)로 기울여요.
	local rapidsDepth = Layout.RAPIDS.front - Layout.RAPIDS.back
	local rapidsCenter = Layout.RAPIDS.front - rapidsDepth / 2
	local slope = math.rad(Layout.RAPIDS_SLOPE_DEG)
	local slopeFrame = at(0, Layout.rapidsHeightAt(rapidsCenter), rapidsCenter) * CFrame.Angles(-slope, 0, 0)
	local slideLength = rapidsDepth / math.cos(slope)
	local slide = makePart({
		Name = "BrothSlide",
		Size = Vector3.new(Layout.RAPIDS_WIDTH, Layout.FLOOR_THICKNESS, slideLength),
		CFrame = slopeFrame * CFrame.new(0, -Layout.FLOOR_THICKNESS / 2, 0),
		Color = COLORS.broth,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Parent = model,
	})
	CollectionService:AddTag(slide, TAG_BROTH)
	for _, side in { -1, 1 } do
		makePart({
			Name = "Wall",
			Size = Vector3.new(0.5, Layout.LOW_WALL_HEIGHT, slideLength),
			CFrame = slopeFrame * CFrame.new(side * (Layout.RAPIDS_WIDTH / 2 + 0.25), Layout.LOW_WALL_HEIGHT / 2, 0),
			Color = COLORS.wall,
			Material = Enum.Material.Marble,
			Parent = model,
		})
	end
	-- 소용돌이 표시 (판정은 RamenRapidsLogic.whirlpoolAt, 이 파츠는 보이기만)
	for i, pool in Layout.WHIRLPOOLS do
		makePart({
			Name = `Whirlpool{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, Layout.WHIRLPOOL_DIAMETER, Layout.WHIRLPOOL_DIAMETER),
			CFrame = at(pool.x, Layout.rapidsHeightAt(pool.z), pool.z)
				* CFrame.Angles(-slope, 0, 0)
				* CFrame.new(0, 0.06, 0)
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = COLORS.whirl,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = model,
		})
	end
	-- 면발 줄기: 폭 전체를 가로지르는 낮은 원기둥 (점프로 넘어요)
	for i, z in Layout.NOODLE_ZS do
		makePart({
			Name = `Noodle{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.RAPIDS_WIDTH, Layout.NOODLE_HEIGHT, Layout.NOODLE_HEIGHT),
			CFrame = at(0, Layout.rapidsHeightAt(z), z)
				* CFrame.Angles(-slope, 0, 0)
				* CFrame.new(0, Layout.NOODLE_HEIGHT / 2, 0),
			Color = COLORS.noodle,
			Parent = model,
		})
	end

	-- C. 토핑: 차슈(Chashu 태그, 서버가 오르내림) + 나루토(고정 원판, 위의 분홍 소용돌이만 돌아요)
	local toppings = Instance.new("Folder")
	toppings.Name = "Toppings"
	toppings.Parent = model
	for i, chashu in Layout.CHASHUS do
		local part = makePart({
			Name = `Chashu{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.CHASHU_THICKNESS, Layout.CHASHU_DIAMETER, Layout.CHASHU_DIAMETER),
			CFrame = discCFrame(origin, chashu.x, Logic.chashuHeight(i, 0), chashu.z, Layout.CHASHU_THICKNESS),
			Color = COLORS.chashu,
			Material = Enum.Material.Slate,
			Parent = toppings,
		})
		part:SetAttribute("ChashuIndex", i)
		CollectionService:AddTag(part, TAG_CHASHU)
	end
	for i, naruto in Layout.NARUTOS do
		local top = Layout.narutoTop()
		makePart({
			Name = `Naruto{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.NARUTO_THICKNESS, Layout.NARUTO_DIAMETER, Layout.NARUTO_DIAMETER),
			CFrame = discCFrame(origin, naruto.x, top, naruto.z, Layout.NARUTO_THICKNESS),
			Color = COLORS.naruto,
			Parent = toppings,
		})
		-- 분홍 소용돌이 장식: 윗면 바로 위 얇은 막대 두 개 (충돌 없음, start에서 천천히 돌아요)
		for k = 0, 1 do
			local swirl = makePart({
				Name = `NarutoSwirl{i}`,
				Size = Vector3.new(Layout.NARUTO_DIAMETER * 0.7, 0.06, 0.8),
				CFrame = at(naruto.x, top + 0.04, naruto.z) * CFrame.Angles(0, k * math.pi / 2, 0),
				Color = COLORS.narutoSwirl,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				Parent = toppings,
			})
			swirl:SetAttribute("SwirlOffset", k * math.pi / 2)
		end
	end

	-- D. 회전 젓가락 막대: 원판 2개 + 가운데 축 + 막대(NoodleSweeper 태그, 충돌 없음 — 맞음은 서버가 거리로)
	local platformTop = Layout.platformTop()
	local radius = Layout.PLATFORM_DIAMETER / 2
	for i, sweeper in Layout.SWEEPER_LIST do
		makePart({
			Name = `SweeperPlatform{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.FLOOR_THICKNESS, radius * 2, radius * 2),
			CFrame = discCFrame(origin, 0, platformTop, sweeper.z, Layout.FLOOR_THICKNESS),
			Color = COLORS.platform,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		makePart({
			Name = `SweeperHub{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.HUB_HEIGHT, Layout.HUB_DIAMETER, Layout.HUB_DIAMETER),
			CFrame = at(0, platformTop + Layout.HUB_HEIGHT / 2, sweeper.z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = COLORS.hub,
			Parent = model,
		})
		local hubTop = at(0, platformTop, sweeper.z)
		local spec = Logic.sweeperSpec()
		local stick = makePart({
			Name = `NoodleSweeper{i}`,
			Size = Vector3.new(spec.outerReach - spec.innerReach, Layout.SWEEPER_THICKNESS, 1.2),
			CFrame = sweeperCFrame(hubTop, Logic.sweeperAngle(i, 0)),
			Color = COLORS.sweeper,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = model,
		})
		stick:SetAttribute("SweeperIndex", i)
		CollectionService:AddTag(stick, TAG_SWEEPER)
	end

	-- E. 결승: 마지막 원판과 조금 겹치게 시작
	local finishFront = Layout.FINISH.front + Layout.FINISH_FLOOR_OVERLAP
	local finishDepth = finishFront - Layout.FINISH.back
	local finishCenter = finishFront - finishDepth / 2
	makePart({
		Name = "FinishFloor",
		Size = Vector3.new(Layout.FINISH_WIDTH, Layout.FLOOR_THICKNESS, finishDepth),
		CFrame = at(0, platformTop - Layout.FLOOR_THICKNESS / 2, finishCenter),
		Color = COLORS.platform,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local wallDepth = Layout.FINISH.front - Layout.FINISH.back
	sideWalls(Layout.FINISH_WIDTH, Layout.FINISH.front - wallDepth / 2, wallDepth, platformTop)
	makePart({
		Name = "EndWall",
		Size = Vector3.new(Layout.FINISH_WIDTH + 1, Layout.END_WALL_HEIGHT, 0.5),
		CFrame = at(0, platformTop + Layout.END_WALL_HEIGHT / 2, Layout.FINISH.back - 0.25),
		Color = COLORS.wall,
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		Parent = model,
	})
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
		CFrame = at(0, platformTop + 0.2, Layout.finishLineZ()),
		Color = COLORS.finish,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	-- 장식 (충돌 없음) + 김 + 소개 카메라 + 사용자 Studio 아트 자리
	local decor = MapKit.decorFolder(model)
	MapKit.buildDecor(Art.decor(), origin, decor)
	for i, point in Art.steamPoints() do
		local anchor = Instance.new("Part")
		anchor.Name = `Steam{i}`
		anchor.Size = Vector3.new(8, 0.2, 8)
		anchor.Transparency = 1
		anchor.CFrame = at(point.x, point.y, point.z)
		MapKit.applyDecorRules(anchor)
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "Steam"
		steam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		steam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		steam.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 4),
			NumberSequenceKeypoint.new(1, 14),
		})
		steam.Lifetime = NumberRange.new(4, 6)
		steam.Rate = 6
		steam.Speed = NumberRange.new(4, 7)
		steam.SpreadAngle = Vector2.new(15, 15)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.LightInfluence = 0.5
		steam.Parent = anchor
		anchor.Parent = decor
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

-- ctx.model 하위에 있는 태그 파츠만 (여러 방 동시 진행)
local function taggedParts(ctx: MapTypes.RoundContext, tag: string): { BasePart }
	local CollectionService = game:GetService("CollectionService")
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function rootAndHumanoid(player: Player): (BasePart?, Humanoid?)
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

-- 캐릭터는 클라이언트가 물리를 맡아서 서버가 속도만 바꾸면 덮어써질 수 있어요.
-- 와사비처럼 LinearVelocity를 잠깐 붙여 그 클라이언트 물리가 넉백을 직접 계산하게 해요.
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "RamenKnockAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "SweeperKnock"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(Layout.KNOCK_HOLD, function()
		push:Destroy()
	end))
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local startedAt = os.clock()

	local finishProgress = Logic.finishProgress()
	local finishLine = ctx.model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		finishProgress = Logic.progress(origin:PointToObjectSpace(finishLine.Position).Z)
	end

	local brothZones = taggedParts(ctx, TAG_BROTH)
	local chashus: { { part: BasePart, index: number } } = {}
	for _, part in taggedParts(ctx, TAG_CHASHU) do
		local index = part:GetAttribute("ChashuIndex")
		if type(index) == "number" and Layout.CHASHUS[index] then
			table.insert(chashus, { part = part, index = index })
		end
	end
	local sweepers: { { part: BasePart, index: number, hub: CFrame, angle: number } } = {}
	for _, part in taggedParts(ctx, TAG_SWEEPER) do
		local index = part:GetAttribute("SweeperIndex")
		if type(index) == "number" and Layout.SWEEPER_LIST[index] then
			local z = Layout.SWEEPER_LIST[index].z
			table.insert(sweepers, {
				part = part,
				index = index,
				hub = origin * CFrame.new(0, Layout.platformTop(), z),
				angle = Logic.sweeperAngle(index, 0),
			})
		end
	end
	local swirls: { { part: BasePart, center: CFrame, offset: number } } = {}
	local toppings = ctx.model:FindFirstChild("Toppings")
	if toppings then
		for _, child in toppings:GetChildren() do
			local offset = child:GetAttribute("SwirlOffset")
			if child:IsA("BasePart") and type(offset) == "number" then
				table.insert(swirls, { part = child, center = CFrame.new(child.Position), offset = offset })
			end
		end
	end

	local forward = origin.LookVector
	local right = origin.RightVector
	local inBroth: { [Player]: boolean } = {}
	local lastExempt: { [Player]: number } = {}
	local lastHitAt: { [Player]: number } = {}

	local function exempt(player: Player, now: number)
		if now - (lastExempt[player] or -math.huge) >= Layout.EXEMPT_REFRESH then
			lastExempt[player] = now
			MoveExempt.mark(player.Character)
		end
	end

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	local function onBroth(position: Vector3): BasePart?
		for _, zone in brothZones do
			local rel = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(rel.X) <= half.X
				and math.abs(rel.Z) <= half.Z
				and rel.Y >= -half.Y
				and rel.Y <= half.Y + Layout.BROTH_ZONE_HEIGHT
			then
				return zone
			end
		end
		return nil
	end

	local function knockBack(player: Player, root: BasePart, humanoid: Humanoid, dx: number, dz: number)
		local outward = Vector3.new(dx, 0, dz)
		outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.xAxis
		local worldOut = origin:VectorToWorldSpace(outward)
		MoveExempt.mark(player.Character, Layout.KNOCKDOWN_TIME + 0.5)
		humanoid.PlatformStand = true
		launch(ctx, root, worldOut * Layout.KNOCK_OUTWARD + Vector3.yAxis * Layout.KNOCK_UP)
		ctx.cleanup:add(task.delay(Layout.KNOCKDOWN_TIME, function()
			-- 그 사이 통과·탈락했으면(탈락 고정은 PlatformStand를 켜 둬요) 손대지 않아요
			if ctx.isActive() and humanoid.Parent and player.Character == humanoid.Parent and isRacer(player) then
				humanoid.PlatformStand = false
			end
		end))
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 장애물 움직임 (판정 전에 위치를 맞춰요)
		for _, chashu in chashus do
			local def = Layout.CHASHUS[chashu.index]
			local top = Logic.chashuHeight(chashu.index, elapsed)
			chashu.part.CFrame = discCFrame(origin, def.x, top, def.z, Layout.CHASHU_THICKNESS)
			local solid = not Logic.chashuSubmerged(chashu.index, elapsed)
			if chashu.part.CanCollide ~= solid then
				chashu.part.CanCollide = solid
			end
		end
		local sweepFrom: { [number]: number } = {}
		for _, sweeper in sweepers do
			sweepFrom[sweeper.index] = sweeper.angle
			sweeper.angle = Logic.sweeperAngle(sweeper.index, elapsed)
			sweeper.part.CFrame = sweeperCFrame(sweeper.hub, sweeper.angle)
		end
		local spin = math.rad(Layout.NARUTO_SPIN_SPEED) * elapsed
		for _, swirl in swirls do
			swirl.part.CFrame = swirl.center * CFrame.Angles(0, spin + swirl.offset, 0)
		end

		-- 판정: 결승선 통과 / 구간 낙하선 아래
		for _, player in ctx.getRacers() do
			local root = rootAndHumanoid(player)
			if root then
				local rel = origin:PointToObjectSpace(root.Position)
				if Logic.progress(rel.Z) >= finishProgress then
					ctx.pass(player)
				elseif rel.Y < Logic.fallLineAt(rel.Z) then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					return -- 이 통과/탈락으로 라운드가 끝났어요
				end
			end
		end

		-- 남은 레이서에게 급류 밀기·막대 넉백
		local current: { [Player]: boolean } = {}
		for _, player in ctx.getRacers() do
			current[player] = true
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)

			local zone = onBroth(root.Position)
			if zone then
				if not inBroth[player] then
					inBroth[player] = true
					MapSfx.play(zone, "SoySlow")
				end
				local push = Logic.pushVector(rel.X, rel.Z)
				local velocity = root.AssemblyLinearVelocity
				local addForward = Logic.pushDelta(velocity:Dot(forward), push.forward, Layout.BROTH_PUSH_ACCEL, dt)
				local addSide = Logic.pushDelta(velocity:Dot(right), push.side, Layout.WHIRLPOOL_PUSH_ACCEL, dt)
				if addForward ~= 0 or addSide ~= 0 then
					root.AssemblyLinearVelocity = velocity + forward * addForward + right * addSide
					exempt(player, now)
				end
			elseif inBroth[player] then
				inBroth[player] = nil
			end

			if humanoid and now - (lastHitAt[player] or -math.huge) >= Layout.KNOCKDOWN_TIME then
				for _, sweeper in sweepers do
					local def = Layout.SWEEPER_LIST[sweeper.index]
					local dx, dz = rel.X, rel.Z - def.z
					local rootY = rel.Y - Layout.platformTop()
					if Logic.sweeperHit(dx, dz, rootY, sweepFrom[sweeper.index], sweeper.angle) then
						lastHitAt[player] = now
						knockBack(player, root, humanoid, dx, dz)
						MapSfx.play(sweeper.part, "SkewerWhoosh")
						break
					end
				end
			end
		end
		-- 통과·탈락해서 빠진 사람은 잊어요
		for player in inBroth do
			if not current[player] then
				inBroth[player] = nil
			end
		end
		for player in lastExempt do
			if not current[player] then
				lastExempt[player] = nil
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "라멘 국물 급류",
	rule = "국물 급류를 타고 차슈·나루토를 밟아 건너, 결승선까지!",
	build = build,
	start = start,
}

return map
