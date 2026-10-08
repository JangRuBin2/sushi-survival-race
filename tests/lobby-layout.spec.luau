--!strict
-- Shared.LobbyLayout: 로비 회전초밥집 배치·레일·조명 (m4-06 AC1~AC4)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local LobbyLayout = RobloxRequire.require(Shared.LobbyLayout)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)

local EPS = 1e-6
local SAMPLE_TIMES = { 0, 1.7, 13.25, 44, 1759900000.5 }

local function overlaps(a: any, b: any): boolean
	return a.min.x < b.max.x - EPS
		and a.max.x > b.min.x + EPS
		and a.min.y < b.max.y - EPS
		and a.max.y > b.min.y + EPS
		and a.min.z < b.max.z - EPS
		and a.max.z > b.min.z + EPS
end

local function onEllipse(p: any): number
	local rail = LobbyLayout.RAIL
	return ((p.x - rail.center.x) / rail.a) ^ 2 + ((p.z - rail.center.z) / rail.b) ^ 2
end

local function angleOf(p: any): number
	local rail = LobbyLayout.RAIL
	return math.atan2((p.z - rail.center.z) / rail.b, (p.x - rail.center.x) / rail.a)
end

return function(t: Test.Test)
	t.test("AC1: 로비 장식 목록이 MapKitLogic.validate를 통과하고 파츠 800개 이하", function()
		t.eq(MapKitLogic.validate(LobbyLayout.STRUCTURE), nil)
		t.eq(MapKitLogic.validate(LobbyLayout.DECOR), nil)
		for i = 1, LobbyLayout.RAIL.plateCount do
			t.eq(MapKitLogic.validate(LobbyLayout.plateParts(i)), nil, `plate {i}`)
		end
		local all = LobbyLayout.allSpecs(0)
		t.eq(MapKitLogic.validate(all), nil)
		t.ok(MapKitLogic.count(all) <= 800, `parts {MapKitLogic.count(all)}`)
		-- 한 번에 만드는 묶음(건물, 장식)은 MapKit 경고 예산 600 안
		t.ok(#LobbyLayout.STRUCTURE <= MapKitLogic.DECOR_PART_BUDGET)
		t.ok(#LobbyLayout.DECOR <= MapKitLogic.DECOR_PART_BUDGET)
	end)

	t.test("AC1: 이름이 겹치지 않고, 빛은 8개 이하이며 있는 장식 파츠에 붙어요", function()
		local names = {}
		for _, list in { LobbyLayout.STRUCTURE, LobbyLayout.DECOR } do
			for _, spec in list do
				t.eq(names[spec.name], nil, `duplicate {spec.name}`)
				names[spec.name] = true
			end
		end
		t.ok(#LobbyLayout.LIGHTS >= 1 and #LobbyLayout.LIGHTS <= 8, `lights {#LobbyLayout.LIGHTS}`)
		for _, light in LobbyLayout.LIGHTS do
			local found = false
			for _, spec in LobbyLayout.DECOR do
				if spec.name == light.part then
					found = true
				end
			end
			t.ok(found, `light part {light.part}`)
			t.ok(light.range > 0 and light.range <= 60 and light.brightness > 0)
		end
	end)

	t.test("AC2: 모든 파츠가 원점 반지름 128·높이 60 안", function()
		local limits = LobbyLayout.LIMITS
		t.eq(limits.radius, 128)
		t.eq(limits.height, 60)
		for _, time in SAMPLE_TIMES do
			for _, spec in LobbyLayout.allSpecs(time) do
				local b = MapKitLogic.bounds({ spec }) :: any
				t.ok(b.min.y >= -EPS and b.max.y <= limits.height, `height {spec.name}`)
				for _, x in { b.min.x, b.max.x } do
					for _, z in { b.min.z, b.max.z } do
						t.ok(math.sqrt(x * x + z * z) <= limits.radius, `radius {spec.name}`)
					end
				end
			end
		end
	end)

	t.test("AC2: 스폰 반지름 10·스폰→카운터 통로와 겹치지 않음", function()
		local zones = LobbyLayout.CLEAR_ZONES
		t.eq(#zones, 2)
		-- 스폰 상자가 반지름 10을 덮어요
		t.ok(zones[1].min.x <= -10 and zones[1].max.x >= 10 and zones[1].min.z <= -10 and zones[1].max.z >= 10)
		-- 통로는 스폰 상자에서 카운터 앞면(z = 가운데 - 깊이/2)까지 이어져요
		local counter = LobbyLayout.COUNTER
		local front = counter.center.z + counter.depth / 2
		t.ok(zones[2].max.z >= zones[1].min.z, "corridor touches spawn zone")
		t.ok(zones[2].min.z <= front + 1, "corridor reaches counter")
		for _, time in SAMPLE_TIMES do
			for _, spec in LobbyLayout.allSpecs(time) do
				local b = MapKitLogic.bounds({ spec })
				for _, zone in zones do
					t.ok(not overlaps(b, zone), `{spec.name} overlaps {zone.name}`)
				end
			end
		end
	end)

	t.test("AC2: 아레나(x ≥ 2000, 높이 300)와 떨어져 있어요", function()
		local b = MapKitLogic.bounds(LobbyLayout.allSpecs(0)) :: any
		t.ok(b.max.x < 2000 and b.max.y < 300)
	end)

	t.test("AC3: plateAt이 레일 타원 위에 있고 진행 방향(yaw)이 접선이에요", function()
		local rail = LobbyLayout.RAIL
		for _, time in SAMPLE_TIMES do
			for i = 1, rail.plateCount do
				local p = LobbyLayout.plateAt(i, time)
				t.ok(math.abs(onEllipse(p) - 1) < 1e-6, `plate {i} off rail`)
				t.ok(math.abs(p.y - rail.center.y) < EPS)
				-- 아주 조금 뒤 자리 쪽이 yaw의 -Z 방향과 같아요
				local q = LobbyLayout.plateAt(i, time + 0.01)
				local dx, dz = q.x - p.x, q.z - p.z
				local fx, fz = -math.sin(p.yaw), -math.cos(p.yaw)
				local len = math.sqrt(dx * dx + dz * dz)
				t.ok(len > 0 and (dx * fx + dz * fz) / len > 0.99, `plate {i} yaw`)
			end
		end
	end)

	t.test("AC3: 같은 t에서 접시 16개 사이 호 길이 간격이 같아요", function()
		local rail = LobbyLayout.RAIL
		t.eq(rail.plateCount, 16)
		local length = LobbyLayout.railLength()
		local spacing = length / rail.plateCount
		for _, time in SAMPLE_TIMES do
			for i = 1, rail.plateCount do
				local nextIndex = i % rail.plateCount + 1
				local gap = (LobbyLayout.plateArc(nextIndex, time) - LobbyLayout.plateArc(i, time)) % length
				t.ok(math.abs(gap - spacing) < 1e-6, `gap {i}`)
			end
		end
		-- 호 길이 → 점 변환이 실제 거리와 맞아요 (짧은 구간 직선 거리 ≈ 호 길이)
		for s = 0, length, length / 64 do
			local a, b = LobbyLayout.pointAtArc(s), LobbyLayout.pointAtArc(s + 0.05)
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			t.ok(math.abs(d - 0.05) < 0.002, `arc {s}`)
		end
	end)

	t.test("AC3: t가 늘면 한 방향으로 돌고, 주기 = 둘레 / 속도", function()
		local rail = LobbyLayout.RAIL
		local length = LobbyLayout.railLength()
		-- 타원 둘레 (Ramanujan 근사)와 비교
		local a, b = rail.a, rail.b
		local h = ((a - b) / (a + b)) ^ 2
		local approx = math.pi * (a + b) * (1 + 3 * h / (10 + math.sqrt(4 - 3 * h)))
		t.ok(math.abs(length - approx) < 0.05, `length {length} vs {approx}`)
		t.ok(math.abs(LobbyLayout.period() - length / rail.speed) < EPS)
		t.ok(rail.speed > 0)
		for i = 1, rail.plateCount do
			local prev = angleOf(LobbyLayout.plateAt(i, 100))
			for step = 1, 200 do
				local now = angleOf(LobbyLayout.plateAt(i, 100 + step * 0.25))
				local delta = (now - prev) % (2 * math.pi)
				t.ok(delta > 0 and delta < math.pi, `plate {i} step {step} turned back`)
				prev = now
			end
			-- 한 주기 뒤 같은 자리
			local p0 = LobbyLayout.plateAt(i, 7)
			local p1 = LobbyLayout.plateAt(i, 7 + LobbyLayout.period())
			t.ok(math.abs(p0.x - p1.x) < 1e-6 and math.abs(p0.z - p1.z) < 1e-6, `period plate {i}`)
		end
	end)

	t.test("AC3: 접시 파츠는 접시 가운데 기준이고 이름표가 Plate01~16", function()
		t.eq(LobbyLayout.plateName(1), "Plate01")
		t.eq(LobbyLayout.plateName(16), "Plate16")
		local colors = {}
		for i = 1, 16 do
			local parts = LobbyLayout.plateParts(i)
			t.ok(#parts >= 3 and #parts <= 4)
			t.eq(parts[1].name, "Plate")
			colors[`{parts[1].color.r},{parts[1].color.g},{parts[1].color.b}`] = true
		end
		local kinds = 0
		for _ in colors do
			kinds += 1
		end
		t.eq(kinds, 3, "빨강·파랑·금색 접시")
	end)

	t.test("단상은 스폰 오른쪽(+X) 약 30, 가운데 단이 가장 높아요", function()
		local podium = LobbyLayout.PODIUM
		t.ok(math.abs(podium.center.x - 30) <= 5 and math.abs(podium.center.z) <= 5)
		local heights = {}
		for _, spec in LobbyLayout.STRUCTURE do
			if string.match(spec.name, "^Podium") then
				heights[spec.name] = spec.size.y
			end
		end
		t.eq(heights.PodiumFirst, podium.topY)
		t.ok(heights.PodiumFirst > heights.PodiumSecond and heights.PodiumSecond > heights.PodiumThird)
		t.ok(podium.scale == 1.5)
		t.ok(podium.labelHeight > podium.topY)
	end)

	t.test("AC4: 조명 표에 필요한 키가 있고 Atmosphere.Density ≤ 0.3", function()
		local L = LobbyLayout.LIGHTING
		t.eq(L.ClockTime, 14)
		for _, key in { "Brightness", "Ambient", "OutdoorAmbient", "Atmosphere", "ColorCorrection", "Bloom" } do
			t.ok((L :: any)[key] ~= nil, `missing {key}`)
		end
		for _, key in { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } do
			t.ok((L.Atmosphere :: any)[key] ~= nil, `missing Atmosphere.{key}`)
		end
		t.ok(L.Atmosphere.Density >= 0 and L.Atmosphere.Density <= 0.3)
		for _, key in { "Brightness", "Contrast", "Saturation", "TintColor" } do
			t.ok((L.ColorCorrection :: any)[key] ~= nil, `missing ColorCorrection.{key}`)
		end
		t.ok(math.abs(L.ColorCorrection.Saturation - 0.05) < EPS)
		for _, key in { "Intensity", "Size", "Threshold" } do
			t.ok((L.Bloom :: any)[key] ~= nil, `missing Bloom.{key}`)
		end
		t.ok(L.Bloom.Intensity <= 0.5, "bloom weak")
		t.eq((L :: any).Technology, nil)
	end)
end
