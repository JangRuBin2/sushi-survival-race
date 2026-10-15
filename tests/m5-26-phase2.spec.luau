--!strict
-- m5-26 QA 수정(B1~B4) + 2단계(단상·월드 글씨·칭호 숫자) 테스트.

local fs = require("@lune/fs")

local LocTest = require("./lib/LocTest")
local LuauStrings = require("./lib/LuauStrings")
local RobloxRequire = require("./lib/RobloxRequire")
local RoomServiceHarness = require("./lib/RoomServiceHarness")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic)
local PodiumLogic = RobloxRequire.require(Shared.PodiumLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local WorldText = RobloxRequire.require(Shared.WorldText)
local Attributes = RobloxRequire.require(Shared.Attributes)

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

local function restore(env: any, settings: any, hostUserId: number, players: { any }, filterWith: any): any
	return env.Service.restoreRoom({ key = nil, settings = settings, hostUserId = hostUserId }, players, filterWith)
end

local function entryOf(key: string): any
	return LocTest.catalog[key]
end

return function(t: Test.Test)
	------------------------------------------------------------------ B1 방 이름
	t.test("B1: 방장이 이 서버에 있으면 조작된 기본 이름 대신 방장 DisplayName", function()
		local env = RoomServiceHarness.load()
		local host = env.join(1, "Mina")
		local room = restore(
			env,
			{ maxPlayers = 8, isPrivate = false, name = "badword", nameIsDefault = true },
			1,
			{ host },
			host
		)
		t.ok(room ~= nil)
		t.eq(room.name, "Mina")
		t.eq(room.nameIsDefault, true)
	end)

	t.test("B1: 방장이 없으면 기본 이름도 필터하고, 걸리면 돌아온 사람 이름으로", function()
		local env = RoomServiceHarness.load()
		local p = env.join(2, "Hana")
		local room = restore(
			env,
			{ maxPlayers = 8, isPrivate = false, name = "badword", nameIsDefault = true },
			1,
			{ p },
			p
		)
		t.ok(room ~= nil)
		t.eq(room.name, "Hana")
		t.eq(room.nameIsDefault, true)
		t.ok(#env.filterCalls >= 1, "filtered")
	end)

	t.test(
		"B1: 방장이 없어도 필터를 그대로 통과한 기본 이름은 기본 이름으로 남아요",
		function()
			local env = RoomServiceHarness.load()
			local p = env.join(2, "Hana")
			local room = restore(
				env,
				{ maxPlayers = 8, isPrivate = false, name = "Mina", nameIsDefault = true },
				1,
				{ p },
				p
			)
			t.ok(room ~= nil)
			t.eq(room.name, "Mina")
			t.eq(room.nameIsDefault, true)
		end
	)

	t.test("B1: 쓴 이름은 filterWith가 있으면 항상 필터 (nameIsDefault 없음)", function()
		local env = RoomServiceHarness.load()
		local p = env.join(1, "Mina")
		local room = restore(env, { maxPlayers = 8, isPrivate = false, name = "Shop badword" }, 1, { p }, p)
		t.ok(room ~= nil)
		t.eq(room.name, "Shop #######")
		t.ok(not room.nameIsDefault)
		t.eq(#env.filterCalls, 1)
	end)

	t.test("B1: 필터가 실패하면 기본 이름도 돌아온 사람 이름 (방장 없을 때)", function()
		local env = RoomServiceHarness.load()
		local p = env.join(2, "Hana")
		env.filterFails = true
		local room = restore(
			env,
			{ maxPlayers = 8, isPrivate = false, name = "Mina", nameIsDefault = true },
			1,
			{ p },
			p
		)
		t.ok(room ~= nil)
		t.eq(room.name, "Hana")
		t.eq(room.nameIsDefault, true)
	end)

	t.test("B1: 매치 서버(filterWith 없음, 매니페스트를 믿음)는 그대로", function()
		local env = RoomServiceHarness.load()
		local p = env.join(1, "Mina")
		local room = restore(
			env,
			{ maxPlayers = 8, isPrivate = false, name = "Mina", nameIsDefault = true },
			1,
			{ p },
			nil
		)
		t.ok(room ~= nil)
		t.eq(room.name, "Mina")
		t.eq(room.nameIsDefault, true)
		t.eq(#env.filterCalls, 0)
	end)

	------------------------------------------------------------------ B3 등수
	t.test("B3: placeValue는 영어만 서수, 한국어·그 밖은 숫자", function()
		t.eq(LocalizeLogic.placeValue(5, "en"), "5th")
		t.eq(LocalizeLogic.placeValue(1, "en"), "1st")
		t.eq(LocalizeLogic.placeValue(5, "ko"), "5")
		t.eq(LocalizeLogic.placeValue(5, "de"), "5")
		t.eq(LocalizeLogic.placeValue(22, "ja"), "22")
	end)

	t.test("B3: 그 밖 언어가 카탈로그 영어로 폴백하면 englishArgs(서수)를 써요", function()
		local entry = entryOf("hud.result.out")
		-- 독일어, 번역기 없음 → 카탈로그 en + "5th"
		local fallback = LocalizeLogic.choose({
			language = "de",
			key = "hud.result.out",
			entry = entry,
			args = { place = "5" },
			translatorError = true,
			englishArgs = { place = "5th" },
		})
		t.eq(fallback, "🥢 You're out! (5th place)")
		-- 독일어 자동 번역이 있으면 숫자만 든 번역 그대로
		local translated = LocalizeLogic.choose({
			language = "de",
			key = "hud.result.out",
			entry = entry,
			args = { place = "5" },
			translated = "🥢 Ausgeschieden… (Platz 5)",
			translatorError = false,
			englishArgs = { place = "5th" },
		})
		t.eq(translated, "🥢 Ausgeschieden… (Platz 5)")
		-- 한국어는 숫자 + "등"
		local korean = LocalizeLogic.choose({
			language = "ko",
			key = "hud.result.out",
			entry = entry,
			args = { place = "5" },
			englishArgs = { place = "5th" },
		})
		t.eq(korean, "🥢 탈락했어요… (5등)")
		-- englishArgs가 없으면 예전처럼 args
		local plain = LocalizeLogic.choose({
			language = "en",
			key = "hud.result.out",
			entry = entry,
			args = { place = "3rd" },
			translatorError = true,
		})
		t.eq(plain, "🥢 You're out! (3rd place)")
	end)

	t.test(
		"B3: 등수 문구는 Loc.tPlace로만 만들어요 (Loc.place를 문구 인자로 넣지 않음)",
		function()
			local files = {}
			walk("src/client", files)
			local bad = {}
			for _, path in files do
				local source = fs.readFile(path)
				if string.find(source, "place = Loc.place(", 1, true) then
					table.insert(bad, path)
				end
			end
			t.eq(bad, {})
			local loc = fs.readFile("src/client/Loc.luau")
			t.ok(string.find(loc, "function Loc.tPlace", 1, true) ~= nil)
			t.ok(string.find(loc, "LocalizeLogic.placeValue(n, language)", 1, true) ~= nil, "Loc.place = placeValue")
		end
	)

	------------------------------------------------------------------ B4 늦은 번역기
	t.test("B4: 늦은 번역기로 다시 쓸 언어는 ko·en 밖뿐", function()
		t.eq(LocalizeLogic.needsLateRefresh("ko"), false)
		t.eq(LocalizeLogic.needsLateRefresh("en"), false)
		t.eq(LocalizeLogic.needsLateRefresh("de"), true)
		t.eq(LocalizeLogic.needsLateRefresh("ja"), true)
	end)

	t.test("B4: 다시 쓰기 목록 — 처음 것 유지, 빈 글씨 무시, 한도", function()
		local map = LocalizeLogic.newLateMap(2)
		LocalizeLogic.recordLate(map, "Quick Join", { key = "lobby.quickJoin.btn" })
		LocalizeLogic.recordLate(map, "Quick Join", { key = "other.key" })
		LocalizeLogic.recordLate(map, "", { key = "lobby.title" })
		t.eq(map.count, 1)
		t.eq((LocalizeLogic.lateEntryFor(map, "Quick Join") :: any).key, "lobby.quickJoin.btn")
		LocalizeLogic.recordLate(map, "Create Room", { key = "lobby.create.btn" })
		LocalizeLogic.recordLate(map, "Join with Code", { key = "lobby.joinCode.btn" })
		t.eq(map.count, 2)
		t.eq(LocalizeLogic.lateEntryFor(map, "Join with Code"), nil)
		t.eq(LocalizeLogic.lateEntryFor(map, "Mina"), nil) -- 이름처럼 기록에 없는 글씨는 안 건드려요
	end)

	t.test(
		"B4: Loc은 번역기가 없을 때만 기록하고, 늦게 오면 화면·구독자를 다시 써요",
		function()
			local loc = fs.readFile("src/client/Loc.luau")
			t.ok(
				string.find(loc, "if translator == nil and LocalizeLogic.needsLateRefresh(language) then", 1, true)
					~= nil
			)
			t.ok(string.find(loc, "if initialWaitOver then", 1, true) ~= nil)
			t.ok(string.find(loc, "function Loc.onChanged", 1, true) ~= nil)
			for _, path in { "src/client/fx/WorldTextController.luau", "src/client/fx/LobbyFxController.luau" } do
				t.ok(string.find(fs.readFile(path), "Loc.onChanged(", 1, true) ~= nil, path)
			end
		end
	)

	------------------------------------------------------------------ B2 영어 문구
	t.test("B2: QA 영어 다듬기 반영", function()
		local expected = {
			["hud.result.passed"] = "✅ Qualified! ({place} place)",
			["shop.btn.needCoins"] = "Need {count} more 🍚",
			["common.err.connection"] = "Connection problem. Please try again",
			["offer.fxOff.btn"] = "In Use · Remove",
			["room.err.BadCode"] = "Room codes are {count} digits",
			["offer.err.OwnsSome"] = "You already own a skin in this set. Buy the others one at a time",
			["reward.summary"] = "This match: +{total} 🍚 (Total: {coins})",
			["reward.summaryTokens"] = "This match: +{total} 🍚 +{tokens} {icon} (Total: {coins})",
			["room.status.needPlayers"] = "Need {count}+ players to start",
			["code.err.NotSaved"] = "Saving is down right now. Try codes again later",
		}
		for key, en in expected do
			t.eq(entryOf(key).en, en, key)
		end
		-- 코인 가격 최대(레어 900)로 모자란 수를 넣어도 버튼 길이 16자 안
		t.ok(utf8.len(LocTest.en({ key = "shop.btn.needCoins", args = { count = 900 } })) :: number <= 16)
	end)

	------------------------------------------------------------------ 2단계: 단상
	t.test("2단계 단상: 빈 상태·우승자·칭호·승수 (숫자 하나 + 단위가 한 키)", function()
		local empty = PodiumLogic.view(nil, nil)
		t.eq(LocTest.ko(empty.name), "다음 우승자는 누구?")
		t.eq(LocTest.en(empty.name), "Who's the next winner?")
		t.eq(empty.title, nil)
		t.eq(empty.wins, nil)

		local view = PodiumLogic.view("Mina", 12)
		t.eq(LocTest.ko(view.name), "🏆 Mina")
		t.eq(LocTest.en(view.name), "🏆 Mina")
		t.eq(LocTest.ko(view.title), "전설의 참치")
		t.eq(LocTest.en(view.title), "Legendary Tuna")
		t.eq(LocTest.ko(view.wins), "12승")
		t.eq(LocTest.en(view.wins), "Wins: 12")
		t.eq((view.wins :: any).args.wins, 12, "server-side value is a number")

		local big = PodiumLogic.view("Mina", 1234)
		t.eq(LocTest.en(big.wins), "Wins: 1,234")
		t.eq(LocTest.en(big.title), "King of the Sea")
	end)

	t.test("2단계 단상: 이상한 속성 값은 빈 상태·이름만", function()
		t.eq(PodiumLogic.view("", 3).name.key, "lobby.podium.empty")
		t.eq(PodiumLogic.view(42, 3).name.key, "lobby.podium.empty")
		t.eq(PodiumLogic.view(string.rep("a", 61), 3).name.key, "lobby.podium.empty")
		for _, wins in { 0, -1, 1.5, "3", math.huge, 0 / 0 } do
			local view = PodiumLogic.view("Mina", wins)
			t.eq(view.name.key, "lobby.podium.winner")
			t.eq(view.wins, nil, `wins {wins}`)
			t.eq(view.title, nil, `title {wins}`)
		end
		local one = PodiumLogic.view("Mina", 1)
		t.eq(LocTest.en(one.title), "Escaped Sushi")
		t.eq(LocTest.en(one.wins), "Wins: 1")
	end)

	t.test(
		"2단계 단상: 서버는 문장을 만들지 않고 이름·숫자 속성만, 이름표는 AutoLocalize false",
		function()
			local server = fs.readFile("src/server/LobbyService.luau")
			t.ok(string.find(server, "SetAttribute(Attributes.WinnerName, info.name)", 1, true) ~= nil)
			t.ok(string.find(server, "SetAttribute(Attributes.WinnerWins, wins)", 1, true) ~= nil)
			t.ok(string.find(server, "label.AutoLocalize = false", 1, true) ~= nil)
			t.eq(string.find(server, "titleFor(", 1, true), nil, "no Korean title on the server")
			local client = fs.readFile("src/client/fx/LobbyFxController.luau")
			t.ok(string.find(client, "PodiumLogic.view(", 1, true) ~= nil)
			t.ok(string.find(client, "label.AutoLocalize = false", 1, true) ~= nil)
			t.eq(Attributes.WinnerName, "WinnerName")
			t.eq(Attributes.WinnerWins, "WinnerWins")
		end
	)

	------------------------------------------------------------------ 2단계: 칭호 숫자
	t.test("2단계 칭호: 서버는 기준 승수만 (titleWinsFor), 클라이언트가 Loc.titleName", function()
		t.eq(ProfileSchema.titleWinsFor(0), nil)
		t.eq(ProfileSchema.titleWinsFor(1), 1)
		t.eq(ProfileSchema.titleWinsFor(9), 1)
		t.eq(ProfileSchema.titleWinsFor(10), 10)
		t.eq(ProfileSchema.titleWinsFor(99), 10)
		t.eq(ProfileSchema.titleWinsFor(100), 100)
		t.eq(ProfileSchema.titleWinsFor(5000), 100)
		t.eq(PodiumLogic.titleWins(42), 10)
		local reward = fs.readFile("src/server/RewardService.luau")
		t.ok(string.find(reward, "ProfileSchema.titleWinsFor(wins)", 1, true) ~= nil)
		local fx = fs.readFile("src/client/fx/CharacterFxController.luau")
		t.ok(string.find(fx, "Loc.titleName(threshold)", 1, true) ~= nil)
		t.ok(string.find(fx, "Loc.titleFromName(value)", 1, true) ~= nil, "old servers' Korean name still works")
		for wins = 1, 100 do
			local threshold = ProfileSchema.titleWinsFor(wins)
			t.ok(threshold ~= nil and LocTest.has(LocalizeLogic.titleKey(threshold :: number)), `title key for {wins}`)
		end
	end)

	------------------------------------------------------------------ 2단계: 월드 글씨
	t.test("2단계 월드 글씨: keyOf는 올바른 키만, 와사비 글씨는 키로", function()
		t.eq(WorldText.keyOf("map.soy-swamp.spicy"), "map.soy-swamp.spicy")
		t.eq(WorldText.keyOf("매워!!"), nil)
		t.eq(WorldText.keyOf(""), nil)
		t.eq(WorldText.keyOf(3), nil)
		t.eq(WorldText.keyOf(nil), nil)
		t.eq(LocTest.ko({ key = "map.soy-swamp.spicy" }), "매워!!")
		t.eq(LocTest.en({ key = "map.soy-swamp.spicy" }), "So spicy!!")
		local hazards = fs.readFile("src/shared/maps/SoySwampHazards.luau")
		t.ok(string.find(hazards, 'WorldText.mark(label, "map.soy-swamp.spicy")', 1, true) ~= nil)
		for _, literal in LuauStrings.literals(hazards) do
			t.ok(not LuauStrings.hasHangul(literal.text), `Korean literal in SoySwampHazards: {literal.text}`)
		end
	end)

	------------------------------------------------------------------ 사용자 규칙: 숫자 + 단위는 한 키
	t.test(
		"규칙: 코드는 숫자에 한국어 단위를 붙이지 않아요 (`{n}승` 같은 보간 금지, 관리자 제외)",
		function()
			local files = {}
			walk("src", files)
			local bad = {}
			for _, path in files do
				if string.find(path, "Admin", 1, true) then
					continue
				end
				for _, literal in LuauStrings.literals(fs.readFile(path)) do
					-- 보간 리터럴은 {…} 자리가 "{}"로 남아요
					if string.find(literal.text, "{}", 1, true) and LuauStrings.hasHangul(literal.text) then
						table.insert(bad, `{path}:{literal.line}: {literal.text}`)
					end
				end
			end
			t.eq(bad, {})
		end
	)

	t.test("규칙: 단위가 붙은 한국어 문구는 영어도 같은 자리표시자를 가진 한 키", function()
		local units = { "승", "명", "초", "등", "개", "일" }
		local checked = 0
		for _, row in LocTest.rows do
			for _, unit in units do
				if string.find(row.Source, "}" .. unit, 1, true) then
					checked += 1
					t.eq(
						LocalizeLogic.placeholders(row.en),
						LocalizeLogic.placeholders(row.Source),
						`{row.Key} placeholders`
					)
					t.ok(not LuauStrings.hasHangul(row.en), `{row.Key} en`)
				end
			end
		end
		t.ok(checked >= 10, `unit rows {checked}`)
	end)
end
