--!strict
-- m4-13 QA: 탈의실 서버(ShopService)를 가짜 Roblox 환경에서 실제로 돌려 봐요.
--   리모트 인자 검증, 보유·등급·가격·코인, 요청 간격(두 리모트 공용), 라운드·연출 잠금,
--   코인 해금이 update 한 번 안에서 끝나는지(두 번 차감·음수 없음), canPersist=false 실서버 거절,
--   grantSkin(m4-14 준비), 장착 스킨 고르기(resolver).
-- 그리고 16종 스킨을 가짜 Instance로 build해서 파츠가 판정에 끼지 않는지(Massless·충돌·쿼리·터치) 봐요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local Skins = RobloxRequire.require(Shared.Skins)
local RealSushiBody = RobloxRequire.require(Shared.SushiBody)

local SHOP_SOURCE = fs.readFile("src/server/ShopService.luau")
local SUSHI_SOURCE = fs.readFile("src/shared/SushiBody.luau")

---------------------------------------------------------------- ShopService 가짜 환경
type Harness = {
	shop: any,
	now: number,
	studio: boolean,
	persist: boolean,
	profiles: { [any]: any },
	placed: { [any]: boolean },
	refreshed: { any },
	saves: number,
	updates: number,
	resolver: ((any) -> string?)?,
	onResult: ((string, any) -> ())?,
	invoke: (name: string, player: any, arg: any) -> (boolean, string?),
	advance: (seconds: number) -> (),
	getThrows: boolean,
}

local function newPlayer(userId: number): any
	return { UserId = userId, Name = `P{userId}` }
end

local function harness(): Harness
	local h: Harness = {} :: any
	h.now = 1000
	h.studio = false
	h.persist = true
	h.profiles = {}
	h.placed = {}
	h.refreshed = {}
	h.saves = 0
	h.updates = 0
	h.getThrows = false

	local remotes: { [string]: any } = {}
	local function fn(name: string): any
		local r = remotes[name]
		if r == nil then
			r = {}
			remotes[name] = r
		end
		return r
	end

	local fakeSignal = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}

	local DataService = {
		get = function(player: any)
			if h.getThrows then
				error("boom")
			end
			return h.profiles[player]
		end,
		update = function(player: any, mutate: (any) -> ()): boolean
			local profile = h.profiles[player]
			if profile == nil then
				return false
			end
			h.updates += 1
			mutate(profile)
			return true
		end,
		canPersist = function(player: any): boolean
			return h.profiles[player] ~= nil and h.persist
		end,
		saveNow = function(_player: any): boolean
			h.saves += 1
			return true
		end,
		onLoaded = function(_fn: any) end,
	}
	local AppearanceService = {
		setResolver = function(f: any)
			h.resolver = f
		end,
		refresh = function(player: any)
			table.insert(h.refreshed, player)
		end,
	}
	local MatchEvents = {
		onResult = function(f: any)
			h.onResult = f
		end,
	}
	local RoundService = {
		placedRoomOf = function(player: any): string?
			return if h.placed[player] then "room1" else nil
		end,
	}
	local Remotes = { fn = fn }

	local SharedProxy = setmetatable({}, {
		__index = function(_, name: string)
			if name == "Remotes" then
				return { __fake = Remotes }
			end
			return (Shared :: any)[name]
		end,
	})
	local services = {
		Players = { PlayerRemoving = fakeSignal },
		ReplicatedStorage = { Shared = SharedProxy },
		RunService = {
			IsStudio = function()
				return h.studio
			end,
		},
	}
	local game = {
		GetService = function(_self: any, name: string)
			return services[name]
		end,
	}
	local script = {
		Parent = {
			AppearanceService = { __fake = AppearanceService },
			DataService = { __fake = DataService },
			MatchEvents = { __fake = MatchEvents },
			RoundService = { __fake = RoundService },
		},
	}
	local function fakeRequire(module: any): any
		if type(module) == "table" and rawget(module, "__fake") ~= nil then
			return module.__fake
		end
		return RobloxRequire.require(module)
	end
	local fakeOs = {
		clock = function()
			return h.now
		end,
		time = os.time,
	}
	local fakeTask = {
		spawn = function(f: any, ...)
			f(...)
		end,
	}
	local chunk = luau.load(SHOP_SOURCE, {
		debugName = "ShopService",
		environment = {
			game = game,
			script = script,
			require = fakeRequire,
			os = fakeOs,
			task = fakeTask,
			print = function() end,
			warn = function() end,
		},
	})
	h.shop = chunk()
	h.shop.init()
	h.shop.start()
	h.invoke = function(name: string, player: any, arg: any): (boolean, string?)
		return fn(name).OnServerInvoke(player, arg)
	end
	h.advance = function(seconds: number)
		h.now += seconds
	end
	return h
end

local function withProfile(h: Harness, userId: number, coins: number, owned: { string }?): (any, any)
	local player = newPlayer(userId)
	local profile = ProfileSchema.new()
	profile.coins = coins
	for _, id in owned or {} do
		profile.ownedSkins[id] = true
	end
	h.profiles[player] = profile
	return player, profile
end

local COOLDOWN = Config.Shop.RequestCooldown + 0.01

---------------------------------------------------------------- SushiBody 가짜 Instance
local function proxyEnum(prefix: string): any
	return setmetatable({}, {
		__index = function(_, k)
			if prefix == "" then
				return proxyEnum(k)
			end
			return `{prefix}.{k}`
		end,
	})
end

local function fakeValue(kind: string)
	return {
		new = function(...)
			return { __kind = kind, args = { ... } }
		end,
	}
end

local function newFakeInstance(className: string): any
	local inst: any = { ClassName = className, Name = className, _children = {}, _parent = nil }
	local mt = {}
	mt.__index = function(self, key)
		if key == "Parent" then
			return rawget(self, "_parent")
		elseif key == "GetChildren" then
			return function(s)
				return table.clone(s._children)
			end
		elseif key == "GetDescendants" then
			return function(s)
				local out = {}
				local function walk(x)
					for _, c in x._children do
						table.insert(out, c)
						walk(c)
					end
				end
				walk(s)
				return out
			end
		elseif key == "IsA" then
			return function(s, name)
				if name == "BasePart" then
					return s.ClassName == "Part"
				end
				return s.ClassName == name
			end
		end
		return nil
	end
	mt.__newindex = function(self, key, value)
		if key == "Parent" then
			local old = rawget(self, "_parent")
			if old then
				local i = table.find(old._children, self)
				if i then
					table.remove(old._children, i)
				end
			end
			rawset(self, "_parent", value)
			if value then
				table.insert(value._children, self)
			end
			return
		end
		rawset(self, key, value)
	end
	return setmetatable(inst, mt)
end

local CFRAME_MT = {}
CFRAME_MT.__mul = function(a: any, b: any): any
	return setmetatable({ __kind = "Product", args = { a, b } }, CFRAME_MT)
end

local function loadFakeSushiBody(): any
	local chunk = luau.load(SUSHI_SOURCE, {
		debugName = "SushiBody(fake)",
		environment = {
			script = Shared.SushiBody,
			require = function(m: any)
				return RobloxRequire.require(m)
			end,
			Instance = { new = newFakeInstance },
			Vector3 = fakeValue("Vector3"),
			Vector2 = fakeValue("Vector2"),
			Color3 = {
				fromRGB = function(r, g, b)
					return { R = r, G = g, B = b }
				end,
			},
			CFrame = {
				new = function(...)
					return setmetatable({ __kind = "CFrame", args = { ... } }, CFRAME_MT)
				end,
				Angles = function(...)
					return setmetatable({ __kind = "Angles", args = { ... } }, CFRAME_MT)
				end,
			},
			ColorSequence = fakeValue("ColorSequence"),
			NumberSequence = fakeValue("NumberSequence"),
			NumberRange = fakeValue("NumberRange"),
			Enum = proxyEnum(""),
		},
	})
	return chunk()
end

return function(t: Test.Test)
	---------------------------------------------------------------- 리모트 인자 검증
	t.test("QA EquipSkin: 문자열이 아닌 인자는 '없는 스킨', 프로필을 안 바꿔요", function()
		for i, bad in { nil, 5, true, {}, { "salmon" } } :: { any } do
			local h = harness()
			local p = withProfile(h, i, 0, { "salmon" })
			local ok, err = h.invoke("EquipSkin", p, bad)
			t.eq(ok, false, `arg {i}`)
			t.eq(err, ShopLogic.message("UnknownSkin"))
			t.eq(h.updates, 0)
			t.eq(#h.refreshed, 0)
		end
	end)

	t.test("QA BuyWithCoins: 문자열이 아닌 인자·모르는 id는 거절, 코인 그대로", function()
		for i, bad in { 5, {}, "no-such-skin", "" } :: { any } do
			local h = harness()
			local p, profile = withProfile(h, i, 5000)
			local ok = h.invoke("BuyWithCoins", p, bad)
			t.eq(ok, false, `arg {i}`)
			t.eq(profile.coins, 5000)
			t.eq(h.updates, 0)
		end
	end)

	t.test(
		"QA EquipSkin: 미보유 거절, 보유하면 저장 + 다시 입힘, 같은 스킨이면 update 없이 성공",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 0, { "salmon" })
			local ok, err = h.invoke("EquipSkin", p, "tuna")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("NotOwned"))
			h.advance(COOLDOWN)
			ok = h.invoke("EquipSkin", p, "salmon")
			t.eq(ok, true)
			t.eq(profile.equippedSkin, "salmon")
			t.eq(#h.refreshed, 1)
			h.advance(COOLDOWN)
			local before = h.updates
			ok = h.invoke("EquipSkin", p, "salmon")
			t.eq(ok, true)
			t.eq(h.updates, before)
			h.advance(COOLDOWN)
			ok = h.invoke("EquipSkin", p, "tamago") -- 기본으로 돌아가기
			t.eq(ok, true)
			t.eq(profile.equippedSkin, "tamago")
		end
	)

	t.test(
		"QA 요청 간격: 0.3초 안 두 번째 요청은 거절, EquipSkin·BuyWithCoins가 같이 써요",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 1000, { "salmon" })
			t.eq((h.invoke("EquipSkin", p, "salmon")), true)
			local ok, err = h.invoke("BuyWithCoins", p, "tuna")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("TooFast"))
			t.eq(profile.coins, 1000)
			h.advance(COOLDOWN)
			t.eq((h.invoke("BuyWithCoins", p, "tuna")), true)
			t.eq(profile.coins, 700)
			-- 다른 사람은 따로 세요
			local q = withProfile(h, 2, 0, { "salmon" })
			t.eq((h.invoke("EquipSkin", q, "salmon")), true)
		end
	)

	---------------------------------------------------------------- 코인 해금 원자성
	t.test(
		"QA BuyWithCoins: 연타(간격 지난 뒤 재요청)해도 한 번만 차감, 두 번째는 '이미 있음'",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 1000)
			t.eq((h.invoke("BuyWithCoins", p, "salmon")), true)
			t.eq(profile.coins, 700)
			t.eq(profile.ownedSkins.salmon, true)
			t.eq(profile.equippedSkin, "salmon")
			t.eq(h.updates, 1, "update 한 번")
			t.eq(h.saves, 1, "바로 저장")
			t.eq(#h.refreshed, 1)
			h.advance(COOLDOWN)
			local ok, err = h.invoke("BuyWithCoins", p, "salmon")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("AlreadyOwned"))
			t.eq(profile.coins, 700)
		end
	)

	t.test(
		"QA BuyWithCoins: 300으로 두 개를 사려 하면 두 번째는 '🍚 300개 더', 음수 없음",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 300)
			t.eq((h.invoke("BuyWithCoins", p, "salmon")), true)
			h.advance(COOLDOWN)
			local ok, err = h.invoke("BuyWithCoins", p, "tuna")
			t.eq(ok, false)
			t.eq(err, "🍚 300개 더 필요해요")
			t.eq(profile.coins, 0)
			t.eq(profile.ownedSkins.tuna, nil)
		end
	)

	t.test(
		"QA BuyWithCoins: 299 코인 → '🍚 1개 더 필요해요', 전설 → '코인으로는 살 수 없어요'",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 299)
			local ok, err = h.invoke("BuyWithCoins", p, "shrimp")
			t.eq(ok, false)
			t.eq(err, "🍚 1개 더 필요해요")
			h.advance(COOLDOWN)
			profile.coins = 99999
			ok, err = h.invoke("BuyWithCoins", p, "dragon-roll")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("NotForCoins"))
			t.eq(profile.coins, 99999)
			t.eq(profile.ownedSkins["dragon-roll"], nil)
		end
	)

	t.test(
		"BuyWithCoins 레어: 899 → '🍚 1개 더', 900 → 해금·장착, 다시 하면 '이미 있음'(한 번만 차감)",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 899)
			local ok, err = h.invoke("BuyWithCoins", p, "eel")
			t.eq(ok, false)
			t.eq(err, "🍚 1개 더 필요해요")
			t.eq(profile.coins, 899)
			t.eq(profile.ownedSkins.eel, nil)
			h.advance(COOLDOWN)
			profile.coins = 900
			t.eq((h.invoke("BuyWithCoins", p, "eel")), true)
			t.eq(profile.coins, 0)
			t.eq(profile.ownedSkins.eel, true)
			t.eq(profile.equippedSkin, "eel")
			h.advance(COOLDOWN)
			profile.coins = 5000
			ok, err = h.invoke("BuyWithCoins", p, "eel")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("AlreadyOwned"))
			t.eq(profile.coins, 5000)
		end
	)

	t.test(
		"QA BuyWithCoins: 프로필이 update 직전에 바뀌어도(코인 감소) 안에서 다시 판단해요",
		function()
			-- 앞 판단(get) 뒤 update 안에서 재판단: 그 사이 다른 차감이 있었던 상황을 흉내
			local profile = ProfileSchema.new()
			profile.coins = 500
			local first = ShopLogic.canBuyWithCoins("salmon", profile, true)
			t.eq(first.ok, true)
			profile.coins = 100 -- 그 사이 다른 곳에서 씀
			local decision = ShopLogic.buyWithCoins(profile, "salmon", true)
			t.eq(decision.ok, false)
			t.eq(profile.coins, 100)
			t.eq(profile.ownedSkins.salmon, nil)
		end
	)

	t.test(
		"QA ShopService 소스: 코인 해금은 update 콜백 안에서 ShopLogic.buyWithCoins로 판단·차감해요",
		function()
			t.ok(
				string.find(
					SHOP_SOURCE,
					"DataService.update%(player, function%(p%)%s*decision = ShopLogic.buyWithCoins%(p,"
				) ~= nil,
				"buyWithCoins inside update"
			)
			-- 서버 파일 어디서도 coins를 직접 빼지 않아요
			t.eq(string.find(SHOP_SOURCE, "coins -=", 1, true), nil)
			t.eq(string.find(SHOP_SOURCE, "task.wait", 1, true), nil)
		end
	)

	---------------------------------------------------------------- 저장 불가
	t.test(
		"QA canPersist=false: 실제 서버는 '저장이 안 되는 상태예요', Studio는 허용(저장 호출 없음)",
		function()
			local h = harness()
			h.persist = false
			local p, profile = withProfile(h, 1, 600)
			local ok, err = h.invoke("BuyWithCoins", p, "salmon")
			t.eq(ok, false)
			t.eq(err, ShopLogic.message("CannotSave"))
			t.eq(profile.coins, 600)
			t.eq(profile.ownedSkins.salmon, nil)

			local s = harness()
			s.persist = false
			s.studio = true
			local sp, sprofile = withProfile(s, 1, 600)
			t.eq((s.invoke("BuyWithCoins", sp, "salmon")), true)
			t.eq(sprofile.coins, 300)
			t.eq(s.saves, 0, "임시 프로필은 saveNow 안 불러요")
		end
	)

	t.test("QA 프로필 없음: 두 리모트 모두 '프로필을 불러오는 중이에요'", function()
		local h = harness()
		local p = newPlayer(9)
		local ok, err = h.invoke("EquipSkin", p, "tamago")
		t.eq(ok, false)
		t.eq(err, ShopLogic.message("NoProfile"))
		h.advance(COOLDOWN)
		ok, err = h.invoke("BuyWithCoins", p, "salmon")
		t.eq(ok, false)
		t.eq(err, ShopLogic.message("NoProfile"))
	end)

	t.test("QA 핸들러 에러는 pcall로 막고 '다시 해 주세요'", function()
		local h = harness()
		local p = withProfile(h, 1, 0)
		h.getThrows = true
		local ok, err = h.invoke("EquipSkin", p, "tamago")
		t.eq(ok, false)
		t.eq(err, "다시 해 주세요")
	end)

	---------------------------------------------------------------- 잠금
	t.test("QA 잠금: 배치된 레이서는 장착·해금 모두 거절, 코인 그대로", function()
		local h = harness()
		local p, profile = withProfile(h, 1, 600, { "tuna" })
		h.placed[p] = true
		local ok, err = h.invoke("EquipSkin", p, "tuna")
		t.eq(ok, false)
		t.eq(err, "매치가 끝나면 바꿀 수 있어요")
		h.advance(COOLDOWN)
		ok, err = h.invoke("BuyWithCoins", p, "salmon")
		t.eq(ok, false)
		t.eq(err, "매치가 끝나면 바꿀 수 있어요")
		t.eq(profile.coins, 600)
		t.eq(profile.ownedSkins.salmon, nil)
		t.eq(#h.refreshed, 0)
		-- 통과·탈락해서 배치가 풀리면 됨 (대기석·관전)
		h.placed[p] = nil
		h.advance(COOLDOWN)
		t.eq((h.invoke("EquipSkin", p, "tuna")), true)
	end)

	t.test(
		"QA 잠금: 탈락 연출(EliminationCutscene)·우승(VictoryDuration+1) 동안, 퇴장(Left)은 잠그지 않아요",
		function()
			local h = harness()
			local p = withProfile(h, 1, 0, { "tuna", "salmon" })
			local onResult = h.onResult :: any
			onResult("room1", { userId = 1, result = "Eliminated", cause = "Fall" })
			local ok = h.invoke("EquipSkin", p, "tuna")
			t.eq(ok, false, "탈락 연출 중")
			h.advance(Config.Match.EliminationCutscene + 0.01)
			t.eq((h.invoke("EquipSkin", p, "tuna")), true, "연출 뒤 관전 중")

			h.advance(COOLDOWN)
			onResult("room1", { userId = 1, result = "Won" })
			t.eq((h.invoke("EquipSkin", p, "salmon")), false, "우승 연출 중")
			h.advance(Config.Match.VictoryDuration + 1.01)
			t.eq((h.invoke("EquipSkin", p, "salmon")), true, "우승 연출 뒤")

			local q = withProfile(h, 2, 0, { "tuna" })
			onResult("room1", { userId = 2, result = "Eliminated", cause = "Left" })
			t.eq((h.invoke("EquipSkin", q, "tuna")), true)
		end
	)

	---------------------------------------------------------------- grantSkin (m4-14 준비)
	t.test(
		"QA grantSkin: 모르는 id·프로필 없음 → false, 잠금 중 equip은 보유만, 아니면 장착 + 다시 입힘",
		function()
			local h = harness()
			local p, profile = withProfile(h, 1, 0)
			t.eq(h.shop.grantSkin(p, "no-such-skin", true), false)
			t.eq(h.shop.grantSkin(newPlayer(77), "eel", true), false)
			h.placed[p] = true
			t.eq(h.shop.grantSkin(p, "eel", true), true)
			t.eq(profile.ownedSkins.eel, true)
			t.eq(profile.equippedSkin, "tamago", "잠금 중엔 장착 안 함")
			t.eq(#h.refreshed, 0)
			h.placed[p] = nil
			t.eq(h.shop.grantSkin(p, "uni", true), true)
			t.eq(profile.equippedSkin, "uni")
			t.eq(#h.refreshed, 1)
			-- 같은 스킨을 다시 지급(결제 재시도)해도 true, 코인 변화 없음
			t.eq(h.shop.grantSkin(p, "uni", true), true)
			t.eq(profile.coins, 0)
			t.eq(h.saves, 0, "grantSkin은 저장하지 않아요 (m4-14가 saveNow)")
		end
	)

	t.test(
		"QA grantSkin: 임시 프로필(canPersist=false)에도 true를 돌려줘요 → m4-14는 saveNow 결과로 영수증 처리해야 함",
		function()
			local h = harness()
			h.persist = false
			local p = withProfile(h, 1, 0)
			t.eq(h.shop.grantSkin(p, "eel", false), true)
		end
	)

	---------------------------------------------------------------- resolver
	t.test("QA resolver: 카탈로그에 있고 보유한 equippedSkin만, 아니면 nil(기본)", function()
		local h = harness()
		local resolver = h.resolver :: any
		t.ok(resolver ~= nil)
		local p, profile = withProfile(h, 1, 0, { "salmon" })
		profile.equippedSkin = "salmon"
		t.eq(resolver(p), "salmon")
		profile.equippedSkin = "eel" -- 미보유 (조작된 저장값)
		t.eq(resolver(p), nil)
		profile.ownedSkins["old-skin"] = true
		profile.equippedSkin = "old-skin" -- 카탈로그에서 빠진 스킨
		t.eq(resolver(p), nil)
		t.eq(resolver(newPlayer(42)), nil)
	end)

	---------------------------------------------------------------- 외형 단일 지점
	t.test(
		"QA 외형 단일 지점: AppearanceId를 쓰는 곳은 AppearanceService뿐 (서버·클라이언트·공용)",
		function()
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.match(name, "%.luau$") and path ~= "src/server/AppearanceService.luau" then
						local source = fs.readFile(path)
						t.eq(
							string.find(source, "SetAttribute(Attributes.AppearanceId", 1, true),
							nil,
							`{path} sets AppearanceId`
						)
					end
				end
			end
			scan("src")
		end
	)

	t.test(
		"QA 프로필 마이그레이션: 기본 스킨은 항상 보유 → 언제든 계란초밥으로 돌아갈 수 있어요",
		function()
			local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
			local profile = ProfileLogic.migrate({ version = 1, coins = 0, ownedSkins = { salmon = true } })
			t.eq(profile.ownedSkins[Config.Appearance.Default], true)
			local ok = ShopLogic.canEquip(Config.Appearance.Default, profile.ownedSkins)
			t.eq(ok, true)
		end
	)

	---------------------------------------------------------------- 공정성: 실제 build 결과
	t.test(
		"QA 공정성: 16종 build — 모든 파츠 Massless·충돌·쿼리·터치 없음, Body만 앵커, 효과 1개 이하",
		function()
			local SushiBody = loadFakeSushiBody()
			for _, skin in Skins.LIST do
				local model = SushiBody.build(skin.id)
				local parts, effects, bodies = 0, 0, 0
				for _, inst in model:GetDescendants() do
					if inst.ClassName == "Part" then
						parts += 1
						t.eq(inst.Massless, true, `{skin.id} {inst.Name} Massless`)
						t.eq(inst.CanCollide, false, `{skin.id} {inst.Name} CanCollide`)
						t.eq(inst.CanQuery, false, `{skin.id} {inst.Name} CanQuery`)
						t.eq(inst.CanTouch, false, `{skin.id} {inst.Name} CanTouch`)
						if inst.Name == "Body" then
							bodies += 1
							t.eq(inst.Anchored, true)
						else
							t.eq(inst.Anchored, false, `{skin.id} {inst.Name} Anchored`)
						end
					elseif
						inst.ClassName == "ParticleEmitter"
						or inst.ClassName == "Sparkles"
						or inst.ClassName == "Fire"
						or inst.ClassName == "PointLight"
						or inst.ClassName == "SpotLight"
					then
						effects += 1
					end
				end
				t.eq(bodies, 1, skin.id)
				t.eq(parts, #RealSushiBody.layout(skin.id), `{skin.id} part count`)
				t.ok(effects <= 1, `{skin.id} effects {effects}`)
				t.eq(model.PrimaryPart and model.PrimaryPart.Name, "Body", skin.id)
				-- 효과를 끄면 전부 꺼져요 (탈락 연출이 진짜 캐릭터를 숨길 때)
				SushiBody.setEffectsEnabled(model, false)
				for _, inst in model:GetDescendants() do
					if inst.ClassName == "ParticleEmitter" or inst.ClassName == "Sparkles" then
						t.eq(inst.Enabled, false, skin.id)
					end
				end
			end
		end
	)

	t.test(
		"QA 공정성: 외곽 비율 기록 — 최대 축 비율이 1.15 이하, 모든 스킨 발바닥 높이 같음",
		function()
			local function extents(id: string): { number }
				local b = RealSushiBody.bounds(RealSushiBody.layout(id))
				return { b.max[1] - b.min[1], b.max[2] - b.min[2], b.max[3] - b.min[3] }
			end
			local base = extents("tamago")
			local worst, worstId = 0, ""
			for _, skin in Skins.LIST do
				local e = extents(skin.id)
				for axis = 1, 3 do
					local r = math.abs(e[axis] / base[axis] - 1)
					if r > worst then
						worst, worstId = r, `{skin.id}#{axis}`
					end
				end
			end
			t.ok(worst <= 0.15 + 1e-9, `worst {worstId} {worst}`)
		end
	)

	t.test(
		"QA m4-14 준비: forProduct는 productId가 채워지면 그 스킨을 돌려주고 validate가 중복을 잡아요",
		function()
			local eel = Skins.get("eel") :: any
			local uni = Skins.get("uni") :: any
			eel.productId = 111
			local found = Skins.forProduct(111)
			local ok1 = Skins.validate(Skins.LIST)
			uni.productId = 111
			local ok2 = Skins.validate(Skins.LIST)
			eel.productId = nil
			uni.productId = nil
			t.eq(found, eel)
			t.eq(ok1, true)
			t.eq(ok2, false, "duplicate productId")
			t.eq(Skins.forProduct(111), nil)
		end
	)
end
