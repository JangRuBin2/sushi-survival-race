--!strict
-- m5-04 QA (docs/qa/m5-04-map-ikura-bombs.md): 실제 IkuraBombs.luau를 가짜 Roblox 환경 + 가짜 스케줄러
-- (os.clock·task.wait·task.delay·task.spawn·Heartbeat:Wait를 시계 하나로)로 돌려 보는 확인.
--   폭발: 반경 안 넉백 방향·세기·PlatformStand 1초·MoveExempt·LinearVelocity 0.12초, 반경 밖·높이 차 밖은 무사
--   금 가기: 같은 바깥 칸 두 번 → 1초 경고 뒤 사라짐, 원판은 몇 번 맞아도 그대로
--   연장전: 바로 돌아옴, 고리 일정(1·10.5·20초)대로 사라지고 collapseDuration 뒤 충돌 파츠 0, 정해진 낙하 멈춤
--   낙하선 −30, 여러 방 동시, 라운드가 끝나면 폭탄·넉백 멈춤, 모든 스레드·연결이 ctx.cleanup에
--   순수 경계: bombWave 경계, pickTargets(레이서 0명·칸 0개·D4 한 명 + 3개), overtimeRings 경계

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.maps.IkuraBombsLayout)
local Logic = RobloxRequire.require(Shared.maps.IkuraBombsLogic)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

---------------------------------------------------------------- 가짜 스케줄러

type Sched = {
	clock: number,
	sleepers: { { co: thread, at: number, args: { any }? } },
	threads: { thread },
}

local function newSched(): Sched
	return { clock = 0, sleepers = {}, threads = {} }
end

local function resume(co: thread, ...: any)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)))
	end
end

local function newSignal(sched: Sched): any
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
	function signal:Wait()
		table.insert(sched.sleepers, { co = coroutine.running(), at = sched.clock + 1e-9 })
		return coroutine.yield()
	end
	return signal
end

local function newTask(sched: Sched): any
	return {
		spawn = function(fn: any, ...: any): thread
			local co = coroutine.create(fn)
			table.insert(sched.threads, co)
			resume(co, ...)
			return co
		end,
		delay = function(seconds: number, fn: any, ...: any): thread
			local co = coroutine.create(fn)
			table.insert(sched.threads, co)
			table.insert(sched.sleepers, { co = co, at = sched.clock + seconds, args = table.pack(...) })
			return co
		end,
		wait = function(seconds: number?): number
			table.insert(sched.sleepers, { co = coroutine.running(), at = sched.clock + (seconds or 0) })
			coroutine.yield()
			return seconds or 0
		end,
	}
end

---------------------------------------------------------------- 가짜 인스턴스

local BASE_PARTS = { Part = true }

local function newInstance(className: string): any
	local props: { [string]: any } = { ClassName = className, Name = className }
	local children: { any } = {}
	local attributes: { [string]: any } = {}
	local inst: any
	local methods: { [string]: any } = {}
	function methods.IsA(_, cls: string): boolean
		return cls == className or (cls == "BasePart" and BASE_PARTS[className] == true) or cls == "Instance"
	end
	function methods.GetChildren(_)
		return table.clone(children)
	end
	function methods.GetDescendants(_)
		local out = {}
		local function walk(list)
			for _, child in list do
				table.insert(out, child)
				walk(child.__children)
			end
		end
		walk(children)
		return out
	end
	function methods.FindFirstChild(_, name: string)
		for _, child in children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods.FindFirstChildOfClass(_, cls: string)
		for _, child in children do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end
	function methods.IsAncestorOf(_, other: any): boolean
		local p = other.Parent
		while p do
			if p == inst then
				return true
			end
			p = p.Parent
		end
		return false
	end
	function methods.Destroy(_)
		props.__destroyed = true
		inst.Parent = nil
	end
	function methods.GetAttribute(_, name: string)
		return attributes[name]
	end
	function methods.SetAttribute(_, name: string, value: any)
		attributes[name] = value
	end
	function methods.PivotTo(_, cf: any)
		props.__pivot = cf
	end
	function methods.Emit(_, n: number)
		props.__emitted = (props.__emitted or 0) + n
	end
	inst = setmetatable({}, {
		__index = function(_, key: string)
			if key == "__children" then
				return children
			end
			local m = methods[key]
			if m then
				return m
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

local enumStub = setmetatable({}, {
	__index = function(_, enumName: string)
		return setmetatable({}, {
			__index = function(_, item: string)
				return `{enumName}.{item}`
			end,
		})
	end,
})

local function newCollection(): any
	local tags: { [string]: { any } } = {}
	local service = { added = {} :: { [string]: number } }
	function service:AddTag(inst: any, tag: string)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], inst)
		service.added[tag] = (service.added[tag] or 0) + 1
	end
	function service:GetTagged(tag: string)
		return table.clone(tags[tag] or {})
	end
	return service
end

type Env = {
	map: any,
	sched: Sched,
	heartbeat: any,
	collection: any,
	exempt: { any },
	sfx: { string },
	step: (dt: number) -> (),
	runTo: (time: number) -> (),
}

local function loadEnv(): Env
	local sched = newSched()
	local heartbeat = newSignal(sched)
	local collection = newCollection()
	local exempt: { any } = {}
	local sfx: { string } = {}
	local stubs: { [string]: any } = {
		MapKit = {
			buildDecor = function()
				return {}
			end,
			decorFolder = function(model)
				local existing = model:FindFirstChild("Decor")
				if existing then
					return existing
				end
				local folder = newInstance("Folder")
				folder.Name = "Decor"
				folder.Parent = model
				return folder
			end,
			applyDecorRules = function(part)
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end,
			introCamera = function() end,
			attachStudioArt = function() end,
		},
		MapSfx = {
			play = function(_, cue)
				table.insert(sfx, cue)
			end,
		},
		MapTypes = {},
		MoveExempt = {
			mark = function(character, seconds)
				table.insert(exempt, { character = character, seconds = seconds })
			end,
		},
	}
	local function token(name: string): any
		return { __mod = name }
	end
	local parent = setmetatable(
		{ Parent = setmetatable({}, {
			__index = function(_, name: string)
				return token(name)
			end,
		}) },
		{
			__index = function(_, name: string)
				return token(name)
			end,
		}
	)
	local map = luau.load(fs.readFile("src/shared/maps/IkuraBombs.luau"), {
		debugName = "IkuraBombs",
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local name = target.__mod
				if stubs[name] ~= nil then
					return stubs[name]
				end
				return RobloxRequire.require((Shared :: any).maps[name])
			end,
			Instance = { new = newInstance },
			Vector3 = RV3,
			Vector2 = roblox.Vector2,
			CFrame = RCF,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			NumberSequence = roblox.NumberSequence,
			NumberRange = roblox.NumberRange,
			Enum = enumStub,
			task = newTask(sched),
			game = {
				GetService = function(_, name: string)
					if name == "RunService" then
						return { Heartbeat = heartbeat }
					elseif name == "CollectionService" then
						return collection
					end
					error(`unexpected service {name}`)
				end,
			},
			os = {
				clock = function()
					return sched.clock
				end,
			},
		},
	})()

	local function step(dt: number)
		sched.clock += dt
		heartbeat:Fire(dt)
		local ready = {}
		local keep = {}
		for _, s in sched.sleepers do
			if s.at <= sched.clock + 1e-9 then
				table.insert(ready, s)
			else
				table.insert(keep, s)
			end
		end
		sched.sleepers = keep
		table.sort(ready, function(a, b)
			return a.at < b.at
		end)
		for _, s in ready do
			if coroutine.status(s.co) == "suspended" then
				if s.args then
					resume(s.co, table.unpack(s.args :: any, 1, (s.args :: any).n))
				else
					resume(s.co)
				end
			end
		end
	end

	return {
		map = map,
		sched = sched,
		heartbeat = heartbeat,
		collection = collection,
		exempt = exempt,
		sfx = sfx,
		step = step,
		runTo = function(time: number)
			while sched.clock < time - 1e-9 do
				step(math.min(0.05, time - sched.clock))
			end
		end,
	}
end

-- 결정적 난수 (lune에는 Random이 없어요)
local function seededRng(seed: number): any
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self: any, min: number?, max: number?): number
			local lo, hi = min or 0, max or 1
			return lo + step() * (hi - lo)
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1))
		end,
	}
end

-- 조건이 참이 될 때까지 0.05초씩 (limit초 넘으면 실패)
local function runUntil(env: any, cond: () -> boolean, limit: number): number
	while not cond() do
		assert(env.sched.clock < limit, `condition not met before {limit}`)
		env.step(0.05)
	end
	return env.sched.clock
end

-- NextNumber() = 0 → 폭탄은 언제나 첫 레이서(지터 0) 위, NextInteger → 최솟값
local function zeroRng(): any
	return {
		NextNumber = function(_self: any, min: number?, _max: number?): number
			return min or 0
		end,
		NextInteger = function(_self: any, min: number, _max: number): number
			return min
		end,
	}
end

type Run = {
	env: Env,
	ctx: any,
	model: any,
	cleanup: { any },
	racers: { any },
	eliminated: { any },
	setActive: (boolean) -> (),
}

local ORIGIN = RCF.new(2000, 300, 0)

local function newRun(env: Env, origin: any, racers: { any }): Run
	local model = env.map.build(origin)
	local cleanupItems: { any } = {}
	local active = true
	local eliminated: { any } = {}
	local ctx = {
		model = model,
		origin = origin,
		rng = zeroRng(),
		targetCount = 1,
		cleanup = {
			add = function(_, item)
				table.insert(cleanupItems, item)
				return item
			end,
		},
		isActive = function()
			return active
		end,
		getRacers = function()
			return table.clone(racers)
		end,
		pass = function() end,
		eliminate = function(player)
			table.insert(eliminated, player)
			local index = table.find(racers, player)
			if index then
				table.remove(racers, index)
			end
		end,
	}
	return {
		env = env,
		ctx = ctx,
		model = model,
		cleanup = cleanupItems,
		racers = racers,
		eliminated = eliminated,
		setActive = function(value: boolean)
			active = value
		end,
	}
end

-- 레이서: origin 기준 로컬 (x, y, z)에 HumanoidRootPart
local function racerAt(origin: any, name: string, x: number, y: number, z: number): any
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = origin:PointToWorldSpace(RV3.new(x, y, z))
	root.Parent = character
	local attachment = newInstance("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = newInstance("Humanoid")
	humanoid.PlatformStand = false
	humanoid.Parent = character
	return { Character = character, Name = name, UserId = #name, root = root, humanoid = humanoid }
end

local function tileModel(model: any, id: number): any
	for _, child in model:GetChildren() do
		if child:GetAttribute("TileId") == id then
			return child
		end
	end
	error(`no tile {id}`)
end

local function tileSolid(tile: any): boolean
	for _, child in tile:GetChildren() do
		if child.ClassName == "Part" and child.Name == "Slab" and child.CanCollide ~= false then
			return true
		end
	end
	return false
end

-- model 안의 충돌 파츠 (설 수 있는 것)
local function solidParts(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d.ClassName == "Part" and d.CanCollide ~= false then
			table.insert(out, d)
		end
	end
	return out
end

local function ringSolid(model: any, ring: number): (number, number)
	local solid, total = 0, 0
	for _, child in model:GetChildren() do
		if child:GetAttribute("Ring") == ring then
			total += 1
			if tileSolid(child) then
				solid += 1
			end
		end
	end
	return solid, total
end

local function launchOf(root: any): any
	return root:FindFirstChild("IkuraLaunch")
end

local function near(t: Test.Test, a: number, b: number, eps: number, msg: string)
	t.ok(math.abs(a - b) <= eps, `{msg}: expected {b} got {a}`)
end

-- 바깥 고리 칸 7(0~36도) 가운데 각도 18도, 반지름 20
local A_DEG = 18
local A_R = 20

return function(t: Test.Test)
	---------------------------------------------------------------- build
	t.test(
		"QA build: 충돌 파츠는 전부 칸 Slab(17칸), 스폰·숟가락·경계선은 충돌 없음, 칸 윗면 = origin 높이",
		function()
			local env = loadEnv()
			local model = env.map.build(ORIGIN)
			local tiles = {}
			for _, part in solidParts(model) do
				t.eq(part.Name, "Slab", "only tile slabs collide")
				local tile = part.Parent
				t.ok(tile:GetAttribute("TileId") ~= nil, "slab belongs to a tile model")
				tiles[tile:GetAttribute("TileId")] = true
				local rel = ORIGIN:ToObjectSpace(part.CFrame)
				near(t, rel.Position.Y, -Layout.THICKNESS / 2, 1e-3, "slab centre y")
				t.ok(part.Anchored == true, "slab anchored")
			end
			local count = 0
			for _ in tiles do
				count += 1
			end
			t.eq(count, 17)
			t.eq(env.collection.added.IkuraTile, 17)
			t.eq(env.collection.added.IkuraSpoon, 1)
			local spawns = model:FindFirstChild("Spawns")
			t.eq(#spawns:GetChildren(), 24)
			-- 숟가락은 Decor 폴더 안 (판정 지오메트리 아님)
			local decor = model:FindFirstChild("Decor")
			t.ok(decor and decor:FindFirstChild("Spoon"), "spoon lives in Decor")
		end
	)

	---------------------------------------------------------------- 폭발 넉백
	t.test(
		"QA 폭발: 반경 안은 바깥 방향 넉백 + 넘어짐 1초 + MoveExempt 1.5, 반경 밖·높이 차 밖은 무사",
		function()
			local env = loadEnv()
			local ax, az = Layout.polar(A_R, A_DEG)
			local bx, bz = Layout.polar(A_R - 5, A_DEG) -- 폭발 중심에서 5 안쪽
			local cx, cz = Layout.polar(A_R - 8, A_DEG) -- 8: 반경 7 밖
			local a = racerAt(ORIGIN, "a", ax, 3, az)
			local b = racerAt(ORIGIN, "b", bx, 3, bz)
			local c = racerAt(ORIGIN, "c", cx, 3, cz)
			local d = racerAt(ORIGIN, "high", ax, 10, az) -- 높이 차 10 > 6
			local run = newRun(env, ORIGIN, { a, b, c, d })
			env.map.start(run.ctx)

			env.runTo(2.9)
			t.eq(env.collection.added.IkuraBomb, nil, "출발 3초 동안 폭탄 없음")
			env.runTo(3.05)
			t.eq(env.collection.added.IkuraBomb, 1, "3초에 첫 폭탄")
			env.runTo(4.45)
			t.eq(a.humanoid.PlatformStand, false, "경고 1.5초 동안은 아무 일 없음")
			local hitAt = runUntil(env, function()
				return a.humanoid.PlatformStand == true
			end, 4.7)
			t.eq(a.humanoid.PlatformStand, true)
			t.eq(b.humanoid.PlatformStand, true)
			t.eq(c.humanoid.PlatformStand, false, "반경 밖")
			t.eq(d.humanoid.PlatformStand, false, "높이 차 밖")
			t.eq(#env.exempt, 2)
			t.eq(env.exempt[1].seconds, 1.5)
			t.ok(table.find(env.sfx, "IkuraPop") ~= nil, "IkuraPop")

			-- a: 중심(거리 0) → 접시 중심 반대쪽(바깥) 50, 위 30
			local ua = RV3.new(ax, 0, az).Unit
			local va = launchOf(a.root).VectorVelocity
			near(t, va:Dot(ua), 50, 1e-3, "a outward")
			near(t, va.Y, 30, 1e-3, "a up")
			-- b: 폭발 중심에서 b 쪽(접시 안쪽) 50 × (1 − 0.4 × 5/7)
			local vb = launchOf(b.root).VectorVelocity
			near(t, vb:Dot(-ua), 50 * (1 - 0.4 * 5 / 7), 1e-3, "b pushed away from blast centre")
			near(t, vb.Y, 30, 1e-3, "b up")
			t.eq(launchOf(c.root), nil)

			env.runTo(hitAt + 0.2)
			t.eq(launchOf(a.root), nil, "LinearVelocity 0.12초 뒤 사라짐")
			env.runTo(hitAt + 0.9)
			t.eq(a.humanoid.PlatformStand, true, "1초 동안 넘어짐")
			env.runTo(hitAt + 1.1)
			t.eq(a.humanoid.PlatformStand, false, "1초 뒤 일어남")
			t.eq(b.humanoid.PlatformStand, false)
		end
	)

	t.test("QA 폭발: 돌린 origin에서도 넉백이 월드 기준 바깥 방향", function()
		local env = loadEnv()
		local origin = RCF.new(4000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
		local ax, az = Layout.polar(A_R, A_DEG)
		local a = racerAt(origin, "a", ax, 3, az)
		local run = newRun(env, origin, { a })
		env.map.start(run.ctx)
		runUntil(env, function()
			return launchOf(a.root) ~= nil
		end, 4.7)
		local v = launchOf(a.root).VectorVelocity
		local outward = origin:VectorToWorldSpace(RV3.new(ax, 0, az).Unit)
		near(t, v:Dot(outward), 50, 1e-3, "world outward")
		t.eq(run.ctx ~= nil, true)
	end)

	t.test(
		"QA 넘어진 사이 탈락하면 PlatformStand를 건드리지 않아요 (EliminationService 고정)",
		function()
			local env = loadEnv()
			local ax, az = Layout.polar(A_R, A_DEG)
			local a = racerAt(ORIGIN, "a", ax, 3, az)
			local run = newRun(env, ORIGIN, { a })
			env.map.start(run.ctx)
			local hitAt = runUntil(env, function()
				return a.humanoid.PlatformStand == true
			end, 4.7)
			run.ctx.eliminate(a)
			env.runTo(hitAt + 1.2)
			t.eq(a.humanoid.PlatformStand, true)
		end
	)

	---------------------------------------------------------------- 금 가기
	t.test(
		"QA 금 가기: 같은 바깥 칸에 두 번 → Falling → 1초 뒤 충돌 없음·투명, 0.5초 쿨다운 뒤 다시 맞음",
		function()
			local env = loadEnv()
			local ax, az = Layout.polar(A_R, A_DEG)
			local a = racerAt(ORIGIN, "a", ax, 3, az)
			local run = newRun(env, ORIGIN, { a })
			env.map.start(run.ctx)
			local tile = tileModel(run.model, 7)
			env.runTo(5)
			t.eq(tile:GetAttribute("Cracks"), 1)
			t.ok(tileSolid(tile), "금 1번은 그대로")
			-- 두 번째 폭탄: 약 5.5 생성 → 약 7.0 폭발
			env.runTo(6.9)
			t.eq(tile:GetAttribute("Cracks"), 1)
			local crackAt = runUntil(env, function()
				return tile:GetAttribute("Cracks") == 2
			end, 7.3)
			t.eq(tile:GetAttribute("Falling"), true)
			t.eq(#env.exempt, 2, "쿨다운(0.5초)이 지나 두 번째 폭탄에도 맞아요")
			t.ok(tileSolid(tile), "경고 1초 동안은 서 있음")
			env.runTo(crackAt + 0.9)
			t.ok(tileSolid(tile), "경고 1초 동안은 서 있음 (0.9초)")
			env.runTo(crackAt + 1.3)
			t.eq(tile:GetAttribute("Dropped"), true)
			t.ok(not tileSolid(tile), "떨어진 칸은 충돌 없음")
			for _, d in tile:GetDescendants() do
				if d.ClassName == "Part" then
					t.eq(d.Transparency, 1, d.Name)
					t.eq(d.CanQuery, false, d.Name)
					t.eq(d.CanTouch, false, d.Name)
				end
			end
		end
	)

	t.test("QA 금 가기: 가운데 원판은 35초 동안 계속 맞아도 금·낙하 없음", function()
		local env = loadEnv()
		local a = racerAt(ORIGIN, "a", 0.5, 3, 0.5)
		local run = newRun(env, ORIGIN, { a })
		env.map.start(run.ctx)
		env.runTo(35)
		local center = tileModel(run.model, 0)
		t.eq(center:GetAttribute("Cracks"), 0)
		t.ok(tileSolid(center))
		t.eq(center:GetAttribute("Falling"), nil)
		t.ok(#env.exempt >= 10, `원판 위 레이서가 계속 맞음 ({#env.exempt})`)
	end)

	---------------------------------------------------------------- 정해진 낙하
	t.test(
		"QA 정해진 낙하: 40초에 바깥 칸 하나 경고 → 41초 사라짐, 바깥 3칸 남으면 멈춤, 원판 그대로",
		function()
			local env = loadEnv()
			local run = newRun(env, ORIGIN, {})
			env.map.start(run.ctx)
			env.runTo(39.9)
			t.eq(select(1, ringSolid(run.model, 2)), 10)
			env.runTo(41.1)
			t.eq(select(1, ringSolid(run.model, 2)), 9)
			env.runTo(89)
			-- 40·46·52·58·64·70·76(7번) → 3칸 남음, 82·88은 멈춤
			t.eq(select(1, ringSolid(run.model, 2)), 3)
			-- 가운데: 60·66·72·78 → 6 − 4 = 2칸에서 멈춤
			t.eq(select(1, ringSolid(run.model, 1)), 2)
			t.eq(select(1, ringSolid(run.model, 0)), 1)
		end
	)

	---------------------------------------------------------------- 연장전
	t.test(
		"QA 연장전: 바로 돌아오고, 1·10.5·20초에 고리째 사라져 20초 뒤 충돌 파츠 0",
		function()
			local env = loadEnv()
			-- 레이서 없음: 폭탄은 원판(금 안 감)만 노려서 고리 칸 수가 정해진 낙하·연장전으로만 바뀌어요
			local run = newRun(env, ORIGIN, {})
			env.map.start(run.ctx)
			env.runTo(45) -- 40초 정해진 낙하 하나 끝남
			t.eq(select(1, ringSolid(run.model, 2)), 9)
			local co = coroutine.create(env.map.overtime)
			local ok = coroutine.resume(co, run.ctx, { collapseDuration = 20 })
			t.ok(ok)
			t.eq(coroutine.status(co), "dead", "overtime은 yield 없이 돌아와요")
			env.runTo(45.95)
			t.ok(select(1, ringSolid(run.model, 2)) > 0, "바깥 고리는 1초 경고 동안 서 있음")
			env.runTo(46.1)
			t.eq(select(1, ringSolid(run.model, 2)), 0)
			t.eq(select(1, ringSolid(run.model, 1)), 6, "가운데 고리는 아직")
			env.runTo(55.45)
			t.eq(select(1, ringSolid(run.model, 1)), 6)
			env.runTo(55.6)
			t.eq(select(1, ringSolid(run.model, 1)), 0)
			env.runTo(64.95)
			t.eq(select(1, ringSolid(run.model, 0)), 1)
			env.runTo(65.1)
			t.eq(select(1, ringSolid(run.model, 0)), 0)
			t.eq(#solidParts(run.model), 0, "collapseDuration 뒤 설 곳 0 (모델 안 충돌 파츠 없음)")
		end
	)

	t.test(
		"QA 연장전: 금이 2번 가도 새 낙하 없음, 정해진 낙하도 멈춤, 폭탄은 1초마다 3개",
		function()
			local env = loadEnv()
			local ax, az = Layout.polar(A_R, A_DEG)
			local a = racerAt(ORIGIN, "a", ax, 3, az)
			local run = newRun(env, ORIGIN, { a })
			env.map.start(run.ctx)
			env.runTo(4.6) -- 칸 7 금 1
			env.map.overtime(run.ctx, { collapseDuration = 100 }) -- 고리 일정을 길게: 바깥 4.6+1, 가운데 4.6+50.5
			local tile7 = tileModel(run.model, 7)
			t.eq(tile7:GetAttribute("Cracks"), 1)
			local before = env.collection.added.IkuraBomb
			env.runTo(5.4)
			env.runTo(15.4)
			local made = env.collection.added.IkuraBomb - before
			t.ok(made >= 27 and made <= 33, `연장전 10초에 폭탄 약 30개 (실제 {made})`)
			-- 가운데 고리: 60·66초 정해진 낙하가 멈춰서 54.6 경고 전까지 6칸 그대로
			env.runTo(54)
			t.eq(select(1, ringSolid(run.model, 1)), 6)
			for _, child in run.model:GetChildren() do
				if child:GetAttribute("Ring") == 1 then
					t.eq(child:GetAttribute("Cracks"), 0, "연장전에는 금도 안 가요")
				end
			end
		end
	)

	t.test("QA 연장전: start 전에 불려도(맵 시작 실패) 바닥을 없애요", function()
		local env = loadEnv()
		local run = newRun(env, ORIGIN, {})
		env.map.overtime(run.ctx, { collapseDuration = 20 })
		env.runTo(20.1)
		t.eq(#solidParts(run.model), 0)
	end)

	---------------------------------------------------------------- 낙하 판정
	t.test("QA 낙하선: 칸 윗면 −30 아래면 탈락, −29.9는 아직, 한 번만", function()
		local env = loadEnv()
		local low = racerAt(ORIGIN, "low", 0, -30.1, 0)
		local mid = racerAt(ORIGIN, "mid", 30, -29.9, 0)
		local run = newRun(env, ORIGIN, { low, mid })
		env.map.start(run.ctx)
		env.step(0.05)
		env.step(0.05)
		t.eq(run.eliminated, { low })
	end)

	---------------------------------------------------------------- 여러 방 · 정리
	t.test("QA 여러 방: 한 방의 연장전 붕괴·넉백이 다른 방에 안 섞여요", function()
		local env = loadEnv()
		local o1, o2 = RCF.new(2000, 300, 0), RCF.new(4000, 300, 0)
		local ax, az = Layout.polar(A_R, A_DEG)
		local a1 = racerAt(o1, "a1", ax, 3, az)
		local a2 = racerAt(o2, "a2", 0, 3, 0)
		local r1 = newRun(env, o1, { a1 })
		local r2 = newRun(env, o2, { a2 })
		env.map.start(r1.ctx)
		env.map.start(r2.ctx)
		env.runTo(5)
		env.map.overtime(r1.ctx, { collapseDuration = 20 })
		env.runTo(25.2)
		t.eq(#solidParts(r1.model), 0, "방 1은 무너짐")
		t.eq(select(1, ringSolid(r2.model, 2)), 10, "방 2 바깥 고리 그대로")
		t.eq(select(1, ringSolid(r2.model, 1)), 6)
		t.eq(tileModel(r1.model, 7):GetAttribute("Cracks"), 1, "방 1 칸 7 금 1 (연장전 전 첫 폭탄)")
		t.eq(tileModel(r2.model, 7):GetAttribute("Cracks"), 0)
		-- 방 2 폭탄은 방 2 레이서만 노려요 (a1은 방 1에서만 맞음)
		local hits1, hits2 = 0, 0
		for _, e in env.exempt do
			if e.character == a1.Character then
				hits1 += 1
			elseif e.character == a2.Character then
				hits2 += 1
			end
		end
		t.ok(hits1 > 0 and hits2 > 0, `둘 다 자기 방 폭탄에 맞음 ({hits1}, {hits2})`)
	end)

	t.test(
		"QA 정리: 라운드가 끝나면 경고 중 폭탄은 터지지 않고 사라지며, 모든 스레드·연결이 ctx.cleanup에",
		function()
			local env = loadEnv()
			local ax, az = Layout.polar(A_R, A_DEG)
			local a = racerAt(ORIGIN, "a", ax, 3, az)
			local run = newRun(env, ORIGIN, { a })
			env.map.start(run.ctx)
			env.runTo(4.0) -- 첫 폭탄 경고 중
			local bombs = run.model:FindFirstChild("Bombs")
			t.ok(bombs ~= nil, "Bombs folder")
			t.ok(table.find(run.cleanup, bombs) ~= nil, "Bombs 폴더는 cleanup에")
			env.map.overtime(run.ctx, { collapseDuration = 20 })
			run.setActive(false)
			env.runTo(30)
			t.eq(a.humanoid.PlatformStand, false, "끝난 라운드에는 폭발 없음")
			t.eq(#env.exempt, 0)
			local liveBombs = 0
			for _, child in bombs:GetChildren() do
				if child.Name == "Bomb" then
					liveBombs += 1
				end
			end
			t.eq(liveBombs, 0, "경고 중이던 폭탄 Model도 지워짐")
			t.ok(tileSolid(tileModel(run.model, 0)), "끝난 라운드는 연장전 붕괴도 멈춤")
			for i, co in env.sched.threads do
				t.ok(table.find(run.cleanup, co) ~= nil, `thread {i} in ctx.cleanup`)
			end
			local connections = 0
			for _, item in run.cleanup do
				if type(item) == "table" and item.Disconnect then
					connections += 1
				end
			end
			t.eq(connections, 1, "Heartbeat 연결 1개가 cleanup에")
		end
	)

	---------------------------------------------------------------- 순수 경계값
	t.test("QA bombWave 경계: 29.999/30, 59.999/60, overtimeAt = 15(디버그)·overtimeAt < 3", function()
		t.eq(Logic.bombWave(29.999), { interval = 2.5, count = 1, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(30), { interval = 2.0, count = 2, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(59.999), { interval = 2.0, count = 2, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(60), { interval = 1.5, count = 2, warn = 1.2, radius = 9 })
		t.eq(
			Logic.bombWave(200),
			{ interval = 1.5, count = 2, warn = 1.2, radius = 9 },
			"연장전 없으면 서든데스 그대로"
		)
		t.eq(Logic.bombWave(14.9, 15), { interval = 2.5, count = 1, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(15, 15), { interval = 1.0, count = 3, warn = 1.2, radius = 9 })
		t.eq(Logic.bombWave(1, 0.5), { interval = 1.0, count = 3, warn = 1.2, radius = 9 })
	end)

	t.test(
		"QA pickTargets 경계: 레이서 0명이면 전부 칸 위 무작위, 칸 0개면 빈 목록, count 0이면 빈 목록",
		function()
			local rng = seededRng(5)
			for _ = 1, 200 do
				local points = Logic.pickTargets(rng, {}, { 0, 3, 9 }, 3)
				t.eq(#points, 3)
				for _, p in points do
					local id = Logic.tileAt(p.x, p.z)
					t.ok(id == 0 or id == 3 or id == 9, `on alive tile ({id})`)
				end
			end
			t.eq(Logic.pickTargets(rng, { { x = 0, z = 0 } }, {}, 3), {})
			t.eq(Logic.pickTargets(rng, { { x = 0, z = 0 } }, { 0 }, 0), {})
		end
	)

	t.test(
		"QA pickTargets D4: 레이서 1명 + 3개(연장전), 칸이 넉넉하면 간격 6 미만이 1% 이하",
		function()
			local rng = seededRng(11)
			local alive = {}
			for id = 0, 16 do
				table.insert(alive, id)
			end
			local bad, onRacer = 0, 0
			local trials = 1000
			for _ = 1, trials do
				local racer = { x = 18, z = -4 }
				local points = Logic.pickTargets(rng, { racer }, alive, 3)
				t.eq(#points, 3)
				for i = 1, 3 do
					for j = i + 1, 3 do
						local dx, dz = points[i].x - points[j].x, points[i].z - points[j].z
						if dx * dx + dz * dz < 36 then
							bad += 1
						end
					end
					local rx, rz = points[i].x - racer.x, points[i].z - racer.z
					if rx * rx + rz * rz <= 9.0001 then
						onRacer += 1
					end
				end
			end
			t.ok(bad / trials <= 0.01, `spacing violations {bad}/{trials}`)
			-- 레이서 위 폭탄은 묶음마다 최대 1개(D4) — 3개 중 비율이 1/3을 넘지 않아요
			t.ok(onRacer / (3 * trials) <= 1 / 3 + 1e-9, `on racer {onRacer}`)
			t.ok(onRacer / trials >= 0.55, `첫 폭탄은 여전히 약 60% 레이서 ({onRacer})`)
		end
	)

	t.test(
		"QA pickTargets: 레이서 2명 + 2개 → 두 사람을 각각 노리는 묶음이 나와요 (D4가 다른 레이서는 안 뺌)",
		function()
			local rng = seededRng(3)
			local alive = {}
			for id = 0, 16 do
				table.insert(alive, id)
			end
			local racers = { { x = 18, z = -4 }, { x = -18, z = 4 } }
			local both = 0
			for _ = 1, 500 do
				local points = Logic.pickTargets(rng, racers, alive, 2)
				local hit = { false, false }
				for _, p in points do
					for i, r in racers do
						if (p.x - r.x) ^ 2 + (p.z - r.z) ^ 2 <= 9.0001 then
							hit[i] = true
						end
					end
				end
				if hit[1] and hit[2] then
					both += 1
				end
			end
			t.ok(both > 100, `both racers targeted in one batch {both}/500`)
		end
	)

	t.test(
		"QA overtimeRings 경계: collapseDuration = warn이면 전부 0초 경고·1초 낙하, 더 짧으면 warn을 줄임",
		function()
			local same = Logic.overtimeRings(1, 1)
			for _, s in same do
				t.eq(s.warnAt, 0)
				t.eq(s.dropAt, 1)
			end
			local short = Logic.overtimeRings(0.5, 1)
			t.eq(short[3].dropAt, 0.5)
			for _, s in short do
				t.ok(s.warnAt >= 0, "warnAt never negative")
			end
			local long = Logic.overtimeRings(40, 1)
			t.eq({ long[1].ring, long[2].ring, long[3].ring }, { 2, 1, 0 })
			t.eq(long[3].dropAt, 40)
		end
	)

	t.test("QA knockback 경계: 반경 바로 안/밖, 방향 0이고 레이서도 접시 중심이면 +X", function()
		local v = Logic.knockback(0, 0, 7, 0, 0)
		t.eq(v, { x = 50, y = 30, z = 0 })
		t.ok(Logic.knockback(7.0001, 0, 7) == nil)
		local edge = Logic.knockback(0, -7, 7) :: any
		near(t, edge.z, -30, 1e-9, "edge speed 30")
		t.ok(Logic.inBlast(0, 6, 0, 7))
		t.ok(not Logic.inBlast(0, 6.01, 0, 7))
		t.ok(not Logic.inBlast(0, -6.01, 0, 7))
	end)
end
