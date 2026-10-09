--!strict
-- "와르르 나무 블록"(giant-jenga, m5-16) 격자 치수. Roblox API를 쓰지 않아요 (tests/map-giant-jenga.spec.luau).
-- 좌표는 탑 중심(origin) 기준 로컬 (x, z), 탑 꼭대기(블록이 전부 있을 때) = y 0. 격자 칸 (i, j)의 중심은
-- (i·CELL_SIZE, j·CELL_SIZE), i·j는 -2~2 (5×5 = 25칸). 동적 상태·계산(제거 일정·기울기)은 GiantJengaLogic에.
--   Layout.columns()              칸 25개 (i, j, x, z, key)
--   Layout.isProtected(i, j)      가운데 3×3 (|i| ≤ 1, |j| ≤ 1) — 절대 안 뽑히고 안 기울어요
--   Layout.spawnOffsets()         스폰 24곳 ((0,0) 제외한 나머지 칸)
--   Layout.neighborsOf(i, j)      그 칸의 4방향 중 격자 안에 실제로 있는 이웃 좌표들
--   Layout.key(i, j)              보드 상태 테이블의 키 문자열

export type Column = { i: number, j: number, x: number, z: number, key: string }
export type Offset = { x: number, z: number }
export type Neighbor = { i: number, j: number }

local Layout = {}

Layout.GRID_HALF = 2 -- 칸 번호 -2~2 (5×5)
Layout.PROTECTED_HALF = 1 -- |i|, |j| ≤ 1 은 보호 (가운데 3×3)
Layout.CELL_SIZE = 10
Layout.LEVEL_MAX = 3 -- 기둥 한 칸 = 나무 블록 3단
Layout.LEVEL_DROP = 4 -- 한 단 뽑힐 때마다 윗면이 이만큼 가라앉아요
Layout.FALL_DEPTH = 30 -- origin 기준 이만큼 아래로 떨어지면 탈락

local function key(i: number, j: number): string
	return `{i},{j}`
end
Layout.key = key

function Layout.isProtected(i: number, j: number): boolean
	local h = Layout.PROTECTED_HALF
	return math.abs(i) <= h and math.abs(j) <= h
end

local function inGrid(i: number, j: number): boolean
	local g = Layout.GRID_HALF
	return i >= -g and i <= g and j >= -g and j <= g
end
Layout.inGrid = inGrid

function Layout.columns(): { Column }
	local list: { Column } = {}
	local g = Layout.GRID_HALF
	local size = Layout.CELL_SIZE
	for j = -g, g do
		for i = -g, g do
			table.insert(list, { i = i, j = j, x = i * size, z = j * size, key = key(i, j) })
		end
	end
	return list
end

-- 25칸 중 정중앙 (0,0)을 뺀 24곳
function Layout.spawnOffsets(): { Offset }
	local list: { Offset } = {}
	local g = Layout.GRID_HALF
	local size = Layout.CELL_SIZE
	for j = -g, g do
		for i = -g, g do
			if not (i == 0 and j == 0) then
				table.insert(list, { x = i * size, z = j * size })
			end
		end
	end
	return list
end

-- (i, j)의 4방향 이웃 중 격자 안에 실제로 있는 것만 (모서리 칸은 2개, 변 칸은 3개, 안쪽은 4개)
function Layout.neighborsOf(i: number, j: number): { Neighbor }
	local list: { Neighbor } = {}
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ni, nj = i + d[1], j + d[2]
		if inGrid(ni, nj) then
			table.insert(list, { i = ni, j = nj })
		end
	end
	return list
end

return Layout
