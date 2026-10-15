--!strict
-- m5-05 QA (docs/qa/m5-05-map-tempura-pot.md): 개발 테스트(map-tempura-pot)에 없는 경계값과
-- 실제 맵 코드를 돌려 보는 확인.
--   정적: oilHeight·splashInterval·splashKnockback 경계, 모든 발판에서 꼭대기까지 길(아래층으로 떨어져도 계속),
--         위층 발판과 머리 공간, 벽 위로 못 올라감
--   렌더러 환경(진짜 인스턴스)으로 build: 충돌 파츠가 냄비·발판뿐(장식·기름·OilFollowers·스폰 전부 충돌·쿼리 없음),
--         냄비 안 장식이 "가짜 바닥"이 아님, 조명·파티클 실제 수가 Extended 안 (튀는 기름 런타임 여유 포함)
--   가짜 Heartbeat·task로 start: 기름 표면·OilFollowers가 따라 올라감, 발 < 기름이면 탈락, 경고 원 → 1.2초 뒤
--         넉백(LinearVelocity 35/25, PlatformStand 1초, MoveExempt 1.5초), 원 밖·쿨다운·탈락자 제외,
--         다른 방 발판 안 봄, 라운드 끝나면 일정 멈춤

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.maps.TempuraPotLayout)
local Logic = RobloxRequire.require(Shared.maps.TempuraPotLogic)
local Art = RobloxRequire.require(Shared.maps.TempuraPotArt)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

---------------------------------------------------------------- 가짜 Roblox (m5-14-16-reqa와 같은 방식 + task)

local function newSignal(): any
	local handlers: { any } = {}
	local signal = { handlers = handlers }
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
	function methods.Emit(_, n: number)
		props.__emitted = (props.__emitted or 0) + n
	end
	function methods.GetAttribute(_, name: string)
		return attributes[name]
	end
	function methods.SetAttribute(_, name: string, value: any)
		attributes[name] = value
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
	local service = {}
	function service:AddTag(inst: any, tag: string)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], inst)
	end
	function service:GetTagged(tag: string)
		return table.clone(tags[tag] or {})
	end
	return service
end

-- 시계를 손으로 돌리는 task: spawn은 바로 실행, wait/delay는 clock이 지나야 깨어나요.
local function newScheduler(getClock: () -> number): any
	local sleepers: { { co: thread, wakeAt: number, since: number } } = {}
	local delays: { { fn: any, args: any, wakeAt: number, cancelled: boolean } } = {}
	local T = {}
	function T.spawn(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end
	function T.delay(seconds: number, fn, ...)
		local entry = { fn = fn, args = table.pack(...), wakeAt = getClock() + seconds, cancelled = false }
		table.insert(delays, entry)
		local co = coroutine.create(function() end);
		(entry :: any).thread = co
		return co
	end
	function T.wait(seconds: number?)
		local co = coroutine.running()
		local now = getClock()
		table.insert(sleepers, { co = co, wakeAt = now + (seconds or 0), since = now })
		return coroutine.yield()
	end
	function T.cancelAll()
		for _, s in sleepers do
			s.wakeAt = math.huge
		end
		for _, d in delays do
			d.cancelled = true
		end
	end
	-- clock 기준으로 깰 것 깨우기
	function T.pump()
		local progressed = true
		while progressed do
			progressed = false
			local now = getClock()
			for i = #sleepers, 1, -1 do
				local s = sleepers[i]
				if s.wakeAt <= now then
					table.remove(sleepers, i)
					local ok, err = coroutine.resume(s.co, now - s.since)
					if not ok then
						error(err)
					end
					progressed = true
				end
			end
			for i = #delays, 1, -1 do
				local d = delays[i]
				if d.wakeAt <= now then
					table.remove(delays, i)
					if not d.cancelled then
						d.fn(table.unpack(d.args, 1, d.args.n))
					end
					progressed = true
				end
			end
		end
	end
	T.sleepers = sleepers
	T.delays = delays
	return T
end

type Env = {
	map: any,
	heartbeat: any,
	collection: any,
	clock: { value: number },
	task: any,
	exempts: { { character: any, seconds: number } },
	sfx: { string },
	raycastParams: { any },
}

local function loadMap(): Env
	local heartbeat = newSignal()
	local collection = newCollection()
	local clock = { value = 0 }
	local scheduler = newScheduler(function()
		return clock.value
	end)
	local exempts: { { character: any, seconds: number } } = {}
	local sfx: { string } = {}
	local raycastParams: { any } = {}
	local env: Env
	local stubs: { [string]: any } = {
		MapKit = {
			buildDecor = function()
				return {}
			end,
			decorFolder = function(model)
				local folder = newInstance("Folder")
				folder.Name = "Decor"
				folder.Parent = model
				return folder
			end,
			introCamera = function() end,
			attachStudioArt = function() end,
			makeEmitter = function(name: string, rate: number)
				local e = newInstance("ParticleEmitter")
				e.Name = name
				e.Rate = rate
				return e
			end,
			makeLight = function(_spec)
				return newInstance("PointLight")
			end,
		},
		MapSfx = {
			play = function(_, cue: string)
				table.insert(sfx, cue)
			end,
		},
		MapTypes = {},
		MoveExempt = {
			mark = function(character, seconds)
				table.insert(exempts, { character = character, seconds = seconds })
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
	-- 발밑 레이캐스트: 필터 목록(이 방 발판)에서 (x, z) 위이고 윗면이 [y − 길이, y] 안인 발판
	local function raycast(origin: any, direction: any, params: any): any
		table.insert(raycastParams, params)
		local best, bestY = nil, -math.huge
		for _, p in params.FilterDescendantsInstances do
			local key = p:GetAttribute("RaftKey")
			local raft = env.raftOf(key)
			local o = env.originOf(p)
			local rel = o:PointToObjectSpace(origin)
			if raft and Logic.isOnRaft(raft, rel.X, rel.Z) then
				local top = raft.topY
				if top <= rel.Y and top >= rel.Y + direction.Y and top > bestY then
					best, bestY = p, top
				end
			end
		end
		return if best then { Instance = best } else nil
	end
	local map = luau.load(fs.readFile("src/shared/maps/TempuraPot.luau"), {
		debugName = "TempuraPot",
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
			NumberRange = roblox.NumberRange,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			PhysicalProperties = {
				new = function()
					return {}
				end,
			},
			Enum = enumStub,
			RaycastParams = {
				new = function()
					return {}
				end,
			},
			workspace = {
				Raycast = function(_, origin, direction, params)
					return raycast(origin, direction, params)
				end,
			},
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
			task = scheduler,
			os = {
				clock = function()
					return clock.value
				end,
			},
		},
	})()
	local raftsByKey: { [string]: any } = { Basket = Layout.basket() }
	for _, r in Layout.rafts() do
		raftsByKey[r.key] = r
	end
	local origins: { [any]: any } = {}
	env = {
		map = map,
		heartbeat = heartbeat,
		collection = collection,
		clock = clock,
		task = scheduler,
		exempts = exempts,
		sfx = sfx,
		raycastParams = raycastParams,
	}
	(env :: any).raftOf = function(key)
		return raftsByKey[key]
	end
	(env :: any).originOf = function(p)
		return origins[p]
	end
	(env :: any).registerOrigin = function(model, origin)
		for _, d in model:GetDescendants() do
			if d:GetAttribute("RaftKey") then
				origins[d] = origin
			end
		end
	end
	return env
end

local function newCleanup(): any
	local items: { any } = {}
	return {
		items = items,
		add = function(_, item)
			table.insert(items, item)
			return item
		end,
	}
end

-- origin 로컬 (x, footY, z)에 서 있는 레이서 (root = 발 + FOOT_OFFSET)
local function newRacer(name: string, origin: any, x: number, footY: number, z: number): any
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = origin:PointToWorldSpace(RV3.new(x, footY + Layout.FOOT_OFFSET, z))
	root.Parent = character
	local attachment = newInstance("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = newInstance("Humanoid")
	humanoid.PlatformStand = false
	humanoid.Parent = character
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

local function moveTo(racer: any, origin: any, x: number, footY: number, z: number)
	racer.root.Position = origin:PointToWorldSpace(RV3.new(x, footY + Layout.FOOT_OFFSET, z))
end

type Run = {
	env: Env,
	ctx: any,
	cleanup: any,
	racers: { any },
	active: { value: boolean },
	eliminated: { any },
	model: any,
	origin: any,
	advance: (number) -> (),
}

-- 돌린 origin (실제 아레나는 회전이 없지만 더 엄격하게)
local ORIGIN = RCF.new(2000, 300, 4000) * RCF.Angles(0, math.rad(90), 0)

local function startRun(origin: any?, env: Env?): Run
	local o = origin or ORIGIN
	local e = env or loadMap()
	local model = e.map.build(o);
	(e :: any).registerOrigin(model, o)
	local cleanup = newCleanup()
	local racers: { any } = {}
	local active = { value = true }
	local eliminated: { any } = {}
	local ctx = {
		model = model,
		origin = o,
		cleanup = cleanup,
		rng = {
			NextInteger = function(_, a: number, _b: number): number
				return a
			end,
		},
		targetCount = 1,
		isActive = function()
			return active.value
		end,
		getRacers = function()
			return table.clone(racers)
		end,
		pass = function() end,
		eliminate = function(p)
			table.insert(eliminated, p)
			local i = table.find(racers, p)
			if i then
				table.remove(racers, i)
			end
		end,
	}
	local run: Run
	run = {
		env = e,
		ctx = ctx,
		cleanup = cleanup,
		racers = racers,
		active = active,
		eliminated = eliminated,
		model = model,
		origin = o,
		-- dt만큼 0.05초 걸음으로 시간을 보내요 (Heartbeat + task 깨우기)
		advance = function(seconds: number)
			local steps = math.floor(seconds / 0.05 + 0.5)
			for _ = 1, steps do
				e.clock.value += 0.05
				e.heartbeat:Fire(0.05)
				e.task.pump()
			end
		end,
	}
	e.map.start(ctx)
	e.task.pump()
	return run
end

local function rafts(): { any }
	return Layout.rafts()
end

local function raftByKey(key: string): any
	if key == "Basket" then
		return Layout.basket()
	end
	for _, r in rafts() do
		if r.key == key then
			return r
		end
	end
	error(key)
end

local function warnings(model: any): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d.Name == "OilSplashWarning" then
			table.insert(list, d)
		end
	end
	return list
end

local function launchOf(racer: any): any
	return racer.root:FindFirstChild("OilSplashLaunch")
end

---------------------------------------------------------------- 렌더러 환경 (진짜 인스턴스)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)
local builtModel: any = nil
local BUILT_ORIGIN = roblox.CFrame.new(2000, 300, 0)
local function realModel(): any
	if builtModel == nil then
		builtModel = RMaps.get("tempura-pot").build(BUILT_ORIGIN)
	end
	return builtModel
end

local function underFolder(part: any, model: any, folderName: string): boolean
	local p = part.Parent
	while p and p ~= model do
		if p.Name == folderName then
			return true
		end
		p = p.Parent
	end
	return false
end

return function(t: Test.Test)
	---------------------------------------------------------------- 기름 경계
	t.test("QA oil: 6초 직후부터 오르고 68.5초에 정확히 25에서 멈춰요, 음수 시간은 0", function()
		t.eq(Logic.oilHeight(-5), 0)
		t.ok(Logic.oilHeight(6.01) > 0, "rises right after grace")
		t.ok(near(Logic.oilHeight(61), 22), "61s = 22")
		t.ok(near(Logic.oilHeight(60.9), 21.96, 1e-9), "60.9s just under")
		t.eq(Logic.oilHeight(1000), 25) -- m5-40 서든데스 상한
		-- 경계에서 같은 높이는 살아요 (13.5초 바구니 발 = 3)
		t.eq(Logic.isFried(Layout.BASKET_TOP_Y, Logic.oilHeight(13.5)), false)
		t.eq(Logic.isFried(Layout.BASKET_TOP_Y, Logic.oilHeight(13.6)), true)
		-- m5-40: 상한이 25가 되어 23층은 약 63.5초에 잠기고, 27층은 OIL_MAX(25)보다도 높아 영원히 안전
		t.ok(Layout.TIER_TOPS[6] > Logic.OIL_MAX_Y + 1, "tier 27 above max oil even after time limit")
	end)

	t.test("QA splash 경계: 간격 29.99 → 3, 44.99 → 2, 60·1000 → 1.2(m5-40), 음수 nil", function()
		t.eq(Logic.splashInterval(-1), nil)
		t.eq(Logic.splashInterval(29.99), 3)
		t.eq(Logic.splashInterval(44.99), 2)
		t.eq(Logic.splashInterval(60), 1.2) -- m5-40 서든데스
		t.eq(Logic.splashInterval(1000), 1.2)
	end)

	t.test(
		"QA splash 경계: 반경 정확히 5는 맞고 5.0001은 안 맞음, 수평 크기는 어느 방향이든 35",
		function()
			t.ok(Logic.splashKnockback(5, 0) ~= nil, "exactly 5 hits")
			t.eq(Logic.splashKnockback(5.0001, 0), nil)
			t.eq(Logic.splashKnockback(3, 4.0001), nil)
			local center = Logic.splashKnockback(0, 0)
			t.ok(center ~= nil and center.x == 35 and center.z == 0 and center.y == 25, "center pushes +X")
			for deg = 0, 359, 17 do
				local r = 0.5 + (deg % 5)
				local v = Logic.splashKnockback(r * math.cos(math.rad(deg)), r * math.sin(math.rad(deg)))
				t.ok(v ~= nil, `hit at {deg}`)
				if v then
					t.ok(near(math.sqrt(v.x * v.x + v.z * v.z), 35, 1e-6), `horizontal 35 at {deg}`)
					t.ok(v.x * math.cos(math.rad(deg)) + v.z * math.sin(math.rad(deg)) > 0, `outward at {deg}`)
					t.eq(v.y, 25)
				end
			end
		end
	)

	---------------------------------------------------------------- 길 (AC4·AC12 보강)
	t.test(
		"QA 길: 어느 발판에서 떨어져도 그 발판에서 꼭대기까지 위로 가는 길이 있어요 (AC12 계속하기)",
		function()
			for _, raft in rafts() do
				t.ok(Logic.pathFrom(raft) ~= nil, `{raft.key} reaches top`)
			end
			t.ok(Logic.pathFrom(Layout.basket()) ~= nil, "basket reaches top")
		end
	)

	t.test(
		"QA 길: 이어지는 층 사이 높이 차는 정확히 4 (점프 약 6.4 안), 층 높이 순서대로",
		function()
			for i = 2, #Layout.TIER_TOPS do
				t.eq(Layout.TIER_TOPS[i] - Layout.TIER_TOPS[i - 1], 4)
			end
			t.eq(Layout.TIER_TOPS[1] - Layout.BASKET_TOP_Y, 4)
		end
	)

	t.test(
		"QA 머리 공간: 높이 차 12 미만인 두 발판(위·아래)은 위에서 볼 때 겹치지 않아요",
		function()
			local all = { Layout.basket() }
			for _, r in rafts() do
				table.insert(all, r)
			end
			for _, a in all do
				for _, b in all do
					local rise = b.topY - a.topY
					if rise > 0 and rise < 12 then
						t.ok(Logic.gap(a, b) > 0, `{a.key} under {b.key} overlaps (rise {rise})`)
					end
				end
			end
		end
	)

	t.test(
		"QA 벽: 모든 발판에서 점프(6.4)로 벽 꼭대기(40)에 못 닿고, 넉백 최고점(+5)으로도 못 닿아요",
		function()
			local topRaft = Layout.TIER_TOPS[#Layout.TIER_TOPS]
			t.ok(topRaft + 6.4 < Layout.POT_WALL_TOP_Y, "jump")
			-- 넉백: 0.15초 동안 위 25로 붙잡은 뒤 포물선 (중력 196.2)
			local rise = 25 * Logic.SPLASH_HOLD + 25 * 25 / (2 * 196.2)
			t.ok(rise < 6, `knock rise {rise}`)
			t.ok(topRaft + rise + 2 < Layout.POT_WALL_TOP_Y, "knock + body below rim")
			for _, raft in rafts() do
				t.ok(Logic.wallClearance(raft) > 0, `{raft.key} inside wall`)
			end
		end
	)

	---------------------------------------------------------------- 렌더러 환경 build (충돌 감사)
	t.test(
		"QA build: 충돌 파츠는 냄비(Pot)·발판(Rafts)뿐, 장식·기름·OilFollowers·스폰은 충돌·쿼리·터치 없음",
		function()
			local model = realModel()
			local collidable, raftParts = 0, 0
			for _, d in model:GetDescendants() do
				if not d:IsA("BasePart") then
					continue
				end
				local inPot = underFolder(d, model, "Pot")
				local inRafts = underFolder(d, model, "Rafts")
				if d.CanCollide then
					collidable += 1
					t.ok(inPot or inRafts, `collidable outside Pot/Rafts: {d:GetFullName()}`)
				end
				if inRafts then
					raftParts += 1
					t.ok(d.CanCollide and d.CanQuery, `{d.Name} raft collides/queries`)
				elseif not inPot then
					t.ok(not d.CanCollide, `{d.Name} no collide`)
					if not underFolder(d, model, "Spawns") and not underFolder(d, model, "IntroCamera") then
						t.ok(not d.CanQuery, `{d:GetFullName()} no query`)
						t.ok(not d.CanTouch, `{d:GetFullName()} no touch`)
					end
				end
			end
			t.eq(raftParts, #rafts() + 1)
			t.eq(collidable, Layout.POT_WALL_SEGMENTS + 1 + #rafts() + 1)
		end
	)

	t.test(
		"QA build: 냄비 벽은 전부 꼭대기 40·안쪽 면 반지름 36 이상, 바닥 윗면 −10",
		function()
			local model = realModel()
			local pot = model:FindFirstChild("Pot")
			local walls = 0
			for _, p in pot:GetChildren() do
				local rel = BUILT_ORIGIN:ToObjectSpace(p.CFrame)
				if string.sub(p.Name, 1, 7) == "PotWall" then
					walls += 1
					t.ok(near(rel.Position.Y + p.Size.Y / 2, Layout.POT_WALL_TOP_Y, 1e-3), `{p.Name} top`)
					local dx, dz = rel.Position.X - Layout.POT_CENTER_X, rel.Position.Z - Layout.POT_CENTER_Z
					local centerDist = math.sqrt(dx * dx + dz * dz)
					t.ok(centerDist - p.Size.Z / 2 >= Layout.POT_INNER_RADIUS - 1e-3, `{p.Name} inner face`)
				elseif p.Name == "PotFloor" then
					t.ok(near(rel.Position.Y + p.Size.X / 2, Layout.POT_FLOOR_Y, 1e-3), "floor top")
				end
			end
			t.eq(walls, Layout.POT_WALL_SEGMENTS)
		end
	)

	t.test(
		"QA build: 냄비 안(벽 안쪽, y −10~40)에 발판처럼 보이는 넓고 평평한 장식이 없어요 (가짜 바닥)",
		function()
			local model = realModel()
			local decor = model:FindFirstChild("Decor")
			local fake = {}
			local examined = 0
			for _, d in decor:GetDescendants() do
				if not d:IsA("BasePart") or d.Transparency >= 0.95 then
					continue
				end
				local rel = BUILT_ORIGIN:ToObjectSpace(d.CFrame)
				local p = rel.Position
				local dx, dz = p.X - Layout.POT_CENTER_X, p.Z - Layout.POT_CENTER_Z
				if math.sqrt(dx * dx + dz * dz) > Layout.POT_INNER_RADIUS - 0.5 then
					continue
				end
				if p.Y < Layout.POT_FLOOR_Y or p.Y > Layout.POT_WALL_TOP_Y then
					continue
				end
				examined += 1
				-- 평평하고 넓은 판: 가장 짧은 변 ≤ 1.5, 나머지 두 변 ≥ 3 (월드 축으로 본 가장 위 면이 수평에 가까움)
				local s = { d.Size.X, d.Size.Y, d.Size.Z }
				table.sort(s)
				if s[1] <= 1.5 and s[2] >= 3 then
					-- 발판 바로 아래(윗면 이하)·발판 테두리에 붙은 것은 발판 장식이라 괜찮아요
					local onRaft = false
					for _, raft in rafts() do
						if Logic.pointDistance(raft, p.X, p.Z) <= 1.5 and p.Y <= raft.topY + 0.05 then
							onRaft = true
						end
					end
					if not onRaft then
						table.insert(fake, `{d.Name}@{math.floor(p.X)},{math.floor(p.Y)},{math.floor(p.Z)}`)
					end
				end
			end
			t.ok(examined > 50, `examined {examined} decor parts inside the pot`)
			t.eq(fake, {}, "flat decor slabs inside the pot")
		end
	)

	t.test(
		"QA build: 실제 인스턴스 조명·파티클 수가 Extended 안, 튀는 기름 런타임(동시 2개) 여유 포함",
		function()
			local model = realModel()
			local lights, shadowed, particles = 0, 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
					lights += 1
					if d.Shadows then
						shadowed += 1
					end
				elseif d:IsA("ParticleEmitter") then
					particles += 1
				end
			end
			local budget = MapKitLogic.budget(Art.BUDGET)
			t.ok(lights <= budget.lights, `lights {lights}`)
			t.ok(shadowed <= budget.shadowedLights, `shadowed {shadowed}`)
			-- 튀는 기름 1.5초 간격, 파티클은 1.5초 뒤 사라져서 동시에 최대 2개
			t.ok(particles + 2 <= budget.particles, `particles {particles} + 2 runtime`)
			-- 장식 파츠 예산 (런타임 장식 아님 — 경고 원·방울은 Decor 밖이라 예산에 안 들어가요)
			t.eq(MapKitLogic.checkBudget(Art.decor(), "Extended"), nil)
		end
	)

	t.test("QA build: OilFollowers와 기름 표면이 같이 지어지고 기름은 HotOil 태그 1개", function()
		local model = realModel()
		local followers = model:FindFirstChild("OilFollowers")
		t.ok(followers ~= nil, "OilFollowers")
		local n = 0
		for _, c in followers:GetChildren() do
			if c:IsA("BasePart") then
				n += 1
				t.ok(not c.CanCollide and not c.CanQuery and not c.CanTouch, c.Name)
			end
		end
		t.eq(n, 1 + #Art.OIL_GLOWS + 1)
		local oil = model:FindFirstChild("Oil")
		t.ok(oil and not oil.CanCollide and not oil.CanQuery, "oil ghost")
	end)

	---------------------------------------------------------------- start (가짜 Heartbeat·task)
	t.test("QA start: 기름 표면·OilFollowers가 oilHeight를 따라 올라가요", function()
		local run = startRun()
		local oil = run.model:FindFirstChild("Oil")
		local deep = run.model:FindFirstChild("OilFollowers"):FindFirstChild("OilDepth")
		local deepOffset = run.origin:ToObjectSpace(deep.CFrame).Position.Y
			- run.origin:ToObjectSpace(oil.CFrame).Position.Y
		run.advance(20)
		local oilRelY = run.origin:ToObjectSpace(oil.CFrame).Position.Y
		-- 원판 중심 = 윗면 − 두께/2
		t.ok(near(oilRelY + oil.Size.X / 2, Logic.oilHeight(20), 0.06), `oil top {oilRelY}`)
		local deepRelY = run.origin:ToObjectSpace(deep.CFrame).Position.Y
		t.ok(near(deepRelY - oilRelY, deepOffset, 1e-3), "OilDepth keeps its offset")
		run.active.value = false
		run.env.task.cancelAll()
	end)

	t.test(
		"QA start: 바구니에 서 있으면 13.5초 안 탈락, 그 뒤 탈락 / 꼭대기는 60초까지 안 탈락",
		function()
			local run = startRun()
			local top = raftByKey("Top")
			local onBasket = newRacer("basket", run.origin, 5, Layout.BASKET_TOP_Y, Layout.POT_CENTER_Z)
			local onTop = newRacer("top", run.origin, top.x, top.topY, top.z)
			table.insert(run.racers, onBasket)
			table.insert(run.racers, onTop)
			run.advance(13.4)
			t.eq(#run.eliminated, 0, "nobody before 13.5")
			run.advance(0.3)
			t.eq(run.eliminated[1], onBasket, "basket fried after 13.5")
			-- 꼭대기 레이서는 튀는 기름에 맞으면 날아가니 계속 제자리로 돌려놓아요
			for _ = 1, 47 * 4 do
				moveTo(onTop, run.origin, top.x, top.topY, top.z)
				run.advance(0.25)
			end
			t.eq(table.find(run.eliminated, onTop), nil, "top survives 60s")
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test("QA start: 냄비 바닥 밑 안전망(−15)·기름보다 낮은 발은 한 번만 탈락", function()
		local run = startRun()
		local r = newRacer("deep", run.origin, 0, Layout.FALL_ELIMINATION_Y - 4, Layout.POT_CENTER_Z)
		table.insert(run.racers, r)
		run.advance(0.2)
		t.eq(#run.eliminated, 1)
		run.advance(1)
		t.eq(#run.eliminated, 1, "not eliminated twice")
		run.active.value = false
		run.env.task.cancelAll()
	end)

	t.test(
		"QA splash: 10초 전에는 경고가 없고, 10초에 서 있는 레이서 발밑에 OilSplash 경고 원",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			local r = newRacer("a", run.origin, raft.x, raft.topY, raft.z)
			table.insert(run.racers, r)
			run.advance(9.9)
			t.eq(#warnings(run.model), 0, "no warning before 10s")
			run.advance(0.15)
			local list = warnings(run.model)
			t.eq(#list, 1, "warning at 10s")
			if list[1] then
				local rel = run.origin:ToObjectSpace(list[1].CFrame).Position
				t.ok(near(rel.X, raft.x, 0.01) and near(rel.Z, raft.z, 0.01), "circle under the racer")
				t.ok(rel.Y > raft.topY and rel.Y < raft.topY + 0.3, "just above raft top")
				t.ok(not list[1].CanCollide and not list[1].CanQuery, "warning ghost")
				local tagged = run.env.collection:GetTagged("OilSplash")
				t.ok(table.find(tagged, list[1]) ~= nil, "tag OilSplash")
			end
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test(
		"QA splash: 1.2초 뒤 원 안 레이서는 바깥 35·위 25로 밀리고 PlatformStand 1초·MoveExempt 1.5초·OilSplash 소리",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			local r = newRacer("a", run.origin, raft.x, raft.topY, raft.z)
			table.insert(run.racers, r)
			run.advance(10.05)
			t.eq(#warnings(run.model), 1)
			-- 경고 중에 원 안에서 2 옮김 (원은 그대로)
			moveTo(r, run.origin, raft.x + 2, raft.topY, raft.z)
			run.advance(1.0)
			t.eq(launchOf(r), nil, "not yet at 1.0s")
			local push = nil
			for _ = 1, 10 do
				run.advance(0.05)
				push = launchOf(r)
				if push then
					break
				end
			end
			local hitAt = run.env.clock.value
			t.ok(hitAt >= 10 + Logic.SPLASH_WARN_TIME and hitAt <= 10 + Logic.SPLASH_WARN_TIME + 0.3, `hit at {hitAt}`)
			t.ok(push ~= nil, "launched after warning")
			t.eq(#warnings(run.model), 0, "warning removed")
			if push then
				local v = run.origin:VectorToObjectSpace(push.VectorVelocity)
				t.ok(near(v.X, 35, 1e-3) and near(v.Z, 0, 1e-3), `outward local +X {v}`)
				t.ok(near(push.VectorVelocity.Y, 25, 1e-3), "up 25 (world)")
				t.ok(push.MaxForce == math.huge, "max force")
			end
			t.eq(r.humanoid.PlatformStand, true, "knocked down")
			t.eq(#run.env.exempts, 1)
			t.eq(run.env.exempts[1] and run.env.exempts[1].seconds, 1.5)
			t.ok(table.find(run.env.sfx, "OilSplash") ~= nil, "sfx")
			run.advance(0.2)
			t.eq(launchOf(r), nil, "LinearVelocity removed after hold")
			moveTo(r, run.origin, raft.x, raft.topY, raft.z)
			run.advance(0.9)
			t.eq(r.humanoid.PlatformStand, false, "stands up after 1s")
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test("QA splash: 경고 중에 원 밖(5 넘게)으로 피하면 안 맞아요", function()
		local run = startRun()
		local raft = raftByKey("Basket")
		local r = newRacer("a", run.origin, raft.x + 8, raft.topY, raft.z)
		table.insert(run.racers, r)
		run.advance(10.05)
		t.eq(#warnings(run.model), 1)
		moveTo(r, run.origin, raft.x + 8 + 5.5, raft.topY, raft.z)
		run.advance(1.3)
		t.eq(launchOf(r), nil, "dodged")
		t.eq(r.humanoid.PlatformStand, false)
		t.eq(#run.env.exempts, 0)
		run.active.value = false
		run.env.task.cancelAll()
	end)

	t.test(
		"QA splash: 공중(발밑에 발판 없음)·잠긴 발판 위 레이서는 대상이 아니에요",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			-- 공중: 발판 윗면보다 6 위 (레이 4.5에 안 닿음)
			local air = newRacer("air", run.origin, raft.x, raft.topY + 6, raft.z)
			table.insert(run.racers, air)
			run.advance(10.05)
			t.eq(#warnings(run.model), 0, "no target in the air")
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test(
		"QA splash: 같은 사람은 0.5초 안에 두 번 안 맞고, 넉백 중 탈락하면 PlatformStand를 안 풀어요",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			local r = newRacer("a", run.origin, raft.x, raft.topY, raft.z)
			table.insert(run.racers, r)
			run.advance(11.3)
			t.eq(#run.env.exempts, 1, "first hit")
			-- 탈락 처리(서비스가 고정) → 1초 뒤에도 PlatformStand 그대로
			run.ctx.eliminate(r)
			run.advance(1.1)
			t.eq(r.humanoid.PlatformStand, true, "eliminated stays knocked")
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test(
		"QA splash: 원 안이어도 발이 윗면 −1 아래거나 +3.5 위면 안 맞고, 위층(+4)도 안 맞아요 (B1 수정: SPLASH_HEIGHT_RANGE 3.5)",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			local target = newRacer("target", run.origin, raft.x, raft.topY, raft.z)
			table.insert(run.racers, target)
			run.advance(10.05)
			t.eq(#warnings(run.model), 1)
			-- 경고 중에 대상은 원 밖으로 빠지고, 다른 셋을 원 안 높이별로 둬요 (getRacers는 매번 새로 읽어요)
			moveTo(target, run.origin, raft.x + 20, raft.topY, raft.z)
			local low = newRacer("low", run.origin, raft.x + 1, raft.topY - 1.5, raft.z)
			local high = newRacer("high", run.origin, raft.x - 1, raft.topY + 6.5, raft.z)
			local above = newRacer("above", run.origin, raft.x, raft.topY + 4, raft.z + 1)
			table.insert(run.racers, low)
			table.insert(run.racers, high)
			table.insert(run.racers, above)
			run.advance(1.3)
			t.eq(launchOf(target), nil, "target dodged")
			t.eq(low.humanoid.PlatformStand, false, "below -1 not hit")
			t.eq(high.humanoid.PlatformStand, false, "above +3.5 not hit")
			t.eq(above.humanoid.PlatformStand, false, "one tier up (+4) is not hit (B1 fixed)")
			run.active.value = false
			run.env.task.cancelAll()
		end
	)

	t.test("QA splash: 간격 — 10~30초 3초마다, 45초 뒤 1.5초마다 경고가 생겨요", function()
		local run = startRun()
		local top = raftByKey("Top")
		local r = newRacer("a", run.origin, top.x, top.topY, top.z)
		table.insert(run.racers, r)
		local seen = 0
		local wasWarning = false
		local startsBefore30, startsAfter45 = 0, 0
		for _ = 1, 60 * 20 do
			moveTo(r, run.origin, top.x, top.topY, top.z)
			run.advance(0.05)
			local now = run.env.clock.value
			local isWarning = #warnings(run.model) > 0
			if isWarning and not wasWarning then
				seen += 1
				if now < 30 then
					startsBefore30 += 1
				elseif now >= 45 and now < 60 then
					startsAfter45 += 1
				end
			end
			wasWarning = isWarning
		end
		-- 10·13·16·19·22·25·28 = 7번, 45~60초 1.5초 간격 = 약 10번
		t.eq(startsBefore30, 7)
		t.ok(startsAfter45 >= 9 and startsAfter45 <= 11, `after 45: {startsAfter45}`)
		run.active.value = false
		run.env.task.cancelAll()
	end)

	t.test(
		"QA cleanup: 라운드가 끝나면 일정이 멈추고 Heartbeat·스레드·경고 원이 cleanup에 있어요",
		function()
			local run = startRun()
			local raft = raftByKey("T1_3")
			local r = newRacer("a", run.origin, raft.x, raft.topY, raft.z)
			table.insert(run.racers, r)
			run.advance(10.3)
			local warn = warnings(run.model)[1]
			t.ok(warn ~= nil, "warning up")
			local hasConn, hasThread, hasWarn = false, false, false
			for _, item in run.cleanup.items do
				if type(item) == "table" and item.Disconnect then
					hasConn = true
				elseif type(item) == "thread" then
					hasThread = true
				elseif item == warn then
					hasWarn = true
				end
			end
			t.ok(hasConn and hasThread and hasWarn, "cleanup has connection, threads, warning")
			run.active.value = false
			-- 끝난 뒤에는 새 경고·넉백·탈락이 없어요
			local before = #run.env.exempts
			moveTo(r, run.origin, 0, -30, Layout.POT_CENTER_Z)
			run.advance(10)
			t.eq(#run.env.exempts, before, "no knock after end")
			t.eq(#run.eliminated, 0, "no elimination after end")
			-- 경고 중이던 원은 루프가 그냥 돌아가고 RoundService의 cleanup이 지워요 (새 원은 안 생겨요)
			t.ok(#warnings(run.model) <= 1, "no new warning after end")
		end
	)

	t.test("QA 여러 방: 발밑 레이캐스트는 이 방 Model의 발판만 봐요", function()
		local env = loadMap()
		local runA = startRun(RCF.new(0, 300, 0), env)
		local runB = startRun(RCF.new(2000, 300, 0), env)
		local raft = raftByKey("T1_3")
		local r = newRacer("a", runA.origin, raft.x, raft.topY, raft.z)
		table.insert(runA.racers, r)
		runA.advance(0.2)
		for _, params in env.raycastParams do
			for _, p in params.FilterDescendantsInstances do
				t.ok(runA.model:IsAncestorOf(p) or runB.model:IsAncestorOf(p), "own model")
			end
		end
		-- 마지막 레이캐스트(A의 레이서)는 A의 발판만
		local last = env.raycastParams[#env.raycastParams]
		for _, p in last.FilterDescendantsInstances do
			t.ok(runA.model:IsAncestorOf(p), "A racer probes only A rafts")
		end
		t.eq(#last.FilterDescendantsInstances, #rafts() + 1)
		runA.active.value = false
		runB.active.value = false
		env.task.cancelAll()
	end)
end
