--!strict
-- "고양이 카페 캣타워"(cat-cafe-shelves, m5-17) 코스 치수 (Roblox API 없음).
--
-- 구조: 가운데가 뚫린 사각 테두리가 3단으로 쌓인 피라미드예요. 단(tier) 1·2는 "긴 선반" 2개(바깥 한 변
-- 전체 길이, North·South)와 "짧은 선반" 2개(긴 선반 사이에 겹치지 않게 끼워 맞는 길이, East·West)로
-- 이뤄진 사각 테두리 — 4개가 액자처럼 이어져 가운데 구멍을 둘러싸요. 단 3(꼭대기)은 뚫리지 않은
-- 꽉 찬 판("캣방석") 1개예요. 좌표는 origin 기준 로컬 (x, z), 캣타워 중심은
-- (TOWER_CENTER_X, TOWER_CENTER_Z). 코스는 origin 앞쪽(로컬 -Z)에 있어요.
--
--   Layout.shelves() -> { Shelf }           선반 9개 (1단 4 + 2단 4 + 3단 1), 타워 중심 오프셋 포함
--   Layout.spawnOffsets() -> { {x,z} }      스폰 24개 (1단 선반 4개에 6개씩), 로컬 좌표
--   Layout.outerSideOf(tier) -> number      그 단의 바깥 한 변
--   Layout.topYOf(tier) -> number           그 단의 윗면 높이
--
-- CatCafeShelvesLogic이 이 표를 읽어서 공 왕복·고양이 발·오르는 틈(climbGap)을 계산해요.

export type Shelf = {
	key: string,
	tier: number,
	side: string, -- "North" | "South" | "East" | "West" | "Top"
	axis: "X" | "Z", -- 공이 왕복하는 긴 쪽 방향
	length: number,
	width: number,
	topY: number,
	centerX: number,
	centerZ: number,
}

local Layout = {}

Layout.TOWER_CENTER_X = 0
Layout.TOWER_CENTER_Z = -40
Layout.SHELF_WIDTH = 4 -- 1·2단 선반(테두리) 폭

-- 단 치수. 3단은 뚫리지 않은 꽉 찬 판이라 바깥 한 변이 곧 판 크기예요.
Layout.TIER1_OUTER = 44
Layout.TIER1_TOP_Y = 4
Layout.TIER2_OUTER = 28
Layout.TIER2_TOP_Y = 9
Layout.TIER3_OUTER = 12
Layout.TIER3_TOP_Y = 14

-- origin 기준 로컬 y. 이 아래로 떨어지면 탈락 (1단 topY − 15).
Layout.ELIMINATION_Y = Layout.TIER1_TOP_Y - 15

-- 스폰: 1단 선반(길이 방향) 양 끝 여백과 선반 하나당 개수.
Layout.SPAWN_COLUMNS = 6 -- 선반 4개 × 6개 = 24
Layout.SPAWN_EDGE_MARGIN = 4

function Layout.outerSideOf(tier: number): number
	if tier == 1 then
		return Layout.TIER1_OUTER
	elseif tier == 2 then
		return Layout.TIER2_OUTER
	end
	return Layout.TIER3_OUTER
end

function Layout.topYOf(tier: number): number
	if tier == 1 then
		return Layout.TIER1_TOP_Y
	elseif tier == 2 then
		return Layout.TIER2_TOP_Y
	end
	return Layout.TIER3_TOP_Y
end

-- 단(1 또는 2)의 선반 4개. 긴 선반(North·South, 바깥 한 변 전체 길이) 2개 + 짧은 선반
-- (East·West, 긴 선반 사이에 끼워 맞는 길이 = 바깥 한 변 − 폭×2) 2개. 겹치지 않고 사각 테두리를
-- 이뤄서 가운데 구멍(바깥 한 변 − 폭×2)을 둘러싸요.
local function ringShelves(tier: number): { Shelf }
	local outer = Layout.outerSideOf(tier)
	local width = Layout.SHELF_WIDTH
	local topY = Layout.topYOf(tier)
	local longLength = outer
	local shortLength = outer - 2 * width
	local edge = outer / 2 - width / 2 -- 선반 중심의 타워 중심 기준 바깥쪽 오프셋
	local cx, cz = Layout.TOWER_CENTER_X, Layout.TOWER_CENTER_Z
	return {
		{
			key = `Tier{tier}North`,
			tier = tier,
			side = "North",
			axis = "X" :: "X",
			length = longLength,
			width = width,
			topY = topY,
			centerX = cx,
			centerZ = cz + edge,
		},
		{
			key = `Tier{tier}South`,
			tier = tier,
			side = "South",
			axis = "X" :: "X",
			length = longLength,
			width = width,
			topY = topY,
			centerX = cx,
			centerZ = cz - edge,
		},
		{
			key = `Tier{tier}East`,
			tier = tier,
			side = "East",
			axis = "Z" :: "Z",
			length = shortLength,
			width = width,
			topY = topY,
			centerX = cx + edge,
			centerZ = cz,
		},
		{
			key = `Tier{tier}West`,
			tier = tier,
			side = "West",
			axis = "Z" :: "Z",
			length = shortLength,
			width = width,
			topY = topY,
			centerX = cx - edge,
			centerZ = cz,
		},
	}
end

-- 3단: 뚫리지 않은 꽉 찬 판("캣방석"). 길이·폭 모두 바깥 한 변.
local function topShelf(): Shelf
	local outer = Layout.outerSideOf(3)
	return {
		key = "Top",
		tier = 3,
		side = "Top",
		axis = "X" :: "X", -- 공이 왕복할 축 (정사각형이라 어느 쪽이든 동치)
		length = outer,
		width = outer,
		topY = Layout.topYOf(3),
		centerX = Layout.TOWER_CENTER_X,
		centerZ = Layout.TOWER_CENTER_Z,
	}
end

-- 선반 9개: 1단 4개 + 2단 4개 + 3단(Top) 1개.
function Layout.shelves(): { Shelf }
	local list: { Shelf } = {}
	for _, shelf in ringShelves(1) do
		table.insert(list, shelf)
	end
	for _, shelf in ringShelves(2) do
		table.insert(list, shelf)
	end
	table.insert(list, topShelf())
	return list
end

-- 스폰 24개: 1단 선반 4개 각각의 길이 방향으로 양 끝 여백 SPAWN_EDGE_MARGIN을 두고 고르게.
function Layout.spawnOffsets(): { { x: number, z: number } }
	local list: { { x: number, z: number } } = {}
	for _, shelf in ringShelves(1) do
		local count = Layout.SPAWN_COLUMNS
		local usable = shelf.length - 2 * Layout.SPAWN_EDGE_MARGIN
		for i = 0, count - 1 do
			local along = if count > 1 then -usable / 2 + (i / (count - 1)) * usable else 0
			local x: number, z: number
			if shelf.axis == "X" then
				x, z = shelf.centerX + along, shelf.centerZ
			else
				x, z = shelf.centerX, shelf.centerZ + along
			end
			table.insert(list, { x = x, z = z })
		end
	end
	return list
end

return Layout
