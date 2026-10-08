--!strict
-- TeleportService·MemoryStoreService를 감싼 얇은 층 (m4-11). 서비스가 아니라 init/start가 없어요.
-- PlaceService·RoomDirectory는 이 Backend 모양만 써요 — Studio·흉내 모드·테스트에서는 fake()로 바꿔 끼워요.
--   real()  실제 Roblox API (퍼블리시된 서버)
--   fake(onTeleport)  메모리 저장소 + 텔레포트 대신 onTeleport 호출 (Studio)
-- 모든 함수는 실패하면 에러를 던질 수 있어요 — 부르는 쪽이 pcall해요.

local HttpService = game:GetService("HttpService")

local PlaceBackend = {}

export type TeleportRequest = {
	placeId: number,
	accessCode: string?, -- 예약 서버(ReservedServerAccessCode)
	serverInstanceId: string?, -- 특정 서버(ServerInstanceId)
	data: any?, -- TeleportData (클라이언트를 거쳐요 — 받는 쪽은 힌트로만)
	fallback: TeleportRequest?, -- 실패하면 다음 시도부터 이 요청으로 (예: 원래 로비 서버가 없으면 아무 로비)
}

export type RawItem = { key: string, value: any }
export type Transform = (old: any) -> any
export type FailHandler = (player: Player, result: string, message: string) -> ()
export type TeleportHandler = (players: { Player }, request: TeleportRequest) -> ()

export type Backend = {
	isFake: boolean,
	jobId: string,
	privateServerId: string,
	reserveServer: (placeId: number) -> (string, string), -- (accessCode, privateServerId)
	teleport: (players: { Player }, request: TeleportRequest) -> (),
	onTeleportFailed: (fn: FailHandler) -> (),
	joinData: (player: Player) -> any,
	hashGet: (map: string, key: string) -> any,
	hashSet: (map: string, key: string, value: any, ttl: number) -> (),
	sortedGet: (map: string, key: string) -> any,
	sortedSet: (map: string, key: string, value: any, ttl: number) -> (),
	sortedRemove: (map: string, key: string) -> (),
	sortedRange: (map: string, count: number) -> { RawItem },
	sortedUpdate: (map: string, key: string, transform: Transform, ttl: number) -> any,
}

function PlaceBackend.real(): Backend
	local TeleportService = game:GetService("TeleportService")
	local MemoryStoreService = game:GetService("MemoryStoreService")

	local hashMaps: { [string]: MemoryStoreHashMap } = {}
	local sortedMaps: { [string]: MemoryStoreSortedMap } = {}
	local function hash(name: string): MemoryStoreHashMap
		local map = hashMaps[name]
		if map == nil then
			map = MemoryStoreService:GetHashMap(name)
			hashMaps[name] = map
		end
		return map :: MemoryStoreHashMap
	end
	local function sorted(name: string): MemoryStoreSortedMap
		local map = sortedMaps[name]
		if map == nil then
			map = MemoryStoreService:GetSortedMap(name)
			sortedMaps[name] = map
		end
		return map :: MemoryStoreSortedMap
	end

	local function options(request: TeleportRequest): TeleportOptions
		local opts = Instance.new("TeleportOptions")
		if request.accessCode then
			opts.ReservedServerAccessCode = request.accessCode
		end
		if request.serverInstanceId then
			opts.ServerInstanceId = request.serverInstanceId
		end
		if request.data ~= nil then
			opts:SetTeleportData(request.data)
		end
		return opts
	end

	return {
		isFake = false,
		jobId = game.JobId,
		privateServerId = game.PrivateServerId,
		reserveServer = function(placeId: number): (string, string)
			local accessCode, privateServerId = TeleportService:ReserveServer(placeId)
			return accessCode, privateServerId
		end,
		teleport = function(players: { Player }, request: TeleportRequest)
			TeleportService:TeleportAsync(request.placeId, players, options(request))
		end,
		onTeleportFailed = function(fn: FailHandler)
			TeleportService.TeleportInitFailed:Connect(
				function(player: Player, result: Enum.TeleportResult, message: string)
					fn(player, result.Name, message)
				end
			)
		end,
		joinData = function(player: Player): any
			local ok, data = pcall(function()
				return player:GetJoinData()
			end)
			if ok and type(data) == "table" then
				return data.TeleportData
			end
			return nil
		end,
		hashGet = function(map: string, key: string): any
			return hash(map):GetAsync(key)
		end,
		hashSet = function(map: string, key: string, value: any, ttl: number)
			hash(map):SetAsync(key, value, ttl)
		end,
		sortedGet = function(map: string, key: string): any
			return sorted(map):GetAsync(key)
		end,
		sortedSet = function(map: string, key: string, value: any, ttl: number)
			sorted(map):SetAsync(key, value, ttl)
		end,
		sortedRemove = function(map: string, key: string)
			sorted(map):RemoveAsync(key)
		end,
		sortedRange = function(map: string, count: number): { RawItem }
			local items = sorted(map):GetRangeAsync(Enum.SortDirection.Ascending, count)
			local list: { RawItem } = {}
			for _, item in items do
				table.insert(list, { key = item.key, value = item.value })
			end
			return list
		end,
		sortedUpdate = function(map: string, key: string, transform: Transform, ttl: number): any
			return sorted(map):UpdateAsync(key, transform, ttl)
		end,
	}
end

-- 메모리 저장소. 만료는 os.clock() 기준으로 흉내 내요.
function PlaceBackend.fake(onTeleport: TeleportHandler): Backend
	type Cell = { value: any, expiresAt: number }
	local maps: { [string]: { [string]: Cell } } = {}
	local function mapOf(name: string): { [string]: Cell }
		local map = maps[name]
		if map == nil then
			map = {}
			maps[name] = map
		end
		return map :: { [string]: Cell }
	end
	local function get(name: string, key: string): any
		local cell = mapOf(name)[key]
		if cell == nil then
			return nil
		end
		if os.clock() > cell.expiresAt then
			mapOf(name)[key] = nil
			return nil
		end
		return cell.value
	end
	local function set(name: string, key: string, value: any, ttl: number)
		mapOf(name)[key] = { value = value, expiresAt = os.clock() + ttl }
	end

	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	return {
		isFake = true,
		jobId = jobId,
		privateServerId = if game.PrivateServerId ~= "" then game.PrivateServerId else "studio-private",
		reserveServer = function(_placeId: number): (string, string)
			return "fake-access-code", `fake-{HttpService:GenerateGUID(false)}`
		end,
		teleport = function(players: { Player }, request: TeleportRequest)
			onTeleport(players, request)
		end,
		onTeleportFailed = function(_fn: FailHandler) end,
		joinData = function(_player: Player): any
			return nil
		end,
		hashGet = get,
		hashSet = set,
		sortedGet = get,
		sortedSet = set,
		sortedRemove = function(map: string, key: string)
			mapOf(map)[key] = nil
		end,
		sortedRange = function(map: string, count: number): { RawItem }
			local keys = {}
			for key in mapOf(map) do
				if get(map, key) ~= nil then
					table.insert(keys, key)
				end
			end
			table.sort(keys)
			local list: { RawItem } = {}
			for i = 1, math.min(count, #keys) do
				table.insert(list, { key = keys[i], value = get(map, keys[i]) })
			end
			return list
		end,
		sortedUpdate = function(map: string, key: string, transform: Transform, ttl: number): any
			local new = transform(get(map, key))
			if new ~= nil then
				set(map, key, new, ttl)
			end
			return new
		end,
	}
end

return PlaceBackend
