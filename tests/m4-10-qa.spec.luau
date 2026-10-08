--!strict
-- m4-10 QA: 서버 이동 감시가 main(맵 6개 병합 뒤)의 실제 상수로 정상 플레이를 잡지 않는지,
-- 각 맵의 MoveExempt 표시 간격·길이, 복제 지연·멈춤 상황, 서비스 코드 계약(킥 없음, 구제 통과 무검사)을 확인해요.
-- 맵 모듈 지역 상수(벨트 밀기·꼬치 넉백 등)는 소스에서 읽어요 — 값이 바뀌면 이 표도 다시 확인되게.

local fs = require("@lune/fs")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.MovementGuardLogic)
local Config = RobloxRequire.require(Shared.Config)
local SoyLayout = RobloxRequire.require(Shared.maps.SoySwampLayout)
local RamenLayout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local ChefLogic = RobloxRequire.require(Shared.maps.ChefBoardLogic)

local cfg = Config.MovementGuard
local GRAVITY = 196.2
local SAMPLE = cfg.SampleInterval

type Sample = { x: number, y: number, z: number, t: number }

local function at(x: number, y: number, z: number, t: number): Sample
	return { x = x, y = y, z = z, t = t }
end

-- 소스 파일에서 `local NAME = 숫자`를 읽어요.
local function localNumber(file: string, name: string): number
	local source = fs.readFile(file)
	local value = string.match(source, "local " .. name .. "%s*=%s*([%d%.]+)")
	assert(value, `{name} not found in {file}`)
	return tonumber(value) :: number
end

local function horizontalLimit(dt: number): number
	return cfg.MaxHorizontalSpeed * dt + cfg.Slack
end

local function riseLimit(dt: number): number
	return cfg.MaxRiseSpeed * dt + cfg.Slack
end

-- 처음 속도 (h 수평, v 위)로 던져진 포물선이 첫 샘플 간격 dt 동안 가는 거리 (가장 불리한 구간 = 출발 직후)
local function launchDisplacement(h: number, v: number, dt: number): (number, number)
	return h * dt, v * dt - 0.5 * GRAVITY * dt * dt
end

-- 복제 지연 시뮬레이션: 서버 시각 t에 보이는 위치는 path(t - latency(t)) (단, 이미 본 것보다 과거로는 안 가요).
-- 서버는 SAMPLE 간격으로 check → advance. 위반 수를 돌려줘요.
local function simulateLatency(
	path: (r: number) -> (number, number, number),
	duration: number,
	latency: (t: number) -> number
): number
	local seen = 0
	local x, y, z = path(0)
	local baseline = at(x, y, z, 0)
	local violations = 0
	local t = 0
	while t < duration do
		t += SAMPLE
		seen = math.max(seen, t - latency(t))
		local cx, cy, cz = path(seen)
		local cur = at(cx, cy, cz, t)
		local verdict = Logic.check(baseline, cur, nil, cfg)
		if verdict == "violation" then
			violations += 1
		end
		baseline = Logic.advance(baseline, cur, verdict)
	end
	return violations
end

return function(t: Test.Test)
	-- 1. 표시(MoveExempt) 없이도 한 샘플(0.2초) 안에 들어오는지: main의 실제 상수
	t.test("unmarked worst case per 0.2s sample stays within 22 horizontal / 34 rise", function()
		local beltPush = localNumber("src/shared/maps/RotatingBelt.luau", "PUSH_SPEED")
		local skewerOut = localNumber("src/shared/maps/SkewerShowdown.luau", "KNOCK_OUTWARD")
		local skewerUp = localNumber("src/shared/maps/SkewerShowdown.luau", "KNOCK_UP")
		local walk = Config.Character.WalkSpeed
		local dive = Config.Dive.ForwardSpeed
		local cases: { { name: string, h: number, v: number } } = {
			{ name = "walk", h = walk, v = 0 },
			{ name = "jump", h = walk, v = Config.Character.JumpPower },
			{ name = "ground dive", h = dive, v = Config.Dive.UpSpeed },
			{ name = "air dive after jump", h = dive, v = Config.Dive.AirMaxUpSpeed },
			{ name = "wasabi launch", h = SoyLayout.WASABI_FORWARD, v = SoyLayout.WASABI_UP },
			-- 와사비 공중에서 다이브: 수평은 다이브 값으로 덮어써요, 위는 AirMaxUpSpeed로 잘려요
			{ name = "wasabi + dive", h = dive, v = Config.Dive.AirMaxUpSpeed },
			{ name = "belt push + walk backwards", h = beltPush + walk, v = 0 },
			{ name = "dive on belt (worst add)", h = dive + beltPush, v = Config.Dive.UpSpeed },
			{ name = "tobiko ball hit", h = SoyLayout.BALL_MAX_SPEED, v = 0 },
			{ name = "skewer knockback", h = skewerOut, v = skewerUp },
			{ name = "ramen broth push + walk", h = RamenLayout.BROTH_PUSH_SPEED + walk, v = 0 },
			{ name = "ramen dive in broth (worst add)", h = dive + RamenLayout.BROTH_PUSH_SPEED, v = 0 },
			{
				name = "ramen whirlpool side + forward",
				h = math.sqrt(RamenLayout.WHIRLPOOL_FORWARD_SPEED ^ 2 + RamenLayout.WHIRLPOOL_PUSH_SPEED ^ 2) + walk,
				v = 0,
			},
			{ name = "ramen sweeper knockback", h = RamenLayout.KNOCK_OUTWARD, v = RamenLayout.KNOCK_UP },
			{ name = "chef knife knockback", h = ChefLogic.KNOCK_HORIZONTAL, v = ChefLogic.KNOCK_UP },
			{ name = "chef tilt push + dive", h = ChefLogic.TILT_PUSH_SPEED + dive, v = 0 },
		}
		for _, case in cases do
			local h, v = launchDisplacement(case.h, case.v, SAMPLE)
			t.ok(h <= horizontalLimit(SAMPLE), `{case.name}: horizontal {h} > {horizontalLimit(SAMPLE)}`)
			t.ok(v <= riseLimit(SAMPLE), `{case.name}: rise {v} > {riseLimit(SAMPLE)}`)
		end
	end)

	t.test("skewer chef hand lift (ease-out 30 in 0.5s) rises at most within the limit per sample", function()
		local height = localNumber("src/shared/maps/SkewerShowdown.luau", "HAND_LIFT_HEIGHT")
		local time = localNumber("src/shared/maps/SkewerShowdown.luau", "HAND_LIFT_TIME")
		local function lift(s: number): number
			local a = math.min(s / time, 1)
			return height * (1 - (1 - a) * (1 - a))
		end
		-- 가장 빠른 구간은 출발 직후
		t.ok(lift(SAMPLE) - lift(0) <= riseLimit(SAMPLE), "hand lift too fast")
	end)

	t.test("chef board tilt raises the board edge slower than the rise limit", function()
		local edgeRise = ChefLogic.BOARD_RADIUS * math.sin(math.rad(ChefLogic.TILT_MAX_DEG))
		-- TILT_RAMP 동안 다 기울어도 0.2초 몫은 그보다 작아요
		t.ok(edgeRise * math.min(SAMPLE / ChefLogic.TILT_RAMP, 1) <= riseLimit(SAMPLE), "tilt edge too fast")
	end)

	t.test("ramen chashu bob is far slower than the rise limit", function()
		local maxSpeed = math.pi * RamenLayout.CHASHU_RANGE / RamenLayout.CHASHU_PERIOD
		t.ok(maxSpeed * SAMPLE <= riseLimit(SAMPLE), "chashu too fast")
	end)

	-- 2. 표시 간격·길이
	t.test("continuous push maps refresh MoveExempt before it runs out (refresh + one sample < exempt)", function()
		local refreshes = {
			belt = localNumber("src/shared/maps/RotatingBelt.luau", "CONVEYOR_EXEMPT_REFRESH"),
			chef = localNumber("src/shared/maps/ChefBoard.luau", "EXEMPT_REFRESH"),
			ramen = RamenLayout.EXEMPT_REFRESH,
		}
		for name, refresh in refreshes do
			t.ok(
				refresh + SAMPLE < cfg.ExemptAfterServerMove,
				`{name}: refresh {refresh} too close to exempt {cfg.ExemptAfterServerMove}`
			)
		end
	end)

	t.test("wasabi exempt covers the whole launch flight", function()
		local exempt = localNumber("src/shared/maps/SoySwampHazards.luau", "WASABI_EXEMPT")
		local flight = SoyLayout.WASABI_HOLD + 2 * SoyLayout.WASABI_UP / GRAVITY
		t.ok(exempt > flight, `wasabi exempt {exempt} <= flight {flight}`)
	end)

	t.test("knockdown exempts last at least as long as the knockdown", function()
		-- ChefBoard: KNOCKDOWN_TIME + 1, RamenRapids: KNOCKDOWN_TIME + 0.5, SoySwamp: KNOCKDOWN_DURATION + 1
		local chef = fs.readFile("src/shared/maps/ChefBoard.luau")
		t.ok(string.find(chef, "MoveExempt.mark(player.Character, Logic.KNOCKDOWN_TIME + 1)", 1, true) ~= nil)
		local ramen = fs.readFile("src/shared/maps/RamenRapids.luau")
		t.ok(string.find(ramen, "MoveExempt.mark(player.Character, Layout.KNOCKDOWN_TIME + 0.5)", 1, true) ~= nil)
		local soy = fs.readFile("src/shared/maps/SoySwampHazards.luau")
		t.ok(string.find(soy, "MoveExempt.mark(player.Character, Layout.KNOCKDOWN_DURATION + 1)", 1, true) ~= nil)
		-- 꼬치 넉백은 기본값(1초) = KNOCKDOWN_TIME(1). 32/22 studs/s라 표시가 없어도 기준 안 (위 테스트)
		t.ok(cfg.ExemptAfterServerMove >= localNumber("src/shared/maps/SkewerShowdown.luau", "KNOCKDOWN_TIME"))
	end)

	t.test("every map that sets a character velocity also calls MoveExempt.mark", function()
		for _, file in
			{
				"src/shared/maps/RotatingBelt.luau",
				"src/shared/maps/SoySwampHazards.luau",
				"src/shared/maps/SkewerShowdown.luau",
				"src/shared/maps/RamenRapids.luau",
				"src/shared/maps/ChefBoard.luau",
			}
		do
			local source = fs.readFile(file)
			t.ok(string.find(source, "root.AssemblyLinearVelocity =", 1, true) ~= nil, `{file}: no velocity set?`)
			t.ok(string.find(source, "MoveExempt.mark(", 1, true) ~= nil, `{file}: no MoveExempt.mark`)
		end
	end)

	-- 3. 복제 지연·멈춤
	t.test("dive chain (40/s) under 0.15s latency jitter has no violations", function()
		local dive = Config.Dive.ForwardSpeed
		local v = simulateLatency(
			function(r)
				return 0, 0, -dive * r
			end,
			10,
			function(time)
				-- 0.05~0.2초 사이를 오가는 지연
				return 0.05 + 0.15 * ((math.floor(time / SAMPLE) % 3) / 2)
			end
		)
		t.eq(v, 0, "dive under jitter")
	end)

	t.test("dive (40/s) through a 0.6s replication stall then catch-up has no violations", function()
		local dive = Config.Dive.ForwardSpeed
		local v = simulateLatency(
			function(r)
				return 0, 0, -dive * r
			end,
			6,
			function(time)
				-- 2.05~2.65초 동안 복제가 멈춤 (서버에 보이는 위치가 그대로)
				if time >= 2.05 and time < 2.65 then
					return time - 2.05 + 0.05
				end
				return 0.05
			end
		)
		t.eq(v, 0, "dive through stall")
	end)

	t.test("partial stall: last update just after a sample, catch-up next sample (dive 40) is ok", function()
		-- 기준 샘플이 0.2초 낡아도(움직임 있음 → StallGrace 적용 안 됨) 다음 샘플 따라잡기는 40*0.4 = 16 ≤ 22
		local dive = Config.Dive.ForwardSpeed
		local base = at(0, 0, -dive * 0.0, 1.2) -- 서버 1.2초에 본 위치는 실제 1.0초 위치(0.2초 낡음)
		local cur = at(0, 0, -dive * 0.4, 1.4) -- 0.2초 뒤 따라잡음
		t.eq(Logic.check(base, cur, nil, cfg), "ok")
	end)

	-- 4. 남은 한계 (결정 기록 2026-10-08 복제 멈춤): 서 있다가 순간이동해도 86 studs를 넘으면 항상 위반
	t.test("standing still for any time never allows a teleport longer than 80*MaxGap+Slack", function()
		local cap = cfg.MaxHorizontalSpeed * Logic.MaxGap + cfg.Slack
		for _, still in { 0.2, 0.6, 0.8, 1.0, 1.4, 5 } do
			local baseline = at(0, 0, 0, 0)
			local time = 0
			while time < still - 1e-9 do
				time += SAMPLE
				baseline =
					Logic.advance(baseline, at(0, 0, 0, time), Logic.check(baseline, at(0, 0, 0, time), nil, cfg))
			end
			local verdict = Logic.check(baseline, at(0, 0, -(cap + 1), time + SAMPLE), nil, cfg)
			t.eq(verdict, "violation", `still {still}s then teleport {cap + 1}`)
		end
	end)

	-- 5. 서비스 계약 (소스)
	t.test("MovementGuardService never kicks or eliminates", function()
		local source = fs.readFile("src/server/MovementGuardService.luau")
		t.ok(string.find(source, ":Kick(", 1, true) == nil, "Kick found")
		t.ok(string.find(source, "eliminate", 1, true) == nil, "eliminate found")
		t.ok(string.find(source, "PlayerRemoving", 1, true) ~= nil, "no PlayerRemoving cleanup")
		t.ok(string.find(source, "setPassValidator(validatePass)", 1, true) ~= nil, "validator not registered")
	end)

	t.test("pass validator is only consulted from ctx.pass, not for rescue passes", function()
		local source = fs.readFile("src/server/RoundService.luau")
		local count = 0
		for _ in string.gmatch(source, "passAllowed%(player%)") do
			count += 1
		end
		t.eq(count, 1, "passAllowed(player) call sites")
		-- RoundLogic(구제 통과 포함)는 validator를 모름
		local logic = fs.readFile("src/shared/RoundLogic.luau")
		t.ok(string.find(logic, "alidator", 1, true) == nil, "RoundLogic references a validator")
	end)

	t.test("MovementGuardService is started by the server bootstrap", function()
		local source = fs.readFile("src/server/init.server.luau")
		t.ok(string.find(source, "MovementGuardService", 1, true) ~= nil)
	end)
end
