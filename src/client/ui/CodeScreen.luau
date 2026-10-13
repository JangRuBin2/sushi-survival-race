--!strict
-- "🎟 코드" 창 화면 (m5-10). 자기 ScreenGui `CodeGui`. 보여 주기만 하고 요청은 actions로 넘겨요.
--   열기 버튼 "🎟 코드": 왼쪽 위, "🍣 스킨"(y10)·"🎁 상점"(y60) 아래 (기본 y110, 110 × 44). CodeController가 보일지 정해요.
--   창: 제목 "코드 넣기" + 닫기, 텍스트 칸(최대 Config.Codes.MaxLength자), "받기", 결과 한 줄, 안내 한 줄.
--   compact(휴대폰)에서는 창을 화면 위쪽에 붙여서 화면 키보드에 안 가려지게 해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	open: () -> (),
	close: () -> (),
	submit: (text: string) -> (),
}

export type CodeScreen = {
	gui: ScreenGui,
	setButtonVisible: (self: CodeScreen, visible: boolean) -> (),
	setOpen: (self: CodeScreen, open: boolean) -> (),
	isOpen: (self: CodeScreen) -> boolean,
	setBusy: (self: CodeScreen, busy: boolean) -> (),
	showResult: (self: CodeScreen, text: string, isError: boolean) -> (),
	clearInput: (self: CodeScreen) -> (),
	setLayout: (self: CodeScreen, m: UiLayout.Metrics) -> (),
}

local CodeScreen = {}

local WINDOW_SIZE = Vector2.new(420, 250)
local GAP = 8
local BUTTON_GAP = 6 -- 왼쪽 위 버튼 사이 간격
local BUTTON_ROW = 2 -- 0 = 🍣 스킨, 1 = 🎁 상점, 2 = 🎟 코드

local function buttonY(buttonHeight: number): number
	return 10 + BUTTON_ROW * (buttonHeight + BUTTON_GAP)
end

function CodeScreen.new(playerGui: Instance, actions: Actions): CodeScreen
	local gui = Kit.new("ScreenGui", {
		Name = "CodeGui",
		ResetOnSpawn = false,
		DisplayOrder = 20, -- 탈의실과 같은 층 (코인 토스트 55 아래)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local openButton = Kit.button(Loc.t("code.open.btn"), Color.Egg, {
		Name = "CodeButton",
		Parent = gui,
		Position = UDim2.fromOffset(12, buttonY(44)),
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
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = Color.Panel,
		Active = true,
	}, {
		Kit.corner(16),
		Kit.padding(14),
		Kit.list(Enum.FillDirection.Vertical, GAP),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 400) }),
	})

	local header = Kit.new("Frame", {
		Name = "Header",
		Parent = window,
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	})
	local titleLabel = Kit.label({
		Parent = header,
		Text = Loc.t("code.title"),
		TextSize = 24,
		Size = UDim2.new(1, -52, 1, 0),
	})
	local closeButton = Kit.button("✕", Color.Nori, {
		Name = "Close",
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
	})
	Kit.onClick(closeButton, actions.close)

	local inputRow = Kit.new("Frame", {
		Name = "InputRow",
		Parent = window,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	})
	local input = Kit.textBox({
		Name = "CodeInput",
		Parent = inputRow,
		PlaceholderText = Loc.t("code.enterCode"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -(100 + GAP), 1, 0),
	}) :: TextBox
	local submitButton = Kit.button(Loc.t("code.redeem.btn"), Color.Salmon, {
		Name = "Submit",
		Parent = inputRow,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 100, 1, 0),
	})

	local resultLabel = Kit.label({
		Name = "Result",
		Parent = window,
		LayoutOrder = 3,
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
	})
	local hintLabel = Kit.label({
		Name = "Hint",
		Parent = window,
		LayoutOrder = 4,
		Text = Loc.t("code.hint"),
		TextColor3 = Color.SubText,
		TextSize = 14,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
	})

	-- 최대 길이: 붙여 넣은 것도 잘라요 (서버가 다시 검사해요)
	local maxLength = Config.Codes.MaxLength
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if #input.Text > maxLength then
			input.Text = string.sub(input.Text, 1, maxLength)
		end
	end)

	local busy = false
	local function submit()
		if busy then
			return
		end
		actions.submit(input.Text)
	end
	Kit.onClick(submitButton, submit)
	input.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	local resultToken = 0
	local screen = { gui = gui } :: CodeScreen

	function screen.setButtonVisible(_self: CodeScreen, visible: boolean)
		openButton.Visible = visible
	end

	function screen.setOpen(_self: CodeScreen, open: boolean)
		backdrop.Visible = open
		if not open then
			input:ReleaseFocus()
			resultToken += 1
			resultLabel.Text = ""
		end
	end

	function screen.isOpen(_self: CodeScreen): boolean
		return backdrop.Visible
	end

	function screen.setBusy(_self: CodeScreen, value: boolean)
		busy = value
		Kit.setEnabled(submitButton, not value)
		input.TextEditable = not value
	end

	function screen.showResult(_self: CodeScreen, text: string, isError: boolean)
		resultToken += 1
		local mine = resultToken
		resultLabel.Text = text
		resultLabel.TextColor3 = if isError then Color.Error else Color.Nori
		task.delay(6, function()
			if resultToken == mine then
				resultLabel.Text = ""
			end
		end)
	end

	function screen.clearInput(_self: CodeScreen)
		input.Text = ""
	end

	function screen.setLayout(_self: CodeScreen, m: UiLayout.Metrics)
		local text = function(base: number): number
			return UiLayout.textSize(base, m)
		end
		local buttonHeight = UiLayout.touchSize(44, m)
		openButton.Position = UDim2.fromOffset(12, buttonY(buttonHeight))
		openButton.Size = UDim2.fromOffset(110, buttonHeight)
		openButton.TextSize = text(18)
		header.Size = UDim2.new(1, 0, 0, buttonHeight)
		titleLabel.TextSize = text(24)
		titleLabel.Size = UDim2.new(1, -(buttonHeight + 8), 1, 0)
		closeButton.Size = UDim2.fromOffset(buttonHeight, buttonHeight)
		inputRow.Size = UDim2.new(1, 0, 0, buttonHeight)
		input.TextSize = text(18)
		submitButton.TextSize = text(18)
		local resultHeight = UiLayout.lineHeight(26, m, 18)
		resultLabel.Size = UDim2.new(1, 0, 0, resultHeight)
		resultLabel.TextSize = text(18)
		local hintHeight = UiLayout.lineHeight(40, m, 14)
		hintLabel.Size = UDim2.new(1, 0, 0, hintHeight)
		hintLabel.TextSize = text(14)
		local height = 28 + buttonHeight * 2 + resultHeight + hintHeight + GAP * 3
		if m.compact then
			-- 휴대폰: 화면 위쪽에 붙여서 아래에서 올라오는 키보드에 덜 가려지게
			window.AnchorPoint = Vector2.new(0.5, 0)
			window.Position = UDim2.new(0.5, 0, 0, 8)
			window.Size = UDim2.new(0.9, 0, 0, height)
		else
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.Position = UDim2.fromScale(0.5, 0.5)
			window.Size = UDim2.fromOffset(WINDOW_SIZE.X, math.max(WINDOW_SIZE.Y, height))
		end
	end

	return screen
end

return CodeScreen
