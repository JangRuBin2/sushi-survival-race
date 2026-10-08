--!strict
-- m3-09 통합 수정: Roblox 런타임이 필요한 파일이라 소스 확인으로 회귀를 막아요 (Studio 확인은 스펙 개발 메모).

local fs = require("@lune/fs")

local Test = require("./lib/Test")

local function has(path: string, text: string): boolean
	return string.find(fs.readFile(path), text, 1, true) ~= nil
end

return function(t: Test.Test)
	t.test("서버: 시간 종료·정원 마감 탈락은 cause Timeout", function()
		t.ok(has("src/server/RoundService.luau", 'causeOf[userId] or "Timeout"'), "RoundService fills Timeout")
		t.ok(has("src/shared/Types.luau", '"Fall" | "Reset" | "Left" | "Timeout"'), "Types.EliminationCause")
	end)

	t.test("서버: 결승 마지막 탈락 연출 뒤 우승 발표 (m3-03 QA B1)", function()
		local source = fs.readFile("src/server/RoundService.luau")
		local waitAt = string.find(source, "task.wait(Config.Match.EliminationCutscene)", 1, true)
		local wonAt = string.find(source, "EliminationService.won(roomId, wonUserId)", 1, true)
		t.ok(waitAt ~= nil and wonAt ~= nil and waitAt < wonAt, "wait before deferred Won")
		t.ok(string.find(source, "delayWon = released", 1, true) ~= nil, "only after start")
	end)

	t.test("서버: 리셋 탈락 위치를 새 캐릭터로 채우지 않아요 (m3-01 QA B2)", function()
		t.ok(has("src/server/EliminationService.luau", 'if cause ~= "Reset" and root then'), "EliminationService")
		t.ok(has("src/server/RoundService.luau", 'queueFall(userId, nil, "Reset", lastPosition(), true)'), "watch")
	end)

	t.test("클라이언트: 탈락 고정(Anchored)은 넘어짐 연출이 아니에요 (m3-02 QA B1)", function()
		t.ok(
			has(
				"src/client/fx/CharacterFxController.luau",
				"humanoid.PlatformStand and humanoid.Health > 0 and not root.Anchored"
			),
			"knocked excludes anchored"
		)
		t.ok(has("src/client/fx/CharacterFxController.luau", "HumanoidDisplayDistanceType.None"), "own name tag")
	end)

	t.test("클라이언트: 소개 중 탈락하면 출발! 없음 (m3-04 QA B1)", function()
		t.ok(has("src/client/fx/IntroController.luau", "if participant and isAlive() then"), "RoundActive check")
	end)

	t.test(
		"클라이언트: 우승자 개인 결과 글씨를 연출 위에 띄우지 않아요 (m3-05 QA B3)",
		function()
			-- m3-09 QA B1: Won 글씨는 띄우고(Victory가 올 때까지 유지) Victory 단계가 시작되면 지워요
			local source = fs.readFile("src/client/ui/HudController.luau")
			t.ok(
				string.find(source, "hud:showPersonalResult(personalResultText(result), true)", 1, true) ~= nil,
				"Won shown and kept"
			)
			t.ok(string.find(source, 'if currentPhase ~= "Victory" then', 1, true) ~= nil, "not during Victory")
			local victoryAt = string.find(source, 'if info.phase == "Victory" then', 1, true)
			local clearAt = string.find(source, "hud:clearPersonalResult()", 1, true)
			t.ok(victoryAt ~= nil and clearAt ~= nil and victoryAt < clearAt, "cleared on Victory")
			local screen = fs.readFile("src/client/ui/HudScreen.luau")
			t.ok(
				string.find(screen, "function screen.clearPersonalResult", 1, true) ~= nil,
				"HudScreen.clearPersonalResult"
			)
			t.ok(string.find(screen, "if keep then", 1, true) ~= nil, "keep skips 4s timer")
		end
	)

	t.test(
		"클라이언트: 다이브하면 잡기를 놓고, 끝나면 원래 상태로 되돌려요 (m3-06 QA B4, m3-07 G3)",
		function()
			local source = fs.readFile("src/client/input/DiveController.luau")
			t.ok(string.find(source, "GrabController.cancelHold()", 1, true) ~= nil, "cancel grab on dive")
			t.ok(string.find(source, "body.humanoid.AutoRotate = savedAutoRotate", 1, true) ~= nil, "AutoRotate")
			t.ok(string.find(source, "SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpWasEnabled)", 1, true) ~= nil)
		end
	)

	t.test("클라이언트: 조작 버튼 화면에 NoClickSfx", function()
		t.ok(has("src/client/input/DiveButton.luau", "SetAttribute(Attributes.NoClickSfx, true)"), "DiveGui")
		t.ok(has("src/client/input/GrabButton.luau", "SetAttribute(Attributes.NoClickSfx, true)"), "GrabGui")
	end)
end
