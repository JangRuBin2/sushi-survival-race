--!strict
-- 우승 연출 큰 글씨 (m3-05): 화면 가운데 위쪽에 "{이름} 탈출 성공!" / "탈출 성공! 🏆".
-- 크고 두꺼운 글씨(Fall Guys 결과 글씨, docs/REFERENCE-party-royale.md §3). 휴대폰에서도 잘리지 않게
-- 화면 폭 비율 + TextScaled(최대 크기 제한)로 맞춰요.
-- 다른 UI 위에 뜨도록 자기 ScreenGui(DisplayOrder 높음)를 따로 가져요.

local TweenService = game:GetService("TweenService")

export type VictoryCutsceneScreen = {
	show: (self: VictoryCutsceneScreen, text: string) -> (),
	hide: (self: VictoryCutsceneScreen) -> (),
}

local VictoryCutsceneScreen = {}

local DISPLAY_ORDER = 50
local MAX_TEXT_SIZE = 84

function VictoryCutsceneScreen.new(playerGui: Instance): VictoryCutsceneScreen
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VictoryCutscene"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = DISPLAY_ORDER
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.22)
	label.Size = UDim2.fromScale(0.9, 0.16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.Text = ""
	label.Parent = screenGui

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = MAX_TEXT_SIZE
	sizeLimit.MinTextSize = 18
	sizeLimit.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(90, 40, 10)
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = label

	local popTween: Tween? = nil

	local screen = {}

	function screen.show(_self: VictoryCutsceneScreen, text: string)
		label.Text = text
		screenGui.Enabled = true
		if popTween then
			popTween:Cancel()
		end
		-- 쾅 하고 커지며 나타나요
		scale.Scale = 0.3
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		popTween = tween
		tween:Play()
	end

	function screen.hide(_self: VictoryCutsceneScreen)
		if popTween then
			popTween:Cancel()
			popTween = nil
		end
		screenGui.Enabled = false
		label.Text = ""
	end

	return (screen :: any) :: VictoryCutsceneScreen
end

return VictoryCutsceneScreen
