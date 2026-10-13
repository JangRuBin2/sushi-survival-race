--!strict
-- m5-06 QA (docs/qa/m5-06-map-dessert-fridge.md): 개발 테스트(map-dessert-fridge·ice-logic)에 없는 확인.
--   실제 DessertFridge.luau를 가짜 Roblox 환경(돌린 origin)에서 build/start로 돌려 봐요:
--     build: 스폰 24개가 출발 바닥 위, Ice 태그는 B·D 바닥에만, 구멍 자리에 충돌 바닥 없음, 코스가 끊기지 않음,
--            결승선 판정 파츠(충돌·쿼리·터치 없음), 젤리 3·송풍구 2, 여러 방이 서로의 태그 파츠를 안 씀
--     start: 결승선 경계(-250), 구간별 낙하선 경계(-25/-13), 끝난 라운드 무시, 젤리 튕김 속도·면제·쿨다운·
--            0.15초 뒤 제거 예약, 송풍구 불기/쉼/방향(origin.RightVector)·면제 없음·목표 이상 안 줄임, 서리 켜고 끄기
--   IceLogic 경계: 프레임 속도와 무관(지수 감쇠), 큰 dt, 걷기 0, 다이브 속도에서 늘지 않음, 음수 dt
--   IceController 정적 확인: 리모트·속성 없음, 비활성 조건, 캐릭터 바뀌면 제약 삭제
--   장식: 코스 바로 위(바닥 +0.01 ~ +2, 개발 테스트는 +2 ~ +12)와 코스 가장자리 바로 바깥에 바닥 위로 솟은
--         충돌 없는 장식(가짜 난간·턱)이 없음, 배경 바닥이 낙하선 10 아래

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.maps.DessertFridgeLayout)
local Logic = RobloxRequire.require(Shared.maps.DessertFridgeLogic)
local Art = RobloxRequire.require(Shared.maps.DessertFridgeArt)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local IceLogic = RobloxRequire.require(Shared.IceLogic)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

---------------------------------------------------------------- 가짜 Roblox

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
	function service:HasTag(inst: any, tag: string)
		return table.find(tags[tag] or {}, inst) ~= nil
	end
	return service
end

local function ctor(): any
	return {
		new = function(...)
			return { ... }
		end,
	}
end

type Env = {
	map: any,
	heartbeat: any,
	collection: any,
	setClock: (number) -> (),
	exempt: { any },
	delays: { { seconds: number, fn: () -> () } },
	sounds: { string },
}

local function loadMap(): Env
	local heartbeat = newSignal()
	local collection = newCollection()
	local clock = 0
	local exempt: { any } = {}
	local delays: { { seconds: number, fn: () -> () } } = {}
	local sounds: { string } = {}
	local stubs: { [string]: any } = {
		MapKit = {
			buildDecor = function()
				return {}
			end,
			decorFolder = function(model)
				return model
			end,
			introCamera = function() end,
			attachStudioArt = function() end,
		},
		MapSfx = {
			play = function(_, cue: string)
				table.insert(sounds, cue)
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
	local parent = setmetatable({
		Parent = setmetatable({}, {
			__index = function(_, name: string)
				return token("@" .. name)
			end,
		}),
	}, {
		__index = function(_, name: string)
			return token(name)
		end,
	})
	local map = luau.load(fs.readFile("src/shared/maps/DessertFridge.luau"), {
		debugName = "DessertFridge",
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local name = target.__mod
				local shared = string.sub(name, 1, 1) == "@"
				if shared then
					name = string.sub(name, 2)
				end
				if stubs[name] ~= nil then
					return stubs[name]
				end
				if shared then
					return RobloxRequire.require((Shared :: any)[name])
				end
				return RobloxRequire.require((Shared :: any).maps[name])
			end,
			Instance = { new = newInstance },
			Vector3 = RV3,
			Vector2 = ctor(),
			CFrame = RCF,
			Color3 = roblox.Color3,
			ColorSequence = ctor(),
			NumberSequence = ctor(),
			NumberSequenceKeypoint = ctor(),
			NumberRange = ctor(),
			PhysicalProperties = ctor(),
			Enum = enumStub,
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
					return clock
				end,
			},
			task = {
				delay = function(seconds: number, fn: () -> ())
					local entry = { seconds = seconds, fn = fn }
					table.insert(delays, entry)
					return entry
				end,
			},
		},
	})()
	return {
		map = map,
		heartbeat = heartbeat,
		collection = collection,
		setClock = function(v: number)
			clock = v
		end,
		exempt = exempt,
		delays = delays,
		sounds = sounds,
	}
end

-- 실제 아레나처럼 띄우고, 더 엄격하게 돌려 놓은 origin
local ORIGIN = RCF.new(2000, 300, 4000) * RCF.Angles(0, math.rad(90), 0)

local function world(x: number, y: number, z: number): any
	return ORIGIN * RV3.new(x, y, z)
end

local function localOf(part: any): any
	return ORIGIN:ToObjectSpace(part.CFrame)
end

local function newRacer(name: string, x: number, y: number, z: number, velocity: any?): (any, any)
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = world(x, y, z)
	root.AssemblyLinearVelocity = velocity or RV3.new(0, 0, 0)
	root.Parent = character
	local attachment = newInstance("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	return { Character = character, Name = name }, root
end

type Run = {
	env: Env,
	model: any,
	ctx: any,
	cleanup: { any },
	racers: { any },
	passed: { any },
	eliminated: { any },
	active: { value: boolean },
}

local function startRun(racers: { any }, envOverride: Env?, modelOverride: any?, startClock: number?): Run
	local env = envOverride or loadMap()
	local model = modelOverride or env.map.build(ORIGIN)
	local cleanup: { any } = {}
	local passed: { any } = {}
	local eliminated: { any } = {}
	local active = { value = true }
	local live = table.clone(racers)
	local function drop(player)
		local i = table.find(live, player)
		if i then
			table.remove(live, i)
		end
	end
	local ctx = {
		model = model,
		origin = ORIGIN,
		cleanup = {
			add = function(_, item)
				table.insert(cleanup, item)
				return item
			end,
		},
		isActive = function()
			return active.value
		end,
		getRacers = function()
			return table.clone(live)
		end,
		pass = function(player)
			table.insert(passed, player)
			drop(player)
		end,
		eliminate = function(player)
			table.insert(eliminated, player)
			drop(player)
		end,
	}
	env.setClock(startClock or 0)
	env.map.start(ctx)
	return {
		env = env,
		model = model,
		ctx = ctx,
		cleanup = cleanup,
		racers = live,
		passed = passed,
		eliminated = eliminated,
		active = active,
	}
end

local function tick(run: Run, clock: number, dt: number?)
	run.env.setClock(clock)
	run.env.heartbeat:Fire(dt or 1 / 60)
end

-- build가 만든 충돌 파츠의 로컬 상자
type Box = { name: string, minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }

local function collidableBoxes(model: any): { Box }
	local boxes: { Box } = {}
	for _, part in model:GetDescendants() do
		if part.ClassName == "Part" and part.CanCollide ~= false and part.Size then
			local rel = localOf(part).Position
			local half = part.Size / 2
			table.insert(boxes, {
				name = part.Name,
				minX = rel.X - half.X,
				maxX = rel.X + half.X,
				minY = rel.Y - half.Y,
				maxY = rel.Y + half.Y,
				minZ = rel.Z - half.Z,
				maxZ = rel.Z + half.Z,
			})
		end
	end
	return boxes
end

-- (x, z)를 덮는 충돌 파츠 중 윗면이 topY(±0.01)인 것이 있는지
local function floorAt(boxes: { Box }, x: number, z: number, topY: number): Box?
	for _, b in boxes do
		if x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ and math.abs(b.maxY - topY) < 0.01 then
			return b
		end
	end
	return nil
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-4)
end

return function(t: Test.Test)
	---------------------------------------------------------------- build

	t.test("QA build: 스폰 24개가 모두 출발 바닥(y 0) 위, 충돌·터치·쿼리 없음", function()
		local env = loadMap()
		local model = env.map.build(ORIGIN)
		local boxes = collidableBoxes(model)
		local spawns = model:FindFirstChild("Spawns"):GetChildren()
		t.eq(#spawns, 24)
		for _, spawn in spawns do
			local rel = localOf(spawn).Position
			for _, dx in { -1, 1 } do
				for _, dz in { -1, 1 } do
					local f = floorAt(boxes, rel.X + dx, rel.Z + dz, Layout.LOW_Y)
					t.ok(f ~= nil and f.name == "StartFloor", `{spawn.Name} corner on StartFloor`)
				end
			end
			t.eq(spawn.CanCollide, false, spawn.Name)
			t.eq(spawn.CanTouch, false, spawn.Name)
			t.eq(spawn.CanQuery, false, spawn.Name)
		end
	end)

	t.test(
		"QA build: Ice 태그는 B 얼음 쟁반 조각과 D 선반에만, 전부 Ice 재질이고 윗면 y 0 / 12",
		function()
			local env = loadMap()
			local model = env.map.build(ORIGIN)
			local iced = env.collection:GetTagged("Ice")
			local trayCount, shelfCount = 0, 0
			for _, part in iced do
				t.ok(model:IsAncestorOf(part), "ice part in model")
				t.eq(part.Material, "Material.Ice", part.Name)
				t.eq(part.CanCollide, true, part.Name)
				t.eq(part.Anchored, true, part.Name)
				local rel = localOf(part).Position
				local top = rel.Y + part.Size.Y / 2
				if string.match(part.Name, "^IceTray") then
					trayCount += 1
					t.ok(near(top, Layout.LOW_Y), `{part.Name} top {top}`)
				elseif part.Name == "FanShelf" then
					shelfCount += 1
					t.ok(near(top, Layout.HIGH_Y), `FanShelf top {top}`)
				else
					t.ok(false, `unexpected Ice tag on {part.Name}`)
				end
			end
			t.eq(trayCount, #Layout.iceTrayRects())
			t.eq(shelfCount, 1)
			-- 일반 바닥(출발·C·착지대·결승)·큐브·젤리·쿠키에는 Ice 태그가 없어요
			for _, name in { "StartFloor", "JellyFloor", "Landing", "FinishFloor", "IceCube1", "Jelly1", "CookieStep1" } do
				local part = model:FindFirstChild(name)
				t.ok(part ~= nil, name)
				t.ok(not env.collection:HasTag(part, "Ice"), `{name} must not be Ice`)
			end
		end
	)

	t.test(
		"QA build: 구멍 자리에는 충돌 바닥이 없고, 구멍 바로 옆은 얼음 바닥이에요",
		function()
			local env = loadMap()
			local model = env.map.build(ORIGIN)
			local boxes = collidableBoxes(model)
			for _, hole in Layout.HOLES do
				for _, d in { { 0, 0 }, { -2.9, -2.9 }, { 2.9, 2.9 }, { -2.9, 2.9 }, { 2.9, -2.9 } } do
					local x, z = hole.x + d[1], hole.z + d[2]
					for _, b in boxes do
						local covers = x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ and b.maxY > -25
						t.ok(not covers, `hole ({x},{z}) covered by {b.name}`)
					end
				end
				t.ok(floorAt(boxes, hole.x + 3.2, hole.z, Layout.LOW_Y) ~= nil, "ice right of hole")
				t.ok(floorAt(boxes, hole.x - 3.2, hole.z, Layout.LOW_Y) ~= nil, "ice left of hole")
			end
		end
	)

	t.test(
		"QA build: x = 0 줄을 따라 출발 → 결승 끝까지 바닥이 끊기지 않아요 (C 착지대에서 0 → 12)",
		function()
			local env = loadMap()
			local model = env.map.build(ORIGIN)
			local boxes = collidableBoxes(model)
			local z = -0.25
			while z > Layout.FINISH.back do
				local expectedTop = if z > Layout.LANDING.front then Layout.LOW_Y else Layout.HIGH_Y
				-- 구멍(x -5 / +5)은 x = 0을 덮지 않아요(6 폭 → x -8 ~ -2, 2 ~ 8). 젤리 구간(x 0은 젤리 2 위)은 윗면 1
				local f = floorAt(boxes, 0, z, expectedTop)
				if f == nil and z <= -116 and z >= -124 then
					f = floorAt(boxes, 0, z, Layout.JELLY_TOP)
				end
				t.ok(f ~= nil, `no floor at z {z}`)
				z -= 0.5
			end
			-- 결승선 너머에도 바닥이 있어요
			t.ok(floorAt(boxes, 0, Layout.FINISH_LINE_Z - 5, Layout.HIGH_Y) ~= nil, "floor past the finish")
		end
	)

	t.test("QA build: 결승선은 z -250, 충돌·터치·쿼리 없음, 결승 바닥 폭 전체", function()
		local env = loadMap()
		local model = env.map.build(ORIGIN)
		local line = model:FindFirstChild("FinishLine")
		t.ok(line ~= nil, "FinishLine")
		local rel = localOf(line).Position
		t.ok(near(rel.Z, -250), `finish z {rel.Z}`)
		t.eq(line.CanCollide, false)
		t.eq(line.CanTouch, false)
		t.eq(line.CanQuery, false)
		t.eq(line.Size.X, Layout.FINISH_WIDTH)
	end)

	t.test(
		"QA build: 젤리 3개(윗면 1·Jelly 태그·충돌), 송풍구 2개(ColdFan 태그·충돌 없음·서리 꺼짐·선반 바깥)",
		function()
			local env = loadMap()
			local model = env.map.build(ORIGIN)
			local jellies = env.collection:GetTagged("Jelly")
			t.eq(#jellies, 3)
			for _, pad in jellies do
				local rel = localOf(pad).Position
				t.ok(near(rel.Y + pad.Size.Y / 2, Layout.JELLY_TOP), `{pad.Name} top`)
				t.eq(pad.CanCollide, true)
				t.eq(pad.Anchored, true)
			end
			local fans = env.collection:GetTagged("ColdFan")
			t.eq(#fans, 2)
			for _, vent in fans do
				t.eq(vent.CanCollide, false)
				t.eq(vent.CanQuery, false)
				t.eq(vent.CanTouch, false)
				local index = vent:GetAttribute("FanIndex")
				t.ok(index == 1 or index == 2, "FanIndex")
				local frost = vent:FindFirstChild("Frost")
				t.ok(frost ~= nil and frost.Enabled == false, "frost starts off")
				local rel = localOf(vent).Position
				t.ok(math.abs(rel.X) > Layout.FAN_SHELF_WIDTH / 2, "vent outside the shelf")
				-- 미는 방향의 반대편에 있어요 (+X로 밀면 왼쪽 벽)
				t.ok(rel.X * Layout.FANS[index].dirX < 0, "vent on the upwind side")
			end
		end
	)

	---------------------------------------------------------------- start: 판정

	t.test("QA start: 결승선 -250에서 통과, -249.9는 아직 (돌린 origin)", function()
		local near1, _ = newRacer("near", 0, 15, -249.9)
		local over, _ = newRacer("over", 6, 15, -250)
		local run = startRun({ near1, over })
		tick(run, 0.1)
		t.eq(run.passed, { over })
		t.eq(#run.eliminated, 0)
	end)

	t.test("QA start: 낙하선 경계 — B·C -25, D·E -13 (C 착지대 위에서 떨어져도 -25)", function()
		local cases = {
			{ z = -40, y = -25.1, out = true },
			{ z = -40, y = -24.9, out = false },
			{ z = -130, y = -24.9, out = false }, -- C 착지대 아래 (C 구간 낙하선 -25)
			{ z = -150, y = -13.1, out = true },
			{ z = -150, y = -12.9, out = false },
			{ z = -240, y = -13.1, out = true },
			{ z = 5, y = -25.1, out = true }, -- 출발 뒤로 떨어져도
		}
		for _, case in cases do
			local racer = newRacer("r", 0, case.y, case.z)
			local run = startRun({ racer })
			tick(run, 0.1)
			t.eq(#run.eliminated, if case.out then 1 else 0, `z {case.z} y {case.y}`)
			t.eq(#run.passed, 0)
		end
	end)

	t.test("QA start: 라운드가 끝나면(isActive false) 판정·밀기·튕김 모두 안 해요", function()
		local faller = newRacer("faller", 0, -40, -40)
		local jumper, jumperRoot = newRacer("jumper", -3, 4, -120)
		local run = startRun({ faller, jumper })
		run.active.value = false
		tick(run, 1.0)
		t.eq(#run.eliminated, 0)
		t.eq(#run.passed, 0)
		t.eq(#run.env.exempt, 0)
		t.eq(jumperRoot:FindFirstChild("JellyLaunch"), nil)
	end)

	t.test("QA start: Heartbeat 연결이 ctx.cleanup에 들어가요", function()
		local run = startRun({})
		local hasConnection = false
		for _, item in run.cleanup do
			if type(item) == "table" and type(item.Disconnect) == "function" then
				hasConnection = true
			end
		end
		t.ok(hasConnection, "heartbeat connection registered for cleanup")
	end)

	---------------------------------------------------------------- start: 젤리

	t.test(
		"QA 젤리: 위 72 + 진행 방향 10, 면제 1.5초, LinearVelocity 0.15초 뒤 제거 예약, 소리",
		function()
			local racer, root = newRacer("jumper", -3, 4, -120)
			local run = startRun({ racer })
			tick(run, 0.1)
			local launch = root:FindFirstChild("JellyLaunch")
			t.ok(launch ~= nil, "JellyLaunch")
			local expected = RV3.new(0, Layout.JELLY_UP, 0) + ORIGIN.LookVector * Layout.JELLY_FORWARD
			t.ok((launch.VectorVelocity - expected).Magnitude < 1e-4, "launch velocity")
			t.ok((root.AssemblyLinearVelocity - expected).Magnitude < 1e-4, "root velocity")
			t.eq(launch.MaxForce, math.huge)
			t.eq(launch.Attachment0, root:FindFirstChild("RootAttachment"))
			t.eq(#run.env.exempt, 1)
			t.eq(run.env.exempt[1].character, racer.Character)
			t.eq(run.env.exempt[1].seconds, 1.5)
			t.eq(table.find(run.cleanup, launch) ~= nil, true, "launch in cleanup")
			local hold = nil
			for _, d in run.env.delays do
				if near(d.seconds, Layout.JELLY_HOLD) then
					hold = d
				end
			end
			t.ok(hold ~= nil, "removal scheduled after JELLY_HOLD")
			t.ok(table.find(run.cleanup, hold) ~= nil, "removal thread in cleanup")
			hold.fn()
			t.eq(root:FindFirstChild("JellyLaunch"), nil, "removed after hold")
			t.ok(table.find(run.env.sounds, "JellyBoing") ~= nil, "JellyBoing")
		end
	)

	t.test("QA 젤리: 같은 사람 0.6초 쿨다운 (0.59 안 튕김, 0.6 다시 튕김)", function()
		local racer = newRacer("jumper", 5, 3, -118)
		local run = startRun({ racer })
		tick(run, 1.0)
		t.eq(#run.env.exempt, 1)
		tick(run, 1.59)
		t.eq(#run.env.exempt, 1)
		tick(run, 1.6)
		t.eq(#run.env.exempt, 2)
	end)

	t.test(
		"QA 젤리: 옆 바닥·쿠키 계단·착지대 위·젤리 위 높이 떠 있으면 안 튕겨요",
		function()
			local spots = {
				{ 12, 3, -120 }, -- 쿠키 계단 옆 바닥 (x 9 ~ 15)
				{ 0, 3, -110 }, -- 젤리 앞 C 바닥
				{ -3, 15, -126 }, -- 착지대 위
				{ -3, 7, -120 }, -- 젤리 위 6 (튕겨 오르는 중)
				{ -16, 3, -120 }, -- C 폭 밖
			}
			for _, p in spots do
				local racer = newRacer("r", p[1], p[2], p[3])
				local run = startRun({ racer })
				tick(run, 0.1)
				t.eq(#run.env.exempt, 0, `({p[1]},{p[2]},{p[3]})`)
			end
		end
	)

	---------------------------------------------------------------- start: 송풍구

	t.test(
		"QA 송풍구: 불기 동안만 origin.RightVector 쪽으로 40/s 가속, MoveExempt 없음, 소리는 불기 시작 한 번",
		function()
			local racer, root = newRacer("r", 0, 15, -158)
			local run = startRun({ racer })
			local right = ORIGIN.RightVector
			-- 경고 (0 ~ 0.5): 밀지 않음, 서리 켜짐
			tick(run, 0.2, 0.1)
			t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, "no push while warning")
			local fan1 = nil
			for _, vent in run.env.collection:GetTagged("ColdFan") do
				if vent:GetAttribute("FanIndex") == 1 and run.model:IsAncestorOf(vent) then
					fan1 = vent
				end
			end
			t.ok(fan1:FindFirstChild("Frost").Enabled, "frost on while warning")
			-- 불기 (0.5 ~ 2.5)
			tick(run, 1.0, 0.1)
			t.ok(near(root.AssemblyLinearVelocity:Dot(right), 4, 1e-4), "push +4 after 0.1s")
			t.ok(
				near(root.AssemblyLinearVelocity.Y, 0) and near(root.AssemblyLinearVelocity:Dot(ORIGIN.LookVector), 0),
				"only sideways"
			)
			tick(run, 1.1, 0.1)
			t.ok(near(root.AssemblyLinearVelocity:Dot(right), 8, 1e-4), "push +8 after 0.2s")
			-- 쉼 (2.5 ~ 4): 그대로, 서리 꺼짐
			tick(run, 3.0, 0.1)
			t.ok(near(root.AssemblyLinearVelocity:Dot(right), 8, 1e-4), "no push while resting")
			t.eq(fan1:FindFirstChild("Frost").Enabled, false, "frost off while resting")
			t.eq(#run.env.exempt, 0, "fan push must not mark MoveExempt (decision Q2)")
			local gusts = 0
			for _, cue in run.env.sounds do
				if cue == "FanGust" then
					gusts += 1
				end
			end
			-- 불기 시작마다 한 번: 송풍구 2(t 0.2 첫 틱에 이미 불기) + 송풍구 1(t 1.0) + 송풍구 2 다음 주기(t 3.0 = 위상 1.0)
			t.eq(gusts, 3)
		end
	)

	t.test(
		"QA 송풍구: 2번은 -X로 밀고, 목표 14보다 빠르면 줄이지 않아요, 선반 밖·높이 떠 있으면 안 밀어요",
		function()
			local right = ORIGIN.RightVector
			-- 송풍구 2 (offset 2): t 3.0 → 위상 1.0 = 불기
			local r2, root2 = newRacer("r2", 0, 15, -194)
			local run = startRun({ r2 })
			tick(run, 3.0, 0.1)
			t.ok(near(root2.AssemblyLinearVelocity:Dot(right), -4, 1e-4), "fan 2 pushes -X")
			-- 이미 +20으로 미끄러지는 사람은 송풍구 1이 줄이지 않아요
			local fast, fastRoot = newRacer("fast", 0, 15, -158, right * 20)
			run = startRun({ fast })
			tick(run, 1.0, 0.1)
			t.ok(near(fastRoot.AssemblyLinearVelocity:Dot(right), 20, 1e-4), "faster than target: unchanged")
			-- 목표 근처에서 넘치지 않아요
			local almost, almostRoot = newRacer("almost", 0, 15, -158, right * 13)
			run = startRun({ almost })
			tick(run, 1.0, 0.1)
			t.ok(near(almostRoot.AssemblyLinearVelocity:Dot(right), 14, 1e-4), "capped at 14")
			-- 선반 밖(떨어지는 중)·바닥 위 8 넘게 떠 있으면 안 밀어요
			for _, p in { { 10, 15, -158 }, { 0, 21, -158 }, { 0, 15, -176 } } do
				local r, root = newRacer("r", p[1], p[2], p[3])
				run = startRun({ r })
				tick(run, 1.0, 0.1)
				t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, `({p[1]},{p[2]},{p[3]}) not pushed`)
			end
		end
	)

	t.test(
		"QA 송풍구: 밀기 14 + 걷기 16 + 송풍구 겹침 없음 → 이동 감시 상한 80보다 한참 아래",
		function()
			local Config = RobloxRequire.require(Shared.Config)
			local guard = Config.MovementGuard
			local limit = guard.MaxHorizontalSpeed
			t.ok(
				Layout.FAN_PUSH_SPEED + Config.Character.WalkSpeed <= limit / 2,
				"fan + walk well under the guard limit"
			)
			-- 두 송풍구 구역은 겹치지 않아요 (한 사람이 두 바람을 같이 맞지 않음)
			local a, b = Layout.FANS[1], Layout.FANS[2]
			t.ok(a.back > b.front or b.back > a.front, "fan zones do not overlap")
		end
	)

	---------------------------------------------------------------- 여러 방

	t.test(
		"QA 여러 방: 한 방의 start는 자기 모델의 송풍구 서리만 켜요 (상태가 ctx별)",
		function()
			local env = loadMap()
			local modelA = env.map.build(ORIGIN)
			local otherOrigin = RCF.new(4000, 300, 4000)
			local modelB = env.map.build(otherOrigin)
			local run = startRun({}, env, modelA)
			tick(run, 0.2)
			for _, vent in env.collection:GetTagged("ColdFan") do
				local frost = vent:FindFirstChild("Frost")
				if modelB:IsAncestorOf(vent) then
					t.eq(frost.Enabled, false, "other room's frost untouched")
				end
			end
			-- 모듈 수준 상태 없음: 같은 모듈로 두 번째 방을 따로 시작해도 첫 방 시계와 무관해요
			local racer, root = newRacer("r", 0, 15, -158)
			local run2 = startRun({ racer }, env, env.map.build(ORIGIN), 10.0) -- 이 방은 시계 10.0에서 시작
			tick(run2, 10.2, 0.1) -- 두 번째 방 기준 0.2초 → 경고, 안 밀어요
			t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, "second room uses its own start time")
		end
	)

	---------------------------------------------------------------- IceLogic 경계

	t.test("QA IceLogic: 프레임 속도와 무관 (1/240·1/60·1/30로 1초 = 한 번에 1초)", function()
		for _, target in { { x = 0, z = -16 }, { x = 0, z = 0 } } do
			local once = IceLogic.step({ x = 12, z = 3 }, target, 1, 16)
			for _, fps in { 30, 60, 240 } do
				local v = { x = 12, z = 3 }
				for _ = 1, fps do
					v = IceLogic.step(v, target, 1 / fps, 16)
				end
				t.ok(math.abs(v.x - once.x) < 1e-6 and math.abs(v.z - once.z) < 1e-6, `fps {fps}`)
			end
		end
	end)

	t.test(
		"QA IceLogic: 큰 dt는 목표에 닿고 넘지 않음, 음수 dt는 그대로, 걷기 0 + 입력 없음은 감쇠",
		function()
			local v = IceLogic.step({ x = 0, z = 0 }, { x = 16, z = 0 }, 1e6, 16)
			t.ok(math.abs(v.x - 16) < 1e-9 and v.z == 0, "huge dt reaches target")
			local same = IceLogic.step({ x = 3, z = -4 }, { x = 16, z = 0 }, -0.5, 16)
			t.eq(same, { x = 3, z = -4 })
			local frozen = IceLogic.step({ x = 10, z = 0 }, { x = 0, z = 0 }, 0.5, 0)
			t.ok(frozen.x < 10 and frozen.x > 0, "WalkSpeed 0 still slides and decays")
			-- 아주 작은 입력은 입력 없음
			local tiny = IceLogic.step({ x = 10, z = 0 }, { x = 1e-4, z = 0 }, 1, 16)
			t.ok(math.abs(tiny.x - 10 * math.exp(-1)) < 1e-9, "tiny input counts as no input")
		end
	)

	t.test(
		"QA IceLogic: 다이브 40에서 입력을 유지해도 속도가 늘지 않고 16으로 줄어요 (이동 감시와 무관)",
		function()
			local v = { x = 0, z = -40 }
			local last = 40 -- 크기 상한은 max(지난 크기, 걷기 16): 꺾는 동안 16 아래로 내려갔다가 16까지 돌아올 수 있어요
			for _ = 1, 600 do
				v = IceLogic.step(v, { x = 16, z = 0 }, 1 / 60, 16) -- 옆으로 꺾으며
				local m = math.sqrt(v.x * v.x + v.z * v.z)
				t.ok(m <= math.max(last, 16) + 1e-9, "never above max(|current|, walkSpeed)")
				last = m
			end
			t.ok(math.abs(v.x - 16) < 0.01 and math.abs(v.z) < 0.01, "settles on the walk target")
			-- 입력 없이 미끄러지는 거리: 16 → 적분 16/DRAG = 약 16 studs
			local s, dist = { x = 0, z = -16 }, 0
			for _ = 1, 60 * 20 do
				s = IceLogic.step(s, { x = 0, z = 0 }, 1 / 60, 16)
				dist += math.abs(s.z) / 60
			end
			t.ok(dist > 15 and dist < 16.1, `slide distance {dist}`)
		end
	)

	---------------------------------------------------------------- IceController 정적 확인

	t.test(
		"QA IceController: 리모트·속성·서버 신뢰 없음, 비활성 조건, 캐릭터 바뀌면 제약 삭제, 등록",
		function()
			local source = fs.readFile("src/client/input/IceController.luau")
			for _, banned in { "Remotes", "FireServer", "InvokeServer", "SetAttribute", "MoveExempt" } do
				t.eq(string.find(source, banned, 1, true), nil, `IceController must not use {banned}`)
			end
			for _, state in
				{ "Dead", "Seated", "Ragdoll", "FallingDown", "GettingUp", "Freefall", "Jumping", "Physics" }
			do
				t.ok(string.find(source, `HumanoidStateType.{state}`, 1, true) ~= nil, `skips {state}`)
			end
			for _, guard in
				{ "humanoid.Health > 0", "not humanoid.PlatformStand", "not humanoid.Sit", "not root.Anchored" }
			do
				t.ok(string.find(source, guard, 1, true) ~= nil, guard)
			end
			t.ok(string.find(source, "glideRoot ~= root", 1, true) ~= nil, "new character destroys the old glide")
			t.ok(string.find(source, "IsDescendantOf(workspace)", 1, true) ~= nil, "no character -> destroy")
			t.ok(string.find(source, "VelocityConstraintMode.Plane", 1, true) ~= nil, "horizontal only")
			local init = fs.readFile("src/client/init.client.luau")
			t.ok(string.find(init, "input.IceController", 1, true) ~= nil, "IceController registered")
			-- 얼음 태그는 디저트 냉장고에만 (다른 맵·로비로 얼음 모드가 새지 않음)
			for _, file in fs.readDir("src/shared/maps") do
				if file ~= "DessertFridge.luau" and string.match(file, "%.luau$") then
					local text = fs.readFile("src/shared/maps/" .. file)
					t.eq(string.find(text, "IceLogic.TAG", 1, true), nil, `{file} uses the Ice tag`)
					t.eq(string.find(text, 'AddTag%([^,]+,%s*"Ice"%)'), nil, `{file} tags Ice`)
				end
			end
		end
	)

	---------------------------------------------------------------- 장식 가독성

	t.test(
		"QA 장식: 코스 바로 위(바닥 +0.01 ~ +2)에 장식 없음 — 걸려 넘어질 것처럼 보이는 가짜 턱 없음",
		function()
			local low, high = Layout.LOW_Y, Layout.HIGH_Y
			local strips = {
				{ half = Layout.START_WIDTH / 2, y = low, front = Layout.START.front, back = Layout.START.back },
				{
					half = Layout.ICE_TRAY_WIDTH / 2,
					y = low,
					front = Layout.ICE_TRAY.front,
					back = Layout.ICE_TRAY.back,
				},
				{
					half = Layout.JELLY_ZONE_WIDTH / 2,
					y = low,
					front = Layout.JELLY_ZONE.front,
					back = Layout.LANDING.front,
				},
				{
					half = Layout.JELLY_ZONE_WIDTH / 2,
					y = high,
					front = Layout.LANDING.front,
					back = Layout.LANDING.back,
				},
				{
					half = Layout.FAN_SHELF_WIDTH / 2,
					y = high,
					front = Layout.FAN_SHELF.front,
					back = Layout.FAN_SHELF.back,
				},
				{ half = Layout.FINISH_WIDTH / 2, y = high, front = Layout.FINISH.front, back = Layout.FINISH.back },
			}
			for _, spec in Art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: any
				for i, s in strips do
					local overlap = b.min.x < s.half - 0.01
						and b.max.x > -s.half + 0.01
						and b.min.z < s.front - 0.01
						and b.max.z > s.back + 0.01
						and b.max.y > s.y + 0.01
						and b.min.y < s.y + 2
					t.ok(not overlap, `{spec.name} sits on course strip {i}`)
				end
			end
		end
	)

	t.test(
		"QA 장식: 양옆 벽이 없는 B·D 가장자리 바로 바깥(1.5 안)에 바닥보다 솟은 장식 없음 — 가짜 난간 없음",
		function()
			local edges = {
				{
					half = Layout.ICE_TRAY_WIDTH / 2,
					y = Layout.LOW_Y,
					front = Layout.ICE_TRAY.front,
					back = Layout.ICE_TRAY.back,
				},
				{
					half = Layout.FAN_SHELF_WIDTH / 2,
					y = Layout.HIGH_Y,
					front = Layout.FAN_SHELF.front,
					back = Layout.FAN_SHELF.back,
				},
			}
			for _, spec in Art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: any
				for i, e in edges do
					for _, side in { -1, 1 } do
						local x0 = if side > 0 then e.half else -e.half - 1.5
						local x1 = if side > 0 then e.half + 1.5 else -e.half
						local overlap = b.min.x < x1
							and b.max.x > x0
							and b.min.z < e.front - 0.01
							and b.max.z > e.back + 0.01
							and b.max.y > e.y + 0.3
							and b.min.y < e.y + 6
						if overlap then
							-- B2(P3): D 선반 송풍구 하우징·테(바람이 나오는 쪽 반대편, 송풍구 z 구간 안)만 예외로 기록해요.
							-- 판정 송풍구 파츠(ColdFan, CanCollide false)와 같은 자리라 "벽"처럼 보이지만 막지 않아요.
							local inFan = false
							for _, fan in Layout.FANS do
								if b.max.z <= fan.front + 2.01 and b.min.z >= fan.back - 2.01 and side == -fan.dirX then
									inFan = true
								end
							end
							local known = i == 2 and inFan and string.match(spec.name, "^Fan") ~= nil
							t.ok(known, `{spec.name} looks like a rail on edge {i} side {side} z {b.min.z}..{b.max.z}`)
						end
					end
				end
			end
		end
	)

	t.test(
		"QA 장식: 아래 유리 선반은 코스 가장자리에서 15 이상, 바닥보다 10 이상 낮고, 배경 바닥은 낙하선 10 아래",
		function()
			local widest = math.max(
				Layout.START_WIDTH,
				Layout.ICE_TRAY_WIDTH,
				Layout.JELLY_ZONE_WIDTH,
				Layout.FINISH_WIDTH
			) / 2
			t.ok(Art.SHELF_INNER_X - widest >= 15, "low shelf 15+ studs from the widest course edge")
			t.ok(Layout.LOW_Y - Art.LOW_SHELF_Y >= 10, "low shelf 10+ below the low floor")
			for _, spec in Art.decor() do
				if spec.name == "GlassShelf" then
					local b = MapKitLogic.bounds({ spec }) :: any
					t.ok(math.min(math.abs(b.min.x), math.abs(b.max.x)) >= Art.SHELF_INNER_X - 0.01, "shelf inner edge")
					t.ok((spec.transparency or 0) <= 0.5, "glass shelf transparency <= 0.5 (guide)")
				end
			end
			t.ok(Art.DRAWER_TOP_Y <= Logic.fallLineAt(0) - 10, "crisper 10 below fall line")
			t.ok(Art.KITCHEN_FLOOR_Y <= Logic.fallLineAt(-250) - 10, "kitchen 10 below fall line")
		end
	)

	t.test("QA 장식: 소개 카메라 4점이 냉장고 안(벽·천장·뒷벽 안쪽)에 있어요", function()
		for i, p in Art.introCamera() do
			t.ok(math.abs(p.pos.x) < Art.IN_X, `intro {i} x`)
			t.ok(p.pos.y < Art.CEIL_Y and p.pos.y > Art.FLOOR_Y, `intro {i} y`)
			t.ok(p.pos.z < Art.BACK_Z and p.pos.z > Art.FRONT_Z, `intro {i} z`)
		end
	end)
end
