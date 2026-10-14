--!strict
-- m5-31 우승자 뽑기 티켓 (2차 결정 2026-10-14): 카탈로그(특 스킨 이름·drawGrade·DRAW_IDS), 무료 아님, 프로필 v3,
-- 등급별 확률(꽝 없음, 빈 등급 몫 나누기), 표시 = 판정, 뽑기 판정·분포·적용, 대표 스킨, 우승 지급,
-- Studio 전부 입기, 관리자 tickets, 리모트·타입·설정, 탈의실 로직. (스펙 AC1~AC14)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local SushiBody = RobloxRequire.require(Shared.SushiBody)

-- id, 새 이름, 뽑기 등급
local SPECIAL = {
	{ "concept-salmon", "연어초밥 (특)", "Epic" },
	{ "concept-tuna", "참치초밥 (특)", "Uncommon" },
	{ "concept-shrimp", "새우초밥 (특)", "Common" },
	{ "concept-tamago", "계란초밥 (특)", "Common" },
	{ "concept-ikura", "연어알 군함 (특)", "Rare" },
	{ "concept-unagi", "장어초밥 (특)", "Uncommon" },
	{ "concept-uni", "성게 군함 (특)", "Rare" },
	{ "concept-tako", "문어초밥 (특)", "Rare" },
	{ "concept-inari", "유부초밥 (특)", "Uncommon" },
}

local HALLOWEEN = 1792108800 + 3600 -- 할로윈 이벤트 안 (m5-07)

local function keys(map: { [string]: any }): { string }
	local list = {}
	for key in map do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

local function near(t: Test.Test, a: number, b: number, eps: number, message: string)
	t.ok(math.abs(a - b) <= eps, `{message}: {a} vs {b}`)
end

-- 시드로 만드는 결정적 rng (Random.new(seed)와 같은 메서드). 48비트 LCG
local function seededRng(seed: number)
	local state = seed
	local function step(): number
		state = (state * 25214903917 + 11) % 281474976710656
		return state / 281474976710656
	end
	return {
		NextNumber = function(_): number
			return step()
		end,
		NextInteger = function(_, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1))
		end,
	}
end

-- 정해진 값을 돌려주는 가짜 rng
local function fakeRng(number: number, integer: number?)
	local calls = { number = 0, integer = 0, lastMax = 0 }
	local rng = {
		NextNumber = function(_): number
			calls.number += 1
			return number
		end,
		NextInteger = function(_, _min: number, max: number): number
			calls.integer += 1
			calls.lastMax = max
			return integer or 1
		end,
	}
	return rng, calls
end

-- 가짜 카탈로그: 전설 1종 추가 (m5-32 고등어 흉내)
local MACKEREL = "fresh-mackerel-test"
local function withLegendary(): { any }
	local list = table.clone(Skins.LIST) :: { any }
	table.insert(list, {
		id = MACKEREL,
		displayName = "고등어 초밥 [신선]",
		tier = "Legendary",
		robux = 199,
		drawGrade = "Legendary",
		speech = { "팔딱!" },
		order = 999,
	})
	return list
end

-- 가짜 카탈로그: 영웅(연어) 빼기 (영웅·전설 비움)
local function withoutEpic(): { any }
	local list = {}
	for _, skin in Skins.LIST do
		if skin.id ~= "concept-salmon" then
			table.insert(list, skin)
		end
	end
	return list
end

local function wallet(tickets: number, owned: { string }?): any
	local ownedSkins = { tamago = true }
	for _, id in owned or {} do
		ownedSkins[id] = true
	end
	return { coins = 0, ownedSkins = ownedSkins, equippedSkin = "tamago", drawTickets = tickets, eventTokens = {} }
end

local function gradeOf(rows: { any }, grade: string): any
	for _, row in rows do
		if row.grade == grade then
			return row
		end
	end
	return nil
end

-- 실제 카탈로그 누적 경계
local EPIC = 5 / 99
local RARE_END = 20 / 99
local UNCOMMON_END = 50 / 99

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 카탈로그
	t.test(
		"AC1: 특 9종 이름 '(특)'·drawGrade 표대로·가격 없음·id·order·대사·conceptBody 그대로, validate 통과",
		function()
			local orders = {
				["concept-salmon"] = 32,
				["concept-tuna"] = 33,
				["concept-shrimp"] = 34,
				["concept-tamago"] = 35,
				["concept-ikura"] = 36,
				["concept-unagi"] = 37,
				["concept-uni"] = 38,
				["concept-tako"] = 39,
				["concept-inari"] = 40,
			}
			for _, row in SPECIAL do
				local skin = Skins.get(row[1])
				t.ok(skin ~= nil, row[1])
				t.eq(skin.displayName, row[2], `{row[1]} name`)
				t.ok(string.find(skin.displayName, "(테스트)", 1, true) == nil, `{row[1]} no (테스트)`)
				t.ok(string.find(skin.displayName, "콘셉트", 1, true) == nil, `{row[1]} no 콘셉트`)
				t.eq(skin.drawGrade, row[3], `{row[1]} grade`)
				t.eq(Skins.drawGradeOf(row[1]), row[3])
				t.eq(skin.tier, "Basic", `{row[1]} tier`)
				t.eq(skin.conceptBody, true, `{row[1]} conceptBody`)
				t.eq(skin.order, orders[row[1]], `{row[1]} order`)
				t.eq(#skin.speech, 2, `{row[1]} speech`)
				t.eq(Skins.isDrawOnly(row[1]), true, row[1])
				for _, field in { "robux", "coins", "tokens", "season", "vipOnly", "productId" } do
					t.eq((skin :: any)[field], nil, `{row[1]} {field}`)
				end
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("AC1: DRAW_IDS(9) = drawGrade가 있는 id = CONCEPT_BODY_IDS = SushiBody.CONCEPT_BODY", function()
		local drawIds = {}
		for _, skin in Skins.LIST do
			if skin.drawGrade ~= nil then
				drawIds[skin.id] = true
			end
		end
		t.eq(keys(drawIds), keys(Skins.DRAW_IDS))
		t.eq(keys(Skins.DRAW_IDS), keys(Skins.CONCEPT_BODY_IDS))
		t.eq(keys(Skins.DRAW_IDS), keys(SushiBody.CONCEPT_BODY))
		t.eq(#keys(Skins.DRAW_IDS), 9)
		t.eq(DrawLogic.totalSkins(), 9)
		for _, id in { "tamago", "salmon", "no-such" } do
			t.eq(Skins.isDraw(id), false, id)
			t.eq(Skins.isDrawOnly(id), false, id)
		end
		t.eq(Skins.DRAW_GRADES, { "Legendary", "Epic", "Rare", "Uncommon", "Common" })
		local names = {}
		for _, grade in Skins.DRAW_GRADES do
			table.insert(names, Skins.DRAW_GRADE_INFO[grade].displayName)
		end
		t.eq(names, { "전설", "영웅", "희귀", "고급", "일반" })
	end)

	t.test("AC1: validate가 잡는 것 / 가짜 고등어(drawGrade + 전설 199)는 통과", function()
		local function patched(id: string, patch: { [string]: any }): (boolean, string)
			local list = table.clone(Skins.LIST) :: { any }
			for i, skin in list do
				if skin.id == id then
					local copy = table.clone(skin)
					for key, value in patch do
						copy[key] = value
					end
					list[i] = copy
				end
			end
			local ok, problems = Skins.validate(list)
			return ok, table.concat(problems, ";")
		end
		local ok1, p1 = patched("concept-uni", { drawGrade = "Mythic" })
		t.eq(ok1, false)
		t.ok(string.find(p1, "unknown drawGrade", 1, true) ~= nil, p1)
		local ok2, p2 = patched("salmon", { drawGrade = "Rare" }) -- 목록 밖 id
		t.eq(ok2, false)
		t.ok(string.find(p2, "DRAW_IDS", 1, true) ~= nil, p2)
		for _, field in
			{
				{ "coins", 300 },
				{ "tokens", 80 },
				{ "season", "halloween-2026" },
				{ "vipOnly", true },
				{ "productId", 123 },
			}
		do
			t.eq((patched("concept-uni", { [field[1]] = field[2] })), false, `draw-only + {field[1]}`)
		end
		t.eq((patched("concept-uni", { tier = "Rare" })), false, "draw-only tier")
		-- 가짜 고등어
		Skins.DRAW_IDS[MACKEREL] = true
		local ok3, problems3 = Skins.validate(withLegendary() :: any)
		local fake = withLegendary()
		fake[#fake].robux = 99 -- 전설 가격표와 다름
		local ok4 = Skins.validate(fake :: any)
		local fake2 = withLegendary()
		fake2[#fake2].season = "halloween-2026"
		local ok5 = Skins.validate(fake2 :: any)
		Skins.DRAW_IDS[MACKEREL] = nil
		t.ok(ok3, table.concat(problems3, "; "))
		t.eq(ok4, false, "wrong tier price")
		t.eq(ok5, false, "draw + season")
	end)

	---------------------------------------------------------------- AC2 무료 아님
	t.test(
		"AC2: isFree는 계란초밥만, 새 프로필에서 특 스킨 장착·코인·로벅스·재화 모두 거절, 보유하면 장착",
		function()
			t.eq(Skins.isFree("tamago"), true)
			local fresh = ProfileSchema.new()
			for _, row in SPECIAL do
				local id = row[1]
				t.eq(Skins.isFree(id), false, id)
				t.eq(select(2, ShopLogic.canEquip(id, fresh.ownedSkins)), "NotOwned", id)
				t.eq(ShopLogic.canBuyWithCoins(id, fresh).reason, "NotForCoins", id)
				t.eq(
					select(2, ReceiptLogic.canRequest(id, fresh.ownedSkins, { canSave = true, fake = true })),
					"NotRobux"
				)
				t.eq(ShopLogic.canBuyWithTokens(id, fresh, HALLOWEEN, true, false).reason, "NotForTokens", id)
				t.eq(ShopLogic.canEquip(id, { tamago = true, [id] = true }), true, id)
			end
		end
	)

	---------------------------------------------------------------- AC3 프로필 v3
	t.test(
		"AC3: VERSION 3, 새 프로필 0, v2 → 0, 잘못된 값 0(노트)·99 초과 99, 특 스킨 장착 정리, toView",
		function()
			t.eq(ProfileSchema.VERSION, 3)
			t.eq(ProfileSchema.new().drawTickets, 0)
			local v2 = ProfileSchema.new() :: any
			v2.version = 2
			v2.drawTickets = nil
			v2.coins = 777
			v2.ownedSkins.salmon = true
			local migrated, info = ProfileLogic.migrate(v2)
			t.eq(migrated.drawTickets, 0)
			t.eq(migrated.coins, 777)
			t.eq(migrated.ownedSkins.salmon, true)
			t.eq(migrated.version, 3)
			t.eq(info.persistable, true)
			for _, bad in { -1, 1.5, 0 / 0, "3", math.huge } :: { any } do
				local raw = ProfileSchema.new() :: any
				raw.drawTickets = bad
				local profile, badInfo = ProfileLogic.migrate(raw)
				t.eq(profile.drawTickets, 0, tostring(bad))
				t.ok(#badInfo.notes >= 1, `{tostring(bad)} note`)
			end
			local big = ProfileSchema.new() :: any
			big.drawTickets = 150
			t.eq(ProfileLogic.migrate(big).drawTickets, 99)
			local fine = ProfileSchema.new() :: any
			fine.drawTickets = 42
			t.eq(ProfileLogic.migrate(fine).drawTickets, 42)
			local wearing = ProfileSchema.new() :: any
			wearing.equippedSkin = "concept-uni"
			local p1, i1 = ProfileLogic.migrate(wearing)
			t.eq(p1.equippedSkin, "tamago")
			t.ok(#i1.notes >= 1)
			wearing.ownedSkins["concept-uni"] = true
			t.eq(ProfileLogic.migrate(wearing).equippedSkin, "concept-uni")
			local profile = ProfileSchema.new()
			profile.drawTickets = 5
			local view = ProfileSchema.toView(profile, true)
			t.eq(view.drawTickets, 5)
			t.eq(view.studioUnlockAll, false)
			t.eq(ProfileSchema.toView(profile, true, { vip = false, unlockAll = true }).studioUnlockAll, true)
		end
	)

	---------------------------------------------------------------- AC4 등급 확률
	t.test(
		"AC4: 실제 카탈로그 — 전설 0·빈 목록, 영웅 5/99, 희귀 15/99, 고급 30/99, 일반 49/99, 합 1",
		function()
			local rows = DrawLogic.grades()
			t.eq(#rows, 5)
			local order = {}
			local sum = 0
			for _, row in rows do
				table.insert(order, row.grade)
				sum += row.chance
				t.eq(row.duplicateCoins, Config.Draw.DuplicateCoins[row.grade], row.grade)
			end
			t.eq(order, { "Legendary", "Epic", "Rare", "Uncommon", "Common" })
			near(t, sum, 1, 1e-9, "sum")
			t.eq(gradeOf(rows, "Legendary").chance, 0)
			t.eq(gradeOf(rows, "Legendary").skinIds, {})
			near(t, gradeOf(rows, "Epic").chance, 5 / 99, 1e-9, "Epic")
			near(t, gradeOf(rows, "Rare").chance, 15 / 99, 1e-9, "Rare")
			near(t, gradeOf(rows, "Uncommon").chance, 30 / 99, 1e-9, "Uncommon")
			near(t, gradeOf(rows, "Common").chance, 49 / 99, 1e-9, "Common")
			t.eq(gradeOf(rows, "Epic").skinIds, { "concept-salmon" })
			t.eq(gradeOf(rows, "Rare").skinIds, { "concept-ikura", "concept-uni", "concept-tako" })
			t.eq(gradeOf(rows, "Uncommon").skinIds, { "concept-tuna", "concept-unagi", "concept-inari" })
			t.eq(gradeOf(rows, "Common").skinIds, { "concept-shrimp", "concept-tamago" })
			for _, row in rows do
				for _, id in row.skinIds do
					t.ok(Skins.isDraw(id) and not Skins.isFree(id), id)
				end
			end
		end
	)

	t.test(
		"AC4: 가짜 카탈로그 — 전설 1종이면 1/5/15/30/49, 영웅·전설 비우면 15/94·30/94·49/94",
		function()
			local rows = DrawLogic.grades(withLegendary() :: any)
			near(t, gradeOf(rows, "Legendary").chance, 0.01, 1e-9, "L")
			near(t, gradeOf(rows, "Epic").chance, 0.05, 1e-9, "E")
			near(t, gradeOf(rows, "Rare").chance, 0.15, 1e-9, "R")
			near(t, gradeOf(rows, "Uncommon").chance, 0.30, 1e-9, "U")
			near(t, gradeOf(rows, "Common").chance, 0.49, 1e-9, "C")
			t.eq(gradeOf(rows, "Legendary").skinIds, { MACKEREL })
			local noEpic = DrawLogic.grades(withoutEpic() :: any)
			t.eq(gradeOf(noEpic, "Epic").chance, 0)
			near(t, gradeOf(noEpic, "Rare").chance, 15 / 94, 1e-9, "R94")
			near(t, gradeOf(noEpic, "Uncommon").chance, 30 / 94, 1e-9, "U94")
			near(t, gradeOf(noEpic, "Common").chance, 49 / 94, 1e-9, "C94")
		end
	)

	---------------------------------------------------------------- AC5 표시 = 판정
	t.test(
		"AC5: displayPercents — 전설 '준비 중', 5.0/15.2/30.3/49.5 (합 정확히 100.0), 전설 있으면 1.0/5.0/15.0/30.0/49.0",
		function()
			local shown = DrawLogic.displayPercents(DrawLogic.grades())
			t.eq(shown, {
				Legendary = "준비 중",
				Epic = "5.0%",
				Rare = "15.2%",
				Uncommon = "30.3%",
				Common = "49.5%",
			})
			local total = 0
			for _, text in shown do
				local value = tonumber(string.match(text, "^([%d%.]+)%%$"))
				if value then
					total += math.floor(value * 10 + 0.5)
				end
			end
			t.eq(total, 1000)
			t.eq(DrawLogic.displayPercents(DrawLogic.grades(withLegendary() :: any)), {
				Legendary = "1.0%",
				Epic = "5.0%",
				Rare = "15.0%",
				Uncommon = "30.0%",
				Common = "49.0%",
			})
		end
	)

	t.test(
		"AC5: perSkinPercent — 연어 5.05%, 성게 5.05%, 장어 10.10%, 새우 24.75%; 표시는 grades()에서만",
		function()
			local per = DrawLogic.perSkinPercent(DrawLogic.grades())
			t.eq(per["concept-salmon"], "5.05%")
			t.eq(per["concept-uni"], "5.05%")
			t.eq(per["concept-unagi"], "10.10%")
			t.eq(per["concept-shrimp"], "24.75%")
			t.eq(per.tamago, nil)
			-- 화면도 같은 함수를 써요 (별도 확률 상수 없음)
			local screen = fs.readFile("src/client/ui/DrawScreen.luau")
			t.ok(string.find(screen, "DrawLogic.displayPercents(grades)", 1, true) ~= nil)
			t.ok(string.find(screen, "DrawLogic.perSkinPercent(grades)", 1, true) ~= nil)
			t.eq(string.find(screen, "0.49", 1, true), nil)
			t.eq(string.find(screen, "49.5", 1, true), nil)
			local logic = fs.readFile("src/shared/DrawLogic.luau")
			t.ok(string.find(logic, "Config.Draw.GradeWeights", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- AC6 판정 (가짜 rng)
	t.test(
		"AC6: 누적 경계 — 0.0505 영웅, 0.0506 희귀, 0.2020 희귀, 0.2021 고급, 0.5050 고급, 0.5051 일반, 0.9999 일반",
		function()
			local function gradeAt(value: number): string
				return (DrawLogic.roll({}, (fakeRng(value))) :: any).grade
			end
			t.eq(gradeAt(0.0505), "Epic")
			t.eq(gradeAt(0.0506), "Rare")
			t.eq(gradeAt(0.2020), "Rare")
			t.eq(gradeAt(0.2021), "Uncommon")
			t.eq(gradeAt(0.5050), "Uncommon")
			t.eq(gradeAt(0.5051), "Common")
			t.eq(gradeAt(0.9999), "Common")
			t.eq(gradeAt(EPIC - 1e-6), "Epic")
			t.eq(gradeAt(EPIC + 1e-6), "Rare")
			t.eq(gradeAt(RARE_END - 1e-6), "Rare")
			t.eq(gradeAt(RARE_END + 1e-6), "Uncommon")
			t.eq(gradeAt(UNCOMMON_END - 1e-6), "Uncommon")
			t.eq(gradeAt(UNCOMMON_END + 1e-6), "Common")
			-- 가짜 전설: 0.0099 전설
			t.eq((DrawLogic.roll({}, (fakeRng(0.0099)), withLegendary() :: any) :: any).grade, "Legendary")
		end
	)

	t.test(
		"AC6: NextInteger(1, n)대로 그 등급 스킨, 새 스킨 Skin / 가진 스킨 Duplicate + 등급 코인, 꽝 없음",
		function()
			local rng, calls = fakeRng(0.1, 3)
			local outcome = DrawLogic.roll({}, rng) :: any
			t.eq(outcome.kind, "Skin")
			t.eq(outcome.grade, "Rare")
			t.eq(outcome.skinId, "concept-tako")
			t.eq(outcome.coins, 0)
			t.eq(calls.number, 1)
			t.eq(calls.integer, 1)
			t.eq(calls.lastMax, 3)
			t.eq((DrawLogic.roll({}, (fakeRng(0.3, 2))) :: any).skinId, "concept-unagi")
			t.eq((DrawLogic.roll({}, (fakeRng(0.9, 2))) :: any).skinId, "concept-tamago")
			local cases = {
				{ 0.9, 1, "concept-shrimp", 20 },
				{ 0.3, 1, "concept-tuna", 40 },
				{ 0.1, 1, "concept-ikura", 80 },
				{ 0.01, 1, "concept-salmon", 150 },
			}
			for _, case in cases do
				local owned = { [case[3]] = true }
				local dup = DrawLogic.roll(owned, (fakeRng(case[1], case[2]))) :: any
				t.eq(dup.kind, "Duplicate", case[3])
				t.eq(dup.skinId, case[3])
				t.eq(dup.coins, case[4], case[3])
			end
			local legend = DrawLogic.roll({ [MACKEREL] = true }, (fakeRng(0.001)), withLegendary() :: any) :: any
			t.eq(legend.kind, "Duplicate")
			t.eq(legend.coins, 300)
			-- 빈 풀이면 nil
			t.eq(DrawLogic.roll({}, (fakeRng(0.5)), { Skins.get("tamago") } :: any), nil)
			t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), "Consolation", 1, true), nil)
		end
	)

	---------------------------------------------------------------- AC7 분포
	t.test(
		"AC7: 고정 시드 100,000번 — 등급 비율 ±0.005, 등급 안 스킨 1/n ±0.01; 보유 4종도 같고 가진 건 Duplicate",
		function()
			local rows = DrawLogic.grades()
			for _, ownedList in { {}, { "concept-shrimp", "concept-tuna", "concept-uni", "concept-salmon" } } do
				local owned: { [string]: boolean } = {}
				for _, id in ownedList do
					owned[id] = true
				end
				local rng = seededRng(20261014)
				local N = 100000
				local gradeCount: { [string]: number } = {}
				local skinCount: { [string]: number } = {}
				for _ = 1, N do
					local outcome = DrawLogic.roll(owned, rng) :: any
					gradeCount[outcome.grade] = (gradeCount[outcome.grade] or 0) + 1
					skinCount[outcome.skinId] = (skinCount[outcome.skinId] or 0) + 1
					if owned[outcome.skinId] then
						t.ok(outcome.kind == "Duplicate", outcome.skinId)
					elseif outcome.kind ~= "Skin" then
						t.ok(false, `{outcome.skinId} should be Skin`)
					end
				end
				for _, row in rows do
					near(t, (gradeCount[row.grade] or 0) / N, row.chance, 0.005, row.grade)
					for _, id in row.skinIds do
						near(t, (skinCount[id] or 0) / (gradeCount[row.grade] or 1), 1 / #row.skinIds, 0.01, id)
					end
				end
			end
		end
	)

	---------------------------------------------------------------- AC8 적용
	t.test("AC8: apply — 티켓 −1, Skin은 보유 + 장착·코인 그대로, Duplicate는 코인만", function()
		local w = wallet(3)
		local result = DrawLogic.apply(w, { kind = "Skin", skinId = "concept-uni", grade = "Rare", coins = 0 })
		t.eq(w.drawTickets, 2)
		t.eq(w.ownedSkins["concept-uni"], true)
		t.eq(w.equippedSkin, "tamago")
		t.eq(w.coins, 0)
		t.eq(result, { kind = "Skin", skinId = "concept-uni", grade = "Rare", coins = 0, ticketsLeft = 2 })
		local before = table.clone(w.ownedSkins)
		local dup = DrawLogic.apply(w, { kind = "Duplicate", skinId = "concept-uni", grade = "Rare", coins = 80 })
		t.eq(w.drawTickets, 1)
		t.eq(w.coins, 80)
		t.eq(w.ownedSkins, before)
		t.eq(dup, { kind = "Duplicate", skinId = "concept-uni", grade = "Rare", coins = 80, ticketsLeft = 1 })
	end)

	t.test("AC8: canDraw — 0장 NoTickets, 잠금 Locked, 저장 불가 CannotSave, 지갑 그대로", function()
		t.eq(select(2, DrawLogic.canDraw(wallet(0))), "NoTickets")
		t.eq(select(2, DrawLogic.canDraw(wallet(2), true)), "Locked")
		t.eq(select(2, DrawLogic.canDraw(wallet(2), false, false)), "CannotSave")
		t.eq(DrawLogic.canDraw(wallet(1), false, true), true)
		t.eq(DrawLogic.message("NoTickets"), "우승하면 🎫 뽑기권을 받아요")
		local w = wallet(0)
		local snapshot = table.clone(w)
		DrawLogic.canDraw(w)
		t.eq(w.drawTickets, snapshot.drawTickets)
		t.eq(w.coins, snapshot.coins)
	end)

	---------------------------------------------------------------- AC9 대표 스킨
	t.test(
		"AC9: featured — 빈 보유 연어, 연어 보유 → 희귀 첫(연어알), 다 가지면 연어, 가짜 전설이면 고등어",
		function()
			t.eq(DrawLogic.featured({}), "concept-salmon")
			t.eq(DrawLogic.featured({ ["concept-salmon"] = true }), "concept-ikura")
			local all = {}
			for _, row in SPECIAL do
				all[row[1]] = true
			end
			t.eq(DrawLogic.featured(all), "concept-salmon")
			t.eq(DrawLogic.featured({}, withLegendary() :: any), MACKEREL)
			t.eq(DrawLogic.ownedCount({ ["concept-uni"] = true, tamago = true }), 1)
		end
	)

	---------------------------------------------------------------- AC10 우승 지급
	t.test("AC10: Won만 1장(이벤트 중에도 1), Passed·결승 출발 없음, addTickets 상한 99", function()
		local tracker = RewardLogic.newTracker()
		for _, grant in RewardLogic.onRoundStart(tracker, 3, 3, { 1, 2 }, HALLOWEEN) do
			t.eq(grant.tickets, nil)
		end
		t.eq(RewardLogic.onResult(tracker, 1, "Won")[1].tickets, 1)
		t.eq(RewardLogic.onResult(tracker, 1, "Won", HALLOWEEN)[1].tickets, 1)
		t.eq(#RewardLogic.onResult(tracker, 2, "Eliminated"), 0)
		local pre = RewardLogic.newTracker()
		RewardLogic.onRoundStart(pre, 1, 3, { 1 })
		t.eq(RewardLogic.onResult(pre, 1, "Passed")[1].tickets, nil)
		t.eq(RewardLogic.matchEndPayout(nil, 100, nil).tickets, nil)
		t.eq(DrawLogic.addTickets(98, 1), 99)
		t.eq(select(2, DrawLogic.addTickets(98, 1)), 1)
		t.eq(DrawLogic.addTickets(99, 1), 99)
		t.eq(select(2, DrawLogic.addTickets(99, 1)), 0)
		t.eq(DrawLogic.addTickets(nil, 1), 1)
		t.eq(DrawLogic.addTickets(5, -10), 0)
	end)

	t.test("AC10: simulate 코인 그대로 + 티켓 합계, 토스트·정산 글씨", function()
		local events: { any } = {
			{ kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = { 1, 2, 3 } },
			{ kind = "Result", userId = 1, result = "Passed" },
			{ kind = "Result", userId = 2, result = "Passed" },
			{ kind = "Result", userId = 3, result = "Eliminated" },
			{ kind = "RoundStart", roundIndex = 3, roundCount = 3, userIds = { 1, 2 } },
			{ kind = "Result", userId = 2, result = "Eliminated" },
			{ kind = "Result", userId = 1, result = "Won" },
		}
		local coins, _tokens, tickets = RewardLogic.simulate(events)
		t.eq(coins[1], 10 + 30 + 100)
		t.eq(coins[2], 10 + 30)
		t.eq(tickets[1], 1)
		t.eq(tickets[2], nil)
		t.eq(RewardLogic.ticketToastText(1, false), "+1 🎫 우승 뽑기권")
		t.eq(RewardLogic.ticketToastText(0, true), "🎫 뽑기권이 가득 찼어요 (99장)")
		t.eq(RewardLogic.ticketToastText(nil, nil), nil)
		t.eq(RewardLogic.summaryText(140, 500, nil, nil, 1), "이번 판 +140 🍚 🎫 +1 (총 500)")
		t.eq(RewardLogic.summaryText(140, 500), "이번 판 +140 🍚 (총 500)")
		local src = fs.readFile("src/server/RewardService.luau")
		t.ok(string.find(src, "DrawLogic.addTickets(p.drawTickets, tickets)", 1, true) ~= nil)
		t.ok(string.find(src, "ticketsFull =", 1, true) ~= nil)
	end)

	---------------------------------------------------------------- AC11 Studio 전부 입기
	t.test(
		"AC11: unlockAllActive는 (true, true, false)만, canEquip은 모르는 id·잠금만 거절, 뽑기·구매는 저장 보유만",
		function()
			t.eq(ShopLogic.unlockAllActive(true, true, false), true)
			t.eq(ShopLogic.unlockAllActive(true, true, true), false)
			t.eq(ShopLogic.unlockAllActive(false, true, false), false)
			t.eq(ShopLogic.unlockAllActive(true, false, false), false)
			local owned = { tamago = true }
			for _, id in { "concept-uni", "golden-otoro", "vip-gold-tamago", "pumpkin-sushi", "salmon" } do
				t.eq(ShopLogic.canEquip(id, owned, false, true), true, id)
				t.eq(select(2, ShopLogic.canEquip(id, owned, true, true)), "Locked", id)
				t.eq(select(2, ShopLogic.canEquip(id, owned, false, false)), "NotOwned", id)
			end
			t.eq(select(2, ShopLogic.canEquip("no-such", owned, false, true)), "UnknownSkin")
			t.eq(DrawLogic.featured(owned), "concept-salmon")
			t.eq((DrawLogic.roll(owned, (fakeRng(0))) :: any).kind, "Skin")
			t.eq(ShopLogic.canBuyWithCoins("salmon", { coins = 999, ownedSkins = owned } :: any).ok, true)
			t.eq(Config.DEBUG.unlockAllSkinsInStudio, true)
			local shop = fs.readFile("src/server/ShopService.luau")
			t.ok(string.find(shop, "ShopLogic.unlockAllActive(", 1, true) ~= nil)
			t.ok(string.find(shop, "Config.DEBUG.unlockAllSkinsInStudio", 1, true) ~= nil)
			t.ok(
				string.find(
					shop,
					"ShopLogic.canEquip(skinId, profile.ownedSkins, ShopService.isLocked(player), unlockAll)",
					1,
					true
				) ~= nil
			)
			t.ok(string.find(shop, "owned = table.clone(owned)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- AC12 관리자
	t.test(
		"AC12: tickets StudioOnly, 정수 −99~99, 저장 켠 Studio·실서버 거절, AdminService에 경제 모듈 없음",
		function()
			t.eq(AdminLogic.commandTier("tickets"), "StudioOnly")
			t.eq((AdminLogic.parse("tickets", 98) :: any).amount, 98)
			t.eq((AdminLogic.parse("tickets", -99) :: any).amount, -99)
			for _, bad in { 100, -100, 1.5, "3", 0 / 0 } :: { any } do
				t.eq(select(2, AdminLogic.parse("tickets", bad)), "BadCommandArgs", tostring(bad))
			end
			t.eq(select(2, AdminLogic.canRun("StudioOnly", true, true)), "PersistOn")
			t.eq(select(2, AdminLogic.canRun("StudioOnly", false, false)), "StudioOnly")
			local service = fs.readFile("src/server/AdminService.luau")
			t.eq(string.find(service, "DrawLogic", 1, true), nil)
			t.eq(string.find(service, "DataService", 1, true), nil)
			t.ok(
				string.find(
					fs.readFile("src/server/AdminCommands.luau"),
					"DrawLogic.addTickets(profile.drawTickets, n)",
					1,
					true
				) ~= nil
			)
		end
	)

	---------------------------------------------------------------- AC13 리모트·타입·설정
	t.test("AC13: RemoteFunction 16·RemoteEvent 11, Types, Config.Draw", function()
		local src = fs.readFile("src/shared/Remotes.luau")
		local functions = string.match(src, "local FUNCTIONS = (%b{})") :: string
		local events = string.match(src, "local EVENTS = (%b{})") :: string
		local _, fnCount = string.gsub(functions, '"%w+"', "")
		local _, evCount = string.gsub(events, '"%w+"', "")
		t.eq(fnCount, 16)
		t.eq(evCount, 11)
		t.ok(string.find(functions, '"DrawTicket"', 1, true) ~= nil)
		local types = fs.readFile("src/shared/Types.luau")
		for _, needle in
			{
				'export type DrawGrade = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"',
				"drawTickets: number,",
				"studioUnlockAll: boolean,",
				"tickets: number?,",
				"ticketsFull: boolean?,",
				"export type DrawResult = {",
				'kind: "Skin" | "Duplicate",',
				"grade: DrawGrade,",
				"ticketsLeft: number,",
			}
		do
			t.ok(string.find(types, needle, 1, true) ~= nil, needle)
		end
		local sum = 0
		for _, grade in Skins.DRAW_GRADES do
			sum += Config.Draw.GradeWeights[grade]
			local coins = Config.Draw.DuplicateCoins[grade]
			t.ok(type(coins) == "number" and coins > 0 and coins % 1 == 0, grade)
		end
		near(t, sum, 1, 1e-9, "weights")
		t.eq(Config.Draw.GradeWeights, { Legendary = 0.01, Epic = 0.05, Rare = 0.15, Uncommon = 0.30, Common = 0.49 })
		t.eq(Config.Draw.DuplicateCoins, { Common = 20, Uncommon = 40, Rare = 80, Epic = 150, Legendary = 300 })
		t.eq((Config.Draw :: any).SkinChance, nil)
		t.eq((Config.Draw :: any).ConsolationCoins, nil)
		t.eq(Config.Draw.TicketsPerWin, 1)
		t.eq(Config.Draw.MaxTickets, 99)
		t.eq(Config.Draw.RequestCooldown, 1)
	end)

	t.test(
		"서버 소스: DrawTicket 인자 없음·별도 간격·update 한 번·saveNow 없음·NoPool·[Draw] 로그",
		function()
			local src = fs.readFile("src/server/ShopService.luau")
			t.ok(string.find(src, 'Remotes.fn("DrawTicket").OnServerInvoke = function(player: Player)', 1, true) ~= nil)
			t.ok(string.find(src, "Config.Draw.RequestCooldown", 1, true) ~= nil)
			local body = string.match(src, "local function onDraw.-\nend\n") :: string
			t.ok(body ~= nil, "onDraw body")
			local _, updates = string.gsub(body, "DataService.update%(", "")
			t.eq(updates, 1)
			t.eq(string.find(body, "saveNow", 1, true), nil)
			t.ok(string.find(body, '"NoPool"', 1, true) ~= nil)
			t.ok(string.find(body, "-> skin {done.skinId} {done.grade} (tickets {done.ticketsLeft})", 1, true) ~= nil)
			t.ok(string.find(body, "-> duplicate {done.skinId} {done.grade} +{done.coins}", 1, true) ~= nil)
		end
	)

	t.test(
		"판매 금지: 상품·코드·결제 어디에도 뽑기권을 주거나 파는 길이 없어요",
		function()
			for _, path in
				{
					"src/shared/Offers.luau",
					"src/shared/OfferLogic.luau",
					"src/shared/CodeLogic.luau",
					"src/server/CodeService.luau",
					"src/server/OfferService.luau",
					"src/server/RobuxShopService.luau",
					"src/shared/ReceiptLogic.luau",
				}
			do
				t.eq(string.find(fs.readFile(path), "drawTickets", 1, true), nil, path)
			end
		end
	)

	---------------------------------------------------------------- AC14 탈의실
	t.test(
		"AC14: '🎫 특' 탭은 전체 다음, 뽑기 전용 9종 order 순, 등급 탭에 없음, 전체에 있음",
		function()
			local tabs = ShopLogic.tabs(nil)
			t.eq(tabs[1].id, "all")
			t.eq(tabs[2].id, "draw")
			t.eq(tabs[2].label, "🎫 특")
			local view = { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
			local ids = {}
			for _, skin in ShopLogic.visibleSkins(view, tabs[2], nil) do
				table.insert(ids, skin.id)
			end
			t.eq(ids, {
				"concept-salmon",
				"concept-tuna",
				"concept-shrimp",
				"concept-tamago",
				"concept-ikura",
				"concept-unagi",
				"concept-uni",
				"concept-tako",
				"concept-inari",
			})
			local inAll = {}
			for _, skin in ShopLogic.visibleSkins(view, tabs[1], nil) do
				inAll[skin.id] = true
			end
			for _, row in SPECIAL do
				t.ok(inAll[row[1]], `{row[1]} in all`)
			end
			for _, tab in tabs do
				if tab.tier then
					for _, skin in ShopLogic.visibleSkins(view, tab, nil) do
						t.ok(not Skins.isDrawOnly(skin.id), `{skin.id} in {tab.id}`)
					end
				end
			end
		end
	)

	t.test(
		"AC14: 안 가진 특 스킨 'Draw'·'🎫 뽑기로 얻기', Studio 전부 입기면 '입기 (Studio)', 카드 배지 = 뽑기 등급",
		function()
			local view: any = { coins = 99999, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
			local state = ShopLogic.cardState(Skins.get("concept-uni"), view)
			t.eq(state.kind, "Draw")
			t.eq(ShopLogic.cardButtonText(state), "🎫 뽑기로 얻기")
			t.eq(ShopLogic.robuxButtonText(state), nil)
			view.studioUnlockAll = true
			for _, id in { "concept-uni", "golden-otoro", "vip-gold-tamago" } do
				local studio = ShopLogic.cardState(Skins.get(id), view)
				t.eq(studio.kind, "Equip", id)
				t.eq(ShopLogic.cardButtonText(studio), "입기 (Studio)", id)
			end
			view.ownedSkins = { "concept-uni", "tamago" }
			t.eq(ShopLogic.cardButtonText(ShopLogic.cardState(Skins.get("concept-uni"), view)), "입기")
			local screen = fs.readFile("src/client/ui/ShopScreen.luau")
			t.ok(string.find(screen, "Text = `🎫 {gradeInfo.displayName}`", 1, true) ~= nil)
		end
	)

	t.test("결과 글씨·뽑기권 글씨", function()
		t.eq(
			DrawLogic.resultText(
				{ kind = "Skin", skinId = "concept-ikura", grade = "Rare", coins = 0, ticketsLeft = 1 },
				"연어알 군함 (특)"
			),
			"🎉 연어알 군함 (특) 획득!"
		)
		t.eq(
			DrawLogic.resultText({
				kind = "Duplicate",
				skinId = "concept-ikura",
				grade = "Rare",
				coins = 80,
				ticketsLeft = 1,
			}),
			"이미 가진 스킨이에요 → 🍚 +80"
		)
		t.eq(DrawLogic.ticketText(3), "×3")
	end)
end
