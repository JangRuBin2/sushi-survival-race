--!strict
-- M1 버그 수정 재검증(docs/qa/m1-retro.md "재검증")에서 QA가 추가한 성질 테스트.
-- settleLeftover/eliminationPlace가 어떤 입력에도 순위를 일관되게 매기는지,
-- roundToPlay + nextRound로 MatchService 루프를 흉내 냈을 때 중간 이탈이 있어도 규칙을 지키는지.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Rules = RobloxRequire.require(Shared.Rules)

-- 시드 고정 의사 난수 (0 이상 1 미만)
local function lcg(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

type Racer = { id: number, progress: number }

local function progressOf(r: Racer): number
	return r.progress
end

-- MatchService.runMatch 루프를 순수 로직으로 흉내 내요.
-- dropBeforeRound(roundIndex, alive) → 그 라운드 소개 중 나가는 인원 수.
-- 라운드 안에서는 정확히 qualifyCount만큼 통과한다고 봐요. 실제로 돈 라운드 번호 목록과 마지막 인원을 돌려줘요.
local function simulateMatch(startCount: number, dropBeforeRound: (number, number) -> number): ({ number }, number)
	local roundCount = Rules.roundCount(startCount)
	local alive = startCount
	local played = {}
	local roundIndex: number? = 1
	local guard = 0
	while roundIndex and alive > 1 do
		guard += 1
		assert(guard < 50, "match loop did not terminate")
		roundIndex = Rules.roundToPlay(roundIndex :: number, roundCount, alive)
		-- 라운드 소개 중 이탈
		alive = math.max(alive - dropBeforeRound(roundIndex :: number, alive), 0)
		if alive <= 1 then
			break
		end
		if Rules.roundToPlay(roundIndex :: number, roundCount, alive) ~= roundIndex then
			continue
		end
		alive = Rules.qualifyCount(alive, roundCount, roundIndex :: number)
		table.insert(played, roundIndex :: number)
		roundIndex = Rules.nextRound(roundIndex :: number, roundCount, alive)
	end
	return played, alive
end

return function(t: Test.Test)
	------------------------------------------------------------------------
	-- settleLeftover / eliminationPlace 성질

	t.test(
		"settleLeftover: 무작위 입력 500개 — 빠짐·중복 없음, 통과자는 탈락자보다 멀리 간 사람",
		function()
			local rand = lcg(42)
			for case = 1, 500 do
				local n = math.floor(rand() * 24)
				local entries: { Racer } = {}
				for i = 1, n do
					-- 동률이 자주 나오게 정수로 거칠게 뽑아요
					table.insert(entries, { id = i, progress = math.floor(rand() * 6) })
				end
				local openSlots = math.floor(rand() * 30) - 3
				local qualify, eliminate = Rules.settleLeftover(entries, progressOf, openSlots)

				t.eq(#qualify, math.clamp(openSlots, 0, n), `case {case}: qualify count`)
				t.eq(#qualify + #eliminate, n, `case {case}: total`)
				local seen = {}
				for _, r in qualify do
					t.ok(not seen[r.id], `case {case}: duplicate {r.id}`)
					seen[r.id] = true
				end
				for _, r in eliminate do
					t.ok(not seen[r.id], `case {case}: duplicate {r.id}`)
					seen[r.id] = true
				end
				-- 통과자는 멀리 간 순, 탈락자는 못 간 순
				for i = 2, #qualify do
					t.ok(qualify[i - 1].progress >= qualify[i].progress, `case {case}: qualify order`)
				end
				for i = 2, #eliminate do
					t.ok(eliminate[i - 1].progress <= eliminate[i].progress, `case {case}: eliminate order`)
				end
				if #qualify > 0 and #eliminate > 0 then
					t.ok(qualify[#qualify].progress >= eliminate[#eliminate].progress, `case {case}: qualify ahead`)
				end
			end
		end
	)

	t.test(
		"settleLeftover + eliminationPlace: 더 멀리 간 탈락자가 절대 더 나쁜 등수를 받지 않아요",
		function()
			local rand = lcg(7)
			for case = 1, 300 do
				local total = 2 + math.floor(rand() * 23)
				local alreadyOut = math.floor(rand() * (total - 1))
				local leftover: { Racer } = {}
				for i = 1, total - alreadyOut do
					table.insert(leftover, { id = i, progress = rand() * 100 })
				end
				local _, eliminate = Rules.settleLeftover(leftover, progressOf, 0)
				local places = {}
				for k, r in eliminate do
					places[k] = { progress = r.progress, place = Rules.eliminationPlace(total, alreadyOut + k) }
				end
				for a = 1, #places do
					for b = 1, #places do
						if places[a].progress > places[b].progress then
							t.ok(places[a].place < places[b].place, `case {case}`)
						end
					end
				end
			end
		end
	)

	t.test(
		"eliminationPlace: 한 판 전체에서 탈락 등수는 2..시작 인원을 한 번씩 써요 (우승자 1등 제외)",
		function()
			for n = 4, 24 do
				local roundCount = Rules.roundCount(n)
				local alive = n
				local round: number? = 1
				local used = {}
				while round do
					local q = Rules.qualifyCount(alive, roundCount, round :: number)
					for k = 1, alive - q do
						local place = Rules.eliminationPlace(alive, k)
						t.ok(not used[place], `start {n}: place {place} twice`)
						used[place] = true
					end
					alive = q
					round = Rules.nextRound(round :: number, roundCount, alive)
				end
				for place = 2, n do
					t.ok(used[place], `start {n}: place {place} unused`)
				end
				t.ok(not used[1], `start {n}: place 1 is the winner's`)
			end
		end
	)

	------------------------------------------------------------------------
	-- roundToPlay로 MatchService 루프 흉내

	t.test(
		"이탈 없는 한 판: roundToPlay를 넣어도 기존 GDD 예시와 같은 라운드를 돌아요",
		function()
			local function none(_: number, _: number): number
				return 0
			end
			local played24, last24 = simulateMatch(24, none)
			t.eq(played24, { 1, 2, 3, 4 })
			t.eq(last24, 1)
			local played8, last8 = simulateMatch(8, none)
			t.eq(played8, { 1, 2, 3 })
			t.eq(last8, 1)
			local played4, last4 = simulateMatch(4, none)
			t.eq(played4, { 1, 3 }, "4 → 2 → (R2 생략) 결승")
			t.eq(last4, 1)
		end
	)

	t.test("2명으로 시작(Studio)하면 R1 없이 바로 결승을 해요", function()
		local played, last = simulateMatch(2, function()
			return 0
		end)
		t.eq(played, { 3 })
		t.eq(last, 1)
	end)

	t.test(
		"무작위 소개 중 이탈 2000판: 결승 아닌 라운드는 3명 이상에서만, 결승은 마지막 한 번, 라운드 수 이하",
		function()
			local rand = lcg(2024)
			for case = 1, 2000 do
				local start = 4 + math.floor(rand() * 21)
				local roundCount = Rules.roundCount(start)
				local log: { { round: number, alive: number } } = {}
				local played, last = simulateMatch(start, function(roundIndex: number, alive: number): number
					local drop = if rand() < 0.3 then math.floor(rand() * alive) else 0
					table.insert(log, { round = roundIndex, alive = alive - drop })
					return drop
				end)
				t.ok(#played <= roundCount, `case {case}: {#played} rounds`)
				t.ok(last <= 1 or played[#played] == roundCount, `case {case}: ended without final`)
				for i, round in played do
					if round == roundCount then
						t.eq(i, #played, `case {case}: final not last`)
					end
					if i > 1 then
						t.ok(round > played[i - 1], `case {case}: rounds not increasing`)
					end
				end
				-- 실제로 돈 결승 전 라운드는 (이탈 반영 후) 3명 이상이었어요
				local idx = 0
				for _, entry in log do
					if entry.alive > 1 and Rules.roundToPlay(entry.round, roundCount, entry.alive) == entry.round then
						idx += 1
						if entry.round < roundCount then
							t.ok(entry.alive >= 3, `case {case}: round {entry.round} with {entry.alive}`)
						end
					end
				end
				t.eq(idx, #played, `case {case}: log/played mismatch`)
			end
		end
	)
end
