--!strict
-- "온천탕 인형뽑기"(onsen-claw, m5-39) 순수 로직 (Roblox API 없음, tests/map-onsen-claw.spec.luau).
-- 시각 t는 전부 "결승 출발 기준 초"예요. 수치는 스펙 기본값 — 재미 확인(AC16) 뒤 이 상수만 고쳐요.
--
-- 온천수
--   Logic.waterHeight(t) -> number          판정 물 높이: −3 + floor(t/10), 4.5에서 멈춤
--   Logic.waterVisual(t) -> number          보이는 물 높이: 다음 칸 1초 전부터 부드럽게 올라 그 칸 시각에 판정과 같아요
--                                           (보이는 물 ≥ 판정 물 — 안 보이는 물에 빠지는 일이 없게)
--   Logic.isSoaked(footY, waterY) -> boolean 발이 물 − 0.5보다 낮으면 "목욕 끝"
--   Logic.sinkAt(tier) -> number?           그 단 데크가 가라앉는 시각 (물이 윗면 − 1 이상), 4단은 nil
--   Logic.deckState(tier, t) -> "Solid" | "Warn" | "Sunk"
-- 인형뽑기 충격파
--   Logic.nextSlam(prevAt?, overtimeAt?) -> Slam      다음 "쿵" (시각, 고리 수)
--   Logic.slamTimes(overtimeAt?, untilT?) -> { Slam } 처음부터 untilT(기본 190 = 안전 상한 150 + 40)까지
--   Logic.ringRadius(slamAt, t) -> number   고리 앞면 반지름 (쿵 전에는 시작 반지름 9)
--   Logic.waveHit(dist, prevRadius, radius, footY, deckTop) -> boolean
--   Logic.waveKnockback(dist, tier) -> Knock          바깥 수평·위 속도 (4단 ×1.3)
--   Logic.outward(dx, dz) -> (ux, uz)                 탕 중심 → 사람 수평 단위 벡터 (가운데면 +X)
-- 연장전
--   Logic.overtimeSinkOrder(remaining, collapseDuration) -> { SinkStep }

local Layout = require(script.Parent.OnsenClawLayout)

export type DeckState = "Solid" | "Warn" | "Sunk"
export type Slam = { at: number, rings: number }
export type Knock = { horizontal: number, up: number }
export type DeckRef = { tier: number, index: number }
export type SinkStep = { tier: number, index: number, warnAt: number, dropAt: number }

local Logic = {}

-- 판정 확인 간격 (물 탈락). 충격파는 매 Heartbeat
Logic.CHECK_INTERVAL = 0.1

-- 온천수 (스펙 "온천수 상승")
Logic.WATER_START = -3
Logic.WATER_STEP = 1 -- 한 칸
Logic.WATER_EVERY = 10 -- 초마다
Logic.WATER_MAX = 4.5
Logic.WATER_EASE = 1 -- 보이는 물이 한 칸 오르는 데 걸리는 시간
Logic.SOAK_MARGIN = 0.5 -- 발 < 물 − 이 값이면 탈락
Logic.SINK_LEAD = 1 -- 물이 윗면 − 이 값에 닿으면 그 단이 가라앉아요
Logic.SINK_WARN = 3 -- 가라앉기 전 경고
Logic.SINK_DROP = 5 -- 가라앉으며 내려가는 거리
Logic.SINK_DURATION = 1

-- 충격파 (스펙 "인형뽑기 충격파")
Logic.FIRST_SLAM = 8
Logic.SLAM_PHASES = {
	{ from = 0, interval = 12, rings = 1 },
	{ from = 45, interval = 9, rings = 1 },
	{ from = 65, interval = 6, rings = 2 },
}
Logic.OVERTIME_INTERVAL = 3
Logic.OVERTIME_RINGS = 2
Logic.RING_GAP = 0.8 -- 두 번째 고리가 이만큼 뒤에
Logic.SLAM_WARN = 1.5
Logic.SLAM_HORIZON = 190 -- slamTimes 기본 끝 (Config.Final 안전 상한 150 + 40)
Logic.RING_START = 9 -- 섬 가장자리
Logic.RING_SPEED = 24 -- studs/s
Logic.RING_THICKNESS = 3 -- 보이는 고리 두께 (판정은 앞면만)
Logic.RING_END = 46 -- 1단 바깥 42 + 고리 두께를 지나면 사라져요
Logic.GROUND_TOLERANCE = 1.2 -- 발 ≤ 데크 윗면 + 이 값이면 "땅에 서 있음"
Logic.BELOW_TOLERANCE = 1.5 -- 발이 윗면보다 이만큼 넘게 낮으면 그 데크 위가 아니에요 (물에 빠지는 중)
Logic.KNOCK_HORIZONTAL = 24
Logic.KNOCK_UP = 18
Logic.TOP_TIER_MULTIPLIER = 1.3
Logic.KNOCK_HOLD = 0.12 -- LinearVelocity로 붙잡는 시간 (그 뒤는 포물선)
Logic.KNOCKDOWN_TIME = 0.8 -- PlatformStand
Logic.KNOCK_MOVE_EXEMPT = 1.5 -- MoveExempt.mark 초

-- 연장전
Logic.OVERTIME_WARN = 2

---------------------------------------------------------------- 온천수

function Logic.waterHeight(t: number): number
	local steps = math.floor(math.max(t, 0) / Logic.WATER_EVERY)
	return math.min(Logic.WATER_START + steps * Logic.WATER_STEP, Logic.WATER_MAX)
end

function Logic.waterVisual(t: number): number
	local current = Logic.waterHeight(t)
	local nextAt = (math.floor(math.max(t, 0) / Logic.WATER_EVERY) + 1) * Logic.WATER_EVERY
	local left = nextAt - t
	if left > Logic.WATER_EASE then
		return current
	end
	local target = Logic.waterHeight(nextAt)
	local alpha = 1 - left / Logic.WATER_EASE
	alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep
	return current + (target - current) * alpha
end

function Logic.isSoaked(footY: number, waterY: number): boolean
	return footY < waterY - Logic.SOAK_MARGIN
end

function Logic.sinkAt(tierIndex: number): number?
	local tier = Layout.TIERS[tierIndex]
	if tier == nil then
		return nil
	end
	local need = tier.top - Logic.SINK_LEAD
	if need > Logic.WATER_MAX then
		return nil
	end
	local steps = math.max(0, math.ceil((need - Logic.WATER_START) / Logic.WATER_STEP))
	return steps * Logic.WATER_EVERY
end

function Logic.deckState(tierIndex: number, t: number): DeckState
	local at = Logic.sinkAt(tierIndex)
	if at == nil then
		return "Solid"
	end
	if t >= at then
		return "Sunk"
	end
	if t >= at - Logic.SINK_WARN then
		return "Warn"
	end
	return "Solid"
end

---------------------------------------------------------------- 충격파

local function phaseAt(t: number)
	local result = Logic.SLAM_PHASES[1]
	for _, phase in Logic.SLAM_PHASES do
		if t >= phase.from then
			result = phase
		end
	end
	return result
end

-- 다음 "쿵". 이전 쿵 + 지금 구간 간격이 다음 구간에 들어가면 그 구간 간격을 써요
-- (44 + 12 = 56 ≥ 45 → 44 + 9 = 53, 62 + 9 = 71 ≥ 65 → 62 + 6 = 68 — 스펙 "45초부터 9초 간격(53, 62초)").
-- 연장전이 정해졌고 다음 쿵이 그 뒤면: max(이전, 연장전) + 3초, 고리 2개.
function Logic.nextSlam(prevAt: number?, overtimeAt: number?): Slam
	local candidate: number
	local phase
	if prevAt == nil then
		candidate = Logic.FIRST_SLAM
		phase = phaseAt(candidate)
	else
		local gap = phaseAt(prevAt).interval
		phase = phaseAt(prevAt + gap)
		candidate = prevAt + phase.interval
	end
	if overtimeAt ~= nil and candidate >= overtimeAt then
		return {
			at = math.max(prevAt or overtimeAt, overtimeAt) + Logic.OVERTIME_INTERVAL,
			rings = Logic.OVERTIME_RINGS,
		}
	end
	return { at = candidate, rings = phase.rings }
end

function Logic.slamTimes(overtimeAt: number?, untilT: number?): { Slam }
	local limit = untilT or Logic.SLAM_HORIZON
	local list: { Slam } = {}
	local prev: number? = nil
	while true do
		local slam = Logic.nextSlam(prev, overtimeAt)
		if slam.at > limit then
			break
		end
		table.insert(list, slam)
		prev = slam.at
	end
	return list
end

function Logic.ringRadius(slamAt: number, t: number): number
	return Logic.RING_START + Logic.RING_SPEED * math.max(0, t - slamAt)
end

-- 고리 앞면이 이번 틱에 그 사람을 지나가고(직전엔 고리 바깥: prevDist > prevRadius, 지금은 안쪽: dist ≤ radius),
-- 발이 그 데크 위(윗면 − 1.5 ~ 윗면 + 1.2)면 맞아요. 고리가 사람을 지나가든, 사람이 고리 쪽으로 걸어 들어와
-- 가로지르든 같아요 (m5-39 QA P2-1: 현재 거리만 보면 안쪽으로 걷는 사람이 구간을 건너뛰었어요).
-- prevDist가 없으면(처음 본 틱) 지금 거리를 써요. 점프 중이거나 이미 안쪽에 있던 사람은 안 맞아요.
function Logic.waveHit(
	dist: number,
	prevRadius: number,
	radius: number,
	footY: number,
	deckTop: number,
	prevDist: number?
): boolean
	local before = prevDist or dist
	if not (before > prevRadius and dist <= radius) then
		return false
	end
	if footY > deckTop + Logic.GROUND_TOLERANCE then
		return false
	end
	return footY >= deckTop - Logic.BELOW_TOLERANCE
end

function Logic.waveKnockback(dist: number, tier: number?): Knock
	local multiplier = 1
	if tier == Layout.TOP_TIER or dist < Layout.TIERS[Layout.TOP_TIER].outer then
		multiplier = Logic.TOP_TIER_MULTIPLIER
	end
	return { horizontal = Logic.KNOCK_HORIZONTAL * multiplier, up = Logic.KNOCK_UP * multiplier }
end

function Logic.outward(dx: number, dz: number): (number, number)
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-3 then
		return 1, 0
	end
	return dx / d, dz / d
end

---------------------------------------------------------------- 연장전

-- 남은 데크를 낮은 단부터, 같은 단은 Index 순으로 하나씩. k번째(1..n)는 duration·k/n에 가라앉고 2초 전부터 경고.
function Logic.overtimeSinkOrder(remaining: { DeckRef }, collapseDuration: number): { SinkStep }
	local sorted = table.clone(remaining)
	table.sort(sorted, function(a: DeckRef, b: DeckRef): boolean
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.index < b.index
	end)
	local n = #sorted
	local steps: { SinkStep } = {}
	for k, deck in sorted do
		local dropAt = collapseDuration * k / n
		table.insert(steps, {
			tier = deck.tier,
			index = deck.index,
			warnAt = math.max(0, dropAt - Logic.OVERTIME_WARN),
			dropAt = dropAt,
		})
	end
	return steps
end

return Logic
