--!strict
-- Final 맵 "온천탕 인형뽑기" (m5-39, GDD §5.3 3차 배치). 해 질 녘 노천탕 가운데 섬에 분홍 탁상 인형뽑기가 있고,
-- 둘레에 높이가 다른 나무 데크 고리 4단(윗면 0·2·4·6)이 떠 있어요.
--   · 인형뽑기 "쿵": 경고 1.5초(집게가 내려가고 밑바닥 불빛 깜빡) 뒤 가운데서 충격파 고리가 초당 24로 퍼져요.
--     고리 앞면이 지나가는 순간 데크에 서 있으면(발 ≤ 윗면 + 1.2) 바깥으로 튕겨요 — 점프하면 안 맞아요.
--     4단(가장 안)은 ×1.3. 간격은 12 → 9 → 6초(+고리 2개), 연장전 3초(+고리 2개).
--   · 온천수: 10초마다 한 칸(−3 → 4.5) 차올라요. 물이 그 단 윗면 − 1에 닿으면 그 단 데크가 통째로 가라앉아요
--     (1단 20초, 2단 40초, 3단 60초, 각각 3초 경고). 4단은 연장전까지 남아요. 발이 물 − 0.5보다 낮으면 "목욕 끝".
--   · 연장전: 물은 멈추고, 남은 데크를 낮은 단부터 하나씩 collapseDuration 안에 가라앉히고, 마지막에
--     인형뽑기 몸체 충돌도 꺼서 설 곳이 0이 돼요 (장식은 처음부터 충돌 없음 — 매달릴 곳 없음, m5-18 B1).
--
-- 치수는 OnsenClawLayout, 시간·판정 계산은 OnsenClawLogic (둘 다 순수, tests/map-onsen-claw.spec.luau).
-- 장식은 OnsenClawArt → MapKit.buildDecor. 데크는 태그 "OnsenDeck"(Model, 속성 Tier·Index·Top), 조각 파츠가 판정 바닥.
-- 이 맵은 떨어진 사람을 ctx.eliminate로 알리기만 해요 — 우승·동시 낙하·시간 종료는 RoundService (m2-05, m5-01).
-- 상태는 start 지역 변수와 roundStates[ctx](start·overtime이 같이 봄)에 둬서 여러 방이 섞이지 않아요.
-- Roblox API는 build/start/overtime 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.OnsenClawArt)
local Layout = require(script.Parent.OnsenClawLayout)
local Logic = require(script.Parent.OnsenClawLogic)
local MapKit = require(script.Parent.MapKit)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "onsen-claw"
local DECK_TAG = "OnsenDeck"
local BODY_TAG = "OnsenClawBody"
local WATER_TAG = "OnsenWater"
local WATER_NAME = "OnsenWater"
local WATER_FOLLOWERS = "WaterFollowers"
local CLAW_RIG = "ClawRig"
local SLAM_LIGHTS = "SlamLights"
local WAVES = "Waves"
local WATER_THICKNESS = 0.4
local PROBE_LENGTH = 4.5 -- 루트 중심 → 발(3) + 1.2 + 여유 — 데크에 서 있을 때만 닿아요
local RING_SEGMENTS = 24
local VISUAL_STEP = 1 / 30 -- 고리·집게 보여주기 갱신 간격
local BLINK = 0.15
local SHAKE = 0.12
local BUBBLE_EVERY = 4 -- 경고 거품 파티클은 데크 4개마다 하나

-- Color3는 Roblox API라 함수 안에서만 만들어요
local function color3(rgb: MapKitLogic.RGB): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
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

local function ghost(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local UPRIGHT_Z = math.rad(90)

-- 윗면이 topY인 세운 원판 (origin 로컬, 탕 중심)
local function discCFrame(origin: CFrame, topY: number, thickness: number): CFrame
	return origin * CFrame.new(Layout.CENTER_X, topY - thickness / 2, Layout.CENTER_Z) * CFrame.Angles(0, 0, UPRIGHT_Z)
end

local function taggedInModel(model: Model, tag: string): { Instance }
	local CollectionService = game:GetService("CollectionService")
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if model:IsAncestorOf(instance) then
			table.insert(list, instance)
		end
	end
	return list
end

---------------------------------------------------------------- build

local function buildDeck(deck: Layout.Deck, origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local model = Instance.new("Model")
	model.Name = deck.key
	for k, seg in Layout.deckSegments(deck) do
		local p = part({
			Name = string.format("Plank%02d", k),
			Size = Vector3.new(seg.depth, Layout.DECK_THICKNESS, seg.width),
			CFrame = origin
				* CFrame.new(seg.x, seg.top - Layout.DECK_THICKNESS / 2, seg.z)
				* CFrame.Angles(0, math.rad(seg.angle), 0),
			Color = color3(Art.deckColor(deck.tier, deck.index, k)),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
		})
		p.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic) -- 재질이 물성을 바꾸지 않게
		p:SetAttribute("Tier", deck.tier)
		p.Parent = model
	end
	-- 가장자리 판·받침 기둥: 데크와 같이 가라앉는 장식 (충돌 없음, anim 없음)
	MapKit.buildDecor(Art.deckDecor(deck), origin, model)
	model:SetAttribute("Tier", deck.tier)
	model:SetAttribute("Index", deck.index)
	model:SetAttribute("Top", deck.top)
	CollectionService:AddTag(model, DECK_TAG)
	return model
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local model = Instance.new("Model")
	model.Name = ID

	local decks = Instance.new("Folder")
	decks.Name = "Decks"
	for _, deck in Layout.decks() do
		buildDeck(deck, origin).Parent = decks
	end
	decks.Parent = model

	-- 인형뽑기 몸체: 판정 충돌 상자 (보이는 모습은 Art 장식이 같은 자리에). 연장전 끝에 충돌을 꺼요.
	local bodyHeight = Layout.BODY_TOP_Y - Layout.BODY_BOTTOM_Y
	local body = part({
		Name = "ClawBody",
		Size = Vector3.new(Layout.BODY_HALF * 2, bodyHeight, Layout.BODY_HALF * 2),
		CFrame = origin * CFrame.new(Layout.CENTER_X, Layout.BODY_BOTTOM_Y + bodyHeight / 2, Layout.CENTER_Z),
		Transparency = 1,
		CanCollide = true,
		CastShadow = false,
	})
	CollectionService:AddTag(body, BODY_TAG)
	body.Parent = model

	-- 움직이는 집게·밑바닥 불빛 (서버가 옮기고 칠해요, 충돌 없음)
	local rig = Instance.new("Folder")
	rig.Name = CLAW_RIG
	MapKit.buildDecor(Art.clawRig(), origin, rig)
	rig.Parent = model
	local lights = Instance.new("Folder")
	lights.Name = SLAM_LIGHTS
	MapKit.buildDecor(Art.slamLights(), origin, lights)
	lights.Parent = model

	-- 온천수 표면 (보여 주기만, 충돌 없음 — 판정은 숫자 Logic.waterHeight). start가 따라 올려요.
	local water = part({
		Name = WATER_NAME,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(WATER_THICKNESS, Layout.POOL_RADIUS * 2, Layout.POOL_RADIUS * 2),
		CFrame = discCFrame(origin, Logic.waterVisual(0), WATER_THICKNESS),
		Color = color3(Art.COLORS.water),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Reflectance = 0.15,
	})
	ghost(water)
	CollectionService:AddTag(water, WATER_TAG)
	local glow = MapKit.makeLight(Art.WATER_LIGHT)
	if glow:IsA("SurfaceLight") then
		glow.Face = Enum.NormalId.Right -- 세운 원판: 로컬 +X = 위
	end
	glow.Parent = water
	water.Parent = model
	-- 물을 따라 오르는 불투명한 깊은 물빛 (반투명 판은 표면 1장만 — 휴대폰 성능)
	local followers = Instance.new("Folder")
	followers.Name = WATER_FOLLOWERS
	local deep = part({
		Name = "WaterDepth",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(WATER_THICKNESS, Layout.POOL_RADIUS * 2 - 0.4, Layout.POOL_RADIUS * 2 - 0.4),
		CFrame = water.CFrame * CFrame.new(-3, 0, 0),
		Color = color3(Art.COLORS.waterDeep),
		Material = Enum.Material.SmoothPlastic,
	})
	ghost(deep)
	deep.Parent = followers
	followers.Parent = model

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, point in Layout.spawnPoints() do
		local pos = Vector3.new(point.x, point.y + 0.1, point.z)
		local center = Vector3.new(Layout.CENTER_X, point.y + 0.1, Layout.CENTER_Z)
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.lookAt(pos, center), -- 가운데 인형뽑기를 바라봐요
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
	return model
end

---------------------------------------------------------------- 라운드 상태

type DeckInfo = {
	model: Model,
	tier: number,
	index: number,
	parts: { BasePart },
	rims: { BasePart },
	rimColors: { [BasePart]: Color3 },
	pivot: CFrame,
}

type RoundState = {
	startedAt: number, -- os.clock() 출발
	overtimeAt: number?, -- 연장전 시작 (출발 기준 초)
	decks: { DeckInfo },
	sunk: { [Model]: boolean },
	body: BasePart?,
}

local roundStates: { [MapTypes.RoundContext]: RoundState } = {}

local function collectDecks(model: Model): { DeckInfo }
	local list: { DeckInfo } = {}
	for _, instance in taggedInModel(model, DECK_TAG) do
		if not instance:IsA("Model") then
			continue
		end
		local info: DeckInfo = {
			model = instance,
			tier = instance:GetAttribute("Tier") :: number,
			index = instance:GetAttribute("Index") :: number,
			parts = {},
			rims = {},
			rimColors = {},
			pivot = instance:GetPivot(),
		}
		for _, d in instance:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(info.parts, d)
				if d.Name == Art.RIM_NAME then
					table.insert(info.rims, d)
					info.rimColors[d] = d.Color
				end
			end
		end
		table.insert(list, info)
	end
	table.sort(list, function(a: DeckInfo, b: DeckInfo): boolean
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.index < b.index
	end)
	return list
end

-- 데크 하나를 가라앉혀요: 충돌을 바로 끄고 1초에 걸쳐 5 내려간 뒤 안 보이게. 두 번 불러도 한 번만.
local function sinkDeck(ctx: MapTypes.RoundContext, sunk: { [Model]: boolean }, info: DeckInfo)
	if sunk[info.model] then
		return
	end
	sunk[info.model] = true
	local TweenService = game:GetService("TweenService")
	info.model:PivotTo(info.pivot)
	for _, p in info.parts do
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		local goal = p.CFrame - Vector3.new(0, Logic.SINK_DROP, 0)
		local tween = TweenService:Create(
			p,
			TweenInfo.new(Logic.SINK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = goal }
		)
		tween:Play()
		ctx.cleanup:add(tween)
	end
	MapSfx.play(info.parts[1], "TileVanish")
	ctx.cleanup:add(task.delay(Logic.SINK_DURATION, function()
		for _, p in info.parts do
			if p.Parent then
				p.Transparency = 1
			end
		end
	end))
end

-- 경고: 가장자리 판이 주황·흰색으로 깜빡이고, 데크가 삐걱 흔들리고, 데크 아래 물에서 거품이 솟아요.
-- dropAt(os.clock)이 되면 가라앉혀요. abort()가 true가 되면(연장전이 정상 일정을 가져감) 원래대로 돌리고 끝.
local function warnAndSink(
	ctx: MapTypes.RoundContext,
	state: RoundState,
	infos: { DeckInfo },
	dropAt: number,
	abort: (() -> boolean)?
)
	local warnA = color3(Art.COLORS.warn)
	local warnB = color3(Art.COLORS.warnWhite)
	local bubbles: { BasePart } = {}
	local waterT = os.clock() - state.startedAt
	if state.overtimeAt then
		waterT = math.min(waterT, state.overtimeAt)
	end
	-- 거품은 데크 BUBBLE_EVERY개마다 하나 (1단 12개가 한꺼번에 경고해도 파티클 3개)
	for n, info in infos do
		if state.sunk[info.model] or (n - 1) % BUBBLE_EVERY ~= 0 then
			continue
		end
		-- 데크 가운데(가운데 반지름·가운데 각도) 아래 물 표면
		local tier = Layout.TIERS[info.tier]
		local sweep = 360 / tier.count
		local cx, cz = Layout.polar(tier.angleOffset + (info.index - 0.5) * sweep, (tier.inner + tier.outer) / 2)
		local holder = part({
			Name = "SinkBubbles",
			Size = Vector3.new(4, 0.2, 4),
			CFrame = ctx.origin * CFrame.new(cx, Logic.waterVisual(waterT) + 0.1, cz),
			Transparency = 1,
		})
		ghost(holder)
		MapKit.makeEmitter("Bubbles", 14).Parent = holder
		holder.Parent = ctx.model
		ctx.cleanup:add(holder)
		table.insert(bubbles, holder)
	end
	MapSfx.play(infos[1] and infos[1].parts[1], "OnsenRise")

	local function restore()
		for _, info in infos do
			if state.sunk[info.model] then
				continue
			end
			info.model:PivotTo(info.pivot)
			for _, rim in info.rims do
				rim.Color = info.rimColors[rim]
			end
		end
	end

	local on = true
	local tick = 0
	while os.clock() < dropAt do
		if not ctx.isActive() then
			return
		end
		if abort and abort() then
			restore()
			for _, b in bubbles do
				b:Destroy()
			end
			return
		end
		tick += 1
		for _, info in infos do
			if state.sunk[info.model] then
				continue
			end
			for _, rim in info.rims do
				rim.Color = if on then warnA else warnB
			end
			-- 삐걱: 아주 작게 위아래 (평행 이동만 — 피벗 위치와 상관없이 데크가 제자리에서 떨려요)
			local wobble = if tick % 2 == 0 then SHAKE else -SHAKE
			info.model:PivotTo(info.pivot + Vector3.new(0, wobble, 0))
		end
		on = not on
		task.wait(math.min(BLINK, math.max(dropAt - os.clock(), 0)))
	end
	if not ctx.isActive() or (abort and abort()) then
		if ctx.isActive() then
			restore()
		end
		return
	end
	for _, info in infos do
		sinkDeck(ctx, state.sunk, info)
	end
	for _, b in bubbles do
		b:Destroy()
	end
end

---------------------------------------------------------------- 충격파 고리 (보여주기)

type Ring = {
	startAt: number, -- 출발 기준 초
	prevRadius: number,
	hit: { [Player]: boolean },
	visual: Model?,
}

local function makeRingVisual(ctx: MapTypes.RoundContext, parent: Instance, transparency: number): Model
	local ring = Instance.new("Model")
	ring.Name = "ShockRing"
	for i = 1, RING_SEGMENTS do
		for _, layer in { "Outer", "Inner" } do
			local p = part({
				Name = layer,
				Color = color3(if layer == "Outer" then Art.COLORS.ringOuter else Art.COLORS.ringInner),
				Material = Enum.Material.Neon,
				Transparency = transparency,
				Size = Vector3.new(1, 0.25, 1),
			})
			ghost(p)
			p:SetAttribute("Segment", i)
			p.Parent = ring
		end
	end
	ring.Parent = parent
	ctx.cleanup:add(ring)
	return ring
end

-- 고리 앞면 반지름 r, 높이 y에 맞춰 조각을 옮겨요 (바깥 흰색 띠가 앞면, 안쪽 주황 띠가 뒤)
local function placeRing(ctx: MapTypes.RoundContext, ring: Model, radius: number, y: number)
	local half = Logic.RING_THICKNESS / 2
	for _, p in ring:GetChildren() do
		if not p:IsA("BasePart") then
			continue
		end
		local i = p:GetAttribute("Segment") :: number
		local outer = p.Name == "Outer"
		local r = if outer then radius - half / 2 else radius - half * 1.5
		r = math.max(r, 0.5)
		local angle = (i - 0.5) * 360 / RING_SEGMENTS
		local x, z = Layout.polar(angle, r)
		local chord = 2 * r * math.sin(math.pi / RING_SEGMENTS) * 1.06
		p.Size = Vector3.new(half, 0.25, chord)
		p.CFrame = ctx.origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(angle), 0)
	end
end

---------------------------------------------------------------- start

-- 서버가 root를 짧게(hold초) 강제 속도로 띄워요 (TempuraPot·SoySwampHazards와 같은 방식)
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3, hold: number)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "OnsenClawAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "ShockwaveLaunch"
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
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local startedAt = os.clock()

	local state: RoundState = {
		startedAt = startedAt,
		overtimeAt = nil,
		decks = collectDecks(ctx.model),
		sunk = {},
		body = nil,
	}
	for _, instance in taggedInModel(ctx.model, BODY_TAG) do
		if instance:IsA("BasePart") then
			state.body = instance
		end
	end
	roundStates[ctx] = state
	ctx.cleanup:add(function()
		roundStates[ctx] = nil
	end)

	local function elapsed(): number
		return os.clock() - startedAt
	end
	-- 연장전이면 물·데크 일정이 그 시각에서 멈춰요
	local function scheduleTime(): number
		local t = elapsed()
		if state.overtimeAt then
			return math.min(t, state.overtimeAt)
		end
		return t
	end

	-- 물 표면과 따라 움직일 파츠
	local water: BasePart? = nil
	for _, instance in taggedInModel(ctx.model, WATER_TAG) do
		if instance:IsA("BasePart") then
			water = instance
		end
	end
	local followers: { { part: BasePart, rel: CFrame } } = {}
	local followerFolder = ctx.model:FindFirstChild(WATER_FOLLOWERS)
	if water and followerFolder then
		for _, child in followerFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(followers, { part = child, rel = water.CFrame:ToObjectSpace(child.CFrame) })
			end
		end
	end

	-- 집게·불빛
	local clawParts: { { part: BasePart, base: CFrame } } = {}
	local rigFolder = ctx.model:FindFirstChild(CLAW_RIG)
	if rigFolder then
		for _, d in rigFolder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(clawParts, { part = d, base = d.CFrame })
			end
		end
	end
	local slamLights: { BasePart } = {}
	local lightFolder = ctx.model:FindFirstChild(SLAM_LIGHTS)
	if lightFolder then
		for _, d in lightFolder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(slamLights, d)
			end
		end
	end
	local wavesFolder = Instance.new("Folder")
	wavesFolder.Name = WAVES
	wavesFolder.Parent = ctx.model
	ctx.cleanup:add(wavesFolder)

	-- 발밑 데크 확인 (충격파): 이 방 데크 조각만, 가라앉은 조각은 CanQuery = false라 안 맞아요
	local probeTargets: { Instance } = {}
	for _, info in state.decks do
		table.insert(probeTargets, info.model)
	end
	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = probeTargets
	local down = Vector3.new(0, -PROBE_LENGTH, 0)

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	local function knock(player: Player, root: BasePart, humanoid: Humanoid?, rel: Vector3, dist: number, tier: number)
		local k = Logic.waveKnockback(dist, tier)
		local ux, uz = Logic.outward(rel.X - Layout.CENTER_X, rel.Z - Layout.CENTER_Z)
		MoveExempt.mark(player.Character, Logic.KNOCK_MOVE_EXEMPT)
		if humanoid then
			humanoid.PlatformStand = true
			ctx.cleanup:add(task.delay(Logic.KNOCKDOWN_TIME, function()
				-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
				if ctx.isActive() and humanoid.Parent and isRacer(player) then
					humanoid.PlatformStand = false
				end
			end))
		end
		local velocity = origin:VectorToWorldSpace(Vector3.new(ux * k.horizontal, 0, uz * k.horizontal))
			+ Vector3.new(0, k.up, 0)
		launch(ctx, root, velocity, Logic.KNOCK_HOLD)
	end

	-- 그 반지름에서 고리가 보일 높이: 그 자리 단이 아직 있으면 윗면 위, 아니면 물 위
	local function ringHeight(radius: number, waterY: number): number
		local tier = Layout.tierAt(radius)
		if tier and Logic.deckState(tier, scheduleTime()) ~= "Sunk" then
			return Layout.tierTop(tier) + 0.15
		end
		return waterY + 0.15
	end

	local rings: { Ring } = {}
	local nextSlam: Logic.Slam? = nil
	local nextSlamFor: number? = -1 -- nextSlam을 계산할 때의 overtimeAt (바뀌면 다시 계산)
	local lastSlamAt: number? = nil
	local ripple: Model? = nil
	local tierWarned: { [number]: boolean } = {}
	local lastWaterStep = Logic.waterHeight(0)
	local sinceCheck = math.huge
	local sinceVisual = math.huge
	local lastWaterVisual = math.huge

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local t = elapsed()
		local st = scheduleTime()
		sinceVisual += dt
		local visualTick = sinceVisual >= VISUAL_STEP
		if visualTick then
			sinceVisual = 0
		end

		-- 온천수 (보이는 높이)
		local waterVisual = Logic.waterVisual(st)
		if water and math.abs(waterVisual - lastWaterVisual) > 0.002 then
			lastWaterVisual = waterVisual
			local surface = discCFrame(origin, waterVisual, WATER_THICKNESS)
			water.CFrame = surface
			for _, follower in followers do
				follower.part.CFrame = surface * follower.rel
			end
		end
		local waterY = Logic.waterHeight(st)
		if waterY > lastWaterStep then
			lastWaterStep = waterY
			MapSfx.play(water, "OnsenRise")
		end

		-- 단 가라앉기 (연장전 전에만 정상 일정)
		if state.overtimeAt == nil then
			for tier = 1, #Layout.TIERS do
				local at = Logic.sinkAt(tier)
				if at and not tierWarned[tier] and t >= at - Logic.SINK_WARN then
					tierWarned[tier] = true
					local infos: { DeckInfo } = {}
					for _, info in state.decks do
						if info.tier == tier then
							table.insert(infos, info)
						end
					end
					ctx.cleanup:add(task.spawn(warnAndSink, ctx, state, infos, startedAt + at, function(): boolean
						return state.overtimeAt ~= nil
					end))
				end
			end
		end

		-- 다음 "쿵" (연장전이 시작되면 다시 계산)
		if nextSlam == nil or nextSlamFor ~= state.overtimeAt then
			nextSlam = Logic.nextSlam(lastSlamAt, state.overtimeAt)
			nextSlamFor = state.overtimeAt
		end
		local slam = nextSlam :: Logic.Slam
		local warnFrom = slam.at - Logic.SLAM_WARN
		if t >= slam.at then
			for r = 1, slam.rings do
				table.insert(rings, {
					startAt = slam.at + (r - 1) * Logic.RING_GAP,
					prevRadius = Logic.RING_START,
					hit = {},
					visual = nil,
				})
			end
			lastSlamAt = slam.at
			nextSlam = nil
			MapSfx.play(state.body, "ClawSlam")
			if ripple then
				ripple:Destroy()
				ripple = nil
			end
		end

		-- 집게 높이·불빛 (보여주기, 30Hz)
		if visualTick then
			local drop = 0
			if t >= warnFrom and nextSlam then
				drop = math.clamp((t - warnFrom) / Logic.SLAM_WARN, 0, 1)
			elseif lastSlamAt and t - lastSlamAt < 0.8 then
				drop = 1 - (t - lastSlamAt) / 0.8
			end
			for _, claw in clawParts do
				claw.part.CFrame = claw.base - Vector3.new(0, Art.CLAW_DROP * drop * drop, 0)
			end
			local warning = nextSlam ~= nil and t >= warnFrom
			local blinkOn = math.floor(t / BLINK) % 2 == 0
			local lightColor = if warning
				then color3(if blinkOn then Art.COLORS.warn else Art.COLORS.warnWhite)
				else color3(Art.COLORS.slamIdle)
			for _, light in slamLights do
				light.Color = lightColor
			end
			-- 물 위 잔물결 예고 (경고 동안 섬 가장자리에 옅은 고리)
			if warning and ripple == nil then
				ripple = makeRingVisual(ctx, wavesFolder, 0.55)
			end
			if ripple then
				placeRing(ctx, ripple, Logic.RING_START + 1.5 + (if blinkOn then 0.6 else 0), waterVisual + 0.15)
			end
		end

		-- 충격파 고리: 앞면이 지나가는 사람 판정 (매 Heartbeat), 보여주기는 30Hz
		for i = #rings, 1, -1 do
			local ring = rings[i]
			if t < ring.startAt then
				continue
			end
			local radius = Logic.ringRadius(ring.startAt, t)
			for _, player in ctx.getRacers() do
				if ring.hit[player] then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not (root and root:IsA("BasePart")) then
					continue
				end
				local rel = origin:PointToObjectSpace(root.CFrame.Position)
				local dx, dz = rel.X - Layout.CENTER_X, rel.Z - Layout.CENTER_Z
				local dist = math.sqrt(dx * dx + dz * dz)
				if not (dist > ring.prevRadius and dist <= radius) then
					continue
				end
				local hit = workspace:Raycast(root.CFrame.Position, down, probeParams)
				local tier = if hit then hit.Instance:GetAttribute("Tier") else nil
				if type(tier) ~= "number" then
					continue -- 공중이거나 데크 밖
				end
				local footY = rel.Y - Layout.FOOT_OFFSET
				if Logic.waveHit(dist, ring.prevRadius, radius, footY, Layout.tierTop(tier)) then
					ring.hit[player] = true
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					knock(player, root, humanoid, rel, dist, tier)
				end
			end
			ring.prevRadius = radius
			if radius > Logic.RING_END then
				if ring.visual then
					ring.visual:Destroy()
				end
				table.remove(rings, i)
			elseif visualTick then
				if ring.visual == nil then
					ring.visual = makeRingVisual(ctx, wavesFolder, 0.05)
				end
				placeRing(ctx, ring.visual :: Model, radius, ringHeight(radius, waterVisual))
			end
		end

		-- 물·안전망 탈락 (CHECK_INTERVAL마다)
		sinceCheck += dt
		if sinceCheck < Logic.CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local rel = origin:PointToObjectSpace(root.CFrame.Position)
			if rel.Y < Layout.FALL_ELIMINATION_Y or Logic.isSoaked(rel.Y - Layout.FOOT_OFFSET, waterY) then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 결승이 끝났어요
				end
			end
		end
	end))
end

---------------------------------------------------------------- 연장전

-- 결승 연장전 (m5-01): 물·정상 가라앉기 일정이 멈추고(scheduleTime), 충격파는 3초 간격 + 고리 2개로 계속.
-- 남은 데크를 낮은 단부터 하나씩 collapseDuration 안에 가라앉히고, 끝에 인형뽑기 몸체 충돌을 꺼요.
-- 훅은 바로 돌아와요 — 기다리는 건 전부 task.delay(ctx.cleanup).
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	local now = os.clock()
	local state = roundStates[ctx]
	if state == nil then
		-- start가 실패했어도 설 곳은 없애요 (안전 상한까지 기다리지 않게)
		local fallback: RoundState = {
			startedAt = now,
			overtimeAt = 0,
			decks = collectDecks(ctx.model),
			sunk = {},
			body = nil,
		}
		for _, instance in taggedInModel(ctx.model, BODY_TAG) do
			if instance:IsA("BasePart") then
				fallback.body = instance
			end
		end
		state = fallback
	else
		state.overtimeAt = now - state.startedAt
	end
	local s = state :: RoundState

	local remaining: { Logic.DeckRef } = {}
	local byKey: { [string]: DeckInfo } = {}
	for _, deckInfo in s.decks do
		if not s.sunk[deckInfo.model] then
			table.insert(remaining, { tier = deckInfo.tier, index = deckInfo.index })
			byKey[Layout.deckKey(deckInfo.tier, deckInfo.index)] = deckInfo
		end
	end
	for _, step in Logic.overtimeSinkOrder(remaining, info.collapseDuration) do
		local deckInfo = byKey[Layout.deckKey(step.tier, step.index)]
		ctx.cleanup:add(task.delay(step.warnAt, warnAndSink, ctx, s, { deckInfo }, now + step.dropAt, nil))
	end

	-- 김이 짙어져요 (보여주기)
	local decor = ctx.model:FindFirstChild("Decor")
	if decor then
		for _, d in decor:GetDescendants() do
			if d:IsA("ParticleEmitter") and (d.Name == "Steam" or d.Name == "SteamThick") then
				d.Rate *= 1.8
			end
		end
	end

	-- 마지막: 남은 데크 전부(안전) + 인형뽑기 몸체 충돌 끔 → 설 곳 0
	ctx.cleanup:add(task.delay(info.collapseDuration, function()
		if not ctx.isActive() then
			return
		end
		for _, deckInfo in s.decks do
			sinkDeck(ctx, s.sunk, deckInfo)
		end
		local body = s.body
		if body then
			body.CanCollide = false
			body.CanTouch = false
			body.CanQuery = false
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "온천탕 인형뽑기",
	rule = "인형뽑기가 쿵! 퍼지는 충격파는 점프로 넘고, 차오르는 온천물을 피해요!",
	lighting = Art.LIGHTING, -- 해 질 녘 온천 (m5-39)
	build = build,
	start = start,
	overtime = overtime,
}

return map
