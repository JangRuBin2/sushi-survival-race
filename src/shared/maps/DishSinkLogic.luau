--!strict
-- "깨끗하게! 설거지통"(dish-sink, m5-34)의 순수 로직: 진행도, 구간, 바닥·낙하선, 접시 방향·밀기, 수세미 위치·속도·맞음,
-- 넉백 방향, 길이 추정, 길 찾기용 틈 계산. Roblox API를 쓰지 않아서 Lune 테스트에서 그대로 불러요.
-- 치수는 DishSinkLayout. 좌표는 origin 기준 로컬 (x: 오른쪽 +, y: 위, z: 결승 쪽이 -)이에요.

local Layout = require(script.Parent.DishSinkLayout)

local Logic = {}

-- 진행도(로컬 -Z). 시간 종료 때 순위도 이 축이에요.
function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

-- z가 속한 구간 이름 ("A" ~ "G"). 출발 뒤(z > 0)는 A, 끝 너머는 G.
function Logic.sectionAt(z: number): string
	for i, span in Layout.sections() do
		if z > span.back then
			return Layout.SECTION_NAMES[i]
		end
	end
	return "G"
end

-- 그 z의 구간 바닥 높이: A·B·C 0, D 0 → 4 (z를 따라 고르게), E·F 4, G 오르막 4 → 10 뒤 10.
function Logic.floorAt(z: number): number
	if z > Layout.CUPS.front then
		return Layout.LOW_Y
	elseif z > Layout.CUPS.back then
		local t = (Layout.CUPS.front - z) / (Layout.CUPS.front - Layout.CUPS.back)
		return Layout.LOW_Y + (Layout.HIGH_Y - Layout.LOW_Y) * t
	elseif z > Layout.RAMP.front then
		return Layout.HIGH_Y
	elseif z > Layout.RAMP.back then
		local t = (Layout.RAMP.front - z) / (Layout.RAMP.front - Layout.RAMP.back)
		return Layout.HIGH_Y + (Layout.FINISH_Y - Layout.HIGH_Y) * t
	end
	return Layout.FINISH_Y
end

-- 탈락선: 그 구간 바닥보다 FALL_MARGIN(12) 아래
function Logic.fallLineAt(z: number): number
	return Logic.floorAt(z) - Layout.FALL_MARGIN
end

-- ── 회전 접시 ───────────────────────────────────────────────────────
function Logic.plateDirection(row: number, lane: number): number
	return Layout.plateDirection(row, lane)
end

-- 접시 중심 기준 상대 위치 (dx, dz)에 있는 사람을 미는 목표 수평 속도 (vx, vz). 접시 밖이면 nil.
-- dir 1 = 위에서 볼 때 시계 방향, -1 = 반시계. kind가 없으면 B 접시(지름 20).
-- 접선 크기 = min(ω·r, cap), 가장자리(r > 0.7R)에서는 바깥쪽 EDGE_PUSH를 더해요.
function Logic.platePush(dx: number, dz: number, dir: number, kind: Layout.PlateKind?): (number?, number?)
	local k = kind or Layout.SMALL_PLATE
	local r = math.sqrt(dx * dx + dz * dz)
	if r > k.radius then
		return nil, nil
	end
	if r < 1e-6 then
		return 0, 0
	end
	local ux, uz = dx / r, dz / r
	-- 위에서 볼 때 시계 방향 접선 (화면 위 = -Z): (vx, vz) = (-uz, ux)
	local tangent = math.min(k.omega * r, k.cap) * (if dir < 0 then -1 else 1)
	local vx, vz = -uz * tangent, ux * tangent
	if r > Layout.EDGE_FRACTION * k.radius then
		vx += ux * Layout.EDGE_PUSH
		vz += uz * Layout.EDGE_PUSH
	end
	return vx, vz
end

-- 로컬 (x, y, z)가 어느 접시 위인지 (발 높이가 윗면 -1 ~ +ZONE 안이고 반지름 안). 없으면 nil.
function Logic.plateAt(x: number, y: number, z: number): Layout.Plate?
	local foot = y - Layout.FOOT_OFFSET
	for _, plate in Layout.PLATES do
		local h = foot - plate.top
		if h < -1 or h > Layout.PLATE_ZONE_HEIGHT then
			continue
		end
		local dx, dz = x - plate.x, z - plate.z
		if dx * dx + dz * dz <= plate.kind.radius * plate.kind.radius then
			return plate
		end
	end
	return nil
end

-- 한 축 밀기: 지금 속도(current)를 목표(target) 쪽으로 이번 프레임에 더할 양 (줄이지는 않아요).
function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

-- ── 수세미 ──────────────────────────────────────────────────────────
-- 한 주기 안 위치 (0 ~ 8초): 0 ~ 1.5 +A 멈춤, 1.5 ~ 4 +A → -A, 4 ~ 5.5 -A 멈춤, 5.5 ~ 8 -A → +A.
-- 이동은 코사인으로 부드럽게 (양 끝에서 천천히 출발·정지).
local function cycle(i: number, t: number): (number, number)
	local sponge = Layout.SPONGES[i]
	local offset = if sponge then sponge.offset else 0
	local amp = if sponge then sponge.amplitude else 12
	return (t - offset) % Layout.SPONGE_PERIOD, amp
end

function Logic.spongeX(i: number, t: number): number
	local phase, amp = cycle(i, t)
	local hold, move = Layout.SPONGE_HOLD, Layout.SPONGE_MOVE
	if phase < hold then
		return amp
	elseif phase < hold + move then
		local s = (phase - hold) / move
		return amp * math.cos(math.pi * s)
	elseif phase < 2 * hold + move then
		return -amp
	end
	local s = (phase - 2 * hold - move) / move
	return -amp * math.cos(math.pi * s)
end

-- x 속도 (studs/s). 멈춰 있으면 0.
function Logic.spongeVelocity(i: number, t: number): number
	local phase, amp = cycle(i, t)
	local hold, move = Layout.SPONGE_HOLD, Layout.SPONGE_MOVE
	if phase < hold or (phase >= hold + move and phase < 2 * hold + move) then
		return 0
	elseif phase < hold + move then
		local s = (phase - hold) / move
		return -amp * math.pi / move * math.sin(math.pi * s)
	end
	local s = (phase - 2 * hold - move) / move
	return amp * math.pi / move * math.sin(math.pi * s)
end

-- 수세미 중심 기준 (dx, dz)·발 높이(그 자리 바닥 기준 footY)가 맞음인지. sizeX·sizeZ가 없으면 C 수세미(9 x 7).
function Logic.spongeHit(dx: number, dz: number, footY: number, sizeX: number?, sizeZ: number?): boolean
	local hx = (sizeX or 9) / 2 + Layout.SPONGE_HIT_PAD_X
	local hz = (sizeZ or 7) / 2 + Layout.SPONGE_HIT_PAD_Z
	if footY >= Layout.SPONGE_HIT_FOOT or footY < -4 then
		return false
	end
	return math.abs(dx) <= hx and math.abs(dz) <= hz
end

-- 넉백 x 방향 (+1/-1): 움직이는 중이면 그 방향, 멈춰 있으면 수세미 중심에서 멀어지는 쪽.
function Logic.knockDirection(velocityX: number, dx: number): number
	if math.abs(velocityX) > 0.05 then
		return if velocityX > 0 then 1 else -1
	end
	return if dx >= 0 then 1 else -1
end

-- 수세미 i가 그 자리 길(반폭 halfWidth)을 완전히 비켰는지: 수세미 안쪽 면 |x| - sizeX/2 ≥ halfWidth
function Logic.spongeClear(i: number, t: number, halfWidth: number): boolean
	local sponge = Layout.SPONGES[i]
	local half = if sponge then sponge.sizeX / 2 else 4.5
	return math.abs(Logic.spongeX(i, t)) - half >= halfWidth - 1e-9
end

-- 그 수세미가 놓인 길의 반폭 (C 칸막이 6, E 다리 5, F 복도 8)
function Logic.pathHalfWidth(sponge: Layout.Sponge): number
	if sponge.section == "C" then
		return Layout.PARTITION_WIDTH / 2
	elseif sponge.section == "E" then
		return Layout.BRIDGE_WIDTH / 2
	end
	return Layout.CORRIDOR_WIDTH / 2
end

-- ── 길이 추정 ───────────────────────────────────────────────────────
-- 1번 줄 스폰에서 결승선까지 걷는 시간 + 구간별 지연 합 (빠른 사람 기준, 초)
function Logic.estimateClearTime(): number
	local startZ = Layout.START.front - 2.5
	local walk = (startZ - Layout.FINISH_LINE_Z) / Layout.WALK_SPEED
	local delay = 0
	for _, name in Layout.SECTION_NAMES do
		delay += Layout.SECTION_DELAY[name] or 0
	end
	return walk + delay
end

-- ── 길 찾기용 틈 ────────────────────────────────────────────────────
-- 원(중심 x,z, 반지름 r)과 직사각형 사이 수평 틈 (겹치면 0 이하)
function Logic.circleRectGap(cx: number, cz: number, r: number, rect: Layout.Rect): number
	local nx = math.clamp(cx, rect.minX, rect.maxX)
	local nz = math.clamp(cz, rect.minZ, rect.maxZ)
	return math.sqrt((cx - nx) ^ 2 + (cz - nz) ^ 2) - r
end

function Logic.circleGap(ax: number, az: number, ar: number, bx: number, bz: number, br: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) - ar - br
end

return Logic
