--!strict
-- 모바일 다이브 버튼 (m3-06). 터치 기기에서 기본 점프 버튼이 있을 때만 만들어요.
--   DiveButton.create(onPress) -> DiveButton?   터치 기기가 아니면 nil
--   button:setCooldown(fraction)                 0~1, 남은 쿨다운 비율 (위에서부터 줄어드는 어두운 덮개)
--   button:destroy()
-- 점프 버튼(PlayerGui.TouchGui.TouchControlFrame.JumpButton) 왼쪽에 85% 크기로 붙고(Shared.UiLayout.touchButtons, m4-09),
-- 점프 버튼 위치·크기나 화면 크기가 바뀌면 다시 맞춰요. 점프 버튼 픽셀에 맞추므로 UIScale은 붙이지 않아요.
-- 편집한 배치(m5-41)가 있으면 TouchLayoutController.current()의 자리·크기를 쓰고, 편집 중에는 숨어요.
-- 로비에서도 다이브가 되니 잡기·공격과 달리 늘 보여요 (m6-14 결정). 겉모습은 TouchButtonFace (m6-14 C2):
-- 아이콘 id(Shared.IconAssets)가 있으면 그림, 없으면 "🤸 다이브" 글씨.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(game:GetService("ReplicatedStorage").Shared.Attributes)
local Cleanup = require(game:GetService("ReplicatedStorage").Shared.Cleanup)
local UiLayout = require(game:GetService("ReplicatedStorage").Shared.UiLayout)

local Loc = require(script.Parent.Parent.Loc)
local TouchButtonFace = require(script.Parent.TouchButtonFace)
local TouchLayoutController = require(script.Parent.TouchLayoutController)

local DiveButton = {}
DiveButton.__index = DiveButton

export type DiveButton = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		button: TextButton,
		face: TouchButtonFace.Face,
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
	gui:SetAttribute(Attributes.NoClickSfx, true) -- 조작 버튼이라 클릭음 없음 (Sfx, m3-09)

	local face = TouchButtonFace.create("DiveButton", gui)
	face.setIcon("dive", Loc.t("input.dive.btn"))
	local button = face.button
	button.Visible = true -- 보일지는 gui.Enabled가 정해요

	gui.Parent = playerGui

	local self = setmetatable({
		gui = gui,
		button = button,
		face = face,
		cleanup = Cleanup.new(),
		jumpCleanup = Cleanup.new(),
	}, DiveButton)
	self.cleanup:add(gui)

	local function layout(jump: GuiObject)
		local size = jump.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local position: UDim2, buttonSize: UDim2
		local custom = TouchLayoutController.current()
		if custom then
			-- 편집한 배치 (전체 화면 좌표 → 우리 ScreenGui 좌표)
			position, buttonSize = TouchLayoutController.place(gui, custom.dive)
		else
			-- 점프 버튼의 화면 좌표를 우리 ScreenGui 좌표로 바꿔요 (GUI 인셋 차이 흡수)
			local origin = jump.AbsolutePosition - gui.AbsolutePosition
			local screenSize = gui.AbsoluteSize
			local rect = UiLayout.touchButtons(screenSize.X, screenSize.Y, {
				x = origin.X,
				y = origin.Y,
				size = math.min(size.X, size.Y),
			}).dive
			position = UDim2.fromOffset(rect.x, rect.y)
			buttonSize = UDim2.fromOffset(rect.size, rect.size)
		end
		button.Position = position
		button.Size = buttonSize
		-- 편집 중에는 점프 버튼도 숨어 있지만, 따로도 꺼 둬요 (입력이 안 나가게)
		gui.Enabled = jump.Visible and not TouchLayoutController.isEditing()
	end

	local currentJump: GuiObject? = nil

	local function attach(jump: GuiObject)
		self.jumpCleanup:run()
		currentJump = jump
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
				currentJump = nil
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
	-- 배치를 저장·편집하면 다시 맞춰요 (m5-41)
	self.cleanup:add(TouchLayoutController.changed(function()
		local jump = currentJump
		if jump then
			layout(jump)
		end
	end))

	self.cleanup:add(button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if not TouchLayoutController.isEditing() then
				onPress()
			end
		end
	end))

	return self
end

function DiveButton.setCooldown(self: DiveButton, fraction: number)
	self.face.setCooldown(fraction, nil)
end

function DiveButton.destroy(self: DiveButton)
	self.jumpCleanup:run()
	self.cleanup:run()
end

return DiveButton
