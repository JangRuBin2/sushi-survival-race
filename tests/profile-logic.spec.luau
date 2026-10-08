--!strict
-- m4-07 플레이어 데이터 저장: ProfileLogic (docs/specs/m4-07-data-persistence.md AC1~AC4)
-- 가짜 저장소(표 하나)로 UpdateAsync 변환 흐름(로드 잠금 → 저장 → 해제, 두 서버)도 확인해요.

local FakeSfxEnv = require("./lib/FakeSfxEnv")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)

local EXPIRY = Config.Data.SessionLockExpiry

-- UpdateAsync 흉내: 변환 함수가 nil을 돌려주면 쓰지 않아요
local function fakeStore()
	local data: { [string]: any } = {}
	return {
		data = data,
		update = function(key: string, transform: (any) -> any)
			local new = transform(ProfileLogic.deepCopy(data[key]))
			if new ~= nil then
				data[key] = ProfileLogic.deepCopy(new)
			end
		end,
	}
end

return function(t: Test.Test)
	-- AC1
	t.test("migrate(nil) is a new profile", function()
		local profile, info = ProfileLogic.migrate(nil)
		t.eq(profile, ProfileSchema.new())
		t.eq(info.persistable, true)
	end)

	t.test("migrate fixes invalid numbers to 0", function()
		local profile, info = ProfileLogic.migrate({ coins = "abc", wins = -3 })
		t.eq(profile.coins, 0)
		t.eq(profile.wins, 0)
		t.eq(profile.matchesPlayed, 0)
		t.eq(info.persistable, true)
		t.ok(#info.notes >= 2, "notes explain the fixes")
	end)

	t.test("migrate rejects NaN, infinity and floors fractions", function()
		local profile = ProfileLogic.migrate({ coins = 0 / 0, wins = math.huge, matchesPlayed = 4.7 })
		t.eq(profile.coins, 0)
		t.eq(profile.wins, 0)
		t.eq(profile.matchesPlayed, 4)
	end)

	t.test("migrate keeps valid values", function()
		local profile = ProfileLogic.migrate({
			version = 1,
			coins = 120,
			wins = 3,
			matchesPlayed = 9,
			lastDailyBonusDay = 20000,
			ownedSkins = { tamago = true, salmon = true },
			equippedSkin = "salmon",
			settings = { muteLevel = 3 },
		})
		t.eq(profile.coins, 120)
		t.eq(profile.wins, 3)
		t.eq(profile.matchesPlayed, 9)
		t.eq(profile.lastDailyBonusDay, 20000)
		t.eq(profile.ownedSkins, { tamago = true, salmon = true })
		t.eq(profile.equippedSkin, "salmon")
		t.eq(profile.settings, { muteLevel = 3 })
	end)

	t.test("migrate always owns tamago", function()
		local profile = ProfileLogic.migrate({ ownedSkins = {} })
		t.eq(profile.ownedSkins, { tamago = true })
		local broken = ProfileLogic.migrate({ ownedSkins = "x" })
		t.eq(broken.ownedSkins, { tamago = true })
	end)

	t.test("migrate resets an equipped skin that is not owned", function()
		local profile = ProfileLogic.migrate({ equippedSkin = "salmon" })
		t.eq(profile.equippedSkin, "tamago")
	end)

	t.test("migrate keeps unknown fields", function()
		local profile = ProfileLogic.migrate({ foo = 1, coins = 5 }) :: any
		t.eq(profile.foo, 1)
		t.eq(profile.coins, 5)
	end)

	t.test("migrate resets invalid settings and day", function()
		local profile = ProfileLogic.migrate({ settings = { muteLevel = 7 }, lastDailyBonusDay = "today" })
		t.eq(profile.settings, { muteLevel = 1 })
		t.eq(profile.lastDailyBonusDay, nil)
	end)

	t.test("migrate of a non-table value is a new profile", function()
		local profile, info = ProfileLogic.migrate("garbage")
		t.eq(profile, ProfileSchema.new())
		t.eq(info.persistable, true)
	end)

	t.test("migrate does not share tables with the input or defaults", function()
		local raw = { ownedSkins = { tamago = true } }
		local profile = ProfileLogic.migrate(raw)
		profile.ownedSkins.salmon = true
		t.eq(raw.ownedSkins.salmon, nil)
		t.eq(ProfileSchema.new().ownedSkins.salmon, nil)
	end)

	-- AC2
	t.test("future version is not persistable", function()
		local profile, info = ProfileLogic.migrate({ version = 99, coins = 50 })
		t.eq(info.persistable, false)
		t.eq(profile.coins, 50)
		t.ok(#info.notes >= 1)
	end)

	t.test("current and older versions are persistable", function()
		local _, current = ProfileLogic.migrate({ version = ProfileSchema.VERSION })
		local _, older = ProfileLogic.migrate({ version = 0 })
		t.eq(current.persistable, true)
		t.eq(older.persistable, true)
	end)

	-- AC3
	t.test("lockDecision", function()
		local now = 10000
		t.eq(ProfileLogic.lockDecision(nil, "A", now, EXPIRY), "take")
		t.eq(ProfileLogic.lockDecision({ jobId = "A", at = now - 10 }, "A", now, EXPIRY), "take")
		t.eq(ProfileLogic.lockDecision({ jobId = "B", at = now - 10 }, "A", now, EXPIRY), "wait")
		t.eq(ProfileLogic.lockDecision({ jobId = "B", at = now - EXPIRY - 1 }, "A", now, EXPIRY), "steal")
		t.eq(ProfileLogic.lockDecision({ jobId = "B", at = now - EXPIRY }, "A", now, EXPIRY), "steal")
	end)

	t.test("canWrite only with my lock", function()
		t.eq(ProfileLogic.canWrite(nil, "A"), false)
		t.eq(ProfileLogic.canWrite({ jobId = "A", at = 0 }, "A"), true)
		t.eq(ProfileLogic.canWrite({ jobId = "B", at = 0 }, "A"), false)
	end)

	t.test("readLock ignores malformed locks", function()
		t.eq(ProfileLogic.readLock(nil), nil)
		t.eq(ProfileLogic.readLock({ lock = "A" }), nil)
		t.eq(ProfileLogic.readLock({ lock = { jobId = 1, at = 2 } }), nil)
		t.eq(ProfileLogic.readLock({ lock = { jobId = "A", at = 2 } }), { jobId = "A", at = 2 })
	end)

	-- AC4
	t.test("dayNumber changes at UTC midnight", function()
		t.eq(ProfileLogic.dayNumber(0), 0)
		t.eq(ProfileLogic.dayNumber(86399), 0)
		t.eq(ProfileLogic.dayNumber(86400), 1)
		t.eq(ProfileLogic.dayNumber(86400 * 20000 + 5), 20000)
	end)

	-- 저장 흐름 (가짜 저장소)
	t.test("claim and commit round trip", function()
		local store = fakeStore()
		local decision
		store.update("u_1", function(old)
			local new, d = ProfileLogic.claim(old, "A", 100, EXPIRY, false)
			decision = d
			return new
		end)
		t.eq(decision, "take")
		t.eq(store.data.u_1.lock, { jobId = "A", at = 100 })

		local profile = ProfileSchema.new()
		profile.coins = 42
		local written
		store.update("u_1", function(old)
			local new, ok = ProfileLogic.commit(old, profile, "A", 160, false)
			written = ok
			return new
		end)
		t.eq(written, true)
		t.eq(store.data.u_1.profile.coins, 42)
		t.eq(store.data.u_1.lock, { jobId = "A", at = 160 })

		store.update("u_1", function(old)
			return (ProfileLogic.commit(old, profile, "A", 200, true))
		end)
		t.eq(store.data.u_1.lock, nil)
		t.eq(store.data.u_1.profile.coins, 42)
	end)

	t.test("second server waits, then reads the first server's last save", function()
		local store = fakeStore()
		store.update("u_1", function(old)
			return (ProfileLogic.claim(old, "A", 100, EXPIRY, false))
		end)
		local profile = ProfileSchema.new()
		profile.coins = 70

		-- B가 A의 잠금을 봄 → 쓰지 않고 기다림
		local decision
		store.update("u_1", function(old)
			local new, d = ProfileLogic.claim(old, "B", 101, EXPIRY, false)
			decision = d
			return new
		end)
		t.eq(decision, "wait")
		t.eq(store.data.u_1.lock.jobId, "A")

		-- A가 나가며 저장·해제 → B가 가져가서 70을 읽음
		store.update("u_1", function(old)
			return (ProfileLogic.commit(old, profile, "A", 102, true))
		end)
		local raw
		store.update("u_1", function(old)
			local new, d = ProfileLogic.claim(old, "B", 103, EXPIRY, false)
			decision = d
			raw = old.profile
			return new
		end)
		t.eq(decision, "take")
		t.eq(ProfileLogic.migrate(raw).coins, 70)
		t.eq(store.data.u_1.lock.jobId, "B")
	end)

	t.test("after stealing, the old server cannot overwrite", function()
		local store = fakeStore()
		store.update("u_1", function(old)
			return (ProfileLogic.claim(old, "A", 100, EXPIRY, false))
		end)
		local decision
		store.update("u_1", function(old)
			local new, d = ProfileLogic.claim(old, "B", 110, EXPIRY, true)
			decision = d
			return new
		end)
		t.eq(decision, "steal")

		local stale = ProfileSchema.new()
		local written
		store.update("u_1", function(old)
			local new, ok = ProfileLogic.commit(old, stale, "A", 120, true)
			written = ok
			return new
		end)
		t.eq(written, false)
		t.eq(store.data.u_1.lock.jobId, "B")
	end)

	t.test("release only frees my own lock", function()
		t.eq(ProfileLogic.release({ lock = { jobId = "B", at = 0 } }, "A"), nil)
		local freed = ProfileLogic.release({ profile = { coins = 1 }, lock = { jobId = "A", at = 0 } }, "A")
		t.ok(freed ~= nil)
		t.eq((freed :: any).lock, nil)
		t.eq((freed :: any).profile, { coins = 1 })
	end)

	t.test("commit keeps unknown top-level keys", function()
		local new =
			ProfileLogic.commit({ lock = { jobId = "A", at = 0 }, extra = 5 }, ProfileSchema.new(), "A", 1, false)
		t.eq((new :: any).extra, 5)
	end)

	t.test("deepCopy is independent", function()
		local profile = ProfileSchema.new()
		local copy = ProfileLogic.deepCopy(profile)
		copy.ownedSkins.salmon = true
		t.eq(profile.ownedSkins.salmon, nil)
		t.eq(ProfileLogic.deepCopy(profile), profile)
	end)

	-- 음소거 저장·복원 (Sfx.luau, 가짜 클라이언트 환경)
	local function muteEnv(): (any, any)
		local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
		env.module.start({})
		local button = env.playerGui:FindFirstChild("SoundGui"):FindFirstChild("MuteButton")
		return env, button
	end

	local function saves(env: any): { number }
		local list = {}
		for _, item in env.sent do
			if item.name == "SaveSettings" then
				table.insert(list, item.args[1].muteLevel)
			end
		end
		return list
	end

	local function view(muteLevel: number): any
		local profile = ProfileSchema.new()
		profile.settings.muteLevel = muteLevel
		return ProfileSchema.toView(profile, true)
	end

	t.test("mute: rapid presses send SaveSettings once, 0.5s after the last press", function()
		local env, button = muteEnv()
		button.Activated:Fire()
		env.now += 0.3
		button.Activated:Fire()
		env.runDelayed(env.now + 0.4)
		t.eq(saves(env), {}, "not yet")
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 3 })
	end)

	t.test("mute: sends are spaced so the server rate limit never drops the last value", function()
		local env, button = muteEnv()
		button.Activated:Fire()
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 2 })
		button.Activated:Fire() -- 0.0초 뒤 다시 → 0.5초 뒤 보낼 차례지만 간격 1초를 지켜요
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 2 })
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 2, 3 })
	end)

	t.test("mute: pressing back to the saved level sends nothing", function()
		local env, button = muteEnv()
		env.pushProfile(view(1))
		for _ = 1, 3 do
			button.Activated:Fire()
		end
		env.now += 1
		env.runDelayed(env.now)
		t.eq(saves(env), {})
	end)

	t.test("mute: first profile restores the saved level", function()
		local env, button = muteEnv()
		env.pushProfile(view(3))
		t.eq(button.Text, "🔇 모두 끔")
		local sfx = env.soundService:FindFirstChild("Sfx")
		t.eq(sfx.Volume, 0)
		env.pushProfile(view(1)) -- 첫 프로필만 따라요
		t.eq(button.Text, "🔇 모두 끔")
		env.now += 2
		env.runDelayed(env.now)
		t.eq(saves(env), {})
	end)

	t.test("mute: profile received before start is applied at start", function()
		local env = FakeSfxEnv.load(SfxCues, SfxLibrary)
		env.profileView = view(2)
		env.module.start({})
		local button = env.playerGui:FindFirstChild("SoundGui"):FindFirstChild("MuteButton")
		t.eq(button.Text, "🎵 음악 끔")
	end)

	t.test("mute: a press before the profile arrives wins", function()
		local env, button = muteEnv()
		button.Activated:Fire() -- 2
		env.pushProfile(view(3))
		t.eq(button.Text, "🎵 음악 끔")
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 2 })
	end)
end
