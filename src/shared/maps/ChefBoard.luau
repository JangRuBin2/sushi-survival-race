--!strict
-- Survival 맵 "셰프의 도마" (GDD 5.2 ④, m4-05).
-- 공중에 뜬 둥근 나무 도마(8×8 칸 61개) 위에서 버텨요. 셰프의 칼이 가로·세로 한 줄을 빨갛게 예고한 뒤
-- 내리쳐 그 줄 위 초밥을 바깥으로 튕겨 내고, 줄 양 끝 칸이 흔들리다 떨어져 도마가 점점 작아져요.
-- 가운데 3×3은 잘리지 않아요. 10·20·30·40·50초에 도마가 8도 기울어 3초 동안 낮은 쪽으로 밀어요.
--
-- 판정은 ctx.eliminate만 불러요 (도마 윗면보다 30 아래로 떨어지면). Survival 종료(목표 인원 이하, 60초 종료 시
-- 전원 통과)와 점수(높이)는 RoundService/RoundLogic이 해요.
-- 칸(ChefBoardCell)과 칼(ChefKnife)은 CollectionService 태그를 달고, start에서 ctx.model 하위의 태그만 동작시켜요.
-- 상태(남은 칸, 기울기 일정, 넉백 시각)는 전부 start 안의 지역 변수에 둬요 (여러 방이 같은 맵을 동시에 돌려도 안전).
-- 서버가 캐릭터를 튕길 때(칼 넉백)는 MoveExempt.mark로 이동 감시(m4-10) 오탐을 막아요. 기울기 밀기는 기준 안이라 표시 없음.
-- 순수 로직은 ChefBoardLogic, 아트 데이터는 ChefBoardArt (tests/map-chef-board.spec.luau).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.ChefBoardArt)
local Config = require(script.Parent.Parent.Config)
local Logic = require(script.Parent.ChefBoardLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "chef-board"
local TAG_CELL = "ChefBoardCell"
local TAG_KNIFE = "ChefKnife"

local KNIFE_REST_HEIGHT = 34 -- 쉬는 칼날 바닥 높이 (도마 윗면 기준)
local KNIFE_RAISED_HEIGHT = 18 -- 경고 중 줄 위에서 들고 있는 높이
local KNIFE_STRIKE_HEIGHT = 0.2
local KNIFE_AIM_TIME = 0.35 -- 경고 시작 뒤 줄 위로 옮겨 가는 시간 (경고 시간 안)
local KNIFE_SLAM_TIME = 0.12
local KNIFE_HOLD_TIME = 0.25
local KNIFE_LIFT_TIME = 0.4
local WARN_BLINK = 0.15
local CUT_FALL_TIME = 0.8
local CUT_FALL_DISTANCE = 30
local CUT_SHAKE = 0.3
local BOARD_PUSH_MARGIN = 2 -- 도마 반지름 + 이만큼 안에 있으면 기울기에 밀려요
-- 칼이 내려치는 전체 과정이 가장 짧은 주기(3초)보다 짧아야 다음 경고가 밀리지 않아요
assert(0.8 + KNIFE_SLAM_TIME + KNIFE_HOLD_TIME + KNIFE_LIFT_TIME < Logic.knifeInterval(math.huge), "knife too slow")

type RGB = { r: number, g: number, b: number }

local function color3(c: RGB): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local shape = props.Shape
	props.Shape = nil
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
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

local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- 칼이 내려칠 줄의 자리 (도마 중심 기준). 칼날 길이 방향이 로컬 X가 되게 돌려요.
local function lineCFrame(line: Logic.Line): CFrame
	local offset = Logic.lineOffset(line)
	if line.axis == "Row" then
		return CFrame.new(0, 0, offset)
	end
	return CFrame.new(offset, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
end

-- 칼 + 셰프 팔. 피벗 = 칼날 바닥 가운데, 칼날 길이 방향 = 로컬 X.
local function buildKnife(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local knife = Instance.new("Model")
	knife.Name = "ChefKnife"
	local pivot = origin * CFrame.new(0, KNIFE_REST_HEIGHT, 0)
	local half = Logic.KNIFE_LENGTH / 2
	local colors = Art.KNIFE
	makePart({
		Name = "Blade",
		Size = Vector3.new(Logic.KNIFE_LENGTH, 10, 0.6),
		CFrame = pivot * CFrame.new(0, 5, 0),
		Color = color3(colors.blade),
		Material = Enum.Material.Metal,
		Reflectance = 0.15,
		Parent = knife,
	})
	makePart({
		Name = "Edge",
		Size = Vector3.new(Logic.KNIFE_LENGTH, 1, 0.7),
		CFrame = pivot * CFrame.new(0, 0.5, 0),
		Color = color3(colors.edge),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = knife,
	})
	makePart({
		Name = "Handle",
		Size = Vector3.new(14, 3.6, 2.2),
		CFrame = pivot * CFrame.new(half + 7, 8, 0),
		Color = color3(colors.handle),
		Parent = knife,
	})
	for k = 1, 3 do
		makePart({
			Name = "Rivet",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 1, 1),
			CFrame = pivot * CFrame.new(half + 2.5 + k * 3, 8, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color3(colors.rivet),
			Material = Enum.Material.Metal,
			Parent = knife,
		})
	end
	makePart({
		Name = "Hand",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		CFrame = pivot * CFrame.new(half + 8, 10.5, 0),
		Color = color3(colors.skin),
		Parent = knife,
	})
	-- 흰 소매: 손에서 위·바깥으로 (원기둥 축 = 로컬 X)
	local sleeveAngle = math.atan2(22, 12)
	makePart({
		Name = "Sleeve",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 7, 7),
		CFrame = pivot * CFrame.new(half + 8 + 6, 10.5 + 11, 0) * CFrame.Angles(0, 0, sleeveAngle),
		Color = color3(colors.sleeve),
		Material = Enum.Material.Fabric,
		Parent = knife,
	})
	for _, part in knife:GetChildren() do
		if part:IsA("BasePart") then
			ghost(part) -- 맞음 판정은 서버가 줄 위치로 해요
		end
	end
	knife.WorldPivot = pivot
	CollectionService:AddTag(knife, TAG_KNIFE)
	knife.Parent = model
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	local cellsFolder = Instance.new("Folder")
	cellsFolder.Name = "Cells"
	local cellSize = Logic.CELL_SIZE
	local thickness = Logic.BOARD_THICKNESS
	local full = Logic.newBoard()
	local function hasNeighbor(i: number, j: number): boolean
		return Logic.isAlive(full, i, j)
	end
	for _, cell in Logic.cells() do
		local part = makePart({
			Name = `Cell_{cell.i}_{cell.j}`,
			Size = Vector3.new(cellSize, thickness, cellSize),
			CFrame = origin * CFrame.new(cell.x, -thickness / 2, cell.z),
			Color = color3(Art.cellColor(cell.i, cell.j)),
			Material = Enum.Material.WoodPlanks,
			CanTouch = false,
		})
		part:SetAttribute("CellI", cell.i)
		part:SetAttribute("CellJ", cell.j)
		-- 칼자국 장식은 칸의 자식이라 칸과 같이 기울고 떨어져요
		MapKit.buildDecor(Art.cellDecor(cell, hasNeighbor), origin, part)
		CollectionService:AddTag(part, TAG_CELL)
		part.Parent = cellsFolder
	end
	cellsFolder.Parent = model

	buildKnife(model, origin)

	-- 스폰 24개: 가운데 5×5 칸 위 (RoundService가 3 studs 띄워서 배치해요)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Logic.spawnOffsets() do
		local spawn = makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, 0.1, offset.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
		})
		ghost(spawn)
		spawn.Parent = spawns
	end
	spawns.Parent = model

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

-- 태그가 붙은 것 중 이 라운드의 맵(ctx.model) 안에 있는 것만
local function taggedInModel(model: Model, tag: string): { Instance }
	local CollectionService = game:GetService("CollectionService")
	local found = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if model:IsAncestorOf(instance) then
			table.insert(found, instance)
		end
	end
	return found
end

-- Model을 duration 동안 to로 옮긴다 (Anchored 파츠라 Heartbeat마다 PivotTo).
local function movePivot(target: Model, to: CFrame, duration: number, easeIn: boolean?)
	local RunService = game:GetService("RunService")
	local from = target:GetPivot()
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.Heartbeat:Wait()
		local a = math.min(elapsed / duration, 1)
		local eased = if easeIn then a * a else 1 - (1 - a) * (1 - a)
		target:PivotTo(from:Lerp(to, eased))
	end
	target:PivotTo(to)
end

-- 칸 하나와 그 장식 (기울기·흔들림·떨어짐 때 같이 움직여요)
type CellEntry = {
	part: BasePart,
	base: CFrame, -- origin 기준 (평평할 때)
	children: { { part: BasePart, rel: CFrame } },
	cutting: boolean,
}

local function setCellCFrame(entry: CellEntry, cf: CFrame)
	entry.part.CFrame = cf
	for _, child in entry.children do
		child.part.CFrame = cf * child.rel
	end
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")

	local origin = ctx.origin
	local startedAt = os.clock()
	local board = Logic.newBoard()
	local tiltPlan = Logic.tiltPlan(ctx.rng)
	local currentTilt = CFrame.identity
	local wasTilted = false

	-- 이 방의 칸
	local cells: { [string]: CellEntry } = {}
	for _, instance in taggedInModel(ctx.model, TAG_CELL) do
		if instance:IsA("BasePart") then
			local i = instance:GetAttribute("CellI")
			local j = instance:GetAttribute("CellJ")
			if type(i) == "number" and type(j) == "number" then
				local children = {}
				for _, child in instance:GetDescendants() do
					if child:IsA("BasePart") then
						table.insert(children, { part = child, rel = instance.CFrame:ToObjectSpace(child.CFrame) })
					end
				end
				cells[Logic.cellKey(i, j)] = {
					part = instance,
					base = origin:ToObjectSpace(instance.CFrame),
					children = children,
					cutting = false,
				}
			end
		end
	end
	local knife: Model? = nil
	for _, instance in taggedInModel(ctx.model, TAG_KNIFE) do
		if instance:IsA("Model") then
			knife = instance
		end
	end
	local blade = knife and knife:FindFirstChild("Blade") :: BasePart?

	-- 기울기를 따라가는 임시 파츠 (경고 줄)
	local followers: { [BasePart]: CFrame } = {}

	local function applyTilt(rotation: CFrame)
		currentTilt = rotation
		local frame = origin * rotation
		for _, entry in cells do
			if not entry.cutting then
				setCellCFrame(entry, frame * entry.base)
			end
		end
		for part, rel in followers do
			part.CFrame = frame * rel
		end
	end

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	local lastHitAt: { [Player]: number } = {}

	local function knockBack(player: Player, line: Logic.Line, root: BasePart, humanoid: Humanoid, x: number, z: number)
		lastHitAt[player] = os.clock()
		local dx, dz = Logic.knockDirection(line, x, z)
		local outward = origin:VectorToWorldSpace(Vector3.new(dx, 0, dz))
		MoveExempt.mark(player.Character, Logic.KNOCKDOWN_TIME + 1)
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = outward * Logic.KNOCK_HORIZONTAL + Vector3.yAxis * Logic.KNOCK_UP
		ctx.cleanup:add(task.delay(Logic.KNOCKDOWN_TIME, function()
			-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
			if ctx.isActive() and humanoid.Parent and isRacer(player) then
				humanoid.PlatformStand = false
			end
		end))
	end

	-- 매 프레임: 기울기 적용, 낙하 탈락, 기운 쪽으로 밀기
	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local tilt = Logic.tiltCFrameParams(now - startedAt, tiltPlan)
		if tilt then
			applyTilt(CFrame.fromAxisAngle(Vector3.new(tilt.axisX, 0, tilt.axisZ), tilt.angle))
			wasTilted = true
		elseif wasTilted then
			applyTilt(CFrame.identity)
			wasTilted = false
		end

		local pushDirection = if tilt then origin:VectorToWorldSpace(Vector3.new(tilt.downX, 0, tilt.downZ)) else nil
		local pushSpeed = if tilt then Logic.TILT_PUSH_SPEED * tilt.strength else 0
		local pushRadius = Logic.BOARD_RADIUS + BOARD_PUSH_MARGIN

		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local relative = origin:PointToObjectSpace(root.Position)
			if relative.Y < -Logic.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
				continue
			end
			if
				pushDirection
				and relative.Y > -8
				and relative.Y < 10
				and relative.X * relative.X + relative.Z * relative.Z <= pushRadius * pushRadius
			then
				local current = root.AssemblyLinearVelocity
				local along = current:Dot(pushDirection)
				if along < pushSpeed then
					local delta = math.min(Logic.TILT_PUSH_ACCEL * dt, pushSpeed - along)
					root.AssemblyLinearVelocity = current + pushDirection * delta
				end
				-- 기울기 밀기(최고 6)는 표시 없이도 감시 기준 안이라 MoveExempt를 달지 않아요 (m4-10 QA B1).
			end
		end
	end))

	-- 잘린 칸: 흔들리다가 떨어져 사라져요
	local function dropCell(entry: CellEntry)
		entry.cutting = true
		local home = entry.part.CFrame
		local shaken = 0
		while shaken < Logic.CUT_SHAKE_TIME do
			local shake = Vector3.new(
				ctx.rng:NextNumber(-CUT_SHAKE, CUT_SHAKE),
				ctx.rng:NextNumber(-CUT_SHAKE, CUT_SHAKE) * 0.4,
				ctx.rng:NextNumber(-CUT_SHAKE, CUT_SHAKE)
			)
			setCellCFrame(entry, home + shake)
			shaken += task.wait(0.05)
		end
		entry.part.CanCollide = false
		entry.part.CanQuery = false
		MapSfx.play(entry.part, "TileVanish")
		local fallen = 0
		while fallen < CUT_FALL_TIME do
			fallen += RunService.Heartbeat:Wait()
			local a = math.min(fallen / CUT_FALL_TIME, 1)
			setCellCFrame(entry, home + Vector3.new(0, -CUT_FALL_DISTANCE * a * a, 0))
			entry.part.Transparency = a
			for _, child in entry.children do
				child.part.Transparency = a
			end
		end
		entry.part:Destroy()
	end

	local function makeStripe(line: Logic.Line): BasePart
		local rel = lineCFrame(line) * CFrame.new(0, 0.12, 0)
		local stripe = makePart({
			Name = "KnifeWarning",
			Size = Vector3.new(Logic.BOARD_RADIUS * 2, 0.2, Logic.CELL_SIZE),
			CFrame = origin * currentTilt * rel,
			Color = color3(Art.KNIFE.warn),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		ghost(stripe)
		stripe.Parent = ctx.model
		followers[stripe] = rel
		return stripe
	end

	-- 칼 한 번: 경고 줄 → 내려침(넉백) → 양 끝 칸 잘림 → 올라감
	local function strike(line: Logic.Line, warnTime: number)
		local stripe = makeStripe(line)
		MapSfx.play(stripe, "ChefHandWarn")
		local lineRel = lineCFrame(line)
		local aimThread: thread? = nil
		if knife then
			aimThread = task.spawn(
				movePivot,
				knife,
				origin * currentTilt * lineRel * CFrame.new(0, KNIFE_RAISED_HEIGHT, 0),
				math.min(KNIFE_AIM_TIME, warnTime),
				false
			)
			ctx.cleanup:add(aimThread)
		end
		local warned = 0
		local visible = true
		while warned < warnTime do
			stripe.Transparency = if visible then 0.45 else 0.75
			visible = not visible
			warned += task.wait(math.min(WARN_BLINK, warnTime - warned))
		end
		stripe.Transparency = 0.3
		if not ctx.isActive() then
			followers[stripe] = nil
			stripe:Destroy()
			return
		end

		if knife then
			MapSfx.play(blade, "SkewerWhoosh")
			movePivot(
				knife,
				origin * currentTilt * lineRel * CFrame.new(0, KNIFE_STRIKE_HEIGHT, 0),
				KNIFE_SLAM_TIME,
				true
			)
		end
		if not ctx.isActive() then
			followers[stripe] = nil
			stripe:Destroy()
			return
		end

		-- 탕! 줄 위에 있던 사람을 튕겨 내요
		local now = os.clock()
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (root and root:IsA("BasePart") and humanoid) then
				continue
			end
			if now - (lastHitAt[player] or -math.huge) < Logic.KNOCKDOWN_TIME then
				continue
			end
			local relative = origin:PointToObjectSpace(root.Position)
			if relative.Y > -4 and relative.Y < Logic.HIT_HEIGHT and Logic.isOnLine(line, relative.X, relative.Z) then
				knockBack(player, line, root, humanoid, relative.X, relative.Z)
			end
		end

		-- 줄 양 끝 칸이 잘려 나가요
		local cut = Logic.cutCells(board, line)
		Logic.removeCells(board, cut)
		for _, cell in cut do
			local entry = cells[cell.key]
			if entry then
				ctx.cleanup:add(task.spawn(dropCell, entry))
			end
		end

		followers[stripe] = nil
		stripe:Destroy()
		if knife then
			task.wait(KNIFE_HOLD_TIME)
			movePivot(knife, origin * lineRel * CFrame.new(0, KNIFE_REST_HEIGHT, 0), KNIFE_LIFT_TIME)
		end
	end

	-- 칼: 정해진 시각마다 줄 하나
	ctx.cleanup:add(task.spawn(function()
		local previousKey: string? = nil
		for _, warnAt in Logic.strikeTimes(Config.TimeLimit.Survival) do
			local untilWarn = warnAt - (os.clock() - startedAt)
			if untilWarn > 0 then
				task.wait(untilWarn)
			end
			if not ctx.isActive() then
				break
			end
			local line = Logic.pickLine(board, previousKey, ctx.rng)
			if line == nil then
				break
			end
			previousKey = line.key
			strike(line, Logic.warnTime(warnAt))
		end
	end))
end

local ChefBoard: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "셰프의 도마",
	rule = "칼이 내려치는 줄을 피하고, 잘려 나가는 도마 위에서 끝까지 버티세요!",
	build = build,
	start = start,
}

return ChefBoard
