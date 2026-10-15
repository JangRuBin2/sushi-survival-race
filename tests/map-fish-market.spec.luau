--!strict
-- m5-37 Survival 맵 "수산시장" (docs/specs/m5-37-map-fish-market.md): 상자 격자·스폰, Ice 태그 금지·충돌 파츠,
-- 시간 제한·얼음 블록 위치·개수·같은 줄 금지, 얼음 맞음, 생선 일정·과녁·넉백, 아트 예산·시야 상자,
-- 그리고 실제 start를 가짜 Heartbeat·가짜 시계로 75초 돌리는 연기 시험.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.FishMarketLayout)
local Logic = RobloxRequire.require(Shared.maps.FishMarketLogic)
local Art = RobloxRequire.require(Shared.maps.FishMarketArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

-- 결정적 가짜 rng (NextNumber·NextInteger)
local function fakeRng(seed: number)
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end
	return {
		NextInteger = function(_, min: number, max: number): number
			return min + step() % (max - min + 1)
		end,
		NextNumber = function(_): number
			return step() / 2147483648
		end,
	}
end

local function approx(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local function overlaps(a: any, b: any): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

local function inFolder(model: any, d: any, folderName: string): boolean
	local parent = d.Parent
	while parent and parent ~= model do
		if parent.Name == folderName then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function isNeighbor(pair: any): boolean
	local dr = math.abs(pair.a.row - pair.b.row)
	local dc = math.abs(pair.a.col - pair.b.col)
	return dr + dc == 1
end

---------------------------------------------------------------- 연기 시험 환경
-- 실제 FishMarket.luau 소스를 Shims 전역 + 가짜 game·task·os로 불러요. 시간은 우리가 움직여요.
type Sim = {
	map: any,
	clock: number,
	heartbeat: { () -> () },
	delays: { { at: number, fn: () -> () } },
	sfx: { string },
	exempts: { number },
	model: any,
}

local function newSim(): Sim
	local sim: Sim = { map = nil, clock = 1000, heartbeat = {}, delays = {}, sfx = {}, exempts = {}, model = nil }
	local fakeRun = {
		Heartbeat = {
			Connect = function(_, fn: () -> ())
				table.insert(sim.heartbeat, fn)
				local connection = {}
				function connection.Disconnect()
					local i = table.find(sim.heartbeat, fn)
					if i then
						table.remove(sim.heartbeat, i)
					end
				end
				return connection
			end,
		},
	}
	local fakeCollection = {
		GetTagged = function(_, tag: string): { any }
			local list = {}
			for _, d in sim.model:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(list, d)
				end
			end
			return list
		end,
		AddTag = function(_, inst: any, tag: string)
			inst:AddTag(tag)
		end,
	}
	local fakeTask = {
		delay = function(seconds: number, fn: () -> ()): any
			local entry = { at = sim.clock + seconds, fn = fn }
			table.insert(sim.delays, entry)
			return entry
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return {}
		end,
		wait = function(): number
			error("task.wait is not allowed in fish-market start")
		end,
	}
	local fakeMapSfx = {
		play = function(_part: any, cue: string)
			table.insert(sim.sfx, cue)
		end,
	}
	local fakeMoveExempt = {
		mark = function(_character: any, seconds: number?)
			table.insert(sim.exempts, seconds or -1)
		end,
	}
	local fakeMapKit = {
		makeEmitter = function(_name: string, _rate: number?): any
			return { Enabled = true, Emit = function() end }
		end,
	}
	local env = table.clone(Shims.globals)
	env.game = {
		GetService = function(_, name: string): any
			if name == "RunService" then
				return fakeRun
			elseif name == "CollectionService" then
				return fakeCollection
			end
			error(`unexpected service {name}`)
		end,
	}
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return sim.clock
		end,
	}
	env.script = RShared.maps.FishMarket
	env.require = function(target: any): any
		local name = target.Name
		if name == "MapSfx" then
			return fakeMapSfx
		elseif name == "MoveExempt" then
			return fakeMoveExempt
		elseif name == "MapKit" then
			return fakeMapKit
		end
		return Shims.require(target)
	end
	-- lune 인스턴스는 Position 읽기를 못 해요 (CFrame에서 읽어요)
	local source = string.gsub(fs.readFile("src/shared/maps/FishMarket.luau"), "root%.Position", "root.CFrame.Position")
	sim.map = luau.load(source, { debugName = "FishMarket(sim)", environment = env })()
	return sim
end

local function stepSim(sim: Sim, dt: number)
	sim.clock += dt
	local i = 1
	while i <= #sim.delays do
		local entry = sim.delays[i]
		if entry.at <= sim.clock then
			table.remove(sim.delays, i)
			entry.fn()
		else
			i += 1
		end
	end
	for _, fn in table.clone(sim.heartbeat) do
		fn()
	end
end

local function makeRacer(name: string, origin: any, x: number, y: number, z: number): (any, any, any)
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = origin * RCF.new(x, y, z)
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Parent = character
	local player = { Name = name, Character = character }
	return player, root, humanoid
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: fish-market은 Survival 맵, 이름·규칙 확정값, lighting = Art.LIGHTING, 풀에 들어감",
		function()
			local map = Maps.get("fish-market")
			t.eq(MapTypes.validate(map), nil)
			t.eq(map.kind, "Survival")
			t.eq(map.displayName, "수산시장")
			t.eq(map.rule, "떨어지는 생선과 밀려오는 얼음을 피해 상자 위에서 버텨요!")
			t.ok(map.lighting == Art.LIGHTING, "lighting = Art.LIGHTING")
			t.ok(map.inPool ~= false, "inPool = false 줄이 지워졌어야 해요")
			local pooled = false
			for _, info in Maps.infos() do
				if info.id == "fish-market" then
					pooled = true
				end
			end
			t.ok(pooled, "fish-market is in the random pool")
		end
	)

	t.test("AC1: 상자 36개 (Row·Col 0~5, 10 × 10, 물길 5 → 전체 85)", function()
		local crates = Layout.crates()
		t.eq(#crates, 36)
		t.eq(Layout.CRATE_SIZE, 10)
		t.eq(Layout.GAP, 5)
		t.eq(Layout.SPAN, 85)
		local seen: { [string]: boolean } = {}
		for _, crate in crates do
			t.ok(crate.row >= 0 and crate.row <= 5 and crate.col >= 0 and crate.col <= 5, crate.key)
			t.ok(not seen[crate.key], `duplicate {crate.key}`)
			seen[crate.key] = true
			-- 이웃 상자 중심 간격 15 (상자 10 + 물길 5)
			if crate.col < 5 then
				t.eq(Layout.colX(crate.col + 1) - Layout.colX(crate.col), 15)
			end
		end
		t.eq(Layout.colX(5) - Layout.colX(0) + Layout.CRATE_SIZE, 85)
		t.eq(Layout.rowZ(0) - Layout.rowZ(5) + Layout.CRATE_SIZE, 85)
		-- 상자 위 / 물길 / 밖
		t.eq({ Layout.crateAt(Layout.colX(2) + 4.9, Layout.rowZ(3) - 4.9) }, { 3, 2 })
		t.eq({ Layout.crateAt(Layout.colX(2) + 5.1, Layout.rowZ(3)) }, {})
		t.eq({ Layout.crateAt(Layout.colX(0) - 5.1, Layout.rowZ(0)) }, {})
		t.eq({ Layout.crateAt(Layout.colX(5) + 5.5, Layout.rowZ(5)) }, {})
	end)

	t.test(
		"AC1: build — 상자 파츠 36개(태그·Row·Col·크기·윗면 0), 스폰 24개가 가운데 4 × 4 상자 위 서로 3 이상",
		function()
			local origin = RCF.new(2000, 300, 0)
			local model = RMaps.get("fish-market").build(origin)
			local crates = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("MarketCrate") then
					table.insert(crates, d)
				end
			end
			t.eq(#crates, 36)
			for _, crate in crates do
				local row, col = crate:GetAttribute("Row"), crate:GetAttribute("Col")
				t.ok(type(row) == "number" and type(col) == "number", "Row·Col")
				t.ok(crate.Anchored and crate.CanCollide, `{crate.Name} anchored + collide`)
				t.ok(
					approx(crate.Size.X, 10) and approx(crate.Size.Y, 6) and approx(crate.Size.Z, 10),
					"size 10×6×10"
				)
				local localPos = origin:PointToObjectSpace(crate.CFrame.Position)
				t.ok(approx(localPos.Y + crate.Size.Y / 2, 0), "top y 0")
				t.ok(approx(localPos.X, Layout.colX(col)) and approx(localPos.Z, Layout.rowZ(row)), "position")
			end
			local spawns = model:FindFirstChild("Spawns"):GetChildren()
			t.eq(#spawns, 24)
			local perCrate: { [string]: number } = {}
			for i, s in spawns do
				local p = origin:PointToObjectSpace(s.CFrame.Position)
				local row, col = Layout.crateAt(p.X, p.Z)
				t.ok(row ~= nil and col ~= nil, `{s.Name} on a crate`)
				t.ok(row >= 1 and row <= 4 and col >= 1 and col <= 4, `{s.Name} in the middle 4 × 4`)
				t.ok(p.Y > 0 and p.Y < 1, `{s.Name} just above the top`)
				local key = Layout.crateKey(row, col)
				perCrate[key] = (perCrate[key] or 0) + 1
				for j = i + 1, #spawns do
					local d = (s.CFrame.Position - spawns[j].CFrame.Position).Magnitude
					t.ok(d >= 3, `{s.Name}/{spawns[j].Name} too close ({d})`)
				end
			end
			local count = 0
			for _, n in perCrate do
				count += 1
				t.ok(n == 1 or n == 2, "1~2 spawns per crate")
			end
			t.eq(count, 16)
		end
	)

	---------------------------------------------------------------- AC2
	t.test(
		"AC2: Ice 태그 없음, 상자 밖에 충돌 있는 파츠 없음 (얼음 블록·스폰·장식 모두 충돌 없음)",
		function()
			local origin = RCF.new()
			local model = RMaps.get("fish-market").build(origin)
			local iceBlocks = 0
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					t.ok(tag ~= "Ice", `{d:GetFullName()} has the Ice tag`)
				end
				if d:IsA("BasePart") then
					if d:HasTag("MarketIceBlock") then
						iceBlocks += 1
					end
					if d.CanCollide then
						t.ok(d:HasTag("MarketCrate"), `{d:GetFullName()} collides but is not a crate`)
					end
				end
			end
			t.eq(iceBlocks, 4)
			-- 소스에도 Ice 태그를 다는 줄이 없어요 (런타임 생선·표지 포함)
			for _, path in
				{
					"src/shared/maps/FishMarket.luau",
					"src/shared/maps/FishMarketLogic.luau",
					"src/shared/maps/FishMarketArt.luau",
				}
			do
				local source = fs.readFile(path)
				t.ok(string.find(source, '"Ice")', 1, true) == nil, `{path} tags Ice`)
				t.ok(string.find(source, 'ICE_TAG = "Ice"', 1, true) == nil, `{path} Ice tag constant`)
			end
		end
	)

	---------------------------------------------------------------- AC3
	t.test("AC3: timeLimit 75, iceCount 경계", function()
		t.eq(Maps.get("fish-market").timeLimit, 75)
		t.eq(Logic.iceCount(0), 0)
		t.eq(Logic.iceCount(4.9), 0)
		t.eq(Logic.iceCount(5), 2)
		t.eq(Logic.iceCount(24.9), 2)
		t.eq(Logic.iceCount(25), 3)
		t.eq(Logic.iceCount(45), 4)
		t.eq(Logic.iceCount(70), 4)
	end)

	t.test(
		"AC3: icePosition — 0초 x −50, 8초 +50, 8~10초 멈춤, 10초부터 반대로 (60초부터 6.7초 이동)",
		function()
			local block = Logic.newIceBlock(2, 1, 0)
			local row, x = Logic.icePosition(block, 0)
			t.eq(row, 2)
			t.ok(approx(x, -50), `t=0 x {x}`)
			_, x = Logic.icePosition(block, 4)
			t.ok(approx(x, 0), `t=4 x {x}`)
			_, x = Logic.icePosition(block, 8)
			t.ok(approx(x, 50), `t=8 x {x}`)
			_, x = Logic.icePosition(block, 9.99)
			t.ok(approx(x, 50), `t=9.99 x {x}`)
			t.eq(Logic.iceState(block, 9).phase, "Pause")
			t.eq(Logic.iceState(block, 10).phase, "Move")
			t.eq(Logic.iceState(block, 10).dir, -1)
			_, x = Logic.icePosition(block, 11)
			t.ok(approx(x, 50 - 12.5), `t=11 x {x}`)
			_, x = Logic.icePosition(block, 18)
			t.ok(approx(x, -50), `t=18 x {x}`)
			-- 출발 전(경고 중)은 출발 끝에서 대기
			local waiting = Logic.newIceBlock(1, -1, 5)
			row, x = Logic.icePosition(waiting, 3.5)
			t.eq(row, 1)
			t.ok(approx(x, 50), "waits at +50 before moving −X")
			t.eq(Logic.iceState(waiting, 3.5).phase, "Wait")
			-- 서든데스: 60초부터 출발한 다리는 6.7초
			t.ok(approx(Logic.travelTime(59.9), 8), "8s before 60")
			t.ok(approx(Logic.travelTime(60), 100 / 15), "6.7s from 60")
			local late = Logic.newIceBlock(0, 1, 60)
			_, x = Logic.icePosition(late, 60 + 100 / 15 / 2)
			t.ok(approx(x, 0), `late half-way x {x}`)
			t.eq(Logic.iceState(late, 60 + 100 / 15 + 0.01).phase, "Pause")
			-- 옆 줄로 옮기면 멈춘 동안 row가 소수로 미끄러져 다음 다리에서 새 줄
			local shifting = Logic.newIceBlock(2, 1, 0)
			shifting.rows[2] = 3
			row = Logic.icePosition(shifting, 8.2)
			t.eq(row, 2)
			row = Logic.icePosition(shifting, 9)
			t.ok(row > 2 and row < 3, `sliding row {row}`)
			row, x = Logic.icePosition(shifting, 10.5)
			t.eq(row, 3)
			t.ok(x < 50, "moving back on the new row")
		end
	)

	t.test(
		"AC3: 75초 시뮬레이션(0.1초) — 같은 줄에 블록 2개가 동시에 없고, 개수는 iceCount를 따라요",
		function()
			for seed = 1, 40 do
				local director = Logic.newIceDirector()
				local rng = fakeRng(seed)
				local shifts, spawns = 0, 0
				for i = 0, 750 do
					local now = i * 0.1
					for _, ev in Logic.stepIce(director, now, rng) do
						t.ok(ev.row >= 0 and ev.row < Layout.GRID, "event row in grid")
						if ev.kind == "Shift" then
							shifts += 1
						else
							spawns += 1
						end
					end
					t.eq(#director.blocks, Logic.iceCount(now), `seed {seed} t {now} count`)
					local rows = {}
					for _, block in director.blocks do
						local row, x = Logic.icePosition(block, now)
						t.ok(row >= 0 and row <= Layout.GRID - 1, "row in grid")
						t.ok(x >= -50 - 1e-6 and x <= 50 + 1e-6, "x in range")
						table.insert(rows, row)
					end
					for a = 1, #rows do
						for b = a + 1, #rows do
							t.ok(
								math.abs(rows[a] - rows[b]) >= 1 - 1e-6,
								`seed {seed} t {now}: rows {rows[a]} {rows[b]}`
							)
						end
					end
				end
				t.eq(spawns, 4, `seed {seed} spawns`)
				t.ok(shifts >= 1, `seed {seed} at least one row change`)
			end
		end
	)

	---------------------------------------------------------------- AC4
	t.test("AC4: iceHit — 블록 상자(± 5) 안 · 발 < 7만 맞음, 블록 높이 7 > 점프 6.4", function()
		t.ok(Logic.iceHit(0, 0, 0), "center")
		t.ok(Logic.iceHit(4.9, -4.9, 6.9), "edge, foot 6.9")
		t.ok(Logic.iceHit(5, 5, 0), "margin edge")
		t.ok(not Logic.iceHit(0, 0, 7), "foot 7 clears")
		t.ok(not Logic.iceHit(0, 0, 8), "foot 8 clears")
		t.ok(not Logic.iceHit(5.1, 0, 0), "outside x")
		t.ok(not Logic.iceHit(0, -5.1, 0), "outside z")
		t.ok(Logic.ICE_HEIGHT > Logic.JUMP_HEIGHT, "cannot jump over")
		t.eq(Logic.ICE_HEIGHT, 7)
		t.eq(Logic.ICE_KNOCK_HORIZONTAL, 30)
		t.eq(Logic.ICE_KNOCK_UP, 12)
		t.eq(Logic.ICE_MOVE_EXEMPT, 1.2)
		t.eq(Logic.ICE_COOLDOWN, 0.8)
	end)

	---------------------------------------------------------------- AC5
	t.test("AC5: fishWave 표", function()
		t.eq(Logic.fishWave(7.9), nil)
		t.eq(Logic.fishWave(8), { interval = 8, count = 1 })
		t.eq(Logic.fishWave(29.9), { interval = 8, count = 1 })
		t.eq(Logic.fishWave(30), { interval = 6, count = 1 })
		t.eq(Logic.fishWave(45), { interval = 4.5, count = 2 })
		t.eq(Logic.fishWave(60), { interval = 4, count = 2 })
		t.eq(Logic.fishWave(74.9), { interval = 4, count = 2 })
	end)

	t.test("AC5: cratePairs 60쌍 모두 이웃", function()
		local pairs = Logic.cratePairs(Layout.crates())
		t.eq(#pairs, 60)
		for _, pair in pairs do
			t.ok(isNeighbor(pair), "neighbor")
			if pair.axis == "X" then
				t.eq(pair.a.row, pair.b.row)
			else
				t.eq(pair.a.col, pair.b.col)
			end
		end
	end)

	t.test(
		"AC5: pickFishTarget 1,000번 — 늘 이웃 쌍, 누운 생선 상자 피함, 약 60%가 레이서 가장 많은 쌍",
		function()
			local crates = Layout.crates()
			-- 레이서 5명이 (2,2)·(2,3)에 몰려 있어요 → 가장 많은 쌍은 (2,2)-(2,3) 하나
			local racers = {
				{ x = Layout.colX(2), z = Layout.rowZ(2) },
				{ x = Layout.colX(2) + 2, z = Layout.rowZ(2) },
				{ x = Layout.colX(3), z = Layout.rowZ(2) },
				{ x = Layout.colX(3) - 2, z = Layout.rowZ(2) + 2 },
				{ x = Layout.colX(0), z = Layout.rowZ(5) },
				{ x = Layout.colX(0) - 7.5, z = Layout.rowZ(5) }, -- 물길 (세지 않아요)
			}
			local lying = { [Layout.crateKey(4, 4)] = true, [Layout.crateKey(4, 5)] = true }
			local rng = fakeRng(7)
			local best = 0
			for _ = 1, 1000 do
				local pair = Logic.pickFishTarget(rng, racers, crates, lying)
				t.ok(pair ~= nil, "pair")
				t.ok(isNeighbor(pair), "neighbor pair")
				for _, cell in { pair.a, pair.b } do
					t.ok(not lying[Layout.crateKey(cell.row, cell.col)], "avoids lying fish crates")
				end
				local isBest = pair.a.row == 2 and pair.b.row == 2 and pair.a.col == 2 and pair.b.col == 3
				if isBest then
					best += 1
				end
			end
			t.ok(best >= 530 and best <= 670, `best pair {best}/1000 (60% ± 7%)`)
			-- 모든 상자가 막히면 nil
			local all = {}
			for _, crate in crates do
				all[crate.key] = true
			end
			t.eq(Logic.pickFishTarget(fakeRng(1), racers, crates, all), nil)
		end
	)

	---------------------------------------------------------------- AC6
	t.test("AC6: fishKnockback — 과녁 상자 위 36 + 22 수직, 몸에서 6 안 18 + 12, 그 밖 nil", function()
		local k = Logic.fishKnockback("X", { x = 0, y = 0, z = 2 })
		t.eq(k, { dirX = 0, dirZ = 1, horizontal = 36, up = 22 })
		k = Logic.fishKnockback("X", { x = 12, y = 0, z = -3 })
		t.eq(k, { dirX = 0, dirZ = -1, horizontal = 36, up = 22 })
		k = Logic.fishKnockback("Z", { x = 2, y = 0, z = -12 })
		t.eq(k, { dirX = 1, dirZ = 0, horizontal = 36, up = 22 })
		k = Logic.fishKnockback("Z", { x = -4, y = 0, z = 0 })
		t.eq(k, { dirX = -1, dirZ = 0, horizontal = 36, up = 22 })
		-- 옆 줄 상자 (몸 가장자리 3에서 5.5) → 약한 넉백, 몸에서 멀어지게
		k = Logic.fishKnockback("X", { x = 0, y = 0, z = 8.5 })
		t.eq(k, { dirX = 0, dirZ = 1, horizontal = 18, up = 12 })
		-- 긴 축 끝 너머 (몸 끝 10에서 4) → 약한 넉백, 긴 축 방향
		k = Logic.fishKnockback("X", { x = -14, y = 0, z = 0 })
		t.eq(k, { dirX = -1, dirZ = 0, horizontal = 18, up = 12 })
		-- 6 밖
		t.eq(Logic.fishKnockback("X", { x = 0, y = 0, z = 9.5 }), nil)
		t.eq(Logic.fishKnockback("Z", { x = 0, y = 0, z = 17 }), nil)
		-- 대각선은 단위 벡터
		k = Logic.fishKnockback("X", { x = 13, y = 0, z = 6 })
		t.ok(k ~= nil and approx(k.dirX * k.dirX + k.dirZ * k.dirZ, 1), "unit diagonal")
	end)

	t.test("AC6: flopKnockback — 몸에서 4 안(위 포함) 16 + 16, 밖 nil, 상수", function()
		t.eq(Logic.flopKnockback("X", { x = 0, y = 5, z = 0 }), { dirX = 0, dirZ = 1, horizontal = 16, up = 16 })
		t.eq(Logic.flopKnockback("X", { x = 0, y = 0, z = -6.9 }), { dirX = 0, dirZ = -1, horizontal = 16, up = 16 })
		t.eq(Logic.flopKnockback("Z", { x = 0, y = 0, z = 13.5 }), { dirX = 0, dirZ = 1, horizontal = 16, up = 16 })
		t.eq(Logic.flopKnockback("X", { x = 0, y = 0, z = 7.5 }), nil)
		t.eq(Logic.flopKnockback("X", { x = 0, y = 9.5, z = 0 }), nil)
		t.eq(Logic.FISH_MOVE_EXEMPT, 1.5)
		t.eq(Logic.ICE_MOVE_EXEMPT, 1.2)
		t.eq(Logic.FISH_COOLDOWN, 0.6)
		t.eq(Logic.KNOCK_HOLD, 0.12)
		t.eq(Logic.PLATFORM_STAND, 0.8)
		t.eq(Logic.FISH_WARN, 2)
		t.eq(Logic.FISH_LIE, 5)
		t.eq(Logic.FISH_FLOP_AT, 2.5)
		t.eq(Logic.MAX_LYING, 2)
		t.eq(Logic.FISH_SIGN_HEIGHT, 30)
	end)

	---------------------------------------------------------------- AC7
	t.test(
		"AC7: 장식 validate·Extended 예산, 시야 상자와 안 겹침, 얼음 조각 윗면 ≤ −2, 배경 바닥 ≤ −50",
		function()
			local decor = Art.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(Art.BUDGET, "Extended")
			t.eq(MapKitLogic.checkBudget(decor, "Extended"), nil)
			local count = MapKitLogic.count(decor)
			t.ok(count >= 700 and count <= 1300, `decor parts {count} (target 700~1300)`)
			t.ok(MapKitLogic.countParticles(decor) >= 6, "particles ≥ 6")
			t.ok(MapKitLogic.countAnimated(decor) >= 3, "anim ≥ 3")
			t.eq(MapKitLogic.countShadowedLights(decor), 1)
			local sight = Art.courseVolume()
			local chunks, floors = 0, 0
			for _, spec in decor do
				local b = MapKitLogic.bounds({ spec })
				t.ok(not overlaps(b, sight), `{spec.name} overlaps the sight box`)
				if spec.name == "IceChunk" then
					chunks += 1
					t.ok(b.max.y <= -2 + 1e-6, `IceChunk top {b.max.y}`)
				elseif spec.name == "MarketFloor" then
					floors += 1
					t.ok(b.max.y <= -50, `MarketFloor top {b.max.y}`)
				end
				-- 상자·얼음 블록·생선·⚠ 표지는 장식이 아니라 anim도 없어요; 장식 쪽 이름에도 없어요
				t.ok(not (spec.anim and (string.find(spec.name, "Crate") or string.find(spec.name, "Ice"))), spec.name)
			end
			t.ok(chunks >= 10, "ice chunks")
			t.eq(floors, 1)
			-- 큰 반투명 판은 물 표면 1장뿐
			for _, spec in decor do
				local longest = math.max(spec.size.x, spec.size.y, spec.size.z)
				local seeThrough = (spec.transparency or 0) > 0 and (spec.transparency or 0) < 1
				if seeThrough and longest >= 40 then
					t.eq(spec.name, "Water", "only the water surface is a big translucent sheet")
				end
			end
		end
	)

	t.test("AC7: 소개 카메라 5점, 출발 자리로 끝나요", function()
		local points = Art.introCamera()
		t.eq(#points, 5)
		local last = points[#points]
		t.ok(last.pos.z > Layout.rowZ(0), "last point behind the start side")
	end)

	---------------------------------------------------------------- 연기 시험 (실제 start)
	t.test(
		"smoke: 실제 start를 75초 돌려요 — 얼음 4개·생선·넉백·낙하 탈락, 상자 그대로, 정리",
		function()
			local sim = newSim()
			local origin = RCF.new(2000, 300, 0)
			local model = RMaps.get("fish-market").build(origin)
			sim.model = model
			local cleanupItems: { any } = {}
			local cleanup = {
				add = function(self: any, item: any)
					table.insert(cleanupItems, item)
					return item
				end,
			}
			local active = true
			local eliminated: { [any]: boolean } = {}
			-- 레이서 6명: 상자 위 (같은 줄·이웃 상자에 몰리게) + 1명은 물길에 빠져 있어요
			local racers = {}
			local roots = {}
			for i, cell in { { 1, 1 }, { 1, 2 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 2, 3 } } do
				local player, root = makeRacer(`P{i}`, origin, Layout.colX(cell[2]), 3, Layout.rowZ(cell[1]))
				table.insert(racers, player)
				roots[player] = root
			end
			local swimmer = makeRacer("Swimmer", origin, Layout.colX(0) + 7.5, -6.5, Layout.rowZ(0))
			table.insert(racers, swimmer)
			local ctx = {
				model = model,
				origin = origin,
				rng = Shims.globals.Random.new(42),
				targetCount = 1,
				cleanup = cleanup,
				isActive = function()
					return active
				end,
				getRacers = function()
					local list = {}
					for _, p in racers do
						if not eliminated[p] then
							table.insert(list, p)
						end
					end
					return list
				end,
				pass = function() end,
				eliminate = function(p: any)
					eliminated[p] = true
				end,
			}
			sim.map.start(ctx)
			t.eq(#sim.heartbeat, 1, "one Heartbeat connection")
			local maxFish, maxSigns = 0, 0
			local sawLinear = false
			local iceMoved = false
			local core1 = model:FindFirstChild("IceBlocks"):FindFirstChild("IceBlock1"):FindFirstChild("Core")
			local startCF = core1.CFrame
			for _ = 1, 750 do
				stepSim(sim, 0.1)
				local hazards = model:FindFirstChild("Hazards")
				local fish, signs = 0, 0
				for _, d in hazards:GetChildren() do
					if d.Name == "MarketFish" then
						fish += 1
					elseif d.Name == "FishWarn" then
						signs += 1
					end
				end
				maxFish = math.max(maxFish, fish)
				maxSigns = math.max(maxSigns, signs)
				for _, root in roots do
					if root:FindFirstChild("FishMarketLaunch") then
						sawLinear = true
					end
				end
				if (core1.CFrame.Position - startCF.Position).Magnitude > 1 then
					iceMoved = true
				end
				-- 얼음 블록은 상자 격자 위에서는 늘 줄 높이로만 있어요 (경고 중에 격자를 가로질러 날지 않아요)
				for _, block in model:FindFirstChild("IceBlocks"):GetChildren() do
					local p = origin:PointToObjectSpace(block:FindFirstChild("Core").CFrame.Position)
					if math.abs(p.X) < Layout.SPAN / 2 + Logic.ICE_SIZE / 2 then
						t.ok(approx(p.Y, Logic.ICE_HEIGHT / 2, 1e-3), `{block.Name} over the grid at y {p.Y}`)
					end
				end
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and d.CanCollide then
						t.ok(d:HasTag("MarketCrate") or d:HasTag("MarketFish"), `{d:GetFullName()} collides`)
					end
				end
			end
			t.ok(eliminated[swimmer], "racer in the water is eliminated")
			for _, p in racers do
				if p ~= swimmer then
					t.ok(not eliminated[p], `{p.Name} standing on a crate is safe`)
				end
			end
			t.ok(iceMoved, "ice blocks slide")
			t.ok(maxFish >= 2, `fish dropped (max {maxFish})`)
			t.ok(maxSigns >= 1, "⚠ signs shown")
			t.ok(sawLinear, "knockback LinearVelocity applied")
			local sawIceExempt, sawFishExempt = false, false
			for _, s in sim.exempts do
				if s == 1.2 then
					sawIceExempt = true
				elseif s == 1.5 then
					sawFishExempt = true
				end
			end
			t.ok(sawIceExempt, "ice knockback marks MoveExempt 1.2")
			t.ok(sawFishExempt, "fish knockback marks MoveExempt 1.5")
			for _, cue in { "IceBlockSlide", "MarketFishWarn", "MarketFishSlam" } do
				t.ok(table.find(sim.sfx, cue) ~= nil, `cue {cue}`)
			end
			-- 상자는 그대로 36개, 모두 충돌
			local crates = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("MarketCrate") then
					crates += 1
					t.ok(d.CanCollide and d.Transparency == 0, "crate unchanged")
				end
			end
			t.eq(crates, 36)
			-- 라운드가 끝나면 판정 없음
			active = false
			local before = #sim.sfx
			stepSim(sim, 5)
			t.eq(#sim.sfx, before, "no hazards after the round ends")
			-- 정리: Hazards 폴더가 cleanup에 있고, PlatformStand 되돌리는 함수도 있어요
			local hazardsFolder = model:FindFirstChild("Hazards")
			local hasHazards, hasFn = false, false
			for _, item in cleanupItems do
				if item == hazardsFolder then
					hasHazards = true
				elseif type(item) == "function" then
					hasFn = true
				end
			end
			t.ok(hasHazards and hasFn, "cleanup has the hazards folder and the PlatformStand reset")
		end
	)
end
