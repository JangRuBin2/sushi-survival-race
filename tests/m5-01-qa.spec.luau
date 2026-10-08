--!strict
-- m5-01 QA: 결승 연장전.
--   RoundService 대기 루프(schedule/clockPhase, 0.2초 간격, 한 프레임 = 한 탈락 묶음)를 그대로 흉내 내서
--   무작위 낙하·리셋·퇴장 시점을 섞어 돌려요. 불변식:
--     - 우승자(Won)는 많아야 1명이고, 리셋·퇴장한 사람은 우승하지 못해요.
--     - Won이 없으면 마지막 묶음이 전부 리셋·퇴장이었을 때뿐이에요.
--     - 우승자보다 늦은 묶음에서 탈락한 사람은 없어요 (가장 늦게 떨어진 사람 우승).
--     - 연장전 훅은 결승에서만, 많아야 한 번 불려요. 결승이 아닌 라운드는 시간 제한에 끝나요.
--     - 훅이 붕괴를 하면 collapseAt 조금 뒤에 끝나고, 훅이 실패해도 안전 상한(hardCapAt)에는 반드시 끝나요.
--   SkewerShowdownLogic: 붕괴 일정(모든 줄을 정확히 한 번, collapseDuration 안에), 속도 연속성.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Logic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)

local FPS = 60
local LOOP_STEP = 0.2 -- RoundService 대기 루프의 task.wait
local FALL_TIME = 0.45 -- 무대 윗면에서 FALL_DEPTH(20) 아래까지 떨어지는 시간 (대략)
local STRIPS = 8

local function lcg(seed: number)
	local state = seed
	local rng = {}
	function rng.NextInteger(_self: any, min: number, max: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return min + state % (max - min + 1)
	end
	function rng.number(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return rng
end

type Event = { frame: number, userId: number, cause: "Fall" | "Reset", score: number }

type SimResult = {
	endTime: number,
	overtimeCalls: number,
	overtimeTime: number?,
	outcomes: { [number]: string },
	wonCount: number,
	winner: number?,
	resultFrame: { [number]: number }, -- userId → 탈락/우승 처리된 프레임
	lastBatchCauses: { string },
	resetIds: { [number]: boolean },
	timedOut: boolean,
	standingsWinner: number?,
}

-- mode/timeLimit/ids/events: 라운드. hook: "ok"(꼬치 쇼다운처럼 줄 단위 붕괴) / "error"(훅 실패) / "none"(훅 없음)
local function simulate(
	mode: string,
	timeLimit: number,
	ids: { number },
	baseEvents: { Event },
	hook: string,
	rng: any,
	override: number?
): SimResult
	local round = RoundLogic.newRound(mode, ids, rng)
	RoundLogic.activate(round, if mode == "Final" then 1 else math.max(1, math.floor(#ids / 2)))
	local entries = {}
	for _, id in ids do
		table.insert(entries, { userId = id, name = `P{id}` })
	end
	local standings = RoundLogic.newStandings(entries)
	local schedule = RoundLogic.schedule(mode, timeLimit, Config.Final, override)

	local eventsByFrame: { [number]: { Event } } = {}
	local function addEvent(e: Event)
		local list = eventsByFrame[e.frame]
		if list == nil then
			list = {}
			eventsByFrame[e.frame] = list
		end
		table.insert(list, e)
	end
	for _, e in baseEvents do
		addEvent(e)
	end

	local result: SimResult = {
		endTime = 0,
		overtimeCalls = 0,
		overtimeTime = nil,
		outcomes = {},
		wonCount = 0,
		winner = nil,
		resultFrame = {},
		lastBatchCauses = {},
		resetIds = {},
		timedOut = false,
		standingsWinner = nil,
	}

	local function record(outcomes: { any }, frame: number)
		for _, o in RoundLogic.applyOutcomes(standings, outcomes) do
			assert(result.outcomes[o.userId] == nil, `user {o.userId} got two outcomes`)
			result.outcomes[o.userId] = o.result
			result.resultFrame[o.userId] = frame
			if o.result == "Won" then
				result.wonCount += 1
				result.winner = o.userId
			end
		end
	end

	local pending: { any } = {}
	local pendingIds: { [number]: boolean } = {}
	local function flush(frame: number)
		if #pending == 0 then
			return
		end
		local falls = pending
		pending = {}
		pendingIds = {}
		local causes = {}
		for _, f in falls do
			table.insert(causes, f.cause)
		end
		local out = RoundLogic.eliminate(round, falls, function()
			return 0
		end)
		if #out > 0 then
			result.lastBatchCauses = causes
		end
		record(out, frame)
	end

	local overtimeStarted = false
	local nextWake = 0
	local frame = 0
	local maxFrames = math.ceil((schedule.hardCapAt + 5) * FPS)
	while frame <= maxFrames do
		local t = frame / FPS
		-- 이 프레임에 들어온 탈락 (queueFall: 이미 끝났거나, 대기 중이거나, 레이서가 아니면 무시)
		for _, e in eventsByFrame[frame] or {} do
			if not round.ended and not pendingIds[e.userId] and RoundLogic.isRacing(round, e.userId) then
				pendingIds[e.userId] = true
				if e.cause == "Reset" then
					result.resetIds[e.userId] = true
				end
				table.insert(pending, { userId = e.userId, score = e.score, cause = e.cause })
			end
		end
		-- 대기 루프
		if t >= nextWake - 1e-9 then
			nextWake += LOOP_STEP
			if round.ended then
				result.endTime = t
				break
			end
			local phase = RoundLogic.clockPhase(schedule, t)
			if phase == "Expired" then
				flush(frame)
				local out = RoundLogic.timeout(round, function(userId: number)
					return userId * 7 % 11 -- 높이 (결정적)
				end)
				if #out > 0 then
					result.timedOut = true
				end
				record(out, frame)
				result.endTime = t
				break
			end
			if phase ~= "Normal" and not overtimeStarted then
				overtimeStarted = true
				result.overtimeCalls += 1
				result.overtimeTime = t
				if hook == "ok" then
					-- 꼬치 쇼다운: 남은 레이서가 서 있는 줄이 사라지면 떨어져요 (점프 중이면 조금 늦게)
					local steps = Logic.collapseTimes(STRIPS, Config.Final.CollapseDuration, Logic.COLLAPSE_WARN_TIME)
					local dropOf: { [number]: number } = {}
					for _, step in steps do
						dropOf[step.strip] = step.dropAt
					end
					for _, userId in RoundLogic.racers(round) do
						local strip = rng:NextInteger(1, STRIPS)
						local jitter = rng.number() * 0.8
						local fallAt = t + dropOf[strip] + FALL_TIME + jitter
						addEvent({
							frame = math.floor(fallAt * FPS),
							userId = userId,
							cause = "Fall",
							score = -20 - jitter, -- 판정 순간 높이 (늦게 떨어진 사람이 더 높음)
						})
					end
				end
			end
		end
		-- task.defer(flush): 프레임 끝
		flush(frame)
		frame += 1
	end
	result.standingsWinner = RoundLogic.winnerOf(standings)
	return result
end

-- 무작위 사건: 결승 중 낙하(꼬치에 맞음·손), 리셋, 퇴장 — 일부는 같은 프레임에 묶여요
local function randomEvents(rng: any, ids: { number }, horizon: number): { Event }
	local events: { Event } = {}
	local sharedFrame = math.floor(rng.number() * horizon * FPS)
	for _, id in ids do
		local roll = rng.number()
		if roll < 0.45 then
			-- 연장전 전에 떨어짐 (일부는 같은 프레임)
			local frame = if rng.number() < 0.3 then sharedFrame else math.floor(rng.number() * horizon * FPS)
			table.insert(events, { frame = frame, userId = id, cause = "Fall", score = rng.number() * 10 })
		elseif roll < 0.6 then
			local frame = if rng.number() < 0.3 then sharedFrame else math.floor(rng.number() * horizon * FPS)
			table.insert(events, { frame = frame, userId = id, cause = "Reset", score = -math.huge })
		end
		-- 나머지는 연장전까지 버팀
	end
	return events
end

local function idsOf(n: number): { number }
	local ids = {}
	for i = 1, n do
		table.insert(ids, i)
	end
	return ids
end

local function checkFinalInvariants(t: Test.Test, r: SimResult, ids: { number }, label: string)
	t.ok(r.wonCount <= 1, `{label}: at most one Won`)
	-- 모든 레이서가 결과를 정확히 하나 받아요
	for _, id in ids do
		t.ok(r.outcomes[id] ~= nil, `{label}: user {id} has an outcome`)
	end
	if r.winner then
		t.ok(not r.resetIds[r.winner], `{label}: reset/left user {r.winner} must not win`)
		t.eq(r.standingsWinner, r.winner, `{label}: standings winner = Won`)
		local winFrame = r.resultFrame[r.winner]
		for id, f in r.resultFrame do
			t.ok(f <= winFrame, `{label}: user {id} eliminated after the winner`)
		end
	else
		-- Won이 없으면 마지막 묶음이 전부 리셋·퇴장
		t.ok(#r.lastBatchCauses > 0, `{label}: no winner needs a last batch`)
		for _, cause in r.lastBatchCauses do
			t.eq(cause, "Reset", `{label}: no winner only when the last batch is all resets`)
		end
		t.eq(r.standingsWinner, nil, `{label}: no standings winner`)
	end
end

return function(t: Test.Test)
	t.test(
		"m5-01 QA: Config 기본값 — 붕괴 20, 상한 +40, 디버그 overtimeAt nil, 결승 시간 제한 90",
		function()
			t.eq(Config.Final.CollapseDuration, 20)
			t.eq(Config.Final.HardCapMargin, 40)
			t.eq(Config.DEBUG.overtimeAt, nil)
			t.eq(Config.TimeLimit.Final, 90)
			t.eq(Config.DEBUG.forceMapPlan, nil)
		end
	)

	t.test(
		"m5-01 QA: 무작위 결승 400판 — 붕괴가 있으면 collapseAt 뒤 곧 끝나고 우승자 불변식 유지",
		function()
			local schedule = RoundLogic.schedule("Final", 90, Config.Final)
			for seed = 1, 400 do
				local rng = lcg(seed * 7919)
				local n = rng:NextInteger(1, 8)
				local ids = idsOf(n)
				local r = simulate("Final", 90, ids, randomEvents(rng, ids, 95), "ok", rng)
				local label = `seed {seed} n={n}`
				checkFinalInvariants(t, r, ids, label)
				t.ok(r.overtimeCalls <= 1, `{label}: overtime once`)
				-- 붕괴(마지막 줄 collapseAt) + 낙하 + 점프 + 루프 간격 안에 끝나요. 안전 상한까지 가지 않아요.
				t.ok(not r.timedOut, `{label}: collapse should end the final before the hard cap`)
				t.ok(
					r.endTime <= (schedule.collapseAt :: number) + FALL_TIME + 0.8 + LOOP_STEP + 0.1,
					`{label}: ended at {r.endTime}`
				)
				if r.overtimeTime then
					t.ok(
						r.overtimeTime >= 90 and r.overtimeTime < 90 + LOOP_STEP + 1e-6,
						`{label}: overtime at {r.overtimeTime}`
					)
				end
			end
		end
	)

	t.test(
		"m5-01 QA: 훅 실패·훅 없음 — 안전 상한 150초에 반드시 끝나고 남은 사람 중 1명만 Won",
		function()
			local schedule = RoundLogic.schedule("Final", 90, Config.Final)
			for _, hook in { "error", "none" } do
				for seed = 1, 150 do
					local rng = lcg(seed * 104729 + #hook)
					local n = rng:NextInteger(1, 8)
					local ids = idsOf(n)
					local r = simulate("Final", 90, ids, randomEvents(rng, ids, 140), hook, rng)
					local label = `{hook} seed {seed} n={n}`
					checkFinalInvariants(t, r, ids, label)
					t.ok(r.endTime <= schedule.hardCapAt + LOOP_STEP + 1e-6, `{label}: ended at {r.endTime}`)
					if r.timedOut then
						t.ok(r.endTime >= schedule.hardCapAt - 1e-6, `{label}: timeout only at the hard cap`)
						t.eq(r.wonCount, 1, `{label}: hard cap gives exactly one Won`)
					end
				end
			end
		end
	)

	t.test(
		"m5-01 QA: 아무도 안 떨어지는 결승(훅 실패) — 정확히 150초에 높이 1명 우승",
		function()
			local rng = lcg(42)
			local ids = idsOf(5)
			local r = simulate("Final", 90, ids, {}, "error", rng)
			t.ok(r.timedOut, "timeout")
			t.eq(r.wonCount, 1)
			-- 높이 = userId * 7 % 11 → 1:7, 2:3, 3:10, 4:6, 5:2 → 3번 우승
			t.eq(r.winner, 3)
			t.ok(math.abs(r.endTime - 150) < LOOP_STEP + 1e-6, `ended at {r.endTime}`)
			t.eq(r.overtimeCalls, 1)
		end
	)

	t.test("m5-01 QA: 혼자 결승(강제 플랜) — 연장전 붕괴로 떨어져 Won, 멈추지 않음", function()
		for seed = 1, 20 do
			local rng = lcg(seed)
			local r = simulate("Final", 90, { 1 }, {}, "ok", rng)
			t.eq(r.outcomes[1], "Won", `seed {seed}`)
			t.ok(r.endTime < 112, `seed {seed}: ended at {r.endTime}`)
		end
		-- 디버그 overtimeAt = 15
		local r = simulate("Final", 90, { 1 }, {}, "ok", lcg(3), 15)
		t.eq(r.outcomes[1], "Won")
		t.ok(r.endTime < 37 and r.overtimeTime ~= nil and (r.overtimeTime :: number) < 15.3, `ended at {r.endTime}`)
		-- 혼자 리셋이면 우승 없이 끝
		r = simulate("Final", 90, { 1 }, { { frame = 30 * FPS, userId = 1, cause = "Reset", score = 0 } }, "ok", lcg(4))
		t.eq(r.outcomes[1], "Eliminated")
		t.eq(r.wonCount, 0)
		t.ok(r.endTime < 31, "ends right after the reset")
	end)

	t.test("m5-01 QA: 연장전 중 리셋·퇴장 — 남은 1명이 그 즉시 우승", function()
		local r = simulate(
			"Final",
			90,
			{ 1, 2 },
			{ { frame = math.floor(90.5 * FPS), userId = 2, cause = "Reset", score = -math.huge } },
			"ok",
			lcg(9)
		)
		t.eq(r.outcomes[1], "Won")
		t.eq(r.outcomes[2], "Eliminated")
		t.eq(r.resultFrame[1], math.floor(90.5 * FPS))
	end)

	t.test("m5-01 QA: 결승이 아닌 라운드는 연장전 없이 시간 제한에 끝나요 (무작위)", function()
		for _, case in { { "Race", 90 }, { "Survival", 60 }, { "Survival", 90 } } do
			local mode, limit = case[1], case[2]
			for seed = 1, 60 do
				local rng = lcg(seed * 31 + limit)
				local n = rng:NextInteger(2, 12)
				local ids = idsOf(n)
				local r = simulate(mode, limit, ids, randomEvents(rng, ids, limit + 10), "ok", rng)
				local label = `{mode} seed {seed}`
				t.eq(r.overtimeCalls, 0, `{label}: no overtime`)
				t.eq(r.wonCount, 0, `{label}: no Won outside the final`)
				t.ok(r.endTime <= limit + LOOP_STEP + 1e-6, `{label}: ended at {r.endTime}`)
				for _, id in ids do
					t.ok(r.outcomes[id] ~= nil, `{label}: user {id} has an outcome`)
				end
			end
		end
		-- 디버그 overtimeAt은 결승에서만
		t.eq(RoundLogic.schedule("Survival", 90, Config.Final, 15), { hardCapAt = 90 })
		t.eq(RoundLogic.schedule("Race", 90, Config.Final, 15), { hardCapAt = 90 })
	end)

	t.test("m5-01 QA: clockPhase는 시간에 따라 되돌아가지 않아요 (디버그 값 여러 개)", function()
		local order = { Normal = 1, Overtime = 2, Collapsed = 3, Expired = 4 }
		for _, override in { 0, 1, 15, 60, 90, 200 } do
			local s = RoundLogic.schedule("Final", 90, Config.Final, override)
			t.eq(s.collapseAt, override + 20)
			t.eq(s.hardCapAt, override + 60)
			local prev = 0
			for e = 0, 300, 0.1 do
				local p = order[RoundLogic.clockPhase(s, e)]
				t.ok(p >= prev, `override {override}: phase went back at {e}`)
				prev = p
			end
			t.eq(prev, 4)
		end
	end)

	t.test(
		"m5-01 QA: 붕괴 일정 — 모든 줄을 한 번씩, 바깥부터, 시간 안에, 경고가 겹치지 않음",
		function()
			for _, case in
				{ { 8, 20, 1 }, { 8, 10, 1 }, { 8, 4, 1 }, { 8, 30, 2 }, { 3, 20, 1 }, { 1, 20, 1 }, { 8, 20, 5 } }
			do
				local strips, duration, warnTime = case[1], case[2], case[3]
				local steps = Logic.collapseTimes(strips, duration, warnTime)
				local label = `({strips},{duration},{warnTime})`
				t.eq(#steps, strips, label)
				local seen = {}
				for i, step in steps do
					t.eq(step.strip, strips - i + 1, `{label}: outer strip first`)
					seen[step.strip] = true
					t.ok(step.warnAt >= -1e-9, `{label}: warnAt >= 0`)
					t.ok(step.dropAt <= duration + 1e-9, `{label}: dropAt within duration`)
					t.ok(step.dropAt > step.warnAt, `{label}: warning before drop`)
					if i > 1 then
						t.ok(step.warnAt >= steps[i - 1].dropAt - 1e-9, `{label}: warnings do not overlap`)
					end
				end
				for s = 1, strips do
					t.ok(seen[s], `{label}: strip {s} collapses`)
				end
				t.ok(math.abs(steps[#steps].dropAt - duration) < 1e-9, `{label}: innermost strip at collapseAt`)
			end
			-- 기본값: 사라지는 간격 19/7 ≈ 2.71초 (스펙 "2.5초마다"는 대략값 — 개발 메모)
			local steps = Logic.collapseTimes(8, 20, 1)
			t.eq(steps[1].warnAt, 0)
			t.eq(steps[1].dropAt, 1)
			t.ok(math.abs((steps[2].dropAt - steps[1].dropAt) - 19 / 7) < 1e-9, "spacing 19/7")
		end
	)

	t.test(
		"m5-01 QA: 꼬치 속도 — 연장전 시작 순간 끊김 없음, 줄지 않음, 상한 190/150",
		function()
			for o = 0, 120, 2.5 do
				local before = Logic.speeds(o)
				local at = Logic.speeds(o, o)
				t.eq(at.low, before.low, `low continuous at {o}`)
				t.eq(at.high, before.high, `high continuous at {o}`)
				local prev = at
				for e = o, o + 40, 0.25 do
					local s = Logic.speeds(e, o, 20)
					t.ok(s.low >= prev.low - 1e-9 and s.high >= prev.high - 1e-9, `overtime {o}: slowed at {e}`)
					t.ok(s.low <= 190 + 1e-9 and s.high <= 150 + 1e-9, `overtime {o}: above max at {e}`)
					prev = s
				end
				t.eq(Logic.speeds(o + 20, o, 20).low, 190)
				t.eq(Logic.speeds(o + 25, o, 20).high, 150)
				-- 연장전 전 시각은 그대로
				if o > 1 then
					t.eq(Logic.speeds(o - 1, o).low, Logic.speeds(o - 1).low)
				end
			end
			-- 램프 0이면 바로 최고 속도
			t.eq(Logic.speeds(90, 90, 0).low, 190)
		end
	)
end
