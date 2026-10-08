--!strict
-- HUD 리모트 연결: MatchPhase/RoundProgress/PlayerResult를 받아 HudScreen에 반영해요.
-- 보이고 숨기는 기준은 방 상태(RoomUpdated)예요: InMatch면 보이고, 아니면 숨겨요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EliminationCutsceneLogic = require(ReplicatedStorage.Shared.EliminationCutsceneLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local HudScreen = require(script.Parent.HudScreen)

local HudController = {}

local function personalResultText(result: Types.PlayerResult): string
	if result.result == "Won" then
		return "🏆 우승했어요!"
	elseif result.result == "Passed" then
		return `✅ {result.place}번째로 통과했어요!`
	end
	return `🥢 탈락했어요… ({result.place}등)`
end

function HudController.start(gui: Instance)
	local player = Players.LocalPlayer

	local function nameOf(userId: number): string
		local other = Players:GetPlayerByUserId(userId)
		return if other then other.DisplayName else `#{userId}`
	end

	local hud = HudScreen.new(gui, nameOf, player.UserId)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		hud:setVisible(room ~= nil and room.state == "InMatch")
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		hud:setPhase(info)
	end)

	Remotes.event("RoundProgress").OnClientEvent:Connect(function(progress: Types.RoundProgress)
		hud:setProgress(progress)
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if result.userId == player.UserId then
			-- 낙하·리셋 탈락은 탈락 연출의 "먹혔다!" 스탬프가 등수를 대신 보여 줘요 (m3-03)
			if result.result == "Eliminated" and EliminationCutsceneLogic.shouldPlay(result.cause) then
				return
			end
			-- 우승은 곧바로 이어지는 우승 연출·화면이 보여 줘요. 연출 위에 글씨가 겹치지 않게 띄우지 않아요 (m3-05 QA B3)
			if result.result == "Won" then
				return
			end
			hud:showPersonalResult(personalResultText(result))
		end
	end)
end

return HudController
