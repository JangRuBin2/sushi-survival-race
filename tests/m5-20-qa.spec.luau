--!strict
-- m5-20 QA: 기존 맵 장식 품질 패스 (판정 불변)
--   - 반전 샷이 기존 2·3번째 점 "사이"에 들어갔는지, 반전 샷 앞뒤로 카메라 방향(앞 = -Z)이 뒤집히지 않는지
--   - 소개 카메라 경로가 안개 패널(Glass)을 뚫고 지나가지 않는지 (선분-상자 교차, 샘플링 아님)
--   - 라멘 고명 38개가 급류 양옆(|x| >= 30)·국물 수면 높이·그릇 안에 있고 시야 상자와 안 겹치는지
--   - 태그·클라이언트 애니메이션 코드가 서버 판정에 닿지 않는지 (소스 검사)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapDecorTags = RobloxRequire.require(Shared.maps.MapDecorTags)
local BeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)
local SwampArt = RobloxRequire.require(Shared.maps.SoySwampArt)
local ChefArt = RobloxRequire.require(Shared.maps.ChefBoardArt)
local RamenArt = RobloxRequire.require(Shared.maps.RamenRapidsArt)
local RamenLayout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local HotPlateArt = RobloxRequire.require(Shared.maps.HotPlateArt)

type Vec = { x: number, y: number, z: number }

local function stripComments(source: string): string
	local out = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	out = string.gsub(out, "%-%-[^\n]*", "")
	return out
end

local function overlaps(a: MapKitLogic.Bounds, b: MapKitLogic.Bounds): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

-- 선분 p0→p1이 상자와 만나는지 (slab 방식)
local function segmentHitsBox(p0: Vec, p1: Vec, b: MapKitLogic.Bounds): boolean
	local tmin, tmax = 0, 1
	for _, axis in { "x", "y", "z" } do
		local a0 = (p0 :: any)[axis]
		local d = (p1 :: any)[axis] - a0
		local lo, hi = (b.min :: any)[axis], (b.max :: any)[axis]
		if math.abs(d) < 1e-12 then
			if a0 < lo or a0 > hi then
				return false
			end
		else
			local t1, t2 = (lo - a0) / d, (hi - a0) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin = math.max(tmin, t1)
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return false
			end
		end
	end
	return true
end

local function fogBoxes(decor: { any }, name: string): { MapKitLogic.Bounds }
	local out = {}
	for _, spec in decor do
		if spec.name == name then
			table.insert(out, MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds)
		end
	end
	return out
end

local function lerp(a: Vec, b: Vec, alpha: number): Vec
	return { x = a.x + (b.x - a.x) * alpha, y = a.y + (b.y - a.y) * alpha, z = a.z + (b.z - a.z) * alpha }
end

return function(t: Test.Test)
	t.test(
		"QA AC5: 반전 샷은 기존 2번째와 3번째 점 사이(3번째 자리)에 들어가요 — 순서 유지",
		function()
			local belt = BeltArt.introCamera()
			t.eq(#belt, 5)
			t.eq(belt[2].pos, { x = 0, y = 17, z = -66 })
			t.eq(belt[4].pos, { x = 8, y = 24, z = -112 }) -- m5-40: 결승 샷 → 뒷부분 넓은 샷 (길어진 코스)
			t.ok(belt[3].pos.y > belt[2].pos.y and belt[3].pos.y > belt[4].pos.y, "belt reverse shot is higher")
			t.ok(belt[3].lookAt.y < belt[3].pos.y, "belt reverse shot looks down")
			local swamp = SwampArt.introCamera()
			t.eq(#swamp, 5)
			t.eq(swamp[2].pos, { x = -4, y = 26, z = -50 })
			t.eq(swamp[4].pos, { x = 0, y = 64, z = -150 }) -- m5-40: 결승 샷 → 뒷부분 넓은 샷 (길어진 코스)
			t.ok(swamp[3].lookAt.y < swamp[3].pos.y, "swamp reverse shot looks down")
		end
	)

	t.test(
		"QA AC12: 반전 샷 앞뒤 구간에서 카메라 수평 방향이 계속 앞(-Z)이라 휙 돌지 않아요",
		function()
			for label, points in { belt = BeltArt.introCamera(), swamp = SwampArt.introCamera() } do
				for seg = 2, 3 do
					local a, b = points[seg], points[seg + 1]
					for s = 0, 20 do
						local alpha = s / 20
						local pos = lerp(a.pos, b.pos, alpha)
						local look = lerp(a.lookAt, b.lookAt, alpha)
						local dx, dz = look.x - pos.x, look.z - pos.z
						-- 앞(-Z)이거나 바로 아래(수평 성분 0)만 허용, 뒤(+Z)나 옆으로 크게 돌면 실패
						t.ok(dz <= 1e-9, `{label} seg {seg} alpha {alpha} looks backward (dz {dz})`)
						t.ok(math.abs(dx) <= math.abs(dz) + 1e-9, `{label} seg {seg} alpha {alpha} turns sideways`)
					end
				end
			end
		end
	)

	t.test(
		"QA AC10: 소개 카메라 경로(경유점 사이 직선)가 안개 패널을 뚫지 않아요 (간장 늪·라멘·도마)",
		function()
			local maps = {
				{ id = "soy-swamp", art = SwampArt },
				{ id = "ramen-rapids", art = RamenArt },
				{ id = "chef-board", art = ChefArt },
			}
			for _, m in maps do
				local boxes = fogBoxes(m.art.decor(), m.art.FOG_PANEL)
				t.ok(#boxes >= 3 and #boxes <= 4, `{m.id} fog count {#boxes}`)
				local points = m.art.introCamera()
				for i = 1, #points - 1 do
					for j, box in boxes do
						t.ok(not segmentHitsBox(points[i].pos, points[i + 1].pos, box), `{m.id} seg {i} hits fog #{j}`)
					end
				end
			end
		end
	)

	t.test("QA AC10: 안개 패널은 옅은 Glass(투명도 0.88~0.92), 세 맵 색이 서로 달라요", function()
		local colors = {}
		for id, art in { ["soy-swamp"] = SwampArt, ["ramen-rapids"] = RamenArt, ["chef-board"] = ChefArt } do
			local color = nil
			for _, spec in art.decor() do
				if spec.name == art.FOG_PANEL then
					t.eq(spec.material, "Glass", id)
					t.ok(spec.transparency ~= nil and spec.transparency >= 0.88 and spec.transparency <= 0.92, id)
					color = `{spec.color.r},{spec.color.g},{spec.color.b}`
				end
			end
			t.ok(color ~= nil, `{id} has fog`)
			t.ok(colors[color :: any] == nil, `{id} fog color repeats`)
			colors[color :: any] = true
		end
	end)

	t.test(
		"QA AC3: 라멘 고명 38개는 급류 양옆(|x|>=30)·국물 수면 바로 위·그릇 안, 시야 상자와 안 겹쳐요",
		function()
			local want = { Kombu = 12, SesameSeed = 20, ChopstickRest = 6 }
			local got = { Kombu = 0, SesameSeed = 0, ChopstickRest = 0 }
			local volumes = RamenArt.courseVolumes()
			for _, spec in RamenArt.decor() do
				if want[spec.name] ~= nil then
					got[spec.name] += 1
					local o = spec.offset
					t.ok(math.abs(o.x) >= 30, `{spec.name} x {o.x}`)
					t.ok(o.y > RamenLayout.BROTH_Y and o.y < RamenLayout.BROTH_Y + 1, `{spec.name} y {o.y}`)
					local dz = o.z - RamenArt.BOWL_CENTER_Z
					t.ok(math.sqrt(o.x * o.x + dz * dz) < RamenArt.BOWL_RADIUS - 5, `{spec.name} outside bowl`)
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					for j, volume in volumes do
						t.ok(not overlaps(b, volume), `{spec.name} overlaps course volume #{j}`)
					end
				end
			end
			t.eq(got, want)
			t.eq(MapKitLogic.checkBudget(RamenArt.decor(), "Extended"), nil, "ramen budget") -- m5-24 D2
		end
	)

	t.test(
		"QA AC11: 애니메이션 대상 — 손님 눈 6개(FaceEye)·간장병 3개(SauceBottle), 태그 이름은 MapDecor* 전용",
		function()
			local eyes, bottles = 0, 0
			for _, spec in BeltArt.decor() do
				if spec.name == BeltArt.FACE_EYE then
					eyes += 1
				end
			end
			for _, spec in HotPlateArt.decor() do
				if spec.name == HotPlateArt.SAUCE_BOTTLE then
					bottles += 1
				end
			end
			t.eq(eyes, 6)
			t.eq(bottles, 3)
			t.ok(string.sub(MapDecorTags.EyeBlink, 1, 8) == "MapDecor", "EyeBlink prefix")
			t.ok(string.sub(MapDecorTags.Wobble, 1, 8) == "MapDecor", "Wobble prefix")
			local belt = stripComments(fs.readFile("src/shared/maps/RotatingBelt.luau"))
			local hot = stripComments(fs.readFile("src/shared/maps/HotPlate.luau"))
			t.ok(string.find(belt, "AddTag(part, MapDecorTags.EyeBlink)", 1, true) ~= nil, "belt tags eyes")
			t.ok(string.find(hot, "AddTag(part, MapDecorTags.Wobble)", 1, true) ~= nil, "hot plate tags bottles")
			-- 판정 쪽(Logic·Layout·RoundService 등)은 이 태그를 모르고, 장식 태그를 판정 파츠에 달지 않아요
			for _, path in
				{
					"src/shared/maps/HotPlateLogic.luau",
					"src/shared/maps/RamenRapidsLogic.luau",
					"src/shared/maps/ChefBoardLogic.luau",
					"src/server/RoundService.luau",
				}
			do
				-- m5-23: RoundService는 아레나 모델에 MapDecorTags.Arena(조명 전환용)만 달아요. 애니메이션 태그는 몰라요
				local src = fs.readFile(path)
				t.eq(string.find(src, "MapDecorTags.EyeBlink", 1, true), nil, path)
				t.eq(string.find(src, "MapDecorTags.Wobble", 1, true), nil, path)
			end
		end
	)

	t.test(
		"QA AC11: MapDecorFxController는 로컬 표시만 — 리모트·Size·Destroy 없음, 눈은 Transparency·병은 CFrame만",
		function()
			local src = stripComments(fs.readFile("src/client/fx/MapDecorFxController.luau"))
			for _, banned in { "FireServer", "InvokeServer", "Remotes", ":Destroy(", "CanCollide", "Anchored =" } do
				t.eq(string.find(src, banned, 1, true), nil, banned)
			end
			-- m5-23 Pulse: 크기는 원래 크기 기준으로만 바꿔요 (누적 없음, 클라이언트 로컬)
			for line in string.gmatch(src, "[^\n]+") do
				if string.find(line, ".Size =", 1, true) then
					t.ok(string.find(line, "baseSize", 1, true) ~= nil, "Size only from baseSize: " .. line)
				end
			end
			t.ok(string.find(src, "GetInstanceRemovedSignal", 1, true) ~= nil, "untracks removed parts")
			t.ok(string.find(src, "part.Parent == nil", 1, true) ~= nil, "drops destroyed parts")
			t.ok(string.find(src, "FAR_DISTANCE", 1, true) ~= nil, "distance culling")
			-- 원래 값 기준으로 오프셋만 얹어요 (누적 회전 없음)
			t.ok(string.find(src, "entry.base * CFrame.Angles", 1, true) ~= nil, "wobble from base cframe")
			t.ok(string.find(src, "entry.baseTransparency", 1, true) ~= nil, "blink restores base transparency")
			local init = fs.readFile("src/client/init.client.luau")
			t.ok(string.find(init, "require(script.fx.MapDecorFxController)", 1, true) ~= nil, "registered")
		end
	)

	t.test("QA AC8: 새 조명·파티클 수치는 은은하게 (스펙 기본값)", function()
		local belt = fs.readFile("src/shared/maps/RotatingBelt.luau")
		local swamp = fs.readFile("src/shared/maps/SoySwamp.luau")
		local chef = fs.readFile("src/shared/maps/ChefBoard.luau")
		t.ok(string.find(belt, "light.Range = 25", 1, true) ~= nil, "lantern range")
		t.ok(string.find(belt, "glint.Rate = 1.5", 1, true) ~= nil, "glint rate")
		t.ok(string.find(swamp, "light.Range = 20", 1, true) ~= nil, "hill range")
		t.ok(string.find(swamp, "bubble.Rate = 1", 1, true) ~= nil, "bubble rate")
		t.ok(string.find(chef, "if isCenter then 30 else 18", 1, true) ~= nil, "lamp ranges")
		t.ok(string.find(chef, "spark.Rate = 0", 1, true) ~= nil, "spark not continuous")
		t.ok(string.find(chef, "spark.Enabled = false", 1, true) ~= nil, "spark disabled")
	end)
end
