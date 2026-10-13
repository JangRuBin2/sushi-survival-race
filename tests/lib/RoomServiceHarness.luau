--!strict
-- 가짜 Roblox 환경으로 src/server/RoomService.luau를 직접 돌리는 하네스 (m5-26 QA 하네스에서 가져옴).
-- 가짜 필터는 "badword"를 #######로 가려요. env.join / env.call / env.lastSnapshot / env.lastList,
-- env.filterFails = true면 필터가 오류, env.filterCalls에 필터 호출 기록.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./RobloxRequire")

local Shared = RobloxRequire.root("src/shared")

local function newSignal(): any
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

local function loadRoomService(): any
	local env: any = {}
	env.clock = 1000
	env.players = {}
	env.filterCalls = {}
	env.fired = {}
	env.warnings = {}
	env.remotes = {}
	env.filterFails = false

	local Players: any = { PlayerAdded = newSignal(), PlayerRemoving = newSignal() }
	function Players.GetPlayers(_self)
		local list = {}
		for _, p in env.players do
			if p.Parent ~= nil then
				table.insert(list, p)
			end
		end
		return list
	end
	function Players.GetPlayerByUserId(_self, userId: number)
		local p = env.players[userId]
		return if p and p.Parent ~= nil then p else nil
	end
	local guid = 0
	local services: { [string]: any } = {
		Players = Players,
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return `guid-{guid}`
			end,
		},
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		TextService = {
			-- 가짜 필터: "badword"를 ####### 로 가려요
			FilterStringAsync = function(_self, text: string, userId: number, _context: any)
				table.insert(env.filterCalls, { text = text, userId = userId })
				if env.filterFails then
					error("filter down")
				end
				return {
					GetNonChatStringForBroadcastAsync = function()
						return (string.gsub(text, "badword", "#######"))
					end,
				}
			end,
		},
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
	}
	local function remote(name: string): any
		if env.remotes[name] == nil then
			local r: any = { Name = name }
			function r.FireClient(_, player, ...)
				table.insert(env.fired, { name = name, player = player, args = table.pack(...) })
			end
			env.remotes[name] = r
		end
		return env.remotes[name]
	end
	local rngState = 0
	local environment = {
		game = {
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
		},
		script = { Parent = {} },
		require = function(target: any)
			if target.__shared == "Remotes" then
				return { fn = remote, event = remote }
			end
			return RobloxRequire.require((Shared :: any)[assert(target.__shared, "server module")])
		end,
		Random = {
			new = function()
				return {
					NextInteger = function(_self, min: number, _max: number): number
						rngState += 1
						return min + rngState
					end,
				}
			end,
		},
		Enum = { TextFilterContext = { PublicChat = "PublicChat" } },
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
			defer = function(fn, ...)
				fn(...)
			end,
			delay = function(_seconds, _fn, ...)
				return { delayed = true }
			end,
			cancel = function() end,
		},
		os = {
			clock = function()
				return env.clock
			end,
			time = os.time,
		},
		warn = function(...)
			table.insert(env.warnings, table.concat({ ... }, " "))
		end,
		workspace = {
			GetServerTimeNow = function()
				return env.clock
			end,
		},
	}
	env.Service = luau.load(
		fs.readFile("src/server/RoomService.luau"),
		{ debugName = "RoomService", environment = environment }
	)()
	env.Service.init()
	env.Service.start()

	function env.join(userId: number, displayName: string?): any
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			DisplayName = displayName or `Name{userId}`,
			Parent = Players,
		}
		env.players[userId] = player
		Players.PlayerAdded:Fire(player)
		return player
	end
	-- 리모트 요청 하나 (요청 간격 0.3초보다 길게 시계를 움직여요)
	function env.call(name: string, player: any, ...: any): (any, any)
		env.clock += 1
		return env.remotes[name].OnServerInvoke(player, ...)
	end
	function env.lastSnapshot(player: any): any
		for i = #env.fired, 1, -1 do
			local f = env.fired[i]
			if f.name == "RoomUpdated" and f.player == player then
				return f.args[1]
			end
		end
		return nil
	end
	function env.lastList(player: any): any
		for i = #env.fired, 1, -1 do
			local f = env.fired[i]
			if f.name == "RoomList" and f.player == player then
				return f.args[1]
			end
		end
		return nil
	end
	return env
end

return { load = loadRoomService }
