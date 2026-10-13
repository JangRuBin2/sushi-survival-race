--!strict
-- m5-03 QA (docs/qa/m5-03-foundation.md): 개발 테스트(m5-03-foundation·seasons·fx-catalog)에 없는 경계값과
-- 가짜 Roblox 환경에서 실제로 돌려 보는 확인.
--   맵 껍데기 3개: build(스폰 24개·바닥·결승선) / start(낙하·결승선) / ikura-bombs overtime(바로 돌아옴, 시간 뒤 판 제거)
--   껍데기 서비스: OfferService·CodeService 리모트가 아무 인자에도 false, "준비 중이에요"
--   DataService.setViewExtra: 바뀔 때만 ProfileUpdated, 로드 전 기억, 나간 뒤 무시
--   프로필 v2 경계: v1 두 번 migrate, 칸 모양이 틀린 v2 칸, redeemedCodes 정확히 200·201
--   관리자 명령 등급: canRun 12칸 전부, commandTier 대소문자·특수 키

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AdminLogic = RobloxRequire.require(Shared.AdminLogic)
local Config = RobloxRequire.require(Shared.Config)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)

---------------------------------------------------------------- 공통 가짜 도구 (m4-01-qa와 같은 방식)

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
	return signal
end

local function newTask(): any
	local deferred: { any } = {}
	local delayed: { any } = {}
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
	function T.delay(seconds: number, fn, ...)
		local entry = { seconds = seconds, fn = fn, args = table.pack(...) }
		table.insert(delayed, entry)
		return entry
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
	T.delayed = delayed
	return T
end

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

---------------------------------------------------------------- 가짜 지오메트리 (회전 없는 CFrame)

local Vector3: any = {}
local vectorMeta: any = {}
vectorMeta.__index = vectorMeta
vectorMeta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.new(x: number?, y: number?, z: number?): any
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta)
end

local CFrame: any = {}
local cframeMeta: any = {}
cframeMeta.__index = cframeMeta
cframeMeta.__mul = function(a, b)
	return CFrame.new(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
end
function cframeMeta.PointToObjectSpace(self, point)
	return point - self.Position
end
function CFrame.new(x: number?, y: number?, z: number?): any
	return setmetatable({ Position = Vector3.new(x, y, z) }, cframeMeta)
end

local function newInstance(className: string): any
	local props: { [string]: any } = { ClassName = className, Name = className }
	local children: { any } = {}
	local inst: any
	inst = setmetatable({}, {
		__index = function(_, key: string)
			if key == "__children" then
				return children
			elseif key == "GetChildren" then
				return function()
					return table.clone(children)
				end
			elseif key == "FindFirstChild" then
				return function(_, name: string)
					for _, child in children do
						if child.Name == name then
							return child
						end
					end
					return nil
				end
			elseif key == "IsA" then
				return function(_, cls: string)
					return cls == className or (cls == "BasePart" and className == "Part")
				end
			end
			return props[key]
		end,
		__newindex = function(_, key: string, value: any)
			if key == "Parent" then
				local old = props.Parent
				if old then
					local index = table.find(old.__children, inst)
					if index then
						table.remove(old.__children, index)
					end
				end
				if value then
					table.insert(value.__children, inst)
				end
			end
			props[key] = value
		end,
	})
	return inst
end

local MAP_TYPES_TOKEN = { __mapTypes = true }

type MapEnv = { map: any, T: any, heartbeat: any }

local function loadMap(file: string): MapEnv
	local T = newTask()
	local heartbeat = newSignal()
	local map = load(`src/shared/maps/{file}.luau`, {
		script = { Parent = { MapTypes = MAP_TYPES_TOKEN } },
		require = function(target: any): any
			assert(target == MAP_TYPES_TOKEN, "map shell should only require MapTypes")
			return {}
		end,
		Instance = { new = newInstance },
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = {
			fromRGB = function(r: number, g: number, b: number)
				return { r, g, b }
			end,
		},
		Enum = setmetatable({}, {
			__index = function(_, enumName: string)
				return setmetatable({}, {
					__index = function(_, item: string)
						return `{enumName}.{item}`
					end,
				})
			end,
		}),
		game = {
			GetService = function(_, name: string)
				assert(name == "RunService", name)
				return { Heartbeat = heartbeat }
			end,
		},
		task = T,
	})
	return { map = map, T = T, heartbeat = heartbeat }
end

local ORIGIN_X, ORIGIN_Y, ORIGIN_Z = 2000, 300, 4000

local function origin(): any
	return CFrame.new(ORIGIN_X, ORIGIN_Y, ORIGIN_Z)
end

-- 스폰 중심이 바닥 윗면(로컬 y 0)에 있고, 스폰 발판(2×2) 전체가 바닥 가장자리 안쪽 margin 이상인가
local function spawnOnFloor(spawn: any, floor: any, margin: number): boolean
	local s = spawn.CFrame.Position
	local f = floor.CFrame.Position
	local top = f.Y + floor.Size.Y / 2
	if math.abs((s.Y - spawn.Size.Y / 2) - top) > 0.01 then
		return false
	end
	local dx = math.abs(s.X - f.X) + spawn.Size.X / 2
	local dz = math.abs(s.Z - f.Z) + spawn.Size.Z / 2
	return dx <= floor.Size.X / 2 - margin and dz <= floor.Size.Z / 2 - margin
end

type Ctx = {
	ctx: any,
	passed: { any },
	eliminated: { any },
	cleanups: { any },
	setActive: (boolean) -> (),
}

local function newCtx(model: any, racers: { any }): Ctx
	local passed, eliminated, cleanups = {}, {}, {}
	local active = true
	local ctx = {
		model = model,
		origin = origin(),
		targetCount = 1,
		cleanup = {
			add = function(_, item)
				table.insert(cleanups, item)
				return item
			end,
		},
		isActive = function()
			return active
		end,
		getRacers = function()
			local list = {}
			for _, r in racers do
				if not table.find(passed, r) and not table.find(eliminated, r) then
					table.insert(list, r)
				end
			end
			return list
		end,
		pass = function(player)
			table.insert(passed, player)
		end,
		eliminate = function(player)
			table.insert(eliminated, player)
		end,
	}
	return {
		ctx = ctx,
		passed = passed,
		eliminated = eliminated,
		cleanups = cleanups,
		setActive = function(value: boolean)
			active = value
		end,
	}
end

local function racerAt(name: string, x: number, y: number, z: number): any
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(ORIGIN_X + x, ORIGIN_Y + y, ORIGIN_Z + z)
	root.Parent = character
	return { Name = name, Character = character, root = root }
end

---------------------------------------------------------------- DataService (메모리 모드)

type DataEnv = {
	DataService: any,
	T: any,
	sent: { { player: any, view: any } },
	add: (player: any) -> (),
	newPlayer: (userId: number) -> any,
	leave: (player: any) -> (),
}

local function loadDataService(): DataEnv
	local T = newTask()
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
				return 100
			end,
			time = os.time,
		},
		warn = function() end,
	})
	DataService.init()
	DataService.start()
	return {
		DataService = DataService,
		T = T,
		sent = sent,
		newPlayer = function(userId: number): any
			return { UserId = userId, Name = `P{userId}`, Parent = Players }
		end,
		add = function(player: any)
			table.insert(list, player)
			Players.PlayerAdded:Fire(player)
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
end

---------------------------------------------------------------- 껍데기 서비스

local function loadShellService(path: string): ({ [string]: any }, any)
	local fns: { [string]: any } = {}
	local codeConfigLoads = 0
	local service = load(path, {
		game = {
			GetService = function(_, name: string)
				assert(name == "ReplicatedStorage", name)
				return { Shared = sharedFolder() }
			end,
		},
		script = { Parent = { CodeConfig = { __shared = "CodeConfig" } } },
		require = fakeRequire({
			Remotes = {
				fn = function(name: string)
					fns[name] = fns[name] or {}
					return fns[name]
				end,
				event = function(name: string)
					error(`shell service should not touch RemoteEvent {name}`)
				end,
			},
			CodeConfig = {
				load = function()
					codeConfigLoads += 1
					return {}
				end,
			},
		}),
	})
	service.init()
	service.start()
	return fns, codeConfigLoads
end

local function v1Profile(): { [string]: any }
	return {
		version = 1,
		coins = 1234,
		wins = 12,
		matchesPlayed = 40,
		ownedSkins = { tamago = true, salmon = true },
		equippedSkin = "salmon",
		settings = { muteLevel = 2 },
		receipts = { { id = "purchase-1", at = 100 } },
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- 맵 껍데기 build
	t.test("QA 껍데기 build: ikura-bombs 스폰 24개가 전부 바닥 위(가장자리 1 stud 이상)", function()
		-- tempura-pot은 m5-05에서 실제 맵이 돼서 빠졌어요 (스폰·경로는 tests/map-tempura-pot.spec.luau)
		for _, case in { { "IkuraBombs", "Plate" } } do
			local env = loadMap(case[1])
			local model = env.map.build(origin())
			t.eq(model.Name, env.map.id)
			local floor = model:FindFirstChild(case[2])
			t.ok(floor and floor.CanCollide ~= false, `{case[1]} floor collides`)
			local spawns = model:FindFirstChild("Spawns"):GetChildren()
			t.eq(#spawns, 24, case[1])
			local names = {}
			for _, spawn in spawns do
				t.ok(spawnOnFloor(spawn, floor, 1), `{case[1]} {spawn.Name} on the floor`)
				t.eq(spawn.CanCollide, false, `{spawn.Name} no collision`)
				names[spawn.Name] = true
			end
			for i = 1, 24 do
				t.ok(names[string.format("Spawn%02d", i)], `{case[1]} Spawn{i} name sorts in order`)
			end
		end
	end)

	t.test(
		"QA 껍데기 build: dessert-fridge 결승선은 출발선에서 160 앞, 혼자~12명 스폰(1~12번)은 바닥 위",
		function()
			-- 13~24번은 바닥 끝 걸침·밖 (QA 리포트 B1, P3 — m5-06 AC1 "스폰은 A 구간 안"이 덮어쓰며 고침).
			-- 여기서는 고쳐질 부분을 기대값으로 고정하지 않고, 지금 맞는 부분만 확인해요.
			local env = loadMap("DessertFridge")
			local model = env.map.build(origin())
			local floor = model:FindFirstChild("Floor")
			local spawns = model:FindFirstChild("Spawns"):GetChildren()
			table.sort(spawns, function(a, b)
				return a.Name < b.Name
			end)
			t.eq(#spawns, 24)
			for i = 1, 12 do
				t.ok(spawnOnFloor(spawns[i], floor, 1), `{spawns[i].Name} on the floor`)
			end
			local finish = model:FindFirstChild("FinishLine")
			t.ok(finish ~= nil, "FinishLine")
			t.eq(finish.CFrame.Position.Z - ORIGIN_Z, -160)
			t.eq(finish.CanCollide, false)
			-- 결승선 너머에도 바닥이 있어요 (통과 직후 떨어지지 않게)
			t.ok(floor.CFrame.Position.Z - floor.Size.Z / 2 - ORIGIN_Z < -160, "floor extends past the finish")
		end
	)

	---------------------------------------------------------------- 맵 껍데기 start
	t.test(
		"QA 껍데기 start: 낙하 25 아래면 탈락, 판 위면 그대로, 끝난 라운드에는 판정 안 함",
		function()
			-- tempura-pot은 m5-05 실제 맵(기름 높이 판정)이라 빠졌어요
			for _, file in { "IkuraBombs", "DessertFridge" } do
				local env = loadMap(file)
				local model = env.map.build(origin())
				local safe = racerAt("safe", 0, 3, -40)
				local edge = racerAt("edge", 0, -24.9, -40)
				local fallen = racerAt("fallen", 0, -25.1, -40)
				local c = newCtx(model, { safe, edge, fallen })
				env.map.start(c.ctx)
				t.eq(#c.cleanups, 1, `{file}: heartbeat connection is in ctx.cleanup`)
				env.heartbeat:Fire()
				t.eq(c.eliminated, { fallen }, file)
				t.eq(#c.passed, 0, file)
				c.setActive(false)
				safe.root.Position = Vector3.new(ORIGIN_X, ORIGIN_Y - 100, ORIGIN_Z)
				env.heartbeat:Fire()
				t.eq(#c.eliminated, 1, `{file}: inactive round ignores falls`)
			end
		end
	)

	t.test("QA 껍데기 start: dessert-fridge 결승선(-Z 160)에서 통과, 159.9는 아직", function()
		local env = loadMap("DessertFridge")
		local model = env.map.build(origin())
		local near = racerAt("near", 0, 3, -159.9)
		local over = racerAt("over", 5, 3, -160)
		local c = newCtx(model, { near, over })
		env.map.start(c.ctx)
		env.heartbeat:Fire()
		t.eq(c.passed, { over })
		t.eq(#c.eliminated, 0)
	end)

	---------------------------------------------------------------- ikura-bombs 연장전
	t.test("QA ikura-bombs overtime: 바로 돌아오고, collapseDuration 뒤에 접시가 사라져요", function()
		local env = loadMap("IkuraBombs")
		local model = env.map.build(origin())
		local c = newCtx(model, {})
		env.map.start(c.ctx)
		local plate = model:FindFirstChild("Plate")
		local co = coroutine.create(env.map.overtime)
		local ok = coroutine.resume(co, c.ctx, { collapseDuration = 20 })
		t.ok(ok, "overtime ran")
		t.eq(coroutine.status(co), "dead", "overtime returns without yielding (task.wait 금지)")
		t.eq(#env.T.delayed, 1)
		local entry = env.T.delayed[1]
		t.eq(entry.seconds, 20)
		t.ok(table.find(c.cleanups, entry) ~= nil, "delay thread is in ctx.cleanup")
		t.eq(plate.CanCollide ~= false, true, "plate still there before the delay")
		entry.fn()
		t.eq(plate.CanCollide, false)
		t.eq(plate.Transparency, 1)
		-- 판이 사라진 뒤 떨어진 사람은 start의 낙하 판정으로 탈락
		local faller = racerAt("faller", 0, -30, -40)
		local c2 = newCtx(model, { faller })
		env.map.start(c2.ctx)
		env.heartbeat:Fire()
		t.eq(c2.eliminated, { faller })
	end)

	t.test(
		"QA ikura-bombs overtime: 라운드가 먼저 끝나면(isActive false) 접시를 건드리지 않아요",
		function()
			local env = loadMap("IkuraBombs")
			local model = env.map.build(origin())
			local c = newCtx(model, {})
			env.map.overtime(c.ctx, { collapseDuration = 5 })
			c.setActive(false)
			env.T.delayed[1].fn()
			local plate = model:FindFirstChild("Plate")
			t.ok(plate.CanCollide ~= false, "plate kept")
			t.ok(plate.Transparency ~= 1, "plate visible")
		end
	)

	---------------------------------------------------------------- 껍데기 서비스
	t.test(
		"QA 껍데기 서비스: RequestOfferPurchase·EquipFx·RedeemCode는 어떤 인자에도 false, '준비 중이에요'",
		function()
			local offerFns = loadShellService("src/server/OfferService.luau")
			local codeFns, loads = loadShellService("src/server/CodeService.luau")
			t.eq(loads, 1, "CodeService reads the code list once at init")
			local junk =
				{ { "starter-pack" }, {}, { 5 }, { nil, "x" }, { { nested = true } }, { string.rep("A", 10000) } }
			for _, case in
				{
					{ offerFns, "RequestOfferPurchase" },
					{ offerFns, "EquipFx" },
					{ codeFns, "RedeemCode" },
				}
			do
				local handler = case[1][case[2]].OnServerInvoke
				t.eq(type(handler), "function", case[2])
				for _, args in junk do
					local ok, err = handler({ UserId = 1 }, table.unpack(args))
					t.eq(ok, false, case[2])
					t.eq(err, "준비 중이에요", case[2])
				end
			end
		end
	)

	---------------------------------------------------------------- DataService.setViewExtra
	t.test("QA setViewExtra: vip가 바뀔 때만 ProfileUpdated 한 번, boolean이 아니면 false", function()
		local env = loadDataService()
		local p = env.newPlayer(1)
		env.add(p)
		env.T.flush()
		t.ok(#env.sent >= 1, "initial view sent")
		t.eq(env.sent[#env.sent].view.vip, false, "default vip false")
		table.clear(env.sent)

		env.DataService.setViewExtra(p, { vip = true })
		env.DataService.setViewExtra(p, { vip = true })
		env.T.flush()
		t.eq(#env.sent, 1, "one update for a change")
		t.eq(env.sent[1].view.vip, true)

		env.DataService.setViewExtra(p, { vip = true })
		env.T.flush()
		t.eq(#env.sent, 1, "same value → no resend")

		env.DataService.setViewExtra(p, { vip = "yes" } :: any)
		env.T.flush()
		t.eq(#env.sent, 2)
		t.eq(env.sent[2].view.vip, false, "non-boolean is not VIP")

		-- 다른 저장 변경에도 vip가 그대로 실려요
		env.DataService.setViewExtra(p, { vip = true })
		env.T.flush()
		env.DataService.update(p, function(profile)
			profile.coins += 1
		end)
		env.T.flush()
		t.eq(env.sent[#env.sent].view.vip, true, "vip survives other updates")
	end)

	t.test("QA setViewExtra: 로드 전에 부르면 기억했다가 첫 화면에, 나간 뒤에는 무시", function()
		local env = loadDataService()
		local p = env.newPlayer(2)
		env.DataService.setViewExtra(p, { vip = true })
		env.T.flush()
		t.eq(#env.sent, 0, "nothing sent before the profile exists")
		env.add(p)
		env.T.flush()
		t.ok(#env.sent >= 1)
		t.eq(env.sent[#env.sent].view.vip, true, "remembered before load")

		env.leave(p)
		table.clear(env.sent)
		env.DataService.setViewExtra(p, { vip = false })
		env.T.flush()
		t.eq(#env.sent, 0, "left player gets nothing")
		-- 다른 사람에게는 영향이 없어요
		local q = env.newPlayer(3)
		env.add(q)
		env.T.flush()
		t.eq(env.sent[#env.sent].view.vip, false, "other players unaffected")
	end)

	---------------------------------------------------------------- 프로필 v2 경계
	t.test("QA 프로필: v1을 두 번 migrate해도 같고 notes가 없어요", function()
		local once, info1 = ProfileLogic.migrate(v1Profile())
		local twice, info2 = ProfileLogic.migrate(ProfileLogic.deepCopy(once))
		t.eq(twice, once)
		t.eq(#info1.notes, 0, table.concat(info1.notes, "; "))
		t.eq(#info2.notes, 0, table.concat(info2.notes, "; "))
		t.eq(twice.version, 2)
	end)

	t.test("QA 프로필: 모양이 틀린 v2 칸은 빈 값 + notes, 다른 칸은 그대로", function()
		local raw = v1Profile()
		raw.ownedFx = "all"
		raw.equippedFx = 7
		raw.eventTokens = true
		raw.boughtOffers = { [1] = 5 }
		local profile, info = ProfileLogic.migrate(raw)
		t.eq(profile.ownedFx, {})
		t.eq(profile.equippedFx, {})
		t.eq(profile.eventTokens, {})
		t.eq(profile.boughtOffers, {})
		t.ok(#info.notes >= 4, table.concat(info.notes, "; "))
		t.eq(profile.coins, 1234)
		t.eq(profile.ownedSkins, { tamago = true, salmon = true })
		t.eq(profile.equippedSkin, "salmon")
		t.eq(info.persistable, true)
	end)

	t.test("QA 프로필: equippedFx의 모르는 칸 이름은 버려요", function()
		local raw = v1Profile()
		raw.ownedFx = { ["cat-customer"] = true, fireworks = true }
		raw.equippedFx = { Elimination = "cat-customer", Lobby = "fireworks", Victory = "fireworks" }
		local profile = ProfileLogic.migrate(raw)
		t.eq(profile.equippedFx, { Elimination = "cat-customer", Victory = "fireworks" })
	end)

	t.test(
		"QA 프로필: redeemedCodes 정확히 200개는 다 남고, 201개면 가장 오래된 1개만 빠져요",
		function()
			local raw = v1Profile()
			local codes = {}
			for i = 1, 200 do
				codes[`C{i}`] = 1000 + i
			end
			raw.redeemedCodes = codes
			local profile, info = ProfileLogic.migrate(raw)
			local count = 0
			for _ in profile.redeemedCodes do
				count += 1
			end
			t.eq(count, 200)
			t.eq(#info.notes, 0, table.concat(info.notes, "; "))

			local raw2 = v1Profile()
			local codes2 = table.clone(codes)
			codes2.C0 = 500 -- 가장 오래됨
			raw2.redeemedCodes = codes2
			local p2 = ProfileLogic.migrate(raw2)
			local count2 = 0
			for _ in p2.redeemedCodes do
				count2 += 1
			end
			t.eq(count2, 200)
			t.eq(p2.redeemedCodes.C0, nil)
			t.eq(p2.redeemedCodes.C1, 1001)
		end
	)

	t.test(
		"QA 프로필: 미래 버전(3)은 새 칸 값이 이상해도 저장하지 않음이 유지돼요",
		function()
			local raw = v1Profile()
			raw.version = 3
			raw.ownedFx = { ["v3-only-fx"] = { tier = 2 } }
			local _, info = ProfileLogic.migrate(raw)
			t.eq(info.persistable, false)
		end
	)

	---------------------------------------------------------------- 관리자 명령 등급
	t.test("QA canRun: 등급 3 × Studio 여부 2 × 저장 켬 여부 2 = 12칸", function()
		local cases = {
			-- tier, isStudio, persist, ok, reason
			{ "Info", false, false, true, nil },
			{ "Info", false, true, true, nil },
			{ "Info", true, false, true, nil },
			{ "Info", true, true, true, nil },
			{ "Test", false, false, false, "StudioOnly" },
			{ "Test", false, true, false, "StudioOnly" },
			{ "Test", true, false, true, nil },
			{ "Test", true, true, true, nil },
			{ "StudioOnly", false, false, false, "StudioOnly" },
			{ "StudioOnly", false, true, false, "StudioOnly" },
			{ "StudioOnly", true, false, true, nil },
			{ "StudioOnly", true, true, false, "PersistOn" },
		}
		for _, c in cases do
			local ok, reason = AdminLogic.canRun(c[1], c[2], c[3])
			local label = `{c[1]} studio={c[2]} persist={c[3]}`
			t.eq(ok, c[4], label)
			t.eq(reason, c[5], label)
		end
	end)

	t.test(
		"QA commandTier: 대소문자·빈 문자열·표의 특수 키·비문자열은 모르는 명령",
		function()
			for _, bad in { "INFO", "Info", "", " info", "info ", "__index", "__newindex", "COMMAND_TIERS" } do
				t.eq(AdminLogic.commandTier(bad), nil, bad)
			end
			for _, bad in { nil, true, {}, 1.5, function() end } do
				t.eq(AdminLogic.commandTier(bad), nil, typeof(bad))
			end
			-- 실서버에서 통과하는 명령은 Info 등급뿐이에요
			for name, tier in AdminLogic.COMMAND_TIERS do
				local okLive = AdminLogic.canRun(tier, false, false)
				t.eq(okLive, tier == "Info", name)
			end
		end
	)
end
