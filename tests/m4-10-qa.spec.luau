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
	-- 설계 변경 (m4-10 QA B1, 2026-10-08): 연속 밀기(벨트·급류·소용돌이·도마 기울기)는 반복 MoveExempt를 달지 않아요
	-- (면제 중엔 속도 조작이 안 잡혀서). 그 대신 밀기(+다이브 최악 합)가 표시 없이 기준 안인 것은 위 1번 표가 고정해요.
	t.test("continuous push maps do not refresh MoveExempt (pushes are within the unmarked limit)", function()
		t.ok(
			string.find(fs.readFile("src/shared/maps/RotatingBelt.luau"), "MoveExempt", 1, true) == nil,
			"belt conveyor"
		)
		t.ok(string.find(fs.readFile("src/shared/maps/ChefBoard.luau"), "EXEMPT_REFRESH", 1, true) == nil, "chef tilt")
		t.ok(RamenLayout.EXEMPT_REFRESH == nil, "ramen broth")
		t.ok(
			string.find(fs.readFile("src/shared/maps/RamenRapids.luau"), "MoveExempt.mark(player.Character)", 1, true)
				== nil,
			"ramen broth mark"
		)
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

	-- 설계 변경 (m4-10 QA B1): 회전 벨트(RotatingBelt.luau)는 연속 밀기만 속도를 줘서 표시가 없어요 → 목록에서 빼고
	-- 벨트의 순간 충격(젓가락 집기·놓기)은 RotatingBeltChopstick.luau의 표시로 확인해요.
	t.test("every map that gives a character an impulse also calls MoveExempt.mark", function()
		local chop = fs.readFile("src/shared/maps/RotatingBeltChopstick.luau")
		t.ok(string.find(chop, "MoveExempt.mark(character, GRAB_DURATION + 1)", 1, true) ~= nil, "chopstick grab")
		for _, file in
			{
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

	-- 6. 재검증 (be5a7f1·d5e5732): 연속 밀기 면제를 뺀 뒤 오탐, StallGrace 0.5 경계, 새 RoundService API
	-- 서버 샘플: 간격 SAMPLE 또는 SAMPLE + 한 프레임(60fps). 복제: 기본 지연 0.05초, onset부터 stall초 동안 멈춤.
	local function firstViolationWithStall(speed: number, stall: number): boolean
		for _, step in { SAMPLE, SAMPLE + 1 / 60 } do
			for k = 0, 40 do
				local onset = 2 + k * 0.01
				local seen = 0
				local baseline = at(0, 0, 0, 0)
				local time = 0
				while time < 6 do
					time += step
					local real = if time >= onset and time < onset + stall then onset - 0.05 else time - 0.05
					seen = math.max(seen, real)
					local cur = at(0, 0, -speed * seen, time)
					local verdict = Logic.check(baseline, cur, nil, cfg)
					if verdict == "violation" then
						return true
					end
					baseline = Logic.advance(baseline, cur, verdict)
				end
			end
		end
		return false
	end

	t.test("recheck: unmarked pushes + dive survive replication stalls of 0.45~0.6s (StallGrace 0.5)", function()
		local beltPush = localNumber("src/shared/maps/RotatingBelt.luau", "PUSH_SPEED")
		local dive = Config.Dive.ForwardSpeed
		local walk = Config.Character.WalkSpeed
		local speeds = {
			walk = walk,
			["belt backwards walk"] = beltPush + walk,
			["ramen broth + walk"] = RamenLayout.BROTH_PUSH_SPEED + walk,
			dive = dive,
			["ramen whirlpool side + dive"] = math.sqrt(dive * dive + RamenLayout.WHIRLPOOL_PUSH_SPEED ^ 2),
			["chef tilt + dive"] = ChefLogic.TILT_PUSH_SPEED + dive,
			["belt + dive (worst add)"] = beltPush + dive,
		}
		for name, speed in speeds do
			for _, stall in { 0.45, 0.5, 0.55, 0.6 } do
				t.ok(not firstViolationWithStall(speed, stall), `{name} ({speed}/s) stall {stall}s`)
			end
		end
	end)

	t.test("recheck: walking survives replication stalls up to 1.2s", function()
		for _, stall in { 0.7, 0.8, 1.0, 1.2 } do
			t.ok(not firstViolationWithStall(Config.Character.WalkSpeed, stall), `walk stall {stall}s`)
		end
	end)

	t.test("recheck: dive chain on the belt / in broth under latency jitter has no violations", function()
		local beltPush = localNumber("src/shared/maps/RotatingBelt.luau", "PUSH_SPEED")
		local dive = Config.Dive.ForwardSpeed
		-- 1.5초 주기: 0.9초 다이브 비행(40), 나머지는 밀기 섞인 달리기 (벨트 앞으로 16-10, 급류 20+16)
		local function chain(groundSpeed: number): (r: number) -> (number, number, number)
			return function(r: number)
				local cycles = math.floor(r / 1.5)
				local within = r - cycles * 1.5
				local per = dive * 0.9 + groundSpeed * 0.6
				local z = cycles * per
					+ (if within < 0.9 then dive * within else dive * 0.9 + groundSpeed * (within - 0.9))
				return 0, 0, -z
			end
		end
		local function jitter(time: number): number
			return 0.05 + 0.15 * ((math.floor(time / SAMPLE) % 3) / 2)
		end
		t.eq(simulateLatency(chain(Config.Character.WalkSpeed - beltPush), 12, jitter), 0, "belt dive chain")
		t.eq(simulateLatency(chain(RamenLayout.BROTH_PUSH_SPEED + 16), 12, jitter), 0, "broth dive chain")
		t.eq(simulateLatency(chain(ChefLogic.TILT_PUSH_SPEED + 16), 12, jitter), 0, "tilt dive chain")
	end)

	t.test("recheck: StallGrace boundary caps a stand-still teleport at 80*(0.5+one sample)+6", function()
		t.eq(Logic.StallGrace, 0.5)
		for _, step in { SAMPLE, SAMPLE + 1 / 60, SAMPLE + 2 / 60 } do
			local cap = cfg.MaxHorizontalSpeed * (Logic.StallGrace + step) + cfg.Slack
			for n = 1, 12 do
				local baseline = at(0, 0, 0, 0)
				local time = 0
				for _ = 1, n do
					time += step
					local cur = at(0, 0, 0, time)
					baseline = Logic.advance(baseline, cur, Logic.check(baseline, cur, nil, cfg))
				end
				t.ok(time - baseline.t < Logic.StallGrace, `baseline age {time - baseline.t}`)
				local verdict = Logic.check(baseline, at(0, 0, -(cap + 0.5), time + step), nil, cfg)
				t.eq(verdict, "violation", `step {step} still {n} samples`)
			end
		end
	end)

	t.test("recheck: impulse marks stay (chopstick, wasabi, soy, tobiko, skewer, ramen sweeper, chef knife)", function()
		local function has(file: string, text: string)
			t.ok(string.find(fs.readFile(file), text, 1, true) ~= nil, `{file}: {text}`)
		end
		has("src/shared/maps/RotatingBeltChopstick.luau", "MoveExempt.mark(character, GRAB_DURATION + 1)")
		has("src/shared/maps/SoySwampHazards.luau", "MoveExempt.mark(character, WASABI_EXEMPT)")
		has("src/shared/maps/SoySwampHazards.luau", "MoveExempt.mark(player.Character, Layout.KNOCKDOWN_DURATION + 1)")
		has("src/shared/maps/SkewerShowdown.luau", "MoveExempt.mark(player.Character)")
		has("src/shared/maps/RamenRapids.luau", "MoveExempt.mark(player.Character, Layout.KNOCKDOWN_TIME + 0.5)")
		has("src/shared/maps/ChefBoard.luau", "MoveExempt.mark(player.Character, Logic.KNOCKDOWN_TIME + 1)")
		has("src/server/RoundService.luau", "MoveExempt.mark(character)")
		has("src/server/CharacterUtil.luau", "MoveExempt.mark(character)")
	end)

	t.test("recheck: exempt cap still covers the largest marked impulses in one sample", function()
		local cases = {
			{ h = ChefLogic.KNOCK_HORIZONTAL + Config.Character.WalkSpeed, v = ChefLogic.KNOCK_UP },
			{ h = RamenLayout.KNOCK_OUTWARD + Config.Character.WalkSpeed, v = RamenLayout.KNOCK_UP },
			{ h = SoyLayout.WASABI_FORWARD + Config.Character.WalkSpeed, v = SoyLayout.WASABI_UP },
		}
		for _, case in cases do
			-- 한 샘플이 한 프레임 늦어도 (0.2 + 1/60)
			local dt = SAMPLE + 1 / 60
			t.ok(case.h * dt <= Logic.ExemptMaxHorizontalSpeed * SAMPLE + cfg.Slack, `h {case.h}`)
			t.ok(case.v * dt <= Logic.ExemptMaxRiseSpeed * SAMPLE + cfg.Slack, `v {case.v}`)
		end
	end)

	t.test("recheck: RoundService placement API registers before placing, is pcall'd and cleared on close", function()
		local round = fs.readFile("src/server/RoundService.luau")
		local registerAt = string.find(round, "placedRacing[roomId] = function", 1, true)
		local spawnAt = string.find(round, "cleanup:add(task.spawn(placeAt", 1, true)
		t.ok(registerAt ~= nil and spawnAt ~= nil and registerAt < spawnAt, "placedRacing registered before placeAt")
		t.ok(string.find(round, "pcall(listener, player, character, position)", 1, true) ~= nil, "listener pcall")
		t.ok(string.find(round, "placedRacing[roomId] = nil", 1, true) ~= nil, "cleared on close")
		-- 배치 알림은 PivotTo 바로 뒤, placed = true 앞 (그 사이 yield 없음)
		local pivot = string.find(round, "character:PivotTo(spawn.CFrame + SPAWN_LIFT)\n\t\t\tnotifyPlaced(", 1, true)
		t.ok(pivot ~= nil, "notifyPlaced right after PivotTo")
		-- activeRoomOf(잡기 등 M3)는 그대로 round.active를 요구
		t.ok(
			string.find(round, "return round.active\n\t\t\t\tand not round.ended", 1, true) ~= nil,
			"activeRacing unchanged"
		)
		local guard = fs.readFile("src/server/MovementGuardService.luau")
		t.ok(
			string.find(guard, "return false -- 감시하던 캐릭터가 아니에요", 1, true) ~= nil,
			"other character denied"
		)
	end)
end
