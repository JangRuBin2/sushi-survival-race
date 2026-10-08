--!strict
-- 탈의실 화면 (m4-13, GDD 3.1·9). 자기 ScreenGui `ShopGui`. 보여 주기만 하고 요청은 actions로 넘겨요.
--   열기 버튼 "🍣 스킨": 왼쪽 위 (코인 배지 아래). ShopController가 보일지 정해요 (로비·대기실·관전·대기석).
--   창: 등급 탭(전체/일반/레어/에픽/전설) + 스킨 카드 격자(이름, 등급 색 테두리, 상태 글씨) +
--       큰 미리보기(ViewportFrame + SushiBody.build, 천천히 회전) + 말풍선 대사 + 행동 버튼 + 결과 글씨.
--   compact(휴대폰): 카드 2열, 미리보기는 위쪽. 그 밖: 미리보기 왼쪽, 카드 3열.
-- 카드 상태 글씨·버튼 활성은 Shared.ShopLogic.cardState. 로벅스(m4-14)는 상품 id가 있거나 Studio 가짜 결제일 때만
-- 켜지고, 아니면 "곧 열려요" 비활성. 일반 스킨은 코인 해금 버튼 아래에 "R$ 49로 사기" 버튼이 하나 더 있어요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	open: () -> (),
	close: () -> (),
	select: (skinId: string) -> (),
	act: (skinId: string) -> (), -- 선택한 스킨의 행동 버튼 (입기 / 해금 / 로벅스 레어 이상)
	buyRobux: (skinId: string) -> (), -- 일반 스킨의 두 번째 버튼 "R$ 49로 사기" (m4-14)
	tab: (tier: Skins.Tier?) -> (),
}

export type ShopScreen = {
	gui: ScreenGui,
	setButtonVisible: (self: ShopScreen, visible: boolean) -> (),
	setOpen: (self: ShopScreen, open: boolean) -> (),
	isOpen: (self: ShopScreen) -> boolean,
	render: (
		self: ShopScreen,
		view: ShopLogic.ViewLike,
		tier: Skins.Tier?,
		selected: string,
		robux: ShopLogic.RobuxOptions?
	) -> (),
	setBusy: (self: ShopScreen, busy: boolean) -> (),
	showResult: (self: ShopScreen, text: string, isError: boolean) -> (),
	setLayout: (self: ShopScreen, m: UiLayout.Metrics) -> (),
}

local ShopScreen = {}

local WINDOW_MAX = Vector2.new(880, 580)
local GAP = 8
local CARD_HEIGHT = 70
local SPIN_SPEED = 0.8 -- rad/s
local TABS: { { tier: Skins.Tier?, label: string } } = {
	{ tier = nil, label = "전체" },
	{ tier = "Common", label = "일반" },
	{ tier = "Rare", label = "레어" },
	{ tier = "Epic", label = "에픽" },
	{ tier = "Legendary", label = "전설" },
}

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

local function tierColor(tier: Skins.Tier): Color3
	return rgb(Skins.TIER_INFO[tier].color)
end

function ShopScreen.new(playerGui: Instance, actions: Actions): ShopScreen
	local gui = Kit.new("ScreenGui", {
		Name = "ShopGui",
		ResetOnSpawn = false,
		DisplayOrder = 20, -- 로비·HUD(0) 위, 코인 토스트(55) 아래
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local openButton = Kit.button("🍣 스킨", Color.Salmon, {
		Name = "SkinButton",
		Parent = gui,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(110, 44),
		Visible = false,
	})
	Kit.onClick(openButton, actions.open)

	-- 창 뒤를 어둡게 가리고 클릭을 막아요
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

	-- 머리줄: 제목 · 코인 · 닫기
	local header = Kit.new("Frame", {
		Name = "Header",
		Parent = window,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	})
	local titleLabel = Kit.label({
		Parent = header,
		Text = "🍣 탈의실",
		TextSize = 24,
		Size = UDim2.fromScale(0.5, 1),
	})
	local coinLabel = Kit.label({
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 0),
		Size = UDim2.fromScale(0.4, 1),
		Text = "🍚 0",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local closeButton = Kit.button("✕", Color.Nori, {
		Name = "Close",
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
	})
	Kit.onClick(closeButton, actions.close)

	-- 등급 탭
	local tabRow = Kit.new("Frame", {
		Name = "Tabs",
		Parent = window,
		Position = UDim2.fromOffset(0, 40 + GAP),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local tabButtons: { { button: TextButton, tier: Skins.Tier? } } = {}
	for i, tab in TABS do
		local color = if tab.tier then tierColor(tab.tier) else Color.Salmon
		local button = Kit.button(tab.label, color, {
			Parent = tabRow,
			LayoutOrder = i,
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
			TextSize = 16,
		})
		local tier = tab.tier
		Kit.onClick(button, function()
			actions.tab(tier)
		end)
		table.insert(tabButtons, { button = button, tier = tier })
	end

	-- 본문: 미리보기 칸 + 카드 격자
	local content = Kit.new("Frame", {
		Name = "Content",
		Parent = window,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 88 + GAP),
		Size = UDim2.new(1, 0, 1, -(88 + GAP)),
	})

	local previewPane = Kit.new("Frame", {
		Name = "Preview",
		Parent = content,
		BackgroundColor3 = Color.Row,
	}, { Kit.corner(12), Kit.padding(8) })

	local viewport = Kit.new("ViewportFrame", {
		Name = "Viewport",
		Parent = previewPane,
		BackgroundColor3 = Color3.fromRGB(255, 240, 215),
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
	}, { Kit.corner(10) }) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -10), Vector3.new(0, 0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local infoBox = Kit.new("Frame", {
		Name = "Info",
		Parent = previewPane,
		BackgroundTransparency = 1,
	}, { Kit.list(Enum.FillDirection.Vertical, 4) })
	local nameLabel = Kit.label({ Parent = infoBox, LayoutOrder = 1, TextSize = 20, Text = "" })
	local tierLabel = Kit.label({ Parent = infoBox, LayoutOrder = 2, TextSize = 15, Text = "" })
	local speechLabel = Kit.label({
		Parent = infoBox,
		LayoutOrder = 3,
		TextSize = 15,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color.SubText,
		Text = "",
		Size = UDim2.new(1, 0, 0, 36),
	})
	local actionButton = Kit.button("입기", Color.Salmon, {
		Name = "Action",
		Parent = infoBox,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 17,
	})
	local robuxButton = Kit.button("R$", Color.Egg, {
		Name = "Robux",
		Parent = infoBox,
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 15,
		Visible = false,
	})
	local resultLabel = Kit.label({
		Name = "Result",
		Parent = infoBox,
		LayoutOrder = 6,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Size = UDim2.new(1, 0, 0, 20),
	})

	local grid = Kit.new("ScrollingFrame", {
		Name = "Cards",
		Parent = content,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color.SubText,
	}) :: ScrollingFrame
	local gridLayout = Kit.new("UIGridLayout", {
		Parent = grid,
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.new(1 / 3, -GAP, 0, CARD_HEIGHT),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIGridLayout
	Kit.new("UIPadding", { Parent = grid, PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) })

	type Card = { button: TextButton, stroke: UIStroke, name: TextLabel, status: TextLabel }
	local cards: { [string]: Card } = {}
	for _, skin in Skins.LIST do
		local button = Kit.new("TextButton", {
			Name = skin.id,
			Parent = grid,
			LayoutOrder = skin.order,
			BackgroundColor3 = Color.White,
			Text = "",
			AutoButtonColor = true,
		}, { Kit.corner(10), Kit.padding(6) }) :: TextButton
		local stroke = Kit.new("UIStroke", {
			Parent = button,
			Color = tierColor(skin.tier),
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}) :: UIStroke
		local name = Kit.label({
			Parent = button,
			Text = skin.displayName,
			TextSize = 16,
			Size = UDim2.fromScale(1, 0.55),
			TextScaled = false,
		})
		local status = Kit.label({
			Parent = button,
			Position = UDim2.fromScale(0, 0.55),
			Size = UDim2.fromScale(1, 0.45),
			Text = "",
			TextSize = 13,
			TextColor3 = Color.SubText,
		})
		local id = skin.id
		Kit.onClick(button, function()
			actions.select(id)
		end)
		cards[skin.id] = { button = button, stroke = stroke, name = name, status = status }
	end

	local selectedId = Skins.DEFAULT_ID
	Kit.onClick(actionButton, function()
		actions.act(selectedId)
	end)
	Kit.onClick(robuxButton, function()
		actions.buyRobux(selectedId)
	end)

	-- 미리보기 인형: 바뀔 때만 다시 만들고, 창이 열려 있을 때만 돌려요
	local previewModel: Model? = nil
	local previewId: string? = nil
	local spinConnection: RBXScriptConnection? = nil
	local angle = 0

	local function setPreview(skinId: string)
		if previewId == skinId and previewModel then
			return
		end
		if previewModel then
			previewModel:Destroy()
		end
		local ok, model = pcall(SushiBody.build, skinId)
		if not ok then
			warn(`[ShopScreen] preview failed: {model}`)
			previewModel = nil
			previewId = nil
			return
		end
		previewId = skinId
		previewModel = model
		model:PivotTo(CFrame.Angles(0, angle, 0))
		model.Parent = viewport
	end

	local function startSpin()
		if spinConnection then
			return
		end
		spinConnection = RunService.RenderStepped:Connect(function(dt: number)
			angle = (angle + dt * SPIN_SPEED) % (math.pi * 2)
			local model = previewModel
			if model then
				model:PivotTo(CFrame.Angles(0, angle, 0))
			end
		end)
	end

	local function stopSpin()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end

	local busy = false
	local currentState: ShopLogic.CardState? = nil
	local resultToken = 0

	local function refreshAction()
		local state = currentState
		if state == nil then
			return
		end
		actionButton.Text = ShopLogic.cardButtonText(state)
		Kit.setEnabled(actionButton, state.enabled and not busy)
		local robuxText = ShopLogic.robuxButtonText(state)
		robuxButton.Visible = robuxText ~= nil
		if robuxText then
			robuxButton.Text = robuxText
			Kit.setEnabled(robuxButton, state.robuxEnabled == true and not busy)
		end
	end

	local screen = {} :: ShopScreen
	screen.gui = gui

	function screen.setButtonVisible(_self: ShopScreen, visible: boolean)
		openButton.Visible = visible
	end

	function screen.setOpen(_self: ShopScreen, open: boolean)
		backdrop.Visible = open
		if open then
			startSpin()
		else
			stopSpin()
		end
	end

	function screen.isOpen(_self: ShopScreen): boolean
		return backdrop.Visible
	end

	function screen.render(
		_self: ShopScreen,
		view: ShopLogic.ViewLike,
		tier: Skins.Tier?,
		selected: string,
		robux: ShopLogic.RobuxOptions?
	)
		coinLabel.Text = `🍚 {view.coins}`
		for _, tab in tabButtons do
			Kit.setSelected(tab.button, tab.tier == tier)
		end
		for _, skin in Skins.LIST do
			local card = cards[skin.id]
			card.button.Visible = tier == nil or skin.tier == tier
			local state = ShopLogic.cardState(skin, view, robux)
			card.status.Text = ShopLogic.cardButtonText(state)
			card.status.TextColor3 = if state.kind == "Equipped" then Color.Salmon else Color.SubText
			card.button.BackgroundColor3 = if skin.id == selected then Color.Row else Color.White
			card.stroke.Thickness = if skin.id == selected then 4 else 2
		end

		local skin = Skins.get(selected) or Skins.get(Skins.DEFAULT_ID) :: Skins.Skin
		if selectedId ~= skin.id then
			-- 다른 카드를 고르면 대사를 새로 뽑고 결과 글씨를 지워요
			speechLabel.Text = `💬 "{skin.speech[math.random(1, #skin.speech)]}"`
			resultLabel.Text = ""
		elseif speechLabel.Text == "" then
			speechLabel.Text = `💬 "{skin.speech[1]}"`
		end
		selectedId = skin.id
		nameLabel.Text = skin.displayName
		local info = Skins.TIER_INFO[skin.tier]
		tierLabel.Text = info.displayName
		tierLabel.TextColor3 = rgb(info.color)
		setPreview(skin.id)
		currentState = ShopLogic.cardState(skin, view, robux)
		refreshAction()
	end

	function screen.setBusy(_self: ShopScreen, value: boolean)
		busy = value
		refreshAction()
	end

	function screen.showResult(_self: ShopScreen, text: string, isError: boolean)
		resultToken += 1
		local mine = resultToken
		resultLabel.Text = text
		resultLabel.TextColor3 = if isError then Color.Error else Color.Nori
		task.delay(4, function()
			if resultToken == mine then
				resultLabel.Text = ""
			end
		end)
	end

	function screen.setLayout(_self: ShopScreen, m: UiLayout.Metrics)
		local text = function(base: number): number
			return UiLayout.textSize(base, m)
		end
		local buttonHeight = UiLayout.touchSize(44, m)
		openButton.Size = UDim2.fromOffset(110, buttonHeight)
		openButton.TextSize = text(18)
		closeButton.Size = UDim2.fromOffset(buttonHeight, buttonHeight)
		header.Size = UDim2.new(1, 0, 0, buttonHeight)
		titleLabel.TextSize = text(24)
		coinLabel.TextSize = text(20)
		coinLabel.Position = UDim2.new(1, -(buttonHeight + 8), 0, 0)
		local tabHeight = UiLayout.touchSize(36, m)
		tabRow.Position = UDim2.fromOffset(0, buttonHeight + GAP)
		tabRow.Size = UDim2.new(1, 0, 0, tabHeight)
		for _, tab in tabButtons do
			tab.button.TextSize = text(16)
		end
		local top = buttonHeight + GAP + tabHeight + GAP
		content.Position = UDim2.fromOffset(0, top)
		content.Size = UDim2.new(1, 0, 1, -top)

		nameLabel.TextSize = text(20)
		nameLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(24, m, 20))
		tierLabel.TextSize = text(15)
		tierLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(20, m, 15))
		speechLabel.TextSize = text(15)
		actionButton.Size = UDim2.new(1, 0, 0, buttonHeight)
		actionButton.TextSize = text(17)
		robuxButton.Size = UDim2.new(1, 0, 0, UiLayout.touchSize(36, m))
		robuxButton.TextSize = text(15)
		resultLabel.TextSize = text(14)
		grid.ScrollBarThickness = UiLayout.scrollBarThickness(m)

		local cardHeight = math.max(CARD_HEIGHT, UiLayout.touchSize(CARD_HEIGHT, m))
		for _, card in cards do
			card.name.TextSize = text(16)
			card.status.TextSize = text(13)
		end

		if m.compact then
			-- 휴대폰: 미리보기(인형 + 정보)가 위, 카드 2열이 아래
			window.AnchorPoint = Vector2.new(0.5, 0)
			window.Position = UDim2.fromScale(0.5, 0.03)
			window.Size = UDim2.fromScale(0.96, 0.94)
			previewPane.Position = UDim2.fromScale(0, 0)
			previewPane.Size = UDim2.new(1, 0, 0.45, -GAP / 2)
			viewport.Size = UDim2.fromScale(0.4, 1)
			infoBox.Position = UDim2.new(0.4, GAP, 0, 0)
			infoBox.Size = UDim2.new(0.6, -GAP, 1, 0)
			grid.Position = UDim2.new(0, 0, 0.45, GAP / 2)
			grid.Size = UDim2.new(1, 0, 0.55, -GAP / 2)
			gridLayout.CellSize = UDim2.new(0.5, -GAP, 0, cardHeight)
		else
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.Position = UDim2.fromScale(0.5, 0.5)
			window.Size = UDim2.fromScale(0.94, 0.9)
			previewPane.Position = UDim2.fromScale(0, 0)
			previewPane.Size = UDim2.new(0.36, -GAP / 2, 1, 0)
			viewport.Size = UDim2.fromScale(1, 0.55)
			infoBox.Position = UDim2.new(0, 0, 0.55, GAP)
			infoBox.Size = UDim2.new(1, 0, 0.45, -GAP)
			grid.Position = UDim2.new(0.36, GAP / 2, 0, 0)
			grid.Size = UDim2.new(0.64, -GAP / 2, 1, 0)
			gridLayout.CellSize = UDim2.new(1 / 3, -GAP, 0, cardHeight)
		end
	end

	return screen
end

return ShopScreen
