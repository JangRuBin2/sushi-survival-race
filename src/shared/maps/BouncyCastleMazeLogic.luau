--!strict
-- "방방 미로"의 순수 판정 로직 (m5-14). Roblox API를 쓰지 않아서 Lune 테스트에서 바로 불러요.
--   Logic.blockedAt(x, z, partitions, gate, bounds, exitGate)  격자 한 점이 벽(칸막이·관문·출구 벽·바깥 벽) 안인지
--   Logic.bounceProfile(upSpeed, gravity)            위 속도만의 포물선: 최고 높이·비행 시간
--   Logic.fallLineAt(z)                               낙하 판정선(origin 기준 로컬 y). 전 구간 동일 상수
--   Logic.courseBlockedAt(x, z, margin?)              코스 전체(두 미로·풍선 기둥) 격자 판정 (m5-40)
--   Logic.estimateClearTime()                         빠른 사람 완주 시간 추정 (m5-40)
-- 치수 데이터(칸막이·관문·레인 위치 등)는 BouncyCastleMazeLayout에 있어요. 이 모듈은 그 데이터를 받아
-- 계산만 해요 (여러 방이 같은 맵을 동시에 돌려도 상태를 안 가지니 섞이지 않아요).

local Layout = require(script.Parent.BouncyCastleMazeLayout)

local Logic = {}

export type BounceProfile = { apex: number, flightTime: number }

local function gateBlocks(x: number, z: number, gate: Layout.Gate): boolean
	return math.abs(z - gate.z) <= gate.thickness / 2 and (x < gate.openXMin or x > gate.openXMax)
end

-- 격자 판정: (x, z)가 벽(칸막이·입구 관문·출구 벽·바깥 벽) 안이면 true. 1 stud 플러드필 테스트가 이걸로
-- 길을 찾아요. 출구 벽(exitGate, m5-14 B1)은 관문과 같은 모양이라 같은 계산으로 봐요.
function Logic.blockedAt(
	x: number,
	z: number,
	partitions: { Layout.Partition },
	gate: Layout.Gate,
	bounds: Layout.Bounds,
	exitGate: Layout.Gate
): boolean
	if x <= bounds.xMin or x >= bounds.xMax then
		return true
	end
	if gateBlocks(x, z, gate) or gateBlocks(x, z, exitGate) then
		return true
	end
	for _, partition in partitions do
		if math.abs(x - partition.x) <= partition.thickness / 2 then
			if z <= partition.blockedZHigh and z >= partition.blockedZLow then
				return true
			end
		end
	end
	return false
end

-- m5-40: 코스 전체 격자 판정 — 첫 미로(blockedAt) + 두 번째 미로(칸막이 2·문 2) + 풍선 기둥(원).
-- margin만큼 벽·기둥을 두껍게 봐요(몸 반폭을 넣으면 "몸이 지나갈 수 있는 길"이 돼요). 출발 앞(z > 0)과
-- 결승 뒤(z < FINISH.back)도 막혀 있어요.
function Logic.courseBlockedAt(x: number, z: number, margin: number?): boolean
	local m = margin or 0
	if z > Layout.START.front - m or z < Layout.FINISH.back + m then
		return true
	end
	local bounds = { xMin = Layout.BOUNDS.xMin + m, xMax = Layout.BOUNDS.xMax - m }
	local function thick(gate: Layout.Gate): Layout.Gate
		return {
			z = gate.z,
			thickness = gate.thickness + 2 * m,
			openXMin = gate.openXMin + m,
			openXMax = gate.openXMax - m,
		}
	end
	local function thickPartitions(list: { Layout.Partition }): { Layout.Partition }
		local out = {}
		for _, p in list do
			table.insert(out, {
				x = p.x,
				thickness = p.thickness + 2 * m,
				blockedZHigh = p.blockedZHigh + m,
				blockedZLow = p.blockedZLow - m,
			})
		end
		return out
	end
	if
		Logic.blockedAt(x, z, thickPartitions(Layout.PARTITIONS), thick(Layout.GATE), bounds, thick(Layout.EXIT_GATE))
	then
		return true
	end
	if
		Logic.blockedAt(
			x,
			z,
			thickPartitions(Layout.MAZE2_PARTITIONS),
			thick(Layout.MAZE2_GATE),
			bounds,
			thick(Layout.MAZE2_EXIT_GATE)
		)
	then
		return true
	end
	for _, pillar in Layout.pillars() do
		local dx, dz = x - pillar.x, z - pillar.z
		local r = pillar.radius + m
		if dx * dx + dz * dz <= r * r then
			return true
		end
	end
	return false
end

-- m5-40: 빠른 사람 완주 시간 추정(초) = 구간별 걷는 길이 합 ÷ 걷기 속도 + 구간별 지연 합 (상수는 Layout).
function Logic.estimateClearTime(): number
	local walk, delay = 0, 0
	for _, name in Layout.SECTION_ORDER do
		walk += Layout.SECTION_WALK[name] or 0
		delay += Layout.SECTION_DELAY[name] or 0
	end
	return walk / Layout.WALK_SPEED + delay
end

-- 포물선 계산 (순수 물리, 공기저항 없음): apex(최고 높이), flightTime(같은 높이로 돌아오는 시간).
function Logic.bounceProfile(upSpeed: number, gravity: number): BounceProfile
	return {
		apex = upSpeed * upSpeed / (2 * gravity),
		flightTime = 2 * upSpeed / gravity,
	}
end

-- 낙하 판정선 (origin 기준 로컬 y). 전 구간 동일한 상수라 z는 받기만 하고 쓰지 않아요
-- (다른 맵의 slopeHeightAt 같은 함수와 호출 모양을 맞춰서, 구간마다 달라질 일이 생겨도 호출부를 안 바꿔도 돼요).
function Logic.fallLineAt(_z: number): number
	return -Layout.FALL_DEPTH
end

return Logic
