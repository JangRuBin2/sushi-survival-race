--!strict
-- 로비 ↔ 방 대기실 화면 전환과 방 요청 (RoomService와 대화하는 쪽).
--   방이 없으면 로비, 대기 중인 방이면 방 대기실, 매치 중이면 둘 다 숨겨요 (HUD가 맡아요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoomLogic = require(ReplicatedStorage.Shared.RoomLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local LobbyScreen = require(script.Parent.LobbyScreen)
local RoomScreen = require(script.Parent.RoomScreen)
local UiScaleController = require(script.Parent.UiScaleController)

local LobbyController = {}

function LobbyController.start(): ScreenGui
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- 화면 크기 배율·안전 영역 (m4-09): 로비·방·HUD·관전·출발 글씨·탈락 도장이 모두 이 gui 위에 있어요
	UiScaleController.attach(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	local currentRoom: Types.RoomSnapshot? = nil
	local busy = false
	local lobby: LobbyScreen.LobbyScreen
	local roomScreen: RoomScreen.RoomScreen

	-- 매치 서버(m4-11)에는 로비가 없어요: 방 목록·대기실 대신 안내 한 줄만 보여요
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"
	local matchSeen = false
	local statusLabel: TextLabel? = nil
	if isMatchServer then
		local label = Instance.new("TextLabel")
		label.Name = "MatchServerStatus"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromOffset(420, 60)
		label.BackgroundColor3 = Color3.fromRGB(30, 24, 20)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 24
		label.Text = "매치 서버 연결 중…"
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = label
		label.Parent = gui
		statusLabel = label
	end

	local function refreshVisibility()
		local room = currentRoom
		if isMatchServer then
			local inMatch = room ~= nil and room.state == "InMatch"
			matchSeen = matchSeen or inMatch
			lobby:setVisible(false)
			roomScreen:setVisible(false)
			if statusLabel then
				statusLabel.Visible = not inMatch
				if matchSeen and not inMatch then
					statusLabel.Text = "로비로 돌아가는 중…"
				end
			end
			return
		end
		lobby:setVisible(room == nil)
		roomScreen:setVisible(room ~= nil and room.state == "Waiting")
	end

	-- 서버 요청 하나. 응답이 올 때까지 버튼을 막아 두고, 실패 이유는 지금 보이는 화면에 띄워요.
	local function request(name: string, ...: any): boolean
		if busy then
			return false
		end
		busy = true
		lobby:setBusy(true)
		roomScreen:setBusy(true)
		local called, ok, err = pcall(Remotes.fn(name).InvokeServer, Remotes.fn(name), ...)
		busy = false
		lobby:setBusy(false)
		roomScreen:setBusy(false)

		if called and ok == true then
			return true
		end
		local message = if called and type(err) == "string" then err else "서버와 연결이 불안정해요"
		if currentRoom then
			roomScreen:showMessage(message, true)
		else
			lobby:showMessage(message, true)
		end
		return false
	end

	lobby = LobbyScreen.new(gui, RoomLogic.defaultName(player.DisplayName), {
		quickJoin = function()
			request("QuickJoin")
		end,
		joinRoom = function(roomId)
			request("JoinRoom", roomId)
		end,
		joinByCode = function(code)
			request("JoinByCode", code)
		end,
		createRoom = function(settings)
			if request("CreateRoom", settings) then
				lobby:closeCreateDialog()
			end
		end,
	})

	roomScreen = RoomScreen.new(gui, player.UserId, RoomLogic.minPlayersToStart(RunService:IsStudio()), {
		start = function()
			request("StartRoom")
		end,
		leave = function()
			request("LeaveRoom")
		end,
	})

	Remotes.event("RoomList").OnClientEvent:Connect(function(rooms: { Types.RoomListing })
		-- 다른 로비 서버의 방은 이름 앞에 표시 (m4-11)
		local shown = table.create(#rooms) :: { Types.RoomListing }
		for i, listing in rooms do
			if listing.remote then
				local copy = table.clone(listing)
				copy.name = `🌐 {listing.name}`
				shown[i] = copy
			else
				shown[i] = listing
			end
		end
		lobby:setRooms(shown)
	end)

	-- 서버의 짧은 안내 (m4-11: 텔레포트 실패, 다른 서버로 이동 중 등)
	Remotes.event("Notice").OnClientEvent:Connect(function(message: string)
		if type(message) ~= "string" then
			return
		end
		if statusLabel then
			statusLabel.Text = message
			statusLabel.Visible = true
		else
			local isError = string.find(message, "…", 1, true) == nil -- "이동하고 있어요…" 같은 진행 안내는 오류가 아니에요
			if currentRoom then
				roomScreen:showMessage(message, isError)
			else
				lobby:showMessage(message, isError)
			end
		end
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		currentRoom = room
		if room then
			roomScreen:setRoom(room)
		end
		refreshVisibility()
	end)

	refreshVisibility()
	return gui
end

return LobbyController
