--!strict
-- 서버 간 방 목록·방 코드 (GDD 11.2, m4-11). 로비 역할에서만 PlaceService가 start해요. 서비스가 아니에요.
--   SortedMap "RoomDirectory"  키 "<JobId>:<roomId>" → 공개·대기 중 방 (Config.Teleport.DirectoryRefresh마다, TTL DirectoryTtl)
--   SortedMap "RoomCodes"      키 코드 → { jobId, roomId } (비공개 방, 만들 때 UpdateAsync로 예약)
-- MemoryStore 요청이 실패하면 경고만 하고 이 서버 방만 보여 줘요 (게임은 계속). 판단은 RoomDirectoryLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomDirectoryLogic = require(ReplicatedStorage.Shared.RoomDirectoryLogic)
local Types = require(ReplicatedStorage.Shared.Types)

local PlaceBackend = require(script.Parent.PlaceBackend)
local RoomService = require(script.Parent.RoomService)

local RoomDirectory = {}

local DIRECTORY_MAP = "RoomDirectory"
local CODES_MAP = "RoomCodes"
local RANGE_COUNT = 200 -- GetRangeAsync 한 번에 읽는 최대 개수
local WARN_INTERVAL = 60 -- 같은 경고를 다시 남기기까지(초)

local backend: PlaceBackend.Backend? = nil
local jobId = ""
local remoteCache: { RoomDirectoryLogic.Entry } = {}
local cacheSignature = ""
local published: { [string]: boolean } = {} -- 올려 둔 디렉터리 키
local publishedCodes: { [string]: string } = {} -- 올려 둔 코드 → roomId
local lastWarnAt: { [string]: number } = {}

local function warnOnce(what: string, err: any)
	local now = os.clock()
	local last = lastWarnAt[what]
	if last and now - last < WARN_INTERVAL then
		return
	end
	lastWarnAt[what] = now
	warn(`[RoomDirectory] {what} failed (showing this server's rooms only): {err}`)
end

local function ttl(): number
	return Config.Teleport.DirectoryTtl
end

local function signature(entries: { RoomDirectoryLogic.Entry }): string
	local parts = table.create(#entries)
	for i, entry in entries do
		parts[i] = `{entry.jobId}:{entry.roomId}:{entry.name}:{entry.memberCount}/{entry.maxPlayers}:{entry.state}`
	end
	return table.concat(parts, "|")
end

-- 이 서버 방 올리기 + 사라진 방 지우기 + 코드 갱신
local function publish()
	local b = backend
	if b == nil then
		return
	end
	local now = os.time()
	local current: { [string]: boolean } = {}
	local currentCodes: { [string]: string } = {}
	for _, room in RoomService.listRooms() do
		local entry = RoomDirectoryLogic.entryFor(room, jobId, now)
		if entry then
			local key = RoomDirectoryLogic.key(jobId, room.id)
			current[key] = true
			local ok, err = pcall(b.sortedSet, DIRECTORY_MAP, key, entry, ttl())
			if ok then
				published[key] = true
			else
				warnOnce("publish", err)
			end
		end
		if room.code then
			currentCodes[room.code] = room.id
			local ok, err = pcall(b.sortedSet, CODES_MAP, room.code, {
				jobId = jobId,
				roomId = room.id,
				updatedAt = now,
			}, ttl())
			if not ok then
				warnOnce("publish code", err)
			end
		end
	end
	for key in published do
		if not current[key] then
			published[key] = nil
			pcall(b.sortedRemove, DIRECTORY_MAP, key)
		end
	end
	publishedCodes = currentCodes
end

local function fetch()
	local b = backend
	if b == nil then
		return
	end
	local ok, items = pcall(b.sortedRange, DIRECTORY_MAP, RANGE_COUNT)
	local entries: { RoomDirectoryLogic.Entry } = {}
	if ok then
		entries = RoomDirectoryLogic.cleanRemote(items, jobId, os.time(), ttl())
	else
		warnOnce("read", items)
	end
	remoteCache = entries
	local sig = signature(entries)
	if sig ~= cacheSignature then
		cacheSignature = sig
		RoomService.refreshList()
	end
end

local function loop()
	while true do
		publish()
		fetch()
		task.wait(Config.Teleport.DirectoryRefresh)
	end
end

------------------------------------------------------------------------

-- 이 서버 목록 뒤에 다른 서버 방을 붙여요 (yield 없음, 캐시만 씀)
function RoomDirectory.decorate(localListings: { Types.RoomListing }): { Types.RoomListing }
	return RoomDirectoryLogic.merge(localListings, remoteCache, jobId, os.time(), ttl())
end

-- 다른 서버 방을 저장소에서 다시 읽어 들어갈 수 있는지 확인해요 (yield). 못 들어가면 (nil, 이유)
function RoomDirectory.findRemote(id: string): (RoomDirectoryLogic.Entry?, string?)
	local b = backend
	local remoteJobId = RoomDirectoryLogic.parseKey(id)
	if b == nil or remoteJobId == nil or remoteJobId == jobId then
		return nil, "방을 찾을 수 없어요"
	end
	local ok, raw = pcall(b.sortedGet, DIRECTORY_MAP, id)
	if not ok then
		warnOnce("find", raw)
		return nil, "지금은 다른 서버 방에 들어갈 수 없어요"
	end
	local entry = RoomDirectoryLogic.readEntry(raw)
	if entry == nil or RoomDirectoryLogic.key(entry.jobId, entry.roomId) ~= id then
		return nil, "방을 찾을 수 없어요"
	end
	if not RoomDirectoryLogic.canJoin(entry, os.time(), ttl()) then
		return nil,
			if entry.memberCount >= entry.maxPlayers
				then "방이 꽉 찼어요"
				else "이미 게임 중인 방이에요"
	end
	return entry, nil
end

-- 다른 서버의 비공개 방 코드 (yield). 없으면 nil
function RoomDirectory.lookupCode(code: string): RoomDirectoryLogic.CodeEntry?
	local b = backend
	if b == nil then
		return nil
	end
	local ok, raw = pcall(b.sortedGet, CODES_MAP, code)
	if not ok then
		warnOnce("lookup code", raw)
		return nil
	end
	local entry = RoomDirectoryLogic.readCodeEntry(raw)
	if entry == nil or entry.jobId == jobId or not RoomDirectoryLogic.isFresh(entry.updatedAt, os.time(), ttl()) then
		return nil
	end
	return entry
end

-- 빠른 참가용 다른 서버 방 (캐시에서 고르고 저장소에서 다시 확인)
function RoomDirectory.pickRemoteQuickJoin(): RoomDirectoryLogic.Entry?
	local pick = RoomDirectoryLogic.pickQuickJoin({}, remoteCache, jobId, os.time(), ttl())
	if pick == nil or pick.entry == nil then
		return nil
	end
	local entry = pick.entry :: RoomDirectoryLogic.Entry
	return (RoomDirectory.findRemote(RoomDirectoryLogic.key(entry.jobId, entry.roomId)))
end

-- 코드를 이 서버 방으로 예약해요 (yield). 다른 서버가 쓰는 코드면 false. 요청이 실패하면 에러를 던져요.
function RoomDirectory.claimCode(code: string, roomId: string): boolean
	local b = backend
	if b == nil then
		return true
	end
	local now = os.time()
	local result = b.sortedUpdate(CODES_MAP, code, function(old: any): any
		local existing = RoomDirectoryLogic.readCodeEntry(old)
		if existing and existing.jobId ~= jobId and RoomDirectoryLogic.isFresh(existing.updatedAt, now, ttl()) then
			return nil -- 다른 서버 방: 바꾸지 않아요
		end
		return { jobId = jobId, roomId = roomId, updatedAt = now }
	end, ttl())
	local entry = RoomDirectoryLogic.readCodeEntry(result)
	return entry ~= nil and entry.jobId == jobId and entry.roomId == roomId
end

function RoomDirectory.releaseCode(code: string)
	local b = backend
	if b == nil then
		return
	end
	publishedCodes[code] = nil
	local ok, raw = pcall(b.sortedGet, CODES_MAP, code)
	local entry = if ok then RoomDirectoryLogic.readCodeEntry(raw) else nil
	if entry and entry.jobId == jobId then
		pcall(b.sortedRemove, CODES_MAP, code)
	end
end

-- 방이 닫히거나 출발했어요: 목록에서 바로 지워요
function RoomDirectory.removeRoom(roomId: string)
	local b = backend
	local key = RoomDirectoryLogic.key(jobId, roomId)
	if b == nil or not published[key] then
		return
	end
	published[key] = nil
	pcall(b.sortedRemove, DIRECTORY_MAP, key)
end

function RoomDirectory.jobId(): string
	return jobId
end

function RoomDirectory.start(newBackend: PlaceBackend.Backend)
	backend = newBackend
	jobId = newBackend.jobId
	task.spawn(loop)
	game:BindToClose(function()
		local b = backend
		if b == nil then
			return
		end
		for key in published do
			pcall(b.sortedRemove, DIRECTORY_MAP, key)
		end
		for code in publishedCodes do
			pcall(b.sortedRemove, CODES_MAP, code)
		end
	end)
end

return RoomDirectory
