--!strict
-- 방 만들기 창 (GDD 3.2, m6-14 UX 개선 — docs/specs/m6-14-lobby-mobile-ux.md B).
--   설정(인원 칩·공개 여부 세그먼트)과 행동("방 만들기" 하나)을 모양으로 나눠요. 닫기는 오른쪽 위 X(게임패드 B)뿐 —
--   예전처럼 바닥에 "취소"를 두지 않아요(공개/비공개 줄과 구분이 안 됐어요).
--   안 고른 칩 = 밝은 접시색 + 얇은 나무 테두리, 고른 칩 = 채움색 + 굵은 테두리 (취소색 Neutral은 쓰지 않아요).
--   크기는 순수 Shared.CreateRoomLayout: 휴대폰 가로는 두 열(스크롤 없이 한 화면), PC는 한 열.
--   onSubmit(settings)만 부르고 서버 요청은 LobbyController가 해요. 이 창은 보여 주기만 해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreateRoomLayout = require(ReplicatedStorage.Shared.CreateRoomLayout)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local GamepadNav = require(script.Parent.GamepadNav)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type CreateRoomDialog = {
	open: (self: CreateRoomDialog) -> (),
	close: (self: CreateRoomDialog) -> (),
	isOpen: (self: CreateRoomDialog) -> boolean,
	setBusy: (self: CreateRoomDialog, busy: boolean) -> (),
	showMessage: (self: CreateRoomDialog, text: string, isError: boolean?) -> (),
	applyLayout: (self: CreateRoomDialog, m: UiLayout.Metrics, virtualWidth: number, virtualHeight: number) -> (),
}

local CreateRoomDialog = {}

local Z = 12

-- TextBox 글자 수 제한 (글자 단위)
local function capText(box: TextBox, maxChars: number)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local cut = utf8.len(box.Text) and utf8.offset(box.Text, maxChars + 1)
		if cut then
			box.Text = string.sub(box.Text, 1, cut - 1)
		end
	end)
end

-- 선택형 칩: 고르면 채움색 + 흰 글씨 + 굵은 테두리, 아니면 밝은 접시색 + 진한 글씨 + 얇은 테두리
local function styleChoice(button: TextButton, selected: boolean)
	local accent = button:GetAttribute("BaseColor") :: Color3
	button.BackgroundColor3 = if selected then accent else Color.Row
	button.TextColor3 = if selected then Color.White else Color.Text
	button.TextStrokeTransparency = if selected then 0.75 else 1
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = if selected then 3 else 1.5
		stroke.Transparency = if selected then 0 else 0.45
	end
	button:SetAttribute("Selected", selected)
end

function CreateRoomDialog.new(
	parent: Instance,
	defaultRoomName: string,
	onSubmit: (settings: Types.RoomSettings) -> ()
): CreateRoomDialog
	local selectedMax = Config.Room.DefaultMaxPlayers
	local selectedPrivate = false
	local options = Config.Room.MaxPlayerOptions

	local backdrop = Kit.new("TextButton", { -- 뒤 화면 클릭을 막는 배경
		Name = "CreateDialog",
		Parent = parent,
		Visible = false,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.4,
		ZIndex = 10,
	})
	local panel = Kit.new("Frame", {
		Name = "Panel",
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CreateRoomLayout.MAX_WIDTH_SINGLE, 480),
		BackgroundColor3 = Color.Panel,
		ZIndex = 11,
	}, { Kit.corner(16) })
	Kit.woodFrame(panel) -- 나무 카운터 테두리 (UI 개선 P1)
	local panelPadding = Kit.padding(CreateRoomLayout.PADDING)
	panelPadding.Parent = panel

	-- 머리줄: 제목 + X
	local header = Kit.new("Frame", {
		Name = "Header",
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = Z,
	})
	local title = Kit.label({
		Parent = header,
		Text = Loc.t("lobby.create.title"),
		TextSize = 22,
		Size = UDim2.new(1, -60, 1, 0),
		ZIndex = Z,
	})
	local closeButton = Kit.button(Kit.CLOSE_TEXT, Color.Nori, {
		Name = "Close",
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = Z + 1,
	})

	-- 본문: 두 열(휴대폰) 또는 한 열(PC). 넘치면 스크롤
	local body = Kit.new("ScrollingFrame", {
		Name = "Body",
		Parent = panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 300),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color.SubText,
		Selectable = false,
		ZIndex = Z,
	})
	local bodyList = Kit.list(Enum.FillDirection.Horizontal, CreateRoomLayout.COLUMN_GAP)
	bodyList.Parent = body

	local function column(order: number, name: string): (Frame, UIListLayout)
		local list = Kit.list(Enum.FillDirection.Vertical, CreateRoomLayout.GAP)
		local frame = Kit.new("Frame", {
			Name = name,
			Parent = body,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 100),
			ZIndex = Z,
		}, { list })
		return frame, list
	end
	local left, leftList = column(1, "Settings")
	local right, rightList = column(2, "Finish")

	type Label = { label: TextLabel, base: number, kind: "label" | "hint" | "summary" }
	local labels: { Label } = {}
	local function sectionLabel(parentFrame: Instance, order: number, text: string, kind: "label" | "hint" | "summary")
		local label = Kit.label({
			Parent = parentFrame,
			LayoutOrder = order,
			Text = text,
			TextSize = if kind == "hint" then 14 else 16,
			TextColor3 = if kind == "summary" then Color.Text else Color.SubText,
			TextWrapped = kind == "hint",
			TextYAlignment = if kind == "hint" then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = Z,
		})
		table.insert(labels, { label = label, base = if kind == "hint" then 14 else 16, kind = kind })
		return label
	end

	-- 왼쪽: 최대 인원 칩
	sectionLabel(left, 1, Loc.t("lobby.create.maxPlayers"), "label")
	local chipRow = Kit.new("Frame", {
		Name = "MaxPlayers",
		Parent = left,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = Z,
	})
	local chipGrid = Kit.new("UIGridLayout", {
		Parent = chipRow,
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellPadding = UDim2.fromOffset(CreateRoomLayout.CHIP_GAP, CreateRoomLayout.CHIP_GAP),
		CellSize = UDim2.fromOffset(64, 44),
	}) :: UIGridLayout
	local chips: { [number]: TextButton } = {}
	local allChoices: { TextButton } = {}

	-- 왼쪽: 누가 들어올 수 있나요? (공개 | 비공개)
	sectionLabel(left, 3, Loc.t("lobby.create.privacy"), "label")
	local segment = Kit.new("Frame", {
		Name = "Privacy",
		Parent = left,
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = Z,
	}, { Kit.list(Enum.FillDirection.Horizontal, CreateRoomLayout.CHIP_GAP) })
	local publicButton = Kit.button(Loc.t("lobby.create.public.btn"), Color.Nori, {
		Parent = segment,
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -CreateRoomLayout.CHIP_GAP / 2, 1, 0),
		ZIndex = Z + 1,
	})
	local privateButton = Kit.button(Loc.t("lobby.create.private.btn"), Color.Nori, {
		Parent = segment,
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -CreateRoomLayout.CHIP_GAP / 2, 1, 0),
		ZIndex = Z + 1,
	})
	table.insert(allChoices, publicButton)
	table.insert(allChoices, privateButton)

	-- 공개 여부 설명 (두 열이면 오른쪽 요약 위로, 한 열이면 세그먼트 바로 아래로 옮겨요)
	local hint = sectionLabel(left, 5, "", "hint")

	-- 오른쪽: 방 이름 → 요약 → 방 만들기
	sectionLabel(right, 1, Loc.t("lobby.create.name"), "label")
	local nameBox = Kit.textBox({
		Parent = right,
		LayoutOrder = 2,
		PlaceholderText = defaultRoomName,
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Z + 1,
	})
	capText(nameBox, Config.Room.NameMaxLength)
	local summary = sectionLabel(right, 4, "", "summary")
	local submitButton = Kit.button(Loc.t("lobby.create.confirm.btn"), Color.Salmon, {
		Name = "Submit",
		Parent = right,
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = Z + 1,
	})
	local showMessage, messageLabel = Kit.messageLabel(right, 6)
	messageLabel.ZIndex = Z

	local function refresh()
		for count, chip in chips do
			styleChoice(chip, count == selectedMax)
		end
		styleChoice(publicButton, not selectedPrivate)
		styleChoice(privateButton, selectedPrivate)
		hint.Text = if selectedPrivate
			then Loc.t("lobby.create.privateHint", { count = Config.Room.CodeLength })
			else Loc.t("lobby.create.publicHint")
		summary.Text = Loc.t("lobby.create.summary", {
			count = selectedMax,
			privacy = Loc.t(if selectedPrivate then "lobby.create.private.btn" else "lobby.create.public.btn"),
		})
	end

	for i, count in options do
		local chip = Kit.button(Loc.t("lobby.create.count.btn", { count = count }), Color.Salmon, {
			Parent = chipRow,
			LayoutOrder = i,
			ZIndex = Z + 1,
		})
		chips[count] = chip
		table.insert(allChoices, chip)
		Kit.onClick(chip, function()
			selectedMax = count
			refresh()
		end)
	end
	Kit.onClick(publicButton, function()
		selectedPrivate = false
		refresh()
	end)
	Kit.onClick(privateButton, function()
		selectedPrivate = true
		refresh()
	end)

	local function close()
		backdrop.Visible = false
	end
	Kit.onClick(closeButton, close)
	Kit.onClick(submitButton, function()
		local name = string.match(nameBox.Text, "^%s*(.-)%s*$")
		onSubmit({
			maxPlayers = selectedMax,
			isPrivate = selectedPrivate,
			name = if name and name ~= "" then name else nil,
		})
	end)

	GamepadNav.window({
		root = backdrop,
		group = panel,
		close = close,
		first = function(): GuiObject?
			return chips[selectedMax]
		end,
	})

	------------------------------------------------------------------

	local dialog = {}

	function dialog.applyLayout(
		_self: CreateRoomDialog,
		m: UiLayout.Metrics,
		virtualWidth: number,
		virtualHeight: number
	)
		local layout = CreateRoomLayout.compute(m, virtualWidth, virtualHeight, #options)

		if m.compact then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0, CreateRoomLayout.TOP_MARGIN)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
		end
		panel.Size = UDim2.fromOffset(layout.width, layout.height)
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			(panelPadding :: any)[side] = UDim.new(0, layout.padding)
		end

		header.Size = UDim2.new(1, 0, 0, layout.header)
		title.TextSize = layout.text.title
		title.Size = UDim2.new(1, -(layout.touch + 8), 1, 0)
		closeButton.Size = UDim2.fromOffset(layout.touch, layout.touch)
		closeButton.TextSize = layout.text.button

		body.Position = UDim2.fromOffset(0, layout.header + layout.gap)
		body.Size = UDim2.new(1, 0, 0, layout.bodyVisible)
		body.ScrollBarThickness = layout.scrollBar
		bodyList.FillDirection = if layout.twoColumn then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		bodyList.Padding = UDim.new(0, if layout.twoColumn then layout.columnGap else layout.gap)
		leftList.Padding = UDim.new(0, layout.gap)
		rightList.Padding = UDim.new(0, layout.gap)
		left.Size = UDim2.fromOffset(layout.columnWidth, layout.left)
		right.Size = UDim2.fromOffset(layout.columnWidth, layout.right)

		-- 설명: 두 열이면 오른쪽(요약 위), 한 열이면 왼쪽(세그먼트 아래)
		if layout.twoColumn then
			hint.Parent = right
			hint.LayoutOrder = 3
		else
			hint.Parent = left
			hint.LayoutOrder = 5
		end

		for _, item in labels do
			local height = if item.kind == "hint"
				then layout.hint
				elseif item.kind == "summary" then layout.summary
				else layout.label
			item.label.Size = UDim2.new(1, 0, 0, height)
			item.label.TextSize = if item.kind == "hint" then layout.text.hint else layout.text.label
		end

		chipRow.Size = UDim2.new(1, 0, 0, layout.chips)
		chipGrid.CellSize = UDim2.fromOffset(layout.chipWidth, layout.touch)
		segment.Size = UDim2.new(1, 0, 0, layout.touch)
		for _, button in allChoices do
			button.TextSize = layout.text.button
		end
		nameBox.Size = UDim2.new(1, 0, 0, layout.touch)
		nameBox.TextSize = layout.text.button
		submitButton.Size = UDim2.new(1, 0, 0, layout.touch)
		submitButton.TextSize = layout.text.button
		messageLabel.Size = UDim2.new(1, 0, 0, layout.message)
		messageLabel.TextSize = layout.text.label
	end

	function dialog.open(_self: CreateRoomDialog)
		selectedMax = Config.Room.DefaultMaxPlayers
		selectedPrivate = false
		nameBox.Text = ""
		messageLabel.Text = ""
		body.CanvasPosition = Vector2.zero
		refresh()
		backdrop.Visible = true
	end

	function dialog.close(_self: CreateRoomDialog)
		close()
	end

	function dialog.isOpen(_self: CreateRoomDialog): boolean
		return backdrop.Visible
	end

	function dialog.setBusy(_self: CreateRoomDialog, value: boolean)
		Kit.setEnabled(submitButton, not value)
	end

	function dialog.showMessage(_self: CreateRoomDialog, text: string, isError: boolean?)
		showMessage(text, isError)
	end

	refresh()
	return (dialog :: any) :: CreateRoomDialog
end

return CreateRoomDialog
