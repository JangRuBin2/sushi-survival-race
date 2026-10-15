--!strict
-- 테스트용 관리자 패널 화면 (m5-02). 자기 ScreenGui `AdminPanel`. AdminController가 관리자에게만 만들어요.
--   열기 버튼 "🛠": 왼쪽 가장자리 세로 가운데 (위쪽 바 줄·탈의실 버튼(왼쪽 위)·관전/터치 버튼(아래)과 겹치지 않아요).
--   패널: 위쪽 탭 2개 "👕 미리보기" / "🛠 명령" (m5-11), 아래 결과 한 줄(서버가 돌려준 문구).
--     미리보기 탭: 스킨 버튼 격자(이름 + 등급 색, Skins.LIST 순서), 미리보기 중인 스킨 강조, "끄기 (내 스킨으로)".
--     명령 탭 (스크롤): info, 바로 시작, 맵 순서(맵 id 버튼을 눌러 순서대로 쌓기 → "다음 판에 쓰기"/"비우기"),
--       코인 +100/+1000/−1000, 이벤트 재화 +10/+80, 연출 미리보기(칸마다 기본 + FxCatalog 연출),
--       resetprofile(options.showReset일 때만 — Studio, 두 번 눌러 확인).
--   등급(Studio 전용 여부)은 몰라요: 실서버에서 Test 명령을 누르면 서버가 거절 문구를 돌려줘요.
-- 보여 주기만 하고 요청은 actions로 넘겨요. 판정은 서버 AdminService가 해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxCatalog = require(ReplicatedStorage.Shared.FxCatalog)
local Skins = require(ReplicatedStorage.Shared.Skins)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	toggle: () -> (),
	preview: (skinId: string?) -> (), -- nil이면 끄기
	command: (name: string, args: any) -> (), -- AdminCommand (m5-11)
}

export type Options = {
	mapIds: { string }, -- 맵 순서에 쓸 수 있는 id (Maps.allInfos 순서)
	showReset: boolean, -- resetprofile 버튼 (Studio에서만)
}

export type AdminPanel = {
	gui: ScreenGui,
	setOpen: (self: AdminPanel, open: boolean) -> (),
	isOpen: (self: AdminPanel) -> boolean,
	setCurrent: (self: AdminPanel, skinId: string?) -> (),
	setBusy: (self: AdminPanel, busy: boolean) -> (),
	showResult: (self: AdminPanel, text: string, isError: boolean) -> (),
	setLayout: (self: AdminPanel, m: UiLayout.Metrics) -> (),
}

local AdminPanel = {}

local MARGIN = 12
local BUTTON_SIZE = 44
local GAP = 6
local CELL_HEIGHT = 40
local PANEL_SIZE = Vector2.new(360, 460)
local TAB_HEIGHT = 32
local ROW_HEIGHT = 36
local PLAN_MAX = 4
local RESET_CONFIRM_SECONDS = 3
local HIGHLIGHT = Color3.fromRGB(40, 160, 90)

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

function AdminPanel.new(playerGui: Instance, actions: Actions, options: Options): AdminPanel
	local gui = Kit.new("ScreenGui", {
		Name = "AdminPanel",
		ResetOnSpawn = false,
		DisplayOrder = 15, -- 로비·HUD(0) 위, 탈의실(20) 아래: 탈의실 창이 열리면 그 아래로 가려져요
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local openButton = Kit.button("🛠", Color.Nori, {
		Name = "AdminButton",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		TextSize = 22,
	})
	Kit.onClick(openButton, actions.toggle)

	local panel = Kit.new("Frame", {
		Name = "Panel",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN + BUTTON_SIZE + GAP, 0.5, 0),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = Color.Panel,
		Active = true,
		Visible = false,
	}, {
		Kit.corner(12),
		Kit.padding(10),
	})

	-- 탭 줄
	local tabRow = Kit.new("Frame", {
		Name = "Tabs",
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	}, {
		Kit.list(Enum.FillDirection.Horizontal, GAP),
	})
	local previewTab = Kit.button("👕 미리보기", Color.Salmon, {
		Name = "PreviewTab",
		Parent = tabRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -GAP / 2, 1, 0),
		TextSize = 16,
	})
	local commandTab = Kit.button("🛠 명령", Color.Nori, {
		Name = "CommandTab",
		Parent = tabRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -GAP / 2, 1, 0),
		TextSize = 16,
	})

	-- 탭 내용 (결과 줄 위까지)
	local function page(name: string): Frame
		return Kit.new("Frame", {
			Name = name,
			Parent = panel,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, TAB_HEIGHT + GAP),
			Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + GAP + 26)),
		})
	end
	local previewPage = page("PreviewPage")
	local commandPage = page("CommandPage")
	commandPage.Visible = false

	local title = Kit.label({
		Name = "Title",
		Parent = previewPage,
		Text = "테스트 착용 (저장 안 됨)",
		TextSize = 16,
		TextColor3 = Color.SubText,
		Size = UDim2.new(1, 0, 0, 22),
	})

	local offButton = Kit.button("끄기 (내 스킨으로)", Color.Salmon, {
		Name = "OffButton",
		Parent = previewPage,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -GAP),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = 16,
	})
	Kit.onClick(offButton, function()
		actions.preview(nil)
	end)

	local resultLabel = Kit.label({
		Name = "Result",
		Parent = panel,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Parent = previewPage,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -(26 + 38 + GAP * 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color.SubText,
	})
	local gridLayout = Kit.new("UIGridLayout", {
		Parent = grid,
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.new(0.5, -GAP, 0, CELL_HEIGHT),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIGridLayout

	local buttons: { [string]: TextButton } = {}
	for index, skin in Skins.LIST do
		local button = Kit.button(skin.displayName, Color.Row, {
			Name = skin.id,
			Parent = grid,
			LayoutOrder = index,
			TextColor3 = Color.Text,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Kit.new("UIStroke", {
			Parent = button,
			Color = rgb(Skins.TIER_INFO[skin.tier].color),
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		local id = skin.id
		Kit.onClick(button, function()
			actions.preview(id)
		end)
		buttons[id] = button
	end

	local resultToken = 0
	local function showResultText(text: string, isError: boolean)
		resultToken += 1
		local token = resultToken
		resultLabel.Text = text
		resultLabel.TextColor3 = if isError then Color.Error else Color.Text
		task.delay(4, function()
			if token == resultToken then
				resultLabel.Text = ""
			end
		end)
	end

	---------------------------------------------------------------- 명령 탭 (m5-11)
	local commandList = Kit.new("ScrollingFrame", {
		Name = "Commands",
		Parent = commandPage,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color.SubText,
	}, {
		Kit.list(Enum.FillDirection.Vertical, GAP),
	})

	local commandButtons: { TextButton } = {}
	local rowHeights: { Frame } = {}
	local sectionLabels: { TextLabel } = {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function section(text: string)
		local label = Kit.label({
			Parent = commandList,
			LayoutOrder = nextOrder(),
			Text = text,
			TextSize = 14,
			TextColor3 = Color.SubText,
			Size = UDim2.new(1, -8, 0, 18),
		})
		table.insert(sectionLabels, label)
	end

	-- 버튼 한 줄 (가로로 같은 너비)
	local function row(items: { { text: string, color: Color3, onClick: () -> () } }): { TextButton }
		local frame = Kit.new("Frame", {
			Parent = commandList,
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		}, {
			Kit.list(Enum.FillDirection.Horizontal, GAP),
		})
		table.insert(rowHeights, frame)
		local count = #items
		local made: { TextButton } = {}
		for index, item in items do
			local button = Kit.button(item.text, item.color, {
				Parent = frame,
				LayoutOrder = index,
				Size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			Kit.onClick(button, item.onClick)
			table.insert(commandButtons, button)
			table.insert(made, button)
		end
		return made
	end

	local function send(name: string, args: any): () -> ()
		return function()
			actions.command(name, args)
		end
	end

	section("상태")
	row({ { text = "ℹ info", color = Color.Nori, onClick = send("info", nil) } })

	section("매치 (Studio 전용)")
	row({ { text = "▶ 바로 시작 (혼자여도)", color = Color.Salmon, onClick = send("start", nil) } })

	-- 맵 순서 쌓기
	local planIds: { string } = {}
	local planLabel = Kit.label({
		Name = "PlanLabel",
		Parent = commandList,
		LayoutOrder = nextOrder(),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Size = UDim2.new(1, -8, 0, 36),
	})
	local function paintPlan()
		planLabel.Text = if #planIds == 0
			then "맵 순서: (아래 맵을 3~4개 눌러요)"
			else `맵 순서: {table.concat(planIds, " → ")}`
	end
	local mapGrid = Kit.new("Frame", {
		Name = "MapGrid",
		Parent = commandList,
		LayoutOrder = nextOrder(),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local mapGridLayout = Kit.new("UIGridLayout", {
		Parent = mapGrid,
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.new(0.5, -GAP, 0, 30),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIGridLayout
	local mapButtons: { TextButton } = {}
	for index, id in options.mapIds do
		local button = Kit.button(id, Color.Row, {
			Name = id,
			Parent = mapGrid,
			LayoutOrder = index,
			TextColor3 = Color.Text,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Kit.onClick(button, function()
			if #planIds < PLAN_MAX then
				table.insert(planIds, id)
				paintPlan()
			end
		end)
		table.insert(commandButtons, button)
		table.insert(mapButtons, button)
	end
	row({
		{
			text = "다음 판에 쓰기",
			color = Color.Salmon,
			onClick = function()
				actions.command("plan", table.clone(planIds))
			end,
		},
		{
			text = "비우기",
			color = Color.Neutral,
			onClick = function()
				table.clear(planIds)
				paintPlan()
			end,
		},
	})
	paintPlan()

	section("내 재화 (Studio 전용)")
	row({
		{ text = "코인 +100", color = Color.Egg, onClick = send("coins", 100) },
		{ text = "+1000", color = Color.Egg, onClick = send("coins", 1000) },
		{ text = "−1000", color = Color.Neutral, onClick = send("coins", -1000) },
	})
	row({
		{ text = "이벤트 재화 +10", color = Color.Egg, onClick = send("tokens", 10) },
		{ text = "+80", color = Color.Egg, onClick = send("tokens", 80) },
	})
	row({ -- m5-31: 🎫 뽑기 티켓 (0~99로 잘려요)
		{ text = "🎫 티켓 +1", color = Color.Egg, onClick = send("tickets", 1) },
		{ text = "+10", color = Color.Egg, onClick = send("tickets", 10) },
		{ text = "+98", color = Color.Egg, onClick = send("tickets", 98) },
		{ text = "0으로", color = Color.Neutral, onClick = send("tickets", -99) },
	})

	section("연출 미리보기 (저장 안 됨)")
	for _, slot in FxCatalog.SLOTS do
		local items = {
			{
				text = if slot == "Elimination" then "탈락: 기본" else "우승: 기본",
				color = Color.Neutral,
				onClick = send("fx", { slot, "off" }),
			},
		}
		for _, fx in FxCatalog.bySlot(slot) do
			table.insert(items, { text = fx.displayName, color = Color.Nori, onClick = send("fx", { slot, fx.id }) })
		end
		row(items)
	end

	if options.showReset then
		section("Studio 전용 · 되돌릴 수 없음")
		local armedUntil = 0
		row({
			{
				text = "프로필 초기화 (두 번 눌러요)",
				color = Color.Error,
				onClick = function()
					local now = os.clock()
					if now <= armedUntil then
						armedUntil = 0
						actions.command("resetprofile", nil)
						return
					end
					armedUntil = now + RESET_CONFIRM_SECONDS
					showResultText("한 번 더 누르면 프로필을 초기화해요", true)
				end,
			},
		})
	end

	local function showPage(commands: boolean)
		previewPage.Visible = not commands
		commandPage.Visible = commands
		Kit.setSelected(previewTab, not commands)
		Kit.setSelected(commandTab, commands)
	end
	Kit.onClick(previewTab, function()
		showPage(false)
	end)
	Kit.onClick(commandTab, function()
		showPage(true)
	end)
	showPage(false)

	local open = false
	local current: string? = nil
	local busy = false

	local function paint()
		for id, button in buttons do
			local on = id == current
			button.BackgroundColor3 = if on then HIGHLIGHT else Color.Row
			button.TextColor3 = if on then Color.White else Color.Text
			button.Active = not busy
			button.AutoButtonColor = not busy
		end
		Kit.setEnabled(offButton, not busy and current ~= nil)
		for _, button in commandButtons do
			button.Active = not busy
			button.AutoButtonColor = not busy
		end
	end

	local screen = {} :: AdminPanel
	screen.gui = gui

	function screen.setOpen(_self: AdminPanel, value: boolean)
		open = value
		panel.Visible = value
	end

	function screen.isOpen(_self: AdminPanel): boolean
		return open
	end

	function screen.setCurrent(_self: AdminPanel, skinId: string?)
		current = skinId
		paint()
	end

	function screen.setBusy(_self: AdminPanel, value: boolean)
		busy = value
		paint()
	end

	function screen.showResult(_self: AdminPanel, text: string, isError: boolean)
		showResultText(text, isError)
	end

	function screen.setLayout(_self: AdminPanel, m: UiLayout.Metrics)
		local function text(base: number): number
			return UiLayout.textSize(base, m)
		end
		local button = UiLayout.touchSize(BUTTON_SIZE, m)
		openButton.Size = UDim2.fromOffset(button, button)
		panel.Position = UDim2.new(0, MARGIN + button + GAP, 0.5, 0)
		title.TextSize = text(16)
		local tab = UiLayout.lineHeight(TAB_HEIGHT, m, 16)
		tabRow.Size = UDim2.new(1, 0, 0, tab)
		previewTab.TextSize = text(16)
		commandTab.TextSize = text(16)
		for _, p in { previewPage, commandPage } do
			p.Position = UDim2.fromOffset(0, tab + GAP)
			p.Size = UDim2.new(1, 0, 1, -(tab + GAP + 26))
		end
		local rowHeight = UiLayout.lineHeight(ROW_HEIGHT, m, 15)
		for _, frame in rowHeights do
			frame.Size = UDim2.new(1, -8, 0, rowHeight)
		end
		for _, b in commandButtons do
			b.TextSize = text(15)
		end
		for _, b in mapButtons do
			b.TextSize = text(13)
		end
		for _, label in sectionLabels do
			label.TextSize = text(14)
		end
		planLabel.TextSize = text(14)
		mapGridLayout.CellSize = UDim2.new(0.5, -GAP, 0, UiLayout.lineHeight(30, m, 13))
		commandList.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		resultLabel.TextSize = text(14)
		offButton.TextSize = text(16)
		local cell = UiLayout.lineHeight(CELL_HEIGHT, m, 15)
		gridLayout.CellSize = UDim2.new(0.5, -GAP, 0, cell)
		for _, b in buttons do
			b.TextSize = text(15)
		end
		grid.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		if m.compact then
			-- 휴대폰: 화면 높이에 맞추고 격자는 스크롤
			panel.Size = UDim2.new(0, PANEL_SIZE.X, 0.9, 0)
		else
			panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
		end
	end

	paint()
	return screen
end

return AdminPanel
