--!strict
-- Survival 맵 "튀김 냄비 탈출" (m5-05). m5-03 껍데기: 회색 바닥 + 스폰 24개, 떨어지면 탈락.
-- 실제 맵(차오르는 기름, 튀김 발판, 튀는 기름)은 m5-05가 이 파일을 덮어써요.
-- id·kind·displayName·rule은 m5-03에서 확정이에요 (바꾸려면 m5-05 결정 기록에).
-- inPool = false: 랜덤 판에 안 나오고 Config.DEBUG.forceMapPlan으로만 돌아요. 맵이 끝나면 그 줄만 지워요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local MapTypes = require(script.Parent.MapTypes)

local ID = "tempura-pot"
local SIZE = 60 -- 정사각 바닥 한 변
local THICKNESS = 2
local CENTER_Z = -40 -- 바닥 중심 (origin 앞쪽)
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
		Name = "Floor",
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

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "튀김 냄비 탈출",
	rule = "차오르는 기름을 피해 위로! 튀는 기름도 조심!",
	inPool = false, -- m5-05가 끝나면 이 줄만 지워요
	build = build,
	start = start,
}

return map
