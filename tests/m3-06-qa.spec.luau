--!strict
-- m3-06 다이브 QA: 경계값, 프레임 시뮬레이션(연타 손해), 서버 값·리모트를 건드리지 않는지 소스 확인

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local DiveLogic = RobloxRequire.require(Shared.DiveLogic)
local Config = RobloxRequire.require(Shared.Config)

local GRAVITY = 196.2
local DT = 1 / 60

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) < (eps or 1e-6)
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

-- 한 방향(-Z)으로 달리면서 전략대로 다이브하는 단순 물리 시뮬레이션.
-- Ready면 WalkSpeed로 걷고, Flying이면 발사 수평 속도 유지(DiveController의 PreSimulation과 같음), Stunned면 멈춤.
-- strategy(grounded, vy, state, now) -> "dive" | "jump" | nil
local function simulate(duration: number, strategy: (boolean, number, any, number) -> string?): number
	local state = DiveLogic.newState()
	local x, y, vy = 0, 0, 0
	local horizontal = 0
	local now = 0
	while now < duration do
		local grounded = y <= 0 and vy <= 0
		state = DiveLogic.step(state, now, grounded, false)
		local action = strategy(grounded, vy, state, now)
		if action == "dive" and DiveLogic.canDive(readyInput({ state = state, now = now })) then
			local v = DiveLogic.launch(launchInput({ moveZ = -1, grounded = grounded, vy = vy }))
			state = DiveLogic.begin(state, now)
			horizontal = math.sqrt(v.vx * v.vx + v.vz * v.vz)
			vy = v.vy
		elseif action == "jump" and grounded and state.phase == "Ready" then
			vy = Config.Character.JumpPower
		end

		local speed = 0
		if state.phase == "Flying" then
			speed = horizontal
		elseif state.phase == "Ready" then
			speed = Config.Character.WalkSpeed
		end
		x += speed * DT
		vy -= GRAVITY * DT
		y += vy * DT
		if y <= 0 then
			y, vy = 0, 0
		end
		now += DT
	end
	return x / duration
end

return function(t: Test.Test)
	-- canDive 경계값
	t.test("canDive: WalkSpeed가 아주 작아도 0보다 크면 할 수 있어요", function()
		t.eq(DiveLogic.canDive(readyInput({ walkSpeed = 0.01 })), true)
		t.eq(DiveLogic.canDive(readyInput({ walkSpeed = -1 })), false)
	end)

	t.test("canDive: 체력이 음수면 못 해요", function()
		t.eq(DiveLogic.canDive(readyInput({ health = -5 })), false)
	end)

	t.test("canDive: 쿨다운 경계는 정확히 1.5초 (부동소수점 오차 허용)", function()
		local state = { phase = "Ready", phaseStart = 0, lastDiveAt = 0.1 }
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 0.1 + 1.5 })), true)
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 0.1 + 1.4999 })), false)
	end)

	t.test("canDive: 같은 키를 연달아 눌러도 두 번째는 안 나가요 (같은 시각)", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 5)
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 5 })), false)
	end)

	-- launch 경계값
	t.test("launch: 이동 입력 길이가 정확히 0.1이면 바라보는 방향", function()
		local v = DiveLogic.launch(launchInput({ moveX = 0.1, moveZ = 0, lookX = 0, lookZ = -1 }))
		t.ok(near(v.vx, 0) and near(v.vz, -40), `got {v.vx}, {v.vz}`)
	end)

	t.test("launch: 이동도 바라보는 방향도 수평 성분이 없으면 -Z로", function()
		local v = DiveLogic.launch(launchInput({ lookX = 0, lookZ = 0 }))
		t.ok(near(v.vx, 0) and near(v.vz, -40), `got {v.vx}, {v.vz}`)
	end)

	t.test("launch: 바라보는 방향도 정규화돼요", function()
		local v = DiveLogic.launch(launchInput({ lookX = 0.03, lookZ = 0.04 }))
		t.ok(near(math.sqrt(v.vx * v.vx + v.vz * v.vz), 40))
	end)

	t.test(
		"launch: 간장 웅덩이 값(WalkSpeed 50%, JumpPower 0)이면 절반 속력에 위로 안 튀어요",
		function()
			local v = DiveLogic.launch(launchInput({ walkSpeed = 8, jumpPower = 0 }))
			t.ok(near(math.sqrt(v.vx * v.vx + v.vz * v.vz), 20))
			t.eq(v.vy, 0)
		end
	)

	-- m3-09: QA B1 수정으로 공중 다이브의 위쪽 속도는 Config.Dive.AirMaxUpSpeed까지만 남아요.
	-- (원래 기대값 45 = "그대로"는 B1의 원인이라 바꿨어요. 꼭대기·내려가는 중은 그대로.)
	t.test("launch: 공중에서 빨리 올라가는 중이면 수직 속도를 AirMaxUpSpeed로 잘라요", function()
		t.eq(DiveLogic.launch(launchInput({ grounded = false, vy = 45 })).vy, Config.Dive.AirMaxUpSpeed)
		t.eq(DiveLogic.launch(launchInput({ grounded = false, vy = 5 })).vy, 5)
		t.eq(DiveLogic.launch(launchInput({ grounded = false, vy = -20 })).vy, -20)
	end)

	t.test("launch: WalkSpeed 0이면 수평 0 (canDive가 먼저 막지만 음수 배수는 안 나와요)", function()
		local v = DiveLogic.launch(launchInput({ walkSpeed = 0 }))
		t.ok(near(v.vx, 0) and near(v.vz, 0))
		local w = DiveLogic.launch(launchInput({ walkSpeed = -4 }))
		t.ok(near(w.vx, 0) and near(w.vz, 0))
	end)

	-- step 경계값
	t.test("step: 착지 유예 0.1초 정각에 땅이면 Stunned", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 1)
		t.eq(DiveLogic.step(state, 1.1, true, false).phase, "Stunned")
		t.eq(DiveLogic.step(state, 1.0999, true, false).phase, "Flying")
	end)

	t.test("step: 최대 체공 시각에 마침 착지하면 경직이 붙어요 (착지 판정 우선)", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 0)
		t.eq(DiveLogic.step(state, Config.Dive.MaxFlightTime, true, false).phase, "Stunned")
	end)

	t.test("step: 경직은 땅 여부와 상관없이 0.5초", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 0)
		state = DiveLogic.step(state, 0.2, true, false)
		t.eq(DiveLogic.step(state, 0.69, false, false).phase, "Stunned")
		t.eq(DiveLogic.step(state, 0.7, false, false).phase, "Ready")
	end)

	t.test("begin/step은 받은 상태를 바꾸지 않아요", function()
		local ready = DiveLogic.newState()
		local flying = DiveLogic.begin(ready, 3)
		t.eq(ready.phase, "Ready")
		t.eq(ready.lastDiveAt, nil)
		DiveLogic.step(flying, 3.5, true, false)
		t.eq(flying.phase, "Flying")
	end)

	t.test("끊긴 뒤에도 쿨다운은 시작 기준으로 흘러요", function()
		local state = DiveLogic.begin(DiveLogic.newState(), 2)
		state = DiveLogic.step(state, 2.05, false, true)
		t.eq(state.phase, "Ready")
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 3 })), false)
		t.eq(DiveLogic.canDive(readyInput({ state = state, now = 3.5 })), true)
	end)

	-- AC5 보강: 프레임 시뮬레이션
	t.test("AC5 시뮬레이션: 걷기만 하면 WalkSpeed", function()
		local speed = simulate(15, function()
			return nil
		end)
		t.ok(near(speed, Config.Character.WalkSpeed, 0.1), `walk {speed}`)
	end)

	t.test("AC5 시뮬레이션: 땅에서 쿨다운마다 다이브하면 걷기보다 느려요", function()
		local walk = Config.Character.WalkSpeed
		local speed = simulate(15, function()
			return "dive"
		end)
		t.ok(speed < walk, `ground dive spam {speed} < walk {walk}`)
	end)

	t.test("AC5 시뮬레이션: 점프 꼭대기 다이브를 반복해도 걷기보다 느려요", function()
		local walk = Config.Character.WalkSpeed
		local speed = simulate(15, function(grounded, vy)
			if grounded then
				return "jump"
			end
			if vy <= 0 then
				return "dive"
			end
			return nil
		end)
		t.ok(speed < walk, `apex jump-dive spam {speed} < walk {walk}`)
	end)
	-- QA 리포트 B1 (m3-09에서 수정: 공중 다이브 vy 상한): 점프 직후(올라가는 중) 다이브를 반복해도 걷기보다 느려요.
	for _, delay in { 0.02, 0.05, 0.1, 0.2 } do
		t.test(`B1 시뮬레이션: 점프 {delay}초 뒤 다이브를 반복해도 걷기보다 느려요`, function()
			local walk = Config.Character.WalkSpeed
			local jumpedAt: number? = nil
			local speed = simulate(15, function(grounded, _vy, state, now)
				if grounded and state.phase == "Ready" then
					jumpedAt = now
					return "jump"
				end
				if jumpedAt ~= nil and now - (jumpedAt :: number) >= delay then
					jumpedAt = nil
					return "dive"
				end
				return nil
			end)
			t.ok(speed < walk, `jump+{delay}s dive spam {speed} < walk {walk}`)
		end)
	end

	t.test("AC9 시뮬레이션: 점프 꼭대기 다이브는 그냥 점프보다 멀리 가요", function()
		-- 한 번 점프해서 착지할 때까지의 수평 거리
		local function oneJump(diveAtApex: boolean): number
			local state = DiveLogic.newState()
			local x, y, vy = 0, 0, Config.Character.JumpPower
			local horizontal = 0
			local now = 0
			while true do
				if diveAtApex and vy <= 0 and state.phase == "Ready" and state.lastDiveAt == nil then
					local v = DiveLogic.launch(launchInput({ moveZ = -1, grounded = false, vy = vy }))
					state = DiveLogic.begin(state, now)
					horizontal = math.sqrt(v.vx * v.vx + v.vz * v.vz)
					vy = v.vy
				end
				local speed = if state.phase == "Flying" then horizontal else Config.Character.WalkSpeed
				x += speed * DT
				vy -= GRAVITY * DT
				y += vy * DT
				now += DT
				if y <= 0 then
					return x
				end
			end
		end
		local plain, dived = oneJump(false), oneJump(true)
		t.ok(dived > plain * 1.5, `apex dive {dived} vs plain jump {plain}`)
	end)

	-- 소스 확인: 서버 값·리모트·속성을 건드리지 않음
	t.test("DiveController는 WalkSpeed·JumpPower·PlatformStand에 쓰지 않아요", function()
		local source = fs.readFile("src/client/input/DiveController.luau")
		for _, prop in { "WalkSpeed", "JumpPower", "JumpHeight", "PlatformStand" } do
			t.eq(string.find(source, "%." .. prop .. "%s*=[^=]"), nil, `assigns {prop}`)
		end
	end)

	t.test("다이브는 리모트·속성을 만들지 않아요", function()
		for _, file in
			{ "src/client/input/DiveController.luau", "src/client/input/DiveButton.luau", "src/shared/DiveLogic.luau" }
		do
			local source = fs.readFile(file)
			-- m3-09: 모바일 버튼 ScreenGui의 UI 전용 속성 NoClickSfx(클릭음 끄기, 로컬 UI)는 판정과 무관해서 빼고 봐요
			source = string.gsub(source, "[%w_]+:SetAttribute%(Attributes%.NoClickSfx, true%)", "")
			t.eq(string.find(source, "Remotes"), nil, `{file} uses Remotes`)
			t.eq(string.find(source, "SetAttribute"), nil, `{file} sets attribute`)
			t.eq(string.find(source, "FireServer"), nil, `{file} fires server`)
		end
	end)

	t.test("DiveController: 키·gameProcessed·경직 우선순위가 스펙대로", function()
		local source = fs.readFile("src/client/input/DiveController.luau")
		for _, key in { "LeftShift", "RightShift", "KeyCode.E", "ButtonX" } do
			t.ok(string.find(source, key, 1, true) ~= nil, key)
		end
		t.ok(string.find(source, "if gameProcessed then", 1, true) ~= nil, "gameProcessed")
		t.ok(string.find(source, "Enum.RenderPriority.Input.Value + 2", 1, true) ~= nil, "stun priority")
		t.ok(string.find(source, 'Sfx.play("Dive"', 1, true) ~= nil, "Dive sfx")
		t.ok(string.find(source, 'Sfx.play("DiveLand"', 1, true) ~= nil, "DiveLand sfx")
	end)

	t.test("DiveButton: 터치 기기만, ResetOnSpawn 끔, 글자·간격이 스펙대로", function()
		local source = fs.readFile("src/client/input/DiveButton.luau")
		t.ok(string.find(source, "UserInputService.TouchEnabled", 1, true) ~= nil, "TouchEnabled")
		t.ok(string.find(source, "ResetOnSpawn = false", 1, true) ~= nil, "ResetOnSpawn")
		t.ok(string.find(source, '"DiveGui"', 1, true) ~= nil, "DiveGui")
		t.ok(string.find(source, '"다이브"', 1, true) ~= nil, "label")
		t.ok(string.find(source, "GAP_RATIO = 0.15", 1, true) ~= nil, "gap")
	end)

	t.test("SfxCues에 Dive·DiveLand가 있어요", function()
		local source = fs.readFile("src/shared/SfxCues.luau")
		t.ok(string.find(source, "Dive%s*=") ~= nil or string.find(source, '"Dive"') ~= nil, "Dive")
		t.ok(string.find(source, "DiveLand") ~= nil, "DiveLand")
	end)
end
