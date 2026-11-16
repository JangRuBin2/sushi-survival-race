--!strict
-- 터치 조작 버튼 겉모습 (m6-14 C2): 밝은 접시색 원 + 나무 테두리, 가운데 아이콘(IconAssets id가 있을 때) 또는 글씨 폴백,
-- 쿨다운은 아이콘 위 어두운 덮개(아래에서 차오름) + 남은 초. 계산은 Shared.TouchButtonFaceLogic(순수).
-- 위치·크기는 부르는 쪽(DiveButton·GrabButton·AttackButton)이 지금 규칙(UiLayout.touchButtons·편집 배치)대로 정해요.
--   TouchButtonFace.create(name, parent) -> Face
--   face.button                         눌림을 받는 TextButton (Position·Size·Visible은 부르는 쪽이)
--   face.setIcon(iconName, fallbackText)   IconAssets.image(iconName)가 있으면 그림, 없으면 글씨
--   face.setCooldown(fraction, text?)      0~1 덮개(0이면 숨김), text가 있으면 덮개 위에 크게
--   face.setTone(tone)                     "Idle" 기본 · "Active" 잡는 중 · "Armed" 다이너마이트를 듦

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconAssets = require(ReplicatedStorage.Shared.IconAssets)
local TouchButtonFaceLogic = require(ReplicatedStorage.Shared.TouchButtonFaceLogic)
local Kit = require(script.Parent.Parent.ui.RoomUiKit)

local Color = Kit.Color

export type Tone = "Idle" | "Active" | "Armed"

export type Face = {
	button: TextButton,
	setIcon: (iconName: IconAssets.Name, fallbackText: string) -> (),
	setCooldown: (fraction: number, text: string?) -> (),
	setTone: (tone: Tone) -> (),
}

-- 고정 표 (톤 3개)
local TONES = {
	Idle = { plate = Color.Row, stroke = Color.Wood },
	Active = { plate = Color.Egg, stroke = Color.Wood },
	Armed = { plate = Color3.fromRGB(255, 226, 150), stroke = Color.Salmon },
} :: { [Tone]: { plate: Color3, stroke: Color3 } }

-- 접시 위→아래 음영 (배경색에 곱해져요)
local PLATE_SHADE = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 214, 198))

local TouchButtonFace = {}

function TouchButtonFace.create(name: string, parent: Instance): Face
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.AutoLocalize = false -- m5-26: 글씨는 Loc으로 이미 번역했어요
	button.Text = ""
	button.BackgroundColor3 = TONES.Idle.plate
	button.BackgroundTransparency = 0.06
	button.BorderSizePixel = 0
	button.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = PLATE_SHADE
	shade.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = TONES.Idle.stroke
	stroke.Thickness = TouchButtonFaceLogic.STROKE_MIN
	stroke.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(TouchButtonFaceLogic.ICON_SCALE, TouchButtonFaceLogic.ICON_SCALE)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	icon.Active = false
	icon.ZIndex = 2
	icon.Parent = button

	local inset = TouchButtonFaceLogic.TEXT_INSET
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1 - 2 * inset, 1 - 2.6 * inset)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color.Text
	label.Text = ""
	label.Active = false
	label.ZIndex = 2
	label.Parent = button

	-- 쿨다운 덮개: 버튼과 같은 동그란 판, 세로 그라디언트 투명도로 아래에서 차올라요 (모서리도 둥글게 잘려요)
	local cover = Instance.new("Frame")
	cover.Name = "Cooldown"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0
	cover.BorderSizePixel = 0
	cover.Visible = false
	cover.Active = false
	cover.ZIndex = 3
	cover.Parent = button
	local coverCorner = Instance.new("UICorner")
	coverCorner.CornerRadius = UDim.new(0.5, 0)
	coverCorner.Parent = cover
	local coverFill = Instance.new("UIGradient")
	coverFill.Rotation = 90
	coverFill.Parent = cover

	local count = Instance.new("TextLabel")
	count.Name = "Seconds"
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.5)
	count.Size = UDim2.fromScale(0.62, 0.5)
	count.BackgroundTransparency = 1
	count.AutoLocalize = false
	count.Font = Kit.Font
	count.TextScaled = true
	count.TextColor3 = Color.White
	count.Text = ""
	count.Visible = false
	count.Active = false
	count.ZIndex = 4
	count.Parent = button
	local countStroke = Instance.new("UIStroke")
	countStroke.Color = Color.Nori
	countStroke.Thickness = 2
	countStroke.Parent = count

	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local size = button.AbsoluteSize
		stroke.Thickness = TouchButtonFaceLogic.strokeThickness(math.min(size.X, size.Y))
	end)
	button.Parent = parent

	local shownFraction = -1
	local hasCount = false
	return {
		button = button,
		setIcon = function(iconName: IconAssets.Name, fallbackText: string)
			local face = TouchButtonFaceLogic.face(IconAssets.image(iconName), fallbackText)
			local image = face.image
			if image then
				icon.Image = image
				icon.Visible = true
			else
				icon.Visible = false
			end
			label.Text = face.text
			label.Visible = face.text ~= "" and not hasCount -- 글씨 폴백은 쿨다운 숫자와 겹치지 않게
		end,
		setCooldown = function(fraction: number, text: string?)
			-- 1/50 단위로만 다시 그려요 (매 프레임 부르니까)
			local quantized = math.floor(math.clamp(fraction, 0, 1) * 50 + 0.5) / 50
			if quantized ~= shownFraction then
				shownFraction = quantized
				local keys = TouchButtonFaceLogic.coverKeys(quantized)
				if keys then
					local points = {}
					for _, key in keys do
						table.insert(points, NumberSequenceKeypoint.new(key.time, key.value))
					end
					coverFill.Transparency = NumberSequence.new(points)
					cover.Visible = true
				else
					cover.Visible = false
				end
			end
			if text then
				count.Text = text
			end
			hasCount = text ~= nil
			count.Visible = hasCount
			label.Visible = label.Text ~= "" and not hasCount
		end,
		setTone = function(tone: Tone)
			local colors = TONES[tone]
			button.BackgroundColor3 = colors.plate
			stroke.Color = colors.stroke
		end,
	}
end

return TouchButtonFace
