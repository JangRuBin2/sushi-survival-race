--!strict
-- m5-16 Survival 맵 "와르르 나무 블록": 격자 치수, 제거 일정·고르기·적용, 국소 기울기, 아트 (순수 로직)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local Logic = RobloxRequire.require(Shared.maps.GiantJengaLogic)
local Art = RobloxRequire.require(Shared.maps.GiantJengaArt)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
		NextNumber = function(_, min: number?, max: number?): number
			state = (state * 1103515245 + 12345) % 2147483648
			local a, b = min or 0, max or 1
			return a + (state % 1000000) / 1000000 * (b - a)
		end,
	}
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function boxesOverlap(a: any, b: any): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

-- 한 판(60초)을 순수 로직만으로 돌려요. 제거마다 check(board, picks, wave)를 불러요.
local function simulate(seed: number, check: (board: any, picks: { any }, wave: any) -> ())
	local rng = fakeRng(seed)
	local board = Logic.newBoard()
	local previousKeys: { string }? = nil
	for _, removeAt in Logic.removalTimes(60) do
		local wave = Logic.removalWave(removeAt)
		if wave == nil then
			break
		end
		local picks = Logic.pickColumns(board, previousKeys, wave.count, rng)
		check(board, picks, wave)
		Logic.applyRemoval(board, picks)
		if #picks > 0 then
			local keys = {}
			for _, column in picks do
				table.insert(keys, column.key)
			end
			previousKeys = keys
		end
	end
	return board
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: giant-jenga는 인터페이스를 지키는 Survival 맵 (overtime 없어도 통과)", function()
		local map = Maps.get("giant-jenga")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "와르르 나무 블록")
		t.eq(map.timeLimit, 75) -- m5-40: 맵 timeLimit 75 (Config.TimeLimit.Survival 60은 그대로)
	end)

	t.test("AC1: 칸 25개(i, j ∈ -2..2), 서로 겹치지 않음", function()
		local columns = Layout.columns()
		t.eq(#columns, 25)
		local seen: { [string]: boolean } = {}
		for _, column in columns do
			t.ok(column.i >= -2 and column.i <= 2, `{column.key} i out of range`)
			t.ok(column.j >= -2 and column.j <= 2, `{column.key} j out of range`)
			t.eq(column.x, column.i * Layout.CELL_SIZE)
			t.eq(column.z, column.j * Layout.CELL_SIZE)
			t.ok(not seen[column.key], `duplicate {column.key}`)
			seen[column.key] = true
		end
	end)

	t.test("AC1: 가운데 3×3(9칸)만 보호 칸", function()
		local protectedCount = 0
		for _, column in Layout.columns() do
			local want = math.abs(column.i) <= 1 and math.abs(column.j) <= 1
			t.eq(Layout.isProtected(column.i, column.j), want, column.key)
			if want then
				protectedCount += 1
			end
		end
		t.eq(protectedCount, 9)
	end)

	t.test("AC1: 스폰 24곳 = (0,0)을 제외한 나머지 칸과 정확히 일치", function()
		local spawns = Layout.spawnOffsets()
		t.eq(#spawns, 24)
		local wanted: { [string]: boolean } = {}
		for _, column in Layout.columns() do
			if not (column.i == 0 and column.j == 0) then
				wanted[`{column.x},{column.z}`] = true
			end
		end
		local seen: { [string]: boolean } = {}
		for _, offset in spawns do
			local key = `{offset.x},{offset.z}`
			t.ok(wanted[key], `spawn {key} is not a non-centre column`)
			t.ok(not seen[key], `duplicate spawn {key}`)
			seen[key] = true
		end
		for key in wanted do
			t.ok(seen[key], `missing spawn for {key}`)
		end
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: removalWave가 표대로 (간격·개수)", function()
		t.eq(Logic.removalWave(3), nil)
		t.eq(Logic.removalWave(6), { interval = 5.0, count = 1 })
		t.eq(Logic.removalWave(17.9), { interval = 5.0, count = 1 })
		t.eq(Logic.removalWave(18), { interval = 3.5, count = 1 })
		t.eq(Logic.removalWave(33.9), { interval = 3.5, count = 1 })
		t.eq(Logic.removalWave(34), { interval = 2.5, count = 2 })
		t.eq(Logic.removalWave(47.9), { interval = 2.5, count = 2 })
		t.eq(Logic.removalWave(48), { interval = 1.5, count = 2 })
		t.eq(Logic.removalWave(59), { interval = 1.5, count = 2 })
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: removalTimes(60)은 6초부터 시작해 구간 간격대로 늘고 60초 미만", function()
		local times = Logic.removalTimes(60)
		t.ok(#times > 5, "several removals in 60s")
		t.eq(times[1], Logic.FIRST_REMOVAL_AT)
		for k = 2, #times do
			local wave = Logic.removalWave(times[k - 1]) :: any
			t.ok(near(times[k] - times[k - 1], wave.interval), `gap before #{k}`)
		end
		t.ok(times[#times] < 60, "last removal before time limit")
	end)

	---------------------------------------------------------------- AC4
	t.test(
		"AC4: 시드 1~200 — 보호 칸·레벨 0 칸은 절대 안 고르고, 중복 없고, count 이하",
		function()
			for seed = 1, 200 do
				simulate(seed, function(board, picks, wave)
					t.ok(#picks <= wave.count, `seed {seed}: picks exceed wave.count`)
					local seen: { [string]: boolean } = {}
					for _, column in picks do
						t.ok(not Layout.isProtected(column.i, column.j), `seed {seed}: picked protected {column.key}`)
						t.ok((board.levels[column.key] or 0) > 0, `seed {seed}: picked empty {column.key}`)
						t.ok(not seen[column.key], `seed {seed}: duplicate pick {column.key}`)
						seen[column.key] = true
					end
				end)
			end
		end
	)

	t.test(
		"AC4: 대안이 있으면 previousKeys를 피하고, 대안이 없으면 어쩔 수 없이 다시 고름",
		function()
			local board = Logic.newBoard()
			for _, column in Layout.columns() do
				if not Layout.isProtected(column.i, column.j) and column.key ~= "2,0" and column.key ~= "2,1" then
					board.levels[column.key] = 0
				end
			end
			for seed = 1, 50 do
				local picks = Logic.pickColumns(board, { "2,0" }, 1, fakeRng(seed))
				t.eq(#picks, 1)
				t.eq(picks[1].key, "2,1", `seed {seed}: should avoid previous while an alternative exists`)
			end
			board.levels["2,1"] = 0
			for seed = 1, 50 do
				local picks = Logic.pickColumns(board, { "2,0" }, 1, fakeRng(seed))
				t.eq(#picks, 1)
				t.eq(picks[1].key, "2,0", `seed {seed}: no alternative left, must reuse previous`)
			end
		end
	)

	t.test("AC4: 남은 레벨이 많은 칸이 더 자주 뽑혀요 (가중 랜덤)", function()
		local board = Logic.newBoard()
		for _, column in Layout.columns() do
			if not Layout.isProtected(column.i, column.j) then
				board.levels[column.key] = 0
			end
		end
		board.levels["2,0"] = 3
		board.levels["2,1"] = 1
		local counts: { [string]: number } = {}
		local rng = fakeRng(11)
		for _ = 1, 3000 do
			local picks = Logic.pickColumns(board, nil, 1, rng)
			local key = picks[1] and picks[1].key
			if key then
				counts[key] = (counts[key] or 0) + 1
			end
		end
		t.ok((counts["2,0"] or 0) > (counts["2,1"] or 0), "higher remaining level picked more often")
	end)

	t.test("AC4: 60초 동안 탑의 바깥 테두리가 실제로 깎여요 (가운데는 그대로)", function()
		local board = simulate(3, function() end)
		local removed = 0
		for _, column in Layout.columns() do
			if not Layout.isProtected(column.i, column.j) and (board.levels[column.key] or 0) < Layout.LEVEL_MAX then
				removed += 1
			end
			if Layout.isProtected(column.i, column.j) then
				t.eq(board.levels[column.key], Layout.LEVEL_MAX, `protected {column.key} changed`)
			end
		end
		t.ok(removed > 0, "outer ring should shrink over 60s")
	end)

	---------------------------------------------------------------- AC5
	t.test(
		"AC5: applyRemoval은 레벨을 1씩 줄이고 0 밑으로 안 내려가며, 보호 칸은 그대로",
		function()
			local board = Logic.newBoard()
			local outer = { i = 2, j = 0, x = 20, z = 0, key = "2,0" }
			Logic.applyRemoval(board, { outer })
			t.eq(board.levels["2,0"], 2)
			Logic.applyRemoval(board, { outer })
			Logic.applyRemoval(board, { outer })
			t.eq(board.levels["2,0"], 0)
			Logic.applyRemoval(board, { outer }) -- 더 줄여도 0 밑으로는 안 내려가요
			t.eq(board.levels["2,0"], 0)

			local protectedColumn = { i = 0, j = 0, x = 0, z = 0, key = "0,0" }
			Logic.applyRemoval(board, { protectedColumn })
			t.eq(board.levels["0,0"], Layout.LEVEL_MAX, "protected column must not change")
		end
	)

	---------------------------------------------------------------- AC6
	t.test("AC6: 전부 레벨 3(평평)이면 모든 칸이 nil", function()
		local board = Logic.newBoard()
		for _, column in Layout.columns() do
			t.eq(Logic.tiltFor(board, column.i, column.j), nil, column.key)
		end
	end)

	t.test(
		"AC6: 이웃 하나만 레벨 2면 기울고, 각도가 DEG_PER_UNIT(6도)에 가깝고 그쪽이 낮은 쪽",
		function()
			local board = Logic.newBoard()
			board.levels["2,1"] = 2 -- (2,0)의 이웃
			local tilt = Logic.tiltFor(board, 2, 0) :: any
			t.ok(tilt ~= nil, "should tilt")
			t.ok(near(tilt.angle, math.rad(Logic.DEG_PER_UNIT)), "about DEG_PER_UNIT degrees")
			t.eq(tilt.downX, 0)
			t.eq(tilt.downZ, 1) -- (2,1) 쪽, 즉 +j 쪽이 낮은 쪽
			t.ok(near(tilt.axisX * tilt.downX + tilt.axisZ * tilt.downZ, 0), "axis ⟂ down")
		end
	)

	t.test(
		"AC6: 이웃이 레벨 0(뚫림)이면 레벨 2일 때보다 각도가 더 크고, 최대 MAX_TILT_DEG에서 캡",
		function()
			local boardLevel2 = Logic.newBoard()
			boardLevel2.levels["2,1"] = 2
			local tiltLevel2 = Logic.tiltFor(boardLevel2, 2, 0) :: any

			local boardHole = Logic.newBoard()
			boardHole.levels["2,1"] = 0
			local tiltHole = Logic.tiltFor(boardHole, 2, 0) :: any

			t.ok(tiltHole.angle > tiltLevel2.angle, "hole should tilt more than a sunk-by-one neighbour")
			t.ok(tiltHole.angle <= math.rad(Logic.MAX_TILT_DEG) + 1e-9, "never exceeds MAX_TILT_DEG")

			-- 여러 이웃이 모두 뚫려도 캡을 넘지 않아요
			local boardAllHoles = Logic.newBoard()
			for _, neighbor in Layout.neighborsOf(2, 0) do
				boardAllHoles.levels[Layout.key(neighbor.i, neighbor.j)] = 0
			end
			local tiltAll = Logic.tiltFor(boardAllHoles, 2, 0) :: any
			if tiltAll then
				t.ok(tiltAll.angle <= math.rad(Logic.MAX_TILT_DEG) + 1e-9, "capped even with several holes")
			end
		end
	)

	t.test("AC6: 보호 칸은 이웃이 전부 뚫려도 항상 nil", function()
		local board = Logic.newBoard()
		for _, neighbor in Layout.neighborsOf(0, 0) do
			board.levels[Layout.key(neighbor.i, neighbor.j)] = 0
		end
		for i = -1, 1 do
			for j = -1, 1 do
				t.eq(Logic.tiltFor(board, i, j), nil, `protected {i},{j} should stay flat`)
			end
		end
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: heightOf는 레벨 3/2/1 → 0 / -LEVEL_DROP / -2·LEVEL_DROP", function()
		local board = Logic.newBoard()
		t.eq(Logic.heightOf(board, 2, 0), 0)
		board.levels["2,0"] = 2
		t.eq(Logic.heightOf(board, 2, 0), -Layout.LEVEL_DROP)
		board.levels["2,0"] = 1
		t.eq(Logic.heightOf(board, 2, 0), -2 * Layout.LEVEL_DROP)
	end)

	---------------------------------------------------------------- AC8
	t.test("AC8: 장식이 MapKitLogic.validate 통과, 파츠·파티클·조명 예산 안", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		-- m5-24 D2: 아트 패스로 Extended 예산 (장식 1500·조명 24·그림자 2·파티클 16·움직임 80)
		t.eq(MapKitLogic.checkBudget(decor, "Extended", { lights = 3 }), nil, `decor {MapKitLogic.count(decor)} parts`)
		local lamps = 0
		for _, spec in decor do
			if spec.name == Art.LAMP_BULB then
				lamps += 1
			end
		end
		t.eq(lamps, 3)
		t.ok(lamps <= MapKitLogic.LIGHT_BUDGET, "light budget")
	end)

	t.test("AC8: 장식이 시야 상자(탑 꼭대기 위 2~12, 격자 안쪽)와 안 겹쳐요", function()
		local volume = Art.courseVolume()
		for i, spec in Art.decor() do
			local box = MapKitLogic.bounds({ spec }) :: any
			t.ok(not boxesOverlap(box, volume), `#{i} {spec.name} blocks the view`)
		end
	end)

	t.test("AC8: 손님 얼굴은 탈락 높이(30) 아래", function()
		local faces = 0
		for _, spec in Art.decor() do
			if spec.name == "CustomerHead" then
				faces += 1
				local box = MapKitLogic.bounds({ spec }) :: any
				t.ok(box.max.y < -Layout.FALL_DEPTH, `{spec.name} top {box.max.y}`)
			end
		end
		t.ok(faces >= 2, "customer faces below the tower")
	end)

	t.test("AC8: IntroCamera 3점 이상 (탑 전체 → 바깥 테두리 → 가운데)", function()
		local points = Art.introCamera()
		t.ok(#points >= 3, "at least 3 points")
	end)

	t.test("AC8: GiantJenga.luau에 inPool = false 줄이 없어요", function()
		local source = fs.readFile("src/shared/maps/GiantJenga.luau")
		t.eq(string.find(source, "inPool", 1, true), nil, "inPool line should be removed")
	end)

	t.test("AC8: 랜덤 Survival 풀(Maps.infos)에 giant-jenga가 들어 있어요", function()
		local found = false
		for _, info in Maps.infos() do
			if info.id == "giant-jenga" then
				found = true
			end
		end
		t.ok(found, "giant-jenga should be in the random map pool")
	end)

	t.test(
		"m5-16 B1: 레벨이 줄면 맨 위 블록부터 사라져요 (3→2 Block1, 2→1 Block2, 1→0 Block3)",
		function()
			t.eq(Logic.poppedBlockIndex(2), 1)
			t.eq(Logic.poppedBlockIndex(1), 2)
			t.eq(Logic.poppedBlockIndex(0), 3)
			-- Block1이 가장 높고 번호가 커질수록 낮아요
			for n = 1, Layout.LEVEL_MAX - 1 do
				t.ok(Logic.blockCenterY(n) > Logic.blockCenterY(n + 1), `Block{n} above Block{n + 1}`)
			end
			-- 레벨 L에서 남은 블록(아직 안 숨긴 것) 중 가장 높은 블록 윗면이 그 칸 윗면(heightOf) 바로 아래예요
			local board = Logic.newBoard()
			for newLevel = Layout.LEVEL_MAX - 1, 1, -1 do
				board.levels["2,0"] = newLevel
				local topRemaining = Logic.poppedBlockIndex(newLevel) + 1
				local blockTop = Logic.blockCenterY(topRemaining) + Layout.LEVEL_DROP / 2
				local surface = Logic.heightOf(board, 2, 0)
				t.ok(math.abs(blockTop - surface) < 1e-9, `level {newLevel}: block top {blockTop} vs surface {surface}`)
			end
			local source = fs.readFile("src/shared/maps/GiantJenga.luau")
			t.ok(
				string.find(source, "entry.blocks[Logic.poppedBlockIndex(newLevel)]", 1, true) ~= nil,
				"server uses it"
			)
			t.ok(string.find(source, "Logic.blockCenterY(level)", 1, true) ~= nil, "build uses the same order")
		end
	)

	t.test(
		"m5-16 B3: 혼자 가라앉은 테두리 칸은 바깥으로 DEG_PER_UNIT의 50%까지만 기울어요",
		function()
			local maxOutward = math.rad(Logic.DEG_PER_UNIT * Logic.EDGE_OUTWARD_MAX_UNITS) + 1e-9
			-- 변 칸 4곳과 모서리 칸 하나: 그 칸만 레벨 2·1로 가라앉힘 (이웃은 전부 3)
			for _, cell in { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 }, { 2, 2 }, { -2, -2 } } do
				for _, level in { 2, 1 } do
					local board = Logic.newBoard()
					board.levels[Layout.key(cell[1], cell[2])] = level
					local tilt = Logic.tiltFor(board, cell[1], cell[2]) :: any
					t.ok(tilt ~= nil, `{cell[1]},{cell[2]} still tilts a little`)
					-- 바깥쪽 성분(각도 × 바깥 방향 성분)이 상한 이하
					local outward = 0
					if cell[1] ~= 0 then
						outward = math.max(outward, tilt.downX * cell[1] / math.abs(cell[1]))
					end
					if cell[2] ~= 0 then
						outward = math.max(outward, tilt.downZ * cell[2] / math.abs(cell[2]))
					end
					t.ok(
						tilt.angle * outward <= maxOutward,
						`{cell[1]},{cell[2]} L{level} outward {tilt.angle * outward}`
					)
				end
			end
			-- 안쪽·테두리를 따라가는 기울기는 그대로 (이웃 (2,1)이 레벨 2 → 6도, +j 쪽)
			local board = Logic.newBoard()
			board.levels["2,1"] = 2
			local along = Logic.tiltFor(board, 2, 0) :: any
			t.ok(math.abs(along.angle - math.rad(Logic.DEG_PER_UNIT)) < 1e-9, "along-edge tilt unchanged")
		end
	)

	t.test(
		"m5-16 B4: 서버가 칸을 놓는 높이는 build와 같아요 (윗면 = heightOf, 중심은 두께 절반 아래)",
		function()
			local source = fs.readFile("src/shared/maps/GiantJenga.luau")
			t.ok(
				string.find(source, "Logic.heightOf(board, entry.i, entry.j) - TOP_THICKNESS / 2", 1, true) ~= nil,
				"flatCFrame offset"
			)
			t.ok(
				string.find(source, "CFrame.new(column.x, -TOP_THICKNESS / 2, column.z)", 1, true) ~= nil,
				"build offset"
			)
		end
	)
end
