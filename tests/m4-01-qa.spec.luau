--!strict
-- m4-01 QA: 다른 m4 스펙이 기대는 서버/클라이언트 모듈을 가짜 Roblox 환경에서 실제로 돌려 봐요.
--   MatchEvents: 핸들러 에러·대기가 fire(= 매치)를 멈추지 않는지, 해제, 인자 복사.
--   DataService(메모리): 로드·한 프레임 한 번 ProfileUpdated·SaveSettings 검증(타입·범위·간격)·onLoaded·퇴장.
--   ProfileStore: get/changed/Disconnect, 잘못된 값 무시, start 한 번만.
--   RoundLogic 결승 규칙(m2-07 I1 수정): 무작위 묶음에서도 "우승자는 Won을 받은 사람", 리셋은 우승 못 함,
--   결승이 아닌 라운드는 그대로.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)

---------------------------------------------------------------- 가짜 환경 도구

local function newSignal(): any
	local handlers: { any } = {}
	local signal = {}
	function signal:Connect(fn)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, h in table.clone(handlers) do
			if h.connected then
				h.fn(...)
			end
		end
	end
	function signal:count(): number
		local n = 0
		for _, h in handlers do
			if h.connected then
				n += 1
			end
		end
		return n
	end
	return signal
end

-- task.spawn은 바로 실행(코루틴), task.defer는 flush()까지 모아 둬요 (= "프레임 끝").
local function newTask(): any
	local deferred: { any } = {}
	local T = {}
	function T.spawn(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end
	function T.defer(fn, ...)
		table.insert(deferred, { fn = fn, args = table.pack(...) })
	end
	function T.wait(_seconds: number?)
		return coroutine.yield()
	end
	function T.flush()
		while #deferred > 0 do
			local queue = deferred
			deferred = {}
			for _, d in queue do
				T.spawn(d.fn, table.unpack(d.args, 1, d.args.n))
			end
		end
	end
	function T.pending(): number
		return #deferred
	end
	return T
end

-- require(ReplicatedStorage.Shared.X)를 modules[X]로 바꿔 주는 가짜 Shared 폴더
local function sharedFolder(): any
	return setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
end

local function load(path: string, environment: { [string]: any }): any
	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end

local function fakeRequire(modules: { [string]: any }): (any) -> any
	return function(target: any): any
		local name = type(target) == "table" and target.__shared
		assert(name and modules[name] ~= nil, `fake require: {tostring(name)}`)
		return modules[name]
	end
end

---------------------------------------------------------------- MatchEvents

local function loadMatchEvents(): (any, any, { string })
	local T = newTask()
	local warnings: { string } = {}
	local services = { ReplicatedStorage = { Shared = sharedFolder() } }
	local MatchEvents = load("src/server/MatchEvents.luau", {
		game = {
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
		},
		require = fakeRequire({ Types = {} }),
		task = T,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	})
	return MatchEvents, T, warnings
end

---------------------------------------------------------------- DataService

type DataEnv = {
	DataService: any,
	T: any,
	players: any,
	sent: { { player: any, view: any } },
	saveSettings: any,
	warnings: { string },
	setClock: (number) -> (),
	join: (userId: number) -> any,
	leave: (player: any) -> (),
}

local function loadDataService(): DataEnv
	local T = newTask()
	local warnings: { string } = {}
	local clock = 100
	local sent: { { player: any, view: any } } = {}
	local events: { [string]: any } = {}
	local function event(name: string): any
		if events[name] == nil then
			events[name] = {
				OnServerEvent = newSignal(),
				FireClient = function(_, player, payload)
					if name == "ProfileUpdated" then
						table.insert(sent, { player = player, view = payload })
					end
				end,
			}
		end
		return events[name]
	end
	local list: { any } = {}
	local Players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		GetPlayers = function()
			return table.clone(list)
		end,
	}
	-- m4-07 병합: DataService가 DataStore를 쓰게 됐어요. Studio 기본(persistDataInStudio = false) = 메모리 모드로 돌려요.
	local guid = 0
	local services = {
		Players = Players,
		ReplicatedStorage = { Shared = sharedFolder() },
		DataStoreService = {},
		RunService = {
			IsStudio = function()
				return true
			end,
		},
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return `guid-{guid}`
			end,
		},
	}
	local DataService = load("src/server/DataService.luau", {
		game = {
			JobId = "",
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
			BindToClose = function() end,
		},
		require = fakeRequire({
			Config = Config,
			ProfileLogic = ProfileLogic,
			ProfileSchema = ProfileSchema,
			Remotes = { event = event },
		}),
		task = T,
		os = {
			clock = function()
				return clock
			end,
			time = os.time,
		},
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	})
	DataService.init()
	DataService.start()
	local env: DataEnv = {
		DataService = DataService,
		T = T,
		players = Players,
		sent = sent,
		saveSettings = event("SaveSettings"),
		warnings = warnings,
		setClock = function(value: number)
			clock = value
		end,
		join = function(userId: number): any
			local player = { UserId = userId, Name = `P{userId}`, Parent = Players }
			table.insert(list, player)
			Players.PlayerAdded:Fire(player)
			return player
		end,
		leave = function(player: any)
			Players.PlayerRemoving:Fire(player)
			local index = table.find(list, player)
			if index then
				table.remove(list, index)
			end
			player.Parent = nil
		end,
	}
	return env
end

---------------------------------------------------------------- ProfileStore

local function loadProfileStore(): (any, any)
	local T = newTask()
	local clientEvent = { OnClientEvent = newSignal() }
	local services = { ReplicatedStorage = { Shared = sharedFolder() } }
	local ProfileStore = load("src/client/ProfileStore.luau", {
		game = {
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
		},
		require = fakeRequire({
			Types = {},
			Remotes = {
				event = function(name: string)
					assert(name == "ProfileUpdated", name)
					return clientEvent
				end,
			},
		}),
		task = T,
	})
	return ProfileStore, clientEvent
end

---------------------------------------------------------------- RoundLogic 도우미

local function lcg(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end
end

local function noScore(): number
	return 0
end

return function(t: Test.Test)
	-- MatchEvents ---------------------------------------------------------------------------
	t.test("MatchEvents: 핸들러 에러는 경고만, 다른 핸들러와 fire는 계속돼요", function()
		local MatchEvents, _, warnings = loadMatchEvents()
		local got: { string } = {}
		MatchEvents.onMatchStart(function()
			error("boom")
		end)
		MatchEvents.onMatchStart(function(roomId: string, userIds: { number })
			table.insert(got, `{roomId}:{#userIds}`)
		end)
		MatchEvents.fireMatchStart("R1", { 1, 2, 3 })
		t.eq(got, { "R1:3" })
		t.eq(#warnings, 1)
		t.ok(string.find(warnings[1], "MatchStart handler failed", 1, true) ~= nil, warnings[1])
	end)

	t.test("MatchEvents: 기다리는(yield) 핸들러가 fire를 막지 않아요", function()
		local MatchEvents, T = loadMatchEvents()
		local order: { string } = {}
		MatchEvents.onMatchEnd(function()
			table.insert(order, "slow-start")
			T.wait(30) -- 저장 대기 같은 것
			table.insert(order, "slow-end")
		end)
		MatchEvents.onMatchEnd(function()
			table.insert(order, "fast")
		end)
		MatchEvents.fireMatchEnd("R1", { winnerUserId = 1, standings = {}, participants = { 1, 2 } })
		table.insert(order, "after-fire")
		t.eq(order, { "slow-start", "fast", "after-fire" })
	end)

	t.test("MatchEvents: 모든 훅이 해제 함수를 돌려주고, 해제하면 더 안 불려요", function()
		local MatchEvents = loadMatchEvents()
		local calls = 0
		local function bump()
			calls += 1
		end
		local offs = {
			MatchEvents.onMatchStart(bump),
			MatchEvents.onRoundStart(bump),
			MatchEvents.onResult(bump),
			MatchEvents.onMatchEnd(bump),
			MatchEvents.onWinnerShowcase(bump),
		}
		local function fireAll()
			MatchEvents.fireMatchStart("R", { 1 })
			MatchEvents.fireRoundStart("R", 3, 3, { 1 })
			MatchEvents.fireResult("R", { userId = 1, result = "Won", place = 1 })
			MatchEvents.fireMatchEnd("R", { winnerUserId = 1, standings = {}, participants = { 1 } })
			MatchEvents.fireWinnerShowcase({ userId = 1, name = "A", appearanceId = "tamago" })
		end
		fireAll()
		t.eq(calls, 5)
		for _, off in offs do
			t.eq(type(off), "function")
			off()
			off() -- 두 번 불러도 괜찮아요
		end
		fireAll()
		t.eq(calls, 5)
	end)

	t.test("MatchEvents: roundStart 인자 순서, userIds·result는 복사본이에요", function()
		local MatchEvents = loadMatchEvents()
		local seen: any = nil
		MatchEvents.onRoundStart(function(roomId, roundIndex, roundCount, userIds)
			seen = { roomId, roundIndex, roundCount, #userIds }
			table.insert(userIds, 999) -- 핸들러가 고쳐도
		end)
		local ids = { 1, 2 }
		MatchEvents.fireRoundStart("R", 4, 4, ids)
		t.eq(seen, { "R", 4, 4, 2 })
		t.eq(ids, { 1, 2 }, "caller list untouched")

		MatchEvents.onResult(function(_, result)
			result.place = 99
		end)
		local result = { userId = 1, result = "Passed", place = 3 }
		MatchEvents.fireResult("R", result)
		t.eq(result.place, 3, "caller result untouched")
	end)

	t.test("MatchEvents: 핸들러 안에서 구독해도 이번 fire에는 안 불려요 (목록 복사)", function()
		local MatchEvents = loadMatchEvents()
		local late = 0
		MatchEvents.onMatchStart(function()
			MatchEvents.onMatchStart(function()
				late += 1
			end)
		end)
		MatchEvents.fireMatchStart("R", {})
		t.eq(late, 0)
	end)

	-- DataService ---------------------------------------------------------------------------
	t.test(
		"DataService: 접속하면 바로 로드, 프레임 끝에 ProfileUpdated 한 번 (persistent false)",
		function()
			local env = loadDataService()
			local p = env.join(1)
			local profile = env.DataService.get(p)
			t.ok(profile ~= nil, "loaded on PlayerAdded")
			t.eq(profile.coins, 0)
			t.eq(#env.sent, 0, "sent at end of frame, not immediately")
			env.T.flush()
			t.eq(#env.sent, 1)
			t.eq(env.sent[1].player, p)
			t.eq(env.sent[1].view.persistent, false)
			t.eq(env.sent[1].view.ownedSkins, { "tamago" })
			t.eq(env.DataService.canPersist(p), false)
			t.eq(env.DataService.waitForProfile(p, 0), profile)
		end
	)

	t.test(
		"DataService.update: 한 프레임 여러 번 → ProfileUpdated 한 번, 로드 전/모르는 사람은 false",
		function()
			local env = loadDataService()
			local p = env.join(1)
			env.T.flush()
			table.clear(env.sent)
			for _ = 1, 3 do
				t.eq(
					env.DataService.update(p, function(profile)
						profile.coins += 10
					end),
					true
				)
			end
			env.T.flush()
			t.eq(#env.sent, 1, "batched")
			t.eq(env.sent[1].view.coins, 30)
			-- 다음 프레임에 또 바꾸면 또 한 번
			env.DataService.update(p, function(profile)
				profile.wins = 10
			end)
			env.T.flush()
			t.eq(#env.sent, 2)
			t.eq(env.sent[2].view.title, "전설의 참치")
			local stranger = { UserId = 2, Parent = env.players }
			local called = false
			t.eq(
				env.DataService.update(stranger, function()
					called = true
				end),
				false
			)
			t.ok(not called, "mutate not called before load")
		end
	)

	t.test("DataService: 나가면 프로필이 지워지고, 남은 프레임 끝 전송도 안 가요", function()
		local env = loadDataService()
		local p = env.join(1)
		env.T.flush()
		table.clear(env.sent)
		env.DataService.update(p, function(profile)
			profile.coins = 5
		end)
		env.leave(p)
		env.T.flush()
		t.eq(#env.sent, 0)
		t.eq(env.DataService.get(p), nil)
		t.eq(env.DataService.waitForProfile(p, 5), nil, "left player returns nil without waiting")
	end)

	t.test("DataService.onLoaded: 이미 로드된 사람에게도 바로, 에러는 격리, 해제 가능", function()
		local env = loadDataService()
		local a = env.join(1)
		local seen: { number } = {}
		env.DataService.onLoaded(function()
			error("listener bug")
		end)
		local off = env.DataService.onLoaded(function(player, profile)
			t.ok(profile ~= nil)
			table.insert(seen, player.UserId)
		end)
		t.eq(seen, { 1 }, "already loaded")
		t.eq(#env.warnings, 1, "first listener error was warned")
		env.join(2)
		t.eq(seen, { 1, 2 })
		off()
		env.join(3)
		t.eq(seen, { 1, 2 })
		t.ok(a ~= nil)
	end)

	t.test(
		"SaveSettings: 정수 1~3만, 표가 아니거나 범위 밖·소수·NaN·inf·문자열은 무시",
		function()
			local env = loadDataService()
			local p = env.join(1)
			local clock = 100
			local function send(value: any)
				clock += 1 -- 간격 제한에 안 걸리게
				env.setClock(clock)
				env.saveSettings.OnServerEvent:Fire(p, value)
			end
			local function level(): number
				return env.DataService.get(p).settings.muteLevel
			end
			send({ muteLevel = 3 })
			t.eq(level(), 3)
			for _, bad in
				{
					{ muteLevel = 0 },
					{ muteLevel = 4 },
					{ muteLevel = 2.5 },
					{ muteLevel = 0 / 0 },
					{ muteLevel = math.huge },
					{ muteLevel = -math.huge },
					{ muteLevel = "2" },
					{ muteLevel = { 2 } },
					{},
					2,
					"muteLevel",
					true,
				} :: { any }
			do
				send(bad)
				t.eq(level(), 3, `rejected {tostring(bad)}`)
			end
			send(nil)
			t.eq(level(), 3, "nil rejected")
			send({ muteLevel = 1, extra = "ignored" })
			t.eq(level(), 1)
			t.eq(env.DataService.get(p).settings.extra, nil, "only muteLevel copied")
		end
	)

	t.test(
		"SaveSettings: 요청 간격 0.5초 안의 두 번째는 무시, 그 뒤는 받아요 (사람마다 따로)",
		function()
			local env = loadDataService()
			local a = env.join(1)
			local b = env.join(2)
			t.eq(Config.Data.SettingsMinInterval, 0.5)
			env.setClock(200)
			env.saveSettings.OnServerEvent:Fire(a, { muteLevel = 2 })
			env.setClock(200.3)
			env.saveSettings.OnServerEvent:Fire(a, { muteLevel = 3 })
			t.eq(env.DataService.get(a).settings.muteLevel, 2, "too soon")
			env.saveSettings.OnServerEvent:Fire(b, { muteLevel = 3 })
			t.eq(env.DataService.get(b).settings.muteLevel, 3, "other player not limited")
			env.setClock(200.8)
			env.saveSettings.OnServerEvent:Fire(a, { muteLevel = 3 })
			t.eq(env.DataService.get(a).settings.muteLevel, 3, "after interval")
		end
	)

	t.test("SaveSettings: 로드 전·모르는 사람이 보내도 에러 없음", function()
		local env = loadDataService()
		local ghost = { UserId = 9, Parent = env.players }
		env.saveSettings.OnServerEvent:Fire(ghost, { muteLevel = 2 })
		t.eq(env.DataService.get(ghost), nil)
	end)

	t.test("ProfileUpdated·RewardGranted는 서버가 OnServerEvent로 듣지 않아요 (S→C 전용)", function()
		for _, file in { "src/server/DataService.luau", "src/server/RewardService.luau" } do
			local text = fs.readFile(file)
			t.ok(string.find(text, 'event("ProfileUpdated").OnServerEvent', 1, true) == nil, file)
			t.ok(string.find(text, 'event("RewardGranted").OnServerEvent', 1, true) == nil, file)
		end
	end)

	-- ProfileStore --------------------------------------------------------------------------
	t.test(
		"ProfileStore: 받기 전 nil, 받으면 get·changed, Disconnect 뒤 안 불림, 잘못된 값 무시",
		function()
			local ProfileStore, remote = loadProfileStore()
			t.eq(ProfileStore.get(), nil)
			ProfileStore.start(nil)
			ProfileStore.start(nil)
			t.eq(remote.OnClientEvent:count(), 1, "start connects once")
			local seen: { number } = {}
			local conn = ProfileStore.changed(function(view)
				table.insert(seen, view.coins)
			end)
			t.eq(conn.Connected, true)
			remote.OnClientEvent:Fire(ProfileSchema.toView(ProfileSchema.new(), false))
			t.eq(seen, { 0 })
			t.eq(ProfileStore.get().persistent, false)
			remote.OnClientEvent:Fire("not a table")
			remote.OnClientEvent:Fire(nil)
			t.eq(seen, { 0 }, "garbage ignored")
			t.eq(ProfileStore.get().coins, 0)
			conn:Disconnect()
			t.eq(conn.Connected, false)
			local view = ProfileSchema.toView(ProfileSchema.new(), true)
			view.coins = 50
			remote.OnClientEvent:Fire(view)
			t.eq(seen, { 0 })
			t.eq(ProfileStore.get().coins, 50)
		end
	)

	-- RoundLogic 결승 규칙 (m2-07 I1) ---------------------------------------------------------
	t.test(
		"결승 무작위 묶음 2000판: Won ≤ 1, 리셋은 우승 못 함, 우승자 = standings 우승자, 등수 1..N",
		function()
			local rand = lcg(7)
			for game = 1, 2000 do
				local n = 2 + rand() % 7 -- 2~8명
				local ids = {}
				local entries = {}
				for i = 1, n do
					table.insert(ids, i)
					table.insert(entries, { userId = i, name = `P{i}` })
				end
				local standings = RoundLogic.newStandings(entries)
				local round = RoundLogic.newRound("Final", ids)
				RoundLogic.activate(round, 1)
				local wonCount = 0
				local wonUser: number? = nil
				local guard = 0
				while not round.ended and guard < 20 do
					guard += 1
					local racers = RoundLogic.racers(round)
					local batch = {}
					local causeById: { [number]: string } = {}
					for _, id in racers do
						if rand() % 3 == 0 or #racers <= 2 and rand() % 2 == 0 then
							local cause = if rand() % 2 == 0 then "Fall" else "Reset"
							causeById[id] = cause
							table.insert(batch, { userId = id, score = rand() % 100, cause = cause })
						end
					end
					if #batch > 0 then
						local before = #racers
						local hasFall = false
						for _, f in batch do
							hasFall = hasFall or f.cause == "Fall"
						end
						local out = RoundLogic.applyOutcomes(standings, RoundLogic.eliminate(round, batch, noScore))
						for _, o in out do
							if o.result == "Won" then
								wonCount += 1
								wonUser = o.userId
								t.ok(causeById[o.userId] ~= "Reset", `game {game}: a reset player won`)
								t.eq(o.place, 1)
							end
						end
						if #batch == before then
							-- 묶음이 남은 전원: 낙하가 있으면 우승자, 전부 리셋이면 우승자 없이 끝
							t.eq(wonUser ~= nil, hasFall, `game {game}: all-out batch winner iff a fall`)
							t.ok(round.ended, `game {game}: ended`)
						end
					end
				end
				if not round.ended then
					local out = RoundLogic.applyOutcomes(standings, RoundLogic.timeout(round, noScore))
					for _, o in out do
						if o.result == "Won" then
							wonCount += 1
							wonUser = o.userId
						end
					end
				end
				t.ok(wonCount <= 1, `game {game}: at most one Won`)
				t.eq(RoundLogic.winnerOf(standings), wonUser, `game {game}: standings winner = Won`)
				local winner, needsWon = RoundLogic.decideWinner(standings, {})
				t.eq(winner, wonUser)
				t.eq(needsWon, false, "final never needs an extra Won")
				local places = {}
				for _, row in RoundLogic.standingsList(standings) do
					t.ok(places[row.place] == nil, `game {game}: duplicate place {row.place}`)
					places[row.place] = true
				end
				for place = 1, n do
					t.ok(places[place], `game {game}: place {place} filled`)
				end
				-- 끝난 뒤에는 더 아무 일도 없어요
				t.eq(RoundLogic.eliminate(round, { { userId = 1, score = 0, cause = "Fall" } }, noScore), {})
				t.eq(RoundLogic.timeout(round, noScore), {})
			end
		end
	)

	t.test("결승: 리셋 혼자 → 남은 1명 우승 (기존 동작 유지)", function()
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, { { userId = 1, score = 99, cause = "Reset" } }, noScore)
		t.eq(#out, 2)
		t.eq(out[1].result, "Eliminated")
		t.eq(out[2].userId, 2)
		t.eq(out[2].result, "Won")
	end)

	t.test("결승: 같은 묶음 낙하·리셋 점수가 같아도 낙하가 우승", function()
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, {
			{ userId = 2, score = 10, cause = "Fall" },
			{ userId = 1, score = 10, cause = "Reset" },
		}, noScore)
		t.eq(out[#out].userId, 2)
		t.eq(out[#out].result, "Won")
	end)

	t.test(
		"결승 전원 리셋으로 끝남: Victory 없음, 순위표는 1..N으로 채워짐 (1등 칸에 우승자 아닌 사람)",
		function()
			local standings = RoundLogic.newStandings({ { userId = 1, name = "A" }, { userId = 2, name = "B" } })
			local round = RoundLogic.newRound("Final", { 1, 2 })
			RoundLogic.activate(round, 1)
			RoundLogic.applyOutcomes(
				standings,
				RoundLogic.eliminate(round, {
					{ userId = 1, score = 10, cause = "Reset" },
					{ userId = 2, score = 50, cause = "Reset" },
				}, noScore)
			)
			t.eq(RoundLogic.winnerOf(standings), nil)
			local byPlace = {}
			for _, row in RoundLogic.standingsList(standings) do
				byPlace[row.place] = row.userId
			end
			-- 소비자(m4-08·m4-11)는 place == 1이 아니라 winnerUserId로 우승을 판단해야 해요 (리포트 B3)
			t.eq(byPlace[1], 2)
			t.eq(byPlace[2], 1)
		end
	)

	t.test("결승이 아닌 라운드 묶음은 그대로: 점수 순 등수, 구제는 낙하만", function()
		-- Race 4명, 통과 0, 3명이 같은 묶음(리셋 점수 90, 낙하 50, 낙하 10) → 2명 보장 빈자리 1: 가장 잘 간 낙하 1명 구제, 리셋은 점수가 높아도 탈락
		local round = RoundLogic.newRound("Race", { 1, 2, 3, 4 })
		RoundLogic.activate(round, 2)
		local out = RoundLogic.eliminate(round, {
			{ userId = 1, score = 90, cause = "Reset" },
			{ userId = 2, score = 50, cause = "Fall" },
			{ userId = 3, score = 10, cause = "Fall" },
		}, noScore)
		local result: { [number]: string } = {}
		for _, o in out do
			result[o.userId] = o.result
		end
		t.eq(result[1], "Eliminated", "reset never rescued")
		t.eq(result[2], "Passed", "best fall rescued")
		t.ok(result[3] ~= "Won", "no Won outside the final")
	end)
end
