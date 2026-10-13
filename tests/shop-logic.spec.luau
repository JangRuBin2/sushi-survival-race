--!strict
-- m4-13 탈의실 판단 (Shared.ShopLogic): 장착·코인 해금·지급·카드 상태

local RobloxRequire = require("./lib/RobloxRequire")
local LocTest = require("./lib/LocTest")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Skins = RobloxRequire.require(Shared.Skins)

local function wallet(coins: number, owned: { string }?, equipped: string?): any
	local profile = ProfileSchema.new()
	profile.coins = coins
	for _, id in owned or {} do
		profile.ownedSkins[id] = true
	end
	if equipped then
		profile.equippedSkin = equipped
	end
	return profile
end

local function view(coins: number, owned: { string }, equipped: string): any
	return { coins = coins, ownedSkins = owned, equippedSkin = equipped }
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC3 코인 해금 판단
	t.test("AC3: 일반·미보유·코인 300 → ok (가격 300)", function()
		local d = ShopLogic.canBuyWithCoins("salmon", wallet(300))
		t.eq(d.ok, true)
		t.eq(d.price, 300)
	end)

	t.test("AC3: 코인 299 → 부족 (1개 모자람)", function()
		local d = ShopLogic.canBuyWithCoins("salmon", wallet(299))
		t.eq(d.ok, false)
		t.eq(d.reason, "NotEnoughCoins")
		t.eq(d.missing, 1)
		t.eq(LocTest.ko(ShopLogic.message(d.reason, d.missing)), "🍚 1개 더 필요해요")
	end)

	t.test("AC3: 이미 있음 / 에픽·전설은 코인으로 못 삼 / 모르는 id", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(9999, { "salmon" })).reason, "AlreadyOwned")
		t.eq(ShopLogic.canBuyWithCoins("tamago", wallet(9999)).reason, "AlreadyOwned")
		for _, id in { "rainbow-roll", "aburi-salmon", "golden-otoro", "dragon-roll" } do
			local d = ShopLogic.canBuyWithCoins(id, wallet(9999))
			t.eq(d.ok, false, id)
			t.eq(d.reason, "NotForCoins", id)
		end
		t.eq(ShopLogic.canBuyWithCoins("no-such-skin", wallet(9999)).reason, "UnknownSkin")
		t.eq(ShopLogic.canBuyWithCoins(42, wallet(9999)).reason, "UnknownSkin")
		t.eq(ShopLogic.canBuyWithCoins(nil, wallet(9999)).reason, "UnknownSkin")
	end)

	t.test("AC3: 저장이 안 되는 상태(canSave = false)면 거절, nil·true면 판단대로", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(300), false).reason, "CannotSave")
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(300), true).ok, true)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(300), nil).ok, true)
	end)

	t.test("코인 값이 이상하면(음수·NaN·무한) 0으로 봐요", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(-1000)).missing, 300)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(0 / 0)).missing, 300)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(math.huge)).ok, false)
	end)

	---------------------------------------------------------------- 해금 실행 (DataService.update 안)
	t.test("buyWithCoins: 차감 + 보유 + 장착을 한 번에", function()
		local p = wallet(530)
		local d = ShopLogic.buyWithCoins(p, "tuna")
		t.eq(d.ok, true)
		t.eq(p.coins, 230)
		t.eq(p.ownedSkins.tuna, true)
		t.eq(p.equippedSkin, "tuna")
	end)

	t.test("buyWithCoins: 두 번 연달아 해도 한 번만 차감 (중복 방지)", function()
		local p = wallet(1000)
		t.eq(ShopLogic.buyWithCoins(p, "shrimp").ok, true)
		local second = ShopLogic.buyWithCoins(p, "shrimp")
		t.eq(second.ok, false)
		t.eq(second.reason, "AlreadyOwned")
		t.eq(p.coins, 700)
	end)

	t.test("buyWithCoins: 실패하면 프로필을 바꾸지 않아요 (음수 방지)", function()
		local p = wallet(299, nil, "tamago")
		local d = ShopLogic.buyWithCoins(p, "salmon")
		t.eq(d.ok, false)
		t.eq(p.coins, 299)
		t.eq(p.ownedSkins.salmon, nil)
		t.eq(p.equippedSkin, "tamago")
		local epic = wallet(5000)
		t.eq(ShopLogic.buyWithCoins(epic, "rainbow-roll").ok, false)
		t.eq(epic.coins, 5000)
		local unsaved = wallet(300)
		t.eq(ShopLogic.buyWithCoins(unsaved, "salmon", false).ok, false)
		t.eq(unsaved.coins, 300)
	end)

	t.test("buyWithCoins: 일반 8종(m5-22 포함)을 모두 사면 2400 코인", function()
		local common = Skins.byTier("Common")
		local p = wallet(#common * Skins.COMMON_COINS)
		for _, skin in common do
			t.eq(ShopLogic.buyWithCoins(p, skin.id).ok, true, skin.id)
		end
		t.eq(p.coins, 0)
		t.eq(ShopLogic.buyWithCoins(p, "salmon").ok, false)
	end)

	---------------------------------------------------------------- AC3 장착 판단
	t.test("AC3: canEquip — 보유 → ok, 미보유 → 거절, 모르는 id → 거절", function()
		local owned = { tamago = true, salmon = true }
		t.eq(ShopLogic.canEquip("salmon", owned), true)
		t.eq(ShopLogic.canEquip("tamago", owned), true)
		local ok, reason = ShopLogic.canEquip("tuna", owned)
		t.eq(ok, false)
		t.eq(reason, "NotOwned")
		local ok2, reason2 = ShopLogic.canEquip("no-such-skin", { ["no-such-skin"] = true })
		t.eq(ok2, false)
		t.eq(reason2, "UnknownSkin")
		t.eq(ShopLogic.canEquip(nil, owned), false)
		t.eq(ShopLogic.canEquip(123, owned), false)
	end)

	t.test(
		"canEquip: 라운드·연출 중(locked)이면 거절, 문구는 '매치가 끝나면 바꿀 수 있어요'",
		function()
			local ok, reason = ShopLogic.canEquip("salmon", { salmon = true }, true)
			t.eq(ok, false)
			t.eq(reason, "Locked")
			t.eq(LocTest.ko(ShopLogic.message(reason)), "매치가 끝나면 바꿀 수 있어요")
		end
	)

	---------------------------------------------------------------- 지급 (m4-14 로벅스 결제가 씀)
	t.test(
		"grantSkin: 새로 넣으면 true, 이미 있으면 false, 모르는 id는 false. equip이면 장착",
		function()
			local p = wallet(0)
			t.eq(ShopLogic.grantSkin(p, "dragon-roll"), true)
			t.eq(p.ownedSkins["dragon-roll"], true)
			t.eq(p.equippedSkin, "tamago")
			t.eq(ShopLogic.grantSkin(p, "dragon-roll", true), false)
			t.eq(p.equippedSkin, "dragon-roll")
			t.eq(ShopLogic.grantSkin(p, "no-such-skin", true), false)
			t.eq(p.ownedSkins["no-such-skin"], nil)
			t.eq(p.coins, 0)
		end
	)

	---------------------------------------------------------------- 카드 상태 (AC6·AC11 보조)
	t.test("cardState: 입는 중 / 입기 / 코인 해금 / 코인 부족 / 로벅스(비활성)", function()
		local v = view(320, { "salmon", "tamago" }, "salmon")
		local function state(id: string)
			return ShopLogic.cardState(Skins.get(id), v)
		end
		t.eq(state("salmon").kind, "Equipped")
		t.eq(LocTest.ko(ShopLogic.cardButtonText(state("salmon"))), "입는 중")
		t.eq(state("tamago").kind, "Equip")
		t.eq(LocTest.ko(ShopLogic.cardButtonText(state("tamago"))), "입기")
		t.eq(state("tuna").kind, "Unlock")
		t.eq(LocTest.ko(ShopLogic.cardButtonText(state("tuna"))), "🍚 300 · 해금")
		t.eq(state("tuna").enabled, true)
		local poor = ShopLogic.cardState(Skins.get("tuna"), view(120, { "tamago" }, "tamago"))
		t.eq(poor.kind, "NeedCoins")
		t.eq(poor.missing, 180)
		t.eq(poor.enabled, false)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(poor)), "🍚 180개 더 필요해요")
		-- 상품 id가 없는 에픽 (사용자가 id를 채워도 이 검사는 그대로)
		local rainbow = table.clone(Skins.get("rainbow-roll")) :: any
		rainbow.productId = nil
		local epic = ShopLogic.cardState(rainbow, v)
		t.eq(epic.kind, "Robux")
		t.eq(epic.enabled, false)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(epic)), "R$ 99 — 곧 열려요")
		t.eq(ShopLogic.robuxButtonText(epic), nil, "epic has one button")
		local dragon = table.clone(Skins.get("dragon-roll")) :: any
		dragon.productId = nil
		t.eq(LocTest.ko(ShopLogic.cardButtonText(ShopLogic.cardState(dragon, v))), "R$ 199 — 곧 열려요")
	end)

	t.test("cardState: 레어 카드는 코인 해금 버튼과 R$ 버튼이 둘 다 나와요", function()
		local eel = table.clone(Skins.get("eel")) :: any
		eel.productId = nil
		local poor = ShopLogic.cardState(eel, view(320, { "tamago" }, "tamago"))
		t.eq(poor.kind, "NeedCoins")
		t.eq(poor.missing, 580)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(poor)), "🍚 580개 더 필요해요")
		t.eq(LocTest.ko(ShopLogic.robuxButtonText(poor)), "R$ 59 — 곧 열려요")
		local rich = ShopLogic.cardState(eel, view(900, { "tamago" }, "tamago"), { fake = true })
		t.eq(rich.kind, "Unlock")
		t.eq(rich.enabled, true)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(rich)), "🍚 900 · 해금")
		t.eq(rich.robuxEnabled, true)
		t.eq(LocTest.ko(ShopLogic.robuxButtonText(rich)), "R$ 59 · 사기")
	end)

	---------------------------------------------------------------- 레어 코인 해금 (900)
	t.test("레어 코인 해금: 900이면 ok, 899면 1개 부족", function()
		for _, skin in Skins.byTier("Rare") do
			if skin.season then
				continue -- 시즌 스킨은 이벤트 재화로만 (m5-03)
			end
			local d = ShopLogic.canBuyWithCoins(skin.id, wallet(900))
			t.eq(d.ok, true, skin.id)
			t.eq(d.price, 900, skin.id)
			local short = ShopLogic.canBuyWithCoins(skin.id, wallet(899))
			t.eq(short.ok, false, skin.id)
			t.eq(short.reason, "NotEnoughCoins", skin.id)
			t.eq(short.missing, 1, skin.id)
		end
	end)

	t.test("레어 코인 해금: 코인이 모자라면 프로필 그대로", function()
		local p = wallet(899, nil, "tamago")
		local d = ShopLogic.buyWithCoins(p, "uni")
		t.eq(d.ok, false)
		t.eq(d.reason, "NotEnoughCoins")
		t.eq(p.coins, 899)
		t.eq(p.ownedSkins.uni, nil)
		t.eq(p.equippedSkin, "tamago")
	end)

	t.test("레어 코인 해금: 차감 + 보유 + 장착, 두 번 해도 한 번만 차감", function()
		local p = wallet(2000)
		t.eq(ShopLogic.buyWithCoins(p, "eel").ok, true)
		t.eq(p.coins, 1100)
		t.eq(p.ownedSkins.eel, true)
		t.eq(p.equippedSkin, "eel")
		local second = ShopLogic.buyWithCoins(p, "eel")
		t.eq(second.ok, false)
		t.eq(second.reason, "AlreadyOwned")
		t.eq(p.coins, 1100)
	end)

	t.test(
		"AC11: 로벅스 버튼은 상품 id가 없으면 꺼져 있어요 (m4-14: 상품 id 또는 Studio 가짜 결제면 켜짐)",
		function()
			for _, skin in Skins.LIST do
				if skin.productId == nil then
					t.eq(ShopLogic.robuxOpen(skin), false, skin.id)
				end
			end
		end
	)

	t.test("message: 모든 거절 이유에 한국어 문구가 있어요", function()
		for _, reason in
			{
				"UnknownSkin",
				"NotOwned",
				"Locked",
				"AlreadyOwned",
				"NotForCoins",
				"NotEnoughCoins",
				"CannotSave",
				"TooFast",
				"NoProfile",
			}
		do
			local text = LocTest.ko(ShopLogic.message(reason :: any))
			t.ok(type(text) == "string" and #text > 0 and text ~= "다시 해 주세요", reason)
		end
		t.eq(LocTest.ko(ShopLogic.message("CannotSave")), "저장이 안 되는 상태예요")
	end)

	---------------------------------------------------------------- m5-07 이벤트 재화 교환·카드
	local HALLOWEEN = 1792108800
	local HALLOWEEN_END = 1793923200

	local function tokenWallet(tokens: number, owned: { string }?): any
		local w = wallet(0, owned)
		w.eventTokens["halloween-2026"] = tokens
		return w
	end

	t.test(
		"m5-07 AC3: canBuyWithTokens — 재화 80·기간 중·미보유·잠금 아님·저장 가능이면 ok",
		function()
			local d = ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80), HALLOWEEN, true, false)
			t.eq(d.ok, true)
			t.eq(d.price, 80)
			t.eq(d.eventId, "halloween-2026")
		end
	)

	t.test("m5-07 AC3: 조건이 빠지면 맞는 Reason", function()
		local d = ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(79), HALLOWEEN, true)
		t.eq(d.reason, "NeedTokens")
		t.eq(d.missing, 1)
		t.eq(LocTest.ko(ShopLogic.message(d.reason, d.missing, "🍬")), "🍬 1개 더 필요해요")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80), HALLOWEEN_END, true).reason, "EventEnded")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80), HALLOWEEN - 1, true).reason, "EventEnded")
		t.eq(
			ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80, { "ghost-tamago" }), HALLOWEEN, true).reason,
			"AlreadyOwned"
		)
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80), HALLOWEEN, true, true).reason, "Locked")
		t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", tokenWallet(80), HALLOWEEN, false).reason, "CannotSave")
		t.eq(ShopLogic.canBuyWithTokens("pumpkin-sushi", tokenWallet(999), HALLOWEEN, true).reason, "NotForTokens")
		t.eq(ShopLogic.canBuyWithTokens("salmon", tokenWallet(999), HALLOWEEN, true).reason, "NotForTokens")
		t.eq(ShopLogic.canBuyWithTokens("nope", tokenWallet(999), HALLOWEEN, true).reason, "UnknownSkin")
		t.eq(ShopLogic.canBuyWithTokens(42, tokenWallet(999), HALLOWEEN, true).reason, "UnknownSkin")
		-- 크리스마스 스킨은 할로윈 재화로 못 받아요 (기간도 아님)
		t.eq(ShopLogic.canBuyWithTokens("tree-maki", tokenWallet(999), HALLOWEEN, true).reason, "EventEnded")
		for _, reason in { "NotForTokens", "EventEnded", "NeedTokens" } do
			local text = LocTest.ko(ShopLogic.message(reason :: any))
			t.ok(#text > 0 and text ~= "다시 해 주세요", reason)
		end
	end)

	t.test(
		"m5-07 AC3: buyWithTokens 성공하면 재화 −80, 스킨 보유 + 장착 / 실패하면 그대로",
		function()
			local w = tokenWallet(85)
			local d = ShopLogic.buyWithTokens(w, "ghost-tamago", HALLOWEEN, true)
			t.eq(d.ok, true)
			t.eq(w.eventTokens["halloween-2026"], 5)
			t.eq(w.ownedSkins["ghost-tamago"], true)
			t.eq(w.equippedSkin, "ghost-tamago")
			-- 두 번째는 AlreadyOwned, 변화 없음
			local again = ShopLogic.buyWithTokens(w, "ghost-tamago", HALLOWEEN, true)
			t.eq(again.reason, "AlreadyOwned")
			t.eq(w.eventTokens["halloween-2026"], 5)
			local poor = tokenWallet(10)
			t.eq(ShopLogic.buyWithTokens(poor, "ghost-tamago", HALLOWEEN, true).ok, false)
			t.eq(poor.eventTokens["halloween-2026"], 10)
			t.eq(poor.ownedSkins["ghost-tamago"], nil)
			-- eventTokens가 없는 지갑도 에러 없이
			local bare = { coins = 0, ownedSkins = { tamago = true }, equippedSkin = "tamago" }
			t.eq(ShopLogic.canBuyWithTokens("ghost-tamago", bare :: any, HALLOWEEN, true).reason, "NeedTokens")
		end
	)

	t.test("m5-07 AC4: cardState 7가지", function()
		local function v(owned: { string }, tokens: number, equipped: string?): any
			return {
				coins = 0,
				ownedSkins = owned,
				equippedSkin = equipped or "tamago",
				eventTokens = { ["halloween-2026"] = tokens },
			}
		end
		local ghost = Skins.get("ghost-tamago")
		local pumpkin = Skins.get("pumpkin-sushi")
		local vip = Skins.get("vip-gold-tamago")
		-- 1. 재화 스킨, 기간 중, 미보유, 재화 충분
		local s1 = ShopLogic.cardState(ghost, v({ "tamago" }, 80), nil, HALLOWEEN)
		t.eq(s1.kind, "Tokens")
		t.eq(s1.enabled, true)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(s1)), "🍬 80 · 받기")
		-- 2. 재화 부족
		local s2 = ShopLogic.cardState(ghost, v({ "tamago" }, 32), nil, HALLOWEEN)
		t.eq(s2.kind, "NeedTokens")
		t.eq(s2.enabled, false)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(s2)), "🍬 32 / 80")
		-- 3. 유료 한정, 기간 중, 미보유 → 로벅스 카드
		local s3 = ShopLogic.cardState(pumpkin, v({ "tamago" }, 0), { fake = true, prices = {} }, HALLOWEEN)
		t.eq(s3.kind, "Robux")
		t.eq(s3.price, 99)
		t.eq(s3.enabled, true)
		local s3price =
			ShopLogic.cardState(pumpkin, v({ "tamago" }, 0), { prices = { ["pumpkin-sushi"] = 80 } }, HALLOWEEN)
		t.eq(s3price.price, 80, "실제 상품 가격 우선 (PriceCache)")
		-- 4. 한정, 기간 끝, 미보유 → OffSale (목록에서 숨김은 visibleSkins)
		for _, skin in { ghost, pumpkin } do
			local s4 = ShopLogic.cardState(skin, v({ "tamago" }, 999), { fake = true }, HALLOWEEN_END)
			t.eq(s4.kind, "OffSale", skin.id)
			t.eq(s4.enabled, false, skin.id)
		end
		-- 5. 한정, 보유 → 입기/입는 중 + 한정 표시 (기간 끝나도)
		local s5 = ShopLogic.cardState(ghost, v({ "tamago", "ghost-tamago" }, 0), nil, HALLOWEEN_END)
		t.eq(s5.kind, "Equip")
		t.eq(s5.limited, true)
		local s5b =
			ShopLogic.cardState(pumpkin, v({ "tamago", "pumpkin-sushi" }, 0, "pumpkin-sushi"), nil, HALLOWEEN_END)
		t.eq(s5b.kind, "Equipped")
		t.eq(s5b.limited, true)
		t.eq(
			ShopLogic.cardState(Skins.get("salmon"), v({ "tamago", "salmon" }, 0)).limited,
			nil,
			"일반 스킨은 한정 아님"
		)
		-- 6. VIP, 미보유
		local s6 = ShopLogic.cardState(vip, v({ "tamago" }, 0), { fake = true }, HALLOWEEN)
		t.eq(s6.kind, "Vip")
		t.eq(s6.enabled, false)
		t.eq(LocTest.ko(ShopLogic.cardButtonText(s6)), "👑 VIP 전용")
		-- 7. VIP, 보유
		t.eq(ShopLogic.cardState(vip, v({ "tamago", "vip-gold-tamago" }, 0)).kind, "Equip")
		t.eq(ShopLogic.cardState(vip, v({ "tamago", "vip-gold-tamago" }, 0, "vip-gold-tamago")).kind, "Equipped")
	end)

	t.test("m5-07 AC4: visibleSkins — 기간 끝 + 미보유 한정 스킨은 어느 탭에도 없음", function()
		local function ids(list: { any }): { [string]: boolean }
			local set = {}
			for _, skin in list do
				set[skin.id] = true
			end
			return set
		end
		local none = { coins = 0, ownedSkins = { "tamago" }, equippedSkin = "tamago" }
		local owner = { coins = 0, ownedSkins = { "tamago", "ghost-tamago" }, equippedSkin = "tamago" }
		for _, tab in ShopLogic.tabs(HALLOWEEN_END) do
			local set = ids(ShopLogic.visibleSkins(none, tab, HALLOWEEN_END))
			for _, id in { "pumpkin-sushi", "ghost-tamago", "santa-shrimp", "tree-maki" } do
				t.eq(set[id], nil, `{tab.id} {id}`)
			end
		end
		local all = ids(ShopLogic.visibleSkins(none, nil, HALLOWEEN_END))
		t.eq(all["salmon"], true)
		t.eq(all["vip-gold-tamago"], true, "VIP는 기간이 없어서 보여요")
		-- 가진 한정 스킨은 원래 등급 탭(레어)에 남아요
		local rareTab = { id = "Rare", label = "레어", tier = "Rare" }
		t.eq(ids(ShopLogic.visibleSkins(owner, rareTab :: any, HALLOWEEN_END))["ghost-tamago"], true)
		-- 기간 중: 이벤트 탭은 그 이벤트 스킨 2종만
		local eventTab = ShopLogic.defaultTab(HALLOWEEN)
		t.eq(eventTab.id, "event")
		local list = ShopLogic.visibleSkins(none, eventTab, HALLOWEEN)
		t.eq(#list, 2)
		local set = ids(list)
		t.eq(set["pumpkin-sushi"], true)
		t.eq(set["ghost-tamago"], true)
		-- 받기 전에는 등급 탭에 안 나오고 전체에는 나와요
		t.eq(ids(ShopLogic.visibleSkins(none, rareTab :: any, HALLOWEEN))["ghost-tamago"], nil)
		t.eq(ids(ShopLogic.visibleSkins(none, nil, HALLOWEEN))["ghost-tamago"], true)
		t.eq(ids(ShopLogic.visibleSkins(none, nil, HALLOWEEN))["tree-maki"], nil, "다른 이벤트 스킨은 숨김")
	end)

	t.test("m5-07: tabs — 이벤트 중이면 이벤트 탭이 맨 앞, 아니면 등급 탭만", function()
		local during = ShopLogic.tabs(HALLOWEEN)
		t.eq(#during, 6)
		t.eq(LocTest.ko(during[1].label), "🎃 할로윈")
		t.eq(during[1].eventId, "halloween-2026")
		t.eq(during[2].id, "all")
		local xmas = ShopLogic.tabs(1796947200)
		t.eq(LocTest.ko(xmas[1].label), "🎄 크리스마스")
		local outside = ShopLogic.tabs(HALLOWEEN_END)
		t.eq(#outside, 5)
		t.eq(outside[1].id, "all")
		t.eq(ShopLogic.defaultTab(HALLOWEEN_END).id, "all")
		t.eq(#ShopLogic.tabs(nil), 5)
	end)

	t.test("m5-07 AC5: eventHeader — 끝 11/6 00:00 UTC → '11월 5일까지', 카운트다운 없음", function()
		local Seasons = RobloxRequire.require(Shared.Seasons)
		local halloween = Seasons.get("halloween-2026")
		t.eq(LocTest.ko(ShopLogic.eventHeader(halloween, HALLOWEEN)), "할로윈 초밥 축제 · 11월 5일까지")
		t.eq(
			LocTest.ko(ShopLogic.eventHeader(halloween, HALLOWEEN, 32)),
			"할로윈 초밥 축제 · 11월 5일까지 · 🍬 32"
		)
		local christmas = Seasons.get("christmas-2026")
		t.eq(LocTest.ko(ShopLogic.lastDayText(christmas)), "1월 7일")
		-- 남은 시간과 상관없이 같은 글씨 (초·시간 표시 없음)
		t.eq(ShopLogic.eventHeader(halloween, HALLOWEEN_END - 5), ShopLogic.eventHeader(halloween, HALLOWEEN))
		-- 윤년·연말 경계
		local leap = { id = "x", name = "X", startsAt = 0, endsAt = 1709251200, token = { name = "a", icon = "a" } } -- 2024-03-01
		t.eq(LocTest.ko(ShopLogic.lastDayText(leap :: any)), "2월 29일")
		local newYear = { id = "y", name = "Y", startsAt = 0, endsAt = 1767225600, token = { name = "a", icon = "a" } } -- 2026-01-01
		t.eq(LocTest.ko(ShopLogic.lastDayText(newYear :: any)), "12월 31일")
		t.ok(string.find(LocTest.ko(ShopLogic.EVENT_NOTE), "다음 해에 다시 올 수도 있어요", 1, true) ~= nil)
	end)
end
