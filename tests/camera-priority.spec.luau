--!strict
-- m3-01 기반: 카메라 우선순위(CameraPriority), M3 Config 값, Attributes·SfxCues 상수

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local CameraPriority = RobloxRequire.require(Shared.CameraPriority)
local Config = RobloxRequire.require(Shared.Config)
local Attributes = RobloxRequire.require(Shared.Attributes)
local SfxCues = RobloxRequire.require(Shared.SfxCues)

return function(t: Test.Test)
	t.test("AC1: 우선순위가 높은 owner가 이겨요", function()
		local spectate = { owner = "Spectate", priority = 10 }
		local intro = { owner = "Intro", priority = 30 }
		t.eq(CameraPriority.pick({ spectate, intro }), "Intro")
		t.eq(CameraPriority.pick({ intro, spectate }), "Intro")
		t.eq(CameraPriority.pick({ spectate }), "Spectate")
	end)

	t.test("AC1: 빈 목록이면 nil", function()
		t.eq(CameraPriority.pick({}), nil)
	end)

	t.test("AC1: 같은 우선순위면 나중에 요청한 owner", function()
		t.eq(CameraPriority.pick({ { owner = "A", priority = 20 }, { owner = "B", priority = 20 } }), "B")
		t.eq(
			CameraPriority.pick({
				{ owner = "A", priority = 20 },
				{ owner = "B", priority = 20 },
				{ owner = "C", priority = 10 },
			}),
			"B"
		)
	end)

	t.test("AC2: M3 Config 값", function()
		t.ok(type(Config.Dive) == "table", "Config.Dive")
		for _, key in { "Cooldown", "LandingStun", "ForwardSpeed", "UpSpeed", "MaxFlightTime" } do
			t.ok(type((Config.Dive :: any)[key]) == "number", `Config.Dive.{key}`)
		end
		t.ok(type(Config.Grab) == "table", "Config.Grab")
		for _, key in
			{
				"Range",
				"FrontDot",
				"BreakRange",
				"MaxHold",
				"TargetSpeedMultiplier",
				"GrabberSpeedMultiplier",
				"Cooldown",
				"Immunity",
				"InputMinInterval",
			}
		do
			t.ok(type((Config.Grab :: any)[key]) == "number", `Config.Grab.{key}`)
		end
		t.eq(Config.Appearance.Default, "tamago")
		t.ok(type(Config.Match.VictoryCutscene) == "number", "VictoryCutscene")
		t.ok(Config.Match.VictoryCutscene < Config.Match.VictoryDuration, "VictoryCutscene < VictoryDuration")
		t.eq(Config.DEBUG.forceMapPlan, nil)
	end)

	t.test("AC3: Attributes 이름은 서로 다른 문자열", function()
		local seen: { [string]: boolean } = {}
		local count = 0
		for key, value in Attributes :: { [string]: any } do
			t.ok(type(value) == "string" and #value > 0, `Attributes.{key}`)
			t.ok(not seen[value], `duplicate attribute name {value}`)
			seen[value] = true
			count += 1
		end
		for _, key in
			{
				"AppearanceId",
				"GrabbedBy",
				"GrabbingUserId",
				"RoomId",
				"RoundIndex",
				"MapId",
				"KeepVisible",
				"NoClickSfx",
				"Title",
				"MoveExemptUntil",
				"PlaceRole",
				"Vip",
				"EliminationFx",
				"VictoryFx",
			}
		do
			t.ok((Attributes :: any)[key] ~= nil, `Attributes.{key}`)
		end
		t.eq(count, 16) -- m3-09: KeepVisible·NoClickSfx, m4-01: Title·MoveExemptUntil, m4-11: PlaceRole, m5-02: IsAdmin·AdminPreview, m5-03: Vip·EliminationFx·VictoryFx
	end)

	t.test("AC3: SfxCues에 확정 목록이 모두 있고 중복이 없어요", function()
		local effects = {
			"ButtonClick",
			"IntroWhoosh",
			"Go",
			"Qualified",
			"Eliminated",
			"VictoryFanfare",
			"Overtime", -- m5-01 결승 연장전 경적
			"ChopstickClack",
			"Struggle",
			"SoyDip",
			"Chomp",
			"SpeechPop",
			"ChefHand",
			"MouthFall",
			"DoorBurst",
			"Splash",
			"FishClap",
			"Dive",
			"DiveLand",
			"GrabStart",
			"Grabbed",
			"Knockdown",
			"ChopstickWarn",
			"WasabiBoing",
			"SoySlow",
			"HotTileSizzle",
			"TileVanish",
			"SkewerWhoosh",
			"ChefHandWarn",
			-- m5-03
			"TokenGet",
			"CodeRedeemed",
			"CatMeow",
			"Fireworks",
			"IkuraPop",
			"OilSplash",
			"FanGust",
			"JellyBoing",
			"BounceBoing", -- m5-14
			"BlockCreak", -- m5-16
			"CatToyBounce", -- m5-17
			"CatPawWarn", -- m5-17
			"CatPawSwipe", -- m5-17
		}
		local music = { "Lobby", "Round", "Final", "Victory" }
		for _, name in effects do
			t.ok(SfxCues.isEffect(name), `effect {name}`)
			t.ok(not SfxCues.isMusic(name), `effect {name} is not music`)
		end
		for _, name in music do
			t.ok(SfxCues.isMusic(name), `music {name}`)
		end
		local all = SfxCues.all()
		t.eq(#all, #effects + #music)
		local seen: { [string]: boolean } = {}
		for _, name in all do
			t.ok(not seen[name], `duplicate cue {name}`)
			seen[name] = true
		end
		t.ok(not SfxCues.isEffect("NoSuchCue"), "unknown cue")
	end)
end
