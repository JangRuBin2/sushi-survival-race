--!strict
-- m5-40 L4: Survival 5개(hot-plate, chef-board, tempura-pot, giant-jenga, cat-cafe-shelves) 시간 제한 75초 + 60~75초 서든데스.
-- AC3: timeLimit 75, 단계 함수가 60초부터 서든데스 값, 튀김 냄비 기름 상한, 철판 75초 바닥 시뮬레이션.
-- 공용 Config.TimeLimit.Survival(60)은 그대로예요 (스펙 D2).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)
local HotPlateLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local HotPlateArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local ChefLogic = RobloxRequire.require(Shared.maps.ChefBoardLogic)
local TempuraLogic = RobloxRequire.require(Shared.maps.TempuraPotLogic)
local TempuraLayout = RobloxRequire.require(Shared.maps.TempuraPotLayout)
local JengaLogic = RobloxRequire.require(Shared.maps.GiantJengaLogic)
local JengaLayout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local CatLogic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)
local CatLayout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)

local L4_IDS = { "hot-plate", "chef-board", "tempura-pot", "giant-jenga", "cat-cafe-shelves" }
local FINAL_IDS = { "skewer-showdown", "ikura-bombs", "tug-of-war-platform", "claw-machine-prize" }

-- 칼 한 번: 경고 + 내려침(0.12) + 유지(0.25) + 올림(0.4) — ChefBoard.luau 지역 상수와 같은 값 (m4-05-qa도 같은 값)
local KNIFE_AFTER_WARN = 0.12 + 0.25 + 0.4

local function near(a: number, b: number, tol: number?): boolean
	return math.abs(a - b) <= (tol or 1e-6)
end

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
		NextNumber = function(_, min: number?, max: number?): number
			state = (state * 1103515245 + 12345) % 2147483648
			local lo, hi = min or 0, max or 1
			return lo + (state / 2147483648) * (hi - lo)
		end,
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- 공통
	t.test("AC3: Survival 5개 timeLimit 75, 공용 Config.TimeLimit.Survival은 60 그대로", function()
		t.eq(Config.TimeLimit.Survival, 60)
		for _, id in L4_IDS do
			local map = Maps.get(id)
			t.ok(map ~= nil, id)
			local m = map :: any
			t.eq(m.kind, "Survival", id)
			t.eq(m.timeLimit, 75, id)
			t.eq(Maps.timeLimit(m), 75, id)
		end
		for _, logic in { HotPlateLogic, ChefLogic, TempuraLogic, JengaLogic, CatLogic } :: { any } do
			t.eq(logic.TIME_LIMIT, 75)
			t.eq(logic.SUDDEN_DEATH_AT, 60)
		end
	end)

	t.test("AC4: Final 4개는 맵 timeLimit을 따로 두지 않아요 (Config.TimeLimit.Final 그대로)", function()
		for _, id in FINAL_IDS do
			local map = Maps.get(id) :: any
			t.eq(map.kind, "Final", id)
			t.eq(map.timeLimit, nil, id)
		end
	end)

	---------------------------------------------------------------- 뜨거운 철판
	t.test(
		"hot-plate: heatDuration 59.99 → 1.5, 60 → 1.2, 서든데스 타일은 1.2초에 사라져요",
		function()
			t.eq(HotPlateLogic.heatDuration(0), 1.5)
			t.eq(HotPlateLogic.heatDuration(59.99), 1.5)
			t.eq(HotPlateLogic.heatDuration(60), 1.2)
			t.eq(HotPlateLogic.heatDuration(74.9), 1.2)
			local sudden = HotPlateLogic.heatDuration(60)
			local _, goneBefore = HotPlateLogic.heatVisual(sudden - 0.01, sudden)
			local _, goneAt = HotPlateLogic.heatVisual(sudden, sudden)
			t.eq(goneBefore, false)
			t.eq(goneAt, true)
			-- 기본(시간 인자 없음)은 예전과 같아요
			local _, goneOld = HotPlateLogic.heatVisual(1.2)
			t.eq(goneOld, false)
			-- Neon은 서든데스 타일에서도 주황 뒤·사라지기 전
			local from = sudden * HotPlateArt.GLOW_FROM
			t.ok(from > sudden / 2 and from < sudden - 0.1, `glow from {from}`)
			t.eq(HotPlateArt.isGlowing(from - 0.01, sudden), false)
			t.eq(HotPlateArt.isGlowing(from, sudden), true)
		end
	)

	t.test(
		"hot-plate: 75초 바닥 시뮬레이션 — 3라운드 판(5~8명)에서 시간 끝까지 갈 최소 인원도 바닥이 0이 안 돼요",
		function()
			-- 시간 종료까지 가려면 목표 인원 + 1명 이상이 남아야 해요(목표 이하가 되면 바로 끝). 3라운드 판에서
			-- Survival이 나올 수 있는 2라운드의 그 인원 중 가장 큰 값(= 가장 바닥을 많이 쓰는 경우).
			local worst = 0
			for start = 5, 8 do
				t.eq(Rules.roundCount(start), 3)
				local alive = Rules.qualifyCount(start, 3, 1)
				if not Rules.shouldSkipToFinal(alive) then
					worst = math.max(worst, Rules.qualifyCount(alive, 3, 2) + 1)
				end
			end
			t.eq(worst, 4)
			local lowest, atEnd = HotPlateLogic.simulateFloor(worst, HotPlateLogic.TIME_LIMIT)
			t.ok(lowest > 0, `lowest {lowest}`)
			t.ok(atEnd > 0, `at 75s {atEnd}`)
			t.eq(lowest, atEnd) -- 다시 생기지 않으니 끝이 가장 적어요
			-- 서든데스가 실제로 바닥을 더 빨리 써요 (같은 인원, 75초 동안 1.5초로만 썼을 때보다 적게 남음)
			t.ok(atEnd < 243 - worst - worst * math.floor(75 / 1.5), "sudden death uses floor faster")
		end
	)

	t.test(
		"hot-plate: simulateFloor — 60초까지는 예전(1.5초)과 같고, 혼자면 75초에 한참 남아요",
		function()
			local _, at60 = HotPlateLogic.simulateFloor(4, 60)
			t.eq(at60, 243 - 4 - 4 * 40)
			local _, solo = HotPlateLogic.simulateFloor(1, 75)
			t.eq(solo, 243 - 1 - 40 - 12) -- 60초까지 40칸, 61.2~74.4초 12칸
		end
	)

	---------------------------------------------------------------- 셰프의 도마
	t.test("chef-board: 칼 주기 59.9 → 3, 60 → 2.5, 경고 0.8 그대로, 60·70초 기울기", function()
		t.eq(ChefLogic.knifeInterval(59.9), 3)
		t.eq(ChefLogic.knifeInterval(60), 2.5)
		t.eq(ChefLogic.knifeInterval(74), 2.5)
		t.eq(ChefLogic.warnTime(60), 0.8)
		local plan = ChefLogic.tiltPlan(fakeRng(3))
		t.eq(plan[6].startAt, 60)
		t.eq(plan[7].startAt, 70)
		t.ok(ChefLogic.tiltCFrameParams(61.5, plan) ~= nil, "tilted at 61.5")
		t.ok(ChefLogic.tiltCFrameParams(71.5, plan) ~= nil, "tilted at 71.5")
		t.eq(ChefLogic.tiltCFrameParams(65, plan), nil)
	end)

	t.test(
		"chef-board: strikeTimes(75) — 60초 뒤 2.5초 간격, 칼이 겹치지 않고 마지막 내려침이 75초 전",
		function()
			local times = ChefLogic.strikeTimes(ChefLogic.TIME_LIMIT)
			local after60 = {}
			for k, at in times do
				if k < #times then
					t.ok(at + ChefLogic.warnTime(at) + KNIFE_AFTER_WARN < times[k + 1], `strike {k} overlaps next`)
				end
				if at >= 60 then
					table.insert(after60, at)
				end
			end
			t.eq(after60, { 61.5, 64, 66.5, 69, 71.5, 74 })
			local last = times[#times]
			t.ok(last + ChefLogic.warnTime(last) + 0.12 < ChefLogic.TIME_LIMIT, "last slam before 75")
			-- 60초까지의 일정은 예전 그대로 (m4-05-qa 고정 목록)
			t.eq(ChefLogic.strikeTimes(60), { 3, 9, 15, 21, 25.5, 30, 34.5, 39, 43.5, 46.5, 49.5, 52.5, 55.5, 58.5 })
		end
	)

	t.test(
		"chef-board: 시드 1~200으로 75초 뒤에도 가운데 3×3 9칸이 남고 칼 줄이 늘 있어요",
		function()
			for seed = 1, 200 do
				local rng = fakeRng(seed)
				local board = ChefLogic.newBoard()
				local previous: string? = nil
				for _ in ChefLogic.strikeTimes(ChefLogic.TIME_LIMIT) do
					local line = ChefLogic.pickLine(board, previous, rng)
					t.ok(line ~= nil, `seed {seed}: no line`)
					local l = line :: any
					ChefLogic.removeCells(board, ChefLogic.cutCells(board, l))
					previous = l.key
				end
				for i = -1, 1 do
					for j = -1, 1 do
						t.ok(ChefLogic.isAlive(board, i, j), `seed {seed}: center {i},{j} cut`)
					end
				end
			end
		end
	)

	---------------------------------------------------------------- 튀김 냄비
	t.test(
		"tempura-pot: oilHeight 60 → 21.6, 68.5 → 25, 100 → 25, 61 → 22 (60초까지는 예전과 같음)",
		function()
			t.ok(near(TempuraLogic.oilHeight(60), 21.6), `60: {TempuraLogic.oilHeight(60)}`)
			t.ok(near(TempuraLogic.oilHeight(61), 22), `61: {TempuraLogic.oilHeight(61)}`)
			t.ok(near(TempuraLogic.oilHeight(68.5), 25), `68.5: {TempuraLogic.oilHeight(68.5)}`)
			t.eq(TempuraLogic.oilHeight(100), 25)
			t.eq(TempuraLogic.OIL_MAX_Y, 25)
			t.ok(TempuraLogic.oilHeight(68) < 25, "still rising at 68")
		end
	)

	t.test("tempura-pot: 27·31층 윗면 > oilHeight(75) + 1, 23층은 약 63.5초에 잠겨요", function()
		local oil75 = TempuraLogic.oilHeight(TempuraLogic.TIME_LIMIT)
		for _, top in { TempuraLayout.TIER_TOPS[6], TempuraLayout.TIER_TOPS[7] } do
			t.ok(top > oil75 + 1, `tier {top} vs oil {oil75}`)
		end
		t.eq(TempuraLayout.TIER_TOPS[6], 27)
		t.eq(TempuraLayout.TIER_TOPS[7], 31)
		local tier23 = TempuraLayout.TIER_TOPS[5]
		t.eq(tier23, 23)
		t.eq(TempuraLogic.isFried(tier23, TempuraLogic.oilHeight(63.4)), false)
		t.eq(TempuraLogic.isFried(tier23, TempuraLogic.oilHeight(63.6)), true)
		-- 60초까지는 23층도 안전 (예전 AC5)
		t.ok(tier23 - TempuraLogic.oilHeight(60) >= 1, "tier 23 safe until 60")
		-- 기름이 냄비 벽을 넘지 않아요
		t.ok(TempuraLogic.OIL_MAX_Y < TempuraLayout.POT_WALL_TOP_Y, "oil below wall top")
	end)

	t.test("tempura-pot: splashInterval 59.99 → 1.5, 60 → 1.2, 75 → 1.2", function()
		t.eq(TempuraLogic.splashInterval(59.99), 1.5)
		t.eq(TempuraLogic.splashInterval(60), 1.2)
		t.eq(TempuraLogic.splashInterval(75), 1.2)
	end)

	---------------------------------------------------------------- 와르르 나무 블록
	t.test("giant-jenga: removalWave 59.9 → 1.5초 2개, 60 → 1.2초 2개 (마지막 단계 × 0.8)", function()
		t.eq(JengaLogic.removalWave(59.9), { interval = 1.5, count = 2 })
		t.eq(JengaLogic.removalWave(60), { interval = 1.2, count = 2 })
		t.eq(JengaLogic.removalWave(74), { interval = 1.2, count = 2 })
		t.ok(near(JengaLogic.SUDDEN_DEATH_INTERVAL, 1.5 * 0.8), "× 0.8")
		-- 60초까지 일정은 그대로 (마지막 59초)
		local times = JengaLogic.removalTimes(60)
		t.eq(times[#times], 59)
		local full = JengaLogic.removalTimes(JengaLogic.TIME_LIMIT)
		t.ok(full[#full] < 75, "last removal before 75")
		t.eq(full[#times + 1], 60.5)
		t.ok(near(full[#times + 2], 61.7), `next {full[#times + 2]}`)
	end)

	t.test(
		"giant-jenga: 시드 1~200으로 75초 — 가운데 3×3은 끝까지 3단, 테두리는 서든데스에 다 빠져요",
		function()
			for seed = 1, 200 do
				local rng = fakeRng(seed)
				local board = JengaLogic.newBoard()
				local previousKeys: { string }? = nil
				local emptyAt: number? = nil
				for _, at in JengaLogic.removalTimes(JengaLogic.TIME_LIMIT) do
					local wave = JengaLogic.removalWave(at) :: any
					local picks = JengaLogic.pickColumns(board, previousKeys, wave.count, rng)
					JengaLogic.applyRemoval(board, picks)
					local keys = {}
					for _, column in picks do
						table.insert(keys, column.key)
					end
					previousKeys = keys
					if emptyAt == nil then
						local left = 0
						for _, column in JengaLayout.columns() do
							if not JengaLayout.isProtected(column.i, column.j) then
								left += board.levels[column.key]
							end
						end
						if left == 0 then
							emptyAt = at
						end
					end
				end
				for _, column in JengaLayout.columns() do
					if JengaLayout.isProtected(column.i, column.j) then
						t.eq(board.levels[column.key], JengaLayout.LEVEL_MAX, `seed {seed}: {column.key}`)
					end
				end
				-- 60초에 남은 15개(48 − 33)를 1.2초마다 2개씩 → 약 69초
				t.ok(
					emptyAt ~= nil and (emptyAt :: number) > 65 and (emptyAt :: number) < 71,
					`seed {seed}: empty at {emptyAt}`
				)
			end
		end
	)

	---------------------------------------------------------------- 고양이 카페 캣타워
	t.test(
		"cat-cafe-shelves: pawInterval 59.9 → 2, 60 → 1.6 (마지막 단계 × 0.8), 경고 1.1초가 들어가요",
		function()
			t.eq(CatLogic.pawInterval(59.9), 2)
			t.eq(CatLogic.pawInterval(60), 1.6)
			t.eq(CatLogic.pawInterval(75), 1.6)
			t.ok(CatLogic.PAW_WARN_TIME < CatLogic.PAW_INTERVAL_SUDDEN, "warn fits")
			t.ok(near(CatLogic.PAW_INTERVAL_SUDDEN, 2 * 0.8), "× 0.8")
		end
	)

	t.test(
		"cat-cafe-shelves: 공 주기 60초 전 4.5 · 뒤 3.8, 60초에서 위치가 끊기지 않고 75초까지 선반 안",
		function()
			t.eq(CatLogic.ballPeriod(59.9), 4.5)
			t.eq(CatLogic.ballPeriod(60), 3.8)
			-- 60초 전에는 예전 공식 그대로
			t.ok(near(CatLogic.ballCycles(30), 30 / 4.5), "cycles before 60")
			t.ok(near(CatLogic.ballCycles(60 + 3.8), 60 / 4.5 + 1), "one full sudden cycle")
			for _, shelf in CatLayout.shelves() do
				local before = CatLogic.ballOffset(shelf, 60 - 1e-4)
				local after = CatLogic.ballOffset(shelf, 60 + 1e-4)
				t.ok(math.abs(after - before) < 0.01, `{shelf.key} jump {after - before}`)
				local limit = shelf.length / 2 - CatLogic.BALL_DIAMETER / 2
				local time = 0
				while time <= 75 + 1e-9 do
					t.ok(math.abs(CatLogic.ballOffset(shelf, time)) <= limit + 1e-6, `{shelf.key} out at {time}`)
					time += 0.25
				end
			end
		end
	)

	t.test("cat-cafe-shelves: 서든데스 공은 한 주기(3.8초) 안에 선반 어디든 지나가요", function()
		for _, shelf in CatLayout.shelves() do
			local half = shelf.length / 2
			local along = -half
			while along <= half + 1e-6 do
				local hit = false
				local tt = 60
				while tt <= 60 + CatLogic.BALL_PERIOD_SUDDEN + 1e-6 do
					if CatLogic.isHit(math.abs(along - CatLogic.ballOffset(shelf, tt))) then
						hit = true
						break
					end
					tt += 0.01
				end
				t.ok(hit, `{shelf.key}: along {along} never hit`)
				along += 0.5
			end
		end
	end)
end
