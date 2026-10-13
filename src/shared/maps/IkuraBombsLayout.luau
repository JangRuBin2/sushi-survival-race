--!strict
-- "연어알 폭탄 접시"(m5-04) 무대 모양 순수 데이터. Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 좌표 약속: 접시 중심 = origin, 칸 윗면 = origin 높이(로컬 y 0). 각도 θ = atan2(-z, x)(도, 0~360) —
-- CFrame.Angles(0, θ, 0)이 로컬 X축을 (cos θ, 0, -sin θ)로 돌리는 것과 같아요 (꼬치 쇼다운과 같은 약속).
--
-- 칸 17개 (TileId 0~16):
--   Ring 0  가운데 원판   반지름 0~8    1칸            TileId 0
--   Ring 1  가운데 고리   반지름 8~16   6칸 (60도씩)   TileId 1~6   (Index 0~5)
--   Ring 2  바깥 고리     반지름 16~24  10칸 (36도씩)  TileId 7~16  (Index 0~9)
-- 판정 파츠: 원판은 원기둥 1개, 고리는 6도 조각마다 직사각형 1개(조각 이등분선 위, 폭 = 바깥 현,
-- 깊이 = (rOut − rIn)·cos 3°). 고리 경계가 같은 현 위에 있어서 고리 사이 틈은 0이에요.
--   Layout.slices(ring) -> { Slice }     조각 목록 (원판은 빈 목록)
--   Layout.tiles() -> { TileDef }        칸 17개 (id 순서)
--   Layout.spawns() -> { Spawn }         스폰 24개 (origin 기준 로컬, 이름순)

local Layout = {}

Layout.ID = "ikura-bombs"
Layout.RADIUS = 24 -- 접시(칸) 반지름
Layout.RING_EDGES = { 0, 8, 16, 24 } -- Ring r은 RING_EDGES[r+1] ~ RING_EDGES[r+2]
Layout.RING_TILES = { [0] = 1, [1] = 6, [2] = 10 } -- 고리마다 칸 수
Layout.SLICE_DEG = 6 -- 판정 조각 각도 (60·36 둘 다 나눠떨어져요)
Layout.THICKNESS = 1.5 -- 칸 두께 (윗면 y 0)
Layout.FALL_DEPTH = 30 -- 칸 윗면보다 이만큼 아래로 떨어지면 탈락
Layout.SPOON_HEIGHT = 28 -- 셰프 숟가락·손 높이 (장식, 충돌 없음)
Layout.SPAWN_RADII = { 13, 19 } -- 스폰 두 줄 (12개씩)
Layout.SPAWN_PER_RING = 12

export type TileDef = { id: number, ring: number, index: number, fromDeg: number, toDeg: number }
export type Slice = { tileId: number, angleDeg: number, distance: number, width: number, depth: number }
export type Spawn = { x: number, y: number, z: number }

function Layout.ringInner(ring: number): number
	return Layout.RING_EDGES[ring + 1]
end

function Layout.ringOuter(ring: number): number
	return Layout.RING_EDGES[ring + 2]
end

-- 칸 하나가 차지하는 각도 (원판은 360)
function Layout.tileArc(ring: number): number
	return 360 / Layout.RING_TILES[ring]
end

-- (ring, index) → TileId. 범위 밖이면 nil
function Layout.tileId(ring: number, index: number): number?
	local count = Layout.RING_TILES[ring]
	if count == nil or index < 0 or index >= count or index ~= math.floor(index) then
		return nil
	end
	if ring == 0 then
		return 0
	elseif ring == 1 then
		return 1 + index
	end
	return 1 + Layout.RING_TILES[1] + index
end

local tileList: { TileDef } = {}
for ring = 0, 2 do
	local arc = Layout.tileArc(ring)
	for index = 0, Layout.RING_TILES[ring] - 1 do
		table.insert(tileList, {
			id = Layout.tileId(ring, index) :: number,
			ring = ring,
			index = index,
			fromDeg = index * arc,
			toDeg = (index + 1) * arc,
		})
	end
end
Layout.TILE_COUNT = #tileList -- 17

-- 칸 17개 (id 0~16 순서). 돌려받은 표를 고치지 마세요.
function Layout.tiles(): { TileDef }
	return tileList
end

function Layout.tile(id: number): TileDef?
	return tileList[id + 1]
end

-- 고리(1·2)의 판정 조각. 조각 k는 [6k, 6k+6]도, 이등분선 위 직사각형(로컬 X = 반지름 방향).
function Layout.slices(ring: number): { Slice }
	local list: { Slice } = {}
	if ring == 0 then
		return list
	end
	local rIn, rOut = Layout.ringInner(ring), Layout.ringOuter(ring)
	local half = math.rad(Layout.SLICE_DEG / 2)
	local width = 2 * rOut * math.sin(half)
	local inner = rIn * math.cos(half)
	local outer = rOut * math.cos(half)
	local perTile = Layout.tileArc(ring) / Layout.SLICE_DEG
	for k = 0, 360 / Layout.SLICE_DEG - 1 do
		local index = k // perTile
		table.insert(list, {
			tileId = Layout.tileId(ring, index) :: number,
			angleDeg = k * Layout.SLICE_DEG + Layout.SLICE_DEG / 2,
			distance = (inner + outer) / 2,
			width = width,
			depth = outer - inner,
		})
	end
	return list
end

-- 각도 → 로컬 (x, z) (θ = atan2(-z, x))
function Layout.polar(radius: number, angleDeg: number): (number, number)
	local a = math.rad(angleDeg)
	return radius * math.cos(a), -radius * math.sin(a)
end

-- 스폰 24개: 반지름 13에 30도 간격 12개, 반지름 19에 15도 어긋나게 12개. 앞 번호부터 두 줄을 번갈아
-- 접시 둘레에 흩어지게 (각도 순서 = 5씩 건너뛰기, 12와 서로소) 섞어요. 혼자·둘이 해도 한쪽에 몰리지 않게.
function Layout.spawns(): { Spawn }
	local list: { Spawn } = {}
	for n = 0, Layout.SPAWN_PER_RING - 1 do
		local slot = (n * 5) % Layout.SPAWN_PER_RING
		for ringIndex, radius in Layout.SPAWN_RADII do
			local angle = slot * 30 + (ringIndex - 1) * 15 + if ringIndex == 2 then 90 else 0
			local x, z = Layout.polar(radius, angle)
			table.insert(list, { x = x, y = 0.1, z = z })
		end
	end
	return list
end

return Layout
