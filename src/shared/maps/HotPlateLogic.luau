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
HotPlateLogic.COLOR_COLD = { r = 163, g = 162, b = 165 } :: RGB -- 회색 철판
HotPlateLogic.COLOR_WARM = { r = 255, g = 140, b = 0 } :: RGB -- 주황
HotPlateLogic.COLOR_HOT = { r = 220, g = 30, b = 0 } :: RGB -- 빨강

local function lerp(a: RGB, b: RGB, alpha: number): RGB
	return {
		r = math.floor(a.r + (b.r - a.r) * alpha + 0.5),
		g = math.floor(a.g + (b.g - a.g) * alpha + 0.5),
		b = math.floor(a.b + (b.b - a.b) * alpha + 0.5),
	}
end

-- 처음 밟힌 뒤 elapsed초가 지난 타일의 색과 사라졌는지.
-- 0초 회색 → 절반(0.75초) 주황 → HEAT_DURATION(1.5초) 빨강. HEAT_DURATION 이상이면 gone = true.
function HotPlateLogic.heatVisual(elapsed: number): (RGB, boolean)
	local duration = HotPlateLogic.HEAT_DURATION
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

return HotPlateLogic
