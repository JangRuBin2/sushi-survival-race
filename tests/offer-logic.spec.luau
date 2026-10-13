--!strict
-- m5-08 특별 상품: 카탈로그(Shared.Offers)와 판단(Shared.OfferLogic)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Offers = RobloxRequire.require(Shared.Offers)
local OfferLogic = RobloxRequire.require(Shared.OfferLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Skins = RobloxRequire.require(Shared.Skins)

-- 클라이언트 보기 모양 (Types.ProfileView처럼 목록)
local function view(changes: { [string]: any }?): any
	local v: any = { ownedSkins = { "tamago" }, ownedFx = {}, boughtOffers = {}, vip = false }
	for k, value in changes or {} do
		v[k] = value
	end
	return v
end

local function offer(id: string): any
	return assert(Offers.get(id), id)
end

local function copyList(list: { any }): { any }
	local out = {}
	for i, item in list do
		out[i] = table.clone(item)
	end
	return out
end

local function hasProblem(problems: { string }, needle: string): boolean
	for _, line in problems do
		if string.find(line, needle, 1, true) then
			return true
		end
	end
	return false
end

local SAVE = { canSave = true, fake = false }

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 카탈로그
	t.test("AC1: validate(Offers.LIST) 통과, 6개, 스펙 표 가격·구성", function()
		local ok, problems = Offers.validate(Offers.LIST)
		t.ok(ok, table.concat(problems, "; "))
		t.eq(#Offers.LIST, 6)
		local expected = {
			{ "starter-pack", "Bundle", 79 },
			{ "epic-set", "Bundle", 249 },
			{ "legendary-set", "Bundle", 499 },
			{ "fx-cat-customer", "Fx", 59 },
			{ "fx-fireworks", "Fx", 99 },
			{ "vip", "Pass", 149 },
		}
		for i, row in expected do
			local o = Offers.LIST[i]
			t.eq(o.id, row[1])
			t.eq(o.kind, row[2])
			t.eq(o.robux, row[3])
			t.eq(o.order, i)
		end
		t.eq(offer("starter-pack").skins, { "salmon", "tuna", "shrimp", "eel" })
		t.eq(offer("epic-set").skins, { "rainbow-roll", "aburi-salmon", "california-roll" })
		t.eq(offer("legendary-set").skins, { "golden-otoro", "diamond-uni", "dragon-roll" })
		t.eq(offer("fx-cat-customer").fx, { "cat-customer" })
		t.eq(offer("fx-fireworks").fx, { "fireworks" })
		t.eq(offer("vip").skins, { "vip-gold-tamago" })
		t.eq(#offer("vip").perks, 3)
		t.eq(Offers.get("nope"), nil)
		t.eq(Offers.get(5), nil)
	end)

	t.test("AC1: 상품 id가 스킨 상품 id와 겹치면 잡혀요", function()
		local skins = copyList(Skins.LIST)
		for _, skin in skins do
			if skin.id == "uni" then
				skin.productId = 777
			end
		end
		local list = copyList(Offers.LIST)
		list[1].productId = 777
		local ok, problems = Offers.validate(list, skins)
		t.eq(ok, false)
		t.ok(hasProblem(problems, "productId already used by skin uni"), table.concat(problems, "; "))
		-- 상품끼리 겹침
		local list2 = copyList(Offers.LIST)
		list2[1].productId = 10
		list2[2].productId = 10
		local ok2, problems2 = Offers.validate(list2)
		t.eq(ok2, false)
		t.ok(hasProblem(problems2, "productId already used by offer starter-pack"), table.concat(problems2, "; "))
	end)

	t.test(
		"AC1: 묶음에 VIP 전용·시즌 스킨, 모르는 Fx id, 겹치는 id·order, 나쁜 가격은 잡혀요",
		function()
			local function problemsWith(edit: (list: { any }) -> ()): { string }
				local list = copyList(Offers.LIST)
				edit(list)
				local ok, problems = Offers.validate(list)
				t.eq(ok, false)
				return problems
			end
			t.ok(
				hasProblem(
					problemsWith(function(list)
						list[1].skins = { "salmon", "vip-gold-tamago" }
					end),
					"not a regular robux skin"
				),
				"vip skin in bundle"
			)
			t.ok(
				hasProblem(
					problemsWith(function(list)
						list[2].skins = { "rainbow-roll", "pumpkin-sushi" }
					end),
					"not a regular robux skin"
				),
				"season skin in bundle"
			)
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].skins = { "salmon" }
				end),
				"at least 2 skins"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].skins = { "salmon", "nope" }
				end),
				"unknown skin nope"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[4].fx = { "dancing-cat" }
				end),
				"unknown fx dancing-cat"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[2].id = "starter-pack"
				end),
				"duplicate id"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[2].order = 1
				end),
				"duplicate order"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].robux = 0
				end),
				"robux must be a positive integer"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].robux = 79.5
				end),
				"robux must be a positive integer"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[6].skins = { "salmon" }
				end),
				"must be vipOnly"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[6].productId = 55
				end),
				"passes use gamePassId"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].gamePassId = 55
				end),
				"bundles are developer products"
			))
			t.ok(hasProblem(
				problemsWith(function(list)
					list[1].kind = "Gacha"
				end),
				"kind must be"
			))
		end
	)

	t.test("AC1: forProduct·forPass·fxSlot", function()
		local list = copyList(Offers.LIST)
		t.eq(Offers.forProduct(123), nil)
		t.eq(Offers.forProduct("x"), nil)
		t.eq(Offers.forPass(456), nil)
		t.eq(Offers.fxSlot(offer("fx-cat-customer")), "Elimination")
		t.eq(Offers.fxSlot(offer("fx-fireworks")), "Victory")
		t.eq(Offers.fxSlot(offer("starter-pack")), nil)
		-- 커밋 카탈로그에는 아직 상품·패스 id가 없어요 (사용자가 채워요)
		for _, o in list do
			t.eq(o.productId, nil, `{o.id} productId empty until the user creates it`)
			t.eq(o.gamePassId, nil, `{o.id} gamePassId empty`)
		end
	end)

	---------------------------------------------------------------- AC2 visible
	t.test("AC2: 스타터 팩은 4종 중 하나라도 가졌거나 산 기록이 있으면 안 보여요", function()
		local starter = offer("starter-pack")
		t.eq(OfferLogic.visible(starter, view()), true, "new profile")
		for _, id in { "salmon", "tuna", "shrimp", "eel" } do
			t.eq(OfferLogic.visible(starter, view({ ownedSkins = { "tamago", id } })), false, `owns {id}`)
		end
		t.eq(OfferLogic.visible(starter, view({ ownedSkins = { "uni" } })), true, "other skins don't matter")
		t.eq(OfferLogic.visible(starter, view({ boughtOffers = { "starter-pack" } })), false, "bought")
		-- 서버 프로필(맵) 모양도
		local profile = ProfileSchema.new()
		t.eq(OfferLogic.visible(starter, profile), true)
		profile.ownedSkins.salmon = true
		t.eq(OfferLogic.visible(starter, profile), false)
		local profile2 = ProfileSchema.new()
		profile2.boughtOffers["starter-pack"] = 100
		t.eq(OfferLogic.visible(starter, profile2), false)
	end)

	t.test(
		"AC2: 에픽·전설 세트도 같은 규칙, 연출은 없을 때만, VIP는 vip == false일 때만",
		function()
			local epic = offer("epic-set")
			t.eq(OfferLogic.visible(epic, view()), true)
			t.eq(OfferLogic.visible(epic, view({ ownedSkins = { "aburi-salmon" } })), false)
			t.eq(OfferLogic.visible(epic, view({ boughtOffers = { "epic-set" } })), false)
			t.eq(OfferLogic.visible(epic, view({ ownedSkins = { "salmon", "golden-otoro" } })), true)
			local legend = offer("legendary-set")
			t.eq(OfferLogic.visible(legend, view({ ownedSkins = { "dragon-roll" } })), false)
			local cat = offer("fx-cat-customer")
			t.eq(OfferLogic.visible(cat, view()), true)
			t.eq(OfferLogic.visible(cat, view({ ownedFx = { "cat-customer" } })), false)
			t.eq(OfferLogic.visible(cat, view({ ownedFx = { "fireworks" } })), true)
			local vip = offer("vip")
			t.eq(OfferLogic.visible(vip, view({ vip = false })), true)
			t.eq(OfferLogic.visible(vip, view({ vip = true })), false)
			-- VIP 스킨을 이미 가졌어도(패스가 없어진 경우) VIP가 아니면 다시 살 수 있어요
			t.eq(OfferLogic.visible(vip, view({ ownedSkins = { "vip-gold-tamago" } })), true)
		end
	)

	---------------------------------------------------------------- AC3 canRequest
	t.test("AC3: canRequest 이유", function()
		local fakeOn = { canSave = false, fake = true }
		t.eq(table.pack(OfferLogic.canRequest("nope", view(), SAVE)), table.pack(false, "Unknown"))
		t.eq(table.pack(OfferLogic.canRequest(42, view(), SAVE)), table.pack(false, "Unknown"))
		t.eq(table.pack(OfferLogic.canRequest("starter-pack", nil, SAVE)), table.pack(false, "NoProfile"))
		t.eq(
			table.pack(OfferLogic.canRequest("starter-pack", view({ boughtOffers = { "starter-pack" } }), fakeOn)),
			table.pack(false, "AlreadyBought")
		)
		t.eq(
			table.pack(OfferLogic.canRequest("starter-pack", view({ ownedSkins = { "eel" } }), fakeOn)),
			table.pack(false, "OwnsSome")
		)
		t.eq(
			table.pack(OfferLogic.canRequest("fx-fireworks", view({ ownedFx = { "fireworks" } }), fakeOn)),
			table.pack(false, "AlreadyOwned")
		)
		t.eq(table.pack(OfferLogic.canRequest("vip", view({ vip = true }), fakeOn)), table.pack(false, "AlreadyVip"))
		-- 상품 id 없음: NotForSale, 가짜 결제면 통과 (저장 불가여도)
		t.eq(table.pack(OfferLogic.canRequest("starter-pack", view(), SAVE)), table.pack(false, "NotForSale"))
		t.eq(table.pack(OfferLogic.canRequest("starter-pack", view(), fakeOn)), table.pack(true, nil))
		t.eq(table.pack(OfferLogic.canRequest("vip", view(), SAVE)), table.pack(false, "NotForSale"))
		t.eq(
			table.pack(OfferLogic.canRequest("vip", view(), { canSave = true, fake = false, fakeVip = true })),
			table.pack(true, nil),
			"fake VIP mode"
		)
	end)

	t.test(
		"AC3: 상품 id가 있으면 저장 가능할 때만 (CannotSave), 패스는 저장과 상관없음",
		function()
			local starter = offer("starter-pack")
			local vip = offer("vip")
			starter.productId = 9001
			vip.gamePassId = 9002
			local ok1, r1 = OfferLogic.canRequest("starter-pack", view(), SAVE)
			local ok2, r2 = OfferLogic.canRequest("starter-pack", view(), { canSave = false, fake = false })
			local ok3, r3 = OfferLogic.canRequest("vip", view(), { canSave = false, fake = false })
			starter.productId = nil
			vip.gamePassId = nil
			t.eq(table.pack(ok1, r1), table.pack(true, nil))
			t.eq(table.pack(ok2, r2), table.pack(false, "CannotSave"))
			t.eq(table.pack(ok3, r3), table.pack(true, nil))
		end
	)

	t.test("AC3: message", function()
		t.eq(OfferLogic.message("AlreadyBought"), "이미 샀어요")
		t.eq(OfferLogic.message("OwnsSome"), "이미 가진 스킨이 있어서 따로 사야 해요")
		t.eq(OfferLogic.message("NotForSale"), "준비 중이에요")
		t.eq(OfferLogic.message(nil), "")
		for _, reason in
			{
				"Unknown",
				"AlreadyOwned",
				"AlreadyVip",
				"CannotSave",
				"NoProfile",
				"TooFast",
				"BadSlot",
				"UnknownFx",
				"WrongSlot",
				"NotOwned",
				"Locked",
			}
		do
			t.ok(OfferLogic.message(reason :: any) ~= "다시 해 주세요", reason)
		end
	end)

	---------------------------------------------------------------- AC4 valueText
	t.test("AC4: valueText", function()
		t.eq(OfferLogic.valueText(offer("starter-pack")), "따로 사면 R$ 146")
		t.eq(OfferLogic.valueText(offer("epic-set")), "따로 사면 R$ 297")
		t.eq(OfferLogic.valueText(offer("legendary-set")), "따로 사면 R$ 597")
		t.eq(OfferLogic.valueText(offer("fx-fireworks")), nil)
		t.eq(OfferLogic.valueText(offer("vip")), nil)
	end)

	---------------------------------------------------------------- 지급
	t.test("grantsFor·ownedParts·applyGrant: 묶음은 남은 것만 + boughtOffers, 장착 안 함", function()
		local starter = offer("starter-pack")
		local profile = ProfileSchema.new()
		profile.ownedSkins.tuna = true
		t.eq(OfferLogic.ownedParts(starter, profile), { "tuna" })
		t.eq(OfferLogic.grantsFor(starter, profile), { skins = { "salmon", "shrimp", "eel" }, fx = {} })
		local grants = OfferLogic.applyGrant(profile, starter, true, 1234.7)
		t.eq(grants.skins, { "salmon", "shrimp", "eel" })
		t.eq(profile.boughtOffers["starter-pack"], 1234)
		t.eq(profile.equippedSkin, "tamago", "equip flag ignored for bundles")
		t.eq(OfferLogic.delivered(starter, profile), true)
		-- 두 번째는 아무것도 안 줘요, 시각도 그대로
		local again = OfferLogic.applyGrant(profile, starter, false, 9999)
		t.eq(again, { skins = {}, fx = {} })
		t.eq(profile.boughtOffers["starter-pack"], 1234)
	end)

	t.test("applyGrant: 연출은 보유 + equip이면 그 칸 장착, equip false면 보유만", function()
		local profile = ProfileSchema.new()
		OfferLogic.applyGrant(profile, offer("fx-fireworks"), false, 1)
		t.eq(profile.ownedFx.fireworks, true)
		t.eq(profile.equippedFx.Victory, nil)
		t.eq(OfferLogic.delivered(offer("fx-fireworks"), profile), true)
		OfferLogic.applyGrant(profile, offer("fx-cat-customer"), true, 1)
		t.eq(profile.equippedFx.Elimination, "cat-customer")
		t.eq(profile.equippedFx.Victory, nil)
		t.eq(profile.boughtOffers["fx-cat-customer"], nil)
	end)

	t.test("applyGrant: VIP 패스 스킨만, 장착 안 함", function()
		local profile = ProfileSchema.new()
		local grants = OfferLogic.applyGrant(profile, offer("vip"), false, 1)
		t.eq(grants.skins, { "vip-gold-tamago" })
		t.eq(profile.ownedSkins["vip-gold-tamago"], true)
		t.eq(profile.equippedSkin, "tamago")
		t.eq(profile.boughtOffers.vip, nil)
	end)

	---------------------------------------------------------------- EquipFx
	t.test('canEquipFx: 칸·카탈로그·보유·잠금, nil·""는 벗기', function()
		local owned = view({ ownedFx = { "cat-customer" } })
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", "cat-customer", owned, false)), table.pack(true, nil))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", nil, owned, false)), table.pack(true, nil))
		t.eq(table.pack(OfferLogic.canEquipFx("Victory", "", owned, false)), table.pack(true, nil))
		t.eq(table.pack(OfferLogic.canEquipFx("Hat", "cat-customer", owned, false)), table.pack(false, "BadSlot"))
		t.eq(table.pack(OfferLogic.canEquipFx(3, nil, owned, false)), table.pack(false, "BadSlot"))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", "nope", owned, false)), table.pack(false, "UnknownFx"))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", 5, owned, false)), table.pack(false, "UnknownFx"))
		t.eq(table.pack(OfferLogic.canEquipFx("Victory", "cat-customer", owned, false)), table.pack(false, "WrongSlot"))
		t.eq(table.pack(OfferLogic.canEquipFx("Victory", "fireworks", owned, false)), table.pack(false, "NotOwned"))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", "cat-customer", owned, true)), table.pack(false, "Locked"))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", nil, owned, true)), table.pack(false, "Locked"))
		t.eq(table.pack(OfferLogic.canEquipFx("Elimination", nil, nil, false)), table.pack(false, "NoProfile"))
	end)

	---------------------------------------------------------------- 화면
	t.test(
		"cardState·buttonText·screenList: 산 상품은 아래 회색, 조건 안 맞는 묶음은 빠져요",
		function()
			local fresh = OfferLogic.screenList(view(), {})
			t.eq(#fresh, 6)
			t.eq(fresh[1].offer.id, "starter-pack")
			t.eq(fresh[1].state, { kind = "Soon", enabled = false }, "no product id yet")
			t.eq(OfferLogic.buttonText(fresh[1].state, 79), "곧 열려요")
			local fake = OfferLogic.screenList(view(), { fake = true })
			t.eq(fake[1].state, { kind = "Buy", enabled = true })
			t.eq(OfferLogic.buttonText(fake[1].state, 79), "R$ 79로 사기")
			t.eq(fake[6].offer.id, "vip")
			t.eq(fake[6].state.kind, "Soon", "fake robux does not open the pass")
			t.eq(OfferLogic.screenList(view(), { fakeVip = true })[6].state.kind, "Buy")

			local after = OfferLogic.screenList(
				view({
					ownedSkins = { "salmon", "tuna", "shrimp", "eel", "rainbow-roll" },
					boughtOffers = { "starter-pack" },
					ownedFx = { "fireworks" },
					vip = true,
				}),
				{ fake = true }
			)
			local ids = {}
			for _, entry in after do
				table.insert(ids, `{entry.offer.id}:{entry.state.kind}`)
			end
			t.eq(ids, {
				"legendary-set:Buy",
				"fx-cat-customer:Buy",
				"starter-pack:Bought",
				"fx-fireworks:Bought",
				"vip:Bought",
			}, "epic-set hidden (owns one), bought ones last")
			t.eq(OfferLogic.buttonText({ kind = "Bought", enabled = false }, 79), "산 상품")
		end
	)

	t.test("contentLines", function()
		t.eq(OfferLogic.contentLines(offer("starter-pack")), { "연어 · 참치 · 새우 · 장어" })
		t.eq(#OfferLogic.contentLines(offer("vip")), 3)
		t.eq(#OfferLogic.contentLines(offer("fx-cat-customer")), 1)
	end)
end
