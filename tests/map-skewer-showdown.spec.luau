--!strict
-- m2-04 "회전 꼬치 쇼다운": 맵 모양(AC1)과 순수 로직(AC3) — 꼬치 속도 일정, 셰프 손 일정, 맞음 판정

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Logic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)

local LOW = { height = 1.75, radius = 0.6, innerReach = 2.5, outerReach = 22 }
local HIGH = { height = 6.8, radius = 0.6, innerReach = 2.5, outerReach = 22 }
local STANDING = 3 -- 서 있을 때 HumanoidRootPart 높이 (무대 윗면 기준)

return function(t: Test.Test)
	t.test("AC1: skewer-showdown은 인터페이스를 지키는 Final 맵", function()
		local map = Maps.get("skewer-showdown")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Final")
		t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
	end)

	t.test("AC3: 꼬치 속도는 시간이 갈수록 줄지 않고 60초부터 최고 속도", function()
		local previous = Logic.speeds(0)
		t.eq(previous.low, 45)
		t.eq(previous.high, 0, "높은 꼬치는 10초 전에는 안 돌아요")
		for elapsed = 0, 120, 0.5 do
			local now = Logic.speeds(elapsed)
			t.ok(now.low >= previous.low, `low speed dropped at {elapsed}`)
			t.ok(now.high >= previous.high, `high speed dropped at {elapsed}`)
			previous = now
		end
		local s0, s30, s60 = Logic.speeds(0), Logic.speeds(30), Logic.speeds(60)
		t.ok(s0.low < s30.low and s30.low < s60.low, "0 < 30 < 60")
		t.eq(s60.low, Logic.LOW_SPEED_MAX)
		t.eq(Logic.speeds(89).low, Logic.LOW_SPEED_MAX)
		t.ok(s60.low >= 140 and s60.low <= 160, "최고 속도 약 150°/s")
		t.ok(s60.high > 0 and s60.high ~= s60.low, "두 꼬치는 다른 속도")
		t.ok(not Logic.highSkewerActive(9.9) and Logic.highSkewerActive(10), "높은 꼬치는 10초에 등장")
	end)

	t.test("AC3: 손 간격 — 20초 전 없음, 8초, 60초부터 3초", function()
		t.eq(Logic.handInterval(19.9), nil)
		t.eq(Logic.handInterval(20), 8)
		t.eq(Logic.handInterval(59), 8)
		t.eq(Logic.handInterval(60), 3)
		t.eq(Logic.handInterval(85), 3)
	end)

	t.test("AC3: 조각 8개에서 끝까지 가져가면 정확히 1조각이 남아요", function()
		local times = Logic.grabTimes(8)
		t.eq(#times, 7, "8 - 7 = 1")
		t.eq(times[1], 20)
		local beforeSuddenDeath = 0
		for i, at in times do
			t.ok(at < Config.TimeLimit.Final - 10, `grab {i} at {at} should leave time before 90s`)
			if i > 1 then
				t.ok(at > times[i - 1], "grab times increase")
			end
			if at < Logic.SUDDEN_DEATH_AT then
				beforeSuddenDeath += 1
			end
		end
		t.ok(8 - beforeSuddenDeath >= 2, "서든데스 전에는 2조각까지만")
		t.eq(times, { 20, 28, 36, 44, 52, 60, 63 })
	end)

	t.test("AC3: 조각이 적어도 서든데스 전에는 2개까지만, 결국 1개", function()
		t.eq(Logic.grabTimes(3), { 20, 60 })
		t.eq(Logic.grabTimes(2), { 60 })
		t.eq(Logic.grabTimes(1), {})
	end)

	t.test("angleOf: CFrame.Angles(0, θ, 0) * X축 방향 (cos θ, -sin θ)과 같은 기준", function()
		for _, theta in { 0, 0.5, 1.5, 3, -2 } do
			local got = Logic.angleOf(math.cos(theta), -math.sin(theta))
			t.ok(math.abs(math.sin(got - theta)) < 1e-9 and math.cos(got - theta) > 0, `theta {theta}`)
		end
	end)

	t.test("angleSwept: 쓸고 지나간 구간, 0 경계, 한 바퀴 넘게", function()
		t.ok(Logic.angleSwept(0.5, 0.4, 0.6, 0))
		t.ok(not Logic.angleSwept(0.7, 0.4, 0.6, 0.05))
		t.ok(Logic.angleSwept(0.65, 0.4, 0.6, 0.1), "margin")
		t.ok(Logic.angleSwept(0.05, 6.2, 6.4, 0), "2π를 넘어가는 구간")
		t.ok(Logic.angleSwept(-0.05, 6.2, 6.4, 0), "음수 각도도 같은 방향")
		t.ok(Logic.angleSwept(3, 0, 7, 0), "한 바퀴 넘게 돌면 전부")
	end)

	t.test("isHit: 낮은 꼬치는 서 있으면 맞고, 충분히 뛰면 안 맞아요", function()
		-- 각도 0.5 방향 반지름 10에 서 있고 꼬치가 0.45 → 0.55로 지나감
		local dx, dz = 10 * math.cos(0.5), -10 * math.sin(0.5)
		t.ok(Logic.isHit(dx, dz, STANDING, 0.45, 0.55, LOW), "standing")
		t.ok(not Logic.isHit(dx, dz, STANDING + 3, 0.45, 0.55, LOW), "jumped 3 studs")
		t.ok(not Logic.isHit(dx, dz, STANDING, 1.0, 1.1, LOW), "skewer elsewhere")
		t.ok(not Logic.isHit(dx, dz, STANDING, 0.2, 0.3, LOW), "skewer already passed")
	end)

	t.test("isHit: 높은 꼬치는 서 있으면 안 맞고, 높이 뛰면 맞아요", function()
		local dx, dz = 12 * math.cos(2), -12 * math.sin(2)
		t.ok(not Logic.isHit(dx, dz, STANDING, 1.95, 2.05, HIGH), "standing is safe")
		t.ok(Logic.isHit(dx, dz, STANDING + 3, 1.95, 2.05, HIGH), "jumping over the low one hits the high one")
		-- 점프 최고점(JumpPower 50 → 약 6.4 studs)에서도 낮은 꼬치는 안 맞아요
		t.ok(not Logic.isHit(dx, dz, STANDING + 6.3, 1.95, 2.05, LOW))
	end)

	t.test("isHit: 꼬치 끝 바깥과 기둥 안쪽은 안 맞아요", function()
		t.ok(Logic.isHit(22.5, 0, STANDING, -0.01, 0.01, LOW), "끝 근처는 몸 반지름만큼 맞아요")
		t.ok(not Logic.isHit(25, 0, STANDING, -0.01, 0.01, LOW), "outside the stage")
		t.ok(not Logic.isHit(0.5, 0, STANDING, -0.01, 0.01, LOW), "inside the pillar")
	end)
end
