--!strict
-- m3-06 다이브: canDive, launch, step, 연타 손해

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local DiveLogic = RobloxRequire.require(Shared.DiveLogic)
local Config = RobloxRequire.require(Shared.Config)

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function readyInput(overrides: { [string]: any }?): any
	local input: { [string]: any } = {
		hasCharacter = true,
		health = 100,
		anchored = false,
		sitting = false,
		walkSpeed = 16,
		platformStand = false,
		spectating = false,
		state = DiveLogic.newState(),
		now = 10,
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function launchInput(overrides: { [string]: any }?): any
	local input: { [string]: any } = {
		moveX = 0,
		moveZ = 0,
		lookX = 0,
		lookZ = -1,
		walkSpeed = 16,
		grounded = true,
		jumpPower = 50,
		vy = 0,
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function horizontalSpeed(v: any): number
	return math.sqrt(v.vx * v.vx + v.vz * v.vz)
end

return function(t: Test.Test)
	t.test("AC1: 조건이 다 맞으면 다이브할 수 있어요", function()
		t.eq(DiveLogic.canDive(readyInput()), true)
	end)

	t.test("AC1: 조건 하나만 어긋나도 못 해요", function()
		local cases: { [string]: { [string]: any } } = {
			noCharacter = { hasCharacter = false },
			dead = { health = 0 },
			walkSpeedZero = { walkSpeed = 0 },
			platformStand = { platformStand = true },
			anchored = { anchored = true },
			sitting = { sitting = true },
			spectating = { spectating = true },
			flying = { state = { phase = "Flying", phaseStart = 9.9, lastDiveAt = 5 } },
			stunned = { state = { phase = "Stunned", phaseStart = 9.9, lastDiveAt = 5 } },
			cooldown = { state = { phase = "Ready", phaseStart = 9.9, lastDiveAt = 10 - 1.49 } },
		}
		for name, override in cases do
			t.eq(DiveLogic.canDive(readyInput(override)), false, name)
		end
	end)

	t.test("AC1: 마지막 시작 뒤 1.5초면 다시 할 수 있어요", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 2.2)
		state = DiveLogic.step(state, 2.4, true, false) -- Stunned
		state = DiveLogic.step(state, 2.9, true, false) -- Ready
		t.eq(state.phase, "Ready")
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 3.69 })), false)
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 2.2 + 1.5 })), true)
		t.ok(near(DiveLogic.cooldownLeft(state, 3.2), 0.5))
		t.eq(DiveLogic.cooldownLeft(state, 4), 0)
	end)

	t.test("AC2: 이동 입력 방향으로 날아가요", function()
		local v = DiveLogic.launch(launchInput({ moveX = 1, moveZ = 0 }))
		t.ok(near(v.vx / horizontalSpeed(v), 1) and near(v.vz, 0), "direction (1, 0)")
	end)

	t.test("AC2: 이동 입력이 짧으면 바라보는 방향으로", function()
		local v = DiveLogic.launch(launchInput({ moveX = 0.05, moveZ = 0, lookX = 0, lookZ = -1 }))
		t.ok(near(v.vx, 0) and near(v.vz / horizontalSpeed(v), -1), "direction (0, -1)")
	end)

	t.test("AC2: 방향은 정규화돼요", function()
		local v = DiveLogic.launch(launchInput({ moveX = 0.3, moveZ = 0.4 }))
		t.ok(near(horizontalSpeed(v), 40))
		t.ok(near(v.vx / v.vz, 0.75))
	end)

	t.test("AC2: 수평 속력은 WalkSpeed 비율을 따르고 기본보다 빨라지지 않아요", function()
		t.ok(near(horizontalSpeed(DiveLogic.launch(launchInput({ walkSpeed = 16 }))), 40), "16 -> 40")
		t.ok(near(horizontalSpeed(DiveLogic.launch(launchInput({ walkSpeed = 8 }))), 20), "8 -> 20")
		t.ok(near(horizontalSpeed(DiveLogic.launch(launchInput({ walkSpeed = 24 }))), 40), "24 -> 40")
	end)

	t.test("AC3: 수직 속도", function()
		t.eq(DiveLogic.launch(launchInput({ grounded = true, jumpPower = 50 })).vy, 16)
		t.eq(DiveLogic.launch(launchInput({ grounded = true, jumpPower = 0 })).vy, 0)
		t.eq(DiveLogic.launch(launchInput({ grounded = false, jumpPower = 50, vy = -30 })).vy, -30)
	end)

	t.test("AC4: 발사 직후 땅에 닿아 있어도 Flying", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 1)
		t.eq(state.phase, "Flying")
		t.eq(state.lastDiveAt, 1)
		t.eq(DiveLogic.step(state, 1.05, true, false).phase, "Flying")
		t.eq(DiveLogic.step(state, 1.2, false, false).phase, "Flying")
	end)

	t.test("AC4: 0.2초 뒤 착지하면 Stunned, 0.5초 뒤 Ready", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 1)
		state = DiveLogic.step(state, 1.2, true, false)
		t.eq(state.phase, "Stunned")
		t.eq(DiveLogic.step(state, 1.69, true, false).phase, "Stunned")
		local ready = DiveLogic.step(state, 1.7, true, false)
		t.eq(ready.phase, "Ready")
		t.eq(ready.lastDiveAt, 1)
	end)

	t.test("AC4: 공중에서 1초가 지나면 경직 없이 Ready", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 3)
		t.eq(DiveLogic.step(state, 3.99, false, false).phase, "Flying")
		t.eq(DiveLogic.step(state, 3 + Config.Dive.MaxFlightTime, false, false).phase, "Ready")
	end)

	t.test("AC4: 끊기면 어느 상태든 바로 Ready (쿨다운은 그대로)", function()
		local flying = DiveLogic.begin(DiveLogic.newState(), 1)
		local stopped = DiveLogic.step(flying, 1.01, false, true)
		t.eq(stopped.phase, "Ready")
		t.eq(stopped.lastDiveAt, 1)
		local stunned = DiveLogic.step(flying, 1.2, true, false)
		t.eq(DiveLogic.step(stunned, 1.21, true, true).phase, "Ready")
		local ready = DiveLogic.newState()
		t.eq(DiveLogic.step(ready, 5, true, true).phase, "Ready")
	end)

	t.test("AC5: 쿨다운마다 다이브하는 것이 걷기만 하는 것보다 느려요", function()
		local gravity = 196.2
		local flight = DiveLogic.groundFlightTime(Config.Dive.UpSpeed, gravity)
		t.ok(flight > DiveLogic.LandingGrace, "flight longer than landing grace")
		local diveDistance = Config.Dive.ForwardSpeed * flight
		local walkDistance = Config.Character.WalkSpeed * (flight + Config.Dive.LandingStun)
		t.ok(diveDistance < walkDistance, `dive {diveDistance} < walk {walkDistance}`)
	end)

	t.test("groundFlightTime: 위로 안 튀면 0", function()
		t.eq(DiveLogic.groundFlightTime(0, 196.2), 0)
		t.ok(near(DiveLogic.groundFlightTime(19.62, 196.2), 0.2))
	end)
end
