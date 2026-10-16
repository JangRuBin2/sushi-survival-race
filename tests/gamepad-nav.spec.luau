--!strict
-- m5-12 콘솔(게임패드) UI: Shared.GamepadNavLogic (순수) + 화면 등록 소스 검사

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local GamepadNavLogic = RobloxRequire.require(Shared.GamepadNavLogic)

local function read(path: string): string
	return fs.readFile(path)
end

return function(t: Test.Test)
	------------------------------------------------------------------ AC1
	t.test("AC1: isGamepadInput — Gamepad1~8만 true", function()
		t.eq(GamepadNavLogic.isGamepadInput("Gamepad1"), true)
		t.eq(GamepadNavLogic.isGamepadInput("Gamepad8"), true)
		t.eq(GamepadNavLogic.isGamepadInput("MouseButton1"), false)
		t.eq(GamepadNavLogic.isGamepadInput("MouseMovement"), false)
		t.eq(GamepadNavLogic.isGamepadInput("Touch"), false)
		t.eq(GamepadNavLogic.isGamepadInput("Keyboard"), false)
		t.eq(GamepadNavLogic.isGamepadInput("Gamepad9"), false)
		t.eq(GamepadNavLogic.isGamepadInput("Gamepad0"), false)
		t.eq(GamepadNavLogic.isGamepadInput("Gamepad10"), false)
		t.eq(GamepadNavLogic.isGamepadInput(""), false)
	end)

	t.test(
		"AC1·AC10: modeFor — 패드면 켜고, 마우스·터치·키보드면 끄고, 창 포커스·글자 입력은 그대로",
		function()
			t.eq(GamepadNavLogic.modeFor(false, "Gamepad2"), true)
			t.eq(GamepadNavLogic.modeFor(true, "MouseMovement"), false)
			t.eq(GamepadNavLogic.modeFor(true, "MouseButton1"), false)
			t.eq(GamepadNavLogic.modeFor(true, "Touch"), false)
			t.eq(GamepadNavLogic.modeFor(true, "Keyboard"), false)
			t.eq(GamepadNavLogic.modeFor(true, "Focus"), true)
			t.eq(GamepadNavLogic.modeFor(false, "Focus"), false)
			t.eq(GamepadNavLogic.modeFor(true, "None"), true)
			t.eq(GamepadNavLogic.modeFor(true, "TextInput"), true)
			-- 콘솔 화면 키보드로 글자를 넣는 동안은 패드 모드 그대로 (선택이 풀리지 않게)
			t.eq(GamepadNavLogic.modeFor(true, "Keyboard", true), true)
			t.eq(GamepadNavLogic.modeFor(false, "Keyboard", true), false)
		end
	)

	------------------------------------------------------------------ AC2
	t.test("AC2: insetsFor — 10피트면 각 변 5%, 아니면 0", function()
		local tv = GamepadNavLogic.insetsFor(true, 1920, 1080)
		t.eq(tv.x, 96)
		t.eq(tv.y, 54)
		t.eq(tv.fraction, 0.05)
		local pc = GamepadNavLogic.insetsFor(false, 1920, 1080)
		t.eq(pc.x, 0)
		t.eq(pc.y, 0)
		t.eq(pc.fraction, 0)
		local small = GamepadNavLogic.insetsFor(true, 1280, 720)
		t.eq(small.x, 64)
		t.eq(small.y, 36)
		t.eq(GamepadNavLogic.insetsFor(true, 0, 0).x, 0)
	end)

	------------------------------------------------------------------ AC3
	t.test("AC3: nextTab — LB/RB로 돌고 끝에서 멈춰요", function()
		local tabs = { "all", "draw", "Basic", "Rare", "Epic", "Legendary" }
		t.eq(GamepadNavLogic.nextTab(tabs, "all", 1), "draw")
		t.eq(GamepadNavLogic.nextTab(tabs, "draw", -1), "all")
		t.eq(GamepadNavLogic.nextTab(tabs, "all", -1), "all") -- 처음에서 LB: 그대로
		t.eq(GamepadNavLogic.nextTab(tabs, "Legendary", 1), "Legendary") -- 끝에서 RB: 그대로
		t.eq(GamepadNavLogic.nextTab(tabs, "Epic", 1), "Legendary")
		t.eq(GamepadNavLogic.nextTab(tabs, "Rare", 5), "Epic") -- 한 번에 한 칸
		t.eq(GamepadNavLogic.nextTab(tabs, "Rare", 0), "Rare")
		t.eq(GamepadNavLogic.nextTab(tabs, "gone", 1), "all") -- 없어진 탭(이벤트 끝)이면 맨 앞
		t.eq(GamepadNavLogic.nextTab({}, "all", 1), "all")
		t.eq(GamepadNavLogic.nextTab({ "only" }, "only", 1), "only")
	end)

	------------------------------------------------------------------ 잠금
	t.test(
		"navAllowed: 로비·관전·대기석·라운드 결과는 켜고, 소개·달리는 중·카운트다운·우승은 꺼요",
		function()
			local function allowed(inMatch: boolean, phase: string?, alive: boolean, passed: boolean): boolean
				return GamepadNavLogic.navAllowed({ inMatch = inMatch, phase = phase, alive = alive, passed = passed })
			end
			t.eq(allowed(false, nil, true, false), true) -- 로비·대기실
			t.eq(allowed(true, nil, true, false), false) -- 매치 막 시작 (단계 모름)
			t.eq(allowed(true, "Starting", true, false), false)
			t.eq(allowed(true, "RoundIntro", true, false), false) -- 라운드 소개
			t.eq(allowed(true, "RoundActive", true, false), false) -- 달리는 중
			t.eq(allowed(true, "RoundActive", true, true), true) -- 통과해 대기석
			t.eq(allowed(true, "RoundIntro", true, true), true)
			t.eq(allowed(true, "RoundActive", false, false), true) -- 탈락해 관전
			t.eq(allowed(true, "RoundResults", true, false), true) -- 라운드 사이
			t.eq(allowed(true, "Victory", false, false), false) -- 우승 연출
			t.eq(allowed(true, "Starting", false, false), false)
		end
	)

	------------------------------------------------------------------ 창 쌓기
	t.test("reconcile: 열린 순서대로 쌓고, 닫힌 창은 빼요", function()
		local order = { "shop", "draw", "result", "code" }
		local stack, opened, closed = GamepadNavLogic.reconcile({}, { shop = true }, order)
		t.eq(stack, { "shop" })
		t.eq(opened, { "shop" })
		t.eq(closed, {})
		stack, opened, closed = GamepadNavLogic.reconcile(stack, { shop = true, draw = true }, order)
		t.eq(stack, { "shop", "draw" })
		t.eq(opened, { "draw" })
		stack, opened, closed = GamepadNavLogic.reconcile(stack, { shop = true, draw = true, result = true }, order)
		t.eq(stack, { "shop", "draw", "result" })
		stack, opened, closed = GamepadNavLogic.reconcile(stack, { shop = true, draw = true }, order)
		t.eq(stack, { "shop", "draw" })
		t.eq(closed, { "result" })
		t.eq(opened, {})
		-- 같은 프레임에 두 창이 열리면 등록 순서대로
		stack, opened = GamepadNavLogic.reconcile({}, { code = true, shop = true }, order)
		t.eq(stack, { "shop", "code" })
		t.eq(opened, { "shop", "code" })
		-- 먼저 연 창이 위에 있지 않아도 열린 순서가 그대로 (코드 창 → 탈의실)
		stack = GamepadNavLogic.reconcile({ "code" }, { code = true, shop = true }, order)
		t.eq(stack, { "code", "shop" })
		-- 전부 닫힘 (라운드 시작)
		stack, opened, closed = GamepadNavLogic.reconcile({ "shop", "draw" }, {}, order)
		t.eq(stack, {})
		t.eq(closed, { "shop", "draw" })
	end)

	t.test("reconcile 층: 한 번에 열린 창은 화면 층이 높은 것이 맨 위 (QA P3-2)", function()
		local order = { "shop", "admin" } -- 관리자 패널이 나중에 등록돼도
		-- 마우스로 둘 다 연 뒤 패드로 바꿈: 탈의실(20)이 관리자(15) 위에 보여요
		local stack, opened = GamepadNavLogic.reconcile(
			{},
			{ shop = true, admin = true },
			order,
			{ shop = 20, admin = 15 }
		)
		t.eq(stack, { "admin", "shop" })
		t.eq(opened, { "admin", "shop" })
		-- 같은 층이면 등록 순서
		stack = GamepadNavLogic.reconcile({}, { shop = true, admin = true }, order, { shop = 15, admin = 15 })
		t.eq(stack, { "shop", "admin" })
		-- 이미 쌓인 창은 층과 상관없이 그대로 아래
		stack = GamepadNavLogic.reconcile({ "shop" }, { shop = true, admin = true }, order, { shop = 20, admin = 15 })
		t.eq(stack, { "shop", "admin" })
	end)

	t.test(
		"nextInReadingOrder: 위 줄 왼쪽부터, 마지막 다음은 nil (QA P3-4 Select 앵커 차례)",
		function()
			local points = { { x = 900, y = 10 }, { x = 10, y = 12 }, { x = 120, y = 10 }, { x = 10, y = 80 } }
			t.eq(GamepadNavLogic.nextInReadingOrder(points, nil), 2)
			t.eq(GamepadNavLogic.nextInReadingOrder(points, 2), 3)
			t.eq(GamepadNavLogic.nextInReadingOrder(points, 3), 1)
			t.eq(GamepadNavLogic.nextInReadingOrder(points, 1), 4)
			t.eq(GamepadNavLogic.nextInReadingOrder(points, 4), nil)
			t.eq(GamepadNavLogic.nextInReadingOrder({}, nil), nil)
		end
	)

	t.test("stickScroll: 오른쪽 스틱으로 글 목록 굴리기, 데드존·끝에서 멈춤 (QA P3-1)", function()
		local speed = GamepadNavLogic.STICK_SCROLL_SPEED
		-- 데드존 안 → 그대로
		t.eq(GamepadNavLogic.stickScroll(100, 0.1, 0.1, 300, 1000), 100)
		-- 아래로 밀면(-1) 아래 글이 보여요
		t.eq(GamepadNavLogic.stickScroll(100, -1, 0.1, 300, 1000), 100 + speed * 0.1)
		-- 끝에서 멈춤 (캔버스 1000 - 보이는 300)
		t.eq(GamepadNavLogic.stickScroll(650, -1, 1, 300, 1000), 700)
		t.eq(GamepadNavLogic.stickScroll(20, 1, 1, 300, 1000), 0)
		-- 글이 창보다 짧으면 0, NaN은 그대로
		t.eq(GamepadNavLogic.stickScroll(0, -1, 1, 300, 200), 0)
		t.eq(GamepadNavLogic.stickScroll(50, 0 / 0, 1, 300, 1000), 50)
	end)

	t.test(
		"QA P3 소스: 창 층·이어 고르기·앵커 차례·스틱 스크롤·음소거 앵커·소개 여백",
		function()
			local nav = read("src/client/ui/GamepadNav.luau")
			t.ok(string.find(nav, "GamepadNavLogic.reconcile(stack, open, order, layers)", 1, true) ~= nil, "layers")
			t.ok(string.find(nav, "carryUntil > now", 1, true) ~= nil, "carry selection to the next page")
			t.ok(string.find(nav, "setSelection(anchorAfter(current))", 1, true) ~= nil, "select cycles anchors")
			t.ok(string.find(nav, "scrollTextWithStick(top, dt)", 1, true) ~= nil, "stick scroll in windows")
			t.ok(string.find(nav, "gui.ChildAdded:Connect(adoptMute)", 1, true) ~= nil, "mute button is an anchor")
			local sfx = read("src/client/Sfx.luau")
			t.ok(string.find(sfx, 'screen.Name = "SoundGui"', 1, true) ~= nil, "SoundGui name")
			t.ok(string.find(sfx, 'button.Name = "MuteButton"', 1, true) ~= nil, "MuteButton name")
			local intro = read("src/client/fx/IntroScreen.luau")
			t.ok(string.find(intro, "bannerBottom(parent) - top", 1, true) ~= nil, "intro subtracts TV padding")
		end
	)

	------------------------------------------------------------------ 첫 버튼
	t.test("pickFirst: 맨 위 줄의 맨 왼쪽 (같은 줄은 6px 안)", function()
		t.eq(GamepadNavLogic.pickFirst({}), nil)
		t.eq(GamepadNavLogic.pickFirst({ { x = 50, y = 50 } }), 1)
		t.eq(GamepadNavLogic.pickFirst({ { x = 300, y = 100 }, { x = 10, y = 200 }, { x = 120, y = 100 } }), 3)
		-- 3px 아래지만 같은 줄이라 왼쪽이 이겨요
		t.eq(GamepadNavLogic.pickFirst({ { x = 200, y = 40 }, { x = 20, y = 43 } }), 2)
		-- 7px 아래면 다른 줄
		t.eq(GamepadNavLogic.pickFirst({ { x = 200, y = 40 }, { x = 20, y = 47 } }), 1)
	end)

	------------------------------------------------------------------ 스크롤 따라가기
	t.test("scrollToShow: 선택한 칸이 목록 안에 보이게 굴려요", function()
		-- 이미 보임 → 그대로
		t.eq(GamepadNavLogic.scrollToShow(0, 300, 100, 50, 1000), 0)
		-- 아래로 벗어남 → 칸 아래 + 여유가 보이게
		t.eq(GamepadNavLogic.scrollToShow(0, 300, 400, 50, 1000), 400 + 50 + 8 - 300)
		-- 위로 벗어남 → 칸 위 - 여유
		t.eq(GamepadNavLogic.scrollToShow(500, 300, 450, 50, 1000), 442)
		-- 맨 위 칸 → 0 아래로 안 가요
		t.eq(GamepadNavLogic.scrollToShow(100, 300, 2, 50, 1000), 0)
		-- 맨 아래 칸 → 캔버스 끝을 넘지 않아요
		t.eq(GamepadNavLogic.scrollToShow(0, 300, 960, 40, 1000), 700)
		-- 목록이 보이는 칸보다 짧으면 0
		t.eq(GamepadNavLogic.scrollToShow(0, 300, 200, 50, 250), 0)
	end)

	------------------------------------------------------------------ 화면 등록 (소스 검사)
	t.test("화면마다 GamepadNav에 등록돼요 (스펙 화면 + 추가 범위)", function()
		local windows = {
			"src/client/ui/ShopScreen.luau",
			"src/client/ui/OfferScreen.luau",
			"src/client/ui/CodeScreen.luau",
			"src/client/ui/AdminPanel.luau",
			"src/client/ui/DrawScreen.luau",
			"src/client/ui/LobbyScreen.luau", -- 방 만들기 창
		}
		for _, path in windows do
			local source = read(path)
			t.ok(string.find(source, "GamepadNav.window(", 1, true) ~= nil, `{path} window`)
			t.ok(string.find(source, "close =", 1, true) ~= nil, `{path} close (B)`)
		end
		for _, path in { "src/client/ui/LobbyScreen.luau", "src/client/ui/RoomScreen.luau" } do
			t.ok(string.find(read(path), "GamepadNav.page(", 1, true) ~= nil, `{path} page`)
		end
		-- 탭: 탈의실·관리자·뽑기(휴대폰 탭)
		for _, path in
			{ "src/client/ui/ShopScreen.luau", "src/client/ui/AdminPanel.luau", "src/client/ui/DrawScreen.luau" }
		do
			t.ok(string.find(read(path), "tabs = function", 1, true) ~= nil, `{path} tabs`)
		end
		-- 뽑기 화면의 결과 창·확률 상세도 창
		local _, count = string.gsub(read("src/client/ui/DrawScreen.luau"), "GamepadNav%.window%(", "")
		t.eq(count, 3, "DrawScreen windows")
		-- 컨트롤러 등록
		t.ok(
			string.find(read("src/client/init.client.luau"), "require(script.ui.GamepadNav)", 1, true) ~= nil,
			"init.client starts GamepadNav"
		)
	end)

	t.test("터치 버튼 편집·⚙는 게임패드 모드에서 숨겨요 (터치 전용)", function()
		local editor = read("src/client/ui/TouchLayoutEditor.luau")
		t.ok(string.find(editor, "GamepadNav.isGamepad()", 1, true) ~= nil, "editor refuses in gamepad mode")
		local settings = read("src/client/ui/SettingsButton.luau")
		t.ok(string.find(settings, "not GamepadNav.isGamepad()", 1, true) ~= nil, "⚙ hidden in gamepad mode")
		t.ok(string.find(settings, "GamepadNav.onModeChanged", 1, true) ~= nil, "⚙ follows mode changes")
	end)

	t.test("관전 LB/RB·Y, 10피트 채팅 끄기·안전 여백", function()
		local spectate = read("src/client/ui/SpectateController.luau")
		for _, key in { "ButtonL1", "ButtonR1", "ButtonY" } do
			t.ok(string.find(spectate, `Enum.KeyCode.{key}`, 1, true) ~= nil, key)
		end
		t.ok(string.find(spectate, "GamepadNav.isWindowOpen()", 1, true) ~= nil, "window first")
		local chat = read("src/client/ui/ChatTagController.luau")
		t.ok(string.find(chat, "IsTenFootInterface", 1, true) ~= nil, "chat ten-foot check")
		t.ok(string.find(chat, "ChatWindowConfiguration", 1, true) ~= nil, "chat window off")
		local scale = read("src/client/ui/UiScaleController.luau")
		t.ok(string.find(scale, "GamepadNavLogic.insetsFor", 1, true) ~= nil, "safe padding")
	end)

	t.test(
		"잠금은 GuiNavigationEnabled를 끄고 선택을 지워요, 스크롤 목록은 선택 안 됨",
		function()
			local nav = read("src/client/ui/GamepadNav.luau")
			t.ok(
				string.find(nav, "GuiService.GuiNavigationEnabled = not value", 1, true) ~= nil,
				"nav off while racing"
			)
			t.ok(string.find(nav, "GamepadNavLogic.navAllowed", 1, true) ~= nil, "uses navAllowed")
			t.ok(string.find(nav, "SelectionBehavior.Stop", 1, true) ~= nil, "window fence")
			local kit = read("src/client/ui/RoomUiKit.luau")
			t.ok(string.find(kit, "Selectable = false", 1, true) ~= nil, "scroll list not selectable")
			t.ok(string.find(kit, "function Kit.selectionImage", 1, true) ~= nil, "selection style")
		end
	)
end
