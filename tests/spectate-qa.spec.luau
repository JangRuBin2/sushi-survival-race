--!strict
-- m2-06 QA(docs/qa/m2-06-spectate-victory-ui.md)에서 추가한 SpectateLogic 성질 테스트.
-- m2-05 전처럼 aliveUserIds/racerUserIds가 nil이거나 비어 있는 경우, 무작위 입력에서의 불변식.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local SpectateLogic = RobloxRequire.require(Shared.SpectateLogic)

local function lcg(seed: number): (number, number) -> number
	local state = seed
	return function(min: number, max: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return min + state % (max - min + 1)
	end
end

local function randomIds(rand: (number, number) -> number, maxCount: number): { number }?
	if rand(0, 4) == 0 then
		return nil -- m2-05 전처럼 필드가 안 오는 경우
	end
	local ids = {}
	for _ = 1, rand(0, maxCount) do
		-- Studio 테스트 플레이어처럼 음수 userId도 섞어요
		table.insert(ids, rand(-6, 8))
	end
	return ids
end

return function(t: Test.Test)
	t.test(
		"m2-05 전: 생존자·레이서가 모두 nil/빈 목록이면 후보는 빈 목록, step·reconcile은 nil",
		function()
			for _, pair in { { nil, nil }, { {}, nil }, { nil, {} }, { {}, {} } } :: { { any } } do
				local list = SpectateLogic.candidates(pair[1], pair[2], 1)
				t.eq(list, {})
				t.eq(SpectateLogic.step(list, nil, 1), nil)
				t.eq(SpectateLogic.reconcile({ 3, 5 }, list, 3), nil)
			end
		end
	)

	t.test("레이서 목록에 나만 있으면 생존자로 넘어가요", function()
		t.eq(SpectateLogic.candidates({ 1 }, { 1, 3 }, 1), { 3 })
	end)

	t.test("음수 userId(Studio 테스트 플레이어)도 오름차순", function()
		t.eq(SpectateLogic.candidates({ -1, -3, -2 }, nil, -4), { -3, -2, -1 })
	end)

	t.test(
		"무작위 3000개: 후보는 나 제외·중복 없음·오름차순·입력의 부분집합, 레이서가 있으면 레이서에서만",
		function()
			local rand = lcg(11)
			for case = 1, 3000 do
				local racers = randomIds(rand, 6)
				local alive = randomIds(rand, 8)
				local me = rand(-6, 8)
				local list = SpectateLogic.candidates(racers, alive, me)
				local seen = {}
				for i, id in list do
					t.ok(id ~= me, `case {case}: includes me`)
					t.ok(not seen[id], `case {case}: duplicate {id}`)
					seen[id] = true
					if i > 1 then
						t.ok(list[i - 1] < id, `case {case}: not sorted`)
					end
				end
				local racerOthers = 0
				for _, id in racers or {} do
					if id ~= me then
						racerOthers += 1
					end
				end
				local source = if racerOthers > 0 then racers else alive
				for _, id in list do
					t.ok(table.find(source :: { number }, id) ~= nil, `case {case}: {id} not from the right source`)
				end
			end
		end
	)

	t.test("무작위: step을 목록 길이만큼 돌면 제자리, 다음 → 이전은 원래 대상", function()
		local rand = lcg(5)
		for case = 1, 500 do
			local list = SpectateLogic.candidates(randomIds(rand, 8), nil, 0)
			if #list == 0 then
				continue
			end
			local start = list[rand(1, #list)]
			local current: number? = start
			for _ = 1, #list do
				current = SpectateLogic.step(list, current, 1)
			end
			t.eq(current, start, `case {case}: full cycle`)
			t.eq(SpectateLogic.step(list, SpectateLogic.step(list, start, 1), -1), start, `case {case}: next/prev`)
		end
	end)

	t.test(
		"무작위: reconcile 결과는 항상 새 목록 안(또는 비면 nil), 대상이 남아 있으면 그대로",
		function()
			local rand = lcg(77)
			for case = 1, 2000 do
				local old = SpectateLogic.candidates(randomIds(rand, 8), nil, 0)
				local new = SpectateLogic.candidates(randomIds(rand, 8), nil, 0)
				local current: number? = if #old > 0 and rand(0, 3) > 0 then old[rand(1, #old)] else nil
				local result = SpectateLogic.reconcile(old, new, current)
				if #new == 0 then
					t.eq(result, nil, `case {case}`)
				else
					t.ok(result ~= nil and table.find(new, result :: number) ~= nil, `case {case}: result outside new`)
					if current ~= nil and table.find(new, current) then
						t.eq(result, current, `case {case}: kept target`)
					end
				end
			end
		end
	)
end
