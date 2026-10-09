--!strict
-- m5-03 M5 두 번째 묶음 기반: 맵 풀 inPool·껍데기, 프로필 v2, ProfileView, 스킨 카탈로그 규칙, 판매 기간,
-- cue·토스트 문구, 관리자 명령 등급(실서버 = Info만), 코드 목록 로더(공개 저장소 — 로컬 파일)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Server = RobloxRequire.root("src/server")
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local Rules = RobloxRequire.require(Shared.Rules)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local CodeConfig = RobloxRequire.require(Server.CodeConfig)

-- claw-machine-prize는 m5-19가 실제 맵으로 완성해서 더 이상 껍데기가 아니에요(inPool = true로 랜덤 풀에 합류).
local SHELLS = {
	"ikura-bombs",
	"tempura-pot",
	"dessert-fridge",
	"bouncy-castle-maze",
	"lantern-bridge",
	"giant-jenga",
	"cat-cafe-shelves",
	"tug-of-war-platform",
}

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function validMap(): { [string]: any }
	return {
		id = "TestMap",
		kind = "Race",
		displayName = "테스트 맵",
		rule = "결승선까지 달려요",
		build = function() end,
		start = function() end,
	}
end

-- M4 때 저장된 v1 프로필 모양
local function v1Profile(): { [string]: any }
	return {
		version = 1,
		coins = 1234,
		wins = 12,
		matchesPlayed = 40,
		lastDailyBonusDay = 20000,
		ownedSkins = { tamago = true, salmon = true, ["golden-otoro"] = true },
		equippedSkin = "golden-otoro",
		settings = { muteLevel = 2 },
		receipts = { { id = "purchase-1", at = 100 }, { id = "purchase-2", at = 200 } },
		futureField = { keep = true },
	}
end

local function read(path: string): string
	return fs.readFile(path)
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 inPool·맵 껍데기
	t.test("AC1: validate — inPool이 boolean이 아니면 에러, false·nil은 통과", function()
		local bad = validMap()
		bad.inPool = "x"
		t.eq(MapTypes.validate(bad), "TestMap: inPool must be a boolean")
		local off = validMap()
		off.inPool = false
		t.eq(MapTypes.validate(off), nil)
		local on = validMap()
		on.inPool = true
		t.eq(MapTypes.validate(on), nil)
		t.eq(MapTypes.validate(validMap()), nil)
	end)

	t.test("AC1: 맵 15개 전부 validate 통과, 껍데기 8개는 스펙 표 그대로 + inPool = false", function()
		local expected = {
			["ikura-bombs"] = {
				"Final",
				"연어알 폭탄 접시",
				"떨어지는 연어알 폭탄을 피해 마지막까지 버텨요!",
			},
			["tempura-pot"] = {
				"Survival",
				"튀김 냄비 탈출",
				"차오르는 기름을 피해 위로! 튀는 기름도 조심!",
			},
			["dessert-fridge"] = {
				"Race",
				"디저트 냉장고",
				"미끄러운 얼음을 건너 냉장고 문까지 달려요!",
			},
			["bouncy-castle-maze"] = {
				"Race",
				"방방 미로",
				"말랑한 바닥 위를 튕기며 미로를 빠져나가요.",
			},
			["lantern-bridge"] = {
				"Race",
				"등불 다리 건너기",
				"흔들리는 다리와 종이 등불 사이를 건너요.",
			},
			["giant-jenga"] = {
				"Survival",
				"와르르 나무 블록",
				"흔들리는 블록탑 위에서 안 떨어지게 버텨요.",
			},
			["cat-cafe-shelves"] = {
				"Survival",
				"고양이 카페 캣타워",
				"흔들리는 캣타워 선반 위에서 버텨요.",
			},
			["tug-of-war-platform"] = {
				"Final",
				"줄다리기 발판",
				"발판이 기울며 한쪽 끝으로 미끄러져요.",
			},
		}
		t.eq(#Maps.allInfos(), 15)
		for _, info in Maps.allInfos() do
			local map = Maps.get(info.id)
			t.eq(MapTypes.validate(map), nil, info.id)
			local row = expected[info.id]
			if row then
				t.eq(map.kind, row[1], `{info.id} kind`)
				t.eq(map.displayName, row[2], `{info.id} name`)
				t.eq(map.rule, row[3], `{info.id} rule`)
				t.eq(map.inPool, false, `{info.id} inPool`)
			else
				t.ok(map.inPool ~= false, `{info.id} stays in the pool`)
			end
		end
		t.eq(type(Maps.get("ikura-bombs").overtime), "function")
		t.eq(type(Maps.get("tug-of-war-platform").overtime), "function")
		t.eq(type(Maps.get("claw-machine-prize").overtime), "function")
	end)

	---------------------------------------------------------------- AC2 맵 풀
	t.test("AC2: infos()는 7개(껍데기 없음, m5-19 합류), allInfos()는 15개", function()
		local ids = {}
		for _, info in Maps.infos() do
			ids[info.id] = true
		end
		t.eq(#Maps.infos(), 7)
		for _, id in SHELLS do
			t.ok(not ids[id], `{id} not in random pool`)
		end
		local all = {}
		for _, info in Maps.allInfos() do
			all[info.id] = info.kind
		end
		for _, id in SHELLS do
			t.ok(all[id] ~= nil, `{id} in allInfos`)
		end
	end)

	t.test("AC2: 강제 플랜은 allInfos로 껍데기도 그 순서대로", function()
		local plan, problem =
			Rules.resolveForcedPlan({ "dessert-fridge", "tempura-pot", "ikura-bombs" }, Maps.allInfos())
		t.eq(problem, nil)
		t.eq(plan, {
			{ id = "dessert-fridge", kind = "Race" },
			{ id = "tempura-pot", kind = "Survival" },
			{ id = "ikura-bombs", kind = "Final" },
		})
		-- 랜덤 풀(infos)로는 껍데기를 못 찾아요
		local none = Rules.resolveForcedPlan({ "dessert-fridge", "tempura-pot", "ikura-bombs" }, Maps.infos())
		t.eq(none, nil)
	end)

	t.test("AC2: buildRoundPlan을 1,000번 돌려도 껍데기가 안 나와요", function()
		local shell = {}
		for _, id in SHELLS do
			shell[id] = true
		end
		for seed = 1, 1000 do
			local roundCount = if seed % 2 == 0 then 3 else 4
			local plan = Rules.buildRoundPlan(roundCount, Maps.infos(), fakeRng(seed))
			for _, info in plan do
				t.ok(not shell[info.id], `seed {seed}: {info.id}`)
			end
		end
	end)

	t.test("MatchService 강제 플랜은 Maps.allInfos()를 써요", function()
		local match = read("src/server/MatchService.luau")
		t.ok(string.find(match, "Rules.resolveForcedPlan(ids, Maps.allInfos())", 1, true) ~= nil)
		t.ok(string.find(match, "pcall(Rules.buildRoundPlan, roundCount, Maps.infos(), Random.new())", 1, true) ~= nil)
	end)

	---------------------------------------------------------------- AC3 프로필 v2
	t.test("AC3: v1 프로필 → v2, 새 칸 5개 빈 표, 기존 값 그대로, 모르는 칸 보존", function()
		local profile, info = ProfileLogic.migrate(v1Profile())
		t.eq(info.persistable, true)
		t.eq(profile.version, 2)
		t.eq(ProfileSchema.VERSION, 2)
		t.eq(profile.coins, 1234)
		t.eq(profile.wins, 12)
		t.eq(profile.matchesPlayed, 40)
		t.eq(profile.lastDailyBonusDay, 20000)
		t.eq(profile.ownedSkins, { tamago = true, salmon = true, ["golden-otoro"] = true })
		t.eq(profile.equippedSkin, "golden-otoro")
		t.eq(profile.settings, { muteLevel = 2 })
		t.eq(profile.receipts, { { id = "purchase-1", at = 100 }, { id = "purchase-2", at = 200 } })
		t.eq((profile :: any).futureField, { keep = true })
		t.eq(profile.redeemedCodes, {})
		t.eq(profile.eventTokens, {})
		t.eq(profile.ownedFx, {})
		t.eq(profile.equippedFx, {})
		t.eq(profile.boughtOffers, {})
		t.eq(#info.notes, 0, table.concat(info.notes, "; "))
	end)

	t.test("AC3: v2 프로필을 다시 migrate해도 같아요 (저장 → 로드 왕복)", function()
		local raw = v1Profile()
		raw.version = 2
		raw.redeemedCodes = { SUSHI2026 = 1790000000 }
		raw.eventTokens = { ["halloween-2026"] = 42 }
		raw.ownedFx = { ["cat-customer"] = true, fireworks = true }
		raw.equippedFx = { Elimination = "cat-customer", Victory = "fireworks" }
		raw.boughtOffers = { ["starter-pack"] = 1790000001 }
		local profile, info = ProfileLogic.migrate(raw)
		t.eq(info.persistable, true)
		t.eq(profile.redeemedCodes, { SUSHI2026 = 1790000000 })
		t.eq(profile.eventTokens, { ["halloween-2026"] = 42 })
		t.eq(profile.ownedFx, { ["cat-customer"] = true, fireworks = true })
		t.eq(profile.equippedFx, { Elimination = "cat-customer", Victory = "fireworks" })
		t.eq(profile.boughtOffers, { ["starter-pack"] = 1790000001 })
		local again = ProfileLogic.migrate(ProfileLogic.deepCopy(profile))
		t.eq(again, profile)
	end)

	t.test("AC3: 잘못된 숫자 항목은 버리고 notes에, 소수는 내림", function()
		local raw = v1Profile()
		raw.eventTokens = { a = -1, [5] = 3, b = "x", c = 2.7 }
		local profile, info = ProfileLogic.migrate(raw)
		t.eq(profile.eventTokens, { c = 2 })
		t.ok(#info.notes >= 1)
		local raw2 = v1Profile()
		raw2.boughtOffers = { ok = 10, nan = 0 / 0, inf = math.huge }
		raw2.redeemedCodes = "nope"
		local p2, info2 = ProfileLogic.migrate(raw2)
		t.eq(p2.boughtOffers, { ok = 10 })
		t.eq(p2.redeemedCodes, {})
		t.ok(#info2.notes >= 2)
	end)

	t.test("AC3: ownedFx는 true만, equippedFx는 가진 것 + 맞는 칸만", function()
		local raw = v1Profile()
		raw.ownedFx = { ["cat-customer"] = true, fireworks = "yes", [3] = true }
		raw.equippedFx = { Elimination = "fireworks", Victory = "fireworks" }
		local profile = ProfileLogic.migrate(raw)
		t.eq(profile.ownedFx, { ["cat-customer"] = true })
		t.eq(profile.equippedFx.Elimination, nil) -- 칸이 다름
		t.eq(profile.equippedFx.Victory, nil) -- 안 가짐
		local raw2 = v1Profile()
		raw2.ownedFx = { ["cat-customer"] = true }
		raw2.equippedFx = { Elimination = "cat-customer", Victory = "no-such-fx" }
		local p2 = ProfileLogic.migrate(raw2)
		t.eq(p2.equippedFx, { Elimination = "cat-customer" })
		local raw3 = v1Profile()
		raw3.equippedFx = { Elimination = "cat-customer" } -- 안 가짐
		t.eq(ProfileLogic.migrate(raw3).equippedFx, {})
	end)

	t.test("AC3: redeemedCodes 250개는 시각이 큰 200개만", function()
		local raw = v1Profile()
		local codes = {}
		for i = 1, 250 do
			codes[`CODE{i}`] = 1790000000 + i
		end
		raw.redeemedCodes = codes
		local profile, info = ProfileLogic.migrate(raw)
		local count = 0
		for code, at in profile.redeemedCodes do
			count += 1
			t.ok(at > 1790000050, `{code} kept`)
		end
		t.eq(count, ProfileSchema.MAX_REDEEMED_CODES)
		t.eq(ProfileSchema.MAX_REDEEMED_CODES, 200)
		t.eq(profile.redeemedCodes.CODE250, 1790000250)
		t.eq(profile.redeemedCodes.CODE50, nil)
		t.ok(#info.notes >= 1)
	end)

	t.test("AC3: 미래 버전(3)은 저장하지 않아요, v1·v2는 저장", function()
		local raw = v1Profile()
		raw.version = 3
		local _, info = ProfileLogic.migrate(raw)
		t.eq(info.persistable, false)
		raw.version = 2
		t.eq(select(2, ProfileLogic.migrate(raw)).persistable, true)
	end)

	t.test("AC3: new()에 v2 칸이 있고 부를 때마다 다른 표", function()
		local a, b = ProfileSchema.new(), ProfileSchema.new()
		t.eq(a.version, 2)
		t.eq(a.redeemedCodes, {})
		t.ok(a.redeemedCodes ~= b.redeemedCodes)
		t.ok(a.eventTokens ~= b.eventTokens)
		t.ok(a.ownedFx ~= b.ownedFx)
		t.ok(a.equippedFx ~= b.equippedFx)
		t.ok(a.boughtOffers ~= b.boughtOffers)
	end)

	---------------------------------------------------------------- AC4 ProfileView
	t.test("AC4: toView 새 칸 — 이름순 목록, vip는 extra로만", function()
		local profile = ProfileSchema.new()
		profile.eventTokens = { ["halloween-2026"] = 7 }
		profile.ownedFx = { fireworks = true, ["cat-customer"] = true }
		profile.equippedFx = { Victory = "fireworks" }
		profile.boughtOffers = { ["starter-pack"] = 5, ["epic-set"] = 6 }
		local view = ProfileSchema.toView(profile, true)
		t.eq(view.vip, false)
		t.eq(view.eventTokens, { ["halloween-2026"] = 7 })
		t.ok(view.eventTokens ~= profile.eventTokens, "copied")
		t.eq(view.ownedFx, { "cat-customer", "fireworks" })
		t.eq(view.equippedFx, { Victory = "fireworks" })
		t.eq(view.boughtOffers, { "epic-set", "starter-pack" })
		t.eq(ProfileSchema.toView(profile, true, { vip = true }).vip, true)
		t.eq(ProfileSchema.toView(profile, true, { vip = false }).vip, false)
	end)

	t.test("DataService.setViewExtra가 있고 ProfileUpdated에 넘겨요", function()
		local src = read("src/server/DataService.luau")
		t.ok(
			string.find(
				src,
				"function DataService.setViewExtra(player: Player, extra: ProfileSchema.ViewExtra)",
				1,
				true
			)
		)
		t.ok(
			string.find(
				src,
				"ProfileSchema.toView(session.profile, DataService.canPersist(player), viewExtra[player])",
				1,
				true
			)
		)
		t.ok(string.find(src, "viewExtra[player] = nil", 1, true), "cleared on leave")
	end)

	---------------------------------------------------------------- AC5 스킨 카탈로그
	t.test("AC5: 21종, order 1~21, 새 5종의 얻는 길·시즌", function()
		t.eq(#Skins.LIST, 21)
		for i, skin in Skins.LIST do
			t.eq(skin.order, i)
		end
		local ok, problems = Skins.validate(Skins.LIST)
		t.ok(ok, table.concat(problems, "; "))
		local rows = {
			{ "pumpkin-sushi", "Epic", 99, nil, "halloween-2026", nil, 17 },
			{ "ghost-tamago", "Rare", nil, 80, "halloween-2026", nil, 18 },
			{ "santa-shrimp", "Epic", 99, nil, "christmas-2026", nil, 19 },
			{ "tree-maki", "Rare", nil, 80, "christmas-2026", nil, 20 },
			{ "vip-gold-tamago", "Legendary", nil, nil, nil, true, 21 },
		}
		for _, row in rows do
			local skin = Skins.get(row[1])
			t.ok(skin ~= nil, row[1])
			t.eq(skin.tier, row[2], `{row[1]} tier`)
			t.eq(skin.robux, row[3], `{row[1]} robux`)
			t.eq(skin.tokens, row[4], `{row[1]} tokens`)
			t.eq(skin.season, row[5], `{row[1]} season`)
			t.eq(skin.vipOnly, row[6], `{row[1]} vipOnly`)
			t.eq(skin.order, row[7], `{row[1]} order`)
			t.eq(skin.coins, nil, `{row[1]} coins`)
			t.eq(#skin.speech, 2, `{row[1]} speech`)
		end
	end)

	t.test("AC5: 규칙 위반 표본을 각각 잡아요", function()
		local function base(): { [string]: any }
			return table.clone(Skins.get("tamago")) :: any
		end
		local function skin(fields: { [string]: any }): { [string]: any }
			local s = {
				id = "test-skin",
				displayName = "시험",
				tier = "Rare",
				speech = { "안녕" },
				order = 99,
			}
			for k, v in fields do
				s[k] = v
			end
			return s
		end
		local cases = {
			["tokens without season"] = skin({ tokens = 80 }),
			["season skin with coins"] = skin({ robux = 99, season = "halloween-2026", coins = 900 }),
			["vipOnly with robux"] = skin({ vipOnly = true, robux = 99 }),
			["two ways (robux + tokens)"] = skin({ robux = 99, tokens = 80, season = "halloween-2026" }),
			["unknown season"] = skin({ tokens = 80, season = "summer-2030" }),
			["no way to get"] = skin({}),
			["vipOnly with season"] = skin({ vipOnly = true, season = "halloween-2026" }),
		}
		for name, bad in cases do
			local ok, problems = Skins.validate({ base(), bad :: any })
			t.eq(ok, false, name)
			t.ok(#problems >= 1, name)
		end
		-- 맞는 표본은 통과
		for _, good in
			{
				skin({ tokens = 80, season = "halloween-2026" }),
				skin({ robux = 99, season = "christmas-2026" }),
				skin({ vipOnly = true }),
				skin({ robux = 59, coins = 900 }),
			}
		do
			local ok, problems = Skins.validate({ base(), good :: any })
			t.ok(ok, table.concat(problems, "; "))
		end
	end)

	t.test("AC5: 새 스킨 5개에 자리 표시 레이아웃이 있어요", function()
		for _, id in { "pumpkin-sushi", "ghost-tamago", "santa-shrimp", "tree-maki", "vip-gold-tamago" } do
			t.ok(SushiBody.hasLayout(id), id)
		end
	end)

	t.test("AC5: 탈의실 카드 — 재화·VIP 스킨은 비활성 '곧 열려요', 에러 없음", function()
		local view = { coins = 99999, equippedSkin = "tamago", ownedSkins = { "tamago" } }
		for _, id in { "ghost-tamago", "tree-maki", "vip-gold-tamago" } do
			local state = ShopLogic.cardState(Skins.get(id), view, { fake = true })
			t.eq(state.kind, "Soon", id)
			t.eq(state.enabled, false, id)
			t.eq(ShopLogic.cardButtonText(state), "곧 열려요", id)
			t.eq(ShopLogic.robuxButtonText(state), nil, id)
		end
		for _, skin in Skins.LIST do
			local state = ShopLogic.cardState(skin, view)
			t.ok(type(ShopLogic.cardButtonText(state)) == "string", skin.id)
		end
		-- 시즌 스킨은 코인으로 못 사요
		local wallet = { coins = 99999, ownedSkins = { tamago = true }, equippedSkin = "tamago" }
		t.eq(ShopLogic.canBuyWithCoins("ghost-tamago", wallet).reason, "NotForCoins")
	end)

	---------------------------------------------------------------- AC8 판매 기간
	t.test("AC8: canRequest — 시즌 기간 밖 OffSale, 안이면 통과, 재화·VIP 스킨은 NotRobux", function()
		local owned = { tamago = true }
		local before =
			ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true, now = 1792108799 })
		t.eq(before, false)
		t.eq(
			select(
				2,
				ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true, now = 1792108799 })
			),
			"OffSale"
		)
		t.eq(ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true, now = 1792108800 }), true)
		t.eq(ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true, now = 1793923200 }), false)
		for _, id in { "ghost-tamago", "tree-maki", "vip-gold-tamago" } do
			local ok, reason = ReceiptLogic.canRequest(id, owned, { canSave = true, fake = true, now = 1792108800 })
			t.eq(ok, false, id)
			t.eq(reason, "NotRobux", id)
		end
		t.eq(ReceiptLogic.message("OffSale"), "판매 기간이 아니에요")
		t.eq(ReceiptLogic.message("NotRobux"), "로벅스로 살 수 없는 스킨이에요")
		-- now가 없으면 기간을 보지 않아요 (기존 호출)
		t.eq(ReceiptLogic.canRequest("pumpkin-sushi", owned, { canSave = true, fake = true }), true)
		-- 시즌 없는 스킨은 now와 상관없이
		t.eq(ReceiptLogic.canRequest("salmon", owned, { canSave = true, fake = true, now = 0 }), true)
	end)

	t.test("AC8: RobuxShopService가 now(Studio면 eventNow)를 넘겨요", function()
		local src = read("src/server/RobuxShopService.luau")
		t.ok(string.find(src, "now = Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())", 1, true))
	end)

	---------------------------------------------------------------- AC9 cue·토스트
	t.test("AC9: 새 cue 8개, 맵 cue 4개는 장애물 목록에, SfxLibrary와 1:1", function()
		for _, name in
			{ "IkuraPop", "OilSplash", "FanGust", "JellyBoing", "TokenGet", "CodeRedeemed", "CatMeow", "Fireworks" }
		do
			t.ok(SfxCues.isEffect(name), name)
			local entry = SfxLibrary.get(name)
			t.ok(entry ~= nil, `{name} in library`)
			t.eq(entry.id, nil, `{name} silent until the user picks an id`)
		end
		for name in SfxLibrary.Entries do
			t.ok(SfxCues.isEffect(name) or SfxCues.isMusic(name), `{name} in SfxCues`)
		end
		local chefWarn = table.find(SfxCues.Effects, "ChefHandWarn") :: number
		for _, name in { "IkuraPop", "OilSplash", "FanGust", "JellyBoing" } do
			t.ok((table.find(SfxCues.Effects, name) :: number) > chefWarn, `{name} after map cues`)
		end
	end)

	t.test("AC9: 토스트 문구 Code·MatchPlayed", function()
		t.eq(RewardLogic.REASON_TEXT.Code, "코드 보상")
		t.eq(RewardLogic.REASON_TEXT.MatchPlayed, "판 참가")
		t.eq(RewardLogic.toastText("Code", 200), "+200 🍚 코드 보상")
	end)

	---------------------------------------------------------------- 공용 파일 계약
	t.test("Remotes: 새 RemoteFunction 5개", function()
		local src = read("src/shared/Remotes.luau")
		local functions = string.match(src, "local FUNCTIONS = (%b{})") :: string
		for _, name in { "BuyWithTokens", "RequestOfferPurchase", "EquipFx", "RedeemCode", "AdminCommand" } do
			t.ok(string.find(functions, `"{name}"`, 1, true) ~= nil, name)
		end
	end)

	t.test("Attributes: Vip·EliminationFx·VictoryFx", function()
		local Attributes = RobloxRequire.require(Shared.Attributes)
		t.eq(Attributes.Vip, "Vip")
		t.eq(Attributes.EliminationFx, "EliminationFx")
		t.eq(Attributes.VictoryFx, "VictoryFx")
	end)

	t.test("Config: Events·Codes, DEBUG 기본값(eventNow nil, fakeVipInStudio false)", function()
		t.eq(Config.Events.Tokens, { MatchPlayed = 1, RoundPass = 1, FinalQualify = 2, Win = 5, DailyFirstMatch = 3 })
		t.eq(Config.Codes, { RequestCooldown = 2, MaxFailures = 8, FailureWindow = 600, MaxLength = 20 })
		t.eq(Config.DEBUG.eventNow, nil)
		t.eq(Config.DEBUG.fakeVipInStudio, false)
		t.eq(Config.DEBUG.forceMapPlan, nil)
		-- 사용자 결정 2026-10-08: 실서버에서 테스트 명령을 켜는 설정은 없어요
		t.eq((Config.DEBUG :: any).liveTestCommands, nil)
		t.eq(string.find(read("src/server/AdminConfig.luau"), "LiveTestCommands", 1, true), nil)
	end)

	t.test("init: 껍데기 서비스·컨트롤러 등록", function()
		local server = read("src/server/init.server.luau")
		local offerAt = string.find(server, "require(script.OfferService)", 1, true)
		local codeAt = string.find(server, "require(script.CodeService)", 1, true)
		local adminAt = string.find(server, "require(script.AdminService)", 1, true)
		t.ok(offerAt and codeAt and adminAt and offerAt < adminAt and codeAt < adminAt, "before AdminService")
		local client = read("src/client/init.client.luau")
		for _, name in
			{
				"script.ui.OfferController",
				"script.ui.CodeController",
				"script.ui.ChatTagController",
				"script.input.IceController",
			}
		do
			t.ok(string.find(client, `require({name})`, 1, true) ~= nil, name)
		end
	end)

	---------------------------------------------------------------- 관리자 명령 등급 (m5-11 틀)
	t.test(
		"AdminCommand 등급: 실서버는 Info만, Test·StudioOnly는 Studio에서만 (설정으로 못 켬)",
		function()
			t.eq(AdminLogic.commandTier("info"), "Info")
			t.eq(AdminLogic.commandTier("fx"), "Info")
			for _, name in { "start", "plan", "coins", "tokens" } do
				t.eq(AdminLogic.commandTier(name), "Test", name)
			end
			t.eq(AdminLogic.commandTier("resetprofile"), "StudioOnly")
			t.eq(AdminLogic.commandTier("kick"), nil)
			t.eq(AdminLogic.commandTier(5), nil)

			t.eq(AdminLogic.canRun("Info", false), true)
			t.eq(AdminLogic.canRun("Info", true), true)
			t.eq(AdminLogic.canRun("Test", false), false)
			t.eq(select(2, AdminLogic.canRun("Test", false)), "StudioOnly")
			t.eq(AdminLogic.canRun("Test", true), true)
			t.eq(AdminLogic.canRun("StudioOnly", false), false)
			t.eq(AdminLogic.canRun("StudioOnly", true, false), true)
			t.eq(select(2, AdminLogic.canRun("StudioOnly", true, true)), "PersistOn")
			t.eq(AdminLogic.message("StudioOnly"), "Studio에서만 쓸 수 있는 명령이에요")
		end
	)

	t.test("AdminService: AdminCommand 핸들러가 Studio 확인(canRun) 뒤에만 실행해요", function()
		local src = read("src/server/AdminService.luau")
		local canRunAt =
			string.find(src, "AdminLogic.canRun(tier, isStudio(), Config.DEBUG.persistDataInStudio)", 1, true)
		local runAt = string.find(src, "local ok, result = runCommand(player, name, tier, args)", 1, true)
		t.ok(canRunAt and runAt and canRunAt < runAt)
		t.ok(string.find(src, 'Remotes.fn("AdminCommand").OnServerInvoke', 1, true) ~= nil)
	end)

	---------------------------------------------------------------- 코드 목록 로더 (공개 저장소)
	t.test("CodeConfig.resolve: 파일 없음·모양 틀림이면 빈 목록 + 경고, 있으면 목록", function()
		local list, warning = CodeConfig.resolve(false, nil)
		t.eq(list, {})
		t.ok(warning ~= nil and string.find(warning, "CodeList.luau", 1, true) ~= nil)
		local bad, badWarning = CodeConfig.resolve(true, { codes = {} })
		t.eq(bad, {})
		t.ok(badWarning ~= nil)
		local failed = CodeConfig.resolve(true, nil) -- require 실패
		t.eq(failed, {})
		local fake = {
			Codes = {
				{ code = "FAKECODE1", coins = 100 },
				{ code = "FAKECODE2", coins = 50, tokens = 5, eventId = "halloween-2026", startsAt = 1, expiresAt = 2 },
				"junk",
			},
		}
		local good, none = CodeConfig.resolve(true, fake)
		t.eq(none, nil)
		t.eq(#good, 2)
		t.eq(good[1].code, "FAKECODE1")
		t.eq(good[2].eventId, "halloween-2026")
		t.ok(good[1] ~= fake.Codes[1], "copied")
	end)

	t.test("코드 목록: 실제 목록 파일은 gitignore, 커밋되는 예시는 빈 목록", function()
		local ignore = read(".gitignore")
		t.ok(string.find(ignore, "\nsrc/server/CodeList.luau\n", 1, true) ~= nil, ".gitignore has CodeList.luau")
		local example = read("src/server/CodeList.example.luau")
		t.ok(string.find(example, "Codes = {},", 1, true) ~= nil, "example list is empty")
		local loaded = (require :: any)("../src/server/CodeList.example")
		t.eq(loaded, { Codes = {} })
		t.eq(CodeConfig.LIST_NAME, "CodeList")
	end)
end
