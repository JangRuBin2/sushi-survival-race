--!strict
-- m5-28 QA 회귀 테스트: 콘셉트 몸 실험 스킨 4종의 남용 방지(살 수 없음·특별 상품에 못 넣음·저장 없음),
-- 나중에 id를 빼도 저장 프로필이 안전하게 계란초밥으로 돌아가는지, 탈의실 탭 위치,
-- 새우 꼬리가 외곽 상자만이 아니라 실제 모양으로 돔에 닿는지(떠 보이지 않게), 팔 흔들기 관절 위치.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Offers = RobloxRequire.require(Shared.Offers)
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)

local NEW = { "concept-tuna", "concept-shrimp", "concept-tamago", "concept-ikura" }

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

-- XYZ 순서 회전 행렬 (CFrame.Angles(rx, ry, rz)와 같은 순서)
local function rotation(r: { number }): { { number } }
	local rx, ry, rz = math.rad(r[1]), math.rad(r[2]), math.rad(r[3])
	local function mul(a: { { number } }, b: { { number } }): { { number } }
		local c = {}
		for i = 1, 3 do
			c[i] = {}
			for j = 1, 3 do
				c[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
			end
		end
		return c
	end
	local X = { { 1, 0, 0 }, { 0, math.cos(rx), -math.sin(rx) }, { 0, math.sin(rx), math.cos(rx) } }
	local Y = { { math.cos(ry), 0, math.sin(ry) }, { 0, 1, 0 }, { -math.sin(ry), 0, math.cos(ry) } }
	local Z = { { math.cos(rz), -math.sin(rz), 0 }, { math.sin(rz), math.cos(rz), 0 }, { 0, 0, 1 } }
	return mul(mul(X, Y), Z)
end

return function(t: Test.Test)
	t.test(
		"QA: 새 4종은 코인·로벅스·이벤트 재화 어느 길로도 살 수 없고 상품 id로도 안 찾아져요",
		function()
			for _, id in NEW do
				local wallet =
					{ coins = 1e6, ownedSkins = { tamago = true }, equippedSkin = "tamago", eventTokens = {} }
				t.eq(ShopLogic.canBuyWithCoins(id, wallet).ok, false, `{id} coins`)
				-- 저장 목록에 이미 있어도(옛 데이터) 마찬가지
				t.eq(ShopLogic.canBuyWithTokens(id, wallet, 0).ok, false, `{id} tokens`)
				t.eq((ReceiptLogic.canRequest(id, {}, { canSave = true, fake = true })), false, `{id} robux fake`)
				t.eq((ReceiptLogic.canRequest(id, {}, { canSave = true })), false, `{id} robux`)
				t.eq(Skins.get(id).productId, nil, `{id} product`)
			end
			-- 상품 id 어떤 값으로도 콘셉트 스킨이 나오지 않아요
			for _, skin in Skins.LIST do
				if skin.productId ~= nil then
					t.ok(Skins.CONCEPT_BODY_IDS[(Skins.forProduct(skin.productId) :: any).id] ~= true, skin.id)
				end
			end
		end
	)

	t.test("QA: 특별 상품(묶음)에 콘셉트 스킨을 넣으면 Offers.validate가 막아요", function()
		for _, id in NEW do
			local list = table.clone(Offers.LIST) :: { any }
			local copy = table.clone(list[1])
			copy.skins = { "salmon", id }
			list[1] = copy
			t.eq((Offers.validate(list)), false, `{id} in bundle`)
		end
		-- 지금 목록에는 없어요
		for _, offer in Offers.LIST do
			for _, skinId in (offer :: any).skins or {} do
				t.ok(Skins.CONCEPT_BODY_IDS[skinId] ~= true, `{offer.id} {skinId}`)
			end
		end
	end)

	t.test(
		"QA: 나중에 콘셉트 id를 카탈로그에서 빼도 장착값은 안전하게 계란초밥, 저장에 흔적 없음",
		function()
			for _, id in NEW do
				-- 지금(m5-31): 뽑기로 보유하면 장착값 유지, 보유가 없으면 계란초밥 (무료가 아니에요)
				local raw = ProfileSchema.new() :: any
				raw.equippedSkin = id
				raw.ownedSkins[id] = true
				local profile = ProfileLogic.migrate(raw)
				t.eq(profile.equippedSkin, id, `{id} kept when owned`)
				local unowned = ProfileSchema.new() :: any
				unowned.equippedSkin = id
				t.eq(ProfileLogic.migrate(unowned).equippedSkin, "tamago", `{id} unowned falls back`)
				-- 예외 목록에서 빼도 migrate가 안전한지 (CONCEPT_BODY_IDS에서 잠시 뺌)
				Skins.CONCEPT_BODY_IDS[id] = nil
				local ok, result = pcall(function()
					local again = ProfileSchema.new() :: any
					again.equippedSkin = id
					return ProfileLogic.migrate(again)
				end)
				Skins.CONCEPT_BODY_IDS[id] = true
				t.ok(ok, `{id} migrate after removal`)
				t.eq((result :: any).equippedSkin, "tamago", `{id} falls back to tamago`)
				-- 카탈로그에 없는 id(완전히 삭제)도 외형 resolver는 nil → 기본 계란초밥
				local unknown = function(_: string): boolean
					return false
				end
				t.eq(AdminLogic.pickAppearance(nil, id, { [id] = true }, unknown), nil, `{id} unknown skin`)
				-- SushiBody.layout도 모르는 id면 계란초밥 레이아웃
				t.eq(SushiBody.layout("concept-removed"), SushiBody.layout("tamago"))
			end
		end
	)

	t.test(
		"QA: 탈의실 — 새 4종은 '전체' 탭 끝(m5-29 4종 바로 앞)에만, 등급 탭(일반~전설)에는 안 보여요",
		function()
			local view = { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
			local tabs = ShopLogic.tabs(nil)
			for _, tab in tabs do
				local list = ShopLogic.visibleSkins(view, tab, nil)
				local ids = {}
				for _, skin in list do
					ids[skin.id] = true
				end
				for _, id in NEW do
					if tab.id == "all" or tab.id == "draw" then
						t.ok(ids[id], `{id} in {tab.id} tab`) -- m5-31: 🎫 특 탭에도
					else
						t.ok(ids[id] == nil, `{id} not in {tab.id} tab`)
					end
				end
				if tab.id == "all" then
					-- m5-29가 그 뒤에 4종을 더 붙여요 → 맨 끝 4종 바로 앞
					local tail = {}
					for i = #list - 7, #list - 4 do
						table.insert(tail, list[i].id)
					end
					t.eq(tail, NEW, "four right before the m5-29 batch in the all tab")
				end
			end
		end
	)

	t.test(
		"QA: 새우 꼬리 3장이 외곽 상자가 아니라 실제 쐐기 꼭짓점으로 돔에 닿아요 (떠 보이지 않게)",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local parts = byName(SushiBody.layout("concept-shrimp", expression))
				local ridge = parts.Ridge
				local radius = ridge.size[2] / 2
				local half = ridge.size[1] / 2
				for _, name in { "TailLeft", "TailMid", "TailRight" } do
					local spec = parts[name]
					t.eq(spec.shape, "Wedge", name)
					local m = rotation(spec.rotation)
					local hx, hy, hz = spec.size[1] / 2, spec.size[2] / 2, spec.size[3] / 2
					local corners = {
						{ -hx, -hy, -hz },
						{ hx, -hy, -hz },
						{ -hx, -hy, hz },
						{ hx, -hy, hz },
						{ -hx, hy, hz },
						{ hx, hy, hz },
					}
					local nearest = math.huge
					for _, v in corners do
						local w = {}
						for i = 1, 3 do
							w[i] = m[i][1] * v[1] + m[i][2] * v[2] + m[i][3] * v[3] + spec.offset[i]
						end
						local dx = math.max(0, math.abs(w[1] - ridge.offset[1]) - half)
						local dy, dz = w[2] - ridge.offset[2], w[3] - ridge.offset[3]
						nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz) - radius)
					end
					-- 꼭짓점 하나라도 돔 표면 안쪽(또는 0.02 이내)에 있어야 붙어 보여요
					t.ok(nearest <= 0.02, `{expression} {name} nearest {nearest}`)
					-- 그렇다고 돔 속에 깊이 묻히지도 않아요 (꼬리 실루엣)
					t.ok(nearest > -0.3, `{expression} {name} not buried {nearest}`)
				end
			end
		end
	)

	t.test(
		"QA: 팔은 5종 모두 같은 자리·같은 관절이라 팔 흔들기가 같아요, 토핑이 팔을 덮지 않아요",
		function()
			local salmon = byName(SushiBody.layout("concept-salmon"))
			for _, id in Sample.SKIN_IDS do
				local parts = byName(SushiBody.layout(id))
				for _, arm in { "ArmLeft", "ArmRight" } do
					t.eq(parts[arm].joint, true, `{id} {arm} joint`)
					t.eq(parts[arm].offset, salmon[arm].offset, `{id} {arm} offset`)
					t.eq(parts[arm].size, salmon[arm].size, `{id} {arm} size`)
				end
			end
		end
	)
end
