--!strict
-- 밥알 코인 지급 규칙 (docs/specs/m4-08-rewards-titles.md AC1~AC4)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)

local TODAY = 20000

local function ids(from: number, to: number): { number }
	local list = {}
	for id = from, to do
		table.insert(list, id)
	end
	return list
end

local function results(list: { number }, result: string): { any }
	local events = {}
	for _, id in list do
		table.insert(events, { kind = "Result", userId = id, result = result })
	end
	return events
end

local function concat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

-- 8명 3라운드: R1 1~5 통과(6~8 탈락), R2 1~3 통과(4,5 탈락), 결승 1 우승(2,3 탈락)
local function eightPlayerMatch(lastDays: { [number]: number }?): { any }
	return concat(
		{ { kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = ids(1, 8) } },
		results(ids(1, 5), "Passed"),
		results(ids(6, 8), "Eliminated"),
		{ { kind = "RoundStart", roundIndex = 2, roundCount = 3, userIds = ids(1, 5) } },
		results(ids(1, 3), "Passed"),
		results(ids(4, 5), "Eliminated"),
		{ { kind = "RoundStart", roundIndex = 3, roundCount = 3, userIds = ids(1, 3) } },
		results(ids(2, 3), "Eliminated"),
		results({ 1 }, "Won"),
		{ { kind = "MatchEnd", userIds = ids(1, 8), today = TODAY, lastDays = lastDays } }
	)
end

return function(t: Test.Test)
	t.test("AC1: 8 players 3 rounds, winner 150 and R1 loser 0 without daily bonus", function()
		local everyone = {}
		for _, id in ids(1, 8) do
			everyone[id] = TODAY
		end
		local totals = RewardLogic.simulate(eightPlayerMatch(everyone))
		t.eq(totals[1], 150, "winner")
		t.eq(totals[2], 10 + 10 + 30, "finalist")
		t.eq(totals[4], 10, "R2 loser")
		t.eq(totals[6], nil, "R1 loser gets nothing")
	end)

	t.test("AC1: with daily first match bonus, winner 200 and R1 loser 50", function()
		local totals = RewardLogic.simulate(eightPlayerMatch(nil))
		t.eq(totals[1], 200, "winner")
		t.eq(totals[6], 50, "R1 loser")
	end)

	t.test("AC1: player who left before match end gets no daily bonus", function()
		local events = eightPlayerMatch(nil)
		local last = events[#events]
		last.userIds = { 1, 2, 3, 4, 5, 7, 8 } -- 6 left
		local totals = RewardLogic.simulate(events)
		t.eq(totals[6], nil)
	end)

	t.test("AC2: 4 players skipping R2 straight to final, R1 passers get 10 + 30", function()
		local totals = RewardLogic.simulate(concat(
			{ { kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = ids(1, 4) } },
			results({ 1, 2 }, "Passed"),
			results({ 3, 4 }, "Eliminated"),
			-- 남은 2명 → 결승으로 건너뛰어요 (roundIndex 3)
			{ { kind = "RoundStart", roundIndex = 3, roundCount = 3, userIds = { 1, 2 } } }
		))
		t.eq(totals[1], 40)
		t.eq(totals[2], 40)
		t.eq(totals[3], nil)
	end)

	t.test("AC3: final round Passed/Eliminated give 0, rescued pass before final gives 10", function()
		local tracker = RewardLogic.newTracker()
		RewardLogic.onRoundStart(tracker, 2, 3, { 1, 2 })
		-- 결승 전 라운드의 구제 통과도 그냥 Passed로 와요
		t.eq(RewardLogic.matchTotal(RewardLogic.onResult(tracker, 1, "Passed")), 10, "rescued pass")
		t.eq(#RewardLogic.onResult(tracker, 2, "Eliminated"), 0)
		RewardLogic.onRoundStart(tracker, 3, 3, { 1 })
		t.eq(#RewardLogic.onResult(tracker, 1, "Passed"), 0, "final pass")
		t.eq(#RewardLogic.onResult(tracker, 1, "Eliminated"), 0, "final elimination")
		local win = RewardLogic.onResult(tracker, 1, "Won")
		t.eq(win, { { userId = 1, reason = "Win", amount = 100 } })
	end)

	t.test("AC3: forPass / forRoundStart / forWin", function()
		t.eq(RewardLogic.forPass(false), Config.Rewards.RoundPass)
		t.eq(RewardLogic.forPass(true), nil)
		t.eq(RewardLogic.forRoundStart(1, 4), nil)
		t.eq(RewardLogic.forRoundStart(3, 4), nil)
		t.eq(RewardLogic.forRoundStart(4, 4), Config.Rewards.FinalQualify)
		t.eq(RewardLogic.forWin(), Config.Rewards.Win)
	end)

	t.test("final qualify grants every racer with reason FinalQualify", function()
		local grants = RewardLogic.onRoundStart(RewardLogic.newTracker(), 4, 4, { 7, 9 })
		t.eq(grants, {
			{ userId = 7, reason = "FinalQualify", amount = 30 },
			{ userId = 9, reason = "FinalQualify", amount = 30 },
		})
	end)

	t.test("bye win before final still pays Win (no tracker round needed)", function()
		local totals = RewardLogic.simulate(
			concat(
				{ { kind = "RoundStart", roundIndex = 1, roundCount = 3, userIds = { 1, 2 } } },
				results({ 1 }, "Passed"),
				results({ 1 }, "Won"),
				{ { kind = "MatchEnd", userIds = { 1 }, today = TODAY, lastDays = { [1] = TODAY } } }
			)
		)
		t.eq(totals[1], 110)
	end)

	t.test("AC4: dailyBonus by UTC day number", function()
		t.eq(RewardLogic.dailyBonus(nil, TODAY), 50)
		t.eq(RewardLogic.dailyBonus(TODAY, TODAY), nil)
		t.eq(RewardLogic.dailyBonus(TODAY - 1, TODAY), 50)
	end)

	t.test("dayNumber uses UTC day boundaries", function()
		t.eq(RewardLogic.dayNumber(0), 0)
		t.eq(RewardLogic.dayNumber(86399), 0)
		t.eq(RewardLogic.dayNumber(86400), 1)
	end)

	t.test("AC6: forced 4-round solo win totals 210 on the first match of the day", function()
		local totals = RewardLogic.simulate({
			{ kind = "RoundStart", roundIndex = 1, roundCount = 4, userIds = { 1 } },
			{ kind = "Result", userId = 1, result = "Passed" },
			{ kind = "RoundStart", roundIndex = 2, roundCount = 4, userIds = { 1 } },
			{ kind = "Result", userId = 1, result = "Passed" },
			{ kind = "RoundStart", roundIndex = 3, roundCount = 4, userIds = { 1 } },
			{ kind = "Result", userId = 1, result = "Passed" },
			{ kind = "RoundStart", roundIndex = 4, roundCount = 4, userIds = { 1 } },
			{ kind = "Result", userId = 1, result = "Won" },
			{ kind = "MatchEnd", userIds = { 1 }, today = TODAY },
		})
		t.eq(totals[1], 210)
	end)

	t.test("matchTotal sums grant amounts", function()
		t.eq(RewardLogic.matchTotal({}), 0)
		t.eq(RewardLogic.matchTotal({ { amount = 10 }, { amount = 30 }, { amount = 100 } }), 140)
	end)

	t.test("toast and summary text", function()
		t.eq(RewardLogic.toastText("RoundPass", 10), "+10 🍚 라운드 통과")
		t.eq(RewardLogic.toastText("FinalQualify", 30), "+30 🍚 결승 진출")
		t.eq(RewardLogic.toastText("Win", 100), "+100 🍚 우승!")
		t.eq(RewardLogic.toastText("DailyFirstMatch", 50), "+50 🍚 오늘 첫 판")
		t.eq(RewardLogic.summaryText(210, 1234), "이번 판 +210 🍚 (총 1234)")
	end)

	t.test("titles follow wins (GDD 8)", function()
		t.eq(ProfileSchema.titleFor(0), nil)
		t.eq(ProfileSchema.titleFor(1), "탈출 초밥")
		t.eq(ProfileSchema.titleFor(10), "전설의 참치")
		t.eq(ProfileSchema.titleFor(100), "바다의 왕")
	end)

	t.test("B1: matchEndRecipients keeps only participants still in the room", function()
		t.eq(
			RewardLogic.matchEndRecipients({ 1, 2, 3, 4 }, { 4, 2, 9 }),
			{ 2, 4 },
			"left room or joined later excluded"
		)
		t.eq(RewardLogic.matchEndRecipients({ 1, 2 }, {}), {})
		t.eq(RewardLogic.matchEndRecipients({ 1, 1, 2 }, { 1, 2 }), { 1, 2 }, "no duplicates")
	end)

	t.test("B1: participant who left the room but stayed on the server gets no daily bonus", function()
		local events = eightPlayerMatch(nil)
		local last = events[#events]
		last.participants = ids(1, 8)
		last.userIds = { 1, 2, 3, 4, 5, 7, 8, 42 } -- 6이 방만 나감, 42는 매치 뒤 들어온 사람
		local totals = RewardLogic.simulate(events)
		t.eq(totals[6], nil, "left room")
		t.eq(totals[42], nil, "not a participant")
		t.eq(totals[7], 50, "stayed spectating")
		t.eq(totals[1], 200, "winner")
	end)
end
