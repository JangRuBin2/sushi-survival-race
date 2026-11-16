--!strict
-- 모바일 "공격" 버튼 (m6-08). 기본 자리는 다이브 위·잡기 왼쪽 대각선 (Shared.UiLayout.touchButtons의 attack).
-- 편집한 배치(m5-41)가 있으면 TouchLayoutController.current()의 attack을 쓰고, 편집 중에는 숨어요.
-- 출발한 라운드에서 아직 달리는 내 레이서일 때만 보여요 (m6-14 C1, RaceActionState) — 로비·대기실·관전·부활 대기 중에는 숨어요.
-- 겉모습은 TouchButtonFace (m6-14 C2): 아이콘 id(Shared.IconAssets)가 있으면 그림, 없으면 "💥 공격" 글씨.
--   AttackButton.create(onPress) -> { setCooldown(seconds?, fraction?), setDynamite(on), destroy() }?
--     setDynamite(true)면 다이너마이트를 들고 있어 🧨 점화 아이콘(쿨다운 표시보다 먼저, m6-12)
--     터치 기기가 아니면 nil. 누르는 순간 onPress() 한 번 (누르고 있기 아님).
--     setCooldown(n, f)이면 어두운 덮개(f = 남은 비율, 없으면 가득) + 남은 초, nil이면 원래 모습.
--     기본 터치 컨트롤(PlayerGui.TouchGui.TouchControlFrame.JumpButton)이 나타날 때까지 기다렸다가 보여요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local IconAssets = require(ReplicatedStorage.Shared.IconAssets)
local RaceActionLogic = require(ReplicatedStorage.Shared.RaceActionLogic)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local Loc = require(script.Parent.Parent.Loc)
local RaceActionState = require(script.Parent.RaceActionState)
local TouchButtonFace = require(script.Parent.TouchButtonFace)
local TouchLayoutController = require(script.Parent.TouchLayoutController)

export type AttackButton = {
	setCooldown: (seconds: number?, fraction: number?) -> (),
	setDynamite: (on: boolean) -> (),
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
	local face = TouchButtonFace.create("AttackButton", screen)
	local button = face.button
	screen.Parent = playerGui

	local connections: { RBXScriptConnection } = {}
	local jumpConnections: { RBXScriptConnection } = {}
	local destroyed = false
	local shownCooldown: number? = nil
	local shownFraction: number? = nil
	local dynamite = false
	local placementOk = false -- 점프 버튼에 맞춰 자리를 잡을 수 있음 (보이고 크기 있음, 편집 중 아님)
	local function refresh()
		if dynamite then
			face.setIcon(IconAssets.attackIcon(true), Loc.t("input.dynamite.btn"))
			face.setTone("Armed")
			face.setCooldown(0, nil)
		else
			face.setIcon(IconAssets.attackIcon(false), readyText)
			face.setTone("Idle")
			local seconds = shownCooldown
			if seconds == nil then
				face.setCooldown(0, nil)
			else
				face.setCooldown(shownFraction or 1, Loc.t("input.attack.cooldown", { seconds = seconds }))
			end
		end
	end
	refresh()

	local function applyVisible()
		button.Visible = RaceActionLogic.buttonVisible(placementOk, RaceActionState.get())
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
		placementOk = jump.Visible and size.X > 0 and not TouchLayoutController.isEditing()
		applyVisible()
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
					placementOk = false
					applyVisible()
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
				placementOk = false
				applyVisible()
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

	-- 달리는 중이 되거나 끝나면 (m6-14 C1)
	local stopRaceWatch = RaceActionState.changed(applyVisible)

	table.insert(
		connections,
		button.InputBegan:Connect(function(input: InputObject)
			if TouchLayoutController.isEditing() or not button.Visible then
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
		setCooldown = function(seconds: number?, fraction: number?)
			if seconds == shownCooldown and fraction == shownFraction then
				return
			end
			shownCooldown = seconds
			shownFraction = fraction
			refresh()
		end,
		setDynamite = function(on: boolean)
			if on == dynamite then
				return
			end
			dynamite = on
			refresh()
		end,
		destroy = function()
			destroyed = true
			stopLayoutWatch()
			stopRaceWatch()
			disconnectJump()
			for _, c in connections do
				c:Disconnect()
			end
			screen:Destroy()
		end,
	}
end

return AttackButton
