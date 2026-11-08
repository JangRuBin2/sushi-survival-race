--!strict
-- Survival 대형 맵 "중식당 회전 원판" (m6-06, GDD v0.9 5.2, 제안서 large-maps ④). 반지름 72·스폰 40·12~40명·75초.
--   고리 4개(SusanSegment 태그, 10° 조각 × 36 × 4): 판정 조각은 고정이고, 서버가 고리와 같이 도는 구멍 구간을 계산해
--     곧 열릴 조각은 빨갛게(Warn), 구멍 안 조각은 충돌을 끄고 거의 투명하게(Open), 지나가면 다시 닫아요(Solid).
--   고리 위 사람은 회전 방향으로 연속 밀기(MoveExempt 없음 — 회전 벨트와 같은 규칙).
--   반찬 그릇(SusanBowl 태그, 충돌 없음): 서버가 고리와 같이 돌리고, 닿으면 회전 방향으로 밀려나요(MoveExempt).
--   가운데 유리판(SusanCenter)은 서든데스부터 5초마다 빨갛게 → 1.5초 열려요.
--   떨어지면(낙하선 -12) 탈락. 75초 버티면 통과(Survival 규칙), 60초부터 서든데스(구멍 폭 40° → 70°).
-- 상태는 전부 start 지역 변수, 태그는 ctx.model 하위만.

local Art = require(script.Parent.LazySusanArt)
local Layout = require(script.Parent.LazySusanLayout)
local Logic = require(script.Parent.LazySusanLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "lazy-susan"
local TAG_SEGMENT = "SusanSegment"
local TAG_BOWL = "SusanBowl"
local TAG_CENTER = "SusanCenter"
local CENTER_TRANSPARENCY = 0.15
local OPEN_TRANSPARENCY = 0.9

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

-- 조각 CFrame: 반지름 방향이 로컬 X, 가운데가 반지름 rMid
local function segmentFrame(origin: CFrame, ring: Layout.Ring, k: number): CFrame
	local a = math.rad(Layout.segmentAngle(k))
	local rMid = (ring.inner + ring.outer) / 2
	return origin * CFrame.Angles(0, -a, 0) * CFrame.new(rMid, Layout.FLOOR_Y - Layout.FLOOR_THICKNESS / 2, 0)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.JUDGE_COLORS
	local model = Instance.new("Model")
	model.Name = ID

	-- 가운데 고정 유리판
	local center = makePart({
		Name = "CenterGlass",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Layout.FLOOR_THICKNESS, Layout.CENTER_RADIUS * 2, Layout.CENTER_RADIUS * 2),
		CFrame = origin
			* CFrame.new(0, Layout.FLOOR_Y - Layout.FLOOR_THICKNESS / 2, 0)
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(C.center),
		Material = Enum.Material.Glass,
		Transparency = CENTER_TRANSPARENCY,
		Parent = model,
	})
	CollectionService:AddTag(center, TAG_CENTER)

	-- 고리 조각
	local rings = Instance.new("Folder")
	rings.Name = "Rings"
	rings.Parent = model
	for _, ring in Layout.RINGS do
		local rMid = (ring.inner + ring.outer) / 2
		local chord = 2 * rMid * math.sin(math.rad(Layout.SEGMENT_DEG / 2)) * 1.06 + 0.4 -- 이음새 겹침
		for k = 1, Layout.SEGMENTS do
			local part = makePart({
				Name = string.format("Ring%d_%02d", ring.index, k),
				Size = Vector3.new(ring.outer - ring.inner, Layout.FLOOR_THICKNESS, chord),
				CFrame = segmentFrame(origin, ring, k),
				Color = rgb(Art.ringColor(ring.index, k)),
				Material = Enum.Material.SmoothPlastic,
				Parent = rings,
			})
			part:SetAttribute("Ring", ring.index)
			part:SetAttribute("Segment", k)
			CollectionService:AddTag(part, TAG_SEGMENT)
		end
	end

	-- 반찬 그릇 (충돌 없음 — 서버가 돌려요)
	local bowls = Instance.new("Folder")
	bowls.Name = "Bowls"
	bowls.Parent = model
	for _, bowl in Layout.BOWLS do
		local x, z = Logic.bowlPosition(bowl, 0)
		local d = Layout.BOWL_RADIUS * 2
		local part = ghost({
			Name = string.format("Bowl%d", bowl.index),
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d * 0.7, d),
			CFrame = origin * CFrame.new(x, Layout.FLOOR_Y + d * 0.2, z),
			Color = rgb(C.bowl),
			Parent = bowls,
		})
		part:SetAttribute("Bowl", bowl.index)
		CollectionService:AddTag(part, TAG_BOWL)
	end

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == Layout.CAPACITY, "spawn count must equal capacity")
	for i, pos in positions do
		ghost({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(pos.x, Layout.FLOOR_Y + 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			Parent = spawns,
		})
	end

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

local function knock(ctx: MapTypes.RoundContext, player: Player, root: BasePart, humanoid: Humanoid?, velocity: Vector3)
	MoveExempt.mark(player.Character, Layout.BOWL_EXEMPT)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "SusanAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "SusanKnock"
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
	if humanoid then
		humanoid.PlatformStand = true
		ctx.cleanup:add(task.delay(Layout.BOWL_DOWN, function()
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
	local C = Art.JUDGE_COLORS
	local startedAt = os.clock()

	type Seg = { part: BasePart, ring: Layout.Ring, k: number, state: Logic.SegmentState }
	local segments: { Seg } = {}
	for _, part in taggedParts(ctx, TAG_SEGMENT) do
		local ringIndex, k = part:GetAttribute("Ring"), part:GetAttribute("Segment")
		if type(ringIndex) == "number" and type(k) == "number" and Layout.RINGS[ringIndex] then
			local seg: Seg = { part = part, ring = Layout.RINGS[ringIndex], k = k, state = "Solid" }
			table.insert(segments, seg)
		end
	end
	local bowlParts: { [number]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_BOWL) do
		local index = part:GetAttribute("Bowl")
		if type(index) == "number" then
			bowlParts[index] = part
		end
	end
	local centers = taggedParts(ctx, TAG_CENTER)
	local centerState: Logic.SegmentState = "Solid"
	local readyAt: { [Player]: number } = {}

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 낙하 탈락
		for _, player in ctx.getRacers() do
			local root = rootAndHumanoid(player)
			if root then
				local rel = origin:PointToObjectSpace(root.Position)
				if rel.Y < Logic.fallLine() then
					ctx.eliminate(player)
					if not ctx.isActive() then
						return
					end
				end
			end
		end

		-- 2. 조각 상태 바꾸기 (바뀐 것만)
		local opened: BasePart? = nil
		for _, seg in segments do
			local state = Logic.segmentState(seg.ring, seg.k, elapsed)
			if state ~= seg.state then
				seg.state = state
				local part = seg.part
				if state == "Open" then
					part.CanCollide = false
					part.CanQuery = false
					part.Transparency = OPEN_TRANSPARENCY
					opened = opened or part
				else
					part.CanCollide = true
					part.CanQuery = true
					part.Transparency = 0
					part.Color = rgb(if state == "Warn" then C.warn else Art.ringColor(seg.ring.index, seg.k))
				end
			end
		end
		local nextCenter = Logic.centerState(elapsed)
		if nextCenter ~= centerState then
			centerState = nextCenter
			for _, part in centers do
				part.CanCollide = nextCenter ~= "Open"
				part.CanQuery = nextCenter ~= "Open"
				part.Transparency = if nextCenter == "Open" then OPEN_TRANSPARENCY else CENTER_TRANSPARENCY
				part.Color = rgb(if nextCenter == "Warn" then C.warn else C.center)
				if nextCenter == "Open" then
					opened = opened or part
				end
			end
		end
		if opened then
			MapSfx.play(opened, "TileVanish")
		end

		-- 3. 그릇 돌리기
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local bowlXZ: { [number]: { x: number, z: number } } = {}
		for _, bowl in Layout.BOWLS do
			local part = bowlParts[bowl.index]
			if part then
				local x, z = Logic.bowlPosition(bowl, elapsed)
				bowlXZ[bowl.index] = { x = x, z = z }
				table.insert(moveParts, part)
				table.insert(moveFrames, origin * CFrame.new(x, Layout.FLOOR_Y + Layout.BOWL_RADIUS * 0.4, z))
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 4. 남은 사람: 그릇 맞음, 고리 밀기
		for _, player in ctx.getRacers() do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local foot = rel.Y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
			if (readyAt[player] or 0) <= now then
				local hit = false
				for _, bowl in Layout.BOWLS do
					local p = bowlXZ[bowl.index]
					if p and Logic.bowlHit(rel.X - p.x, rel.Z - p.z, foot) then
						local ring = Layout.RINGS[bowl.ring]
						local tx, tz = Logic.tangent(p.x, p.z, ring.dir)
						local dir = origin:VectorToWorldSpace(Vector3.new(tx, 0, tz))
						readyAt[player] = now + Layout.BOWL_COOLDOWN
						knock(
							ctx,
							player,
							root,
							humanoid,
							dir * Layout.BOWL_KNOCK + Vector3.new(0, Layout.BOWL_KNOCK_UP, 0)
						)
						MapSfx.play(root, "Knockdown")
						hit = true
						break
					end
				end
				if hit then
					continue
				end
			end
			local ring = Logic.ringAt(rel.X, rel.Y, rel.Z)
			if ring then
				local tx, tz = Logic.tangent(rel.X, rel.Z, ring.dir)
				local speed = Logic.pushSpeed(ring, math.sqrt(rel.X * rel.X + rel.Z * rel.Z), elapsed)
				local unit = origin:VectorToWorldSpace(Vector3.new(tx, 0, tz))
				local velocity = root.AssemblyLinearVelocity
				local add = Logic.pushDelta(velocity:Dot(unit), speed, Layout.PUSH_ACCEL, dt)
				if add ~= 0 then
					root.AssemblyLinearVelocity = velocity + unit * add
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "중식당 회전 원판",
	rule = "빙글빙글 도는 원판의 구멍을 피해 끝까지 버텨요! 빨간 칸은 곧 사라져요.",
	timeLimit = Layout.TIME_LIMIT, -- 75초, 60초부터 서든데스 (m5-40 규칙과 같아요)
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 붉은 등이 걸린 저녁 중식당
	capacity = Layout.CAPACITY,
	minPlayers = Layout.MIN_PLAYERS,
}

return map
