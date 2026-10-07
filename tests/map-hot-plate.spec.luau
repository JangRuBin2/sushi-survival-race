--!strict
-- m2-03 Survival 맵 "뜨거운 철판": 맵 모듈 모양, 치수, 타일 달아오름 색/사라짐 (순수 로직)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Logic = RobloxRequire.require(Shared.maps.HotPlateLogic)

local function same(a: any, b: any): boolean
	return a.r == b.r and a.g == b.g and a.b == b.b
end

return function(t: Test.Test)
	t.test("m2-03 AC1: hot-plate는 인터페이스를 지키는 Survival 맵", function()
		local map = Maps.get("hot-plate")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "뜨거운 철판")
	end)

	t.test("m2-03 AC3: 0초 회색, 0.75초 주황, 1.5초 빨강이면서 사라짐", function()
		local c0, gone0 = Logic.heatVisual(0)
		t.ok(same(c0, Logic.COLOR_COLD), "0s should be grey")
		t.eq(gone0, false)

		local cMid, goneMid = Logic.heatVisual(0.75)
		t.ok(same(cMid, Logic.COLOR_WARM), "0.75s should be orange")
		t.eq(goneMid, false)

		local cEnd, goneEnd = Logic.heatVisual(1.5)
		t.ok(same(cEnd, Logic.COLOR_HOT), "1.5s should be red")
		t.eq(goneEnd, true)

		local cAfter, goneAfter = Logic.heatVisual(9)
		t.ok(same(cAfter, Logic.COLOR_HOT), "after 1.5s colour stays red")
		t.eq(goneAfter, true)

		local _, goneJustBefore = Logic.heatVisual(1.49)
		t.eq(goneJustBefore, false)
	end)

	t.test("달아오르는 동안 빨간 쪽으로만 변해요 (초록·파랑이 늘지 않음)", function()
		local prev = Logic.heatVisual(0)
		for i = 1, 15 do
			local color = Logic.heatVisual(i * 0.1)
			t.ok(color.g <= prev.g, `green rises at {i * 0.1}s`)
			t.ok(color.b <= prev.b, `blue rises at {i * 0.1}s`)
			prev = color
		end
	end)

	t.test("층 3개, 층 간격 18~24, 층마다 9×9 타일이 틈 없이 깔려요", function()
		t.eq(Logic.LAYER_COUNT, 3)
		t.ok(Logic.LAYER_GAP >= 18 and Logic.LAYER_GAP <= 24, "layer gap out of range")
		t.eq(Logic.layerTopY(1), 0)
		t.eq(Logic.layerTopY(2) - Logic.layerTopY(3), Logic.LAYER_GAP)

		local offsets = Logic.tileOffsets()
		t.eq(#offsets, Logic.GRID_SIZE * Logic.GRID_SIZE)
		t.eq(#offsets, 81)
		local half = Logic.plateSize() / 2
		local seen = {}
		for _, o in offsets do
			-- 타일 가장자리가 층 경계 안에 있고, 같은 칸에 두 개가 없어요
			t.ok(math.abs(o.x) + Logic.TILE_SIZE / 2 <= half + 1e-6, "tile outside plate (x)")
			t.ok(math.abs(o.z) + Logic.TILE_SIZE / 2 <= half + 1e-6, "tile outside plate (z)")
			local key = `{o.x},{o.z}`
			t.ok(not seen[key], `duplicate tile at {key}`)
			seen[key] = true
		end
		-- 틈 없음: 타일 총 면적 = 층 면적
		t.eq(#offsets * Logic.TILE_SIZE * Logic.TILE_SIZE, Logic.plateSize() * Logic.plateSize())
	end)

	t.test("스폰 24개가 맨 위층 안에 고르게 흩어져요", function()
		local spawns = Logic.spawnOffsets()
		t.eq(#spawns, 24)
		local half = Logic.plateSize() / 2
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		local seen = {}
		for _, s in spawns do
			t.ok(math.abs(s.x) < half - 1 and math.abs(s.z) < half - 1, "spawn too close to the edge")
			local key = `{s.x},{s.z}`
			t.ok(not seen[key], `duplicate spawn at {key}`)
			seen[key] = true
			minX, maxX = math.min(minX, s.x), math.max(maxX, s.x)
			minZ, maxZ = math.min(minZ, s.z), math.max(maxZ, s.z)
		end
		-- 층 전체에 퍼져 있어요 (한쪽에 몰리지 않음)
		t.ok(maxX - minX >= half, "spawns not spread on x")
		t.ok(maxZ - minZ >= half, "spawns not spread on z")
	end)

	t.test("맨 아래층보다 15 studs 아래가 탈락 높이", function()
		t.eq(Logic.eliminationY(), Logic.layerTopY(3) - 15)
		t.ok(Logic.centerZ() < 0, "plate should sit in front of origin (local -Z)")
	end)
end
