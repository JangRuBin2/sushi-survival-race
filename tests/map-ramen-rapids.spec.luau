--!strict
-- m4-04 "라멘 국물 급류": 코스 치수 약속, 차슈·막대·밀기·낙하선 순수 계산, 장식 규칙

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local Logic = RobloxRequire.require(Shared.maps.RamenRapidsLogic)
local Art = RobloxRequire.require(Shared.maps.RamenRapidsArt)
local RamenRapids = RobloxRequire.require(Shared.maps.RamenRapids)

local EPS = 1e-6

local function overlaps(a: any, b: any): boolean
	return a.min.x < b.max.x
		and a.max.x > b.min.x
		and a.min.y < b.max.y
		and a.max.y > b.min.y
		and a.min.z < b.max.z
		and a.max.z > b.min.z
end

return function(t: Test.Test)
	t.test("AC1: 풀에 등록된 Race 맵이고 인터페이스·이름·규칙이 m4-01 그대로예요", function()
		t.eq(MapTypes.validate(RamenRapids), nil)
		t.eq(Maps.get("ramen-rapids"), RamenRapids)
		t.eq(RamenRapids.kind, "Race")
		t.eq(RamenRapids.displayName, "라멘 국물 급류")
		t.eq(RamenRapids.rule, "국물 급류를 타고 차슈·나루토를 밟아 건너, 결승선까지!")
		t.eq(RamenRapids.timeLimit, nil) -- Config.TimeLimit.Race (90초)
		t.eq(Maps.timeLimit(RamenRapids), Config.TimeLimit.Race)
	end)

	t.test("AC1: 구간이 출발→급류→토핑→막대→결승 순서로 이어지고 길이 약 300", function()
		local sections = Layout.sections()
		t.eq(sections[1].front, 0)
		for i, span in sections do
			t.ok(span.front > span.back, `section {i} must extend toward -Z`)
			if i > 1 then
				t.eq(span.front, sections[i - 1].back, `section {i} must start where {i - 1} ends`)
			end
		end
		t.eq(Layout.totalLength(), 300)
		local finishZ = Layout.finishLineZ()
		t.ok(finishZ < Layout.FINISH.front and finishZ > Layout.FINISH.back, "finish line inside finish section")
		-- 급류 약 12도, 출발에서 결승까지 내려가요
		t.eq(Layout.RAPIDS_SLOPE_DEG, 12)
		t.ok(Layout.platformTop() < -Layout.rapidsDrop(), "finish lower than rapids end")
		t.ok(-Layout.platformTop() >= 25, "course drops at least 25 studs")
	end)

	t.test("AC1: 스폰 24개가 출발 구간 안에서 서로 3 studs 이상 떨어져 있어요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		t.eq(#spawns, 24)
		for i, a in spawns do
			t.ok(math.abs(a.x) + 1.5 <= Layout.START_WIDTH / 2, `spawn {i} x {a.x} outside start`)
			t.ok(a.z < Layout.START.front - 1 and a.z > Layout.START.back + 1, `spawn {i} z {a.z} outside start`)
			for j = i + 1, #spawns do
				local b = spawns[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.ok(d >= 3, `spawns {i},{j} only {d} apart`)
			end
		end
	end)

	t.test("AC2: 0~60초 0.1초 간격 어느 시각이든 토핑 구간을 건너는 길이 있어요", function()
		for step = 0, 600 do
			local time = step / 10
			local path = Logic.crossingPath(time)
			t.ok(path ~= nil, `no crossing path at t={time}`)
			if path then
				t.ok(#path >= 2, `path at t={time} too short`)
				for _, platform in path do
					t.ok(Logic.platformUp(platform, time), `submerged platform in path at t={time}`)
				end
				for i = 2, #path do
					local a, b = path[i - 1], path[i]
					local gap = Logic.discGap(a.x, a.z, a.radius, b.x, b.z, b.radius)
					t.ok(gap <= Layout.MAX_JUMP_GAP, `gap {gap} at t={time}`)
				end
			end
		end
	end)

	t.test(
		"AC2: 발판끼리 겹치지 않고 토핑 구간 안에 있어요, 개수는 차슈 9 + 나루토 4",
		function()
			t.eq(#Layout.CHASHUS, 9)
			t.eq(#Layout.NARUTOS, 4)
			local platforms = Logic.platforms()
			for i, a in platforms do
				t.ok(
					a.z + a.radius <= Layout.TOPPINGS.front and a.z - a.radius >= Layout.TOPPINGS.back,
					`{a.kind}{a.index} outside toppings section`
				)
				for j = i + 1, #platforms do
					local b = platforms[j]
					t.ok(
						Logic.discGap(a.x, a.z, a.radius, b.x, b.z, b.radius) > 0.5,
						`{a.kind}{a.index} touches {b.kind}{b.index}`
					)
				end
			end
			-- 나루토만으로는 건널 수 없어요 (차슈를 꼭 밟아야 해요)
			local narutos = Layout.NARUTOS
			for i = 2, #narutos do
				local gap = Logic.discGap(
					narutos[i - 1].x,
					narutos[i - 1].z,
					Layout.NARUTO_DIAMETER / 2,
					narutos[i].x,
					narutos[i].z,
					Layout.NARUTO_DIAMETER / 2
				)
				t.ok(gap > Layout.MAX_JUMP_GAP, `naruto {i - 1} → {i} reachable without chashu`)
			end
		end
	)

	t.test(
		"QA R1: 급류 끝에서 어디로(가장자리 포함) 걸어 나가거나 점프해도 착지판 위에 1 stud 이상 여유로 떨어져요",
		function()
			local GRAVITY = 196.2
			local landing = Layout.LANDING
			-- 착지판은 급류 끝에 붙어 있고 급류보다 넓고, 발판과 겹치지 않아요
			t.eq(landing.front, Layout.RAPIDS.back)
			t.ok(landing.width >= Layout.RAPIDS_WIDTH + 2, "landing wider than the slide")
			for _, p in Logic.platforms() do
				t.ok(p.z + p.radius <= landing.back - 0.5 + 1e-9, `{p.kind}{p.index} overlaps the landing raft`)
			end
			local drop = -Layout.rapidsDrop() - Layout.narutoTop()
			t.ok(drop > 0, "landing is below the rapids end")
			local fastest = math.max(Config.Character.WalkSpeed, Layout.BROTH_PUSH_SPEED)
			local depth = landing.front - landing.back
			for speed = 0, fastest, 1 do
				for _, up in { 0, Config.Character.JumpPower } do
					local reach = Logic.landingDistance(speed, up, drop, GRAVITY)
					t.ok(reach + 1 <= depth, `speed {speed} up {up}: lands {reach} past edge (raft {depth})`)
				end
			end
			-- 옆으로: 소용돌이에 밀려 벽에 붙어 내려와도 (몸 반폭 1) 착지판 안
			t.ok(Layout.RAPIDS_WIDTH / 2 + 1 <= landing.width / 2, "slide edge inside the raft")
			-- 착지판 → 첫 줄 발판은 건널 수 있는 거리
			local nearest = math.huge
			for _, p in Logic.platforms() do
				nearest = math.min(nearest, Logic.gapFromRapids(p.x, p.z, p.radius))
			end
			t.ok(nearest <= Layout.MAX_JUMP_GAP, `first platforms {nearest} from the raft`)
		end
	)

	t.test(
		"QA R2: 급류는 걷기보다 빠르게 밀고, 소용돌이와 합쳐도 이동 감시 기준 안이에요",
		function()
			t.ok(Layout.BROTH_PUSH_SPEED > Config.Character.WalkSpeed, "push faster than walking")
			local plain = Logic.pushVector(0, -30)
			t.ok(Logic.pushDelta(Config.Character.WalkSpeed, plain.forward, Layout.BROTH_PUSH_ACCEL, 1 / 60) > 0)
			local guard = Config.MovementGuard
			local worst = 0
			for _, pool in Layout.WHIRLPOOLS do
				local push = Logic.pushVector(pool.x, pool.z)
				worst = math.max(worst, math.sqrt(push.forward ^ 2 + push.side ^ 2))
			end
			worst = math.max(worst, plain.forward)
			t.ok(worst <= guard.MaxHorizontalSpeed / 2, `push speed {worst} too close to guard limit`)
		end
	)

	t.test("AC2: 모든 차슈가 잠기는 때가 있고, 잠긴 차슈는 길에서 빠져요", function()
		for i = 1, #Layout.CHASHUS do
			local sawSubmerged, sawUp = false, false
			for step = 0, 60 do
				local time = step / 10
				if Logic.chashuSubmerged(i, time) then
					sawSubmerged = true
				else
					sawUp = true
				end
			end
			t.ok(sawSubmerged and sawUp, `chashu {i} must sink and rise`)
		end
	end)

	t.test("AC3: 차슈 높이는 주기 6초, 위아래 폭 3 (수면 아래 0.5 ~ 위 2.5)", function()
		t.eq(Layout.CHASHU_PERIOD, 6)
		for i = 1, #Layout.CHASHUS do
			local low, high = math.huge, -math.huge
			for step = 0, 600 do
				local time = step / 10
				local h = Logic.chashuHeight(i, time)
				low = math.min(low, h)
				high = math.max(high, h)
				t.ok(math.abs(h - Logic.chashuHeight(i, time + 6)) < EPS, `chashu {i} not periodic at {time}`)
			end
			t.ok(high - low <= 3 + EPS and high - low >= 3 - 0.01, `chashu {i} range {high - low}`)
			t.ok(math.abs(low - (Layout.BROTH_Y - 0.5)) < 0.01, `chashu {i} lowest {low}`)
			t.ok(math.abs(high - (Layout.BROTH_Y + 2.5)) < 0.01, `chashu {i} highest {high}`)
		end
	end)

	t.test("AC3: 두 회전 막대 각속도 40·55도/s, 방향 반대", function()
		local function degPerSec(index: number): number
			return math.deg(Logic.sweeperAngle(index, 1) - Logic.sweeperAngle(index, 0))
		end
		t.ok(math.abs(math.abs(degPerSec(1)) - 40) < EPS, `sweeper 1 {degPerSec(1)}`)
		t.ok(math.abs(math.abs(degPerSec(2)) - 55) < EPS, `sweeper 2 {degPerSec(2)}`)
		t.ok(degPerSec(1) * degPerSec(2) < 0, "sweepers must turn opposite ways")
		t.eq(#Layout.SWEEPER_LIST, 2)
	end)

	t.test("막대: 서 있으면 맞고, 점프하면 넘고, 지나간 각도 밖이면 안 맞아요", function()
		local from, to = 0, math.rad(5)
		local standing = 3 -- HumanoidRootPart가 바닥 위 약 3
		local jumpPeak = standing + (Config.Character.JumpPower ^ 2) / (2 * 196.2)
		-- 막대 방향 (cos θ, -sin θ) 위의 점
		local dx, dz = 10 * math.cos(math.rad(2)), -10 * math.sin(math.rad(2))
		t.ok(Logic.sweeperHit(dx, dz, standing, from, to), "standing in path must be hit")
		t.ok(not Logic.sweeperHit(dx, dz, jumpPeak, from, to), "jumping over must clear")
		t.ok(not Logic.sweeperHit(-10, 0, standing, from, to), "opposite side must not be hit")
		t.ok(not Logic.sweeperHit(30, 0, standing, from, to), "outside platform must not be hit")
	end)

	t.test("AC4: fallLineAt(z)는 각 구간 바닥보다 25 낮아요", function()
		t.eq(Layout.FALL_MARGIN, 25)
		t.ok(math.abs(Logic.fallLineAt(-8) - (0 - 25)) < EPS, "start")
		for _, z in { -20, -60, -100, -125 } do
			t.ok(math.abs(Logic.fallLineAt(z) - (Layout.rapidsHeightAt(z) - 25)) < EPS, `rapids {z}`)
		end
		t.ok(math.abs(Logic.fallLineAt(-160) - (Layout.narutoTop() - 25)) < EPS, "toppings")
		t.ok(math.abs(Logic.fallLineAt(-240) - (Layout.platformTop() - 25)) < EPS, "sweepers")
		t.ok(math.abs(Logic.fallLineAt(-290) - (Layout.platformTop() - 25)) < EPS, "finish")
		-- 급류 바닥은 12도로 내려가요
		local drop = Layout.rapidsHeightAt(-16) - Layout.rapidsHeightAt(-126)
		t.ok(math.abs(drop - 110 * math.tan(math.rad(12))) < EPS, `rapids drop {drop}`)
		-- 출발 → 결승 낙하선은 점점 낮아지거나 같아요 (앞 구간 낙하선이 뒤 구간 발판보다 위로 튀지 않게)
		local previous = math.huge
		for z = 0, -300, -1 do
			local line = Logic.fallLineAt(z)
			t.ok(line <= previous + EPS, `fall line rises at z={z}`)
			previous = line
		end
	end)

	t.test("AC4: 소용돌이는 3곳, 좌우 번갈아 벽 쪽으로 밀고 앞쪽 성분은 14 이하", function()
		t.eq(#Layout.WHIRLPOOLS, 3)
		t.eq(Layout.WHIRLPOOL_DIAMETER, 8)
		local previousSign = 0
		for i, pool in Layout.WHIRLPOOLS do
			t.ok(pool.z < Layout.RAPIDS.front - 4 and pool.z > Layout.RAPIDS.back + 4, `whirlpool {i} outside rapids`)
			t.ok(math.abs(pool.x) + 4 <= Layout.RAPIDS_WIDTH / 2, `whirlpool {i} outside the slide`)
			local push = Logic.pushVector(pool.x, pool.z)
			local sign = if push.side > 0 then 1 else -1
			t.eq(sign, if pool.x > 0 then 1 else -1, `whirlpool {i} must push toward its wall`)
			t.eq(math.abs(push.side), 10)
			t.ok(push.forward <= 14, `whirlpool {i} forward {push.forward}`)
			t.ok(sign ~= previousSign, `whirlpool {i} must alternate sides`)
			previousSign = sign
		end
		local plain = Logic.pushVector(0, -30)
		t.eq(plain.side, 0)
		t.eq(plain.forward, Layout.BROTH_PUSH_SPEED)
		t.eq(Logic.whirlpoolAt(0, -30), nil)
	end)

	t.test("면발 줄기 4개, 소용돌이와 겹치지 않아요", function()
		t.eq(#Layout.NOODLE_ZS, 4)
		for _, z in Layout.NOODLE_ZS do
			t.ok(z < Layout.RAPIDS.front and z > Layout.RAPIDS.back, `noodle {z} outside rapids`)
			for _, pool in Layout.WHIRLPOOLS do
				t.ok(math.abs(z - pool.z) > Layout.WHIRLPOOL_DIAMETER / 2 + 1, `noodle {z} on whirlpool`)
			end
		end
	end)

	t.test(
		"pushDelta: 목표까지만 더하고, 이미 빠르면 그대로, 거슬러 가도 막지 않아요",
		function()
			t.eq(Logic.pushDelta(0, 14, 30, 0.1), 3)
			t.eq(Logic.pushDelta(13, 14, 30, 0.1), 1)
			t.eq(Logic.pushDelta(20, 14, 30, 0.1), 0)
			t.eq(Logic.pushDelta(0, -10, 40, 0.1), -4)
			t.eq(Logic.pushDelta(-12, -10, 40, 0.1), 0)
			t.eq(Logic.pushDelta(5, 0, 40, 0.1), 0)
		end
	)

	t.test("AC5: 진행도(로컬 -Z)가 코스를 따라 단조 증가하고 결승이 가장 커요", function()
		local previous = -math.huge
		for z = 0, -300, -2 do
			local p = Logic.progress(z)
			t.ok(p > previous, `progress not increasing at z={z}`)
			previous = p
		end
		t.eq(Logic.finishProgress(), -Layout.finishLineZ())
		for _, span in Layout.sections() do
			t.ok(Logic.progress(span.front) <= Logic.finishProgress() or span == Layout.FINISH, "finish is furthest")
		end
		-- 마지막 토핑에서 첫 회전 발판까지 건널 수 있고, 회전 발판 두 개는 이어져 있어요
		local a, b = Layout.SWEEPER_LIST[1], Layout.SWEEPER_LIST[2]
		t.ok(math.abs(a.z - b.z) < Layout.PLATFORM_DIAMETER, "sweeper platforms must touch")
		t.ok(b.z - Layout.PLATFORM_DIAMETER / 2 <= Layout.FINISH.front, "finish floor must meet last platform")
		t.ok(
			Layout.FINISH.front + Layout.FINISH_FLOOR_OVERLAP
				>= b.z - math.sqrt((Layout.PLATFORM_DIAMETER / 2) ^ 2 - (Layout.FINISH_WIDTH / 2) ^ 2),
			"finish floor must overlap the last platform across its width"
		)
	end)

	t.test("AC6: 장식이 validate 통과, 600개 이하, 구간별 시야 상자와 안 겹쳐요", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, `decor {MapKitLogic.count(decor)}`)
		t.ok(#Art.steamPoints() == 3 and #Art.steamPoints() <= MapKitLogic.PARTICLE_BUDGET, "steam emitters 3")
		local volumes = Art.courseVolumes()
		t.eq(#volumes, 5)
		for i, spec in decor do
			local bounds = MapKitLogic.bounds({ spec }) :: any
			for j, volume in volumes do
				t.ok(not overlaps(bounds, volume), `decor #{i} {spec.name} overlaps course volume {j}`)
			end
		end
		-- 거대한 젓가락은 머리 위 20 이상
		for _, spec in decor do
			if spec.name == "GiantChopstick" then
				local bounds = MapKitLogic.bounds({ spec }) :: any
				t.ok(bounds.min.y >= 20, `giant chopstick at {bounds.min.y}`)
			end
		end
		-- 국물: 주황 갈색 반투명 Glass, Transparency 0.2
		local broth
		for _, spec in decor do
			if spec.name == "BrothSurface" then
				broth = spec
			end
		end
		t.ok(broth ~= nil, "broth surface decor")
		t.eq(broth.material, "Glass")
		t.eq(broth.transparency, 0.2)
	end)

	t.test("IntroCamera 4점, 끝점은 출발선 뒤 높이 12", function()
		local points = Art.introCamera()
		t.eq(#points, 4)
		local last = points[#points]
		t.eq(last.pos.y, 12)
		t.ok(last.pos.z > Layout.START.front, "last point behind start line")
	end)

	---------------------------------------------------------------- m5-20 (맵 장식 품질 패스)
	local function countNamed(specs: { any }, name: string): number
		local n = 0
		for _, spec in specs do
			if spec.name == name then
				n += 1
			end
		end
		return n
	end

	t.test("m5-20 AC3: floatingGarnish — 다시마 12 + 통깨 20 + 젓가락 받침 6 = 38, 예산 안", function()
		local decor = Art.decor()
		t.eq(countNamed(decor, "Kombu"), 12)
		t.eq(countNamed(decor, "SesameSeed"), 20)
		t.eq(countNamed(decor, "ChopstickRest"), 6)
		t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, `decor {MapKitLogic.count(decor)}`)
		-- 급류 양옆(|x| >= 30)에만 있어요 (코스 공간과 안 겹침, AC6 테스트가 다시 확인해요)
		for _, name in { "Kombu", "SesameSeed", "ChopstickRest" } do
			for _, spec in decor do
				if spec.name == name then
					t.ok(math.abs(spec.offset.x) >= 30, `{name} at x={spec.offset.x} too close to the course`)
				end
			end
		end
	end)

	t.test("m5-20 AC4: 국물 안개 패널이 구간별 시야 상자(courseVolumes)와 안 겹쳐요", function()
		local volumes = Art.courseVolumes()
		local fogCount = 0
		for i, spec in Art.decor() do
			if spec.name == Art.FOG_PANEL then
				fogCount += 1
				local bounds = MapKitLogic.bounds({ spec }) :: any
				for j, volume in volumes do
					t.ok(not overlaps(bounds, volume), `fog panel #{i} overlaps course volume {j}`)
				end
			end
		end
		t.ok(fogCount >= 3 and fogCount <= 4, `fog panel count {fogCount}`)
	end)
end
