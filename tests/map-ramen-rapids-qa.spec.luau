--!strict
-- m4-04 QA(docs/qa/m4-04-map-ramen-rapids.md)에서 추가한 테스트: 스폰이 바닥 위(m4-01 QA B1 고정),
-- 시간을 따라 실제로 건널 수 있는지(차슈 잠김 타이밍), 막다른 차슈 없음, 낙하선·결승·태그·모듈 상태.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local Logic = RobloxRequire.require(Shared.maps.RamenRapidsLogic)

local SOURCE_PATH = "src/shared/maps/RamenRapids.luau"
local GRAVITY = 196.2
local SPAWN_PAD = 3 -- build의 Spawn 파트 크기 (3 x 3)
local BODY_HALF_WIDTH = 1 -- 캐릭터 몸 반폭 (근사)
local HOP_TIME = 0.8 -- 발판 사이 한 번 뛰는 데 드는 시간 (보수적으로)
local LAND_GRACE = 0.6 -- 착지 뒤 다음 판단까지 발판이 떠 있어야 하는 시간
local STEP = 0.1

local function airtime(): number
	return 2 * Config.Character.JumpPower / GRAVITY
end

return function(t: Test.Test)
	---------------------------------------------------------------- 스폰 (m4-01 QA B1)
	t.test(
		"B1 고정: 스폰 24개 발판(3x3)과 캐릭터 몸이 전부 출발 바닥 안에 1 stud 이상 여유",
		function()
			local spawns = Layout.spawnPositions()
			t.eq(#spawns, 24)
			local halfWidth = Layout.START_WIDTH / 2
			local margin = math.max(SPAWN_PAD / 2, BODY_HALF_WIDTH)
			for i, s in spawns do
				-- 좌우: 바닥 끝(그리고 낮은 벽)에서 1 stud 이상 안쪽
				t.ok(math.abs(s.x) + margin + 1 <= halfWidth, `spawn {i} x {s.x} too close to side`)
				-- 앞뒤: 출발 바닥 z ∈ [START.back, START.front] 안, 출발 뒤 벽(z = front)과 급류 시작에서 1 이상
				t.ok(s.z + margin + 1 <= Layout.START.front, `spawn {i} z {s.z} too close to start wall`)
				t.ok(s.z - margin - 1 >= Layout.START.back, `spawn {i} z {s.z} hangs over the rapids edge`)
			end
		end
	)

	t.test(
		"B1 고정: build가 Layout.spawnPositions와 START 구간 바닥(윗면 y=0)을 그대로 써요",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.ok(string.find(source, "Layout.spawnPositions()", 1, true) ~= nil, "spawns from Layout")
			t.ok(string.find(source, "at(pos.x, 0.1, pos.z)", 1, true) ~= nil, "spawn pads on floor top y=0")
			t.ok(
				string.find(source, "local startDepth = Layout.START.front - Layout.START.back", 1, true) ~= nil,
				"start floor spans START section"
			)
			t.ok(
				string.find(source, "CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, startCenter)", 1, true) ~= nil,
				"start floor top at y=0"
			)
			-- 스폰 수는 최대 방 인원과 같아야 해요 (build의 assert)
			t.eq(#Layout.spawnPositions(), Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		end
	)

	---------------------------------------------------------------- 토핑 구간: 시간을 따라 건너기
	t.test("AC2 보강: 발판 사이 최대 빈틈 7이 실제 달리기 점프 거리(같은 높이) 안", function()
		local reach = Config.Character.WalkSpeed * airtime()
		t.ok(Layout.MAX_JUMP_GAP <= reach - 1, `MAX_JUMP_GAP {Layout.MAX_JUMP_GAP} vs reach {reach}`)
		-- 차슈 가장 높을 때(수면 + 2.5)도 나루토·회전 발판(수면 + 1)에서 올라갈 수 있어요
		local jumpHeight = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
		local rise = (Layout.BROTH_Y + Layout.CHASHU_LOW + Layout.CHASHU_RANGE) - Layout.narutoTop()
		t.ok(rise + 1 <= jumpHeight, `rise {rise} vs jump {jumpHeight}`)
	end)

	t.test(
		"AC2 보강: 막다른 차슈 없음 — 모든 차슈 옆 7 이내에 가라앉지 않는 발판(나루토/회전 발판)이 있어요",
		function()
			local platforms = Logic.platforms()
			for _, p in platforms do
				if p.kind == "Chashu" then
					local safe = Logic.gapToSweeperPlatform(p.x, p.z, p.radius) <= Layout.MAX_JUMP_GAP
					for _, q in platforms do
						if
							q.kind == "Naruto"
							and Logic.discGap(p.x, p.z, p.radius, q.x, q.z, q.radius) <= Layout.MAX_JUMP_GAP
						then
							safe = true
						end
					end
					t.ok(safe, `chashu {p.index} has no always-up neighbour`)
				end
			end
		end
	)

	t.test(
		"AC2 보강: 차슈는 한 주기에 1.4초 이상 계속 잠기지 않고, 떠 있는 시간이 4초 이상 이어져요",
		function()
			for i = 1, #Layout.CHASHUS do
				local longestUp, longestDown = 0, 0
				local runUp, runDown = 0, 0
				for step = 0, 1200 do -- 0~120초, 0.1초 간격 (주기 6초를 여러 번)
					local time = step * STEP
					if Logic.chashuSubmerged(i, time) then
						runDown += STEP
						runUp = 0
					else
						runUp += STEP
						runDown = 0
					end
					longestUp = math.max(longestUp, runUp)
					longestDown = math.max(longestDown, runDown)
				end
				t.ok(longestUp >= 4, `chashu {i} up only {longestUp}s`)
				t.ok(longestDown <= 1.8, `chashu {i} submerged {longestDown}s`)
			end
		end
	)

	t.test(
		"AC2 보강: 급류 끝에 어느 시각에 도착해도 시간을 따라 실제로 건널 수 있어요 (뛰기 0.8초, 착지 뒤 0.6초 여유)",
		function()
			local platforms = Logic.platforms()
			local n = #platforms
			local maxGap = Layout.MAX_JUMP_GAP
			-- 이웃 표 (0 = 급류 끝, n + 1 = 첫 회전 발판)
			local START, GOAL = 0, n + 1
			local function gapBetween(a: number, b: number): number
				if a == START then
					local p = platforms[b]
					return if b == GOAL then math.huge else Logic.gapFromRapids(p.x, p.z, p.radius)
				end
				local p = platforms[a]
				if b == GOAL then
					return Logic.gapToSweeperPlatform(p.x, p.z, p.radius)
				end
				local q = platforms[b]
				return Logic.discGap(p.x, p.z, p.radius, q.x, q.z, q.radius)
			end
			local function upDuring(node: number, from: number, to: number): boolean
				if node == START or node == GOAL then
					return true
				end
				local time = from
				while time <= to + 1e-9 do
					if not Logic.platformUp(platforms[node], time) then
						return false
					end
					time += STEP
				end
				return true
			end
			local hopSteps = math.round(HOP_TIME / STEP)
			local horizon = math.round(30 / STEP) -- 30초 안에 건너야 해요
			local worst = 0
			for startStep = 0, math.round(Layout.CHASHU_PERIOD / STEP) - 1 do
				-- reached[k][node] = startStep + k 스텝에 node 위에 서 있을 수 있음
				local reached: { [number]: { [number]: boolean } } = { [0] = { [START] = true } }
				local arrival: number? = nil
				for k = 0, horizon do
					local here = reached[k]
					if here == nil then
						continue
					end
					if here[GOAL] then
						arrival = k
						break
					end
					local now = (startStep + k) * STEP
					for node in here do
						-- 기다리기 (나루토·급류 끝은 항상, 차슈는 다음 스텝에도 떠 있으면)
						if upDuring(node, now + STEP, now + STEP) then
							reached[k + 1] = reached[k + 1] or {}
							reached[k + 1][node] = true
						end
						-- 뛰기
						for other = 1, n + 1 do
							if other ~= node and gapBetween(node, other) <= maxGap then
								local land = now + HOP_TIME
								if upDuring(other, land, land + LAND_GRACE) then
									reached[k + hopSteps] = reached[k + hopSteps] or {}
									reached[k + hopSteps][other] = true
								end
							end
						end
					end
				end
				t.ok(arrival ~= nil, `cannot cross toppings when arriving at t={startStep * STEP}`)
				worst = math.max(worst, (arrival or math.huge) * STEP)
			end
			-- 차슈 5줄(나루토 사이 4번)을 기다림 포함 15초 안에 건너야 Race 90초에 무리가 없어요
			t.ok(worst <= 15, `worst crossing time {worst}s`)
		end
	)

	---------------------------------------------------------------- 낙하선·결승
	t.test(
		"낙하선: 밟을 수 있는 모든 곳(차슈 가장 낮을 때 포함)이 그 z의 낙하선보다 20 이상 위",
		function()
			for z = 0, -300, -0.5 do
				local floor = Logic.floorAt(z)
				t.ok(floor - Logic.fallLineAt(z) >= 25 - 1e-9, `fall margin at z={z}`)
			end
			for i, c in Layout.CHASHUS do
				local lowest = Layout.BROTH_Y + Layout.CHASHU_LOW
				for dz = -Layout.CHASHU_DIAMETER / 2, Layout.CHASHU_DIAMETER / 2, 0.5 do
					t.ok(lowest - Logic.fallLineAt(c.z + dz) >= 20, `chashu {i} lowest too close to fall line`)
				end
			end
			-- 급류 끝 바로 앞에서 떨어져도 낙하선이 그 자리 바닥보다 25 아래 (C 구간 쪽으로 넘어가도 더 높아지지 않음)
			t.ok(Logic.fallLineAt(Layout.TOPPINGS.front - 0.1) <= Logic.fallLineAt(Layout.RAPIDS.back + 0.1))
		end
	)

	t.test("낙하 판정은 1초 안: 각 구간 바닥에서 낙하선까지 자유 낙하 시간 < 1초", function()
		local fallTime = math.sqrt(2 * Layout.FALL_MARGIN / GRAVITY)
		t.ok(fallTime < 1, `fall {fallTime}s`)
	end)

	t.test("결승선은 결승 바닥 위, 마지막 회전 발판 밖, 끝 벽 앞", function()
		local z = Layout.finishLineZ()
		local last = Layout.SWEEPER_LIST[#Layout.SWEEPER_LIST]
		t.ok(z < last.z - Layout.PLATFORM_DIAMETER / 2, "finish line past the last sweeper platform")
		t.ok(z > Layout.FINISH.back, "finish line before end wall")
		t.ok(z < Layout.FINISH.front + Layout.FINISH_FLOOR_OVERLAP, "finish line over finish floor")
		t.ok(Logic.progress(z) > Logic.progress(Layout.SWEEPERS.back), "finish is furthest progress")
	end)

	---------------------------------------------------------------- 코드 규칙 (소스 확인)
	t.test("여러 방: 태그 파츠는 ctx.model 하위만, 모듈 최상위에 가변 상태 없음", function()
		local source = fs.readFile(SOURCE_PATH)
		t.ok(
			string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil,
			"taggedParts filters by ctx.model"
		)
		for _, tag in { "TAG_BROTH", "TAG_CHASHU", "TAG_SWEEPER" } do
			t.ok(string.find(source, `taggedParts(ctx, {tag})`, 1, true) ~= nil, `{tag} via taggedParts`)
		end
		-- 최상위 local은 상수·함수뿐 (테이블 상태 없음)
		for line in string.gmatch(source, "[^\n]+") do
			local name, rhs = string.match(line, "^local%s+([%w_]+)%s*=%s*(.+)$")
			if name and rhs then
				t.ok(string.sub(rhs, 1, 1) ~= "{", `top-level mutable table {name}`)
			end
		end
		t.ok(string.find(source, "ctx.cleanup:add(RunService.Heartbeat:Connect", 1, true) ~= nil, "heartbeat cleaned")
	end)

	t.test("MoveExempt: 막대 넉백만 표시하고, 급류 밀기는 표시 없이 기준 안이에요", function()
		-- 설계 변경 (m4-10 QA B1, 2026-10-08): 급류·소용돌이 밀기에 반복 면제를 달면 국물 위 속도 조작이
		-- 안 잡혀서 뺐어요. 대신 밀기(+다이브 최악 합)가 0.2초 기본 기준(수평 22 studs) 안인지 고정해요.
		local source = fs.readFile(SOURCE_PATH)
		t.eq(string.find(source, "MoveExempt.mark(player.Character)", 1, true), nil, "no repeated push exempt")
		local guard = Config.MovementGuard
		local limit = guard.MaxHorizontalSpeed * guard.SampleInterval + guard.Slack
		local whirl = math.sqrt(Layout.WHIRLPOOL_FORWARD_SPEED ^ 2 + Layout.WHIRLPOOL_PUSH_SPEED ^ 2)
		for name, speed in
			{
				broth = Layout.BROTH_PUSH_SPEED + Config.Dive.ForwardSpeed,
				whirlpool = whirl + Config.Dive.ForwardSpeed,
			}
		do
			t.ok(speed * guard.SampleInterval <= limit, `{name} + dive {speed}`)
		end
		t.ok(
			string.find(source, "MoveExempt.mark(player.Character, Layout.KNOCKDOWN_TIME + 0.5)", 1, true) ~= nil,
			"knockback marks"
		)
		t.eq(Layout.EXEMPT_REFRESH, nil, "no exempt refresh interval")
	end)
end
