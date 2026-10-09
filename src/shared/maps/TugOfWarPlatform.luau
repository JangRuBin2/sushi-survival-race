--!strict
-- Final 맵 "줄다리기 발판" (m5-18, docs/specs/m5-18-map-tug-of-war-platform.md).
-- 가게 마당에 놓인 거대한 시소형 발판 위에서 결승을 치러요. 살아남은 사람의 로컬 X 위치(무게 분포)로
-- 발판이 좌우로 기울고(TugOfWarPlatformLogic.tilt), 마찰이 낮아서 기울기가 크면 그 쪽으로 미끄러져 떨어져요.
-- 넉백·순간이동은 없어요 — 서버는 발판 CFrame만 돌리고, 미끄러짐은 전부 Roblox 물리(중력+마찰)예요.
-- 그래서 이동 감시(m4-10)에도 MoveExempt.mark를 달지 않아요(CLAUDE.md "이동 감시 면제", 결정 기록 D3 —
-- RamenRapidsLayout의 국물 밀기와 같은 "연속 밀기" 논리).
--
-- 연장전(overtime, m5-01)이 오면 무게 분포를 더 보지 않고 TugOfWarPlatformLogic.overtimeAngle이 정하는
-- 각도로 발판을 강제로 돌려요. 마지막 꺾인점은 항상 완전 수직(90°)이라 collapseDuration 안에 반드시
-- 설 곳이 없어져요(결정 기록 D2). 훅 안에서는 기다리지 않고(task.wait 없음) 시작 시각·각도만 기록해 두고,
-- 이미 돌고 있는 Heartbeat 루프가 매 틱 새 각도를 읽어서 적용해요.
--
-- 판정(발판 1개 BasePart, 태그 TugOfWarPlatform)과 레이아웃 수치는 TugOfWarPlatformLayout에,
-- 기울기·연장전 각도 계산은 TugOfWarPlatformLogic(둘 다 Roblox API 없음, Lune 테스트)에 있어요.
-- 장식(저울 접시 테두리·동아줄·무게추)은 발판과 같이 기울어지는 "PlatformGroup" 하위에 두고, 매 틱
-- workspace:BulkMoveTo로 발판과 같은 피벗 CFrame을 적용해요(SkewerShowdown의 moveFood 패턴과 같아요).
-- Roblox API는 build/start/overtime 안에서만 써서 Lune에서 require해도 안전해요.

local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.TugOfWarPlatformLayout)
local Logic = require(script.Parent.TugOfWarPlatformLogic)
local Art = require(script.Parent.TugOfWarPlatformArt)
local MapKit = require(script.Parent.MapKit)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapTypes = require(script.Parent.MapTypes)

local ID = "tug-of-war-platform"
local TAG_PLATFORM = "TugOfWarPlatform"

-- Logic.tilt가 양수(오른쪽, +X가 내려감)를 돌려줘도 실제 CFrame.Angles(0, 0, z)는 +X를 +Y(위)로 돌리는
-- 방향이라 부호를 뒤집어요. Studio AC9에서 반대로 보이면 이 상수만 뒤집어요(스펙 "무대" 절).
local TILT_SIGN = -1

local PALETTE = MapKitLogic.PALETTE

local function rgb(c: MapKitLogic.RGB): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function part(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
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

local function flatPivotOf(origin: CFrame): CFrame
	return origin * CFrame.new(0, 0, Layout.CENTER_Z)
end

local function buildPlatformGroup(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local flatPivot = flatPivotOf(origin)

	local group = Instance.new("Model")
	group.Name = "PlatformGroup"

	local platform = part({
		Name = "Platform",
		Size = Vector3.new(Layout.LENGTH, Layout.THICKNESS, Layout.WIDTH),
		CFrame = flatPivot * CFrame.new(0, -Layout.THICKNESS / 2, 0),
		Color = rgb(PALETTE.Wood),
		Material = Enum.Material.WoodPlanks,
		-- Friction만 낮추고 그 외(밀도·탄성·가중치)는 Roblox의 Plastic/SmoothPlastic 기본값 그대로예요
		-- (Density 0.7, Elasticity 0.5, FrictionWeight 1, ElasticityWeight 1).
		CustomPhysicalProperties = PhysicalProperties.new(0.7, Layout.FRICTION, 0.5, 1, 1),
		Parent = group,
	})
	CollectionService:AddTag(platform, TAG_PLATFORM)

	local weights = Instance.new("Folder")
	weights.Name = "Weights"
	weights.Parent = group
	MapKit.buildDecor(Art.deckDecor(), flatPivot, weights)

	return group
end

local function buildStaticArt(model: Model, origin: CFrame)
	local flatPivot = flatPivotOf(origin)
	local decorFolder = MapKit.decorFolder(model)
	for _, p in MapKit.buildDecor(Art.decor(), flatPivot, decorFolder) do
		p.CastShadow = false
		if p.Name == Art.LANTERN then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 170, 120)
			light.Brightness = 1.2
			light.Range = 16
			light.Parent = p
		end
	end
	MapKit.introCamera(model, Art.introCamera(), flatPivot)
	MapKit.attachStudioArt(model, ID, origin)
end

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	local platformGroup = buildPlatformGroup(origin)
	platformGroup.Parent = model

	buildStaticArt(model, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, pos in Layout.spawnPositions() do
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(pos.x, Layout.SPAWN_Y, pos.z),
			CanCollide = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	return model
end

-- 라운드(ctx)마다 start와 overtime이 같이 보는 상태 (m5-01 패턴, SkewerShowdown과 동일).
type RoundState = {
	startedAt: number, -- os.clock() 출발 시각
	angle: number, -- 지금 적용 중인 기울기(라디안)
	overtimeAt: number?, -- 연장전 시작(출발 기준 초). nil이면 아직 연장전 전
	collapseDuration: number?, -- 연장전이 시작되면 info.collapseDuration
	overtimeStartAngle: number, -- 연장전이 시작된 순간의 각도 (이어서 흔들려요)
}
local roundStates: { [MapTypes.RoundContext]: RoundState } = {}

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local flatPivot = flatPivotOf(origin)

	local platformGroup = ctx.model:FindFirstChild("PlatformGroup") :: Model
	assert(platformGroup and platformGroup:IsA("Model"), "PlatformGroup missing")

	-- 기울 때 같이 움직이는 전부(발판 파츠 + 무게추 장식). 오프셋은 flatPivot 기준(기울지 않은 상태)으로
	-- 한 번만 계산해 두고, 매 틱 pivotCFrame * offset으로 되돌려요 (SkewerShowdown.moveFood와 같은 패턴).
	local movingParts: { BasePart } = {}
	local movingOffsets: { CFrame } = {}
	for _, instance in platformGroup:GetDescendants() do
		if instance:IsA("BasePart") then
			table.insert(movingParts, instance)
			-- ToObjectSpace는 가변 반환(...CFrame)이라 괄호로 값 하나만 받아요(안 그러면 table.insert 인자가 늘어나요)
			table.insert(movingOffsets, (flatPivot:ToObjectSpace(instance.CFrame)))
		end
	end

	local startedAt = os.clock()
	local state: RoundState = {
		startedAt = startedAt,
		angle = 0,
		overtimeAt = nil,
		collapseDuration = nil,
		overtimeStartAngle = 0,
	}
	roundStates[ctx] = state
	ctx.cleanup:add(function()
		roundStates[ctx] = nil
	end)

	local function applyAngle(angle: number)
		local pivotCFrame = flatPivot * CFrame.Angles(0, 0, TILT_SIGN * angle)
		local targets = table.create(#movingParts) :: { CFrame }
		for i, offset in movingOffsets do
			targets[i] = pivotCFrame * offset
		end
		workspace:BulkMoveTo(movingParts, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local elapsed = os.clock() - startedAt

		-- 떨어진 사람을 먼저 걸러내고(origin 기준 Y는 기울어도 고정 기준), 남은 사람의 로컬 X를
		-- 다음 틱 기울기 목표에 써요(연장전 중에는 쓰지 않아요 — 무게 분포를 더 안 봐요).
		local positions: { number } = {}
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local relative = origin:PointToObjectSpace(root.Position)
			if relative.Y < -Layout.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return
				end
				continue
			end
			table.insert(positions, relative.X)
		end

		if state.overtimeAt ~= nil then
			local sinceOvertime = elapsed - state.overtimeAt
			state.angle = Logic.overtimeAngle(
				sinceOvertime,
				state.collapseDuration or Config.Final.CollapseDuration,
				state.overtimeStartAngle
			)
		else
			local target = Logic.tilt(positions)
			state.angle = Logic.approach(state.angle, target, Logic.TILT_RATE * dt)
		end
		applyAngle(state.angle)
	end))
end

-- 결승 연장전 (m5-01): 무게 분포를 더 안 보고, 지금 각도에서 이어서 강제로 좌우로 점점 크게 흔들어요.
-- 마지막 꺾인점이 완전 수직(90°)이라 info.collapseDuration 안에 반드시 설 곳이 없어져요. 기다리지 않고
-- (task.wait 없음) 시작 시각·각도만 적어 두면 start의 Heartbeat 루프가 매 틱 새 각도를 적용해요.
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	local state = roundStates[ctx]
	if state == nil then
		-- start가 실패했으면(있을 수 없지만) 안전 상한이 판정을 마무리해요.
		return
	end
	local elapsed = os.clock() - state.startedAt
	state.overtimeAt = elapsed
	state.collapseDuration = info.collapseDuration
	state.overtimeStartAngle = state.angle
end

local TugOfWarPlatform: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "줄다리기 발판",
	rule = "사람들이 몰린 쪽으로 발판이 기울어요. 균형을 잘 잡고 끝까지 버티세요!",
	build = build,
	start = start,
	overtime = overtime,
}

return TugOfWarPlatform
