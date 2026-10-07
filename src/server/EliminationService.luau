--!strict
-- 라운드 한 명 결과 발표: 통과/우승/탈락을 PlayerResult로 방송하고 (GDD 4, 7),
-- 탈락은 캐릭터를 고정했다가 Config.Match.EliminationCutscene 뒤 로비 스폰으로 돌려보내요.
-- RoundService·MatchService가 "무슨 일이 있었는지"(순서, 등수)를 계산해서 여기 함수를 불러요.
-- 결과는 그 매치의 방(roomId) 멤버 전원과 본인에게 보내요. 방을 막 나간 사람의 결과도 남은 사람에게 가요.
-- TODO(M3): 젓가락 픽업 → 간장 → 냠! 연출 (지금은 그 자리에 고정만 해요)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local CharacterUtil = require(script.Parent.CharacterUtil)
local RoomService = require(script.Parent.RoomService)

local EliminationService = {}

local playerResultEvent: RemoteEvent

local function broadcast(roomId: string, result: Types.PlayerResult)
	local sent: { [Player]: boolean } = {}
	local audience = RoomService.getPlayers(roomId)
	local subject = Players:GetPlayerByUserId(result.userId)
	if subject then
		table.insert(audience, subject)
	end
	for _, target in audience do
		if target.Parent and not sent[target] then -- 게임을 떠나는 중인 플레이어에게는 보내지 않아요
			sent[target] = true
			playerResultEvent:FireClient(target, result)
		end
	end
end

-- 라운드 통과 (결승이 아닌 라운드). place는 이번 라운드에서 통과한 순서(1부터)예요.
function EliminationService.passed(roomId: string, player: Player, place: number)
	broadcast(roomId, { userId = player.UserId, result = "Passed", place = place })
end

-- 결승 1등. EliminationService.passed 대신 이걸 불러요.
function EliminationService.won(roomId: string, userId: number)
	broadcast(roomId, { userId = userId, result = "Won", place = 1 })
end

-- 매치 중 방/게임을 나간 사람의 탈락 발표. 캐릭터는 건드리지 않아요.
function EliminationService.left(roomId: string, userId: number, place: number)
	broadcast(roomId, { userId = userId, result = "Eliminated", place = place })
end

-- 탈락. place는 이 매치에서의 최종 등수예요 (RoundLogic.Standings가 계산해요).
-- 캐릭터를 그 자리에 고정했다가 연출 시간 뒤 로비 스폰으로 돌려보내요.
function EliminationService.eliminate(roomId: string, player: Player, place: number)
	broadcast(roomId, { userId = player.UserId, result = "Eliminated", place = place })

	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.PlatformStand = true
	end
	if root then
		root.Anchored = true
	end

	task.delay(Config.Match.EliminationCutscene, function()
		if not player.Parent or player.Character ~= character then
			return -- 그 사이 나갔거나 캐릭터가 바뀌었으면(리셋으로 리스폰) 손대지 않아요
		end
		-- 고정 풀기와 이동 값 복구(WalkSpeed·JumpPower)까지 toLobby가 해요
		CharacterUtil.toLobby(player)
	end)
end

function EliminationService.init()
	playerResultEvent = Remotes.event("PlayerResult")
end

function EliminationService.start() end

return EliminationService
