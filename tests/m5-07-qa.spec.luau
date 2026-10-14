--!strict
-- m5-07 QA: 시즌 이벤트 경계값·거절 순서·이중 지급·카드 상태·로비 장식 배치·Studio 전용 eventNow.
-- 서버 서비스(ShopService·RewardService)는 가짜 Roblox 환경으로 소스를 직접 돌려요 (season-shop.spec과 같은 방식).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Seasons = RobloxRequire.require(Shared.Seasons)
local Skins = RobloxRequire.require(Shared.Skins)
local LobbyLayout = RobloxRequire.require(Shared.LobbyLayout)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)

local H_START = 1792108800 -- 2026-10-16 00:00 UTC
local H_END = 1793923200 -- 2026-11-06 00:00 UTC
local C_START = 1796947200 -- 2026-12-11
local C_END = 1799366400 -- 2027-01-08
local TODAY = 1791849600 -- 2026-10-13 (할로윈 전)

---------------------------------------------------------------- 가짜 Roblox 환경 (season-shop.spec과 같은 모양 + update 횟수)
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
	local env: any = {
		now = H_START,
		clock = 100,
		studio = false,
		canPersist = true,
		profiles = {},
		saves = 0,
		updates = 0,
		refreshes = 0,
		placed = {},
		remotes = {},
		fired = {},
		matchHandlers = {},
		roomPlayers = {},
	}
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
				env.updates += 1
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
	env.environment = function(): { [string]: any }
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
	function env.join(userId: number, tokens: { [string]: number }?, owned: { [string]: boolean }?): any
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
			ownedSkins = owned or { tamago = true },
			equippedSkin = "tamago",
			eventTokens = tokens or {},
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
	function env.call(name: string, player, ...)
		env.clock += 1
		return env.remotes[name].OnServerInvoke(player, ...)
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

local function wallet(tokens: { [string]: number }?, owned: { [string]: boolean }?): any
	return { coins = 0, ownedSkins = owned or { tamago = true }, equippedSkin = "tamago", eventTokens = tokens or {} }
end

local function view(tokens: { [string]: number }?, owned: { string }?, equipped: string?): any
	return {
		coins = 0,
		equippedSkin = equipped or "tamago",
		ownedSkins = owned or { "tamago" },
		eventTokens = tokens or {},
	}
end

local function ids(list: { any }): { [string]: boolean }
	local out = {}
	for _, skin in list do
		out[skin.id] = true
	end
	return out
end

return function(t: Test.Test)
	---------------------------------------------------------------- 재화 지급 경계 (AC1·AC2)
	t.test(
		"QA AC1: 재화는 [시작, 끝) 안에서만 — 경계 1초 단위, 두 이벤트 사이는 없음",
		function()
			local cases = {
				{ H_START - 1, nil },
				{ H_START, "halloween-2026" },
				{ H_END - 1, "halloween-2026" },
				{ H_END, nil },
				{ (H_END + C_START) // 2, nil },
				{ C_START - 1, nil },
				{ C_START, "christmas-2026" },
				{ C_END - 1, "christmas-2026" },
				{ C_END, nil },
			}
			for _, case in cases do
				local tokens, eventId = RewardLogic.tokensFor("RoundPass", case[1])
				t.eq(eventId, case[2], `eventId at {case[1]}`)
				t.eq(tokens, if case[2] then 1 else nil, `tokens at {case[1]}`)
			end
			t.eq(select(1, RewardLogic.tokensFor("RoundPass", nil)), nil, "now nil → 재화 없음")
			t.eq(select(1, RewardLogic.tokensFor("Nope", H_START)), nil, "모르는 이유 → 재화 없음")
			-- 크리스마스 값도 같은 표
			t.eq(select(1, RewardLogic.tokensFor("Win", C_START)), 5)
			t.eq(select(1, RewardLogic.tokensFor("FinalQualify", C_START)), 2)
		end
	)

	t.test(
		"QA AC2: 매치 끝 — 하루 첫 판인데 이벤트 밖이면 예전과 같은 DailyFirstMatch 50, 재화 nil",
		function()
			local today = RewardLogic.dayNumber(TODAY)
			local payout = RewardLogic.matchEndPayout(nil, today, TODAY)
			t.ok(payout ~= nil)
			local p = payout :: any
			t.eq(p.reason, "DailyFirstMatch")
			t.eq(p.amount, 50)
			t.eq(p.tokens, nil)
			t.eq(p.eventId, nil)
			t.eq(p.daily, true)
			-- 이벤트 마지막 1초 / 끝난 순간
			local last = RewardLogic.matchEndPayout(today, today, H_END - 1) :: any
			t.eq(last.reason, "MatchPlayed")
			t.eq(last.tokens, 1)
			t.eq(RewardLogic.matchEndPayout(today, today, H_END), nil)
		end
	)

	t.test(
		"QA: 한 판 시뮬레이션 (이벤트 중, 3라운드) — 우승자 13개, 1라운드 탈락자 1개, 이중 지급 없음",
		function()
			local today = RewardLogic.dayNumber(H_START)
			local coins, tokens = RewardLogic.simulate({
				{ kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = { 1, 2, 3, 4 }, now = H_START },
				{ kind = "Result", userId = 1, result = "Passed", now = H_START },
				{ kind = "Result", userId = 3, result = "Passed", now = H_START },
				{ kind = "Result", userId = 2, result = "Eliminated", now = H_START },
				{ kind = "Result", userId = 4, result = "Eliminated", now = H_START },
				{ kind = "RoundStart", roundIndex = 2, roundCount = 3, userIds = { 1, 3 }, now = H_START },
				{ kind = "Result", userId = 1, result = "Passed", now = H_START },
				{ kind = "Result", userId = 3, result = "Passed", now = H_START },
				{ kind = "RoundStart", roundIndex = 3, roundCount = 3, userIds = { 1, 3 }, now = H_START },
				-- 결승에서 Passed가 와도(혹시) 결승은 통과 지급 없음
				{ kind = "Result", userId = 1, result = "Passed", now = H_START },
				{ kind = "Result", userId = 3, result = "Eliminated", now = H_START },
				{ kind = "Result", userId = 1, result = "Won", now = H_START },
				{
					kind = "MatchEnd",
					userIds = { 1, 2, 3 }, -- 4는 나감
					participants = { 1, 2, 3, 4 },
					today = today,
					lastDays = { [2] = today },
					now = H_START,
				},
			})
			-- 1: 통과 1+1, 결승 2, 우승 5, 하루 첫 판 4 = 13 / 코인 10+10+30+100+50 = 200
			t.eq(tokens[1], 13)
			t.eq(coins[1], 200)
			-- 2: 1라운드 탈락, 오늘 첫 판 이미 받음 → 판 참가 1, 코인 0
			t.eq(tokens[2], 1)
			t.eq(coins[2] or 0, 0)
			-- 3: 통과 2 + 결승 2 + 하루 첫 판 4 = 8
			t.eq(tokens[3], 8)
			-- 4: 매치 끝 전에 나감 → 아무것도 없음
			t.eq(tokens[4], nil)
			t.eq(coins[4], nil)
		end
	)

	---------------------------------------------------------------- canBuyWithTokens 거절 순서 (AC3)
	t.test("QA AC3: 거절 순서 — 카탈로그 → 기간 → 보유 → 잠금 → 저장 → 재화", function()
		local full = { ["halloween-2026"] = 80 }
		local owned = { tamago = true, ["ghost-tamago"] = true }
		-- 여러 조건이 같이 빠지면 앞 순서의 이유
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet({}, owned), H_END, false, true).reason, "EventEnded")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet({}, owned), H_START, false, true).reason, "AlreadyOwned")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet({}), H_START, false, true).reason, "Locked")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet({}), H_START, false, false).reason, "CannotSave")
		local need = ShopLogic.canBuyWithTokens("ghost-tamago", wallet({ ["halloween-2026"] = 79 }), H_START, true)
		t.eq(need.reason, "NeedTokens")
		t.eq(need.missing, 1)
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet(full), H_START - 1, true).reason, "EventEnded")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet(full), H_END - 1, true).ok, true)
		-- 재화로 받는 스킨이 아님
		for _, id in { "salmon", "pumpkin-sushi", "vip-gold-tamago", "tamago" } do
			t.eq(ShopLogic.canBuyWithTokens(id, wallet(full), H_START, true).reason, "NotForTokens", id)
		end
		for _, bad in { "nope", 42, {}, "", string.rep("a", 10000) } do
			t.eq(ShopLogic.canBuyWithTokens(bad, wallet(full), H_START, true).reason, "UnknownSkin")
		end
		-- 다른 이벤트 재화로는 못 받음 / 크리스마스 중에는 할로윈 스킨 못 받음
		t.eq(
			ShopLogic.canBuyWithTokens("ghost-tamago", wallet({ ["christmas-2026"] = 999 }), H_START, true).reason,
			"NeedTokens"
		)
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", wallet(full), C_START, true).reason, "EventEnded")
		t.eq(ShopLogic.canBuyWithTokens("tree-maki", wallet({ ["christmas-2026"] = 80 }), C_START, true).ok, true)
	end)

	t.test(
		"QA AC3: 이상한 재화 값은 0으로, 실패하면 지갑 그대로, 성공하면 남은 재화 정확히",
		function()
			for _, bad in { 0 / 0, -5, math.huge, "80" :: any } do
				local w = wallet({ ["halloween-2026"] = bad })
				local before = w.eventTokens["halloween-2026"]
				local d = ShopLogic.buyWithTokens(w, "ghost-tamago", H_START, true)
				t.eq(d.ok, false)
				t.eq(d.reason, "NeedTokens")
				t.ok(w.ownedSkins["ghost-tamago"] == nil)
				t.ok(w.eventTokens["halloween-2026"] == before or before ~= before)
				t.eq(w.equippedSkin, "tamago")
			end
			local w = wallet({ ["halloween-2026"] = 200.7, ["christmas-2026"] = 3 })
			local d = ShopLogic.buyWithTokens(w, "ghost-tamago", H_START, true)
			t.eq(d.ok, true)
			t.eq(w.eventTokens["halloween-2026"], 120)
			t.eq(w.eventTokens["christmas-2026"], 3, "다른 이벤트 재화는 그대로")
			t.eq(w.equippedSkin, "ghost-tamago")
			-- 두 번째는 AlreadyOwned, 재화 그대로 (이중 차감 없음)
			local again = ShopLogic.buyWithTokens(w, "ghost-tamago", H_START, true)
			t.eq(again.reason, "AlreadyOwned")
			t.eq(w.eventTokens["halloween-2026"], 120)
		end
	)

	---------------------------------------------------------------- 카드·탭 (AC4, m5-03 B3)
	t.test("QA AC4: cardState 7가지 + 버튼 글씨", function()
		local ghost = Skins.get("ghost-tamago")
		local pumpkin = Skins.get("pumpkin-sushi")
		local vip = Skins.get("vip-gold-tamago")
		local s = ShopLogic.cardState(ghost, view({ ["halloween-2026"] = 80 }), nil, H_START)
		t.eq(s.kind, "Tokens")
		t.eq(s.enabled, true)
		t.eq(ShopLogic.cardButtonText(s), "🍬 80으로 받기")
		s = ShopLogic.cardState(ghost, view({ ["halloween-2026"] = 32 }), nil, H_START)
		t.eq(s.kind, "NeedTokens")
		t.eq(s.enabled, false)
		t.eq(ShopLogic.cardButtonText(s), "🍬 32 / 80")
		s = ShopLogic.cardState(pumpkin, view(), { fake = true }, H_START)
		t.eq(s.kind, "Robux")
		t.eq(s.price, 99)
		t.eq(s.enabled, true)
		t.eq(ShopLogic.cardButtonText(s), "R$ 99") -- DEV5: 기존 로벅스 카드 글씨 그대로
		s = ShopLogic.cardState(pumpkin, view(), { fake = true }, H_END)
		t.eq(s.kind, "OffSale")
		t.eq(s.enabled, false)
		s = ShopLogic.cardState(pumpkin, view(nil, { "tamago", "pumpkin-sushi" }), nil, H_END)
		t.eq(s.kind, "Equip")
		t.eq(s.limited, true)
		s = ShopLogic.cardState(ghost, view(nil, { "tamago", "ghost-tamago" }, "ghost-tamago"), nil, H_END)
		t.eq(s.kind, "Equipped")
		t.eq(s.limited, true)
		s = ShopLogic.cardState(vip, view(), { fake = true }, H_START)
		t.eq(s.kind, "Vip")
		t.eq(s.enabled, false)
		t.eq(ShopLogic.cardButtonText(s), "👑 VIP 전용")
		s = ShopLogic.cardState(vip, view(nil, { "tamago", "vip-gold-tamago" }), nil, H_START)
		t.eq(s.kind, "Equip")
		t.eq(s.limited, nil, "VIP는 한정 표시 없음")
		-- 크리스마스 아이콘
		s = ShopLogic.cardState(Skins.get("tree-maki"), view({ ["christmas-2026"] = 5 }), nil, C_START)
		t.eq(ShopLogic.cardButtonText(s), "⭐ 5 / 80")
	end)

	t.test(
		"QA m5-03 B3 닫힘: 판매 기간 전(오늘) 가짜 결제여도 호박 초밥 카드는 비활성·숨김",
		function()
			local pumpkin = Skins.get("pumpkin-sushi")
			local s = ShopLogic.cardState(pumpkin, view(), { fake = true }, TODAY)
			t.eq(s.kind, "OffSale")
			t.eq(s.enabled, false)
			for _, tab in ShopLogic.tabs(TODAY) do
				local seen = ids(ShopLogic.visibleSkins(view(), tab, TODAY))
				t.ok(not seen["pumpkin-sushi"] and not seen["ghost-tamago"], tab.id)
				t.ok(not seen["santa-shrimp"] and not seen["tree-maki"], tab.id)
			end
			-- 클라이언트가 실제로 now를 넘김
			local screen = fs.readFile("src/client/ui/ShopScreen.luau")
			t.ok(string.find(screen, "ShopLogic.cardState(skin, view, robux, now)", 1, true) ~= nil)
		end
	)

	t.test(
		"QA AC4: 탭·보이는 카드 — 이벤트 탭 2종, 기간 끝 미보유는 어디에도 없음, 보유는 등급 탭에",
		function()
			local tabs = ShopLogic.tabs(H_START)
			t.eq(tabs[1].id, "event")
			t.eq(tabs[1].label, "🎃 할로윈")
			t.eq(ShopLogic.defaultTab(H_START).id, "event")
			t.eq(ShopLogic.tabs(C_START)[1].label, "🎄 크리스마스")
			t.eq(ShopLogic.defaultTab(H_END).id, "all")
			t.eq(#ShopLogic.tabs(H_END), 6) -- m5-31: 전체·🎫 특·일반·레어·에픽·전설
			local inEvent = ids(ShopLogic.visibleSkins(view(), tabs[1], H_START))
			local n = 0
			for _ in inEvent do
				n += 1
			end
			t.eq(n, 2)
			t.ok(inEvent["pumpkin-sushi"] and inEvent["ghost-tamago"])
			-- 기간 끝, 미보유
			for _, tab in ShopLogic.tabs(H_END) do
				local seen = ids(ShopLogic.visibleSkins(view(), tab, H_END))
				t.ok(not seen["pumpkin-sushi"] and not seen["ghost-tamago"], tab.id)
			end
			-- 기간 끝, 보유 → 원래 등급 탭과 전체에
			local mine = view(nil, { "tamago", "pumpkin-sushi", "ghost-tamago" })
			local epic = ids(ShopLogic.visibleSkins(mine, { id = "Epic", label = "에픽", tier = "Epic" }, H_END))
			t.ok(epic["pumpkin-sushi"])
			local rare = ids(ShopLogic.visibleSkins(mine, { id = "Rare", label = "레어", tier = "Rare" }, H_END))
			t.ok(rare["ghost-tamago"])
			local all = ids(ShopLogic.visibleSkins(mine, { id = "all", label = "전체" }, H_END))
			t.ok(all["pumpkin-sushi"] and all["ghost-tamago"])
			-- VIP 미보유는 전설 탭에 (비활성 카드)
			local legend =
				ids(ShopLogic.visibleSkins(view(), { id = "Legendary", label = "전설", tier = "Legendary" }, H_END))
			t.ok(legend["vip-gold-tamago"])
		end
	)

	t.test("QA AC5: 머리줄 — 날짜만, 크리스마스는 해를 넘겨 1월 7일", function()
		local h = Seasons.get("halloween-2026") :: any
		local c = Seasons.get("christmas-2026") :: any
		t.eq(ShopLogic.eventHeader(h, H_START), "할로윈 초밥 축제 · 11월 5일까지")
		t.eq(ShopLogic.eventHeader(h, H_END - 1, 32), "할로윈 초밥 축제 · 11월 5일까지 · 🍬 32")
		t.eq(ShopLogic.eventHeader(c, C_START, 0), "크리스마스 초밥 축제 · 1월 7일까지 · ⭐ 0")
		t.ok(string.find(ShopLogic.EVENT_NOTE, "다시 올 수도", 1, true) ~= nil)
	end)

	t.test("QA: 토스트·정산 글씨 (별 아이콘, 재화만, 코인만)", function()
		t.eq(RewardLogic.toastText("RoundPass", 10, 1, "⭐"), "+10 🍚 +1 ⭐ 라운드 통과")
		t.eq(RewardLogic.toastText("MatchPlayed", 0, 1, "🍬"), "+1 🍬 판 참가")
		t.eq(RewardLogic.toastText("DailyFirstMatch", 50, 4, "🍬"), "+50 🍚 +4 🍬 오늘 첫 판")
		t.eq(RewardLogic.toastText("RoundPass", 10, nil), "+10 🍚 라운드 통과")
		t.eq(RewardLogic.toastText("RoundPass", 10, 0, "🍬"), "+10 🍚 라운드 통과")
		t.eq(RewardLogic.summaryText(210, 1234, 8, "🍬"), "이번 판 +210 🍚 +8 🍬 (총 1234)")
		t.eq(RewardLogic.summaryText(210, 1234, 0), "이번 판 +210 🍚 (총 1234)")
		t.eq(RewardLogic.matchTokenTotal({ { tokens = 1 }, { tokens = nil }, { tokens = -3 }, { tokens = 4 } }), 5)
	end)

	---------------------------------------------------------------- ShopService.BuyWithTokens (서버)
	t.test("QA m5-03 B2 닫힘: BuyWithTokens 핸들러가 붙어 있고 잘못된 인자는 바로 거절", function()
		local env = loadShop()
		t.ok(env.remotes.BuyWithTokens ~= nil and env.remotes.BuyWithTokens.OnServerInvoke ~= nil)
		local p = env.join(1, { ["halloween-2026"] = 80 })
		for _, bad in { nil :: any, 42, true, {}, { "ghost-tamago" }, string.rep("x", 100000), "__index" } do
			local ok, err = env.call("BuyWithTokens", p, bad)
			t.eq(ok, false)
			t.ok(type(err) == "string" and err ~= "")
		end
		t.eq(env.profiles[1].eventTokens["halloween-2026"], 80)
		t.eq(env.profiles[1].ownedSkins["ghost-tamago"], nil)
		t.eq(env.updates, 0, "거절은 update 없이")
		t.eq(env.saves, 0)
	end)

	t.test(
		"QA: BuyWithTokens 성공 = update 1번 + 저장 1번, 다시 누르면 AlreadyOwned (이중 차감 없음)",
		function()
			local env = loadShop()
			local p = env.join(1, { ["halloween-2026"] = 100 })
			local ok, err = env.call("BuyWithTokens", p, "ghost-tamago")
			t.eq(ok, true, err)
			t.eq(env.updates, 1)
			t.eq(env.saves, 1)
			t.eq(env.profiles[1].eventTokens["halloween-2026"], 20)
			ok, err = env.call("BuyWithTokens", p, "ghost-tamago")
			t.eq(ok, false)
			t.eq(err, "이미 가진 스킨이에요")
			t.eq(env.profiles[1].eventTokens["halloween-2026"], 20)
			t.eq(env.updates, 1)
			t.eq(env.saves, 1)
		end
	)

	t.test(
		"QA: 요청 간격은 EquipSkin·BuyWithCoins·BuyWithTokens가 같이 쓰고, 간격 검사가 인자 검사보다 먼저",
		function()
			local env = loadShop()
			local p = env.join(1, { ["halloween-2026"] = 80 })
			env.clock += 1
			env.remotes.EquipSkin.OnServerInvoke(p, "tamago")
			local ok, err = env.remotes.BuyWithTokens.OnServerInvoke(p, "ghost-tamago")
			t.eq(ok, false)
			t.eq(err, "잠시 뒤에 다시 해 주세요")
			ok, err = env.remotes.BuyWithTokens.OnServerInvoke(p, 42)
			t.eq(err, "잠시 뒤에 다시 해 주세요")
			env.clock += Config.Shop.RequestCooldown + 0.01
			ok, err = env.remotes.BuyWithTokens.OnServerInvoke(p, "ghost-tamago")
			t.eq(ok, true, err)
		end
	)

	t.test(
		"QA: 실서버 저장 불가면 거절·저장 없음, Studio 메모리 모드면 받지만 저장 호출 없음",
		function()
			local env = loadShop()
			local p = env.join(1, { ["halloween-2026"] = 80 })
			env.canPersist = false
			local ok, err = env.call("BuyWithTokens", p, "ghost-tamago")
			t.eq(ok, false)
			t.eq(err, "저장이 안 되는 상태예요")
			t.eq(env.updates, 0)
			env.studio = true
			ok = env.call("BuyWithTokens", p, "ghost-tamago")
			t.eq(ok, true)
			t.eq(env.saves, 0, "메모리 모드는 saveNow를 부르지 않음")
			t.eq(env.profiles[1].equippedSkin, "ghost-tamago")
		end
	)

	t.test(
		"QA: eventNow는 Studio에서만 — 실서버는 Config.DEBUG.eventNow를 무시 (ShopService·RewardService)",
		function()
			local saved = Config.DEBUG.eventNow
			local ok1, problem = pcall(function()
				Config.DEBUG.eventNow = H_START
				-- 실서버: os.time() = 오늘(할로윈 전) → 기간 아님
				local env = loadShop()
				env.now = TODAY
				local p = env.join(1, { ["halloween-2026"] = 80 })
				local ok, err = env.call("BuyWithTokens", p, "ghost-tamago")
				assert(ok == false and err == "이벤트 기간이 아니에요", `live server used eventNow: {err}`)
				env.studio = true
				ok, err = env.call("BuyWithTokens", p, "ghost-tamago")
				assert(ok == true, `studio should use eventNow: {err}`)

				local renv = loadReward()
				renv.now = TODAY
				renv.join(2, { ["halloween-2026"] = 0 })
				renv.matchHandlers.onMatchStart("room", { 2 })
				renv.matchHandlers.onRoundStart("room", 1, 3, { 2 })
				renv.matchHandlers.onResult("room", { userId = 2, result = "Passed" })
				local g = grantsOf(renv, 2)
				assert(#g == 1 and g[1].tokens == nil, "live server granted tokens from eventNow")
				renv.studio = true
				renv.matchHandlers.onResult("room", { userId = 2, result = "Passed" })
				g = grantsOf(renv, 2)
				assert(#g == 2 and g[2].tokens == 1, "studio should grant tokens with eventNow")
			end)
			Config.DEBUG.eventNow = saved
			t.ok(ok1, tostring(problem))
		end
	)

	---------------------------------------------------------------- RewardService (서버)
	t.test(
		"QA: RewardService 매치 끝 — 사람마다 RewardGranted 1번, update 1번 (코인·재화 한 묶음)",
		function()
			local env = loadReward()
			local a = env.join(1)
			local b = env.join(2)
			env.profiles[2].lastDailyBonusDay = RewardLogic.dayNumber(H_START)
			env.roomPlayers = { a, b }
			env.matchHandlers.onMatchStart("room", { 1, 2 })
			local before = env.updates
			env.matchHandlers.onMatchEnd("room", { participants = { 1, 2 } })
			t.eq(env.updates - before, 2)
			local ga, gb = grantsOf(env, 1), grantsOf(env, 2)
			t.eq(#ga, 1)
			t.eq(#gb, 1)
			t.eq(ga[1].reason, "DailyFirstMatch")
			t.eq(ga[1].tokens, 4)
			t.eq(gb[1].reason, "MatchPlayed")
			t.eq(gb[1].amount, 0)
			t.eq(gb[1].tokens, 1)
			t.eq(gb[1].tokenTotal, 1)
			t.eq(gb[1].eventId, "halloween-2026")
			t.eq(env.profiles[2].coins, 0)
		end
	)

	t.test(
		"QA: RewardService 결승 출발·우승 재화가 eventTokens에 쌓이고 tokenTotal이 누적값",
		function()
			local env = loadReward()
			env.join(1, { ["halloween-2026"] = 10 })
			env.matchHandlers.onMatchStart("room", { 1 })
			env.matchHandlers.onRoundStart("room", 3, 3, { 1 })
			env.matchHandlers.onResult("room", { userId = 1, result = "Passed" }) -- 결승 통과는 지급 없음
			env.matchHandlers.onResult("room", { userId = 1, result = "Won" })
			local g = grantsOf(env, 1)
			t.eq(#g, 2)
			t.eq(g[1].reason, "FinalQualify")
			t.eq(g[1].tokens, 2)
			t.eq(g[1].tokenTotal, 12)
			t.eq(g[2].reason, "Win")
			t.eq(g[2].tokens, 5)
			t.eq(g[2].tokenTotal, 17)
			t.eq(env.profiles[1].eventTokens["halloween-2026"], 17)
		end
	)

	t.test("QA: 클라이언트에서 재화를 주는 리모트가 없음 (RewardService·ShopService)", function()
		local reward = fs.readFile("src/server/RewardService.luau")
		t.ok(string.find(reward, "OnServerEvent", 1, true) == nil)
		t.ok(string.find(reward, "OnServerInvoke", 1, true) == nil)
		local shop = fs.readFile("src/server/ShopService.luau")
		-- 재화를 더하는 곳 없음 (빼기만)
		t.ok(string.find(shop, "eventTokens", 1, true) == nil, "ShopService는 ShopLogic.buyWithTokens로만")
	end)

	---------------------------------------------------------------- 로비 시즌 장식 배치 (AC12)
	local src = fs.readFile("src/server/LobbyService.luau")
	local startAt = string.find(src, "type SeasonDecor = {", 1, true)
	local stopAt = string.find(src, "local function addSnow", 1, true)
	local decorFns: any = nil
	if startAt and stopAt then
		local chunk = string.sub(src, startAt, stopAt - 1)
			.. "\nreturn { halloween = halloweenDecor, christmas = christmasDecor, kind = decorKind }"
		decorFns = luau.load(chunk, { debugName = "LobbySeasonDecor" })()
	end

	t.test(
		"QA AC12: 시즌 장식 — 올바른 DecorSpec, 40파츠 이하, 조명 2 이하, 바닥 위, 로비 한계 안",
		function()
			t.ok(decorFns ~= nil, "장식 함수를 꺼낼 수 있어야 해요")
			for _, name in { "halloween", "christmas" } do
				local decor = decorFns[name]()
				t.eq(MapKitLogic.validate(decor.specs), nil, name)
				t.ok(MapKitLogic.count(decor.specs) <= 40, `{name} parts`)
				t.ok(#decor.lights <= 2, `{name} lights`)
				for _, spec in decor.specs do
					local b = MapKitLogic.bounds({ spec }) :: any
					-- 선물 리본(2.05)이 바닥 아래로 0.025 내려가요 — 보이지 않아 허용
					t.ok(b.min.y >= -0.05, `{name} {spec.name} below floor`)
					t.ok(b.max.y <= LobbyLayout.LIMITS.height, `{name} {spec.name} too high`)
					local r = math.sqrt(spec.offset.x ^ 2 + spec.offset.z ^ 2)
					t.ok(r <= LobbyLayout.LIMITS.radius, `{name} {spec.name} outside lobby`)
					for _, zone in LobbyLayout.CLEAR_ZONES do
						local inside = b.max.x > zone.min.x
							and b.min.x < zone.max.x
							and b.max.z > zone.min.z
							and b.min.z < zone.max.z
							and b.min.y < zone.max.y
						t.ok(not inside, `{name} {spec.name} in clear zone {zone.name}`)
					end
				end
			end
			t.eq(decorFns.kind("halloween-2026"), "halloween")
			t.eq(decorFns.kind("christmas-2027"), "christmas")
			t.eq(decorFns.kind(nil), nil)
		end
	)

	t.test(
		"QA AC12: 시즌 장식이 로비의 충돌 있는 건물(카운터·레일·벽·단상)과 겹치지 않아요",
		function()
			t.ok(decorFns ~= nil)
			local structure = table.clone(LobbyLayout.STRUCTURE)
			for _, other in LobbyLayout.DECOR do
				table.insert(structure, other) -- 의자·셰프·수조 같은 장식과도 안 겹쳐야 보기 좋아요
			end
			local hits: { string } = {}
			for _, name in { "halloween", "christmas" } do
				local decor = decorFns[name]()
				for _, spec in decor.specs do
					if spec.transparency == 1 then
						continue -- 눈 구름(보이지 않는 판)
					end
					local a = MapKitLogic.bounds({ spec }) :: any
					for _, other in structure do
						local b = MapKitLogic.bounds({ other }) :: any
						local hit = a.max.x > b.min.x + 0.05
							and a.min.x < b.max.x - 0.05
							and a.max.y > b.min.y + 0.05
							and a.min.y < b.max.y - 0.05
							and a.max.z > b.min.z + 0.05
							and a.min.z < b.max.z - 0.05
						if hit then
							table.insert(hits, `{name} {spec.name} × {other.name}`)
						end
					end
				end
			end
			t.eq(#hits, 0, table.concat(hits, ", "))
		end
	)

	t.test(
		"QA AC12: 장식 폴더는 바뀔 때만 지우고 새로 만들어요 (누수 없음), 10분 루프는 pcall",
		function()
			t.ok(string.find(src, "if kind == seasonDecorKind then\n\t\treturn", 1, true) ~= nil)
			t.ok(
				string.find(
					src,
					"local old = lobby:FindFirstChild(SEASON_FOLDER)\n\tif old then\n\t\told:Destroy()",
					1,
					true
				) ~= nil
			)
			t.ok(string.find(src, "pcall(applySeasonDecor)", 1, true) ~= nil)
		end
	)
end
