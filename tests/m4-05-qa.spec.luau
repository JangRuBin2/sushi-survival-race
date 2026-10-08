--!strict
-- m4-05 QA: 셰프의 도마 경계값 (스폰 여유, 61칸 기준, 보호 칸 최악 경우, 칼 일정 겹침, 넉백 전수),
-- ChefBoard.luau 소스 점검 (ctx.model 하위 태그만, 모듈 상태 없음, Cleanup 등록, MoveExempt, ctx.eliminate만)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Logic = RobloxRequire.require(Shared.maps.ChefBoardLogic)
local Art = RobloxRequire.require(Shared.maps.ChefBoardArt)

local SOURCE_PATH = "src/shared/maps/ChefBoard.luau"

-- ChefBoard.luau의 상수와 같은 값 (칼 한 번에 걸리는 시간, 경고 시간 제외)
local SLAM, HOLD, LIFT = 0.12, 0.25, 0.4

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function countMatches(source: string, pattern: string): number
	local n = 0
	for _ in string.gmatch(source, pattern) do
		n += 1
	end
	return n
end

local function cellCountFor(limit: number): number
	local n = 0
	for i = -4, 4 do
		for j = -4, 4 do
			if (i * 8) ^ 2 + (j * 8) ^ 2 <= limit * limit then
				n += 1
			end
		end
	end
	return n
end

return function(t: Test.Test)
	---------------------------------------------------------------- 스폰
	t.test(
		"QA AC1: 스폰 24곳이 서로 다른 칸 중앙이고 도마 가장자리에서 10 studs 이상 안쪽",
		function()
			local board = Logic.newBoard()
			for _, s in Logic.spawnOffsets() do
				local i, j = s.x / Logic.CELL_SIZE, s.z / Logic.CELL_SIZE
				t.ok(Logic.isAlive(board, i, j), `spawn {i},{j} on a cell`)
				local r = math.sqrt(s.x * s.x + s.z * s.z)
				t.ok(Logic.BOARD_RADIUS - r >= 10, `spawn {i},{j} rim margin {Logic.BOARD_RADIUS - r}`)
				-- 칸 네 이웃이 모두 있어서 칸 경계에서 4 studs 이상 + 옆 칸까지 바닥이 이어져요
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					t.ok(Logic.isAlive(board, i + d[1], j + d[2]), `spawn {i},{j} neighbour {d[1]},{d[2]}`)
				end
			end
		end
	)

	---------------------------------------------------------------- 61칸 기준 (개발 결정)
	t.test("QA 결정: 반지름 36 그대로면 69칸, 61칸은 CENTER_LIMIT 33.95~35.77에서만", function()
		t.eq(cellCountFor(36), 69)
		t.eq(cellCountFor(Logic.CENTER_LIMIT), 61)
		t.eq(cellCountFor(33.9), 57)
		t.eq(cellCountFor(33.95), 61)
		t.eq(cellCountFor(35.77), 61)
		t.eq(cellCountFor(35.78), 69)
		t.eq(#Logic.cells(), 61)
	end)

	---------------------------------------------------------------- 보호 칸
	t.test(
		"QA AC4: 최악 경우 — 모든 줄을 차례로 100바퀴 내려쳐도 가운데 3×3만 남고 줄 고르기는 nil이 안 됨",
		function()
			local board = Logic.newBoard()
			for _ = 1, 100 do
				for _, line in Logic.lines() do
					for _, cell in Logic.cutCells(board, line) do
						t.ok(not Logic.isProtected(cell.i, cell.j), `cut protected {cell.key}`)
					end
					Logic.removeCells(board, Logic.cutCells(board, line))
				end
			end
			local alive = 0
			for key in board.alive do
				alive += 1
				local i, j = string.match(key, "^(-?%d+),(-?%d+)$")
				t.ok(Logic.isProtected(tonumber(i) :: number, tonumber(j) :: number), `non-protected left {key}`)
			end
			t.eq(alive, 9)
			-- 보호 칸만 남아도 고를 줄이 있고 (Row/Column -1·0·1), 바로 전 줄을 빼도 마찬가지
			for _, previous in { nil, "Row0", "Column1" } do
				local line = Logic.pickLine(board, previous, fakeRng(3))
				t.ok(line ~= nil and line.key ~= previous, `pick after {previous}`)
				t.eq(#Logic.cutCells(board, line :: any), 0)
			end
		end
	)

	t.test("QA AC3: 시드 1~200, 칼마다 고른 줄은 남은 칸이 있고 18줄 중 하나", function()
		local valid: { [string]: boolean } = {}
		for _, line in Logic.lines() do
			valid[line.key] = true
		end
		t.eq(#Logic.lines(), 18)
		for seed = 1, 200 do
			local rng = fakeRng(seed)
			local board = Logic.newBoard()
			local previous: string? = nil
			for _ in Logic.strikeTimes(Config.TimeLimit.Survival) do
				local line = Logic.pickLine(board, previous, rng)
				t.ok(line ~= nil, `seed {seed}: nil line`)
				local l = line :: any
				t.ok(valid[l.key], `seed {seed}: bad line {l.key}`)
				t.ok(l.key ~= previous, `seed {seed}: repeated`)
				t.ok(Logic.remainingOn(board, l) > 0, `seed {seed}: empty line`)
				Logic.removeCells(board, Logic.cutCells(board, l))
				previous = l.key
			end
		end
	end)

	---------------------------------------------------------------- 칼 일정
	t.test(
		"QA AC2: 칼 한 번(경고+내려침+유지+올림)이 다음 경고 전에 끝나고, 마지막 내려침이 60초 전",
		function()
			local limit = Config.TimeLimit.Survival
			local times = Logic.strikeTimes(limit)
			t.eq(times, { 3, 9, 15, 21, 25.5, 30, 34.5, 39, 43.5, 46.5, 49.5, 52.5, 55.5, 58.5 })
			for k, at in times do
				local done = at + Logic.warnTime(at) + SLAM + HOLD + LIFT
				if k < #times then
					t.ok(done < times[k + 1], `strike #{k} at {at} overlaps next`)
				end
				t.ok(at + Logic.warnTime(at) + SLAM < limit, `strike #{k} slams after time limit`)
			end
		end
	)

	t.test("QA AC5: 기울기 창 5개가 서로 겹치지 않고 마지막은 53초에 끝나요", function()
		local plan = Logic.tiltPlan(fakeRng(9))
		for k = 2, #plan do
			t.ok(plan[k].startAt >= plan[k - 1].startAt + Logic.TILT_DURATION, `tilt {k} overlaps`)
		end
		t.ok(plan[#plan].startAt + Logic.TILT_DURATION <= Config.TimeLimit.Survival, "last tilt ends in time")
		t.ok(Logic.TILT_RAMP * 2 <= Logic.TILT_DURATION, "ramp fits in duration")
	end)

	---------------------------------------------------------------- 칼 맞음 / 넉백
	t.test(
		"QA AC5: 모든 줄·줄 위 모든 칸에서 넉백은 단위 벡터, 줄과 수직, 바깥쪽(가운데 줄은 플레이어 쪽)",
		function()
			for _, line in Logic.lines() do
				for along = -36, 36, 2 do
					for acrossOff = -5, 5 do
						local across = Logic.lineOffset(line) + acrossOff
						local x = if line.axis == "Row" then along else across
						local z = if line.axis == "Row" then across else along
						if Logic.isOnLine(line, x, z) then
							local dx, dz = Logic.knockDirection(line, x, z)
							t.eq(dx * dx + dz * dz, 1)
							if line.axis == "Row" then
								t.eq(dx, 0)
							else
								t.eq(dz, 0)
							end
							local outward = dx * x + dz * z
							t.ok(outward >= 0, `{line.key} at {x},{z} knocks inward`)
						end
					end
				end
			end
		end
	)

	t.test("QA AC8: 맞음 폭(반폭 5.5)은 옆 줄 중심에 닿지 않아요", function()
		for _, line in Logic.lines() do
			local o = Logic.lineOffset(line)
			for _, neighbour in { o - Logic.CELL_SIZE, o + Logic.CELL_SIZE } do
				local x = if line.axis == "Row" then 0 else neighbour
				local z = if line.axis == "Row" then neighbour else 0
				t.eq(Logic.isOnLine(line, x, z), false, `{line.key} hits neighbour centre`)
			end
		end
	end)

	---------------------------------------------------------------- 예산
	t.test("QA AC6: 장식 전체(칸 장식 + 배경)가 예산 안, 아트에 조명·파티클 없음", function()
		local total = MapKitLogic.count(Art.decor()) + MapKitLogic.count(Art.allCellDecor())
		t.ok(total <= MapKitLogic.DECOR_PART_BUDGET, `decor {total}`)
		local source = fs.readFile(SOURCE_PATH) .. fs.readFile("src/shared/maps/ChefBoardArt.luau")
		t.eq(string.find(source, "ParticleEmitter", 1, true), nil)
		t.eq(string.find(source, "PointLight", 1, true), nil)
		t.eq(string.find(source, "SpotLight", 1, true), nil)
	end)

	---------------------------------------------------------------- 소스 점검
	t.test("QA 서버: 태그는 ctx.model 하위만, 모듈 수준 가변 상태 없음", function()
		local source = fs.readFile(SOURCE_PATH)
		t.ok(string.find(source, "model:IsAncestorOf(instance)", 1, true) ~= nil, "filters by ctx.model")
		t.eq(countMatches(source, "GetTagged%("), 1) -- taggedInModel 한 곳에서만
		t.ok(string.find(source, "taggedInModel(ctx.model, TAG_CELL)", 1, true) ~= nil, "cells from ctx.model")
		t.ok(string.find(source, "taggedInModel(ctx.model, TAG_KNIFE)", 1, true) ~= nil, "knife from ctx.model")
		-- 맨 왼쪽(들여쓰기 없는) local 중 테이블/가변 값이 없어야 해요 (상수·함수·require·타입만)
		for line in string.gmatch(source, "[^\n]+") do
			if string.match(line, "^local ") and not string.match(line, "^local function ") then
				local ok = string.find(line, "require(", 1, true)
					or string.match(line, '^local [%u_]+ = [%d%.%-"]')
					or string.match(line, "^local ChefBoard: MapTypes%.MapModule")
				t.ok(ok, `module-level state? {line}`)
			end
		end
	end)

	t.test("QA 서버: 연결·스레드는 모두 ctx.cleanup에 등록", function()
		local source = fs.readFile(SOURCE_PATH)
		local spawned = countMatches(source, "task%.spawn%(") + countMatches(source, "task%.delay%(")
		local connected = countMatches(source, ":Connect%(")
		local added = countMatches(source, "ctx%.cleanup:add%(")
		t.eq(spawned, 4)
		t.eq(connected, 1)
		t.eq(added, spawned + connected)
		t.ok(string.find(source, "ctx.cleanup:add(aimThread)", 1, true) ~= nil, "aim thread")
		t.ok(string.find(source, "ctx.cleanup:add(task.spawn(dropCell", 1, true) ~= nil, "drop threads")
		t.ok(string.find(source, "ctx.cleanup:add(RunService.Heartbeat:Connect", 1, true) ~= nil, "heartbeat")
	end)

	t.test(
		"QA 서버: 판정은 ctx.eliminate만 (Survival은 pass 없음), 서버 이동엔 MoveExempt.mark",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.eq(string.find(source, "ctx.pass(", 1, true), nil)
			t.eq(countMatches(source, "ctx%.eliminate%("), 1)
			t.ok(string.find(source, "relative.Y < -Logic.FALL_DEPTH", 1, true) ~= nil, "fall depth from origin")
			-- 칼 넉백 한 곳만. 기울기 밀기는 반복 면제를 달지 않아요 — 설계 변경 (m4-10 QA B1, 2026-10-08):
			-- 면제 중엔 속도 조작이 안 잡혀서 뺐고, 대신 밀기(+다이브 최악 합)가 기본 기준 안인지 고정해요.
			t.eq(countMatches(source, "MoveExempt%.mark%("), 1)
			t.ok(string.find(source, "MoveExempt.mark(player.Character, Logic.KNOCKDOWN_TIME", 1, true) ~= nil, "knock")
			t.eq(string.find(source, "MoveExempt.mark(character)", 1, true), nil, "no repeated tilt-push exempt")
			local guard = Config.MovementGuard
			local worst = (Logic.TILT_PUSH_SPEED + Config.Dive.ForwardSpeed) * guard.SampleInterval
			t.ok(worst <= guard.MaxHorizontalSpeed * guard.SampleInterval + guard.Slack, `tilt + dive {worst}`)
			-- 랜덤은 ctx.rng만
			t.eq(string.find(source, "Random.new", 1, true), nil)
			t.eq(string.find(source, "math.random", 1, true), nil)
			-- 칼 일정은 Survival 시간 제한을 따라요 (맵 timeLimit 없음)
			t.ok(string.find(source, "Logic.strikeTimes(Config.TimeLimit.Survival)", 1, true) ~= nil, "schedule limit")
		end
	)

	t.test(
		"QA 범위: 손님 얼굴(탈락 연출)은 낙하 탈락 깊이 아래, 쉬는 칼은 시야 상자 위",
		function()
			for _, spec in Art.decor() do
				if string.sub(spec.name, 1, 8) == "Customer" then
					local box = MapKitLogic.bounds({ spec }) :: any
					t.ok(box.max.y < -Logic.FALL_DEPTH, spec.name)
				end
			end
			local volume = Art.courseVolume()
			local source = fs.readFile(SOURCE_PATH)
			local rest = tonumber(string.match(source, "local KNIFE_REST_HEIGHT = (%d+)"))
			t.ok(rest ~= nil and rest > volume.max.y, "knife rests above the play volume")
		end
	)
end
