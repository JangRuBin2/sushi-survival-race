--!strict
-- UI 개선안 P0·P1 (2026-11-15): 닫기 글씨, 탈의실 썸네일, 관리자 Studio 칸, 가려진 방 이름, 테마 토큰

local fs = require("@lune/fs")
local Test = require("./lib/Test")

local UI = "src/client/ui"

return function(t: Test.Test)
	t.test("P0: 화면 코드에 깨지는 닫기 글자(✕)가 없고 Kit.CLOSE_TEXT를 써요", function()
		for _, name in fs.readDir(UI) do
			local src = fs.readFile(`{UI}/{name}`)
			for line in string.gmatch(src, "[^\n]+") do
				if string.find(line, "✕", 1, true) and not string.match(line, "^%s*%-%-") then
					t.ok(false, `{name}: {line}`)
				end
			end
		end
		t.ok(string.find(fs.readFile(`{UI}/RoomUiKit.luau`), 'Kit.CLOSE_TEXT = "X"', 1, true) ~= nil)
	end)

	t.test("P0: 탈의실 카드 썸네일은 처음 열 때 한 번만 만들어요", function()
		local src = fs.readFile(`{UI}/ShopScreen.luau`)
		t.ok(string.find(src, "local function buildThumbs()", 1, true) ~= nil)
		t.ok(string.find(src, "if thumbsBuilt then", 1, true) ~= nil)
		t.ok(string.find(src, "if open then\n\t\t\tbuildThumbs()", 1, true) ~= nil)
	end)

	t.test("P0: 실서버에서는 관리자 Studio 전용 칸을 숨겨요", function()
		local src = fs.readFile(`{UI}/AdminPanel.luau`)
		t.ok(string.find(src, "if not options.showReset then", 1, true) ~= nil)
		t.ok(string.find(src, "child.Visible = false", 1, true) ~= nil)
	end)

	t.test("P0: 필터로 다 가려진 방 이름은 기본 이름으로", function()
		local src = fs.readFile("src/server/RoomService.luau")
		t.ok(string.find(src, 'string.match(cleaned, "^[#%s]*$")', 1, true) ~= nil)
		t.eq(string.match("#######", "^[#%s]*$") ~= nil, true)
		t.eq(string.match("## 초밥 ##", "^[#%s]*$") ~= nil, false)
	end)

	t.test("P1: 큰 창은 나무 테두리(Kit.woodFrame)", function()
		for _, name in { "LobbyScreen", "RoomScreen", "ShopScreen", "PracticeDialog", "OfferScreen", "CodeScreen" } do
			t.ok(string.find(fs.readFile(`{UI}/{name}.luau`), "Kit.woodFrame(", 1, true) ~= nil, name)
		end
	end)
end
