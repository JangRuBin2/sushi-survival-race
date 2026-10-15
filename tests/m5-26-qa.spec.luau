--!strict
-- m5-26 QA: 현지화 카탈로그 위생, 코드 키 전수 검사(AC4 보강), 용어집, LocalizeLogic 경계값,
-- 가짜 Roblox 환경으로 src/server/RoomService.luau를 직접 돌려 리모트 오류가 LocText인지(AC14),
-- 기본 방 이름(AC15), 복귀 방 이름 필터(QA B1)를 확인해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local LocTest = require("./lib/LocTest")
local LuauStrings = require("./lib/LuauStrings")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic)
local PlacePayload = RobloxRequire.require(Shared.PlacePayload)

local HANGUL = "[\234-\237][\128-\191][\128-\191]" -- UTF-8 3바이트 중 한글 음절 범위(대략, 가~힣 포함)

local function hasHangul(text: string): boolean
	for _, code in utf8.codes(text) do
		if code >= 0xAC00 and code <= 0xD7A3 then
			return true
		end
	end
	return false
end

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

local function enOf(key: string): string?
	local entry = LocTest.catalog[key]
	return if entry then entry.en else nil
end

---------------------------------------------------------------- 가짜 Roblox 환경 (RoomService)
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

local function isCatalogLocText(value: any): boolean
	return LocalizeLogic.isLocText(value) and LocTest.has(value.key)
end

return function(t: Test.Test)
	------------------------------------------------------------------ 카탈로그 위생
	t.test("QA 카탈로그: en 열에 한글이 없어요 (번역 빠짐)", function()
		local bad = {}
		for _, row in LocTest.rows do
			if hasHangul(row.en) then
				table.insert(bad, `{row.Key}: {row.en}`)
			end
		end
		t.eq(bad, {})
		t.ok(HANGUL ~= "", "pattern kept for readers")
	end)

	t.test(
		"QA 카탈로그: 앞뒤 공백·줄바꿈 없음, Context 있음, 대소문자만 다른 키 없음",
		function()
			local bad = {}
			local lower: { [string]: string } = {}
			for _, row in LocTest.rows do
				for _, column in { "Key", "Source", "en" } do
					local value = row[column]
					if string.match(value, "^%s") or string.match(value, "%s$") then
						table.insert(bad, `{row.Key}: {column} has edge whitespace`)
					end
					if string.find(value, "[\r\n]") then
						table.insert(bad, `{row.Key}: {column} has a line break`)
					end
				end
				if row.Context == "" then
					table.insert(bad, `{row.Key}: empty Context`)
				end
				local folded = string.lower(row.Key)
				if lower[folded] and lower[folded] ~= row.Key then
					table.insert(bad, `{row.Key}: same as {lower[folded]} ignoring case`)
				end
				lower[folded] = row.Key
			end
			t.eq(bad, {})
		end
	)

	t.test(
		"QA 카탈로그: 파일 머리줄·열 수가 Roblox 내보내기 형식 그대로 (Rojo가 읽는 모양)",
		function()
			local text = LocTest.text
			t.ok(string.sub(text, 1, 3) ~= "\239\187\191", "no BOM (Rojo/Roblox CSV)")
			t.eq(LocalizeLogic.headerOf(text), "Key,Source,Context,Example,en")
			for _, row in LocTest.rows do
				t.ok(row.Key ~= "" and row.Source ~= "", row.Key)
			end
			-- 따옴표·쉼표가 든 칸 예: 쉼표가 든 문구가 한 칸으로 읽혀요
			local rows, problems =
				LocalizeLogic.parseCsv('Key,Source,Context,Example,en\r\na.b,"x, ""y""\nz",c,,"e,f"\r\n')
			t.eq(problems, {})
			t.eq(rows[1].Source, 'x, "y"\nz')
			t.eq(rows[1].en, "e,f")
			local _, broken = LocalizeLogic.parseCsv('Key,Source,Context,Example,en\na.b,"open,c,,e\n')
			t.ok(#broken > 0, "unterminated quote is reported")
			local _, short = LocalizeLogic.parseCsv("Key,Source,Context,Example,en\na.b,x,c\n")
			t.ok(#short > 0, "short record is reported")
		end
	)

	------------------------------------------------------------------ AC4 보강
	t.test(
		"QA AC4 보강: 소스의 모든 문자열 리터럴 중 키 모양(영역.이름)은 CSV에 있어요 (Loc.t 밖 테이블·if 식 포함)",
		function()
			local areas: { [string]: boolean } = {}
			for _, area in LocalizeLogic.AREAS do
				areas[area] = true
			end
			local files = {}
			walk("src", files)
			local missing = {}
			local seen = 0
			for _, path in files do
				if string.find(path, "Admin", 1, true) then
					continue
				end
				for _, literal in LuauStrings.literals(fs.readFile(path)) do
					local area = string.match(literal.text, "^([a-z]+)%.")
					if area and areas[area] and LocalizeLogic.isValidKey(literal.text) then
						seen += 1
						if not LocTest.has(literal.text) then
							table.insert(missing, `{path}:{literal.line}: {literal.text}`)
						end
					end
				end
			end
			t.eq(missing, {})
			t.ok(seen > 150, `key-like literals found: {seen}`)
		end
	)

	t.test(
		"QA AC13 보강: 자리표시자 뒤 받침 따라 바뀌는 조사 (랑·야·라·아·나·이나·이고 등)",
		function()
			local particles = {
				"이랑",
				"랑",
				"이야",
				"야",
				"이라",
				"라고",
				"이나",
				"나",
				"아",
				"이고",
				"이든",
				"든",
			}
			local bad = {}
			for _, row in LocTest.rows do
				for after in string.gmatch(row.Source, "}([^{]*)") do
					for _, particle in particles do
						if string.sub(after, 1, #particle) == particle then
							table.insert(bad, `{row.Key}: {row.Source}`)
							break
						end
					end
				end
			end
			t.eq(bad, {})
		end
	)

	------------------------------------------------------------------ 용어집 (스펙 7절)
	t.test("QA 용어집: 스펙 7절 확정 영어가 CSV en과 같아요", function()
		local want = {
			["lobby.title"] = "🍣 Sushi Survival Race",
			["lobby.quickJoin.btn"] = "Quick Join",
			["lobby.create.btn"] = "Create Room",
			["lobby.joinCode.btn"] = "Join with Code",
			["lobby.create.public.btn"] = "Public",
			["intro.go"] = "GO!",
			["cutscene.eaten"] = "EATEN!",
			["input.grabbed"] = "Grabbed!",
			["cutscene.sushiBar"] = "Sushi Bar",
			["spectate.toLobby.btn"] = "Back to Lobby",
			["shop.btn.wear"] = "Wear",
			["shop.btn.wearing"] = "Wearing",
			["shop.limited"] = "Limited",
			["offer.myFx"] = "✨ My Effects",
			["offer.slot.Elimination"] = "Elimination Effect",
			["offer.slot.Victory"] = "Victory Effect",
			["code.redeem.btn"] = "Redeem",
			["coin.unsaved"] = "(Not saved)",
			["sfx.mute.on.btn"] = "🔊 Sound On",
			["sfx.mute.music.btn"] = "🎵 Music Off",
			["sfx.mute.all.btn"] = "🔇 All Off",
			["tier.Basic"] = "Basic",
			["tier.Common"] = "Common",
			["tier.Rare"] = "Rare",
			["tier.Epic"] = "Epic",
			["tier.Legendary"] = "Legendary",
			["title.w1"] = "Escaped Sushi",
			["title.w10"] = "Legendary Tuna",
			["title.w100"] = "King of the Sea",
			["season.halloween-2026.name"] = "Halloween Sushi Festival",
			["season.christmas-2026.name"] = "Christmas Sushi Festival",
			["season.halloween-2026.token"] = "Candy",
			["season.christmas-2026.token"] = "Stars",
			["fx.cat-customer.name"] = "Cat Customer",
			["fx.fireworks.name"] = "Fireworks",
			["offer.starter-pack.name"] = "Starter Pack",
			["offer.starter-pack.blurb"] = "A bundle for new players",
			["offer.epic-set.name"] = "Epic Set",
			["offer.epic-set.blurb"] = "3 Epic skins",
			["offer.legendary-set.name"] = "Legendary Set",
			["offer.legendary-set.blurb"] = "3 Legendary skins",
			["offer.fx-cat-customer.name"] = "Elimination Effect: Cat Customer",
			["offer.fx-cat-customer.blurb"] = "A cat eats you instead of a customer",
			["offer.fx-fireworks.name"] = "Victory Effect: Fireworks",
			["offer.fx-fireworks.blurb"] = "Fireworks burst when you win",
			["offer.vip.name"] = "VIP Pass",
			["offer.vip.blurb"] = "Looks only (no coin boost)",
			["offer.vip.perk.1"] = 'Exclusive skin "Gold Leaf Egg Sushi"',
			["offer.vip.perk.2"] = "👑 in front of your name",
			["offer.vip.perk.3"] = "[VIP] chat tag",
		}
		local maps = {
			["rotating-belt"] = {
				"Spinning Belt",
				"Run against the belt, dodge the chopsticks, and reach the finish!",
			},
			["soy-swamp"] = {
				"Soy Swamp & Wasabi Hill",
				"Avoid the soy puddles, launch off wasabi pads, and reach the finish!",
			},
			["ramen-rapids"] = {
				"Ramen Rapids",
				"Ride the broth rapids, hop across chashu and naruto, and reach the finish!",
			},
			["dessert-fridge"] = { "Dessert Fridge", "Slide across the slippery ice and race to the fridge door!" },
			["bouncy-castle-maze"] = { "Bouncy Maze", "Bounce across the squishy floor and find your way out!" },
			["lantern-bridge"] = { "Lantern Bridge", "Cross the wobbly bridge past the paper lanterns." },
			["hot-plate"] = { "Hot Plate", "Tiles vanish after you step on them. Keep moving to survive!" },
			["chef-board"] = {
				"Chef's Cutting Board",
				"Dodge the chopping knife and survive on the shrinking board!",
			},
			["tempura-pot"] = { "Tempura Pot Escape", "Climb away from the rising oil! Watch out for splashes!" },
			["giant-jenga"] = { "Tumbling Blocks", "The floor tips toward the missing blocks. Hang on to the end!" },
			["cat-cafe-shelves"] = {
				"Cat Café Tower",
				"Hop between narrow shelves and hang on. Don't get pushed off!",
			},
			["skewer-showdown"] = {
				"Skewer Showdown",
				"Jump over the spinning skewers! Only the last one standing escapes.",
			},
			["ikura-bombs"] = { "Roe Bomb Plate", "Dodge the falling roe bombs and be the last one standing!" },
			["tug-of-war-platform"] = {
				"Tug-of-War Platform",
				"The platform tips toward the crowd. Keep your balance and survive!",
			},
			["claw-machine-prize"] = {
				"Inside the Claw Machine",
				"Survive inside the glass box while the claw sweeps by.",
			},
		}
		for id, pair in maps do
			want[LocalizeLogic.mapNameKey(id)] = pair[1]
			want[LocalizeLogic.mapRuleKey(id)] = pair[2]
		end
		local skins = {
			tamago = "Egg Sushi",
			salmon = "Salmon",
			tuna = "Tuna",
			shrimp = "Shrimp",
			inari = "Inari",
			["kappa-maki"] = "Cucumber Roll",
			eel = "Eel",
			uni = "Sea Urchin",
			ikura = "Salmon Roe",
			octopus = "Octopus",
			["rainbow-roll"] = "Rainbow Roll",
			["aburi-salmon"] = "Flame Salmon",
			["california-roll"] = "California Roll",
			["golden-otoro"] = "Golden Tuna Belly",
			["diamond-uni"] = "Diamond Urchin",
			["dragon-roll"] = "Dragon Roll",
			["pumpkin-sushi"] = "Pumpkin Sushi",
			["ghost-tamago"] = "Ghost Egg Sushi",
			["santa-shrimp"] = "Santa Shrimp",
			["tree-maki"] = "Tree Roll",
			["vip-gold-tamago"] = "Gold Leaf Egg Sushi",
			takoyaki = "Takoyaki",
			["egg-toast"] = "Egg Toast",
			["slider-burger"] = "Slider Burger",
			tonkatsu = "Tonkatsu",
			["cat-sushi"] = "Cat Sushi",
			["robo-roll"] = "Robo Roll",
			["galaxy-roll"] = "Galaxy Roll",
			["softserve-roll"] = "Soft Serve Roll",
			["crown-tuna"] = "Crown Tuna",
			["unicorn-roll"] = "Unicorn Roll",
		}
		for id, name in skins do
			want[LocalizeLogic.skinNameKey(id)] = name
		end
		local wrong = {}
		for key, value in want do
			if enOf(key) ~= value then
				table.insert(wrong, `{key}: got {enOf(key)} want {value}`)
			end
		end
		table.sort(wrong)
		t.eq(wrong, {})
	end)

	t.test("QA 용어집: 영어에 kill/die/dead/death 같은 말이 없어요 (스펙 6절)", function()
		local bad = {}
		for _, row in LocTest.rows do
			local lower = string.lower(row.en)
			for _, word in { "kill", "die", "dead", "death", "murder" } do
				if string.find(lower, "%f[%a]" .. word .. "%f[%A]") then
					table.insert(bad, `{row.Key}: {row.en}`)
				end
			end
		end
		t.eq(bad, {})
	end)

	------------------------------------------------------------------ LocalizeLogic 경계값
	t.test(
		"QA choose 경계: 빈 결과·짝 안 맞는 괄호·오류 플래그·en과 원문이 같은 번역",
		function()
			local entry = { ko = "안녕 {name}", en = "Hi {name}" }
			local args = { name = "Mina" }
			local function choose(language: string, translated: string?, failed: boolean?): string
				return LocalizeLogic.choose({
					language = language,
					key = "t.key",
					entry = entry,
					args = args,
					translated = translated,
					translatorError = failed,
				})
			end
			t.eq(choose("en", "", false), "Hi Mina", "empty translation")
			t.eq(choose("en", "Hey {", false), "Hi Mina", "stray brace")
			t.eq(choose("en", "Hey Mina", true), "Hi Mina", "error flag wins over text")
			t.eq(choose("en", "안녕 Mina", false), "Hi Mina", "en translator returned Korean source")
			t.eq(choose("ja", "こんにちは Mina", false), "こんにちは Mina", "auto translation")
			t.eq(choose("ja", "Hi Mina", false), "Hi Mina", "translator fell back to en")
			t.eq(choose("ko", nil, true), "안녕 Mina", "ko without translator")
			t.eq(choose("", nil, true), "Hi Mina", "unknown language → en")
		end
	)

	t.test(
		"QA format: 인자 값 안의 {이름}은 다시 바꾸지 않아요 (이름으로 끼워 넣기 방지)",
		function()
			local text, complete = LocalizeLogic.format("{a} / {b}", { a = "{b}", b = "X" })
			t.eq(text, "{b} / X")
			t.eq(complete, true)
			local catalog = { ["t.room"] = { ko = "{name}의 초밥집", en = "{name}'s Sushi Bar" } }
			t.eq(
				LocalizeLogic.render(catalog, "en", { key = "t.room", args = { name = "{name}%1" } }),
				"{name}%1's Sushi Bar",
				"gsub replacement chars in args are literal"
			)
			-- 문자열 인자는 키로 풀지 않아요 (서버가 보낸 이름이 키처럼 생겨도 그대로)
			t.eq(
				LocalizeLogic.render(
					LocTest.catalog,
					"en",
					{ key = "room.defaultName", args = { name = "shop.title" } }
				),
				"shop.title's Sushi Bar"
			)
		end
	)

	t.test("QA render: 없는 키는 키 그대로, en 없는 행은 Source, ko는 Source", function()
		local catalog = { ["t.only"] = { ko = "한국어만" } }
		t.eq(LocalizeLogic.render(catalog, "en", { key = "t.missing" }), "t.missing")
		t.eq(LocalizeLogic.render(catalog, "en", { key = "t.only" }), "한국어만")
		t.eq(LocalizeLogic.render(LocTest.catalog, "de", { key = "intro.go" }), "GO!", "other language → en")
		t.eq(LocalizeLogic.render(LocTest.catalog, "ko", { key = "intro.go" }), "출발!")
	end)

	t.test("QA isLocText 경계: 깊이·숫자·메타테이블·키 길이·인자 이름·중첩 모양", function()
		local ok = LocalizeLogic.isLocText
		t.ok(ok({ key = "a.b", args = { x = { key = "c.d", args = { y = { key = "e.f" } } } } }), "depth 2 ok")
		t.ok(not ok({
			key = "a.b",
			args = { x = { key = "c.d", args = { y = { key = "e.f", args = { z = { key = "g.h" } } } } } },
		}), "depth 3 rejected")
		t.ok(not ok({ key = "a.b", args = { n = 0 / 0 } }), "NaN")
		t.ok(not ok({ key = "a.b", args = { n = math.huge } }), "inf")
		t.ok(not ok(setmetatable({ key = "a.b" }, {})), "metatable")
		t.ok(not ok({ key = "a." .. string.rep("b", 100) }), "key over 100 chars")
		t.ok(not ok({ key = "a.b", args = { ["1x"] = "v" } }), "arg name starts with digit")
		t.ok(not ok({ key = "a.b", args = { ["a-b"] = "v" } }), "arg name with dash")
		t.ok(not ok({ key = "a.b", args = { x = true } }), "boolean value")
		t.ok(not ok({ key = "a.b", args = { x = { key = "c.d", extra = 1 } } }), "nested extra field")
		t.ok(not ok({ key = "a.b", args = { x = { key = "Bad Key" } } }), "nested bad key")
		t.ok(not ok({ key = "a.b", args = "x" }), "args string")
		t.ok(not ok({ key = "A.b" }), "area must be lower case")
		t.ok(not ok({ key = "a..b" }), "empty segment")
	end)

	t.test("QA languageOf·formatNumber·ordinal 추가 경계", function()
		t.eq(LocalizeLogic.languageOf("de-de"), "de")
		t.eq(LocalizeLogic.languageOf("zh-cn"), "zh")
		t.eq(LocalizeLogic.languageOf("pt-br"), "pt")
		t.eq(LocalizeLogic.languageOf("en_US"), "en")
		t.eq(LocalizeLogic.languageOf("-x"), "ko", "no letters → source language")
		t.eq(LocalizeLogic.formatNumber(0 / 0), "0")
		t.eq(LocalizeLogic.formatNumber(math.huge), "0")
		t.eq(LocalizeLogic.formatNumber(-0.4), "0")
		t.eq(LocalizeLogic.formatNumber(999999), "999,999")
		t.eq(LocalizeLogic.formatNumber(100000), "100,000")
		t.eq(LocalizeLogic.ordinal(24, "en"), "24th")
		t.eq(LocalizeLogic.ordinal(23, "en"), "23rd")
		t.eq(LocalizeLogic.ordinal(112, "en"), "112th")
		t.eq(LocalizeLogic.ordinal(2.4, "en"), "2nd")
		t.eq(LocalizeLogic.ordinal(5, "de"), "5", "non-en is a plain number")
	end)

	------------------------------------------------------------------ 서버 → 클라이언트 계약 (코드 읽기 + 정적 검사)
	t.test("QA Notice: 서버의 Notice FireClient는 모두 (LocText, kind) 두 인자", function()
		local files = {}
		walk("src/server", files)
		local calls = 0
		for _, path in files do
			local source = fs.readFile(path)
			for line in string.gmatch(source, "[^\n]+") do
				if string.find(line, "Notice", 1, true) and string.find(line, "FireClient(", 1, true) then
					calls += 1
					t.ok(string.find(line, "FireClient%([^,]+,[^,]+,[^,]+%)") ~= nil, `{path}: {line}`)
				end
			end
		end
		local place = fs.readFile("src/server/PlaceService.luau")
		t.ok(string.find(place, 'event:FireClient(player, message, kind or "error")', 1, true) ~= nil)
		t.ok(calls >= 1, "found Notice calls")
	end)

	t.test(
		"QA 보안: 클라이언트는 서버가 준 LocText만 풀고, 문자열은 키로 보지 않아요 (Loc.text)",
		function()
			local loc = fs.readFile("src/client/Loc.luau")
			t.ok(string.find(loc, 'if type(value) == "string" then\n\t\treturn value', 1, true) ~= nil)
			t.ok(string.find(loc, "LocalizeLogic.isLocText(value)", 1, true) ~= nil)
			-- 클라이언트 → 서버 리모트 인자에서 LocText를 받아 다시 보내는 곳이 없어요
			local files = {}
			walk("src/server", files)
			for _, path in files do
				local source = fs.readFile(path)
				t.ok(string.find(source, "isLocText", 1, true) == nil, `{path} never trusts a client LocText`)
			end
		end
	)

	t.test(
		"QA AutoLocalize: 이름·글씨를 직접 만드는 클라이언트 객체는 모두 AutoLocalize = false",
		function()
			local files = {}
			walk("src/client", files)
			local bad = {}
			for _, path in files do
				if string.find(path, "Admin", 1, true) then
					continue
				end
				local source = fs.readFile(path)
				local lines = string.split(source, "\n")
				for i, line in lines do
					local var = string.match(line, 'local (%w+) = Instance%.new%("Text[LBo][a-z]+"%)')
					if var then
						local found = false
						for j = i + 1, math.min(i + 15, #lines) do
							if string.find(lines[j], var .. ".AutoLocalize = false", 1, true) then
								found = true
							end
						end
						if not found then
							table.insert(bad, `{path}:{i}: {var}`)
						end
					end
				end
			end
			t.eq(bad, {})
			local kit = fs.readFile("src/client/ui/RoomUiKit.luau")
			local _, count = string.gsub(kit, "AutoLocalize = false", "")
			t.ok(count >= 3, "Kit.label / textBox / button")
		end
	)

	------------------------------------------------------------------ RoomService (가짜 환경)
	t.test("QA AC14: 방 리모트 오류는 모두 CSV 키의 LocText (문자열 아님)", function()
		local env = loadRoomService()
		local host = env.join(1, "Mina")
		local ok, err = env.call("CreateRoom", host, { maxPlayers = 4, isPrivate = false })
		t.eq(ok, true)
		t.eq(err, nil)
		local snap = env.lastSnapshot(host)
		local roomId = snap.id

		local function expect(name: string, player: any, key: string, ...: any)
			local okay, e = env.call(name, player, ...)
			t.eq(okay, false, name)
			t.ok(isCatalogLocText(e), `{name} returns LocText`)
			t.eq(e and e.key, key, name)
			return e
		end
		-- 이미 방 안
		expect("CreateRoom", host, "room.err.AlreadyInRoom", { maxPlayers = 4, isPrivate = false })
		-- 방장 아닌 사람 시작 / 최소 인원
		local p2 = env.join(2)
		t.eq(env.call("JoinRoom", p2, roomId), true)
		expect("StartRoom", p2, "room.err.NotHost")
		local need = expect("StartRoom", host, "room.err.NeedPlayers")
		t.eq(need.args, { count = 4 })
		-- 꽉 찬 방
		t.eq(env.call("JoinRoom", env.join(3), roomId), true)
		local j4ok, j4err = env.call("JoinRoom", env.join(4), roomId)
		t.eq(j4ok, true, `join 4 {j4err and j4err.key} {env.warnings[1]}`)
		expect("JoinRoom", env.join(5), "room.err.Full", roomId)
		-- 잘못된 코드·없는 코드·없는 방·방 밖에서 나가기
		local bad = expect("JoinByCode", env.join(6), "room.err.BadCode", "12a4")
		t.eq(bad.args, { count = 4 })
		expect("JoinByCode", env.join(7), "room.err.NoCodeRoom", "9999")
		expect("JoinRoom", env.join(8), "room.err.NotFound", "nope")
		expect("JoinRoom", env.join(9), "room.err.NotFound", 42)
		expect("LeaveRoom", env.join(10), "room.err.NotInRoom")
		expect("CreateRoom", env.join(11), "room.err.BadSettings", "x")
		expect("CreateRoom", env.join(12), "room.err.BadMaxPlayers", { maxPlayers = 5, isPrivate = false })
		-- 너무 빠른 요청
		local quick = env.join(13)
		env.call("LeaveRoom", quick)
		local okay, fast = env.remotes.LeaveRoom.OnServerInvoke(quick)
		t.eq(okay, false)
		t.eq(fast.key, "room.err.TooFast")
	end)

	t.test(
		"QA AC15: 이름 없이 만든 방은 nameIsDefault + DisplayName, 이름 쓴 방은 필터된 이름",
		function()
			local env = loadRoomService()
			local host = env.join(1, "Mina")
			t.eq(env.call("CreateRoom", host, { maxPlayers = 8, isPrivate = false }), true)
			local snap = env.lastSnapshot(host)
			t.eq(snap.nameIsDefault, true)
			t.eq(snap.name, "Mina")
			t.eq(#env.filterCalls, 0, "default name is not sent to the filter")

			local other = env.join(2, "Bo")
			t.eq(env.call("CreateRoom", other, { maxPlayers = 8, isPrivate = false, name = "Shop badword" }), true)
			local named = env.lastSnapshot(other)
			t.eq(named.nameIsDefault, nil)
			t.eq(named.name, "Shop #######")
			-- QuickJoin으로 새로 만든 방도 기본 이름
			local lobbyPlayer = env.join(3, "Cy")
			local list = env.lastList(lobbyPlayer)
			t.ok(list ~= nil, "room list sent")
			local byName = {}
			for _, listing in list do
				byName[listing.name] = listing
			end
			t.eq(byName["Mina"].nameIsDefault, true)
			t.eq(byName["Shop #######"].nameIsDefault, nil)
		end
	)

	t.test("QA restoreRoom: 필터가 실패하면 그 사람 DisplayName 기본 이름", function()
		local env = loadRoomService()
		local p = env.join(1, "Mina")
		env.filterFails = true
		local room = env.Service.restoreRoom({
			key = nil,
			settings = { maxPlayers = 8, isPrivate = false, name = "Custom" },
			hostUserId = 1,
		}, { p }, p)
		t.ok(room ~= nil)
		t.eq(room.name, "Mina")
		t.eq(room.nameIsDefault, true)
	end)

	t.test(
		"QA B1 (P1): 확인 안 된 복귀 티켓의 nameIsDefault = true를 믿고 방 이름 필터를 건너뛰면 안 돼요",
		function()
			-- 로비 복귀 티켓은 TeleportData(클라이언트를 거쳐 와서 바꿀 수 있음)로 와요. validateReturnTicket은
			-- nameIsDefault = true + 임의 이름을 받아 줘요 (모양 검사뿐).
			local ticket = PlacePayload.validateReturnTicket({
				v = PlacePayload.VERSION,
				kind = "return",
				roomKey = "k-1",
				settings = { maxPlayers = 8, isPrivate = false, name = "badword", nameIsDefault = true },
				memberUserIds = { 1 },
				hostUserId = 1,
			}, 1)
			if ticket == nil then
				-- 모양이 바뀌었으면 아래 서비스 검사만으로 판단해요
				t.ok(true)
			else
				t.eq(ticket.settings.nameIsDefault, true, "tampered flag passes shape validation")
			end
			-- PlaceService.handleReturn은 확인 안 된 티켓의 settings 그대로 restoreRoom(…, player)를 불러요.
			local env = loadRoomService()
			local p = env.join(1, "Mina")
			local room = env.Service.restoreRoom({
				key = nil,
				settings = { maxPlayers = 8, isPrivate = false, name = "badword", nameIsDefault = true },
				hostUserId = 1,
			}, { p }, p)
			t.ok(room ~= nil)
			-- 기대: 필터를 거치거나(→ "#######") 이름을 서버가 아는 DisplayName으로 다시 만들어요. 원문 그대로면 안 돼요.
			t.ok(room.name ~= "badword", `unfiltered room name broadcast: {room and room.name}`)
		end
	)

	t.test(
		"QA restoreRoom: 정상 기본 이름 방은 복귀해도 nameIsDefault가 유지돼요 (B1 고칠 때 지킬 것)",
		function()
			local env = loadRoomService()
			local p = env.join(1, "Mina")
			local room = env.Service.restoreRoom({
				key = nil,
				settings = { maxPlayers = 8, isPrivate = false, name = "Mina", nameIsDefault = true },
				hostUserId = 1,
			}, { p }, p)
			t.ok(room ~= nil)
			t.eq(room.nameIsDefault, true)
			t.eq(room.name, "Mina")
		end
	)

	t.test("QA AC14: 핸들러가 오류를 던지면 room.err.ServerError (LocText)", function()
		local env = loadRoomService()
		local p = env.join(1)
		-- settings 테이블의 maxPlayers 읽기에서 오류를 내요
		local evil = setmetatable({}, {
			__index = function()
				error("boom")
			end,
		})
		local ok, err = env.call("CreateRoom", p, evil)
		t.eq(ok, false)
		t.eq(err.key, "room.err.ServerError")
		t.ok(#env.warnings > 0, "warns on the server")
	end)
end
