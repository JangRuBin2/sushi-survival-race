--!strict
-- 모바일 "공격" 버튼 (m6-08). 기본 자리는 다이브 위·잡기 왼쪽 대각선 (Shared.UiLayout.touchButtons의 attack).
-- 편집한 배치(m5-41)가 있으면 TouchLayoutController.current()의 attack을 쓰고, 편집 중에는 숨어요.
--   AttackButton.create(onPress) -> { setCooldown(seconds?), destroy() }?
--     터치 기기가 아니면 nil. 누르는 순간 onPress() 한 번 (누르고 있기 아님).
--     setCooldown(n)이면 버튼에 남은 초를 쓰고 흐리게, nil이면 원래 글씨.
--     기본 터치 컨트롤(PlayerGui.TouchGui.TouchControlFrame.JumpButton)이 나타날 때까지 기다렸다가 보여요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local Loc = require(script.Parent.Parent.Loc)
local TouchLayoutController = require(script.Parent.TouchLayoutController)

local READY_COLOR = Color3.fromRGB(255, 196, 120)
local COOLDOWN_COLOR = Color3.fromRGB(120, 120, 120)

export type AttackButton = {
	setCooldown: (seconds: number?) -> (),
	destroy: () -> (),
}

local AttackButton = {}

function AttackButton.create(onPress: () -> ()): AttackButton?
	if not UserInputService.TouchEnabled then
		return nil
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local screen = Instance.new("ScreenGui")
	screen.Name = "AttackGui"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1
	screen:SetAttribute(Attributes.NoClickSfx, true) -- 조작 버튼이라 클릭음 없음

	local readyText = Loc.t("input.attack.btn")
	local button = Instance.new("TextButton")
	button.Name = "AttackButton"
	button.AutoButtonColor = false
	button.AutoLocalize = false -- m5-26
	button.Text = readyText
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(40, 40, 40)
	button.BackgroundColor3 = READY_COLOR
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
	local destroyed = false
	local shownCooldown: number? = nil

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
		local custom = TouchLayoutController.current()
		if custom then
			local position, buttonSize = TouchLayoutController.place(screen, custom.attack)
			button.Size = buttonSize
			button.Position = position
		else
			local origin = jump.AbsolutePosition - screen.AbsolutePosition
			local screenSize = screen.AbsoluteSize
			local rect = UiLayout.touchButtons(screenSize.X, screenSize.Y, {
				x = origin.X,
				y = origin.Y,
				size = math.min(size.X, size.Y),
			}).attack
			button.Size = UDim2.fromOffset(rect.size, rect.size)
			button.Position = UDim2.fromOffset(rect.x, rect.y)
		end
		button.Visible = jump.Visible and size.X > 0 and not TouchLayoutController.isEditing()
	end

	local placed: { touchGui: ScreenGui, jump: GuiObject }? = nil

	local function attach(touchGui: ScreenGui, jump: GuiObject)
		disconnectJump()
		placed = { touchGui = touchGui, jump = jump }
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
				end
			end)
		)
		update()
	end

	-- 점프 버튼은 캐릭터가 생길 때 다시 만들어질 수 있어서 계속 찾아요 (GrabButton과 같은 방식)
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
			end
			task.wait(1)
		end
	end)

	local stopLayoutWatch = TouchLayoutController.changed(function()
		local at = placed
		if at and #jumpConnections > 0 then
			place(at.touchGui, at.jump)
		end
	end)

	table.insert(
		connections,
		button.InputBegan:Connect(function(input: InputObject)
			if TouchLayoutController.isEditing() then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
				return
			end
			onPress()
		end)
	)

	return {
		setCooldown = function(seconds: number?)
			if seconds == shownCooldown then
				return
			end
			shownCooldown = seconds
			if seconds == nil then
				button.Text = readyText
				button.BackgroundColor3 = READY_COLOR
			else
				button.Text = Loc.t("input.attack.cooldown", { seconds = seconds })
				button.BackgroundColor3 = COOLDOWN_COLOR
			end
		end,
		destroy = function()
			destroyed = true
			stopLayoutWatch()
			disconnectJump()
			for _, c in connections do
				c:Disconnect()
			end
			screen:Destroy()
		end,
	}
end

return AttackButton
