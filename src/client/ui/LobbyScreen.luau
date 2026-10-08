--!strict
-- 로비 화면 (GDD 3.1, 3.2, 10): 공개 방 목록, 빠른 참가, 방 만들기 창, 코드로 참가.
-- 서버 요청은 actions로 넘겨받아요. 이 화면은 보여주기만 해요.
-- 화면 크기 대응 (m4-09): 버튼은 배율 적용 뒤 Config.Ui.MinTouchSize 이상, compact(휴대폰 가로)에서는
-- 패널·방 만들기 창을 위쪽에 붙이고(키보드가 올라와도 입력칸이 보이게) 글씨를 실제 14px 이상으로 키워요.
-- TODO(M4): 스킨 상점, 탈의실, 코인 표시, 방 목록을 벨트 위 접시로

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

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

local PANEL_MAX = Vector2.new(760, 560)
local DIALOG_MAX_WIDTH = 460
local GAP = 8
local PADDING = 16
local MAX_BUTTON_GAP = 6

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
	local metrics = UiScaleController.metrics()

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
		Kit.padding(PADDING),
		Kit.list(Enum.FillDirection.Vertical, GAP),
		Kit.new("UISizeConstraint", { MaxSize = PANEL_MAX }),
	})

	local titleLabel = Kit.label({
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

	local listTitle = Kit.label({
		Parent = panel,
		LayoutOrder = 3,
		Text = "공개 방",
		TextColor3 = Color.SubText,
		TextSize = 16,
	})

	local list = Kit.scrollList({
		Parent = panel,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 1, -(36 + 44 + 24 + 22 + GAP * 4)),
	}, 6)

	local showMessage, messageLabel = Kit.messageLabel(panel, 5)

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
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.4,
		ZIndex = 10,
	})
	-- 작은 화면에서 창이 화면보다 길면 스크롤해요
	local dialogPanel = Kit.new("ScrollingFrame", {
		Parent = dialog,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 400),
		BackgroundColor3 = Color.Panel,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color.SubText,
		ZIndex = 11,
	}, {
		Kit.corner(16),
		Kit.padding(PADDING),
		Kit.list(Enum.FillDirection.Vertical, GAP),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(DIALOG_MAX_WIDTH, math.huge) }),
	})

	type DialogLabel = { label: TextLabel, base: number }
	local dialogLabels: { DialogLabel } = {}
	local function dialogLabel(order: number, text: string, size: number?): TextLabel
		local label = Kit.label({
			Parent = dialogPanel,
			LayoutOrder = order,
			Text = text,
			TextSize = size or 16,
			TextColor3 = if size then Color.Text else Color.SubText,
			ZIndex = 12,
		})
		table.insert(dialogLabels, { label = label, base = size or 16 })
		return label
	end
	local function dialogRow(order: number): Frame
		return Kit.new("Frame", {
			Parent = dialogPanel,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 12,
		}, { Kit.list(Enum.FillDirection.Horizontal, MAX_BUTTON_GAP) })
	end

	dialogLabel(1, "방 만들기", 22)
	dialogLabel(2, "최대 인원")
	-- 인원 버튼 5개: 한 줄에 안 들어가면 두 줄 (UIGridLayout 칸 크기는 applyLayout이 정해요)
	local maxRow = Kit.new("Frame", {
		Parent = dialogPanel,
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 12,
	})
	local maxGrid = Kit.new("UIGridLayout", {
		Parent = maxRow,
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellPadding = UDim2.fromOffset(MAX_BUTTON_GAP, MAX_BUTTON_GAP),
		CellSize = UDim2.new(0.2, -MAX_BUTTON_GAP, 0, 44),
	}) :: UIGridLayout
	local options = Config.Room.MaxPlayerOptions
	local maxButtons: { [number]: TextButton } = {}
	for i, count in options do
		local button = Kit.button(`{count}명`, Color.Salmon, {
			Parent = maxRow,
			LayoutOrder = i,
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

	local privacyLabel = dialogLabel(4, "공개 여부")
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

	local nameLabel = dialogLabel(6, "방 이름")
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
	local showDialogMessage, dialogMessageLabel = Kit.messageLabel(dialogPanel, 9)

	local function openDialog()
		selectedMax = Config.Room.DefaultMaxPlayers
		selectedPrivate = false
		nameBox.Text = ""
		for c, b in maxButtons do
			Kit.setSelected(b, c == selectedMax)
		end
		refreshPrivacy()
		dialogPanel.CanvasPosition = Vector2.zero
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
		local m = metrics
		local rowHeight = UiLayout.touchSize(44, m) + 8
		local text = UiLayout.textSize(18, m)
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
				TextSize = UiLayout.textSize(16, m),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -8, 0, math.max(48, UiLayout.textSize(16, m) * 2 + 8)),
			})
			return
		end
		for i, room in rooms do
			local row = Kit.new("Frame", {
				Parent = list,
				LayoutOrder = i,
				BackgroundColor3 = Color.Row,
				Size = UDim2.new(1, -8, 0, rowHeight),
			}, {
				Kit.corner(10),
				Kit.padding(4),
				Kit.list(Enum.FillDirection.Horizontal, 8, {
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			})
			Kit.label({
				Parent = row,
				LayoutOrder = 1,
				Text = room.name,
				TextSize = text,
				Size = UDim2.new(0.5, -8, 1, 0),
			})
			local full = room.memberCount >= room.maxPlayers
			Kit.label({
				Parent = row,
				LayoutOrder = 2,
				Text = `{room.memberCount}/{room.maxPlayers}명`,
				TextColor3 = Color.SubText,
				TextSize = text,
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
					TextSize = text,
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
	-- 화면 크기 대응 (m4-09)

	local function applyLayout(m: UiLayout.Metrics)
		metrics = m
		local touch = UiLayout.touchSize(44, m)
		local function text(base: number): number
			return UiLayout.textSize(base, m)
		end
		local function line(base: number, textBase: number): number
			return UiLayout.lineHeight(base, m, textBase)
		end
		local virtualWidth = if m.width > 0 then m.width / m.scale else 1280
		-- 높이는 LobbyGui 실제 높이(CoreUISafeInsets라 위쪽 바를 뺀 값)로 (m4-09 QA B2)
		local guiHeight = if parent:IsA("GuiBase2d") then parent.AbsoluteSize.Y else 0
		local realHeight = if guiHeight > 0 then guiHeight else m.height
		local virtualHeight = if realHeight > 0 then realHeight / m.scale else 720
		local scrollBar = UiLayout.scrollBarThickness(m)

		-- 로비 패널: compact면 위쪽에 붙여 코드 입력칸이 키보드에 가리지 않게 (높이는 화면 90% 이하)
		if m.compact then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.fromScale(0.5, 0.03)
			panel.Size = UDim2.fromScale(0.94, 0.9)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
			panel.Size = UDim2.fromScale(0.92, 0.86)
		end

		local titleHeight = line(36, 26)
		titleLabel.TextSize = text(26)
		titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
		actionRow.Size = UDim2.new(1, 0, 0, touch)
		for _, button in { quickButton, createButton } do
			button.TextSize = text(18)
		end
		codeBox.TextSize = text(18)
		codeButton.TextSize = text(16)
		local listTitleHeight = line(24, 16)
		listTitle.TextSize = text(16)
		listTitle.Size = UDim2.new(1, 0, 0, listTitleHeight)
		local messageHeight = line(22, 16)
		messageLabel.TextSize = text(16)
		messageLabel.Size = UDim2.new(1, 0, 0, messageHeight)
		list.ScrollBarThickness = scrollBar
		list.Size = UDim2.new(1, 0, 1, -(titleHeight + touch + listTitleHeight + messageHeight + GAP * 4))

		-- 방 만들기 창
		local dialogWidth = math.min(virtualWidth * 0.9, DIALOG_MAX_WIDTH)
		local inner = dialogWidth - PADDING * 2 - scrollBar
		local perRow, rows = UiLayout.gridRows(#options, inner, touch + 16, MAX_BUTTON_GAP)
		maxGrid.CellSize = UDim2.new(1 / perRow, -MAX_BUTTON_GAP, 0, touch)
		local maxRowHeight = rows * touch + (rows - 1) * MAX_BUTTON_GAP
		maxRow.Size = UDim2.new(1, 0, 0, maxRowHeight)
		for _, button in maxButtons do
			button.TextSize = text(18)
		end
		local labelsHeight = 0
		for _, item in dialogLabels do
			local height = line(24, item.base)
			item.label.TextSize = text(item.base)
			item.label.Size = UDim2.new(1, 0, 0, height)
			labelsHeight += height
		end
		privacyRow.Size = UDim2.new(1, 0, 0, touch)
		confirmRow.Size = UDim2.new(1, 0, 0, touch)
		nameBox.Size = UDim2.new(1, 0, 0, touch)
		nameBox.TextSize = text(18)
		for _, button in { publicButton, privateButton, cancelButton, confirmButton } do
			button.TextSize = text(18)
		end
		dialogMessageLabel.TextSize = text(16)
		dialogMessageLabel.Size = UDim2.new(1, 0, 0, messageHeight)
		dialogPanel.ScrollBarThickness = scrollBar

		local content = labelsHeight + maxRowHeight + touch * 3 + messageHeight + GAP * 8 + PADDING * 2
		if m.compact then
			-- 위쪽에 두고 방 이름 칸을 맨 위로: 키보드가 올라와도 입력칸이 보여요
			dialogPanel.AnchorPoint = Vector2.new(0.5, 0)
			dialogPanel.Position = UDim2.new(0.5, 0, 0, 8)
			nameLabel.LayoutOrder = 2
			nameBox.LayoutOrder = 3
			dialogLabels[2].label.LayoutOrder = 4
			maxRow.LayoutOrder = 5
			privacyLabel.LayoutOrder = 6
			privacyRow.LayoutOrder = 7
		else
			dialogPanel.AnchorPoint = Vector2.new(0.5, 0.5)
			dialogPanel.Position = UDim2.fromScale(0.5, 0.5)
			dialogLabels[2].label.LayoutOrder = 2
			maxRow.LayoutOrder = 3
			privacyLabel.LayoutOrder = 4
			privacyRow.LayoutOrder = 5
			nameLabel.LayoutOrder = 6
			nameBox.LayoutOrder = 7
		end
		dialogPanel.Size = UDim2.new(0.9, 0, 0, math.min(content, virtualHeight * 0.9 - 8))

		renderRooms()
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

	UiScaleController.onChanged(applyLayout) -- 바로 한 번 불러서 renderRooms까지 해요
	if parent:IsA("GuiBase2d") then
		-- 안전 영역(위쪽 바 높이)이 늦게 정해지거나 바뀌면 창 높이를 다시 맞춰요
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			applyLayout(metrics)
		end)
	end

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
