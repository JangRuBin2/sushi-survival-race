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
	{ "salmon", "연어", "Common", 49, 500 },
	{ "tuna", "참치", "Common", 49, 500 },
	{ "shrimp", "새우", "Common", 49, 500 },
	{ "inari", "유부", "Common", 49, 500 },
	{ "kappa-maki", "오이마키", "Common", 49, 500 },
	{ "eel", "장어", "Rare", 99, nil },
	{ "uni", "성게", "Rare", 99, nil },
	{ "ikura", "연어알 군함", "Rare", 99, nil },
	{ "octopus", "문어", "Rare", 99, nil },
	{ "rainbow-roll", "무지개 롤", "Epic", 199, nil },
	{ "aburi-salmon", "불꽃 연어", "Epic", 199, nil },
	{ "california-roll", "아보카도 캘리포니아롤", "Epic", 199, nil },
	{ "golden-otoro", "황금 참치 뱃살", "Legendary", 399, nil },
	{ "diamond-uni", "다이아 성게", "Legendary", 399, nil },
	{ "dragon-roll", "용 롤", "Legendary", 399, nil },
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
	t.test("AC1: 카탈로그 16종이 표와 같아요 (순서·이름·등급·로벅스·코인)", function()
		t.eq(#Skins.LIST, #EXPECTED)
		for i, row in EXPECTED do
			local skin = Skins.LIST[i]
			t.eq(skin.id, row[1], `#{i} id`)
			t.eq(skin.displayName, row[2], `{row[1]} name`)
			t.eq(skin.tier, row[3], `{row[1]} tier`)
			t.eq(skin.robux, row[4], `{row[1]} robux`)
			t.eq(skin.coins, row[5], `{row[1]} coins`)
			t.eq(skin.productId, nil, `{row[1]} productId (m4-14가 채워요)`)
			t.eq(Skins.get(row[1]), skin)
		end
	end)

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

	t.test("AC1: 레어 이상은 코인 해금이 없고, 일반은 500 코인 (GDD 9.4)", function()
		for _, skin in Skins.LIST do
			if skin.tier == "Rare" or skin.tier == "Epic" or skin.tier == "Legendary" then
				t.eq(skin.coins, nil, skin.id)
			elseif skin.tier == "Common" then
				t.eq(skin.coins, 500, skin.id)
				t.eq(skin.coins, Skins.COMMON_COINS)
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

	t.test("byTier: 등급별 개수 (기본 1, 일반 5, 레어 4, 에픽 3, 전설 3), nil이면 전체", function()
		t.eq(#Skins.byTier("Basic"), 1)
		t.eq(#Skins.byTier("Common"), 5)
		t.eq(#Skins.byTier("Rare"), 4)
		t.eq(#Skins.byTier("Epic"), 3)
		t.eq(#Skins.byTier("Legendary"), 3)
		t.eq(#Skins.byTier(nil), 16)
		for _, tier in Skins.TIERS do
			t.ok(Skins.TIER_INFO[tier] ~= nil, tier)
		end
	end)

	t.test("validate가 잘못된 카탈로그를 잡아요", function()
		local bad = {
			{ id = "tamago", displayName = "계란", tier = "Basic", speech = { "a" }, order = 1 },
			{ id = "x", displayName = "x", tier = "Rare", robux = 99, coins = 500, speech = { "a" }, order = 2 },
			{ id = "x", displayName = "y", tier = "Common", robux = 49, speech = {}, order = 2 },
			{ id = "z", displayName = "z", tier = "Mythic", robux = 49, speech = { "a", "b", "c" }, order = 3 },
		}
		local ok, problems = Skins.validate(bad :: any)
		t.eq(ok, false)
		local text = table.concat(problems, "\n")
		t.ok(string.find(text, "coin price only for Common", 1, true) ~= nil, "rare coins")
		t.ok(string.find(text, "duplicate id", 1, true) ~= nil, "duplicate id")
		t.ok(string.find(text, "duplicate order", 1, true) ~= nil, "duplicate order")
		t.ok(string.find(text, "unknown tier", 1, true) ~= nil, "unknown tier")
		t.ok(string.find(text, "speech must have 1~2 lines", 1, true) ~= nil, "speech")
		local noDefault = { { id = "a", displayName = "a", tier = "Rare", robux = 99, speech = { "a" }, order = 1 } }
		local ok2, problems2 = Skins.validate(noDefault :: any)
		t.eq(ok2, false)
		t.ok(string.find(table.concat(problems2, ";"), "default skin", 1, true) ~= nil)
	end)

	t.test("forProduct: 상품 id가 아직 없어서 nil (m4-14가 채우면 그 스킨)", function()
		t.eq(Skins.forProduct(123), nil)
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

	t.test("AC2: 외곽 상자가 계란초밥 외곽의 ±15% 안 (폭·높이·두께)", function()
		local base = extents(SushiBody.layout("tamago"))
		for _, skin in Skins.LIST do
			local size = extents(SushiBody.layout(skin.id))
			for axis = 1, 3 do
				local ratio = size[axis] / base[axis]
				t.ok(
					ratio >= 1 - TOLERANCE and ratio <= 1 + TOLERANCE,
					`{skin.id} axis {axis}: {size[axis]} vs {base[axis]} ({ratio})`
				)
			end
		end
	end)

	t.test("AC2: 효과(불꽃·반짝이)는 스킨당 1개 이하, 계획한 스킨에만", function()
		local withEffect = { ["aburi-salmon"] = "Fire", ["golden-otoro"] = "Sparkles", ["diamond-uni"] = "Sparkles" }
		for _, skin in Skins.LIST do
			local layout = SushiBody.layout(skin.id)
			local count = SushiBody.effectCount(layout)
			t.ok(count <= 1, `{skin.id} effects {count}`)
			local expected = withEffect[skin.id]
			t.eq(count, if expected then 1 else 0, skin.id)
			for _, spec in layout do
				if spec.effect then
					t.eq(spec.effect, expected, skin.id)
				end
			end
		end
	end)

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
						spec.shape == nil or spec.shape == "Block" or spec.shape == "Ball" or spec.shape == "Cylinder",
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
