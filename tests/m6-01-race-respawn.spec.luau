--!strict
-- m6-01 Race 부활: 정원이 차기 전 낙하·리셋은 탈락 대신 출발점 부활 + 화면 카운트다운 (GDD 4)

local fs = require("@lune/fs")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local RespawnCountdownLogic = RobloxRequire.require(Shared.RespawnCountdownLogic)

local function progress(scores: { [number]: number }): (number) -> number
	return function(userId: number): number
		return scores[userId] or 0
	end
end

return function(t: Test.Test)
	t.test("Config: 부활 켜짐, 3초", function()
		t.eq(Config.Race.Respawn, true)
		t.eq(Config.Race.RespawnDelay, 3)
	end)

	t.test("respawns: 결승이 아닌 Race 라운드에서 아직 달리는 사람만", function()
		local race = RoundLogic.newRound(RoundLogic.modeFor("Race", false), { 1, 2, 3, 4 })
		RoundLogic.activate(race, 2)
		t.eq(RoundLogic.respawns(race, 1, true), true)
		t.eq(RoundLogic.respawns(race, 1, false), false) -- Config.Race.Respawn = false면 예전처럼 탈락
		t.eq(RoundLogic.respawns(race, 99, true), false) -- 레이서가 아님

		local survival = RoundLogic.newRound(RoundLogic.modeFor("Survival", false), { 1, 2, 3 })
		RoundLogic.activate(survival, 2)
		t.eq(RoundLogic.respawns(survival, 1, true), false)

		-- Race 맵이 마지막 라운드(디버그 강제 플랜)면 결승 방식이라 부활 없어요
		local final = RoundLogic.newRound(RoundLogic.modeFor("Race", true), { 1, 2 })
		RoundLogic.activate(final, 1)
		t.eq(RoundLogic.respawns(final, 1, true), false)
	end)

	t.test("respawns: 소개 중(activate 전)에도 부활, 통과한 사람은 아님", function()
		local race = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
		t.eq(RoundLogic.respawns(race, 1, true), true)
		RoundLogic.activate(race, 3)
		RoundLogic.pass(race, 1, progress({}))
		t.eq(RoundLogic.respawns(race, 1, true), false)
		t.eq(RoundLogic.respawns(race, 2, true), true)
	end)

	t.test(
		"정원이 차는 순간 끝: 부활 대기자 포함 남은 사람 탈락, 그 뒤엔 부활 없음",
		function()
			local race = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(race, 2)
			local scores = progress({ [3] = 50, [4] = 10 })
			t.eq(#RoundLogic.pass(race, 1, scores), 1)
			local outcomes = RoundLogic.pass(race, 2, scores)
			t.eq(race.ended, true)
			local eliminated = {}
			for _, outcome in outcomes do
				if outcome.result == "Eliminated" then
					table.insert(eliminated, outcome.userId)
				end
			end
			table.sort(eliminated)
			t.eq(eliminated, { 3, 4 })
			t.eq(RoundLogic.respawns(race, 3, true), false)
		end
	)

	t.test("countdown: 남은 초를 올림, 지나면 1에서 멈춤, 속성 없으면 숨김", function()
		t.eq(RespawnCountdownLogic.secondsLeft(nil, 100), nil)
		t.eq(RespawnCountdownLogic.secondsLeft("3", 100), nil)
		t.eq(RespawnCountdownLogic.secondsLeft(0 / 0, 100), nil)
		t.eq(RespawnCountdownLogic.secondsLeft(103, 100), 3)
		t.eq(RespawnCountdownLogic.secondsLeft(103, 100.01), 3)
		t.eq(RespawnCountdownLogic.secondsLeft(103, 101), 2)
		t.eq(RespawnCountdownLogic.secondsLeft(103, 102.5), 1)
		t.eq(RespawnCountdownLogic.secondsLeft(103, 104), 1)
	end)

	t.test("RoundService 계약: 부활 분기·강제 탈락·레이서 질의에서 빠짐", function()
		local src = fs.readFile("src/server/RoundService.luau")
		local queueFall = string.match(src, "local function queueFall.-\n\t\tend\n") :: string
		t.ok(queueFall ~= nil, "queueFall found")
		t.ok(
			string.find(queueFall, "RoundLogic.respawns(round, userId, respawnEnabled)", 1, true) ~= nil,
			"부활 판단"
		)
		t.ok(string.find(queueFall, "not force", 1, true) ~= nil, "force면 부활 안 함")
		t.ok(string.find(src, "Config.Race.RespawnDelay", 1, true) ~= nil, "Config 지연 사용")
		t.ok(
			string.find(src, "SetAttribute(Attributes.RespawnAt, respawnAt)", 1, true) ~= nil,
			"카운트다운 속성"
		)
		t.ok(string.find(src, "SetAttribute(Attributes.RespawnAt, nil)", 1, true) ~= nil, "카운트다운 지움")

		-- 방·게임을 나간 사람과 캐릭터가 안 생긴 사람은 부활 없이 탈락 (force = true)
		local remover = string.match(src, "activeRemovers%[roomId%] = function.-\n\t\tend\n") :: string
		t.ok(remover ~= nil, "remover found")
		t.ok(string.find(remover, '"Reset", nil, nil, true)', 1, true) ~= nil, "나간 사람 강제 탈락")
		local placeAt = string.match(src, "local function placeAt.-\n\t\tend\n") :: string
		t.ok(string.find(placeAt, '"Reset", nil, nil, true)', 1, true) ~= nil, "캐릭터 없음 강제 탈락")

		-- 부활 대기 중에는 맵(getRacers)·잡기(activeRacing)·이동 감시(placedRacing)·낙하 판정에서 빠져요
		local _, excluded = string.gsub(src, "not respawning%[userId%]", "")
		t.ok(excluded >= 5, `respawning 제외 {excluded}곳`)
		t.ok(
			string.find(src, "placed[player.UserId] and not respawning[player.UserId]", 1, true) ~= nil,
			"eliminate 무시"
		)
	end)

	t.test("클라이언트: HUD가 카운트다운을 켜고, 문구는 키로", function()
		local hud = fs.readFile("src/client/ui/HudController.luau")
		t.ok(string.find(hud, "RespawnCountdown.start(gui)", 1, true) ~= nil, "HUD에서 시작")
		local ui = fs.readFile("src/client/ui/RespawnCountdown.luau")
		t.ok(string.find(ui, 'Loc.t("hud.respawn.title")', 1, true) ~= nil, "title key")
		t.ok(string.find(ui, 'Loc.t("hud.respawn.sub")', 1, true) ~= nil, "sub key")
		t.ok(string.find(ui, "RespawnCountdownLogic.secondsLeft(", 1, true) ~= nil, "순수 로직 사용")
	end)
end
