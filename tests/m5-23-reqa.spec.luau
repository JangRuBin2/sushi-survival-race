--!strict
-- m5-23 재QA (docs/qa/m5-23-map-visual-kit-reqa.md): 맵이 21개로 늘어난 뒤(m5-24 아트 패스, m5-33~39 새 맵 6개, m5-40)
-- 키트·렌더러 회귀를 막는 확인. 이전 QA(m5-23-qa)·개발 테스트(m5-23-visual-kit)에 없는 것만.
--   풀 전체: 모든 맵의 Art.decor()가 validate를 통과하고(= buildDecor가 장식 전체를 건너뛰지 않음), 렌더러 환경에서
--            지은 Decor 폴더에 장식이 실제로 생기고, 실제 인스턴스 수(파츠·조명·그림자 조명·파티클·움직임)가
--            그 맵 예산 단계 안. DecorSpec Surface 조명은 모두 range ≤ 16 (B1)
--   buildDecor: 올바른 장식 여러 개 + 틀린 것 하나 → 하나도 안 만듦(부분 생성 없음)
--   렌더러 Scene: 새 맵이 쓰는 인스턴스(LinearVelocity·VectorForce·SurfaceGui·BillboardGui·TextLabel·WeldConstraint·
--            Attachment)가 섞인 모델을 오류 없이 읽고 파츠·조명만 셈
--   render-map 명령: 작은 크기로 한 맵을 돌려 stats.txt 형식(스펙 A 통계 한 줄), 모르는 맵은 끝 코드 1
--   B3 소스: MapLightingController가 서버 효과가 늦게 오면 자기가 만든 것을 지움

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local Scene = require("../tools/render/Scene")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Maps = RobloxRequire.require(Shared.maps)
local Config = RobloxRequire.require(Shared.Config)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)
local RMapKit = Shims.require(RShared.maps.MapKit)

local function pascal(id: string): string
	return (string.gsub("-" .. id, "%-(%w)", string.upper))
end

-- <Map>Art 모듈 (없으면 nil). tools/render-map.luau budgetTier와 같은 규칙
local function artModule(id: string): any
	local ok, art = pcall(function()
		return RobloxRequire.require((Shared.maps :: any)[pascal(id) .. "Art"])
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

local function base(extra: { [string]: any }?): any
	local spec: { [string]: any } = {
		name = "R",
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

local function underDecor(inst: any, model: any): boolean
	local parent = inst.Parent
	while parent and parent ~= model do
		if parent.Name == "Decor" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- 렌더러 countModel과 같은 계산 + Decor 파츠 수
local function countModel(model: any): { [string]: number }
	local c = { decor = 0, lights = 0, shadowed = 0, particles = 0, anim = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			c.lights += 1
			if d.Shadows then
				c.shadowed += 1
			end
		elseif d:IsA("ParticleEmitter") then
			c.particles += 1
		elseif d:IsA("BasePart") then
			if d:HasTag("MapDecorAnim") then
				c.anim += 1
			end
			if underDecor(d, model) then
				c.decor += 1
			end
		end
	end
	return c
end

return function(t: Test.Test)
	t.test(
		"reQA pool: 모든 맵 Art.decor()가 validate 통과 — 장식 전체 건너뛰기 없음, Surface range ≤ 16",
		function()
			local withArt = 0
			for _, id in allIds() do
				local art = artModule(id)
				if art == nil or type(art.decor) ~= "function" then
					continue
				end
				withArt += 1
				local decor = art.decor()
				t.eq(
					MapKitLogic.validate(decor),
					nil,
					`{id}: Art.decor() invalid → MapKit.buildDecor would skip ALL decor`
				)
				for _, spec in decor do
					local light = spec.light
					if light and light.kind == "Surface" then
						t.ok(light.range <= 16, `{id}/{spec.name}: Surface range {light.range} > 16`)
					end
				end
				local tier = if type(art.BUDGET) == "string" then art.BUDGET else "Standard"
				t.eq(MapKitLogic.checkBudget(decor, tier), nil, `{id}: decor over {tier} budget`)
			end
			t.ok(withArt >= 21, `every map in the pool has an Art module with decor() (got {withArt})`)
		end
	)

	t.test(
		"reQA pool: 렌더러 환경에서 지은 모든 맵 — 장식이 실제로 생기고 실제 인스턴스 수가 예산 단계 안",
		function()
			for _, id in allIds() do
				local map = RMaps.get(id)
				local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
				local ok, model = pcall(map.build, origin)
				t.ok(ok, `{id}: build failed in the render shim — {tostring(model)}`)
				if not ok then
					continue
				end
				local c = countModel(model)
				local art = artModule(id)
				local tier = if art and type(art.BUDGET) == "string" then art.BUDGET else "Standard"
				local budget = MapKitLogic.budget(tier)
				if art and type(art.decor) == "function" then
					local specCount = #art.decor()
					t.ok(
						c.decor >= specCount,
						`{id}: Decor folder has {c.decor} parts < {specCount} DecorSpecs (skipped?)`
					)
				end
				t.ok(c.decor <= budget.parts, `{id} ({tier}): decor parts {c.decor} > {budget.parts}`)
				t.ok(c.lights <= budget.lights, `{id} ({tier}): lights {c.lights} > {budget.lights}`)
				t.ok(
					c.shadowed <= budget.shadowedLights,
					`{id} ({tier}): shadowed {c.shadowed} > {budget.shadowedLights}`
				)
				t.ok(c.particles <= budget.particles, `{id} ({tier}): particles {c.particles} > {budget.particles}`)
				t.ok(c.anim <= budget.anim, `{id} ({tier}): anim {c.anim} > {budget.anim}`)
				model:Destroy()
			end
		end
	)

	t.test(
		"reQA buildDecor: 올바른 장식 + 틀린 것 하나 → 아무것도 안 만듦 (부분 생성 없음)",
		function()
			local origin = roblox.CFrame.new(0, 300, 0)
			local surface = { kind = "Surface", color = { r = 255, g = 255, b = 255 }, brightness = 1 }
			local function lightRange(range: number): any
				local l = table.clone(surface) :: any
				l.range = range
				return l
			end
			-- 경계값 그대로면 전부 생성
			local folder = roblox.Instance.new("Folder")
			local good = {
				base({ name = "A" }),
				base({ name = "B", light = lightRange(16) }),
				base({ name = "C", particle = "Steam" }),
				base({ name = "D", anim = { kind = "Spin", period = 4 } }),
			}
			t.eq(#RMapKit.buildDecor(good, origin, folder), 4, "all valid → 4 parts")
			t.eq(#folder:GetChildren(), 4)
			-- 마지막 하나만 틀려도(Surface 17 — B1 경계) 하나도 안 만듦
			for _, bad in
				{
					base({ name = "E", light = lightRange(17) }),
					base({ name = "E", particle = "NoSuchPreset" }),
					base({ name = "E", anim = { kind = "Bob", period = 0.4, amount = 1 } }),
					base({ name = "E", shape = "Cone" }),
				}
			do
				local list = table.clone(good)
				table.insert(list, bad)
				local f2 = roblox.Instance.new("Folder")
				t.ok(MapKitLogic.validate(list) ~= nil, "list is invalid")
				t.eq(#RMapKit.buildDecor(list, origin, f2), 0, "invalid list → no parts")
				t.eq(#f2:GetChildren(), 0, "nothing parented")
			end
		end
	)

	t.test(
		"reQA Scene: 새 맵 인스턴스(LinearVelocity·SurfaceGui 등)가 섞여도 오류 없이 파츠·조명만 셈",
		function()
			local model = roblox.Instance.new("Model")
			local part = roblox.Instance.new("Part")
			part.Size = roblox.Vector3.new(4, 1, 4)
			part.CFrame = roblox.CFrame.new(0, 300, 0)
			part.Parent = model
			local att = roblox.Instance.new("Attachment")
			att.Parent = part
			local lv = roblox.Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.Parent = part
			local vf = roblox.Instance.new("VectorForce")
			vf.Attachment0 = att
			vf.Parent = part
			local weld = roblox.Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Parent = part
			local gui = roblox.Instance.new("SurfaceGui")
			gui.Parent = part
			local label = roblox.Instance.new("TextLabel")
			label.Text = "test"
			label.Parent = gui
			local bb = roblox.Instance.new("BillboardGui")
			bb.Parent = part
			local light = roblox.Instance.new("SurfaceLight")
			light.Range = 40 -- Lune은 안 자름 → Scene이 16으로 잘라야 해요 (B1)
			light.Parent = part
			local scene = Scene.new()
			local ok, err = pcall(Scene.addModel, scene, model)
			t.ok(ok, `Scene.addModel failed: {tostring(err)}`)
			t.eq(scene.stats.parts, 1, "one BasePart")
			t.eq(scene.stats.lights, 1, "one light")
			t.ok(#scene.lights == 1 and scene.lights[1].range <= 16, "Surface range clamped to 16 in the renderer")
		end
	)

	t.test("reQA render-map 명령: stats.txt 형식, 모르는 맵은 끝 코드 1", function()
		local out = "build/reqa-render-test"
		local res = process.exec("lune", {
			"run",
			"tools/render-map",
			"hot-plate",
			"--view",
			"top",
			"--quality",
			"fast",
			"--size",
			"160x90",
			"--out",
			out,
		})
		t.ok(res.ok, `render-map hot-plate failed: {res.stdout} {res.stderr}`)
		local statsPath = `{out}/hot-plate/stats.txt`
		t.ok(fs.isFile(statsPath), "stats.txt written")
		t.ok(fs.isFile(`{out}/hot-plate/top.png`), "top.png written")
		if fs.isFile(statsPath) then
			local first = string.match(fs.readFile(statsPath), "^[^\n]+") or ""
			local pattern = "^%[render%] hot%-plate decor=%d+/%d+ lights=%d+/%d+ %(shadowed %d+/%d+%) particles=%d+/%d+ "
				.. "anim=%d+/%d+ tris=%d+ void=top:%d+%% time=[%d%.]+s$"
			t.ok(string.match(first, pattern) ~= nil, `stats line format: {first}`)
		end
		local bad = process.exec("lune", { "run", "tools/render-map", "no-such-map", "--out", out })
		t.ok(not bad.ok and bad.code == 1, "unknown map exits 1")
		t.ok(string.find(bad.stdout, "unknown map", 1, true) ~= nil, "unknown map message")
		pcall(fs.removeDir, out)
	end)

	t.test(
		"reQA B3 소스: 서버 효과가 늦게 오면 클라이언트가 만든 효과를 지우고 다시 적용",
		function()
			local src = fs.readFile("src/client/fx/MapLightingController.luau")
			t.ok(string.find(src, "Lighting.ChildAdded:Connect", 1, true) ~= nil, "listens to Lighting.ChildAdded")
			t.ok(string.find(src, "mine:Destroy()", 1, true) ~= nil, "destroys the locally created duplicate")
			t.ok(string.find(src, "localCreated[className] = created", 1, true) ~= nil, "remembers what it created")
		end
	)
end
