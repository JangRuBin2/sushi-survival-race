--!strict
-- "뜨거운 철판" Survival 맵의 순수 로직 (m2-03). Roblox API를 쓰지 않아서 Lune 테스트에서 바로 불러요.
-- 치수(층·타일 격자·스폰 배치), 달아오르는 타일의 색/사라짐 계산, 탈락 높이를 여기 모아 둬요.
-- 색은 Color3 대신 0~255 RGB 테이블로 돌려줘요 (HotPlate.luau가 Color3로 바꿔요).

local HotPlateLogic = {}

export type RGB = { r: number, g: number, b: number }
export type Offset = { x: number, z: number }

-- 치수 (studs). 플레이테스트로 조정하는 초기값 (스펙 결정 기록).
HotPlateLogic.LAYER_COUNT = 3
HotPlateLogic.GRID_SIZE = 9 -- 한 층 = GRID_SIZE × GRID_SIZE 타일
HotPlateLogic.TILE_SIZE = 6 -- 타일 한 변 (층 한 변 = 54)
HotPlateLogic.TILE_THICKNESS = 1
HotPlateLogic.LAYER_GAP = 20 -- 층 윗면 사이 높이 (스펙: 18~24)
HotPlateLogic.FALL_BELOW_BOTTOM = 15 -- 맨 아래층 윗면보다 이만큼 아래면 탈락
HotPlateLogic.SPAWN_COUNT = 24 -- 최대 방 인원
HotPlateLogic.SPAWN_COLUMNS = 6

-- 달아오름: 처음 밟힌 순간부터 HEAT_DURATION초 뒤 사라져요. 내려와도 멈추지 않고 다시 생기지 않아요.
HotPlateLogic.HEAT_DURATION = 1.5
-- m5-40: 시간 제한 75초(맵 timeLimit — Config.TimeLimit.Survival 60은 그대로), 60초부터 서든데스.
-- 서든데스에 처음 밟힌 타일은 HEAT_DURATION_SUDDEN초에 사라져요. 이미 달아오르던 타일은 처음 밟힌 때의 시간을 그대로 써요.
HotPlateLogic.TIME_LIMIT = 75
HotPlateLogic.SUDDEN_DEATH_AT = 60
HotPlateLogic.HEAT_DURATION_SUDDEN = 1.2
-- 색만 m4-03 아트 패스로 다듬었어요 (진회색 철판 → 진한 주황 → 빨강, 마지막엔 HotPlateArt.isGlowing으로 Neon).
-- 달아오르는 동안 초록·파랑이 늘지 않게 COLD의 g·b가 WARM보다 커요 (map-hot-plate 테스트).
HotPlateLogic.COLOR_COLD = { r = 104, g = 106, b = 112 } :: RGB -- 진회색 철판
HotPlateLogic.COLOR_WARM = { r = 232, g = 100, b = 24 } :: RGB -- 주황
HotPlateLogic.COLOR_HOT = { r = 196, g = 36, b = 16 } :: RGB -- 빨강 (Neon이라 조금 어둡게)

local function lerp(a: RGB, b: RGB, alpha: number): RGB
	return {
		r = math.floor(a.r + (b.r - a.r) * alpha + 0.5),
		g = math.floor(a.g + (b.g - a.g) * alpha + 0.5),
		b = math.floor(a.b + (b.b - a.b) * alpha + 0.5),
	}
end

-- 라운드 시작 뒤 roundElapsed초에 처음 밟힌 타일이 사라지기까지 걸리는 시간 (m5-40 서든데스).
function HotPlateLogic.heatDuration(roundElapsed: number): number
	if roundElapsed >= HotPlateLogic.SUDDEN_DEATH_AT then
		return HotPlateLogic.HEAT_DURATION_SUDDEN
	end
	return HotPlateLogic.HEAT_DURATION
end

-- 처음 밟힌 뒤 elapsed초가 지난 타일의 색과 사라졌는지. heatTime은 그 타일의 달아오름 시간(기본 HEAT_DURATION).
-- 0초 회색 → 절반 주황 → heatTime 빨강. heatTime 이상이면 gone = true.
function HotPlateLogic.heatVisual(elapsed: number, heatTime: number?): (RGB, boolean)
	local duration = heatTime or HotPlateLogic.HEAT_DURATION
	local t = math.clamp(elapsed / duration, 0, 1)
	local color
	if t <= 0.5 then
		color = lerp(HotPlateLogic.COLOR_COLD, HotPlateLogic.COLOR_WARM, t / 0.5)
	else
		color = lerp(HotPlateLogic.COLOR_WARM, HotPlateLogic.COLOR_HOT, (t - 0.5) / 0.5)
	end
	return color, elapsed >= duration
end

-- 층 한 변 길이
function HotPlateLogic.plateSize(): number
	return HotPlateLogic.GRID_SIZE * HotPlateLogic.TILE_SIZE
end

-- 층 index(1 = 맨 위)의 윗면 높이. 맨 위층 윗면이 origin 높이(0)예요.
function HotPlateLogic.layerTopY(layerIndex: number): number
	return -(layerIndex - 1) * HotPlateLogic.LAYER_GAP
end

-- 철판 중심의 로컬 z. 다른 맵처럼 origin 앞쪽(로컬 -Z)에 지어요.
function HotPlateLogic.centerZ(): number
	return -HotPlateLogic.plateSize() / 2
end

-- 한 층의 타일 중심들 (철판 중심 기준 로컬 x, z). 틈 없이 GRID_SIZE² 개.
function HotPlateLogic.tileOffsets(): { Offset }
	local n = HotPlateLogic.GRID_SIZE
	local size = HotPlateLogic.TILE_SIZE
	local offsets = {}
	for row = 0, n - 1 do
		for col = 0, n - 1 do
			table.insert(offsets, {
				x = (col - (n - 1) / 2) * size,
				z = (row - (n - 1) / 2) * size,
			})
		end
	end
	return offsets
end

-- 스폰 SPAWN_COUNT개를 맨 위층 전체에 고르게 흩어요 (철판 중심 기준 로컬 x, z).
-- 칸을 층 전체로 나눈 뒤 각 칸 가운데에 둬서 가장자리와도 여유가 있어요.
function HotPlateLogic.spawnOffsets(): { Offset }
	local count = HotPlateLogic.SPAWN_COUNT
	local columns = HotPlateLogic.SPAWN_COLUMNS
	local rows = math.ceil(count / columns)
	local plate = HotPlateLogic.plateSize()
	local cellX = plate / columns
	local cellZ = plate / rows
	local offsets = {}
	for i = 1, count do
		local col = (i - 1) % columns
		local row = (i - 1) // columns
		table.insert(offsets, {
			x = -plate / 2 + (col + 0.5) * cellX,
			z = -plate / 2 + (row + 0.5) * cellZ,
		})
	end
	return offsets
end

-- 이 로컬 높이(origin 기준 y)보다 아래로 내려가면 탈락
function HotPlateLogic.eliminationY(): number
	return HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT) - HotPlateLogic.FALL_BELOW_BOTTOM
end

-- m5-40 AC3: 바닥이 모자라지 않는지 보는 단순 시뮬레이션. 레이서 players명이 "조심스럽게" 움직여요 —
-- 한 타일에 그 타일이 사라지기 직전까지 서 있다가 아직 안 밟은 타일로 옮겨요(한 사람이 한 번에 한 타일만 달굼).
-- 한 사람이 타일 하나를 쓰는 시간 = 그 타일을 밟은 시각의 heatDuration. 층 3개의 전체 타일(243)에서
-- step초 간격으로 빼 나가요(타일은 다시 생기지 않아요, m2-03). 돌려주는 값: 가장 적었을 때 남은 "아직 안 밟은"
-- 타일 수, duration초에 남은 타일 수. 실제로는 넘어지거나 떨어진 사람이 생겨 이보다 덜 써요.
function HotPlateLogic.simulateFloor(players: number, duration: number, step: number?): (number, number)
	local dt = step or 0.05
	local total = HotPlateLogic.LAYER_COUNT * HotPlateLogic.GRID_SIZE * HotPlateLogic.GRID_SIZE
	local remaining = total - players -- 출발할 때 각자 한 타일 위 (스폰은 서로 다른 타일)
	local lowest = remaining
	local nextStep: { number } = {}
	for i = 1, players do
		nextStep[i] = HotPlateLogic.heatDuration(0)
	end
	local t = 0
	while t < duration - 1e-9 do
		t += dt
		for i = 1, players do
			if t >= nextStep[i] - 1e-9 then
				remaining -= 1
				nextStep[i] += HotPlateLogic.heatDuration(nextStep[i])
			end
		end
		lowest = math.min(lowest, remaining)
	end
	return lowest, remaining
end

return HotPlateLogic
