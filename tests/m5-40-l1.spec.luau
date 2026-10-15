--!strict
-- m5-40 길이 늘리기 그룹 L1 (rotating-belt · soy-swamp) — docs/specs/m5-40-map-length-pass.md
-- AC1 길이·구간 단조·추정 시간·새 구간 길 약속, AC2 새 장애물 수치가 기존 범위 안, AC5 예산·소개 카메라 범위.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local BeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)
local BeltLayout = RobloxRequire.require(Shared.maps.RotatingBeltLayout)
local BeltLogic = RobloxRequire.require(Shared.maps.RotatingBeltLogic)
local Chopstick = RobloxRequire.require(Shared.maps.RotatingBeltChopstick)
local SoyArt = RobloxRequire.require(Shared.maps.SoySwampArt)
local SoyLayout = RobloxRequire.require(Shared.maps.SoySwampLayout)
local SoyLogic = RobloxRequire.require(Shared.maps.SoySwampLogic)

local GRAVITY = 196.2
local JUMP_APEX = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
local BODY_R = 1 -- 캐릭터 몸 반폭 (근사)

local function localNumber(path: string, name: string): number
	local value = string.match(fs.readFile(path), `\nlocal {name} = (%-?[%d%.]+)`)
	assert(value, `{name} not found in {path}`)
	return tonumber(value) :: number
end

return function(t: Test.Test)
	---------------------------------------------------------------- 회전 벨트

	t.test(
		"벨트 AC1: 코스 길이(스폰 앞줄 → 결승선)가 400 ± 10%이고 구간이 출발 → 결승으로 단조",
		function()
			local length = BeltLogic.courseLength()
			t.ok(length >= 360 and length <= 440, `length {length}`)
			local sections = BeltArt.SECTIONS
			t.eq(sections[1].front, 0)
			for i, section in sections do
				t.ok(section.front > section.back, `section {i} goes -Z`)
				if i > 1 then
					t.eq(section.front, sections[i - 1].back, `section {i} continues`)
				end
			end
			t.eq(sections[#sections].name, "Finish", "finish stays last")
			t.eq(BeltArt.FINISH_LINE_Z, sections[#sections].back + 4)
			t.eq(BeltLayout.newBack(), sections[#sections].front)
		end
	)

	t.test("벨트 AC1: estimateClearTime 42~55초", function()
		local estimate = BeltLogic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
	end)

	t.test(
		"벨트 AC1: 접시 탑 슬라롬은 몸(반폭 1)이 지나갈 길이 있고, 곧게는 못 지나가요",
		function()
			t.ok(BeltLogic.slalomPath(0.25, BODY_R + 0.25), "slalom route exists (with 0.25 margin)")
			t.ok(BeltLogic.slalomHasNoStraightLane(0.25, BODY_R), "slalom forces weaving")
			for i, tower in BeltLayout.TOWERS do
				local plates = math.floor(tower.h / BeltLayout.PLATE_THICKNESS + 0.5)
				local top = plates * BeltLayout.PLATE_THICKNESS
				t.ok(top >= 12, `tower {i} top {top} reaches the sight box top`)
				t.ok(top > JUMP_APEX + 1, `tower {i} cannot be jumped`)
				local section = BeltLayout.sectionByName("Slalom")
				t.ok(
					tower.z - tower.d / 2 >= 3 and tower.z + tower.d / 2 <= (section :: any).depth - 3,
					`tower {i} inside`
				)
			end
		end
	)

	t.test(
		"벨트 AC1: 옆 벨트는 좌우로 번갈아 밀고, 칸막이 틈은 미는 반대쪽·몸이 지나갈 폭",
		function()
			local section = BeltLayout.sectionByName("SideBelts") :: any
			local total = 0
			for i, belt in BeltLayout.SIDE_BELTS do
				total += belt.depth
				t.ok(belt.push == 1 or belt.push == -1, `belt {i} push`)
				if i > 1 then
					t.ok(belt.push ~= BeltLayout.SIDE_BELTS[i - 1].push, `belt {i} alternates`)
				end
				local solidMin, solidMax = BeltLayout.partitionSolid(i)
				if belt.push > 0 then
					t.eq(solidMax, section.half, "solid part on the push side")
					t.ok(solidMin - -section.half >= 2 * BODY_R + 2, "gap on the far side")
				else
					t.eq(solidMin, -section.half, "solid part on the push side")
					t.ok(section.half - solidMax >= 2 * BODY_R + 2, "gap on the far side")
				end
			end
			t.eq(total, section.depth, "side belts fill the section")
			t.ok(BeltLayout.PARTITION_HEIGHT > JUMP_APEX + 1, "partition cannot be jumped")
		end
	)

	t.test("벨트 AC2: 밀기·젓가락 수치는 기존 범위 안 (벨트 C 대기 2.5~3.5 ⊂ 2.5~4.5)", function()
		t.eq(localNumber("src/shared/maps/RotatingBelt.luau", "PUSH_SPEED"), 10)
		t.eq(localNumber("src/shared/maps/RotatingBelt.luau", "PUSH_ACCEL"), 24)
		t.eq(BeltLayout.BELT_PUSH_SPEED, 10)
		local sticks = BeltLayout.BELT_C_CHOPSTICKS
		local minAll = localNumber("src/shared/maps/RotatingBeltChopstick.luau", "COOLDOWN_MIN")
		local maxAll = localNumber("src/shared/maps/RotatingBeltChopstick.luau", "COOLDOWN_MAX")
		t.ok(sticks.cooldownMin >= minAll and sticks.cooldownMax <= maxAll, "belt C cooldown in range")
		t.ok(sticks.cooldownMax < maxAll, "belt C is the stronger variant")
		local a, b = Chopstick.cooldownRange(1, 9)
		t.eq({ a, b }, { minAll, maxAll }, "cooldownRange clamps to the old range")
		local c, d = Chopstick.cooldownRange(nil, nil)
		t.eq({ c, d }, { minAll, maxAll }, "default range")
		-- 젓가락 3개 영역(깊이 10)이 벨트 C 안에서 겹치지 않아요
		local section = BeltLayout.sectionByName("BeltC") :: any
		t.ok(section.depth / (#sticks.offsets + 1) >= 10, "chopstick zones do not overlap")
		for _, x in sticks.offsets do
			t.ok(math.abs(x) + 4 <= section.half + 1e-6, "zone inside the belt")
		end
	end)

	t.test("벨트 AC1: 옆 벨트 밀기는 PushSide 속성으로, 나머지는 뒤로 (start 소스)", function()
		local source = fs.readFile("src/shared/maps/RotatingBelt.luau")
		t.ok(string.find(source, "origin.RightVector * math.sign(side)", 1, true) ~= nil, "side push")
		t.ok(string.find(source, "zone:SetAttribute(PUSH_SIDE_ATTRIBUTE, pushSide)", 1, true) ~= nil, "attr set")
	end)

	---------------------------------------------------------------- 간장 늪

	t.test("간장 늪 AC1: 코스 길이 400 ± 10%, 구간 단조, estimateClearTime 42~55초", function()
		local length = SoyLogic.courseLength()
		t.ok(length >= 360 and length <= 440, `length {length}`)
		local sections = SoyLogic.sections()
		t.eq(sections[1].span.front, 0)
		for i, s in sections do
			t.ok(s.span.front > s.span.back, `{s.name} goes -Z`)
			if i > 1 then
				t.eq(s.span.front, sections[i - 1].span.back, `{s.name} continues`)
			end
		end
		t.eq(sections[#sections].name, "FINISH")
		local estimate = SoyLogic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
	end)

	t.test(
		"간장 늪 AC1: 김 징검다리 — 둑·발판 사이 틈이 모두 3~4, 발판은 벽 안·강 안",
		function()
			local gaps = SoyLogic.stoneHops()
			t.eq(#gaps, #SoyLayout.STONES + 1)
			for i, gap in gaps do
				t.ok(gap >= 3 - 1e-6 and gap <= 4 + 1e-6, `hop {i} gap {gap}`)
				-- 걷는 속도 점프 한 번(약 8 studs)이면 넘어요
				t.ok(gap < Config.Character.WalkSpeed * (2 * Config.Character.JumpPower / GRAVITY), `hop {i} jumpable`)
			end
			local half = SoyLayout.WIDTH / 2
			for i, s in SoyLayout.STONES do
				t.ok(math.abs(s.x) + s.width / 2 <= half, `stone {i} inside walls`)
				t.ok(
					s.z + s.depth / 2 < SoyLayout.RIVER.front and s.z - s.depth / 2 > SoyLayout.RIVER.back,
					`stone {i}`
				)
			end
			-- 발판 위에 서 있으면 간장 밖, 강바닥에 서 있으면 간장 안
			local plateCenter = SoyLayout.RIVER_BED_Y + 0.1 + SoyLayout.PUDDLE_DEPTH / 2
			t.ok(SoyLayout.SLOPE_HIGH + 3 - plateCenter > SoyLayout.SOY_ZONE_HEIGHT, "on a stone: dry")
			t.ok(SoyLayout.RIVER_BED_Y + 3 - plateCenter <= SoyLayout.SOY_ZONE_HEIGHT, "in the river: soaked")
			-- 강바닥에서 점프가 막혀서(간장) 발판(높이 4)에 다시 못 올라가요 → 경사로로
			t.ok(SoyLayout.SLOPE_HIGH - SoyLayout.RIVER_BED_Y > 2, "stones are taller than a step")
		end
	)

	t.test(
		"간장 늪 AC1: 강에 빠진 사람은 어디서든 걸어서 나오는 경사로에 닿아요 (0.5 격자 BFS)",
		function()
			local ramp = SoyLayout.RIVER_RAMP
			local half = SoyLayout.WIDTH / 2
			local slopeDeg =
				math.deg(math.atan((SoyLayout.SLOPE_HIGH - SoyLayout.RIVER_BED_Y) / (ramp.low - ramp.high)))
			t.ok(slopeDeg < 30, `river ramp slope {slopeDeg}`)
			t.ok(
				ramp.x + ramp.width / 2 <= half and ramp.high == SoyLayout.RIVER.back,
				"ramp in the corner, meets far bank"
			)
			local function blocked(x: number, z: number): boolean
				if math.abs(x) > half - BODY_R then
					return true
				end
				for _, s in SoyLayout.STONES do
					if math.abs(x - s.x) < s.width / 2 + BODY_R and math.abs(z - s.z) < s.depth / 2 + BODY_R then
						return true
					end
				end
				return false
			end
			local step = 0.5
			local front, back = SoyLayout.RIVER.front - BODY_R, SoyLayout.RIVER.back
			local cols = math.floor(2 * half / step)
			local rows = math.floor((front - back) / step)
			local function pos(c: number, r: number): (number, number)
				return -half + c * step, front - r * step
			end
			local function onRamp(x: number, z: number): boolean
				return math.abs(x - ramp.x) <= ramp.width / 2 - BODY_R and z <= ramp.low and z >= ramp.high
			end
			-- 모든 빈 칸에서 경사로까지: 경사로 칸에서 거꾸로 퍼져서 빈 칸을 다 덮는지
			local seen: { [number]: boolean } = {}
			local queue = {}
			for c = 0, cols do
				for r = 0, rows do
					local x, z = pos(c, r)
					if onRamp(x, z) and not blocked(x, z) then
						seen[c * 10000 + r] = true
						table.insert(queue, { c, r })
					end
				end
			end
			t.ok(#queue > 0, "ramp cells exist")
			local head = 1
			while head <= #queue do
				local c, r = queue[head][1], queue[head][2]
				head += 1
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nc, nr = c + d[1], r + d[2]
					local key = nc * 10000 + nr
					if nc >= 0 and nc <= cols and nr >= 0 and nr <= rows and not seen[key] then
						local x, z = pos(nc, nr)
						if not blocked(x, z) then
							seen[key] = true
							table.insert(queue, { nc, nr })
						end
					end
				end
			end
			local stranded = 0
			for c = 0, cols do
				for r = 0, rows do
					local x, z = pos(c, r)
					if not blocked(x, z) and not seen[c * 10000 + r] then
						stranded += 1
					end
				end
			end
			t.eq(stranded, 0, "every river cell reaches the ramp")
			-- 경사로 자리에는 발판이 없어요
			for i, s in SoyLayout.STONES do
				local overlapX = math.abs(s.x - ramp.x) < (s.width + ramp.width) / 2
				local overlapZ = s.z + s.depth / 2 > ramp.high and s.z - s.depth / 2 < ramp.low
				t.ok(not (overlapX and overlapZ), `stone {i} clear of the ramp`)
			end
		end
	)

	t.test(
		"간장 늪 AC1·AC2: 와사비 산 2 — 패드 3개에서 튀면 몸통 위, 느린 길은 경사로 30° 미만 + 간장",
		function()
			local h = SoyLayout.MOUNTAIN2_HEIGHT
			t.eq(h, SoyLayout.MOUNTAIN_HEIGHT, "same height as mountain 1")
			local up = SoyLayout.WASABI_UP
			local tLand = (up + math.sqrt(up * up - 2 * GRAVITY * h)) / GRAVITY
			local body = SoyLayout.MOUNTAIN2_BODY
			local bodyFront, bodyBack = body.z + body.depth / 2, body.z - body.depth / 2
			local bodyLeft, bodyRight = body.x - body.width / 2, body.x + body.width / 2
			t.eq(#SoyLayout.WASABI_PADS_2, 3)
			t.eq(bodyFront, SoyLayout.MOUNTAIN2.front)
			t.eq(bodyRight, SoyLayout.WIDTH / 2, "body on the right (mirrored)")
			for i, pad in SoyLayout.WASABI_PADS_2 do
				t.ok(pad.z + pad.depth / 2 <= SoyLayout.APPROACH2.front, `pad {i} on approach 2`)
				t.ok(pad.z - pad.depth / 2 > SoyLayout.MOUNTAIN2.front, `pad {i} before the cliff`)
				t.ok(
					pad.x - pad.width / 2 >= bodyLeft and pad.x + pad.width / 2 <= bodyRight,
					`pad {i} faces the cliff`
				)
				for _, z in { pad.z + pad.depth / 2, pad.z - pad.depth / 2 } do
					local landZ = z - SoyLayout.WASABI_FORWARD * tLand
					t.ok(landZ < bodyFront and landZ > bodyBack, `pad {i} from {z} lands at {landZ}`)
				end
			end
			-- 패드 튕김 최고점이 옛 벽보다 낮아요 (산 2 앞 평지는 높이 20)
			local highest = SoyLayout.MOUNTAIN2_BASE + up * SoyLayout.WASABI_HOLD + up ^ 2 / (2 * GRAVITY) + 5
			t.ok(highest < SoyLayout.WALL_HEIGHT, `launch {highest} under walls`)
			-- 결승 단(40)에서 점프해도 벽(48)을 못 넘어요
			t.ok(SoyLayout.SLOPE2_HIGH + JUMP_APEX + 1 < SoyLayout.WALL_HEIGHT, "finish floor walls")
			-- 느린 길: 왼쪽 경사로가 몸통 바로 옆, 통로 폭 3 이상, 30° 미만
			local ramp = SoyLayout.RAMP2
			t.eq(ramp.x + ramp.width / 2, bodyLeft)
			t.ok(ramp.x - ramp.width / 2 - -SoyLayout.WIDTH / 2 >= 3, "corridor 3+ wide")
			t.eq(ramp.low, bodyBack)
			t.ok(math.deg(math.atan(h / (ramp.high - ramp.low))) < 30, "ramp 2 slope")
			-- 통로 간장은 통로 안, 경사로 옆 지면 길 위
			local puddle = SoyLayout.CORRIDOR_PUDDLE
			t.ok(puddle.x - puddle.width / 2 >= -SoyLayout.WIDTH / 2, "puddle inside walls")
			t.ok(puddle.x + puddle.width / 2 <= ramp.x - ramp.width / 2, "puddle beside the ramp")
			t.ok(puddle.z - puddle.depth / 2 > SoyLayout.MOUNTAIN2.back, "puddle in mountain 2")
		end
	)

	t.test(
		"간장 늪 AC1·AC2: 날치알 내리막 2 — 결승 쪽이 높고 두 레인 공은 옛 공 규칙 그대로",
		function()
			t.eq(SoyLayout.SLOPE2_LOW, SoyLayout.MOUNTAIN2_BASE + SoyLayout.MOUNTAIN2_HEIGHT)
			t.eq(SoyLayout.slope2HeightAt(SoyLayout.SLOPE2.front), SoyLayout.SLOPE2_LOW)
			t.eq(SoyLayout.slope2HeightAt(SoyLayout.SLOPE2.back), SoyLayout.SLOPE2_HIGH)
			t.ok(
				SoyLayout.SLOPE2_HIGH - SoyLayout.SLOPE2_LOW <= SoyLayout.SLOPE_HIGH - SoyLayout.SLOPE_LOW,
				"not steeper"
			)
			t.eq(#SoyLayout.BALL_LANES_2, 2)
			local r = SoyLayout.BALL_DIAMETER / 2
			for i, lane in SoyLayout.BALL_LANES_2 do
				t.ok(lane.minX < lane.maxX, `lane {i}`)
				t.ok(
					math.abs(lane.minX) + r <= SoyLayout.WIDTH / 2 and math.abs(lane.maxX) + r <= SoyLayout.WIDTH / 2,
					"inside"
				)
			end
			t.ok(SoyLayout.BALL_LANES_2[1].maxX < SoyLayout.BALL_LANES_2[2].minX, "two separate lanes")
			local z = SoyLayout.BALL_SPAWN_Z_2
			t.ok(z < SoyLayout.SLOPE2.front and z > SoyLayout.SLOPE2.back, "spawn on slope 2")
			-- 내리막 2 공은 내리막 2 앞 끝을 지나면 사라지고, 그 위에서는 남아요
			t.ok(not SoyLayout.ballExpired(1, z, 40, SoyLayout.SLOPE2))
			t.ok(SoyLayout.ballExpired(1, SoyLayout.SLOPE2.front + 0.5, 32, SoyLayout.SLOPE2))
			-- 옛 3인자 호출은 내리막 1 그대로
			t.ok(SoyLayout.ballExpired(1, SoyLayout.SLOPE.front + 0.5, 12))
			t.ok(not SoyLayout.ballExpired(1, (SoyLayout.SLOPE.front + SoyLayout.SLOPE.back) / 2, 15))
		end
	)

	t.test("간장 늪 AC2: 옛 구간 수치 그대로 (패드 1개·웅덩이 3개·공 간격·감속)", function()
		t.eq(#SoyLayout.WASABI_PADS, 1)
		t.eq(#SoyLayout.PUDDLES, 3)
		t.eq(SoyLayout.BALL_INTERVAL_MIN, 2)
		t.eq(SoyLayout.BALL_INTERVAL_MAX, 3)
		t.eq(SoyLayout.SOY_SPEED_MULTIPLIER, 0.5)
		t.eq(SoyLayout.WASABI_COOLDOWN, 1)
	end)

	---------------------------------------------------------------- 아트 (AC5)

	t.test("AC5: 두 맵 장식이 Extended 예산 안, 새 와사비 공은 패드 위 0.5 이하", function()
		t.eq(MapKitLogic.checkBudget(BeltArt.decor(), "Extended"), nil, "belt")
		t.eq(MapKitLogic.checkBudget(SoyArt.decor(), "Extended", SoyArt.CODE_EXTRAS), nil, "soy")
		local top = SoyLayout.MOUNTAIN2_BASE + SoyLayout.PAD_THICKNESS
		local n = 0
		for _, spec in SoyArt.decor() do
			if spec.name == "WasabiPadBump" then
				n += 1
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				t.ok(b.max.y <= top + 0.5 + 1e-6 and b.min.y >= SoyLayout.MOUNTAIN2_BASE - 1e-6, "bump on pad")
			end
		end
		t.ok(n > 0, "pad 2 bumps")
	end)

	t.test("AC5: 시야 상자가 새 구간까지 코스 전체를 덮어요", function()
		local minZ = math.huge
		for _, box in BeltArt.courseVolume() do
			minZ = math.min(minZ, box.min.z)
		end
		t.eq(minZ, BeltArt.SECTIONS[#BeltArt.SECTIONS].back)
		minZ = math.huge
		for _, box in SoyArt.courseVolume() do
			minZ = math.min(minZ, box.min.z)
		end
		t.eq(minZ, SoyLayout.FINISH.back)
	end)

	t.test(
		"AC5: 소개 카메라 5점이 코스 상자 + 40 안이고 새 뒷부분을 보는 점이 있어요",
		function()
			local cases = {
				{ id = "rotating-belt", art = BeltArt, back = BeltArt.SECTIONS[#BeltArt.SECTIONS].back, half = 10 },
				{ id = "soy-swamp", art = SoyArt, back = SoyLayout.FINISH.back, half = SoyLayout.WIDTH / 2 },
			}
			for _, c in cases do
				local points = c.art.introCamera()
				t.eq(#points, 5, c.id)
				local seesBack = false
				for i, p in points do
					t.ok(p.pos.z <= 40 and p.pos.z >= c.back - 40, `{c.id} point {i} z`)
					t.ok(math.abs(p.pos.x) <= c.half + 40, `{c.id} point {i} x`)
					t.ok(p.pos.y <= 100, `{c.id} point {i} y`)
					if p.lookAt.z < -200 then
						seesBack = true
					end
				end
				t.ok(seesBack, `{c.id} has a shot of the new back half`)
			end
		end
	)

	t.test("AC5: 배경 바닥이 낙하선(-40)보다 10 이상 아래", function()
		t.ok(BeltArt.FLOOR_Y <= -50, "belt maru floor")
		t.ok(SoyArt.LAKE_Y <= -50, "soy lake")
		for _, spec in BeltArt.decor() do
			if spec.name == "StreetGround" then
				local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
				t.ok(b.max.y <= -50, "street ground below fall line")
				t.ok(math.abs(b.min.x) <= 800 and math.abs(b.max.x) <= 800, "street within 800 of the course")
			end
		end
	end)
end
