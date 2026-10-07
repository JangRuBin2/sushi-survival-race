--!strict
-- M1 소급 QA (docs/qa/m1-retro.md)에서 추가한 경계값 테스트.
-- 방 설정/코드/이름 검증의 이상한 입력, 방장 승계 연쇄, 자동 시작 취소 조건,
-- 결승 건너뛰기와 통과 인원의 경계 (GDD 3.2, 3.3, 4.1).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)
local Rules = RobloxRequire.require(Shared.Rules)

local function member(userId: number)
	return { userId = userId, name = `p{userId}` }
end

local function room(maxPlayers: number, memberCount: number)
	local r = RoomLogic.newRoom({
		id = "1",
		name = "room",
		maxPlayers = maxPlayers,
		isPrivate = false,
		slot = 1,
	}, member(1))
	for userId = 2, memberCount do
		assert(RoomLogic.addMember(r, member(userId)))
	end
	return r
end

return function(t: Test.Test)
	------------------------------------------------------------------------
	-- 방 설정 검증 (클라이언트 입력)

	t.test("validateSettings: 선택지 밖의 숫자(경계·NaN·무한·소수)는 거절", function()
		local nan = 0 / 0
		for i, maxPlayers in { 0, 3, 5, 25, -4, 12.5, nan, math.huge, -math.huge } do
			local settings, err = RoomLogic.validateSettings({ maxPlayers = maxPlayers, isPrivate = false })
			t.eq(settings, nil, `case {i} ({maxPlayers})`)
			t.ok(type(err) == "string", `case {i} has a reason`)
		end
	end)

	t.test("validateSettings: 알 수 없는 필드는 버리고 필요한 필드만 남겨요", function()
		local settings = RoomLogic.validateSettings({
			maxPlayers = 8,
			isPrivate = true,
			hostUserId = 999,
			code = "0000",
			state = "InMatch",
		})
		t.eq(settings, { maxPlayers = 8, isPrivate = true })
	end)

	t.test(
		"validateSettings: 이름이 공백/제어 문자뿐이면 nil (서버가 기본 이름을 써요)",
		function()
			local settings = RoomLogic.validateSettings({ maxPlayers = 12, isPrivate = false, name = "\n\t \0" })
			t.ok(settings ~= nil)
			t.eq((settings :: any).name, nil)
		end
	)

	t.test("validateSettings: table/boolean 이름은 거절", function()
		t.eq(RoomLogic.validateSettings({ maxPlayers = 12, isPrivate = false, name = {} }), nil)
		t.eq(RoomLogic.validateSettings({ maxPlayers = 12, isPrivate = false, name = true }), nil)
	end)

	------------------------------------------------------------------------
	-- 방 이름

	t.test("cleanName: 정확히 최대 길이는 그대로, 한 글자 넘으면 잘라요", function()
		local exact = string.rep("가", Config.Room.NameMaxLength)
		t.eq(RoomLogic.cleanName(exact), exact)
		local over = exact .. "나"
		t.eq(RoomLogic.cleanName(over), exact)
	end)

	t.test("cleanName: 자른 끝에 공백이 남지 않아요", function()
		local name = string.rep("a", Config.Room.NameMaxLength - 1) .. " bcd"
		local cleaned = RoomLogic.cleanName(name) :: string
		t.eq(cleaned, string.rep("a", Config.Room.NameMaxLength - 1))
	end)

	t.test("cleanName: NUL·탭 같은 제어 문자는 공백 하나로", function()
		t.eq(RoomLogic.cleanName("a\0b\tc"), "a b c")
	end)

	t.test("cleanName: 문자열이 아니면 nil", function()
		t.eq(RoomLogic.cleanName(123), nil)
		t.eq(RoomLogic.cleanName({}), nil)
	end)

	------------------------------------------------------------------------
	-- 방 코드

	t.test("isValidCode: 공백·전각 숫자·부호·nil은 거절", function()
		for i, code in { " 1234", "1234 ", "12 4", "１２３４", "-123", "+123", "", "12.4", nil :: any, {} } do
			t.ok(not RoomLogic.isValidCode(code), `case {i}`)
		end
	end)

	t.test("generateCode: 경계값 0과 9999도 4자리로", function()
		local function rngOf(value: number)
			return {
				NextInteger = function(_, min: number, max: number): number
					assert(min == 0 and max == 9999, `range [{min}, {max}]`)
					return value
				end,
			}
		end
		local never = function()
			return false
		end
		t.eq(RoomLogic.generateCode(rngOf(0), never), "0000")
		t.eq(RoomLogic.generateCode(rngOf(9999), never), "9999")
		t.ok(RoomLogic.isValidCode(RoomLogic.generateCode(rngOf(0), never)))
	end)

	------------------------------------------------------------------------
	-- 참가/퇴장/방장 승계

	t.test("방장이 연달아 나가면 매번 남은 사람 중 가장 먼저 들어온 사람이 방장", function()
		local r = room(8, 4)
		for expectedHost = 2, 4 do
			t.ok(RoomLogic.removeMember(r, r.hostUserId))
			t.eq(r.hostUserId, expectedHost)
		end
		t.eq(#r.members, 1)
	end)

	t.test("마지막 사람이 나가면 멤버가 비어요 (RoomService가 방을 닫는 조건)", function()
		local r = room(4, 1)
		t.ok(RoomLogic.removeMember(r, 1))
		t.eq(#r.members, 0)
	end)

	t.test("나간 사람 자리가 비면 다시 참가할 수 있어요, 같은 사람도", function()
		local r = room(4, 4)
		t.eq(RoomLogic.canJoin(r, 9), false)
		RoomLogic.removeMember(r, 3)
		t.eq(RoomLogic.canJoin(r, 9), true)
		t.eq(RoomLogic.canJoin(r, 3), true, "rejoin after leaving")
	end)

	t.test("새 방장은 시작 권한을 갖고, 이전 방장은 잃어요", function()
		local r = room(8, 4)
		RoomLogic.removeMember(r, 1)
		RoomLogic.addMember(r, member(1))
		t.eq(RoomLogic.canStart(r, 1, 4), false, "old host rejoined")
		t.eq(RoomLogic.canStart(r, 2, 4), true, "new host")
	end)

	t.test(
		"정원이 찬 방에서 한 명이 나가면 자동 시작 조건이 꺼지고, 다시 차면 켜져요",
		function()
			local r = room(4, 4)
			t.ok(RoomLogic.shouldAutoStart(r))
			RoomLogic.removeMember(r, 2)
			t.ok(not RoomLogic.shouldAutoStart(r))
			RoomLogic.addMember(r, member(5))
			t.ok(RoomLogic.shouldAutoStart(r))
		end
	)

	t.test("실서버 최소 인원은 4명, 3명이면 방장도 시작 못 해요", function()
		local min = RoomLogic.minPlayersToStart(false)
		t.eq(min, 4)
		t.eq(RoomLogic.canStart(room(8, 3), 1, min), false)
		t.eq(RoomLogic.canStart(room(8, 4), 1, min), true)
	end)

	t.test("pickQuickJoin: 대기 중인 공개 방이 하나 남았으면 정원 직전이라도 골라요", function()
		local r = room(4, 3)
		t.eq(RoomLogic.pickQuickJoin({ r }), r)
	end)

	------------------------------------------------------------------------
	-- 라운드 규칙 경계

	t.test("roundCount 경계: 8명 3라운드, 9명 4라운드", function()
		t.eq(Rules.roundCount(8), 3)
		t.eq(Rules.roundCount(9), 4)
	end)

	t.test("nextRound: 결승 전 남은 인원이 2명 이하이면 어느 라운드 뒤든 결승으로", function()
		for _, roundCount in { 3, 4 } do
			for finished = 1, roundCount - 1 do
				for alive = 0, 2 do
					t.eq(
						Rules.nextRound(finished, roundCount, alive),
						roundCount,
						`{finished}/{roundCount} alive {alive}`
					)
				end
				t.eq(Rules.nextRound(finished, roundCount, 3), finished + 1, `{finished}/{roundCount} alive 3`)
			end
		end
	end)

	t.test("nextRound가 결승 아닌 라운드를 주면 그 라운드는 항상 1명 이상 탈락해요", function()
		for _, roundCount in { 3, 4 } do
			for finished = 1, roundCount - 1 do
				for alive = 0, 24 do
					local nextIndex = Rules.nextRound(finished, roundCount, alive)
					if nextIndex and nextIndex < roundCount then
						local q = Rules.qualifyCount(alive, roundCount, nextIndex)
						t.ok(q <= alive - 1 and q >= 2, `{nextIndex}/{roundCount} alive {alive}: {q}`)
					end
				end
			end
		end
	end)

	t.test("qualifyCount: 남은 인원 3명이면 결승 전 어느 라운드든 2명 통과", function()
		for _, roundCount in { 3, 4 } do
			for round = 1, roundCount - 1 do
				t.eq(Rules.qualifyCount(3, roundCount, round), 2, `{round}/{roundCount}`)
			end
		end
	end)

	t.test(
		"qualifyCount: 인원이 0~2명이어도 에러 없이 숫자를 돌려줘요 (매치 중 이탈 대비)",
		function()
			for _, roundCount in { 3, 4 } do
				for round = 1, roundCount do
					for alive = 0, 2 do
						local ok, q = pcall(Rules.qualifyCount, alive, roundCount, round)
						t.ok(ok and type(q) == "number", `{round}/{roundCount} alive {alive}`)
					end
				end
			end
		end
	)

	t.test(
		"GDD 4.1: 결승 직전 인원은 항상 2명 이상, 결승 전 라운드 수는 라운드 수 - 1 이하",
		function()
			for n = 4, 24 do
				local roundCount = Rules.roundCount(n)
				local alive = n
				local round: number? = 1
				local played = 0
				while round and round < roundCount do
					alive = Rules.qualifyCount(alive, roundCount, round)
					played += 1
					round = Rules.nextRound(round, roundCount, alive)
				end
				t.ok(alive >= 2, `start {n}: {alive} before final`)
				t.ok(played <= roundCount - 1, `start {n}: {played} rounds before final`)
				t.eq(round, roundCount, `start {n}: reaches final`)
			end
		end
	)
end
