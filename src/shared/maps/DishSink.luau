--!strict
-- Race 맵 "깨끗하게! 설거지통" (m5-34, GDD §5.3 3차 배치). 업소용 개수대 속 설거지물 위를 달려 건조대의 깨끗한 접시까지.
--   B·E 회전 접시(SinkPlate 태그): 판정 파츠는 고정이고, 서버가 접시 위 사람을 접선 방향으로 밀어요(회전 벨트와 같은
--     연속 밀기 — MoveExempt 없음). 도는 느낌은 접시 아래 테두리 장식의 Spin anim(클라이언트)으로만 보여 줘요(스펙 D2).
--   C·E·F 수세미(SinkSponge 태그): 충돌·쿼리·터치 없음. 서버가 매 Heartbeat CFrame으로 x 왕복시키고, 맞음은 숫자로 판정해
--     옆으로 넉백(LinearVelocity 잠깐 + PlatformStand + MoveExempt)해요(스펙 D3).
-- 치수는 DishSinkLayout, 계산은 DishSinkLogic, 장식은 DishSinkArt.
-- 태그 파츠는 ctx.model 하위의 것만 쓰고, 상태는 전부 start 안 지역 변수에 둬요(여러 방 동시 진행).
-- id·kind·displayName·rule은 GDD §5.3(v0.7)에서 확정이에요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.DishSinkArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.DishSinkLayout)
local Logic = require(script.Parent.DishSinkLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "dish-sink"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
local TAG_PLATE = "SinkPlate"
local TAG_SPONGE = "SinkSponge"

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }, class: string?): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new(class or "Part") :: BasePart
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

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.JUDGE_COLORS
	local model = Instance.new("Model")
	model.Name = ID
	local thickness = Layout.FLOOR_THICKNESS

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 직사각형 바닥 (조리대·칸막이·다리·복도·건조대)
	for _, rect in Layout.floorRects() do
		local isSteel = rect.name ~= "StartCounter" and rect.name ~= "DryingRack"
		makePart({
			Name = rect.name,
			Size = Vector3.new(rect.maxX - rect.minX, thickness, rect.maxZ - rect.minZ),
			CFrame = at((rect.minX + rect.maxX) / 2, rect.top - thickness / 2, (rect.minZ + rect.maxZ) / 2),
			Color = rgb(
				if rect.name == "StartCounter"
					then C.counter
					elseif rect.name == "DryingRack" then C.rack
					else C.steelTop
			),
			Material = if isSteel then Enum.Material.Metal else Enum.Material.SmoothPlastic,
			Reflectance = if isSteel then 0.08 else 0,
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
	end

	-- G 오르막: 아래 받침 + 쐐기 (높은 쪽이 결승 쪽 -Z)
	local rampLength = Layout.RAMP.front - Layout.RAMP.back
	local rampZ = (Layout.RAMP.front + Layout.RAMP.back) / 2
	makePart({
		Name = "RampBase",
		Size = Vector3.new(Layout.FINISH_WIDTH, thickness, rampLength),
		CFrame = at(0, Layout.HIGH_Y - thickness / 2, rampZ),
		Color = rgb(C.rack),
		Parent = model,
	})
	makePart({
		Name = "Ramp",
		Size = Vector3.new(Layout.FINISH_WIDTH, Layout.FINISH_Y - Layout.HIGH_Y, rampLength),
		CFrame = at(0, (Layout.HIGH_Y + Layout.FINISH_Y) / 2, rampZ) * CFrame.Angles(0, math.pi, 0),
		Color = rgb(C.rack),
		Parent = model,
	}, "WedgePart")

	-- 출발 스폰 24개
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == MAX_PLAYERS, "spawn count must cover the largest room size")
	for i, pos in positions do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, Layout.LOW_Y + 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end

	-- 회전 접시 (고정 원판 — 밟는 면은 무늬 없는 흰색)
	for _, plate in Layout.PLATES do
		local d = plate.kind.radius * 2
		local part = makePart({
			Name = string.format("SinkPlate%02d", plate.index),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.PLATE_THICKNESS, d, d),
			CFrame = at(plate.x, plate.top - Layout.PLATE_THICKNESS / 2, plate.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(C.plate),
			Reflectance = 0.06,
			Parent = model,
		})
		part:SetAttribute("PlateIndex", plate.index)
		part:SetAttribute("PlateDirection", plate.dir)
		CollectionService:AddTag(part, TAG_PLATE)
	end

	-- D 엎어 둔 컵·밥공기 (고정)
	for _, cup in Layout.CUP_LIST do
		local d = cup.radius * 2
		makePart({
			Name = string.format("Cup%d", cup.index),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.CUP_HEIGHT, d, d),
			CFrame = at(cup.x, cup.top - Layout.CUP_HEIGHT / 2, cup.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(if cup.index % 2 == 0 then C.cupA else C.cupB),
			Reflectance = 0.05,
			Parent = model,
		})
	end

	-- 결승선 (건조대 위)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
		CFrame = at(0, Layout.FINISH_Y + 0.2, Layout.FINISH_LINE_Z),
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	-- 수세미 (충돌 없음, 서버가 옮겨요). 몸통 파츠에 태그·번호, 거품 파티클(Emit 전용)
	local spongeFolder = Instance.new("Folder")
	spongeFolder.Name = "Sponges"
	spongeFolder.Parent = model
	for _, sponge in Layout.SPONGES do
		local holder = Instance.new("Model")
		holder.Name = string.format("Sponge%d", sponge.index)
		holder.Parent = spongeFolder
		local center = at(Logic.spongeX(sponge.index, 0), sponge.floorY + sponge.sizeY / 2, sponge.z)
		local parts = MapKit.buildDecor(Art.spongeSpecs(sponge), center, holder)
		local body = holder:FindFirstChild(Art.SPONGE_BODY)
		if body and body:IsA("BasePart") then
			body:SetAttribute("SpongeIndex", sponge.index)
			CollectionService:AddTag(body, TAG_SPONGE)
			local foam = MapKit.makeEmitter("SoapFoam", 0)
			foam.Name = "SpongeFoam"
			foam.Enabled = false
			foam.Parent = body
		end
		assert(#parts > 0, "sponge decor must build")
	end

	-- 장식(충돌 없음) + 소개 카메라 + 사용자 Studio 아트 자리
	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

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

-- 넉백: 캐릭터 물리는 그 클라이언트가 맡아서 서버가 LinearVelocity를 잠깐 걸어요 (와사비·젤리와 같은 방식)
local function knock(ctx: MapTypes.RoundContext, player: Player, root: BasePart, humanoid: Humanoid?, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "SpongeAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "SpongeKnock"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(Layout.SPONGE_KNOCK_HOLD, function()
		push:Destroy()
	end))
	if humanoid then
		humanoid.PlatformStand = true
		ctx.cleanup:add(task.delay(Layout.SPONGE_KNOCKDOWN, function()
			-- 그 사이 통과·탈락했으면 손대지 않아요 (탈락 고정은 PlatformStand를 켜 둬요)
			if humanoid.Parent == nil or player.Character ~= humanoid.Parent then
				return
			end
			if table.find(ctx.getRacers(), player) then
				humanoid.PlatformStand = false
			end
		end))
	end
end

type SpongeRig = { index: number, body: BasePart, parts: { BasePart }, rel: { CFrame }, foam: ParticleEmitter? }

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local right = origin.RightVector
	local startedAt = os.clock()
	local finishProgress = Logic.finishProgress()

	-- 수세미 묶음: 몸통 기준 상대 CFrame을 기억해 두고 몸통 자리만 계산해요
	local rigs: { SpongeRig } = {}
	for _, body in taggedParts(ctx, TAG_SPONGE) do
		local index = body:GetAttribute("SpongeIndex")
		local holder = body.Parent
		if type(index) ~= "number" or holder == nil or Layout.SPONGES[index] == nil then
			continue
		end
		local parts: { BasePart } = {}
		local rel: { CFrame } = {}
		for _, d in holder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				table.insert(rel, (body.CFrame:ToObjectSpace(d.CFrame)))
			end
		end
		local foam = body:FindFirstChild("SpongeFoam")
		table.insert(rigs, {
			index = index,
			body = body,
			parts = parts,
			rel = rel,
			foam = if foam and foam:IsA("ParticleEmitter") then foam else nil,
		})
	end
	local bodyRotation = {} :: { [number]: CFrame }
	for _, rig in rigs do
		bodyRotation[rig.index] = origin:ToObjectSpace(rig.body.CFrame).Rotation
	end

	local hitReadyAt: { [Player]: number } = {}

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 판정: 결승선 통과 / 낙하
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

		-- 2. 수세미 옮기기 (한 번에)
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local spongeXs: { [number]: number } = {}
		for _, rig in rigs do
			local sponge = Layout.SPONGES[rig.index]
			local x = Logic.spongeX(rig.index, elapsed)
			spongeXs[rig.index] = x
			local bodyFrame = origin
				* CFrame.new(x, sponge.floorY + sponge.sizeY / 2, sponge.z)
				* (bodyRotation[rig.index] or CFrame.identity)
			for k, part in rig.parts do
				table.insert(moveParts, part)
				table.insert(moveFrames, bodyFrame * rig.rel[k])
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 3. 남은 레이서: 수세미 맞음, 접시 밀기
		for _, player in ctx.getRacers() do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)

			local hit = false
			for _, rig in rigs do
				local sponge = Layout.SPONGES[rig.index]
				local dx = rel.X - spongeXs[rig.index]
				local dz = rel.Z - sponge.z
				local foot = rel.Y - Layout.FOOT_OFFSET - sponge.floorY
				if Logic.spongeHit(dx, dz, foot, sponge.sizeX, sponge.sizeZ) then
					hit = true
					local readyAt = hitReadyAt[player]
					if readyAt == nil or now >= readyAt then
						hitReadyAt[player] = now + Layout.SPONGE_COOLDOWN
						local side = Logic.knockDirection(Logic.spongeVelocity(rig.index, elapsed), dx)
						local velocity = right * (side * Layout.SPONGE_KNOCK_SIDE)
							+ Vector3.new(0, Layout.SPONGE_KNOCK_UP, 0)
						-- 큰 넉백: 날아가 착지할 때까지 이동 감시(m4-10)에서 빼요
						MoveExempt.mark(player.Character, Layout.SPONGE_EXEMPT)
						knock(ctx, player, root, humanoid, velocity)
						MapSfx.play(rig.body, "SpongeSquish")
						if rig.foam then
							rig.foam:Emit(12)
						end
					end
					break
				end
			end
			if hit then
				continue
			end

			local plate = Logic.plateAt(rel.X, rel.Y, rel.Z)
			if plate then
				local vx, vz = Logic.platePush(rel.X - plate.x, rel.Z - plate.z, plate.dir, plate.kind)
				if vx and vz then
					local target = origin:VectorToWorldSpace(Vector3.new(vx, 0, vz))
					local speed = target.Magnitude
					if speed > 1e-3 then
						local unit = target / speed
						local velocity = root.AssemblyLinearVelocity
						local add = Logic.pushDelta(velocity:Dot(unit), speed, Layout.PUSH_ACCEL, dt)
						if add ~= 0 then
							root.AssemblyLinearVelocity = velocity + unit * add
						end
					end
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "깨끗하게! 설거지통",
	rule = "빙글빙글 접시와 움직이는 수세미를 피해 깨끗한 접시까지 달려요!",
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 한낮 업소용 주방, 햇살 드는 스테인리스 개수대
}

return map
