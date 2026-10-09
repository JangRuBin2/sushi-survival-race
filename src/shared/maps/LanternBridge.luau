--!strict
-- Race 맵 "등불 다리 건너기" (m5-15). m5-13 껍데기: 회색 바닥 + 스폰 24개 + 결승선.
-- 원안(docs/proposals/map-expansion-and-quality.md §3-5번): 흔들리는 외나무다리, 몰린 인원이 많을수록 더 흔들림.
-- 실제 코스(흔들리는 다리, 종이 등불)는 m5-15가 이 파일을 덮어써요.
-- id·kind·displayName·rule은 GDD §5.3(v0.6)에서 확정이에요 (바꾸려면 m5-15 결정 기록에, GDD도 같이).
-- inPool = false: 랜덤 판에 안 나오고 Config.DEBUG.forceMapPlan으로만 돌아요. 맵이 끝나면 이 줄만 지워요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local MapTypes = require(script.Parent.MapTypes)

local ID = "lantern-bridge"
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
	displayName = "등불 다리 건너기",
	rule = "흔들리는 다리와 종이 등불 사이를 건너요.",
	inPool = false, -- m5-15가 끝나면 이 줄만 지워요
	build = build,
	start = start,
}

return map
