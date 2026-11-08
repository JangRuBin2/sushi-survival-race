--!strict
-- m6-03 "초밥집 카운터 대횡단"(sushi-counter-crossing): 대형 Race(스폰 40·12~40명). 코스 치수 약속, 낙하선, 갈림길 3개,
-- 레일 방향, 간장병·동전 일정, 젓가락 넉백, 길이 추정, 장식 예산·시야 상자, build 태그, 서버 start(가짜 Heartbeat).

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local H = require("./lib/LargeMapHarness")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local Layout = RobloxRequire.require(Shared.maps.SushiCounterCrossingLayout)
local Logic = RobloxRequire.require(Shared.maps.SushiCounterCrossingLogic)
local Art = RobloxRequire.require(Shared.maps.SushiCounterCrossingArt)
local Map = RobloxRequire.require(Shared.maps.SushiCounterCrossing)

local RCF: any = roblox.CFrame
local EPS = 1e-6
local PATH = "src/shared/maps/SushiCounterCrossing.luau"

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function harness(model: any): H.Harness
	return H.new(PATH, {
		SushiCounterCrossingArt = Art,
		SushiCounterCrossingLayout = Layout,
		SushiCounterCrossingLogic = Logic,
		MapTypes = MapTypes,
	}, model)
end

local function rectByName(name: string): any
	for _, rect in Layout.floorRects() do
		if rect.name == name then
			return rect
		end
	end
	return nil
end

return function(t: Test.Test)
	t.test("등록: 풀에 든 대형 Race, capacity 40·minPlayers 12, 조명 검사", function()
		t.eq(MapTypes.validate(Map), nil)
		t.eq(Maps.get("sushi-counter-crossing"), Map)
		t.eq(Map.kind, "Race")
		t.eq(Map.displayName, "초밥집 카운터 대횡단")
		t.eq(Map.capacity, Config.Maps.LargeCapacity)
		t.eq(Map.minPlayers, Config.Maps.LargeMinPlayers)
		t.eq(Map.timeLimit, nil)
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
		local info
		for _, i in Maps.infos() do
			if i.id == Map.id then
				info = i
			end
		end
		t.ok(info ~= nil, "in random pool")
		t.ok(Rules.fitsCount(info, 40, 40), "fits a 40 room round 1")
		t.ok(not Rules.fitsCount(info, 8, 8), "not for 8 players")
	end)

	t.test("스폰 40개: 출발 광장 안, 서로 6 이상 떨어짐", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, 40)
		for i, a in spawns do
			t.ok(math.abs(a.x) + 1 <= Layout.HALF, `spawn {i} x`)
			t.ok(a.z - 1 >= Layout.START.back and a.z + 1 <= Layout.START.front, `spawn {i} z`)
			for j = i + 1, #spawns do
				local b = spawns[j]
				t.ok(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 6 - EPS, `spawns {i},{j}`)
			end
		end
	end)

	t.test("코스 치수: 폭 72, 갈림길 18 × 3(틈 9), 오르막 14 × 4(틈 4), 길이 약 520", function()
		t.eq(Layout.WIDTH, 72)
		for _, name in { "StartPlaza", "MergePlaza", "ChopstickField", "FinishPlaza" } do
			local r = rectByName(name)
			t.eq(r.maxX - r.minX, 72, name)
		end
		local lw = Layout.LANE_WIDTH
		t.eq(lw, 18)
		t.eq(Layout.LANE_X[2] - Layout.LANE_X[1] - lw, 9)
		t.eq(Layout.LANE_X[3] - Layout.LANE_X[2] - lw, 9)
		t.ok(Layout.LANE_X[3] + lw / 2 <= Layout.HALF + EPS and Layout.LANE_X[1] - lw / 2 >= -Layout.HALF - EPS)
		for i = 1, #Layout.RAMP_LIST - 1 do
			local gap = Layout.RAMP_LIST[i + 1].x - Layout.RAMP_LIST[i].x - Layout.RAMP_WIDTH
			t.eq(gap, 4)
		end
		t.ok(Layout.RAMP_WIDTH >= 14, "narrowest path 14")
		t.ok(-Layout.FINISH.back >= 500 and -Layout.FINISH.back <= 530, "length")
		-- 구간이 빈틈 없이 이어져요
		local sections = Layout.sections()
		for i = 1, #sections - 1 do
			t.eq(sections[i].back, sections[i + 1].front)
		end
		-- 출발 뒤 첫 30%(z > -156)의 갈래 중 레일·간장병 줄은 폭 18 (가운데는 일부러 위험한 접시 길)
		t.ok(rectByName("BottleLane").maxX - rectByName("BottleLane").minX >= 18)
		t.ok(rectByName("Rail1").maxX - rectByName("Rail1").minX >= 18)
	end)

	t.test("접시 징검다리: 13개, 이웃 틈 3~5, 출발·합류와 이어짐", function()
		t.eq(#Layout.PLATES, 13)
		for i = 1, #Layout.PLATES - 1 do
			local a, b = Layout.PLATES[i], Layout.PLATES[i + 1]
			local gap = Logic.circleGap(a.x, a.z, a.radius, b.x, b.z, b.radius)
			t.ok(gap >= 3 and gap <= 5, `plate gap {i} {gap}`)
			t.ok(math.abs(a.x) + a.radius <= Layout.LANE_WIDTH / 2 + EPS, "plates inside the lane")
		end
		local first, last = Layout.PLATES[1], Layout.PLATES[#Layout.PLATES]
		t.ok(Layout.LANES.front - (first.z + first.radius) <= 2, "start → first plate")
		t.ok((last.z - last.radius) - Layout.MERGE.front <= 6, "last plate → merge")
	end)

	t.test(
		"바닥·낙하선: 0 → 오르막 0 → 12 → 12, 낙하선 = 바닥 − 12, 가게 바닥은 10 이상 아래",
		function()
			t.eq(Logic.floorAt(0), 0)
			t.eq(Logic.floorAt(-379), 0)
			t.ok(near(Logic.floorAt(-410), 6, EPS))
			t.eq(Logic.floorAt(-460), 12)
			for z = 40, -540, -2 do
				t.eq(Logic.fallLineAt(z), Logic.floorAt(z) - 12)
				t.ok(Art.KITCHEN_FLOOR_Y <= Logic.fallLineAt(z) - 10, `kitchen floor below fall line at {z}`)
			end
			t.eq(Logic.sectionAt(-10), "A")
			t.eq(Logic.sectionAt(-100), "B")
			t.eq(Logic.sectionAt(-300), "D")
			t.eq(Logic.sectionAt(-520), "F")
		end
	)

	t.test("회전 레일: 이웃 구간은 반대, 5초마다 뒤바뀜, 바뀌기 0.4초 전 경고", function()
		for seg = 1, 3 do
			t.eq(Logic.railDirection(seg, 1), -Logic.railDirection(seg + 1, 1))
		end
		t.eq(Logic.railDirection(1, 1), 1)
		t.eq(Logic.railDirection(1, 6), -1)
		t.eq(Logic.railDirection(1, 11), 1)
		t.ok(Logic.railSwitchSoon(4.7))
		t.ok(not Logic.railSwitchSoon(4.5))
		t.eq(Logic.railAt(-27, 3, -60), 1)
		t.eq(Logic.railAt(-27, 3, -190), 4)
		t.eq(Logic.railAt(0, 3, -60), nil)
		t.eq(Logic.railAt(-27, 20, -60), nil, "airborne high above the rail")
	end)

	t.test("간장병·동전: 시간만으로 자리, 슬롯이 겹치지 않고 줄 안·구간 안", function()
		t.eq(#Logic.bottles(0.5), 0)
		t.eq(#Logic.coins(5), 0)
		for step = 0, 600 do
			local e = step * 0.1
			local seen = {}
			for _, b in Logic.bottles(e) do
				t.ok(not seen[b.slot], `bottle slot reused at {e}`)
				seen[b.slot] = true
				t.ok(b.z >= Layout.BOTTLE_FROM_Z - EPS and b.z <= Layout.BOTTLE_TO_Z + EPS)
				t.ok(math.abs(b.x - Layout.LANE_X[3]) + Layout.BOTTLE_LENGTH / 2 <= Layout.LANE_WIDTH / 2 + EPS)
			end
			local seenCoin = {}
			for _, c in Logic.coins(e) do
				local key = `{c.lane}:{c.slot}`
				t.ok(not seenCoin[key], `coin slot reused at {e}`)
				seenCoin[key] = true
				t.ok(c.lane == 2 or c.lane == 3, "coins only on inner ramps")
				t.ok(c.z >= Layout.COIN_FROM_Z - EPS and c.z <= Layout.COIN_TO_Z + EPS)
			end
		end
		-- 맞음: 바닥에 서 있으면 맞고, 점프(발 4)면 넘어가요
		t.ok(Logic.rollHit(0, 0, 0, Layout.BOTTLE_LENGTH, Layout.BOTTLE_DIAMETER))
		t.ok(not Logic.rollHit(0, 0, 4, Layout.BOTTLE_LENGTH, Layout.BOTTLE_DIAMETER), "jump clears")
		t.ok(not Logic.rollHit(7, 0, 0, Layout.BOTTLE_LENGTH, Layout.BOTTLE_DIAMETER), "side gap")
	end)

	t.test("젓가락: 원 안이면 맞음, 바깥쪽 단위 방향, 정중앙이면 뒤로", function()
		t.ok(Logic.strikeHit(3, 4))
		t.ok(not Logic.strikeHit(6, 6))
		local x, z = Logic.strikeKnock(3, 4)
		t.ok(near(x, 0.6, 1e-9) and near(z, 0.8, 1e-9))
		t.eq({ Logic.strikeKnock(0, 0) }, { 0, 1 })
		local rng = {
			NextNumber = function(_, lo: number, hi: number)
				return (lo + hi) / 2
			end,
		}
		local s = Logic.strikeAt(rng)
		t.ok(s.z < Layout.FIELD.front and s.z > Layout.FIELD.back, "strike inside the field")
	end)

	t.test("길이 추정 45 ~ 60초", function()
		local e = Logic.estimateClearTime()
		t.ok(e >= 45 and e <= 60, `estimate {e}`)
	end)

	t.test("장식: validate·Large 예산·시야 상자 비움·소개 카메라 5개", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.eq(Art.BUDGET, "Large")
		t.eq(MapKitLogic.checkBudget(decor, "Large"), nil)
		local count = MapKitLogic.count(decor)
		t.ok(count >= 900 and count <= 2200, `decor {count}`)
		t.ok(MapKitLogic.countParticles(decor) >= 3, "particles")
		t.ok(MapKitLogic.countAnimated(decor) >= 10, "anim")
		for _, spec in decor do
			if spec.light and spec.light.kind == "Surface" then
				t.ok(spec.light.range <= 16, `{spec.name} surface range`)
			end
		end
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
		t.eq(#Art.introCamera(), 5)
		for _, p in Art.introCamera() do
			t.ok(
				math.abs(p.pos.x) <= Layout.HALF + 40 and p.pos.z <= 40 and p.pos.z >= Layout.FINISH.back - 40,
				"intro inside arena + 40"
			)
		end
	end)

	t.test(
		"build(진짜 인스턴스): 스폰 40개 바닥 위, 태그 파츠 개수, 굴림·젓가락은 충돌·쿼리·터치 없음",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = H.build("sushi-counter-crossing", origin)
			local spawns = model:FindFirstChild("Spawns"):GetChildren()
			t.eq(#spawns, 40)
			for _, s in spawns do
				local rel = origin:PointToObjectSpace(s.CFrame.Position)
				t.ok(
					rel.Z <= Layout.START.front and rel.Z >= Layout.START.back and math.abs(rel.X) <= Layout.HALF,
					s.Name
				)
				t.ok(near(rel.Y, 0.1, 1e-3), "spawn on the start floor")
			end
			local tags: { [string]: number } = {}
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					tags[tag] = (tags[tag] or 0) + 1
				end
				if
					d:IsA("BasePart")
					and (
						d:HasTag("CounterBottle")
						or d:HasTag("CounterCoin")
						or d:HasTag("ChopstickStrike")
						or d.Name == "StrikeStick"
					)
				then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, `{d.Name} must not collide`)
				end
			end
			t.eq(tags.RailSegment, 4)
			t.eq(tags.CounterBottle, Layout.BOTTLE_SLOTS)
			t.eq(tags.CounterCoin, 2 * Layout.COIN_SLOTS)
			t.eq(tags.ChopstickStrike, Layout.STRIKE_SLOTS)
			t.ok(model:FindFirstChild("FinishLine") ~= nil)
		end
	)

	t.test(
		"서버 모듈: 태그는 ctx.model 하위만, 판정은 ctx.pass/eliminate, 넉백만 MoveExempt",
		function()
			local source = fs.readFile(PATH)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil)
			local _, tagged = string.gsub(source, ":GetTagged%(", "")
			t.eq(tagged, 1)
			local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
			t.eq(marks, 1, "only knock() marks")
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function") then
					local ok = string.match(line, "= require%(") ~= nil
						or string.match(line, '= "[^"]*"$') ~= nil
						or string.match(line, "^local PARK_Y = %-?%d+") ~= nil
						or string.match(line, "^local map: MapTypes") ~= nil
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	---------------------------------------------------------------- start (가짜 Heartbeat)
	t.test("start: 결승선 통과·낙하 판정, 레일 위면 방향대로 가속(면제 없음)", function()
		local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
		local model = H.build("sushi-counter-crossing", origin)
		local onRail = H.fakeRacer(origin, -27, Layout.LOW_Y + Layout.FOOT_OFFSET, -60)
		local falling = H.fakeRacer(origin, 0, Logic.fallLineAt(-100) - 0.1, -100)
		local finishing = H.fakeRacer(origin, 0, Layout.HIGH_Y + 3, Layout.FINISH_LINE_Z - 0.01)
		local h = harness(model)
		local ctx = H.newCtx(model, origin, { onRail, falling, finishing })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(0.1)
		h.fire(0.1)
		t.ok(ctx.eliminated[falling])
		t.ok(ctx.passed[finishing])
		-- 레일 1구간은 처음 5초 결승 쪽(-z)으로 밀어요
		local v = origin:VectorToObjectSpace(onRail.root.AssemblyLinearVelocity)
		t.ok(near(v.Z, -24 * 0.1, 1e-6), `rail push {v.Z}`)
		t.eq(#h.marks, 0, "continuous push has no MoveExempt")
		ctx.active = false
		local before = h.bulk
		h.fire(0.1)
		t.eq(h.bulk, before, "no work after the round ended")
	end)

	t.test("start: 간장병에 맞으면 뒤로 넉백 + MoveExempt 1초, 쿨다운 0.8초", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("sushi-counter-crossing", origin)
		-- 첫 병은 출발 1초 뒤 z -198에서 출발 → 1.5초에 z -191
		local bottle = Logic.bottles(1.5)[1]
		local racer = H.fakeRacer(origin, bottle.x, Layout.LOW_Y + Layout.FOOT_OFFSET, bottle.z)
		local h = harness(model)
		local ctx = H.newCtx(model, origin, { racer })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(1.5)
		h.fire(1 / 60)
		t.eq(#h.marks, 1)
		t.eq(h.marks[1].seconds, Layout.ROLL_EXEMPT)
		local v = origin:VectorToObjectSpace(racer.root.AssemblyLinearVelocity)
		t.ok(v.Z > 20 and v.Y > 10, "knocked back (+z) and up")
		t.ok(racer.humanoid.PlatformStand)
		h.setClock(1.6)
		h.fire(1 / 60)
		t.eq(#h.marks, 1, "cooldown")
	end)

	t.test("start: 젓가락 경고 1.5초 뒤 원 안 사람만 넉백, 경고·내려찍기 소리", function()
		local origin = RCF.new(0, 300, 2000)
		local model = H.build("sushi-counter-crossing", origin)
		local h = harness(model)
		local ctx = H.newCtx(model, origin, {}, 42)
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(Layout.STRIKE_START_DELAY)
		h.fire(1 / 60)
		-- 띄운 원 위치 찾기
		local disc
		for _, d in model:GetDescendants() do
			if d.Name == "StrikeDisc" and d.Transparency < 1 then
				disc = d
			end
		end
		t.ok(disc ~= nil, "a warning disc is shown")
		t.ok(table.find(h.sounds, "ChopstickWarn") ~= nil)
		local rel = origin:PointToObjectSpace(disc.CFrame.Position)
		t.ok(rel.Z < Layout.FIELD.front and rel.Z > Layout.FIELD.back, "disc in the field")
		local inside = H.fakeRacer(origin, rel.X + 2, Layout.LOW_Y + Layout.FOOT_OFFSET, rel.Z)
		local outside = H.fakeRacer(origin, rel.X + 2, Layout.LOW_Y + Layout.FOOT_OFFSET, rel.Z + 20)
		ctx.getRacers = function()
			return { inside, outside }
		end
		h.setClock(Layout.STRIKE_START_DELAY + Layout.STRIKE_WARN + 0.01)
		h.fire(1 / 60)
		t.ok(table.find(h.sounds, "ChopstickClack") ~= nil)
		t.ok(inside.humanoid.PlatformStand, "inside knocked")
		t.ok(not outside.humanoid.PlatformStand, "outside untouched")
		local v = origin:VectorToObjectSpace(inside.root.AssemblyLinearVelocity)
		t.ok(v.X > 20, `pushed outward (+x) {v.X}`)
	end)
end
