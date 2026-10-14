--!strict
-- m5-31 QA 수정: B1(휴대폰 뽑기 화면 버튼 44px 이상 — DrawScreenLayout 순수 계산), B2(두근두근 중 화면 다시 그리기 보류).

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local DrawScreenLayout = RobloxRequire.require(Shared.DrawScreenLayout)

local SCREENS = {
	{ 844, 390 }, -- iPhone 가로 (QA B1 기준)
	{ 667, 375 },
	{ 390, 844 }, -- 세로
	{ 568, 320 },
	{ 1366, 768 },
	{ 1920, 1080 },
}

return function(t: Test.Test)
	t.test("B1: 모든 화면 크기에서 뽑기 화면 버튼이 실제 44px 이상", function()
		for _, size in SCREENS do
			local m = UiLayout.metrics(size[1], size[2])
			local h = DrawScreenLayout.heights(m)
			for name, units in h :: any do
				local real = DrawScreenLayout.realPx(units, m)
				t.ok(real >= Config.Ui.MinTouchSize - 1e-6, `{size[1]}x{size[2]} {name}: {real}px`)
			end
		end
	end)

	t.test("B1: 844×390(배율 0.6)에서 높이는 UIScale 안 74 이상, PC에서는 기본값", function()
		local phone = UiLayout.metrics(844, 390)
		t.eq(phone.compact, true)
		local h = DrawScreenLayout.heights(phone)
		t.ok(h.wear >= 74 and h.expression >= 74 and h.info >= 74 and h.close >= 74 and h.result >= 74, "phone")
		local pc = DrawScreenLayout.heights(UiLayout.metrics(1920, 1080))
		t.eq(pc, DrawScreenLayout.BASE)
	end)

	t.test("B1 source: setLayout이 QA 표의 버튼을 모두 DrawScreenLayout 높이로 정해요", function()
		local src = fs.readFile("src/client/ui/DrawScreen.luau")
		local body = string.match(src, "function screen%.setLayout.-\n\tend\n") :: string
		t.ok(body ~= nil, "setLayout body")
		for _, needle in
			{
				"local h = DrawScreenLayout.heights(m)",
				"closeButton.Size = UDim2.fromOffset(h.close, h.close)",
				"infoButton.Size = UDim2.fromOffset(h.info, h.info)",
				"infoClose.Size = UDim2.fromOffset(h.close, h.close)",
				"detailClose.Size = UDim2.fromOffset(h.close, h.close)",
				"startButton.Size = UDim2.new(0.82, 0, 0, h.start)",
				"okButton.Size = UDim2.new(0.42, 0, 0, h.result)",
				"resultWear.Size = UDim2.new(0.42, 0, 0, h.result)",
				"exprRow.Size = UDim2.new(1, 0, 0, h.expression)",
				"wearButton.Size = UDim2.new(0.55, 0, 0, h.wear)",
			}
		do
			t.ok(string.find(body, needle, 1, true) ~= nil, needle)
		end
	end)

	t.test(
		"B2 source: 두근두근(busy) 중 render는 상태만 저장하고, 결과 공개·오류 뒤에 그려요",
		function()
			local src = fs.readFile("src/client/ui/DrawScreen.luau")
			local render = string.match(src, "function screen%.render.-\n\tend\n") :: string
			t.ok(render ~= nil)
			t.ok(string.find(render, "if busy then\n\t\t\tpendingPaint = true", 1, true) ~= nil, "defer while busy")
			local reveal = string.match(src, "function screen%.reveal.-\n\tend\n") :: string
			t.ok(string.find(reveal, "pendingPaint = false\n\t\tpaint()", 1, true) ~= nil, "paint after reveal")
			local message = string.match(src, "function screen%.showMessage.-\n\tend\n") :: string
			t.ok(string.find(message, "if pendingPaint then", 1, true) ~= nil, "paint after error")
		end
	)
end
