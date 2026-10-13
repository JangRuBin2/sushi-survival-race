--!strict
-- m5-19 QA: "인형뽑기 기계 속"(claw-machine-prize) 경계값·불변식.
--   - 격자 좌표: colOf/rowOf가 tileLocalX/tileLocalZGrid의 역함수, 정수 아닌 칸 번호는 nil.
--   - liftedTiles: 3x3은 모서리 4·가장자리 6·안쪽 9칸, 2x2는 어디서나 4칸, 격자 밖 칸 없음.
--   - clawWave: 30·60초 경계 바로 앞뒤, 디버그 overtimeAt이 출발 여유(5초)보다 빨라도 연장전 값.
--   - pickClawTarget 무작위 플레이 300판: 결과는 비지 않고, 살아 있는 칸만, 한 창(size x size) 안,
--     칸을 다 치울 때까지 반복해도 무한 루프 없음.
--   - overtimeTilt: collapseDuration 8·20·40에서 8줄 정확히 한 번, 경고 창이 겹치지 않음, 마지막이 정확히 끝,
--     기울기 0~35 단조.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.maps.ClawMachinePrizeLayout)
local Logic = RobloxRequire.require(Shared.maps.ClawMachinePrizeLogic)

local EPS = 1e-9

-- Random:NextInteger·NextNumber 모양 (Park–Miller, 곱이 2^53 안이라 정확)
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

return function(t: Test.Test)
	t.test(
		"QA 격자: colOf/rowOf는 칸 중심·가장자리 안쪽에서 역함수, 정수 아닌 칸 번호는 nil",
		function()
			for i = 0, Layout.GRID_SIZE - 1 do
				t.eq(Layout.colOf(Layout.tileLocalX(i)), i)
				t.eq(Layout.rowOf(Layout.tileLocalZGrid(i)), i)
				t.eq(Layout.colOf(Layout.tileLocalX(i) - Layout.TILE_SIZE / 2 + 0.01), i)
				t.eq(Layout.colOf(Layout.tileLocalX(i) + Layout.TILE_SIZE / 2 - 0.01), i)
			end
			t.eq(Layout.colOf(-Layout.BOX_SIZE / 2 - 0.01), -1)
			t.eq(Layout.colOf(Layout.BOX_SIZE / 2), Layout.GRID_SIZE)
			t.eq(Layout.tileIndex(1.5, 2), nil)
			t.eq(Layout.tileIndex(0, 7), 7)
			t.eq(Layout.tileIndex(7, 7), 63)
			t.eq(Layout.tileIndex(8, 0), nil)
			t.eq(Layout.tileIndex(0, -1), nil)
		end
	)

	t.test("QA 격자: 칸 높이는 ±1.5 안, 같은 칸은 늘 같은 값", function()
		for row = 0, 7 do
			for col = 0, 7 do
				local h = Layout.tileHeight(row, col)
				t.ok(math.abs(h) <= Layout.HEIGHT_RANGE + EPS, `({row},{col}) {h}`)
				t.eq(Layout.tileHeight(row, col), h)
			end
		end
	end)

	t.test(
		"QA liftedTiles: 3x3은 모서리 4·가장자리 6·안쪽 9칸, 2x2는 어디서나 4칸, 격자 밖 없음",
		function()
			for row = 0, 7 do
				for col = 0, 7 do
					local tiles = Logic.liftedTiles(row, col, 3, 8)
					local edgeR = row == 0 or row == 7
					local edgeC = col == 0 or col == 7
					local expected = if edgeR and edgeC then 4 elseif edgeR or edgeC then 6 else 9
					t.eq(#tiles, expected, `3x3 at ({row},{col})`)
					for _, tile in tiles do
						t.ok(Layout.tileIndex(tile.row, tile.col) ~= nil, "outside grid")
						t.ok(math.abs(tile.row - row) <= 1 and math.abs(tile.col - col) <= 1, "outside window")
					end
				end
			end
			for row = 0, 6 do
				for col = 0, 6 do
					t.eq(#Logic.liftedTiles(row, col, 2, 8), 4, `2x2 at ({row},{col})`)
				end
			end
			t.eq(#Logic.liftedTiles(3, 3, 0, 8), 0)
		end
	)

	t.test(
		"QA clawWave 경계: 29.999/30, 59.999/60, 디버그 연장전이 5초 전이어도 연장전 값",
		function()
			local function w(e: number, ot: number?)
				local wave = Logic.clawWave(e, ot)
				return if wave then { wave.interval, wave.size, wave.warnTime } else nil
			end
			t.eq(w(29.999), { 8, 2, 2 })
			t.eq(w(30), { 6, 2, 1.5 })
			t.eq(w(59.999), { 6, 2, 1.5 })
			t.eq(w(60), { 4, 3, 1.2 })
			t.eq(w(89.99, 90), { 4, 3, 1.2 })
			t.eq(w(90, 90), { 2.5, 3, 1 })
			t.eq(w(4, 3), { 2.5, 3, 1 })
			t.eq(w(0), nil)
			t.eq(w(500), { 4, 3, 1.2 })
			-- 경고는 언제나 주기보다 짧아요 (경고가 다음 과녁과 겹쳐 쌓이지 않게)
			for e = 5, 200, 0.5 do
				local wave = Logic.clawWave(e, 90) :: any
				t.ok(wave.warnTime < wave.interval, `warn ≥ interval at {e}`)
			end
		end
	)

	t.test(
		"QA pickClawTarget 무작위 300판: 비지 않음, 살아 있는 칸만, 한 창 안, 다 치울 때까지 끝남",
		function()
			local rng = pmRng(1919)
			for game = 1, 300 do
				local alive: { [number]: boolean } = {}
				local aliveCount = 64
				for i = 0, 63 do
					alive[i] = true
				end
				local racers = {}
				for _ = 1, rng:NextInteger(0, 8) do
					table.insert(racers, { row = rng:NextInteger(0, 7), col = rng:NextInteger(0, 7) })
				end
				local waves = 0
				while aliveCount > 0 do
					waves += 1
					t.ok(waves <= 64, `game {game}: too many waves`)
					if waves > 64 then
						break
					end
					local aliveList = {}
					for i = 0, 63 do
						if alive[i] then
							table.insert(aliveList, { row = i // 8, col = i % 8 })
						end
					end
					local size = if rng:NextInteger(1, 2) == 1 then 2 else 3
					local chosen = Logic.pickClawTarget(rng, racers, aliveList, size, 8)
					t.ok(#chosen > 0, "empty target with tiles alive")
					local minR, maxR, minC, maxC = 99, -1, 99, -1
					for _, tile in chosen do
						local index = Layout.tileIndex(tile.row, tile.col) :: number
						t.ok(alive[index] == true, `game {game}: picked dead tile {index}`)
						minR, maxR = math.min(minR, tile.row), math.max(maxR, tile.row)
						minC, maxC = math.min(minC, tile.col), math.max(maxC, tile.col)
					end
					local whole = #aliveList <= size * size
					if whole then
						t.eq(#chosen, #aliveList, "few tiles left → all of them")
					elseif not (maxR - minR < size and maxC - minC < size) then
						-- 한 창보다 넓으면 스펙의 마지막 대비책("재시도 5번 실패 → 남은 칸 전부")뿐이에요 (리포트 B 참고)
						t.eq(#chosen, #aliveList, `game {game}: target wider than {size} but not the whole remainder`)
					end
					for _, tile in chosen do
						local index = Layout.tileIndex(tile.row, tile.col) :: number
						if alive[index] then
							alive[index] = nil
							aliveCount -= 1
						end
					end
				end
			end
		end
	)

	t.test(
		"QA overtimeTilt: 8·20·40초 — 8줄 정확히 한 번, 경고 창 안 겹침, 마지막 = 끝, 기울기 0~35 단조",
		function()
			for _, duration in { 8, 20, 40 } do
				local steps = Logic.overtimeTilt(duration, 1, 8)
				t.eq(#steps, 8)
				local seen = {}
				local prevDrop = -math.huge
				local prevTilt = -math.huge
				for i, step in steps do
					t.eq(step.row, i, "lowest line first, in order")
					t.ok(not seen[step.row], "line twice")
					seen[step.row] = true
					t.ok(step.warnAt >= -EPS, `negative warnAt {step.warnAt}`)
					t.ok(math.abs(step.dropAt - step.warnAt - 1) < 1e-9, "warn = 1s")
					t.ok(step.warnAt >= prevDrop - 1e-9, `warn windows overlap at line {i} (duration {duration})`)
					t.ok(step.dropAt <= duration + EPS, "drops after collapseDuration")
					t.ok(step.tiltAngle >= prevTilt - EPS and step.tiltAngle <= Logic.OVERTIME_MAX_TILT + EPS, "tilt")
					prevDrop, prevTilt = step.dropAt, step.tiltAngle
				end
				t.ok(math.abs(steps[8].dropAt - duration) < 1e-9, "last line at collapseDuration")
				t.ok(math.abs(steps[8].tiltAngle - Logic.OVERTIME_MAX_TILT) < 1e-9, "35° at the end")
			end
			-- 아주 짧은 붕괴(4초)여도 경고를 줄여 끝 시각을 지켜요
			local short = Logic.overtimeTilt(4, 1, 8)
			t.ok(math.abs(short[8].dropAt - 4) < 1e-9)
			t.ok(short[1].warnAt >= -EPS)
			t.eq(#Logic.overtimeTilt(0, 1, 8), 0)
		end
	)
end
