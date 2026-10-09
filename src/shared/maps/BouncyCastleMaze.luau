--!strict
-- Race 맵 "방방 미로" (GDD §5.3 v0.6, 스펙 m5-14).
-- 출발(일반 바닥) → 대기실·관문(BounceFloor, 1번 레인만 열림) → 미로(BounceFloor, 레인 4개를 칸막이
-- 3개가 S자로 갈라놓음) → 출구 통로(일반 바닥, 튕김 끝) → 결승.
-- BounceFloor 위에 있으면 쿨다운마다 자동으로 위로 튕겨서(수직 전용, 수평 성분 없음) 멈춰 설 수 없어요.
-- 치수·튜닝 값은 BouncyCastleMazeLayout, 포물선·격자 판정 계산은 BouncyCastleMazeLogic에 있어요.
-- 코스는 origin의 LookVector(로컬 -Z)로 뻗어요. build/start 안에서만 Roblox API를 써서 Lune에서
-- require해도 안전해요 (CLAUDE.md "맵 모듈 공통 인터페이스").

local Art = require(script.Parent.BouncyCastleMazeArt)
local Layout = require(script.Parent.BouncyCastleMazeLayout)
local Logic = require(script.Parent.BouncyCastleMazeLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "bouncy-castle-maze"
local BOUNCE_TAG = "BounceFloor"

local function toColor3(rgb: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
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

	local COLORS = Art.COLORS
	-- 아트 재질을 입혀도 마찰·밀도는 M3의 SmoothPlastic 그대로 (바운스·발밑 느낌이 같게)
	local SMOOTH = PhysicalProperties.new(Enum.Material.SmoothPlastic)
	local model = Instance.new("Model")
	model.Name = ID

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- origin 기준 바닥 한 장 (z 범위, 태그 유무 선택)
	local function floorSlab(
		name: string,
		front: number,
		back: number,
		color: { r: number, g: number, b: number },
		tag: boolean?
	)
		local depth = front - back
		local slab = makePart({
			Name = name,
			Size = Vector3.new(Layout.WIDTH, Layout.FLOOR_THICKNESS, depth),
			CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, front - depth / 2),
			Color = toColor3(color),
			CustomPhysicalProperties = SMOOTH,
			Parent = model,
		})
		if tag then
			CollectionService:AddTag(slab, BOUNCE_TAG)
		end
		return slab
	end

	-- A: 출발 (일반 바닥)
	floorSlab("FloorStart", Layout.START.front, Layout.START.back, COLORS.floor)
	-- B+C: 대기실 + 미로 (BounceFloor, 한 장으로 이어져요 — 칸막이가 위에서 길을 갈라요)
	floorSlab("FloorBounce", Layout.ANTEROOM.front, Layout.MAZE.back, COLORS.bounceFloor, true)
	-- D: 출구 통로 (일반 바닥, 튕김 끝)
	floorSlab("FloorExit", Layout.EXIT.front, Layout.EXIT.back, COLORS.floor)
	-- E: 결승 (일반 바닥)
	floorSlab("FloorFinish", Layout.FINISH.front, Layout.FINISH.back, COLORS.floor)

	-- 양옆 벽 + 출발 뒤 벽 + 끝 벽 (바운스로 튀어도 못 넘게 높게)
	local length = Layout.totalLength()
	local wallY = Layout.WALL_HEIGHT / 2
	for _, side in { -1, 1 } do
		makePart({
			Name = "Wall",
			Size = Vector3.new(0.5, Layout.WALL_HEIGHT, length),
			CFrame = at(side * (Layout.HALF_WIDTH + 0.25), wallY, Layout.START.front - length / 2),
			Color = toColor3(COLORS.wall),
			Parent = model,
		})
	end
	makePart({
		Name = "StartWall",
		Size = Vector3.new(Layout.WIDTH + 1, Layout.WALL_HEIGHT, 0.5),
		CFrame = at(0, wallY, Layout.START.front + 0.25),
		Color = toColor3(COLORS.wall),
		Parent = model,
	})
	makePart({
		Name = "EndWall",
		Size = Vector3.new(Layout.WIDTH + 1, Layout.WALL_HEIGHT, 0.5),
		CFrame = at(0, wallY, Layout.FINISH.back - 0.25),
		Color = toColor3(COLORS.wall),
		Parent = model,
	})

	-- 칸막이 3개: 각자 막힌 구간(blockedZHigh~blockedZLow)만큼만 벽을 세워요. 틈은 벽이 아예 없어요.
	for i, partition in Layout.PARTITIONS do
		local depth = partition.blockedZHigh - partition.blockedZLow
		local colorKey = Art.PARTITION_COLOR_KEYS[i]
		makePart({
			Name = string.format("Partition%d", i),
			Size = Vector3.new(partition.thickness, Layout.WALL_HEIGHT, depth),
			CFrame = at(partition.x, wallY, (partition.blockedZHigh + partition.blockedZLow) / 2),
			Color = toColor3(COLORS[colorKey]),
			Parent = model,
		})
	end

	-- 관문(입구 문): 1번 레인(Layout.GATE.openXMin~openXMax)만 비우고 나머지 폭을 막아요.
	local gate = Layout.GATE
	local function gateDoor(name: string, xMin: number, xMax: number)
		local width = xMax - xMin
		if width <= 0 then
			return
		end
		makePart({
			Name = name,
			Size = Vector3.new(width, Layout.WALL_HEIGHT, gate.thickness),
			CFrame = at((xMin + xMax) / 2, wallY, gate.z),
			Color = toColor3(COLORS.gate),
			Parent = model,
		})
	end
	gateDoor("GateDoorLeft", Layout.BOUNDS.xMin, gate.openXMin)
	gateDoor("GateDoorRight", gate.openXMax, Layout.BOUNDS.xMax)

	-- 스폰 24개 (6열 × 4줄, 이름순 배치)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, pos in Layout.spawnPositions() do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, 0.1, pos.z),
			Color = toColor3(COLORS.spawn),
			Transparency = 0.4,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = spawns,
		})
	end
	spawns.Parent = model

	-- 결승선 (표시용, 판정은 start의 위치 판정)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.WIDTH, 0.4, 1),
		CFrame = at(0, 0.2, Layout.finishLineZ()),
		Color = toColor3(COLORS.finish),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	-- 아트: 장식은 충돌·쿼리·터치 없음, 손으로 짠 소개 카메라, 사용자 Studio 아트 자리
	for _, part in MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model)) do
		if part.Name == Art.LAMP then
			local light = Instance.new("PointLight")
			light.Color = part.Color -- 파츠 색(LAMP_COLORS 순환)과 맞춘 조명 색
			light.Brightness = 2
			light.Range = 18
			light.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

-- 바운스: HumanoidRootPart 아래로 짧게 레이캐스트해 BounceFloor에 닿았는지 보고, 쿨다운이 끝났으면
-- 위로만 튕겨요(수평 성분 없음). LinearVelocity를 BOUNCE_HOLD초 강제로 걸고 그다음은 포물선.
local function bounceStepper(ctx: MapTypes.RoundContext): (racers: { Player }) -> ()
	local CollectionService = game:GetService("CollectionService")
	local tagged: { Instance } = {}
	for _, instance in CollectionService:GetTagged(BOUNCE_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(tagged, instance)
		end
	end

	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = tagged
	local down = Vector3.new(0, -Layout.BOUNCE_RAYCAST_LENGTH, 0)
	local upVelocity = Vector3.new(0, Layout.BOUNCE_UP_SPEED, 0)

	local readyAt: { [Player]: number } = {}

	local function launch(root: BasePart)
		local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if attachment == nil then
			local created = Instance.new("Attachment")
			created.Name = "BounceAttachment"
			created.Parent = root
			ctx.cleanup:add(created)
			attachment = created
		end
		local push = Instance.new("LinearVelocity")
		push.Name = "BounceLaunch"
		push.Attachment0 = attachment :: Attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		push.VectorVelocity = upVelocity
		push.MaxForce = math.huge
		push.Parent = root
		root.AssemblyLinearVelocity = upVelocity
		ctx.cleanup:add(push)
		ctx.cleanup:add(task.delay(Layout.BOUNCE_HOLD, function()
			push:Destroy()
		end))
	end

	return function(racers: { Player })
		local now = os.clock()
		for _, player in racers do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") then
				continue
			end
			local nextReady = readyAt[player]
			if nextReady ~= nil and now < nextReady then
				continue
			end
			local hit = workspace:Raycast(root.Position, down, probeParams)
			if hit and hit.Instance:IsA("BasePart") then
				readyAt[player] = now + Layout.BOUNCE_COOLDOWN
				MoveExempt.mark(character, Layout.BOUNCE_EXEMPT)
				launch(root)
				MapSfx.play(root, "BounceBoing")
			end
		end
	end
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local finishProgress = -Layout.finishLineZ()

	local stepBounce = bounceStepper(ctx)

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local relative = origin:PointToObjectSpace(root.Position)
				if -relative.Z >= finishProgress then
					ctx.pass(player)
				elseif relative.Y < Logic.fallLineAt(relative.Z) then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					return -- 이 통과/탈락으로 라운드가 끝났어요
				end
			end
		end

		-- 판정이 끝난 뒤 남은 레이서에게만 바운스를 적용해요
		stepBounce(ctx.getRacers())
	end))
end

local BouncyCastleMaze: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "방방 미로",
	rule = "말랑한 바닥 위를 튕기며 미로를 빠져나가요.",
	build = build,
	start = start,
}

return BouncyCastleMaze
