--!strict
-- m5-15 "등불 다리 건너기"(lantern-bridge): 코스 치수 약속, 흔들림·미는 힘·낙하선 순수 계산, 장식 예산

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local Logic = RobloxRequire.require(Shared.maps.LanternBridgeLogic)
local Art = RobloxRequire.require(Shared.maps.LanternBridgeArt)
local LanternBridge = RobloxRequire.require(Shared.maps.LanternBridge)

local EPS = 1e-6

return function(t: Test.Test)
	t.test("AC1: 풀에 등록된 Race 맵이고 인터페이스·이름·규칙이 m5-13 그대로예요", function()
		t.eq(MapTypes.validate(LanternBridge), nil)
		t.eq(Maps.get("lantern-bridge"), LanternBridge)
		t.eq(LanternBridge.kind, "Race")
		t.eq(LanternBridge.displayName, "등불 다리 건너기")
		t.eq(LanternBridge.rule, "흔들리는 다리와 종이 등불 사이를 건너요.")
		t.eq(LanternBridge.inPool, true)
		t.eq(Maps.timeLimit(LanternBridge), Config.TimeLimit.Race)
	end)

	t.test("AC1: 스폰 24개가 출발 평지 안에서 서로 3 studs 이상 떨어져 있어요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		t.eq(#spawns, 24)
		for i, a in spawns do
			t.ok(math.abs(a.x) + 1.5 <= Layout.START_WIDTH / 2, `spawn {i} x {a.x} outside start width`)
			t.ok(a.z < Layout.START.front and a.z > Layout.START.back, `spawn {i} z {a.z} outside start`)
			for j = i + 1, #spawns do
				local b = spawns[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				t.ok(d >= 3 - EPS, `spawns {i},{j} only {d} apart`)
			end
		end
	end)

	t.test(
		"AC2: swayAmplitudeDeg은 riders에 비감소, CAP명부터 안 늘고, 항상 maxDeg 이하, riders=0도 0보다 커요",
		function()
			local maxDeg = 100 -- 넉넉히 커서 cap이 실제로 걸리는지 보여요
			local previous = -1
			for riders = 0, 24 do
				local amplitude = Logic.swayAmplitudeDeg(riders, maxDeg)
				t.ok(amplitude >= previous - EPS, `riders={riders} amplitude {amplitude} < previous {previous}`)
				previous = amplitude
			end
			t.ok(Logic.swayAmplitudeDeg(0, maxDeg) > 0, "riders=0 should still sway a little")
			local atCap = Logic.swayAmplitudeDeg(Layout.SWAY_RIDER_CAP, maxDeg)
			local pastCap = Logic.swayAmplitudeDeg(Layout.SWAY_RIDER_CAP + 10, maxDeg)
			t.eq(atCap, pastCap, "amplitude should stop growing past SWAY_RIDER_CAP")
			-- maxDeg을 넘지 않아요
			for riders = 0, 24 do
				t.ok(Logic.swayAmplitudeDeg(riders, 3) <= 3 + EPS, `riders={riders} exceeded maxDeg`)
			end
		end
	)

	t.test("AC3: 네 다리의 maxSwayDeg이 1→2→3로 낮아지다가 4에서 다시 가장 높아요", function()
		local b = Layout.BRIDGES
		t.eq(#b, 4)
		t.ok(b[1].maxSwayDeg > b[2].maxSwayDeg, "bridge1 should sway more than bridge2")
		t.ok(b[2].maxSwayDeg > b[3].maxSwayDeg, "bridge2 should sway more than bridge3")
		t.ok(b[4].maxSwayDeg > b[1].maxSwayDeg, "bridge4 should be the highest maxSwayDeg")
		t.ok(b[4].maxSwayDeg > b[2].maxSwayDeg)
		t.ok(b[4].maxSwayDeg > b[3].maxSwayDeg)
		-- 폭도 좁아지다가(1,2,3) 4에서 다시 넓어져요 (GDD 의도)
		t.ok(b[1].width > b[2].width)
		t.ok(b[2].width > b[3].width)
		t.ok(b[4].width > b[3].width)
		-- 다리마다 phase가 달라요 (같이 안 흔들려요)
		local phases = {}
		for _, bridge in b do
			t.ok(not phases[bridge.phase], `duplicate phase {bridge.phase}`)
			phases[bridge.phase] = true
		end
	end)

	t.test("AC4: 같은 riders 수에서 가장 좁은 다리(3번)가 가장 위험해요", function()
		for riders = 0, 24 do
			local amps = {}
			for _, bridge in Layout.BRIDGES do
				amps[bridge.index] = Logic.swayAmplitudeDeg(riders, bridge.maxSwayDeg)
			end
			local risk3 = Logic.fallRisk(amps[3], Layout.BRIDGES[3].halfWidth)
			for _, index in { 1, 2, 4 } do
				local risk = Logic.fallRisk(amps[index], Layout.BRIDGES[index].halfWidth)
				t.ok(
					risk3 > risk + EPS,
					`riders={riders}: bridge3 risk {risk3} should exceed bridge{index} risk {risk}`
				)
			end
		end
	end)

	t.test(
		"AC5: swayAngle은 사인파로 ±amplitude(라디안) 안에서만 움직이고 period마다 한 바퀴 돌아요",
		function()
			local amplitudeDeg = 10
			local amplitudeRad = math.rad(amplitudeDeg)
			local period = 4
			-- 극값: t = period/4에서 최대, t = 3*period/4에서 최소 (phase 0)
			t.ok(math.abs(Logic.swayAngle(period / 4, amplitudeDeg, period, 0) - amplitudeRad) < 1e-9)
			t.ok(math.abs(Logic.swayAngle(3 * period / 4, amplitudeDeg, period, 0) + amplitudeRad) < 1e-9)
			-- 주기성: t와 t + period는 같아요
			for _, t0 in { 0, 0.37, 1.5, 2.9, 3.98 } do
				t.ok(
					math.abs(
						Logic.swayAngle(t0, amplitudeDeg, period, 0.6)
							- Logic.swayAngle(t0 + period, amplitudeDeg, period, 0.6)
					) < 1e-9
				)
			end
			-- 범위를 벗어나지 않아요
			for step = 0, 400 do
				local angle = Logic.swayAngle(step / 50, amplitudeDeg, period, 1.1)
				t.ok(math.abs(angle) <= amplitudeRad + 1e-9, `angle {angle} outside ±amplitude`)
			end
		end
	)

	t.test(
		"AC6: pushSpeedFor은 0도에서 0, maxDeg에서 최고 속도, 부호가 기운 방향과 같아요",
		function()
			local maxDeg = 8
			t.eq(Logic.pushSpeedFor(0, maxDeg), 0)
			t.ok(math.abs(Logic.pushSpeedFor(math.rad(maxDeg), maxDeg) - Layout.PLANK_PUSH_SPEED) < EPS)
			t.ok(math.abs(Logic.pushSpeedFor(-math.rad(maxDeg), maxDeg) + Layout.PLANK_PUSH_SPEED) < EPS)
			t.ok(Logic.pushSpeedFor(math.rad(maxDeg / 2), maxDeg) > 0, "positive angle should push positive")
			t.ok(Logic.pushSpeedFor(-math.rad(maxDeg / 2), maxDeg) < 0, "negative angle should push negative")
		end
	)

	t.test("AC6: pushDelta는 목표 속도까지만 가속하고 줄이지 않아요", function()
		t.eq(Logic.pushDelta(0, 7, 20, 0.1), 2) -- min(20*0.1, 7-0) = 2
		t.eq(Logic.pushDelta(5, 7, 20, 0.1), 2) -- min(2, 7-5) = 2 (목표 못 넘어요)
		t.eq(Logic.pushDelta(8, 7, 20, 0.1), 0) -- 이미 목표보다 빨라요 — 줄이지 않아요
		t.eq(Logic.pushDelta(0, -7, 20, 0.1), -2)
		t.eq(Logic.pushDelta(2, 0, 20, 0.1), 0) -- target 0: 밀지 않아요(줄이지도 않아요)
	end)

	t.test("AC7: isOffPlank는 경계(±halfWidth)에서 정확히 갈려요", function()
		local halfWidth = 4
		t.eq(Logic.isOffPlank(halfWidth, halfWidth), false)
		t.eq(Logic.isOffPlank(-halfWidth, halfWidth), false)
		t.eq(Logic.isOffPlank(halfWidth + 0.001, halfWidth), true)
		t.eq(Logic.isOffPlank(-halfWidth - 0.001, halfWidth), true)
		t.eq(Logic.isOffPlank(0, halfWidth), false)
	end)

	t.test(
		"AC8: fallLineAt은 바닥(y=0)보다 일정 여유만큼 낮고, progress는 코스를 따라 단조 증가해요",
		function()
			for _, z in { 0, -14, -50, -100, -152 } do
				t.eq(Logic.fallLineAt(z), -Layout.FALL_MARGIN)
			end
			local previous = -math.huge
			for z = 0, -152, -4 do
				local p = Logic.progress(z)
				t.ok(p > previous - EPS, `progress not increasing at z={z}`)
				previous = p
			end
			t.ok(Logic.finishProgress() > Logic.progress(Layout.START.back))
		end
	)

	t.test(
		"AC9: 다리·쉼터 구간 표가 서로 안 겹치고 z 순서대로 이어지며 FinishLine이 결승 평지 안에 있어요",
		function()
			local sections = Layout.sections()
			t.eq(#sections, 9) -- 출발 + 다리4 + 쉼터3 + 결승
			t.eq(sections[1].front, 0)
			for i, span in sections do
				t.ok(span.front > span.back, `section {i} must extend toward -Z`)
				if i > 1 then
					t.eq(span.front, sections[i - 1].back, `section {i} must start where {i - 1} ends`)
				end
			end
			t.eq(Layout.totalLength(), 152)
			local finishZ = Layout.finishLineZ()
			t.ok(finishZ < Layout.FINISH.front and finishZ > Layout.FINISH.back, "finish line inside finish section")
		end
	)

	t.test("AC10: 장식이 MapKitLogic.validate를 통과하고 파츠·조명 예산 안이에요", function()
		local specs = Art.decor()
		t.eq(MapKitLogic.validate(specs), nil)
		t.ok(MapKitLogic.count(specs) <= MapKitLogic.DECOR_PART_BUDGET, "decor part budget")
		local lights = 0
		for _, spec in specs do
			if spec.name == Art.LANTERN then
				lights += 1
			end
		end
		t.eq(lights, 12)
		t.ok(lights <= MapKitLogic.LIGHT_BUDGET, "light budget")
		t.eq(#Art.introCamera(), 4)
	end)

	t.test(
		"bridgeAt은 다리 구간 안에서만 그 다리를, 쉼터·출발·결승에서는 nil을 돌려줘요",
		function()
			t.eq(Logic.bridgeAt(-2), nil) -- 출발
			t.eq((Logic.bridgeAt(-20) :: any).index, 1) -- 다리 1 안
			t.eq(Logic.bridgeAt(-39), nil) -- 쉼터 1
			t.eq((Logic.bridgeAt(-50) :: any).index, 2) -- 다리 2 안
			t.eq(Logic.bridgeAt(-73), nil) -- 쉼터 2
			t.eq((Logic.bridgeAt(-90) :: any).index, 3) -- 다리 3 안
			t.eq(Logic.bridgeAt(-103), nil) -- 쉼터 3
			t.eq((Logic.bridgeAt(-120) :: any).index, 4) -- 다리 4 안
			t.eq(Logic.bridgeAt(-145), nil) -- 결승
		end
	)
end
