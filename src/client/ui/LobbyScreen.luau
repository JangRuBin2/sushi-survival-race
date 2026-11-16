--!strict
-- 로비 화면 (GDD 3.1, 3.2, 10): 공개 방 목록, 빠른 참가, 방 만들기 창, 코드로 참가.
-- 서버 요청은 actions로 넘겨받아요. 이 화면은 보여주기만 해요.
-- 화면 크기 대응 (m4-09): 버튼은 배율 적용 뒤 Config.Ui.MinTouchSize 이상, compact(휴대폰 가로)에서는
-- 패널·방 만들기 창을 위쪽에 붙이고(키보드가 올라와도 입력칸이 보이게) 글씨를 실제 14px 이상으로 키워요.
-- 게임패드 (m5-12): 로비는 GamepadNav.page(첫 버튼 = 빠른 참가), 방 만들기 창은 GamepadNav.window(B = 취소).
-- 1인 연습 (m6-13): "연습" 버튼 → PracticeDialog(맵 고르기) → actions.startPractice(mapId).
-- 방 만들기 창 (m6-14): CreateRoomDialog (설정 칩·세그먼트와 주 버튼을 모양으로 나눈 새 창).
-- 패널 접기 (m6-14): 제목 줄 "접기" → 패널을 숨기고 위쪽 가운데 "🔍 방 찾기" 버튼만 남겨 로비(회전초밥집·단상)를
--   구경할 수 있어요. 방에 갔다 로비로 돌아오거나 로비에 안내가 오면 다시 펼쳐요 (접힌 상태는 저장하지 않아요).
-- TODO(M4): 스킨 상점, 탈의실, 코인 표시, 방 목록을 벨트 위 접시로

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local CreateRoomDialog = require(script.Parent.CreateRoomDialog)
local GamepadNav = require(script.Parent.GamepadNav)
local PracticeDialog = require(script.Parent.PracticeDialog)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

local Color = Kit.Color

export type Actions = {
	quickJoin: () -> (),
	joinRoom: (roomId: string) -> (),
	joinByCode: (code: string) -> (),
	createRoom: (settings: Types.RoomSettings) -> (),
	startPractice: (mapId: string) -> (),
}

export type LobbyScreen = {
	setVisible: (self: LobbyScreen, visible: boolean) -> (),
	setRooms: (self: LobbyScreen, rooms: { Types.RoomListing }) -> (),
	setBusy: (self: LobbyScreen, busy: boolean) -> (),
	showMessage: (self: LobbyScreen, text: string, isError: boolean?) -> (),
	closeCreateDialog: (self: LobbyScreen) -> (),
	closePracticeDialog: (self: LobbyScreen) -> (),
	setCollapsed: (self: LobbyScreen, collapsed: boolean) -> (),
	isCollapsed: (self: LobbyScreen) -> boolean,
}

local LobbyScreen = {}

local PANEL_MAX = Vector2.new(760, 560)
local GAP = 8
local PADDING = 16
local EXPAND_TOP = 8 -- 접었을 때 "방 찾기" 버튼: 화면 위에서 띄우는 거리

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
	Kit.woodFrame(panel) -- UI 개선 P1: 나무 카운터 테두리

	-- 제목 줄: 제목 + 오른쪽 "접기" (m6-14)
	local titleRow = Kit.new("Frame", {
		Name = "TitleRow",
		Parent = panel,
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	})
	local titleLabel = Kit.label({
		Parent = titleRow,
		Text = Loc.t("lobby.title"),
		TextSize = 26,
		Size = UDim2.new(1, -120, 1, 0),
	})
	local collapseButton = Kit.button(Loc.t("lobby.collapse.btn"), Color.Nori, {
		Name = "Collapse",
		Parent = titleRow,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(110, 44),
	})

	-- 접었을 때 위쪽 가운데에 남는 "🔍 방 찾기" (m6-14)
	local expandButton = Kit.button(Loc.t("lobby.expand.btn"), Color.Salmon, {
		Name = "Expand",
		Parent = root,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, EXPAND_TOP),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Kit.new("UIPadding", {
		Parent = expandButton,
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	})

	-- 빠른 참가 / 방 만들기 / 코드 입력 / 참가
	local actionRow = Kit.new("Frame", {
		Parent = panel,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })

	local quickButton = Kit.button(Loc.t("lobby.quickJoin.btn"), Color.Salmon, {
		Parent = actionRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.22, -6, 1, 0),
	})
	local createButton = Kit.button(Loc.t("lobby.create.btn"), Color.Egg, {
		Parent = actionRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.22, -6, 1, 0),
		TextColor3 = Color.Text,
	})
	local practiceButton = Kit.button(Loc.t("lobby.practice.btn"), Color.Nori, {
		Parent = actionRow,
		LayoutOrder = 3,
		Size = UDim2.new(0.16, -6, 1, 0),
	})
	local codeBox = Kit.textBox({
		Parent = actionRow,
		LayoutOrder = 4,
		PlaceholderText = Loc.t("lobby.codePlaceholder", { count = Config.Room.CodeLength }),
		Size = UDim2.new(0.22, -6, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local codeButton = Kit.button(Loc.t("lobby.joinCode.btn"), Color.Nori, {
		Parent = actionRow,
		LayoutOrder = 5,
		Size = UDim2.new(0.18, -6, 1, 0),
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
		Text = Loc.t("lobby.publicRooms"),
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
	-- 방 만들기 창 (m6-14: CreateRoomDialog로 분리) · 1인 연습 맵 고르기 창 (m6-13)

	local createDialog = CreateRoomDialog.new(root, defaultRoomName, actions.createRoom)
	local practiceDialog = PracticeDialog.new(root, actions.startPractice)

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
				Text = Loc.t("lobby.noRooms"),
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
				Text = Loc.t("lobby.room.count", { count = room.memberCount, max = room.maxPlayers }),
				TextColor3 = Color.SubText,
				TextSize = text,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0.2, -8, 1, 0),
			})
			local canJoin = room.state == "Waiting" and not full
			local joinButton = Kit.button(
				if room.state == "InMatch"
					then Loc.t("lobby.room.playing.btn")
					elseif full then Loc.t("lobby.room.full.btn")
					else Loc.t("lobby.room.join.btn"),
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

		local titleHeight = math.max(line(36, 26), touch)
		titleLabel.TextSize = text(26)
		titleRow.Size = UDim2.new(1, 0, 0, titleHeight)
		collapseButton.TextSize = text(16)
		collapseButton.Size = UDim2.fromOffset(math.max(touch * 1.6, 96), touch)
		titleLabel.Size = UDim2.new(1, -(math.max(touch * 1.6, 96) + 8), 1, 0)
		expandButton.TextSize = text(18)
		expandButton.Size = UDim2.fromOffset(0, touch)
		actionRow.Size = UDim2.new(1, 0, 0, touch)
		for _, button in { quickButton, createButton, practiceButton } do
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

		createDialog:applyLayout(m, virtualWidth, virtualHeight)
		practiceDialog:applyLayout(m, virtualWidth, virtualHeight)

		renderRooms()
	end

	------------------------------------------------------------------

	busyButtons = { quickButton, createButton, practiceButton, codeButton }

	-- 접기·펼치기 (m6-14). 게임패드면 선택도 따라가요 (사라진 버튼에 선택이 남지 않게)
	local collapsed = false
	local function setCollapsed(value: boolean)
		if collapsed == value then
			return
		end
		collapsed = value
		panel.Visible = not value
		expandButton.Visible = value
		if GamepadNav.isGamepad() and GuiService.SelectedObject ~= nil then
			GuiService.SelectedObject = if value then expandButton else quickButton
		end
	end
	Kit.onClick(collapseButton, function()
		setCollapsed(true)
	end)
	Kit.onClick(expandButton, function()
		setCollapsed(false)
	end)

	Kit.onClick(quickButton, actions.quickJoin)
	Kit.onClick(createButton, function()
		createDialog:open()
	end)
	Kit.onClick(practiceButton, function()
		practiceDialog:open()
	end)
	Kit.onClick(codeButton, function()
		if #codeBox.Text ~= Config.Room.CodeLength then
			showMessage(Loc.t("lobby.codeNeeded", { count = Config.Room.CodeLength }), true)
			return
		end
		actions.joinByCode(codeBox.Text)
	end)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and #codeBox.Text == Config.Room.CodeLength and codeButton.Active then
			actions.joinByCode(codeBox.Text)
		end
	end)

	-- 게임패드 (m5-12): 로비는 기본 화면 (첫 버튼 = 빠른 참가, 접혀 있으면 "방 찾기"). 방 만들기 창은 CreateRoomDialog가 등록해요
	GamepadNav.page({
		root = root,
		first = function(): GuiObject?
			return if collapsed then expandButton else quickButton
		end,
	})

	UiScaleController.onChanged(applyLayout) -- 바로 한 번 불러서 renderRooms까지 해요
	if parent:IsA("GuiBase2d") then
		-- 안전 영역(위쪽 바 높이)이 늦게 정해지거나 바뀌면 창 높이를 다시 맞춰요
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			applyLayout(metrics)
		end)
	end

	local screen = {}

	function screen.setVisible(_self: LobbyScreen, visible: boolean)
		if visible and not root.Visible then
			setCollapsed(false) -- 방·매치에서 로비로 돌아오면 다시 펼쳐요 (m6-14)
		end
		root.Visible = visible
		if not visible then
			createDialog:close()
			practiceDialog:close()
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
		practiceDialog:setBusy(busy)
		createDialog:setBusy(busy)
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
		if createDialog:isOpen() then
			createDialog:showMessage(text, isError)
		elseif practiceDialog:isOpen() then
			practiceDialog:showMessage(text, isError)
		else
			setCollapsed(false) -- 접힌 채로는 안내 줄이 안 보여요 (m6-14)
			showMessage(text, isError)
		end
	end

	function screen.closeCreateDialog(_self: LobbyScreen)
		createDialog:close()
	end

	function screen.closePracticeDialog(_self: LobbyScreen)
		practiceDialog:close()
	end

	function screen.setCollapsed(_self: LobbyScreen, value: boolean)
		setCollapsed(value)
	end

	function screen.isCollapsed(_self: LobbyScreen): boolean
		return collapsed
	end

	return (screen :: any) :: LobbyScreen
end

return LobbyScreen
