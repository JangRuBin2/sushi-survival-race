--!strict
-- 플레이스 역할과 텔레포트 (GDD 4-1, 4-5, 11.2, m4-11).
--   "Single"  한 플레이스 모드 (Studio 기본, Config.Places가 비어 있음): 아무것도 하지 않아요 — 지금과 같아요.
--   "Lobby"   방이 출발하면 매치 서버를 예약해 매니페스트를 MemoryStore에 쓰고 멤버 전원을 텔레포트해요.
--             매치에서 돌아온 사람(returnTicket)을 같은 방으로 다시 묶고, 단상에 우승자를 세워요(MatchResult).
--             다른 서버 방 목록·참가는 RoomDirectory.
--   "Match"   MemoryStore 매니페스트(키 = PrivateServerId)만 믿어요. 멤버가 다 오거나 ArrivalTimeout이 지나면
--             방을 복원해 바로 매치, 끝나면 MatchResult를 쓰고 남은 멤버 전원을 로비로 (같은 방 복귀 티켓).
--   Studio에서 Config.DEBUG.simulateMatchServer = true면 "Match"를 텔레포트 없이 흉내 내요 (가짜 Backend).
--
-- 데이터 (m4-07 세션 잠금): 텔레포트 직전에 DataService.saveNow로 저장하고, 잠금은 이 서버를 떠날 때
-- (PlayerRemoving) DataService가 풀어요. 도착한 서버는 잠금이 풀릴 때까지 다시 읽어요(LoadRetries).
--
-- API
--   PlaceService.role()                          역할
--   PlaceService.finishMatch(roomId, winner?)    MatchService가 매치 끝에 불러요. 매치 역할이면 처리하고 true
--   PlaceService.setBackend(backend)             (테스트·디버그) 텔레포트·MemoryStore 대체

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local PlacePayload = require(ReplicatedStorage.Shared.PlacePayload)
local PlaceRole = require(ReplicatedStorage.Shared.PlaceRole)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CharacterUtil = require(script.Parent.CharacterUtil)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local PlaceBackend = require(script.Parent.PlaceBackend)
local RoomDirectory = require(script.Parent.RoomDirectory)
local RoomService = require(script.Parent.RoomService)

local PlaceService = {}

export type WinnerInfo = MatchEvents.WinnerShowcaseInfo
type TeleportRequest = PlaceBackend.TeleportRequest
type GiveUp = (player: Player, message: string) -> ()

local MANIFEST_MAP = "MatchManifest"
local RESULT_MAP = "MatchResult"
local STORE_RETRIES = 3 -- 매니페스트·결과 읽기/쓰기 다시 시도 횟수
local RETRY_BATCH_DELAY = 1 -- 텔레포트 실패를 모아서 다시 보내기까지(초) — 같이 실패한 사람은 같이 보내요
local ARRIVAL_POLL = 0.25
local RESTORE_WAIT = 15 -- 같은 방 복원이 끝나기를 기다리는 최대 시간(초)

local backend: PlaceBackend.Backend? = nil
local noticeEvent: RemoteEvent? = nil
local started = false

function PlaceService.role(): PlaceRole.Role
	return PlaceRole.resolve(game.PlaceId, Config.Places, RunService:IsStudio(), Config.DEBUG.simulateMatchServer)
end

local function isSimulated(): boolean
	return RunService:IsStudio() and Config.DEBUG.simulateMatchServer == true
end

function PlaceService.setBackend(newBackend: PlaceBackend.Backend)
	backend = newBackend
end

local function getBackend(): PlaceBackend.Backend
	return backend :: PlaceBackend.Backend
end

local function notice(player: Player, message: string)
	local event = noticeEvent
	if event and player.Parent then
		event:FireClient(player, message)
	end
end

-- MemoryStore 요청을 몇 번 다시 해요. 성공하면 (true, 결과)
local function withRetries<T>(what: string, fn: () -> T): (boolean, T?)
	local lastErr: any = nil
	for attempt = 1, STORE_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < STORE_RETRIES then
			task.wait(attempt)
		end
	end
	warn(`[PlaceService] {what} failed: {lastErr}`)
	return false, nil
end

------------------------------------------------------------------------
-- 텔레포트 (실패하면 그 사람만 MaxRetries번까지 다시, 같이 실패한 사람은 모아서 같이)

type Pending = {
	request: TeleportRequest,
	attempts: number,
	giveUp: GiveUp,
}

local pending: { [Player]: Pending } = {}
local retryBatches: { [TeleportRequest]: { Player } } = {}

local function sendNow(players: { Player }, request: TeleportRequest): (boolean, any)
	return pcall(getBackend().teleport, players, request)
end

local handleFailure: (player: Player, result: string, message: string) -> ()

local function flushRetries(request: TeleportRequest)
	local batch = retryBatches[request]
	retryBatches[request] = nil
	if batch == nil then
		return
	end
	local players: { Player } = {}
	for _, player in batch do
		local entry = pending[player]
		if entry and entry.request == request and player.Parent then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return
	end
	local nextRequest = request.fallback or request
	for _, player in players do
		(pending[player] :: Pending).request = nextRequest
	end
	local ok, err = sendNow(players, nextRequest)
	if not ok then
		for _, player in players do
			handleFailure(player, "Error", tostring(err))
		end
	end
end

handleFailure = function(player: Player, result: string, message: string)
	local entry = pending[player]
	if entry == nil then
		return
	end
	if player.Parent == nil then
		pending[player] = nil
		return
	end
	entry.attempts += 1
	if entry.attempts > Config.Teleport.MaxRetries then
		pending[player] = nil
		warn(`[PlaceService] teleport for {player.Name} gave up ({result}): {message}`)
		entry.giveUp(player, message)
		return
	end
	local request = entry.request
	local batch = retryBatches[request]
	if batch == nil then
		batch = {}
		retryBatches[request] = batch
		task.delay(RETRY_BATCH_DELAY, flushRetries, request)
	end
	table.insert(batch :: { Player }, player)
end

-- 여럿을 한 번에 보내요 (같은 서버로 같이). 끝내 실패한 사람마다 giveUp.
local function teleportGroup(players: { Player }, request: TeleportRequest, giveUp: GiveUp)
	local list: { Player } = {}
	for _, player in players do
		if player.Parent then
			pending[player] = { request = request, attempts = 0, giveUp = giveUp }
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return
	end
	local ok, err = sendNow(list, request)
	if not ok then
		for _, player in list do
			handleFailure(player, "Error", tostring(err))
		end
	end
end

-- 텔레포트 전에 프로필을 저장해요 (병렬, 최대 Config.Teleport.SaveBeforeTeleport초). 잠금은 떠날 때 풀려요.
local function saveBeforeTeleport(players: { Player })
	local remaining = #players
	for _, player in players do
		task.spawn(function()
			local ok, err = pcall(DataService.saveNow, player)
			if not ok then
				warn(`[PlaceService] save before teleport failed for {player.Name}: {err}`)
			end
			remaining -= 1
		end)
	end
	local deadline = os.clock() + Config.Teleport.SaveBeforeTeleport
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function lobbyPlaceId(): number
	return Config.Places.LobbyPlaceId or game.PlaceId
end

-- 한 사람을 아무 로비 서버로 (티켓 없이)
local function sendToLobby(player: Player, reason: string)
	if getBackend().isFake then
		print(`[PlaceService] (Studio) would teleport {player.Name} to the lobby: {reason}`)
		CharacterUtil.toLobby(player)
		return
	end
	teleportGroup({ player }, { placeId = lobbyPlaceId() }, function(p: Player)
		p:Kick("로비로 돌아가지 못했어요. 다시 접속해 주세요")
	end)
end

------------------------------------------------------------------------
-- 로비 역할

-- 방 출발: 매치 서버 예약 → 매니페스트 → 저장 → 텔레포트
local function launchMatch(room: RoomService.Room, _players: { Player })
	local roomId = room.id
	local key = room.key :: string
	local b = getBackend()

	local function cancel(message: string)
		if RoomService.getRoom(roomId) == room then
			for _, player in RoomService.getPlayers(roomId) do
				notice(player, message)
			end
			RoomService.endMatch(roomId)
		end
	end

	local matchPlaceId = Config.Places.MatchPlaceId :: number
	local reserved, accessCode, privateServerId = pcall(b.reserveServer, matchPlaceId)
	if not reserved then
		warn(`[PlaceService] ReserveServer failed for room {roomId}: {accessCode}`)
		cancel("매치 서버를 열지 못했어요. 다시 시작해 주세요")
		return
	end
	if RoomService.getRoom(roomId) ~= room or room.state ~= "InMatch" then
		return
	end

	local manifest = PlacePayload.manifest({
		roomKey = key,
		settings = PlacePayload.settingsOf(room),
		hostUserId = room.hostUserId,
		memberUserIds = PlacePayload.userIdsOf(room.members),
		lobbyJobId = b.jobId,
		createdAt = os.time(),
	})
	local stored = withRetries(`write manifest {roomId}`, function()
		b.hashSet(MANIFEST_MAP, privateServerId, manifest, Config.Teleport.ManifestTtl)
		return true
	end)
	if not stored then
		cancel("매치 서버를 열지 못했어요. 다시 시작해 주세요")
		return
	end

	local players = RoomService.getPlayers(roomId)
	saveBeforeTeleport(players)
	players = RoomService.getPlayers(roomId)
	if RoomService.getRoom(roomId) ~= room or #players == 0 then
		return
	end
	print(`[PlaceService] room {roomId} ({key}) → match server {privateServerId}, {#players} players`)
	teleportGroup(players, {
		placeId = matchPlaceId,
		accessCode = accessCode,
		data = PlacePayload.matchHint(key),
	}, function(player: Player)
		if RoomService.getRoomIdOf(player) == roomId then
			RoomService.removeFromRoom(player)
		end
		notice(player, "매치 서버로 이동하지 못했어요")
	end)

	-- 오래 남아 있는 멤버(텔레포트가 소리 없이 멈춤)는 방에서 빼요. 나머지가 떠나면 방은 닫혀요.
	task.delay(Config.Teleport.LaunchTimeout, function()
		if RoomService.getRoom(roomId) ~= room then
			return
		end
		for _, player in RoomService.getPlayers(roomId) do
			pending[player] = nil
			RoomService.removeFromRoom(player)
			notice(player, "매치 서버로 이동하지 못했어요")
		end
	end)
end

type Restore = {
	key: string,
	settings: PlacePayload.Settings,
	hostUserId: number,
	members: { [number]: boolean },
	roomId: string?,
	resultLoaded: boolean,
	busy: boolean,
}

local restores: { [string]: Restore } = {}

local function memberSet(userIds: { number }): { [number]: boolean }
	local set = {}
	for _, userId in userIds do
		set[userId] = true
	end
	return set
end

-- 믿을 수 있는 매치 결과 (매치 서버가 씀). 있으면 방 정보를 이걸로 바꾸고 단상에 우승자를 세워요.
local function loadResult(restore: Restore)
	local b = getBackend()
	local ok, raw = withRetries(`read match result {restore.key}`, function()
		return b.hashGet(RESULT_MAP, restore.key)
	end)
	if not ok or raw == nil then
		return
	end
	local result, err = PlacePayload.validateMatchResult(raw)
	if result == nil or result.roomKey ~= restore.key then
		warn(`[PlaceService] ignoring bad match result for {restore.key}: {err}`)
		return
	end
	restore.settings = result.settings
	restore.hostUserId = result.hostUserId
	restore.members = memberSet(result.memberUserIds)
	if result.winnerUserId and result.winnerName and result.appearanceId then
		MatchEvents.fireWinnerShowcase({
			userId = result.winnerUserId,
			name = result.winnerName,
			appearanceId = result.appearanceId,
		})
	end
end

-- 매치에서 돌아온 사람을 같은 방으로 (RestoreWindow 동안)
local function handleReturn(player: Player, raw: any)
	local ticket, err = PlacePayload.validateReturnTicket(raw, player.UserId)
	if ticket == nil then
		warn(`[PlaceService] ignoring bad return ticket from {player.Name}: {err}`)
		return
	end
	local key = ticket.roomKey
	local restore = restores[key]
	if restore == nil then
		local fresh: Restore = {
			key = key,
			settings = ticket.settings,
			hostUserId = ticket.hostUserId,
			members = memberSet(ticket.memberUserIds),
			roomId = nil,
			resultLoaded = false,
			busy = false,
		}
		restores[key] = fresh
		restore = fresh
		task.delay(Config.Teleport.RestoreWindow, function()
			if restores[key] == fresh then
				restores[key] = nil
			end
		end)
	end
	local r = restore :: Restore

	local deadline = os.clock() + RESTORE_WAIT
	while r.busy do
		if player.Parent == nil or os.clock() > deadline then
			return
		end
		task.wait(0.1)
	end
	if restores[key] ~= r or player.Parent == nil then
		return
	end
	r.busy = true
	local ok, failure = pcall(function()
		if not r.resultLoaded then
			r.resultLoaded = true
			loadResult(r)
		end
		if not r.members[player.UserId] then
			warn(`[PlaceService] {player.Name} is not a member of returning room {key}`)
			return
		end
		-- 이미 복원한 방, 또는 아직 닫히지 않은 원래 방(같은 키)
		local room = if r.roomId then RoomService.getRoom(r.roomId) else nil
		if room == nil or room.key ~= key then
			room = RoomService.findByKey(key)
		end
		if room then
			r.roomId = room.id
			local joined, why = RoomService.joinRestored(player, room.id, r.hostUserId)
			if not joined then
				notice(player, `원래 방에 들어가지 못했어요: {why}`)
			end
		else
			local created = RoomService.restoreRoom({
				key = key,
				settings = r.settings,
				hostUserId = r.hostUserId,
			}, { player }, player)
			r.roomId = if created then created.id else nil
		end
	end)
	r.busy = false
	if not ok then
		warn(`[PlaceService] restoring room {key} for {player.Name} failed: {failure}`)
	end
end

-- 다른 로비 서버에서 방에 들어가려고 온 사람
local function handleJoinTicket(player: Player, raw: any)
	local ticket = PlacePayload.validateJoinTicket(raw)
	if ticket == nil then
		return
	end
	local ok, err
	if ticket.code then
		ok, err = RoomService.joinLocalByCode(player, ticket.code)
	else
		ok, err = RoomService.joinLocalById(player, ticket.roomId :: string)
	end
	if not ok then
		notice(player, `그 방에 들어가지 못했어요: {err}`)
	end
end

local function onLobbyPlayerAdded(player: Player)
	local data = getBackend().joinData(player)
	local kind = PlacePayload.kindOf(data)
	if kind == "return" then
		handleReturn(player, data)
	elseif kind == "join" then
		handleJoinTicket(player, data)
	end
end

-- 다른 로비 서버로 한 사람 보내기 (방 참가)
local function teleportToLobbyServer(player: Player, jobId: string, ticket: PlacePayload.JoinTicket)
	notice(player, "방이 있는 서버로 이동하고 있어요…")
	saveBeforeTeleport({ player })
	teleportGroup({ player }, {
		placeId = lobbyPlaceId(),
		serverInstanceId = jobId,
		data = ticket,
	}, function(p: Player)
		notice(p, "그 방이 있는 서버로 이동하지 못했어요")
	end)
end

local function startLobby()
	local b = getBackend()
	RoomDirectory.start(b)
	RoomService.setPlaceHooks({
		launchMatch = launchMatch,
		decorateList = RoomDirectory.decorate,
		joinRemote = function(player: Player, id: string): (boolean, string?)
			local entry, err = RoomDirectory.findRemote(id)
			if entry == nil then
				return false, err
			end
			teleportToLobbyServer(player, entry.jobId, PlacePayload.joinTicket(entry.roomId, nil))
			return true, nil
		end,
		joinRemoteByCode = function(player: Player, code: string): (boolean, string?)
			local entry = RoomDirectory.lookupCode(code)
			if entry == nil then
				return false, "그 코드의 방이 없어요"
			end
			teleportToLobbyServer(player, entry.jobId, PlacePayload.joinTicket(nil, code))
			return true, nil
		end,
		quickJoinRemote = function(player: Player): boolean
			local entry = RoomDirectory.pickRemoteQuickJoin()
			if entry == nil then
				return false
			end
			teleportToLobbyServer(player, entry.jobId, PlacePayload.joinTicket(entry.roomId, nil))
			return true
		end,
		claimCode = RoomDirectory.claimCode,
		releaseCode = RoomDirectory.releaseCode,
		onRoomGone = RoomDirectory.removeRoom,
	})
	Players.PlayerAdded:Connect(onLobbyPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onLobbyPlayerAdded, player)
	end
end

------------------------------------------------------------------------
-- 매치 역할

type MatchServerState = "loading" | "waiting" | "started" | "finished" | "aborted"

local matchState: MatchServerState = "loading"
local manifest: PlacePayload.Manifest? = nil
local arrivals: { Player } = {}
local matchRoomId: string? = nil

local function isManifestMember(userId: number): boolean
	local m = manifest
	return m ~= nil and table.find(m.memberUserIds, userId) ~= nil
end

local function presentArrivals(): { Player }
	local list = {}
	for _, player in arrivals do
		if player.Parent and isManifestMember(player.UserId) then
			table.insert(list, player)
		end
	end
	return list
end

-- 같은 방 복귀 티켓을 들고 로비로 (도착 취소·매치 끝)
local function returnToLobby(players: { Player }, settings: PlacePayload.Settings, hostUserId: number, reason: string)
	local m = manifest :: PlacePayload.Manifest
	local ticket = PlacePayload.returnTicket(m.roomKey, settings, hostUserId, PlacePayload.userIdsOfPlayers(players))
	local b = getBackend()
	if b.isFake then
		-- Studio 흉내: 텔레포트 대신 로그 + 로비 스폰 (AC8)
		print(
			`[PlaceService] (Studio) would teleport {#players} players back to the lobby ({reason}), room {m.roomKey}`
		)
		for _, player in players do
			CharacterUtil.toLobby(player)
		end
		return
	end
	if #players == 0 then
		return
	end
	saveBeforeTeleport(players)
	local anyLobby: TeleportRequest = { placeId = lobbyPlaceId(), data = ticket }
	local request: TeleportRequest = if m.lobbyJobId ~= ""
		then { placeId = lobbyPlaceId(), serverInstanceId = m.lobbyJobId, data = ticket, fallback = anyLobby }
		else anyLobby
	print(`[PlaceService] room {m.roomKey}: {#players} players → lobby ({reason})`)
	teleportGroup(players, request, function(player: Player)
		player:Kick("로비로 돌아가지 못했어요. 다시 접속해 주세요")
	end)
end

local function abortMatch(reason: string)
	matchState = "aborted"
	local m = manifest :: PlacePayload.Manifest
	warn(`[PlaceService] match server for room {m.roomKey} aborted: {reason}`)
	local players = presentArrivals()
	returnToLobby(players, m.settings, m.hostUserId, reason)
end

local function startMatchNow()
	local m = manifest :: PlacePayload.Manifest
	local players = presentArrivals()
	local room = RoomService.restoreRoom({
		key = m.roomKey,
		settings = m.settings,
		hostUserId = m.hostUserId,
	}, players, nil)
	if room == nil then
		abortMatch("could not restore room")
		return
	end
	matchRoomId = room.id
	matchState = "started"
	print(`[PlaceService] room {m.roomKey}: {#players}/{#m.memberUserIds} arrived, starting match`)
	RoomService.startRestored(room.id)
end

local function onMatchPlayerAdded(player: Player)
	if matchState == "loading" then
		table.insert(arrivals, player) -- 매니페스트를 읽은 뒤 판단해요
		return
	end
	if not isManifestMember(player.UserId) then
		warn(`[PlaceService] {player.Name} is not in the match manifest, sending to the lobby`)
		sendToLobby(player, "not in manifest")
		return
	end
	if matchState == "waiting" then
		table.insert(arrivals, player)
	elseif matchState == "started" then
		-- 늦게 온 멤버: 관전자 (매치 생존자 아님)
		local roomId = matchRoomId
		if roomId == nil or not RoomService.addLateMember(roomId, player) then
			sendToLobby(player, "late arrival")
		end
	else
		local m = manifest :: PlacePayload.Manifest
		returnToLobby({ player }, m.settings, m.hostUserId, "match already over")
	end
end

-- Studio 흉내: 접속한 사람 전원을 멤버로 보는 매니페스트 (새로 오는 사람이 SimulateSettle초 없을 때)
local function simulatedManifest(): PlacePayload.Manifest
	local lastCount, lastChange = -1, os.clock()
	while true do
		local count = #Players:GetPlayers()
		if count ~= lastCount then
			lastCount, lastChange = count, os.clock()
		elseif count > 0 and os.clock() - lastChange >= Config.Teleport.SimulateSettle then
			break
		end
		task.wait(0.25)
	end
	local players = Players:GetPlayers()
	local maxPlayers = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
	for _, option in Config.Room.MaxPlayerOptions do
		if option >= #players then
			maxPlayers = option
			break
		end
	end
	local userIds = PlacePayload.userIdsOfPlayers(players)
	-- Studio 테스트 플레이어 UserId는 음수라 validateManifest를 거치지 않아요 (서버가 만든 값)
	return PlacePayload.manifest({
		roomKey = "studio-simulated",
		settings = { maxPlayers = maxPlayers, isPrivate = false, name = "Studio 매치" },
		hostUserId = userIds[1],
		memberUserIds = userIds,
		lobbyJobId = "",
		createdAt = os.time(),
	})
end

local function readManifest(): PlacePayload.Manifest?
	local b = getBackend()
	if isSimulated() then
		return simulatedManifest()
	end
	local privateServerId = b.privateServerId
	if privateServerId == "" then
		return nil
	end
	local ok, raw = withRetries("read manifest", function()
		return b.hashGet(MANIFEST_MAP, privateServerId)
	end)
	if not ok or raw == nil then
		return nil
	end
	local m, err = PlacePayload.validateManifest(raw)
	if m == nil then
		warn(`[PlaceService] bad match manifest: {err}`)
	end
	return m
end

local function runMatchServer()
	local m = readManifest()
	if m == nil then
		matchState = "aborted"
		warn("[PlaceService] no match manifest for this server — sending everyone to the lobby")
		for _, player in Players:GetPlayers() do
			sendToLobby(player, "no manifest")
		end
		Players.PlayerAdded:Connect(function(player: Player)
			sendToLobby(player, "no manifest")
		end)
		return
	end
	manifest = m

	-- 매니페스트를 읽는 동안 온 사람 정리
	local waiting = arrivals
	arrivals = {}
	matchState = "waiting"
	for _, player in waiting do
		if player.Parent then
			onMatchPlayerAdded(player)
		end
	end

	local minPlayers = if isSimulated() then Config.DEBUG.minPlayersToStart else 2
	local startedAt = os.clock()
	while true do
		local decision = PlacePayload.arrivalReady(
			#m.memberUserIds,
			#presentArrivals(),
			os.clock() - startedAt,
			Config.Teleport.ArrivalTimeout,
			minPlayers
		)
		if decision == "start" then
			startMatchNow()
			return
		elseif decision == "abort" then
			abortMatch("not enough players arrived")
			return
		end
		task.wait(ARRIVAL_POLL)
	end
end

local function startMatchServer()
	RoomService.setPlaceHooks({
		matchServer = true,
		onLeaveRoom = function(player: Player)
			sendToLobby(player, "left the room")
		end,
	})
	Players.PlayerAdded:Connect(onMatchPlayerAdded)
	for _, player in Players:GetPlayers() do
		table.insert(arrivals, player)
	end
	task.spawn(runMatchServer)
end

-- MatchService가 매치 끝(우승 화면 뒤)에 불러요. 매치 역할이면 결과를 쓰고 멤버를 로비로 보내고 true.
function PlaceService.finishMatch(roomId: string, winner: WinnerInfo?): boolean
	if PlaceService.role() ~= "Match" or not started then
		return false
	end
	local m = manifest
	local room = RoomService.getRoom(roomId)
	if m == nil or room == nil then
		return false
	end
	matchState = "finished"
	local players = RoomService.getPlayers(roomId)
	local result = PlacePayload.matchResult({
		roomKey = m.roomKey,
		settings = m.settings,
		hostUserId = room.hostUserId,
		memberUserIds = PlacePayload.userIdsOfPlayers(players),
	}, winner)
	local b = getBackend()
	if #players > 0 then
		withRetries(`write match result {m.roomKey}`, function()
			b.hashSet(RESULT_MAP, m.roomKey, result, Config.Teleport.ResultTtl)
			return true
		end)
	end
	if winner then
		print(`[PlaceService] room {m.roomKey} winner: {winner.name} ({winner.userId})`)
	end
	returnToLobby(players, m.settings, room.hostUserId, "match finished")
	if b.isFake then
		-- Studio 흉내: 방을 대기 상태로 (클라이언트는 "로비로 돌아가는 중…" 안내만 보여요)
		RoomService.endMatch(roomId)
	end
	return true
end

------------------------------------------------------------------------

function PlaceService.init()
	local role = PlaceService.role()
	workspace:SetAttribute(Attributes.PlaceRole, role)
	noticeEvent = Remotes.event("Notice")
	if backend == nil and role ~= "Single" then
		if RunService:IsStudio() then
			backend = PlaceBackend.fake(function(players: { Player }, request: TeleportRequest)
				local names = {}
				for _, player in players do
					table.insert(names, player.Name)
				end
				print(`[PlaceService] (Studio) teleport to place {request.placeId}: {table.concat(names, ", ")}`)
			end)
		else
			backend = PlaceBackend.real()
		end
	end
end

function PlaceService.start()
	local role = PlaceService.role()
	if role == "Single" then
		return -- 한 플레이스 모드: 지금과 같아요
	end
	started = true
	getBackend().onTeleportFailed(handleFailure)
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
	end)
	if role == "Lobby" then
		startLobby()
	else
		startMatchServer()
	end
end

return PlaceService
