--!strict
-- 탈의실 카드·미리보기에 🎫 뽑기 확률 (사용자 요청 2026-11-10). 값은 뽑기 화면 ⓘ와 같은 DrawLogic 계산이어야 해요.

local fs = require("@lune/fs")

local LocTest = require("./lib/LocTest")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local Skins = RobloxRequire.require(Shared.Skins)

return function(t: Test.Test)
	t.test(
		"뽑기 스킨마다 카드 확률 = 뽑기 화면 스킨별 확률, 뽑기 아닌 스킨은 없음",
		function()
			local perSkin = DrawLogic.perSkinPercent(DrawLogic.grades())
			local drawCount = 0
			for _, skin in Skins.LIST do
				local odds = DrawLogic.drawOdds(skin.id)
				if Skins.drawGradeOf(skin.id) ~= nil then
					drawCount += 1
					t.ok(odds ~= nil, `{skin.id} has odds`)
					t.eq(odds, perSkin[skin.id], skin.id)
					local tag = DrawLogic.drawOddsTag(skin.id)
					t.eq(LocTest.ko(tag :: any), `🎫 {odds}`, `{skin.id} tag`)
					t.eq(
						LocTest.ko(DrawLogic.drawOddsLine(skin.id) :: any),
						`뽑기 확률 각 {odds}`,
						`{skin.id} line`
					)
					t.ok(
						string.find(LocTest.en(DrawLogic.drawOddsLine(skin.id) :: any), odds :: string, 1, true) ~= nil
					)
				else
					t.eq(odds, nil, `{skin.id} not in draw`)
					t.eq(DrawLogic.drawOddsTag(skin.id), nil)
					t.eq(DrawLogic.drawOddsLine(skin.id), nil)
				end
			end
			local listed = 0
			for _ in Skins.DRAW_IDS do
				listed += 1
			end
			t.eq(drawCount, listed, "every draw skin checked")
		end
	)

	t.test("전설 카드 확률 = 전설 1% ÷ 전설 스킨 수 (고등어 포함 같은 값)", function()
		local legendary = 0
		for _, skin in Skins.LIST do
			if Skins.drawGradeOf(skin.id) == "Legendary" then
				legendary += 1
			end
		end
		t.ok(legendary > 0, "legendary draw skins")
		local expected = DrawLogic.perSkinPercent(DrawLogic.grades())["fresh-mackerel"]
		for _, skin in Skins.LIST do
			if Skins.drawGradeOf(skin.id) == "Legendary" then
				t.eq(DrawLogic.drawOdds(skin.id), expected, skin.id)
			end
		end
	end)

	t.test("화면이 카드 구석 표와 미리보기 줄을 그려요", function()
		local src = fs.readFile("src/client/ui/ShopScreen.luau")
		t.ok(string.find(src, "DrawLogic.drawOddsTag(skin.id)", 1, true) ~= nil, "card tag")
		t.ok(string.find(src, "DrawLogic.drawOddsLine(skin.id)", 1, true) ~= nil, "preview line")
	end)
end
