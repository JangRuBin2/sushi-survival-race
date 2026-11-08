--!strict
-- m6-07 "연회상 쟁반 쓸기"(banquet-sweep): 대형 Survival(스폰 40). 벽 일정(구간·수직 두 장·빈 칸 규칙·풀 자리),
-- 벽 위치·닿음, 예고 줄, 바깥 줄 무너짐, 장식 예산·시야 상자, build 태그, 서버 start(가짜 Heartbeat).

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local H = require("./lib/LargeMapHarness")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local Layout = RobloxRequire.require(Shared.maps.BanquetSweepLayout)
local Logic = RobloxRequire.require(Shared.maps.BanquetSweepLogic)
local Art = RobloxRequire.require(Shared.maps.BanquetSweepArt)
local Map = RobloxRequire.require(Shared.maps.BanquetSweep)

local RCF: any = roblox.CFrame
local PATH = "src/shared/maps/BanquetSweep.luau"

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function harness(model: any): H.Harness
	return H.new(PATH, {
		BanquetSweepArt = Art,
		BanquetSweepLayout = Layout,
		BanquetSweepLogic = Logic,
		MapTypes = MapTypes,
	}, model)
end

local function rngFor(seed: number): any
	return H.newCtx({} :: any, RCF.new(), {}, seed).rng
end

local function sweep(at: number, axis: string, dir: number, kind: string, gaps: { number }): any
	return { at = at, axis = axis, dir = dir, kind = kind, gaps = gaps }
end

return function(t: Test.Test)
	t.test("등록: 풀에 든 대형 Survival, capacity 40·minPlayers 12·75초", function()
		t.eq(MapTypes.validate(Map), nil)
		t.eq(Maps.get("banquet-sweep"), Map)
		t.eq(Map.kind, "Survival")
		t.eq(Map.displayName, "연회상 쟁반 쓸기")
		t.eq(Map.timeLimit, 75)
		t.eq(Map.capacity, Config.Maps.LargeCapacity)
		t.eq(Map.minPlayers, Config.Maps.LargeMinPlayers)
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
		t.eq(#Layout.spawnPositions(), 40)
		for _, p in Layout.spawnPositions() do
			t.ok(math.abs(p.x) < Layout.INNER_HALF and math.abs(p.z) < Layout.INNER_HALF, "spawn on the inner board")
		end
	end)

	t.test(
		"일정: 4초 시작·15초 전 낮은 벽만·30초부터 수직 두 장·빈 칸 규칙·72초 뒤 없음 (시드 50개)",
		function()
			for seed = 1, 50 do
				local schedule = Logic.schedule(rngFor(seed))
				t.eq(schedule[1].at, Layout.FIRST_AT)
				local byAt: { [number]: { any } } = {}
				for i, s in schedule do
					if i > 1 then
						t.ok(s.at >= schedule[i - 1].at, "sorted")
					end
					t.ok(s.at <= Layout.LAST_AT)
					t.ok(s.dir == 1 or s.dir == -1)
					if s.at < 15 then
						t.eq(s.kind, "Low")
					end
					if s.kind == "High" then
						local want = if s.at >= Layout.SUDDEN_DEATH_AT then 1 else 2
						t.eq(#s.gaps, want)
						for _, lane in s.gaps do
							t.ok(lane >= 2 and lane <= Layout.LANES - 1, "gaps never on the collapsing lanes")
						end
						-- 어느 칸에서든 가장 가까운 빈 칸까지 3칸 안 (빈 칸 2개일 때)
						if #s.gaps == 2 then
							for lane = 1, Layout.LANES do
								local best = math.huge
								for _, g in s.gaps do
									best = math.min(best, math.abs(lane - g))
								end
								t.ok(best <= 3, `lane {lane} far from gaps`)
							end
						end
					else
						t.eq(#s.gaps, 0)
					end
					byAt[s.at] = byAt[s.at] or {}
					table.insert(byAt[s.at], s)
				end
				for at, group in byAt do
					if at >= 30 then
						t.eq(#group, 2, `two walls at {at}`)
						t.ok(group[1].axis ~= group[2].axis, "perpendicular")
						t.ok(group[1].kind ~= group[2].kind, "one low, one high")
					else
						t.eq(#group, 1)
					end
				end
			end
		end
	)

	t.test("풀: 동시에 움직이는 벽 ≤ 6, 자리 번호가 겹치지 않아요 (시드 50개)", function()
		for seed = 1, 50 do
			local schedule = Logic.schedule(rngFor(seed))
			for step = 0, 800 do
				local time = step * 0.1
				local slots = {}
				local active = Logic.active(schedule, time)
				t.ok(#active <= Layout.POOL)
				for _, a in active do
					local slot = Logic.slotOf(a.index)
					t.ok(not slots[slot], `slot {slot} reused at {time}`)
					slots[slot] = true
				end
			end
		end
		t.ok(Layout.POOL * Layout.LANES <= 60, "moving judgment parts ≤ 60")
	end)

	t.test("벽: 상 바깥 4에서 출발해 반대편 바깥 4까지, 낮은 벽 16·높은 벽 10", function()
		local s = sweep(10, "X", 1, "Low", {})
		t.eq(Logic.wallPos(s, 9.9), nil)
		t.eq(Logic.wallPos(s, 10), -Layout.WALL_START)
		t.ok(near(Logic.wallPos(s, 11) :: number, -Layout.WALL_START + 16, 1e-9))
		t.eq(Logic.wallPos(s, 10 + Logic.duration("Low")), nil)
		local back = sweep(0, "Z", -1, "High", { 3, 6 })
		t.eq(Logic.wallPos(back, 0), Layout.WALL_START)
		t.ok(near(Logic.duration("High"), 2 * Layout.WALL_START / 10, 1e-9))
		t.eq(Logic.sideOf(s), "XNeg")
		t.eq(Logic.sideOf(back), "ZPos")
	end)

	t.test(
		"닿음: 낮은 벽은 점프(발 3)로 넘고, 높은 벽은 빈 칸 가운데로만 지나가요",
		function()
			local low = sweep(0, "X", 1, "Low", {})
			t.ok(Logic.wallHit(low, 0, 1, 0, 0))
			t.ok(not Logic.wallHit(low, 0, 1, 0, 3.1), "jumped over")
			t.ok(not Logic.wallHit(low, 0, 3, 0, 0), "not touching yet")
			local high = sweep(0, "X", 1, "High", { 3, 6 })
			local gapCenter = Layout.laneCenter(3)
			t.ok(not Logic.wallHit(high, 0, 0, gapCenter, 0), "through the gap")
			t.ok(Logic.wallHit(high, 0, 0, gapCenter + 5, 0), "clipping the gap edge")
			t.ok(Logic.wallHit(high, 0, 0, Layout.laneCenter(4), 0))
			t.ok(Logic.wallHit(high, 0, 0, Layout.laneCenter(4), 10), "a tall wall cannot be jumped")
			t.eq(Logic.laneOf(-48), 1)
			t.eq(Logic.laneOf(47.9), 8)
			t.eq(Logic.laneOf(49), nil)
		end
	)

	t.test("예고·무너짐: 1.5초 전 그 변, 45초에 바깥 줄(1.5초 전 빨강)", function()
		local schedule = { sweep(10, "X", 1, "High", { 2, 5 }), sweep(10, "Z", -1, "Low", {}) }
		t.eq(next(Logic.warnings(schedule, 8.4)), nil)
		local w = Logic.warnings(schedule, 8.6)
		t.eq(w.XNeg, schedule[1])
		t.eq(w.ZPos, schedule[2])
		t.eq(next(Logic.warnings(schedule, 10)), nil)
		t.eq(Logic.edgeState(43.4), "Solid")
		t.eq(Logic.edgeState(43.6), "Warn")
		t.eq(Logic.edgeState(45), "Open")
		t.eq(Logic.boardHalf(44), 48)
		t.eq(Logic.boardHalf(45), 36)
		local outer = 0
		for i = 1, 8 do
			for j = 1, 8 do
				if Logic.isOuterTile(i, j) then
					outer += 1
				end
			end
		end
		t.eq(outer, 28)
	end)

	t.test(
		"장식: validate·Large 예산·시야 상자 비움·소개 카메라는 방 안·방바닥은 낙하선보다 10 아래",
		function()
			local decor = Art.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(Art.BUDGET, "Large")
			t.eq(MapKitLogic.checkBudget(decor, "Large"), nil)
			t.ok(MapKitLogic.count(decor) >= 400)
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
			for _, p in Art.introCamera() do
				t.ok(math.abs(p.pos.x) < Art.ROOM_HALF - 10 and math.abs(p.pos.z) < Art.ROOM_HALF - 10)
				t.ok(math.abs(p.pos.x) <= Layout.HALF + 40 and math.abs(p.pos.z) <= Layout.HALF + 40)
				t.ok(p.pos.y < Art.ROOM_FLOOR_Y + Art.WALL_HEIGHT - 10, "under the ceiling")
			end
			t.ok(Art.ROOM_FLOOR_Y <= Logic.fallLine() - 10)
		end
	)

	t.test("build: 스폰 40, 타일 64(바깥 28), 벽 풀 48·예고 32 충돌 없음", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("banquet-sweep", origin)
		t.eq(#model:FindFirstChild("Spawns"):GetChildren(), 40)
		local tags: { [string]: number } = {}
		local outer = 0
		for _, d in model:GetDescendants() do
			for _, tag in d:GetTags() do
				tags[tag] = (tags[tag] or 0) + 1
			end
			if d:IsA("BasePart") and (d:HasTag("BanquetWall") or d:HasTag("BanquetWarn")) then
				t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name)
			end
			if d:IsA("BasePart") and d:HasTag("BanquetWarn") then
				t.eq(d.Transparency, 1)
			end
			if d:IsA("BasePart") and d:HasTag("BanquetTile") then
				t.ok(d.CanCollide)
				if d:GetAttribute("Outer") then
					outer += 1
				end
			end
		end
		t.eq(tags.BanquetTile, 64)
		t.eq(outer, 28)
		t.eq(tags.BanquetWall, Layout.POOL * Layout.LANES)
		t.eq(tags.BanquetWarn, 4 * Layout.LANES)
	end)

	t.test(
		"서버 모듈: 태그는 ctx.model 하위만, MoveExempt는 넉백 한 곳, 일정은 ctx.rng로",
		function()
			local source = fs.readFile(PATH)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil)
			t.ok(string.find(source, "Logic.schedule(ctx.rng)", 1, true) ~= nil)
			local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
			t.eq(marks, 1)
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function") then
					local ok = string.match(line, "= require%(") ~= nil
						or string.match(line, '= "[^"]*"$') ~= nil
						or string.match(line, "^local [%u_]+ = %-?[%d%.]+") ~= nil
						or string.match(line, "^local map: MapTypes") ~= nil
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	t.test(
		"start: 예고 줄이 켜지고(빈 칸 초록) 벽이 움직이며, 닿으면 진행 방향으로 넘어져요",
		function()
			local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local model = H.build("banquet-sweep", origin)
			local h = harness(model)
			local schedule = Logic.schedule(rngFor(7)) -- 같은 시드 → start와 같은 일정
			local first = schedule[1]
			-- 첫 벽이 지나갈 자리에 사람 하나
			local pos = Logic.wallPos(first, first.at + 3) :: number
			local x = if first.axis == "X" then pos else 0
			local z = if first.axis == "Z" then pos else 0
			local racer = H.fakeRacer(origin, x, Layout.FOOT_OFFSET, z)
			local falling = H.fakeRacer(origin, 0, Logic.fallLine() - 0.1, 0)
			local ctx = H.newCtx(model, origin, { racer, falling }, 7)
			h.setClock(0)
			h.map.start(ctx)
			-- 예고 (1초 전)
			h.setClock(first.at - 1)
			h.fire(1 / 60)
			t.ok(ctx.eliminated[falling])
			local side = Logic.sideOf(first)
			local lit = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("BanquetWarn") then
					if d:GetAttribute("Side") == side then
						t.ok(d.Transparency < 1)
						lit += 1
					else
						t.eq(d.Transparency, 1)
					end
				end
			end
			t.eq(lit, Layout.LANES)
			t.ok(table.find(h.sounds, "ChopstickWarn") ~= nil)
			-- 벽이 그 자리에 오면 닿음
			h.setClock(first.at + 3)
			h.fire(1 / 60)
			t.eq(#h.marks, 1)
			t.eq(h.marks[1].seconds, Layout.KNOCK_EXEMPT)
			local v = origin:VectorToObjectSpace(racer.root.AssemblyLinearVelocity)
			local push = if first.axis == "X" then v.X else v.Z
			t.ok(near(push, first.dir * Layout.KNOCK, 1e-3), `pushed along the sweep {push}`)
			t.ok(near(v.Y, Layout.KNOCK_UP, 1e-3))
			t.ok(racer.humanoid.PlatformStand)
			-- 그 벽 칸 하나는 벽 자리에
			local wall = model:FindFirstChild("Walls"):FindFirstChild(string.format("Wall%d_%d", Logic.slotOf(1), 4))
			local rel = origin:PointToObjectSpace(wall.CFrame.Position)
			t.ok(near(if first.axis == "X" then rel.X else rel.Z, pos, 1e-3))
			t.ok(h.bulk > 0)
		end
	)

	t.test("start: 45초에 바깥 줄이 무너지고 예고 줄이 새 가장자리로", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("banquet-sweep", origin)
		local h = harness(model)
		local ctx = H.newCtx(model, origin, {}, 3)
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(44)
		h.fire(1 / 60)
		local warnColor = roblox.Color3.fromRGB(
			Art.JUDGE_COLORS.collapseWarn.r,
			Art.JUDGE_COLORS.collapseWarn.g,
			Art.JUDGE_COLORS.collapseWarn.b
		)
		local tiles = model:FindFirstChild("Tiles")
		t.eq(tiles:FindFirstChild("Tile1_4").Color, warnColor)
		t.ok(tiles:FindFirstChild("Tile1_4").CanCollide)
		h.setClock(45.1)
		h.fire(1 / 60)
		t.ok(not tiles:FindFirstChild("Tile1_4").CanCollide)
		t.ok(not tiles:FindFirstChild("Tile8_8").CanCollide)
		t.ok(tiles:FindFirstChild("Tile2_2").CanCollide, "inner tiles stay")
		t.ok(table.find(h.sounds, "TileVanish") ~= nil)
		local strip = model:FindFirstChild("Warnings"):FindFirstChild("WarnXNeg_4")
		local rel = origin:PointToObjectSpace(strip.CFrame.Position)
		t.ok(near(rel.X, -(Layout.INNER_HALF - 1.5), 1e-3))
	end)
end
