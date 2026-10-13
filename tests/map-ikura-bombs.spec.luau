--!strict
-- m5-04 "연어알 폭탄 접시": 칸·스폰(AC1), tileAt(AC2), 폭탄 시간표(AC3), 노릴 곳(AC4), 넉백(AC5),
-- 금 가기·정해진 낙하(AC6), 연장전 고리 일정(AC7), 장식(AC8).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.IkuraBombsLayout)
local Logic = RobloxRequire.require(Shared.maps.IkuraBombsLogic)
local Art = RobloxRequire.require(Shared.maps.IkuraBombsArt)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)

type Bounds = MapKitLogic.Bounds

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

local EPS = 1e-6

local function near(t: Test.Test, actual: number, expected: number, eps: number)
	t.ok(math.abs(actual - expected) <= eps, `expected {expected} got {actual}`)
end

local function polar(r: number, deg: number): (number, number)
	return Layout.polar(r, deg)
end

local function allIds(): { number }
	local ids = {}
	for id = 0, 16 do
		table.insert(ids, id)
	end
	return ids
end

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x - EPS
		and a.max.x > b.min.x + EPS
		and a.min.y < b.max.y - EPS
		and a.max.y > b.min.y + EPS
		and a.min.z < b.max.z - EPS
		and a.max.z > b.min.z + EPS
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: Final 맵, overtime 함수, validate 통과, 랜덤 풀에 들어가요", function()
		local map = Maps.get("ikura-bombs")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Final")
		t.eq(type(map.overtime), "function")
		t.ok(map.inPool ~= false, "inPool 줄 삭제")
		t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
		local found = false
		for _, info in Maps.infos() do
			if info.id == "ikura-bombs" then
				found = true
			end
		end
		t.ok(found, "Maps.infos()에 있어요")
	end)

	t.test("AC1: 칸 17개 (Ring 0 = 1, Ring 1 = 6, Ring 2 = 10), id 0~16 고유", function()
		local byRing = { [0] = 0, [1] = 0, [2] = 0 }
		local seen: { [number]: boolean } = {}
		for i, tile in Layout.tiles() do
			t.eq(tile.id, i - 1)
			t.ok(not seen[tile.id], "duplicate id")
			seen[tile.id] = true
			byRing[tile.ring] += 1
		end
		t.eq(Layout.TILE_COUNT, 17)
		t.eq(byRing[0], 1)
		t.eq(byRing[1], 6)
		t.eq(byRing[2], 10)
	end)

	t.test("AC1: 고리 조각 — 틈 0 (고리 경계가 같은 현), 조각마다 그 칸 각도 안", function()
		local half = math.rad(Layout.SLICE_DEG / 2)
		for ring = 1, 2 do
			local slices = Layout.slices(ring)
			t.eq(#slices, 60)
			local perTile: { [number]: number } = {}
			for _, slice in slices do
				perTile[slice.tileId] = (perTile[slice.tileId] or 0) + 1
				local tile = Layout.tile(slice.tileId) :: any
				t.eq(tile.ring, ring)
				t.ok(slice.angleDeg > tile.fromDeg and slice.angleDeg < tile.toDeg, "slice inside tile arc")
				-- 안쪽 변 = rIn·cos3°, 바깥 변 = rOut·cos3°
				near(t, slice.distance - slice.depth / 2, Layout.ringInner(ring) * math.cos(half), 1e-6)
				near(t, slice.distance + slice.depth / 2, Layout.ringOuter(ring) * math.cos(half), 1e-6)
			end
			for _, n in perTile do
				t.eq(n, 60 / Layout.RING_TILES[ring])
			end
		end
		-- 가운데 고리 안쪽 변은 원판(반지름 8) 안에 있어요 → 틈 0
		t.ok(Layout.ringInner(1) * math.cos(half) <= Layout.ringOuter(0), "ring1 meets center disc")
		-- 가운데 고리 바깥 변 == 바깥 고리 안쪽 변
		local outer1 = Layout.slices(1)[1]
		local inner2 = Layout.slices(2)[1]
		near(t, outer1.distance + outer1.depth / 2, inner2.distance - inner2.depth / 2, 1e-9)
		-- 바깥 고리 조각 모서리는 반지름 24 밖으로 안 나가요
		local s = Layout.slices(2)[1]
		local corner = math.sqrt((s.distance + s.depth / 2) ^ 2 + (s.width / 2) ^ 2)
		t.ok(corner <= Layout.RADIUS + 1e-6, `corner {corner}`)
	end)

	t.test(
		"AC1: 스폰 24개, 전부 칸 위(반지름 12~20, 가장자리에서 4 이상), 서로 3 이상",
		function()
			local spawns = Layout.spawns()
			t.eq(#spawns, 24)
			for i, s in spawns do
				local r = math.sqrt(s.x * s.x + s.z * s.z)
				t.ok(r >= 12 - EPS and r <= 20 + EPS, `spawn {i} radius {r}`)
				t.ok(Logic.tileAt(s.x, s.z) ~= nil, `spawn {i} on tile`)
				t.ok(Layout.RADIUS - r >= 4, `spawn {i} edge`)
				t.ok(s.y > 0 and s.y < 1, "spawn just above tile top")
			end
			for i = 1, #spawns do
				for j = i + 1, #spawns do
					local a, b = spawns[i], spawns[j]
					local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
					t.ok(d >= 3, `spawn {i}-{j} distance {d}`)
				end
			end
			-- 앞 4개가 한쪽에 몰리지 않아요 (두 줄 섞임)
			local r1 = math.sqrt(spawns[1].x ^ 2 + spawns[1].z ^ 2)
			local r2 = math.sqrt(spawns[2].x ^ 2 + spawns[2].z ^ 2)
			t.ok(math.abs(r1 - r2) > 1, "first two spawns on different rows")
		end
	)

	---------------------------------------------------------------- AC2
	t.test("AC2: tileAt — 경계 바로 안쪽 표본 20개, 반지름 24 밖은 nil", function()
		local cases = {
			-- { r, deg, ring, index }
			{ 7.99, 0, 0, 0 },
			{ 0, 0, 0, 0 },
			{ 7.9, 200, 0, 0 },
			{ 8.01, 0.01, 1, 0 },
			{ 8.01, 59.99, 1, 0 },
			{ 8.01, 60.01, 1, 1 },
			{ 15.99, 119.99, 1, 1 },
			{ 15.99, 120.01, 1, 2 },
			{ 12, 239.99, 1, 3 },
			{ 12, 240.01, 1, 4 },
			{ 12, 359.99, 1, 5 },
			{ 16.01, 0.01, 2, 0 },
			{ 16.01, 35.99, 2, 0 },
			{ 16.01, 36.01, 2, 1 },
			{ 23.99, 71.99, 2, 1 },
			{ 23.99, 72.01, 2, 2 },
			{ 20, 179.99, 2, 4 },
			{ 20, 180.01, 2, 5 },
			{ 23.99, 323.99, 2, 8 },
			{ 23.99, 359.99, 2, 9 },
		}
		t.eq(#cases, 20)
		for _, c in cases do
			local x, z = polar(c[1], c[2])
			t.eq(Logic.tileAt(x, z), Layout.tileId(c[3], c[4]), `r {c[1]} deg {c[2]}`)
		end
		for _, deg in { 0, 45, 90, 200, 300 } do
			local x, z = polar(24.01, deg)
			t.eq(Logic.tileAt(x, z), nil, `outside at {deg}`)
		end
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: bombWave 표", function()
		t.eq(Logic.bombWave(0), nil)
		t.eq(Logic.bombWave(2.9), nil)
		t.eq(Logic.bombWave(3), { interval = 2.5, count = 1, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(29.9), { interval = 2.5, count = 1, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(30), { interval = 2.0, count = 2, warn = 1.5, radius = 7 })
		t.eq(Logic.bombWave(60), { interval = 1.5, count = 2, warn = 1.2, radius = 9 })
		t.eq(Logic.bombWave(95), { interval = 1.5, count = 2, warn = 1.2, radius = 9 })
		t.eq(Logic.bombWave(95, 90), { interval = 1.0, count = 3, warn = 1.2, radius = 9 })
		t.eq(Logic.bombWave(89, 90), { interval = 1.5, count = 2, warn = 1.2, radius = 9 })
		-- DEBUG.overtimeAt처럼 일찍 와도 연장전 값
		t.eq(Logic.bombWave(15, 15), { interval = 1.0, count = 3, warn = 1.2, radius = 9 })
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: pickTargets — 약 60%가 레이서 3 studs 안, 모든 점이 남은 칸 위", function()
		local rng = seededRng(7)
		local x1, z1 = polar(12, 30)
		local x2, z2 = polar(20, 200)
		local racers = { { x = x1, z = z1 }, { x = x2, z = z2 } }
		local alive = allIds()
		local near = 0
		for _ = 1, 1000 do
			local points = Logic.pickTargets(rng, racers, alive, 1)
			t.eq(#points, 1)
			local p = points[1]
			t.ok(Logic.tileAt(p.x, p.z) ~= nil, "on a tile")
			for _, r in racers do
				if (p.x - r.x) ^ 2 + (p.z - r.z) ^ 2 <= 9 + EPS then
					near += 1
					break
				end
			end
		end
		t.ok(near >= 530 and near <= 670, `near {near}`)
	end)

	t.test("AC4: 남은 칸 밖을 노리면 가장 가까운 남은 칸 위로 옮겨요", function()
		local rng = seededRng(11)
		-- 바깥 고리 칸 0(0~36도)만 남음, 레이서는 떨어진 칸(180도) 위
		local onlyId = Layout.tileId(2, 0) :: number
		local x, z = polar(20, 180)
		for _ = 1, 300 do
			for _, p in Logic.pickTargets(rng, { { x = x, z = z } }, { onlyId }, 3) do
				t.eq(Logic.tileAt(p.x, p.z), onlyId)
			end
		end
		-- 원판만 남음
		for _ = 1, 300 do
			for _, p in Logic.pickTargets(rng, { { x = x, z = z } }, { 0 }, 2) do
				t.eq(Logic.tileAt(p.x, p.z), 0)
			end
		end
		-- clampToAlive: 이미 남은 칸 위면 (경계 여유 안에서) 그대로
		local px, pz = polar(12, 30)
		local same = Logic.clampToAlive(px, pz, { Layout.tileId(1, 0) :: number })
		near(t, same.x, px, 1e-9)
		near(t, same.z, pz, 1e-9)
		t.eq(#Logic.pickTargets(rng, { { x = x, z = z } }, {}, 3), 0)
	end)

	t.test("AC4: 같은 묶음 중심 간격 ≥ 6 (칸이 넉넉하면)", function()
		local rng = seededRng(3)
		local alive = allIds()
		local x, z = polar(13, 100)
		local violations = 0
		for _ = 1, 500 do
			local points = Logic.pickTargets(rng, { { x = x, z = z } }, alive, 3)
			t.eq(#points, 3)
			for i = 1, 3 do
				for j = i + 1, 3 do
					local a, b = points[i], points[j]
					if (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 < 36 - EPS then
						violations += 1
					end
				end
			end
		end
		-- 다시 뽑기 5번 뒤에도 실패하는 건 아주 드물어요
		t.ok(violations <= 5, `violations {violations}`)
	end)

	t.test(
		"AC4: 칸이 하나뿐이라 간격이 불가능하면 5번 뒤 그대로 허용 (개수는 그대로)",
		function()
			local rng = seededRng(5)
			local points = Logic.pickTargets(rng, {}, { 0 }, 3)
			t.eq(#points, 3)
			for _, p in points do
				t.eq(Logic.tileAt(p.x, p.z), 0)
			end
		end
	)

	---------------------------------------------------------------- AC5
	t.test("AC5: knockback", function()
		-- 거리 0 → 기본 방향 (+X), nil 아님
		local zero = Logic.knockback(0, 0, 7) :: any
		t.ok(zero ~= nil, "not nil at center")
		near(t, zero.x, 50, 1e-9)
		near(t, zero.z, 0, 1e-9)
		t.eq(zero.y, 30)
		-- 거리 0 + 접시 중심 반대쪽 방향
		local away = Logic.knockback(0, 0, 7, 0, -10) :: any
		near(t, away.x, 0, 1e-9)
		near(t, away.z, -50, 1e-9)
		-- 거리 = 반경 → 수평 30
		local edge = Logic.knockback(7, 0, 7) :: any
		near(t, edge.x, 30, 1e-9)
		t.eq(edge.y, 30)
		local diag = Logic.knockback(3, 4, 9) :: any
		near(t, math.sqrt(diag.x ^ 2 + diag.z ^ 2), 50 * (1 - 0.4 * 5 / 9), 1e-9)
		t.ok(diag.x > 0 and diag.z > 0, "outward")
		-- 반경 밖 → nil
		t.eq(Logic.knockback(7.01, 0, 7), nil)
		-- inBlast: 높이 차 6 이하
		t.ok(Logic.inBlast(3, 6, 0, 7), "dy 6 ok")
		t.ok(not Logic.inBlast(3, 6.1, 0, 7), "dy 6.1 no")
		t.ok(not Logic.inBlast(7.1, 0, 0, 7), "outside radius")
	end)

	---------------------------------------------------------------- AC6
	t.test("AC6: 금 가기 — Ring 1·2는 두 번에 drop, Ring 0은 안 떨어짐", function()
		local c, drop = Logic.crack(1, 0)
		t.eq(c, 1)
		t.eq(drop, false)
		c, drop = Logic.crack(1, c)
		t.eq(c, 2)
		t.eq(drop, true)
		c, drop = Logic.crack(2, 1)
		t.eq(drop, true)
		local zc = 0
		for _ = 1, 10 do
			local d
			zc, d = Logic.crack(0, zc)
			t.eq(d, false)
		end
		t.eq(zc, 0)
	end)

	local function fullAlive(): { any }
		local list = {}
		for _, tile in Layout.tiles() do
			table.insert(list, { id = tile.id, ring = tile.ring, cracks = 0 })
		end
		return list
	end

	local function removeId(list: { any }, id: number)
		for i, tile in list do
			if tile.id == id then
				table.remove(list, i)
				return
			end
		end
	end

	local function countRing(list: { any }, ring: number): number
		local n = 0
		for _, tile in list do
			if tile.ring == ring then
				n += 1
			end
		end
		return n
	end

	t.test(
		"AC6: scheduledDrops — 40초 전 없음, 40·46·52…에 바깥 하나씩, 3칸 남으면 멈춤",
		function()
			local alive = fullAlive()
			for _, e in { 0, 10, 39.9, 41, 43, 45.9 } do
				t.eq(Logic.scheduledDrops(e, alive), {}, `at {e}`)
			end
			local time = 40
			local dropped = 0
			while time < 60 do
				local drops = Logic.scheduledDrops(time, alive)
				t.eq(#drops, 1, `at {time}`)
				local tile = Layout.tile(drops[1]) :: any
				t.eq(tile.ring, 2)
				removeId(alive, drops[1])
				dropped += 1
				time += 6
			end
			t.eq(dropped, 4) -- 40, 46, 52, 58
			t.eq(countRing(alive, 2), 6)
			-- 계속 돌리면 바깥은 3칸에서 멈춰요
			while countRing(alive, 2) > 3 do
				local drops = Logic.scheduledDrops(time, alive)
				for _, id in drops do
					removeId(alive, id)
				end
				time += 6
			end
			local after = Logic.scheduledDrops(time, alive)
			for _, id in after do
				t.ok((Layout.tile(id) :: any).ring ~= 2, "outer stops at 3")
			end
			t.eq(countRing(alive, 2), 3)
		end
	)

	t.test("AC6: 60초부터 가운데 고리, 2칸 남으면 멈춤, 원판은 정해진 낙하 없음", function()
		local alive = fullAlive()
		t.eq(Logic.scheduledDrops(52, alive), { Layout.tileId(2, 0) }) -- rng 없으면 id 작은 칸
		local drops60 = Logic.scheduledDrops(60, alive)
		t.eq(#drops60, 1)
		t.eq((Layout.tile(drops60[1]) :: any).ring, 1)
		local time = 60
		for _ = 1, 20 do
			for _, id in Logic.scheduledDrops(time, alive) do
				removeId(alive, id)
			end
			time += 6
		end
		t.eq(countRing(alive, 1), 2)
		t.eq(countRing(alive, 0), 1)
		-- 마크가 아닌 시각은 없음
		t.eq(Logic.scheduledDrops(61, fullAlive()), {})
	end)

	t.test("AC6: 금 간 칸이 먼저, 같으면 무작위", function()
		local alive = fullAlive()
		for _, tile in alive do
			if tile.id == 12 then
				tile.cracks = 1
			end
		end
		t.eq(Logic.scheduledDrops(40, alive, seededRng(1)), { 12 })
		local seen: { [number]: boolean } = {}
		local fresh = fullAlive()
		for seed = 1, 200 do
			local drops = Logic.scheduledDrops(46, fresh, seededRng(seed))
			seen[drops[1]] = true
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		t.ok(kinds >= 5, `random spread {kinds}`)
	end)

	t.test("AC6: scheduleMarks — 40부터 6초마다 + 60부터 6초마다 (겹침 없음)", function()
		local marks = Logic.scheduleMarks(91)
		t.eq(marks[1], 40)
		t.ok(table.find(marks, 46) ~= nil, "46")
		t.ok(table.find(marks, 60) ~= nil, "60")
		t.ok(table.find(marks, 66) ~= nil, "66")
		t.ok(table.find(marks, 88) ~= nil, "88")
		for i = 2, #marks do
			t.ok(marks[i] > marks[i - 1], "sorted unique")
		end
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: overtimeRings(20, 1) — ring 2·1·0, dropAt 1·10.5·20, 경고 1초", function()
		local steps = Logic.overtimeRings(20, 1)
		t.eq(#steps, 3)
		local rings = { 2, 1, 0 }
		local drops = { 1, 10.5, 20 }
		for i, step in steps do
			t.eq(step.ring, rings[i])
			near(t, step.dropAt, drops[i], 1e-9)
			near(t, step.dropAt - step.warnAt, 1, 1e-9)
		end
		near(t, steps[1].warnAt, 0, 1e-9)
		t.eq(steps[3].dropAt, Config.Final.CollapseDuration)
	end)

	---------------------------------------------------------------- AC8 · AC17 (아트)
	local function allDecor(): { any }
		local list = table.clone(Art.decor())
		for id = 0, 16 do
			for _, spec in Art.tileDecor(id) do
				table.insert(list, spec)
			end
		end
		for _, spec in Art.spoonDecor() do
			table.insert(list, spec)
		end
		return list
	end

	t.test("AC8·AC17: 장식 — 목록마다 validate 통과, 합쳐서 Extended 예산 안", function()
		t.eq(Art.BUDGET, "Extended")
		t.eq(MapKitLogic.validate(Art.decor()), nil)
		t.eq(MapKitLogic.validate(Art.spoonDecor()), nil)
		for id = 0, 16 do
			t.eq(MapKitLogic.validate(Art.tileDecor(id)), nil, `tileDecor {id}`)
		end
		t.eq(MapKitLogic.checkBudget(Art.decor(), "Extended"), nil)
		t.eq(MapKitLogic.checkBudget(allDecor(), "Extended"), nil)
		t.ok(MapKitLogic.countShadowedLights(allDecor()) <= 2, "shadowed lights")
		t.ok(MapKitLogic.countParticles(allDecor()) >= 2, "particles")
		t.ok(MapKitLogic.countAnimated(Art.decor()) >= 3, "anim")
		-- 움직이는 숟가락·칸 장식에는 anim·조명 금지
		for _, spec in Art.spoonDecor() do
			t.eq(spec.anim, nil, `spoon {spec.name} anim`)
			t.ok(spec.light == nil, `spoon {spec.name} light`)
		end
		for id = 0, 16 do
			for _, spec in Art.tileDecor(id) do
				t.eq(spec.anim, nil, "tile decor anim")
			end
		end
		t.eq(Art.spoonDecor()[1].name, "SpoonBowl") -- 숟가락 Model의 PrimaryPart
		t.eq(#Art.tileDecor(0), 0) -- 원판은 경계 선 없음
		-- Surface 조명은 Roblox 최대 범위 16 (m5-23 QA)
		for _, spec in allDecor() do
			if spec.light and spec.light.kind == "Surface" then
				t.ok(spec.light.range <= 16, `{spec.name} surface light range`)
			end
		end
	end)

	t.test(
		"AC8: 장식이 시야 상자(칸 윗면 위 2~12)와 안 겹쳐요, 칸 경계 선은 윗면에 붙어 있어요",
		function()
			local sight = Art.courseVolume()
			for _, spec in Art.decor() do
				local bounds = MapKitLogic.bounds({ spec }) :: Bounds
				t.ok(not overlaps(bounds, sight), `{spec.name} overlaps sight box`)
			end
			for id = 0, 16 do
				for _, spec in Art.tileDecor(id) do
					local bounds = MapKitLogic.bounds({ spec }) :: Bounds
					t.ok(bounds.max.y <= 0.1 and bounds.min.y >= -0.01, "seam stays flush with the tile top")
				end
			end
		end
	)

	t.test(
		"AC17: 가짜 바닥 없음 — 접시 근처에서 칸 윗면 ±1 안의 얇은 판 장식은 립(윗면보다 낮게)뿐",
		function()
			for _, spec in Art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				local near = b.min.x < 30 and b.max.x > -30 and b.min.z < 30 and b.max.z > -30
				-- 얇고 넓은 판(두께 ≤ 1.5, 가로세로 ≥ 2)만 "바닥처럼 보이는 것" (와사비 덩이 같은 둥근 더미는 제외)
				local flat = b.max.y - b.min.y <= 1.5 and math.min(b.max.x - b.min.x, b.max.z - b.min.z) >= 2
				if near and flat and b.max.y > -1 and b.max.y < 1 then
					t.eq(spec.name, "PlateLip", `{spec.name} top {b.max.y} looks like floor`)
					t.ok(b.max.y < 0, "lip is below the tile top")
				end
			end
		end
	)

	t.test("AC17: 배경 바닥(부두·바다·길)은 낙하 탈락선보다 10 이상 아래", function()
		local killY = -Layout.FALL_DEPTH
		local found = 0
		for _, spec in Art.decor() do
			if spec.name == "Sea" or spec.name == "DeckPlank" or spec.name == "Street" then
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				t.ok(b.max.y <= killY - 10, `{spec.name} top {b.max.y}`)
				found += 1
			end
		end
		t.ok(found > 10, "background floors exist")
	end)

	t.test("AC17: 맵 lighting 프리셋이 있고 validate 통과, 로비와 달라요", function()
		local map = Maps.get("ikura-bombs")
		t.ok(map.lighting ~= nil, "lighting preset")
		t.eq(MapLighting.validate(map.lighting), nil)
		t.ok((map.lighting :: any).ClockTime ~= MapLighting.LOBBY.ClockTime, "differs from lobby")
	end)

	t.test("소개 카메라 4점, 전부 판정 경계 + 40 안 (밖이면 로비 조명)", function()
		local points = Art.introCamera()
		t.eq(#points, 4)
		local limit = Layout.RADIUS + 40
		for i, p in points do
			t.ok(math.abs(p.pos.x) <= limit and math.abs(p.pos.z) <= limit, `point {i} xz`)
			t.ok(p.pos.y <= 40 and p.pos.y >= -40, `point {i} y`)
		end
	end)
end
