--!strict
-- m5-39 "온천탕 인형뽑기" (docs/specs/m5-39-map-onsen-claw.md):
--   AC1 데크 30개·반지름·윗면·스폰, AC2 몸체 높이·충돌 파츠, AC3 물 높이, AC4 가라앉기 시각·상태,
--   AC5 "쿵" 일정, AC6 충격파 판정·넉백, AC7 연장전 순서 + 모의 실행(설 곳 0), AC8 장식 규칙.
--   start 모의 실행: 물 탈락, 고리가 지나갈 때 서 있으면 넉백(+MoveExempt), 점프 중이면 안 맞음.

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
local Layout = RobloxRequire.require(Shared.maps.OnsenClawLayout)
local Logic = RobloxRequire.require(Shared.maps.OnsenClawLogic)
local Art = RobloxRequire.require(Shared.maps.OnsenClawArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

type DecorSpec = MapKitLogic.DecorSpec

local EPS = 1e-6

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

-- 판정 충돌 파츠 (Decor·Spawns·IntroCamera 밖, CanCollide)
local function colliders(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local skip = false
			local p = d.Parent
			while p and p ~= model do
				if p.Name == "Decor" or p.Name == "Spawns" or p.Name == "IntroCamera" then
					skip = true
					break
				end
				p = p.Parent
			end
			if not skip then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function decksOf(model: any): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:HasTag("OnsenDeck") then
			table.insert(list, d)
		end
	end
	return list
end

-- 장식 상자 하나가 탕 중심에서 갖는 수평 거리 범위 [minR, maxR]
local function radialRange(b: MapKitLogic.Bounds): (number, number)
	local cx, cz = Layout.CENTER_X, Layout.CENTER_Z
	local nx = math.clamp(cx, b.min.x, b.max.x)
	local nz = math.clamp(cz, b.min.z, b.max.z)
	local minR = math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
	local maxR = 0
	for _, x in { b.min.x, b.max.x } do
		for _, z in { b.min.z, b.max.z } do
			maxR = math.max(maxR, math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2))
		end
	end
	return minR, maxR
end

---------------------------------------------------------------- 가짜 환경 (start·overtime 모의 실행)

type Sim = {
	now: number,
	queue: { { at: number, fn: any, args: { any } } },
	heartbeat: { (dt: number) -> () },
	waits: number,
	sounds: { string }?,
}

local implemented = false
local function ensureServerTime()
	if implemented then
		return
	end
	implemented = true
	pcall(roblox.implementMethod, "Workspace", "GetServerTimeNow", function()
		return 0
	end)
end

-- OnsenClaw 모듈을 가짜 task·os·Heartbeat·Raycast로 새로 불러요 (Shims 환경 + 실제 Layout/Logic/Art/MapKit)
local function loadMap(sim: Sim, raycast: ((any, any) -> any)?): any
	ensureServerTime()
	local fakeTask = {
		delay = function(seconds: number, fn: any, ...: any): any
			table.insert(sim.queue, { at = sim.now + seconds, fn = fn, args = table.pack(...) })
			return { __thread = true }
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return { __thread = true }
		end,
		wait = function(seconds: number?): number
			sim.waits += 1
			local dt = seconds or 0.03
			sim.now += dt
			return dt
		end,
	}
	local heartbeat = {
		Connect = function(_self: any, fn: any)
			table.insert(sim.heartbeat, fn)
			return { Disconnect = function() end }
		end,
	}
	local env = table.clone(Shims.globals)
	env.script = RShared.maps.OnsenClaw
	local sounds: { string } = {}
	sim.sounds = sounds
	env.require = function(node: any): any
		if node.Name == "MapSfx" then
			-- 소리는 리모트가 필요해서 기록만 (Lune에는 Remotes가 없어요)
			return {
				play = function(_part: any, cue: string)
					table.insert(sounds, cue)
				end,
			}
		end
		return Shims.require(node)
	end
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return sim.now
		end,
	}
	env.game = {
		GetService = function(_self: any, name: string): any
			if name == "RunService" then
				return { Heartbeat = heartbeat }
			end
			return Shims.game:GetService(name)
		end,
	}
	env.workspace = {
		Raycast = function(_self: any, origin: any, direction: any, _params: any): any
			return if raycast then raycast(origin, direction) else nil
		end,
	}
	local source = fs.readFile("src/shared/maps/OnsenClaw.luau")
	return luau.load(source, { debugName = "OnsenClaw(sim)", environment = env })()
end

-- 큐를 시간 순서로 끝까지 (각 delay 함수 안의 task.wait는 sim.now를 앞으로 보내요)
local function runQueue(sim: Sim, untilAt: number, onStep: (() -> ())?)
	while true do
		table.sort(sim.queue, function(a, b)
			return a.at < b.at
		end)
		local item = sim.queue[1]
		if item == nil or item.at > untilAt then
			break
		end
		table.remove(sim.queue, 1)
		sim.now = math.max(sim.now, item.at)
		item.fn(table.unpack(item.args, 1, item.args.n))
		if onStep then
			onStep()
		end
	end
end

local function newCtx(model: any, origin: any, racers: { any }): any
	local ctx: any = {
		model = model,
		origin = origin,
		cleanup = { items = {} },
		active = true,
		eliminated = {} :: { string },
	}
	function ctx.cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		local out = {}
		for _, r in racers do
			if not table.find(ctx.eliminated, r.Name) then
				table.insert(out, r)
			end
		end
		return out
	end
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, player.Name)
	end
	ctx.pass = function() end
	return ctx
end

-- 진짜 Part 루트 + Humanoid가 있는 가짜 플레이어 (탕 중심 기준 각도·거리·발 높이)
local function racer(name: string, origin: any, angle: number, dist: number, footY: number): any
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	local x, z = Layout.polar(angle, dist)
	root.CFrame = origin * RCF.new(x, footY + Layout.FOOT_OFFSET, z)
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Parent = character
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

local function hasLaunch(r: any): boolean
	return r.root:FindFirstChild("ShockwaveLaunch") ~= nil
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: Final, overtime 함수, 풀에 들어감(inPool 없음), 조명 = Art.LIGHTING, 시간 제한 90",
		function()
			local map = Maps.get("onsen-claw")
			t.eq(MapTypes.validate(map), nil)
			t.eq(map.kind, "Final")
			t.eq(type(map.overtime), "function")
			t.eq(map.inPool, nil, "inPool 줄 삭제")
			t.ok(map.lighting == Art.LIGHTING, "lighting = Art.LIGHTING")
			t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
			t.eq(map.displayName, "온천탕 인형뽑기")
			t.eq(
				map.rule,
				"인형뽑기가 쿵! 퍼지는 충격파는 점프로 넘고, 차오르는 온천물을 피해요!"
			)
		end
	)

	t.test("AC1: 단 표 — 반지름·윗면·데크 수, 이웃 단 높이 차 2, 같은 단 틈 ≤ 1", function()
		local expected = {
			{ inner = 33, outer = 42, top = 0, count = 12 },
			{ inner = 25, outer = 33, top = 2, count = 8 },
			{ inner = 17, outer = 25, top = 4, count = 6 },
			{ inner = 10, outer = 17, top = 6, count = 4 },
		}
		for i, row in expected do
			local tier = Layout.TIERS[i]
			t.eq(tier.inner, row.inner, `tier {i} inner`)
			t.eq(tier.outer, row.outer, `tier {i} outer`)
			t.eq(tier.top, row.top, `tier {i} top`)
			t.eq(tier.count, row.count, `tier {i} count`)
			t.ok(Layout.seamGap(i) <= 1, `tier {i} seam gap {Layout.seamGap(i)}`)
			if i > 1 then
				t.eq(tier.top - Layout.TIERS[i - 1].top, 2, `tier {i - 1}→{i} height step`)
				t.eq(tier.outer, Layout.TIERS[i - 1].inner, `tier {i} touches tier {i - 1}`)
			end
		end
		t.eq(#Layout.decks(), 30)
	end)

	t.test(
		"AC1: build — 데크 Model 30개(태그 OnsenDeck, Tier·Index), 조각이 표의 반지름·윗면 안",
		function()
			local origin = RCF.new(0, 300, 0)
			local model = RMaps.get("onsen-claw").build(origin)
			local decks = decksOf(model)
			t.eq(#decks, 30)
			local perTier = { 0, 0, 0, 0 }
			local seen: { [string]: boolean } = {}
			for _, deck in decks do
				local tier = deck:GetAttribute("Tier")
				local index = deck:GetAttribute("Index")
				t.ok(type(tier) == "number" and type(index) == "number", `{deck.Name} attributes`)
				perTier[tier] += 1
				local key = `{tier}/{index}`
				t.ok(not seen[key], `duplicate deck {key}`)
				seen[key] = true
				local row = Layout.TIERS[tier]
				t.ok(index >= 1 and index <= row.count, `{key} index range`)
				local planks = 0
				for _, p in deck:GetChildren() do
					if p:IsA("BasePart") and p.CanCollide then
						planks += 1
						local rel = origin:ToObjectSpace(p.CFrame)
						local dx, dz = rel.Position.X - Layout.CENTER_X, rel.Position.Z - Layout.CENTER_Z
						local centerR = math.sqrt(dx * dx + dz * dz)
						-- 상자 가운데선 위 안쪽·바깥 면 (반지름 방향 = 상자 로컬 X)
						t.ok(near(centerR - p.Size.X / 2, row.inner, 1e-3), `{key} inner edge {centerR - p.Size.X / 2}`)
						t.ok(near(centerR + p.Size.X / 2, row.outer, 1e-3), `{key} outer edge`)
						local top = rel.Position.Y + p.Size.Y / 2
						t.ok(near(top, row.top, Layout.SEAM_DROP + 1e-3), `{key} top {top}`)
					end
				end
				t.eq(planks, row.segments, `{key} plank count`)
			end
			t.eq(perTier, { 12, 8, 6, 4 })
		end
	)

	t.test(
		"AC1: 스폰 24개 — 2·3단 조각 위(윗면 + 0.1), 서로 3 이상, 가운데를 바라봐요",
		function()
			local origin = RCF.new()
			local model = RMaps.get("onsen-claw").build(origin)
			local spawns = model:FindFirstChild("Spawns"):GetChildren()
			t.eq(#spawns, 24)
			local planks = colliders(model)
			for i, s in spawns do
				local p = s.CFrame.Position
				local dx, dz = p.X - Layout.CENTER_X, p.Z - Layout.CENTER_Z
				local tier = Layout.tierAt(math.sqrt(dx * dx + dz * dz))
				t.ok(tier == 2 or tier == 3, `{s.Name} tier {tier}`)
				-- 그 단 조각 하나의 윗면 위
				local over = false
				for _, plank in planks do
					local lp = plank.CFrame:PointToObjectSpace(p)
					local above = lp.Y - plank.Size.Y / 2
					if
						math.abs(lp.X) <= plank.Size.X / 2
						and math.abs(lp.Z) <= plank.Size.Z / 2
						and above >= 0
						and above <= 0.2
					then
						over = true
					end
				end
				t.ok(over, `{s.Name} over a deck plank`)
				-- 가운데를 바라봐요 (LookVector가 탕 중심 쪽)
				local look = s.CFrame.LookVector
				t.ok(look.X * -dx + look.Z * -dz > 0, `{s.Name} faces the center`)
				for j = i + 1, #spawns do
					local d = (p - spawns[j].CFrame.Position).Magnitude
					t.ok(d >= 3, `{s.Name}/{spawns[j].Name} {d}`)
				end
			end
			local points = Layout.spawnPoints()
			t.eq(#points, 24)
			local tiers = { [2] = 0, [3] = 0 }
			for _, p in points do
				tiers[p.tier] += 1
			end
			t.eq(tiers[2], 12)
			t.eq(tiers[3], 12)
		end
	)

	---------------------------------------------------------------- AC2
	t.test("AC2: 인형뽑기 몸체 윗면 24 − 4단 6 > 점프 + 5, 몸체는 섬(반지름 9) 안", function()
		t.eq(Layout.BODY_TOP_Y, 24)
		t.ok(Layout.BODY_TOP_Y - Layout.TIERS[4].top > Layout.JUMP_HEIGHT + 5, "body too low")
		t.ok(Layout.BODY_HALF * math.sqrt(2) <= Layout.ISLAND_RADIUS, "body corner inside the island")
		t.ok(Layout.ISLAND_RADIUS < Layout.TIERS[4].inner, "island inside tier 4")
	end)

	t.test(
		"AC2: 충돌 있는 파츠는 데크 조각과 인형뽑기 몸체뿐 (탕 밖·섬·기계 장식은 충돌 없음)",
		function()
			local model = RMaps.get("onsen-claw").build(RCF.new())
			local planks, body = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide then
					if d.Name == "ClawBody" then
						body += 1
					else
						local deck = d.Parent
						t.ok(
							deck ~= nil and deck:IsA("Model") and deck:HasTag("OnsenDeck"),
							`{d:GetFullName()} collides`
						)
						t.ok(string.match(d.Name, "^Plank%d+$") ~= nil, `{d.Name} is a plank`)
						planks += 1
					end
				end
			end
			t.eq(body, 1)
			t.eq(planks, 4 * 9 + 6 * 6 + 8 * 5 + 12 * 3)
			local bodyPart = model:FindFirstChild("ClawBody")
			local top = bodyPart.CFrame.Position.Y + bodyPart.Size.Y / 2
			t.ok(near(top, 24, 1e-3), `body top {top}`)
		end
	)

	---------------------------------------------------------------- AC3
	t.test(
		"AC3: waterHeight 0·9.9 → −3, 10 → −2, 20 → −1, 40 → 1, 60 → 3, 70 → 4, 80·200 → 4.5",
		function()
			for _, row in
				{
					{ 0, -3 },
					{ 9.9, -3 },
					{ 10, -2 },
					{ 20, -1 },
					{ 40, 1 },
					{ 60, 3 },
					{ 70, 4 },
					{ 80, 4.5 },
					{ 200, 4.5 },
				}
			do
				t.eq(Logic.waterHeight(row[1]), row[2], `t={row[1]}`)
			end
		end
	)

	t.test(
		"AC3: 물은 0~200초 0.1초 간격으로 줄지 않고, 보이는 물 ≥ 판정 물(1초 안에 따라잡음)",
		function()
			local prev = -math.huge
			local prevVisual = -math.huge
			for i = 0, 2000 do
				local s = i / 10
				local h = Logic.waterHeight(s)
				local vis = Logic.waterVisual(s)
				t.ok(h >= prev, `waterHeight decreased at {s}`)
				t.ok(vis >= prevVisual - EPS, `waterVisual decreased at {s}`)
				t.ok(vis >= h - EPS, `visual below judgment at {s}`)
				t.ok(vis <= Logic.waterHeight(s + Logic.WATER_EASE) + EPS, `visual ahead by more than the ease at {s}`)
				prev, prevVisual = h, vis
			end
			t.ok(Logic.isSoaked(-2.6, -2), "foot below water − 0.5")
			t.ok(not Logic.isSoaked(-2.5, -2), "exactly water − 0.5 is safe")
		end
	)

	---------------------------------------------------------------- AC4
	t.test("AC4: sinkAt 1단 20·2단 40·3단 60·4단 nil, deckState 경고·가라앉음", function()
		t.eq(Logic.sinkAt(1), 20)
		t.eq(Logic.sinkAt(2), 40)
		t.eq(Logic.sinkAt(3), 60)
		t.eq(Logic.sinkAt(4), nil)
		t.eq(Logic.deckState(1, 16.9), "Solid")
		t.eq(Logic.deckState(1, 17), "Warn")
		t.eq(Logic.deckState(1, 20), "Sunk")
		t.eq(Logic.deckState(2, 37), "Warn")
		t.eq(Logic.deckState(3, 57), "Warn")
		t.eq(Logic.deckState(3, 60), "Sunk")
		t.eq(Logic.deckState(4, 89.9), "Solid")
		t.eq(Logic.deckState(4, 200), "Solid")
	end)

	t.test(
		"AC4: 어느 시각이든 서 있는(Solid) 단 윗면 > 물 − 0.5, 가라앉는 순간 물 ≥ 윗면 − 1",
		function()
			for i = 0, 2000 do
				local s = i / 10
				local water = Logic.waterHeight(s)
				for tier = 1, 4 do
					if Logic.deckState(tier, s) ~= "Sunk" then
						t.ok(water - Logic.SOAK_MARGIN < Layout.TIERS[tier].top, `tier {tier} at {s}`)
					end
				end
			end
			for tier = 1, 3 do
				local at = Logic.sinkAt(tier) :: number
				t.ok(
					Logic.waterHeight(at) >= Layout.TIERS[tier].top - 1,
					`tier {tier} sinks when water reaches top − 1`
				)
				t.ok(Logic.waterHeight(at - 0.01) < Layout.TIERS[tier].top - 1, `tier {tier} not earlier`)
			end
			-- 60초 뒤 4단만 남아도 넓이가 충분 (약 590)
			local area = math.pi * (17 ^ 2 - 10 ^ 2)
			t.ok(area > 550 and area < 620, `tier 4 area {area}`)
		end
	)

	---------------------------------------------------------------- AC5
	t.test("AC5: slamTimes — 8, 20, 32, 44, 53, 62, 그 뒤 6초 간격 고리 2개", function()
		local list = Logic.slamTimes(nil, 100)
		local expect = { 8, 20, 32, 44, 53, 62, 68, 74, 80, 86, 92, 98 }
		t.eq(#list, #expect)
		for i, at in expect do
			t.eq(list[i].at, at, `slam {i}`)
			t.eq(list[i].rings, if at >= 65 then 2 else 1, `slam {i} rings`)
		end
	end)

	t.test("AC5: 연장전 — 연장전 뒤 쿵은 3초 간격·고리 2개, 그 전 일정은 그대로", function()
		local list = Logic.slamTimes(90, 120)
		local before, after = {}, {}
		for _, slam in list do
			if slam.at < 90 then
				table.insert(before, slam.at)
			else
				table.insert(after, slam)
			end
		end
		t.eq(before, { 8, 20, 32, 44, 53, 62, 68, 74, 80, 86 })
		t.eq(after[1].at, 93)
		for i, slam in after do
			t.eq(slam.rings, 2, `overtime slam {i} rings`)
			if i > 1 then
				t.eq(slam.at - after[i - 1].at, 3, `overtime gap {i}`)
			end
		end
		-- 디버그로 일찍(65초) 와도 3초 간격
		local early = Logic.slamTimes(65, 80)
		t.eq(early[#early].at - early[#early - 1].at, 3)
		t.eq(early[7].at, 68, "first overtime slam = max(62, 65) + 3")
	end)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: ringRadius·waveHit — 이번 틱에 지나가고 서 있으면 맞음, 점프 중·이미 지나감은 안 맞음",
		function()
			t.eq(Logic.ringRadius(8, 9), 9 + 24)
			t.eq(Logic.ringRadius(8, 7), 9, "쿵 전에는 시작 반지름")
			local top = 4
			t.ok(Logic.waveHit(20, 19.5, 20.2, top, top), "standing")
			t.ok(Logic.waveHit(20, 19.5, 20.2, top + 1.2, top), "foot exactly top + 1.2")
			t.ok(not Logic.waveHit(20, 19.5, 20.2, top + 1.21, top), "jumping")
			t.ok(not Logic.waveHit(20, 20.2, 20.6, top, top), "ring already passed")
			t.ok(not Logic.waveHit(20, 18, 19.9, top, top), "ring not yet there")
			t.ok(not Logic.waveHit(20, 19.5, 20.2, top - 2, top), "falling below the deck (in the water)")
			-- 1단 바깥(42)까지 약 1.4초, 점프 체공(약 0.51초) > 고리 통과(두께 3 / 24 = 0.125초)
			t.ok(near((42 - 9) / Logic.RING_SPEED, 1.375), "ring reaches 42 in ~1.4s")
			t.ok(2 * 50 / 196.2 > Logic.RING_THICKNESS / Logic.RING_SPEED, "a jump outlasts the ring")
		end
	)

	t.test("AC6: waveKnockback — 4단 ×1.3 (31.2·23.4), 그 밖 24·18, outward는 단위 벡터", function()
		local k4 = Logic.waveKnockback(13, 4)
		t.ok(near(k4.horizontal, 31.2) and near(k4.up, 23.4), "tier 4")
		local k3 = Logic.waveKnockback(20, 3)
		t.ok(near(k3.horizontal, 24) and near(k3.up, 18), "tier 3")
		local k1 = Logic.waveKnockback(40, 1)
		t.ok(near(k1.horizontal, 24) and near(k1.up, 18), "tier 1")
		local ux, uz = Logic.outward(3, -4)
		t.ok(near(ux, 0.6) and near(uz, -0.8), "unit outward")
		local cx, cz = Logic.outward(0, 0)
		t.ok(cx == 1 and cz == 0, "center → +X")
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: overtimeSinkOrder — 4단 4개면 5·10·15·20, 경고 = 2초 전", function()
		local steps = Logic.overtimeSinkOrder({
			{ tier = 4, index = 3 },
			{ tier = 4, index = 1 },
			{ tier = 4, index = 4 },
			{ tier = 4, index = 2 },
		}, 20)
		t.eq(#steps, 4)
		for k, step in steps do
			t.eq(step.index, k, "Index order")
			t.ok(near(step.dropAt, 5 * k), `dropAt {step.dropAt}`)
			t.ok(near(step.warnAt, step.dropAt - 2), `warnAt {step.warnAt}`)
		end
	end)

	t.test("AC7: 낮은 단이 섞이면 낮은 단 먼저, 마지막은 20초, warnAt ≥ 0", function()
		local remaining = {}
		for _, deck in Layout.decks() do
			table.insert(remaining, { tier = 5 - deck.tier, index = deck.index }) -- 순서를 뒤집어 넣어도
		end
		local steps = Logic.overtimeSinkOrder(remaining, 20)
		t.eq(#steps, 30)
		for k, step in steps do
			t.ok(step.warnAt >= 0, "warnAt >= 0")
			if k > 1 then
				local prev = steps[k - 1]
				t.ok(prev.tier < step.tier or (prev.tier == step.tier and prev.index < step.index), `order at {k}`)
				t.ok(step.dropAt > prev.dropAt, `dropAt increasing at {k}`)
			end
		end
		t.ok(near(steps[#steps].dropAt, 20), "last at collapseDuration")
		t.eq(Logic.overtimeSinkOrder({}, 20), {})
	end)

	t.test(
		"AC7: 연장전 모의 실행 — 훅이 바로 돌아오고, 데크가 낮은 단부터 하나씩, +20초에 충돌 파츠 0",
		function()
			for _, withStart in { false, true } do
				local sim: Sim = { now = 1000, queue = {}, heartbeat = {}, waits = 0 }
				local map = loadMap(sim, nil)
				local origin = RCF.new(2000, 300, 0)
				local model = map.build(origin)
				model.Parent = Shims.globals.workspace
				local ctx = newCtx(model, origin, {})
				if withStart then
					map.start(ctx)
				end
				local startedHook = sim.now
				map.overtime(ctx, { collapseDuration = Config.Final.CollapseDuration })
				t.eq(sim.now, startedHook, "hook returns without waiting")
				t.eq(sim.waits, 0, "no task.wait inside the hook")
				t.ok(#sim.queue >= 31, `delays queued ({#sim.queue})`)
				-- 데크가 충돌을 잃는 시각
				local sunkAt: { [any]: number } = {}
				local decks = decksOf(model)
				local function record()
					for _, deck in decks do
						if sunkAt[deck] == nil then
							local plank = deck:FindFirstChild("Plank01")
							if plank and not plank.CanCollide then
								sunkAt[deck] = sim.now - startedHook
							end
						end
					end
				end
				runQueue(sim, startedHook + Config.Final.CollapseDuration + 5, record)
				t.eq(#colliders(model), 0, `withStart={withStart}: no colliders after collapse`)
				-- 낮은 단부터: 단 k의 마지막 데크 ≤ 단 k+1의 첫 데크
				local lastOfTier = { 0, 0, 0, 0 }
				local firstOfTier = { math.huge, math.huge, math.huge, math.huge }
				for _, deck in decks do
					local tier = deck:GetAttribute("Tier")
					local at = sunkAt[deck]
					t.ok(at ~= nil, `{deck.Name} sank`)
					if at then
						lastOfTier[tier] = math.max(lastOfTier[tier], at)
						firstOfTier[tier] = math.min(firstOfTier[tier], at)
						t.ok(at <= Config.Final.CollapseDuration + 1e-6, `{deck.Name} at {at}`)
					end
				end
				for tier = 1, 3 do
					t.ok(lastOfTier[tier] <= firstOfTier[tier + 1] + 1e-6, `tier {tier} before tier {tier + 1}`)
				end
				t.ok(near(lastOfTier[4], Config.Final.CollapseDuration, 1e-3), `last deck at {lastOfTier[4]}`)
				local body = model:FindFirstChild("ClawBody")
				t.eq(body.CanCollide, false, "claw body collision off")
				t.ok(table.find(sim.sounds or {}, "TileVanish") ~= nil, "sink cue")
				model:Destroy()
			end
		end
	)

	t.test("AC7: 연장전 — 라운드가 이미 끝났으면 손대지 않아요", function()
		local sim: Sim = { now = 50, queue = {}, heartbeat = {}, waits = 0 }
		local map = loadMap(sim, nil)
		local origin = RCF.new()
		local model = map.build(origin)
		model.Parent = Shims.globals.workspace
		local ctx = newCtx(model, origin, {})
		map.start(ctx)
		map.overtime(ctx, { collapseDuration = 20 })
		ctx.active = false
		runQueue(sim, sim.now + 30)
		local body = model:FindFirstChild("ClawBody")
		t.eq(body.CanCollide, true, "body untouched after the round ended")
		local plank = decksOf(model)[1]:FindFirstChild("Plank01")
		t.eq(plank.CanCollide, true, "decks untouched after the round ended")
		model:Destroy()
	end)

	---------------------------------------------------------------- start 모의 실행
	t.test("start: 물에 잠긴 발은 탈락, 4단 위는 안전, 안전망 −25", function()
		local sim: Sim = { now = 0, queue = {}, heartbeat = {}, waits = 0 }
		local map = loadMap(sim, nil)
		local origin = RCF.new(0, 300, 0)
		local model = map.build(origin)
		model.Parent = Shims.globals.workspace
		local wet = racer("Wet", origin, 0, 45, -3) -- 1단 바깥 물 띠, 발 −3
		local dry = racer("Dry", origin, 90, 13, 6) -- 4단 위
		local deep = racer("Deep", origin, 180, 30, -23) -- 루트 y = −20 (안전망 위지만 물 아래)
		local ctx = newCtx(model, origin, { wet, dry, deep })
		map.start(ctx)
		-- 9초: 물 −3 → 발 −3은 안전(−3 < −3.5 아님)
		for _ = 1, 3 do
			sim.now += 3
			for _, fn in sim.heartbeat do
				fn(3)
			end
		end
		t.eq(ctx.eliminated, { "Deep" }, "only the deep one at 9s")
		-- 15초: 물 −2 → 발 −3 < −2.5 → 탈락
		sim.now = 15
		for _, fn in sim.heartbeat do
			fn(0.2)
		end
		t.ok(table.find(ctx.eliminated, "Wet") ~= nil, "wet eliminated at 15s")
		t.ok(table.find(ctx.eliminated, "Dry") == nil, "tier 4 is dry")
		model:Destroy()
	end)

	t.test(
		"start: 고리가 지나갈 때 서 있으면 바깥으로 튕기고 MoveExempt, 점프 중이면 안 맞아요",
		function()
			local sim: Sim = { now = 0, queue = {}, heartbeat = {}, waits = 0 }
			local origin = RCF.new(0, 300, 0)
			-- 가짜 Raycast: 루트 아래 4.5 안에 그 자리 단 윗면이 있으면 그 단 조각에 맞음
			local function raycast(from: any, direction: any): any
				local rel = origin:PointToObjectSpace(from)
				local dx, dz = rel.X - Layout.CENTER_X, rel.Z - Layout.CENTER_Z
				local tier = Layout.tierAt(math.sqrt(dx * dx + dz * dz))
				if tier == nil then
					return nil
				end
				local top = Layout.TIERS[tier].top
				if rel.Y >= top and rel.Y + direction.Y <= top then
					return {
						Instance = {
							GetAttribute = function(_self: any, name: string): any
								return if name == "Tier" then tier else nil
							end,
						},
					}
				end
				return nil
			end
			local map = loadMap(sim, raycast)
			local model = map.build(origin)
			model.Parent = Shims.globals.workspace
			local standing = racer("Standing", origin, 30, 21, 4) -- 3단에 서 있음
			local jumping = racer("Jumping", origin, 150, 21, 4 + 2.5) -- 3단 위로 점프 중
			local inner = racer("Inner", origin, 270, 13, 6) -- 4단
			local ctx = newCtx(model, origin, { standing, jumping, inner })
			map.start(ctx)
			-- 0 → 8.6초를 1/60초로 (8초 "쿵", 고리 반지름 21에 8.5초쯤)
			local dt = 1 / 60
			while sim.now < 8.6 do
				sim.now += dt
				for _, fn in sim.heartbeat do
					fn(dt)
				end
			end
			t.ok(hasLaunch(standing), "standing racer launched")
			t.ok(not hasLaunch(jumping), "jumping racer not hit")
			t.ok(hasLaunch(inner), "tier 4 racer launched")
			t.eq(standing.humanoid.PlatformStand, true, "knocked down")
			local exempt = standing.Character:GetAttribute("MoveExemptUntil")
			t.ok(type(exempt) == "number" and exempt > 0, "MoveExempt marked")
			-- 바깥 방향 + 위, 4단은 ×1.3
			local v3 = standing.root:FindFirstChild("ShockwaveLaunch").VectorVelocity
			local local3 = origin:VectorToObjectSpace(v3)
			local px, pz = Layout.polar(30, 21)
			local ux, uz = Logic.outward(px - Layout.CENTER_X, pz - Layout.CENTER_Z)
			t.ok(near(local3.X, ux * 24, 1e-3) and near(local3.Z, uz * 24, 1e-3), "outward 24")
			t.ok(near(v3.Y, 18, 1e-3), "up 18")
			local vi = inner.root:FindFirstChild("ShockwaveLaunch").VectorVelocity
			t.ok(near(vi.Y, 23.4, 1e-3), "tier 4 up 23.4")
			t.eq(#ctx.eliminated, 0)
			t.ok(table.find(sim.sounds or {}, "ClawSlam") ~= nil, "ClawSlam cue")
			-- 고리 보여주기 파츠는 충돌 없음
			local waves = model:FindFirstChild("Waves")
			t.ok(waves ~= nil, "Waves folder")
			for _, d in waves:GetDescendants() do
				if d:IsA("BasePart") then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, "ring visual is ghost")
				end
			end
			model:Destroy()
		end
	)

	---------------------------------------------------------------- AC8
	t.test(
		"AC8: 장식 validate, Extended 예산 안 (데크 장식·집게·불빛·물빛 포함), 생동감",
		function()
			local decor = Art.decor()
			t.eq(Art.BUDGET, "Extended")
			t.eq(MapKitLogic.validate(decor), nil)
			local extraParts = #Art.clawRig() + #Art.slamLights()
			for _, deck in Layout.decks() do
				local specs = Art.deckDecor(deck)
				t.eq(MapKitLogic.validate(specs), nil, `deckDecor {deck.key}`)
				extraParts += #specs
			end
			t.eq(MapKitLogic.validate(Art.clawRig()), nil)
			t.eq(MapKitLogic.validate(Art.slamLights()), nil)
			-- 물 표면 SurfaceLight 1 + 경고 거품 최대 3 (1단 12개 / 4)
			t.eq(MapKitLogic.checkBudget(decor, "Extended", { parts = extraParts, lights = 1, particles = 3 }), nil)
			t.ok(#decor >= 700 and #decor <= 1300, `decor parts {#decor} (목표 700~1300)`)
			t.ok(MapKitLogic.countParticles(decor) >= 6 and MapKitLogic.countParticles(decor) <= 12, "particles 6~12")
			t.ok(MapKitLogic.countAnimated(decor) >= 10, "anim")
			t.ok(MapKitLogic.countShadowedLights(decor) == 2, "two shadowed lights")
			for _, spec in decor do
				if spec.light and spec.light.kind == "Surface" then
					t.ok(spec.light.range <= 16, `{spec.name} SurfaceLight range`)
				end
			end
			t.ok(
				Art.WATER_LIGHT.kind == "Surface" and Art.WATER_LIGHT.range <= 16 and Art.WATER_LIGHT.shadows ~= true,
				"water light"
			)
		end
	)

	t.test(
		"AC8: 데크·집게·불빛·기계 하위 장식에 anim 없음, 배경 바닥 ≤ −35, 종이등은 데크 위에 없음",
		function()
			for _, deck in Layout.decks() do
				for _, spec in Art.deckDecor(deck) do
					t.eq(spec.anim, nil, `deckDecor {spec.name}`)
				end
			end
			for _, spec in Art.clawRig() do
				t.eq(spec.anim, nil, `clawRig {spec.name}`)
			end
			for _, spec in Art.slamLights() do
				t.eq(spec.anim, nil, `slamLights {spec.name}`)
			end
			local floor = nil
			for _, spec in Art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				local minR, maxR = radialRange(b)
				-- 섬(몸체) 위·안의 장식은 움직이지 않아요 (연장전에 몸체 충돌을 끄니까)
				if maxR <= Layout.ISLAND_RADIUS + 0.5 then
					t.eq(spec.anim, nil, `machine decor {spec.name} animated`)
				end
				-- 데크 고리 위로 보이는 장식(물 위 높이)은 anim 없음
				if minR < Layout.TIERS[1].outer and maxR > Layout.TIERS[4].inner and b.max.y > -3 and b.min.y < 30 then
					t.eq(spec.anim, nil, `{spec.name} over the decks animated`)
				end
				if spec.name == "PoolFloor" then
					floor = b.max.y
				end
				if string.sub(spec.name, 1, 5) == "Andon" then
					t.ok(minR > Layout.POOL_RADIUS, `{spec.name} lantern not on the decks`)
				end
			end
			t.ok(floor ~= nil and floor <= Layout.FALL_ELIMINATION_Y - 10, `pool floor {floor}`)
		end
	)

	t.test("AC8: 밟는 면 시야 상자(각 단 윗면 ~ +7)와 겹치는 장식 없음", function()
		for _, spec in Art.decor() do
			local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
			local minR, maxR = radialRange(b)
			for i, tier in Layout.TIERS do
				local radial = minR < tier.outer - EPS and maxR > tier.inner + EPS
				local vertical = b.min.y < tier.top + 7 - EPS and b.max.y > tier.top + EPS
				t.ok(not (radial and vertical), `{spec.name} overlaps tier {i} walking volume`)
			end
		end
		-- 데크 가장자리 판은 그 데크 윗면보다 0.1 낮게
		for _, deck in Layout.decks() do
			for _, spec in Art.deckDecor(deck) do
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				t.ok(b.max.y <= deck.top - 0.1 + 1e-6, `{spec.name} on {deck.key} below the top`)
			end
		end
	end)

	t.test(
		"AC8: 소개 카메라 5점, 탕(판정 경계) + 40 안, 물·바위·기계를 뚫지 않아요",
		function()
			local points = Art.introCamera()
			t.eq(#points, 5)
			for i, p in points do
				local dx, dz = p.pos.x - Layout.CENTER_X, p.pos.z - Layout.CENTER_Z
				local r = math.sqrt(dx * dx + dz * dz)
				t.ok(r <= Layout.POOL_RADIUS + 40 + 10, `intro {i} r {r}`)
				t.ok(p.pos.y > Logic.WATER_MAX + 0.5 or p.pos.y > Logic.waterHeight(0) + 1, `intro {i} above water`)
				-- 기계 몸체 안이 아님
				t.ok(
					not (
							math.abs(dx) <= Layout.BODY_HALF
							and math.abs(dz) <= Layout.BODY_HALF
							and p.pos.y <= Layout.BODY_TOP_Y + 8
						),
					`intro {i} inside the machine`
				)
				-- 데크 위라면 밟는 면 위 2 이상
				local tier = Layout.tierAt(r)
				if tier then
					t.ok(p.pos.y >= Layout.TIERS[tier].top + 2, `intro {i} above tier {tier}`)
				end
			end
		end
	)
end
