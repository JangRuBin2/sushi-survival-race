--!strict
-- m5-18 QA: "줄다리기 발판"(tug-of-war-platform) 경계값·불변식.
--   - tilt: 좌우 대칭(반대 부호), 오른쪽에 사람이 늘면 각도가 줄지 않음, 포화 경계(합 105).
--   - approach: 어떤 입력에서도 넘어서지 않음, maxDelta 0이면 그대로.
--   - 서버 루프 흉내(60fps): 평평 → 포화까지 최소 1.5초(서서히), 목표가 바뀌어도 한 프레임에 TILT_RATE/60 이상 안 움직임.
--   - overtimeAngle: 연장전 시작 순간 각도가 끊기지 않음(startAngle), 한 프레임 변화량 상한(최대 160°/5초),
--     크기는 90°를 넘지 않음, collapseDuration 뒤로는 계속 수직.
--   - 낙하선: 평상시 최대 기울기(30°)에서 낮은 끝에 서 있어도 탈락선(-25) 위, 수직이면 낮은 끝이 탈락선 아래.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.TugOfWarPlatformLayout)
local Logic = RobloxRequire.require(Shared.maps.TugOfWarPlatformLogic)

local EPS = 1e-9

local function rng(seed: number)
	local state = seed
	local function nextUnit(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		int = function(min: number, max: number): number
			return min + math.floor(nextUnit() * (max - min + 1))
		end,
		num = function(min: number, max: number): number
			return min + nextUnit() * (max - min)
		end,
	}
end

return function(t: Test.Test)
	t.test(
		"QA tilt: 좌우 대칭, 오른쪽에 한 명 더하면 각도가 줄지 않음 (무작위 1000번)",
		function()
			local r = rng(1018)
			for _ = 1, 1000 do
				local n = r.int(0, 24)
				local positions = {}
				local mirrored = {}
				for i = 1, n do
					positions[i] = r.num(-Layout.HALF_LENGTH, Layout.HALF_LENGTH)
					mirrored[i] = -positions[i]
				end
				local a = Logic.tilt(positions)
				t.ok(math.abs(a + Logic.tilt(mirrored)) < 1e-9, "mirror symmetry")
				local more = table.clone(positions)
				table.insert(more, r.num(0, Layout.HALF_LENGTH))
				t.ok(Logic.tilt(more) >= a - EPS, "adding a right-side racer never tilts left")
			end
		end
	)

	t.test("QA tilt 포화 경계: 합 104.9는 MAX 아래, 105·200은 정확히 MAX", function()
		t.ok(Logic.tilt({ 35, 35, 34.9 }) < Logic.MAX_ANGLE)
		t.ok(math.abs(Logic.tilt({ 35, 35, 35 }) - Logic.MAX_ANGLE) < 1e-12)
		t.eq(Logic.tilt({ 35, 35, 35, 35, 35, 25 }), Logic.MAX_ANGLE)
		t.eq(Logic.tilt({ -35, -35, -35, -35 }), -Logic.MAX_ANGLE)
		-- 한 명이 끝에 서 있으면 10도 — 1명·2명으로는 포화되지 않아요
		t.ok(Logic.tilt({ 35, 35 }) < Logic.MAX_ANGLE)
	end)

	t.test(
		"QA approach: 무작위 1000번 — target을 넘지 않고, |변화| ≤ maxDelta, maxDelta 0이면 그대로",
		function()
			local r = rng(77)
			for _ = 1, 1000 do
				local cur = r.num(-2, 2)
				local target = r.num(-2, 2)
				local maxDelta = r.num(0, 0.5)
				local nextValue = Logic.approach(cur, target, maxDelta)
				t.ok(math.abs(nextValue - cur) <= maxDelta + EPS, "step bounded")
				if target >= cur then
					t.ok(nextValue <= target + EPS and nextValue >= cur - EPS, "no overshoot up")
				else
					t.ok(nextValue >= target - EPS and nextValue <= cur + EPS, "no overshoot down")
				end
				t.eq(Logic.approach(cur, target, 0), cur)
			end
		end
	)

	t.test(
		"QA 서버 루프 흉내(60fps): 평평 → 포화까지 최소 1.5초, 프레임당 변화 ≤ TILT_RATE/60",
		function()
			local dt = 1 / 60
			local angle = 0
			local frames = 0
			while angle < Logic.MAX_ANGLE - 1e-9 do
				local nextAngle = Logic.approach(angle, Logic.tilt({ 35, 35, 35 }), Logic.TILT_RATE * dt)
				t.ok(nextAngle - angle <= Logic.TILT_RATE * dt + EPS, "frame step")
				angle = nextAngle
				frames += 1
				t.ok(frames < 10000, "never converges")
			end
			t.ok(frames * dt >= 1.5 - 1e-6, `reached MAX in {frames * dt}s`)
			-- 반대쪽으로 다 옮기면 -MAX까지 3초
			local back = 0
			while angle > -Logic.MAX_ANGLE + 1e-9 do
				angle = Logic.approach(angle, Logic.tilt({ -35, -35, -35 }), Logic.TILT_RATE * dt)
				back += 1
			end
			t.ok(back * dt >= 3 - 1e-6, `swing to -MAX in {back * dt}s`)
		end
	)

	t.test(
		"QA overtimeAngle: 시작 순간 끊김 없음, 프레임당 변화 ≤ 32°/s, |각도| ≤ 90°, 이후 계속 수직",
		function()
			local dt = 1 / 60
			for _, duration in { 8, 20, 40 } do
				for _, startDeg in { -30, -12, 0, 17, 30 } do
					local startAngle = math.rad(startDeg)
					t.ok(math.abs(Logic.overtimeAngle(0, duration, startAngle) - startAngle) < 1e-12, "continuous at 0")
					-- 가장 빠른 구간: 70° → -90° (160°)를 duration/4초에
					local maxRate = math.rad(160) / (duration / 4)
					local prev = startAngle
					local tt = dt
					while tt <= duration + 10 do
						local a = Logic.overtimeAngle(tt, duration, startAngle)
						t.ok(math.abs(a) <= Logic.LETHAL_ANGLE + 1e-9, `|angle| {math.deg(a)} > 90 at {tt}`)
						t.ok(math.abs(a - prev) <= maxRate * dt + 1e-9, `jump {math.deg(a - prev)}° at {tt}`)
						if tt >= duration then
							t.ok(math.abs(math.abs(a) - Logic.LETHAL_ANGLE) < 1e-9, `not vertical at {tt}`)
						end
						prev = a
						tt += dt
					end
				end
			end
		end
	)

	t.test("QA overtimeAngle: 꺾인점 부호는 +, -, +, - 이고 크기는 30, 50, 70, 90", function()
		local expected = { 30, -50, 70, -90 }
		for i, deg in expected do
			local a = Logic.overtimeAngle(i * 5, 20, math.rad(-25))
			t.ok(math.abs(a - math.rad(deg)) < 1e-9, `keyframe {i}: {math.deg(a)}`)
		end
		-- collapseDuration 0 이하도 에러 없이 수직
		t.ok(math.abs(math.abs(Logic.overtimeAngle(0, 0, 0)) - Logic.LETHAL_ANGLE) < 1e-12)
	end)

	t.test(
		"QA 낙하선: 평상시 30°에서 낮은 끝에 서도 탈락 안 됨, 수직이면 낮은 끝이 탈락선 아래",
		function()
			local ROOT_ABOVE_FLOOR = 3 -- 루트는 발판 윗면에서 약 3 위
			local lowEndAtMax = -Layout.HALF_LENGTH * math.sin(Logic.MAX_ANGLE)
			t.ok(lowEndAtMax + ROOT_ABOVE_FLOOR * math.cos(Logic.MAX_ANGLE) > -Layout.FALL_DEPTH, "false elimination")
			t.ok(-Layout.HALF_LENGTH * math.sin(Logic.LETHAL_ANGLE) < -Layout.FALL_DEPTH, "vertical low end above line")
		end
	)

	t.test(
		"QA 스폰: 24개 모두 발판 가장자리에서 2 이상 안쪽, 좌우 토크 합 0 (출발 때 평평)",
		function()
			local positions = {}
			for _, s in Layout.spawnPositions() do
				t.ok(Layout.HALF_LENGTH - math.abs(s.x) >= 2, `x {s.x} too close to the end`)
				t.ok(Layout.HALF_WIDTH - math.abs(s.z - Layout.CENTER_Z) >= 2, `z {s.z} too close to the side`)
				table.insert(positions, s.x)
			end
			t.eq(#positions, 24)
			t.eq(Logic.tilt(positions), 0)
			-- 기본 연장전 길이가 그대로인지 (훅이 이 값을 받아요)
			t.eq(Config.Final.CollapseDuration, 20)
		end
	)
end
