--!strict
-- 회전 벨트 Race 맵 (GDD 5.2 ①). 손님 테이블 사이를 도는 컨베이어 벨트를 거슬러 결승선까지 달려요.
-- 구성: 출발 구간 → 벨트 A(뒤로 미는 구간) → 간장 종지 병목 → 벨트 B(젓가락 2개) → 결승.
-- 코스는 origin의 LookVector(로컬 -Z) 방향으로 뻗어요 (MapTypes 약속).
-- 상태(벨트 Heartbeat, 젓가락 사이클, 통과 집합)는 전부 ctx/스레드 안에 둬서 여러 방이 같은 맵을
-- 동시에 돌려도 서로 섞이지 않게 해요. build()는 Workspace에 아직 안 들어간 Model만 돌려줘요.

local Config = require(script.Parent.Parent.Config)
local MapTypes = require(script.Parent.MapTypes)
local Chopstick = require(script.Parent.RotatingBeltChopstick)

local ID = "rotating-belt"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]

-- 코스 치수(studs). 로컬 z: 0이 출발선, 음수로 갈수록 결승에 가까워져요.
local WIDTH_NORMAL = 16
local WIDTH_NARROW = 6
local DEPTH_START = 14
local DEPTH_BELT_A = 34
local DEPTH_NARROW = 24
local DEPTH_BELT_B = 34
local DEPTH_FINISH = 14
local WALL_HEIGHT = 6
local FLOOR_THICKNESS = 2

local PUSH_SPEED = 10 -- 벨트가 선수를 뒤로 미는 최고 속도 (studs/s, GDD: 진행 반대 방향으로 밀어요)
local PUSH_ACCEL = 24 -- 그 속도까지 끌어올리는 가속도 (studs/s^2). 즉시 적용하면 뚝뚝 끊겨 보여서 완만하게.
local VOID_DROP = 40 -- origin보다 이만큼 아래로 떨어지면 탈락 (바깥으로 튕겨나갔을 때의 안전망)
local CHOPSTICK_OFFSETS = { -3, 3 } -- 벨트 B 구간에서 두 젓가락이 자리잡을 좌우 위치 (반대 레인으로 피하게)

-- Instance.new + 속성 적용. Parent는 맨 마지막에 넣어서 복제 이벤트를 줄여요.
local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
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
	local model = Instance.new("Model")
	model.Name = ID

	local function toWorld(localCFrame: CFrame): CFrame
		return origin:ToWorldSpace(localCFrame)
	end

	local function addFloor(
		centerZ: number,
		depth: number,
		width: number,
		color: Color3,
		material: Enum.Material?
	): BasePart
		return makePart({
			Name = "Floor",
			Size = Vector3.new(width, FLOOR_THICKNESS, depth),
			CFrame = toWorld(CFrame.new(0, -FLOOR_THICKNESS / 2, centerZ)),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end

	local function addWalls(centerZ: number, depth: number, width: number)
		for _, side in { -1, 1 } do
			makePart({
				Name = "Wall",
				Size = Vector3.new(0.5, WALL_HEIGHT, depth),
				CFrame = toWorld(CFrame.new(side * (width / 2 + 0.25), WALL_HEIGHT / 2, centerZ)),
				Color = Color3.fromRGB(235, 230, 220),
				Transparency = 0.5,
				Material = Enum.Material.Glass,
				Parent = model,
			})
		end
	end

	-- 코스를 따라가며 구간 하나씩 쌓는다. nextSegment는 그 구간의 중심 z를 돌려주고 커서를 넘긴다.
	local cursor = 0
	local function nextSegment(depth: number): number
		local centerZ = cursor - depth / 2
		cursor -= depth
		return centerZ
	end

	local conveyors = Instance.new("Folder")
	conveyors.Name = "Conveyors"
	conveyors.Parent = model

	local function addConveyorZone(centerZ: number, depth: number, width: number)
		makePart({
			Name = "ConveyorZone",
			Size = Vector3.new(width, 6, depth),
			CFrame = toWorld(CFrame.new(0, 3, centerZ)),
			Transparency = 1,
			CanCollide = false,
			Parent = conveyors,
		})
	end

	-- 출발 구간 + 스폰 (최대 인원만큼, 이름순으로 배치되도록 두 자리 숫자를 써요)
	local startCenter = nextSegment(DEPTH_START)
	addFloor(startCenter, DEPTH_START, WIDTH_NORMAL + 4, Color3.fromRGB(214, 202, 190))
	addWalls(startCenter, DEPTH_START, WIDTH_NORMAL + 4)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local spawnIndex = 0
	for row = 0, 3 do
		for col = 0, 5 do
			spawnIndex += 1
			local x = (col - 2.5) * 4
			local z = startCenter + 2 + row * 4 -- 출발선(z=0)보다 뒤쪽에 줄지어 선다
			makePart({
				Name = string.format("Spawn%02d", spawnIndex),
				Size = Vector3.new(3, 0.2, 3),
				CFrame = toWorld(CFrame.new(x, 0.1, z)),
				Color = Color3.fromRGB(246, 196, 70),
				Transparency = 0.4,
				CanCollide = false,
				Parent = spawns,
			})
		end
	end
	assert(spawnIndex == MAX_PLAYERS, "spawn count must cover the largest room size")

	-- 벨트 A: 진행 반대 방향으로 미는 첫 구간
	local beltACenter = nextSegment(DEPTH_BELT_A)
	addFloor(beltACenter, DEPTH_BELT_A, WIDTH_NORMAL, Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
	addWalls(beltACenter, DEPTH_BELT_A, WIDTH_NORMAL)
	addConveyorZone(beltACenter, DEPTH_BELT_A, WIDTH_NORMAL)

	-- 병목 구간: 간장 종지 더미로 좁아져요 (GDD)
	local narrowCenter = nextSegment(DEPTH_NARROW)
	addFloor(narrowCenter, DEPTH_NARROW, WIDTH_NARROW, Color3.fromRGB(150, 130, 90))
	addWalls(narrowCenter, DEPTH_NARROW, WIDTH_NARROW)
	for _, side in { -1, 1 } do
		for row = 0, 2 do
			makePart({
				Name = "SoyDish",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2, 2, 2),
				CFrame = toWorld(
					CFrame.new(
						side * (WIDTH_NARROW / 2 + 1.5),
						1,
						narrowCenter - DEPTH_NARROW / 3 + row * (DEPTH_NARROW / 3)
					) * CFrame.Angles(0, 0, math.rad(90))
				),
				Color = Color3.fromRGB(90, 60, 40),
				Material = Enum.Material.Plastic,
				Parent = model,
			})
		end
	end

	-- 벨트 B: 다시 넓어지고, 여기서 젓가락 두 개가 레인을 위협해요
	local beltBCenter = nextSegment(DEPTH_BELT_B)
	addFloor(beltBCenter, DEPTH_BELT_B, WIDTH_NORMAL, Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
	addWalls(beltBCenter, DEPTH_BELT_B, WIDTH_NORMAL)
	addConveyorZone(beltBCenter, DEPTH_BELT_B, WIDTH_NORMAL)

	local hazards = Instance.new("Folder")
	hazards.Name = "Hazards"
	hazards.Parent = model
	local nearEdgeZ = beltBCenter + DEPTH_BELT_B / 2 -- 벨트 B에서 출발선에 더 가까운 쪽 끝
	for i, offsetX in CHOPSTICK_OFFSETS do
		local fraction = i / (#CHOPSTICK_OFFSETS + 1)
		local stationZ = nearEdgeZ - fraction * DEPTH_BELT_B
		local station = Chopstick.build(toWorld(CFrame.new(offsetX, 0, stationZ)))
		station.Parent = hazards
	end

	-- 결승
	local finishCenter = nextSegment(DEPTH_FINISH)
	addFloor(finishCenter, DEPTH_FINISH, WIDTH_NORMAL + 4, Color3.fromRGB(214, 202, 190))
	addWalls(finishCenter, DEPTH_FINISH, WIDTH_NORMAL + 4)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(WIDTH_NORMAL + 4, 0.4, 1),
		CFrame = toWorld(CFrame.new(0, 0.2, cursor + 0.5)),
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	return model
end

local function isWithinZone(zone: BasePart, worldPosition: Vector3): boolean
	local half = zone.Size / 2
	local relative = zone.CFrame:PointToObjectSpace(worldPosition)
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function start(ctx: MapTypes.RoundContext)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")

	local origin = ctx.origin
	local model = ctx.model
	local pushDirection = -origin.LookVector -- GDD: 벨트가 진행 반대 방향으로 밀어요

	local conveyorZones: { BasePart } = {}
	local conveyorsFolder = model:FindFirstChild("Conveyors")
	if conveyorsFolder then
		for _, zone in conveyorsFolder:GetChildren() do
			if zone:IsA("BasePart") then
				table.insert(conveyorZones, zone)
			end
		end
	end

	-- 결승선 통과: 서버에서만 판정하고, 플레이어당 한 번만 ctx.pass를 부른다.
	local passed: { [Player]: boolean } = {}
	local finishLine = model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		local finishConn = finishLine.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character :: Model)
			if player and ctx.isActive() and not passed[player] then
				passed[player] = true
				ctx.pass(player)
			end
		end)
		ctx.cleanup:add(finishConn)
	end

	-- 매 프레임: 벨트 구간이면 뒤로 밀고, 코스 밖(아래)으로 떨어졌으면 탈락시킨다 (낙하 판정 안전망).
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if root.Position.Y < origin.Position.Y - VOID_DROP then
					ctx.eliminate(player)
					continue
				end
				for _, zone in conveyorZones do
					if isWithinZone(zone, root.Position) then
						local current = root.AssemblyLinearVelocity
						local along = current:Dot(pushDirection)
						if along < PUSH_SPEED then
							local delta = math.min(PUSH_ACCEL * dt, PUSH_SPEED - along)
							root.AssemblyLinearVelocity = current + pushDirection * delta
						end
						break
					end
				end
			end
		end
	end)
	ctx.cleanup:add(heartbeat)

	-- 젓가락 station마다 독립된 사이클을 돌린다. 스레드는 ctx.cleanup에 넣어서 라운드가 끝나면 같이 멈춘다.
	local hazards = model:FindFirstChild("Hazards")
	if hazards then
		for _, station in hazards:GetChildren() do
			if station:IsA("Model") then
				local thread = task.spawn(function()
					Chopstick.run(station, ctx)
				end)
				ctx.cleanup:add(thread)
			end
		end
	end
end

local RotatingBelt: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "회전 벨트",
	rule = "젓가락을 피해 벨트를 거슬러 결승선까지 달려요",
	build = build,
	start = start,
}

return RotatingBelt
