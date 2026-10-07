--!strict
-- 관전·우승 카메라 (m2-06, GDD 4·10). 클라이언트 카메라만 바꾸고 서버 판정·캐릭터 위치는 건드리지 않아요.
--   탈락: 연출 시간(Config.Match.EliminationCutscene) 뒤 자동 관전. [로비로] = 관전만 끄기 (방 멤버십 유지,
--         리모트 호출 없음), 그 뒤 [관전하기]로 다시 관전.
--   Race 통과: 대기석에서 바로 관전, [내 캐릭터 보기]로 끌 수 있고 다음 RoundIntro에 자동으로 끝나요.
--   우승(Victory): 모두의 카메라가 우승자를 비춰요.
--   방이 대기실로 돌아오거나 방을 나가면 모두 정리하고 카메라를 내 캐릭터로 돌려요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpectateLogic = require(ReplicatedStorage.Shared.SpectateLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local SpectateScreen = require(script.Parent.SpectateScreen)

-- 대상이 통과·탈락·퇴장했는지, 기본 카메라 스크립트가 CameraSubject를 되돌렸는지 다시 보는 간격(초)
local REFRESH_INTERVAL = 0.25

type Role = "None" | "Eliminated" | "Passed"

local SpectateController = {}

local function humanoidOf(userId: number): Humanoid?
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function SpectateController.start(gui: Instance)
	local player = Players.LocalPlayer
	local me = player.UserId

	-- 서버에서 받은 값
	local inMatch = false
	local aliveUserIds: { number }? = nil
	local racerUserIds: { number }? = nil
	local mapKind: Types.MapKind? = nil
	local victoryWinner: number? = nil
	local inVictory = false

	-- 내 관전 상태
	local role: Role = "None"
	local watching = false
	local inCutscene = false -- 탈락 연출 중에는 관전 UI를 띄우지 않아요
	local roleToken = 0 -- 탈락 연출 대기 중에 상태가 바뀌었는지 확인용
	local candidates: { number } = {}
	local target: number? = nil
	local cameraOverridden = false

	local screen: SpectateScreen.SpectateScreen

	local function setCameraSubject(humanoid: Humanoid)
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		cameraOverridden = true
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		if camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
	end

	-- 우리가 카메라를 바꿨을 때만 되돌려요 (다른 연출 카메라와 싸우지 않게)
	local function restoreCamera()
		if not cameraOverridden then
			return
		end
		cameraOverridden = false
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		camera.CameraType = Enum.CameraType.Custom
		local mine = humanoidOf(me)
		if mine then
			camera.CameraSubject = mine
		end
	end

	local function isAvailable(userId: number): boolean
		return humanoidOf(userId) ~= nil
	end

	local function refreshCandidates()
		local fresh = SpectateLogic.candidates(racerUserIds, aliveUserIds, me, isAvailable)
		target = SpectateLogic.reconcile(candidates, fresh, target)
		candidates = fresh
	end

	local function nameOf(userId: number): string
		local other = Players:GetPlayerByUserId(userId)
		return if other then other.DisplayName else `#{userId}`
	end

	local function render()
		if not inMatch then
			screen:hide()
			restoreCamera()
			return
		end

		if inVictory then
			screen:hide()
			local winnerHumanoid = if victoryWinner then humanoidOf(victoryWinner) else nil
			if winnerHumanoid then
				setCameraSubject(winnerHumanoid)
			else
				restoreCamera()
			end
			return
		end

		if role == "None" or inCutscene then
			screen:hide()
			restoreCamera()
			return
		end

		local actionText = if role == "Eliminated" then "로비로" else "내 캐릭터 보기"
		if not watching then
			screen:showIdle("👀 관전하기")
			restoreCamera()
			return
		end

		refreshCandidates()
		local targetHumanoid = if target then humanoidOf(target) else nil
		if target and targetHumanoid then
			setCameraSubject(targetHumanoid)
			screen:showWatching(`👀 관전 중: {nameOf(target)}`, #candidates > 1, actionText)
		else
			restoreCamera()
			screen:showWatching("관전할 사람이 없어요", false, actionText)
		end
	end

	local function setRole(newRole: Role, newWatching: boolean)
		roleToken += 1
		role = newRole
		watching = newWatching
		inCutscene = false
		render()
	end

	local function resetAll()
		inVictory = false
		victoryWinner = nil
		racerUserIds = nil
		aliveUserIds = nil
		mapKind = nil
		candidates = {}
		target = nil
		setRole("None", false)
	end

	local function cycle(direction: number)
		if role == "None" or not watching or inVictory or inCutscene then
			return
		end
		refreshCandidates()
		target = SpectateLogic.step(candidates, target, direction)
		render()
	end

	screen = SpectateScreen.new(gui, {
		previous = function()
			cycle(-1)
		end,
		nextTarget = function()
			cycle(1)
		end,
		action = function()
			if role == "None" or inCutscene then
				return
			end
			watching = not watching
			render()
		end,
	})

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		local nowInMatch = room ~= nil and room.state == "InMatch"
		if not nowInMatch then
			inMatch = false
			resetAll()
		else
			inMatch = true
			render()
		end
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if info.aliveUserIds then
			aliveUserIds = info.aliveUserIds
		end
		if info.mapKind then
			mapKind = info.mapKind
		end

		if info.phase == "Starting" then
			-- 새 매치: 이전 매치의 상태가 남아 있지 않게
			local alive = aliveUserIds
			resetAll()
			aliveUserIds = alive
		elseif info.phase == "RoundIntro" then
			-- 지난 라운드의 레이서 목록은 버리고(새 RoundProgress가 올 때까지 생존자를 봐요),
			-- Race 통과자의 관전은 여기서 끝나요.
			racerUserIds = nil
			inVictory = false
			if role == "Passed" then
				setRole("None", false)
				return
			end
		elseif info.phase == "Victory" then
			inVictory = true
			victoryWinner = info.winnerUserId
		else
			inVictory = false
		end
		render()
	end)

	Remotes.event("RoundProgress").OnClientEvent:Connect(function(progress: Types.RoundProgress)
		racerUserIds = progress.racerUserIds
		render()
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if result.userId ~= me then
			render() -- 보고 있던 사람이 통과·탈락했을 수 있어요
			return
		end
		if result.result == "Eliminated" then
			setRole("Eliminated", false)
			inCutscene = true
			render()
			local mine = roleToken
			task.delay(Config.Match.EliminationCutscene, function()
				if roleToken == mine and role == "Eliminated" and inMatch then
					inCutscene = false
					watching = true
					render()
				end
			end)
		elseif result.result == "Passed" and mapKind == "Race" then
			setRole("Passed", true)
		end
	end)

	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Left or key == Enum.KeyCode.Q then
			cycle(-1)
		elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.E then
			cycle(1)
		end
	end)

	-- 대상이 사라졌거나, 대상·내 캐릭터가 리스폰해서 기본 카메라가 CameraSubject를 바꿨을 때를 잡아요
	task.spawn(function()
		while gui.Parent do
			if inMatch and (inVictory or (role ~= "None" and watching)) then
				render()
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return SpectateController
