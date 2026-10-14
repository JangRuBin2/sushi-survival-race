--!strict
-- m5-41 QA: 터치 버튼 배치 편집의 경계값·보안 회귀 테스트.
--   서버: 진짜 DataService(메모리)로 SaveSettings 부분 저장 — 맨 위 경제 칸(coins 등) 무시, 틀린 요청은 간격을 안 씀(D11),
--   칸별 간격, reset, 큰 표·NaN·키 종류, 병합이 settings 밖을 안 건드림.
--   순수: 노치·위쪽 바가 있는 화면에서 프리셋·fit 규칙, 아주 작은 화면, 묶음 경계, 편집 잠금 표, 관전 화살표 경계.
--   클라이언트 소스: 편집 중 입력 막기·점프 다시 적용 가드·PC에서 ⚙ 없음.
-- (가짜 환경 도구는 tests/m4-01-qa.spec.luau에서 그대로 가져왔어요.)

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local TouchLayoutLogic = RobloxRequire.require(Shared.TouchLayoutLogic)
local UiLayout = RobloxRequire.require(Shared.UiLayout)

---------------------------------------------------------------- 가짜 환경 도구

local function newSignal(): any
	local handlers: { any } = {}
	local signal = {}
	function signal:Connect(fn)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, h in table.clone(handlers) do
			if h.connected then
				h.fn(...)
			end
		end
	end
	function signal:count(): number
		local n = 0
		for _, h in handlers do
			if h.connected then
				n += 1
			end
		end
		return n
	end
	return signal
end

-- task.spawn은 바로 실행(코루틴), task.defer는 flush()까지 모아 둬요 (= "프레임 끝").
local function newTask(): any
	local deferred: { any } = {}
	local T = {}
	function T.spawn(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end
	function T.defer(fn, ...)
		table.insert(deferred, { fn = fn, args = table.pack(...) })
	end
	function T.wait(_seconds: number?)
		return coroutine.yield()
	end
	function T.flush()
		while #deferred > 0 do
			local queue = deferred
			deferred = {}
			for _, d in queue do
				T.spawn(d.fn, table.unpack(d.args, 1, d.args.n))
			end
		end
	end
	function T.pending(): number
		return #deferred
	end
	return T
end

-- require(ReplicatedStorage.Shared.X)를 modules[X]로 바꿔 주는 가짜 Shared 폴더
local function sharedFolder(): any
	return setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
end

local function load(path: string, environment: { [string]: any }): any
	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end

local function fakeRequire(modules: { [string]: any }): (any) -> any
	return function(target: any): any
		local name = type(target) == "table" and target.__shared
		assert(name and modules[name] ~= nil, `fake require: {tostring(name)}`)
		return modules[name]
	end
end

---------------------------------------------------------------- DataService

type DataEnv = {
	DataService: any,
	T: any,
	players: any,
	sent: { { player: any, view: any } },
	saveSettings: any,
	warnings: { string },
	setClock: (number) -> (),
	join: (userId: number) -> any,
	leave: (player: any) -> (),
}

local function loadDataService(): DataEnv
	local T = newTask()
	local warnings: { string } = {}
	local clock = 100
	local sent: { { player: any, view: any } } = {}
	local events: { [string]: any } = {}
	local function event(name: string): any
		if events[name] == nil then
			events[name] = {
				OnServerEvent = newSignal(),
				FireClient = function(_, player, payload)
					if name == "ProfileUpdated" then
						table.insert(sent, { player = player, view = payload })
					end
				end,
			}
		end
		return events[name]
	end
	local list: { any } = {}
	local Players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function()
			return table.clone(list)
		end,
	}
	-- m4-07 병합: DataService가 DataStore를 쓰게 됐어요. Studio 기본(persistDataInStudio = false) = 메모리 모드로 돌려요.
	local guid = 0
	local services = {
		Players = Players,
		ReplicatedStorage = { Shared = sharedFolder() },
		DataStoreService = {},
		RunService = {
			IsStudio = function()
				return true
			end,
		},
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return `guid-{guid}`
			end,
		},
	}
	local DataService = load("src/server/DataService.luau", {
		game = {
			JobId = "",
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
			BindToClose = function() end,
		},
		require = fakeRequire({
			Config = Config,
			ProfileLogic = ProfileLogic,
			ProfileSchema = ProfileSchema,
			Remotes = { event = event },
		}),
		task = T,
		os = {
			clock = function()
				return clock
			end,
			time = os.time,
		},
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	})
	DataService.init()
	DataService.start()
	local env: DataEnv = {
		DataService = DataService,
		T = T,
		players = Players,
		sent = sent,
		saveSettings = event("SaveSettings"),
		warnings = warnings,
		setClock = function(value: number)
			clock = value
		end,
		join = function(userId: number): any
			local player = { UserId = userId, Name = `P{userId}`, Parent = Players }
			table.insert(list, player)
			Players.PlayerAdded:Fire(player)
			return player
		end,
		leave = function(player: any)
			Players.PlayerRemoving:Fire(player)
			local index = table.find(list, player)
			if index then
				table.remove(list, index)
			end
			player.Parent = nil
		end,
	}
	return env
end

---------------------------------------------------------------- 도우미

local NAMES = { "jump", "dive", "grab" }

local function goodLayout(): any
	return {
		v = 1,
		preset = "custom",
		jump = { x = 0.9, y = 0.8, s = 0.18 },
		dive = { x = 0.75, y = 0.82, s = 0.15 },
		grab = { x = 0.88, y = 0.5, s = 0.15 },
	}
end

local function phoneChange(): any
	return { bucket = "phone", layout = goodLayout() }
end

local function checkRules(t: any, buttons: any, s: any, label: string)
	local b = TouchLayoutLogic.bounds(s)
	for _, name in NAMES do
		local r = buttons[name]
		t.ok(r.size >= Config.Ui.MinTouchSize, `{label} {name} >= 44 ({r.size})`)
		t.ok(r.x >= b.left and r.y >= b.top, `{label} {name} top-left in bounds`)
		t.ok(r.x + r.size <= b.right and r.y + r.size <= b.bottom, `{label} {name} bottom-right in bounds`)
		t.ok(r.x >= s.width * 0.4, `{label} {name} right of joystick zone`)
		t.ok(r.x >= s.safe.left + 8, `{label} {name} notch left`)
		t.ok(r.y >= (s.topBar or 0) + 8, `{label} {name} below topbar`)
	end
	t.ok(next(TouchLayoutLogic.overlaps(buttons)) == nil, `{label} no overlap`)
	t.ok(TouchLayoutLogic.isValid(buttons, s), `{label} isValid`)
end

-- 가짜 환경에서 TouchLayoutController의 편집 잠금만 돌려 봐요 (PC로 두면 start가 잠금 감시만 켜요)
local function loadLockController(): (any, { [string]: any })
	local T = newTask()
	local events: { [string]: any } = {}
	local function event(name: string): any
		if events[name] == nil then
			events[name] = { OnClientEvent = newSignal(), FireServer = function() end }
		end
		return events[name]
	end
	local services = {
		GuiService = {},
		Players = { LocalPlayer = { UserId = 7 } },
		ReplicatedStorage = { Shared = sharedFolder() },
		UserInputService = { TouchEnabled = false },
	}
	local fakeScript = { Parent = { Parent = { ProfileStore = { __shared = "ProfileStore" } } } }
	local controller = load("src/client/input/TouchLayoutController.luau", {
		game = {
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
		},
		script = fakeScript,
		require = fakeRequire({
			Remotes = { event = event },
			TouchLayoutLogic = TouchLayoutLogic,
			Types = {},
			UiLayout = UiLayout,
			ProfileStore = {
				changed = function() end,
				get = function()
					return nil
				end,
			},
		}),
		task = T,
	})
	controller.start(nil)
	return controller, events
end

return function(t: Test.Test)
	------------------------------------------------------------ 서버 (진짜 DataService, 메모리)

	t.test(
		"qa: SaveSettings 배치 저장이 맨 위 경제 칸(coins·wins·ownedSkins 등)을 절대 안 바꿔요 (D8)",
		function()
			local env = loadDataService()
			local p = env.join(1)
			local before = env.DataService.get(p)
			local coins, wins = before.coins, before.wins
			env.setClock(300)
			env.saveSettings.OnServerEvent:Fire(p, {
				touchLayout = phoneChange(),
				coins = 999999,
				wins = 500,
				ownedSkins = { ["vip-gold-tamago"] = true },
				equippedSkin = "vip-gold-tamago",
				version = 99,
				settings = { muteLevel = 3 },
			})
			local after = env.DataService.get(p)
			t.eq(after.coins, coins, "coins")
			t.eq(after.wins, wins, "wins")
			t.eq(after.ownedSkins["vip-gold-tamago"], nil, "skin")
			t.ok(after.equippedSkin ~= "vip-gold-tamago", "equipped")
			t.eq(after.version, ProfileSchema.VERSION, "version")
			t.eq(after.settings.muteLevel, 1, "nested settings key ignored")
			t.ok(after.settings.touchLayout ~= nil and after.settings.touchLayout.phone ~= nil, "layout saved")
			-- 배치 안에 경제 칸을 넣으면 전체 거절
			env.setClock(301)
			local sneaky = phoneChange()
			sneaky.layout.coins = 5
			env.saveSettings.OnServerEvent:Fire(p, { touchLayout = { bucket = "tablet", layout = sneaky.layout } })
			t.eq(env.DataService.get(p).settings.touchLayout.tablet, nil, "extra key inside layout rejected")
			t.eq(env.DataService.get(p).coins, coins)
		end
	)

	t.test(
		"qa: 틀린 요청은 간격을 쓰지 않아요 — 틀린 배치 바로 뒤 맞는 배치는 받아요 (D11)",
		function()
			local env = loadDataService()
			local p = env.join(1)
			env.setClock(400)
			local bad = phoneChange()
			bad.layout.jump.x = 0 / 0
			env.saveSettings.OnServerEvent:Fire(p, { touchLayout = bad })
			t.eq(env.DataService.get(p).settings.touchLayout, nil, "NaN rejected")
			env.setClock(400.1)
			env.saveSettings.OnServerEvent:Fire(p, { touchLayout = phoneChange() })
			t.ok(env.DataService.get(p).settings.touchLayout ~= nil, "valid accepted right after invalid")
			-- 맞는 배치 뒤 0.2초 안의 두 번째(같은 칸)는 버림, 음소거는 받음
			env.setClock(400.3)
			env.saveSettings.OnServerEvent:Fire(p, { touchLayout = { bucket = "phone", reset = true } })
			t.ok(env.DataService.get(p).settings.touchLayout ~= nil, "same field too soon -> dropped")
			env.saveSettings.OnServerEvent:Fire(p, { muteLevel = 3 })
			t.eq(env.DataService.get(p).settings.muteLevel, 3, "other field accepted")
			env.setClock(400.7)
			env.saveSettings.OnServerEvent:Fire(p, { touchLayout = { bucket = "phone", reset = true } })
			t.eq(env.DataService.get(p).settings.touchLayout, nil, "reset after interval, last bucket -> nil")
			t.eq(env.DataService.get(p).settings.muteLevel, 3, "mute kept after reset")
		end
	)

	t.test(
		"qa: 둘 다 보냈는데 음소거만 너무 빠르면 배치만 받아요 (부분 수락), 음소거 간격 기록은 그대로",
		function()
			local last: { [string]: number } = { muteLevel = 10 }
			local patch = ProfileSchema.sanitizeSettings({ muteLevel = 2, touchLayout = phoneChange() })
			t.ok(patch ~= nil)
			local accepted = ProfileSchema.acceptByInterval(patch, last, 10.2, 0.5)
			t.ok(accepted ~= nil)
			t.eq(accepted.muteLevel, nil, "mute dropped")
			t.ok(accepted.touchLayout ~= nil, "layout kept")
			t.eq(last.muteLevel, 10, "mute time unchanged")
			t.eq(last.touchLayout, 10.2)
			-- 모두 너무 빠르면 nil
			t.eq(ProfileSchema.acceptByInterval(patch, last, 10.3, 0.5), nil)
		end
	)

	t.test("qa: 퇴장하면 칸별 간격 기록이 지워져요", function()
		local src = fs.readFile("src/server/DataService.luau")
		t.ok(string.find(src, "lastSettingsAt[player] = nil", 1, true) ~= nil, "cleared on leave")
	end)

	t.test(
		"qa: sanitizeChange 경계 — reset·layout 섞기, 키 종류, 숫자 키, 큰 표, 버전·preset 타입",
		function()
			local S = TouchLayoutLogic.sanitizeChange
			t.ok(S({ bucket = "tablet", reset = true }) ~= nil, "tablet reset")
			t.eq(S({ bucket = "phone", reset = false, layout = goodLayout() }), nil, "reset=false + layout")
			t.eq(S({ bucket = "phone", reset = true, layout = goodLayout() }), nil, "reset + layout")
			t.eq(S({ bucket = "phone", reset = "true" }), nil, "reset string")
			t.eq(S({ bucket = "phone" }), nil, "neither")
			t.eq(S({ bucket = "PHONE", layout = goodLayout() }), nil, "bucket case")
			t.eq(S({ bucket = 1, layout = goodLayout() }), nil, "bucket number")
			t.eq(S({ [1] = "phone", layout = goodLayout() } :: any), nil, "numeric key")
			local function layoutWith(edit: (any) -> ()): any
				local l = goodLayout()
				edit(l)
				return S({ bucket = "phone", layout = l })
			end
			t.eq(
				layoutWith(function(l)
					l.v = 2
				end),
				nil,
				"v 2"
			)
			t.eq(
				layoutWith(function(l)
					l.v = "1"
				end),
				nil,
				"v string"
			)
			t.eq(
				layoutWith(function(l)
					l.preset = 1
				end),
				nil,
				"preset number"
			)
			t.eq(
				layoutWith(function(l)
					l.preset = "Custom"
				end),
				nil,
				"preset case"
			)
			t.eq(
				layoutWith(function(l)
					l.preset = string.rep("c", 10000)
				end),
				nil,
				"preset long"
			)
			t.eq(
				layoutWith(function(l)
					l.jump.s = 0.0399
				end),
				nil,
				"s below"
			)
			t.eq(
				layoutWith(function(l)
					l.jump.s = 0.4001
				end),
				nil,
				"s above"
			)
			t.eq(
				layoutWith(function(l)
					l.jump.x = -0.0001
				end),
				nil,
				"x below"
			)
			t.eq(
				layoutWith(function(l)
					l.jump.y = 1.0001
				end),
				nil,
				"y above"
			)
			t.eq(
				layoutWith(function(l)
					l.dive.y = -math.huge
				end),
				nil,
				"-inf"
			)
			t.eq(
				layoutWith(function(l)
					l.grab.s = math.huge
				end),
				nil,
				"inf"
			)
			t.eq(
				layoutWith(function(l)
					l.grab = { x = 0.5, y = 0.5, s = 0.1, z = 1 }
				end),
				nil,
				"4 keys in spot"
			)
			t.eq(
				layoutWith(function(l)
					l.grab = { 0.5, 0.5, 0.1 }
				end),
				nil,
				"array spot"
			)
			t.eq(
				layoutWith(function(l)
					l.grab = "0.5,0.5"
				end),
				nil,
				"string spot"
			)
			t.eq(
				layoutWith(function(l)
					l.extra = { deep = { deeper = true } }
				end),
				nil,
				"nested extra"
			)
			-- 경계 안쪽 끝값은 통과
			local edge = layoutWith(function(l)
				l.jump = { x = 0, y = 1, s = 0.04 }
				l.dive = { x = 1, y = 0, s = 0.4 }
			end)
			t.ok(edge ~= nil, "edges accepted")
			-- 큰 표: 키 1만 개 — 거절
			local huge: { [string]: any } = { bucket = "phone", layout = goodLayout() }
			for i = 1, 10000 do
				huge["k" .. i] = i
			end
			t.eq(S(huge), nil, "huge change table")
			local hugeLayout = goodLayout()
			for i = 1, 10000 do
				hugeLayout["k" .. i] = i
			end
			t.eq(S({ bucket = "phone", layout = hugeLayout }), nil, "huge layout table")
			-- 저장값은 새 표 (원본 참조 아님), 소수 셋째 자리
			local raw = goodLayout()
			raw.jump.x = 0.123456
			local out = S({ bucket = "phone", layout = raw })
			t.eq(out.layout.jump.x, 0.123)
			t.ok(out.layout.jump ~= raw.jump, "fresh table")
			raw.jump.x = 0.9
			t.eq(out.layout.jump.x, 0.123, "not aliased")
		end
	)

	t.test(
		"qa: sanitizeSettings — 틀린 muteLevel + 맞는 배치는 전체 무시, 맨 위 모르는 칸만 있으면 nil",
		function()
			t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 9, touchLayout = phoneChange() }), nil)
			t.eq(ProfileSchema.sanitizeSettings({ coins = 5 }), nil, "only unknown keys")
			t.eq(ProfileSchema.sanitizeSettings({ touchLayout = false }), nil, "touchLayout false")
			t.eq(ProfileSchema.sanitizeSettings({ touchLayout = {} }), nil, "touchLayout empty")
			local patch = ProfileSchema.sanitizeSettings({ touchLayout = phoneChange(), coins = 5 })
			t.ok(patch ~= nil)
			t.eq((patch :: any).coins, nil, "coins not copied")
		end
	)

	t.test(
		"qa: applySettings는 settings 표만 바꾸고, 다른 묶음은 지켜요 (DataService.update 안)",
		function()
			local settings: any = { muteLevel = 2 }
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "phone", reset = true } })
			t.eq(settings, { muteLevel = 2 }, "reset on empty stays empty")
			ProfileSchema.applySettings(settings, { touchLayout = phoneChange() })
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "tablet", layout = goodLayout() } })
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "phone", reset = true } })
			t.eq(settings.touchLayout.phone, nil)
			t.ok(settings.touchLayout.tablet ~= nil, "tablet kept")
			t.eq(settings.muteLevel, 2)
			local src = fs.readFile("src/server/DataService.luau")
			local fnBody = string.match(src, "local function onSaveSettings.-\nend\n") or ""
			t.ok(
				string.find(
					fnBody,
					"DataService.update(player, function(profile)\n\t\tProfileSchema.applySettings",
					1,
					true
				) ~= nil,
				"applySettings inside update"
			)
			local sanitizeAt = string.find(fnBody, "sanitizeSettings", 1, true) or math.huge
			local intervalAt = string.find(fnBody, "acceptByInterval", 1, true) or -1
			t.ok(sanitizeAt < intervalAt, "validate before interval (D11)")
		end
	)

	t.test(
		"qa: 불러오기 — 묶음 안 버튼 하나만 망가져도 그 묶음만 버리고, 경제 필드는 지켜요",
		function()
			local broken = goodLayout()
			broken.dive.s = 0 / 0
			local profile, info = ProfileLogic.migrate({
				version = 3,
				coins = 123,
				wins = 4,
				settings = { muteLevel = 2, touchLayout = { phone = broken, tablet = goodLayout(), pc = goodLayout() } },
			})
			t.eq(profile.coins, 123)
			t.eq(profile.wins, 4)
			t.eq(profile.settings.muteLevel, 2)
			t.eq(profile.settings.touchLayout.phone, nil)
			t.ok(profile.settings.touchLayout.tablet ~= nil, "tablet kept")
			t.eq((profile.settings.touchLayout :: any).pc, nil, "unknown bucket dropped")
			t.eq(info.persistable, true)
			-- 다시 불러와도 같은 결과 (멱등)
			local again = ProfileLogic.migrate(profile)
			t.eq(again.settings, profile.settings)
		end
	)

	------------------------------------------------------------ 순수 배치 경계

	t.test("qa: 왼쪽 노치(47)·위쪽 바(58)·아래 홈 바(21) 화면에서 프리셋·fit 규칙", function()
		for _, size in { { 844, 390 }, { 932, 430 }, { 667, 375 }, { 568, 320 }, { 1194, 834 }, { 2400, 1080 } } do
			for _, safe in
				{
					{ left = 47, top = 0, right = 0, bottom = 21 },
					{ left = 47, top = 0, right = 47, bottom = 21 },
					{ left = 0, top = 24, right = 0, bottom = 0 },
				}
			do
				local s = TouchLayoutLogic.screen(size[1], size[2], safe, 58)
				local label = `{size[1]}x{size[2]} L{safe.left} R{safe.right} T{safe.top}`
				for _, name in { "large", "compact" } do
					local p = TouchLayoutLogic.preset(name, s)
					checkRules(t, p, s, `{name} {label}`)
				end
				local fitted = TouchLayoutLogic.resolve(goodLayout(), s)
				if fitted then
					checkRules(t, fitted, s, `fit {label}`)
				end
				local clamped, problem = TouchLayoutLogic.clamp(TouchLayoutLogic.preset("default", s), s)
				if problem == nil then
					checkRules(t, clamped, s, `default-clamped {label}`)
				end
			end
		end
	end)

	t.test(
		"qa: 아주 작은 화면·세로 화면에서도 에러 없이 기본으로 떨어지거나 화면 안",
		function()
			for _, size in { { 480, 270 }, { 390, 844 }, { 320, 240 } } do
				local s = TouchLayoutLogic.screen(size[1], size[2], nil, 36)
				local ok, result = pcall(TouchLayoutLogic.resolve, goodLayout(), s)
				t.ok(ok, `resolve no error {size[1]}`)
				if ok and result then
					checkRules(t, result, s, `resolve {size[1]}`)
				end
				for _, name in { "large", "compact" } do
					local okP, p = pcall(TouchLayoutLogic.preset, name, s)
					t.ok(okP, `{name} no error {size[1]}`)
					if okP then
						for _, n in NAMES do
							t.ok(UiLayout.inside((p :: any)[n], size[1], size[2]), `{name} {n} inside {size[1]}`)
						end
					end
				end
			end
		end
	)

	t.test("qa: 묶음 경계 — 짧은 변 500 = phone, 501 = tablet (가로·세로 같음)", function()
		local B = TouchLayoutLogic.bucketFor
		t.eq(B(TouchLayoutLogic.screen(1000, 500)), "phone")
		t.eq(B(TouchLayoutLogic.screen(1000, 501)), "tablet")
		t.eq(B(TouchLayoutLogic.screen(500, 1000)), "phone")
		t.eq(UiLayout.JUMP_SMALL_SHORT_SIDE, 500)
	end)

	t.test(
		"qa: 끌기·크기 조절을 아무리 반복해도 금지 구역·44px·짧은 변 35%를 넘지 않아요",
		function()
			local s = TouchLayoutLogic.screen(844, 390, { left = 47, top = 0, right = 47, bottom = 21 }, 58)
			local buttons = TouchLayoutLogic.preset("default", s)
			local seed = 12345
			local function rand(): number
				seed = (seed * 1103515245 + 12345) % 2147483648
				return seed / 2147483648
			end
			local b = TouchLayoutLogic.bounds(s)
			for i = 1, 400 do
				local name = NAMES[(i % 3) + 1]
				if rand() < 0.5 then
					buttons = TouchLayoutLogic.move(buttons, name, rand() * 1400 - 300, rand() * 800 - 200, s)
				else
					buttons = TouchLayoutLogic.resize(buttons, name, if rand() < 0.5 then -1 else 1, s)
				end
				local r = (buttons :: any)[name]
				local lo, hi = TouchLayoutLogic.sizeRange(name, s)
				t.ok(r.size >= math.max(44, lo) and r.size <= hi and r.size <= 390 * 0.35, `size step {i}`)
				t.ok(
					r.x >= b.left and r.y >= b.top and r.x + r.size <= b.right and r.y + r.size <= b.bottom,
					`pos step {i}`
				)
			end
			for _ = 1, 30 do
				buttons = TouchLayoutLogic.resize(buttons, "dive", -1, s)
			end
			t.ok(buttons.dive.size >= 44, "min 44")
			for _ = 1, 30 do
				buttons = TouchLayoutLogic.resize(buttons, "jump", 1, s)
			end
			local base = TouchLayoutLogic.baseSizes(s).jump
			t.ok(buttons.jump.size <= math.min(base * 1.6, 390 * 0.35), "max")
		end
	)

	t.test(
		"qa: 관전 화살표 — 버튼이 위쪽 띠 바로 아래·오른쪽 끝에 있어도 겹치지 않고 화면 안",
		function()
			for _, size in { { 844, 390 }, { 667, 375 }, { 568, 320 } } do
				local w, h = size[1], size[2]
				local s = TouchLayoutLogic.screen(w, h, nil, 58)
				local b = TouchLayoutLogic.bounds(s)
				local js = TouchLayoutLogic.baseSizes(s).jump
				local raw = {
					jump = { x = b.right - js, y = b.top, size = js },
					dive = { x = b.right - js * 2 - 20, y = b.top + 20, size = js },
					grab = { x = b.right - js, y = b.top + js + 20, size = js },
				}
				local buttons, problem = TouchLayoutLogic.clamp(raw, s)
				t.eq(problem, nil, `layout ok {w}`)
				local arrows = UiLayout.spectateArrows(w, h, buttons)
				for _, side in { "left", "right" } do
					local a = (arrows :: any)[side]
					t.ok(UiLayout.inside(a, w, h), `{side} inside {w}`)
					for _, n in NAMES do
						t.ok(UiLayout.gapBetween(a, (buttons :: any)[n]) >= UiLayout.MIN_TOUCH_GAP, `{side} vs {n} {w}`)
					end
				end
			end
		end
	)

	------------------------------------------------------------ 클라이언트 (가짜 환경 + 소스)

	t.test("qa: 편집 잠금 — 실제 이벤트 순서(Starting → RoomUpdated InMatch → RoundIntro)", function()
		local controller, events = loadLockController()
		local roomUpdated = events.RoomUpdated.OnClientEvent
		local phase = events.MatchPhase.OnClientEvent
		local result = events.PlayerResult.OnClientEvent
		t.eq(controller.isLocked(), false, "lobby")
		-- 서버: RoomService.beginMatch는 RoomUpdated를 task.defer로 미루고, MatchService는 Starting을 먼저 보내요
		phase:Fire({ phase = "Starting", aliveUserIds = { 7, 8 } })
		roomUpdated:Fire({ state = "InMatch" })
		local startingLocked = controller.isLocked()
		phase:Fire({ phase = "RoundIntro", aliveUserIds = { 7, 8 } })
		t.eq(controller.isLocked(), true, "intro locked")
		phase:Fire({ phase = "RoundActive", aliveUserIds = { 7, 8 } })
		t.eq(controller.isLocked(), true, "active locked")
		result:Fire({ userId = 8, result = "Eliminated" })
		t.eq(controller.isLocked(), true, "someone else eliminated")
		result:Fire({ userId = 7, result = "Passed" })
		t.eq(controller.isLocked(), false, "passed -> bench, unlocked")
		phase:Fire({ phase = "RoundResults", aliveUserIds = { 7 } })
		t.eq(controller.isLocked(), false, "results")
		phase:Fire({ phase = "RoundIntro", aliveUserIds = { 7 } })
		t.eq(controller.isLocked(), true, "next round intro locked again")
		result:Fire({ userId = 7, result = "Eliminated" })
		t.eq(controller.isLocked(), false, "eliminated -> spectate, unlocked")
		phase:Fire({ phase = "RoundIntro", aliveUserIds = { 8 } })
		t.eq(controller.isLocked(), false, "not alive stays unlocked")
		roomUpdated:Fire({ state = "Waiting" })
		t.eq(controller.isLocked(), false, "back to room")
		-- 리포트 B1(P3): D10은 Starting도 잠근다고 했지만, 이 순서에서는 RoomUpdated가 phase를 지워서 안 잠겨요.
		-- 지금 동작을 기록해 둬요 — B1을 고치면 이 기대값을 true로 바꿔요.
		t.eq(startingLocked, false, "B1: Starting not locked with real event order")
	end)

	t.test(
		"qa: 편집 중 입력 막기 — 다이브·잡기가 isEditing을 보고, 잡기는 놓고, 점프는 숨겨요",
		function()
			local dive = fs.readFile("src/client/input/DiveButton.luau")
			t.ok(
				string.find(dive, "if not TouchLayoutController.isEditing() then\n\t\t\t\tonPress()", 1, true) ~= nil,
				"dive"
			)
			t.ok(
				string.find(dive, "gui.Enabled = jump.Visible and not TouchLayoutController.isEditing()", 1, true)
					~= nil,
				"dive hidden"
			)
			local grab = fs.readFile("src/client/input/GrabButton.luau")
			t.ok(string.find(grab, "currentTouch ~= nil or TouchLayoutController.isEditing()", 1, true) ~= nil, "grab")
			t.ok(string.find(grab, "if editing then\n\t\t\trelease()", 1, true) ~= nil, "grab released")
			local ctl = fs.readFile("src/client/input/TouchLayoutController.luau")
			t.ok(
				string.find(ctl, "if editing then\n\t\tif button.Visible then\n\t\t\tbutton.Visible = false", 1, true)
					~= nil,
				"jump hidden"
			)
			local editor = fs.readFile("src/client/ui/TouchLayoutEditor.luau")
			t.ok(
				string.find(editor, 'Name = "Overlay",\n\t\tParent = gui,\n\t\tActive = true', 1, true) ~= nil,
				"overlay sinks"
			)
			t.ok(string.find(editor, "TouchLayoutController.isLocked()", 1, true) ~= nil, "open checks lock")
		end
	)

	t.test(
		"qa: 점프 다시 적용 — 우리가 쓴 값은 기억 안 하고, 같으면 안 쓰고, 한 번만 미뤄요 (무한 루프 방지)",
		function()
			local ctl = fs.readFile("src/client/input/TouchLayoutController.luau")
			t.ok(string.find(ctl, "if state.applying then\n\t\t\t\t\treturn", 1, true) ~= nil, "applying guard")
			t.ok(string.find(ctl, "if button.Position ~= position then", 1, true) ~= nil, "write only if changed (pos)")
			t.ok(string.find(ctl, "if button.Size ~= size then", 1, true) ~= nil, "write only if changed (size)")
			t.ok(string.find(ctl, "if state == nil or state.queued then", 1, true) ~= nil, "single defer")
			t.ok(
				string.find(ctl, "desired == nil or button.Position ~= desired.position", 1, true) ~= nil,
				"deferred signal of our own write not recorded as native"
			)
			t.eq(string.find(ctl, "RenderStepped", 1, true), nil, "no per-frame loop")
			t.eq(string.find(ctl, "Heartbeat", 1, true), nil, "no per-frame loop")
		end
	)

	t.test(
		"qa: PC·게임패드 — TouchEnabled가 아니면 ⚙·편집·배치가 아무것도 안 만들어요",
		function()
			local settings = fs.readFile("src/client/ui/SettingsButton.luau")
			local guard = string.find(settings, "if not UserInputService.TouchEnabled then\n\t\treturn", 1, true)
			local gui = string.find(settings, 'Instance.new("ScreenGui")', 1, true)
			t.ok(guard ~= nil and gui ~= nil and guard < gui, "settings guard before gui")
			local ctl = fs.readFile("src/client/input/TouchLayoutController.luau")
			local cguard = string.find(ctl, "if not UserInputService.TouchEnabled then", 1, true)
			local cgui = string.find(ctl, 'Instance.new("ScreenGui")', 1, true)
			t.ok(cguard ~= nil and cgui ~= nil and cguard < cgui, "controller guard before gui")
			local editor = fs.readFile("src/client/ui/TouchLayoutEditor.luau")
			t.ok(string.find(editor, "not UserInputService.TouchEnabled", 1, true) ~= nil, "editor guard")
			local controller = loadLockController()
			t.eq(controller.current(), nil)
			t.eq(controller.isEditing(), false)
		end
	)
end
