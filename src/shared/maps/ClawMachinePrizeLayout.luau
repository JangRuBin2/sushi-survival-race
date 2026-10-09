--!strict
-- "인형뽑기 기계 속"(m5-19) 격자 좌표 순수 로직. Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 좌표 약속: 격자 중심(가로 세로 48)이 origin 기준 로컬 (0, 0, CENTER_Z)에 있어요. Row는 로컬 -Z→+Z,
-- Col은 로컬 -X→+X 방향으로 0~7. 칸 윗면은 origin 높이에서 tileHeight(row, col)(-1.5~+1.5)만큼 떠요
-- (인형 더미 느낌 — 판정에는 안 쓰고 시각 정보일 뿐이라 떨어진 칸이 돌아와도 섞이지 않아요).
--   ClawMachinePrizeLayout.tileIndex(row, col) -> number?   격자 밖(0~7 밖)이면 nil, 안이면 0~63 고유 번호
--   ClawMachinePrizeLayout.tileHeight(row, col) -> number   고정 의사난수 오프셋(-1.5~1.5), 시드는 row·col
--   ClawMachinePrizeLayout.tileLocalX(col) / tileLocalZGrid(row) -> number   격자 중심 기준 로컬 오프셋
--   ClawMachinePrizeLayout.colOf(localXFromGridCenter) / rowOf(localZFromGridCenter) -> number
--     tileLocalX·tileLocalZGrid의 역함수(그 좌표가 속한 칸의 col·row). 격자 밖 좌표를 넣으면 0~7 밖의 값도 나와요.
--   ClawMachinePrizeLayout.spawnTiles() -> { { row, col, x, y, z } }   스폰 24개(origin 기준 로컬 좌표)

local Layout = {}

Layout.GRID_SIZE = 8 -- 8 x 8 = 64칸
Layout.TILE_SIZE = 6 -- 칸 한 변 (studs), 틈 0
Layout.BOX_SIZE = Layout.GRID_SIZE * Layout.TILE_SIZE -- 48
Layout.THICKNESS = 2 -- 칸 두께
Layout.CENTER_Z = -40 -- 격자 중심의 origin 기준 로컬 Z (origin 앞쪽)
Layout.FALL_DEPTH = 25 -- origin 기준 이만큼 아래로 떨어지면 탈락
Layout.HEIGHT_RANGE = 1.5 -- tileHeight가 ±이 범위 안에서 움직여요

-- 격자 칸(row, col)의 고유 번호(0~63). 격자 밖(row·col이 0~7을 벗어남)이면 nil.
function Layout.tileIndex(row: number, col: number): number?
	if row < 0 or row > Layout.GRID_SIZE - 1 or col < 0 or col > Layout.GRID_SIZE - 1 then
		return nil
	end
	if row ~= math.floor(row) or col ~= math.floor(col) then
		return nil
	end
	return row * Layout.GRID_SIZE + col
end

-- 0~1 사이 고정 의사난수 (정수 n에서 결정론적으로). Roblox API 없이 순수 수학만 써요.
local function hashFrac(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

-- 칸마다 다른 높이(인형 더미 느낌). 같은 (row, col)이면 매 라운드 항상 같은 값(재현 가능).
function Layout.tileHeight(row: number, col: number): number
	local n = row * Layout.GRID_SIZE + col
	return (hashFrac(n) - 0.5) * 2 * Layout.HEIGHT_RANGE
end

-- 격자 중심 기준 로컬 X(col) · Z(row) 오프셋. CENTER_Z는 더하지 않아요(순수 격자 좌표).
function Layout.tileLocalX(col: number): number
	return (col - (Layout.GRID_SIZE - 1) / 2) * Layout.TILE_SIZE
end

function Layout.tileLocalZGrid(row: number): number
	return (row - (Layout.GRID_SIZE - 1) / 2) * Layout.TILE_SIZE
end

-- tileLocalX의 역함수: 그 로컬 X가 속한 칸의 col (격자 밖 좌표를 넣으면 0~7 밖 정수도 나와요)
function Layout.colOf(localX: number): number
	return math.floor(localX / Layout.TILE_SIZE + Layout.GRID_SIZE / 2)
end

-- tileLocalZGrid의 역함수: 그 로컬 Z(격자 중심 기준, CENTER_Z 뺀 값)가 속한 칸의 row
function Layout.rowOf(localZGrid: number): number
	return math.floor(localZGrid / Layout.TILE_SIZE + Layout.GRID_SIZE / 2)
end

-- 스폰 서브 그리드: 가운데 4x4(Row·Col 2~5) 칸 영역 안에 6열 x 4행 = 24개, 서로 3 studs 이상.
local SPAWN_X = { -10, -6, -2, 2, 6, 10 }
local SPAWN_ZGRID = { -9, -3, 3, 9 }

export type SpawnTile = { row: number, col: number, x: number, y: number, z: number }

-- 스폰 24개(origin 기준 로컬 좌표, y는 그 칸 윗면 + 0.1 여유). 이름순(Spawn01, …)으로 쓰려고 row 우선 정렬.
function Layout.spawnTiles(): { SpawnTile }
	local list: { SpawnTile } = {}
	for _, zGrid in SPAWN_ZGRID do
		local row = Layout.rowOf(zGrid)
		for _, x in SPAWN_X do
			local col = Layout.colOf(x)
			local y = Layout.tileHeight(row, col) + 0.1
			table.insert(list, { row = row, col = col, x = x, y = y, z = Layout.CENTER_Z + zGrid })
		end
	end
	return list
end

return Layout
