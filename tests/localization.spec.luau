--!strict
-- m5-26 현지화: 카탈로그(Strings.csv) 검사, 코드 키 ↔ CSV, 데이터 동기화, LocalizeLogic, 한국어 리터럴 금지

local fs = require("@lune/fs")

local LocTest = require("./lib/LocTest")
local LuauStrings = require("./lib/LuauStrings")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic)
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local Skins = RobloxRequire.require(Shared.Skins)
local Offers = RobloxRequire.require(Shared.Offers)
local FxCatalog = RobloxRequire.require(Shared.FxCatalog)
local Seasons = RobloxRequire.require(Shared.Seasons)
local Elim = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local OfferLogic = RobloxRequire.require(Shared.OfferLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local CodeLogic = RobloxRequire.require(Shared.CodeLogic)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)

------------------------------------------------------------------------
-- AC11 허용 목록: { 파일, 줄에 들어 있는 글자, 이유 }. 이유 필수.
local KOREAN_ALLOWLIST = {
	{
		file = "src/server/RoomService.luau",
		contains = "매치 서버에서는 할 수 없어요",
		reason = "RoomService.forceStart — 관리자 명령(m5-11) 전용 문구, 관리자 도구는 m5-26 제외",
	},
	{
		file = "src/server/RoomService.luau",
		contains = "방이 없어요",
		reason = "RoomService.forceStart — 관리자 명령 전용",
	},
	{
		file = "src/server/RoomService.luau",
		contains = "이미 게임 중이에요",
		reason = "RoomService.forceStart — 관리자 명령 전용",
	},
	{
		file = "src/server/RoomService.luau",
		contains = "곧 자동으로 시작해요",
		reason = "RoomService.forceStart — 관리자 명령 전용",
	},
	{
		file = "src/server/PlaceService.luau",
		contains = "Studio 매치",
		reason = "Studio 흉내 모드 전용 방 이름 (스펙 제외: Studio 전용 이름)",
	},
}

-- AC11 검사 대상 (src/client 전부 + 아래 파일). 관리자 파일·CharacterFxController(2단계)는 빼요.
local SERVER_AND_LOGIC = {
	"src/server/RoomService.luau",
	"src/server/RoomDirectory.luau",
	"src/server/PlaceService.luau",
	"src/server/ShopService.luau",
	"src/server/OfferService.luau",
	"src/server/RobuxShopService.luau",
	"src/server/CodeService.luau",
	"src/shared/ShopLogic.luau",
	"src/shared/OfferLogic.luau",
	"src/shared/ReceiptLogic.luau",
	"src/shared/CodeLogic.luau",
	"src/shared/RoomLogic.luau",
	"src/shared/RewardLogic.luau",
	"src/shared/VictoryCutsceneLogic.luau",
}

local function isAdminFile(path: string): boolean
	return string.find(path, "Admin", 1, true) ~= nil
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

local function allSource(): { string }
	local files = {}
	walk("src", files)
	table.sort(files)
	return files
end

local function rowByKey(): { [string]: { [string]: string } }
	local map = {}
	for _, row in LocTest.rows do
		map[row.Key] = row
	end
	return map
end

local function sourceOf(key: string): string?
	local entry = LocTest.catalog[key]
	return if entry then entry.ko else nil
end

local function fakeRng(value: number): any
	return {
		NextInteger = function(_self: any, min: number, _max: number): number
			return min + value
		end,
	}
end

return function(t: Test.Test)
	------------------------------------------------------------------ AC1·AC2·AC3
	t.test("AC1: CSV는 문제 없이 읽히고 머리줄은 Key,Source,Context,Example,en", function()
		t.eq(LocTest.parseProblems, {}, "parse problems")
		t.eq(LocalizeLogic.headerOf(LocTest.text), "Key,Source,Context,Example,en")
		t.ok(#LocTest.rows > 300, `rows {#LocTest.rows}`)
	end)

	t.test(
		"AC2·AC3: 모든 행이 올바른 키·중복 없음·Source/en 있음·자리표시자 같음·Example",
		function()
			local seen: { [string]: boolean } = {}
			local problems: { string } = {}
			for _, row in LocTest.rows do
				if seen[row.Key] then
					table.insert(problems, `duplicate {row.Key}`)
				end
				seen[row.Key] = true
				for _, problem in LocalizeLogic.checkRow(row) do
					table.insert(problems, problem)
				end
			end
			t.eq(problems, {})
		end
	)

	------------------------------------------------------------------ AC4
	t.test("AC4: 코드에 쓴 키는 모두 CSV에 있고, 안 쓰는 CSV 키는 동적 키 모양뿐", function()
		local used: { [string]: boolean } = {}
		local missing: { string } = {}
		local patterns = {
			'Loc%.t%(%s*"([^"]+)"',
			'LocalizeLogic%.text%(%s*"([^"]+)"',
			'key%s*=%s*"([^"]+)"',
		}
		for _, path in allSource() do
			if isAdminFile(path) then
				continue
			end
			local source = fs.readFile(path)
			for _, pattern in patterns do
				for key in string.gmatch(source, pattern) do
					if LocalizeLogic.isValidKey(key) or string.find(key, ".", 1, true) then
						used[key] = true
						if not LocTest.has(key) and LocalizeLogic.isValidKey(key) then
							table.insert(missing, `{path}: {key}`)
						end
					end
				end
			end
		end
		t.eq(missing, {}, "keys used in code but missing in CSV")
		local unused: { string } = {}
		for _, row in LocTest.rows do
			if not used[row.Key] and not LocalizeLogic.isDynamicKey(row.Key) then
				table.insert(unused, row.Key)
			end
		end
		t.eq(unused, {}, "CSV keys not used in code")
	end)

	------------------------------------------------------------------ AC5
	t.test("AC5: 맵 이름·규칙이 데이터와 같아요", function()
		for _, info in Maps.allInfos() do
			local map = Maps.get(info.id)
			t.eq(sourceOf(LocalizeLogic.mapNameKey(map.id)), map.displayName, map.id)
			t.eq(sourceOf(LocalizeLogic.mapRuleKey(map.id)), map.rule, map.id)
		end
	end)

	t.test("AC5: 스킨 이름·대사·등급이 데이터와 같아요", function()
		for _, skin in Skins.LIST do
			t.eq(sourceOf(LocalizeLogic.skinNameKey(skin.id)), skin.displayName, skin.id)
			for i, line in skin.speech do
				t.eq(sourceOf(LocalizeLogic.skinSpeechKey(skin.id, i)), line, `{skin.id} {i}`)
			end
			t.eq(sourceOf(LocalizeLogic.skinSpeechKey(skin.id, #skin.speech + 1)), nil, `{skin.id} extra speech`)
		end
		for _, tier in Skins.TIERS do
			t.eq(sourceOf(LocalizeLogic.tierKey(tier)), Skins.TIER_INFO[tier].displayName, tier)
		end
	end)

	t.test("AC5: 상품·연출·시즌·칭호·보상 이유·탈락 대사가 데이터와 같아요", function()
		for _, offer in Offers.LIST do
			t.eq(sourceOf(LocalizeLogic.offerNameKey(offer.id)), offer.displayName, offer.id)
			t.eq(sourceOf(LocalizeLogic.offerBlurbKey(offer.id)), offer.blurb, `{offer.id} blurb`)
			local perks = offer.perks or {}
			for i, perk in perks do
				t.eq(sourceOf(LocalizeLogic.offerPerkKey(offer.id, i)), perk, `{offer.id} perk {i}`)
			end
			t.eq(sourceOf(LocalizeLogic.offerPerkKey(offer.id, #perks + 1)), nil, `{offer.id} extra perk`)
		end
		for _, fx in FxCatalog.LIST do
			t.eq(sourceOf(LocalizeLogic.fxNameKey(fx.id)), fx.displayName, fx.id)
		end
		for _, event in Seasons.LIST do
			t.eq(sourceOf(LocalizeLogic.seasonNameKey(event.id)), event.name, event.id)
			t.eq(sourceOf(LocalizeLogic.seasonTokenKey(event.id)), event.token.name, event.id)
		end
		for _, title in Config.Titles do
			t.eq(sourceOf(LocalizeLogic.titleKey(title.wins)), title.name, `title {title.wins}`)
		end
		t.eq(#RewardLogic.REASONS, 6)
		for _, reason in RewardLogic.REASONS do
			t.ok(LocTest.has(LocalizeLogic.rewardReasonKey(reason)), reason)
		end
		for group, lines in { common = Elim.COMMON_LINES, final = Elim.FINAL_LINES, cat = Elim.CAT_LINES } do
			for i, line in lines do
				t.eq(sourceOf(LocalizeLogic.cutsceneLineKey(group, i)), line, `{group} {i}`)
			end
			t.eq(sourceOf(LocalizeLogic.cutsceneLineKey(group, #lines + 1)), nil, `{group} extra`)
		end
		for month = 1, 12 do
			t.ok(LocTest.has(LocalizeLogic.monthKey(month)), `month {month}`)
		end
	end)

	t.test(
		"AC5: 동적 키 모양의 CSV 행은 실제 데이터가 있어요 (지운 맵·스킨의 행이 남지 않게)",
		function()
			local valid: { [string]: boolean } = {}
			local function add(key: string)
				valid[key] = true
			end
			for _, info in Maps.allInfos() do
				add(LocalizeLogic.mapNameKey(info.id))
				add(LocalizeLogic.mapRuleKey(info.id))
			end
			for _, skin in Skins.LIST do
				add(LocalizeLogic.skinNameKey(skin.id))
				for i in skin.speech do
					add(LocalizeLogic.skinSpeechKey(skin.id, i))
				end
			end
			for _, tier in Skins.TIERS do
				add(LocalizeLogic.tierKey(tier))
			end
			for _, offer in Offers.LIST do
				add(LocalizeLogic.offerNameKey(offer.id))
				if offer.blurb then
					add(LocalizeLogic.offerBlurbKey(offer.id))
				end
				for i in offer.perks or {} do
					add(LocalizeLogic.offerPerkKey(offer.id, i))
				end
			end
			for _, fx in FxCatalog.LIST do
				add(LocalizeLogic.fxNameKey(fx.id))
			end
			for _, event in Seasons.LIST do
				add(LocalizeLogic.seasonNameKey(event.id))
				add(LocalizeLogic.seasonTokenKey(event.id))
			end
			for _, title in Config.Titles do
				add(LocalizeLogic.titleKey(title.wins))
			end
			for _, reason in RewardLogic.REASONS do
				add(LocalizeLogic.rewardReasonKey(reason))
			end
			for month = 1, 12 do
				add(LocalizeLogic.monthKey(month))
			end
			for group, lines in { common = Elim.COMMON_LINES, final = Elim.FINAL_LINES, cat = Elim.CAT_LINES } do
				for i in lines do
					add(LocalizeLogic.cutsceneLineKey(group, i))
				end
			end
			local stale: { string } = {}
			for _, row in LocTest.rows do
				if LocalizeLogic.isDynamicKey(row.Key) and not valid[row.Key] then
					table.insert(stale, row.Key)
				end
			end
			t.eq(stale, {})
		end
	)

	------------------------------------------------------------------ AC6
	t.test("AC6: 이유 enum마다 message가 LocText이고 키가 CSV에 있어요", function()
		local modules: { [string]: any } = {
			ShopLogic = ShopLogic,
			OfferLogic = OfferLogic,
			ReceiptLogic = ReceiptLogic,
			CodeLogic = CodeLogic,
			RoomLogic = RoomLogic,
		}
		for name, module in modules do
			t.ok(#module.REASONS > 0, name)
			for _, reason in module.REASONS do
				local message = module.message(reason)
				t.ok(LocalizeLogic.isLocText(message), `{name} {reason}`)
				t.ok(LocTest.has(message.key), `{name} {reason} {message.key}`)
			end
		end
		t.eq(ShopLogic.message("Nope" :: any), { key = "common.err.retry" })
		t.eq(OfferLogic.message("Nope" :: any), { key = "common.err.retry" })
		t.eq(ReceiptLogic.message("Nope" :: any), { key = "common.err.retry" })
		t.eq(RoomLogic.message("Nope" :: any), { key = "common.err.retry" })
		t.eq(CodeLogic.message("Nope" :: any), { key = "code.err.Error" })
		t.eq(ShopLogic.message(nil), nil)
	end)

	------------------------------------------------------------------ AC7
	t.test("AC7: format", function()
		local text, complete = LocalizeLogic.format("{a} + {b}", { a = "1", b = 2 })
		t.eq(text, "1 + 2")
		t.eq(complete, true)
		text, complete = LocalizeLogic.format("{a} + {b}", { a = "1" })
		t.eq(text, "1 + ")
		t.eq(complete, false)
		text, complete = LocalizeLogic.format("{a}", { a = "x", extra = "y" })
		t.eq(text, "x")
		t.eq(complete, true)
		t.eq((LocalizeLogic.format("{n}", { n = 1234 })), "1,234")
		local catalog = {
			["t.outer"] = { ko = "밖 {inner}", en = "out {inner}" },
			["t.inner"] = { ko = "안 {x}", en = "in {x}" },
			["t.leaf"] = { ko = "잎", en = "leaf" },
		}
		local nested = { key = "t.outer", args = { inner = { key = "t.inner", args = { x = 5 } } } }
		t.eq(LocalizeLogic.render(catalog, "ko", nested), "밖 안 5")
		t.eq(LocalizeLogic.render(catalog, "en", nested), "out in 5")
		local deep = {
			key = "t.outer",
			args = {
				inner = { key = "t.inner", args = { x = { key = "t.inner", args = { x = { key = "t.leaf" } } } } },
			},
		}
		t.eq(LocalizeLogic.render(catalog, "en", deep), "out in in ", "depth 3 is empty")
	end)

	------------------------------------------------------------------ AC8
	t.test("AC8: choose 폴백 사슬", function()
		local entry = { ko = "안녕 {name}", en = "Hi {name}" }
		local args = { name = "Mina" }
		local function choose(language: string, translated: string?, failed: boolean?, e: any?): string
			return LocalizeLogic.choose({
				language = language,
				key = "t.key",
				entry = if e == false then nil else (e or entry),
				args = args,
				translated = translated,
				translatorError = failed,
			})
		end
		t.eq(choose("ko", "Hallo Mina", false), "안녕 Mina", "ko")
		t.eq(choose("en", "Hey Mina", false), "Hey Mina", "en ok")
		t.eq(choose("en", nil, true), "Hi Mina", "en error")
		t.eq(choose("en", "Hi {name}", false), "Hi Mina", "en placeholder left")
		t.eq(choose("de", "Hallo Mina", false), "Hallo Mina", "de ok")
		t.eq(choose("de", nil, true), "Hi Mina", "de error")
		t.eq(choose("de", "안녕 Mina", false), "Hi Mina", "de same as source")
		t.eq(choose("de", nil, true, { ko = "안녕 {name}" }), "안녕 Mina", "no en column")
		t.eq(choose("en", nil, true, false), "t.key", "missing key")
	end)

	------------------------------------------------------------------ AC9
	t.test("AC9: languageOf, formatNumber, ordinal", function()
		t.eq(LocalizeLogic.languageOf("en-us"), "en")
		t.eq(LocalizeLogic.languageOf("ko-kr"), "ko")
		t.eq(LocalizeLogic.languageOf("EN"), "en")
		t.eq(LocalizeLogic.languageOf(""), "ko")
		t.eq(LocalizeLogic.languageOf(nil), "ko")
		t.eq(LocalizeLogic.formatNumber(0), "0")
		t.eq(LocalizeLogic.formatNumber(999), "999")
		t.eq(LocalizeLogic.formatNumber(1000), "1,000")
		t.eq(LocalizeLogic.formatNumber(1234567), "1,234,567")
		t.eq(LocalizeLogic.formatNumber(-1500), "-1,500")
		t.eq(LocalizeLogic.formatNumber(2.6), "3")
		local en = { 1, "1st", 2, "2nd", 3, "3rd", 4, "4th", 11, "11th", 12, "12th", 13, "13th" }
		for i = 1, #en, 2 do
			t.eq(LocalizeLogic.ordinal(en[i], "en"), en[i + 1])
		end
		t.eq(LocalizeLogic.ordinal(21, "en"), "21st")
		t.eq(LocalizeLogic.ordinal(22, "en"), "22nd")
		t.eq(LocalizeLogic.ordinal(101, "en"), "101st")
		t.eq(LocalizeLogic.ordinal(111, "en"), "111th")
		t.eq(LocalizeLogic.ordinal(3, "ko"), "3")
	end)

	------------------------------------------------------------------ AC10
	t.test("AC10: isLocText", function()
		t.ok(LocalizeLogic.isLocText({ key = "room.err.Full" }))
		t.ok(LocalizeLogic.isLocText({ key = "a.b", args = { n = 3, s = "x", inner = { key = "c.d" } } }))
		t.ok(not LocalizeLogic.isLocText({ key = "Bad Key" }), "bad key")
		t.ok(not LocalizeLogic.isLocText({ key = "nodots" }), "no dot")
		t.ok(not LocalizeLogic.isLocText({ key = "a.b", args = { "x" } }), "array args")
		t.ok(not LocalizeLogic.isLocText({ key = "a.b", args = { f = function() end } }), "function value")
		t.ok(not LocalizeLogic.isLocText({ key = "a.b", args = { s = string.rep("x", 201) } }), "201 chars")
		t.ok(LocalizeLogic.isLocText({ key = "a.b", args = { s = string.rep("x", 200) } }), "200 chars")
		local many = {}
		for i = 1, 21 do
			many[`a{i}`] = i
		end
		t.ok(not LocalizeLogic.isLocText({ key = "a.b", args = many }), "21 args")
		many.a21 = nil
		t.ok(LocalizeLogic.isLocText({ key = "a.b", args = many }), "20 args")
		t.ok(not LocalizeLogic.isLocText("a.b"), "string")
		t.ok(not LocalizeLogic.isLocText({ key = "a.b", extra = 1 }), "extra field")
		t.eq(LocalizeLogic.text("a.b", { n = 1 }), { key = "a.b", args = { n = 1 } })
	end)

	------------------------------------------------------------------ AC11
	t.test("AC11: 화면 코드에 한국어 문자열 리터럴이 없어요 (허용 목록 제외)", function()
		for _, entry in KOREAN_ALLOWLIST do
			t.ok(entry.reason ~= "", `allowlist reason for {entry.file}`)
		end
		local files: { string } = {}
		walk("src/client", files)
		for _, path in SERVER_AND_LOGIC do
			table.insert(files, path)
		end
		local found: { string } = {}
		local allowHits: { [number]: boolean } = {}
		for _, path in files do
			if isAdminFile(path) then
				continue
			end
			local source = fs.readFile(path)
			local lines = LuauStrings.lines(source)
			for _, literal in LuauStrings.literals(source) do
				if not LuauStrings.hasHangul(literal.text) then
					continue
				end
				local lineText = lines[literal.line] or ""
				if
					string.find(lineText, "warn(", 1, true)
					or string.find(lineText, "print(", 1, true)
					or string.find(lineText, "error(", 1, true)
					or string.find(lineText, "assert(", 1, true)
				then
					continue
				end
				local allowed = false
				for index, entry in KOREAN_ALLOWLIST do
					if entry.file == path and string.find(lineText, entry.contains, 1, true) then
						allowed = true
						allowHits[index] = true
					end
				end
				if not allowed then
					table.insert(found, `{path}:{literal.line}: {literal.text}`)
				end
			end
		end
		t.eq(found, {})
		for index, entry in KOREAN_ALLOWLIST do
			t.ok(allowHits[index], `unused allowlist entry {entry.file} {entry.contains}`)
		end
	end)

	t.test("AC11: 토크나이저가 주석·보간·긴 문자열을 구분해요", function()
		local source =
			'-- "주석"\nlocal a = "가" --[[ "주석" ]]\nlocal b = `x {f("나")} 다`\nlocal c = [[라]]\n'
		local texts = {}
		for _, literal in LuauStrings.literals(source) do
			table.insert(texts, `{literal.line}:{literal.text}`)
		end
		t.eq(texts, { "2:가", "3:x {} 다", "4:라" })
	end)

	------------------------------------------------------------------ AC12·AC13
	t.test(
		"AC12: 버튼(.btn) 영어 16자 이하, 탭(.tab) 10자 이하 (자리표시자는 4자로 계산)",
		function()
			local tooLong: { string } = {}
			for _, row in LocTest.rows do
				if string.find(row.Context or "", "long-ok", 1, true) then
					continue
				end
				local limit = if string.find(row.Key, ".btn", 1, true)
					then 16
					elseif string.find(row.Key, ".tab", 1, true) then 10
					else nil
				if limit then
					local measured = string.gsub(row.en, "{[A-Za-z][A-Za-z0-9]*}", "0000")
					local length = utf8.len(measured) or #measured
					if length > limit then
						table.insert(tooLong, `{row.Key} ({length}): {row.en}`)
					end
				end
			end
			t.eq(tooLong, {})
		end
	)

	t.test("AC13: 원문에서 자리표시자 바로 뒤에 받침 따라 바뀌는 조사가 없어요", function()
		local particles =
			{ "이에요", "예요", "으로", "이", "가", "을", "를", "은", "는", "로", "과", "와" }
		local bad: { string } = {}
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
	end)

	------------------------------------------------------------------ 화면 함수가 키를 돌려줘요 (AC14 일부)
	t.test("화면 문구 함수는 CSV 키를 돌려주고 한국어로 풀면 예전 글씨와 같아요", function()
		t.eq(
			LocTest.ko(RoomLogic.message("NeedPlayers", { count = 4 })),
			"최소 4명이 모여야 시작할 수 있어요"
		)
		t.eq(LocTest.en(RoomLogic.message("Full")), "That room is full")
		t.eq(LocTest.ko(RewardLogic.toastText("RoundPass", 10)), "+10 🍚 라운드 통과")
		t.eq(LocTest.en(RewardLogic.toastText("RoundPass", 10)), "+10 🍚 Round cleared")
		t.eq(LocTest.ko(RewardLogic.summaryText(210, 1234)), "이번 판 +210 🍚 (총 1,234)")
		t.eq(LocTest.ko(CodeLogic.successMessage({ coins = 200 })), "🍚 200 받았어요!")
		t.eq(LocTest.en(CodeLogic.successMessage({ coins = 200 })), "You got 🍚 200!")
		local line = Elim.pickLineText("tamago", "Chopsticks", fakeRng(0))
		t.eq(LocTest.ko(line), Elim.pickLine("tamago", "Chopsticks", fakeRng(0)))
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } do
			for _, fx in { "Default", "Cat" } do
				local texts = Elim.lineTextsFor("salmon", variant :: any, fx :: any)
				local lines = Elim.linesFor("salmon", variant :: any, fx :: any)
				t.eq(#texts, #lines, `{variant} {fx}`)
				for i, text in texts do
					t.eq(LocTest.ko(text), lines[i], `{variant} {fx} {i}`)
				end
			end
		end
	end)

	t.test("AC14: 서버 오류·알림은 키(LocText)로 — 꽉 찬 방, 텔레포트 실패 Notice", function()
		local room = RoomLogic.newRoom(
			{ id = "1", name = "Mina", maxPlayers = 4, isPrivate = false, slot = 1, nameIsDefault = true },
			{ userId = 1, name = "Mina" }
		)
		for i = 2, 4 do
			t.ok(RoomLogic.addMember(room, { userId = i, name = `p{i}` }))
		end
		local ok, err = RoomLogic.addMember(room, { userId = 9, name = "late" })
		t.eq(ok, false)
		t.eq((err :: any).key, "room.err.Full")
		local place = fs.readFile("src/server/PlaceService.luau")
		t.ok(
			string.find(place, 'event:FireClient(player, message, kind or "error")', 1, true) ~= nil,
			"Notice always sends a kind"
		)
		t.ok(string.find(place, 'notice(player, LocalizeLogic.text("place.err.matchTeleport"))', 1, true) ~= nil)
		local offer = fs.readFile("src/server/OfferService.luau")
		t.ok(string.find(offer, "message: Types.LocText, kind", 1, true) ~= nil, "offer notice is LocText")
	end)

	t.test("AC15: 기본 방 이름은 nameIsDefault + 방장 이름, 다른 서버 목록도 그대로", function()
		local RoomDirectoryLogic = RobloxRequire.require(Shared.RoomDirectoryLogic)
		local PlacePayload = RobloxRequire.require(Shared.PlacePayload)
		local default = RoomLogic.newRoom({
			id = "1",
			name = RoomLogic.defaultName("Mina"),
			maxPlayers = 8,
			isPrivate = false,
			slot = 1,
			nameIsDefault = true,
		}, { userId = 1, name = "Mina" })
		local named = RoomLogic.newRoom(
			{ id = "2", name = "Shop", maxPlayers = 8, isPrivate = false, slot = 2 },
			{ userId = 2, name = "Bo" }
		)
		local snap = RoomLogic.snapshot(default)
		t.eq(snap.nameIsDefault, true)
		t.eq(snap.name, "Mina")
		t.eq(RoomLogic.snapshot(named).nameIsDefault, nil)
		local list = RoomLogic.listPublic({ default, named })
		t.eq(list[1].nameIsDefault, true)
		t.eq(list[2].nameIsDefault, nil)
		local entry = RoomDirectoryLogic.entryFor(default, "job-a", 100) :: any
		t.eq(entry.nameIsDefault, true)
		local read = RoomDirectoryLogic.readEntry(entry) :: any
		t.eq(read.nameIsDefault, true)
		local merged = RoomDirectoryLogic.merge({}, { read }, "job-b", 100, 30)
		t.eq(merged[1].nameIsDefault, true)
		t.eq(merged[1].name, "Mina")
		t.eq(RoomDirectoryLogic.readEntry(RoomDirectoryLogic.entryFor(named, "job-a", 100)).nameIsDefault, nil)
		-- 서버 이동(매니페스트·복귀 티켓)에도 따라가요
		local settings = PlacePayload.settingsOf(default)
		t.eq(settings.nameIsDefault, true)
		t.eq((PlacePayload.validateSettings(settings) :: any).nameIsDefault, true)
		t.eq((PlacePayload.validateSettings(PlacePayload.settingsOf(named)) :: any).nameIsDefault, nil)
		t.eq(
			select(
				2,
				PlacePayload.validateSettings({ maxPlayers = 8, isPrivate = false, name = "x", nameIsDefault = "y" })
			),
			"nameIsDefault"
		)
	end)

	t.test("기본 방 이름 키: 한국어 '{name}의 초밥집', 영어 \"{name}'s Sushi Bar\"", function()
		local loc = { key = "room.defaultName", args = { name = "Rubin" } }
		t.eq(LocTest.ko(loc), "Rubin의 초밥집")
		t.eq(LocTest.en(loc), "Rubin's Sushi Bar")
		t.eq(rowByKey()["room.defaultName"].Example ~= "", true)
	end)
end
