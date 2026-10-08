--!strict
-- m4-03 맵 아트 패스: 뜨거운 철판 · 회전 꼬치 쇼다운 (docs/specs/m4-03-art-survival-final-maps.md)
-- 장식 목록 검사(AC1), 시야 상자(AC2), 꼬치 음식이 판정 상자 안(AC3), 손으로 짠 소개 카메라(AC4),
-- 파티클·조명 예산, 판정 수치 고정, 맵 소스 계약(MapKit·MoveExempt).

local fs = require("@lune/fs")

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

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x - EPS
		and a.max.x > b.min.x + EPS
		and a.min.y < b.max.y - EPS
		and a.max.y > b.min.y + EPS
		and a.min.z < b.max.z - EPS
		and a.max.z > b.min.z + EPS
end

local function concat(...: { DecorSpec }): { DecorSpec }
	local all = {}
	for _, list in { ... } do
		for _, spec in list do
			table.insert(all, spec)
		end
	end
	return all
end

local function skewerStatic(): { DecorSpec }
	local list = SkewerArt.decor()
	for index = 1, SkewerLogic.SLICE_COUNT do
		list = concat(list, SkewerArt.sliceDecor(index))
	end
	return list
end

local function skewerAll(): { DecorSpec }
	return concat(
		skewerStatic(),
		SkewerArt.skewerFood(SkewerLogic.LOW_SKEWER),
		SkewerArt.skewerFood(SkewerLogic.HIGH_SKEWER),
		SkewerArt.handDecor()
	)
end

local function countNamed(specs: { DecorSpec }, name: string): number
	local n = 0
	for _, spec in specs do
		if spec.name == name then
			n += 1
		end
	end
	return n
end

-- Roblox는 Ball을 정육면체 크기로, Cylinder 단면을 원(y = z)으로 맞춰 버려요 → 데이터가 처음부터 그 모양이어야 해요
local function shapeProblem(specs: { DecorSpec }): string?
	for i, spec in specs do
		local s = spec.size
		if spec.shape == "Ball" and not (s.x == s.y and s.y == s.z) then
			return `#{i} {spec.name}: Ball size must be uniform`
		end
		if spec.shape == "Cylinder" and s.y ~= s.z then
			return `#{i} {spec.name}: Cylinder y and z must match`
		end
	end
	return nil
end

local function checkNoOverlap(t: Test.Test, specs: { DecorSpec }, boxes: { Bounds }, label: string)
	for i, spec in specs do
		local b = MapKitLogic.bounds({ spec }) :: Bounds
		for k, box in boxes do
			t.ok(not overlaps(b, box), `{label} #{i} {spec.name} overlaps sight box {k}`)
		end
	end
end

local function horizontal(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

return function(t: Test.Test)
	-- AC1 ---------------------------------------------------------------------------------
	t.test("AC1: 철판 decor()가 검사를 통과하고 600개 이하", function()
		local specs = HotPlateArt.decor()
		t.eq(MapKitLogic.validate(specs), nil)
		t.ok(MapKitLogic.count(specs) <= MapKitLogic.DECOR_PART_BUDGET, `count {MapKitLogic.count(specs)}`)
		t.ok(#specs >= 50, "철판 장식이 충분히 있어요")
		t.eq(shapeProblem(specs), nil)
	end)

	t.test(
		"AC1: 꼬치 쇼다운 장식(고정·조각·음식·손 전부)이 검사를 통과하고 합쳐서 600개 이하",
		function()
			t.eq(MapKitLogic.validate(SkewerArt.decor()), nil)
			for index = 1, SkewerLogic.SLICE_COUNT do
				t.eq(MapKitLogic.validate(SkewerArt.sliceDecor(index)), nil, `slice {index}`)
			end
			t.eq(MapKitLogic.validate(SkewerArt.skewerFood(SkewerLogic.LOW_SKEWER)), nil)
			t.eq(MapKitLogic.validate(SkewerArt.handDecor()), nil)
			local all = skewerAll()
			t.ok(MapKitLogic.count(all) <= MapKitLogic.DECOR_PART_BUDGET, `count {MapKitLogic.count(all)}`)
			t.eq(shapeProblem(all), nil)
		end
	)

	t.test("파티클·조명 예산: 철판 김 2~4개, 조명은 12개 이하", function()
		local hot = HotPlateArt.decor()
		local steam = countNamed(hot, HotPlateArt.STEAM_VENT)
		t.ok(steam >= 2 and steam <= 4, `steam vents {steam}`)
		t.ok(steam <= MapKitLogic.PARTICLE_BUDGET)
		t.ok(countNamed(hot, HotPlateArt.HOOD_LAMP) <= MapKitLogic.LIGHT_BUDGET)
		t.ok(countNamed(skewerStatic(), SkewerArt.LANTERN) <= MapKitLogic.LIGHT_BUDGET)
		t.ok(countNamed(skewerStatic(), SkewerArt.LANTERN) >= 1, "가게 문 등롱")
	end)

	t.test("김은 타일 위가 아니라 테두리(철판 바깥)에서 나와요", function()
		local half = HotPlateLogic.plateSize() / 2
		local cz = HotPlateLogic.centerZ()
		for _, spec in HotPlateArt.decor() do
			if spec.name == HotPlateArt.STEAM_VENT then
				local outside = math.abs(spec.offset.x) > half or math.abs(spec.offset.z - cz) > half
				t.ok(outside, "steam vent above tiles")
			end
		end
	end)

	-- AC2 ---------------------------------------------------------------------------------
	t.test(
		"AC2: 철판 장식이 층마다의 시야 상자(윗면 위 2~12, 철판 안쪽)와 겹치지 않아요",
		function()
			local boxes = HotPlateArt.courseVolume()
			t.eq(#boxes, HotPlateLogic.LAYER_COUNT)
			local half = HotPlateLogic.plateSize() / 2
			for layer, box in boxes do
				local top = HotPlateLogic.layerTopY(layer)
				t.eq(box.min.y, top + 2)
				t.eq(box.max.y, top + 12)
				t.eq(box.max.x - box.min.x, half * 2)
			end
			checkNoOverlap(t, HotPlateArt.decor(), boxes, "hot-plate")
		end
	)

	t.test("AC2: 꼬치 쇼다운 고정·조각 장식이 무대 시야 상자와 겹치지 않아요", function()
		local boxes = SkewerArt.courseVolume()
		t.eq(#boxes, 1)
		t.eq(boxes[1].max.x, SkewerLogic.STAGE_RADIUS)
		t.eq(boxes[1].min.y, 2)
		t.eq(boxes[1].max.y, 12)
		checkNoOverlap(t, skewerStatic(), boxes, "skewer-showdown")
	end)

	t.test("AC2 보조: 시야 상자 검사가 실제로 걸러내요 (무대 위 상자는 실패)", function()
		local bad: DecorSpec = {
			name = "Bad",
			shape = "Block",
			size = { x = 1, y = 1, z = 1 },
			color = { r = 1, g = 1, b = 1 },
			material = "Wood",
			offset = { x = 0, y = 5, z = 10 },
		}
		local b = MapKitLogic.bounds({ bad }) :: Bounds
		t.ok(overlaps(b, SkewerArt.courseVolume()[1]))
	end)

	t.test("조각 장식은 얇은 금 선이 윗면 위 0.05쯤, 테두리는 무대 가장자리", function()
		for index = 1, SkewerLogic.SLICE_COUNT do
			for _, spec in SkewerArt.sliceDecor(index) do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				if spec.name == "GoldLine" then
					t.ok(b.min.y > 0 and b.max.y <= 0.1, "gold line height")
					t.ok(horizontal(spec.offset.x, spec.offset.z) < SkewerLogic.STAGE_RADIUS, "gold line on stage")
				end
				t.ok(b.max.y < 2, `{spec.name} stays low`)
			end
		end
	end)

	-- AC3 ---------------------------------------------------------------------------------
	t.test("AC3: 꼬치 음식 장식이 모두 꼬치 판정 상자 안쪽 (낮은·높은 꼬치)", function()
		for _, spec in { SkewerLogic.LOW_SKEWER, SkewerLogic.HIGH_SKEWER } do
			local food = SkewerArt.skewerFood(spec)
			t.ok(#food >= 4, "food pieces")
			local ok, why = SkewerArt.skewerFoodWithinHitbox(food, spec)
			t.ok(ok, why)
		end
	end)

	t.test("AC3: 판정 상자 = 꼬치 길이 × 굵기, 맞음 판정 반경 안에 들어가요", function()
		local spec = SkewerLogic.LOW_SKEWER
		local box = SkewerArt.skewerHitbox(spec)
		t.eq(box.max.x - box.min.x, spec.outerReach - spec.innerReach)
		t.eq(box.max.y, spec.radius)
		t.eq(box.max.z, spec.radius)
		-- 상자 모서리에 몸통이 닿으면(몸통 중심이 모서리에서 BODY_RADIUS) 서버도 맞음으로 봐요
		t.ok(box.max.z + SkewerLogic.BODY_RADIUS <= spec.radius + SkewerLogic.BODY_RADIUS + EPS)
		local corner = 15 -- 무대 중심에서 15 studs 떨어진 곳, 꼬치 각도 0
		local standing = spec.height + SkewerLogic.BODY_BELOW_ROOT -- 발이 꼬치 높이
		t.ok(SkewerLogic.isHit(corner, -(box.max.z + SkewerLogic.BODY_RADIUS * 0.99), standing, 0, 0, spec))
	end)

	t.test("AC3 보조: 판정 밖으로 튀어나온 음식은 검사에서 걸려요", function()
		local spec = SkewerLogic.LOW_SKEWER
		local big: DecorSpec = {
			name = "BigChicken",
			shape = "Block",
			size = { x = 1.8, y = spec.radius * 2 + 0.4, z = spec.radius * 2 },
			color = { r = 1, g = 1, b = 1 },
			material = "SmoothPlastic",
			offset = { x = 0, y = 0, z = 0 },
		}
		local ok = SkewerArt.skewerFoodWithinHitbox({ big }, spec)
		t.eq(ok, false)
		local tilted = table.clone(big)
		tilted.size = { x = 1.8, y = spec.radius * 2, z = spec.radius * 2 }
		tilted.rotation = { x = 45, y = 0, z = 0 }
		t.eq(
			(SkewerArt.skewerFoodWithinHitbox({ tilted }, spec)),
			false,
			"45° 돌린 정사각 단면은 튀어나와요"
		)
		local beyond = table.clone(tilted)
		beyond.rotation = nil
		beyond.offset = { x = (spec.outerReach - spec.innerReach) / 2, y = 0, z = 0 }
		t.eq((SkewerArt.skewerFoodWithinHitbox({ beyond }, spec)), false, "꼬치 끝 너머")
	end)

	-- AC4 ---------------------------------------------------------------------------------
	t.test(
		"AC4: 철판 소개 카메라 3~5개, 끝점은 맨 위층 바깥 높이 10~25에서 철판 가운데를 봐요",
		function()
			local points = HotPlateArt.introCamera()
			t.ok(#points >= 3 and #points <= 5, `points {#points}`)
			local last = points[#points]
			local half = HotPlateLogic.plateSize() / 2
			local cz = HotPlateLogic.centerZ()
			local top = HotPlateLogic.layerTopY(1)
			t.ok(math.abs(last.pos.x) > half or math.abs(last.pos.z - cz) > half, "end outside the plate")
			t.ok(last.pos.y - top >= 10 and last.pos.y - top <= 25, `end height {last.pos.y}`)
			t.eq(last.lookAt.x, 0)
			t.eq(last.lookAt.z, cz)
			-- 맨 처음은 맨 아래층 밑의 손님 얼굴을 봐요
			t.ok(points[1].lookAt.y < HotPlateLogic.eliminationY(), "first shot looks at the customers")
		end
	)

	t.test(
		"AC4: 꼬치 쇼다운 소개 카메라 3~5개, 무대를 돌고 무대 바깥 높이 10~25에서 가운데를 봐요",
		function()
			local points = SkewerArt.introCamera()
			t.ok(#points >= 3 and #points <= 5, `points {#points}`)
			local last = points[#points]
			t.ok(horizontal(last.pos.x, last.pos.z) > SkewerLogic.STAGE_RADIUS, "end outside the stage")
			t.ok(last.pos.y >= 10 and last.pos.y <= 25, `end height {last.pos.y}`)
			t.eq(last.lookAt.x, 0)
			t.eq(last.lookAt.z, 0)
			-- 한 바퀴: 경유점 각도가 네 사분면 중 셋 이상에 걸쳐 있어요
			local quadrants = {}
			for _, p in points do
				quadrants[(if p.pos.x >= 0 then 1 else 0) + (if p.pos.z >= 0 then 2 else 0)] = true
			end
			local n = 0
			for _ in quadrants do
				n += 1
			end
			t.ok(n >= 3, `quadrants {n}`)
			for i, p in points do
				t.ok(horizontal(p.pos.x, p.pos.z) > SkewerLogic.STAGE_RADIUS, `point {i} outside the stage`)
			end
		end
	)

	-- 판정 고정 ------------------------------------------------------------------------------
	t.test("판정 수치는 M2 그대로 (철판 층·타일·시간, 꼬치 치수)", function()
		t.eq(HotPlateLogic.LAYER_COUNT, 3)
		t.eq(HotPlateLogic.TILE_SIZE, 6)
		t.eq(HotPlateLogic.GRID_SIZE, 9)
		t.eq(HotPlateLogic.HEAT_DURATION, 1.5)
		t.eq(HotPlateLogic.eliminationY(), -55)
		t.eq(SkewerLogic.STAGE_RADIUS, 22)
		t.eq(SkewerLogic.LOW_SKEWER.radius, 0.6)
		t.eq(SkewerLogic.HIGH_SKEWER.height, 6.8)
		t.eq(SkewerLogic.SUDDEN_DEATH_AT, 60)
	end)

	t.test(
		"철판 색: 회색 → 주황 → 빨강, 마지막 단계만 Neon (사라지는 시간은 그대로)",
		function()
			local cold = HotPlateLogic.COLOR_COLD
			t.ok(math.abs(cold.r - cold.g) < 16 and math.abs(cold.g - cold.b) < 16, "cold is grey")
			t.ok(cold.r < 140, "진회색")
			local warm = HotPlateLogic.COLOR_WARM
			t.ok(warm.r > warm.g and warm.g > warm.b, "warm is orange")
			local hot = HotPlateLogic.COLOR_HOT
			t.ok(hot.r > 150 and hot.g < 60 and hot.b < 60, "hot is red")
			t.eq(HotPlateArt.isGlowing(0), false)
			t.eq(HotPlateArt.isGlowing(0.75), false)
			t.eq(HotPlateArt.isGlowing(1.4), true)
			local _, gone = HotPlateLogic.heatVisual(1.49)
			t.eq(gone, false)
		end
	)

	t.test(
		"가게 문은 무대 앞쪽(로컬 -Z, 우승 연출이 문을 박차고 나가는 방향) 바깥",
		function()
			t.ok(SkewerArt.DOOR_Z < -SkewerLogic.STAGE_RADIUS - 10)
			local found = false
			for _, spec in SkewerArt.decor() do
				if spec.name == "Noren" then
					found = true
					t.ok(spec.offset.z < -SkewerLogic.STAGE_RADIUS, "noren on the -Z side")
				end
			end
			t.ok(found, "noren")
		end
	)

	t.test("셰프·손님 얼굴은 탈락 높이 아래에 있어요 (떨어지면 그 쪽으로)", function()
		local belowFaces = 0
		for _, spec in HotPlateArt.decor() do
			if spec.name == "CustomerHead" then
				belowFaces += 1
				t.ok(spec.offset.y + spec.size.y / 2 < HotPlateLogic.layerTopY(HotPlateLogic.LAYER_COUNT), "face below")
			end
		end
		t.ok(belowFaces >= 2 and belowFaces <= 3, `faces {belowFaces}`)
		for _, spec in SkewerArt.decor() do
			if string.sub(spec.name, 1, 4) == "Chef" then
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				t.ok(b.max.y < -20, `{spec.name} deep below`)
			end
		end
	end)

	-- 소스 계약 ------------------------------------------------------------------------------
	t.test(
		"맵 build가 MapKit 장식·IntroCamera·Studio 아트를 쓰고, 꼬치 넉백은 MoveExempt.mark",
		function()
			for _, path in { "src/shared/maps/HotPlate.luau", "src/shared/maps/SkewerShowdown.luau" } do
				local source = fs.readFile(path)
				for _, needle in { "MapKit.buildDecor(", "MapKit.introCamera(", "MapKit.attachStudioArt(" } do
					t.ok(string.find(source, needle, 1, true) ~= nil, `{path} uses {needle}`)
				end
			end
			local skewer = fs.readFile("src/shared/maps/SkewerShowdown.luau")
			t.ok(string.find(skewer, "MoveExempt.mark(", 1, true) ~= nil, "knockback marks MoveExempt")
			local hot = fs.readFile("src/shared/maps/HotPlate.luau")
			t.ok(string.find(hot, "CustomPhysicalProperties", 1, true) ~= nil, "tile physics pinned when going Neon")
		end
	)
end
