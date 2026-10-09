--!strict
-- Race 맵 "간장 늪 & 와사비 산" (GDD 5.2 ②, 스펙 m2-02).
-- 출발 → 간장 늪(웅덩이 사이 지그재그 마른 길) → 와사비 산(패드로 바로 / 옆 통로+경사로로 돌아서)
-- → 날치알 내리막(결승 쪽이 높고 공이 굴러 내려와요) → 결승.
-- 치수·튜닝 값은 SoySwampLayout, 장애물 동작은 SoySwampHazards에 있어요.
-- 코스는 origin의 LookVector(로컬 -Z)로 뻗어요. build/start 안에서만 Roblox API를 써서 Lune에서 require해도 안전해요.

local Art = require(script.Parent.SoySwampArt)
local Config = require(script.Parent.Parent.Config)
local Hazards = require(script.Parent.SoySwampHazards)
local Layout = require(script.Parent.SoySwampLayout)
local MapKit = require(script.Parent.MapKit)
local MapTypes = require(script.Parent.MapTypes)

local ID = "soy-swamp"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]

-- 색 표 (m4-02 아트: SoySwampArt.COLORS). Color3는 Roblox API라 build 안에서만 만들어요.
local function palette(): { [string]: Color3 }
	local colors = {}
	for key, c in Art.COLORS do
		colors[key] = Color3.fromRGB(c.r, c.g, c.b)
	end
	return colors
end

-- Instance.new + 속성 적용. Parent는 맨 마지막에 넣어요.
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
	-- 아트 재질(나무·모래)을 입혀도 마찰·밀도는 M3의 SmoothPlastic 그대로 (날치알 구르기·발밑 느낌이 같게)
	local SMOOTH = PhysicalProperties.new(Enum.Material.SmoothPlastic)
	local model = Instance.new("Model")
	model.Name = ID

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 바닥 위(y 0)에서 높이 height인 블록. box의 x/z 중심과 폭·깊이를 써요.
	local function block(
		name: string,
		x: number,
		z: number,
		width: number,
		depth: number,
		height: number,
		color: Color3,
		material: Enum.Material
	): BasePart
		return makePart({
			Name = name,
			Size = Vector3.new(width, height, depth),
			CFrame = at(x, height / 2, z),
			Color = color,
			Material = material,
			CustomPhysicalProperties = SMOOTH,
			Parent = model,
		})
	end

	local half = Layout.WIDTH / 2
	local length = Layout.totalLength()

	-- 지면: 출발부터 끝 벽까지 한 장 (구간별 색은 위에 얇은 판을 깔지 않고 지면 하나로 둬요)
	makePart({
		Name = "Floor",
		Size = Vector3.new(Layout.WIDTH, Layout.FLOOR_THICKNESS, length),
		CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, Layout.START.front - length / 2),
		Color = COLORS.floor,
		Material = Enum.Material.WoodPlanks,
		CustomPhysicalProperties = SMOOTH,
		Parent = model,
	})

	-- 양옆 벽 + 출발 뒤 벽 + 끝 벽 (와사비로 튀어도 못 넘게 높게)
	local wallY = Layout.WALL_HEIGHT / 2
	for _, side in { -1, 1 } do
		makePart({
			Name = "Wall",
			Size = Vector3.new(0.5, Layout.WALL_HEIGHT, length),
			CFrame = at(side * (half + 0.25), wallY, Layout.START.front - length / 2),
			Color = COLORS.wall,
			Transparency = 0.6,
			Material = Enum.Material.Glass,
			Parent = model,
		})
	end
	makePart({
		Name = "StartWall",
		Size = Vector3.new(Layout.WIDTH + 1, Layout.WALL_HEIGHT, 0.5),
		CFrame = at(0, wallY, Layout.START.front + 0.25),
		Color = COLORS.wall,
		Transparency = 0.6,
		Material = Enum.Material.Glass,
		Parent = model,
	})
	makePart({
		Name = "EndWall",
		Size = Vector3.new(Layout.WIDTH + 1, Layout.WALL_HEIGHT, 0.5),
		CFrame = at(0, wallY, Layout.FINISH.back - 0.25),
		Color = COLORS.wall,
		Transparency = 0.6,
		Material = Enum.Material.Glass,
		Parent = model,
	})

	-- 1. 출발 구간 + 스폰 24개 (이름순 배치)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == MAX_PLAYERS, "spawn count must cover the largest room size")
	for i, pos in positions do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(3, 0.2, 3),
			CFrame = at(pos.x, 0.1, pos.z),
			Color = COLORS.spawn,
			Transparency = 0.4,
			CanCollide = false,
			Parent = spawns,
		})
	end

	-- 2. 간장 늪: 늪 바닥 색 판 + 간장 웅덩이(SoySauce 태그)
	local swampDepth = Layout.SWAMP.front - Layout.SWAMP.back
	makePart({
		Name = "SwampFloor",
		Size = Vector3.new(Layout.WIDTH, 0.1, swampDepth),
		CFrame = at(0, 0.05, Layout.SWAMP.front - swampDepth / 2),
		Color = COLORS.swamp,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local puddles = Instance.new("Folder")
	puddles.Name = "SoyPuddles"
	puddles.Parent = model
	for i, box in Layout.PUDDLES do
		local puddle = makePart({
			Name = `SoyPuddle{i}`,
			Size = Vector3.new(box.width, Layout.PUDDLE_DEPTH, box.depth),
			CFrame = at(box.x, 0.1 + Layout.PUDDLE_DEPTH / 2, box.z),
			Color = COLORS.soy,
			Material = Enum.Material.Glass,
			Reflectance = Art.SOY_REFLECTANCE,
			Transparency = 0.15,
			CanCollide = false,
			CanTouch = false,
			Parent = puddles,
		})
		CollectionService:AddTag(puddle, "SoySauce")
	end

	-- 3. 와사비 산: 앞이 절벽인 몸통 + 폭 전체 뒷단 + 오른쪽 경사로 (지면 통로 끝에서 되돌아 올라가요)
	local h = Layout.MOUNTAIN_HEIGHT
	local body = Layout.MOUNTAIN_BODY
	block("MountainBody", body.x, body.z, body.width, body.depth, h, COLORS.mountain, Enum.Material.Sand)
	local back = Layout.MOUNTAIN_BACK
	block("MountainBack", back.x, back.z, back.width, back.depth, h, COLORS.mountain, Enum.Material.Sand)

	local ramp = Layout.RAMP
	local run = ramp.high - ramp.low
	local angle = math.atan(h / run)
	local slab = 1
	makePart({
		Name = "Ramp",
		Size = Vector3.new(ramp.width, slab, math.sqrt(run * run + h * h)),
		-- 가운데 높이 h/2, 높은 쪽이 +Z(ramp.high). Rx(-angle)이 +Z 끝을 들어 올려요.
		CFrame = at(ramp.x, h / 2 - (slab / 2) / math.cos(angle), (ramp.low + ramp.high) / 2)
			* CFrame.Angles(-angle, 0, 0),
		Color = COLORS.ramp,
		Material = Enum.Material.WoodPlanks,
		CustomPhysicalProperties = SMOOTH,
		Parent = model,
	})

	local pads = Instance.new("Folder")
	pads.Name = "WasabiPads"
	pads.Parent = model
	for i, box in Layout.WASABI_PADS do
		local pad = makePart({
			Name = `WasabiPad{i}`,
			Size = Vector3.new(box.width, Layout.PAD_THICKNESS, box.depth),
			CFrame = at(box.x, Layout.PAD_THICKNESS / 2, box.z),
			Color = COLORS.wasabi,
			Material = Enum.Material.Neon,
			Parent = pads,
		})
		CollectionService:AddTag(pad, "Wasabi")
	end

	-- 4. 날치알 내리막: 산 높이의 받침 위에 결승 쪽이 높은 판
	local slopeDepth = Layout.SLOPE.front - Layout.SLOPE.back
	local slopeCenterZ = Layout.SLOPE.front - slopeDepth / 2
	block("SlopeBase", 0, slopeCenterZ, Layout.WIDTH, slopeDepth, Layout.SLOPE_LOW, COLORS.mountain, Enum.Material.Sand)
	local rise = Layout.SLOPE_HIGH - Layout.SLOPE_LOW
	local slopeAngle = math.atan(rise / slopeDepth)
	makePart({
		Name = "TobikoSlope",
		Size = Vector3.new(Layout.WIDTH, slab, math.sqrt(slopeDepth * slopeDepth + rise * rise)),
		-- 높은 쪽이 -Z(결승 쪽). Rx(+angle)이 -Z 끝을 들어 올려요.
		CFrame = at(0, (Layout.SLOPE_LOW + Layout.SLOPE_HIGH) / 2 - (slab / 2) / math.cos(slopeAngle), slopeCenterZ)
			* CFrame.Angles(slopeAngle, 0, 0),
		Color = COLORS.slope,
		Material = Enum.Material.WoodPlanks,
		CustomPhysicalProperties = SMOOTH,
		Parent = model,
	})
	-- 경사판 아래 빈틈은 받침(아래)·결승 단(앞)·양옆 벽으로 막혀 있어서 따로 채우지 않아요.

	-- 5. 결승 구간: 내리막 꼭대기 높이의 단 + 결승선(표시용, 판정은 start의 위치 판정)
	local finishDepth = Layout.FINISH.front - Layout.FINISH.back
	block(
		"FinishBase",
		0,
		Layout.FINISH.front - finishDepth / 2,
		Layout.WIDTH,
		finishDepth,
		Layout.SLOPE_HIGH,
		COLORS.floor,
		Enum.Material.WoodPlanks
	)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.WIDTH, 0.4, 1),
		CFrame = at(0, Layout.SLOPE_HIGH + 0.2, Layout.finishLineZ()),
		Color = COLORS.finish,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	-- 아트 (m4-02, m5-20): 장식은 충돌·쿼리·터치 없음, 손으로 짠 소개 카메라, 사용자 Studio 아트 자리
	for _, part in MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model)) do
		if part.Name == Art.HILL_RICE then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(150, 230, 70)
			light.Brightness = 1
			light.Range = 20
			light.Parent = part
		elseif part.Name == Art.PUDDLE_BUBBLE then
			local bubble = Instance.new("ParticleEmitter")
			bubble.Name = "SoyBubbleEmitter"
			bubble.Color = ColorSequence.new(Color3.fromRGB(70, 40, 20))
			bubble.LightEmission = 0
			bubble.Rate = 1
			bubble.Lifetime = NumberRange.new(2, 3)
			bubble.Speed = NumberRange.new(0.3, 0.6)
			bubble.SpreadAngle = Vector2.new(5, 5)
			bubble.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 0.5),
			})
			bubble.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			})
			bubble.EmissionDirection = Enum.NormalId.Top
			bubble.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin

	-- 결승선 통과: HumanoidRootPart가 결승선의 로컬 z를 지났는지로 판정해요 (M1 B2 수정과 같은 방식 —
	-- 높이와 상관없어서 점프로 넘어도 통과). ctx.pass는 통과한 사람을 getRacers에서 빼서 한 번만 불려요.
	local finishProgress = -Layout.finishLineZ()
	local finishLine = ctx.model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		finishProgress = -origin:PointToObjectSpace(finishLine.Position).Z
	end
	local fallY = origin.Position.Y - Layout.FALL_DEPTH

	local stepSoy = Hazards.soyStepper(ctx)
	local stepWasabi = Hazards.wasabiStepper(ctx)
	local stepTobiko = Hazards.tobikoStepper(ctx)

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if -origin:PointToObjectSpace(root.Position).Z >= finishProgress then
					ctx.pass(player)
				elseif root.Position.Y < fallY then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					return -- 이 통과/탈락으로 라운드가 끝났어요
				end
			end
		end

		-- 판정이 끝난 뒤 남은 레이서에게만 장애물을 적용해요
		local racers = ctx.getRacers()
		stepSoy(racers)
		stepWasabi(racers)
		stepTobiko(racers)
	end))
end

local SoySwamp: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "간장 늪 & 와사비 산",
	rule = "간장 웅덩이는 피하고, 와사비 패드로 튀어 올라 결승선까지!",
	build = build,
	start = start,
}

return SoySwamp
