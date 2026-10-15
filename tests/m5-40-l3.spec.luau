--!strict
-- m5-40 그룹 L3 (docs/specs/m5-40-map-length-pass.md): bouncy-castle-maze · lantern-bridge 길이 늘리기.
--   AC1 코스 길이(스폰 앞줄 → 결승선)가 목표 ±10%, 구간 z 단조, estimateClearTime 42~55초, 새 구간 길 약속
--       (방방 미로: 몸 반폭을 넣은 격자 플러드필 + build 벽과 순수 판정 일치, 등불 다리: 징검돌 틈 사슬)
--   AC2 새 장애물 수치가 기존 범위 안(벽 높이·칸막이 두께·레인 폭·바운스 / 흔들림·밀기·위험도), 스폰·출발 구간 그대로
--   AC5 Extended 예산, 새 구간 장식이 걷는 시야 상자와 안 겹침, 소개 점이 아레나 상자 + 40 안

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)

local MazeLayout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)
local MazeLogic = RobloxRequire.require(Shared.maps.BouncyCastleMazeLogic)
local MazeArt = RobloxRequire.require(Shared.maps.BouncyCastleMazeArt)
local BridgeLayout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local BridgeLogic = RobloxRequire.require(Shared.maps.LanternBridgeLogic)
local BridgeArt = RobloxRequire.require(Shared.maps.LanternBridgeArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local GRAVITY = 196.2
local BODY_HALF = 1.2 -- 몸 반폭 (격자 길 찾기에서 벽·기둥을 이만큼 두껍게 봐요)
local EPS = 1e-6

type Bounds = MapKitLogic.Bounds

local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = RMaps.get(id).build(origin)
	end
	return built[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

-- 판정 파츠(Decor·IntroCamera·Spawns 밖)의 origin 기준 상자 합 (아레나 상자)
local function judgmentBox(model: any): Bounds
	local min = { x = math.huge, y = math.huge, z = math.huge }
	local max = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and not under(d, model, "Decor")
			and not under(d, model, "IntroCamera")
			and not under(d, model, "Spawns")
		then
			local p = origin:PointToObjectSpace(d.CFrame.Position)
			local r = d.Size.Magnitude / 2
			min.x, min.y, min.z = math.min(min.x, p.X - r), math.min(min.y, p.Y - r), math.min(min.z, p.Z - r)
			max.x, max.y, max.z = math.max(max.x, p.X + r), math.max(max.y, p.Y + r), math.max(max.z, p.Z + r)
		end
	end
	return { min = min, max = max } :: any
end

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

local function box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): Bounds
	return {
		min = { x = math.min(x0, x1), y = math.min(y0, y1), z = math.min(z0, z1) },
		max = { x = math.max(x0, x1), y = math.max(y0, y1), z = math.max(z0, z1) },
	} :: any
end

-- 서 있는 높이(로컬 y = 2)에서 (x, z)가 충돌 판정 파츠 안인지 (블록·세운 원기둥, 회전 고려)
local function solidAt(parts: { any }, x: number, z: number): boolean
	local world = origin:PointToWorldSpace(roblox.Vector3.new(x, 2, z))
	for _, part in parts do
		local rel = part.CFrame:PointToObjectSpace(world)
		local half = part.Size / 2
		if string.find(tostring(part.Shape), "Cylinder", 1, true) then
			local r = math.min(half.Y, half.Z)
			if math.abs(rel.X) <= half.X and rel.Y * rel.Y + rel.Z * rel.Z <= r * r then
				return true
			end
		elseif math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- 1 stud 격자 BFS: 출발 점에서 targetZ(이하)까지 최단 걸음 수 (막힘 판정 함수 blocked)
local function shortest(
	blocked: (number, number) -> boolean,
	startX: number,
	startZ: number,
	targetZ: number,
	xMin: number,
	xMax: number,
	zMin: number,
	zMax: number
): number?
	local dist: { [string]: number } = { [`{startX},{startZ}`] = 0 }
	local queue = { { x = startX, z = startZ } }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		local d = dist[`{cur.x},{cur.z}`]
		if cur.z <= targetZ then
			return d
		end
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = cur.x + step[1], cur.z + step[2]
			local k = `{nx},{nz}`
			if nx >= xMin and nx <= xMax and nz >= zMin and nz <= zMax and dist[k] == nil and not blocked(nx, nz) then
				dist[k] = d + 1
				table.insert(queue, { x = nx, z = nz })
			end
		end
	end
	return nil
end

return function(t: Test.Test)
	---------------------------------------------------------------- bouncy-castle-maze AC1
	t.test(
		"L3 AC1 방방 미로: 코스 길이 240 ±10%, 구간이 출발 → 결승으로 빈틈없이 단조",
		function()
			local spawnFrontZ = MazeLayout.spawnPositions()[1].z
			local length = spawnFrontZ - MazeLayout.finishLineZ()
			t.ok(length >= 240 * 0.9 and length <= 240 * 1.1, `course length {length}`)
			local sections = MazeLayout.sections()
			t.eq(sections[1], MazeLayout.START)
			t.eq(sections[#sections], MazeLayout.FINISH)
			for i, span in sections do
				t.ok(span.front > span.back, `section {i} toward -Z`)
				if i > 1 then
					t.eq(span.front, sections[i - 1].back, `section {i} continues {i - 1}`)
				end
			end
			t.ok(
				MazeLayout.finishLineZ() < MazeLayout.FINISH.front and MazeLayout.finishLineZ() > MazeLayout.FINISH.back
			)
			-- 바운스 바닥 구간은 B·C·F·H, 일반 바닥은 A·D·G·E (튕김 사이 쉼 통로가 있어요)
			t.eq(MazeLayout.MAZE2.front, MazeLayout.EXIT.back)
			t.eq(MazeLayout.LANDING.front, MazeLayout.MAZE2.back)
			t.eq(MazeLayout.FOREST.front, MazeLayout.LANDING.back)
		end
	)

	t.test("L3 AC1 방방 미로: estimateClearTime이 42~55초", function()
		local seconds = MazeLogic.estimateClearTime()
		t.ok(seconds >= 42 and seconds <= 55, `estimate {seconds}`)
		for _, name in MazeLayout.SECTION_ORDER do
			t.ok(MazeLayout.SECTION_WALK[name] ~= nil, `walk constant for {name}`)
		end
	end)

	t.test(
		"L3 AC1 방방 미로: 몸 반폭을 넣어도 스폰 → 결승선 길이 있고, 걸음 수가 추정 걷는 길이와 비슷해요",
		function()
			local function blocked(x: number, z: number): boolean
				return MazeLogic.courseBlockedAt(x, z, BODY_HALF)
			end
			local steps = shortest(
				blocked,
				0,
				-3,
				MazeLayout.finishLineZ(),
				-MazeLayout.HALF_WIDTH,
				MazeLayout.HALF_WIDTH,
				MazeLayout.FINISH.back,
				MazeLayout.START.front
			)
			t.ok(steps ~= nil, "finish reachable with body margin")
			local declared = 0
			for _, name in MazeLayout.SECTION_ORDER do
				declared += MazeLayout.SECTION_WALK[name]
			end
			-- 격자 4방향 최단 경로는 모퉁이를 직각으로 돌아서 실제(대각선) 길보다 조금 길어요
			local ratio = (steps :: number) / declared
			t.ok(ratio >= 0.85 and ratio <= 1.3, `grid steps {steps} vs declared walk {declared}`)
		end
	)

	t.test(
		"L3 AC1 방방 미로 F: 두 번째 미로는 오른쪽 → 가운데(되돌아감) → 왼쪽 S자만 지나가요",
		function()
			local zTop, zBottom = MazeLayout.EXIT.front - 1, MazeLayout.LANDING.back + 1
			local function run(extra: ((number, number) -> boolean)?): number?
				return shortest(
					function(x: number, z: number): boolean
						return MazeLogic.courseBlockedAt(x, z, BODY_HALF) or (extra ~= nil and extra(x, z))
					end,
					15,
					-115,
					MazeLayout.LANDING.back + 1,
					-MazeLayout.HALF_WIDTH,
					MazeLayout.HALF_WIDTH,
					zBottom,
					zTop
				)
			end
			local steps = run(nil)
			t.ok(steps ~= nil, "maze2 passable")
			-- 가운데 레인을 막으면 못 지나가요 (오른쪽 → 왼쪽 직행 없음)
			t.eq(
				run(function(x: number, z: number): boolean
					return math.abs(x) < 6 and z < MazeLayout.MAZE2.front and z > MazeLayout.MAZE2.back
				end),
				nil,
				"middle lane is mandatory"
			)
			-- 왼쪽 레인으로만 나가요: 왼쪽 레인을 막으면 쉼 통로에 못 가요
			t.eq(
				run(function(x: number, z: number): boolean
					return x < -8 and z < MazeLayout.MAZE2.front and z > MazeLayout.MAZE2.back
				end),
				nil,
				"exit only through the left lane"
			)
			-- 되돌아가는 S자라 직선(56)보다 한참 길어요
			t.ok((steps :: number) >= 140, `maze2 path {steps}`)
		end
	)

	t.test(
		"L3 AC1 방방 미로 H: 기둥 줄마다 열린 쪽이 번갈아 있고, 열린 폭 ≥ 8, 기둥 사이 틈은 몸보다 좁아요",
		function()
			local rows = MazeLayout.FOREST_ROWS
			t.eq(#rows, 4)
			for i, row in rows do
				t.ok(
					row.z < MazeLayout.FOREST.front - 3 and row.z > MazeLayout.FOREST.back + 3,
					`row {i} inside forest`
				)
				if i > 1 then
					t.ok(row.open ~= rows[i - 1].open, `row {i} alternates`)
					t.ok(rows[i - 1].z - row.z >= 8, `row {i} spacing`)
				end
			end
			t.ok(MazeLayout.FOREST_OPENING >= 8, "opening width")
			local gap = MazeLayout.PILLAR_PITCH - MazeLayout.PILLAR_DIAMETER
			t.ok(gap < BODY_HALF, `pillar gap {gap} must block a body`)
			-- 줄마다 열린 쪽 외에는 몸이 못 지나가요: 그 줄 z에서 몸 반폭 격자로 막히지 않은 x는 열린 쪽뿐
			for _, row in rows do
				for x = -MazeLayout.HALF_WIDTH + 1, MazeLayout.HALF_WIDTH - 1 do
					if not MazeLogic.courseBlockedAt(x, row.z, BODY_HALF) then
						local inOpening = if row.open == "Left"
							then x < -MazeLayout.HALF_WIDTH + MazeLayout.FOREST_OPENING
							else x > MazeLayout.HALF_WIDTH - MazeLayout.FOREST_OPENING
						t.ok(inOpening, `row z {row.z} leaks at x {x}`)
					end
				end
			end
		end
	)

	t.test(
		"L3 AC1 방방 미로: build가 세운 새 구간 벽·문·기둥이 순수 courseBlockedAt과 같은 칸을 막아요",
		function()
			local model = build("bouncy-castle-maze")
			local solids = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide and not under(d, model, "Decor") then
					local rel = origin:PointToObjectSpace(d.CFrame.Position)
					if rel.Y > 0.5 then -- 바닥 제외 (서 있는 높이의 벽·기둥만)
						table.insert(solids, d)
					end
				end
			end
			local mismatches = {}
			for zi = MazeLayout.EXIT.front - 1, MazeLayout.FINISH.front + 1, -1 do
				for xi = -MazeLayout.HALF_WIDTH + 1, MazeLayout.HALF_WIDTH - 2 do
					local x, z = xi + 0.25, zi - 0.25
					if MazeLogic.courseBlockedAt(x, z) ~= solidAt(solids, x, z) then
						table.insert(mismatches, `{x},{z}`)
					end
				end
			end
			t.eq(#mismatches, 0, `mismatch at {table.concat(mismatches, " ")}`)
		end
	)

	---------------------------------------------------------------- bouncy-castle-maze AC2
	t.test(
		"L3 AC2 방방 미로: 새 장애물 수치가 첫 미로와 같은 범위, 스폰·출발 구간 그대로",
		function()
			for _, p in MazeLayout.MAZE2_PARTITIONS do
				t.eq(p.thickness, MazeLayout.PARTITION_THICKNESS)
			end
			for _, g in { MazeLayout.MAZE2_GATE, MazeLayout.MAZE2_EXIT_GATE } do
				t.eq(g.thickness, MazeLayout.GATE_THICKNESS)
				t.ok(g.openXMax - g.openXMin >= MazeLayout.LANE_WIDTH, "maze2 gate opening ≥ lane width")
			end
			-- 레인 폭 ≥ 첫 미로 레인 폭(10)
			local edges = { MazeLayout.HALF_WIDTH, 7, -7, -MazeLayout.HALF_WIDTH }
			for i = 1, 3 do
				t.ok(edges[i] - edges[i + 1] >= MazeLayout.LANE_WIDTH, `maze2 lane {i} width`)
			end
			-- 기둥은 벽과 같은 높이라 바운스로 못 넘어요
			local apex = MazeLogic.bounceProfile(MazeLayout.BOUNCE_UP_SPEED, GRAVITY).apex
			t.ok(MazeLayout.WALL_HEIGHT >= apex * 1.5)
			local model = build("bouncy-castle-maze")
			local pillars = 0
			for _, d in model:GetChildren() do
				if string.match(d.Name, "^BalloonPillar") then
					pillars += 1
					t.eq(d.Size.X, MazeLayout.WALL_HEIGHT, `{d.Name} height`)
				end
			end
			t.eq(pillars, #MazeLayout.pillars())
			-- 바운스 수치 그대로 (m5-14 값)
			t.eq(MazeLayout.BOUNCE_UP_SPEED, 55)
			t.eq(MazeLayout.BOUNCE_HOLD, 0.08)
			t.eq(MazeLayout.BOUNCE_COOLDOWN, 0.45)
			t.eq(MazeLayout.BOUNCE_EXEMPT, 0.8)
			-- 스폰·출발 구간 그대로 (m5-14 격자)
			t.eq(MazeLayout.START.front, 0)
			t.eq(MazeLayout.START.back, -16)
			local spawns = MazeLayout.spawnPositions()
			t.eq(#spawns, 24)
			t.eq(spawns[1].x, -15)
			t.eq(spawns[1].z, -2.5)
			t.ok(math.abs(spawns[24].z - (-2.5 - 3 * 3.6)) < EPS, `last spawn z {spawns[24].z}`)
			-- 바운스 MoveExempt는 여전히 한 곳 (새 바운스 구간도 같은 스텝퍼)
			local source = fs.readFile("src/shared/maps/BouncyCastleMaze.luau")
			local marks = 0
			for _ in string.gmatch(source, "MoveExempt%.mark%(") do
				marks += 1
			end
			t.eq(marks, 1)
		end
	)

	t.test("L3 AC2 방방 미로: 새 바운스 바닥은 BounceFloor 태그, 쉼 통로는 일반 바닥", function()
		local model = build("bouncy-castle-maze")
		for _, name in { "FloorBounceMaze2", "FloorBounceForest" } do
			local floor = model:FindFirstChild(name)
			t.ok(floor ~= nil, name)
			t.ok(table.find(floor:GetTags(), "BounceFloor") ~= nil, `{name} tagged`)
			local rel = origin:PointToObjectSpace(floor.CFrame.Position)
			t.ok(math.abs(rel.Y + floor.Size.Y / 2) < EPS, `{name} top at y 0`)
		end
		local landing = model:FindFirstChild("FloorLanding")
		t.ok(landing ~= nil and #landing:GetTags() == 0, "landing has no bounce tag")
	end)

	---------------------------------------------------------------- bouncy-castle-maze AC5
	t.test(
		"L3 AC5 방방 미로: Extended 예산, 새 구간 걷는 공간에 장식은 벽·기둥에 붙은 것뿐, 소개 점이 아레나 상자 + 40 안",
		function()
			local decor = MazeArt.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			local lamps = 0
			for _, s in decor do
				if s.name == MazeArt.LAMP then
					lamps += 1
				end
			end
			t.eq(MapKitLogic.checkBudget(decor, "Extended", { lights = lamps }), nil)
			local sight = box(
				-MazeLayout.HALF_WIDTH + 0.5,
				MazeLayout.HALF_WIDTH - 0.5,
				0.2,
				8,
				MazeLayout.MAZE2.front,
				MazeLayout.FOREST.back
			)
			for i, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				if overlaps(b, sight) then
					local cx, cz = (b.min.x + b.max.x) / 2, (b.min.z + b.max.z) / 2
					t.ok(MazeLogic.courseBlockedAt(cx, cz, 0.6), `#{i} {spec.name} stands in the walking space`)
				end
			end
			local arena = judgmentBox(build("bouncy-castle-maze"))
			for i, point in MazeArt.introCamera() do
				local p = point.pos
				t.ok(
					p.x >= arena.min.x - 40
						and p.x <= arena.max.x + 40
						and p.y >= arena.min.y - 40
						and p.y <= arena.max.y + 40
						and p.z >= arena.min.z - 40
						and p.z <= arena.max.z + 40,
					`intro {i} inside arena + 40`
				)
			end
			-- 소개 한 컷은 새 구간(두 번째 미로·풍선 숲)을 봐요
			local sawNew = false
			for _, point in MazeArt.introCamera() do
				if point.lookAt.z <= MazeLayout.MAZE2.front and point.lookAt.z >= MazeLayout.FOREST.back then
					sawNew = true
				end
			end
			t.ok(sawNew, "an intro shot looks at the new sections")
		end
	)

	---------------------------------------------------------------- lantern-bridge AC1
	t.test(
		"L3 AC1 등불 다리: 코스 길이 380 ±10%, 구간 15개가 출발 → 결승으로 빈틈없이 단조",
		function()
			local spawnFrontZ = BridgeLayout.spawnPositions()[1].z
			local length = spawnFrontZ - BridgeLayout.finishLineZ()
			t.ok(length >= 380 * 0.9 and length <= 380 * 1.1, `course length {length}`)
			local sections = BridgeLayout.sections()
			t.eq(#sections, 15)
			t.eq(sections[1].front, BridgeLayout.START.front)
			t.eq(sections[#sections].back, BridgeLayout.FINISH.back)
			for i, span in sections do
				t.ok(span.front > span.back, `section {i} toward -Z`)
				if i > 1 then
					t.eq(span.front, sections[i - 1].back, `section {i} continues {i - 1}`)
				end
			end
			-- 코스 순서: 3 → 5 → 6 → 7 → 개울 → 4 (피날레 다리 4는 결승 바로 앞)
			local b = BridgeLayout.BRIDGES
			t.eq(b[5].front, BridgeLayout.RESTS[3].back)
			t.eq(b[7].back, BridgeLayout.STREAM.front)
			t.eq(b[4].front, BridgeLayout.STREAM.back)
			t.eq(BridgeLayout.FINISH.front, b[4].back)
			for i, bridge in b do
				t.eq(bridge.index, i, "index == array slot (server finds planks by BridgeIndex)")
			end
		end
	)

	t.test("L3 AC1 등불 다리: estimateClearTime이 42~55초", function()
		local seconds = BridgeLogic.estimateClearTime()
		t.ok(seconds >= 42 and seconds <= 55, `estimate {seconds}`)
		t.eq(#BridgeLayout.BRIDGE_DELAY, #BridgeLayout.BRIDGES)
	end)

	t.test(
		"L3 AC1 등불 다리 개울: 둑 → 돌 → 섬 → 돌 → 둑 사슬의 틈이 전부 2~4 (점프로 닿고 걸어서는 안 넘어가요)",
		function()
			local pads = BridgeLayout.streamPads()
			t.eq(#pads, #BridgeLayout.STONES + 3)
			t.eq(pads[1].z + pads[1].halfZ, BridgeLayout.STREAM.front)
			t.eq(pads[#pads].z - pads[#pads].halfZ, BridgeLayout.STREAM.back)
			-- 점프 수평 거리: 걷기 16 × 체공(2 × 점프 50 / 중력) ≈ 8.2 — 틈 상한은 그 절반 아래
			local airtime = 2 * Config.Character.JumpPower / GRAVITY
			local reach = Config.Character.WalkSpeed * airtime
			t.ok(BridgeLayout.STONE_GAP_MAX <= reach / 2, `gap max {BridgeLayout.STONE_GAP_MAX} vs reach {reach}`)
			for i = 2, #pads do
				local gap = BridgeLogic.padGap(pads[i - 1], pads[i])
				t.ok(
					gap >= BridgeLayout.STONE_GAP_MIN - EPS and gap <= BridgeLayout.STONE_GAP_MAX + EPS,
					`{pads[i - 1].name} → {pads[i].name} gap {gap}`
				)
				t.ok(pads[i].z < pads[i - 1].z, `{pads[i].name} further than {pads[i - 1].name}`)
			end
			-- 돌이 좌우로 어긋나요 (지그재그)
			for i = 2, #BridgeLayout.STONES do
				local a, c = BridgeLayout.STONES[i - 1], BridgeLayout.STONES[i]
				if i ~= 6 then -- 5 → 6 사이에는 섬이 있어요
					t.ok(a.x * c.x < 0, `stones {i - 1}/{i} zigzag`)
				end
			end
		end
	)

	t.test(
		"L3 AC1 등불 다리: build한 징검돌 윗면이 y 0이고 태그·흔들림 없이 고정이에요",
		function()
			local model = build("lantern-bridge")
			for _, stone in BridgeLayout.STONES do
				local part = model:FindFirstChild(stone.name)
				t.ok(part ~= nil, stone.name)
				t.ok(part.Anchored and part.CanCollide, `{stone.name} solid`)
				t.eq(#part:GetTags(), 0, `{stone.name} no tag`)
				local rel = origin:PointToObjectSpace(part.CFrame.Position)
				t.ok(math.abs(rel.Y + part.Size.X / 2) < 1e-4, `{stone.name} top at y 0`)
				t.ok(math.abs(rel.X - stone.x) < 1e-4 and math.abs(rel.Z - stone.z) < 1e-4, `{stone.name} position`)
				t.ok(math.abs(part.Size.Y - stone.radius * 2) < 1e-4, `{stone.name} diameter`)
			end
			local planks = 0
			for _, d in model:GetChildren() do
				if table.find(d:GetTags(), "LanternBridgePlank") then
					planks += 1
				end
			end
			t.eq(planks, #BridgeLayout.BRIDGES)
		end
	)

	---------------------------------------------------------------- lantern-bridge AC2
	t.test(
		"L3 AC2 등불 다리: 새 다리 흔들림은 기존 범위(5.5~10), 피날레 다리 4가 여전히 가장 세고 3번이 가장 위험해요",
		function()
			local b = BridgeLayout.BRIDGES
			for i = 5, 7 do
				t.ok(b[i].maxSwayDeg >= 5.5 and b[i].maxSwayDeg < b[4].maxSwayDeg, `bridge {i} sway {b[i].maxSwayDeg}`)
				t.eq(b[i].halfWidth * 2, b[i].width)
				t.eq(b[i].front - b[i].back, b[i].length)
			end
			-- 스펙 표: 폭 10 긴 다리, 폭 6 짧은 다리
			t.eq(b[5].width, 10)
			t.ok(b[5].length >= 40, "bridge 5 is the long one")
			t.eq(b[6].width, 6)
			t.ok(b[6].length <= 20, "bridge 6 is the short one")
			for riders = 0, 24 do
				local risk3 =
					BridgeLogic.fallRisk(BridgeLogic.swayAmplitudeDeg(riders, b[3].maxSwayDeg), b[3].halfWidth)
				for i, bridge in b do
					if i ~= 3 then
						local risk = BridgeLogic.fallRisk(
							BridgeLogic.swayAmplitudeDeg(riders, bridge.maxSwayDeg),
							bridge.halfWidth
						)
						t.ok(risk3 > risk + EPS, `riders {riders}: bridge 3 risk {risk3} vs bridge {i} {risk}`)
					end
				end
			end
			-- 밀기 수치 그대로 (m5-15)
			t.eq(BridgeLayout.PLANK_PUSH_SPEED, 7)
			t.eq(BridgeLayout.PLANK_PUSH_ACCEL, 20)
			t.eq(BridgeLayout.SWAY_PERIOD, 2.6)
		end
	)

	t.test(
		"L3 AC2 등불 다리: 스폰·출발 구간 그대로, 다리 4 치수 그대로(자리만 이동)",
		function()
			t.eq(BridgeLayout.START.front, 0)
			t.eq(BridgeLayout.START.back, -14)
			t.eq(BridgeLayout.START_WIDTH, 16)
			local spawns = BridgeLayout.spawnPositions()
			t.eq(#spawns, 24)
			t.eq(spawns[1].x, -6)
			t.eq(spawns[1].z, -1)
			t.eq(spawns[24].z, -13)
			local b4 = BridgeLayout.BRIDGES[4]
			t.eq(b4.width, 8)
			t.eq(b4.length, 30)
			t.eq(b4.maxSwayDeg, 10)
			for i = 1, 3 do
				local bridge = BridgeLayout.BRIDGES[i]
				t.ok(bridge.front > -110, `bridge {i} unchanged spot`)
			end
		end
	)

	---------------------------------------------------------------- lantern-bridge AC5
	t.test(
		"L3 AC5 등불 다리: Extended 예산(빌드 등불 조명 포함), 새 구간 걷는 공간에 장식 없음, 소개 점이 아레나 상자 + 40 안",
		function()
			local decor = BridgeArt.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			local lanterns = 0
			for _, s in decor do
				if s.name == BridgeArt.LANTERN then
					lanterns += 1
				end
			end
			t.eq(lanterns, 12)
			t.eq(MapKitLogic.checkBudget(decor, "Extended", { lights = lanterns }), nil)

			-- 걷는 시야 상자 (판자·발판 위 0.3~6): 새 다리는 가장자리 등불(±반폭) 안쪽, 새 쉼터·둑·섬은 구석 석등 안쪽,
			-- 징검돌은 돌 위
			local boxes: { { name: string, b: Bounds } } = {}
			for i = 5, 7 do
				local bridge = BridgeLayout.BRIDGES[i]
				local hw = bridge.halfWidth - 1.2
				table.insert(boxes, { name = `bridge{i}`, b = box(-hw, hw, 0.3, 6, bridge.back, bridge.front) })
			end
			for _, zone in
				{
					BridgeLayout.RESTS[4],
					BridgeLayout.RESTS[5],
					BridgeLayout.STREAM_BANK_FRONT,
					BridgeLayout.STREAM_ISLAND,
					BridgeLayout.STREAM_BANK_BACK,
				}
			do
				-- 이웃한 가장 좁은 새 다리(폭 5)만큼의 가운데 통로 — 다리 입구 기둥(반폭 + 0.7)·구석 석등은 그 밖
				local hw = math.min(zone.width / 2 - 3.2, 2.6)
				table.insert(boxes, { name = zone.name, b = box(-hw, hw, 0.3, 6, zone.back, zone.front) })
			end
			for _, stone in BridgeLayout.STONES do
				local r = stone.radius
				table.insert(
					boxes,
					{ name = stone.name, b = box(stone.x - r, stone.x + r, 0.3, 6, stone.z - r, stone.z + r) }
				)
			end
			for i, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				for _, entry in boxes do
					t.ok(not overlaps(b, entry.b), `#{i} {spec.name} in walking space {entry.name}`)
				end
			end

			local arena = judgmentBox(build("lantern-bridge"))
			for i, point in BridgeArt.introCamera() do
				local p = point.pos
				t.ok(
					p.x >= arena.min.x - 40
						and p.x <= arena.max.x + 40
						and p.y >= arena.min.y - 40
						and p.y <= arena.max.y + 40
						and p.z >= arena.min.z - 40
						and p.z <= arena.max.z + 40,
					`intro {i} inside arena + 40`
				)
			end
			local sawNew = false
			for _, point in BridgeArt.introCamera() do
				if point.lookAt.z <= BridgeLayout.STREAM.front and point.lookAt.z >= BridgeLayout.STREAM.back then
					sawNew = true
				end
			end
			t.ok(sawNew, "an intro shot looks at the stream")
		end
	)

	t.test("L3: 두 맵 모두 Race 시간 제한 그대로(맵 timeLimit 없음, Config 90)", function()
		for _, id in { "bouncy-castle-maze", "lantern-bridge" } do
			local map = Maps.get(id)
			t.eq(map.timeLimit, nil, id)
			t.eq(Maps.timeLimit(map), Config.TimeLimit.Race, id)
		end
	end)
end
