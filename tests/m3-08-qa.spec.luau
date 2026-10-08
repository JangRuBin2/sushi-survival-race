--!strict
-- m3-08 QA: 클라이언트 Sfx.luau를 가짜 Roblox 환경(tests/lib/FakeSfxEnv)에서 실제로 돌려 봐요.
-- start 전 무시, 모르는 cue 경고, 같은 cue 0.05초 제한, 동시 16개, 다 울린 Sound 정리, 3D 위치,
-- 배경음 전환(서버 방송 순서 그대로), 음소거 3단계, 버튼 클릭음, 통과음. 그리고 SfxLibrary의 기본 소리 경로.

local FakeSfxEnv = require("./lib/FakeSfxEnv")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)

-- 배경음 4곡에 id를 채운 SfxLibrary 복사본 (기본은 무음이라 전환을 보려고)
local function libraryWithMusic(): any
	local lib: any = { Entries = {}, musicFor = SfxLibrary.musicFor }
	for name, entry in SfxLibrary.Entries do
		lib.Entries[name] = table.clone(entry)
	end
	for _, name in SfxCues.Music do
		lib.Entries[name].id = `rbxassetid://{name}`
	end
	function lib.get(name: string)
		return lib.Entries[name]
	end
	return lib
end

local function started(library: any?): FakeSfxEnv.Env
	local env = FakeSfxEnv.load(SfxCues, library or SfxLibrary)
	env.module.start({})
	return env
end

local function soundsNamed(env: FakeSfxEnv.Env, name: string): { any }
	local list = {}
	for _, s in env.sounds() do
		if s.Name == name then
			table.insert(list, s)
		end
	end
	return list
end

local function musicSounds(env: FakeSfxEnv.Env): { any }
	local list = {}
	for _, s in env.soundService:GetChildren() do
		if s.ClassName == "Sound" and string.sub(s.Name, 1, 6) == "Music_" and not s.Destroyed then
			table.insert(list, s)
		end
	end
	return list
end

local function group(env: FakeSfxEnv.Env, name: string): any
	local g = env.soundService:FindFirstChild(name)
	assert(g and g.ClassName == "SoundGroup", `SoundGroup {name}`)
	return g
end

-- 기본 소리 11개 (공개 Roblox-Client-Tracker rbxManifest.txt의 content\sounds, 2026-10-08 QA가 직접 받아 확인)
local KNOWN_BUILTIN_SOUNDS = {
	"rbxasset://sounds/action_falling.ogg",
	"rbxasset://sounds/action_footsteps_plastic.mp3",
	"rbxasset://sounds/action_get_up.mp3",
	"rbxasset://sounds/action_jump.mp3",
	"rbxasset://sounds/action_jump_land.mp3",
	"rbxasset://sounds/action_swim.mp3",
	"rbxasset://sounds/impact_explosion_03.mp3",
	"rbxasset://sounds/impact_water.mp3",
	"rbxasset://sounds/oof.ogg",
	"rbxasset://sounds/ouch.ogg",
	"rbxasset://sounds/volume_slider.ogg",
}

return function(t: Test.Test)
	-------------------------------------------------------------------- SfxLibrary
	t.test(
		"SfxLibrary: rbxasset:// 경로는 모두 클라이언트 매니페스트에 있는 기본 소리",
		function()
			for name, entry in SfxLibrary.Entries do
				local id = entry.id
				if id ~= nil and string.sub(id, 1, 11) == "rbxasset://" then
					t.ok(table.find(KNOWN_BUILTIN_SOUNDS, id) ~= nil, `{name}: {id} not in client manifest`)
				end
			end
		end
	)

	t.test(
		"SfxLibrary: 배경음 4개는 기본 무음, 스펙의 m3-08 cue(ButtonClick, Qualified)는 소리가 있음",
		function()
			for _, name in SfxCues.Music do
				t.eq(SfxLibrary.get(name).id, nil, name)
			end
			t.ok(SfxLibrary.get("ButtonClick").id ~= nil, "ButtonClick")
			t.ok(SfxLibrary.get("Qualified").id ~= nil, "Qualified")
		end
	)

	t.test(
		"musicFor: 우승 단계는 roundIndex가 없어도 Victory, 결승 건너뛰기(1→3/3)도 Final",
		function()
			t.eq(SfxLibrary.musicFor(true, "Victory"), "Victory")
			t.eq(SfxLibrary.musicFor(true, "Victory", 2, 4), "Victory")
			t.eq(SfxLibrary.musicFor(true, "RoundActive", 3, 3), "Final")
			t.eq(SfxLibrary.musicFor(true, "Starting", 1, 3), "Round")
			t.eq(SfxLibrary.musicFor(false, "Victory", 3, 3), "Lobby")
		end
	)

	-------------------------------------------------------------------- start 전
	t.test("start 전: play/setMusic은 Sound를 만들지 않고 경고도 없음", function()
		local env = FakeSfxEnv.load(SfxCues, libraryWithMusic())
		env.module.play("Chomp")
		env.module.play("Chomp", FakeSfxEnv.vector3(0, 0, 0))
		env.module.setMusic("Lobby")
		t.eq(#env.sounds(), 0)
		t.eq(#env.soundService:GetChildren(), 0)
		t.eq(#env.warnings, 0)
	end)

	-------------------------------------------------------------------- 경고
	t.test("모르는 cue는 이름당 한 번 경고, id 없는 cue는 조용히 무시", function()
		local env = started()
		env.module.play("NoSuchCue")
		env.module.play("NoSuchCue")
		t.eq(#env.warnings, 1)
		env.module.play("Lobby") -- 배경음 이름은 효과음이 아님
		t.eq(#env.warnings, 2)
		env.module.setMusic("Chomp")
		t.eq(#env.warnings, 3)
		env.module.play("VictoryFanfare") -- id = nil
		env.module.play("ChopstickWarn")
		t.eq(#env.warnings, 3)
		t.eq(#env.sounds(), 0)
	end)

	-------------------------------------------------------------------- start
	t.test("start: SoundGroup Sfx 0.7 / Music 0.3, SoundGui(ResetOnSpawn=false)에 음소거 버튼", function()
		local env = started()
		t.eq(group(env, "Sfx").Volume, 0.7)
		t.eq(group(env, "Music").Volume, 0.3)
		local screen = env.playerGui:FindFirstChild("SoundGui")
		t.ok(screen ~= nil, "SoundGui")
		t.eq(screen.ResetOnSpawn, false)
		local button = screen:FindFirstChild("MuteButton")
		t.ok(button ~= nil and button:IsA("GuiButton"), "MuteButton")
		t.eq(button.Text, "🔊 소리 켬")
	end)

	t.test("start를 두 번 불러도 그룹·버튼이 하나씩", function()
		local env = started()
		env.module.start({})
		local groups, screens = 0, 0
		for _, c in env.soundService:GetChildren() do
			if c.ClassName == "SoundGroup" then
				groups += 1
			end
		end
		for _, c in env.playerGui:GetChildren() do
			if c.Name == "SoundGui" then
				screens += 1
			end
		end
		t.eq(groups, 2)
		t.eq(screens, 1)
	end)

	-------------------------------------------------------------------- play
	t.test("play 2D: SoundService에 Sfx 그룹·RollOff 120·pitch±jitter, 끝나면 지워짐", function()
		local env = started()
		env.module.play("ButtonClick")
		local sounds = soundsNamed(env, "ButtonClick")
		t.eq(#sounds, 1)
		local s = sounds[1]
		t.eq(s.Parent, env.soundService)
		t.eq(s.SoundGroup, group(env, "Sfx"))
		t.eq(s.SoundId, SfxLibrary.get("ButtonClick").id)
		t.eq(s.RollOffMaxDistance, 120)
		t.ok(s.Playing, "playing")
		local entry = SfxLibrary.get("ButtonClick")
		local base = entry.pitch or 1
		local jitter = entry.pitchJitter or 0
		t.ok(
			s.PlaybackSpeed >= base * (1 - jitter) - 1e-9 and s.PlaybackSpeed <= base * (1 + jitter) + 1e-9,
			`speed {s.PlaybackSpeed}`
		)
		s.Ended:Fire()
		t.ok(s.Destroyed, "destroyed after Ended")
		t.eq(#env.sounds(), 0)
	end)

	t.test("play Vector3: Terrain 아래 임시 Attachment, 끝나면 Attachment도 지워짐", function()
		local env = started()
		env.module.play("SoyDip", FakeSfxEnv.vector3(1, 2, 3))
		local attachments = env.terrain:GetChildren()
		t.eq(#attachments, 1)
		local a = attachments[1]
		t.eq(a.ClassName, "Attachment")
		t.eq(a.WorldPosition.X, 1)
		local s = a:GetChildren()[1]
		t.eq(s.ClassName, "Sound")
		t.eq(s.RollOffMaxDistance, 120)
		s.Ended:Fire()
		t.eq(#env.terrain:GetChildren(), 0)
	end)

	t.test(
		"play BasePart: 파트 아래에서 재생, 파트가 먼저 사라져도 동시 개수가 돌아옴",
		function()
			local env = started()
			local parts = {}
			for i = 1, 16 do
				local part = FakeSfxEnv.newInstance("Part")
				part.Parent = env.terrain
				parts[i] = part
				env.module.play("Splash", part)
				env.now += 0.1
			end
			t.eq(parts[1]:GetChildren()[1].ClassName, "Sound")
			-- 16개가 울리는 중이라 17번째는 버려짐
			env.module.play("Chomp")
			t.eq(#soundsNamed(env, "Chomp"), 0)
			-- 파트 하나가 사라지면 자리가 생김
			parts[1]:Destroy()
			env.module.play("Chomp")
			t.eq(#soundsNamed(env, "Chomp"), 1)
		end
	)

	t.test("play: BasePart가 아닌 인스턴스면 아무것도 만들지 않고 개수도 안 셈", function()
		local env = started()
		local folder = FakeSfxEnv.newInstance("Folder")
		for _ = 1, 20 do
			env.module.play("Splash", folder)
			env.now += 0.1
		end
		t.eq(#folder:GetChildren(), 0)
		env.module.play("Chomp")
		t.eq(#soundsNamed(env, "Chomp"), 1)
	end)

	t.test("같은 cue는 0.05초 안에 다시 울리지 않음, 다른 cue는 상관없음", function()
		local env = started()
		env.module.play("Chomp")
		env.now += 0.03
		env.module.play("Chomp")
		t.eq(#soundsNamed(env, "Chomp"), 1)
		env.module.play("SoyDip")
		t.eq(#soundsNamed(env, "SoyDip"), 1)
		env.now += 0.03 -- 첫 소리부터 0.06초
		env.module.play("Chomp")
		t.eq(#soundsNamed(env, "Chomp"), 2)
	end)

	t.test("동시 효과음 최대 16개, 하나 끝나면 다시 울림", function()
		local env = started()
		for _ = 1, 20 do
			env.module.play("Chomp")
			env.now += 0.1
		end
		t.eq(#env.sounds(), 16)
		env.sounds()[1].Ended:Fire()
		env.module.play("Chomp")
		t.eq(#env.sounds(), 16)
	end)

	t.test(
		"Ended가 안 와도 10초 뒤 지워지고, 늦게 온 Ended로 개수가 두 번 빠지지 않음",
		function()
			local env = started()
			local first = nil
			for i = 1, 16 do
				env.module.play("Chomp")
				if i == 1 then
					first = env.sounds()[1]
				end
				env.now += 0.1
			end
			env.runDelayed(env.now + 10)
			t.eq(#env.sounds(), 0)
			t.ok(first.Destroyed, "first destroyed by lifetime")
			first.Ended:Fire() -- 늦게 온 Ended
			-- 개수가 음수로 내려갔다면 17개 이상 울릴 거예요
			for _ = 1, 20 do
				env.module.play("Chomp")
				env.now += 0.1
			end
			t.eq(#env.sounds(), 16)
		end
	)

	-------------------------------------------------------------------- 배경음
	t.test(
		"setMusic: id 있는 곡은 Music 그룹·반복·0에서 페이드인, 같은 곡이면 그대로",
		function()
			local env = started(libraryWithMusic())
			-- start가 Lobby를 틀어요
			local list = musicSounds(env)
			t.eq(#list, 1)
			local lobby = list[1]
			t.eq(lobby.Name, "Music_Lobby")
			t.eq(lobby.Looped, true)
			t.eq(lobby.SoundGroup, group(env, "Music"))
			t.eq(lobby.Volume, 0)
			local fadeIn = env.tweens[#env.tweens]
			t.eq(fadeIn.object, lobby)
			t.eq(fadeIn.goal.Volume, SfxLibrary.get("Lobby").volume)
			local tweenCount = #env.tweens
			env.module.setMusic("Lobby")
			t.eq(#env.tweens, tweenCount)
			t.eq(#musicSounds(env), 1)
		end
	)

	t.test("setMusic: 바꾸면 이전 곡은 0으로 줄인 뒤 지워지고, nil이면 끔", function()
		local env = started(libraryWithMusic())
		local lobby = musicSounds(env)[1]
		env.module.setMusic("Round")
		local fadeOut = nil
		for _, tw in env.tweens do
			if tw.object == lobby and tw.goal.Volume == 0 then
				fadeOut = tw
			end
		end
		t.ok(fadeOut ~= nil and fadeOut.played, "lobby fade out")
		t.ok(not lobby.Destroyed, "still fading")
		fadeOut:finish()
		t.ok(lobby.Destroyed, "lobby destroyed after fade")
		local list = musicSounds(env)
		t.eq(#list, 1)
		t.eq(list[1].Name, "Music_Round")
		env.module.setMusic(nil)
		for _, tw in env.tweens do
			if tw.object == list[1] and tw.goal.Volume == 0 then
				tw:finish()
			end
		end
		t.eq(#musicSounds(env), 0)
	end)

	t.test(
		"배경음 흐름: 서버 순서(MatchPhase Starting이 RoomUpdated InMatch보다 먼저)대로 Lobby→Round→Final→Victory→Lobby",
		function()
			local env = started(libraryWithMusic())
			local function current(): string?
				-- 페이드 중인 곡은 무시하고 마지막에 만든 곡
				local list = musicSounds(env)
				local last = list[#list]
				return if last then string.sub(last.Name, 7) else nil
			end
			local room = { state = "Waiting" }
			local inMatch = { state = "InMatch" }
			env.events.RoomUpdated:Fire(room)
			t.eq(current(), "Lobby")
			-- RoomService.beginMatch는 markChanged를 defer하고 MatchService가 바로 Starting을 보내요
			env.events.MatchPhase:Fire({ phase = "Starting", roundIndex = 1, roundCount = 3 })
			t.eq(current(), "Lobby")
			env.events.RoomUpdated:Fire(inMatch)
			t.eq(current(), "Round")
			env.events.MatchPhase:Fire({ phase = "RoundIntro", roundIndex = 2, roundCount = 3 })
			t.eq(current(), "Round")
			env.events.MatchPhase:Fire({ phase = "RoundIntro", roundIndex = 3, roundCount = 3 })
			t.eq(current(), "Final")
			env.events.MatchPhase:Fire({ phase = "RoundResults", roundIndex = 3, roundCount = 3 })
			t.eq(current(), "Final")
			env.events.MatchPhase:Fire({ phase = "Victory" })
			t.eq(current(), "Victory")
			env.events.RoomUpdated:Fire(room) -- endMatch → Waiting
			t.eq(current(), "Lobby")
			-- 다음 판: 지난 판의 결승 단계가 남아 있지 않아요
			env.events.RoomUpdated:Fire(inMatch)
			t.eq(current(), "Round")
			env.events.RoomUpdated:Fire(nil) -- 방을 나감
			t.eq(current(), "Lobby")
		end
	)

	-------------------------------------------------------------------- 음소거
	t.test("음소거 3단계: 소리 켬 → 음악 끔 → 모두 끔 → 소리 켬", function()
		local env = started()
		local button = env.playerGui:FindFirstChild("SoundGui"):FindFirstChild("MuteButton")
		local sfx, music = group(env, "Sfx"), group(env, "Music")
		button.Activated:Fire()
		t.eq(button.Text, "🎵 음악 끔")
		t.eq(sfx.Volume, 0.7)
		t.eq(music.Volume, 0)
		button.Activated:Fire()
		t.eq(button.Text, "🔇 모두 끔")
		t.eq(sfx.Volume, 0)
		t.eq(music.Volume, 0)
		button.Activated:Fire()
		t.eq(button.Text, "🔊 소리 켬")
		t.eq(sfx.Volume, 0.7)
		t.eq(music.Volume, 0.3)
	end)

	-------------------------------------------------------------------- 버튼 클릭음
	t.test(
		"버튼 클릭음: start 전부터 있던 버튼과 나중에 생긴 버튼 모두, TextBox·Frame은 아님",
		function()
			local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
			local screen = FakeSfxEnv.newInstance("ScreenGui")
			local early = FakeSfxEnv.newInstance("TextButton")
			early.Parent = screen
			screen.Parent = env.playerGui
			env.module.start({})

			early.Activated:Fire()
			t.eq(#soundsNamed(env, "ButtonClick"), 1)

			-- 나중에 만든 화면: 자식을 먼저 붙이고 화면을 PlayerGui에 넣어도 잡혀요
			env.now += 1
			local later = FakeSfxEnv.newInstance("ScreenGui")
			local frame = FakeSfxEnv.newInstance("Frame")
			local image = FakeSfxEnv.newInstance("ImageButton")
			image.Parent = frame
			frame.Parent = later
			later.Parent = env.playerGui
			image.Activated:Fire()
			t.eq(#soundsNamed(env, "ButtonClick"), 2)

			local box = FakeSfxEnv.newInstance("TextBox")
			box.Parent = later
			t.eq(box.Activated:count(), 0)
			t.eq(frame.Activated:count(), 0)
		end
	)

	t.test(
		"버튼 클릭음: 같은 버튼을 다시 붙여도(재부모) 한 번 누르면 소리는 하나",
		function()
			local env = started()
			local screen = FakeSfxEnv.newInstance("ScreenGui")
			screen.Parent = env.playerGui
			local button = FakeSfxEnv.newInstance("TextButton")
			button.Parent = screen
			button.Parent = nil
			button.Parent = screen
			env.now += 1
			button.Activated:Fire()
			t.eq(#soundsNamed(env, "ButtonClick"), 1)
		end
	)

	-------------------------------------------------------------------- 통과음
	t.test("통과음: 내 Passed만 Qualified, 남의 Passed·내 Won/Eliminated는 아님", function()
		local env = started()
		env.events.PlayerResult:Fire({ userId = 2, result = "Passed", place = 1 })
		t.eq(#soundsNamed(env, "Qualified"), 0)
		env.events.PlayerResult:Fire({ userId = env.userId, result = "Won", place = 1 })
		env.events.PlayerResult:Fire({ userId = env.userId, result = "Eliminated", place = 3 })
		t.eq(#soundsNamed(env, "Qualified"), 0)
		env.events.PlayerResult:Fire({ userId = env.userId, result = "Passed", place = 2 })
		t.eq(#soundsNamed(env, "Qualified"), 1)
	end)
end
