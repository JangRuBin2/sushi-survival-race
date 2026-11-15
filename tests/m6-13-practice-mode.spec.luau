--!strict
-- m6-13 1인 연습 모드: 맵을 골라 혼자 한 라운드. 결승 아님, 구제 없음, 보상·순위 훅 없음.

local fs = require("@lune/fs")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local PracticeLogic = RobloxRequire.require(Shared.PracticeLogic)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)

local INFOS = {
	{ id = "hot-plate", kind = "Survival" },
	{ id = "rotating-belt", kind = "Race" },
	{ id = "skewer-showdown", kind = "Final" },
	{ id = "soy-swamp", kind = "Race" },
}

local function zero(_userId: number): number
	return 0
end

-- 함수 본문만 잘라요 (다음 최상위 local function / function까지)
local function body(src: string, header: string): string
	local start = string.find(src, header, 1, true)
	assert(start, `missing {header}`)
	local rest = string.sub(src, start + #header)
	local stop = string.find(rest, "\nlocal function ", 1, true) or string.find(rest, "\nfunction ", 1, true)
	return if stop then string.sub(rest, 1, stop) else rest
end

return function(t: Test.Test)
	t.test("resolveMap: 풀에 있는 id만, 타입·길이 검사", function()
		local info = PracticeLogic.resolveMap("soy-swamp", INFOS)
		t.eq(info and info.id, "soy-swamp")
		for _, bad in { nil, 5, "", "nope", string.rep("a", 65), { "soy-swamp" } } :: { any } do
			local none, reason = PracticeLogic.resolveMap(bad, INFOS)
			t.eq(none, nil)
			t.eq(reason, "BadPracticeMap")
		end
	end)

	t.test("orderedMaps: Race → Survival → Final, 같은 종류는 받은 순서", function()
		local ids = {}
		for _, info in PracticeLogic.orderedMaps(INFOS) do
			table.insert(ids, info.id)
		end
		t.eq(table.concat(ids, ","), "rotating-belt,soy-swamp,hot-plate,skewer-showdown")
	end)

	t.test("RoomLogic: BadPracticeMap 거절 문구 키", function()
		t.eq(RoomLogic.message("BadPracticeMap").key, "room.err.BadPracticeMap")
	end)

	t.test("연습 Survival: 혼자 떨어지면 구제 없이 탈락하고 끝", function()
		local round = RoundLogic.newRound(RoundLogic.modeFor("Survival", false), { 1 })
		round.noRescue = true
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, { { userId = 1, score = 0, cause = "Fall" } }, zero)
		t.eq(#out, 1)
		t.eq(out[1].result, "Eliminated")
		t.eq(round.ended, true)
	end)

	t.test("보통 Survival: 같은 낙하는 2명 보장 구제로 통과 (연습만 다름)", function()
		local round = RoundLogic.newRound(RoundLogic.modeFor("Survival", false), { 1 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, { { userId = 1, score = 0, cause = "Fall" } }, zero)
		t.eq(out[1].result, "Passed")
	end)

	t.test("연습 Survival·결승 맵: 시간 끝까지 버티면 통과(우승 아님)", function()
		for _, kind in { "Survival", "Final" } do
			local round = RoundLogic.newRound(RoundLogic.modeFor(kind, false), { 1 })
			round.noRescue = true
			RoundLogic.activate(round, 1)
			local out = RoundLogic.timeout(round, zero)
			t.eq(#out, 1)
			t.eq(out[1].result, "Passed")
		end
	end)

	t.test("연습 Race: 결승이 아니라 부활, 결승선 통과로 끝(우승 아님)", function()
		local round = RoundLogic.newRound(RoundLogic.modeFor("Race", false), { 1 })
		round.noRescue = true
		RoundLogic.activate(round, 1)
		t.eq(RoundLogic.respawns(round, 1, true), true)
		local out = RoundLogic.pass(round, 1, zero)
		t.eq(out[1].result, "Passed")
		t.eq(round.ended, true)
	end)

	t.test("RoundService: practice면 마지막 라운드여도 결승 아님, 구제 끔", function()
		local src = fs.readFile("src/server/RoundService.luau")
		t.ok(string.find(src, "args.roundIndex == args.roundCount and not args.practice", 1, true) ~= nil)
		t.ok(string.find(src, "round.noRescue = args.practice == true", 1, true) ~= nil)
	end)

	t.test(
		"MatchService.runPractice: MatchEvents·우승 처리를 부르지 않아요 (보상·뽑기권·단상 없음)",
		function()
			local src = fs.readFile("src/server/MatchService.luau")
			local practice = body(src, "local function runPractice(")
			for _, needle in
				{
					"MatchEvents.",
					"fireMatchEnd",
					"fireWinnerShowcase",
					"EliminationService.won",
					"decideWinner",
				}
			do
				t.ok(string.find(practice, needle, 1, true) == nil, `runPractice must not use {needle}`)
			end
			t.ok(string.find(practice, "practice = true", 1, true) ~= nil, "prepareRound practice flag")
			t.ok(string.find(practice, "endFired = true", 1, true) ~= nil, "crash path must not fire match end")
			t.ok(string.find(src, "runPractice(room, players, practiceMapId)", 1, true) ~= nil)
		end
	)

	t.test(
		"RoomService: StartPractice는 방 없음·맵 풀 검사, 텔레포트 없이, 끝나면 방을 닫아요",
		function()
			local src = fs.readFile("src/server/RoomService.luau")
			local handler = body(src, "function handlers.StartPractice(")
			t.ok(string.find(handler, "requireNoRoom(player)", 1, true) ~= nil)
			t.ok(string.find(handler, "PracticeLogic.resolveMap(rawMapId, Maps.infos())", 1, true) ~= nil)
			t.ok(string.find(handler, "isPrivate = true", 1, true) ~= nil)
			t.ok(string.find(handler, "code = nil", 1, true) ~= nil)
			t.ok(string.find(src, "if room.practiceMapId then\n\t\tlaunch = nil", 1, true) ~= nil)
			local endMatch = body(src, "function RoomService.endMatch(")
			t.ok(string.find(endMatch, "closeRoom(room)", 1, true) ~= nil)
		end
	)

	t.test("Remotes·화면: StartPractice 리모트, 로비 연습 버튼", function()
		local remotes = fs.readFile("src/shared/Remotes.luau")
		local functions = string.match(remotes, "local FUNCTIONS = (%b{})") :: string
		t.ok(string.find(functions, '"StartPractice"', 1, true) ~= nil)
		local controller = fs.readFile("src/client/ui/LobbyController.luau")
		t.ok(string.find(controller, 'request("StartPractice", mapId)', 1, true) ~= nil)
		local hud = fs.readFile("src/client/ui/HudScreen.luau")
		t.ok(string.find(hud, 'Loc.t("hud.practice")', 1, true) ~= nil)
	end)
end
