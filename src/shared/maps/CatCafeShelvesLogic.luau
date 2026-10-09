--!strict
-- "고양이 카페 캣타워"(cat-cafe-shelves, m5-17)의 순수 로직: 오르는 틈, 장난감 공 왕복·맞음,
-- 바깥쪽(넉백) 방향, 고양이 발 일정·선반 고르기. Roblox API를 쓰지 않아서 Lune 테스트에서 바로 불러요.
-- 치수(선반·단)는 CatCafeShelvesLayout에 있어요.
--
--   Logic.climbGap(tierIndex)                   tierIndex단 안쪽 가장자리 → (tierIndex+1)단 바깥쪽 가장자리 수평 거리
--   Logic.ballOffset(shelf, t)                   t초일 때 공의 선반 축 기준(along) 위치 (사인파 왕복)
--   Logic.isHit(diff)                            along 위치 차가 BALL_HIT_RANGE 이하면 맞음
--   Logic.outwardDirection(centerX, centerZ, x, z)  중심 → (x, z) 방향 단위 벡터 (dx, dz)
--   Logic.pawInterval(t)                         t초일 때 고양이 발 경고 간격 (그레이스면 nil)
--   Logic.pickShelf(occupancy, previousKey, rng) 다음 고양이 발 대상 선반 (occupant 가중 랜덤, Top 제외, 연속 금지)
-- rng는 NextInteger(min, max)만 써요 (Random과 테스트용 가짜 rng 모두, ChefBoardLogic.pickLine과 같은 패턴).

local Layout = require(script.Parent.CatCafeShelvesLayout)

type Shelf = Layout.Shelf
type Rng = { NextInteger: (self: any, min: number, max: number) -> number }

local Logic = {}

local TAU = 2 * math.pi

-- 장난감 공
Logic.BALL_DIAMETER = 2
Logic.BALL_PERIOD = 4.5 -- 왕복 주기 (초)
Logic.BALL_HIT_EXTRA = 1.2 -- 맞음 판정 여유 (지름/2 + 이거)
Logic.BALL_HIT_RANGE = Logic.BALL_DIAMETER / 2 + Logic.BALL_HIT_EXTRA -- 2.2
Logic.BALL_KNOCK_HORIZONTAL = 14
Logic.BALL_KNOCK_UP = 6
Logic.BALL_KNOCK_HOLD = 0.1 -- LinearVelocity를 강제로 거는 시간 (초)
Logic.BALL_COOLDOWN = 1.2 -- 같은 플레이어 재피격 쿨다운 (= MoveExempt 길이)

-- 고양이 발
Logic.PAW_GRACE = 8 -- 이 전까지는 경고가 없어요
Logic.PAW_WARN_TIME = 1.1
Logic.PAW_KNOCK_HORIZONTAL = 20
Logic.PAW_KNOCK_UP = 9
Logic.PAW_KNOCK_HOLD = 0.12
Logic.PAW_MOVE_EXEMPT = 1.6

-- Layout.shelves()의 순서 = 공 위상(phase)의 기준 index (1부터, 9개). 키 → 순서를 한 번만 계산해 둬요.
local SHELF_ORDER: { [string]: number } = {}
for i, shelf in Layout.shelves() do
	SHELF_ORDER[shelf.key] = i
end
local SHELF_COUNT = #Layout.shelves()

local function phaseOf(shelf: Shelf): number
	local index = SHELF_ORDER[shelf.key] or 1
	return (index - 1) / SHELF_COUNT
end

-- tierIndex(1 또는 2)단 안쪽 가장자리(구멍 반지름) → (tierIndex+1)단 바깥쪽 가장자리까지 수평 거리.
function Logic.climbGap(tierIndex: number): number
	local outer = Layout.outerSideOf(tierIndex)
	local innerHalf = outer / 2 - Layout.SHELF_WIDTH -- 구멍 반지름(절반)
	local nextOuterHalf = Layout.outerSideOf(tierIndex + 1) / 2
	return innerHalf - nextOuterHalf
end

-- 공이 선반 밖으로 안 나가는 최대 왕복 반폭.
local function ballAmplitude(shelf: Shelf): number
	return shelf.length / 2 - Logic.BALL_DIAMETER / 2 - 0.5
end
Logic.ballAmplitude = ballAmplitude

-- t초일 때 공의 선반 축 기준(along, 선반 중심 기준) 위치. 선반마다 위상이 달라 전부 같이 움직이지 않아요.
function Logic.ballOffset(shelf: Shelf, t: number): number
	local amplitude = ballAmplitude(shelf)
	local phase = phaseOf(shelf)
	return amplitude * math.sin(TAU * (t / Logic.BALL_PERIOD + phase))
end

-- 선반 축 기준 위치 차(diff, 항상 0 이상)가 BALL_HIT_RANGE 이하면 맞은 것.
function Logic.isHit(diff: number): boolean
	return diff <= Logic.BALL_HIT_RANGE + 1e-9
end

-- 중심(centerX, centerZ)에서 (x, z) 쪽으로 향하는 단위 벡터 (dx, dz). 정확히 중심이면(거리 0)
-- 에러 없이 고정된 기본 방향(0, -1, 로컬 -Z 쪽)을 돌려줘요.
function Logic.outwardDirection(centerX: number, centerZ: number, x: number, z: number): (number, number)
	local dx, dz = x - centerX, z - centerZ
	local magnitude = math.sqrt(dx * dx + dz * dz)
	if magnitude < 1e-6 then
		return 0, -1
	end
	return dx / magnitude, dz / magnitude
end

-- t초일 때 고양이 발 경고 간격. 그레이스(PAW_GRACE 전)에는 nil.
function Logic.pawInterval(t: number): number?
	if t < Logic.PAW_GRACE then
		return nil
	elseif t < 25 then
		return 5
	elseif t < 45 then
		return 3.2
	end
	return 2
end

-- 다음 고양이 발 대상 선반 키. occupancy = { [shelfKey] = 그 순간 선반 위 인원 }.
-- occupant가 0인 선반·"Top"(3단, 꼭대기는 고양이 발 대상에서 빠져요)·previousKey(바로 전 선반)는 후보에서 빼고,
-- 남은 후보 중 occupant 수로 가중 랜덤. 후보가 없으면(occupant 0이거나 previousKey뿐) nil.
function Logic.pickShelf(occupancy: { [string]: number }, previousKey: string?, rng: Rng): string?
	local candidates: { string } = {}
	local weights: { number } = {}
	local total = 0
	for _, shelf in Layout.shelves() do
		if shelf.side == "Top" then
			continue
		end
		local count = occupancy[shelf.key] or 0
		if count > 0 and shelf.key ~= previousKey then
			table.insert(candidates, shelf.key)
			table.insert(weights, count)
			total += count
		end
	end
	if total == 0 then
		return nil
	end
	local roll = rng:NextInteger(1, total)
	for index, key in candidates do
		roll -= weights[index]
		if roll <= 0 then
			return key
		end
	end
	return candidates[#candidates]
end

return Logic
