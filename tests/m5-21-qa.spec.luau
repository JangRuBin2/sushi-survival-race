--!strict
-- m5-21 QA: 스킨 기반 v2 (Wedge · 등급별 효과 예산 · 등급별 박스 허용치)
--   - Wedge 외곽 상자 == Block 외곽 상자 (90도가 아닌 임의 회전 포함)
--   - Skins.validate가 실제로 등급별 경계를 잡는지 (가짜 레이아웃을 주입한 새 Skins 인스턴스로)
--   - 가짜 Instance로 build: Wedge → WedgePart(.Shape 안 씀), Smoke → ParticleEmitter, Glow → 작은 PointLight,
--     setEffectsEnabled가 PointLight도 끔, 모든 파츠 Massless·충돌·쿼리·터치 없음 (겉모습만)

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RealSushiBody = RobloxRequire.require(Shared.SushiBody)

local SUSHI_SOURCE = fs.readFile("src/shared/SushiBody.luau")

---------------------------------------------------------------- 주입 가능한 Skins
local function loadSharedFresh(name: string, deps: { [string]: any }): any
	local path = `src/shared/{name}.luau`
	local parent = setmetatable({}, {
		__index = function(_, k)
			return { __dep = k }
		end,
	})
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			script = { Parent = parent },
			require = function(target: any)
				return assert(deps[target.__dep], `missing dep {target.__dep}`)
			end,
		},
	})()
end

-- overrides[id] = 레이아웃이면 그 id의 레이아웃을 바꿔치기한 SushiBody로 Skins를 새로 불러와요
local function skinsWith(overrides: { [string]: { any } }): any
	local fakeBody = setmetatable({
		layout = function(id: string)
			return overrides[id] or RealSushiBody.layout(id)
		end,
		hasLayout = function(id: string)
			return overrides[id] ~= nil or RealSushiBody.hasLayout(id)
		end,
	}, { __index = RealSushiBody })
	local Seasons = loadSharedFresh("Seasons", {})
	return loadSharedFresh("Skins", { Config = Config, Seasons = Seasons, SushiBody = fakeBody })
end

-- 계란초밥 + 머리 위 가는 기둥 하나: 전체 높이가 계란초밥의 ratio 배가 돼요 (바닥 -2.3 고정)
local function tallLayout(ratio: number, effects: { string }?): { any }
	local base = RealSushiBody.layout("tamago")
	local b = RealSushiBody.bounds(base)
	local height = b.max[2] - b.min[2]
	local top = b.min[2] + height * ratio
	local layout = table.clone(base)
	local spikeHeight = 0.2
	table.insert(layout, {
		name = "QaSpike",
		size = { 0.1, spikeHeight, 0.1 },
		color = { 255, 0, 0 },
		material = "SmoothPlastic",
		offset = { 0, top - spikeHeight / 2, 0 },
	})
	for i, effect in effects or {} do
		table.insert(layout, {
			name = `QaFx{i}`,
			size = { 0.1, 0.1, 0.1 },
			color = { 255, 255, 255 },
			material = "SmoothPlastic",
			offset = { 0, 0.5, 0 },
			effect = effect,
		})
	end
	return layout
end

local function testSkin(id: string, tier: string): any
	local skin: any = {
		id = id,
		displayName = "QA",
		tier = tier,
		speech = { "QA" },
		order = 9000,
	}
	if tier == "Common" or tier == "Rare" then
		skin.robux = if tier == "Common" then 29 else 59
		skin.coins = if tier == "Common" then 300 else 900
	else
		skin.robux = if tier == "Epic" then 99 else 199
	end
	return skin
end

local function problemsFor(skins: any, extra: any): { string }
	local list = table.clone(skins.LIST)
	table.insert(list, extra)
	local _, problems = skins.validate(list)
	return problems
end

local function hasProblem(problems: { string }, needle: string): boolean
	for _, p in problems do
		if string.find(p, needle, 1, true) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- SushiBody 가짜 Instance (m4-13-qa와 같은 방식)
local function proxyEnum(prefix: string): any
	return setmetatable({}, {
		__index = function(_, k)
			if prefix == "" then
				return proxyEnum(k)
			end
			return `{prefix}.{k}`
		end,
	})
end

local function fakeValue(kind: string)
	return {
		new = function(...)
			return { __kind = kind, args = { ... } }
		end,
	}
end

local function newFakeInstance(className: string): any
	local inst: any = { ClassName = className, Name = className, _children = {}, _parent = nil, _set = {} }
	local mt = {}
	mt.__index = function(self, key)
		if key == "Parent" then
			return rawget(self, "_parent")
		elseif key == "GetChildren" then
			return function(s)
				return table.clone(s._children)
			end
		elseif key == "GetDescendants" then
			return function(s)
				local out = {}
				local function walk(x)
					for _, c in x._children do
						table.insert(out, c)
						walk(c)
					end
				end
				walk(s)
				return out
			end
		elseif key == "IsA" then
			return function(s, name)
				if name == "BasePart" then
					return s.ClassName == "Part" or s.ClassName == "WedgePart"
				end
				return s.ClassName == name
			end
		end
		return nil
	end
	mt.__newindex = function(self, key, value)
		if key == "Parent" then
			local old = rawget(self, "_parent")
			if old then
				local i = table.find(old._children, self)
				if i then
					table.remove(old._children, i)
				end
			end
			rawset(self, "_parent", value)
			if value then
				table.insert(value._children, self)
			end
			return
		end
		if key == "Shape" and rawget(self, "ClassName") == "WedgePart" then
			error("WedgePart has no Shape property")
		end
		rawset(self, key, value)
	end
	return setmetatable(inst, mt)
end

local CFRAME_MT = {}
CFRAME_MT.__mul = function(a: any, b: any): any
	return setmetatable({ __kind = "Product", args = { a, b } }, CFRAME_MT)
end

local function loadFakeSushiBody(): any
	local chunk = luau.load(SUSHI_SOURCE, {
		debugName = "SushiBody(fake)",
		environment = {
			script = Shared.SushiBody,
			require = function(m: any)
				return RobloxRequire.require(m)
			end,
			Instance = { new = newFakeInstance },
			Vector3 = fakeValue("Vector3"),
			Vector2 = fakeValue("Vector2"),
			Color3 = {
				fromRGB = function(r, g, b)
					return { R = r, G = g, B = b }
				end,
			},
			CFrame = {
				new = function(...)
					return setmetatable({ __kind = "CFrame", args = { ... } }, CFRAME_MT)
				end,
				Angles = function(...)
					return setmetatable({ __kind = "Angles", args = { ... } }, CFRAME_MT)
				end,
			},
			ColorSequence = fakeValue("ColorSequence"),
			NumberSequence = fakeValue("NumberSequence"),
			NumberRange = fakeValue("NumberRange"),
			Enum = proxyEnum(""),
		},
	})
	return chunk()
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return function(t: Test.Test)
	t.test(
		"QA AC1: Wedge 외곽 상자 == Block 외곽 상자 (90도가 아닌 회전·여러 축 회전 포함)",
		function()
			local rotations: { { number }? } =
				{ nil, { 0, 0, 20 }, { 10, 0, 15 }, { 0, 45, 0 }, { 30, 60, 90 }, { -25, 0, 0 } }
			for i = 1, #rotations + 1 do
				local rot = rotations[i]
				local function one(shape: string): any
					return RealSushiBody.bounds({
						{
							name = "X",
							shape = shape,
							size = { 0.5, 0.7, 0.35 },
							color = { 1, 1, 1 },
							material = "SmoothPlastic",
							offset = { 0.65, 2.68, -0.45 },
							rotation = rot,
						},
					})
				end
				local w, b = one("Wedge"), one("Block")
				for axis = 1, 3 do
					t.ok(near(w.min[axis], b.min[axis]) and near(w.max[axis], b.max[axis]), `rotation #{i} axis {axis}`)
				end
			end
		end
	)

	t.test("QA AC3: 예산·허용치 표 값과 SushiBody에 require 없음", function()
		t.eq(RealSushiBody.EFFECT_BUDGET.Common, 1)
		t.eq(RealSushiBody.EFFECT_BUDGET.Rare, 1)
		t.eq(RealSushiBody.EFFECT_BUDGET.Epic, 2)
		t.eq(RealSushiBody.EFFECT_BUDGET.Legendary, 2)
		t.eq(RealSushiBody.EFFECT_BUDGET.Basic, 0)
		t.eq(RealSushiBody.BOUNDS_TOLERANCE.Common, 0.15)
		t.eq(RealSushiBody.BOUNDS_TOLERANCE.Rare, 0.15)
		t.eq(RealSushiBody.BOUNDS_TOLERANCE.Epic, 0.25)
		t.eq(RealSushiBody.BOUNDS_TOLERANCE.Legendary, 0.25)
		t.eq(string.find(SUSHI_SOURCE, "require(", 1, true), nil)
	end)

	t.test(
		"QA AC5·AC6: validate 박스 경계 — 일반·레어 1.14 통과/1.16 실패, 에픽·전설 1.24 통과/1.26 실패",
		function()
			local cases = {
				{ tier = "Common", ratio = 1.14, ok = true },
				{ tier = "Common", ratio = 1.16, ok = false },
				{ tier = "Rare", ratio = 1.14, ok = true },
				{ tier = "Rare", ratio = 1.20, ok = false },
				{ tier = "Epic", ratio = 1.20, ok = true },
				{ tier = "Epic", ratio = 1.24, ok = true },
				{ tier = "Epic", ratio = 1.26, ok = false },
				{ tier = "Legendary", ratio = 1.24, ok = true },
				{ tier = "Legendary", ratio = 1.30, ok = false },
			}
			for i, case in cases do
				local id = `qa-tall-{i}`
				local skins = skinsWith({ [id] = tallLayout(case.ratio) })
				local problems = problemsFor(skins, testSkin(id, case.tier))
				t.eq(#problems == 0, case.ok, `{case.tier} ratio {case.ratio}: {table.concat(problems, "; ")}`)
				if not case.ok then
					t.ok(hasProblem(problems, "outside tolerance"), `{case.tier} {case.ratio} message`)
				end
			end
		end
	)

	t.test(
		"QA AC4·AC6: validate 효과 예산 — 일반 1·에픽 2·전설 2 통과, 레어 2·전설 3 실패",
		function()
			local cases = {
				{ tier = "Common", effects = { "Sparkles" }, ok = true },
				{ tier = "Rare", effects = { "Glow", "Smoke" }, ok = false },
				{ tier = "Epic", effects = { "Smoke", "Glow" }, ok = true },
				{ tier = "Legendary", effects = { "Fire", "Sparkles" }, ok = true },
				{ tier = "Legendary", effects = { "Fire", "Sparkles", "Glow" }, ok = false },
			}
			for i, case in cases do
				local id = `qa-fx-{i}`
				local skins = skinsWith({ [id] = tallLayout(1, case.effects) })
				local problems = problemsFor(skins, testSkin(id, case.tier))
				t.eq(#problems == 0, case.ok, `{case.tier} x{#case.effects}: {table.concat(problems, "; ")}`)
				if not case.ok then
					t.ok(hasProblem(problems, "effect budget exceeded"), `{case.tier} message`)
				end
			end
		end
	)

	t.test(
		"QA AC7: 모르는 등급·레이아웃 없는 id는 기하 검사를 건너뛰고 에러 없이 문제만 기록",
		function()
			local skins = skinsWith({ ["qa-mythic"] = tallLayout(2, { "Fire", "Fire", "Fire" }) })
			local weird = testSkin("qa-mythic", "Epic")
			weird.tier = "Mythic"
			local problems = problemsFor(skins, weird)
			t.ok(hasProblem(problems, "tier"), "unknown tier reported")
			t.ok(not hasProblem(problems, "effect budget exceeded"), "no budget check for unknown tier")
			t.ok(not hasProblem(problems, "outside tolerance"), "no bounds check for unknown tier")
			local noLayout = testSkin("qa-no-layout", "Rare")
			local problems2 = problemsFor(skinsWith({}), noLayout)
			t.eq(#problems2, 0, table.concat(problems2, "; "))
		end
	)

	t.test(
		"QA build: Wedge는 WedgePart(.Shape 안 씀), Smoke는 ParticleEmitter, Glow는 작은 PointLight",
		function()
			local SushiBody = loadFakeSushiBody()
			local layout = table.clone(RealSushiBody.layout("tamago"))
			table.insert(layout, {
				name = "QaWedge",
				shape = "Wedge",
				size = { 0.5, 0.7, 0.35 },
				color = { 255, 160, 190 },
				material = "SmoothPlastic",
				offset = { 0, 2.6, 0 },
				rotation = { 0, 0, 20 },
				effect = "Smoke",
			})
			table.insert(layout, {
				name = "QaGlow",
				shape = "Ball",
				size = { 0.2, 0.2, 0.2 },
				color = { 255, 255, 255 },
				material = "Neon",
				offset = { 0, 1, 1.1 },
				effect = "Glow",
				effectColor = { 200, 200, 255 },
			})
			SushiBody.layout = function(_id: string)
				return layout
			end
			local model = SushiBody.build("qa")
			local wedge, emitters, lights = nil, 0, {}
			for _, inst in model:GetDescendants() do
				if inst.Name == "QaWedge" then
					wedge = inst
				elseif inst.ClassName == "ParticleEmitter" then
					emitters += 1
					t.eq(inst.Name, "SkinEffect")
					t.eq(inst.Parent and inst.Parent.Name, "QaWedge")
				elseif inst.ClassName == "PointLight" then
					table.insert(lights, inst)
				end
				if inst.ClassName == "Part" or inst.ClassName == "WedgePart" then
					t.eq(inst.Massless, true, inst.Name)
					t.eq(inst.CanCollide, false, inst.Name)
					t.eq(inst.CanQuery, false, inst.Name)
					t.eq(inst.CanTouch, false, inst.Name)
				end
			end
			t.ok(wedge ~= nil, "wedge built")
			t.eq(wedge.ClassName, "WedgePart")
			t.eq(rawget(wedge, "Shape"), nil)
			-- Body에 용접돼요 (WedgePart도 BasePart라 WeldConstraint 루프에 들어가요)
			local weld = nil
			for _, c in wedge._children do
				if c.ClassName == "WeldConstraint" then
					weld = c
				end
			end
			t.ok(weld ~= nil, "wedge welded to body")
			t.eq(emitters, 1)
			t.eq(#lights, 1)
			local light = lights[1]
			t.ok(light.Range <= 8 and light.Brightness <= 2, "glow is small and dim")
			t.eq(light.Parent and light.Parent.Name, "QaGlow")
			SushiBody.setEffectsEnabled(model, false)
			t.eq(light.Enabled, false, "glow off during elimination cutscene")
			SushiBody.setEffectsEnabled(model, true)
			t.eq(light.Enabled, true)
		end
	)

	t.test(
		"QA 공정성: Wedge·효과는 GROUND_OFFSET(이름표·단상 높이 기준)과 무관한 고정값",
		function()
			t.eq(RealSushiBody.GROUND_OFFSET, 2.3)
			-- 모든 스킨의 발바닥이 같은 높이 (토핑이 발보다 아래로 내려가지 않아요)
			local Skins = RobloxRequire.require(Shared.Skins)
			for _, skin in Skins.LIST do
				local b = RealSushiBody.bounds(RealSushiBody.layout(skin.id))
				t.ok(near(b.min[2], -RealSushiBody.GROUND_OFFSET), `{skin.id} min y {b.min[2]}`)
			end
		end
	)
end
