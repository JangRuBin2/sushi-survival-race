--!strict
-- "디저트 냉장고"(dessert-fridge, m5-06)의 순수 로직: 진행도, 낙하선, 송풍구 주기·방향·구역, 젤리 구역,
-- 밀기 속도, 튕김 높이, 길 찾기용 바닥 판정. Roblox API를 쓰지 않아서 Lune 테스트에서 그대로 불러요.
-- 치수는 DessertFridgeLayout. 좌표는 origin 기준 로컬 (x: 오른쪽 +, y: 위, z: 결승 쪽이 -)이에요.

local Layout = require(script.Parent.DessertFridgeLayout)

export type FanState = "Warn" | "Blow" | "Rest"

local Logic = {}

-- 진행도(로컬 -Z). 시간 종료 때 순위도 이 축이에요.
function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.FINISH_LINE_Z)
end

-- 그 z의 구간 바닥 높이 (A·B·C는 y 0, D·F·G는 y 12, E는 y 24). C 착지대(y 12)도 C 구간이라 0으로 봐요(스펙 표).
-- m5-40: G 착지대(y 24)도 같은 규칙으로 G 구간(12)이에요.
function Logic.floorAt(z: number): number
	if z > Layout.FAN_SHELF.front then
		return Layout.LOW_Y
	elseif z > Layout.SCOOP_ZONE.back then
		return Layout.HIGH_Y
	end
	return Layout.TOP_Y
end

-- 탈락선: 그 구간 바닥보다 FALL_MARGIN 아래 (B·C·구멍 -25, D·F·G -13, E -1)
function Logic.fallLineAt(z: number): number
	return Logic.floorAt(z) - Layout.FALL_MARGIN
end

-- 송풍구(한 개)의 시각 t 상태. 주기 4초: 0 ~ 0.5 Warn, 0.5 ~ 2.5 Blow, 2.5 ~ 4 Rest. (m5-40: D·F 송풍구 공통)
function Logic.fanStateOf(fan: Layout.Fan?, t: number): FanState
	local offset = if fan then fan.offset else 0
	local phase = (t - offset) % Layout.FAN_PERIOD
	if phase < Layout.FAN_WARN then
		return "Warn"
	elseif phase < Layout.FAN_WARN + Layout.FAN_BLOW then
		return "Blow"
	end
	return "Rest"
end

-- 송풍구 i의 시각 t(라운드 시작부터 초) 상태
function Logic.fanState(i: number, t: number): FanState
	return Logic.fanStateOf(Layout.FANS[i], t)
end

-- F 냉동 송풍구 i의 시각 t 상태 (m5-40)
function Logic.freezerFanState(i: number, t: number): FanState
	return Logic.fanStateOf(Layout.FREEZER_FANS[i], t)
end

-- 송풍구 i가 미는 방향 (로컬, 크기 1, 수평)
function Logic.fanPush(i: number): { x: number, y: number, z: number }
	local fan = Layout.FANS[i]
	local dirX = if fan then fan.dirX else 0
	return { x = dirX, y = 0, z = 0 }
end

-- 로컬 (x, y, z)가 송풍구 몇 번 구역 안인지 (밖이면 nil). 선반 폭 안이고 바닥 위 FAN_ZONE_HEIGHT 안이에요.
function Logic.fanAt(x: number, y: number, z: number): number?
	if math.abs(x) > Layout.FAN_SHELF_WIDTH / 2 then
		return nil
	end
	local height = y - Layout.HIGH_Y
	if height < -1 or height > Layout.FAN_ZONE_HEIGHT then
		return nil
	end
	for _, fan in Layout.FANS do
		if z <= fan.front and z >= fan.back then
			return fan.index
		end
	end
	return nil
end

-- 로컬 (x, y, z)가 F 냉동 송풍구 몇 번 구역 안인지 (m5-40). 냉동실 폭 안이고 바닥(y 12) 위 FAN_ZONE_HEIGHT 안이에요.
function Logic.freezerFanAt(x: number, y: number, z: number): number?
	if math.abs(x) > Layout.FREEZER_WIDTH / 2 then
		return nil
	end
	local height = y - Layout.HIGH_Y
	if height < -1 or height > Layout.FAN_ZONE_HEIGHT then
		return nil
	end
	for _, fan in Layout.FREEZER_FANS do
		if z <= fan.front and z >= fan.back then
			return fan.index
		end
	end
	return nil
end

-- F 냉동 송풍구 i가 미는 방향 (로컬, 크기 1, 수평)
function Logic.freezerFanPush(i: number): { x: number, y: number, z: number }
	local fan = Layout.FREEZER_FANS[i]
	return { x = if fan then fan.dirX else 0, y = 0, z = 0 }
end

-- 로컬 z가 F 냉동실 구간 안인지 (송풍구 소리는 누가 냉동실에 있을 때만 — m5-40)
function Logic.inFreezer(z: number): boolean
	return z <= Layout.FREEZER.front and z >= Layout.FREEZER.back
end

-- 한 축 밀기: 지금 속도(current)를 목표(target) 쪽으로 이번 프레임에 더할 양.
-- 이미 목표보다 빠르면(같은 방향) 더하지 않고, 반대로 줄이지도 않아요(다른 맵들과 같은 계약).
function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

-- 위 속도 up으로 튕겨 오르는 최고 높이 (중력 g)
function Logic.bounceHeight(up: number, gravity: number): number
	return up * up / (2 * gravity)
end

-- 로컬 (x, y, z)가 젤리 발판 몇 번 위인지 (발판 윗면 아래 1 ~ 위 JELLY_ZONE_HEIGHT, 발판 넓이 안). 아니면 nil.
function Logic.jellyAt(x: number, y: number, z: number): number?
	local height = y - Layout.JELLY_TOP
	if height < -1 or height > Layout.JELLY_ZONE_HEIGHT then
		return nil
	end
	local half = Layout.JELLY_SIZE / 2
	for i, jelly in Layout.JELLIES do
		if math.abs(x - jelly.x) <= half and math.abs(z - jelly.z) <= half then
			return i
		end
	end
	return nil
end

-- 로컬 (x, y, z)가 G 지름길 젤리 위인지 (m5-40). 윗면 = 바닥(y 12) + JELLY_TOP, 높이 규칙은 jellyAt과 같아요.
function Logic.scoopJellyAt(x: number, y: number, z: number): boolean
	local height = y - (Layout.HIGH_Y + Layout.JELLY_TOP)
	if height < -1 or height > Layout.JELLY_ZONE_HEIGHT then
		return false
	end
	local half = Layout.JELLY_SIZE / 2
	local jelly = Layout.SCOOP_JELLY
	return math.abs(x - jelly.x) <= half and math.abs(z - jelly.z) <= half
end

local function inside(rect: Layout.Rect, x: number, z: number): boolean
	return x > rect.minX and x < rect.maxX and z > rect.minZ and z < rect.maxZ
end

-- 길 찾기용: B 얼음 쟁반에서 로컬 (x, z) 한 점을 밟을 수 있는지 (바닥 있음, 구멍·큐브 아님)
function Logic.iceTrayWalkable(x: number, z: number): boolean
	if math.abs(x) > Layout.ICE_TRAY_WIDTH / 2 then
		return false
	end
	if z > Layout.ICE_TRAY.front or z < Layout.ICE_TRAY.back then
		return false
	end
	for _, rect in Layout.holeRects() do
		if inside(rect, x, z) then
			return false
		end
	end
	for _, rect in Layout.cubeRects() do
		if inside(rect, x, z) then
			return false
		end
	end
	return true
end

-- 쿠키 계단 디딤 높이 목록 (바닥 → 디딤 1 → 2 → 3 → 착지대). 연속 디딤 높이 차가 오르는 높이예요.
function Logic.cookieClimb(): { number }
	local heights = { Layout.LOW_Y }
	for _, step in Layout.COOKIE_STEPS do
		table.insert(heights, step.top)
	end
	table.insert(heights, Layout.HIGH_Y)
	return heights
end

-- 길 찾기용 (m5-40): F 냉동실에서 로컬 (x, z) 한 점을 밟을 수 있는지 (바닥 있음, 구멍 아님)
function Logic.freezerWalkable(x: number, z: number): boolean
	if math.abs(x) > Layout.FREEZER_WIDTH / 2 then
		return false
	end
	if z > Layout.FREEZER.front or z < Layout.FREEZER.back then
		return false
	end
	for _, rect in Layout.freezerHoleRects() do
		if inside(rect, x, z) then
			return false
		end
	end
	return true
end

export type Hop = { from: string, to: string, gap: number, rise: number }

-- G 스쿱 계단 길 (m5-40 AC1 길 약속): 통 바닥 → 스쿱 1 → … → 스쿱 4 → 착지대. gap: 가로 빈틈, rise: 오르는 높이.
function Logic.scoopClimb(): { Hop }
	local hops: { Hop } = {}
	local r = Layout.SCOOP_DIAMETER / 2
	local first = Layout.SCOOPS[1]
	-- 바닥에서 첫 스쿱: 바닥이 스쿱 둘레까지 있어서 빈틈 0
	table.insert(hops, { from = "ScoopFloor", to = "Scoop1", gap = 0, rise = Layout.scoopTop(1) - Layout.HIGH_Y })
	assert(first, "scoops")
	for i = 2, #Layout.SCOOPS do
		local a, b = Layout.SCOOPS[i - 1], Layout.SCOOPS[i]
		local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		table.insert(hops, {
			from = `Scoop{i - 1}`,
			to = `Scoop{i}`,
			gap = math.max(0, d - 2 * r),
			rise = Layout.scoopTop(i) - Layout.scoopTop(i - 1),
		})
	end
	local last = Layout.SCOOPS[#Layout.SCOOPS]
	table.insert(hops, {
		from = `Scoop{#Layout.SCOOPS}`,
		to = "ScoopLanding",
		gap = math.max(0, (last.z - r) - Layout.SCOOP_LANDING.front),
		rise = Layout.TOP_Y - Layout.scoopTop(#Layout.SCOOPS),
	})
	return hops
end

-- 빠른 사람 클리어 추정 (초): 1번 줄 스폰 → 결승선 걷기 + 구간별 지연 합 (m5-40 AC1, 42~55초)
function Logic.estimateClearTime(): number
	local startZ = Layout.START.front - 2.5
	local walk = (startZ - Layout.FINISH_LINE_Z) / Layout.WALK_SPEED
	local delay = 0
	for _, value in Layout.SECTION_DELAY do
		delay += value
	end
	return walk + delay
end

return Logic
