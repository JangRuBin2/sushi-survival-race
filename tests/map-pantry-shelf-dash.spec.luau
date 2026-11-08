--!strict
-- m6-05 "팬트리 선반 대질주"(pantry-shelf-dash): 대형 Race(스폰 40). 선반 섬 틈·길 이어짐, 바람 박자, 통조림 일정,
-- 장식 예산·시야 상자, build 태그, 서버 start(가짜 Heartbeat): 바람 줄무늬·옆 밀기, 통조림 넉백, 낙하·결승.

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
local Layout = RobloxRequire.require(Shared.maps.PantryShelfDashLayout)
local Logic = RobloxRequire.require(Shared.maps.PantryShelfDashLogic)
local Art = RobloxRequire.require(Shared.maps.PantryShelfDashArt)
local Map = RobloxRequire.require(Shared.maps.PantryShelfDash)

local RCF: any = roblox.CFrame
local EPS = 1e-6
local PATH = "src/shared/maps/PantryShelfDash.luau"

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function harness(model: any): H.Harness
	return H.new(PATH, {
		PantryShelfDashArt = Art,
		PantryShelfDashLayout = Layout,
		PantryShelfDashLogic = Logic,
		MapTypes = MapTypes,
	}, model)
end

local function overlapX(a: any, b: any): number
	return math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX)
end

return function(t: Test.Test)
	t.test("등록: 풀에 든 대형 Race, capacity 40·minPlayers 12", function()
		t.eq(MapTypes.validate(Map), nil)
		t.eq(Maps.get("pantry-shelf-dash"), Map)
		t.eq(Map.kind, "Race")
		t.eq(Map.displayName, "팬트리 선반 대질주")
		t.eq(Map.capacity, Config.Maps.LargeCapacity)
		t.eq(Map.minPlayers, Config.Maps.LargeMinPlayers)
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
	end)

	t.test(
		"선반 섬: 줄 사이 틈 6~10, 섬은 x ±45 안·폭 14 이상, 이웃 줄끼리 겹치는 곳이 있어 길이 이어져요",
		function()
			local rects = Layout.floorRects()
			local byRow: { [number]: { any } } = {}
			for _, shelf in Layout.SHELVES do
				t.ok(shelf.width >= 14, `shelf {shelf.index} width`)
				t.ok(math.abs(shelf.x) + shelf.width / 2 <= Layout.SHELF_HALF + EPS, `shelf {shelf.index} inside`)
			end
			for _, rect in rects do
				local index = tonumber(string.match(rect.name, "^Shelf(%d+)$"))
				if index then
					local row = Layout.SHELVES[index].row
					byRow[row] = byRow[row] or {}
					table.insert(byRow[row], rect)
				end
			end
			local function rectNamed(name: string): any
				for _, r in rects do
					if r.name == name then
						return r
					end
				end
				return nil
			end
			byRow[0] = { rectNamed("StartShelf") }
			byRow[#Layout.ROWS + 1] = { rectNamed("FinishLid") }
			for row = 0, #Layout.ROWS do
				local here, nextRow = byRow[row], byRow[row + 1]
				local gap = here[1].minZ - nextRow[1].maxZ
				t.ok(gap >= 6 - EPS and gap <= 10 + EPS, `row {row} → {row + 1} gap {gap}`)
				local linked = false
				for _, a in here do
					for _, b in nextRow do
						if overlapX(a, b) >= 6 then
							linked = true
						end
					end
				end
				t.ok(linked, `row {row} links to row {row + 1}`)
			end
			t.eq(#Layout.spawnPositions(), 40)
		end
	)

	t.test("바람: 3초 뒤부터 6초마다 4초 켜짐, 줄마다 방향 반대·박자 어긋남", function()
		local r1, r2 = Layout.ROWS[1], Layout.ROWS[2]
		t.eq(r1.wind, -r2.wind)
		t.ok(not Logic.windOn(r1, 2))
		t.ok(Logic.windOn(r1, 3.5))
		t.ok(not Logic.windOn(r1, 7.5))
		t.ok(Logic.windOn(r1, 9.1))
		t.eq(Logic.windTarget(r1, 3.5), 10)
		t.eq(Logic.windTarget(r1, 8), 0)
		t.ok(Logic.windOn(r2, 5.5) and not Logic.windOn(r2, 4.5), "row 2 is offset by 2 s")
		t.eq(Logic.rowAt(-50), r1)
		t.eq(Logic.rowAt(-122), r2, "the gap belongs to the next row")
		t.eq(Logic.rowAt(-10), nil)
		t.eq(Logic.rowAt(-450), nil)
	end)

	t.test("통조림: 2·4번째 줄 선반마다, 슬롯이 겹치지 않고 그 섬 위로만", function()
		t.eq(#Logic.cans(3), 0)
		for step = 0, 500 do
			local seen = {}
			for _, can in Logic.cans(step * 0.1) do
				local key = `{can.shelf}:{can.slot}`
				t.ok(not seen[key])
				seen[key] = true
				local shelf = Layout.SHELVES[can.shelf]
				local row = Layout.ROWS[shelf.row]
				t.ok(row.cans, "only can rows")
				t.ok(can.z >= row.back and can.z <= row.front, "on the island")
				t.ok(math.abs(can.x - shelf.x) + Layout.CAN_LENGTH / 2 <= shelf.width / 2 + EPS, "inside the island")
			end
		end
		t.ok(Logic.rollHit(0, 0, 0))
		t.ok(not Logic.rollHit(0, 0, 4), "jump clears")
	end)

	t.test("길이 추정 45 ~ 60초, 팬트리 바닥은 낙하선보다 10 이상 아래", function()
		local e = Logic.estimateClearTime()
		t.ok(e >= 45 and e <= 60, `estimate {e}`)
		t.ok(Art.PANTRY_FLOOR_Y <= Logic.fallLineAt(0) - 10)
	end)

	t.test("장식: validate·Large 예산·시야 상자 비움·소개 카메라는 벽 안", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.eq(Art.BUDGET, "Large")
		t.eq(MapKitLogic.checkBudget(decor, "Large"), nil)
		t.ok(MapKitLogic.count(decor) >= 400)
		t.ok(MapKitLogic.countAnimated(decor) >= 15, "fans spin")
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
			t.ok(p.pos.z < Art.BACK_Z - 2 and p.pos.z > Art.END_Z + 2, "intro inside the end walls")
			t.ok(math.abs(p.pos.x) < Art.UNIT_X, "intro between the shelving units")
		end
	end)

	t.test(
		"build: 스폰 40, 바람 줄무늬 줄마다 6가닥(처음엔 안 보임), 통조림 12개, 충돌 없음",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = H.build("pantry-shelf-dash", origin)
			t.eq(#model:FindFirstChild("Spawns"):GetChildren(), 40)
			local tags: { [string]: number } = {}
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					tags[tag] = (tags[tag] or 0) + 1
				end
				if d:IsA("BasePart") and (d:HasTag("PantryWind") or d:HasTag("PantryCan")) then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name)
				end
				if d:IsA("BasePart") and d:HasTag("PantryWind") then
					t.eq(d.Transparency, 1)
				end
			end
			t.eq(tags.PantryWind, 6 * #Layout.ROWS)
			t.eq(tags.PantryCan, 4 * Layout.CAN_SLOTS) -- 2·4번째 줄 선반 2개씩
		end
	)

	t.test("서버 모듈: 태그는 ctx.model 하위만, 바람에는 MoveExempt 없음(넉백 한 곳)", function()
		local source = fs.readFile(PATH)
		t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil)
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
	end)

	t.test(
		"start: 바람이 켜지면 줄무늬가 보이고(소리) 그 줄 사람을 옆으로 밀어요, 낙하·결승 판정",
		function()
			local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local model = H.build("pantry-shelf-dash", origin)
			local h = harness(model)
			local inRow1 = H.fakeRacer(origin, 0, Layout.FOOT_OFFSET, -80)
			local falling = H.fakeRacer(origin, 0, Logic.fallLineAt(0) - 0.1, -122)
			local finisher = H.fakeRacer(origin, 0, Layout.FOOT_OFFSET, Layout.FINISH_LINE_Z - 0.01)
			local ctx = H.newCtx(model, origin, { inRow1, falling, finisher })
			h.setClock(0)
			h.map.start(ctx)
			h.setClock(3.5)
			h.fire(0.1)
			t.ok(ctx.eliminated[falling])
			t.ok(ctx.passed[finisher])
			local shown = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("PantryWind") and d:GetAttribute("Row") == 1 then
					t.ok(d.Transparency < 1)
					shown += 1
				end
			end
			t.eq(shown, 6)
			t.ok(table.find(h.sounds, "FanGust") ~= nil)
			local v = origin:VectorToObjectSpace(inRow1.root.AssemblyLinearVelocity)
			t.ok(near(v.X, Layout.WIND_ACCEL * 0.1, 1e-6), `pushed +x {v.X}`)
			t.eq(#h.marks, 0, "wind has no MoveExempt")
		end
	)

	t.test("start: 통조림에 맞으면 뒤로 넘어지고 면제 1초", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("pantry-shelf-dash", origin)
		local h = harness(model)
		local can = Logic.cans(4.5)[1]
		local racer = H.fakeRacer(origin, can.x, Layout.FOOT_OFFSET, can.z)
		local ctx = H.newCtx(model, origin, { racer })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(4.5)
		h.fire(1 / 60)
		t.eq(#h.marks, 1)
		t.eq(h.marks[1].seconds, Layout.CAN_EXEMPT)
		local v = origin:VectorToObjectSpace(racer.root.AssemblyLinearVelocity)
		t.ok(v.Z > 15 and v.Y > 10)
		t.ok(racer.humanoid.PlatformStand)
	end)
end
