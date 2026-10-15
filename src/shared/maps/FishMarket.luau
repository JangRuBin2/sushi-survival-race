--!strict
-- Survival 맵 "수산시장" (m5-37). m5-33 껍데기: 회색 접시 + 스폰 24개, 떨어지면 탈락.
-- 콘셉트(GDD §5.3 3차 배치, 사용자 콘셉트 시트): 떨어지는 생선, 밀려오는 얼음 블록, 나무 상자.
-- m5-33 껍데기 → m5-37가 이 파일을 덮어써요 (실제 지형·장애물·아트).
-- id·kind·displayName·rule은 GDD §5.3(v0.7)에서 확정이에요 (바꾸려면 m5-37 결정 기록에, GDD도 같이).
-- inPool = false: 랜덤 판에 안 나오고 Config.DEBUG.forceMapPlan으로만 돌아요. 맵이 끝나면 이 줄만 지워요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.FishMarketArt)
local MapKit = require(script.Parent.MapKit)
local MapTypes = require(script.Parent.MapTypes)

local ID = "fish-market"
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

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
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
	displayName = "수산시장",
	rule = "떨어지는 생선과 밀려오는 얼음을 피해 상자 위에서 버텨요!",
	inPool = false, -- m5-37가 끝나면 이 줄만 지워요
	build = build,
	start = start,
	lighting = Art.LIGHTING,
}

return map
