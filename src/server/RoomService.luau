--!strict
-- 방 생성/참가/퇴장/방장/시작 (GDD 3)
-- 규칙 판단은 Shared.RoomLogic(순수 함수)에 맡기고, 여기서는 리모트 검증·상태 보관·방송·자동 시작을 해요.
--
-- MatchService 연결 (방 하나의 매치는 MatchService가 돌려요):
--   RoomService.onMatchStart(fn(room, players))  방이 출발할 때 한 번 불러요. room.state는 이미 "InMatch".
--   RoomService.onMemberLeft(fn(roomId, player)) 매치 중에 누가 방을 나가거나 게임을 떠났을 때.
--   RoomService.endMatch(roomId)                 매치가 끝나면 불러서 방을 대기실로 돌려요 (같은 멤버로 한 판 더).
--   RoomService.getArenaOrigin(roomId)           이 방의 매치 맵을 지을 위치 (방마다 슬롯이 달라요).
--
-- 플레이스 분리 (m4-11, PlaceService가 연결해요. 한 플레이스 모드(Single)에서는 훅이 없어 지금과 같아요):
--   RoomService.setPlaceHooks(hooks)             로비: 출발 = 텔레포트, 다른 서버 방 목록·참가, 서버 간 코드 예약.
--                                               매치: 로비 요청 막기, 방 목록 안 보냄, 자동 시작 없음.
--   RoomService.restoreRoom(spec, players, filterWith?)  같은 방을 다시 만들어요 (매치 서버 도착, 로비 복귀)
--   RoomService.joinRestored(player, roomId, hostUserId, verified) 복귀한 멤버를 다시 묶어요 (확인된 복귀면 원래 방장으로)
--   RoomService.startRestored(roomId)            대기실 없이 바로 출발 (매치 서버)
--   RoomService.addLateMember(roomId, player)    이미 출발한 방에 늦게 온 멤버 (매치 서버: 관전자)
--   RoomService.removeFromRoom(player)           방에서 빼요 (텔레포트 실패 등)
--   RoomService.joinLocalById / joinLocalByCode  다른 서버에서 넘어온 참가 티켓 처리 (이 서버 방만)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlacePayload = require(ReplicatedStorage.Shared.PlacePayload)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoomDirectoryLogic = require(ReplicatedStorage.Shared.RoomDirectoryLogic)
local RoomLogic = require(ReplicatedStorage.Shared.RoomLogic)
local Types = require(ReplicatedStorage.Shared.Types)

export type Room = RoomLogic.Room
type MatchStartHandler = (room: Room, players: { Player }) -> ()
type MemberLeftHandler = (roomId: string, player: Player) -> ()
type ListDecorator = (listings: { Types.RoomListing }) -> { Types.RoomListing }
type RemoteJoin = (player: Player, id: string) -> (boolean, string?)
type ClaimCode = (code: string, roomId: string) -> boolean

-- PlaceService가 넣어 주는 훅 (모두 선택)
export type PlaceHooks = {
	launchMatch: MatchStartHandler?, -- 로비: 출발하면 로컬 매치 대신 이걸 불러요 (텔레포트)
	decorateList: ListDecorator?, -- 로비: 이 서버 목록 뒤에 다른 서버 방을 붙여요 (yield 금지)
	joinRemote: RemoteJoin?, -- 로비: 다른 서버 방 id("<JobId>:<roomId>")로 참가
	joinRemoteByCode: RemoteJoin?, -- 로비: 이 서버에 없는 코드
	quickJoinRemote: ((player: Player) -> boolean)?, -- 로비: 이 서버에 들어갈 방이 없을 때. 텔레포트하면 true
	claimCode: ClaimCode?, -- 로비: 다른 서버와 겹치지 않게 코드 예약 (yield 가능, 실패 false)
	releaseCode: ((code: string) -> ())?,
	onRoomGone: ((roomId: string) -> ())?, -- 로비: 방이 닫히거나 출발했어요 (목록에서 바로 지우기)
	matchServer: boolean?, -- 매치: 로비 요청·방 목록·자동 시작 없음
	onLeaveRoom: ((player: Player) -> ())?, -- 매치: 방을 떠난 사람 (로비로 텔레포트)
	isTeleporting: ((player: Player) -> boolean)?, -- 로비: 다른 서버로 이동 중이면 방 요청을 받지 않아요 (QA R2)
}

export type RestoreSpec = {
	key: string?, -- nil이면 새 키 (MatchResult로 확인되지 않은 복귀, m4-11 QA R1)
	settings: PlacePayload.Settings,
	hostUserId: number,
}

local REQUEST_COOLDOWN = 0.3 -- 같은 플레이어의 방 요청 사이 최소 간격(초)
local NO_MATCH_RETURN_DELAY = 3 -- MatchService가 연결되지 않았을 때 대기실로 돌아오는 시간(초)
local CODE_CLAIM_TRIES = 10

local RoomService = {}

local rooms: { [string]: Room } = {}
local roomIdByUser: { [number]: string } = {}
local roomIdByCode: { [string]: string } = {}
local roomIdByKey: { [string]: string } = {}
local usedSlots: { [number]: boolean } = {}
local autoStartThreads: { [string]: thread } = {}
local lastRequestAt: { [Player]: number } = {}
local nextRoomId = 0
local rng = Random.new()

local matchStartHandler: MatchStartHandler? = nil
local memberLeftHandler: MemberLeftHandler? = nil
local hooks: PlaceHooks = {}

local roomListEvent: RemoteEvent
local roomUpdatedEvent: RemoteEvent

------------------------------------------------------------------------
-- 방송: 바뀐 방은 표시만 해두고 프레임 끝에 한 번에 보내요.

local dirtyRooms: { [string]: boolean } = {}
local listDirty = false
local flushScheduled = false

local function playersOf(room: Room): { Player }
	local result = {}
	for _, member in room.members do
		local player = Players:GetPlayerByUserId(member.userId)
		if player then
			table.insert(result, player)
		end
	end
	return result
end

local function allRooms(): { Room }
	local list = {}
	for _, room in rooms do
		table.insert(list, room)
	end
	return list
end

-- 로비에 보이는 목록 (로비 역할이면 다른 서버 방까지)
local function currentListings(): { Types.RoomListing }
	local listings = RoomLogic.listPublic(allRooms())
	local decorate = hooks.decorateList
	if decorate then
		local ok, result = pcall(decorate, listings)
		if ok then
			return result
		end
		warn(`[RoomService] room list decorator failed: {result}`)
	end
	if #listings > RoomDirectoryLogic.MAX_LISTINGS then
		listings = table.move(listings, 1, RoomDirectoryLogic.MAX_LISTINGS, 1, {})
	end
	return listings
end

local function flush()
	flushScheduled = false
	for roomId in dirtyRooms do
		local room = rooms[roomId]
		if room then
			local snapshot = RoomLogic.snapshot(room)
			for _, player in playersOf(room) do
				roomUpdatedEvent:FireClient(player, snapshot)
			end
		end
	end
	table.clear(dirtyRooms)

	if listDirty then
		listDirty = false
		if hooks.matchServer then
			return -- 매치 서버에는 로비 방 목록이 없어요
		end
		local listings = currentListings()
		for _, player in Players:GetPlayers() do
			if roomIdByUser[player.UserId] == nil then
				roomListEvent:FireClient(player, listings)
			end
		end
	end
end

local function scheduleFlush()
	if not flushScheduled then
		flushScheduled = true
		task.defer(flush)
	end
end

local function markChanged(room: Room)
	dirtyRooms[room.id] = true
	listDirty = true
	scheduleFlush()
end

local function markListChanged()
	listDirty = true
	scheduleFlush()
end

local function roomGone(roomId: string)
	local fn = hooks.onRoomGone
	if fn then
		task.spawn(fn, roomId)
	end
end

------------------------------------------------------------------------
-- 매치 출발과 자동 시작

local function cancelAutoStart(room: Room)
	local thread = autoStartThreads[room.id]
	if thread then
		autoStartThreads[room.id] = nil
		if thread ~= coroutine.running() then
			task.cancel(thread)
		end
	end
	room.autoStartAt = nil
end

local function beginMatch(room: Room)
	cancelAutoStart(room)
	room.state = "InMatch"
	markChanged(room)
	roomGone(room.id)

	local players = playersOf(room)
	local launch = hooks.launchMatch
	if launch then
		task.spawn(launch, room, players) -- 로비 역할: 매치 서버로 텔레포트 (m4-11)
		return
	end
	local handler = matchStartHandler
	if handler then
		task.spawn(handler, room, players)
	else
		warn(`[RoomService] room {room.id} started but no match handler is connected; returning to waiting`)
		task.delay(NO_MATCH_RETURN_DELAY, RoomService.endMatch, room.id)
	end
end

-- 정원이 차면 카운트다운을 걸고, 누가 나가서 자리가 비면 취소해요. 매치 서버에서는 자동 시작이 없어요.
local function refreshAutoStart(room: Room)
	if not hooks.matchServer and RoomLogic.shouldAutoStart(room) then
		if autoStartThreads[room.id] == nil then
			room.autoStartAt = workspace:GetServerTimeNow() + Config.Room.AutoStartDelay
			autoStartThreads[room.id] = task.delay(Config.Room.AutoStartDelay, function()
				autoStartThreads[room.id] = nil
				if rooms[room.id] == room and RoomLogic.shouldAutoStart(room) then
					beginMatch(room)
				end
			end)
		end
	elseif room.autoStartAt ~= nil or autoStartThreads[room.id] then
		cancelAutoStart(room)
	end
end

------------------------------------------------------------------------
-- 방 만들기/참가/퇴장

local function memberInfo(player: Player): Types.MemberInfo
	return { userId = player.UserId, name = player.DisplayName }
end

local function releaseCode(code: string)
	roomIdByCode[code] = nil
	local release = hooks.releaseCode
	if release then
		task.spawn(release, code)
	end
end

local function closeRoom(room: Room)
	cancelAutoStart(room)
	rooms[room.id] = nil
	usedSlots[room.slot] = nil
	if room.code and roomIdByCode[room.code] == room.id then
		releaseCode(room.code)
	end
	if room.key and roomIdByKey[room.key] == room.id then
		roomIdByKey[room.key] = nil
	end
	dirtyRooms[room.id] = nil
	markListChanged()
	roomGone(room.id)
end

-- 텍스트 필터를 못 거치면 이름을 쓰지 않아요 (기본 이름으로 대체).
local function filterRoomName(name: string, player: Player): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn(`[RoomService] room name filter failed: {result}`)
		return nil
	end
	return RoomLogic.cleanName(result)
end

local function reserveRoomId(): string
	nextRoomId += 1
	return tostring(nextRoomId)
end

-- 겹치지 않는 비공개 방 코드. 로비 역할이면 다른 서버와도 겹치지 않게 예약해요 (yield). 못 찾으면 nil.
local function pickCode(roomId: string): string?
	for _ = 1, CODE_CLAIM_TRIES do
		local code = RoomLogic.generateCode(rng, function(candidate)
			return roomIdByCode[candidate] ~= nil
		end)
		if code == nil then
			return nil
		end
		roomIdByCode[code] = roomId -- 예약이 yield하는 동안 이 서버의 다른 방이 같은 코드를 못 쓰게
		local claim = hooks.claimCode
		if claim == nil then
			return code
		end
		local ok, claimed = pcall(claim, code, roomId)
		if not ok or claimed then
			return code -- 예약 요청이 실패하면 이 서버 안에서만 겹치지 않으면 돼요 (게임은 계속)
		end
		roomIdByCode[code] = nil -- 다른 서버가 쓰는 코드: 다시 뽑아요
	end
	return nil
end

type CreateParams = {
	roomId: string,
	settings: { maxPlayers: number, isPrivate: boolean },
	name: string,
	code: string?,
	key: string?,
	players: { Player }, -- 첫 사람이 방장 (restore는 뒤에서 바꿔요)
}

-- 여기서부터는 yield하지 않아요. players는 모두 방이 없는 상태여야 해요.
local function insertRoom(params: CreateParams): Room
	local slot = RoomLogic.nextFreeSlot(usedSlots)
	local key = params.key or HttpService:GenerateGUID(false)
	local room = RoomLogic.newRoom({
		id = params.roomId,
		name = params.name,
		maxPlayers = params.settings.maxPlayers,
		isPrivate = params.settings.isPrivate,
		code = params.code,
		slot = slot,
		key = key,
	}, memberInfo(params.players[1]))
	for i = 2, #params.players do
		RoomLogic.addMember(room, memberInfo(params.players[i]))
	end

	rooms[room.id] = room
	usedSlots[slot] = true
	if params.code then
		roomIdByCode[params.code] = room.id
	end
	roomIdByKey[key] = room.id
	for _, member in room.members do
		roomIdByUser[member.userId] = room.id
	end
	refreshAutoStart(room)
	markChanged(room)
	return room
end

local function createRoom(player: Player, settings: Types.RoomSettings, name: string): Room?
	local roomId = reserveRoomId()
	local code: string? = nil
	if settings.isPrivate then
		code = pickCode(roomId)
		if code == nil then
			return nil
		end
	end
	-- 코드 예약이 yield하는 동안 나갔거나 다른 방에 들어갔을 수 있어요
	if player.Parent == nil or roomIdByUser[player.UserId] ~= nil then
		if code then
			releaseCode(code)
		end
		return nil
	end
	return insertRoom({
		roomId = roomId,
		settings = settings,
		name = name,
		code = code,
		key = nil,
		players = { player },
	})
end

local function joinRoom(player: Player, room: Room): (boolean, string?)
	local ok, err = RoomLogic.addMember(room, memberInfo(player))
	if not ok then
		return false, err
	end
	roomIdByUser[player.UserId] = room.id
	refreshAutoStart(room)
	markChanged(room)
	return true, nil
end

local function leaveRoom(player: Player)
	local roomId = roomIdByUser[player.UserId]
	if roomId == nil then
		return
	end
	local room = rooms[roomId]
	if room == nil then
		roomIdByUser[player.UserId] = nil
		return
	end

	-- 매치 중이면 방에서 빼기 **전에** 알려요. 그래야 탈락 결과(PlayerResult)가 남은 멤버에게도 방송돼요.
	if room.state == "InMatch" and memberLeftHandler then
		local ok, err = pcall(memberLeftHandler, room.id, player)
		if not ok then
			warn(`[RoomService] member left handler failed for {player.Name}: {err}`)
		end
	end

	roomIdByUser[player.UserId] = nil
	RoomLogic.removeMember(room, player.UserId)

	if player.Parent then
		roomUpdatedEvent:FireClient(player, nil)
	end

	if #room.members == 0 then
		closeRoom(room)
	else
		refreshAutoStart(room)
		markChanged(room)
	end
end

------------------------------------------------------------------------
-- 리모트 요청 처리. 반환: (ok, 실패 이유)

local MATCH_SERVER_BLOCKED = "매치 서버에서는 할 수 없어요"

local function requireNoRoom(player: Player): string?
	if hooks.matchServer then
		return MATCH_SERVER_BLOCKED
	end
	if roomIdByUser[player.UserId] ~= nil then
		return "이미 방에 들어가 있어요"
	end
	local teleporting = hooks.isTeleporting
	if teleporting and teleporting(player) then
		return "다른 서버로 이동하고 있어요"
	end
	return nil
end

local function joinLocalById(player: Player, roomId: string): (boolean, string?)
	local room = rooms[roomId]
	if room == nil or room.isPrivate then -- 비공개 방은 코드로만 들어가요
		return false, "방을 찾을 수 없어요"
	end
	return joinRoom(player, room)
end

local function joinLocalByCode(player: Player, code: string): (boolean, string?)
	local roomId = roomIdByCode[code]
	local room = roomId and rooms[roomId]
	if not room then
		return false, "그 코드의 방이 없어요"
	end
	return joinRoom(player, room)
end

local handlers: { [string]: (player: Player, ...any) -> (boolean, string?) } = {}

function handlers.CreateRoom(player: Player, rawSettings: any): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	local settings, err = RoomLogic.validateSettings(rawSettings)
	if settings == nil then
		return false, err
	end
	local name = settings.name and filterRoomName(settings.name, player)
	if player.Parent == nil then -- 필터가 yield하는 동안 게임을 떠났으면 방을 만들지 않아요 (유령 방 방지)
		return false, "게임을 떠났어요"
	end
	if roomIdByUser[player.UserId] ~= nil then -- 필터가 yield하는 동안 다른 요청으로 방에 들어갔을 수 있어요
		return false, "이미 방에 들어가 있어요"
	end
	local room = createRoom(player, settings, name or RoomLogic.defaultName(player.DisplayName))
	if room == nil then
		if player.Parent == nil then
			return false, "게임을 떠났어요"
		end
		if roomIdByUser[player.UserId] ~= nil then
			return false, "이미 방에 들어가 있어요"
		end
		return false, "방을 만들 수 없어요. 잠시 뒤 다시 시도해 주세요"
	end
	return true, nil
end

function handlers.JoinRoom(player: Player, roomId: any): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	if type(roomId) ~= "string" or #roomId > 200 then
		return false, "방을 찾을 수 없어요"
	end
	-- 다른 로비 서버의 방 (m4-11): 그 서버로 텔레포트해서 들어가요
	local joinRemote = hooks.joinRemote
	if joinRemote and RoomDirectoryLogic.isRemoteId(roomId) then
		return joinRemote(player, roomId)
	end
	return joinLocalById(player, roomId)
end

function handlers.JoinByCode(player: Player, code: any): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	if not RoomLogic.isValidCode(code) then
		return false, `방 코드는 숫자 {Config.Room.CodeLength}자리예요`
	end
	local roomId = roomIdByCode[code]
	local joinRemote = hooks.joinRemoteByCode
	if (roomId == nil or rooms[roomId] == nil) and joinRemote then
		return joinRemote(player, code)
	end
	return joinLocalByCode(player, code)
end

function handlers.QuickJoin(player: Player): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	-- 이 서버 방 → 다른 서버 방 → 새 방 (m4-11)
	local room = RoomLogic.pickQuickJoin(allRooms())
	if room then
		return joinRoom(player, room)
	end
	local quickJoinRemote = hooks.quickJoinRemote
	if quickJoinRemote and quickJoinRemote(player) then
		return true, nil
	end
	if player.Parent == nil or roomIdByUser[player.UserId] ~= nil then
		return false, "이미 방에 들어가 있어요"
	end
	local created = createRoom(player, {
		maxPlayers = Config.Room.DefaultMaxPlayers,
		isPrivate = false,
	}, RoomLogic.defaultName(player.DisplayName))
	if created == nil then
		return false, "방을 만들 수 없어요. 잠시 뒤 다시 시도해 주세요"
	end
	return true, nil
end

function handlers.LeaveRoom(player: Player): (boolean, string?)
	if roomIdByUser[player.UserId] == nil then
		return false, "방에 들어가 있지 않아요"
	end
	leaveRoom(player)
	local onLeave = hooks.onLeaveRoom
	if onLeave then
		task.spawn(onLeave, player) -- 매치 서버: 방을 떠나면 로비로 (m4-11)
	end
	return true, nil
end

function handlers.StartRoom(player: Player): (boolean, string?)
	if hooks.matchServer then
		return false, MATCH_SERVER_BLOCKED
	end
	local roomId = roomIdByUser[player.UserId]
	local room = roomId and rooms[roomId]
	if not room then
		return false, "방에 들어가 있지 않아요"
	end
	local ok, err = RoomLogic.canStart(room, player.UserId, RoomLogic.minPlayersToStart(RunService:IsStudio()))
	if not ok then
		return false, err
	end
	beginMatch(room)
	return true, nil
end

local function bindRequest(name: string)
	local handler = handlers[name]
	Remotes.fn(name).OnServerInvoke = function(player: Player, ...: any): (boolean, string?)
		local now = os.clock()
		local last = lastRequestAt[player]
		if last and now - last < REQUEST_COOLDOWN then
			return false, "너무 빨라요. 잠시 뒤 다시 눌러 주세요"
		end
		lastRequestAt[player] = now

		local ok, result, err = pcall(handler, player, ...)
		if not ok then
			warn(`[RoomService] {name} failed for {player.Name}: {result}`)
			return false, "서버 오류가 났어요"
		end
		return result, err
	end
end

------------------------------------------------------------------------
-- MatchService에서 쓰는 API

function RoomService.onMatchStart(handler: MatchStartHandler)
	assert(matchStartHandler == nil, "match start handler already connected")
	matchStartHandler = handler
end

function RoomService.onMemberLeft(handler: MemberLeftHandler)
	assert(memberLeftHandler == nil, "member left handler already connected")
	memberLeftHandler = handler
end

-- 매치가 끝난 방을 대기실로 돌려요. 남은 멤버로 다시 시작할 수 있어요.
function RoomService.endMatch(roomId: string)
	local room = rooms[roomId]
	if room == nil or room.state ~= "InMatch" then
		return
	end
	room.state = "Waiting"
	refreshAutoStart(room)
	markChanged(room)
end

-- 읽기 전용으로 써 주세요. 방 상태는 RoomService만 바꿔요.
function RoomService.getRoom(roomId: string): Room?
	return rooms[roomId]
end

function RoomService.getRoomIdOf(player: Player): string?
	return roomIdByUser[player.UserId]
end

function RoomService.getPlayers(roomId: string): { Player }
	local room = rooms[roomId]
	return if room then playersOf(room) else {}
end

function RoomService.getArenaOrigin(roomId: string): CFrame
	local room = rooms[roomId]
	assert(room, `unknown room {roomId}`)
	return CFrame.new(room.slot * Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
end

------------------------------------------------------------------------
-- 플레이스 분리 API (m4-11, PlaceService·RoomDirectory가 써요)

function RoomService.setPlaceHooks(newHooks: PlaceHooks)
	hooks = newHooks
	markListChanged()
end

-- 읽기 전용 목록 (방 목록 올리기)
function RoomService.listRooms(): { Room }
	return allRooms()
end

function RoomService.findByKey(key: string): Room?
	local roomId = roomIdByKey[key]
	return if roomId then rooms[roomId] else nil
end

-- 다른 서버 방 목록이 바뀌었어요: 로비에 있는 사람에게 목록을 다시 보내요
function RoomService.refreshList()
	markListChanged()
end

function RoomService.removeFromRoom(player: Player)
	leaveRoom(player)
end

-- 같은 방을 다시 만들어요 (설정·키 그대로, 방장 = 원래 방장이 있으면 그 사람, 아니면 players의 첫 사람).
-- filterWith가 있으면 그 사람 기준으로 이름을 다시 필터해요 (로비 복귀, 실패하면 기본 이름). yield할 수 있어요.
-- players 중 이미 방이 있거나 나간 사람은 빼요. 아무도 없거나 코드를 못 만들면 nil.
function RoomService.restoreRoom(spec: RestoreSpec, players: { Player }, filterWith: Player?): Room?
	local function keyTaken(): boolean
		local existing = if spec.key then roomIdByKey[spec.key] else nil
		return existing ~= nil and rooms[existing] ~= nil
	end
	if keyTaken() then
		return nil -- 이미 있어요 (joinRestored로)
	end
	local name = spec.settings.name
	if filterWith then
		name = filterRoomName(name, filterWith) or RoomLogic.defaultName(filterWith.DisplayName)
	end
	local roomId = reserveRoomId()
	local code: string? = nil
	if spec.settings.isPrivate then
		code = pickCode(roomId) -- 비공개 방은 새 코드
		if code == nil then
			return nil
		end
	end
	local present: { Player } = {}
	local ids: { number } = {}
	for _, player in players do
		if player.Parent ~= nil and roomIdByUser[player.UserId] == nil and #present < spec.settings.maxPlayers then
			table.insert(present, player)
			table.insert(ids, player.UserId)
		end
	end
	if #present == 0 or keyTaken() then
		if code then
			releaseCode(code)
		end
		return nil
	end
	local room = insertRoom({
		roomId = roomId,
		settings = spec.settings,
		name = name,
		code = code,
		key = spec.key,
		players = present,
	})
	room.hostUserId = PlacePayload.pickRestoreHost(spec.hostUserId, ids) or room.hostUserId
	markChanged(room)
	return room
end

-- 복귀한 멤버를 같은 방에 다시 넣어요. verified(MatchResult로 확인된 복귀)일 때만 원래 방장이 돌아오면
-- 방장을 돌려줘요 — 확인되지 않은 티켓으로 방장을 바꿀 수 없게 (m4-11 QA R1).
function RoomService.joinRestored(
	player: Player,
	roomId: string,
	hostUserId: number,
	verified: boolean
): (boolean, string?)
	if roomIdByUser[player.UserId] ~= nil then
		return false, "이미 방에 들어가 있어요"
	end
	local room = rooms[roomId]
	if room == nil then
		return false, "방을 찾을 수 없어요"
	end
	local ok, err = joinRoom(player, room)
	if ok and verified then
		room.hostUserId = PlacePayload.pickRestoreHost(hostUserId, PlacePayload.userIdsOf(room.members))
			or room.hostUserId
		markChanged(room)
	end
	return ok, err
end

-- 대기실 없이 바로 출발 (매치 서버)
function RoomService.startRestored(roomId: string): boolean
	local room = rooms[roomId]
	if room == nil or room.state ~= "Waiting" then
		return false
	end
	beginMatch(room)
	return true
end

-- 이미 출발한 방에 늦게 온 멤버 (매치 서버: 관전자, 매치 생존자 아님)
function RoomService.addLateMember(roomId: string, player: Player): boolean
	local room = rooms[roomId]
	if room == nil or roomIdByUser[player.UserId] ~= nil then
		return false
	end
	if not RoomLogic.addLateMember(room, memberInfo(player)) then
		return false
	end
	roomIdByUser[player.UserId] = room.id
	markChanged(room)
	return true
end

function RoomService.joinLocalById(player: Player, roomId: string): (boolean, string?)
	if roomIdByUser[player.UserId] ~= nil then
		return false, "이미 방에 들어가 있어요"
	end
	return joinLocalById(player, roomId)
end

function RoomService.joinLocalByCode(player: Player, code: string): (boolean, string?)
	if roomIdByUser[player.UserId] ~= nil then
		return false, "이미 방에 들어가 있어요"
	end
	return joinLocalByCode(player, code)
end

------------------------------------------------------------------------

function RoomService.init()
	roomListEvent = Remotes.event("RoomList")
	roomUpdatedEvent = Remotes.event("RoomUpdated")
	for name in handlers do
		bindRequest(name)
	end
end

function RoomService.start()
	local function onPlayerAdded(player: Player)
		if hooks.matchServer then
			return -- 매치 서버: 로비 방 목록이 없어요
		end
		roomListEvent:FireClient(player, currentListings())
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		leaveRoom(player)
		lastRequestAt[player] = nil
	end)
end

return RoomService
