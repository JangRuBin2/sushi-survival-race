--!strict
-- m6-04 "도시락 뚜껑 대탈출"(bento-door-dash): 대형 Race(스폰 40). 문 줄·진짜 문 고르기, 우메보시·웅덩이·회전 막대·튕김판,
-- 장식 예산·시야 상자, build 태그, 서버 start(가짜 Heartbeat): 진짜 문은 깨지고 가짜 문은 튕겨 내요.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local H = require("./lib/LargeMapHarness")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLighting = RobloxRequire.require(Shared.maps.MapLighting)
local Layout = RobloxRequire.require(Shared.maps.BentoDoorDashLayout)
local Logic = RobloxRequire.require(Shared.maps.BentoDoorDashLogic)
local Art = RobloxRequire.require(Shared.maps.BentoDoorDashArt)
local Map = RobloxRequire.require(Shared.maps.BentoDoorDash)

local RCF: any = roblox.CFrame
local EPS = 1e-6
local PATH = "src/shared/maps/BentoDoorDash.luau"

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function harness(model: any): H.Harness
	return H.new(PATH, {
		BentoDoorDashArt = Art,
		BentoDoorDashLayout = Layout,
		BentoDoorDashLogic = Logic,
		MapTypes = MapTypes,
	}, model)
end

local function seqRng(seed: number): any
	local state = seed
	return {
		NextInteger = function(_, lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + state % (hi - lo + 1)
		end,
	}
end

return function(t: Test.Test)
	t.test("등록: 풀에 든 대형 Race, capacity 40·minPlayers 12", function()
		t.eq(MapTypes.validate(Map), nil)
		t.eq(Maps.get("bento-door-dash"), Map)
		t.eq(Map.kind, "Race")
		t.eq(Map.displayName, "도시락 뚜껑 대탈출")
		t.eq(Map.capacity, Config.Maps.LargeCapacity)
		t.eq(Map.minPlayers, Config.Maps.LargeMinPlayers)
		t.eq(MapLighting.validate(Art.LIGHTING), nil)
	end)

	t.test(
		"치수: 폭 80, 문 줄 5개 × 8칸(폭 10)이 폭을 꽉 채우고, 벽은 점프로 못 넘어요",
		function()
			t.eq(Layout.WIDTH, 80)
			t.eq(#Layout.DOOR_ROWS_Z, 5)
			t.eq(Layout.DOORS_PER_ROW * Layout.DOOR_WIDTH, Layout.WIDTH)
			t.ok(Layout.WALL_HEIGHT >= 12 and Layout.SIDE_WALL_HEIGHT >= 8, "too tall to jump over")
			t.eq(Layout.REAL_DOORS, { 5, 4, 4, 3, 3 })
			for d = 1, 8 do
				local x = Layout.doorX(d)
				t.ok(math.abs(x) + Layout.DOOR_WIDTH / 2 <= Layout.HALF + EPS)
			end
			t.eq(Layout.doorX(1), -35)
			t.eq(Layout.doorX(8), 35)
			local spawns = Layout.spawnPositions()
			t.eq(#spawns, 40)
			for i, a in spawns do
				t.ok(
					a.z <= Layout.START.front and a.z >= Layout.START.back and math.abs(a.x) < Layout.HALF,
					`spawn {i}`
				)
			end
			-- 방해 구간이 문 줄 사이에 있어요
			t.ok(Layout.BALL_ZONE.front < -80 and Layout.BALL_ZONE.back > -160)
			t.ok(Layout.SOY_ZONE.front < -160 and Layout.SOY_ZONE.back > -240)
			t.ok(Layout.BAR_ZONE.front < -240 and Layout.BAR_ZONE.back > -320)
			t.ok(Layout.PAD_ZONE.front < -320 and Layout.PAD_ZONE.back > -400)
			t.ok(
				Layout.BAR_CENTER.z + Layout.BAR_RADIUS < -240 - 1
					and Layout.BAR_CENTER.z - Layout.BAR_RADIUS > -320 + 1,
				"bar clears the door walls"
			)
			t.ok(Layout.BAR_RADIUS < Layout.HALF, "bar clears the side walls")
		end
	)

	t.test("진짜 문 고르기: 줄마다 정해진 수, 매번 섞여요", function()
		local seenDifferent = false
		local first
		for seed = 1, 50 do
			local rows = Logic.pickRealDoors(seqRng(seed))
			local signature = ""
			for row, set in rows do
				local count = 0
				for door in set do
					t.ok(door >= 1 and door <= 8)
					count += 1
				end
				t.eq(count, Layout.REAL_DOORS[row], `row {row}`)
				for d = 1, 8 do
					signature ..= if set[d] then "1" else "0"
				end
			end
			first = first or signature
			if signature ~= first then
				seenDifferent = true
			end
		end
		t.ok(seenDifferent, "layouts vary between rounds")
	end)

	t.test("doorAt: 출발 쪽 면 3.5 안에서만, 문 번호는 x로", function()
		local face = -80 + 1
		t.eq({ Logic.doorAt(-35, face + 1) }, { 1, 1 })
		t.eq({ Logic.doorAt(39, face + 3) }, { 1, 8 })
		t.eq({ Logic.doorAt(0, face + 5) }, {})
		t.eq({ Logic.doorAt(0, -82) }, {}, "behind the wall")
		t.eq({ Logic.doorAt(12, -400 + 2) }, { 5, 6 })
	end)

	t.test(
		"우메보시: 슬롯이 겹치지 않고 줄·방향이 번갈아, 맞음은 반지름 + 1·발 4 미만",
		function()
			t.eq(#Logic.balls(1), 0)
			for step = 0, 400 do
				local seen = {}
				for _, b in Logic.balls(step * 0.1) do
					t.ok(not seen[b.slot])
					seen[b.slot] = true
					t.ok(math.abs(b.x) <= Layout.BALL_FROM_X + EPS)
					t.ok(table.find(Layout.BALL_Z, b.z) ~= nil)
				end
			end
			local b0 = Logic.balls(2.0)[1]
			t.eq(b0.dir, 1)
			t.ok(near(b0.x, -44, EPS))
			t.ok(Logic.ballHit(3, 0, 0))
			t.ok(not Logic.ballHit(4, 0, 0))
			t.ok(not Logic.ballHit(0, 0, 4.5), "jump clears")
		end
	)

	t.test("웅덩이: 안이면 수평 속도 9로 줄여요, 밖·공중이면 아니에요", function()
		local p = Layout.PUDDLES[1]
		t.ok(Logic.inPuddle(p.x, Layout.FOOT_OFFSET, p.z))
		t.ok(not Logic.inPuddle(p.x + 9, Layout.FOOT_OFFSET, p.z))
		t.ok(not Logic.inPuddle(p.x, Layout.FOOT_OFFSET + 5, p.z), "jumping over")
		local vx, vz = Logic.slowVelocity(0, -16)
		t.ok(near(vx, 0, EPS) and near(vz, -9, EPS))
		t.eq({ Logic.slowVelocity(3, 4) }, { 3, 4 })
	end)

	t.test(
		"회전 막대: 4초에 한 바퀴, 막대 위·점프·축 위는 안전, 미는 방향은 회전 접선",
		function()
			t.ok(near(Logic.barAngle(4), 2 * math.pi, EPS))
			-- 각도 0이면 막대가 x축: (10, 0)은 맞고, (0, 10)은 안 맞아요
			t.ok(Logic.barHit(10, 0, 0, 0))
			t.ok(not Logic.barHit(0, 10, 0, 0))
			t.ok(not Logic.barHit(10, 0, 3, 0), "jumping over")
			t.ok(not Logic.barHit(1, 0, 0, 0), "standing on the hub")
			t.ok(not Logic.barHit(31, 0, 0, 0), "beyond the tip")
			local tx, tz = Logic.barKnock(10, 0, 0)
			t.ok(near(tx, 0, EPS) and near(tz, 1, EPS), "angle grows toward +z at +x")
			local tx2, tz2 = Logic.barKnock(-10, 0, 0)
			t.ok(near(tx2, 0, EPS) and near(tz2, -1, EPS))
		end
	)

	t.test("튕김판: 원판 위 발 높이에서만", function()
		local pad = Layout.PADS[1]
		t.eq(Logic.padAt(pad.x, Layout.PAD_TOP + Layout.FOOT_OFFSET, pad.z), pad)
		t.eq(Logic.padAt(pad.x + 5, Layout.PAD_TOP + Layout.FOOT_OFFSET, pad.z), nil)
		t.eq(Logic.padAt(pad.x, Layout.PAD_TOP + Layout.FOOT_OFFSET + 4, pad.z), nil)
	end)

	t.test("길이 추정 44 ~ 60초, 낙하선은 돗자리보다 10 이상 위", function()
		local e = Logic.estimateClearTime()
		t.ok(e >= 44 and e <= 60, `estimate {e}`)
		t.ok(Art.BLANKET_Y <= Logic.fallLineAt(0) - 10)
	end)

	t.test("장식: validate·Large 예산·시야 상자 비움·소개 카메라 5개", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.eq(Art.BUDGET, "Large")
		t.eq(MapKitLogic.checkBudget(decor, "Large"), nil)
		local count = MapKitLogic.count(decor)
		t.ok(count >= 600 and count <= 2200, `decor {count}`)
		t.ok(MapKitLogic.countParticles(decor) >= 3)
		for i, spec in decor do
			local b = MapKitLogic.bounds({ spec }) :: any
			for j, volume in Art.courseVolume() do
				local overlap = b.min.x < volume.max.x
					and b.max.x > volume.min.x
					and b.min.y < volume.max.y
					and b.max.y > volume.min.y
					and b.min.z < volume.max.z
					and b.max.z > volume.min.z
				t.ok(not overlap, `decor #{i} {spec.name} overlaps course volume #{j}`)
			end
		end
		t.eq(#Art.introCamera(), 5)
	end)

	t.test(
		"build: 스폰 40개, 문 40칸 태그, 우메보시·막대는 충돌 없음, 문·벽은 충돌",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = H.build("bento-door-dash", origin)
			t.eq(#model:FindFirstChild("Spawns"):GetChildren(), 40)
			local tags: { [string]: number } = {}
			for _, d in model:GetDescendants() do
				for _, tag in d:GetTags() do
					tags[tag] = (tags[tag] or 0) + 1
				end
				if d:IsA("BasePart") then
					if d:HasTag("BentoBall") or d:HasTag("BentoBar") then
						t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name)
					elseif d:HasTag("BentoDoor") or d.Name == "BentoSideWall" then
						t.ok(d.CanCollide, d.Name)
					end
				end
			end
			t.eq(tags.BentoDoor, 40)
			t.eq(tags.BentoBall, Layout.BALL_SLOTS)
			t.eq(tags.BentoBar, 1)
		end
	)

	t.test("서버 모듈: 태그는 ctx.model 하위만, 모듈 수준 상태 없음", function()
		local source = fs.readFile(PATH)
		t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil)
		t.ok(
			string.find(source, "Logic.pickRealDoors(ctx.rng)", 1, true) ~= nil,
			"doors chosen per round on the server"
		)
		for line in string.gmatch(source, "[^\n]+") do
			if string.match(line, "^local ") and not string.match(line, "^local function") then
				local ok = string.match(line, "= require%(") ~= nil
					or string.match(line, '= "[^"]*"$') ~= nil
					or string.match(line, "^local PARK_Y = %-?%d+") ~= nil
					or string.match(line, "^local map: MapTypes") ~= nil
				t.ok(ok, `module-level state? {line}`)
			end
		end
	end)

	---------------------------------------------------------------- start
	t.test(
		"start: 진짜 문에 닿으면 깨져 열리고(소리), 가짜 문은 뒤로 튕겨 내요(면제)",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = H.build("bento-door-dash", origin)
			local h = harness(model)
			local ctx = H.newCtx(model, origin, {}, 5)
			-- 같은 rng로 진짜 문을 미리 계산해요 (start가 처음 쓰는 rng 값과 같게)
			local real = Logic.pickRealDoors(H.newCtx(model, origin, {}, 5).rng)
			local realDoor, fakeDoor
			for d = 1, 8 do
				if real[1][d] then
					realDoor = realDoor or d
				else
					fakeDoor = fakeDoor or d
				end
			end
			local face = Layout.DOOR_ROWS_Z[1] + Layout.WALL_THICKNESS / 2
			local a = H.fakeRacer(origin, Layout.doorX(realDoor), Layout.FOOT_OFFSET, face + 2)
			local b = H.fakeRacer(origin, Layout.doorX(fakeDoor), Layout.FOOT_OFFSET, face + 2)
			ctx.getRacers = function()
				return { a, b }
			end
			h.setClock(0)
			h.map.start(ctx)
			h.setClock(0.1)
			h.fire(1 / 60)
			local realPart = model:FindFirstChild(`Door1_{realDoor}`, true)
			local fakePart = model:FindFirstChild(`Door1_{fakeDoor}`, true)
			t.ok(not realPart.CanCollide and realPart.Transparency == 1, "real door broke")
			t.ok(fakePart.CanCollide and fakePart.Transparency == 0, "fake door stays")
			t.ok(table.find(h.sounds, "DoorBurst") ~= nil)
			t.ok(table.find(h.sounds, "BounceBoing") ~= nil)
			local v = origin:VectorToObjectSpace(b.root.AssemblyLinearVelocity)
			t.ok(v.Z > 10, "fake door pushes back (+z)")
			t.eq(#h.marks, 1)
			t.eq(h.marks[1].character, b.Character)
		end
	)

	t.test("start: 튕김판은 위·앞(-z)으로, 막대는 맞으면 넘어져요, 결승선 통과", function()
		local origin = RCF.new(2000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
		local model = H.build("bento-door-dash", origin)
		local h = harness(model)
		local pad = Layout.PADS[2]
		local jumper = H.fakeRacer(origin, pad.x, Layout.PAD_TOP + Layout.FOOT_OFFSET, pad.z)
		local swept = H.fakeRacer(origin, Layout.BAR_CENTER.x + 12, Layout.FOOT_OFFSET, Layout.BAR_CENTER.z)
		local finisher = H.fakeRacer(origin, 0, Layout.FOOT_OFFSET, Layout.FINISH_LINE_Z - 0.01)
		local ctx = H.newCtx(model, origin, { jumper, swept, finisher })
		h.setClock(0)
		h.map.start(ctx)
		h.setClock(0) -- 막대 각도 0 → x축
		h.fire(1 / 60)
		t.ok(ctx.passed[finisher])
		local v = origin:VectorToObjectSpace(jumper.root.AssemblyLinearVelocity)
		t.ok(v.Y > 40 and v.Z < -10, "launched up and forward")
		t.ok(not jumper.humanoid.PlatformStand, "launch does not knock down")
		t.ok(swept.humanoid.PlatformStand, "bar knocks down")
		t.ok(table.find(h.sounds, "WasabiBoing") ~= nil)
	end)
end
