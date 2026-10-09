--!strict
-- Final 맵 "인형뽑기 기계 속" (m5-19). m5-13 껍데기: 회색 접시 + 스폰 24개, 떨어지면 탈락.
-- 원안(docs/proposals/map-expansion-and-quality.md §3-14번): 집게가 판정 지오메트리를 직접 들어 옮김.
-- 연장전(overtime)이 오면 collapseDuration초 뒤에 접시를 한 번에 없애요 (충돌 끔 + 투명).
-- 실제 맵(유리 상자, 집게가 바닥을 들어 올림)은 m5-19가 이 파일을 덮어써요.
-- id·kind·displayName·rule은 GDD §5.3(v0.6)에서 확정이에요 (바꾸려면 m5-19 결정 기록에, GDD도 같이).
-- inPool = false: 랜덤 판에 안 나오고 Config.DEBUG.forceMapPlan으로만 돌아요. 맵이 끝나면 이 줄만 지워요.
-- Roblox API는 build/start/overtime 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local MapTypes = require(script.Parent.MapTypes)

local ID = "claw-machine-prize"
local SIZE = 60 -- 정사각 접시 한 변
local THICKNESS = 2
local CENTER_Z = -40 -- 접시 중심 (origin 앞쪽)
local FALL_DEPTH = 25 -- origin 아래로 이만큼 떨어지면 탈락
local SPAWN_COLUMNS = 6
local SPAWN_SPACING = 6

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

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	part({
		Name = "Plate",
		Size = Vector3.new(SIZE, THICKNESS, SIZE),
		CFrame = origin * CFrame.new(0, -THICKNESS / 2, CENTER_Z),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	local rows = 24 // SPAWN_COLUMNS
	for i = 1, 24 do
		local column = (i - 1) % SPAWN_COLUMNS
		local row = (i - 1) // SPAWN_COLUMNS
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(
				(column - (SPAWN_COLUMNS - 1) / 2) * SPAWN_SPACING,
				0.1,
				CENTER_Z + (row - (rows - 1) / 2) * SPAWN_SPACING
			),
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	return model
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and origin:PointToObjectSpace(root.Position).Y < -FALL_DEPTH then
				ctx.eliminate(player)
			end
		end
	end))
end

-- 껍데기 연장전: collapseDuration초 뒤 접시를 한 번에 없애요. 기다리는 건 task.delay 스레드(ctx.cleanup)라 훅은 바로 돌아와요.
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	ctx.cleanup:add(task.delay(info.collapseDuration, function()
		if not ctx.isActive() then
			return
		end
		local plate = ctx.model:FindFirstChild("Plate")
		if plate and plate:IsA("BasePart") then
			plate.CanCollide = false
			plate.Transparency = 1
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "인형뽑기 기계 속",
	rule = "집게가 훑고 지나가는 유리 상자 안에서 버텨요.",
	inPool = false, -- m5-19가 끝나면 이 줄만 지워요
	build = build,
	start = start,
	overtime = overtime,
}

return map
