--!strict
-- m5-02 테스트용 관리자 스킨 미리보기: Shared.AdminLogic (순수) + AdminService·ShopService를 가짜 Roblox로 돌려서
-- 권한(클라이언트가 단 IsAdmin 속성은 무시)·저장 오염 없음·서버 간 유지 값을 확인해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local Maps = RobloxRequire.require(Shared.maps)
local Seasons = RobloxRequire.require(Shared.Seasons)
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

---------------------------------------------------------------- m5-11 AdminCommands (가짜 서버 모듈)
local HALLOWEEN_NOW = 1792108800 + 3600 -- halloween-2026 진행 중

local function loadCommands(options: { [string]: any }?): any
	local opts = options or {}
	local env: any = {
		role = opts.role or "Single",
		locked = false,
		persist = false,
		now = opts.now or 1700000000,
		profile = {
			coins = 100,
			wins = 3,
			ownedSkins = { tamago = true, salmon = true },
			equippedSkin = "salmon",
			eventTokens = {},
			ownedFx = { ["cat-customer"] = true },
			equippedFx = { Elimination = "cat-customer" },
			redeemedCodes = { ABC = 1 },
		},
		roomId = "7",
		room = { id = "7", state = "Waiting" },
		forceStarts = {},
		nextPlans = {},
		saves = 0,
		previews = {},
	}
	local attributes: { [string]: any } = {}
	local player = {
		UserId = 1,
		Name = "Admin",
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
	}
	env.player = player
	env.attributes = attributes
	local serverModules: { [string]: any } = {
		DataService = {
			get = function()
				return env.profile
			end,
			update = function(_, fn)
				if env.profile == nil then
					return false
				end
				fn(env.profile)
				return true
			end,
			saveNow = function()
				env.saves += 1
				return false
			end,
			canPersist = function()
				return env.persist
			end,
		},
		MatchService = {
			setNextPlan = function(roomId, plan)
				env.nextPlans[roomId] = plan
			end,
		},
		PlaceService = {
			role = function()
				return env.role
			end,
		},
		RoomService = {
			getRoomIdOf = function()
				return env.roomId
			end,
			getRoom = function()
				return env.room
			end,
			listRooms = function()
				return { env.room }
			end,
			forceStart = function(roomId)
				table.insert(env.forceStarts, roomId)
				return true, nil
			end,
		},
		ShopService = {
			isLocked = function()
				return env.locked
			end,
			setPreview = function(_, skinId)
				table.insert(env.previews, skinId or "off")
				return true
			end,
		},
	}
	local services: { [string]: any } = {
		Players = {
			GetPlayers = function()
				return { player }
			end,
		},
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
		RunService = {
			IsStudio = function()
				return true
			end,
		},
	}
	env.AdminCommands = luau.load(fs.readFile("src/server/AdminCommands.luau"), {
		debugName = "AdminCommands",
		environment = {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
				JobId = "abcdef0123456789",
			},
			script = {
				Parent = setmetatable({}, {
					__index = function(_, name: string)
						return { __server = name }
					end,
				}),
			},
			require = function(target: any)
				if target.__shared then
					return RobloxRequire.require((Shared :: any)[target.__shared])
				end
				return assert(serverModules[target.__server], target.__server)
			end,
			task = {
				spawn = function(fn, ...)
					fn(...)
				end,
			},
			os = {
				time = function()
					return env.now
				end,
				clock = os.clock,
			},
		},
	})()
	function env.run(command: string, args: any): (boolean, string?)
		local parsed = assert(AdminLogic.parse(command, args))
		return env.AdminCommands.run(player, parsed)
	end
	return env
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

	---------------------------------------------------------------- m5-11 관리자 명령: 순수 로직
	t.test("m5-11 AC1: commandTier for all 7 commands, unknown nil", function()
		for _, name in { "info", "fx" } do
			t.eq(AdminLogic.commandTier(name), "Info", name)
		end
		for _, name in { "start", "plan" } do
			t.eq(AdminLogic.commandTier(name), "Test", name)
		end
		t.eq(AdminLogic.commandTier("resetprofile"), "StudioOnly")
		-- 경제 명령은 저장을 켠 Studio에서도 막아요 (2026-10-13 사용자 결정)
		t.eq(AdminLogic.commandTier("coins"), "StudioOnly")
		t.eq(AdminLogic.commandTier("tokens"), "StudioOnly")
		for _, bad in { "kick", "give", "", "INFO", 1, true, {} } :: { any } do
			t.eq(AdminLogic.commandTier(bad), nil)
		end
		t.eq(AdminLogic.commandTier(nil), nil)
	end)

	t.test("m5-11 AC2: canRun 3 tiers x 3 environments (live server has no switch)", function()
		-- 환경: Studio(저장 끔) / Studio(저장 켬) / 실서버
		local expected: { [string]: { boolean } } = {
			Info = { true, true, true },
			Test = { true, true, false },
			StudioOnly = { true, false, false },
		}
		for tier, row in expected do
			local tierName = tier :: any
			t.eq(AdminLogic.canRun(tierName, true, false), row[1], `{tier} studio`)
			t.eq(AdminLogic.canRun(tierName, true, true), row[2], `{tier} studio persist`)
			t.eq(AdminLogic.canRun(tierName, false, false), row[3], `{tier} live`)
			t.eq(AdminLogic.canRun(tierName, false, true), row[3], `{tier} live persist`)
		end
		t.eq(select(2, AdminLogic.canRun("Test", false, false)), "StudioOnly")
		t.eq(select(2, AdminLogic.canRun("StudioOnly", true, true)), "PersistOn")
		t.eq(AdminLogic.message("PersistOn"), "저장을 켠 Studio에서는 쓸 수 없어요")
	end)

	t.test("m5-11 AC3: parse coins/tokens accepts only integers in range", function()
		t.eq((AdminLogic.parse("coins", 1000) :: any).amount, 1000)
		t.eq((AdminLogic.parse("coins", -10000) :: any).amount, -10000)
		t.eq((AdminLogic.parse("coins", 10000) :: any).amount, 10000)
		for _, bad in { 10001, -10001, 1.5, "100", 0 / 0, math.huge, -math.huge, {} } :: { any } do
			local parsed, reason = AdminLogic.parse("coins", bad)
			t.eq(parsed, nil, tostring(bad))
			t.eq(reason, "BadCommandArgs", tostring(bad))
		end
		t.eq(AdminLogic.parse("coins", nil), nil)
		t.eq((AdminLogic.parse("tokens", 500) :: any).amount, 500)
		t.eq((AdminLogic.parse("tokens", -500) :: any).amount, -500)
		t.eq(AdminLogic.parse("tokens", 501), nil)
		t.eq(AdminLogic.parse("tokens", 80.5), nil)
		t.eq(AdminLogic.parse("tokens", "80"), nil)
	end)

	t.test("m5-11 AC3: parse plan takes a list of 3-4 strings only", function()
		t.eq((AdminLogic.parse("plan", { "a", "b", "c" }) :: any).ids, { "a", "b", "c" })
		t.eq((AdminLogic.parse("plan", { "a", "b", "c", "d" }) :: any).ids, { "a", "b", "c", "d" })
		for _, bad in
			{
				{ "a", "b" },
				{ "a", "b", "c", "d", "e" },
				{ "a", 2, "c" },
				{ "a", "", "c" },
				{ a = "x", b = "y", c = "z" },
				{ "a", "b", "c", extra = "d" },
				{ "a", "b", string.rep("x", 65) },
				"a,b,c",
			} :: { any }
		do
			t.eq(AdminLogic.parse("plan", bad), nil)
		end
		t.eq(AdminLogic.parse("plan", nil), nil)
	end)

	t.test("m5-11 AC3: parse fx takes slot + nil/off/FxCatalog id of that slot", function()
		local parsed = AdminLogic.parse("fx", { "Elimination", "cat-customer" }) :: any
		t.eq(parsed.slot, "Elimination")
		t.eq(parsed.fxId, "cat-customer")
		t.eq((AdminLogic.parse("fx", { "Victory", "fireworks" }) :: any).fxId, "fireworks")
		local off = AdminLogic.parse("fx", { "Victory", "off" }) :: any
		t.eq(off.slot, "Victory")
		t.eq(off.fxId, nil)
		t.eq((AdminLogic.parse("fx", { "Victory" }) :: any).fxId, nil)
		for _, bad in
			{
				{ "Victory", "cat-customer" }, -- 다른 칸 연출
				{ "Elimination", "nope" },
				{ "Spawn", "off" },
				{ "Elimination", 3 },
				"Elimination",
			} :: { any }
		do
			t.eq(AdminLogic.parse("fx", bad), nil)
		end
		t.eq(AdminLogic.parse("fx", nil), nil)
	end)

	t.test("m5-11: parse rejects unknown commands, no-arg commands ignore args", function()
		t.eq(select(2, AdminLogic.parse("kick", 1)), "UnknownCommand")
		t.eq((AdminLogic.parse("info", nil) :: any).command, "info")
		t.eq((AdminLogic.parse("start", { "x" }) :: any).command, "start")
		t.eq((AdminLogic.parse("resetprofile", nil) :: any).command, "resetprofile")
	end)

	t.test("m5-11 AC4: applyCoins/applyTokens never go below 0", function()
		t.eq(AdminLogic.applyCoins(100, -1000), 0)
		t.eq(AdminLogic.applyCoins(100, 1000), 1100)
		t.eq(AdminLogic.applyCoins(0, 0), 0)
		t.eq(AdminLogic.applyTokens(nil, 80), 80)
		t.eq(AdminLogic.applyTokens(5, -500), 0)
	end)

	t.test("m5-11: resolvePlan accepts any pool id (incl. inPool = false) and warns on non-Final last", function()
		local pool = Maps.allInfos()
		local inRandom: { [string]: boolean } = {}
		for _, info in Maps.infos() do
			inRandom[info.id] = true
		end
		local hidden: string? = nil
		for _, info in pool do
			if not inRandom[info.id] then
				hidden = info.id
			end
		end
		local plan, text = AdminLogic.resolvePlan({ "rotating-belt", "hot-plate", "skewer-showdown" }, pool)
		t.ok(plan ~= nil and #plan == 3)
		t.eq(text, "다음 판: rotating-belt → hot-plate → skewer-showdown")
		if hidden then
			local hiddenPlan = AdminLogic.resolvePlan({ hidden, "hot-plate", "skewer-showdown" }, pool)
			t.ok(hiddenPlan ~= nil, `forced-only map {hidden} accepted`)
		end
		local warnPlan, warnText = AdminLogic.resolvePlan({ "skewer-showdown", "hot-plate", "rotating-belt" }, pool)
		t.ok(warnPlan ~= nil)
		t.ok(string.find(warnText, "주의", 1, true) ~= nil, warnText)
		local bad, badText = AdminLogic.resolvePlan({ "rotating-belt", "nope", "skewer-showdown" }, pool)
		t.eq(bad, nil)
		t.ok(string.find(badText, "nope", 1, true) ~= nil)
	end)

	t.test("m5-11: equippedFx returns owned catalog fx of that slot only", function()
		local owned = { ["cat-customer"] = true }
		t.eq(AdminLogic.equippedFx({ Elimination = "cat-customer" }, owned, "Elimination"), "cat-customer")
		t.eq(AdminLogic.equippedFx({ Elimination = "cat-customer" }, {}, "Elimination"), nil)
		t.eq(AdminLogic.equippedFx({ Victory = "cat-customer" }, owned, "Victory"), nil)
		t.eq(AdminLogic.equippedFx(nil, owned, "Victory"), nil)
	end)

	t.test("m5-11: infoLine and describe", function()
		local line = AdminLogic.infoLine({
			role = "Single",
			jobId = "abcdef0123456789",
			rooms = 0,
			players = 1,
			coins = 50,
		})
		t.eq(line, "Single · 서버 abcdef01 · 방 0 · 플레이어 1 · 내 방 없음 · 코인 50")
		local withRoom = AdminLogic.infoLine({
			role = "Lobby",
			jobId = "",
			rooms = 2,
			players = 3,
			roomId = "4",
			roomState = "Waiting",
			eventName = "할로윈",
			tokenIcon = "🍬",
			tokens = 7,
		})
		t.eq(
			withRoom,
			"Lobby · 서버 - · 방 2 · 플레이어 3 · 내 방 4(Waiting) · 코인 ? · 할로윈 🍬7"
		)
		t.eq(AdminLogic.describe(AdminLogic.parse("coins", -5) :: any), "-5")
		t.eq(AdminLogic.describe(AdminLogic.parse("plan", { "a", "b", "c" }) :: any), "a,b,c")
		t.eq(AdminLogic.describe(AdminLogic.parse("fx", { "Victory" }) :: any), "Victory off")
		t.eq(AdminLogic.describe(AdminLogic.parse("info", nil) :: any), "-")
	end)

	---------------------------------------------------------------- m5-11 AdminService.AdminCommand 권한 (가짜 Roblox)
	local function commandEnv(studio: boolean): (any, { any })
		local env = loadEnv({ studio = studio })
		local ran: { any } = {}
		env.AdminService.setCommandRunner(function(player, parsed)
			table.insert(ran, { player = player, parsed = parsed })
			return true, "ran"
		end)
		return env, ran
	end
	local function command(env: any, player: any, name: any, args: any): (boolean, string?)
		env.clock += 1
		return env.remotes.AdminCommand.OnServerInvoke(player, name, args)
	end

	t.test("m5-11 AC13: non-admin is refused for every command (client IsAdmin ignored), warn once", function()
		local env, ran = commandEnv(false)
		local p = env.join(123, { IsAdmin = true })
		for _, name in { "info", "fx", "start", "plan", "coins", "tokens", "resetprofile" } do
			local ok, err = command(env, p, name, nil)
			t.eq(ok, false, name)
			t.eq(err, "권한이 없어요", name)
		end
		t.eq(#ran, 0)
		t.eq(#env.warnings, 1)
	end)

	t.test("m5-11 AC14: live admin runs Info commands only; Test/StudioOnly refused before running", function()
		local env, ran = commandEnv(false)
		local p = env.join(OWNER)
		t.eq(command(env, p, "info", nil), true)
		t.eq(command(env, p, "fx", { "Elimination", "cat-customer" }), true)
		local cases: { { name: string, args: any } } = {
			{ name = "start", args = nil },
			{ name = "plan", args = { "a", "b", "c" } },
			{ name = "coins", args = 1000 },
			{ name = "tokens", args = 80 },
			{ name = "resetprofile", args = nil },
		}
		for _, case in cases do
			local ok, err = command(env, p, case.name, case.args)
			t.eq(ok, false, case.name)
			t.eq(err, "Studio에서만 쓸 수 있는 명령이에요", case.name)
		end
		t.eq(#ran, 2)
		t.eq(ran[1].parsed.command, "info")
		t.eq(ran[2].parsed.fxId, "cat-customer")
	end)

	t.test("m5-11: Studio admin runs every command; bad args and unknown command never run", function()
		local env, ran = commandEnv(true)
		local p = env.join(-1)
		local cases: { { name: string, args: any } } = {
			{ name = "info", args = nil },
			{ name = "start", args = nil },
			{ name = "plan", args = { "a", "b", "c" } },
			{ name = "coins", args = 100 },
			{ name = "tokens", args = 10 },
			{ name = "fx", args = { "Victory", "off" } },
			{ name = "resetprofile", args = nil },
		}
		for _, case in cases do
			t.eq(command(env, p, case.name, case.args), true, case.name)
		end
		t.eq(#ran, 7)
		local ok, err = command(env, p, "coins", 99999)
		t.eq(ok, false)
		t.eq(err, "명령 값이 잘못됐어요")
		ok, err = command(env, p, "kick", nil)
		t.eq(ok, false)
		t.eq(err, "모르는 명령이에요")
		_, err = command(env, p, 42, nil)
		t.eq(err, "모르는 명령이에요")
		t.eq(#ran, 7)
		-- 결과 문구는 실행기가 돌려준 그대로
		t.eq(select(2, command(env, p, "info", nil)), "ran")
	end)

	t.test("m5-11: AdminCommand is rate-limited like the preview", function()
		local env, ran = commandEnv(true)
		local p = env.join(-1)
		command(env, p, "info", nil)
		local ok, err = env.remotes.AdminCommand.OnServerInvoke(p, "info", nil) -- 같은 시각
		t.eq(ok, false)
		t.eq(err, "잠시 뒤에 다시 해 주세요")
		t.eq(#ran, 1)
	end)

	t.test("source: AdminService checks admin, parse and canRun before runCommand", function()
		local src = fs.readFile("src/server/AdminService.luau")
		local body = string.match(src, "local function onCommand.-\nend") :: string
		t.ok(body ~= nil)
		local adminAt = string.find(body, "if not admins[userId] then", 1, true)
		local parseAt = string.find(body, "AdminLogic.parse(name, args)", 1, true)
		local canRunAt =
			string.find(body, "AdminLogic.canRun(tier, isStudio(), Config.DEBUG.persistDataInStudio)", 1, true)
		local runAt = string.find(body, "local ok, result = runCommand(player, parsed)", 1, true)
		t.ok(adminAt and parseAt and canRunAt and runAt)
		t.ok(adminAt < parseAt and parseAt < canRunAt and canRunAt < runAt)
		t.ok(string.find(src, "require(script.Parent.AdminCommands)", 1, true) ~= nil)
	end)

	---------------------------------------------------------------- m5-11 AdminCommands 실행 (가짜 서버 모듈)
	t.test("m5-11 AC10: coins adds to my profile, floors at 0, requests a save", function()
		local env = loadCommands()
		local ok, text = env.run("coins", 1000)
		t.eq(ok, true)
		t.eq(env.profile.coins, 1100)
		t.eq(text, "코인 +1000 → 1100")
		ok = env.run("coins", -10000)
		t.eq(ok, true)
		t.eq(env.profile.coins, 0)
		t.eq(env.saves, 2)
		t.eq(env.profile.wins, 3) -- 다른 칸은 그대로
		env.profile = nil
		local failed, reason = env.run("coins", 1)
		t.eq(failed, false)
		t.eq(reason, "프로필을 아직 불러오지 못했어요")
	end)

	t.test("m5-11 AC10: tokens need a running event and go to that event id", function()
		local env = loadCommands()
		local ok, err = env.run("tokens", 80)
		t.eq(ok, false)
		t.eq(err, "진행 중인 이벤트가 없어요")
		local live = loadCommands({ now = HALLOWEEN_NOW })
		t.eq((Seasons.current(HALLOWEEN_NOW) :: any).id, "halloween-2026")
		ok = live.run("tokens", 80)
		t.eq(ok, true)
		t.eq(live.profile.eventTokens["halloween-2026"], 80)
		live.run("tokens", -500)
		t.eq(live.profile.eventTokens["halloween-2026"], 0)
	end)

	t.test("m5-11 AC11: fx preview only sets the attribute, off restores the equipped fx, locked refuses", function()
		local env = loadCommands()
		local ok = env.run("fx", { "Victory", "fireworks" })
		t.eq(ok, true)
		t.eq(env.attributes.VictoryFx, "fireworks")
		t.eq(env.profile.ownedFx.fireworks, nil) -- 소유·장착은 그대로
		t.eq(env.profile.equippedFx.Victory, nil)
		env.run("fx", { "Victory", "off" })
		t.eq(env.attributes.VictoryFx, nil)
		env.run("fx", { "Elimination", "off" })
		t.eq(env.attributes.EliminationFx, "cat-customer") -- 프로필 장착값으로
		env.locked = true
		local refused, err = env.run("fx", { "Victory", "fireworks" })
		t.eq(refused, false)
		t.eq(err, "라운드 중에는 바꿀 수 없어요")
		t.eq(env.attributes.VictoryFx, nil)
	end)

	t.test("m5-11 AC8: start force-starts my room; not in a room is refused", function()
		local env = loadCommands()
		t.eq(env.run("start", nil), true)
		t.eq(env.forceStarts, { "7" })
		env.roomId = nil
		local ok, err = env.run("start", nil)
		t.eq(ok, false)
		t.eq(err, "방에 들어가 있지 않아요")
	end)

	t.test("m5-11 AC9: plan sets my room's next plan in single-place mode only", function()
		local env = loadCommands()
		local ok, text = env.run("plan", { "rotating-belt", "hot-plate", "skewer-showdown" })
		t.eq(ok, true)
		t.eq(text, "다음 판: rotating-belt → hot-plate → skewer-showdown")
		local plan = env.nextPlans["7"]
		t.eq(#plan, 3)
		t.eq(plan[3].kind, "Final")
		local bad, badText = env.run("plan", { "rotating-belt", "nope", "skewer-showdown" })
		t.eq(bad, false)
		t.ok(string.find(badText, "nope", 1, true) ~= nil)
		local lobby = loadCommands({ role = "Lobby" })
		local refused, err = lobby.run("plan", { "rotating-belt", "hot-plate", "skewer-showdown" })
		t.eq(refused, false)
		t.eq(err, "한 플레이스 모드에서만 돼요")
		t.eq(lobby.nextPlans["7"], nil)
	end)

	t.test("m5-11 AC12: resetprofile replaces my memory profile; persisted profile is refused", function()
		local env = loadCommands()
		env.attributes.EliminationFx = "cat-customer"
		local ok = env.run("resetprofile", nil)
		t.eq(ok, true)
		t.eq(env.profile.coins, 0)
		t.eq(env.profile.wins, 0)
		t.eq(env.profile.equippedSkin, "tamago")
		t.eq(env.profile.ownedSkins, { tamago = true })
		t.eq(env.profile.redeemedCodes, {})
		t.eq(env.profile.equippedFx, {})
		t.eq(env.attributes.EliminationFx, nil)
		t.eq(env.previews, { "off" }) -- 스킨 미리보기 끄고 다시 입혀요
		local saved = loadCommands()
		saved.persist = true
		local refused, err = saved.run("resetprofile", nil)
		t.eq(refused, false)
		t.eq(err, "저장을 켠 Studio에서는 쓸 수 없어요")
		t.eq(saved.profile.coins, 100)
	end)

	t.test("m5-11: info shows role, job, rooms, players, my room, coins and event tokens", function()
		local env = loadCommands({ now = HALLOWEEN_NOW })
		env.profile.eventTokens["halloween-2026"] = 12
		local ok, text = env.run("info", nil)
		t.eq(ok, true)
		t.eq(
			text,
			"Single · 서버 abcdef01 · 방 1 · 플레이어 1 · 내 방 7(Waiting) · 코인 100 · 할로윈 초밥 축제 🍬12"
		)
	end)

	t.test("source: MatchService uses the admin plan once, before DEBUG.forceMapPlan", function()
		local src = fs.readFile("src/server/MatchService.luau")
		t.ok(string.find(src, "nextPlans[roomId] = nil", 1, true) ~= nil, "consumed once")
		t.ok(string.find(src, "local forced = adminPlan or forcedPlan(roomId)", 1, true) ~= nil, "admin plan first")
		local room = fs.readFile("src/server/RoomService.luau")
		local body = string.match(room, "function RoomService.forceStart.-\nend") :: string
		t.ok(body ~= nil)
		t.ok(string.find(body, "beginMatch(room)", 1, true) ~= nil, "same start path")
		t.eq(string.find(body, "minPlayersToStart", 1, true), nil, "no minimum player check")
		t.ok(string.find(body, "autoStartAt", 1, true) ~= nil, "refuses during auto-start countdown")
	end)
end
