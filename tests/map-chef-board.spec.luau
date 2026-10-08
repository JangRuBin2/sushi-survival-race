--!strict
-- m4-05 Survival 맵 "셰프의 도마": 칸 격자, 칼 일정, 줄 고르기, 잘려 나가는 칸, 기울기, 넉백 방향, 아트 데이터

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Logic = RobloxRequire.require(Shared.maps.ChefBoardLogic)
local Art = RobloxRequire.require(Shared.maps.ChefBoardArt)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- 60초 한 판을 순수 로직만으로 돌려요. 매 칼마다 check(board, line, previousKey)를 불러요.
local function simulate(seed: number, check: (board: any, line: any, previous: string?) -> ())
	local rng = fakeRng(seed)
	local board = Logic.newBoard()
	local previous: string? = nil
	for _ in Logic.strikeTimes(60) do
		local line = Logic.pickLine(board, previous, rng)
		if line == nil then
			break
		end
		check(board, line, previous)
		Logic.removeCells(board, Logic.cutCells(board, line))
		previous = line.key
	end
	return board
end

-- 점 (px, 0, pz)를 축 (ax, 0, az) 둘레로 angle만큼 돌린 뒤의 y (로드리게스 공식)
local function rotatedY(px: number, pz: number, ax: number, az: number, angle: number): number
	-- k × p 의 y 성분 = az·px - ax·pz
	return (az * px - ax * pz) * math.sin(angle)
end

local function boxesOverlap(a: any, b: any): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: chef-board는 인터페이스를 지키는 Survival 맵", function()
		local map = Maps.get("chef-board")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "셰프의 도마")
		t.eq(map.timeLimit, nil) -- Config.TimeLimit.Survival(60)
	end)

	t.test("AC1: 칸 61개, 중심이 반지름 36 안, 서로 겹치지 않음", function()
		local cells = Logic.cells()
		t.eq(#cells, 61)
		local seen: { [string]: boolean } = {}
		for _, cell in cells do
			t.ok(math.sqrt(cell.x * cell.x + cell.z * cell.z) <= 36, `{cell.key} outside radius 36`)
			t.ok(not seen[cell.key], `duplicate {cell.key}`)
			seen[cell.key] = true
			t.eq(cell.x, cell.i * 8)
			t.eq(cell.z, cell.j * 8)
		end
		-- 같은 크기(8) 칸이 8 간격 격자에 있으면 서로 겹치지 않아요
		for a = 1, #cells do
			for b = a + 1, #cells do
				local dx = math.abs(cells[a].x - cells[b].x)
				local dz = math.abs(cells[a].z - cells[b].z)
				t.ok(dx >= 8 or dz >= 8, `{cells[a].key} overlaps {cells[b].key}`)
			end
		end
	end)

	t.test("AC1: 스폰 24개가 가운데 쪽 칸 위", function()
		local board = Logic.newBoard()
		local spawns = Logic.spawnOffsets()
		t.eq(#spawns, 24)
		local seen: { [string]: boolean } = {}
		for _, s in spawns do
			local i, j = s.x / 8, s.z / 8
			t.ok(i == math.floor(i) and j == math.floor(j), "spawn on a cell centre")
			t.ok(Logic.isAlive(board, i, j), `spawn {i},{j} not on a cell`)
			t.ok(math.abs(i) <= 2 and math.abs(j) <= 2, `spawn {i},{j} not central`)
			local key = `{i},{j}`
			t.ok(not seen[key], "spawns must not share a cell")
			seen[key] = true
		end
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: 칼 주기 6 → 4.5 → 3초, 경고 1.2 → 0.8초", function()
		t.eq(Logic.knifeInterval(5), 6)
		t.eq(Logic.knifeInterval(25), 4.5)
		t.eq(Logic.knifeInterval(45), 3)
		t.eq(Logic.knifeInterval(0), 6)
		t.eq(Logic.knifeInterval(20), 4.5)
		t.eq(Logic.knifeInterval(40), 3)
		t.eq(Logic.warnTime(5), 1.2)
		t.eq(Logic.warnTime(39.9), 1.2)
		t.eq(Logic.warnTime(40), 0.8)
		t.eq(Logic.warnTime(55), 0.8)
	end)

	t.test("AC2: 경고 시각 목록은 주기대로 늘고 60초 안", function()
		local times = Logic.strikeTimes(60)
		t.ok(#times > 5, "several strikes in 60s")
		t.eq(times[1], Logic.FIRST_STRIKE_AT)
		for k = 2, #times do
			t.ok(near(times[k] - times[k - 1], Logic.knifeInterval(times[k - 1])), `gap before #{k}`)
		end
		t.ok(times[#times] < 60, "last strike before time limit")
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: 시드 1~200 — 같은 줄 연속 없음, 남은 칸 0인 줄 안 고름", function()
		for seed = 1, 200 do
			simulate(seed, function(board, line, previous)
				t.ok(line.key ~= previous, `seed {seed}: repeated {line.key}`)
				t.ok(Logic.remainingOn(board, line) > 0, `seed {seed}: picked empty {line.key}`)
			end)
		end
	end)

	t.test("AC3: 남은 칸이 많은 줄이 더 자주 나와요 (가중 랜덤)", function()
		local board = Logic.newBoard()
		local counts: { [string]: number } = {}
		local rng = fakeRng(7)
		for _ = 1, 4000 do
			local line = Logic.pickLine(board, nil, rng) :: any
			counts[line.key] = (counts[line.key] or 0) + 1
		end
		-- Row0(9칸)이 Row4(3칸)보다 많이
		t.ok((counts.Row0 or 0) > (counts.Row4 or 0), "longer line picked more often")
	end)

	t.test("AC3: 다른 줄이 모두 비면 이전 줄도 못 골라 nil", function()
		local board = { alive = { ["0,0"] = true } }
		t.eq(Logic.pickLine(board, nil, fakeRng(1)) ~= nil, true)
		-- (0,0)은 Row0과 Column0에 있어요 — Row0을 막아도 Column0이 남아요
		local line = Logic.pickLine(board, "Row0", fakeRng(1)) :: any
		t.eq(line.key, "Column0")
		t.eq(Logic.pickLine({ alive = {} }, nil, fakeRng(1)), nil)
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: 잘려 나갈 칸 = 줄 양 끝에서 첫 남은 칸, 보호 칸에서 멈춤", function()
		local board = Logic.newBoard()
		local row0 = Logic.makeLine("Row", 0)
		local function keys(cells: { any }): string
			local list = {}
			for _, c in cells do
				table.insert(list, c.key)
			end
			table.sort(list)
			return table.concat(list, " ")
		end
		local expected = { "-4,0 4,0", "-3,0 3,0", "-2,0 2,0", "", "" }
		for round, want in expected do
			local cut = Logic.cutCells(board, row0)
			t.eq(keys(cut), want, `row0 cut #{round}`)
			Logic.removeCells(board, cut)
		end
		t.eq(Logic.remainingOn(board, row0), 3) -- 가운데 3칸

		-- 보호 칸 없는 줄은 끝까지 비워져요 (마지막 한 칸은 한 번만)
		local row4 = Logic.makeLine("Row", 4)
		t.eq(Logic.remainingOn(board, row4), 3)
		local cut1 = Logic.cutCells(board, row4)
		t.eq(keys(cut1), "-1,4 1,4")
		Logic.removeCells(board, cut1)
		local last = Logic.cutCells(board, row4)
		t.eq(keys(last), "0,4")
		Logic.removeCells(board, last)
		t.eq(Logic.remainingOn(board, row4), 0)
		t.eq(#Logic.cutCells(board, row4), 0)
	end)

	t.test("AC4: 시드 1~200으로 60초 뒤에도 가운데 3×3 9칸이 남아 있어요", function()
		for seed = 1, 200 do
			local board = simulate(seed, function(board, line)
				for _, cell in Logic.cutCells(board, line) do
					t.ok(not Logic.isProtected(cell.i, cell.j), `seed {seed}: cutting protected {cell.key}`)
				end
			end)
			local protected = 0
			for i = -1, 1 do
				for j = -1, 1 do
					if Logic.isAlive(board, i, j) then
						protected += 1
					end
				end
			end
			t.eq(protected, 9, `seed {seed}`)
		end
	end)

	t.test("AC4: 60초 동안 도마가 실제로 작아져요", function()
		local board = simulate(3, function() end)
		local alive = 0
		for _ in board.alive do
			alive += 1
		end
		t.ok(alive < 61 and alive >= 9, `alive {alive}`)
	end)

	---------------------------------------------------------------- AC5
	t.test("AC5: 기울기는 10·20·30·40·50초에 시작해 3초, 최대 8도", function()
		local plan = Logic.tiltPlan(fakeRng(5))
		t.eq(#plan, 5)
		local maxAngle = 0
		for k, startAt in { 10, 20, 30, 40, 50 } do
			t.eq(plan[k].startAt, startAt)
			t.eq(Logic.tiltCFrameParams(startAt - 0.01, plan), nil, `before {startAt}`)
			t.ok(Logic.tiltCFrameParams(startAt + 0.1, plan) ~= nil, `just after {startAt}`)
			t.ok(Logic.tiltCFrameParams(startAt + 2.9, plan) ~= nil, `end of {startAt}`)
			t.eq(Logic.tiltCFrameParams(startAt + 3, plan), nil, `after {startAt}`)
			local mid = Logic.tiltCFrameParams(startAt + 1.5, plan) :: any
			t.ok(near(mid.angle, math.rad(8)), "full 8 degrees in the middle")
			t.ok(near(mid.strength, 1), "full strength in the middle")
			for step = 0, 300 do
				local p = Logic.tiltCFrameParams(startAt + step / 100, plan)
				if p then
					maxAngle = math.max(maxAngle, p.angle)
				end
			end
		end
		t.ok(maxAngle <= math.rad(8) + 1e-9, "never more than 8 degrees")
		for _, flat in { 0, 5, 13.5, 25, 59 } do
			t.eq(Logic.tiltCFrameParams(flat, plan), nil, `flat at {flat}`)
		end
	end)

	t.test("AC5: 회전축이 낮은 쪽과 수직이고, 낮은 쪽 가장자리가 내려가요", function()
		for seed = 1, 50 do
			local plan = Logic.tiltPlan(fakeRng(seed))
			local p = Logic.tiltCFrameParams(11.5, plan) :: any
			t.ok(near(p.axisX * p.downX + p.axisZ * p.downZ, 0), "axis ⟂ down")
			t.ok(near(p.downX * p.downX + p.downZ * p.downZ, 1), "down is unit")
			local edge = Logic.BOARD_RADIUS
			t.ok(rotatedY(p.downX * edge, p.downZ * edge, p.axisX, p.axisZ, p.angle) < -4, "low edge goes down")
			t.ok(rotatedY(-p.downX * edge, -p.downZ * edge, p.axisX, p.axisZ, p.angle) > 4, "far edge goes up")
		end
	end)

	t.test("AC5: 넉백 방향은 줄과 수직이고 도마 중심에서 바깥쪽", function()
		local cases = {
			{ line = Logic.makeLine("Row", 2), x = 5, z = 16, want = { 0, 1 } },
			{ line = Logic.makeLine("Row", -3), x = -10, z = -25, want = { 0, -1 } },
			{ line = Logic.makeLine("Column", 1), x = 9, z = -20, want = { 1, 0 } },
			{ line = Logic.makeLine("Column", -4), x = -31, z = 3, want = { -1, 0 } },
			{ line = Logic.makeLine("Row", 0), x = 3, z = -2, want = { 0, -1 } },
			{ line = Logic.makeLine("Row", 0), x = 3, z = 2, want = { 0, 1 } },
			{ line = Logic.makeLine("Column", 0), x = -1, z = 7, want = { -1, 0 } },
		}
		for _, case in cases do
			local dx, dz = Logic.knockDirection(case.line, case.x, case.z)
			t.eq({ dx, dz }, case.want, `{case.line.key} at {case.x},{case.z}`)
			-- 줄 방향(Row = X축, Column = Z축)과 수직
			local alongX = if case.line.axis == "Row" then 1 else 0
			local alongZ = 1 - alongX
			t.eq(dx * alongX + dz * alongZ, 0)
			-- 중심 → 플레이어 방향과 같은 쪽 (바깥쪽)
			t.ok(dx * case.x + dz * case.z > 0, "outward from board centre")
		end
	end)

	t.test("AC5: 칼 맞음은 줄 폭(8) + 여유 안, 줄 밖은 안 맞음", function()
		local row = Logic.makeLine("Row", 2)
		t.eq(Logic.isOnLine(row, 0, 16), true)
		t.eq(Logic.isOnLine(row, -30, 20), true)
		t.eq(Logic.isOnLine(row, 0, 21.4), true)
		t.eq(Logic.isOnLine(row, 0, 22), false)
		t.eq(Logic.isOnLine(row, 0, 8), false)
		local column = Logic.makeLine("Column", -1)
		t.eq(Logic.isOnLine(column, -8, 30), true)
		t.eq(Logic.isOnLine(column, 0, 0), false)
	end)

	---------------------------------------------------------------- AC6
	t.test("AC6: 장식이 MapKitLogic.validate 통과, 600개 이하", function()
		local decor = Art.decor()
		local cellDecor = Art.allCellDecor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.eq(MapKitLogic.validate(cellDecor), nil)
		local total = MapKitLogic.count(decor) + MapKitLogic.count(cellDecor)
		t.ok(total <= MapKitLogic.DECOR_PART_BUDGET, `decor {total} parts`)
		t.ok(#cellDecor > 61, "knife grooves between cells")
	end)

	t.test("AC6: 장식이 시야 상자(도마 윗면 위 2~12, 반지름 안)와 안 겹침", function()
		local volume = Art.courseVolume()
		t.eq(volume.min.y, 2)
		t.eq(volume.max.y, 12)
		for _, list in { Art.decor(), Art.allCellDecor() } do
			for _, spec in list do
				local box = MapKitLogic.bounds({ spec }) :: any
				t.ok(not boxesOverlap(box, volume), `{spec.name} blocks the view`)
			end
		end
	end)

	t.test("AC6: 손님 얼굴은 탈락 높이 아래 (도마 아래 30~60)", function()
		local faces = 0
		for _, spec in Art.decor() do
			if string.sub(spec.name, 1, 8) == "Customer" then
				local box = MapKitLogic.bounds({ spec }) :: any
				t.ok(box.max.y < -Logic.FALL_DEPTH, `{spec.name} top {box.max.y}`)
				t.ok(box.min.y >= -60, `{spec.name} bottom {box.min.y}`)
				if spec.name == "CustomerHead" then
					faces += 1
				end
			end
		end
		t.ok(faces >= 2, "customer faces below the board")
	end)

	t.test("AC6: IntroCamera 3점, 끝점은 도마 바깥 높이 10~25에서 가운데를 봐요", function()
		local points = Art.introCamera()
		t.ok(#points >= 3 and #points <= 5, "3~5 points")
		local last = points[#points]
		t.ok(last.pos.y >= 10 and last.pos.y <= 25, "last height")
		t.ok(math.sqrt(last.pos.x ^ 2 + last.pos.z ^ 2) > Logic.BOARD_RADIUS, "last point outside the board")
		t.ok(math.abs(last.lookAt.x) < 1 and math.abs(last.lookAt.z) < 1, "looks at the centre")
	end)

	t.test("칸 색은 0~255이고 가장자리 칸은 서로 조금씩 달라요", function()
		local edgeColors: { [string]: boolean } = {}
		for _, cell in Logic.cells() do
			local c = Art.cellColor(cell.i, cell.j)
			for _, v in { c.r, c.g, c.b } do
				t.ok(v >= 0 and v <= 255, "colour range")
			end
			if math.max(math.abs(cell.i), math.abs(cell.j)) >= 3 then
				edgeColors[`{c.r},{c.g},{c.b}`] = true
			end
		end
		local distinct = 0
		for _ in edgeColors do
			distinct += 1
		end
		t.ok(distinct >= 3, "edge pieces vary")
	end)
end
