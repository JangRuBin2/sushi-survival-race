--!strict
-- m6-03~07 QA: 대형 맵 5개(sushi-counter-crossing · bento-door-dash · pantry-shelf-dash · lazy-susan · banquet-sweep)를
-- 같은 잣대로 한 번에 봐요. 개발 테스트(tests/map-<id>.spec.luau)에 없는 것만:
--   1. 공통 계약: 풀·capacity 40·minPlayers 12, Survival timeLimit 75(서든데스 60), Race 추정 45~55초·결승선이 -Z 끝,
--      스폰 40개가 진짜 build에서 모두 충돌 바닥 위(회전·원기둥 포함)
--   2. 아트 규칙: Art.BUDGET = "Large" + checkBudget, 조명 범위(Surface ≤ 16 · Point/Spot ≤ 60) · 그림자는 Spot만,
--      안개 패널(큰 반투명 판) 없음, 소개 카메라 점이 판정 상자 + 40 안, 소개 경로가 불투명 판정 파츠를 뚫지 않음
--   3. 서버 모듈 소스: build 끝 introCamera → attachStudioArt → return, MoveExempt.mark 한 곳, 태그는 ctx.model 하위만,
--      모듈 수준 표 상태 없음, 레이서 목록은 ctx.getRacers()만(Race 부활 대기자는 맵에 안 보임)
--   4. 점프 창(물리 근사): 굴러오는 것을 마주 달려 점프하면 넘을 수 있는 시간 여유(카운터 간장병·동전, 팬트리 통조림),
--      연회상 낮은 벽은 마주 달려 점프 여유 0.2초 이상 — 가만히 서서는 0.06초뿐(리포트 m6-07 P2-1)
--   5. 회전 원판: 조각 사이 쐐기 틈 ≤ 1 stud, 연회상: 높은 벽 빈 칸은 어디서 출발해도 도망치며 닿을 수 있어요

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local H = require("./lib/LargeMapHarness")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)

local SCLayout = RobloxRequire.require(Shared.maps.SushiCounterCrossingLayout)
local PLayout = RobloxRequire.require(Shared.maps.PantryShelfDashLayout)
local BLayout = RobloxRequire.require(Shared.maps.BanquetSweepLayout)
local BLogic = RobloxRequire.require(Shared.maps.BanquetSweepLogic)
local LLayout = RobloxRequire.require(Shared.maps.LazySusanLayout)
local LLogic = RobloxRequire.require(Shared.maps.LazySusanLogic)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local GRAVITY = 196.2
local JUMP = Config.Character.JumpPower
local WALK = Config.Character.WalkSpeed

type MapCase = { id: string, file: string, kind: string, art: any, logic: any }

local CASES: { MapCase } = {
	{
		id = "sushi-counter-crossing",
		file = "SushiCounterCrossing",
		kind = "Race",
		art = RobloxRequire.require(Shared.maps.SushiCounterCrossingArt),
		logic = RobloxRequire.require(Shared.maps.SushiCounterCrossingLogic),
	},
	{
		id = "bento-door-dash",
		file = "BentoDoorDash",
		kind = "Race",
		art = RobloxRequire.require(Shared.maps.BentoDoorDashArt),
		logic = RobloxRequire.require(Shared.maps.BentoDoorDashLogic),
	},
	{
		id = "pantry-shelf-dash",
		file = "PantryShelfDash",
		kind = "Race",
		art = RobloxRequire.require(Shared.maps.PantryShelfDashArt),
		logic = RobloxRequire.require(Shared.maps.PantryShelfDashLogic),
	},
	{
		id = "lazy-susan",
		file = "LazySusan",
		kind = "Survival",
		art = RobloxRequire.require(Shared.maps.LazySusanArt),
		logic = LLogic,
	},
	{
		id = "banquet-sweep",
		file = "BanquetSweep",
		kind = "Survival",
		art = RobloxRequire.require(Shared.maps.BanquetSweepArt),
		logic = BLogic,
	},
}

-- 리포트 m6-04 P3-1: 도시락 소개 ① (z 50)이 판정 상자(z 최대 약 3) + 40 밖. MapLightingController는 소개 점을 상자에 넣어 재서
-- 화면 차이는 없지만 CLAUDE.md 규칙("소개 카메라 점은 아레나 상자 + 40 안")과 달라요.
local KNOWN_INTRO_OUTSIDE: { [string]: boolean } = { ["bento-door-dash:1"] = true }

local origin = RCF.new(Config.Arena.SlotSpacing * 3, Config.Arena.BaseHeight, 0)
local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = H.build(id, origin)
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

-- 판정 파츠(Decor·IntroCamera 밖) 경계 상자, origin 로컬 (MapLightingController.measure처럼 Size.Magnitude / 2)
local function judgmentBounds(model: any): any
	local min = { x = math.huge, y = math.huge, z = math.huge }
	local max = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "Decor") and not under(d, model, "IntroCamera") then
			local p = origin:PointToObjectSpace(d.CFrame.Position)
			local r = d.Size.Magnitude / 2
			min.x, min.y, min.z = math.min(min.x, p.X - r), math.min(min.y, p.Y - r), math.min(min.z, p.Z - r)
			max.x, max.y, max.z = math.max(max.x, p.X + r), math.max(max.y, p.Y + r), math.max(max.z, p.Z + r)
		end
	end
	return { min = min, max = max }
end

-- 점 p(월드)가 파츠 안인가 (원기둥은 축 X 기준 반지름까지)
local function pointInPart(part: any, p: any): boolean
	local rel = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	if math.abs(rel.X) > h.X or math.abs(rel.Y) > h.Y or math.abs(rel.Z) > h.Z then
		return false
	end
	if part:IsA("Part") and part.Shape == roblox.Enum.PartType.Cylinder then
		return math.sqrt(rel.Y * rel.Y + rel.Z * rel.Z) <= math.min(h.Y, h.Z)
	end
	if part:IsA("Part") and part.Shape == roblox.Enum.PartType.Ball then
		return rel.Magnitude <= h.X
	end
	return true
end

-- 점프: 발 높이 (점프 뒤 s초)
local function footAt(s: number): number
	if s <= 0 then
		return 0
	end
	return math.max(JUMP * s - 0.5 * GRAVITY * s * s, 0)
end

-- 마주 오는 장애물(맞는 띠 반폭 half, 맞는 발 높이 미만 thr)을 닫히는 속도 closing으로 지날 때,
-- 띠를 지나는 동안 내내 발이 thr 이상이 되게 하는 점프 시각의 폭(초). 0이면 점프로 못 넘어요.
local function jumpWindow(half: number, closing: number, thr: number): number
	if closing <= 0 then
		return 0
	end
	local inside = 2 * half / closing
	local good = 0
	local step = 0.001
	for tj = -1, 1, step do
		local ok = true
		local t = 0
		while t <= inside do
			if footAt(t - tj) < thr then
				ok = false
				break
			end
			t += 1 / 240
		end
		if ok then
			good += step
		end
	end
	return good
end

return function(t: Test.Test)
	---------------------------------------------------------------- 1. 공통 계약
	t.test(
		"공통: 5개 모두 랜덤 풀, capacity 40·minPlayers 12, Survival은 timeLimit 75·서든데스 60",
		function()
			for _, c in CASES do
				local map = Maps.get(c.id)
				t.ok(map ~= nil, c.id)
				t.eq(map.kind, c.kind, c.id)
				t.ok(map.inPool ~= false, `{c.id} in pool`)
				t.eq(map.capacity, Config.Maps.LargeCapacity, c.id)
				t.eq(map.minPlayers, Config.Maps.LargeMinPlayers, c.id)
				t.ok(map.lighting ~= nil, `{c.id} lighting`)
				if c.kind == "Survival" then
					t.eq(map.timeLimit, 75, c.id)
					t.eq(c.logic.TIME_LIMIT, 75, c.id)
					t.eq(c.logic.SUDDEN_DEATH_AT, 60, c.id)
				else
					t.eq(map.timeLimit, nil, `{c.id} uses Config.TimeLimit.Race`)
					local est = c.logic.estimateClearTime()
					t.ok(est >= 45 and est <= 55, `{c.id} estimate {est}`)
				end
			end
		end
	)

	t.test(
		"공통: 스폰 40개가 모두 충돌 켜진 판정 바닥 바로 위 (진짜 build, 회전 조각·원기둥 포함)",
		function()
			for _, c in CASES do
				local model = build(c.id)
				local floors = {}
				for _, d in model:GetDescendants() do
					if
						d:IsA("BasePart")
						and d.CanCollide
						and not under(d, model, "Decor")
						and not under(d, model, "Spawns")
						and not under(d, model, "IntroCamera")
					then
						table.insert(floors, d)
					end
				end
				local spawns = model:FindFirstChild("Spawns"):GetChildren()
				t.eq(#spawns, 40, c.id)
				for _, s in spawns do
					local below = s.CFrame.Position - RV3.new(0, 0.6, 0)
					local found = false
					for _, f in floors do
						if pointInPart(f, below) then
							found = true
							break
						end
					end
					t.ok(found, `{c.id} {s.Name} stands on a collidable floor`)
				end
			end
		end
	)

	t.test("Race: 코스가 로컬 -Z로 — 결승선이 모든 스폰보다 -Z 쪽, 진행도 = -z", function()
		for _, c in CASES do
			if c.kind ~= "Race" then
				continue
			end
			local model = build(c.id)
			local finish = model:FindFirstChild("FinishLine")
			t.ok(finish ~= nil, c.id)
			local fz = origin:PointToObjectSpace(finish.CFrame.Position).Z
			for _, s in model:FindFirstChild("Spawns"):GetChildren() do
				t.ok(origin:PointToObjectSpace(s.CFrame.Position).Z > fz + 400, `{c.id} {s.Name} far behind the finish`)
			end
			t.eq(c.logic.finishProgress(), -fz, c.id)
			t.eq(c.logic.progress(-100), 100, c.id)
		end
	end)

	---------------------------------------------------------------- 2. 아트 규칙
	t.test("아트: Large 예산, 조명 범위·그림자는 좁은 Spot만, 안개 패널 없음", function()
		for _, c in CASES do
			t.eq(c.art.BUDGET, "Large", c.id)
			local decor = c.art.decor()
			t.eq(MapKitLogic.checkBudget(decor, "Large"), nil, c.id)
			t.eq(MapKitLogic.validate(decor), nil, c.id)
			for _, spec in decor do
				local light = spec.light
				if light then
					if light.kind == "Surface" then
						t.ok(light.range <= 16, `{c.id} {spec.name} surface range {light.range}`)
					else
						t.ok(light.range <= 60, `{c.id} {spec.name} range {light.range}`)
					end
					if light.shadows then
						t.eq(light.kind, "Spot", `{c.id} {spec.name} shadow light kind`)
					end
				end
				-- 안개 패널: 얇고(≤ 2) 넓은(두 변 ≥ 40) 반투명(0.3~0.97) 판
				local tr = spec.transparency or 0
				local dims = { spec.size.x, spec.size.y, spec.size.z }
				table.sort(dims)
				t.ok(
					not (tr >= 0.3 and tr <= 0.97 and dims[1] <= 2 and dims[2] >= 40),
					`{c.id} {spec.name} looks like a fog panel ({tr}, {dims[2]}x{dims[3]})`
				)
			end
		end
	end)

	t.test("아트: 소개 카메라 점은 판정 파츠 상자 + 40 안 (IntroCamera·Decor 빼고 잼)", function()
		for _, c in CASES do
			local b = judgmentBounds(build(c.id))
			local points = c.art.introCamera()
			t.ok(#points >= 3, `{c.id} intro points`)
			for i, p in points do
				local q = p.pos
				local inside = q.x >= b.min.x - 40
					and q.x <= b.max.x + 40
					and q.y >= b.min.y - 40
					and q.y <= b.max.y + 40
					and q.z >= b.min.z - 40
					and q.z <= b.max.z + 40
				local key = `{c.id}:{i}`
				if KNOWN_INTRO_OUTSIDE[key] then
					-- 알려진 예외가 고쳐지면 이 표에서 지워요
					t.ok(not inside, `{key} is fixed — remove it from KNOWN_INTRO_OUTSIDE`)
				else
					t.ok(inside, `{key} ({q.x}, {q.y}, {q.z}) outside judgment box + 40 (z max {b.max.z})`)
				end
			end
		end
	end)

	t.test("아트: 소개 카메라 경로가 불투명 판정 파츠 속을 지나가지 않아요", function()
		for _, c in CASES do
			local model = build(c.id)
			local intro = model:FindFirstChild("IntroCamera")
			t.ok(intro ~= nil, c.id)
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
				if
					d:IsA("BasePart")
					and not under(d, model, "IntroCamera")
					and not under(d, model, "Decor")
					and d.Transparency < 0.5
				then
					table.insert(solids, d)
				end
			end
			local hits: { [string]: boolean } = {}
			for step = 0, 400 do
				local w = IntroCameraLogic.sample(path, step / 400).position
				local wp = RV3.new(w.x, w.y, w.z)
				for _, part in solids do
					if pointInPart(part, wp) then
						hits[part.Name] = true
					end
				end
			end
			local names = {}
			for name in hits do
				table.insert(names, name)
			end
			table.sort(names)
			t.eq(names, {}, `{c.id}: intro path through judgment parts`)
		end
	end)

	---------------------------------------------------------------- 3. 서버 모듈 소스
	t.test(
		"소스: build 끝 introCamera → attachStudioArt → return, MoveExempt 한 곳, 태그는 ctx.model 하위, 모듈 수준 상태 없음",
		function()
			for _, c in CASES do
				local src = fs.readFile(`src/shared/maps/{c.file}.luau`)
				local _, marks = string.gsub(src, "MoveExempt%.mark%(", "")
				t.eq(marks, 1, `{c.id} MoveExempt.mark sites`)
				local _, tagged = string.gsub(src, ":GetTagged%(", "")
				t.eq(tagged, 1, `{c.id} GetTagged sites`)
				t.ok(
					string.find(src, "ctx%.model:IsAncestorOf%(instance%)") ~= nil,
					`{c.id} tags filtered by ctx.model`
				)
				t.ok(
					string.find(
						src,
						"MapKit%.introCamera%(model, Art%.introCamera%(%), origin%)%s+MapKit%.attachStudioArt%(model, ID, origin%)%s+return model"
					) ~= nil,
					`{c.id} build ends with introCamera + attachStudioArt`
				)
				-- 레이서는 ctx.getRacers()로만 (Race 부활 대기자는 맵에 안 보여요) — Players 서비스를 직접 보지 않아요
				t.ok(string.find(src, "GetPlayers") == nil, `{c.id} no Players:GetPlayers`)
				t.ok(string.find(src, '"Players"') == nil, `{c.id} no Players service`)
				-- 모듈 수준(들여쓰기 0) 표 상태 없음
				for line in string.gmatch(src, "[^\n]+") do
					if string.match(line, "^local [%w_]+%s*:?[^=]*=%s*{%s*}") then
						t.ok(false, `{c.id} module-level table: {line}`)
					end
				end
				-- 이동 감시 면제는 넉백 함수 안에만: 연속 밀기(AssemblyLinearVelocity = velocity + unit * add) 근처에 mark 없음
				local knockAt = string.find(src, "local function knock")
				local markAt = string.find(src, "MoveExempt%.mark%(")
				t.ok(knockAt ~= nil and markAt ~= nil and markAt > knockAt, `{c.id} mark inside knock()`)
				local startAt = string.find(src, "local function start")
				t.ok(startAt ~= nil and markAt < startAt, `{c.id} no mark inside start()`)
			end
		end
	)

	---------------------------------------------------------------- 4. 점프 창
	t.test(
		"점프 창: 굴러오는 것을 마주 달려(걷기 16) 점프하면 넘을 시간 여유가 0.1초 이상",
		function()
			local cases = {
				{
					"counter bottle",
					SCLayout.BOTTLE_DIAMETER / 2 + SCLayout.HIT_PAD,
					SCLayout.BOTTLE_SPEED,
					math.min(SCLayout.HIT_FOOT, SCLayout.BOTTLE_DIAMETER - 0.5),
				},
				{
					"counter coin",
					SCLayout.COIN_DIAMETER / 2 + SCLayout.HIT_PAD,
					SCLayout.COIN_SPEED,
					math.min(SCLayout.HIT_FOOT, SCLayout.COIN_DIAMETER - 0.5),
				},
				{ "pantry can", PLayout.CAN_DIAMETER / 2 + PLayout.HIT_PAD, PLayout.CAN_SPEED, PLayout.HIT_FOOT },
			}
			for _, c in cases do
				local w = jumpWindow(c[2], c[3] + WALK, c[4])
				t.ok(w >= 0.1, `{c[1]} running jump window {w}`)
			end
		end
	)

	t.test(
		"점프 창: 연회상 낮은 벽은 마주 달려 점프하면 0.2초 이상 (가만히 서서는 0.06초 — 리포트 P2-1)",
		function()
			local half = BLayout.WALL_THICKNESS / 2 + BLayout.HIT_PAD
			local low = BLayout.KINDS.Low
			local running = jumpWindow(half, low.speed + WALK, low.height)
			t.ok(running >= 0.2, `running toward {running}`)
			-- 가만히 서서 넘는 여유(지금 약 0.06초)는 단정하지 않아요 — 리포트 m6-07 P2-1. 고친 뒤 하한(예: ≥ 0.15)을 더해요.
			-- 등지고 달아나면(벽 16 = 걷기 16) 절대 못 넘어요: 낮은 벽은 점프 말고 피할 길이 없어요
			t.eq(jumpWindow(half, low.speed - WALK, low.height), 0)
		end
	)

	---------------------------------------------------------------- 5. 회전 원판 · 연회상
	t.test(
		"회전 원판: 직사각형 조각 사이 바깥 가장자리 쐐기 틈 ≤ 1 stud, 고리 사이 틈 1.5",
		function()
			for i, ring in LLayout.RINGS do
				local rMid = (ring.inner + ring.outer) / 2
				local chord = 2 * rMid * math.sin(math.rad(LLayout.SEGMENT_DEG / 2)) * 1.06 + 0.4
				local gap = 2 * (ring.outer * math.tan(math.rad(LLayout.SEGMENT_DEG / 2)) - chord / 2)
				t.ok(gap <= 1, `ring {i} outer wedge gap {gap}`)
				if i > 1 then
					t.eq(ring.inner - LLayout.RINGS[i - 1].outer, 1.5)
				end
			end
			t.eq(LLayout.RINGS[1].inner - LLayout.CENTER_RADIUS, 0.5)
		end
	)

	t.test("회전 원판: 0~75초 내내 고리마다 열린 조각이 65% 미만 (디딜 곳 35% 넘게)", function()
		for _, ring in LLayout.RINGS do
			local worst = 0
			for step = 0, 1500 do
				local time = step * 0.05
				local open = 0
				for k = 1, LLayout.SEGMENTS do
					if LLogic.segmentState(ring, k, time) == "Open" then
						open += 1
					end
				end
				worst = math.max(worst, open / LLayout.SEGMENTS)
			end
			t.ok(worst < 0.65, `ring {ring.index} worst open {worst}`)
		end
	end)

	t.test(
		"연회상: 높은 벽 빈 칸은 판 어디서 예고를 봐도 도망치며 닿을 수 있어요 (시드 30개, 걷기 16)",
		function()
			local laneW = BLayout.TILE
			local safe = laneW / 2 - 1.5
			for seed = 1, 30 do
				local ctx = H.newCtx({}, origin, {}, seed)
				for _, sweep in BLogic.schedule(ctx.rng) do
					if sweep.kind ~= "High" then
						continue
					end
					-- 벽이 판에 닿는 시각의 판 크기 (45초 무너짐 뒤면 72)
					local half = BLogic.boardHalf(sweep.at + 1)
					local speed = BLayout.KINDS.High.speed
					for along = -half + 1, half - 1, 4 do
						for perp = -half + 1, half - 1, 4 do
							-- 가장 가까운 빈 칸 안전 띠까지 옆 거리
							local need = math.huge
							for _, lane in sweep.gaps do
								local cLane = BLayout.laneCenter(lane)
								need = math.min(need, math.max(math.abs(perp - cLane) - safe, 0))
							end
							-- 벽 진행 방향 좌표로 바꿔요 (벽이 -WALL_START에서 +로 온다고 보고)
							local a = along * sweep.dir
							-- 벽과 같은 속도로 달아나며(진행 10) 옆으로 √(16² − 10²)
							local side = math.sqrt(WALK * WALK - speed * speed)
							local tWall = BLayout.WARN
								+ (a - BLayout.WALL_THICKNESS / 2 - BLayout.HIT_PAD + BLayout.WALL_START) / speed
							-- 벽보다 먼저 판 끝에 닿기 전까지 쓸 수 있는 시간
							local room = (half - a) / speed
							local reach = math.max(WALK * tWall, side * room) -- 옆으로만 달리기 / 달아나며 옆으로
							t.ok(
								need <= reach + 1e-6,
								`seed {seed} at {sweep.at}: ({along},{perp}) needs {need} > {reach}`
							)
						end
					end
				end
			end
		end
	)
end
