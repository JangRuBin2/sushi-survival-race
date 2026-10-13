--!strict
-- m5-15 QA(docs/qa/m5-15-map-lantern-bridge.md): 스폰·구간 폭, 기운 다리 가장자리 높이, 이동 감시 여유,
-- 서버 코드 점검. (미는 방향이 오르막 쪽인 B1은 리포트 참고 — 실패 테스트로 넣지 않음)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local Logic = RobloxRequire.require(Shared.maps.LanternBridgeLogic)

local SOURCE_PATH = "src/shared/maps/LanternBridge.luau"
local BODY_HALF_WIDTH = 1

local function countMatches(source: string, pattern: string): number
	local n = 0
	for _ in string.gmatch(source, pattern) do
		n += 1
	end
	return n
end

return function(t: Test.Test)
	t.test("m5-15 QA: 스폰 24개는 출발 평지 폭 안(몸 반폭 여유)이고 출발 구간 안", function()
		local positions = Layout.spawnPositions()
		t.eq(#positions, 24)
		for i, pos in positions do
			t.ok(math.abs(pos.x) + BODY_HALF_WIDTH <= Layout.START_WIDTH / 2, `spawn {i} x {pos.x}`)
			t.ok(pos.z < Layout.START.front and pos.z >= Layout.START.back + BODY_HALF_WIDTH, `spawn {i} z {pos.z}`)
		end
	end)

	t.test("m5-15 QA: 다리는 앞뒤 평지보다 좁아요 (다리 폭 바깥 = 낙하)", function()
		for _, bridge in Layout.BRIDGES do
			t.eq(bridge.halfWidth * 2, bridge.width, `bridge {bridge.index} halfWidth`)
			t.eq(bridge.front - bridge.back, bridge.length, `bridge {bridge.index} length`)
			t.ok(bridge.width < Layout.START_WIDTH and bridge.width < Layout.FINISH_WIDTH)
			for _, rest in Layout.RESTS do
				t.ok(bridge.width <= rest.width, `bridge {bridge.index} vs {rest.name}`)
			end
		end
	end)

	t.test("m5-15 QA: 다리가 최대로 기울어도 가장자리는 낙하선보다 한참 위", function()
		for _, bridge in Layout.BRIDGES do
			local edgeDrop = bridge.halfWidth * math.sin(math.rad(bridge.maxSwayDeg)) + Layout.FLOOR_THICKNESS
			t.ok(-edgeDrop > Logic.fallLineAt(bridge.front) + 10, `bridge {bridge.index} edge`)
		end
	end)

	t.test(
		"m5-15 QA: 혼자(1명)여도 기본보다 더 흔들리고, 최대 인원에서도 maxSwayDeg에서 멈춰요",
		function()
			for _, bridge in Layout.BRIDGES do
				local one = Logic.swayAmplitudeDeg(1, bridge.maxSwayDeg)
				t.ok(one >= Logic.swayAmplitudeDeg(0, bridge.maxSwayDeg))
				t.eq(Logic.swayAmplitudeDeg(24, bridge.maxSwayDeg), bridge.maxSwayDeg)
				-- 각도 → 미는 속도는 maxSwayDeg에서 정확히 PLANK_PUSH_SPEED
				local peak = Logic.swayAngle(Layout.SWAY_PERIOD / 4, bridge.maxSwayDeg, Layout.SWAY_PERIOD, 0)
				t.ok(math.abs(Logic.pushSpeedFor(peak, bridge.maxSwayDeg) - Layout.PLANK_PUSH_SPEED) < 1e-6)
			end
		end
	)

	t.test(
		"m5-15 QA: 걷기 + 미는 힘 최고 속도는 이동 감시 수평 상한보다 한참 작아요 (MoveExempt 없이 안전)",
		function()
			local worst = Config.Character.WalkSpeed + Layout.PLANK_PUSH_SPEED
			t.ok(worst * 2 < Config.MovementGuard.MaxHorizontalSpeed, `walk+push {worst}`)
		end
	)

	t.test(
		"m5-15 QA 서버: 태그는 ctx.model 하위만, 모듈 수준 가변 상태 없음, MoveExempt·리모트 없음",
		function()
			local source = fs.readFile(SOURCE_PATH)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil, "filters by ctx.model")
			t.eq(countMatches(source, "GetTagged%("), 1)
			t.eq(countMatches(source, "MoveExempt%.mark"), 0) -- 연속 밀기라 면제 없음 (주석에만 언급)
			t.eq(countMatches(source, "require%(script%.Parent%.Parent%.MoveExempt%)"), 0)
			t.eq(countMatches(source, "OnServerEvent"), 0)
			for line in string.gmatch(source, "[^\n]+") do
				if string.match(line, "^local ") and not string.match(line, "^local function ") then
					local ok = string.find(line, "require(", 1, true)
						or string.match(line, '^local [%u_]+ = [%d%.%-"]')
						or string.match(line, "^local MAX_PLAYERS = Config%.Room%.MaxPlayerOptions")
						or string.match(line, "^local map: MapTypes%.MapModule")
					t.ok(ok, `module-level state? {line}`)
				end
			end
		end
	)

	t.test("m5-15 QA 서버: 판정은 ctx.pass/ctx.eliminate만, 연결은 ctx.cleanup 하나", function()
		local source = fs.readFile(SOURCE_PATH)
		t.eq(countMatches(source, "ctx%.pass%("), 1)
		t.eq(countMatches(source, "ctx%.eliminate%("), 1)
		t.eq(countMatches(source, ":Connect%("), 1)
		t.eq(countMatches(source, "task%.spawn%(") + countMatches(source, "task%.delay%("), 0)
		t.ok(string.find(source, "ctx.cleanup:add(RunService.Heartbeat:Connect(", 1, true) ~= nil)
		-- 판정 뒤 라운드가 끝났으면 바로 빠져요 (끝난 라운드에 밀기 안 함)
		t.ok(string.find(source, "if not ctx.isActive() then\n\t\t\t\t\treturn", 1, true) ~= nil)
	end)
end
