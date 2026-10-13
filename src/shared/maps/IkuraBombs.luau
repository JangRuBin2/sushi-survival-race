--!strict
-- Final 맵 "연어알 폭탄 접시" (m5-04, GDD §5.2·§5.3). 가게 앞 거대한 간장 접시(반지름 24, 칸 17개) 위에서
-- 셰프가 숟가락으로 거대한 연어알 폭탄을 떨어뜨려요. 빨간 원 경고 → 폭발(바깥으로 넉백 + 1초 넘어짐),
-- 같은 고리 칸이 두 번 맞으면 깨져 떨어지고, 40초부터 바깥 고리·60초부터 가운데 고리 칸이 하나씩 떨어져요.
-- 연장전(m5-01)은 바깥 고리 → 가운데 고리 → 원판 순서로 고리째 없애요 (collapseDuration 안에 설 곳 0).
--
-- 이 맵은 ctx.pass를 부르지 않아요(결승선 없음). 우승 판정은 RoundService. 낙하만 ctx.eliminate.
-- 칸(태그 IkuraTile, 속성 Ring·Index·TileId·Cracks)은 6도 조각 파츠를 묶은 Model이에요. 폭탄(태그 IkuraBomb)은
-- 라운드 중 ctx.model.Bombs 아래에 만들어요. 숟가락(태그 IkuraSpoon)·접시 테두리 등 장식은 전부 충돌 없음.
-- 상태는 roundStates[ctx]에 둬요 (여러 방이 같은 맵을 동시에 돌려도 안 섞여요, 라운드 끝에 ctx.cleanup이 지움).
-- Roblox API는 build/start/overtime 안에서만 써서 Lune에서 require해도 안전해요.

local Art = require(script.Parent.IkuraBombsArt)
local Layout = require(script.Parent.IkuraBombsLayout)
local Logic = require(script.Parent.IkuraBombsLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = Layout.ID

local TAG_TILE = "IkuraTile"
local TAG_BOMB = "IkuraBomb"
local TAG_SPOON = "IkuraSpoon"

local ROE_DIAMETER = 4
local ROE_FALL_TIME = 0.5 -- 경고 마지막 이 초 동안 연어알이 떨어지는 모습
local WARN_BLINK = 0.15 -- 빨간 원 깜빡임 간격
local CIRCLE_TRANSPARENCY = { 0.35, 0.65 }
local LAUNCH_HOLD = 0.12 -- LinearVelocity 유지 시간
local KNOCKDOWN_TIME = 1 -- PlatformStand
local EXEMPT_TIME = 1.5 -- 이동 감시 면제
local HIT_COOLDOWN = 0.5 -- 같은 사람은 이 안에 두 번 안 맞아요
local DROP_WARN = 1 -- 금 2번·정해진 낙하 경고 (흔들림 + 빨간 깜빡임)
local TILE_BLINK = 0.2
local SHAKE = 0.15 -- 경고 흔들림 크기
local CRACK_DARKEN = 0.4 -- 금 1번이면 색을 검정 쪽으로 이만큼
local OVERTIME_WARN = 1
local SPOON_FOLLOW = 6 -- 숟가락이 목표를 따라가는 빠르기 (1/초)
local PARTICLE_COUNT = 24

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function noCollide(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- 원기둥 축(로컬 X)을 Y로 (모듈 맨 위에서 CFrame을 만들면 Lune require가 깨져서 함수로)
local function upright(): CFrame
	return CFrame.Angles(0, 0, math.rad(90))
end

-- 칸 Model 하나. 원판은 원기둥 1개, 고리 칸은 6도 조각 직사각형들. 윗면은 로컬 y 0.
local function buildTile(model: Model, origin: CFrame, tile: Layout.TileDef)
	local CollectionService = game:GetService("CollectionService")
	local tileModel = Instance.new("Model")
	tileModel.Name = string.format("Tile_%d_%d", tile.ring, tile.index)
	local color = if tile.ring == 0
		then rgb(Art.COLORS.center)
		elseif tile.index % 2 == 0 then rgb(Art.COLORS.soyA)
		else rgb(Art.COLORS.soyB)
	local y = -Layout.THICKNESS / 2
	if tile.ring == 0 then
		local d = Layout.ringOuter(0) * 2
		makePart({
			Name = "Slab",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.THICKNESS, d, d),
			CFrame = origin * CFrame.new(0, y, 0) * upright(),
			Color = color,
			Reflectance = 0.12,
			Parent = tileModel,
		})
	else
		for _, slice in Layout.slices(tile.ring) do
			if slice.tileId == tile.id then
				local x, z = Layout.polar(slice.distance, slice.angleDeg)
				makePart({
					Name = "Slab",
					Size = Vector3.new(slice.depth, Layout.THICKNESS, slice.width),
					CFrame = origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(slice.angleDeg), 0),
					Color = color,
					Reflectance = 0.12,
					Parent = tileModel,
				})
			end
		end
	end
	tileModel:SetAttribute("Ring", tile.ring)
	tileModel:SetAttribute("Index", tile.index)
	tileModel:SetAttribute("TileId", tile.id)
	tileModel:SetAttribute("Cracks", 0)
	CollectionService:AddTag(tileModel, TAG_TILE)
	tileModel.Parent = model
end

-- 셰프 손 + 은 숟가락 (자리 잡기용, PHASE B에서 아트로 바꿔요). 충돌 없음, Heartbeat가 PivotTo로 옮겨요.
local function buildSpoon(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local spoon = Instance.new("Model")
	spoon.Name = "Spoon"
	local base = origin * CFrame.new(0, Layout.SPOON_HEIGHT, 0)
	local bowl = makePart({
		Name = "Bowl",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 1.6, 6),
		CFrame = base,
		Color = rgb(Art.COLORS.spoon),
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
		Parent = spoon,
	})
	makePart({
		Name = "Handle",
		Size = Vector3.new(1, 0.6, 12),
		CFrame = base * CFrame.new(0, 1.5, 8) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = rgb(Art.COLORS.spoon),
		Material = Enum.Material.Metal,
		Parent = spoon,
	})
	makePart({
		Name = "Hand",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 4, 5),
		CFrame = base * CFrame.new(0, 3.5, 13),
		Color = rgb(Art.COLORS.hand),
		Parent = spoon,
	})
	for _, part in spoon:GetChildren() do
		if part:IsA("BasePart") then
			MapKit.applyDecorRules(part)
		end
	end
	spoon.PrimaryPart = bowl
	CollectionService:AddTag(spoon, TAG_SPOON)
	spoon.Parent = model
end

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	for _, tile in Layout.tiles() do
		buildTile(model, origin, tile)
	end
	buildSpoon(model, origin)

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, spawn in Layout.spawns() do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(spawn.x, spawn.y, spawn.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end
	spawns.Parent = model
	return model
end

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

type TileState = {
	model: Model,
	parts: { BasePart },
	baseColor: Color3,
	id: number,
	ring: number,
	cracks: number,
	status: "alive" | "falling" | "dropped",
}

type RoundState = {
	startedAt: number,
	overtimeAt: number?, -- 연장전 시작(출발 기준 초). nil이면 연장전 전
	tiles: { [number]: TileState },
	lastHit: { [Player]: number },
	spoonTarget: Vector3?, -- 로컬 (x, 0, z)
	bombs: Folder?,
	burst: ParticleEmitter?,
}
local roundStates: { [MapTypes.RoundContext]: RoundState } = {}

local function collectTiles(model: Model): { [number]: TileState }
	local tiles: { [number]: TileState } = {}
	for _, instance in taggedInModel(model, TAG_TILE) do
		local id, ring = instance:GetAttribute("TileId"), instance:GetAttribute("Ring")
		if instance:IsA("Model") and type(id) == "number" and type(ring) == "number" then
			local parts: { BasePart } = {}
			for _, child in instance:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
			tiles[id] = {
				model = instance,
				parts = parts,
				baseColor = if parts[1] then parts[1].Color else Color3.new(),
				id = id,
				ring = ring,
				cracks = 0,
				status = "alive",
			}
		end
	end
	return tiles
end

local function newState(ctx: MapTypes.RoundContext): RoundState
	local state: RoundState = {
		startedAt = os.clock(),
		overtimeAt = nil,
		tiles = collectTiles(ctx.model),
		lastHit = {},
		spoonTarget = nil,
		bombs = nil,
		burst = nil,
	}
	roundStates[ctx] = state
	ctx.cleanup:add(function()
		roundStates[ctx] = nil
	end)
	return state
end

local function aliveIds(state: RoundState): { number }
	local ids: { number } = {}
	for id, tile in state.tiles do
		if tile.status == "alive" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function setTileColor(tile: TileState, color: Color3)
	for _, part in tile.parts do
		part.Color = color
	end
end

-- 칸을 없애요: 충돌·터치·쿼리 끔 + 투명 (안의 금 장식까지)
local function vanish(tile: TileState)
	tile.status = "dropped"
	for _, descendant in tile.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			noCollide(descendant)
			descendant.Transparency = 1
		end
	end
	tile.model:SetAttribute("Dropped", true)
end

-- 경고(빨간 깜빡임 + 흔들림) 뒤 dropAt(os.clock)에 칸을 없애요. 이미 떨어진 칸은 무시.
local function dropTile(ctx: MapTypes.RoundContext, tile: TileState, dropAt: number, shake: boolean)
	if tile.status == "dropped" then
		return
	end
	tile.status = "falling"
	tile.model:SetAttribute("Falling", true)
	local homes: { [BasePart]: CFrame } = {}
	for _, part in tile.parts do
		homes[part] = part.CFrame
	end
	local warnColor = rgb(Art.COLORS.warn)
	local blinkOn = true
	while os.clock() < dropAt do
		if not ctx.isActive() then
			return
		end
		setTileColor(tile, if blinkOn then warnColor else tile.baseColor)
		for part, home in homes do
			part.CFrame = if shake and blinkOn
				then home * CFrame.new((math.random() - 0.5) * SHAKE * 2, 0, (math.random() - 0.5) * SHAKE * 2)
				else home
		end
		blinkOn = not blinkOn
		task.wait(math.min(TILE_BLINK, math.max(dropAt - os.clock(), 0)))
	end
	if not ctx.isActive() or tile.status == "dropped" then
		return
	end
	for part, home in homes do
		part.CFrame = home
	end
	vanish(tile)
	MapSfx.play(tile.parts[1], "TileVanish")
end

-- 금 1번: 색을 어둡게 하고 칸 윗면에 검은 금 줄 몇 개 (충돌 없음, 칸 Model 안 — 칸과 같이 사라져요)
local function showCrack(ctx: MapTypes.RoundContext, tile: TileState)
	tile.baseColor = tile.baseColor:Lerp(Color3.new(0, 0, 0), CRACK_DARKEN)
	setTileColor(tile, tile.baseColor)
	local lineColor = rgb(Art.COLORS.crackLine)
	for i, part in tile.parts do
		if i % 2 == 1 then
			local size = part.Size
			local long = math.max(size.X, size.Z) * 0.8
			local line = makePart({
				Name = "Crack",
				Size = Vector3.new(0.25, 0.05, long),
				CFrame = part.CFrame
					* CFrame.new(0, size.Y / 2 + 0.03, 0)
					* CFrame.Angles(0, math.rad(ctx.rng:NextNumber(-50, 50)), 0),
				Color = lineColor,
				Parent = tile.model,
			})
			MapKit.applyDecorRules(line)
		end
	end
end

-- 레이서 루트 (로컬 좌표와 함께)
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

-- 캐릭터는 클라이언트가 물리를 맡아서 서버가 속도만 바꾸면 덮어써질 수 있어요 → LinearVelocity를 잠깐 붙여요
-- (SoySwampHazards 와사비와 같은 방식).
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "IkuraAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "IkuraLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(LAUNCH_HOLD, function()
		push:Destroy()
	end))
end

local function explode(ctx: MapTypes.RoundContext, state: RoundState, center: Vector3, radius: number, at: BasePart)
	local origin = ctx.origin
	local now = os.clock()
	for _, racer in racerRoots(ctx) do
		local dx, dy, dz = racer.at.X - center.X, racer.at.Y - center.Y, racer.at.Z - center.Z
		if not Logic.inBlast(dx, dy, dz, radius) then
			continue
		end
		local last = state.lastHit[racer.player]
		if last and now - last < HIT_COOLDOWN then
			continue
		end
		local push = Logic.knockback(dx, dz, radius, racer.at.X, racer.at.Z)
		if push == nil then
			continue
		end
		state.lastHit[racer.player] = now
		local player, humanoid = racer.player, racer.humanoid
		-- 넘어짐(PlatformStand)이 켜지면 잡기도 풀려요 (GrabService isDown)
		humanoid.PlatformStand = true
		MoveExempt.mark(player.Character, EXEMPT_TIME) -- 서버가 튕긴 속도라 이동 감시(m4-10)에서 빼요
		launch(ctx, racer.root, origin:VectorToWorldSpace(Vector3.new(push.x, push.y, push.z)))
		ctx.cleanup:add(task.delay(KNOCKDOWN_TIME, function()
			-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
			if ctx.isActive() and humanoid.Parent and table.find(ctx.getRacers(), player) then
				humanoid.PlatformStand = false
			end
		end))
	end

	MapSfx.play(at, "IkuraPop")
	local burst = state.burst
	if burst then
		local holder = burst.Parent
		if holder and holder:IsA("BasePart") then
			holder.CFrame = origin * CFrame.new(center.X, 0.5, center.Z)
		end
		burst:Emit(PARTICLE_COUNT)
	end

	-- 금 가기 (연장전 전에만, 원판 제외)
	if state.overtimeAt ~= nil then
		return
	end
	local id = Logic.tileAt(center.X, center.Z)
	local tile = id and state.tiles[id]
	if tile and tile.status == "alive" then
		local cracks, drop = Logic.crack(tile.ring, tile.cracks)
		if cracks ~= tile.cracks then
			tile.cracks = cracks
			tile.model:SetAttribute("Cracks", cracks)
			if drop then
				ctx.cleanup:add(task.spawn(dropTile, ctx, tile, os.clock() + DROP_WARN, true))
			else
				showCrack(ctx, tile)
			end
		end
	end
end

-- 폭탄 하나: 빨간 원 경고(warn초, 깜빡임) + 숟가락 이동 → 마지막 0.5초 연어알 낙하 → 폭발
local function runBomb(ctx: MapTypes.RoundContext, state: RoundState, point: Logic.Point, wave: Logic.Wave)
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local folder = state.bombs
	if folder == nil then
		return
	end
	local center = Vector3.new(point.x, 0, point.z)
	local bomb = Instance.new("Model")
	bomb.Name = "Bomb"
	local d = wave.radius * 2
	local circle = makePart({
		Name = "Warning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, d, d),
		CFrame = origin * CFrame.new(center.X, 0.12, center.Z) * upright(),
		Color = rgb(Art.COLORS.bombCircle),
		Material = Enum.Material.Neon,
		Transparency = CIRCLE_TRANSPARENCY[1],
		Parent = bomb,
	})
	noCollide(circle)
	CollectionService:AddTag(bomb, TAG_BOMB)
	bomb.Parent = folder
	ctx.cleanup:add(bomb)
	state.spoonTarget = center

	local bornAt = os.clock()
	local explodeAt = bornAt + wave.warn
	local fallFrom = explodeAt - math.min(ROE_FALL_TIME, wave.warn)
	-- 연어알 (마지막 ROE_FALL_TIME초 동안만 보이게, 그 전엔 투명)
	local roe = makePart({
		Name = "Roe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * ROE_DIAMETER,
		CFrame = origin * CFrame.new(center.X, Layout.SPOON_HEIGHT, center.Z),
		Color = rgb(Art.COLORS.roe),
		Material = Enum.Material.Glass,
		Transparency = 1,
		Parent = bomb,
	})
	noCollide(roe)
	local blinkOn = true
	local nextBlink = bornAt
	while true do
		if not ctx.isActive() then
			bomb:Destroy()
			return
		end
		local now = os.clock()
		if now >= explodeAt then
			break
		end
		if now >= nextBlink then
			circle.Transparency = CIRCLE_TRANSPARENCY[if blinkOn then 1 else 2]
			blinkOn = not blinkOn
			nextBlink = now + WARN_BLINK
		end
		if now >= fallFrom then
			roe.Transparency = 0.25
			local alpha = math.clamp((now - fallFrom) / math.max(explodeAt - fallFrom, 1e-3), 0, 1)
			local height = Layout.SPOON_HEIGHT * (1 - alpha * alpha) + ROE_DIAMETER / 2
			roe.CFrame = origin * CFrame.new(center.X, height, center.Z)
		end
		RunService.Heartbeat:Wait()
	end
	explode(ctx, state, center, wave.radius, circle)
	bomb:Destroy()
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local state = roundStates[ctx] or newState(ctx)
	state.startedAt = os.clock()

	local bombs = Instance.new("Folder")
	bombs.Name = "Bombs"
	bombs.Parent = ctx.model
	ctx.cleanup:add(bombs)
	state.bombs = bombs

	-- 폭발 알갱이: 투명 파츠 하나에 ParticleEmitter 하나, 폭발 때마다 옮겨서 Emit (파티클 예산 1)
	local holder = makePart({
		Name = "BurstHolder",
		Size = Vector3.one,
		CFrame = origin,
		Transparency = 1,
		Parent = bombs,
	})
	noCollide(holder)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "IkuraBurst"
	burst.Enabled = false
	burst.Color = ColorSequence.new(rgb(Art.COLORS.roe))
	burst.Size = NumberSequence.new(0.8, 0.2)
	burst.Lifetime = NumberRange.new(0.3, 0.4)
	burst.Speed = NumberRange.new(18, 30)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Parent = holder
	state.burst = burst

	local spoon: Model? = nil
	for _, instance in taggedInModel(ctx.model, TAG_SPOON) do
		if instance:IsA("Model") then
			spoon = instance
		end
	end
	local spoonAt = Vector3.zero

	-- 낙하 판정 + 숟가락 따라가기
	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and origin:PointToObjectSpace(root.Position).Y < -Layout.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return
				end
			end
		end
		local target = state.spoonTarget
		if spoon and target then
			spoonAt = spoonAt:Lerp(target, math.min(1, dt * SPOON_FOLLOW))
			spoon:PivotTo(origin * CFrame.new(spoonAt.X, Layout.SPOON_HEIGHT, spoonAt.Z))
		end
	end))

	-- 폭탄 일정
	ctx.cleanup:add(task.spawn(function()
		while ctx.isActive() do
			local elapsed = os.clock() - state.startedAt
			local wave = Logic.bombWave(elapsed, state.overtimeAt)
			if wave == nil then
				task.wait(math.max(0.05, Logic.START_GRACE - elapsed))
				continue
			end
			local alive = aliveIds(state)
			if #alive > 0 then
				local racers: { Logic.Point } = {}
				for _, racer in racerRoots(ctx) do
					if racer.at.Y > -Layout.FALL_DEPTH / 2 then
						table.insert(racers, { x = racer.at.X, z = racer.at.Z })
					end
				end
				for _, point in Logic.pickTargets(ctx.rng, racers, alive, wave.count) do
					ctx.cleanup:add(task.spawn(runBomb, ctx, state, point, wave))
				end
			end
			task.wait(wave.interval)
		end
	end))

	-- 정해진 낙하 (40초부터 바깥 고리, 60초부터 가운데 고리, 6초마다). 연장전이 오면 새 낙하는 멈춰요.
	for _, mark in Logic.scheduleMarks(Logic.MIDDLE_DROP_START + 60) do
		ctx.cleanup:add(task.delay(mark, function()
			if not ctx.isActive() or state.overtimeAt ~= nil then
				return
			end
			local alive: { Logic.AliveTile } = {}
			for _, tile in state.tiles do
				if tile.status == "alive" then
					table.insert(alive, { id = tile.id, ring = tile.ring, cracks = tile.cracks })
				end
			end
			for _, id in Logic.scheduledDrops(mark, alive, ctx.rng) do
				local tile = state.tiles[id]
				if tile then
					ctx.cleanup:add(task.spawn(dropTile, ctx, tile, os.clock() + DROP_WARN, true))
				end
			end
		end))
	end
end

-- 결승 연장전 (m5-01): 정해진 낙하·금 낙하를 멈추고(경고 중인 칸은 끝까지), 폭탄은 연장전 값으로 계속.
-- 남은 칸을 바깥 고리 → 가운데 고리 → 원판 순서로 Logic.overtimeRings 일정대로 없애요.
-- 숟가락·손·테두리는 처음부터 충돌이 없어서 매달려 버틸 곳이 없어요.
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	local now = os.clock()
	local state = roundStates[ctx] or newState(ctx) -- start가 실패했어도 바닥은 없애요
	state.overtimeAt = now - state.startedAt
	for _, step in Logic.overtimeRings(info.collapseDuration, OVERTIME_WARN) do
		ctx.cleanup:add(task.delay(step.warnAt, function()
			for _, tile in state.tiles do
				if tile.ring == step.ring and tile.status ~= "dropped" then
					ctx.cleanup:add(task.spawn(dropTile, ctx, tile, now + step.dropAt, false))
				end
			end
		end))
	end
end

local IkuraBombs: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "연어알 폭탄 접시",
	rule = "떨어지는 연어알 폭탄을 피해 마지막까지 버텨요!",
	build = build,
	start = start,
	overtime = overtime,
}

return IkuraBombs
