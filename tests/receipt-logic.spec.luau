--!strict
-- m4-14 로벅스 결제 판단 (Shared.ReceiptLogic): decide, process(가짜 저장소), 구매 요청 검사, 처리한 결제 id 목록

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Skins = RobloxRequire.require(Shared.Skins)

-- 가짜 서버: 메모리 프로필 + "저장된" 프로필 + 구매 기록. 실패를 켜고 끌 수 있어요.
type World = {
	present: boolean,
	ready: boolean,
	profile: any, -- 서버 메모리의 프로필
	saved: any, -- 마지막으로 저장에 성공한 프로필 사본
	log: { [string]: any },
	failSave: boolean,
	failRecord: boolean,
	failLookup: boolean,
	saves: number,
	grants: number,
	skinOf: { [number]: string },
}

local function newWorld(): World
	local profile = ProfileSchema.new()
	return {
		present = true,
		ready = true,
		profile = profile,
		saved = ProfileLogic.deepCopy(profile),
		log = {},
		failSave = false,
		failRecord = false,
		failLookup = false,
		saves = 0,
		grants = 0,
		skinOf = { [1001] = "uni", [1002] = "salmon" },
	}
end

local function portFor(w: World, receipt: any): any
	return {
		hasPlayer = function()
			return w.present
		end,
		skinFor = function()
			return w.skinOf[receipt.ProductId]
		end,
		profileReady = function()
			return w.present and w.ready
		end,
		owns = function(skinId: string)
			return w.profile.ownedSkins[skinId] == true
		end,
		hasReceipt = function(id: string)
			return ReceiptLogic.hasReceipt(w.profile.receipts, id)
		end,
		lookupRecord = function(id: string)
			if w.failLookup then
				return nil
			end
			return w.log[id] ~= nil
		end,
		grant = function(skinId: string, equip: boolean)
			if ShopLogic.grantSkin(w.profile, skinId, equip) then
				w.grants += 1
			end
			return true
		end,
		rememberReceipt = function(id: string)
			ReceiptLogic.remember(w.profile.receipts, id, 100, Config.Shop.ReceiptHistoryMax)
			return true
		end,
		save = function()
			if w.failSave then
				return false
			end
			w.saves += 1
			w.saved = ProfileLogic.deepCopy(w.profile)
			return true
		end,
		writeRecord = function(id: string, record: any)
			if w.failRecord then
				return false
			end
			if w.log[id] == nil then
				w.log[id] = record
			end
			return true
		end,
		now = function()
			return 12345
		end,
	}
end

local function receipt(purchaseId: string, productId: number?): any
	return { PlayerId = 7, ProductId = productId or 1001, PurchaseId = purchaseId }
end

local function run(w: World, r: any): any
	return ReceiptLogic.process(r, portFor(w, r))
end

local function countKeys(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 decide
	t.test("AC1: decide 판단 순서", function()
		local base = { playerPresent = true, skinId = "uni", profileReady = true, recorded = false, owned = false }
		local function with(changes: { [string]: any }): any
			local s = table.clone(base) :: any
			for k, v in changes do
				s[k] = v
			end
			return s
		end
		t.eq(ReceiptLogic.decide(with({})), "GrantAndRecord")
		t.eq(ReceiptLogic.decide(with({ playerPresent = false })), "NotProcessedYet", "no player")
		local unknown = with({})
		unknown.skinId = nil
		t.eq(ReceiptLogic.decide(unknown), "NotProcessedYet", "unknown product")
		t.eq(ReceiptLogic.decide(with({ profileReady = false })), "NotProcessedYet", "no profile / cannot persist")
		local unread = with({})
		unread.recorded = nil
		t.eq(ReceiptLogic.decide(unread), "NotProcessedYet", "log read failed")
		t.eq(ReceiptLogic.decide(with({ recorded = true })), "AlreadyRecorded")
		t.eq(ReceiptLogic.decide(with({ recorded = true, owned = true })), "AlreadyRecorded")
		t.eq(ReceiptLogic.decide(with({ owned = true })), "RecordOnly")
		-- 플레이어 없음이 가장 먼저 (다른 값이 뭐든)
		t.eq(ReceiptLogic.decide(with({ playerPresent = false, recorded = true })), "NotProcessedYet")
	end)

	t.test(
		"AC1: process — 플레이어 없음·모르는 상품·프로필 준비 안 됨은 NotProcessedYet, 아무것도 바꾸지 않아요",
		function()
			local w = newWorld()
			w.present = false
			t.eq(run(w, receipt("p1")).result, "NotProcessedYet")
			w.present = true
			local unknown = run(w, receipt("p2", 9999))
			t.eq(unknown.result, "NotProcessedYet")
			t.eq(unknown.skinId, nil)
			w.ready = false
			t.eq(run(w, receipt("p3")).result, "NotProcessedYet")
			w.ready = true
			w.failLookup = true
			t.eq(run(w, receipt("p4")).result, "NotProcessedYet", "log read failed")
			t.eq(w.profile.ownedSkins.uni, nil)
			t.eq(countKeys(w.log), 0)
			t.eq(w.saves, 0)
		end
	)

	t.test("AC1: process — 처음 결제는 지급 + 장착 + 저장 + 기록 → PurchaseGranted", function()
		local w = newWorld()
		local out = run(w, receipt("p1"))
		t.eq(out.result, "PurchaseGranted")
		t.eq(out.verdict, "GrantAndRecord")
		t.eq(out.granted, true)
		t.eq(w.saved.ownedSkins.uni, true, "saved profile has the skin")
		t.eq(w.saved.equippedSkin, "uni", "worn right away")
		t.eq(ReceiptLogic.hasReceipt(w.saved.receipts, "p1"), true, "purchase id saved in profile")
		t.eq(w.log.p1, { userId = 7, productId = 1001, skinId = "uni", at = 12345 })
	end)

	t.test(
		"AC1: process — 기록 없음 + 이미 보유(다른 서버에서 또 산 경우)는 기록만 → PurchaseGranted",
		function()
			local w = newWorld()
			w.profile.ownedSkins.uni = true
			local out = run(w, receipt("p9"))
			t.eq(out.verdict, "RecordOnly")
			t.eq(out.result, "PurchaseGranted")
			t.eq(out.granted, false)
			t.ok(string.find(out.note, "already owned", 1, true) ~= nil, "warning note")
			t.ok(w.log.p9 ~= nil)
			t.eq(w.grants, 0)
		end
	)

	---------------------------------------------------------------- AC2 저장 실패
	t.test(
		"AC2: 저장이 실패하면 NotProcessedYet, 기록 없음. 다시 부르면 스킨은 한 번만 + PurchaseGranted",
		function()
			local w = newWorld()
			w.failSave = true
			local first = run(w, receipt("p1"))
			t.eq(first.result, "NotProcessedYet")
			t.eq(first.verdict, "GrantAndRecord")
			t.eq(countKeys(w.log), 0, "no record before a successful save")
			t.eq(w.saved.ownedSkins.uni, nil, "nothing saved")
			-- 같은 서버에서 다시 (메모리 프로필엔 이미 들어가 있음)
			w.failSave = false
			local second = run(w, receipt("p1"))
			t.eq(second.result, "PurchaseGranted")
			t.eq(second.verdict, "RecordOnly")
			t.eq(w.grants, 1, "granted once")
			t.eq(w.saved.ownedSkins.uni, true, "saved on retry")
			t.ok(w.log.p1 ~= nil)
			t.ok(string.find(second.note, "retry", 1, true) ~= nil, "retry note (not a warning)")
		end
	)

	t.test(
		"AC2: 저장 실패 뒤 다른 서버(저장된 프로필에서 다시 로드)에서 다시 부르면 그때 지급",
		function()
			local w = newWorld()
			w.failSave = true
			t.eq(run(w, receipt("p1")).result, "NotProcessedYet")
			-- 서버가 꺼져 메모리 프로필은 사라지고 저장된 값으로 다시 로드
			w.profile = ProfileLogic.deepCopy(w.saved)
			w.failSave = false
			w.grants = 0
			local again = run(w, receipt("p1"))
			t.eq(again.result, "PurchaseGranted")
			t.eq(again.verdict, "GrantAndRecord")
			t.eq(w.grants, 1)
			t.eq(w.saved.ownedSkins.uni, true)
		end
	)

	---------------------------------------------------------------- AC3 기록 실패
	t.test(
		"AC3: 기록 저장이 실패하면 NotProcessedYet, 다시 부르면 RecordOnly → PurchaseGranted, 중복 없음",
		function()
			local w = newWorld()
			w.failRecord = true
			local first = run(w, receipt("p1"))
			t.eq(first.result, "NotProcessedYet")
			t.eq(w.saved.ownedSkins.uni, true, "profile saved before the record")
			w.failRecord = false
			local second = run(w, receipt("p1"))
			t.eq(second.verdict, "RecordOnly")
			t.eq(second.result, "PurchaseGranted")
			t.eq(w.grants, 1, "skin granted once")
			t.eq(#w.profile.receipts, 1, "purchase id remembered once")
			-- 세 번째(이미 기록됨)도 그대로
			local third = run(w, receipt("p1"))
			t.eq(third.verdict, "AlreadyRecorded")
			t.eq(third.result, "PurchaseGranted")
			t.eq(w.grants, 1)
		end
	)

	t.test("AC3: 기록은 있는데 프로필에 스킨이 없으면 다시 넣고 저장돼야 완료", function()
		local w = newWorld()
		w.log.p1 = { userId = 7, productId = 1001, skinId = "uni", at = 1 }
		w.failSave = true
		t.eq(run(w, receipt("p1")).result, "NotProcessedYet")
		w.failSave = false
		local out = run(w, receipt("p1"))
		t.eq(out.verdict, "AlreadyRecorded")
		t.eq(out.result, "PurchaseGranted")
		t.eq(w.saved.ownedSkins.uni, true)
		t.eq(w.saved.equippedSkin, "tamago", "restored, not force-worn")
	end)

	t.test(
		"가짜 저장소: 같은 PurchaseId를 여러 번 + 다른 결제 섞어도 스킨·기록은 결제당 하나",
		function()
			local w = newWorld()
			for _ = 1, 3 do
				t.eq(run(w, receipt("a")).result, "PurchaseGranted")
				t.eq(run(w, receipt("b", 1002)).result, "PurchaseGranted")
			end
			t.eq(w.grants, 2)
			t.eq(countKeys(w.log), 2)
			t.eq(#w.profile.receipts, 2)
			t.eq(w.profile.equippedSkin, "salmon")
		end
	)

	---------------------------------------------------------------- AC4 카탈로그
	t.test(
		"AC4: productId가 겹치는 스킨이 없어요 (nil 제외), 기본 스킨은 상품이 없어요",
		function()
			local seen: { [number]: string } = {}
			for _, skin in Skins.LIST do
				local pid = skin.productId
				if pid ~= nil then
					t.eq(seen[pid], nil, `{skin.id} duplicates {seen[pid]}`)
					seen[pid] = skin.id
				end
			end
			t.eq((Skins.get(Skins.DEFAULT_ID) :: any).productId, nil)
			local dup = table.clone(Skins.LIST) :: any
			dup[2] = table.clone(dup[2])
			dup[3] = table.clone(dup[3])
			dup[2].productId = 555
			dup[3].productId = 555
			local ok, problems = Skins.validate(dup)
			t.eq(ok, false)
			t.ok(string.find(table.concat(problems, ";"), "duplicate productId", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 구매 요청 검사
	t.test(
		"canRequest: 미보유·상품 id·저장 가능해야, Studio 가짜 결제는 상품 id·저장과 무관",
		function()
			local owned = { tamago = true, uni = true }
			local real = { canSave = true, fake = false }
			t.eq(ReceiptLogic.canRequest("uni", owned, real), false)
			t.eq(select(2, ReceiptLogic.canRequest("uni", owned, real)), "AlreadyOwned")
			t.eq(select(2, ReceiptLogic.canRequest("tamago", owned, real)), "AlreadyOwned")
			t.eq(select(2, ReceiptLogic.canRequest("nope", owned, real)), "UnknownSkin")
			t.eq(select(2, ReceiptLogic.canRequest(42, owned, real)), "UnknownSkin")
			t.eq(select(2, ReceiptLogic.canRequest("eel", nil, real)), "NoProfile")
			-- 상품 id가 없는 스킨 (사용자가 id를 채워도 이 검사는 복제본으로)
			local eel = Skins.get("eel") :: any
			local saved = eel.productId
			eel.productId = nil
			t.eq(select(2, ReceiptLogic.canRequest("eel", owned, real)), "NotForSale")
			t.eq(ReceiptLogic.canRequest("eel", owned, { canSave = false, fake = true }), true, "studio fake")
			eel.productId = 777
			t.eq(ReceiptLogic.canRequest("eel", owned, real), true)
			t.eq(select(2, ReceiptLogic.canRequest("eel", owned, { canSave = false, fake = false })), "CannotSave")
			eel.productId = saved
			-- 일반 스킨도 로벅스로 살 수 있어요 (GDD 9.2)
			t.eq(ReceiptLogic.canRequest("salmon", owned, { canSave = false, fake = true }), true)
		end
	)

	t.test("message: 거절 문구 (스펙 문구 그대로)", function()
		t.eq(ReceiptLogic.message("AlreadyOwned"), "이미 있어요")
		t.eq(ReceiptLogic.message("CannotSave"), "저장이 안 되는 상태라 지금은 살 수 없어요")
		t.eq(ReceiptLogic.message("NotForSale"), "준비 중이에요")
		for _, reason in { "UnknownSkin", "NoProfile", "TooFast" } do
			local text = ReceiptLogic.message(reason :: any)
			t.ok(#text > 0 and text ~= "다시 해 주세요", reason)
		end
	end)

	---------------------------------------------------------------- 처리한 결제 id 목록
	t.test("remember: 중복 없이 끝에 더하고 max개만 (오래된 것부터 지움)", function()
		local h = {}
		ReceiptLogic.remember(h, "a", 1, 3)
		ReceiptLogic.remember(h, "a", 2, 3)
		t.eq(#h, 1)
		ReceiptLogic.remember(h, "b", 2, 3)
		ReceiptLogic.remember(h, "c", 3, 3)
		ReceiptLogic.remember(h, "d", 4, 3)
		t.eq(#h, 3)
		t.eq(ReceiptLogic.hasReceipt(h, "a"), false, "oldest dropped")
		t.eq(ReceiptLogic.hasReceipt(h, "d"), true)
		t.eq(h[1].id, "b")
	end)

	t.test("sanitizeHistory + migrate: 잘못된 항목은 버리고 시각 순 최근 max개", function()
		local raw = {
			{ id = "x", at = 5 },
			{ id = "y", at = 1 },
			{ id = "x", at = 9 }, -- 같은 id는 처음 것만
			{ id = "", at = 2 },
			{ id = 3, at = 2 },
			{ id = "z", at = 0 / 0 },
			"junk",
		}
		t.eq(ReceiptLogic.sanitizeHistory(raw, 10), { { id = "y", at = 1 }, { id = "x", at = 5 } })
		t.eq(ReceiptLogic.sanitizeHistory("nope", 10), {})
		local many = {}
		for i = 1, Config.Shop.ReceiptHistoryMax + 5 do
			table.insert(many, { id = `r{i}`, at = i })
		end
		local profile = ProfileLogic.migrate({ receipts = many })
		t.eq(#profile.receipts, Config.Shop.ReceiptHistoryMax)
		t.eq(profile.receipts[1].id, "r6")
		t.eq(ProfileLogic.migrate({}).receipts, {}, "old profiles get an empty list")
		t.eq(ProfileSchema.new().receipts, {})
	end)

	---------------------------------------------------------------- 카드 상태 (AC6 보조)
	t.test(
		"cardState: 가짜 결제면 상품 id 없이도 로벅스 켜짐, 일반 스킨은 코인 옆에 로벅스 버튼",
		function()
			local v = { coins = 0, ownedSkins = { "tamago" }, equippedSkin = "tamago" }
			local uni = table.clone(Skins.get("uni") :: any)
			uni.productId = nil
			local off = ShopLogic.cardState(uni, v)
			t.eq(off.enabled, false)
			t.eq(ShopLogic.cardButtonText(off), "R$ 99 — 곧 열려요")
			local on = ShopLogic.cardState(uni, v, { fake = true })
			t.eq(on.kind, "Robux")
			t.eq(on.enabled, true)
			t.eq(ShopLogic.cardButtonText(on), "R$ 99")
			-- 실제 상품 가격이 오면 그 값
			uni.productId = 1
			local priced = ShopLogic.cardState(uni, v, { prices = { uni = 89 } })
			t.eq(priced.enabled, true)
			t.eq(ShopLogic.cardButtonText(priced), "R$ 89")
			-- 일반: 코인이 모자라도 로벅스 버튼
			local salmon = table.clone(Skins.get("salmon") :: any)
			salmon.productId = nil
			local common = ShopLogic.cardState(salmon, v, { fake = true })
			t.eq(common.kind, "NeedCoins")
			t.eq(ShopLogic.robuxButtonText(common), "R$ 49로 사기")
			t.eq(common.robuxEnabled, true)
			t.eq(ShopLogic.robuxButtonText(ShopLogic.cardState(salmon, v)), "R$ 49 — 곧 열려요")
			-- 가진 스킨·기본 스킨은 로벅스 버튼 없음 (AC8)
			local owned = { coins = 0, ownedSkins = { "tamago", "uni" }, equippedSkin = "tamago" }
			t.eq(ShopLogic.cardState(uni, owned, { fake = true }).kind, "Equip")
			t.eq(ShopLogic.robuxButtonText(ShopLogic.cardState(uni, owned, { fake = true })), nil)
			t.eq(ShopLogic.robuxOpen(Skins.get(Skins.DEFAULT_ID) :: any, true), false)
		end
	)

	---------------------------------------------------------------- 서버 배선 (소스 검사)
	t.test(
		"RobuxShopService: ProcessReceipt 하나, 저장 성공(saveNow) 뒤에만, 가짜 결제는 Studio 가드",
		function()
			local fs = require("@lune/fs")
			local src = fs.readFile("src/server/RobuxShopService.luau")
			local _, assigns = string.gsub(src, "MarketplaceService%.ProcessReceipt%s*=", "")
			t.eq(assigns, 1, "one ProcessReceipt")
			t.ok(string.find(src, "DataService.saveNow(me())", 1, true) ~= nil, "uses saveNow result")
			t.ok(
				string.find(src, "RunService:IsStudio() and Config.DEBUG.fakeRobuxInStudio == true", 1, true) ~= nil,
				"fake mode is studio-only"
			)
			t.ok(string.find(src, "PromptProductPurchase", 1, true) ~= nil)
			t.eq(Config.DEBUG.fakeRobuxInStudio, false, "default off")
			t.eq(Config.Shop.PurchaseRequestCooldown, 1)
			local all = ""
			for _, name in fs.readDir("src") do
				if fs.isDir(`src/{name}`) then
					for _, file in fs.readDir(`src/{name}`) do
						if string.match(file, "%.luau$") then
							all ..= fs.readFile(`src/{name}/{file}`)
						end
					end
				end
			end
			local _, total = string.gsub(all, "ProcessReceipt%s*=", "")
			t.eq(total, 1, "no other ProcessReceipt in src")
		end
	)
end
