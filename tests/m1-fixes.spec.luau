--!strict
-- M1 소급 QA(docs/qa/m1-retro.md) 버그 수정의 순수 로직 회귀 테스트.
-- B3: 라운드 끝 탈락 등수 순서 (Rules.settleLeftover, Rules.eliminationPlace)
-- B7: 라운드 소개 중 이탈로 2명 이하가 되면 결승으로 (Rules.roundToPlay)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Rules = RobloxRequire.require(Shared.Rules)

type Racer = { name: string, progress: number }

local function racer(name: string, progress: number): Racer
	return { name = name, progress = progress }
end

local function progressOf(r: Racer): number
	return r.progress
end

local function names(list: { Racer }): { string }
	local out = {}
	for _, r in list do
		table.insert(out, r.name)
	end
	return out
end

-- RoundService.finish처럼: 통과 처리 → 탈락 처리 순으로 등수를 매겨 이름 → 등수를 돌려줘요.
local function placesAfterSettle(
	total: number,
	alreadyEliminated: number,
	leftover: { Racer },
	openSlots: number
): { [string]: number }
	local _, toEliminate = Rules.settleLeftover(leftover, progressOf, openSlots)
	local places = {}
	local eliminatedCount = alreadyEliminated
	for _, r in toEliminate do
		eliminatedCount += 1
		places[r.name] = Rules.eliminationPlace(total, eliminatedCount)
	end
	return places
end

return function(t: Test.Test)
	-- B3 ---------------------------------------------------------------

	t.test("B3 eliminationPlace: 8명 중 첫 탈락은 8등, 세 번째 탈락은 6등", function()
		t.eq(Rules.eliminationPlace(8, 1), 8)
		t.eq(Rules.eliminationPlace(8, 3), 6)
		t.eq(Rules.eliminationPlace(2, 1), 2)
	end)

	t.test(
		"B3 settleLeftover: 시간 종료, 멀리 간 순으로 빈 자리를 채우고 탈락은 못 간 사람부터",
		function()
			local leftover = { racer("c", 30), racer("a", 50), racer("d", 10), racer("b", 40) }
			local qualify, eliminate = Rules.settleLeftover(leftover, progressOf, 2)
			t.eq(names(qualify), { "a", "b" })
			t.eq(names(eliminate), { "d", "c" })
		end
	)

	t.test(
		"B3 QA 재현: 8명·목표 5명·통과 0명 시간 종료 → 탈락자 중 멀리 간 사람이 6등, 가장 못 간 사람이 8등",
		function()
			local leftover = {}
			for i = 1, 8 do
				table.insert(leftover, racer(`r{i}`, 100 - i * 10)) -- r1이 가장 멀리 감
			end
			local places = placesAfterSettle(8, 0, leftover, 5)
			t.eq(places, { r6 = 6, r7 = 7, r8 = 8 })
		end
	)

	t.test("B3 목표 도달 종료(빈 자리 0): 남은 사람 전원 탈락, 진행도 순으로 등수", function()
		-- 4명 중 2명 통과로 끝남. 남은 2명 중 더 멀리 간 x가 3등, y가 4등.
		local places = placesAfterSettle(4, 0, { racer("y", 5), racer("x", 20) }, 0)
		t.eq(places, { x = 3, y = 4 })
	end)

	t.test("B3 라운드 중 이미 떨어진 사람이 있으면 그 뒤 등수부터 이어 붙여요", function()
		-- 6명: 1명이 먼저 낙하(6등). 시간 종료 때 남은 4명 중 목표 3명이 비어 있음.
		local leftover = { racer("p", 1), racer("q", 9), racer("r", 5), racer("s", 7) }
		local places = placesAfterSettle(6, 1, leftover, 3)
		t.eq(places, { p = 5 })
	end)

	t.test("B3 settleLeftover: 빈 자리가 남은 인원보다 많거나 음수여도 안전해요", function()
		local leftover = { racer("a", 1), racer("b", 2) }
		local q1, e1 = Rules.settleLeftover(leftover, progressOf, 5)
		t.eq(names(q1), { "b", "a" })
		t.eq(#e1, 0)
		local q2, e2 = Rules.settleLeftover(leftover, progressOf, -3)
		t.eq(#q2, 0)
		t.eq(names(e2), { "a", "b" })
		local q3, e3 = Rules.settleLeftover({}, progressOf, 2)
		t.eq(#q3, 0)
		t.eq(#e3, 0)
	end)

	t.test("B3 settleLeftover: 캐릭터가 없는 사람(-inf)은 맨 뒤, 동률은 입력 순서", function()
		local leftover = { racer("gone", -math.huge), racer("tie1", 3), racer("tie2", 3), racer("far", 9) }
		local qualify, eliminate = Rules.settleLeftover(leftover, progressOf, 2)
		t.eq(names(qualify), { "far", "tie1" })
		t.eq(names(eliminate), { "gone", "tie2" })
	end)

	-- B7 ---------------------------------------------------------------

	t.test("B7 roundToPlay: 결승 전 라운드에 2명 이하가 남으면 결승 번호", function()
		t.eq(Rules.roundToPlay(2, 3, 2), 3)
		t.eq(Rules.roundToPlay(2, 4, 1), 4)
		t.eq(Rules.roundToPlay(3, 4, 2), 4)
		t.eq(Rules.roundToPlay(1, 3, 2), 3)
	end)

	t.test("B7 roundToPlay: 3명 이상이거나 이미 결승이면 그대로", function()
		t.eq(Rules.roundToPlay(2, 3, 3), 2)
		t.eq(Rules.roundToPlay(1, 4, 24), 1)
		t.eq(Rules.roundToPlay(3, 3, 2), 3)
		t.eq(Rules.roundToPlay(4, 4, 1), 4)
	end)

	t.test(
		"B7 QA 재현: R2 소개 중 3명 → 2명이면 아무도 탈락 안 하는 R2 대신 결승을 해요",
		function()
			local roundCount = 3
			local alive = 3
			local planned = Rules.nextRound(1, roundCount, alive)
			t.eq(planned, 2)
			alive = 2 -- 소개 3초 동안 한 명이 나감
			local play = Rules.roundToPlay(planned :: number, roundCount, alive)
			t.eq(play, roundCount)
			t.eq(Rules.qualifyCount(alive, roundCount, play), 1)
		end
	)

	t.test("B7 roundToPlay가 고른 결승 전 라운드는 항상 1명 이상 탈락해요", function()
		for roundCount = 3, 4 do
			for planned = 1, roundCount do
				for alive = 2, 24 do
					local play = Rules.roundToPlay(planned, roundCount, alive)
					local q = Rules.qualifyCount(alive, roundCount, play)
					t.ok(q < alive, `planned {planned}/{roundCount}, alive {alive} → round {play} keeps {q}`)
				end
			end
		end
	end)
end
