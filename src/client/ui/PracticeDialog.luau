--!strict
-- 1인 연습 맵 고르기 창 (m6-13). 로비의 "연습" 버튼이 열어요.
-- 맵 버튼을 누르면 onPick(mapId) → LobbyController가 StartPractice 요청. 이 창은 보여 주기만 해요.
-- 맵 목록은 처음 열 때 Shared.maps(랜덤 판 풀)에서 읽어 Race → Survival → Final 순서로 만들어요 (PracticeLogic.orderedMaps).
-- 게임패드 (m5-12): GamepadNav.window (B = 닫기, 첫 버튼 = 첫 맵).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PracticeLogic = require(ReplicatedStorage.Shared.PracticeLogic)
local Rules = require(ReplicatedStorage.Shared.Rules)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local GamepadNav = require(script.Parent.GamepadNav)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type PracticeDialog = {
	open: (self: PracticeDialog) -> (),
	close: (self: PracticeDialog) -> (),
	isOpen: (self: PracticeDialog) -> boolean,
	setBusy: (self: PracticeDialog, busy: boolean) -> (),
	showMessage: (self: PracticeDialog, text: string, isError: boolean?) -> (),
	applyLayout: (self: PracticeDialog, m: UiLayout.Metrics, virtualWidth: number, virtualHeight: number) -> (),
}

local PracticeDialog = {}

local MAX_WIDTH = 560
local PADDING = 16
local GAP = 8
local CELL_GAP = 6
local MIN_CELL_WIDTH = 150

local function kindTitle(kind: string): string
	if kind == "Survival" then
		return Loc.t("lobby.practice.kind.Survival")
	elseif kind == "Final" then
		return Loc.t("lobby.practice.kind.Final")
	end
	return Loc.t("lobby.practice.kind.Race")
end

local function kindColor(kind: string): Color3
	if kind == "Survival" then
		return Color.Nori
	elseif kind == "Final" then
		return Color.Egg
	end
	return Color.Salmon
end

function PracticeDialog.new(parent: Instance, onPick: (mapId: string) -> ()): PracticeDialog
	local busy = false
	local built = false
	local mapButtons: { TextButton } = {}
	local grids: { UIGridLayout } = {}
	local kindLabels: { TextLabel } = {}
	local lastLayout: { m: UiLayout.Metrics, width: number, height: number }? = nil

	local backdrop = Kit.new("TextButton", { -- 뒤 화면 클릭을 막는 배경
		Name = "PracticeDialog",
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
	local panel = Kit.new("ScrollingFrame", {
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.86, 0),
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
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, math.huge) }),
	})

	local title = Kit.label({
		Parent = panel,
		LayoutOrder = 1,
		Text = Loc.t("lobby.practice.title"),
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 12,
	})
	local desc = Kit.label({
		Parent = panel,
		LayoutOrder = 2,
		Text = Loc.t("lobby.practice.desc"),
		TextColor3 = Color.SubText,
		TextSize = 15,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 12,
	})
	local closeButton = Kit.button(Loc.t("lobby.practice.close.btn"), Color.Neutral, {
		Parent = panel,
		LayoutOrder = 1000,
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = Color.Text,
		ZIndex = 13,
	})
	local showMessage, messageLabel = Kit.messageLabel(panel, 1001)

	local function refreshEnabled()
		for _, button in mapButtons do
			Kit.setEnabled(button, not busy)
		end
	end

	local function layoutGrids()
		local layout = lastLayout
		if layout == nil then
			return
		end
		local m = layout.m
		local touch = UiLayout.touchSize(44, m)
		local scrollBar = UiLayout.scrollBarThickness(m)
		local inner = math.min(layout.width * 0.92, MAX_WIDTH) - PADDING * 2 - scrollBar
		local perRow = UiLayout.gridRows(3, inner, MIN_CELL_WIDTH, CELL_GAP)
		perRow = math.max(1, math.min(perRow, 3))
		for _, grid in grids do
			grid.CellSize = UDim2.new(1 / perRow, -CELL_GAP, 0, touch)
		end
		for _, button in mapButtons do
			button.TextSize = UiLayout.textSize(16, m)
		end
		for _, label in kindLabels do
			label.TextSize = UiLayout.textSize(16, m)
			label.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(24, m, 16))
		end
	end

	-- 맵 버튼은 처음 열 때 만들어요 (로비를 띄울 때 맵 모듈 26개를 읽지 않게)
	local function build()
		if built then
			return
		end
		built = true
		local Maps = require(ReplicatedStorage.Shared.maps) :: any
		local infos: { Rules.MapInfo } = PracticeLogic.orderedMaps(Maps.infos())
		local order = 10
		local currentKind: string? = nil
		local grid: Frame? = nil
		for _, info in infos do
			if info.kind ~= currentKind then
				currentKind = info.kind
				order += 1
				local label = Kit.label({
					Parent = panel,
					LayoutOrder = order,
					Text = kindTitle(info.kind),
					TextColor3 = Color.SubText,
					TextSize = 16,
					Size = UDim2.new(1, 0, 0, 24),
					ZIndex = 12,
				})
				table.insert(kindLabels, label)
				order += 1
				local frame = Kit.new("Frame", {
					Parent = panel,
					LayoutOrder = order,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					ZIndex = 12,
				})
				local layout = Kit.new("UIGridLayout", {
					Parent = frame,
					SortOrder = Enum.SortOrder.LayoutOrder,
					CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
					CellSize = UDim2.new(1 / 3, -CELL_GAP, 0, 44),
				}) :: UIGridLayout
				table.insert(grids, layout)
				grid = frame
			end
			local button = Kit.button(Loc.mapName(info.id), kindColor(info.kind), {
				Parent = grid,
				LayoutOrder = #mapButtons + 1,
				TextSize = 16,
				TextWrapped = true,
				TextColor3 = if info.kind == "Final" then Color.Text else Color.White,
				ZIndex = 13,
			})
			button:SetAttribute("MapId", info.id)
			local mapId = info.id
			Kit.onClick(button, function()
				if not busy then
					onPick(mapId)
				end
			end)
			table.insert(mapButtons, button)
		end
		refreshEnabled()
		layoutGrids()
	end

	Kit.onClick(closeButton, function()
		backdrop.Visible = false
	end)

	GamepadNav.window({
		root = backdrop,
		group = panel,
		close = function()
			backdrop.Visible = false
		end,
		first = function(): GuiObject?
			return mapButtons[1] or closeButton
		end,
	})

	local dialog = {}

	function dialog.open(_self: PracticeDialog)
		build()
		messageLabel.Text = ""
		panel.CanvasPosition = Vector2.zero
		backdrop.Visible = true
	end

	function dialog.close(_self: PracticeDialog)
		backdrop.Visible = false
	end

	function dialog.isOpen(_self: PracticeDialog): boolean
		return backdrop.Visible
	end

	function dialog.setBusy(_self: PracticeDialog, value: boolean)
		busy = value
		refreshEnabled()
	end

	function dialog.showMessage(_self: PracticeDialog, text: string, isError: boolean?)
		showMessage(text, isError)
	end

	function dialog.applyLayout(_self: PracticeDialog, m: UiLayout.Metrics, virtualWidth: number, virtualHeight: number)
		lastLayout = { m = m, width = virtualWidth, height = virtualHeight }
		local touch = UiLayout.touchSize(44, m)
		title.TextSize = UiLayout.textSize(22, m)
		title.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(30, m, 22))
		desc.TextSize = UiLayout.textSize(15, m)
		closeButton.Size = UDim2.new(1, 0, 0, touch)
		closeButton.TextSize = UiLayout.textSize(18, m)
		messageLabel.TextSize = UiLayout.textSize(16, m)
		messageLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(22, m, 16))
		panel.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		local height = math.max(200, virtualHeight * 0.9 - 8)
		panel.Size = UDim2.new(0.92, 0, 0, height)
		if m.compact then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0, 8)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
		end
		layoutGrids()
	end

	return (dialog :: any) :: PracticeDialog
end

return PracticeDialog
