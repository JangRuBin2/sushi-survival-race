--!strict
-- m4-14 QA: 실제 RobuxShopService + PurchaseLog + DataService + ShopService 소스를 가짜 Roblox 환경에서 같이 돌려요.
--   가짜 MarketplaceService(ProcessReceipt·PromptProductPurchase), 가짜 DataStore(프로필·Purchases_v1 공유 가능,
--   실패·지연 주입), 가짜 스케줄러(시간이 있는 task.wait). 서버 두 개가 같은 저장소를 쓰면 서버 이동(m4-11)이에요.
-- 불변식: PurchaseGranted를 돌려줬으면 저장소의 프로필에 스킨이 있고 Purchases_v1에 기록이 있어야 해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Types = RobloxRequire.require(Shared.Types)

local GRANTED = "Enum.ProductPurchaseDecision.PurchaseGranted"
local NOT_YET = "Enum.ProductPurchaseDecision.NotProcessedYet"

local deepCopy = ProfileLogic.deepCopy

---------------------------------------------------------------- 상품 id를 채운 카탈로그 (공유 캐시를 건드리지 않게 새로 불러요)
local function loadSharedFresh(name: string, deps: { [string]: any }): any
	local path = `src/shared/{name}.luau`
	local parent = setmetatable({}, {
		__index = function(_, k)
			return { __dep = k }
		end,
	})
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			script = { Parent = parent },
			require = function(target: any)
				return assert(deps[target.__dep], `missing dep {target.__dep}`)
			end,
		},
	})()
end

local function patchedCatalog(): (any, any)
	local Skins = loadSharedFresh("Skins", { Config = Config })
	for i, skin in Skins.LIST do
		if skin.robux ~= nil then
			skin.productId = 5000 + i
		end
	end
	local ReceiptLogic = loadSharedFresh("ReceiptLogic", { Skins = Skins })
	return Skins, ReceiptLogic
end

---------------------------------------------------------------- 가짜 DataStore
type Store = {
	data: { [string]: any },
	userIds: { [string]: any },
	failUpdate: boolean,
	failGet: boolean,
	holdUpdate: number,
	held: { thread },
	updates: number,
	api: any,
}

local function newStore(): Store
	local s: Store = {
		data = {},
		userIds = {},
		failUpdate = false,
		failGet = false,
		holdUpdate = 0,
		held = {},
		updates = 0,
	} :: any
	s.api = {
		UpdateAsync = function(_, key: string, transform: any)
			if s.holdUpdate > 0 then
				s.holdUpdate -= 1
				table.insert(s.held, coroutine.running())
				coroutine.yield()
			end
			if s.failUpdate then
				error("fake UpdateAsync error")
			end
			s.updates += 1
			local new, uids = transform(deepCopy(s.data[key]))
			if new ~= nil then
				s.data[key] = deepCopy(new)
				s.userIds[key] = uids
			end
			return new
		end,
		GetAsync = function(_, key: string)
			if s.failGet then
				error("fake GetAsync error")
			end
			return deepCopy(s.data[key])
		end,
	}
	return s
end

---------------------------------------------------------------- 서버 하나
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

type Options = {
	studio: boolean?,
	fake: boolean?,
	persistInStudio: boolean?,
	stores: { [string]: Store }?,
	jobId: string?,
	clock: number?,
}

local function loadServer(opts: Options?): any
	local o: Options = opts or {}
	local env: any = { clock = o.clock or 1000, logs = {}, warnings = {}, prompts = {}, instances = {}, closers = {} }
	env.stores = o.stores or {}
	local function storeFor(name: string): Store
		local s = env.stores[name]
		if s == nil then
			s = newStore()
			env.stores[name] = s
		end
		return s
	end
	env.profiles = storeFor(Config.Data.StoreName)
	env.purchases = storeFor(Config.Shop.PurchaseLogStore)

	-- 스케줄러
	local sleepers: { { co: thread, at: number } } = {}
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
	function T.wait(seconds: number?)
		table.insert(sleepers, { co = coroutine.running(), at = env.clock + (seconds or 0) })
		return coroutine.yield()
	end
	function T.delay(seconds: number, fn: any, ...: any)
		local args = table.pack(...)
		T.spawn(function()
			T.wait(seconds)
			fn(table.unpack(args, 1, args.n))
		end)
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
			for _, s in queue do
				if env.clock + 1e-9 >= s.at then
					if coroutine.status(s.co) == "suspended" then
						T.spawn(s.co)
					end
				else
					table.insert(sleepers, s)
				end
			end
		end
	end
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
	function env.releaseHeld(store: Store)
		local queue = store.held
		store.held = {}
		for _, co in queue do
			T.spawn(co)
		end
	end

	-- 리모트
	local functions: { [string]: any } = {}
	local events: { [string]: any } = {}
	local Remotes = {
		fn = function(name: string): any
			functions[name] = functions[name] or {}
			return functions[name]
		end,
		event = function(name: string): any
			if events[name] == nil then
				events[name] = {
					OnServerEvent = newSignal(T.spawn),
					FireClient = function() end,
				}
			end
			return events[name]
		end,
	}
	env.functions = functions

	-- 서비스
	local list: { any } = {}
	local Players: any = {
		PlayerAdded = newSignal(T.spawn),
		PlayerRemoving = newSignal(T.spawn),
		GetPlayers = function()
			return table.clone(list)
		end,
		GetPlayerByUserId = function(_, userId: number)
			for _, p in list do
				if p.UserId == userId then
					return p
				end
			end
			return nil
		end,
		FindFirstChild = function(_, name: string)
			for _, p in list do
				if p.Name == name then
					return p
				end
			end
			return nil
		end,
	}
	local Marketplace: any = {
		PromptProductPurchaseFinished = newSignal(T.spawn),
		PromptProductPurchase = function(_, player: any, productId: number)
			table.insert(env.prompts, { player = player, productId = productId })
		end,
	}
	env.market = Marketplace
	local ServerStorage = { Name = "ServerStorage" }
	env.serverStorage = ServerStorage
	local services = {
		Players = Players,
		MarketplaceService = Marketplace,
		ServerStorage = ServerStorage,
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
		RunService = {
			IsStudio = function()
				return o.studio == true
			end,
		},
		HttpService = {
			GenerateGUID = function()
				env.guid = (env.guid or 0) + 1
				return `{o.jobId or "job-1"}-guid-{env.guid}`
			end,
		},
		DataStoreService = {
			GetDataStore = function(_, name: string)
				return storeFor(name).api
			end,
			GetRequestBudgetForRequestType = function()
				return 100
			end,
		},
	}

	local cfg = table.clone(Config)
	cfg.DEBUG = table.clone(Config.DEBUG)
	cfg.DEBUG.fakeRobuxInStudio = o.fake == true
	cfg.DEBUG.persistDataInStudio = o.persistInStudio == true
	env.config = cfg

	local Skins, ReceiptLogic = patchedCatalog()
	env.Skins = Skins
	local sharedMods = {
		Config = cfg,
		ProfileLogic = ProfileLogic,
		ProfileSchema = ProfileSchema,
		ReceiptLogic = ReceiptLogic,
		Remotes = Remotes,
		ShopLogic = ShopLogic,
		Skins = Skins,
		Types = Types,
	}
	env.locked = {} -- player → 라운드 레이서
	env.refreshed = 0
	local serverMods: { [string]: any } = {
		AppearanceService = {
			setResolver = function() end,
			refresh = function()
				env.refreshed += 1
			end,
		},
		MatchEvents = {
			onResult = function(fn)
				env.onResult = fn
			end,
		},
		RoundService = {
			placedRoomOf = function(player: any): string?
				return if env.locked[player] then "room1" else nil
			end,
		},
	}
	local parent = setmetatable({}, {
		__index = function(_, name: string)
			return { __server = name }
		end,
	})
	local function req(target: any): any
		if target.__shared then
			return assert((sharedMods :: any)[target.__shared], target.__shared)
		end
		return assert(serverMods[target.__server], target.__server)
	end
	local game = {
		JobId = o.jobId or "job-1",
		GetService = function(_, name: string)
			return assert((services :: any)[name], name)
		end,
		BindToClose = function(_, fn)
			table.insert(env.closers, fn)
		end,
	}
	local Instance = {
		new = function(className: string)
			local inst = { ClassName = className }
			table.insert(env.instances, inst)
			return inst
		end,
	}
	local Enum = setmetatable({}, {
		__index = function(_, a)
			return setmetatable({}, {
				__index = function(_, b)
					return `Enum.{a}.{b}`
				end,
			})
		end,
	})
	local fakeOs = {
		clock = function()
			return env.clock
		end,
		time = function()
			return math.floor(env.clock)
		end,
	}
	local function load(name: string)
		local path = `src/server/{name}.luau`
		serverMods[name] = luau.load(fs.readFile(path), {
			debugName = path,
			environment = {
				game = game,
				script = { Parent = parent },
				require = req,
				task = T,
				os = fakeOs,
				Instance = Instance,
				Enum = Enum,
				print = function(...)
					table.insert(env.logs, table.concat({ ... }, " "))
				end,
				warn = function(...)
					local line = table.concat({ ... }, " ")
					table.insert(env.logs, line)
					table.insert(env.warnings, line)
				end,
			},
		})()
	end
	for _, name in { "DataService", "PurchaseLog", "ShopService", "RobuxShopService" } do
		load(name)
	end
	-- init.server.luau 순서: 모두 init → 모두 start (DataService가 먼저, ShopService 다음 RobuxShopService)
	for _, name in { "DataService", "ShopService", "RobuxShopService" } do
		serverMods[name].init()
	end
	for _, name in { "DataService", "ShopService", "RobuxShopService" } do
		serverMods[name].start()
	end
	env.DataService = serverMods.DataService

	function env.join(userId: number): any
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			Parent = Players,
			IsA = function(_, c)
				return c == "Player"
			end,
		}
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
	function env.close()
		for _, fn in env.closers do
			T.spawn(fn)
		end
	end
	-- ProcessReceipt를 코루틴에서 부르고, steps만큼 돌린 뒤 결과
	function env.receipt(userId: number, productId: number, purchaseId: string, steps: number?): any
		local get = env.call(function()
			return Marketplace.ProcessReceipt({
				PlayerId = userId,
				ProductId = productId,
				PurchaseId = purchaseId,
				CurrencySpent = 99,
				CurrencyType = "Robux",
				PlaceIdWherePurchased = 1,
			})
		end)
		env.run(steps or 80)
		return get()
	end
	function env.startReceipt(userId: number, productId: number, purchaseId: string): () -> any
		return env.call(function()
			return Marketplace.ProcessReceipt({ PlayerId = userId, ProductId = productId, PurchaseId = purchaseId })
		end)
	end
	function env.request(player: any, skinId: any): (boolean, string?)
		local box: any = {}
		local get = env.call(function()
			box.ok, box.err = functions.RequestRobuxPurchase.OnServerInvoke(player, skinId)
			return true
		end)
		env.run(2)
		get()
		return box.ok, box.err
	end
	function env.productOf(skinId: string): number
		return (Skins.get(skinId) :: any).productId
	end
	function env.savedProfile(userId: number): any
		local entry = env.profiles.data[`u_{userId}`]
		return entry and entry.profile
	end
	function env.lastReceiptLine(): string?
		for i = #env.logs, 1, -1 do
			if string.find(env.logs[i], "[Shop] receipt", 1, true) then
				return env.logs[i]
			end
		end
		return nil
	end
	return env
end

local function countOwned(profile: any): number
	local n = 0
	for _, has in profile.ownedSkins do
		if has then
			n += 1
		end
	end
	return n
end

-- 불변식 검사: Granted면 저장소 프로필에 스킨 + 구매 기록
local function assertGrantedPersisted(t: Test.Test, env: any, userId: number, skinId: string, purchaseId: string)
	local saved = env.savedProfile(userId)
	t.ok(saved ~= nil and saved.ownedSkins[skinId] == true, `saved profile owns {skinId}`)
	local record = env.purchases.data[purchaseId]
	t.ok(record ~= nil, `purchase record {purchaseId} exists`)
	t.eq(record.userId, userId)
	t.eq(record.skinId, skinId)
end

return function(t: Test.Test)
	---------------------------------------------------------------- 정상 흐름
	t.test(
		"live: receipt → skin granted + equipped, profile saved first, then Purchases_v1 record with userId metadata",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			t.eq(env.DataService.canPersist(p), true)
			local before = env.profiles.updates
			local result = env.receipt(1, env.productOf("uni"), "pid-1")
			t.eq(result, GRANTED)
			assertGrantedPersisted(t, env, 1, "uni", "pid-1")
			t.ok(env.profiles.updates > before, "profile was written")
			t.eq(env.savedProfile(1).equippedSkin, "uni", "auto equipped")
			t.eq(env.purchases.userIds["pid-1"], { 1 }, "UserId metadata for GDPR lookup")
			t.eq(env.savedProfile(1).receipts[1].id, "pid-1")
			local line = env.lastReceiptLine()
			t.ok(line ~= nil and string.find(line, "PurchaseGranted", 1, true) ~= nil, "one [Shop] receipt log line")
		end
	)

	t.test("live: same PurchaseId re-sent → Granted again, skin once, record not overwritten", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		t.eq(env.receipt(1, env.productOf("uni"), "pid-1"), GRANTED)
		local at = env.purchases.data["pid-1"].at
		local owned = countOwned(env.DataService.get(p))
		env.run(30)
		t.eq(env.receipt(1, env.productOf("uni"), "pid-1"), GRANTED)
		t.eq(countOwned(env.DataService.get(p)), owned)
		t.eq(#env.DataService.get(p).receipts, 1, "receipt id kept once")
		t.eq(env.purchases.data["pid-1"].at, at, "record kept")
		t.ok(string.find(env.lastReceiptLine() or "", "AlreadyRecorded", 1, true) ~= nil, "AlreadyRecorded")
	end)

	t.test("live: concurrent callback with the same PurchaseId → second NotProcessedYet, first Granted", function()
		local env = loadServer()
		env.join(1)
		env.run(5)
		env.profiles.holdUpdate = 1 -- 프로필 저장이 느림
		local first = env.startReceipt(1, env.productOf("uni"), "pid-1")
		env.run(3)
		local second = env.startReceipt(1, env.productOf("uni"), "pid-1")
		env.run(3)
		t.eq(second(), NOT_YET, "in flight on this server")
		env.releaseHeld(env.profiles)
		env.run(30)
		t.eq(first(), GRANTED)
		assertGrantedPersisted(t, env, 1, "uni", "pid-1")
	end)

	---------------------------------------------------------------- 저장 실패 → NotProcessedYet → 다시 시도
	t.test(
		"live: profile save fails → NotProcessedYet and no record; retry after recovery → Granted once",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			env.profiles.failUpdate = true
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 200), NOT_YET)
			t.eq(env.purchases.data["pid-1"], nil, "record not written before the save succeeds")
			local savedNow = env.savedProfile(1)
			t.ok(savedNow == nil or savedNow.ownedSkins.uni == nil, "nothing persisted")
			env.profiles.failUpdate = false
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1"), GRANTED)
			assertGrantedPersisted(t, env, 1, "uni", "pid-1")
			t.eq(#env.DataService.get(p).receipts, 1)
		end
	)

	t.test(
		"live: purchase log write fails → NotProcessedYet (profile has skin); retry → Granted, no double grant",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			env.purchases.failUpdate = true
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 200), NOT_YET)
			t.eq(env.savedProfile(1).ownedSkins.uni, true, "profile saved before record")
			t.eq(env.purchases.data["pid-1"], nil)
			env.purchases.failUpdate = false
			local owned = countOwned(env.DataService.get(p))
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1"), GRANTED)
			assertGrantedPersisted(t, env, 1, "uni", "pid-1")
			t.eq(countOwned(env.DataService.get(p)), owned)
			t.ok(string.find(env.lastReceiptLine() or "", "retry", 1, true) ~= nil, "logged as retry, not re-buy")
		end
	)

	t.test("live: purchase log read fails → NotProcessedYet and nothing granted", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.purchases.failGet = true
		t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 200), NOT_YET)
		t.eq(env.DataService.get(p).ownedSkins.uni, nil)
	end)

	---------------------------------------------------------------- 받을 수 없는 상태
	t.test("live: player not here / unknown product / profile still loading → NotProcessedYet", function()
		local env = loadServer()
		t.eq(env.receipt(9, env.productOf("uni"), "pid-x"), NOT_YET, "player not in server")
		local p = env.join(1)
		env.run(5)
		t.eq(env.receipt(1, 424242, "pid-y"), NOT_YET, "unknown product")
		t.eq(env.DataService.get(p).ownedSkins.uni, nil)
		-- 로드 중
		env.profiles.holdUpdate = 1
		env.join(2)
		env.run(3)
		t.eq(env.receipt(2, env.productOf("uni"), "pid-z", 3), NOT_YET, "profile loading")
		env.releaseHeld(env.profiles)
		env.run(10)
		t.eq(env.purchases.data["pid-z"], nil)
	end)

	t.test("live: malformed receipt shapes → NotProcessedYet", function()
		local env = loadServer()
		env.join(1)
		env.run(5)
		for _, bad in
			{
				{},
				{ PlayerId = "1", ProductId = 1, PurchaseId = "a" },
				{ PlayerId = 1, ProductId = 1, PurchaseId = "" },
			}
		do
			local get = env.call(function()
				return env.market.ProcessReceipt(bad)
			end)
			env.run(5)
			t.eq(get(), NOT_YET)
		end
	end)

	t.test(
		"live (m4-07 D2): session lock lost → saveNow false → NotProcessedYet; later retries also wait",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			-- 다른 서버가 잠금을 가져감
			local entry = env.profiles.data.u_1
			entry.lock = { jobId = "other-job", at = 1000, session = "other" }
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 100), NOT_YET)
			t.eq(env.purchases.data["pid-1"], nil)
			t.eq(env.DataService.canPersist(p), false, "temporary profile now")
			t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 100), NOT_YET, "temporary profile never completes")
			t.eq(env.purchases.data["pid-1"], nil)
		end
	)

	t.test("live (m4-07 D2): after BindToClose (closing/released) → NotProcessedYet", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.close()
		env.run(20)
		t.eq(env.profiles.data.u_1.lock, nil, "released on close")
		t.eq(env.receipt(1, env.productOf("uni"), "pid-1", 100), NOT_YET)
		t.eq(env.purchases.data["pid-1"], nil)
		t.ok(env.savedProfile(1) == nil or env.savedProfile(1).ownedSkins.uni == nil)
		t.ok(p ~= nil)
	end)

	t.test(
		"live: player leaves while the profile save is slow → Granted only if the skin really reached the store",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			env.profiles.holdUpdate = 1
			local get = env.startReceipt(1, env.productOf("uni"), "pid-1")
			env.run(3)
			env.leave(p)
			env.run(3)
			env.releaseHeld(env.profiles)
			env.run(60)
			local result = get()
			if result == GRANTED then
				assertGrantedPersisted(t, env, 1, "uni", "pid-1")
			else
				t.eq(result, NOT_YET)
				t.eq(env.purchases.data["pid-1"], nil)
			end
			t.eq(env.profiles.data.u_1.lock, nil, "released after leave")
		end
	)

	t.test("live: player leaves during the purchase-log lookup → NotProcessedYet", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.purchases.failGet = true -- 읽기가 재시도(1초씩) 하는 동안 나감
		local get = env.startReceipt(1, env.productOf("uni"), "pid-1")
		env.run(5)
		env.leave(p)
		env.purchases.failGet = false
		env.run(60)
		t.eq(get(), NOT_YET)
	end)

	---------------------------------------------------------------- 서버 이동 (m4-11) — 같은 저장소, 다른 서버
	t.test(
		"server move: record write failed on A, player moves to B, re-sent receipt → Granted on B, skin once",
		function()
			local a = loadServer({ jobId = "job-A" })
			local pa = a.join(1)
			a.run(5)
			a.purchases.failUpdate = true
			t.eq(a.receipt(1, a.productOf("uni"), "pid-1", 200), NOT_YET)
			a.purchases.failUpdate = false
			a.leave(pa)
			a.run(20)
			local b = loadServer({ jobId = "job-B", stores = a.stores, clock = a.clock })
			local pb = b.join(1)
			b.run(10)
			t.eq(b.DataService.canPersist(pb), true)
			t.eq(b.DataService.get(pb).ownedSkins.uni, true, "skin came with the profile")
			t.eq(b.receipt(1, b.productOf("uni"), "pid-1"), GRANTED)
			assertGrantedPersisted(t, b, 1, "uni", "pid-1")
			t.ok(string.find(b.lastReceiptLine() or "", "retry", 1, true) ~= nil, "seen as retry via profile receipts")
		end
	)

	t.test("server move: profile save failed on A (skin only in memory), B re-processes → GrantAndRecord", function()
		local a = loadServer({ jobId = "job-A" })
		local pa = a.join(1)
		a.run(5)
		a.profiles.failUpdate = true
		t.eq(a.receipt(1, a.productOf("uni"), "pid-1", 200), NOT_YET)
		a.leave(pa) -- 퇴장 저장도 실패
		a.run(200)
		a.profiles.failUpdate = false
		-- A의 잠금이 남아 있으면 B는 기다리다 가져가요 (만료 전이면 LoadRetries 뒤 steal)
		local b = loadServer({ jobId = "job-B", stores = a.stores, clock = a.clock })
		local pb = b.join(1)
		b.run(400)
		local profile = b.DataService.get(pb)
		t.ok(profile ~= nil, "loaded on B")
		t.eq(profile.ownedSkins.uni, nil, "skin was lost with the failed save")
		t.eq(b.receipt(1, b.productOf("uni"), "pid-1"), GRANTED)
		assertGrantedPersisted(t, b, 1, "uni", "pid-1")
	end)

	t.test("receipts history trimmed to 50: an old PurchaseId re-sent is still stopped by Purchases_v1", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		t.eq(env.receipt(1, env.productOf("uni"), "old-1"), GRANTED)
		-- 같은 스킨 재구매 영수증 50개로 old-1을 목록에서 밀어내요
		for i = 1, Config.Shop.ReceiptHistoryMax do
			env.run(1)
			t.eq(env.receipt(1, env.productOf("salmon"), `fill-{i}`, 40), GRANTED)
		end
		local profile = env.DataService.get(p)
		t.eq(#profile.receipts, Config.Shop.ReceiptHistoryMax)
		local found = false
		for _, entry in profile.receipts do
			if entry.id == "old-1" then
				found = true
			end
		end
		t.eq(found, false, "old-1 trimmed from the profile list")
		-- 프로필이 되돌려져 uni가 없어졌다고 해도: 기록이 있어 AlreadyRecorded → 복구만, 새 지급 아님
		profile.ownedSkins.uni = nil
		t.eq(env.receipt(1, env.productOf("uni"), "old-1"), GRANTED)
		t.ok(string.find(env.lastReceiptLine() or "", "AlreadyRecorded", 1, true) ~= nil, "stopped by Purchases_v1")
		t.eq(env.savedProfile(1).ownedSkins.uni, true, "restored and saved")
	end)

	---------------------------------------------------------------- RequestRobuxPurchase
	t.test("RequestRobuxPurchase: argument types, catalog, default, owned → rejected, no prompt", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.DataService.update(p, function(profile)
			profile.ownedSkins.salmon = true
		end)
		for _, bad in { nil, 42, true, {}, { "uni" }, "nope", "tamago", "salmon" } do
			env.clock += 1.1
			local ok, err = env.request(p, bad)
			t.eq(ok, false, `rejects {tostring(bad)}`)
			t.ok(type(err) == "string" and err ~= "", "reason text")
		end
		t.eq(#env.prompts, 0)
	end)

	t.test("RequestRobuxPurchase: valid → PromptProductPurchase only (no grant); 1 s cooldown", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.clock += 2
		local ok = env.request(p, "uni")
		t.eq(ok, true)
		t.eq(#env.prompts, 1)
		t.eq(env.prompts[1].productId, env.productOf("uni"))
		t.eq(env.DataService.get(p).ownedSkins.uni, nil, "request never grants")
		local ok2, err2 = env.request(p, "eel")
		t.eq(ok2, false)
		t.eq(err2, "잠시 뒤에 다시 해 주세요")
		env.clock += 1.01
		t.eq((env.request(p, "eel")), true)
		t.eq(#env.prompts, 2)
	end)

	t.test(
		"RequestRobuxPurchase: productId nil → 준비 중이에요; cannot persist (lock lost) → 저장 거절",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5);
			(env.Skins.get("eel") :: any).productId = nil
			env.clock += 2
			local ok, err = env.request(p, "eel")
			t.eq(ok, false)
			t.eq(err, "준비 중이에요")
			env.profiles.data.u_1.lock = { jobId = "other-job", at = 1000, session = "other" }
			local save = env.call(function()
				return env.DataService.saveNow(p)
			end)
			env.run(10)
			t.eq(save(), false)
			env.clock += 2
			local ok2, err2 = env.request(p, "uni")
			t.eq(ok2, false)
			t.eq(err2, "저장이 안 되는 상태라 지금은 살 수 없어요")
			t.eq(#env.prompts, 0)
		end
	)

	---------------------------------------------------------------- Studio 가짜 결제·디버그 훅
	t.test("live server: fakeRobuxInStudio = true is ignored (no ShopDebug, no fake receipt, no grant)", function()
		local env = loadServer({ studio = false, fake = true })
		t.eq(#env.instances, 0, "no debug BindableFunction on a live server")
		local p = env.join(1)
		env.run(5);
		(env.Skins.get("eel") :: any).productId = nil
		env.clock += 2
		local ok, err = env.request(p, "eel")
		t.eq(ok, false)
		t.eq(err, "준비 중이에요")
		env.clock += 2
		t.eq((env.request(p, "uni")), true)
		env.run(20)
		t.eq(#env.prompts, 1, "real prompt, not a fake receipt")
		t.eq(env.DataService.get(p).ownedSkins.uni, nil)
	end)

	t.test("Studio without fakeRobuxInStudio: no ShopDebug; memory profile → CannotSave", function()
		local env = loadServer({ studio = true, fake = false })
		t.eq(#env.instances, 0)
		local p = env.join(1)
		env.run(5)
		t.eq(env.DataService.canPersist(p), false)
		env.clock += 2
		local ok, err = env.request(p, "uni")
		t.eq(ok, false)
		t.eq(err, "저장이 안 되는 상태라 지금은 살 수 없어요")
		t.eq(env.receipt(1, env.productOf("uni"), "pid-1"), NOT_YET, "memory profile never completes a real receipt")
	end)

	t.test(
		"Studio + fakeRobuxInStudio: request → fake receipt grants into memory; ReplayReceipt same id → skin once",
		function()
			local env = loadServer({ studio = true, fake = true })
			local kinds = {}
			for _, inst in env.instances do
				table.insert(kinds, inst.ClassName)
			end
			table.sort(kinds)
			t.eq(kinds, { "BindableFunction", "Folder" })
			local p = env.join(1)
			env.run(5);
			(env.Skins.get("eel") :: any).productId = nil
			env.clock += 2
			t.eq((env.request(p, "eel")), true)
			env.run(20)
			t.eq(#env.prompts, 0, "no real prompt in fake mode")
			t.eq(env.DataService.get(p).ownedSkins.eel, true)
			local replay
			for _, inst in env.instances do
				if inst.ClassName == "BindableFunction" then
					replay = inst
				end
			end
			local first = env.call(function()
				return replay.OnInvoke("P1", "uni", "studio-test-1")
			end)
			env.run(20)
			t.eq(first(), "PurchaseGranted")
			local owned = countOwned(env.DataService.get(p))
			local second = env.call(function()
				return replay.OnInvoke("P1", "uni", "studio-test-1")
			end)
			env.run(20)
			t.eq(second(), "PurchaseGranted")
			t.eq(countOwned(env.DataService.get(p)), owned, "skin once")
			t.ok(string.find(env.lastReceiptLine() or "", "AlreadyRecorded", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 결제로 받은 스킨은 겉모습뿐 (Pay-to-Win 없음)
	t.test("paid skins only change ownedSkins/equippedSkin/receipts in the profile", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		local before = deepCopy(env.DataService.get(p))
		t.eq(env.receipt(1, env.productOf("dragon-roll"), "pid-1"), GRANTED)
		local after = env.DataService.get(p)
		for key, value in after do
			if key ~= "ownedSkins" and key ~= "equippedSkin" and key ~= "receipts" then
				t.eq(value, before[key], `field {key} unchanged`)
			end
		end
	end)

	---------------------------------------------------------------- QA 후 수정 (developer, R2·R4)
	local function coinUnlock(env: any, player: any, skinId: string): (boolean, string?)
		local box: any = {}
		local get = env.call(function()
			box.ok, box.err = env.functions.BuyWithCoins.OnServerInvoke(player, skinId)
			return true
		end)
		env.run(2)
		get()
		return box.ok, box.err
	end

	t.test("R2 fix: while the robux prompt for a skin is open, coin unlock of that skin is refused", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.DataService.update(p, function(profile)
			profile.coins = 1000
		end)
		local ok = env.request(p, "salmon")
		t.eq(ok, true)
		t.eq(#env.prompts, 1)
		env.run(5) -- 요청 간격 지나기
		local bought, err = coinUnlock(env, p, "salmon")
		t.eq(bought, false, "coin unlock refused while prompt open")
		t.eq(err, ShopLogic.message("PurchasePending"))
		t.eq(env.DataService.get(p).coins, 1000, "coins untouched")
		-- 다른 일반 스킨은 그대로 해금돼요
		env.run(5)
		t.eq((coinUnlock(env, p, "tuna")), true)
		-- 결제 완료 → 영수증 Granted(GrantAndRecord, 경고 없음) → 막힘 해제
		t.eq(env.receipt(1, env.productOf("salmon"), "pid-salmon"), GRANTED)
		t.ok(string.find(env.lastReceiptLine() or "", "GrantAndRecord", 1, true) ~= nil, "not RecordOnly")
	end)

	t.test("R2 fix: cancelled prompt or timeout unblocks coin unlock; RecordOnly path still warns", function()
		local env = loadServer()
		local p = env.join(1)
		env.run(5)
		env.DataService.update(p, function(profile)
			profile.coins = 1000
		end)
		env.request(p, "salmon")
		env.market.PromptProductPurchaseFinished:Fire(1, env.productOf("salmon"), false) -- 취소
		env.run(15)
		t.eq((coinUnlock(env, p, "salmon")), true, "cancel unblocks")
		-- 타임아웃
		env.run(15)
		env.request(p, "shrimp")
		env.run(math.ceil(Config.Shop.PurchasePromptHold * 10) + 5)
		t.eq((coinUnlock(env, p, "shrimp")), true, "timeout unblocks")
		-- 그래도 이미 가진 스킨의 영수증이 오면(다른 서버 등) RecordOnly + 경고
		local warnings = #env.warnings
		t.eq(env.receipt(1, env.productOf("salmon"), "pid-late"), GRANTED)
		t.ok(#env.warnings > warnings, "RecordOnly warning kept")
		env.leave(p)
	end)

	t.test("R4 fix: fake robux + persistDataInStudio together → fake purchase refused, nothing written", function()
		local env = loadServer({ studio = true, fake = true, persistInStudio = true })
		local p = env.join(1)
		env.run(5)
		local found = false
		for _, line in env.warnings do
			if string.find(line, "fakeRobuxInStudio is ignored", 1, true) then
				found = true
			end
		end
		t.ok(found, "warning at startup")
		t.eq(#env.instances, 0, "no ReplayReceipt debug hook")
		-- 상품 id가 있으면 진짜 결제 창 (가짜 영수증 없음)
		t.eq((env.request(p, "uni")), true)
		env.run(20)
		t.eq(#env.prompts, 1, "real prompt instead of fake receipt")
		t.eq(next(env.purchases.data), nil, "no fake record in Purchases_v1")
		t.eq(env.DataService.get(p).ownedSkins.uni, nil, "no free skin")
		t.eq(ShopLogic.fakeRobuxActive(true, true, true), false, "client uses the same rule")
		t.eq(ShopLogic.fakeRobuxActive(true, true, false), true)
		t.eq(ShopLogic.fakeRobuxActive(false, true, false), false, "never on a live server")
	end)

	t.test("R3·R5 fix (source): client clears pending on cancel, Remotes comment names RobuxShopService", function()
		local client = fs.readFile("src/client/ui/ShopController.luau")
		t.ok(string.find(client, "PromptProductPurchaseFinished:Connect", 1, true) ~= nil, "listens for prompt finish")
		t.ok(string.find(client, "pending[skin.id] = nil", 1, true) ~= nil, "clears pending")
		local remotes = fs.readFile("src/shared/Remotes.luau")
		t.ok(string.find(remotes, "(m4-14, RobuxShopService:", 1, true) ~= nil)
	end)
end
