--!strict
-- m3-02 계란초밥 몸 (SushiBody.layout / bounds), m5-21: Wedge·효과 예산·박스 허용치 테이블

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local SushiBody = RobloxRequire.require(Shared.SushiBody)

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

return function(t: Test.Test)
	t.test(
		"AC1: tamago에 Body·계란(토핑·자락)·김 띠·김 끈·눈 2개가 있고 이름이 겹치지 않아요",
		function()
			local layout = SushiBody.layout("tamago")
			local seen = {}
			for _, spec in layout do
				t.ok(seen[spec.name] == nil, `duplicate part name {spec.name}`)
				seen[spec.name] = true
			end
			for _, name in { "Body", "Topping", "ToppingBack", "Nori", "Strap", "StrapBack", "EyeLeft", "EyeRight" } do
				t.ok(seen[name] == true, `missing {name}`)
			end
		end
	)

	t.test("AC1: Body가 기준(오프셋 0)이고 모든 파츠에 크기·색·재질이 있어요", function()
		local layout = SushiBody.layout("tamago")
		local body = byName(layout).Body
		t.eq(body.offset[1], 0)
		t.eq(body.offset[2], 0)
		t.eq(body.offset[3], 0)
		for _, spec in layout do
			t.eq(#spec.size, 3)
			t.eq(#spec.color, 3)
			t.eq(#spec.offset, 3)
			t.ok(type(spec.material) == "string" and #spec.material > 0, `material of {spec.name}`)
			for axis = 1, 3 do
				t.ok(spec.size[axis] > 0, `size of {spec.name}`)
				t.ok(spec.color[axis] >= 0 and spec.color[axis] <= 255, `color of {spec.name}`)
			end
		end
	end)

	t.test(
		"AC2·m5-25 AC1: 넓고 낮은 몸 — 높이 4.0~4.6, 폭 3.6~4.0, 두께 3.2 이하, 폭/높이 0.8 이상",
		function()
			local b = SushiBody.bounds(SushiBody.layout("tamago"))
			local width = b.max[1] - b.min[1]
			local height = b.max[2] - b.min[2]
			local depth = b.max[3] - b.min[3]
			t.ok(height >= 4.0 and height <= 4.6, `height {height}`)
			t.ok(width >= 3.6 and width <= 4.0, `width {width}`)
			t.ok(depth <= 3.2, `depth {depth}`)
			t.ok(width / height >= 0.8, `width/height {width / height}`)
		end
	)

	t.test("AC2: GROUND_OFFSET은 Body 중심에서 발바닥까지", function()
		local b = SushiBody.bounds(SushiBody.layout("tamago"))
		t.ok(math.abs(-b.min[2] - SushiBody.GROUND_OFFSET) < 1e-6, `bottom {b.min[2]}`)
	end)

	t.test("AC1: 눈은 앞면(-Z) 밖으로 나와 있고, 왼쪽·오른쪽에 하나씩", function()
		local parts = byName(SushiBody.layout("tamago"))
		local bodyFront = -parts.Body.size[3] / 2
		for _, name in { "EyeLeft", "EyeRight", "EyeWhiteLeft", "EyeWhiteRight", "PupilLeft", "PupilRight" } do
			local b = SushiBody.bounds({ parts[name] })
			t.ok(b.min[3] < bodyFront - 0.01, `{name} in front ({b.min[3]})`)
		end
		t.ok(parts.EyeLeft.offset[1] < 0 and parts.EyeRight.offset[1] > 0, "eyes left/right")
	end)

	t.test("AC3: 모르는 id는 tamago와 같아요", function()
		local a = SushiBody.layout("no-such-skin")
		local b = SushiBody.layout("tamago")
		t.eq(#a, #b)
		for i, spec in b do
			t.eq(a[i].name, spec.name)
			t.eq(a[i].material, spec.material)
			for axis = 1, 3 do
				t.eq(a[i].size[axis], spec.size[axis])
				t.eq(a[i].color[axis], spec.color[axis])
				t.eq(a[i].offset[axis], spec.offset[axis])
			end
		end
	end)

	t.test("layout은 복사본이라 고쳐도 다음 결과가 안 바뀌어요", function()
		local first = SushiBody.layout("tamago")
		first[1].size[1] = 999
		first[1].name = "Changed"
		local second = SushiBody.layout("tamago")
		t.eq(second[1].name, "Body")
		t.ok(second[1].size[1] ~= 999, "size copied")
	end)

	---------------------------------------------------------------- m5-21 Wedge
	t.test(
		"AC1: Wedge spec의 bounds는 같은 size·offset·rotation의 Block spec과 같아요 (회전 없음 + 90도)",
		function()
			local wedge = {
				name = "W",
				size = { 1, 2, 3 },
				color = { 0, 0, 0 },
				material = "SmoothPlastic",
				offset = { 0.5, -0.25, 1 },
				shape = "Wedge",
			}
			local block = table.clone(wedge)
			block.shape = "Block"
			local bw = SushiBody.bounds({ wedge } :: any)
			local bb = SushiBody.bounds({ block } :: any)
			for axis = 1, 3 do
				t.eq(bw.min[axis], bb.min[axis], `min axis {axis}`)
				t.eq(bw.max[axis], bb.max[axis], `max axis {axis}`)
			end

			local wedgeRotated = table.clone(wedge)
			wedgeRotated.rotation = { 0, 90, 0 }
			local blockRotated = table.clone(block)
			blockRotated.rotation = { 0, 90, 0 }
			local bwr = SushiBody.bounds({ wedgeRotated } :: any)
			local bbr = SushiBody.bounds({ blockRotated } :: any)
			for axis = 1, 3 do
				t.eq(bwr.min[axis], bbr.min[axis], `rotated min axis {axis}`)
				t.eq(bwr.max[axis], bbr.max[axis], `rotated max axis {axis}`)
			end
		end
	)

	---------------------------------------------------------------- m5-21 효과 예산·박스 허용치 테이블
	t.test(
		"AC3: EFFECT_BUDGET·BOUNDS_TOLERANCE 값이 맞고 SushiBody는 순수 SushiConceptSample만 require해요 (m5-27)",
		function()
			t.eq(SushiBody.EFFECT_BUDGET.Common, 1)
			t.eq(SushiBody.EFFECT_BUDGET.Rare, 1)
			t.eq(SushiBody.EFFECT_BUDGET.Epic, 2)
			t.eq(SushiBody.EFFECT_BUDGET.Legendary, 2)
			t.eq(SushiBody.BOUNDS_TOLERANCE.Common, 0.15)
			t.eq(SushiBody.BOUNDS_TOLERANCE.Rare, 0.15)
			t.eq(SushiBody.BOUNDS_TOLERANCE.Epic, 0.25)
			t.eq(SushiBody.BOUNDS_TOLERANCE.Legendary, 0.25)
			local source = fs.readFile("src/shared/SushiBody.luau")
			-- 유일한 예외 (m5-27): 순수 SushiConceptSample 하나만, 그 모듈은 아무것도 require하지 않아요
			local _, count = string.gsub(source, "require%(", "")
			t.eq(count, 1, "SushiBody requires only SushiConceptSample")
			t.ok(string.find(source, "require(script.Parent.SushiConceptSample)", 1, true) ~= nil, "concept require")
			-- m5-32: 견본은 순수 고등어 토핑 모듈(ConceptMackerel → PartMath)만 불러요 (Roblox API 없음)
			local sample = fs.readFile("src/shared/SushiConceptSample.luau")
			local _, sampleCount = string.gsub(sample, "require%(", "")
			t.eq(sampleCount, 1, "SushiConceptSample requires only ConceptMackerel")
			for _, path in { "src/shared/ConceptMackerel.luau", "src/shared/PartMath.luau" } do
				local src = fs.readFile(path)
				t.eq(string.find(src, "game:GetService", 1, true), nil, `{path} pure`)
				t.eq(string.find(src, "Instance.new", 1, true), nil, `{path} pure`)
			end
		end
	)

	---------------------------------------------------------------- m5-07 시즌 한정·VIP 생김새
	local SEASON_SKINS = {
		-- m5-25 재배치 이름 (호박 = 높은 토핑, 유령 천 = Sheet, VIP = 금 띠·금 끈)
		["pumpkin-sushi"] = { "Topping", "JackEyeLeft", "JackEyeRight", "JackMouth", "Stem" },
		["ghost-tamago"] = { "Sheet", "SheetBack", "GhostEyeLeft", "GhostEyeRight" },
		["santa-shrimp"] = { "HatBrim", "HatBase", "HatPompom", "Band1" },
		["tree-maki"] = { "TreeLayer1", "TreeLayer2", "TreeLayer3", "StarA" },
		["vip-gold-tamago"] = { "GoldLeaf1", "Nori", "Strap" },
	}

	t.test(
		"m5-07 AC6: 새 스킨 5종은 자리 표시가 아니고(계란초밥과 다름) 이름이 겹치지 않아요",
		function()
			local tamago = SushiBody.layout("tamago")
			for id, signature in SEASON_SKINS do
				t.ok(SushiBody.hasLayout(id), id)
				local layout = SushiBody.layout(id)
				local parts = byName(layout)
				local seen = 0
				for _ in parts do
					seen += 1
				end
				t.eq(seen, #layout, `{id} duplicate part names`)
				for _, name in signature do
					t.ok(parts[name] ~= nil, `{id} missing {name}`)
				end
				local tamagoNames = byName(tamago)
				local extra = 0
				for name in parts do
					if tamagoNames[name] == nil then
						extra += 1
					end
				end
				t.ok(extra >= 2, `{id} differs from tamago`)
				-- 밥 몸통·얼굴·발은 같아요
				for _, name in { "Body", "EyeLeft", "EyeRight", "Mouth", "FootLeft", "FootRight" } do
					t.ok(parts[name] ~= nil, `{id} keeps {name}`)
				end
			end
		end
	)

	t.test("m5-07 AC6: 외곽 상자는 계란초밥 ±15% 안, 효과 1개 이하", function()
		local base = SushiBody.bounds(SushiBody.layout("tamago"))
		for id in SEASON_SKINS do
			local layout = SushiBody.layout(id)
			local b = SushiBody.bounds(layout)
			for axis = 1, 3 do
				local ratio = (b.max[axis] - b.min[axis]) / (base.max[axis] - base.min[axis])
				t.ok(ratio >= 0.85 and ratio <= 1.15, `{id} axis {axis} ratio {ratio}`)
			end
			t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) < 1e-6, `{id} feet on the ground`)
			t.ok(SushiBody.effectCount(layout) <= 1, `{id} effects`)
		end
	end)

	t.test("m5-07: 유령 천은 반투명(0.25)이고 빛 효과, 나머지 파츠는 불투명", function()
		local parts = byName(SushiBody.layout("ghost-tamago"))
		t.eq(parts.Sheet.transparency, 0.25)
		t.eq(parts.SheetBack.transparency, 0.25)
		t.eq(parts.GhostGlow.effect, "Glow")
		t.eq(parts.Body.transparency, nil)
		local tree = byName(SushiBody.layout("tree-maki"))
		t.eq(tree.StarA.effect, "Sparkles")
		local gold = byName(SushiBody.layout("vip-gold-tamago"))
		t.eq(gold.GoldLeaf1.effect, "Sparkles")
		t.eq(gold.GoldLeaf1.material, "Foil")
		-- 투명도도 복사본이에요
		local copy = SushiBody.layout("ghost-tamago")
		for _, spec in copy do
			spec.transparency = 1
		end
		t.eq(byName(SushiBody.layout("ghost-tamago")).Sheet.transparency, 0.25)
		local source = fs.readFile("src/shared/SushiBody.luau")
		t.ok(
			string.find(source, "part.Transparency = spec.transparency or 0", 1, true) ~= nil,
			"build sets Transparency"
		)
	end)
end
