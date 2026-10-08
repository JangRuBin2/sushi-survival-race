--!strict
-- m3-09 QA: 장애물 소리 간격 제한 경계값, 꼬치 가속 소리 횟수, Timeout 연출 종류, 결승 우승 발표 지연과
-- 우승자 판정(Won 받은 사람만), 잡기 규칙 경계, 공중 다이브 vy 상한 경계, 좁은 화면 음소거 버튼 배치 계산,
-- MapSfx 리모트가 서버→클라이언트 전용인지 정적 확인.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapSfxLogic = RobloxRequire.require(Shared.maps.MapSfxLogic)
local SkewerLogic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)
local CutsceneLogic = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local GrabLogic = RobloxRequire.require(Shared.GrabLogic)
local DiveLogic = RobloxRequire.require(Shared.DiveLogic)

local function stripComments(source: string): string
	local noBlock = string.gsub(source, "%-%-%[%[.-%]%]", "")
	return (string.gsub(noBlock, "%-%-[^\n]*", ""))
end

local function listLuau(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			listLuau(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

local function launchInput(vy: number, grounded: boolean): any
	return {
		moveX = 0,
		moveZ = 0,
		lookX = 0,
		lookZ = -1,
		walkSpeed = Config.Character.WalkSpeed,
		grounded = grounded,
		vy = vy,
		jumpPower = Config.Character.JumpPower,
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- MapSfxLogic 경계값
	t.test("MapSfxLogic: 부동소수점으로 쌓인 0.2초(0.1 + 0.1)도 허용", function()
		local limiter = MapSfxLogic.newLimiter()
		local part = {}
		local start = 1234.7
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", start), true)
		t.eq(MapSfxLogic.allow(limiter, part, "TileVanish", start + 0.1 + 0.1), true)
	end)

	t.test("MapSfxLogic: 정리(prune)가 아직 간격 안의 기록은 지우지 않아요", function()
		local limiter = MapSfxLogic.newLimiter()
		local part = {}
		t.eq(MapSfxLogic.allow(limiter, part, "SoySlow", 0.95), true)
		-- 1.05초에 다른 키 호출로 정리가 돌아도 0.1초 전 기록은 남아요
		t.eq(MapSfxLogic.allow(limiter, "other", "SoySlow", 1.05), true)
		t.eq(MapSfxLogic.allow(limiter, part, "SoySlow", 1.06), false)
		t.eq(MapSfxLogic.allow(limiter, part, "SoySlow", 1.15), true)
	end)

	t.test("MapSfxLogic: 더 긴 gap을 쓰면 정리도 그 gap 기준이에요", function()
		local limiter = MapSfxLogic.newLimiter()
		t.eq(MapSfxLogic.allow(limiter, "a", "SkewerWhoosh", 0, 0.5), true)
		t.eq(MapSfxLogic.allow(limiter, "b", "SkewerWhoosh", 1.0), true) -- 정리 (a는 1초 지나 지워져도 됨)
		t.eq(MapSfxLogic.allow(limiter, "c", "SkewerWhoosh", 2.2, 0.5), true)
		t.eq(MapSfxLogic.allow(limiter, "d", "SkewerWhoosh", 3.3), true) -- 정리: c(1.1초 전)는 지워짐
		t.eq(MapSfxLogic.allow(limiter, "c", "SkewerWhoosh", 3.31, 0.5), true)
		t.eq(MapSfxLogic.allow(limiter, "c", "SkewerWhoosh", 3.5, 0.5), false)
	end)

	t.test("MapSfxLogic.MIN_INTERVAL은 Config.Fx.MapSfxMinInterval", function()
		t.eq(MapSfxLogic.MIN_INTERVAL, Config.Fx.MapSfxMinInterval)
	end)

	---------------------------------------------------------------- 꼬치 가속 소리
	t.test("꼬치 가속 휙: 60fps로 90초 돌리면 정확히 6번 (10·20·…·60초)", function()
		local marks = MapSfxLogic.marks(SkewerLogic.HIGH_SKEWER_AT, SkewerLogic.SUDDEN_DEATH_AT, 10)
		local count = 0
		local last = 0
		local elapsed = 0
		for _ = 1, 90 * 60 do
			elapsed += 1 / 60
			if MapSfxLogic.crossedMark(last, elapsed, marks) then
				count += 1
			end
			last = elapsed
		end
		t.eq(count, 6)
	end)

	t.test(
		"꼬치 가속 휙: 렉으로 한 프레임에 두 시각을 넘어도 한 번만 (중복 재생 없음)",
		function()
			local marks = MapSfxLogic.marks(10, 60, 10)
			t.eq(MapSfxLogic.crossedMark(9, 21, marks), true)
			t.eq(MapSfxLogic.crossedMark(21, 21.5, marks), false)
		end
	)

	---------------------------------------------------------------- Timeout 연출
	t.test("Timeout 연출 종류: Race·Survival = 젓가락, 결승 = 셰프 손 (결정 기록)", function()
		t.eq(CutsceneLogic.shouldPlay("Timeout"), true)
		t.eq(CutsceneLogic.shouldPlay("Left"), false)
		t.eq(CutsceneLogic.shouldPlay(nil), false)
		t.eq(CutsceneLogic.variantFor("Race", false, "Timeout"), "Chopsticks")
		t.eq(CutsceneLogic.variantFor("Survival", false, "Timeout"), "Chopsticks")
		t.eq(CutsceneLogic.variantFor("Final", true, "Timeout"), "ChefHand")
		t.eq(CutsceneLogic.variantFor("Race", true, "Timeout"), "ChefHand")
	end)

	t.test("동시 재생 한도는 Config.Fx 값 (6)", function()
		t.eq(CutsceneLogic.MAX_CONCURRENT, Config.Fx.EliminationMaxConcurrent)
		t.eq(CutsceneLogic.canStartWorld(Config.Fx.EliminationMaxConcurrent - 1), true)
		t.eq(CutsceneLogic.canStartWorld(Config.Fx.EliminationMaxConcurrent), false)
	end)

	t.test(
		"Race 시간 종료·정원 마감 탈락은 cause 없는 Eliminated로 나와 RoundService가 Timeout을 채워요",
		function()
			-- 시간 종료: 남은 사람 전원 탈락 (낙하 대기열을 거치지 않음 → causeOf 없음 → Timeout)
			local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round, 2)
			local scores = { [1] = 10, [2] = 20, [3] = 30, [4] = 40 }
			local function scoreOf(id: number): number
				return scores[id]
			end
			local passOut = RoundLogic.pass(round, 4, scoreOf)
			t.eq(#passOut, 1)
			local out = RoundLogic.timeout(round, scoreOf)
			-- 시간 종료: 빈 통과 자리는 더 멀리 간 사람(3)으로 채우고 나머지(1, 2)는 탈락
			local eliminated = {}
			for _, o in out do
				if o.result == "Eliminated" then
					table.insert(eliminated, o.userId)
				else
					t.eq(o.userId, 3, "best progress fills the open slot")
				end
			end
			table.sort(eliminated)
			t.eq(eliminated, { 1, 2 }, "timeout eliminates the rest")
			-- 정원 마감: 2명째 통과로 남은 사람이 한 번에 탈락
			local round2 = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
			RoundLogic.activate(round2, 2)
			RoundLogic.pass(round2, 4, scoreOf)
			local out2 = RoundLogic.pass(round2, 3, scoreOf)
			local e2 = 0
			for _, o in out2 do
				if o.result == "Eliminated" then
					e2 += 1
				end
			end
			t.eq(e2, 2, "target reached eliminates the rest")
			-- 서버가 이 경로에 Timeout을 채우는지 (낙하·리셋 사유가 없을 때만)
			local source = fs.readFile("src/server/RoundService.luau")
			t.ok(string.find(source, 'causeOf[userId] or "Timeout"', 1, true) ~= nil)
			-- 방을 나간 사람은 여전히 Left (EliminationService.left)
			t.ok(string.find(source, "EliminationService.left(roomId, userId, place)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 결승 우승 발표 지연과 우승자 판정
	t.test("결승 2명: 마지막 낙하 묶음은 Eliminated + Won이 같이 나와요 (지연 대상)", function()
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, { { userId = 2, score = 0, cause = "Fall" } }, function()
			return 0
		end)
		t.eq(#out, 2)
		t.eq(out[1].result, "Eliminated")
		t.eq(out[1].userId, 2)
		t.eq(out[2].result, "Won")
		t.eq(out[2].userId, 1)
		t.eq(round.ended, true)
	end)

	t.test(
		"우승 발표를 3초 미뤄도 Standings에는 바로 우승자가 기록돼요 (그 사이 우승자가 나가도 우승)",
		function()
			local standings = RoundLogic.newStandings({
				{ userId = 1, name = "A" },
				{ userId = 2, name = "B" },
			})
			local round = RoundLogic.newRound("Final", { 1, 2 })
			RoundLogic.activate(round, 1)
			local out = RoundLogic.eliminate(round, { { userId = 2, score = 0, cause = "Fall" } }, function()
				return 0
			end)
			RoundLogic.applyOutcomes(standings, out)
			-- 지연 중 우승자(1)가 나감: MatchService는 aliveUserIds에서 빼고, placeOf가 있으니 Left를 보내지 않아요
			t.eq(RoundLogic.placeOf(standings, 1), 1)
			t.eq(RoundLogic.placeOf(standings, 2), 2)
			local winner, needsWon = RoundLogic.decideWinner(standings, {})
			t.eq(winner, 1)
			t.eq(needsWon, false, "Won is not sent twice")
		end
	)

	t.test("지연 중 남은 사람(진 사람)이 나가도 우승자는 그대로 (Won 받은 사람만)", function()
		local standings = RoundLogic.newStandings({
			{ userId = 1, name = "A" },
			{ userId = 2, name = "B" },
			{ userId = 3, name = "C" },
		})
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		RoundLogic.applyOutcomes(standings, { { userId = 3, result = "Eliminated" } })
		local out = RoundLogic.eliminate(round, { { userId = 2, score = 0, cause = "Reset" } }, function()
			return 0
		end)
		RoundLogic.applyOutcomes(standings, out)
		local winner, needsWon = RoundLogic.decideWinner(standings, { 1 })
		t.eq(winner, 1)
		t.eq(needsWon, false)
	end)

	t.test(
		"서버 소스: 지연은 출발 뒤 + 방에 남은 탈락자가 있을 때만, Won은 대기 뒤 한 번",
		function()
			local source = stripComments(fs.readFile("src/server/RoundService.luau"))
			local _, wonCount = string.gsub(source, "EliminationService%.won%(", "")
			t.eq(wonCount, 2, "immediate + deferred")
			t.ok(string.find(source, "RoomService.getRoomIdOf(player) == roomId", 1, true) ~= nil)
			t.ok(string.find(source, "delayWon = released", 1, true) ~= nil)
			-- 대기 시간은 탈락 연출 길이
			t.ok(string.find(source, "task.wait(Config.Match.EliminationCutscene)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 잡기 규칙 경계 (G2·G3)
	t.test("잡기 G2: 잡고 있는 A는 못 잡지만, A가 놓으면 바로 잡을 수 있어요", function()
		local cfg = Config.Grab
		local book = GrabLogic.newBook()
		t.eq(GrabLogic.begin(book, 1, 2, 0), true) -- A(1)가 B(2)를 잡음
		t.eq(GrabLogic.begin(book, 3, 1, 0.5), false, "C cannot grab A while A grabs")
		GrabLogic.finish(book, 1, 1, cfg)
		t.eq(GrabLogic.begin(book, 3, 1, 1.01), true, "after release A is a normal target")
		-- 잡힌 B는 면역, 잡고 있는 C도 대상 아님
		t.eq(GrabLogic.begin(book, 4, 2, 1.02), false, "B immune")
		t.eq(GrabLogic.begin(book, 4, 3, 1.02), false, "C is grabbing")
	end)

	t.test("잡기 G2: 잡힌 사람은 잡기 시작 불가 (m3-07 AC5 유지)", function()
		local book = GrabLogic.newBook()
		t.eq(GrabLogic.begin(book, 1, 2, 0), true)
		t.eq(GrabLogic.begin(book, 2, 3, 0), false)
	end)

	---------------------------------------------------------------- 공중 다이브 vy 상한 경계 (m3-06 B1)
	t.test("공중 다이브 vy: 상한 정확히·살짝 넘음·바닥 다이브는 UpSpeed", function()
		local cap = Config.Dive.AirMaxUpSpeed
		t.eq(DiveLogic.launch(launchInput(cap, false)).vy, cap)
		t.eq(DiveLogic.launch(launchInput(cap + 0.001, false)).vy, cap)
		t.eq(DiveLogic.launch(launchInput(cap - 0.001, false)).vy, cap - 0.001)
		t.eq(DiveLogic.launch(launchInput(0, true)).vy, Config.Dive.UpSpeed)
		t.ok(cap <= Config.Character.JumpPower, "cap below jump speed")
	end)

	---------------------------------------------------------------- 좁은 화면 음소거 버튼 (m3-08 B2)
	-- Sfx.luau buildMuteButton(AnchorPoint 1,0), HudScreen 위 가운데 패널(420), LobbyScreen 패널(0.92배, 최대 760, 안쪽 16)
	local function muteSpan(width: number): (number, number)
		if width < Config.Fx.NarrowScreenWidth then
			return width - 4 - 34, width - 4
		end
		return width - 16 - 110, width - 16
	end
	local function hudPanelRight(width: number): number
		return width / 2 + 210
	end
	local function lobbyContentRight(width: number): number
		local panel = math.min(width * 0.92, 760)
		return width / 2 + panel / 2 - 16
	end

	t.test(
		"좁은 화면(560~899px): 아이콘 버튼이 HUD 위 패널·로비 패널 내용과 가로로 안 겹쳐요",
		function()
			for width = 560, Config.Fx.NarrowScreenWidth - 1 do
				local left = muteSpan(width)
				t.ok(left > hudPanelRight(width), `hud overlap at {width}`)
				t.ok(left > lobbyContentRight(width), `lobby overlap at {width}`)
			end
		end
	)

	t.test("넓은 화면(900~2560px): 글자 버튼이 HUD 위 패널과 안 겹쳐요", function()
		for width = Config.Fx.NarrowScreenWidth, 2560 do
			local left = muteSpan(width)
			t.ok(left > hudPanelRight(width), `hud overlap at {width}`)
		end
	end)

	---------------------------------------------------------------- MapSfx 리모트 방향
	t.test("MapSfx: 서버는 OnServerEvent를 듣지 않고, 클라이언트는 FireServer하지 않아요", function()
		local files = {}
		listLuau("src", files)
		for _, path in files do
			local source = stripComments(fs.readFile(path))
			t.eq(string.find(source, 'event%("MapSfx"%)%.OnServerEvent'), nil, `{path} listens MapSfx on server`)
			t.eq(string.find(source, 'event%("MapSfx"%):FireServer'), nil, `{path} fires MapSfx to server`)
		end
		-- 보내는 곳은 MapSfx.luau 한 곳뿐
		local senders = {}
		for _, path in files do
			local source = stripComments(fs.readFile(path))
			if
				string.find(source, 'Remotes.event("MapSfx")', 1, true)
				and string.find(source, "FireAllClients", 1, true)
			then
				table.insert(senders, path)
			end
		end
		t.eq(senders, { "src/shared/maps/MapSfx.luau" })
	end)

	t.test("MapSfx: 서버 전용 가드 (클라이언트에서 불려도 보내지 않음)", function()
		local source = fs.readFile("src/shared/maps/MapSfx.luau")
		t.ok(string.find(source, "RunService:IsServer()", 1, true) ~= nil)
	end)

	t.test("forceMapPlan은 nil (커밋 상태)", function()
		t.eq(Config.DEBUG.forceMapPlan, nil)
	end)
end
