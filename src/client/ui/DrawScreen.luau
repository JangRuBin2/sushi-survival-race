--!strict
-- 🎫 스킨 뽑기 화면 (m5-31, GDD 9.6·10). 사용자 샘플 docs/귀여운 초밥 스킨 뽑기 UI.png를 Roblox 기본 UI로 옮겼어요.
-- 자기 ScreenGui `DrawGui` (탈의실 위). 보여 주기만 하고 요청은 actions로 넘겨요 — 판정·확률·결과는 서버(ShopService).
--   위: 왼쪽 나무 간판 "👑 스킨 뽑기" + "지금, 특별한 스킨을 획득할 수 있는 기회!", "보유 중인 뽑기권 ×N" 상자, 안내
--       "1등만 뽑기권을 획득할 수 있어요!". 가운데 단상 위 대표 스킨(가장 높은 등급, ViewportFrame + SushiBody.build,
--       천천히 회전) + "○○ 스킨 획득 가능!" 말풍선 + 큰 노란 "🎫 뽑기 시작하기 >"(티켓 0이면 꺼지고 이유 한 줄).
--       오른쪽 "스킨 등급별 확률 ⓘ" 표(전설 금·영웅 보라·희귀 파랑·고급 초록·일반 회색, 👑 색, %) —
--       DrawLogic.grades + displayPercents (서버 roll과 같은 값, 빈 등급은 "준비 중") + 안내, 닫기 ✕.
--       ⓘ: 스킨별 "각 x.xx%"(perSkinPercent)와 중복 코인, 반올림 안내.
--   아래(남색 띠): "보유 스킨 목록 n/총수" 격자(인형 썸네일·이름·등급 배지, 안 가진 건 실루엣 + 🔒) + 오른쪽 상세
--       (등급 배지·이름·대사 한 줄·큰 인형·표정 썸네일·"입기").
--   결과: "스킨 획득!" 창 (등급색 빛 번짐·반짝임, 인형, 이름 + 등급 배지, "확인"·"입기"). 이미 가진 스킨이면
--       "이미 가진 스킨 → 🍚 +N". 결과 전 약 1.2초 두근두근(빛이 커졌다 작아졌다).
--   휴대폰(compact): 위에 탭 "🎫 뽑기 / 📊 확률 / 📦 목록"으로 한 번에 한 칸씩 (겹치지 않게). 목록 탭에서 카드를
--       누르면 상세가 목록 위에 겹치는 창으로 떠요(✕로 닫기). 버튼 높이는 DrawScreenLayout.heights(44px 이상, QA B1).
--   두근두근 ~ 결과 공개 사이에 온 프로필 변화는 결과를 보여 준 뒤에 그려요 (QA B2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DrawLogic = require(ReplicatedStorage.Shared.DrawLogic)
local DrawScreenLayout = require(ReplicatedStorage.Shared.DrawScreenLayout)
local Skins = require(ReplicatedStorage.Shared.Skins)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)
local DollAnimator = require(script.Parent.Parent.fx.DollAnimator)

local Color = Kit.Color

export type Actions = {
	close: () -> (),
	draw: () -> (),
	wear: (skinId: string) -> (),
	-- m5-32: 뽑기 스킨인데 로벅스로도 파는 스킨(고등어 [신선])의 상세 "R$ 199로 사기"
	buyRobux: (skinId: string) -> (),
	robuxOpen: (skinId: string) -> boolean, -- 상품 id가 있어 살 수 있는지 (없으면 "곧 열려요")
}

export type RenderState = {
	tickets: number,
	ownedSkins: { string },
	equippedSkin: string,
	studioUnlockAll: boolean,
	disabledReason: string?, -- 뽑기 버튼이 꺼진 이유 (nil이면 켜짐)
}

export type DrawScreen = {
	gui: ScreenGui,
	setOpen: (self: DrawScreen, open: boolean) -> (),
	isOpen: (self: DrawScreen) -> boolean,
	render: (self: DrawScreen, state: RenderState) -> (),
	suspense: (self: DrawScreen) -> (), -- 결과를 기다리는 두근두근
	reveal: (self: DrawScreen, result: Types.DrawResult) -> (),
	showMessage: (self: DrawScreen, text: string, isError: boolean) -> (),
	setLayout: (self: DrawScreen, m: UiLayout.Metrics) -> (),
}

local DrawScreen = {}

DrawScreen.SUSPENSE_TIME = 1.2 -- 초: 결과 전 두근두근 최소 시간

local WINDOW_MAX = Vector2.new(1120, 720)
local SPIN_SPEED = 0.7
local WOOD = Color3.fromRGB(150, 90, 50)
local WOOD_DARK = Color3.fromRGB(95, 55, 30)
local NAVY = Color3.fromRGB(32, 44, 78)
local NAVY_CARD = Color3.fromRGB(48, 62, 104)
local YELLOW = Color3.fromRGB(255, 200, 40)
local YELLOW_TEXT = Color3.fromRGB(90, 55, 10)
local DARK_BOX = Color3.fromRGB(45, 40, 40)

local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

local function gradeColor(grade: string?): Color3
	local info = if grade then Skins.DRAW_GRADE_INFO[grade :: Skins.DrawGrade] else nil
	return if info then rgb(info.color) else Color.SubText
end

local function gradeName(grade: string?): string
	local info = if grade then Skins.DRAW_GRADE_INFO[grade :: Skins.DrawGrade] else nil
	return if info then info.displayName else "?"
end

-- 글씨: 칸에 맞춰 줄고 maxSize를 넘지 않아요 (화면 크기가 달라도 안 넘쳐요)
local function text(props: { [string]: any }, maxSize: number): TextLabel
	local label = Kit.label(props)
	label.TextScaled = true
	label.TextWrapped = true
	Kit.new("UITextSizeConstraint", { Parent = label, MaxTextSize = maxSize, MinTextSize = 8 })
	return label
end

local function scaledButton(caption: string, color: Color3, props: { [string]: any }, maxSize: number): TextButton
	local button = Kit.button(caption, color, props)
	button.TextScaled = true
	Kit.new("UITextSizeConstraint", { Parent = button, MaxTextSize = maxSize, MinTextSize = 10 })
	return button
end

-- 인형 하나를 ViewportFrame에 (카메라 포함). 실패하면 nil. animate가 있으면 고등어 관절이 있는 스킨만 팔딱여요
-- (m5-32 DollAnimator — 화면이 보일 때만 돌고 인형이 지워지면 멈춰요, 소리는 UI 소리로 작게)
local function doll(viewport: ViewportFrame, skinId: string, expression: string?, animate: DollAnimator.Mode?): Model?
	local ok, model = pcall(SushiBody.build, skinId, expression)
	if not ok then
		warn(`[DrawScreen] doll failed for {skinId}: {model}`)
		return nil
	end
	model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
	model.Parent = viewport
	-- 길게 나온 스킨(고등어)은 카메라를 조금 뒤로 (m5-32, 다른 스킨은 그대로)
	local camera = viewport.CurrentCamera
	if camera then
		local extents = model:GetExtentsSize()
		local distance = UiLayout.previewDistance(math.max(extents.X, extents.Z) / 2)
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.1, -distance), Vector3.new(0, 0.2, 0))
	end
	if animate then
		DollAnimator.attach(model, animate, { sound = "Ui" })
	end
	return model
end

local function newViewport(props: { [string]: any }): ViewportFrame
	local viewport = Kit.new("ViewportFrame", props) :: ViewportFrame
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 160, 150)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.6, -1, 0.8)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 36
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.1, -10), Vector3.new(0, 0.2, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function badge(parent: Instance, props: { [string]: any }): TextLabel
	local label = text(props, 14)
	label.Parent = parent
	label.BackgroundTransparency = 0
	label.TextColor3 = Color.White
	label.TextXAlignment = Enum.TextXAlignment.Center
	Kit.corner(8).Parent = label
	return label
end

function DrawScreen.new(playerGui: Instance, actions: Actions): DrawScreen
	local gui = Kit.new("ScreenGui", {
		Name = "DrawGui",
		ResetOnSpawn = false,
		DisplayOrder = 22, -- 탈의실(20) 위, 코인 토스트(55) 아래
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	}) :: ScreenGui

	local backdrop = Kit.new("Frame", {
		Name = "Backdrop",
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.35,
		Active = true,
	})
	local window = Kit.new("Frame", {
		Name = "Window",
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.97, 0.95),
		BackgroundColor3 = Color.White,
		Active = true,
		ClipsDescendants = true,
	}, {
		Kit.corner(18),
		Kit.new("UISizeConstraint", { MaxSize = WINDOW_MAX }),
		-- 하늘 → 크림 (샘플 배경의 밝은 가게 느낌)
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 205, 245)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 232, 200)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 200, 160)),
			}),
		}),
	}) :: Frame

	-- 휴대폰 탭
	local tabBar = Kit.new("Frame", {
		Name = "Tabs",
		Parent = window,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -70, 0, 44),
		Visible = false,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local TABS = {
		{ id = "draw", label = "🎫 뽑기" },
		{ id = "odds", label = "📊 확률" },
		{ id = "list", label = "📦 목록" },
	}
	local tabButtons: { [string]: TextButton } = {}
	local currentTab = "draw"

	local content = Kit.new("Frame", {
		Name = "Content",
		Parent = window,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}) :: Frame

	-- 아래 남색 띠 (넓은 화면에서 목록·상세 뒤)
	local band = Kit.new("Frame", {
		Name = "Band",
		Parent = content,
		BackgroundColor3 = NAVY,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
	})

	---------------------------------------------------------------- 왼쪽: 간판 · 뽑기권
	local signCol = Kit.new("Frame", { Name = "Sign", Parent = content, BackgroundTransparency = 1 }) :: Frame
	local sign = Kit.new("Frame", {
		Name = "Board",
		Parent = signCol,
		BackgroundColor3 = WOOD,
		Rotation = -3,
	}, {
		Kit.corner(18),
		Kit.new("UIStroke", { Color = WOOD_DARK, Thickness = 4 }),
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(190, 120, 70), Color3.fromRGB(130, 75, 40)),
		}),
	}) :: Frame
	text({
		Parent = sign,
		Text = "👑",
		Position = UDim2.fromScale(0.36, -0.18),
		Size = UDim2.fromScale(0.3, 0.32),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, 40)
	local signTitle = text({
		Parent = sign,
		Text = "스킨 뽑기",
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, 0.5),
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, 54)
	Kit.new("UIStroke", { Parent = signTitle, Color = WOOD_DARK, Thickness = 3 })
	text({
		Parent = sign,
		Text = "지금, 특별한 스킨을\n획득할 수 있는 기회!",
		Position = UDim2.fromScale(0.06, 0.6),
		Size = UDim2.fromScale(0.88, 0.34),
		TextColor3 = Color3.fromRGB(255, 240, 215),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, 18)

	local ticketBox = Kit.new("Frame", {
		Name = "TicketBox",
		Parent = signCol,
		BackgroundColor3 = DARK_BOX,
		BackgroundTransparency = 0.25,
	}, { Kit.corner(12) }) :: Frame
	text({
		Parent = ticketBox,
		Text = "🎫",
		Position = UDim2.fromScale(0.03, 0.1),
		Size = UDim2.fromScale(0.3, 0.8),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, 46)
	text({
		Parent = ticketBox,
		Text = "보유 중인 뽑기권",
		Position = UDim2.fromScale(0.36, 0.1),
		Size = UDim2.fromScale(0.6, 0.35),
		TextColor3 = Color.White,
	}, 17)
	local ticketCount = text({
		Parent = ticketBox,
		Text = "×0",
		Position = UDim2.fromScale(0.36, 0.45),
		Size = UDim2.fromScale(0.6, 0.48),
		TextColor3 = YELLOW,
	}, 34)
	local hintBox = text({
		Name = "Hint",
		Parent = signCol,
		Text = "1등만 뽑기권을 획득할 수 있어요!\n(확률에 따라 스킨이 지급돼요)",
		BackgroundColor3 = DARK_BOX,
		BackgroundTransparency = 0.35,
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, 15)
	Kit.corner(12).Parent = hintBox
	Kit.new("UIPadding", { Parent = hintBox, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	---------------------------------------------------------------- 가운데: 단상 · 대표 스킨 · 시작 버튼
	local stageCol = Kit.new("Frame", { Name = "Stage", Parent = content, BackgroundTransparency = 1 }) :: Frame
	Kit.new("Frame", { -- 단상
		Name = "Pedestal",
		Parent = stageCol,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.78, 0.16),
		BackgroundColor3 = Color3.fromRGB(205, 130, 75),
	}, {
		Kit.corner(999),
		Kit.new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }),
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(230, 160, 100), Color3.fromRGB(165, 95, 50)),
		}),
	})
	local featuredView = newViewport({
		Name = "Featured",
		Parent = stageCol,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.75, 0.68),
		ZIndex = 2,
	})
	local bubble = text({
		Name = "Bubble",
		Parent = stageCol,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0.02),
		Size = UDim2.fromScale(0.42, 0.14),
		Text = "",
		BackgroundColor3 = Color.White,
		BackgroundTransparency = 0.1,
		TextColor3 = Color3.fromRGB(40, 60, 120),
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = -6,
		ZIndex = 3,
	}, 16)
	Kit.corner(12).Parent = bubble
	local startButton = scaledButton("🎫 뽑기 시작하기  >", YELLOW, {
		Name = "Start",
		Parent = stageCol,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromScale(0.82, 0.14),
		TextColor3 = YELLOW_TEXT,
		ZIndex = 3,
	}, 30)
	Kit.new("UIStroke", {
		Parent = startButton,
		Color = Color3.fromRGB(200, 130, 20),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local startReason = text({
		Name = "Reason",
		Parent = stageCol,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.935),
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 60, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, 15)

	---------------------------------------------------------------- 오른쪽: 확률표
	local oddsPanel = Kit.new("Frame", {
		Name = "Odds",
		Parent = content,
		BackgroundColor3 = Color.White,
		BackgroundTransparency = 0.05,
	}, { Kit.corner(16), Kit.padding(10) }) :: Frame
	text({
		Parent = oddsPanel,
		Text = "스킨 등급별 확률",
		Size = UDim2.fromScale(0.8, 0.12),
		TextColor3 = Color3.fromRGB(40, 50, 90),
	}, 24)
	local infoButton = scaledButton("ⓘ", Color3.fromRGB(150, 160, 190), {
		Name = "Info",
		Parent = oddsPanel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
	}, 22)
	local oddsRows: { [string]: { frame: Frame, label: TextLabel, percent: TextLabel, color: Color3 } } = {}
	for i, grade in Skins.DRAW_GRADES do
		local color = rgb(Skins.DRAW_GRADE_INFO[grade].color)
		local row = Kit.new("Frame", {
			Name = grade,
			Parent = oddsPanel,
			Position = UDim2.fromScale(0, 0.14 + (i - 1) * 0.135),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = color:Lerp(Color.White, 0.82),
		}, { Kit.corner(10) }) :: Frame
		text({
			Parent = row,
			Text = "👑",
			TextColor3 = color,
			Position = UDim2.fromScale(0.03, 0.1),
			Size = UDim2.fromScale(0.14, 0.8),
			TextXAlignment = Enum.TextXAlignment.Center,
		}, 24)
		local label = text({
			Parent = row,
			Text = "",
			TextColor3 = color:Lerp(Color.Text, 0.35),
			Position = UDim2.fromScale(0.2, 0.15),
			Size = UDim2.fromScale(0.52, 0.7),
		}, 18)
		local percent = text({
			Parent = row,
			Text = "",
			TextColor3 = Color.Text,
			Position = UDim2.fromScale(0.72, 0.15),
			Size = UDim2.fromScale(0.25, 0.7),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, 20)
		oddsRows[grade] = { frame = row, label = label, percent = percent, color = color }
	end
	local oddsNote = text({
		Parent = oddsPanel,
		Text = "👑 뽑기권은 1등에게만 지급되며, 등급별 확률에 따라 스킨이 획득됩니다. 이미 가진 스킨이 나오면 🍚 코인으로 바뀌어요.",
		Position = UDim2.fromScale(0, 0.835),
		Size = UDim2.fromScale(1, 0.165),
		BackgroundColor3 = Color.Row,
		BackgroundTransparency = 0,
		TextColor3 = Color.SubText,
	}, 14)
	Kit.corner(10).Parent = oddsNote
	Kit.new("UIPadding", { Parent = oddsNote, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	---------------------------------------------------------------- 아래 왼쪽: 보유 스킨 목록
	local listPanel = Kit.new("Frame", {
		Name = "List",
		Parent = content,
		BackgroundColor3 = NAVY_CARD,
		BackgroundTransparency = 0.2,
	}, { Kit.corner(14), Kit.padding(8) }) :: Frame
	local listTitle = text({
		Parent = listPanel,
		Text = "보유 스킨 목록",
		Size = UDim2.new(0.7, 0, 0, 26),
		TextColor3 = Color.White,
	}, 20)
	local listCount = text({
		Parent = listPanel,
		Text = "0/0",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.28, 0, 0, 26),
		TextColor3 = Color3.fromRGB(200, 210, 240),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, 16)
	local grid = Kit.new("ScrollingFrame", {
		Name = "Grid",
		Parent = listPanel,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 160, 200),
	}) :: ScrollingFrame
	local gridLayout = Kit.new("UIGridLayout", {
		Parent = grid,
		CellPadding = UDim2.fromOffset(6, 6),
		CellSize = UDim2.new(0.25, -6, 0, 120),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIGridLayout
	Kit.new("UIPadding", { Parent = grid, PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) })

	type Card = { button: TextButton, viewport: ViewportFrame, lock: TextLabel, stroke: UIStroke }
	local cards: { [string]: Card } = {}
	local cardsBuilt = false
	local selectedId: string? = nil

	---------------------------------------------------------------- 아래 오른쪽: 상세
	local detailPanel = Kit.new("Frame", {
		Name = "Detail",
		Parent = content,
		BackgroundColor3 = NAVY_CARD,
		BackgroundTransparency = 0.2,
		-- 휴대폰에서 목록 위에 겹치는 창: 빈 곳을 눌러도 아래 목록 카드가 눌리지 않게 (m5-31 재QA R1)
		Active = true,
	}, { Kit.corner(14), Kit.padding(10) }) :: Frame
	local detailBadge = badge(detailPanel, {
		Text = "",
		Size = UDim2.fromScale(0.22, 0.11),
	})
	local detailName = text({
		Parent = detailPanel,
		Text = "",
		Position = UDim2.fromScale(0, 0.13),
		Size = UDim2.fromScale(0.52, 0.14), -- 큰 미리보기(오른쪽 0.46)와 겹치지 않게 (m5-31 재QA R2)
		TextColor3 = Color.White,
	}, 24)
	local detailLine = text({
		Parent = detailPanel,
		Text = "",
		Position = UDim2.fromScale(0, 0.28),
		Size = UDim2.fromScale(0.52, 0.2),
		TextColor3 = Color3.fromRGB(210, 220, 245),
	}, 15)
	local detailView = newViewport({
		Name = "Big",
		Parent = detailPanel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0.02),
		Size = UDim2.fromScale(0.46, 0.62),
	})
	local exprRow = Kit.new("Frame", {
		Name = "Expressions",
		Parent = detailPanel,
		Position = UDim2.fromScale(0, 0.66),
		Size = UDim2.fromScale(1, 0.2),
		BackgroundTransparency = 1,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local exprViews: { ViewportFrame } = {}
	local exprHolders: { TextButton } = {}
	local detailExpression: string? = "Happy" -- 큰 미리보기 표정 (썸네일을 누르면 바뀌어요)
	local detailFor: string? = nil
	-- 표정 썸네일: 콘셉트 몸 표정 6종 (m5-32 — 화남·슬픔 추가)
	local EXPRESSION_SLOTS = 6
	for i = 1, EXPRESSION_SLOTS do
		local holder = Kit.new("TextButton", {
			Parent = exprRow,
			LayoutOrder = i,
			Size = UDim2.new(1 / EXPRESSION_SLOTS, -5, 1, 0),
			BackgroundColor3 = NAVY,
			Text = "",
			AutoButtonColor = true,
		}, { Kit.corner(10) }) :: TextButton
		local view = newViewport({ Parent = holder, Size = UDim2.fromScale(1, 1) })
		table.insert(exprViews, view)
		table.insert(exprHolders, holder)
	end
	local wearButton = scaledButton("입기", Color.Salmon, {
		Name = "Wear",
		Parent = detailPanel,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(0.55, 0.12),
	}, 18)
	local detailNote = text({
		Parent = detailPanel,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromScale(0.43, 0.12),
		Text = "",
		TextColor3 = Color3.fromRGB(200, 210, 240),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, 14)

	---------------------------------------------------------------- 닫기
	-- 휴대폰에서 겹치는 상세 창 닫기 (QA B1·B3)
	local detailClose = scaledButton("✕", Color3.fromRGB(50, 60, 90), {
		Name = "DetailClose",
		Parent = detailPanel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		Visible = false,
		ZIndex = 3,
	}, 22)

	local closeButton = scaledButton("✕", Color3.fromRGB(50, 60, 90), {
		Name = "Close",
		Parent = window,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(48, 48),
		ZIndex = 10,
	}, 24)
	Kit.onClick(closeButton, actions.close)

	---------------------------------------------------------------- ⓘ 확률 상세
	local infoLayer = Kit.new("Frame", {
		Name = "OddsInfo",
		Parent = window,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.8),
		BackgroundColor3 = Color.White,
		Active = true,
		Visible = false,
		ZIndex = 30,
	}, {
		Kit.corner(16),
		Kit.padding(12),
		Kit.new("UIStroke", { Color = NAVY, Thickness = 3 }),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }),
	}) :: Frame
	text({
		Parent = infoLayer,
		Text = "스킨별 확률",
		Size = UDim2.new(1, -56, 0, 40),
		TextColor3 = Color3.fromRGB(40, 50, 90),
		ZIndex = 30,
	}, 24)
	local infoClose = scaledButton("✕", Color3.fromRGB(50, 60, 90), {
		Parent = infoLayer,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 31,
	}, 22)
	local infoScroll = Kit.new("ScrollingFrame", {
		Parent = infoLayer,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ZIndex = 30,
	}) :: ScrollingFrame
	local infoText = Kit.label({
		Parent = infoScroll,
		Text = "",
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 16,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 30,
	})
	Kit.onClick(infoClose, function()
		infoLayer.Visible = false
	end)

	---------------------------------------------------------------- 결과 창
	local resultLayer = Kit.new("Frame", {
		Name = "Result",
		Parent = window,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 35),
		BackgroundTransparency = 0.25,
		Active = true,
		Visible = false,
		ZIndex = 20,
	}) :: Frame
	local resultCard = Kit.new("Frame", {
		Parent = resultLayer,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.88),
		BackgroundColor3 = Color3.fromRGB(40, 30, 50),
		ZIndex = 20,
	}, {
		Kit.corner(18),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 600) }),
	}) :: Frame
	local glow = Kit.new("Frame", {
		Name = "Glow",
		Parent = resultCard,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.75),
		BackgroundColor3 = YELLOW,
		ZIndex = 20,
	}, {
		Kit.corner(999),
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.6, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	}) :: Frame
	-- 빛줄기 (얇은 Frame이 돌아요, 등급색)
	local rays: { Frame } = {}
	for i = 1, 6 do
		local ray = Kit.new("Frame", {
			Name = "Ray",
			Parent = resultCard,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(1.3, 0.035),
			BackgroundColor3 = YELLOW,
			Rotation = i * 30,
			ZIndex = 20,
		}, {
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}) :: Frame
		table.insert(rays, ray)
	end
	-- 뚜껑 덮인 접시 (두근두근 동안 들썩여요)
	local DOME_HOME = UDim2.fromScale(0.5, 0.62)
	local dome = text({
		Name = "Dome",
		Parent = resultCard,
		Text = "🛎️",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = DOME_HOME,
		Size = UDim2.fromScale(0.5, 0.35),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 24,
	}, 96)
	-- 반짝이 (빛 위에서 깜빡여요)
	local sparkles: { TextLabel } = {}
	for i, spot in { { 0.15, 0.2 }, { 0.82, 0.18 }, { 0.12, 0.62 }, { 0.86, 0.6 }, { 0.5, 0.1 }, { 0.3, 0.75 } } do
		local sparkle = text({
			Parent = resultCard,
			Text = if i % 2 == 0 then "✨" else "⭐",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromScale(0.1, 0.08),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 22,
		}, 30)
		table.insert(sparkles, sparkle)
	end
	local resultTitle = text({
		Parent = resultCard,
		Text = "👑 스킨 획득!",
		Position = UDim2.fromScale(0.05, 0.03),
		Size = UDim2.fromScale(0.9, 0.12),
		TextColor3 = YELLOW,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 23,
	}, 40)
	Kit.new("UIStroke", { Parent = resultTitle, Color = WOOD_DARK, Thickness = 3 })
	local resultView = newViewport({
		Parent = resultCard,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.8, 0.5),
		ZIndex = 23,
	})
	local resultName = text({
		Parent = resultCard,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.67),
		Size = UDim2.fromScale(0.8, 0.09),
		BackgroundColor3 = Color3.fromRGB(60, 40, 20),
		BackgroundTransparency = 0,
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 23,
	}, 22)
	Kit.corner(999).Parent = resultName
	local resultStroke = Kit.new("UIStroke", { Parent = resultName, Color = YELLOW, Thickness = 3 }) :: UIStroke
	local resultLine = text({
		Parent = resultCard,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromScale(0.9, 0.07),
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 23,
	}, 18)
	local okButton = scaledButton("확인", YELLOW, {
		Parent = resultCard,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.95, 0.97),
		Size = UDim2.fromScale(0.42, 0.11),
		TextColor3 = YELLOW_TEXT,
		ZIndex = 23,
	}, 24)
	local resultWear = scaledButton("입기", Color.Salmon, {
		Parent = resultCard,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.05, 0.97),
		Size = UDim2.fromScale(0.42, 0.11),
		ZIndex = 23,
	}, 22)

	---------------------------------------------------------------- 상태
	local state: RenderState? = nil
	local metrics: UiLayout.Metrics? = nil
	local busy = false
	local revealedSkin: string? = nil
	local featuredModel: Model? = nil
	local featuredId: string? = nil
	local spin: RBXScriptConnection? = nil
	local pulse: RBXScriptConnection? = nil
	local angle = 0
	local resultModel: Model? = nil
	local refresh: () -> () = function() end -- 아래 paint로 바꿔요 (카드 클릭)
	local openDetail: () -> () = function() end -- 휴대폰: 상세 창 열기 (아래 setTab 뒤에 정해요)
	local detailOpen = false -- 휴대폰에서 상세 창이 열려 있는지
	local pendingPaint = false -- 두근두근 중에 온 화면 변화 (결과 공개 뒤에 그려요)

	local function ownedMap(): { [string]: boolean }
		local map: { [string]: boolean } = {}
		local s = state
		for _, id in if s then s.ownedSkins else {} do
			map[id] = true
		end
		return map
	end

	local function owns(skinId: string): boolean
		local s = state
		return s ~= nil and table.find(s.ownedSkins, skinId) ~= nil
	end

	local function canWear(skinId: string): boolean
		local s = state
		return s ~= nil and (owns(skinId) or s.studioUnlockAll)
	end

	local function clearChildren(viewport: ViewportFrame)
		for _, child in viewport:GetChildren() do
			if not child:IsA("Camera") then
				child:Destroy()
			end
		end
	end

	local function buildCards()
		if cardsBuilt then
			return
		end
		cardsBuilt = true
		local order = 0
		for _, row in DrawLogic.grades() do
			local grade = row.grade
			for _, skinId in row.skinIds do
				order += 1
				local skin = Skins.get(skinId) :: Skins.Skin
				local button = Kit.new("TextButton", {
					Name = skinId,
					Parent = grid,
					LayoutOrder = order,
					BackgroundColor3 = NAVY,
					Text = "",
					AutoButtonColor = true,
				}, { Kit.corner(12) }) :: TextButton
				local stroke = Kit.new("UIStroke", {
					Parent = button,
					Color = gradeColor(grade),
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}) :: UIStroke
				local viewport = newViewport({
					Parent = button,
					Position = UDim2.fromScale(0.05, 0.02),
					Size = UDim2.fromScale(0.9, 0.58),
				})
				doll(viewport, skinId, nil)
				text({
					Parent = button,
					Text = skin.displayName,
					Position = UDim2.fromScale(0.04, 0.6),
					Size = UDim2.fromScale(0.92, 0.18),
					TextColor3 = Color.White,
					TextXAlignment = Enum.TextXAlignment.Center,
				}, 14)
				badge(button, {
					Text = gradeName(grade),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.8),
					Size = UDim2.fromScale(0.5, 0.16),
					BackgroundColor3 = gradeColor(grade),
				})
				local lock = text({
					Parent = button,
					Text = "🔒 아직 없어요",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.2),
					Size = UDim2.fromScale(0.9, 0.2),
					TextColor3 = Color.White,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 2,
				}, 18)
				Kit.onClick(button, function()
					selectedId = skinId
					refresh()
					openDetail()
				end)
				cards[skinId] = { button = button, viewport = viewport, lock = lock, stroke = stroke }
			end
		end
	end

	local function setFeatured()
		local id = DrawLogic.featured(ownedMap())
		if id == featuredId then
			return
		end
		featuredId = id
		clearChildren(featuredView)
		featuredModel = if id then doll(featuredView, id, "Happy", "Preview") else nil
		local skin = if id then Skins.get(id) else nil
		bubble.Text = if skin then `{skin.displayName}\n획득 가능!` else ""
		bubble.Visible = skin ~= nil
	end

	local function paintDetail()
		local id = selectedId or featuredId
		local skin = if id then Skins.get(id) else nil
		if skin == nil or id == nil then
			return
		end
		local grade = Skins.drawGradeOf(id)
		detailBadge.Text = gradeName(grade)
		detailBadge.BackgroundColor3 = gradeColor(grade)
		detailName.Text = skin.displayName
		detailLine.Text = `💬 "{skin.speech[1]}"`
		local rule = SushiBody.CONCEPT_BODY[id]
		local expressions: { string } = if rule then rule.expressions :: any else {}
		if detailFor ~= id then
			-- 다른 스킨: 썸네일을 새로 만들어요 (같은 스킨이면 다시 안 만들어요)
			detailFor = id
			detailExpression = if #expressions > 0 then "Happy" else nil
			for i, view in exprViews do
				clearChildren(view)
				local expression = expressions[i]
				exprHolders[i].Visible = expression ~= nil
				if expression then
					doll(view, id, expression)
				end
			end
		end
		clearChildren(detailView)
		doll(detailView, id, detailExpression, "Preview")
		for i, holder in exprHolders do
			holder.BackgroundColor3 = if expressions[i] == detailExpression then YELLOW else NAVY
		end
		local s = state
		local wearing = s ~= nil and s.equippedSkin == id
		local can = canWear(id)
		-- m5-32: 뽑기 + 판매 스킨(고등어 [신선])은 안 가졌으면 "R$ 199로 사기" (상품 id 전엔 "곧 열려요")
		local buyable = not can and skin.robux ~= nil
		local open = buyable and actions.robuxOpen(id)
		wearButton.Text = if wearing
			then "입는 중"
			elseif can and not owns(id) then "입기 (Studio)"
			elseif can then "입기"
			elseif buyable and open then `R$ {skin.robux}로 사기`
			elseif buyable then `R$ {skin.robux} — 곧 열려요`
			else "🎫 뽑기로 얻기"
		Kit.setEnabled(wearButton, (can and not wearing) or open)
		detailNote.Text = if owns(id) then "보유 중" else "아직 없어요"
	end

	local function paint()
		local s = state
		if s == nil then
			return
		end
		buildCards()
		setFeatured()
		ticketCount.Text = DrawLogic.ticketText(s.tickets)
		local reason = s.disabledReason
		Kit.setEnabled(startButton, reason == nil and not busy)
		startReason.Text = if busy then "두근두근…" else (reason or "")
		-- 화면 확률 = 서버 판정과 같은 DrawLogic.grades (빈 등급은 "준비 중")
		local grades = DrawLogic.grades()
		local percents = DrawLogic.displayPercents(grades)
		local compact = metrics ~= nil and metrics.compact
		for _, row in grades do
			local ui = oddsRows[row.grade]
			local info = Skins.DRAW_GRADE_INFO[row.grade]
			local empty = row.chance <= 0
			ui.label.Text = if compact then info.displayName else `{info.displayName} ({info.english})`
			ui.percent.Text = percents[row.grade]
			ui.frame.BackgroundColor3 = if empty
				then Color3.fromRGB(225, 225, 228)
				else ui.color:Lerp(Color.White, if row.grade == "Legendary" then 0.6 else 0.82)
			ui.percent.TextColor3 = if empty then Color.SubText else Color.Text
		end
		local perSkin = DrawLogic.perSkinPercent(grades)
		local lines: { string } = {}
		for _, row in grades do
			local info = Skins.DRAW_GRADE_INFO[row.grade]
			table.insert(lines, `<b>{info.displayName} ({info.english}) · {percents[row.grade]}</b>`)
			if #row.skinIds == 0 then
				table.insert(lines, "  아직 스킨이 없어요")
			end
			for _, skinId in row.skinIds do
				local skin = Skins.get(skinId)
				table.insert(lines, `  {if skin then skin.displayName else skinId} — 각 {perSkin[skinId]}`)
			end
			table.insert(lines, `  중복이면 🍚 +{row.duplicateCoins}`)
		end
		table.insert(lines, "")
		table.insert(lines, DrawLogic.ROUNDING_NOTE)
		infoText.Text = table.concat(lines, "\n")
		local owned = 0
		for skinId, card in cards do
			local has = owns(skinId)
			if has then
				owned += 1
			end
			card.lock.Visible = not has
			-- 안 가진 스킨은 실루엣
			card.viewport.ImageColor3 = if has then Color.White else Color3.fromRGB(20, 20, 30)
			local wearing = skinId == s.equippedSkin
			card.stroke.Thickness = if skinId == (selectedId or featuredId) or wearing then 4 else 2
			card.stroke.Color = if wearing then YELLOW else gradeColor(Skins.drawGradeOf(skinId))
		end
		listCount.Text = `{DrawLogic.ownedCount(ownedMap())}/{DrawLogic.totalSkins()}`
		paintDetail()
	end
	refresh = paint

	local function startSpin()
		if spin then
			return
		end
		spin = RunService.RenderStepped:Connect(function(dt: number)
			angle = (angle + dt * SPIN_SPEED) % (math.pi * 2)
			local breathe = 1 + math.sin(os.clock() * 2.4) * 0.03
			local model = featuredModel
			if model then
				model:PivotTo(CFrame.Angles(0, angle, 0))
				model:ScaleTo(breathe)
			end
			local prize = resultModel
			if prize and resultLayer.Visible then
				prize:PivotTo(CFrame.Angles(0, angle * 1.6, 0))
			end
			if resultLayer.Visible then
				for i, ray in rays do
					ray.Rotation = i * 30 + angle * 40
				end
			end
			if resultLayer.Visible then
				for i, sparkle in sparkles do
					sparkle.TextTransparency = 0.5 + math.sin(os.clock() * 4 + i * 1.3) * 0.5
				end
			end
		end)
	end

	local function stopSpin()
		if spin then
			spin:Disconnect()
			spin = nil
		end
		if pulse then
			pulse:Disconnect()
			pulse = nil
		end
	end

	local function setTab(id: string)
		currentTab = id
		for tabId, button in tabButtons do
			Kit.setSelected(button, tabId == id)
		end
		local m = metrics
		if m and m.compact then
			signCol.Visible = id == "draw"
			stageCol.Visible = id == "draw"
			oddsPanel.Visible = id == "odds"
			listPanel.Visible = id == "list"
			detailPanel.Visible = id == "list" and detailOpen
		end
	end
	openDetail = function()
		detailOpen = true
		setTab(currentTab)
	end
	Kit.onClick(detailClose, function()
		detailOpen = false
		setTab(currentTab)
	end)

	for i, tab in TABS do
		local button = scaledButton(tab.label, NAVY, {
			Parent = tabBar,
			LayoutOrder = i,
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
		}, 18)
		local id = tab.id
		Kit.onClick(button, function()
			setTab(id)
		end)
		tabButtons[id] = button
	end

	local function hideResult()
		resultLayer.Visible = false
		clearChildren(resultView)
		resultModel = nil
		revealedSkin = nil
	end

	Kit.onClick(startButton, function()
		if not busy then
			actions.draw()
		end
	end)
	Kit.onClick(wearButton, function()
		local id = selectedId or featuredId
		if id == nil then
			return
		end
		if canWear(id) then
			actions.wear(id)
		else
			local skin = Skins.get(id)
			if skin and skin.robux ~= nil then
				actions.buyRobux(id)
			end
		end
	end)
	Kit.onClick(okButton, hideResult)
	Kit.onClick(infoButton, function()
		infoLayer.Visible = not infoLayer.Visible
	end)
	for i, holder in exprHolders do
		Kit.onClick(holder, function()
			local id = detailFor
			local rule = if id then SushiBody.CONCEPT_BODY[id] else nil
			local expressions: { string } = if rule then rule.expressions :: any else {}
			if expressions[i] then
				detailExpression = expressions[i]
				refresh()
			end
		end)
	end
	Kit.onClick(resultWear, function()
		local id = revealedSkin
		if id then
			actions.wear(id)
			hideResult()
		end
	end)

	local screen = {} :: DrawScreen
	screen.gui = gui

	function screen.setOpen(_self: DrawScreen, open: boolean)
		gui.Enabled = open
		if open then
			startSpin()
			paint()
		else
			stopSpin()
			if not busy then
				hideResult()
			end
		end
	end

	function screen.isOpen(_self: DrawScreen): boolean
		return gui.Enabled
	end

	function screen.render(_self: DrawScreen, newState: RenderState)
		state = newState
		if busy then
			pendingPaint = true -- 결과보다 먼저 목록·단상이 바뀌지 않게 (QA B2)
			return
		end
		if gui.Enabled then
			paint()
		end
	end

	function screen.suspense(_self: DrawScreen)
		busy = true
		hideResult()
		resultLayer.Visible = true
		resultTitle.Text = "두근두근…"
		resultName.Visible = false
		resultLine.Text = ""
		okButton.Visible = false
		resultWear.Visible = false
		glow.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
		glow.Size = UDim2.fromScale(0.4, 0.34)
		for _, ray in rays do
			ray.Visible = false
		end
		dome.Visible = true
		dome.TextTransparency = 0
		dome.Position = DOME_HOME
		local started = os.clock()
		if pulse then
			pulse:Disconnect()
		end
		pulse = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			local strength = math.min(1, t / DrawScreen.SUSPENSE_TIME)
			dome.Rotation = math.sin(t * 28) * (4 + 10 * strength)
			dome.Position = DOME_HOME - UDim2.fromScale(0, math.abs(math.sin(t * 14)) * 0.04 * strength)
		end)
		paint()
	end

	function screen.reveal(_self: DrawScreen, result: Types.DrawResult)
		busy = false
		if pulse then
			pulse:Disconnect()
			pulse = nil
		end
		local color = gradeColor(result.grade)
		local skin = Skins.get(result.skinId)
		resultLayer.Visible = true
		-- 등급색 빛이 새어 나오고 뚜껑이 날아가요. 전설·영웅은 빛이 더 커요
		dome.Rotation = 0
		TweenService:Create(
			dome,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = DOME_HOME - UDim2.fromScale(0, 0.5), TextTransparency = 1 }
		):Play()
		local big = result.grade == "Legendary" or result.grade == "Epic"
		local glowScale = if result.grade == "Legendary" then 1.15 elseif big then 1.0 else 0.85
		glow.BackgroundColor3 = color
		glow.Size = UDim2.fromScale(0.4, 0.34)
		TweenService:Create(
			glow,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(glowScale, glowScale * 0.85) }
		):Play()
		for i, ray in rays do
			ray.Visible = big or i <= 3
			ray.BackgroundColor3 = color
		end
		clearChildren(resultView)
		resultModel = doll(resultView, result.skinId, "Happy", "Victory")
		resultName.Visible = true
		resultName.Text = `{if skin then skin.displayName else result.skinId}  [{gradeName(result.grade)}]`
		resultStroke.Color = color
		okButton.Visible = true
		if result.kind == "Skin" then
			resultTitle.Text = "👑 스킨 획득!"
			resultLine.Text = "· 확인 버튼을 눌러 주세요 ·"
			revealedSkin = result.skinId
			resultWear.Visible = true
		else
			resultTitle.Text = "👑 스킨 획득!"
			resultLine.Text = DrawLogic.resultText(result)
			revealedSkin = nil
			resultWear.Visible = false
		end
		selectedId = result.skinId
		pendingPaint = false
		paint()
	end

	function screen.showMessage(_self: DrawScreen, message: string, isError: boolean)
		busy = false
		if pulse then
			pulse:Disconnect()
			pulse = nil
		end
		hideResult()
		if pendingPaint then
			pendingPaint = false
			paint()
		end
		startReason.Text = message
		startReason.TextColor3 = if isError then Color.Error else Color3.fromRGB(120, 60, 40)
		local s = state
		Kit.setEnabled(startButton, s ~= nil and s.disabledReason == nil)
	end

	function screen.setLayout(_self: DrawScreen, m: UiLayout.Metrics)
		metrics = m
		local touch = UiLayout.touchSize(44, m)
		local h = DrawScreenLayout.heights(m) -- 실제 44px 이상 (QA B1)
		closeButton.Size = UDim2.fromOffset(h.close, h.close)
		infoButton.Size = UDim2.fromOffset(h.info, h.info)
		infoClose.Size = UDim2.fromOffset(h.close, h.close)
		infoScroll.Position = UDim2.fromOffset(0, h.close + 6)
		infoScroll.Size = UDim2.new(1, 0, 1, -(h.close + 6))
		detailClose.Size = UDim2.fromOffset(h.close, h.close)
		startButton.AnchorPoint = Vector2.new(0.5, 1)
		startButton.Position = UDim2.fromScale(0.5, 0.93)
		startButton.Size = UDim2.new(0.82, 0, 0, h.start)
		okButton.Size = UDim2.new(0.42, 0, 0, h.result)
		resultWear.Size = UDim2.new(0.42, 0, 0, h.result)
		-- 상세: 아래에 표정 줄 + 입기 줄 (Offset 높이), 큰 미리보기는 그 위
		local bottom = h.wear + 8 + h.expression + 8
		exprRow.Position = UDim2.new(0, 0, 1, -(h.wear + 8 + h.expression))
		exprRow.Size = UDim2.new(1, 0, 0, h.expression)
		wearButton.Size = UDim2.new(0.55, 0, 0, h.wear)
		detailNote.Size = UDim2.new(0.43, 0, 0, h.wear)
		detailView.Size = UDim2.new(0.46, 0, 1, -bottom)
		grid.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		local cardHeight = math.max(110, UiLayout.touchSize(110, m))
		if m.compact then
			-- 휴대폰: 탭으로 한 칸씩
			window.Size = UDim2.fromScale(0.98, 0.96)
			tabBar.Visible = true
			tabBar.Size = UDim2.new(1, -(touch + 24), 0, touch)
			local top = touch + 16
			content.Position = UDim2.fromOffset(0, top)
			content.Size = UDim2.new(1, 0, 1, -top)
			band.Visible = false
			window.BackgroundColor3 = Color.White
			-- 간판·안내는 접고(안내는 ⓘ 안으로) 뽑기권 한 줄만
			signCol.Position = UDim2.fromScale(0.02, 0)
			signCol.Size = UDim2.fromScale(0.96, 0.14)
			sign.Visible = false
			hintBox.Visible = false
			ticketBox.Position = UDim2.fromScale(0, 0)
			ticketBox.Size = UDim2.fromScale(1, 1)
			stageCol.Position = UDim2.fromScale(0.02, 0.15)
			stageCol.Size = UDim2.fromScale(0.96, 0.84)
			infoLayer.Size = UDim2.fromScale(0.96, 0.9)
			oddsPanel.Position = UDim2.fromScale(0.03, 0)
			oddsPanel.Size = UDim2.fromScale(0.94, 0.98)
			listPanel.Position = UDim2.fromScale(0.02, 0)
			listPanel.Size = UDim2.fromScale(0.96, 0.52)
			listPanel.Size = UDim2.fromScale(0.96, 1)
			-- 상세는 목록 위에 겹치는 창 (카드를 누르면 열리고 ✕로 닫아요)
			detailPanel.Position = UDim2.fromScale(0.02, 0)
			detailPanel.Size = UDim2.fromScale(0.96, 1)
			detailPanel.ZIndex = 5
			detailPanel.BackgroundTransparency = 0
			detailClose.Visible = true
			-- 큰 미리보기는 ✕ 아래 오른쪽 칸에만 (이름·대사 칸과 안 겹치게, m5-31 재QA R2)
			detailView.Position = UDim2.new(1, 0, 0, h.close + 8)
			detailView.Size = UDim2.new(0.44, 0, 1, -(bottom + h.close + 8))
			detailPanel.Active = true
			gridLayout.CellSize = UDim2.new(1 / 3, -6, 0, cardHeight)
			resultCard.Size = UDim2.fromScale(0.94, 0.9)
		else
			window.Size = UDim2.fromScale(0.97, 0.95)
			tabBar.Visible = false
			content.Position = UDim2.fromOffset(0, 0)
			content.Size = UDim2.fromScale(1, 1)
			band.Visible = true
			signCol.Position = UDim2.fromScale(0.015, 0.03)
			signCol.Size = UDim2.fromScale(0.26, 0.54)
			sign.Visible = true
			hintBox.Visible = true
			infoLayer.Size = UDim2.fromScale(0.7, 0.8)
			sign.Position = UDim2.fromScale(0.02, 0.08)
			sign.Size = UDim2.fromScale(0.96, 0.4)
			ticketBox.Position = UDim2.fromScale(0, 0.53)
			ticketBox.Size = UDim2.fromScale(1, 0.22)
			hintBox.Position = UDim2.fromScale(0, 0.78)
			hintBox.Size = UDim2.fromScale(1, 0.2)
			stageCol.Position = UDim2.fromScale(0.285, 0.02)
			stageCol.Size = UDim2.fromScale(0.38, 0.57)
			oddsPanel.Position = UDim2.fromScale(0.68, 0.1)
			oddsPanel.Size = UDim2.fromScale(0.31, 0.48)
			listPanel.Position = UDim2.fromScale(0.012, 0.615)
			listPanel.Size = UDim2.fromScale(0.6, 0.37)
			detailPanel.Position = UDim2.fromScale(0.625, 0.615)
			detailPanel.Size = UDim2.fromScale(0.363, 0.37)
			detailPanel.ZIndex = 1
			detailPanel.BackgroundTransparency = 0.2
			detailClose.Visible = false
			detailView.Position = UDim2.fromScale(1, 0.02)
			gridLayout.CellSize = UDim2.new(0.25, -6, 0, cardHeight)
			resultCard.Size = UDim2.fromScale(0.62, 0.88)
			signCol.Visible = true
			stageCol.Visible = true
			oddsPanel.Visible = true
			listPanel.Visible = true
			detailPanel.Visible = true
		end
		listTitle.Size = UDim2.new(0.7, 0, 0, UiLayout.lineHeight(26, m, 20))
		setTab(currentTab)
		paint() -- 확률표 이름(휴대폰은 영어 괄호를 빼요)
	end

	return screen
end

return DrawScreen
