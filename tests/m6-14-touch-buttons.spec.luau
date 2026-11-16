--!strict
-- m6-14 C 터치 조작 버튼: 잡기·공격을 보일 때(RaceActionLogic, AC4), 아이콘 폴백(IconAssets·TouchButtonFaceLogic, AC5)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local RaceActionLogic = RobloxRequire.require(Shared.RaceActionLogic)
local IconAssets = RobloxRequire.require(Shared.IconAssets)
local TouchButtonFaceLogic = RobloxRequire.require(Shared.TouchButtonFaceLogic)
local TouchLayoutLogic = RobloxRequire.require(Shared.TouchLayoutLogic)

local ME = 101
local OTHER = 202

local RACING = { respawning = false, spectating = false }
local RESPAWNING = { respawning = true, spectating = false }
local SPECTATING = { respawning = false, spectating = true }

local function can(state: any, live: any?): boolean
	return RaceActionLogic.canUseRaceActions(state, live or RACING)
end

-- 방에 들어가 매치가 시작돼 첫 라운드가 출발한 상태
local function racing(): any
	local s = RaceActionLogic.new()
	RaceActionLogic.onRoom(s, false) -- 대기실
	RaceActionLogic.onRoom(s, true)
	RaceActionLogic.onPhase(s, "Starting", { ME, OTHER }, ME)
	RaceActionLogic.onPhase(s, "RoundIntro", { ME, OTHER }, ME)
	RaceActionLogic.onPhase(s, "RoundActive", { ME, OTHER }, ME)
	return s
end

return function(t: Test.Test)
	------------------------------------------------------------------ AC4 (C1)
	t.test("AC4: 로비·대기실에서는 숨김", function()
		local s = RaceActionLogic.new()
		t.eq(can(s), false, "lobby")
		RaceActionLogic.onRoom(s, false)
		t.eq(can(s), false, "waiting room")
		-- 로비에서 이상한 단계 방송이 와도 매치 밖이면 숨김
		RaceActionLogic.onPhase(s, "RoundActive", { ME }, ME)
		t.eq(can(s), false, "not in match")
	end)

	t.test("AC4: 카운트다운(Starting)·소개(RoundIntro)는 숨김, 출발(RoundActive)하면 보임", function()
		local s = RaceActionLogic.new()
		RaceActionLogic.onRoom(s, true)
		t.eq(can(s), false, "InMatch, no phase yet")
		RaceActionLogic.onPhase(s, "Starting", { ME, OTHER }, ME)
		t.eq(can(s), false, "Starting")
		RaceActionLogic.onPhase(s, "RoundIntro", { ME, OTHER }, ME)
		t.eq(can(s), false, "RoundIntro")
		RaceActionLogic.onPhase(s, "RoundActive", { ME, OTHER }, ME)
		t.eq(can(s), true, "RoundActive racer")
	end)

	t.test("AC4: 통과하면 숨김, 다음 라운드 출발에 다시 보임", function()
		local s = racing()
		RaceActionLogic.onResult(s, "Passed")
		t.eq(can(s), false, "passed")
		RaceActionLogic.onPhase(s, "RoundResults", { ME, OTHER }, ME)
		t.eq(can(s), false, "RoundResults")
		RaceActionLogic.onPhase(s, "RoundIntro", { ME, OTHER }, ME)
		t.eq(can(s), false, "next RoundIntro")
		RaceActionLogic.onPhase(s, "RoundActive", { ME, OTHER }, ME)
		t.eq(can(s), true, "next RoundActive")
	end)

	t.test("AC4: 탈락하면 매치 끝까지 숨김 (관전)", function()
		local s = racing()
		RaceActionLogic.onResult(s, "Eliminated")
		t.eq(can(s), false, "eliminated")
		RaceActionLogic.onPhase(s, "RoundResults", { OTHER }, ME)
		RaceActionLogic.onPhase(s, "RoundIntro", { OTHER }, ME)
		RaceActionLogic.onPhase(s, "RoundActive", { OTHER }, ME)
		t.eq(can(s), false, "next round while spectating")
		t.eq(can(s, SPECTATING), false)
	end)

	t.test("AC4: aliveUserIds에 내가 없으면 숨김 (늦게 받은 단계 방송)", function()
		local s = RaceActionLogic.new()
		RaceActionLogic.onRoom(s, true)
		RaceActionLogic.onPhase(s, "RoundActive", { OTHER }, ME)
		t.eq(can(s), false)
		RaceActionLogic.onPhase(s, "RoundActive", { OTHER, ME }, ME)
		t.eq(can(s), true)
		-- aliveUserIds가 없으면 그대로
		RaceActionLogic.onPhase(s, "RoundActive", nil, ME)
		t.eq(can(s), true)
	end)

	t.test("AC4: 관전 카메라·부활 대기(RespawnAt) 동안 숨김, 다시 달리면 보임", function()
		local s = racing()
		t.eq(can(s, SPECTATING), false, "spectating")
		t.eq(can(s, RESPAWNING), false, "respawn wait")
		t.eq(can(s, { respawning = true, spectating = true }), false)
		t.eq(can(s, RACING), true, "respawned")
	end)

	t.test("AC4: 라운드 결과·우승 연출은 숨김, 우승(Won)도 숨김", function()
		local s = racing()
		RaceActionLogic.onPhase(s, "RoundResults", { ME, OTHER }, ME)
		t.eq(can(s), false, "RoundResults")
		local final = racing()
		RaceActionLogic.onResult(final, "Won")
		t.eq(can(final), false, "won before Victory arrives")
		RaceActionLogic.onPhase(final, "Victory", { ME }, ME)
		t.eq(can(final), false, "Victory")
	end)

	t.test("AC4: 1인 연습(m6-13)은 Starting 없이 소개 → 출발, 출발하면 보임", function()
		local s = RaceActionLogic.new()
		RaceActionLogic.onRoom(s, true)
		RaceActionLogic.onPhase(s, "RoundIntro", { ME }, ME)
		t.eq(can(s), false, "practice intro")
		RaceActionLogic.onPhase(s, "RoundActive", { ME }, ME)
		t.eq(can(s), true, "practice active")
		t.eq(can(s, RESPAWNING), false, "practice respawn wait")
		RaceActionLogic.onResult(s, "Passed")
		t.eq(can(s), false, "practice finished")
		RaceActionLogic.onRoom(s, false) -- 방 닫힘 → 로비
		t.eq(can(s), false, "back in lobby")
	end)

	t.test("AC4: 매치가 끝나고 새 매치에 들어가면 탈락·통과를 지워요", function()
		local s = racing()
		RaceActionLogic.onResult(s, "Eliminated")
		RaceActionLogic.onRoom(s, false) -- 대기실로
		t.eq(s.alive, true)
		t.eq(s.passed, false)
		t.eq(s.phase, nil)
		RaceActionLogic.onRoom(s, true)
		RaceActionLogic.onPhase(s, "Starting", nil, ME)
		RaceActionLogic.onPhase(s, "RoundIntro", nil, ME)
		RaceActionLogic.onPhase(s, "RoundActive", nil, ME)
		t.eq(can(s), true)
		-- InMatch인 채로 온 방 갱신은 매치 상태를 지우지 않아요
		RaceActionLogic.onRoom(s, true)
		t.eq(can(s), true)
	end)

	t.test("AC4: 버튼 표시 = 자리 잡기 가능(점프 보임·편집 아님) AND 달리는 중", function()
		t.eq(RaceActionLogic.buttonVisible(true, true), true)
		t.eq(RaceActionLogic.buttonVisible(false, true), false)
		t.eq(RaceActionLogic.buttonVisible(true, false), false)
		t.eq(RaceActionLogic.buttonVisible(false, false), false)
	end)

	t.test(
		"AC4: 잡기·공격 버튼은 RaceActionState를 따르고, 다이브 버튼은 따르지 않아요",
		function()
			for _, file in { "GrabButton", "AttackButton" } do
				local source = fs.readFile(`src/client/input/{file}.luau`)
				t.ok(string.find(source, "RaceActionState.changed(", 1, true), `{file} subscribes`)
				t.ok(string.find(source, "RaceActionLogic.buttonVisible(placementOk", 1, true), `{file} visibility`)
				t.ok(not string.find(source, "button.Visible = jump.Visible", 1, true), `{file} old rule gone`)
			end
			local dive = fs.readFile("src/client/input/DiveButton.luau")
			t.ok(not string.find(dive, "RaceActionState", 1, true), "dive stays visible in lobby")
			-- 편집기는 4버튼 그대로 (m5-41)
			t.eq(#TouchLayoutLogic.NAMES, 4)
			-- 순수 판단은 Roblox API 없이
			local logic = fs.readFile("src/shared/RaceActionLogic.luau")
			t.ok(not string.find(logic, "game:", 1, true) and not string.find(logic, "Instance", 1, true))
		end
	)

	------------------------------------------------------------------ AC5 (C2)
	t.test("AC5: 커밋한 아이콘 id는 비어 있어서 모두 글씨 폴백", function()
		for _, name in IconAssets.NAMES do
			t.eq(IconAssets.IDS[name], "", `{name} id empty in commit`)
			t.eq(IconAssets.image(name), nil, name)
			local face = TouchButtonFaceLogic.face(IconAssets.image(name), "fallback")
			t.eq(face.image, nil)
			t.eq(face.text, "fallback")
		end
	end)

	t.test("AC5: id를 넣으면 그림, 이상한 값은 폴백", function()
		local ids = { dive = "rbxassetid://123", grab = " 456 ", attack = "abc", dynamite = "rbxassetid://0" }
		t.eq(IconAssets.image("dive", ids), "rbxassetid://123")
		t.eq(IconAssets.image("grab", ids), "rbxassetid://456")
		t.eq(IconAssets.image("attack", ids), nil)
		t.eq(IconAssets.image("dynamite", ids), nil)
		t.eq(IconAssets.normalize(nil), nil)
		t.eq(IconAssets.normalize(123), nil)
		t.eq(IconAssets.normalize("http://www.roblox.com/asset/?id=5"), nil)
		local face = TouchButtonFaceLogic.face("rbxassetid://123", "🤸")
		t.eq(face.image, "rbxassetid://123")
		t.eq(face.text, "", "icon only, no text")
		t.eq(IconAssets.attackIcon(true), "dynamite")
		t.eq(IconAssets.attackIcon(false), "attack")
	end)

	t.test("AC5: SVG 원본·PNG·내보내기 도구가 이름마다 있어요", function()
		for _, name in IconAssets.NAMES do
			t.ok(fs.isFile(`assets/icons/{name}.svg`), `svg {name}`)
			t.ok(fs.isFile(`assets/icons/png/{name}.png`), `png {name}`)
			local svg = fs.readFile(`assets/icons/{name}.svg`)
			t.ok(string.find(svg, "<svg", 1, true) ~= nil, `svg tag {name}`)
			t.ok(not string.find(svg, "<image", 1, true), `no embedded bitmap {name}`)
		end
		t.ok(fs.isFile("tools/icons/export-icons.js"), "export tool")
		t.ok(fs.isFile("docs/renders/icons/touch-icons-sheet.png"), "contact sheet")
	end)

	t.test("AC5: 쿨다운 덮개 — 0이면 숨김, 1이면 가득, 사이는 아래에서 차올라요", function()
		t.eq(TouchButtonFaceLogic.coverKeys(0), nil)
		t.eq(TouchButtonFaceLogic.coverKeys(-1), nil)
		t.eq(TouchButtonFaceLogic.coverKeys(0 / 0), nil)
		local a = TouchButtonFaceLogic.COVER_ALPHA
		t.eq(TouchButtonFaceLogic.coverKeys(1), { { time = 0, value = a }, { time = 1, value = a } })
		t.eq(TouchButtonFaceLogic.coverKeys(2), { { time = 0, value = a }, { time = 1, value = a } })
		for _, f in { 0.001, 0.02, 0.25, 0.5, 0.98, 0.9985 } do
			local keys = TouchButtonFaceLogic.coverKeys(f)
			t.ok(keys ~= nil, `keys {f}`)
			local list = keys :: { any }
			t.eq(list[1].time, 0)
			t.eq(list[#list].time, 1)
			t.eq(list[1].value, 1, "top transparent")
			t.eq(list[#list].value, a, "bottom dark")
			for i = 2, #list do
				t.ok(list[i].time > list[i - 1].time, `increasing time at {f}`)
			end
		end
	end)

	t.test("AC5: 테두리 두께·쿨다운 숫자", function()
		t.eq(TouchButtonFaceLogic.strokeThickness(20), 2)
		t.eq(TouchButtonFaceLogic.strokeThickness(60), 4)
		t.eq(TouchButtonFaceLogic.strokeThickness(102), 6)
		t.eq(TouchButtonFaceLogic.strokeThickness(300), 6)
		t.eq(TouchButtonFaceLogic.cooldownLabel(nil), nil)
		t.eq(TouchButtonFaceLogic.cooldownLabel(0), nil)
		t.eq(TouchButtonFaceLogic.cooldownLabel(2.1), 3)
	end)
end
