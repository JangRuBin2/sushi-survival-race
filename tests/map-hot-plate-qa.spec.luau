--!strict
-- m2-03 QA(docs/qa/m2-03-survival-hot-plate.md)에서 추가한 경계값·공정성 테스트 (순수 로직만)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Logic = RobloxRequire.require(Shared.maps.HotPlateLogic)

-- 타일 격자에서 (x, z)가 속한 칸 번호 (0부터). 철판 중심 기준 로컬 좌표.
local function cellOf(x: number, z: number): (number, number)
	local half = Logic.plateSize() / 2
	return math.floor((x + half) / Logic.TILE_SIZE), math.floor((z + half) / Logic.TILE_SIZE)
end

return function(t: Test.Test)
	t.test(
		"heatVisual: 1.5초 전에는 절대 사라지지 않고, 1.5초부터는 항상 사라져요 (0.01초 간격)",
		function()
			for i = 0, 300 do
				local elapsed = i * 0.01
				local _, gone = Logic.heatVisual(elapsed)
				t.eq(gone, elapsed >= Logic.HEAT_DURATION, `elapsed {elapsed}`)
			end
		end
	)

	t.test("heatVisual: 음수 경과(시계 오차)여도 회색이고 사라지지 않아요", function()
		local color, gone = Logic.heatVisual(-0.5)
		t.eq(color, Logic.COLOR_COLD)
		t.eq(gone, false)
	end)

	t.test("heatVisual: RGB가 항상 0~255 정수예요", function()
		for i = 0, 200 do
			local color = Logic.heatVisual(i * 0.01)
			for _, channel in { color.r, color.g, color.b } do
				t.ok(channel >= 0 and channel <= 255 and channel == math.floor(channel), `{i * 0.01}s: {channel}`)
			end
		end
	end)

	t.test(
		"공정성: 스폰 24개가 전부 서로 다른 타일 위에 있어요 (출발부터 같은 타일을 나눠 달구지 않음)",
		function()
			local seen = {}
			for i, s in Logic.spawnOffsets() do
				local cx, cz = cellOf(s.x, s.z)
				t.ok(cx >= 0 and cx < Logic.GRID_SIZE and cz >= 0 and cz < Logic.GRID_SIZE, `spawn {i} off the plate`)
				local key = `{cx},{cz}`
				t.ok(not seen[key], `spawn {i} shares tile {key}`)
				seen[key] = true
			end
		end
	)

	t.test("공정성: 스폰 사이 거리가 캐릭터가 겹치지 않을 만큼(4 studs 이상)", function()
		local spawns = Logic.spawnOffsets()
		for a = 1, #spawns do
			for b = a + 1, #spawns do
				local dx, dz = spawns[a].x - spawns[b].x, spawns[a].z - spawns[b].z
				t.ok(math.sqrt(dx * dx + dz * dz) >= 4, `spawn {a}-{b}`)
			end
		end
	end)

	t.test("스폰 수가 최대 방 인원 이상", function()
		local maxPlayers = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
		t.ok(#Logic.spawnOffsets() >= maxPlayers)
	end)

	t.test(
		"층 사이 여유: 아래층 위에 캐릭터(약 5 studs)가 설 공간이 있고, 탈락 높이는 맨 아래층 밑면보다 아래",
		function()
			for layer = 1, Logic.LAYER_COUNT - 1 do
				local upperBottom = Logic.layerTopY(layer) - Logic.TILE_THICKNESS
				local lowerTop = Logic.layerTopY(layer + 1)
				t.ok(upperBottom - lowerTop >= 6, `layer {layer}->{layer + 1} clearance {upperBottom - lowerTop}`)
			end
			local bottomUnderside = Logic.layerTopY(Logic.LAYER_COUNT) - Logic.TILE_THICKNESS
			t.ok(Logic.eliminationY() < bottomUnderside, "elimination must be below the bottom layer")
		end
	)

	t.test("스펙 범위: 층 간격 18~24, 타일 9×9·한 변 6 (층 54×54)", function()
		t.ok(Logic.LAYER_GAP >= 18 and Logic.LAYER_GAP <= 24)
		t.eq(Logic.GRID_SIZE, 9)
		t.eq(Logic.TILE_SIZE, 6)
		t.eq(Logic.plateSize(), 54)
	end)
end
