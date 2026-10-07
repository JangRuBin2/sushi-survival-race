--!strict
-- 로비 화면 (GDD 3.1, 3.2, 10): 공개 방 목록, 빠른 참가, 방 만들기 창, 코드로 참가.
-- 서버 요청은 actions로 넘겨받아요. 이 화면은 보여주기만 해요.
-- TODO(M4): 스킨 상점, 탈의실, 코인 표시, 방 목록을 벨트 위 접시로

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	quickJoin: () -> (),
	joinRoom: (roomId: string) -> (),
	joinByCode: (code: string) -> (),
	createRoom: (settings: Types.RoomSettings) -> (),
}

export type LobbyScreen = {
	setVisible: (self: LobbyScreen, visible: boolean) -> (),
	setRooms: (self: LobbyScreen, rooms: { Types.RoomListing }) -> (),
	setBusy: (self: LobbyScreen, busy: boolean) -> (),
	showMessage: (self: LobbyScreen, text: string, isError: boolean?) -> (),
	closeCreateDialog: (self: LobbyScreen) -> (),
}

local LobbyScreen = {}

-- TextBox 글자 수 제한 (글자 단위)
local function capText(box: TextBox, maxChars: number)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local cut = utf8.len(box.Text) and utf8.offset(box.Text, maxChars + 1)
		if cut then
			box.Text = string.sub(box.Text, 1, cut - 1)
		end
	end)
end

function LobbyScreen.new(parent: Instance, defaultRoomName: string, actions: Actions): LobbyScreen
	local busy = false
	local rooms: { Types.RoomListing } = {}
	local busyButtons: { TextButton } = {}

	local root = Kit.new("Frame", {
		Name = "Lobby",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local panel = Kit.new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		BackgroundColor3 = Color.Panel,
	}, {
		Kit.corner(16),
		Kit.padding(16),
		Kit.list(Enum.FillDirection.Vertical, 8),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(760, 560) }),
	})

	Kit.label({
		Parent = panel,
		LayoutOrder = 1,
		Text = "🍣 초밥 서바이벌 레이스",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 36),
	})

	-- 빠른 참가 / 방 만들기 / 코드 입력 / 참가
	local actionRow = Kit.new("Frame", {
		Parent = panel,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })

	local quickButton = Kit.button("빠른 참가", Color.Salmon, {
		Parent = actionRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.27, -6, 1, 0),
	})
	local createButton = Kit.button("방 만들기", Color.Egg, {
		Parent = actionRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.27, -6, 1, 0),
		TextColor3 = Color.Text,
	})
	local codeBox = Kit.textBox({
		Parent = actionRow,
		LayoutOrder = 3,
		PlaceholderText = `방 코드 {Config.Room.CodeLength}자리`,
		Size = UDim2.new(0.26, -6, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local codeButton = Kit.button("코드로 참가", Color.Nori, {
		Parent = actionRow,
		LayoutOrder = 4,
		Size = UDim2.new(0.2, -6, 1, 0),
		TextSize = 16,
	})
	codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = string.sub(string.gsub(codeBox.Text, "%D", ""), 1, Config.Room.CodeLength)
		if digits ~= codeBox.Text then
			codeBox.Text = digits
		end
	end)

	Kit.label({
		Parent = panel,
		LayoutOrder = 3,
		Text = "공개 방",
		TextColor3 = Color.SubText,
		TextSize = 16,
	})

	local list = Kit.new("ScrollingFrame", {
		Parent = panel,
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -(36 + 44 + 24 + 22 + 8 * 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color.SubText,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })

	local showMessage = Kit.messageLabel(panel, 5)

	------------------------------------------------------------------
	-- 방 만들기 창

	local selectedMax = Config.Room.DefaultMaxPlayers
	local selectedPrivate = false

	local dialog = Kit.new("TextButton", { -- 뒤 화면 클릭을 막는 배경
		Name = "CreateDialog",
		Parent = root,
		Visible = false,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.4,
		ZIndex = 10,
	})
	local dialogPanel = Kit.new("Frame", {
		Parent = dialog,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 400),
		BackgroundColor3 = Color.Panel,
		ZIndex = 11,
	}, {
		Kit.corner(16),
		Kit.padding(16),
		Kit.list(Enum.FillDirection.Vertical, 8),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(460, 400) }),
	})

	local function dialogLabel(order: number, text: string, size: number?)
		Kit.label({
			Parent = dialogPanel,
			LayoutOrder = order,
			Text = text,
			TextSize = size or 16,
			TextColor3 = if size then Color.Text else Color.SubText,
			ZIndex = 12,
		})
	end
	local function dialogRow(order: number): Frame
		return Kit.new("Frame", {
			Parent = dialogPanel,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 12,
		}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	end

	dialogLabel(1, "방 만들기", 22)
	dialogLabel(2, "최대 인원")
	local maxRow = dialogRow(3)
	local options = Config.Room.MaxPlayerOptions
	local maxButtons: { [number]: TextButton } = {}
	for i, count in options do
		local button = Kit.button(`{count}명`, Color.Salmon, {
			Parent = maxRow,
			LayoutOrder = i,
			Size = UDim2.new(1 / #options, -6, 1, 0),
			ZIndex = 13,
		})
		maxButtons[count] = button
		Kit.onClick(button, function()
			selectedMax = count
			for c, b in maxButtons do
				Kit.setSelected(b, c == selectedMax)
			end
		end)
	end

	dialogLabel(4, "공개 여부")
	local privacyRow = dialogRow(5)
	local publicButton = Kit.button("공개", Color.Nori, {
		Parent = privacyRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -3, 1, 0),
		ZIndex = 13,
	})
	local privateButton = Kit.button("비공개 (코드)", Color.Nori, {
		Parent = privacyRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -3, 1, 0),
		ZIndex = 13,
	})
	local function refreshPrivacy()
		Kit.setSelected(publicButton, not selectedPrivate)
		Kit.setSelected(privateButton, selectedPrivate)
	end
	Kit.onClick(publicButton, function()
		selectedPrivate = false
		refreshPrivacy()
	end)
	Kit.onClick(privateButton, function()
		selectedPrivate = true
		refreshPrivacy()
	end)

	dialogLabel(6, "방 이름")
	local nameBox = Kit.textBox({
		Parent = dialogPanel,
		LayoutOrder = 7,
		PlaceholderText = defaultRoomName,
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	capText(nameBox, Config.Room.NameMaxLength)

	local confirmRow = dialogRow(8)
	local cancelButton = Kit.button("취소", Color.Neutral, {
		Parent = confirmRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -3, 1, 0),
		TextColor3 = Color.Text,
		ZIndex = 13,
	})
	local confirmButton = Kit.button("만들기", Color.Salmon, {
		Parent = confirmRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -3, 1, 0),
		ZIndex = 13,
	})
	local showDialogMessage = Kit.messageLabel(dialogPanel, 9)

	local function openDialog()
		selectedMax = Config.Room.DefaultMaxPlayers
		selectedPrivate = false
		nameBox.Text = ""
		for c, b in maxButtons do
			Kit.setSelected(b, c == selectedMax)
		end
		refreshPrivacy()
		dialog.Visible = true
	end

	Kit.onClick(cancelButton, function()
		dialog.Visible = false
	end)
	Kit.onClick(confirmButton, function()
		local name = string.match(nameBox.Text, "^%s*(.-)%s*$")
		actions.createRoom({
			maxPlayers = selectedMax,
			isPrivate = selectedPrivate,
			name = if name and name ~= "" then name else nil,
		})
	end)

	------------------------------------------------------------------
	-- 방 목록

	local function renderRooms()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #rooms == 0 then
			Kit.label({
				Parent = list,
				Text = "열린 방이 없어요. 방을 만들거나 빠른 참가를 눌러 보세요!",
				TextColor3 = Color.SubText,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -8, 0, 48),
			})
			return
		end
		for i, room in rooms do
			local row = Kit.new("Frame", {
				Parent = list,
				LayoutOrder = i,
				BackgroundColor3 = Color.Row,
				Size = UDim2.new(1, -8, 0, 52),
			}, {
				Kit.corner(10),
				Kit.padding(6),
				Kit.list(Enum.FillDirection.Horizontal, 8, {
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			})
			Kit.label({
				Parent = row,
				LayoutOrder = 1,
				Text = room.name,
				Size = UDim2.new(0.5, -8, 1, 0),
			})
			local full = room.memberCount >= room.maxPlayers
			Kit.label({
				Parent = row,
				LayoutOrder = 2,
				Text = `{room.memberCount}/{room.maxPlayers}명`,
				TextColor3 = Color.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0.2, -8, 1, 0),
			})
			local canJoin = room.state == "Waiting" and not full
			local joinButton = Kit.button(
				if room.state == "InMatch" then "게임 중" elseif full then "꽉 참" else "참가",
				Color.Salmon,
				{
					Parent = row,
					LayoutOrder = 3,
					Size = UDim2.new(0.3, -8, 1, 0),
				}
			)
			Kit.setEnabled(joinButton, canJoin and not busy)
			joinButton:SetAttribute("CanJoin", canJoin)
			Kit.onClick(joinButton, function()
				actions.joinRoom(room.id)
			end)
		end
	end

	------------------------------------------------------------------

	busyButtons = { quickButton, createButton, codeButton, confirmButton }

	Kit.onClick(quickButton, actions.quickJoin)
	Kit.onClick(createButton, openDialog)
	Kit.onClick(codeButton, function()
		if #codeBox.Text ~= Config.Room.CodeLength then
			showMessage(`방 코드 {Config.Room.CodeLength}자리를 입력해 주세요`, true)
			return
		end
		actions.joinByCode(codeBox.Text)
	end)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and #codeBox.Text == Config.Room.CodeLength and codeButton.Active then
			actions.joinByCode(codeBox.Text)
		end
	end)

	renderRooms()

	local screen = {}

	function screen.setVisible(_self: LobbyScreen, visible: boolean)
		root.Visible = visible
		if not visible then
			dialog.Visible = false
		end
	end

	function screen.setRooms(_self: LobbyScreen, newRooms: { Types.RoomListing })
		rooms = newRooms
		renderRooms()
	end

	function screen.setBusy(_self: LobbyScreen, value: boolean)
		busy = value
		for _, button in busyButtons do
			Kit.setEnabled(button, not busy)
		end
		for _, row in list:GetChildren() do
			for _, child in row:GetChildren() do
				if child:IsA("TextButton") then
					Kit.setEnabled(child, not busy and child:GetAttribute("CanJoin") == true)
				end
			end
		end
	end

	function screen.showMessage(_self: LobbyScreen, text: string, isError: boolean?)
		-- 방 만들기 창이 열려 있으면 창 안에 보여줘요 (뒤 화면 문구는 가려져요)
		if dialog.Visible then
			showDialogMessage(text, isError)
		else
			showMessage(text, isError)
		end
	end

	function screen.closeCreateDialog(_self: LobbyScreen)
		dialog.Visible = false
	end

	return (screen :: any) :: LobbyScreen
end

return LobbyScreen
