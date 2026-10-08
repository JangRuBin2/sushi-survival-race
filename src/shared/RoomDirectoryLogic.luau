--!strict
-- 서버 간 방 목록 (GDD 11.2, m4-11). 순수 로직이에요 (Roblox API 없음).
-- 로비 서버마다 자기 공개·대기 중 방을 MemoryStore SortedMap "RoomDirectory"에 올리고(키 "<JobId>:<roomId>"),
-- 다른 서버 항목을 읽어 이 서버 목록 뒤에 붙여요. 클라이언트가 보는 다른 서버 방 id = 그 키 (":"가 있어요).
-- 이 서버 방 id는 숫자라 ":"가 없어서 둘이 섞이지 않아요.

local RoomLogic = require(script.Parent.RoomLogic)
local Types = require(script.Parent.Types)

local RoomDirectoryLogic = {}

RoomDirectoryLogic.MAX_LISTINGS = 50
local MAX_FIELD = 64

-- MemoryStore에 올리는 값 (updatedAt = os.time())
export type Entry = {
	jobId: string,
	roomId: string,
	name: string,
	maxPlayers: number,
	memberCount: number,
	state: Types.RoomState,
	updatedAt: number,
}

-- 비공개 방 코드 항목 (SortedMap "RoomCodes", 키 = 코드)
export type CodeEntry = {
	jobId: string,
	roomId: string,
	updatedAt: number,
}

export type RawItem = { key: string, value: any }

export type QuickJoinPick = {
	kind: "local" | "remote",
	room: RoomLogic.Room?,
	entry: Entry?,
}

function RoomDirectoryLogic.key(jobId: string, roomId: string): string
	return `{jobId}:{roomId}`
end

-- 다른 서버 방 id면 (jobId, roomId). 이 서버 방 id(숫자)면 nil.
function RoomDirectoryLogic.parseKey(id: any): (string?, string?)
	if type(id) ~= "string" or #id > MAX_FIELD * 2 then
		return nil, nil
	end
	local jobId, roomId = string.match(id, "^(.+):([^:]+)$")
	if jobId == nil or roomId == nil then
		return nil, nil
	end
	return jobId, roomId
end

function RoomDirectoryLogic.isRemoteId(id: any): boolean
	return (RoomDirectoryLogic.parseKey(id)) ~= nil
end

local function isText(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

-- 다른 서버가 올린 값의 모양을 확인해요 (깨진 값은 버림)
function RoomDirectoryLogic.readEntry(raw: any): Entry?
	if type(raw) ~= "table" then
		return nil
	end
	if not isText(raw.jobId, MAX_FIELD) or not isText(raw.roomId, MAX_FIELD) or not isText(raw.name, 200) then
		return nil
	end
	if type(raw.maxPlayers) ~= "number" or type(raw.memberCount) ~= "number" or type(raw.updatedAt) ~= "number" then
		return nil
	end
	if raw.state ~= "Waiting" and raw.state ~= "InMatch" then
		return nil
	end
	return {
		jobId = raw.jobId,
		roomId = raw.roomId,
		name = raw.name,
		maxPlayers = raw.maxPlayers,
		memberCount = raw.memberCount,
		state = raw.state,
		updatedAt = raw.updatedAt,
	}
end

function RoomDirectoryLogic.readCodeEntry(raw: any): CodeEntry?
	if type(raw) ~= "table" then
		return nil
	end
	if not isText(raw.jobId, MAX_FIELD) or not isText(raw.roomId, MAX_FIELD) or type(raw.updatedAt) ~= "number" then
		return nil
	end
	return { jobId = raw.jobId, roomId = raw.roomId, updatedAt = raw.updatedAt }
end

function RoomDirectoryLogic.isFresh(updatedAt: number, now: number, ttl: number): boolean
	return now - updatedAt <= ttl
end

-- 들어갈 수 있는 다른 서버 방인가: 대기 중, 자리 있음, 만료 전
function RoomDirectoryLogic.canJoin(entry: Entry, now: number, ttl: number): boolean
	return entry.state == "Waiting"
		and entry.memberCount < entry.maxPlayers
		and RoomDirectoryLogic.isFresh(entry.updatedAt, now, ttl)
end

-- 이 서버 방 → 올릴 항목 (공개·대기 중만, 나머지는 nil)
function RoomDirectoryLogic.entryFor(room: RoomLogic.Room, jobId: string, now: number): Entry?
	if room.isPrivate or room.state ~= "Waiting" then
		return nil
	end
	return {
		jobId = jobId,
		roomId = room.id,
		name = room.name,
		maxPlayers = room.maxPlayers,
		memberCount = #room.members,
		state = room.state,
		updatedAt = now,
	}
end

-- MemoryStore에서 읽은 항목을 정리해요: 깨진 값·이 서버 항목·만료된 항목을 빼고, 같은 키는 최신 하나만.
function RoomDirectoryLogic.cleanRemote(items: { RawItem }, myJobId: string, now: number, ttl: number): { Entry }
	local byKey: { [string]: Entry } = {}
	for _, item in items do
		local entry = RoomDirectoryLogic.readEntry(item.value)
		if entry == nil or entry.jobId == myJobId or not RoomDirectoryLogic.isFresh(entry.updatedAt, now, ttl) then
			continue
		end
		local key = RoomDirectoryLogic.key(entry.jobId, entry.roomId)
		local existing = byKey[key]
		if existing == nil or existing.updatedAt < entry.updatedAt then
			byKey[key] = entry
		end
	end
	local list = {}
	for _, entry in byKey do
		table.insert(list, entry)
	end
	-- 대기 중 → 사람 많은 방 → 키 순 (서버마다 같은 순서로 보이게)
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.state ~= b.state then
			return a.state == "Waiting"
		end
		if a.memberCount ~= b.memberCount then
			return a.memberCount > b.memberCount
		end
		return RoomDirectoryLogic.key(a.jobId, a.roomId) < RoomDirectoryLogic.key(b.jobId, b.roomId)
	end)
	return list
end

-- 클라이언트에 보내는 목록: 이 서버 방이 먼저, 그다음 다른 서버 방(remote = true), 최대 limit개.
-- remote는 cleanRemote를 거친 목록이어도 되고 날것이어도 돼요 (여기서 한 번 더 걸러요).
function RoomDirectoryLogic.merge(
	localListings: { Types.RoomListing },
	remote: { Entry },
	myJobId: string,
	now: number,
	ttl: number,
	limit: number?
): { Types.RoomListing }
	local max = limit or RoomDirectoryLogic.MAX_LISTINGS
	local result: { Types.RoomListing } = {}
	local seen: { [string]: boolean } = {}
	for _, listing in localListings do
		if #result >= max then
			return result
		end
		if seen[listing.id] then
			continue
		end
		seen[listing.id] = true
		table.insert(result, listing)
	end
	local items = table.create(#remote) :: { RawItem }
	for i, entry in remote do
		items[i] = { key = RoomDirectoryLogic.key(entry.jobId, entry.roomId), value = entry }
	end
	for _, entry in RoomDirectoryLogic.cleanRemote(items, myJobId, now, ttl) do
		if #result >= max then
			break
		end
		local id = RoomDirectoryLogic.key(entry.jobId, entry.roomId)
		if seen[id] then
			continue
		end
		seen[id] = true
		table.insert(result, {
			id = id,
			name = entry.name,
			maxPlayers = entry.maxPlayers,
			memberCount = entry.memberCount,
			state = entry.state,
			remote = true,
		})
	end
	return result
end

-- 빠른 참가: 이 서버 방 → 다른 서버 방(대기 중·자리 있음·사람 많은 순) → 없음(nil = 새 방)
function RoomDirectoryLogic.pickQuickJoin(
	localRooms: { RoomLogic.Room },
	remote: { Entry },
	myJobId: string,
	now: number,
	ttl: number
): QuickJoinPick?
	local room = RoomLogic.pickQuickJoin(localRooms)
	if room then
		return { kind = "local", room = room, entry = nil }
	end
	local items = table.create(#remote) :: { RawItem }
	for i, entry in remote do
		items[i] = { key = RoomDirectoryLogic.key(entry.jobId, entry.roomId), value = entry }
	end
	for _, entry in RoomDirectoryLogic.cleanRemote(items, myJobId, now, ttl) do
		if RoomDirectoryLogic.canJoin(entry, now, ttl) then
			return { kind = "remote", room = nil, entry = entry }
		end
	end
	return nil
end

return RoomDirectoryLogic
