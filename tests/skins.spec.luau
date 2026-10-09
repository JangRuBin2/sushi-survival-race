--!strict
-- m4-13 스킨 카탈로그 (Shared.Skins)와 생김새 (Shared.SushiBody.layout), 탈락 대사 연결

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local Config = RobloxRequire.require(Shared.Config)

-- 스펙 표 그대로: id, 이름, 등급, 로벅스, 코인
local EXPECTED = {
	{ "tamago", "계란초밥", "Basic", nil, nil },
	{ "salmon", "연어", "Common", 29, 300 },
	{ "tuna", "참치", "Common", 29, 300 },
	{ "shrimp", "새우", "Common", 29, 300 },
	{ "inari", "유부", "Common", 29, 300 },
	{ "kappa-maki", "오이마키", "Common", 29, 300 },
	{ "eel", "장어", "Rare", 59, 900 },
	{ "uni", "성게", "Rare", 59, 900 },
	{ "ikura", "연어알 군함", "Rare", 59, 900 },
	{ "octopus", "문어", "Rare", 59, 900 },
	{ "rainbow-roll", "무지개 롤", "Epic", 99, nil },
	{ "aburi-salmon", "불꽃 연어", "Epic", 99, nil },
	{ "california-roll", "아보카도 캘리포니아롤", "Epic", 99, nil },
	{ "golden-otoro", "황금 참치 뱃살", "Legendary", 199, nil },
	{ "diamond-uni", "다이아 성게", "Legendary", 199, nil },
	{ "dragon-roll", "용 롤", "Legendary", 199, nil },
	-- m5-03: 시즌 한정 4 + VIP 1 (얻는 길은 아래 m5-03 테스트)
	{ "pumpkin-sushi", "호박 초밥", "Epic", 99, nil },
	{ "ghost-tamago", "유령 계란초밥", "Rare", nil, nil },
	{ "santa-shrimp", "산타 새우", "Epic", 99, nil },
	{ "tree-maki", "트리 마키", "Rare", nil, nil },
	{ "vip-gold-tamago", "금박 계란초밥", "Legendary", nil, nil },
}

local TOLERANCE = 0.15

local function extents(layout: { any }): { number }
	local b = SushiBody.bounds(layout)
	return { b.max[1] - b.min[1], b.max[2] - b.min[2], b.max[3] - b.min[3] }
end

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 카탈로그
	t.test(
		"AC1: 카탈로그 21종이 표와 같아요 (m5-03이 5종 추가) (순서·이름·등급·로벅스·코인)",
		function()
			t.eq(#Skins.LIST, #EXPECTED)
			for i, row in EXPECTED do
				local skin = Skins.LIST[i]
				t.eq(skin.id, row[1], `#{i} id`)
				t.eq(skin.displayName, row[2], `{row[1]} name`)
				t.eq(skin.tier, row[3], `{row[1]} tier`)
				t.eq(skin.robux, row[4], `{row[1]} robux`)
				t.eq(skin.coins, row[5], `{row[1]} coins`)
				-- productId: m4-14 이후 사용자가 채워요 (nil 또는 양의 정수, 기본 스킨은 항상 nil)
				local pid = skin.productId
				t.ok(pid == nil or (type(pid) == "number" and pid > 0 and pid % 1 == 0), `{row[1]} productId`)
				if row[1] == "tamago" then
					t.eq(pid, nil, "default skin has no product")
				end
				t.eq(Skins.get(row[1]), skin)
			end
		end
	)

	t.test("AC1: id·순서가 겹치지 않고 validate가 통과해요", function()
		local ids, orders = {}, {}
		for _, skin in Skins.LIST do
			t.ok(ids[skin.id] == nil, `duplicate id {skin.id}`)
			t.ok(orders[skin.order] == nil, `duplicate order {skin.order}`)
			ids[skin.id] = true
			orders[skin.order] = true
		end
		local ok, problems = Skins.validate(Skins.LIST)
		t.ok(ok, table.concat(problems, "; "))
	end)

	t.test("AC1: 에픽 이상은 코인 해금이 없고, 일반은 300·레어는 900 코인 (GDD 9.4)", function()
		t.eq(Skins.COMMON_COINS, 300)
		t.eq(Skins.RARE_COINS, 900)
		for _, skin in Skins.LIST do
			if skin.tier == "Epic" or skin.tier == "Legendary" then
				t.eq(skin.coins, nil, skin.id)
			elseif skin.tier == "Common" then
				t.eq(skin.coins, Skins.COMMON_COINS, skin.id)
			elseif skin.tier == "Rare" then
				-- 시즌 스킨(이벤트 재화)은 코인 해금이 없어요 (m5-03)
				t.eq(skin.coins, if skin.season then nil else Skins.RARE_COINS, skin.id)
			end
		end
	end)

	t.test("기본 스킨은 Config.Appearance.Default이고 무료예요", function()
		t.eq(Skins.DEFAULT_ID, Config.Appearance.Default)
		local skin = Skins.get(Config.Appearance.Default)
		t.ok(skin ~= nil)
		t.eq(skin.robux, nil)
		t.eq(skin.coins, nil)
	end)

	t.test("get: 모르는 id·문자열이 아닌 값은 nil", function()
		t.eq(Skins.get("no-such-skin"), nil)
		t.eq(Skins.get(nil), nil)
		t.eq(Skins.get(5), nil)
		t.eq(Skins.get({}), nil)
	end)

	t.test(
		"byTier: 등급별 개수 (기본 1, 일반 5, 레어 6, 에픽 5, 전설 4 — m5-03 포함), nil이면 전체",
		function()
			t.eq(#Skins.byTier("Basic"), 1)
			t.eq(#Skins.byTier("Common"), 5)
			t.eq(#Skins.byTier("Rare"), 6)
			t.eq(#Skins.byTier("Epic"), 5)
			t.eq(#Skins.byTier("Legendary"), 4)
			t.eq(#Skins.byTier(nil), 21)
			for _, tier in Skins.TIERS do
				t.ok(Skins.TIER_INFO[tier] ~= nil, tier)
			end
		end
	)

	t.test("validate가 잘못된 카탈로그를 잡아요", function()
		local bad = {
			{ id = "tamago", displayName = "계란", tier = "Basic", speech = { "a" }, order = 1 },
			{ id = "x", displayName = "x", tier = "Epic", robux = 99, coins = 900, speech = { "a" }, order = 2 },
			{ id = "x", displayName = "y", tier = "Common", robux = 29, speech = {}, order = 2 },
			{ id = "z", displayName = "z", tier = "Mythic", robux = 29, speech = { "a", "b", "c" }, order = 3 },
		}
		local ok, problems = Skins.validate(bad :: any)
		t.eq(ok, false)
		local text = table.concat(problems, "\n")
		t.ok(string.find(text, "coin price only for Common and Rare", 1, true) ~= nil, "epic coins")
		t.ok(string.find(text, "duplicate id", 1, true) ~= nil, "duplicate id")
		t.ok(string.find(text, "duplicate order", 1, true) ~= nil, "duplicate order")
		t.ok(string.find(text, "unknown tier", 1, true) ~= nil, "unknown tier")
		t.ok(string.find(text, "speech must have 1~2 lines", 1, true) ~= nil, "speech")
		local noDefault = { { id = "a", displayName = "a", tier = "Rare", robux = 99, speech = { "a" }, order = 1 } }
		local ok2, problems2 = Skins.validate(noDefault :: any)
		t.eq(ok2, false)
		t.ok(string.find(table.concat(problems2, ";"), "default skin", 1, true) ~= nil)
	end)

	t.test(
		"AC6(m5-21): validate가 효과 예산 초과를 잡아요 (실제 레이아웃을 가진 id, tier만 낮춰 예산 초과)",
		function()
			local fake: { any } = {}
			for _, skin in Skins.LIST do
				table.insert(fake, skin)
			end
			local index: number? = nil
			for i, skin in fake do
				if skin.id == "aburi-salmon" then
					index = i
				end
			end
			t.ok(index ~= nil, "aburi-salmon found in catalog")
			local overridden = table.clone(fake[index :: number])
			overridden.tier = "Basic" -- EFFECT_BUDGET.Basic == 0, aburi-salmon layout has 1 effect
			fake[index :: number] = overridden
			local ok, problems = Skins.validate(fake :: any)
			t.eq(ok, false)
			local text = table.concat(problems, "\n")
			t.ok(string.find(text, "effect budget exceeded", 1, true) ~= nil, text)
		end
	)

	t.test(
		"AC6(m5-21): 실제 카탈로그는 여전히 통과해요 (새 예산·허용치를 전부 지켜요)",
		function()
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("forProduct: 상품 id → 그 스킨, 모르는 id·문자열은 nil (m4-14)", function()
		t.eq(Skins.forProduct(-1), nil)
		for _, skin in Skins.LIST do
			if skin.productId then
				t.eq(Skins.forProduct(skin.productId), skin, skin.id)
			end
		end
		t.eq(Skins.forProduct("123"), nil)
	end)

	---------------------------------------------------------------- AC2 생김새
	t.test("AC2: 16종 모두 전용 레이아웃이 있고 Body를 가져요", function()
		for _, skin in Skins.LIST do
			t.ok(SushiBody.hasLayout(skin.id), `{skin.id} layout`)
			local names = byName(SushiBody.layout(skin.id))
			t.ok(names.Body ~= nil, `{skin.id} Body`)
		end
	end)

	t.test(
		"AC2: 히트박스·이름표 기준이 같아요 — Body·눈·입·발은 계란초밥과 같은 값, 발바닥 높이 같음",
		function()
			local base = byName(SushiBody.layout("tamago"))
			for _, skin in Skins.LIST do
				local layout = SushiBody.layout(skin.id)
				t.eq(layout[1].name, "Body", `{skin.id}: Body first`)
				local parts = byName(layout)
				for _, name in { "Body", "EyeLeft", "EyeRight", "Mouth", "FootLeft", "FootRight" } do
					local a, b = parts[name], base[name]
					t.ok(a ~= nil, `{skin.id} {name}`)
					for axis = 1, 3 do
						t.eq(a.size[axis], b.size[axis], `{skin.id} {name} size`)
						t.eq(a.offset[axis], b.offset[axis], `{skin.id} {name} offset`)
					end
					t.eq(a.rotation, nil, `{skin.id} {name} not rotated`)
				end
				local bounds = SushiBody.bounds(layout)
				t.ok(math.abs(-bounds.min[2] - SushiBody.GROUND_OFFSET) < 1e-6, `{skin.id} bottom {bounds.min[2]}`)
			end
		end
	)

	t.test(
		"AC2·AC5(m5-21): 외곽 상자가 등급별 허용치 안 (일반·레어 ±15%, 에픽·전설 ±25%)",
		function()
			local base = extents(SushiBody.layout("tamago"))
			for _, skin in Skins.LIST do
				local size = extents(SushiBody.layout(skin.id))
				local tolerance = SushiBody.BOUNDS_TOLERANCE[skin.tier] or TOLERANCE
				for axis = 1, 3 do
					local ratio = size[axis] / base[axis]
					t.ok(
						ratio >= 1 - tolerance and ratio <= 1 + tolerance,
						`{skin.id} axis {axis}: {size[axis]} vs {base[axis]} ({ratio}, tolerance {tolerance})`
					)
				end
			end
		end
	)

	t.test(
		"AC5(m5-21): 박스 허용치 - 높이 +20%는 에픽·전설만 통과, 일반·레어는 허용치 초과",
		function()
			local base = extents(SushiBody.layout("tamago"))
			local wideLayout = {
				{
					name = "Body",
					size = { base[1], base[2] * 1.2, base[3] },
					color = { 0, 0, 0 },
					material = "SmoothPlastic",
					offset = { 0, 0, 0 },
				},
			}
			local wideExtents = extents(wideLayout :: any)
			local ratio = wideExtents[2] / base[2]
			t.ok(math.abs(ratio - 1.2) < 1e-6, `ratio {ratio}`)
			for _, tier in { "Epic", "Legendary" } do
				local tolerance = SushiBody.BOUNDS_TOLERANCE[tier]
				t.ok(ratio <= 1 + tolerance, `{tier} should allow +20%`)
			end
			for _, tier in { "Common", "Rare" } do
				local tolerance = SushiBody.BOUNDS_TOLERANCE[tier]
				t.ok(ratio > 1 + tolerance, `{tier} should reject +20%`)
			end
		end
	)

	t.test(
		"AC2: 효과(불꽃·반짝이)는 등급별 예산 이하, 계획한 스킨에만 (m5-21: 예산표로 확인)",
		function()
			local withEffect =
				{ ["aburi-salmon"] = "Fire", ["golden-otoro"] = "Sparkles", ["diamond-uni"] = "Sparkles" }
			for _, skin in Skins.LIST do
				local layout = SushiBody.layout(skin.id)
				local count = SushiBody.effectCount(layout)
				local budget = SushiBody.EFFECT_BUDGET[skin.tier]
				t.ok(budget == nil or count <= budget, `{skin.id} effects {count} over budget {budget}`)
				local expected = withEffect[skin.id]
				t.eq(count, if expected then 1 else 0, skin.id)
				for _, spec in layout do
					if spec.effect then
						t.eq(spec.effect, expected, skin.id)
					end
				end
			end
		end
	)

	t.test(
		"AC4(m5-21): 효과 예산 - 에픽·전설 2개 통과, 일반·레어 2개는 budget 초과 (가짜 레이아웃, 실제 카탈로그 그대로)",
		function()
			local twoEffects = {
				{
					name = "A",
					size = { 0.2, 0.2, 0.2 },
					color = { 0, 0, 0 },
					material = "Neon",
					offset = { 0, 0, 0 },
					effect = "Fire",
				},
				{
					name = "B",
					size = { 0.2, 0.2, 0.2 },
					color = { 0, 0, 0 },
					material = "Neon",
					offset = { 0, 0, 0 },
					effect = "Sparkles",
				},
			}
			local count = SushiBody.effectCount(twoEffects :: any)
			t.eq(count, 2)
			t.ok(count <= SushiBody.EFFECT_BUDGET.Epic, "epic budget allows 2")
			t.ok(count <= SushiBody.EFFECT_BUDGET.Legendary, "legendary budget allows 2")
			t.ok(count > SushiBody.EFFECT_BUDGET.Common, "common budget is exceeded by 2")
			t.ok(count > SushiBody.EFFECT_BUDGET.Rare, "rare budget is exceeded by 2")
		end
	)

	t.test(
		"AC2: 파츠 값이 올바르고(크기 > 0, 색 0~255, Ball은 정육면체) 이름이 겹치지 않아요",
		function()
			for _, skin in Skins.LIST do
				local seen = {}
				for _, spec in SushiBody.layout(skin.id) do
					t.ok(seen[spec.name] == nil, `{skin.id} duplicate {spec.name}`)
					seen[spec.name] = true
					t.ok(type(spec.material) == "string" and #spec.material > 0, `{skin.id} {spec.name} material`)
					for axis = 1, 3 do
						t.ok(spec.size[axis] > 0, `{skin.id} {spec.name} size`)
						t.ok(spec.color[axis] >= 0 and spec.color[axis] <= 255, `{skin.id} {spec.name} color`)
					end
					if spec.shape == "Ball" then
						t.ok(
							spec.size[1] == spec.size[2] and spec.size[2] == spec.size[3],
							`{skin.id} {spec.name} ball`
						)
					end
					t.ok(
						spec.shape == nil
							or spec.shape == "Block"
							or spec.shape == "Ball"
							or spec.shape == "Cylinder"
							or spec.shape == "Wedge",
						`{skin.id} {spec.name} shape`
					)
				end
			end
		end
	)

	t.test("AC2: 모르는 id는 계란초밥 (hasLayout false)", function()
		t.eq(SushiBody.hasLayout("no-such-skin"), false)
		t.eq(#SushiBody.layout("no-such-skin"), #SushiBody.layout("tamago"))
	end)

	t.test("bounds는 회전을 반영해요 (Z로 90도 돌린 원판은 높이가 두께)", function()
		local spec = {
			name = "Disc",
			size = { 0.2, 1, 1 },
			color = { 0, 0, 0 },
			material = "SmoothPlastic",
			offset = { 0, 0, 0 },
			rotation = { 0, 0, 90 },
		}
		local b = SushiBody.bounds({ spec } :: any)
		t.ok(math.abs((b.max[2] - b.min[2]) - 0.2) < 1e-6, `height {b.max[2] - b.min[2]}`)
		t.ok(math.abs((b.max[1] - b.min[1]) - 1) < 1e-6, `width {b.max[1] - b.min[1]}`)
	end)

	t.test("layout 복사본: 회전·효과 색을 고쳐도 원본은 그대로", function()
		local first = SushiBody.layout("aburi-salmon")
		for _, spec in first do
			if spec.effectColor then
				spec.effectColor[1] = 0
			end
		end
		for _, spec in SushiBody.layout("aburi-salmon") do
			if spec.effectColor then
				t.ok(spec.effectColor[1] ~= 0, "effectColor copied")
			end
		end
		local salmon = SushiBody.layout("salmon")
		for _, spec in salmon do
			if spec.rotation then
				spec.rotation[2] = 999
			end
		end
		for _, spec in SushiBody.layout("salmon") do
			if spec.rotation then
				t.ok(spec.rotation[2] ~= 999, "rotation copied")
			end
		end
	end)

	---------------------------------------------------------------- AC4 대사
	t.test("AC4: 대사는 1~2줄이고 linesFor(id, variant)에 들어가요", function()
		for _, skin in Skins.LIST do
			t.ok(#skin.speech >= 1 and #skin.speech <= 2, `{skin.id} speech`)
			for _, variant in { "Chopsticks", "Mouth", "ChefHand" } do
				local lines = Cutscene.linesFor(skin.id, variant :: any)
				for _, line in skin.speech do
					t.ok(table.find(lines, line) ~= nil, `{skin.id} {variant} {line}`)
				end
			end
			t.eq(Cutscene.SKIN_LINES[skin.id], skin.speech)
		end
	end)

	t.test("AC4: 계란초밥 대사는 예전 그대로, 다른 스킨 대사는 섞이지 않아요", function()
		t.eq(Cutscene.SKIN_LINES.tamago, { "계란초밥은 역시 달달해", "폭신폭신 계란 최고!" })
		local salmonLines = Cutscene.linesFor("salmon", "Chopsticks")
		t.eq(table.find(salmonLines, "계란초밥은 역시 달달해"), nil)
	end)

	---------------------------------------------------------------- 외형 적용 지점
	t.test(
		"외형은 AppearanceService 한 곳: 서버의 다른 파일은 applyAppearance를 직접 부르지 않아요",
		function()
			for _, name in fs.readDir("src/server") do
				if string.match(name, "%.luau$") and name ~= "AppearanceService.luau" then
					local source = fs.readFile(`src/server/{name}`)
					t.ok(string.find(source, "applyAppearance(", 1, true) == nil, `{name} calls applyAppearance`)
				end
			end
		end
	)
end
