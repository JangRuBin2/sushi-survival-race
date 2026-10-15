--!strict
-- Survival 맵 "수산시장" (m5-37, GDD §5.3 v0.7). 얼음물 수조 위 나무 됫박 상자 6 × 6 격자에서 버텨요.
--   · 상자 사이는 물길(5)이라 점프로 건너요. 물에 빠지면(HumanoidRootPart 로컬 y < −6) 탈락.
--   · 커다란 얼음 블록(태그 MarketIceBlock)이 한 줄(Row)을 끝에서 끝까지 미끄러지며 그 줄 사람을 밀어내요.
--     끝에서 2초 멈춘 뒤 옆 줄로 옮기거나(파란 화살표 경고) 그대로 돌아와요. 블록 높이 7은 점프보다 높아서
--     뛰어넘을 수 없어요 — 옆 줄로 피해요.
--   · 하늘에서 ⚠ 표지·그림자 2초 뒤 생선이 이웃 상자 두 개에 철퍼덕 떨어져 주변을 날려요. 5초 동안 누워
--     (올라설 수 있음) 2.5초에 한 번 팔딱이고 물로 가라앉아요. 상자는 없어지지 않아요.
--   · 얼음은 미끄러운 바닥이 아니에요: Ice 태그를 절대 달지 않아요 (dessert-fridge와 겹침 방지, 스펙 D1).
--
-- 치수는 FishMarketLayout, 얼음·생선 계산(일정·위치·맞음·넉백·과녁)은 FishMarketLogic — 둘 다 순수 로직이고
-- tests/map-fish-market.spec.luau가 확인해요. 아트는 FishMarketArt(DecorSpec 목록) → MapKit.buildDecor.
-- 상자는 태그 "MarketCrate" + 속성 Row·Col, 얼음 블록은 "MarketIceBlock". start는 ctx.model 하위 태그 파츠만 찾아요.
-- 얼음 블록·생선은 Anchored로 서버가 CFrame을 정해요(물리 아님). 넉백은 CatCafeShelves.launch와 같은 방식
-- (LinearVelocity를 짧게) + PlatformStand 0.8초 + MoveExempt. 상태는 전부 start 지역 변수(여러 방이 같은 맵을
-- 동시에 돌려도 안 섞여요). Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.FishMarketArt)
local Layout = require(script.Parent.FishMarketLayout)
local Logic = require(script.Parent.FishMarketLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)
local WorldText = require(script.Parent.Parent.WorldText)

local ID = "fish-market"
local CRATE_TAG = "MarketCrate"
local ICE_TAG = "MarketIceBlock"
local FISH_TAG = "MarketFish"
local ICE_MODELS = 4 -- Logic.iceCount 최대
local ICE_PARK_X = 60 -- 대기 중 블록: 수조 가장자리 물에 반쯤 잠겨 떠 있어요
local ICE_PARK_Y = -2.5
local ARROW_BLINK = 0.25

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

-- 판정에 쓰지 않는 보이기만 하는 파츠 (충돌·쿼리·터치 없음)
local function visual(props: { [string]: any }): BasePart
	local p = part(props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = props.CastShadow == true
	return p
end

-- 상자 색: 꿀색 나무 3 shade (밟는 윗면이 가장 밝은 판정 파츠)
local function crateColor(row: number, col: number): Color3
	local k = (row * 2 + col) % 3
	if k == 0 then
		return Color3.fromRGB(238, 200, 138)
	elseif k == 1 then
		return Color3.fromRGB(228, 186, 120)
	end
	return Color3.fromRGB(220, 174, 106)
end

local function iceParkCFrame(origin: CFrame, index: number): CFrame
	local side = if index % 2 == 1 then -1 else 1
	local row = 1 + (index - 1) // 2 * 2 + (if side < 0 then 0 else 1) -- 1, 2, 3, 4
	return origin
		* CFrame.new(side * ICE_PARK_X, ICE_PARK_Y, Layout.rowZ(row))
		* CFrame.Angles(0, math.rad(index * 11), 0)
end

local function buildIceBlock(origin: CFrame, index: number): Model
	local CollectionService = game:GetService("CollectionService")
	local block = Instance.new("Model")
	block.Name = `IceBlock{index}`
	local size = Logic.ICE_SIZE
	local core = visual({
		Name = "Core",
		Size = Vector3.new(size, Logic.ICE_HEIGHT, size),
		Color = Color3.fromRGB(196, 236, 250),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Reflectance = 0.2,
		CastShadow = true,
	})
	core:SetAttribute("IceIndex", index)
	CollectionService:AddTag(core, ICE_TAG)
	core.Parent = block
	local inner = visual({
		Name = "Inner",
		Size = Vector3.new(size - 1.6, Logic.ICE_HEIGHT - 1.6, size - 1.6),
		Color = Color3.fromRGB(140, 206, 238),
		Material = Enum.Material.Ice,
		Transparency = 0.1,
	})
	inner.Parent = block
	-- 윗면 하얀 서리 테두리 (얇은 판)
	local frost = visual({
		Name = "FrostCap",
		Size = Vector3.new(size + 0.2, 0.3, size + 0.2),
		Color = Color3.fromRGB(236, 248, 255),
		Material = Enum.Material.Snow,
	})
	frost.Parent = block
	local emitter = MapKit.makeEmitter("Frost", 3)
	emitter.Parent = core
	block.PrimaryPart = core
	local function place(cf: CFrame)
		core.CFrame = cf
		inner.CFrame = cf
		frost.CFrame = cf * CFrame.new(0, Logic.ICE_HEIGHT / 2 + 0.15, 0)
	end
	place(iceParkCFrame(origin, index))
	return block
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	local crates = Instance.new("Folder")
	crates.Name = "Crates"
	for _, crate in Layout.crates() do
		local tile = part({
			Name = crate.key,
			Size = Vector3.new(Layout.CRATE_SIZE, Layout.CRATE_HEIGHT, Layout.CRATE_SIZE),
			CFrame = origin * CFrame.new(crate.centerX, Layout.TOP_Y - Layout.CRATE_HEIGHT / 2, crate.centerZ),
			Color = crateColor(crate.row, crate.col),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
		})
		tile:SetAttribute("Row", crate.row)
		tile:SetAttribute("Col", crate.col)
		CollectionService:AddTag(tile, CRATE_TAG)
		tile.Parent = crates
	end
	crates.Parent = model

	local iceFolder = Instance.new("Folder")
	iceFolder.Name = "IceBlocks"
	for i = 1, ICE_MODELS do
		buildIceBlock(origin, i).Parent = iceFolder
	end
	iceFolder.Parent = model

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Layout.spawnOffsets() do
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, Layout.TOP_Y + 0.1, offset.z),
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
		if decorPart.Name == Art.SIGN_BOARD then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "SignText"
			gui.Face = Enum.NormalId.Top
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 12
			gui.LightInfluence = 1
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			WorldText.mark(label, "map.fish-market.sign") -- "수산시장", 클라이언트가 그 사람 언어로 채워요 (m5-26)
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.TextColor3 = Color3.fromRGB(184, 44, 40)
			label.Parent = gui
			gui.Parent = decorPart
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
	return model
end

---------------------------------------------------------------- 런타임 모양 (⚠ 표지·그림자·생선·화살표)

-- ⚠ 표지: 노란 삼각형(Wedge 2개) + Neon 주황 테두리 + 검은 느낌표. 두 장을 십자로 엇갈려 어느 쪽에서도 보여요.
local function buildWarnSign(parent: Instance, cf: CFrame): Model
	local sign = Instance.new("Model")
	sign.Name = "FishWarn"
	local W, H = 10, 9
	for _, yaw in { 0, 90 } do
		local base = cf * CFrame.Angles(0, math.rad(yaw), 0)
		for _, layer in
			{
				{ w = W + 1.8, h = H + 1.6, t = 0.4, neon = true, dy = -0.3 },
				{ w = W, h = H, t = 0.7, neon = false, dy = 0 },
			}
		do
			for _, s in { -1, 1 } do
				local wedge = Instance.new("WedgePart")
				wedge.Anchored = true
				wedge.CanCollide = false
				wedge.CanQuery = false
				wedge.CanTouch = false
				wedge.CastShadow = false
				wedge.Size = Vector3.new(layer.t, layer.h, layer.w / 2)
				wedge.Color = if layer.neon then Color3.fromRGB(255, 150, 20) else Color3.fromRGB(255, 214, 40)
				wedge.Material = if layer.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
				-- 두 Wedge의 세운 면이 가운데에서 만나 이등변 삼각형이 돼요
				wedge.CFrame = base
					* CFrame.new(0, layer.dy, s * layer.w / 4)
					* CFrame.Angles(0, if s > 0 then math.pi else 0, 0)
				wedge.Parent = sign
			end
		end
		visual({
			Name = "Bang",
			Size = Vector3.new(1, 3.4, 1.3),
			Color = Color3.fromRGB(20, 20, 24),
			Material = Enum.Material.SmoothPlastic,
			CFrame = base * CFrame.new(0, 0.2, 0),
			Parent = sign,
		})
		visual({
			Name = "Dot",
			Size = Vector3.new(1, 1.1, 1.3),
			Color = Color3.fromRGB(20, 20, 24),
			Material = Enum.Material.SmoothPlastic,
			CFrame = base * CFrame.new(0, -2.6, 0),
			Parent = sign,
		})
	end
	sign.Parent = parent
	return sign
end

type FishLook = { back: Color3, belly: Color3, fin: Color3 }

-- 떨어지는 생선 (긴 축 = 로컬 X, 머리 +X). Hitbox(20 × 5 × 6)가 판정용 — 누워 있을 때만 CanCollide.
local function buildFish(parent: Instance, look: FishLook): (Model, BasePart, { [BasePart]: CFrame })
	local CollectionService = game:GetService("CollectionService")
	local fish = Instance.new("Model")
	fish.Name = "MarketFish"
	local hitbox = part({
		Name = "Hitbox",
		Size = Vector3.new(Logic.FISH_LENGTH, Logic.FISH_HEIGHT, Logic.FISH_WIDTH),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	CollectionService:AddTag(hitbox, FISH_TAG)
	hitbox.Parent = fish
	fish.PrimaryPart = hitbox
	local offsets: { [BasePart]: CFrame } = {}
	local function add(name: string, shape: Enum.PartType?, size: Vector3, color: Color3, offset: CFrame)
		local p = visual({
			Name = name,
			Size = size,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.15,
			CastShadow = true,
		})
		if shape then
			(p :: Part).Shape = shape
		end
		p.Parent = fish
		offsets[p] = offset
	end
	local cyl, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	add("Body", cyl, Vector3.new(11, 5, 5), look.belly, CFrame.new(0, 0, 0))
	add("Back", cyl, Vector3.new(10.4, 3.8, 3.8), look.back, CFrame.new(0, 0.85, 0))
	add("Head", ball, Vector3.new(5, 5, 5), look.belly, CFrame.new(5.5, 0, 0))
	add("HeadBack", ball, Vector3.new(4, 4, 4), look.back, CFrame.new(5.6, 0.7, 0))
	add("Snout", ball, Vector3.new(3.2, 3.2, 3.2), look.belly, CFrame.new(8.2, -0.2, 0))
	add("Tail", ball, Vector3.new(4, 4, 4), look.back, CFrame.new(-5.6, 0.2, 0))
	add("Peduncle", cyl, Vector3.new(3, 2.4, 2.4), look.back, CFrame.new(-7.6, 0.2, 0))
	add(
		"TailFinA",
		nil,
		Vector3.new(3.4, 1.2, 0.4),
		look.fin,
		CFrame.new(-9.6, 1.3, 0) * CFrame.Angles(0, 0, math.rad(40))
	)
	add(
		"TailFinB",
		nil,
		Vector3.new(3.4, 1.2, 0.4),
		look.fin,
		CFrame.new(-9.6, -0.9, 0) * CFrame.Angles(0, 0, math.rad(-40))
	)
	add(
		"Dorsal",
		nil,
		Vector3.new(4, 1.4, 0.4),
		look.fin,
		CFrame.new(-0.5, 2.9, 0) * CFrame.Angles(0, 0, math.rad(-12))
	)
	for _, s in { -1, 1 } do
		add("Eye", ball, Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(240, 240, 236), CFrame.new(7.2, 0.7, s * 1.9))
		add("Pupil", ball, Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(20, 20, 26), CFrame.new(7.45, 0.75, s * 2.35))
	end
	fish.Parent = parent
	return fish, hitbox, offsets
end

local function placeFish(hitbox: BasePart, offsets: { [BasePart]: CFrame }, cf: CFrame)
	hitbox.CFrame = cf
	for p, offset in offsets do
		p.CFrame = cf * offset
	end
end

-- 파란 화살표 (얼음 블록이 들어올 줄 끝 상자 윗면 위): 몸통 + 꺾쇠 두 개, dir 방향(로컬 ±X)을 가리켜요
local function buildArrow(parent: Instance, cf: CFrame, dir: number): { BasePart }
	local parts: { BasePart } = {}
	local color = Color3.fromRGB(40, 150, 255)
	local base = cf * CFrame.Angles(0, if dir < 0 then math.pi else 0, 0)
	local function add(size: Vector3, offset: CFrame)
		local p = visual({
			Name = "IceArrow",
			Size = size,
			Color = color,
			Material = Enum.Material.Neon,
			CFrame = base * offset,
			Parent = parent,
		})
		table.insert(parts, p)
	end
	add(Vector3.new(5, 0.12, 1.4), CFrame.new(-1, 0, 0))
	add(Vector3.new(3.6, 0.12, 1.4), CFrame.new(1.9, 0, -1.1) * CFrame.Angles(0, math.rad(40), 0))
	add(Vector3.new(3.6, 0.12, 1.4), CFrame.new(1.9, 0, 1.1) * CFrame.Angles(0, math.rad(-40), 0))
	return parts
end

---------------------------------------------------------------- start

type Falling = {
	pair: Logic.Pair,
	warnStart: number,
	slamAt: number,
	sign: Model,
	shadow: BasePart,
	fish: Model,
	hitbox: BasePart,
	offsets: { [BasePart]: CFrame },
	baseCF: CFrame, -- 누운 자리 (높이 0, 방향 포함)
	keys: { string },
}
type Lying = {
	pair: Logic.Pair,
	lieStart: number,
	sinkAt: number,
	collided: boolean,
	flopped: boolean,
	sinking: boolean,
	fish: Model,
	hitbox: BasePart,
	offsets: { [BasePart]: CFrame },
	baseCF: CFrame,
	keys: { string },
}

local SINK_TIME = 1.2
local FLOP_TIME = 0.5

local function start(ctx: MapTypes.RoundContext)
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local rng = ctx.rng :: any

	-- 이 방 Model 안의 상자·얼음 블록만 (다른 방의 같은 맵과 안 섞여요)
	local crateParts: { [string]: BasePart } = {}
	for _, instance in CollectionService:GetTagged(CRATE_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			local row, col = instance:GetAttribute("Row"), instance:GetAttribute("Col")
			if type(row) == "number" and type(col) == "number" then
				crateParts[Layout.crateKey(row, col)] = instance
			end
		end
	end
	local iceModels: { Model } = {}
	for _, instance in CollectionService:GetTagged(ICE_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			local index = instance:GetAttribute("IceIndex")
			local model = instance.Parent
			if type(index) == "number" and model and model:IsA("Model") then
				iceModels[index] = model
			end
		end
	end

	local hazards = Instance.new("Folder")
	hazards.Name = "Hazards"
	hazards.Parent = ctx.model
	ctx.cleanup:add(hazards)

	local crates = Layout.crates()
	local startedAt = os.clock()
	local director = Logic.newIceDirector()
	local modelOf: { [number]: Model } = {} -- 블록 id → 얼음 Model
	local riseFrom: { [number]: CFrame } = {} -- 블록 id → 경고 동안 떠오르기 시작하는 자리
	local usedModel: { [number]: boolean } = {}
	local arrows: { { parts: { BasePart }, untilAt: number } } = {}
	local iceReady: { [Player]: number } = {}
	local fishReady: { [Player]: number } = {}
	local standUntil: { [Humanoid]: number } = {}
	local falling: { Falling } = {}
	local lying: { Lying } = {}
	local nextFishAt = Logic.FISH_START

	local function setIce(model: Model, cf: CFrame)
		local core = model:FindFirstChild("Core") :: BasePart?
		local inner = model:FindFirstChild("Inner") :: BasePart?
		local frost = model:FindFirstChild("FrostCap") :: BasePart?
		if core then
			core.CFrame = cf
		end
		if inner then
			inner.CFrame = cf
		end
		if frost then
			frost.CFrame = cf * CFrame.new(0, Logic.ICE_HEIGHT / 2 + 0.15, 0)
		end
	end

	-- 넉백: LinearVelocity를 KNOCK_HOLD초 + PlatformStand PLATFORM_STAND초 + MoveExempt
	local function knock(player: Player, k: Logic.Knock, exempt: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and root and root:IsA("BasePart")) or root.Anchored then
			return
		end
		MoveExempt.mark(character, exempt)
		local direction = origin:VectorToWorldSpace(Vector3.new(k.dirX, 0, k.dirZ))
		local velocity = direction * k.horizontal + Vector3.new(0, k.up, 0)
		local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if attachment == nil then
			local created = Instance.new("Attachment")
			created.Name = "FishMarketAttachment"
			created.Parent = root
			ctx.cleanup:add(created)
			attachment = created
		end
		local push = Instance.new("LinearVelocity")
		push.Name = "FishMarketLaunch"
		push.Attachment0 = attachment :: Attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		push.VectorVelocity = velocity
		push.MaxForce = math.huge
		push.Parent = root
		root.AssemblyLinearVelocity = velocity
		ctx.cleanup:add(push)
		ctx.cleanup:add(task.delay(Logic.KNOCK_HOLD, function()
			push:Destroy()
		end))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
			local untilAt = os.clock() + Logic.PLATFORM_STAND
			standUntil[humanoid] = untilAt
			ctx.cleanup:add(task.delay(Logic.PLATFORM_STAND, function()
				if standUntil[humanoid] == untilAt then
					standUntil[humanoid] = nil
					if humanoid.Parent and not root.Anchored then
						humanoid.PlatformStand = false
					end
				end
			end))
		end
	end
	-- 라운드가 끝나 delay가 취소돼도 넘어진 채로 남지 않게
	ctx.cleanup:add(function()
		for humanoid in standUntil do
			local character = humanoid.Parent
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid.Parent and not (root and root:IsA("BasePart") and root.Anchored) then
				humanoid.PlatformStand = false
			end
		end
		table.clear(standUntil)
	end)

	local function racerRel(player: Player): (BasePart?, Vector3?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local rel: Vector3 = origin:PointToObjectSpace(root.Position)
			return root, rel
		end
		return nil, nil
	end

	local function endCrate(row: number, side: number): BasePart?
		local col = if side > 0 then Layout.GRID - 1 else 0
		return crateParts[Layout.crateKey(math.floor(row + 0.5), col)]
	end

	local function showIceWarning(ev: Logic.IceEvent, now: number)
		local crate = endCrate(ev.row, ev.side)
		if crate == nil then
			return
		end
		local col = if ev.side > 0 then Layout.GRID - 1 else 0
		local cf = origin * CFrame.new(Layout.colX(col), Layout.TOP_Y + 0.08, Layout.rowZ(ev.row))
		table.insert(arrows, { parts = buildArrow(hazards, cf, ev.dir), untilAt = now + Logic.ICE_WARN })
		MapSfx.play(crate, "IceBlockSlide")
	end

	local function fishLook(): FishLook
		if rng:NextNumber() < 0.5 then
			-- 고등어: 은청 등 + 은빛 배
			return {
				back = Color3.fromRGB(60, 98, 124),
				belly = Color3.fromRGB(200, 208, 218),
				fin = Color3.fromRGB(46, 70, 92),
			}
		end
		-- 도미: 분홍빛 등 + 연한 배
		return {
			back = Color3.fromRGB(214, 132, 128),
			belly = Color3.fromRGB(240, 210, 200),
			fin = Color3.fromRGB(190, 100, 100),
		}
	end

	local function blockedKeys(): { [string]: boolean }
		local blocked: { [string]: boolean } = {}
		for _, f in falling do
			for _, key in f.keys do
				blocked[key] = true
			end
		end
		for _, l in lying do
			for _, key in l.keys do
				blocked[key] = true
			end
		end
		return blocked
	end

	local function dropFish(elapsed: number)
		local racers: { Logic.Point } = {}
		for _, player in ctx.getRacers() do
			local _, rel = racerRel(player)
			if rel then
				table.insert(racers, { x = rel.X, z = rel.Z })
			end
		end
		local pair = Logic.pickFishTarget(rng, racers, crates, blockedKeys())
		if pair == nil then
			return
		end
		local flip = rng:NextNumber() < 0.5
		local yaw = (if pair.axis == "Z" then math.pi / 2 else 0) + (if flip then math.pi else 0)
		local baseCF = origin
			* CFrame.new(pair.centerX, Layout.TOP_Y + Logic.FISH_HEIGHT / 2, pair.centerZ)
			* CFrame.Angles(0, yaw, 0)
		local sign = buildWarnSign(
			hazards,
			origin * CFrame.new(pair.centerX, Layout.TOP_Y + Logic.FISH_SIGN_HEIGHT, pair.centerZ)
		)
		local shadow = visual({
			Name = "FishShadow",
			Size = Vector3.new(Logic.FISH_LENGTH * 0.4, 0.1, Logic.FISH_WIDTH * 0.4),
			Color = Color3.fromRGB(16, 24, 34),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.45,
			CFrame = baseCF * CFrame.new(0, -Logic.FISH_HEIGHT / 2 + 0.1, 0),
			Parent = hazards,
		})
		local fish, hitbox, offsets = buildFish(hazards, fishLook())
		placeFish(hitbox, offsets, baseCF + Vector3.new(0, Logic.FISH_DROP_HEIGHT, 0))
		local keys = {
			Layout.crateKey(pair.a.row, pair.a.col),
			Layout.crateKey(pair.b.row, pair.b.col),
		}
		table.insert(falling, {
			pair = pair,
			warnStart = elapsed,
			slamAt = elapsed + Logic.FISH_WARN,
			sign = sign,
			shadow = shadow,
			fish = fish,
			hitbox = hitbox,
			offsets = offsets,
			baseCF = baseCF,
			keys = keys,
		})
		local crate = crateParts[keys[1]]
		if crate then
			MapSfx.play(crate, "MarketFishWarn")
		end
	end

	local function knockAround(pair: Logic.Pair, hitFn: (axis: "X" | "Z", rel: Logic.Rel) -> Logic.Knock?)
		local now = os.clock()
		for _, player in ctx.getRacers() do
			local _, rel = racerRel(player)
			if rel == nil then
				continue
			end
			local readyAt = fishReady[player]
			if readyAt and now < readyAt then
				continue
			end
			local k = hitFn(pair.axis, {
				x = rel.X - pair.centerX,
				y = rel.Y - Layout.FOOT_OFFSET - Layout.TOP_Y,
				z = rel.Z - pair.centerZ,
			})
			if k then
				fishReady[player] = now + Logic.FISH_COOLDOWN
				knock(player, k, Logic.FISH_MOVE_EXEMPT)
			end
		end
	end

	local function slam(f: Falling, elapsed: number)
		f.sign:Destroy()
		f.shadow:Destroy()
		placeFish(f.hitbox, f.offsets, f.baseCF)
		knockAround(f.pair, Logic.fishKnockback)
		MapSfx.play(f.hitbox, "MarketFishSlam")
		local splash = MapKit.makeEmitter("SeaSpray")
		splash.Enabled = false
		splash.Parent = f.hitbox
		splash:Emit(30)
		table.insert(lying, {
			pair = f.pair,
			lieStart = elapsed,
			sinkAt = elapsed + Logic.FISH_LIE,
			collided = false,
			flopped = false,
			sinking = false,
			fish = f.fish,
			hitbox = f.hitbox,
			offsets = f.offsets,
			baseCF = f.baseCF,
			keys = f.keys,
		})
		-- 누운 생선이 MAX_LYING을 넘으면 가장 오래된 것부터 지금 가라앉혀요
		local alive = 0
		for i = #lying, 1, -1 do
			local l = lying[i]
			if not l.sinking then
				alive += 1
				if alive > Logic.MAX_LYING and l.sinkAt > elapsed then
					l.sinkAt = elapsed
				end
			end
		end
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		---------------------------------------------------- 얼음 블록
		for _, ev in Logic.stepIce(director, elapsed, rng) do
			if ev.kind == "Spawn" then
				-- 같은 쪽 가장자리에 떠 있던 블록을 먼저 써요 (격자 위를 가로질러 날아가지 않게).
				-- 그쪽에 남은 게 없으면 다른 블록을 출발 끝 물속에서 떠오르게 해요.
				local chosen: number? = nil
				for i = 1, #iceModels do
					if not usedModel[i] and (if i % 2 == 1 then -1 else 1) == ev.side then
						chosen = i
						break
					end
				end
				local sameSide = chosen ~= nil
				if chosen == nil then
					for i = 1, #iceModels do
						if not usedModel[i] then
							chosen = i
							break
						end
					end
				end
				if chosen then
					usedModel[chosen] = true
					modelOf[ev.block.id] = iceModels[chosen]
					local startX = ev.side * Logic.ICE_X_END
					riseFrom[ev.block.id] = if sameSide
						then iceParkCFrame(origin, chosen)
						else origin * CFrame.new(startX, Logic.ICE_HEIGHT / 2 - 9, Layout.rowZ(ev.row))
				end
			end
			showIceWarning(ev, now)
		end
		for _, block in director.blocks do
			local model = modelOf[block.id]
			if model == nil then
				continue
			end
			local state = Logic.iceState(block, elapsed)
			local target = origin * CFrame.new(state.x, Logic.ICE_HEIGHT / 2, Layout.rowZ(state.row))
			if state.phase == "Wait" then
				-- 대기 자리에서 출발 끝으로 떠올라요 (경고 동안)
				local alpha = math.clamp(1 - (block.born - elapsed) / Logic.ICE_WARN, 0, 1)
				local from = riseFrom[block.id] or target
				setIce(model, from:Lerp(target, alpha))
			else
				setIce(model, target)
			end
		end
		for i = #arrows, 1, -1 do
			local arrow = arrows[i]
			if now >= arrow.untilAt then
				for _, p in arrow.parts do
					p:Destroy()
				end
				table.remove(arrows, i)
			else
				local on = math.floor((arrow.untilAt - now) / ARROW_BLINK) % 2 == 0
				for _, p in arrow.parts do
					p.Transparency = if on then 0 else 0.6
				end
			end
		end

		---------------------------------------------------- 생선
		while elapsed >= nextFishAt and ctx.isActive() do
			local wave = Logic.fishWave(nextFishAt)
			if wave == nil then
				nextFishAt = Logic.FISH_START
				break
			end
			for _ = 1, wave.count do
				dropFish(elapsed)
			end
			nextFishAt += wave.interval
		end
		for i = #falling, 1, -1 do
			local f = falling[i]
			if elapsed >= f.slamAt then
				table.remove(falling, i)
				slam(f, elapsed)
			else
				local alpha = math.clamp((elapsed - f.warnStart) / Logic.FISH_WARN, 0, 1)
				local height = Logic.FISH_DROP_HEIGHT * (1 - alpha * alpha)
				local tilt = CFrame.Angles(0, 0, math.rad(-25 * (1 - alpha)))
				placeFish(f.hitbox, f.offsets, (f.baseCF + Vector3.new(0, height, 0)) * tilt)
				local grow = 0.4 + 0.6 * alpha
				f.shadow.Size = Vector3.new(Logic.FISH_LENGTH * grow, 0.1, Logic.FISH_WIDTH * grow)
				f.shadow.Transparency = 0.6 - 0.25 * alpha
			end
		end
		for i = #lying, 1, -1 do
			local l = lying[i]
			local t = elapsed - l.lieStart
			if not l.sinking and elapsed >= l.sinkAt then
				l.sinking = true
				l.hitbox.CanCollide = false
				l.sinkAt = elapsed
			end
			if l.sinking then
				local alpha = math.clamp((elapsed - l.sinkAt) / SINK_TIME, 0, 1)
				placeFish(
					l.hitbox,
					l.offsets,
					l.baseCF * CFrame.new(0, -9 * alpha, 0) * CFrame.Angles(math.rad(70 * alpha), 0, 0)
				)
				if alpha >= 1 then
					l.fish:Destroy()
					table.remove(lying, i)
				end
				continue
			end
			if not l.collided and t >= Logic.FISH_COLLIDE_DELAY then
				l.collided = true
				l.hitbox.CanCollide = true
			end
			if not l.flopped and t >= Logic.FISH_FLOP_AT then
				l.flopped = true
				knockAround(l.pair, Logic.flopKnockback)
				MapSfx.play(l.hitbox, "MarketFishSlam")
			end
			local ft = t - Logic.FISH_FLOP_AT
			if ft >= 0 and ft <= FLOP_TIME then
				local a = ft / FLOP_TIME
				local lift = 3 * math.sin(a * math.pi)
				local roll = math.rad(25 * math.sin(a * 2 * math.pi))
				placeFish(l.hitbox, l.offsets, l.baseCF * CFrame.new(0, lift, 0) * CFrame.Angles(roll, 0, 0))
			elseif ft > FLOP_TIME and ft < FLOP_TIME + 0.1 then
				placeFish(l.hitbox, l.offsets, l.baseCF)
			end
		end

		---------------------------------------------------- 레이서: 낙하 · 얼음 맞음
		for _, player in ctx.getRacers() do
			local _, rel = racerRel(player)
			if rel == nil then
				continue
			end
			if rel.Y < Layout.ELIMINATION_Y or rel.Y < Layout.SAFETY_NET_Y then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
				continue
			end
			local readyAt = iceReady[player]
			if readyAt and now < readyAt then
				continue
			end
			local footY = rel.Y - Layout.FOOT_OFFSET - Layout.TOP_Y
			for _, block in director.blocks do
				local state = Logic.iceState(block, elapsed)
				if state.phase == "Move" and Logic.iceHit(rel.X - state.x, rel.Z - Layout.rowZ(state.row), footY) then
					iceReady[player] = now + Logic.ICE_COOLDOWN
					knock(player, {
						dirX = state.dir,
						dirZ = 0,
						horizontal = Logic.ICE_KNOCK_HORIZONTAL,
						up = Logic.ICE_KNOCK_UP,
					}, Logic.ICE_MOVE_EXEMPT)
					break
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "수산시장",
	rule = "떨어지는 생선과 밀려오는 얼음을 피해 상자 위에서 버텨요!",
	timeLimit = 75, -- Survival 기본 60 + 15 (60~75초 서든데스, 스펙 D5)
	build = build,
	start = start,
	lighting = Art.LIGHTING,
}

return map
