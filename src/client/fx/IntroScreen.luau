--!strict
-- "출발!" 큰 글씨 (m3-04). 라운드가 시작되는 순간 화면 가운데에 커졌다가 사라져요.
-- LobbyScreen/HudScreen과 같은 ScreenGui 위에 떠요.

-- 위치·크기는 띄울 때마다 HUD 위 배너(맵 이름·규칙)의 실제 아래 가장자리를 기준으로 Shared.IntroLayout이 정해요
-- (사용자 수정 지시, m3-09: 휴대폰 가로 화면에서 배너를 덮지 않게).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local IntroLayout = require(ReplicatedStorage.Shared.IntroLayout)
local HudScreen = require(script.Parent.Parent.ui.HudScreen)

export type IntroScreen = {
	showGo: (self: IntroScreen, duration: number) -> (),
	hide: (self: IntroScreen) -> (),
}

local IntroScreen = {}

local GO_TEXT = "출발!"
local POP_FRACTION = 0.25 -- 전체 시간 중 커지는 구간
local START_SCALE = 0.4
local PEAK_SCALE = 1.15
local END_SCALE = IntroLayout.MAX_SCALE -- 가장 커지는 배율 (배치 계산도 이 크기로 겹침을 피해요)

-- HUD 위 배너의 아래 끝 (parent 기준 픽셀). 못 찾으면 IntroLayout 기본값.
local function bannerBottom(parent: Instance): number
	local hud = parent:FindFirstChild(HudScreen.ROOT_NAME)
	local banner = hud and hud:FindFirstChild(HudScreen.TOP_BANNER_NAME)
	if banner == nil or not banner:IsA("GuiObject") then
		return IntroLayout.bannerBottom(nil, nil)
	end
	local guiTop = if parent:IsA("GuiBase2d") then parent.AbsolutePosition.Y else 0
	return IntroLayout.bannerBottom(banner.AbsolutePosition.Y, banner.AbsoluteSize.Y, guiTop)
end

function IntroScreen.new(parent: Instance): IntroScreen
	local label = Instance.new("TextLabel")
	label.Name = "IntroGo"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, IntroLayout.PREFERRED_CENTER_SCALE)
	label.Size = UDim2.fromOffset(IntroLayout.TEXT_SIZE * IntroLayout.BOX_WIDTH_RATIO, 160)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = GO_TEXT
	label.TextSize = IntroLayout.TEXT_SIZE
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextStrokeColor3 = Color3.fromRGB(70, 30, 10)
	label.TextStrokeTransparency = 0
	label.ZIndex = 50
	label.Visible = false

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = START_SCALE
	uiScale.Parent = label
	label.Parent = parent

	local token = 0
	local running: { Tween } = {}

	local function stopTweens()
		for _, tween in running do
			tween:Cancel()
		end
		table.clear(running)
	end

	local function play(instance: Instance, seconds: number, style: Enum.EasingStyle, goal: { [string]: any })
		local tween = TweenService:Create(instance, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), goal)
		table.insert(running, tween)
		tween:Play()
		return tween
	end

	-- 지금 화면 크기와 HUD 배너 위치로 자리·크기를 다시 정해요
	local function place()
		if not parent:IsA("GuiBase2d") then
			return
		end
		local size = parent.AbsoluteSize
		if size.Y <= 0 then
			return
		end
		local layout = IntroLayout.compute(size.X, size.Y, bannerBottom(parent))
		label.Position = UDim2.new(0.5, 0, 0, layout.centerY)
		label.Size = UDim2.fromOffset(layout.boxWidth, layout.boxHeight)
		label.TextSize = layout.textSize
	end

	local screen = {}

	function screen.hide(_self: IntroScreen)
		token += 1
		stopTweens()
		label.Visible = false
	end

	function screen.showGo(_self: IntroScreen, duration: number)
		token += 1
		local mine = token
		stopTweens()
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0
		uiScale.Scale = START_SCALE
		place()
		label.Visible = true

		local popTime = duration * POP_FRACTION
		local fadeTime = duration - popTime
		play(uiScale, popTime, Enum.EasingStyle.Back, { Scale = PEAK_SCALE })
		task.delay(popTime, function()
			if token ~= mine then
				return
			end
			play(uiScale, fadeTime, Enum.EasingStyle.Quad, { Scale = END_SCALE })
			play(label, fadeTime, Enum.EasingStyle.Quad, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
		task.delay(duration, function()
			if token == mine then
				label.Visible = false
			end
		end)
	end

	return (screen :: any) :: IntroScreen
end

return IntroScreen
