--!strict
-- 맵 조명 분위기 (m5-23). Lighting은 전역 하나라 서버는 로비 조명만 두고(LobbyService), 이 컨트롤러가
-- 카메라가 들어가 있는 아레나의 맵 조명으로 **클라이언트에서만** 바꿔요(클라이언트의 Lighting 변경은 복제되지 않아서
-- 한 플레이스 모드의 여러 방이 서로 안 섞여요). 아레나를 나오면 로비 조명으로 되돌려요.
--   아레나 = MapDecorTags.Arena 태그가 달린 라운드 맵 Model (RoundService가 달아요) + 속성 Attributes.MapId
--   판단은 순수 MapLightingLogic.pickArena(카메라 위치, 아레나 경계 상자들, 지금 아레나) — 0.25초마다
--   전환은 MapLightingLogic.BLEND_SECONDS 동안 MapLighting.lerp. 관전·소개·연출 카메라도 카메라 위치라 자동으로 따라가요.
-- 효과 인스턴스(Atmosphere·ColorCorrection·Bloom·SunRays)는 서버가 만든 게 있으면 그걸 고치고, 없으면 하나만 만들어요.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local MapDecorTags = require(ReplicatedStorage.Shared.maps.MapDecorTags)
local MapLighting = require(ReplicatedStorage.Shared.maps.MapLighting)
local MapLightingLogic = require(ReplicatedStorage.Shared.maps.MapLightingLogic)
local Maps = require(ReplicatedStorage.Shared.maps)

local MapLightingController = {}

type ArenaEntry = { key: string, model: Model, center: Vector3, size: Vector3, mapId: string }

local arenas: { [Model]: ArenaEntry } = {}
local nextKey = 0

local applied: MapLighting.Resolved = MapLighting.LOBBY
local blendFrom: MapLighting.Resolved = MapLighting.LOBBY
local blendTo: MapLighting.Resolved = MapLighting.LOBBY
local blendStart = 0
local blending = false
local currentKey: string? = nil

local function color(c: MapLighting.RGB): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

-- 서버 효과가 늦게 복제되면 클라이언트가 먼저 만든 것을 지워서 클래스마다 하나만 남겨요 (QA B3)
local localCreated: { [string]: Instance } = {}

-- 같은 클래스 효과는 하나만 (서버가 만든 Lobby* 이름을 먼저 찾아요)
local function effect(className: string, preferred: string): Instance
	local named = Lighting:FindFirstChild(preferred)
	if named and named:IsA(className) then
		return named
	end
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = preferred
	created.Parent = Lighting
	localCreated[className] = created
	return created
end

local function apply(preset: MapLighting.Resolved)
	applied = preset
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = color(preset.Ambient)
	Lighting.OutdoorAmbient = color(preset.OutdoorAmbient)
	Lighting.EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = preset.EnvironmentSpecularScale
	Lighting.ShadowSoftness = preset.ShadowSoftness
	Lighting.ExposureCompensation = preset.ExposureCompensation
	Lighting.GeographicLatitude = preset.GeographicLatitude

	local atmosphere = effect("Atmosphere", "LobbyAtmosphere") :: Atmosphere
	atmosphere.Density = preset.Atmosphere.Density
	atmosphere.Offset = preset.Atmosphere.Offset
	atmosphere.Color = color(preset.Atmosphere.Color)
	atmosphere.Decay = color(preset.Atmosphere.Decay)
	atmosphere.Glare = preset.Atmosphere.Glare
	atmosphere.Haze = preset.Atmosphere.Haze

	local grading = effect("ColorCorrectionEffect", "LobbyColorCorrection") :: ColorCorrectionEffect
	grading.Brightness = preset.ColorCorrection.Brightness
	grading.Contrast = preset.ColorCorrection.Contrast
	grading.Saturation = preset.ColorCorrection.Saturation
	grading.TintColor = color(preset.ColorCorrection.TintColor)

	local bloom = effect("BloomEffect", "LobbyBloom") :: BloomEffect
	bloom.Intensity = preset.Bloom.Intensity
	bloom.Size = preset.Bloom.Size
	bloom.Threshold = preset.Bloom.Threshold

	local rays = effect("SunRaysEffect", "MapSunRays") :: SunRaysEffect
	rays.Intensity = preset.SunRays.Intensity
	rays.Spread = preset.SunRays.Spread
end

local function presetFor(mapId: string): MapLighting.Resolved
	local ok, map = pcall(Maps.get, mapId)
	return if ok and map.lighting then MapLighting.resolve(map.lighting) else MapLighting.LOBBY
end

-- 판정 파츠(Decor·IntroCamera 밖)의 경계 상자
local function measure(model: Model): (Vector3?, Vector3?)
	local minV: Vector3? = nil
	local maxV: Vector3? = nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local parent = d.Parent
		local skip = false
		local introPoint = false
		while parent and parent ~= model do
			if parent.Name == "Decor" then
				skip = true
				break
			elseif parent.Name == "IntroCamera" then
				introPoint = true -- 소개 경유점은 크기 없이 점으로 (QA B2: 소개 첫 컷부터 맵 조명)
			end
			parent = parent.Parent
		end
		if skip then
			continue
		end
		local half = if introPoint then 0 else d.Size.Magnitude / 2
		local p = d.Position
		local lo = p - Vector3.new(half, half, half)
		local hi = p + Vector3.new(half, half, half)
		minV = if minV then minV:Min(lo) else lo
		maxV = if maxV then maxV:Max(hi) else hi
	end
	if minV and maxV then
		return (minV + maxV) / 2, maxV - minV
	end
	return nil, nil
end

local function addArena(inst: Instance)
	if not inst:IsA("Model") or arenas[inst] then
		return
	end
	local model = inst
	-- 자식이 다 복제될 시간을 조금 줘요
	task.delay(0.5, function()
		if model.Parent == nil then
			return
		end
		local center, size = measure(model)
		local mapId = model:GetAttribute(Attributes.MapId)
		if center == nil or size == nil or type(mapId) ~= "string" then
			return
		end
		nextKey += 1
		arenas[model] = { key = `arena{nextKey}`, model = model, center = center, size = size, mapId = mapId }
	end)
end

local function toVec(v: Vector3): MapLightingLogic.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function poll()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local list: { MapLightingLogic.Arena } = {}
	local byKey: { [string]: ArenaEntry } = {}
	for model, entry in arenas do
		if model.Parent == nil then
			arenas[model] = nil
			continue
		end
		table.insert(list, { key = entry.key, center = toVec(entry.center), size = toVec(entry.size) })
		byKey[entry.key] = entry
	end
	local key = MapLightingLogic.pickArena(toVec(camera.CFrame.Position), list, currentKey)
	if key == currentKey then
		return
	end
	currentKey = key
	local entry = if key then byKey[key] else nil
	blendFrom = applied
	blendTo = if entry then presetFor(entry.mapId) else MapLighting.LOBBY
	blendStart = os.clock()
	blending = true
end

function MapLightingController.start(_gui: Instance)
	Lighting.ChildAdded:Connect(function(child: Instance)
		for className, mine in localCreated do
			if child ~= mine and child:IsA(className) then
				localCreated[className] = nil
				mine:Destroy()
				apply(applied)
				return
			end
		end
	end)
	apply(MapLighting.LOBBY)
	for _, inst in CollectionService:GetTagged(MapDecorTags.Arena) do
		addArena(inst)
	end
	CollectionService:GetInstanceAddedSignal(MapDecorTags.Arena):Connect(addArena)
	CollectionService:GetInstanceRemovedSignal(MapDecorTags.Arena):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			arenas[inst] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MapLightingLogic.POLL_SECONDS)
			poll()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not blending then
			return
		end
		local alpha = MapLightingLogic.blendAlpha(os.clock() - blendStart)
		apply(MapLighting.lerp(blendFrom, blendTo, alpha))
		if alpha >= 1 then
			blending = false
		end
	end)
end

return MapLightingController
