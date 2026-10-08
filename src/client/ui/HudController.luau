--!strict
-- HUD 리모트 연결: MatchPhase/RoundProgress/PlayerResult를 받아 HudScreen에 반영해요.
-- 보이고 숨기는 기준은 방 상태(RoomUpdated)예요: InMatch면 보이고, 아니면 숨겨요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EliminationCutsceneLogic = require(ReplicatedStorage.Shared.EliminationCutsceneLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Sfx = require(script.Parent.Parent.Sfx)
local HudScreen = require(script.Parent.HudScreen)

local OVERTIME_MUSIC_SPEED = 1.1 -- 결승 연장전 동안 배경음 재생 속도 (m5-01)

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

	-- 지금 매치 단계 (우승 글씨를 Victory 동안 띄우지 않으려고)
	local currentPhase: Types.MatchPhase? = nil
	-- 결승 연장전 표시 중 (m5-01). 처음 받을 때 한 번만 배너·경적·배경음 가속
	local overtimeShown = false

	local function clearOvertime()
		if not overtimeShown then
			return
		end
		overtimeShown = false
		hud:clearOvertime()
		Sfx.setMusicSpeed(1)
	end

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		local inMatch = room ~= nil and room.state == "InMatch"
		if not inMatch then
			currentPhase = nil
			clearOvertime()
		end
		hud:setVisible(inMatch)
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		currentPhase = info.phase
		if info.phase ~= "RoundActive" then
			clearOvertime()
		end
		hud:setPhase(info)
		-- 우승 연출이 시작되면 "🏆 우승했어요!"를 지워요 — 연출 위에 겹치지 않게 (m3-05 QA B3, m3-09 QA B1)
		if info.phase == "Victory" then
			hud:clearPersonalResult()
		end
	end)

	Remotes.event("RoundProgress").OnClientEvent:Connect(function(progress: Types.RoundProgress)
		hud:setProgress(progress)
		local collapseAt = progress.collapseAt
		if
			progress.overtime == true
			and type(collapseAt) == "number"
			and not overtimeShown
			and currentPhase == "RoundActive"
		then
			overtimeShown = true
			hud:showOvertime(collapseAt)
			Sfx.play("Overtime")
			Sfx.setMusicSpeed(OVERTIME_MUSIC_SPEED)
		end
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if result.userId == player.UserId then
			-- 낙하·리셋 탈락은 탈락 연출의 "먹혔다!" 스탬프가 등수를 대신 보여 줘요 (m3-03)
			if result.result == "Eliminated" and EliminationCutsceneLogic.shouldPlay(result.cause) then
				return
			end
			-- 우승 글씨는 Victory가 올 때까지 남겨 둬요 (결승 뒤 RoundResults 동안 우승을 바로 알게, m3-09 QA B1)
			if result.result == "Won" then
				if currentPhase ~= "Victory" then
					hud:showPersonalResult(personalResultText(result), true)
				end
				return
			end
			hud:showPersonalResult(personalResultText(result))
		end
	end)
end

return HudController
