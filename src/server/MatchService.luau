--!strict
-- 방 하나의 매치 상태 머신 (GDD 4, 11.4)
-- RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting
-- 라운드 수/통과 인원/맵 구성은 Shared.Rules로 계산해요.
-- 상태는 이 모듈 전역이 아니라 방마다 생기는 MatchContext(aliveUserIds)에 둬요
-- (여러 방이 동시에 매치를 돌릴 수 있어요). RoomService.onMatchStart가 방마다 새 스레드로
-- runMatch를 불러주기 때문에, 여기서는 그 스레드를 그냥 끝까지 쓰면 돼요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Types = require(ReplicatedStorage.Shared.Types)
local Maps = require(ReplicatedStorage.Shared.maps)

local RoomService = require(script.Parent.RoomService)
local RoundService = require(script.Parent.RoundService)

local MatchService = {}

type MatchContext = {
	roomId: string,
	aliveUserIds: { [number]: boolean },
}

local SPAWN_LIFT = Vector3.new(0, 3, 0)

-- 방 id → 지금 진행 중인 매치. RoomService.onMemberLeft가 여기서 생존자 집계를 지워요.
local matches: { [string]: MatchContext } = {}

local matchPhaseEvent: RemoteEvent

local function broadcast(roomId: string, info: Types.MatchPhaseInfo)
	for _, player in RoomService.getPlayers(roomId) do
		matchPhaseEvent:FireClient(player, info)
	end
end

local function aliveCount(ctx: MatchContext): number
	local n = 0
	for _ in ctx.aliveUserIds do
		n += 1
	end
	return n
end

local function alivePlayers(ctx: MatchContext): { Player }
	local list = {}
	for userId in ctx.aliveUserIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function sendHome(roomId: string)
	local spawn = workspace:FindFirstChild("LobbySpawn") :: BasePart?
	if spawn == nil then
		return
	end
	for _, player in RoomService.getPlayers(roomId) do
		local character = player.Character
		if character then
			character:PivotTo(spawn.CFrame + SPAWN_LIFT)
		end
	end
end

local function runMatch(room: RoomService.Room, players: { Player })
	local roomId = room.id
	local ctx: MatchContext = { roomId = roomId, aliveUserIds = {} }
	for _, player in players do
		ctx.aliveUserIds[player.UserId] = true
	end
	matches[roomId] = ctx

	local startCount = #players
	broadcast(roomId, { phase = "Starting", endsAt = workspace:GetServerTimeNow() + Config.Match.StartCountdown })
	task.wait(Config.Match.StartCountdown)

	local roundCount = Rules.roundCount(startCount)
	-- 맵 풀이 아직 비어 있으면(race-belt 트랙이 머지되기 전) 라운드 없이 바로 결과로 가요.
	-- 맵이 등록되면 이 분기는 저절로 안 타게 돼요.
	local planOk, planResult = pcall(Rules.buildRoundPlan, roundCount, Maps.infos(), Random.new())
	local plan: { Rules.MapInfo }? = if planOk then planResult else nil
	if plan == nil then
		warn(`[MatchService] room {roomId}: no maps registered in Shared.maps yet — skipping rounds ({planResult})`)
	end

	local roundIndex: number? = 1
	while plan and roundIndex and aliveCount(ctx) > 1 do
		local mapInfo = (plan :: { Rules.MapInfo })[roundIndex]
		local map = Maps.get(mapInfo.id)
		local timeLimit = Maps.timeLimit(map)

		broadcast(roomId, {
			phase = "RoundIntro",
			endsAt = workspace:GetServerTimeNow() + Config.Match.IntroDuration,
			roundIndex = roundIndex,
			roundCount = roundCount,
			mapId = map.id,
			mapName = map.displayName,
			mapKind = map.kind,
			rule = map.rule,
		})
		task.wait(Config.Match.IntroDuration)

		if aliveCount(ctx) <= 1 then
			break -- 소개 보여주는 사이에 인원이 줄어서 이미 승부가 났어요
		end
		local targetCount = Rules.qualifyCount(aliveCount(ctx), roundCount, roundIndex)

		broadcast(roomId, {
			phase = "RoundActive",
			endsAt = workspace:GetServerTimeNow() + timeLimit,
			roundIndex = roundIndex,
			roundCount = roundCount,
			mapId = map.id,
			mapName = map.displayName,
			mapKind = map.kind,
			rule = map.rule,
		})

		local result = RoundService.runRound({
			roomId = roomId,
			players = alivePlayers(ctx),
			map = map,
			targetCount = targetCount,
			roundIndex = roundIndex,
			roundCount = roundCount,
		})
		for _, userId in result.eliminatedUserIds do
			ctx.aliveUserIds[userId] = nil
		end

		broadcast(roomId, {
			phase = "RoundResults",
			endsAt = workspace:GetServerTimeNow() + Config.Match.ResultsDuration,
			roundIndex = roundIndex,
			roundCount = roundCount,
		})
		task.wait(Config.Match.ResultsDuration)

		roundIndex = Rules.nextRound(roundIndex, roundCount, aliveCount(ctx))
	end

	local winnerUserId: number? = nil
	for userId in ctx.aliveUserIds do
		winnerUserId = userId
		break
	end

	if winnerUserId then
		broadcast(roomId, {
			phase = "Victory",
			endsAt = workspace:GetServerTimeNow() + Config.Match.VictoryDuration,
			winnerUserId = winnerUserId,
		})
		task.wait(Config.Match.VictoryDuration)
	end

	sendHome(roomId)
	matches[roomId] = nil
	RoomService.endMatch(roomId)
end

function MatchService.init()
	matchPhaseEvent = Remotes.event("MatchPhase")
end

function MatchService.start()
	RoomService.onMatchStart(function(room: RoomService.Room, players: { Player })
		local ok, err = pcall(runMatch, room, players)
		if not ok then
			warn(`[MatchService] match for room {room.id} crashed: {err}`)
			matches[room.id] = nil
			RoomService.endMatch(room.id)
		end
	end)

	RoomService.onMemberLeft(function(roomId: string, player: Player)
		local ctx = matches[roomId]
		if ctx then
			ctx.aliveUserIds[player.UserId] = nil
		end
		RoundService.handlePlayerLeft(roomId, player)
	end)
end

return MatchService
