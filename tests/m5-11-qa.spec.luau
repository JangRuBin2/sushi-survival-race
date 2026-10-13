--!strict
-- m5-11 QA: 관리자 명령을 진짜 AdminService + ShopService + AdminCommands로 끝까지 돌려요 (가짜 Roblox).
-- 보안 초점: 관리자는 서버 표로만, 실서버는 Info만(설정·persist와 무관), 요청 간격, 인자 검사,
-- 명령은 부른 사람 본인에게만, 거절된 명령은 프로필·방·매치에 아무것도 안 함, 로그 형식, 미리보기 경로의 경제 무기록.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local Config = RobloxRequire.require(Shared.Config)

local OWNER = 11402290839
local HALLOWEEN_NOW = 1792108800 + 3600

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

type Options = { studio: boolean?, adminConfig: { [string]: any }?, now: number?, role: string? }

local function loadEnv(options: Options?): any
	local opts = options or {}
	local env: any = {
		clock = 100,
		studio = opts.studio == true,
		now = opts.now or 1700000000,
		role = opts.role or "Single",
		remotes = {},
		profiles = {},
		writes = {},
		prints = {},
		warnings = {},
		forceStarts = {},
		nextPlans = {},
		commandsLoaded = 0,
		roomOf = {},
		placed = {},
	}
	local adminConfig = opts.adminConfig
		or { UserIds = { OWNER }, IncludeOwner = false, StudioAllAdmins = true, LiveEnabled = true }

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

	local serverModules: { [string]: any } = {}
	serverModules.DataService = {
		get = function(player)
			return env.profiles[player.UserId]
		end,
		update = function(player, fn)
			table.insert(env.writes, `update:{player.UserId}`)
			local profile = env.profiles[player.UserId]
			if profile == nil then
				return false
			end
			fn(profile)
			return true
		end,
		saveNow = function(player)
			table.insert(env.writes, `saveNow:{player.UserId}`)
			return false
		end,
		canPersist = function()
			return false
		end,
		onLoaded = function() end,
	}
	serverModules.AppearanceService = {
		setResolver = function() end,
		refresh = function() end,
	}
	serverModules.MatchEvents = { onResult = function() end }
	serverModules.RoundService = {
		placedRoomOf = function(player)
			return if env.placed[player] then "room-1" else nil
		end,
	}
	serverModules.AdminConfig = adminConfig
	serverModules.PlaceService = {
		role = function()
			return env.role
		end,
	}
	serverModules.RoomService = {
		getRoomIdOf = function(player)
			return env.roomOf[player.UserId]
		end,
		getRoom = function(roomId)
			return { id = roomId, state = "Waiting" }
		end,
		listRooms = function()
			return {}
		end,
		forceStart = function(roomId)
			table.insert(env.forceStarts, roomId)
			return true, nil
		end,
	}
	serverModules.MatchService = {
		setNextPlan = function(roomId, plan)
			env.nextPlans[roomId] = plan
		end,
	}

	local function environment(): { [string]: any }
		return {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
				CreatorType = "User",
				CreatorId = 1,
				JobId = "0123456789abcdef",
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
				if target.__server == "AdminCommands" then
					env.commandsLoaded += 1
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
					return env.now
				end,
			},
			warn = function(...)
				table.insert(env.warnings, table.concat({ ... }, " "))
			end,
			print = function(...)
				table.insert(env.prints, table.concat({ ... }, " "))
			end,
		}
	end

	local function load(path: string): any
		return luau.load(fs.readFile(path), { debugName = path, environment = environment() })()
	end
	serverModules.ShopService = load("src/server/ShopService.luau")
	serverModules.AdminCommands = load("src/server/AdminCommands.luau")
	env.AdminService = load("src/server/AdminService.luau")
	env.AdminService.setStore({
		get = function()
			return nil
		end,
		set = function() end,
	})
	serverModules.ShopService.init()
	env.AdminService.init()
	serverModules.ShopService.start()
	env.AdminService.start()

	function env.join(userId: number, attrs: { [string]: any }?): any
		local attributes = table.clone(attrs or {})
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			DisplayName = `P{userId}`,
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
			wins = 2,
			ownedSkins = { tamago = true, salmon = true },
			equippedSkin = "salmon",
			eventTokens = {},
			ownedFx = {},
			equippedFx = {},
			redeemedCodes = {},
		}
		env.roomOf[userId] = `r{userId}`
		table.insert(list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function env.command(player: any, name: any, args: any): (boolean, string?)
		env.clock += 1
		return env.remotes.AdminCommand.OnServerInvoke(player, name, args)
	end
	return env
end

local ALL_COMMANDS: { { name: string, args: any } } = {
	{ name = "info", args = nil },
	{ name = "fx", args = { "Victory", "fireworks" } },
	{ name = "start", args = nil },
	{ name = "plan", args = { "rotating-belt", "hot-plate", "skewer-showdown" } },
	{ name = "coins", args = 1000 },
	{ name = "tokens", args = 80 },
	{ name = "resetprofile", args = nil },
}

local function untouched(env: any)
	return #env.writes == 0 and #env.forceStarts == 0 and next(env.nextPlans) == nil
end

return function(t: Test.Test)
	---------------------------------------------------------------- 권한 (서버 표만)
	t.test(
		"QA: non-admin on live with client IsAdmin/AdminPreview attributes: every command refused, nothing loaded or written",
		function()
			local env = loadEnv({ studio = false })
			local p = env.join(777, { IsAdmin = true, AdminPreview = "salmon" })
			for _, case in ALL_COMMANDS do
				local ok, err = env.command(p, case.name, case.args)
				t.eq(ok, false, case.name)
				t.eq(err, "권한이 없어요", case.name)
			end
			for _, junk in { 1, {}, "kick", true } :: { any } do
				t.eq(env.command(p, junk, nil), false)
			end
			t.ok(untouched(env))
			t.eq(env.commandsLoaded, 0, "AdminCommands never required for a non-admin")
			t.eq(#env.warnings, 1, "warn once")
			t.eq(p:GetAttribute("VictoryFx"), nil)
		end
	)

	t.test("QA: Studio with StudioAllAdmins = false: unlisted id refused even if IsAdmin set by client", function()
		local env = loadEnv({
			studio = true,
			adminConfig = { UserIds = { OWNER }, IncludeOwner = false, StudioAllAdmins = false, LiveEnabled = true },
		})
		local p = env.join(-2, { IsAdmin = true })
		t.eq(select(2, env.command(p, "coins", 1000)), "권한이 없어요")
		t.ok(untouched(env))
	end)

	t.test("QA: LiveEnabled = false: listed owner on live gets nothing, even info", function()
		local env = loadEnv({
			studio = false,
			adminConfig = { UserIds = { OWNER }, IncludeOwner = false, StudioAllAdmins = true, LiveEnabled = false },
		})
		local p = env.join(OWNER)
		t.eq(select(2, env.command(p, "info", nil)), "권한이 없어요")
		t.eq(env.commandsLoaded, 0)
	end)

	---------------------------------------------------------------- 등급: 실서버
	t.test(
		"QA: live admin: economy/judging commands never touch profile, room or plan (even with persistDataInStudio = true)",
		function()
			local saved = Config.DEBUG.persistDataInStudio
			for _, persist in { false, true } do
				Config.DEBUG.persistDataInStudio = persist
				local env = loadEnv({ studio = false, now = HALLOWEEN_NOW })
				local p = env.join(OWNER)
				for _, case in ALL_COMMANDS do
					if AdminLogic.commandTier(case.name) ~= "Info" then
						local ok, err = env.command(p, case.name, case.args)
						t.eq(ok, false, case.name)
						t.eq(err, "Studio에서만 쓸 수 있는 명령이에요", case.name)
					end
				end
				t.ok(untouched(env), `persist={persist}`)
				t.eq(env.profiles[OWNER].coins, 50)
				t.eq(env.profiles[OWNER].eventTokens["halloween-2026"], nil)
				-- Info 명령은 돼요. 프로필에 쓰지 않아요
				t.eq(env.command(p, "info", nil), true)
				t.eq(env.command(p, "fx", { "Victory", "fireworks" }), true)
				t.eq(p:GetAttribute("VictoryFx"), "fireworks")
				t.eq(#env.writes, 0, "fx/info do not write the profile")
				t.eq(env.profiles[OWNER].equippedFx.Victory, nil)
				t.eq(env.profiles[OWNER].ownedFx.fireworks, nil)
			end
			Config.DEBUG.persistDataInStudio = saved
		end
	)

	t.test("QA: live admin bad args for a Test command are refused and never run", function()
		local env = loadEnv({ studio = false })
		local p = env.join(OWNER)
		local ok = env.command(p, "coins", 99999)
		t.eq(ok, false)
		t.eq(env.command(p, "coins", "1000"), false)
		t.ok(untouched(env))
	end)

	---------------------------------------------------------------- 등급: Studio
	t.test("QA: Studio admin: coins/tokens/start/plan affect only the caller", function()
		local env = loadEnv({ studio = true, now = HALLOWEEN_NOW })
		local a = env.join(-1)
		local b = env.join(-2)
		t.eq(env.command(a, "coins", 1000), true)
		t.eq(env.command(a, "tokens", 80), true)
		t.eq(env.command(a, "start", nil), true)
		t.eq(env.command(a, "plan", { "rotating-belt", "hot-plate", "skewer-showdown" }), true)
		t.eq(env.command(a, "fx", { "Elimination", "cat-customer" }), true)
		t.eq(env.profiles[-1].coins, 1050)
		t.eq(env.profiles[-1].eventTokens["halloween-2026"], 80)
		t.eq(env.profiles[-2].coins, 50)
		t.eq(env.profiles[-2].eventTokens["halloween-2026"], nil)
		t.eq(b:GetAttribute("EliminationFx"), nil)
		t.eq(env.forceStarts, { "r-1" })
		t.ok(env.nextPlans["r-1"] ~= nil and env.nextPlans["r-2"] == nil)
		for _, w in env.writes do
			t.ok(string.find(w, ":-1", 1, true) ~= nil, w)
		end
	end)

	t.test("QA: Studio + persistDataInStudio: resetprofile refused before running, profile intact", function()
		local saved = Config.DEBUG.persistDataInStudio
		Config.DEBUG.persistDataInStudio = true
		local env = loadEnv({ studio = true })
		local p = env.join(-1)
		local ok, err = env.command(p, "resetprofile", nil)
		Config.DEBUG.persistDataInStudio = saved
		t.eq(ok, false)
		t.eq(err, "저장을 켠 Studio에서는 쓸 수 없어요")
		t.eq(env.profiles[-1].coins, 50)
		t.eq(#env.writes, 0)
	end)

	t.test("QA: Studio resetprofile while running (locked) is refused", function()
		local env = loadEnv({ studio = true })
		local p = env.join(-1)
		env.placed[p] = true
		local ok, err = env.command(p, "resetprofile", nil)
		t.eq(ok, false)
		t.eq(err, "라운드 중에는 바꿀 수 없어요")
		t.eq(env.profiles[-1].wins, 2)
		t.eq(#env.writes, 0)
	end)

	---------------------------------------------------------------- 요청 간격
	t.test("QA: rate limit: second command inside cooldown refused, shared with skin preview", function()
		local env = loadEnv({ studio = true })
		local p = env.join(-1)
		t.eq(env.command(p, "coins", 10), true)
		local ok, err = env.remotes.AdminCommand.OnServerInvoke(p, "coins", 10) -- 같은 시각
		t.eq(ok, false)
		t.eq(err, "잠시 뒤에 다시 해 주세요")
		t.eq(env.profiles[-1].coins, 60)
		env.clock += 1
		t.eq(env.remotes.AdminPreviewSkin.OnServerInvoke(p, "salmon"), true)
		t.eq(select(2, env.remotes.AdminCommand.OnServerInvoke(p, "coins", 10)), "잠시 뒤에 다시 해 주세요")
		t.eq(env.profiles[-1].coins, 60)
		env.clock += Config.Shop.RequestCooldown + 0.01
		t.eq(env.remotes.AdminCommand.OnServerInvoke(p, "coins", 10), true)
	end)

	---------------------------------------------------------------- 인자 모양 (리모트로 올 수 있는 이상한 값)
	t.test("QA: parse edge cases from a hostile client", function()
		local sparse = { "rotating-belt", "hot-plate", "skewer-showdown", "x" } :: { any }
		sparse[2] = nil -- {1, 3, 4}: 3개지만 순서 목록이 아님
		t.eq(AdminLogic.parse("plan", sparse), nil)
		t.eq(AdminLogic.parse("plan", { { "a" }, "b", "c" }), nil)
		local big = {}
		for i = 1, 1000 do
			big[i] = "rotating-belt"
		end
		t.eq(AdminLogic.parse("plan", big), nil)
		t.eq(AdminLogic.parse("fx", { "Elimination", "" }), nil)
		t.eq(AdminLogic.parse("fx", { "elimination", "cat-customer" }), nil)
		t.eq(AdminLogic.parse("fx", { "Elimination", "cat-customer " }), nil)
		t.eq(AdminLogic.parse("fx", {}), nil)
		t.eq(AdminLogic.parse("coins", true), nil)
		t.eq((AdminLogic.parse("coins", -0) :: any).amount, 0)
		t.eq(AdminLogic.parse("tokens", 1e300), nil)
		t.eq(select(2, AdminLogic.parse("coins ", 1)), "UnknownCommand")
		t.eq(select(2, AdminLogic.parse(" info", nil)), "UnknownCommand")
		-- Parsed에는 대상 플레이어 칸이 없어요 (본인 전용)
		local parsed = AdminLogic.parse("coins", 5) :: any
		t.eq(parsed.target, nil)
		t.eq(parsed.userId, nil)
	end)

	t.test("QA: unknown map id or wrong count through the remote: nothing scheduled", function()
		local env = loadEnv({ studio = true })
		local p = env.join(-1)
		local ok, text = env.command(p, "plan", { "rotating-belt", "../../etc", "skewer-showdown" })
		t.eq(ok, false)
		t.ok(string.find(text :: string, "맵 순서를 쓸 수 없어요", 1, true) ~= nil, text)
		t.eq(select(2, env.command(p, "plan", { "a", "b" })), "명령 값이 잘못됐어요")
		t.eq(next(env.nextPlans), nil)
	end)

	t.test("QA: plan outside single-place mode refused (Lobby role)", function()
		local env = loadEnv({ studio = true, role = "Lobby" })
		local p = env.join(-1)
		t.eq(
			select(2, env.command(p, "plan", { "rotating-belt", "hot-plate", "skewer-showdown" })),
			"한 플레이스 모드에서만 돼요"
		)
		t.eq(next(env.nextPlans), nil)
	end)

	---------------------------------------------------------------- 로그
	t.test("QA: every command path logs '[Admin] Name(UserId) <command> ... -> <result>'", function()
		local env = loadEnv({ studio = false })
		local p = env.join(OWNER)
		env.command(p, "info", nil)
		env.command(p, "coins", 1000)
		env.command(p, "coins", 1.5)
		env.command(p, "nope", nil)
		local prefix = `[Admin] P{OWNER}({OWNER}) `
		t.eq(#env.prints, 4)
		t.eq(env.prints[1], prefix .. "info - -> ok")
		t.eq(env.prints[2], prefix .. "coins 1000 -> StudioOnly")
		t.eq(env.prints[3], prefix .. "coins ? -> BadCommandArgs")
		t.eq(env.prints[4], prefix .. "nope -> UnknownCommand")
	end)

	t.test("QA: AdminService.init never fails the remote on a runner error (pcall, generic message)", function()
		local env = loadEnv({ studio = true })
		local p = env.join(-1)
		env.AdminService.setCommandRunner(function()
			error("boom")
		end)
		local ok, err = env.command(p, "info", nil)
		t.eq(ok, false)
		t.eq(err, "다시 해 주세요")
	end)

	---------------------------------------------------------------- 소스 구조 (m5-02 원칙)
	t.test(
		"QA source: AdminCommands is only required lazily inside runCommand; preview path never reaches it",
		function()
			local src = fs.readFile("src/server/AdminService.luau")
			local count = 0
			for _ in string.gmatch(src, "require%(script%.Parent%.AdminCommands%)") do
				count += 1
			end
			t.eq(count, 1)
			local runBody = string.match(src, "local function runCommand.-\nend") :: string
			t.ok(runBody ~= nil and string.find(runBody, "require(script.Parent.AdminCommands)", 1, true) ~= nil)
			local previewBody = string.match(src, "local function onPreview.-\nend") :: string
			t.ok(previewBody ~= nil)
			t.eq(string.find(previewBody, "runCommand", 1, true), nil)
			for _, name in { "DataService", "ShopLogic", "ReceiptLogic", "PurchaseLog", "RewardService" } do
				t.eq(string.find(src, name, 1, true), nil, `AdminService must not mention {name}`)
			end
		end
	)

	t.test("QA source: AdminCommands only acts on the calling player and lives on the server", function()
		local src = fs.readFile("src/server/AdminCommands.luau")
		for _, bad in { "GetPlayerByUserId", "FindFirstChild", ":Kick", "ReceiptLogic", "PurchaseLog", "RewardService" } do
			t.eq(string.find(src, bad, 1, true), nil, bad)
		end
		-- 다른 플레이어 목록은 info의 인원 세기에만
		local _, uses = string.gsub(src, "GetPlayers%(", "")
		t.eq(uses, 1)
		t.ok(not fs.isFile("src/shared/AdminCommands.luau"))
		t.ok(not fs.isFile("src/shared/AdminConfig.luau"))
		local client = fs.readFile("src/client/ui/AdminController.luau") .. fs.readFile("src/client/ui/AdminPanel.luau")
		t.eq(string.find(client, "AdminConfig", 1, true), nil)
	end)
end
