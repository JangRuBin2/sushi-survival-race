--!strict
-- 잡기 판정 (껍데기 — 채우는 스펙: m3-07). 지금은 GrabInput을 받아서 무시해요.
-- 채울 때: 인자 타입(boolean)·요청 간격(Config.Grab.InputMinInterval)을 검증하고,
-- RoundService.activeRoomOf로 "같은 방에서 달리는 중"인지 확인해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GrabService = {}

local grabInputEvent: RemoteEvent

function GrabService.init()
	grabInputEvent = Remotes.event("GrabInput")
end

function GrabService.start()
	grabInputEvent.OnServerEvent:Connect(function(_player: Player, _holding: unknown) end)
end

return GrabService
