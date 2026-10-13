--!strict
-- 얼음 위 관성 이동의 순수 계산 (m5-06 디저트 냉장고, GDD 5.3). Roblox API를 쓰지 않아요.
-- 클라이언트 IceController가 매 프레임 지금 실제 수평 속도(current)에서 출발해 입력 목표(target)로 천천히 다가가요.
--   입력이 있으면  current + (target - current) * (1 - e^(-ACCEL * dt))   (ACCEL 2.5: 약 0.9초에 목표의 90%)
--   입력이 없으면  current * e^(-DRAG * dt)                                (DRAG 1.0: 걷기 16에서 약 16 studs 미끄러짐)
-- 결과 크기는 max(|current|, walkSpeed)를 넘지 않아요 — 얼음은 속도를 늘리지 않아요(이동 감시 상한과 무관).
-- 수직 속도는 여기서 다루지 않아요 (x, z만).

export type Vec2 = { x: number, z: number }

local IceLogic = {}

IceLogic.TAG = "Ice" -- 이 태그가 달린 바닥 위에서만 얼음 모드
IceLogic.ACCEL = 2.5
IceLogic.DRAG = 1.0
IceLogic.RAY_LENGTH = 4.5 -- HumanoidRootPart에서 아래로 이만큼 레이캐스트
IceLogic.INPUT_EPSILON = 1e-3 -- 목표 속도 크기가 이보다 작으면 입력 없음

local function magnitude(v: Vec2): number
	return math.sqrt(v.x * v.x + v.z * v.z)
end

-- 땅에 닿아 있고 발밑 파츠가 Ice 태그일 때만 얼음 모드
function IceLogic.isIceMode(grounded: boolean, floorIsIce: boolean): boolean
	return grounded and floorIsIce
end

function IceLogic.step(current: Vec2, target: Vec2, dt: number, walkSpeed: number): Vec2
	if dt <= 0 then
		return { x = current.x, z = current.z }
	end
	local nextX, nextZ
	if magnitude(target) > IceLogic.INPUT_EPSILON then
		local k = 1 - math.exp(-IceLogic.ACCEL * dt)
		nextX = current.x + (target.x - current.x) * k
		nextZ = current.z + (target.z - current.z) * k
	else
		local k = math.exp(-IceLogic.DRAG * dt)
		nextX = current.x * k
		nextZ = current.z * k
	end
	local limit = math.max(magnitude(current), walkSpeed)
	local size = math.sqrt(nextX * nextX + nextZ * nextZ)
	if size > limit and size > 0 then
		local scale = limit / size
		nextX *= scale
		nextZ *= scale
	end
	return { x = nextX, z = nextZ }
end

return IceLogic
