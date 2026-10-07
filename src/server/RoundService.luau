--!strict
-- 라운드 하나: 맵 짓기 → 배치·이동 잠금(소개 동안) → 동시 출발 → 통과/탈락 판정 → 결과 (GDD 4, 5)
-- 맵 모듈은 Shared.maps의 공통 인터페이스(MapTypes.MapModule)를 따라요.
-- 판정 규칙(종료 조건, 남은 사람 정리, 결승 우승자)은 Shared.RoundLogic의 순수 함수가 정하고,
-- 여기서는 그 결과대로 EliminationService를 부르고 캐릭터를 옮겨요.
--
-- 흐름 (MatchService가 부름)
--   prepareRound(args)  RoundIntro 시작 때. 맵을 짓고 생존자를 스폰에 세운 뒤 움직이지 못하게 잠가요.
--                       이때부터 레이서의 캐릭터가 죽거나 사라지거나 새로 생기면 탈락이에요.
--   handle.run(target)  RoundActive 방송과 동시에. 잠금을 풀고 map.start(ctx)를 부른 뒤 끝날 때까지 기다려요.
--   handle.cancel()     소개 중 인원이 줄어 이 라운드를 건너뛸 때. 맵을 치우고 레이서를 로비 스폰으로 보내요.
--
-- 라운드 상태는 이 모듈 전역이 아니라 prepareRound 호출마다 생기는 지역 상태에 둬요
-- (한 서버에서 여러 방이 동시에 라운드를 돌릴 수 있어요). 방마다 지금 라운드의
-- "플레이어 이탈" 콜백만 activeRemovers에 담아 둬요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Maps = require(ReplicatedStorage.Shared.maps)
local MapTypes = require(ReplicatedStorage.Shared.maps.MapTypes)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

local CharacterUtil = require(script.Parent.CharacterUtil)
local EliminationService = require(script.Parent.EliminationService)
local RoomService = require(script.Parent.RoomService)

local RoundService = {}

export type RoundResult = {
	qualifiedUserIds: { number }, -- 통과 순서대로 (결승이면 우승자)
	eliminatedUserIds: { number }, -- 탈락 순서대로
}

export type PrepareArgs = {
	roomId: string,
	players: { Player }, -- 이번 라운드를 뛰는, 지금까지 살아남은 플레이어
	map: MapTypes.MapModule,
	roundIndex: number,
	roundCount: number,
	standings: RoundLogic.Standings, -- 매치 등수 기록 (MatchService 소유)
	onEliminated: (userId: number) -> (), -- 탈락 즉시 불려요 (MatchService가 생존자에서 빼요)
}

export type PreparedRound = {
	racerCount: () -> number, -- 아직 통과/탈락하지 않은 레이서 수
	run: (targetCount: number) -> RoundResult,
	cancel: () -> (),
}

local SPAWN_WAIT_TIMEOUT = 5
local SPAWN_LIFT = Vector3.new(0, 3, 0)

local roundProgressEvent: RemoteEvent

-- 방 하나당 지금 준비/진행 중인 라운드에서 플레이어 한 명이 나갔을 때 부르는 함수.
-- 그 사람이 이 라운드의 레이서였으면 탈락 처리하고 true를 돌려줘요.
local activeRemovers: { [string]: (player: Player) -> boolean } = {}

local function waitForCharacter(player: Player, timeout: number): Model?
	local deadline = os.clock() + timeout
	while player.Parent do
		-- 라운드 사이에 리셋한 캐릭터는 죽은 채로 잠깐 남아 있어요. 리스폰된 새 캐릭터를 기다려요.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
			return character
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(0.1)
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- 출발 전 이동 잠금 (걷기·점프 0). 풀 때는 CharacterUtil.resetMovement.
local function lockMovement(humanoid: Humanoid)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.PlatformStand = false
	humanoid.Jump = false
end

-- 라운드를 준비해요: 맵 짓기, 배치·잠금, 리셋 감시. 에러가 나면 만든 것을 치우고 다시 던져요.
function RoundService.prepareRound(args: PrepareArgs): PreparedRound
	local roomId = args.roomId
	local map = args.map
	local cleanup = Cleanup.new()
	local closed = false -- run이 끝났거나 cancel됐어요

	local function close()
		if closed then
			return
		end
		closed = true
		if activeRemovers[roomId] then
			activeRemovers[roomId] = nil
		end
		local cleanupOk, cleanupErr = pcall(cleanup.run, cleanup)
		if not cleanupOk then
			warn(`[RoundService] round cleanup failed: {cleanupErr}`)
		end
	end

	local ok, handleOrErr = pcall(function(): PreparedRound
		local origin = RoomService.getArenaOrigin(roomId)
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

		-- 결승은 맵 종류가 아니라 매치의 마지막 라운드예요 (B8).
		local isFinal = args.roundIndex == args.roundCount
		local mode = RoundLogic.modeFor(map.kind, isFinal)
		local playersById: { [number]: Player } = {}
		local ids: { number } = {}
		for _, player in args.players do
			playersById[player.UserId] = player
			table.insert(ids, player.UserId)
		end
		local round = RoundLogic.newRound(mode, ids, Random.new())
		local released = false -- 출발했으면 늦게 배치되는 사람도 잠그지 않아요
		local qualified: { number } = {}
		local eliminated: { number } = {}

		-- 점수가 클수록 잘한 거예요. Race 맵은 코스 진행도(origin의 로컬 -Z, MapTypes 문서),
		-- 그 밖(Survival·결승)은 높이. 캐릭터가 없으면 가장 낮은 점수.
		local scoreByProgress = map.kind == "Race"
		local function scoreOf(userId: number): number
			local player = playersById[userId]
			local root = player and rootOf(player)
			if root == nil then
				return -math.huge
			end
			if scoreByProgress then
				return -origin:PointToObjectSpace(root.Position).Z
			end
			return root.Position.Y
		end

		local function broadcastProgress()
			if not (round.active or round.ended) then
				return -- 소개 중에는 목표 인원이 아직 없어요. 출발할 때 한 번 보내요.
			end
			local racerUserIds = RoundLogic.racers(round)
			local progress: Types.RoundProgress = {
				passed = round.passedCount,
				target = round.target or 0,
				remaining = #racerUserIds,
				racerUserIds = racerUserIds,
			}
			for _, player in RoomService.getPlayers(roomId) do
				roundProgressEvent:FireClient(player, progress)
			end
		end

		-- RoundLogic 결과를 매치 등수로 바꿔서 발표하고 캐릭터를 옮겨요.
		local function apply(outcomes: { RoundLogic.Outcome })
			if #outcomes == 0 then
				return
			end
			for _, outcome in RoundLogic.applyOutcomes(args.standings, outcomes) do
				local userId = outcome.userId
				local player = playersById[userId]
				local place = outcome.place :: number
				local inGame = player ~= nil and player.Parent ~= nil
				if outcome.result == "Eliminated" then
					table.insert(eliminated, userId)
					if inGame and RoomService.getRoomIdOf(player :: Player) == roomId then
						EliminationService.eliminate(roomId, player :: Player, place)
					else
						EliminationService.left(roomId, userId, place)
					end
					args.onEliminated(userId)
				elseif outcome.result == "Won" then
					table.insert(qualified, userId)
					EliminationService.won(roomId, userId)
				else
					table.insert(qualified, userId)
					-- 통과자는 바로 코스 밖 대기석(로비 스폰, B1과 같은 곳)으로. 아직 달리는 사람을 막지 못해요.
					if player then
						EliminationService.passed(roomId, player, place)
						if inGame then
							CharacterUtil.toLobby(player)
						end
					end
				end
			end
			broadcastProgress()
		end

		-- 같은 프레임에 들어온 탈락은 모아서 한 번에 판정해요 (결승 동시 낙하 = 높이 순).
		local pending: { RoundLogic.Fall } = {}
		local pendingIds: { [number]: boolean } = {}
		local flushScheduled = false

		local function flush()
			flushScheduled = false
			if #pending == 0 then
				return
			end
			local falls = pending
			pending = {}
			pendingIds = {}
			if closed then
				return
			end
			apply(RoundLogic.eliminate(round, falls, scoreOf))
		end

		local function queueFall(userId: number, score: number?)
			if closed or round.ended or pendingIds[userId] or not RoundLogic.isRacing(round, userId) then
				return
			end
			pendingIds[userId] = true
			table.insert(pending, { userId = userId, score = score or scoreOf(userId) })
			if not flushScheduled then
				flushScheduled = true
				task.defer(flush)
			end
		end

		-- 라운드 중 캐릭터 사망/제거/교체 = 탈락. 배치가 끝난 뒤부터 봐요
		-- (라운드 사이에 리셋해서 리스폰 중이던 캐릭터가 나타나는 건 탈락이 아니에요).
		local function watch(player: Player, character: Model)
			local userId = player.UserId
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				cleanup:add(humanoid.Died:Connect(function()
					queueFall(userId)
				end))
			end
			cleanup:add(character.AncestryChanged:Connect(function()
				if not character:IsDescendantOf(game) then
					queueFall(userId, -math.huge)
				end
			end))
			cleanup:add(player.CharacterAdded:Connect(function()
				queueFall(userId, -math.huge)
			end))
		end

		local function placeAt(player: Player, spawn: BasePart)
			local character = waitForCharacter(player, SPAWN_WAIT_TIMEOUT)
			if closed or not RoundLogic.isRacing(round, player.UserId) then
				return
			end
			if character == nil then
				warn(`[RoundService] {player.Name} has no character to place at round start`)
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			if released then
				CharacterUtil.resetMovement(humanoid)
			else
				lockMovement(humanoid)
			end
			character:PivotTo(spawn.CFrame + SPAWN_LIFT)
			watch(player, character)
		end

		for i, player in args.players do
			local spawn = spawns[((i - 1) % #spawns) + 1] :: BasePart
			cleanup:add(task.spawn(placeAt, player, spawn))
		end

		local ctx: MapTypes.RoundContext = {
			model = model,
			origin = origin,
			rng = Random.new(),
			targetCount = 0, -- run에서 정해요
			cleanup = cleanup,
			isActive = function()
				return round.active and not round.ended and not closed
			end,
			getRacers = function()
				local list = {}
				for _, userId in RoundLogic.racers(round) do
					local player = playersById[userId]
					if player and not pendingIds[userId] then
						table.insert(list, player)
					end
				end
				return list
			end,
			pass = function(player: Player)
				if closed or not round.active or not RoundLogic.isRacing(round, player.UserId) then
					return
				end
				flush() -- 같은 프레임에 먼저 떨어진 사람부터 판정해요
				apply(RoundLogic.pass(round, player.UserId, scoreOf))
			end,
			eliminate = function(player: Player)
				queueFall(player.UserId)
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

		activeRemovers[roomId] = function(player: Player): boolean
			if RoundLogic.isRacing(round, player.UserId) then
				queueFall(player.UserId, -math.huge)
				return true
			end
			return pendingIds[player.UserId] == true
		end

		local function playRound(targetCount: number): RoundResult
			ctx.targetCount = targetCount
			flush() -- 소개 중에 들어온 탈락을 먼저 처리해요
			RoundLogic.activate(round, targetCount)
			released = true
			for _, userId in RoundLogic.racers(round) do
				local player = playersById[userId]
				local character = player and player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					CharacterUtil.resetMovement(humanoid)
				end
			end
			broadcastProgress()

			if not round.ended then
				local startOk, startErr = pcall(map.start, ctx)
				if not startOk then
					warn(`[RoundService] {map.id} start() failed: {startErr}`)
				end
			end

			local deadline = os.clock() + Maps.timeLimit(map)
			while not round.ended and os.clock() < deadline do
				task.wait(0.2)
			end
			flush()
			apply(RoundLogic.timeout(round, scoreOf)) -- 이미 끝났으면 빈 목록이에요

			-- 맵이 곧 사라지니까 통과자·우승자를 로비 스폰으로 옮겨요. 결과 단계(·우승 연출) 동안 거기서
			-- 기다리다가 다음 라운드 소개 때 새 맵 스폰으로 옮겨져요. 탈락자는 EliminationService가 돌려보내요.
			for _, userId in qualified do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					CharacterUtil.toLobby(player)
				end
			end
			return { qualifiedUserIds = qualified, eliminatedUserIds = eliminated }
		end

		return {
			racerCount = function()
				local n = 0
				for _, userId in RoundLogic.racers(round) do
					if not pendingIds[userId] then
						n += 1
					end
				end
				return n
			end,
			run = function(targetCount: number): RoundResult
				assert(not closed, "round already closed")
				local runOk, result = pcall(playRound, targetCount)
				close()
				if not runOk then
					error(result, 0)
				end
				return result
			end,
			cancel = function()
				if closed then
					return
				end
				flush()
				close()
				for _, userId in RoundLogic.racers(round) do
					local player = playersById[userId]
					if player and player.Parent then
						CharacterUtil.toLobby(player) -- 이동 잠금도 풀어요
					end
				end
			end,
		}
	end)

	if not ok then
		close()
		error(handleOrErr, 0)
	end
	return handleOrErr
end

-- 매치 중에 플레이어가 방을 나가면 MatchService가 불러요. 지금 그 방의 라운드 레이서였으면
-- 탈락 처리하고 true, 아니면(라운드 없음·이미 통과) false.
function RoundService.handlePlayerLeft(roomId: string, player: Player): boolean
	local remover = activeRemovers[roomId]
	if remover then
		return remover(player)
	end
	return false
end

function RoundService.init()
	roundProgressEvent = Remotes.event("RoundProgress")
end

function RoundService.start() end

return RoundService
