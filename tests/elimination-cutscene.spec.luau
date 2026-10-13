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

	-- m5-09 고양이 손님 ------------------------------------------------------

	t.test("m5-09 AC1: skinFor — 고양이 손님만 Cat, 그 밖은 기본", function()
		t.eq(Logic.skinFor("cat-customer"), "Cat")
		t.eq(Logic.skinFor(nil), "Default")
		t.eq(Logic.skinFor("fireworks"), "Default", "우승 slot 연출")
		t.eq(Logic.skinFor("x"), "Default")
		t.eq(Logic.skinFor(""), "Default")
		t.eq(Logic.skinFor(42), "Default", "문자열이 아닌 속성")
	end)

	t.test("m5-09 AC2: 고양이면 고양이 대사 3개만 (결승 ChefHand여도)", function()
		t.eq(Logic.CAT_LINES, { "냥~ 신선하다냥!", "생선은 역시 최고냥", "한 접시 더 달라냥!" })
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } :: { Logic.Variant } do
			t.eq(Logic.linesFor("tamago", variant, "Cat"), Logic.CAT_LINES, variant)
			t.eq(Logic.linesFor(nil, variant, "Cat"), Logic.CAT_LINES, `{variant} 스킨 nil`)
		end
		local seen = {}
		for seed = 1, 200 do
			seen[Logic.pickLine("tamago", "ChefHand", seededRng(seed), "Cat")] = true
		end
		local cat = setOf(Logic.CAT_LINES)
		local count = 0
		for line in seen do
			t.ok(cat[line] == true, `고양이 대사가 아니에요: {line}`)
			count += 1
		end
		t.eq(count, 3, "세 대사가 모두 나와요")
		-- 돌려준 목록을 바꿔도 원본은 그대로
		local lines = Logic.linesFor(nil, "Mouth", "Cat")
		lines[1] = "바뀜"
		t.eq(Logic.CAT_LINES[1], "냥~ 신선하다냥!")
	end)

	t.test("m5-09 AC2: 기본이면 지금 대사 규칙 그대로", function()
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } :: { Logic.Variant } do
			t.eq(Logic.linesFor("tamago", variant, "Default"), Logic.linesFor("tamago", variant), variant)
			t.eq(
				Logic.pickLine("tamago", variant, seededRng(7), "Default"),
				Logic.pickLine("tamago", variant, seededRng(7))
			)
		end
	end)

	t.test("m5-09 AC3: 고양이 박자 = 기본 박자 + CatMeow 하나 (먹는 박자 뒤 0.3초 안)", function()
		local anchor = { Chopsticks = "Chomp", Mouth = "Chomp", ChefHand = "ChefHand" }
		for _, duration in { 3, Config.Match.EliminationCutscene } do
			for _, variant in { "Chopsticks", "Mouth", "ChefHand" } :: { Logic.Variant } do
				local base = Logic.timeline(variant, duration)
				local cat = Logic.timeline(variant, duration, "Cat")
				t.eq(#cat, #base + 1, `{variant}: 하나 더`)
				local rest = {}
				local meows = {}
				for _, beat in cat do
					if beat.cue == "CatMeow" then
						table.insert(meows, beat)
					else
						table.insert(rest, beat)
					end
				end
				t.eq(rest, base, `{variant}: 나머지 박자는 그대로`)
				t.eq(#meows, 1, `{variant}: CatMeow 한 번`)
				local anchorAt: number? = nil
				for _, beat in base do
					if beat.cue == anchor[variant] then
						anchorAt = beat.at
					end
				end
				t.ok(anchorAt ~= nil, `{variant}: 기준 박자`)
				local gap = meows[1].at - (anchorAt :: number)
				t.ok(gap > 0 and gap <= 0.3 * duration / 3, `{variant}: CatMeow 간격 {gap}`)
				local last = -1
				for _, beat in cat do
					t.ok(beat.at >= last, `{variant}: 오름차순`)
					t.ok(beat.at <= duration, `{variant}: 길이 안`)
					last = beat.at
				end
				t.eq(cat[#cat].cue, "SpeechPop", `{variant}: 마지막은 말풍선`)
				t.ok(SfxCues.isEffect("CatMeow"), "CatMeow는 SfxCues")
			end
		end
		t.eq(Logic.timeline("Chopsticks", 3, "Default"), Logic.timeline("Chopsticks", 3))
	end)
end
