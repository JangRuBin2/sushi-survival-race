--!strict
-- Final 맵 "회전 꼬치 쇼다운" (GDD 5.2 ⑥, 생존형 결승, m2-04).
-- 공중에 뜬 원형 접시 무대(부채꼴 조각 8개) 가운데 기둥에서 꼬치 두 개가 돌아요.
-- 낮은 꼬치는 뛰어넘고, 높은 꼬치는 너무 높이 뛰면 맞아요. 시간이 갈수록 빨라지고
-- 셰프의 손이 경고 뒤 조각을 하나씩 가져가서 결국 1조각만 남아요.
--
-- 이 맵은 떨어진 사람을 ctx.eliminate로 알리기만 해요. 우승 판정(1명 남음, 동시 낙하, 시간 종료)은
-- RoundService가 해요 (m2-05). ctx.pass는 부르지 않아요 (결승선 없음).
-- 장애물(꼬치·조각·손)은 CollectionService 태그를 달고, start에서 ctx.model 하위의 태그만 동작시켜요 (B10 A).
-- 상태는 전부 start 안의 지역 변수/ctx에 둬요 (여러 방이 같은 맵을 동시에 돌려도 섞이지 않게).
-- Roblox API는 build/start 안에서만 써서 Lune에서 require해도 안전해요.
-- 시간 일정·속도·맞음 판정 계산은 SkewerShowdownLogic(순수 로직, tests/map-skewer-showdown.spec.luau)에 있어요.

local Config = require(script.Parent.Parent.Config)
local Logic = require(script.Parent.SkewerShowdownLogic)
local MapTypes = require(script.Parent.MapTypes)

local ID = "skewer-showdown"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]

local TAG_SKEWER = "SkewerShowdownSkewer"
local TAG_SLICE = "SkewerShowdownSlice"
local TAG_HAND = "SkewerShowdownHand"

-- 무대 (studs). 무대 중심 = origin, 무대 윗면 = origin 높이.
local STAGE_RADIUS = Logic.STAGE_RADIUS
local STAGE_THICKNESS = 1.5
local STRIPS_PER_SLICE = 8
local PILLAR_DIAMETER = Logic.PILLAR_DIAMETER
local PILLAR_TOP = 16 -- 무대 위로 이만큼 솟아서 뛰어 올라갈 수 없어요
local PILLAR_BOTTOM = -10
local FALL_DEPTH = 20 -- 무대 윗면보다 이만큼 아래로 내려가면 탈락

-- 꼬치 치수·시작 각도는 스폰 배치와 함께 SkewerShowdownLogic에 있어요 (시작 직후 맞지 않는지 테스트로 고정)
local LOW_SKEWER = Logic.LOW_SKEWER
local HIGH_SKEWER = Logic.HIGH_SKEWER
local SKEWER_THICKNESS = LOW_SKEWER.radius * 2

-- 꼬치에 맞았을 때
local KNOCK_OUTWARD = 32 -- 바깥쪽 속도 (studs/s)
local KNOCK_UP = 22 -- 위로 띄우는 속도
local KNOCKDOWN_TIME = 1 -- 넘어져 있는 시간, 같은 플레이어 재피격 쿨다운

-- 셰프의 손
local WARN_TIME = 2 -- 조각이 빨갛게 깜빡이며 흔들리는 시간
local WARN_BLINK = 0.2
local WARN_SHAKE = 0.25
local HAND_REST_HEIGHT = 35
local HAND_HOVER_HEIGHT = 2.5 -- 조각을 집을 때 손바닥 높이 (무대 윗면 기준)
local HAND_DESCEND_TIME = 0.4
local HAND_LIFT_TIME = 0.5
local HAND_LIFT_HEIGHT = 30
-- 경고 + 내려옴 + 들어 올림이 서든데스 간격(3초)보다 짧아야 손이 밀리지 않아요
assert(WARN_TIME + HAND_DESCEND_TIME + HAND_LIFT_TIME < Logic.SUDDEN_DEATH_INTERVAL, "hand grab too slow")

-- 색은 Color3(Roblox API)라서 require 때가 아니라 쓸 때 만들어요 (Lune에서 require 안전)
local WARN_RGB = { 230, 40, 40 }
local WOOD_RGB = { 205, 168, 112 }

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

-- 무대 중심 기준 각도 angle 방향(꼬치 각도와 같은 기준)으로 radial만큼, 높이 y인 CFrame. 로컬 X축이 바깥쪽.
local function radialCFrame(origin: CFrame, angle: number, radial: number, y: number): CFrame
	return origin * CFrame.Angles(0, angle, 0) * CFrame.new(radial, y, 0)
end

local function skewerCFrame(origin: CFrame, spec: Logic.SkewerSpec, angle: number): CFrame
	return radialCFrame(origin, angle, (spec.innerReach + spec.outerReach) / 2, spec.height)
end

local function buildSlice(model: Model, origin: CFrame, index: number): Model
	local CollectionService = game:GetService("CollectionService")
	local slice = Instance.new("Model")
	slice.Name = string.format("Slice%d", index)
	local sliceAngle = 2 * math.pi / Logic.SLICE_COUNT
	local bisector = (index - 0.5) * sliceAngle
	local halfTan = math.tan(sliceAngle / 2)
	local apothem = STAGE_RADIUS * math.cos(sliceAngle / 2)
	local depth = apothem / STRIPS_PER_SLICE
	-- 조각마다 밝기를 조금씩 달리해서 구분돼요
	local color = Color3.fromHSV(0.09, if index % 2 == 0 then 0.10 else 0.18, 0.96 - (index - 1) * 0.025)
	for strip = 1, STRIPS_PER_SLICE do
		local mid = (strip - 0.5) * depth
		makePart({
			Name = "Plate",
			Size = Vector3.new(depth, STAGE_THICKNESS, 2 * mid * halfTan),
			CFrame = radialCFrame(origin, bisector, mid, -STAGE_THICKNESS / 2),
			Color = color,
			Parent = slice,
		})
	end
	slice:SetAttribute("SliceIndex", index)
	slice:SetAttribute("Bisector", bisector)
	CollectionService:AddTag(slice, TAG_SLICE)
	slice.Parent = model
	return slice
end

local function buildSkewer(model: Model, origin: CFrame, name: string, spec: Logic.SkewerSpec, angle: number)
	local CollectionService = game:GetService("CollectionService")
	local skewer = makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder, -- 축이 로컬 X(바깥쪽)
		Size = Vector3.new(spec.outerReach - spec.innerReach, SKEWER_THICKNESS, SKEWER_THICKNESS),
		CFrame = skewerCFrame(origin, spec, angle),
		Color = Color3.fromRGB(table.unpack(WOOD_RGB)),
		Material = Enum.Material.Wood,
		CanCollide = false, -- 올라타서 버티지 못하게. 맞음 판정은 서버가 거리로 해요.
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})
	CollectionService:AddTag(skewer, TAG_SKEWER)
end

local function buildHand(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local hand = Instance.new("Model")
	hand.Name = "ChefHand"
	local grey = Color3.fromRGB(200, 200, 205)
	local base = origin * CFrame.new(0, HAND_REST_HEIGHT, 0)
	local palm = makePart({
		Name = "Palm",
		Size = Vector3.new(9, 2, 8),
		CFrame = base,
		Parent = hand,
	})
	for i = 1, 4 do
		makePart({
			Name = "Finger",
			Size = Vector3.new(1.6, 5, 1.6),
			CFrame = base * CFrame.new(-3.6 + (i - 1) * 2.4, -3, -3),
			Parent = hand,
		})
	end
	makePart({
		Name = "Thumb",
		Size = Vector3.new(1.8, 4, 1.8),
		CFrame = base * CFrame.new(0, -2.5, 3.6),
		Parent = hand,
	})
	for _, part in hand:GetChildren() do
		if part:IsA("BasePart") then
			part.Color = grey
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	hand.PrimaryPart = palm
	CollectionService:AddTag(hand, TAG_HAND)
	hand.Parent = model
end

-- 장식용 가게 문: 무대 앞쪽(로컬 -Z) 너머, 뛰어서 닿지 않는 거리. 밟을 수도 없어요.
local function buildShopDoor(model: Model, origin: CFrame)
	local door = Instance.new("Model")
	door.Name = "ShopDoor"
	local base = origin * CFrame.new(0, 0, -(STAGE_RADIUS + 18))
	local frame = Color3.fromRGB(110, 80, 55)
	for _, side in { -1, 1 } do
		makePart({
			Name = "Post",
			Size = Vector3.new(2, 16, 2),
			CFrame = base * CFrame.new(side * 6, 8, 0),
			Color = frame,
			Parent = door,
		})
	end
	makePart({
		Name = "Lintel",
		Size = Vector3.new(16, 2, 2.5),
		CFrame = base * CFrame.new(0, 17, 0),
		Color = frame,
		Parent = door,
	})
	makePart({
		Name = "Panel",
		Size = Vector3.new(10, 14, 0.5),
		CFrame = base * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.Wood,
		Parent = door,
	})
	makePart({
		Name = "Noren", -- 가게 천 간판
		Size = Vector3.new(14, 3, 0.2),
		CFrame = base * CFrame.new(0, 14.5, 0.6),
		Color = Color3.fromRGB(40, 60, 120),
		Material = Enum.Material.Fabric,
		Parent = door,
	})
	for _, part in door:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	door.Parent = model
end

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	for index = 1, Logic.SLICE_COUNT do
		buildSlice(model, origin, index)
	end

	-- 가운데 기둥: 무대 위로 높이 솟아 있어서 올라가 버틸 수 없어요
	makePart({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(PILLAR_TOP - PILLAR_BOTTOM, PILLAR_DIAMETER, PILLAR_DIAMETER),
		CFrame = origin * CFrame.new(0, (PILLAR_TOP + PILLAR_BOTTOM) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 150, 155),
		Material = Enum.Material.Metal,
		Parent = model,
	})

	buildSkewer(model, origin, "LowSkewer", LOW_SKEWER, Logic.LOW_START_ANGLE)
	buildSkewer(model, origin, "HighSkewer", HIGH_SKEWER, Logic.HIGH_START_ANGLE)
	buildHand(model, origin)
	buildShopDoor(model, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	-- 각도는 Logic.spawnAngles: 낮은 꼬치 시작 각도 바로 앞(회전 방향) 90°는 비워서 시작 직후 맞지 않아요 (QA B1)
	for i, angle in Logic.spawnAngles(MAX_PLAYERS) do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = radialCFrame(origin, angle, Logic.SPAWN_RADIUS, 0.1),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			Parent = spawns,
		})
	end

	return model
end

-- 태그가 붙은 것 중 이 라운드의 맵(ctx.model) 안에 있는 것만 (B10 A)
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
local function movePivot(target: Model, to: CFrame, duration: number)
	local RunService = game:GetService("RunService")
	local from = target:GetPivot()
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / duration, 1)
		target:PivotTo(from:Lerp(to, 1 - (1 - alpha) * (1 - alpha))) -- ease-out
	end
end

local function setSliceColor(slice: Model, color: Color3?)
	for _, part in slice:GetChildren() do
		if part:IsA("BasePart") then
			part.Color = color or (part:GetAttribute("BaseColor") :: Color3? or part.Color)
		end
	end
end

-- 조각 하나: 2초 경고(빨갛게 깜빡이며 흔들림) → 손이 내려와 집음(바닥이 사라져 위에 있던 사람은 떨어짐) → 들어 올려 치움.
local function grabSlice(ctx: MapTypes.RoundContext, slice: Model, hand: Model?)
	for _, part in slice:GetChildren() do
		if part:IsA("BasePart") then
			part:SetAttribute("BaseColor", part.Color)
		end
	end
	local home = slice:GetPivot()
	local warnColor = Color3.fromRGB(table.unpack(WARN_RGB))
	local blinkOn = true
	local warned = 0
	while warned < WARN_TIME do
		setSliceColor(slice, if blinkOn then warnColor else nil)
		local shake = Vector3.new(
			ctx.rng:NextNumber(-WARN_SHAKE, WARN_SHAKE),
			ctx.rng:NextNumber(-WARN_SHAKE, WARN_SHAKE) * 0.4,
			ctx.rng:NextNumber(-WARN_SHAKE, WARN_SHAKE)
		)
		slice:PivotTo(home + shake)
		blinkOn = not blinkOn
		warned += task.wait(WARN_BLINK)
	end
	slice:PivotTo(home)
	setSliceColor(slice, warnColor)
	if not ctx.isActive() then
		return
	end

	local bisector = slice:GetAttribute("Bisector") :: number
	local sliceCenter = radialCFrame(ctx.origin, bisector, STAGE_RADIUS * 0.55, 0)
	if hand then
		movePivot(hand, CFrame.new(sliceCenter.Position + Vector3.new(0, HAND_HOVER_HEIGHT + 3, 0)), HAND_DESCEND_TIME)
	end
	-- 집은 순간 바닥이 사라져요 (그 위에 있던 캐릭터는 떨어져요)
	for _, part in slice:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Transparency = 0.3
		end
	end
	local lift = Vector3.new(0, HAND_LIFT_HEIGHT, 0)
	local liftThread
	if hand then
		local handTarget = hand:GetPivot() + lift
		liftThread = task.spawn(movePivot, hand, handTarget, HAND_LIFT_TIME)
		ctx.cleanup:add(liftThread)
	end
	movePivot(slice, home + lift, HAND_LIFT_TIME)
	slice:Destroy()
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")

	local origin = ctx.origin
	local stageTopY = origin.Position.Y
	local startedAt = os.clock()

	local lowSkewer: BasePart? = nil
	local highSkewer: BasePart? = nil
	for _, instance in taggedInModel(ctx.model, TAG_SKEWER) do
		if instance:IsA("BasePart") then
			if instance.Name == "LowSkewer" then
				lowSkewer = instance
			elseif instance.Name == "HighSkewer" then
				highSkewer = instance
			end
		end
	end
	local slices: { Model } = {}
	for _, instance in taggedInModel(ctx.model, TAG_SLICE) do
		if instance:IsA("Model") then
			table.insert(slices, instance)
		end
	end
	table.sort(slices, function(a, b)
		return (a:GetAttribute("SliceIndex") :: number) < (b:GetAttribute("SliceIndex") :: number)
	end)
	local hand: Model? = nil
	for _, instance in taggedInModel(ctx.model, TAG_HAND) do
		if instance:IsA("Model") then
			hand = instance
		end
	end

	if highSkewer then
		highSkewer.Transparency = 1 -- 10초에 등장
	end

	local lowAngle = Logic.LOW_START_ANGLE
	local highAngle = Logic.HIGH_START_ANGLE
	local lastHitAt: { [number]: number } = {}

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	-- 바깥쪽(+위로 조금) 밀어내고 1초 넘어뜨린다. 캐릭터는 클라이언트 소유라 서버가 속도를 직접 줘요.
	local function knockBack(player: Player, root: BasePart, humanoid: Humanoid, dx: number, dz: number)
		lastHitAt[player.UserId] = os.clock()
		local outward = Vector3.new(dx, 0, dz)
		outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.xAxis
		local worldOut = origin:VectorToWorldSpace(outward)
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = worldOut * KNOCK_OUTWARD + Vector3.yAxis * KNOCK_UP
		ctx.cleanup:add(task.delay(KNOCKDOWN_TIME, function()
			-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
			if ctx.isActive() and humanoid.Parent and isRacer(player) then
				humanoid.PlatformStand = false
			end
		end))
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local elapsed = os.clock() - startedAt
		local speeds = Logic.speeds(elapsed)
		local highActive = Logic.highSkewerActive(elapsed)

		local lowFrom = lowAngle
		local lowTo = lowFrom + math.rad(speeds.low) * dt
		lowAngle = lowTo % (2 * math.pi)
		if lowSkewer then
			lowSkewer.CFrame = skewerCFrame(origin, LOW_SKEWER, lowAngle)
		end
		local highFrom = highAngle
		local highTo = highFrom + math.rad(speeds.high) * dt
		highAngle = highTo % (2 * math.pi)
		if highSkewer then
			highSkewer.CFrame = skewerCFrame(origin, HIGH_SKEWER, highAngle)
			if highActive and highSkewer.Transparency > 0 then
				highSkewer.Transparency = 0
			end
		end

		local now = os.clock()
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			if root.Position.Y < stageTopY - FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					break -- 이 탈락으로 결승이 끝났어요
				end
				continue
			end
			if humanoid == nil or now - (lastHitAt[player.UserId] or -math.huge) < KNOCKDOWN_TIME then
				continue
			end
			local relative = origin:PointToObjectSpace(root.Position)
			local hit = Logic.isHit(relative.X, relative.Z, relative.Y, lowFrom, lowTo, LOW_SKEWER)
				or (highActive and Logic.isHit(relative.X, relative.Z, relative.Y, highFrom, highTo, HIGH_SKEWER))
			if hit then
				knockBack(player, root, humanoid, relative.X, relative.Z)
			end
		end
	end))

	-- 셰프의 손: 정해진 시각마다 남은 조각 중 무작위로 하나 (서 있는 사람과 상관없이)
	ctx.cleanup:add(task.spawn(function()
		local alive = table.clone(slices)
		for _, grabAt in Logic.grabTimes(#slices) do
			local untilGrab = grabAt - (os.clock() - startedAt)
			if untilGrab > 0 then
				task.wait(untilGrab)
			end
			if not ctx.isActive() or #alive <= Logic.SLICES_AT_END then
				break
			end
			local slice = table.remove(alive, ctx.rng:NextInteger(1, #alive)) :: Model
			grabSlice(ctx, slice, hand)
		end
	end))
end

local SkewerShowdown: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "회전 꼬치 쇼다운",
	rule = "돌아오는 꼬치를 뛰어넘고 끝까지 버티세요! 마지막 1명만 탈출해요",
	build = build,
	start = start,
}

return SkewerShowdown
