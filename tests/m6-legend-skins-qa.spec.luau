--!strict
-- m6-08~m6-11 QA (전설 콘셉트 몸 스킨 8종 + 고등어): 얻는 길·가격·뽑기 확률·규칙 표가 서로 맞는지 한 번에 봐요.
--   "drawGrade + robux" 스킨은 모두 전설 R$ 199 + 뽑기 전설(코인·재화·시즌·VIP 없음), 뽑기 전설 등급 1%를 균등하게 나눔,
--   번들 상품에 새 전설이 들어가지 않음, 연출 표 ⊆ 콘셉트 몸·뽑기 목록, 규칙 표 예외(faceHidden·이름표)는 정해진 스킨만.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local AttackFxLogic = RobloxRequire.require(Shared.AttackFxLogic)
local Offers = RobloxRequire.require(Shared.Offers)

local NEW_LEGENDS = {
	"dragon-sushi",
	"sky-dragon-sushi",
	"jet-sushi",
	"shadow-jet-sushi",
	"magical-girl-sushi",
	"angel-sushi",
	"devil-sushi",
	"dynamite-sushi",
}

local function set(list: { string }): { [string]: boolean }
	local out = {}
	for _, id in list do
		out[id] = true
	end
	return out
end

return function(t: Test.Test)
	t.test(
		"QA 얻는 길: drawGrade + robux 스킨은 전설 R$ 199 + 뽑기 전설뿐 (코인·재화·시즌·VIP 없음)",
		function()
			local sold: { string } = {}
			for _, skin in Skins.LIST do
				if skin.drawGrade ~= nil and skin.robux ~= nil then
					table.insert(sold, skin.id)
					t.eq(skin.tier, "Legendary", skin.id)
					t.eq(skin.drawGrade, "Legendary", skin.id)
					t.eq(skin.robux, Skins.TIER_ROBUX.Legendary, skin.id)
					t.eq(skin.coins, nil, skin.id)
					t.eq(skin.tokens, nil, skin.id)
					t.eq(skin.season, nil, skin.id)
					t.eq(skin.vipOnly, nil, skin.id)
					t.eq(skin.conceptBody, true, skin.id)
					t.ok(not Skins.isDrawOnly(skin.id), `{skin.id} is not draw-only`)
					t.ok(not Skins.isFree(skin.id), `{skin.id} is not free`)
				end
			end
			local expected = set(NEW_LEGENDS)
			expected["fresh-mackerel"] = true
			t.eq(set(sold), expected)
		end
	)

	t.test("QA 뽑기 확률: 등급 비율은 그대로(전설 1%), 전설 9종이 균등하게 나눠요", function()
		local rows = DrawLogic.grades()
		local sum = 0
		for _, row in rows do
			sum += row.chance
			t.eq(row.chance, Config.Draw.GradeWeights[row.grade], `{row.grade} chance unchanged`)
			t.ok(#row.skinIds > 0, `{row.grade} not empty`)
		end
		t.ok(math.abs(sum - 1) < 1e-9, "chances sum to 1")
		local legend = rows[1]
		t.eq(legend.grade, "Legendary")
		t.eq(#legend.skinIds, 9)
		t.eq(set(legend.skinIds)["fresh-mackerel"], true)
		local per = DrawLogic.perSkinPercent(rows)
		for _, id in NEW_LEGENDS do
			t.eq(per[id], per["fresh-mackerel"], id)
			t.eq(DrawLogic.drawOdds(id), per[id], `card odds = draw screen {id}`)
		end
		t.eq(per["dragon-sushi"], "0.11%")
		-- 뽑기 목록 = drawGrade 있는 스킨 (특 9 + 전설 9)
		local n = 0
		for _ in Skins.DRAW_IDS do
			n += 1
		end
		t.eq(n, 18)
	end)

	t.test("QA 상품: 번들(스타터·에픽·전설 세트)·VIP에 새 전설 스킨이 없어요", function()
		local banned = set(NEW_LEGENDS)
		for _, offer in Offers.LIST do
			for _, id in offer.skins or {} do
				t.ok(not banned[id], `{offer.id} gives {id}`)
			end
		end
		local ok, problems = Offers.validate(Offers.LIST)
		t.ok(ok, table.concat(problems, ", "))
	end)

	t.test(
		"QA 규칙 표: 콘셉트 몸 목록 = SushiBody.CONCEPT_BODY, 새 전설은 상한 70·80 + 전설 ±25%",
		function()
			local ids: { [string]: boolean } = {}
			for id in SushiBody.CONCEPT_BODY do
				ids[id] = true
			end
			t.eq(ids, Skins.CONCEPT_BODY_IDS)
			for _, id in NEW_LEGENDS do
				local rule = SushiBody.CONCEPT_BODY[id]
				t.ok(rule ~= nil, id)
				t.ok(rule.partBudget == 70 or rule.partBudget == 80, `{id} part budget {rule.partBudget}`)
				t.eq(rule.boundsTolerance, 0.25, id)
				t.eq(rule.nameTagHeight, nil, `{id} uses the default name tag height`)
				t.eq(rule.faceHidden, if id == "dynamite-sushi" then true else nil, `{id} faceHidden`)
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, ", "))
		end
	)

	t.test(
		"QA 연출 표: 스킨별 공격 연출은 새 전설 8종뿐이고 모두 콘셉트 몸·뽑기 목록에 있어요",
		function()
			t.eq(
				set((function()
					local out = {}
					for id in AttackFxLogic.STYLE_BY_SKIN do
						table.insert(out, id)
					end
					return out
				end)()),
				set(NEW_LEGENDS)
			)
			for id, style in AttackFxLogic.STYLE_BY_SKIN do
				t.ok(Skins.DRAW_IDS[id] == true and Skins.CONCEPT_BODY_IDS[id] == true, id)
				t.ok(AttackFxLogic.STYLES[style] ~= nil, `{id} style {style}`)
				t.ok(AttackFxLogic.STYLES[style].duration <= 1, `{style} is short`)
			end
			-- 고등어·특 스킨·기본은 기본 연출
			for _, id in { "fresh-mackerel", "concept-salmon", "tamago" } do
				t.eq(AttackFxLogic.styleFor(id), "RiceBurst", id)
			end
		end
	)
end
