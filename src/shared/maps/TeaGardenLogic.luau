--!strict
-- "찻잎 정원" 순수 계산 (m5-38). Roblox API 없음 — tests/map-tea-garden.spec.luau.
-- 시간 t는 라운드 출발 기준 초, overtimeAt은 연장전이 시작된 출발 기준 초(없으면 아직 연장전 전).
--   Logic.collapseAt(ring, overtimeAt?) -> number?                 본 경기 일정 (5·4·3단 15·30·45초, 2·1단 연장전 +10·+20)
--   Logic.isCollapsing(ring, t, overtimeAt?) -> "Solid" | "Warn" | "Gone"
--   Logic.overtimeCollapse(collapseDuration, remainingRings) -> { { ring, warnAt, dropAt } }   (연장전 기준 초)
--   Logic.cupWave(t, overtimeAt?) -> (count, speed)                찻잔 수·선속도
--   Logic.cupPosition(cup, t) -> (ring, angle)                     구르는 찻잔 위치
--   Logic.cupHit(dx, dz, footY, ringTop) -> boolean
--   Logic.cupKnockback(angle, dir) -> { x, y, z }                  진행 방향 26 + 바깥 12 + 위 18
--   Logic.safeRings(rings, t) -> { number }
--   Logic.pickCupRing(rng, cups, rings, t, index?) -> number?      찻잔 index가 옮겨 갈 이웃 단 (없으면 nil)
--   Logic.mustMoveCup(cups, rings, t, index?) -> boolean           지금 단이 위험하거나 (찻잔 수 ≤ 남은 단 수인데) 겹침
--   Logic.shouldMoveCup(rng, cups, rings, t, index?) -> boolean    6초마다: 꼭 옮겨야 하면 true, 아니면 50%

local Layout = require(script.Parent.TeaGardenLayout)

export type Phase = "Solid" | "Warn" | "Gone"
export type OvertimeStep = { ring: number, warnAt: number, dropAt: number }
export type RingInfo = { ring: number, collapseAt: number? } -- 아직 남은 단과 (알면) 무너질 시각
export type Cup = { ring: number, angle0: number, t0: number, dir: number, speed: number }
export type Vec = { x: number, y: number, z: number }
export type Rng = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

local Logic = {}

-- ── 차밭이 무너짐 ─────────────────────────────────────────────
Logic.COLLAPSE_AT = { [5] = 15, [4] = 30, [3] = 45 } :: { [number]: number }
Logic.OVERTIME_DROP = { [2] = 10, [1] = 20 } :: { [number]: number } -- 연장전 기준 (보통 1·2단만 남아요)
Logic.WARN_TIME = 3 -- 무너지기 전 깜빡임
Logic.DROP_TIME = 0.6 -- 무너질 때 내려가며 투명해지는 시간
Logic.DROP_DISTANCE = 3

function Logic.collapseAt(ring: number, overtimeAt: number?): number?
	local main = Logic.COLLAPSE_AT[ring]
	if main then
		return main
	end
	local late = Logic.OVERTIME_DROP[ring]
	if late and overtimeAt then
		return overtimeAt + late
	end
	return nil
end

function Logic.isCollapsing(ring: number, t: number, overtimeAt: number?): Phase
	local at = Logic.collapseAt(ring, overtimeAt)
	if at == nil then
		return "Solid"
	end
	if t >= at then
		return "Gone"
	end
	if t >= at - Logic.WARN_TIME then
		return "Warn"
	end
	return "Solid"
end

-- 남은 단을 바깥 → 안 순서로, k번째(1부터, 모두 n개)를 dropAt = D·k/n, warnAt = max(0, dropAt − 3).
function Logic.overtimeCollapse(collapseDuration: number, remainingRings: { number }): { OvertimeStep }
	local rings = table.clone(remainingRings)
	table.sort(rings, function(a: number, b: number): boolean
		return a > b -- 바깥(큰 번호) 먼저
	end)
	local n = #rings
	local steps: { OvertimeStep } = {}
	for k, ring in rings do
		local dropAt = collapseDuration * k / n
		table.insert(steps, { ring = ring, warnAt = math.max(0, dropAt - Logic.WARN_TIME), dropAt = dropAt })
	end
	return steps
end

-- ── 굴러가는 찻잔 ─────────────────────────────────────────────
Logic.CUP_DIAMETER = 6
Logic.CUP_WIDTH = 4
Logic.CUP_START = 3 -- 첫 찻잔이 나오는 시각
Logic.CUP_EMERGE_WARN = 1.5 -- 새 찻잔이 나오기 전 찻사발 아래 틈이 빛나는 시간
Logic.CUP_EMERGE_TIME = 0.5 -- 찻사발에서 1단 가운데까지 굴러 나오는 시간
Logic.MAX_CUPS = 3
-- { from, count, speed } — from초부터 (마지막 행이 이김)
Logic.WAVES = {
	{ from = 3, count = 1, speed = 13 },
	{ from = 30, count = 2, speed = 13 },
	{ from = 60, count = 3, speed = 16 },
}
Logic.OVERTIME_CUPS = 3
Logic.OVERTIME_SPEED = 18

Logic.MOVE_INTERVAL = 6 -- 찻잔마다 이 간격으로 단 옮기기를 정해요
Logic.MOVE_CHANCE = 0.5
Logic.MOVE_WARN = 1.2 -- 노랗게 빛나고 점선 호
Logic.MOVE_TIME = 0.5 -- 옮겨 가는 시간
Logic.MOVE_SAFE_WINDOW = 4 -- 이 안에 무너질 단으로는 안 가요 (지금 단이면 바로 떠나요)

-- 맞음
Logic.HIT_RADIUS = 3.5
Logic.HIT_HEIGHT = 6 -- 발이 단 윗면 + 6보다 낮으면 맞아요 (점프 최고 약 6.4라 사실상 못 넘어요)
Logic.KNOCK_FORWARD = 26
Logic.KNOCK_OUTWARD = 12
Logic.KNOCK_UP = 18
Logic.LAUNCH_HOLD = 0.12
Logic.KNOCKDOWN_TIME = 0.8 -- PlatformStand
Logic.EXEMPT_TIME = 1.5 -- MoveExempt
Logic.HIT_COOLDOWN = 1

function Logic.cupWave(t: number, overtimeAt: number?): (number, number)
	if overtimeAt ~= nil and t >= overtimeAt then
		return Logic.OVERTIME_CUPS, Logic.OVERTIME_SPEED
	end
	local count, speed = 0, 0
	for _, wave in Logic.WAVES do
		if t >= wave.from then
			count, speed = wave.count, wave.speed
		end
	end
	return count, speed
end

-- 단 가운데 원을 따라 일정 선속도로 돌아요 (D4: 일정 각속도면 바깥 단에서 너무 빨라요)
function Logic.cupPosition(cup: Cup, t: number): (number, number)
	local radius = Layout.ringMid(cup.ring)
	local angle = cup.angle0 + cup.dir * cup.speed / radius * (t - cup.t0)
	return cup.ring, angle % (2 * math.pi)
end

-- 같은 위치에서 속도·단을 바꿀 때 기준점을 다시 잡아요 (위치가 튀지 않게)
function Logic.rebase(cup: Cup, t: number, ring: number?, speed: number?): Cup
	local _, angle = Logic.cupPosition(cup, t)
	return { ring = ring or cup.ring, angle0 = angle, t0 = t, dir = cup.dir, speed = speed or cup.speed }
end

function Logic.cupHit(dx: number, dz: number, footY: number, ringTop: number): boolean
	return dx * dx + dz * dz <= Logic.HIT_RADIUS * Logic.HIT_RADIUS and footY < ringTop + Logic.HIT_HEIGHT
end

-- 찻잔이 각도 angle에서 dir(+1 = 각도가 커지는 쪽) 방향으로 구를 때 맞은 사람이 받는 속도 (origin 로컬)
function Logic.cupKnockback(angle: number, dir: number): Vec
	local tx, tz = -math.sin(angle) * dir, math.cos(angle) * dir
	local ox, oz = math.cos(angle), math.sin(angle)
	return {
		x = tx * Logic.KNOCK_FORWARD + ox * Logic.KNOCK_OUTWARD,
		y = Logic.KNOCK_UP,
		z = tz * Logic.KNOCK_FORWARD + oz * Logic.KNOCK_OUTWARD,
	}
end

-- 지금 시각 t에 찻잔이 갈 수 있는 단 (무너지지 않았고 MOVE_SAFE_WINDOW 안에 무너지지 않음), 작은 번호부터
function Logic.safeRings(rings: { RingInfo }, t: number): { number }
	local out: { number } = {}
	for _, info in rings do
		local at = info.collapseAt
		if at == nil or at > t + Logic.MOVE_SAFE_WINDOW then
			table.insert(out, info.ring)
		end
	end
	table.sort(out)
	return out
end

-- cups[i] = 찻잔 i가 있는(또는 옮겨 가는 중인) 단. index 찻잔의 다음 단을 골라요.
-- 이웃 단 = 갈 수 있는 단 중 바로 안쪽·바로 바깥쪽 (무너진 단은 건너뛰어요). 둘 중 무작위.
-- 찻잔 수 ≤ 남은 단 수면 다른 찻잔이 있는 이웃은 빼요. 지금 단이 위험한데 빈 이웃이 없으면 겹쳐도 옮겨요.
-- 갈 곳이 없으면 nil (그대로 있어요).
function Logic.pickCupRing(rng: Rng, cups: { number }, rings: { RingInfo }, t: number, index: number?): number?
	local i = index or 1
	local current = cups[i]
	local safe = Logic.safeRings(rings, t)
	local currentSafe = table.find(safe, current) ~= nil
	local inner: number? = nil
	local outer: number? = nil
	for _, ring in safe do
		if ring < current and (inner == nil or ring > inner) then
			inner = ring
		elseif ring > current and (outer == nil or ring < outer) then
			outer = ring
		end
	end
	local neighbors: { number } = {}
	if inner then
		table.insert(neighbors, inner)
	end
	if outer then
		table.insert(neighbors, outer)
	end
	local options = neighbors
	if #cups <= #rings then
		local free: { number } = {}
		for _, ring in neighbors do
			local taken = false
			for j, other in cups do
				if j ~= i and other == ring then
					taken = true
					break
				end
			end
			if not taken then
				table.insert(free, ring)
			end
		end
		if #free > 0 or currentSafe then
			options = free
		end
	end
	if #options == 0 then
		return nil
	elseif #options == 1 then
		return options[1]
	end
	return options[rng:NextInteger(1, #options)]
end

-- 단 옮기기 결정 (6초마다 + 매 틱 위험 확인): 지금 단이 위험하면 꼭, 찻잔 수 ≤ 남은 단 수인데 다른 찻잔과 같은
-- 단이면 꼭, 아니면 MOVE_CHANCE. 꼭 옮겨야 할 때는 rng를 쓰지 않아요.
function Logic.mustMoveCup(cups: { number }, rings: { RingInfo }, t: number, index: number?): boolean
	local i = index or 1
	local current = cups[i]
	if table.find(Logic.safeRings(rings, t), current) == nil then
		return true
	end
	if #cups <= #rings then
		for j, other in cups do
			if j ~= i and other == current then
				return true
			end
		end
	end
	return false
end

function Logic.shouldMoveCup(rng: Rng, cups: { number }, rings: { RingInfo }, t: number, index: number?): boolean
	if Logic.mustMoveCup(cups, rings, t, index) then
		return true
	end
	return rng:NextNumber() < Logic.MOVE_CHANCE
end

return Logic
