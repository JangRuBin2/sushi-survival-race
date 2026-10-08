--!strict
-- 방 하나의 매치 상태 머신 (GDD 4, 11.4)
-- RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting
-- 라운드 수/통과 인원/맵 구성은 Shared.Rules로, 매치 등수는 Shared.RoundLogic의 Standings로 계산해요.
-- 모든 MatchPhase 방송에 aliveUserIds(아직 탈락하지 않은 사람), Victory에 standings(전체 순위)를 실어요.
-- 상태는 이 모듈 전역이 아니라 방마다 생기는 MatchContext(aliveUserIds, standings)에 둬요
-- (여러 방이 동시에 매치를 돌릴 수 있어요). RoomService.onMatchStart가 방마다 새 스레드로
-- runMatch를 불러주기 때문에, 여기서는 그 스레드를 그냥 끝까지 쓰면 돼요.
-- 매치 흐름 훅(MatchEvents): matchStart = Starting 방송 직후, roundStart = 출발 직전, matchEnd = 승부가 정해진 순간
-- (우승자가 있으면 Victory 방송 직후), winnerShowcase = Victory가 끝나고 로비로 보내기 직전 (m4-01).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Rules)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local Maps = require(ReplicatedStorage.Shared.maps)

local CharacterUtil = require(script.Parent.CharacterUtil)
local EliminationService = require(script.Parent.EliminationService)
local MatchEvents = require(script.Parent.MatchEvents)
local PlaceService = require(script.Parent.PlaceService)
local RoomService = require(script.Parent.RoomService)
local RoundService = require(script.Parent.RoundService)

local MatchService = {}

type MatchContext = {
	roomId: string,
	aliveUserIds: { [number]: boolean },
	standings: RoundLogic.Standings, -- 매치를 시작한 모든 플레이어의 등수 (나간 사람 포함)
	round: RoundService.PreparedRound?, -- 지금 소개/진행 중인 라운드
	participants: { number }, -- 매치를 시작한 전원 (MatchEvents)
	endFired: boolean, -- MatchEvents.fireMatchEnd를 이미 보냈는지 (매치당 한 번)
}

-- 방 id → 지금 진행 중인 매치. RoomService.onMemberLeft가 여기서 생존자 집계를 지워요.
local matches: { [string]: MatchContext } = {}

local matchPhaseEvent: RemoteEvent

local function aliveList(ctx: MatchContext): { number }
	local list = {}
	for userId in ctx.aliveUserIds do
		table.insert(list, userId)
	end
	table.sort(list)
	return list
end

local function broadcast(ctx: MatchContext, info: Types.MatchPhaseInfo)
	info.aliveUserIds = aliveList(ctx)
	for _, player in RoomService.getPlayers(ctx.roomId) do
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
	for _, player in RoomService.getPlayers(roomId) do
		CharacterUtil.toLobby(player)
	end
end

-- 승부가 정해진 순간 (MatchEvents.onMatchEnd). 매치당 한 번만 보내요.
local function fireMatchEnd(ctx: MatchContext, winnerUserId: number?, standings: { Types.Standing })
	if ctx.endFired then
		return
	end
	ctx.endFired = true
	MatchEvents.fireMatchEnd(ctx.roomId, {
		winnerUserId = winnerUserId,
		standings = standings,
		participants = table.clone(ctx.participants),
	})
end

-- 로비 단상에 세울 우승자 (MatchEvents.onWinnerShowcase, m4-06). 한 플레이스 모드에서만 여기서 보내요 —
-- 플레이스 분리 모드는 로비 서버가 보내요 (m4-11).
local function fireWinnerShowcase(ctx: MatchContext, winnerUserId: number)
	if PlaceService.role() ~= "Single" then
		return
	end
	local name = tostring(winnerUserId)
	for _, entry in ctx.standings.entries do
		if entry.userId == winnerUserId then
			name = entry.name
		end
	end
	local appearanceId = Config.Appearance.Default
	local player = Players:GetPlayerByUserId(winnerUserId)
	local character = player and player.Character
	local worn = character and character:GetAttribute(Attributes.AppearanceId)
	if type(worn) == "string" and worn ~= "" then
		appearanceId = worn
	end
	MatchEvents.fireWinnerShowcase({ userId = winnerUserId, name = name, appearanceId = appearanceId })
end

-- Studio 전용 디버그 강제 플랜 (Config.DEBUG.forceMapPlan). 없거나 잘못됐으면 nil (잘못됐으면 경고).
local function forcedPlan(roomId: string): { Rules.MapInfo }?
	local ids = Config.DEBUG.forceMapPlan
	if ids == nil or not RunService:IsStudio() then
		return nil
	end
	local plan, problem = Rules.resolveForcedPlan(ids, Maps.infos())
	if plan == nil then
		warn(`[MatchService] room {roomId}: ignoring Config.DEBUG.forceMapPlan — {problem}`)
	end
	return plan
end

local function runMatch(room: RoomService.Room, players: { Player })
	local roomId = room.id
	local entries = {}
	for _, player in players do
		table.insert(entries, { userId = player.UserId, name = player.DisplayName })
	end
	local ctx: MatchContext = {
		roomId = roomId,
		aliveUserIds = {},
		standings = RoundLogic.newStandings(entries),
		round = nil,
		participants = {},
		endFired = false,
	}
	for _, player in players do
		ctx.aliveUserIds[player.UserId] = true
		table.insert(ctx.participants, player.UserId)
	end
	matches[roomId] = ctx

	local startCount = #players
	broadcast(ctx, { phase = "Starting", endsAt = workspace:GetServerTimeNow() + Config.Match.StartCountdown })
	MatchEvents.fireMatchStart(roomId, ctx.participants)
	task.wait(Config.Match.StartCountdown)

	-- 강제 플랜이면 목록을 끝까지 돌아요: 결승 건너뛰기 없음, 혼자(생존자 1명)여도 계속.
	local forced = forcedPlan(roomId)
	local isForced = forced ~= nil
	local minAlive = if isForced then 1 else 2 -- 이 인원 이상 살아 있어야 다음 라운드를 해요

	local roundCount: number
	local plan: { Rules.MapInfo }?
	if forced then
		plan = forced
		roundCount = #forced
	else
		roundCount = Rules.roundCount(startCount)
		-- 맵 풀이 비어 있으면 라운드 없이 바로 결과로 가요.
		local planOk, planResult = pcall(Rules.buildRoundPlan, roundCount, Maps.infos(), Random.new())
		plan = if planOk then planResult else nil
		if plan == nil then
			warn(
				`[MatchService] room {roomId}: no maps registered in Shared.maps yet — skipping rounds ({planResult})`
			)
		end
	end

	-- 결승 건너뛰기(GDD 4.1)는 강제 플랜에서는 쓰지 않아요.
	local function roundToPlay(index: number): number
		if isForced then
			return index
		end
		return Rules.roundToPlay(index, roundCount, aliveCount(ctx))
	end
	local function nextRound(finished: number): number?
		if isForced then
			return if finished < roundCount then finished + 1 else nil
		end
		return Rules.nextRound(finished, roundCount, aliveCount(ctx))
	end

	local roundIndex: number? = 1
	while plan and roundIndex and aliveCount(ctx) >= minAlive do
		-- 결과 단계 뒤 nextRound가 정한 번호를, 그 사이 이탈까지 반영해서 한 번 더 맞춰요 (GDD 4.1)
		roundIndex = roundToPlay(roundIndex)
		local mapInfo = (plan :: { Rules.MapInfo })[roundIndex]
		local map = Maps.get(mapInfo.id)
		local timeLimit = Maps.timeLimit(map)

		broadcast(ctx, {
			phase = "RoundIntro",
			endsAt = workspace:GetServerTimeNow() + Config.Match.IntroDuration,
			roundIndex = roundIndex,
			roundCount = roundCount,
			mapId = map.id,
			mapName = map.displayName,
			mapKind = map.kind,
			rule = map.rule,
		})
		-- 소개 동안 맵을 짓고 생존자를 스폰에 세워 잠가요. 이때부터 리셋·사망은 탈락이에요.
		local prepared = RoundService.prepareRound({
			roomId = roomId,
			players = alivePlayers(ctx),
			map = map,
			roundIndex = roundIndex,
			roundCount = roundCount,
			standings = ctx.standings,
			onEliminated = function(userId: number)
				ctx.aliveUserIds[userId] = nil
			end,
		})
		ctx.round = prepared
		task.wait(Config.Match.IntroDuration)

		if aliveCount(ctx) < minAlive then
			prepared.cancel() -- 소개 보여주는 사이에 인원이 줄어서 이미 승부가 났어요
			ctx.round = nil
			break
		end
		if roundToPlay(roundIndex) ~= roundIndex then
			prepared.cancel() -- 소개 중 이탈로 2명 이하가 됐어요: 이 라운드 대신 결승 소개부터 다시 해요
			ctx.round = nil
			continue
		end
		-- 통과 인원은 출발하는 순간 살아 있는 인원으로 계산해요 (GDD 4.1, Q6)
		local targetCount = Rules.qualifyCount(aliveCount(ctx), roundCount, roundIndex)

		broadcast(ctx, {
			phase = "RoundActive",
			endsAt = workspace:GetServerTimeNow() + timeLimit,
			roundIndex = roundIndex,
			roundCount = roundCount,
			mapId = map.id,
			mapName = map.displayName,
			mapKind = map.kind,
			rule = map.rule,
		})
		MatchEvents.fireRoundStart(roomId, roundIndex, roundCount, aliveList(ctx))
		prepared.run(targetCount) -- 잠금 해제와 map.start가 이 방송과 같은 순간이에요
		ctx.round = nil

		-- 결승 전 라운드가 끝났는데 생존자가 1명 이하면(나머지가 리셋·퇴장) 결과 단계 없이 바로
		-- 부전승 Won → Victory로 가요 (m2-07 결정). 강제 플랜(디버그)은 혼자여도 끝까지 돌아요.
		if not isForced and roundIndex < roundCount and aliveCount(ctx) <= 1 then
			break
		end

		broadcast(ctx, {
			phase = "RoundResults",
			endsAt = workspace:GetServerTimeNow() + Config.Match.ResultsDuration,
			roundIndex = roundIndex,
			roundCount = roundCount,
		})
		task.wait(Config.Match.ResultsDuration)

		roundIndex = nextRound(roundIndex)
	end

	-- 우승자는 Won을 받은 사람뿐이에요 (m2-05 QA F1). 결승 없이 생존자가 1명이 되면(나머지가 리셋·퇴장,
	-- 소개 중 이탈, 혼자 시작 등) 그 사람이 부전승 — Won을 보낸 뒤 Victory도 같은 사람으로 보내요.
	-- 생존자가 0명이면 Victory 없이 끝내요.
	local winnerUserId, needsWon = RoundLogic.decideWinner(ctx.standings, aliveList(ctx))
	if winnerUserId and needsWon then
		EliminationService.won(roomId, winnerUserId)
	end

	local standings = RoundLogic.standingsList(ctx.standings)
	local lines = {}
	for _, row in standings do
		table.insert(lines, `{row.place}. {row.name} ({row.userId})`)
	end
	print(`[MatchService] room {roomId} standings: {table.concat(lines, ", ")}`)

	if winnerUserId then
		broadcast(ctx, {
			phase = "Victory",
			endsAt = workspace:GetServerTimeNow() + Config.Match.VictoryDuration,
			winnerUserId = winnerUserId,
			standings = standings,
		})
		-- Victory 방송 직후: 우승 연출·순위표 10초 동안 보상 정산을 보여 줄 수 있게 (m4-08)
		fireMatchEnd(ctx, winnerUserId, standings)
		task.wait(Config.Match.VictoryDuration)
		fireWinnerShowcase(ctx, winnerUserId)
	else
		fireMatchEnd(ctx, nil, standings)
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
			local ctx = matches[room.id]
			if ctx and ctx.round then
				pcall(ctx.round.cancel) -- 소개 중이던 맵이 남지 않게 치워요
			end
			if ctx then
				-- 아직 안 보냈으면 우승자 없이 끝난 것으로 알려요 (매치당 한 번)
				pcall(fireMatchEnd, ctx, nil, RoundLogic.standingsList(ctx.standings))
			end
			sendHome(room.id) -- 아레나에 남은 캐릭터를 로비로 돌려보내요
			matches[room.id] = nil
			RoomService.endMatch(room.id)
		end
	end)

	RoomService.onMemberLeft(function(roomId: string, player: Player)
		local ctx = matches[roomId]
		local userId = player.UserId
		local wasAlive = ctx ~= nil and ctx.aliveUserIds[userId] == true
		if ctx then
			ctx.aliveUserIds[userId] = nil
		end
		-- 이번 라운드 레이서면 RoundService가 탈락(등수)을 처리해요. 아니면(라운드 사이, 이미 통과)
		-- 여기서 남은 가장 나쁜 등수를 줘요. 순위표에 나간 사람도 자기 등수로 남아요.
		local handled = RoundService.handlePlayerLeft(roomId, player)
		if ctx and wasAlive and not handled and RoundLogic.placeOf(ctx.standings, userId) == nil then
			local place = RoundLogic.placeEliminated(ctx.standings, userId)
			EliminationService.left(roomId, userId, place)
		end
		-- 방만 나가고 게임에는 남은 사람은 아레나에 두지 않고 바로 로비로 보내요
		if ctx and player.Parent then
			CharacterUtil.toLobby(player)
		end
	end)
end

return MatchService
