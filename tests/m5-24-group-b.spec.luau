--!strict
-- m5-24 아트 패스 v2, 그룹 B (soy-swamp · chef-board · tug-of-war-platform): AC2~AC5 순수 로직 확인.
--   AC2 Art.BUDGET == "Extended", checkBudget(장식 + 맵 코드 Instance.new 조명·파티클) 통과
--   AC3 장식이 시야 상자와 안 겹치고 validate 통과 (줄다리기: 발판이 도는 공간과 안 겹침)
--   AC4 맵 lighting == Art.LIGHTING, validate 통과, 로비와 ClockTime 또는 Atmosphere.Color가 다름
--   AC5 판정 파츠와 같이 움직이는 장식(도마 칸·줄다리기 발판 하위)에 anim 없음

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local SwampArt = RobloxRequire.require(Shared.maps.SoySwampArt)
local ChefArt = RobloxRequire.require(Shared.maps.ChefBoardArt)
local ChefLogic = RobloxRequire.require(Shared.maps.ChefBoardLogic)
local TugArt = RobloxRequire.require(Shared.maps.TugOfWarPlatformArt)
local TugLayout = RobloxRequire.require(Shared.maps.TugOfWarPlatformLayout)

type Bounds = MapKitLogic.Bounds

local function overlaps(a: Bounds, b: Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

local function concat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #out + 1, out)
	end
	return out
end

-- 맵마다: 예산 검사에 넣을 장식 전부(움직이는 판정 하위 장식 포함)
local MAPS = {
	{
		id = "soy-swamp",
		art = SwampArt,
		all = function()
			return SwampArt.decor()
		end,
	},
	{
		id = "chef-board",
		art = ChefArt,
		all = function()
			return concat(ChefArt.decor(), ChefArt.allCellDecor())
		end,
	},
	{
		id = "tug-of-war-platform",
		art = TugArt,
		all = function()
			return concat(TugArt.decor(), TugArt.deckDecor())
		end,
	},
}

return function(t: Test.Test)
	t.test("AC2: 세 맵 모두 Extended, 장식 + 코드 조명·파티클이 예산 안", function()
		for _, m in MAPS do
			t.eq(m.art.BUDGET, "Extended", m.id)
			t.ok(type(m.art.CODE_EXTRAS) == "table", `{m.id} CODE_EXTRAS`)
			local specs = m.all()
			t.eq(MapKitLogic.validate(specs), nil, `{m.id} validate`)
			t.eq(MapKitLogic.checkBudget(specs, "Extended", m.art.CODE_EXTRAS), nil, `{m.id} budget`)
			-- 가이드 8절: 파티클 2종 이상·움직임 3개 이상 (장식 스펙만으로)
			local kinds: { [string]: boolean } = {}
			local nKinds = 0
			for _, s in specs do
				if s.particle and not kinds[s.particle] then
					kinds[s.particle] = true
					nKinds += 1
				end
			end
			t.ok(nKinds >= 2, `{m.id} particle kinds {nKinds}`)
			t.ok(MapKitLogic.countAnimated(specs) >= 3, `{m.id} anim count`)
			-- 그림자 조명은 고정 파츠에만 (anim 붙은 파츠에 shadows 없음)
			for _, s in specs do
				if s.light and s.light.shadows then
					t.eq(s.anim, nil, `{m.id} {s.name} shadow light on animated decor`)
				end
			end
		end
	end)

	t.test(
		"AC3: 도마 장식은 도마 시야 상자와 안 겹치고, 받침 기둥은 보호 칸(가운데 3×3) 안",
		function()
			local volume = ChefArt.courseVolume()
			for _, s in concat(ChefArt.decor(), ChefArt.allCellDecor()) do
				local b = MapKitLogic.bounds({ s }) :: Bounds
				t.ok(not overlaps(b, volume), `{s.name} blocks the view`)
			end
			local protectedHalf = (ChefLogic.PROTECTED_HALF + 0.5) * ChefLogic.CELL_SIZE -- 12
			for _, s in ChefArt.decor() do
				local b = MapKitLogic.bounds({ s }) :: Bounds
				-- 도마 가까이(낙하선 위)에 있는 받침 부분만 — 잘린 칸 구멍 사이로 "칸"처럼 보이지 않게
				if string.sub(s.name, 1, 10) == "BoardStand" and b.max.y > -ChefLogic.FALL_DEPTH then
					t.ok(b.max.x <= protectedHalf and b.min.x >= -protectedHalf, `{s.name} x inside protected cells`)
					t.ok(b.max.z <= protectedHalf and b.min.z >= -protectedHalf, `{s.name} z inside protected cells`)
					t.ok(b.max.y < -ChefLogic.BOARD_THICKNESS, `{s.name} below the board`)
				end
			end
			-- 배경 바닥(작업대)은 낙하선보다 10 이상 아래
			t.ok(ChefArt.TABLE_Y <= -ChefLogic.FALL_DEPTH - 10, "steel table below fall line")
		end
	)

	t.test(
		"AC3: 줄다리기 고정 장식은 발판이 도는 공간(연장전 90°까지)과 안 겹쳐요 (받침대만 축 아래)",
		function()
			local r = TugArt.SWEEP_RADIUS
			t.ok(r > TugLayout.HALF_LENGTH, "sweep radius covers the platform")
			local sweep: Bounds = {
				min = { x = -r, y = -r, z = -TugLayout.HALF_WIDTH - 1 },
				max = { x = r, y = r, z = TugLayout.HALF_WIDTH + 1 },
			}
			for _, s in TugArt.decor() do
				local underAxis = string.sub(s.name, 1, 8) == "Pedestal" or string.sub(s.name, 1, 6) == "Mortar"
				if not underAxis then
					local b = MapKitLogic.bounds({ s }) :: Bounds
					t.ok(not overlaps(b, sweep), `{s.name} inside the platform sweep`)
				end
			end
			t.ok(TugArt.YARD_Y <= -TugLayout.FALL_DEPTH - 10, "yard ground below fall line")
		end
	)

	t.test("AC3: 간장 늪 배경 호수는 낙하선보다 10 이상 아래", function()
		t.ok(SwampArt.LAKE_Y <= -40 - 10 + 1e-9, "lake below fall line")
	end)

	t.test("AC4: lighting = Art.LIGHTING, validate 통과, 로비와 다름", function()
		for _, m in MAPS do
			local map = Maps.get(m.id)
			t.ok(map.lighting == m.art.LIGHTING, `{m.id} uses Art.LIGHTING`)
			t.eq(MapTypes.validate(map), nil, m.id)
			t.eq(MapLighting.validate(m.art.LIGHTING), nil, m.id)
			local resolved = MapLighting.resolve(m.art.LIGHTING)
			local lobby = MapLighting.LOBBY
			local sameClock = resolved.ClockTime == lobby.ClockTime
			local a, b = resolved.Atmosphere.Color, lobby.Atmosphere.Color
			local sameColor = a.r == b.r and a.g == b.g and a.b == b.b
			t.ok(not (sameClock and sameColor), `{m.id} differs from lobby`)
		end
	end)

	t.test(
		"AC5: 판정 파츠와 같이 움직이는 장식(도마 칸·줄다리기 발판 하위)에 anim 없음",
		function()
			for _, s in ChefArt.allCellDecor() do
				t.eq(s.anim, nil, `chef cell decor {s.name}`)
				t.eq(s.light, nil, `chef cell decor {s.name} light`)
			end
			for _, s in TugArt.deckDecor() do
				t.eq(s.anim, nil, `tug deck decor {s.name}`)
				t.eq(s.light, nil, `tug deck decor {s.name} light`)
			end
		end
	)

	t.test("m5-20 이름 개수 유지 (LampBulb 3·FogPanel 3~4·Lantern 2)", function()
		local function count(list: { any }, name: string): number
			local n = 0
			for _, s in list do
				if s.name == name then
					n += 1
				end
			end
			return n
		end
		t.eq(count(ChefArt.decor(), ChefArt.LAMP_BULB), 3)
		local fog = count(ChefArt.decor(), ChefArt.FOG_PANEL)
		t.ok(fog >= 3 and fog <= 4, "chef fog panels kept")
		t.eq(count(TugArt.decor(), TugArt.LANTERN), TugArt.CODE_EXTRAS.lights)
	end)
end
