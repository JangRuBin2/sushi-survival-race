--!strict
-- m5-02 QA: 관리자 스킨 미리보기의 보안·경제 오염 경계값.
-- tests/admin-logic.spec.luau(개발)의 가짜 Roblox 환경을 줄여 다시 만들고, 개발 테스트가 다루지 않은 경우를 더해요:
--   비관리자 스팸(warn 한 번·MemoryStore 0회), 남의 키, 코인 해금·장착 실패·잠금 중 지급과 미리보기,
--   소스 검사(AdminConfig가 서버 전용, 서버가 IsAdmin·AdminPreview 속성·이름을 권한에 안 씀).

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

---------------------------------------------------------------- 가짜 Roblox 환경 (admin-logic.spec.luau와 같은 모양)
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

local function loadEnv(options: { [string]: any }?): any
	local opts = options or {}
	local env: any = {}
	env.clock = 100
	env.studio = opts.studio == true
	env.adminConfig = opts.adminConfig
		or { UserIds = { OWNER }, IncludeOwner = true, StudioAllAdmins = true, LiveEnabled = true }
	env.remotes = {}
	env.profiles = {}
	env.writes = {}
	env.refreshes = 0
	env.placed = {}
	env.store = {}
	env.storeReads = {}
	env.storeWrites = {}
	env.warnings = {}
	env.onStoreGet = nil

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
	local resolver: any = nil
	local serverModules: { [string]: any } = {
		DataService = {
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
		},
		AppearanceService = {
			setResolver = function(fn)
				resolver = fn
			end,
			refresh = function()
				env.refreshes += 1
			end,
		},
		MatchEvents = { onResult = function() end },
		RoundService = {
			placedRoomOf = function(player)
				return if env.placed[player] or env.lockAll then "room-1" else nil
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
				CreatorType = opts.creatorType or "User",
				CreatorId = opts.creatorId or 1,
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
			table.insert(env.storeReads, key)
			local hook = env.onStoreGet
			if hook then
				hook(key)
			end
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

	function env.call(name: string, player: any, arg: any)
		env.clock += 1
		return env.remotes[name].OnServerInvoke(player, arg)
	end
	function env.invoke(player, skinId)
		return env.call("AdminPreviewSkin", player, skinId)
	end
	function env.join(userId: number, profile: any?): any
		local attributes = {}
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			DisplayName = "Admin",
			Parent = Players,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
		}
		env.profiles[userId] = profile
			or { coins = 50, ownedSkins = { tamago = true, salmon = true }, equippedSkin = "salmon" }
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

-- 줄 단위로 주석(--)을 떼고 소스를 돌려줘요 (주석 속 설명 문구는 검사하지 않음)
local function codeOf(path: string): string
	local lines = {}
	for line in string.gmatch(fs.readFile(path), "[^\n]*") do
		local cut = string.find(line, "--", 1, true)
		table.insert(lines, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(lines, "\n")
end

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

return function(t: Test.Test)
	---------------------------------------------------------------- 순수 경계값
	t.test("QA isAdmin: listed user on a group-owned game is still admin (list does not depend on owner)", function()
		t.eq(AdminLogic.isAdmin(input({ creatorType = "Group", creatorId = 999 })), true)
	end)

	t.test("QA isAdmin: group id equal to a user id never makes that user owner-admin", function()
		t.eq(
			AdminLogic.isAdmin(
				input({ userId = 42, allowList = {}, includeOwner = true, creatorType = "Group", creatorId = 42 })
			),
			false
		)
	end)

	t.test("QA isAdmin: unpublished place (creatorId 0) gives no owner-admin", function()
		t.eq(AdminLogic.isAdmin(input({ userId = 0, allowList = {}, includeOwner = true, creatorId = 0 })), false)
	end)

	t.test("QA isAdmin: Studio + studioAllAdmins false still honours the list even if liveEnabled false", function()
		t.eq(
			AdminLogic.isAdmin(input({ isStudio = true, studioAllAdmins = false, liveEnabled = false, userId = OWNER })),
			true
		)
		t.eq(
			AdminLogic.isAdmin(input({ isStudio = true, studioAllAdmins = false, liveEnabled = false, userId = -2 })),
			false
		)
	end)

	t.test("QA checkPreview: booleans, whitespace and case variants are rejected", function()
		t.eq((AdminLogic.checkPreview(true, true, known, false)), false)
		t.eq((AdminLogic.checkPreview(true, false, known, false)), false)
		t.eq((AdminLogic.checkPreview(true, " uni", known, false)), false)
		t.eq((AdminLogic.checkPreview(true, "UNI", known, false)), false)
		t.eq((AdminLogic.checkPreview(true, string.rep("a", 10000), known, false)), false)
	end)

	t.test("QA decodeEntry: non-string skinId and tampered shapes decode to nil", function()
		t.eq(AdminLogic.decodeEntry({ skinId = 5 }, known), nil)
		t.eq(AdminLogic.decodeEntry({ skinId = true }, known), nil)
		t.eq(AdminLogic.decodeEntry({ skinId = { "uni" } }, known), nil)
		t.eq(AdminLogic.decodeEntry({}, known), nil)
	end)

	t.test("QA storeKey: different users never share a key", function()
		t.ok(AdminLogic.storeKey(1) ~= AdminLogic.storeKey(11), "1 vs 11")
		t.ok(AdminLogic.storeKey(OWNER) ~= AdminLogic.storeKey(OWNER + 1), "neighbours")
	end)

	---------------------------------------------------------------- 서버 (가짜 Roblox)
	t.test("QA spam: non-admin 200 requests → 1 warn, no store read/write, no re-dress, no profile write", function()
		local env = loadEnv()
		local p = env.join(123)
		local before = snapshot(env.profiles[123])
		local refreshes = env.refreshes
		for i = 1, 200 do
			local ok, err = env.remotes.AdminPreviewSkin.OnServerInvoke(p, if i % 2 == 0 then "uni" else i)
			t.eq(ok, false)
			t.eq(err, "권한이 없어요")
		end
		t.eq(#env.warnings, 1)
		t.eq(#env.storeReads, 0)
		t.eq(#env.storeWrites, 0)
		t.eq(env.refreshes, refreshes)
		t.eq(#env.writes, 0)
		t.eq(snapshot(env.profiles[123]), before)
		t.eq(p:GetAttribute("AdminPreview"), nil)
	end)

	t.test("QA spam: a non-admin's planted key is never read, and an admin's key never reaches others", function()
		local env = loadEnv()
		env.store["u_123"] = { skinId = "golden-otoro", at = 1 }
		env.store["u_11402290839"] = { skinId = "dragon-roll", at = 1 }
		local stranger = env.join(123)
		t.eq(env.resolve(stranger), "salmon")
		t.eq(table.find(env.storeReads, "u_123"), nil)
		t.eq(table.find(env.storeReads, "u_11402290839"), nil)
		local admin = env.join(OWNER)
		t.eq(env.resolve(admin), "dragon-roll")
		t.eq(env.resolve(stranger), "salmon")
		t.eq(#env.storeReads, 1)
		t.eq(env.storeReads[1], "u_11402290839")
	end)

	t.test("QA store: admin preview only writes the admin's own key", function()
		local env = loadEnv({ adminConfig = { UserIds = { 7, 8 }, IncludeOwner = false, LiveEnabled = true } })
		local a = env.join(7)
		local b = env.join(8)
		env.invoke(a, "uni")
		env.invoke(b, nil)
		for _, w in env.storeWrites do
			t.ok(w.key == "u_7" or w.key == "u_8", w.key)
		end
		t.eq(env.store["u_7"].skinId, "uni")
		t.eq(env.resolve(b), "salmon")
		-- b는 미리보기를 켠 적이 없어 끄기도 값이 같아 쓰지 않아요
		t.eq(env.store["u_8"], nil)
	end)

	t.test("QA store: MemoryStore failure only warns, preview still works", function()
		local env = loadEnv()
		env.AdminService.setStore({
			get = function()
				error("MemoryStore down")
			end,
			set = function()
				error("MemoryStore down")
			end,
		})
		local p = env.join(OWNER)
		t.eq(env.invoke(p, "uni"), true)
		t.eq(env.resolve(p), "uni")
		t.ok(#env.warnings >= 2, "read + write warned")
	end)

	t.test("QA economy: coin unlock of the previewed skin charges normally and clears preview", function()
		local env = loadEnv()
		local p = env.join(OWNER, { coins = 1000, ownedSkins = { tamago = true }, equippedSkin = "tamago" })
		env.invoke(p, "tuna")
		t.eq(env.resolve(p), "tuna")
		t.eq(env.profiles[OWNER].ownedSkins.tuna, nil) -- 미리보기는 보유가 아니에요
		local ok, err = env.call("BuyWithCoins", p, "tuna")
		t.eq(ok, true, err)
		t.eq(env.profiles[OWNER].coins, 1000 - Skins.get("tuna").coins)
		t.eq(env.profiles[OWNER].ownedSkins.tuna, true)
		t.eq(env.ShopService.getPreview(p), nil)
		t.eq(env.resolve(p), "tuna")
	end)

	t.test("QA economy: previewing a skin does not let EquipSkin wear it (still not owned)", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.invoke(p, "golden-otoro")
		local writes = #env.storeWrites
		local ok = env.call("EquipSkin", p, "golden-otoro")
		t.eq(ok, false)
		t.eq(env.profiles[OWNER].equippedSkin, "salmon")
		t.eq(env.ShopService.getPreview(p), "golden-otoro") -- 실패한 장착은 미리보기를 끄지 않아요
		t.eq(#env.storeWrites, writes)
		t.eq(#env.writes, 0)
	end)

	t.test("QA economy: robux grant during a locked phase owns the skin but keeps the preview", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.invoke(p, "uni")
		env.placed[p] = true
		t.eq(env.ShopService.grantSkin(p, "dragon-roll", true), true)
		t.eq(env.profiles[OWNER].ownedSkins["dragon-roll"], true)
		t.eq(env.profiles[OWNER].equippedSkin, "salmon") -- 잠금 중이라 장착 안 함 (m4-14 규칙)
		t.eq(env.ShopService.getPreview(p), "uni")
		-- equip 없이 지급해도 미리보기는 그대로
		env.placed[p] = nil
		env.ShopService.grantSkin(p, "eel", false)
		t.eq(env.ShopService.getPreview(p), "uni")
	end)

	t.test("QA leave: same-server rejoin in Studio starts without preview (slot cleared)", function()
		local env = loadEnv({ studio = true })
		env.AdminService.setStore(nil)
		local p = env.join(-1)
		env.invoke(p, "uni")
		env.leave(p)
		t.eq(env.ShopService.getPreview(p), nil)
		local again = env.join(-1)
		t.eq(env.resolve(again), "salmon")
	end)

	t.test("QA admin table: removed from the admin table on leave; old Player object loses access", function()
		local env = loadEnv()
		local p = env.join(OWNER)
		env.leave(p)
		t.eq(env.AdminService.isAdmin(p), false)
		t.eq(select(2, env.invoke(p, "uni")), "권한이 없어요")
	end)

	t.test("QA restore while locked: slot is set, no re-dress, no store write", function()
		local env = loadEnv()
		env.store["u_11402290839"] = { skinId = "uni", at = 1 }
		local refreshesAtRead = -1
		env.onStoreGet = function()
			env.lockAll = true -- 읽는 동안 라운드에 배치된 것처럼
			refreshesAtRead = env.refreshes
		end
		local p = env.join(OWNER)
		t.eq(env.ShopService.getPreview(p), "uni")
		t.eq(env.refreshes, refreshesAtRead) -- 잠금 중에는 다시 입히지 않아요 (다음 스폰 때)
		t.eq(#env.storeWrites, 0)
	end)

	---------------------------------------------------------------- 소스 검사 (복제·권한 경로)
	t.test("QA source: src/server maps to ServerScriptService, AdminConfig only required by server", function()
		local project = fs.readFile("default.project.json")
		t.ok(
			string.find(project, '"ServerScriptService"%s*:%s*{%s*"Server"%s*:%s*{%s*"%$path"%s*:%s*"src/server"')
				~= nil,
			"tree"
		)
		t.ok(fs.isFile("src/server/AdminConfig.luau"), "AdminConfig in src/server")
		local files = {}
		luauFiles("src/client", files)
		luauFiles("src/shared", files)
		for _, path in files do
			t.eq(string.find(codeOf(path), "AdminConfig", 1, true), nil, path)
			t.eq(string.find(codeOf(path), "11402290839", 1, true), nil, path)
		end
	end)

	t.test("QA source: server never reads IsAdmin/AdminPreview attributes or names for permission", function()
		local files = {}
		luauFiles("src/server", files)
		for _, path in files do
			local code = codeOf(path)
			t.eq(string.find(code, "GetAttribute(Attributes.IsAdmin", 1, true), nil, path)
			t.eq(string.find(code, "GetAttribute(Attributes.AdminPreview", 1, true), nil, path)
			t.eq(string.find(code, 'GetAttribute("IsAdmin"', 1, true), nil, path)
			t.eq(string.find(code, 'GetAttribute("AdminPreview"', 1, true), nil, path)
		end
		local admin = codeOf("src/server/AdminService.luau")
		t.eq(string.find(admin, "DisplayName", 1, true), nil, "DisplayName")
		-- 권한 계산 입력은 UserId·서버 game 값·AdminConfig뿐
		local compute = string.match(admin, "local function computeAdmin.-\nend") :: string
		t.ok(compute ~= nil, "computeAdmin found")
		t.eq(string.find(compute, "player.Name", 1, true), nil, "no Name")
		t.ok(string.find(compute, "player.UserId", 1, true) ~= nil, "uses UserId")
		t.ok(string.find(compute, "game.CreatorId", 1, true) ~= nil, "uses CreatorId")
	end)

	t.test("QA source: ShopService preview path never touches DataService", function()
		local code = codeOf("src/server/ShopService.luau")
		for _, name in { "assignPreview", "clearPreview" } do
			local body = string.match(code, `local function {name}.-\nend`) :: string
			t.ok(body ~= nil, name)
			t.eq(string.find(body, "DataService", 1, true), nil, name)
		end
		for _, name in { "setPreview", "getPreview", "setPreviewListener" } do
			local body = string.match(code, `function ShopService.{name}.-\nend`) :: string
			t.ok(body ~= nil, name)
			t.eq(string.find(body, "DataService", 1, true), nil, name)
		end
	end)

	t.test("QA source: client AdminController builds UI only on IsAdmin and sends only skin ids", function()
		local code = codeOf("src/client/ui/AdminController.luau")
		t.eq(select(2, string.gsub(code, "InvokeServer", "")), 1)
		t.ok(string.find(code, "GetAttribute(Attributes.IsAdmin) == true", 1, true) ~= nil, "gated on IsAdmin")
	end)
end
