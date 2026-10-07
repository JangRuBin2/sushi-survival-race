--!strict
-- "간장 늪 & 와사비 산" 코스 치수와 튜닝 값, 장애물 판정에 쓰는 순수 계산 (Roblox API 없음).
-- SoySwamp.build가 이 표대로 회색 박스를 쌓고, tests/map-soy-swamp.spec.luau가 치수 약속을 확인해요.
--
-- 좌표는 origin 기준 로컬 studs예요. x: 좌우(-가 왼쪽), y: 위, z: 0이 출발 끝이고 음수로 갈수록 결승.
-- 바닥 윗면이 y = 0이에요.

export type Box = {
	x: number, -- 중심
	z: number, -- 중심
	width: number, -- x 크기
	depth: number, -- z 크기
}

export type Span = { front: number, back: number } -- front > back (z가 작을수록 결승 쪽)

local Layout = {}

-- 공통
Layout.WIDTH = 24 -- 코스 폭 (간장 늪 폭 20 이상)
Layout.FLOOR_THICKNESS = 2
Layout.WALL_HEIGHT = 48 -- 와사비로 가장 높이 튀어도 못 넘게 (아래 테스트가 확인)
Layout.FALL_DEPTH = 40 -- origin보다 이만큼 아래로 떨어지면 탈락 (안전망)

-- 구간 (z 범위)
Layout.START = { front = 0, back = -16 } :: Span
Layout.SWAMP = { front = -16, back = -60 } :: Span
Layout.APPROACH = { front = -60, back = -72 } :: Span -- 와사비 산 앞 평지 (와사비 패드가 있어요)
Layout.MOUNTAIN = { front = -72, back = -112 } :: Span
Layout.SLOPE = { front = -112, back = -160 } :: Span -- 날치알 내리막 (결승 쪽이 높아요)
Layout.FINISH = { front = -160, back = -174 } :: Span

-- 간장 늪: 웅덩이 3개가 번갈아 한쪽 끝만 비워서, 폭 4의 마른 길이 지그재그로 이어져요.
Layout.DRY_PATH_WIDTH = 4
Layout.PUDDLES = {
	{ x = -2, z = -25, width = 20, depth = 10 }, -- 오른쪽(x 8~12)이 마른 길
	{ x = 2, z = -39, width = 20, depth = 10 }, -- 왼쪽(x -12~-8)이 마른 길
	{ x = -2, z = -53, width = 20, depth = 10 }, -- 오른쪽이 마른 길
} :: { Box }
Layout.PUDDLE_DEPTH = 0.2 -- 바닥에 깔린 얇은 판 (CanCollide false)

-- 와사비 산: 높이 MOUNTAIN_HEIGHT. 왼쪽 몸통(x -12~4)은 앞이 절벽이라 와사비 패드로만 바로 올라가요.
-- 오른쪽은 지면 통로(x 8~12)로 산 뒤쪽까지 간 다음, 경사로(x 4~8)를 되돌아 올라가는 길이에요 (느리지만 안전).
Layout.MOUNTAIN_HEIGHT = 12
Layout.MOUNTAIN_BODY = { x = -4, z = -88, width = 16, depth = 32 } :: Box -- z -72 ~ -104
Layout.MOUNTAIN_BACK = { x = 0, z = -108, width = 24, depth = 8 } :: Box -- z -104 ~ -112, 폭 전체
Layout.RAMP = { x = 6, width = 4, low = -104, high = -76 } -- low 쪽이 지면, high 쪽이 산 꼭대기 높이
Layout.WASABI_PADS = {
	{ x = -4, z = -63.5, width = 12, depth = 5 }, -- 절벽(z -72)에서 6~11 studs 앞
} :: { Box }
Layout.PAD_THICKNESS = 0.4

-- 날치알 내리막: SLOPE 구간에서 높이 SLOPE_LOW → SLOPE_HIGH로 올라가요. 공은 위(결승 쪽)에서 굴러 내려와요.
Layout.SLOPE_LOW = 12
Layout.SLOPE_HIGH = 20
Layout.BALL_SPAWN_Z = -157 -- 공이 생기는 z (내리막 꼭대기 바로 아래)
Layout.BALL_SPAWN_HALF_WIDTH = 9 -- 공이 생기는 x 범위 (±)

-- 결승: 높이 SLOPE_HIGH의 평지. 결승선을 끝 벽보다 FINISH_LINE_INSET 앞에 둬요 (넘은 뒤 서 있을 자리).
Layout.FINISH_LINE_INSET = 4

-- 스폰 24개 (6열 × 4줄)
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 4
Layout.SPAWN_SPACING = 3.6

-- 튜닝 초기값 (플레이테스트로 조정)
Layout.SOY_SPEED_MULTIPLIER = 0.5 -- 간장 안 이동 속도 배율
Layout.SOY_ZONE_HEIGHT = 5 -- 웅덩이 위 이 높이 안에 HumanoidRootPart가 있으면 간장 안이에요 (서 있으면 약 3)
Layout.WASABI_UP = 80 -- 튕김 위 속도 (studs/s)
Layout.WASABI_FORWARD = 30 -- 튕김 앞 속도 (studs/s)
Layout.WASABI_ZONE_HEIGHT = 4.5 -- 패드 위 이 높이 안이면 밟은 거예요
Layout.WASABI_COOLDOWN = 1 -- 같은 플레이어 재발동 간격 (초)
Layout.WASABI_HOLD = 0.08 -- 튕김 속도를 강제로 거는 시간 (초). 그다음은 그냥 포물선이에요.
Layout.WASABI_TEXT_DURATION = 1 -- "매워!!" 표시 시간
Layout.BALL_DIAMETER = 5 -- 날치알 공 지름 (4~6)
Layout.BALL_INTERVAL_MIN = 2 -- 공 생성 간격 (초)
Layout.BALL_INTERVAL_MAX = 3
Layout.BALL_LIFETIME = 8 -- 이 시간이 지나면 사라져요
Layout.BALL_START_SPEED = 8 -- 생길 때 아래로 미는 속도
Layout.BALL_MAX_SPEED = 28 -- 내리막에서 너무 빨라지지 않게 자르는 속도
Layout.BALL_HIT_EXTRA = 1.5 -- 공 반지름 + 이만큼 안에 HumanoidRootPart가 들어오면 맞은 거예요
Layout.KNOCKDOWN_DURATION = 1 -- 넘어져 있는 시간
Layout.KNOCKDOWN_COOLDOWN = 1.5 -- 같은 플레이어가 다시 넘어질 수 있기까지 (맞은 순간부터)

-- 코스 전체 길이 (출발 끝 ~ 끝 벽)
function Layout.totalLength(): number
	return Layout.START.front - Layout.FINISH.back
end

function Layout.finishLineZ(): number
	return Layout.FINISH.back + Layout.FINISH_LINE_INSET
end

-- 스폰 위치 (로컬 x, z). 출발 구간 안에 6열 × 4줄.
function Layout.spawnPositions(): { { x: number, z: number } }
	local list = {}
	for row = 0, Layout.SPAWN_ROWS - 1 do
		for col = 0, Layout.SPAWN_COLUMNS - 1 do
			table.insert(list, {
				x = (col - (Layout.SPAWN_COLUMNS - 1) / 2) * Layout.SPAWN_SPACING,
				z = Layout.START.front - 2.5 - row * Layout.SPAWN_SPACING,
			})
		end
	end
	return list
end

-- 내리막 위 로컬 z에서의 바닥 높이
function Layout.slopeHeightAt(z: number): number
	local t = (Layout.SLOPE.front - z) / (Layout.SLOPE.front - Layout.SLOPE.back)
	t = math.clamp(t, 0, 1)
	return Layout.SLOPE_LOW + (Layout.SLOPE_HIGH - Layout.SLOPE_LOW) * t
end

-- 판 위 영역 판정: rel은 판 CFrame 기준 상대 좌표, sizeX/sizeZ는 판 크기.
-- 판 가운데 높이 기준으로 아래 below, 위 above 사이에 있어야 해요.
function Layout.isAbovePlate(
	relX: number,
	relY: number,
	relZ: number,
	sizeX: number,
	sizeZ: number,
	below: number,
	above: number
): boolean
	return math.abs(relX) <= sizeX / 2 and math.abs(relZ) <= sizeZ / 2 and relY >= -below and relY <= above
end

-- 간장 안 이동 속도
function Layout.soyWalkSpeed(baseWalkSpeed: number): number
	return baseWalkSpeed * Layout.SOY_SPEED_MULTIPLIER
end

-- 공이 사라져야 하는지: 오래됐거나, 내리막 아래 끝을 지나 굴러 나왔거나, 너무 아래로 떨어졌거나.
function Layout.ballExpired(age: number, localZ: number, localY: number): boolean
	return age >= Layout.BALL_LIFETIME or localZ > Layout.SLOPE.front or localY < -Layout.FALL_DEPTH
end

-- 키(플레이어 등)별 쿨다운. tryUse가 true면 지금 써도 되고, 그 시각부터 duration 동안은 false예요.
export type Cooldown = {
	tryUse: (key: any, now: number) -> boolean,
	forget: (key: any) -> (),
}

function Layout.newCooldown(duration: number): Cooldown
	local readyAt: { [any]: number } = {}
	return {
		tryUse = function(key: any, now: number): boolean
			local at = readyAt[key]
			if at ~= nil and now < at then
				return false
			end
			readyAt[key] = now + duration
			return true
		end,
		forget = function(key: any)
			readyAt[key] = nil
		end,
	}
end

return Layout
