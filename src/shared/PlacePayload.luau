--!strict
-- 플레이스 사이에 오가는 데이터 (GDD 11.2, m4-11). 순수 로직이에요 (Roblox API 없음).
--
--   manifest      로비 → MemoryStore "MatchManifest"(키 = 매치 서버 PrivateServerId). 매치 서버가 믿는 유일한 값.
--   matchHint     로비 → 매치 텔레포트 데이터. roomKey만 (힌트일 뿐, 판단에 쓰지 않아요).
--   returnTicket  매치 → 로비 텔레포트 데이터. 같은 방으로 다시 묶을 때 써요.
--   joinTicket    로비 → 다른 로비 텔레포트 데이터. 도착한 서버가 그 방에 넣어 줘요.
--   matchResult   매치 → MemoryStore "MatchResult"(키 = roomKey). 우승자(단상)와 방 정보(복귀 때 믿는 값).
--
-- 텔레포트 데이터는 클라이언트를 거쳐 바뀔 수 있어요. 그래서 validate*는 모양·크기·범위를 모두 검사하고,
-- 티켓으로 할 수 있는 일은 "CreateRoom과 같은 검증을 거친 설정의 방을 만들기 / 공개 방에 들어가기"뿐이에요.

local Config = require(script.Parent.Config)
local RoomLogic = require(script.Parent.RoomLogic)
local Types = require(script.Parent.Types)

local PlacePayload = {}

PlacePayload.VERSION = 1
PlacePayload.MAX_MEMBERS = 24
PlacePayload.MAX_KEY_LENGTH = 64 -- roomKey, jobId (GUID 36자)
PlacePayload.MAX_ROOM_ID_LENGTH = 16

export type Settings = {
	maxPlayers: number,
	isPrivate: boolean,
	name: string,
}

export type Manifest = {
	v: number,
	roomKey: string,
	settings: Settings,
	hostUserId: number,
	memberUserIds: { number },
	lobbyJobId: string,
	createdAt: number,
}

export type MatchHint = {
	v: number,
	kind: "match",
	roomKey: string,
}

export type ReturnTicket = {
	v: number,
	kind: "return",
	roomKey: string,
	settings: Settings,
	hostUserId: number,
	memberUserIds: { number },
}

export type JoinTicket = {
	v: number,
	kind: "join",
	roomId: string?, -- 공개 방 id (그 서버의 방)
	code: string?, -- 비공개 방 코드
}

export type MatchResult = {
	v: number,
	roomKey: string,
	winnerUserId: number?,
	winnerName: string?,
	appearanceId: string?,
	settings: Settings,
	hostUserId: number,
	memberUserIds: { number },
}

export type ManifestParams = {
	roomKey: string,
	settings: Settings,
	hostUserId: number,
	memberUserIds: { number },
	lobbyJobId: string,
	createdAt: number,
}

export type ArrivalDecision = "wait" | "start" | "abort"

------------------------------------------------------------------------
-- 검사 도우미

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < 2 ^ 53 and value % 1 == 0
end

local function isKey(value: any, maxLength: number): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= maxLength
		and string.match(value, "^[%w%-_:{}]+$") ~= nil
end

local function isShortString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value <= maxLength and utf8.len(value) ~= nil
end

-- 방 설정: CreateRoom과 같은 범위 (maxPlayers는 고를 수 있는 값, 이름은 정리된 이름 길이 이하)
function PlacePayload.validateSettings(raw: any): (Settings?, string?)
	if type(raw) ~= "table" then
		return nil, "settings"
	end
	if type(raw.maxPlayers) ~= "number" or not table.find(Config.Room.MaxPlayerOptions, raw.maxPlayers) then
		return nil, "maxPlayers"
	end
	if type(raw.isPrivate) ~= "boolean" then
		return nil, "isPrivate"
	end
	local name = raw.name
	if type(name) ~= "string" or utf8.len(name) == nil then
		return nil, "name"
	end
	local cleaned = RoomLogic.cleanName(name)
	if cleaned == nil or cleaned ~= name then
		return nil, "name" -- 정리하면 달라지는 이름(너무 김·제어 문자·앞뒤 공백)은 받지 않아요
	end
	return { maxPlayers = raw.maxPlayers, isPrivate = raw.isPrivate, name = name }, nil
end

-- 멤버 userId 목록: 1~MAX_MEMBERS명, 정수, 중복 없음
function PlacePayload.validateMembers(raw: any): ({ number }?, string?)
	if type(raw) ~= "table" then
		return nil, "members"
	end
	local count = #raw
	if count < 1 or count > PlacePayload.MAX_MEMBERS then
		return nil, "member count"
	end
	local n = 0
	for _ in raw do
		n += 1
	end
	if n ~= count then
		return nil, "members not a list"
	end
	local seen = {}
	local list = table.create(count)
	for i = 1, count do
		local userId = raw[i]
		if not isUserId(userId) then
			return nil, "member userId"
		end
		if seen[userId] then
			return nil, "duplicate member"
		end
		seen[userId] = true
		list[i] = userId
	end
	return list, nil
end

local function checkVersion(raw: any): boolean
	return type(raw) == "table" and raw.v == PlacePayload.VERSION
end

------------------------------------------------------------------------
-- 만들기

function PlacePayload.settingsOf(room: { maxPlayers: number, isPrivate: boolean, name: string }): Settings
	return { maxPlayers = room.maxPlayers, isPrivate = room.isPrivate, name = room.name }
end

function PlacePayload.manifest(params: ManifestParams): Manifest
	return {
		v = PlacePayload.VERSION,
		roomKey = params.roomKey,
		settings = table.clone(params.settings),
		hostUserId = params.hostUserId,
		memberUserIds = table.clone(params.memberUserIds),
		lobbyJobId = params.lobbyJobId,
		createdAt = params.createdAt,
	}
end

function PlacePayload.matchHint(roomKey: string): MatchHint
	return { v = PlacePayload.VERSION, kind = "match", roomKey = roomKey }
end

function PlacePayload.returnTicket(
	roomKey: string,
	settings: Settings,
	hostUserId: number,
	memberUserIds: { number }
): ReturnTicket
	return {
		v = PlacePayload.VERSION,
		kind = "return",
		roomKey = roomKey,
		settings = table.clone(settings),
		hostUserId = hostUserId,
		memberUserIds = table.clone(memberUserIds),
	}
end

function PlacePayload.joinTicket(roomId: string?, code: string?): JoinTicket
	return { v = PlacePayload.VERSION, kind = "join", roomId = roomId, code = code }
end

function PlacePayload.matchResult(
	manifest: {
		roomKey: string,
		settings: Settings,
		hostUserId: number,
		memberUserIds: { number },
	},
	winner: { userId: number, name: string, appearanceId: string }?
): MatchResult
	return {
		v = PlacePayload.VERSION,
		roomKey = manifest.roomKey,
		winnerUserId = winner and winner.userId,
		winnerName = winner and winner.name,
		appearanceId = winner and winner.appearanceId,
		settings = table.clone(manifest.settings),
		hostUserId = manifest.hostUserId,
		memberUserIds = table.clone(manifest.memberUserIds),
	}
end

------------------------------------------------------------------------
-- 검증

function PlacePayload.validateManifest(raw: any): (Manifest?, string?)
	if not checkVersion(raw) then
		return nil, "version"
	end
	if not isKey(raw.roomKey, PlacePayload.MAX_KEY_LENGTH) then
		return nil, "roomKey"
	end
	local settings, settingsErr = PlacePayload.validateSettings(raw.settings)
	if settings == nil then
		return nil, settingsErr
	end
	local members, membersErr = PlacePayload.validateMembers(raw.memberUserIds)
	if members == nil then
		return nil, membersErr
	end
	if #members > settings.maxPlayers then
		return nil, "member count"
	end
	if not isUserId(raw.hostUserId) then
		return nil, "hostUserId"
	end
	if not isShortString(raw.lobbyJobId, PlacePayload.MAX_KEY_LENGTH) then
		return nil, "lobbyJobId"
	end
	if type(raw.createdAt) ~= "number" or raw.createdAt ~= raw.createdAt then
		return nil, "createdAt"
	end
	return {
		v = PlacePayload.VERSION,
		roomKey = raw.roomKey,
		settings = settings,
		hostUserId = raw.hostUserId,
		memberUserIds = members,
		lobbyJobId = raw.lobbyJobId,
		createdAt = raw.createdAt,
	},
		nil
end

-- 받은 사람(userId)이 멤버 목록에 없으면 거부해요 (남의 방 티켓을 들고 오지 못하게).
function PlacePayload.validateReturnTicket(raw: any, userId: number): (ReturnTicket?, string?)
	if not checkVersion(raw) or raw.kind ~= "return" then
		return nil, "version"
	end
	if not isKey(raw.roomKey, PlacePayload.MAX_KEY_LENGTH) then
		return nil, "roomKey"
	end
	local settings, settingsErr = PlacePayload.validateSettings(raw.settings)
	if settings == nil then
		return nil, settingsErr
	end
	local members, membersErr = PlacePayload.validateMembers(raw.memberUserIds)
	if members == nil then
		return nil, membersErr
	end
	if #members > settings.maxPlayers then
		return nil, "member count"
	end
	if not isUserId(raw.hostUserId) then
		return nil, "hostUserId"
	end
	if not table.find(members, userId) then
		return nil, "not a member"
	end
	return PlacePayload.returnTicket(raw.roomKey, settings, raw.hostUserId, members), nil
end

function PlacePayload.validateJoinTicket(raw: any): (JoinTicket?, string?)
	if not checkVersion(raw) or raw.kind ~= "join" then
		return nil, "version"
	end
	local roomId, code = raw.roomId, raw.code
	if (roomId == nil) == (code == nil) then
		return nil, "roomId or code"
	end
	if roomId ~= nil and not isKey(roomId, PlacePayload.MAX_ROOM_ID_LENGTH) then
		return nil, "roomId"
	end
	if code ~= nil and not RoomLogic.isValidCode(code) then
		return nil, "code"
	end
	return PlacePayload.joinTicket(roomId, code), nil
end

function PlacePayload.validateMatchHint(raw: any): (MatchHint?, string?)
	if not checkVersion(raw) or raw.kind ~= "match" then
		return nil, "version"
	end
	if not isKey(raw.roomKey, PlacePayload.MAX_KEY_LENGTH) then
		return nil, "roomKey"
	end
	return PlacePayload.matchHint(raw.roomKey), nil
end

function PlacePayload.validateMatchResult(raw: any): (MatchResult?, string?)
	if not checkVersion(raw) then
		return nil, "version"
	end
	if not isKey(raw.roomKey, PlacePayload.MAX_KEY_LENGTH) then
		return nil, "roomKey"
	end
	local settings, settingsErr = PlacePayload.validateSettings(raw.settings)
	if settings == nil then
		return nil, settingsErr
	end
	local members, membersErr = PlacePayload.validateMembers(raw.memberUserIds)
	if members == nil then
		return nil, membersErr
	end
	if not isUserId(raw.hostUserId) then
		return nil, "hostUserId"
	end
	local winner: { userId: number, name: string, appearanceId: string }? = nil
	if raw.winnerUserId ~= nil then
		if
			not isUserId(raw.winnerUserId)
			or not isShortString(raw.winnerName, 100)
			or not isShortString(raw.appearanceId, PlacePayload.MAX_KEY_LENGTH)
		then
			return nil, "winner"
		end
		winner = { userId = raw.winnerUserId, name = raw.winnerName, appearanceId = raw.appearanceId }
	end
	return PlacePayload.matchResult({
		roomKey = raw.roomKey,
		settings = settings,
		hostUserId = raw.hostUserId,
		memberUserIds = members,
	}, winner),
		nil
end

------------------------------------------------------------------------
-- 판단

-- 매치 서버의 도착 대기 (GDD 4-1). expected = 매니페스트 멤버 수, arrived = 와 있는 멤버 수.
--   전원 도착 → start (단, minPlayers 미만이면 abort)
--   아직 시간 남음 → wait
--   시간 초과 → minPlayers 이상이면 start, 아니면 abort
-- minPlayers 기본 2 (Studio 흉내 모드는 Config.DEBUG.minPlayersToStart).
function PlacePayload.arrivalReady(
	expected: number,
	arrived: number,
	elapsed: number,
	timeout: number,
	minPlayers: number?
): ArrivalDecision
	local need = minPlayers or 2
	if arrived >= expected then
		return if arrived >= need then "start" else "abort"
	end
	if elapsed < timeout then
		return "wait"
	end
	return if arrived >= need then "start" else "abort"
end

-- 복귀(또는 매치 서버) 방장: 원래 방장이 와 있으면 그 사람, 아니면 가장 먼저 온 사람. 아무도 없으면 nil.
function PlacePayload.pickRestoreHost(hostUserId: number, arrivedInOrder: { number }): number?
	if table.find(arrivedInOrder, hostUserId) then
		return hostUserId
	end
	return arrivedInOrder[1]
end

-- 텔레포트 데이터 종류 (모양만 본 힌트. 실제 검증은 validate*)
function PlacePayload.kindOf(raw: any): ("return" | "join" | "match")?
	if type(raw) ~= "table" then
		return nil
	end
	local kind = raw.kind
	if kind == "return" or kind == "join" or kind == "match" then
		return kind
	end
	return nil
end

-- 방 멤버 정보에서 userId 목록 (들어온 순서)
function PlacePayload.userIdsOf(members: { Types.MemberInfo }): { number }
	local list = table.create(#members)
	for i, member in members do
		list[i] = member.userId
	end
	return list
end

-- 플레이어(UserId가 있는 값) 목록에서 userId 목록 (순서 그대로)
function PlacePayload.userIdsOfPlayers(players: { any }): { number }
	local list = table.create(#players)
	for i, player in players do
		list[i] = player.UserId
	end
	return list
end

return PlacePayload
