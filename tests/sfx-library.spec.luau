--!strict
-- m3-08: SfxLibrary (cue → 소리 정보, 배경음 선택)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)

return function(t: Test.Test)
	t.test("AC1: SfxCues와 SfxLibrary의 이름이 같아요", function()
		for _, name in SfxCues.all() do
			t.ok(SfxLibrary.get(name) ~= nil, `library has {name}`)
		end
		for name in SfxLibrary.Entries do
			t.ok(SfxCues.isEffect(name) or SfxCues.isMusic(name), `cue list has {name}`)
		end
	end)

	t.test("AC2: 항목 모양 (볼륨, 그룹, 반복, id 형식)", function()
		for name, entry in SfxLibrary.Entries do
			t.ok(entry.volume >= 0 and entry.volume <= 1, `{name} volume`)
			t.ok(entry.group == "Sfx" or entry.group == "Music", `{name} group`)
			if SfxCues.isMusic(name) then
				t.eq(entry.group, "Music")
				t.eq(entry.looped, true)
			else
				t.eq(entry.group, "Sfx")
				t.ok(not entry.looped, `{name} not looped`)
			end
			local id = entry.id
			if id ~= nil then
				t.ok(
					string.sub(id, 1, 11) == "rbxasset://" or string.sub(id, 1, 13) == "rbxassetid://",
					`{name} id {id}`
				)
			end
			if entry.pitch ~= nil then
				t.ok(entry.pitch > 0 and entry.pitch <= 3, `{name} pitch`)
			end
			if entry.pitchJitter ~= nil then
				t.ok(entry.pitchJitter >= 0 and entry.pitchJitter < 0.5, `{name} pitchJitter`)
			end
		end
	end)

	t.test("AC3: musicFor", function()
		t.eq(SfxLibrary.musicFor(false, nil), "Lobby")
		t.eq(SfxLibrary.musicFor(false, "RoundActive", 1, 3), "Lobby")
		t.eq(SfxLibrary.musicFor(true, "RoundActive", 1, 3), "Round")
		t.eq(SfxLibrary.musicFor(true, "RoundIntro", 3, 3), "Final")
		t.eq(SfxLibrary.musicFor(true, "RoundResults", 4, 4), "Final")
		t.eq(SfxLibrary.musicFor(true, "RoundResults", 3, 4), "Round")
		t.eq(SfxLibrary.musicFor(true, "Victory", 3, 3), "Victory")
		t.eq(SfxLibrary.musicFor(true, "Starting"), "Round")
		t.eq(SfxLibrary.musicFor(true, nil), "Round")
	end)

	t.test("AC4: id가 있는 효과음이 10개 이상, 핵심 cue 4개 이상", function()
		local count = 0
		for _, name in SfxCues.Effects do
			local entry = SfxLibrary.get(name)
			if entry and entry.id ~= nil then
				count += 1
			end
		end
		t.ok(count >= 10, `effects with id: {count}`)
		local core = 0
		for _, name in { "Chomp", "SoyDip", "Go", "Qualified", "Eliminated", "Dive" } do
			local entry = SfxLibrary.get(name)
			if entry and entry.id ~= nil then
				core += 1
			end
		end
		t.ok(core >= 4, `core cues with id: {core}`)
	end)

	t.test("모르는 이름은 nil", function()
		t.eq(SfxLibrary.get("NoSuchCue"), nil)
	end)
end
