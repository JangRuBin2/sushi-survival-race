--!strict
-- m5-27 콘셉트 견본 (사용자 콘셉트 시트를 따른 연어초밥, 렌더 확인용 — 게임에서는 안 써요):
-- 표정 4종 × 자세 2종이 만들어지고, 파츠 수·겹침·떠 있는 파츠·발바닥이 맞는지, 게임 코드가 견본을 안 쓰는지.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local SushiBody = RobloxRequire.require(Shared.SushiBody)

-- 견본 하나의 파츠 상한: 게임 스킨 상한(40)보다 조금 높아요 — 돔·늘어진 가장자리·팔이 파츠를 더 써요
-- (docs/developer/m5-27-character-concept.md). 게임에 넣을 때 다시 줄여요.
local SAMPLE_BUDGET = 48

local function eachVariant(fn: (string, string) -> ())
	for _, expression in Sample.EXPRESSIONS do
		for _, pose in Sample.POSES do
			fn(expression, pose)
		end
	end
end

return function(t: Test.Test)
	t.test("표정 4종·자세 2종 이름", function()
		t.eq(Sample.EXPRESSIONS, { "Default", "Happy", "Flustered", "Hurt" })
		t.eq(Sample.POSES, { "Stand", "Run" })
	end)

	t.test(
		"모든 조합: 파츠 ≤ 48, 이름 안 겹침, 모양·크기 정상, 깜빡임(z-fighting) 0, 떠 있는 파츠 0",
		function()
			eachVariant(function(expression, pose)
				local layout = Sample.layout(expression, pose)
				local label = `{expression}/{pose}`
				t.ok(#layout <= SAMPLE_BUDGET, `{label} parts {#layout}`)
				t.eq(layout[1].name, "Body", label)
				local seen = {}
				for _, spec in layout do
					t.ok(seen[spec.name] == nil, `{label} duplicate {spec.name}`)
					seen[spec.name] = true
					for axis = 1, 3 do
						t.ok(spec.size[axis] > 0, `{label} {spec.name} size`)
						t.ok(spec.color[axis] >= 0 and spec.color[axis] <= 255, `{label} {spec.name} color`)
					end
					if spec.shape == "Ball" then
						t.ok(spec.size[1] == spec.size[2] and spec.size[2] == spec.size[3], `{label} {spec.name} ball`)
					end
					t.ok(
						spec.shape == nil or spec.shape == "Ball" or spec.shape == "Cylinder",
						`{label} {spec.name} shape {spec.shape}`
					)
				end
				t.eq(LayoutCheck.zFight(layout), {}, `{label} z-fighting`)
				t.eq(LayoutCheck.floating(layout), {}, `{label} floating`)
			end)
		end
	)

	t.test("발바닥 = -GROUND_OFFSET (서기), 달리기에서도 땅 아래로 안 내려가요", function()
		local stand = SushiBody.bounds(Sample.layout("Default", "Stand"))
		t.ok(math.abs(stand.min[2] + Sample.GROUND_OFFSET) < 1e-9, `stand bottom {stand.min[2]}`)
		eachVariant(function(expression, pose)
			local b = SushiBody.bounds(Sample.layout(expression, pose))
			t.ok(b.min[2] >= -Sample.GROUND_OFFSET - 1e-9, `{expression}/{pose} bottom {b.min[2]}`)
		end)
	end)

	t.test(
		"콘셉트 비율: 넓고 낮은 몸, 토핑이 키의 30~42%, 표정이 바뀌어도 몸은 같아요",
		function()
			local layout = Sample.layout()
			local b = SushiBody.bounds(layout)
			local height = b.max[2] - b.min[2]
			local toppingBottom = math.huge
			for _, spec in layout do
				-- 보이는 아래끝 = 늘어진 가장자리 판 (돔 캡슐 아래쪽은 밥 속에 숨어요)
				if string.find(spec.name, "^Topping") then
					toppingBottom = math.min(toppingBottom, SushiBody.bounds({ spec }).min[2])
				end
			end
			local share = (b.max[2] - toppingBottom) / height
			t.ok(share >= 0.3 and share <= 0.42, `topping share {share}`)
			local riceWidth = 0
			for _, spec in layout do
				if spec.name == "BodyWide" then
					riceWidth = spec.size[1]
				end
			end
			t.ok(riceWidth / height >= 0.85, `rice width/height {riceWidth / height}`)
			-- 표정 파츠(얼굴) 말고 몸·토핑·김·팔다리는 표정과 무관
			local base = {}
			for _, spec in Sample.layout("Default") do
				base[spec.name] = spec
			end
			for _, expression in Sample.EXPRESSIONS do
				for _, spec in Sample.layout(expression) do
					local same = base[spec.name]
					if
						same
						and (
							string.find(spec.name, "^Body")
							or string.find(spec.name, "^Topping")
							or string.find(spec.name, "^Nori")
						)
					then
						t.eq(spec.size, same.size, `{expression} {spec.name} size`)
						t.eq(spec.offset, same.offset, `{expression} {spec.name} offset`)
					end
				end
			end
		end
	)

	t.test(
		"build: 진짜 Instance로 만들어지고 Body만 고정, 팔·다리는 Motor6D, 나머지는 용접",
		function()
			local Real = Shims.require(Shims.root("src/shared").SushiConceptSample)
			eachVariant(function(expression, pose)
				local model = Real.build(expression, pose)
				local layout = Sample.layout(expression, pose)
				local parts = model:GetChildren()
				t.eq(#parts, #layout, `{expression}/{pose} part count`)
				t.ok(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Body", "PrimaryPart")
				local motors = 0
				for _, part in parts do
					t.eq(part.Anchored, part.Name == "Body", `{part.Name} anchored`)
					t.eq(part.CanCollide, false, `{part.Name} collide`)
					t.eq(part.Massless, true, `{part.Name} massless`)
					if part.Name ~= "Body" then
						local joints = part:GetChildren()
						t.eq(#joints, 1, `{part.Name} attached once`)
						if joints[1] and joints[1]:IsA("Motor6D") then
							motors += 1
							t.ok(string.find(part.Name, "^Arm") or string.find(part.Name, "^Leg"), part.Name)
						end
					end
				end
				t.eq(motors, 4, `{expression}/{pose} motors`)
			end)
		end
	)

	t.test("견본은 게임에서 안 써요 (렌더 도구만)", function()
		local function scan(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					scan(path)
				elseif string.match(name, "%.luau$") and name ~= "SushiConceptSample.luau" then
					local source = fs.readFile(path)
					t.ok(string.find(source, "SushiConceptSample", 1, true) == nil, `{path} uses the sample`)
				end
			end
		end
		scan("src")
		t.ok(
			string.find(fs.readFile("tools/render-character.luau"), "SushiConceptSample", 1, true) ~= nil,
			"render tool uses it"
		)
	end)
end
