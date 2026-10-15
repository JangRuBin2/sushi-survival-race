--!strict
-- Final 맵 "찻잎 정원" (tea-garden, m5-38, GDD §5.3 3차 배치). 해 질 녘 벚꽃 아래 분재 차밭 정원.
-- 가운데 커다란 찻사발을 둘러싼 동심원 계단식 차밭 5단(1단 = 가장 안·높음) 위에서 마지막 1명이 될 때까지 버텨요.
--   - 찻사발에서 작은 찻잔이 굴러 나와 한 단을 따라 돌며 부딪힌 사람을 날려 보내요 (점프로는 못 넘고 단을 옮겨 피함).
--     찻잔은 6초마다 50%로 이웃 단으로 옮겨 가요 (경고: 노랗게 빛남 + 옮겨 갈 단에 점선 호 + TeaCupRoll).
--   - 15·30·45초에 바깥 5·4·3단이 무너져요 (3초 경고: 바깥 가장자리 주황-빨강 깜빡임 + 찻잎 + TeaFieldCrumble).
--   - 연장전(m5-01): 남은 단(보통 2·1단)을 바깥부터 collapseDuration 안에 없애고, 끝에 찻사발 심 충돌도 꺼요.
--
-- 이 맵은 ctx.pass를 부르지 않아요(결승선 없음). 우승 판정은 RoundService, 낙하만 ctx.eliminate.
-- 조각(태그 TeaTerrace, 속성 Ring·Index)은 Slab + 경고 파츠 + 장식 폴더를 묶은 Model이라 장식이 같이 무너져요.
-- 찻잔(태그 TeaRollingCup)은 build에서 3개를 미리 만들어 찻사발 안에 숨겨 두고, 충돌 없이 서버가 CFrame으로 옮겨요.
-- 상태는 roundStates[ctx]에 둬요 (여러 방이 같은 맵을 동시에 돌려도 안 섞여요, 라운드 끝에 ctx.cleanup이 지움).
-- 기다림은 전부 task.delay + Heartbeat 연결이고 ctx.cleanup에 넣어요 (task.wait 없음 — 연장전 훅은 바로 돌아와요).
-- Roblox API는 build/start/overtime 안에서만 써서 Lune에서 require해도 안전해요.
-- 수치는 TeaGardenLayout(지오메트리)·TeaGardenLogic(일정·찻잔·넉백), 장식·색은 TeaGardenArt.

local Art = require(script.Parent.TeaGardenArt)
local Layout = require(script.Parent.TeaGardenLayout)
local Logic = require(script.Parent.TeaGardenLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = Layout.ID

local TAG_TERRACE = "TeaTerrace"
local TAG_CUP = "TeaRollingCup"
local TAG_CORE = "TeaBowlCore"

local WARN_BLINK = 0.2 -- 경고 깜빡임 간격
local WARN_SHAKE = 0.15 -- 경고 파츠 흔들림 (판정 조각은 그대로)
local LEAF_BURST = 5 -- 경고 때 조각마다 찻잎 몇 장
local CUP_HOP = 2.2 -- 단을 옮길 때 튀어 오르는 높이
local DASHES = 6 -- 옮겨 갈 단에 그리는 점선 호 조각 수
local CUP_PARK_Y = 8 -- 숨긴 찻잔을 두는 높이 (찻사발 심 안)

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
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

-- 정원 중심에서 angle 방향 r, 높이 y. 로컬 X = 바깥쪽, 로컬 Z = 각도가 커지는 쪽(접선).
local function radialCFrame(origin: CFrame, angle: number, r: number, y: number): CFrame
	local x, z = Layout.polar(r, angle)
	return origin * CFrame.new(x, y, z) * CFrame.Angles(0, -angle, 0)
end

-- ── build ──────────────────────────────────────────────────────────

local function buildSlice(model: Model, origin: CFrame, slice: Layout.SliceDef)
	local CollectionService = game:GetService("CollectionService")
	local ring = slice.ring
	local def = Layout.RINGS[ring]
	local sliceModel = Instance.new("Model")
	sliceModel.Name = string.format("Terrace_%d_%02d", ring, slice.index)
	local slab = makePart({
		Name = "Slab",
		Size = Vector3.new(slice.depth, slice.height, slice.width),
		CFrame = radialCFrame(origin, slice.angle, slice.distance, slice.centerY),
		Color = rgb(Art.COLORS.ringTop[ring]),
		Material = Enum.Material.Grass,
		-- 재질을 바꿔도 물성(마찰 등)은 Plastic 그대로 (다른 맵과 같은 발 느낌)
		CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic),
		Parent = sliceModel,
	})
	slab.CanCollide = true
	-- 무너짐 경고: 바깥 가장자리 주황-빨강 띠 + 흰 테두리 (평소에는 투명, 충돌 없음)
	local far = def.outer * math.cos(Layout.SLICE_ANGLE / 2)
	local warnDepth = 2
	local warn = makePart({
		Name = "WarnEdge",
		Size = Vector3.new(warnDepth, 0.08, slice.width * 0.92),
		CFrame = radialCFrame(origin, slice.angle, far - warnDepth / 2 - 0.45, def.top + 0.04),
		Color = rgb(Art.COLORS.warn),
		Transparency = 1,
		CastShadow = false,
		Parent = sliceModel,
	})
	noCollide(warn)
	local border = makePart({
		Name = "WarnBorder",
		Size = Vector3.new(0.4, 0.1, slice.width * 0.96),
		CFrame = radialCFrame(origin, slice.angle, far - 0.25, def.top + 0.05),
		Color = rgb(Art.COLORS.warnBorder),
		Transparency = 1,
		CastShadow = false,
		Parent = sliceModel,
	})
	noCollide(border)
	local decor = Art.terraceDecor(ring, slice.index)
	if #decor > 0 then
		MapKit.buildDecor(decor, origin, MapKit.decorFolder(sliceModel))
	end
	sliceModel:SetAttribute("Ring", ring)
	sliceModel:SetAttribute("Index", slice.index)
	CollectionService:AddTag(sliceModel, TAG_TERRACE)
	sliceModel.Parent = model
end

local function buildCup(model: Model, origin: CFrame, index: number)
	local CollectionService = game:GetService("CollectionService")
	local cup = Instance.new("Model")
	cup.Name = string.format("Cup%d", index)
	local at = origin * CFrame.new(0, CUP_PARK_Y, 0)
	-- 옆으로 누운 작은 찻잔: 원기둥 축(로컬 X) = 정원 바깥쪽, 지름 6 · 폭 4
	local body = makePart({
		Name = "CupBody",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Logic.CUP_WIDTH, Logic.CUP_DIAMETER, Logic.CUP_DIAMETER),
		CFrame = at,
		Color = rgb(Art.COLORS.cup),
		Reflectance = 0.08,
		Transparency = 1,
		Parent = cup,
	})
	noCollide(body)
	local glow = makePart({
		Name = "CupGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Logic.CUP_WIDTH + 0.5, Logic.CUP_DIAMETER + 0.6, Logic.CUP_DIAMETER + 0.6),
		CFrame = at,
		Color = rgb(Art.COLORS.cupGlow),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CastShadow = false,
		Parent = cup,
	})
	noCollide(glow)
	for _, part in MapKit.buildDecor(Art.cupDecor(), at, cup) do
		part:SetAttribute("ShownTransparency", part.Transparency)
		part.Transparency = 1
	end
	cup.PrimaryPart = body
	cup:SetAttribute("CupIndex", index)
	CollectionService:AddTag(cup, TAG_CUP)
	cup.Parent = model
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local model = Instance.new("Model")
	model.Name = ID

	for ring = 1, Layout.RING_COUNT do
		for _, slice in Layout.slices(ring) do
			buildSlice(model, origin, slice)
		end
	end

	-- 가운데 찻사발 충돌 심: 보이지 않는 원기둥, 윗면 20 (올라설 수 없음). 겉모습은 Art 장식(찻사발).
	local coreHeight = Layout.CORE_TOP - Layout.CORE_BOTTOM
	local core = makePart({
		Name = "BowlCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(coreHeight, Layout.CORE_RADIUS * 2, Layout.CORE_RADIUS * 2),
		CFrame = origin * CFrame.new(0, Layout.CORE_BOTTOM + coreHeight / 2, 0) * upright(),
		Transparency = 1,
		CastShadow = false,
		Parent = model,
	})
	core.CanCollide = true
	core.CanTouch = false
	CollectionService:AddTag(core, TAG_CORE)

	-- 런타임 표시물 폴더 (찻사발 아래 빛, 점선 호, 찻잎 터짐) — 전부 충돌 없음
	local fx = Instance.new("Folder")
	fx.Name = "CupFx"
	local bowlGlow = makePart({
		Name = "BowlGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, Layout.CORE_RADIUS * 2 + 1.6, Layout.CORE_RADIUS * 2 + 1.6),
		CFrame = origin * CFrame.new(0, Layout.RINGS[1].top + 0.06, 0) * upright(),
		Color = rgb(Art.COLORS.bowlGlow),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CastShadow = false,
		Parent = fx,
	})
	noCollide(bowlGlow)
	fx.Parent = model

	for index = 1, Logic.MAX_CUPS do
		buildCup(model, origin, index)
	end
	-- 소개 카메라용: 첫 찻잔을 1단 위에 보이게 세워 둬요 (start가 숨기고 3초에 찻사발에서 다시 굴러 나와요)
	local preview = model:FindFirstChild("Cup1")
	if preview and preview:IsA("Model") then
		local x, z = Layout.polar(Layout.ringMid(1), Art.PREVIEW_CUP_ANGLE)
		preview:PivotTo(
			origin
				* CFrame.new(x, Layout.RINGS[1].top + Logic.CUP_DIAMETER / 2, z)
				* CFrame.Angles(0, -Art.PREVIEW_CUP_ANGLE, 0)
		)
		for _, part in preview:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "CupGlow" then
				local shown = part:GetAttribute("ShownTransparency")
				part.Transparency = if type(shown) == "number" then shown else 0
			end
		end
	end

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, spawn in Layout.spawns() do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(spawn.x, spawn.y, spawn.z) * CFrame.Angles(0, spawn.yaw, 0),
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

-- ── 라운드 상태 ─────────────────────────────────────────────────────

type SlicePart = { part: BasePart, home: CFrame, transparency: number }
type Slice = { model: Model, parts: { SlicePart }, warnParts: { BasePart } }
type RingState = {
	phase: Logic.Phase,
	dropAt: number?, -- 출발 기준 초 (알면)
	owner: "main" | "overtime",
	slices: { Slice },
	blink: RBXScriptConnection?,
}
type Move = { to: number, moveAt: number, endAt: number, fromR: number, fromTop: number, dashes: { BasePart } }
type CupState = {
	model: Model,
	parts: { BasePart },
	shown: { [BasePart]: number },
	glow: BasePart?,
	status: "Hidden" | "Emerging" | "Rolling",
	motion: Logic.Cup,
	emergeAt: number, -- 굴러 나오기 시작 (출발 기준 초)
	nextDecision: number,
	move: Move?,
	roll: number,
	lastT: number,
	visible: boolean,
}
type RoundState = {
	startedAt: number,
	overtimeAt: number?,
	rings: { [number]: RingState },
	cups: { CupState },
	stopped: boolean, -- 연장전 끝: 찻잔 멈춤·사라짐
	lastHit: { [Player]: number },
	core: BasePart?,
	fx: Instance?,
	bowlGlow: BasePart?,
	leaves: ParticleEmitter?,
}
local roundStates: { [MapTypes.RoundContext]: RoundState } = {}

-- 이 라운드 맵(ctx.model) 하위에서 태그가 붙은 것만 (B10 A)
local function taggedInModel(model: Model, tag: string): { Instance }
	local CollectionService = game:GetService("CollectionService")
	local found = {}
	for _, instance in model:GetDescendants() do
		if CollectionService:HasTag(instance, tag) then
			table.insert(found, instance)
		end
	end
	return found
end

local function collectSlice(sliceModel: Model): Slice
	local slice: Slice = { model = sliceModel, parts = {}, warnParts = {} }
	for _, d in sliceModel:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(slice.parts, { part = d, home = d.CFrame, transparency = d.Transparency })
			if d.Name == "WarnEdge" or d.Name == "WarnBorder" then
				table.insert(slice.warnParts, d)
			end
		end
	end
	return slice
end

local function newState(ctx: MapTypes.RoundContext): RoundState
	local state: RoundState = {
		startedAt = os.clock(),
		overtimeAt = nil,
		rings = {},
		cups = {},
		stopped = false,
		lastHit = {},
		core = nil,
		fx = ctx.model:FindFirstChild("CupFx"),
		bowlGlow = nil,
		leaves = nil,
	}
	for ring = 1, Layout.RING_COUNT do
		state.rings[ring] = {
			phase = "Solid",
			dropAt = Logic.collapseAt(ring),
			owner = "main",
			slices = {},
			blink = nil,
		}
	end
	for _, instance in taggedInModel(ctx.model, TAG_TERRACE) do
		local ring = instance:GetAttribute("Ring")
		if instance:IsA("Model") and type(ring) == "number" and state.rings[ring] then
			table.insert(state.rings[ring].slices, collectSlice(instance))
		end
	end
	for _, instance in taggedInModel(ctx.model, TAG_CORE) do
		if instance:IsA("BasePart") then
			state.core = instance
		end
	end
	local fx = state.fx
	if fx then
		local glow = fx:FindFirstChild("BowlGlow")
		if glow and glow:IsA("BasePart") then
			state.bowlGlow = glow
		end
	end
	local cupModels: { Model } = {}
	for _, instance in taggedInModel(ctx.model, TAG_CUP) do
		if instance:IsA("Model") then
			table.insert(cupModels, instance)
		end
	end
	table.sort(cupModels, function(a, b)
		return (a:GetAttribute("CupIndex") :: number? or 0) < (b:GetAttribute("CupIndex") :: number? or 0)
	end)
	for _, cupModel in cupModels do
		local parts: { BasePart } = {}
		local shown: { [BasePart]: number } = {}
		local glow: BasePart? = nil
		for _, d in cupModel:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				if d.Name == "CupGlow" then
					glow = d
				else
					local value = d:GetAttribute("ShownTransparency")
					shown[d] = if type(value) == "number" then value else 0
				end
			end
		end
		local cup: CupState = {
			model = cupModel,
			parts = parts,
			shown = shown,
			glow = glow,
			status = "Hidden",
			motion = { ring = 1, angle0 = 0, t0 = 0, dir = 1, speed = 0 },
			emergeAt = math.huge,
			nextDecision = math.huge,
			move = nil,
			roll = 0,
			lastT = 0,
			visible = false,
		}
		table.insert(state.cups, cup)
	end
	roundStates[ctx] = state
	ctx.cleanup:add(function()
		roundStates[ctx] = nil
	end)
	return state
end

local function elapsedOf(state: RoundState): number
	return os.clock() - state.startedAt
end

-- 아직 남은 단 (찻잔 단 고르기용)
local function ringInfos(state: RoundState): { Logic.RingInfo }
	local list: { Logic.RingInfo } = {}
	for ring = 1, Layout.RING_COUNT do
		local rs = state.rings[ring]
		if rs.phase ~= "Gone" then
			table.insert(list, { ring = ring, collapseAt = rs.dropAt })
		end
	end
	return list
end

-- ── 차밭 경고·무너짐 ────────────────────────────────────────────────

local function stopBlink(rs: RingState)
	local blink = rs.blink
	if blink then
		blink:Disconnect()
		rs.blink = nil
	end
end

local function warnRing(ctx: MapTypes.RoundContext, state: RoundState, ring: number)
	local RunService = game:GetService("RunService")
	local rs = state.rings[ring]
	if not ctx.isActive() or rs.phase ~= "Solid" then
		return
	end
	rs.phase = "Warn"
	-- 찻잎 바스락 (조각마다 한 번)
	local leaves = state.leaves
	local holder = leaves and leaves.Parent
	for _, slice in rs.slices do
		local slab = slice.model:FindFirstChild("Slab")
		if leaves and holder and holder:IsA("BasePart") and slab and slab:IsA("BasePart") then
			holder.CFrame = slab.CFrame * CFrame.new(0, slab.Size.Y / 2 + 0.5, 0)
			leaves:Emit(LEAF_BURST)
		end
	end
	local warnColor = rgb(Art.COLORS.warn)
	local blinkColor = rgb(Art.COLORS.warnBlink)
	local startedAt = os.clock()
	local lastStep = -1
	stopBlink(rs)
	local connection = RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			stopBlink(rs)
			return
		end
		local step = math.floor((os.clock() - startedAt) / WARN_BLINK)
		if step == lastStep then
			return
		end
		lastStep = step
		local on = step % 2 == 0
		for _, slice in rs.slices do
			for _, entry in slice.parts do
				local part = entry.part
				if part.Name == "WarnEdge" then
					part.Transparency = 0
					part.Color = if on then warnColor else blinkColor
					part.CFrame = entry.home
						* CFrame.new((math.random() - 0.5) * WARN_SHAKE * 2, 0, (math.random() - 0.5) * WARN_SHAKE * 2)
				elseif part.Name == "WarnBorder" then
					part.Transparency = if on then 0 else 0.4
				end
			end
		end
	end)
	rs.blink = connection
	ctx.cleanup:add(connection)
end

-- 무너짐: 충돌을 바로 끄고 0.6초 동안 3 내려가며 투명해져요. 다시 돌아오지 않아요.
local function dropRing(ctx: MapTypes.RoundContext, state: RoundState, ring: number)
	local RunService = game:GetService("RunService")
	local rs = state.rings[ring]
	if not ctx.isActive() or rs.phase == "Gone" then
		return
	end
	rs.phase = "Gone"
	stopBlink(rs)
	local first: BasePart? = nil
	local moving: { SlicePart } = {}
	for _, slice in rs.slices do
		for _, entry in slice.parts do
			noCollide(entry.part)
			first = first or entry.part
			table.insert(moving, entry)
		end
		slice.model:SetAttribute("Dropped", true)
	end
	MapSfx.play(first, "TeaFieldCrumble")
	local startedAt = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - startedAt) / Logic.DROP_TIME, 0, 1)
		local eased = alpha * alpha
		for _, entry in moving do
			entry.part.CFrame = entry.home - Vector3.new(0, Logic.DROP_DISTANCE * eased, 0)
			entry.part.Transparency = entry.transparency + (1 - entry.transparency) * alpha
		end
		if alpha >= 1 and connection then
			connection:Disconnect()
		end
	end)
	ctx.cleanup:add(connection)
	-- 시간이 지나면 다 보이지 않게 (Heartbeat가 멈춰 있어도)
	ctx.cleanup:add(task.delay(Logic.DROP_TIME + 0.1, function()
		for _, entry in moving do
			entry.part.Transparency = 1
		end
	end))
end

-- ── 찻잔 ────────────────────────────────────────────────────────────

local function setCupVisible(cup: CupState, visible: boolean)
	cup.visible = visible
	for part, value in cup.shown do
		part.Transparency = if visible then value else 1
	end
	local glow = cup.glow
	if glow then
		glow.Transparency = 1
	end
end

local function clearDashes(cup: CupState)
	local move = cup.move
	if move then
		for _, dash in move.dashes do
			dash:Destroy()
		end
		move.dashes = {}
	end
end

-- 찻잔 중심 (로컬 x, z), 바닥 높이, 각도
local function cupPlacement(cup: CupState, t: number): (number, number, number, number)
	local _, angle = Logic.cupPosition(cup.motion, t)
	local ring = cup.motion.ring
	local r = Layout.ringMid(ring)
	local base = Layout.RINGS[ring].top
	if cup.status == "Emerging" then
		local alpha = math.clamp((t - cup.emergeAt) / Logic.CUP_EMERGE_TIME, 0, 1)
		r = 3 + (r - 3) * alpha
	end
	local move = cup.move
	if move and t >= move.moveAt then
		local alpha = math.clamp((t - move.moveAt) / Logic.MOVE_TIME, 0, 1)
		local toR = Layout.ringMid(move.to)
		local toTop = Layout.RINGS[move.to].top
		r = move.fromR + (toR - move.fromR) * alpha
		base = move.fromTop + (toTop - move.fromTop) * alpha + math.sin(math.pi * alpha) * CUP_HOP
	end
	local x, z = Layout.polar(r, angle)
	return x, z, base, angle
end

local function placeCup(ctx: MapTypes.RoundContext, cup: CupState, t: number)
	local x, z, base, angle = cupPlacement(cup, t)
	local cf = ctx.origin
		* CFrame.new(x, base + Logic.CUP_DIAMETER / 2, z)
		* CFrame.Angles(0, -angle, 0)
		* CFrame.Angles(cup.roll, 0, 0)
	cup.model:PivotTo(cf)
end

local function startMove(ctx: MapTypes.RoundContext, state: RoundState, cup: CupState, to: number, t: number)
	local from = cup.motion.ring
	local move: Move = {
		to = to,
		moveAt = t + Logic.MOVE_WARN,
		endAt = t + Logic.MOVE_WARN + Logic.MOVE_TIME,
		fromR = Layout.ringMid(from),
		fromTop = Layout.RINGS[from].top,
		dashes = {},
	}
	cup.move = move
	local glow = cup.glow
	if glow then
		glow.Transparency = 0.45
	end
	-- 옮겨 갈 단에 점선 호 (찻잔 앞쪽으로)
	local fx = state.fx
	if fx then
		local _, angle = Logic.cupPosition(cup.motion, t)
		local r = Layout.ringMid(to)
		local top = Layout.RINGS[to].top
		for k = 1, DASHES do
			local a = angle + cup.motion.dir * (k * 1.6) / r
			local dash = makePart({
				Name = "MoveDash",
				Size = Vector3.new(0.5, 0.08, 1.2),
				CFrame = radialCFrame(ctx.origin, a, r, top + 0.05),
				Color = rgb(Art.COLORS.cupGlow),
				Material = Enum.Material.Neon,
				CastShadow = false,
				Parent = fx,
			})
			noCollide(dash)
			table.insert(move.dashes, dash)
		end
	end
	MapSfx.play(cup.model.PrimaryPart, "TeaCupRoll")
end

local function finishMove(cup: CupState, t: number)
	local move = cup.move
	if move == nil then
		return
	end
	clearDashes(cup)
	cup.motion = Logic.rebase(cup.motion, t, move.to)
	cup.move = nil
	local glow = cup.glow
	if glow then
		glow.Transparency = 1
	end
end

local function cupRings(state: RoundState): { number }
	local list: { number } = {}
	for _, cup in state.cups do
		if cup.status ~= "Hidden" then
			table.insert(list, if cup.move then cup.move.to else cup.motion.ring)
		end
	end
	return list
end

local function decide(ctx: MapTypes.RoundContext, state: RoundState, cup: CupState, t: number, forced: boolean)
	local active: { CupState } = {}
	for _, c in state.cups do
		if c.status ~= "Hidden" then
			table.insert(active, c)
		end
	end
	local index = table.find(active, cup) or 1
	local rings = cupRings(state)
	local infos = ringInfos(state)
	if forced or Logic.shouldMoveCup(ctx.rng, rings, infos, t, index) then
		local to = Logic.pickCupRing(ctx.rng, rings, infos, t, index)
		if to then
			startMove(ctx, state, cup, to, t)
		end
	end
end

local function emergeCup(ctx: MapTypes.RoundContext, state: RoundState, cup: CupState, t: number)
	cup.status = "Emerging"
	cup.emergeAt = t + Logic.CUP_EMERGE_WARN
	local _, speed = Logic.cupWave(cup.emergeAt, state.overtimeAt)
	cup.motion = {
		ring = 1,
		angle0 = ctx.rng:NextNumber(0, 2 * math.pi),
		t0 = cup.emergeAt,
		dir = if ctx.rng:NextInteger(0, 1) == 0 then -1 else 1,
		speed = speed,
	}
	cup.nextDecision = cup.emergeAt + Logic.CUP_EMERGE_TIME + Logic.MOVE_INTERVAL
	cup.roll = 0
	cup.lastT = t
	MapSfx.play(state.bowlGlow, "TeaCupRoll")
end

local function stopCups(state: RoundState)
	state.stopped = true
	for _, cup in state.cups do
		clearDashes(cup)
		cup.move = nil
		cup.status = "Hidden"
		setCupVisible(cup, false)
	end
	local glow = state.bowlGlow
	if glow then
		glow.Transparency = 1
	end
end

-- 캐릭터는 클라이언트가 물리를 맡아서 서버가 속도만 바꾸면 덮어써질 수 있어요 → LinearVelocity를 잠깐 붙여요
-- (IkuraBombs·SoySwampHazards와 같은 방식).
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "TeaCupAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "TeaCupLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(Logic.LAUNCH_HOLD, function()
		push:Destroy()
	end))
end

local function knock(
	ctx: MapTypes.RoundContext,
	player: Player,
	root: BasePart,
	humanoid: Humanoid,
	angle: number,
	dir: number
)
	local push = Logic.cupKnockback(angle, dir)
	humanoid.PlatformStand = true -- 넘어짐 (잡기도 풀려요)
	MoveExempt.mark(player.Character, Logic.EXEMPT_TIME) -- 서버가 튕긴 속도라 이동 감시(m4-10)에서 빼요
	launch(ctx, root, ctx.origin:VectorToWorldSpace(Vector3.new(push.x, push.y, push.z)))
	ctx.cleanup:add(task.delay(Logic.KNOCKDOWN_TIME, function()
		-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
		if ctx.isActive() and humanoid.Parent and table.find(ctx.getRacers(), player) then
			humanoid.PlatformStand = false
		end
	end))
end

local function updateCups(ctx: MapTypes.RoundContext, state: RoundState, t: number)
	if state.stopped then
		return
	end
	-- 새 찻잔: 나올 시각보다 경고(1.5초)만큼 먼저 찻사발 아래가 빛나요. 한 번에 하나씩.
	local wanted = Logic.cupWave(t + Logic.CUP_EMERGE_WARN, state.overtimeAt)
	local started, emerging = 0, false
	for _, cup in state.cups do
		if cup.status ~= "Hidden" then
			started += 1
		end
		if cup.status == "Emerging" then
			emerging = true
		end
	end
	if started < wanted and not emerging then
		for _, cup in state.cups do
			if cup.status == "Hidden" then
				emergeCup(ctx, state, cup, t)
				emerging = true
				break
			end
		end
	end
	local bowlGlow = state.bowlGlow
	if bowlGlow then
		local glowing = false
		for _, cup in state.cups do
			if cup.status == "Emerging" and t < cup.emergeAt then
				glowing = true
			end
		end
		bowlGlow.Transparency = if glowing then (if math.floor(t / WARN_BLINK) % 2 == 0 then 0.2 else 0.6) else 1
	end

	local _, speed = Logic.cupWave(t, state.overtimeAt)
	for _, cup in state.cups do
		if cup.status == "Hidden" then
			continue
		end
		if cup.status == "Emerging" then
			if t < cup.emergeAt then
				cup.lastT = t
				continue -- 아직 찻사발 안
			end
			if not cup.visible then
				setCupVisible(cup, true)
			end
			if t >= cup.emergeAt + Logic.CUP_EMERGE_TIME then
				cup.status = "Rolling"
			end
		end
		-- 속도가 바뀌면 지금 자리에서 다시 잡아요
		if speed > 0 and cup.motion.speed ~= speed then
			cup.motion = Logic.rebase(cup.motion, t, nil, speed)
		end
		cup.roll += cup.motion.dir * cup.motion.speed * math.max(t - cup.lastT, 0) / (Logic.CUP_DIAMETER / 2)
		cup.lastT = t
		local move = cup.move
		if move and t >= move.endAt then
			finishMove(cup, t)
		end
		if cup.status == "Rolling" and cup.move == nil then
			local infos = ringInfos(state)
			local unsafe = table.find(Logic.safeRings(infos, t), cup.motion.ring) == nil
			if unsafe then
				decide(ctx, state, cup, t, true)
			elseif t >= cup.nextDecision then
				cup.nextDecision += Logic.MOVE_INTERVAL
				decide(ctx, state, cup, t, false)
			end
		end
		placeCup(ctx, cup, t)
	end
end

local function hitCheck(ctx: MapTypes.RoundContext, state: RoundState, t: number)
	if state.stopped then
		return
	end
	local origin = ctx.origin
	local now = os.clock()
	local cupsNow: { { x: number, z: number, base: number, angle: number, dir: number } } = {}
	for _, cup in state.cups do
		if cup.status ~= "Hidden" and t >= cup.emergeAt then
			local x, z, base, angle = cupPlacement(cup, t)
			table.insert(cupsNow, { x = x, z = z, base = base, angle = angle, dir = cup.motion.dir })
		end
	end
	if #cupsNow == 0 then
		return
	end
	for _, player in ctx.getRacers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid) then
			continue
		end
		local last = state.lastHit[player]
		if last and now - last < Logic.HIT_COOLDOWN then
			continue
		end
		local rel = origin:PointToObjectSpace(root.Position)
		local foot = rel.Y - (humanoid.HipHeight + root.Size.Y / 2)
		for _, c in cupsNow do
			if Logic.cupHit(rel.X - c.x, rel.Z - c.z, foot, c.base) then
				state.lastHit[player] = now
				knock(ctx, player, root, humanoid, c.angle, c.dir)
				break
			end
		end
	end
end

-- ── start ───────────────────────────────────────────────────────────

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local state = roundStates[ctx] or newState(ctx)
	state.startedAt = os.clock()
	-- 소개용으로 세워 둔 찻잔도 숨기고 찻사발 안으로 (3초에 굴러 나와요)
	for _, cup in state.cups do
		setCupVisible(cup, false)
		cup.model:PivotTo(origin * CFrame.new(0, CUP_PARK_Y, 0))
	end

	-- 찻잎 터짐: 투명 파츠 하나에 ParticleEmitter 하나, 경고 때마다 옮겨서 Emit
	local fx = state.fx
	if fx then
		local holder = makePart({
			Name = "LeafHolder",
			Size = Vector3.one,
			CFrame = origin,
			Transparency = 1,
			CastShadow = false,
			Parent = fx,
		})
		noCollide(holder)
		ctx.cleanup:add(holder)
		local leaves = MapKit.makeEmitter("TeaLeaves", 0)
		leaves.Enabled = false
		leaves.Parent = holder
		state.leaves = leaves
	end

	-- 본 경기 붕괴 일정: 5·4·3단 (경고 3초)
	for ring, at in Logic.COLLAPSE_AT do
		ctx.cleanup:add(task.delay(math.max(at - Logic.WARN_TIME, 0), function()
			if state.rings[ring].owner == "main" then
				warnRing(ctx, state, ring)
			end
		end))
		ctx.cleanup:add(task.delay(at, function()
			if state.rings[ring].owner == "main" then
				dropRing(ctx, state, ring)
			end
		end))
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		-- 낙하
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and origin:PointToObjectSpace(root.Position).Y < -Layout.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 결승이 끝났어요
				end
			end
		end
		local t = elapsedOf(state)
		updateCups(ctx, state, t)
		hitCheck(ctx, state, t)
	end))
end

-- ── 연장전 (m5-01) ──────────────────────────────────────────────────
-- 남은 단(경고 전인 단)을 바깥 → 안 순서로 collapseDuration 안에 없애요 (보통 2단 +10초, 1단 +20초).
-- 끝(+collapseDuration)에 찻사발 심 충돌을 끄고 찻잔을 멈춰 숨겨요 → 설 곳 0.
-- 정원 밖 장식은 처음부터 충돌이 없고, 심은 처음부터 올라설 수 없어서 매달려 버틸 곳이 없어요 (m5-18 B1 교훈).
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	local state = roundStates[ctx] or newState(ctx) -- start가 실패했어도 바닥은 없애요
	local overtimeAt = elapsedOf(state)
	state.overtimeAt = overtimeAt
	local remaining: { number } = {}
	for ring = 1, Layout.RING_COUNT do
		if state.rings[ring].phase == "Solid" then
			table.insert(remaining, ring)
		end
	end
	for _, step in Logic.overtimeCollapse(info.collapseDuration, remaining) do
		local rs = state.rings[step.ring]
		rs.owner = "overtime"
		rs.dropAt = overtimeAt + step.dropAt
		ctx.cleanup:add(task.delay(step.warnAt, warnRing, ctx, state, step.ring))
		ctx.cleanup:add(task.delay(step.dropAt, dropRing, ctx, state, step.ring))
	end
	ctx.cleanup:add(task.delay(info.collapseDuration, function()
		if not ctx.isActive() then
			return
		end
		-- 혹시 남은 단이 있으면(경고 중이던 단 포함) 지금 없애요
		for ring = 1, Layout.RING_COUNT do
			dropRing(ctx, state, ring)
		end
		local core = state.core
		if core then
			core.CanCollide = false
			core.CanQuery = false
		end
		stopCups(state)
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "찻잎 정원",
	rule = "굴러오는 찻잔을 피해 단을 옮기고, 무너지는 차밭에서 끝까지 버텨요!",
	build = build,
	start = start,
	overtime = overtime,
	lighting = Art.LIGHTING, -- 해 질 녘 벚꽃 정원
}

return map
