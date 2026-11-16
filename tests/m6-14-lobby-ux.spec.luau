--!strict
-- m6-14 로비·방 만들기 UX: 방 만들기 창 크기 계산(CreateRoomLayout), 로비 접기·방 만들기 창 소스 규칙

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local CreateRoomLayout = RobloxRequire.require(Shared.CreateRoomLayout)
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local Config = RobloxRequire.require(Shared.Config)

-- 휴대폰 가로(포인트). 위쪽 바(CoreUISafeInsets)는 가장 두꺼운 58px로 빼요.
local PHONES = { { 640, 360 }, { 667, 375 }, { 812, 375 }, { 844, 390 }, { 915, 412 }, { 932, 430 } }
local DESKTOPS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 1024, 768 } }
local TOP_BAR = 58
local CHIPS = #Config.Room.MaxPlayerOptions

local function layoutFor(w: number, h: number)
	local m = UiLayout.metrics(w, h)
	local vw = w / m.scale
	local vh = (h - TOP_BAR) / m.scale
	return CreateRoomLayout.compute(m, vw, vh, CHIPS), m, vw, vh
end

return function(t: Test.Test)
	t.test("AC3 휴대폰 가로: 두 열, 스크롤 없이 화면 안", function()
		for _, s in PHONES do
			local layout, m, vw, vh = layoutFor(s[1], s[2])
			local tag = `{s[1]}x{s[2]}`
			t.eq(m.compact, true, tag)
			t.eq(layout.twoColumn, true, tag .. " 두 열")
			t.eq(
				layout.scrolls,
				false,
				tag .. ` 스크롤 없음 (본문 {layout.body}, 보이는 {layout.bodyVisible})`
			)
			t.ok(layout.height <= vh * CreateRoomLayout.HEIGHT_RATIO + 0.5, tag .. " 높이")
			t.ok(layout.width <= vw, tag .. " 폭")
			t.ok(layout.chipRows <= 2, tag .. " 인원 칩 두 줄 이하")
		end
	end)

	t.test("AC3 버튼·칩은 실제 px로 MinTouchSize 이상", function()
		for _, list in { PHONES, DESKTOPS } do
			for _, s in list do
				local layout, m = layoutFor(s[1], s[2])
				t.ok(layout.touch * m.scale >= Config.Ui.MinTouchSize - 1e-6, `{s[1]}x{s[2]} 높이`)
				t.ok(layout.chipWidth * m.scale >= Config.Ui.MinTouchSize - 1e-6, `{s[1]}x{s[2]} 칩 폭`)
				t.ok(layout.header >= layout.touch, "X 버튼이 머리줄에 들어가요")
			end
		end
	end)

	t.test("AC3 PC·태블릿: 한 열, 최대 폭, 스크롤 없음", function()
		for _, s in DESKTOPS do
			local layout = layoutFor(s[1], s[2])
			local tag = `{s[1]}x{s[2]}`
			t.eq(layout.twoColumn, false, tag)
			t.ok(layout.width <= CreateRoomLayout.MAX_WIDTH_SINGLE, tag)
			t.eq(layout.scrolls, false, tag)
			t.eq(layout.body, layout.left + layout.gap + layout.right, tag .. " 한 열 = 왼쪽 + 오른쪽")
		end
	end)

	t.test("아주 낮은 화면은 본문만 스크롤 (머리줄은 남아요)", function()
		local m = UiLayout.metrics(568, 320)
		local layout = CreateRoomLayout.compute(m, 568 / m.scale, 150 / m.scale, CHIPS)
		t.eq(layout.scrolls, true)
		t.ok(layout.bodyVisible >= layout.touch)
		t.eq(layout.height, layout.padding * 2 + layout.header + layout.gap + layout.bodyVisible)
	end)

	t.test("compact여도 가상 폭이 두 열 최소 폭보다 좁으면 한 열", function()
		local m = UiLayout.metrics(667, 375)
		local narrow = (CreateRoomLayout.MIN_TWO_COLUMN_WIDTH - 1) / CreateRoomLayout.WIDTH_RATIO
		local layout = CreateRoomLayout.compute(m, narrow, 600, CHIPS)
		t.eq(m.compact, true)
		t.eq(layout.twoColumn, false)
	end)

	t.test(
		"AC2 방 만들기 창: 바닥 취소 버튼 없음, X·B로 닫기, 설정은 Neutral 색을 안 써요",
		function()
			local source = fs.readFile("src/client/ui/CreateRoomDialog.luau")
			t.ok(string.find(source, "common.cancel.btn", 1, true) == nil, "취소 버튼 없음")
			t.ok(string.find(source, "Kit.CLOSE_TEXT", 1, true) ~= nil, "X 닫기")
			t.ok(string.find(source, "GamepadNav.window", 1, true) ~= nil, "게임패드 B = 닫기")
			t.ok(
				string.find(source, "Color.Neutral", 1, true) == nil,
				"설정 칩이 취소색(Neutral)과 같지 않게"
			)
			t.ok(string.find(source, "lobby.create.privateHint", 1, true) ~= nil, "비공개 설명")
			t.ok(string.find(source, "lobby.create.publicHint", 1, true) ~= nil, "공개 설명")
			t.ok(string.find(source, "CreateRoomLayout.compute", 1, true) ~= nil, "크기는 순수 계산으로")
		end
	)

	t.test("AC1 로비 패널 접기: 접기·방 찾기 버튼, 복귀 시 펼침, 안내가 오면 펼침", function()
		local source = fs.readFile("src/client/ui/LobbyScreen.luau")
		t.ok(string.find(source, "lobby.collapse.btn", 1, true) ~= nil, "접기 버튼")
		t.ok(string.find(source, "lobby.expand.btn", 1, true) ~= nil, "방 찾기 버튼")
		t.ok(string.find(source, "setCollapsed(false)", 1, true) ~= nil, "펼치는 길")
		t.ok(string.find(source, "CreateRoomDialog.new", 1, true) ~= nil, "방 만들기 창 분리")
	end)
end
