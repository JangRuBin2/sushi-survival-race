--!strict
-- m4-07 DataService를 가짜 DataStore(라이브 서버 모드)로 돌려 봐요. QA 후 수정 D1(같은 서버 재접속)·D2(해제 뒤 saveNow).
-- 가짜 스케줄러: task.spawn/defer/wait는 코루틴, env.run(steps)이 한 걸음마다 시계를 0.1초 움직이며 깨워요.
-- 저장소의 UpdateAsync는 다음 env.hold번의 요청이 멈춰 있다가(요청이 느린 상황) env.releaseHeld()로 이어져요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)

local function newSignal(spawn: (any, ...any) -> ()): any
	local handlers: { any } = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function()
					local index = table.find(handlers, fn)
					if index then
						table.remove(handlers, index)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do
				spawn(fn, ...)
			end
		end,
	}
end

local function loadEnv(): any
	local env: any = { clock = 100, warnings = {}, held = {}, hold = 0, data = {}, sent = {} }
	local sleepers: { thread } = {}
	local deferred: { any } = {}

	local T = {}
	function T.spawn(fn: any, ...: any)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end
	function T.defer(fn: any, ...: any)
		table.insert(deferred, { fn = fn, args = table.pack(...) })
	end
	function T.wait(_seconds: number?)
		table.insert(sleepers, coroutine.running())
		return coroutine.yield()
	end

	function env.run(steps: number?)
		for _ = 1, steps or 50 do
			env.clock += 0.1
			while #deferred > 0 do
				local queue = deferred
				deferred = {}
				for _, d in queue do
					T.spawn(d.fn, table.unpack(d.args, 1, d.args.n))
				end
			end
			local queue = sleepers
			sleepers = {}
			for _, co in queue do
				if coroutine.status(co) == "suspended" then
					T.spawn(co)
				end
			end
		end
	end

	function env.releaseHeld()
		local queue = env.held
		env.held = {}
		for _, co in queue do
			T.spawn(co)
		end
	end

	local dataStore = {
		UpdateAsync = function(_, key: string, transform: any)
			if env.hold > 0 then
				env.hold -= 1
				table.insert(env.held, coroutine.running())
				coroutine.yield()
			end
			local new = transform(ProfileLogic.deepCopy(env.data[key]))
			if new ~= nil then
				env.data[key] = ProfileLogic.deepCopy(new)
			end
			return new
		end,
	}

	local events: { [string]: any } = {}
	local function event(name: string): any
		if events[name] == nil then
			events[name] = {
				OnServerEvent = newSignal(T.spawn),
				FireClient = function(_, player, payload)
					table.insert(env.sent, { name = name, player = player, payload = payload })
				end,
			}
		end
		return events[name]
	end

	local list: { any } = {}
	local Players = {
		PlayerAdded = newSignal(T.spawn),
		PlayerRemoving = newSignal(T.spawn),
		GetPlayers = function()
			return table.clone(list)
		end,
	}
	local guid = 0
	local services = {
		Players = Players,
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return `guid-{guid}`
			end,
		},
		DataStoreService = {
			GetDataStore = function()
				return dataStore
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		},
	}
	local modules = {
		Config = Config,
		ProfileLogic = ProfileLogic,
		ProfileSchema = ProfileSchema,
		Remotes = { event = event },
	}
	local path = "src/server/DataService.luau"
	local DataService = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			game = {
				JobId = "job-1",
				GetService = function(_, name: string)
					return assert((services :: any)[name], name)
				end,
				BindToClose = function(_, fn)
					env.onClose = fn
				end,
			},
			Enum = { DataStoreRequestType = { UpdateAsync = "UpdateAsync" } },
			require = function(target: any)
				return assert((modules :: any)[target.__shared], target.__shared)
			end,
			task = T,
			os = {
				clock = function()
					return env.clock
				end,
				time = function()
					return math.floor(env.clock)
				end,
			},
			warn = function(...)
				table.insert(env.warnings, table.concat({ ... }, " "))
			end,
		},
	})()
	DataService.init()
	DataService.start()
	env.DataService = DataService

	function env.join(userId: number): any
		local player = { UserId = userId, Name = `P{userId}`, Parent = Players }
		table.insert(list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function env.leave(player: any)
		local index = table.find(list, player)
		if index then
			table.remove(list, index)
		end
		player.Parent = nil
		Players.PlayerRemoving:Fire(player)
	end
	-- 코루틴 안에서 fn을 돌리고 결과를 env.run 뒤에 꺼내요
	function env.call(fn: () -> any): () -> any
		local box: any = { done = false }
		T.spawn(function()
			box.value = fn()
			box.done = true
		end)
		return function()
			assert(box.done, "call did not finish")
			return box.value
		end
	end
	function env.lastView(player: any): any
		for i = #env.sent, 1, -1 do
			local item = env.sent[i]
			if item.name == "ProfileUpdated" and item.player == player then
				return item.payload
			end
		end
		return nil
	end
	return env
end

return function(t: Test.Test)
	t.test("live mode: load takes the lock with a session id, leave saves and releases", function()
		local env = loadEnv()
		local p = env.join(1)
		env.run(5)
		t.ok(env.DataService.get(p) ~= nil, "loaded")
		t.eq(env.DataService.canPersist(p), true)
		t.eq(env.data.u_1.lock.jobId, "job-1")
		t.ok(type(env.data.u_1.lock.session) == "string", "session id in lock")
		env.DataService.update(p, function(profile)
			profile.coins = 5
		end)
		env.leave(p)
		env.run(5)
		t.eq(env.data.u_1.profile.coins, 5)
		t.eq(env.data.u_1.lock, nil)
	end)

	t.test("D1: rejoining the same server waits for the old session's release save", function()
		local env = loadEnv()
		local old = env.join(1)
		env.run(5)
		env.DataService.update(old, function(profile)
			profile.coins = 5
		end)
		env.hold = 1 -- 퇴장 저장만 느림
		env.leave(old)
		env.run(5)
		local new = env.join(1)
		env.run(20)
		t.eq(env.DataService.get(new), nil, "still waiting for the old save")
		env.releaseHeld()
		env.run(20)
		local profile = env.DataService.get(new)
		t.ok(profile ~= nil, "loaded after the old save")
		t.eq(profile.coins, 5, "reads the old session's last save")
		t.eq(env.DataService.canPersist(new), true)
		t.eq(env.lastView(new).persistent, true)

		env.DataService.update(new, function(p)
			p.coins = 7
		end)
		local result = env.call(function()
			return env.DataService.saveNow(new)
		end)
		env.run(5)
		t.eq(result(), true)
		t.eq(env.data.u_1.profile.coins, 7)
		t.ok(env.data.u_1.lock ~= nil, "new session still holds the lock")
		for _, w in env.warnings do
			t.ok(not string.find(w, "lock lost", 1, true), `no lost-lock warning: {w}`)
		end
	end)

	t.test("D1: if the old release save is very late, it cannot clear the new session's lock", function()
		local env = loadEnv()
		local old = env.join(1)
		env.run(5)
		env.DataService.update(old, function(profile)
			profile.coins = 5
		end)
		env.hold = 1
		env.leave(old)
		env.run(5)
		local new = env.join(1)
		env.run(400) -- 40초: 재접속 대기(30초)를 넘김
		t.ok(env.DataService.get(new) ~= nil, "gave up waiting and took the stale lock")
		-- 이제야 옛 세션의 해제 저장이 도착 → 새 세션 잠금을 건드리지 못해요
		env.releaseHeld()
		env.run(20)
		t.ok(env.DataService.get(new) ~= nil, "loaded")
		local result = env.call(function()
			return env.DataService.saveNow(new)
		end)
		env.run(5)
		t.eq(result(), true, "new session can still save")
		t.eq(env.DataService.canPersist(new), true)
		local lock = env.data.u_1.lock
		t.ok(lock ~= nil and lock.session ~= nil, "lock belongs to a session")
	end)

	t.test("D2: saveNow after BindToClose released the lock returns false", function()
		local env = loadEnv()
		local p = env.join(1)
		env.run(5)
		local closed = env.call(function()
			env.onClose()
			return true
		end)
		env.run(10)
		t.eq(closed(), true)
		t.eq(env.data.u_1.lock, nil, "released on close")
		env.DataService.update(p, function(profile)
			profile.coins = 99
		end)
		local result = env.call(function()
			return env.DataService.saveNow(p)
		end)
		env.run(5)
		t.eq(result(), false)
		t.ok(env.data.u_1.profile.coins ~= 99, "not written")
	end)

	t.test("saveNow on a temporary profile (load failed) returns false and never writes", function()
		local env = loadEnv()
		env.data.u_1 = { profile = { version = 99, coins = 3 } }
		local p = env.join(1)
		env.run(5)
		t.eq(env.DataService.canPersist(p), false)
		local result = env.call(function()
			return env.DataService.saveNow(p)
		end)
		env.run(5)
		t.eq(result(), false)
		t.eq(env.data.u_1.profile.version, 99)
		t.eq(env.data.u_1.lock, nil, "future-version lock released")
	end)
end
