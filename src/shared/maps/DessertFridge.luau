--!strict
-- Race 맵 "디저트 냉장고" (m5-06). m5-03 껍데기: 회색 바닥 + 스폰 24개 + 결승선.
-- 실제 코스(미끄러운 얼음, 젤리 튕김, 송풍구)는 m5-06이 이 파일을 덮어써요.
-- id·kind·displayName·rule은 m5-03에서 확정이에요 (바꾸려면 m5-06 결정 기록에).
-- inPool = false: 랜덤 판에 안 나오고 Config.DEBUG.forceMapPlan으로만 돌아요. 맵이 끝나면 그 줄만 지워요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local MapTypes = require(script.Parent.MapTypes)

local ID = "dessert-fridge"
local LENGTH = 160 -- 출발선(로컬 z = 0)부터 결승선까지
local WIDTH = 40
local THICKNESS = 2
local FALL_DEPTH = 25 -- origin 아래로 이만큼 떨어지면 탈락
local SPAWN_COLUMNS = 6
local SPAWN_SPACING = 5

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
		Size = Vector3.new(WIDTH, THICKNESS, LENGTH + 20),
		CFrame = origin * CFrame.new(0, -THICKNESS / 2, -(LENGTH + 20) / 2 + 10),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i = 1, 24 do
		local column = (i - 1) % SPAWN_COLUMNS
		local row = (i - 1) // SPAWN_COLUMNS
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new((column - (SPAWN_COLUMNS - 1) / 2) * SPAWN_SPACING, 0.1, row * SPAWN_SPACING),
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	part({
		Name = "FinishLine",
		Size = Vector3.new(WIDTH, 0.4, 1),
		CFrame = origin * CFrame.new(0, 0.2, -LENGTH),
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

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
			if root and root:IsA("BasePart") then
				local relative = origin:PointToObjectSpace(root.Position)
				if -relative.Z >= LENGTH then
					ctx.pass(player)
					if not ctx.isActive() then
						break
					end
				elseif relative.Y < -FALL_DEPTH then
					ctx.eliminate(player)
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
	inPool = false, -- m5-06이 끝나면 이 줄만 지워요
	build = build,
	start = start,
}

return map
