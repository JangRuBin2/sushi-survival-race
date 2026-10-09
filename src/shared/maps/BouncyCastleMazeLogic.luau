--!strict
-- "방방 미로"의 순수 판정 로직 (m5-14). Roblox API를 쓰지 않아서 Lune 테스트에서 바로 불러요.
--   Logic.blockedAt(x, z, partitions, gate, bounds)  격자 한 점이 벽(칸막이·관문·바깥 벽) 안인지
--   Logic.bounceProfile(upSpeed, gravity)            위 속도만의 포물선: 최고 높이·비행 시간
--   Logic.fallLineAt(z)                               낙하 판정선(origin 기준 로컬 y). 전 구간 동일 상수
-- 치수 데이터(칸막이·관문·레인 위치 등)는 BouncyCastleMazeLayout에 있어요. 이 모듈은 그 데이터를 받아
-- 계산만 해요 (여러 방이 같은 맵을 동시에 돌려도 상태를 안 가지니 섞이지 않아요).

local Layout = require(script.Parent.BouncyCastleMazeLayout)

local Logic = {}

export type BounceProfile = { apex: number, flightTime: number }

-- 격자 판정: (x, z)가 벽(칸막이·관문·바깥 벽) 안이면 true. 1 stud 플러드필 테스트가 이걸로 길을 찾아요.
function Logic.blockedAt(
	x: number,
	z: number,
	partitions: { Layout.Partition },
	gate: Layout.Gate,
	bounds: Layout.Bounds
): boolean
	if x <= bounds.xMin or x >= bounds.xMax then
		return true
	end
	if math.abs(z - gate.z) <= gate.thickness / 2 then
		if x < gate.openXMin or x > gate.openXMax then
			return true
		end
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
