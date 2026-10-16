--!strict
-- 터치 버튼 배치 (m5-41). 저장된 배치(ProfileStore settings.touchLayout)를 지금 화면에 맞춰 들고 있고,
-- Roblox 기본 점프 버튼을 그 자리로 옮기고, 편집 중에는 진짜 버튼을 숨겨요. 계산은 Shared.TouchLayoutLogic(순수).
--   TouchLayoutController.current() -> TouchButtons?    편집한 배치 (전체 화면 픽셀). nil = 기본 배치(지금과 같은 경로)
--   TouchLayoutController.changed(fn) -> () -> ()       배치·편집 상태가 바뀔 때. 돌려준 함수로 끊어요
--   TouchLayoutController.isEditing() / setEditing(on)
--   TouchLayoutController.screen() -> Screen?            지금 화면 (전체·안전 영역·위쪽 바)
--   TouchLayoutController.place(gui, rect) -> (UDim2, UDim2)   전체 화면 rect를 gui 안 Offset으로
--   TouchLayoutController.defaultButtons() -> TouchButtons      지금 기본 배치 (점프 실제 위치 기준, 편집 화면 시작값)
--   TouchLayoutController.save(bucket, layout?)          저장 (nil = 기본으로). 바로 적용하고 1초 간격으로 보내요
--   TouchLayoutController.isLocked() / lockChanged(fn)   라운드에 배치된 동안 편집 잠금
-- 점프 버튼: 기본 배치면 손대지 않아요. 편집한 배치면 Position·Size를 바꾸고, PlayerModule이 되돌리면 그때마다
-- 다시 적용해요 (같은 프레임 반복 방지). 기본으로 돌아가면 PlayerModule이 마지막으로 쓴 값으로 되돌려요.
-- 좌표: 모든 rect는 ScreenInsets = None인 기준 gui(왼쪽 위 = 화면 왼쪽 위)의 좌표예요. 다른 gui 안에 둘 때는
-- AbsolutePosition 차이로 바꿔요 (위쪽 바 인셋·안전 영역 차이 흡수).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TouchLayoutLogic = require(ReplicatedStorage.Shared.TouchLayoutLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local ProfileStore = require(script.Parent.Parent.ProfileStore)

local TouchLayoutController = {}

local SEND_GAP = 1 -- 보내는 간격 최소값 (연타는 마지막만, 서버 SettingsMinInterval보다 넉넉히)
local PENDING_HOLD = 6 -- 보낸 값이 프로필로 돌아올 때까지 이 시간(초)은 내 값을 믿어요

type Listener = () -> ()

local started = false
local listeners: { [number]: Listener } = {}
local lockListeners: { [number]: (locked: boolean) -> () } = {}
local nextId = 0

local refGui: ScreenGui? = nil -- ScreenInsets None (전체 화면)
local safeGui: ScreenGui? = nil -- ScreenInsets DeviceSafeInsets (노치 뺀 칸)
local currentScreen: TouchLayoutLogic.Screen? = nil
local saved: { [string]: Types.TouchLayout } = {} -- 묶음 → 저장된 배치 (서버 값 + 보낸 값)
-- 묶음 → 보냈거나 보낼 값 (token = 마지막 저장 번호, 연타는 마지막만 보내요)
local pending: { [string]: { layout: Types.TouchLayout?, at: number, token: number } } = {}
local current: UiLayout.TouchButtons? = nil
local editing = false
local locked = false

local function notify()
	for _, fn in table.clone(listeners) do
		task.spawn(fn)
	end
end

function TouchLayoutController.changed(fn: Listener): () -> ()
	nextId += 1
	local id = nextId
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

function TouchLayoutController.lockChanged(fn: (locked: boolean) -> ()): () -> ()
	nextId += 1
	local id = nextId
	lockListeners[id] = fn
	return function()
		lockListeners[id] = nil
	end
end

function TouchLayoutController.current(): UiLayout.TouchButtons?
	if editing then
		return nil -- 편집 중에는 진짜 버튼이 숨어 있어요 (관전 화살표 등은 기본 자리)
	end
	return current
end

function TouchLayoutController.isEditing(): boolean
	return editing
end

function TouchLayoutController.isLocked(): boolean
	return locked
end

function TouchLayoutController.screen(): TouchLayoutLogic.Screen?
	return currentScreen
end

local function origin(): Vector2
	return if refGui then refGui.AbsolutePosition else Vector2.zero
end

-- 전체 화면 rect → gui 안 Offset (위치, 크기)
function TouchLayoutController.place(gui: GuiBase2d, rect: UiLayout.Rect): (UDim2, UDim2)
	local offset = gui.AbsolutePosition - origin()
	return UDim2.fromOffset(math.floor(rect.x - offset.X + 0.5), math.floor(rect.y - offset.Y + 0.5)),
		UDim2.fromOffset(rect.size, rect.size)
end

-- 화면 재기 ----------------------------------------------------------------

local function measure(): TouchLayoutLogic.Screen?
	local ref, safe = refGui, safeGui
	if ref == nil or safe == nil then
		return nil
	end
	local size = ref.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local o = ref.AbsolutePosition
	local sp = safe.AbsolutePosition - o
	local ss = safe.AbsoluteSize
	local inset = GuiService:GetGuiInset()
	return TouchLayoutLogic.screen(size.X, size.Y, {
		left = math.max(0, sp.X),
		top = math.max(0, sp.Y),
		right = math.max(0, size.X - (sp.X + ss.X)),
		bottom = math.max(0, size.Y - (sp.Y + ss.Y)),
	}, math.max(0, inset.Y))
end

-- 점프 버튼 ------------------------------------------------------------------

local function findJumpButton(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") then
		return jump
	end
	return nil
end

type JumpState = {
	button: GuiObject,
	connections: { RBXScriptConnection },
	native: { position: UDim2, size: UDim2, visible: boolean }, -- PlayerModule이 마지막으로 쓴 값
	applying: boolean,
	queued: boolean,
	desired: { position: UDim2, size: UDim2 }?, -- 우리가 마지막으로 쓴 값 (신호가 늦게 와도 우리 값은 기억하지 않게)
	moved: boolean, -- 우리가 Position·Size를 바꿔 둔 상태
	hidden: boolean, -- 편집 중 우리가 숨긴 상태
}

local jumpState: JumpState? = nil

-- 지금 기본 배치 (점프 실제 위치 기준 — 지금 DiveButton·GrabButton과 같은 계산), 못 찾으면 UiLayout 기본
function TouchLayoutController.defaultButtons(): UiLayout.TouchButtons
	local s = currentScreen
	local w = if s then s.width else 0
	local h = if s then s.height else 0
	local state = jumpState
	if state and not state.moved then
		local jump = state.button
		local size = jump.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local at = jump.AbsolutePosition - origin()
			return UiLayout.touchButtons(w, h, { x = at.X, y = at.Y, size = math.min(size.X, size.Y) })
		end
	end
	return UiLayout.touchButtons(w, h)
end

local function applyJump()
	local state = jumpState
	if state == nil then
		return
	end
	local button = state.button
	state.applying = true
	local rect = current
	if rect ~= nil then
		local parent = button.Parent
		if parent and parent:IsA("GuiBase2d") then
			local jump = rect.jump
			local position, size = TouchLayoutController.place(parent, jump)
			-- AnchorPoint가 있어도 왼쪽 위가 rect에 오게
			local anchor = button.AnchorPoint
			position = position + UDim2.fromOffset(anchor.X * jump.size, anchor.Y * jump.size)
			if button.Position ~= position then
				button.Position = position
			end
			if button.Size ~= size then
				button.Size = size
			end
			state.desired = { position = position, size = size }
			state.moved = true
		end
	elseif state.moved then
		state.moved = false
		state.desired = nil
		button.Position = state.native.position
		button.Size = state.native.size
	end
	if editing then
		if button.Visible then
			button.Visible = false
		end
		state.hidden = true
	elseif state.hidden then
		button.Visible = state.native.visible
		state.hidden = false
	end
	state.applying = false
end

local function queueJump()
	local state = jumpState
	if state == nil or state.queued then
		return
	end
	state.queued = true
	task.defer(function()
		state.queued = false
		if jumpState == state then
			applyJump()
		end
	end)
end

local function detachJump()
	local state = jumpState
	if state == nil then
		return
	end
	for _, c in state.connections do
		c:Disconnect()
	end
	jumpState = nil
end

local function attachJump(button: GuiObject)
	detachJump()
	local state: JumpState = {
		button = button,
		connections = {},
		native = { position = button.Position, size = button.Size, visible = button.Visible },
		applying = false,
		queued = false,
		desired = nil,
		moved = false,
		hidden = false,
	}
	jumpState = state
	local function watch(prop: string, record: () -> ())
		table.insert(
			state.connections,
			button:GetPropertyChangedSignal(prop):Connect(function()
				if state.applying then
					return
				end
				-- PlayerModule(또는 다른 스크립트)이 쓴 값: 기억해 두고 우리 배치를 다시 적용해요
				record()
				if current ~= nil or editing then
					queueJump()
				end
			end)
		)
	end
	watch("Position", function()
		local desired = state.desired
		if desired == nil or button.Position ~= desired.position then
			state.native.position = button.Position
		end
	end)
	watch("Size", function()
		local desired = state.desired
		if desired == nil or button.Size ~= desired.size then
			state.native.size = button.Size
		end
	end)
	watch("Visible", function()
		if not (state.hidden and button.Visible == false) then
			state.native.visible = button.Visible
		end
	end)
	table.insert(
		state.connections,
		button:GetPropertyChangedSignal("AnchorPoint"):Connect(function()
			if current ~= nil then
				queueJump()
			end
		end)
	)
	local parent = button.Parent
	if parent and parent:IsA("GuiObject") then
		table.insert(
			state.connections,
			parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				if current ~= nil then
					queueJump()
				end
			end)
		)
	end
	table.insert(
		state.connections,
		button.AncestryChanged:Connect(function()
			if jumpState == state and not button:IsDescendantOf(game) then
				detachJump()
			end
		end)
	)
	applyJump()
end

local function refindJump()
	local button = findJumpButton()
	if button == nil then
		if jumpState then
			detachJump()
		end
		return
	end
	if jumpState == nil or jumpState.button ~= button then
		attachJump(button)
	end
end

-- 배치 다시 계산 --------------------------------------------------------------

local function recompute()
	currentScreen = measure()
	local s = currentScreen
	local nextButtons: UiLayout.TouchButtons? = nil
	if s then
		nextButtons = TouchLayoutLogic.resolve(saved[TouchLayoutLogic.bucketFor(s)], s)
	end
	current = nextButtons
	applyJump()
	notify()
end

local function sameLayout(a: Types.TouchLayout?, b: Types.TouchLayout?): boolean
	if a == nil or b == nil then
		return a == b
	end
	if a.preset ~= b.preset then
		return false
	end
	for _, name in TouchLayoutLogic.NAMES do
		local p, q = (a :: any)[name], (b :: any)[name]
		if p.x ~= q.x or p.y ~= q.y or p.s ~= q.s then
			return false
		end
	end
	return true
end

local function onProfile(view: Types.ProfileView)
	local settings = view.settings
	local stored = if type(settings) == "table" then settings.touchLayout else nil
	local fresh: { [string]: Types.TouchLayout } = {}
	for _, bucket in TouchLayoutLogic.BUCKETS do
		local raw = if type(stored) == "table" then (stored :: any)[bucket] else nil
		local layout = TouchLayoutLogic.sanitizeLayout(raw)
		local mine = pending[bucket]
		if mine then
			if sameLayout(mine.layout, layout) or os.clock() - mine.at > PENDING_HOLD then
				pending[bucket] = nil
			else
				layout = mine.layout -- 보낸 값이 아직 안 돌아왔어요
			end
		end
		if layout then
			fresh[bucket] = layout
		end
	end
	saved = fresh
	recompute()
end

-- 저장 ----------------------------------------------------------------------

local lastSentAt = -math.huge
local saveSerial = 0

local function send(bucket: string, token: number)
	local mine = pending[bucket]
	if mine == nil or mine.token ~= token then
		return -- 더 새 저장이 있거나, 이미 서버 값과 같아졌어요
	end
	local wait = SEND_GAP - (os.clock() - lastSentAt)
	if wait > 0 then
		task.delay(wait, send, bucket, token)
		return
	end
	lastSentAt = os.clock()
	mine.at = lastSentAt
	local layout = mine.layout
	local change: Types.TouchLayoutChange = if layout
		then { bucket = bucket :: any, layout = layout }
		else { bucket = bucket :: any, reset = true }
	Remotes.event("SaveSettings"):FireServer({ touchLayout = change })
end

function TouchLayoutController.save(bucket: Types.TouchLayoutBucket, layout: Types.TouchLayout?)
	local value = if layout and layout.preset ~= "default" then TouchLayoutLogic.quantize(layout) else nil
	saveSerial += 1
	pending[bucket] = { layout = value, at = os.clock(), token = saveSerial }
	if value then
		saved[bucket] = value
	else
		saved[bucket] = nil -- 기본으로: 그 묶음 저장값을 지워요
	end
	send(bucket, saveSerial)
	recompute()
end

function TouchLayoutController.setEditing(on: boolean)
	if editing == on then
		return
	end
	editing = on
	applyJump()
	notify()
end

-- 편집 잠금 (라운드에 배치된 동안) ----------------------------------------------

local function watchLock()
	local me = Players.LocalPlayer
	local inMatch = false
	local phase: string? = nil
	local alive = true
	local passed = false
	local function refresh()
		local now = TouchLayoutLogic.editLocked({ inMatch = inMatch, phase = phase, alive = alive, passed = passed })
		if now ~= locked then
			locked = now
			for _, fn in table.clone(lockListeners) do
				task.spawn(fn, now)
			end
		end
	end
	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
		inMatch = type(snapshot) == "table" and snapshot.state == "InMatch"
		-- 서버는 Starting을 RoomUpdated(InMatch)보다 먼저 보내요 — InMatch가 될 때 phase를 지우면 Starting 잠금이 빠져요
		if not inMatch then
			phase = nil
			alive = true
			passed = false
		end
		refresh()
	end)
	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if type(info) ~= "table" then
			return
		end
		phase = info.phase
		if info.phase == "Starting" then
			alive = true
			passed = false
		elseif info.phase == "RoundIntro" then
			passed = false
		end
		local ids = info.aliveUserIds
		if type(ids) == "table" then
			alive = table.find(ids, me.UserId) ~= nil
		end
		refresh()
	end)
	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if type(result) ~= "table" or result.userId ~= me.UserId then
			return
		end
		if result.result == "Eliminated" then
			alive = false
		elseif result.result == "Passed" then
			passed = true
		end
		refresh()
	end)
end

function TouchLayoutController.start(_gui: Instance)
	if started then
		return
	end
	started = true
	watchLock()
	if not UserInputService.TouchEnabled then
		return -- PC·게임패드: 아무것도 바꾸지 않아요
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local ref = Instance.new("ScreenGui")
	ref.Name = "TouchLayoutRef"
	ref.ResetOnSpawn = false
	ref.ScreenInsets = Enum.ScreenInsets.None
	-- 재기만 해요 (자식이 없어 아무것도 그리지 않아요)
	ref.Parent = playerGui
	refGui = ref
	local safe = Instance.new("ScreenGui")
	safe.Name = "TouchLayoutSafe"
	safe.ResetOnSpawn = false
	safe.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	safe.Parent = playerGui
	safeGui = safe

	for _, gui in { ref, safe } do
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute)
		gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(recompute)
	end

	playerGui.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "JumpButton" or descendant.Name == "TouchGui" then
			task.defer(refindJump)
		end
	end)
	-- 점프 버튼은 다시 만들어질 수 있어서 가끔 확인해요 (GrabButton과 같은 방식)
	task.spawn(function()
		while true do
			refindJump()
			task.wait(1)
		end
	end)

	ProfileStore.changed(onProfile)
	local view = ProfileStore.get()
	if view then
		onProfile(view)
	else
		recompute()
	end
end

return TouchLayoutController
