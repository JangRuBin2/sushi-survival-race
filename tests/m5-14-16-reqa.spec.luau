--!strict
-- m5-14·m5-15·m5-16 재QA (브랜치 m5-maps-fix-a): 버그 수정을 실제 맵 코드로 돌려 보는 확인.
--   m5-14 B1: build가 실제로 만든 벽(충돌 파츠)으로 격자를 칠해 플러드필 — S자 길이 유일하고 길이가 S자만큼 길다
--   m5-14 B2·B3·B5: start를 가짜 Heartbeat로 돌려 수평 속도 유지·LinearVelocity 재사용·cleanup 항목 고정·
--                   유지 시간 끝에 꺼짐(라운드가 끝나도·통과해도)·레이캐스트 여유
--   m5-15 B1·B2: start를 돌린 origin(회전)에서 돌려 다리 판의 낮은 가장자리 쪽으로 밀고, 떨어지는 중·판 밖은
--                인원·밀기에서 빠지는지
--   m5-16 B1·B3: 블록 이름 ↔ 높이 ↔ 숨기는 순서가 build·start에서 같은지, 무작위 보드에서 테두리 바깥 기울기 상한

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

---------------------------------------------------------------- 가짜 Roblox (인스턴스·신호·태그)

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
	return service
end

type Env = {
	map: any,
	heartbeat: any,
	collection: any,
	setClock: (number) -> (),
	exemptCount: () -> number,
	setRaycast: (any) -> (),
}

-- 맵 모듈 하나를 가짜 환경으로 불러요. 순수 모듈(Layout·Logic·Art·Config)은 진짜, MapKit·MapSfx·MoveExempt는 가짜.
local function loadMap(file: string): Env
	local heartbeat = newSignal()
	local collection = newCollection()
	local clock = 0
	local exempt = 0
	local raycast: any = function()
		return nil
	end
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
		MapSfx = { play = function() end },
		MapTypes = {},
		MoveExempt = {
			mark = function()
				exempt += 1
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
	local map = luau.load(fs.readFile(`src/shared/maps/{file}.luau`), {
		debugName = file,
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local name = target.__mod
				if stubs[name] ~= nil then
					return stubs[name]
				end
				if name == "Config" then
					return RobloxRequire.require((Shared :: any)[name])
				end
				return RobloxRequire.require((Shared :: any).maps[name])
			end,
			Instance = { new = newInstance },
			Vector3 = RV3,
			CFrame = RCF,
			Color3 = roblox.Color3,
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
			os = {
				clock = function()
					return clock
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
		exemptCount = function()
			return exempt
		end,
		setRaycast = function(fn)
			raycast = fn
		end,
	}
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

local function newRacer(position: any, velocity: any): (any, any)
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.AssemblyLinearVelocity = velocity
	root.Parent = character
	local attachment = newInstance("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	return { Character = character, Name = "racer" }, root
end

local function countClass(parent: any, cls: string): number
	local n = 0
	for _, child in parent:GetChildren() do
		if child.ClassName == cls then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- m5-14 방방 미로

local MazeLayout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)

-- 돌린 origin(실제 아레나는 회전이 없지만 더 엄격하게)
local MAZE_ORIGIN = RCF.new(2000, 300, 4000) * RCF.Angles(0, math.rad(90), 0)

type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

-- build가 만든 충돌 파츠 중 서 있는 높이(로컬 y 1~3)를 가로막는 것 → origin 기준 xz 상자
local function wallBoxes(model: any, origin: any): { Box }
	local boxes: { Box } = {}
	for _, part in model:GetDescendants() do
		if part.ClassName == "Part" and part.CanCollide ~= false and part.Size then
			local rel = origin:ToObjectSpace(part.CFrame).Position
			local half = part.Size / 2
			if rel.Y + half.Y > 1 and rel.Y - half.Y < 3 then
				table.insert(boxes, {
					minX = rel.X - half.X,
					maxX = rel.X + half.X,
					minZ = rel.Z - half.Z,
					maxZ = rel.Z + half.Z,
				})
			end
		end
	end
	return boxes
end

local function blockedByBoxes(boxes: { Box }, x: number, z: number): boolean
	for _, b in boxes do
		if x >= b.minX - 0.01 and x <= b.maxX + 0.01 and z >= b.minZ - 0.01 and z <= b.maxZ + 0.01 then
			return true
		end
	end
	return false
end

-- 스폰 앞(0, -3)에서 1 stud 격자 BFS. 결승선(z ≤ FINISH_LINE_Z)까지의 최단 걸음 수(못 닿으면 nil).
local function shortestToFinish(boxes: { Box }, extraBlocked: ((number, number) -> boolean)?): number?
	local function key(x: number, z: number): string
		return `{x},{z}`
	end
	local xMin, xMax = -MazeLayout.HALF_WIDTH + 1, MazeLayout.HALF_WIDTH - 1
	local zMax, zMin = MazeLayout.START.front - 1, MazeLayout.FINISH.back + 1
	local dist: { [string]: number } = { [key(0, -3)] = 0 }
	local queue = { { x = 0, z = -3 } }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		local d = dist[key(cur.x, cur.z)]
		if cur.z <= MazeLayout.FINISH_LINE_Z then
			return d
		end
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = cur.x + step[1], cur.z + step[2]
			local k = key(nx, nz)
			if
				nx >= xMin
				and nx <= xMax
				and nz >= zMin
				and nz <= zMax
				and dist[k] == nil
				and not blockedByBoxes(boxes, nx, nz)
				and not (extraBlocked and extraBlocked(nx, nz))
			then
				dist[k] = d + 1
				table.insert(queue, { x = nx, z = nz })
			end
		end
	end
	return nil
end

type MazeRun = {
	env: Env,
	ctx: any,
	cleanup: any,
	racers: { any },
	active: { value: boolean },
	floor: any,
}

local function startMaze(): MazeRun
	local env = loadMap("BouncyCastleMaze")
	local model = env.map.build(MAZE_ORIGIN)
	local floor = model:FindFirstChild("FloorBounce")
	assert(floor, "FloorBounce")
	local cleanup = newCleanup()
	local racers: { any } = {}
	local active = { value = true }
	local ctx = {
		model = model,
		origin = MAZE_ORIGIN,
		cleanup = cleanup,
		isActive = function()
			return active.value
		end,
		getRacers = function()
			return table.clone(racers)
		end,
		pass = function() end,
		eliminate = function() end,
	}
	-- 발밑 레이캐스트: 로컬 높이로 판단 (BounceFloor 윗면은 로컬 y 0, z가 B+C 구간 안일 때만)
	env.setRaycast(function(origin, direction, params)
		local rel = MAZE_ORIGIN:PointToObjectSpace(origin)
		local onBounceSpan = rel.Z <= MazeLayout.ANTEROOM.front and rel.Z >= MazeLayout.MAZE.back
		local included = table.find(params.FilterDescendantsInstances, floor) ~= nil
		if included and onBounceSpan and rel.Y + direction.Y <= 0 then
			return { Instance = floor }
		end
		return nil
	end)
	env.map.start(ctx)
	return { env = env, ctx = ctx, cleanup = cleanup, racers = racers, active = active, floor = floor }
end

local function mazePoint(x: number, y: number, z: number): any
	return MAZE_ORIGIN:PointToWorldSpace(RV3.new(x, y, z))
end

---------------------------------------------------------------- m5-15 등불 다리

local BridgeLayout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local BridgeLogic = RobloxRequire.require(Shared.maps.LanternBridgeLogic)

local BRIDGE_ORIGIN = RCF.new(100, 50, -30) * RCF.Angles(0, math.rad(37), 0)

type BridgeRun = { env: Env, racers: { any }, planks: { [number]: any } }

local function startBridge(): BridgeRun
	local env = loadMap("LanternBridge")
	local model = newInstance("Model")
	local planks: { [number]: any } = {}
	for _, bridge in BridgeLayout.BRIDGES do
		local part = newInstance("Part")
		part.Name = `Plank{bridge.index}`
		part:SetAttribute("BridgeIndex", bridge.index)
		part.Parent = model
		env.collection:AddTag(part, "LanternBridgePlank")
		planks[bridge.index] = part
	end
	local racers: { any } = {}
	env.setClock(0)
	env.map.start({
		model = model,
		origin = BRIDGE_ORIGIN,
		cleanup = newCleanup(),
		isActive = function()
			return true
		end,
		getRacers = function()
			return table.clone(racers)
		end,
		pass = function() end,
		eliminate = function() end,
	})
	return { env = env, racers = racers, planks = planks }
end

local function bridgePoint(x: number, y: number, z: number): any
	return BRIDGE_ORIGIN:PointToWorldSpace(RV3.new(x, y, z))
end

local function centerOf(bridge: any): number
	return (bridge.front + bridge.back) / 2
end

---------------------------------------------------------------- m5-16 와르르 나무 블록

local JengaLayout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local JengaLogic = RobloxRequire.require(Shared.maps.GiantJengaLogic)

return function(t: Test.Test)
	---------------------------------------------------------------- m5-14 B1
	t.test(
		"m5-14 재QA B1: build가 세운 실제 벽으로 길을 찾으면 결승까지는 S자 길(약 300 studs 이상)뿐이에요",
		function()
			local env = loadMap("BouncyCastleMaze")
			local model = env.map.build(MAZE_ORIGIN)
			t.ok(model:FindFirstChild("ExitWallLeft") ~= nil, "exit wall built")
			t.ok(model:FindFirstChild("ExitWallRight") == nil, "lane 4 side is open (zero width)")
			local boxes = wallBoxes(model, MAZE_ORIGIN)

			local steps = shortestToFinish(boxes)
			t.ok(steps ~= nil, "finish must be reachable")
			-- S자: 1번 레인 ↓ → 2번 ↑ → 3번 ↓ → 4번 → D. 출구 벽이 없으면 약 150 걸음(1번 레인 직진)
			t.ok((steps :: number) >= 300, `shortest path {steps} must be the S-path`)

			-- 4번 레인(x ≥ 10)을 막으면 결승에 못 가요
			local withoutLane4 = shortestToFinish(boxes, function(x: number, _z: number)
				return x >= MazeLayout.EXIT_GATE.openXMin
			end)
			t.eq(withoutLane4, nil, "only lane 4 reaches the exit corridor")

			-- 1번 레인 한가운데 줄(x -15)은 미로 끝에서 출구 벽에 막혀요
			t.ok(blockedByBoxes(boxes, -15, MazeLayout.MAZE.back), "lane 1 end blocked")
			t.ok(not blockedByBoxes(boxes, 15, MazeLayout.MAZE.back), "lane 4 end open")
			-- 출구 벽 높이는 다른 벽과 같아요 (바운스 정점으로 못 넘게)
			local exitWall = model:FindFirstChild("ExitWallLeft")
			t.eq(exitWall.Size.Y, MazeLayout.WALL_HEIGHT)
		end
	)

	t.test(
		"m5-14 재QA B1: 순수 blockedAt 격자와 build 벽 격자가 미로·출구 구간에서 같은 칸을 막아요",
		function()
			local Logic = RobloxRequire.require(Shared.maps.BouncyCastleMazeLogic)
			local env = loadMap("BouncyCastleMaze")
			local boxes = wallBoxes(env.map.build(MAZE_ORIGIN), MAZE_ORIGIN)
			local mismatches = {}
			-- 벽 가장자리(경계값 포함 여부만 다른 폭 0 선)를 피하려고 0.25 어긋난 점에서 비교해요
			for zi = MazeLayout.ANTEROOM.front - 1, MazeLayout.EXIT.back + 1, -1 do
				for xi = -MazeLayout.HALF_WIDTH + 1, MazeLayout.HALF_WIDTH - 1 do
					local x, z = xi + 0.25, zi - 0.25
					local pure = Logic.blockedAt(
						x,
						z,
						MazeLayout.PARTITIONS,
						MazeLayout.GATE,
						MazeLayout.BOUNDS,
						MazeLayout.EXIT_GATE
					)
					if pure ~= blockedByBoxes(boxes, x, z) then
						table.insert(mismatches, `{x},{z}`)
					end
				end
			end
			t.eq(#mismatches, 0, `mismatch at {table.concat(mismatches, " ")}`)
		end
	)

	---------------------------------------------------------------- m5-14 B2·B3·B5
	t.test("m5-14 재QA B2: 튕길 때 걷던 수평 속도는 그대로, 세로축만 55로 묶어요", function()
		local run = startMaze()
		local walk = MAZE_ORIGIN:VectorToWorldSpace(RV3.new(6, 0, -14))
		local player, root = newRacer(mazePoint(-15, 3, -50), walk)
		table.insert(run.racers, player)
		run.env.setClock(1)
		run.env.heartbeat:Fire(1 / 60)
		local v = root.AssemblyLinearVelocity
		t.ok(math.abs(v.X - walk.X) < 1e-6 and math.abs(v.Z - walk.Z) < 1e-6, `horizontal kept: {v}`)
		t.ok(math.abs(v.Y - MazeLayout.BOUNCE_UP_SPEED) < 1e-6, `up speed {v.Y}`)
		local push = root:FindFirstChild("BounceLaunch")
		t.ok(push ~= nil, "LinearVelocity on root")
		t.eq(push.VelocityConstraintMode, "VelocityConstraintMode.Line")
		t.eq(push.LineDirection, RV3.yAxis)
		t.eq(push.LineVelocity, MazeLayout.BOUNCE_UP_SPEED)
		t.eq(push.Enabled, true)
		t.eq(push.Attachment0, root:FindFirstChild("RootAttachment"))
		t.eq(run.env.exemptCount(), 1)

		-- 유지 시간 안에는 켜져 있고, 끝나면 꺼져요
		root.Position = mazePoint(-15, 10, -50)
		run.env.setClock(1 + MazeLayout.BOUNCE_HOLD / 2)
		run.env.heartbeat:Fire(1 / 60)
		t.eq(push.Enabled, true, "held")
		run.env.setClock(1 + MazeLayout.BOUNCE_HOLD + 0.001)
		run.env.heartbeat:Fire(1 / 60)
		t.eq(push.Enabled, false, "released after hold")
	end)

	t.test(
		"m5-14 재QA B3: 300번 튕겨도 루트마다 LinearVelocity 1개, ctx.cleanup 항목이 늘지 않아요",
		function()
			local run = startMaze()
			local player, root = newRacer(mazePoint(-15, 3, -50), RV3.zero)
			table.insert(run.racers, player)
			local clock = 1
			run.env.setClock(clock)
			run.env.heartbeat:Fire(1 / 60)
			local baseline = #run.cleanup.items
			local push = root:FindFirstChild("BounceLaunch")
			for _ = 1, 300 do
				clock += MazeLayout.BOUNCE_COOLDOWN + 0.01
				root.Position = mazePoint(-15, 3, -50)
				run.env.setClock(clock)
				run.env.heartbeat:Fire(1 / 60)
				t.eq(push.Enabled, true)
				clock += MazeLayout.BOUNCE_HOLD + 0.01
				root.Position = mazePoint(-15, 10, -50)
				run.env.setClock(clock)
				run.env.heartbeat:Fire(1 / 60)
				t.eq(push.Enabled, false)
			end
			t.eq(run.env.exemptCount(), 301, "every bounce exempts")
			t.eq(#run.cleanup.items, baseline, "cleanup does not grow per bounce")
			t.eq(countClass(root, "LinearVelocity"), 1)
			t.eq(root:FindFirstChild("BounceLaunch"), push, "same instance reused")

			-- 리스폰(새 루트)이면 새 LinearVelocity 하나만 더해져요
			local player2, root2 = newRacer(mazePoint(-15, 3, -50), RV3.zero)
			run.racers[1] = player2
			clock += 1
			run.env.setClock(clock)
			run.env.heartbeat:Fire(1 / 60)
			t.eq(#run.cleanup.items, baseline + 1)
			t.eq(countClass(root2, "LinearVelocity"), 1)
		end
	)

	t.test(
		"m5-14 재QA B3: 유지 중에 통과하거나 라운드가 끝나도 다음 프레임에 꺼져요",
		function()
			-- 통과(레이서 목록에서 빠짐)
			local run = startMaze()
			local player, root = newRacer(mazePoint(15, 3, -105), RV3.zero)
			table.insert(run.racers, player)
			run.env.setClock(1)
			run.env.heartbeat:Fire(1 / 60)
			local push = root:FindFirstChild("BounceLaunch")
			t.eq(push.Enabled, true)
			table.remove(run.racers, 1)
			run.env.setClock(1 + MazeLayout.BOUNCE_HOLD + 0.001)
			run.env.heartbeat:Fire(1 / 60)
			t.eq(push.Enabled, false, "released after leaving racers")

			-- 라운드 끝 (isActive false)
			local run2 = startMaze()
			local player2, root2 = newRacer(mazePoint(-15, 3, -50), RV3.zero)
			table.insert(run2.racers, player2)
			run2.env.setClock(1)
			run2.env.heartbeat:Fire(1 / 60)
			local push2 = root2:FindFirstChild("BounceLaunch")
			run2.active.value = false
			run2.env.setClock(1 + MazeLayout.BOUNCE_HOLD + 0.001)
			run2.env.heartbeat:Fire(1 / 60)
			t.eq(push2.Enabled, false, "released after round end")
			-- 라운드가 끝난 뒤에는 새로 튕기지 않아요
			run2.env.setClock(5)
			run2.env.heartbeat:Fire(1 / 60)
			t.eq(push2.Enabled, false)
			t.eq(run2.env.exemptCount(), 1)
		end
	)

	t.test(
		"m5-14 재QA B5: 서 있는 높이(3)·조금 뜬 높이(4)에서는 걸리고, 공중(8)에서는 안 걸려요",
		function()
			for _, case in { { y = 3, hit = true }, { y = 4, hit = true }, { y = 8, hit = false } } do
				local run = startMaze()
				local player, root = newRacer(mazePoint(-15, case.y, -50), RV3.zero)
				table.insert(run.racers, player)
				run.env.setClock(1)
				run.env.heartbeat:Fire(1 / 60)
				t.eq(root:FindFirstChild("BounceLaunch") ~= nil, case.hit, `y {case.y}`)
			end
			-- 출구 통로(D, 일반 바닥)에서는 안 튕겨요
			local run = startMaze()
			local player, root = newRacer(mazePoint(15, 3, -115), RV3.zero)
			table.insert(run.racers, player)
			run.env.setClock(1)
			run.env.heartbeat:Fire(1 / 60)
			t.eq(root:FindFirstChild("BounceLaunch"), nil, "no bounce on exit floor")
		end
	)

	---------------------------------------------------------------- m5-15 B1·B2
	t.test(
		"m5-15 재QA B1: 돌린 origin에서 서버가 다리 판의 낮은 가장자리 쪽으로 밀어요 (다리 4개, 여러 시점)",
		function()
			for _, bridge in BridgeLayout.BRIDGES do
				local pushes = 0
				local sides = {}
				for step = 1, 24 do
					local run = startBridge()
					local player, root = newRacer(bridgePoint(0, 3, centerOf(bridge)), RV3.zero)
					table.insert(run.racers, player)
					run.env.setClock(step * BridgeLayout.SWAY_PERIOD / 24)
					run.env.heartbeat:Fire(1 / 30)
					local plank = run.planks[bridge.index].CFrame
					local plusEdge = plank:PointToWorldSpace(RV3.new(bridge.halfWidth, 0, 0))
					local minusEdge = plank:PointToWorldSpace(RV3.new(-bridge.halfWidth, 0, 0))
					local dv = root.AssemblyLinearVelocity
					if dv.Magnitude > 1e-6 then
						pushes += 1
						local low, high = plusEdge, minusEdge
						if minusEdge.Y < plusEdge.Y then
							low, high = minusEdge, plusEdge
						end
						t.ok(dv:Dot(low - high) > 0, `bridge {bridge.index} step {step}: push toward low edge`)
						t.ok(math.abs(dv.Y) < 1e-6, "push is horizontal")
						sides[if low == plusEdge then "+" else "-"] = true
					end
				end
				t.ok(pushes >= 12, `bridge {bridge.index} pushed {pushes} times`)
				t.ok(sides["+"] and sides["-"], `bridge {bridge.index} pushed both ways`)
			end
		end
	)

	t.test(
		"m5-15 재QA B2: 떨어지는 중·판 밖 사람은 안 밀고, 다리 흔들림 인원에도 안 들어가요",
		function()
			local bridge = BridgeLayout.BRIDGES[3]
			local z = centerOf(bridge)
			local clock = BridgeLayout.SWAY_PERIOD / 4 + 0.05
			local function plankAfter(positions: { any }): (any, { any })
				local run = startBridge()
				local roots = {}
				for _, position in positions do
					local player, root = newRacer(position, RV3.zero)
					table.insert(run.racers, player)
					table.insert(roots, root)
				end
				run.env.setClock(clock)
				run.env.heartbeat:Fire(1 / 30)
				return run.planks[bridge.index].CFrame, roots
			end
			local empty = plankAfter({})
			local falling, fallingRoots = plankAfter({
				bridgePoint(0, BridgeLogic.RIDER_MIN_Y - 2, z),
				bridgePoint(0, -10, z),
				bridgePoint(bridge.halfWidth + BridgeLogic.RIDER_EDGE_MARGIN + 1, 3, z),
			})
			local riding = plankAfter({ bridgePoint(0, 3, z), bridgePoint(1, 3, z), bridgePoint(-1, 3, z) })
			local function rollOf(cf: any): number
				local r = cf.RightVector
				return math.asin(math.clamp(BRIDGE_ORIGIN.UpVector:Dot(r), -1, 1))
			end
			t.ok(math.abs(rollOf(falling) - rollOf(empty)) < 1e-9, "fallers/off-plank do not add sway")
			t.ok(math.abs(rollOf(riding)) > math.abs(rollOf(empty)) + 1e-4, "riders do add sway (test is meaningful)")
			for i, root in fallingRoots do
				t.eq(root.AssemblyLinearVelocity.Magnitude, 0, `faller/off-plank {i} not pushed`)
			end
		end
	)

	---------------------------------------------------------------- m5-16 B1·B3
	t.test(
		"m5-16 재QA B1: build의 Block<n> 이름·높이와 start의 blocks[n]이 같은 번호를 쓰고, 위에서부터 숨겨요",
		function()
			local source = fs.readFile("src/shared/maps/GiantJenga.luau")
			t.ok(string.find(source, "Name = `Block{level}`", 1, true) ~= nil, "build names Block<level>")
			t.ok(string.find(source, "local centerY = Logic.blockCenterY(level)", 1, true) ~= nil)
			t.ok(string.find(source, "blocksFolder:FindFirstChild(`Block{level}`)", 1, true) ~= nil)
			t.ok(string.find(source, "blocks[level] = block", 1, true) ~= nil, "start indexes by the same number")
			-- 3단을 차례로 뽑으면 Block1 → Block2 → Block3 순서, 남은 블록 윗면은 늘 그 칸 윗면 이하
			local hidden: { [number]: boolean } = {}
			local board = JengaLogic.newBoard()
			local key = JengaLayout.key(2, 0)
			for newLevel = JengaLayout.LEVEL_MAX - 1, 0, -1 do
				board.levels[key] = newLevel
				local index = JengaLogic.poppedBlockIndex(newLevel)
				t.ok(
					index >= 1 and index <= JengaLayout.LEVEL_MAX and not hidden[index],
					`level {newLevel} pops {index}`
				)
				hidden[index] = true
				if newLevel > 0 then
					local surface = JengaLogic.heightOf(board, 2, 0)
					for n = 1, JengaLayout.LEVEL_MAX do
						if not hidden[n] then
							local top = JengaLogic.blockCenterY(n) + JengaLayout.LEVEL_DROP / 2
							t.ok(top <= surface + 1e-9, `level {newLevel}: Block{n} top {top} above surface {surface}`)
						end
					end
				end
			end
			t.eq(hidden[1] and hidden[2] and hidden[3], true)
		end
	)

	t.test(
		"m5-16 재QA B3: 무작위 보드 500개에서 테두리 칸 바깥쪽 기울기 ≤ 3도, 안쪽 칸은 상한의 영향이 없어요",
		function()
			math.randomseed(1613)
			local g = JengaLayout.GRID_HALF
			local cap = math.rad(JengaLogic.DEG_PER_UNIT * JengaLogic.EDGE_OUTWARD_MAX_UNITS) + 1e-9
			local sawEdgeTilt = false
			for _ = 1, 500 do
				local board = JengaLogic.newBoard()
				for k in board.levels do
					board.levels[k] = math.random(0, JengaLayout.LEVEL_MAX)
				end
				for _, column in JengaLayout.columns() do
					local i, j = column.i, column.j
					local tilt = JengaLogic.tiltFor(board, i, j)
					if tilt and (math.abs(i) == g or math.abs(j) == g) then
						sawEdgeTilt = true
						if i == g or i == -g then
							local outward = tilt.downX * (if i > 0 then 1 else -1)
							t.ok(tilt.angle * outward <= cap, `({i},{j}) x outward {math.deg(tilt.angle * outward)}`)
						end
						if j == g or j == -g then
							local outward = tilt.downZ * (if j > 0 then 1 else -1)
							t.ok(tilt.angle * outward <= cap, `({i},{j}) z outward {math.deg(tilt.angle * outward)}`)
						end
					end
				end
			end
			t.ok(sawEdgeTilt, "random boards produced edge tilts")
		end
	)
end
