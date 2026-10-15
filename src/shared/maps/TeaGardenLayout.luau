--!strict
-- "찻잎 정원" (tea-garden, m5-38) 판정 상수와 지오메트리 표. Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- 좌표는 map origin(정원 중심, 가장 바깥 5단 윗면 높이 = y 0) 기준 로컬. 각도 a는 x = r·cos a, z = r·sin a.
-- 수치는 전부 스펙 기본값이에요 (docs/specs/m5-38-map-tea-garden.md "규칙"). 손맛을 바꿀 때는 여기만 고쳐요.
--   Layout.RINGS[k] = { inner, outer, top }   k = 1(가장 안·높음) ~ 5(가장 바깥·낮음)
--   Layout.ringMid(k) / Layout.polar(r, a)
--   Layout.slices(k) -> { SliceDef }          단 하나의 부채꼴 조각 12개 (상자 근사, 조각 사이 틈 0)
--   Layout.spawns() -> { SpawnDef }           3·4단 위 24개 (서로 3 이상, 정원 중심을 바라봐요)

export type Ring = { inner: number, outer: number, top: number }
export type SliceDef = {
	ring: number,
	index: number,
	angle: number, -- 이등분선 각도 (라디안)
	distance: number, -- 상자 중심까지 이등분선 거리
	depth: number, -- 반지름 방향 길이
	width: number, -- 접선 방향 길이 (바깥 현)
	height: number, -- 두께 (윗면 → BASE_Y)
	centerY: number,
}
export type SpawnDef = { x: number, y: number, z: number, yaw: number, ring: number }

local Layout = {}

Layout.ID = "tea-garden"

-- 단 표 (스펙 "무대")
Layout.RINGS = {
	{ inner = 7, outer = 15, top = 6 },
	{ inner = 15, outer = 23, top = 4.5 },
	{ inner = 23, outer = 31, top = 3 },
	{ inner = 31, outer = 39, top = 1.5 },
	{ inner = 39, outer = 47, top = 0 },
} :: { Ring }
Layout.RING_COUNT = 5
Layout.STEP = 1.5 -- 이웃 단 높이 차
Layout.SLICES = 12 -- 단마다 부채꼴 조각
Layout.SLICE_ANGLE = 2 * math.pi / 12
Layout.RADIUS = 47 -- 정원 바깥 반지름 (이 밖에는 충돌 파츠가 없어요)
Layout.BASE_Y = -6 -- 모든 단 조각의 밑면 (옆면 흙·돌 층이 보이게)

-- 가운데 찻사발 충돌 심 (보이지 않음): 반지름 7, 윗면 20 — 1단 6 + 점프 6.4보다 훨씬 높아 올라설 수 없어요
Layout.CORE_RADIUS = 7
Layout.CORE_TOP = 20
Layout.CORE_BOTTOM = Layout.BASE_Y
Layout.JUMP_HEIGHT = 6.4 -- 기본 점프 최고 높이 (근사, 스펙 표기)

Layout.FALL_DEPTH = 25 -- 로컬 y < −25면 탈락

-- 스폰: 3단(r 27)·4단(r 35)에 12개씩, 4단은 15° 어긋나게
Layout.SPAWN_RINGS = { 3, 4 }

function Layout.ringMid(ring: number): number
	local r = Layout.RINGS[ring]
	return (r.inner + r.outer) / 2
end

function Layout.polar(r: number, angle: number): (number, number)
	return r * math.cos(angle), r * math.sin(angle)
end

-- 조각 i(1~12)의 이등분선 각도
function Layout.sliceAngle(index: number): number
	return (index - 0.5) * Layout.SLICE_ANGLE
end

-- 부채꼴을 상자 하나로 근사: 폭 = 바깥 현(2·outer·sin15°), 안·바깥 면은 inner·cos15°·outer·cos15°.
-- 이웃 단의 맞닿는 면이 같은 현이라 단 사이 틈 0, 같은 단 조각끼리는 안쪽에서 겹쳐요(같은 높이·같은 색).
function Layout.slices(ring: number): { SliceDef }
	local def = Layout.RINGS[ring]
	local half = Layout.SLICE_ANGLE / 2
	local near = def.inner * math.cos(half)
	local far = def.outer * math.cos(half)
	local height = def.top - Layout.BASE_Y
	local list: { SliceDef } = {}
	for i = 1, Layout.SLICES do
		table.insert(list, {
			ring = ring,
			index = i,
			angle = Layout.sliceAngle(i),
			distance = (near + far) / 2,
			depth = far - near,
			width = 2 * def.outer * math.sin(half),
			height = height,
			centerY = def.top - height / 2,
		})
	end
	return list
end

-- 정원 중심을 바라보는 yaw (CFrame.Angles(0, yaw, 0)의 LookVector = (−sin yaw, 0, −cos yaw))
function Layout.faceCenterYaw(angle: number): number
	return math.pi / 2 - angle
end

function Layout.spawns(): { SpawnDef }
	local list: { SpawnDef } = {}
	-- 앞 번호부터 두 단·여러 방향에 흩어지게: 3단·4단을 번갈아, 각도는 5칸씩 건너뛰어요 (12와 서로소)
	for k = 0, 11 do
		local step = (k * 5) % 12
		for _, ring in Layout.SPAWN_RINGS do
			local r = Layout.ringMid(ring)
			local angle = Layout.sliceAngle(step + 1) + (if ring == 4 then Layout.SLICE_ANGLE / 2 else 0)
			local x, z = Layout.polar(r, angle)
			table.insert(list, {
				x = x,
				y = Layout.RINGS[ring].top + 0.1,
				z = z,
				yaw = Layout.faceCenterYaw(angle),
				ring = ring,
			})
		end
	end
	return list
end

return Layout
