--!strict
-- 관전 화면 (GDD 4, 10): 아래 가운데에 "👀 관전 중: 이름" + [◀] [▶] + 동작 버튼.
--   watching: 이름 줄 + ◀▶ + [로비로] / [내 캐릭터 보기]
--   idle:     [관전하기] 버튼 하나 (로비로 간 탈락자, 내 캐릭터를 보는 통과자)
-- 모바일: 버튼 높이 48px, 패널 폭 340px로 가운데에 두어 오른쪽 아래 점프 버튼과 겹치지 않아요
-- (점프 버튼은 작은 화면 기준 오른쪽 끝에서 95px, 큰 화면 170px 안쪽에 있어요).

local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

local PANEL_WIDTH = 340
local BUTTON_HEIGHT = 48

export type Callbacks = {
	previous: () -> (),
	nextTarget: () -> (),
	action: () -> (),
}

export type SpectateScreen = {
	hide: (self: SpectateScreen) -> (),
	showWatching: (self: SpectateScreen, title: string, canCycle: boolean, actionText: string) -> (),
	showIdle: (self: SpectateScreen, actionText: string) -> (),
}

local SpectateScreen = {}

function SpectateScreen.new(parent: Instance, callbacks: Callbacks): SpectateScreen
	local root = Kit.new("Frame", {
		Name = "Spectate",
		Parent = parent,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		-- 맨 아래 개인 결과 안내(HudScreen, 아래에서 24~54px)보다 위
		Position = UDim2.new(0.5, 0, 1, -62),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.25,
	}, {
		Kit.corner(14),
		Kit.padding(8),
		Kit.list(Enum.FillDirection.Vertical, 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	local titleLabel = Kit.label({
		Parent = root,
		LayoutOrder = 1,
		TextSize = 18,
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
	})

	local buttonRow = Kit.new("Frame", {
		Parent = root,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
	}, {
		Kit.list(Enum.FillDirection.Horizontal, 8, {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	local previousButton = Kit.button("◀", Color.Nori, {
		Parent = buttonRow,
		LayoutOrder = 1,
		TextSize = 22,
		Size = UDim2.fromOffset(56, BUTTON_HEIGHT),
	})
	local nextButton = Kit.button("▶", Color.Nori, {
		Parent = buttonRow,
		LayoutOrder = 2,
		TextSize = 22,
		Size = UDim2.fromOffset(56, BUTTON_HEIGHT),
	})
	local actionButton = Kit.button("", Color.Salmon, {
		Parent = buttonRow,
		LayoutOrder = 3,
		Size = UDim2.fromOffset(160, BUTTON_HEIGHT),
	})

	Kit.onClick(previousButton, callbacks.previous)
	Kit.onClick(nextButton, callbacks.nextTarget)
	Kit.onClick(actionButton, callbacks.action)

	local screen = {}

	function screen.hide(_self: SpectateScreen)
		root.Visible = false
	end

	function screen.showWatching(_self: SpectateScreen, title: string, canCycle: boolean, actionText: string)
		titleLabel.Visible = true
		titleLabel.Text = title
		previousButton.Visible = true
		nextButton.Visible = true
		Kit.setEnabled(previousButton, canCycle)
		Kit.setEnabled(nextButton, canCycle)
		actionButton.Text = actionText
		root.Visible = true
	end

	function screen.showIdle(_self: SpectateScreen, actionText: string)
		titleLabel.Visible = false
		previousButton.Visible = false
		nextButton.Visible = false
		actionButton.Text = actionText
		root.Visible = true
	end

	return (screen :: any) :: SpectateScreen
end

return SpectateScreen
