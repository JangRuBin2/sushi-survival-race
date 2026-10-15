--!strict
-- ⚙ 설정 버튼 (m5-41). Roblox 위쪽 바 줄, 음소거 버튼(Sfx SoundGui.MuteButton) 바로 왼쪽.
-- 터치 컨트롤이 보일 때만 보여요 (UserInputService.TouchEnabled이고 PlayerGui.TouchGui가 켜져 있을 때) — PC·게임패드는 없음.
-- 누르면 작은 메뉴: "버튼 위치 편집"(TouchLayoutEditor). 라운드에 배치된 동안은 회색 "라운드 중에는 편집할 수 없어요".
-- 다른 설정 항목은 아직 없어요 (메뉴 틀만).
--   SettingsButton.start(gui)   init.client.luau가 불러요

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local Loc = require(script.Parent.Parent.Loc)
local Kit = require(script.Parent.RoomUiKit)
local TouchLayoutController = require(script.Parent.Parent.input.TouchLayoutController)
local TouchLayoutEditor = require(script.Parent.TouchLayoutEditor)

local Color = Kit.Color

local SettingsButton = {}

local MARGIN = 4 -- 위쪽 바 안 위아래 여백 (음소거 버튼과 같아요)
local WIDTH = 36
local MAX_HEIGHT = 36
local GAP = 6 -- 음소거 버튼과 사이
local MENU_WIDTH = 240

local started = false

function SettingsButton.start(_gui: Instance)
	if started then
		return
	end
	started = true
	if not UserInputService.TouchEnabled then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local screen = Instance.new("ScreenGui")
	screen.Name = "SettingsGui"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets -- 음소거 버튼과 같은 위쪽 바 칸 (Sfx 참고)
	screen.Enabled = false

	local button = Kit.new("TextButton", {
		Name = "SettingsButton",
		Parent = screen,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(MARGIN + WIDTH + GAP), 0.5, 0),
		Size = UDim2.new(0, WIDTH, 1, -MARGIN * 2),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.35,
		TextColor3 = Color.White,
		Font = Kit.Font,
		TextSize = 18,
		Text = "⚙",
		AutoButtonColor = true,
	}, {
		Kit.corner(8),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(WIDTH, MAX_HEIGHT) }),
	})
	screen.Parent = playerGui

	-- 메뉴는 위쪽 바 칸 밖(아래)에 그려야 해서 전체 화면 gui에 따로 둬요
	local menuGui = Instance.new("ScreenGui")
	menuGui.Name = "SettingsMenuGui"
	menuGui.ResetOnSpawn = false
	menuGui.DisplayOrder = 55
	menuGui.ScreenInsets = Enum.ScreenInsets.None
	menuGui.Enabled = false
	local backdrop = Kit.new("TextButton", {
		Name = "Backdrop",
		Parent = menuGui,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local menu = Kit.new("Frame", {
		Name = "Menu",
		Parent = menuGui,
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(MENU_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
	}, { Kit.corner(10), Kit.padding(6), Kit.list(Enum.FillDirection.Vertical, 6) })
	local item = Kit.button(Loc.t("input.layout.menuItem"), Color.Salmon, {
		Name = "EditTouchLayout",
		Parent = menu,
		LayoutOrder = 1,
		ZIndex = 2,
		TextWrapped = true,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, math.max(44, UiLayout.MIN_TEXT_PX * 3)),
	})
	menuGui.Parent = playerGui

	local function refreshItem()
		local locked = TouchLayoutController.isLocked()
		Kit.setEnabled(item, not locked)
		item.Text = if locked then Loc.t("input.layout.menuLocked") else Loc.t("input.layout.menuItem")
		item.TextColor3 = if locked then Color.Text else Color.White
	end

	local function placeMenu()
		local at = button.AbsolutePosition - menuGui.AbsolutePosition
		local size = button.AbsoluteSize
		local x = math.max(8, at.X + size.X - MENU_WIDTH)
		menu.Position = UDim2.fromOffset(x, at.Y + size.Y + 6)
	end

	local function setMenu(open: boolean)
		if open then
			refreshItem()
			placeMenu()
		end
		menuGui.Enabled = open
	end

	Kit.onClick(button, function()
		setMenu(not menuGui.Enabled)
	end)
	Kit.onClick(backdrop, function()
		setMenu(false)
	end)
	Kit.onClick(item, function()
		setMenu(false)
		TouchLayoutEditor.open()
	end)
	TouchLayoutController.lockChanged(function()
		refreshItem()
	end)

	-- 음소거 버튼 바로 왼쪽 (음소거 버튼 폭은 화면 폭에 따라 바뀌어요)
	local muteConnections: { RBXScriptConnection } = {}
	local function placeButton()
		local soundGui = playerGui:FindFirstChild("SoundGui")
		local mute = soundGui and soundGui:FindFirstChild("MuteButton")
		if mute and mute:IsA("GuiObject") and screen.AbsoluteSize.X > 0 then
			local right = screen.AbsolutePosition.X + screen.AbsoluteSize.X
			local fromRight = right - mute.AbsolutePosition.X + GAP
			button.Position = UDim2.new(1, -fromRight, 0.5, 0)
		end
	end
	local function watchMute()
		for _, c in muteConnections do
			c:Disconnect()
		end
		table.clear(muteConnections)
		local soundGui = playerGui:FindFirstChild("SoundGui")
		local mute = soundGui and soundGui:FindFirstChild("MuteButton")
		if mute and mute:IsA("GuiObject") then
			table.insert(muteConnections, mute:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeButton))
			table.insert(muteConnections, mute:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeButton))
		end
		placeButton()
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeButton)

	-- 터치 컨트롤이 보일 때만 (터치 + 키보드 기기에서 키보드로 바꾸면 TouchGui가 꺼져요)
	local touchConnection: RBXScriptConnection? = nil
	local function refreshVisible()
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local visible = touchGui ~= nil and touchGui:IsA("ScreenGui") and touchGui.Enabled
		screen.Enabled = visible
		if not visible then
			setMenu(false)
			if TouchLayoutEditor.isOpen() then
				TouchLayoutEditor.cancel()
			end
		end
	end
	local function watchTouchGui()
		if touchConnection then
			touchConnection:Disconnect()
			touchConnection = nil
		end
		local touchGui = playerGui:FindFirstChild("TouchGui")
		if touchGui and touchGui:IsA("ScreenGui") then
			touchConnection = touchGui:GetPropertyChangedSignal("Enabled"):Connect(refreshVisible)
		end
		refreshVisible()
	end
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == "TouchGui" then
			task.defer(watchTouchGui)
		elseif child.Name == "SoundGui" then
			task.defer(watchMute)
		end
	end)
	playerGui.ChildRemoved:Connect(function(child: Instance)
		if child.Name == "TouchGui" then
			task.defer(watchTouchGui)
		end
	end)
	watchTouchGui()
	watchMute()
end

return SettingsButton
