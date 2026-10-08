--!strict
-- 로비·방 대기실 화면에서 같이 쓰는 UI 도우미. 화면은 스튜디오 에셋 없이 코드로 만들어요.

local Kit = {}

Kit.Color = {
	Backdrop = Color3.fromRGB(30, 22, 20),
	Panel = Color3.fromRGB(255, 248, 235),
	Row = Color3.fromRGB(246, 234, 214),
	Text = Color3.fromRGB(55, 38, 32),
	SubText = Color3.fromRGB(135, 112, 100),
	Salmon = Color3.fromRGB(236, 104, 72),
	Egg = Color3.fromRGB(246, 196, 70),
	Nori = Color3.fromRGB(58, 74, 60),
	Neutral = Color3.fromRGB(214, 202, 190),
	Disabled = Color3.fromRGB(196, 190, 184),
	Error = Color3.fromRGB(200, 52, 52),
	White = Color3.fromRGB(255, 255, 255),
}

Kit.Font = Enum.Font.GothamBold

-- Instance.new + 속성 + 자식. Parent는 마지막에 넣어요.
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function merge(defaults: { [string]: any }, props: { [string]: any }?): { [string]: any }
	local result = table.clone(defaults)
	for key, value in props or {} do
		result[key] = value
	end
	return result
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Kit.padding(px: number): UIPadding
	local p = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Kit.list(direction: Enum.FillDirection, gap: number, props: { [string]: any }?): UIListLayout
	return Kit.new(
		"UIListLayout",
		merge({
			FillDirection = direction,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, props)
	)
end

function Kit.label(props: { [string]: any }?): TextLabel
	return Kit.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Kit.Font,
			TextColor3 = Kit.Color.Text,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 24),
		}, props)
	)
end

function Kit.textBox(props: { [string]: any }?): TextBox
	return Kit.new(
		"TextBox",
		merge({
			BackgroundColor3 = Kit.Color.White,
			Font = Kit.Font,
			TextColor3 = Kit.Color.Text,
			PlaceholderColor3 = Kit.Color.SubText,
			TextSize = 18,
			Text = "",
			ClearTextOnFocus = false,
			Size = UDim2.fromOffset(160, 44),
		}, props),
		{ Kit.corner(8), Kit.padding(8) }
	)
end

-- 버튼. 색은 BaseColor 속성에 기억해 두고 setEnabled/setSelected가 바꿔요.
function Kit.button(text: string, color: Color3, props: { [string]: any }?): TextButton
	local button = Kit.new(
		"TextButton",
		merge({
			Text = text,
			BackgroundColor3 = color,
			Font = Kit.Font,
			TextColor3 = Kit.Color.White,
			TextSize = 18,
			AutoButtonColor = true,
			Size = UDim2.fromOffset(140, 44),
		}, props),
		{ Kit.corner(10) }
	)
	button:SetAttribute("BaseColor", color)
	return button
end

function Kit.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then button:GetAttribute("BaseColor") :: Color3 else Kit.Color.Disabled
end

-- 선택형 버튼(인원, 공개/비공개): 선택되면 BaseColor, 아니면 회색
function Kit.setSelected(button: TextButton, selected: boolean)
	button.BackgroundColor3 = if selected then button:GetAttribute("BaseColor") :: Color3 else Kit.Color.Neutral
	button.TextColor3 = if selected then Kit.Color.White else Kit.Color.Text
end

-- 비활성(Active = false) 버튼은 눌러도 무시해요.
function Kit.onClick(button: TextButton, handler: () -> ()): RBXScriptConnection
	return button.Activated:Connect(function()
		if button.Active then
			handler()
		end
	end)
end

export type ShowMessage = (text: string, isError: boolean?) -> ()

-- 터치 스크롤 목록 (세로만, 내용만큼 캔버스가 늘어나요). 두께는 화면 배율에 맞춰 바꿔요 (m4-09).
function Kit.scrollList(props: { [string]: any }?, gap: number): ScrollingFrame
	return Kit.new(
		"ScrollingFrame",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Kit.Color.SubText,
		}, props),
		{ Kit.list(Enum.FillDirection.Vertical, gap) }
	)
end

-- 화면 아래쪽 안내/오류 문구. 몇 초 뒤 사라져요. 두 번째 값은 크기를 바꿀 때 쓰는 라벨이에요.
function Kit.messageLabel(parent: Instance, layoutOrder: number): (ShowMessage, TextLabel)
	local label = Kit.label({
		Parent = parent,
		LayoutOrder = layoutOrder,
		Text = "",
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
	})
	local token = 0
	local function show(text: string, isError: boolean?)
		token += 1
		local mine = token
		label.Text = text
		label.TextColor3 = if isError then Kit.Color.Error else Kit.Color.SubText
		task.delay(4, function()
			if token == mine then
				label.Text = ""
			end
		end)
	end
	return show, label
end

return Kit
