--!strict
-- 탈의실 화면 (m4-13, GDD 3.1·9). 자기 ScreenGui `ShopGui`. 보여 주기만 하고 요청은 actions로 넘겨요.
--   열기 버튼 "🍣 스킨": 왼쪽 위 (코인 배지 아래). ShopController가 보일지 정해요 (로비·대기실·관전·대기석).
--   창: 등급 탭(전체/일반/레어/에픽/전설) + 스킨 카드 격자(이름, 등급 색 테두리, 상태 글씨) +
--       큰 미리보기(ViewportFrame + SushiBody.build, 천천히 회전) + 말풍선 대사 + 행동 버튼 + 결과 글씨.
--   compact(휴대폰): 카드 2열, 미리보기는 위쪽. 그 밖: 미리보기 왼쪽, 카드 3열.
-- 카드 상태 글씨·버튼 활성은 Shared.ShopLogic.cardState. 로벅스(m4-14)는 상품 id가 있거나 Studio 가짜 결제일 때만
-- 켜지고, 아니면 "곧 열려요" 비활성. 일반·레어 스킨은 코인 해금 버튼 아래에 "R$ 29로 사기"(레어는 59) 버튼이 하나 더 있어요.
-- 시즌 이벤트 (m5-07): 탭은 ShopLogic.tabs(now) — 이벤트 중이면 "🎃 할로윈" 탭이 맨 앞. 이벤트 탭에서는 카드 위에
--   머리줄 "할로윈 초밥 축제 · 11월 5일까지 · 🍬 32" + 작은 안내(ShopLogic.EVENT_NOTE). 날짜로만, 카운트다운 없음 (D4).
--   보이는 카드는 ShopLogic.visibleSkins (기간 끝 + 미보유 한정 스킨은 숨김), 보유한 한정 스킨 카드 구석에 "한정".
-- 🎫 뽑기 (m5-31): 머리줄 "🎫 뽑기 N" 버튼 → 뽑기 화면(DrawScreen, ShopController가 열어요). "🎫 특" 탭(전체 다음), 특 스킨 카드 테두리는
--   Skins.DRAW_INFO 색 + 구석 "🎫 특" 표시, 미리보기 등급 줄도 "🎫 특". 티켓이 있으면 "🍣 스킨" 버튼에 빨간 숫자 배지.
-- 게임패드 (m5-12): 창이 열리면 첫 카드가 선택되고, 카드에 선택이 오면 그 스킨을 미리보기 (actions.select).
--   LB/RB = 탭 이동(끝에서 멈춤, GamepadNavLogic.nextTab), A = 누르기, B = 닫기 → "🍣 스킨" 버튼으로 돌아가요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local GamepadNav = require(script.Parent.GamepadNav)
local GamepadNavLogic = require(ReplicatedStorage.Shared.GamepadNavLogic)
local Kit = require(script.Parent.RoomUiKit)
local DollAnimator = require(script.Parent.Parent.fx.DollAnimator)

local Color = Kit.Color

export type Actions = {
	open: () -> (),
	close: () -> (),
	select: (skinId: string) -> (),
	act: (skinId: string) -> (), -- 선택한 스킨의 행동 버튼 (입기 / 해금 / 재화로 받기 / 로벅스 레어 이상)
	buyRobux: (skinId: string) -> (), -- 일반·레어 스킨의 두 번째 버튼 "R$ 29로 사기" (m4-14)
	tab: (tabId: string) -> (), -- ShopLogic.Tab.id (m5-07)
	openDraw: () -> (), -- 🎫 뽑기 화면 열기 (m5-31)
}

-- 한 번 그리기에 필요한 것 (m5-07)
export type RenderState = {
	view: ShopLogic.ViewLike,
	tab: ShopLogic.Tab,
	tabs: { ShopLogic.Tab },
	selected: string,
	robux: ShopLogic.RobuxOptions?,
	now: number?, -- 시즌 판매 기간 판단 시각
	eventHeader: string?, -- 이벤트 탭 머리줄 (이벤트 탭이 아니면 nil)
}

export type ShopScreen = {
	gui: ScreenGui,
	setButtonVisible: (self: ShopScreen, visible: boolean) -> (),
	setOpen: (self: ShopScreen, open: boolean) -> (),
	isOpen: (self: ShopScreen) -> boolean,
	render: (self: ShopScreen, state: RenderState) -> (),
	setBusy: (self: ShopScreen, busy: boolean) -> (),
	showResult: (self: ShopScreen, text: string, isError: boolean) -> (),
	setLayout: (self: ShopScreen, m: UiLayout.Metrics) -> (),
	setTickets: (self: ShopScreen, tickets: number) -> (), -- m5-31: 배지·머리줄 버튼 숫자
}

local ShopScreen = {}

local WINDOW_MAX = Vector2.new(880, 580)
local GAP = 8
local CARD_HEIGHT = 70
local SPIN_SPEED = 0.8 -- rad/s
local EVENT_COLOR = Color3.fromRGB(150, 80, 200) -- 이벤트 탭·"한정" 표시 (m5-07)
local EVENT_BAR_HEIGHT = 44 -- 이벤트 머리줄 두 줄 (기본 크기, setLayout이 바꿔요)
local BADGE_COLOR = Color3.fromRGB(220, 40, 40) -- 🎫 티켓 배지 (m5-31)

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

local function tierColor(tier: Skins.Tier): Color3
	return rgb(Skins.TIER_INFO[tier].color)
end

-- 카드·미리보기 등급 표시 (특 스킨은 등급 대신 "🎫 특", m5-31)
local function skinInfo(skin: Skins.Skin): Skins.TierInfo
	local grade = Skins.drawGradeOf(skin.id)
	if grade ~= nil and Skins.isDrawOnly(skin.id) then
		local info = Skins.DRAW_GRADE_INFO[grade]
		return {
			displayName = Loc.t("shop.drawTierLine", { grade = Loc.drawGradeName(grade) }),
			color = info.color,
		}
	end
	return { displayName = Loc.tierName(skin.tier), color = Skins.TIER_INFO[skin.tier].color }
end

local SPECIAL_COLOR = rgb(Skins.DRAW_INFO.color)

function ShopScreen.new(playerGui: Instance, actions: Actions): ShopScreen
	local gui = Kit.new("ScreenGui", {
		Name = "ShopGui",
		ResetOnSpawn = false,
		DisplayOrder = 20, -- 로비·HUD(0) 위, 코인 토스트(55) 아래
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local openButton = Kit.button(Loc.t("shop.open.btn"), Color.Salmon, {
		Name = "SkinButton",
		Parent = gui,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(110, 44),
		Visible = false,
	})
	Kit.onClick(openButton, actions.open)
	-- 🎫 티켓 배지 (m5-31): 티켓이 있으면 빨간 숫자
	local badge = Kit.label({
		Name = "TicketBadge",
		Parent = openButton,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = BADGE_COLOR,
		BackgroundTransparency = 0,
		Text = "0",
		TextSize = 14,
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
	})
	Kit.corner(12).Parent = badge

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
		Text = Loc.t("shop.title"),
		TextSize = 24,
		Size = UDim2.fromScale(0.3, 1),
	})
	-- 🎫 뽑기 패널 열기 (m5-31)
	local drawOpenButton = Kit.button(Loc.t("shop.btn.openDraw"), SPECIAL_COLOR, {
		Name = "OpenDraw",
		Parent = header,
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.28, 1),
		TextSize = 16,
	})
	Kit.new("UISizeConstraint", { Parent = drawOpenButton, MaxSize = Vector2.new(170, math.huge) })
	Kit.onClick(drawOpenButton, actions.openDraw)
	local coinLabel = Kit.label({
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 0),
		Size = UDim2.fromScale(0.22, 1),
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
	local tabButtons: { { button: TextButton, id: string } } = {}
	local tabKey = "" -- 지금 만든 탭들의 id·이름 (바뀔 때만 다시 만들어요)
	local tabTextSize = 16

	local function buildTabs(tabs: { ShopLogic.Tab })
		local key = ""
		for _, tab in tabs do
			key ..= `{tab.id}={Loc.text(tab.label)};`
		end
		if key == tabKey then
			return
		end
		tabKey = key
		for _, old in tabButtons do
			old.button:Destroy()
		end
		table.clear(tabButtons)
		for i, tab in tabs do
			local color = if tab.eventId
				then EVENT_COLOR
				elseif tab.draw then SPECIAL_COLOR
				elseif tab.tier then tierColor(tab.tier)
				else Color.Salmon
			local button = Kit.button(Loc.text(tab.label), color, {
				Parent = tabRow,
				LayoutOrder = i,
				Size = UDim2.new(1 / #tabs, -6, 1, 0),
				TextSize = tabTextSize,
			}) :: TextButton
			local id = tab.id
			Kit.onClick(button, function()
				actions.tab(id)
			end)
			table.insert(tabButtons, { button = button, id = id })
		end
	end

	-- 이벤트 머리줄 (이벤트 탭에서만, m5-07): 이벤트 이름 · 마지막 날 · 내 재화 + 작은 안내
	local eventBar = Kit.new("Frame", {
		Name = "EventBar",
		Parent = window,
		BackgroundColor3 = Color.Row,
		Size = UDim2.new(1, 0, 0, EVENT_BAR_HEIGHT),
		Visible = false,
	}, { Kit.corner(10), Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	local eventTitle = Kit.label({
		Name = "Title",
		Parent = eventBar,
		Size = UDim2.fromScale(1, 0.58),
		Text = "",
		TextSize = 17,
	})
	local eventNote = Kit.label({
		Name = "Note",
		Parent = eventBar,
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.42),
		Text = Loc.text(ShopLogic.EVENT_NOTE),
		TextSize = 12,
		TextColor3 = Color.SubText,
	})
	local contentTop = 88 + GAP -- 탭 아래 (setLayout이 바꿔요)
	local eventBarHeight = EVENT_BAR_HEIGHT

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
	local actionButton = Kit.button(Loc.t("shop.btn.wear"), Color.Salmon, {
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

	type Card = {
		button: TextButton,
		stroke: UIStroke,
		name: TextLabel,
		status: TextLabel,
		limited: TextLabel,
		special: TextLabel?,
	}
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
			Color = rgb(skinInfo(skin).color),
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}) :: UIStroke
		local name = Kit.label({
			Parent = button,
			Text = Loc.skinName(skin.id),
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
		local limited = Kit.label({
			Name = "Limited",
			Parent = button,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 2, 0, -2),
			Size = UDim2.fromOffset(34, 16),
			Text = Loc.t("shop.limited"),
			TextSize = 11,
			TextColor3 = Color.White,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundColor3 = EVENT_COLOR,
			BackgroundTransparency = 0,
			Visible = false,
			ZIndex = 2,
		})
		Kit.corner(6).Parent = limited
		-- 특 스킨 구석 표시 (m5-31)
		local special: TextLabel? = nil
		local drawGrade = Skins.drawGradeOf(skin.id)
		if drawGrade ~= nil then
			local gradeInfo = Skins.DRAW_GRADE_INFO[drawGrade]
			local tag = Kit.label({
				Name = "Special",
				Parent = button,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 2, 0, -2),
				Size = UDim2.fromOffset(42, 16),
				Text = Loc.t("shop.drawBadge", { grade = Loc.drawGradeName(drawGrade) }), -- 뽑기 등급 배지
				TextSize = 11,
				TextScaled = true, -- 영어 "Legendary"도 들어가게 (m5-26)
				TextColor3 = Color.White,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundColor3 = rgb(gradeInfo.color),
				BackgroundTransparency = 0,
				ZIndex = 2,
			})
			Kit.corner(6).Parent = tag
			special = tag
		end
		local id = skin.id
		Kit.onClick(button, function()
			actions.select(id)
		end)
		-- 게임패드로 카드에 오면 미리보기를 바꿔요 (m5-12). 마우스에서는 안 와요
		button.SelectionGained:Connect(function()
			if GamepadNav.isGamepad() then
				actions.select(id)
			end
		end)
		cards[skin.id] =
			{ button = button, stroke = stroke, name = name, status = status, limited = limited, special = special }
	end

	local selectedId = Skins.DEFAULT_ID
	local currentTabId: string? = nil -- 마지막으로 그린 탭 (LB/RB, m5-12)
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
		local ok, model = pcall(SushiBody.build, skinId, nil) -- 표정 없음 (기본)
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
		-- 길게 나온 스킨은 카메라를 조금 뒤로 (m5-32, 다른 스킨은 그대로 z -10)
		local extents = model:GetExtentsSize()
		local distance = UiLayout.previewDistance(math.max(extents.X, extents.Z) / 2)
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -distance), Vector3.new(0, 0.1, 0))
		-- 고등어 관절이 있으면 살랑 + 자주 팔딱 (m5-32, 탈의실이 닫히면 화면이 안 보여 멈춰요)
		DollAnimator.attach(model, "Preview", { sound = "Ui" })
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
		actionButton.Text = Loc.text(ShopLogic.cardButtonText(state))
		Kit.setEnabled(actionButton, state.enabled and not busy)
		local robuxText = ShopLogic.robuxButtonText(state)
		robuxButton.Visible = robuxText ~= nil
		if robuxText then
			robuxButton.Text = Loc.text(robuxText)
			Kit.setEnabled(robuxButton, state.robuxEnabled == true and not busy)
		end
	end

	-- 게임패드 (m5-12): 탭은 LB/RB, 첫 선택 = 보이는 카드 중 맨 앞
	local sortedSkins = table.clone(Skins.LIST)
	table.sort(sortedSkins, function(a: Skins.Skin, b: Skins.Skin): boolean
		return a.order < b.order
	end)
	GamepadNav.anchor(openButton)
	GamepadNav.window({
		root = backdrop,
		close = actions.close,
		first = function(): GuiObject?
			for _, skin in sortedSkins do
				local card = cards[skin.id]
				if card.button.Visible then
					return card.button
				end
			end
			return actionButton
		end,
		tabs = function(dir: number)
			local current = currentTabId
			if current == nil or #tabButtons == 0 then
				return
			end
			local ids = {}
			for _, tab in tabButtons do
				table.insert(ids, tab.id)
			end
			local nextId = GamepadNavLogic.nextTab(ids, current, dir)
			if nextId ~= current then
				actions.tab(nextId)
			end
		end,
	})

	local screen = {} :: ShopScreen
	screen.gui = gui

	function screen.setTickets(_self: ShopScreen, tickets: number)
		badge.Visible = tickets > 0
		badge.Text = if tickets > 99 then "99" else tostring(tickets)
		drawOpenButton.Text = if tickets > 0
			then Loc.t("shop.btn.openDrawCount", { count = tickets })
			else Loc.t("shop.btn.openDraw")
	end

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

	local function placeContent(showEventBar: boolean)
		eventBar.Visible = showEventBar
		eventBar.Position = UDim2.fromOffset(0, contentTop)
		eventBar.Size = UDim2.new(1, 0, 0, eventBarHeight)
		local top = if showEventBar then contentTop + eventBarHeight + GAP else contentTop
		content.Position = UDim2.fromOffset(0, top)
		content.Size = UDim2.new(1, 0, 1, -top)
	end

	function screen.render(_self: ShopScreen, state: RenderState)
		local view = state.view
		local selected = state.selected
		local robux = state.robux
		local now = state.now
		coinLabel.Text = `🍚 {Loc.number(view.coins)}`
		buildTabs(state.tabs)
		currentTabId = state.tab.id
		for _, tab in tabButtons do
			Kit.setSelected(tab.button, tab.id == state.tab.id)
		end
		local eventText = state.eventHeader
		eventTitle.Text = eventText or ""
		placeContent(eventText ~= nil)
		local visible: { [string]: boolean } = {}
		for _, skin in ShopLogic.visibleSkins(view, state.tab, now) do
			visible[skin.id] = true
		end
		for _, skin in Skins.LIST do
			local card = cards[skin.id]
			card.button.Visible = visible[skin.id] == true
			local cardState = ShopLogic.cardState(skin, view, robux, now)
			card.status.Text = Loc.text(ShopLogic.cardButtonText(cardState))
			card.status.TextColor3 = if cardState.kind == "Equipped" then Color.Salmon else Color.SubText
			card.limited.Visible = cardState.limited == true
			card.button.BackgroundColor3 = if skin.id == selected then Color.Row else Color.White
			card.stroke.Thickness = if skin.id == selected then 4 else 2
		end

		local skin = Skins.get(selected) or Skins.get(Skins.DEFAULT_ID) :: Skins.Skin
		if selectedId ~= skin.id then
			-- 다른 카드를 고르면 대사를 새로 뽑고 결과 글씨를 지워요
			speechLabel.Text = `💬 "{Loc.skinSpeech(skin.id, math.random(1, #skin.speech))}"`
			resultLabel.Text = ""
		elseif speechLabel.Text == "" then
			speechLabel.Text = `💬 "{Loc.skinSpeech(skin.id, 1)}"`
		end
		selectedId = skin.id
		nameLabel.Text = Loc.skinName(skin.id)
		local info = skinInfo(skin)
		-- 뽑기에서도 나오는 판매 스킨이면 안내를 붙여요 (m5-32)
		local hint = ShopLogic.drawHint(skin)
		tierLabel.Text = if hint then `{info.displayName} · {Loc.text(hint)}` else info.displayName
		tierLabel.TextColor3 = rgb(info.color)
		setPreview(skin.id)
		currentState = ShopLogic.cardState(skin, view, robux, now)
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
		drawOpenButton.TextSize = text(16)
		badge.Size = UDim2.fromOffset(text(24), text(24))
		badge.TextSize = text(14)
		coinLabel.TextSize = text(20)
		coinLabel.Position = UDim2.new(1, -(buttonHeight + 8), 0, 0)
		local tabHeight = UiLayout.touchSize(36, m)
		tabRow.Position = UDim2.fromOffset(0, buttonHeight + GAP)
		tabRow.Size = UDim2.new(1, 0, 0, tabHeight)
		tabTextSize = text(16)
		for _, tab in tabButtons do
			tab.button.TextSize = tabTextSize
		end
		contentTop = buttonHeight + GAP + tabHeight + GAP
		eventTitle.TextSize = text(17)
		eventNote.TextSize = text(12)
		eventBarHeight = UiLayout.lineHeight(24, m, 17) + UiLayout.lineHeight(18, m, 12)
		placeContent(eventBar.Visible)

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
