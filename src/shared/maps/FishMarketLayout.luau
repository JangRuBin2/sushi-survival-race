--!strict
-- "수산시장"(fish-market, m5-37) 무대 치수 (Roblox API 없음).
--
-- 얼음물 수조 위 나무 됫박 상자 6 × 6 = 36개. 상자 10 × 6(높이) × 10, 윗면 y 0, 상자 사이 물길 5
-- (가장자리 사이) → 격자 전체 85 × 85. Row는 z 방향(0 = 출발 쪽 +Z, 5 = 안쪽 −Z), Col은 x 방향(0 = −X).
-- 좌표는 origin 기준 로컬 (x, z). 격자 중심은 (0, GRID_CENTER_Z) — 코스는 origin 앞쪽(로컬 −Z)이에요.
--
--   Layout.crates() -> { Crate }                 상자 36개 (row, col, key, centerX, centerZ)
--   Layout.crateKey(row, col) -> string          "R<row>C<col>"
--   Layout.colX(col) / Layout.rowZ(row)          상자 중심 x / z (row는 소수도 돼요 — 얼음 블록이 줄을 옮길 때)
--   Layout.crateAt(x, z) -> (row?, col?)         그 점이 윗면 위에 있는 상자 (물길·밖이면 nil)
--   Layout.spawnOffsets() -> { {x, z} }          스폰 24개 (가운데 4 × 4 상자, 체크무늬로 2개·1개)

export type Crate = { row: number, col: number, key: string, centerX: number, centerZ: number }

local Layout = {}

Layout.GRID = 6 -- 6 × 6
Layout.CRATE_SIZE = 10 -- 상자 윗면 한 변
Layout.CRATE_HEIGHT = 6
Layout.GAP = 5 -- 상자 사이 물길 (가장자리 사이)
Layout.PITCH = Layout.CRATE_SIZE + Layout.GAP -- 15
Layout.SPAN = Layout.GRID * Layout.CRATE_SIZE + (Layout.GRID - 1) * Layout.GAP -- 85
Layout.TOP_Y = 0 -- 상자 윗면
Layout.GRID_CENTER_X = 0
Layout.GRID_CENTER_Z = -50

Layout.WATER_Y = -4 -- 물 표면 (장식, 충돌 없음)
Layout.ELIMINATION_Y = -6 -- HumanoidRootPart 로컬 y가 이보다 낮으면 물에 빠져 탈락 (상자 바닥 높이)
Layout.SAFETY_NET_Y = -40 -- 안전망 기준 (배경 바닥은 이보다 10 이상 아래 −50 이하)
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이 (TempuraPotLayout과 같은 관례)

-- 스폰 영역 = 가운데 4 × 4 (Row·Col 1~4)
Layout.SPAWN_MIN = 1
Layout.SPAWN_MAX = 4
Layout.SPAWN_PAIR_OFFSET = 2.5 -- 2개 스폰 상자의 좌우 간격 반 (서로 5)

function Layout.crateKey(row: number, col: number): string
	return `R{row}C{col}`
end

function Layout.colX(col: number): number
	return Layout.GRID_CENTER_X + (col - (Layout.GRID - 1) / 2) * Layout.PITCH
end

-- row 0이 출발 쪽(+Z)이에요. 소수 row는 줄 사이 (얼음 블록이 옆 줄로 옮기는 중).
function Layout.rowZ(row: number): number
	return Layout.GRID_CENTER_Z + ((Layout.GRID - 1) / 2 - row) * Layout.PITCH
end

function Layout.crates(): { Crate }
	local list: { Crate } = {}
	for row = 0, Layout.GRID - 1 do
		for col = 0, Layout.GRID - 1 do
			table.insert(list, {
				row = row,
				col = col,
				key = Layout.crateKey(row, col),
				centerX = Layout.colX(col),
				centerZ = Layout.rowZ(row),
			})
		end
	end
	return list
end

-- 한 축에서 상자 index (가장자리 포함). 물길·격자 밖이면 nil.
local function axisIndex(offsetFromFirst: number): number?
	local index = math.floor(offsetFromFirst / Layout.PITCH + 0.5)
	if index < 0 or index >= Layout.GRID then
		return nil
	end
	local center = index * Layout.PITCH
	if math.abs(offsetFromFirst - center) > Layout.CRATE_SIZE / 2 then
		return nil
	end
	return index
end

-- 점 (x, z)가 어떤 상자 윗면 위에 있는지. 물길·격자 밖이면 nil.
function Layout.crateAt(x: number, z: number): (number?, number?)
	local col = axisIndex(x - Layout.colX(0))
	local row = axisIndex(Layout.rowZ(0) - z)
	if col == nil or row == nil then
		return nil, nil
	end
	return row, col
end

-- 스폰 24개: 가운데 4 × 4 상자(16개). (row + col)이 짝수인 8개는 2개(x ± 2.5), 홀수인 8개는 가운데 1개.
function Layout.spawnOffsets(): { { x: number, z: number } }
	local list: { { x: number, z: number } } = {}
	for row = Layout.SPAWN_MIN, Layout.SPAWN_MAX do
		for col = Layout.SPAWN_MIN, Layout.SPAWN_MAX do
			local x, z = Layout.colX(col), Layout.rowZ(row)
			if (row + col) % 2 == 0 then
				table.insert(list, { x = x - Layout.SPAWN_PAIR_OFFSET, z = z })
				table.insert(list, { x = x + Layout.SPAWN_PAIR_OFFSET, z = z })
			else
				table.insert(list, { x = x, z = z })
			end
		end
	end
	return list
end

return Layout
