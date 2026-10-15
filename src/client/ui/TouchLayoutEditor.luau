--!strict
-- 터치 버튼 위치 편집 화면 (m5-41). ⚙ → "버튼 위치 편집"(SettingsButton)이 열어요.
--   TouchLayoutEditor.open()    라운드에 배치된 동안(TouchLayoutController.isLocked)·터치 기기가 아니면 안 열려요
--   TouchLayoutEditor.isOpen()
--   TouchLayoutEditor.cancel()  바꾼 것을 버리고 닫아요 (라운드 배치가 오면 자동으로)
-- 화면: 반투명 덮개(아래 터치를 막음) + 점프·다이브·잡기 편집용 복사본(끌기) + 왼쪽 조이스틱 자리의 도구 칸
--   (작게 −·크게 +·프리셋 기본/크게/엄지 가까이·기본값으로·취소·저장). 겹치면 빨간 테두리 + 저장 끔.
-- 편집 중에는 진짜 버튼이 숨고 입력이 안 나가요 (TouchLayoutController.setEditing).
-- 규칙(크기·금지 구역·겹침)은 Shared.TouchLayoutLogic. 끄는 동안은 잡은 버튼만 맞추고, 겹쳐도 밀어내지 않아요.
-- 도구 칸은 UIScale 안 좌표, 버튼 높이는 실제 Config.Ui.MinTouchSize(44px) 이상 (TouchLayoutLogic.editorPanel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local TouchLayoutLogic = require(ReplicatedStorage.Shared.TouchLayoutLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local Loc = require(script.Parent.Parent.Loc)
local Kit = require(script.Parent.RoomUiKit)
local TouchLayoutController = require(script.Parent.Parent.input.TouchLayoutController)

local Color = Kit.Color

local TouchLayoutEditor = {}

-- 버튼 이름 (m5-26: 편집 화면을 열 때 그 사람 언어로)
local function labelOf(name: string): string
	if name == "jump" then
		return Loc.t("input.jump.btn")
	elseif name == "dive" then
		return Loc.t("input.dive.btn")
	end
	return Loc.t("input.grab.btn")
end
local SELECTED_COLOR = Color3.fromRGB(255, 255, 255)
local OVERLAP_COLOR = Color3.fromRGB(235, 60, 60)

type Session = {
	gui: ScreenGui,
	connections: { RBXScriptConnection },
	stops: { () -> () },
}

local session: Session? = nil

function TouchLayoutEditor.isOpen(): boolean
	return session ~= nil
end

local function close()
	local s = session
	if s == nil then
		return
	end
	session = nil
	for _, c in s.connections do
		c:Disconnect()
	end
	for _, stop in s.stops do
		stop()
	end
	s.gui:Destroy()
	TouchLayoutController.setEditing(false)
end

function TouchLayoutEditor.cancel()
	close()
end

function TouchLayoutEditor.open()
	if session ~= nil or not UserInputService.TouchEnabled or TouchLayoutController.isLocked() then
		return
	end
	local screen = TouchLayoutController.screen()
	if screen == nil then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end

	-- 시작 상태: 편집한 배치가 있으면 그것, 없으면 지금 보이는 기본 배치 (점프 실제 위치 기준)
	local startCustom = TouchLayoutController.current()
	local defaultStart = TouchLayoutController.defaultButtons()
	local buttons: UiLayout.TouchButtons = startCustom or defaultStart
	local preset: Types.TouchLayoutPreset = if startCustom then "custom" else "default"
	local selected: string? = nil
	local s: TouchLayoutLogic.Screen = screen

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchLayoutEditor"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.ScreenInsets = Enum.ScreenInsets.None -- 전체 화면 좌표 = 배치 좌표
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local current: Session = { gui = gui, connections = {}, stops = {} }
	session = current
	TouchLayoutController.setEditing(true)

	-- 덮개: 아래(게임 화면·조이스틱) 터치를 막아요
	local overlay = Kit.new("Frame", {
		Name = "Overlay",
		Parent = gui,
		Active = true,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	})
	-- 버튼이 못 가는 곳 (왼쪽 조이스틱 자리, 위쪽 띠)
	local joystickZone = Kit.new("Frame", {
		Name = "JoystickZone",
		Parent = overlay,
		BackgroundColor3 = Color3.fromRGB(120, 40, 40),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	})
	local joystickLabel = Kit.label({
		Parent = joystickZone,
		Text = Loc.t("input.layout.joystick"),
		TextColor3 = Color.White,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -16, 0, 24),
		TextSize = 16,
	})
	local topZone = Kit.new("Frame", {
		Name = "TopZone",
		Parent = overlay,
		BackgroundColor3 = Color3.fromRGB(120, 40, 40),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	})

	-- 편집용 복사본 (조작 버튼처럼 클릭음 없음)
	local copyLayer = Kit.new("Frame", {
		Name = "Buttons",
		Parent = overlay,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	copyLayer:SetAttribute(Attributes.NoClickSfx, true)
	local copies: { [string]: TextButton } = {}
	local strokes: { [string]: UIStroke } = {}
	for _, name in TouchLayoutLogic.NAMES do
		local copy = Kit.new("TextButton", {
			Name = name,
			Parent = copyLayer,
			AutoButtonColor = false,
			Text = labelOf(name),
			AutoLocalize = false, -- 이미 Loc으로 푼 글씨 (m5-26)
			TextScaled = true,
			Font = Kit.Font,
			TextColor3 = Color.White,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			BackgroundTransparency = 0.25,
			ZIndex = 3,
		}, {
			Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Kit.new("UIPadding", {
				PaddingLeft = UDim.new(0.15, 0),
				PaddingRight = UDim.new(0.15, 0),
				PaddingTop = UDim.new(0.3, 0),
				PaddingBottom = UDim.new(0.3, 0),
			}),
		})
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = copy
		copies[name] = copy
		strokes[name] = stroke
	end

	-- 도구 칸 (왼쪽 조이스틱 자리 — 버튼이 못 오는 곳이라 가리지 않아요)
	local panel = Kit.new("Frame", {
		Name = "Tools",
		Parent = overlay,
		ZIndex = 4,
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.15,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { Kit.corner(12) })
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local panelPadding = Kit.padding(6)
	panelPadding.Parent = panel
	local panelList = Kit.list(Enum.FillDirection.Vertical, 6)
	panelList.Parent = panel
	local info = Kit.label({
		Name = "Info",
		Parent = panel,
		LayoutOrder = 1,
		Text = Loc.t("input.layout.info"),
		TextColor3 = Color.White,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
	})
	local grid = Kit.new("Frame", {
		Name = "Grid",
		Parent = panel,
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	local gridLayout = Kit.new("UIGridLayout", {
		Parent = grid,
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 2,
	})

	local function tool(order: number, text: string, color: Color3): TextButton
		local button = Kit.button(text, color, { Parent = grid, LayoutOrder = order, ZIndex = 4, TextWrapped = true })
		return button
	end
	local smaller = tool(1, Loc.t("input.layout.smaller.btn"), Color.Nori)
	local bigger = tool(2, Loc.t("input.layout.bigger.btn"), Color.Nori)
	local presetDefault = tool(3, Loc.t("input.layout.presetDefault.btn"), Color.Egg)
	local presetLarge = tool(4, Loc.t("input.layout.presetLarge.btn"), Color.Egg)
	local presetCompact = tool(5, Loc.t("input.layout.presetCompact.btn"), Color.Egg)
	local resetButton = tool(6, Loc.t("input.layout.reset.btn"), Color.Neutral)
	resetButton.TextColor3 = Color.Text
	local cancelButton = tool(7, Loc.t("common.cancel.btn"), Color.Neutral)
	cancelButton.TextColor3 = Color.Text
	local saveButton = tool(8, Loc.t("input.layout.save.btn"), Color.Salmon)
	local toolButtons =
		{ smaller, bigger, presetDefault, presetLarge, presetCompact, resetButton, cancelButton, saveButton }

	local overlapping: { [string]: boolean } = {}

	local function render()
		local b = TouchLayoutLogic.bounds(s)
		joystickZone.Position = UDim2.fromOffset(0, 0)
		joystickZone.Size = UDim2.new(0, math.ceil(s.width * TouchLayoutLogic.LEFT_FORBIDDEN), 1, 0)
		topZone.Position = UDim2.fromOffset(math.ceil(s.width * TouchLayoutLogic.LEFT_FORBIDDEN), 0)
		topZone.Size = UDim2.new(1, -math.ceil(s.width * TouchLayoutLogic.LEFT_FORBIDDEN), 0, b.top)
		joystickLabel.Visible = s.height > 260

		overlapping = TouchLayoutLogic.overlaps(buttons)
		for _, name in TouchLayoutLogic.NAMES do
			local rect: UiLayout.Rect = (buttons :: any)[name]
			local copy = copies[name]
			local position, size = TouchLayoutController.place(gui, rect)
			copy.Position = position
			copy.Size = size
			local stroke = strokes[name]
			if overlapping[name] then
				stroke.Color = OVERLAP_COLOR
				stroke.Thickness = 4
				stroke.Transparency = 0
			elseif selected == name then
				stroke.Color = SELECTED_COLOR
				stroke.Thickness = 4
				stroke.Transparency = 0
			else
				stroke.Color = SELECTED_COLOR
				stroke.Thickness = 2
				stroke.Transparency = 0.5
			end
		end
		local hasOverlap = next(overlapping) ~= nil
		info.Text = if hasOverlap then Loc.t("input.layout.overlap") else Loc.t("input.layout.info")
		info.TextColor3 = if hasOverlap then Color3.fromRGB(255, 140, 140) else Color.White
		Kit.setEnabled(saveButton, not hasOverlap)
		Kit.setEnabled(smaller, selected ~= nil)
		Kit.setEnabled(bigger, selected ~= nil)
		Kit.setSelected(presetDefault, preset == "default")
		Kit.setSelected(presetLarge, preset == "large")
		Kit.setSelected(presetCompact, preset == "compact")
	end

	local function applyPanel()
		local m = UiLayout.metrics(s.width, s.height)
		local p = TouchLayoutLogic.editorPanel(s, m)
		panelScale.Scale = p.scale
		panel.Position = UDim2.fromOffset(p.x, p.y) -- 편집 gui = 전체 화면 좌표 (UIScale은 크기만 바꿔요)
		panel.Size = UDim2.fromOffset(p.width, 0)
		panelPadding.PaddingTop = UDim.new(0, p.gap)
		panelPadding.PaddingBottom = UDim.new(0, p.gap)
		panelPadding.PaddingLeft = UDim.new(0, p.gap)
		panelPadding.PaddingRight = UDim.new(0, p.gap)
		panelList.Padding = UDim.new(0, p.gap)
		info.TextSize = p.textSize
		info.Size = UDim2.new(1, 0, 0, p.textSize * 2 + 6)
		local rows = TouchLayoutLogic.PANEL_ROWS
		grid.Size = UDim2.new(1, 0, 0, p.rowHeight * rows + p.gap * (rows - 1))
		gridLayout.CellPadding = UDim2.fromOffset(p.gap, p.gap)
		gridLayout.CellSize = UDim2.new(0.5, -math.ceil(p.gap / 2), 0, p.rowHeight)
		for _, button in toolButtons do
			button.TextSize = p.textSize
		end
		joystickLabel.TextSize = UiLayout.textSize(16, m)
	end

	-- 처음 손대면 기본 배치도 규칙에 맞춰 둬요 (기기 기본 점프 자리가 금지 구역에 걸칠 수 있어요)
	local function beginEdit()
		if preset == "default" then
			buttons = (TouchLayoutLogic.clamp(buttons, s))
		end
		preset = "custom"
	end

	-- 끌기 -----------------------------------------------------------------
	local dragInput: InputObject? = nil
	local dragName: string? = nil
	local dragStart = Vector2.zero
	local dragRect: UiLayout.Rect? = nil

	for _, name in TouchLayoutLogic.NAMES do
		local copy = copies[name]
		table.insert(
			current.connections,
			copy.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
					return
				end
				if dragInput ~= nil then
					return
				end
				selected = name
				dragInput = input
				dragName = name
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
				local r: UiLayout.Rect = (buttons :: any)[name]
				dragRect = { x = r.x, y = r.y, size = r.size }
				render()
			end)
		)
	end

	table.insert(
		current.connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local active = dragInput
			local name = dragName
			local start = dragRect
			if active == nil or name == nil or start == nil then
				return
			end
			local same = input == active
				or (
					active.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			if not same then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			if delta.Magnitude < 1 then
				return
			end
			beginEdit()
			buttons = TouchLayoutLogic.move(buttons, name, start.x + delta.X, start.y + delta.Y, s)
			render()
		end)
	)
	table.insert(
		current.connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local active = dragInput
			if active == nil then
				return
			end
			if
				input == active
				or (
					active.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseButton1
				)
			then
				dragInput = nil
				dragName = nil
				dragRect = nil
			end
		end)
	)

	-- 도구 -----------------------------------------------------------------
	local function resize(direction: number)
		local name = selected
		if name == nil then
			return
		end
		beginEdit()
		buttons = TouchLayoutLogic.resize(buttons, name, direction, s)
		render()
	end
	table.insert(
		current.connections,
		Kit.onClick(smaller, function()
			resize(-1)
		end)
	)
	table.insert(
		current.connections,
		Kit.onClick(bigger, function()
			resize(1)
		end)
	)
	local function toDefault()
		buttons = TouchLayoutController.defaultButtons()
		preset = "default"
		selected = nil
		render()
	end
	table.insert(current.connections, Kit.onClick(presetDefault, toDefault))
	table.insert(current.connections, Kit.onClick(resetButton, toDefault))
	table.insert(
		current.connections,
		Kit.onClick(presetLarge, function()
			buttons = TouchLayoutLogic.preset("large", s)
			preset = "large"
			render()
		end)
	)
	table.insert(
		current.connections,
		Kit.onClick(presetCompact, function()
			buttons = TouchLayoutLogic.preset("compact", s)
			preset = "compact"
			render()
		end)
	)
	table.insert(current.connections, Kit.onClick(cancelButton, close))
	table.insert(
		current.connections,
		Kit.onClick(saveButton, function()
			if next(TouchLayoutLogic.overlaps(buttons)) ~= nil then
				return
			end
			local bucket = TouchLayoutLogic.bucketFor(s)
			if preset == "default" then
				TouchLayoutController.save(bucket, nil) -- 그 묶음 저장값을 지워요
			else
				TouchLayoutController.save(bucket, TouchLayoutLogic.fromScreen(buttons, s, preset))
			end
			close()
		end)
	)

	-- 라운드에 배치되면 저장하지 않고 닫아요
	table.insert(
		current.stops,
		TouchLayoutController.lockChanged(function(isLocked: boolean)
			if isLocked and session == current then
				close()
			end
		end)
	)
	-- 화면 크기가 바뀌면(회전·기기 바꾸기) 비율대로 옮겨 맞춰요
	table.insert(
		current.stops,
		TouchLayoutController.changed(function()
			if session ~= current then
				return
			end
			local fresh = TouchLayoutController.screen()
			if fresh == nil or (fresh.width == s.width and fresh.height == s.height) then
				return
			end
			if preset == "default" then
				s = fresh
				buttons = TouchLayoutController.defaultButtons()
			else
				local layout = TouchLayoutLogic.fromScreen(buttons, s, preset)
				s = fresh
				buttons = (TouchLayoutLogic.fit(TouchLayoutLogic.toScreen(layout, s), s))
			end
			applyPanel()
			render()
		end)
	)

	gui.Parent = playerGui
	applyPanel()
	render()
end

return TouchLayoutEditor
