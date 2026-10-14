--!strict
-- m5-29 QA 회귀 테스트: 콘셉트 몸 실험 스킨 2차 4종(concept-unagi·uni·tako·inari)의 남용 방지(살 수 없음·특별 상품에
-- 못 넣음·나중에 빼도 안전), 탈의실 탭 위치, 게임에서 쓰는 표정에서 토핑이 얼굴 파츠를 가리지 않는지(외곽 상자),
-- 유부 밥 색 예외가 다른 콘셉트 스킨(연어 등)에 새지 않는지(호출 순서와 무관).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Offers = RobloxRequire.require(Shared.Offers)

local NEW = { "concept-unagi", "concept-uni", "concept-tako", "concept-inari" }
local INARI = "concept-inari"
local SALMON = "concept-salmon"

local FACE_PREFIXES = { "Eye", "Lid", "Shine", "Mouth", "Tongue", "Cheek", "Brow", "Sweat", "Bandage" }
local function isFace(name: string): boolean
	for _, prefix in FACE_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end
local function isSharedBody(name: string): boolean
	return string.match(name, "^Body") ~= nil or string.match(name, "^Arm") ~= nil or string.match(name, "^Foot") ~= nil
end

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

-- 얼굴 파츠 f를 앞(-Z)에서 가리는 토핑 파츠 이름들 (외곽 상자: x·y가 0.01 넘게 겹치고 앞면이 더 앞)
local function coveringParts(layout: { any }, f: any): { string }
	local flo, fhi = LayoutCheck.box(f)
	local found = {}
	for _, spec in layout do
		if not isFace(spec.name) and not isSharedBody(spec.name) then
			local lo, hi = LayoutCheck.box(spec)
			local ox = math.min(hi[1], fhi[1]) - math.max(lo[1], flo[1])
			local oy = math.min(hi[2], fhi[2]) - math.max(lo[2], flo[2])
			if ox > 0.01 and oy > 0.01 and lo[3] < flo[3] - 1e-6 then
				table.insert(found, spec.name)
			end
		end
	end
	return found
end

return function(t: Test.Test)
	t.test(
		"QA: 새 4종은 코인·로벅스·이벤트 재화 어느 길로도 살 수 없고 상품 id도 없어요",
		function()
			for _, id in NEW do
				local wallet =
					{ coins = 1e6, ownedSkins = { tamago = true }, equippedSkin = "tamago", eventTokens = {} }
				t.eq(ShopLogic.canBuyWithCoins(id, wallet).ok, false, `{id} coins`)
				t.eq(ShopLogic.canBuyWithTokens(id, wallet, 0).ok, false, `{id} tokens`)
				t.eq((ReceiptLogic.canRequest(id, {}, { canSave = true, fake = true })), false, `{id} robux fake`)
				t.eq((ReceiptLogic.canRequest(id, {}, { canSave = true })), false, `{id} robux`)
				t.eq(Skins.get(id).productId, nil, `{id} product`)
			end
		end
	)

	t.test("QA: 특별 상품(묶음)에 새 4종을 넣으면 Offers.validate가 막아요", function()
		for _, id in NEW do
			local list = table.clone(Offers.LIST) :: { any }
			local copy = table.clone(list[1])
			copy.skins = { "salmon", id }
			list[1] = copy
			t.eq((Offers.validate(list)), false, `{id} in bundle`)
		end
	end)

	t.test(
		"QA: 나중에 새 4종 id를 예외 목록에서 빼도 장착값은 계란초밥으로 안전하게 돌아가요",
		function()
			for _, id in NEW do
				Skins.EXPERIMENTAL_IDS[id] = nil
				local ok, result = pcall(function()
					local raw = ProfileSchema.new() :: any
					raw.equippedSkin = id
					return ProfileLogic.migrate(raw)
				end)
				Skins.EXPERIMENTAL_IDS[id] = true
				t.ok(ok, `{id} migrate after removal`)
				t.eq((result :: any).equippedSkin, "tamago", `{id} falls back to tamago`)
			end
		end
	)

	t.test(
		"QA: 탈의실 — 새 4종은 '전체' 탭 맨 끝 4장(표 순서)이고 등급 탭에는 안 보여요 (AC13 보조)",
		function()
			local view = { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
			for _, tab in ShopLogic.tabs(nil) do
				local list = ShopLogic.visibleSkins(view, tab, nil)
				local ids = {}
				for _, skin in list do
					ids[skin.id] = true
				end
				for _, id in NEW do
					if tab.id == "all" then
						t.ok(ids[id], `{id} in all tab`)
					else
						t.ok(ids[id] == nil, `{id} not in {tab.id} tab`)
					end
				end
				if tab.id == "all" then
					local tail = {}
					for i = #list - 3, #list do
						table.insert(tail, list[i].id)
					end
					t.eq(tail, NEW, "last four in the all tab")
					t.eq(list[#list - 4].id, "concept-ikura", "right after concept-ikura")
				end
			end
		end
	)

	t.test(
		"QA: 게임에서 쓰는 모습(기본·우승 Happy·탈락 Hurt + 견본 당황 Flustered, m5-30 B1)에서 콘셉트 9종 모두 토핑이 얼굴 파츠를 앞에서 안 가려요",
		function()
			for _, id in Sample.SKIN_IDS do
				for _, expression in { nil :: string?, "Default", "Happy", "Hurt", "Flustered" } do
					local layout = SushiBody.layout(id, expression)
					for _, spec in layout do
						-- 감은 눈(Lid)은 쉴 때 밥 속에 있어요 (깜빡임은 m5-29 관절 테스트가 봐요)
						if isFace(spec.name) and string.sub(spec.name, 1, 3) ~= "Lid" then
							t.eq(coveringParts(layout, spec), {}, `{id}/{tostring(expression)} {spec.name} covered`)
						end
					end
				end
			end
		end
	)

	t.test(
		"QA: 유부 밥 색 예외는 유부에만 — 유부를 먼저 만들어도 다른 콘셉트 스킨의 밥·입 덮개 색은 그대로",
		function()
			local before = {}
			for _, id in Sample.SKIN_IDS do
				if id ~= INARI then
					before[id] = byName(SushiBody.layout(id, "Default"))
				end
			end
			-- 유부를 여러 경로로 먼저 만들어요 (게임 레이아웃·견본 레이아웃)
			for _, expression in Sample.EXPRESSIONS do
				SushiBody.layout(INARI, expression)
				for _, pose in Sample.POSES do
					Sample.layout(expression, pose, INARI)
				end
			end
			local salmonSample = byName(Sample.layout("Default", "Stand", SALMON))
			local salmonGame = byName(SushiBody.layout(SALMON, "Default"))
			local inari = byName(SushiBody.layout(INARI, "Default"))
			t.ok(salmonGame.MouthCover.color[1] ~= inari.MouthCover.color[1], "salmon cover differs from pouch")
			t.eq(salmonSample.MouthCover.color, salmonGame.Body.color, "salmon sample cover = rice")
			t.eq(salmonSample.MouthCover.material, salmonGame.Body.material, "salmon sample cover material")
			for id, old in before do
				local now = byName(SushiBody.layout(id, "Default"))
				for _, name in { "Body", "BodyBase", "BodyBaseWide", "MouthCover" } do
					t.eq(now[name].color, old[name].color, `{id} {name} color`)
					t.eq(now[name].material, old[name].material, `{id} {name} material`)
					t.eq(now[name].color, salmonGame.Body.color, `{id} {name} = rice color`)
				end
			end
		end
	)
end
