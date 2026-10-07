--!strict
-- 아직 실제 코스가 없는 맵의 "동작하는 최소 껍데기"(stub)를 만들어요 (m2-01).
-- 회색 바닥 + Spawns 24개, Race면 결승선과 끝 벽. 판정은 Race 결승선 통과 → ctx.pass,
-- origin보다 FALL_DEPTH 아래로 떨어지면 → ctx.eliminate 뿐이에요.
-- 맵 담당(m2-02~04)이 자기 맵 파일을 실제 맵으로 덮어쓰면 이 모듈은 더 이상 쓰이지 않아요
-- (셋 다 바뀌면 지워도 돼요). Roblox API는 build/start 안에서만 써서 Lune에서 require해도 안전해요.

local Config = require(script.Parent.Parent.Config)
local MapTypes = require(script.Parent.MapTypes)

local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
local FALL_DEPTH = 40 -- origin보다 이만큼 아래로 떨어지면 탈락
local FLOOR_THICKNESS = 2
local WALL_HEIGHT = 8
local SPAWN_COLUMNS = 6

-- Race: 출발 → 결승선까지 곧은 길
local RACE_WIDTH = 20
local RACE_LENGTH = 80
local FINISH_LINE_INSET = 4 -- 결승선을 끝 벽보다 이만큼 앞에 둬요 (넘은 뒤 서 있을 자리)

-- Survival/Final: 벽 없는 정사각형 바닥 (떨어지면 탈락)
local ARENA_SIZE = 40

export type StubInfo = {
	id: string,
	kind: MapTypes.MapKind,
	displayName: string,
	rule: string,
}

local StubMap = {}

local function makePart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function build(info: StubInfo, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = info.id
	local grey = Color3.fromRGB(163, 162, 165)
	local isRace = info.kind == "Race"

	-- 바닥 중심 z (코스는 로컬 -Z로 뻗어요)
	local length = if isRace then RACE_LENGTH else ARENA_SIZE
	local width = if isRace then RACE_WIDTH else ARENA_SIZE
	local centerZ = -length / 2
	makePart(
		model,
		"Floor",
		Vector3.new(width, FLOOR_THICKNESS, length),
		origin * CFrame.new(0, -FLOOR_THICKNESS / 2, centerZ),
		grey
	)

	-- Spawns 24개: Race는 출발 구간에, 생존형은 바닥 가운데에 격자로
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local spacing = if isRace then 3 else 5
	local rows = math.ceil(MAX_PLAYERS / SPAWN_COLUMNS)
	local firstRowZ = if isRace then -2 else centerZ + (rows - 1) * spacing / 2
	for i = 1, MAX_PLAYERS do
		local col = (i - 1) % SPAWN_COLUMNS
		local row = (i - 1) // SPAWN_COLUMNS
		local x = (col - (SPAWN_COLUMNS - 1) / 2) * spacing
		local z = firstRowZ - row * spacing
		local spawn = makePart(
			model,
			string.format("Spawn%02d", i),
			Vector3.new(2, 0.2, 2),
			origin * CFrame.new(x, 0.1, z),
			Color3.fromRGB(246, 196, 70)
		)
		spawn.CanCollide = false
		spawn.Transparency = 0.4
		spawn.Parent = spawns
	end

	if isRace then
		for _, side in { -1, 1 } do
			local wall = makePart(
				model,
				"Wall",
				Vector3.new(0.5, WALL_HEIGHT, length),
				origin * CFrame.new(side * (width / 2 + 0.25), WALL_HEIGHT / 2, centerZ),
				grey
			)
			wall.Transparency = 0.5
		end
		local endWall = makePart(
			model,
			"EndWall",
			Vector3.new(width + 1, WALL_HEIGHT * 2, 0.5),
			origin * CFrame.new(0, WALL_HEIGHT, -length - 0.25),
			grey
		)
		endWall.Transparency = 0.5
		local finishLine = makePart(
			model,
			"FinishLine",
			Vector3.new(width, 0.4, 1),
			origin * CFrame.new(0, 0.2, -length + FINISH_LINE_INSET),
			Color3.fromRGB(255, 196, 40)
		)
		finishLine.CanCollide = false
		finishLine.Material = Enum.Material.Neon
	end

	return model
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin

	-- 결승선(있으면)의 진행 거리. 점프로 넘어도 통과하게 위치(로컬 z)로 판정해요 (M1 B2와 같은 방식).
	local finishProgress = math.huge
	local finishLine = ctx.model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		finishProgress = -origin:PointToObjectSpace(finishLine.Position).Z
	end

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
				elseif root.Position.Y < origin.Position.Y - FALL_DEPTH then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					break
				end
			end
		end
	end))
end

function StubMap.create(info: StubInfo): MapTypes.MapModule
	return {
		id = info.id,
		kind = info.kind,
		displayName = info.displayName,
		rule = info.rule,
		build = function(origin: CFrame): Model
			return build(info, origin)
		end,
		start = start,
	}
end

return StubMap
