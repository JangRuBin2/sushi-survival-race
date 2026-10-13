--!strict
-- m5-22 QA: 스킨 1차 배치 10종을 스펙 표(가격 A안·등급·효과·Wedge 파츠)와 독립적으로 대조해요.
-- 개발 테스트(tests/skins.spec.luau)와 별개로, 스펙 문서의 숫자를 그대로 옮긴 표로 확인해요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)

-- 스펙 "가격·등급·speech 정리" 표 + "10종 상세"의 효과·Wedge
-- m5-25(캐릭터 퀄리티 2단계, 사용자 확정)가 31종을 새 몸에 맞춰 재배치하며 효과·Wedge 파츠 이름을 바꿨어요.
-- 콘셉트(갤럭시 = 반짝이+빛, 크라운 = 금관 가시+빛, 유니콘 = 뿔 반짝이+갈기 빛)는 그대로 — 표는 m5-25 스펙 기준.
local NEW = {
	{ id = "takoyaki", order = 22, tier = "Common", fx = {}, wedges = {} },
	{ id = "egg-toast", order = 23, tier = "Common", fx = {}, wedges = {} },
	{ id = "slider-burger", order = 24, tier = "Common", fx = {}, wedges = {} },
	{ id = "tonkatsu", order = 25, tier = "Rare", fx = {}, wedges = {} },
	{
		id = "cat-sushi",
		order = 26,
		tier = "Rare",
		fx = {},
		wedges = { "EarLeft", "EarRight", "EarInnerLeft", "EarInnerRight" },
	},
	{ id = "robo-roll", order = 27, tier = "Rare", fx = { AntennaTip = "Glow" }, wedges = {} },
	{
		id = "galaxy-roll",
		order = 28,
		tier = "Epic",
		fx = { Planet = "Sparkles", GlowCore = "Glow" },
		wedges = {},
	},
	{ id = "softserve-roll", order = 29, tier = "Epic", fx = {}, wedges = {} },
	{
		id = "crown-tuna",
		order = 30,
		tier = "Legendary",
		fx = { Jewel = "Sparkles", Ermine = "Glow" },
		wedges = {
			"CrownSpike1",
			"CrownSpike2",
			"CrownSpike3",
			"CrownSpike4",
			"CrownSpike5",
		},
	},
	{
		id = "unicorn-roll",
		order = 31,
		tier = "Legendary",
		fx = { HornTip = "Sparkles", Mane4 = "Glow" },
		wedges = { "Mane1", "Mane2", "Mane3", "Mane4" },
	},
}

-- 가격 A안 (CLAUDE.md "스킨 · 상점 규칙", GDD 9.2)
local ROBUX = { Common = 29, Rare = 59, Epic = 99, Legendary = 199 }
local COINS = { Common = 300, Rare = 900 }

local BASE_PARTS = { "Body", "EyeLeft", "EyeRight", "Mouth", "FootLeft", "FootRight" }

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

return function(t: Test.Test)
	t.test(
		"QA AC1: 새 10종 order·등급·가격(A안)·얻는 길 — productId·시즌·토큰·VIP 없음",
		function()
			for _, row in NEW do
				local skin = Skins.get(row.id)
				t.ok(skin ~= nil, `{row.id} in catalog`)
				if skin == nil then
					continue
				end
				t.eq(skin.order, row.order, `{row.id} order`)
				t.eq(skin.tier, row.tier, `{row.id} tier`)
				t.eq(skin.robux, ROBUX[row.tier], `{row.id} robux`)
				t.eq(skin.coins, COINS[row.tier], `{row.id} coins (nil for epic/legendary)`)
				t.eq(skin.productId, nil, `{row.id} productId`)
				t.eq(skin.season, nil, `{row.id} season`)
				t.eq(skin.tokens, nil, `{row.id} tokens`)
				t.eq(skin.vipOnly, nil, `{row.id} vipOnly`)
				t.ok(type(skin.displayName) == "string" and skin.displayName ~= "", `{row.id} displayName`)
			end
		end
	)

	t.test(
		"QA AC1: 카탈로그 전체 — 로벅스·코인 가격이 등급별 A안과 같아요 (코인→로벅스 판매 없음)",
		function()
			for _, skin in Skins.LIST do
				if skin.robux ~= nil then
					t.eq(skin.robux, ROBUX[skin.tier], `{skin.id} robux`)
				end
				if skin.coins ~= nil then
					t.eq(skin.coins, COINS[skin.tier], `{skin.id} coins`)
				end
				if skin.tier == "Epic" or skin.tier == "Legendary" then
					t.eq(skin.coins, nil, `{skin.id} epic/legendary have no coin price`)
				end
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.eq(ok, true, table.concat(problems, "; "))
			t.eq(#Skins.LIST, 31)
		end
	)

	t.test(
		"QA AC2: 새 10종 히트박스 기준 파츠(Body·눈·입·발)가 계란초밥과 완전히 같아요",
		function()
			local base = byName(SushiBody.layout("tamago"))
			for _, row in NEW do
				t.ok(SushiBody.hasLayout(row.id), `{row.id} has layout`)
				local parts = byName(SushiBody.layout(row.id))
				for _, name in BASE_PARTS do
					local a, b = parts[name], base[name]
					t.ok(a ~= nil, `{row.id} has {name}`)
					if a and b then
						t.eq(a.size, b.size, `{row.id} {name} size`)
						t.eq(a.offset, b.offset, `{row.id} {name} offset`)
						t.eq(a.rotation, b.rotation, `{row.id} {name} rotation`)
						t.eq(a.shape, b.shape, `{row.id} {name} shape`)
					end
				end
			end
		end
	)

	t.test("QA AC2: 효과 — 스펙 표의 파츠·종류 그대로, 등급 예산 이하", function()
		for _, row in NEW do
			local layout = SushiBody.layout(row.id)
			local found: { [string]: string } = {}
			for _, spec in layout do
				if spec.effect ~= nil then
					found[spec.name] = spec.effect
				end
			end
			t.eq(found, row.fx, `{row.id} effects`)
			local count = SushiBody.effectCount(layout)
			t.ok(count <= SushiBody.EFFECT_BUDGET[row.tier], `{row.id} effect budget`)
		end
	end)

	t.test("QA AC2: Wedge 파츠 — 스펙에 적힌 이름만 Wedge, 크기 세 축 모두 양수", function()
		local total = 0
		for _, row in NEW do
			local wedgeNames: { [string]: boolean } = {}
			for _, spec in SushiBody.layout(row.id) do
				if spec.shape == "Wedge" then
					wedgeNames[spec.name] = true
					total += 1
					for axis = 1, 3 do
						t.ok(spec.size[axis] > 0, `{row.id} {spec.name} size {axis}`)
					end
				end
			end
			local expected: { [string]: boolean } = {}
			for _, name in row.wedges do
				expected[name] = true
			end
			t.eq(wedgeNames, expected, `{row.id} wedge parts`)
		end
		t.eq(total, 13)
	end)

	t.test(
		"QA AC2: 외곽 상자 — 등급별 허용치 안, 꼭대기 y는 일반·레어 ≤ 3.105 / 에픽·전설 ≤ 3.575",
		function()
			local base = SushiBody.bounds(SushiBody.layout("tamago"))
			local baseHeight = base.max[2] - base.min[2]
			for _, row in NEW do
				local b = SushiBody.bounds(SushiBody.layout(row.id))
				local tol = SushiBody.BOUNDS_TOLERANCE[row.tier]
				local topLimit = base.min[2] + baseHeight * (1 + tol)
				t.ok(b.max[2] <= topLimit + 1e-9, `{row.id} top {b.max[2]} > {topLimit}`)
				t.ok(b.min[2] >= base.min[2] - 1e-9, `{row.id} below feet`)
				for axis = 1, 3 do
					local ratio = (b.max[axis] - b.min[axis]) / (base.max[axis] - base.min[axis])
					t.ok(ratio >= 1 - tol and ratio <= 1 + tol, `{row.id} axis {axis} ratio {ratio}`)
				end
			end
		end
	)

	t.test("QA AC1: 등급별 개수 Basic 1 / Common 8 / Rare 9 / Epic 7 / Legendary 6", function()
		t.eq(#Skins.byTier("Basic"), 1)
		t.eq(#Skins.byTier("Common"), 8)
		t.eq(#Skins.byTier("Rare"), 9)
		t.eq(#Skins.byTier("Epic"), 7)
		t.eq(#Skins.byTier("Legendary"), 6)
	end)

	t.test("QA AC4: 새 10종 대사 1~2줄, 빈 줄 없음, 세 변형 모두에 섞여요", function()
		for _, row in NEW do
			local skin = Skins.get(row.id) :: any
			t.ok(#skin.speech >= 1 and #skin.speech <= 2, `{row.id} speech count`)
			for _, line in skin.speech do
				t.ok(type(line) == "string" and line ~= "", `{row.id} empty line`)
				for _, variant in { "Chopsticks", "Mouth", "ChefHand" } do
					t.ok(table.find(Cutscene.linesFor(row.id, variant :: any), line) ~= nil, `{row.id} {variant}`)
				end
			end
		end
	end)
end
