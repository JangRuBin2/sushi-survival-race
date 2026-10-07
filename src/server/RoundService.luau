--!strict
-- 라운드 하나: 맵 짓기 → 배치 → 시작 → 통과/탈락 판정 → 결과 (GDD 5)
-- 맵 모듈은 Shared.maps의 공통 인터페이스(MapTypes.MapModule)를 따라요.
-- 라운드 상태는 이 모듈 전역이 아니라 runRound 호출마다 생기는 지역 컨텍스트에 둬요
-- (한 서버에서 여러 방이 동시에 라운드를 돌릴 수 있어요). 방마다 지금 도는 라운드 하나의
-- "플레이어 제거" 콜백만 activeRemovers에 담아 둬서, 매치 중 누가 방을 나가면 MatchService가 불러요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Maps = require(ReplicatedStorage.Shared.maps)
local MapTypes = require(ReplicatedStorage.Shared.maps.MapTypes)

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
		humanoid.WalkSpeed = Config.Character.WalkSpeed
		humanoid.PlatformStand = false
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

function RoundService.runRound(args: RunRoundArgs): RoundResult
	local map = args.map
	local origin = RoomService.getArenaOrigin(args.roomId)
	local model = map.build(origin)
	model.Name = `Round{args.roundIndex}_{map.id}`
	model.Parent = workspace

	local spawnsFolder = model:FindFirstChild("Spawns")
	assert(spawnsFolder, `{map.id}: build() must create a Spawns folder`)
	local spawns = spawnsFolder:GetChildren()
	assert(#spawns > 0, `{map.id}: Spawns folder has no spawn parts`)
	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)

	local cleanup = Cleanup.new()
	cleanup:add(model)

	local remaining: { [number]: Player } = {}
	for i, player in args.players do
		remaining[player.UserId] = player
		local spawn = spawns[((i - 1) % #spawns) + 1] :: BasePart
		task.spawn(placeAt, player, spawn)
	end

	local totalRacers = #args.players
	local isFinal = map.kind == "Final"
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
		local place = totalRacers - #eliminated + 1
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
			if isTimeout then
				-- 시간이 끝났는데 목표만큼 통과를 못 했으면, 가장 멀리 간 순서로 나머지 자리를 채워요.
				table.sort(leftover, function(a, b)
					return progressOf(origin, a) > progressOf(origin, b)
				end)
				local neededMore = math.max(args.targetCount - #qualified, 0)
				for i, player in leftover do
					if i <= neededMore then
						finalizeQualified(player)
					else
						finalizeEliminated(player)
					end
				end
			elseif map.kind == "Survival" then
				-- Survival: 목표 인원만 남을 때까지 버티는 거라, 남은 사람(=살아남은 사람) 전원이 통과예요.
				for _, player in leftover do
					finalizeQualified(player)
				end
			else
				-- Race/Final: 결승선에 목표 인원이 들어오면 그 자리에서 끝나요 (GDD 5.2).
				-- 아직 결승선을 못 넘은 나머지는 탈락이에요 (GDD 4.1: 매 라운드 최소 1명은 꼭 탈락).
				for _, player in leftover do
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

	activeRemovers[args.roomId] = nil
	if map.cleanup then
		local cleanupOk, cleanupErr = pcall(map.cleanup, ctx)
		if not cleanupOk then
			warn(`[RoundService] {map.id} cleanup() failed: {cleanupErr}`)
		end
	end
	cleanup:run()

	return { qualifiedUserIds = qualified, eliminatedUserIds = eliminated }
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
