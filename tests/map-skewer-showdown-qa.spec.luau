--!strict
-- m2-04 QA(docs/qa/m2-04-final-skewer-showdown.md)에서 추가한 순수 로직 경계값 테스트.
-- 꼬치 높이·반지름은 SkewerShowdown.luau의 초기값과 같게 둬요 (낮은 1.75, 높은 6.8, 굵기 1.2, 기둥 반지름 2.5, 무대 22).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Logic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)

local LOW = { height = 1.75, radius = 0.6, innerReach = 2.5, outerReach = 22 }
local HIGH = { height = 6.8, radius = 0.6, innerReach = 2.5, outerReach = 22 }
local STANDING = 3.1 -- 스폰에 놓였을 때 루트 높이 (스폰 0.1 + 3)
local JUMP_APEX = 50 * 50 / (2 * 196.2) -- JumpPower 50, 기본 중력 → 약 6.37 studs

local function at(radius: number, angle: number): (number, number)
	return radius * math.cos(angle), -radius * math.sin(angle)
end

return function(t: Test.Test)
	t.test(
		"안전지대 없음: 기둥 바로 옆(3.5)부터 무대 끝(22)까지 서 있으면 한 바퀴 안에 낮은 꼬치에 맞아요",
		function()
			for radius = 3.5, 22, 0.5 do
				for _, angle in { 0.3, 1.7, 3.2, 4.9 } do
					local dx, dz = at(radius, angle)
					t.ok(Logic.isHit(dx, dz, STANDING, 0, 2 * math.pi - 0.01, LOW), `r {radius} a {angle}`)
				end
			end
		end
	)

	t.test("무대 밖(꼬치 끝 + 몸 반지름 + 꼬치 굵기 너머)은 안 맞아요", function()
		local dx, dz = at(22 + 1.6 + 0.1, 1)
		t.ok(not Logic.isHit(dx, dz, STANDING, 0, 2 * math.pi - 0.01, LOW))
	end)

	t.test("높은 꼬치: 어느 반지름·각도에서든 서 있으면 절대 안 맞아요", function()
		for radius = 3.5, 22, 0.5 do
			for k = 0, 11 do
				local dx, dz = at(radius, k * math.pi / 6)
				t.ok(not Logic.isHit(dx, dz, STANDING, 0, 2 * math.pi - 0.01, HIGH), `r {radius} k {k}`)
			end
		end
	end)

	t.test(
		"낮은 꼬치: 발이 꼬치 윗면(2.35)보다 높으면 안 맞고, 점프 최고점이면 충분히 넘어요",
		function()
			local dx, dz = at(12, 1)
			local clearRoot = LOW.height + LOW.radius + Logic.BODY_BELOW_ROOT + 0.01
			t.ok(not Logic.isHit(dx, dz, clearRoot, 0.9, 1.1, LOW), "just above")
			t.ok(Logic.isHit(dx, dz, clearRoot - 0.05, 0.9, 1.1, LOW), "just below")
			t.ok(JUMP_APEX > clearRoot - STANDING, "jump apex must clear the low skewer")
		end
	)

	t.test(
		"프레임이 멈칫해 한 번에 크게 돌아도 그 사이의 사람은 맞아요 (150°/s × 1초)",
		function()
			local dx, dz = at(14, math.rad(75))
			t.ok(Logic.isHit(dx, dz, STANDING, 0, math.rad(150), LOW))
			local bx, bz = at(14, math.rad(200))
			t.ok(not Logic.isHit(bx, bz, STANDING, 0, math.rad(150), LOW))
		end
	)

	t.test("각도가 2π를 넘어가는 프레임에서도 각도 0 근처 사람이 맞아요", function()
		local dx, dz = at(10, 0.01)
		t.ok(Logic.isHit(dx, dz, STANDING, 2 * math.pi - 0.02, 2 * math.pi + 0.02, LOW))
	end)

	t.test(
		"손 일정: 연속된 두 번 사이 간격이 손 한 번(경고 2 + 내려옴 0.4 + 들어 올림 0.5 = 2.9초)보다 길어요",
		function()
			local times = Logic.grabTimes(Logic.SLICE_COUNT)
			for i = 2, #times do
				t.ok(times[i] - times[i - 1] > 2.9, `gap {i}: {times[i] - times[i - 1]}`)
			end
			t.ok(times[#times] + 2.9 < Config.TimeLimit.Final, "마지막 조각이 시간 종료 전에 사라져요")
		end
	)

	t.test("손 일정: 조각 수가 몇 개로 시작해도 끝에는 정확히 1조각", function()
		for count = 1, 12 do
			local times = Logic.grabTimes(count)
			t.eq(#times, math.max(count - Logic.SLICES_AT_END, 0), `count {count}`)
		end
	end)

	t.test("속도: 음수·아주 큰 경과 시간에도 범위 안 (0 ≤ 속도 ≤ 최고)", function()
		for _, elapsed in { -5, 0, 9.99, 10, 35, 59.99, 60, 1000 } do
			local s = Logic.speeds(elapsed)
			t.ok(s.low >= 0 and s.low <= Logic.LOW_SPEED_MAX, `low at {elapsed}`)
			t.ok(s.high >= 0 and s.high <= Logic.HIGH_SPEED_MAX, `high at {elapsed}`)
		end
	end)
end
