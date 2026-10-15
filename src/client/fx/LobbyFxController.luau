--!strict
-- 로비 연출 (m4-06): 회전 레일 위 접시 16개를 이 클라이언트에서만 돌려요.
-- 서버가 Workspace.Lobby.Plates에 접시를 t = 0 자리(LobbyLayout.plateAt(i, 0))로 멈춰 두면,
-- 여기서 매 프레임 workspace:GetServerTimeNow()로 자리를 계산해 로컬로 옮겨요 (복제 없음).
-- 모든 클라이언트가 같은 서버 시각을 쓰므로 접시 위치가 거의 같아 보여요.
-- 카메라가 로비에서 멀면(아레나 관전 등) 옮기지 않아요.
-- 우승자 단상 인형도 여기서 세워요: 서버가 Lobby.Podium 폴더에 단 속성(LobbyLayout.WINNER_ATTRS)이 바뀌면
-- SushiBody.build(appearanceId)로 1.5배 인형(앵커·충돌 없음)을 가운데 단 위에 세워요 (가장 최근 1명).
-- 단상 이름표 글씨도 여기서 채워요 (m5-26): 서버가 단 Attributes.WinnerName·WinnerWins → PodiumLogic.view → Loc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Loc = require(script.Parent.Parent.Loc)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PodiumLogic = require(ReplicatedStorage.Shared.PodiumLogic)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Types = require(ReplicatedStorage.Shared.Types)
local DollAnimator = require(script.Parent.DollAnimator)

local LobbyFxController = {}

local LOBBY_WAIT = 60 -- 로비가 이만큼 안 오면 (매치 플레이스 등) 포기
local CHILD_WAIT = 10
local FAR_DISTANCE = 400 -- 카메라가 레일 가운데에서 이보다 멀면 쉬어요

type Plate = { index: number, parts: { BasePart }, offsets: { CFrame } }

local function poseCFrame(pose: LobbyLayout.Pose): CFrame
	return CFrame.new(pose.x, pose.y, pose.z) * CFrame.Angles(0, pose.yaw, 0)
end

local function collectPlates(platesFolder: Instance): { Plate }
	local plates: { Plate } = {}
	for i = 1, LobbyLayout.RAIL.plateCount do
		local model = platesFolder:WaitForChild(LobbyLayout.plateName(i), CHILD_WAIT)
		if model then
			local base = poseCFrame(LobbyLayout.plateAt(i, 0))
			local plate: Plate = { index = i, parts = {}, offsets = {} }
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(plate.parts, d)
					table.insert(plate.offsets, (base:ToObjectSpace(d.CFrame)))
				end
			end
			table.insert(plates, plate)
		end
	end
	return plates
end

local DOLL_NAME = "WinnerDoll"

local function placeDoll(podiumFolder: Instance)
	local old = podiumFolder:FindFirstChild(DOLL_NAME)
	if old then
		old:Destroy()
	end
	local attrs = LobbyLayout.WINNER_ATTRS
	local appearanceId = podiumFolder:GetAttribute(attrs.appearanceId)
	-- 이름표가 높은 스킨(m5-32 고등어)이면 단상 이름표도 그만큼(인형 크기 배율) 로컬로 올려요. 서버 이름표 자리는 그대로
	local showcase = podiumFolder:FindFirstChild("ShowcaseLabel")
	local billboard = showcase and showcase:FindFirstChild("Showcase")
	if billboard and billboard:IsA("BillboardGui") then
		local tag = SushiBody.nameTagHeight(if type(appearanceId) == "string" then appearanceId else nil)
		local lift = (tag - SushiBody.NAME_TAG_HEIGHT) * LobbyLayout.PODIUM.scale
		billboard.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	end
	if type(appearanceId) ~= "string" then
		return -- 아직 우승자 없음 (이름표만 "다음 우승자는 누구?")
	end
	local podium = LobbyLayout.PODIUM
	local model = SushiBody.build(appearanceId, "Happy") -- 표정은 concept-salmon만 (m5-27)
	model.Name = DOLL_NAME
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:ScaleTo(podium.scale)
	local height = podium.topY + SushiBody.GROUND_OFFSET * podium.scale
	model:PivotTo(
		CFrame.new(podium.center.x, height, podium.center.z) * CFrame.Angles(0, math.rad(podium.facingYawDeg), 0)
	)
	model.Parent = podiumFolder
	-- 우승자 단상: 고등어 관절이 있으면 신나게 팔딱 (m5-32, 카메라 60 안에서만 돌고 인형이 바뀌면 저절로 멈춰요)
	DollAnimator.attach(model, "Victory", { sound = "World" })
end

type PodiumLabels = { name: TextLabel, title: TextLabel, wins: TextLabel }

local function findLabels(podiumFolder: Instance): PodiumLabels?
	local anchor = podiumFolder:WaitForChild(LobbyLayout.PODIUM_ANCHOR, CHILD_WAIT)
	local billboard = anchor and anchor:WaitForChild(LobbyLayout.PODIUM_BILLBOARD, CHILD_WAIT)
	if billboard == nil then
		return nil
	end
	local names = LobbyLayout.PODIUM_LABELS
	local name = billboard:WaitForChild(names.name, CHILD_WAIT)
	local title = billboard:WaitForChild(names.title, CHILD_WAIT)
	local wins = billboard:WaitForChild(names.wins, CHILD_WAIT)
	if not (name and name:IsA("TextLabel") and title and title:IsA("TextLabel") and wins and wins:IsA("TextLabel")) then
		return nil
	end
	return { name = name, title = title, wins = wins }
end

local function setLine(label: TextLabel, text: Types.LocText?)
	label.AutoLocalize = false -- 우승자 이름을 번역하지 않게 (문구는 이미 Loc으로 풀었어요)
	label.Text = if text then Loc.text(text) else ""
	label.Visible = text ~= nil
end

-- 서버가 단 이름·승수로 이름표를 이 플레이어 언어로 채워요 (m5-26 2단계)
local function renderLabels(podiumFolder: Instance, labels: PodiumLabels)
	local view = PodiumLogic.view(
		podiumFolder:GetAttribute(Attributes.WinnerName),
		podiumFolder:GetAttribute(Attributes.WinnerWins)
	)
	setLine(labels.name, view.name)
	setLine(labels.title, view.title)
	setLine(labels.wins, view.wins)
end

local function watchPodium(lobby: Instance)
	local podiumFolder = lobby:WaitForChild("Podium", CHILD_WAIT)
	if podiumFolder == nil then
		return
	end
	podiumFolder:GetAttributeChangedSignal(LobbyLayout.WINNER_ATTRS.serial):Connect(function()
		placeDoll(podiumFolder)
	end)
	placeDoll(podiumFolder)

	local labels = findLabels(podiumFolder)
	if labels == nil then
		return
	end
	for _, attr in { Attributes.WinnerName, Attributes.WinnerWins } do
		podiumFolder:GetAttributeChangedSignal(attr):Connect(function()
			renderLabels(podiumFolder, labels)
		end)
	end
	Loc.onChanged(function() -- 번역기가 늦게 오면 다시 (QA B4)
		renderLabels(podiumFolder, labels)
	end)
	renderLabels(podiumFolder, labels)
end

local function run()
	local lobby = workspace:WaitForChild("Lobby", LOBBY_WAIT)
	if lobby == nil then
		return
	end
	task.spawn(watchPodium, lobby)
	local platesFolder = lobby:WaitForChild("Plates", CHILD_WAIT)
	if platesFolder == nil then
		return
	end
	local plates = collectPlates(platesFolder)
	local parts: { BasePart } = {}
	for _, plate in plates do
		for _, p in plate.parts do
			table.insert(parts, p)
		end
	end
	if #parts == 0 then
		return
	end
	local center = LobbyLayout.RAIL.center
	local railCenter = Vector3.new(center.x, center.y, center.z)
	local cframes = table.create(#parts) :: { CFrame }

	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if lobby.Parent == nil then
			connection:Disconnect()
			return
		end
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - railCenter).Magnitude > FAR_DISTANCE then
			return
		end
		local now = workspace:GetServerTimeNow()
		local n = 0
		for _, plate in plates do
			local cf = poseCFrame(LobbyLayout.plateAt(plate.index, now))
			for _, offset in plate.offsets do
				n += 1
				cframes[n] = cf * offset
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

function LobbyFxController.start(_gui: Instance)
	task.spawn(run)
end

return LobbyFxController
