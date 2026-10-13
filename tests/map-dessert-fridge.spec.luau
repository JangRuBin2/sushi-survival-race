--!strict
-- m5-06 "디저트 냉장고"(dessert-fridge): 코스 치수 약속, 낙하선, 길 찾기, 송풍구 주기, 젤리 높이, 장식 예산

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.DessertFridgeLayout)
local Logic = RobloxRequire.require(Shared.maps.DessertFridgeLogic)
local Art = RobloxRequire.require(Shared.maps.DessertFridgeArt)
local DessertFridge = RobloxRequire.require(Shared.maps.DessertFridge)

local EPS = 1e-6
local GRAVITY = 196.2

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX - EPS and a.maxX > b.minX + EPS and a.minZ < b.maxZ - EPS and a.maxZ > b.minZ + EPS
end

local function area(r: Rect): number
	return (r.maxX - r.minX) * (r.maxZ - r.minZ)
end

return function(t: Test.Test)
	t.test(
		"AC1: 풀에 등록된 Race 맵이고 이름·규칙이 m5-03 그대로, inPool 줄이 지워졌어요",
		function()
			t.eq(MapTypes.validate(DessertFridge), nil)
			t.eq(Maps.get("dessert-fridge"), DessertFridge)
			t.eq(DessertFridge.kind, "Race")
			t.eq(DessertFridge.displayName, "디저트 냉장고")
			t.eq(DessertFridge.rule, "미끄러운 얼음을 건너 냉장고 문까지 달려요!")
			t.ok(DessertFridge.inPool == nil or DessertFridge.inPool == true, "inPool")
			t.eq(Maps.timeLimit(DessertFridge), Config.TimeLimit.Race)
			local found = false
			for _, info in Maps.infos() do
				if info.id == "dessert-fridge" then
					found = true
				end
			end
			t.ok(found, "dessert-fridge is in the random pool")
			local source = fs.readFile("src/shared/maps/DessertFridge.luau")
			t.eq(string.find(source, "inPool", 1, true), nil, "inPool line should be removed")
		end
	)

	t.test("AC1: 스폰 24개가 출발 바닥(A) 안에서 서로 3 studs 이상 떨어져 있어요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		t.eq(#spawns, 24)
		for i, a in spawns do
			t.ok(math.abs(a.x) + 1 <= Layout.START_WIDTH / 2, `spawn {i} x {a.x} outside start width`)
			t.ok(a.z - 1 >= Layout.START.back and a.z + 1 <= Layout.START.front, `spawn {i} z {a.z} outside start`)
			for j = i + 1, #spawns do
				local b = spawns[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.ok(d >= 3 - EPS, `spawns {i},{j} only {d} apart`)
			end
		end
	end)

	t.test(
		"AC2: 구간이 출발 → 결승으로 빈틈 없이 이어지고 진행도가 단조 증가해요",
		function()
			local sections = Layout.sections()
			t.eq(#sections, 5)
			t.eq(sections[1].front, 0)
			for i, span in sections do
				t.ok(span.front > span.back, `section {i} has positive length`)
				if i > 1 then
					t.eq(span.front, sections[i - 1].back, `section {i} starts where {i - 1} ends`)
				end
			end
			t.eq(sections[#sections].back, -260)
			local previous = -math.huge
			for z = 0, -260, -0.5 do
				local p = Logic.progress(z)
				t.ok(p > previous, `progress not increasing at z {z}`)
				previous = p
			end
			-- 결승선은 E 안, 진행도 250
			t.ok(Layout.FINISH_LINE_Z < Layout.FINISH.front and Layout.FINISH_LINE_Z > Layout.FINISH.back)
			t.eq(Logic.finishProgress(), 250)
		end
	)

	t.test("AC2: fallLineAt(z)는 각 구간 바닥 - 25 (A·B·C -25, D·E -13)", function()
		local cases = {
			{ z = -5, floor = 0 },
			{ z = -40, floor = 0 }, -- 구멍 1
			{ z = -70, floor = 0 }, -- 구멍 2
			{ z = -90, floor = 0 },
			{ z = -110, floor = 0 },
			{ z = -130, floor = 0 }, -- C 착지대도 C 구간
			{ z = -137, floor = 12 },
			{ z = -200, floor = 12 },
			{ z = -240, floor = 12 },
			{ z = -259, floor = 12 },
		}
		for _, case in cases do
			t.eq(Logic.fallLineAt(case.z), case.floor - 25, `z {case.z}`)
		end
		t.eq(Logic.fallLineAt(-100), -25)
		t.eq(Logic.fallLineAt(-150), -13)
	end)

	t.test(
		"AC3: B 얼음 바닥 조각은 쟁반 안, 구멍과 안 겹치고, 넓이 = 쟁반 - 구멍 2개",
		function()
			local rects = Layout.iceTrayRects()
			local half = Layout.ICE_TRAY_WIDTH / 2
			local total = 0
			for i, r in rects do
				t.ok(r.minX >= -half - EPS and r.maxX <= half + EPS, `rect {i} x`)
				t.ok(r.maxZ <= Layout.ICE_TRAY.front + EPS and r.minZ >= Layout.ICE_TRAY.back - EPS, `rect {i} z`)
				for _, hole in Layout.holeRects() do
					t.ok(not overlaps(r, hole), `rect {i} overlaps a hole`)
				end
				for j = i + 1, #rects do
					t.ok(not overlaps(r, rects[j]), `rects {i},{j} overlap`)
				end
				total += area(r)
			end
			local expected = Layout.ICE_TRAY_WIDTH * (Layout.ICE_TRAY.front - Layout.ICE_TRAY.back)
				- #Layout.HOLES * Layout.HOLE_SIZE * Layout.HOLE_SIZE
			t.ok(math.abs(total - expected) < 1e-6, `area {total} vs {expected}`)
			t.eq(#Layout.HOLES, 2)
			t.eq(#Layout.CUBES, 8)
			-- 구멍·큐브는 쟁반 안, 서로 안 겹쳐요
			for _, r in Layout.cubeRects() do
				t.ok(r.minX >= -half and r.maxX <= half, "cube inside tray width")
				t.ok(r.maxZ <= Layout.ICE_TRAY.front and r.minZ >= Layout.ICE_TRAY.back, "cube inside tray")
				for _, hole in Layout.holeRects() do
					t.ok(not overlaps(r, hole), "cube over a hole")
				end
			end
			-- 큐브가 지그재그 (x 부호가 번갈아 나와요)
			local signs = 0
			for i = 2, #Layout.CUBES do
				if (Layout.CUBES[i].x > 0) ~= (Layout.CUBES[i - 1].x > 0) then
					signs += 1
				end
			end
			t.ok(signs >= 5, `zigzag changes {signs}`)
		end
	)

	t.test(
		"AC3: B 구간 구멍·큐브 사이로 폭 4 이상의 길이 출발 쪽에서 C까지 이어져요 (격자 탐색)",
		function()
			local STEP = 0.5
			local HALF = 2 -- 4 x 4 정사각형이 지나갈 수 있는지
			local trayHalf = Layout.ICE_TRAY_WIDTH / 2
			local blockers = {}
			for _, r in Layout.holeRects() do
				table.insert(blockers, r)
			end
			for _, r in Layout.cubeRects() do
				table.insert(blockers, r)
			end
			local function free(cx: number, cz: number): boolean
				if cx - HALF < -trayHalf - EPS or cx + HALF > trayHalf + EPS then
					return false
				end
				local square = { minX = cx - HALF, maxX = cx + HALF, minZ = cz - HALF, maxZ = cz + HALF }
				for _, b in blockers do
					if overlaps(square, b) then
						return false
					end
				end
				return true
			end
			local xs = math.floor((2 * (trayHalf - HALF)) / STEP + 0.5)
			local zFront = Layout.ICE_TRAY.front -- 사각형 중심 z (앞쪽 끝: 출발 바닥에 걸쳐도 돼요)
			local zBack = Layout.ICE_TRAY.back
			local zs = math.floor((zFront - zBack) / STEP + 0.5)
			local function key(ix: number, iz: number): number
				return iz * 10000 + ix
			end
			local function pos(ix: number, iz: number): (number, number)
				return -trayHalf + HALF + ix * STEP, zFront - iz * STEP
			end
			local queue = {}
			local seen = {}
			for ix = 0, xs do
				local x, z = pos(ix, 0)
				if free(x, z) then
					table.insert(queue, { ix, 0 })
					seen[key(ix, 0)] = true
				end
			end
			local reached = false
			local head = 1
			while head <= #queue do
				local node = queue[head]
				head += 1
				if node[2] == zs then
					reached = true
					break
				end
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx, nz = node[1] + d[1], node[2] + d[2]
					if nx >= 0 and nx <= xs and nz >= 0 and nz <= zs and not seen[key(nx, nz)] then
						local x, z = pos(nx, nz)
						if free(x, z) then
							seen[key(nx, nz)] = true
							table.insert(queue, { nx, nz })
						end
					end
				end
			end
			t.ok(reached, "no 4-wide path through the ice tray")
			-- 구멍이 길을 다 막지 않는다는 것도 개별 점으로 확인
			t.eq(Logic.iceTrayWalkable(-5, -40), false, "hole 1")
			t.eq(Logic.iceTrayWalkable(5, -70), false, "hole 2")
			t.eq(Logic.iceTrayWalkable(-6, -24), false, "cube 1")
			t.eq(Logic.iceTrayWalkable(0, -20), true)
		end
	)

	t.test(
		"AC3: C 구간 쿠키 계단만으로 위 칸(y 12)에 닿아요 (디딤 높이 <= 3, 이어진 계단)",
		function()
			local heights = Logic.cookieClimb()
			t.eq(heights[1], Layout.LOW_Y)
			t.eq(heights[#heights], Layout.HIGH_Y)
			for i = 2, #heights do
				local rise = heights[i] - heights[i - 1]
				t.ok(rise > 0 and rise <= 3 + EPS, `step {i} rise {rise}`)
			end
			local steps = Layout.COOKIE_STEPS
			t.ok(
				steps[1].front < Layout.JELLY_ZONE.front and steps[1].front > Layout.LANDING.front,
				"first step on C floor"
			)
			for i = 2, #steps do
				t.eq(steps[i].front, steps[i - 1].back, `step {i} follows step {i - 1}`)
			end
			t.eq(steps[#steps].back, Layout.LANDING.front, "last step touches the landing")
			-- 계단 폭 6, C 폭 안, 젤리와 안 겹쳐요
			t.eq(Layout.COOKIE_MAX_X - Layout.COOKIE_MIN_X, 6)
			t.ok(Layout.COOKIE_MAX_X <= Layout.JELLY_ZONE_WIDTH / 2, "stairs inside C width")
			local stairs = {
				minX = Layout.COOKIE_MIN_X,
				maxX = Layout.COOKIE_MAX_X,
				minZ = steps[#steps].back,
				maxZ = steps[1].front,
			}
			for _, jelly in Layout.jellyRects() do
				t.ok(not overlaps(stairs, jelly), "stairs overlap a jelly")
			end
			-- 착지대는 위 칸(D) 시작과 붙어 있어요
			t.eq(Layout.LANDING.back, Layout.FAN_SHELF.front)
		end
	)

	t.test("AC4: fanState — 송풍구 1은 0~0.5 Warn, 0.5~2.5 Blow, 2.5~4 Rest, 4에서 다시 Warn", function()
		local cases = {
			{ 0, "Warn" },
			{ 0.25, "Warn" },
			{ 0.49, "Warn" },
			{ 0.5, "Blow" },
			{ 1.5, "Blow" },
			{ 2.49, "Blow" },
			{ 2.5, "Rest" },
			{ 3.99, "Rest" },
			{ 4, "Warn" },
			{ 4.6, "Blow" },
			{ 102.6, "Rest" },
		}
		for _, case in cases do
			t.eq(Logic.fanState(1, case[1]), case[2], `t {case[1]}`)
		end
	end)

	t.test("AC4: 송풍구 2는 2초 어긋나고, 두 밀기 방향은 반대이며 크기 1", function()
		for step = 0, 400 do
			local time = step * 0.05
			t.eq(Logic.fanState(2, time + 2), Logic.fanState(1, time), `t {time}`)
		end
		t.eq(Logic.fanState(2, 0), "Blow") -- 2초 어긋나서 시작 때 이미 불기 중 (선반까지 오려면 한참 걸려요)
		t.eq(Logic.fanState(2, 2), "Warn")
		local a, b = Logic.fanPush(1), Logic.fanPush(2)
		t.ok(math.abs(math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) - 1) < EPS, "fan 1 unit")
		t.ok(math.abs(math.sqrt(b.x ^ 2 + b.y ^ 2 + b.z ^ 2) - 1) < EPS, "fan 2 unit")
		t.ok(math.abs(a.x + b.x) < EPS and math.abs(a.z + b.z) < EPS and a.y == 0 and b.y == 0, "opposite")
		t.eq(a.x, 1) -- z -150 ~ -166은 +X
		t.eq(b.x, -1) -- z -186 ~ -202는 -X
		t.eq(Layout.FAN_PUSH_SPEED, 14)
		t.eq(Layout.FAN_PUSH_ACCEL, 40)
	end)

	t.test("AC4: 송풍구 구역은 D 선반 안 (fanAt)", function()
		for _, fan in Layout.FANS do
			t.ok(fan.front <= Layout.FAN_SHELF.front and fan.back >= Layout.FAN_SHELF.back, `fan {fan.index} in D`)
		end
		t.eq(Logic.fanAt(0, 15, -158), 1)
		t.eq(Logic.fanAt(-8, 15, -194), 2)
		t.eq(Logic.fanAt(0, 15, -176), nil) -- 두 송풍구 사이
		t.eq(Logic.fanAt(12, 15, -158), nil) -- 선반 밖(이미 떨어지는 중)
		t.eq(Logic.fanAt(0, 40, -158), nil) -- 높이 떠 있음
	end)

	t.test("AC4: pushDelta는 목표 속도까지만 가속하고 줄이지 않아요", function()
		t.eq(Logic.pushDelta(0, 14, 40, 0.1), 4)
		t.eq(Logic.pushDelta(12, 14, 40, 0.1), 2)
		t.eq(Logic.pushDelta(20, 14, 40, 0.1), 0)
		t.eq(Logic.pushDelta(0, -14, 40, 0.1), -4)
		t.eq(Logic.pushDelta(-20, -14, 40, 0.1), 0)
	end)

	t.test("AC5: 젤리 위 속도 72로 오르는 높이(g 196.2)가 12 이상 15 이하", function()
		t.eq(Layout.JELLY_UP, 72)
		local height = Logic.bounceHeight(Layout.JELLY_UP, GRAVITY)
		t.ok(height >= 12 and height <= 15, `height {height}`)
		-- 젤리 윗면(y 1)에서 오르면 위 칸(y 12)을 넘어요
		t.ok(Layout.JELLY_TOP + height >= Layout.HIGH_Y, "reaches the upper tier")
		t.eq(Layout.JELLY_FORWARD, 10)
		t.eq(Layout.JELLY_HOLD, 0.15)
		t.eq(Layout.JELLY_EXEMPT, 1.5)
		t.eq(Layout.JELLY_COOLDOWN, 0.6)
	end)

	t.test(
		"AC5: 젤리 3개는 8 x 8, C 바닥 위, 착지대 앞면에 붙어 있고 착지대 폭 안이에요",
		function()
			t.eq(#Layout.JELLIES, 3)
			t.eq(Layout.JELLY_SIZE, 8)
			t.eq(Layout.JELLY_TOP, 1)
			local half = Layout.JELLY_ZONE_WIDTH / 2
			local rects = Layout.jellyRects()
			for i, r in rects do
				t.ok(r.minX >= -half - EPS and r.maxX <= half + EPS, `jelly {i} inside C width`)
				t.ok(r.maxZ <= Layout.JELLY_ZONE.front and r.minZ >= Layout.LANDING.front - EPS, `jelly {i} on C floor`)
				t.ok(math.abs(r.minZ - Layout.LANDING.front) < EPS, `jelly {i} touches the landing`)
				for j = i + 1, #rects do
					t.ok(not overlaps(r, rects[j]), `jellies {i},{j} overlap`)
				end
			end
			-- jellyAt: 발판 위에 서 있으면(루트 y ~4) 그 번호, 옆 바닥·위 칸은 nil
			t.eq(Logic.jellyAt(-11, 4, -120), 1)
			t.eq(Logic.jellyAt(5, 4, -118), 3)
			t.eq(Logic.jellyAt(12, 4, -120), nil)
			t.eq(Logic.jellyAt(-3, 15, -120), nil)
		end
	)

	t.test("D·E 폭, 출발 폭, B 폭이 스펙 표 그대로", function()
		t.eq(Layout.START_WIDTH, 24)
		t.eq(Layout.ICE_TRAY_WIDTH, 22)
		t.eq(Layout.FAN_SHELF_WIDTH, 18)
		t.eq(Layout.FINISH_LINE_Z, -250)
		t.eq(Layout.HIGH_Y, 12)
		t.eq(Layout.CUBE_SIZE, 4)
		t.eq(Layout.HOLE_SIZE, 6)
		t.eq(Layout.HOLES[1].x, -5)
		t.eq(Layout.HOLES[1].z, -40)
		t.eq(Layout.HOLES[2].x, 5)
		t.eq(Layout.HOLES[2].z, -70)
	end)

	t.test("AC7: 장식이 MapKitLogic.validate 통과, 600개 이하, 소개 카메라 4점", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, `decor {MapKitLogic.count(decor)}`)
		t.eq(#Art.introCamera(), 4)
	end)

	t.test("AC8: 서버 모듈이 판정 지오메트리에 태그를 달아요 (Ice·Jelly·ColdFan)", function()
		local source = fs.readFile("src/shared/maps/DessertFridge.luau")
		t.ok(string.find(source, 'TAG_JELLY = "Jelly"', 1, true) ~= nil)
		t.ok(string.find(source, 'TAG_FAN = "ColdFan"', 1, true) ~= nil)
		t.ok(string.find(source, "IceLogic.TAG", 1, true) ~= nil)
		t.ok(string.find(source, "MoveExempt.mark", 1, true) ~= nil)
		local client = fs.readFile("src/client/input/IceController.luau")
		t.ok(string.find(client, "IceLogic.step", 1, true) ~= nil)
		t.ok(string.find(client, "RunService.Stepped", 1, true) ~= nil)
	end)
end
