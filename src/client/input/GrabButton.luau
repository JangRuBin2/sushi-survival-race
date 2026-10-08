--!strict
-- 모바일 "잡기" 버튼 (m3-07). 기본 점프 버튼 위쪽에 같은 크기로 둬요 (다이브 버튼은 왼쪽, m3-06).
--   GrabButton.create(onHold) -> { setActive(active), destroy() }?
--     터치 기기가 아니면 nil. 누르면 onHold(true), 손을 떼면 onHold(false).
--     기본 터치 컨트롤(PlayerGui.TouchGui.TouchControlFrame.JumpButton)이 나타날 때까지 기다렸다가 보여요.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(game:GetService("ReplicatedStorage").Shared.Attributes)

local GAP_RATIO = 0.15 -- 점프 버튼과의 간격 (버튼 높이 배수)
local IDLE_COLOR = Color3.fromRGB(255, 255, 255)
local ACTIVE_COLOR = Color3.fromRGB(255, 170, 60)

export type GrabButton = {
	setActive: (active: boolean) -> (),
	destroy: () -> (),
}

local GrabButton = {}

function GrabButton.create(onHold: (holding: boolean) -> ()): GrabButton?
	if not UserInputService.TouchEnabled then
		return nil
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local screen = Instance.new("ScreenGui")
	screen.Name = "GrabGui"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1
	screen:SetAttribute(Attributes.NoClickSfx, true) -- 조작 버튼이라 클릭음 없음 (Sfx, m3-09)

	local button = Instance.new("TextButton")
	button.Name = "GrabButton"
	button.AutoButtonColor = false
	button.Text = "잡기"
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(40, 40, 40)
	button.BackgroundColor3 = IDLE_COLOR
	button.BackgroundTransparency = 0.3
	button.Visible = false
	button.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.18, 0)
	padding.PaddingRight = UDim.new(0.18, 0)
	padding.PaddingTop = UDim.new(0.25, 0)
	padding.PaddingBottom = UDim.new(0.25, 0)
	padding.Parent = button
	screen.Parent = playerGui

	local connections: { RBXScriptConnection } = {}
	local jumpConnections: { RBXScriptConnection } = {}
	local currentTouch: InputObject? = nil
	local destroyed = false

	local function release()
		if currentTouch ~= nil then
			currentTouch = nil
			onHold(false)
		end
	end

	local function disconnectJump()
		for _, c in jumpConnections do
			c:Disconnect()
		end
		table.clear(jumpConnections)
	end

	local function place(touchGui: ScreenGui, jump: GuiObject)
		screen.IgnoreGuiInset = touchGui.IgnoreGuiInset
		screen.ScreenInsets = touchGui.ScreenInsets
		local size = jump.AbsoluteSize
		local pos = jump.AbsolutePosition
		local gap = size.Y * GAP_RATIO
		button.Size = UDim2.fromOffset(size.X, size.Y)
		button.Position = UDim2.fromOffset(pos.X, pos.Y - size.Y - gap)
		button.Visible = jump.Visible and size.X > 0
	end

	local function attach(touchGui: ScreenGui, jump: GuiObject)
		disconnectJump()
		local function update()
			place(touchGui, jump)
		end
		table.insert(jumpConnections, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
		table.insert(jumpConnections, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
		table.insert(jumpConnections, jump:GetPropertyChangedSignal("Visible"):Connect(update))
		table.insert(
			jumpConnections,
			jump.AncestryChanged:Connect(function()
				if not jump:IsDescendantOf(playerGui) then
					disconnectJump()
					button.Visible = false
					release()
				end
			end)
		)
		update()
	end

	-- 점프 버튼은 캐릭터가 생길 때 다시 만들어질 수 있어서 계속 찾아요
	task.spawn(function()
		while not destroyed do
			local touchGui = playerGui:FindFirstChild("TouchGui")
			local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if touchGui and touchGui:IsA("ScreenGui") and jump and jump:IsA("GuiObject") then
				if #jumpConnections == 0 then
					attach(touchGui, jump)
				end
			elseif #jumpConnections > 0 then
				disconnectJump()
				button.Visible = false
				release()
			end
			task.wait(1)
		end
	end)

	table.insert(
		connections,
		button.InputBegan:Connect(function(input: InputObject)
			if currentTouch ~= nil then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
				return
			end
			currentTouch = input
			onHold(true)
		end)
	)
	-- 손가락이 버튼 밖으로 나가도 떼는 순간을 놓치지 않게 UserInputService에서도 봐요
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input == currentTouch
				or (
					currentTouch
					and input.UserInputType == currentTouch.UserInputType
					and input.UserInputType == Enum.UserInputType.MouseButton1
				)
			then
				release()
			end
		end)
	)
	table.insert(
		connections,
		button.InputEnded:Connect(function(input: InputObject)
			if input == currentTouch then
				release()
			end
		end)
	)

	return {
		setActive = function(isActive: boolean)
			button.BackgroundColor3 = if isActive then ACTIVE_COLOR else IDLE_COLOR
		end,
		destroy = function()
			destroyed = true
			release()
			disconnectJump()
			for _, c in connections do
				c:Disconnect()
			end
			screen:Destroy()
		end,
	}
end

return GrabButton
