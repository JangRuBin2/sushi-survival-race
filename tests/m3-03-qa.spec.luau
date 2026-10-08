--!strict
-- m3-03 QA: 탈락 연출 순수 로직 경계값 + 클라이언트 연출 코드가 판정·공용 파일을 건드리지 않는지 정적 확인.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local Config = RobloxRequire.require(Shared.Config)

-- NextInteger가 항상 고정된 위치(min + offset, 범위를 넘으면 max)를 돌려주는 rng
local function fixedRng(offset: number)
	return {
		NextInteger = function(_, min: number, max: number): number
			return math.min(max, min + offset)
		end,
	}
end

local function stripComments(source: string): string
	local noBlock = string.gsub(source, "%-%-%[%[.-%]%]", "")
	return (string.gsub(noBlock, "%-%-[^\n]*", ""))
end

local CLIENT_FILES = {
	"src/client/fx/EliminationCutsceneController.luau",
	"src/client/fx/EliminationCutsceneScreen.luau",
	"src/client/fx/CutsceneProps.luau",
}

return function(t: Test.Test)
	t.test("variantFor: 결승이면 맵 종류·원인과 상관없이 ChefHand", function()
		for _, kind in { "Race", "Survival", "Final" } do
			for _, cause in { "Fall", "Reset" } do
				t.eq(Logic.variantFor(kind, true, cause), "ChefHand", `{kind}/{cause}`)
			end
		end
		t.eq(Logic.variantFor(nil, true, "Fall"), "ChefHand")
	end)

	t.test("variantFor: 결승이 아니면 Survival 낙하만 Mouth", function()
		t.eq(Logic.variantFor("Final", false, "Fall"), "Chopsticks") -- Final 맵이 결승이 아닌 자리(강제 플랜)
		t.eq(Logic.variantFor("Final", false, "Reset"), "Chopsticks")
		t.eq(Logic.variantFor("Race", false, "Reset"), "Chopsticks")
		t.eq(Logic.variantFor("Survival", false, nil), "Chopsticks")
		t.eq(Logic.variantFor("Survival", false, "Left"), "Chopsticks")
	end)

	t.test("isFinalRound: 3·4라운드 결승, 1라운드짜리 강제 플랜, 건너뛴 결승", function()
		t.eq(Logic.isFinalRound(3, 3), true)
		t.eq(Logic.isFinalRound(4, 4), true)
		t.eq(Logic.isFinalRound(1, 1), true)
		t.eq(Logic.isFinalRound(3, 4), false)
		t.eq(Logic.isFinalRound(1, 3), false)
		t.eq(Logic.isFinalRound(nil, nil), false)
	end)

	-- m3-09: 시간 종료·정원 마감 탈락에 cause "Timeout"을 추가하고 연출하기로 해서 Timeout은 true예요.
	t.test("shouldPlay: Fall·Reset·Timeout 말고는 전부 false", function()
		t.eq(Logic.shouldPlay("Timeout"), true)
		for _, cause in { "Left", "fall", "", "Won", "timeout" } do
			t.eq(Logic.shouldPlay(cause), false, cause)
		end
	end)

	t.test("linesFor: 원본 목록을 바꾸지 않고, 순서는 공통 → 스킨 → 결승", function()
		local commonCount = #Logic.COMMON_LINES
		for _ = 1, 3 do
			Logic.linesFor("tamago", "ChefHand")
		end
		t.eq(#Logic.COMMON_LINES, commonCount, "COMMON_LINES 길이 그대로")
		t.eq(#Logic.SKIN_LINES.tamago, 2)
		t.eq(#Logic.FINAL_LINES, 2)

		local lines = Logic.linesFor("tamago", "ChefHand")
		t.eq(#lines, commonCount + 4)
		t.eq(lines[1], Logic.COMMON_LINES[1])
		t.eq(lines[commonCount + 1], Logic.SKIN_LINES.tamago[1])
		t.eq(lines[#lines], Logic.FINAL_LINES[#Logic.FINAL_LINES])
	end)

	t.test("linesFor: 스킨이 nil·모르는 값이면 공통(+결승)만", function()
		t.eq(#Logic.linesFor(nil, "Chopsticks"), #Logic.COMMON_LINES)
		t.eq(#Logic.linesFor("no-such-skin", "Mouth"), #Logic.COMMON_LINES)
		t.eq(#Logic.linesFor("no-such-skin", "ChefHand"), #Logic.COMMON_LINES + #Logic.FINAL_LINES)
	end)

	t.test("linesFor: 스펙 기본 대사 9줄, 중복 없음", function()
		t.eq(Logic.COMMON_LINES, {
			"음~ 신선하네!",
			"와사비 좀 더 주세요",
			"한 접시 더!",
			"이 집 초밥 잘하네~",
			"냠냠, 꿀맛!",
		})
		t.eq(Logic.SKIN_LINES.tamago, { "계란초밥은 역시 달달해", "폭신폭신 계란 최고!" })
		t.eq(Logic.FINAL_LINES, { "오늘의 마지막 접시!", "이건 내가 먹어야지~" })
		local seen = {}
		for _, line in Logic.linesFor("tamago", "ChefHand") do
			t.ok(seen[line] == nil, `중복 대사: {line}`)
			seen[line] = true
		end
	end)

	t.test("pickLine: 목록의 모든 위치를 고를 수 있고 nil이 나오지 않아요", function()
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } :: { any } do
			local lines = Logic.linesFor("tamago", variant)
			for i = 1, #lines do
				t.eq(Logic.pickLine("tamago", variant, fixedRng(i - 1)), lines[i], `{variant} {i}`)
			end
		end
		t.ok(Logic.pickLine(nil, "Chopsticks", fixedRng(0)) ~= nil, "스킨 nil도 대사가 나와요")
	end)

	t.test("기본 스킨(Config.Appearance.Default)은 전용 대사가 있어요", function()
		t.eq(Config.Appearance.Default, "tamago")
		t.ok(Logic.SKIN_LINES[Config.Appearance.Default] ~= nil)
	end)

	t.test("canStartWorld: 6개 재생 중 7번째는 막히고 하나 끝나면 다시 돼요", function()
		local active = 0
		local started = 0
		for _ = 1, 10 do
			if Logic.canStartWorld(active) then
				active += 1
				started += 1
			end
		end
		t.eq(started, 6)
		t.eq(Logic.canStartWorld(active), false)
		active -= 1
		t.eq(Logic.canStartWorld(active), true)
		t.eq(Logic.canStartWorld(-1), true)
	end)

	t.test("timeline: 연출 흐름 순서가 스펙 표와 같아요", function()
		local function cues(variant: any): { string }
			local list = {}
			for _, beat in Logic.timeline(variant, 3) do
				table.insert(list, beat.cue)
			end
			return list
		end
		t.eq(cues("Chopsticks"), { "ChopstickClack", "Struggle", "SoyDip", "Chomp", "SpeechPop" })
		t.eq(cues("Mouth"), { "MouthFall", "Chomp", "SpeechPop" })
		t.eq(cues("ChefHand"), { "ChefHand", "SpeechPop" })
	end)

	t.test("timeline: 젓가락 박자가 스펙 구간 안 (0~0.6 / 0.6~1.2 / 1.2~1.8 / 1.8~2.4 / 2.4~)", function()
		local windows = { { 0, 0.6 }, { 0.6, 1.2 }, { 1.2, 1.8 }, { 1.8, 2.4 }, { 2.4, 3 } }
		local beats = Logic.timeline("Chopsticks", 3)
		for i, beat in beats do
			t.ok(beat.at >= windows[i][1] and beat.at <= windows[i][2], `{beat.cue} at {beat.at}`)
		end
	end)

	t.test(
		"timeline: 길이 nil = 3초, 부를 때마다 새 표 (수정해도 다음 호출에 영향 없음)",
		function()
			local a = Logic.timeline("Mouth", nil)
			t.eq(a[2].at, 1.35)
			a[2].at = 99
			t.eq(Logic.timeline("Mouth", nil)[2].at, 1.35)
			t.eq(Logic.timeline("ChefHand", 1.5)[2].at, 1.1)
		end
	)

	t.test("정적: 연출 코드는 서버로 아무것도 보내지 않아요 (판정은 서버)", function()
		for _, file in CLIENT_FILES do
			local source = stripComments(fs.readFile(file))
			for _, forbidden in { "FireServer", "InvokeServer", "SetAttribute", "Remotes.fn" } do
				t.ok(string.find(source, forbidden, 1, true) == nil, `{file}: {forbidden}`)
			end
		end
	end)

	t.test(
		"정적: 컨트롤러가 PlayerResult·MatchPhase·RoomUpdated만 듣고 Victory·매치 종료에 전부 정리",
		function()
			local source = stripComments(fs.readFile("src/client/fx/EliminationCutsceneController.luau"))
			for _, name in { "PlayerResult", "MatchPhase", "RoomUpdated" } do
				t.ok(string.find(source, `Remotes.event("{name}")`, 1, true) ~= nil, name)
			end
			t.ok(string.find(source, 'info.phase == "Victory" then%s+stopAll%(%)') ~= nil, "Victory → stopAll")
			t.ok(
				string.find(source, 'room.state ~= "InMatch" then%s+phase = nil%s+stopAll%(%)') ~= nil,
				"매치 끝 → stopAll"
			)
			t.ok(string.find(source, "CameraDirector.Priority.Elimination", 1, true) ~= nil, "Elimination 우선순위")
			t.ok(string.find(source, "CameraDirector.release(OWNER)", 1, true) ~= nil, "카메라 release")
			t.ok(string.find(source, "hider.restore", 1, true) ~= nil, "숨김 복원이 cleanup에 있어요")
		end
	)

	t.test("정적: HudController는 낙하·리셋 탈락 문구만 생략 (shouldPlay 재사용)", function()
		local source = stripComments(fs.readFile("src/client/ui/HudController.luau"))
		t.ok(
			string.find(source, 'result.result == "Eliminated" and EliminationCutsceneLogic.shouldPlay%(result.cause%)')
				~= nil
		)
	end)
end
