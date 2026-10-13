--!strict
-- m5-24 아트 패스 v2 그룹 A (rotating-belt · hot-plate · skewer-showdown) — docs/specs/m5-24-map-art-pass-v2.md
-- AC2 Extended 예산, AC3 시야 상자·validate, AC4 Art.LIGHTING(로비와 다름), AC5 판정 파츠와 같이 움직이는 장식에 anim 없음,
-- 배경 바닥이 낙하선보다 10 이상 아래, 그림자 조명은 좁은 SpotLight에만.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Maps = RobloxRequire.require(Shared.maps)
local BeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)
local HotArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local HotLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local SkewerArt = RobloxRequire.require(Shared.maps.SkewerShowdownArt)
local SkewerLogic = RobloxRequire.require(Shared.maps.SkewerShowdownLogic)

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

-- 맵별 정보: Art 모듈, 정적 장식, 낙하선(origin 기준 로컬 y), 배경 바닥 장식 이름
local MAPS = {
	{ id = "rotating-belt", art = BeltArt, decor = BeltArt.decor, fallY = -40, floorNames = { "MaruBoard" } },
	{
		id = "hot-plate",
		art = HotArt,
		decor = HotArt.decor,
		fallY = HotLogic.eliminationY(),
		floorNames = { "GriddleTop", "Floor" },
	},
	{
		id = "skewer-showdown",
		art = SkewerArt,
		decor = SkewerArt.decor,
		fallY = -20,
		floorNames = { "PlazaStone" },
	},
}

local function lightOf(spec: DecorSpec): MapKitLogic.LightSpec?
	return spec.light
end

return function(t: Test.Test)
	t.test("AC2: 세 맵 모두 Art.BUDGET = Extended이고 checkBudget 통과", function()
		for _, m in MAPS do
			t.eq(m.art.BUDGET, "Extended", m.id)
			local specs = m.decor()
			t.eq(MapKitLogic.validate(specs), nil, `{m.id} validate`)
			t.eq(MapKitLogic.checkBudget(specs, "Extended"), nil, `{m.id} budget`)
			-- 목표 밀도 (가이드 8절): 700 이상
			t.ok(MapKitLogic.count(specs) >= 700, `{m.id} decor {MapKitLogic.count(specs)} >= 700`)
			t.ok(MapKitLogic.countParticles(specs) >= 2, `{m.id} particles >= 2`)
			t.ok(MapKitLogic.countAnimated(specs) >= 3, `{m.id} anim >= 3`)
		end
	end)

	t.test("AC2: 꼬치 쇼다운은 조각·음식·손 장식까지 합쳐도 Extended 안", function()
		local all = SkewerArt.decor()
		for i = 1, SkewerLogic.SLICE_COUNT do
			for _, s in SkewerArt.sliceDecor(i) do
				table.insert(all, s)
			end
		end
		for _, spec in { SkewerLogic.LOW_SKEWER, SkewerLogic.HIGH_SKEWER } do
			for _, s in SkewerArt.skewerFood(spec) do
				table.insert(all, s)
			end
		end
		for _, s in SkewerArt.handDecor() do
			table.insert(all, s)
		end
		t.eq(MapKitLogic.checkBudget(all, "Extended"), nil)
	end)

	t.test("AC3: 장식이 시야 상자와 겹치지 않아요", function()
		for _, m in MAPS do
			local boxes = m.art.courseVolume()
			if boxes.min then
				boxes = { boxes }
			end
			for i, spec in m.decor() do
				local b = MapKitLogic.bounds({ spec }) :: Bounds
				for k, box in boxes do
					t.ok(not overlaps(b, box), `{m.id} #{i} {spec.name} overlaps sight box {k}`)
				end
			end
		end
	end)

	t.test("AC4: lighting = Art.LIGHTING, 검사 통과, 로비와 ClockTime이 달라요", function()
		for _, m in MAPS do
			local map = Maps.get(m.id)
			t.ok(map.lighting == m.art.LIGHTING, `{m.id} lighting is Art.LIGHTING`)
			t.eq(MapTypes.validate(map), nil, m.id)
			t.eq(MapLighting.validate(m.art.LIGHTING), nil, m.id)
			t.ok(m.art.LIGHTING.ClockTime ~= MapLighting.LOBBY.ClockTime, `{m.id} clock differs from lobby`)
		end
	end)

	t.test(
		"AC5: 판정 파츠와 같이 움직이는 장식(꼬치 조각·꼬치 음식·셰프 손)에 anim이 없어요",
		function()
			for i = 1, SkewerLogic.SLICE_COUNT do
				for _, spec in SkewerArt.sliceDecor(i) do
					t.eq(spec.anim, nil, `slice {i} {spec.name}`)
				end
			end
			for _, skewer in { SkewerLogic.LOW_SKEWER, SkewerLogic.HIGH_SKEWER } do
				for _, spec in SkewerArt.skewerFood(skewer) do
					t.eq(spec.anim, nil, `food {spec.name}`)
				end
			end
			for _, spec in SkewerArt.handDecor() do
				t.eq(spec.anim, nil, `hand {spec.name}`)
			end
		end
	)

	t.test(
		"가이드 2절: 배경 바닥은 낙하선보다 10 이상 아래이고 화면을 채울 만큼 넓어요",
		function()
			for _, m in MAPS do
				local found = 0
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, spec in m.decor() do
					if table.find(m.floorNames, spec.name) then
						found += 1
						local b = MapKitLogic.bounds({ spec }) :: Bounds
						t.ok(b.max.y <= m.fallY - 10, `{m.id} {spec.name} top {b.max.y} vs fall {m.fallY}`)
						minX, maxX = math.min(minX, b.min.x), math.max(maxX, b.max.x)
						minZ, maxZ = math.min(minZ, b.min.z), math.max(maxZ, b.max.z)
					end
				end
				t.ok(found > 0, `{m.id} has a background floor`)
				t.ok(maxX - minX >= 200 and maxZ - minZ >= 200, `{m.id} floor {maxX - minX} x {maxZ - minZ}`)
			end
		end
	)

	t.test("가이드 6절: 그림자 조명은 좁은 SpotLight(각도 < 120)에만, 맵당 2 이하", function()
		for _, m in MAPS do
			local shadowed = 0
			for _, spec in m.decor() do
				local light = lightOf(spec)
				if light and light.shadows then
					shadowed += 1
					t.eq(light.kind, "Spot", `{m.id} {spec.name} shadow light kind`)
					t.ok((light.angle or 90) < 120, `{m.id} {spec.name} spot angle`)
					t.eq(spec.anim, nil, `{m.id} {spec.name} shadow light on a fixed part`)
				end
			end
			t.ok(shadowed >= 1 and shadowed <= 2, `{m.id} shadowed {shadowed}`)
		end
	end)

	t.test(
		"가이드 4절: 빛나는 장식은 판정 경고 빨강(230,40,40)과 같은 색을 쓰지 않아요",
		function()
			for _, m in MAPS do
				for _, spec in m.decor() do
					if spec.material == "Neon" then
						local c = spec.color
						t.ok(not (c.r == 230 and c.g == 40 and c.b == 40), `{m.id} {spec.name}`)
					end
				end
			end
		end
	)
end
