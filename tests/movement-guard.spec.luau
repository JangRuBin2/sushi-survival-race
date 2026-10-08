--!strict
-- m4-10 서버 이동 감시: MovementGuardLogic check / advance / allowPass / strikeLog,
-- 그리고 정상 이동 경로(걷기·다이브·와사비·넉백·벨트·낙하·리스폰) 시뮬레이션에서 오탐이 없는지.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.MovementGuardLogic)
local Config = RobloxRequire.require(Shared.Config)

local cfg = Config.MovementGuard

type Sample = { x: number, y: number, z: number, t: number }
type PathFn = (t: number) -> (number, number, number)

local function at(x: number, y: number, z: number, t: number): Sample
	return { x = x, y = y, z = z, t = t }
end

-- 서버 샘플링 흉내: duration 동안 interval(+jitter) 간격으로 path(t)를 재서 check → advance.
-- exemptUntilAt(t)는 그 시각의 MoveExemptUntil 값. 위반 수를 돌려줘요.
-- 위반이면 실제 서비스처럼 되돌린다고 보고, 경로는 그 뒤 기준점에서 다시 이어진다고 가정하지 않아요
-- (정상 경로 시나리오는 위반 0이 기대값이라 되돌린 뒤를 흉내 낼 필요가 없어요).
local function simulate(
	path: PathFn,
	duration: number,
	exemptUntilAt: ((t: number) -> number?)?,
	interval: number?,
	jitter: number?
): number
	local step = interval or cfg.SampleInterval
	local x, y, z = path(0)
	local baseline = at(x, y, z, 0)
	local violations = 0
	local t = 0
	local i = 0
	while t < duration do
		i += 1
		-- 결정적 흔들림: 서버 프레임 단위로 샘플 간격이 조금씩 길어져요.
		t += step + (jitter or 0) * ((i % 3) / 2)
		local cx, cy, cz = path(t)
		local cur = at(cx, cy, cz, t)
		local exemptUntil = if exemptUntilAt then exemptUntilAt(t) else nil
		local verdict = Logic.check(baseline, cur, exemptUntil, cfg)
		if verdict == "violation" then
			violations += 1
		end
		baseline = Logic.advance(baseline, cur, verdict)
	end
	return violations
end

local GRAVITY = 196.2

-- 포물선: 처음 속도(vx, vy, vz)로 던져져 groundY에 닿으면 멈춰요 (그 뒤엔 걷기 속도로 앞으로).
local function ballistic(vx: number, vy: number, vz: number, walkAfter: number): PathFn
	local landT = 2 * math.max(vy, 0) / GRAVITY
	return function(t: number)
		if t <= landT then
			return vx * t, vy * t - 0.5 * GRAVITY * t * t, vz * t
		end
		local extra = t - landT
		return vx * landT, 0, vz * landT - walkAfter * extra
	end
end

return function(t: Test.Test)
	-- AC1
	t.test("AC1: 0.2s horizontal 8 studs (dive 40/s) is ok", function()
		t.eq(Logic.check(at(0, 0, 0, 10), at(8, 0, 0, 10.2), nil, cfg), "ok")
	end)

	t.test("AC1: 0.2s horizontal 30 studs is a violation (80*0.2+6 = 22)", function()
		t.eq(Logic.check(at(0, 0, 0, 10), at(0, 0, -30, 10.2), nil, cfg), "violation")
		t.eq(Logic.check(at(0, 0, 0, 10), at(18, 0, -24, 10.2), nil, cfg), "violation") -- 대각선 30
	end)

	t.test("AC1: horizontal 30 studs while MoveExemptUntil is later is exempt", function()
		t.eq(Logic.check(at(0, 0, 0, 10), at(0, 0, -30, 10.2), 10.5, cfg), "exempt")
		-- 면제가 이미 끝났으면 다시 검사해요
		t.eq(Logic.check(at(0, 0, 0, 10), at(0, 0, -30, 10.2), 10.1, cfg), "violation")
	end)

	-- AC2
	t.test("AC2: falling 100 studs is ok, rising 35 in 0.2s is a violation", function()
		t.eq(Logic.check(at(0, 100, 0, 10), at(0, 0, 0, 10.2), nil, cfg), "ok")
		t.eq(Logic.check(at(0, 0, 0, 10), at(0, 35, 0, 10.2), nil, cfg), "violation")
		t.eq(Logic.check(at(0, 0, 0, 10), at(0, 33, 0, 10.2), nil, cfg), "ok")
	end)

	-- AC3
	t.test("AC3: allowPass blocks for 2s after a violation", function()
		t.eq(Logic.allowPass(nil, 50, cfg), true)
		t.eq(Logic.allowPass(50, 51, cfg), false)
		t.eq(Logic.allowPass(50, 52.5, cfg), true)
	end)

	-- AC4
	t.test("AC4: strike log fires once on the 3rd strike", function()
		t.eq(Logic.strikeLog(1, false, cfg), false)
		t.eq(Logic.strikeLog(2, false, cfg), false)
		t.eq(Logic.strikeLog(3, false, cfg), true)
		t.eq(Logic.strikeLog(4, true, cfg), false)
		t.eq(Logic.strikeLog(3, false), true) -- cfg 생략 시 Config.MovementGuard
	end)

	-- advance
	t.test("advance: violation keeps the last good position with the new time", function()
		local nextBase = Logic.advance(at(1, 2, 3, 10), at(50, 2, 3, 10.2), "violation")
		t.eq(nextBase, at(1, 2, 3, 10.2))
	end)

	t.test("advance: ok/exempt move the baseline to the current sample", function()
		t.eq(Logic.advance(at(0, 0, 0, 10), at(3, 0, 0, 10.2), "ok"), at(3, 0, 0, 10.2))
		t.eq(Logic.advance(at(0, 0, 0, 10), at(300, 0, 0, 10.2), "exempt"), at(300, 0, 0, 10.2))
	end)

	t.test("advance: standing still keeps the baseline time up to StallGrace", function()
		local base = at(0, 0, 0, 10)
		t.eq(Logic.advance(base, at(0, 0, 0, 10.2), "ok"), base)
		t.eq(Logic.advance(base, at(0, 0, 0, 10 + Logic.StallGrace), "ok"), at(0, 0, 0, 10 + Logic.StallGrace))
	end)

	t.test("check: dt is capped at MaxGap (long wait does not allow a long teleport)", function()
		-- 10초 동안 기준이 안 바뀌어도 허용 거리는 80*1+6 = 86
		t.eq(Logic.check(at(0, 0, 0, 0), at(0, 0, -80, 10), nil, cfg), "ok")
		t.eq(Logic.check(at(0, 0, 0, 0), at(0, 0, -300, 10), nil, cfg), "violation")
	end)

	t.test("check: zero or negative dt only allows Slack", function()
		t.eq(Logic.check(at(0, 0, 0, 10), at(5, 0, 0, 10), nil, cfg), "ok")
		t.eq(Logic.check(at(0, 0, 0, 10), at(7, 0, 0, 9.9), nil, cfg), "violation")
	end)

	-- 정상 이동 시뮬레이션 (오탐 없음)
	t.test("sim: walking 16 studs/s for 10s has no violations", function()
		t.eq(
			simulate(function(time)
				return 0, 0, -16 * time
			end, 10),
			0
		)
	end)

	t.test("sim: ground dive (40 forward, 16 up) chained every cooldown has no violations", function()
		local cooldown = Config.Dive.Cooldown
		local path: PathFn = function(time)
			-- 쿨다운마다 다이브: 날아가는 동안 40, 그다음은 걷기 16
			local n = math.floor(time / cooldown)
			local local_ = time - n * cooldown
			local perCycle = 40 * 0.3 + 16 * (cooldown - 0.3)
			local fly = math.min(local_, 0.3)
			local walk = math.max(local_ - 0.3, 0)
			local y = math.max(16 * fly - 0.5 * GRAVITY * fly * fly, 0)
			return 0, y, -(n * perCycle + 40 * fly + 16 * walk)
		end
		t.eq(simulate(path, 8, nil, nil, 1 / 60), 0)
	end)

	t.test("sim: jump then air dive (40 forward, up capped 16) has no violations", function()
		local path: PathFn = function(time)
			-- 점프 0~0.3초 (위 50/s), 그 뒤 공중 다이브 40 수평
			if time < 0.3 then
				return 0, 50 * time - 0.5 * GRAVITY * time * time, -16 * time
			end
			local d = time - 0.3
			local y0 = 50 * 0.3 - 0.5 * GRAVITY * 0.09
			local y = math.max(y0 + 16 * d - 0.5 * GRAVITY * d * d, 0)
			return 0, y, -(16 * 0.3 + 40 * d)
		end
		t.eq(simulate(path, 2), 0)
	end)

	t.test("sim: wasabi launch (80 up, 30 forward) with walking has no violations even unmarked", function()
		t.eq(simulate(ballistic(0, 80, -46, 16), 3), 0)
	end)

	t.test("sim: wasabi launch marked with MoveExempt is exempt during the window", function()
		local verdict = Logic.check(at(0, 0, 0, 10), at(0, 60, -40, 10.2), 11, cfg)
		t.eq(verdict, "exempt")
	end)

	t.test("sim: skewer knockback (32 out, 22 up) plus walking has no violations", function()
		t.eq(simulate(ballistic(48, 22, 0, 16), 2), 0)
	end)

	t.test("sim: standing on a slice lifted 30 studs in 0.5s (ease-out) has no violations", function()
		local path: PathFn = function(time)
			local a = math.clamp(time / 0.5, 0, 1)
			return 0, 30 * (1 - (1 - a) * (1 - a)), 0
		end
		t.eq(simulate(path, 1.5, nil, 0.1), 0)
		t.eq(simulate(path, 1.5), 0)
	end)

	t.test("sim: belt pushing back 10 while walking forward / standing has no violations", function()
		t.eq(
			simulate(function(time)
				return 0, 0, -16 * time + 10 * time
			end, 5),
			0
		)
		t.eq(
			simulate(function(time)
				return 0, 0, 10 * time
			end, 5),
			0
		)
	end)

	t.test("sim: hot plate fall through several layers has no violations", function()
		t.eq(
			simulate(function(time)
				return 0, -0.5 * GRAVITY * time * time, 0
			end, 3),
			0
		)
	end)

	t.test("sim: server hitch (0.5s between samples) while diving has no violations", function()
		t.eq(
			simulate(function(time)
				return 0, 0, -40 * time
			end, 3, nil, 0.5),
			0
		)
	end)

	t.test("sim: replication stall then catch-up burst is not a violation", function()
		-- 0~1초 정상 걷기, 1~1.6초 복제가 멈춰 서버가 같은 위치만 봄, 1.6초에 다이브 속도로 따라잡음
		local path: PathFn = function(time)
			if time < 1 then
				return 0, 0, -16 * time
			elseif time < 1.6 then
				return 0, 0, -16
			end
			return 0, 0, -16 - 40 * (time - 1)
		end
		t.eq(simulate(path, 2.2), 0)
	end)

	t.test("sim: spawn placement / toLobby teleport is exempt via MoveExempt", function()
		local path: PathFn = function(time)
			if time < 1 then
				return 0, 0, 0
			end
			return 2000, 300, -50 -- 서버가 다른 아레나 스폰으로 옮김
		end
		local function exempt(time: number): number?
			return if time >= 0.95 then 0.95 + Config.MovementGuard.ExemptAfterServerMove else nil
		end
		t.eq(simulate(path, 3, exempt), 0)
	end)

	-- 위반이 나야 하는 경우
	t.test("sim: WalkSpeed 120 speed hack violates every sample", function()
		local v = simulate(function(time)
			return 0, 0, -120 * time
		end, 1)
		t.ok(v >= 3, `expected repeated violations, got {v}`)
	end)

	t.test("sim: teleport to the finish line after standing still is a violation", function()
		local path: PathFn = function(time)
			if time < 3 then
				return 0, 0, 0
			end
			return 0, 0, -400
		end
		local v = simulate(path, 3.4)
		t.ok(v >= 1, "teleport should be caught")
	end)

	t.test("sim: unmarked server move far away would be a violation (maps must mark)", function()
		t.eq(Logic.check(at(0, 0, 0, 10), at(2000, 300, 0, 10.2), nil, cfg), "violation")
	end)
end
