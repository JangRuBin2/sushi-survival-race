--!strict
-- m5-40 그룹 L2 (docs/specs/m5-40-map-length-pass.md): 라멘 국물 급류 · 디저트 냉장고 길이 늘리기.
--   AC1: 코스 길이(스폰 앞줄 → 결승선)가 목표 ±10%, 구간 z 단조, estimateClearTime 42~55초, 새 구간 길 약속
--   AC2: 새 구간 장애물 수치가 기존 같은 종류 범위 안, 스폰·출발 구간·기존 구간 수치 그대로
--   AC5: 장식 Extended 예산, 새 구간 시야 상자와 안 겹침, 배경 바닥이 새 구간 낙하선보다 10 이상 아래,
--        소개 카메라 점이 아레나 상자 + 40 안이고 경로가 불투명 파츠를 지나가지 않음
--   실제 build(렌더러 가짜 Roblox 환경 tools/render/Shims)로 새 판정 파츠·태그·결승선을 확인해요.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)
local RLayout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local RLogic = RobloxRequire.require(Shared.maps.RamenRapidsLogic)
local RArt = RobloxRequire.require(Shared.maps.RamenRapidsArt)
local DLayout = RobloxRequire.require(Shared.maps.DessertFridgeLayout)
local DLogic = RobloxRequire.require(Shared.maps.DessertFridgeLogic)
local DArt = RobloxRequire.require(Shared.maps.DessertFridgeArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local GRAVITY = 196.2
local EPS = 1e-6
local WALK = Config.Character.WalkSpeed
local JUMP_HEIGHT = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)

-- 같은 높이 / rise만큼 높은 발판으로 달려 뛸 때 닿는 가로 거리 (몸 반폭 여유 없이)
local function reachWithRise(rise: number): number
	local v = Config.Character.JumpPower
	local disc = v * v - 2 * GRAVITY * rise
	if disc < 0 then
		return 0
	end
	return WALK * (v + math.sqrt(disc)) / GRAVITY
end

local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = RMaps.get(id).build(origin)
	end
	return built[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function localPos(part: any): any
	return origin:PointToObjectSpace(part.CFrame.Position)
end

local function find(model: any, name: string): any
	for _, d in model:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function tagged(model: any, tag: string): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag(tag) then
			table.insert(list, d)
		end
	end
	return list
end

-- 판정 파츠(Decor·IntroCamera 밖) 경계 상자 (로컬)
local function judgmentBounds(model: any): any
	local min = { x = math.huge, y = math.huge, z = math.huge }
	local max = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "Decor") and not under(d, model, "IntroCamera") then
			local p = localPos(d)
			local r = math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2
			min.x, min.y, min.z = math.min(min.x, p.X - r), math.min(min.y, p.Y - r), math.min(min.z, p.Z - r)
			max.x, max.y, max.z = math.max(max.x, p.X + r), math.max(max.y, p.Y + r), math.max(max.z, p.Z + r)
		end
	end
	return { min = min, max = max }
end

local function introInsideArena(t: Test.Test, id: string, art: any)
	local b = judgmentBounds(build(id))
	for i, p in art.introCamera() do
		local q = p.pos
		t.ok(
			q.x >= b.min.x - 40 and q.x <= b.max.x + 40,
			`{id} intro {i} x {q.x} outside arena box + 40 ({b.min.x}..{b.max.x})`
		)
		t.ok(q.y >= b.min.y - 40 and q.y <= b.max.y + 40, `{id} intro {i} y {q.y}`)
		t.ok(q.z >= b.min.z - 40 and q.z <= b.max.z + 40, `{id} intro {i} z {q.z}`)
	end
end

-- 소개 카메라 경로가 불투명(투명도 < 0.5) 파츠 속을 지나가지 않아요 (m5-24-qa AC14와 같은 계산)
local function introPathClear(t: Test.Test, id: string, known: { [string]: boolean })
	local model = build(id)
	local intro = model:FindFirstChild("IntroCamera")
	local points = intro:GetChildren()
	table.sort(points, function(a: any, b: any)
		return a.Name < b.Name
	end)
	local path = {}
	for _, p in points do
		local pos = p.CFrame.Position
		local look = pos + p.CFrame.LookVector * 10
		table.insert(path, {
			position = { x = pos.X, y = pos.Y, z = pos.Z },
			lookAt = { x = look.X, y = look.Y, z = look.Z },
		})
	end
	local solids = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "IntroCamera") and d.Transparency < 0.5 then
			table.insert(solids, d)
		end
	end
	local hits: { string } = {}
	local seen: { [string]: boolean } = {}
	for step = 0, 600 do
		local w = IntroCameraLogic.sample(path, step / 600).position
		local wp = roblox.Vector3.new(w.x, w.y, w.z)
		for _, part in solids do
			local rel = part.CFrame:PointToObjectSpace(wp)
			local h = part.Size / 2
			if math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z then
				if not seen[part.Name] and not known[part.Name] then
					seen[part.Name] = true
					table.insert(hits, part.Name)
				end
			end
		end
	end
	table.sort(hits)
	t.eq(hits, {}, `{id}: intro camera path passes through opaque parts`)
end

type Box = { min: any, max: any }
local function overlaps(a: Box, b: Box): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

return function(t: Test.Test)
	---------------------------------------------------------------- 라멘 국물 급류
	t.test(
		"AC1 ramen: 스폰 앞줄 → 결승선 약 430 (±10%), 결승은 맨 끝, 구간이 출발 → 결승으로 이어져요",
		function()
			local startZ = RLayout.START.front - 2.5
			local length = startZ - RLayout.finishLineZ()
			t.ok(length >= 430 * 0.9 and length <= 430 * 1.1, `course length {length}`)
			local sections = RLayout.sections()
			t.eq(sections[#sections], RLayout.FINISH)
			for i = 2, #sections do
				t.eq(sections[i].front, sections[i - 1].back, `section {i}`)
				t.ok(sections[i].front > sections[i].back, `section {i} toward -Z`)
			end
			-- 결승선은 결승 구간 안, 진행도가 가장 커요
			t.ok(RLayout.finishLineZ() < RLayout.FINISH.front and RLayout.finishLineZ() > RLayout.FINISH.back)
			t.eq(RLogic.finishProgress(), -RLayout.finishLineZ())
		end
	)

	t.test("AC1 ramen: estimateClearTime(걷기 16 + 구간 지연)이 42~55초", function()
		local estimate = RLogic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
		-- 새 구간 지연은 양수, 급류는 밀기가 걷기보다 빨라 음수
		t.ok(RLayout.SECTION_DELAY.CHOPSTICKS > 0 and RLayout.SECTION_DELAY.RENGE_STAIRS > 0)
		t.ok(RLayout.SECTION_DELAY.RAPIDS2 < 0)
	end)

	t.test(
		"AC1 ramen: 새 구간 길 약속 — 이음매마다 달려 뛰어 닿고, 오르막은 점프 높이 안",
		function()
			local links = RLogic.newSectionLinks()
			t.ok(#links >= 12, `links {#links}`)
			for _, link in links do
				local label = `{link.from} → {link.to}`
				t.ok(link.rise <= JUMP_HEIGHT - 2, `{label} rise {link.rise} vs jump {JUMP_HEIGHT}`)
				if link.rise > 0.01 then
					t.ok(link.gap + 1 <= reachWithRise(link.rise), `{label} gap {link.gap} rise {link.rise}`)
					t.ok(link.gap <= 3, `{label} uphill gap {link.gap}`)
				else
					t.ok(link.gap <= RLayout.MAX_JUMP_GAP, `{label} gap {link.gap}`)
				end
			end
			-- 이어지는 이음매 (빈틈 0): 원판 → 뗏목, 뗏목 → 첫 쌍, 첫 쌍 → 받침, 받침 → 둘째 쌍, 급류 → 결승
			for _, link in links do
				if
					link.from ~= "Chopstick3"
					and link.from ~= "Chopstick4"
					and string.sub(link.from, 1, 5) ~= "Renge"
				then
					t.ok(link.gap < EPS, `{link.from} → {link.to} must touch (gap {link.gap})`)
				end
			end
			-- 렌게 4칸이 정확히 두 번째 급류 꼭대기까지 올라가고, 결승은 회전 발판 높이
			t.ok(
				math.abs(RLayout.rengeStepTop(#RLayout.RENGE_STEPS) - RLayout.rapids2HeightAt(RLayout.RAPIDS2.front))
					< EPS
			)
			t.ok(math.abs(RLayout.rapids2HeightAt(RLayout.RAPIDS2.back) - RLayout.platformTop()) < EPS)
		end
	)

	t.test(
		"AC1 ramen: 젓가락 다리 — 젓가락은 폭 1.6, 첫 쌍은 나란히, 둘째 쌍은 X자로 가운데에서 만나요",
		function()
			t.eq(RLayout.CHOPSTICK_WIDTH, 1.6)
			local sticks = RLogic.chopsticks()
			t.eq(#sticks, 4)
			t.eq(sticks[1].x0, sticks[1].x1)
			t.eq(sticks[2].x0, sticks[2].x1)
			t.ok(math.abs(sticks[1].x0 - sticks[2].x0) >= 4, "first pair lanes apart")
			-- 둘째 쌍: 앞 끝 x 부호가 반대, 가운데 z에서 같은 x(0)
			t.ok(sticks[3].x0 * sticks[3].x1 < 0 and sticks[4].x0 * sticks[4].x1 < 0, "crossing")
			t.ok(
				math.abs((sticks[3].x0 + sticks[3].x1) / 2) < EPS and math.abs((sticks[4].x0 + sticks[4].x1) / 2) < EPS
			)
			-- 모든 젓가락이 F 구간 안, 받침·뗏목 폭 안에서 끝나요
			for i, s in sticks do
				t.ok(s.z0 <= RLayout.CHOPSTICKS.front and s.z1 >= RLayout.CHOPSTICKS.back, `stick {i} in F`)
				t.ok(math.abs(s.x0) + 0.8 <= RLayout.CHOP_REST.width / 2, `stick {i} front end on rest/raft`)
				t.ok(math.abs(s.x1) + 0.8 <= RLayout.CHOP_REST.width / 2 + 1, `stick {i} back end`)
			end
		end
	)

	t.test(
		"AC1 ramen: 낙하선은 출발 → 결승으로 낮아지기만 하고, 새 구간 발판은 낙하선보다 25 이상 위",
		function()
			local previous = math.huge
			for z = 0, RLayout.FINISH.back, -0.5 do
				local line = RLogic.fallLineAt(z)
				t.ok(line <= previous + EPS, `fall line rises at z {z}`)
				previous = line
			end
			for i, step in RLayout.RENGE_STEPS do
				t.ok(RLayout.rengeStepTop(i) - RLogic.fallLineAt(step.back) >= 25, `renge {i}`)
			end
			for z = RLayout.RAPIDS2.front, RLayout.RAPIDS2.back, -1 do
				t.ok(RLayout.rapids2HeightAt(z) - RLogic.fallLineAt(z) >= 25 - EPS, `rapids2 z {z}`)
			end
			-- 가장 높은 새 발판(두 번째 급류 꼭대기)에서 떨어져도 1초 안에 낙하선
			local drop = RLayout.rapids2HeightAt(RLayout.RAPIDS2.front) - RLogic.fallLineAt(RLayout.RAPIDS2.front)
			t.ok(math.sqrt(2 * drop / GRAVITY) < 1, `fall time from rapids2 top {drop}`)
		end
	)

	t.test(
		"AC2 ramen: 새 장애물 수치가 기존 범위 안 (두 번째 급류 = 첫 급류와 같은 기울기·폭·밀기, 소용돌이 없음)",
		function()
			t.eq(RLayout.RAPIDS2_WIDTH, RLayout.RAPIDS_WIDTH)
			t.ok(RLayout.RAPIDS2.front - RLayout.RAPIDS2.back <= RLayout.RAPIDS.front - RLayout.RAPIDS.back)
			for z = RLayout.RAPIDS2.front, RLayout.RAPIDS2.back, -2 do
				for _, x in { -8, 0, 8 } do
					local push = RLogic.pushVector(x, z)
					t.eq(push.side, 0, `rapids2 ({x},{z}) side push`)
					t.eq(push.forward, RLayout.BROTH_PUSH_SPEED, `rapids2 ({x},{z}) forward push`)
				end
			end
			t.eq(#RLayout.RAPIDS2_NOODLE_ZS, 2)
			for _, z in RLayout.RAPIDS2_NOODLE_ZS do
				t.ok(z < RLayout.RAPIDS2.front - 4 and z > RLayout.RAPIDS2.back + 4, `noodle {z} inside rapids2`)
			end
			-- 렌게 한 칸 오름(약 2.66)은 차슈가 나루토보다 높아지는 폭(1.5)과 점프 높이 사이
			local rise = RLayout.rapids2Drop() / #RLayout.RENGE_STEPS
			t.ok(rise <= 3, `renge rise {rise}`)
			-- 새 구간에는 MoveExempt를 새로 달지 않아요 (막대 넉백 한 곳 그대로)
			local source = fs.readFile("src/shared/maps/RamenRapids.luau")
			local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
			t.eq(marks, 1)
		end
	)

	t.test("AC2 ramen: 스폰·출발 구간과 A~D 구간 치수가 m5-40 전 그대로", function()
		t.eq(RLayout.START.front, 0)
		t.eq(RLayout.START.back, -16)
		t.eq(RLayout.RAPIDS.back, -126)
		t.eq(RLayout.TOPPINGS.back, -206)
		t.eq(RLayout.SWEEPERS.back, -276)
		local spawns = RLayout.spawnPositions()
		t.eq(#spawns, 24)
		t.eq(spawns[1].x, -2.5 * 3.6)
		t.eq(spawns[1].z, -2.5)
		t.eq(spawns[24].z, -2.5 - 3 * 3.6)
	end)

	t.test(
		"build ramen: 새 판정 파츠(뗏목·젓가락 4·받침·렌게 4·두 번째 급류)가 충돌 있고, Broth 판은 2개",
		function()
			local model = build("ramen-rapids")
			for _, name in
				{
					"ChopRaft",
					"Chopstick1",
					"Chopstick2",
					"Chopstick3",
					"Chopstick4",
					"ChopRest",
					"RengeStep1",
					"RengeStep2",
					"RengeStep3",
					"RengeStep4",
					"BrothSlide2",
				}
			do
				local part = find(model, name)
				t.ok(part ~= nil, name)
				if part then
					t.eq(part.CanCollide, true, name)
					t.eq(part.Anchored, true, name)
					t.ok(not under(part, model, "Decor"), `{name} is judgment`)
				end
			end
			t.eq(#tagged(model, "Broth"), 2)
			-- 렌게 발판 윗면 높이 = Layout
			for i = 1, #RLayout.RENGE_STEPS do
				local part = find(model, `RengeStep{i}`)
				local top = localPos(part).Y + part.Size.Y / 2
				t.ok(math.abs(top - RLayout.rengeStepTop(i)) < 1e-3, `renge {i} top {top}`)
			end
			-- 젓가락 윗면 = 회전 발판 높이, 길이 방향이 앞 끝 → 뒤 끝
			for i, s in RLogic.chopsticks() do
				local part = find(model, `Chopstick{i}`)
				local p = localPos(part)
				t.ok(math.abs(p.Y + part.Size.Y / 2 - RLayout.platformTop()) < 1e-3, `stick {i} top`)
				local front = origin:PointToObjectSpace(part.CFrame * roblox.Vector3.new(0, 0, -part.Size.Z / 2))
				t.ok(math.abs(front.X - s.x1) < 1e-3 and math.abs(front.Z - s.z1) < 1e-3, `stick {i} orientation`)
			end
			local line = find(model, "FinishLine")
			t.ok(math.abs(localPos(line).Z - RLayout.finishLineZ()) < 1e-3, "finish line z")
		end
	)

	t.test(
		"AC5 ramen: 장식 Extended 예산, 새 구간 시야 상자와 안 겹침, 그릇이 코스를 감싸고 배경은 낙하선 10 아래",
		function()
			local decor = RArt.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(MapKitLogic.checkBudget(decor, "Extended"), nil, `decor {MapKitLogic.count(decor)}`)
			local volumes = RArt.courseVolumes()
			t.ok(#volumes >= 16, "new section volumes")
			for i, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: any
				for j, volume in volumes do
					t.ok(not overlaps(b, volume :: any), `decor #{i} {spec.name} overlaps volume {j}`)
				end
			end
			-- 그릇 벽(반지름) 안쪽에 코스 끝까지 들어가요 (출발 뒤·결승 끝에서 벽까지 20 이상)
			local function inBowl(x: number, z: number): number
				local dz = z - RArt.BOWL_CENTER_Z
				return RArt.BOWL_RADIUS - math.sqrt(x * x + dz * dz)
			end
			t.ok(inBowl(12, RLayout.FINISH.back) >= 20, "finish end inside bowl")
			t.ok(inBowl(12, RLayout.START.front) >= 20, "start inside bowl")
			-- 카운터(배경 바닥)는 새 구간 낙하선보다 10 이상 아래
			local lowest = math.huge
			for z = 0, RLayout.FINISH.back, -1 do
				lowest = math.min(lowest, RLogic.fallLineAt(z))
			end
			t.ok(RArt.COUNTER_TOP_Y <= lowest - 10, `counter {RArt.COUNTER_TOP_Y} vs fall {lowest}`)
			-- 새 구간 장식 무리가 있어요 (국자·렌게·젓가락 받침)
			local names: { [string]: boolean } = {}
			for _, spec in decor do
				names[spec.name] = true
			end
			for _, name in { "LadleCup", "LadleStream", "RengeBowl", "RengeHandle", "RestHead", "StairLantern" } do
				t.ok(names[name], `decor {name}`)
			end
		end
	)

	t.test(
		"AC5 ramen: 소개 카메라 4점이 아레나 상자 + 40 안, 경로가 불투명 파츠를 지나가지 않아요",
		function()
			t.eq(#RArt.introCamera(), 4)
			introInsideArena(t, "ramen-rapids", RArt)
			-- StartWall: 출발 뒤 반투명(0.6) 판정 벽 — m5-24-qa KNOWN_INTRO_THROUGH와 같은 예외
			introPathClear(t, "ramen-rapids", { StartWall = true })
		end
	)

	---------------------------------------------------------------- 디저트 냉장고
	t.test(
		"AC1 dessert: 스폰 앞줄 → 결승선 약 420 (±10%), 구간이 출발 → 결승으로 이어져요",
		function()
			local startZ = DLayout.START.front - 2.5
			local length = startZ - DLayout.FINISH_LINE_Z
			t.ok(length >= 420 * 0.9 and length <= 420 * 1.1, `course length {length}`)
			local sections = DLayout.sections()
			t.eq(sections[#sections], DLayout.FINISH)
			for i = 2, #sections do
				t.eq(sections[i].front, sections[i - 1].back, `section {i}`)
			end
			t.eq(DLayout.SCOOP_LANDING.back, DLayout.SCOOP_ZONE.back)
			t.eq(DLayout.SCOOP_ZONE.back, DLayout.FINISH.front)
			t.ok(DLayout.FINISH_LINE_Z < DLayout.FINISH.front and DLayout.FINISH_LINE_Z > DLayout.FINISH.back)
		end
	)

	t.test("AC1 dessert: estimateClearTime(걷기 16 + 구간 지연)이 42~55초", function()
		local estimate = DLogic.estimateClearTime()
		t.ok(estimate >= 42 and estimate <= 55, `estimate {estimate}`)
	end)

	t.test(
		"AC1 dessert: F 냉동실 — 구멍 3개가 x = 0을 안 덮고, 폭 4 길이 F를 끝까지 이어져요 (격자 탐색)",
		function()
			t.eq(#DLayout.FREEZER_HOLES, 3)
			local half = DLayout.FREEZER_WIDTH / 2
			for i, r in DLayout.freezerHoleRects() do
				t.ok(r.minX >= -half - EPS and r.maxX <= half + EPS, `hole {i} inside width`)
				t.ok(r.maxZ <= DLayout.FREEZER.front and r.minZ >= DLayout.FREEZER.back, `hole {i} inside F`)
				t.ok(r.minX > 0 or r.maxX < 0, `hole {i} leaves x = 0`)
				t.eq(DLogic.freezerWalkable((r.minX + r.maxX) / 2, (r.minZ + r.maxZ) / 2), false)
			end
			-- 바닥 조각 넓이 = 칸 넓이 - 구멍 3개
			local area = 0
			for _, r in DLayout.freezerRects() do
				area += (r.maxX - r.minX) * (r.maxZ - r.minZ)
			end
			local expected = DLayout.FREEZER_WIDTH * (DLayout.FREEZER.front - DLayout.FREEZER.back)
				- 3 * DLayout.HOLE_SIZE ^ 2
			t.ok(math.abs(area - expected) < 1e-6, `area {area} vs {expected}`)
			-- 폭 4 정사각형이 지나가는 길 (0.5 격자)
			local STEP, HALF = 0.5, 2
			local function free(x: number, z: number): boolean
				if math.abs(x) + HALF > half + EPS then
					return false
				end
				for _, r in DLayout.freezerHoleRects() do
					if
						x - HALF < r.maxX - EPS
						and x + HALF > r.minX + EPS
						and z - HALF < r.maxZ - EPS
						and z + HALF > r.minZ + EPS
					then
						return false
					end
				end
				return true
			end
			local xs = math.floor((2 * (half - HALF)) / STEP + 0.5)
			local zs = math.floor((DLayout.FREEZER.front - DLayout.FREEZER.back) / STEP + 0.5)
			local seen: { [number]: boolean } = {}
			local queue = {}
			for ix = 0, xs do
				if free(-half + HALF + ix * STEP, DLayout.FREEZER.front) then
					table.insert(queue, { ix, 0 })
					seen[ix] = true
				end
			end
			local reached = false
			local head = 1
			while head <= #queue do
				local node = queue[head]
				head += 1
				if node[2] == zs then
					reached = true
					break
				end
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx, nz = node[1] + d[1], node[2] + d[2]
					local key = nz * 10000 + nx
					if nx >= 0 and nx <= xs and nz >= 0 and nz <= zs and not seen[key] then
						if free(-half + HALF + nx * STEP, DLayout.FREEZER.front - nz * STEP) then
							seen[key] = true
							table.insert(queue, { nx, nz })
						end
					end
				end
			end
			t.ok(reached, "no 4-wide path through the freezer")
		end
	)

	t.test(
		"AC1 dessert: G 스쿱 계단 — 바닥 → 스쿱 4개 → 착지대가 점프로 이어지고, 젤리는 착지대까지 튕겨요",
		function()
			local hops = DLogic.scoopClimb()
			t.eq(#hops, #DLayout.SCOOPS + 1)
			for _, hop in hops do
				local label = `{hop.from} → {hop.to}`
				t.ok(hop.rise > 0 and hop.rise <= 3, `{label} rise {hop.rise}`)
				t.ok(hop.gap + 1 <= reachWithRise(hop.rise), `{label} gap {hop.gap}`)
			end
			t.ok(
				math.abs(DLayout.scoopTop(#DLayout.SCOOPS) + DLayout.SCOOP_RISE - DLayout.TOP_Y) < EPS,
				"last rise lands on top"
			)
			-- 스쿱은 G 바닥 안, 젤리와 안 겹쳐요
			local r = DLayout.SCOOP_DIAMETER / 2
			local jelly = DLayout.scoopJellyRect()
			for i, s in DLayout.SCOOPS do
				t.ok(math.abs(s.x) + r <= DLayout.SCOOP_ZONE_WIDTH / 2, `scoop {i} x`)
				t.ok(s.z + r <= DLayout.SCOOP_ZONE.front and s.z - r >= DLayout.SCOOP_LANDING.front, `scoop {i} z`)
				local nx = math.clamp(s.x, jelly.minX, jelly.maxX)
				local nz = math.clamp(s.z, jelly.minZ, jelly.maxZ)
				t.ok(math.sqrt((s.x - nx) ^ 2 + (s.z - nz) ^ 2) > r + 0.5, `scoop {i} clear of the jelly`)
			end
			-- 젤리: C 젤리와 같은 크기·튕김, 착지대 앞면에 붙어 있고 그 높이를 넘어요
			t.ok(math.abs(jelly.minZ - DLayout.SCOOP_LANDING.front) < EPS, "jelly touches the landing")
			t.ok(math.abs(jelly.minX) <= DLayout.SCOOP_ZONE_WIDTH / 2, "jelly inside G")
			local bounce = DLogic.bounceHeight(DLayout.JELLY_UP, GRAVITY)
			t.ok(DLayout.HIGH_Y + DLayout.JELLY_TOP + bounce >= DLayout.TOP_Y, "jelly reaches the upper tier")
			t.eq(DLogic.scoopJellyAt(DLayout.SCOOP_JELLY.x, DLayout.HIGH_Y + 4, DLayout.SCOOP_JELLY.z), true)
			t.eq(DLogic.scoopJellyAt(DLayout.SCOOP_JELLY.x, DLayout.TOP_Y + 3, DLayout.SCOOP_JELLY.z), false)
			t.eq(DLogic.scoopJellyAt(8, DLayout.HIGH_Y + 4, DLayout.SCOOP_JELLY.z), false)
			-- 원래 C 젤리 판정은 G 젤리에 반응하지 않아요 (높이가 달라요)
			t.eq(DLogic.jellyAt(DLayout.SCOOP_JELLY.x, DLayout.HIGH_Y + 4, DLayout.SCOOP_JELLY.z), nil)
		end
	)

	t.test(
		"AC1 dessert: 낙하선 — F·G -13, E -1 (G 착지대도 G 구간), 단조 증가 없이 구간 바닥 - 25",
		function()
			t.eq(DLogic.fallLineAt(-240), -13)
			t.eq(DLogic.fallLineAt(-330), -13)
			t.eq(DLogic.fallLineAt(-380), -13) -- G 착지대 (C 착지대와 같은 규칙)
			t.eq(DLogic.fallLineAt(-400), DLayout.TOP_Y - 25)
			t.eq(DLogic.fallLineAt(DLayout.FINISH.back + 1), DLayout.TOP_Y - 25)
			-- 높은 결승에서 떨어져도 1초 안
			t.ok(math.sqrt(2 * DLayout.FALL_MARGIN / GRAVITY) < 1)
		end
	)

	t.test("AC2 dessert: 냉동 송풍구·젤리 수치가 D·C와 같고, F는 B·D보다 좁아요", function()
		t.ok(DLayout.FREEZER_WIDTH < DLayout.ICE_TRAY_WIDTH and DLayout.FREEZER_WIDTH < DLayout.FAN_SHELF_WIDTH)
		t.eq(#DLayout.FREEZER_FANS, 1)
		local fan = DLayout.FREEZER_FANS[1]
		t.ok(fan.front <= DLayout.FREEZER.front and fan.back >= DLayout.FREEZER.back, "fan zone in F")
		t.eq(math.abs(fan.dirX), 1)
		-- 상태는 D와 같은 주기 (0.5 경고 → 2 불기 → 1.5 쉼), offset만 달라요
		for step = 0, 160 do
			local time = step * 0.05
			t.eq(DLogic.freezerFanState(1, time + fan.offset), DLogic.fanState(1, time), `t {time}`)
		end
		t.eq(DLogic.freezerFanAt(0, DLayout.HIGH_Y + 3, (fan.front + fan.back) / 2), 1)
		t.eq(DLogic.freezerFanAt(9, DLayout.HIGH_Y + 3, (fan.front + fan.back) / 2), nil)
		t.eq(DLogic.freezerFanAt(0, DLayout.HIGH_Y + 20, (fan.front + fan.back) / 2), nil)
		-- D 송풍구 판정은 F를 모르고, F 판정은 D를 몰라요
		t.eq(DLogic.fanAt(0, DLayout.HIGH_Y + 3, (fan.front + fan.back) / 2), nil)
		t.eq(DLogic.freezerFanAt(0, DLayout.HIGH_Y + 3, -158), nil)
		t.eq(DLogic.freezerFanPush(1).x, fan.dirX)
		t.eq(DLogic.inFreezer(-250), true)
		t.eq(DLogic.inFreezer(-158), false)
		-- 서버: 냉동 송풍구는 D와 같은 밀기(FAN_PUSH_SPEED·ACCEL), 젤리는 같은 튕김·면제 한 곳, 소리는 냉동실에 누가 있을 때만
		local source = fs.readFile("src/shared/maps/DessertFridge.luau")
		local _, marks = string.gsub(source, "MoveExempt%.mark%(", "")
		t.eq(marks, 1)
		t.ok(string.find(source, 'TAG_FREEZER_FAN = "FreezerFan"', 1, true) ~= nil)
		t.ok(string.find(source, 'TAG_SCOOP_JELLY = "ScoopJelly"', 1, true) ~= nil)
		t.ok(string.find(source, 'if state == "Blow" and anyoneInFreezer then', 1, true) ~= nil)
		t.ok(string.find(source, "taggedParts(ctx, TAG_FREEZER_FAN)", 1, true) ~= nil)
		t.ok(string.find(source, "taggedParts(ctx, TAG_SCOOP_JELLY)", 1, true) ~= nil)
	end)

	t.test("AC2 dessert: 스폰·출발 구간과 A~D 구간이 m5-40 전 그대로", function()
		t.eq(DLayout.START.front, 0)
		t.eq(DLayout.START.back, -16)
		t.eq(DLayout.ICE_TRAY.back, -96)
		t.eq(DLayout.JELLY_ZONE.back, -136)
		t.eq(DLayout.FAN_SHELF.back, -216)
		t.eq(#DLayout.FANS, 2)
		t.eq(#DLayout.JELLIES, 3)
		local spawns = DLayout.spawnPositions()
		t.eq(#spawns, 24)
		t.eq(spawns[1].z, -2.5)
		t.eq(spawns[24].z, -2.5 - 3 * 3.5)
	end)

	t.test(
		"build dessert: F 얼음 조각·냉동 송풍구·스쿱 4·젤리·착지대·결승(y 24)이 Layout대로",
		function()
			local model = build("dessert-fridge")
			local freezerIce = 0
			for _, part in tagged(model, "Ice") do
				if string.match(part.Name, "^FreezerFloor") then
					freezerIce += 1
					local p = localPos(part)
					t.ok(math.abs(p.Y + part.Size.Y / 2 - DLayout.HIGH_Y) < 1e-3, `{part.Name} top`)
				end
			end
			t.eq(freezerIce, #DLayout.freezerRects())
			local fans = tagged(model, "FreezerFan")
			t.eq(#fans, 1)
			t.eq(fans[1].CanCollide, false)
			t.eq(fans[1]:GetAttribute("FanIndex"), 1)
			t.ok(math.abs(localPos(fans[1]).X) > DLayout.FREEZER_WIDTH / 2, "vent outside the freezer floor")
			local jellies = tagged(model, "ScoopJelly")
			t.eq(#jellies, 1)
			t.eq(jellies[1].CanCollide, true)
			t.eq(#tagged(model, "Jelly"), 3) -- C 젤리 수 그대로
			t.eq(#tagged(model, "ColdFan"), 2) -- D 송풍구 수 그대로
			for i = 1, #DLayout.SCOOPS do
				local scoop = find(model, `Scoop{i}`)
				t.ok(scoop ~= nil and scoop.CanCollide, `scoop {i}`)
				local p = localPos(scoop)
				t.ok(math.abs(p.Y + scoop.Size.X / 2 - DLayout.scoopTop(i)) < 1e-3, `scoop {i} top`)
			end
			local landing = find(model, "ScoopLanding")
			t.ok(math.abs(localPos(landing).Y + landing.Size.Y / 2 - DLayout.TOP_Y) < 1e-3, "landing top 24")
			local finish = find(model, "FinishFloor")
			t.ok(math.abs(localPos(finish).Y + finish.Size.Y / 2 - DLayout.TOP_Y) < 1e-3, "finish floor top 24")
			local line = find(model, "FinishLine")
			t.ok(math.abs(localPos(line).Z - DLayout.FINISH_LINE_Z) < 1e-3, "finish line z")
		end
	)

	t.test(
		"AC5 dessert: 장식 Extended 예산, 새 구간 시야 상자·바로 위(+0.01~+2)·가장자리 가짜 난간 없음",
		function()
			local decor = DArt.decor()
			t.eq(MapKitLogic.validate(decor), nil)
			t.eq(MapKitLogic.checkBudget(decor, "Extended"), nil, `decor {MapKitLogic.count(decor)}`)
			local volumes = DArt.courseVolume()
			t.eq(#volumes, 9)
			for i, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: any
				for j, volume in volumes do
					t.ok(not overlaps(b, volume :: any), `decor #{i} {spec.name} overlaps volume {j}`)
				end
			end
			local high, top = DLayout.HIGH_Y, DLayout.TOP_Y
			local strips = {
				{
					half = DLayout.FREEZER_WIDTH / 2,
					y = high,
					front = DLayout.FREEZER.front,
					back = DLayout.FREEZER.back,
				},
				{
					half = DLayout.SCOOP_ZONE_WIDTH / 2,
					y = high,
					front = DLayout.SCOOP_ZONE.front,
					back = DLayout.SCOOP_LANDING.front,
				},
				{
					half = DLayout.SCOOP_ZONE_WIDTH / 2,
					y = top,
					front = DLayout.SCOOP_LANDING.front,
					back = DLayout.SCOOP_LANDING.back,
				},
				{ half = DLayout.FINISH_WIDTH / 2, y = top, front = DLayout.FINISH.front, back = DLayout.FINISH.back },
			}
			for _, spec in decor do
				local b = MapKitLogic.bounds({ spec }) :: any
				for i, s in strips do
					local on = b.min.x < s.half - 0.01
						and b.max.x > -s.half + 0.01
						and b.min.z < s.front - 0.01
						and b.max.z > s.back + 0.01
						and b.max.y > s.y + 0.01
						and b.min.y < s.y + 2
					t.ok(not on, `{spec.name} sits on new course strip {i}`)
				end
				-- F 가장자리 바로 바깥(1.5 안)에 바닥보다 솟은 장식 없음 (송풍구 하우징 자리만 예외)
				local fh = DLayout.FREEZER_WIDTH / 2
				for _, side in { -1, 1 } do
					local x0 = if side > 0 then fh else -fh - 1.5
					local x1 = if side > 0 then fh + 1.5 else -fh
					local rail = b.min.x < x1
						and b.max.x > x0
						and b.min.z < DLayout.FREEZER.front - 0.01
						and b.max.z > DLayout.FREEZER.back + 0.01
						and b.max.y > high + 0.3
						and b.min.y < high + 6
					if rail then
						local fan = DLayout.FREEZER_FANS[1]
						local known = string.match(spec.name, "^Fan") ~= nil
							and b.max.z <= fan.front + 2.01
							and b.min.z >= fan.back - 2.01
							and side == -fan.dirX
						t.ok(known, `{spec.name} looks like a rail on the freezer edge side {side}`)
					end
				end
			end
			-- 배경 바닥은 가장 낮은 낙하선(-25)보다 10 이상 아래, 냉장고가 결승 끝을 감싸요
			t.ok(DArt.KITCHEN_FLOOR_Y <= DLogic.fallLineAt(0) - 10)
			t.ok(DArt.FRONT_Z <= DLayout.FINISH.back, "fridge front past the finish end")
			-- 새 구간 무리 (냉동실 문틀·눈꽃 표지·스쿱 케이크 단·냉동 참치)
			local names: { [string]: boolean } = {}
			for _, spec in decor do
				names[spec.name] = true
			end
			for _, name in { "FreezerGatePost", "FreezerSnowflake", "IceCakeLayer", "FrozenTuna", "Icicle" } do
				t.ok(names[name], `decor {name}`)
			end
		end
	)

	t.test(
		"AC5 dessert: 소개 카메라 4점이 냉장고 안·아레나 상자 + 40 안, 경로가 불투명 파츠를 지나가지 않아요",
		function()
			t.eq(#DArt.introCamera(), 4)
			for i, p in DArt.introCamera() do
				t.ok(math.abs(p.pos.x) < DArt.IN_X, `intro {i} x`)
				t.ok(p.pos.y < DArt.CEIL_Y and p.pos.y > DArt.FLOOR_Y, `intro {i} y`)
				t.ok(p.pos.z < DArt.BACK_Z and p.pos.z > DArt.FRONT_Z, `intro {i} z`)
			end
			introInsideArena(t, "dessert-fridge", DArt)
			introPathClear(t, "dessert-fridge", {})
		end
	)
end
