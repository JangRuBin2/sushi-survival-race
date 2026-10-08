--!strict
-- m3-09: 장애물 소리 (MapSfxLogic 간격 제한, cue 표, 맵 호출 위치, 클라이언트 재생) + 통합 수정 몇 가지

local fs = require("@lune/fs")

local FakeSfxEnv = require("./lib/FakeSfxEnv")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)
local MapSfxLogic = RobloxRequire.require(Shared.maps.MapSfxLogic)
local MapSfx = RobloxRequire.require(Shared.maps.MapSfx)

-- 스펙 범위 1 표: 맵 파일 → 그 파일에서 부르는 cue
local MAP_CUES: { [string]: { string } } = {
	["src/shared/maps/RotatingBeltChopstick.luau"] = { "ChopstickWarn" },
	["src/shared/maps/SoySwampHazards.luau"] = { "SoySlow", "WasabiBoing" },
	["src/shared/maps/HotPlate.luau"] = { "HotTileSizzle", "TileVanish" },
	["src/shared/maps/SkewerShowdown.luau"] = { "SkewerWhoosh", "ChefHandWarn" },
}

local function soundsNamed(env: any, name: string): { any }
	local list = {}
	for _, s in env.sounds() do
		if s.Name == name then
			table.insert(list, s)
		end
	end
	return list
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 간격 제한
	t.test("AC1: 같은 (파트, cue)는 0.19초 뒤 막히고 0.2초 뒤 허용", function()
		t.eq(MapSfxLogic.MIN_INTERVAL, 0.2)
		local limiter = MapSfxLogic.newLimiter()
		local part = {}
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", 10), true)
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", 10.19), false)
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", 10.2), true)
		-- 0.2초 뒤 다시 울렸으니 그 시각부터 다시 0.2초
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", 10.39), false)
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", 10.4), true)
	end)

	t.test("AC1: 다른 파트나 다른 cue는 서로 막지 않아요", function()
		local limiter = MapSfxLogic.newLimiter()
		local a, b = {}, {}
		t.eq(MapSfxLogic.allow(limiter, a, "HotTileSizzle", 0), true)
		t.eq(MapSfxLogic.allow(limiter, b, "HotTileSizzle", 0.01), true)
		t.eq(MapSfxLogic.allow(limiter, a, "TileVanish", 0.02), true)
		t.eq(MapSfxLogic.allow(limiter, a, "HotTileSizzle", 0.03), false)
	end)

	t.test("AC1: 기록이 쌓이지 않아요 (오래된 항목은 정리)", function()
		local limiter = MapSfxLogic.newLimiter()
		local now = 0
		for i = 1, 2000 do
			MapSfxLogic.allow(limiter, { i }, "TileVanish", now)
			now += 0.01
		end
		-- 정리는 1초마다: 남는 건 최근 1초 + 간격 안의 것뿐
		t.ok(MapSfxLogic.size(limiter) <= 130, `size {MapSfxLogic.size(limiter)}`)
		MapSfxLogic.allow(limiter, "later", "TileVanish", now + 5)
		t.eq(MapSfxLogic.size(limiter), 1)
	end)

	t.test("marks·crossedMark: 꼬치가 빨라지는 순간을 한 번씩만", function()
		local marks = MapSfxLogic.marks(10, 60, 10)
		t.eq(marks, { 10, 20, 30, 40, 50, 60 })
		t.eq(MapSfxLogic.crossedMark(9.9, 10, marks), true)
		t.eq(MapSfxLogic.crossedMark(10, 10.1, marks), false)
		t.eq(MapSfxLogic.crossedMark(59.95, 60.01, marks), true)
		t.eq(MapSfxLogic.crossedMark(60.01, 70, marks), false)
		t.eq(MapSfxLogic.marks(0, 1, 0), {})
	end)

	---------------------------------------------------------------- AC2 cue 표
	t.test("AC2: 장애물 cue가 모두 SfxCues·SfxLibrary에 있어요", function()
		for _, cues in MAP_CUES do
			for _, cue in cues do
				t.ok(SfxCues.isEffect(cue), `SfxCues {cue}`)
				local entry = SfxLibrary.get(cue)
				t.ok(entry ~= nil and entry.group == "Sfx", `SfxLibrary {cue}`)
			end
		end
	end)

	t.test("맵 파일은 표의 순간에 MapSfx.play를 불러요 (소리 호출만)", function()
		for path, cues in MAP_CUES do
			local source = fs.readFile(path)
			t.ok(string.find(source, "require(script.Parent.MapSfx)", 1, true) ~= nil, `{path} requires MapSfx`)
			for _, cue in cues do
				t.ok(string.find(source, `"{cue}")`, 1, true) ~= nil, `{path} plays {cue}`)
			end
		end
	end)

	t.test("MapSfx: Lune에서 require 안전, id 없는 cue·파트 없음은 조용히 넘어가요", function()
		t.eq(type(MapSfx.play), "function")
		MapSfx.play(nil, "ChopstickWarn") -- id nil
		MapSfx.play(nil, "WasabiBoing") -- 파트 없음
	end)

	t.test("Remotes: MapSfx가 RemoteEvent 목록에 있어요", function()
		local source = fs.readFile("src/shared/Remotes.luau")
		local events = string.match(source, "local EVENTS = (%b{})") :: string
		t.ok(string.find(events, '"MapSfx"', 1, true) ~= nil, "MapSfx in EVENTS")
	end)

	---------------------------------------------------------------- 클라이언트 재생 (가짜 환경)
	t.test(
		"클라이언트: MapSfx 방송을 받으면 그 위치에서 소리가 나요 (pitch 적용, Sfx 그룹)",
		function()
			local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
			env.module.start({})
			env.events.MapSfx:Fire("WasabiBoing", nil, FakeSfxEnv.vector3(1, 2, 3))
			local list = soundsNamed(env, "WasabiBoing")
			t.eq(#list, 1)
			local sound = list[1]
			local entry = SfxLibrary.get("WasabiBoing") :: any
			t.ok(math.abs(sound.PlaybackSpeed - entry.pitch) <= entry.pitch * (entry.pitchJitter or 0) + 1e-6, "pitch")
			t.eq(sound.SoundGroup, env.soundService:FindFirstChild("Sfx"))
			t.eq(sound.Parent.WorldPosition.X, 1)
			-- 이상한 인자는 무시
			env.now += 1
			env.events.MapSfx:Fire(42, nil, FakeSfxEnv.vector3(0, 0, 0))
			env.events.MapSfx:Fire("WasabiBoing", nil, "nowhere")
			t.eq(#soundsNamed(env, "WasabiBoing"), 1)
		end
	)

	t.test(
		"클라이언트: 조작 버튼(TouchGui·ContextActionGui·NoClickSfx)은 클릭음이 없어요",
		function()
			local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
			env.module.start({})
			local function button(screenName: string, attribute: boolean?): any
				local screen = FakeSfxEnv.newInstance("ScreenGui")
				screen.Name = screenName
				if attribute then
					screen:SetAttribute("NoClickSfx", true)
				end
				local b = FakeSfxEnv.newInstance("ImageButton")
				b.Parent = screen
				screen.Parent = env.playerGui
				return b
			end
			for _, b in { button("TouchGui"), button("ContextActionGui"), button("DiveGui", true) } do
				env.now += 1
				b.Activated:Fire()
			end
			t.eq(#soundsNamed(env, "ButtonClick"), 0)
			env.now += 1
			button("Lobby").Activated:Fire()
			t.eq(#soundsNamed(env, "ButtonClick"), 1)
		end
	)

	t.test(
		"클라이언트: 10초 수명 때 아직 울리는 긴 소리는 남은 길이만큼 더 기다려요",
		function()
			local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
			env.module.start({})
			env.module.play("Chomp")
			local sound = soundsNamed(env, "Chomp")[1]
			sound.IsPlaying = true
			sound.TimeLength = 14
			sound.TimePosition = 10
			sound.PlaybackSpeed = 1
			env.runDelayed(env.now + 10)
			t.ok(not sound.Destroyed, "still playing at 10s")
			env.runDelayed(env.now + 20)
			t.ok(sound.Destroyed, "destroyed after its length")
		end
	)

	---------------------------------------------------------------- Config.Fx 튜닝 자리
	t.test("Config.Fx: 옮긴 튜닝 값이 원래 값 그대로", function()
		t.eq(Config.Fx.EliminationMaxConcurrent, 6)
		t.eq(Config.Fx.SfxVolume, 0.7)
		t.eq(Config.Fx.MusicVolume, 0.3)
		t.eq(Config.Fx.SfxMaxDistance, 120)
		t.eq(Config.Fx.SfxMaxActive, 16)
		t.eq(Config.Fx.MapSfxMinInterval, 0.2)
		t.ok(Config.Fx.SpectateHoldMargin > 0 and Config.Fx.SpectateHoldMargin < Config.Match.EliminationCutscene)
		t.eq(Config.DEBUG.forceMapPlan, nil)
	end)
end
