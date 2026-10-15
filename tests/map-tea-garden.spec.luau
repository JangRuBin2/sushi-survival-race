--!strict
-- m5-38 "찻잎 정원" (docs/specs/m5-38-map-tea-garden.md): 단·조각·스폰(AC1), 찻사발 심·정원 밖 충돌(AC2),
-- 붕괴 일정(AC3), 찻잔 수·속도(AC4), 단 고르기(AC5), 맞음·넉백(AC6), 연장전 일정 + 모의 실행(AC7), 장식(AC8).
-- 모의 실행은 실제 TeaGarden 소스를 렌더러 환경(tools/render/Shims)에 가짜 task·Heartbeat를 넣어 불러 돌려요.

local luau = require("@lune/luau")
local fs = require("@lune/fs")
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
local Layout = RobloxRequire.require(Shared.maps.TeaGardenLayout)
local Logic = RobloxRequire.require(Shared.maps.TeaGardenLogic)
local Art = RobloxRequire.require(Shared.maps.TeaGardenArt)

local RShared = Shims.root("src/shared")
-- Lune의 ParticleEmitter에는 Emit이 없어요 (실제 Roblox에는 있어요) — 모의 실행에서는 아무것도 안 해요
pcall(roblox.implementMethod, "ParticleEmitter", "Emit", function() end)
local RCF: any = roblox.CFrame
local RV3: any = roblox.Vector3

type Bounds = MapKitLogic.Bounds

local EPS = 1e-6

local function near(t: Test.Test, actual: number, expected: number, eps: number?, label: string?)
	t.ok(math.abs(actual - expected) <= (eps or EPS), `{label or ""} expected {expected} got {actual}`)
end

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

---------------------------------------------------------------- 모의 실행 환경

type Harness = { map: any, delays: { { seconds: number, fn: any, args: { any } } }, waits: number, beats: { any } }

local function newHarness(): Harness
	local harness: Harness = { map = nil, delays = {}, waits = 0, beats = {} }
	local heartbeat = {}
	function heartbeat:Connect(fn: any)
		local h = { fn = fn, connected = true }
		table.insert(harness.beats, h)
		local connection = {}
		function connection:Disconnect()
			h.connected = false
		end
		return connection
	end
	local fakeTask = {
		delay = function(seconds: number, fn: any, ...: any): any
			table.insert(harness.delays, { seconds = seconds, fn = fn, args = { ... } })
			return { __thread = true }
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return { __thread = true }
		end,
		wait = function(): number
			harness.waits += 1
			error("task.wait is not allowed in tea-garden")
		end,
	}
	local runService = { Heartbeat = heartbeat }
	local env = table.clone(Shims.globals)
	env.task = fakeTask
	env.game = {
		GetService = function(_self: any, name: string): any
			if name == "RunService" then
				return runService
			end
			return Shims.game:GetService(name)
		end,
	}
	env.script = (RShared.maps :: any).TeaGarden
	env.require = function(target: any): any
		return Shims.require(target)
	end
	local source = fs.readFile("src/shared/maps/TeaGarden.luau")
	harness.map = luau.load(source, { debugName = "TeaGarden", environment = env })()
	return harness
end

local function newCtx(model: any, origin: any): any
	local ctx: any = {
		model = model,
		origin = origin,
		rng = seededRng(17),
		targetCount = 1,
		active = true,
		eliminated = {} :: { string },
	}
	local items = {}
	ctx.cleanup = {
		items = items,
		add = function(_self: any, item: any)
			table.insert(items, item)
			return item
		end,
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return {}
	end
	ctx.pass = function() end
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, player.Name)
	end
	return ctx
end

-- 순서대로 남은 delay를 모두 실행 (실행 중에 생긴 delay도)
local function runDelays(h: Harness, upTo: number?)
	local i = 1
	while i <= #h.delays do
		local d = h.delays[i]
		if upTo == nil or d.seconds <= upTo then
			table.remove(h.delays, i)
			d.fn(table.unpack(d.args))
		else
			i += 1
		end
	end
end

local function under(part: any, model: any, folder: string): boolean
	local p = part.Parent
	while p and p ~= model do
		if p.Name == folder then
			return true
		end
		p = p.Parent
	end
	return false
end

-- 판정 충돌 파츠 (Decor·Spawns·IntroCamera 밖, CanCollide)
local function colliders(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.CanCollide
			and not under(d, model, "Decor")
			and not under(d, model, "Spawns")
			and not under(d, model, "IntroCamera")
		then
			table.insert(out, d)
		end
	end
	return out
end

local function corners(part: any): { any }
	local half = part.Size / 2
	local list = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(list, part.CFrame:PointToWorldSpace(RV3.new(sx * half.X, sy * half.Y, sz * half.Z)))
			end
		end
	end
	return list
end

-- 장식 상자의 정원 중심 기준 반지름 범위 (원기둥·공은 실제 반지름으로)
local function radialRange(spec: any): (number, number)
	local b = MapKitLogic.bounds({ spec }) :: Bounds
	local cx, cz = (b.min.x + b.max.x) / 2, (b.min.z + b.max.z) / 2
	local rot = spec.rotation
	local upright = spec.shape == "Cylinder" and rot ~= nil and rot.x == 0 and rot.y == 0 and math.abs(rot.z) == 90
	if upright then
		local r = spec.size.y / 2
		local d = math.sqrt(cx * cx + cz * cz)
		return math.max(0, d - r), d + r
	end
	if spec.shape == "Ball" then
		local r = spec.size.x / 2
		local d = math.sqrt(cx * cx + cz * cz)
		return math.max(0, d - r), d + r
	end
	local function clampDist(lo: number, hi: number): number
		if lo > 0 then
			return lo
		elseif hi < 0 then
			return -hi
		end
		return 0
	end
	local nx, nz = clampDist(b.min.x, b.max.x), clampDist(b.min.z, b.max.z)
	local fx = math.max(math.abs(b.min.x), math.abs(b.max.x))
	local fz = math.max(math.abs(b.min.z), math.abs(b.max.z))
	return math.sqrt(nx * nx + nz * nz), math.sqrt(fx * fx + fz * fz)
end

local function allDecor(): { any }
	local list = table.clone(Art.decor())
	for ring = 1, Layout.RING_COUNT do
		for index = 1, Layout.SLICES do
			for _, spec in Art.terraceDecor(ring, index) do
				table.insert(list, spec)
			end
		end
	end
	for _ = 1, Logic.MAX_CUPS do
		for _, spec in Art.cupDecor() do
			table.insert(list, spec)
		end
	end
	return list
end

local built: any = nil
local function buildModel(): any
	if built == nil then
		built = Shims.require((RShared.maps :: any).TeaGarden).build(RCF.new(0, 300, 2000))
	end
	return built
end
local ORIGIN = RCF.new(0, 300, 2000)

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: Final 맵, overtime 함수, validate 통과, lighting = Art.LIGHTING, 랜덤 풀에 들어가요",
		function()
			local map = Maps.get("tea-garden")
			t.eq(MapTypes.validate(map), nil)
			t.eq(map.kind, "Final")
			t.eq(type(map.overtime), "function")
			t.ok(map.inPool ~= false, "inPool 줄 삭제")
			t.ok(map.lighting == Art.LIGHTING, "lighting = Art.LIGHTING")
			t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
			t.eq(map.displayName, "찻잎 정원")
			t.eq(
				map.rule,
				"굴러오는 찻잔을 피해 단을 옮기고, 무너지는 차밭에서 끝까지 버텨요!"
			)
			local found = false
			for _, info in Maps.infos() do
				found = found or info.id == "tea-garden"
			end
			t.ok(found, "Maps.infos()에 있어요")
		end
	)

	t.test("AC1: 단 표 — 반지름·윗면이 스펙과 같고 이웃 단 높이 차 1.5", function()
		local want = { { 7, 15, 6 }, { 15, 23, 4.5 }, { 23, 31, 3 }, { 31, 39, 1.5 }, { 39, 47, 0 } }
		t.eq(#Layout.RINGS, 5)
		for k, row in want do
			local r = Layout.RINGS[k]
			t.eq(r.inner, row[1])
			t.eq(r.outer, row[2])
			t.eq(r.top, row[3])
			if k > 1 then
				t.eq(Layout.RINGS[k - 1].top - r.top, 1.5, `step {k}`)
				t.eq(Layout.RINGS[k - 1].outer, r.inner, `ring {k} meets ring {k - 1}`)
			end
		end
		t.eq(Layout.RADIUS, 47)
	end)

	t.test(
		"AC1: 조각 상자 — 바깥 모서리가 반지름 outer에 닿고(틈 0), 이웃 단의 맞닿는 면이 같은 현",
		function()
			local half = Layout.SLICE_ANGLE / 2
			for ring = 1, 5 do
				local slices = Layout.slices(ring)
				t.eq(#slices, 12)
				local def = Layout.RINGS[ring]
				for _, s in slices do
					local far = s.distance + s.depth / 2
					local corner = math.sqrt(far * far + (s.width / 2) ^ 2)
					near(t, corner, def.outer, 1e-9, "outer corner on the circle")
					-- 조각 경계선(이등분선 ±15°) 위 바깥 끝까지 상자가 덮어요 → 조각 사이 틈 0 (≤ 0.5)
					local edgeAlong = def.outer * math.cos(half)
					local edgeAcross = def.outer * math.sin(half)
					t.ok(edgeAlong <= far + EPS and edgeAcross <= s.width / 2 + EPS, "slice boundary covered")
					near(t, s.centerY + s.height / 2, def.top, 1e-9, "top")
				end
				if ring > 1 then
					local inner = slices[1]
					local outerOfPrev = Layout.slices(ring - 1)[1]
					near(
						t,
						inner.distance - inner.depth / 2,
						outerOfPrev.distance + outerOfPrev.depth / 2,
						1e-9,
						"ring faces meet"
					)
				end
			end
		end
	)

	t.test(
		"AC1: build — 단 5개 × 조각 12개(태그 TeaTerrace, 속성 Ring·Index), 윗면 높이가 표와 같아요",
		function()
			local model = buildModel()
			local perRing: { [number]: number } = {}
			local count = 0
			for _, d in model:GetDescendants() do
				if d:IsA("Model") and d:HasTag("TeaTerrace") then
					count += 1
					local ring = d:GetAttribute("Ring")
					t.ok(type(ring) == "number" and ring >= 1 and ring <= 5, "Ring attribute")
					t.ok(type(d:GetAttribute("Index")) == "number", "Index attribute")
					perRing[ring] = (perRing[ring] or 0) + 1
					local slab = d:FindFirstChild("Slab")
					t.ok(slab ~= nil and slab.CanCollide, "slab collides")
					local topY = slab.CFrame.Position.Y + slab.Size.Y / 2 - 300
					near(t, topY, Layout.RINGS[ring].top, 1e-3, `ring {ring} top`)
				end
			end
			t.eq(count, 60)
			for ring = 1, 5 do
				t.eq(perRing[ring], 12, `ring {ring}`)
			end
		end
	)

	t.test("AC1: 스폰 24개 — 3·4단 위, 단 윗면 바로 위, 서로 3 이상", function()
		local spawns = Layout.spawns()
		t.eq(#spawns, 24)
		local byRing = { [3] = 0, [4] = 0 }
		for i, s in spawns do
			local r = math.sqrt(s.x * s.x + s.z * s.z)
			local def = Layout.RINGS[s.ring]
			t.ok(s.ring == 3 or s.ring == 4, `spawn {i} ring`)
			byRing[s.ring] += 1
			t.ok(r > def.inner + 1 and r < def.outer * math.cos(Layout.SLICE_ANGLE / 2) - 1, `spawn {i} radius {r}`)
			near(t, s.y, def.top + 0.1, 1e-9, `spawn {i} y`)
		end
		t.eq(byRing[3], 12)
		t.eq(byRing[4], 12)
		for i = 1, #spawns do
			for j = i + 1, #spawns do
				local a, b = spawns[i], spawns[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.ok(d >= 3, `spawn {i}-{j} distance {d}`)
			end
		end
		-- 앞 두 개가 다른 단 (몰리지 않게)
		t.ok(spawns[1].ring ~= spawns[2].ring, "first two spawns on different rings")
	end)

	---------------------------------------------------------------- AC2
	t.test(
		"AC2: 찻사발 심 윗면 − 1단 윗면 > 점프 + 5, 정원 밖(반지름 47)에 충돌 파츠 없음",
		function()
			t.ok(Layout.CORE_TOP - Layout.RINGS[1].top > Layout.JUMP_HEIGHT + 5, "core too low")
			local model = buildModel()
			local list = colliders(model)
			t.ok(#list > 60, "terraces + core collide")
			local core = model:FindFirstChild("BowlCore")
			t.ok(core ~= nil and core.CanCollide and core.Transparency == 1, "invisible core collides")
			near(t, core.CFrame.Position.Y + core.Size.X / 2 - 300, Layout.CORE_TOP, 1e-3, "core top")
			for _, part in list do
				for _, p in corners(part) do
					local x, z = p.X, p.Z - 2000
					t.ok(math.sqrt(x * x + z * z) <= Layout.RADIUS + 1e-3, `{part:GetFullName()} outside the garden`)
				end
			end
			-- 찻잔은 충돌·터치·쿼리 없음
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local parent = d.Parent
					if parent and parent:HasTag("TeaRollingCup") then
						t.ok(not d.CanCollide and not d.CanTouch and not d.CanQuery, `cup part {d.Name}`)
					end
				end
			end
		end
	)

	---------------------------------------------------------------- AC3
	t.test("AC3: collapseAt·isCollapsing", function()
		t.eq(Logic.collapseAt(5), 15)
		t.eq(Logic.collapseAt(4), 30)
		t.eq(Logic.collapseAt(3), 45)
		t.eq(Logic.collapseAt(2), nil)
		t.eq(Logic.collapseAt(1), nil)
		t.eq(Logic.collapseAt(2, 90), 100)
		t.eq(Logic.collapseAt(1, 90), 110)
		t.eq(Logic.collapseAt(5, 90), 15)
		t.eq(Logic.isCollapsing(5, 12), "Warn")
		t.eq(Logic.isCollapsing(5, 11.9), "Solid")
		t.eq(Logic.isCollapsing(5, 15), "Gone")
		t.eq(Logic.isCollapsing(4, 26.9), "Solid")
		t.eq(Logic.isCollapsing(4, 27), "Warn")
		t.eq(Logic.isCollapsing(2, 99), "Solid")
		t.eq(Logic.isCollapsing(2, 97, 90), "Warn")
		t.eq(Logic.isCollapsing(1, 110, 90), "Gone")
		t.eq(Logic.WARN_TIME, 3)
		t.eq(Logic.DROP_TIME, 0.6)
		t.eq(Logic.DROP_DISTANCE, 3)
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: cupWave 표", function()
		local function wave(time: number, ot: number?): { number }
			local count, speed = Logic.cupWave(time, ot)
			return { count, speed }
		end
		t.eq(Logic.cupWave(2.9), 0)
		t.eq(wave(3), { 1, 13 })
		t.eq(wave(29.9), { 1, 13 })
		t.eq(wave(30), { 2, 13 })
		t.eq(wave(60), { 3, 16 })
		t.eq(wave(95), { 3, 16 })
		t.eq(wave(90, 90), { 3, 18 })
		t.eq(wave(89, 90), { 3, 16 })
		-- 디버그 overtimeAt처럼 일찍 와도 연장전 값
		t.eq(wave(20, 20), { 3, 18 })
	end)

	t.test("AC4: cupPosition — 일정 선속도, rebase는 위치를 바꾸지 않아요", function()
		local cup = { ring = 2, angle0 = 0, t0 = 3, dir = 1, speed = 13 }
		local ring, angle = Logic.cupPosition(cup, 3)
		t.eq(ring, 2)
		near(t, angle, 0)
		-- 2단 한 바퀴(반지름 19)는 약 9초
		local lap = 2 * math.pi * Layout.ringMid(2) / 13
		t.ok(lap > 8.9 and lap < 9.4, `lap {lap}`)
		local _, back = Logic.cupPosition({ ring = 2, angle0 = 1, t0 = 0, dir = -1, speed = 19 }, 1)
		near(t, back, 0, 1e-9, "reverse direction")
		local moved = Logic.rebase(cup, 10, nil, 16)
		local _, a1 = Logic.cupPosition(cup, 10)
		local _, a2 = Logic.cupPosition(moved, 10)
		near(t, a1, a2, 1e-9, "rebase keeps position")
		t.eq(moved.speed, 16)
	end)

	---------------------------------------------------------------- AC5
	t.test("AC5: pickCupRing — 무너진 단·4초 안에 무너질 단은 안 골라요", function()
		local rng = seededRng(3)
		local rings = {
			{ ring = 1, collapseAt = nil },
			{ ring = 2, collapseAt = nil },
			{ ring = 3, collapseAt = 45 },
			{ ring = 4, collapseAt = 30 }, -- 이미 무너짐 (t ≥ 30)
		}
		for _ = 1, 300 do
			local to = Logic.pickCupRing(rng, { 2 }, rings, 42)
			t.ok(to == 1, `picked {tostring(to)} (3 collapses within 4s, 4 is gone)`)
		end
		-- 40.9초면 3단은 아직 안전 (45 > 40.9 + 4)
		local seen: { [number]: boolean } = {}
		for _ = 1, 300 do
			local to = Logic.pickCupRing(rng, { 2 }, rings, 40.9)
			if to then
				seen[to] = true
			end
		end
		t.ok(seen[1] and seen[3] and not seen[4], "neighbors 1 and 3 when 3 is still safe")
		-- 4단이 무너진 뒤 3단의 바깥 이웃은 없어요 (무너진 단은 건너뛰어 5단으로 가지도 않아요)
		local afterFour = { { ring = 1 }, { ring = 2 }, { ring = 3, collapseAt = 45 }, { ring = 5, collapseAt = 15 } }
		for _ = 1, 50 do
			t.eq(Logic.pickCupRing(rng, { 3 }, afterFour, 31), 2)
		end
		-- 위험한 단에 있는 찻잔은 다른 찻잔이 있어도 옮겨요
		t.eq(Logic.pickCupRing(rng, { 3, 2 }, rings, 42, 1), 2)
		t.ok(Logic.mustMoveCup({ 3 }, rings, 42), "must leave a collapsing ring")
		t.ok(not Logic.mustMoveCup({ 2 }, rings, 42), "safe ring")
		-- 갈 곳이 없으면 nil (연장전 끝: 1단만 남고 곧 무너짐)
		t.eq(Logic.pickCupRing(rng, { 1 }, { { ring = 1, collapseAt = 110 } }, 107), nil)
	end)

	t.test("AC5: 찻잔 수 ≤ 남은 단 수면 같은 단 중복 없음, 이웃 단만", function()
		local rng = seededRng(9)
		local rings = {}
		for r = 1, 5 do
			table.insert(rings, { ring = r, collapseAt = Logic.collapseAt(r) })
		end
		for _ = 1, 500 do
			-- 3초: 5단 모두 남음, 찻잔 2개 (1단·2단)
			local to = Logic.pickCupRing(rng, { 1, 2 }, rings, 3, 1)
			t.ok(to == nil, `cup on 1 with 2 taken has no free neighbor (got {tostring(to)})`)
			local to2 = Logic.pickCupRing(rng, { 1, 2 }, rings, 3, 2)
			t.eq(to2, 3, "cup on 2 goes outward to 3 (1 taken)")
			local to3 = Logic.pickCupRing(rng, { 3, 1, 5 }, rings, 3, 1)
			t.ok(to3 == 2 or to3 == 4, `neighbor of 3 ({tostring(to3)})`)
			-- 이웃이 아닌 단으로는 건너뛰지 않아요
			t.eq(Logic.pickCupRing(rng, { 1, 2, 4 }, rings, 3, 1), nil, "1 cannot hop over 2")
		end
		-- 겹쳐 있으면 꼭 옮겨요 (찻잔 수 ≤ 남은 단 수)
		t.ok(Logic.mustMoveCup({ 1, 1 }, rings, 3, 2), "duplicate must move")
		-- 찻잔 3개, 단 2개면 겹쳐도 돼요
		local two = { { ring = 1 }, { ring = 2 } }
		t.ok(not Logic.mustMoveCup({ 1, 1, 2 }, two, 70, 2), "3 cups on 2 rings may share")
		t.eq(Logic.pickCupRing(rng, { 1, 1, 2 }, two, 70, 1), 2)
	end)

	t.test("AC5: 1,000번 시뮬레이션 (45~90초, 1·2단만 남음) — 늘 1 또는 2", function()
		local rng = seededRng(21)
		local rings = { { ring = 1 }, { ring = 2 } }
		local moved = 0
		for _ = 1, 1000 do
			local time = rng:NextNumber(45, 90)
			local count = rng:NextInteger(1, 3)
			local cups = {}
			for i = 1, count do
				cups[i] = rng:NextInteger(1, 2)
			end
			local index = rng:NextInteger(1, count)
			local to = Logic.pickCupRing(rng, cups, rings, time, index)
			t.ok(to == nil or to == 1 or to == 2, `got {tostring(to)}`)
			if to then
				moved += 1
				t.ok(to ~= cups[index], "moves to another ring")
				if count <= 2 then
					for j, other in cups do
						t.ok(j == index or other ~= to, "no duplicate when cups ≤ rings")
					end
				end
			end
		end
		t.ok(moved > 300, `moved {moved}`)
	end)

	t.test("AC5: shouldMoveCup — 위험·중복이면 꼭, 아니면 약 50%", function()
		local rng = seededRng(5)
		local rings = { { ring = 1 }, { ring = 2 }, { ring = 3 } }
		local yes = 0
		for _ = 1, 2000 do
			if Logic.shouldMoveCup(rng, { 2 }, rings, 50) then
				yes += 1
			end
		end
		t.ok(yes > 900 and yes < 1100, `about half ({yes})`)
		t.eq(Logic.MOVE_INTERVAL, 6)
		t.eq(Logic.MOVE_WARN, 1.2)
		t.eq(Logic.MOVE_TIME, 0.5)
		t.eq(Logic.MOVE_SAFE_WINDOW, 4)
	end)

	---------------------------------------------------------------- AC6
	t.test("AC6: cupHit — 수평 3.5 안 · 발 < 윗면 + 6", function()
		t.ok(Logic.cupHit(0, 0, 4.5, 4.5), "center")
		t.ok(Logic.cupHit(3.5, 0, 4.5, 4.5), "edge 3.5")
		t.ok(Logic.cupHit(2, 2.8, 10.4, 4.5), "inside, foot just below top + 6")
		t.ok(not Logic.cupHit(2, 2.9, 4.5, 4.5), "outside 3.5 (diagonal)")
		t.ok(not Logic.cupHit(3.51, 0, 4.5, 4.5), "outside 3.5")
		t.ok(not Logic.cupHit(0, 0, 10.5, 4.5), "foot = top + 6")
		t.ok(not Logic.cupHit(0, 0, 11, 4.5), "jumped over")
		t.eq(Logic.KNOCK_FORWARD, 26)
		t.eq(Logic.KNOCK_OUTWARD, 12)
		t.eq(Logic.KNOCK_UP, 18)
		t.eq(Logic.EXEMPT_TIME, 1.5)
		t.eq(Logic.HIT_COOLDOWN, 1)
		t.eq(Logic.KNOCKDOWN_TIME, 0.8)
		t.eq(Logic.LAUNCH_HOLD, 0.12)
		t.eq(Logic.CUP_DIAMETER, 6)
		t.eq(Logic.CUP_WIDTH, 4)
	end)

	t.test("AC6: cupKnockback — 진행 방향 26 + 바깥 12 + 위 18", function()
		-- 각도 0(+X 위), dir +1 → 진행 방향 +Z, 바깥 +X
		local k = Logic.cupKnockback(0, 1)
		near(t, k.x, 12)
		near(t, k.y, 18)
		near(t, k.z, 26)
		local back = Logic.cupKnockback(0, -1)
		near(t, back.z, -26)
		near(t, back.x, 12)
		local quarter = Logic.cupKnockback(math.pi / 2, 1) -- +Z 위: 진행 −X, 바깥 +Z
		near(t, quarter.x, -26, 1e-9)
		near(t, quarter.z, 12, 1e-9)
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: overtimeCollapse 표", function()
		local steps = Logic.overtimeCollapse(20, { 2, 1 })
		t.eq(steps, { { ring = 2, warnAt = 7, dropAt = 10 }, { ring = 1, warnAt = 17, dropAt = 20 } })
		-- 순서가 섞여 들어와도 바깥 먼저
		t.eq(Logic.overtimeCollapse(20, { 1, 2 }), steps)
		local all = Logic.overtimeCollapse(20, { 5, 4, 3, 2, 1 })
		t.eq(#all, 5)
		for i, step in all do
			t.eq(step.ring, 6 - i, "outer first")
			near(t, step.dropAt, 4 * i, 1e-9, "4s apart")
			near(t, step.warnAt, math.max(0, 4 * i - 3), 1e-9)
		end
		t.eq(all[5].dropAt, 20)
		t.eq(all[5].dropAt, Config.Final.CollapseDuration)
		t.eq(Logic.overtimeCollapse(20, {}), {})
	end)

	t.test(
		"AC7 모의 실행: 본 경기 붕괴 뒤 연장전 — 훅이 바로 돌아오고, +10 2단·+20 1단·심 → 충돌 파츠 0개",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN)
			local ctx = newCtx(model, ORIGIN)
			h.map.start(ctx)
			t.eq(h.waits, 0, "start does not wait")
			-- 본 경기 일정 (5·4·3단 경고·무너짐)
			local marks = {}
			for _, d in h.delays do
				table.insert(marks, d.seconds)
			end
			table.sort(marks)
			t.eq(marks, { 12, 15, 27, 30, 42, 45 })
			runDelays(h)
			local function ringColliding(ring: number): number
				local n = 0
				for _, d in model:GetDescendants() do
					if d:IsA("Model") and d:GetAttribute("Ring") == ring then
						local slab = d:FindFirstChild("Slab")
						if slab and slab.CanCollide then
							n += 1
						end
					end
				end
				return n
			end
			for ring = 3, 5 do
				t.eq(ringColliding(ring), 0, `ring {ring} gone`)
			end
			t.eq(ringColliding(2), 12)
			t.eq(ringColliding(1), 12)

			-- 연장전 훅
			local before = os.clock()
			h.map.overtime(ctx, { collapseDuration = 20 })
			t.ok(os.clock() - before < 0.05, "overtime returns at once")
			t.eq(h.waits, 0, "no task.wait in overtime")
			local seconds = {}
			for _, d in h.delays do
				table.insert(seconds, d.seconds)
			end
			table.sort(seconds)
			t.eq(seconds, { 7, 10, 17, 20, 20 })
			runDelays(h, 10)
			t.eq(ringColliding(2), 0, "ring 2 at +10")
			t.eq(ringColliding(1), 12, "ring 1 stays until +20")
			t.ok(#colliders(model) > 0, "still somewhere to stand")
			runDelays(h)
			t.eq(#colliders(model), 0, "nothing to stand or hang on after +20")
			local core = model:FindFirstChild("BowlCore")
			t.eq(core.CanCollide, false, "core off")
			-- 찻잔은 숨겨져요
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Parent and d.Parent:HasTag("TeaRollingCup") then
					t.eq(d.Transparency, 1, `cup {d.Name} hidden`)
				end
			end
			-- 모든 delay·연결은 ctx.cleanup에
			t.ok(#ctx.cleanup.items >= 12, "scheduled work is in ctx.cleanup")
		end
	)

	t.test(
		"AC7 모의 실행: 디버그 연장전이 일러도(5단 모두 남음) 같은 20초 안에 전부 무너져요",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN)
			local ctx = newCtx(model, ORIGIN)
			h.map.start(ctx)
			local mainDelays = h.delays
			h.delays = {}
			h.map.overtime(ctx, { collapseDuration = 20 })
			local drops = {}
			for _, d in h.delays do
				table.insert(drops, d.seconds)
			end
			table.sort(drops)
			t.eq(drops, { 1, 4, 5, 8, 9, 12, 13, 16, 17, 20, 20 })
			-- 본 경기 일정이 뒤늦게 와도 연장전이 맡은 단은 건드리지 않아요 (이중 실행 없음)
			for _, d in mainDelays do
				d.fn(table.unpack(d.args))
			end
			runDelays(h)
			t.eq(#colliders(model), 0, "all gone within collapseDuration")
		end
	)

	t.test(
		"AC7 모의 실행: 라운드가 먼저 끝났으면 연장전이 바닥을 건드리지 않아요, start 없이도 무너져요",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN)
			local ctx = newCtx(model, ORIGIN)
			local count = #colliders(model)
			h.map.overtime(ctx, { collapseDuration = 20 }) -- start가 실패한 경우
			ctx.active = false
			runDelays(h)
			t.eq(#colliders(model), count, "inactive round keeps the floor")
			local h2 = newHarness()
			local model2 = h2.map.build(ORIGIN)
			local ctx2 = newCtx(model2, ORIGIN)
			h2.map.overtime(ctx2, { collapseDuration = 20 })
			runDelays(h2)
			t.eq(#colliders(model2), 0, "overtime without start still clears the garden")
		end
	)

	t.test(
		"모의 실행: 낙하선 — origin 로컬 y −25 아래면 탈락 (아레나 슬롯 높이에서도)",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN)
			local ctx = newCtx(model, ORIGIN)
			local function fake(name: string, y: number): any
				local root = {
					Position = ORIGIN:PointToWorldSpace(RV3.new(30, y, 0)),
					IsA = function(_, cls: string)
						return cls == "BasePart"
					end,
				}
				return {
					Name = name,
					Character = {
						FindFirstChild = function(_, n: string)
							return if n == "HumanoidRootPart" then root else nil
						end,
						FindFirstChildOfClass = function()
							return nil
						end,
					},
				}
			end
			local safe, fallen = fake("safe", -24.9), fake("fallen", -25.1)
			ctx.getRacers = function()
				return { safe, fallen }
			end
			h.map.start(ctx)
			t.eq(#h.beats, 1, "one Heartbeat connection")
			h.beats[1].fn(1 / 60)
			t.eq(ctx.eliminated, { "fallen" })
			ctx.active = false
			ctx.eliminated = {}
			h.beats[1].fn(1 / 60)
			t.eq(ctx.eliminated, {}, "inactive round does not judge")
		end
	)

	---------------------------------------------------------------- AC8
	t.test(
		"AC8: 장식 — 목록마다 validate, 합쳐서 Extended 예산 안, 움직이는 조각·찻잔에는 anim 없음",
		function()
			t.eq(Art.BUDGET, "Extended")
			t.eq(MapKitLogic.validate(Art.decor()), nil)
			t.eq(MapKitLogic.validate(Art.cupDecor()), nil)
			for ring = 1, 5 do
				for index = 1, 12 do
					local list = Art.terraceDecor(ring, index)
					t.eq(MapKitLogic.validate(list), nil, `terrace {ring}/{index}`)
					for _, spec in list do
						t.eq(spec.anim, nil, `terrace decor {spec.name} anim`)
						t.eq(spec.light, nil, `terrace decor {spec.name} light`)
					end
				end
			end
			for _, spec in Art.cupDecor() do
				t.eq(spec.anim, nil, `cup decor {spec.name} anim`)
			end
			local all = allDecor()
			-- 런타임 찻잎 터짐 이미터 1개도 같이 세요
			t.eq(MapKitLogic.checkBudget(all, "Extended", { particles = 1 }), nil)
			t.ok(#all >= 700 and #all <= 1300, `decor parts {#all} (target 700~1300)`)
			t.ok(MapKitLogic.countShadowedLights(all) <= 2, "shadowed lights")
			t.ok(MapKitLogic.countParticles(all) >= 6 and MapKitLogic.countParticles(all) <= 12, "particles 6~12")
			t.ok(MapKitLogic.countAnimated(Art.decor()) >= 3, "anim")
			for _, spec in all do
				if spec.light and spec.light.kind == "Surface" then
					t.ok(spec.light.range <= 16, `{spec.name} surface light range`)
				end
			end
			-- 파티클 종류: Petals·TeaLeaves·Steam·Sparkle
			local kinds: { [string]: boolean } = {}
			for _, spec in all do
				if spec.particle then
					kinds[spec.particle] = true
				end
			end
			for _, name in { "Petals", "TeaLeaves", "Steam", "Sparkle" } do
				t.ok(kinds[name], `particle {name}`)
			end
		end
	)

	t.test("AC8: 장식이 밟는 면 시야(각 단 윗면 위 2~12)를 가리지 않아요", function()
		local function check(list: { any }, label: string)
			for _, spec in list do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				local rMin, rMax = radialRange(spec)
				for ring = 1, 5 do
					local def = Layout.RINGS[ring]
					local overlapR = rMax > def.inner + 0.5 and rMin < def.outer - 0.5
					local overlapY = b.max.y > def.top + Art.SIGHT_MIN and b.min.y < def.top + Art.SIGHT_MAX
					t.ok(not (overlapR and overlapY), `{label} {spec.name} blocks ring {ring} sight`)
				end
			end
		end
		check(Art.decor(), "decor")
		for ring = 1, 5 do
			for index = 1, 12 do
				check(Art.terraceDecor(ring, index), "terrace")
			end
		end
	end)

	t.test(
		"AC8: 가짜 바닥 없음 — 정원 근처 단 윗면 ±1 안의 넓고 얇은 장식 판이 없어요",
		function()
			local function check(list: { any }, label: string)
				for _, spec in list do
					local b = MapKitLogic.bounds({ spec }) :: Bounds
					local rMin = radialRange(spec)
					local flat = b.max.y - b.min.y <= 1.5 and math.min(b.max.x - b.min.x, b.max.z - b.min.z) >= 2
					if flat and rMin < Layout.RADIUS + 12 then
						for ring = 1, 5 do
							local top = Layout.RINGS[ring].top
							-- 단 윗면에 붙은 무늬(이랑 줄)·경고 띠는 윗면 0.1 안 — 그 밖 ±1은 금지
							local flush = b.max.y <= top + 0.1 and b.min.y >= top - 0.01
							if not flush and b.max.y > top - 1 and b.max.y < top + 1 and b.max.y > top - 0.05 then
								t.ok(false, `{label} {spec.name} top {b.max.y} looks like a floor near ring {ring}`)
							end
						end
					end
				end
			end
			check(Art.decor(), "decor")
			for ring = 1, 5 do
				for index = 1, 12 do
					check(Art.terraceDecor(ring, index), "terrace")
				end
			end
		end
	)

	t.test("AC8: 배경 바닥(땅·시냇물)은 낙하 탈락선 −25보다 10 이상 아래 (≤ −35)", function()
		local found = 0
		for _, spec in Art.decor() do
			if spec.name == "Ground" or spec.name == "GroundMoss" or spec.name == "Stream" then
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				t.ok(b.max.y <= -35, `{spec.name} top {b.max.y}`)
				found += 1
			end
		end
		t.ok(found >= 5, "background floors exist")
		t.ok(Art.GROUND_Y <= -Layout.FALL_DEPTH - 10, "ground")
	end)

	t.test("AC8: 맵 lighting 프리셋이 validate 통과, 로비와 달라요 (황금 시간 17.3)", function()
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
		t.eq(Art.LIGHTING.ClockTime, 17.3)
		t.ok(Art.LIGHTING.ClockTime ~= MapLighting.LOBBY.ClockTime, "differs from lobby")
	end)

	t.test(
		"소개 카메라 4~5점, 판정 경계 + 40 안, 카메라 자리가 판정 파츠 속이 아니에요",
		function()
			local points = Art.introCamera()
			t.ok(#points >= 4 and #points <= 5, "4~5 points")
			local limit = Layout.RADIUS + 40
			local model = buildModel()
			local solids = colliders(model)
			for i, p in points do
				t.ok(math.sqrt(p.pos.x ^ 2 + p.pos.z ^ 2) <= limit, `point {i} xz`)
				t.ok(p.pos.y <= Layout.CORE_TOP + 40 and p.pos.y >= -40, `point {i} y`)
				local world = ORIGIN:PointToWorldSpace(RV3.new(p.pos.x, p.pos.y, p.pos.z))
				for _, part in solids do
					local lp = part.CFrame:PointToObjectSpace(world)
					local half = part.Size / 2
					local inside = math.abs(lp.X) < half.X and math.abs(lp.Y) < half.Y and math.abs(lp.Z) < half.Z
					t.ok(not inside, `intro point {i} inside {part.Name}`)
				end
			end
		end
	)
end
