--!strict
-- m5-26 재QA (p3: main 8750ee6 + 최신 main 병합 뒤). 개발 테스트가 안 보는 경계만 더해요.
--   B1 경계(참·거짓이 아닌 nameIsDefault), 칭호 기준 승수 ↔ title.w* 동기화,
--   🎫 뽑기 등급 동적 키(shop.drawGrade.*)의 en = Skins.DRAW_GRADE_INFO.english,
--   DrawLogic 거절 이유 전부 → shop.drawErr.* (한국어는 main 때와 글자 하나 다르지 않게),
--   정산 줄 4조합·티켓 토스트의 한국어 = main 때 모양, 영어에 한글·자리표시자 없음,
--   뽑기 확률표 RichText에 들어가는 글씨(스킨 이름·등급·상세 줄)에 <, >, & 없음,
--   렌더러 환경에서 지은 맵 21개의 TextLabel에 한글 없음 + 서버 월드 글씨는 키(WorldText.mark)로.

local roblox = require("@lune/roblox")

local LocTest = require("./lib/LocTest")
local RobloxRequire = require("./lib/RobloxRequire")
local RoomServiceHarness = require("./lib/RoomServiceHarness")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic)
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Maps = RobloxRequire.require(Shared.maps)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local function hasHangul(text: string): boolean
	for _, code in utf8.codes(text) do
		if
			(code >= 0xAC00 and code <= 0xD7A3)
			or (code >= 0x1100 and code <= 0x11FF)
			or (code >= 0x3130 and code <= 0x318F)
		then
			return true
		end
	end
	return false
end

local function rowOf(key: string): { [string]: string }?
	for _, row in LocTest.rows do
		if row.Key == key then
			return row
		end
	end
	return nil
end

local function cleanEnglish(t: Test.Test, text: string, label: string)
	t.ok(text ~= "", `{label}: empty`)
	t.ok(not hasHangul(text), `{label}: Hangul in English: {text}`)
	t.ok(string.find(text, "{", 1, true) == nil and string.find(text, "}", 1, true) == nil, `{label}: braces left`)
end

return function(t: Test.Test)
	---------------------------------------------------------------- B1 경계
	t.test('reQA B1: 참·거짓이 아닌 nameIsDefault("yes")는 쓴 이름으로 보고 필터해요', function()
		local env = RoomServiceHarness.load()
		local p = env.join(1, "Mina")
		local room = env.Service.restoreRoom({
			key = nil,
			settings = { maxPlayers = 8, isPrivate = false, name = "badword", nameIsDefault = "yes" :: any },
			hostUserId = 1,
		}, { p }, p)
		t.ok(room ~= nil)
		t.ok(room.name ~= "badword", `unfiltered name: {room and room.name}`)
		t.ok(#env.filterCalls >= 1, "ticket name went through the filter")
	end)

	t.test(
		"reQA B1: 방장이 다른 사람이고 이 서버에 없으면 조작된 기본 이름은 필터 뒤 돌아온 사람 이름",
		function()
			local env = RoomServiceHarness.load()
			local p = env.join(1, "Mina")
			local room = env.Service.restoreRoom({
				key = nil,
				settings = { maxPlayers = 8, isPrivate = false, name = "x badword", nameIsDefault = true },
				hostUserId = 777, -- 이 서버에 없는 방장
			}, { p }, p)
			t.ok(room ~= nil)
			t.eq(room.name, "Mina")
			t.eq(room.nameIsDefault, true)
		end
	)

	---------------------------------------------------------------- 칭호
	t.test(
		"reQA 칭호: Config.Titles 기준 승수 ↔ titleWinsFor ↔ title.w<wins> 키 (원문·영어)",
		function()
			t.eq(#Config.Titles, 3)
			for _, entry in Config.Titles do
				t.eq(ProfileSchema.titleWinsFor(entry.wins), entry.wins, `titleWinsFor({entry.wins})`)
				local row = rowOf(`title.w{entry.wins}`)
				t.ok(row ~= nil, `title.w{entry.wins} in CSV`)
				if row then
					t.eq(row.Source, entry.name)
					cleanEnglish(t, row.en, `title.w{entry.wins}`)
				end
			end
			t.eq(ProfileSchema.titleWinsFor(0), nil)
			t.eq(ProfileSchema.titleWinsFor(9), 1)
			t.eq(ProfileSchema.titleWinsFor(99), 10)
			t.eq(ProfileSchema.titleWinsFor(100000), 100)
		end
	)

	---------------------------------------------------------------- 🎫 뽑기 등급 동적 키 (developer 판단 1)
	t.test(
		"reQA 뽑기 등급: shop.drawGrade.<Grade> 5개 — Source = displayName, en = english, 키 도우미 일치",
		function()
			local count = 0
			for grade, info in Skins.DRAW_GRADE_INFO do
				count += 1
				local key = LocalizeLogic.drawGradeKey(grade)
				t.eq(key, `shop.drawGrade.{grade}`)
				t.ok(LocalizeLogic.isValidKey(key), key)
				local row = rowOf(key)
				t.ok(row ~= nil, `{key} in CSV`)
				if row then
					t.eq(row.Source, info.displayName, key)
					t.eq(row.en, info.english, `{key}: en follows Skins.DRAW_GRADE_INFO.english`)
				end
			end
			t.eq(count, 5)
			-- 고등어 상세 안내 (ShopLogic.drawHint)의 영어도 등급 이름을 그대로 써요
			local hint = LocalizeLogic.text("shop.drawHint", { grade = LocalizeLogic.text("shop.drawGrade.Legendary") })
			t.ok(string.find(LocTest.en(hint), "Legendary", 1, true) ~= nil, LocTest.en(hint))
			t.eq(LocTest.ko(hint), "🎫 뽑기 전설에서도 나와요")
		end
	)

	---------------------------------------------------------------- DrawLogic 문구 (developer 판단 5)
	t.test(
		"reQA 뽑기 거절 이유: 6개 모두 shop.drawErr.<이유>, 한국어는 main 때와 같고 영어는 깨끗해요",
		function()
			local mainKo = {
				NoTickets = "우승하면 🎫 뽑기권을 받아요",
				Locked = "매치가 끝나면 뽑을 수 있어요",
				CannotSave = "저장이 안 되는 상태예요",
				TooFast = "잠시 뒤에 다시 해 주세요",
				NoProfile = "프로필을 불러오는 중이에요",
				NoPool = "뽑을 스킨이 없어요",
			}
			for reason, ko in mainKo do
				local msg = DrawLogic.message(reason)
				t.ok(LocalizeLogic.isLocText(msg), reason)
				t.eq(msg and msg.key, `shop.drawErr.{reason}`)
				t.eq(LocTest.ko(msg), ko, reason)
				cleanEnglish(t, LocTest.en(msg), reason)
			end
			t.eq(DrawLogic.message(nil), nil)
			local unknown = DrawLogic.message("Nope" :: any)
			t.eq(unknown and unknown.key, "common.err.retry")
			-- 빈 등급·반올림 안내도 키, 퍼센트는 문자열 그대로
			t.eq(LocTest.ko(DrawLogic.EMPTY_TEXT), "준비 중")
			cleanEnglish(t, LocTest.en(DrawLogic.EMPTY_TEXT), "shop.draw.empty")
			cleanEnglish(t, LocTest.en(DrawLogic.ROUNDING_NOTE), "shop.draw.roundingNote")
			local shown = DrawLogic.displayPercents(DrawLogic.grades())
			for grade, value in shown do
				if type(value) == "string" then
					t.ok(string.match(value, "^%d+%.%d%%$") ~= nil, `{grade}: {value}`)
				else
					t.eq(value.key, "shop.draw.empty", grade)
				end
			end
			-- 결과 줄: 중복은 숫자 인자, 스킨은 이름 키
			local dup = DrawLogic.resultText({
				kind = "Duplicate",
				skinId = "concept-ikura",
				grade = "Rare",
				coins = 1500,
				ticketsLeft = 0,
			} :: any)
			t.eq(LocTest.ko(dup), "이미 가진 스킨이에요 → 🍚 +1,500")
			cleanEnglish(t, LocTest.en(dup), "resultDuplicate")
			local got = DrawLogic.resultText({
				kind = "Skin",
				skinId = "fresh-mackerel",
				grade = "Legendary",
				coins = 0,
				ticketsLeft = 0,
			} :: any)
			t.ok(string.find(LocTest.ko(got), Skins.get("fresh-mackerel").displayName, 1, true) ~= nil, LocTest.ko(got))
			cleanEnglish(t, LocTest.en(got), "resultSkin")
		end
	)

	---------------------------------------------------------------- 정산 줄 (developer 판단 7)
	t.test("reQA 정산 줄: 4조합 한국어 = main 모양, 영어 깨끗, 티켓 토스트", function()
		local function mainKo(total: number, coins: number, tokens: number?, icon: string?, tickets: number?): string
			local text = `이번 판 +{total} 🍚`
			if tokens and tokens > 0 then
				text ..= ` +{tokens} {icon or "🍬"}`
			end
			if tickets and tickets > 0 then
				text ..= ` 🎫 +{tickets}`
			end
			return `{text} (총 {coins})`
		end
		local cases = {
			{ 140, 500, nil, nil, nil, "reward.summary" },
			{ 140, 500, 8, "🍬", nil, "reward.summaryTokens" },
			{ 140, 500, nil, nil, 1, "reward.summaryTickets" },
			{ 140, 500, 8, "⭐", 1, "reward.summaryTokensTickets" },
			{ 140, 500, 0, "🍬", 0, "reward.summary" },
		}
		for _, c in cases do
			local loc = RewardLogic.summaryText(c[1], c[2], c[3], c[4], c[5])
			t.eq(loc.key, c[6])
			t.eq(LocTest.ko(loc), mainKo(c[1], c[2], c[3], c[4], c[5]), c[6])
			local en = LocTest.en(loc)
			cleanEnglish(t, en, c[6])
			if c[5] and c[5] > 0 then
				t.ok(string.find(en, "🎫 +1", 1, true) ~= nil, en)
			end
			if c[3] and c[3] > 0 then
				t.ok(string.find(en, `+8 {c[4]}`, 1, true) ~= nil, en)
			end
		end
		cleanEnglish(t, LocTest.en(RewardLogic.ticketToastText(1, false)), "reward.ticketToast")
		local full = LocTest.en(RewardLogic.ticketToastText(0, true, 99))
		cleanEnglish(t, full, "reward.ticketFull")
		t.ok(string.find(full, "99", 1, true) ~= nil, full)
	end)

	---------------------------------------------------------------- RichText 안전
	t.test(
		"reQA 뽑기 확률 상세(RichText): 스킨 이름·등급·상세 줄에 <, >, & 없음 (ko·en)",
		function()
			local function safe(text: string, label: string)
				t.ok(string.find(text, "[<>&]") == nil, `{label}: {text}`)
			end
			for _, id in Skins.DRAW_IDS do
				local key = LocalizeLogic.skinNameKey(id)
				safe(LocTest.ko({ key = key }), key)
				safe(LocTest.en({ key = key }), key)
			end
			for grade in Skins.DRAW_GRADE_INFO do
				local key = LocalizeLogic.drawGradeKey(grade)
				safe(LocTest.ko({ key = key }), key)
				safe(LocTest.en({ key = key }), key)
			end
			for _, key in
				{
					"shop.draw.perSkinLine",
					"shop.draw.duplicateLine",
					"shop.draw.noSkinsYet",
					"shop.draw.roundingNote",
					"shop.draw.empty",
				}
			do
				local row = rowOf(key)
				t.ok(row ~= nil, key)
				if row then
					safe(row.Source, key)
					safe(row.en, key)
				end
			end
		end
	)

	---------------------------------------------------------------- 맵 21개 월드 글씨
	t.test(
		"reQA 맵 21개: 지은 모델의 TextLabel에 한글 없음, 키 표시 글씨는 CSV 키 + AutoLocalize false",
		function()
			local ids = {}
			for _, info in Maps.allInfos() do
				table.insert(ids, info.id)
			end
			t.eq(#ids, 21)
			local marked = {}
			for _, id in ids do
				local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
				local ok, model = pcall(RMaps.get(id).build, origin)
				t.ok(ok, `{id}: build failed — {tostring(model)}`)
				if not ok then
					continue
				end
				for _, d in (model :: any):GetDescendants() do
					if d:IsA("TextLabel") or d:IsA("TextButton") then
						t.ok(not hasHangul(d.Text), `{id}: Hangul world text "{d.Text}" ({d:GetFullName()})`)
						local key = d:GetAttribute("LocKey")
						if key ~= nil then
							t.ok(LocTest.has(key), `{id}: LocKey {key} in CSV`)
							t.eq(d.AutoLocalize, false, `{id}: {key} AutoLocalize`)
							t.eq(d.Text, "", `{id}: {key} text filled on the client`)
							marked[key] = true
						else
							-- 키 없는 글씨는 언어와 무관한 것(숫자 타이머 등)만, 자동 번역·수집도 꺼요
							t.eq(d.AutoLocalize, false, `{id}: unmarked world text "{d.Text}" must not AutoLocalize`)
						end
					end
				end
				model:Destroy()
			end
			t.ok(marked["map.fish-market.sign"], "fish market sign is a LocKey world text")
			local sign = rowOf("map.fish-market.sign")
			t.eq(sign and sign.Source, "수산시장")
		end
	)
end
