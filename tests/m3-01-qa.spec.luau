--!strict
-- m3-01 QA: CameraDirector 실제 동작(가짜 game/workspace로 불러옴), Sfx 껍데기, Config 값 범위,
-- 공용 파일(Remotes, default.project.json)의 M3 변경, 다른 M3 스펙이 기대하는 인터페이스.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local FakeSfxEnv = require("./lib/FakeSfxEnv")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local CameraPriority = RobloxRequire.require(Shared.CameraPriority)
local Config = RobloxRequire.require(Shared.Config)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)
local SushiBody = RobloxRequire.require(Shared.SushiBody)

-- 가짜 Roblox 환경에서 클라이언트 모듈 하나를 불러요. require는 ReplicatedStorage.Shared.<이름>만 지원해요.
type FakeEnv = {
	camera: any,
	humanoid: any,
	warnings: { string },
}

local function loadClientModule(path: string, sharedModules: { [string]: any }): (any, FakeEnv)
	local env: FakeEnv = {
		camera = { CameraType = "Custom", CameraSubject = nil, CFrame = nil },
		humanoid = { Name = "MyHumanoid" },
		warnings = {},
	}
	local character = {
		FindFirstChildOfClass = function(_self, className: string)
			return if className == "Humanoid" then env.humanoid else nil
		end,
	}
	local sharedFolder = setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
	local services = {
		Players = { LocalPlayer = { Character = character, UserId = 1 } },
		ReplicatedStorage = { Shared = sharedFolder },
	}
	local fakeGame = {
		GetService = function(_self, name: string)
			return assert(services[name], `no fake service {name}`)
		end,
	}
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			game = fakeGame,
			workspace = { CurrentCamera = env.camera },
			Enum = { CameraType = { Custom = "Custom", Scriptable = "Scriptable" } },
			warn = function(...)
				local parts = {}
				for _, v in { ... } do
					table.insert(parts, tostring(v))
				end
				table.insert(env.warnings, table.concat(parts, " "))
			end,
			require = function(target: any)
				local name = target.__shared
				return assert(sharedModules[name], `no fake shared module {name}`)
			end,
		},
	})
	return chunk(), env
end

local function newDirector(): (any, FakeEnv)
	return loadClientModule("src/client/CameraDirector.luau", { CameraPriority = CameraPriority })
end

return function(t: Test.Test)
	-------------------------------------------------------------------- CameraPriority
	t.test("CameraPriority.pick: 입력 목록을 바꾸지 않아요", function()
		local requests = { { owner = "A", priority = 10 }, { owner = "B", priority = 30 } }
		CameraPriority.pick(requests)
		t.eq(#requests, 2)
		t.eq(requests[1].owner, "A")
		t.eq(requests[2].priority, 30)
	end)

	t.test(
		"CameraPriority.pick: 먼저 요청한 높은 우선순위가 나중의 낮은 요청을 이겨요",
		function()
			t.eq(
				CameraPriority.pick({
					{ owner = "Elimination", priority = 40 },
					{ owner = "Spectate", priority = 10 },
					{ owner = "Intro", priority = 30 },
				}),
				"Elimination"
			)
		end
	)

	t.test("CameraPriority.pick: 다섯 owner 모두 있으면 VictoryCutscene", function()
		t.eq(
			CameraPriority.pick({
				{ owner = "VictoryCutscene", priority = 50 },
				{ owner = "Spectate", priority = 10 },
				{ owner = "Victory", priority = 20 },
				{ owner = "Intro", priority = 30 },
				{ owner = "Elimination", priority = 40 },
			}),
			"VictoryCutscene"
		)
	end)

	-------------------------------------------------------------------- CameraDirector
	t.test("CameraDirector.Priority 값이 스펙과 같아요", function()
		local director = newDirector()
		t.eq(director.Priority, { Spectate = 10, Victory = 20, Intro = 30, Elimination = 40, VictoryCutscene = 50 })
	end)

	t.test("CameraDirector: 높은 요청만 apply, release하면 다음 owner의 apply를 다시 불러요", function()
		local director, env = newDirector()
		local calls: { string } = {}
		director.request("Spectate", director.Priority.Spectate, function(camera)
			table.insert(calls, "Spectate")
			camera.CameraSubject = "target"
		end)
		t.eq(director.current(), "Spectate")
		t.eq(env.camera.CameraSubject, "target")

		director.request("Intro", director.Priority.Intro, function(camera)
			table.insert(calls, "Intro")
			camera.CameraType = "Scriptable"
		end)
		t.eq(director.current(), "Intro")
		t.ok(director.isActive("Intro"), "Intro active")
		t.ok(not director.isActive("Spectate"), "Spectate not active")

		-- 낮은 owner가 다시 요청해도 카메라를 건드리지 않아요
		director.request("Spectate", director.Priority.Spectate, function()
			table.insert(calls, "Spectate2")
		end)
		t.eq(calls, { "Spectate", "Intro" })

		director.release("Intro")
		t.eq(director.current(), "Spectate")
		t.eq(calls, { "Spectate", "Intro", "Spectate2" }) -- 바뀐 apply로 다시 맞춰요
	end)

	t.test("CameraDirector: 아무도 없으면 기본 카메라(Custom, 내 Humanoid)로 돌려요", function()
		local director, env = newDirector()
		director.request("Elimination", director.Priority.Elimination, function(camera)
			camera.CameraType = "Scriptable"
			camera.CameraSubject = "doll"
		end)
		t.eq(env.camera.CameraType, "Scriptable")
		director.release("Elimination")
		t.eq(director.current(), nil)
		t.eq(env.camera.CameraType, "Custom")
		t.eq(env.camera.CameraSubject, env.humanoid)
	end)

	t.test(
		"CameraDirector: 1등 owner가 다시 요청하면 apply를 또 불러요 (CameraSubject 되돌림 대응)",
		function()
			local director = newDirector()
			local n = 0
			local function apply()
				n += 1
			end
			director.request("Spectate", 10, apply)
			director.request("Spectate", 10, apply)
			director.request("Spectate", 10, apply)
			t.eq(n, 3)
		end
	)

	t.test("CameraDirector: 요청하지 않은 owner를 release해도 아무 일 없어요", function()
		local director, env = newDirector()
		local n = 0
		director.request("Intro", 30, function()
			n += 1
		end)
		env.camera.CameraType = "Scriptable"
		director.release("Nobody")
		director.release("Spectate")
		t.eq(director.current(), "Intro")
		t.eq(n, 1)
		t.eq(env.camera.CameraType, "Scriptable") -- 기본 카메라로 돌리지 않았어요
	end)

	t.test("CameraDirector: 낮은 owner를 release해도 1등 apply를 다시 부르지 않아요", function()
		local director = newDirector()
		local introCalls = 0
		director.request("Spectate", 10, function() end)
		director.request("Intro", 30, function()
			introCalls += 1
		end)
		director.release("Spectate")
		t.eq(director.current(), "Intro")
		t.eq(introCalls, 1)
	end)

	t.test(
		"CameraDirector: 같은 우선순위면 나중에 요청한 owner, 재요청은 순서를 바꾸지 않아요",
		function()
			local director = newDirector()
			director.request("A", 20, function() end)
			director.request("B", 20, function() end)
			t.eq(director.current(), "B")
			director.request("A", 20, function() end) -- 처음 요청 순서 유지 (CameraDirector 문서)
			t.eq(director.current(), "B")
			director.release("B")
			t.eq(director.current(), "A")
		end
	)

	t.test("CameraDirector: 우선순위를 바꿔 다시 요청하면 1등이 바뀌어요", function()
		local director = newDirector()
		local calls: { string } = {}
		director.request("Spectate", 10, function()
			table.insert(calls, "S")
		end)
		director.request("Intro", 30, function()
			table.insert(calls, "I")
		end)
		director.request("Spectate", 60, function()
			table.insert(calls, "S2")
		end)
		t.eq(director.current(), "Spectate")
		t.eq(calls, { "S", "I", "S2" })
	end)

	t.test("CameraDirector: apply가 에러를 내도 중재는 계속돼요 (경고만)", function()
		local director, env = newDirector()
		director.request("Broken", 40, function()
			error("boom")
		end)
		t.eq(director.current(), "Broken")
		t.eq(#env.warnings, 1)
		t.ok(string.find(env.warnings[1], "Broken", 1, true) ~= nil, "warning names owner")
		director.release("Broken")
		t.eq(director.current(), nil)
		t.eq(env.camera.CameraType, "Custom")
	end)

	-------------------------------------------------------------------- Sfx 껍데기
	t.test(
		"Sfx 껍데기: start 전에도 에러 없이 무시, 모르는 이름은 이름당 한 번만 경고",
		function()
			-- m3-08 QA: Sfx가 실제 구현이 되면서 SoundService·TweenService 등이 필요해져 FakeSfxEnv로 불러요 (기대값은 그대로)
			local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
			local Sfx = env.module
			Sfx.play("Chomp")
			Sfx.play("Chomp", { Position = 0 })
			Sfx.setMusic("Final")
			Sfx.setMusic(nil)
			t.eq(#env.warnings, 0)
			Sfx.play("NoSuchCue")
			Sfx.play("NoSuchCue")
			Sfx.play("OtherCue")
			t.eq(#env.warnings, 2)
			Sfx.setMusic("Chomp") -- 효과음 이름은 음악이 아니에요
			Sfx.setMusic("Chomp")
			t.eq(#env.warnings, 3)
			Sfx.play("Lobby") -- 음악 이름은 효과음이 아니에요
			t.eq(#env.warnings, 4)
			Sfx.start({})
		end
	)

	-------------------------------------------------------------------- Config
	t.test("Config: M2 연출 시간은 그대로, 우승 단계만 10초", function()
		t.eq(Config.Match.VictoryDuration, 10)
		t.eq(Config.Match.VictoryCutscene, 6)
		t.eq(Config.Match.EliminationCutscene, 3)
		t.eq(Config.Match.IntroDuration, 3)
	end)

	t.test("Config.Dive·Grab 값이 스펙 기본값이고 범위가 말이 돼요", function()
		t.eq(Config.Dive, { Cooldown = 1.5, LandingStun = 0.5, ForwardSpeed = 40, UpSpeed = 16, MaxFlightTime = 1.0 })
		t.eq(Config.Grab, {
			Range = 5,
			FrontDot = 0.5,
			BreakRange = 9,
			MaxHold = 2,
			TargetSpeedMultiplier = 0.5,
			GrabberSpeedMultiplier = 0.7,
			Cooldown = 1.5,
			Immunity = 1.0,
			InputMinInterval = 0.1,
		})
		local g = Config.Grab
		t.ok(g.BreakRange > g.Range, "BreakRange > Range")
		t.ok(g.FrontDot >= -1 and g.FrontDot <= 1, "FrontDot in [-1, 1]")
		t.ok(g.TargetSpeedMultiplier > 0 and g.TargetSpeedMultiplier <= 1, "TargetSpeedMultiplier")
		t.ok(g.GrabberSpeedMultiplier > 0 and g.GrabberSpeedMultiplier <= 1, "GrabberSpeedMultiplier")
		t.ok(g.InputMinInterval > 0, "InputMinInterval > 0")
		t.ok(Config.Dive.LandingStun < Config.Dive.Cooldown, "LandingStun < Cooldown")
	end)

	-------------------------------------------------------------------- 공용 파일
	t.test("Remotes: GrabInput이 RemoteEvent 목록에 있고 RemoteFunction 목록에는 없어요", function()
		local source = fs.readFile("src/shared/Remotes.luau")
		local events = string.match(source, "local EVENTS = (%b{})") :: string
		local functions = string.match(source, "local FUNCTIONS = (%b{})") :: string
		t.ok(events and string.find(events, '"GrabInput"', 1, true) ~= nil, "GrabInput in EVENTS")
		t.ok(functions and string.find(functions, "GrabInput", 1, true) == nil, "GrabInput not in FUNCTIONS")
		t.ok(string.find(source, "GrabInput(holding: boolean)", 1, true) ~= nil, "documented signature")
	end)

	t.test("default.project.json: Shift Lock 끄기, 아바타 불러오지 않기", function()
		local project = serde.decode("json", fs.readFile("default.project.json"))
		local props = project.tree.StarterPlayer["$properties"]
		t.eq(props.EnableMouseLockOption, false)
		t.eq(props.LoadCharacterAppearance, false)
		t.eq(props.CharacterJumpPower, 50) -- M2 값 유지
	end)

	t.test(
		"SushiBody: lune에서 불러올 수 있고 layout은 목록을 돌려줘요 (m3-02 테스트 전제)",
		function()
			t.eq(type(SushiBody.layout("tamago")), "table")
			t.eq(type(SushiBody.build), "function")
		end
	)

	t.test(
		"클라이언트 init이 껍데기 컨트롤러를 모두 등록하고 Sfx를 먼저 시작해요",
		function()
			local source = fs.readFile("src/client/init.client.luau")
			local list = string.match(source, "local CONTROLLERS = (%b{})") :: string
			t.ok(list ~= nil, "CONTROLLERS list")
			local order = {
				"script.Sfx",
				"script.ui.HudController",
				"script.ui.SpectateController",
				"script.fx.CharacterFxController",
				"script.fx.EliminationCutsceneController",
				"script.fx.IntroController",
				"script.fx.VictoryCutsceneController",
				"script.input.DiveController",
				"script.input.GrabController",
			}
			for _, name in order do
				t.ok(string.find(list, `require({name})`, 1, true) ~= nil, `registers {name}`)
			end
			local sfxAt = string.find(list, "script.Sfx", 1, true) :: number
			local uiAt = string.find(list, "script.ui", 1, true) :: number
			t.ok(sfxAt < uiAt, "Sfx first")
			for _, file in
				{
					"src/client/fx/CharacterFxController.luau",
					"src/client/fx/EliminationCutsceneController.luau",
					"src/client/fx/IntroController.luau",
					"src/client/fx/VictoryCutsceneController.luau",
					"src/client/input/DiveController.luau",
					"src/client/input/GrabController.luau",
				}
			do
				t.ok(string.find(fs.readFile(file), "%.start%(_?gui: Instance%)") ~= nil, `{file} has start(gui)`)
			end
		end
	)

	t.test("서버 init이 AppearanceService·GrabService를 등록해요", function()
		local source = fs.readFile("src/server/init.server.luau")
		t.ok(string.find(source, "require(script.AppearanceService)", 1, true) ~= nil, "AppearanceService")
		t.ok(string.find(source, "require(script.GrabService)", 1, true) ~= nil, "GrabService")
		for _, file in { "src/server/AppearanceService.luau", "src/server/GrabService.luau" } do
			local s = fs.readFile(file)
			t.ok(string.find(s, "%.init%(%)") ~= nil, `{file} init()`)
			t.ok(string.find(s, "%.start%(%)") ~= nil, `{file} start()`)
		end
	end)
end
