--!strict
-- 탈락 연출 UI (m3-03): 본인 화면의 "먹혔다!" 도장 스탬프 + 등수, 손님·셰프 머리 위 말풍선.
--   showStamp(gui, place, duration)  화면 가운데에 쾅 찍혀요. 돌려준 함수를 부르면 지워요 (duration 뒤 저절로 사라지기도 해요).
--   speechBubble(adornee, text)      BillboardGui 말풍선이 톡 튀어나와요. adornee를 지우면 같이 지워져요.
-- 글씨는 TextScaled + 최대 크기 제한이라 휴대폰 화면에서도 잘리지 않아요.

local TweenService = game:GetService("TweenService")

local EliminationCutsceneScreen = {}

local FONT = Enum.Font.GothamBlack
local STAMP_RED = Color3.fromRGB(214, 40, 40)
local STAMP_ZINDEX = 40

local function stroke(parent: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function textLabel(props: {
	name: string,
	text: string,
	color: Color3,
	size: UDim2,
	position: UDim2,
	maxTextSize: number,
	parent: Instance,
	zIndex: number,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.name
	label.Text = props.text
	label.Font = FONT
	label.TextColor3 = props.color
	label.TextScaled = true
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = props.size
	label.Position = props.position
	label.ZIndex = props.zIndex
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = props.maxTextSize
	limit.MinTextSize = 8
	limit.Parent = label
	label.Parent = props.parent
	return label
end

function EliminationCutsceneScreen.showStamp(gui: Instance, place: number?, duration: number): () -> ()
	local root = Instance.new("Frame")
	root.Name = "EliminatedStamp"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.4)
	root.Size = UDim2.fromScale(0.62, 0.3)
	root.BackgroundTransparency = 1
	root.ZIndex = STAMP_ZINDEX
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 220)
	sizeLimit.Parent = root
	local scale = Instance.new("UIScale")
	scale.Scale = 2.4
	scale.Parent = root

	-- 빨간 도장 테두리 (살짝 기울어짐)
	local seal = Instance.new("Frame")
	seal.Name = "Seal"
	seal.AnchorPoint = Vector2.new(0.5, 0.5)
	seal.Position = UDim2.fromScale(0.5, 0.36)
	seal.Size = UDim2.fromScale(0.86, 0.62)
	seal.Rotation = -8
	seal.BackgroundColor3 = Color3.fromRGB(255, 244, 236)
	seal.BackgroundTransparency = 0.15
	seal.ZIndex = STAMP_ZINDEX
	seal.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = seal
	stroke(seal, STAMP_RED, 6, Enum.ApplyStrokeMode.Border)

	local title = textLabel({
		name = "Title",
		text = "먹혔다!",
		color = STAMP_RED,
		size = UDim2.fromScale(0.88, 0.8),
		position = UDim2.fromScale(0.5, 0.5),
		maxTextSize = 96,
		parent = seal,
		zIndex = STAMP_ZINDEX + 1,
	})
	stroke(title, Color3.fromRGB(110, 10, 10), 2)

	if place then
		local placeLabel = textLabel({
			name = "Place",
			text = `{place}등`,
			color = Color3.fromRGB(255, 255, 255),
			size = UDim2.fromScale(0.5, 0.26),
			position = UDim2.fromScale(0.5, 0.86),
			maxTextSize = 48,
			parent = root,
			zIndex = STAMP_ZINDEX + 1,
		})
		stroke(placeLabel, Color3.fromRGB(40, 20, 20), 3)
	end

	root.Parent = gui

	-- 쾅: 크게 시작해서 살짝 작아졌다가 제자리
	local slam = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.92,
	})
	local settle = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	slam.Completed:Connect(function()
		if root.Parent then
			settle:Play()
		end
	end)
	slam:Play()

	local destroyed = false
	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		slam:Cancel()
		settle:Cancel()
		root:Destroy()
	end
	task.delay(duration, destroy)
	return destroy
end

function EliminationCutsceneScreen.speechBubble(adornee: BasePart, text: string): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpeechBubble"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	billboard.Size = UDim2.fromOffset(200, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bubble.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = bubble
	stroke(bubble, Color3.fromRGB(40, 40, 40), 3, Enum.ApplyStrokeMode.Border)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = bubble
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = bubble

	textLabel({
		name = "Line",
		text = text,
		color = Color3.fromRGB(30, 30, 30),
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		maxTextSize = 26,
		parent = bubble,
		zIndex = 2,
	})

	billboard.Parent = adornee
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	return billboard
end

return EliminationCutsceneScreen
