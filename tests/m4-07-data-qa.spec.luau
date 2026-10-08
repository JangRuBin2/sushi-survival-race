--!strict
-- m4-07 QA: 저장 흐름 경계값 (docs/qa/m4-07-data-persistence.md)
-- 잠금 만료 경계, 미래 버전 데이터 보호, 해제 뒤 쓰기 금지, 잠금 갱신, SaveSettings 검증, 음소거 복원 경계.

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

-- UpdateAsync 흉내 (변환 함수가 nil이면 쓰지 않음)
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

local function claim(store: any, job: string, now: number, allowSteal: boolean): (string, any)
	local decision, raw
	store.update("u_1", function(old)
		local new, d = ProfileLogic.claim(old, job, now, EXPIRY, allowSteal)
		decision = d
		raw = if type(old) == "table" then old.profile else nil
		return new
	end)
	return decision, raw
end

local function commit(store: any, job: string, profile: any, now: number, release: boolean): boolean
	local written = false
	store.update("u_1", function(old)
		local new, ok = ProfileLogic.commit(old, ProfileLogic.deepCopy(profile), job, now, release)
		written = ok
		return new
	end)
	return written
end

return function(t: Test.Test)
	-- 잠금 결정 경계
	t.test("qa: lock expires exactly at SessionLockExpiry", function()
		local lock = { jobId = "B", at = 1000 }
		t.eq(ProfileLogic.lockDecision(lock, "A", 1000 + EXPIRY - 1, EXPIRY), "wait")
		t.eq(ProfileLogic.lockDecision(lock, "A", 1000 + EXPIRY, EXPIRY), "steal")
	end)

	t.test("qa: a lock stamped in the future (clock skew) still means wait", function()
		t.eq(ProfileLogic.lockDecision({ jobId = "B", at = 5000 }, "A", 4000, EXPIRY), "wait")
	end)

	t.test("qa: lock refresh interval is well inside the expiry", function()
		-- DataService는 SessionLockExpiry / 3 마다 잠금을 갱신해요. 자동 저장 간격보다 길고 만료보다 짧아야 해요.
		t.ok(EXPIRY / 3 >= Config.Data.AutosaveInterval)
		t.ok(EXPIRY / 3 + Config.Data.AutosaveInterval < EXPIRY)
	end)

	t.test("qa: refreshed lock keeps a waiting server out until it expires again", function()
		local store = fakeStore()
		claim(store, "A", 0, false)
		local profile = ProfileSchema.new()
		t.eq(commit(store, "A", profile, 600, false), true) -- 10분 갱신
		t.eq((claim(store, "B", 600 + EXPIRY - 1, false)), "wait")
		t.eq(store.data.u_1.lock.jobId, "A")
		t.eq((claim(store, "B", 600 + EXPIRY, false)), "steal")
	end)

	t.test("qa: waiting claim writes nothing", function()
		local store = fakeStore()
		local profile = ProfileSchema.new()
		profile.coins = 9
		claim(store, "A", 0, false)
		commit(store, "A", profile, 1, false)
		local before = ProfileLogic.deepCopy(store.data.u_1)
		t.eq((claim(store, "B", 2, false)), "wait")
		t.eq(store.data.u_1, before)
	end)

	t.test("qa: stealing keeps the stored profile untouched", function()
		local store = fakeStore()
		local profile = ProfileSchema.new()
		profile.coins = 77
		claim(store, "A", 0, false)
		commit(store, "A", profile, 1, false)
		local decision, raw = claim(store, "B", 2, true)
		t.eq(decision, "steal")
		t.eq(store.data.u_1.profile.coins, 77)
		t.eq(ProfileLogic.migrate(raw).coins, 77)
	end)

	t.test("qa: a server that already released cannot write again", function()
		local store = fakeStore()
		local profile = ProfileSchema.new()
		profile.coins = 5
		claim(store, "A", 0, false)
		t.eq(commit(store, "A", profile, 1, true), true)
		local late = ProfileSchema.new()
		late.coins = 0
		t.eq(commit(store, "A", late, 2, false), false)
		t.eq(store.data.u_1.profile.coins, 5)
		t.eq(store.data.u_1.lock, nil)
	end)

	t.test("qa: thief's later save is not overwritten by the old server", function()
		local store = fakeStore()
		claim(store, "A", 0, false)
		claim(store, "B", 5, true)
		local mine = ProfileSchema.new()
		mine.coins = 300
		t.eq(commit(store, "B", mine, 6, false), true)
		t.eq(commit(store, "A", ProfileSchema.new(), 7, true), false)
		t.eq(store.data.u_1.profile.coins, 300)
		t.eq(store.data.u_1.lock.jobId, "B")
	end)

	-- 미래 버전 데이터 보호: 로드 → 저장 안 함 → 잠금만 해제. 저장된 프로필은 한 글자도 바뀌지 않아요.
	t.test("qa: future-version data survives load and release byte for byte", function()
		local store = fakeStore()
		local future = {
			version = ProfileSchema.VERSION + 1,
			coins = 1234,
			wins = 7,
			matchesPlayed = 20,
			ownedSkins = { tamago = true, newSkin = true },
			equippedSkin = "newSkin",
			settings = { muteLevel = 2, newSetting = true },
			brandNewField = { a = 1 },
		}
		store.data.u_1 = { profile = ProfileLogic.deepCopy(future) }
		local decision, raw = claim(store, "A", 0, false)
		t.eq(decision, "take")
		local _, info = ProfileLogic.migrate(raw)
		t.eq(info.persistable, false)
		store.update("u_1", function(old)
			return ProfileLogic.release(old, "A")
		end)
		t.eq(store.data.u_1.profile, future)
		t.eq(store.data.u_1.lock, nil)
	end)

	t.test("qa: stored value with only a lock (crash before first save) loads as a new profile", function()
		local profile, info = ProfileLogic.migrate(({ lock = { jobId = "A", at = 0 } } :: any).profile)
		t.eq(profile, ProfileSchema.new())
		t.eq(info.persistable, true)
	end)

	-- migrate 경계
	t.test("qa: migrate treats numeric strings as invalid (0)", function()
		local profile = ProfileLogic.migrate({ coins = "50", wins = true, matchesPlayed = {} })
		t.eq(profile.coins, 0)
		t.eq(profile.wins, 0)
		t.eq(profile.matchesPlayed, 0)
	end)

	t.test("qa: migrate drops non-true and non-string skin entries", function()
		local profile = ProfileLogic.migrate({
			ownedSkins = { salmon = false, [1] = true, tuna = "yes", ebi = true } :: any,
			equippedSkin = "salmon",
		})
		t.eq(profile.ownedSkins, { [Config.Appearance.Default] = true, ebi = true })
		t.eq(profile.equippedSkin, Config.Appearance.Default)
	end)

	t.test("qa: migrate keeps a valid owned equipped skin and mute setting", function()
		local profile = ProfileLogic.migrate({
			ownedSkins = { ebi = true },
			equippedSkin = "ebi",
			settings = { muteLevel = 3 },
		})
		t.eq(profile.equippedSkin, "ebi")
		t.eq(profile.settings.muteLevel, 3)
	end)

	t.test("qa: migrate resets an out-of-range mute level", function()
		t.eq(ProfileLogic.migrate({ settings = { muteLevel = 4 } }).settings.muteLevel, 1)
		t.eq(ProfileLogic.migrate({ settings = { muteLevel = 0 } }).settings.muteLevel, 1)
	end)

	t.test("qa: non-numeric version is not treated as future data", function()
		local _, info = ProfileLogic.migrate({ version = "99" })
		t.eq(info.persistable, true)
		local _, info2 = ProfileLogic.migrate({ version = 1.5 })
		t.eq(info2.persistable, false)
	end)

	t.test("qa: dayNumber boundaries", function()
		t.eq(ProfileLogic.dayNumber(0), 0)
		t.eq(ProfileLogic.dayNumber(86399), 0)
		t.eq(ProfileLogic.dayNumber(86400), 1)
		t.eq(ProfileLogic.dayNumber(86400 * 20000 + 5), 20000)
	end)

	-- SaveSettings 서버 검증 (DataService.onSaveSettings → ProfileSchema.sanitizeSettings)
	t.test("qa: SaveSettings rejects malformed values", function()
		local bad: { any } = {
			nil,
			"x",
			5,
			{},
			{ muteLevel = "2" },
			{ muteLevel = 0 },
			{ muteLevel = 4 },
			{ muteLevel = 1.5 },
			{ muteLevel = 0 / 0 },
			{ muteLevel = math.huge },
			{ muteLevel = -math.huge },
		}
		for i = 1, 11 do
			t.eq(ProfileSchema.sanitizeSettings(bad[i]), nil, `case {i}`)
		end
	end)

	t.test("qa: SaveSettings keeps only muteLevel", function()
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 2, coins = 999 }), { muteLevel = 2 })
	end)

	-- 음소거 복원 경계 (Sfx.luau)
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

	local function rawView(settings: any): any
		local view = ProfileSchema.toView(ProfileSchema.new(), true)
		view.settings = settings
		return view
	end

	t.test("qa: mute restore ignores an invalid saved level", function()
		for _, settings in { { muteLevel = 7 }, { muteLevel = 2.5 }, { muteLevel = 0 }, "bad" } :: { any } do
			local env, button = muteEnv()
			local before = button.Text
			env.pushProfile(rawView(settings))
			t.eq(button.Text, before)
			env.now += 2
			env.runDelayed(env.now)
			t.eq(saves(env), {})
		end
	end)

	t.test("qa: after restoring 3, one press cycles to 1 and saves 1", function()
		local env, button = muteEnv()
		env.pushProfile(rawView({ muteLevel = 3 }))
		button.Activated:Fire()
		env.now += 0.5
		env.runDelayed(env.now)
		t.eq(saves(env), { 1 })
		local sfx = env.soundService:FindFirstChild("Sfx")
		t.ok(sfx.Volume > 0)
	end)
end
