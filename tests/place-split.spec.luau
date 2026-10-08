--!strict
-- m4-11 로비/매치 플레이스 분리: PlacePayload(매니페스트·티켓 검증, 도착 대기, 복귀 방장),
-- RoomDirectoryLogic(서버 간 방 목록 합치기·빠른 참가), PlaceRole, 한 플레이스 모드 유지 (docs/specs/m4-11-place-split.md)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local PlacePayload = RobloxRequire.require(Shared.PlacePayload)
local PlaceRole = RobloxRequire.require(Shared.PlaceRole)
local RoomDirectoryLogic = RobloxRequire.require(Shared.RoomDirectoryLogic)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)

local function stripComments(source: string): string
	local s = string.gsub(source, "%-%-%[%[.-%]%]", "")
	s = string.gsub(s, "%-%-[^\n]*", "")
	return s
end

local function source(path: string): string
	return stripComments(fs.readFile(path))
end

local function settings(overrides: { [string]: any }?): { [string]: any }
	local s: { [string]: any } = { maxPlayers = 8, isPrivate = false, name = "초밥집" }
	for k, v in overrides or {} do
		s[k] = v
	end
	return s
end

local function manifest(overrides: { [string]: any }?): { [string]: any }
	local m: { [string]: any } = PlacePayload.manifest({
		roomKey = "8C2D1E0A-1111-2222-3333-444455556666",
		settings = settings() :: any,
		hostUserId = 101,
		memberUserIds = { 101, 102, 103, 104 },
		lobbyJobId = "job-lobby-1",
		createdAt = 1700000000,
	})
	for k, v in overrides or {} do
		m[k] = v
	end
	return m
end

local function ticket(overrides: { [string]: any }?): { [string]: any }
	local tk: { [string]: any } =
		PlacePayload.returnTicket("room-key-1", settings() :: any, 101, { 101, 102, 103, 104 })
	for k, v in overrides or {} do
		tk[k] = v
	end
	return tk
end

local function without(tbl: { [string]: any }, key: string): { [string]: any }
	local copy = table.clone(tbl)
	copy[key] = nil
	return copy
end

local function range(n: number, start: number?): { number }
	local list = {}
	for i = 1, n do
		table.insert(list, (start or 100) + i)
	end
	return list
end

local function entry(jobId: string, roomId: string, overrides: { [string]: any }?): { [string]: any }
	local e: { [string]: any } = {
		jobId = jobId,
		roomId = roomId,
		name = `{jobId}-{roomId}`,
		maxPlayers = 8,
		memberCount = 2,
		state = "Waiting",
		updatedAt = 1000,
	}
	for k, v in overrides or {} do
		e[k] = v
	end
	return e
end

local function localRoom(id: string, members: number, overrides: { [string]: any }?): any
	local room = RoomLogic.newRoom({
		id = id,
		name = `room {id}`,
		maxPlayers = 8,
		isPrivate = false,
		code = nil,
		slot = tonumber(id) or 1,
		key = `key-{id}`,
	}, { userId = 1, name = "a" })
	for i = 2, members do
		table.insert(room.members, { userId = i, name = `p{i}` })
	end
	for k, v in overrides or {} do
		room[k] = v
	end
	return room
end

return function(t: Test.Test)
	------------------------------------------------------------------ AC1 PlacePayload
	t.test("AC1: 매니페스트를 만들고 검증하면 통과해요", function()
		local m, err = PlacePayload.validateManifest(manifest())
		t.ok(m ~= nil, err)
		t.eq(m.roomKey, "8C2D1E0A-1111-2222-3333-444455556666")
		t.eq(m.settings, { maxPlayers = 8, isPrivate = false, name = "초밥집" })
		t.eq(m.memberUserIds, { 101, 102, 103, 104 })
		t.eq(m.hostUserId, 101)
		t.eq(m.lobbyJobId, "job-lobby-1")
		t.eq(m.v, 1)
	end)

	t.test("AC1: 매니페스트 — 멤버 25명·이름 200자·숫자 아닌 userId·v 누락은 거부", function()
		t.eq(
			PlacePayload.validateManifest(
				manifest({ memberUserIds = range(25), settings = settings({ maxPlayers = 24 }) })
			),
			nil,
			"25 members"
		)
		t.eq(PlacePayload.validateManifest(manifest({ settings = settings({ name = string.rep("가", 200) }) })), nil)
		t.eq(PlacePayload.validateManifest(manifest({ memberUserIds = { 101, "102" } })), nil, "string userId")
		t.eq(PlacePayload.validateManifest(manifest({ memberUserIds = { 101, 1.5 } })), nil, "fraction userId")
		t.eq(PlacePayload.validateManifest(manifest({ memberUserIds = { 101, -3 } })), nil, "negative userId")
		t.eq(PlacePayload.validateManifest(without(manifest(), "v")), nil, "missing v")
		t.eq(PlacePayload.validateManifest(manifest({ v = 2 })), nil, "future v")
		t.eq(PlacePayload.validateManifest("nope"), nil)
		t.eq(PlacePayload.validateManifest(nil), nil)
	end)

	t.test("AC1: 매니페스트 — 설정·키·방장·중복 멤버·정원 초과도 거부", function()
		t.eq(PlacePayload.validateManifest(manifest({ settings = settings({ maxPlayers = 7 }) })), nil, "maxPlayers")
		t.eq(PlacePayload.validateManifest(manifest({ settings = settings({ isPrivate = "no" }) })), nil)
		t.eq(PlacePayload.validateManifest(manifest({ settings = settings({ name = " 앞 공백" }) })), nil)
		t.eq(PlacePayload.validateManifest(manifest({ roomKey = "" })), nil, "empty key")
		t.eq(PlacePayload.validateManifest(manifest({ roomKey = string.rep("a", 65) })), nil, "long key")
		t.eq(PlacePayload.validateManifest(manifest({ roomKey = "a b" })), nil, "space in key")
		t.eq(PlacePayload.validateManifest(manifest({ hostUserId = "101" })), nil)
		t.eq(PlacePayload.validateManifest(manifest({ memberUserIds = { 101, 101 } })), nil, "duplicate")
		t.eq(PlacePayload.validateManifest(manifest({ memberUserIds = {} })), nil, "empty")
		t.eq(
			PlacePayload.validateManifest(
				manifest({ memberUserIds = range(5), settings = settings({ maxPlayers = 4 }) })
			),
			nil,
			"more members than maxPlayers"
		)
		t.eq(PlacePayload.validateManifest(manifest({ lobbyJobId = 5 })), nil)
		t.eq(PlacePayload.validateManifest(manifest({ createdAt = "now" })), nil)
	end)

	t.test("AC1: 매니페스트 — 24명은 통과, 정리된 이름(24자)은 통과", function()
		local big = manifest({ memberUserIds = range(24) })
		big.settings = settings({ maxPlayers = 24, name = string.rep("가", 24) })
		local m = PlacePayload.validateManifest(big)
		t.ok(m ~= nil)
		t.eq(#m.memberUserIds, 24)
		t.eq(
			PlacePayload.validateManifest(manifest({ settings = settings({ name = string.rep("가", 25) }) })),
			nil,
			"25 chars"
		)
	end)

	t.test("AC1: 복귀 티켓을 만들고 검증하면 통과해요 (본인이 멤버)", function()
		local tk, err = PlacePayload.validateReturnTicket(ticket(), 103)
		t.ok(tk ~= nil, err)
		t.eq(tk.kind, "return")
		t.eq(tk.roomKey, "room-key-1")
		t.eq(tk.hostUserId, 101)
		t.eq(tk.memberUserIds, { 101, 102, 103, 104 })
		t.eq(tk.settings.name, "초밥집")
	end)

	t.test("AC1: 복귀 티켓 — 본인 userId가 멤버에 없으면 거부", function()
		local tk, err = PlacePayload.validateReturnTicket(ticket(), 999)
		t.eq(tk, nil)
		t.eq(err, "not a member")
	end)

	t.test("AC1: 복귀 티켓 — 25명·200자·숫자 아닌 userId·v 누락·종류 다름은 거부", function()
		t.eq(
			PlacePayload.validateReturnTicket(
				ticket({ memberUserIds = range(25), settings = settings({ maxPlayers = 24 }) }),
				101
			),
			nil
		)
		t.eq(
			PlacePayload.validateReturnTicket(ticket({ settings = settings({ name = string.rep("x", 200) }) }), 101),
			nil
		)
		t.eq(PlacePayload.validateReturnTicket(ticket({ memberUserIds = { 101, {} } }), 101), nil)
		t.eq(PlacePayload.validateReturnTicket(without(ticket(), "v"), 101), nil)
		t.eq(PlacePayload.validateReturnTicket(ticket({ kind = "join" }), 101), nil)
		t.eq(PlacePayload.validateReturnTicket(ticket({ hostUserId = 0 }), 101), nil)
		t.eq(PlacePayload.validateReturnTicket(ticket({ memberUserIds = { [1] = 101, extra = 5 } }), 101), nil)
		t.eq(PlacePayload.validateReturnTicket(42, 101), nil)
	end)

	t.test("참가 티켓: 방 id 또는 코드 중 하나만, 코드는 숫자 4자리", function()
		local byId = PlacePayload.validateJoinTicket(PlacePayload.joinTicket("12", nil))
		t.ok(byId ~= nil and byId.roomId == "12" and byId.code == nil)
		local byCode = PlacePayload.validateJoinTicket(PlacePayload.joinTicket(nil, "0042"))
		t.ok(byCode ~= nil and byCode.code == "0042")
		t.eq(PlacePayload.validateJoinTicket(PlacePayload.joinTicket(nil, nil)), nil, "neither")
		t.eq(PlacePayload.validateJoinTicket({ v = 1, kind = "join", roomId = "1", code = "0042" }), nil, "both")
		t.eq(PlacePayload.validateJoinTicket(PlacePayload.joinTicket(nil, "42")), nil, "short code")
		t.eq(PlacePayload.validateJoinTicket(PlacePayload.joinTicket(string.rep("1", 17), nil)), nil, "long id")
		t.eq(PlacePayload.validateJoinTicket({ kind = "join", roomId = "1" }), nil, "missing v")
	end)

	t.test("매치 힌트·결과: 만들고 검증, 우승자 없는 결과도 통과", function()
		local hint = PlacePayload.validateMatchHint(PlacePayload.matchHint("abc-1"))
		t.ok(hint ~= nil and hint.roomKey == "abc-1")
		t.eq(PlacePayload.validateMatchHint({ v = 1, kind = "match" }), nil)

		local m = manifest()
		local withWinner = PlacePayload.validateMatchResult(
			PlacePayload.matchResult(m :: any, { userId = 102, name = "참치", appearanceId = "tamago" })
		)
		t.ok(withWinner ~= nil)
		t.eq(withWinner.winnerUserId, 102)
		t.eq(withWinner.winnerName, "참치")
		t.eq(withWinner.memberUserIds, { 101, 102, 103, 104 })
		local noWinner = PlacePayload.validateMatchResult(PlacePayload.matchResult(m :: any, nil))
		t.ok(noWinner ~= nil and noWinner.winnerUserId == nil)
		local bad =
			PlacePayload.matchResult(m :: any, { userId = 102, name = "참치", appearanceId = "tamago" }) :: any
		bad.winnerName = nil
		t.eq(PlacePayload.validateMatchResult(bad), nil, "winner without name")
	end)

	t.test("kindOf: 텔레포트 데이터 종류 힌트", function()
		t.eq(PlacePayload.kindOf(ticket()), "return")
		t.eq(PlacePayload.kindOf(PlacePayload.joinTicket("1", nil)), "join")
		t.eq(PlacePayload.kindOf(PlacePayload.matchHint("k")), "match")
		t.eq(PlacePayload.kindOf({ kind = "other" }), nil)
		t.eq(PlacePayload.kindOf(nil), nil)
		t.eq(PlacePayload.kindOf("return"), nil)
	end)

	------------------------------------------------------------------ AC2 도착 대기
	t.test("AC2: arrivalReady", function()
		t.eq(PlacePayload.arrivalReady(4, 4, 1, 20), "start", "all arrived")
		t.eq(PlacePayload.arrivalReady(4, 2, 5, 20), "wait", "some arrived, time left")
		t.eq(PlacePayload.arrivalReady(4, 0, 5, 20), "wait", "none yet, time left")
		t.eq(PlacePayload.arrivalReady(4, 2, 20, 20), "start", "timeout with 2")
		t.eq(PlacePayload.arrivalReady(4, 3, 25, 20), "start", "timeout with 3")
		t.eq(PlacePayload.arrivalReady(4, 1, 20, 20), "abort", "timeout with 1")
		t.eq(PlacePayload.arrivalReady(4, 0, 30, 20), "abort", "timeout with 0")
	end)

	t.test("AC2: arrivalReady — 최소 인원 (Studio 흉내 1명)", function()
		t.eq(PlacePayload.arrivalReady(1, 1, 0, 20), "abort", "all arrived but under 2")
		t.eq(PlacePayload.arrivalReady(1, 1, 0, 20, 1), "start", "simulate min 1")
		t.eq(PlacePayload.arrivalReady(3, 1, 20, 20, 1), "start")
	end)

	------------------------------------------------------------------ AC3 방 목록
	t.test("AC3: merge — 이 서버 방 먼저, 다른 서버 방은 remote = true와 키 id", function()
		local localListings = RoomLogic.listPublic({ localRoom("1", 3), localRoom("2", 1) })
		local merged = RoomDirectoryLogic.merge(localListings, { entry("jobB", "5") :: any }, "jobA", 1000, 30)
		t.eq(#merged, 3)
		t.eq(merged[1].id, "1")
		t.eq(merged[1].remote, nil)
		t.eq(merged[2].id, "2")
		t.eq(merged[3].id, "jobB:5")
		t.eq(merged[3].remote, true)
		t.eq(merged[3].memberCount, 2)
	end)

	t.test(
		"AC3: merge — 만료·이 서버·깨진 원격 항목을 빼고, 같은 키는 하나만(최신)",
		function()
			local remote = {
				entry("jobB", "1", { updatedAt = 1000 }),
				entry("jobB", "1", { updatedAt = 990, memberCount = 7 }), -- 같은 키, 오래됨
				entry("jobC", "2", { updatedAt = 960 }), -- 40초 전: 만료 (ttl 30)
				entry("jobA", "3"), -- 이 서버
				entry("jobD", "4", { state = "Broken" }), -- 깨짐
				entry("jobE", "5", { updatedAt = 970 }), -- 딱 30초: 아직 유효
			}
			local merged = RoomDirectoryLogic.merge({}, remote :: any, "jobA", 1000, 30)
			local ids = {}
			for _, listing in merged do
				table.insert(ids, listing.id)
			end
			t.eq(ids, { "jobB:1", "jobE:5" })
			t.eq(merged[1].memberCount, 2, "keeps the newest duplicate")
		end
	)

	t.test("AC3: merge — 최대 50개, 이 서버 방이 자리를 먼저 가져요", function()
		local locals = {}
		for i = 1, 30 do
			table.insert(locals, { id = tostring(i), name = "l", maxPlayers = 8, memberCount = 1, state = "Waiting" })
		end
		local remote = {}
		for i = 1, 40 do
			table.insert(remote, entry("jobZ", tostring(i)))
		end
		local merged = RoomDirectoryLogic.merge(locals :: any, remote :: any, "jobA", 1000, 30)
		t.eq(#merged, 50)
		t.eq(merged[30].id, "30")
		t.eq(merged[31].remote, true)
		t.eq(RoomDirectoryLogic.MAX_LISTINGS, 50)
	end)

	t.test("AC3: merge — 원격은 대기 중 → 사람 많은 순", function()
		local remote = {
			entry("jobB", "1", { memberCount = 1 }),
			entry("jobC", "1", { memberCount = 5 }),
			entry("jobD", "1", { state = "InMatch", memberCount = 8 }),
		}
		local merged = RoomDirectoryLogic.merge({}, remote :: any, "jobA", 1000, 30)
		t.eq(merged[1].id, "jobC:1")
		t.eq(merged[2].id, "jobB:1")
		t.eq(merged[3].id, "jobD:1")
	end)

	t.test("AC3: 빠른 참가 — 이 서버 → 원격 → 없음", function()
		local remote = { entry("jobB", "9", { memberCount = 3 }) }
		local pick = RoomDirectoryLogic.pickQuickJoin({ localRoom("1", 2) }, remote :: any, "jobA", 1000, 30)
		t.ok(pick ~= nil and pick.kind == "local" and pick.room.id == "1", "local first")

		local full = localRoom("2", 8)
		pick = RoomDirectoryLogic.pickQuickJoin({ full }, remote :: any, "jobA", 1000, 30)
		t.ok(pick ~= nil and pick.kind == "remote" and pick.entry.roomId == "9", "then remote")

		local notJoinable = {
			entry("jobB", "1", { memberCount = 8 }), -- 꽉 참
			entry("jobC", "1", { state = "InMatch" }),
			entry("jobD", "1", { updatedAt = 900 }), -- 만료
			entry("jobA", "1"), -- 이 서버
		}
		pick = RoomDirectoryLogic.pickQuickJoin({ full }, notJoinable :: any, "jobA", 1000, 30)
		t.eq(pick, nil, "none → new room")
		t.eq(RoomDirectoryLogic.pickQuickJoin({}, {}, "jobA", 1000, 30), nil)
	end)

	t.test('방 목록 키: 다른 서버 id는 "<JobId>:<roomId>", 이 서버 id(숫자)는 아님', function()
		t.eq(RoomDirectoryLogic.key("abc-123", "7"), "abc-123:7")
		local jobId, roomId = RoomDirectoryLogic.parseKey("abc-123:7")
		t.eq(jobId, "abc-123")
		t.eq(roomId, "7")
		t.eq(RoomDirectoryLogic.isRemoteId("7"), false)
		t.eq(RoomDirectoryLogic.isRemoteId("abc:"), false)
		t.eq(RoomDirectoryLogic.isRemoteId(":7"), false)
		t.eq(RoomDirectoryLogic.isRemoteId(7), false)
		t.eq(RoomDirectoryLogic.isRemoteId(string.rep("a", 200) .. ":1"), false, "too long")
	end)

	t.test("올릴 항목: 공개·대기 중 방만", function()
		local room = localRoom("3", 2)
		local e = RoomDirectoryLogic.entryFor(room, "jobA", 1234)
		t.eq(e, {
			jobId = "jobA",
			roomId = "3",
			name = "room 3",
			maxPlayers = 8,
			memberCount = 2,
			state = "Waiting",
			updatedAt = 1234,
		})
		t.eq(RoomDirectoryLogic.entryFor(localRoom("4", 2, { isPrivate = true, code = "1234" }), "jobA", 1), nil)
		t.eq(RoomDirectoryLogic.entryFor(localRoom("5", 2, { state = "InMatch" }), "jobA", 1), nil)
	end)

	t.test("코드 항목 읽기·만료", function()
		t.eq(
			RoomDirectoryLogic.readCodeEntry({ jobId = "j", roomId = "1", updatedAt = 5 }),
			{ jobId = "j", roomId = "1", updatedAt = 5 }
		)
		t.eq(RoomDirectoryLogic.readCodeEntry({ jobId = "j", roomId = 1, updatedAt = 5 }), nil)
		t.eq(RoomDirectoryLogic.isFresh(970, 1000, 30), true)
		t.eq(RoomDirectoryLogic.isFresh(969, 1000, 30), false)
	end)

	------------------------------------------------------------------ AC4 복귀 방장
	t.test(
		"AC4: 복귀 방장 — 원래 방장이 왔으면 그 사람, 아니면 가장 먼저 온 사람",
		function()
			t.eq(PlacePayload.pickRestoreHost(101, { 103, 101, 102 }), 101)
			t.eq(PlacePayload.pickRestoreHost(101, { 103, 102 }), 103)
			t.eq(PlacePayload.pickRestoreHost(101, {}), nil)
		end
	)

	t.test(
		"늦게 온 멤버(매치 서버 관전자): 방이 출발한 뒤에도 넣고, 중복·정원 초과는 막아요",
		function()
			local room = localRoom("1", 3, { state = "InMatch" })
			t.eq(RoomLogic.canJoin(room, 50), false, "normal join blocked in match")
			t.eq(RoomLogic.addLateMember(room, { userId = 50, name = "late" }), true)
			t.eq(#room.members, 4)
			t.eq(RoomLogic.addLateMember(room, { userId = 50, name = "late" }), false, "already member")
			local full = localRoom("2", 8, { state = "InMatch" })
			t.eq(RoomLogic.addLateMember(full, { userId = 60, name = "x" }), false, "full")
		end
	)

	------------------------------------------------------------------ QA 후 수정 (docs/qa/m4-11-place-split.md)
	t.test(
		"R1 재현: MatchResult 없는(확인 안 된) 위조 티켓은 살아 있는 같은 키 방에 못 들어가고 새 방만",
		function()
			-- 2분 뒤 옛 멤버 B가 roomKey K 티켓을 위조해 옴: 같은 키 방이 있어도 create (새 키)
			t.eq(PlacePayload.returnAction(false, false, true), "create")
			t.eq(PlacePayload.returnAction(false, false, false), "create")
			-- 확인된 복귀(MatchResult 멤버)만 같은 키 방에 합쳐요
			t.eq(PlacePayload.returnAction(true, false, true), "joinKey")
			t.eq(PlacePayload.returnAction(true, false, false), "create")
			-- 이번 복귀가 만든 방이 있으면 거기로 (확인 여부와 무관, 방장 변경은 확인된 것만 — 아래 정적)
			t.eq(PlacePayload.returnAction(false, true, true), "joinOwn")
			t.eq(PlacePayload.returnAction(true, true, true), "joinOwn")
		end
	)

	t.test("R1 정적: 확인 안 된 복귀는 방장을 못 바꾸고, 새 방은 새 키", function()
		local room = source("src/server/RoomService.luau")
		local join = string.match(room, "function RoomService%.joinRestored%(.-\nend\n") :: string
		t.ok(join ~= nil, "joinRestored")
		t.ok(string.find(join, "if ok and verified then", 1, true) ~= nil, "host change only when verified")
		local place = source("src/server/PlaceService.luau")
		local handle = string.match(place, "local function handleReturn.-\nend\n") :: string
		t.ok(string.find(handle, "PlacePayload.returnAction(r.verified", 1, true) ~= nil)
		t.ok(
			string.find(handle, "RoomService.joinRestored(player, target.id, r.hostUserId, r.verified)", 1, true) ~= nil
		)
		t.ok(
			string.find(handle, "key = if r.verified and keyRoom == nil then key else nil", 1, true) ~= nil,
			"fresh key"
		)
		-- verified는 MatchResult를 읽었을 때만 켜져요
		local load = string.match(place, "local function loadResult.-\nend\n") :: string
		t.ok(string.find(load, "restore.verified = true", 1, true) ~= nil)
		local _, count = string.gsub(place, "verified = true", "")
		t.eq(count, 1, "only loadResult sets verified")
	end)

	t.test("R2 정적: 다른 서버로 이동 중이면 방 요청을 거부해요 (저장 중 포함)", function()
		local room = source("src/server/RoomService.luau")
		local blocked = string.match(room, "local function requireNoRoom.-\nend") :: string
		t.ok(string.find(blocked, "hooks.isTeleporting", 1, true) ~= nil)
		local place = source("src/server/PlaceService.luau")
		local fn = string.match(place, "local function teleportToLobbyServer.-\nend\n") :: string
		local markAt = string.find(fn, "joiningAt[player] = mark", 1, true) :: number
		local saveAt = string.find(fn, "saveBeforeTeleport", 1, true) :: number
		t.ok(markAt ~= nil and saveAt ~= nil and markAt < saveAt, "marked before saving")
		t.ok(string.find(place, "return joiningAt[player] ~= nil or pending[player] ~= nil", 1, true) ~= nil)
	end)

	t.test("R3 정적: 크래시 경로도 Won 받은 우승자를 finish(MatchResult·단상)로 넘겨요", function()
		local match = source("src/server/MatchService.luau")
		t.ok(string.find(match, "finish(room.id, winner)", 1, true) ~= nil)
		t.eq(string.find(match, "finish(room.id, nil)", 1, true), nil)
		t.ok(string.find(match, "pcall(fireWinnerShowcase, ctx, winnerUserId)", 1, true) ~= nil)
	end)

	------------------------------------------------------------------ AC5 한 플레이스 모드
	t.test("AC5: PlaceRole — Studio·id 없음은 Single, 흉내 모드는 Studio에서만 Match", function()
		local empty = { LobbyPlaceId = nil, MatchPlaceId = nil }
		local both = { LobbyPlaceId = 10, MatchPlaceId = 20 }
		t.eq(PlaceRole.resolve(10, empty, true), "Single")
		t.eq(PlaceRole.resolve(10, empty, false), "Single")
		t.eq(PlaceRole.resolve(20, both, true), "Single", "Studio with ids")
		t.eq(PlaceRole.resolve(20, both, false), "Match")
		t.eq(PlaceRole.resolve(10, both, false), "Lobby")
		t.eq(PlaceRole.resolve(10, empty, true, true), "Match", "simulate in Studio")
		t.eq(PlaceRole.resolve(10, empty, false, true), "Single", "simulate ignored outside Studio")
		t.eq(PlaceRole.resolve(10, both, false, true), "Lobby", "simulate ignored outside Studio")
		t.eq(PlaceRole.resolve(10, empty, true, false), "Single")
	end)

	t.test("AC5: 기본 설정 — 플레이스 id 없음, 흉내 모드 꺼짐, Teleport 값", function()
		t.eq(Config.Places.LobbyPlaceId, nil)
		t.eq(Config.Places.MatchPlaceId, nil)
		t.eq(Config.DEBUG.simulateMatchServer, false)
		t.eq(Config.DEBUG.forceMapPlan, nil)
		t.eq(Config.Teleport.ArrivalTimeout, 20)
		t.eq(Config.Teleport.RestoreWindow, 30)
		t.eq(Config.Teleport.DirectoryRefresh, 5)
		t.eq(Config.Teleport.DirectoryTtl, 30)
		t.eq(Config.Teleport.ManifestTtl, 600)
		t.eq(Config.Teleport.ResultTtl, 120)
		t.ok(Config.Teleport.MaxRetries >= 1)
		t.eq(PlacePayload.MAX_MEMBERS, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
	end)

	t.test("AC5: Single 역할이면 PlaceService가 아무것도 시작하지 않아요 (정적)", function()
		local src = source("src/server/PlaceService.luau")
		local startAt = string.find(src, "function PlaceService.start()", 1, true) :: number
		t.ok(startAt ~= nil)
		local body = string.sub(src, startAt)
		local singleAt = string.find(body, 'if role == "Single" then', 1, true) :: number
		local returnAt = string.find(body, "return", singleAt, true) :: number
		local hooksAt = string.find(body, "startLobby()", 1, true) :: number
		t.ok(singleAt ~= nil and returnAt ~= nil and returnAt < hooksAt, "Single returns before any hook")
		-- 훅이 없으면 RoomService는 지금과 같은 경로 (launchMatch 없음 → matchStartHandler)
		local room = source("src/server/RoomService.luau")
		t.ok(string.find(room, "local hooks: PlaceHooks = {}", 1, true) ~= nil, "no hooks by default")
		t.ok(string.find(room, "local launch = hooks.launchMatch", 1, true) ~= nil)
	end)

	t.test("정적: 매치 끝은 sendHome 뒤 PlaceService.finishMatch, 처리 안 되면 endMatch", function()
		local match = source("src/server/MatchService.luau")
		local finishAt = string.find(match, "local function finish(", 1, true) :: number
		t.ok(finishAt ~= nil)
		local body = string.sub(match, finishAt)
		local homeAt = string.find(body, "sendHome(roomId)", 1, true) :: number
		local placeAt = string.find(body, "PlaceService.finishMatch", 1, true) :: number
		local endAt = string.find(body, "RoomService.endMatch(roomId)", 1, true) :: number
		t.ok(homeAt < placeAt and placeAt < endAt)
		-- 단상은 Single에서만 매치 서비스가 보내요 (나머지는 로비 서버가 MatchResult로)
		t.ok(string.find(match, 'if PlaceService.role() == "Single" then', 1, true) ~= nil)
		-- 크래시 경로도 Won 받은 사람을 우승자로 (m4-01 QA B2)
		t.ok(string.find(match, "RoundLogic.winnerOf(ctx.standings)", 1, true) ~= nil)
	end)

	t.test(
		"정적: 보안 — 매치 서버는 매니페스트만 믿고, 텔레포트 데이터는 검증해요",
		function()
			local place = source("src/server/PlaceService.luau")
			t.ok(string.find(place, "PlacePayload.validateManifest(raw)", 1, true) ~= nil, "manifest validated")
			t.ok(string.find(place, "b.hashGet(MANIFEST_MAP, privateServerId)", 1, true) ~= nil, "keyed by server")
			t.ok(string.find(place, "PlacePayload.validateReturnTicket(raw, player.UserId)", 1, true) ~= nil)
			t.ok(string.find(place, "PlacePayload.validateJoinTicket(raw)", 1, true) ~= nil)
			t.ok(string.find(place, "not isManifestMember(player.UserId)", 1, true) ~= nil, "non-members bounced")
			-- 매치 힌트(TeleportData)는 매치 서버에서 읽지 않아요
			t.eq(string.find(place, "validateMatchHint", 1, true), nil, "hint never trusted")
			-- 텔레포트 전에 저장
			local saveAt = string.find(place, "saveBeforeTeleport(players)", 1, true) :: number
			local sendAt = string.find(place, "teleportGroup(players, {", 1, true) :: number
			t.ok(saveAt ~= nil and sendAt ~= nil and saveAt < sendAt, "save before teleport")
		end
	)

	t.test(
		"정적: 다른 서버 방 참가는 저장소에서 다시 확인하고, 이 서버 방 id와 섞이지 않아요",
		function()
			local room = source("src/server/RoomService.luau")
			t.ok(string.find(room, "RoomDirectoryLogic.isRemoteId(roomId)", 1, true) ~= nil)
			local dir = source("src/server/RoomDirectory.luau")
			t.ok(string.find(dir, "b.sortedGet, DIRECTORY_MAP, id", 1, true) ~= nil, "re-read before teleport")
			t.ok(string.find(dir, "RoomDirectoryLogic.canJoin(entry", 1, true) ~= nil)
			-- 서버 init 순서: PlaceService가 RoomService보다 먼저 start (훅을 먼저 걸어요)
			local init = source("src/server/init.server.luau")
			local placeAt = string.find(init, "require(script.PlaceService)", 1, true) :: number
			local roomAt = string.find(init, "require(script.RoomService)", 1, true) :: number
			t.ok(placeAt < roomAt)
		end
	)

	t.test(
		"정적: 순환 require 없음 (RoomService·RoomDirectory는 PlaceService를 부르지 않아요)",
		function()
			for _, file in
				{ "src/server/RoomService.luau", "src/server/RoomDirectory.luau", "src/server/PlaceBackend.luau" }
			do
				t.eq(string.find(source(file), "require%(script%.Parent%.PlaceService%)"), nil, file)
				t.eq(string.find(source(file), "require%(script%.Parent%.MatchService%)"), nil, file)
			end
			t.eq(string.find(source("src/server/PlaceService.luau"), "require%(script%.Parent%.MatchService%)"), nil)
		end
	)
end
