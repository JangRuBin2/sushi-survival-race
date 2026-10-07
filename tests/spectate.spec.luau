--!strict
-- Shared.SpectateLogic: 관전 후보, 다음/이전 대상, 대상이 사라졌을 때 (m2-06)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local SpectateLogic = RobloxRequire.require(Shared.SpectateLogic)

return function(t: Test.Test)
	t.test("AC1: 달리는 사람 우선, 나 제외", function()
		t.eq(SpectateLogic.candidates({ 3, 5 }, { 1, 3, 5, 7 }, 1), { 3, 5 })
	end)

	t.test("AC1: 달리는 사람이 비면 생존자", function()
		t.eq(SpectateLogic.candidates({}, { 1, 3, 5, 7 }, 1), { 3, 5, 7 })
		t.eq(SpectateLogic.candidates(nil, { 1, 3, 5, 7 }, 1), { 3, 5, 7 })
	end)

	t.test("AC1: 나만 남았으면 빈 목록", function()
		t.eq(SpectateLogic.candidates({ 1 }, { 1 }, 1), {})
		t.eq(SpectateLogic.candidates(nil, nil, 1), {})
	end)

	t.test("후보 순서는 userId 오름차순으로 고정, 중복 제거", function()
		t.eq(SpectateLogic.candidates({ 7, 3, 5, 3 }, nil, 1), { 3, 5, 7 })
	end)

	t.test("isAvailable이 false인 사람은 빼고, 다 빠지면 생존자로", function()
		local function isAvailable(id: number): boolean
			return id ~= 5
		end
		t.eq(SpectateLogic.candidates({ 3, 5 }, { 1, 3, 5, 7 }, 1, isAvailable), { 3 })
		t.eq(SpectateLogic.candidates({ 5 }, { 1, 3, 5, 7 }, 1, isAvailable), { 3, 7 })
	end)

	t.test("AC2: 끝에서 처음으로 순환", function()
		t.eq(SpectateLogic.step({ 3, 5, 7 }, 7, 1), 3)
		t.eq(SpectateLogic.step({ 3, 5, 7 }, 3, -1), 7)
		t.eq(SpectateLogic.step({ 3, 5, 7 }, 3, 1), 5)
		t.eq(SpectateLogic.step({ 3, 5, 7 }, 7, -1), 5)
	end)

	t.test("step: 대상이 목록에 없거나 목록이 비었을 때", function()
		t.eq(SpectateLogic.step({ 3, 5, 7 }, nil, 1), 3)
		t.eq(SpectateLogic.step({ 3, 5, 7 }, 4, -1), 7)
		t.eq(SpectateLogic.step({ 3 }, 3, 1), 3)
		t.eq(SpectateLogic.step({}, 3, 1), nil)
	end)

	t.test("AC3: 대상이 빠지면 목록에서 그 다음 자리", function()
		t.eq(SpectateLogic.reconcile({ 3, 5, 7 }, { 3, 7 }, 5), 7)
	end)

	t.test("AC3: 후보가 비면 nil", function()
		t.eq(SpectateLogic.reconcile({ 3, 5, 7 }, {}, 5), nil)
	end)

	t.test("reconcile: 대상이 남아 있으면 그대로, 마지막이 빠지면 처음으로", function()
		t.eq(SpectateLogic.reconcile({ 3, 5, 7 }, { 3, 5, 7, 9 }, 5), 5)
		t.eq(SpectateLogic.reconcile({ 3, 5, 7 }, { 3, 5 }, 7), 3)
		t.eq(SpectateLogic.reconcile({ 3, 5, 7 }, { 3 }, 5), 3)
	end)

	t.test("reconcile: 새 라운드처럼 목록이 통째로 바뀌면 새 목록의 첫 번째", function()
		t.eq(SpectateLogic.reconcile({ 3, 5 }, { 8, 9 }, 5), 8)
		t.eq(SpectateLogic.reconcile({}, { 8, 9 }, nil), 8)
		t.eq(SpectateLogic.reconcile({}, { 8, 9 }, 5), 8)
	end)
end
