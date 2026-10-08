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
--                       기다리는 시간은 RoundLogic.schedule: 결승이면 시간 제한에 map.overtime(ctx, info)을 한 번
--                       부르고(연장전, RoundProgress.overtime/collapseAt), 안전 상한에 높이 순으로 끝내요 (m5-01).
--   handle.cancel()     소개 중 인원이 줄어 이 라운드를 건너뛸 때. 맵을 치우고 레이서를 로비 스폰으로 보내요.
--
-- 라운드 상태는 이 모듈 전역이 아니라 prepareRound 호출마다 생기는 지역 상태에 둬요
-- (한 서버에서 여러 방이 동시에 라운드를 돌릴 수 있어요). 방마다 지금 라운드의
-- "플레이어 이탈" 콜백(activeRemovers)과 "지금 달리는 중인가" 질의(activeRacing)만 담아 둬요.
--
-- 탈락 발표(PlayerResult)에는 연출용 cause·position을 채워요 (m3-01):
--   ctx.eliminate(맵 낙하) = "Fall"(위치는 마지막으로 땅을 밟은 곳, m4-01), 사망·캐릭터 교체·캐릭터 없음 = "Reset",
--   방/게임을 나감 = "Left"(EliminationService.left), 시간 종료·통과 인원이 다 차서 남은 사람의 탈락 = "Timeout"(m3-09).
-- 결승에서 탈락과 우승이 같은 묶음으로 나오면(마지막 낙하 등) 탈락 연출(Config.Match.EliminationCutscene)이
-- 끝날 때까지 기다렸다가 Won을 보내요. 그 뒤 MatchService가 바로 Victory로 가요 (m3-03 QA B1, m3-09).
-- 맵 Model에는 Workspace에 넣기 전에 Attributes.RoomId/RoundIndex/MapId를 달아요 (클라이언트가 자기 방 맵을 찾음).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Maps = require(ReplicatedStorage.Shared.maps)
local MapSfx = require(ReplicatedStorage.Shared.maps.MapSfx)
local MapSfxLogic = require(ReplicatedStorage.Shared.maps.MapSfxLogic)
local MapTypes = require(ReplicatedStorage.Shared.maps.MapTypes)
local MoveExempt = require(ReplicatedStorage.Shared.MoveExempt)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Rules = require(ReplicatedStorage.Shared.Rules)

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
local GROUND_SAMPLE = 0.1 -- 마지막으로 땅을 밟은 위치를 기록하는 간격(초)

local roundProgressEvent: RemoteEvent

-- 결승선 통과를 받기 전에 묻는 함수 (m4-01 setPassValidator, m4-10 이동 감시가 등록). 하나만.
local passValidator: ((player: Player) -> boolean)? = nil

-- 등록된 검사가 없거나 true면 통과를 받아요. 검사가 에러 나면 통과를 막지 않아요(경고만).
local function passAllowed(player: Player): boolean
	local validator = passValidator
	if validator == nil then
		return true
	end
	local ok, allowed = pcall(validator, player)
	if not ok then
		warn(`[RoundService] pass validator failed: {allowed}`)
		return true
	end
	return allowed ~= false
end

-- 레이서를 스폰에 배치한 순간 알려 받을 함수 (m4-10 이동 감시가 기준점을 스폰으로 잡아요). 하나만.
export type PlacementListener = (player: Player, character: Model, position: Vector3) -> ()
local placementListener: PlacementListener? = nil

local function notifyPlaced(player: Player, character: Model, position: Vector3)
	local listener = placementListener
	if listener == nil then
		return
	end
	local ok, err = pcall(listener, player, character, position)
	if not ok then
		warn(`[RoundService] placement listener failed: {err}`)
	end
end

-- 방 하나당 지금 준비/진행 중인 라운드에서 플레이어 한 명이 나갔을 때 부르는 함수.
-- 그 사람이 이 라운드의 레이서였으면 탈락 처리하고 true를 돌려줘요.
local activeRemovers: { [string]: (player: Player) -> boolean } = {}

-- 방 하나당 지금 라운드에서 그 userId가 "출발한 라운드에서 스폰에 배치된 채 아직 달리는 중"인지.
local activeRacing: { [string]: (userId: number) -> boolean } = {}
-- 소개 중 포함, 스폰에 배치돼 아직 통과·탈락하지 않은 레이서인가 (m4-10 이동 감시).
local placedRacing: { [string]: (userId: number) -> boolean } = {}

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
		if activeRacing[roomId] then
			activeRacing[roomId] = nil
		end
		if placedRacing[roomId] then
			placedRacing[roomId] = nil
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
		table.sort(spawns, function(a: Instance, b: Instance): boolean
			return a.Name < b.Name
		end)
		model:SetAttribute(Attributes.RoomId, roomId)
		model:SetAttribute(Attributes.RoundIndex, args.roundIndex)
		model:SetAttribute(Attributes.MapId, map.id)
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
		local roundRng: Rules.Rng = Random.new()
		local round = RoundLogic.newRound(mode, ids, roundRng)
		local released = false -- 출발했으면 늦게 배치되는 사람도 잠그지 않아요
		local qualified: { number } = {}
		local eliminated: { number } = {}
		-- 스폰에 배치가 끝난 레이서. 맵(getRacers)에는 배치된 사람만 보여요 — 라운드 시작 순간
		-- 리스폰 중이라 아직 로비에 있는 캐릭터를 맵이 "떨어졌다"고 판정하지 않게 해요 (QA N1/H1/B2/W1).
		local placed: { [number]: boolean } = {}
		-- 낙하·리셋으로 탈락 대기열에 들어간 사람의 사유와 위치 (PlayerResult.cause/position)
		local causeOf: { [number]: RoundLogic.FallCause } = {}
		local positionOf: { [number]: Vector3 } = {}
		-- 배치된 레이서가 마지막으로 땅을 밟고 있던 HumanoidRootPart 위치 (GROUND_SAMPLE 간격, 낙하 탈락 연출 위치)
		local lastGroundOf: { [number]: Vector3 } = {}

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

		-- 결승 연장전 중이면 바닥이 다 사라지는 시각 (workspace:GetServerTimeNow() 기준, m5-01). 연장전 전·결승 밖은 nil.
		local overtimeCollapseAt: number? = nil

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
				overtime = if overtimeCollapseAt ~= nil then true else nil,
				collapseAt = overtimeCollapseAt,
			}
			for _, player in RoomService.getPlayers(roomId) do
				roundProgressEvent:FireClient(player, progress)
			end
		end

		-- 결승 마지막 탈락 연출이 끝난 뒤 보낼 우승자 (playRound가 기다렸다가 보내요)
		local deferredWonUserId: number? = nil

		-- RoundLogic 결과를 매치 등수로 바꿔서 발표하고 캐릭터를 옮겨요.
		local function apply(outcomes: { RoundLogic.Outcome })
			if #outcomes == 0 then
				return
			end
			-- 같은 묶음에 연출이 나오는 탈락(방에 남아 있는 사람)이 있으면 우승 발표를 연출 뒤로 미뤄요.
			-- 출발 전(소개 중 취소 등)에는 playRound가 돌지 않으니 미루지 않아요.
			local delayWon = false
			for _, outcome in outcomes do
				local player = playersById[outcome.userId]
				if
					outcome.result == "Eliminated"
					and player ~= nil
					and player.Parent ~= nil
					and RoomService.getRoomIdOf(player) == roomId
				then
					delayWon = released
				end
			end
			for _, outcome in RoundLogic.applyOutcomes(args.standings, outcomes) do
				local userId = outcome.userId
				local player = playersById[userId]
				local place = outcome.place :: number
				local inGame = player ~= nil and player.Parent ~= nil
				if outcome.result == "Eliminated" then
					table.insert(eliminated, userId)
					if inGame and RoomService.getRoomIdOf(player :: Player) == roomId then
						EliminationService.eliminate(
							roomId,
							player :: Player,
							place,
							causeOf[userId] or "Timeout", -- 낙하·리셋이 아니면 시간 종료·정원 마감
							positionOf[userId]
						)
					else
						EliminationService.left(roomId, userId, place)
					end
					args.onEliminated(userId)
				elseif outcome.result == "Won" then
					table.insert(qualified, userId)
					if delayWon then
						deferredWonUserId = userId
					else
						EliminationService.won(roomId, userId)
					end
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

		-- cause: "Fall"(맵의 낙하 판정, 결승 진출 2명 보장의 구제 대상) / "Reset"(리셋·사망·퇴장·캐릭터 없음)
		-- position: 탈락 순간 HumanoidRootPart 위치 (연출용). nil이면 지금 캐릭터 위치를 써요.
		-- knownCharacter: 이 캐릭터의 감시에서 온 탈락이면 true — 그때는 지금 player.Character(리스폰된 새 캐릭터일 수
		-- 있음)의 위치로 채우지 않아요 (m3-01 QA B2). 모르면 position nil → 연출은 스탬프만.
		local function queueFall(
			userId: number,
			score: number?,
			cause: RoundLogic.FallCause,
			position: Vector3?,
			knownCharacter: boolean?
		)
			if closed or round.ended or pendingIds[userId] or not RoundLogic.isRacing(round, userId) then
				return
			end
			pendingIds[userId] = true
			causeOf[userId] = cause
			if position == nil and cause == "Fall" then
				-- 낙하는 판정 순간(코스 20~40 studs 아래) 대신 마지막으로 땅을 밟은 위치 (m4-01, m3-03 B2)
				position = lastGroundOf[userId]
			end
			if position == nil and not knownCharacter then
				local player = playersById[userId]
				local root = player and rootOf(player)
				position = root and root.Position
			end
			positionOf[userId] = position
			table.insert(pending, { userId = userId, score = score or scoreOf(userId), cause = cause })
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
			-- 이 캐릭터(새 캐릭터 말고)의 마지막 위치
			local function lastPosition(): Vector3?
				local root = character:FindFirstChild("HumanoidRootPart")
				return if root and root:IsA("BasePart") then root.Position else nil
			end
			if humanoid then
				cleanup:add(humanoid.Died:Connect(function()
					queueFall(userId, nil, "Reset", lastPosition(), true)
				end))
			end
			cleanup:add(character.AncestryChanged:Connect(function()
				if not character:IsDescendantOf(game) then
					queueFall(userId, -math.huge, "Reset", lastPosition(), true)
				end
			end))
			cleanup:add(player.CharacterAdded:Connect(function()
				queueFall(userId, -math.huge, "Reset", lastPosition(), true)
			end))
		end

		local function placeAt(player: Player, spawn: BasePart)
			local character = waitForCharacter(player, SPAWN_WAIT_TIMEOUT)
			if closed or not RoundLogic.isRacing(round, player.UserId) then
				return
			end
			if character == nil then
				-- 캐릭터가 끝내 안 생기면 감시도 배치도 못 하니 탈락이에요 (m2-05 QA F3).
				-- 그대로 두면 Survival 시간 종료에 "버틴 사람"으로 통과해 버려요.
				warn(`[RoundService] {player.Name} has no character to place at round start; eliminating`)
				queueFall(player.UserId, -math.huge, "Reset")
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
			MoveExempt.mark(character) -- 서버가 옮겼어요: 이동 감시(m4-10) 오탐 방지
			character:PivotTo(spawn.CFrame + SPAWN_LIFT)
			notifyPlaced(player, character, (spawn.CFrame + SPAWN_LIFT).Position)
			lastGroundOf[player.UserId] = nil
			watch(player, character)
			placed[player.UserId] = true
		end

		-- 이동 감시(m4-10)가 배치 알림 직후부터 물어요: 배치 전에 등록해 둬요.
		placedRacing[roomId] = function(userId: number): boolean
			return not round.ended
				and not closed
				and placed[userId] == true
				and not pendingIds[userId]
				and RoundLogic.isRacing(round, userId)
		end
		for i, player in args.players do
			local spawn = spawns[((i - 1) % #spawns) + 1] :: BasePart
			cleanup:add(task.spawn(placeAt, player, spawn))
		end

		-- 마지막으로 땅을 밟은 위치 기록 (m4-01, m3-03 B2). 배치된 레이서만, 라운드가 닫히면 멈춰요.
		cleanup:add(task.spawn(function()
			while not closed do
				for _, userId in RoundLogic.racers(round) do
					local player = playersById[userId]
					if player and placed[userId] and not pendingIds[userId] then
						local character = player.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						local root = rootOf(player)
						if humanoid and root and humanoid.FloorMaterial ~= Enum.Material.Air then
							lastGroundOf[userId] = root.Position
						end
					end
				end
				task.wait(GROUND_SAMPLE)
			end
		end))

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
					if player and placed[userId] and not pendingIds[userId] then
						table.insert(list, player)
					end
				end
				return list
			end,
			pass = function(player: Player)
				if closed or not round.active or not RoundLogic.isRacing(round, player.UserId) then
					return
				end
				if not passAllowed(player) then
					return -- 이동 감시(m4-10) 등이 막은 통과는 무시해요. 계속 달려요.
				end
				flush() -- 같은 프레임에 먼저 떨어진 사람부터 판정해요
				apply(RoundLogic.pass(round, player.UserId, scoreOf))
			end,
			eliminate = function(player: Player)
				if placed[player.UserId] then -- 배치 전 캐릭터(로비 위치)의 낙하 판정은 무시해요
					queueFall(player.UserId, nil, "Fall")
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

		activeRemovers[roomId] = function(player: Player): boolean
			if RoundLogic.isRacing(round, player.UserId) then
				queueFall(player.UserId, -math.huge, "Reset")
				return true
			end
			return pendingIds[player.UserId] == true
		end

		activeRacing[roomId] = function(userId: number): boolean
			return round.active
				and not round.ended
				and not closed
				and placed[userId] == true
				and not pendingIds[userId]
				and RoundLogic.isRacing(round, userId)
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

			local startedAt = os.clock()
			if not round.ended then
				local startOk, startErr = pcall(map.start, ctx)
				if not startOk then
					warn(`[RoundService] {map.id} start() failed: {startErr}`)
				end
			end

			-- 시간 일정 (m5-01): Race·Survival은 시간 제한에 끝, 결승은 시간 제한에 연장전 → 안전 상한에 끝.
			-- 결승 맵에 overtime 훅이 없으면(디버그 강제 플랜으로 Race 맵이 결승 등) 연장전 없이 시간 제한에
			-- 예전처럼 높이 순으로 끝내요 (m5-01 QA B2).
			local overtimeOverride: number? = if RunService:IsStudio() then Config.DEBUG.overtimeAt else nil
			local overtimeHook = map.overtime
			local schedule = RoundLogic.schedule(
				mode,
				Maps.timeLimit(map),
				Config.Final,
				overtimeOverride,
				type(overtimeHook) == "function"
			)
			local overtimeStarted = false
			while not round.ended do
				local elapsed = os.clock() - startedAt
				local action = RoundLogic.loopAction(schedule, elapsed, overtimeStarted)
				if action == "Expire" then
					break
				end
				if action == "StartOvertime" then
					overtimeStarted = true
					local collapseAt = schedule.collapseAt or elapsed
					overtimeCollapseAt = workspace:GetServerTimeNow() + math.max(collapseAt - elapsed, 0)
					if overtimeHook then
						local hook = overtimeHook
						local info: MapTypes.OvertimeInfo = { collapseDuration = Config.Final.CollapseDuration }
						-- 훅이 기다려도(yield) 이 루프와 안전 상한은 멈추지 않게 따로 돌려요 (m5-01 QA B1).
						-- 라운드가 끝나면 cleanup이 아직 도는 훅 스레드를 멈춰요.
						cleanup:add(task.spawn(function()
							local overtimeOk, overtimeErr = pcall(hook, ctx, info)
							if not overtimeOk then
								-- 판정은 안전 상한(Config.Final.HardCapMargin)이 마무리해요
								warn(`[RoundService] {map.id} overtime() failed: {overtimeErr}`)
							end
						end))
					end
					broadcastProgress()
				end
				task.wait(0.2)
			end
			flush()
			apply(RoundLogic.timeout(round, scoreOf)) -- 이미 끝났으면 빈 목록이에요

			-- 결승 마지막 탈락 연출을 다 보여 준 뒤 우승 발표 (그동안 맵·우승자는 그대로 둬요)
			local wonUserId = deferredWonUserId
			if wonUserId ~= nil then
				deferredWonUserId = nil
				task.wait(Config.Match.EliminationCutscene)
				EliminationService.won(roomId, wonUserId)
			end

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
				-- 아직 달리는 사람과, 소개 중에 이미 통과·우승한 사람(결승 소개 중 상대가 나가 우승 등,
				-- m2-05 QA F2) 모두 로비로 보내요. 이동 잠금도 풀어요.
				local toMove = RoundLogic.racers(round)
				table.move(qualified, 1, #qualified, #toMove + 1, toMove)
				for _, userId in toMove do
					local player = playersById[userId]
					if player and player.Parent then
						CharacterUtil.toLobby(player)
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

-- 맵이 ctx.pass(player)를 부를 때 먼저 물어볼 검사를 등록해요 (하나만, m4-10 이동 감시).
-- false를 돌려주면 그 통과는 무시돼요 (통과 처리·방송 없음, 플레이어는 계속 달려요).
-- 결승 진출 2명 보장의 구제 통과(RoundLogic.eliminate 안)는 묻지 않아요.
function RoundService.setPassValidator(fn: (player: Player) -> boolean)
	assert(passValidator == nil, "RoundService.setPassValidator: a validator is already registered")
	passValidator = fn
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

-- 그 플레이어가 지금 출발한(RoundActive) 라운드에서 스폰에 배치된 채 아직 달리는 레이서면 방 id, 아니면 nil.
-- 소개 중·통과·탈락 대기·탈락 뒤·라운드 사이에는 nil이에요 (잡기 m3-07이 씀).
function RoundService.activeRoomOf(player: Player): string?
	local roomId = RoomService.getRoomIdOf(player)
	if roomId == nil then
		return nil
	end
	local isRacing = activeRacing[roomId]
	if isRacing and isRacing(player.UserId) then
		return roomId
	end
	return nil
end

-- 레이서를 스폰에 배치할 때(소개 전·늦은 배치 모두) 부를 함수를 등록해요 (하나만, m4-10 이동 감시).
function RoundService.setPlacementListener(fn: PlacementListener)
	assert(placementListener == nil, "RoundService.setPlacementListener: a listener is already registered")
	placementListener = fn
end

-- 그 플레이어가 지금 라운드(소개 중 포함)에서 스폰에 배치된 채 아직 통과·탈락하지 않았으면 방 id, 아니면 nil.
-- activeRoomOf와 달리 출발 전(소개 중)에도 돌려줘요 (m4-10 이동 감시).
function RoundService.placedRoomOf(player: Player): string?
	local roomId = RoomService.getRoomIdOf(player)
	if roomId == nil then
		return nil
	end
	local isPlaced = placedRacing[roomId]
	if isPlaced and isPlaced(player.UserId) then
		return roomId
	end
	return nil
end

-- 디버그 (Config.DEBUG.logArenaStats, m4-12): 아직 정리되지 않은 라운드 훅 수. 다른 방이 매치 중이 아니면 0이어야 해요.
function RoundService.debugHookCount(): number
	local n = 0
	for _ in activeRemovers do
		n += 1
	end
	for _ in activeRacing do
		n += 1
	end
	for _ in placedRacing do
		n += 1
	end
	return n
end

function RoundService.init()
	roundProgressEvent = Remotes.event("RoundProgress")
	-- 장애물 소리는 그 방 사람에게만 (m3-09 QA B2). 맵 파트는 맵 Model의 RoomId로,
	-- 캐릭터 파트(간장 감속)는 그 플레이어의 방으로 찾아요. 모르면 nil → MapSfx가 모두에게 보내요.
	MapSfx.setAudience(function(part: BasePart): { Player }?
		local roomId = MapSfxLogic.roomIdOf(part, Attributes.RoomId)
		if roomId == nil then
			local character = part:FindFirstAncestorOfClass("Model")
			local owner = character and Players:GetPlayerFromCharacter(character)
			roomId = owner and RoomService.getRoomIdOf(owner)
		end
		if roomId == nil then
			return nil
		end
		return RoomService.getPlayers(roomId :: string)
	end)
end

function RoundService.start() end

return RoundService
