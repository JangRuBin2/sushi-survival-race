--!strict
-- m3-04 QA: IntroCameraLogic 경계값 · 속성 검사 (방향 여러 개, 납작한/긴 맵, 스폰 위치, 입력 불변)

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

local function top(bounds): number
	return bounds.center.y + bounds.size.y / 2
end

local function finite(v: Vec): boolean
	for _, n in { v.x, v.y, v.z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

-- 스폰이 경계 상자의 한쪽 끝에 있고 코스가 forward로 length만큼 뻗은 Race 맵
local function raceCase(forward: Vec, length: number, width: number, height: number)
	local start = vec(1000, 300, 500)
	local center = vec(start.x + forward.x * length / 2, start.y + height / 2, start.z + forward.z * length / 2)
	local sizeX = math.abs(forward.x) * length + math.abs(forward.z) * width
	local sizeZ = math.abs(forward.z) * length + math.abs(forward.x) * width
	return { center = center, size = vec(sizeX, height, sizeZ) }, { position = start, forward = forward }
end

-- origin 로컬 Z (forward = 로컬 -Z)
local function localZ(origin, p: Vec): number
	return -dot(sub(p, origin.position), unit(vec(origin.forward.x, 0, origin.forward.z)))
end

local DIRECTIONS = { vec(0, 0, -1), vec(0, 0, 1), vec(1, 0, 0), vec(-1, 0, 0) }

return function(t: Test.Test)
	t.test("QA AC1·AC2: Race 규칙이 네 방향·짧은/긴 코스 모두에서 지켜져요", function()
		for _, forward in DIRECTIONS do
			for _, length in { 30, 200, 600 } do
				local bounds, origin = raceCase(forward, length, 40, 20)
				local path = Logic.autoPath(bounds, origin, "Race")
				local midZ = localZ(origin, bounds.center)
				local first, last = path[1], path[#path]
				local label = `fwd=({forward.x},{forward.z}) len={length}`
				t.ok(localZ(origin, first.position) < midZ, `{label}: first on finish half`)
				t.ok(localZ(origin, last.position) > midZ, `{label}: last on spawn half`)
				t.ok(localZ(origin, last.position) > 0, `{label}: last is behind the spawn`)
				local look = sub(last.lookAt, last.position)
				t.ok(-dot(look, origin.forward) < 0, `{label}: last looks down the course`)
				for i, w in path do
					t.ok(w.position.y > top(bounds), `{label}: waypoint {i} above top`)
					t.ok(finite(w.position) and finite(w.lookAt), `{label}: waypoint {i} finite`)
				end
			end
		end
	end)

	t.test(
		"QA AC1: 스폰 뒤로도 파츠가 있는 맵(출발 대기 발판)에서도 첫 점은 결승 쪽이에요",
		function()
			-- 스폰 뒤 40 studs까지 발판이 있고 앞으로 160 studs 코스
			local origin = { position = vec(0, 300, 0), forward = vec(0, 0, -1) }
			local bounds = { center = vec(0, 305, -60), size = vec(40, 10, 200) }
			local path = Logic.autoPath(bounds, origin, "Race")
			t.ok(path[1].position.z < bounds.center.z, "first on the finish half")
			t.ok(path[#path].position.z > bounds.center.z, "last on the spawn half")
		end
	)

	t.test(
		"QA: forward에 기울기(Y)가 있거나 0벡터여도 NaN 없이 수평 기준으로 경로를 만들어요",
		function()
			local bounds = { center = vec(0, 10, -100), size = vec(40, 20, 200) }
			local tilted = Logic.autoPath(bounds, { position = vec(0, 0, 0), forward = vec(0, 0.6, -0.8) }, "Race")
			t.ok(tilted[1].position.z < -100, "tilted forward still uses horizontal -Z")
			for _, kind in { "Race", "Survival", "Final" } do
				local path = Logic.autoPath(bounds, { position = vec(0, 0, 0), forward = vec(0, 0, 0) }, kind :: any)
				for i, w in path do
					t.ok(finite(w.position) and finite(w.lookAt), `{kind} zero forward waypoint {i} finite`)
				end
			end
		end
	)

	t.test(
		"QA AC2·AC3: 납작하거나(높이 0) 길쭉한 Survival·Final 맵도 위에서 중심을 봐요",
		function()
			local cases = {
				{ center = vec(0, 300, 0), size = vec(80, 0, 80) },
				{ center = vec(500, 320, -40), size = vec(160, 40, 30) },
				{ center = vec(-200, 280, 90), size = vec(10, 120, 10) }, -- 높은 꼬치 기둥
			}
			for ci, bounds in cases do
				for _, kind in { "Survival", "Final" } do
					for _, forward in DIRECTIONS do
						local origin = { position = vec(bounds.center.x, 300, bounds.center.z), forward = forward }
						local path = Logic.autoPath(bounds, origin, kind :: any)
						t.ok(#path >= 3, `case {ci} {kind} orbit`)
						for i, w in path do
							t.ok(w.position.y > top(bounds), `case {ci} {kind} waypoint {i} above top`)
							local look = unit(sub(w.lookAt, w.position))
							local toCenter = unit(sub(bounds.center, w.position))
							t.ok(dot(look, toCenter) > 0.9, `case {ci} {kind} waypoint {i} looks at center`)
							-- 궤도는 맵 바깥(수평) 위를 돌아요
							local dx, dz = w.position.x - bounds.center.x, w.position.z - bounds.center.z
							t.ok(
								math.sqrt(dx * dx + dz * dz) >= math.max(bounds.size.x, bounds.size.z) / 2,
								`case {ci} {kind} waypoint {i} outside footprint`
							)
						end
					end
				end
			end
		end
	)

	t.test(
		"QA AC3: 스폰이 가운데 모이면 forward 반대쪽(코스 시작 쪽)에서 반 바퀴가 끝나요",
		function()
			local bounds = { center = vec(0, 300, 0), size = vec(80, 20, 80) }
			for _, forward in DIRECTIONS do
				local path = Logic.autoPath(bounds, { position = vec(0, 290, 0), forward = forward }, "Survival")
				local last = path[#path].position
				local dir = unit(vec(last.x, 0, last.z))
				t.ok(dot(dir, forward) < -0.99, `fwd=({forward.x},{forward.z}) ends on the back side`)
				local first = unit(vec(path[1].position.x, 0, path[1].position.z))
				t.ok(dot(first, dir) < -0.95, "half orbit (start opposite end)")
			end
		end
	)

	t.test(
		"QA AC4: sample은 t에 대해 경로상 진행 거리가 줄지 않아요 (되돌아가지 않음)",
		function()
			local bounds, origin = raceCase(vec(1, 0, 0), 300, 40, 20)
			local paths = {
				Logic.autoPath(bounds, origin, "Race"),
				Logic.autoPath({ center = vec(0, 300, 0), size = vec(80, 20, 80) }, origin, "Final"),
			}
			for pi, path in paths do
				-- 각 샘플을 폴리라인에 투영해 누적 거리(arc length)를 구하고 단조 증가인지 봐요
				local function arcOf(p: Vec): number
					local best, bestArc = math.huge, 0
					local acc = 0
					for i = 1, #path - 1 do
						local a, b = path[i].position, path[i + 1].position
						local ab = sub(b, a)
						local l2 = dot(ab, ab)
						local s = if l2 > 0 then math.clamp(dot(sub(p, a), ab) / l2, 0, 1) else 0
						local q = vec(a.x + ab.x * s, a.y + ab.y * s, a.z + ab.z * s)
						local d = len(sub(p, q))
						if d < best then
							best, bestArc = d, acc + s * math.sqrt(l2)
						end
						acc += math.sqrt(l2)
					end
					return bestArc
				end
				local prev = -1
				for step = 0, 100 do
					local arc = arcOf(Logic.sample(path, step / 100).position)
					t.ok(arc >= prev - 1e-6, `path {pi} step {step}: arc {arc} >= {prev}`)
					prev = arc
				end
			end
		end
	)

	t.test(
		"QA: autoPath·sample은 입력을 바꾸지 않고, sample 결과를 고쳐도 경로가 안 바뀌어요",
		function()
			local bounds = { center = vec(0, 305, -100), size = vec(40, 10, 200) }
			local origin = { position = vec(0, 300, 0), forward = vec(0, 0, -1) }
			Logic.autoPath(bounds, origin, "Race")
			Logic.autoPath(bounds, origin, "Final")
			t.eq(bounds, { center = vec(0, 305, -100), size = vec(40, 10, 200) })
			t.eq(origin, { position = vec(0, 300, 0), forward = vec(0, 0, -1) })

			local path = Logic.autoPath(bounds, origin, "Race")
			local endX = path[#path].position.x
			local s = Logic.sample(path, 1)
			s.position.x = 9999
			t.eq(path[#path].position.x, endX, "sample(1) must not alias the last waypoint")
			local one = { { position = vec(1, 2, 3), lookAt = vec(0, 0, 0) } }
			Logic.sample(one, 0).position.x = 9999
			t.eq(one[1].position.x, 1, "single-waypoint sample is a copy")
		end
	)

	t.test("QA: 빈 경로 sample은 에러예요 (컨트롤러는 #path == 0이면 건너뜀)", function()
		t.throws(function()
			Logic.sample({}, 0.5)
		end)
	end)

	t.test("QA: ease는 0~1에서 단조 증가하고 범위 밖은 끝값이에요", function()
		local prev = -1
		for i = 0, 100 do
			local v = Logic.ease(i / 100)
			t.ok(v >= prev, `ease monotonic at {i}`)
			prev = v
		end
		t.eq(Logic.ease(-3), 0)
		t.eq(Logic.ease(7), 1)
	end)
end
