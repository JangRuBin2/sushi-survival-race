--!strict
-- Shared.RoomLogic: 방 설정 검증, 이름, 코드, 참가/퇴장/방장 승계, 시작 조건, 빠른 참가 (GDD 3.2)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)
local Config = RobloxRequire.require(Shared.Config)

-- 정해진 값을 차례로 돌려주는 가짜 rng
local function sequenceRng(values: { number })
	local i = 0
	return {
		NextInteger = function(_, min: number, max: number): number
			i += 1
			local value = values[(i - 1) % #values + 1]
			assert(value >= min and value <= max, `rng value {value} out of [{min}, {max}]`)
			return value
		end,
	}
end

local function member(userId: number)
	return { userId = userId, name = `p{userId}` }
end

local function room(id: string, maxPlayers: number, memberCount: number, overrides: { [string]: any }?)
	local r = RoomLogic.newRoom({
		id = id,
		name = `room {id}`,
		maxPlayers = maxPlayers,
		isPrivate = false,
		slot = 1,
	}, member(1))
	for userId = 2, memberCount do
		assert(RoomLogic.addMember(r, member(userId)))
	end
	for k, v in overrides or {} do
		(r :: any)[k] = v
	end
	return r
end

return function(t: Test.Test)
	t.test("validateSettings accepts every max player option", function()
		for _, maxPlayers in Config.Room.MaxPlayerOptions do
			local settings = RoomLogic.validateSettings({ maxPlayers = maxPlayers, isPrivate = false })
			t.eq(settings, { maxPlayers = maxPlayers, isPrivate = false }, `maxPlayers {maxPlayers}`)
		end
	end)

	t.test("validateSettings rejects bad input", function()
		local bad = {
			"nope",
			{ maxPlayers = 5, isPrivate = false },
			{ maxPlayers = "12", isPrivate = false },
			{ maxPlayers = 12 },
			{ maxPlayers = 12, isPrivate = "yes" },
			{ maxPlayers = 12, isPrivate = true, name = 42 },
		}
		for i, raw in bad do
			local settings, err = RoomLogic.validateSettings(raw)
			t.eq(settings, nil, `case {i}`)
			t.ok(type(err) == "string", `case {i} has a reason`)
		end
	end)

	t.test("cleanName trims, collapses whitespace and drops control characters", function()
		t.eq(RoomLogic.cleanName("  계란   초밥\n집 "), "계란 초밥 집")
		t.eq(RoomLogic.cleanName("   "), nil)
		t.eq(RoomLogic.cleanName(""), nil)
		t.eq(RoomLogic.cleanName(nil), nil)
		t.eq(RoomLogic.cleanName("\255\254"), nil, "invalid utf8")
	end)

	t.test("cleanName cuts by characters, not bytes", function()
		local long = string.rep("초", Config.Room.NameMaxLength + 5)
		local name = RoomLogic.cleanName(long) :: string
		t.eq(utf8.len(name), Config.Room.NameMaxLength)
	end)

	t.test("defaultName uses the display name", function()
		t.eq(RoomLogic.defaultName("Rubin"), "Rubin의 초밥집")
	end)

	t.test("isValidCode wants exactly CodeLength digits", function()
		t.ok(RoomLogic.isValidCode("0420"))
		t.ok(not RoomLogic.isValidCode("042"))
		t.ok(not RoomLogic.isValidCode("04200"))
		t.ok(not RoomLogic.isValidCode("04a0"))
		t.ok(not RoomLogic.isValidCode(420))
	end)

	t.test("generateCode zero-pads and skips taken codes", function()
		local taken = { ["0007"] = true }
		local code = RoomLogic.generateCode(sequenceRng({ 7, 7, 42 }), function(c)
			return taken[c] == true
		end)
		t.eq(code, "0042")
	end)

	t.test("generateCode gives up when everything is taken", function()
		local code = RoomLogic.generateCode(sequenceRng({ 1 }), function()
			return true
		end)
		t.eq(code, nil)
	end)

	t.test("nextFreeSlot reuses the lowest free slot", function()
		t.eq(RoomLogic.nextFreeSlot({}), 1)
		t.eq(RoomLogic.nextFreeSlot({ [1] = true, [2] = true }), 3)
		t.eq(RoomLogic.nextFreeSlot({ [1] = true, [3] = true }), 2)
	end)

	t.test("newRoom keeps the code only for private rooms", function()
		local public = RoomLogic.newRoom(
			{ id = "1", name = "a", maxPlayers = 4, isPrivate = false, code = "1234", slot = 1 },
			member(1)
		)
		t.eq(public.code, nil)
		local private = RoomLogic.newRoom(
			{ id = "2", name = "b", maxPlayers = 4, isPrivate = true, code = "1234", slot = 2 },
			member(1)
		)
		t.eq(private.code, "1234")
		t.eq(private.hostUserId, 1)
		t.eq(#private.members, 1)
	end)

	t.test("addMember refuses duplicates, full rooms and rooms in a match", function()
		local r = room("1", 4, 4)
		local ok, err = RoomLogic.addMember(r, member(9))
		t.eq(ok, false)
		t.eq(err, "방이 꽉 찼어요")

		r = room("2", 8, 2)
		ok = RoomLogic.addMember(r, member(2))
		t.eq(ok, false, "duplicate")

		r.state = "InMatch"
		ok, err = RoomLogic.addMember(r, member(9))
		t.eq(ok, false)
		t.eq(err, "이미 게임 중인 방이에요")
	end)

	t.test("host leaves -> earliest joined member becomes host", function()
		local r = room("1", 8, 4)
		t.ok(RoomLogic.removeMember(r, 1))
		t.eq(r.hostUserId, 2)
		t.ok(RoomLogic.removeMember(r, 3))
		t.eq(r.hostUserId, 2, "non-host leaving keeps host")
		t.ok(not RoomLogic.removeMember(r, 99))
	end)

	t.test("canStart needs host, waiting state and enough players", function()
		local r = room("1", 8, 3)
		t.eq(RoomLogic.canStart(r, 2, 4), false, "not host")
		local ok, err = RoomLogic.canStart(r, 1, 4)
		t.eq(ok, false)
		t.eq(err, "최소 4명이 모여야 시작할 수 있어요")
		t.eq(RoomLogic.canStart(r, 1, 3), true)
		r.state = "InMatch"
		t.eq(RoomLogic.canStart(r, 1, 3), false, "already in match")
	end)

	t.test("minPlayersToStart uses the debug value only in studio", function()
		t.eq(RoomLogic.minPlayersToStart(false), Config.Room.MinPlayersToStart)
		t.eq(RoomLogic.minPlayersToStart(true), Config.DEBUG.minPlayersToStart)
	end)

	t.test("shouldAutoStart only for full waiting rooms", function()
		t.ok(RoomLogic.shouldAutoStart(room("1", 4, 4)))
		t.ok(not RoomLogic.shouldAutoStart(room("2", 4, 3)))
		t.ok(not RoomLogic.shouldAutoStart(room("3", 4, 4, { state = "InMatch" })))
	end)

	t.test("pickQuickJoin skips private, full and running rooms", function()
		local rooms = {
			room("1", 4, 4),
			room("2", 8, 7, { isPrivate = true }),
			room("3", 8, 7, { state = "InMatch" }),
		}
		t.eq(RoomLogic.pickQuickJoin(rooms), nil)
	end)

	t.test("pickQuickJoin prefers countdown, then more members, then older room", function()
		local a = room("1", 12, 3)
		local b = room("2", 12, 5)
		local c = room("10", 12, 5)
		t.eq(RoomLogic.pickQuickJoin({ c, a, b }), b, "most members, lowest id")
		local d = room("3", 12, 1, { autoStartAt = 100 })
		local e = room("4", 12, 1, { autoStartAt = 50 })
		t.eq(RoomLogic.pickQuickJoin({ a, b, c, d, e }), e, "earliest countdown")
	end)

	t.test("listPublic hides private rooms and puts waiting rooms first", function()
		local rooms = {
			room("1", 8, 6, { state = "InMatch" }),
			room("2", 8, 2),
			room("3", 8, 2, { isPrivate = true, code = "1111" }),
			room("4", 8, 5),
		}
		local ids = {}
		for i, listing in RoomLogic.listPublic(rooms) do
			ids[i] = listing.id
		end
		t.eq(ids, { "4", "2", "1" })
	end)

	t.test("snapshot copies members", function()
		local r = room("1", 8, 2)
		local snap = RoomLogic.snapshot(r)
		t.eq(#snap.members, 2)
		table.insert(r.members, member(3))
		t.eq(#snap.members, 2, "snapshot is not affected by later changes")
	end)
end
