--!strict
-- m5-24 그룹 D 아트 패스 v2 (bouncy-castle-maze · lantern-bridge · cat-cafe-shelves): 순수 로직 확인.
-- AC2 Extended 예산(+ build의 Instance.new 조명·파티클), AC3 validate, AC4 lighting = Art.LIGHTING·로비와 다름,
-- AC5 등불 다리 판자 구간에 anim 장식 없음, 소개 경로가 장식 속을 안 지남(m4-02 Q1 방식),
-- 배경 바닥이 낙하선보다 10 이상 아래, 장식이 판정 바닥 높이 ±1에 판정 바닥과 붙은 수평 판이 아님.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Maps = RobloxRequire.require(Shared.maps)

local BouncyArt = RobloxRequire.require(Shared.maps.BouncyCastleMazeArt)
local BouncyLayout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)
local LanternArt = RobloxRequire.require(Shared.maps.LanternBridgeArt)
local LanternLayout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local CatArt = RobloxRequire.require(Shared.maps.CatCafeShelvesArt)
local CatLayout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)

type Spec = MapKitLogic.DecorSpec

local function countNamed(specs: { Spec }, name: string): number
	local n = 0
	for _, s in specs do
		if s.name == name then
			n += 1
		end
	end
	return n
end

local function introHits(art: any): { string }
	local path = {}
	for _, point in art.introCamera() do
		table.insert(path, { position = point.pos, lookAt = point.lookAt })
	end
	local boxes = {}
	for _, spec in art.decor() do
		table.insert(boxes, { name = spec.name, b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds })
	end
	local hits: { [string]: boolean } = {}
	local steps = 2000
	for s = 0, steps do
		local p = IntroCameraLogic.sample(path, s / steps).position
		for _, entry in boxes do
			local b = entry.b
			if
				p.x > b.min.x
				and p.x < b.max.x
				and p.y > b.min.y
				and p.y < b.max.y
				and p.z > b.min.z
				and p.z < b.max.z
			then
				hits[entry.name] = true
			end
		end
	end
	local out = {}
	for name in hits do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- 가장 낮은 큰 바닥판(가로·세로 400 이상)의 윗면 높이
local function groundTop(specs: { Spec }): number?
	local best: number? = nil
	for _, s in specs do
		if s.size.x >= 400 and s.size.z >= 400 and s.size.y <= 4 then
			local top = s.offset.y + s.size.y / 2
			if best == nil or top < best then
				best = top
			end
		end
	end
	return best
end

local MAPS = {
	{
		id = "bouncy-castle-maze",
		art = BouncyArt,
		-- build가 Instance.new로 붙이는 조명 (CarnivalLamp마다 PointLight 하나)
		extraLights = function(specs: { Spec }): number
			return countNamed(specs, BouncyArt.LAMP)
		end,
		extraParticles = function(_specs: { Spec }): number
			return 0
		end,
		fallY = -BouncyLayout.FALL_DEPTH,
	},
	{
		id = "lantern-bridge",
		art = LanternArt,
		extraLights = function(specs: { Spec }): number
			return countNamed(specs, LanternArt.LANTERN)
		end,
		extraParticles = function(_specs: { Spec }): number
			return 0
		end,
		fallY = -LanternLayout.FALL_MARGIN,
	},
	{
		id = "cat-cafe-shelves",
		art = CatArt,
		extraLights = function(specs: { Spec }): number
			return countNamed(specs, CatArt.WINDOW_LIGHT)
		end,
		extraParticles = function(specs: { Spec }): number
			return countNamed(specs, CatArt.SUNBEAM)
		end,
		fallY = CatLayout.ELIMINATION_Y,
	},
}

return function(t: Test.Test)
	t.test(
		"m5-24 D AC2·AC3: 3맵 Art.BUDGET Extended, validate 통과, build 조명·파티클 포함 예산 안",
		function()
			for _, m in MAPS do
				local specs = m.art.decor()
				t.eq(m.art.BUDGET, "Extended", `{m.id} BUDGET`)
				t.eq(MapKitLogic.validate(specs), nil, `{m.id} validate`)
				t.eq(
					MapKitLogic.checkBudget(
						specs,
						"Extended",
						{ lights = m.extraLights(specs), particles = m.extraParticles(specs) }
					),
					nil,
					`{m.id} Extended budget`
				)
				-- 가이드 8절 목표 밀도(700~1300 근처) — 너무 얇지 않게
				t.ok(#specs >= 500, `{m.id} decor density {#specs}`)
				-- 가이드 7절 생동감: 파티클 2종(빌드 포함) 이상, 움직임 3개 이상
				t.ok(MapKitLogic.countAnimated(specs) >= 3, `{m.id} anim >= 3`)
			end
		end
	)

	t.test(
		"m5-24 D AC4: lighting == Art.LIGHTING, validate 통과, 로비와 ClockTime·Atmosphere.Color가 달라요",
		function()
			for _, m in MAPS do
				local map = Maps.get(m.id)
				t.ok(map.lighting ~= nil and map.lighting == m.art.LIGHTING, `{m.id} uses Art.LIGHTING`)
				t.eq(MapTypes.validate(map), nil, `{m.id} MapTypes.validate`)
				t.eq(MapLighting.validate(m.art.LIGHTING), nil, `{m.id} MapLighting.validate`)
				local resolved = MapLighting.resolve(m.art.LIGHTING)
				local lobby = MapLighting.LOBBY
				local sameClock = resolved.ClockTime == lobby.ClockTime
				local a, b = resolved.Atmosphere.Color, lobby.Atmosphere.Color
				local sameAtmo = a.r == b.r and a.g == b.g and a.b == b.b
				t.ok(not (sameClock and sameAtmo), `{m.id} differs from lobby`)
			end
		end
	)

	t.test(
		"m5-24 D AC5: 등불 다리 판자 구간(|x| ≤ 폭/2+1, y -3~5) 안에 anim 장식이 없어요",
		function()
			for _, spec in LanternArt.decor() do
				if spec.anim then
					local o = spec.offset
					for _, bridge in LanternLayout.BRIDGES do
						local inside = math.abs(o.x) <= bridge.halfWidth + 1
							and o.y >= -3
							and o.y <= 5
							and o.z <= bridge.front
							and o.z >= bridge.back
						t.ok(not inside, `animated {spec.name} sits on bridge {bridge.index}`)
					end
				end
			end
		end
	)

	t.test(
		"m5-24 D: 소개 카메라 경로(경유점 사이)가 장식 속을 지나가지 않아요 (m4-02 Q1 방식)",
		function()
			for _, m in MAPS do
				local hits = introHits(m.art)
				t.eq(hits, {}, `{m.id} intro path through decor`)
			end
		end
	)

	t.test(
		"m5-24 D: 배경 바닥 윗면이 낙하·탈락선보다 10 이상 아래예요 (체크리스트 16)",
		function()
			for _, m in MAPS do
				local top = groundTop(m.art.decor())
				t.ok(top ~= nil, `{m.id} has a ground plane`)
				if top then
					t.ok(top <= m.fallY - 10, `{m.id} ground top {top} vs fall {m.fallY}`)
				end
			end
		end
	)

	t.test("m5-24 D: 이름으로 센 기존 장식 개수 유지 (Lantern 12, WindowLight 2, Sunbeam 2)", function()
		local lantern = LanternArt.decor()
		t.eq(countNamed(lantern, LanternArt.LANTERN), 12)
		local cat = CatArt.decor()
		t.eq(countNamed(cat, CatArt.WINDOW_LIGHT), 2)
		t.eq(countNamed(cat, CatArt.SUNBEAM), 2)
		t.ok(countNamed(BouncyArt.decor(), BouncyArt.LAMP) > 0, "carnival lamps kept")
	end)

	t.test(
		"m5-24 D: 고양이 카페 장식이 선반 윗면 위 시야(선반 위 0.2~6)를 가리지 않아요",
		function()
			-- 선반마다 윗면 위 상자와 장식 상자가 겹치면 안 돼요 (기존 m5-17 소품 — 바구니·쿠션·캣방석·발자국 —
			-- 는 선반 위 소품으로 원래 있던 것이라 이름으로 빼요)
			local allowed: { [string]: boolean } = {
				ToyBasket = true,
				YarnBall = true,
				Cushion = true,
				CatBed = true,
				CatBedRim = true,
				PawPrint = true,
			}
			for _, spec in CatArt.decor() do
				if not allowed[spec.name] then
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					for _, shelf in CatLayout.shelves() do
						local sx = if shelf.axis == "X" then shelf.length else shelf.width
						local sz = if shelf.axis == "X" then shelf.width else shelf.length
						local overlap = b.max.x > shelf.centerX - sx / 2
							and b.min.x < shelf.centerX + sx / 2
							and b.max.z > shelf.centerZ - sz / 2
							and b.min.z < shelf.centerZ + sz / 2
							and b.max.y > shelf.topY + 0.2
							and b.min.y < shelf.topY + 6
						t.ok(not overlap, `{spec.name} covers {shelf.key}`)
					end
				end
			end
		end
	)
end
