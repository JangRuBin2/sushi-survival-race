--!strict
-- 잡기·공격 버튼을 보일지 지켜보는 클라이언트 모듈 (m6-14 C1). 판단은 Shared.RaceActionLogic(순수).
--   RaceActionState.get() -> boolean            지금 잡기·공격을 쓸 수 있는가 (출발한 라운드의 내 레이서)
--   RaceActionState.changed(fn) -> () -> ()     값이 바뀔 때 fn(canUse). 돌려준 함수로 끊어요
-- 처음 부를 때 한 번만 리모트(RoomUpdated·MatchPhase·PlayerResult)와 RespawnAt 속성·카메라를 듣기 시작해요.
-- 관전(카메라가 내 Humanoid를 안 봄)은 이벤트가 없는 경우도 있어서 0.25초마다 한 번 다시 봐요.
-- UI 편의일 뿐 권한이 아니에요 — 서버 AttackService·GrabService가 그대로 다시 판단해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local RaceActionLogic = require(ReplicatedStorage.Shared.RaceActionLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local POLL_INTERVAL = 0.25

local RaceActionState = {}

local me = Players.LocalPlayer
local state = RaceActionLogic.new()
local current = false
local started = false
local nextId = 0
local listeners: { [number]: (canUse: boolean) -> () } = {}

local function isSpectating(): boolean
	local camera = Workspace.CurrentCamera
	local character = me.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return camera == nil or humanoid == nil or camera.CameraSubject ~= humanoid
end

local function refresh()
	local now = RaceActionLogic.canUseRaceActions(state, {
		respawning = me:GetAttribute(Attributes.RespawnAt) ~= nil,
		spectating = isSpectating(),
	})
	if now == current then
		return
	end
	current = now
	for _, fn in table.clone(listeners) do
		task.spawn(fn, now)
	end
end

local function start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
			RaceActionLogic.onRoom(state, type(snapshot) == "table" and snapshot.state == "InMatch")
			refresh()
		end)
		Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
			if type(info) ~= "table" then
				return
			end
			local ids = if type(info.aliveUserIds) == "table" then info.aliveUserIds else nil
			RaceActionLogic.onPhase(state, info.phase, ids, me.UserId)
			refresh()
		end)
		Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
			if type(result) ~= "table" or result.userId ~= me.UserId then
				return
			end
			RaceActionLogic.onResult(state, result.result)
			refresh()
		end)
	end)
	me:GetAttributeChangedSignal(Attributes.RespawnAt):Connect(refresh)
	me.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			refresh()
		end
	end)
	refresh()
end

function RaceActionState.get(): boolean
	start()
	return current
end

function RaceActionState.changed(fn: (canUse: boolean) -> ()): () -> ()
	start()
	nextId += 1
	local id = nextId
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

return RaceActionState
