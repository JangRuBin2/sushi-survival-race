--!strict
-- m4-13 탈의실 판단 (Shared.ShopLogic): 장착·코인 해금·지급·카드 상태

local RobloxRequire = require("./lib/RobloxRequire")
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
	t.test("AC3: 일반·미보유·코인 500 → ok (가격 500)", function()
		local d = ShopLogic.canBuyWithCoins("salmon", wallet(500))
		t.eq(d.ok, true)
		t.eq(d.price, 500)
	end)

	t.test("AC3: 코인 499 → 부족 (1개 모자람)", function()
		local d = ShopLogic.canBuyWithCoins("salmon", wallet(499))
		t.eq(d.ok, false)
		t.eq(d.reason, "NotEnoughCoins")
		t.eq(d.missing, 1)
		t.eq(ShopLogic.message(d.reason, d.missing), "🍚 1개 더 필요해요")
	end)

	t.test("AC3: 이미 있음 / 레어는 코인으로 못 삼 / 모르는 id", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(9999, { "salmon" })).reason, "AlreadyOwned")
		t.eq(ShopLogic.canBuyWithCoins("tamago", wallet(9999)).reason, "AlreadyOwned")
		for _, id in { "eel", "uni", "rainbow-roll", "dragon-roll" } do
			local d = ShopLogic.canBuyWithCoins(id, wallet(9999))
			t.eq(d.ok, false, id)
			t.eq(d.reason, "NotForCoins", id)
		end
		t.eq(ShopLogic.canBuyWithCoins("no-such-skin", wallet(9999)).reason, "UnknownSkin")
		t.eq(ShopLogic.canBuyWithCoins(42, wallet(9999)).reason, "UnknownSkin")
		t.eq(ShopLogic.canBuyWithCoins(nil, wallet(9999)).reason, "UnknownSkin")
	end)

	t.test("AC3: 저장이 안 되는 상태(canSave = false)면 거절, nil·true면 판단대로", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(500), false).reason, "CannotSave")
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(500), true).ok, true)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(500), nil).ok, true)
	end)

	t.test("코인 값이 이상하면(음수·NaN·무한) 0으로 봐요", function()
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(-1000)).missing, 500)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(0 / 0)).missing, 500)
		t.eq(ShopLogic.canBuyWithCoins("salmon", wallet(math.huge)).ok, false)
	end)

	---------------------------------------------------------------- 해금 실행 (DataService.update 안)
	t.test("buyWithCoins: 차감 + 보유 + 장착을 한 번에", function()
		local p = wallet(730)
		local d = ShopLogic.buyWithCoins(p, "tuna")
		t.eq(d.ok, true)
		t.eq(p.coins, 230)
		t.eq(p.ownedSkins.tuna, true)
		t.eq(p.equippedSkin, "tuna")
	end)

	t.test("buyWithCoins: 두 번 연달아 해도 한 번만 차감 (중복 방지)", function()
		local p = wallet(1200)
		t.eq(ShopLogic.buyWithCoins(p, "shrimp").ok, true)
		local second = ShopLogic.buyWithCoins(p, "shrimp")
		t.eq(second.ok, false)
		t.eq(second.reason, "AlreadyOwned")
		t.eq(p.coins, 700)
	end)

	t.test("buyWithCoins: 실패하면 프로필을 바꾸지 않아요 (음수 방지)", function()
		local p = wallet(499, nil, "tamago")
		local d = ShopLogic.buyWithCoins(p, "salmon")
		t.eq(d.ok, false)
		t.eq(p.coins, 499)
		t.eq(p.ownedSkins.salmon, nil)
		t.eq(p.equippedSkin, "tamago")
		local rare = wallet(5000)
		t.eq(ShopLogic.buyWithCoins(rare, "eel").ok, false)
		t.eq(rare.coins, 5000)
		local unsaved = wallet(500)
		t.eq(ShopLogic.buyWithCoins(unsaved, "salmon", false).ok, false)
		t.eq(unsaved.coins, 500)
	end)

	t.test("buyWithCoins: 일반 5종을 모두 사면 2500 코인", function()
		local p = wallet(2500)
		for _, skin in Skins.byTier("Common") do
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
			t.eq(ShopLogic.message(reason), "매치가 끝나면 바꿀 수 있어요")
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
		local v = view(520, { "salmon", "tamago" }, "salmon")
		local function state(id: string)
			return ShopLogic.cardState(Skins.get(id), v)
		end
		t.eq(state("salmon").kind, "Equipped")
		t.eq(ShopLogic.cardButtonText(state("salmon")), "입는 중")
		t.eq(state("tamago").kind, "Equip")
		t.eq(ShopLogic.cardButtonText(state("tamago")), "입기")
		t.eq(state("tuna").kind, "Unlock")
		t.eq(ShopLogic.cardButtonText(state("tuna")), "🍚 500으로 해금")
		t.eq(state("tuna").enabled, true)
		local poor = ShopLogic.cardState(Skins.get("tuna"), view(120, { "tamago" }, "tamago"))
		t.eq(poor.kind, "NeedCoins")
		t.eq(poor.missing, 380)
		t.eq(poor.enabled, false)
		t.eq(ShopLogic.cardButtonText(poor), "🍚 380개 더 필요해요")
		local rare = state("eel")
		t.eq(rare.kind, "Robux")
		t.eq(rare.enabled, false)
		t.eq(ShopLogic.cardButtonText(rare), "R$ 99 — 곧 열려요")
		t.eq(ShopLogic.cardButtonText(state("dragon-roll")), "R$ 399 — 곧 열려요")
	end)

	t.test("AC11: 로벅스 구매는 m4-14 전까지 꺼져 있어요", function()
		t.eq(ShopLogic.ROBUX_ENABLED, false)
	end)

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
			local text = ShopLogic.message(reason :: any)
			t.ok(type(text) == "string" and #text > 0 and text ~= "다시 해 주세요", reason)
		end
		t.eq(ShopLogic.message("CannotSave"), "저장이 안 되는 상태예요")
	end)
end
