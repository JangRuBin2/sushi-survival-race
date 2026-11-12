--!strict
-- m6-01 QA (docs/qa/m6-01-race-respawn.md): Race 부활 경계값과 m6-08~12(공격·다이너마이트)와의 상호작용.
--   - 순수: 시간 종료 때 부활 대기자는 출발점 진행도로 빈 자리 경쟁, 정원 마감 때 전원 부활 대기여도 끝남,
--     퇴장(강제 Reset)은 구제 없음·혼자 남으면 부전 통과, Respawn = false면 예전 낙하 + 구제, 끝난 라운드·다른 방식은 부활 없음
--   - 카운트다운: 0·음수·지연(3)보다 큰 숫자가 나오지 않음
--   - 소스 계약: 부활 대기자는 공격·다이너마이트·잡기 대상이 아님(activeRoomOf), 출발점 보내기 조건,
--     부활 시작은 respawning 표시 뒤에 순간이동, 라운드가 끝나면 고정(Anchored)이 풀림

local fs = require("@lune/fs")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local RespawnCountdownLogic = RobloxRequire.require(Shared.RespawnCountdownLogic)

local function scores(map: { [number]: number }): (number) -> number
	return function(userId: number): number
		return map[userId] or -math.huge
	end
end

local function split(outcomes: { any }): ({ number }, { number })
	local passed, eliminated = {}, {}
	for _, outcome in outcomes do
		if outcome.result == "Passed" then
			table.insert(passed, outcome.userId)
		elseif outcome.result == "Eliminated" then
			table.insert(eliminated, outcome.userId)
		end
	end
	return passed, eliminated
end

-- 함수 본문 (다음 같은 들여쓰기의 end까지)
local function body(src: string, header: string, indent: string): string
	local s = string.find(src, header, 1, true)
	assert(s, `not found: {header}`)
	local e = string.find(src, "\n" .. indent .. "end", s, true)
	assert(e, `no end for {header}`)
	return string.sub(src, s, e)
end

return function(t: Test.Test)
	t.test(
		"시간 종료: 부활 대기자는 출발점 진행도로 빈 자리를 겨뤄요 (더 멀리 간 사람이 먼저)",
		function()
			local race = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(race, 3)
			RoundLogic.pass(race, 1, scores({}))
			-- 2: 코스 중간(120), 3: 부활 대기(출발점 10), 4: 출발점 뒤쪽 스폰 줄(5), 5: 캐릭터 없음
			local outcomes = RoundLogic.timeout(race, scores({ [2] = 120, [3] = 10, [4] = 5 }))
			local passed, eliminated = split(outcomes)
			t.eq(passed, { 2, 3 })
			t.eq(eliminated, { 5, 4 }) -- 못 간 사람부터 탈락 → 4가 더 좋은 등수
			t.eq(race.ended, true)
			t.eq(RoundLogic.respawns(race, 4, true), false)
		end
	)

	t.test("정원 마감: 남은 사람이 모두 부활 대기여도 그 순간 끝나고 전원 탈락", function()
		local race = RoundLogic.newRound("Race", { 1, 2, 3, 4, 5, 6 })
		RoundLogic.activate(race, 2)
		RoundLogic.pass(race, 1, scores({}))
		local outcomes = RoundLogic.pass(race, 2, scores({ [3] = 0, [4] = 0, [5] = 0, [6] = 0 }))
		local passed, eliminated = split(outcomes)
		t.eq(passed, { 2 })
		t.eq(#eliminated, 4)
		t.eq(race.ended, true)
		for id = 3, 6 do
			t.eq(RoundLogic.respawns(race, id, true), false)
			t.eq(RoundLogic.isRacing(race, id), false)
		end
	end)

	t.test(
		"Race 퇴장(강제 Reset)은 구제 없음, 둘이 동시에 나가 혼자 남으면 부전 통과",
		function()
			local race = RoundLogic.newRound("Race", { 1, 2, 3 })
			RoundLogic.activate(race, 2)
			local outcomes = RoundLogic.eliminate(race, {
				{ userId = 1, score = -math.huge, cause = "Reset" },
				{ userId = 2, score = -math.huge, cause = "Reset" },
			}, scores({ [3] = 0 }))
			local passed, eliminated = split(outcomes)
			t.eq(passed, { 3 })
			table.sort(eliminated)
			t.eq(eliminated, { 1, 2 })
			t.eq(race.ended, true)
		end
	)

	t.test("Race 한 명 퇴장: 나머지는 계속 달리고(부활 가능) 라운드는 안 끝나요", function()
		local race = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
		RoundLogic.activate(race, 2)
		local outcomes = RoundLogic.eliminate(race, { { userId = 4, score = -math.huge, cause = "Reset" } }, scores({}))
		local _, eliminated = split(outcomes)
		t.eq(eliminated, { 4 })
		t.eq(race.ended, false)
		t.eq(RoundLogic.respawns(race, 1, true), true)
		t.eq(RoundLogic.respawns(race, 4, true), false)
	end)

	t.test(
		"Config.Race.Respawn = false 경로: Race 낙하는 예전처럼 탈락 + 결승 진출 2명 구제",
		function()
			local race = RoundLogic.newRound("Race", { 1, 2, 3 })
			RoundLogic.activate(race, 2)
			t.eq(RoundLogic.respawns(race, 2, false), false)
			-- 2·3이 같은 틱에 떨어지면 살아남을 사람이 1명 → 더 멀리 간 3이 구제(통과)
			local outcomes = RoundLogic.eliminate(race, {
				{ userId = 2, score = 10, cause = "Fall" },
				{ userId = 3, score = 50, cause = "Fall" },
			}, scores({ [1] = 0 }))
			local passed, eliminated = split(outcomes)
			t.ok(table.find(passed, 3) ~= nil, "3 rescued")
			t.eq(eliminated, { 2 })
		end
	)

	t.test(
		"부활은 결승이 아닌 Race 방식에서만: Survival·Final(결승 Race 맵 포함)은 누구도 부활 안 함",
		function()
			local ids = { 1, 2, 3, 4 }
			for _, case in
				{
					{ kind = "Survival", final = false },
					{ kind = "Survival", final = true },
					{ kind = "Final", final = true },
					{ kind = "Race", final = true },
				} :: { any }
			do
				local round = RoundLogic.newRound(RoundLogic.modeFor(case.kind, case.final), ids)
				for _, id in ids do
					t.eq(RoundLogic.respawns(round, id, true), false, `{case.kind} final={case.final}`)
				end
				RoundLogic.activate(round, 2)
				for _, id in ids do
					t.eq(RoundLogic.respawns(round, id, true), false, `{case.kind} final={case.final} active`)
				end
			end
		end
	)

	t.test("카운트다운: 지연 3초 동안 3 → 2 → 1, 0·음수·3 초과는 안 나와요", function()
		local delay = Config.Race.RespawnDelay
		local at = 1000
		local seen: { [number]: boolean } = {}
		local step = 0
		while step <= 200 do
			local now = at - delay + step * 0.05
			local s = RespawnCountdownLogic.secondsLeft(at, now) :: number
			t.ok(s ~= nil and s >= 1 and s <= delay, `now {now}: {tostring(s)}`)
			seen[s] = true
			step += 1
		end
		for n = 1, delay do
			t.ok(seen[n], `shows {n}`)
		end
		t.eq(RespawnCountdownLogic.secondsLeft(at, at - delay), delay) -- 처음 보이는 숫자 = 3
		t.eq(RespawnCountdownLogic.secondsLeft(true, at), nil)
		t.eq(RespawnCountdownLogic.secondsLeft({}, at), nil)
	end)

	t.test(
		"소스 계약: 부활 대기자는 공격·다이너마이트·잡기 대상이 아니에요 (activeRoomOf)",
		function()
			local round = fs.readFile("src/server/RoundService.luau")
			local racing = body(round, "activeRacing[roomId] = function", "\t\t")
			t.ok(string.find(racing, "not respawning[userId]", 1, true) ~= nil, "activeRacing excludes respawning")
			local placedFn = body(round, "placedRacing[roomId] = function", "\t\t")
			t.ok(string.find(placedFn, "not respawning[userId]", 1, true) ~= nil, "placedRacing excludes respawning")
			for _, path in
				{ "src/server/AttackService.luau", "src/server/DynamiteService.luau", "src/server/GrabService.luau" }
			do
				local src = fs.readFile(path)
				t.ok(string.find(src, "RoundService.activeRoomOf(", 1, true) ~= nil, `{path} uses activeRoomOf`)
				t.eq(string.find(src, "placedRoomOf", 1, true), nil, `{path} must not use placedRoomOf`)
			end
			-- 공격 대상 후보도 activeRoomOf로 걸러요 (부활 대기 중인 사람은 맞지 않음)
			local attack = fs.readFile("src/server/AttackService.luau")
			t.ok(
				string.find(attack, "other == player or RoundService.activeRoomOf(other) ~= roomId", 1, true) ~= nil,
				"attack candidates"
			)
		end
	)

	t.test(
		"소스 계약: 다이너마이트 출발점 보내기 = 부활 흐름, 조건이 빠지지 않았어요",
		function()
			local round = fs.readFile("src/server/RoundService.luau")
			local home = body(round, "sendHome[roomId] = function", "\t\t")
			for _, needle in
				{
					"closed",
					"round.ended",
					"not placed[userId]",
					"respawning[userId]",
					"pendingIds[userId]",
					"RoundLogic.respawns(round, userId, respawnEnabled)",
					'startRespawn(userId, "Fall")',
				}
			do
				t.ok(string.find(home, needle, 1, true) ~= nil, `sendHome: {needle}`)
			end
			-- 부활 시작은 respawning 표시 → 속성 → 순간이동·고정 순서 (이동 감시가 그 사이 레이서로 보지 않게)
			local start = body(round, "startRespawn = function", "\t\t")
			local mark = string.find(start, "respawning[userId] = true", 1, true) :: number
			local pivot = string.find(start, "character:PivotTo(", 1, true) :: number
			t.ok(mark ~= nil and pivot ~= nil and mark < pivot, "mark respawning before PivotTo")
			t.ok(string.find(start, "MoveExempt.mark(character, respawnDelay + 1)", 1, true) ~= nil, "exempt")
			t.ok(string.find(start, "root.Anchored = true", 1, true) ~= nil, "hold at start")
			-- 다시 세울 때 고정을 풀고 감시를 새 캐릭터로
			local stand = body(round, "local function standOn(", "\t\t")
			for _, needle in
				{ "root.Anchored = false", "MoveExempt.mark(character)", "notifyPlaced(", "watch(player, character)" }
			do
				t.ok(string.find(stand, needle, 1, true) ~= nil, `standOn: {needle}`)
			end
		end
	)

	t.test(
		"소스 계약: 라운드가 끝나면(탈락·통과·취소·방 나감) 부활 고정이 풀리고 속성이 지워져요",
		function()
			local util = fs.readFile("src/server/CharacterUtil.luau")
			local toLobby = body(util, "function CharacterUtil.toLobby(", "")
			t.ok(string.find(toLobby, "root.Anchored = false", 1, true) ~= nil, "toLobby unanchors")
			t.ok(string.find(toLobby, "CharacterUtil.resetMovement(humanoid)", 1, true) ~= nil, "toLobby unlocks")
			local elim = fs.readFile("src/server/EliminationService.luau")
			t.ok(string.find(elim, "CharacterUtil.toLobby(player)", 1, true) ~= nil, "eliminated → toLobby")
			local match = fs.readFile("src/server/MatchService.luau")
			local left = body(match, "RoomService.onMemberLeft(function", "\t")
			t.ok(string.find(left, "CharacterUtil.toLobby(player)", 1, true) ~= nil, "left room → toLobby")
			local round = fs.readFile("src/server/RoundService.luau")
			local apply = body(round, "local function apply(", "\t\t")
			t.ok(string.find(apply, "clearRespawn(userId)", 1, true) ~= nil, "apply clears respawn per outcome")
			local cancel = body(round, "cancel = function()", "\t\t\t")
			t.ok(string.find(cancel, "CharacterUtil.toLobby(player)", 1, true) ~= nil, "cancel → toLobby")
		end
	)

	t.test("문구: 카운트다운 키 2개가 한국어·영어 모두 있어요", function()
		local csv = fs.readFile("src/shared/Localization/Strings.csv")
		for _, key in { "hud.respawn.title", "hud.respawn.sub" } do
			local line = string.match(csv, "\n" .. string.gsub(key, "%.", "%%.") .. ",[^\n]*")
			t.ok(line ~= nil, key)
			local en = string.match(line :: string, ",([^,]*)$")
			t.ok(en ~= nil and #en > 0, `{key} en`)
		end
	end)
end
