--!strict
-- m5-25 QA: 캐릭터 퀄리티 2단계를 개발 테스트와 별개로 확인해요.
--   build 구조(31종, 가짜 Roblox 환경으로 진짜 소스 실행), 이름표·탈의실 카메라 여유, 클라이언트 연출이
--   Transform만 바꾸는지(크기·복제 없음), 움직임 곡선 연속성, LayoutCheck의 새 규칙(원기둥 마개·같은 겉모습).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Skins = RobloxRequire.require(Shared.Skins)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)

local SUSHI_SOURCE = fs.readFile("src/shared/SushiBody.luau")
local FX_SOURCE = fs.readFile("src/client/fx/CharacterFxController.luau")

---------------------------------------------------------------- 가짜 Roblox (build 구조만 보면 돼요)
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

local function value(kind: string): any
	return {
		new = function(...)
			return { __kind = kind, args = { ... } }
		end,
	}
end

local CF_MT = {}
CF_MT.__mul = function(a: any, b: any): any
	return setmetatable({ __kind = "Product", args = { a, b } }, CF_MT)
end

local function newInstance(className: string): any
	local inst: any = { ClassName = className, Name = className, _children = {}, _parent = nil }
	return setmetatable(inst, {
		__index = function(self, key)
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
		end,
		__newindex = function(self, key, v)
			if key == "Parent" then
				rawset(self, "_parent", v)
				if v then
					table.insert(v._children, self)
				end
				return
			end
			rawset(self, key, v)
		end,
	})
end

local function loadFakeSushiBody(): any
	local identity = setmetatable({ __kind = "Identity" }, CF_MT)
	local chunk = luau.load(SUSHI_SOURCE, {
		debugName = "SushiBody(m5-25 qa fake)",
		environment = {
			-- SushiBody의 유일한 require = 순수 SushiConceptSample (m5-27 실험 스킨)
			script = { Parent = { SushiConceptSample = "SushiConceptSample" } },
			require = function(target: any): any
				assert(target == "SushiConceptSample", `unexpected require {tostring(target)}`)
				return RobloxRequire.require(Shared.SushiConceptSample)
			end,
			Instance = { new = newInstance },
			Vector3 = value("Vector3"),
			Vector2 = value("Vector2"),
			Color3 = {
				fromRGB = function(r, g, b)
					return { R = r, G = g, B = b }
				end,
			},
			CFrame = {
				identity = identity,
				new = function(...)
					return setmetatable({ __kind = "CFrame", args = { ... } }, CF_MT)
				end,
				Angles = function(...)
					return setmetatable({ __kind = "Angles", args = { ... } }, CF_MT)
				end,
			},
			ColorSequence = value("ColorSequence"),
			NumberSequence = value("NumberSequence"),
			NumberRange = value("NumberRange"),
			Enum = proxyEnum(""),
		},
	})
	return chunk()
end

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

return function(t: Test.Test)
	t.test(
		"QA build: 31종 모두 Motor6D(PartJoint) 정확히 6개(Part0 = Body), 나머지는 붙을 파츠에 용접 하나씩",
		function()
			local Fake = loadFakeSushiBody()
			for _, skin in Skins.LIST do
				local model = Fake.build(skin.id)
				local specs = byName(SushiBody.layout(skin.id))
				local parts: { [string]: any } = {}
				for _, c in model:GetChildren() do
					parts[c.Name] = c
				end
				local body = parts.Body
				t.ok(model.PrimaryPart == body, `{skin.id} PrimaryPart`)
				local motors = 0
				for name, part in parts do
					if part == body then
						continue
					end
					local joints, welds = 0, 0
					for _, c in part._children do
						if c.ClassName == "Motor6D" then
							joints += 1
							motors += 1
							t.eq(c.Name, SushiBody.PART_JOINT_NAME, `{skin.id} {name} motor name`)
							t.ok(c.Part0 == body and c.Part1 == part, `{skin.id} {name} motor parts`)
							t.ok(c.C0 == part.CFrame, `{skin.id} {name} C0 = 자리`)
						elseif c.ClassName == "WeldConstraint" then
							welds += 1
							local anchor = if specs[name].attach then parts[specs[name].attach] else body
							t.ok(c.Part0 == anchor and c.Part1 == part, `{skin.id} {name} weld parts`)
						end
					end
					t.eq(joints + welds, 1, `{skin.id} {name} attached exactly once`)
					t.eq(part.Anchored, false, `{skin.id} {name} not anchored`)
					-- 눈 속 파츠(attach)만 그림자를 안 드리워요
					t.eq(part.CastShadow, specs[name].attach == nil, `{skin.id} {name} CastShadow`)
				end
				-- 실험 스킨 concept-salmon(m5-27)은 팔 2개가 더 있어요 (눈 2·감은 눈 2·발 2·팔 2)
				t.eq(motors, if skin.experimental then 8 else 6, `{skin.id} motors`)
			end
		end
	)

	t.test(
		"QA 이름표: 31종 모두 꼭대기가 이름표 높이보다 0.4 이상 아래 (모자·뿔·왕관 포함)",
		function()
			for _, skin in Skins.LIST do
				local b = SushiBody.bounds(SushiBody.layout(skin.id))
				t.ok(b.max[2] <= SushiBody.NAME_TAG_HEIGHT - 0.4, `{skin.id} top {b.max[2]}`)
			end
		end
	)

	t.test(
		"QA 탈의실: 미리보기 카메라(z −10, 시야 40°, y 0.1을 봄)에 31종 높이가 다 들어와요",
		function()
			-- ShopScreen.luau: CFrame.lookAt((0, 1.2, -10), (0, 0.1, 0)), FieldOfView 40. 모델 원점 = Body 중심.
			local shop = fs.readFile("src/client/ui/ShopScreen.luau")
			t.ok(string.find(shop, "camera.FieldOfView = 40", 1, true) ~= nil, "shop fov still 40")
			t.ok(string.find(shop, "Vector3.new(0, 1.2, -10), Vector3.new(0, 0.1, 0)", 1, true) ~= nil, "shop camera")
			local pitch = math.atan2(1.1, 10) -- 아래로 기울어진 각
			for _, skin in Skins.LIST do
				local b = SushiBody.bounds(SushiBody.layout(skin.id))
				local radius = math.max(math.abs(b.min[1]), math.abs(b.max[1]), math.abs(b.min[3]), math.abs(b.max[3]))
				for _, y in { b.min[2], b.max[2] } do
					-- 가장 카메라 쪽으로 온 점(회전 중 z = −radius)이 가장 크게 보여요
					local dz = 10 - radius
					local angle = math.atan2(y - 1.2, dz) + pitch
					t.ok(math.abs(math.deg(angle)) < 20, `{skin.id} y {y} angle {math.deg(angle)}`)
				end
			end
		end
	)

	t.test(
		"QA 연출: CharacterFxController는 Transform만 바꾸고 파츠 크기·위치·용접은 안 건드려요",
		function()
			-- GUI(이름표·@_@)의 UDim2 크기는 괜찮고, 파츠 크기(Vector3)는 안 바꿔요
			t.eq(string.find(FX_SOURCE, "Size = Vector3", 1, true), nil, "no part size change")
			t.eq(string.find(FX_SOURCE, ":ScaleTo(", 1, true), nil, "no model scale")
			t.eq(string.find(FX_SOURCE, ".CFrame =", 1, true), nil, "no CFrame write")
			t.eq(string.find(FX_SOURCE, ".C0 =", 1, true), nil, "no C0 write")
			t.eq(string.find(FX_SOURCE, 'Instance.new("Motor6D")', 1, true), nil, "no new joints")
			t.ok(
				string.find(FX_SOURCE, "SushiBody.PART_JOINT_NAME", 1, true) ~= nil,
				"finds part joints by shared name"
			)
			t.ok(string.find(FX_SOURCE, "SushiBody.NAME_TAG_HEIGHT", 1, true) ~= nil, "name tag height shared")
			t.ok(string.find(FX_SOURCE, "CharacterAnimLogic.DETAIL_DISTANCE", 1, true) ~= nil, "distance LOD")
			-- 숨긴 캐릭터(탈락 연출·1인칭)는 관절을 기본 자세로 돌려요
			local _, resets = string.gsub(FX_SOURCE, "resetJoints%(state%.joints%)", "")
			t.ok(resets >= 2, `resetJoints on hidden paths ({resets})`)
		end
	)

	t.test(
		"QA 움직임: 찌그러짐·숨쉬기·걸음 곡선이 끊기지 않아요 (1ms 간격 변화 < 0.02)",
		function()
			local prev = Anim.squash(0, 1)
			for i = 1, 300 do
				local v = Anim.squash(i / 1000, 1)
				t.ok(math.abs(v - prev) < 0.02, `squash jump at {i}ms`)
				prev = v
			end
			local function poseAt(phase: number): any
				return Anim.pose({
					time = phase,
					idle = 0.5,
					walk = 1,
					phase = phase,
					bounce = math.abs(math.sin(phase)) * 0.3,
					blinking = false,
					knocked = false,
					riseSpeed = 0,
					landTime = nil,
					landStrength = 0,
				})
			end
			local last = poseAt(0)
			for i = 1, 2000 do
				local p = poseAt(i * 0.005)
				t.ok(math.abs(p.bodyY - last.bodyY) < 0.02, "body smooth")
				t.ok(math.abs(p.footLeft.y - last.footLeft.y) < 0.02, `left foot smooth at {i}`)
				t.ok(math.abs(p.footRight.z - last.footRight.z) < 0.02, `right foot smooth at {i}`)
				last = p
			end
		end
	)

	t.test("QA 움직임: 깜빡임 간격은 난수 전 구간에서 2.2~5.0, 단조 증가", function()
		local prev = -1
		for i = 0, 100 do
			local d = Anim.nextBlinkDelay(i / 100)
			t.ok(d >= Anim.BLINK_MIN and d <= Anim.BLINK_MAX, `delay {d}`)
			t.ok(d >= prev, "monotonic")
			prev = d
		end
	end)

	t.test("QA LayoutCheck: 원기둥 마개도 깜빡임을 찾고, 색·재질이 같은 쌍은 빼요", function()
		local function spec(name: string, extra: { [string]: any }): any
			local s: { [string]: any } = {
				name = name,
				size = { 1, 1, 1 },
				offset = { 0, 0, 0 },
				color = { 10, 10, 10 },
				material = "SmoothPlastic",
			}
			for k, v in extra do
				s[k] = v
			end
			return s
		end
		-- 세운 원기둥(축 Y) 윗면 y = 0.5와 상자 윗면 y = 0.5, 색이 다르면 깜빡임
		local cyl =
			spec("Cyl", { shape = "Cylinder", size = { 1, 2, 2 }, rotation = { 0, 0, 90 }, color = { 200, 0, 0 } })
		local box = spec("Box", { size = { 1, 1, 1 } })
		t.eq(LayoutCheck.zFight({ cyl, box }), { "Cyl/Box +Y", "Cyl/Box -Y" })
		-- 같은 겉모습이면 안 보여요
		local same = spec("Same", { size = { 1, 1, 1 }, color = { 200, 0, 0 } })
		t.eq(LayoutCheck.zFight({ cyl, same }), {})
		-- 원기둥 옆면(곡면)은 평평하지 않아서 X·Z로는 찾지 않아요
		local side = spec("Side", { size = { 2, 0.2, 0.2 }, offset = { 0, 0, 0.9 } })
		local found = LayoutCheck.zFight({ cyl, side })
		for _, f in found do
			t.ok(not string.find(f, "Z"), f)
		end
	end)

	t.test(
		"QA 공정성: 히트박스 쪽 코드(AppearanceService)는 GROUND_OFFSET 하나로 발바닥을 맞춰요",
		function()
			local source = fs.readFile("src/server/AppearanceService.luau")
			t.ok(string.find(source, "SushiBody.GROUND_OFFSET", 1, true) ~= nil, "uses GROUND_OFFSET")
			local b = SushiBody.bounds(SushiBody.layout("tamago"))
			t.ok(math.abs(-b.min[2] - SushiBody.GROUND_OFFSET) < 1e-9, "feet at -GROUND_OFFSET")
			-- 31종 모두 발바닥이 같아요 (어떤 장식도 발보다 아래로 안 내려가요)
			for _, skin in Skins.LIST do
				local sb = SushiBody.bounds(SushiBody.layout(skin.id))
				t.ok(math.abs(sb.min[2] - b.min[2]) < 1e-9, `{skin.id} bottom {sb.min[2]}`)
			end
		end
	)
end
