--!strict
-- m5-17·m5-18·m5-19 QA 수정 회귀 테스트 (브랜치 m5-maps-fix-b).
--   m5-19 B1: 연장전 기울기는 격자 중심 축, 4방향 모두 낮아지는 줄부터 사라지고, 가만히 선 사람은
--             기울기만으로 낙하선 아래로 가지 않아요.
--   m5-19 B2: 연장전 전에는 바닥을 reserveTiles(살아 있는 인원)만큼 남겨요 — 400판 시뮬레이션.
--   m5-19 B3: 이웃 칸 높이 차 ≤ 2.
--   m5-18 B1: collapseDuration 뒤 발판은 설 수 없는 면(충돌 끔). B2: 발판 길이 밖은 토크에서 빠져요.
--   m5-17 B1: 고양이 발 실제 주기 = 표의 간격. B2: 공 판정이 폭 방향 거리도 봐요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local ClawLayout = RobloxRequire.require(Shared.maps.ClawMachinePrizeLayout)
local ClawLogic = RobloxRequire.require(Shared.maps.ClawMachinePrizeLogic)
local TugLayout = RobloxRequire.require(Shared.maps.TugOfWarPlatformLayout)
local TugLogic = RobloxRequire.require(Shared.maps.TugOfWarPlatformLogic)
local CatLayout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)
local CatLogic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)

local EPS = 1e-9
local GRID = ClawLayout.GRID_SIZE
local DIRS = {
	{ dim = "row", sign = 1 },
	{ dim = "row", sign = -1 },
	{ dim = "col", sign = 1 },
	{ dim = "col", sign = -1 },
}

-- Random:NextInteger·NextNumber 모양 (Park–Miller)
local function pmRng(seed: number): any
	local state = seed
	local function unit(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_self: any): number
			return unit()
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(unit() * (max - min + 1))
		end,
	}
end

-- CFrame.Angles(rx, 0, rz)와 같은 회전 행렬(X축 먼저가 아니라 축 하나씩만 쓰니 순서 무관)로
-- 격자 중심 기준 점 (x, 0, z)의 회전 뒤 높이를 따로 계산해요 (Logic 공식과 독립 확인).
local function rotatedY(x: number, z: number, rx: number, rz: number): number
	-- X축 회전: y' = y·cos(rx) − z·sin(rx), z' = y·sin(rx) + z·cos(rx)
	local y1 = -z * math.sin(rx)
	-- Z축 회전: y'' = x·sin(rz) + y'·cos(rz)
	return x * math.sin(rz) + y1 * math.cos(rz)
end

-- 줄 i의 가운데(격자 중심 기준 오프셋, 줄 방향 축)
local function lineLateral(i: number): number
	return (i - (GRID - 1) / 2) * ClawLayout.TILE_SIZE
end

return function(t: Test.Test)
	t.test("m5-19 B1: tiltedHeight는 CFrame 회전 행렬과 같다 (4방향)", function()
		for _, dir in DIRS do
			for _, deg in { 5, 20, 35 } do
				local angle = math.rad(deg)
				local rx, rz = ClawLogic.tiltRotation(dir.dim, dir.sign, angle)
				for i = 0, GRID - 1 do
					local lateral = lineLateral(i)
					local x = if dir.dim == "col" then lateral else 0
					local z = if dir.dim == "row" then lateral else 0
					local expected = rotatedY(x, z, rx, rz)
					local got = ClawLogic.tiltedHeight(dir.dim, dir.sign, lateral, angle)
					t.ok(math.abs(expected - got) < 1e-6, `{dir.dim}{dir.sign} {deg}° line {i}: {got} vs {expected}`)
				end
			end
		end
	end)

	t.test("m5-19 B1: 4방향 모두 줄이 사라지는 순간 그 줄이 남은 줄 중 가장 낮다", function()
		for _, dir in DIRS do
			local order = ClawLogic.tiltLineOrder(dir.dim, dir.sign, GRID)
			t.eq(#order, GRID)
			local seen: { [number]: boolean } = {}
			for _, i in order do
				t.ok(not seen[i] and i >= 0 and i < GRID, `{dir.dim}{dir.sign}: bad line {i}`)
				seen[i] = true
			end
			for _, duration in { 8, 20, 40 } do
				local steps = ClawLogic.overtimeTilt(duration, 1, GRID)
				for k, step in steps do
					local angle = math.rad(step.tiltAngle)
					local myRx, myRz = ClawLogic.tiltRotation(dir.dim, dir.sign, angle)
					local function heightOf(i: number): number
						local lateral = lineLateral(i)
						return rotatedY(
							if dir.dim == "col" then lateral else 0,
							if dir.dim == "row" then lateral else 0,
							myRx,
							myRz
						)
					end
					local dropping = heightOf(order[step.row])
					for j = k + 1, #steps do
						local other = heightOf(order[steps[j].row])
						t.ok(
							dropping <= other + EPS,
							`{dir.dim}{dir.sign} d={duration}: line {order[step.row]} ({dropping}) dropped before lower line {order[steps[j].row]} ({other})`
						)
					end
				end
			end
		end
	end)

	t.test(
		"m5-19 B1: 가만히 선 칸은 자기 줄이 사라지기 전까지 기울기만으로 낙하선 아래로 안 간다",
		function()
			local duration = 20
			for _, dir in DIRS do
				local order = ClawLogic.tiltLineOrder(dir.dim, dir.sign, GRID)
				for _, step in ClawLogic.overtimeTilt(duration, 1, GRID) do
					local line = order[step.row]
					-- 그 줄의 가장 낮은 모서리(칸 가장자리 ±TILE/2), 가장 낮은 칸 높이, dropAt 직전 기울기
					local angle = math.rad(ClawLogic.OVERTIME_MAX_TILT) * (step.dropAt / duration)
					local rx, rz = ClawLogic.tiltRotation(dir.dim, dir.sign, angle)
					local lowest = math.huge
					for _, edge in { -ClawLayout.TILE_SIZE / 2, ClawLayout.TILE_SIZE / 2 } do
						local lateral = lineLateral(line) + edge
						for _, across in { -ClawLayout.BOX_SIZE / 2, ClawLayout.BOX_SIZE / 2 } do
							local x = if dir.dim == "col" then lateral else across
							local z = if dir.dim == "row" then lateral else across
							lowest = math.min(lowest, rotatedY(x, z, rx, rz) - ClawLayout.HEIGHT_RANGE)
						end
					end
					t.ok(lowest > -ClawLayout.FALL_DEPTH, `{dir.dim}{dir.sign} line {line}: lowest {lowest}`)
				end
			end
		end
	)

	t.test("m5-19 B3: 이웃 칸 높이 차 ≤ 2", function()
		local worst = 0
		for row = 0, GRID - 1 do
			for col = 0, GRID - 1 do
				local h = ClawLayout.tileHeight(row, col)
				if col + 1 < GRID then
					worst = math.max(worst, math.abs(h - ClawLayout.tileHeight(row, col + 1)))
				end
				if row + 1 < GRID then
					worst = math.max(worst, math.abs(h - ClawLayout.tileHeight(row + 1, col)))
				end
			end
		end
		t.ok(worst <= 2 + EPS, `worst neighbour diff {worst}`)
	end)

	t.test(
		"m5-19 B2: reserveTiles = max(6, 2 x 인원), capGrab은 그 아래로 안 내려가고 사람 칸을 먼저 집는다",
		function()
			t.eq(ClawLogic.reserveTiles(0), 6)
			t.eq(ClawLogic.reserveTiles(2), 6)
			t.eq(ClawLogic.reserveTiles(3), 6)
			t.eq(ClawLogic.reserveTiles(4), 8)
			t.eq(ClawLogic.reserveTiles(8), 16)
			local window = {
				{ row = 0, col = 0 },
				{ row = 0, col = 1 },
				{ row = 1, col = 0 },
				{ row = 1, col = 1 },
			}
			t.eq(#ClawLogic.capGrab(window, 30, 4, {}), 4) -- 여유 22
			t.eq(#ClawLogic.capGrab(window, 10, 4, {}), 2) -- 10 - 8
			t.eq(#ClawLogic.capGrab(window, 8, 4, {}), 0) -- 여유 없음: 그 차례 쉼
			t.eq(#ClawLogic.capGrab(window, 5, 2, {}), 0)
			local capped = ClawLogic.capGrab(window, 9, 4, { { row = 1, col = 1 } })
			t.eq(#capped, 1)
			t.eq(capped[1].row, 1)
			t.eq(capped[1].col, 1)
		end
	)

	t.test(
		"m5-19 B2: 시뮬레이션 400판 x 2·4·8명 — 연장전(90초) 전에 바닥이 비는 판 0",
		function()
			local TIME_LIMIT = 90
			for _, racers in { 2, 4, 8 } do
				local rng = pmRng(1000 + racers)
				local emptyBefore90 = 0
				local belowReserve = 0
				local reachedOvertime, endedByElims = 0, 0
				local remainingAt90 = 0
				for _ = 1, 400 do
					local alive: { [number]: boolean } = {}
					for i = 0, GRID * GRID - 1 do
						alive[i] = true
					end
					local aliveCount = GRID * GRID
					local racerCount = racers
					local now = 0
					while now < TIME_LIMIT and racerCount > 1 do
						local wave = ClawLogic.clawWave(now, nil)
						if wave == nil then
							now = ClawLogic.START_GRACE
							continue
						end
						local aliveTiles = {}
						for i = 0, GRID * GRID - 1 do
							if alive[i] then
								table.insert(aliveTiles, { row = i // GRID, col = i % GRID })
							end
						end
						-- 레이서는 남은 칸에 무작위로 서 있어요
						local positions = {}
						for _ = 1, racerCount do
							table.insert(positions, aliveTiles[rng:NextInteger(1, #aliveTiles)])
						end
						local chosen = ClawLogic.pickClawTarget(rng, positions, aliveTiles, wave.size, GRID)
						chosen = ClawLogic.capGrab(chosen, #aliveTiles, racerCount, positions)
						local hitSet: { [number]: boolean } = {}
						for _, tile in chosen do
							local index = tile.row * GRID + tile.col
							t.ok(alive[index], "grab only alive tiles")
							alive[index] = nil
							hitSet[index] = true
							aliveCount -= 1
						end
						-- 집힌 칸 위의 사람은 25% 확률로 못 피하고 떨어져요
						for _, pos in positions do
							if hitSet[pos.row * GRID + pos.col] and racerCount > 1 and rng:NextNumber() < 0.25 then
								racerCount -= 1
							end
						end
						if aliveCount <= 0 then
							emptyBefore90 += 1
							break
						end
						if aliveCount < ClawLogic.reserveTiles(racerCount) then
							belowReserve += 1
						end
						now += wave.interval
					end
					if racerCount <= 1 then
						endedByElims += 1
					elseif now >= TIME_LIMIT and aliveCount > 0 then
						reachedOvertime += 1
						remainingAt90 += aliveCount
					end
				end
				t.eq(emptyBefore90, 0)
				t.eq(belowReserve, 0)
				t.eq(reachedOvertime + endedByElims, 400)
				-- 연장전까지 간 판에서도 집게는 바쁘게 움직였어요(90초 때 평균 남은 칸이 절반 아래)
				local avgRemaining = if reachedOvertime > 0 then remainingAt90 / reachedOvertime else 0
				print(
					`[sim] {racers} racers: overtime {reachedOvertime}/400, elims {endedByElims}/400, avg tiles at 90s {avgRemaining}`
				)
				t.ok(avgRemaining < GRID * GRID / 2, `{racers} racers: avg tiles at 90s {avgRemaining}`)
			end
		end
	)

	t.test("m5-18 B1: 연장전 collapseDuration 뒤 발판은 설 수 없는 면", function()
		t.eq(TugLogic.platformSolid(nil, 20), true)
		t.eq(TugLogic.platformSolid(0, 20), true)
		t.eq(TugLogic.platformSolid(19.99, 20), true)
		t.eq(TugLogic.platformSolid(20, 20), false)
		t.eq(TugLogic.platformSolid(60, 20), false)
		t.eq(TugLogic.platformSolid(0, 0), false)
	end)

	t.test("m5-18 B2: 발판 길이 밖(|x| > 절반 길이)은 토크에서 빠진다", function()
		local half = TugLayout.HALF_LENGTH
		t.eq(TugLogic.riderX(0, half), 0)
		t.eq(TugLogic.riderX(half, half), half)
		t.eq(TugLogic.riderX(-half, half), -half)
		t.eq(TugLogic.riderX(half + 0.01, half), nil)
		t.eq(TugLogic.riderX(-40, half), nil)
	end)

	t.test("m5-17 B1: 고양이 발 실제 주기 = 표의 간격 (경고 1.1초가 간격 안에)", function()
		for _, at in { 10, 30, 50 } do
			local interval = CatLogic.pawInterval(at) :: number
			local spent = CatLogic.PAW_WARN_TIME
			t.ok(math.abs(spent + CatLogic.pawRest(interval, spent) - interval) < EPS, `t={at}`)
		end
		t.eq(CatLogic.pawRest(2, 0), 2) -- 대상 없는 차례
		t.eq(CatLogic.pawRest(1, 3), 0) -- 음수 없음
	end)

	t.test("m5-17 B2: 공 판정은 폭 방향 거리도 본다", function()
		local r = CatLogic.BALL_HIT_RANGE
		t.eq(CatLogic.isHitAt(0, 0), true)
		t.eq(CatLogic.isHitAt(-r, r), true)
		t.eq(CatLogic.isHitAt(0, 5), false) -- 꼭대기에서 공과 Z로 5 떨어진 사람
		t.eq(CatLogic.isHitAt(r + 0.1, 0), false)
		-- 1·2단(폭 4)은 폭 어디에 서 있어도 폭 방향으로는 맞을 수 있어요 (전과 같음)
		for _, shelf in CatLayout.shelves() do
			if shelf.side ~= "Top" then
				t.eq(CatLogic.isHitAt(0, CatLayout.SHELF_WIDTH / 2), true)
			end
		end
	end)
end
