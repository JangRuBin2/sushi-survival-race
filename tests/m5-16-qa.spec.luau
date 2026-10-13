--!strict
-- m5-16 QA(docs/qa/m5-16-map-giant-jenga.md): 60초 제거 여유, 모든 진행 상태의 기울기 범위, 낙하선 여유,
-- 이동 감시 여유, 서버 코드 점검. (가라앉은 칸 블록 표시 B1은 리포트 참고 — 실패 테스트로 넣지 않음)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local Logic = RobloxRequire.require(Shared.maps.GiantJengaLogic)

local SOURCE_PATH = "src/shared/maps/GiantJenga.luau"

local function countMatches(source: string, pattern: string): number
	local n = 0
	for _ in string.gmatch(source, pattern) do
		n += 1
	end
	return n
end

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function checkAllTilts(t: Test.Test, board: any, label: string)
	for _, column in Layout.columns() do
		local tilt = Logic.tiltFor(board, column.i, column.j)
		if Layout.isProtected(column.i, column.j) or (board.levels[column.key] or 0) <= 0 then
			t.eq(tilt, nil, `{label} {column.key} must not tilt`)
		elseif tilt then
			t.ok(tilt.angle > 0 and tilt.angle <= math.rad(Logic.MAX_TILT_DEG) + 1e-9, `{label} {column.key} angle`)
			t.ok(math.abs(tilt.downX ^ 2 + tilt.downZ ^ 2 - 1) < 1e-9, `{label} {column.key} down unit`)
			-- 회전축은 위 × 낮은 쪽 (수평, 낮은 쪽과 수직)
			t.ok(math.abs(tilt.axisX * tilt.downX + tilt.axisZ * tilt.downZ) < 1e-9, `{label} axis ⟂ down`)
			t.ok(tilt.strength > 0 and tilt.strength <= 1 + 1e-9, `{label} strength`)
		end
	end
end

return function(t: Test.Test)
	t.test(
		"m5-16 QA: 60초 동안 뽑는 총 개수는 테두리 16칸 × 3단(48)보다 적어요 (끝까지 뽑을 칸이 있음)",
		function()
			t.eq(Config.TimeLimit.Survival, 60)
			local total = 0
			for _, at in Logic.removalTimes(Config.TimeLimit.Survival) do
				total += (Logic.removalWave(at) :: any).count
			end
			local capacity = 0
			for _, column in Layout.columns() do
				if not Layout.isProtected(column.i, column.j) then
					capacity += Layout.LEVEL_MAX
				end
			end
			t.eq(capacity, 48)
			t.ok(total < capacity, `removals {total} vs capacity {capacity}`)
		end
	)

	t.test(
		"m5-16 QA: 시드 1~300 한 판 내내 고른 칸은 바깥·레벨>0·중복 없음, 모든 칸 기울기는 범위 안",
		function()
			for seed = 1, 300 do
				local rng = fakeRng(seed)
				local board = Logic.newBoard()
				local previousKeys: { string }? = nil
				for _, at in Logic.removalTimes(60) do
					local wave = Logic.removalWave(at) :: any
					local picks = Logic.pickColumns(board, previousKeys, wave.count, rng)
					t.ok(#picks >= 1 and #picks <= wave.count, `seed {seed} t {at} pick count`)
					local seen: { [string]: boolean } = {}
					for _, column in picks do
						t.ok(not Layout.isProtected(column.i, column.j), `seed {seed} protected pick`)
						t.ok((board.levels[column.key] or 0) > 0, `seed {seed} picked empty column`)
						t.ok(not seen[column.key], `seed {seed} duplicate pick`)
						seen[column.key] = true
					end
					Logic.applyRemoval(board, picks)
					local keys = {}
					for _, column in picks do
						table.insert(keys, column.key)
					end
					previousKeys = keys
					if seed <= 30 then
						checkAllTilts(t, board, `seed {seed} t {at}`)
					end
				end
				for _, column in Layout.columns() do
					if Layout.isProtected(column.i, column.j) then
						t.eq(board.levels[column.key], Layout.LEVEL_MAX, `seed {seed} protected changed`)
					end
				end
			end
		end
	)

	t.test("m5-16 QA: 가장 많이 가라앉은 칸(레벨 1)도 낙하선(-30)보다 20 이상 위", function()
		local board = Logic.newBoard()
		board.levels[Layout.key(2, 2)] = 1
		t.eq(Logic.heightOf(board, 2, 2), -2 * Layout.LEVEL_DROP)
		t.ok(Logic.heightOf(board, 2, 2) - 20 > -Layout.FALL_DEPTH)
	end)

	t.test(
		"m5-16 QA: 걷기 + 기울기 밀기 최고 속도는 이동 감시 수평 상한보다 한참 작아요",
		function()
			local worst = Config.Character.WalkSpeed + Logic.TILT_PUSH_SPEED
			t.ok(worst * 2 < Config.MovementGuard.MaxHorizontalSpeed, `walk+push {worst}`)
		end
	)

	t.test(
		"m5-16 QA 서버: 태그는 ctx.model 하위만, 모듈 수준 가변 상태 없음, MoveExempt·ctx.pass·리모트 없음",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.ok(string.find(source, "model:IsAncestorOf(instance)", 1, true) ~= nil, "filters by ctx.model")
			t.ok(string.find(source, "taggedInModel(ctx.model, TAG_COLUMN)", 1, true) ~= nil)
			t.eq(countMatches(source, "GetTagged%("), 1)
			t.eq(countMatches(source, "MoveExempt%.mark"), 0)
			t.eq(countMatches(source, "ctx%.pass%("), 0)
			t.eq(countMatches(source, "ctx%.eliminate%("), 1)
			t.eq(countMatches(source, "OnServerEvent"), 0)
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function ") then
					local ok = string.find(line, "require(", 1, true)
						or string.match(line, '^local [%u_]+ = [%d%.%-"]')
						or string.match(line, "^local GiantJenga: MapTypes%.MapModule")
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	t.test("m5-16 QA 서버: 연결·스레드는 모두 ctx.cleanup, 랜덤은 ctx.rng만", function()
		local source = fs.readFile(SOURCE_PATH)
		local spawned = countMatches(source, "task%.spawn%(") + countMatches(source, "task%.delay%(")
		t.eq(countMatches(source, ":Connect%("), 1)
		t.eq(spawned, 2)
		t.ok(string.find(source, "ctx.cleanup:add(RunService.Heartbeat:Connect(", 1, true) ~= nil)
		t.ok(string.find(source, "ctx.cleanup:add(task.spawn(function()", 1, true) ~= nil)
		t.ok(string.find(source, "ctx.cleanup:add(task.spawn(removeColumn, column))", 1, true) ~= nil)
		t.eq(countMatches(source, "Random%.new"), 0)
		t.eq(countMatches(source, "math%.random"), 0)
	end)
end
