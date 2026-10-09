--!strict
-- m4-12 출시 점검: 잡기 입력 상태(G1·G4), 장애물 소리 기록(B3), 연속 5판 순수 시뮬레이션(상태가 쌓이지 않음),
-- 서버·클라이언트 모듈 전역 표의 정리 경로 점검, 남은 P3 수정(소개 카메라·노렌·바닥 턱·칼·저장 종료),
-- 타입 검사 도구 고정과 커밋용 디버그 값.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local GrabInputLogic = RobloxRequire.require(Shared.GrabInputLogic)
local GrabLogic = RobloxRequire.require(Shared.GrabLogic)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapSfxLogic = RobloxRequire.require(Shared.maps.MapSfxLogic)
local Maps = RobloxRequire.require(Shared.maps)
local RewardLogic = RobloxRequire.require(Shared.RewardLogic)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Rules = RobloxRequire.require(Shared.Rules)

local ART = {
	["rotating-belt"] = RobloxRequire.require(Shared.maps.RotatingBeltArt),
	["soy-swamp"] = RobloxRequire.require(Shared.maps.SoySwampArt),
}
local HotPlateArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local HotPlateLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local SkewerArt = RobloxRequire.require(Shared.maps.SkewerShowdownArt)

local function read(path: string): string
	return fs.readFile(path)
end

local function has(path: string, text: string): boolean
	return string.find(read(path), text, 1, true) ~= nil
end

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local GAP = Config.Grab.InputMinInterval + GrabInputLogic.MARGIN

-- 시드 고정 rng (Random:NextInteger·NextNumber와 같은 모양)
local function seededRng(seed: number): any
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self: any): number
			return step()
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1))
		end,
	}
end

return function(t: Test.Test)
	----------------------------------------------------------------------------
	-- AC2: 잡기 입력 상태 (m3-07 QA G1·G4)

	t.test("AC2: 터치 누름 + 마우스 뗌 → 잡기 유지, 둘 다 떼면 놓음", function()
		local s = GrabInputLogic.new(Config.Grab.InputMinInterval)
		local sends = GrabInputLogic.set(s, "touch", true, 10)
		t.eq(sends, { true }, "first press sent")
		sends = GrabInputLogic.set(s, "mouse", true, 10.5)
		t.eq(sends, {}, "already holding")
		sends = GrabInputLogic.set(s, "mouse", false, 11)
		t.eq(sends, {}, "touch still down: keep holding")
		t.ok(GrabInputLogic.isHolding(s), "holding")
		sends = GrabInputLogic.set(s, "touch", false, 11.2)
		t.eq(sends, { false }, "both up: release")
		t.ok(not GrabInputLogic.isHolding(s), "released")
	end)

	t.test("AC2: 0.05초 안에 뗌→누름이면 간격 뒤에 마지막 누름이 한 번 보내져요", function()
		local s = GrabInputLogic.new(Config.Grab.InputMinInterval)
		local all: { boolean } = {}
		local function push(values: { boolean })
			for _, v in values do
				table.insert(all, v)
			end
		end
		local sends, at = GrabInputLogic.set(s, "mouse", true, 0)
		push(sends)
		t.eq(at, nil, "no schedule on first press")
		push((GrabInputLogic.set(s, "mouse", false, 0.02)))
		sends, at = GrabInputLogic.set(s, "mouse", true, 0.05)
		push(sends)
		t.eq(sends, {}, "too early: not sent now")
		t.ok(at ~= nil and math.abs((at :: number) - GAP) < 1e-9, `scheduled at {at}`)
		t.eq(GrabInputLogic.flush(s, 0.08), {}, "before schedule: nothing")
		push(GrabInputLogic.flush(s, GAP))
		t.eq(all, { true, false, true }, "press, release, then the last press once")
		t.eq(GrabInputLogic.flush(s, GAP + 1), {}, "only once")
		-- 서버 간격 제한(InputMinInterval)보다 두 누름 간격이 길어요
		t.ok(GAP > Config.Grab.InputMinInterval, "margin over server limit")
	end)

	t.test("AC2: 예약 시각 전에 다시 떼면 아무것도 안 보내요", function()
		local s = GrabInputLogic.new(Config.Grab.InputMinInterval)
		GrabInputLogic.set(s, "gamepad", true, 0)
		GrabInputLogic.set(s, "gamepad", false, 0.01)
		local sends, at = GrabInputLogic.set(s, "gamepad", true, 0.03)
		t.eq(sends, {}, "scheduled")
		t.ok(at ~= nil, "has schedule")
		t.eq((GrabInputLogic.set(s, "gamepad", false, 0.06)), {}, "never sent true, nothing to release")
		t.eq(GrabInputLogic.flush(s, 1), {}, "nothing at schedule")
		t.ok(not s.sent, "server thinks released")
	end)

	t.test(
		"AC2: cancel(다이브 등)은 모든 입력원을 떼고, 계속 누르고 있어도 다시 눌러야 잡아요",
		function()
			local s = GrabInputLogic.new(Config.Grab.InputMinInterval)
			GrabInputLogic.set(s, "touch", true, 0)
			GrabInputLogic.set(s, "mouse", true, 0)
			t.eq(GrabInputLogic.cancel(s), { false }, "release sent")
			t.eq(GrabInputLogic.cancel(s), {}, "second cancel: nothing")
			t.eq((GrabInputLogic.set(s, "mouse", false, 0.5)), {}, "late mouse up ignored")
			t.eq((GrabInputLogic.set(s, "touch", true, 1)), { true }, "new press works")
		end
	)

	t.test("AC2: GrabController가 입력원별 상태와 예약 재전송을 써요", function()
		local path = "src/client/input/GrabController.luau"
		t.ok(has(path, "GrabInputLogic.set(inputState, source, down, os.clock())"), "set per source")
		t.ok(has(path, "GrabInputLogic.flush(inputState, os.clock())"), "flush on schedule")
		t.ok(has(path, 'setSource("touch", isHolding)'), "touch button is its own source")
		t.ok(has(path, 'return "mouse"') and has(path, 'return "gamepad"'), "mouse / gamepad sources")
		t.ok(not has(path, "local holding = false"), "no shared holding flag")
	end)

	----------------------------------------------------------------------------
	-- AC3: 장애물 소리 기록 (m3-09 QA B3)

	t.test("AC3: MapSfx 간격 기록은 약한 키 표이고, 정리 뒤 비어요", function()
		local limiter = MapSfxLogic.newLimiter()
		local meta = getmetatable(limiter.last :: any)
		t.ok(meta ~= nil and meta.__mode == "k", "weak keys")
		local parts = {}
		for i = 1, 20 do
			parts[i] = { name = `part{i}` }
			t.ok(MapSfxLogic.allow(limiter, parts[i], "ChefHandWarn", 0), "first play")
		end
		t.eq(MapSfxLogic.size(limiter), 20)
		MapSfxLogic.allow(limiter, "other", "ChefHandWarn", MapSfxLogic.PRUNE_EVERY + 1)
		t.eq(MapSfxLogic.size(limiter), 1, "old parts pruned on the next call")
		t.ok(has("src/shared/maps/MapSfx.luau", "local limiter = MapSfxLogic.newLimiter()"), "MapSfx uses it")
	end)

	----------------------------------------------------------------------------
	-- 연속 매치 안정성 (순수 시뮬레이션)

	-- MatchService.runMatch의 라운드 진행을 순수 함수로 따라가요. 레이서는 무작위로 통과·낙하·리셋.
	local function simulateMatch(rng: any, entries: { { userId: number, name: string } }, plan: { Rules.MapInfo }?)
		local alive: { [number]: boolean } = {}
		for _, e in entries do
			alive[e.userId] = true
		end
		local function aliveList(): { number }
			local list = {}
			for _, e in entries do
				if alive[e.userId] then
					table.insert(list, e.userId)
				end
			end
			return list
		end
		local standings = RoundLogic.newStandings(entries)
		local tracker = RewardLogic.newTracker()
		local forced = plan ~= nil
		local roundCount = if plan then #plan else Rules.roundCount(#entries)
		local thePlan: { Rules.MapInfo } = plan or Rules.buildRoundPlan(roundCount, Maps.infos(), rng)
		local played: { string } = {}
		local minAlive = if forced then 1 else 2
		local index: number? = 1
		local rounds = 0
		while index and #aliveList() >= minAlive do
			if not forced then
				index = Rules.roundToPlay(index :: number, roundCount, #aliveList())
			end
			local i = index :: number
			local info = thePlan[i]
			table.insert(played, info.id)
			local ids = aliveList()
			local round = RoundLogic.newRound(RoundLogic.modeFor(info.kind, i == roundCount), ids, rng)
			RoundLogic.activate(round, Rules.qualifyCount(#ids, roundCount, i))
			RewardLogic.onRoundStart(tracker, i, roundCount, ids)
			local scores: { [number]: number } = {}
			local function scoreOf(userId: number): number
				return scores[userId] or 0
			end
			local function apply(outcomes: { RoundLogic.Outcome })
				for _, outcome in RoundLogic.applyOutcomes(standings, outcomes) do
					RewardLogic.onResult(tracker, outcome.userId, outcome.result)
					if outcome.result == "Eliminated" then
						alive[outcome.userId] = nil
					end
				end
			end
			local ticks = 0
			while not round.ended and ticks < 40 do
				ticks += 1
				local racers = RoundLogic.racers(round)
				if #racers == 0 then
					break
				end
				for _, id in racers do
					scores[id] = rng:NextNumber() * 100
				end
				local who = racers[rng:NextInteger(1, #racers)]
				local roll = rng:NextNumber()
				if round.mode == "Race" and roll < 0.5 then
					apply(RoundLogic.pass(round, who, scoreOf))
				elseif roll < 0.9 then
					apply(RoundLogic.eliminate(round, { { userId = who, score = scoreOf(who) } }, scoreOf))
				else
					apply(RoundLogic.eliminate(round, { { userId = who, score = 0, cause = "Reset" } }, scoreOf))
				end
			end
			if not round.ended then
				apply(RoundLogic.timeout(round, scoreOf))
			end
			t.ok(round.ended, `round {i} ended`)
			rounds += 1
			if not forced and i < roundCount and #aliveList() <= 1 then
				break
			end
			if forced then
				index = if i < roundCount then i + 1 else nil
			else
				index = Rules.nextRound(i, roundCount, #aliveList())
			end
		end
		local winner, needsWon = RoundLogic.decideWinner(standings, aliveList())
		if winner and needsWon then
			RoundLogic.placeWinner(standings, winner)
		end
		return played, RoundLogic.standingsList(standings), winner, rounds
	end

	-- Studio 연속 5판 확인과 같은 강제 플랜 (맵 풀이 모두 한 번 이상, 마지막은 결승)
	local FORCED_PLANS = {
		{ "rotating-belt", "hot-plate", "skewer-showdown" },
		{ "soy-swamp", "chef-board", "skewer-showdown" },
		{ "ramen-rapids", "hot-plate", "rotating-belt", "skewer-showdown" },
		{ "soy-swamp", "ramen-rapids", "chef-board", "skewer-showdown" },
		{ "bouncy-castle-maze", "soy-swamp", "skewer-showdown" },
	}

	t.test("연속 5판: 강제 플랜 5개가 유효하고 6개 맵을 모두 한 번 이상 써요", function()
		local seen: { [string]: boolean } = {}
		for n, ids in FORCED_PLANS do
			local plan, problem = Rules.resolveForcedPlan(ids, Maps.infos())
			t.ok(plan ~= nil, `plan {n}: {problem}`)
			for _, id in ids do
				seen[id] = true
			end
		end
		for _, info in Maps.infos() do
			t.ok(seen[info.id], `map {info.id} in the 5-match plan`)
		end
	end)

	t.test(
		"연속 5판: 같은 서버 상태(방·잡기 기록·소리 기록)가 판마다 쌓이지 않아요",
		function()
			local rng = seededRng(1204)
			local book = GrabLogic.newBook()
			local limiter = MapSfxLogic.newLimiter()
			local clock = 0
			local nextUserId = 1
			local sizesAfter: { number } = {}
			for matchNo = 1, 10 do
				-- 판마다 새 손님 4~12명 (앞 판 손님은 나가요)
				local size = rng:NextInteger(4, 12)
				local entries = {}
				for _ = 1, size do
					table.insert(entries, { userId = nextUserId, name = `p{nextUserId}` })
					nextUserId += 1
				end
				local host = entries[1]
				local room = RoomLogic.newRoom(
					{ id = `room{matchNo}`, name = "방", maxPlayers = 24, isPrivate = false, code = nil, slot = 1 } :: any,
					{ userId = host.userId, name = host.name } :: any
				)
				for k = 2, #entries do
					RoomLogic.addMember(room, { userId = entries[k].userId, name = entries[k].name } :: any)
				end
				t.eq(#room.members, size, "room filled")

				local planIds = FORCED_PLANS[(matchNo - 1) % #FORCED_PLANS + 1]
				local plan = if matchNo <= 5 then Rules.resolveForcedPlan(planIds, Maps.infos()) else nil
				local played, standings, winner = simulateMatch(rng, entries, plan)
				if plan then
					t.eq(played, planIds, `match {matchNo} played the forced plan`)
				end

				-- 순위표: 참가자 전원, 등수 1..N 한 번씩, 우승자는 1등
				t.eq(#standings, size, "everyone ranked")
				local places: { [number]: boolean } = {}
				for _, row in standings do
					t.ok(not places[row.place], `unique place {row.place}`)
					places[row.place] = true
				end
				for p = 1, size do
					t.ok(places[p], `place {p} used`)
				end
				if winner then
					t.eq(standings[1].userId, winner, "winner is first")
				end

				-- 판 도중 잡기·장애물 소리 (맵 파트는 판마다 새로 만들어요)
				local parts = {}
				for k = 1, 8 do
					parts[k] = { matchNo = matchNo, k = k }
				end
				for _ = 1, 30 do
					clock += 0.05
					local a = entries[rng:NextInteger(1, size)].userId
					local b = entries[rng:NextInteger(1, size)].userId
					if a ~= b and GrabLogic.canStart(book, a, clock) then
						GrabLogic.begin(book, a, b, clock)
					end
					local grab = GrabLogic.grabOf(book, b)
					if grab and rng:NextNumber() < 0.5 then
						GrabLogic.finish(book, b, clock, Config.Grab)
					end
					MapSfxLogic.allow(limiter, parts[rng:NextInteger(1, #parts)], "SkewerWhoosh", clock)
				end

				-- 매치 끝: 손님이 모두 나가요 (방에서·서버에서)
				clock += 5
				for _, e in entries do
					RoomLogic.removeMember(room, e.userId)
					GrabLogic.removePlayer(book, e.userId, clock, Config.Grab)
				end
				t.eq(#room.members, 0, "room empty")
				table.clear(parts)
				MapSfxLogic.allow(limiter, "tick", "Probe", clock)
				table.insert(
					sizesAfter,
					count(book.grabs) + count(book.grabbedBy) + count(book.cooldownUntil) + count(book.immuneUntil)
				)
				t.ok(MapSfxLogic.size(limiter) <= 1, `sfx limiter pruned after match {matchNo}`)
			end
			for i, n in sizesAfter do
				t.eq(n, 0, `grab book empty after match {i}`)
			end
		end
	)

	t.test("연속 5판: forceMapPlans는 매치마다 다음 플랜을 써요 (Studio 전용)", function()
		local match = read("src/server/MatchService.luau")
		local studioAt = string.find(match, "if not RunService:IsStudio() then", 1, true)
		local rotateAt = string.find(match, "ids = rotation[forcedPlanTurn % #rotation + 1]", 1, true)
		t.ok(studioAt ~= nil and rotateAt ~= nil and studioAt < rotateAt, "studio guard before rotation")
		t.ok(string.find(match, "if ids == nil and rotation ~= nil", 1, true) ~= nil, "forceMapPlan wins")
	end)

	t.test("연속 매치: 서버 모듈 전역 표마다 지우는 곳이 있어요 (누수 점검)", function()
		-- 키가 플레이어·방·인스턴스인 모듈 전역 표. 크기가 정해진 표(소리 이름·경고 키)와 약한 키 표는 빼요.
		local bounded: { [string]: boolean } = {
			["src/client/Sfx.luau:warned"] = true, -- 소리 이름별 한 번 경고
			["src/client/Sfx.luau:lastPlayed"] = true, -- 소리 이름별 시각
			["src/client/Sfx.luau:hookedButtons"] = true, -- 약한 키
			["src/server/RoomDirectory.luau:lastWarnAt"] = true, -- 경고 종류별
			["src/server/RoomService.luau:handlers"] = true, -- 리모트 이름별 고정
			["src/server/DataService.luau:userBusy"] = true, -- finishUser가 0이면 nil로
			["src/server/PurchaseLog.luau:memory"] = true, -- Studio 메모리 구매 기록 (결제당 한 줄, m4-14)
			["src/client/PriceCache.luau:prices"] = true, -- 상품·패스 id별 가격 (카탈로그 크기, m5-03)
			["src/client/PriceCache.luau:requested"] = true, -- 상품·패스 id별 한 번 (m5-03)
		}
		local files = {}
		for _, dir in { "src/server", "src/client", "src/client/fx", "src/client/input", "src/client/ui" } do
			for _, name in fs.readDir(dir) do
				if string.sub(name, -5) == ".luau" then
					table.insert(files, `{dir}/{name}`)
				end
			end
		end
		local checked = 0
		for _, path in files do
			local source = read(path)
			for name in string.gmatch(source, "\nlocal ([%w_]+): { %[[%w_]+%]: [^\n]-} = [%w(]*{") do
				local key = `{path}:{name}`
				if bounded[key] then
					continue
				end
				checked += 1
				local cleared = string.find(source, name .. "%[[^%]\n]+%] = nil") ~= nil
					or string.find(source, "table.clear(" .. name .. ")", 1, true) ~= nil
					or string.find(source, name .. "%[[^%]\n]+%] = if ") ~= nil
				t.ok(cleared, `{key} has a removal path`)
			end
		end
		t.ok(checked >= 20, `checked {checked} tables`)
	end)

	t.test(
		"연속 매치: 매치 끝 디버그 통계(logArenaStats)가 맵 Model·훅·메모리를 찍어요",
		function()
			t.eq(Config.DEBUG.logArenaStats, false, "off by default")
			local match = read("src/server/MatchService.luau")
			t.ok(string.find(match, "if not Config.DEBUG.logArenaStats then", 1, true) ~= nil, "guarded")
			t.ok(string.find(match, "child:GetAttribute(Attributes.RoomId) ~= nil", 1, true) ~= nil, "arena models")
			t.ok(string.find(match, "RoundService.debugHookCount()", 1, true) ~= nil, "round hooks")
			t.ok(string.find(match, "GetTotalMemoryUsageMb()", 1, true) ~= nil, "memory")
			local finishAt = string.find(match, "local function finish(", 1, true)
			local logAt = string.find(match, "\tlogArenaStats(roomId)", 1, true)
			t.ok(
				finishAt ~= nil and logAt ~= nil and logAt > finishAt,
				"logged from finish (both normal and crash path)"
			)
			t.ok(has("src/server/RoundService.luau", "function RoundService.debugHookCount(): number"), "hook count")
		end
	)

	----------------------------------------------------------------------------
	-- 남은 P3

	t.test(
		"m4-02 Q1: 회전 벨트·간장 늪 소개 카메라 경로(경유점 사이)가 장식 속을 지나가지 않아요",
		function()
			for id, art in ART do
				local path = {}
				for _, point in art.introCamera() do
					table.insert(path, { position = point.pos, lookAt = point.lookAt })
				end
				local boxes = {}
				for _, spec in art.decor() do
					table.insert(boxes, { name = spec.name, b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds })
				end
				local hits: { [string]: boolean } = {}
				local steps = 2000
				for s = 0, steps do
					local p = IntroCameraLogic.sample(path, s / steps).position
					for _, entry in boxes do
						local b = entry.b
						if
							p.x > b.min.x
							and p.x < b.max.x
							and p.y > b.min.y
							and p.y < b.max.y
							and p.z > b.min.z
							and p.z < b.max.z
						then
							hits[entry.name] = true
						end
					end
				end
				for name in hits do
					t.ok(false, `{id}: intro path passes through decor {name}`)
				end
			end
		end
	)

	t.test("m4-02 Q2: 회전 벨트 노렌은 바닥 위 15 이상이에요", function()
		local found = 0
		for _, spec in ART["rotating-belt"].decor() do
			if spec.name == "Noren" or spec.name == "NorenMark" or spec.name == "GateBeam" then
				found += 1
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				t.ok(b.min.y >= 15, `{spec.name} bottom {b.min.y}`)
			end
		end
		t.ok(found >= 9, "noren, marks and beam found")
	end)

	t.test("m4-03 B3: 철판 테두리·꼬치 무대 테두리 윗면이 바닥보다 높지 않아요", function()
		local frames = 0
		for _, spec in HotPlateArt.decor() do
			if spec.name == "Frame" then
				frames += 1
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				local onLayer = false
				for layer = 1, HotPlateLogic.LAYER_COUNT do
					if math.abs(b.max.y - HotPlateLogic.layerTopY(layer)) < 1e-6 then
						onLayer = true
					end
				end
				t.ok(onLayer, `Frame top {b.max.y} flush with a layer top`)
			end
		end
		t.ok(frames > 0, "frames found")
		local lips = 0
		for i = 1, 6 do
			for _, spec in SkewerArt.sliceDecor(i) do
				if spec.name == "RimLip" then
					lips += 1
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					t.ok(b.max.y <= 1e-6, `RimLip top {b.max.y} not above the stage`)
				end
			end
		end
		t.ok(lips > 0, "rim lips found")
	end)

	t.test(
		"m4-05 C2·C3: 칼은 지금 기울기를 따라 내려치고, 도마 가운데 위로 올라가요",
		function()
			local path = "src/shared/maps/ChefBoard.luau"
			t.ok(has(path, "to: CFrame | () -> CFrame"), "movePivot follows a moving goal")
			t.ok(has(path, "return origin * currentTilt * lineRel * CFrame.new(0, KNIFE_STRIKE_HEIGHT, 0)"), "slam")
			t.ok(
				has(path, "return origin * currentTilt * CFrame.new(0, KNIFE_REST_HEIGHT, 0) * lineRel.Rotation"),
				"lift to center"
			)
			t.ok(not has(path, "origin * lineRel * CFrame.new(0, KNIFE_REST_HEIGHT, 0)"), "old rest over the line gone")
		end
	)

	t.test("m4-07 D5: 서버 종료 때 로드 중인 사람도 기다려요", function()
		t.ok(
			has(
				"src/server/DataService.luau",
				"while (next(saving) ~= nil or next(loading) ~= nil) and os.clock() < deadline do"
			),
			"onClose waits for loading"
		)
	end)

	----------------------------------------------------------------------------
	-- 타입 검사 (m2-07 I2) · 커밋 값

	t.test("타입 검사: luau-lsp 버전 고정과 Roblox 정의 파일이 있어요", function()
		local rokit = read("rokit.toml")
		local version = string.match(rokit, 'luau%-lsp = "JohnnyMorganz/luau%-lsp@([%d%.]+)"')
		t.ok(version ~= nil, "luau-lsp pinned in rokit.toml")
		t.ok(fs.isFile("types/globalTypes.None.d.luau"), "definitions committed")
		t.ok(has("types/README.md", `태그 \`{version}\``), "definitions tag matches the pinned version")
		t.ok(has("types/README.md", "--flag:LuauSolverV2=true"), "command documented")
	end)

	t.test("커밋 값: 디버그 설정이 기본값이에요", function()
		t.eq(Config.DEBUG.forceMapPlan, nil, "forceMapPlan")
		t.eq(Config.DEBUG.forceMapPlans, nil, "forceMapPlans")
		t.eq(Config.DEBUG.simulateMatchServer, false, "simulateMatchServer")
		t.eq(Config.DEBUG.persistDataInStudio, false, "persistDataInStudio")
		t.eq(Config.DEBUG.logArenaStats, false, "logArenaStats")
	end)
end
