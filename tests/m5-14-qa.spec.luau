--!strict
-- m5-14 QA(docs/qa/m5-14-map-bouncy-castle-maze.md): 바운스 실제 궤적(유지 시간 포함), 레이캐스트 길이,
-- 이동 감시 여유, 구간·스폰, 서버 코드 점검. (미로 출구 지름길 B1은 리포트 참고 — 실패 테스트로 넣지 않음)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)
local Logic = RobloxRequire.require(Shared.maps.BouncyCastleMazeLogic)

local SOURCE_PATH = "src/shared/maps/BouncyCastleMaze.luau"
local GRAVITY = 196.2
local STAND_ROOT_Y = 3 -- 서 있을 때 바닥 기준 루트 높이 (기본 R15 블록 몸: HipHeight 2 + 루트 반높이 1, R6도 3)

local function countMatches(source: string, pattern: string): number
	local n = 0
	for _ in string.gmatch(source, pattern) do
		n += 1
	end
	return n
end

-- 서버는 BOUNCE_HOLD초 동안 위 속도를 BOUNCE_UP_SPEED로 고정한 뒤 놓아요. 그 구간의 상승까지 넣은 실제 궤적.
local function realBounce(): (number, number)
	local v = Layout.BOUNCE_UP_SPEED
	local holdRise = v * Layout.BOUNCE_HOLD
	local profile = Logic.bounceProfile(v, GRAVITY)
	local apex = holdRise + profile.apex
	local riseTime = v / GRAVITY
	local fallTime = math.sqrt(2 * apex / GRAVITY)
	return apex, Layout.BOUNCE_HOLD + riseTime + fallTime
end

return function(t: Test.Test)
	t.test(
		"m5-14 QA: 유지 시간까지 넣은 실제 정점(+공중 다이브 여유)도 벽 높이 14보다 낮아요",
		function()
			local apex = realBounce()
			-- 공중 다이브는 위 속도를 AirMaxUpSpeed까지만 남겨요 → 정점에서 더 오를 수 있는 높이
			local diveExtra = Config.Dive.AirMaxUpSpeed ^ 2 / (2 * GRAVITY)
			t.ok(apex > 11 and apex < 13, `real apex {apex}`)
			t.ok(apex + diveExtra < Layout.WALL_HEIGHT, `feet apex {apex + diveExtra} vs wall {Layout.WALL_HEIGHT}`)
		end
	)

	t.test("m5-14 QA: 실제 비행 시간은 쿨다운보다 길고 면제(0.8초)보다 짧아요", function()
		local _, flight = realBounce()
		t.ok(Layout.BOUNCE_COOLDOWN < flight, `cooldown {Layout.BOUNCE_COOLDOWN} vs real flight {flight}`)
		t.ok(Layout.BOUNCE_EXEMPT > flight, `exempt {Layout.BOUNCE_EXEMPT} vs real flight {flight}`)
	end)

	t.test(
		"m5-14 QA: 발밑 레이캐스트는 서 있으면 바닥에 닿고, 정점 근처에서는 안 닿아요",
		function()
			t.ok(STAND_ROOT_Y < Layout.BOUNCE_RAYCAST_LENGTH, "standing root must reach floor")
			local apex = realBounce()
			t.ok(STAND_ROOT_Y + apex > Layout.BOUNCE_RAYCAST_LENGTH * 2, "airborne root must not re-trigger")
		end
	)

	t.test(
		"m5-14 QA: 바운스 위 속도는 이동 감시 상승 상한보다 작아요 (면제가 없어도 안 걸림)",
		function()
			t.ok(Layout.BOUNCE_UP_SPEED < Config.MovementGuard.MaxRiseSpeed)
		end
	)

	t.test(
		"m5-14 QA: 바운스 바닥은 B+C(z -16~-110)만, 스폰은 전부 A 구간(일반 바닥)이고 벽에서 1 이상",
		function()
			t.eq(Layout.ANTEROOM.front, Layout.START.back)
			t.eq(Layout.MAZE.front, Layout.ANTEROOM.back)
			t.eq(Layout.EXIT.front, Layout.MAZE.back)
			t.eq(Layout.FINISH.front, Layout.EXIT.back)
			t.ok(Layout.FINISH_LINE_Z < Layout.FINISH.front and Layout.FINISH_LINE_Z > Layout.FINISH.back)
			for i, pos in Layout.spawnPositions() do
				t.ok(pos.z < Layout.START.front - 1 and pos.z > Layout.START.back + 1, `spawn {i} z {pos.z}`)
				t.ok(math.abs(pos.x) <= Layout.HALF_WIDTH - 1, `spawn {i} x {pos.x}`)
			end
			local source = fs.readFile(SOURCE_PATH)
			t.ok(
				string.find(
					source,
					'floorSlab("FloorBounce", Layout.ANTEROOM.front, Layout.MAZE.back, COLORS.bounceFloor, true)',
					1,
					true
				) ~= nil,
				"bounce slab spans B+C only"
			)
			t.eq(countMatches(source, "COLORS%.%w+, true%)"), 1) -- 태그 붙은 바닥은 한 장
		end
	)

	t.test(
		"m5-14 QA: 칸막이 틈·관문 열린 폭은 레인 폭(10) 그대로, 칸막이는 레인 경계 위",
		function()
			t.eq(Layout.GATE.openXMax - Layout.GATE.openXMin, Layout.LANE_WIDTH)
			for i, partition in Layout.PARTITIONS do
				local boundary = (Layout.LANES[i] + Layout.LANES[i + 1]) / 2
				t.eq(partition.x, boundary, `partition {i} on lane boundary`)
				local gapHigh = Layout.MAZE.front - partition.blockedZHigh
				local gapLow = partition.blockedZLow - Layout.MAZE.back
				t.eq(math.max(gapHigh, gapLow), Layout.LANE_WIDTH, `partition {i} gap`)
				t.eq(math.min(gapHigh, gapLow), 0, `partition {i} single gap`)
			end
		end
	)

	t.test(
		"m5-14 QA 서버: 태그는 ctx.model 하위만, 모듈 수준 가변 상태 없음, 리모트 없음",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil, "filters by ctx.model")
			t.eq(countMatches(source, "GetTagged%("), 1)
			t.eq(countMatches(source, "OnServerEvent"), 0)
			t.eq(countMatches(source, "Remotes"), 0)
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function ") then
					local ok = string.find(line, "require(", 1, true)
						or string.match(line, '^local [%u_]+ = [%d%.%-"]')
						or string.match(line, "^local BouncyCastleMaze: MapTypes%.MapModule")
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	t.test(
		"m5-14 QA 서버: 판정은 ctx.pass/ctx.eliminate만, 바운스마다 MoveExempt, 연결·스레드는 ctx.cleanup",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.eq(countMatches(source, "ctx%.pass%("), 1)
			t.eq(countMatches(source, "ctx%.eliminate%("), 1)
			t.ok(
				string.find(source, "MoveExempt.mark(character, Layout.BOUNCE_EXEMPT)", 1, true) ~= nil,
				"exempt per bounce"
			)
			local connected = countMatches(source, ":Connect%(")
			local delayed = countMatches(source, "task%.delay%(") + countMatches(source, "task%.spawn%(")
			t.eq(connected, 1)
			-- m5-14 B3 수정 뒤: 바운스마다 task.delay를 만들지 않고, 루트마다 LinearVelocity 하나를 켜고 꺼요
			t.eq(delayed, 0)
			t.ok(string.find(source, "ctx.cleanup:add(RunService.Heartbeat:Connect(", 1, true) ~= nil)
			t.ok(string.find(source, "ctx.cleanup:add(push)", 1, true) ~= nil)
			t.ok(string.find(source, "releaseBounces()", 1, true) ~= nil, "hold released every frame")
			-- 판정 뒤 남은 레이서에게만 바운스
			local judge = string.find(source, "ctx.eliminate(player)", 1, true) :: number
			local bounce = string.find(source, "stepBounce(ctx.getRacers())", 1, true) :: number
			t.ok(judge ~= nil and bounce ~= nil and judge < bounce, "bounce after judgment")
		end
	)
end
