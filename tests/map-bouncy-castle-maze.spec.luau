--!strict
-- m5-14 "방방 미로": 코스 치수 약속, 미로 길(격자 플러드필), 바운스 포물선 계산, 아트 예산

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)
local Logic = RobloxRequire.require(Shared.maps.BouncyCastleMazeLogic)
local Art = RobloxRequire.require(Shared.maps.BouncyCastleMazeArt)

local GRAVITY = 196.2 -- Roblox 기본 Workspace.Gravity

-- 1 stud 격자 플러드필 (4방향 이동). visited: "x,z" -> true. 열린 칸(blockedAt false)만 지나가요.
local function floodFill(startX: number, startZ: number, xMin: number, xMax: number, zMin: number, zMax: number)
	local visited: { [string]: boolean } = {}
	local function key(x: number, z: number): string
		return `{x},{z}`
	end
	local queue = { { x = startX, z = startZ } }
	visited[key(startX, startZ)] = true
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = cur.x + d[1], cur.z + d[2]
			if nx >= xMin and nx <= xMax and nz >= zMin and nz <= zMax then
				local k = key(nx, nz)
				if not visited[k] and not Logic.blockedAt(nx, nz, Layout.PARTITIONS, Layout.GATE, Layout.BOUNDS) then
					visited[k] = true
					table.insert(queue, { x = nx, z = nz })
				end
			end
		end
	end
	return visited
end

-- (x, z)가 들어 있는 통로의 폭 (같은 z에서 x를 좌우로 벽을 만날 때까지 센 칸 수, stud 단위)
local function openWidthAt(x: number, z: number): number
	local left = x
	while not Logic.blockedAt(left - 1, z, Layout.PARTITIONS, Layout.GATE, Layout.BOUNDS) do
		left -= 1
	end
	local right = x
	while not Logic.blockedAt(right + 1, z, Layout.PARTITIONS, Layout.GATE, Layout.BOUNDS) do
		right += 1
	end
	return right - left + 1
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: 풀에 등록된 Race 맵, overtime 없음", function()
		local map = Maps.get("bouncy-castle-maze")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Race")
		t.eq(map.displayName, "방방 미로")
		t.eq(type(map.overtime), "nil")
	end)

	t.test("AC1: 스폰 24개가 전부 A 구간 바닥 위이고 서로 3 studs 이상 떨어져 있어요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, 24)
		for i, pos in spawns do
			t.ok(math.abs(pos.x) + 1 <= Layout.HALF_WIDTH, `spawn {i} x {pos.x} outside course`)
			t.ok(pos.z < Layout.START.front and pos.z > Layout.START.back, `spawn {i} z {pos.z} outside start`)
			for j, other in spawns do
				if i ~= j then
					local dist = math.sqrt((pos.x - other.x) ^ 2 + (pos.z - other.z) ^ 2)
					t.ok(dist >= 3, `spawn {i}/{j} too close ({dist})`)
				end
			end
		end
	end)

	---------------------------------------------------------------- AC2
	t.test(
		"AC2: 구간이 출발→결승 순서로 빈틈없이 이어지고, 진행도(-Z)가 출발(0)에서 결승(134)으로 커져요",
		function()
			local order = { Layout.START, Layout.ANTEROOM, Layout.MAZE, Layout.EXIT, Layout.FINISH }
			t.eq(order[1].front, 0)
			for i, span in order do
				t.ok(span.front > span.back, `section {i} must extend toward -Z`)
				if i > 1 then
					t.eq(span.front, order[i - 1].back, `section {i} must start where {i - 1} ends`)
				end
			end
			t.eq(-Layout.finishLineZ(), 134)
			t.ok(Layout.finishLineZ() < Layout.FINISH.front and Layout.finishLineZ() > Layout.FINISH.back)
			t.eq(Layout.WIDTH, 40)
		end
	)

	t.test("AC2: fallLineAt은 전 구간 동일한 상수(바닥 - 40)예요", function()
		for _, z in { 0, -16, -18, -60, -105, -115, -130 } do
			t.eq(Logic.fallLineAt(z), -40, `fallLineAt({z})`)
		end
	end)

	---------------------------------------------------------------- AC3
	t.test(
		"AC3: 1번 레인 입구에서 출구 직전까지 미로 길이 있고, 가장 좁은 통과 지점도 8 studs 이상",
		function()
			local visited = floodFill(-15, -19, Layout.BOUNDS.xMin + 1, Layout.BOUNDS.xMax - 1, -109, -19)
			t.ok(visited["15,-109"], "entrance to just-before-exit must be reachable")

			-- 방문한 칸 중 가장 좁은 통과 지점(그 칸이 속한 통로의 폭)
			local narrowest = math.huge
			for k in visited do
				local xs, zs = string.match(k, "(-?%d+),(-?%d+)")
				local x, z = tonumber(xs) :: number, tonumber(zs) :: number
				local width = openWidthAt(x, z)
				if width < narrowest then
					narrowest = width
				end
			end
			t.ok(narrowest >= 8, `narrowest passage {narrowest}`)
		end
	)

	t.test("AC3: 레인 진행 순서가 1→2→3→4로 S자를 두 번 꺾어요 (칸막이 표)", function()
		t.eq(#Layout.PARTITIONS, 3)
		t.eq(Layout.PARTITIONS[1].x, -10)
		t.eq(Layout.PARTITIONS[1].blockedZLow, -100) -- 틈은 출구 쪽 (z -100~-110)
		t.eq(Layout.PARTITIONS[2].x, 0)
		t.eq(Layout.PARTITIONS[2].blockedZHigh, -30) -- 틈은 입구 쪽 (z -20~-30)
		t.eq(Layout.PARTITIONS[3].x, 10)
		t.eq(Layout.PARTITIONS[3].blockedZLow, -100) -- 틈은 출구 쪽
		t.eq(#Layout.LANES, 4)
		t.eq(Layout.LANES, { -15, -5, 5, 15 })
	end)

	---------------------------------------------------------------- AC4
	t.test(
		"AC4: 대기실에서 1번 레인을 거치지 않고 2·3·4번 레인으로 바로 못 넘어가요 (입구 문)",
		function()
			local gate = Layout.GATE
			-- 관문 폭 전체(z = gate.z 근처)에서, 1번 레인 범위 밖은 전부 막혀 있어요.
			for z = gate.z - gate.thickness / 2, gate.z + gate.thickness / 2 do
				for x = gate.openXMax + 1, Layout.BOUNDS.xMax - 1 do
					t.ok(
						Logic.blockedAt(x, z, Layout.PARTITIONS, Layout.GATE, Layout.BOUNDS),
						`gate must block x={x} z={z}`
					)
				end
			end
			-- 1번 레인 범위(입구 문이 열린 폭)는 막혀 있지 않아요.
			for x = gate.openXMin + 1, gate.openXMax - 1 do
				t.ok(
					not Logic.blockedAt(x, gate.z, Layout.PARTITIONS, Layout.GATE, Layout.BOUNDS),
					`lane 1 opening must stay open at x={x}`
				)
			end

			-- 대기실 쪽(x -10~20, 1번 레인 밖)에서 격자 플러드필을 돌리면 관문 두께 밖(z < gate.z - thickness/2)으로는
			-- 절대 못 나가요. 이 구역은 x를 -10 이상(1번 레인 제외)으로 묶어서 돌리니, 닿는다면 입구 문이 새는 거예요.
			local blockedZ = gate.z - gate.thickness / 2 - 1
			local visited =
				floodFill(0, -18, gate.openXMax + 1, Layout.BOUNDS.xMax - 1, blockedZ, Layout.ANTEROOM.front - 1)
			t.ok(not visited[`0,{blockedZ}`], "door-blocked side must not leak past the gate")
			local reachedBeyond = false
			for k in visited do
				local _, zs = string.match(k, "(-?%d+),(-?%d+)")
				if tonumber(zs) :: number <= blockedZ then
					reachedBeyond = true
				end
			end
			t.ok(not reachedBeyond, "door-blocked side must stay inside the anteroom")
		end
	)

	---------------------------------------------------------------- AC5
	t.test(
		"AC5: bounceProfile(55, 196.2) ≈ apex 7.71 / flightTime 0.560, 벽 높이는 apex의 1.5배 이상",
		function()
			local profile = Logic.bounceProfile(55, GRAVITY)
			t.ok(math.abs(profile.apex - 7.71) / 7.71 <= 0.03, `apex {profile.apex}`)
			t.ok(math.abs(profile.flightTime - 0.560) / 0.560 <= 0.03, `flightTime {profile.flightTime}`)
			t.ok(
				Layout.WALL_HEIGHT >= profile.apex * 1.5,
				`wall height {Layout.WALL_HEIGHT} vs apex*1.5 {profile.apex * 1.5}`
			)
		end
	)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: 쿨다운은 비행시간보다 짧고(끊김 없는 연속 바운스), 면제는 비행시간보다 길어요",
		function()
			local flightTime = Logic.bounceProfile(Layout.BOUNCE_UP_SPEED, GRAVITY).flightTime
			t.ok(Layout.BOUNCE_COOLDOWN < flightTime, `cooldown {Layout.BOUNCE_COOLDOWN} vs flight {flightTime}`)
			t.ok(Layout.BOUNCE_EXEMPT > flightTime, `exempt {Layout.BOUNCE_EXEMPT} vs flight {flightTime}`)
		end
	)

	---------------------------------------------------------------- AC7
	t.test(
		"AC7: 장식이 MapKitLogic.validate 통과, 파츠·파티클·조명 예산 안, inPool이 없거나 true",
		function()
			local decor = Art.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.ok(
				MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET,
				`decor part count {MapKitLogic.count(decor)}`
			)

			local lampCount = 0
			for _, spec in decor do
				if spec.name == Art.LAMP then
					lampCount += 1
				end
			end
			t.ok(lampCount <= MapKitLogic.LIGHT_BUDGET, "lamp light budget")
			t.ok(lampCount > 0, "at least one carnival lamp")

			local map = Maps.get("bouncy-castle-maze")
			t.ok(map.inPool == nil or map.inPool == true, "bouncy-castle-maze must stay in the random pool")
		end
	)

	t.test("AC7: 소개 카메라 4점", function()
		t.eq(#Art.introCamera(), 4)
	end)
end
