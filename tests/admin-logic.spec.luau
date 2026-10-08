--!strict
-- m5-02 테스트용 관리자 스킨 미리보기: Shared.AdminLogic (순수) + AdminService·ShopService를 가짜 Roblox로 돌려서
-- 권한(클라이언트가 단 IsAdmin 속성은 무시)·저장 오염 없음·서버 간 유지 값을 확인해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local Skins = RobloxRequire.require(Shared.Skins)

local OWNER = 11402290839

local function known(id: string): boolean
	return Skins.get(id) ~= nil
end

local function input(overrides: { [string]: any }): any
	local base = {
		isStudio = false,
		userId = OWNER,
		allowList = { OWNER },
		includeOwner = false,
		creatorType = "User",
		creatorId = 1,
		studioAllAdmins = true,
		liveEnabled = true,
	}
	for k, v in overrides do
		(base :: any)[k] = v
	end
	return base
end

---------------------------------------------------------------- 가짜 Roblox 환경
type Env = {
	clock: number,
	studio: boolean,
	adminConfig: { [string]: any },
	creatorType: string,
	creatorId: number,
	invoke: (player: any, skinId: any) -> (boolean, string?),
	remotes: { [string]: any },
	join: (userId: number, attrs: { [string]: any }?) -> any,
	leave: (player: any) -> (),
	profiles: { [number]: any },
	writes: { string },
	refreshes: { any },
	placed: { [any]: boolean },
	store: { [string]: any },
	storeWrites: { { key: string, value: any, ttl: number } },
	warnings: { string },
	resolve: (player: any) -> string?,
	AdminService: any,
	ShopService: any,
}

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

local function load(path: string, environment: { [string]: any }): any
	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end

type EnvOptions = {
	studio: boolean?,
	adminConfig: { [string]: any }?,
	creatorType: string?,
	creatorId: number?,
}

local function loadEnv(options: EnvOptions?): Env
	local opts = options or {}
	local env = {} :: Env
	env.clock = 100
	env.studio = opts.studio == true
	env.adminConfig = opts.adminConfig
		or { UserIds = { OWNER }, IncludeOwner = true, StudioAllAdmins = true, LiveEnabled = true }
	env.creatorType = opts.creatorType or "User"
	env.creatorId = opts.creatorId or 1
	env.remotes = {}
	env.profiles = {}
	env.writes = {}
	env.refreshes = {}
	env.placed = {}
	env.store = {}
	env.storeWrites = {}
	env.warnings = {}

	local list: { any } = {}
	local Players = { PlayerAdded = newSignal(), PlayerRemoving = newSignal() }
	function Players.GetPlayers(_)
		return table.clone(list)
	end
	local services: { [string]: any } = {
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
				return env.studio
			end,
		},
		MemoryStoreService = {
			GetHashMap = function()
				error("tests use AdminService.setStore")
			end,
		},
	}

	local function remote(name: string): any
		if env.remotes[name] == nil then
			env.remotes[name] = { Name = name }
		end
		return env.remotes[name]
	end

	-- 가짜 서버 모듈: 프로필·외형에 무엇을 부르는지 기록해요
	local DataService = {
		get = function(player)
			return env.profiles[player.UserId]
		end,
		update = function(player, fn)
			table.insert(env.writes, `update:{player.UserId}`)
			fn(env.profiles[player.UserId])
			return true
		end,
		saveNow = function(player)
			table.insert(env.writes, `saveNow:{player.UserId}`)
		end,
		canPersist = function()
			return true
		end,
		onLoaded = function() end,
	}
	local resolver: any = nil
	local AppearanceService = {
		setResolver = function(fn)
			resolver = fn
		end,
		refresh = function(player)
			table.insert(env.refreshes, player)
		end,
	}
	local serverModules: { [string]: any } = {
		DataService = DataService,
		AppearanceService = AppearanceService,
		MatchEvents = { onResult = function() end },
		RoundService = {
			placedRoomOf = function(player)
				return if env.placed[player] then "room-1" else nil
			end,
		},
		AdminConfig = env.adminConfig,
	}

	local function environment(): { [string]: any }
		return {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
				CreatorType = env.creatorType,
				CreatorId = env.creatorId,
			},
			Enum = { CreatorType = { User = "User", Group = "Group" } },
			script = {
				Parent = setmetatable({}, {
					__index = function(_, name: string)
						return { __server = name }
					end,
				}),
			},
			require = function(target: any)
				if target.__shared == "Remotes" then
					return { fn = remote }
				elseif target.__shared then
					return RobloxRequire.require((Shared :: any)[target.__shared])
				end
				return assert(serverModules[target.__server], target.__server)
			end,
			task = {
				spawn = function(fn, ...)
					fn(...)
				end,
				delay = function() end,
			},
			os = {
				clock = function()
					return env.clock
				end,
				time = function()
					return 1700000000
				end,
			},
			warn = function(...)
				table.insert(env.warnings, table.concat({ ... }, " "))
			end,
			print = function() end,
		}
	end

	env.ShopService = load("src/server/ShopService.luau", environment())
	serverModules.ShopService = env.ShopService
	env.AdminService = load("src/server/AdminService.luau", environment())
	env.AdminService.setStore({
		get = function(key)
			return env.store[key]
		end,
		set = function(key, value, ttl)
			env.store[key] = value
			table.insert(env.storeWrites, { key = key, value = value, ttl = ttl })
		end,
	})
	env.ShopService.init()
	env.AdminService.init()
	env.ShopService.start()
	env.AdminService.start()

	function env.invoke(player, skinId)
		env.clock += 1 -- 요청 간격 제한을 넘겨요
		return env.remotes.AdminPreviewSkin.OnServerInvoke(player, skinId)
	end
	function env.join(userId: number, attrs: { [string]: any }?): any
		local attributes = table.clone(attrs or {})
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			Parent = Players,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
		}
		env.profiles[userId] = {
			coins = 50,
			ownedSkins = { tamago = true, salmon = true },
			equippedSkin = "salmon",
		}
		table.insert(list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function env.leave(player)
		local index = table.find(list, player)
		if index then
			table.remove(list, index)
		end
		player.Parent = nil
		Players.PlayerRemoving:Fire(player)
	end
	function env.resolve(player)
		return resolver(player)
	end
	return env
end

local function snapshot(profile: any): string
	local owned = {}
	for id in profile.ownedSkins do
		table.insert(owned, id)
	end
	table.sort(owned)
	return `{profile.coins}|{profile.equippedSkin}|{table.concat(owned, ",")}`
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1·AC2 isAdmin
	t.test("AC1: Studio + studioAllAdmins → negative test account is admin", function()
		t.eq(AdminLogic.isAdmin(input({ isStudio = true, userId = -1, allowList = {} })), true)
	end)

	t.test("AC1: Studio + studioAllAdmins false → only listed ids", function()
		t.eq(AdminLogic.isAdmin(input({ isStudio = true, studioAllAdmins = false, userId = -1 })), false)
		t.eq(AdminLogic.isAdmin(input({ isStudio = true, studioAllAdmins = false, userId = OWNER })), true)
	end)

	t.test("AC1: live server uses the allow list; 0 and negative ids never", function()
		t.eq(AdminLogic.isAdmin(input({ userId = OWNER })), true)
		t.eq(AdminLogic.isAdmin(input({ userId = 123 })), false)
		t.eq(AdminLogic.isAdmin(input({ userId = 0, allowList = { 0 } })), false)
		t.eq(AdminLogic.isAdmin(input({ userId = -1, allowList = { -1 } })), false)
		t.eq(AdminLogic.isAdmin(input({ userId = 1.5, allowList = { 1.5 } })), false)
	end)

	t.test("AC1: studioAllAdmins does nothing on a live server", function()
		t.eq(AdminLogic.isAdmin(input({ userId = 123, studioAllAdmins = true })), false)
	end)

	t.test("AC2: owner of a user-owned game is admin when includeOwner", function()
		t.eq(AdminLogic.isAdmin(input({ userId = 55, includeOwner = true, creatorId = 55 })), true)
		t.eq(
			AdminLogic.isAdmin(input({ userId = 55, includeOwner = true, creatorType = "Group", creatorId = 55 })),
			false
		)
		t.eq(AdminLogic.isAdmin(input({ userId = 55, includeOwner = false, creatorId = 55 })), false)
	end)

	t.test("AC2: LiveEnabled false → nobody on a live server, even listed or owner", function()
		t.eq(AdminLogic.isAdmin(input({ userId = OWNER, liveEnabled = false })), false)
		t.eq(
			AdminLogic.isAdmin(input({ userId = 55, includeOwner = true, creatorId = 55, liveEnabled = false })),
			false
		)
		-- Studio는 영향 없음
		t.eq(AdminLogic.isAdmin(input({ isStudio = true, userId = -1, liveEnabled = false })), true)
	end)

	---------------------------------------------------------------- AC3 checkPreview
	t.test("AC3: checkPreview rejects non-admin, bad types and unknown skins", function()
		local ok, reason = AdminLogic.checkPreview(false, "uni", known, false)
		t.eq(ok, false)
		t.eq(reason, "NotAdmin")
		t.eq(AdminLogic.message(reason), "권한이 없어요")
		ok, reason = AdminLogic.checkPreview(true, 5, known, false)
		t.eq(ok, false)
		t.eq(reason, "BadArgument")
		ok, reason = AdminLogic.checkPreview(true, { "uni" }, known, false)
		t.eq(ok, false)
		t.eq(reason, "BadArgument")
		ok, reason = AdminLogic.checkPreview(true, "nope", known, false)
		t.eq(ok, false)
		t.eq(reason, "UnknownSkin")
		t.eq(AdminLogic.message(reason), "없는 스킨이에요")
	end)

	t.test("AC3: nil and empty string turn the preview off; unowned skin is fine", function()
		local ok, reason, id = AdminLogic.checkPreview(true, nil, known, false)
		t.eq(ok, true)
		t.eq(reason, nil)
		t.eq(id, nil)
		ok, _, id = AdminLogic.checkPreview(true, "", known, false)
		t.eq(ok, true)
		t.eq(id, nil)
		ok, _, id = AdminLogic.checkPreview(true, "dragon-roll", known, false)
		t.eq(ok, true)
		t.eq(id, "dragon-roll")
	end)

	t.test("AC3: locked rejects both preview and off", function()
		local ok, reason = AdminLogic.checkPreview(true, "uni", known, true)
		t.eq(ok, false)
		t.eq(reason, "Locked")
		t.eq(AdminLogic.message(reason), "라운드 중에는 바꿀 수 없어요")
		ok, reason = AdminLogic.checkPreview(true, nil, known, true)
		t.eq(ok, false)
		t.eq(reason, "Locked")
	end)

	---------------------------------------------------------------- AC4 pickAppearance
	t.test("AC4: preview beats equipped; falls back to owned equipped, then nil", function()
		local owned = { salmon = true }
		t.eq(AdminLogic.pickAppearance("uni", "salmon", owned, known), "uni")
		t.eq(AdminLogic.pickAppearance(nil, "salmon", owned, known), "salmon")
		t.eq(AdminLogic.pickAppearance(nil, "salmon", {}, known), nil)
		t.eq(AdminLogic.pickAppearance("not-a-skin", "salmon", owned, known), "salmon")
	end)

	t.test("store entry: encode/decode round trip, off and garbage decode to nil", function()
		t.eq(AdminLogic.storeKey(OWNER), "u_11402290839")
		local entry = AdminLogic.encodeEntry("uni", 10)
		t.eq(entry.skinId, "uni")
		t.eq(entry.at, 10)
		t.eq(AdminLogic.decodeEntry(entry, known), "uni")
		t.eq(AdminLogic.encodeEntry(nil, 10).skinId, false)
		t.eq(AdminLogic.decodeEntry(AdminLogic.encodeEntry(nil, 10), known), nil)
		t.eq(AdminLogic.decodeEntry({ skinId = "nope" }, known), nil)
		t.eq(AdminLogic.decodeEntry("uni", known), nil)
		t.eq(AdminLogic.decodeEntry(nil, known), nil)
	end)

	---------------------------------------------------------------- AdminService + ShopService (가짜 Roblox)
	t.test("server: listed admin gets IsAdmin and can preview without touching the profile", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		t.eq(p:GetAttribute("IsAdmin"), true)
		local before = snapshot(env.profiles[OWNER])
		local ok, err = env.invoke(p, "golden-otoro")
		t.eq(ok, true)
		t.eq(err, nil)
		t.eq(env.resolve(p), "golden-otoro")
		t.eq(p:GetAttribute("AdminPreview"), "golden-otoro")
		t.eq(env.profiles[OWNER].ownedSkins["golden-otoro"], nil)
		t.eq(snapshot(env.profiles[OWNER]), before)
		t.eq(#env.writes, 0) -- DataService.update·saveNow를 부르지 않아요
		t.ok(#env.refreshes >= 1, "re-dressed")
		-- 끄면 장착 스킨으로
		ok = env.invoke(p, nil)
		t.eq(ok, true)
		t.eq(env.resolve(p), "salmon")
		t.eq(p:GetAttribute("AdminPreview"), nil)
		t.eq(#env.writes, 0)
	end)

	t.test("server: a client-set IsAdmin attribute does not open the remote", function()
		local env = loadEnv()
		local p = env.join(123, { IsAdmin = true }) -- 클라이언트가 스스로 단 것처럼
		local ok, err = env.invoke(p, "uni")
		t.eq(ok, false)
		t.eq(err, "권한이 없어요")
		t.eq(env.ShopService.getPreview(p), nil)
		t.eq(env.resolve(p), "salmon")
		t.eq(#env.warnings, 1)
		env.invoke(p, "uni")
		t.eq(#env.warnings, 1) -- warn은 플레이어당 한 번
		t.eq(env.store["u_123"], nil)
	end)

	t.test("server: non-admin gets no IsAdmin attribute and no store read", function()
		local env = loadEnv()
		env.store["u_123"] = { skinId = "uni", at = 1 }
		local p = env.join(123)
		t.eq(p:GetAttribute("IsAdmin"), nil)
		t.eq(env.resolve(p), "salmon")
	end)

	t.test("server: game owner (user-owned) is admin; group-owned is not", function()
		local env = loadEnv({ creatorId = 77 })
		t.eq(env.join(77):GetAttribute("IsAdmin"), true)
		local group = loadEnv({ creatorType = "Group", creatorId = 77 })
		t.eq(group.join(77):GetAttribute("IsAdmin"), nil)
	end)

	t.test("server: unknown skin, bad type, too fast and locked are rejected", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		t.eq(select(2, env.invoke(p, "nope")), "없는 스킨이에요")
		t.eq(select(2, env.invoke(p, 42)), "없는 스킨이에요")
		env.invoke(p, "uni")
		local ok, err = env.remotes.AdminPreviewSkin.OnServerInvoke(p, "salmon") -- 같은 시각 두 번째
		t.eq(ok, false)
		t.eq(err, "잠시 뒤에 다시 해 주세요")
		env.placed[p] = true
		ok, err = env.invoke(p, "dragon-roll")
		t.eq(ok, false)
		t.eq(err, "라운드 중에는 바꿀 수 없어요")
		t.eq(env.resolve(p), "uni")
	end)

	t.test("server: EquipSkin success turns the preview off", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.invoke(p, "uni")
		env.clock += 1
		local ok = env.remotes.EquipSkin.OnServerInvoke(p, "tamago")
		t.eq(ok, true)
		t.eq(env.ShopService.getPreview(p), nil)
		t.eq(env.resolve(p), "tamago")
		t.eq(p:GetAttribute("AdminPreview"), nil)
		t.eq(env.store["u_11402290839"].skinId, false) -- 서버 간 유지 값도 꺼요
	end)

	t.test("server: grantSkin with equip turns the preview off", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.invoke(p, "uni")
		t.eq(env.ShopService.grantSkin(p, "dragon-roll", true), true)
		t.eq(env.ShopService.getPreview(p), nil)
		t.eq(env.resolve(p), "dragon-roll")
	end)

	t.test("server: live preview writes AdminPreview_v1 with 1h TTL, restored after re-check", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.invoke(p, "dragon-roll")
		local last = env.storeWrites[#env.storeWrites]
		t.eq(last.key, "u_11402290839")
		t.eq(last.value.skinId, "dragon-roll")
		t.eq(last.ttl, 3600)
		env.leave(p)
		t.eq(env.store["u_11402290839"].skinId, "dragon-roll") -- 나갈 때 지우지 않아요
		-- 다른 서버(매치)에 도착: 관리자를 다시 판단한 뒤 복원
		local other = loadEnv()
		other.store["u_11402290839"] = env.store["u_11402290839"]
		local arrived = other.join(OWNER)
		t.eq(other.resolve(arrived), "dragon-roll")
		t.eq(#other.storeWrites, 0) -- 복원은 다시 쓰지 않아요
		t.eq(#other.writes, 0)
	end)

	t.test("server: store entry is not restored if that server says not admin", function()
		local env = loadEnv({
			adminConfig = { UserIds = {}, IncludeOwner = false, StudioAllAdmins = true, LiveEnabled = true },
		})
		env.store["u_11402290839"] = { skinId = "uni", at = 1 }
		local p = env.join(OWNER)
		t.eq(p:GetAttribute("IsAdmin"), nil)
		t.eq(env.resolve(p), "salmon")
	end)

	t.test("server: LiveEnabled false → listed user is not admin on a live server", function()
		local env = loadEnv({
			adminConfig = { UserIds = { OWNER }, IncludeOwner = true, StudioAllAdmins = true, LiveEnabled = false },
		})
		local p = env.join(OWNER)
		t.eq(p:GetAttribute("IsAdmin"), nil)
		t.eq(select(2, env.invoke(p, "uni")), "권한이 없어요")
	end)

	t.test("server: Studio makes test accounts admin and skips MemoryStore", function()
		local env = loadEnv({ studio = true })
		env.AdminService.setStore(nil)
		local p = env.join(-1)
		t.eq(p:GetAttribute("IsAdmin"), true)
		t.eq(env.invoke(p, "uni"), true)
		t.eq(env.resolve(p), "uni")
		t.eq(#env.storeWrites, 0)
	end)

	t.test("source: preview path never calls profile, reward or purchase writers", function()
		local source = fs.readFile("src/server/AdminService.luau")
		for _, banned in
			{ "DataService", "RewardService", "PurchaseLog", "ReceiptLogic", "ShopLogic", "DataStoreService" }
		do
			t.eq(string.find(source, banned, 1, true), nil, `AdminService mentions {banned}`)
		end
		t.eq(string.find(source, "GetAttribute(", 1, true), nil, "AdminService never reads attributes for permission")
	end)

	t.test("source: admin list lives only in the server-only AdminConfig", function()
		t.ok(fs.isFile("src/server/AdminConfig.luau"), "AdminConfig exists")
		t.eq(string.find(fs.readFile("src/shared/Config.luau"), "11402290839", 1, true), nil)
		t.eq(string.find(fs.readFile("src/shared/AdminLogic.luau"), "11402290839", 1, true), nil)
	end)
end
