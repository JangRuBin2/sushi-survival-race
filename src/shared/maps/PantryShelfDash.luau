--!strict
-- Race 대형 맵 "팬트리 선반 대질주" (m6-05, GDD v0.9 5.2, 제안서 large-maps ③). 폭 96·스폰 40·12~40명.
--   선반 섬 5줄: 고정 나무판, 줄 사이 틈 8 (점프·다이브). 떨어지면 Race 부활.
--   환풍기 옆바람(PantryWind 태그 줄무늬): 줄마다 4초 켜짐/2초 꺼짐, 방향 번갈아. 켜지면 줄무늬가 보이고 FanGust 소리.
--     바람은 연속 밀기라 MoveExempt 없음(송풍구와 같은 규칙).
--   통조림(PantryCan 태그): 2·4번째 줄 선반마다 결승 쪽 끝에서 굴러와요. 맞으면 뒤로 넘어짐(MoveExempt).
-- 상태는 전부 start 지역 변수, 태그는 ctx.model 하위만.

local Art = require(script.Parent.PantryShelfDashArt)
local Layout = require(script.Parent.PantryShelfDashLayout)
local Logic = require(script.Parent.PantryShelfDashLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "pantry-shelf-dash"
local TAG_WIND = "PantryWind"
local TAG_CAN = "PantryCan"
local PARK_Y = -70 -- 쉬는 통조림을 숨겨 두는 높이 (팬트리 바닥 아래)
local WIND_SHOWN = 0.72 -- 바람 줄무늬 투명도 (켜짐)

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

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	for _, rect in Layout.floorRects() do
		local color = if rect.name == "FinishLid" then C.lid elseif rect.name == "StartShelf" then C.start else C.shelf
		makePart({
			Name = rect.name,
			Size = Vector3.new(rect.maxX - rect.minX, thickness, rect.maxZ - rect.minZ),
			CFrame = at((rect.minX + rect.maxX) / 2, rect.top - thickness / 2, (rect.minZ + rect.maxZ) / 2),
			Color = rgb(color),
			Material = if rect.name == "FinishLid" then Enum.Material.Metal else Enum.Material.WoodPlanks,
			Parent = model,
		})
	end

	-- 바람 줄무늬 (줄마다 3가닥 × 2높이, 처음엔 안 보임 — 서버가 켜고 꺼요)
	local winds = Instance.new("Folder")
	winds.Name = "Winds"
	winds.Parent = model
	for _, row in Layout.ROWS do
		local depth = row.front - row.back
		for k = 1, 3 do
			for _, y in { 3, 7.5 } do
				local streak = ghost({
					Name = "WindStreak",
					Size = Vector3.new(Layout.WIDTH - 6, 0.25, 1.2),
					CFrame = at(0, Layout.FLOOR_Y + y, row.front - depth * k / 4),
					Color = rgb(C.wind),
					Material = Enum.Material.Neon,
					Transparency = 1,
					Parent = winds,
				})
				streak:SetAttribute("Row", row.index)
				CollectionService:AddTag(streak, TAG_WIND)
			end
		end
	end

	-- 통조림 (충돌 없음, 처음엔 숨김)
	local cans = Instance.new("Folder")
	cans.Name = "Cans"
	cans.Parent = model
	for _, shelf in Layout.SHELVES do
		if not Layout.ROWS[shelf.row].cans then
			continue
		end
		for slot = 1, Layout.CAN_SLOTS do
			local can = ghost({
				Name = string.format("Can%d_%d", shelf.index, slot),
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(Layout.CAN_LENGTH, Layout.CAN_DIAMETER, Layout.CAN_DIAMETER),
				CFrame = at(0, PARK_Y, 0),
				Color = rgb(if slot % 2 == 0 then C.canA else C.canB),
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
				Parent = cans,
			})
			can:SetAttribute("Shelf", shelf.index)
			can:SetAttribute("Slot", slot)
			CollectionService:AddTag(can, TAG_CAN)
		end
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
			CFrame = at(pos.x, Layout.FLOOR_Y + 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			Parent = spawns,
		})
	end

	ghost({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
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

local function knock(ctx: MapTypes.RoundContext, player: Player, root: BasePart, humanoid: Humanoid?, velocity: Vector3)
	MoveExempt.mark(player.Character, Layout.CAN_EXEMPT)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "PantryAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "PantryKnock"
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
		ctx.cleanup:add(task.delay(Layout.CAN_DOWN, function()
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

	local streaks: { [number]: { BasePart } } = {}
	for _, part in taggedParts(ctx, TAG_WIND) do
		local row = part:GetAttribute("Row")
		if type(row) == "number" then
			streaks[row] = streaks[row] or {}
			table.insert(streaks[row], part)
		end
	end
	local canParts: { [string]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_CAN) do
		local shelf, slot = part:GetAttribute("Shelf"), part:GetAttribute("Slot")
		if type(shelf) == "number" and type(slot) == "number" then
			canParts[`{shelf}:{slot}`] = part
		end
	end

	local windShown: { [number]: boolean } = {}
	local readyAt: { [Player]: number } = {}
	local park = origin * CFrame.new(0, PARK_Y, 0)
	local backVector = -origin.LookVector -- +z (출발 쪽)
	local sideVector = origin.RightVector

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 판정
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

		-- 2. 바람 줄무늬 켜고 끄기
		for _, row in Layout.ROWS do
			local on = Logic.windOn(row, elapsed)
			if windShown[row.index] ~= on then
				windShown[row.index] = on
				local list = streaks[row.index] or {}
				for _, part in list do
					part.Transparency = if on then WIND_SHOWN else 1
				end
				if on and list[1] then
					MapSfx.play(list[1], "FanGust")
				end
			end
		end

		-- 3. 통조림 옮기기
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local cans = Logic.cans(elapsed)
		local busy: { [string]: boolean } = {}
		for _, can in cans do
			local key = `{can.shelf}:{can.slot}`
			local part = canParts[key]
			if part then
				busy[key] = true
				local spin = can.z / (Layout.CAN_DIAMETER / 2)
				table.insert(moveParts, part)
				table.insert(
					moveFrames,
					origin
						* CFrame.new(can.x, Layout.FLOOR_Y + Layout.CAN_DIAMETER / 2, can.z)
						* CFrame.Angles(spin, 0, 0)
				)
			end
		end
		for key, part in canParts do
			if not busy[key] then
				table.insert(moveParts, part)
				table.insert(moveFrames, park)
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 4. 남은 레이서: 통조림 맞음, 바람
		for _, player in ctx.getRacers() do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local foot = rel.Y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
			if (readyAt[player] or 0) <= now then
				local hit = false
				for _, can in cans do
					if Logic.rollHit(rel.X - can.x, rel.Z - can.z, foot) then
						readyAt[player] = now + Layout.HIT_COOLDOWN
						knock(
							ctx,
							player,
							root,
							humanoid,
							backVector * Layout.CAN_KNOCK_BACK + Vector3.new(0, Layout.CAN_KNOCK_UP, 0)
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
			local row = Logic.rowAt(rel.Z)
			if row and foot <= Layout.WIND_HEIGHT then
				local target = Logic.windTarget(row, elapsed)
				if target ~= 0 then
					local unit = if target > 0 then sideVector else -sideVector
					local velocity = root.AssemblyLinearVelocity
					local add = Logic.pushDelta(velocity:Dot(unit), math.abs(target), Layout.WIND_ACCEL, dt)
					if add ~= 0 then
						root.AssemblyLinearVelocity = velocity + unit * add
					end
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "팬트리 선반 대질주",
	rule = "옆바람과 굴러오는 통조림을 피해 선반 사이를 뛰어 큰 병뚜껑까지!",
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 오후 햇살 드는 식료품 창고
	capacity = Layout.CAPACITY,
	minPlayers = Layout.MIN_PLAYERS,
}

return map
