--!strict
-- Race 맵 "디저트 냉장고" (m5-06, GDD 5.3). 거대한 냉장고 안 디저트 칸을 달려 냉장고 문까지 탈출해요.
--   B 얼음 쟁반·D 찬바람 선반 바닥은 Ice 태그 — 미끄러짐은 클라이언트 IceController(+ 순수 IceLogic)가 해요.
--   C 젤리 발판(Jelly 태그)은 서버가 위·앞으로 튕겨요 (와사비와 같은 방식, LinearVelocity 잠깐 + MoveExempt).
--   D 송풍구(ColdFan 태그)는 4초 주기(0.5 경고 → 2 불기 → 1.5 쉼)로 구역 안 레이서를 옆으로 밀어요.
--   송풍구 밀기는 연속 밀기라 MoveExempt를 달지 않아요 (CLAUDE.md 규칙, 스펙 결정 Q2 — 밀기 14는 상한 80보다 한참 낮음).
--   m5-40: F 냉동실 칸(얼음 + 구멍 3 + 냉동 송풍구 FreezerFan 1)과 G 스쿱 계단(스쿱 기둥 4 + 지름길 젤리 ScoopJelly 1)을
--   D와 E 사이에 끼웠어요. 새 송풍구·젤리는 D·C와 같은 수치·같은 처리(젤리만 MoveExempt)이고 태그만 따로예요.
-- 치수는 DessertFridgeLayout, 계산은 DessertFridgeLogic, 장식은 DessertFridgeArt.
-- 태그 파츠는 ctx.model 하위의 것만 쓰고, 상태는 전부 start 안 지역 변수에 둬요(여러 방 동시 진행).
-- id·kind·displayName·rule은 m5-03에서 확정이에요 (바꾸지 않아요).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.DessertFridgeArt)
local Config = require(script.Parent.Parent.Config)
local IceLogic = require(script.Parent.Parent.IceLogic)
local Layout = require(script.Parent.DessertFridgeLayout)
local Logic = require(script.Parent.DessertFridgeLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "dessert-fridge"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
local TAG_ICE = IceLogic.TAG
local TAG_JELLY = "Jelly"
local TAG_FAN = "ColdFan"
local TAG_FREEZER_FAN = "FreezerFan" -- m5-40 F
local TAG_SCOOP_JELLY = "ScoopJelly" -- m5-40 G

-- 판정 지오메트리 기본 색 (아트 단계에서 MapKit 장식으로 꾸며요). Color3는 build 안에서만 만들어요(Lune require 안전).
local function palette()
	return {
		floor = Color3.fromRGB(236, 240, 246), -- 냉장고 안 흰 바닥
		ice = Color3.fromRGB(184, 230, 255), -- 밝은 하늘색 얼음 (코스에서 가장 밝고 깨끗하게)
		cube = Color3.fromRGB(206, 236, 252),
		jellies = {
			Color3.fromRGB(230, 60, 72), -- 딸기 젤리
			Color3.fromRGB(110, 210, 90), -- 메론 젤리
			Color3.fromRGB(230, 60, 72),
		},
		cookie = Color3.fromRGB(196, 140, 84),
		landing = Color3.fromRGB(250, 236, 214), -- 커스터드 크림 단
		fan = Color3.fromRGB(150, 160, 172),
		scoopFloor = Color3.fromRGB(246, 236, 222), -- m5-40 아이스크림 통 바닥 (바닐라)
		scoopLanding = Color3.fromRGB(252, 222, 228), -- m5-40 딸기 아이스크림 케이크 단
		scoops = { -- m5-40 스쿱 4개 (밝은 파스텔)
			Color3.fromRGB(255, 196, 206),
			Color3.fromRGB(196, 238, 214),
			Color3.fromRGB(255, 236, 170),
			Color3.fromRGB(214, 200, 246),
		},
		spawn = Color3.fromRGB(246, 196, 70),
		finishLine = Color3.fromRGB(255, 196, 40),
	}
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
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

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local COLORS = palette()
	local model = Instance.new("Model")
	model.Name = ID
	local thickness = Layout.FLOOR_THICKNESS

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 윗면 높이 top, z front ~ back, x minX ~ maxX 인 바닥판
	local function slab(
		name: string,
		minX: number,
		maxX: number,
		front: number,
		back: number,
		top: number,
		depthY: number
	): BasePart
		local width, length = maxX - minX, front - back
		return makePart({
			Name = name,
			Size = Vector3.new(width, depthY, length),
			CFrame = at((minX + maxX) / 2, top - depthY / 2, (front + back) / 2),
			Color = COLORS.floor,
			Parent = model,
		})
	end

	local function makeIce(part: BasePart)
		part.Material = Enum.Material.Ice
		part.Color = COLORS.ice
		-- 미끄러짐은 IceController가 해요. 물성은 SmoothPlastic 그대로(재질 기본 마찰이 다른 물리에 섞이지 않게).
		part.Reflectance = 0.12 -- 얼음 광택 (아트, 판정 무관)
		part.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic)
		CollectionService:AddTag(part, TAG_ICE)
	end

	-- A 출발
	local startHalf = Layout.START_WIDTH / 2
	slab("StartFloor", -startHalf, startHalf, Layout.START.front, Layout.START.back, Layout.LOW_Y, thickness)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == MAX_PLAYERS, "spawn count must cover the largest room size")
	for i, pos in positions do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, Layout.LOW_Y + 0.1, pos.z),
			Color = COLORS.spawn,
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end

	-- B 얼음 쟁반 (구멍 2개를 뺀 조각들) + 얼음 큐브 8개
	for i, rect in Layout.iceTrayRects() do
		local piece =
			slab(string.format("IceTray%02d", i), rect.minX, rect.maxX, rect.maxZ, rect.minZ, Layout.LOW_Y, thickness)
		makeIce(piece)
	end
	local cubeSize = Layout.CUBE_SIZE
	for i, cube in Layout.CUBES do
		makePart({
			Name = string.format("IceCube%d", i),
			Size = Vector3.new(cubeSize, cubeSize, cubeSize),
			CFrame = at(cube.x, Layout.LOW_Y + cubeSize / 2, cube.z),
			Color = COLORS.cube,
			Material = Enum.Material.Ice,
			Transparency = 0.15,
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
	end

	-- C 젤리 계단: 앞쪽 바닥(y 0) + 착지대(y 0 ~ 12 통짜) + 젤리 발판 3개 + 쿠키 계단
	local jellyHalf = Layout.JELLY_ZONE_WIDTH / 2
	slab("JellyFloor", -jellyHalf, jellyHalf, Layout.JELLY_ZONE.front, Layout.LANDING.front, Layout.LOW_Y, thickness)
	local landing = slab(
		"Landing",
		-jellyHalf,
		jellyHalf,
		Layout.LANDING.front,
		Layout.LANDING.back,
		Layout.HIGH_Y,
		Layout.HIGH_Y - Layout.LOW_Y + thickness
	)
	landing.Color = COLORS.landing
	for i, jelly in Layout.JELLIES do
		local pad = makePart({
			Name = string.format("Jelly%d", i),
			Size = Vector3.new(Layout.JELLY_SIZE, Layout.JELLY_TOP - Layout.LOW_Y, Layout.JELLY_SIZE),
			CFrame = at(jelly.x, (Layout.LOW_Y + Layout.JELLY_TOP) / 2, jelly.z),
			Color = COLORS.jellies[i] or COLORS.jellies[1],
			Material = Enum.Material.Glass,
			Transparency = 0.1, -- 휴대폰에서도 빨강·초록이 읽히게
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
		CollectionService:AddTag(pad, TAG_JELLY)
	end
	for _, step in Layout.COOKIE_STEPS do
		local cookie = slab(
			string.format("CookieStep%d", step.index),
			Layout.COOKIE_MIN_X,
			Layout.COOKIE_MAX_X,
			step.front,
			step.back,
			step.top,
			step.top - Layout.LOW_Y
		)
		cookie.Color = COLORS.cookie
		cookie.Material = Enum.Material.Sand
		cookie.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic)
	end

	-- D 찬바람 선반 (얼음) + 송풍구 2개 (미는 쪽의 반대편 바깥에 붙은 환풍구, 충돌 없음)
	local shelfHalf = Layout.FAN_SHELF_WIDTH / 2
	local shelf =
		slab("FanShelf", -shelfHalf, shelfHalf, Layout.FAN_SHELF.front, Layout.FAN_SHELF.back, Layout.HIGH_Y, thickness)
	makeIce(shelf)
	-- 송풍구 하나 (미는 쪽의 반대편 바깥에 붙은 환풍구, 충돌 없음) + 서리 입자. D·F(m5-40) 공통
	local function vent(fan: Layout.Fan, name: string, tag: string, halfWidth: number)
		local length = fan.front - fan.back
		local part = makePart({
			Name = name,
			Size = Vector3.new(1, 6, length),
			CFrame = at(-fan.dirX * (halfWidth + 0.5), Layout.HIGH_Y + 3, (fan.front + fan.back) / 2),
			Color = COLORS.fan,
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
		part:SetAttribute("FanIndex", fan.index)
		CollectionService:AddTag(part, tag)
		-- 서리 입자 (경고·불기 동안 켜요). 바람 방향(+X면 오른쪽)으로 뿜어요.
		local frost = Instance.new("ParticleEmitter")
		frost.Name = "Frost"
		frost.Enabled = false
		frost.Color = ColorSequence.new(Color3.fromRGB(230, 246, 255))
		frost.LightEmission = 0.4
		frost.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
		frost.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		frost.Lifetime = NumberRange.new(0.8, 1.2)
		frost.Rate = 40
		frost.Speed = NumberRange.new(14, 18)
		frost.SpreadAngle = Vector2.new(10, 10)
		frost.EmissionDirection = if fan.dirX > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		frost.Parent = part
	end
	for _, fan in Layout.FANS do
		vent(fan, string.format("ColdFan%d", fan.index), TAG_FAN, shelfHalf)
	end

	-- F 냉동실 칸 (m5-40): 얼음 바닥 조각(구멍 3개를 뺀) + 냉동 송풍구
	for i, rect in Layout.freezerRects() do
		local piece = slab(
			string.format("FreezerFloor%02d", i),
			rect.minX,
			rect.maxX,
			rect.maxZ,
			rect.minZ,
			Layout.HIGH_Y,
			thickness
		)
		makeIce(piece)
	end
	for _, fan in Layout.FREEZER_FANS do
		vent(fan, string.format("FreezerFan%d", fan.index), TAG_FREEZER_FAN, Layout.FREEZER_WIDTH / 2)
	end

	-- G 스쿱 계단 (m5-40): 통 바닥(y 12) + 착지대(y 12 ~ 24 통짜) + 스쿱 기둥 4개 + 지름길 젤리
	local scoopHalf = Layout.SCOOP_ZONE_WIDTH / 2
	local scoopFloor = slab(
		"ScoopFloor",
		-scoopHalf,
		scoopHalf,
		Layout.SCOOP_ZONE.front,
		Layout.SCOOP_LANDING.front,
		Layout.HIGH_Y,
		thickness
	)
	scoopFloor.Color = COLORS.scoopFloor
	local scoopLanding = slab(
		"ScoopLanding",
		-scoopHalf,
		scoopHalf,
		Layout.SCOOP_LANDING.front,
		Layout.SCOOP_LANDING.back,
		Layout.TOP_Y,
		Layout.TOP_Y - Layout.HIGH_Y + thickness
	)
	scoopLanding.Color = COLORS.scoopLanding
	for i, scoop in Layout.SCOOPS do
		local height = Layout.scoopTop(i) - Layout.HIGH_Y
		makePart({
			Name = string.format("Scoop%d", i),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, Layout.SCOOP_DIAMETER, Layout.SCOOP_DIAMETER),
			CFrame = at(scoop.x, Layout.HIGH_Y + height / 2, scoop.z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = COLORS.scoops[i] or COLORS.scoops[1],
			Material = Enum.Material.Sand,
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
	end
	local scoopJelly = makePart({
		Name = "ScoopJelly",
		Size = Vector3.new(Layout.JELLY_SIZE, Layout.JELLY_TOP, Layout.JELLY_SIZE),
		CFrame = at(Layout.SCOOP_JELLY.x, Layout.HIGH_Y + Layout.JELLY_TOP / 2, Layout.SCOOP_JELLY.z),
		Color = COLORS.jellies[2],
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
		Parent = model,
	})
	CollectionService:AddTag(scoopJelly, TAG_SCOOP_JELLY)

	-- E 결승 + FinishLine
	local finishHalf = Layout.FINISH_WIDTH / 2
	slab("FinishFloor", -finishHalf, finishHalf, Layout.FINISH.front, Layout.FINISH.back, Layout.TOP_Y, thickness)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
		CFrame = at(0, Layout.TOP_Y + 0.2, Layout.FINISH_LINE_Z),
		Color = COLORS.finishLine,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	-- 장식(충돌 없음) + 소개 카메라 + 사용자 Studio 아트 자리
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

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- 젤리 튕김: 캐릭터 물리는 그 클라이언트가 맡아서 서버가 LinearVelocity를 잠깐 걸어요 (와사비와 같은 방식)
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "JellyAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "JellyLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(Layout.JELLY_HOLD, function()
		push:Destroy()
	end))
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local right = origin.RightVector
	local startedAt = os.clock()
	local finishProgress = Logic.finishProgress()

	local jellyPads: { [number]: BasePart } = {}
	for _, pad in taggedParts(ctx, TAG_JELLY) do
		local index = tonumber(string.match(pad.Name, "%d+"))
		if index then
			jellyPads[index] = pad
		end
	end
	local fans: { [number]: { vent: BasePart, frost: ParticleEmitter?, last: Logic.FanState? } } = {}
	for _, vent in taggedParts(ctx, TAG_FAN) do
		local index = vent:GetAttribute("FanIndex")
		if type(index) == "number" then
			local frost = vent:FindFirstChild("Frost")
			fans[index] = {
				vent = vent,
				frost = if frost and frost:IsA("ParticleEmitter") then frost else nil,
				last = nil,
			}
		end
	end

	local freezerFans: { [number]: { vent: BasePart, frost: ParticleEmitter?, last: Logic.FanState? } } = {}
	for _, vent in taggedParts(ctx, TAG_FREEZER_FAN) do
		local index = vent:GetAttribute("FanIndex")
		if type(index) == "number" then
			local frost = vent:FindFirstChild("Frost")
			freezerFans[index] = {
				vent = vent,
				frost = if frost and frost:IsA("ParticleEmitter") then frost else nil,
				last = nil,
			}
		end
	end
	local scoopJellyPad: BasePart? = taggedParts(ctx, TAG_SCOOP_JELLY)[1]

	local jellyVelocity = Vector3.new(0, Layout.JELLY_UP, 0) + origin.LookVector * Layout.JELLY_FORWARD
	local jellyReadyAt: { [Player]: number } = {}

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 판정: 결승선 통과 / 낙하
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root then
				local rel = origin:PointToObjectSpace(root.Position)
				if Logic.progress(rel.Z) >= finishProgress then
					ctx.pass(player)
				elseif rel.Y < Logic.fallLineAt(rel.Z) then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					return -- 이 통과/탈락으로 라운드가 끝났어요
				end
			end
		end

		-- 2. 송풍구 상태 (경고·불기 동안 서리, 불기 시작 때 소리 한 번)
		local blowing: { [number]: boolean } = {}
		for index, fan in fans do
			local state = Logic.fanState(index, elapsed)
			if state ~= fan.last then
				if fan.frost then
					fan.frost.Enabled = state ~= "Rest"
				end
				if state == "Blow" then
					MapSfx.play(fan.vent, "FanGust")
				end
				fan.last = state
			end
			blowing[index] = state == "Blow"
		end
		-- F 냉동 송풍구 (m5-40): 소리는 누가 냉동실 안에 있을 때만 (먼 방 소리가 겹치지 않게)
		local anyoneInFreezer = false
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root and Logic.inFreezer(origin:PointToObjectSpace(root.Position).Z) then
				anyoneInFreezer = true
				break
			end
		end
		local freezerBlowing: { [number]: boolean } = {}
		for index, fan in freezerFans do
			local state = Logic.freezerFanState(index, elapsed)
			if state ~= fan.last then
				if fan.frost then
					fan.frost.Enabled = state ~= "Rest"
				end
				if state == "Blow" and anyoneInFreezer then
					MapSfx.play(fan.vent, "FanGust")
				end
				fan.last = state
			end
			freezerBlowing[index] = state == "Blow"
		end

		-- 3. 남은 레이서: 젤리 튕김, 송풍구 밀기
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root == nil then
				continue
			end
			local character = player.Character
			local rel = origin:PointToObjectSpace(root.Position)

			local jelly = Logic.jellyAt(rel.X, rel.Y, rel.Z)
			local onScoopJelly = jelly == nil and Logic.scoopJellyAt(rel.X, rel.Y, rel.Z)
			if jelly or onScoopJelly then
				local readyAt = jellyReadyAt[player]
				if readyAt == nil or now >= readyAt then
					jellyReadyAt[player] = now + Layout.JELLY_COOLDOWN
					MoveExempt.mark(character, Layout.JELLY_EXEMPT)
					launch(ctx, root, jellyVelocity)
					local pad = if jelly then jellyPads[jelly] else scoopJellyPad
					MapSfx.play(pad or root, "JellyBoing")
				end
				continue
			end

			local fanIndex = Logic.fanAt(rel.X, rel.Y, rel.Z)
			if fanIndex and blowing[fanIndex] then
				local push = Logic.fanPush(fanIndex)
				local target = push.x * Layout.FAN_PUSH_SPEED
				local velocity = root.AssemblyLinearVelocity
				local add = Logic.pushDelta(velocity:Dot(right), target, Layout.FAN_PUSH_ACCEL, dt)
				if add ~= 0 then
					root.AssemblyLinearVelocity = velocity + right * add
				end
				continue
			end

			local freezerIndex = Logic.freezerFanAt(rel.X, rel.Y, rel.Z)
			if freezerIndex and freezerBlowing[freezerIndex] then
				local push = Logic.freezerFanPush(freezerIndex)
				local target = push.x * Layout.FAN_PUSH_SPEED
				local velocity = root.AssemblyLinearVelocity
				local add = Logic.pushDelta(velocity:Dot(right), target, Layout.FAN_PUSH_ACCEL, dt)
				if add ~= 0 then
					root.AssemblyLinearVelocity = velocity + right * add
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "디저트 냉장고",
	rule = "미끄러운 얼음을 건너 냉장고 문까지 달려요!",
	lighting = Art.LIGHTING, -- m5-23 맵 조명: 차가운 냉장고 안
	build = build,
	start = start,
}

return map
