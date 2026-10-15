--!strict
-- m5-36 Survival 맵 "초대형 밥솥"(rice-cooker): 인터페이스·스폰, 5단 밥 언덕(판정 조각), 끓어오름 일정·곳 고르기·넉백,
-- 증기 일정·띠·넉백, 타이머 글자, 장식 예산·가독성 (순수 로직 + 렌더러 Shims로 build)

local Batch3 = require("./lib/Batch3")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.RiceCookerLayout)
local Logic = RobloxRequire.require(Shared.maps.RiceCookerLogic)
local Art = RobloxRequire.require(Shared.maps.RiceCookerArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local EPS = 1e-6
local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z

local function near(a: number, b: number, tol: number?): boolean
	return math.abs(a - b) <= (tol or 1e-6)
end

-- Roblox Random처럼 NextInteger·NextNumber (결정적)
local function fakeRng(seed: number)
	local state = (seed * 7919 + 104729) % 2147483647
	if state == 0 then
		state = 1
	end
	local function step(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	for _ = 1, 4 do
		step()
	end
	return {
		NextInteger = function(_, min: number, max: number): number
			return min + math.floor(step() * (max - min + 1)) % (max - min + 1)
		end,
		NextNumber = function(_): number
			return step()
		end,
	}
end

local built: any = nil
local function model(): any
	if built == nil then
		built = RMaps.get("rice-cooker").build(roblox.CFrame.new())
	end
	return built
end

local function inFolder(part: any, folderName: string): boolean
	local p = part.Parent
	while p do
		if p.Name == folderName then
			return true
		end
		p = p.Parent
	end
	return false
end

-- CFrame.Angles(rx, ry, rz)와 같은 회전 (R = Rx · Ry · Rz)
local function rotate(x: number, y: number, z: number, r: any): (number, number, number)
	if r == nil then
		return x, y, z
	end
	local cz, sz = math.cos(math.rad(r.z)), math.sin(math.rad(r.z))
	x, y = x * cz - y * sz, x * sz + y * cz
	local cy, sy = math.cos(math.rad(r.y)), math.sin(math.rad(r.y))
	x, z = x * cy + z * sy, -x * sy + z * cy
	local cx, sx = math.cos(math.rad(r.x)), math.sin(math.rad(r.x))
	y, z = y * cx - z * sx, y * sx + z * cx
	return x, y, z
end

-- 장식 하나의 상자에서 27점 (꼭짓점·모서리 가운데·면 가운데·중심)
local function samples(spec: any): { { number } }
	local out = {}
	for _, a in { -1, 0, 1 } do
		for _, b in { -1, 0, 1 } do
			for _, d in { -1, 0, 1 } do
				local x, y, z = rotate(a * spec.size.x / 2, b * spec.size.y / 2, d * spec.size.z / 2, spec.rotation)
				table.insert(out, { spec.offset.x + x, spec.offset.y + y, spec.offset.z + z })
			end
		end
	end
	return out
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: rice-cooker는 인터페이스를 지키는 Survival 맵이고 랜덤 풀에 들어가요", function()
		local map = Maps.get("rice-cooker")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "초대형 밥솥")
		t.eq(map.rule, "끓어오르는 밥알과 뜨거운 증기를 피해 밥 위에서 버텨요!")
		t.ok(map.inPool ~= false, "inPool = false 줄이 지워졌어야 해요")
		t.ok(map.lighting == Art.LIGHTING, "lighting = Art.LIGHTING")
		local pooled = false
		for _, info in Maps.infos() do
			if info.id == "rice-cooker" then
				pooled = true
			end
		end
		t.ok(pooled, "random pool has rice-cooker")
		t.eq(#Maps.infos(), Batch3.expectedPoolCount(Maps.get))
		t.eq(type(map.start), "function")
		t.eq(map.overtime, nil) -- Survival은 연장전 훅이 없어요
	end)

	t.test("AC1: 스폰 24개가 반지름 12~28(2·3단) 바닥 위, 서로 3 이상", function()
		local spawns = Layout.spawnOffsets()
		t.eq(#spawns, 24)
		for i, s in spawns do
			local r = Layout.radiusOf(s.x, s.z)
			t.ok(r >= 12 + 1 and r <= 28 - 1, `spawn {i} radius {r}`)
			local tier = Layout.tierAt(r)
			t.ok(tier == 2 or tier == 3, `spawn {i} tier {tier}`)
		end
		for a = 1, #spawns do
			for b = a + 1, #spawns do
				local dx, dz = spawns[a].x - spawns[b].x, spawns[a].z - spawns[b].z
				t.ok(math.sqrt(dx * dx + dz * dz) >= 3 - EPS, `spawn {a} and {b} too close`)
			end
		end
		-- build한 Spawns 파츠는 그 단 윗면 + 0.1, 아래에 판정 조각이 있어요
		local m = model()
		local list = m:FindFirstChild("Spawns"):GetChildren()
		t.eq(#list, 24)
		for _, s in list do
			local p = s.CFrame.Position
			local top = Layout.surfaceAtXZ(p.X, p.Z)
			t.ok(top ~= nil and near(p.Y, top + 0.1, 1e-3), `{s.Name} height`)
			local supported = false
			for _, seg in Layout.segments() do
				if seg.topY == top and Layout.onSegment(seg, p.X, p.Z) then
					supported = true
				end
			end
			t.ok(supported, `{s.Name} over a floor segment`)
		end
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: 단 5개의 반지름·윗면이 스펙 표와 같고 이웃 단 높이 차 1", function()
		t.eq(#Layout.TIERS, 5)
		local expected = { { 0, 12, 4 }, { 12, 20, 3 }, { 20, 28, 2 }, { 28, 34, 1 }, { 34, 40, 0 } }
		for i, row in expected do
			local tier = Layout.TIERS[i]
			t.eq(tier.inner, row[1])
			t.eq(tier.outer, row[2])
			t.eq(tier.top, row[3])
			if i > 1 then
				t.ok(near(Layout.TIERS[i - 1].top - tier.top, 1, 0.01), `step {i - 1}→{i}`)
			end
		end
		t.eq(Layout.HILL_RADIUS, 40)
		t.eq(Layout.surfaceAt(0), 4)
		t.eq(Layout.surfaceAt(12.5), 3)
		t.eq(Layout.surfaceAt(39.9), 0)
		t.eq(Layout.surfaceAt(40.1), nil)
	end)

	t.test(
		"AC2: 판정 조각이 단 표대로 언덕을 덮어요 (경계 ±0.2 밖 표본, 가장 높은 조각 = 그 단)",
		function()
			local segs = Layout.segments()
			local count = 0
			for _, n in Layout.SEGMENTS do
				count += n
			end
			t.eq(#segs, count)
			for ri = 0, 79 do
				local r = ri * 0.5 + 0.05
				local boundary = false
				for _, tier in Layout.TIERS do
					if math.abs(r - tier.outer) < 0.2 then
						boundary = true
					end
				end
				if boundary then
					continue
				end
				for ai = 0, 23 do
					local a = math.rad(ai * 15 + 3.7)
					local x, z = CX + r * math.cos(a), CZ - r * math.sin(a)
					local best: number? = nil
					for _, seg in segs do
						if Layout.onSegment(seg, x, z) and (best == nil or seg.topY > best) then
							best = seg.topY
						end
					end
					t.eq(best, Layout.surfaceAt(r), `r {r} angle {ai * 15}`)
				end
			end
		end
	)

	t.test(
		"AC2: 반지름 40 밖에는 충돌 있는 파츠가 없어요 (솥·림·주걱·밸브·타이머는 CanCollide false)",
		function()
			local m = model()
			local floorCount = 0
			for _, d in m:GetDescendants() do
				if not d:IsA("BasePart") then
					continue
				end
				if inFolder(d, "Decor") then
					t.eq(d.CanCollide, false, `decor {d.Name}`)
					continue
				end
				if not d.CanCollide then
					continue
				end
				t.ok(inFolder(d, "RiceHill"), `only rice hill collides ({d.Name})`)
				floorCount += 1
				local half = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local p =
								d.CFrame:PointToWorldSpace(roblox.Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
							local r = Layout.radiusOf(p.X, p.Z)
							t.ok(r <= Layout.HILL_RADIUS + 1e-3, `{d.Name} corner at radius {r}`)
							t.ok(p.Y <= 4 + 1e-3 and p.Y >= Layout.BASE_Y - 1e-3, `{d.Name} corner height {p.Y}`)
						end
					end
				end
			end
			t.eq(floorCount, #Layout.segments())
			for _, name in { "SteamVents", "CookerTimer" } do
				t.ok(m:FindFirstChild(name) ~= nil, name)
			end
		end
	)

	---------------------------------------------------------------- AC3
	t.test("AC3: timeLimit 75, burstWave 4.9 nil · 5 (7,1) · 20 (5.5,2) · 40 (4.5,3) · 60 (3.5,3)", function()
		local map = Maps.get("rice-cooker")
		t.eq(map.timeLimit, 75)
		t.eq(Maps.timeLimit(map), 75)
		t.eq(Config.TimeLimit.Survival, 60) -- 공용 기본은 그대로 (스펙 D5)
		t.eq(Logic.burstWave(0), nil)
		t.eq(Logic.burstWave(4.9), nil)
		t.eq(Logic.burstWave(5), { interval = 7, count = 1 })
		t.eq(Logic.burstWave(19.9), { interval = 7, count = 1 })
		t.eq(Logic.burstWave(20), { interval = 5.5, count = 2 })
		t.eq(Logic.burstWave(40), { interval = 4.5, count = 3 })
		t.eq(Logic.burstWave(60), { interval = 3.5, count = 3 })
		t.eq(Logic.burstWave(75), { interval = 3.5, count = 3 })
	end)

	t.test(
		"AC3: pickBurstSpots 1,000번 — 약 60%(±7%)가 레이서 발밑 ± 2, 모두 반지름 36 안",
		function()
			local racers = { { x = 10, z = 5 }, { x = -20, z = 12 }, { x = 6, z = -25 } }
			local onRacer, total = 0, 0
			for seed = 1, 1000 do
				local spots = Logic.pickBurstSpots(fakeRng(seed), racers, 1)
				t.eq(#spots, 1)
				for _, spot in spots do
					total += 1
					t.ok(math.sqrt(spot.x * spot.x + spot.z * spot.z) <= 36 + EPS, "inside radius 36")
					for _, racer in racers do
						local dx, dz = spot.x - racer.x, spot.z - racer.z
						if math.sqrt(dx * dx + dz * dz) <= 2 + EPS then
							onRacer += 1
							break
						end
					end
				end
			end
			local ratio = onRacer / total
			t.ok(ratio >= 0.53 and ratio <= 0.67, `on-racer ratio {ratio}`)
		end
	)

	t.test(
		"AC3: 같은 차례 곳끼리 12 이상, 가장자리 레이서도 반지름 36 안으로 당겨요",
		function()
			local racers = { { x = 38, z = 0 }, { x = 0, z = 0 }, { x = 1, z = 1 }, { x = -30, z = -10 } }
			for seed = 1, 1000 do
				local spots = Logic.pickBurstSpots(fakeRng(seed), racers, 3)
				t.ok(#spots >= 1 and #spots <= 3, `seed {seed}: {#spots} spots`)
				for i, a in spots do
					t.ok(math.sqrt(a.x * a.x + a.z * a.z) <= 36 + EPS, "inside radius 36")
					for j = i + 1, #spots do
						local b = spots[j]
						local dx, dz = a.x - b.x, a.z - b.z
						t.ok(math.sqrt(dx * dx + dz * dz) >= 12 - EPS, `seed {seed}: spots {i},{j} overlap`)
					end
				end
			end
			-- 레이서가 없으면 전부 무작위
			local spots = Logic.pickBurstSpots(fakeRng(7), {}, 2)
			t.ok(#spots >= 1, "random spots without racers")
			for _, s in spots do
				t.eq(s.targeted, false)
			end
		end
	)

	---------------------------------------------------------------- AC4
	t.test(
		"AC4: burstKnockback — 원 안이면 위 45 + 바깥 22, 원 밖 nil, 중심이면 무작위 수평 22",
		function()
			local v = Logic.burstKnockback(3, 4, fakeRng(1))
			t.ok(v ~= nil, "inside")
			if v then
				t.ok(near(v.x, 13.2) and near(v.z, 17.6), `direction {v.x}, {v.z}`)
				t.eq(v.y, 45)
			end
			local edge = Logic.burstKnockback(0, -6, fakeRng(1))
			t.ok(edge ~= nil and near(edge.z, -22) and near(edge.x, 0), "edge pushes outward")
			t.eq(Logic.burstKnockback(6.01, 0, fakeRng(1)), nil)
			t.eq(Logic.burstKnockback(4.5, 4.5, fakeRng(1)), nil)
			local directions: { [string]: boolean } = {}
			for seed = 1, 40 do
				local c = Logic.burstKnockback(0, 0, fakeRng(seed))
				t.ok(c ~= nil, "centre knocks")
				if c then
					t.ok(near(math.sqrt(c.x * c.x + c.z * c.z), 22, 1e-6), "centre horizontal 22")
					t.eq(c.y, 45)
					directions[`{c.x > 0}{c.z > 0}`] = true
				end
			end
			local quadrants = 0
			for _ in directions do
				quadrants += 1
			end
			t.ok(quadrants >= 3, `random centre direction ({quadrants} quadrants)`)
		end
	)

	---------------------------------------------------------------- AC5
	t.test("AC5: steamSchedule/steamTimes — 11.9 없음, 12·24 1개, 36·44·52 2개, 60·66·72 2개", function()
		t.eq(Logic.steamSchedule(11.9), nil)
		t.eq(Logic.steamSchedule(12), { interval = 12, count = 1 })
		t.eq(Logic.steamSchedule(24), { interval = 12, count = 1 })
		t.eq(Logic.steamSchedule(36), { interval = 8, count = 2 })
		t.eq(Logic.steamSchedule(60), { interval = 6, count = 2 })
		t.eq(Logic.steamTimes(75), { 12, 24, 36, 44, 52, 60, 66, 72 })
		t.eq(Logic.steamBands(11.9, fakeRng(1), {}), {})
	end)

	t.test(
		"AC5: steamBands — 바로 전과 다른 띠, 2개면 서로 다른 띠·양쪽 밸브, 한 띠는 늘 비어요",
		function()
			for seed = 1, 300 do
				local rng = fakeRng(seed)
				local last: { number } = {}
				for _, at in Logic.steamTimes(75) do
					local jets = Logic.steamBands(at, rng, last)
					local wave = Logic.steamSchedule(at)
					t.eq(#jets, wave.count, `seed {seed} t {at}`)
					local seen: { [number]: boolean } = {}
					local fresh = false
					for _, jet in jets do
						t.ok(jet.band >= 1 and jet.band <= 3, "band index")
						t.ok(jet.side == 1 or jet.side == -1, "side")
						t.ok(not seen[jet.band], `seed {seed} t {at}: same band twice`)
						seen[jet.band] = true
						if not table.find(last, jet.band) then
							fresh = true
						end
					end
					t.ok(fresh, `seed {seed} t {at}: no new band`)
					if #jets == 1 then
						t.ok(#last == 0 or not table.find(last, jets[1].band), `seed {seed} t {at}: repeats last band`)
					else
						t.ok(jets[1].side ~= jets[2].side, `seed {seed} t {at}: both valves`)
					end
					local empty = 0
					for band = 1, 3 do
						if not seen[band] then
							empty += 1
						end
					end
					t.ok(empty >= 1, "one band always empty")
					last = {}
					for _, jet in jets do
						table.insert(last, jet.band)
					end
				end
			end
		end
	)

	t.test("AC5: inBand — 가운데 띠 |z| ≤ 5, 옆 띠 −14·+14", function()
		t.eq(Logic.inBand(5, 2), true)
		t.eq(Logic.inBand(-5, 2), true)
		t.eq(Logic.inBand(5.1, 2), false)
		t.eq(Logic.inBand(-14, 1), true)
		t.eq(Logic.inBand(-9, 1), true)
		t.eq(Logic.inBand(-8.9, 1), false)
		t.eq(Logic.inBand(19, 3), true)
		t.eq(Logic.inBand(0, 3), false)
		t.eq(Logic.inBand(0, 4), false)
		t.eq(Layout.BANDS, { -14, 0, 14 })
		-- 띠 사이 빈칸 (|z| 5~9)은 어느 띠에도 안 들어요
		for _, z in { 6, 7, 8.9, -6, -8.9 } do
			for band = 1, 3 do
				t.eq(Logic.inBand(z, band), false, `z {z} band {band}`)
			end
		end
	end)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: 넉백 상수 — 증기 34·10·면제 1.2, 터짐 45·22·면제 1.5, 쿨다운 0.6, 증기 높이 8 > 점프",
		function()
			t.eq(Logic.STEAM_PUSH, 34)
			t.eq(Logic.STEAM_UP, 10)
			t.eq(Logic.STEAM_MOVE_EXEMPT, 1.2)
			t.eq(Logic.STEAM_KNOCKDOWN_TIME, 0.6)
			t.eq(Logic.STEAM_WARN_TIME, 2)
			t.eq(Logic.STEAM_BLAST_TIME, 1.2)
			t.eq(Logic.BURST_UP, 45)
			t.eq(Logic.BURST_OUT, 22)
			t.eq(Logic.BURST_MOVE_EXEMPT, 1.5)
			t.eq(Logic.BURST_KNOCKDOWN_TIME, 0.8)
			t.eq(Logic.BURST_COOLDOWN, 0.6)
			t.eq(Logic.BURST_WARN_TIME, 1.5)
			t.eq(Logic.BURST_RADIUS, 6)
			t.eq(Logic.BURST_HEIGHT_RANGE, 5)
			local jumpHeight = Config.Character.JumpPower ^ 2 / (2 * 196.2)
			t.ok(jumpHeight > 6 and jumpHeight < 7, `jump height {jumpHeight}`)
			t.ok(Logic.STEAM_HEIGHT_RANGE > jumpHeight, "steam can't be jumped over")
			local push = Logic.steamKnockback(1)
			t.eq(push, { x = -34, y = 10, z = 0 })
			t.eq(Logic.steamKnockback(-1), { x = 34, y = 10, z = 0 })
		end
	)

	---------------------------------------------------------------- AC7
	t.test("AC7: formatTimer — 45 → 00:45, 75 → 01:15, 0 → 00:00, 음수 → 00:00", function()
		t.eq(Logic.formatTimer(45), "00:45")
		t.eq(Logic.formatTimer(75), "01:15")
		t.eq(Logic.formatTimer(0), "00:00")
		t.eq(Logic.formatTimer(-3), "00:00")
		t.eq(Logic.formatTimer(44.2), "00:45") -- 남은 시간은 올림
		t.eq(Logic.formatTimer(600), "10:00")
		-- build한 타이머 글자는 시작 값 01:15
		local display = model():FindFirstChild("CookerTimer")
		t.ok(display ~= nil, "CookerTimer")
		local label = display and display:FindFirstChild("Time", true)
		t.ok(label ~= nil and label.Text == "01:15", "timer starts at 01:15")
		t.eq(display.CanCollide, false)
	end)

	---------------------------------------------------------------- AC8
	t.test(
		"AC8: 장식 validate·Extended 예산, 파티클 2개 이상·움직임 3개 이상·그림자 조명 ≤ 2",
		function()
			local decor = Art.decor()
			t.eq(Art.BUDGET, "Extended")
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(MapKitLogic.checkBudget(decor, "Extended"), nil)
			t.ok(#decor >= 700 and #decor <= 1500, `decor parts {#decor}`)
			t.ok(MapKitLogic.countParticles(decor) >= 2, "particles")
			t.ok(MapKitLogic.countAnimated(decor) >= 3, "anim")
			t.ok(MapKitLogic.countShadowedLights(decor) <= 2, "shadowed lights")
			t.ok(MapKitLogic.countLights(decor) >= 8, "lights")
		end
	)

	t.test("AC8: 밟는 면 위 시야 (언덕 반지름 40 기둥, 윗면 + 1 ~ 16)에 장식이 없어요", function()
		for _, spec in Art.decor() do
			for _, p in samples(spec) do
				local r = Layout.radiusOf(p[1], p[3])
				if r < Layout.HILL_RADIUS then
					local top = Layout.surfaceAt(r) :: number
					t.ok(p[2] <= top + 1 or p[2] >= 16, `{spec.name} at r {r} y {p[2]} (top {top})`)
				end
			end
		end
	end)

	t.test(
		"AC8: 배경 바닥 ≤ −30, 테두리 윗면 ≤ −2, 주걱은 반지름 40 밖, 반지름 40 안 장식은 작아요",
		function()
			local floors = { KitchenFloor = true, CounterPlank = true, BackCounterTop = true, LeftCounterTop = true }
			local seenFloor = false
			for _, spec in Art.decor() do
				local b = MapKitLogic.bounds({ spec }) :: any
				if floors[spec.name] then
					seenFloor = true
					t.ok(b.max.y <= -30 + EPS, `{spec.name} top {b.max.y}`)
				end
				if spec.name == "PotRim" or spec.name == "PotRimLip" then
					t.ok(b.max.y <= Layout.RIM_TOP_Y + EPS, `{spec.name} top {b.max.y}`)
				end
				if string.sub(spec.name, 1, 6) == "Paddle" then
					for _, p in samples(spec) do
						t.ok(Layout.radiusOf(p[1], p[3]) >= Layout.HILL_RADIUS, `{spec.name} inside the hill`)
					end
				end
				-- 언덕 위로 걸친 장식은 밥알·김 파츠 같은 작은 것뿐 (가짜 바닥 없음)
				local cx, cz = (b.min.x + b.max.x) / 2, (b.min.z + b.max.z) / 2
				if Layout.radiusOf(cx, cz) < Layout.HILL_RADIUS and b.max.y > Layout.BASE_Y and b.min.y < 16 then
					t.ok(
						spec.size.x <= 2.1 and spec.size.z <= 2.1,
						`{spec.name} is a big part over the hill ({spec.size.x}×{spec.size.z})`
					)
				end
			end
			t.ok(seenFloor, "background floors")
			t.ok(Layout.COUNTER_TOP_Y <= Layout.FALL_ELIMINATION_Y - 10, "counter 10 below the fall line")
		end
	)

	t.test("AC8: IntroCamera 5점 (넓은 샷·타이머·밸브·반전·출발 자리)", function()
		local points = Art.introCamera()
		t.eq(#points, 5)
		for i, p in points do
			local r = Layout.radiusOf(p.pos.x, p.pos.z)
			t.ok(r <= 160, `intro {i} distance {r}`)
			t.ok(p.pos.y > Layout.COUNTER_TOP_Y and p.pos.y < 120, `intro {i} height`)
		end
		local m = model()
		t.eq(#m:FindFirstChild("IntroCamera"):GetChildren(), 5)
	end)
end
