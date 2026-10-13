--!strict
-- 맵 키트 (m4-01): 맵 아트(m4-02~05)와 로비(m4-06)가 같이 쓰는 Roblox 쪽 도구.
-- REFERENCE-map-production §5 "그레이박스 → 아트 교체" 순서를 코드로 옮겼어요:
--   판정·충돌 지오메트리는 맵 build가 그대로 만들고, 장식은 전부 여기서 "충돌·쿼리·터치 없음"으로 덧붙여요.
--   그래서 장식을 아무리 바꿔도 게임 판정(낙하, 결승선, 발밑 레이캐스트)은 달라지지 않아요.
--
--   MapKit.decorFolder(model) -> Folder        맵 Model 아래 "Decor" 폴더 (없으면 만들어요)
--   MapKit.buildDecor(specs, origin, parent)   DecorSpec 목록(MapKitLogic)을 파츠로 만들어 parent에 넣어요
--   MapKit.introCamera(model, points, origin)  "IntroCamera" 폴더에 01, 02, … 투명 앵커 파츠 (m3-04 규칙)
--   MapKit.attachStudioArt(model, mapId, origin)  ServerStorage.MapArt[mapId]가 있으면 Decor/StudioArt로 복제
--   MapKit.applyDecorRules(part)               파츠 하나를 장식 규칙으로 (Anchored, 충돌·쿼리·터치 없음)
--   MapKit.makeEmitter(preset, rate?) -> ParticleEmitter   MapFxPresets 프리셋 (m5-23)
--   MapKit.makeLight(lightSpec) -> Light                  DecorSpec.light 모양 (m5-23)
-- Roblox API는 함수 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local MapDecorTags = require(script.Parent.MapDecorTags)
local MapFxPresets = require(script.Parent.MapFxPresets)
local MapKitLogic = require(script.Parent.MapKitLogic)

local MapKit = {}

local DECOR_FOLDER = "Decor"
local INTRO_FOLDER = "IntroCamera"
local STUDIO_ART = "StudioArt"
local MAP_ART_FOLDER = "MapArt"

local function toVector3(v: MapKitLogic.Vec3): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

-- 장식 파츠 규칙: 게임 판정·충돌에 절대 영향이 없게 해요.
function MapKit.applyDecorRules(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

function MapKit.decorFolder(model: Instance): Folder
	local existing = model:FindFirstChild(DECOR_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = DECOR_FOLDER
	folder.Parent = model
	return folder
end

local function materialOf(name: string): Enum.Material
	local ok, material = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and material then
		return material
	end
	return Enum.Material.SmoothPlastic
end

local function enumItem(enum: any, name: string?, fallback: string): any
	local ok, item = pcall(function()
		return enum[name or fallback]
	end)
	if ok and item then
		return item
	end
	return enum[fallback]
end

local function keypoints(list: { MapFxPresets.Key }): NumberSequence
	local points = {}
	for _, key in list do
		table.insert(points, NumberSequenceKeypoint.new(key.t, key.v))
	end
	if #points == 1 then
		return NumberSequence.new(points[1].Value)
	end
	return NumberSequence.new(points)
end

-- MapFxPresets 프리셋으로 ParticleEmitter를 만들어요 (부모는 부르는 쪽이 정해요). rate가 있으면 Rate를 덮어써요.
function MapKit.makeEmitter(presetName: string, rate: number?): ParticleEmitter
	local preset = assert(MapFxPresets.PRESETS[presetName], `unknown particle preset {presetName}`)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = presetName
	emitter.Texture = preset.Texture
	emitter.Rate = rate or preset.Rate
	emitter.Lifetime = NumberRange.new(preset.Lifetime[1], preset.Lifetime[2])
	emitter.Speed = NumberRange.new(preset.Speed[1], preset.Speed[2])
	emitter.SpreadAngle = Vector2.new(preset.SpreadAngle[1], preset.SpreadAngle[2])
	emitter.Size = keypoints(preset.Size)
	emitter.Transparency = keypoints(preset.Transparency)
	local colors = {}
	for _, key in preset.Color do
		table.insert(colors, ColorSequenceKeypoint.new(key.t, Color3.fromRGB(key.c.r, key.c.g, key.c.b)))
	end
	if #colors == 1 then
		emitter.Color = ColorSequence.new(colors[1].Value)
	else
		emitter.Color = ColorSequence.new(colors)
	end
	emitter.LightEmission = preset.LightEmission
	emitter.LightInfluence = preset.LightInfluence
	emitter.Acceleration = Vector3.new(preset.Acceleration[1], preset.Acceleration[2], preset.Acceleration[3])
	emitter.Drag = preset.Drag
	emitter.Rotation = NumberRange.new(preset.Rotation[1], preset.Rotation[2])
	emitter.RotSpeed = NumberRange.new(preset.RotSpeed[1], preset.RotSpeed[2])
	emitter.EmissionDirection = enumItem(Enum.NormalId, preset.EmissionDirection, "Top")
	return emitter
end

-- LightSpec으로 PointLight/SpotLight/SurfaceLight를 만들어요 (부모는 부르는 쪽이 정해요).
function MapKit.makeLight(spec: MapKitLogic.LightSpec): Light
	local light: Light
	if spec.kind == "Spot" then
		local spot = Instance.new("SpotLight")
		spot.Angle = spec.angle or 90
		spot.Face = enumItem(Enum.NormalId, spec.face, "Front")
		light = spot
	elseif spec.kind == "Surface" then
		local surface = Instance.new("SurfaceLight")
		surface.Angle = spec.angle or 90
		surface.Face = enumItem(Enum.NormalId, spec.face, "Front")
		light = surface
	else
		light = Instance.new("PointLight")
	end
	light.Color = Color3.fromRGB(spec.color.r, spec.color.g, spec.color.b)
	light.Brightness = spec.brightness
	light.Shadows = spec.shadows == true
	(light :: any).Range = spec.range
	return light
end

-- 장식을 만들어요. 목록이 MapKitLogic.validate를 통과하지 못하면 경고하고 아무것도 만들지 않아요
-- (장식 때문에 라운드가 깨지지 않게). 만든 파츠 목록을 돌려줘요.
-- m5-23: CornerWedge, reflectance, castShadow(nil이면 작은 소품은 끔), light, particle, anim(태그·속성만 — 움직임은 클라이언트)
function MapKit.buildDecor(specs: { MapKitLogic.DecorSpec }, origin: CFrame, parent: Instance): { BasePart }
	local problem = MapKitLogic.validate(specs)
	if problem then
		warn(`[MapKit] decor skipped: {problem}`)
		return {}
	end
	local over = MapKitLogic.checkBudget(specs, "Extended")
	if over then
		warn(`[MapKit] decor over budget: {over}`)
	end
	local CollectionService = game:GetService("CollectionService")
	local parts: { BasePart } = {}
	for _, spec in specs do
		local part: BasePart
		if spec.shape == "Wedge" then
			part = Instance.new("WedgePart")
		elseif spec.shape == "CornerWedge" then
			part = Instance.new("CornerWedgePart")
		else
			local block = Instance.new("Part")
			if spec.shape == "Ball" then
				block.Shape = Enum.PartType.Ball
			elseif spec.shape == "Cylinder" then
				block.Shape = Enum.PartType.Cylinder
			end
			part = block
		end
		part.Name = spec.name
		part.Size = toVector3(spec.size)
		part.Color = Color3.fromRGB(spec.color.r, spec.color.g, spec.color.b)
		part.Material = materialOf(spec.material)
		part.Transparency = spec.transparency or 0
		part.Reflectance = spec.reflectance or 0
		part.CastShadow = MapKitLogic.resolveCastShadow(spec)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local rotation = spec.rotation
		local placement = CFrame.new(toVector3(spec.offset))
		if rotation then
			placement *= CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
		end
		part.CFrame = origin * placement
		MapKit.applyDecorRules(part)
		if spec.light then
			MapKit.makeLight(spec.light).Parent = part
		end
		if spec.particle then
			MapKit.makeEmitter(spec.particle, spec.particleRate).Parent = part
		end
		local anim = spec.anim
		if anim then
			part:SetAttribute(MapDecorTags.AnimKind, anim.kind)
			part:SetAttribute(MapDecorTags.AnimPeriod, anim.period)
			part:SetAttribute(MapDecorTags.AnimAmount, anim.amount or 0)
			if anim.axis then
				part:SetAttribute(MapDecorTags.AnimAxis, anim.axis)
			end
			CollectionService:AddTag(part, MapDecorTags.Anim)
		end
		part.Parent = parent
		table.insert(parts, part)
	end
	return parts
end

export type IntroPoint = { pos: MapKitLogic.Vec3, lookAt: MapKitLogic.Vec3 }

-- 라운드 소개 카메라 경유점 (m3-04 IntroController가 이름순으로 읽고 앞면 방향을 봐요).
-- pos·lookAt은 origin 기준 로컬 좌표예요. 이미 있는 IntroCamera 폴더는 바꿔요.
function MapKit.introCamera(model: Instance, points: { IntroPoint }, origin: CFrame): Folder
	local old = model:FindFirstChild(INTRO_FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = INTRO_FOLDER
	for i, point in points do
		local pos = origin:PointToWorldSpace(toVector3(point.pos))
		local lookAt = origin:PointToWorldSpace(toVector3(point.lookAt))
		local part = Instance.new("Part")
		part.Name = string.format("%02d", i)
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.CFrame = if (lookAt - pos).Magnitude > 1e-3 then CFrame.lookAt(pos, lookAt) else CFrame.new(pos)
		MapKit.applyDecorRules(part)
		part.Parent = folder
	end
	folder.Parent = model
	return folder
end

-- 사용자가 Studio에서 만든 장식(assets/map-art/<mapId>.rbxm → ServerStorage.MapArt.<mapId>)을 붙여요.
-- 서버가 아니거나 없으면 아무것도 안 해요. 안의 모든 BasePart는 장식 규칙으로 강제해요.
-- Model의 피벗(Pivot)이 맵 origin 자리(출발선 가운데, 앞쪽 = -Z)에 오게 만들어 두면 그대로 맞춰져요.
function MapKit.attachStudioArt(model: Instance, mapId: string, origin: CFrame): Model?
	local RunService = game:GetService("RunService")
	if not RunService:IsServer() then
		return nil
	end
	local ServerStorage = game:GetService("ServerStorage")
	local artFolder = ServerStorage:FindFirstChild(MAP_ART_FOLDER)
	local source = artFolder and artFolder:FindFirstChild(mapId)
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	copy.Name = STUDIO_ART
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			MapKit.applyDecorRules(descendant)
		end
	end
	copy:PivotTo(origin)
	copy.Parent = MapKit.decorFolder(model)
	return copy
end

return MapKit
