--!strict
-- m4-09 QA: UiLayout 경계값 전수 검사 + UiScaleController 런타임(가짜 Roblox 환경) + 병합 뒤 통합 점검

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local Config = RobloxRequire.require(Shared.Config)

local EPS = 1e-9

-- 짧은 변 320~1200을 16:9, 19.5:9(노치 휴대폰), 4:3(태블릿) 비율로 훑어요
local function sweep(): { { number } }
	local screens = {}
	for short = 320, 1200, 7 do
		for _, ratio in { 16 / 9, 19.5 / 9, 4 / 3 } do
			table.insert(screens, { math.floor(short * ratio), short })
		end
	end
	-- 경계 바로 옆
	for _, s in { { 889, 500 }, { 890, 501 }, { 768, 432 }, { 766, 431 }, { 1600, 900 }, { 1598, 899 } } do
		table.insert(screens, s)
	end
	return screens
end

---------------------------------------------------------------- 가짜 Roblox 환경 (UiScaleController)

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

type Env = {
	controller: any,
	setViewport: (number, number) -> (),
	newGui: (insets: string?) -> any,
	children: (gui: any, className: string) -> { any },
}

local function loadUiScaleController(width: number, height: number): Env
	local instances: { any } = {}
	local viewportSignal = newSignal()
	local camera = {
		ViewportSize = { X = width, Y = height },
		GetPropertyChangedSignal = function(_, prop: string)
			assert(prop == "ViewportSize", prop)
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
	local services = { ReplicatedStorage = { Shared = sharedFolder } }
	local controller = luau.load(fs.readFile("src/client/ui/UiScaleController.luau"), {
		debugName = "UiScaleController",
		environment = {
			game = {
				GetService = function(_, name: string)
					return assert(services[name], name)
				end,
			},
			workspace = fakeWorkspace,
			require = function(target: any)
				assert(type(target) == "table" and target.__shared == "UiLayout", "fake require")
				return UiLayout
			end,
			Instance = { new = newInstance },
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
	return {
		controller = controller,
		setViewport = function(w: number, h: number)
			camera.ViewportSize = { X = w, Y = h }
			viewportSignal:Fire()
		end,
		newGui = function(insets: string?)
			local gui = newInstance("ScreenGui")
			gui.ScreenInsets = insets or "CoreUISafeInsets"
			gui.Parent = "PlayerGui"
			return gui
		end,
		children = function(gui: any, className: string)
			local list = {}
			for _, inst in instances do
				if inst.Parent == gui and inst.ClassName == className then
					table.insert(list, inst)
				end
			end
			return list
		end,
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- 배율 경계값
	t.test("QA 배율: 경계값(432 → 0.6, 720 → 1, 900 → 1.25)과 단조 증가", function()
		t.ok(math.abs(UiLayout.scaleFor(768, 432) - 0.6) < EPS, "짧은 변 432 = 0.6 × 720")
		t.ok(math.abs(UiLayout.scaleFor(766, 431) - 0.6) < EPS, "431은 하한")
		t.ok(math.abs(UiLayout.scaleFor(320, 568) - 0.6) < EPS, "iPhone SE 1세대(세로 입력도 짧은 변)")
		t.eq(UiLayout.scaleFor(1280, 720), 1)
		t.ok(math.abs(UiLayout.scaleFor(1600, 900) - 1.25) < EPS, "900 = 상한")
		t.ok(UiLayout.scaleFor(1598, 899) < 1.25, "899는 상한 아래")
		t.eq(UiLayout.scaleFor(3840, 2160), 1.25)
		t.eq(UiLayout.scaleFor(-5, 400), 1) -- 이상한 값
		t.eq(UiLayout.scaleFor(400, 0), 1)
		local previous = 0
		for short = 100, 2400, 3 do
			local s = UiLayout.scaleFor(short * 2, short)
			t.ok(s >= previous - EPS, `단조 증가 {short}`)
			t.ok(s >= Config.Ui.MinScale - EPS and s <= Config.Ui.MaxScale + EPS, `범위 {short}`)
			previous = s
		end
	end)

	t.test("QA compact: 500/501 경계, 세로 입력, iPad·PC는 compact 아님", function()
		t.eq(UiLayout.isCompact(500, 900), true)
		t.eq(UiLayout.isCompact(501, 900), false)
		t.eq(UiLayout.isCompact(932, 430), true) -- iPhone 14 Pro Max
		t.eq(UiLayout.isCompact(1180, 820), false) -- iPad Air
		t.eq(UiLayout.isCompact(1366, 768), false)
		t.eq(UiLayout.isCompact(1920, 1080), false)
	end)

	t.test("QA 터치·글씨 최소 크기: 짧은 변 320~1200 전 구간", function()
		for _, s in sweep() do
			local m = UiLayout.metrics(s[1], s[2])
			local label = `{s[1]}x{s[2]}`
			for _, base in { 44, 48 } do
				t.ok(UiLayout.touchSize(base, m) * m.scale >= Config.Ui.MinTouchSize - EPS, `{label}: 터치 {base}`)
			end
			if m.compact then
				for _, base in { 14, 16, 18 } do
					t.ok(UiLayout.textSize(base, m) * m.scale >= UiLayout.MIN_TEXT_PX - EPS, `{label}: 글씨 {base}`)
				end
			end
			t.ok(UiLayout.scrollBarThickness(m) * m.scale >= 8 - EPS, `{label}: 스크롤바`)
		end
	end)

	---------------------------------------------------------------- 터치 버튼
	t.test(
		"QA 터치 버튼 3개: 짧은 변 320~1200 전 구간에서 화면 안·8px 이상·방향·조이스틱 구역 밖",
		function()
			for _, s in sweep() do
				local w, h = s[1], s[2]
				local b = UiLayout.touchButtons(w, h)
				local label = `{w}x{h}`
				for name, r in b do
					t.ok(UiLayout.inside(r, w, h), `{label}: {name} 화면 안`)
				end
				t.ok(UiLayout.gapBetween(b.jump, b.dive) >= 8, `{label}: 점프-다이브`)
				t.ok(UiLayout.gapBetween(b.jump, b.grab) >= 8, `{label}: 점프-잡기`)
				t.ok(UiLayout.gapBetween(b.dive, b.grab) >= 8, `{label}: 다이브-잡기`)
				t.ok(b.dive.x + b.dive.size <= b.jump.x - 8, `{label}: 다이브 왼쪽`)
				t.ok(b.grab.y + b.grab.size <= b.jump.y - 8, `{label}: 잡기 위쪽`)
				-- Roblox 기본 조이스틱(왼쪽 40% 폭) 구역과 겹치지 않음
				t.ok(b.dive.x >= w * 0.4, `{label}: 조이스틱 구역 밖`)
				-- 85% 크기
				t.ok(math.abs(b.dive.size - b.jump.size * 0.85) <= 0.5, `{label}: 85%`)
			end
		end
	)

	t.test("QA 터치 버튼: 점프 버튼이 작으면 간격은 최소 8px", function()
		local b = UiLayout.touchButtons(667, 375, { x = 600, y = 300, size = 40 })
		t.eq(b.dive.size, 34)
		t.eq(b.jump.x - (b.dive.x + b.dive.size), 8)
		t.eq(b.jump.y - (b.grab.y + b.grab.size), 8)
		-- 실제 점프 버튼이 다른 크기여도(예: 노치 기기에서 Roblox가 바꾼 크기) 같은 규칙
		local big = UiLayout.touchButtons(932, 430, { x = 800, y = 300, size = 90 })
		t.ok(UiLayout.gapBetween(big.jump, big.dive) >= 8 and UiLayout.gapBetween(big.jump, big.grab) >= 8)
	end)

	t.test(
		"QA compact 관전 ◀ ▶: compact 전 구간에서 화면 안·터치 버튼과 8px 이상·서로 안 겹침",
		function()
			for _, s in sweep() do
				local w, h = s[1], s[2]
				if UiLayout.isCompact(w, h) then
					local a = UiLayout.spectateArrows(w, h)
					local b = UiLayout.touchButtons(w, h)
					local label = `{w}x{h}`
					t.ok(UiLayout.inside(a.left, w, h) and UiLayout.inside(a.right, w, h), `{label}: 화면 안`)
					t.ok(UiLayout.gapBetween(a.left, a.right) >= 8, `{label}: ◀ ▶ 서로`)
					for name, r in b do
						t.ok(UiLayout.gapBetween(a.right, r) >= 8, `{label}: ▶-{name}`)
					end
					t.ok(a.right.size >= Config.Ui.MinTouchSize, `{label}: 44px 이상`)
				end
			end
		end
	)

	---------------------------------------------------------------- UiScaleController 런타임
	t.test("QA UiScaleController.attach: 두 번 불러도 UIScale 하나, 배율 = scaleFor", function()
		local env = loadUiScaleController(667, 375)
		local gui = env.newGui()
		env.controller.attach(gui)
		env.controller.attach(gui)
		local scales = env.children(gui, "UIScale")
		t.eq(#scales, 1)
		t.ok(math.abs(scales[1].Scale - 0.6) < EPS, "iPhone SE 0.6")
		t.eq(scales[1].Name, "UiScale")
		t.eq(gui.ScreenInsets, "CoreUISafeInsets")
		-- start가 같은 gui를 다시 붙여도 하나 (LobbyController + init.client 순서)
		env.controller.start(gui)
		t.eq(#env.children(gui, "UIScale"), 1)
	end)

	t.test(
		"QA UiScaleController: 화면 크기가 바뀌면 배율·리스너 갱신, 끊으면 더 안 불림",
		function()
			local env = loadUiScaleController(667, 375)
			local gui = env.newGui()
			env.controller.attach(gui)
			local seen: { any } = {}
			local disconnect = env.controller.onChanged(function(m)
				table.insert(seen, m)
			end)
			t.eq(#seen, 1) -- 바로 한 번
			t.eq(seen[1].compact, true)
			env.setViewport(1920, 1080)
			t.eq(env.children(gui, "UIScale")[1].Scale, 1.25)
			t.eq(#seen, 2)
			t.eq(seen[2].compact, false)
			t.eq(env.controller.metrics().width, 1920)
			env.setViewport(1920, 1080) -- 같은 크기면 다시 안 불러요
			t.eq(#seen, 2)
			disconnect()
			env.setViewport(1280, 720)
			t.eq(#seen, 2)
			t.eq(env.children(gui, "UIScale")[1].Scale, 1)
		end
	)

	-- 스펙 범위 3: 위쪽 바 줄에 들어가는 gui(음소거, 코인 배지)는 TopbarSafeInsets 예외.
	-- m4-08 CoinController는 CoinScreen이 TopbarSafeInsets로 만든 CoinGui에 attach를 불러요.
	-- 고치는 방법(attach가 TopbarSafeInsets를 지키거나, CoinController가 attach 뒤 되돌리거나)과 상관없이 확인해요.
	t.test("QA 병합: m4-08 CoinGui가 attach 뒤에도 TopbarSafeInsets를 유지 (m4-09 QA B1)", function()
		local env = loadUiScaleController(1920, 1080)
		local coinGui = env.newGui("TopbarSafeInsets")
		env.controller.attach(coinGui)
		local keptByAttach = coinGui.ScreenInsets == "TopbarSafeInsets"

		local controllerSource = fs.readFile("src/client/ui/CoinController.luau")
		local attachAt = string.find(controllerSource, "UiScaleController.attach", 1, true)
		local resetAt = attachAt and string.find(controllerSource, "TopbarSafeInsets", attachAt, true)
		local callsAttach = attachAt ~= nil
		t.ok(
			not callsAttach or keptByAttach or resetAt ~= nil,
			"CoinGui가 attach 뒤 CoreUISafeInsets로 바뀌어 배지가 화면 왼쪽 가운데로, 토스트가 화면 아래 밖으로 가요"
		)
	end)

	---------------------------------------------------------------- 정적 점검
	t.test("QA 관전 키: ←/→ 바인딩 없음, Q/E만", function()
		local source = fs.readFile("src/client/ui/SpectateController.luau")
		t.eq(string.find(source, "KeyCode.Left", 1, true), nil)
		t.eq(string.find(source, "KeyCode.Right", 1, true), nil)
		t.ok(string.find(source, "KeyCode.Q", 1, true) ~= nil)
		t.ok(string.find(source, "KeyCode.E", 1, true) ~= nil)
		-- 관전 중 E는 다이브와 같은 키: 다이브는 카메라가 내 캐릭터가 아니면 막혀요
		local dive = fs.readFile("src/client/input/DiveController.luau")
		t.ok(string.find(dive, "spectating = ", 1, true) ~= nil, "DiveController가 관전 중 다이브를 막음")
		t.ok(string.find(dive, "camera.CameraSubject ~= humanoid", 1, true) ~= nil)
	end)

	t.test("QA 터치 버튼 gui에는 UIScale을 붙이지 않음 (점프 버튼 실제 픽셀 기준)", function()
		for _, path in { "src/client/input/DiveButton.luau", "src/client/input/GrabButton.luau" } do
			local source = fs.readFile(path)
			t.eq(string.find(source, "UiScaleController", 1, true), nil, path)
			t.ok(string.find(source, "UiLayout.touchButtons", 1, true) ~= nil, path)
		end
	end)
end
