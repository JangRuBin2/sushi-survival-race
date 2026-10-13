--!strict
-- m5-23 맵 비주얼 키트 + 미리보기 렌더러: 순수 로직 (AC1~AC9)

local serde = require("@lune/serde")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Png = require("../tools/render/Png")
local Raster = require("../tools/render/Raster")
local Scene = require("../tools/render/Scene")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapKitShapes = RobloxRequire.require(Shared.maps.MapKitShapes)
local MapFxPresets = RobloxRequire.require(Shared.maps.MapFxPresets)
local MapDecorAnimLogic = RobloxRequire.require(Shared.maps.MapDecorAnimLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local MapLightingLogic = RobloxRequire.require(Shared.maps.MapLightingLogic)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Maps = RobloxRequire.require(Shared.maps)
local LobbyLayout = RobloxRequire.require(Shared.LobbyLayout)

local ART_MODULES = {
	"BouncyCastleMazeArt",
	"CatCafeShelvesArt",
	"ChefBoardArt",
	"ClawMachinePrizeArt",
	"GiantJengaArt",
	"HotPlateArt",
	"LanternBridgeArt",
	"RamenRapidsArt",
	"RotatingBeltArt",
	"SkewerShowdownArt",
	"SoySwampArt",
	"TugOfWarPlatformArt",
}

local function base(extra: { [string]: any }?): any
	local spec: { [string]: any } = {
		name = "Test",
		shape = "Block",
		size = { x = 2, y = 2, z = 2 },
		color = { r = 200, g = 100, b = 50 },
		material = "SmoothPlastic",
		offset = { x = 0, y = 0, z = 0 },
	}
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end

local function many(n: number, extra: { [string]: any }?): { any }
	local list = {}
	for _ = 1, n do
		table.insert(list, base(extra))
	end
	return list
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local LIGHT = { kind = "Point", color = { r = 255, g = 220, b = 180 }, brightness = 1, range = 20 }

return function(t: Test.Test)
	-- AC1 ---------------------------------------------------------------------------------
	t.test(
		"AC1: 기존 Art.decor()·로비 장식이 새 validate를 그대로 통과, 예산 상수 그대로",
		function()
			for _, name in ART_MODULES do
				local art = RobloxRequire.require((Shared.maps :: any)[name])
				if type(art.decor) == "function" then
					t.eq(MapKitLogic.validate(art.decor()), nil, `{name}.decor()`)
				end
			end
			t.eq(MapKitLogic.validate(LobbyLayout.DECOR), nil, "lobby decor")
			t.eq(MapKitLogic.validate(LobbyLayout.STRUCTURE), nil, "lobby structure")
			t.eq(MapKitLogic.DECOR_PART_BUDGET, 600)
			t.eq(MapKitLogic.PARTICLE_BUDGET, 8)
			t.eq(MapKitLogic.LIGHT_BUDGET, 12)
			t.ok(table.find(MapKitLogic.SHAPES, "CornerWedge") ~= nil, "CornerWedge shape")
		end
	)

	-- AC2 ---------------------------------------------------------------------------------
	t.test("AC2: 새 필드 검사 — 잘못된 값은 이유, 올바른 값은 nil", function()
		local bad = {
			base({ shape = "Torus" }),
			base({ reflectance = 1.5 }),
			base({ light = { kind = "Point", color = LIGHT.color, brightness = 1, range = 80 } }),
			base({ light = { kind = "Laser", color = LIGHT.color, brightness = 1, range = 10 } }),
			base({ light = { kind = "Spot", color = LIGHT.color, brightness = 1, range = 10, face = "Up" } }),
			base({ particle = "Lava" }),
			base({ particle = "Steam", particleRate = 90 }),
			base({ anim = { kind = "Spin", period = 0, amount = 0 } }),
			base({ anim = { kind = "Wiggle", period = 2, amount = 1 } }),
			base({ anim = { kind = "Bob", period = 2, amount = 5 } }),
			base({ anim = { kind = "Sway", period = 2, amount = 25 } }),
			base({ anim = { kind = "Pulse", period = 2, amount = 0.2 } }),
			base({ castShadow = "yes" }),
		}
		for i, spec in bad do
			local problem = MapKitLogic.validate({ spec })
			t.ok(type(problem) == "string", `bad #{i} rejected ({tostring(problem)})`)
		end
		local good = base({
			shape = "CornerWedge",
			reflectance = 0.3,
			castShadow = false,
			light = {
				kind = "Spot",
				color = LIGHT.color,
				brightness = 2,
				range = 30,
				angle = 60,
				face = "Bottom",
				shadows = true,
			},
			particle = "Steam",
			particleRate = 5,
			anim = { kind = "Sway", period = 3, amount = 8, axis = "X" },
		})
		t.eq(MapKitLogic.validate({ good }), nil)
		t.eq(MapKitLogic.validate({ base({ anim = { kind = "Spin", period = 6, amount = 0 } }) }), nil)
	end)

	-- AC3 ---------------------------------------------------------------------------------
	t.test("AC3: checkBudget — Standard·Extended 경계", function()
		t.eq(MapKitLogic.checkBudget(many(600), "Standard"), nil)
		t.ok(MapKitLogic.checkBudget(many(601), "Standard") ~= nil, "601 parts over Standard")
		t.ok(MapKitLogic.checkBudget(many(601)) ~= nil, "default tier is Standard")
		t.eq(MapKitLogic.checkBudget(many(1500), "Extended"), nil)
		t.ok(MapKitLogic.checkBudget(many(1501), "Extended") ~= nil, "1501 parts over Extended")
		t.ok(MapKitLogic.checkBudget(many(25, { light = LIGHT }), "Extended") ~= nil, "25 lights")
		t.eq(MapKitLogic.checkBudget(many(24, { light = LIGHT }), "Extended"), nil)
		local shadowLight = table.clone(LIGHT) :: any
		shadowLight.shadows = true
		t.ok(MapKitLogic.checkBudget(many(3, { light = shadowLight }), "Extended") ~= nil, "3 shadowed lights")
		t.eq(MapKitLogic.checkBudget(many(2, { light = shadowLight }), "Extended"), nil)
		t.ok(MapKitLogic.checkBudget(many(17, { particle = "Steam" }), "Extended") ~= nil, "17 particles")
		local anim = { kind = "Bob", period = 2, amount = 1 }
		t.ok(MapKitLogic.checkBudget(many(81, { anim = anim }), "Extended") ~= nil, "81 animated")
		t.eq(MapKitLogic.checkBudget(many(80, { anim = anim }), "Extended"), nil)
		-- 맵 코드가 따로 붙인 조명도 셀 수 있어요
		t.ok(MapKitLogic.checkBudget(many(10, { light = LIGHT }), "Standard", { lights = 3 }) ~= nil, "extra lights")
	end)

	t.test("AC3: resolveCastShadow — nil이면 가장 긴 변 3 기준", function()
		t.eq(MapKitLogic.resolveCastShadow(base({ size = { x = 2.9, y = 1, z = 1 } })), false)
		t.eq(MapKitLogic.resolveCastShadow(base({ size = { x = 3, y = 1, z = 1 } })), true)
		t.eq(MapKitLogic.resolveCastShadow(base({ size = { x = 10, y = 1, z = 1 }, castShadow = false })), false)
		t.eq(MapKitLogic.resolveCastShadow(base({ size = { x = 1, y = 1, z = 1 }, castShadow = true })), true)
	end)

	t.test("팔레트 확장·shade·shades", function()
		for _, key in { "Ikura", "TempuraGold", "Batter", "CastIron", "Frost", "IceBlue", "Cream", "PastelPink" } do
			t.ok(MapKitLogic.PALETTE[key] ~= nil, `PALETTE.{key}`)
		end
		for name, c in MapKitLogic.PALETTE do
			t.eq(MapKitLogic.validate({ base({ color = c }) }), nil, `palette {name}`)
		end
		local s = MapKitLogic.shades(MapKitLogic.PALETTE.Wood)
		t.ok(s.light.r > s.base.r and s.dark.r < s.base.r, "light > base > dark")
		t.eq(MapKitLogic.shade({ r = 100, g = 100, b = 100 }, 0.5).r, 50)
		t.eq(MapKitLogic.shade({ r = 255, g = 255, b = 255 }, 1.5).g, 255)
	end)

	-- AC4 ---------------------------------------------------------------------------------
	t.test("AC4: 파티클 프리셋 — 필수 키, 기본 텍스처", function()
		t.ok(#MapFxPresets.NAMES >= 12, "12 presets")
		for _, name in
			{
				"Steam",
				"SteamThick",
				"Bubbles",
				"OilBubbles",
				"Sparkle",
				"Frost",
				"ColdMist",
				"Embers",
				"SeaSpray",
				"Dust",
				"Petals",
				"Confetti",
			}
		do
			local preset = MapFxPresets.PRESETS[name]
			t.ok(preset ~= nil, `preset {name}`)
			t.eq(MapFxPresets.validate(preset), nil, name)
			t.eq(string.sub(preset.Texture, 1, 11), "rbxasset://", `{name} texture`)
		end
	end)

	-- AC5 ---------------------------------------------------------------------------------
	t.test("AC5: 모양 헬퍼 — validate 통과, 결정적, roundedBox 경계", function()
		local P = MapKitLogic.PALETTE
		local o = { x = 3, y = 2, z = -5 }
		local function all(): { { any } }
			return {
				MapKitShapes.roundedBox("RB", { x = 6, y = 3, z = 4 }, P.Wood, "Wood", o),
				MapKitShapes.roundedBox("RBV", { x = 6, y = 3, z = 4 }, P.Wood, "Wood", o, { style = "vertical" }),
				MapKitShapes.roundedBox(
					"RBR",
					{ x = 6, y = 3, z = 4 },
					P.Wood,
					"Wood",
					o,
					{ rotation = { x = 0, y = 30, z = 0 } }
				),
				MapKitShapes.bevelBox("BB", { x = 5, y = 2, z = 3 }, P.Iron, "Metal", o, 0.4),
				MapKitShapes.rimDisc("RD", 8, 0.6, P.Porcelain, "SmoothPlastic", o, { rimColor = P.PorcelainRim }),
				MapKitShapes.ring("RG", 5, 0.5, 1, 12, P.Lacquer, "Wood", o),
				MapKitShapes.capsule("CP", 6, 2, P.Salmon, "SmoothPlastic", o, { x = 0, y = 0, z = 90 }),
				MapKitShapes.lipTrim("LT", { x = 10, y = 0, z = 6 }, 0.4, 0.5, P.Nori, "Slate", o),
				MapKitShapes.scatter(7, 10, { center = o, size = { x = 30, y = 0, z = 20 } }, function(i, pos, _rng)
					return { base({ name = `S{i}`, offset = pos }) }
				end),
			}
		end
		local first, second = all(), all()
		for i, list in first do
			t.ok(#list > 0, `helper #{i} not empty`)
			t.eq(MapKitLogic.validate(list), nil, `helper #{i} valid`)
			t.eq(serde.encode("json", list), serde.encode("json", second[i]), `helper #{i} deterministic`)
		end
		local b = MapKitLogic.bounds(first[1]) :: any
		t.ok(
			near(b.max.x - b.min.x, 6, 0.01) and near(b.max.y - b.min.y, 3, 0.01) and near(b.max.z - b.min.z, 4, 0.01),
			"roundedBox size"
		)
		t.ok(near((b.max.x + b.min.x) / 2, 3, 0.01) and near((b.max.z + b.min.z) / 2, -5, 0.01), "roundedBox center")
		local bv = MapKitLogic.bounds(first[2]) :: any
		t.ok(near(bv.max.x - bv.min.x, 6, 0.01) and near(bv.max.z - bv.min.z, 4, 0.01), "vertical roundedBox size")
		local bb = MapKitLogic.bounds(first[4]) :: any
		t.ok(near(bb.max.y - bb.min.y, 2, 0.01) and near(bb.max.x - bb.min.x, 5, 0.01), "bevelBox size")
		local cp = MapKitLogic.bounds(first[7]) :: any
		t.ok(near(cp.max.y - cp.min.y, 6, 0.01), "capsule rotated to Y, length 6")
		-- 다른 seed면 다른 배치
		local other = MapKitShapes.scatter(
			8,
			10,
			{ center = o, size = { x = 30, y = 0, z = 20 } },
			function(i, pos, _rng)
				return { base({ name = `S{i}`, offset = pos }) }
			end
		)
		t.ok(serde.encode("json", other) ~= serde.encode("json", first[9]), "seed changes scatter")
	end)

	t.test("transform: 회전이 합쳐져도 경계 상자가 맞아요", function()
		local rotated = MapKitShapes.transform(
			{ base({ size = { x = 4, y = 1, z = 1 }, rotation = { x = 0, y = 0, z = 90 } }) },
			{ x = 0, y = 0, z = 0 },
			{ x = 0, y = 90, z = 0 }
		)
		local b = MapKitLogic.bounds(rotated) :: any
		t.ok(near(b.max.y - b.min.y, 4, 1e-3), "still 4 tall after yaw")
	end)

	-- AC6 ---------------------------------------------------------------------------------
	t.test("AC6: MapDecorAnimLogic.offset — 주기·최대값", function()
		for _, kind in { "Spin", "Bob", "Sway", "Pulse" } do
			local a = MapDecorAnimLogic.offset(kind, 3, 0.1, nil, 0, 0.25)
			local b = MapDecorAnimLogic.offset(kind, 3, 0.1, nil, 3, 0.25)
			for _, key in { "dx", "dy", "dz", "rx", "ry", "rz", "scale" } do
				local va, vb = (a :: any)[key], (b :: any)[key]
				local ok = near(va, vb, 1e-6) or (kind == "Spin" and near(math.abs(va - vb), 2 * math.pi, 1e-6))
				t.ok(ok, `{kind}.{key} periodic`)
			end
		end
		local maxBob, maxSway, minPulse, maxPulse = 0, 0, math.huge, -math.huge
		for i = 0, 200 do
			local time = i / 200 * 4
			maxBob = math.max(maxBob, math.abs(MapDecorAnimLogic.offset("Bob", 4, 2, nil, time, 0).dy))
			maxSway = math.max(maxSway, math.abs(math.deg(MapDecorAnimLogic.offset("Sway", 4, 12, nil, time, 0).rz)))
			local s = MapDecorAnimLogic.offset("Pulse", 4, 0.1, nil, time, 0).scale
			minPulse, maxPulse = math.min(minPulse, s), math.max(maxPulse, s)
		end
		t.ok(near(maxBob, 2, 1e-3), `Bob max {maxBob}`)
		t.ok(near(maxSway, 12, 1e-2), `Sway max {maxSway}`)
		t.ok(minPulse >= 0.9 - 1e-9 and maxPulse <= 1.1 + 1e-9, "Pulse in 1 ± 0.1")
		local phase = MapDecorAnimLogic.phaseOf(10.5, 3, -20)
		t.ok(phase >= 0 and phase < 1, "phase 0~1")
		t.eq(MapDecorAnimLogic.phaseOf(10.5, 3, -20), phase)
	end)

	-- AC7 ---------------------------------------------------------------------------------
	t.test("AC7: MapLighting — 프리셋·로비 검사, lerp, 시계 짧은 쪽", function()
		for id, preset in MapLighting.PRESETS do
			t.eq(MapLighting.validate(preset), nil, id)
			local lighting = Maps.get(id).lighting -- m5-24: 맵이 Art.LIGHTING으로 옮겨 다듬을 수 있어요
			t.ok(lighting ~= nil and MapLighting.validate(lighting) == nil, `{id} has a valid lighting preset`)
		end
		for _, id in { "rotating-belt", "soy-swamp", "ramen-rapids", "hot-plate", "chef-board", "skewer-showdown" } do
			t.ok(MapLighting.PRESETS[id] ~= nil, `preset {id}`)
		end
		t.eq(MapLighting.validate(MapLighting.LOBBY), nil, "LOBBY")
		local a = MapLighting.LOBBY
		local b = MapLighting.resolve(MapLighting.PRESETS["hot-plate"])
		t.eq(serde.encode("json", MapLighting.lerp(a, b, 0)), serde.encode("json", a))
		t.eq(serde.encode("json", MapLighting.lerp(a, b, 1)), serde.encode("json", b))
		local late = MapLighting.resolve({ ClockTime = 23 })
		local early = MapLighting.resolve({ ClockTime = 1 })
		local mid = MapLighting.lerp(late, early, 0.5).ClockTime
		t.ok(near(mid, 0, 1e-6) or near(mid, 24, 1e-6), `23 → 1 passes midnight ({mid})`)
		t.ok(MapLighting.validate({ ClockTime = 30 }) ~= nil, "ClockTime 30")
		t.ok(MapLighting.validate({ Fog = 1 }) ~= nil, "unknown key")
		t.ok(MapLighting.validate({ Atmosphere = { Density = 2 } }) ~= nil, "density 2")
		-- 빠진 키는 로비 값
		t.eq(MapLighting.resolve({ ClockTime = 9 }).Bloom.Intensity, MapLighting.LOBBY.Bloom.Intensity)
		local fake = table.clone(Maps.get("hot-plate")) :: any
		fake.lighting = { ClockTime = 30 }
		t.ok(MapTypes.validate(fake) ~= nil, "MapTypes rejects bad lighting")
		fake.lighting = nil
		t.eq(MapTypes.validate(fake), nil, "lighting optional")
	end)

	-- AC8 ---------------------------------------------------------------------------------
	t.test("AC8: pickArena — 들어가기 40, 나가기 80, 가까운 쪽", function()
		local arena = { key = "A", center = { x = 0, y = 300, z = 0 }, size = { x = 100, y = 40, z = 100 } }
		local arenas = { arena }
		t.eq(MapLightingLogic.pickArena({ x = 0, y = 300, z = 0 }, arenas, nil), "A")
		t.eq(MapLightingLogic.pickArena({ x = 50 + 39, y = 300, z = 0 }, arenas, nil), "A")
		t.eq(MapLightingLogic.pickArena({ x = 50 + 60, y = 300, z = 0 }, arenas, nil), nil, "60 out: not entered")
		t.eq(MapLightingLogic.pickArena({ x = 50 + 60, y = 300, z = 0 }, arenas, "A"), "A", "60 out: stays")
		t.eq(MapLightingLogic.pickArena({ x = 50 + 81, y = 300, z = 0 }, arenas, "A"), nil, "81 out: leaves")
		t.eq(MapLightingLogic.pickArena({ x = 0, y = 0, z = 0 }, arenas, nil), nil, "lobby far below")
		local b = { key = "B", center = { x = 180, y = 300, z = 0 }, size = { x = 100, y = 40, z = 100 } }
		t.eq(MapLightingLogic.pickArena({ x = 85, y = 300, z = 0 }, { arena, b }, nil), "A", "closer arena")
		t.eq(MapLightingLogic.pickArena({ x = 100, y = 300, z = 0 }, { arena, b }, nil), "B", "closer arena B")
		t.eq(MapLightingLogic.blendAlpha(0), 0)
		t.eq(MapLightingLogic.blendAlpha(MapLightingLogic.BLEND_SECONDS), 1)
	end)

	-- AC9 ---------------------------------------------------------------------------------
	t.test("AC9: 래스터 — 삼각형 픽셀 수, z-버퍼", function()
		local W, H = 100, 100
		local zb = buffer.create(W * H * 4)
		for i = 0, W * H - 1 do
			buffer.writef32(zb, i * 4, 1e30)
		end
		local covered = 0
		local function count(idx: number, _px: number, _py: number, z: number)
			covered += 1
			buffer.writef32(zb, idx * 4, z)
		end
		-- { sx, sy, q, zq, nx, ny, nz } (직교: q = 1, zq = 깊이)
		Raster.rasterTri(
			W,
			H,
			{ 0, 0, 1, 10, 0, 1, 0 },
			{ 100, 0, 1, 10, 0, 1, 0 },
			{ 0, 100, 1, 10, 0, 1, 0 },
			zb,
			count
		)
		t.ok(math.abs(covered - 5000) / 5000 <= 0.02, `coverage {covered} ≈ 5000`)
		-- 더 가까운(깊이 5) 사각형 절반을 덮으면 남고, 먼(깊이 20) 것은 안 써져요
		local wrote = 0
		Raster.rasterTri(W, H, { 0, 0, 1, 5, 0, 1, 0 }, { 50, 0, 1, 5, 0, 1, 0 }, { 0, 50, 1, 5, 0, 1, 0 }, zb, count)
		Raster.rasterTri(
			W,
			H,
			{ 0, 0, 1, 20, 0, 1, 0 },
			{ 100, 0, 1, 20, 0, 1, 0 },
			{ 0, 100, 1, 20, 0, 1, 0 },
			zb,
			function()
				wrote += 1
			end
		)
		t.eq(wrote, 0, "farther triangle hidden")
		t.ok(near(buffer.readf32(zb, (10 * W + 10) * 4), 5), "near depth kept")
		t.ok(near(buffer.readf32(zb, (10 * W + 80) * 4), 10), "first triangle depth kept")
	end)

	t.test("AC9: PNG — 시그니처·IHDR·CRC·데이터", function()
		local one = buffer.create(3)
		buffer.writeu8(one, 0, 255)
		local png = Png.encode(1, 1, one)
		t.eq(string.sub(png, 1, 8), "\137PNG\r\n\26\n")
		t.eq(string.sub(png, 9, 16), "\0\0\0\13IHDR")
		t.eq(string.sub(png, 17, 29), "\0\0\0\1\0\0\0\1\8\2\0\0\0")
		-- 1×1 RGB IHDR의 잘 알려진 CRC 90 77 53 DE
		t.eq(string.sub(png, 30, 33), "\x90\x77\x53\xDE")
		local two = buffer.create(12)
		for i = 0, 11 do
			buffer.writeu8(two, i, i * 20)
		end
		local png2 = Png.encode(2, 2, two)
		local idatLen = string.unpack(">I4", png2, 34)
		t.eq(string.sub(png2, 38, 41), "IDAT")
		local raw = serde.decompress("zlib", string.sub(png2, 42, 41 + idatLen))
		local expected = "\0"
			.. string.char(0, 20, 40, 60, 80, 100)
			.. "\0"
			.. string.char(120, 140, 160, 180, 200, 220)
		t.eq(raw, expected, "rows with filter byte 0")
		t.eq(string.sub(png2, -12), "\0\0\0\0IEND\xAE\x42\x60\x82", "IEND chunk")
	end)

	t.test("AC9: 같은 장면 두 번 렌더 → 같은 바이트", function()
		local roblox = require("@lune/roblox")
		local function render(): string
			local scene = Scene.new()
			Scene.addBox(
				scene,
				roblox.CFrame.new(0, 0, 0),
				roblox.Vector3.new(20, 1, 20),
				{ 0.8, 0.6, 0.4 },
				"WoodPlanks"
			)
			Scene.addBox(
				scene,
				roblox.CFrame.new(0, 3, 0),
				roblox.Vector3.new(4, 4, 4),
				{ 0.9, 0.2, 0.2 },
				"SmoothPlastic",
				{ shape = "Ball" }
			)
			Scene.addBox(scene, roblox.CFrame.new(5, 2, 2), roblox.Vector3.new(3, 3, 3), { 0.2, 0.9, 0.9 }, "Neon")
			local cam = Raster.perspective({ x = 20, y = 15, z = 20 }, { x = 0, y = 0, z = 0 }, 70, 16 / 9)
			local image = Raster.render(scene, cam, MapLighting.LOBBY, { -12, -2, -12, 12, 8, 12 }, {
				width = 64,
				height = 36,
				supersample = 2,
				shadowSize = 256,
			})
			return buffer.tostring(image.rgb)
		end
		local a, b = render(), render()
		t.eq(#a, 64 * 36 * 3)
		t.ok(a == b, "deterministic")
	end)
end
