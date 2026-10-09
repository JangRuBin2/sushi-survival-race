--!strict
-- "줄다리기 발판"(m5-18) 치수·튜닝 값 (Roblox API 없음). TugOfWarPlatform.build가 이 표대로 짓고,
-- tests/map-tug-of-war-platform.spec.luau가 치수 약속을 확인해요. 수치는 전부 기본값이에요 (플레이테스트로 조정).
--
-- 좌표는 origin 기준 로컬 studs예요. x: 발판 길이 축(왼쪽 음수 · 오른쪽 양수, 기울기 축에서 먼 쪽),
-- z: 발판 폭 축(발판 중심은 CENTER_Z), y: 위(발판 윗면 = origin 높이, 기울지 않았을 때).
-- 발판은 origin 기준 (0, 0, CENTER_Z) 지점을 축으로 로컬 Z축만 돌아요(시소).

local Layout = {}

Layout.CENTER_Z = -40 -- 발판 중심 (origin 앞쪽, 기존 Final 맵과 같은 배치 거리)
Layout.LENGTH = 70 -- 로컬 X축 길이
Layout.WIDTH = 22 -- 로컬 Z축 폭
Layout.THICKNESS = 2
Layout.HALF_LENGTH = Layout.LENGTH / 2 -- 35, Logic.tilt의 "끝" 좌표
Layout.HALF_WIDTH = Layout.WIDTH / 2 -- 11

Layout.FALL_DEPTH = 25 -- origin보다 이만큼 아래로 떨어지면 탈락 (origin은 기울어도 고정 기준)
Layout.FRICTION = 0.35 -- CustomPhysicalProperties. 그 외(밀도·탄성 등)는 SmoothPlastic 기본값 유지

Layout.SPAWN_Y = 0.1 -- 발판 윗면 위 (스폰 전용, 평평한 초기 상태 기준)

-- 스폰 24개: 왼쪽 12 · 오른쪽 12, 6열(길이 축) × 2줄(폭 축) 격자.
Layout.SPAWN_COLUMNS = 6
Layout.SPAWN_ROWS = 2
Layout.SPAWN_INNER_MARGIN = 5 -- 중심에서 가장 가까운 열까지 거리
Layout.SPAWN_COLUMN_SPACING = 5 -- 열 사이 (길이 축)
Layout.SPAWN_ROW_SPACING = 8 -- 줄 사이 (폭 축)

-- origin 기준 (x, z)가 발판 판정면 위인지.
function Layout.onPlatform(x: number, z: number): boolean
	return math.abs(x) <= Layout.HALF_LENGTH and math.abs(z - Layout.CENTER_Z) <= Layout.HALF_WIDTH
end

-- 스폰 위치 24개 (로컬 x, z). 앞 12개는 왼쪽(x < 0), 뒤 12개는 오른쪽(x > 0).
function Layout.spawnPositions(): { { x: number, z: number } }
	local positions = {}
	for side = -1, 1, 2 do
		for row = 0, Layout.SPAWN_ROWS - 1 do
			for col = 0, Layout.SPAWN_COLUMNS - 1 do
				local x = side * (Layout.SPAWN_INNER_MARGIN + col * Layout.SPAWN_COLUMN_SPACING)
				local z = Layout.CENTER_Z + (row - (Layout.SPAWN_ROWS - 1) / 2) * Layout.SPAWN_ROW_SPACING
				table.insert(positions, { x = x, z = z })
			end
		end
	end
	return positions
end

return Layout
