--!strict
-- "연회상 쟁반 쓸기"(banquet-sweep, m6-07) 치수·튜닝 값 (Roblox API 없음).
-- 대형 Survival(m6-02): 스폰 40, 12~40명, 75초(60초부터 서든데스). 좌표는 origin 기준 — 상 가운데가 (0, 0, 0).
--
-- 96 × 96 다다미 상(12짜리 타일 8 × 8). 상 가장자리에서 **쟁반 벽**이 변 전체를 덮고 반대편까지 밀고 지나가요.
-- 벽은 12짜리 칸(레인) 8개로 나뉘고, 낮은 벽(높이 3)은 점프로 넘고, 높은 벽(높이 14)은 빈 칸(1~2개)으로 피해요.
-- 벽이 오기 1.5초 전 그 변에 예고 줄(벽 칸 노랑 · 빈 칸 초록). 벽에 닿으면 벽 진행 방향으로 밀려 넘어져요(MoveExempt) —
-- 벽은 상 밖까지 가니 빈 칸으로 못 피하면 결국 밀려 떨어져요. 벽 파츠는 충돌 없음(서버 판정).
--
-- 진행: 4초부터 낮은 벽 1장씩 → 15초 높은 벽 섞임 → 30초 두 장(서로 수직) → 45초 바깥 한 줄(12) 무너져 72 × 72,
--       간격 4.5초 → 60초 서든데스(4초마다 두 장, 높은 벽 빈 칸 1개).

export type Point = { x: number, z: number }

local Layout = {}

Layout.CAPACITY = 40
Layout.MIN_PLAYERS = 12
Layout.TIME_LIMIT = 75
Layout.SUDDEN_DEATH_AT = 60

Layout.FLOOR_Y = 0
Layout.FLOOR_THICKNESS = 2
Layout.FALL_MARGIN = 12
Layout.FOOT_OFFSET = 3

Layout.TILE = 12
Layout.LANES = 8 -- 한 변의 타일·벽 칸 수
Layout.HALF = 48 -- 상 반 폭 (96)
Layout.INNER_HALF = 36 -- 무너진 뒤 (72)
Layout.COLLAPSE_AT = 45
Layout.COLLAPSE_WARN = 1.5

-- 벽
Layout.WALL_START = Layout.HALF + 4 -- 상 가장자리보다 4 바깥에서 출발, 반대편 바깥 4까지
Layout.WALL_THICKNESS = 2
Layout.WARN = 1.5 -- 예고 줄
export type KindSpec = { height: number, speed: number }
Layout.KINDS = {
	Low = { height = 3, speed = 16 },
	High = { height = 14, speed = 10 },
} :: { [string]: KindSpec }
Layout.HIT_PAD = 1.5 -- 벽 두께 반 + 이만큼 안이면 닿음
Layout.KNOCK = 26
Layout.KNOCK_UP = 10
Layout.KNOCK_EXEMPT = 0.8
Layout.KNOCK_DOWN = 0.4
Layout.KNOCK_COOLDOWN = 0.5
Layout.SIDES = { "XNeg", "XPos", "ZNeg", "ZPos" } -- 예고 줄 변 (벽이 오는 쪽)
Layout.POOL = 6 -- 동시에 움직이는 벽 자리 (× 8칸 = 48 파츠 ≤ 60)

-- 일정 (구간마다 시작 시각·간격·벽 수)
Layout.FIRST_AT = 4
Layout.PHASES = {
	{ from = 0, interval = 5, walls = 1, highChance = 0, gaps = 2 },
	{ from = 15, interval = 5, walls = 1, highChance = 0.5, gaps = 2 },
	{ from = 30, interval = 5, walls = 2, highChance = 0.5, gaps = 2 },
	{ from = 45, interval = 4.5, walls = 2, highChance = 0.5, gaps = 2 },
	{ from = 60, interval = 4, walls = 2, highChance = 0.5, gaps = 1 },
}
Layout.LAST_AT = 72 -- 이 뒤로는 새 벽 없음

-- 스폰 40: 8 × 5 격자, 간격 8 (안쪽 72 안)
function Layout.spawnPositions(): { Point }
	local list: { Point } = {}
	for row = 0, 4 do
		for col = 0, 7 do
			table.insert(list, { x = -28 + col * 8, z = -16 + row * 8 })
		end
	end
	return list
end

-- 칸 j(1..8)의 가운데 좌표 (벽에 수직인 축)
function Layout.laneCenter(j: number): number
	return -Layout.HALF + Layout.TILE * (j - 0.5)
end

return Layout
