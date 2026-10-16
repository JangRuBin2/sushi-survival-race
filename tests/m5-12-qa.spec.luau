--!strict
-- m5-12 QA: 게임패드 UI 경계값·잠금 기준·TV 여백 런타임(가짜 Roblox)·현지화 키·회귀 가드

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local LocTest = require("./lib/LocTest")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local GamepadNavLogic = RobloxRequire.require(Shared.GamepadNavLogic)
local UiLayout = RobloxRequire.require(Shared.UiLayout)

local function read(path: string): string
	return fs.readFile(path)
end

local function has(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local function count(source: string, needle: string): number
	local n = 0
	local at = 1
	while true do
		local s, e = string.find(source, needle, at, true)
		if s == nil then
			return n
		end
		n += 1
		at = (e :: number) + 1
	end
end

-- ShopController.canShow (탈의실 버튼이 보이는 때)를 그대로 옮긴 기준. hiddenUntil(탈락 연출)·매치 서버 로비는 뺐어요.
local function shopCanShow(inMatch: boolean, phase: string?, alive: boolean, passed: boolean): boolean
	if not inMatch then
		return true
	end
	if phase == "Starting" or phase == "Victory" or phase == nil then
		return false
	end
	if not alive then
		return true
	end
	if phase == "RoundResults" then
		return true
	end
	return passed
end

---------------------------------------------------------------- 가짜 Roblox 환경 (UiScaleController, 10피트)

local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function()
					local i = table.find(handlers, fn)
					if i then
						table.remove(handlers, i)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do
				fn(...)
			end
		end,
	}
end

local function loadUiScale(width: number, height: number, tenFoot: boolean)
	local instances: { any } = {}
	local viewportSignal = newSignal()
	local camera = {
		ViewportSize = { X = width, Y = height },
		GetPropertyChangedSignal = function(_, _prop: string)
			return viewportSignal
		end,
	}
	local fakeWorkspace = {
		CurrentCamera = camera,
		GetPropertyChangedSignal = function(_, _prop: string)
			return newSignal()
		end,
	}
	local function findChild(self: any, name: string): any
		for _, inst in instances do
			if inst.Parent == self and inst.Name == name then
				return inst
			end
		end
		return nil
	end
	local function newInstance(className: string): any
		local inst = {
			ClassName = className,
			Name = className,
			Parent = nil,
			Scale = 1,
			IsA = function(self, c: string)
				return self.ClassName == c
			end,
			FindFirstChild = findChild,
		}
		table.insert(instances, inst)
		return inst
	end
	local sharedFolder = setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
	local services = {
		ReplicatedStorage = { Shared = sharedFolder },
		GuiService = {
			IsTenFootInterface = function(_self: any): boolean
				return tenFoot
			end,
		},
	}
	local controller = luau.load(read("src/client/ui/UiScaleController.luau"), {
		debugName = "UiScaleController",
		environment = {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
			},
			workspace = fakeWorkspace,
			require = function(target: any)
				if target.__shared == "GamepadNavLogic" then
					return GamepadNavLogic
				end
				assert(target.__shared == "UiLayout", "fake require")
				return UiLayout
			end,
			Instance = { new = newInstance },
			UDim = {
				new = function(scale: number, offset: number)
					return { Scale = scale, Offset = offset }
				end,
			},
			Enum = {
				ScreenInsets = {
					CoreUISafeInsets = "CoreUISafeInsets",
					TopbarSafeInsets = "TopbarSafeInsets",
					DeviceSafeInsets = "DeviceSafeInsets",
				},
			},
			task = {
				spawn = function(fn, ...)
					fn(...)
				end,
			},
			table = table,
			math = math,
		},
	})()
	local function newGui(insets: string?)
		local gui = newInstance("ScreenGui")
		gui.ScreenInsets = insets or "CoreUISafeInsets"
		gui.Parent = "PlayerGui"
		return gui
	end
	local function children(gui: any, className: string): { any }
		local list = {}
		for _, inst in instances do
			if inst.Parent == gui and inst.ClassName == className then
				table.insert(list, inst)
			end
		end
		return list
	end
	return controller, newGui, children
end

return function(t: Test.Test)
	------------------------------------------------------------------ 잠금 기준 (D9)
	t.test("QA D9: navAllowed는 탈의실 버튼(ShopController.canShow)과 모든 조합에서 같아요", function()
		local phases = { "(nil)", "Starting", "RoundIntro", "RoundActive", "RoundResults", "Victory" }
		local mismatches: { string } = {}
		for _, inMatch in { false, true } do
			for _, name in phases do
				local phase: string? = if name == "(nil)" then nil else name
				for _, alive in { true, false } do
					for _, passed in { true, false } do
						local nav = GamepadNavLogic.navAllowed({
							inMatch = inMatch,
							phase = phase,
							alive = alive,
							passed = passed,
						})
						local shop = shopCanShow(inMatch, phase, alive, passed)
						if nav ~= shop then
							table.insert(mismatches, `{inMatch}/{name}/{alive}/{passed}: nav={nav} shop={shop}`)
						end
					end
				end
			end
		end
		t.eq(mismatches, {})
	end)

	t.test("QA D9: 결승·우승 연출·카운트다운은 탈락자·통과자도 잠겨요", function()
		for _, alive in { true, false } do
			for _, passed in { true, false } do
				t.eq(
					GamepadNavLogic.navAllowed({ inMatch = true, phase = "Victory", alive = alive, passed = passed }),
					false
				)
				t.eq(
					GamepadNavLogic.navAllowed({ inMatch = true, phase = "Starting", alive = alive, passed = passed }),
					false
				)
			end
		end
	end)

	t.test("QA 잠금 소스: GamepadNav와 ShopController가 같은 단계 리셋 규칙을 써요", function()
		local nav = read("src/client/ui/GamepadNav.luau")
		local shop = read("src/client/ui/ShopController.luau")
		-- 매치에 새로 들어오거나 나가면 단계·생존·통과를 처음으로
		t.ok(has(nav, "if not inMatch or not state.inMatch then"), "nav room reset")
		t.ok(has(shop, "if not inMatch or not wasInMatch then"), "shop room reset")
		-- Starting = 생존·통과 초기화, RoundIntro = 통과 초기화
		t.ok(has(nav, 'info.phase == "Starting"') and has(nav, 'info.phase == "RoundIntro"'), "nav phases")
		t.ok(has(shop, 'info.phase == "Starting"') and has(shop, 'info.phase == "RoundIntro"'), "shop phases")
		-- 잠금이면 선택 지우기 + GuiNavigationEnabled 끄기, 창 닫기는 게임패드 모드일 때만
		local lockAt = string.find(nav, "local function setLocked", 1, true) :: number
		local body = string.sub(nav, lockAt, string.find(nav, "\nend\n", lockAt, true) :: number)
		t.ok(has(body, "GuiService.GuiNavigationEnabled = not value"), "nav enabled follows lock")
		t.ok(has(body, "setSelection(nil)"), "selection cleared")
		t.ok(has(body, "if gamepad then"), "windows closed only in gamepad mode (mouse/touch unchanged)")
	end)

	------------------------------------------------------------------ 입력 종류 전환
	t.test(
		"QA 입력 전환: 패드 → 마우스 → 패드 → 화면 키보드 → 터치 순서로 모드가 꼬이지 않아요",
		function()
			local mode = false
			local function feed(name: string, typing: boolean?): boolean
				mode = GamepadNavLogic.modeFor(mode, name, typing)
				return mode
			end
			t.eq(feed("Gamepad1"), true)
			t.eq(feed("Focus"), true) -- 창 포커스는 그대로
			t.eq(feed("MouseMovement"), false)
			t.eq(feed("Focus"), false)
			t.eq(feed("Gamepad3"), true)
			t.eq(feed("Keyboard", true), true) -- 콘솔 화면 키보드
			t.eq(feed("TextInput", true), true)
			t.eq(feed("Keyboard", false), false) -- 글자 칸 밖 키보드면 PC
			t.eq(feed("Gamepad1"), true)
			t.eq(feed("Touch"), false)
			t.eq(feed("None"), false)
			t.eq(feed("MouseWheel"), false)
			t.eq(feed("Gamepad8"), true)
		end
	)

	t.test(
		"QA 비패드 경로: 모드가 아니면 한 프레임·입력·카드 미리보기가 바로 빠져요",
		function()
			local nav = read("src/client/ui/GamepadNav.luau")
			local stepAt = string.find(nav, "local function step(", 1, true) :: number
			t.ok(stepAt ~= nil, "step")
			local stepHead = string.sub(nav, stepAt, stepAt + 80)
			t.ok(has(stepHead, "if not gamepad then"), "step returns when not gamepad")
			local inputAt = string.find(nav, "local function onInput(", 1, true) :: number
			t.ok(has(string.sub(nav, inputAt, inputAt + 120), "if not gamepad or locked then"), "onInput guard")
			-- 마우스로 바꾸면 선택·창 쌓기를 비워요
			local modeAt = string.find(nav, "local function setMode(", 1, true) :: number
			local modeBody = string.sub(nav, modeAt, string.find(nav, "\nend\n", modeAt, true) :: number)
			t.ok(has(modeBody, "stack = {}"), "stack cleared on mouse/touch")
			t.ok(has(modeBody, "setSelection(nil)"), "selection cleared on mouse/touch")
			-- 탈의실 카드: 선택이 와도 패드일 때만 미리보기
			local shop = read("src/client/ui/ShopScreen.luau")
			local gainedAt = string.find(shop, "SelectionGained:Connect", 1, true) :: number
			t.ok(has(string.sub(shop, gainedAt, gainedAt + 120), "GamepadNav.isGamepad()"), "card preview guard")
			-- ⚙: 예전 조건(TouchGui 켜짐)은 그대로 + 패드 아님
			local settings = read("src/client/ui/SettingsButton.luau")
			t.ok(
				has(settings, 'touchGui:IsA("ScreenGui")') and has(settings, "and touchGui.Enabled"),
				"⚙ old rule kept"
			)
		end
	)

	------------------------------------------------------------------ 창 쌓기 경계
	t.test(
		"QA reconcile: 같은 상태를 두 번 맞춰도 변화 없음, 다시 열면 맨 위, 아래 창만 닫혀도 위 창 유지",
		function()
			local order = { "lobbyDialog", "shop", "draw", "result", "info", "offer", "code", "admin" }
			local stack, opened, closed = GamepadNavLogic.reconcile(
				{ "shop", "draw" },
				{ shop = true, draw = true },
				order
			)
			t.eq(stack, { "shop", "draw" })
			t.eq(opened, {})
			t.eq(closed, {})
			-- 아래 창(shop)만 닫힘 → draw는 그대로 맨 위
			stack, opened, closed = GamepadNavLogic.reconcile({ "shop", "draw" }, { draw = true }, order)
			t.eq(stack, { "draw" })
			t.eq(closed, { "shop" })
			-- shop을 다시 열면 이제 맨 위 (열린 순서)
			stack, opened = GamepadNavLogic.reconcile(stack, { draw = true, shop = true }, order)
			t.eq(stack, { "draw", "shop" })
			t.eq(opened, { "shop" })
			-- order에 없는 id(등록 안 된 창)는 무시
			stack, opened = GamepadNavLogic.reconcile({}, { ghost = true }, order)
			t.eq(stack, {})
			t.eq(opened, {})
			-- 입력 칸: 원래 stack 표를 바꾸지 않아요
			local original = { "shop" }
			GamepadNavLogic.reconcile(original, {}, order)
			t.eq(original, { "shop" })
		end
	)

	t.test("QA nextTab: 탭이 하나 줄어도(이벤트 끝) 범위 밖으로 안 가요", function()
		local tabs = { "all", "Basic" }
		for _, dir in { -3, -1, 0, 1, 3 } do
			for _, current in { "all", "Basic", "event-halloween" } do
				local result = GamepadNavLogic.nextTab(tabs, current, dir)
				t.ok(table.find(tabs, result) ~= nil, `{current} {dir} -> {result}`)
			end
		end
		-- 관리자 패널 탭 두 개: LB = 미리보기, RB = 명령 (끝에서 멈춤)
		t.eq(GamepadNavLogic.nextTab({ "preview", "command" }, "command", 1), "command")
		t.eq(GamepadNavLogic.nextTab({ "preview", "command" }, "preview", -1), "preview")
	end)

	------------------------------------------------------------------ TV 안전 여백
	t.test("QA AC2 경계: 흔한 TV·모니터 해상도에서 각 변 5% (반올림)", function()
		local cases = {
			{ 3840, 2160, 192, 108 },
			{ 2560, 1440, 128, 72 },
			{ 1366, 768, 68, 38 },
			{ 1280, 720, 64, 36 },
		}
		for _, c in cases do
			local insets = GamepadNavLogic.insetsFor(true, c[1], c[2])
			t.eq(insets.x, c[3], `{c[1]} x`)
			t.eq(insets.y, c[4], `{c[2]} y`)
			t.eq(insets.fraction, 0.05)
		end
		t.eq(GamepadNavLogic.SAFE_FRACTION, 0.05)
	end)

	t.test("QA D12 런타임: 10피트면 attach가 TvSafePadding 5% 하나, 위쪽 바 gui·PC는 없음", function()
		local controller, newGui, children = loadUiScale(1920, 1080, true)
		local gui = newGui()
		controller.attach(gui)
		controller.attach(gui) -- 두 번 불러도 하나
		local paddings = children(gui, "UIPadding")
		t.eq(#paddings, 1)
		local p = paddings[1]
		t.eq(p.Name, "TvSafePadding")
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			t.eq(p[side].Scale, 0.05, side)
			t.eq(p[side].Offset, 0, side)
		end
		t.eq(#children(gui, "UIScale"), 1, "UIScale still attached")
		-- 위쪽 바 gui(코인 배지·음소거 줄)는 여백도 배율도 안 붙여요
		local topbar = newGui("TopbarSafeInsets")
		controller.attach(topbar)
		t.eq(#children(topbar, "UIPadding"), 0)
		t.eq(topbar.ScreenInsets, "TopbarSafeInsets")

		local pcController, pcNewGui, pcChildren = loadUiScale(1920, 1080, false)
		local pcGui = pcNewGui()
		pcController.attach(pcGui)
		t.eq(#pcChildren(pcGui, "UIPadding"), 0, "PC/phone unchanged")
	end)

	------------------------------------------------------------------ 현지화
	t.test("QA 현지화: gamepad.hint.* 6개 ko/en, 자리표시자 일치, 코드와 CSV가 맞아요", function()
		local expected = {
			"gamepad.hint.page",
			"gamepad.hint.pageIdle",
			"gamepad.hint.spectate",
			"gamepad.hint.spectateIdle",
			"gamepad.hint.withTabs",
			"gamepad.hint.window",
		}
		local inCsv: { string } = {}
		for _, row in LocTest.rows do
			if string.sub(row.Key, 1, 8) == "gamepad." then
				table.insert(inCsv, row.Key)
				t.ok(row.Source ~= "" and row.en ~= "", `{row.Key} ko/en`)
				local function holes(text: string): { string }
					local list = {}
					for name in string.gmatch(text, "{([%a][%w]*)}") do
						table.insert(list, name)
					end
					table.sort(list)
					return list
				end
				t.eq(holes(row.en), holes(row.Source), `{row.Key} placeholders`)
			end
		end
		table.sort(inCsv)
		table.sort(expected)
		t.eq(inCsv, expected)
		-- 코드에서 쓰는 키가 모두 CSV에
		local used = {}
		for _, path in { "src/client/ui/GamepadNav.luau", "src/client/ui/SpectateScreen.luau" } do
			for key in string.gmatch(read(path), 'Loc%.t%("(gamepad%.[%w%.]+)"') do
				used[key] = true
			end
		end
		for key in used do
			t.ok(LocTest.has(key), `{key} in CSV`)
		end
		for _, key in expected do
			t.ok(used[key] == true, `{key} used in code`)
		end
	end)

	------------------------------------------------------------------ 서버·권한
	t.test(
		"QA 서버 무관: 게임패드 코드는 리모트를 보내지 않고, 순수 로직은 Roblox API가 없어요",
		function()
			local nav = read("src/client/ui/GamepadNav.luau")
			t.ok(not has(nav, "FireServer") and not has(nav, "InvokeServer"), "GamepadNav sends nothing")
			t.ok(not has(nav, "OnServerEvent"), "no server listener")
			local logic = read("src/shared/GamepadNavLogic.luau")
			t.ok(not has(logic, "game:GetService") and not has(logic, "Instance.new"), "pure")
			t.ok(not has(logic, "require("), "no dependencies")
		end
	)

	------------------------------------------------------------------ 연결 정리
	t.test(
		"QA 연결: 화면은 한 번만 만들어지고 GamepadNav 등록도 화면당 정해진 수만큼",
		function()
			-- 컨트롤러가 화면을 한 번만 만들어요 (다시 만들면 등록이 쌓여요)
			local builders = {
				{ "src/client/ui/ShopController.luau", "ShopScreen.new(", 1 },
				{ "src/client/ui/ShopController.luau", "DrawScreen.new(", 1 },
				{ "src/client/ui/OfferController.luau", "OfferScreen.new(", 1 },
				{ "src/client/ui/CodeController.luau", "CodeScreen.new(", 1 },
				{ "src/client/ui/AdminController.luau", "AdminPanel.new(", 1 },
				{ "src/client/ui/LobbyController.luau", "LobbyScreen.new(", 1 },
				{ "src/client/ui/LobbyController.luau", "RoomScreen.new(", 1 },
				{ "src/client/ui/SpectateController.luau", "SpectateScreen.new(", 1 },
			}
			for _, b in builders do
				t.eq(count(read(b[1]), b[2]), b[3], `{b[1]} {b[2]}`)
			end
			-- 등록 호출 수 (루프 안·render 안에서 부르지 않아요)
			local registrations = {
				{ "src/client/ui/ShopScreen.luau", 1 },
				{ "src/client/ui/DrawScreen.luau", 3 },
				{ "src/client/ui/OfferScreen.luau", 1 },
				{ "src/client/ui/CodeScreen.luau", 1 },
				{ "src/client/ui/AdminPanel.luau", 1 },
				{ "src/client/ui/LobbyScreen.luau", 1 },
			}
			for _, r in registrations do
				t.eq(count(read(r[1]), "GamepadNav.window({"), r[2], `{r[1]} windows`) -- 주석 속 이름은 빼요
			end
			-- 관리자 패널은 늦게 한 번 만들어요 (IsAdmin이 늦게 와도 연결을 끊어요)
			local admin = read("src/client/ui/AdminController.luau")
			t.ok(has(admin, "connection:Disconnect()"), "admin build once")
			-- GamepadNav.start는 한 번만 연결
			local nav = read("src/client/ui/GamepadNav.luau")
			t.ok(has(nav, "if started then"), "start guard")
			t.eq(count(nav, "RunService.Heartbeat:Connect"), 1)
		end
	)
end
