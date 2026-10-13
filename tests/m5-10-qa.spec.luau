--!strict
-- m5-10 QA: 코드 보상의 서버 검증·남용 방지·한 번 지급 경계값.
-- 개발 테스트(code-logic.spec.luau)는 순수 CodeLogic만 다뤄서, 여기서는 가짜 Roblox 환경으로
-- src/server/CodeService.luau 소스를 직접 돌려 리모트 인자 검증, 요청 간격, 잠금, 한 번 지급,
-- 로그에 코드가 새지 않는지, 이벤트 재화가 이벤트 기간에만 오는지 확인해요. 진짜 코드는 쓰지 않아요 (D4).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local RobloxRequire = require("./lib/RobloxRequire")
local LocTest = require("./lib/LocTest")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local CodeLogic = RobloxRequire.require(Shared.CodeLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)

local HALLOWEEN_START = 1792108800
local HALLOWEEN_END = 1793923200
local NEW_YEAR = 1798761600
local REAL_NOW = 1790000000 -- 할로윈 전 (실서버 os.time)

local function fakeCodes(): { any }
	return {
		{ code = "QAFAKE2026", coins = 200, expiresAt = NEW_YEAR },
		{
			code = "QAFAKESPOOKY",
			coins = 100,
			tokens = 10,
			eventId = "halloween-2026",
			startsAt = HALLOWEEN_START,
			expiresAt = HALLOWEEN_END,
		},
		-- 코드 기간이 이벤트보다 긴 코드 (재화는 이벤트 안에서만)
		{ code = "QALONGEVENT", coins = 50, tokens = 5, eventId = "halloween-2026" },
	}
end

---------------------------------------------------------------- 가짜 Roblox 환경
local function newSignal(): any
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

local function loadEnv(options: { [string]: any }?): any
	local opts = options or {}
	local env: any = {}
	env.clock = 1000
	env.time = opts.time or REAL_NOW
	env.studio = opts.studio == true
	env.persist = if opts.persist == nil then true else opts.persist
	env.codes = opts.codes or fakeCodes()
	env.profiles = {}
	env.updates = 0
	env.saves = 0
	env.fired = {}
	env.prints = {}
	env.warnings = {}
	env.remotes = {}

	local Players = { PlayerRemoving = newSignal(), PlayerAdded = newSignal() }
	local services: { [string]: any } = {
		Players = Players,
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
		RunService = {
			IsStudio = function()
				return env.studio
			end,
		},
	}
	local function remote(name: string): any
		if env.remotes[name] == nil then
			local r: any = { Name = name }
			function r.FireClient(_, player, payload)
				table.insert(env.fired, { name = name, player = player, payload = payload })
			end
			env.remotes[name] = r
		end
		return env.remotes[name]
	end
	local serverModules: { [string]: any } = {
		CodeConfig = {
			load = function()
				return env.codes
			end,
		},
		DataService = {
			get = function(player)
				return env.profiles[player.UserId]
			end,
			update = function(player, fn)
				local profile = env.profiles[player.UserId]
				if profile == nil then
					return false
				end
				env.updates += 1
				local hook = env.beforeUpdate
				if hook then
					hook(profile)
				end
				fn(profile)
				return true
			end,
			saveNow = function()
				env.saves += 1
				return true
			end,
			canPersist = function()
				return env.persist
			end,
		},
	}
	local environment = {
		game = {
			GetService = function(_, name: string)
				return assert(services[name], name)
			end,
		},
		script = {
			Parent = setmetatable({}, {
				__index = function(_, name: string)
					return { __server = name }
				end,
			}),
		},
		require = function(target: any)
			if target.__shared == "Remotes" then
				return { fn = remote, event = remote }
			elseif target.__shared then
				return RobloxRequire.require((Shared :: any)[target.__shared])
			end
			return assert(serverModules[target.__server], target.__server)
		end,
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
		},
		os = {
			clock = function()
				return env.clock
			end,
			time = function()
				return env.time
			end,
		},
		warn = function(...)
			table.insert(env.warnings, table.concat({ ... }, " "))
		end,
		print = function(...)
			table.insert(env.prints, table.concat({ ... }, " "))
		end,
	}
	if opts.eventNow ~= nil then
		local Config = RobloxRequire.require(Shared.Config)
		env.restoreEventNow = Config.DEBUG.eventNow
		Config.DEBUG.eventNow = opts.eventNow
	end
	env.Service = luau.load(
		fs.readFile("src/server/CodeService.luau"),
		{ debugName = "CodeService", environment = environment }
	)()
	env.Service.init()
	env.Service.start()

	-- 요청 하나: 기본으로 요청 간격(2초)보다 길게 시계를 움직여요
	function env.redeem(player: any, raw: any, gap: number?): (boolean, string)
		env.clock += gap or 2.5
		return env.remotes.RedeemCode.OnServerInvoke(player, raw)
	end
	function env.join(userId: number, profile: any?): any
		local player = { UserId = userId, Name = `P{userId}`, Parent = Players }
		env.profiles[userId] = profile or { coins = 0, redeemedCodes = {}, eventTokens = {} }
		return player
	end
	function env.leave(player: any)
		player.Parent = nil
		Players.PlayerRemoving:Fire(player)
	end
	function env.done()
		if opts.eventNow ~= nil then
			local Config = RobloxRequire.require(Shared.Config)
			Config.DEBUG.eventNow = env.restoreEventNow
		end
	end
	return env
end

local function allLogs(env: any): string
	return table.concat(env.prints, "\n") .. "\n" .. table.concat(env.warnings, "\n")
end

local function codeOf(path: string): string
	local lines = {}
	for line in string.gmatch(fs.readFile(path), "[^\n]*") do
		local cut = string.find(line, "--", 1, true)
		table.insert(lines, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(lines, "\n")
end

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

return function(t: Test.Test)
	---------------------------------------------------------------- 리모트 인자 검증
	t.test("QA remote: non-string args are rejected as 'unknown' and count as failures", function()
		local env = loadEnv()
		local p = env.join(1)
		local nilOk, nilText = env.redeem(p, nil)
		t.eq(nilOk, false)
		t.eq(LocTest.ko(nilText), "없는 코드예요")
		for _, raw in { 123, true, { "QAFAKE2026" }, { code = "QAFAKE2026" }, 0 / 0 } :: { any } do
			local ok, text = env.redeem(p, raw)
			t.eq(ok, false)
			t.eq(LocTest.ko(text), "없는 코드예요")
		end
		t.eq(env.profiles[1].coins, 0)
		t.eq(env.updates, 0)
		-- 6번 실패 → 2번 더 틀리면 잠금
		env.redeem(p, "NOPE1")
		env.redeem(p, "NOPE2")
		local ok, text = env.redeem(p, "QAFAKE2026")
		t.eq(ok, false)
		t.eq(LocTest.ko(text), "잠시 뒤에 다시 해 주세요")
		t.eq(env.profiles[1].coins, 0)
	end)

	t.test("QA remote: huge / control-char / unicode / multi-line strings never grant", function()
		local env = loadEnv()
		local p = env.join(1)
		for _, raw in
			{
				string.rep("A", 1_000_000),
				"QAFAKE2026\0",
				"QAFAKE2026 X",
				"QAFAKE２０２６",
				"QA\nFAKE2026",
				"qafake2026; drop",
			}
		do
			local ok = env.redeem(p, raw)
			t.eq(ok, false)
		end
		t.eq(env.profiles[1].coins, 0)
		t.eq(env.updates, 0)
	end)

	t.test("QA remote: lowercase + surrounding whitespace/newline is accepted (AC8 path)", function()
		local env = loadEnv()
		local p = env.join(1)
		local ok, text = env.redeem(p, "\t qafake2026 \n")
		t.eq(ok, true)
		t.eq(LocTest.ko(text), "🍚 200 받았어요!")
		t.eq(env.profiles[1].coins, 200)
		t.eq(env.profiles[1].redeemedCodes, { QAFAKE2026 = REAL_NOW })
	end)

	---------------------------------------------------------------- 요청 간격 · 잠금
	t.test("QA cooldown: requests within 2s are refused and not counted as failures", function()
		local env = loadEnv()
		local p = env.join(1)
		env.redeem(p, "NOPE1") -- 실패 1
		for _ = 1, 50 do
			local ok, text = env.redeem(p, "NOPE2", 0.01)
			t.eq(ok, false)
			t.eq(LocTest.ko(text), "잠시 뒤에 다시 해 주세요")
		end
		-- 스팸 50번은 실패로 안 셌어요: 2초 뒤 진짜 코드는 받아요
		local ok = env.redeem(p, "QAFAKE2026", 2.5)
		t.eq(ok, true)
	end)

	t.test("QA cooldown: exactly 2.0s later is allowed (boundary)", function()
		local env = loadEnv()
		local p = env.join(1)
		env.redeem(p, "NOPE1")
		local ok, text = env.redeem(p, "NOPE2", 1.999)
		t.eq(LocTest.ko(text), "잠시 뒤에 다시 해 주세요")
		t.eq(ok, false)
		-- 1.999초에 거절됐지만 lastAt은 갱신되지 않아야 해요 (거절 요청이 간격을 늘리지 않음)
		ok = env.redeem(p, "QAFAKE2026", 0.001)
		t.eq(ok, true)
	end)

	t.test("QA lockout: 7 failures do not lock, the 8th locks, log printed exactly once without the code", function()
		local env = loadEnv()
		local p = env.join(1)
		for i = 1, 7 do
			local _, text = env.redeem(p, `SECRETGUESS{i}`)
			t.eq(LocTest.ko(text), "없는 코드예요")
		end
		t.eq(#env.prints, 0)
		local _, text = env.redeem(p, "SECRETGUESS8")
		t.eq(LocTest.ko(text), "없는 코드예요") -- 8번째 자체는 "없는 코드"
		t.eq(#env.prints, 1)
		t.eq(env.prints[1], "[Code] P1(1) locked after 8 failures")
		-- 잠긴 뒤: 진짜 코드도 거절, 잠금 로그는 다시 안 찍힘
		for _ = 1, 5 do
			local ok, locked = env.redeem(p, "QAFAKE2026")
			t.eq(ok, false)
			t.eq(LocTest.ko(locked), "잠시 뒤에 다시 해 주세요")
		end
		t.eq(#env.prints, 1)
		t.ok(not string.find(allLogs(env), "SECRETGUESS", 1, true), "failure logs must not contain the guessed code")
		t.eq(env.profiles[1].coins, 0)
	end)

	t.test(
		"QA lockout: lasts until the oldest failure leaves the 600s window, then one more failure re-locks",
		function()
			local env = loadEnv()
			local p = env.join(1)
			local first = env.time
			for i = 1, 8 do
				env.redeem(p, `BAD{i}`)
				env.time += 2
			end
			env.time = first + 599
			local _, text = env.redeem(p, "QAFAKE2026")
			t.eq(LocTest.ko(text), "잠시 뒤에 다시 해 주세요")
			env.time = first + 600 -- 첫 실패가 창 밖 → 7번
			local ok = env.redeem(p, "QAFAKE2026")
			t.eq(ok, true)
			local _, again = env.redeem(p, "BAD9") -- 7 + 1 = 8 → 다시 잠금
			t.eq(LocTest.ko(again), "없는 코드예요")
			local _, locked = env.redeem(p, "QAFAKESPOOKY")
			t.eq(LocTest.ko(locked), "잠시 뒤에 다시 해 주세요")
		end
	)

	t.test("QA lockout: real-code outcomes (NotStarted/Expired/AlreadyRedeemed) never count", function()
		local env = loadEnv({ time = HALLOWEEN_START - 10 })
		local p = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKE2026"))), "🍚 200 받았어요!")
		for _ = 1, 10 do
			t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKE2026"))), "이미 받은 코드예요")
			t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKESPOOKY"))), "아직 쓸 수 없는 코드예요")
		end
		env.time = NEW_YEAR
		for _ = 1, 10 do
			t.eq(LocTest.ko(select(2, env.redeem(p, "qafakespooky"))), "기간이 끝난 코드예요")
		end
		t.eq((select(2, env.redeem(p, "qafakespooky")) :: any).key, "code.err.Expired") -- m5-26 AC14: 키로 비교
		-- 30번 넘게 거절됐지만 잠금 아님: 틀린 코드는 아직 "없는 코드예요"
		t.eq(LocTest.ko(select(2, env.redeem(p, "NOPE"))), "없는 코드예요")
		t.eq(#env.prints, 1) -- 성공 로그 하나뿐
	end)

	t.test("QA lockout: per player — one player's failures do not lock another", function()
		local env = loadEnv()
		local a = env.join(1)
		local b = env.join(2)
		for i = 1, 8 do
			env.redeem(a, `BAD{i}`)
		end
		t.eq(LocTest.ko(select(2, env.redeem(a, "QAFAKE2026"))), "잠시 뒤에 다시 해 주세요")
		t.eq(select(1, env.redeem(b, "QAFAKE2026")), true)
	end)

	t.test(
		"QA lockout: state is cleared on leave (spec '나가면 지움') — rejoin starts a fresh counter",
		function()
			local env = loadEnv()
			local a = env.join(1)
			for i = 1, 8 do
				env.redeem(a, `BAD{i}`)
			end
			env.leave(a)
			local again = env.join(1, env.profiles[1])
			t.eq(LocTest.ko(select(2, env.redeem(again, "NOPE"))), "없는 코드예요") -- 리포트 P3 R1 참고
		end
	)

	---------------------------------------------------------------- 한 번 지급
	t.test("QA once: a second redemption after cooldown is AlreadyRedeemed, coins unchanged", function()
		local env = loadEnv()
		local p = env.join(1)
		t.eq(select(1, env.redeem(p, "QAFAKE2026")), true)
		t.eq(LocTest.ko(select(2, env.redeem(p, "qafake2026"))), "이미 받은 코드예요")
		t.eq(LocTest.ko(select(2, env.redeem(p, " QAFAKE2026 "))), "이미 받은 코드예요")
		t.eq(env.profiles[1].coins, 200)
		t.eq(env.updates, 1)
	end)

	t.test("QA once: profile changed between check and update (race) grants nothing", function()
		local env = loadEnv()
		local p = env.join(1)
		env.beforeUpdate = function(profile)
			profile.redeemedCodes.QAFAKE2026 = 1 -- 다른 경로가 먼저 기록했다고 가정
		end
		local ok, text = env.redeem(p, "QAFAKE2026")
		t.eq(ok, false)
		t.eq(LocTest.ko(text), "이미 받은 코드예요")
		t.eq(env.profiles[1].coins, 0)
		t.eq(#env.fired, 0)
		t.eq(env.saves, 0)
	end)

	t.test("QA once: rejoin on another server with the saved profile is AlreadyRedeemed", function()
		local first = loadEnv()
		local p = first.join(1)
		first.redeem(p, "QAFAKE2026")
		-- 저장된 프로필 → 다른 서버에서 로드 (ProfileLogic 마이그레이션 통과)
		local saved = ProfileLogic.migrate(first.profiles[1])
		local second = loadEnv()
		local q = second.join(1, saved)
		t.eq(LocTest.ko(select(2, second.redeem(q, "QAFAKE2026"))), "이미 받은 코드예요")
		t.eq(saved.coins, 200)
	end)

	t.test("QA once: coins, redemption mark and tokens are written in ONE update + saveNow when persistent", function()
		local env = loadEnv({ time = HALLOWEEN_START + 5 })
		local p = env.join(1)
		local ok, text = env.redeem(p, "QAFAKESPOOKY")
		t.eq(ok, true)
		t.eq(LocTest.ko(text), "🍚 100 + 🍬 10 받았어요!")
		t.eq(env.updates, 1)
		t.eq(env.saves, 1)
		t.eq(env.profiles[1].coins, 100)
		t.eq(env.profiles[1].eventTokens, { ["halloween-2026"] = 10 })
		t.eq(#env.fired, 1)
		t.eq(env.fired[1].name, "RewardGranted")
		t.eq(env.fired[1].player, p)
		t.eq(env.fired[1].payload, {
			reason = "Code",
			amount = 100,
			total = 100,
			tokens = 10,
			tokenTotal = 10,
			eventId = "halloween-2026",
		})
		t.eq(env.prints[1], "[Code] P1(1) redeemed QAFAKESPOOKY +100 +10 halloween-2026")
	end)

	t.test("QA once: existing tokens are added to, not replaced", function()
		local env = loadEnv({ time = HALLOWEEN_START + 5 })
		local p = env.join(1, { coins = 7, redeemedCodes = {}, eventTokens = { ["halloween-2026"] = 33 } })
		env.redeem(p, "QAFAKESPOOKY")
		t.eq(env.profiles[1].eventTokens["halloween-2026"], 43)
		t.eq(env.profiles[1].coins, 107)
		t.eq(env.fired[1].payload.tokenTotal, 43)
	end)

	---------------------------------------------------------------- 프로필 · 저장
	t.test("QA save: live server + canPersist false → NotSaved, nothing granted", function()
		local env = loadEnv({ persist = false })
		local p = env.join(1)
		local ok, text = env.redeem(p, "QAFAKE2026")
		t.eq(ok, false)
		t.eq(LocTest.ko(text), "저장이 안 되는 상태라 지금은 쓸 수 없어요")
		t.eq(env.profiles[1].coins, 0)
		t.eq(env.updates, 0)
	end)

	t.test("QA save: Studio memory mode is allowed but never calls saveNow", function()
		local env = loadEnv({ persist = false, studio = true })
		local p = env.join(1)
		t.eq(select(1, env.redeem(p, "QAFAKE2026")), true)
		t.eq(env.saves, 0)
	end)

	t.test("QA save: no profile yet → NoProfile and not counted as a failure", function()
		local env = loadEnv()
		local p = { UserId = 9, Name = "P9", Parent = {} }
		for _ = 1, 10 do
			t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKE2026"))), "프로필을 불러오는 중이에요")
		end
		env.profiles[9] = { coins = 0, redeemedCodes = {}, eventTokens = {} }
		t.eq(select(1, env.redeem(p, "QAFAKE2026")), true)
	end)

	t.test("QA save: player left mid-request → still recorded, no FireClient to a gone player", function()
		local env = loadEnv()
		local p = env.join(1)
		p.Parent = nil
		t.eq(select(1, env.redeem(p, "QAFAKE2026")), true)
		t.eq(#env.fired, 0)
	end)

	t.test("QA redeemedCodes cap: newest 200 kept on load, so a recent code stays redeemed", function()
		local raw = ProfileLogic.migrate(nil)
		for i = 1, ProfileSchema.MAX_REDEEMED_CODES + 5 do
			raw.redeemedCodes[`OLD{i}`] = i
		end
		raw.redeemedCodes.QAFAKE2026 = REAL_NOW
		local profile = ProfileLogic.migrate(raw)
		t.ok(profile.redeemedCodes.QAFAKE2026 ~= nil)
		local n = 0
		for _ in profile.redeemedCodes do
			n += 1
		end
		t.eq(n, ProfileSchema.MAX_REDEEMED_CODES)
	end)

	---------------------------------------------------------------- 이벤트 재화
	t.test("QA event: tokens only while the event runs (start inclusive, end exclusive)", function()
		local env = loadEnv({ time = HALLOWEEN_START - 1 })
		local a = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(a, "QALONGEVENT"))), "🍚 50 받았어요!")
		t.eq(env.profiles[1].eventTokens, {})
		env.time = HALLOWEEN_START
		local b = env.join(2)
		t.eq(LocTest.ko(select(2, env.redeem(b, "QALONGEVENT"))), "🍚 50 + 🍬 5 받았어요!")
		env.time = HALLOWEEN_END
		local c = env.join(3)
		t.eq(LocTest.ko(select(2, env.redeem(c, "QALONGEVENT"))), "🍚 50 받았어요!")
		t.eq(env.profiles[3].eventTokens, {})
		t.eq(env.fired[3].payload.tokens, nil)
	end)

	t.test("QA event: Config.DEBUG.eventNow is ignored on a live server", function()
		local env = loadEnv({ time = REAL_NOW, eventNow = HALLOWEEN_START + 1, studio = false })
		local p = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKESPOOKY"))), "아직 쓸 수 없는 코드예요")
		env.done()
	end)

	t.test("QA event: Studio uses DEBUG.eventNow for code period, real time for redeemedCodes", function()
		local env = loadEnv({ time = REAL_NOW, eventNow = HALLOWEEN_START + 1, studio = true })
		local p = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKESPOOKY"))), "🍚 100 + 🍬 10 받았어요!")
		t.eq(env.profiles[1].redeemedCodes.QAFAKESPOOKY, REAL_NOW)
		env.done()
	end)

	---------------------------------------------------------------- 설정 검사
	t.test("QA config: invalid entries are skipped with a warn, valid ones still work", function()
		local env = loadEnv({
			codes = {
				{ code = "GOODONE", coins = 100 },
				{ code = "goodone", coins = 100 }, -- 중복
				{ code = "TOOMUCH", coins = 301 },
				{ code = "NOEVENT", coins = 10, tokens = 5 },
				{ code = "BADTIME", coins = 10, startsAt = 10, expiresAt = 10 },
				"not a table",
			},
		})
		t.eq(env.Service.count(), 1)
		t.eq(#env.warnings, 5)
		local p = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(p, "TOOMUCH"))), "없는 코드예요")
		t.eq(select(1, env.redeem(p, "goodone")), true)
	end)

	t.test("QA config: empty list (no CodeList.luau) → every code is 'unknown'", function()
		local env = loadEnv({ codes = {} })
		local p = env.join(1)
		t.eq(LocTest.ko(select(2, env.redeem(p, "QAFAKE2026"))), "없는 코드예요")
	end)

	t.test("QA config: a handler error returns the generic message and does not leak to the client", function()
		local env = loadEnv()
		local p = env.join(1)
		env.beforeUpdate = function()
			error("boom")
		end
		local ok, text = env.redeem(p, "QAFAKE2026")
		t.eq(ok, false)
		t.eq(LocTest.ko(text), "다시 해 주세요")
		t.eq(#env.warnings, 1)
	end)

	---------------------------------------------------------------- 소스 검사 (공개 저장소)
	t.test("QA source: code list is server-only and the real list file is not tracked by git", function()
		local tracked = process.exec("git", { "ls-files", "src/server/CodeList.luau" })
		t.eq(tracked.ok, true)
		t.eq(tracked.stdout, "")
		local ignored = process.exec("git", { "check-ignore", "-q", "src/server/CodeList.luau" })
		t.eq(ignored.code, 0)
		t.ok(not fs.isFile("src/shared/CodeConfig.luau"))
		t.ok(not fs.isFile("src/shared/CodeList.luau"))
		t.ok(not fs.isFile("src/client/CodeList.luau"))
	end)

	t.test("QA source: committed example list is empty", function()
		local example = codeOf("src/server/CodeList.example.luau")
		t.ok(string.find(example, "Codes%s*=%s*{%s*}") ~= nil, "CodeList.example.luau must ship an empty Codes table")
	end)

	t.test("QA source: nothing outside src/server requires CodeConfig/CodeList; client never sees the list", function()
		local files: { string } = {}
		luauFiles("src/shared", files)
		luauFiles("src/client", files)
		for _, path in files do
			local code = codeOf(path)
			t.ok(not string.find(code, "CodeConfig", 1, true), `{path} references CodeConfig`)
			t.ok(not string.find(code, "CodeList", 1, true), `{path} references CodeList`)
		end
	end)

	t.test("QA source: CodeService prints the code only on success", function()
		local code = codeOf("src/server/CodeService.luau")
		local count = 0
		for line in string.gmatch(code, "[^\n]+") do
			if string.find(line, "print(", 1, true) or string.find(line, "warn(", 1, true) then
				if string.find(line, "{code}", 1, true) or string.find(line, "{raw}", 1, true) then
					count += 1
					t.ok(string.find(line, "redeemed", 1, true) ~= nil, `code logged outside success: {line}`)
				end
			end
		end
		t.eq(count, 1)
	end)

	t.test(
		"QA pure: check never reports Locked for the 7th failure and does for the 8th (failNow, not code now)",
		function()
			local list = {}
			for i = 1, 7 do
				CodeLogic.recordFailure(list, 100 + i, 600)
			end
			local _, reason = CodeLogic.check("X", nil, HALLOWEEN_START, {}, list, 110)
			t.eq(reason, "Unknown")
			CodeLogic.recordFailure(list, 108, 600)
			-- Studio eventNow가 먼 미래여도 잠금은 실제 시각(failNow) 기준
			local _, locked = CodeLogic.check("X", nil, NEW_YEAR * 2, {}, list, 110)
			t.eq(locked, "Locked")
		end
	)
end
