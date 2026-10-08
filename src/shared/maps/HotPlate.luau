--!strict
-- Survival 맵 "뜨거운 철판" (GDD 5.2 ⑤, m2-03).
-- 같은 크기의 철판 층 3개를 위아래로 쌓아요. 레이서가 올라선 타일은 1.5초에 걸쳐 회색 → 주황 → 빨강으로
-- 달아오르다가 사라져요(내려와도 멈추지 않고, 다시 생기지 않아요). 맨 아래층보다 15 studs 아래로
-- 떨어지면 탈락. 결승선은 없고 통과자는 RoundService가 정해요 (남은 인원 ≤ 목표 또는 시간 종료).
-- 타일에는 CollectionService 태그 "HotTile"을 달고, start에서 ctx.model 하위의 태그 파츠만 동작시켜요
-- (M1 B10 (A)). 달아오름 상태는 start 안의 지역 변수에 둬서 여러 방이 같은 맵을 동시에 돌려도 섞이지 않아요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

-- 아트(m4-03): 장식은 HotPlateArt(순수 데이터) → MapKit.buildDecor로 Decor 폴더에 만들어요 (충돌·쿼리·터치 없음).
-- 타일 크기·위치·층·탈락 높이·달아오름 시간은 그대로이고, 색·재질만 바뀌어요.

local Art = require(script.Parent.HotPlateArt)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local Logic = require(script.Parent.HotPlateLogic)

local ID = "hot-plate"
local TAG = "HotTile"

-- 발밑 판정: HumanoidRootPart 중심과 앞뒤좌우로 조금 벌린 곳에서 아래로 짧게 레이캐스트해요.
-- 루트 중심에서 발바닥까지 약 3 studs라 PROBE_LENGTH는 "서 있을 때만" 닿는 길이예요 (점프 중엔 안 닿음).
local PROBE_LENGTH = 4.5
local PROBE_SPREAD = 0.9
-- (x, z) 쌍. Vector3는 Roblox 타입이라 start 안에서 만들어요 (모듈 최상위에서 Roblox API 금지).
local PROBE_OFFSETS_XZ = {
	{ 0, 0 },
	{ PROBE_SPREAD, 0 },
	{ -PROBE_SPREAD, 0 },
	{ 0, PROBE_SPREAD },
	{ 0, -PROBE_SPREAD },
}
-- 색은 이 간격(초)마다만 바꿔서 매 프레임 복제를 줄여요.
local COLOR_STEP = 0.1

local function toColor3(rgb: Logic.RGB): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

-- 장식·김·후드 조명·소개 카메라·Studio 아트 (판정과 무관)
local function buildArt(model: Model, origin: CFrame)
	local decor = MapKit.decorFolder(model)
	for _, part in MapKit.buildDecor(Art.decor(), origin, decor) do
		part.CastShadow = false -- QA B4: 큰 장식(후드·벽) 그림자가 철판 경고 색을 가리지 않게
		if part.Name == Art.STEAM_VENT then
			local steam = Instance.new("ParticleEmitter")
			steam.Name = "Steam"
			steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
			steam.LightEmission = 0
			steam.Rate = 3
			steam.Lifetime = NumberRange.new(2, 3)
			steam.Speed = NumberRange.new(3, 5)
			steam.SpreadAngle = Vector2.new(15, 15)
			steam.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.5),
				NumberSequenceKeypoint.new(1, 6),
			})
			steam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			steam.EmissionDirection = Enum.NormalId.Top
			steam.Parent = part
		elseif part.Name == Art.HOOD_LAMP then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 226, 180)
			light.Brightness = 1
			light.Range = 40
			light.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	local centerZ = Logic.centerZ()
	local tileSize = Logic.TILE_SIZE
	local thickness = Logic.TILE_THICKNESS
	local coldColor = toColor3(Logic.COLOR_COLD)

	for layerIndex = 1, Logic.LAYER_COUNT do
		local layer = Instance.new("Folder")
		layer.Name = `Layer{layerIndex}` -- Layer1이 맨 위층
		local topY = Logic.layerTopY(layerIndex)
		for i, offset in Logic.tileOffsets() do
			local tile = Instance.new("Part")
			tile.Name = string.format("Tile%02d", i)
			tile.Anchored = true
			tile.CanCollide = true
			tile.CanTouch = false
			tile.Size = Vector3.new(tileSize, thickness, tileSize)
			tile.CFrame = origin * CFrame.new(offset.x, topY - thickness / 2, centerZ + offset.z)
			tile.Color = coldColor
			tile.Material = Enum.Material.DiamondPlate
			-- 달아오를 때 Neon으로 바꿔도 마찰·밀도가 그대로이게 물성을 고정해요
			tile.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.DiamondPlate)
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.BottomSurface = Enum.SurfaceType.Smooth
			tile:SetAttribute("Layer", layerIndex)
			CollectionService:AddTag(tile, TAG)
			tile.Parent = layer
		end
		layer.Parent = model
	end

	-- 스폰 24개: 맨 위층 위에 고르게 흩어진 표시용 파츠 (RoundService가 3 studs 띄워서 배치해요)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Logic.spawnOffsets() do
		local spawn = Instance.new("Part")
		spawn.Name = string.format("Spawn%02d", i)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.CanTouch = false
		spawn.CanQuery = false
		spawn.Size = Vector3.new(2, 0.2, 2)
		spawn.CFrame = origin * CFrame.new(offset.x, Logic.layerTopY(1) + 0.1, centerZ + offset.z)
		spawn.Color = Color3.fromRGB(246, 196, 70)
		spawn.Transparency = 0.4
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Parent = spawns
	end
	spawns.Parent = model

	buildArt(model, origin)
	return model
end

local function start(ctx: MapTypes.RoundContext)
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")

	local origin = ctx.origin
	local eliminationY = Logic.eliminationY()

	-- 이 방 Model 안의 HotTile만 (다른 방의 같은 맵 타일은 건드리지 않아요)
	local tiles: { Instance } = {}
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("BasePart") and ctx.model:IsAncestorOf(part) then
			table.insert(tiles, part)
		end
	end

	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = tiles

	local probeOffsets: { Vector3 } = {}
	for _, xz in PROBE_OFFSETS_XZ do
		table.insert(probeOffsets, Vector3.new(xz[1], 0, xz[2]))
	end
	local down = Vector3.new(0, -PROBE_LENGTH, 0)

	local heatStart: { [BasePart]: number } = {} -- 달아오르는 중인 타일 → 처음 밟힌 시각
	local colorStep: { [BasePart]: number } = {} -- 마지막으로 칠한 색 단계
	local gone: { [BasePart]: boolean } = {}

	local function startHeating(tile: BasePart, now: number)
		if heatStart[tile] == nil and not gone[tile] then
			heatStart[tile] = now -- 두 번 밟아도 리셋되지 않아요 (처음 밟힌 시각 기준)
			MapSfx.play(tile, "HotTileSizzle")
		end
	end

	local function vanish(tile: BasePart)
		gone[tile] = true
		heatStart[tile] = nil
		colorStep[tile] = nil
		tile.Transparency = 1
		tile.CanCollide = false
		tile.CanQuery = false -- 발밑 레이캐스트에서도 빠져요
		MapSfx.play(tile, "TileVanish")
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		local now = os.clock()

		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if origin:PointToObjectSpace(root.Position).Y < eliminationY then
					ctx.eliminate(player)
					if not ctx.isActive() then
						return -- 이 탈락으로 라운드가 끝났어요
					end
					continue
				end
				for _, offset in probeOffsets do
					local hit = workspace:Raycast(root.Position + offset, down, probeParams)
					if hit and hit.Instance:IsA("BasePart") then
						startHeating(hit.Instance, now)
					end
				end
			end
		end

		for tile, startedAt in heatStart do
			local color, isGone = Logic.heatVisual(now - startedAt)
			if isGone then
				vanish(tile)
			else
				local step = math.floor((now - startedAt) / COLOR_STEP)
				if colorStep[tile] ~= step then
					colorStep[tile] = step
					tile.Color = toColor3(color)
					if Art.isGlowing(now - startedAt) and tile.Material ~= Enum.Material.Neon then
						tile.Material = Enum.Material.Neon -- 마지막 단계는 은은하게 빛나요 (물성은 build에서 고정)
					end
				end
			end
		end
	end))
end

local HotPlate: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "뜨거운 철판",
	rule = "밟은 철판은 곧 사라져요. 계속 움직여서 끝까지 버티세요!",
	build = build,
	start = start,
}

return HotPlate
