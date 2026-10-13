--!strict
-- "🎁 상점" 화면 (m5-08). 자기 ScreenGui `OfferGui`. 보여 주기만 하고 요청은 actions로 넘겨요 (OfferController).
--   열기 버튼 "🎁 상점": 왼쪽 위 "🍣 스킨" 버튼 바로 아래 (12, 60), 110 × 44. 보일지는 OfferController가 정해요.
--   창: 머리줄(제목·닫기) + 결과 한 줄 + 세로 스크롤 목록 1열:
--       "내 연출" 칸 (가진 연출마다 "입기" / "입는 중 · 벗기", 가진 연출이 없으면 숨김)
--       상품 카드 (이름, 주는 것, "따로 사면 R$ …", 가격 버튼 "R$ 79로 사기" / "곧 열려요" / "산 상품" 회색)
--   휴대폰(compact)도 1열 스크롤, 버튼은 UiLayout.touchSize(44) 이상. 색·모양은 RoomUiKit (탈의실과 같아요).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type CardModel = {
	id: string,
	name: string,
	lines: { string },
	value: string?, -- "따로 사면 R$ 146"
	buttonText: string,
	enabled: boolean,
	bought: boolean, -- 산 상품 (회색)
	order: number,
}

export type FxRowModel = {
	id: string,
	slot: string,
	name: string, -- "고양이 손님 (탈락 연출)"
	equipped: boolean,
}

export type Model = { cards: { CardModel }, fx: { FxRowModel } }

export type Actions = {
	open: () -> (),
	close: () -> (),
	buy: (offerId: string) -> (),
	equipFx: (slot: string, fxId: string?) -> (), -- fxId nil = 벗기
}

export type OfferScreen = {
	gui: ScreenGui,
	setButtonVisible: (self: OfferScreen, visible: boolean) -> (),
	setOpen: (self: OfferScreen, open: boolean) -> (),
	isOpen: (self: OfferScreen) -> boolean,
	render: (self: OfferScreen, model: Model) -> (),
	setBusy: (self: OfferScreen, busy: boolean) -> (),
	showResult: (self: OfferScreen, text: string, isError: boolean) -> (),
	setLayout: (self: OfferScreen, m: UiLayout.Metrics) -> (),
}

local OfferScreen = {}

local WINDOW_MAX = Vector2.new(720, 600)
local GAP = 8
local BUTTON_WIDTH = 150
local BUTTON_WIDTH_COMPACT = 124

function OfferScreen.new(playerGui: Instance, actions: Actions): OfferScreen
	local gui = Kit.new("ScreenGui", {
		Name = "OfferGui",
		ResetOnSpawn = false,
		DisplayOrder = 20, -- 탈의실과 같은 층 (로비·HUD 위, 코인 토스트 아래)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local openButton = Kit.button("🎁 상점", Color.Egg, {
		Name = "OfferButton",
		Parent = gui,
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(110, 44),
		Visible = false,
	})
	Kit.onClick(openButton, actions.open)

	local backdrop = Kit.new("Frame", {
		Name = "Backdrop",
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.45,
		Active = true,
		Visible = false,
	})

	local window = Kit.new("Frame", {
		Name = "Window",
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = Color.Panel,
		Active = true,
	}, {
		Kit.corner(16),
		Kit.padding(12),
		Kit.new("UISizeConstraint", { MaxSize = WINDOW_MAX }),
	})

	local header = Kit.new("Frame", {
		Name = "Header",
		Parent = window,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	})
	local titleLabel = Kit.label({
		Parent = header,
		Text = "🎁 상점",
		TextSize = 24,
		Size = UDim2.new(1, -60, 1, 0),
	})
	local closeButton = Kit.button("✕", Color.Nori, {
		Name = "Close",
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
	})
	Kit.onClick(closeButton, actions.close)

	local resultLabel = Kit.label({
		Name = "Result",
		Parent = window,
		Position = UDim2.fromOffset(0, 44 + GAP),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
	})

	local list = Kit.scrollList({
		Name = "Offers",
		Parent = window,
		Position = UDim2.fromOffset(0, 44 + GAP + 22 + GAP),
		Size = UDim2.new(1, 0, 1, -(44 + GAP + 22 + GAP)),
	}, GAP) :: ScrollingFrame
	Kit.new("UIPadding", { Parent = list, PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) })

	local metrics: UiLayout.Metrics? = nil
	local busy = false
	local current: Model? = nil
	local actionButtons: { { button: TextButton, enabled: boolean } } = {}
	local resultToken = 0

	local function text(base: number): number
		local m = metrics
		return if m then UiLayout.textSize(base, m) else base
	end

	local function touch(base: number): number
		local m = metrics
		return if m then UiLayout.touchSize(base, m) else base
	end

	local function addButton(button: TextButton, enabled: boolean)
		table.insert(actionButtons, { button = button, enabled = enabled })
		Kit.setEnabled(button, enabled and not busy)
	end

	local function wrappedLabel(parent: Instance, order: number, value: string, size: number, color: Color3): TextLabel
		return Kit.label({
			Parent = parent,
			LayoutOrder = order,
			Text = value,
			TextSize = text(size),
			TextColor3 = color,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, text(size) + 4),
		})
	end

	local function buttonWidth(): number
		local m = metrics
		return if m and m.compact then BUTTON_WIDTH_COMPACT else BUTTON_WIDTH
	end

	local function buildFxSection(rows: { FxRowModel }, order: number)
		local section = Kit.new("Frame", {
			Name = "MyFx",
			Parent = list,
			LayoutOrder = order,
			BackgroundColor3 = Color.Row,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
		}, { Kit.corner(12), Kit.padding(10), Kit.list(Enum.FillDirection.Vertical, 6) })
		Kit.label({
			Parent = section,
			LayoutOrder = 0,
			Text = "✨ 내 연출",
			TextSize = text(18),
			Size = UDim2.new(1, 0, 0, text(18) + 6),
		})
		local height = touch(44)
		for i, row in rows do
			local line = Kit.new("Frame", {
				Name = row.id,
				Parent = section,
				LayoutOrder = i,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, height),
			})
			Kit.label({
				Parent = line,
				Text = row.name,
				TextSize = text(15),
				Size = UDim2.new(1, -(buttonWidth() + GAP), 1, 0),
			})
			local button = Kit.button(
				if row.equipped then "입는 중 · 벗기" else "입기",
				if row.equipped then Color.Nori else Color.Salmon,
				{
					Name = "Equip",
					Parent = line,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, buttonWidth(), 1, 0),
					TextSize = text(15),
				}
			)
			local slot, fxId = row.slot, row.id
			local equipped = row.equipped
			Kit.onClick(button, function()
				actions.equipFx(slot, if equipped then nil else fxId)
			end)
			addButton(button, true)
		end
	end

	local function buildCard(card: CardModel, order: number)
		local frame = Kit.new("Frame", {
			Name = card.id,
			Parent = list,
			LayoutOrder = order,
			BackgroundColor3 = if card.bought then Color.Neutral else Color.White,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, touch(44) + 20),
		}, { Kit.corner(12), Kit.padding(10) })
		Kit.new("UIStroke", {
			Parent = frame,
			Color = if card.bought then Color.Disabled else Color.Egg,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		local info = Kit.new("Frame", {
			Name = "Info",
			Parent = frame,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -(buttonWidth() + GAP), 0, 0),
		}, { Kit.list(Enum.FillDirection.Vertical, 2) })
		local nameColor = if card.bought then Color.SubText else Color.Text
		wrappedLabel(info, 1, card.name, 19, nameColor)
		for i, line in card.lines do
			wrappedLabel(info, 1 + i, line, 14, Color.SubText)
		end
		local value = card.value
		if value and not card.bought then
			wrappedLabel(info, 100, value, 14, Color.Salmon)
		end
		local button = Kit.button(card.buttonText, if card.bought then Color.Disabled else Color.Salmon, {
			Name = "Buy",
			Parent = frame,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(buttonWidth(), touch(44)),
			TextSize = text(15),
			TextWrapped = true,
		})
		local id = card.id
		Kit.onClick(button, function()
			actions.buy(id)
		end)
		addButton(button, card.enabled)
	end

	local function rebuild()
		local model = current
		if model == nil then
			return
		end
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(actionButtons)
		local order = 1
		if #model.fx > 0 then
			buildFxSection(model.fx, order)
			order += 1
		end
		for _, card in model.cards do
			buildCard(card, order)
			order += 1
		end
	end

	local screen = {} :: OfferScreen
	screen.gui = gui

	function screen.setButtonVisible(_self: OfferScreen, visible: boolean)
		openButton.Visible = visible
	end

	function screen.setOpen(_self: OfferScreen, open: boolean)
		backdrop.Visible = open
	end

	function screen.isOpen(_self: OfferScreen): boolean
		return backdrop.Visible
	end

	function screen.render(_self: OfferScreen, model: Model)
		current = model
		rebuild()
	end

	function screen.setBusy(_self: OfferScreen, value: boolean)
		busy = value
		for _, entry in actionButtons do
			Kit.setEnabled(entry.button, entry.enabled and not busy)
		end
	end

	function screen.showResult(_self: OfferScreen, message: string, isError: boolean)
		resultToken += 1
		local mine = resultToken
		resultLabel.Text = message
		resultLabel.TextColor3 = if isError then Color.Error else Color.Nori
		task.delay(5, function()
			if resultToken == mine then
				resultLabel.Text = ""
			end
		end)
	end

	function screen.setLayout(_self: OfferScreen, m: UiLayout.Metrics)
		metrics = m
		local buttonHeight = UiLayout.touchSize(44, m)
		openButton.Size = UDim2.fromOffset(110, buttonHeight)
		-- "🍣 스킨" 버튼(12, 10)도 같은 높이로 커져요: 그 바로 아래
		openButton.Position = UDim2.fromOffset(12, 10 + buttonHeight + 6)
		openButton.TextSize = UiLayout.textSize(18, m)
		header.Size = UDim2.new(1, 0, 0, buttonHeight)
		closeButton.Size = UDim2.fromOffset(buttonHeight, buttonHeight)
		titleLabel.Size = UDim2.new(1, -(buttonHeight + 8), 1, 0)
		titleLabel.TextSize = UiLayout.textSize(24, m)
		local resultHeight = UiLayout.lineHeight(22, m, 15)
		resultLabel.Position = UDim2.fromOffset(0, buttonHeight + GAP)
		resultLabel.Size = UDim2.new(1, 0, 0, resultHeight)
		resultLabel.TextSize = UiLayout.textSize(15, m)
		local top = buttonHeight + GAP + resultHeight + GAP
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -top)
		list.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		if m.compact then
			window.AnchorPoint = Vector2.new(0.5, 0)
			window.Position = UDim2.fromScale(0.5, 0.03)
			window.Size = UDim2.fromScale(0.96, 0.94)
		else
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.Position = UDim2.fromScale(0.5, 0.5)
			window.Size = UDim2.fromScale(0.94, 0.9)
		end
		rebuild()
	end

	return screen
end

return OfferScreen
