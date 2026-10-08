--!strict
-- QA 보강: 밥알 코인 지급 규칙 경계값 (docs/specs/m4-08-rewards-titles.md, docs/qa/m4-08-rewards-titles.md)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Rules = RobloxRequire.require(Shared.Rules)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)

local TODAY = 20000

local function ids(from: number, to: number): { number }
	local list = {}
	for id = from, to do
		table.insert(list, id)
	end
	return list
end

-- startCount명이 Rules대로 매 라운드 앞번호부터 통과하고 결승에서 1번이 우승하는 한 판.
-- Rules.nextRound로 결승 건너뛰기까지 따라가요. 반환: 이벤트, 결승 레이서 수, 플레이한 라운드 목록
local function rulesMatch(startCount: number): ({ any }, number, { number })
	local roundCount = Rules.roundCount(startCount)
	local events: { any } = {}
	local played: { number } = {}
	local alive = startCount
	local roundIndex: number? = Rules.roundToPlay(1, roundCount, alive)
	local finalRacers = 0
	while roundIndex do
		local index = roundIndex :: number
		table.insert(played, index)
		table.insert(
			events,
			{ kind = "RoundStart", roundIndex = index, roundCount = roundCount, userIds = ids(1, alive) }
		)
		if index == roundCount then
			finalRacers = alive
			for id = 2, alive do
				table.insert(events, { kind = "Result", userId = id, result = "Eliminated" })
			end
			table.insert(events, { kind = "Result", userId = 1, result = "Won" })
			break
		end
		local target = Rules.qualifyCount(alive, roundCount, index)
		for id = 1, target do
			table.insert(events, { kind = "Result", userId = id, result = "Passed" })
		end
		for id = target + 1, alive do
			table.insert(events, { kind = "Result", userId = id, result = "Eliminated" })
		end
		alive = target
		roundIndex = Rules.nextRound(index, roundCount, alive)
	end
	return events, finalRacers, played
end

return function(t: Test.Test)
	t.test("QA: 24 players 4 rounds, winner 160 and final losers 60 (no daily bonus)", function()
		local events, finalRacers, played = rulesMatch(24)
		t.eq(#played, 4)
		local totals = RewardLogic.simulate(events)
		t.eq(totals[1], 3 * Config.Rewards.RoundPass + Config.Rewards.FinalQualify + Config.Rewards.Win)
		t.eq(totals[1], 160)
		t.ok(finalRacers >= 2, "final has at least 2 racers")
		for id = 2, finalRacers do
			t.eq(totals[id], 60)
		end
		-- 첫 라운드에서 떨어진 마지막 번호는 0 (simulate는 0이면 항목 없음)
		t.eq(totals[24], nil)
	end)

	t.test("QA: minimum 4 players skip to final, total coins of the match", function()
		local events, finalRacers, played = rulesMatch(4)
		t.eq(played[#played], 3)
		t.eq(#played, 2) -- R1 → 결승
		t.eq(finalRacers, 2)
		local totals = RewardLogic.simulate(events)
		t.eq(totals[1], 10 + 30 + 100)
		t.eq(totals[2], 10 + 30)
		t.eq(totals[3], nil)
		t.eq(totals[4], nil)
	end)

	t.test("QA: final qualify paid exactly once per racer even when skipping to final", function()
		for startCount = 4, 24 do
			local events, finalRacers = rulesMatch(startCount)
			local finalQualifyCount = 0
			local tracker = RewardLogic.newTracker()
			for _, event in events do
				if event.kind == "RoundStart" then
					for _, grant in RewardLogic.onRoundStart(tracker, event.roundIndex, event.roundCount, event.userIds) do
						t.eq(grant.reason, "FinalQualify")
						finalQualifyCount += 1
					end
				end
			end
			t.eq(finalQualifyCount, finalRacers, `startCount {startCount}`)
		end
	end)

	t.test("QA: non-final round start gives nothing", function()
		local tracker = RewardLogic.newTracker()
		t.eq(#RewardLogic.onRoundStart(tracker, 1, 4, { 1, 2, 3 }), 0)
		t.eq(#RewardLogic.onRoundStart(tracker, 3, 4, { 1, 2 }), 0)
		t.eq(#RewardLogic.onRoundStart(tracker, 4, 4, { 1, 2 }), 2)
	end)

	t.test("QA: Eliminated never pays (any round)", function()
		local tracker = RewardLogic.newTracker()
		RewardLogic.onRoundStart(tracker, 1, 3, { 1 })
		t.eq(#RewardLogic.onResult(tracker, 1, "Eliminated"), 0)
		RewardLogic.onRoundStart(tracker, 3, 3, { 1 })
		t.eq(#RewardLogic.onResult(tracker, 1, "Eliminated"), 0)
	end)

	t.test("QA: trackers of two rooms are independent", function()
		local a = RewardLogic.newTracker()
		local b = RewardLogic.newTracker()
		RewardLogic.onRoundStart(a, 3, 3, { 1 }) -- 방 A 결승
		RewardLogic.onRoundStart(b, 1, 3, { 2 }) -- 방 B 1라운드
		t.eq(#RewardLogic.onResult(a, 1, "Passed"), 0)
		local grants = RewardLogic.onResult(b, 2, "Passed")
		t.eq(#grants, 1)
		t.eq(grants[1].amount, 10)
	end)

	t.test("QA: second match on the same UTC day gets no daily bonus, next day does", function()
		local function oneSoloMatch(lastDay: number?, today: number)
			return RewardLogic.simulate({
				{ kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = { 1, 2 } },
				{ kind = "Result", userId = 2, result = "Eliminated" },
				{ kind = "MatchEnd", userIds = { 1, 2 }, today = today, lastDays = { [2] = lastDay } },
			})
		end
		t.eq(oneSoloMatch(nil, TODAY)[2], 50)
		t.eq(oneSoloMatch(TODAY, TODAY)[2], nil)
		t.eq(oneSoloMatch(TODAY, TODAY + 1)[2], 50)
	end)

	t.test("QA: dayNumber boundary is exactly UTC midnight", function()
		local midnight = TODAY * 86400
		t.eq(RewardLogic.dayNumber(midnight - 1), TODAY - 1)
		t.eq(RewardLogic.dayNumber(midnight), TODAY)
		t.eq(RewardLogic.dayNumber(midnight + 86399), TODAY)
		-- 한국 시간 오전 9시(UTC 0시)에 바뀌어요
		t.eq(RewardLogic.dayNumber(midnight - 9 * 3600), TODAY - 1)
	end)

	t.test("QA: values come from Config.Rewards (GDD 9.4)", function()
		t.eq(Config.Rewards.RoundPass, 10)
		t.eq(Config.Rewards.FinalQualify, 30)
		t.eq(Config.Rewards.Win, 100)
		t.eq(Config.Rewards.DailyFirstMatch, 50)
		t.eq(RewardLogic.forPass(false), Config.Rewards.RoundPass)
		t.eq(RewardLogic.dailyBonus(nil, 0), Config.Rewards.DailyFirstMatch)
	end)

	t.test("QA: every reason has toast text", function()
		for _, reason in { "RoundPass", "FinalQualify", "Win", "DailyFirstMatch" } do
			t.ok(RewardLogic.REASON_TEXT[reason] ~= nil, reason)
		end
	end)
end
