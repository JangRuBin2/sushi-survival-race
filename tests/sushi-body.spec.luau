--!strict
-- m3-02 계란초밥 몸 (SushiBody.layout / bounds)

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
	t.test("AC1: tamago에 Body·계란·김 띠·눈 2개가 있고 이름이 겹치지 않아요", function()
		local layout = SushiBody.layout("tamago")
		local seen = {}
		for _, spec in layout do
			t.ok(seen[spec.name] == nil, `duplicate part name {spec.name}`)
			seen[spec.name] = true
		end
		for _, name in { "Body", "Egg", "Nori", "EyeLeft", "EyeRight" } do
			t.ok(seen[name] == true, `missing {name}`)
		end
	end)

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

	t.test("AC2: 외곽 높이 4.5~5.5, 폭·두께 3.2 이하", function()
		local b = SushiBody.bounds(SushiBody.layout("tamago"))
		local width = b.max[1] - b.min[1]
		local height = b.max[2] - b.min[2]
		local depth = b.max[3] - b.min[3]
		t.ok(height >= 4.5 and height <= 5.5, `height {height}`)
		t.ok(width <= 3.2, `width {width}`)
		t.ok(depth <= 3.2, `depth {depth}`)
	end)

	t.test("AC2: GROUND_OFFSET은 Body 중심에서 발바닥까지", function()
		local b = SushiBody.bounds(SushiBody.layout("tamago"))
		t.ok(math.abs(-b.min[2] - SushiBody.GROUND_OFFSET) < 1e-6, `bottom {b.min[2]}`)
	end)

	t.test("AC1: 눈은 앞면(-Z)에, 왼쪽·오른쪽에 하나씩", function()
		local parts = byName(SushiBody.layout("tamago"))
		local bodyFront = -parts.Body.size[3] / 2
		for _, name in { "EyeLeft", "EyeRight" } do
			t.ok(parts[name].offset[3] < bodyFront + 0.01, `{name} in front`)
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
end
