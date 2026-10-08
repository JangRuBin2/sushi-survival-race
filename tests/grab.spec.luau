--!strict
-- m3-07 잡기: GrabLogic (대상 고르기, 끝내기 판정, 쿨다운·면역 기록)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local GrabLogic = RobloxRequire.require(Shared.GrabLogic)
local Config = RobloxRequire.require(Shared.Config)

local cfg = Config.Grab

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

-- 원점에서 -Z(앞)를 보는 잡는 사람
local GRABBER = { userId = 1, position = v(0, 3, 0), look = v(0, 0, -1) }

local function candidate(userId: number, x: number, z: number, extra: { [string]: any }?)
	local c: { [string]: any } = { userId = userId, position = v(x, 3, z), alive = true, down = false }
	if extra then
		for k, value in extra do
			c[k] = value
		end
	end
	return c :: any
end

local function endState(overrides: { [string]: any }?)
	local s: { [string]: any } = {
		holding = true,
		elapsed = 0.5,
		distance = 3,
		grabberRacing = true,
		targetRacing = true,
		grabberDown = false,
		targetDown = false,
	}
	if overrides then
		for k, value in overrides do
			s[k] = value
		end
	end
	return s :: any
end

return function(t: Test.Test)
	t.test("AC1: 앞 3 studs는 잡히고 뒤·옆·먼 앞은 안 잡혀요", function()
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -3) }, cfg), 2, "front 3")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, 3) }, cfg), nil, "behind")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 3, 0) }, cfg), nil, "side")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -6) }, cfg), nil, "too far")
	end)

	t.test("AC1: 앞에 둘이면 가까운 사람", function()
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(3, 0, -4), candidate(2, 0, -2) }, cfg), 2)
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -2), candidate(3, 0, -4) }, cfg), 2)
	end)

	t.test("AC1: 경계 — 거리 5는 잡히고, 내적 0.5 경계 안쪽은 잡혀요", function()
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -5) }, cfg), 2, "range 5")
		-- 앞에서 45도 (내적 약 0.707)
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 2, -2) }, cfg), 2, "45 deg")
		-- 앞에서 70도 (내적 약 0.34)
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 2.82, -1.03) }, cfg), nil, "70 deg")
	end)

	t.test("AC1: 바라보는 방향의 높낮이는 무시하고, 바로 위 사람은 안 잡혀요", function()
		local tilted = { userId = 1, position = v(0, 3, 0), look = v(0, -0.9, -0.1) }
		t.eq(GrabLogic.pickTarget(tilted, { candidate(2, 0, -3) }, cfg), 2, "tilted look")
		local above = { userId = 2, position = v(0, 7, 0), alive = true, down = false }
		t.eq(GrabLogic.pickTarget(GRABBER, { above :: any }, cfg), nil, "directly above")
		local noLook = { userId = 1, position = v(0, 3, 0), look = v(0, 1, 0) }
		t.eq(GrabLogic.pickTarget(noLook, { candidate(2, 0, -3) }, cfg), nil, "no horizontal look")
	end)

	t.test("AC2: 잡힌·면역·넘어진·죽은 후보와 자기 자신은 안 골라요", function()
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -3, { grabbed = true }) }, cfg), nil, "grabbed")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -3, { immune = true }) }, cfg), nil, "immune")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -3, { down = true }) }, cfg), nil, "down")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(2, 0, -3, { alive = false }) }, cfg), nil, "dead")
		t.eq(GrabLogic.pickTarget(GRABBER, { candidate(1, 0, -3) }, cfg), nil, "self")
		t.eq(GrabLogic.pickTarget(GRABBER, {}, cfg), nil, "empty")
	end)

	t.test("AC2: 못 잡는 가까운 후보를 건너뛰고 다음 사람을 골라요", function()
		local list = { candidate(2, 0, -2, { down = true }), candidate(3, 0, -4) }
		t.eq(GrabLogic.pickTarget(GRABBER, list, cfg), 3)
	end)

	t.test("AC3: 잡던 사람 쿨다운 1.5초, 잡혔던 사람 면역 1초", function()
		local book = GrabLogic.newBook()
		t.ok(GrabLogic.begin(book, 1, 2, 9), "begin")
		local ended = GrabLogic.finish(book, 1, 10, cfg)
		t.ok(ended ~= nil and ended.target == 2, "finish returns grab")
		t.eq(GrabLogic.canStart(book, 1, 11.49), false, "cooldown 11.49")
		t.eq(GrabLogic.canStart(book, 1, 11.5), true, "cooldown 11.5")
		t.eq(GrabLogic.isImmune(book, 2, 10.99), true, "immune 10.99")
		t.eq(GrabLogic.isImmune(book, 2, 11), false, "immune 11")
		t.eq(GrabLogic.begin(book, 3, 2, 10.99), false, "cannot grab immune")
		t.ok(GrabLogic.begin(book, 3, 2, 11), "can grab again at 11")
	end)

	t.test("AC3: 잡히기만 한 사람은 쿨다운이 없어요", function()
		local book = GrabLogic.newBook()
		GrabLogic.begin(book, 1, 2, 0)
		GrabLogic.finish(book, 1, 1, cfg)
		t.eq(GrabLogic.canStart(book, 2, 1), true)
	end)

	t.test(
		"AC4: shouldEnd — 놓음·2초·거리 9.1·레이서 아님·넘어짐은 끝, 1.9초·8.9는 계속",
		function()
			t.eq(GrabLogic.shouldEnd(endState(), cfg), false, "baseline")
			t.eq(GrabLogic.shouldEnd(endState({ holding = false }), cfg), true, "released")
			t.eq(GrabLogic.shouldEnd(endState({ elapsed = 2 }), cfg), true, "2s")
			t.eq(GrabLogic.shouldEnd(endState({ elapsed = 1.9 }), cfg), false, "1.9s")
			t.eq(GrabLogic.shouldEnd(endState({ distance = 9.1 }), cfg), true, "9.1")
			t.eq(GrabLogic.shouldEnd(endState({ distance = 8.9 }), cfg), false, "8.9")
			t.eq(GrabLogic.shouldEnd(endState({ grabberRacing = false }), cfg), true, "grabber not racing")
			t.eq(GrabLogic.shouldEnd(endState({ targetRacing = false }), cfg), true, "target not racing")
			t.eq(GrabLogic.shouldEnd(endState({ grabberDown = true }), cfg), true, "grabber down")
			t.eq(GrabLogic.shouldEnd(endState({ targetDown = true }), cfg), true, "target down")
		end
	)

	t.test("AC5: 한 사람은 동시에 두 사람에게 잡히지 않아요 (먼저 시작한 잡기만)", function()
		local book = GrabLogic.newBook()
		t.ok(GrabLogic.begin(book, 1, 3, 0), "first")
		t.eq(GrabLogic.begin(book, 2, 3, 0), false, "second on same target")
		t.eq(GrabLogic.grabberOf(book, 3), 1)
		t.eq(GrabLogic.isGrabbed(book, 3), true)
		t.eq(GrabLogic.grabOf(book, 2), nil)
	end)

	t.test("AC5: 잡혀 있는 사람·잡고 있는 사람은 잡기를 시작할 수 없어요", function()
		local book = GrabLogic.newBook()
		GrabLogic.begin(book, 1, 2, 0)
		t.eq(GrabLogic.canStart(book, 2, 0), false, "grabbed cannot start")
		t.eq(GrabLogic.begin(book, 2, 3, 0), false, "grabbed begin fails")
		t.eq(GrabLogic.canStart(book, 1, 0), false, "already grabbing")
		t.eq(GrabLogic.begin(book, 1, 3, 0), false, "already grabbing begin fails")
		t.eq(GrabLogic.begin(book, 4, 4, 0), false, "self")
	end)

	t.test("나간 플레이어의 잡기·기록을 지워요", function()
		local book = GrabLogic.newBook()
		GrabLogic.begin(book, 1, 2, 0)
		GrabLogic.begin(book, 3, 1, 0)
		local ended = GrabLogic.removePlayer(book, 1, 1, cfg)
		t.eq(#ended, 2, "both grabs ended")
		t.eq(GrabLogic.grabOf(book, 1), nil)
		t.eq(GrabLogic.grabOf(book, 3), nil)
		t.eq(GrabLogic.isGrabbed(book, 2), false)
		t.eq(GrabLogic.isGrabbed(book, 1), false)
		t.eq(book.cooldownUntil[1], nil, "leaver cooldown cleared")
		t.eq(book.immuneUntil[1], nil, "leaver immunity cleared")
		t.eq(GrabLogic.canStart(book, 3, 1), false, "other grabber cooled down")
		t.eq(GrabLogic.removePlayer(book, 99, 1, cfg), {}, "unknown player")
	end)

	t.test("finish는 잡지 않은 사람이면 nil", function()
		t.eq(GrabLogic.finish(GrabLogic.newBook(), 1, 0, cfg), nil)
	end)
end
