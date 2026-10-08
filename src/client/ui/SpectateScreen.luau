--!strict
-- 관전 화면 (GDD 4, 10): 아래 가운데에 "👀 관전 중: 이름" + [◀] [▶] + 동작 버튼.
--   watching: 이름 줄 + ◀▶ + [로비로] / [내 캐릭터 보기]
--   idle:     [관전하기] 버튼 하나 (로비로 간 탈락자, 내 캐릭터를 보는 통과자)
-- PC·태블릿: 버튼 높이 48px, 패널 폭 340px로 가운데에 두어 오른쪽 아래 점프 버튼과 겹치지 않아요
-- (점프 버튼은 작은 화면 기준 오른쪽 끝에서 95px, 큰 화면 170px 안쪽에 있어요).
-- compact(휴대폰 가로, m4-09): ◀ ▶는 화면 아래쪽 양 끝(엄지 위치, 오른쪽은 점프·다이브·잡기 버튼 바로 위,
-- Shared.UiLayout.spectateArrows), 이름 줄과 동작 버튼은 아래 가운데.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

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

	-- compact에서 ◀ ▶를 화면 양 끝에 둘 때 쓰는 전체 화면 틀 (입력은 막지 않아요)
	local arrowLayer = Kit.new("Frame", {
		Name = "SpectateArrows",
		Parent = parent,
		Visible = false,
		Active = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
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

	local function syncArrowLayer()
		arrowLayer.Visible = root.Visible and previousButton.Parent == arrowLayer
	end

	-- 화면 크기 대응 (m4-09)
	local function applyLayout(m: UiLayout.Metrics)
		local touch = UiLayout.touchSize(BUTTON_HEIGHT, m)
		local titleText = UiLayout.textSize(18, m)
		titleLabel.TextSize = titleText
		titleLabel.Size = UDim2.new(1, 0, 0, math.max(26, titleText + 6))
		buttonRow.Size = UDim2.new(1, 0, 0, touch)
		actionButton.Size = UDim2.fromOffset(160, touch)
		actionButton.TextSize = UiLayout.textSize(18, m)
		if m.compact and m.width > 0 then
			root.Position = UDim2.new(0.5, 0, 1, -8)
			local arrows = UiLayout.spectateArrows(m.width, m.height)
			local s = m.scale
			local function place(button: TextButton, rect: UiLayout.Rect, fromRight: boolean)
				button.Parent = arrowLayer
				button.Size = UDim2.fromOffset(rect.size / s, rect.size / s)
				button.TextSize = UiLayout.textSize(26, m)
				-- 화면 아래·옆 끝에서 잰 거리로 둬요 (위쪽 안전 영역 높이와 상관없게)
				local fromBottom = (m.height - rect.y) / s
				button.Position = if fromRight
					then UDim2.new(1, -(m.width - rect.x) / s, 1, -fromBottom)
					else UDim2.new(0, rect.x / s, 1, -fromBottom)
			end
			place(previousButton, arrows.left, false)
			place(nextButton, arrows.right, true)
		else
			root.Position = UDim2.new(0.5, 0, 1, -62)
			for _, button in { previousButton, nextButton } do
				button.Parent = buttonRow
				button.Position = UDim2.new()
				button.Size = UDim2.fromOffset(56, touch)
				button.TextSize = 22
			end
		end
		syncArrowLayer()
	end
	UiScaleController.onChanged(applyLayout)

	local screen = {}

	function screen.hide(_self: SpectateScreen)
		root.Visible = false
		syncArrowLayer()
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
		syncArrowLayer()
	end

	function screen.showIdle(_self: SpectateScreen, actionText: string)
		titleLabel.Visible = false
		previousButton.Visible = false
		nextButton.Visible = false
		actionButton.Text = actionText
		root.Visible = true
		syncArrowLayer()
	end

	return (screen :: any) :: SpectateScreen
end

return SpectateScreen
