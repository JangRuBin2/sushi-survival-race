--!strict
-- 테스트용 관리자 패널 화면 (m5-02). 자기 ScreenGui `AdminPanel`. AdminController가 관리자에게만 만들어요.
--   열기 버튼 "🛠": 왼쪽 가장자리 세로 가운데 (위쪽 바 줄·탈의실 버튼(왼쪽 위)·관전/터치 버튼(아래)과 겹치지 않아요).
--   패널: 제목 "🛠 테스트 착용 (저장 안 됨)", 스킨 16종 버튼 격자(이름 + 등급 색, Skins.LIST 순서),
--         미리보기 중인 스킨 강조, "끄기 (내 스킨으로)" 버튼, 결과 한 줄. compact(휴대폰)는 스크롤.
-- 보여 주기만 하고 요청은 actions로 넘겨요. 판정은 서버 AdminService가 해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Skins)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	toggle: () -> (),
	preview: (skinId: string?) -> (), -- nil이면 끄기
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
local PANEL_SIZE = Vector2.new(360, 420)
local HIGHLIGHT = Color3.fromRGB(40, 160, 90)

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

function AdminPanel.new(playerGui: Instance, actions: Actions): AdminPanel
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

	local title = Kit.label({
		Name = "Title",
		Parent = panel,
		Text = "🛠 테스트 착용 (저장 안 됨)",
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 26),
	})

	local offButton = Kit.button("끄기 (내 스킨으로)", Color.Salmon, {
		Name = "OffButton",
		Parent = panel,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -26),
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
		Parent = panel,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -(30 + 38 + 26 + GAP)),
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

	local open = false
	local current: string? = nil
	local busy = false
	local resultToken = 0

	local function paint()
		for id, button in buttons do
			local on = id == current
			button.BackgroundColor3 = if on then HIGHLIGHT else Color.Row
			button.TextColor3 = if on then Color.White else Color.Text
			button.Active = not busy
			button.AutoButtonColor = not busy
		end
		Kit.setEnabled(offButton, not busy and current ~= nil)
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

	function screen.setLayout(_self: AdminPanel, m: UiLayout.Metrics)
		local function text(base: number): number
			return UiLayout.textSize(base, m)
		end
		local button = UiLayout.touchSize(BUTTON_SIZE, m)
		openButton.Size = UDim2.fromOffset(button, button)
		panel.Position = UDim2.new(0, MARGIN + button + GAP, 0.5, 0)
		title.TextSize = text(18)
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
