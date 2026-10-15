--!strict
-- m5-08 QA (docs/qa/m5-08-offers-shop.md): 개발 테스트(offer-logic, receipt-logic)에 없는 경계값과
-- 실제 OfferService + RobuxShopService + DataService + PurchaseLog + ShopService 소스를 가짜 Roblox 환경에서 같이 돌리는 확인.
--   가짜 MarketplaceService(ProcessReceipt·PromptProductPurchase·PromptGamePassPurchase·UserOwnsGamePassAsync),
--   가짜 DataStore(실패 주입), 시간이 있는 task.wait. 상품 id·패스 id는 테스트에서 채운 카탈로그를 써요.
-- 불변식: PurchaseGranted면 저장소 프로필에 지급분 + Purchases_v1에 offerId 기록.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local LocTest = require("./lib/LocTest")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
-- m5-26: 문구 모듈은 공유 캐시 그대로 써요
local LOC_DEPS = {
	LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic),
	Types = RobloxRequire.require(Shared.Types),
}
local Config = RobloxRequire.require(Shared.Config)
local FxCatalog = RobloxRequire.require(Shared.FxCatalog)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Types = RobloxRequire.require(Shared.Types)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local RealOffers = RobloxRequire.require(Shared.Offers)
local RealOfferLogic = RobloxRequire.require(Shared.OfferLogic)
local RealSkins = RobloxRequire.require(Shared.Skins)
local RealReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)

local GRANTED = "Enum.ProductPurchaseDecision.PurchaseGranted"
local NOT_YET = "Enum.ProductPurchaseDecision.NotProcessedYet"
local BUNDLE_NOTICE = "탈의실에서 새 스킨을 입어 보세요"

local deepCopy = ProfileLogic.deepCopy

local PRODUCT = {
	["starter-pack"] = 7001,
	["epic-set"] = 7002,
	["legendary-set"] = 7003,
	["fx-cat-customer"] = 7004,
	["fx-fireworks"] = 7005,
}
local PASS_ID = 9001

---------------------------------------------------------------- 상품 id를 채운 카탈로그 (공유 캐시를 건드리지 않게 새로)
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
				return assert(deps[target.__dep] or LOC_DEPS[target.__dep], `missing dep {target.__dep}`)
			end,
		},
	})()
end

local function patchedCatalog(withIds: boolean): { [string]: any }
	local Seasons = loadSharedFresh("Seasons", {})
	local Skins = loadSharedFresh("Skins", { Config = Config, Seasons = Seasons, SushiBody = SushiBody })
	for i, skin in Skins.LIST do
		if skin.robux ~= nil then
			skin.productId = 5000 + i
		end
	end
	local Offers = loadSharedFresh("Offers", { FxCatalog = FxCatalog, Skins = Skins })
	if withIds then
		for _, offer in Offers.LIST do
			if offer.kind == "Pass" then
				offer.gamePassId = PASS_ID
			else
				offer.productId = PRODUCT[offer.id]
			end
		end
	end
	local OfferLogic = loadSharedFresh("OfferLogic", { FxCatalog = FxCatalog, Offers = Offers, Skins = Skins })
	local ReceiptLogic = loadSharedFresh("ReceiptLogic", { Skins = Skins, Seasons = Seasons })
	local ShopLogic = loadSharedFresh("ShopLogic", { Skins = Skins, Seasons = Seasons })
	return {
		Seasons = Seasons,
		Skins = Skins,
		Offers = Offers,
		OfferLogic = OfferLogic,
		ReceiptLogic = ReceiptLogic,
		ShopLogic = ShopLogic,
	}
end

---------------------------------------------------------------- 가짜 DataStore
local function newStore(): any
	local s: any = { data = {}, userIds = {}, failUpdate = false, failGet = false, updates = 0 }
	s.api = {
		UpdateAsync = function(_, key: string, transform: any)
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
	fakeVip: boolean?,
	persistInStudio: boolean?,
	withIds: boolean?, -- 기본 true (상품·패스 id를 채운 카탈로그)
	stores: { [string]: any }?,
	passOwners: { [number]: any }?, -- userId → true / false / "error" / { "error", true } (호출마다)
}

local function loadServer(opts: Options?): any
	local o: Options = opts or {}
	local env: any = {
		clock = 1000,
		logs = {},
		warnings = {},
		productPrompts = {},
		passPrompts = {},
		notices = {},
		closers = {},
		ownsCalls = 0,
	}
	env.passOwners = o.passOwners or {}
	env.stores = o.stores or {}
	local function storeFor(name: string): any
		local s = env.stores[name]
		if s == nil then
			s = newStore()
			env.stores[name] = s
		end
		return s
	end
	env.profiles = storeFor(Config.Data.StoreName)
	env.purchases = storeFor(Config.Shop.PurchaseLogStore)

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
			box.value = table.pack(fn())
			box.done = true
		end)
		return function()
			assert(box.done, "call did not finish")
			return table.unpack(box.value, 1, box.value.n)
		end
	end

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
					FireClient = function(_, player: any, ...: any)
						if name == "Notice" then
							table.insert(env.notices, { player = player, message = (...) })
						end
					end,
				}
			end
			return events[name]
		end,
	}
	env.functions = functions

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
	env.PlayersService = Players
	local Marketplace: any = {
		PromptProductPurchaseFinished = newSignal(T.spawn),
		PromptGamePassPurchaseFinished = newSignal(T.spawn),
		PromptProductPurchase = function(_, player: any, productId: number)
			table.insert(env.productPrompts, { player = player, productId = productId })
		end,
		PromptGamePassPurchase = function(_, player: any, passId: number)
			table.insert(env.passPrompts, { player = player, passId = passId })
		end,
		UserOwnsGamePassAsync = function(_, userId: number, passId: number)
			env.ownsCalls += 1
			assert(passId == PASS_ID, "pass id")
			local entry = env.passOwners[userId]
			if type(entry) == "table" then
				local answer = table.remove(entry, 1)
				if answer == "error" then
					error("fake UserOwnsGamePassAsync error")
				end
				return answer == true
			end
			if entry == "error" then
				error("fake UserOwnsGamePassAsync error")
			end
			return entry == true
		end,
	}
	env.market = Marketplace
	local ServerStorage = { Name = "ServerStorage" }
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
				return `job-guid-{env.guid}`
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
	cfg.DEBUG.fakeVipInStudio = o.fakeVip == true
	cfg.DEBUG.persistDataInStudio = o.persistInStudio == true
	env.config = cfg

	local cat = patchedCatalog(o.withIds ~= false)
	env.cat = cat
	local sharedMods = {
		AdminLogic = RobloxRequire.require(Shared.AdminLogic),
		Attributes = RobloxRequire.require(Shared.Attributes),
		Config = cfg,
		DrawLogic = RobloxRequire.require(Shared.DrawLogic), -- m5-31: ShopService의 DrawTicket
		OfferLogic = cat.OfferLogic,
		Offers = cat.Offers,
		ProfileLogic = ProfileLogic,
		ProfileSchema = ProfileSchema,
		ReceiptLogic = cat.ReceiptLogic,
		Remotes = Remotes,
		Seasons = cat.Seasons,
		ShopLogic = cat.ShopLogic,
		Skins = cat.Skins,
		Types = Types,
	}
	env.locked = {}
	local serverMods: { [string]: any } = {
		AppearanceService = {
			setResolver = function() end,
			refresh = function() end,
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
			return assert((sharedMods :: any)[target.__shared] or LOC_DEPS[target.__shared], target.__shared)
		end
		return assert(serverMods[target.__server], target.__server)
	end
	local game = {
		JobId = "job-1",
		GetService = function(_, name: string)
			return assert((services :: any)[name], name)
		end,
		BindToClose = function(_, fn)
			table.insert(env.closers, fn)
		end,
	}
	local Instance = {
		new = function(className: string)
			return { ClassName = className }
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
	for _, name in { "DataService", "PurchaseLog", "ShopService", "RobuxShopService", "OfferService" } do
		load(name)
	end
	local order = { "DataService", "ShopService", "RobuxShopService", "OfferService" }
	for _, name in order do
		serverMods[name].init()
	end
	for _, name in order do
		serverMods[name].start()
	end
	env.DataService = serverMods.DataService
	env.OfferService = serverMods.OfferService

	function env.join(userId: number): any
		local attrs: { [string]: any } = {}
		local player: any = {
			UserId = userId,
			Name = `P{userId}`,
			DisplayName = `P{userId}`,
			Parent = Players,
			attrs = attrs,
			IsA = function(_, c)
				return c == "Player"
			end,
			SetAttribute = function(_, k: string, v: any)
				attrs[k] = v
			end,
			GetAttribute = function(_, k: string)
				return attrs[k]
			end,
		}
		table.insert(list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function env.receipt(userId: number, productId: number, purchaseId: string, steps: number?): any
		local get = env.call(function()
			return Marketplace.ProcessReceipt({ PlayerId = userId, ProductId = productId, PurchaseId = purchaseId })
		end)
		env.run(steps or 80)
		return get()
	end
	function env.invoke(name: string, player: any, ...: any): (boolean, string?)
		local args = table.pack(...)
		local get = env.call(function()
			return functions[name].OnServerInvoke(player, table.unpack(args, 1, args.n))
		end)
		env.run(3)
		return get()
	end
	function env.saved(userId: number): any
		local entry = env.profiles.data[`u_{userId}`]
		return entry and entry.profile
	end
	function env.lastReceiptLine(): string
		for i = #env.logs, 1, -1 do
			if string.find(env.logs[i], "[Shop] receipt", 1, true) then
				return env.logs[i]
			end
		end
		return ""
	end
	function env.warned(needle: string): boolean
		for _, line in env.warnings do
			if string.find(line, needle, 1, true) then
				return true
			end
		end
		return false
	end
	return env
end

local function count(map: any): number
	local n = 0
	for _, v in map do
		if v then
			n += 1
		end
	end
	return n
end

local function view(changes: { [string]: any }?): any
	local v: any = { ownedSkins = { tamago = true }, ownedFx = {}, boughtOffers = {}, vip = false }
	for k, value in changes or {} do
		v[k] = value
	end
	return v
end

local function profile(): any
	return {
		ownedSkins = { tamago = true },
		ownedFx = {},
		equippedFx = {},
		boughtOffers = {},
		equippedSkin = "tamago",
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- 카탈로그·가격·경제 규칙 (순수)
	t.test(
		"QA 카탈로그: 가격이 A안과 맞고 묶음은 따로 사는 값보다 싸요, 코인·능력치 칸 없음",
		function()
			local allowed = {
				id = true,
				displayName = true,
				kind = true,
				robux = true,
				productId = true,
				gamePassId = true,
				skins = true,
				fx = true,
				perks = true,
				blurb = true,
				order = true,
			}
			for _, offer in RealOffers.LIST do
				for key in offer do
					t.ok(allowed[key] == true, `{offer.id}: unexpected field {key} (coins/stat/random?)`)
				end
				if offer.kind == "Bundle" then
					local total = 0
					for _, skinId in offer.skins do
						local skin = RealSkins.get(skinId)
						t.ok(skin.robux ~= nil, skinId)
						total += skin.robux
					end
					t.ok(offer.robux < total, `{offer.id} {offer.robux} < {total}`)
				end
			end
			-- A안: 일반 29 / 레어 59 / 에픽 99 / 전설 199 → 146 / 297 / 597
			t.eq(LocTest.ko(RealOfferLogic.valueText(RealOffers.get("epic-set"))), "따로 사면 R$ 297")
			t.eq(LocTest.ko(RealOfferLogic.valueText(RealOffers.get("legendary-set"))), "따로 사면 R$ 597")
			t.eq(RealOfferLogic.valueText(RealOffers.get("vip")), nil)
			t.eq(RealOfferLogic.valueText(RealOffers.get("fx-fireworks")), nil)
			-- 커밋 값: 상품 id·패스 id 비어 있음 (사용자가 채움)
			for _, offer in RealOffers.LIST do
				t.eq(offer.productId, nil, offer.id)
				t.eq(offer.gamePassId, nil, offer.id)
			end
			t.eq(Config.DEBUG.fakeVipInStudio, false, "commit default")
		end
	)

	t.test(
		"QA validate: 시즌·기본 스킨 묶음, 패스에 productId, 연출에 gamePassId, 상품 id 겹침, 가격 0·소수",
		function()
			local function check(mutate: (list: { any }) -> (), needle: string)
				local list = {}
				for i, o in RealOffers.LIST do
					list[i] = table.clone(o)
				end
				mutate(list)
				local ok, problems = RealOffers.validate(list)
				t.eq(ok, false, needle)
				local found = false
				for _, line in problems do
					if string.find(line, needle, 1, true) then
						found = true
					end
				end
				t.ok(found, `expected problem '{needle}' in {table.concat(problems, "; ")}`)
			end
			check(function(l)
				l[1].skins = { "salmon", "pumpkin-sushi" }
			end, "not a regular robux skin")
			check(function(l)
				l[1].skins = { "salmon", "tamago" }
			end, "not a regular robux skin")
			check(function(l)
				l[1].skins = { "salmon", "salmon" }
			end, "duplicate skin")
			check(function(l)
				l[6].productId = 123
			end, "passes use gamePassId")
			check(function(l)
				l[4].gamePassId = 55
			end, "fx offers are developer products")
			check(function(l)
				l[1].productId = 77
				l[2].productId = 77
			end, "productId already used")
			check(function(l)
				l[2].robux = 0
			end, "robux must be a positive integer")
			check(function(l)
				l[2].robux = 1.5
			end, "robux must be a positive integer")
			check(function(l)
				l[5].fx = { "cat-customer", "ghost" }
			end, "unknown fx ghost")
			check(function(l)
				l[6].skins = { "salmon" }
			end, "must be vipOnly")
			check(function(l)
				l[3].kind = "Gacha"
			end, "kind must be Bundle, Fx or Pass")
		end
	)

	t.test("QA VIP 스킨: 로벅스·코인으로 살 수 없음 (VIP 패스로만)", function()
		local skin = RealSkins.get("vip-gold-tamago")
		t.ok(skin ~= nil and skin.vipOnly == true)
		t.eq(skin.robux, nil)
		local ok, reason = RealReceiptLogic.canRequest(
			"vip-gold-tamago",
			{ tamago = true },
			{ canSave = true, fake = true }
		)
		t.eq(ok, false)
		t.eq(reason, "NotRobux")
		local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
		local decision = ShopLogic.canBuyWithCoins(
			"vip-gold-tamago",
			{ coins = 999999, ownedSkins = { tamago = true }, equippedSkin = "tamago" },
			true
		)
		t.eq(decision.ok, false, "no coin unlock for the VIP skin")
	end)

	t.test(
		"QA canRequest: 이상한 id·없는 프로필, 가짜 로벅스는 VIP를 열지 않음, 가짜 결제는 CannotSave 무시",
		function()
			for _, junk in { 5, {}, "", string.rep("A", 10000), "STARTER-PACK", " starter-pack" } do
				local ok, reason = RealOfferLogic.canRequest(junk, view(), { canSave = true, fake = true })
				t.eq(ok, false)
				t.eq(reason, "Unknown")
			end
			t.eq(select(2, RealOfferLogic.canRequest("epic-set", nil, { canSave = true, fake = true })), "NoProfile")
			-- 가짜 로벅스(fake)만 켜고 가짜 VIP는 끔 → 패스 id가 없으니 NotForSale
			t.eq(select(2, RealOfferLogic.canRequest("vip", view(), { canSave = true, fake = true })), "NotForSale")
			t.eq(RealOfferLogic.canRequest("vip", view(), { canSave = false, fake = false, fakeVip = true }), true)
			-- VIP는 프로필 저장과 상관없음 (지급은 Roblox) — 패스 id가 있으면 CannotSave여도 열림
			local cat = patchedCatalog(true)
			t.eq(cat.OfferLogic.canRequest("vip", view(), { canSave = false, fake = false }), true)
			t.eq(
				select(2, cat.OfferLogic.canRequest("starter-pack", view(), { canSave = false, fake = false })),
				"CannotSave"
			)
			t.eq(cat.OfferLogic.canRequest("starter-pack", view(), { canSave = false, fake = true }), true)
			-- 이미 산 것 판단이 가짜 모드보다 먼저
			t.eq(
				select(
					2,
					cat.OfferLogic.canRequest(
						"fx-fireworks",
						view({ ownedFx = { fireworks = true } }),
						{ canSave = true, fake = true }
					)
				),
				"AlreadyOwned"
			)
			t.eq(
				select(
					2,
					cat.OfferLogic.canRequest(
						"vip",
						view({ vip = true }),
						{ canSave = true, fake = true, fakeVip = true }
					)
				),
				"AlreadyVip"
			)
		end
	)

	t.test(
		"QA canEquipFx: 이상한 인자 전부 거절, 잠금 중에는 벗기도 거절, 안 가진 칸 벗기는 허용",
		function()
			local owned = view({ ownedFx = { ["cat-customer"] = true } })
			local cases: { { any } } = {
				{ nil, "cat-customer", "BadSlot" },
				{ "elimination", "cat-customer", "BadSlot" },
				{ 1, "cat-customer", "BadSlot" },
				{ {}, nil, "BadSlot" },
				{ "Elimination", 5, "UnknownFx" },
				{ "Elimination", { id = "cat-customer" }, "UnknownFx" },
				{ "Elimination", "fireworks", "WrongSlot" },
				{ "Victory", "cat-customer", "WrongSlot" },
				{ "Victory", "fireworks", "NotOwned" },
				{ "Elimination", string.rep("x", 5000), "UnknownFx" },
			}
			for _, case in cases do
				local ok, reason = RealOfferLogic.canEquipFx(case[1], case[2], owned, false)
				t.eq(ok, false, tostring(case[1]))
				t.eq(reason, case[3], `{tostring(case[1])}/{tostring(case[2])}`)
			end
			t.eq(select(2, RealOfferLogic.canEquipFx("Elimination", nil, owned, true)), "Locked")
			t.eq(select(2, RealOfferLogic.canEquipFx("Elimination", "cat-customer", owned, true)), "Locked")
			t.eq(RealOfferLogic.canEquipFx("Victory", nil, owned, false), true)
			t.eq(RealOfferLogic.canEquipFx("Victory", "", owned, false), true)
			t.eq(select(2, RealOfferLogic.canEquipFx("Elimination", "cat-customer", nil, false)), "NoProfile")
		end
	)

	t.test(
		"QA applyGrant: 두 번 불러도 산 시각·보유가 그대로, 연출 equip=false면 칸 안 바뀜, 패스는 스킨만",
		function()
			local p = profile()
			local starter = RealOffers.get("starter-pack")
			local g1 = RealOfferLogic.applyGrant(p, starter, true, 100)
			t.eq(#g1.skins, 4)
			t.eq(p.equippedSkin, "tamago", "bundle does not equip")
			local g2 = RealOfferLogic.applyGrant(p, starter, true, 999)
			t.eq(#g2.skins, 0)
			t.eq(p.boughtOffers["starter-pack"], 100, "first purchase time kept")
			t.eq(count(p.ownedSkins), 5)

			local q = profile()
			q.equippedFx.Elimination = nil
			RealOfferLogic.applyGrant(q, RealOffers.get("fx-cat-customer"), false, 1)
			t.eq(q.ownedFx["cat-customer"], true)
			t.eq(q.equippedFx.Elimination, nil, "equip=false keeps slot")
			t.eq(q.boughtOffers["fx-cat-customer"], nil, "fx not in boughtOffers")

			local v = profile()
			RealOfferLogic.applyGrant(v, RealOffers.get("vip"), true, 1)
			t.eq(v.ownedSkins["vip-gold-tamago"], true)
			t.eq(v.equippedSkin, "tamago")
			t.eq(v.boughtOffers.vip, nil)
			-- 음수·소수 시각은 0 이상 정수로
			local w = profile()
			RealOfferLogic.applyGrant(w, RealOffers.get("epic-set"), false, -5.5)
			t.eq(w.boughtOffers["epic-set"], 0)
		end
	)

	t.test(
		"QA 화면: 일부 가진 묶음은 숨김, 산 묶음·연출·VIP는 아래 회색, 산 기록 + 일부 보유면 Bought",
		function()
			local v = view({
				ownedSkins = { "tamago", "rainbow-roll" }, -- 목록 모양 (클라이언트 보기)
				ownedFx = { "fireworks" },
				boughtOffers = { "starter-pack" },
				vip = true,
			})
			local list = RealOfferLogic.screenList(v, { fake = true })
			local ids = {}
			for _, e in list do
				table.insert(ids, `{e.offer.id}:{e.state.kind}`)
			end
			t.eq(ids, {
				"legendary-set:Buy",
				"fx-cat-customer:Buy",
				"starter-pack:Bought",
				"fx-fireworks:Bought",
				"vip:Bought",
			})
			-- 커밋 값(상품 id 없음, 가짜 결제 꺼짐) → 전부 "곧 열려요"
			for _, e in RealOfferLogic.screenList(view(), {}) do
				t.eq(e.state.kind, "Soon", e.offer.id)
				t.eq(LocTest.ko(RealOfferLogic.buttonText(e.state, e.offer.robux)), "곧 열려요")
			end
		end
	)

	---------------------------------------------------------------- 실제 서비스: 영수증
	t.test(
		"QA live: 스타터 팩 영수증 → 저장된 프로필에 4종 + boughtOffers, 기록 offerId, 장착 그대로, Notice 한 번",
		function()
			local env = loadServer()
			local p = env.join(1)
			env.run(5)
			t.eq(env.DataService.canPersist(p), true)
			t.eq(env.receipt(1, PRODUCT["starter-pack"], "pid-s1"), GRANTED)
			local saved = env.saved(1)
			for _, id in { "salmon", "tuna", "shrimp", "eel" } do
				t.eq(saved.ownedSkins[id], true, id)
			end
			t.ok(type(saved.boughtOffers["starter-pack"]) == "number", "boughtOffers saved")
			t.eq(saved.equippedSkin, "tamago", "not equipped")
			local record = env.purchases.data["pid-s1"]
			t.eq(record.offerId, "starter-pack")
			t.eq(record.skinId, nil)
			t.eq(record.userId, 1)
			t.eq(record.productId, PRODUCT["starter-pack"])
			t.eq(env.purchases.userIds["pid-s1"], { 1 })
			env.run(5)
			t.eq(#env.notices, 1)
			t.eq(LocTest.ko(env.notices[1].message), BUNDLE_NOTICE)
			t.ok(
				string.find(env.lastReceiptLine(), "offer starter-pack -> PurchaseGranted", 1, true) ~= nil,
				env.lastReceiptLine()
			)

			-- 같은 PurchaseId 다시 → AlreadyRecorded, 중복 없음, 안내 다시 안 함
			env.run(30)
			t.eq(env.receipt(1, PRODUCT["starter-pack"], "pid-s1"), GRANTED)
			t.ok(string.find(env.lastReceiptLine(), "AlreadyRecorded", 1, true) ~= nil)
			t.eq(count(env.DataService.get(p).ownedSkins), 5)
			t.eq(#env.notices, 1, "no second notice")
			-- 다른 PurchaseId로 또 옴(두 번 결제) → RecordOnly + warn, 지급 없음
			t.eq(env.receipt(1, PRODUCT["starter-pack"], "pid-s2"), GRANTED)
			t.ok(string.find(env.lastReceiptLine(), "RecordOnly", 1, true) ~= nil, env.lastReceiptLine())
			t.ok(env.warned("pid-s2"), "operator warn for double purchase")
			-- 그 뒤 결제 창 요청은 거절
			local ok, err = env.invoke("RequestOfferPurchase", p, "starter-pack")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "이미 샀어요")
		end
	)

	t.test(
		"QA live: 프로필 저장 실패 → NotProcessedYet·기록 없음, 저장소 회복 뒤 다시 오면 한 번만 지급",
		function()
			local env = loadServer()
			local p = env.join(2)
			env.run(5)
			env.profiles.failUpdate = true
			t.eq(env.receipt(2, PRODUCT["epic-set"], "pid-e1"), NOT_YET)
			t.eq(env.purchases.data["pid-e1"], nil, "no record before save")
			t.eq(#env.notices, 0)
			env.profiles.failUpdate = false
			env.run(30)
			t.eq(env.receipt(2, PRODUCT["epic-set"], "pid-e1"), GRANTED)
			t.eq(env.saved(2).ownedSkins["rainbow-roll"], true)
			t.eq(env.purchases.data["pid-e1"].offerId, "epic-set")
			t.eq(count(env.DataService.get(p).ownedSkins), 4)
		end
	)

	t.test(
		"QA live: 기록 쓰기 실패 → NotProcessedYet, 다시 오면 retry로 기록만 (지급·안내 한 번)",
		function()
			local env = loadServer()
			env.join(3)
			env.run(5)
			env.purchases.failUpdate = true
			t.eq(env.receipt(3, PRODUCT["legendary-set"], "pid-l1"), NOT_YET)
			t.eq(env.saved(3).ownedSkins["golden-otoro"], true, "saved before record")
			env.purchases.failUpdate = false
			env.run(30)
			t.eq(env.receipt(3, PRODUCT["legendary-set"], "pid-l1"), GRANTED)
			t.ok(
				string.find(env.lastReceiptLine(), "retry, offer already granted", 1, true) ~= nil,
				env.lastReceiptLine()
			)
			t.eq(env.purchases.data["pid-l1"].offerId, "legendary-set")
			env.run(5)
			t.eq(#env.notices, 0, "first attempt was NotProcessedYet → no notice; retry did not newly grant")
		end
	)

	t.test(
		"QA live: 기록은 있는데 다른 서버의 프로필이 되돌려짐 → AlreadyRecorded로 묶음 복원",
		function()
			local env = loadServer()
			env.join(4)
			env.run(5)
			t.eq(env.receipt(4, PRODUCT["starter-pack"], "pid-r1"), GRANTED)
			-- 서버 이동 + 프로필이 결제 전으로 되돌려짐 (저장소 직접 수정)
			local entry = env.profiles.data["u_4"]
			entry.profile.ownedSkins = { tamago = true }
			entry.profile.boughtOffers = {}
			entry.profile.receipts = {}
			entry.lock = nil
			local env2 = loadServer({ stores = env.stores })
			env2.join(4)
			env2.run(5)
			t.eq(env2.receipt(4, PRODUCT["starter-pack"], "pid-r1"), GRANTED)
			t.ok(string.find(env2.lastReceiptLine(), "offer restored", 1, true) ~= nil, env2.lastReceiptLine())
			t.eq(env2.saved(4).ownedSkins.eel, true)
			t.ok(env2.saved(4).boughtOffers["starter-pack"] ~= nil)
		end
	)

	t.test(
		"QA live: 결제 창 중 연어를 먼저 얻음 → 나머지 3개 지급 + warn (already owned: salmon)",
		function()
			local env = loadServer()
			local p = env.join(5)
			env.run(5)
			env.DataService.update(p, function(pr)
				pr.ownedSkins.salmon = true
			end)
			t.eq(env.receipt(5, PRODUCT["starter-pack"], "pid-p1"), GRANTED)
			t.ok(env.warned("already owned: salmon"), "warn")
			t.eq(count(env.saved(5).ownedSkins), 5)
		end
	)

	t.test(
		"QA live: 연출 영수증 → 보유 + 그 칸 장착 + 속성, 라운드 중이면 보유만(속성 없음)",
		function()
			local env = loadServer()
			local p = env.join(6)
			env.run(5)
			t.eq(env.receipt(6, PRODUCT["fx-cat-customer"], "pid-f1"), GRANTED)
			t.eq(env.saved(6).ownedFx["cat-customer"], true)
			t.eq(env.saved(6).equippedFx.Elimination, "cat-customer")
			t.eq(p:GetAttribute("EliminationFx"), "cat-customer")
			t.eq(p:GetAttribute("VictoryFx"), nil)
			env.run(5)
			t.eq(LocTest.ko(env.notices[1].message), "🎉 탈락 연출: 고양이 손님 획득!")

			env.locked[p] = true
			t.eq(env.receipt(6, PRODUCT["fx-fireworks"], "pid-f2"), GRANTED)
			t.eq(env.saved(6).ownedFx.fireworks, true)
			t.eq(env.saved(6).equippedFx.Victory, nil, "locked: owned only")
			t.eq(p:GetAttribute("VictoryFx"), nil)
		end
	)

	t.test(
		"QA live: 모르는 상품·패스 id로 온 영수증·모양이 틀린 영수증은 NotProcessedYet",
		function()
			local env = loadServer()
			env.join(7)
			env.run(5)
			t.eq(env.receipt(7, 424242, "pid-u1"), NOT_YET)
			t.eq(env.receipt(7, PASS_ID, "pid-u2"), NOT_YET) -- 게임 패스 id는 개발자 상품이 아님
			t.eq(env.purchases.data["pid-u1"], nil)
			local get = env.call(function()
				return env.market.ProcessReceipt({ PlayerId = 7, ProductId = "7001", PurchaseId = "x" })
			end)
			env.run(5)
			t.eq(get(), NOT_YET)
		end
	)

	t.test(
		"QA live: 실서버에서 fakeRobuxInStudio·fakeVipInStudio를 켜 둬도 무시 (결제 창·패스 확인 경로)",
		function()
			local env = loadServer({ studio = false, fake = true, fakeVip = true })
			local p = env.join(8)
			env.run(5)
			t.eq(p:GetAttribute("Vip"), nil, "fake VIP ignored on live")
			local ok = env.invoke("RequestOfferPurchase", p, "starter-pack")
			t.eq(ok, true)
			t.eq(#env.productPrompts, 1, "real prompt, not fake receipt")
			t.eq(env.productPrompts[1].productId, PRODUCT["starter-pack"])
			t.eq(env.saved(8) and env.saved(8).ownedSkins.salmon, nil)
			env.run(20)
			t.eq(env.invoke("RequestOfferPurchase", p, "vip"), true)
			t.eq(#env.passPrompts, 1)
			t.eq(env.passPrompts[1].passId, PASS_ID)
			t.eq(p:GetAttribute("Vip"), nil, "prompt alone does not make VIP")
		end
	)

	---------------------------------------------------------------- 실제 서비스: 리모트 검증
	t.test(
		"QA RequestOfferPurchase: 이상한 인자 거절, 1초 간격, 일부 보유 묶음 OwnsSome, 상품 id 없으면 준비 중",
		function()
			local env = loadServer()
			local p = env.join(9)
			env.run(5)
			for _, junk in { 5, {}, "", "nope", string.rep("A", 10000) } do
				local ok, err = env.invoke("RequestOfferPurchase", p, junk)
				t.eq(ok, false)
				t.eq(LocTest.ko(err), "없는 상품이에요")
				env.run(12)
			end
			t.eq(#env.productPrompts, 0)
			local ok1 = env.invoke("RequestOfferPurchase", p, "fx-fireworks")
			t.eq(ok1, true)
			local ok2, err2 = env.invoke("RequestOfferPurchase", p, "fx-fireworks")
			t.eq(ok2, false)
			t.eq(LocTest.ko(err2), "잠시 뒤에 다시 해 주세요")
			t.eq(#env.productPrompts, 1)
			env.run(12)
			env.DataService.update(p, function(pr)
				pr.ownedSkins["dragon-roll"] = true
			end)
			local ok3, err3 = env.invoke("RequestOfferPurchase", p, "legendary-set")
			t.eq(ok3, false)
			t.eq(LocTest.ko(err3), "이미 가진 스킨이 있어서 따로 사야 해요")

			local env2 = loadServer({ withIds = false })
			local q = env2.join(10)
			env2.run(5)
			local ok4, err4 = env2.invoke("RequestOfferPurchase", q, "starter-pack")
			t.eq(ok4, false)
			t.eq(LocTest.ko(err4), "준비 중이에요")
			env2.run(12)
			local ok5, err5 = env2.invoke("RequestOfferPurchase", q, "vip")
			t.eq(ok5, false)
			t.eq(LocTest.ko(err5), "준비 중이에요")
			t.eq(#env2.productPrompts + #env2.passPrompts, 0)
		end
	)

	t.test(
		"QA EquipFx: 이상한 인자·안 가진 연출·라운드 중 거절, 입기/벗기 속성·저장, 0.3초 간격",
		function()
			local env = loadServer()
			local p = env.join(11)
			env.run(5)
			local junk: { { any } } = {
				{},
				{ "Elimination", "cat-customer" }, -- 아직 없음
				{ "Victory", "cat-customer" },
				{ 5, "cat-customer" },
				{ "Elimination", { "x" } },
				{ string.rep("A", 10000), nil },
			}
			for _, args in junk do
				local ok = env.invoke("EquipFx", p, table.unpack(args))
				t.eq(ok, false)
				env.run(5)
			end
			t.eq(p:GetAttribute("EliminationFx"), nil)

			env.locked[p] = true -- 라운드 중 영수증 → 보유만
			t.eq(env.receipt(11, PRODUCT["fx-cat-customer"], "pid-x1"), GRANTED)
			t.eq(p:GetAttribute("EliminationFx"), nil)
			local okL, errL = env.invoke("EquipFx", p, "Elimination", "cat-customer")
			t.eq(okL, false)
			t.eq(LocTest.ko(errL), "매치가 끝나면 바꿀 수 있어요")
			env.locked[p] = nil
			env.run(5)
			local equip = env.functions.EquipFx.OnServerInvoke
			t.eq(equip(p, "Elimination", "cat-customer"), true)
			t.eq(p:GetAttribute("EliminationFx"), "cat-customer")
			t.eq(env.DataService.get(p).equippedFx.Elimination, "cat-customer")
			local okT, errT = equip(p, "Elimination", nil) -- 같은 시각 (간격 0.3초 안)
			t.eq(okT, false, "within cooldown")
			t.eq(LocTest.ko(errT), "잠시 뒤에 다시 해 주세요")
			env.run(5)
			t.eq(env.invoke("EquipFx", p, "Elimination", ""), true)
			t.eq(p:GetAttribute("EliminationFx"), nil, "attribute removed when unequipped")
			t.eq(env.DataService.get(p).equippedFx.Elimination, nil)
		end
	)

	t.test(
		"QA 속성 계약(m5-09): 프로필에 입은 연출이 있으면 접속·로드 때 속성 = FxCatalog id",
		function()
			local env = loadServer()
			local p = env.join(12)
			env.run(5)
			t.eq(env.receipt(12, PRODUCT["fx-fireworks"], "pid-v1"), GRANTED)
			t.eq(p:GetAttribute("VictoryFx"), "fireworks")
			env.saved(12) -- 저장됨
			local entry = env.profiles.data["u_12"]
			entry.lock = nil
			local env2 = loadServer({ stores = env.stores })
			local p2 = env2.join(12)
			env2.run(5)
			t.eq(p2:GetAttribute("VictoryFx"), "fireworks")
			t.eq(p2:GetAttribute("EliminationFx"), nil)
			t.ok(FxCatalog.get(p2:GetAttribute("VictoryFx")) ~= nil)
		end
	)

	---------------------------------------------------------------- 실제 서비스: VIP
	t.test(
		"QA VIP: 패스 보유 → 속성·보기 vip·스킨 지급(장착 안 함)·저장, 다시 요청하면 이미 VIP",
		function()
			local env = loadServer({ passOwners = { [13] = true } })
			local p = env.join(13)
			env.run(10)
			t.eq(p:GetAttribute("Vip"), true)
			t.eq(env.OfferService.isVip(p), true)
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], true)
			t.eq(env.DataService.get(p).equippedSkin, "tamago")
			t.eq(env.saved(13).ownedSkins["vip-gold-tamago"], true, "saved")
			local ok, err = env.invoke("RequestOfferPurchase", p, "vip")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "이미 VIP예요")
			t.eq(#env.passPrompts, 0)
		end
	)

	t.test(
		"QA VIP: 확인 실패 1번 → 5초 뒤 다시 → VIP / 2번 실패 → 이번 접속 VIP 아님 + warn",
		function()
			local env = loadServer({ passOwners = { [14] = { "error", true }, [15] = { "error", "error" } } })
			local a = env.join(14)
			local b = env.join(15)
			env.run(20) -- 2초
			t.eq(a:GetAttribute("Vip"), nil, "not before retry")
			env.run(40) -- 6초
			t.eq(a:GetAttribute("Vip"), true)
			t.eq(b:GetAttribute("Vip"), nil)
			t.ok(env.warned("could not check VIP pass for P15"), "warn after second failure")
			t.eq(env.ownsCalls, 4)
		end
	)

	t.test(
		"QA VIP: 패스 없음 → VIP 아님, 다른 패스 id·안 산 PromptGamePassPurchaseFinished는 무시",
		function()
			local env = loadServer({ passOwners = { [16] = false } })
			local p = env.join(16)
			env.run(10)
			t.eq(p:GetAttribute("Vip"), nil)
			env.market.PromptGamePassPurchaseFinished:Fire(p, 12345, true)
			env.market.PromptGamePassPurchaseFinished:Fire(p, PASS_ID, false)
			env.run(5)
			t.eq(p:GetAttribute("Vip"), nil)
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], nil)
			env.market.PromptGamePassPurchaseFinished:Fire(p, PASS_ID, true)
			env.run(5)
			t.eq(p:GetAttribute("Vip"), true)
		end
	)

	t.test("QA VIP: 패스가 없어져도 받은 스킨은 남아요 (다음 접속은 VIP 아님)", function()
		local env = loadServer({ passOwners = { [17] = true } })
		env.join(17)
		env.run(10)
		env.profiles.data["u_17"].lock = nil
		local env2 = loadServer({ stores = env.stores, passOwners = { [17] = false } })
		local p2 = env2.join(17)
		env2.run(10)
		t.eq(p2:GetAttribute("Vip"), nil)
		t.eq(env2.DataService.get(p2).ownedSkins["vip-gold-tamago"], true)
	end)

	t.test(
		"QA Studio 가짜 결제: 스타터 팩 요청 → 메모리 프로필에 지급, 가짜 VIP는 바로 VIP",
		function()
			local env = loadServer({ studio = true, fake = true, fakeVip = true })
			local p = env.join(18)
			env.run(10)
			t.eq(p:GetAttribute("Vip"), true, "fakeVip on join")
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], true)
			t.eq(env.invoke("RequestOfferPurchase", p, "starter-pack"), true)
			env.run(10)
			t.eq(env.DataService.get(p).ownedSkins.eel, true)
			t.eq(#env.productPrompts, 0)
			t.ok(string.find(env.lastReceiptLine(), "offer starter-pack -> PurchaseGranted", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 정적: 결제 처리 한 곳
	t.test(
		"QA 정적: ProcessReceipt 대입은 RobuxShopService 하나, OfferService는 PromptProductPurchaseFinished로 지급하지 않음",
		function()
			local assigned = {}
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.sub(name, -5) == ".luau" then
						local src = fs.readFile(path)
						if string.find(src, "%.ProcessReceipt%s*=") then
							table.insert(assigned, path)
						end
					end
				end
			end
			scan("src")
			t.eq(assigned, { "src/server/RobuxShopService.luau" })
			local offerSrc = fs.readFile("src/server/OfferService.luau")
			t.eq(string.find(offerSrc, "PromptProductPurchaseFinished", 1, true), nil)
			t.eq(string.find(offerSrc, "coins", 1, true), nil, "no coin grant in offers")
		end
	)
	---------------------------------------------------------------- 개발 QA 수정 (B1·B3)
	t.test(
		"dev B1: 산 이벤트만으로는 영구 VIP 스킨을 주지 않아요 (확인 안 되면 표시만, warn)",
		function()
			local env = loadServer({ passOwners = { [20] = false } })
			local p = env.join(20)
			env.run(10)
			env.market.PromptGamePassPurchaseFinished:Fire(p, PASS_ID, true)
			env.run(2)
			t.eq(p:GetAttribute("Vip"), true, "session perks right away")
			t.eq(env.OfferService.isVip(p), true)
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], nil, "no skin before confirmation")
			env.run(200) -- 20초: 0/2/5/10초 다시 묻기 끝
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], nil, "never confirmed → no skin")
			t.ok(env.warned("not confirmed yet"), "warn")
			t.eq(env.ownsCalls, 1 + #RealOfferLogic.VIP_PURCHASE_RECHECK, "join check + rechecks")
			local saved = env.saved(20)
			t.ok(saved == nil or saved.ownedSkins["vip-gold-tamago"] == nil, "not saved")
		end
	)

	t.test(
		"dev B1: 산 뒤 다시 물어서 true가 나오면 그때 스킨 지급·저장 (장착 안 함)",
		function()
			local env = loadServer({ passOwners = { [21] = { false, false, true } } })
			local p = env.join(21)
			env.run(10) -- 접속 확인: false
			env.market.PromptGamePassPurchaseFinished:Fire(p, PASS_ID, true)
			env.run(10) -- 0초 다시 묻기: false (캐시)
			t.eq(p:GetAttribute("Vip"), true)
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], nil)
			env.run(20) -- 2초 다시 묻기: true
			t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], true)
			t.eq(env.DataService.get(p).equippedSkin, "tamago")
			t.eq(env.saved(21).ownedSkins["vip-gold-tamago"], true, "saved")
			t.eq(env.ownsCalls, 3)
			env.run(200)
			t.eq(env.ownsCalls, 3, "stops asking once confirmed")
			t.eq(env.warned("not confirmed yet"), false)
		end
	)

	t.test("dev B3: Studio에서 persistDataInStudio와 같이 켜면 fakeVipInStudio는 꺼지고 warn", function()
		local env = loadServer({ studio = true, fakeVip = true, persistInStudio = true, passOwners = { [22] = false } })
		local p = env.join(22)
		env.run(20)
		t.eq(p:GetAttribute("Vip"), nil, "no fake VIP")
		t.eq(env.DataService.get(p).ownedSkins["vip-gold-tamago"], nil, "no VIP skin in the real store")
		t.ok(env.warned("fakeVipInStudio is ignored while persistDataInStudio is on"), "startup warn")
		-- 따로 켜면 그대로 가짜 VIP (QA "Studio 가짜 결제" 케이스와 같음)
		local env2 = loadServer({ studio = true, fakeVip = true })
		local p2 = env2.join(23)
		env2.run(10)
		t.eq(p2:GetAttribute("Vip"), true)
	end)
end
