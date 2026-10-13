--!strict
-- 로비 건물·조명·우승자 단상 (GDD 3.1, 8, m4-06). 배치 숫자는 Shared.LobbyLayout(순수 데이터)에 있어요.
--   init():  조명 프리셋을 Lighting에 한 번 적용 (한 플레이스 모드라 아레나도 같은 조명)
--   start(): Workspace.Lobby를 코드로 지어요 (매치 플레이스면 안 지어요) + 우승자 단상
-- 건물(벽·기둥·카운터·레일·단상)은 충돌 있음, 나머지는 MapKit 장식 규칙(충돌·쿼리·터치 없음).
-- 레일 접시는 서버에서는 멈춰 있고, 클라이언트 LobbyFxController가 로컬로 돌려요 (복제·서버 부하 없음).
-- 단상: MatchEvents.onWinnerShowcase가 올 때마다 가장 최근 우승자 1명으로 바꿔요. 서버는 이름표(BillboardGui)와
-- Podium 폴더 속성(LobbyLayout.WINNER_ATTRS)만 두고, 초밥 인형은 클라이언트 LobbyFxController가 그 속성으로 세워요.
-- 인형·이름은 플레이어가 나가도 남아요. 아무도 없으면 "다음 우승자는 누구?".
-- 시즌 이벤트 장식 (m5-07): 로비를 지은 뒤와 10분마다 진행 중 이벤트(Seasons.current, Studio면 Config.DEBUG.eventNow)를
-- 보고 카운터 주변 장식을 켜고 꺼요. 할로윈: 호박 등 6개·보라 조명 2 / 크리스마스: 작은 트리 2·눈 입자 1·선물 상자 4.
-- 모두 MapKit 장식 규칙(충돌·쿼리·터치 없음), 이벤트마다 파츠 40개 이하 (SEASON_DECOR_BUDGET).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local PlaceService = require(script.Parent.PlaceService)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapKit = require(ReplicatedStorage.Shared.maps.MapKit)
local MapKitLogic = require(ReplicatedStorage.Shared.maps.MapKitLogic)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Seasons = require(ReplicatedStorage.Shared.Seasons)

local LobbyService = {}

local LOBBY_NAME = "Lobby"
local STUDIO_ART_ID = "lobby"

local SEASON_FOLDER = "SeasonDecor"
local SEASON_CHECK_INTERVAL = 600 -- 초 (10분)
local SEASON_DECOR_BUDGET = 40 -- 이벤트 하나당 장식 파츠

local podiumFolder: Folder? = nil
local lobbyModel: Model? = nil
local seasonDecorKind: string? = nil -- 지금 켠 장식 종류 ("halloween" / "christmas" / nil)
local labels: { name: TextLabel, title: TextLabel, wins: TextLabel }? = nil
local showcaseSerial = 0

local function color(c: MapKitLogic.RGB): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

-- 이름으로 하나만 두는 Lighting 효과 (이미 있으면 그걸 써요)
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function applyLighting()
	local preset = LobbyLayout.LIGHTING
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = color(preset.Ambient)
	Lighting.OutdoorAmbient = color(preset.OutdoorAmbient)

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
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- 건물 파츠는 장식으로 만든 뒤 충돌만 되돌려요 (밟고 서고, 막혀요)
local function makeSolid(parts: { BasePart })
	for _, p in parts do
		p.CanCollide = true
		p.CanQuery = true
	end
end

local function addLights(parts: { BasePart })
	local byName: { [string]: BasePart } = {}
	for _, p in parts do
		byName[p.Name] = p
	end
	for _, spec in LobbyLayout.LIGHTS do
		local host = byName[spec.part]
		if host then
			local light = Instance.new("PointLight")
			light.Color = color(spec.color)
			light.Range = spec.range
			light.Brightness = spec.brightness
			light.Shadows = false
			light.Parent = host
		end
	end
end

local function poseCFrame(pose: LobbyLayout.Pose): CFrame
	return CFrame.new(pose.x, pose.y, pose.z) * CFrame.Angles(0, pose.yaw, 0)
end

-- 접시는 t = 0 자리에 멈춰 둬요. 클라이언트가 같은 기준(plateAt(i, 0))으로 상대 위치를 계산해 돌려요.
local function buildPlates(parent: Instance)
	local plates = folder("Plates", parent)
	for i = 1, LobbyLayout.RAIL.plateCount do
		local model = Instance.new("Model")
		model.Name = LobbyLayout.plateName(i)
		local parts = MapKit.buildDecor(LobbyLayout.plateParts(i), poseCFrame(LobbyLayout.plateAt(i, 0)), model)
		for _, p in parts do
			p.CastShadow = false
		end
		model.PrimaryPart = parts[1]
		model.Parent = plates
	end
end

local function makeLabel(name: string, order: number, height: number, textColor: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 12)
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildPodium(parent: Instance)
	local podium = LobbyLayout.PODIUM
	podiumFolder = folder("Podium", parent)

	local anchor = Instance.new("Part")
	anchor.Name = "ShowcaseLabel"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(podium.center.x, podium.labelHeight, podium.center.z)
	MapKit.applyDecorRules(anchor)
	anchor.Parent = podiumFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Showcase"
	billboard.Size = UDim2.fromScale(14, 4.5) -- studs (월드 크기라 멀어지면 작아져요)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Parent = anchor

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = billboard

	labels = {
		name = makeLabel("Name", 1, 0.45, Color3.fromRGB(255, 214, 90), billboard),
		title = makeLabel("Title", 2, 0.3, Color3.fromRGB(255, 255, 255), billboard),
		wins = makeLabel("Wins", 3, 0.25, Color3.fromRGB(255, 236, 210), billboard),
	}
end

local function setLabels(nameText: string, titleText: string?, winsText: string?)
	local l = labels
	if l == nil then
		return
	end
	l.name.Text = nameText
	l.title.Text = titleText or ""
	l.title.Visible = titleText ~= nil
	l.wins.Text = winsText or ""
	l.wins.Visible = winsText ~= nil
end

local function onWinnerShowcase(info: MatchEvents.WinnerShowcaseInfo)
	local parent = podiumFolder
	if parent == nil or parent.Parent == nil then
		return
	end
	-- 가장 최근 1명만: 속성을 바꾸면 클라이언트가 전 인형을 치우고 새로 세워요.
	-- 인형은 클라이언트(LobbyFxController)가 만들어요 — 서버에서 초밥 몸을 만드는 곳은 AppearanceService 하나뿐 (m3-02 규칙).
	showcaseSerial += 1
	parent:SetAttribute(LobbyLayout.WINNER_ATTRS.userId, info.userId)
	parent:SetAttribute(LobbyLayout.WINNER_ATTRS.appearanceId, info.appearanceId)
	parent:SetAttribute(LobbyLayout.WINNER_ATTRS.serial, showcaseSerial)

	-- 칭호·승수는 프로필에서 읽어요 (나간 사람이면 이름만)
	local titleText: string? = nil
	local winsText: string? = nil
	local player = Players:GetPlayerByUserId(info.userId)
	local profile = player and DataService.get(player)
	if profile and profile.wins > 0 then
		titleText = ProfileSchema.titleFor(profile.wins)
		winsText = `{profile.wins}승`
	end
	setLabels(`🏆 {info.name}`, titleText, winsText)
end

---------------------------------------------------------------- 시즌 이벤트 장식 (m5-07)

type SeasonDecor = {
	specs: { MapKitLogic.DecorSpec },
	lights: { { part: string, color: MapKitLogic.RGB } }, -- 이 파츠에 PointLight
	snow: string?, -- 이 파츠에 눈 ParticleEmitter
}

local function rgb(r: number, g: number, b: number): MapKitLogic.RGB
	return { r = r, g = g, b = b }
end

local function vec(x: number, y: number, z: number): MapKitLogic.Vec3
	return { x = x, y = y, z = z }
end

local function deco(
	list: { MapKitLogic.DecorSpec },
	name: string,
	shape: MapKitLogic.Shape,
	size: MapKitLogic.Vec3,
	c: MapKitLogic.RGB,
	material: string,
	offset: MapKitLogic.Vec3,
	extra: { rotation: MapKitLogic.Vec3?, transparency: number? }?
)
	table.insert(list, {
		name = name,
		shape = shape,
		size = size,
		color = c,
		material = material,
		offset = offset,
		rotation = extra and extra.rotation,
		transparency = extra and extra.transparency,
	})
end

-- 카운터(가운데 0, -40, 타원 반지름 28×10) 바깥 둘레의 바닥 자리
local AROUND_COUNTER = {
	vec(-38, 0, -40), -- 끝 의자(x ±33)와 안 겹치게 (m5-07 QA B1)
	vec(38, 0, -40),
	vec(-20, 0, -55),
	vec(20, 0, -55),
	vec(-20, 0, -25),
	vec(20, 0, -25),
}

local function halloweenDecor(): SeasonDecor
	local specs: { MapKitLogic.DecorSpec } = {}
	local orange, stem, face = rgb(245, 135, 35), rgb(90, 110, 40), rgb(40, 20, 50)
	for i, at in AROUND_COUNTER do
		deco(specs, `Pumpkin{i}`, "Ball", vec(3, 3, 3), orange, "SmoothPlastic", vec(at.x, 1.5, at.z))
		deco(specs, `PumpkinStem{i}`, "Block", vec(0.5, 0.8, 0.5), stem, "Wood", vec(at.x, 3.3, at.z))
		-- 카운터 쪽을 보는 잭오랜턴 얼굴 (빛나는 띠)
		local toward = if at.z < -40 then 1 elseif at.z > -40 then -1 else 0
		local side = if toward == 0 then (if at.x < 0 then 1 else -1) else 0
		deco(
			specs,
			`PumpkinFace{i}`,
			"Block",
			if toward ~= 0 then vec(1.6, 0.4, 0.2) else vec(0.2, 0.4, 1.6),
			face,
			"Neon",
			vec(at.x + side * 1.45, 1.4, at.z + toward * 1.45)
		)
	end
	local purple = rgb(150, 70, 220)
	deco(specs, "SpookyLampWest", "Ball", vec(1.2, 1.2, 1.2), purple, "Neon", vec(-12, 9, -40))
	deco(specs, "SpookyLampEast", "Ball", vec(1.2, 1.2, 1.2), purple, "Neon", vec(12, 9, -40))
	return {
		specs = specs,
		lights = { { part = "SpookyLampWest", color = purple }, { part = "SpookyLampEast", color = purple } },
	}
end

local function christmasDecor(): SeasonDecor
	local specs: { MapKitLogic.DecorSpec } = {}
	local trunk, green, star = rgb(110, 72, 44), rgb(40, 130, 60), rgb(255, 215, 60)
	for i, x in { -38, 38 } do
		deco(specs, `TreeTrunk{i}`, "Block", vec(1, 1.5, 1), trunk, "Wood", vec(x, 0.75, -40))
		deco(specs, `TreeLow{i}`, "Block", vec(5, 2, 5), green, "Grass", vec(x, 2.5, -40))
		deco(specs, `TreeMid{i}`, "Block", vec(3.6, 2, 3.6), green, "Grass", vec(x, 4.5, -40))
		deco(specs, `TreeTop{i}`, "Block", vec(2, 2, 2), green, "Grass", vec(x, 6.5, -40))
		deco(specs, `TreeStar{i}`, "Block", vec(0.9, 0.9, 0.3), star, "Neon", vec(x, 8, -40), {
			rotation = vec(0, 0, 45),
		})
	end
	local gifts = { rgb(214, 58, 58), rgb(58, 108, 206), rgb(250, 250, 250), rgb(60, 160, 80) }
	local ribbon = rgb(255, 215, 60)
	for i = 3, 6 do
		local at = AROUND_COUNTER[i]
		local c = gifts[i - 2]
		deco(specs, `Gift{i - 2}`, "Block", vec(2, 2, 2), c, "SmoothPlastic", vec(at.x, 1, at.z))
		deco(specs, `GiftRibbonX{i - 2}`, "Block", vec(2.05, 2.05, 0.35), ribbon, "Fabric", vec(at.x, 1, at.z))
		deco(specs, `GiftRibbonZ{i - 2}`, "Block", vec(0.35, 2.05, 2.05), ribbon, "Fabric", vec(at.x, 1, at.z))
	end
	-- 눈: 카운터 위 높은 곳의 보이지 않는 판에서 내려요
	deco(specs, "SnowCloud", "Block", vec(60, 0.2, 26), rgb(255, 255, 255), "SmoothPlastic", vec(0, 16, -40), {
		transparency = 1,
	})
	return { specs = specs, lights = {}, snow = "SnowCloud" }
end

-- 이벤트 id → 장식 종류 (해마다 id가 바뀌어도 앞부분으로 골라요)
local function decorKind(eventId: string?): string?
	if eventId == nil then
		return nil
	elseif string.find(eventId, "^halloween") then
		return "halloween"
	elseif string.find(eventId, "^christmas") then
		return "christmas"
	end
	return nil
end

local function addSnow(host: BasePart)
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Snow"
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.LightEmission = 0.3
	snow.Size = NumberSequence.new(0.3)
	snow.Transparency = NumberSequence.new(0.2, 1)
	snow.Lifetime = NumberRange.new(5, 7)
	snow.Rate = 25
	snow.Speed = NumberRange.new(2, 3)
	snow.SpreadAngle = Vector2.new(10, 10)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Parent = host
end

local function applySeasonDecor()
	local lobby = lobbyModel
	if lobby == nil or lobby.Parent == nil then
		return
	end
	local now = Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())
	local event = Seasons.current(now)
	local kind = decorKind(if event then event.id else nil)
	if kind == seasonDecorKind then
		return
	end
	seasonDecorKind = kind
	local old = lobby:FindFirstChild(SEASON_FOLDER)
	if old then
		old:Destroy()
	end
	if kind == nil then
		return
	end
	local decor = if kind == "halloween" then halloweenDecor() else christmasDecor()
	local count = MapKitLogic.count(decor.specs)
	if count > SEASON_DECOR_BUDGET then
		warn(`[LobbyService] season decor {kind} has {count} parts (budget {SEASON_DECOR_BUDGET})`)
	end
	local seasonFolder = Instance.new("Folder")
	seasonFolder.Name = SEASON_FOLDER
	local parts = MapKit.buildDecor(decor.specs, CFrame.identity, seasonFolder)
	local byName: { [string]: BasePart } = {}
	for _, p in parts do
		p.CastShadow = false
		byName[p.Name] = p
	end
	for _, spec in decor.lights do
		local host = byName[spec.part]
		if host then
			local light = Instance.new("PointLight")
			light.Color = color(spec.color)
			light.Range = 18
			light.Brightness = 1.5
			light.Shadows = false
			light.Parent = host
		end
	end
	local snowHost = if decor.snow then byName[decor.snow] else nil
	if snowHost then
		addSnow(snowHost)
	end
	seasonFolder.Parent = lobby
end

local function buildLobby()
	local existing = workspace:FindFirstChild(LOBBY_NAME)
	if existing then
		existing:Destroy()
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = color(LobbyLayout.FLOOR.color)
		baseplate.Material = Enum.Material.WoodPlanks
	end

	local lobby = Instance.new("Model")
	lobby.Name = LOBBY_NAME

	local structure = MapKit.buildDecor(LobbyLayout.STRUCTURE, CFrame.identity, folder("Structure", lobby))
	makeSolid(structure)
	local decor = MapKit.buildDecor(LobbyLayout.DECOR, CFrame.identity, MapKit.decorFolder(lobby))
	addLights(decor)
	buildPlates(lobby)
	buildPodium(lobby)
	setLabels(LobbyLayout.PODIUM.emptyText, nil, nil)
	MapKit.attachStudioArt(lobby, STUDIO_ART_ID, CFrame.identity)

	-- 다 지은 뒤 한 번에 Workspace로 (클라이언트에 한 묶음으로 복제돼요)
	lobby.Parent = workspace
	lobbyModel = lobby
	seasonDecorKind = nil
end

function LobbyService.init()
	applyLighting()
end

function LobbyService.start()
	if PlaceService.role() == "Match" then
		return -- 매치 플레이스에는 로비가 없어요 (조명만)
	end
	buildLobby()
	MatchEvents.onWinnerShowcase(onWinnerShowcase)
	-- 시즌 장식: 지금 한 번, 그 뒤 10분마다 (m5-07)
	applySeasonDecor()
	task.spawn(function()
		while true do
			task.wait(SEASON_CHECK_INTERVAL)
			local ok, err = pcall(applySeasonDecor)
			if not ok then
				warn(`[LobbyService] season decor failed: {err}`)
			end
		end
	end)
end

return LobbyService
