--!strict
-- m5-31 QA 회귀 테스트: 개발 테스트(m5-31-draw-logic)가 다루지 않는 경계값과 서버 원칙.
--   정확한 누적 경계(`<`), rng 호출 횟수, NextInteger 범위 밖 값, roll 뒤 보유가 생긴 apply, 잘못된 티켓 값,
--   빈 등급 조합 32가지에서 표시 합 100.0%, 화면 = 서버(같은 카탈로그·같은 함수), 티켓을 바꾸는 곳 목록,
--   Studio 전부 입기가 ownedSkins를 바꾸지 않음, 클라이언트 속성으로 권한 판단 없음.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Offers = RobloxRequire.require(Shared.Offers)
local CodeLogic = RobloxRequire.require(Shared.CodeLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)

-- 실제 누적 경계: roll과 같은 순서로 grades()의 chance를 더한 값 (5/99 등과 부동소수가 조금 달라요)
local function cumulative(): { [string]: number }
	local out: { [string]: number } = {}
	local acc = 0
	for _, row in DrawLogic.grades() do
		if row.chance > 0 then
			acc += row.chance
			out[row.grade] = acc
		end
	end
	return out
end
local CUM = cumulative()
local EPIC_END = CUM.Epic
local RARE_END = CUM.Rare
local UNCOMMON_END = CUM.Uncommon

local function fakeRng(number: number, integer: number?)
	local calls = { number = 0, integer = 0, lastMin = 0, lastMax = 0 }
	local rng = {
		NextNumber = function(_): number
			calls.number += 1
			return number
		end,
		NextInteger = function(_, min: number, max: number): number
			calls.integer += 1
			calls.lastMin = min
			calls.lastMax = max
			return integer or min
		end,
	}
	return rng, calls
end

local function wallet(tickets: any, owned: { string }?): any
	local ownedSkins = { tamago = true }
	for _, id in owned or {} do
		ownedSkins[id] = true
	end
	return { coins = 0, ownedSkins = ownedSkins, equippedSkin = "tamago", drawTickets = tickets, eventTokens = {} }
end

-- 등급마다 스킨이 있게: 실제 카탈로그 + 가짜 전설 1종
local function fullCatalog(): { any }
	local list = table.clone(Skins.LIST) :: { any }
	table.insert(list, {
		id = "qa-legend",
		displayName = "QA 전설",
		tier = "Legendary",
		robux = 199,
		drawGrade = "Legendary",
		speech = { "!" },
		order = 999,
	})
	return list
end

-- grades 집합만 남긴 카탈로그 (뽑기 아닌 스킨은 그대로)
local function onlyGrades(keep: { [string]: boolean }): { any }
	local out = {}
	for _, skin in fullCatalog() do
		if skin.drawGrade == nil or keep[skin.drawGrade] then
			table.insert(out, skin)
		end
	end
	return out
end

local function percentNumber(text: string): number?
	local n = string.match(text, "^(%d+%.%d)%%$")
	return if n then tonumber(n) else nil
end

local function bodyOf(src: string, header: string): string?
	return string.match(src, header .. ".-\nend\n")
end

return function(t: Test.Test)
	---------------------------------------------------------------- 롤 경계
	t.test(
		"QA 롤: 정확한 누적값은 다음 등급(`<`), 0은 영웅(빈 전설 건너뜀), 1.0·NaN은 마지막 등급",
		function()
			local function gradeAt(value: number): string
				return (DrawLogic.roll({}, (fakeRng(value))) :: any).grade
			end
			t.ok(math.abs(EPIC_END - 5 / 99) < 1e-12, "epic end ~ 5/99")
			t.ok(math.abs(RARE_END - 20 / 99) < 1e-12, "rare end ~ 20/99")
			t.ok(math.abs(UNCOMMON_END - 50 / 99) < 1e-12, "uncommon end ~ 50/99")
			t.eq(gradeAt(0), "Epic")
			t.eq(gradeAt(EPIC_END), "Rare")
			t.eq(gradeAt(RARE_END), "Uncommon")
			t.eq(gradeAt(UNCOMMON_END), "Common")
			t.eq(gradeAt(1), "Common")
			t.eq(gradeAt(0 / 0), "Common")
			t.eq(gradeAt(-0.5), "Epic")
		end
	)

	t.test("QA 롤: NextNumber·NextInteger 한 번씩, NextInteger(1, 등급 스킨 수)", function()
		for _, case in { { 0.01, "Epic", 1 }, { 0.1, "Rare", 3 }, { 0.3, "Uncommon", 3 }, { 0.9, "Common", 2 } } do
			local rng, calls = fakeRng(case[1] :: number, 1)
			local outcome = DrawLogic.roll({}, rng) :: any
			t.eq(outcome.grade, case[2])
			t.eq(calls.number, 1, `{case[2]} NextNumber once`)
			t.eq(calls.integer, 1, `{case[2]} NextInteger once`)
			t.eq(calls.lastMin, 1)
			t.eq(calls.lastMax, case[3], `{case[2]} pool size`)
		end
	end)

	t.test("QA 롤: NextInteger가 범위 밖(0, n+5, 1.7)이어도 그 등급 안 스킨으로 잘려요", function()
		local commons = { "concept-shrimp", "concept-tamago" } -- order 순
		local low = DrawLogic.roll({}, (fakeRng(0.9, 0))) :: any
		t.eq(low.skinId, commons[1])
		local high = DrawLogic.roll({}, (fakeRng(0.9, 7))) :: any
		t.eq(high.skinId, commons[2])
		local frac = DrawLogic.roll({}, (fakeRng(0.9, 1.7))) :: any
		t.eq(frac.skinId, commons[1])
	end)

	t.test(
		"QA 롤: 뽑기 풀 = DRAW_IDS 정확히 (계란초밥·판매·시즌·VIP 스킨 없음), 꽝 kind 없음",
		function()
			local seen: { [string]: boolean } = {}
			for _, row in DrawLogic.grades() do
				for _, id in row.skinIds do
					t.ok(Skins.DRAW_IDS[id] == true, `{id} in DRAW_IDS`)
					t.ok(seen[id] == nil, `{id} once`)
					seen[id] = true
				end
			end
			for id in Skins.DRAW_IDS do
				t.ok(seen[id], `{id} in pool`)
			end
			t.eq(seen.tamago, nil)
			t.eq(seen["vip-gold-tamago"], nil)
			-- 0.0 ~ 1.0을 촘촘히: kind는 Skin/Duplicate만
			for i = 0, 200 do
				local outcome = DrawLogic.roll({ ["concept-uni"] = true }, (fakeRng(i / 200, 2))) :: any
				t.ok(outcome.kind == "Skin" or outcome.kind == "Duplicate", `kind at {i}`)
			end
		end
	)

	---------------------------------------------------------------- 적용
	t.test(
		"QA apply: roll이 Skin이었는데 그 사이 보유가 생기면 Duplicate + 그 등급 코인, 티켓 −1",
		function()
			local w = wallet(2, { "concept-salmon" })
			w.coins = 10
			local result = DrawLogic.apply(w, { kind = "Skin", skinId = "concept-salmon", grade = "Epic", coins = 0 })
			t.eq(result.kind, "Duplicate")
			t.eq(result.coins, Config.Draw.DuplicateCoins.Epic)
			t.eq(w.coins, 10 + Config.Draw.DuplicateCoins.Epic)
			t.eq(w.drawTickets, 1)
			t.eq(result.ticketsLeft, 1)
		end
	)

	t.test("QA canDraw: 티켓 NaN·음수·0.5·문자열·nil이면 NoTickets (apply 안 불림)", function()
		for _, bad in { 0 / 0, -3, 0.5, "5", false } :: { any } do
			t.eq(select(2, DrawLogic.canDraw(wallet(bad))), "NoTickets", tostring(bad))
		end
		t.eq(select(2, DrawLogic.canDraw(wallet(nil))), "NoTickets", "nil")
		-- 순서: 티켓 없음이 잠금보다 먼저 (어느 쪽이든 거절)
		t.eq(DrawLogic.canDraw(wallet(1), true, true), false)
		t.eq(DrawLogic.canDraw(wallet(1), false, false), false)
		t.eq(DrawLogic.canDraw(wallet(1), false, true), true)
	end)

	t.test(
		"QA addTickets: nil·NaN·음수 → 0부터, 99 넘는 값은 99로, 빼기는 0 아래로 안 감",
		function()
			t.eq(select(1, DrawLogic.addTickets(nil, 1)), 1)
			t.eq(select(1, DrawLogic.addTickets(0 / 0, 1)), 1)
			t.eq(select(1, DrawLogic.addTickets(-5, 1)), 1)
			local after, added = DrawLogic.addTickets(150, 1)
			t.eq(after, 99)
			t.eq(added, 0)
			local down, delta = DrawLogic.addTickets(5, -10)
			t.eq(down, 0)
			t.eq(delta, -5)
			t.eq(select(1, DrawLogic.addTickets(0, 99)), 99)
			t.eq(select(1, DrawLogic.addTickets(1, 99)), 99)
		end
	)

	---------------------------------------------------------------- 마이그레이션
	t.test(
		"QA migrate v2 → v3: drawTickets 경계 (99 유지·100→99·inf·−1·2.5·문자열·true → 0)",
		function()
			local function migrated(value: any): (number, number)
				local raw = ProfileSchema.new() :: any
				raw.version = 2
				raw.drawTickets = value
				local profile, info = ProfileLogic.migrate(raw)
				return profile.drawTickets, #info.notes
			end
			t.eq(select(1, migrated(99)), 99)
			t.eq(select(2, migrated(99)), 0)
			t.eq(select(1, migrated(100)), 99)
			t.ok(select(2, migrated(100)) > 0, "note for 100")
			for _, bad in { math.huge, -1, 2.5, "5", true } :: { any } do
				local value, notes = migrated(bad)
				t.eq(value, 0, tostring(bad))
				t.ok(notes > 0, `note for {tostring(bad)}`)
			end
			local value, notes = migrated(nil)
			t.eq(value, 0)
			t.eq(notes, 0)
			-- 다른 값 그대로
			local raw = ProfileSchema.new() :: any
			raw.version = 2
			raw.drawTickets = nil
			raw.coins = 1234
			raw.wins = 7
			raw.ownedSkins.salmon = true
			raw.ownedSkins["concept-uni"] = true
			raw.equippedSkin = "concept-uni"
			local profile, info = ProfileLogic.migrate(raw)
			t.eq(profile.version, 3)
			t.eq(profile.coins, 1234)
			t.eq(profile.wins, 7)
			t.eq(profile.ownedSkins.salmon, true)
			t.eq(profile.equippedSkin, "concept-uni")
			t.eq(info.persistable, true)
		end
	)

	---------------------------------------------------------------- 확률 표시
	t.test(
		"QA 표시: 빈 등급 조합 31가지 — chance 합 1, 표시 합 정확히 100.0, 각 표시 ±0.1 안",
		function()
			local grades = Skins.DRAW_GRADES
			for mask = 1, 31 do
				local keep: { [string]: boolean } = {}
				for i, grade in grades do
					if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then
						keep[grade] = true
					end
				end
				local rows = DrawLogic.grades(onlyGrades(keep) :: any)
				local percents = DrawLogic.displayPercents(rows)
				local chanceSum = 0
				local tenths = 0
				for _, row in rows do
					chanceSum += row.chance
					local text = percents[row.grade]
					if keep[row.grade] then
						local n = percentNumber(text)
						t.ok(n ~= nil, `mask {mask} {row.grade} '{text}'`)
						if n then
							tenths += math.floor(n * 10 + 0.5)
							t.ok(math.abs(n - row.chance * 100) <= 0.1 + 1e-9, `mask {mask} {row.grade} {n}`)
						end
					else
						t.eq(row.chance, 0)
						t.eq(text, DrawLogic.EMPTY_TEXT, `mask {mask} {row.grade} empty`)
					end
				end
				t.ok(math.abs(chanceSum - 1) <= 1e-9, `mask {mask} chance sum {chanceSum}`)
				t.eq(tenths, 1000, `mask {mask} display sum`)
			end
		end
	)

	t.test(
		"QA 표시: 스킨별 % × 스킨 수가 등급 확률과 반올림 안에서 같아요 (실제·전설 포함 카탈로그)",
		function()
			for _, list in { Skins.LIST, fullCatalog() } :: { any } do
				local rows = DrawLogic.grades(list)
				local perSkin = DrawLogic.perSkinPercent(rows)
				for _, row in rows do
					for _, id in row.skinIds do
						local n = tonumber(string.match(perSkin[id], "^(%d+%.%d%d)%%$") or "")
						t.ok(n ~= nil, `{id} '{perSkin[id]}'`)
						if n then
							t.ok(math.abs(n - row.chance / #row.skinIds * 100) <= 0.005 + 1e-9, `{id} {n}`)
						end
					end
				end
			end
		end
	)

	t.test(
		"QA 화면 = 서버: 화면은 DrawLogic.grades()·displayPercents·perSkinPercent, 서버는 같은 기본 카탈로그로 roll",
		function()
			local screen = fs.readFile("src/client/ui/DrawScreen.luau")
			t.ok(string.find(screen, "DrawLogic.grades()", 1, true) ~= nil, "screen grades()")
			t.ok(string.find(screen, "DrawLogic.displayPercents(grades)", 1, true) ~= nil, "screen displayPercents")
			t.ok(string.find(screen, "DrawLogic.perSkinPercent(grades)", 1, true) ~= nil, "screen perSkinPercent")
			-- 화면 소스에 퍼센트 숫자 상수가 없어요 (예 "5.0%", "49.5%")
			t.eq(string.match(screen, "%d+%.%d+%%"), nil, "no hardcoded percent")
			t.eq(string.find(screen, "GradeWeights", 1, true), nil, "screen does not read weights itself")
			local server = fs.readFile("src/server/ShopService.luau")
			local body = bodyOf(server, "local function onDraw") :: string
			t.ok(body ~= nil, "onDraw body")
			-- 카탈로그 인자 없이 → Skins.LIST (화면 grades()와 같은 목록)
			t.ok(string.find(body, "DrawLogic.roll(p.ownedSkins, rng)", 1, true) ~= nil, "server roll default catalog")
		end
	)

	---------------------------------------------------------------- 서버 원칙
	t.test(
		"QA 서버: onDraw는 클라이언트 인자·속성을 쓰지 않고, 판단·차감·보상이 update 안 한 번",
		function()
			local server = fs.readFile("src/server/ShopService.luau")
			local body = bodyOf(server, "local function onDraw") :: string
			t.ok(string.match(body, "^local function onDraw%(player: Player%)") ~= nil, "only player param")
			t.eq(string.find(body, "GetAttribute", 1, true), nil, "no attribute auth")
			t.ok(string.find(body, "ShopService.isLocked(player)", 1, true) ~= nil, "lock check")
			t.ok(string.find(body, "DataService.canPersist(player) or RunService:IsStudio()", 1, true) ~= nil)
			-- update 안에서 canDraw를 다시 보고 roll·apply
			local inner = string.match(body, "DataService%.update%(player, function%(p%)(.-)\n\tend%)") :: string
			t.ok(inner ~= nil, "update body")
			t.ok(string.find(inner, "DrawLogic.canDraw(p", 1, true) ~= nil, "re-check inside update")
			t.ok(string.find(inner, "DrawLogic.roll(", 1, true) ~= nil)
			t.ok(string.find(inner, "DrawLogic.apply(p, outcome)", 1, true) ~= nil)
			-- 요청 간격은 프로필 확인보다 먼저
			local cooldownAt = string.find(body, "Config.Draw.RequestCooldown", 1, true) :: number
			local profileAt = string.find(body, "DataService.get(player)", 1, true) :: number
			t.ok(cooldownAt ~= nil and profileAt ~= nil and cooldownAt < profileAt, "cooldown first")
			-- 핸들러가 인자를 넘기지 않아요
			t.ok(string.find(server, "pcall(onDraw, player)", 1, true) ~= nil, "handler passes only player")
		end
	)

	t.test(
		"QA 서버: Studio 전부 입기는 서버 설정(IsStudio·DEBUG)만, EquipSkin은 ownedSkins를 안 바꿔요",
		function()
			local server = fs.readFile("src/server/ShopService.luau")
			t.ok(
				string.find(
					server,
					"ShopLogic.unlockAllActive(\n\tRunService:IsStudio(),\n\tConfig.DEBUG.unlockAllSkinsInStudio,\n\tConfig.DEBUG.persistDataInStudio\n)",
					1,
					true
				) ~= nil,
				"unlockAll from server config"
			)
			local equip = bodyOf(server, "local function onEquip") :: string
			t.ok(equip ~= nil, "onEquip body")
			t.eq(string.find(equip, "ownedSkins[", 1, true), nil, "equip never writes ownedSkins")
			t.eq(string.find(equip, "GetAttribute", 1, true), nil)
			-- 실서버(isStudio false)는 플래그와 상관없이 꺼짐, 저장 켠 Studio도 꺼짐
			t.eq(ShopLogic.unlockAllActive(false, true, false), false)
			t.eq(ShopLogic.unlockAllActive(true, true, true), false)
			-- 켜져 있어도 코인 해금·뽑기 중복·대표는 저장 보유만 (특 스킨은 코인으로 못 삼)
			local owned = { tamago = true }
			t.eq(ShopLogic.canEquip("concept-salmon", owned, false, true), true)
			t.eq(owned["concept-salmon"], nil, "canEquip does not add ownership")
			t.eq((DrawLogic.roll(owned, (fakeRng(0.01))) :: any).kind, "Skin")
			t.eq(DrawLogic.featured(owned), "concept-salmon")
		end
	)

	t.test(
		"QA 티켓: drawTickets를 바꾸는 곳은 RewardService·AdminCommands·DrawLogic·ProfileLogic뿐",
		function()
			local allowed = {
				["src/server/RewardService.luau"] = true,
				["src/server/AdminCommands.luau"] = true,
				["src/shared/DrawLogic.luau"] = true,
				["src/shared/ProfileLogic.luau"] = true,
				["src/shared/ProfileSchema.luau"] = true, -- new()의 drawTickets = 0
			}
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.match(name, "%.luau$") then
						local src = fs.readFile(path)
						local writes = string.find(src, "drawTickets%s*[%+%-]?=[^=]")
							or string.find(src, "addTickets%(")
						if writes and string.match(path, "^src/client") == nil then
							t.ok(allowed[path] == true, `{path} changes tickets`)
						end
					end
				end
			end
			scan("src")
			-- 우승 말고는 지급 묶음에 tickets가 없어요 (결승 통과·탈락·매치 끝·코드)
			for _, round in { 1, 2, 3 } do
				local tracker = RewardLogic.newTracker()
				for _, grant in RewardLogic.onRoundStart(tracker, round, 3, { 1, 2 }) do
					t.eq((grant :: any).tickets, nil, `round start {round}`)
				end
				for _, result in { "Passed", "Eliminated" } do
					for _, grant in RewardLogic.onResult(tracker, 1, result :: any) do
						t.eq((grant :: any).tickets, nil, `{result} round {round}`)
					end
				end
			end
			local payout = RewardLogic.matchEndPayout(nil, 100) :: any
			t.ok(payout ~= nil)
			t.eq(payout.tickets, nil, "daily first match")
		end
	)

	t.test(
		"QA 지급: RewardService는 우승 티켓을 코인과 같은 update에서, 가득이면 ticketsFull",
		function()
			local src = fs.readFile("src/server/RewardService.luau")
			t.ok(string.find(src, "tickets = grantInfo.tickets", 1, true) ~= nil)
			t.ok(string.find(src, "DrawLogic.addTickets(p.drawTickets, tickets)", 1, true) ~= nil)
			t.ok(
				string.find(
					src,
					"ticketsFull = if ticketsAdded ~= nil and ticketsAdded <= 0 then true else nil",
					1,
					true
				) ~= nil
			)
			t.eq(RewardLogic.ticketToastText(0, true), "🎫 뽑기권이 가득 찼어요 (99장)")
			t.eq(RewardLogic.ticketToastText(1, false), "+1 🎫 우승 뽑기권")
			t.eq(RewardLogic.ticketToastText(nil, nil), nil)
		end
	)

	---------------------------------------------------------------- 대표 스킨
	t.test(
		"QA featured: 연어 → 연어알(희귀 order 첫) → 성게 → 문어 → 고급 첫(참치) 순",
		function()
			local owned: { [string]: boolean } = { tamago = true }
			local expected = { "concept-salmon", "concept-ikura", "concept-uni", "concept-tako", "concept-tuna" }
			for _, id in expected do
				t.eq(DrawLogic.featured(owned), id)
				owned[id] = true
			end
		end
	)

	---------------------------------------------------------------- 다른 얻는 길 없음
	t.test(
		"QA 판매 금지: 특 스킨은 묶음·VIP 패스·로벅스 결제로 못 주고, 코드 표의 tickets 칸은 버려져요",
		function()
			local bundle = table.clone(Offers.LIST) :: { any }
			table.insert(bundle, {
				id = "qa-draw-bundle",
				displayName = "QA",
				kind = "Bundle",
				robux = 99,
				skins = { "concept-salmon", "concept-uni" },
				order = 900,
			})
			local ok, problems = Offers.validate(bundle)
			t.eq(ok, false, "bundle with draw-only skins")
			t.ok(string.find(table.concat(problems, ";"), "concept-salmon", 1, true) ~= nil, "names the skin")
			local pass = table.clone(Offers.LIST) :: { any }
			table.insert(pass, {
				id = "qa-draw-pass",
				displayName = "QA",
				kind = "Pass",
				robux = 99,
				skins = { "concept-tako" },
				order = 901,
			})
			t.eq((Offers.validate(pass)), false, "pass with a draw-only skin")
			for id in Skins.DRAW_IDS do
				t.eq(
					select(2, ReceiptLogic.canRequest(id, { tamago = true }, { canSave = true, fake = true })),
					"NotRobux",
					id
				)
				t.eq(Skins.isDrawOnly(id), true, id)
			end
			-- 코드 표에 tickets를 적어도 검사된 항목에는 남지 않고, 보상은 코인·재화뿐
			local valid = CodeLogic.validateConfig({ { code = "QATICKET1", coins = 0, tickets = 5 } :: any })
			t.eq(#valid, 1)
			t.eq((valid[1] :: any).tickets, nil, "tickets field dropped")
			local reward = CodeLogic.rewardFor(valid[1], 0, function()
				return true
			end) :: any
			t.eq(reward.tickets, nil)
			t.eq(reward.drawTickets, nil)
		end
	)

	t.test(
		"QA 지급: 우승은 이벤트 기간과 상관없이 정확히 TicketsPerWin, 통과·탈락·결승 패배는 0장",
		function()
			for _, now in { 0, 1792108800 + 3600, 1796947200 + 3600 } do -- 이벤트 밖·할로윈·크리스마스
				local tracker = RewardLogic.newTracker()
				RewardLogic.onRoundStart(tracker, 3, 3, { 1, 2 })
				local grants = RewardLogic.onResult(tracker, 1, "Won", now)
				t.eq(#grants, 1)
				t.eq(grants[1].tickets, Config.Draw.TicketsPerWin, `now {now}`)
				t.eq(grants[1].reason, "Win")
			end
			-- 시뮬레이션: 통과·탈락만 있으면 티켓 없음, 우승 1번이면 1장
			local _, _, tickets = RewardLogic.simulate({
				{ kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = { 1, 2, 3, 4 } },
				{ kind = "Result", userId = 1, result = "Passed" },
				{ kind = "Result", userId = 2, result = "Eliminated" },
				{ kind = "RoundStart", roundIndex = 3, roundCount = 3, userIds = { 1, 3 } },
				{ kind = "Result", userId = 3, result = "Eliminated" },
				{ kind = "Result", userId = 1, result = "Won" },
			} :: any)
			t.eq(tickets[1], 1, "winner 1 ticket")
			t.eq(tickets[2], nil, "eliminated no ticket")
			t.eq(tickets[3], nil, "final loser no ticket")
		end
	)
end
