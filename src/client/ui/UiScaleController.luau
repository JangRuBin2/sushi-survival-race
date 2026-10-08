--!strict
-- 화면 크기 배율 (m4-09). ScreenGui마다 UIScale을 붙여 휴대폰·작은 화면에서 UI 크기를 맞춰요.
--   UiScaleController.attach(screenGui)   UIScale(이름 "UiScale")을 하나 붙이고 화면 크기가 바뀔 때마다 갱신해요.
--                                         같은 gui에 두 번 불러도 하나. ScreenInsets = CoreUISafeInsets도 맞춰요
--                                         (위쪽 바 줄에 들어가는 gui는 attach 뒤에 TopbarSafeInsets로 바꾸면 돼요).
--   UiScaleController.metrics()           지금 화면의 UiLayout.Metrics (scale, compact, width, height)
--   UiScaleController.onChanged(fn)       화면 크기가 바뀔 때마다 fn(metrics). 바로 한 번 불러요. 돌려준 함수로 끊어요.
-- 배율 계산은 Shared.UiLayout(순수). UIScale 안에서 Offset v는 v × scale 실제 픽셀이라,
-- AbsolutePosition/AbsoluteSize(실제 픽셀)를 Offset에 넣을 때는 scale로 나눠야 해요 (IntroScreen 참고).
-- 터치 버튼(DiveGui·GrabGui)은 점프 버튼 픽셀 위치에 맞춰야 해서 붙이지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local SCALE_NAME = "UiScale"

local UiScaleController = {}

export type Listener = (metrics: UiLayout.Metrics) -> ()

local scales: { [ScreenGui]: UIScale } = {}
local listeners: { [number]: Listener } = {}
local nextListenerId = 0
local current: UiLayout.Metrics = UiLayout.metrics(0, 0)
local watching = false
local cameraConnection: RBXScriptConnection? = nil

local function apply()
	for gui, scale in scales do
		if gui.Parent == nil and scale.Parent == nil then
			scales[gui] = nil
		elseif scale.Scale ~= current.scale then
			scale.Scale = current.scale
		end
	end
	for _, listener in table.clone(listeners) do
		task.spawn(listener, current)
	end
end

local function refresh()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local size = camera.ViewportSize
	if size.X == current.width and size.Y == current.height then
		return
	end
	current = UiLayout.metrics(size.X, size.Y)
	apply()
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end

-- 처음 쓰일 때 화면 크기를 보기 시작해요 (LobbyController가 start보다 먼저 attach해요)
local function ensureWatching()
	if watching then
		return
	end
	watching = true
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

function UiScaleController.metrics(): UiLayout.Metrics
	ensureWatching()
	return current
end

function UiScaleController.onChanged(listener: Listener): () -> ()
	ensureWatching()
	nextListenerId += 1
	local id = nextListenerId
	listeners[id] = listener
	listener(current)
	return function()
		listeners[id] = nil
	end
end

function UiScaleController.attach(screenGui: ScreenGui)
	ensureWatching()
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local scale = scales[screenGui]
	if scale == nil then
		local existing = screenGui:FindFirstChild(SCALE_NAME)
		if existing and existing:IsA("UIScale") then
			scale = existing
		else
			local created = Instance.new("UIScale")
			created.Name = SCALE_NAME
			created.Parent = screenGui
			scale = created
		end
		scales[screenGui] = scale :: UIScale
	end
	(scale :: UIScale).Scale = current.scale
end

-- init.client.luau가 부르는 시작점: 로비·방·HUD·관전·연출이 같이 쓰는 LobbyGui를 붙여요
-- (LobbyController가 이미 붙였으면 그대로). 우승 큰 글씨 gui는 VictoryCutsceneScreen이 붙여요.
function UiScaleController.start(gui: Instance)
	if gui:IsA("ScreenGui") then
		UiScaleController.attach(gui)
	end
end

return UiScaleController
