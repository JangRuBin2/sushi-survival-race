--!strict
-- m5-07 시즌 이벤트: 서버 서비스(ShopService BuyWithTokens, RewardService 재화 지급)를 가짜 Roblox 환경에서 직접 돌리고,
-- 클라이언트·로비 장식은 소스로 확인해요. 순수 판단은 tests/shop-logic.spec.luau·reward-logic.spec.luau.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local LocTest = require("./lib/LocTest")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)

local HALLOWEEN = 1792108800 -- 2026-10-16 00:00 UTC
local HALLOWEEN_END = 1793923200

---------------------------------------------------------------- 가짜 Roblox 환경
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

local function newEnv(): any
	local env: any = {}
	env.now = HALLOWEEN
	env.clock = 100
	env.studio = false
	env.canPersist = true
	env.profiles = {}
	env.saves = 0
	env.refreshes = 0
	env.placed = {}
	env.remotes = {}
	env.fired = {}
	env.matchHandlers = {}
	env.roomPlayers = {}

	local list: { any } = {}
	local Players = { PlayerAdded = newSignal(), PlayerRemoving = newSignal() }
	function Players.GetPlayers(_)
		return table.clone(list)
	end
	function Players.GetPlayerByUserId(_, userId: number)
		for _, player in list do
			if player.UserId == userId then
				return player
			end
		end
		return nil
	end
	env.Players = Players
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
	}
	local function remote(name: string): any
		if env.remotes[name] == nil then
			env.remotes[name] = {
				Name = name,
				FireClient = function(_, player, payload)
					table.insert(env.fired, { name = name, userId = player.UserId, payload = payload })
				end,
			}
		end
		return env.remotes[name]
	end
	local function hook(name: string)
		return function(fn)
			env.matchHandlers[name] = fn
		end
	end
	local serverModules: { [string]: any } = {
		DataService = {
			get = function(player)
				return env.profiles[player.UserId]
			end,
			waitForProfile = function(player)
				return env.profiles[player.UserId]
			end,
			update = function(player, fn)
				local profile = env.profiles[player.UserId]
				if profile == nil then
					return false
				end
				fn(profile)
				return true
			end,
			saveNow = function()
				env.saves += 1
			end,
			canPersist = function()
				return env.canPersist
			end,
			onLoaded = function() end,
		},
		AppearanceService = {
			setResolver = function() end,
			refresh = function()
				env.refreshes += 1
			end,
		},
		MatchEvents = {
			onResult = hook("onResult"),
			onMatchStart = hook("onMatchStart"),
			onRoundStart = hook("onRoundStart"),
			onMatchEnd = hook("onMatchEnd"),
		},
		RoundService = {
			placedRoomOf = function(player)
				return if env.placed[player] then "room-1" else nil
			end,
		},
		RoomService = {
			getPlayers = function()
				return env.roomPlayers
			end,
		},
	}
	local function environment(): { [string]: any }
		return {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
			},
			script = {
				Parent = setmetatable({}, {
					__index = function(_, name: string)
						return { __server = name }
					end,
				}),
			},
			require = function(target: any)
				if target.__shared == "Remotes" then
					return { fn = remote, event = remote }
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
					return env.now
				end,
			},
			warn = function() end,
			print = function() end,
		}
	end
	env.environment = environment

	function env.join(userId: number, tokens: number?): any
		local player = {
			UserId = userId,
			Name = `P{userId}`,
			Parent = Players,
			Character = nil,
			CharacterAdded = newSignal(),
			SetAttribute = function() end,
			GetAttribute = function() end,
		}
		env.profiles[userId] = {
			coins = 0,
			wins = 0,
			matchesPlayed = 0,
			ownedSkins = { tamago = true },
			equippedSkin = "tamago",
			eventTokens = { ["halloween-2026"] = tokens or 0 },
		}
		table.insert(list, player)
		return player
	end
	return env
end

local function loadShop(): any
	local env = newEnv()
	env.ShopService = load("src/server/ShopService.luau", env.environment())
	env.ShopService.init()
	env.ShopService.start()
	function env.buy(player, skinId)
		env.clock += 1
		return env.remotes.BuyWithTokens.OnServerInvoke(player, skinId)
	end
	return env
end

local function loadReward(): any
	local env = newEnv()
	env.RewardService = load("src/server/RewardService.luau", env.environment())
	env.RewardService.init()
	env.RewardService.start()
	return env
end

local function grantsOf(env: any, userId: number): { any }
	local out = {}
	for _, fired in env.fired do
		if fired.name == "RewardGranted" and fired.userId == userId then
			table.insert(out, fired.payload)
		end
	end
	return out
end

return function(t: Test.Test)
	---------------------------------------------------------------- ShopService.BuyWithTokens
	t.test(
		"AC3·AC10: BuyWithTokens — 재화 80이면 받고 자동 장착, 재화 0, 저장·다시 입히기",
		function()
			local env = loadShop()
			local p = env.join(1, 80)
			local ok, err = env.buy(p, "ghost-tamago")
			t.eq(ok, true, err)
			local profile = env.profiles[1]
			t.eq(profile.ownedSkins["ghost-tamago"], true)
			t.eq(profile.equippedSkin, "ghost-tamago")
			t.eq(profile.eventTokens["halloween-2026"], 0)
			t.eq(env.saves, 1)
			t.ok(env.refreshes >= 1)
		end
	)

	t.test(
		"AC10: 라운드 중·재화 부족·기간 끝·저장 불가·요청 간격은 거절, 프로필 그대로",
		function()
			local env = loadShop()
			local p = env.join(1, 80)
			env.placed[p] = true
			local ok, err = env.buy(p, "ghost-tamago")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "매치가 끝나면 바꿀 수 있어요")
			env.placed[p] = nil

			local poor = env.join(2, 79)
			ok, err = env.buy(poor, "ghost-tamago")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "🍬 1개 더 필요해요")
			t.eq(env.profiles[2].eventTokens["halloween-2026"], 79)

			env.now = HALLOWEEN_END
			ok, err = env.buy(p, "ghost-tamago")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "이벤트 기간이 아니에요")
			env.now = HALLOWEEN

			env.canPersist = false
			ok = env.buy(p, "ghost-tamago")
			t.eq(ok, false, "실제 서버에서 저장이 안 되면 거절")
			env.studio = true
			ok = env.buy(p, "ghost-tamago")
			t.eq(ok, true, "Studio 메모리 모드는 허용")
			env.studio = false
			env.canPersist = true

			-- 요청 간격 (같은 시각 두 번)
			local fast = env.join(3, 999)
			env.remotes.BuyWithTokens.OnServerInvoke(fast, "salmon")
			ok, err = env.remotes.BuyWithTokens.OnServerInvoke(fast, "ghost-tamago")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "잠시 뒤에 다시 해 주세요")
			-- 잘못된 인자
			ok = env.buy(fast, 42)
			t.eq(ok, false)
			ok, err = env.buy(fast, "pumpkin-sushi")
			t.eq(ok, false)
			t.eq(LocTest.ko(err), "이벤트 재화로는 받을 수 없어요")
		end
	)

	t.test("Studio에서는 Config.DEBUG.eventNow를 써요 (ShopService·RewardService·LobbyService)", function()
		for _, file in
			{ "src/server/ShopService.luau", "src/server/RewardService.luau", "src/server/LobbyService.luau" }
		do
			local src = fs.readFile(file)
			t.ok(
				string.find(src, "Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())", 1, true) ~= nil,
				file
			)
		end
		for _, file in { "src/client/ui/ShopController.luau", "src/client/ui/CoinController.luau" } do
			local src = fs.readFile(file)
			t.ok(
				string.find(src, "Config.DEBUG.eventNow, workspace:GetServerTimeNow()", 1, true) ~= nil,
				`{file} uses server time`
			)
		end
		t.eq(Config.DEBUG.eventNow, nil, "커밋 값은 nil")
	end)

	---------------------------------------------------------------- RewardService
	t.test(
		"AC9: 이벤트 중 라운드 통과 → 코인 10 + 재화 1 한 번에, eventTokens에 더해요",
		function()
			local env = loadReward()
			local p = env.join(1, 5)
			env.matchHandlers.onMatchStart("room", { 1 })
			env.matchHandlers.onRoundStart("room", 1, 3, { 1 })
			env.matchHandlers.onResult("room", { userId = 1, result = "Passed" })
			local grants = grantsOf(env, 1)
			t.eq(#grants, 1)
			t.eq(grants[1].reason, "RoundPass")
			t.eq(grants[1].amount, 10)
			t.eq(grants[1].tokens, 1)
			t.eq(grants[1].tokenTotal, 6)
			t.eq(grants[1].eventId, "halloween-2026")
			t.eq(env.profiles[1].coins, 10)
			t.eq(env.profiles[1].eventTokens["halloween-2026"], 6)
			t.ok(p ~= nil)
		end
	)

	t.test(
		"AC9: 매치 끝 — 하루 첫 판 50 + 4, 두 번째 판 재화 1만(MatchPlayed), 이벤트 밖이면 안 보내요",
		function()
			local env = loadReward()
			local p = env.join(1)
			env.roomPlayers = { p }
			env.matchHandlers.onMatchStart("room", { 1 })
			env.matchHandlers.onMatchEnd("room", { participants = { 1 } })
			local grants = grantsOf(env, 1)
			t.eq(#grants, 1)
			t.eq(grants[1].reason, "DailyFirstMatch")
			t.eq(grants[1].amount, 50)
			t.eq(grants[1].tokens, 4)
			t.eq(grants[1].tokenTotal, 4)

			env.matchHandlers.onMatchStart("room", { 1 })
			env.matchHandlers.onMatchEnd("room", { participants = { 1 } })
			grants = grantsOf(env, 1)
			t.eq(#grants, 2)
			t.eq(grants[2].reason, "MatchPlayed")
			t.eq(grants[2].amount, 0)
			t.eq(grants[2].tokens, 1)
			t.eq(grants[2].total, 50)
			t.eq(env.profiles[1].matchesPlayed, 2)
			t.eq(env.profiles[1].eventTokens["halloween-2026"], 5)

			env.now = HALLOWEEN_END
			env.profiles[1].lastDailyBonusDay = RewardLogic.dayNumber(HALLOWEEN_END) -- 그날 첫 판은 이미 받음
			env.matchHandlers.onMatchStart("room", { 1 })
			env.matchHandlers.onMatchEnd("room", { participants = { 1 } })
			t.eq(#grantsOf(env, 1), 2, "코인도 재화도 0이면 보내지 않아요")
			t.eq(env.profiles[1].matchesPlayed, 3)
		end
	)

	t.test("이벤트 밖 지급은 예전 모양 (재화 칸 nil, eventTokens 그대로)", function()
		local env = loadReward()
		env.now = HALLOWEEN - 1
		env.join(1, 7)
		env.matchHandlers.onMatchStart("room", { 1 })
		env.matchHandlers.onRoundStart("room", 3, 3, { 1 })
		env.matchHandlers.onResult("room", { userId = 1, result = "Won" })
		local grants = grantsOf(env, 1)
		t.eq(#grants, 2)
		for _, grant in grants do
			t.eq(grant.tokens, nil)
			t.eq(grant.tokenTotal, nil)
			t.eq(grant.eventId, nil)
		end
		t.eq(env.profiles[1].coins, 130)
		t.eq(env.profiles[1].wins, 1)
		t.eq(env.profiles[1].eventTokens["halloween-2026"], 7)
	end)

	---------------------------------------------------------------- 클라이언트·로비 (소스)
	t.test(
		"AC8·AC9: 클라이언트 — 이벤트 탭 먼저, 재화 배지·토스트·TokenGet, PriceCache 가격",
		function()
			local shop = fs.readFile("src/client/ui/ShopController.luau")
			t.ok(string.find(shop, "ShopLogic.defaultTab(eventNow()).id", 1, true) ~= nil, "event tab first")
			t.ok(string.find(shop, '"BuyWithTokens"', 1, true) ~= nil)
			t.ok(string.find(shop, "PriceCache.product(productId, skin.robux)", 1, true) ~= nil)
			t.ok(string.find(shop, "GetProductInfoAsync", 1, true) == nil, "가격은 PriceCache 한 곳에서")
			local screen = fs.readFile("src/client/ui/ShopScreen.luau")
			t.ok(string.find(screen, "ShopLogic.visibleSkins(", 1, true) ~= nil)
			t.ok(string.find(screen, "ShopLogic.EVENT_NOTE", 1, true) ~= nil)
			t.ok(string.find(screen, '"한정"', 1, true) ~= nil)
			local coin = fs.readFile("src/client/ui/CoinController.luau")
			t.ok(string.find(coin, 'Sfx.play("TokenGet")', 1, true) ~= nil)
			t.ok(string.find(coin, "RewardLogic.matchTokenTotal(", 1, true) ~= nil)
			t.ok(string.find(coin, "screen:setTokens(", 1, true) ~= nil)
			-- 카운트다운·압박 문구 없음 (D4)
			for _, file in { shop, screen, coin } do
				t.ok(string.find(file, "마지막 기회", 1, true) == nil)
			end
		end
	)

	t.test(
		"AC12: 로비 시즌 장식 — 10분마다 확인, 충돌 없는 MapKit 장식, 이벤트마다 40파츠 이하",
		function()
			local src = fs.readFile("src/server/LobbyService.luau")
			t.ok(string.find(src, "SEASON_CHECK_INTERVAL = 600", 1, true) ~= nil)
			t.ok(string.find(src, "SEASON_DECOR_BUDGET = 40", 1, true) ~= nil)
			t.ok(string.find(src, "MapKit.buildDecor(decor.specs", 1, true) ~= nil, "장식 규칙(충돌 없음)")
			-- Match 확인이 시즌 장식보다 먼저
			local guard = string.find(src, 'PlaceService.role() == "Match"', 1, true) :: number
			local apply = string.find(src, "pcall(applySeasonDecor)", guard, true) -- 첫 적용도 pcall (m5-07 QA 메모)
			t.ok(apply ~= nil and apply > guard)
			-- 장식 파츠 수: deco(…) 호출 × 반복 횟수 (할로윈 6×3 + 2, 크리스마스 2×5 + 4×3 + 1)
			local halloween = string.match(src, "local function halloweenDecor%(%).-\nend") :: string
			local christmas = string.match(src, "local function christmasDecor%(%).-\nend") :: string
			t.ok(halloween ~= nil and christmas ~= nil)
			local function count(body: string, needle: string): number
				local n = 0
				for _ in string.gmatch(body, needle) do
					n += 1
				end
				return n
			end
			t.eq(count(halloween, "`Pumpkin"), 3, "호박 하나에 3파츠")
			t.ok(6 * 3 + count(halloween, 'deco%(specs, "') <= 40)
			t.eq(count(christmas, "`Tree"), 5)
			t.eq(count(christmas, "`Gift"), 3)
			t.ok(2 * 5 + 4 * 3 + count(christmas, 'deco%(specs, "') <= 40)
		end
	)
end
