--!strict
-- m5-17·m5-18·m5-19 재QA (브랜치 m5-maps-fix-b). developer 회귀 테스트(m5-maps-fix-b.spec)와 독립으로 확인해요.
--   m5-19 B1: 서버가 실제로 하는 합성(newPivot = G·R·G⁻¹·O, 파츠 = newPivot·O⁻¹·파츠)을 3x3 행렬로 직접 계산.
--             origin이 돌아가 있고(yaw) 떨어져 있어도, 4방향 모두 줄이 사라지는 순간 그 줄이 남은 줄 중 가장 낮고,
--             아직 남은 칸 위에 선 사람(칸 윗면 + 루트 3)은 낙하선(origin 기준 Y −25) 위.
--   m5-19 B2: 서버 루프 시각 그대로(경고 동안 pending, 경고 끝에 바닥 사라짐) + 사람이 피하는 확률을 바꿔 가며
--             시뮬레이션. 90초 전 바닥 0칸·reserve 미만 0번. 숫자는 출력만(설계 판단은 리포트).
--   m5-18 B1: collapseDuration 이상이면 각도 ±90°이고 같은 순간 platformSolid false (턱이 남는 틱이 없음).
--   m5-17 B1: 서버 루프를 그대로 따라 경고 시작 간격 = 표(5 / 3.2 / 2). B2: 꼭대기에서 공과 폭 방향 2.2 넘게
--             떨어지면 안 맞고, 1·2단은 선반 위 어디서나 폭 방향 판정이 전과 같음.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local ClawLayout = RobloxRequire.require(Shared.maps.ClawMachinePrizeLayout)
local ClawLogic = RobloxRequire.require(Shared.maps.ClawMachinePrizeLogic)
local TugLogic = RobloxRequire.require(Shared.maps.TugOfWarPlatformLogic)
local CatLayout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)
local CatLogic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)

local GRID = ClawLayout.GRID_SIZE
local DIRS = {
	{ dim = "row", sign = 1 },
	{ dim = "row", sign = -1 },
	{ dim = "col", sign = 1 },
	{ dim = "col", sign = -1 },
}

-- 작은 CFrame: { r = 3x3 (행 우선), p = {x,y,z} }
type M3 = { number }
type CF = { r: M3, p: { number } }

local function mmul(a: M3, b: M3): M3
	local out = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			out[i * 3 + j + 1] = s
		end
	end
	return out
end
local function mvec(a: M3, v: { number }): { number }
	return {
		a[1] * v[1] + a[2] * v[2] + a[3] * v[3],
		a[4] * v[1] + a[5] * v[2] + a[6] * v[3],
		a[7] * v[1] + a[8] * v[2] + a[9] * v[3],
	}
end
local function transpose(a: M3): M3
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end
local function cf(x: number, y: number, z: number, r: M3?): CF
	return { r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = { x, y, z } }
end
local function cmul(a: CF, b: CF): CF
	local pv = mvec(a.r, b.p)
	return { r = mmul(a.r, b.r), p = { pv[1] + a.p[1], pv[2] + a.p[2], pv[3] + a.p[3] } }
end
local function cinv(a: CF): CF
	local rt = transpose(a.r)
	local pv = mvec(rt, a.p)
	return { r = rt, p = { -pv[1], -pv[2], -pv[3] } }
end
local function point(a: CF, v: { number }): { number }
	local pv = mvec(a.r, v)
	return { pv[1] + a.p[1], pv[2] + a.p[2], pv[3] + a.p[3] }
end
-- Roblox 회전 (오른손): Rx, Ry, Rz
local function rotX(t: number): M3
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(t: number): M3
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(t: number): M3
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

return function(t: Test.Test)
	t.test(
		"m5-19 재QA B1: 실제 피벗 합성(origin 회전·이동 포함)으로 4방향 낮은 줄부터, 선 사람은 낙하선 위",
		function()
			local ROOT_ABOVE = 3 -- 칸 윗면에서 HumanoidRootPart까지 (대략)
			for _, yaw in { 0, 37, -120 } do
				local origin = cf(1234, 300, -2000, rotY(math.rad(yaw)))
				local originInv = cinv(origin)
				local gridCenter = cmul(origin, cf(0, 0, ClawLayout.CENTER_Z))
				local gridCenterInv = cinv(gridCenter)
				for _, dir in DIRS do
					local order = ClawLogic.tiltLineOrder(dir.dim, dir.sign, GRID)
					local steps = ClawLogic.overtimeTilt(20, 1, GRID)
					local gone: { [number]: boolean } = {}
					for _, step in steps do
						local angle = math.rad(ClawLogic.OVERTIME_MAX_TILT) * (step.dropAt / 20)
						local rx, rz = ClawLogic.tiltRotation(dir.dim, dir.sign, angle)
						local r = mmul(rotX(rx), rotZ(rz)) -- 한 축만 0이 아니라 순서 무관
						local newPivot = cmul(cmul(cmul(gridCenter, cf(0, 0, 0, r)), gridCenterInv), origin)
						local move = cmul(newPivot, originInv) -- 파츠 world → world
						-- 각 줄 가운데의 origin 기준 높이, 남은 칸 위 가장 낮은 "선 사람" 높이
						local function lineHeight(i: number): number
							local x = if dir.dim == "col" then ClawLayout.tileLocalX(i) else 0
							local z = if dir.dim == "row" then ClawLayout.tileLocalZGrid(i) else 0
							local world = point(move, point(origin, { x, 0, ClawLayout.CENTER_Z + z }))
							return point(originInv, world)[2]
						end
						local line = order[step.row]
						local h = lineHeight(line)
						for i = 0, GRID - 1 do
							if not gone[i] and i ~= line then
								t.ok(
									h <= lineHeight(i) + 1e-6,
									`yaw {yaw} {dir.dim}{dir.sign}: line {line} {h} > line {i}`
								)
							end
						end
						-- 사라지기 직전 이 줄(남은 줄 중 가장 낮음)의 칸 위 모서리에 선 사람
						local up = mvec(move.r, mvec(origin.r, { 0, 1, 0 }))
						local upLocal = mvec(transpose(origin.r), up)
						for _, edge in { -ClawLayout.TILE_SIZE / 2, ClawLayout.TILE_SIZE / 2 } do
							for _, across in { -ClawLayout.BOX_SIZE / 2, ClawLayout.BOX_SIZE / 2 } do
								local lateral = (
									if dir.dim == "col"
										then ClawLayout.tileLocalX(line)
										else ClawLayout.tileLocalZGrid(line)
								) + edge
								local x = if dir.dim == "col" then lateral else across
								local z = if dir.dim == "row" then lateral else across
								local top = -ClawLayout.HEIGHT_RANGE
								local world = point(move, point(origin, { x, top, ClawLayout.CENTER_Z + z }))
								local y = point(originInv, world)[2] + ROOT_ABOVE * upLocal[2]
								t.ok(y > -ClawLayout.FALL_DEPTH, `yaw {yaw} {dir.dim}{dir.sign} line {line}: root {y}`)
							end
						end
						gone[line] = true
					end
				end
			end
		end
	)

	t.test(
		"m5-19 재QA B2: 서버 시각 그대로 시뮬레이션 — 90초 전 바닥 0칸 없음, reserve 미만 없음",
		function()
			local TIME_LIMIT = 90
			local DT = 0.1
			local GAMES = 400
			for _, missChance in { 0, 0.1, 0.25 } do
				for _, racers in { 2, 3, 4, 6, 8 } do
					local seed = 7000 + racers * 13 + math.floor(missChance * 100)
					local state = seed
					local function unit(): number
						state = (state * 48271) % 2147483647
						return state / 2147483647
					end
					local rng = {
						NextNumber = function(_self: any): number
							return unit()
						end,
						NextInteger = function(_self: any, min: number, max: number): number
							return min + math.floor(unit() * (max - min + 1))
						end,
					}
					local emptyBefore = 0
					local belowReserve = 0
					local endedBefore = 0
					local endTimes: { number } = {}
					local tilesAt90 = 0
					local reached = 0
					for _ = 1, GAMES do
						local alive: { [number]: boolean } = {}
						for i = 0, GRID * GRID - 1 do
							alive[i] = true
						end
						local pending: { [number]: number } = {} -- index -> drop 시각
						local pos: { number } = {} -- 레이서마다 칸 index
						local function freeTiles(): { number }
							local list = {}
							for i = 0, GRID * GRID - 1 do
								if alive[i] and not pending[i] then
									table.insert(list, i)
								end
							end
							return list
						end
						do
							local free = freeTiles()
							for r = 1, racers do
								pos[r] = free[rng:NextInteger(1, #free)]
							end
						end
						local now = 0
						local nextPick = ClawLogic.START_GRACE
						local ended = false
						while now < TIME_LIMIT do
							now += DT
							-- 바닥 사라짐
							for index, dropAt in pending do
								if now >= dropAt then
									pending[index] = nil
									alive[index] = nil
									for r = #pos, 1, -1 do
										if pos[r] == index and #pos > 1 then
											table.remove(pos, r)
										end
									end
								end
							end
							if #pos <= 1 then
								ended = true
								table.insert(endTimes, now)
								break
							end
							local remaining = 0
							for _ in alive do
								remaining += 1
							end
							if remaining == 0 then
								emptyBefore += 1
								break
							end
							if now >= nextPick then
								local wave = ClawLogic.clawWave(now, nil) :: any
								local free = freeTiles()
								if #free > 0 then
									local occupied = {}
									for _, index in pos do
										table.insert(occupied, { row = index // GRID, col = index % GRID })
									end
									local chosen = ClawLogic.pickClawTarget(
										rng,
										occupied,
										(function()
											local list = {}
											for _, index in free do
												table.insert(list, { row = index // GRID, col = index % GRID })
											end
											return list
										end)(),
										wave.size,
										GRID
									)
									chosen = ClawLogic.capGrab(chosen, #free, #pos, occupied)
									local hit: { [number]: boolean } = {}
									for _, tile in chosen do
										local index = tile.row * GRID + tile.col
										pending[index] = now + wave.warnTime
										hit[index] = true
									end
									if #free - #chosen < ClawLogic.reserveTiles(#pos) then
										belowReserve += 1
									end
									-- 경고를 본 사람은 (1 - missChance) 확률로 남은 칸으로 피해요. 나머지는 가만히/무작위 이동.
									local stillFree = freeTiles()
									for r, index in pos do
										if hit[index] then
											if unit() >= missChance and #stillFree > 0 then
												pos[r] = stillFree[rng:NextInteger(1, #stillFree)]
											end
										elseif unit() < 0.5 and #stillFree > 0 then
											pos[r] = stillFree[rng:NextInteger(1, #stillFree)]
										end
									end
								end
								nextPick = now + wave.interval
							end
						end
						if ended then
							endedBefore += 1
						elseif now >= TIME_LIMIT then
							reached += 1
							for _ in alive do
								tilesAt90 += 1
							end
						end
					end
					table.sort(endTimes)
					local median = if #endTimes > 0 then endTimes[math.max(1, #endTimes // 2)] else 0
					print(
						string.format(
							"[reqa-sim] miss %.2f racers %d: empty<90 %d, below reserve %d, ended<90 %d/%d (median %.0fs), overtime %d (avg tiles at 90 %.1f)",
							missChance,
							racers,
							emptyBefore,
							belowReserve,
							endedBefore,
							GAMES,
							median,
							reached,
							if reached > 0 then tilesAt90 / reached else 0
						)
					)
					t.eq(emptyBefore, 0)
					t.eq(belowReserve, 0)
					t.eq(endedBefore + reached, GAMES)
				end
			end
		end
	)

	t.test(
		"m5-18 재QA B1: collapseDuration부터 각도 ±90°이고 같은 순간 발판 충돌이 꺼진다",
		function()
			for _, duration in { 8, 20, 40 } do
				for _, startAngle in { 0, math.rad(30), -math.rad(30) } do
					for _, dt in { -0.01, 0, 0.01, 5, 100 } do
						local since = duration + dt
						local angle = TugLogic.overtimeAngle(since, duration, startAngle)
						local solid = TugLogic.platformSolid(since, duration)
						if dt >= 0 then
							t.ok(
								math.abs(math.abs(angle) - TugLogic.LETHAL_ANGLE) < 1e-9,
								`d={duration} dt={dt} angle {angle}`
							)
							t.eq(solid, false)
						else
							t.eq(solid, true)
						end
					end
				end
			end
		end
	)

	t.test("m5-17 재QA B1: 서버 루프대로 돌리면 경고 시작 간격 = 표의 간격", function()
		-- 루프: cycleStart → interval = pawInterval(cycleStart) → 경고 1.1초 → 밀기 → wait(max(0.05, pawRest))
		local now = CatLogic.PAW_GRACE
		local starts = {}
		while now < 60 do
			table.insert(starts, now)
			local interval = CatLogic.pawInterval(now) or 2
			local spent = CatLogic.PAW_WARN_TIME
			now += spent + math.max(0.05, CatLogic.pawRest(interval, spent))
		end
		for i = 2, #starts do
			local expected = CatLogic.pawInterval(starts[i - 1]) :: number
			t.ok(math.abs(starts[i] - starts[i - 1] - expected) < 1e-9, `gap at {starts[i - 1]}`)
		end
		local late = 0
		for _, s in starts do
			if s >= 45 then
				late += 1
			end
		end
		t.ok(late >= 7, `45~60초 경고 {late}번 (2초 간격이면 7~8번)`)
	end)

	t.test(
		"m5-17 재QA B2: 꼭대기는 폭 방향 2.2 넘으면 안 맞고, 1·2단 선반 위는 폭 방향으로 항상 판정 안",
		function()
			local range = CatLogic.BALL_HIT_RANGE
			for _, shelf in CatLayout.shelves() do
				if shelf.side == "Top" then
					t.eq(CatLogic.isHitAt(0, range + 0.01), false)
					t.eq(CatLogic.isHitAt(0, -5), false)
					t.eq(CatLogic.isHitAt(0, -range), true)
				else
					-- 레이캐스트가 선반을 맞힌 사람의 폭 방향 거리는 SHELF_WIDTH/2 이하 → 전처럼 along만으로 갈려요
					t.ok(CatLayout.SHELF_WIDTH / 2 <= range, "1·2단 폭 절반 ≤ BALL_HIT_RANGE")
					for _, along in { 0, range, range + 0.01 } do
						t.eq(CatLogic.isHitAt(along, CatLayout.SHELF_WIDTH / 2), CatLogic.isHit(along))
					end
				end
			end
		end
	)
end
