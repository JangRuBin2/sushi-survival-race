--!strict
-- "온천탕 인형뽑기"(onsen-claw, m5-39) 치수 (Roblox API 없음, tests/map-onsen-claw.spec.luau).
--
-- 해 질 녘 노천탕. 탕 중심(CENTER_X, CENTER_Z) 가운데 섬(반지름 9)에 탁상 인형뽑기 기계가 있고,
-- 그 둘레에 나무 데크 고리 4단이 떠 있어요 (스펙 "무대" 표):
--   4단(가장 안, 윗면 6) 반지름 10~17 · 데크 4개
--   3단(윗면 4)          반지름 17~25 · 데크 6개
--   2단(윗면 2)          반지름 25~33 · 데크 8개
--   1단(가장 바깥, 윗면 0) 반지름 33~42 · 데크 12개
-- 데크 하나는 부채꼴이고, 상자 조각(segment) 여러 개로 근사해요. 조각 폭은 바깥 가장자리에서 이웃 조각과 딱 맞게
-- (2·outer·tan(θ/2)) 정해서 틈이 없고(Layout.seamGap = 0), 안쪽으로 갈수록 이웃과 조금(≤ 0.8) 겹쳐요.
-- 겹친 곳이 z-fighting이 안 나게 단 전체에서 번갈아(홀수 조각) SEAM_DROP만큼 낮춰요 (밟는 높이 차 0.02).
-- 단마다 조각 수가 짝수라 데크 경계·한 바퀴 이음매에서도 번갈아 이어져요.
-- 좌표는 origin 기준 로컬 (x, z). 각도는 탕 중심에서 +X를 0°로 −Z 쪽으로 커져요 (polar).
--
--   Layout.TIERS[tier]                     { inner, outer, top, count, segments, angleOffset }
--   Layout.decks() -> { Deck }              데크 30개 (1단 → 4단, 단 안에서는 Index 순)
--   Layout.deckSegments(deck) -> { Segment } 데크 하나의 상자 조각
--   Layout.spawnPoints() -> { {x, y, z, angle} }  스폰 24개 (2·3단 조각 가운데)
--   Layout.tierAt(dist) -> number?          탕 중심에서 수평 거리 → 그 자리의 단 (섬·탕 밖이면 nil)
--   Layout.seamGap(tier) -> number          같은 단 이웃 조각 사이 가장 넓은 틈 (0이면 틈 없음)
--   Layout.polar(angle, radius) -> (x, z)

export type Tier = {
	inner: number,
	outer: number,
	top: number,
	count: number, -- 데크 수
	segments: number, -- 데크 하나의 상자 조각 수
	angleOffset: number, -- 첫 데크가 시작하는 각도 (단마다 이음매가 한 줄로 안 서게)
}

export type Deck = {
	tier: number,
	index: number, -- 단 안 번호 1..count
	key: string, -- "T<tier>D<index>"
	top: number,
	inner: number,
	outer: number,
	startAngle: number,
	sweep: number,
}

export type Segment = {
	x: number,
	z: number,
	angle: number, -- 조각 가운데 각도 (도)
	depth: number, -- 반지름 방향 길이 (상자 로컬 X)
	width: number, -- 접선 방향 길이 (상자 로컬 Z)
	top: number, -- 이 조각 윗면 y (홀수 조각은 SEAM_DROP 낮음)
}

local Layout = {}

-- 탕 (origin 로컬)
Layout.CENTER_X = 0
Layout.CENTER_Z = -45
Layout.POOL_RADIUS = 52 -- 물 표면 반지름 (1단 바깥 42 + 쟁반이 지나갈 물 띠)
Layout.ISLAND_RADIUS = 9 -- 가운데 섬 (인형뽑기 몸체가 이 안)

-- 데크
Layout.DECK_THICKNESS = 1.2
Layout.SEAM_DROP = 0.02
Layout.TIERS = {
	{ inner = 33, outer = 42, top = 0, count = 12, segments = 3, angleOffset = 0 },
	{ inner = 25, outer = 33, top = 2, count = 8, segments = 5, angleOffset = 22.5 },
	{ inner = 17, outer = 25, top = 4, count = 6, segments = 6, angleOffset = 30 },
	{ inner = 10, outer = 17, top = 6, count = 4, segments = 9, angleOffset = 45 },
} :: { Tier }
Layout.TOP_TIER = 4

-- 인형뽑기 몸체 (충돌 있음, 판정). 정사각 기둥, 대각선 반이 섬 반지름 9 안 (6.3·√2 = 8.91)
Layout.BODY_HALF = 6.3
Layout.BODY_BOTTOM_Y = -10
Layout.BODY_TOP_Y = 24

-- 플레이어
Layout.FOOT_OFFSET = 3 -- HumanoidRootPart Y − 이 값 = 발 높이
Layout.JUMP_HEIGHT = 6.4 -- 기본 JumpPower 50, 중력 196.2 → 약 6.4
Layout.FALL_ELIMINATION_Y = -25 -- 안전망 (HRP 로컬 y)

-- 스폰: 3단·2단 고리 가운데 반지름에 12개씩
Layout.SPAWN_TIERS = { 3, 2 }
Layout.SPAWNS_PER_TIER = 12

local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z

local function polar(angle: number, radius: number): (number, number)
	local rad = math.rad(angle)
	return CX + radius * math.cos(rad), CZ - radius * math.sin(rad)
end
Layout.polar = polar

function Layout.deckKey(tier: number, index: number): string
	return `T{tier}D{index}`
end

function Layout.decks(): { Deck }
	local list: { Deck } = {}
	for tierIndex, tier in Layout.TIERS do
		local sweep = 360 / tier.count
		for i = 1, tier.count do
			table.insert(list, {
				tier = tierIndex,
				index = i,
				key = Layout.deckKey(tierIndex, i),
				top = tier.top,
				inner = tier.inner,
				outer = tier.outer,
				startAngle = tier.angleOffset + (i - 1) * sweep,
				sweep = sweep,
			})
		end
	end
	return list
end

-- 데크 하나의 상자 조각. 조각 폭 = 2·outer·tan(θ/2) → 바깥 가장자리에서 이웃 조각과 꼭 맞아요(틈 0).
function Layout.deckSegments(deck: Deck): { Segment }
	local tier = Layout.TIERS[deck.tier]
	local n = tier.segments
	local theta = deck.sweep / n
	local rMid = (deck.inner + deck.outer) / 2
	local depth = deck.outer - deck.inner
	local width = 2 * deck.outer * math.tan(math.rad(theta / 2))
	local list: { Segment } = {}
	for k = 1, n do
		local angle = deck.startAngle + (k - 0.5) * theta
		local x, z = polar(angle, rMid)
		table.insert(list, {
			x = x,
			z = z,
			angle = angle,
			depth = depth,
			width = width,
			top = if ((deck.index - 1) * n + k) % 2 == 0 then deck.top else deck.top - Layout.SEAM_DROP,
		})
	end
	return list
end

-- 같은 단 이웃 조각 사이 가장 넓은 틈. 이음매선(조각 가운데선에서 θ/2) 위 점은 조각 좌표로 (x, x·tan(θ/2))이고,
-- 조각 옆면은 z = width/2라서 틈(한쪽) = x·tan(θ/2) − width/2. 가장 넓은 곳은 바깥 가장자리 x = outer예요.
function Layout.seamGap(tierIndex: number): number
	local tier = Layout.TIERS[tierIndex]
	local half = math.rad(360 / tier.count / tier.segments) / 2
	local deck: Deck? = nil
	for _, d in Layout.decks() do
		if d.tier == tierIndex then
			deck = d
			break
		end
	end
	local width = Layout.deckSegments(deck :: Deck)[1].width -- 실제로 만드는 조각 폭
	return math.max(0, 2 * (tier.outer * math.tan(half) - width / 2))
end

-- 탕 중심에서 수평 거리 → 단 (경계는 안쪽 단: 17이면 4단)
function Layout.tierAt(dist: number): number?
	for tierIndex = #Layout.TIERS, 1, -1 do
		local tier = Layout.TIERS[tierIndex]
		if dist >= tier.inner and dist <= tier.outer then
			return tierIndex
		end
	end
	return nil
end

function Layout.tierTop(tierIndex: number): number
	return Layout.TIERS[tierIndex].top
end

-- 스폰 24개: 3단·2단 조각 가운데 중 고르게 12개씩 (조각 가운데라 판정 상자 안이 확실해요).
-- 1번은 탕 남쪽(+Z, 270°)에 가깝게 — 렌더러 eye 뷰와 첫 배치가 여관(북쪽)을 바라봐요.
export type SpawnPoint = { x: number, y: number, z: number, angle: number, tier: number }

function Layout.spawnPoints(): { SpawnPoint }
	local points: { SpawnPoint } = {}
	for _, tierIndex in Layout.SPAWN_TIERS do
		local segments: { Segment } = {}
		for _, deck in Layout.decks() do
			if deck.tier == tierIndex then
				for _, seg in Layout.deckSegments(deck) do
					table.insert(segments, seg)
				end
			end
		end
		-- 270°에 가장 가까운 조각부터 시작해서 같은 간격으로
		table.sort(segments, function(a: Segment, b: Segment): boolean
			return (a.angle - 270) % 360 < (b.angle - 270) % 360
		end)
		local step = #segments / Layout.SPAWNS_PER_TIER
		for k = 0, Layout.SPAWNS_PER_TIER - 1 do
			local seg = segments[math.floor(k * step + 0.5) % #segments + 1]
			table.insert(
				points,
				{ x = seg.x, y = Layout.TIERS[tierIndex].top, z = seg.z, angle = seg.angle, tier = tierIndex }
			)
		end
	end
	return points
end

return Layout
