--!strict
-- "출발!" 큰 글씨 (m3-04). 라운드가 시작되는 순간 화면 가운데에 커졌다가 사라져요.
-- LobbyScreen/HudScreen과 같은 ScreenGui 위에 떠요.

local TweenService = game:GetService("TweenService")

export type IntroScreen = {
	showGo: (self: IntroScreen, duration: number) -> (),
	hide: (self: IntroScreen) -> (),
}

local IntroScreen = {}

local GO_TEXT = "출발!"
local POP_FRACTION = 0.25 -- 전체 시간 중 커지는 구간
local START_SCALE = 0.4
local PEAK_SCALE = 1.15
local END_SCALE = 1.4

function IntroScreen.new(parent: Instance): IntroScreen
	local label = Instance.new("TextLabel")
	label.Name = "IntroGo"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromOffset(600, 160)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = GO_TEXT
	label.TextSize = 120
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
