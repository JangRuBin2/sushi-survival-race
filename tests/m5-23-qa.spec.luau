--!strict
-- m5-23 QA (docs/qa/m5-23-map-visual-kit.md): 개발 테스트(m5-23-visual-kit)에 없는 경계값과
-- 미리보기 렌더러의 가짜 Roblox 환경(tools/render/Shims — 진짜 @lune/roblox 인스턴스)으로 실제로 지어 보는 확인.
--   MapLighting.validate / MapTypes.validate: 잘못된 조명 입력(NaN·inf·문자열·모르는 키·색 범위·배열)
--   MapLighting.resolve / lerp: 프리셋·LOBBY를 바꾸지 않음, t 범위 밖 clamp, 시계 거꾸로 짧은 쪽
--   MapLightingLogic.pickArena: 경계 정확히, 아래쪽 여유, 현재 아레나가 사라짐, 겹친 아레나에서 현재 유지
--   실제 맵 15개를 한 플레이스 슬롯 1·2에 지어 MapLightingController와 같은 방식으로 아레나 상자를 재고:
--       로비가 어느 아레나에도 안 걸림, 슬롯끼리 안 겹침, 스폰 24개·소개 카메라 경유점이 그 아레나로 잡힘
--   checkBudget: extra(Instance.new 조명·파티클·파츠), 단계별 정확한 경계, 모르는 단계는 Standard
--   validateExtras 추가 경계 (NaN, 181°, 빈 face, Spin amount nil 등)
--   MapDecorAnimLogic: 큰 서버 시각에서도 주기, 위상 0~1, 축별 성분
--   MapKit.buildDecor·makeEmitter·makeLight를 진짜 인스턴스로: 클래스·속성·태그·자식
--   소스 확인: RoundService 태그 순서, MapLightingController·MapDecorFxController에 TweenService/서버 쓰기 없음

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapKitShapes = RobloxRequire.require(Shared.maps.MapKitShapes)
local MapDecorAnimLogic = RobloxRequire.require(Shared.maps.MapDecorAnimLogic)
local MapFxPresets = RobloxRequire.require(Shared.maps.MapFxPresets)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local MapLightingLogic = RobloxRequire.require(Shared.maps.MapLightingLogic)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Maps = RobloxRequire.require(Shared.maps)
local LobbyLayout = RobloxRequire.require(Shared.LobbyLayout)
local Config = RobloxRequire.require(Shared.Config)

-- 렌더러 환경 (진짜 Instance)
local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)
local RMapKit = Shims.require(RShared.maps.MapKit)
local roblox = require("@lune/roblox")

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function base(extra: { [string]: any }?): any
	local spec: { [string]: any } = {
		name = "Q",
		shape = "Block",
		size = { x = 4, y = 4, z = 4 },
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

local LIGHT = { kind = "Point", color = { r = 255, g = 200, b = 150 }, brightness = 1, range = 10 }

local function vec(x: number, y: number, z: number): any
	return { x = x, y = y, z = z }
end

-- MapLightingController.measure와 같은 계산 (판정 파츠, Decor·IntroCamera 밖, 반지름 = Size.Magnitude/2)
local function measure(model: any): (any, any)
	local minV, maxV = nil, nil
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local parent = d.Parent
		local skip = false
		local introPoint = false
		while parent and parent ~= model do
			if parent.Name == "Decor" then
				skip = true
				break
			elseif parent.Name == "IntroCamera" then
				introPoint = true -- 소개 경유점은 크기 없이 점으로 (QA B2: 소개 첫 컷부터 맵 조명)
			end
			parent = parent.Parent
		end
		if skip then
			continue
		end
		local half = if introPoint then 0 else d.Size.Magnitude / 2
		local p = d.CFrame.Position
		local lo = p - roblox.Vector3.new(half, half, half)
		local hi = p + roblox.Vector3.new(half, half, half)
		minV = if minV then minV:Min(lo) else lo
		maxV = if maxV then maxV:Max(hi) else hi
	end
	assert(minV and maxV, "model has no judgment parts")
	local c, s = (minV + maxV) / 2, maxV - minV
	return vec(c.X, c.Y, c.Z), vec(s.X, s.Y, s.Z)
end

local function v3(p: any): any
	return vec(p.X, p.Y, p.Z)
end

-- 실제 맵을 슬롯에 지어요 (렌더러 환경). 결과는 맵마다 한 번만 만들어요.
local built: { [string]: { [number]: any } } = {}
local function buildAt(mapId: string, slot: number): any
	built[mapId] = built[mapId] or {}
	if built[mapId][slot] == nil then
		local map = RMaps.get(mapId)
		local origin = roblox.CFrame.new(slot * Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
		local model = map.build(origin)
		local center, size = measure(model)
		built[mapId][slot] = { model = model, center = center, size = size, origin = origin }
	end
	return built[mapId][slot]
end

-- 맵 아트 모듈의 예산 단계 (<Map>Art.BUDGET, 없으면 Standard). tools/render-map.luau budgetTier와 같은 규칙.
local function artBudgetTier(id: string): any
	local pascal = (string.gsub("-" .. id, "%-(%w)", string.upper))
	local ok, art = pcall(function()
		return RobloxRequire.require((Shared.maps :: any)[pascal .. "Art"])
	end)
	if ok and type(art) == "table" and type(art.BUDGET) == "string" then
		return art.BUDGET
	end
	return "Standard"
end

-- m5-24 D4: 아트 패스 v2를 마친 맵은 <Map>Art.LIGHTING을 가져요 (없으면 nil → 아직 m5-23 프리셋)
local function artModule(id: string): any
	local pascal = (string.gsub("-" .. id, "%-(%w)", string.upper))
	local ok, art = pcall(function()
		return RobloxRequire.require((Shared.maps :: any)[pascal .. "Art"])
	end)
	return if ok and type(art) == "table" then art else nil
end

local function allIds(): { string }
	local ids = {}
	for _, info in Maps.allInfos() do
		table.insert(ids, info.id)
	end
	table.sort(ids)
	return ids
end

-- B1: MapLightingController가 판정 파츠만으로 아레나 상자를 재서, 높이 띄운 소개 경유점이 상자 + 40 밖에 있어요
-- (소개 첫 컷이 로비 조명). MapLightingController.measure가 IntroCamera 점을 상자에 넣으면 이 표를 비워요.
local KNOWN_INTRO_OUTSIDE: { [string]: boolean } = {}

local function read(path: string): string
	return fs.readFile(path)
end

return function(t: Test.Test)
	------------------------------------------------------------------ MapLighting.validate
	t.test("QA lighting: validate가 잘못된 입력을 모두 거절 (이유 문자열)", function()
		local nan = 0 / 0
		local bad: { any } = {
			"evening",
			42,
			true,
			{ ClockTime = nan },
			{ ClockTime = math.huge },
			{ ClockTime = -0.01 },
			{ ClockTime = 24.01 },
			{ ClockTime = "17" },
			{ Brightness = 11 },
			{ ExposureCompensation = -3.5 },
			{ GeographicLatitude = 91 },
			{ ShadowSoftness = 1.2 },
			{ Ambient = { r = 256, g = 0, b = 0 } },
			{ Ambient = { r = 10, g = 10 } },
			{ Ambient = "red" },
			{ OutdoorAmbient = { r = -1, g = 0, b = 0 } },
			{ Atmosphere = 0.3 },
			{ Atmosphere = { Density = 1.5 } },
			{ Atmosphere = { Densty = 0.3 } }, -- 오타
			{ Atmosphere = { Color = { r = 0, g = 0, b = 300 } } },
			{ ColorCorrection = { Saturation = -1.5 } },
			{ ColorCorrection = { TintColor = 5 } },
			{ Bloom = { Size = 57 } },
			{ Bloom = { Intensity = nan } },
			{ SunRays = { Spread = 2 } },
			{ Fog = 1 }, -- 모르는 키
			{ Sky = "rbxassetid://1" }, -- 아직 없는 키
			{ 1, 2, 3 }, -- 배열
			{ Atmosphere = { 0.3 } }, -- 그룹 안 배열
		}
		for i, preset in bad do
			local problem = MapLighting.validate(preset)
			t.ok(type(problem) == "string" and #problem > 0, `bad #{i} rejected ({tostring(problem)})`)
		end
	end)

	t.test("QA lighting: 경계값(0·24·0~255·빈 표·일부 그룹)은 통과", function()
		local good: { any } = {
			{},
			{ ClockTime = 0 },
			{ ClockTime = 24 },
			{ Ambient = { r = 0, g = 0, b = 0 }, OutdoorAmbient = { r = 255, g = 255, b = 255 } },
			{ Atmosphere = {} },
			{ Atmosphere = { Density = 0 }, Bloom = { Threshold = 4 } },
			{ ColorCorrection = { Brightness = -1, Contrast = 1 } },
		}
		for i, preset in good do
			t.eq(MapLighting.validate(preset), nil, `good #{i}`)
		end
	end)

	t.test("QA lighting: MapTypes.validate가 맵 id와 함께 잘못된 lighting을 거절", function()
		local map = deepCopy(Maps.get("hot-plate"))
		-- 함수는 deepCopy가 그대로 둬요
		map.lighting = { ClockTime = 30 }
		local problem = MapTypes.validate(map)
		t.ok(type(problem) == "string" and string.find(problem, "hot-plate", 1, true) ~= nil, tostring(problem))
		map.lighting = "night"
		t.ok(type(MapTypes.validate(map)) == "string", "string lighting rejected")
		map.lighting = { Atmosphere = { Haze = -1 } }
		t.ok(type(MapTypes.validate(map)) == "string", "group value rejected")
		map.lighting = nil
		t.eq(MapTypes.validate(map), nil, "nil lighting ok (lobby)")
		map.lighting = {}
		t.eq(MapTypes.validate(map), nil, "empty lighting ok")
	end)

	t.test("QA lighting: 풀의 모든 맵이 validate 통과, 기존 6개는 프리셋을 씀", function()
		for _, id in allIds() do
			local map = Maps.get(id)
			t.eq(MapTypes.validate(map), nil, id)
		end
		for _, id in { "rotating-belt", "soy-swamp", "ramen-rapids", "hot-plate", "chef-board", "skewer-showdown" } do
			-- m5-24 D4: 아트 패스 v2를 마친 맵(Art.LIGHTING 있음)은 그 값을, 아직인 맵은 m5-23 프리셋을 그대로 써요
			local art = artModule(id)
			if art and art.LIGHTING ~= nil then
				t.ok(Maps.get(id).lighting == art.LIGHTING, `{id} uses Art.LIGHTING (m5-24)`)
			else
				t.ok(Maps.get(id).lighting == MapLighting.PRESETS[id], `{id} uses PRESETS`)
			end
		end
	end)

	t.test("QA lighting: resolve·lerp는 PRESETS·LOBBY를 바꾸지 않음", function()
		local before = deepCopy(MapLighting.PRESETS["hot-plate"])
		local lobbyBefore = deepCopy(MapLighting.LOBBY)
		local r = MapLighting.resolve(MapLighting.PRESETS["hot-plate"])
		r.Atmosphere.Color.r = 1
		r.Ambient.g = 2
		r.Bloom.Intensity = 1.9
		local mid = MapLighting.lerp(MapLighting.LOBBY, r, 0.5)
		mid.Atmosphere.Density = 0.99
		mid.ColorCorrection.TintColor.b = 3
		t.eq(MapLighting.PRESETS["hot-plate"], before, "preset untouched")
		t.eq(MapLighting.LOBBY, lobbyBefore, "LOBBY untouched")
		-- resolve(nil)은 매번 새 표
		local a, b = MapLighting.resolve(nil), MapLighting.resolve(nil)
		t.ok(a ~= b and a.Atmosphere ~= b.Atmosphere, "resolve returns fresh tables")
	end)

	t.test("QA lighting: lerp t 범위 밖은 clamp, 시계는 거꾸로도 짧은 쪽", function()
		local a = MapLighting.resolve({ ClockTime = 1 })
		local b = MapLighting.resolve({ ClockTime = 23, Brightness = 4 })
		t.eq(MapLighting.lerp(a, b, -1), a, "t < 0 → a")
		t.eq(MapLighting.lerp(a, b, 2), b, "t > 1 → b")
		local mid = MapLighting.lerp(a, b, 0.5)
		t.ok(
			math.abs(mid.ClockTime - 0) < 1e-9 or math.abs(mid.ClockTime - 24) < 1e-9,
			`1→23 via 0 ({mid.ClockTime})`
		)
		local q = MapLighting.lerp(a, b, 0.25)
		t.ok(math.abs(q.ClockTime - 0.5) < 1e-9, `quarter 0.5 ({q.ClockTime})`)
		t.ok(math.abs(mid.Brightness - (a.Brightness + b.Brightness) / 2) < 1e-9, "brightness linear")
		-- 모든 lerp 결과는 다시 validate 통과 (Roblox 속성 범위 안)
		for _, id in { "rotating-belt", "hot-plate", "skewer-showdown", "chef-board" } do
			local p = MapLighting.resolve(MapLighting.PRESETS[id])
			for _, k in { 0, 0.33, 0.5, 0.77, 1 } do
				local x = MapLighting.lerp(MapLighting.LOBBY, p, k)
				t.ok(x.ClockTime >= 0 and x.ClockTime < 24, `{id} clock in range`)
			end
		end
	end)

	------------------------------------------------------------------ pickArena
	t.test("QA pickArena: 여유 경계 정확히, 아래쪽 BELOW_EXTRA, 빈 목록", function()
		local A = { key = "A", center = vec(0, 0, 0), size = vec(100, 20, 100) }
		local E, X, B = MapLightingLogic.ENTER_MARGIN, MapLightingLogic.EXIT_MARGIN, MapLightingLogic.BELOW_EXTRA
		t.eq(MapLightingLogic.pickArena(vec(50 + E, 0, 0), { A }, nil), "A", "exactly enter margin")
		t.eq(MapLightingLogic.pickArena(vec(50 + E + 0.01, 0, 0), { A }, nil), nil, "just outside enter")
		t.eq(MapLightingLogic.pickArena(vec(50 + X, 0, 0), { A }, "A"), "A", "exactly exit margin")
		t.eq(MapLightingLogic.pickArena(vec(50 + X + 0.01, 0, 0), { A }, "A"), nil, "just outside exit")
		-- 떨어지는 중: 바닥 아래 여유 + 150까지 유지
		t.eq(MapLightingLogic.pickArena(vec(0, -10 - E - B, 0), { A }, nil), "A", "falling below")
		t.eq(MapLightingLogic.pickArena(vec(0, -10 - E - B - 0.01, 0), { A }, nil), nil, "far below")
		-- 위쪽은 여유만
		t.eq(MapLightingLogic.pickArena(vec(0, 10 + E + 0.01, 0), { A }, nil), nil, "above")
		t.eq(MapLightingLogic.pickArena(vec(0, 0, 0), {}, "A"), nil, "no arenas → lobby")
	end)

	t.test(
		"QA pickArena: 현재 아레나가 사라지면 다른 아레나 또는 nil, 겹치면 현재 유지",
		function()
			local A = { key = "A", center = vec(0, 0, 0), size = vec(100, 20, 100) }
			local B = { key = "B", center = vec(30, 0, 0), size = vec(100, 20, 100) }
			-- A가 사라짐(다음 라운드 맵 B가 같은 자리에) → B
			t.eq(MapLightingLogic.pickArena(vec(10, 0, 0), { B }, "A"), "B", "replaced arena")
			t.eq(MapLightingLogic.pickArena(vec(10, 0, 0), {}, "A"), nil, "destroyed arena")
			-- 둘 다 안: 현재(A)가 B보다 멀어도 유지 (깜빡임 없음)
			t.eq(MapLightingLogic.pickArena(vec(25, 0, 0), { A, B }, "A"), "A", "sticky current")
			t.eq(MapLightingLogic.pickArena(vec(25, 0, 0), { A, B }, nil), "B", "nearest when fresh")
			-- 히스테리시스: 0.25초마다 경계를 왔다 갔다 해도 바뀌는 건 한 번
			local current: string? = nil
			local changes = 0
			for i = 0, 40 do
				local x = 50 + 55 + (if i % 2 == 0 then 5 else -5) -- 100~110: 들어가기(90) 밖, 나가기(130) 안
				if i == 0 then
					x = 60 -- 먼저 들어감
				end
				local nextKey = MapLightingLogic.pickArena(vec(x, 0, 0), { A }, current)
				if nextKey ~= current then
					changes += 1
				end
				current = nextKey
			end
			t.eq(changes, 1, "only one switch at the boundary")
			t.ok(MapLightingLogic.blendAlpha(0) == 0 and MapLightingLogic.blendAlpha(1e9) == 1, "blend ends")
			t.ok(MapLightingLogic.blendAlpha(-1) == 0, "negative elapsed clamps")
		end
	)

	------------------------------------------------------------------ 실제 맵 아레나 상자 (렌더러 환경)
	t.test(
		"QA arenas: 실제 맵 15개 — 로비는 어느 아레나에도 안 걸리고, 슬롯 1·2가 안 겹침",
		function()
			-- 로비 영역: 구조물·장식 경계 + 카메라 높이 여유
			local boxes = { MapKitLogic.bounds(LobbyLayout.STRUCTURE), MapKitLogic.bounds(LobbyLayout.DECOR) }
			local lobbyPoints = {}
			for _, b in boxes do
				for _, x in { b.min.x, b.max.x } do
					for _, y in { b.min.y, b.max.y + 60 } do
						for _, z in { b.min.z, b.max.z } do
							table.insert(lobbyPoints, vec(x, y, z))
						end
					end
				end
			end
			table.insert(lobbyPoints, vec(0, 5, 0))
			for _, id in allIds() do
				local a1 = buildAt(id, 1)
				local a2 = buildAt(id, 2)
				local arenas = {
					{ key = "s1", center = a1.center, size = a1.size },
					{ key = "s2", center = a2.center, size = a2.size },
				}
				for _, p in lobbyPoints do
					t.eq(MapLightingLogic.pickArena(p, arenas, nil), nil, `{id}: lobby point inside an arena`)
				end
				-- 슬롯 1 안의 카메라가 슬롯 2로 잡히지 않음 (x 방향 여유 포함)
				t.ok(
					a1.center.x + a1.size.x / 2 + MapLightingLogic.EXIT_MARGIN
						< a2.center.x - a2.size.x / 2 - MapLightingLogic.EXIT_MARGIN,
					`{id}: slot 1/2 arenas overlap (size {a1.size.x})`
				)
				t.eq(MapLightingLogic.pickArena(a1.center, arenas, nil), "s1", `{id}: center of slot 1`)
			end
		end
	)

	t.test(
		"QA arenas: 스폰 24개·eye 카메라·소개 카메라 경유점이 모두 그 아레나 조명으로 잡혀요",
		function()
			for _, id in allIds() do
				local a = buildAt(id, 1)
				local arenas = { { key = "s1", center = a.center, size = a.size } }
				local spawns = a.model:FindFirstChild("Spawns")
				t.ok(spawns ~= nil, `{id}: Spawns`)
				for _, s in spawns:GetChildren() do
					local p = s.CFrame.Position
					t.eq(MapLightingLogic.pickArena(v3(p), arenas, nil), "s1", `{id}: spawn {s.Name}`)
					-- 기본 카메라(뒤 12·위 4)
					local cam = (s.CFrame * roblox.CFrame.new(0, 4, 12)).Position
					t.eq(MapLightingLogic.pickArena(v3(cam), arenas, nil), "s1", `{id}: eye camera behind {s.Name}`)
				end
				local intro = a.model:FindFirstChild("IntroCamera")
				if intro then
					for _, point in intro:GetChildren() do
						if point:IsA("BasePart") then
							local p = point.CFrame.Position
							local got = MapLightingLogic.pickArena(v3(p), arenas, nil)
							if KNOWN_INTRO_OUTSIDE[`{id}/{point.Name}`] then
								-- B1 (docs/qa/m5-23-map-visual-kit.md): 지금은 밖으로 잡혀요. 고치면 이 항목을 지우세요
								t.eq(
									got,
									nil,
									`{id}: intro {point.Name} is now inside — remove it from KNOWN_INTRO_OUTSIDE`
								)
							else
								-- 소개는 맵 조명으로 바뀐 뒤 보여야 해요: 들어가기 여유 안
								t.eq(
									got,
									"s1",
									`{id}: intro camera {point.Name} at {p} (arena center {a.center.x},{a.center.y},{a.center.z} size {a.size.x},{a.size.y},{a.size.z})`
								)
							end
						end
					end
				end
			end
		end
	)

	------------------------------------------------------------------ 예산
	t.test("QA budget: 단계별 정확한 경계 (같으면 통과, 하나 넘으면 실패)", function()
		local S, X = MapKitLogic.BUDGETS.Standard, MapKitLogic.BUDGETS.Extended
		t.eq(MapKitLogic.checkBudget(many(600), "Standard"), nil, "600 parts std")
		t.eq(MapKitLogic.checkBudget(many(S.lights, { light = LIGHT }), "Standard"), nil, "12 lights std")
		t.ok(MapKitLogic.checkBudget(many(S.lights + 1, { light = LIGHT }), "Standard") ~= nil, "13 lights std")
		t.eq(MapKitLogic.checkBudget(many(X.lights, { light = LIGHT }), "Extended"), nil, "24 lights ext")
		local shadowLight = table.clone(LIGHT)
		shadowLight.shadows = true
		t.eq(MapKitLogic.checkBudget(many(1, { light = shadowLight }), "Standard"), nil, "1 shadowed std")
		t.ok(MapKitLogic.checkBudget(many(2, { light = shadowLight }), "Standard") ~= nil, "2 shadowed std")
		t.eq(MapKitLogic.checkBudget(many(2, { light = shadowLight }), "Extended"), nil, "2 shadowed ext")
		t.eq(MapKitLogic.checkBudget(many(16, { particle = "Steam" }), "Extended"), nil, "16 particles ext")
		t.ok(MapKitLogic.checkBudget(many(9, { particle = "Steam" }), "Standard") ~= nil, "9 particles std")
		local anim = { kind = "Bob", period = 2, amount = 1 }
		t.eq(MapKitLogic.checkBudget(many(80, { anim = anim }), "Extended"), nil, "80 anim ext")
		t.eq(MapKitLogic.checkBudget(many(40, { anim = anim }), "Standard"), nil, "40 anim std")
		t.ok(MapKitLogic.checkBudget(many(41, { anim = anim }), "Standard") ~= nil, "41 anim std")
		-- 기본 단계·모르는 단계는 Standard
		t.ok(MapKitLogic.checkBudget(many(601)) ~= nil, "nil tier = Standard")
		t.ok(MapKitLogic.checkBudget(many(601), "Huge" :: any) ~= nil, "unknown tier = Standard")
	end)

	t.test("QA budget: extra로 Instance.new 조명·파티클·파츠도 같이 세요", function()
		t.eq(MapKitLogic.checkBudget(many(10, { light = LIGHT }), "Standard", { lights = 2 }), nil, "10+2 lights")
		t.ok(MapKitLogic.checkBudget(many(10, { light = LIGHT }), "Standard", { lights = 3 }) ~= nil, "10+3 lights")
		t.ok(
			MapKitLogic.checkBudget(many(7, { particle = "Bubbles" }), "Standard", { particles = 2 }) ~= nil,
			"7+2 particles"
		)
		t.ok(MapKitLogic.checkBudget(many(1500), "Extended", { parts = 1 }) ~= nil, "1500+1 parts")
		t.eq(MapKitLogic.checkBudget(many(1499), "Extended", { parts = 1 }), nil, "1499+1 parts")
	end)

	t.test(
		"QA budget: 렌더러 통계 = 기존 맵 lune 카운트 (AC13, 렌더러 환경에서 지은 모델)",
		function()
			local function count(model: any): (number, number)
				local lights, particles = 0, 0
				for _, d in model:GetDescendants() do
					if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
						lights += 1
					elseif d:IsA("ParticleEmitter") then
						particles += 1
					end
				end
				return lights, particles
			end
			-- m5-24 D2: 아트 패스 v2를 마친 맵(Art.BUDGET = Extended)은 DecorSpec 조명·파티클이 늘어요 → 렌더러 수 =
			-- 장식 목록 수 + 코드가 Instance.new로 붙인 m5-20 수 (렌더러 통계 = lune 카운트라는 원래 뜻은 그대로)
			local function expected(id: string, codeLights: number, codeParticles: number): { number }
				local art = artModule(id)
				if art and art.BUDGET == "Extended" and type(art.decor) == "function" then
					local decor = art.decor()
					return {
						MapKitLogic.countLights(decor) + codeLights,
						MapKitLogic.countParticles(decor) + codeParticles,
					}
				end
				return { codeLights, codeParticles }
			end
			local l1, p1 = count(buildAt("rotating-belt", 1).model)
			t.eq({ l1, p1 }, expected("rotating-belt", 3, 2), "rotating-belt lights/particles")
			local l2, p2 = count(buildAt("soy-swamp", 1).model)
			t.eq({ l2, p2 }, expected("soy-swamp", 2, 3), "soy-swamp lights/particles")
			-- 모든 맵이 자기 예산 단계(<Map>Art.BUDGET, 없으면 Standard — 렌더러 budgetTier와 같은 규칙) 조명·파티클 안
			-- (Instance.new 포함 실제 수). 단계는 맵마다 Art 모듈에서 읽어요 (m5-05 QA: 하드코딩 목록 대신).
			local extendedSeen = 0
			for _, id in allIds() do
				local l, p = count(buildAt(id, 1).model)
				local tier = artBudgetTier(id)
				if tier == "Extended" then
					extendedSeen += 1
				end
				local budget = MapKitLogic.budget(tier)
				t.ok(l <= budget.lights and p <= budget.particles, `{id} ({tier}): {l} lights {p} particles`)
			end
			t.ok(extendedSeen >= 1, "at least one Extended map (tempura-pot) is read from its Art.BUDGET")
		end
	)

	------------------------------------------------------------------ validateExtras 추가 경계
	t.test("QA extras: 추가 경계값 거절", function()
		local nan = 0 / 0
		local bad: { any } = {
			base({ reflectance = nan }),
			base({ reflectance = -0.01 }),
			base({ castShadow = 0 }),
			base({ light = "Point" }),
			base({ light = { color = LIGHT.color, brightness = 1, range = 10 } }), -- kind 없음
			base({ light = { kind = "Point", brightness = 1, range = 10 } }), -- color 없음
			base({ light = { kind = "Point", color = LIGHT.color, brightness = -0.1, range = 10 } }),
			base({ light = { kind = "Point", color = LIGHT.color, brightness = 10.1, range = 10 } }),
			base({ light = { kind = "Point", color = LIGHT.color, brightness = 1, range = -1 } }),
			base({ light = { kind = "Spot", color = LIGHT.color, brightness = 1, range = 10, angle = 181 } }),
			base({ light = { kind = "Spot", color = LIGHT.color, brightness = 1, range = 10, face = "" } }),
			base({ light = { kind = "Point", color = LIGHT.color, brightness = 1, range = 10, shadows = 1 } }),
			base({ particle = 3 }),
			base({ particle = "steam" }), -- 대소문자
			base({ particleRate = 5 }), -- particle 없이
			base({ particle = "Steam", particleRate = -1 }),
			base({ anim = "Spin" }),
			base({ anim = { kind = "Bob", period = 60.01, amount = 1 } }),
			base({ anim = { kind = "Bob", period = 0.49, amount = 1 } }),
			base({ anim = { kind = "Bob", period = 2 } }), -- amount 없음
			base({ anim = { kind = "Bob", period = 2, amount = -0.1 } }),
			base({ anim = { kind = "Pulse", period = 2, amount = 0.151 } }),
			base({ anim = { kind = "Spin", period = 2, amount = "fast" } }),
			base({ anim = { kind = "Spin", period = 2, axis = "W" } }),
			base({ anim = { kind = "Sway", period = nan, amount = 1 } }),
		}
		for i, spec in bad do
			t.ok(type(MapKitLogic.validate({ spec })) == "string", `bad extra #{i}`)
		end
	end)

	t.test("QA extras: 경계값 통과 (Spin amount 없음, 최대값 정확히)", function()
		local good: { any } = {
			base({ reflectance = 0 }),
			base({ reflectance = 1 }),
			base({ light = { kind = "Spot", color = LIGHT.color, brightness = 10, range = 60, angle = 180 } }),
			base({ light = { kind = "Surface", color = LIGHT.color, brightness = 0, range = 0, face = "Top" } }),
			base({ particle = "Confetti", particleRate = 0 }),
			base({ particle = "Embers", particleRate = 50 }),
			base({ anim = { kind = "Spin", period = 0.5 } }),
			base({ anim = { kind = "Bob", period = 60, amount = 4, axis = "X" } }),
			base({ anim = { kind = "Sway", period = 3, amount = 20, axis = "Y" } }),
			base({ anim = { kind = "Pulse", period = 3, amount = 0.15 } }),
			base({ shape = "CornerWedge", castShadow = true }),
		}
		for i, spec in good do
			t.eq(MapKitLogic.validate({ spec }), nil, `good extra #{i}`)
		end
		-- castShadow 명시값이 크기 규칙보다 먼저
		t.eq(MapKitLogic.resolveCastShadow(base({ size = vec(1, 1, 1), castShadow = true })), true, "small forced on")
		t.eq(MapKitLogic.resolveCastShadow(base({ size = vec(50, 1, 1), castShadow = false })), false, "big forced off")
	end)

	------------------------------------------------------------------ 움직임
	t.test("QA anim: 큰 서버 시각에서도 주기, 위상 0~1, 축별 성분만", function()
		local T = 1.76e9 + 0.123 -- workspace:GetServerTimeNow() 크기
		for _, kind in { "Bob", "Sway", "Pulse", "Spin" } do
			local amount = MapDecorAnimLogic.MAX_AMOUNT[kind]
			if amount == math.huge then
				amount = 0
			end
			local a = MapDecorAnimLogic.offset(kind, 3, amount, nil, T, 0.37)
			local b = MapDecorAnimLogic.offset(kind, 3, amount, nil, T + 3, 0.37)
			for key, value in a do
				t.ok(math.abs(value - (b :: any)[key]) < 1e-4, `{kind}.{key} periodic at large t`)
			end
		end
		for _, p in { { 0, 0, 0 }, { 2000, 300, 0 }, { -12.34, 5.5, -999.9 }, { 48000, 300, 123.45 } } do
			local ph = MapDecorAnimLogic.phaseOf(p[1], p[2], p[3])
			t.ok(ph >= 0 and ph < 1, `phase in [0,1) ({ph})`)
		end
		local bobX = MapDecorAnimLogic.offset("Bob", 4, 2, "X", 1, 0) -- sin(π/2) = 1
		t.ok(math.abs(bobX.dx - 2) < 1e-9 and bobX.dy == 0 and bobX.dz == 0, "Bob X only dx")
		local swayDefault = MapDecorAnimLogic.offset("Sway", 4, 10, nil, 1, 0)
		t.ok(math.abs(swayDefault.rz - math.rad(10)) < 1e-9 and swayDefault.rx == 0, "Sway default axis Z")
		local spinHalf = MapDecorAnimLogic.offset("Spin", 10, 0, nil, 5, 0)
		t.ok(math.abs(spinHalf.ry - math.pi) < 1e-9, "Spin half period = π about Y")
		local unknown = MapDecorAnimLogic.offset("Wiggle", 2, 1, nil, 0.5, 0)
		t.eq(unknown, { dx = 0, dy = 0, dz = 0, rx = 0, ry = 0, rz = 0, scale = 1 }, "unknown kind = identity")
	end)

	------------------------------------------------------------------ 진짜 인스턴스로 buildDecor
	t.test("QA MapKit: buildDecor 새 필드가 진짜 인스턴스로 (클래스·속성·태그·자식)", function()
		local folder = roblox.Instance.new("Folder")
		local specs = {
			base({ name = "Corner", shape = "CornerWedge", reflectance = 0.4 }),
			base({ name = "Small", size = vec(1, 2, 2.9) }),
			base({ name = "Big", size = vec(3, 1, 1) }),
			base({
				name = "Lamp",
				light = {
					kind = "Spot",
					color = LIGHT.color,
					brightness = 3,
					range = 25,
					angle = 45,
					face = "Bottom",
					shadows = true,
				},
			}),
			base({ name = "Panel", light = { kind = "Surface", color = LIGHT.color, brightness = 1, range = 12 } }),
			base({ name = "Bulb", light = LIGHT }),
			base({ name = "Pot", particle = "SteamThick", particleRate = 2 }),
			base({ name = "Fan", anim = { kind = "Spin", period = 4 } }),
			base({ name = "Buoy", anim = { kind = "Bob", period = 3, amount = 1.5, axis = "Y" } }),
		}
		local origin = roblox.CFrame.new(2000, 300, 0)
		local parts = RMapKit.buildDecor(specs, origin, folder)
		t.eq(#parts, #specs, "all built")
		local byName = {}
		for _, p in parts do
			byName[p.Name] = p
			t.ok(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, `{p.Name} decor rules`)
			t.ok(p.Parent == folder, `{p.Name} parented`)
		end
		t.eq(byName.Corner.ClassName, "CornerWedgePart", "CornerWedge class")
		t.ok(math.abs(byName.Corner.Reflectance - 0.4) < 1e-6, "reflectance")
		t.eq(byName.Small.CastShadow, false, "small no shadow")
		t.eq(byName.Big.CastShadow, true, "3-stud shadow")
		local spot = byName.Lamp:FindFirstChildOfClass("SpotLight")
		t.ok(spot ~= nil, "SpotLight child")
		t.ok(spot.Shadows == true and spot.Range == 25 and spot.Angle == 45, "spot props")
		t.eq(spot.Face, roblox.Enum.NormalId.Bottom, "spot face")
		local surface = byName.Panel:FindFirstChildOfClass("SurfaceLight")
		t.ok(surface ~= nil and surface.Face == roblox.Enum.NormalId.Front, "SurfaceLight default face Front")
		t.ok(byName.Bulb:FindFirstChildOfClass("PointLight").Shadows == false, "point default no shadows")
		local emitter = byName.Pot:FindFirstChildOfClass("ParticleEmitter")
		t.ok(emitter ~= nil and emitter.Rate == 2 and emitter.Name == "SteamThick", "emitter with rate override")
		t.ok(byName.Fan:HasTag("MapDecorAnim"), "anim tag")
		t.eq(byName.Fan:GetAttribute("AnimKind"), "Spin")
		t.eq(byName.Fan:GetAttribute("AnimAmount"), 0, "Spin amount nil → 0")
		t.eq(byName.Fan:GetAttribute("AnimAxis"), nil, "no axis attr when nil")
		t.eq(byName.Buoy:GetAttribute("AnimAxis"), "Y")
		t.ok(not byName.Bulb:HasTag("MapDecorAnim"), "no tag without anim")
		-- 잘못된 목록은 아무것도 안 만들어요 (라운드가 안 깨지게)
		local bad = RMapKit.buildDecor({ base({ reflectance = 2 }) }, origin, folder)
		t.eq(#bad, 0, "invalid list skipped")
	end)

	t.test("QA MapKit: 모든 파티클 프리셋이 진짜 ParticleEmitter로 (키프레임 0·1 끝)", function()
		for _, name in MapFxPresets.NAMES do
			local preset = MapFxPresets.PRESETS[name]
			for _, field in { "Size", "Transparency", "Color" } do
				local keys = preset[field]
				t.ok(#keys >= 1 and #keys <= 20, `{name}.{field} keypoint count`)
				if #keys > 1 then
					t.eq(keys[1].t, 0, `{name}.{field} starts at 0`)
					t.eq(keys[#keys].t, 1, `{name}.{field} ends at 1`)
					for i = 2, #keys do
						t.ok(keys[i].t >= keys[i - 1].t, `{name}.{field} sorted`)
					end
				end
			end
			local ok, emitter = pcall(RMapKit.makeEmitter, name)
			t.ok(ok, `{name}: makeEmitter ({tostring(emitter)})`)
		end
		t.throws(function()
			RMapKit.makeEmitter("Nope")
		end, "unknown preset errors")
	end)

	------------------------------------------------------------------ 모양 헬퍼 추가 경계
	t.test(
		"QA shapes: 회전한 roundedBox·bevelBox·capsule 경계, ring 최소 3분할, scatter 영역 안",
		function()
			local c = MapKitLogic.PALETTE.Wood
			local rb =
				MapKitShapes.roundedBox("R", vec(10, 4, 6), c, "Wood", vec(1, 2, 3), { rotation = vec(0, 90, 0) })
			local b = MapKitLogic.bounds(rb)
			t.ok(
				math.abs((b.max.x - b.min.x) - 6) < 0.02 and math.abs((b.max.z - b.min.z) - 10) < 0.02,
				"rotated 90 swaps x/z"
			)
			t.ok(math.abs((b.max.x + b.min.x) / 2 - 1) < 0.02, "rotated center x")
			local bevel = MapKitShapes.bevelBox("B", vec(8, 3, 5), c, "Wood", vec(0, 0, 0), 0.8)
			t.eq(MapKitLogic.validate(bevel), nil, "bevel validates")
			local bb = MapKitLogic.bounds(bevel)
			t.ok(math.abs(bb.max.x - bb.min.x - 8) < 0.02 and math.abs(bb.max.y - bb.min.y - 3) < 0.02, "bevel bounds")
			local cap = MapKitShapes.capsule("C", 6, 2, c, "Wood", vec(0, 0, 0), vec(0, 0, 90))
			local cb = MapKitLogic.bounds(cap)
			t.ok(math.abs(cb.max.y - cb.min.y - 6) < 0.02, "upright capsule height = length")
			local ring = MapKitShapes.ring("G", 5, 0.5, 0.5, 2, c, "Wood", vec(0, 0, 0))
			t.eq(#ring, 3, "ring at least 3 segments")
			local area = { center = vec(10, 1, -20), size = vec(30, 0, 12) }
			local placed = MapKitShapes.scatter(7, 50, area, function(i, pos)
				return { base({ name = `S{i}`, offset = pos }) }
			end)
			t.eq(#placed, 50, "scatter count")
			for _, s in placed do
				t.ok(
					math.abs(s.offset.x - 10) <= 15 + 1e-9 and math.abs(s.offset.z + 20) <= 6 + 1e-9,
					"scatter inside area"
				)
				t.eq(s.offset.y, 1, "scatter height")
			end
			-- 다른 seed면 다른 배치
			local other = MapKitShapes.scatter(8, 50, area, function(i, pos)
				return { base({ name = `S{i}`, offset = pos }) }
			end)
			t.ok(other[1].offset.x ~= placed[1].offset.x or other[1].offset.z ~= placed[1].offset.z, "seed matters")
		end
	)

	------------------------------------------------------------------ 소스 확인 (서버 판정 원칙·정리)
	t.test("QA source: RoundService가 MapId·태그를 Workspace에 넣기 전에 달아요", function()
		local src = read("src/server/RoundService.luau")
		local mapIdAt = string.find(src, "model:SetAttribute(Attributes.MapId, map.id)", 1, true)
		local tagAt = string.find(src, "AddTag(model, MapDecorTags.Arena)", 1, true)
		local parentAt = string.find(src, "model.Parent = workspace", 1, true)
		t.ok(mapIdAt and tagAt and parentAt, "all three present")
		t.ok((mapIdAt :: number) < (tagAt :: number) and (tagAt :: number) < (parentAt :: number), "order")
		local cleanupAt = string.find(src, "cleanup:add(model)", 1, true)
		t.ok(cleanupAt ~= nil and (cleanupAt :: number) < (parentAt :: number), "model destroyed by round cleanup")
	end)

	t.test(
		"QA source: 클라이언트 조명·장식 애니메이션은 TweenService·리모트를 쓰지 않아요",
		function()
			for _, path in { "src/client/fx/MapLightingController.luau", "src/client/fx/MapDecorFxController.luau" } do
				local src = read(path)
				t.ok(string.find(src, "TweenService", 1, true) == nil, `{path}: no TweenService`)
				t.ok(string.find(src, "Remotes", 1, true) == nil, `{path}: no remotes`)
				t.ok(string.find(src, "FireServer", 1, true) == nil, `{path}: no FireServer`)
			end
			-- 서버 쪽 MapKit은 움직임을 태그·속성으로만 (RenderStepped·Heartbeat 없음)
			local kit = read("src/shared/maps/MapKit.luau")
			t.ok(
				string.find(kit, "RenderStepped", 1, true) == nil and string.find(kit, "Heartbeat", 1, true) == nil,
				"MapKit static"
			)
			-- 서버는 LobbyService.init 뒤에 Lighting을 다시 쓰지 않아요 (클라이언트 값이 덮이지 않게)
			for _, file in fs.readDir("src/server") do
				if file ~= "LobbyService.luau" and string.match(file, "%.luau$") then
					local s = read("src/server/" .. file)
					t.ok(string.find(s, 'GetService("Lighting")', 1, true) == nil, `{file}: touches Lighting`)
				end
			end
		end
	)

	t.test("QA project: default.project.json Lighting = Future·Realistic·PrioritizeLightingQuality", function()
		local serde = require("@lune/serde")
		local project = serde.decode("json", read("default.project.json"))
		local lighting = project.tree.Lighting
		t.ok(lighting ~= nil, "Lighting node")
		t.eq(lighting["$properties"].Technology, "Future")
		t.eq(lighting["$properties"].LightingStyle, "Realistic")
		t.eq(lighting["$properties"].PrioritizeLightingQuality, true)
		t.ok(lighting["$className"] == nil or lighting["$className"] == "Lighting", "service node")
		local ignore = read(".gitignore")
		t.ok(string.find(ignore, "build/", 1, true) ~= nil, ".gitignore build/")
	end)
end
