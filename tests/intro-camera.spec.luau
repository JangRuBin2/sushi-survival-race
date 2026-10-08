--!strict
-- m3-04: 라운드 소개 플라이스루 자동 경로 (IntroCameraLogic)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.IntroCameraLogic)

type Vec = { x: number, y: number, z: number }

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function sub(a: Vec, b: Vec): Vec
	return vec(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function dot(a: Vec, b: Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function len(a: Vec): number
	return math.sqrt(dot(a, a))
end

local function unit(a: Vec): Vec
	local l = len(a)
	return vec(a.x / l, a.y / l, a.z / l)
end

-- origin(스폰) 앞쪽(-Z)으로 200 studs 뻗은 Race 코스. 바닥 y=300, 높이 20.
local RACE_ORIGIN = { position = vec(2000, 300, 0), forward = vec(0, 0, -1) }
local RACE_BOUNDS = { center = vec(2000, 310, -100), size = vec(40, 20, 200) }
-- 원형 Survival 맵 (지름 80, 높이 30)
local ARENA_ORIGIN = { position = vec(4000, 300, 0), forward = vec(0, 0, -1) }
local ARENA_BOUNDS = { center = vec(4000, 310, 0), size = vec(80, 30, 80) }

-- origin 로컬 Z (forward = 로컬 -Z)
local function localZ(origin, p: Vec): number
	return -dot(sub(p, origin.position), origin.forward)
end

local function top(bounds): number
	return bounds.center.y + bounds.size.y / 2
end

return function(t: Test.Test)
	t.test("AC1: Race는 코스 끝 쪽에서 시작해 스폰 쪽에서 코스 방향을 보며 끝나요", function()
		local path = Logic.autoPath(RACE_BOUNDS, RACE_ORIGIN, "Race")
		t.ok(#path >= 2, "at least two waypoints")
		local midZ = localZ(RACE_ORIGIN, RACE_BOUNDS.center)
		local first, last = path[1], path[#path]
		t.ok(localZ(RACE_ORIGIN, first.position) < midZ, "first waypoint on the far (finish) half")
		t.ok(localZ(RACE_ORIGIN, last.position) > midZ, "last waypoint on the spawn half")
		local look = sub(last.lookAt, last.position)
		t.ok(-dot(look, RACE_ORIGIN.forward) < 0, "last waypoint looks down the course (local Z < 0)")
	end)

	t.test("AC1: 코스 방향이 +X여도 같은 규칙이에요", function()
		local origin = { position = vec(0, 0, 0), forward = vec(1, 0, 0) }
		local bounds = { center = vec(100, 5, 0), size = vec(200, 10, 40) }
		local path = Logic.autoPath(bounds, origin, "Race")
		t.ok(path[1].position.x > 100, "first on the far half")
		t.ok(path[#path].position.x < 100, "last on the spawn half")
		t.ok(path[#path].lookAt.x > path[#path].position.x, "last looks along +X")
	end)

	t.test("AC2: 모든 자동 경유점이 경계 상자 꼭대기보다 높아요", function()
		for _, case in
			{
				{ RACE_BOUNDS, RACE_ORIGIN, "Race" },
				{ ARENA_BOUNDS, ARENA_ORIGIN, "Survival" },
				{ ARENA_BOUNDS, ARENA_ORIGIN, "Final" },
			}
		do
			local bounds, origin, kind = case[1] :: any, case[2] :: any, case[3] :: any
			for i, waypoint in Logic.autoPath(bounds, origin, kind) do
				t.ok(waypoint.position.y > top(bounds), `{kind} waypoint {i} above top`)
			end
		end
	end)

	t.test("AC3: Survival·Final 경로는 모든 점에서 경계 중심을 바라봐요", function()
		for _, kind in { "Survival", "Final" } do
			local path = Logic.autoPath(ARENA_BOUNDS, ARENA_ORIGIN, kind :: any)
			t.ok(#path >= 3, `{kind} has an orbit`)
			for i, waypoint in path do
				local look = unit(sub(waypoint.lookAt, waypoint.position))
				local toCenter = unit(sub(ARENA_BOUNDS.center, waypoint.position))
				t.ok(dot(look, toCenter) > 0.9, `{kind} waypoint {i} looks at the center`)
			end
		end
	end)

	t.test("AC3: 반 바퀴(약 180도) 돌고 스폰 쪽(origin 뒤쪽)에서 끝나요", function()
		local path = Logic.autoPath(ARENA_BOUNDS, ARENA_ORIGIN, "Survival")
		local c = ARENA_BOUNDS.center
		local a = unit(vec(path[1].position.x - c.x, 0, path[1].position.z - c.z))
		local b = unit(vec(path[#path].position.x - c.x, 0, path[#path].position.z - c.z))
		t.ok(dot(a, b) < -0.95, "start and end are opposite")
		t.ok(path[#path].position.z > c.z, "ends behind the origin (spawn side)")
	end)

	t.test("AC3: 스폰이 한쪽에 모여 있으면 그쪽 위에서 끝나요", function()
		local origin = { position = vec(4000, 300, 35), forward = vec(0, 0, -1) }
		local spawnSide = { position = vec(4035, 300, 0), forward = vec(0, 0, -1) }
		local path = Logic.autoPath(ARENA_BOUNDS, origin, "Final")
		t.ok(path[#path].position.z > ARENA_BOUNDS.center.z + 30, "ends above the +Z spawn side")
		local path2 = Logic.autoPath(ARENA_BOUNDS, spawnSide, "Final")
		t.ok(path2[#path2].position.x > ARENA_BOUNDS.center.x + 30, "ends above the +X spawn side")
	end)

	t.test("AC4: sample(0) = 첫 경유점, sample(1) = 마지막 경유점", function()
		for _, case in
			{
				{ RACE_BOUNDS, RACE_ORIGIN, "Race" },
				{ ARENA_BOUNDS, ARENA_ORIGIN, "Survival" },
			}
		do
			local path = Logic.autoPath(case[1] :: any, case[2] :: any, case[3] :: any)
			local s0, s1 = Logic.sample(path, 0), Logic.sample(path, 1)
			t.ok(len(sub(s0.position, path[1].position)) <= 0.01, "t=0 position")
			t.ok(len(sub(s1.position, path[#path].position)) <= 0.01, "t=1 position")
			t.ok(len(sub(s0.lookAt, path[1].lookAt)) <= 0.01, "t=0 lookAt")
			t.ok(len(sub(s1.lookAt, path[#path].lookAt)) <= 0.01, "t=1 lookAt")
			-- 범위 밖 t는 끝에 붙어요
			t.ok(len(sub(Logic.sample(path, -1).position, path[1].position)) <= 0.01, "t<0 clamps")
			t.ok(len(sub(Logic.sample(path, 2).position, path[#path].position)) <= 0.01, "t>1 clamps")
		end
	end)

	t.test("AC4: t가 커질수록 경로를 따라 앞으로만 가요", function()
		for _, case in
			{
				{ RACE_BOUNDS, RACE_ORIGIN, "Race" },
				{ ARENA_BOUNDS, ARENA_ORIGIN, "Final" },
			}
		do
			local path = Logic.autoPath(case[1] :: any, case[2] :: any, case[3] :: any)
			local polyline = 0
			for i = 1, #path - 1 do
				polyline += len(sub(path[i + 1].position, path[i].position))
			end
			-- 되돌아가면 이동 거리 합이 경로 길이보다 길어져요
			local travelled = 0
			local prev = Logic.sample(path, 0)
			local steps = 200
			for step = 1, steps do
				local cur = Logic.sample(path, step / steps)
				travelled += len(sub(cur.position, prev.position))
				t.ok(travelled <= polyline + 1e-6, "never travels more than the path length")
				prev = cur
			end
			-- 샘플이 경유점 모서리를 살짝 질러가는 만큼만 짧아요
			t.ok(travelled > polyline * 0.99, `travelled {travelled} ~= path {polyline}`)
		end
	end)

	t.test("AC4: 경유점 하나·위치가 겹친 경유점도 처리해요", function()
		local one = { { position = vec(1, 2, 3), lookAt = vec(0, 0, 0) } }
		t.eq(Logic.sample(one, 0.5).position.y, 2)
		local dup = {
			{ position = vec(0, 10, 0), lookAt = vec(0, 0, 0) },
			{ position = vec(0, 10, 0), lookAt = vec(0, 0, -5) },
			{ position = vec(0, 10, -10), lookAt = vec(0, 0, -10) },
		}
		t.ok(len(sub(Logic.sample(dup, 1).position, vec(0, 10, -10))) <= 0.01, "reaches the end")
	end)

	t.test("ease는 0~1 가감속이에요", function()
		t.eq(Logic.ease(0), 0)
		t.eq(Logic.ease(1), 1)
		t.eq(Logic.ease(0.5), 0.5)
		t.ok(Logic.ease(0.1) < 0.1, "slow start")
		t.ok(Logic.ease(0.9) > 0.9, "slow end")
	end)
end
