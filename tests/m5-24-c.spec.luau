--!strict
-- m5-24 그룹 C(ramen-rapids · giant-jenga · claw-machine-prize) 아트 패스 v2: Extended 예산, 맵 조명,
-- 배경 바닥 높이, 움직이는 판정 파츠와 같이 움직이는 장식에 anim 없음, 소개 카메라 경로가 장식을 뚫지 않음.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)

local RamenArt = RobloxRequire.require(Shared.maps.RamenRapidsArt)
local RamenLayout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local JengaArt = RobloxRequire.require(Shared.maps.GiantJengaArt)
local JengaLayout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local ClawArt = RobloxRequire.require(Shared.maps.ClawMachinePrizeArt)
local ClawLayout = RobloxRequire.require(Shared.maps.ClawMachinePrizeLayout)

type Bounds = { min: { x: number, y: number, z: number }, max: { x: number, y: number, z: number } }

local MAPS = {
	{ id = "ramen-rapids", art = RamenArt },
	{ id = "giant-jenga", art = JengaArt },
	{ id = "claw-machine-prize", art = ClawArt },
}

local function clawAllDecor(): { any }
	local all = table.clone(ClawArt.decor())
	for row = 0, ClawLayout.GRID_SIZE - 1 do
		for col = 0, ClawLayout.GRID_SIZE - 1 do
			for _, s in ClawArt.tileDecor(row, col) do
				table.insert(all, s)
			end
		end
	end
	return all
end

local function inside(p: any, b: Bounds): boolean
	return p.x > b.min.x and p.x < b.max.x and p.y > b.min.y and p.y < b.max.y and p.z > b.min.z and p.z < b.max.z
end

return function(t: Test.Test)
	t.test("AC2: 세 맵 모두 Art.BUDGET = Extended, checkBudget 통과", function()
		for _, m in MAPS do
			t.eq(m.art.BUDGET, "Extended", m.id)
		end
		t.eq(MapKitLogic.checkBudget(RamenArt.decor(), "Extended"), nil, "ramen-rapids")
		t.eq(MapKitLogic.checkBudget(JengaArt.decor(), "Extended", { lights = 3 }), nil, "giant-jenga (+LampBulb 3)")
		t.eq(MapKitLogic.checkBudget(clawAllDecor(), "Extended", { lights = 1 }), nil, "claw-machine-prize (+NEON 1)")
		t.eq(MapKitLogic.validate(clawAllDecor()), nil, "claw validate")
		t.eq(MapKitLogic.validate(JengaArt.decor()), nil, "jenga validate")
	end)

	t.test("AC4: lighting = Art.LIGHTING, validate 통과, 로비와 ClockTime이 달라요", function()
		for _, m in MAPS do
			local map = Maps.get(m.id)
			t.ok(map.lighting == m.art.LIGHTING, `{m.id} lighting = Art.LIGHTING`)
			t.eq(MapLighting.validate(m.art.LIGHTING), nil, m.id)
			t.eq(MapTypes.validate(map), nil, m.id)
			t.ok(
				MapLighting.resolve(m.art.LIGHTING).ClockTime ~= MapLighting.LOBBY.ClockTime,
				`{m.id} differs from lobby`
			)
		end
	end)

	t.test(
		"AC5: 판정 파츠와 같이 움직이는 장식에 anim 없음 (젠가 블록·인형뽑기 칸·인형·집게)",
		function()
			-- 젠가: 블록·칸 윗면은 build가 직접 만들고, Art.decor()는 전부 Decor 폴더 고정 장식이에요.
			local jengaSource = fs.readFile("src/shared/maps/GiantJenga.luau")
			t.ok(
				string.find(jengaSource, "MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))", 1, true)
					~= nil
			)
			t.eq(
				select(2, string.gsub(jengaSource, "MapKit%.buildDecor%(", "")),
				1,
				"jenga: decor only into the Decor folder"
			)
			-- 인형뽑기: 칸 위 인형(tileDecor)에는 anim 없음, 연장전에 모델 전체가 기우니 Decor는 Pulse만 (CFrame 안 건드림)
			for row = 0, ClawLayout.GRID_SIZE - 1 do
				for col = 0, ClawLayout.GRID_SIZE - 1 do
					for _, s in ClawArt.tileDecor(row, col) do
						t.eq(s.anim, nil, `claw tile {row},{col} {s.name}`)
					end
				end
			end
			for _, s in ClawArt.decor() do
				if s.anim then
					t.eq(s.anim.kind, "Pulse", `claw {s.name}: only Pulse (model tilts in overtime)`)
				end
			end
			-- 그림자 조명이 붙은 파츠는 움직이지 않아요
			for _, m in MAPS do
				for _, s in (if m.id == "claw-machine-prize" then clawAllDecor() else m.art.decor()) do
					if s.light and s.light.shadows then
						t.eq(s.anim, nil, `{m.id} {s.name}: shadowed light on a static part`)
					end
				end
			end
		end
	)

	t.test("가이드 2절: 배경 바닥이 낙하 탈락선보다 10 이상 아래", function()
		t.ok(JengaArt.BENCH_TOP_Y <= -JengaLayout.FALL_DEPTH - 10, "jenga bench top")
		t.ok(ClawArt.PIT_Y <= -ClawLayout.FALL_DEPTH - 10, "claw pit floor")
		t.ok(ClawArt.FLOOR_Y <= -ClawLayout.FALL_DEPTH - 10, "claw carpet")
		local lowest = RamenLayout.BROTH_Y - RamenLayout.FALL_MARGIN
		t.ok(RamenArt.COUNTER_TOP_Y <= lowest - 10, `ramen counter {RamenArt.COUNTER_TOP_Y} vs fall {lowest}`)
		-- 인형뽑기 기계 몸통 윗면은 칸 윗면(−1~+1)보다 3 이상 아래 (밟는 면처럼 보이지 않게)
		t.ok(ClawArt.SHELL_TOP_Y <= -ClawLayout.HEIGHT_RANGE - 3, "claw shell top below tiles")
	end)

	t.test("가이드 9절: 장식이 시야 상자와 안 겹쳐요 (젠가·인형뽑기)", function()
		local function overlaps(a: Bounds, b: Bounds): boolean
			return a.min.x < b.max.x
				and a.max.x > b.min.x
				and a.min.y < b.max.y
				and a.max.y > b.min.y
				and a.min.z < b.max.z
				and a.max.z > b.min.z
		end
		local jv = JengaArt.courseVolume()
		for i, s in JengaArt.decor() do
			t.ok(not overlaps(MapKitLogic.bounds({ s }) :: any, jv), `jenga #{i} {s.name}`)
		end
		local cv = ClawArt.courseVolume()
		for i, s in ClawArt.decor() do
			t.ok(not overlaps(MapKitLogic.bounds({ s }) :: any, cv), `claw #{i} {s.name}`)
		end
	end)

	t.test("AC14: 소개 카메라 경로(경유점 사이)가 장식 상자를 지나가지 않아요", function()
		for _, m in MAPS do
			local path = {}
			for _, point in m.art.introCamera() do
				table.insert(path, { position = point.pos, lookAt = point.lookAt })
			end
			t.ok(#path >= 4, `{m.id}: 4 intro points`)
			local boxes = {}
			for _, s in m.art.decor() do
				-- 투명 앵커(파티클 자리)와 유리벽은 보이지 않거나 뚫어도 되는 판이라 빼요
				if (s.transparency or 0) < 0.85 then
					table.insert(boxes, { name = s.name, b = MapKitLogic.bounds({ s }) :: Bounds })
				end
			end
			local hits: { [string]: boolean } = {}
			for step = 0, 1000 do
				local p = IntroCameraLogic.sample(path, step / 1000).position
				for _, entry in boxes do
					if inside(p, entry.b) then
						hits[entry.name] = true
					end
				end
			end
			for name in hits do
				t.ok(false, `{m.id}: intro path passes through decor {name}`)
			end
		end
	end)
end
