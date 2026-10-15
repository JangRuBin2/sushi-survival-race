--!strict
-- "튀김 냄비 탈출"(tempura-pot, m5-05) 치수 (Roblox API 없음, tests/map-tempura-pot.spec.luau).
--
-- 거대한 튀김 냄비 안. 가운데 출발 판(튀김 바구니, 반지름 20, 윗면 y 3)이 있고, 그 둘레 고리
-- (반지름 20~36)에 튀김 발판이 7층(윗면 7·11·15·19·23·27·31)으로 나선을 그리며 올라가요.
--   · 7·15층은 안쪽 줄(중심 반지름 24.5, 고구마 원판·깻잎 판), 11·19층은 바깥 줄(반지름 32, 새우튀김을
--     원 둘레 방향으로 눕힘) — 바로 위층과는 위에서 볼 때 겹치지 않아 머리가 안 닿고, 수평 틈 1~2라 점프로
--     한 층씩 올라가요. 층마다 각도를 60°씩 돌려서 두 층 위(8 위)와도 겹치지 않게 했어요.
--   · 23·27·31층(60초까지 기름이 닿지 않는 안전 구역)은 안쪽으로 감겨 들어와 바구니 위로 가요.
-- 좌표는 origin 기준 로컬 (x, z). 냄비 중심은 (POT_CENTER_X, POT_CENTER_Z) — 코스는 origin 앞쪽(로컬 -Z).
-- 발판 모양: "Disc"(원판, radius) 또는 "Rect"(직사각형, length = 로컬 X·width = 로컬 Z, yaw도만큼 Y축 회전).
-- yaw 규칙은 CFrame.Angles(0, rad(yaw), 0)과 같아요: 로컬 X축이 (cos yaw, 0, -sin yaw)로 가요.
--
--   Layout.rafts() -> { Raft }               튀김 발판 전부 (층 순서, 같은 층은 각도 순)
--   Layout.basket() -> Raft                   출발 바구니 (Disc, tier 0)
--   Layout.spawnOffsets() -> { {x,z} }        스폰 24개 (바구니 위)
--   Layout.TIER_TOPS                          층 윗면 높이 7개

export type Shape = "Disc" | "Rect"
export type Kind = "Basket" | "Shrimp" | "SweetPotato" | "Shiso"

export type Raft = {
	key: string,
	tier: number, -- 0 = 바구니, 1~7 = TIER_TOPS 순서
	topY: number,
	kind: Kind,
	shape: Shape,
	x: number,
	z: number,
	radius: number, -- Disc만
	length: number, -- Rect: yaw 전 로컬 X 길이
	width: number, -- Rect: yaw 전 로컬 Z 길이
	yaw: number, -- 도
}

local Layout = {}

-- 냄비
Layout.POT_CENTER_X = 0
Layout.POT_CENTER_Z = -40
Layout.POT_INNER_RADIUS = 36
Layout.POT_FLOOR_Y = -10
Layout.POT_WALL_TOP_Y = 40
Layout.POT_WALL_THICKNESS = 2
Layout.POT_WALL_SEGMENTS = 32

-- 출발 바구니
Layout.BASKET_RADIUS = 20
Layout.BASKET_TOP_Y = 3

-- 발판 공통
Layout.RAFT_THICKNESS = 1.6
Layout.TIER_TOPS = { 7, 11, 15, 19, 23, 27, 31 }
Layout.INNER_RING_RADIUS = 24.5 -- 7·15층 발판 중심
Layout.OUTER_RING_RADIUS = 32 -- 11·19층 발판 중심
Layout.TIER_ROTATION = 60 -- 층마다 나선이 도는 각도(도)

-- 모양 치수 (스펙 표)
Layout.SHRIMP_LENGTH = 12
Layout.SHRIMP_WIDTH = 5
Layout.SWEET_POTATO_DIAMETER = 8
Layout.SHISO_LENGTH = 10
Layout.SHISO_WIDTH = 8

-- 안전 구역 (위 세 층)
Layout.SAFE_TIERS = { 5, 6, 7 } -- TIER_TOPS 인덱스 (23·27·31) — 60초까지 안전. m5-40 서든데스에 23층은 약 63.5초에 잠겨요
Layout.TIER5_DIAMETER = 7
Layout.TIER6_DIAMETER = 6
Layout.TOP_DIAMETER = 5

-- 탈락
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이
Layout.FALL_ELIMINATION_Y = -15 -- 냄비 바닥 밑 안전망

-- 스폰
Layout.SPAWN_RING_RADII = { 6, 11, 16 } -- 바구니 위 동심원 3줄
Layout.SPAWN_RING_COUNTS = { 4, 8, 12 } -- 합 24

local CX, CZ = Layout.POT_CENTER_X, Layout.POT_CENTER_Z

-- 냄비 중심 기준 각도(도, +X에서 -Z 쪽으로)·반지름 → origin 로컬 (x, z)
local function polar(angle: number, radius: number): (number, number)
	local rad = math.rad(angle)
	return CX + radius * math.cos(rad), CZ - radius * math.sin(rad)
end
Layout.polar = polar

local function disc(key: string, tier: number, kind: Kind, angle: number, ringRadius: number, diameter: number): Raft
	local x, z = polar(angle, ringRadius)
	return {
		key = key,
		tier = tier,
		topY = Layout.TIER_TOPS[tier],
		kind = kind,
		shape = "Disc",
		x = x,
		z = z,
		radius = diameter / 2,
		length = diameter,
		width = diameter,
		yaw = 0,
	}
end

-- 원 둘레 방향으로 눕힌 직사각형: 로컬 X(length)가 접선, 로컬 Z(width)가 반지름 방향이에요.
-- 각도 angle의 반지름 방향이 (cos, -sin)이라 접선은 yaw = angle + 90.
local function tangentRect(
	key: string,
	tier: number,
	kind: Kind,
	angle: number,
	ringRadius: number,
	length: number,
	width: number
): Raft
	local x, z = polar(angle, ringRadius)
	return {
		key = key,
		tier = tier,
		topY = Layout.TIER_TOPS[tier],
		kind = kind,
		shape = "Rect",
		x = x,
		z = z,
		radius = 0,
		length = length,
		width = width,
		yaw = angle + 90,
	}
end

-- 안쪽 줄(7·15층): 고구마(원판 8)와 깻잎(10 × 8, 8이 반지름 방향)을 번갈아 5개 / 4개, 28° 간격.
local INNER_ANGLES_5 = { -56, -28, 0, 28, 56 }
local INNER_ANGLES_4 = { -42, -14, 14, 42 }
-- 바깥 줄(11·19층): 새우튀김(12 × 5, 접선 방향) 4개, 28° 간격.
local OUTER_ANGLES_4 = { -42, -14, 14, 42 }

local function innerTier(list: { Raft }, tier: number, center: number, angles: { number })
	for i, offset in angles do
		local key = `T{tier}_{i}`
		if i % 2 == 1 then
			table.insert(
				list,
				disc(key, tier, "SweetPotato", center + offset, Layout.INNER_RING_RADIUS, Layout.SWEET_POTATO_DIAMETER)
			)
		else
			table.insert(
				list,
				tangentRect(
					key,
					tier,
					"Shiso",
					center + offset,
					Layout.INNER_RING_RADIUS,
					Layout.SHISO_LENGTH,
					Layout.SHISO_WIDTH
				)
			)
		end
	end
end

local function outerTier(list: { Raft }, tier: number, center: number)
	for i, offset in OUTER_ANGLES_4 do
		table.insert(
			list,
			tangentRect(
				`T{tier}_{i}`,
				tier,
				"Shrimp",
				center + offset,
				Layout.OUTER_RING_RADIUS,
				Layout.SHRIMP_LENGTH,
				Layout.SHRIMP_WIDTH
			)
		)
	end
end

-- 안전 구역 세 층: 나선이 안쪽으로 감겨 들어와요 (각도·반지름은 경로 테스트로 확인한 값)
Layout.TIER5_ANGLES = { 200, 230 }
Layout.TIER5_RING_RADIUS = 24.5
Layout.TIER6_ANGLES = { 222, 252 }
Layout.TIER6_RING_RADIUS = 16.5
Layout.TOP_ANGLE = 240
Layout.TOP_RING_RADIUS = 10

function Layout.rafts(): { Raft }
	local list: { Raft } = {}
	local rot = Layout.TIER_ROTATION
	innerTier(list, 1, 0, INNER_ANGLES_5) -- 7층: 5개
	outerTier(list, 2, rot) -- 11층: 4개
	innerTier(list, 3, rot * 2, INNER_ANGLES_4) -- 15층: 4개
	outerTier(list, 4, rot * 3) -- 19층: 4개
	for i, angle in Layout.TIER5_ANGLES do
		table.insert(list, disc(`T5_{i}`, 5, "SweetPotato", angle, Layout.TIER5_RING_RADIUS, Layout.TIER5_DIAMETER))
	end
	for i, angle in Layout.TIER6_ANGLES do
		table.insert(list, disc(`T6_{i}`, 6, "SweetPotato", angle, Layout.TIER6_RING_RADIUS, Layout.TIER6_DIAMETER))
	end
	table.insert(list, disc("Top", 7, "SweetPotato", Layout.TOP_ANGLE, Layout.TOP_RING_RADIUS, Layout.TOP_DIAMETER))
	return list
end

function Layout.basket(): Raft
	return {
		key = "Basket",
		tier = 0,
		topY = Layout.BASKET_TOP_Y,
		kind = "Basket",
		shape = "Disc",
		x = CX,
		z = CZ,
		radius = Layout.BASKET_RADIUS,
		length = Layout.BASKET_RADIUS * 2,
		width = Layout.BASKET_RADIUS * 2,
		yaw = 0,
	}
end

-- 스폰 24개: 바구니 위 동심원 3줄 (반지름 6·11·16에 4·8·12개)
function Layout.spawnOffsets(): { { x: number, z: number } }
	local list: { { x: number, z: number } } = {}
	for ring, radius in Layout.SPAWN_RING_RADII do
		local count = Layout.SPAWN_RING_COUNTS[ring]
		for i = 0, count - 1 do
			local angle = (i / count) * 360 + ring * 15
			local x, z = polar(angle, radius)
			table.insert(list, { x = x, z = z })
		end
	end
	return list
end

return Layout
