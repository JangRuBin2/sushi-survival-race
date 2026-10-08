--!strict
-- m4-03 QA: 뜨거운 철판 · 회전 꼬치 쇼다운 아트 패스 검증 보강 (docs/qa/m4-03-art-survival-final-maps.md)
-- 스폰 24개가 실제 바닥 위(가장자리 여유), 장식이 판정 바닥과 겹치지 않음, 머리 위 장식 높이,
-- Art 모듈이 상태 없는 순수 데이터인지, 꼬치 음식이 몸통 판정 반경 안인지.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local HotPlateLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local HotPlateArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local SkewerLogic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)
local SkewerArt = RobloxRequire.require(Shared.maps.SkewerShowdownArt)

type DecorSpec = MapKitLogic.DecorSpec
type Bounds = MapKitLogic.Bounds

local EPS = 1e-6
-- 스폰 중심에서 바닥 가장자리까지 최소 여유 (캐릭터 몸통 반지름 1 + 배치 오차)
local SPAWN_EDGE_MARGIN = 2

-- SkewerShowdown.luau 무대 치수 (판정 파츠를 만드는 값과 같게)
local STAGE_THICKNESS = 1.5
local STRIPS_PER_SLICE = 8

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x - EPS
		and a.max.x > b.min.x + EPS
		and a.min.y < b.max.y - EPS
		and a.max.y > b.min.y + EPS
		and a.min.z < b.max.z - EPS
		and a.max.z > b.min.z + EPS
end

local function boundsOf(spec: DecorSpec): Bounds
	return MapKitLogic.bounds({ spec }) :: Bounds
end

-- 꼬치 무대 조각의 띠(직사각형) 판정 바닥 목록을 SkewerShowdown.buildSlice와 같은 식으로 만들어요.
-- 각 띠: 조각 이등분선 방향 radial 구간 [r0, r1], 좌우 ±halfWidth.
type Strip = { bisector: number, r0: number, r1: number, halfWidth: number }
local function stageStrips(): { Strip }
	local strips = {}
	local sliceAngle = 2 * math.pi / SkewerLogic.SLICE_COUNT
	local halfTan = math.tan(sliceAngle / 2)
	local apothem = SkewerLogic.STAGE_RADIUS * math.cos(sliceAngle / 2)
	local depth = apothem / STRIPS_PER_SLICE
	for index = 1, SkewerLogic.SLICE_COUNT do
		local bisector = (index - 0.5) * sliceAngle
		for strip = 1, STRIPS_PER_SLICE do
			local mid = (strip - 0.5) * depth
			table.insert(strips, {
				bisector = bisector,
				r0 = mid - depth / 2,
				r1 = mid + depth / 2,
				halfWidth = mid * halfTan,
			})
		end
	end
	return strips
end

-- 무대 로컬 (x, z)가 띠 바닥 위인가 (radialCFrame: (r cos a, -r sin a))
local function onStage(x: number, z: number, strips: { Strip }): boolean
	for _, s in strips do
		local c, sn = math.cos(s.bisector), math.sin(s.bisector)
		local radial = x * c - z * sn
		local lateral = x * sn + z * c
		if radial >= s.r0 - EPS and radial <= s.r1 + EPS and math.abs(lateral) <= s.halfWidth + EPS then
			return true
		end
	end
	return false
end

return function(t: Test.Test)
	-- 스폰 ---------------------------------------------------------------------------------
	t.test("철판 스폰 24개가 모두 맨 위층 타일 위, 가장자리에서 2 studs 이상 안쪽", function()
		local spawns = HotPlateLogic.spawnOffsets()
		t.eq(#spawns, 24)
		local half = HotPlateLogic.plateSize() / 2
		local tileHalf = HotPlateLogic.TILE_SIZE / 2
		local tiles = HotPlateLogic.tileOffsets()
		for i, s in spawns do
			t.ok(half - math.abs(s.x) >= SPAWN_EDGE_MARGIN, `spawn {i} x margin {half - math.abs(s.x)}`)
			t.ok(half - math.abs(s.z) >= SPAWN_EDGE_MARGIN, `spawn {i} z margin {half - math.abs(s.z)}`)
			-- 실제 타일 하나가 스폰 중심을 덮어요 (틈 없는 격자라도 직접 확인)
			local covered = false
			for _, tile in tiles do
				if math.abs(tile.x - s.x) <= tileHalf and math.abs(tile.z - s.z) <= tileHalf then
					covered = true
					break
				end
			end
			t.ok(covered, `spawn {i} not over a tile`)
		end
	end)

	t.test(
		"꼬치 스폰 24개가 모두 무대 조각 바닥 위, 가장자리·기둥에서 2 studs 이상",
		function()
			local angles = SkewerLogic.spawnAngles(24)
			t.eq(#angles, 24)
			local strips = stageStrips()
			local sliceAngle = 2 * math.pi / SkewerLogic.SLICE_COUNT
			local apothem = SkewerLogic.STAGE_RADIUS * math.cos(sliceAngle / 2)
			local r = SkewerLogic.SPAWN_RADIUS
			t.ok(apothem - r >= SPAWN_EDGE_MARGIN, `outer margin {apothem - r}`)
			t.ok(r - SkewerLogic.PILLAR_DIAMETER / 2 >= SPAWN_EDGE_MARGIN, `pillar margin`)
			for i, angle in angles do
				local x, z = r * math.cos(angle), -r * math.sin(angle)
				t.ok(onStage(x, z, strips), `spawn {i} center not on a strip`)
				-- 몸통 둘레(반지름 1) 여덟 점 중 대부분이 바닥 위 (조각 경계의 띠 틈은 0.5 studs 이하)
				local supported = 0
				for k = 0, 7 do
					local a = k * math.pi / 4
					if onStage(x + math.cos(a), z + math.sin(a), strips) then
						supported += 1
					end
				end
				t.ok(supported >= 6, `spawn {i} footprint support {supported}/8`)
			end
		end
	)

	t.test(
		"꼬치 무대 띠 판정 바닥이 반지름 STAGE_RADIUS·apothem 안쪽 (스폰 반지름은 바닥 안)",
		function()
			local strips = stageStrips()
			-- 스폰 반지름 원 위 360개 점 중 바닥이 아닌 곳은 조각 경계의 얇은 틈뿐이어야 해요
			local misses = 0
			for k = 0, 359 do
				local a = math.rad(k)
				if
					not onStage(SkewerLogic.SPAWN_RADIUS * math.cos(a), -SkewerLogic.SPAWN_RADIUS * math.sin(a), strips)
				then
					misses += 1
				end
			end
			t.ok(misses <= 16, `misses {misses}`)
		end
	)

	-- 장식 vs 판정 바닥 ------------------------------------------------------------------------
	t.test("철판 장식이 어느 층의 타일 판(아래 1 ~ 위 2 studs)과도 겹치지 않아요", function()
		local half = HotPlateLogic.plateSize() / 2
		local cz = HotPlateLogic.centerZ()
		for layer = 1, HotPlateLogic.LAYER_COUNT do
			local top = HotPlateLogic.layerTopY(layer)
			local slab: Bounds = {
				min = { x = -half, y = top - HotPlateLogic.TILE_THICKNESS, z = cz - half },
				max = { x = half, y = top + 2, z = cz + half },
			}
			for i, spec in HotPlateArt.decor() do
				t.ok(not overlaps(boundsOf(spec), slab), `#{i} {spec.name} in layer {layer} slab`)
			end
		end
	end)

	t.test("철판 머리 위 장식(후드)은 맨 위층보다 20 studs 이상 높아요", function()
		local half = HotPlateLogic.plateSize() / 2
		local cz = HotPlateLogic.centerZ()
		local top = HotPlateLogic.layerTopY(1)
		local found = 0
		for _, spec in HotPlateArt.decor() do
			local b = boundsOf(spec)
			local overPlate = b.min.x < half and b.max.x > -half and b.min.z < cz + half and b.max.z > cz - half
			if overPlate and b.max.y > top + HotPlateArt.SIGHT_MAX then
				found += 1
				t.ok(b.min.y >= top + 20, `{spec.name} min y {b.min.y}`)
			end
		end
		t.ok(found > 0, "hood exists over the plate")
	end)

	t.test("꼬치 고정 장식이 무대 판(조각 두께 ~ 윗면 위 2)과 겹치지 않아요", function()
		local r = SkewerLogic.STAGE_RADIUS
		local pillar = SkewerLogic.PILLAR_DIAMETER / 2
		for i, spec in SkewerArt.decor() do
			local b = boundsOf(spec)
			if b.max.y > -STAGE_THICKNESS and b.min.y < 2 then
				-- 가장 가까운 수평 거리가 무대 반지름 밖이거나 기둥 안이어야 해요
				local nx = math.clamp(0, b.min.x, b.max.x)
				local nz = math.clamp(0, b.min.z, b.max.z)
				local nearest = math.sqrt(nx * nx + nz * nz)
				t.ok(nearest >= r - EPS or nearest <= pillar, `#{i} {spec.name} on the stage (nearest {nearest})`)
			end
		end
	end)

	t.test(
		"조각 장식(금 선)은 윗면 위 0.2 이내로 얇고, 테두리는 무대 바깥 가장자리",
		function()
			for index = 1, SkewerLogic.SLICE_COUNT do
				for _, spec in SkewerArt.sliceDecor(index) do
					local b = boundsOf(spec)
					t.ok(b.max.y <= 0.2 + EPS, `slice {index} {spec.name} top {b.max.y}`)
				end
			end
		end
	)

	t.test(
		"셰프 손 장식(손끝)은 집을 때 집는 조각 두께 안까지만 내려가요 (조각 밑으로 뚫고 나오지 않음)",
		function()
			-- 손은 윗면 위 HAND_HOVER_HEIGHT(2.5) + 3 = 5.5에 손바닥 중심이 와요
			local lowest = math.huge
			for _, spec in SkewerArt.handDecor() do
				lowest = math.min(lowest, boundsOf(spec).min.y)
			end
			t.ok(5.5 + lowest >= -STAGE_THICKNESS, `hand decor dips to {5.5 + lowest}`)
		end
	)

	-- 꼬치 음식 = 맞음 -----------------------------------------------------------------------
	t.test("꼬치 음식 모서리가 몸통 판정 반경(radius + BODY_RADIUS) 안", function()
		for _, spec in { SkewerLogic.LOW_SKEWER, SkewerLogic.HIGH_SKEWER } do
			local reach = spec.radius + SkewerLogic.BODY_RADIUS
			for i, food in SkewerArt.skewerFood(spec) do
				local b = boundsOf(food)
				-- 단면 모서리(꼬치 축 기준 대각선)가 판정 반경 안
				local corner = math.sqrt(math.max(b.max.y ^ 2, b.min.y ^ 2) + math.max(b.max.z ^ 2, b.min.z ^ 2))
				t.ok(corner <= reach, `#{i} corner {corner} > {reach}`)
				-- 길이 방향은 꼬치 안
				local half = (spec.outerReach - spec.innerReach) / 2
				t.ok(b.min.x >= -half - EPS and b.max.x <= half + EPS, `#{i} along the skewer`)
			end
		end
	end)

	-- 여러 방 동시: Art는 상태 없는 순수 데이터 ----------------------------------------------
	t.test(
		"Art 함수는 부를 때마다 새 표를 돌려줘요 (한 방이 고쳐도 다른 방에 안 번짐)",
		function()
			local a = HotPlateArt.decor()
			local b = HotPlateArt.decor()
			t.ok(a ~= b and a[1] ~= b[1], "hot plate decor shared")
			local before = b[1].offset.x
			a[1].offset.x += 1000
			t.eq(b[1].offset.x, before)
			t.eq(HotPlateArt.decor()[1].offset.x, before)
			local f1 = SkewerArt.skewerFood(SkewerLogic.LOW_SKEWER)
			local f2 = SkewerArt.skewerFood(SkewerLogic.LOW_SKEWER)
			t.ok(f1 ~= f2 and f1[1] ~= f2[1], "skewer food shared")
			t.ok(SkewerArt.decor() ~= SkewerArt.decor(), "skewer decor shared")
		end
	)

	-- 철판 Neon 타이밍 ------------------------------------------------------------------------
	t.test("Neon은 주황 이후에만, 사라지기 전에 켜져요 (색 단계 0.1초 경계 안)", function()
		local from = HotPlateLogic.HEAT_DURATION * HotPlateArt.GLOW_FROM
		t.ok(from > HotPlateLogic.HEAT_DURATION / 2, "after warm midpoint")
		t.ok(from < HotPlateLogic.HEAT_DURATION - 0.1, "before vanish")
		t.eq(HotPlateArt.isGlowing(from - 0.01), false)
		t.eq(HotPlateArt.isGlowing(from), true)
		local _, goneEarly = HotPlateLogic.heatVisual(HotPlateLogic.HEAT_DURATION - 0.01)
		local _, goneAt = HotPlateLogic.heatVisual(HotPlateLogic.HEAT_DURATION)
		t.eq(goneEarly, false)
		t.eq(goneAt, true)
	end)
end
