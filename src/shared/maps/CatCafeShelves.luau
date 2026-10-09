--!strict
-- Survival 맵 "고양이 카페 캣타워" (m5-17, GDD 5.3 v0.6). 좁은 선반 사이를 옆으로 옮겨 다니며 버티는
-- 수평형 Survival: 3단 캣타워(테두리 모양 선반이 쌓인 피라미드). 선반은 사라지지 않지만 좁아서
--   · 장난감 공(CatToy)이 선반 긴 축을 따라 사인파로 왕복하다 맞으면 타워 중심에서 바깥쪽으로 작게 밀고,
--   · 고양이 발(CatPaw)이 주기적으로(occupant 가중 랜덤) 선반 하나를 경고 뒤 바깥쪽으로 크게 민다.
-- 테두리 밖은 허공이라 가장자리 밖으로 밀리면 떨어져 탈락. 3단(꼭대기, "캣방석")은 고양이 발 대상에서
-- 빠져요(공은 그대로) — Survival은 시간 종료 때 버틴 사람 전원이 통과하니 완전한 안전지대가 필요해요.
--
-- 치수·기하는 CatCafeShelvesLayout, 공·고양이 발 계산(사인파, 맞음, 방향, 일정, 선반 고르기)은
-- CatCafeShelvesLogic — 둘 다 순수 로직이고 tests/map-cat-cafe-shelves.spec.luau가 확인해요.
-- 아트는 CatCafeShelvesArt(DecorSpec 목록) → MapKit.buildDecor로 충돌 없이 만들어요.
-- 선반 파츠는 CollectionService 태그 "CatCafeShelf" + Attribute "ShelfKey"(Layout의 key)를 달아서
-- start가 ctx.model 하위 태그 파츠만 찾아요 (M1 B10 (A)). 장난감 공은 Anchored로 스크립트가 직접
-- 사인파 위치를 정해요(물리 시뮬 아님, RamenRapidsLogic.chashuHeight와 같은 방식) — 네트워크 소유권
-- 문제(M1 B10)를 피해요. 넉백은 SoySwampHazards.launch와 같은 방식(LinearVelocity를 짧게 걸고 그 뒤는
-- 포물선)이에요. 상태(occupancy, 쿨다운 등)는 start 지역 변수에 둬서 여러 방이 같은 맵을 동시에 돌려도
-- 섞이지 않아요. Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.CatCafeShelvesArt)
local Layout = require(script.Parent.CatCafeShelvesLayout)
local Logic = require(script.Parent.CatCafeShelvesLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "cat-cafe-shelves"
local SHELF_TAG = "CatCafeShelf"
local SHELF_THICKNESS = 2
local BALL_Y_OFFSET = Logic.BALL_DIAMETER / 2 + 0.05
local PROBE_LENGTH = 4.5 -- 루트 중심 → 발바닥(약 3)보다 길어서 서 있을 때만 닿아요 (HotPlate와 같은 관례)

-- Color3는 Roblox API라 함수 안에서만 만들어요 (모듈 최상위에서 만들면 Lune require가 실패해요).
local function shelfColor(): Color3
	return Color3.fromRGB(230, 200, 168) -- 밝은 나무 선반
end

local function shelfWarnColor(): Color3
	return Color3.fromRGB(255, 150, 60) -- 고양이 발 경고 중
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

-- 선반의 (X, Z) 파츠 크기. axis == "X"면 length가 X로, 아니면 Z로 뻗어요.
local function shelfFootprint(shelf: Layout.Shelf): (number, number)
	if shelf.axis == "X" then
		return shelf.length, shelf.width
	end
	return shelf.width, shelf.length
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	local shelvesFolder = Instance.new("Folder")
	shelvesFolder.Name = "Shelves"
	for _, shelf in Layout.shelves() do
		local sizeX, sizeZ = shelfFootprint(shelf)
		local tile = part({
			Name = shelf.key,
			Size = Vector3.new(sizeX, SHELF_THICKNESS, sizeZ),
			CFrame = origin * CFrame.new(shelf.centerX, shelf.topY - SHELF_THICKNESS / 2, shelf.centerZ),
			Color = shelfColor(),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
		})
		tile:SetAttribute("ShelfKey", shelf.key)
		CollectionService:AddTag(tile, SHELF_TAG)
		tile.Parent = shelvesFolder
	end
	shelvesFolder.Parent = model

	local toysFolder = Instance.new("Folder")
	toysFolder.Name = "CatToys"
	for _, shelf in Layout.shelves() do
		local ball = part({
			Name = `Toy{shelf.key}`,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * Logic.BALL_DIAMETER,
			Color = Color3.fromRGB(240, 120, 150),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CFrame = origin * CFrame.new(shelf.centerX, shelf.topY + BALL_Y_OFFSET, shelf.centerZ),
		})
		ball:SetAttribute("ShelfKey", shelf.key)
		ball.Parent = toysFolder
	end
	toysFolder.Parent = model

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Layout.spawnOffsets() do
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, Layout.TIER1_TOP_Y + 0.1, offset.z),
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
	for _, decorPart in MapKit.buildDecor(Art.decor(), origin, decor) do
		if decorPart.Name == Art.WINDOW_LIGHT then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 240, 210)
			light.Brightness = 1.2
			light.Range = 24
			light.Parent = decorPart
		elseif decorPart.Name == Art.SUNBEAM then
			local dust = Instance.new("ParticleEmitter")
			dust.Name = "Dust"
			dust.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230))
			dust.LightEmission = 0.3
			dust.Rate = 1.5
			dust.Lifetime = NumberRange.new(3, 5)
			dust.Speed = NumberRange.new(0.3, 0.8)
			dust.SpreadAngle = Vector2.new(25, 25)
			dust.Size = NumberSequence.new(0.15)
			dust.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			})
			dust.Parent = decorPart
		end
	end
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
		created.Name = "CatCafeAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "CatCafeLaunch"
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

	local shelfByKey: { [string]: Layout.Shelf } = {}
	for _, shelf in Layout.shelves() do
		shelfByKey[shelf.key] = shelf
	end

	-- 이 방 Model 안의 선반·공만 (다른 방의 같은 맵과 안 섞여요, M1 B10 (A))
	local shelfParts: { [string]: BasePart } = {}
	for _, instance in CollectionService:GetTagged(SHELF_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			local key = instance:GetAttribute("ShelfKey")
			if type(key) == "string" then
				shelfParts[key] = instance
			end
		end
	end

	local toyParts: { [string]: BasePart } = {}
	local toysFolder = ctx.model:FindFirstChild("CatToys")
	if toysFolder then
		for _, instance in toysFolder:GetChildren() do
			if instance:IsA("BasePart") then
				local key = instance:GetAttribute("ShelfKey")
				if type(key) == "string" then
					toyParts[key] = instance
				end
			end
		end
	end

	local probeTargets: { Instance } = {}
	for _, p in shelfParts do
		table.insert(probeTargets, p)
	end
	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = probeTargets
	local down = Vector3.new(0, -PROBE_LENGTH, 0)

	local startedAt = os.clock()
	local ballCooldown: { [Player]: number } = {} -- 다음에 다시 맞을 수 있는 시각
	local standingOn: { [Player]: string? } = {}
	local occupancy: { [string]: number } = {}

	local function doLaunch(
		root: BasePart,
		localDx: number,
		localDz: number,
		horizontal: number,
		up: number,
		hold: number
	)
		local direction = origin:VectorToWorldSpace(Vector3.new(localDx, 0, localDz))
		launch(ctx, root, direction * horizontal + Vector3.new(0, up, 0), hold)
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt
		local newOccupancy: { [string]: number } = {}
		local newStanding: { [Player]: string? } = {}

		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			if rel.Y < Layout.ELIMINATION_Y then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
				continue
			end

			local shelfKey: string? = nil
			local hit = workspace:Raycast(root.Position, down, probeParams)
			if hit and hit.Instance:IsA("BasePart") then
				local key = hit.Instance:GetAttribute("ShelfKey")
				if type(key) == "string" then
					shelfKey = key
				end
			end
			newStanding[player] = shelfKey

			if shelfKey then
				newOccupancy[shelfKey] = (newOccupancy[shelfKey] or 0) + 1
				local shelf = shelfByKey[shelfKey]
				local toy = toyParts[shelfKey]
				if shelf and toy then
					local along = if shelf.axis == "X" then rel.X - shelf.centerX else rel.Z - shelf.centerZ
					local diff = math.abs(along - Logic.ballOffset(shelf, elapsed))
					if Logic.isHit(diff) then
						local readyAt = ballCooldown[player]
						if readyAt == nil or now >= readyAt then
							ballCooldown[player] = now + Logic.BALL_COOLDOWN
							local dx, dz =
								Logic.outwardDirection(Layout.TOWER_CENTER_X, Layout.TOWER_CENTER_Z, rel.X, rel.Z)
							MoveExempt.mark(character, Logic.BALL_COOLDOWN)
							doLaunch(
								root,
								dx,
								dz,
								Logic.BALL_KNOCK_HORIZONTAL,
								Logic.BALL_KNOCK_UP,
								Logic.BALL_KNOCK_HOLD
							)
							MapSfx.play(toy, "CatToyBounce")
						end
					end
				end
			end
		end

		standingOn = newStanding
		occupancy = newOccupancy

		for _, shelf in Layout.shelves() do
			local toy = toyParts[shelf.key]
			if toy then
				local offset = Logic.ballOffset(shelf, elapsed)
				local x = if shelf.axis == "X" then shelf.centerX + offset else shelf.centerX
				local z = if shelf.axis == "X" then shelf.centerZ else shelf.centerZ + offset
				toy.CFrame = origin * CFrame.new(x, shelf.topY + BALL_Y_OFFSET, z)
			end
		end
	end))

	-- 고양이 발: 그레이스 뒤 주기적으로 선반 하나를 경고 → 그 순간 위에 있던 전원을 바깥쪽으로 크게 밀어요.
	local previousPaw: string? = nil
	ctx.cleanup:add(task.spawn(function()
		task.wait(Logic.PAW_GRACE)
		while ctx.isActive() do
			local key = Logic.pickShelf(occupancy, previousPaw, ctx.rng)
			local shelfPart = if key then shelfParts[key] else nil
			if key and shelfPart then
				previousPaw = key
				shelfPart.Color = shelfWarnColor()
				MapSfx.play(shelfPart, "CatPawWarn")
				task.wait(Logic.PAW_WARN_TIME)
				if ctx.isActive() then
					shelfPart.Color = shelfColor()
					MapSfx.play(shelfPart, "CatPawSwipe")
					for _, player in ctx.getRacers() do
						if standingOn[player] ~= key then
							continue
						end
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and root:IsA("BasePart") then
							local rel = origin:PointToObjectSpace(root.Position)
							local dx, dz =
								Logic.outwardDirection(Layout.TOWER_CENTER_X, Layout.TOWER_CENTER_Z, rel.X, rel.Z)
							MoveExempt.mark(character, Logic.PAW_MOVE_EXEMPT)
							doLaunch(root, dx, dz, Logic.PAW_KNOCK_HORIZONTAL, Logic.PAW_KNOCK_UP, Logic.PAW_KNOCK_HOLD)
						end
					end
				end
			end
			local interval = Logic.pawInterval(os.clock() - startedAt) or 2
			task.wait(interval)
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "고양이 카페 캣타워",
	rule = "좁은 선반 사이를 옮겨 다니며 버텨요. 가장자리 밖으로 밀리면 안 돼요!",
	build = build,
	start = start,
}

return map
