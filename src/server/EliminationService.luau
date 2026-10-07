--!strict
-- 라운드 한 명 결과 발표: 통과/우승/탈락을 PlayerResult로 방송하고 (GDD 4, 7),
-- 탈락은 캐릭터를 고정했다가 Config.Match.EliminationCutscene 뒤 로비 스폰으로 돌려보내요.
-- RoundService가 "무슨 일이 있었는지"(순서, 자리)를 계산해서 여기 함수를 불러요.
-- TODO(M3): 젓가락 픽업 → 간장 → 냠! 연출 (지금은 그 자리에 고정만 해요)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local CharacterUtil = require(script.Parent.CharacterUtil)
local RoomService = require(script.Parent.RoomService)

local EliminationService = {}

local playerResultEvent: RemoteEvent

-- 결과는 같은 방(매치) 멤버에게만 보여요. 방에서 이미 빠진 경우(테스트 등)는 본인에게만.
local function audienceFor(player: Player): { Player }
	local roomId = RoomService.getRoomIdOf(player)
	if roomId then
		return RoomService.getPlayers(roomId)
	end
	return { player }
end

local function broadcast(player: Player, result: Types.PlayerResult)
	for _, target in audienceFor(player) do
		if target.Parent then -- 게임을 떠나는 중인 플레이어에게는 보내지 않아요
			playerResultEvent:FireClient(target, result)
		end
	end
end

-- 라운드 통과 (결승이 아닌 라운드). place는 이번 라운드에서 통과한 순서(1부터)예요.
function EliminationService.passed(player: Player, place: number)
	broadcast(player, { userId = player.UserId, result = "Passed", place = place })
end

-- 결승 1등. EliminationService.passed 대신 이걸 불러요.
function EliminationService.won(player: Player)
	broadcast(player, { userId = player.UserId, result = "Won", place = 1 })
end

-- 탈락. place는 이 매치에서의 최종 등수예요 (RoundService가 계산해요).
-- 캐릭터를 그 자리에 고정했다가 연출 시간 뒤 로비 스폰으로 돌려보내요.
function EliminationService.eliminate(player: Player, place: number)
	broadcast(player, { userId = player.UserId, result = "Eliminated", place = place })

	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.PlatformStand = true
	end
	if root then
		root.Anchored = true
	end

	task.delay(Config.Match.EliminationCutscene, function()
		if not player.Parent or player.Character ~= character then
			return -- 그 사이 나갔거나 캐릭터가 바뀌었으면 손대지 않아요
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
