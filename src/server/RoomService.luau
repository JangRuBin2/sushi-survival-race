--!strict
-- 방 생성/참가/퇴장/방장/시작 (GDD 3)
-- 규칙 판단은 Shared.RoomLogic(순수 함수)에 맡기고, 여기서는 리모트 검증·상태 보관·방송·자동 시작을 해요.
--
-- MatchService 연결 (방 하나의 매치는 MatchService가 돌려요):
--   RoomService.onMatchStart(fn(room, players))  방이 출발할 때 한 번 불러요. room.state는 이미 "InMatch".
--   RoomService.onMemberLeft(fn(roomId, player)) 매치 중에 누가 방을 나가거나 게임을 떠났을 때.
--   RoomService.endMatch(roomId)                 매치가 끝나면 불러서 방을 대기실로 돌려요 (같은 멤버로 한 판 더).
--   RoomService.getArenaOrigin(roomId)           이 방의 매치 맵을 지을 위치 (방마다 슬롯이 달라요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoomLogic = require(ReplicatedStorage.Shared.RoomLogic)
local Types = require(ReplicatedStorage.Shared.Types)

export type Room = RoomLogic.Room
type MatchStartHandler = (room: Room, players: { Player }) -> ()
type MemberLeftHandler = (roomId: string, player: Player) -> ()

local REQUEST_COOLDOWN = 0.3 -- 같은 플레이어의 방 요청 사이 최소 간격(초)
local NO_MATCH_RETURN_DELAY = 3 -- MatchService가 연결되지 않았을 때 대기실로 돌아오는 시간(초)

local RoomService = {}

local rooms: { [string]: Room } = {}
local roomIdByUser: { [number]: string } = {}
local roomIdByCode: { [string]: string } = {}
local usedSlots: { [number]: boolean } = {}
local autoStartThreads: { [string]: thread } = {}
local lastRequestAt: { [Player]: number } = {}
local nextRoomId = 0
local rng = Random.new()

local matchStartHandler: MatchStartHandler? = nil
local memberLeftHandler: MemberLeftHandler? = nil

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
		local listings = RoomLogic.listPublic(allRooms())
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

	local players = playersOf(room)
	local handler = matchStartHandler
	if handler then
		task.spawn(handler, room, players)
	else
		warn(`[RoomService] room {room.id} started but no match handler is connected; returning to waiting`)
		task.delay(NO_MATCH_RETURN_DELAY, RoomService.endMatch, room.id)
	end
end

-- 정원이 차면 카운트다운을 걸고, 누가 나가서 자리가 비면 취소해요.
local function refreshAutoStart(room: Room)
	if RoomLogic.shouldAutoStart(room) then
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

local function closeRoom(room: Room)
	cancelAutoStart(room)
	rooms[room.id] = nil
	usedSlots[room.slot] = nil
	if room.code then
		roomIdByCode[room.code] = nil
	end
	dirtyRooms[room.id] = nil
	markListChanged()
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

local function createRoom(player: Player, settings: Types.RoomSettings, name: string): Room?
	local code: string? = nil
	if settings.isPrivate then
		code = RoomLogic.generateCode(rng, function(candidate)
			return roomIdByCode[candidate] ~= nil
		end)
		if code == nil then
			return nil
		end
	end

	nextRoomId += 1
	local slot = RoomLogic.nextFreeSlot(usedSlots)
	local room = RoomLogic.newRoom({
		id = tostring(nextRoomId),
		name = name,
		maxPlayers = settings.maxPlayers,
		isPrivate = settings.isPrivate,
		code = code,
		slot = slot,
	}, memberInfo(player))

	rooms[room.id] = room
	usedSlots[slot] = true
	if code then
		roomIdByCode[code] = room.id
	end
	roomIdByUser[player.UserId] = room.id
	markChanged(room)
	return room
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
	roomIdByUser[player.UserId] = nil
	local room = rooms[roomId]
	if room == nil then
		return
	end
	RoomLogic.removeMember(room, player.UserId)

	if player.Parent then
		roomUpdatedEvent:FireClient(player, nil)
	end
	if room.state == "InMatch" and memberLeftHandler then
		task.spawn(memberLeftHandler, room.id, player)
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

local function requireNoRoom(player: Player): string?
	if roomIdByUser[player.UserId] ~= nil then
		return "이미 방에 들어가 있어요"
	end
	return nil
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
	if roomIdByUser[player.UserId] ~= nil then -- 필터가 yield하는 동안 다른 요청으로 방에 들어갔을 수 있어요
		return false, "이미 방에 들어가 있어요"
	end
	local room = createRoom(player, settings, name or RoomLogic.defaultName(player.DisplayName))
	if room == nil then
		return false, "방을 만들 수 없어요. 잠시 뒤 다시 시도해 주세요"
	end
	return true, nil
end

function handlers.JoinRoom(player: Player, roomId: any): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	if type(roomId) ~= "string" then
		return false, "방을 찾을 수 없어요"
	end
	local room = rooms[roomId]
	if room == nil or room.isPrivate then -- 비공개 방은 코드로만 들어가요
		return false, "방을 찾을 수 없어요"
	end
	return joinRoom(player, room)
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
	local room = roomId and rooms[roomId]
	if not room then
		return false, "그 코드의 방이 없어요"
	end
	return joinRoom(player, room)
end

function handlers.QuickJoin(player: Player): (boolean, string?)
	local blocked = requireNoRoom(player)
	if blocked then
		return false, blocked
	end
	local room = RoomLogic.pickQuickJoin(allRooms())
	if room then
		return joinRoom(player, room)
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
	return true, nil
end

function handlers.StartRoom(player: Player): (boolean, string?)
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

function RoomService.init()
	roomListEvent = Remotes.event("RoomList")
	roomUpdatedEvent = Remotes.event("RoomUpdated")
	for name in handlers do
		bindRequest(name)
	end
end

function RoomService.start()
	local function onPlayerAdded(player: Player)
		roomListEvent:FireClient(player, RoomLogic.listPublic(allRooms()))
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
