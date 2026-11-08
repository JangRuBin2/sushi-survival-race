--!strict
-- Race 대형 맵 "도시락 뚜껑 대탈출" (m6-04, GDD v0.9 5.2, 제안서 large-maps ②). 폭 80·스폰 40·12~40명.
--   문 줄 5개(BentoDoor 태그): 라운드마다 서버가 진짜 문 자리를 정해요(Logic.pickRealDoors, ctx.rng). 누가 진짜 문에 닿으면
--     그 문이 깨져(충돌 끔·투명) 라운드 내내 열려 있어요 — 앞사람이 길을 열어 줘요. 가짜 문은 그대로 막고 살짝 튕겨 내요.
--   우메보시(BentoBall): 옆으로 굴러와 맞으면 굴러가는 쪽으로 넉백. 간장 웅덩이: 안에서는 수평 속도 상한 9(연속, 면제 없음).
--   회전 젓가락 막대(BentoBar): 4초에 한 바퀴, 점프로 넘기 — 맞으면 회전 방향으로 넉백. 와사비 튕김판: 위·앞으로 튕김.
-- 양옆 도시락 벽이 있어 떨어질 곳은 없어요(낙하선은 안전망으로만). 상태는 전부 start 지역 변수, 태그는 ctx.model 하위만.

local Art = require(script.Parent.BentoDoorDashArt)
local Layout = require(script.Parent.BentoDoorDashLayout)
local Logic = require(script.Parent.BentoDoorDashLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "bento-door-dash"
local TAG_DOOR = "BentoDoor"
local TAG_BALL = "BentoBall"
local TAG_BAR = "BentoBar"
local PARK_Y = -60 -- 쉬는 우메보시를 숨겨 두는 높이 (식탁보 아래)

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

local function ghost(props: { [string]: any }, class: string?): BasePart
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	return makePart(props, class)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.JUDGE_COLORS
	local model = Instance.new("Model")
	model.Name = ID
	local thickness = Layout.FLOOR_THICKNESS
	local length = Layout.COURSE.front - Layout.COURSE.back
	local midZ = (Layout.COURSE.front + Layout.COURSE.back) / 2

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 바닥 (밥 칸처럼 밝은 크림색) + 양옆 도시락 벽
	makePart({
		Name = "BentoFloor",
		Size = Vector3.new(Layout.WIDTH, thickness, length),
		CFrame = at(0, Layout.FLOOR_Y - thickness / 2, midZ),
		Color = rgb(C.floor),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		makePart({
			Name = "BentoSideWall",
			Size = Vector3.new(Layout.SIDE_WALL_THICKNESS, Layout.SIDE_WALL_HEIGHT, length),
			CFrame = at(
				side * (Layout.HALF + Layout.SIDE_WALL_THICKNESS / 2),
				Layout.FLOOR_Y + Layout.SIDE_WALL_HEIGHT / 2,
				midZ
			),
			Color = rgb(C.sideWall),
			Parent = model,
		})
	end

	-- 문 줄: 문 위 가로대 + 문 8칸 (진짜·가짜가 똑같이 보여요)
	for row, wallZ in Layout.DOOR_ROWS_Z do
		local lintelHeight = Layout.WALL_HEIGHT - Layout.DOOR_HEIGHT
		makePart({
			Name = string.format("DoorLintel%d", row),
			Size = Vector3.new(Layout.WIDTH, lintelHeight, Layout.WALL_THICKNESS),
			CFrame = at(0, Layout.FLOOR_Y + Layout.DOOR_HEIGHT + lintelHeight / 2, wallZ),
			Color = rgb(C.divider),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		for door = 1, Layout.DOORS_PER_ROW do
			local part = makePart({
				Name = string.format("Door%d_%d", row, door),
				Size = Vector3.new(Layout.DOOR_WIDTH - 0.2, Layout.DOOR_HEIGHT, Layout.WALL_THICKNESS),
				CFrame = at(Layout.doorX(door), Layout.FLOOR_Y + Layout.DOOR_HEIGHT / 2, wallZ),
				Color = rgb(if door % 2 == 0 then C.doorA else C.doorB),
				Material = Enum.Material.SmoothPlastic,
				Parent = model,
			})
			part:SetAttribute("Row", row)
			part:SetAttribute("Door", door)
			CollectionService:AddTag(part, TAG_DOOR)
		end
	end

	-- 간장 웅덩이 (밟는 면 위 얇은 표시 — 충돌 없음)
	for _, p in Layout.PUDDLES do
		ghost({
			Name = "SoyPuddle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, p.radius * 2, p.radius * 2),
			CFrame = at(p.x, Layout.FLOOR_Y + 0.06, p.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(C.soy),
			Material = Enum.Material.Glass,
			Reflectance = 0.15,
			Parent = model,
		})
	end

	-- 회전 젓가락 막대 (가운데 축은 밟을 수 있고, 막대는 충돌 없음 — 서버가 돌리고 숫자로 맞음 판정)
	local center = Layout.BAR_CENTER
	makePart({
		Name = "BarHub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, Layout.HUB_RADIUS * 2, Layout.HUB_RADIUS * 2),
		CFrame = at(center.x, Layout.FLOOR_Y + 1.5, center.z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(C.hub),
		Parent = model,
	})
	local bar = ghost({
		Name = "ChopstickBar",
		Size = Vector3.new(Layout.BAR_RADIUS * 2, Layout.BAR_THICKNESS, Layout.BAR_THICKNESS),
		CFrame = at(center.x, Layout.FLOOR_Y + Layout.BAR_HEIGHT, center.z),
		Color = rgb(C.bar),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	CollectionService:AddTag(bar, TAG_BAR)

	-- 와사비 튕김판 (밟는 원판)
	for _, pad in Layout.PADS do
		makePart({
			Name = string.format("WasabiPad%d", pad.index),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.PAD_TOP, pad.radius * 2, pad.radius * 2),
			CFrame = at(pad.x, Layout.FLOOR_Y + Layout.PAD_TOP / 2, pad.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(C.pad),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end

	-- 우메보시 (충돌 없음, 처음엔 숨김)
	local balls = Instance.new("Folder")
	balls.Name = "Balls"
	balls.Parent = model
	for slot = 1, Layout.BALL_SLOTS do
		local ball = ghost({
			Name = string.format("Umeboshi%d", slot),
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(Layout.BALL_DIAMETER, Layout.BALL_DIAMETER, Layout.BALL_DIAMETER),
			CFrame = at(0, PARK_Y, 0),
			Color = rgb(C.ball),
			Parent = balls,
		})
		ball:SetAttribute("Slot", slot)
		CollectionService:AddTag(ball, TAG_BALL)
	end

	-- 스폰 40개
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == Layout.CAPACITY, "spawn count must equal capacity")
	for i, pos in positions do
		ghost({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, Layout.FLOOR_Y + 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			Parent = spawns,
		})
	end

	ghost({
		Name = "FinishLine",
		Size = Vector3.new(Layout.WIDTH, 0.4, 1),
		CFrame = at(0, Layout.FLOOR_Y + 0.2, Layout.FINISH_LINE_Z),
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})

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

-- 넉백·튕김: 서버가 LinearVelocity를 잠깐 걸고 이동 감시에서 빼요. down이 있으면 그동안 넘어져 있어요.
local function knock(
	ctx: MapTypes.RoundContext,
	player: Player,
	root: BasePart,
	humanoid: Humanoid?,
	velocity: Vector3,
	exempt: number,
	down: number?
)
	MoveExempt.mark(player.Character, exempt)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "BentoAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "BentoKnock"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(0.15, function()
		push:Destroy()
	end))
	if humanoid and down then
		humanoid.PlatformStand = true
		ctx.cleanup:add(task.delay(down, function()
			if humanoid.Parent == nil or player.Character ~= humanoid.Parent then
				return
			end
			if table.find(ctx.getRacers(), player) then
				humanoid.PlatformStand = false
			end
		end))
	end
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local startedAt = os.clock()
	local finishProgress = Logic.finishProgress()
	local real = Logic.pickRealDoors(ctx.rng)

	local doors: { [string]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_DOOR) do
		local row, door = part:GetAttribute("Row"), part:GetAttribute("Door")
		if type(row) == "number" and type(door) == "number" then
			doors[`{row}:{door}`] = part
		end
	end
	local ballParts: { [number]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_BALL) do
		local slot = part:GetAttribute("Slot")
		if type(slot) == "number" then
			ballParts[slot] = part
		end
	end
	local barPart: BasePart? = nil
	for _, part in taggedParts(ctx, TAG_BAR) do
		barPart = part
	end

	local broken: { [string]: boolean } = {}
	local readyAt: { [Player]: number } = {}
	local padReadyAt: { [Player]: number } = {}
	local wasInPuddle: { [Player]: boolean } = {}
	local park = origin * CFrame.new(0, PARK_Y, 0)
	local center = Layout.BAR_CENTER
	local forward = origin.LookVector -- 결승 쪽 (-z)

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(_dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 판정: 결승선 / 안전망 낙하
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
					return
				end
			end
		end

		-- 2. 우메보시·막대 옮기기
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local balls = Logic.balls(elapsed)
		local busy: { [number]: boolean } = {}
		for _, b in balls do
			local part = ballParts[b.slot]
			if part then
				busy[b.slot] = true
				local spin = b.x / (Layout.BALL_DIAMETER / 2)
				table.insert(moveParts, part)
				table.insert(
					moveFrames,
					origin
						* CFrame.new(b.x, Layout.FLOOR_Y + Layout.BALL_DIAMETER / 2, b.z)
						* CFrame.Angles(0, 0, -spin)
				)
			end
		end
		for slot, part in ballParts do
			if not busy[slot] then
				table.insert(moveParts, part)
				table.insert(moveFrames, park)
			end
		end
		local angle = Logic.barAngle(elapsed)
		if barPart then
			table.insert(moveParts, barPart)
			-- 막대 길이 방향(로컬 X)을 (cos, sin) 쪽으로: Y축으로 −angle 돌려요 (위에서 볼 때 시계 방향)
			table.insert(
				moveFrames,
				origin
					* CFrame.new(center.x, Layout.FLOOR_Y + Layout.BAR_HEIGHT, center.z)
					* CFrame.Angles(0, -angle, 0)
			)
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 3. 남은 레이서
		for _, player in ctx.getRacers() do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local foot = rel.Y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
			local ready = (readyAt[player] or 0) <= now

			-- 문: 진짜면 깨고, 가짜면 튕겨 내요
			local row, door = Logic.doorAt(rel.X, rel.Z)
			if row and door and foot < Layout.DOOR_HEIGHT then
				local key = `{row}:{door}`
				local part = doors[key]
				if real[row][door] then
					if not broken[key] and part then
						broken[key] = true
						part.CanCollide = false
						part.CanQuery = false
						part.Transparency = 1
						MapSfx.play(part, "DoorBurst")
					end
				elseif ready and part then
					readyAt[player] = now + Layout.FAKE_COOLDOWN
					knock(
						ctx,
						player,
						root,
						humanoid,
						-forward * Layout.FAKE_KNOCK_BACK + Vector3.new(0, Layout.FAKE_KNOCK_UP, 0),
						Layout.FAKE_EXEMPT,
						nil
					)
					MapSfx.play(part, "BounceBoing")
					continue
				end
			end

			-- 회전 막대
			if ready then
				local dx, dz = rel.X - center.x, rel.Z - center.z
				if Logic.barHit(dx, dz, foot, angle) then
					local tx, tz = Logic.barKnock(dx, dz, angle)
					local dir = origin:VectorToWorldSpace(Vector3.new(tx, 0, tz))
					readyAt[player] = now + Layout.BAR_COOLDOWN
					knock(
						ctx,
						player,
						root,
						humanoid,
						dir * Layout.BAR_KNOCK + Vector3.new(0, Layout.BAR_KNOCK_UP, 0),
						Layout.BAR_EXEMPT,
						Layout.BAR_DOWN
					)
					MapSfx.play(root, "Knockdown")
					continue
				end
				-- 우메보시
				for _, b in balls do
					if Logic.ballHit(rel.X - b.x, rel.Z - b.z, foot) then
						local dir = origin:VectorToWorldSpace(Vector3.new(b.dir, 0, 0))
						readyAt[player] = now + Layout.BAR_COOLDOWN
						knock(
							ctx,
							player,
							root,
							humanoid,
							dir * Layout.BALL_KNOCK_SIDE + Vector3.new(0, Layout.BALL_KNOCK_UP, 0),
							Layout.BALL_EXEMPT,
							Layout.BALL_DOWN
						)
						MapSfx.play(root, "Knockdown")
						break
					end
				end
			end

			-- 와사비 튕김판
			if (padReadyAt[player] or 0) <= now then
				local pad = Logic.padAt(rel.X, rel.Y, rel.Z)
				if pad then
					padReadyAt[player] = now + Layout.PAD_COOLDOWN
					knock(
						ctx,
						player,
						root,
						humanoid,
						forward * Layout.PAD_LAUNCH_FORWARD + Vector3.new(0, Layout.PAD_LAUNCH_UP, 0),
						Layout.PAD_EXEMPT,
						nil
					)
					MapSfx.play(root, "WasabiBoing")
					continue
				end
			end

			-- 간장 웅덩이: 수평 속도 상한 (연속, 면제 없음)
			local inside = Logic.inPuddle(rel.X, rel.Y, rel.Z)
			if inside then
				local local3 = origin:VectorToObjectSpace(root.AssemblyLinearVelocity)
				local vx, vz = Logic.slowVelocity(local3.X, local3.Z)
				if vx ~= local3.X or vz ~= local3.Z then
					root.AssemblyLinearVelocity = origin:VectorToWorldSpace(Vector3.new(vx, local3.Y, vz))
				end
				if not wasInPuddle[player] then
					MapSfx.play(root, "SoySlow")
				end
			end
			wasInPuddle[player] = inside
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "도시락 뚜껑 대탈출",
	rule = "진짜 뚜껑 문을 찾아 부수고 도시락 끝까지 달려요! 가짜 문은 튕겨 나와요.",
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 한낮 벚꽃 아래 피크닉
	capacity = Layout.CAPACITY,
	minPlayers = Layout.MIN_PLAYERS,
}

return map
