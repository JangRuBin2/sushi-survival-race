--!strict
-- m3-03 탈락 연출: Shared.EliminationCutsceneLogic (연출 종류, 재생 여부, 대사, 동시 재생 한도, 박자)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local Config = RobloxRequire.require(Shared.Config)

-- 시드로 만드는 간단한 rng (Random.new(seed)와 같은 모양)
local function seededRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + (state // 65536) % (max - min + 1)
		end,
	}
end

local function setOf(list: { string }): { [string]: boolean }
	local set = {}
	for _, value in list do
		set[value] = true
	end
	return set
end

-- 시드 1~200으로 고른 대사 집합
local function sample(appearanceId: string, variant: Logic.Variant): { [string]: boolean }
	local seen = {}
	for seed = 1, 200 do
		seen[Logic.pickLine(appearanceId, variant, seededRng(seed))] = true
	end
	return seen
end

local function anyOf(seen: { [string]: boolean }, list: { string }): boolean
	for _, line in list do
		if seen[line] then
			return true
		end
	end
	return false
end

return function(t: Test.Test)
	t.test("AC1: 연출 종류", function()
		t.eq(Logic.variantFor("Race", false, "Fall"), "Chopsticks")
		t.eq(Logic.variantFor("Survival", false, "Fall"), "Mouth")
		t.eq(Logic.variantFor("Survival", false, "Reset"), "Chopsticks")
		t.eq(Logic.variantFor("Final", true, "Fall"), "ChefHand")
		t.eq(Logic.variantFor("Race", true, "Reset"), "ChefHand")
	end)

	t.test("AC1: 맵 종류를 모르면 젓가락", function()
		t.eq(Logic.variantFor(nil, false, "Fall"), "Chopsticks")
	end)

	t.test("AC1: 결승 여부는 roundIndex == roundCount", function()
		t.eq(Logic.isFinalRound(3, 3), true)
		t.eq(Logic.isFinalRound(2, 3), false)
		t.eq(Logic.isFinalRound(nil, 3), false)
		t.eq(Logic.isFinalRound(3, nil), false)
	end)

	t.test("AC2: 낙하·리셋만 연출", function()
		t.eq(Logic.shouldPlay("Fall"), true)
		t.eq(Logic.shouldPlay("Reset"), true)
		t.eq(Logic.shouldPlay("Left"), false)
		t.eq(Logic.shouldPlay(nil), false)
	end)

	t.test("AC3: tamago 젓가락 = 공통 + tamago 대사, 결승 대사 없음", function()
		local seen = sample("tamago", "Chopsticks")
		local allowed = setOf(Logic.linesFor("tamago", "Chopsticks"))
		t.ok(anyOf(seen, Logic.COMMON_LINES), "공통 대사가 나와요")
		t.ok(anyOf(seen, Logic.SKIN_LINES.tamago), "tamago 대사가 나와요")
		t.ok(not anyOf(seen, Logic.FINAL_LINES), "결승 대사는 안 나와요")
		for line in seen do
			t.ok(allowed[line] == true, `목록 밖 대사: {line}`)
		end
	end)

	t.test("AC3: 모르는 스킨은 공통 대사만", function()
		local seen = sample("no-such-skin", "Chopsticks")
		local common = setOf(Logic.COMMON_LINES)
		for line in seen do
			t.ok(common[line] == true, `공통이 아닌 대사: {line}`)
		end
	end)

	t.test("AC3: 결승(ChefHand)은 결승 대사도 나와요", function()
		local seen = sample("tamago", "ChefHand")
		t.ok(anyOf(seen, Logic.FINAL_LINES), "결승 대사가 나와요")
		t.ok(anyOf(seen, Logic.COMMON_LINES), "공통 대사도 나와요")
	end)

	t.test("AC4: 동시 월드 연출 한도 6", function()
		t.eq(Logic.MAX_CONCURRENT, 6)
		t.eq(Logic.canStartWorld(0), true)
		t.eq(Logic.canStartWorld(5), true)
		t.eq(Logic.canStartWorld(6), false)
		t.eq(Logic.canStartWorld(7), false)
	end)

	t.test("박자: 효과음 이름은 SfxCues, 연출 길이 안, 오름차순", function()
		local duration = Config.Match.EliminationCutscene
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } :: { Logic.Variant } do
			local beats = Logic.timeline(variant, duration)
			t.ok(#beats > 0, `{variant} 박자가 있어요`)
			local last = -1
			for _, beat in beats do
				t.ok(SfxCues.isEffect(beat.cue), `{variant}: 모르는 효과음 {beat.cue}`)
				t.ok(beat.at >= 0 and beat.at <= duration, `{variant}: {beat.cue} 시각 {beat.at}`)
				t.ok(beat.at >= last, `{variant}: 순서`)
				last = beat.at
			end
			t.eq(beats[#beats].cue, "SpeechPop")
		end
	end)

	t.test("박자: 길이에 맞춰 늘어나요", function()
		local short = Logic.timeline("Chopsticks", 3)
		local long = Logic.timeline("Chopsticks", 6)
		t.eq(long[2].at, short[2].at * 2)
		t.eq(Logic.scaled(1.2, 6), 2.4)
	end)

	t.test("alpha/smooth: 0~1로 묶여요", function()
		t.eq(Logic.alpha(0, 1, 2), 0)
		t.eq(Logic.alpha(1.5, 1, 2), 0.5)
		t.eq(Logic.alpha(3, 1, 2), 1)
		t.eq(Logic.alpha(2, 2, 2), 1)
		t.eq(Logic.smooth(0), 0)
		t.eq(Logic.smooth(1), 1)
		t.eq(Logic.smooth(0.5), 0.5)
		t.eq(Logic.smooth(2), 1)
	end)
end
