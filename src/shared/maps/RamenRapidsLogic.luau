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

-- ── m5-40 길이 늘리기 ─────────────────────────────────────────────────
export type Stick = { x0: number, z0: number, x1: number, z1: number } -- 젓가락 윗면 가운데 선 (앞 끝 → 뒤 끝)
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number, top: number }
export type Link = { from: string, to: string, gap: number, rise: number }

-- F 젓가락 다리의 젓가락 4개 (첫 쌍 2 + X자 둘째 쌍 2)
function Logic.chopsticks(): { Stick }
	local list: { Stick } = {}
	local p1 = Layout.CHOP_PAIR1
	for _, x in p1.xs do
		table.insert(list, { x0 = x, z0 = p1.front, x1 = x, z1 = p1.back })
	end
	local p2 = Layout.CHOP_PAIR2
	for _, side in { -1, 1 } do
		table.insert(list, { x0 = side * p2.spread, z0 = p2.front, x1 = -side * p2.spread, z1 = p2.back })
	end
	return list
end

-- 렌게 발판 i의 윗면 직사각형
function Logic.rengeRect(i: number): Rect
	local step = Layout.RENGE_STEPS[i]
	assert(step, `unknown renge step {i}`)
	return {
		minX = step.x - step.width / 2,
		maxX = step.x + step.width / 2,
		minZ = step.back,
		maxZ = step.front,
		top = Layout.rengeStepTop(i),
	}
end

-- 두 직사각형 사이 가로 빈틈 (겹치거나 닿으면 0)
function Logic.rectGap(a: Rect, b: Rect): number
	local dx = math.max(0, b.minX - a.maxX, a.minX - b.maxX)
	local dz = math.max(0, b.minZ - a.maxZ, a.minZ - b.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- 젓가락 끝 점(윗면 반폭 포함)에서 직사각형까지 가로 빈틈
local function stickEndGap(x: number, z: number, rect: Rect): number
	local half = Layout.CHOPSTICK_WIDTH / 2
	local endRect: Rect = { minX = x - half, maxX = x + half, minZ = z, maxZ = z, top = Layout.platformTop() }
	return Logic.rectGap(endRect, rect)
end

-- 새 구간(F·G·H)을 지나는 길의 이음매 목록 (m5-40 AC1 길 약속): 마지막 회전 원판 → 유부 뗏목 → 젓가락 첫 쌍 →
-- 받침 → X자 둘째 쌍 → 렌게 1~4 → 두 번째 급류 → 결승. gap: 가로 빈틈, rise: 다음 발판이 높은 만큼.
function Logic.newSectionLinks(): { Link }
	local top = Layout.platformTop()
	local links: { Link } = {}
	local function link(from: string, to: string, gap: number, rise: number)
		table.insert(links, { from = from, to = to, gap = gap, rise = rise })
	end
	local raft = Layout.CHOP_RAFT
	local raftRect: Rect =
		{ minX = -raft.width / 2, maxX = raft.width / 2, minZ = raft.back, maxZ = raft.front, top = top }
	-- 원판 뒤 끝(z - 반지름)이 뗏목 앞 끝보다 뒤면 겹쳐요
	local last = Layout.SWEEPER_LIST[#Layout.SWEEPER_LIST]
	local discBack = last.z - Layout.PLATFORM_DIAMETER / 2
	link("SweeperPlatform", "ChopRaft", math.max(0, discBack - raft.front), 0)
	local p1, rest = Layout.CHOP_PAIR1, Layout.CHOP_REST
	local restRect: Rect =
		{ minX = -rest.width / 2, maxX = rest.width / 2, minZ = rest.back, maxZ = rest.front, top = top }
	local sticks = Logic.chopsticks()
	for i = 1, #p1.xs do
		local s = sticks[i]
		link("ChopRaft", `Chopstick{i}`, stickEndGap(s.x0, s.z0, raftRect), 0)
		link(`Chopstick{i}`, "ChopRest", stickEndGap(s.x1, s.z1, restRect), 0)
	end
	local first = Logic.rengeRect(1)
	for i = #p1.xs + 1, #sticks do
		local s = sticks[i]
		link("ChopRest", `Chopstick{i}`, stickEndGap(s.x0, s.z0, restRect), 0)
		link(`Chopstick{i}`, "Renge1", stickEndGap(s.x1, s.z1, first), first.top - top)
	end
	for i = 2, #Layout.RENGE_STEPS do
		local a, b = Logic.rengeRect(i - 1), Logic.rengeRect(i)
		link(`Renge{i - 1}`, `Renge{i}`, Logic.rectGap(a, b), b.top - a.top)
	end
	local lastStep = Logic.rengeRect(#Layout.RENGE_STEPS)
	link(
		`Renge{#Layout.RENGE_STEPS}`,
		"Rapids2",
		math.max(0, lastStep.minZ - Layout.RAPIDS2.front),
		Layout.rapids2HeightAt(Layout.RAPIDS2.front) - lastStep.top
	)
	link("Rapids2", "Finish", math.max(0, Layout.FINISH.front - Layout.RAPIDS2.back), 0)
	return links
end

-- 빠른 사람 클리어 추정 (초): 1번 줄 스폰 → 결승선 걷기 + 구간별 지연 합 (m5-40 AC1, 42~55초)
function Logic.estimateClearTime(): number
	local startZ = Layout.START.front - 2.5
	local walk = (startZ - Layout.finishLineZ()) / Layout.WALK_SPEED
	local delay = 0
	for _, value in Layout.SECTION_DELAY do
		delay += value
	end
	return walk + delay
end

return Logic
