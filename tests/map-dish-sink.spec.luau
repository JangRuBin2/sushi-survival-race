--!strict
-- m5-34 "깨끗하게! 설거지통"(dish-sink): 코스 치수 약속, 낙하선, 접시 길 찾기, 접시 밀기 방향·크기, 수세미 주기·맞음,
-- 길이 추정, 장식 예산·시야 상자·배경 바닥, 그리고 서버 start를 가짜 Heartbeat로 돌려 보는 확인.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local Layout = RobloxRequire.require(Shared.maps.DishSinkLayout)
local Logic = RobloxRequire.require(Shared.maps.DishSinkLogic)
local Art = RobloxRequire.require(Shared.maps.DishSinkArt)
local DishSink = RobloxRequire.require(Shared.maps.DishSink)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local EPS = 1e-6
local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

-- ── 길 찾기 그래프 ────────────────────────────────────────────────────
type Node = { name: string, kind: string, top: number, x: number?, z: number?, r: number?, rect: any? }

local function gapBetween(a: Node, b: Node): number
	if a.kind == "circle" and b.kind == "circle" then
		return Logic.circleGap(a.x :: number, a.z :: number, a.r :: number, b.x :: number, b.z :: number, b.r :: number)
	elseif a.kind == "circle" then
		return Logic.circleRectGap(a.x :: number, a.z :: number, a.r :: number, b.rect)
	elseif b.kind == "circle" then
		return Logic.circleRectGap(b.x :: number, b.z :: number, b.r :: number, a.rect)
	end
	-- 직사각형끼리 (여기서는 안 써요)
	local dx = math.max(a.rect.minX - b.rect.maxX, b.rect.minX - a.rect.maxX, 0)
	local dz = math.max(a.rect.minZ - b.rect.maxZ, b.rect.minZ - a.rect.maxZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function reachable(nodes: { Node }, from: string, to: string, maxGap: number, maxRise: number): boolean
	local byName: { [string]: Node } = {}
	for _, n in nodes do
		byName[n.name] = n
	end
	local seen: { [string]: boolean } = { [from] = true }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local cur = byName[queue[head]]
		head += 1
		if cur.name == to then
			return true
		end
		for _, nxt in nodes do
			if not seen[nxt.name] and gapBetween(cur, nxt) <= maxGap + EPS and nxt.top - cur.top <= maxRise + EPS then
				seen[nxt.name] = true
				table.insert(queue, nxt.name)
			end
		end
	end
	return false
end

local function rectNode(name: string): Node
	for _, rect in Layout.floorRects() do
		if rect.name == name then
			return { name = name, kind = "rect", top = rect.top, rect = rect }
		end
	end
	error(`no rect {name}`)
end

local function plateNode(plate: any): Node
	return {
		name = `plate{plate.index}`,
		kind = "circle",
		top = plate.top,
		x = plate.x,
		z = plate.z,
		r = plate.kind.radius,
	}
end

local function cupNode(cup: any): Node
	return { name = `cup{cup.index}`, kind = "circle", top = cup.top, x = cup.x, z = cup.z, r = cup.radius }
end

local function bPlates(): { any }
	local list = {}
	for _, plate in Layout.PLATES do
		if plate.kind == Layout.SMALL_PLATE then
			table.insert(list, plate)
		end
	end
	return list
end

local function bigPlates(): { any }
	local list = {}
	for _, plate in Layout.PLATES do
		if plate.kind == Layout.BIG_PLATE then
			table.insert(list, plate)
		end
	end
	return list
end

-- ── start 하네스 (가짜 Heartbeat·시계·서비스, 진짜 CFrame·Vector3·Instance) ─────────────────
type Harness = {
	map: any,
	fire: (dt: number) -> (),
	setClock: (t: number) -> (),
	marks: { { character: any, seconds: number? } },
	sounds: { string },
	delays: { number },
	bulk: number,
}

local function newHarness(model: any): Harness
	local handlers: { any } = {}
	local clock = 0
	local h: Harness = {
		map = nil,
		fire = function(dt: number)
			for _, fn in table.clone(handlers) do
				fn(dt)
			end
		end,
		setClock = function(t: number)
			clock = t
		end,
		marks = {},
		sounds = {},
		delays = {},
		bulk = 0,
	}
	local heartbeat = {
		Connect = function(_, fn: any)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
	}
	local collection = {
		GetTagged = function(_, tag: string)
			local list = {}
			for _, d in model:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(list, d)
				end
			end
			return list
		end,
	}
	local modules: { [string]: any } = {
		DishSinkArt = Art,
		DishSinkLayout = Layout,
		DishSinkLogic = Logic,
		MapTypes = MapTypes,
		Config = Config,
		MapKit = {},
		MapSfx = {
			play = function(_part: any, cue: string)
				table.insert(h.sounds, cue)
			end,
		},
		MoveExempt = {
			mark = function(character: any, seconds: number?)
				table.insert(h.marks, { character = character, seconds = seconds })
			end,
		},
	}
	local parentParent = setmetatable({}, {
		__index = function(_, name: string)
			return { __module = name }
		end,
	})
	local parent = setmetatable({ Parent = parentParent }, {
		__index = function(_, name: string)
			return { __module = name }
		end,
	})
	local fakeInstance = {
		new = function(className: string)
			local inst: any = { ClassName = className }
			function inst:Destroy() end
			return inst
		end,
	}
	h.map = luau.load(fs.readFile("src/shared/maps/DishSink.luau"), {
		debugName = "DishSink",
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local m = modules[target.__module]
				assert(m ~= nil, `unexpected require {tostring(target.__module)}`)
				return m
			end,
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
			workspace = {
				BulkMoveTo = function(_, parts: { any }, frames: { any })
					h.bulk += 1
					for i, p in parts do
						p.CFrame = frames[i]
					end
				end,
			},
			task = {
				delay = function(seconds: number, _fn: any)
					table.insert(h.delays, seconds)
					return {}
				end,
			},
			os = {
				clock = function()
					return clock
				end,
			},
			CFrame = RCF,
			Vector3 = RV3,
			Enum = roblox.Enum,
			Instance = fakeInstance,
			table = table,
			math = math,
			string = string,
			type = type,
			tostring = tostring,
			tonumber = tonumber,
			assert = assert,
			error = error,
		},
	})()
	return h
end

local function fakeRacer(origin: any, x: number, y: number, z: number): any
	local root: any = {
		Position = origin:PointToWorldSpace(RV3.new(x, y, z)),
		AssemblyLinearVelocity = RV3.new(0, 0, 0),
		IsA = function(_, cls: string)
			return cls == "BasePart"
		end,
		FindFirstChild = function(_, name: string)
			if name == "RootAttachment" then
				return { Name = "RootAttachment" }
			end
			return nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	local humanoid: any = { PlatformStand = false }
	local character: any = {}
	character.FindFirstChild = function(_, name: string)
		if name == "HumanoidRootPart" then
			return root
		end
		return nil
	end
	character.FindFirstChildOfClass = function(_, cls: string)
		if cls == "Humanoid" then
			return humanoid
		end
		return nil
	end
	humanoid.Parent = character
	return { Name = "Racer", Character = character, root = root, humanoid = humanoid }
end

-- 진짜 인스턴스로 수세미 모델 하나 (몸통 + 수세미 면) — 서버가 묶어서 옮기는지 봐요
local function spongeModel(origin: any): any
	local model = roblox.Instance.new("Model")
	local folder = roblox.Instance.new("Folder")
	folder.Name = "Sponges"
	folder.Parent = model
	for _, sponge in Layout.SPONGES do
		local holder = roblox.Instance.new("Model")
		holder.Name = `Sponge{sponge.index}`
		holder.Parent = folder
		local center = origin * RCF.new(Logic.spongeX(sponge.index, 0), sponge.floorY + sponge.sizeY / 2, sponge.z)
		local body = roblox.Instance.new("Part")
		body.Name = Art.SPONGE_BODY
		body.CFrame = center
		body:SetAttribute("SpongeIndex", sponge.index)
		body:AddTag("SinkSponge")
		body.Parent = holder
		local top = roblox.Instance.new("Part")
		top.Name = "SpongeScrub"
		top.CFrame = center * RCF.new(0, 2, 0)
		top.Parent = holder
	end
	return model
end

local function newCtx(model: any, origin: any, racers: { any }): any
	local cleanup = { items = {} :: { any } }
	function cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	local ctx: any = {
		model = model,
		origin = origin,
		cleanup = cleanup,
		passed = {},
		eliminated = {},
		active = true,
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		local list = {}
		for _, r in racers do
			if not ctx.passed[r] and not ctx.eliminated[r] then
				table.insert(list, r)
			end
		end
		return list
	end
	ctx.pass = function(p: any)
		ctx.passed[p] = true
	end
	ctx.eliminate = function(p: any)
		ctx.eliminated[p] = true
	end
	return ctx
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: 풀에 든 Race 맵, 이름·규칙이 GDD 그대로, inPool 줄이 지워졌고 조명은 Art.LIGHTING",
		function()
			t.eq(MapTypes.validate(DishSink), nil)
			t.eq(Maps.get("dish-sink"), DishSink)
			t.eq(DishSink.kind, "Race")
			t.eq(DishSink.displayName, "깨끗하게! 설거지통")
			t.eq(
				DishSink.rule,
				"빙글빙글 접시와 움직이는 수세미를 피해 깨끗한 접시까지 달려요!"
			)
			t.ok(DishSink.inPool == nil or DishSink.inPool == true, "inPool")
			t.eq(DishSink.timeLimit, nil)
			t.eq(Maps.timeLimit(DishSink), Config.TimeLimit.Race)
			t.eq(DishSink.lighting, Art.LIGHTING)
			t.eq(MapLighting.validate(Art.LIGHTING), nil)
			local found = false
			for _, info in Maps.infos() do
				if info.id == "dish-sink" then
					found = true
				end
			end
			t.ok(found, "dish-sink is in the random pool")
			local source = fs.readFile("src/shared/maps/DishSink.luau")
			t.eq(string.find(source, "inPool", 1, true), nil, "inPool line should be removed")
			t.eq(string.find(source, "m5-33 껍데기", 1, true), nil, "shell marker removed")
		end
	)

	t.test("AC1: 스폰 24개가 A 출발 바닥 안에서 서로 3 studs 이상 떨어져 있어요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, 24)
		t.eq(#spawns, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		for i, a in spawns do
			t.ok(math.abs(a.x) + 1 <= Layout.START_WIDTH / 2, `spawn {i} x {a.x}`)
			t.ok(a.z - 1 >= Layout.START.back and a.z + 1 <= Layout.START.front, `spawn {i} z {a.z}`)
			for j = i + 1, #spawns do
				local b = spawns[j]
				t.ok(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 3 - EPS, `spawns {i},{j}`)
			end
		end
	end)

	t.test(
		"AC1: build(진짜 인스턴스) — 스폰은 출발 바닥 위, 접시 10개 태그, 수세미는 충돌·쿼리·터치 없음",
		function()
			local model = RMaps.get("dish-sink").build(RCF.new(0, 300, 2000))
			local origin = RCF.new(0, 300, 2000)
			local spawns = model:FindFirstChild("Spawns")
			t.eq(#spawns:GetChildren(), 24)
			local counter = model:FindFirstChild("StartCounter")
			t.ok(counter ~= nil and counter.CanCollide, "start counter")
			for _, s in spawns:GetChildren() do
				local rel = counter.CFrame:PointToObjectSpace(s.CFrame.Position)
				t.ok(
					math.abs(rel.X) <= counter.Size.X / 2 and math.abs(rel.Z) <= counter.Size.Z / 2,
					`{s.Name} on start`
				)
			end
			local plates, sponges = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("SinkPlate") then
					plates += 1
					t.ok(d.CanCollide and d.Anchored, `{d.Name} collides`)
					local index = d:GetAttribute("PlateIndex")
					local plate = Layout.PLATES[index]
					local rel = origin:PointToObjectSpace(d.CFrame.Position)
					t.ok(near(rel.X, plate.x, 1e-3) and near(rel.Z, plate.z, 1e-3), `{d.Name} position`)
					t.ok(near(rel.Y + Layout.PLATE_THICKNESS / 2, plate.top, 1e-3), `{d.Name} top`)
					t.eq(d:GetAttribute("PlateDirection"), plate.dir)
				end
				if d:IsA("BasePart") and d:HasTag("SinkSponge") then
					sponges += 1
				end
			end
			t.eq(plates, 10)
			t.eq(sponges, #Layout.SPONGES)
			local folder = model:FindFirstChild("Sponges")
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, `{d.Name} must not collide`)
					t.ok(
						d:GetAttribute("DecorAnimKind") == nil
							and #d:GetTags() == (if d:HasTag("SinkSponge") then 1 else 0),
						`{d.Name} no anim tag`
					)
				end
			end
			local finish = model:FindFirstChild("FinishLine")
			t.ok(near(origin:PointToObjectSpace(finish.CFrame.Position).Z, -436, 1e-3), "finish line z")
		end
	)

	---------------------------------------------------------------- AC2
	t.test(
		"AC2: 구간 7개가 스펙 표 z 범위 그대로 이어지고 진행도가 단조 증가, 결승선 z -436",
		function()
			local expected = {
				{ 0, -16 },
				{ -16, -111 },
				{ -111, -195 },
				{ -195, -255 },
				{ -255, -335 },
				{ -335, -395 },
				{ -395, -445 },
			}
			local sections = Layout.sections()
			t.eq(#sections, 7)
			for i, span in sections do
				t.eq(span.front, expected[i][1], `section {i} front`)
				t.eq(span.back, expected[i][2], `section {i} back`)
				t.eq(Logic.sectionAt((span.front + span.back) / 2), Layout.SECTION_NAMES[i])
			end
			local previous = -math.huge
			for z = 0, -445, -0.5 do
				local p = Logic.progress(z)
				t.ok(p > previous, `progress at {z}`)
				previous = p
			end
			t.eq(Layout.FINISH_LINE_Z, -436)
			t.eq(Logic.finishProgress(), 436)
			-- 출발 앞줄에서 약 433
			local frontRow = Layout.spawnPositions()[1].z
			t.ok(near(frontRow - Layout.FINISH_LINE_Z, 433, 1), `front row to finish {frontRow - Layout.FINISH_LINE_Z}`)
		end
	)

	t.test("AC2: fallLineAt(z) = 그 구간 바닥 − 12 (D·G는 오르막을 따라)", function()
		local cases = {
			{ 5, -12 },
			{ -8, -12 },
			{ -60, -12 },
			{ -150, -12 },
			{ -195, -12 },
			{ -225, -10 },
			{ -255, -8 },
			{ -300, -8 },
			{ -380, -8 },
			{ -395, -8 },
			{ -405, -5 },
			{ -415, -2 },
			{ -436, -2 },
			{ -445, -2 },
		}
		for _, case in cases do
			t.ok(near(Logic.fallLineAt(case[1]), case[2], 1e-9), `z {case[1]}: {Logic.fallLineAt(case[1])}`)
		end
		-- 판정 바닥 윗면이 그 자리 바닥 높이와 같아요 (직사각형·접시)
		for _, rect in Layout.floorRects() do
			local z = (rect.minZ + rect.maxZ) / 2
			if rect.name ~= "DryingRack" then
				t.ok(near(Logic.floorAt(z), rect.top, 1e-9), `{rect.name} top`)
			end
		end
		for _, plate in Layout.PLATES do
			t.ok(near(Logic.floorAt(plate.z), plate.top, 1e-9), `plate {plate.index} top`)
		end
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: B 접시 8개 지름 20, 이웃 틈 전부 3, A→1행·4행→C 틈 3", function()
		local plates = bPlates()
		t.eq(#plates, 8)
		for _, p in plates do
			t.eq(p.kind.radius * 2, 20)
			t.eq(p.top, 0)
			t.ok(p.z < Layout.PLATES_B.front and p.z > Layout.PLATES_B.back, `plate {p.index} in B`)
		end
		local neighbours = 0
		for i, a in plates do
			for j = i + 1, #plates do
				local b = plates[j]
				if
					(a.row == b.row and math.abs(a.lane - b.lane) == 1)
					or (a.lane == b.lane and math.abs(a.row - b.row) == 1)
				then
					neighbours += 1
					local gap = Logic.circleGap(a.x, a.z, 10, b.x, b.z, 10)
					t.ok(near(gap, 3, 0.1), `plates {a.index},{b.index} gap {gap}`)
				end
			end
		end
		t.eq(neighbours, 10)
		local start = rectNode("StartCounter")
		local head = rectNode("PartitionHead")
		for _, p in plates do
			if p.row == 1 then
				t.ok(near(Logic.circleRectGap(p.x, p.z, 10, start.rect), 3, 0.1), `A → plate {p.index}`)
			elseif p.row == 4 then
				t.ok(near(Logic.circleRectGap(p.x, p.z, 10, head.rect), 3, 0.1), `plate {p.index} → C`)
			end
		end
	end)

	t.test(
		"AC3: B 접시 그래프(틈 ≤ 3.5)로 A → C 길이 있고, 왼쪽 줄만·오른쪽 줄만 길도 있어요",
		function()
			local function nodesFor(lane: number?): { Node }
				local list = { rectNode("StartCounter"), rectNode("PartitionHead") }
				for _, p in bPlates() do
					if lane == nil or p.lane == lane then
						table.insert(list, plateNode(p))
					end
				end
				return list
			end
			t.ok(reachable(nodesFor(nil), "StartCounter", "PartitionHead", 3.5, 2), "any path")
			t.ok(reachable(nodesFor(1), "StartCounter", "PartitionHead", 3.5, 2), "left lane only")
			t.ok(reachable(nodesFor(2), "StartCounter", "PartitionHead", 3.5, 2), "right lane only")
			-- 접시 없이는 못 건너요 (출발 → C 직접 틈이 커요)
			t.ok(
				not reachable(
					{ rectNode("StartCounter"), rectNode("PartitionHead") },
					"StartCounter",
					"PartitionHead",
					3.5,
					2
				)
			)
		end
	)

	t.test(
		"AC3: D 컵·E 큰 접시 그래프(틈 ≤ 4, 오름 ≤ 2)로 C 끝 → F 입구, D는 두 갈래",
		function()
			for _, cup in Layout.CUP_LIST do
				t.ok(cup.radius * 2 >= 8 and cup.radius * 2 <= 10, `cup {cup.index} diameter`)
				t.ok(
					cup.z + cup.radius <= Layout.CUPS.front and cup.z - cup.radius >= Layout.CUPS.back,
					`cup {cup.index} in D`
				)
			end
			t.eq(#Layout.CUP_LIST, 7)
			local tops = {}
			for _, cup in Layout.CUP_LIST do
				tops[cup.top] = true
			end
			t.ok(tops[0] and tops[4], "cups climb 0 → 4")
			local function nodes(skip: string?): { Node }
				local list = { rectNode("Partition"), rectNode("Bridge1"), rectNode("Bridge2"), rectNode("Corridor") }
				for _, cup in Layout.CUP_LIST do
					if cup.branch ~= skip then
						table.insert(list, cupNode(cup))
					end
				end
				for _, p in bigPlates() do
					table.insert(list, plateNode(p))
				end
				return list
			end
			t.ok(reachable(nodes(nil), "Partition", "Corridor", 4, 2), "C → F")
			t.ok(reachable(nodes("L"), "Partition", "Corridor", 4, 2), "right branch alone")
			t.ok(reachable(nodes("R"), "Partition", "Corridor", 4, 2), "left branch alone")
			t.ok(not reachable(nodes("M"), "Partition", "Corridor", 4, 2), "the middle cup joins both branches")
			-- 설계한 이음새의 틈이 2.5 ~ 4
			local byIndex = {}
			for _, cup in Layout.CUP_LIST do
				byIndex[cup.index] = cup
			end
			for _, pair in { { 1, 2 }, { 1, 3 }, { 2, 4 }, { 3, 4 }, { 4, 5 }, { 4, 6 }, { 5, 7 }, { 6, 7 } } do
				local a, b = byIndex[pair[1]], byIndex[pair[2]]
				local gap = Logic.circleGap(a.x, a.z, a.radius, b.x, b.z, b.radius)
				t.ok(gap >= 2.5 - EPS and gap <= 4 + EPS, `cups {pair[1]}-{pair[2]} gap {gap}`)
				t.ok(b.top - a.top <= 2 + EPS, `cups {pair[1]}-{pair[2]} rise`)
			end
			local first = byIndex[1]
			local gapC = Logic.circleRectGap(first.x, first.z, first.radius, rectNode("Partition").rect)
			t.ok(gapC >= 2.5 - EPS and gapC <= 4 + EPS, `C → cup 1 gap {gapC}`)
			-- E: 큰 접시 지름 26, 다리 폭 10, 다리·접시 틈 3
			local big = bigPlates()
			t.eq(#big, 2)
			for _, p in big do
				t.eq(p.kind.radius * 2, 26)
				t.eq(p.top, Layout.HIGH_Y)
				t.ok(
					p.z + 13 <= Layout.BIG_PLATES.front and p.z - 13 >= Layout.BIG_PLATES.back,
					`big plate {p.index} in E`
				)
				for _, name in { "Bridge1", "Bridge2" } do
					local gap = Logic.circleRectGap(p.x, p.z, 13, rectNode(name).rect)
					t.ok(gap >= 3 - 0.1, `big plate {p.index} vs {name} gap {gap}`)
				end
			end
			t.ok(
				near(Logic.circleRectGap(big[1].x, big[1].z, 13, rectNode("Bridge1").rect), 3, 0.1),
				"plate 1 → bridge 1"
			)
			t.ok(
				near(Logic.circleRectGap(big[2].x, big[2].z, 13, rectNode("Bridge1").rect), 3, 0.1),
				"bridge 1 → plate 2"
			)
			t.ok(
				near(Logic.circleRectGap(big[2].x, big[2].z, 13, rectNode("Bridge2").rect), 3, 0.1),
				"plate 2 → bridge 2"
			)
			t.ok(big[1].x * big[2].x < 0, "zigzag")
			for _, b in Layout.BRIDGES do
				t.eq(b.maxX - b.minX, 10)
			end
			t.eq(Layout.CORRIDOR_WIDTH, 16)
			t.eq(Layout.PARTITION_WIDTH, 12)
		end
	)

	t.test("AC3b: estimateClearTime (걷기 16 + 구간 지연)이 42 ~ 55초", function()
		local estimate = Logic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
		t.eq(Layout.WALK_SPEED, Config.Character.WalkSpeed)
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: plateDirection — 이웃 접시끼리 항상 반대, 큰 접시 둘도 반대", function()
		for row = 1, 4 do
			t.eq(Logic.plateDirection(row, 1), -Logic.plateDirection(row, 2), `row {row}`)
			if row < 4 then
				for lane = 1, 2 do
					t.eq(Logic.plateDirection(row, lane), -Logic.plateDirection(row + 1, lane), `row {row} lane {lane}`)
				end
			end
		end
		t.eq(Logic.plateDirection(1, 1), 1) -- (행 + 줄) 짝수 = 시계
		local big = bigPlates()
		t.eq(big[1].dir, -big[2].dir)
		for _, p in Layout.PLATES do
			t.eq(p.dir, Logic.plateDirection(p.row, p.lane))
		end
	end)

	t.test(
		"AC4: platePush — r 3이면 접선 ω·3, r 8이면 접선 8 + 바깥 2.5, 밖이면 nil, 방향 −1이면 반대",
		function()
			local omega = 2 * math.pi / 5
			-- r = 3 (중심 오른쪽): 시계 방향이면 +Z(화면 아래)로
			local vx, vz = Logic.platePush(3, 0, 1)
			t.ok(vx ~= nil and vz ~= nil)
			t.ok(near(vx :: number, 0, 1e-9), "no radial at r 3")
			t.ok(near(vz :: number, omega * 3, omega * 3 * 0.02), `tangent {vz}`)
			t.ok((vz :: number) > 0, "clockwise from above at the right edge goes +Z")
			-- 방향 반대
			local wx, wz = Logic.platePush(3, 0, -1)
			t.ok(near(wx :: number, 0, 1e-9) and near(wz :: number, -(vz :: number), 1e-9), "reversed")
			-- r = 8 (대각선): 접선 8(상한) + 바깥 2.5
			local dx, dz = 8 / math.sqrt(2), -8 / math.sqrt(2)
			local px, pz = Logic.platePush(dx, dz, 1)
			local ux, uz = dx / 8, dz / 8
			local radial = (px :: number) * ux + (pz :: number) * uz
			local tangential = (px :: number) * -uz + (pz :: number) * ux
			t.ok(near(radial, 2.5, 1e-9), `radial {radial}`)
			t.ok(near(tangential, 8, 1e-9), `tangential {tangential}`)
			local mag = math.sqrt((px :: number) ^ 2 + (pz :: number) ^ 2)
			t.ok(mag <= 8.5, `max push {mag} (+ walk 16 < 80)`)
			-- 밖
			local nx = Logic.platePush(10.01, 0, 1)
			t.eq(nx, nil)
			-- 가장자리 안쪽(0.7R 이하)은 바깥 밀기 없음
			local ex, ez = Logic.platePush(0, 6.9, 1)
			t.ok(
				near(ex :: number, -math.min(omega * 6.9, 8), 1e-9) and near(ez :: number, 0, 1e-9),
				"no outward at 6.9"
			)
			-- 큰 접시: ω = 2π/4, 상한 10, R 13
			local bx, bz = Logic.platePush(3, 0, 1, Layout.BIG_PLATE)
			t.ok(near(bz :: number, 2 * math.pi / 4 * 3, 1e-9) and near(bx :: number, 0, 1e-9), "big plate r 3")
			local cx, cz = Logic.platePush(12, 0, 1, Layout.BIG_PLATE)
			t.ok(near(cz :: number, 10, 1e-9) and near(cx :: number, 2.5, 1e-9), "big plate cap + edge")
			t.eq(Logic.platePush(13.01, 0, 1, Layout.BIG_PLATE), nil)
			t.eq(Layout.PUSH_ACCEL, 24)
		end
	)

	t.test("AC4: plateAt — 접시 윗면 근처(발 −1 ~ +5)·반지름 안에서만", function()
		local p1 = Layout.PLATES[1]
		local rootY = p1.top + Layout.FOOT_OFFSET
		t.eq(Logic.plateAt(p1.x, rootY, p1.z), p1)
		t.eq(Logic.plateAt(p1.x + 9.9, rootY, p1.z), p1)
		t.eq(Logic.plateAt(p1.x + 10.1, rootY, p1.z), nil)
		t.eq(Logic.plateAt(p1.x, rootY + 5.5, p1.z), nil) -- 높이 점프 중
		t.eq(Logic.plateAt(p1.x, rootY - 1.5, p1.z), nil) -- 떨어지는 중
		local big = bigPlates()[1]
		t.eq(Logic.plateAt(big.x + 12, big.top + Layout.FOOT_OFFSET, big.z), big)
	end)

	---------------------------------------------------------------- AC5
	t.test(
		"AC5: spongeX — 수세미 1은 0~1.5 +12, 4~5.5 −12, 주기 8, 2·3은 2.7·5.3초 어긋나요",
		function()
			for _, time in { 0, 0.7, 1.49, 8, 9.2, 80.1 } do
				t.ok(near(Logic.spongeX(1, time), 12, 1e-9), `t {time}`)
			end
			for _, time in { 4, 4.8, 5.49, 12.3 } do
				t.ok(near(Logic.spongeX(1, time), -12, 1e-9), `t {time}`)
			end
			t.ok(near(Logic.spongeX(1, 2.75), 0, 1e-9), "middle at 2.75")
			for step = 0, 400 do
				local time = step * 0.04
				t.ok(near(Logic.spongeX(1, time + 8), Logic.spongeX(1, time), 1e-9), `period at {time}`)
				t.ok(near(Logic.spongeX(2, time + 2.7), Logic.spongeX(1, time), 1e-9), `sponge 2 at {time}`)
				t.ok(near(Logic.spongeX(3, time + 5.3), Logic.spongeX(1, time), 1e-9), `sponge 3 at {time}`)
			end
			t.eq(Layout.SPONGE_PERIOD, 8)
			t.eq(Layout.SPONGE_HOLD, 1.5)
		end
	)

	t.test(
		"AC5: C 수세미는 한 주기에 선반이 완전히 비는 시간(|x| ≥ 10.5)이 3초 이상, 멈춰 있으면 항상 양 끝",
		function()
			for _, sponge in Layout.SPONGES do
				local clear = 0
				local dt = 0.005
				for step = 0, math.floor(8 / dt) - 1 do
					local time = step * dt
					local x = Logic.spongeX(sponge.index, time)
					if sponge.section == "C" and math.abs(x) >= 10.5 then
						clear += dt
					end
					local vel = Logic.spongeVelocity(sponge.index, time)
					if vel == 0 then
						t.ok(
							near(math.abs(x), sponge.amplitude, 1e-9),
							`sponge {sponge.index} stopped mid-way at {time}`
						)
					end
					-- 속도가 위치의 변화와 맞아요 (수치 미분)
					local h = 1e-4
					local numeric = (Logic.spongeX(sponge.index, time + h) - Logic.spongeX(sponge.index, time - h))
						/ (2 * h)
					t.ok(near(numeric, vel, 0.05), `sponge {sponge.index} velocity at {time}: {vel} vs {numeric}`)
				end
				if sponge.section == "C" then
					t.ok(clear >= 3 - 0.01, `sponge {sponge.index} clear {clear}`)
					t.eq(sponge.amplitude, 12)
				end
			end
			t.eq(Layout.SPONGES[4].amplitude, 11)
			t.eq(Layout.SPONGES[5].amplitude, 14)
			t.eq(Layout.SPONGES[6].offset - Layout.SPONGES[5].offset, 4)
		end
	)

	t.test(
		"AC5 길 약속: C·E·F 수세미마다 어느 시각이든 6초 안에 그 자리 길이 완전히 비어요",
		function()
			for _, sponge in Layout.SPONGES do
				local half = Logic.pathHalfWidth(sponge)
				t.ok(sponge.amplitude - sponge.sizeX / 2 >= half, `sponge {sponge.index} clears its path at the ends`)
				for step = 0, 160 do
					local start = step * 0.05
					local ok = false
					local s = 0
					while s <= 6 do
						if Logic.spongeClear(sponge.index, start + s, half) then
							ok = true
							break
						end
						s += 0.02
					end
					t.ok(ok, `sponge {sponge.index} blocks for 6s from {start}`)
				end
			end
			-- F: 두 수세미가 서로 반대 끝 (한쪽이 끝에 멈출 때 다른 쪽은 반대 끝 또는 가운데)
			for _, time in { 0, 1, 4, 5 } do
				t.ok(near(Logic.spongeX(5, time), -Logic.spongeX(6, time), 1e-9), `F sponges opposite at {time}`)
			end
		end
	)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: spongeHit — 상자(x ± 1.5, z ± 1 늘림) 안·발 < 6이면 맞음, 그 밖은 아님 + 넉백 상수",
		function()
			t.eq(Logic.spongeHit(0, 0, 0), true)
			t.eq(Logic.spongeHit(5.9, 4.4, 0.5), true) -- 9/2 + 1.5 = 6, 7/2 + 1 = 4.5
			t.eq(Logic.spongeHit(6.1, 0, 0), false)
			t.eq(Logic.spongeHit(0, 4.6, 0), false)
			t.eq(Logic.spongeHit(0, 0, 5.9), true)
			t.eq(Logic.spongeHit(0, 0, 6), false)
			t.eq(Logic.spongeHit(6.9, 0, 0, 11, 7), true) -- 큰 수세미 11/2 + 1.5 = 7
			t.eq(Logic.spongeHit(7.1, 0, 0, 11, 7), false)
			t.eq(Layout.SPONGE_KNOCK_SIDE, 30)
			t.eq(Layout.SPONGE_KNOCK_UP, 14)
			t.eq(Layout.SPONGE_EXEMPT, 1.2)
			t.eq(Layout.SPONGE_COOLDOWN, 0.6)
			t.eq(Layout.SPONGE_KNOCKDOWN, 0.8)
			t.eq(Layout.SPONGE_KNOCK_HOLD, 0.12)
			-- 넉백 방향: 움직이면 그 방향, 멈춰 있으면 중심에서 먼 쪽
			t.eq(Logic.knockDirection(-9, 3), -1)
			t.eq(Logic.knockDirection(9, -3), 1)
			t.eq(Logic.knockDirection(0, -2), -1)
			t.eq(Logic.knockDirection(0, 2), 1)
			for _, s in Layout.SPONGES do
				t.eq(s.sizeY, 6)
				t.eq(s.sizeZ, 7)
				t.eq(s.sizeX, if s.section == "F" then 11 else 9)
			end
		end
	)

	---------------------------------------------------------------- AC7
	t.test(
		"AC7: 장식 validate·Extended 예산(수세미 거품 파티클 포함)·시야 상자·배경 바닥·수세미 anim 없음",
		function()
			local decor = Art.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(Art.BUDGET, "Extended")
			local spongeParticles = #Layout.SPONGES -- DishSink.build가 수세미마다 SoapFoam 하나 (Emit 전용)
			t.eq(MapKitLogic.checkBudget(decor, "Extended", { particles = spongeParticles }), nil)
			local count = MapKitLogic.count(decor)
			t.ok(count >= 700 and count <= 1500, `decor {count}`)
			t.ok(MapKitLogic.countShadowedLights(decor) <= 2, "shadowed")
			t.ok(MapKitLogic.countParticles(decor) >= 2, "particles")
			t.ok(MapKitLogic.countAnimated(decor) >= 3, "anim")
			for _, spec in decor do
				if spec.light and spec.light.kind == "Surface" then
					t.ok(spec.light.range <= 16, `{spec.name} surface range`)
				end
			end
			-- 코스 시야 상자에 장식 없음
			for i, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: any
				for j, volume in Art.courseVolume() do
					local overlap = b.min.x < volume.max.x
						and b.max.x > volume.min.x
						and b.min.y < volume.max.y
						and b.max.y > volume.min.y
						and b.min.z < volume.max.z
						and b.max.z > volume.min.z
					t.ok(not overlap, `decor #{i} {spec.name} overlaps course volume #{j}`)
				end
			end
			-- 배경 바닥(개수대 바닥)이 코스 어디서든 낙하선보다 10 이상 아래
			for z = 30, -462, -1 do
				t.ok(Art.SINK_FLOOR_Y <= Logic.fallLineAt(z) - 10, `sink floor vs fall line at {z}`)
			end
			t.ok(Art.KITCHEN_FLOOR_Y <= Art.SINK_FLOOR_Y, "kitchen floor below")
			-- 수세미 장식: validate, anim·조명·파티클 없음
			for _, sponge in Layout.SPONGES do
				local specs = Art.spongeSpecs(sponge)
				t.eq(MapKitLogic.validate(specs), nil)
				t.eq(specs[1].name, Art.SPONGE_BODY)
				for _, s in specs do
					t.eq(s.anim, nil, `sponge part {s.name} anim`)
					t.eq(s.light, nil)
					t.eq(s.particle, nil)
				end
				local b = MapKitLogic.bounds(specs) :: any
				t.ok(
					b.max.x - b.min.x <= sponge.sizeX + 1.2 and b.max.z - b.min.z <= sponge.sizeZ + 1.2,
					"sponge art ≈ hit box"
				)
			end
			-- 접시 회전 무늬는 판정 접시 밑(윗면보다 낮게)에만, Spin 주기 5(B)·4(E)
			local spins = 0
			for _, spec in decor do
				if spec.name == "PlateSpin" then
					spins += 1
					t.eq(spec.anim and spec.anim.kind, "Spin")
					t.ok(spec.offset.y <= 4 - 0.5, "spin pattern below the plate top")
				end
			end
			t.eq(spins, 2 * #Layout.PLATES)
			-- 큰 반투명 판은 물 표면(칸마다 1장)뿐
			local bigClear = 0
			for _, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: any
				if (spec.transparency or 0) > 0.05 and b.max.x - b.min.x >= 30 and b.max.z - b.min.z >= 30 then
					bigClear += 1
					t.eq(spec.name, "SinkWater")
				end
			end
			t.eq(bigClear, 2)
			t.ok(#Art.introCamera() >= 4 and #Art.introCamera() <= 5, "intro points")
		end
	)

	t.test(
		"AC8: 서버 모듈 — 태그·cue·면제 한 곳(수세미)뿐, 접시 밀기는 MoveExempt 없음",
		function()
			local source = fs.readFile("src/shared/maps/DishSink.luau")
			t.ok(string.find(source, 'TAG_PLATE = "SinkPlate"', 1, true) ~= nil)
			t.ok(string.find(source, 'TAG_SPONGE = "SinkSponge"', 1, true) ~= nil)
			t.ok(string.find(source, '"SpongeSquish"', 1, true) ~= nil)
			t.ok(string.find(source, '"SoapFoam"', 1, true) ~= nil)
			local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
			t.eq(marks, 1, "only the sponge knockback marks MoveExempt")
			t.ok(string.find(source, "MoveExempt.mark(player.Character, Layout.SPONGE_EXEMPT)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- start (가짜 Heartbeat)
	t.test(
		"start: 수세미를 Logic.spongeX 자리로 옮기고(아레나 슬롯 origin), 끝난 라운드는 판정 안 해요",
		function()
			local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local model = spongeModel(origin)
			local h = newHarness(model)
			local ctx = newCtx(model, origin, {})
			h.setClock(100)
			h.map.start(ctx)
			h.setClock(103)
			h.fire(1 / 60)
			t.eq(h.bulk, 1)
			for _, d in model:GetDescendants() do
				if d.Name == Art.SPONGE_BODY then
					local index = d:GetAttribute("SpongeIndex")
					local sponge = Layout.SPONGES[index]
					local rel = origin:PointToObjectSpace(d.CFrame.Position)
					t.ok(near(rel.X, Logic.spongeX(index, 3), 1e-3), `sponge {index} x {rel.X}`)
					t.ok(
						near(rel.Z, sponge.z, 1e-3) and near(rel.Y, sponge.floorY + sponge.sizeY / 2, 1e-3),
						"y·z kept"
					)
					local scrub = d.Parent:FindFirstChild("SpongeScrub")
					t.ok(
						near((d.CFrame:ToObjectSpace(scrub.CFrame)).Position.Y, 2, 1e-3),
						"children move with the body"
					)
				end
			end
			t.eq(#ctx.cleanup.items, 1, "one Heartbeat connection in ctx.cleanup")
			ctx.active = false
			h.fire(1 / 60)
			t.eq(h.bulk, 1, "no work after the round ended")
		end
	)

	t.test(
		"start: 접시 위에 서 있으면 접선 쪽으로 가속(가속 24), 면제 없음 / 낙하·결승 판정",
		function()
			local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local model = spongeModel(origin)
			local plate = Layout.PLATES[1]
			local onPlate = fakeRacer(origin, plate.x + 3, plate.top + Layout.FOOT_OFFSET, plate.z)
			local falling = fakeRacer(origin, 0, Logic.fallLineAt(-60) - 0.1, -60)
			local finishing = fakeRacer(origin, 0, Layout.FINISH_Y + 3, Layout.FINISH_LINE_Z - 0.01)
			local h = newHarness(model)
			local ctx = newCtx(model, origin, { onPlate, falling, finishing })
			h.setClock(0)
			h.map.start(ctx)
			h.setClock(0.1)
			h.fire(0.1)
			t.ok(ctx.eliminated[falling], "fell below the fall line")
			t.ok(ctx.passed[finishing], "crossed the finish line")
			t.ok(not ctx.eliminated[onPlate] and not ctx.passed[onPlate])
			local vx, vz = Logic.platePush(3, 0, plate.dir)
			local target = origin:VectorToWorldSpace(RV3.new(vx, 0, vz))
			local got = onPlate.root.AssemblyLinearVelocity
			t.ok(near(got.Magnitude, 24 * 0.1, 1e-6), `accelerated {got.Magnitude}`)
			t.ok(got:Dot(target.Unit) > 0.999 * got.Magnitude, "along the plate tangent (world space)")
			t.eq(#h.marks, 0, "continuous push does not mark MoveExempt")
			-- 목표 속도까지만
			for _ = 1, 20 do
				h.fire(0.1)
			end
			local final = onPlate.root.AssemblyLinearVelocity.Magnitude
			t.ok(near(final, target.Magnitude, 1e-4), `capped at the target speed {final} vs {target.Magnitude}`)
		end
	)

	t.test("start: 수세미에 맞으면 옆+위 넉백·면제 1.2·소리, 0.6초 쿨다운", function()
		local origin = RCF.new(0, 300, 2000)
		local model = spongeModel(origin)
		local sponge = Layout.SPONGES[1]
		-- t = 0.5: 수세미 1은 +12에 멈춰 있어요. 그 자리 안쪽(x 9)에 서 있는 사람
		local racer = fakeRacer(origin, 9, sponge.floorY + Layout.FOOT_OFFSET, sponge.z)
		local h = newHarness(model)
		local ctx = newCtx(model, origin, { racer })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(0.5)
		h.fire(1 / 60)
		t.eq(#h.marks, 1)
		t.eq(h.marks[1].seconds, 1.2)
		t.eq(h.sounds[1], "SpongeSquish")
		local v = racer.root.AssemblyLinearVelocity
		-- 멈춰 있으니 중심(12)에서 먼 쪽 = −X
		t.ok(near(v.X, -30, 1e-6) and near(v.Y, 14, 1e-6) and near(v.Z, 0, 1e-6), `knock {v}`)
		t.ok(racer.humanoid.PlatformStand, "knocked down")
		t.ok(table.find(h.delays, 0.12) ~= nil and table.find(h.delays, 0.8) ~= nil, "hold 0.12, knockdown 0.8")
		h.setClock(0.8)
		h.fire(1 / 60)
		t.eq(#h.marks, 1, "cooldown 0.6")
		h.setClock(1.15)
		h.fire(1 / 60)
		t.eq(#h.marks, 2, "hit again after the cooldown")
	end)
end
