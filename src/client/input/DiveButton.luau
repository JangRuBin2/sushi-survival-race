--!strict
-- 모바일 다이브 버튼 (m3-06). 터치 기기에서 기본 점프 버튼이 있을 때만 만들어요.
--   DiveButton.create(onPress) -> DiveButton?   터치 기기가 아니면 nil
--   button:setCooldown(fraction)                 0~1, 남은 쿨다운 비율 (위에서부터 줄어드는 덮개)
--   button:destroy()
-- 점프 버튼(PlayerGui.TouchGui.TouchControlFrame.JumpButton) 왼쪽에 같은 크기로 붙고,
-- 점프 버튼 위치·크기가 바뀌면(화면 회전 등) 다시 맞춰요.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Cleanup = require(game:GetService("ReplicatedStorage").Shared.Cleanup)

local GAP_RATIO = 0.15 -- 점프 버튼과의 간격 (버튼 폭 대비)

local DiveButton = {}
DiveButton.__index = DiveButton

export type DiveButton = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		button: TextButton,
		cover: Frame,
		cleanup: Cleanup.Cleanup,
		jumpCleanup: Cleanup.Cleanup,
	},
	DiveButton
))

local function findJumpButton(playerGui: Instance): GuiObject?
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") then
		return jump
	end
	return nil
end

function DiveButton.create(onPress: () -> ()): DiveButton?
	if not UserInputService.TouchEnabled then
		return nil
	end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DiveGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false -- 점프 버튼을 찾을 때까지 숨겨요
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local button = Instance.new("TextButton")
	button.Name = "DiveButton"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	button.BackgroundTransparency = 0.45
	button.BorderSizePixel = 0
	button.Text = "다이브"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.ClipsDescendants = true
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.4
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.15, 0)
	padding.PaddingRight = UDim.new(0.15, 0)
	padding.PaddingTop = UDim.new(0.3, 0)
	padding.PaddingBottom = UDim.new(0.3, 0)
	padding.Parent = button

	-- 쿨다운 덮개: 아래에 붙어 있고 높이가 남은 비율만큼이라 위에서부터 줄어들어요.
	-- 패딩 영향을 받지 않게 버튼과 같은 위치·크기의 별도 프레임으로 둬요.
	local coverHolder = Instance.new("Frame")
	coverHolder.Name = "CooldownHolder"
	coverHolder.BackgroundTransparency = 1
	coverHolder.ClipsDescendants = true
	coverHolder.Active = false
	coverHolder.ZIndex = 2
	coverHolder.Parent = gui

	local holderCorner = Instance.new("UICorner")
	holderCorner.CornerRadius = UDim.new(0.5, 0)
	holderCorner.Parent = coverHolder

	local cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.AnchorPoint = Vector2.new(0, 1)
	cover.Position = UDim2.fromScale(0, 1)
	cover.Size = UDim2.fromScale(1, 0)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0.35
	cover.BorderSizePixel = 0
	cover.Active = false
	cover.ZIndex = 2
	cover.Parent = coverHolder

	gui.Parent = playerGui

	local self = setmetatable({
		gui = gui,
		button = button,
		cover = cover,
		cleanup = Cleanup.new(),
		jumpCleanup = Cleanup.new(),
	}, DiveButton)
	self.cleanup:add(gui)

	local function layout(jump: GuiObject)
		local size = jump.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		-- 점프 버튼의 화면 좌표를 우리 ScreenGui 좌표로 바꿔요 (GUI 인셋 차이 흡수)
		local origin = jump.AbsolutePosition - gui.AbsolutePosition
		local x = origin.X - size.X * GAP_RATIO - size.X
		local position = UDim2.fromOffset(x, origin.Y)
		local buttonSize = UDim2.fromOffset(size.X, size.Y)
		button.Position = position
		button.Size = buttonSize
		coverHolder.Position = position
		coverHolder.Size = buttonSize
		gui.Enabled = jump.Visible
	end

	local function attach(jump: GuiObject)
		self.jumpCleanup:run()
		local relayout = function()
			layout(jump)
		end
		self.jumpCleanup:add(jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(relayout))
		self.jumpCleanup:add(jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))
		self.jumpCleanup:add(jump:GetPropertyChangedSignal("Visible"):Connect(relayout))
		self.jumpCleanup:add(gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(relayout))
		self.jumpCleanup:add(jump.AncestryChanged:Connect(function()
			if not jump:IsDescendantOf(playerGui) then
				self.jumpCleanup:run()
				gui.Enabled = false
			end
		end))
		relayout()
	end

	local function refind()
		local jump = findJumpButton(playerGui)
		if jump then
			attach(jump)
		end
	end

	-- TouchGui·JumpButton은 PlayerModule이 늦게 만들 수 있어요
	self.cleanup:add(playerGui.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "JumpButton" or descendant.Name == "TouchGui" then
			task.defer(refind)
		end
	end))
	local camera = workspace.CurrentCamera
	if camera then
		self.cleanup:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(refind)
		end))
	end
	refind()

	self.cleanup:add(button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			onPress()
		end
	end))

	return self
end

function DiveButton.setCooldown(self: DiveButton, fraction: number)
	local clamped = math.clamp(fraction, 0, 1)
	if self.cover.Size.Y.Scale ~= clamped then
		self.cover.Size = UDim2.fromScale(1, clamped)
	end
end

function DiveButton.destroy(self: DiveButton)
	self.jumpCleanup:run()
	self.cleanup:run()
end

return DiveButton
