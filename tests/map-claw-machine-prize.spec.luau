--!strict
-- m5-19 "인형뽑기 기계 속": 격자 좌표(AC1·AC2), 집게 시간표·과녁 고르기·들어 올리는 칸(AC3~AC5),
-- 연장전 상자 기울기 일정(AC6), 장식 예산·시야 상자(AC7).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.ClawMachinePrizeLayout)
local Logic = RobloxRequire.require(Shared.maps.ClawMachinePrizeLogic)
local Art = RobloxRequire.require(Shared.maps.ClawMachinePrizeArt)

type DecorSpec = MapKitLogic.DecorSpec
type Bounds = MapKitLogic.Bounds

-- 시드 고정 rng (Random:NextInteger·NextNumber와 같은 모양, m4-12-hardening.spec.luau와 같은 패턴)
local function seededRng(seed: number): any
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self: any): number
			return step()
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1))
		end,
	}
end

local EPS = 1e-6

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
	t.test("AC1: Final 맵이고 overtime이 있어요, Maps.get으로 조회돼요", function()
		local map = Maps.get("claw-machine-prize")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Final")
		t.eq(type(map.overtime), "function")
		t.ok(map.inPool ~= false, "랜덤 풀에 들어가요 (inPool 줄 삭제)")
		t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
	end)

	t.test("AC1: 격자 8x8 = 64칸, Row·Col 0~7", function()
		local count = 0
		for row = 0, 7 do
			for col = 0, 7 do
				local index = Layout.tileIndex(row, col)
				t.ok(index ~= nil and index >= 0 and index <= 63, `({row},{col}) index`)
				count += 1
			end
		end
		t.eq(count, 64)
		t.eq(Layout.GRID_SIZE, 8)
	end)

	t.test("AC1: 스폰 24개, 전부 칸 위, 서로 3 studs 이상, Row·Col 2~5", function()
		local spawns = Layout.spawnTiles()
		t.eq(#spawns, 24)
		for _, spawn in spawns do
			t.ok(spawn.row >= 2 and spawn.row <= 5, `row {spawn.row} in 2~5`)
			t.ok(spawn.col >= 2 and spawn.col <= 5, `col {spawn.col} in 2~5`)
			-- x·z가 실제로 그 칸의 발판 위(칸 footprint 안)에 있어요
			local halfTile = Layout.TILE_SIZE / 2
			t.ok(
				math.abs(spawn.x - Layout.tileLocalX(spawn.col)) <= halfTile + EPS,
				`spawn x within tile col {spawn.col}`
			)
			t.ok(
				math.abs((spawn.z - Layout.CENTER_Z) - Layout.tileLocalZGrid(spawn.row)) <= halfTile + EPS,
				`spawn z within tile row {spawn.row}`
			)
			-- colOf/rowOf 역함수로 다시 계산해도 같은 칸
			t.eq(Layout.colOf(spawn.x), spawn.col, "colOf matches")
			t.eq(Layout.rowOf(spawn.z - Layout.CENTER_Z), spawn.row, "rowOf matches")
		end
		for i = 1, #spawns do
			for j = i + 1, #spawns do
				local a, b = spawns[i], spawns[j]
				local dist = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.ok(dist >= 3 - EPS, `spawn {i}-{j} distance {dist}`)
			end
		end
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: tileIndex — 격자 밖은 nil, 격자 안은 0~63 전부 고유", function()
		for _, bad in { { -1, 0 }, { 0, -1 }, { 8, 0 }, { 0, 8 }, { 8, 8 }, { -1, -1 } } do
			t.eq(Layout.tileIndex(bad[1], bad[2]), nil, `({bad[1]},{bad[2]})`)
		end
		local seen: { [number]: boolean } = {}
		for row = 0, 7 do
			for col = 0, 7 do
				local index = Layout.tileIndex(row, col) :: number
				t.ok(not seen[index], `duplicate index {index}`)
				seen[index] = true
			end
		end
		for index = 0, 63 do
			t.ok(seen[index], `index {index} covered`)
		end
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: clawWave — 출발 5초 전 없음, 표대로 주기·구역 크기·경고", function()
		t.eq(Logic.clawWave(4.9, nil), nil)
		t.eq(Logic.clawWave(5, nil), { interval = 8, size = 2, warnTime = 2 })
		t.eq(Logic.clawWave(29.9, nil), { interval = 8, size = 2, warnTime = 2 })
		t.eq(Logic.clawWave(30, nil), { interval = 6, size = 2, warnTime = 1.5 })
		t.eq(Logic.clawWave(59.9, nil), { interval = 6, size = 2, warnTime = 1.5 })
		t.eq(Logic.clawWave(60, nil), { interval = 4, size = 3, warnTime = 1.2 })
		t.eq(
			Logic.clawWave(90, nil),
			{ interval = 4, size = 3, warnTime = 1.2 },
			"overtimeAt 없으면 계속 서든데스 값"
		)
		t.eq(Logic.clawWave(92, 90), { interval = 2.5, size = 3, warnTime = 1 })
		t.eq(
			Logic.clawWave(15, 15),
			{ interval = 2.5, size = 3, warnTime = 1 },
			"디버그로 일찍 당겨도 바로 연장전 값"
		)
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: pickClawTarget — 약 70%는 사람이 몰린 창, 창은 전부 aliveTiles 안", function()
		local aliveTiles: { Logic.Tile } = {}
		for row = 0, 7 do
			for col = 0, 7 do
				table.insert(aliveTiles, { row = row, col = col })
			end
		end
		-- (0,0)·(1,1)에 레이서 2명 — 2x2 창 중 (0,0)을 왼쪽위 모서리로 하는 창만 둘 다 포함해요(유일한 최댓값)
		local racers: { Logic.Tile } = { { row = 0, col = 0 }, { row = 1, col = 1 } }
		local crowded = 0
		local trials = 1000
		for seed = 1, trials do
			local window = Logic.pickClawTarget(seededRng(seed * 7 + 1), racers, aliveTiles, 2, 8)
			t.eq(#window, 4, "2x2 항상 4칸")
			local keys: { [number]: boolean } = {}
			for _, tile in window do
				local key = tile.row * 8 + tile.col
				t.ok(key >= 0 and key <= 63, "window tile is a real grid tile")
				keys[key] = true
			end
			if keys[0] and keys[1] and keys[8] and keys[9] then
				crowded += 1
			end
		end
		local ratio = crowded / trials
		t.ok(ratio > 0.7 - 0.07 and ratio < 0.7 + 0.07, `crowded ratio {ratio}`)
	end)

	t.test("AC4: 살아 있는 칸이 창 크기보다 적으면 남은 칸 전부", function()
		local alive: { Logic.Tile } = { { row = 3, col = 3 }, { row = 3, col = 4 }, { row = 4, col = 3 } }
		local window = Logic.pickClawTarget(seededRng(5), {}, alive, 2, 8)
		t.eq(#window, 3)
	end)

	t.test(
		"AC4: 바닥이 거의 다 사라졌어도(흩어진 몇 칸만 생존) 창이 비지 않고 전부 살아 있는 칸",
		function()
			-- 살아 있는 칸 5개(4+1, size*size=4보다 많아서 "남은 칸 전부" 지름길을 안 타요)가 두 구석에 흩어져 있어요.
			-- 무작위 2x2 창 대부분은 아무 것도 못 가져오니 재시도(최대 5번)나 "남은 칸 전부" 돌려주기를 거쳐요.
			local alive: { Logic.Tile } = {
				{ row = 7, col = 7 },
				{ row = 7, col = 6 },
				{ row = 6, col = 7 },
				{ row = 6, col = 6 },
				{ row = 0, col = 0 },
			}
			for seed = 1, 200 do
				local window = Logic.pickClawTarget(seededRng(seed), {}, alive, 2, 8)
				t.ok(#window > 0, `seed {seed}: empty window`)
				for _, tile in window do
					local found = false
					for _, a in alive do
						if a.row == tile.row and a.col == tile.col then
							found = true
						end
					end
					t.ok(found, `seed {seed}: tile ({tile.row},{tile.col}) is alive`)
				end
			end
		end
	)

	---------------------------------------------------------------- AC5
	t.test("AC5: liftedTiles — 2x2는 항상 4칸, 3x3은 가장자리에서 4~9칸으로 잘려요", function()
		for row = 0, 6 do
			for col = 0, 6 do
				t.eq(#Logic.liftedTiles(row, col, 2, 8), 4, `2x2 at ({row},{col})`)
			end
		end
		t.eq(#Logic.liftedTiles(3, 3, 3, 8), 9, "가운데는 안 잘려요")
		t.eq(#Logic.liftedTiles(0, 0, 3, 8), 4, "구석은 4칸으로 잘려요")
		t.eq(#Logic.liftedTiles(0, 3, 3, 8), 6, "가장자리는 6칸으로 잘려요")
		t.eq(#Logic.liftedTiles(7, 7, 3, 8), 4, "반대쪽 구석도 4칸")
		for row = 0, 7 do
			for col = 0, 7 do
				local n = #Logic.liftedTiles(row, col, 3, 8)
				t.ok(n >= 4 and n <= 9, `3x3 at ({row},{col}) = {n}`)
			end
		end
	end)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: overtimeTilt(20, 1, 8) — 8줄, 낮은 쪽부터, 마지막 20초, tiltAngle 단조 증가",
		function()
			local steps = Logic.overtimeTilt(20, 1, 8)
			t.eq(#steps, 8)
			local previousAngle = -1
			for i, step in steps do
				t.eq(step.row, i)
				t.ok(step.dropAt - step.warnAt - 1 < EPS and step.dropAt - step.warnAt - 1 > -EPS, `warn gap at {i}`)
				t.ok(step.tiltAngle > previousAngle, `monotonic at {i}`)
				previousAngle = step.tiltAngle
				if i > 1 then
					t.ok(step.dropAt > steps[i - 1].dropAt, `dropAt increasing at {i}`)
				end
			end
			t.ok(math.abs(steps[#steps].dropAt - 20) < EPS, "마지막 줄은 20초")
			t.ok(math.abs(steps[#steps].tiltAngle - 35) < EPS, "마지막 줄 기울기 35도")
		end
	)

	---------------------------------------------------------------- AC7
	t.test(
		"AC7: 장식 — validate 통과, 예산 안, 시야 상자와 유리벽·천장이 안 겹쳐요",
		function()
			local decor = Art.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			local total = MapKitLogic.count(decor)
			for row = 0, 7 do
				for col = 0, 7 do
					local tileDecor = Art.tileDecor(row, col)
					t.eq(MapKitLogic.validate(tileDecor), nil, `tileDecor({row},{col})`)
					total += MapKitLogic.count(tileDecor)
				end
			end
			t.ok(total <= MapKitLogic.DECOR_PART_BUDGET, `decor {total} parts over budget`)

			local lightCount = 0
			for _, spec in decor do
				if spec.name == Art.NEON then
					lightCount += 1
				end
			end
			t.ok(lightCount <= MapKitLogic.LIGHT_BUDGET, "light budget")

			local sight = Art.courseVolume()
			for _, spec in decor do
				if
					spec.name == "GlassWallNorth"
					or spec.name == "GlassWallSouth"
					or spec.name == "GlassWallWest"
					or spec.name == "GlassWallEast"
					or spec.name == "GlassCeiling"
				then
					local bounds = MapKitLogic.bounds({ spec }) :: Bounds
					t.ok(not overlaps(bounds, sight), `{spec.name} overlaps sight box`)
				end
			end
		end
	)
end
