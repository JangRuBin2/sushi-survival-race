--!strict
-- 맵 미리보기 렌더러 (m5-23). Studio 없이 맵을 진짜로 build해서 PNG로 그려요.
--   lune run tools/render-map <mapId|all> [--view intro|overview|eye|top|mobile|all] [--size 960x540]
--        [--quality fast|high] [--out build/renders] [--studio-art] [--lobby-light]
-- 결과: <out>/<mapId>/<view>.png + stats.txt
--   intro-01…  맵 IntroCamera 경유점마다 한 장 (라운드 소개 카메라와 같은 자리·방향)
--   overview   위 35°·옆 40°(출발 쪽 왼쪽)에서 본 전체 (3/4 뷰)
--   eye        1번 스폰 캐릭터 뒤 12·위 4에서 본 플레이어 시점 (Roblox 기본 카메라 근사).
--              스폰 1~3에 계란초밥 크기 인형을 세워 크기를 비교해요
--   top        바로 위에서 본 배치도 (직교, 위쪽 = 코스 앞 -Z, 플레이 영역보다 높은 지붕은 빼요)
--   mobile     eye를 480×270으로 (작은 화면에서 읽히는지)
-- 조명은 맵의 lighting(MapLighting, 없으면 로비 조명)을 따라요. --lobby-light면 로비 조명으로 비교.
-- quality: fast = 슈퍼샘플 없음·그림자 1024, high(기본) = 2×2 슈퍼샘플·그림자 2048.
-- 같은 입력이면 같은 PNG 바이트예요 (결정적). 실제 Roblox 렌더와 같지 않아요 — 한계는 docs/DEV-SETUP.md.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Png = require("./render/Png")
local Raster = require("./render/Raster")
local Scene = require("./render/Scene")
local Shims = require("./render/Shims")

type V3 = { x: number, y: number, z: number }

local function v3(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- ── 인자 ────────────────────────────────────────────────────────────
local args = process.args
local mapArg: string? = nil
local outDir = "build/renders"
local width, height = 960, 540
local quality = "high"
local viewArg = "all"
local studioArt = false
local lobbyLight = false

local i = 1
while i <= #args do
	local a = args[i]
	if a == "--out" then
		outDir = args[i + 1]
		i += 1
	elseif a == "--size" then
		local w, h = string.match(args[i + 1] or "", "^(%d+)x(%d+)$")
		assert(w and h, "--size must look like 960x540")
		width, height = tonumber(w) :: number, tonumber(h) :: number
		i += 1
	elseif a == "--quality" then
		quality = args[i + 1]
		assert(quality == "fast" or quality == "high", "--quality must be fast or high")
		i += 1
	elseif a == "--view" then
		viewArg = args[i + 1] or "all"
		i += 1
	elseif a == "--studio-art" then
		studioArt = true
	elseif a == "--lobby-light" then
		lobbyLight = true
	elseif string.sub(a, 1, 2) == "--" then
		error(`unknown option {a}`)
	else
		mapArg = a
	end
	i += 1
end

local supersample = if quality == "high" then 2 else 1
local shadowSize = if quality == "high" then 2048 else 1024

local Shared = Shims.root("src/shared")
local Config = Shims.require(Shared.Config)
local Maps = Shims.require(Shared.maps)
local MapLighting = Shims.require(Shared.maps.MapLighting)
local MapKitLogic = Shims.require(Shared.maps.MapKitLogic)

if mapArg == nil then
	print(
		"usage: lune run tools/render-map <mapId|all> [--view intro|overview|eye|top|mobile|all] [--size 960x540]"
			.. " [--quality fast|high] [--out build/renders] [--studio-art] [--lobby-light]"
	)
	local ids = {}
	for _, info in Maps.allInfos() do
		table.insert(ids, info.id)
	end
	print("maps: " .. table.concat(ids, ", "))
	process.exit(1)
end

-- ── 장면 도우미 ──────────────────────────────────────────────────────
local function sortedParts(folder: any): { any }
	local list = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function boundsOf(scene: Scene.Scene, decorToo: boolean): { number }
	local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
	for _, part in scene.parts do
		if (part.decor and not decorToo) or part.name == "ScaleDummy" or part.minX == math.huge then
			continue
		end
		b[1], b[2], b[3] = math.min(b[1], part.minX), math.min(b[2], part.minY), math.min(b[3], part.minZ)
		b[4], b[5], b[6] = math.max(b[4], part.maxX), math.max(b[5], part.maxY), math.max(b[6], part.maxZ)
	end
	if b[1] == math.huge then
		return { -50, -10, -50, 50, 10, 50 }
	end
	return b
end

-- 크기 비교용 계란초밥 인형 (SushiBody 기본 외형 근사: 밥 2.4×3.2×1.8 + 계란 + 김 띠)
local function addDummy(scene: Scene.Scene, spawn: any, forward: V3)
	local top = spawn.CFrame.Position.Y + spawn.Size.Y / 2
	local pos = spawn.CFrame.Position
	local base = Shims.lookAt(
		roblox.Vector3.new(pos.X, top + 1.6, pos.Z),
		roblox.Vector3.new(pos.X + forward.x, top + 1.6, pos.Z + forward.z)
	)
	local function piece(size: { number }, offset: { number }, rgb: { number })
		Scene.addBox(
			scene,
			base * roblox.CFrame.new(offset[1], offset[2], offset[3]),
			roblox.Vector3.new(size[1], size[2], size[3]),
			{ rgb[1] / 255, rgb[2] / 255, rgb[3] / 255 },
			"SmoothPlastic",
			{ name = "ScaleDummy" }
		)
	end
	piece({ 2.4, 3.2, 1.8 }, { 0, 0, 0 }, { 246, 243, 232 })
	piece({ 2.8, 0.8, 2.2 }, { 0, 2.0, -0.2 }, { 248, 208, 72 })
	piece({ 2.6, 1.6, 0.3 }, { 0, 0.9, 1.05 }, { 248, 208, 72 })
	piece({ 2.5, 0.7, 1.9 }, { 0, -0.3, 0 }, { 30, 36, 32 })
end

-- 플레이어가 보는 방향: Race는 코스 앞(origin -Z), 나머지는 스폰에서 플레이 영역 가운데 쪽(가운데면 -Z)
local function courseForward(map: any, origin: any, spawnPos: V3, jb: { number }): V3
	local look = origin.LookVector
	local forward = v3(look.X, 0, look.Z)
	if map.kind == "Race" then
		return forward
	end
	local cx, cz = (jb[1] + jb[4]) / 2 - spawnPos.x, (jb[3] + jb[6]) / 2 - spawnPos.z
	local l = math.sqrt(cx * cx + cz * cz)
	if l < 4 then
		return forward
	end
	return v3(cx / l, 0, cz / l)
end

type View = { name: string, camera: Raster.Camera, width: number, height: number }

local function makeViews(map: any, model: any, scene: Scene.Scene, origin: any): { View }
	local aspect = width / height
	local views: { View } = {}
	local jb = boundsOf(scene, false)
	local all = boundsOf(scene, true)

	-- (a) 소개 카메라
	local intro = model:FindFirstChild("IntroCamera")
	if intro then
		for _, point in sortedParts(intro) do
			local cf = point.CFrame
			local p, look = cf.Position, cf.LookVector
			table.insert(views, {
				name = "intro-" .. point.Name,
				camera = Raster.perspective(
					v3(p.X, p.Y, p.Z),
					v3(p.X + look.X * 50, p.Y + look.Y * 50, p.Z + look.Z * 50),
					70,
					aspect
				),
				width = width,
				height = height,
			})
		end
	end

	-- (b) 3/4 전체: 모델 경계 상자 (먼 배경판 때문에 플레이 영역의 3배를 넘으면 플레이 영역 기준 2배로 줄여요)
	local fb = all
	local jsx, jsz = jb[4] - jb[1], jb[6] - jb[3]
	if (all[4] - all[1]) > 3 * math.max(jsx, 30) or (all[6] - all[3]) > 3 * math.max(jsz, 30) then
		fb =
			{ jb[1] - jsx / 2, all[2], jb[3] - jsz / 2, jb[4] + jsx / 2, math.min(all[5], jb[5] + 60), jb[6] + jsz / 2 }
	end
	local cx, cy, cz = (fb[1] + fb[4]) / 2, (fb[2] + fb[5]) / 2, (fb[3] + fb[6]) / 2
	local sx, sy, sz = fb[4] - fb[1], fb[5] - fb[2], fb[6] - fb[3]
	local elevation, azimuth = math.rad(35), math.rad(40)
	-- 출발 쪽(+Z, origin 뒤)에서 왼쪽(-X)으로 40° 돌아 위 35°
	local back = origin.LookVector * -1
	local left = origin.RightVector * -1
	local hx = back.X * math.cos(azimuth) + left.X * math.sin(azimuth)
	local hz = back.Z * math.cos(azimuth) + left.Z * math.sin(azimuth)
	local dx, dy, dz = hx * math.cos(elevation), math.sin(elevation), hz * math.cos(elevation)
	-- 상자 꼭짓점 8개가 화면에 다 들어오는 가장 가까운 거리 (카메라 축으로 투영해서 정확히)
	local fov = 55
	local probe = Raster.perspective(v3(cx + dx, cy + dy, cz + dz), v3(cx, cy, cz), fov, aspect)
	local dist = 1
	for k = 0, 7 do
		local ox = (if k % 2 == 0 then -sx else sx) / 2
		local oy = (if math.floor(k / 2) % 2 == 0 then -sy else sy) / 2
		local oz = (if math.floor(k / 4) % 2 == 0 then -sz else sz) / 2
		local rx = ox * probe.rx + oy * probe.ry + oz * probe.rz
		local uy = ox * probe.ux + oy * probe.uy + oz * probe.uz
		local fz = ox * probe.fx + oy * probe.fy + oz * probe.fz
		dist = math.max(dist, math.abs(rx) / probe.sx - fz, math.abs(uy) / probe.sy - fz)
	end
	dist *= 1.06
	table.insert(views, {
		name = "overview",
		camera = Raster.perspective(v3(cx + dx * dist, cy + dy * dist, cz + dz * dist), v3(cx, cy, cz), fov, aspect),
		width = width,
		height = height,
	})

	-- (c) 플레이어 시점: 1번 스폰 캐릭터 뒤 12·위 4 (머리 높이 기준)
	local spawnsFolder = model:FindFirstChild("Spawns")
	local spawns = if spawnsFolder then sortedParts(spawnsFolder) else {}
	if #spawns > 0 then
		local p = spawns[1].CFrame.Position
		local sp = v3(p.X, p.Y, p.Z)
		local fwd = courseForward(map, origin, sp, jb)
		for k = 1, math.min(3, #spawns) do
			addDummy(scene, spawns[k], fwd)
		end
		local headY = sp.y + 4.5
		local eye = v3(sp.x - fwd.x * 12, headY + 4, sp.z - fwd.z * 12)
		local target = v3(sp.x + fwd.x * 20, headY - 1, sp.z + fwd.z * 20)
		table.insert(views, {
			name = "eye",
			camera = Raster.perspective(eye, target, 70, aspect),
			width = width,
			height = height,
		})
		table.insert(views, {
			name = "mobile",
			camera = Raster.perspective(eye, target, 70, 480 / 270),
			width = 480,
			height = 270,
		})
	end

	-- (d) 위에서 (직교, 위쪽 = -Z). 플레이 영역보다 높은 지붕·후드·간판은 빼고 그려요 (배치가 가려지지 않게)
	local tcx, tcz = (jb[1] + jb[4]) / 2, (jb[3] + jb[6]) / 2
	local halfH = math.max(jsz / 2, jsx / 2 / aspect) * 1.08 + 4
	local top = Raster.orthographic(v3(tcx, jb[5] + 400, tcz), v3(0, -1, 0), v3(0, 0, -1), halfH * aspect, halfH)
	top.clipAboveY = jb[5] + 6
	table.insert(views, { name = "top", camera = top, width = width, height = height })
	return views
end

local function fmt(n: number): string
	return string.format("%.0f", n)
end

local function pascal(id: string): string
	return (string.gsub("-" .. id, "%-(%w)", string.upper))
end

-- 맵 아트 모듈의 예산 단계 (<Map>Art.BUDGET, 없으면 Standard)
local function budgetTier(mapId: string): string
	local ok, art = pcall(function()
		return Shims.require((Shared.maps :: any)[pascal(mapId) .. "Art"])
	end)
	if ok and type(art) == "table" and type(art.BUDGET) == "string" then
		return art.BUDGET
	end
	return "Standard"
end

local function countModel(model: any): (number, number, number, number)
	local lights, shadowed, particles, anim = 0, 0, 0, 0
	local animTag = "MapDecorAnim"
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			lights += 1
			local ok, shadows = pcall(function()
				return d.Shadows
			end)
			if ok and shadows then
				shadowed += 1
			end
		elseif d:IsA("ParticleEmitter") then
			particles += 1
		elseif d:IsA("BasePart") and d:HasTag(animTag) then
			anim += 1
		end
	end
	return lights, shadowed, particles, anim
end

local function renderMap(mapId: string): boolean
	local okGet, map = pcall(Maps.get, mapId)
	if not okGet then
		print(`[render] {mapId}: unknown map`)
		return false
	end
	local t0 = os.clock()
	local hasArt = studioArt and Shims.loadStudioArt(mapId)
	local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
	local ok, model = pcall(map.build, origin)
	if not ok then
		print(`[render] {mapId}: build failed in the preview shim — {tostring(model)}`)
		print(
			"[render]   위 메시지의 API(메서드·속성·서비스 이름)가 tools/render/Shims.luau에 없어요. 그 맵만 건너뛰어요."
		)
		return false
	end
	model.Parent = Shims.game.Workspace

	local scene = Scene.new()
	Scene.addModel(scene, model)
	local st = scene.stats
	-- 빔은 반투명 막대로 그려요
	for _, beam in scene.beams do
		local a = roblox.Vector3.new(beam.ax, beam.ay, beam.az)
		local b = roblox.Vector3.new(beam.bx, beam.by, beam.bz)
		local len = (b - a).Magnitude
		if len > 0.01 then
			local w = (beam.width0 + beam.width1) / 2
			Scene.addBox(
				scene,
				Shims.lookAt((a + b) / 2, b),
				roblox.Vector3.new(w, w, len),
				{ beam.r ^ (1 / 2.2), beam.g ^ (1 / 2.2), beam.b ^ (1 / 2.2) },
				if beam.lightEmission > 0.5 then "Neon" else "SmoothPlastic",
				{ transparency = 1 - beam.alpha, castShadow = false, decor = true, name = "Beam" }
			)
		end
	end

	local all = boundsOf(scene, true)
	local jb = boundsOf(scene, false)
	-- 그림자 범위: 전체가 너무 크면(먼 배경판) 플레이 영역 + 200으로
	local shadowBounds = all
	if math.max(all[4] - all[1], all[6] - all[3]) > 1600 then
		shadowBounds = { jb[1] - 200, all[2], jb[3] - 200, jb[4] + 200, all[5], jb[6] + 200 }
	end
	local lighting = if lobbyLight or map.lighting == nil then MapLighting.LOBBY else MapLighting.resolve(map.lighting)

	local dir = `{outDir}/{mapId}`
	fs.writeDir(dir)
	local voids = {}
	local filter = viewArg
	for _, view in makeViews(map, model, scene, origin) do
		local kind = if string.sub(view.name, 1, 6) == "intro-" then "intro" else view.name
		if filter ~= "all" and filter ~= kind and filter ~= view.name then
			continue
		end
		local image = Raster.render(scene, view.camera, lighting, shadowBounds, {
			width = view.width,
			height = view.height,
			supersample = supersample,
			shadowSize = shadowSize,
		})
		fs.writeFile(`{dir}/{view.name}.png`, Png.encode(image.width, image.height, image.rgb))
		table.insert(voids, `{view.name}:{fmt(image.void * 100)}%`)
	end

	local lights, shadowed, particles, anim = countModel(model)
	local tier = budgetTier(mapId)
	local budget = MapKitLogic.budget(tier)
	local line = string.format(
		"[render] %s decor=%d/%d lights=%d/%d (shadowed %d/%d) particles=%d/%d anim=%d/%d tris=%d void=%s time=%.1fs",
		mapId,
		st.decor,
		budget.parts,
		lights,
		budget.lights,
		shadowed,
		budget.shadowedLights,
		particles,
		budget.particles,
		anim,
		budget.anim,
		#scene.p,
		table.concat(voids, ","),
		os.clock() - t0
	)
	local detail = `[render]   {map.kind} · budget {tier} · parts {st.parts} (judgment {st.judgment}, decor {st.decor}, hidden {st.hidden})`
		.. ` · beams {st.beams} · lighting {if map.lighting and not lobbyLight then "map preset" else "lobby"}`
		.. (if hasArt then " · studio art" else "")
		.. `\n[render]   bounds all {fmt(all[4] - all[1])}x{fmt(all[5] - all[2])}x{fmt(all[6] - all[3])}`
		.. ` · play area {fmt(jb[4] - jb[1])}x{fmt(jb[5] - jb[2])}x{fmt(jb[6] - jb[3])} · out {dir}/`
	print(line)
	print(detail)
	fs.writeFile(`{dir}/stats.txt`, line .. "\n" .. detail .. "\n")
	return true
end

local targets = {}
if mapArg == "all" then
	for _, info in Maps.allInfos() do
		table.insert(targets, info.id)
	end
else
	table.insert(targets, mapArg :: string)
end
local failed = 0
for _, id in targets do
	if not renderMap(id) then
		failed += 1
	end
end
if failed > 0 then
	print(`[render] {failed} map(s) failed`)
	process.exit(1)
end
