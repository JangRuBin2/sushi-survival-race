--!strict
-- "라멘 국물 급류"(m4-04)의 순수 로직: 차슈 높이, 젓가락 막대 각도·맞음, 급류 밀기 벡터, 낙하선, 진행도.
-- Roblox API를 쓰지 않아서 Lune 테스트에서 그대로 불러요. 치수는 RamenRapidsLayout에 있어요.
-- 좌표는 origin 기준 로컬 (x: 오른쪽 +, y: 위, z: 결승 쪽이 -)이에요.

local Layout = require(script.Parent.RamenRapidsLayout)
local SkewerLogic = require(script.Parent.SkewerShowdownLogic)

local Logic = {}

local TAU = 2 * math.pi

export type Push = { side: number, forward: number } -- side: 로컬 +X 쪽 속도, forward: 로컬 -Z 쪽 속도
export type Platform = { kind: "Chashu" | "Naruto", index: number, x: number, z: number, radius: number }

-- 차슈 index의 윗면 높이 (t초 뒤). 수면 + LOW ~ 수면 + LOW + RANGE를 주기 PERIOD로 오르내려요.
-- t = 0에서 위상 0이면 가장 높아요.
function Logic.chashuHeight(index: number, t: number): number
	local chashu = Layout.CHASHUS[index]
	assert(chashu, `unknown chashu {index}`)
	local wave = math.cos(TAU * (t / Layout.CHASHU_PERIOD + chashu.phase)) -- 1 = 가장 높음, -1 = 가장 낮음
	local mid = Layout.BROTH_Y + Layout.CHASHU_LOW + Layout.CHASHU_RANGE / 2
	return mid + wave * Layout.CHASHU_RANGE / 2
end

-- 잠김: 윗면이 수면 아래. 잠긴 차슈는 밟을 수 없어요 (서버가 CanCollide를 꺼요).
function Logic.chashuSubmerged(index: number, t: number): boolean
	return Logic.chashuHeight(index, t) < Layout.BROTH_Y
end

-- 젓가락 막대 index의 각도 (라디안, SkewerShowdownLogic과 같은 기준: CFrame.Angles(0, θ, 0)의 X축 방향)
function Logic.sweeperAngle(index: number, t: number): number
	local sweeper = Layout.SWEEPER_LIST[index]
	assert(sweeper, `unknown sweeper {index}`)
	return sweeper.startAngle + math.rad(sweeper.speed) * t
end

-- 막대 맞음 판정용 치수 (SkewerShowdownLogic.SkewerSpec)
function Logic.sweeperSpec(): SkewerLogic.SkewerSpec
	return {
		height = Layout.SWEEPER_CENTER,
		radius = Layout.SWEEPER_THICKNESS / 2,
		innerReach = Layout.HUB_DIAMETER / 2,
		outerReach = Layout.PLATFORM_DIAMETER / 2,
	}
end

-- 이번 프레임에 막대가 from → to로 돌면서 이 캐릭터에 닿았는지.
-- dx, dz: 발판 중심 기준 HumanoidRootPart 수평 위치, rootY: 발판 윗면 기준 높이.
function Logic.sweeperHit(dx: number, dz: number, rootY: number, from: number, to: number): boolean
	return SkewerLogic.isHit(dx, dz, rootY, from, to, Logic.sweeperSpec())
end

-- 소용돌이 안이면 그 번호, 아니면 nil
function Logic.whirlpoolAt(x: number, z: number): number?
	local radius = Layout.WHIRLPOOL_DIAMETER / 2
	for i, pool in Layout.WHIRLPOOLS do
		local dx, dz = x - pool.x, z - pool.z
		if dx * dx + dz * dz <= radius * radius then
			return i
		end
	end
	return nil
end

-- 급류(Broth) 위 (x, z)에서 미는 목표 속도. 앞으로 BROTH_PUSH_SPEED(20),
-- 소용돌이 안이면 앞은 WHIRLPOOL_FORWARD_SPEED(14)로 줄고 그 소용돌이 쪽 벽으로 10.
function Logic.pushVector(x: number, z: number): Push
	local pool = Logic.whirlpoolAt(x, z)
	if pool then
		local poolX = Layout.WHIRLPOOLS[pool].x
		return {
			side = (if poolX >= 0 then 1 else -1) * Layout.WHIRLPOOL_PUSH_SPEED,
			forward = math.min(Layout.BROTH_PUSH_SPEED, Layout.WHIRLPOOL_FORWARD_SPEED),
		}
	end
	return { side = 0, forward = Layout.BROTH_PUSH_SPEED }
end

-- 수평 속도 speed, 위 속도 upSpeed로 출발해서 drop만큼 아래 바닥에 닿을 때까지 가는 수평 거리
function Logic.landingDistance(speed: number, upSpeed: number, drop: number, gravity: number): number
	local airtime = (upSpeed + math.sqrt(upSpeed * upSpeed + 2 * gravity * drop)) / gravity
	return speed * airtime
end

-- 한 축 밀기: 지금 그 축 속도(current)를 목표(target) 쪽으로 이번 프레임에 더할 양.
-- 이미 목표보다 빠르면(같은 방향) 더하지 않아요. 반대로 줄이지도 않아요 (플레이어가 거슬러 갈 수 있게).
function Logic.pushDelta(current: number, target: number, accel: number, dt: number): number
	if target > 0 and current < target then
		return math.min(accel * dt, target - current)
	elseif target < 0 and current > target then
		return math.max(-accel * dt, target - current)
	end
	return 0
end

-- 로컬 z 구간의 바닥 높이 (C 구간은 바닥이 없어서 고정 발판인 나루토 윗면 = 회전 발판과 같은 높이)
function Logic.floorAt(z: number): number
	if z > Layout.RAPIDS.front then
		return 0
	elseif z > Layout.RAPIDS.back then
		return Layout.rapidsHeightAt(z)
	elseif z > Layout.TOPPINGS.back then
		return Layout.narutoTop()
	end
	return Layout.platformTop()
end

-- 이 높이(로컬 y)보다 아래면 탈락
function Logic.fallLineAt(z: number): number
	return Logic.floorAt(z) - Layout.FALL_MARGIN
end

-- 진행도 (로컬 -Z). 시간 종료 때 순위도 이 축이에요.
function Logic.progress(z: number): number
	return -z
end

function Logic.finishProgress(): number
	return Logic.progress(Layout.finishLineZ())
end

-- 토핑 구간의 발판 목록 (차슈 + 나루토)
function Logic.platforms(): { Platform }
	local list: { Platform } = {}
	for i, chashu in Layout.CHASHUS do
		local platform: Platform =
			{ kind = "Chashu", index = i, x = chashu.x, z = chashu.z, radius = Layout.CHASHU_DIAMETER / 2 }
		table.insert(list, platform)
	end
	for i, naruto in Layout.NARUTOS do
		local platform: Platform =
			{ kind = "Naruto", index = i, x = naruto.x, z = naruto.z, radius = Layout.NARUTO_DIAMETER / 2 }
		table.insert(list, platform)
	end
	return list
end

-- 원판 둘 사이 가로 빈틈 (겹치면 0)
function Logic.discGap(ax: number, az: number, ar: number, bx: number, bz: number, br: number): number
	local dx, dz = ax - bx, az - bz
	return math.max(0, math.sqrt(dx * dx + dz * dz) - ar - br)
end

-- 급류 끝에서 건너기 시작하는 곳 = 착지판 끝(z = LANDING.back, |x| <= 폭/2)에서 원판까지 빈틈
function Logic.gapFromRapids(x: number, z: number, radius: number): number
	local half = Layout.LANDING.width / 2
	local nearX = math.clamp(x, -half, half)
	local dx, dz = x - nearX, Layout.LANDING.back - z
	if dz < 0 then
		dz = 0
	end
	return math.max(0, math.sqrt(dx * dx + dz * dz) - radius)
end

-- 원판에서 첫 회전 발판까지 빈틈
function Logic.gapToSweeperPlatform(x: number, z: number, radius: number): number
	local first = Layout.SWEEPER_LIST[1]
	return Logic.discGap(x, z, radius, 0, first.z, Layout.PLATFORM_DIAMETER / 2)
end

-- t초에 밟을 수 있는 발판인지 (나루토는 항상, 차슈는 잠기지 않았을 때)
function Logic.platformUp(platform: Platform, t: number): boolean
	return platform.kind == "Naruto" or not Logic.chashuSubmerged(platform.index, t)
end

-- t초에 급류 끝 → 회전 발판까지 MAX_JUMP_GAP 이하 빈틈으로 이어진 발판 사슬 (없으면 nil). AC2.
function Logic.crossingPath(t: number): { Platform }?
	local all = Logic.platforms()
	local up: { Platform } = {}
	for _, platform in all do
		if Logic.platformUp(platform, t) then
			table.insert(up, platform)
		end
	end
	local maxGap = Layout.MAX_JUMP_GAP
	local cameFrom: { [Platform]: Platform | boolean } = {}
	local queue: { Platform } = {}
	for _, platform in up do
		if Logic.gapFromRapids(platform.x, platform.z, platform.radius) <= maxGap then
			cameFrom[platform] = true
			table.insert(queue, platform)
		end
	end
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		if Logic.gapToSweeperPlatform(current.x, current.z, current.radius) <= maxGap then
			local path = { current }
			local previous = cameFrom[current]
			while type(previous) == "table" do
				table.insert(path, 1, previous)
				previous = cameFrom[previous]
			end
			return path
		end
		for _, other in up do
			if
				cameFrom[other] == nil
				and Logic.discGap(current.x, current.z, current.radius, other.x, other.z, other.radius) <= maxGap
			then
				cameFrom[other] = current
				table.insert(queue, other)
			end
		end
	end
	return nil
end

return Logic
