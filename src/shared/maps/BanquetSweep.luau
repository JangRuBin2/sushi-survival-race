--!strict
-- Survival 대형 맵 "연회상 쟁반 쓸기" (m6-07, GDD v0.9 5.2, 제안서 large-maps ⑤). 96 × 96·스폰 40·12~40명·75초.
--   다다미 타일 8 × 8(BanquetTile, 속성 I·J·Outer): 45초에 바깥 한 줄이 무너져(1.5초 전 빨강) 72 × 72.
--   쟁반 벽(BanquetWall, 풀 6자리 × 8칸, 충돌 없음): 판마다 ctx.rng로 만든 일정대로 변 끝에서 반대편 끝까지 밀고 가요.
--     낮은 벽은 점프로 넘고, 높은 벽은 빈 칸으로 피해요. 닿으면 벽 진행 방향으로 넘어짐(MoveExempt) — 상 밖까지 밀려요.
--   예고 줄(BanquetWarn, 변 4 × 8칸): 벽이 오기 1.5초 전 그 변에 벽 칸 노랑 · 빈 칸 초록.
--   떨어지면(낙하선 -12) 탈락. 75초 버티면 통과(Survival 규칙), 60초부터 서든데스(4초마다 두 장·빈 칸 1개).
-- 상태는 전부 start 지역 변수, 태그는 ctx.model 하위만.

local Art = require(script.Parent.BanquetSweepArt)
local Layout = require(script.Parent.BanquetSweepLayout)
local Logic = require(script.Parent.BanquetSweepLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "banquet-sweep"
local TAG_TILE = "BanquetTile"
local TAG_WALL = "BanquetWall"
local TAG_WARN = "BanquetWarn"
local WARN_TRANSPARENCY = 0.1
local PARK_Y = -200

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

-- 예고 줄 칸 자리 (변 안쪽 끝, 바닥 + 0.2)
local function warnFrame(origin: CFrame, side: string, lane: number, half: number): (CFrame, Vector3)
	local c = Layout.laneCenter(lane)
	local inset = half - 1.5
	local y = Layout.FLOOR_Y + 0.2
	if side == "XNeg" then
		return origin * CFrame.new(-inset, y, c), Vector3.new(3, 0.4, Layout.TILE - 0.6)
	elseif side == "XPos" then
		return origin * CFrame.new(inset, y, c), Vector3.new(3, 0.4, Layout.TILE - 0.6)
	elseif side == "ZNeg" then
		return origin * CFrame.new(c, y, -inset), Vector3.new(Layout.TILE - 0.6, 0.4, 3)
	end
	return origin * CFrame.new(c, y, inset), Vector3.new(Layout.TILE - 0.6, 0.4, 3)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.JUDGE_COLORS
	local model = Instance.new("Model")
	model.Name = ID

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = model
	for i = 1, Layout.LANES do
		for j = 1, Layout.LANES do
			local part = makePart({
				Name = string.format("Tile%d_%d", i, j),
				Size = Vector3.new(Layout.TILE, Layout.FLOOR_THICKNESS, Layout.TILE),
				CFrame = origin * CFrame.new(
					Layout.laneCenter(i),
					Layout.FLOOR_Y - Layout.FLOOR_THICKNESS / 2,
					Layout.laneCenter(j)
				),
				Color = rgb(Art.tileColor(i, j)),
				Material = Enum.Material.Fabric,
				Parent = tiles,
			})
			part:SetAttribute("I", i)
			part:SetAttribute("J", j)
			part:SetAttribute("Outer", Logic.isOuterTile(i, j))
			CollectionService:AddTag(part, TAG_TILE)
		end
	end

	-- 벽 풀 (처음엔 숨김 자리)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	for slot = 1, Layout.POOL do
		for lane = 1, Layout.LANES do
			local part = ghost({
				Name = string.format("Wall%d_%d", slot, lane),
				Size = Vector3.new(Layout.WALL_THICKNESS, Layout.KINDS.Low.height, Layout.TILE),
				CFrame = origin * CFrame.new(0, PARK_Y, 0),
				Color = rgb(C.wallLow),
				Material = Enum.Material.SmoothPlastic,
				Parent = walls,
			})
			part:SetAttribute("Slot", slot)
			part:SetAttribute("Lane", lane)
			CollectionService:AddTag(part, TAG_WALL)
		end
	end

	-- 예고 줄 (처음엔 안 보임)
	local warns = Instance.new("Folder")
	warns.Name = "Warnings"
	warns.Parent = model
	for _, side in Layout.SIDES do
		for lane = 1, Layout.LANES do
			local cf, size = warnFrame(origin, side, lane, Layout.HALF)
			local part = ghost({
				Name = string.format("Warn%s_%d", side, lane),
				Size = size,
				CFrame = cf,
				Color = rgb(C.warnWall),
				Material = Enum.Material.Neon,
				Transparency = 1,
				Parent = warns,
			})
			part:SetAttribute("Side", side)
			part:SetAttribute("Lane", lane)
			CollectionService:AddTag(part, TAG_WARN)
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
	MoveExempt.mark(player.Character, Layout.KNOCK_EXEMPT)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "BanquetAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "BanquetKnock"
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
		ctx.cleanup:add(task.delay(Layout.KNOCK_DOWN, function()
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
	local schedule = Logic.schedule(ctx.rng)
	local park = origin * CFrame.new(0, PARK_Y, 0)

	local outerTiles: { BasePart } = {}
	for _, part in taggedParts(ctx, TAG_TILE) do
		if part:GetAttribute("Outer") == true then
			table.insert(outerTiles, part)
		end
	end
	-- 벽 칸: wallParts[slot][lane]
	local wallParts: { { BasePart } } = {}
	for _, part in taggedParts(ctx, TAG_WALL) do
		local slot, lane = part:GetAttribute("Slot"), part:GetAttribute("Lane")
		if type(slot) == "number" and type(lane) == "number" then
			wallParts[slot] = wallParts[slot] or {}
			wallParts[slot][lane] = part
		end
	end
	-- 예고 칸: warnParts[side][lane]
	local warnParts: { [string]: { BasePart } } = {}
	for _, part in taggedParts(ctx, TAG_WARN) do
		local side, lane = part:GetAttribute("Side"), part:GetAttribute("Lane")
		if type(side) == "string" and type(lane) == "number" then
			warnParts[side] = warnParts[side] or {}
			warnParts[side][lane] = part
		end
	end

	local edgeState: Logic.TileState = "Solid"
	local slotSweep: { [number]: number } = {} -- 자리마다 지금 입힌 일정 번호
	local warnShown: { [string]: number } = {} -- 변마다 지금 보이는 일정 번호 (0 = 안 보임)
	local started: { [number]: boolean } = {}
	local readyAt: { [Player]: number } = {}

	local function dress(slot: number, sweep: Logic.Sweep)
		local kind = Layout.KINDS[sweep.kind]
		local color = rgb(if sweep.kind == "High" then C.wallHigh else C.wallLow)
		for _, part in wallParts[slot] or {} do
			part.Size = if sweep.axis == "X"
				then Vector3.new(Layout.WALL_THICKNESS, kind.height, Layout.TILE)
				else Vector3.new(Layout.TILE, kind.height, Layout.WALL_THICKNESS)
			part.Color = color
		end
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(_dt: number)
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

		-- 2. 바깥 줄 무너짐
		local nextEdge = Logic.edgeState(elapsed)
		if nextEdge ~= edgeState then
			edgeState = nextEdge
			for _, part in outerTiles do
				if nextEdge == "Open" then
					part.CanCollide = false
					part.CanQuery = false
					part.Transparency = 1
				elseif nextEdge == "Warn" then
					part.Color = rgb(C.collapseWarn)
				end
			end
			if nextEdge == "Open" then
				-- 예고 줄을 새 가장자리로
				for side, lanes in warnParts do
					for lane, part in lanes do
						part.CFrame = (warnFrame(origin, side, lane, Layout.INNER_HALF))
					end
				end
				if outerTiles[1] then
					MapSfx.play(outerTiles[1], "TileVanish")
				end
			end
		end

		-- 3. 예고 줄
		local warnings = Logic.warnings(schedule, elapsed)
		for _, side in Layout.SIDES do
			local sweep = warnings[side :: Logic.Side]
			local id = 0
			if sweep then
				id = table.find(schedule, sweep) or 0
			end
			if warnShown[side] ~= id then
				warnShown[side] = id
				for lane, part in warnParts[side] or {} do
					if sweep == nil or (edgeState == "Open" and (lane == 1 or lane == Layout.LANES)) then
						part.Transparency = 1
					else
						part.Transparency = WARN_TRANSPARENCY
						part.Color = rgb(if Logic.isGap(sweep, lane) then C.warnGap else C.warnWall)
					end
				end
				if sweep then
					local first = (warnParts[side] or {})[1]
					if first then
						MapSfx.play(first, "ChopstickWarn")
					end
				end
			end
		end

		-- 4. 벽 움직이기
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local used: { [number]: Logic.Active } = {}
		local active = Logic.active(schedule, elapsed)
		for _, a in active do
			used[Logic.slotOf(a.index)] = a
		end
		for slot = 1, Layout.POOL do
			local lanes = wallParts[slot]
			if lanes == nil then
				continue
			end
			local a = used[slot]
			if a and slotSweep[slot] ~= a.index then
				slotSweep[slot] = a.index
				dress(slot, a.sweep)
				if not started[a.index] then
					started[a.index] = true
					if lanes[1] then
						MapSfx.play(lanes[1], "SkewerWhoosh")
					end
				end
			end
			for lane, part in lanes do
				table.insert(moveParts, part)
				if a == nil or Logic.isGap(a.sweep, lane) then
					table.insert(moveFrames, park)
				else
					local h = Layout.KINDS[a.sweep.kind].height
					local c = Layout.laneCenter(lane)
					if a.sweep.axis == "X" then
						table.insert(moveFrames, origin * CFrame.new(a.pos, Layout.FLOOR_Y + h / 2, c))
					else
						table.insert(moveFrames, origin * CFrame.new(c, Layout.FLOOR_Y + h / 2, a.pos))
					end
				end
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 5. 벽에 닿음
		if #active == 0 then
			return
		end
		for _, player in ctx.getRacers() do
			if (readyAt[player] or 0) > now then
				continue
			end
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local foot = rel.Y - Layout.FOOT_OFFSET - Layout.FLOOR_Y
			for _, a in active do
				local along = if a.sweep.axis == "X" then rel.X else rel.Z
				local perp = if a.sweep.axis == "X" then rel.Z else rel.X
				if Logic.wallHit(a.sweep, a.pos, along, perp, foot) then
					local dirLocal = if a.sweep.axis == "X"
						then Vector3.new(a.sweep.dir, 0, 0)
						else Vector3.new(0, 0, a.sweep.dir)
					local dir = origin:VectorToWorldSpace(dirLocal)
					readyAt[player] = now + Layout.KNOCK_COOLDOWN
					knock(ctx, player, root, humanoid, dir * Layout.KNOCK + Vector3.new(0, Layout.KNOCK_UP, 0))
					MapSfx.play(root, "Knockdown")
					break
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "연회상 쟁반 쓸기",
	rule = "밀려오는 쟁반 벽! 낮으면 뛰어넘고, 높으면 초록 빈칸으로 피해요!",
	timeLimit = Layout.TIME_LIMIT, -- 75초, 60초부터 서든데스 (m5-40 규칙과 같아요)
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 종이 등이 켜진 저녁 연회장
	capacity = Layout.CAPACITY,
	minPlayers = Layout.MIN_PLAYERS,
}

return map
