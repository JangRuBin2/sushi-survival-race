--!strict
-- m4-11 QA: 플레이스 분리의 경계값과 계약.
--   - 로비가 실제로 만드는 방 이름(기본 이름·정리된 이름)이 매니페스트 검증을 통과하는지 (통과 못 하면 매치 서버가 취소)
--   - MemoryStore·TeleportData는 JSON을 거쳐요: 만든 값이 JSON 왕복 뒤에도 검증을 통과하는지
--   - 도착 대기·복귀 방장·방 목록·빠른 참가의 경계
--   - 정적: Notice 방향, 커밋 상태의 디버그 값, 매치 서버에서 로비 UI·자동 시작 없음, 데이터 잠금 대기 값
-- (docs/qa/m4-11-place-split.md)

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local PlacePayload = RobloxRequire.require(Shared.PlacePayload)
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

local function json(value: any): any
	return serde.decode("json", serde.encode("json", value))
end

local GUID = "8C2D1E0A-1111-2222-3333-444455556666"

local function settingsWith(name: string, maxPlayers: number?, isPrivate: boolean?): { [string]: any }
	return { maxPlayers = maxPlayers or 8, isPrivate = isPrivate == true, name = name }
end

local function manifestWith(settings: { [string]: any }, members: { number }): { [string]: any }
	return PlacePayload.manifest({
		roomKey = GUID,
		settings = settings :: any,
		hostUserId = members[1],
		memberUserIds = members,
		lobbyJobId = "a1b2c3d4-0000-1111-2222-333344445555",
		createdAt = 1700000000,
	})
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

return function(t: Test.Test)
	------------------------------------------------------------------ 방 이름 → 매니페스트
	t.test("이름: 로비가 만드는 기본 이름은 길어도 매니페스트 검증을 통과해요", function()
		-- DisplayName은 최대 20자. "의 초밥집"이 붙으면 24자를 넘어서 잘려요
		for _, displayName in
			{
				"a",
				"Player",
				"abcdefghijklmnopqrst",
				"가나다라마바사아자차카타파하가나다라마바",
				"한글English섞인이름_123",
				"ends_with_space_____",
			}
		do
			local name = RoomLogic.defaultName(displayName)
			local m = manifestWith(settingsWith(name), { 1, 2, 3, 4 })
			local valid, err = PlacePayload.validateManifest(m)
			t.ok(valid ~= nil, `default name "{name}" rejected: {err}`)
		end
	end)

	t.test("이름: cleanName은 두 번 해도 같아요 (정리된 이름은 다시 검증해도 통과)", function()
		for _, raw in
			{
				"  초밥   가게  ",
				"tab\there",
				"line\nbreak",
				string.rep("가", 30),
				string.rep("a", 23) .. " b",
				string.rep("a", 24) .. "   ",
				"#### ####", -- 텍스트 필터 결과 모양
				"🍣 초밥 🍣",
			}
		do
			local once = RoomLogic.cleanName(raw)
			t.ok(once ~= nil, raw)
			t.eq(RoomLogic.cleanName(once), once, `not idempotent: {raw}`)
			local valid = PlacePayload.validateSettings(settingsWith(once :: string))
			t.ok(valid ~= nil, `cleaned "{once}" rejected`)
		end
	end)

	t.test("이름: 빈 이름·공백만·제어 문자·잘못된 UTF-8은 거부", function()
		for _, bad in { "", "   ", "a\0b", " lead", "trail ", "\255\254", string.rep("가", 25) } do
			t.eq(PlacePayload.validateSettings(settingsWith(bad)), nil, `accepted {bad}`)
		end
	end)

	------------------------------------------------------------------ JSON 왕복 (MemoryStore·TeleportData)
	t.test("JSON 왕복: 매니페스트·복귀 티켓·참가 티켓·결과가 그대로 검증돼요", function()
		local members = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
		local m = manifestWith(settingsWith("초밥집", 12, true), members)
		local mv = PlacePayload.validateManifest(json(m))
		t.ok(mv ~= nil, "manifest")
		t.eq(mv, m)

		local ticket = PlacePayload.returnTicket(GUID, settingsWith("초밥집", 12) :: any, 3, members)
		t.ok(PlacePayload.validateReturnTicket(json(ticket), 7) ~= nil, "return ticket")

		t.ok(PlacePayload.validateJoinTicket(json(PlacePayload.joinTicket("17", nil))) ~= nil, "join by id")
		t.ok(PlacePayload.validateJoinTicket(json(PlacePayload.joinTicket(nil, "0042"))) ~= nil, "join by code")

		local withWinner = PlacePayload.matchResult(m :: any, { userId = 5, name = "초밥왕", appearanceId = "egg" })
		local rv = PlacePayload.validateMatchResult(json(withWinner))
		t.ok(rv ~= nil and rv.winnerUserId == 5 and rv.winnerName == "초밥왕", "result with winner")
		local noWinner = PlacePayload.matchResult(m :: any, nil)
		local nv = PlacePayload.validateMatchResult(json(noWinner))
		t.ok(nv ~= nil and nv.winnerUserId == nil, "result without winner")
	end)

	t.test("JSON 왕복: 실제 크기의 userId(10자리 이상)도 정수로 남아요", function()
		local big = { 4567891234, 9876543210, 1, 2 }
		local m = manifestWith(settingsWith("x", 4), big)
		local mv = PlacePayload.validateManifest(json(m))
		t.ok(mv ~= nil)
		t.eq((mv :: any).memberUserIds, big)
	end)

	------------------------------------------------------------------ 검증 경계
	t.test(
		"멤버: 실수·음수·0·NaN·2^53·문자열 숫자·구멍 난 배열·키 섞인 표는 거부",
		function()
			for _, bad in
				{
					{ 1.5 },
					{ -1 },
					{ 0 },
					{ 0 / 0 },
					{ 2 ^ 53 },
					{ "101" },
					{},
				}
			do
				t.eq(PlacePayload.validateMembers(bad), nil)
			end
			local holey = { 1, 2 }
			holey[4] = 4
			t.eq(PlacePayload.validateMembers(holey), nil, "holey")
			local mixed: any = { 1, 2 }
			mixed.extra = 3
			t.eq(PlacePayload.validateMembers(mixed), nil, "mixed")
			t.eq(PlacePayload.validateMembers("1,2"), nil, "string")
		end
	)

	t.test(
		"매니페스트: 정원(maxPlayers)과 멤버 수 — 같으면 통과, 넘으면 거부 (4명 방)",
		function()
			local four = manifestWith(settingsWith("x", 4), { 1, 2, 3, 4 })
			t.ok(PlacePayload.validateManifest(four) ~= nil)
			local five = manifestWith(settingsWith("x", 4), { 1, 2, 3, 4, 5 })
			t.eq(PlacePayload.validateManifest(five), nil)
		end
	)

	t.test("roomKey: 공백·따옴표·65자·빈 문자열은 거부, GUID는 통과", function()
		for _, bad in { "", "a b", 'a"b', string.rep("a", 65), "../x", 5 } do
			local m = manifestWith(settingsWith("x"), { 1, 2 })
			m.roomKey = bad
			t.eq(PlacePayload.validateManifest(m), nil, tostring(bad))
		end
		t.ok(PlacePayload.validateManifest(manifestWith(settingsWith("x"), { 1, 2 })) ~= nil)
		local braced = manifestWith(settingsWith("x"), { 1, 2 })
		braced.roomKey = `\{{GUID}\}`
		t.ok(PlacePayload.validateManifest(braced) ~= nil, "GenerateGUID(true) form")
	end)

	t.test("복귀 티켓: 버전 2·종류 join·maxPlayers 5(고를 수 없는 값)는 거부", function()
		local base = PlacePayload.returnTicket(GUID, settingsWith("x") :: any, 1, { 1, 2 })
		local v2 = table.clone(base)
		v2.v = 2
		t.eq(PlacePayload.validateReturnTicket(v2, 1), nil)
		local kind = table.clone(base) :: any
		kind.kind = "join"
		t.eq(PlacePayload.validateReturnTicket(kind, 1), nil)
		local odd = PlacePayload.returnTicket(GUID, settingsWith("x", 5) :: any, 1, { 1, 2 })
		t.eq(PlacePayload.validateReturnTicket(odd, 1), nil)
		t.eq(PlacePayload.validateReturnTicket(nil, 1), nil)
		t.eq(PlacePayload.validateReturnTicket("return", 1), nil)
	end)

	t.test("참가 티켓: 코드 3자리·5자리·문자·방 id 17자는 거부", function()
		for _, bad in { "123", "12345", "12a4" } do
			t.eq(PlacePayload.validateJoinTicket({ v = 1, kind = "join", code = bad }), nil, bad)
		end
		t.eq(PlacePayload.validateJoinTicket({ v = 1, kind = "join", roomId = string.rep("1", 17) }), nil)
		t.eq(PlacePayload.validateJoinTicket({ v = 1, kind = "join", roomId = 7 }), nil, "number id")
	end)

	t.test("결과: 우승자 이름이 없거나 appearanceId가 숫자면 거부", function()
		local m = manifestWith(settingsWith("x"), { 1, 2 })
		local r = PlacePayload.matchResult(m :: any, { userId = 1, name = "a", appearanceId = "egg" }) :: any
		r.winnerName = nil
		t.eq(PlacePayload.validateMatchResult(r), nil)
		local r2 = PlacePayload.matchResult(m :: any, { userId = 1, name = "a", appearanceId = "egg" }) :: any
		r2.appearanceId = 3
		t.eq(PlacePayload.validateMatchResult(r2), nil)
	end)

	------------------------------------------------------------------ 도착 대기 · 복귀 방장
	t.test("arrivalReady 경계: 시간이 딱 timeout이면 더 기다리지 않아요", function()
		local timeout = Config.Teleport.ArrivalTimeout
		t.eq(timeout, 20, "spec default 20s")
		t.eq(PlacePayload.arrivalReady(4, 3, timeout - 0.01, timeout), "wait")
		t.eq(PlacePayload.arrivalReady(4, 3, timeout, timeout), "start")
		t.eq(PlacePayload.arrivalReady(4, 1, timeout, timeout), "abort")
		-- 24명 방, 23명 도착 → 기다림, 시간 초과 → 시작
		t.eq(PlacePayload.arrivalReady(24, 23, 5, timeout), "wait")
		t.eq(PlacePayload.arrivalReady(24, 23, timeout + 1, timeout), "start")
		-- 2명 방에서 1명만 → 시간 초과 때 취소, 둘 다 → 바로 시작
		t.eq(PlacePayload.arrivalReady(2, 1, timeout, timeout), "abort")
		t.eq(PlacePayload.arrivalReady(2, 2, 0, timeout), "start")
	end)

	t.test("pickRestoreHost: 아무도 없으면 nil, 방장이 늦게 와도 방장", function()
		t.eq(PlacePayload.pickRestoreHost(5, {}), nil)
		t.eq(PlacePayload.pickRestoreHost(5, { 9, 8, 5 }), 5)
		t.eq(PlacePayload.pickRestoreHost(5, { 9, 8 }), 9)
	end)

	------------------------------------------------------------------ 늦게 온 멤버
	t.test("addLateMember: 게임 중인 방에도 들어가고, 중복·정원 초과는 거부", function()
		local room = RoomLogic.newRoom({
			id = "1",
			name = "x",
			maxPlayers = 4,
			isPrivate = false,
			code = nil,
			slot = 1,
			key = GUID,
		}, { userId = 1, name = "a" })
		room.state = "InMatch"
		t.eq(RoomLogic.addMember(room, { userId = 2, name = "b" }), false, "normal join blocked in match")
		t.eq(RoomLogic.addLateMember(room, { userId = 2, name = "b" }), true)
		t.eq(RoomLogic.addLateMember(room, { userId = 2, name = "b" }), false, "duplicate")
		t.eq(RoomLogic.addLateMember(room, { userId = 3, name = "c" }), true)
		t.eq(RoomLogic.addLateMember(room, { userId = 4, name = "d" }), true)
		t.eq(RoomLogic.addLateMember(room, { userId = 5, name = "e" }), false, "full")
		t.eq(room.hostUserId, 1, "host unchanged")
	end)

	------------------------------------------------------------------ 방 목록
	t.test(
		"parseKey: 이 서버 방 id(숫자)는 원격이 아니고, 콜론이 여럿이면 마지막 기준",
		function()
			t.eq(RoomDirectoryLogic.isRemoteId("12"), false)
			t.eq(RoomDirectoryLogic.isRemoteId(12), false)
			t.eq(RoomDirectoryLogic.isRemoteId(":12"), false, "empty job")
			t.eq(RoomDirectoryLogic.isRemoteId("job:"), false, "empty room")
			local jobId, roomId = RoomDirectoryLogic.parseKey("a:b:c")
			t.eq(jobId, "a:b")
			t.eq(roomId, "c")
			t.eq(RoomDirectoryLogic.isRemoteId(string.rep("a", 128) .. ":1"), false, "too long (> 128)")
		end
	)

	t.test("merge: 만료 경계(딱 TTL은 살아 있음), 내 서버 항목·깨진 항목은 빠져요", function()
		local ttl = Config.Teleport.DirectoryTtl
		local now = 1000 + ttl
		local remote = {
			entry("other", "1", { updatedAt = 1000 }), -- now - updatedAt == ttl → 살아 있음
			entry("other", "2", { updatedAt = 999 }), -- 만료
			entry("mine", "3", { updatedAt = now }), -- 이 서버
			entry("other", "4", { state = "Closed", updatedAt = now }), -- 깨진 상태
			entry("other", "5", { name = "", updatedAt = now }), -- 빈 이름
		}
		local merged = RoomDirectoryLogic.merge({}, remote :: any, "mine", now, ttl)
		t.eq(#merged, 1)
		t.eq(merged[1].id, "other:1")
		t.eq(merged[1].remote, true)
	end)

	t.test("merge: 같은 키 원격 항목 둘이면 최신 값, 한도 0이면 빈 목록", function()
		local remote = {
			entry("o", "1", { memberCount = 1, updatedAt = 990 }),
			entry("o", "1", { memberCount = 5, updatedAt = 995 }),
		}
		local merged = RoomDirectoryLogic.merge({}, remote :: any, "mine", 1000, 30)
		t.eq(#merged, 1)
		t.eq(merged[1].memberCount, 5)
		t.eq(#RoomDirectoryLogic.merge({}, remote :: any, "mine", 1000, 30, 0), 0)
	end)

	t.test("merge: 이 서버 방이 50개를 넘으면 원격은 하나도 안 붙어요", function()
		local localListings = {}
		for i = 1, 60 do
			table.insert(localListings, {
				id = tostring(i),
				name = `r{i}`,
				maxPlayers = 8,
				memberCount = 1,
				state = "Waiting",
			})
		end
		local merged = RoomDirectoryLogic.merge(
			localListings :: any,
			{ entry("o", "1", { updatedAt = 1000 }) } :: any,
			"m",
			1000,
			30
		)
		t.eq(#merged, RoomDirectoryLogic.MAX_LISTINGS)
		for _, listing in merged do
			t.eq(listing.remote, nil)
		end
	end)

	t.test("빠른 참가: 원격은 꽉 찬 방·게임 중·만료를 건너뛰고 사람 많은 방", function()
		local remote = {
			entry("o", "1", { memberCount = 8, updatedAt = 1000 }), -- 꽉 참
			entry("o", "2", { state = "InMatch", memberCount = 7, updatedAt = 1000 }),
			entry("o", "3", { memberCount = 7, updatedAt = 900 }), -- 만료
			entry("o", "4", { memberCount = 3, updatedAt = 1000 }),
			entry("o", "5", { memberCount = 6, updatedAt = 1000 }),
		}
		local pick = RoomDirectoryLogic.pickQuickJoin({}, remote :: any, "mine", 1000, 30)
		t.ok(pick ~= nil and pick.kind == "remote")
		t.eq((pick :: any).entry.roomId, "5")
		-- 이 서버 비공개·꽉 찬 방은 빠른 참가 대상이 아니라 원격으로 넘어가요
		local privateRoom = RoomLogic.newRoom({
			id = "9",
			name = "p",
			maxPlayers = 4,
			isPrivate = true,
			code = "1234",
			slot = 1,
			key = "k",
		}, { userId = 1, name = "a" })
		local pick2 = RoomDirectoryLogic.pickQuickJoin({ privateRoom }, remote :: any, "mine", 1000, 30)
		t.eq((pick2 :: any).kind, "remote")
	end)

	t.test(
		"entryFor: 비공개·게임 중 방은 올리지 않고, 공개 대기 방은 인원·정원 그대로",
		function()
			local room = RoomLogic.newRoom({
				id = "3",
				name = "공개",
				maxPlayers = 12,
				isPrivate = false,
				code = nil,
				slot = 1,
				key = "k",
			}, { userId = 1, name = "a" })
			local e = RoomDirectoryLogic.entryFor(room, "job", 50) :: any
			t.ok(e ~= nil)
			t.eq(e.memberCount, 1)
			t.eq(e.maxPlayers, 12)
			t.ok(RoomDirectoryLogic.readEntry(json(e)) ~= nil, "json round trip")
			room.state = "InMatch"
			t.eq(RoomDirectoryLogic.entryFor(room, "job", 50), nil)
		end
	)

	------------------------------------------------------------------ 정적 계약
	t.test(
		"정적: 커밋 상태 — 플레이스 id 없음·흉내 모드 꺼짐·강제 맵 없음 (Single이 기본)",
		function()
			t.eq(Config.Places.LobbyPlaceId, nil)
			t.eq(Config.Places.MatchPlaceId, nil)
			t.eq(Config.DEBUG.simulateMatchServer, false)
			t.eq(Config.DEBUG.forceMapPlan, nil)
			-- 잠금 대기: 텔레포트 직후 다른 서버가 잠금을 풀 시간 (spec 결정: 그대로 5 × 2초)
			t.ok(Config.Data.LoadRetries * Config.Data.RetryDelay >= 10, "lock wait >= 10s")
			t.ok(Config.Teleport.SaveBeforeTeleport <= Config.Data.LoadRetries * Config.Data.RetryDelay)
			t.eq(Config.Teleport.RestoreWindow, 30)
			t.eq(Config.Teleport.ResultTtl >= Config.Teleport.RestoreWindow, true, "result outlives restore window")
		end
	)

	t.test("정적: Notice는 서버 → 클라이언트만 (서버가 OnServerEvent를 받지 않아요)", function()
		for _, file in fs.readDir("src/server") do
			if string.match(file, "%.luau$") then
				local src = source(`src/server/{file}`)
				local has = string.find(src, 'Remotes.event("Notice").OnServerEvent', 1, true)
					or (string.find(src, "noticeEvent.OnServerEvent", 1, true))
				t.eq(has, nil, file)
			end
		end
		local client = source("src/client/ui/LobbyController.luau")
		t.ok(string.find(client, 'Remotes.event("Notice").OnClientEvent', 1, true) ~= nil)
		t.ok(string.find(client, 'type(message) ~= "string"', 1, true) ~= nil, "client checks type")
	end)

	t.test(
		"정적: 매치 서버 — 로비 요청 막기·방 목록 안 보냄·자동 시작 없음·로비 건물 없음",
		function()
			local room = source("src/server/RoomService.luau")
			t.ok(string.find(room, "if not hooks.matchServer and RoomLogic.shouldAutoStart(room)", 1, true) ~= nil)
			local blocked = string.match(room, "local function requireNoRoom.-\nend") :: string
			t.ok(blocked ~= nil and string.find(blocked, "hooks.matchServer", 1, true) ~= nil, "requireNoRoom")
			local start = string.match(room, "function handlers%.StartRoom.-\nend") :: string
			t.ok(string.find(start, "hooks.matchServer", 1, true) ~= nil, "StartRoom blocked")
			local lobby = source("src/server/LobbyService.luau")
			t.ok(string.find(lobby, 'if PlaceService.role() == "Match" then', 1, true) ~= nil)
			-- CreateRoom·JoinRoom·JoinByCode·QuickJoin 모두 requireNoRoom을 먼저 불러요
			for _, name in { "CreateRoom", "JoinRoom", "JoinByCode", "QuickJoin" } do
				local body = string.match(room, `function handlers%.{name}.-\nend`) :: string
				t.ok(body ~= nil and string.find(body, "requireNoRoom(player)", 1, true) ~= nil, name)
			end
		end
	)

	t.test("정적: 매치 서버는 매니페스트를 읽기 전에 아무도 방에 넣지 않아요", function()
		local place = source("src/server/PlaceService.luau")
		local added = string.match(place, "local function onMatchPlayerAdded.-\nend") :: string
		t.ok(added ~= nil)
		local loadingAt = string.find(added, 'if matchState == "loading" then', 1, true) :: number
		local memberAt = string.find(added, "if not isManifestMember(player.UserId) then", 1, true) :: number
		local lateAt = string.find(added, "RoomService.addLateMember", 1, true) :: number
		t.ok(loadingAt < memberAt and memberAt < lateAt, "loading → manifest check → late member")
		-- 도착 인원은 매니페스트 멤버만 셉니다
		local present = string.match(place, "local function presentArrivals.-\nend") :: string
		t.ok(string.find(present, "isManifestMember(player.UserId)", 1, true) ~= nil)
	end)

	t.test("정적: 로비 복귀는 MatchResult를 티켓보다 먼저 읽고, 단상은 결과에서만", function()
		local place = source("src/server/PlaceService.luau")
		local handle = string.match(place, "local function handleReturn.-\nend\n") :: string
		t.ok(handle ~= nil)
		local loadAt = string.find(handle, "loadResult(r)", 1, true) :: number
		local memberAt = string.find(handle, "r.members[player.UserId]", 1, true) :: number
		t.ok(loadAt ~= nil and memberAt ~= nil and loadAt < memberAt, "result before membership check")
		local _, showcaseCount = string.gsub(place, "MatchEvents%.fireWinnerShowcase%(", "")
		t.eq(showcaseCount, 1, "single showcase site in PlaceService")
	end)

	t.test(
		"정적: 텔레포트 전 저장은 두 방향(로비→매치, 매치→로비)과 서버 간 참가 모두",
		function()
			local place = source("src/server/PlaceService.luau")
			local _, count = string.gsub(place, "saveBeforeTeleport%(", "")
			-- 정의 1 + 로비→매치 1 + 매치→로비 1 + 다른 로비 1
			t.eq(count, 4)
			local back = string.match(place, "local function returnToLobby.-\nend") :: string
			local saveAt = string.find(back, "saveBeforeTeleport(players)", 1, true) :: number
			local sendAt = string.find(back, "teleportGroup(players", 1, true) :: number
			t.ok(saveAt < sendAt)
		end
	)
end
