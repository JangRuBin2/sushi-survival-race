--!strict
-- 라운드 하나: 맵 짓기 → 배치 → 시작 → 통과/탈락 판정 → 결과 (GDD 5)
-- 맵 모듈은 Shared.maps의 공통 인터페이스(MapTypes.MapModule)를 따라요.
-- 라운드 상태는 이 모듈 전역이 아니라 runRound 호출마다 생기는 지역 컨텍스트에 둬요
-- (한 서버에서 여러 방이 동시에 라운드를 돌릴 수 있어요). 방마다 지금 도는 라운드 하나의
-- "플레이어 제거" 콜백만 activeRemovers에 담아 둬서, 매치 중 누가 방을 나가면 MatchService가 불러요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Maps = require(ReplicatedStorage.Shared.maps)
local MapTypes = require(ReplicatedStorage.Shared.maps.MapTypes)
local Rules = require(ReplicatedStorage.Shared.Rules)

local CharacterUtil = require(script.Parent.CharacterUtil)
local EliminationService = require(script.Parent.EliminationService)
local RoomService = require(script.Parent.RoomService)

local RoundService = {}

export type RoundResult = {
	qualifiedUserIds: { number }, -- 통과 순서대로
	eliminatedUserIds: { number }, -- 탈락 순서대로
}

export type RunRoundArgs = {
	roomId: string,
	players: { Player }, -- 이번 라운드를 뛰는, 지금까지 살아남은 플레이어
	map: MapTypes.MapModule,
	targetCount: number,
	roundIndex: number,
	roundCount: number,
}

local SPAWN_WAIT_TIMEOUT = 5
local SPAWN_LIFT = Vector3.new(0, 3, 0)

local roundProgressEvent: RemoteEvent

-- 방 하나당 지금 돌고 있는 라운드에서 플레이어 한 명을 즉시 탈락 처리하는 함수.
-- 매치 중에 방을 나간 플레이어를 MatchService가 여기로 알려줘요.
local activeRemovers: { [string]: (player: Player) -> () } = {}

local function waitForCharacter(player: Player, timeout: number): Model?
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		return character
	end
	local deadline = os.clock() + timeout
	while player.Parent and os.clock() < deadline do
		character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			return character
		end
		task.wait(0.1)
	end
	return nil
end

local function placeAt(player: Player, spawn: BasePart)
	local character = waitForCharacter(player, SPAWN_WAIT_TIMEOUT)
	if character == nil then
		warn(`[RoundService] {player.Name} has no character to place at round start`)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		CharacterUtil.resetMovement(humanoid)
	end
	character:PivotTo(spawn.CFrame + SPAWN_LIFT)
end

-- 시간 종료 때 못 들어온 플레이어 순위 기준. 코스는 origin의 앞쪽(로컬 -Z)으로 뻗어요
-- (MapTypes 인터페이스 문서 참고). 더 나아간 쪽일수록 로컬 Z가 더 작아요(=음수 쪽으로 커짐).
local function progressOf(origin: CFrame, player: Player): number
	local character = player.Character
	local root = character and (character :: Instance):FindFirstChild("HumanoidRootPart")
	if root == nil then
		return -math.huge
	end
	local relative = origin:PointToObjectSpace((root :: BasePart).Position)
	return -relative.Z
end

-- runRound의 본문. 만든 것은 전부 cleanup에 넣고, 정리는 runRound가 성공/실패와 상관없이 해요.
local function playRound(args: RunRoundArgs, cleanup: Cleanup.Cleanup): RoundResult
	local map = args.map
	local origin = RoomService.getArenaOrigin(args.roomId)
	local model = map.build(origin)
	cleanup:add(model) -- 아래 검사가 실패해도 모델이 남지 않게 Workspace에 넣기 전에 등록해요
	model.Name = `Round{args.roundIndex}_{map.id}`

	local spawnsFolder = model:FindFirstChild("Spawns")
	assert(spawnsFolder, `{map.id}: build() must create a Spawns folder`)
	local spawns = spawnsFolder:GetChildren()
	assert(#spawns > 0, `{map.id}: Spawns folder has no spawn parts`)
	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)
	model.Parent = workspace

	local remaining: { [number]: Player } = {}
	for i, player in args.players do
		remaining[player.UserId] = player
		local spawn = spawns[((i - 1) % #spawns) + 1] :: BasePart
		task.spawn(placeAt, player, spawn)
	end

	local totalRacers = #args.players
	-- 결승은 맵 종류가 아니라 매치의 마지막 라운드예요. 맵 풀이 모자라 Race 맵으로 결승을 돌려도
	-- 1등은 Won을 받아요.
	local isFinal = args.roundIndex == args.roundCount
	local qualified: { number } = {}
	local eliminated: { number } = {}
	local active = true

	local function remainingCount(): number
		local n = 0
		for _ in remaining do
			n += 1
		end
		return n
	end

	local function broadcastProgress()
		local progress: Types.RoundProgress = {
			passed = #qualified,
			target = args.targetCount,
			remaining = remainingCount(),
		}
		for _, player in RoomService.getPlayers(args.roomId) do
			roundProgressEvent:FireClient(player, progress)
		end
	end

	local function finalizeQualified(player: Player)
		remaining[player.UserId] = nil
		table.insert(qualified, player.UserId)
		if isFinal and #qualified == 1 then
			EliminationService.won(player)
		else
			EliminationService.passed(player, #qualified)
		end
	end

	local function finalizeEliminated(player: Player)
		remaining[player.UserId] = nil
		table.insert(eliminated, player.UserId)
		local place = Rules.eliminationPlace(totalRacers, #eliminated)
		EliminationService.eliminate(player, place)
	end

	-- 통과 인원이 목표에 닿았는지, 모두 결판났는지, Survival이면 목표만큼만 남았는지.
	local function roundShouldEnd(): boolean
		if #qualified >= args.targetCount then
			return true
		end
		if remainingCount() == 0 then
			return true
		end
		if map.kind == "Survival" and remainingCount() <= args.targetCount then
			return true
		end
		return false
	end

	local function finish(isTimeout: boolean)
		if not active then
			return
		end
		active = false

		local leftover: { Player } = {}
		for _, player in remaining do
			table.insert(leftover, player)
		end

		if #leftover > 0 then
			if not isTimeout and map.kind == "Survival" then
				-- Survival: 목표 인원만 남을 때까지 버티는 거라, 남은 사람(=살아남은 사람) 전원이 통과예요.
				for _, player in leftover do
					finalizeQualified(player)
				end
			else
				-- 시간 종료: 목표만큼 통과를 못 했으면 가장 멀리 간 순서로 남은 자리를 채워요.
				-- 목표 도달 종료(Race/Final): 결승선을 못 넘은 나머지는 전부 탈락이에요 (GDD 4.1, 5.2).
				-- 탈락자는 못 간 사람부터 처리해서, 더 멀리 간 사람이 더 좋은 등수를 받아요.
				local openSlots = if isTimeout then args.targetCount - #qualified else 0
				local toQualify, toEliminate = Rules.settleLeftover(leftover, function(player: Player)
					return progressOf(origin, player)
				end, openSlots)
				for _, player in toQualify do
					finalizeQualified(player)
				end
				for _, player in toEliminate do
					finalizeEliminated(player)
				end
			end
		end
		broadcastProgress()
	end

	local ctx: MapTypes.RoundContext = {
		model = model,
		origin = origin,
		rng = Random.new(),
		targetCount = args.targetCount,
		cleanup = cleanup,
		isActive = function()
			return active
		end,
		getRacers = function()
			local list = {}
			for _, player in remaining do
				table.insert(list, player)
			end
			return list
		end,
		pass = function(player: Player)
			if not active or remaining[player.UserId] == nil then
				return
			end
			finalizeQualified(player)
			broadcastProgress()
			if roundShouldEnd() then
				finish(false)
			end
		end,
		eliminate = function(player: Player)
			if not active or remaining[player.UserId] == nil then
				return
			end
			finalizeEliminated(player)
			broadcastProgress()
			if roundShouldEnd() then
				finish(false)
			end
		end,
	}

	if map.cleanup then
		local mapCleanup = map.cleanup
		cleanup:add(function()
			local cleanupOk, cleanupErr = pcall(mapCleanup, ctx)
			if not cleanupOk then
				warn(`[RoundService] {map.id} cleanup() failed: {cleanupErr}`)
			end
		end)
	end

	activeRemovers[args.roomId] = function(player: Player)
		if active and remaining[player.UserId] ~= nil then
			finalizeEliminated(player)
			broadcastProgress()
			if roundShouldEnd() then
				finish(false)
			end
		end
	end

	broadcastProgress()
	local startOk, startErr = pcall(map.start, ctx)
	if not startOk then
		warn(`[RoundService] {map.id} start() failed: {startErr}`)
	end

	local timeLimit = Maps.timeLimit(map)
	local deadline = os.clock() + timeLimit
	while active and os.clock() < deadline do
		task.wait(0.2)
	end
	finish(true) -- 이미 끝났으면 아무 일도 안 해요 (finish는 active 가드가 있어요)

	-- 맵이 곧 사라지니까 통과자를 먼저 로비 스폰으로 옮겨요. 결과 단계(·우승 연출) 동안 거기서 기다리다가
	-- 다음 라운드 시작 때 새 맵 스폰으로 옮겨져요. 탈락자는 EliminationService가 따로 돌려보내요.
	for _, userId in qualified do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			CharacterUtil.toLobby(player)
		end
	end

	return { qualifiedUserIds = qualified, eliminatedUserIds = eliminated }
end

-- 라운드 하나를 끝까지 돌리고 결과를 돌려줘요. 도중에 에러가 나도 맵·연결·스레드를 정리하고
-- 방의 플레이어 제거 콜백을 지운 뒤 에러를 다시 던져요 (MatchService가 멤버를 로비로 돌려보내요).
function RoundService.runRound(args: RunRoundArgs): RoundResult
	local cleanup = Cleanup.new()
	local ok, result = pcall(playRound, args, cleanup)
	activeRemovers[args.roomId] = nil
	local cleanupOk, cleanupErr = pcall(cleanup.run, cleanup)
	if not cleanupOk then
		warn(`[RoundService] round cleanup failed: {cleanupErr}`)
	end
	if not ok then
		error(result, 0)
	end
	return result
end

-- 매치 중에 플레이어가 방을 나가면 MatchService가 불러요. 지금 그 방에 도는 라운드가 없으면 아무 일도 안 해요.
function RoundService.handlePlayerLeft(roomId: string, player: Player)
	local remover = activeRemovers[roomId]
	if remover then
		remover(player)
	end
end

function RoundService.init()
	roundProgressEvent = Remotes.event("RoundProgress")
end

function RoundService.start() end

return RoundService
