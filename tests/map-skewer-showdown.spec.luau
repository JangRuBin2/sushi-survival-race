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

	t.test("B1: 어느 스폰에 서 있어도 시작 1.5초 안에는 꼬치에 맞지 않아요", function()
		local angles = Logic.spawnAngles(24)
		t.eq(#angles, 24)
		local dt = 1 / 60
		for i, angle in angles do
			local dx = Logic.SPAWN_RADIUS * math.cos(angle)
			local dz = -Logic.SPAWN_RADIUS * math.sin(angle)
			local lowAngle, highAngle = Logic.LOW_START_ANGLE, Logic.HIGH_START_ANGLE
			local firstHit = math.huge
			local elapsed = 0
			while elapsed < 12 do
				local speeds = Logic.speeds(elapsed)
				local lowTo = lowAngle + math.rad(speeds.low) * dt
				local highTo = highAngle + math.rad(speeds.high) * dt
				local hit = Logic.isHit(dx, dz, STANDING, lowAngle, lowTo, Logic.LOW_SKEWER)
					or (
						Logic.highSkewerActive(elapsed)
						and Logic.isHit(dx, dz, STANDING, highAngle, highTo, Logic.HIGH_SKEWER)
					)
				elapsed += dt
				lowAngle, highAngle = lowTo, highTo
				if hit then
					firstHit = elapsed
					break
				end
			end
			t.ok(firstHit >= 1.5, `Spawn{i} hit at {firstHit}s`)
			t.ok(firstHit < 12, `Spawn{i} should still meet the low skewer`)
		end
	end)

	t.test(
		"B1: 스폰은 무대 안, 서로 캐릭터 폭보다 멀리, 앞 번호는 고르게 흩어져요",
		function()
			local angles = Logic.spawnAngles(24)
			t.ok(Logic.SPAWN_RADIUS + Logic.BODY_RADIUS < Logic.STAGE_RADIUS * math.cos(math.pi / Logic.SLICE_COUNT))
			for i = 1, #angles do
				for j = i + 1, #angles do
					local gap = math.abs(angles[i] - angles[j])
					t.ok(2 * Logic.SPAWN_RADIUS * math.sin(gap / 2) > 2.5, `Spawn{i}/Spawn{j} too close`)
				end
			end
			-- 2명이면 120° 넘게 떨어져 있어요
			t.ok(math.abs(angles[1] - angles[2]) > math.rad(120))
		end
	)

	t.test("isHit: 꼬치 끝 바깥과 기둥 안쪽은 안 맞아요", function()
		t.ok(Logic.isHit(22.5, 0, STANDING, -0.01, 0.01, LOW), "끝 근처는 몸 반지름만큼 맞아요")
		t.ok(not Logic.isHit(25, 0, STANDING, -0.01, 0.01, LOW), "outside the stage")
		t.ok(not Logic.isHit(0.5, 0, STANDING, -0.01, 0.01, LOW), "inside the pillar")
	end)

	------------------------------------------------------------------------
	-- m5-01 결승 연장전

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	t.test("m5-01 AC7: skewer-showdown에는 overtime 훅이 있어요", function()
		local map = Maps.get("skewer-showdown")
		t.eq(type(map.overtime), "function")
	end)

	t.test(
		"m5-01 AC8: speeds — 연장전 전에는 그대로, 연장전 +10초 170/135, +20초 이상 190/150",
		function()
			for _, elapsed in { 0, 5, 10, 30, 59, 60, 89, 89.9 } do
				t.eq(Logic.speeds(elapsed, nil), Logic.speeds(elapsed), `elapsed {elapsed} (nil)`)
				t.eq(Logic.speeds(elapsed, 90), Logic.speeds(elapsed), `elapsed {elapsed} (before 90)`)
			end
			local atStart = Logic.speeds(90, 90)
			t.ok(near(atStart.low, 150) and near(atStart.high, 120), "start of overtime keeps the max speed")
			local mid = Logic.speeds(100, 90)
			t.ok(near(mid.low, 170) and near(mid.high, 135), `+10s: {mid.low}/{mid.high}`)
			for _, elapsed in { 110, 120, 200 } do
				local s = Logic.speeds(elapsed, 90)
				t.ok(near(s.low, 190) and near(s.high, 150), `+{elapsed - 90}s: {s.low}/{s.high}`)
			end
			-- 램프 길이를 넘기면 그 시간에 최고 속도
			local custom = Logic.speeds(100, 90, 10)
			t.ok(near(custom.low, 190) and near(custom.high, 150), "custom ramp")
			-- 디버그로 일찍 시작해도 속도가 줄지 않아요
			local previous = Logic.speeds(0, 15)
			for elapsed = 0, 60, 0.5 do
				local now = Logic.speeds(elapsed, 15)
				t.ok(now.low >= previous.low - 1e-9, `low decreased at {elapsed}`)
				previous = now
			end
		end
	)

	t.test("m5-01 AC9: collapseTimes(8, 20, 1) — 바깥 줄부터 8개, 마지막 dropAt 20, 경고 1초", function()
		local steps = Logic.collapseTimes(8, 20, 1)
		t.eq(#steps, 8)
		t.eq(steps[1].warnAt, 0)
		t.ok(near(steps[#steps].dropAt, 20), `last dropAt {steps[#steps].dropAt}`)
		local lastWarn = -math.huge
		for i, step in steps do
			t.eq(step.strip, 9 - i)
			t.ok(near(step.dropAt - step.warnAt, 1), `strip {step.strip} warn length`)
			t.ok(step.warnAt >= 0, "warnAt >= 0")
			t.ok(step.warnAt > lastWarn, "warnAt increases")
			lastWarn = step.warnAt
			-- 다음 줄 경고는 이 줄이 사라진 뒤에 시작해요 (한 번에 한 줄)
			local nextStep = steps[i + 1]
			if nextStep then
				t.ok(nextStep.warnAt >= step.dropAt - 1e-9, "one strip at a time")
			end
		end
		-- 기본값(Config.Final)과 맵 상수로도 같은 약속
		local defaults = Logic.collapseTimes(8, Config.Final.CollapseDuration, Logic.COLLAPSE_WARN_TIME)
		t.ok(near(defaults[#defaults].dropAt, Config.Final.CollapseDuration), "default collapse ends on time")
		t.eq(#Logic.collapseTimes(0, 20, 1), 0)
		local single = Logic.collapseTimes(1, 20, 1)
		t.eq(#single, 1)
		t.ok(near(single[1].dropAt, 20) and near(single[1].warnAt, 19), "single strip")
	end)
end
