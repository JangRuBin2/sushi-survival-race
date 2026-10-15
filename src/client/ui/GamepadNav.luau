--!strict
-- 게임패드(콘솔) UI 내비게이션 공통 도우미 (m5-12, GDD 1·6·10). 클라이언트 UI만 — 판정·권한과 무관해요.
--   언제: 마지막 입력이 게임패드(Gamepad1~8)일 때만 (PC에 꽂은 패드도 같음). 마우스·터치·키보드를 쓰면 선택 테두리와
--         패드 힌트를 지우고 지금 그대로예요. 판단은 Shared.GamepadNavLogic(순수).
--   화면 등록 (화면 모듈이 만들 때 한 번):
--     GamepadNav.window(options)  닫을 수 있는 창 (탈의실·상점·코드·관리자·방 만들기·뽑기…). 보이면 열린 것으로 보고
--                                 첫 버튼을 자동 선택, 선택이 창 밖으로 못 나가게 SelectionGroup + Stop, B = close.
--                                 닫히면 그 창을 연 버튼으로 선택을 돌려놓아요 (없으면 아래 창의 첫 버튼, 그것도 없으면 해제).
--     GamepadNav.page(options)    닫지 않는 기본 화면 (로비·방 대기실). 자동 선택 없음 — 아무것도 선택 안 됐을 때
--                                 방향키·Select(뷰) 한 번으로 첫 버튼. 울타리 없음 (왼쪽 위 "🍣 스킨" 등으로 갈 수 있게).
--     GamepadNav.anchor(button)   창·화면이 없을 때 Select로 고를 버튼 (관전 중 "🍣 스킨" 등)
--   상태: GamepadNav.isGamepad(), onModeChanged(fn), isWindowOpen(), isLocked()
--   잠금: 라운드 소개·달리는 중·시작 카운트다운·우승 연출(GamepadNavLogic.navAllowed)에는 선택을 지우고
--         GuiService.GuiNavigationEnabled = false → A·B·X·R2는 게임 조작(점프·다이브·잡기)으로만 가요.
--   버튼: B = 맨 위 창 하나 닫기(기본 화면에서는 창을 닫지 않고 선택만 끄기 — 캐릭터를 움직일 수 있게),
--         LB/RB = 창의 탭(options.tabs), Select = 선택 켜기/끄기, 방향키 = 아무것도 선택 안 됐을 때 첫 버튼.
--   힌트: 화면 아래 가운데 한 줄 ("Ⓐ 선택 · Ⓑ 닫기" 등, 게임패드 모드일 때만). 관전 힌트는 SpectateScreen이 직접.
--   선택 테두리: RoomUiKit.selectionImage (굵은 흰 테두리)를 PlayerGui.SelectionImageObject로.
--   선택한 칸이 스크롤 목록 밖이면 목록을 굴려 보여 줘요 (GamepadNavLogic.scrollToShow).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GamepadNavLogic = require(ReplicatedStorage.Shared.GamepadNavLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Loc = require(script.Parent.Parent.Loc)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

local GamepadNav = {}

export type Options = {
	root: GuiBase2d, -- GuiObject(Visible) 또는 ScreenGui(Enabled). 조상까지 모두 보이면 열린 것
	group: GuiBase2d?, -- 선택 울타리 (기본: root)
	close: (() -> ())?, -- B (window만)
	first: (() -> GuiObject?)?, -- 처음 고를 버튼 (없거나 nil이면 울타리 안 맨 위·맨 왼쪽 버튼)
	tabs: ((dir: number) -> ())?, -- LB(-1)/RB(+1)
	hasTabs: (() -> boolean)?, -- 지금 탭이 보이는지 (힌트용, 없으면 tabs가 있으면 true)
}

type Entry = {
	id: string,
	page: boolean,
	root: GuiBase2d,
	group: GuiBase2d,
	close: (() -> ())?,
	first: (() -> GuiObject?)?,
	tabs: ((dir: number) -> ())?,
	hasTabs: (() -> boolean)?,
	opener: GuiObject?,
	lastPath: { string }?,
}

local entries: { Entry } = {}
local byId = {} :: { [string]: Entry } -- 등록한 화면 수만큼 (고정, 지우지 않아요)
local order: { string } = {} -- 창(window)만, 등록 순서
local anchors: { GuiObject } = {}
local stack: { string } = {} -- 열린 창 id (열린 순서)
local nextId = 0

local gamepad = false
local locked = false
local started = false
local modeListeners: { (boolean) -> () } = {}
local previousSelected: GuiObject? = nil
local hintLabel: TextLabel? = nil

local SELECTABLE_CLASSES = { "GuiButton", "TextBox" }

------------------------------------------------------------------ 도우미

local function playerGui(): Instance?
	local player = Players.LocalPlayer
	return if player then player:FindFirstChildOfClass("PlayerGui") else nil
end

-- 자기와 조상(PlayerGui까지)이 모두 보이는가
local function isShown(instance: Instance?): boolean
	local gui = playerGui()
	if instance == nil or gui == nil or not instance:IsDescendantOf(gui) then
		return false
	end
	local current: Instance? = instance
	while current ~= nil and current ~= gui do
		if current:IsA("GuiObject") then
			if not current.Visible then
				return false
			end
		elseif current:IsA("LayerCollector") then
			if not current.Enabled then
				return false
			end
		end
		current = current.Parent
	end
	return true
end

local function isSelectableClass(instance: Instance): boolean
	for _, className in SELECTABLE_CLASSES do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

local function canSelect(object: GuiObject?): boolean
	return object ~= nil and object.Selectable and isShown(object)
end

local function inside(object: Instance?, container: Instance): boolean
	return object ~= nil and (object == container or object:IsDescendantOf(container))
end

-- 울타리 안에서 보이는 버튼·글자 칸 중 맨 위·맨 왼쪽
local function firstIn(container: Instance): GuiObject?
	local candidates: { GuiObject } = {}
	local points: { GamepadNavLogic.Point } = {}
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("GuiObject") and isSelectableClass(descendant) and canSelect(descendant) then
			table.insert(candidates, descendant)
			table.insert(points, { x = descendant.AbsolutePosition.X, y = descendant.AbsolutePosition.Y })
		end
	end
	local index = GamepadNavLogic.pickFirst(points)
	return if index then candidates[index] else nil
end

local function firstOf(entry: Entry): GuiObject?
	local chooser = entry.first
	if chooser then
		local ok, chosen = pcall(chooser)
		if ok and chosen ~= nil and canSelect(chosen) then
			return chosen
		end
	end
	return firstIn(entry.group)
end

local function pathOf(object: Instance, container: Instance): { string }?
	local path: { string } = {}
	local current: Instance? = object
	while current ~= nil and current ~= container do
		table.insert(path, 1, current.Name)
		current = current.Parent
	end
	return if current == container then path else nil
end

local function findPath(container: Instance, path: { string }): GuiObject?
	local current: Instance? = container
	for _, name in path do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current ~= nil and current:IsA("GuiObject") then current else nil
end

-- 장식 스크롤 틀은 선택되지 않게 (스크롤은 선택을 따라 우리가 굴려요)
local function sanitize(container: Instance)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("ScrollingFrame") then
			descendant.Selectable = false
		end
	end
	if container:IsA("GuiObject") and not isSelectableClass(container) then
		container.Selectable = false
	end
end

local function setSelection(object: GuiObject?)
	if GuiService.SelectedObject ~= object then
		GuiService.SelectedObject = object
	end
end

local function topWindow(): Entry?
	local id = stack[#stack]
	return if id then byId[id] else nil
end

local function topPage(): Entry?
	for _, entry in entries do
		if entry.page and isShown(entry.root) then
			return entry
		end
	end
	return nil
end

------------------------------------------------------------------ 힌트 한 줄

local function hintText(): string?
	if not gamepad or locked then
		return nil
	end
	local top = topWindow()
	if top then
		local hasTabs = top.tabs ~= nil and (top.hasTabs == nil or (top.hasTabs :: () -> boolean)())
		return if hasTabs then Loc.t("gamepad.hint.withTabs") else Loc.t("gamepad.hint.window")
	end
	if topPage() then
		return if GuiService.SelectedObject ~= nil then Loc.t("gamepad.hint.page") else Loc.t("gamepad.hint.pageIdle")
	end
	return nil
end

local function refreshHint()
	local label = hintLabel
	if label == nil then
		return
	end
	local text = hintText()
	label.Visible = text ~= nil
	if text and label.Text ~= text then
		label.Text = text
	end
end

local function buildHint(gui: Instance)
	local screen = Kit.new("ScreenGui", {
		Name = "GamepadHintGui",
		ResetOnSpawn = false,
		DisplayOrder = 60, -- 창들(15~22)·코인 토스트(55) 위
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gui,
	}) :: ScreenGui
	hintLabel = Kit.label({
		Name = "Hint",
		Parent = screen,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Kit.Color.Backdrop,
		BackgroundTransparency = 0.2,
		TextColor3 = Kit.Color.White,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = "",
		Visible = false,
	})
	local label = hintLabel :: TextLabel
	Kit.corner(14).Parent = label
	Kit.new("UIPadding", {
		Parent = label,
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	})
	UiScaleController.attach(screen)
end

------------------------------------------------------------------ 스크롤 따라가기

local function scaleAbove(instance: Instance): number
	local scale = 1
	local current: Instance? = instance
	while current ~= nil do
		local uiScale = current:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		if current:IsA("LayerCollector") then
			break
		end
		current = current.Parent
	end
	return if scale > 0 then scale else 1
end

local function scrollIntoView(object: GuiObject)
	local current: Instance? = object.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("ScrollingFrame") then
			local frame = current
			local scale = scaleAbove(frame)
			local canvasY = frame.CanvasPosition.Y
			local itemTop = (object.AbsolutePosition.Y - frame.AbsolutePosition.Y) / scale + canvasY
			local y = GamepadNavLogic.scrollToShow(
				canvasY,
				frame.AbsoluteWindowSize.Y / scale,
				itemTop,
				object.AbsoluteSize.Y / scale,
				frame.AbsoluteCanvasSize.Y / scale
			)
			if math.abs(y - canvasY) > 0.5 then
				frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, y)
			end
			return
		end
		current = current.Parent
	end
end

------------------------------------------------------------------ 한 프레임

local function step()
	if not gamepad then
		return
	end
	-- 열린 창 맞추기
	local open: { [string]: boolean } = {}
	for _, entry in entries do
		if not entry.page then
			open[entry.id] = isShown(entry.root)
		end
	end
	local previousTop = topWindow()
	local newStack, opened, closed = GamepadNavLogic.reconcile(stack, open, order)
	stack = newStack
	local selected = GuiService.SelectedObject

	for _, id in opened do
		local entry = byId[id]
		entry.opener = if selected ~= nil and not inside(selected, entry.group) then selected else nil
		entry.lastPath = nil
		sanitize(entry.root)
		if entry.root ~= entry.group then
			sanitize(entry.group)
		end
	end
	if locked then
		previousSelected = selected
		refreshHint()
		return
	end
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local top = topWindow()

	if #closed > 0 and previousTop ~= nil and previousTop ~= top and table.find(closed, previousTop.id) then
		-- 맨 위 창이 닫혔어요: 연 버튼으로 돌아가요
		local opener = previousTop.opener
		previousTop.opener = nil
		if opener ~= nil and canSelect(opener) and (top == nil or inside(opener, top.group)) then
			setSelection(opener)
		elseif top ~= nil then
			setSelection(firstOf(top))
		else
			setSelection(nil)
		end
		selected = GuiService.SelectedObject
	elseif #opened > 0 and top ~= nil and table.find(opened, top.id) then
		setSelection(firstOf(top))
		selected = GuiService.SelectedObject
	end

	if top ~= nil and not typing then
		-- 창이 열려 있으면 선택은 늘 그 창 안에 (다시 그려서 버튼이 바뀌었으면 같은 이름 자리 → 첫 버튼)
		if selected == nil or not inside(selected, top.group) or not canSelect(selected) then
			local again: GuiObject? = nil
			local path = top.lastPath
			if path then
				local found = findPath(top.group, path)
				if found and canSelect(found) then
					again = found
				end
			end
			setSelection(again or firstOf(top))
			selected = GuiService.SelectedObject
		end
		if selected ~= nil then
			top.lastPath = pathOf(selected, top.group)
		end
	elseif top == nil and not typing then
		-- 기본 화면: 선택한 버튼이 다시 그려져 사라졌으면(방 목록 갱신) 같은 자리 → 첫 버튼
		local page = topPage()
		local lost = previousSelected
		if page ~= nil and selected == nil and lost ~= nil and inside(lost, page.group) and not canSelect(lost) then
			local path = page.lastPath
			local found = if path then findPath(page.group, path) else nil
			setSelection(if found and canSelect(found) then found else firstOf(page))
			selected = GuiService.SelectedObject
		end
		if page ~= nil and selected ~= nil and inside(selected, page.group) then
			page.lastPath = pathOf(selected, page.group)
		end
	end
	previousSelected = selected
	refreshHint()
end

------------------------------------------------------------------ 입력

local function closeTop(): boolean
	local top = topWindow()
	if top == nil or top.close == nil then
		return false
	end
	local close = top.close :: () -> ()
	task.spawn(close)
	return true
end

local function selectFirstAvailable(includeAnchors: boolean)
	local top = topWindow()
	if top then
		setSelection(firstOf(top))
		return
	end
	local page = topPage()
	if page then
		setSelection(firstOf(page))
		return
	end
	if includeAnchors then
		local shown: { GuiObject } = {}
		local points: { GamepadNavLogic.Point } = {}
		for _, button in anchors do
			if canSelect(button) then
				table.insert(shown, button)
				table.insert(points, { x = button.AbsolutePosition.X, y = button.AbsolutePosition.Y })
			end
		end
		local index = GamepadNavLogic.pickFirst(points)
		if index then
			setSelection(shown[index])
		end
	end
end

local DPAD = {
	[Enum.KeyCode.DPadUp] = true,
	[Enum.KeyCode.DPadDown] = true,
	[Enum.KeyCode.DPadLeft] = true,
	[Enum.KeyCode.DPadRight] = true,
}

local function onInput(input: InputObject)
	if not gamepad or locked then
		return
	end
	if not GamepadNavLogic.isGamepadInput(input.UserInputType.Name) then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return -- 화면 키보드로 글자를 넣는 중
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.ButtonB then
		if not closeTop() and GuiService.SelectedObject ~= nil then
			-- 기본 화면(로비·대기실·관전 중 왼쪽 위 버튼): 창은 없고 선택만 꺼요 → 스틱으로 캐릭터를 움직여요
			setSelection(nil)
		end
	elseif key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.ButtonR1 then
		local top = topWindow()
		if top and top.tabs then
			local tabs = top.tabs :: (number) -> ()
			task.spawn(tabs, if key == Enum.KeyCode.ButtonL1 then -1 else 1)
		end
	elseif key == Enum.KeyCode.ButtonSelect then
		if GuiService.SelectedObject == nil then
			selectFirstAvailable(true)
		elseif topWindow() == nil then
			setSelection(nil)
		end
	elseif DPAD[key] then
		if GuiService.SelectedObject == nil then
			selectFirstAvailable(false)
		end
	end
	refreshHint()
end

------------------------------------------------------------------ 모드 · 잠금

local function setMode(value: boolean)
	if value == gamepad then
		return
	end
	gamepad = value
	if not value then
		-- 마우스·터치·키보드: 선택 테두리를 지우고 지금 그대로
		if GuiService.SelectedObject ~= nil then
			setSelection(nil)
		end
		stack = {}
	end
	previousSelected = nil
	refreshHint()
	for _, listener in table.clone(modeListeners) do
		task.spawn(listener, value)
	end
end

local function setLocked(value: boolean)
	if value == locked then
		return
	end
	locked = value
	GuiService.GuiNavigationEnabled = not value
	if value then
		if GuiService.SelectedObject ~= nil then
			setSelection(nil)
		end
		if gamepad then
			-- 라운드 소개·달리는 중에는 창도 닫아요 (탈의실·뽑기는 각 컨트롤러도 닫아요)
			for i = #stack, 1, -1 do
				local entry = byId[stack[i]]
				if entry and entry.close then
					task.spawn(entry.close :: () -> ())
				end
			end
		end
	end
	refreshHint()
end

------------------------------------------------------------------ 공개 함수

local function register(options: Options, page: boolean)
	nextId += 1
	local id = `nav{nextId}`
	local group = options.group or options.root
	local entry: Entry = {
		id = id,
		page = page,
		root = options.root,
		group = group,
		close = options.close,
		first = options.first,
		tabs = options.tabs,
		hasTabs = options.hasTabs,
		opener = nil,
		lastPath = nil,
	}
	if not page then
		-- 선택이 창 밖으로 못 나가게 (방향키가 끝에서 멈춰요)
		group.SelectionGroup = true
		group.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
		group.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
		group.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
		group.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
		table.insert(order, id)
	end
	sanitize(options.root)
	table.insert(entries, entry)
	byId[id] = entry
end

function GamepadNav.window(options: Options)
	register(options, false)
end

function GamepadNav.page(options: Options)
	register(options, true)
end

function GamepadNav.anchor(button: GuiObject)
	table.insert(anchors, button)
end

function GamepadNav.isGamepad(): boolean
	return gamepad
end

function GamepadNav.isLocked(): boolean
	return locked
end

-- 게임패드 모드에서 닫을 수 있는 창이 열려 있는가 (관전 Y·LB/RB가 창 뒤로 새지 않게)
function GamepadNav.isWindowOpen(): boolean
	return gamepad and topWindow() ~= nil
end

function GamepadNav.onModeChanged(listener: (boolean) -> ())
	table.insert(modeListeners, listener)
end

function GamepadNav.start(_gui: Instance)
	if started then
		return
	end
	started = true
	local gui = playerGui() or Players.LocalPlayer:WaitForChild("PlayerGui")
	if gui:IsA("PlayerGui") then
		gui.SelectionImageObject = Kit.selectionImage()
	end
	-- Select 버튼은 우리가 처리해요 (Roblox 자동 선택이 기본 화면 밖 버튼을 고르지 않게)
	GuiService.AutoSelectGuiEnabled = false
	buildHint(gui)

	setMode(GamepadNavLogic.modeFor(false, UserInputService:GetLastInputType().Name, false))
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		setMode(GamepadNavLogic.modeFor(gamepad, inputType.Name, typing))
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
		-- B·LB·RB·Select·방향키는 선택 모드에서 Roblox가 처리했다고 표시될 수 있어 gameProcessed를 보지 않아요
		onInput(input)
	end)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local selected = GuiService.SelectedObject
		if selected ~= nil and gamepad then
			scrollIntoView(selected)
		end
		refreshHint()
	end)
	RunService.Heartbeat:Connect(step)

	-- 잠금: 탈의실을 열 수 있는 때와 같은 기준 (ShopController 참고)
	local me = Players.LocalPlayer
	local state: GamepadNavLogic.NavState = { inMatch = false, phase = nil, alive = true, passed = false }
	local function refreshLock()
		setLocked(not GamepadNavLogic.navAllowed(state))
	end
	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		local inMatch = room ~= nil and room.state == "InMatch"
		if not inMatch or not state.inMatch then
			state.phase = nil
			state.alive = true
			state.passed = false
		end
		state.inMatch = inMatch
		refreshLock()
	end)
	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if type(info) ~= "table" then
			return
		end
		state.phase = info.phase
		if info.phase == "Starting" then
			state.alive = true
			state.passed = false
		elseif info.phase == "RoundIntro" then
			state.passed = false
		end
		local ids = info.aliveUserIds
		if ids then
			state.alive = table.find(ids, me.UserId) ~= nil
		end
		refreshLock()
	end)
	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if type(result) ~= "table" or result.userId ~= me.UserId then
			return
		end
		if result.result == "Eliminated" then
			state.alive = false
		elseif result.result == "Passed" then
			state.passed = true
		end
		refreshLock()
	end)
	refreshHint()
end

return GamepadNav
