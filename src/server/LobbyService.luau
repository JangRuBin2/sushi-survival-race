--!strict
-- 로비 건물·조명·우승자 단상 (GDD 3.1, 8, m4-06). 배치 숫자는 Shared.LobbyLayout(순수 데이터)에 있어요.
--   init():  조명 프리셋을 Lighting에 한 번 적용 (한 플레이스 모드라 아레나도 같은 조명)
--   start(): Workspace.Lobby를 코드로 지어요 (매치 플레이스면 안 지어요) + 우승자 단상
-- 건물(벽·기둥·카운터·레일·단상)은 충돌 있음, 나머지는 MapKit 장식 규칙(충돌·쿼리·터치 없음).
-- 레일 접시는 서버에서는 멈춰 있고, 클라이언트 LobbyFxController가 로컬로 돌려요 (복제·서버 부하 없음).
-- 단상: MatchEvents.onWinnerShowcase가 올 때마다 가장 최근 우승자 1명으로 바꿔요. 서버는 이름표(BillboardGui)와
-- Podium 폴더 속성(LobbyLayout.WINNER_ATTRS)만 두고, 초밥 인형은 클라이언트 LobbyFxController가 그 속성으로 세워요.
-- 인형·이름은 플레이어가 나가도 남아요. 아무도 없으면 "다음 우승자는 누구?".

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local PlaceService = require(script.Parent.PlaceService)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapKit = require(ReplicatedStorage.Shared.maps.MapKit)
local MapKitLogic = require(ReplicatedStorage.Shared.maps.MapKitLogic)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)

local LobbyService = {}

local LOBBY_NAME = "Lobby"
local STUDIO_ART_ID = "lobby"

local podiumFolder: Folder? = nil
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
end

return LobbyService
