--!strict
-- m3-05 QA: 우승 연출 순수 로직 경계값, SushiBody(m3-02) 인형 방향·발 높이, 카메라 시야(부두에 가리는지),
-- 그리고 클라이언트 연출 코드의 카메라 우선순위·정리·서버 타이밍을 정적으로 확인해요.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.VictoryCutsceneLogic)
local Config = RobloxRequire.require(Shared.Config)
local SushiBody = RobloxRequire.require(Shared.SushiBody)

local EPS = 1e-6

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) < (eps or EPS)
end

local function dist(a: { number }, b: { number }): number
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function stripComments(source: string): string
	local noBlock = string.gsub(source, "%-%-%[%[.-%]%]", "")
	return (string.gsub(noBlock, "%-%-[^\n]*", ""))
end

local function read(path: string): string
	return stripComments(fs.readFile(path))
end

-- 선분 a→b가 축 정렬 상자(lo~hi)를 지나가는지 (양 끝 살짝 빼고)
local function segmentHitsBox(a: { number }, b: { number }, lo: { number }, hi: { number }): boolean
	local t0, t1 = 0, 1
	for k = 1, 3 do
		local d = b[k] - a[k]
		if math.abs(d) < 1e-12 then
			if a[k] < lo[k] or a[k] > hi[k] then
				return false
			end
		else
			local u = (lo[k] - a[k]) / d
			local v = (hi[k] - a[k]) / d
			if u > v then
				u, v = v, u
			end
			t0 = math.max(t0, u)
			t1 = math.min(t1, v)
			if t0 > t1 then
				return false
			end
		end
	end
	return t1 > 0.001 and t0 < 0.999
end

-- VictoryProps의 부두 판자 전체 외곽 (장면 로컬): 폭 DockWidth, 윗면 y = 0, 두께 1, z = 0 ~ -DockLength
local function dockBox(): ({ number }, { number })
	local layout = Logic.Layout
	return { -layout.DockWidth / 2, -1, -layout.DockLength }, { layout.DockWidth / 2, 0, 0 }
end

return function(t: Test.Test)
	t.test("beatAt: 박자 경계는 다음 박자, 끝 시각은 마지막 박자 (6초, 3초)", function()
		for _, duration in { 6, 3 } do
			local s = duration / 6
			local timeline = Logic.timeline(duration)
			t.eq(Logic.beatAt(timeline, 0.8 * s), "Run", `{duration} 0.8`)
			t.eq(Logic.beatAt(timeline, 2.8 * s), "Dive", `{duration} 2.8`)
			t.eq(Logic.beatAt(timeline, 3.8 * s), "Clap", `{duration} 3.8`)
			t.eq(Logic.beatAt(timeline, duration), "Clap", `{duration} end`)
			t.eq(Logic.beatAt(timeline, duration + 1e-6), nil, `{duration} after`)
			t.eq(Logic.beatAt(timeline, -1e-6), nil, `{duration} before`)
		end
	end)

	t.test("timeline은 부를 때마다 새 표 (고쳐도 다음 호출에 안 남아요)", function()
		local a = Logic.timeline(6)
		a[1].finish = 99
		t.ok(near(Logic.timeline(6)[1].finish, 0.8), "원본 그대로")
	end)

	t.test("서버 타이밍: VictoryDuration 10 = 연출 6 + 순위표 4", function()
		t.eq(Config.Match.VictoryCutscene, 6)
		t.eq(Config.Match.VictoryDuration, 10)
		t.ok(Config.Match.VictoryDuration - Config.Match.VictoryCutscene >= 3, "순위표가 3초 이상 보여요")
		t.eq(Logic.BASE_DURATION, Config.Match.VictoryCutscene)
	end)

	t.test("인형 자세는 박자 경계에서 순간이동하지 않아요", function()
		local function pos(tt: number)
			return Logic.dollPose(tt, 6).position
		end
		for _, boundary in { 0.8, 2.8, Logic.splashTime(6), 3.8 } do
			local before = pos(boundary - 1e-4)
			local after = pos(boundary)
			t.ok(dist(before, after) < 0.05, `t = {boundary}: {dist(before, after)}`)
		end
		-- 박수 시작에 고개를 돌리는 yaw도 0에서 이어져요
		t.ok(near(Logic.dollPose(3.8, 6).yaw, 0), "Clap 시작 yaw 0")
	end)

	t.test("다이빙 입수 위치는 부두 끝을 지난 바다 위", function()
		local layout = Logic.Layout
		t.ok(layout.DiveLandZ < -layout.DockLength, "부두 끝보다 앞")
		t.ok(layout.WaterY < 0, "수면은 부두보다 아래")
	end)

	t.test("m3-02 SushiBody: GROUND_OFFSET = 발바닥까지 거리, 앞(눈) = -Z", function()
		local layout = SushiBody.layout(Config.Appearance.Default)
		local bounds = SushiBody.bounds(layout)
		t.ok(
			near(SushiBody.GROUND_OFFSET, -bounds.min[2]),
			`GROUND_OFFSET {SushiBody.GROUND_OFFSET} vs {-bounds.min[2]}`
		)
		local eyes = 0
		for _, spec in layout do
			if string.find(spec.name, "Eye") or spec.name == "Mouth" then
				eyes += 1
				t.ok(spec.offset[3] < 0, `{spec.name}는 -Z 쪽`)
			end
		end
		t.ok(eyes >= 2, "눈·입 파츠가 있어요")
	end)

	t.test("박수 때 인형 얼굴이 카메라 쪽 (yaw pi로 -Z 앞 → +Z, 카메라는 +Z 쪽)", function()
		for _, tt in { 4.6, 5.2, 5.9 } do
			local pose = Logic.dollPose(tt, 6)
			-- yaw 회전 뒤 앞(-Z)의 z 성분: -cos(yaw)
			local facingZ = -math.cos(pose.yaw)
			local cam = Logic.cameraPose(tt, 6)
			local toCameraZ = cam.eye[3] - pose.position[3]
			t.ok(facingZ > 0.9 and toCameraZ > 0, `t = {tt}`)
		end
	end)

	t.test("박수 때 인형 눈은 수면 위로 나와요", function()
		local eyeHeight = 0
		for _, spec in SushiBody.layout(Config.Appearance.Default) do
			if spec.name == "EyeLeft" then
				eyeHeight = spec.offset[2]
			end
		end
		local pose = Logic.dollPose(5.5, 6)
		local eyeY = pose.position[2] + SushiBody.GROUND_OFFSET + eyeHeight
		t.ok(eyeY > Logic.Layout.WaterY, `눈 y {eyeY} > 수면 {Logic.Layout.WaterY}`)
	end)

	-- QA B1: 박수 장면 카메라(눈 y = WaterY + 6 = 1, z = DiveLandZ + 17 = -23)가 부두(윗면 y 0, z 0 ~ -30) 바로 위에
	-- 있어서, 카메라 → 인형(z -40, 수면 근처) 시선이 부두 끝 판자에 가려요. 고치면 통과해야 해요.
	t.test("QA B1: 박수 장면에서 카메라 → 인형 머리 시선이 부두에 가리지 않아요", function()
		local lo, hi = dockBox()
		local blocked = {}
		for step = 0, 22 do
			local tt = 3.8 + step * 0.1
			local pose = Logic.dollPose(tt, 6)
			local head = { pose.position[1], pose.position[2] + SushiBody.GROUND_OFFSET + 1.0, pose.position[3] }
			local cam = Logic.cameraPose(tt, 6)
			if segmentHitsBox(cam.eye, head, lo, hi) then
				table.insert(blocked, string.format("%.1f", tt))
			end
		end
		t.eq(#blocked, 0, `가려진 시각: {table.concat(blocked, ", ")}`)
	end)

	t.test("DoorBurst·Run·Dive 카메라 시선은 부두에 가리지 않아요", function()
		local lo, hi = dockBox()
		for step = 0, 37 do
			local tt = step * 0.1
			local pose = Logic.dollPose(tt, 6)
			local head = { pose.position[1], pose.position[2] + SushiBody.GROUND_OFFSET + 1.0, pose.position[3] }
			if head[2] > 0 then
				local cam = Logic.cameraPose(tt, 6)
				t.ok(not segmentHitsBox(cam.eye, head, lo, hi), `t = {tt}`)
			end
		end
	end)

	t.test("정적: 카메라 우선순위 VictoryCutscene(50)가 가장 높고 Victory(20)보다 위", function()
		local source = read("src/client/CameraDirector.luau")
		local function priority(name: string): number
			local value = string.match(source, name .. "%s*=%s*(%d+)")
			assert(value, name)
			return tonumber(value) :: number
		end
		t.eq(priority("VictoryCutscene"), 50)
		t.eq(priority("Victory"), 20)
		for _, other in { "Spectate", "Victory", "Intro", "Elimination" } do
			t.ok(priority("VictoryCutscene") > priority(other), other)
		end
	end)

	t.test("정적: 연출 컨트롤러가 정리 경로를 모두 가져요", function()
		local source = read("src/client/fx/VictoryCutsceneController.luau")
		t.ok(string.find(source, "CameraDirector.release(OWNER)", 1, true) ~= nil, "카메라 release")
		t.ok(
			string.find(source, "CameraDirector.Priority.VictoryCutscene", 1, true) ~= nil,
			"우선순위 VictoryCutscene"
		)
		t.ok(string.find(source, "screen:hide()", 1, true) ~= nil, "글씨 숨김")
		t.ok(string.find(source, "cleanup:add(props.model)", 1, true) ~= nil, "장면 Model 정리")
		t.ok(string.find(source, '"Starting"', 1, true) ~= nil, "새 Starting에 정리")
		t.ok(string.find(source, "RoomUpdated", 1, true) ~= nil, "대기실 복귀에 정리")
		t.ok(string.find(source, 'state ~= "InMatch"', 1, true) ~= nil, "InMatch 아니면 정리")
		t.ok(string.find(source, "t >= duration", 1, true) ~= nil, "시간 끝에 정리")
		t.ok(string.find(source, "isActive(OWNER)", 1, true) ~= nil, "밀렸을 때 카메라를 건드리지 않음")
	end)

	t.test("정적: 연출 코드는 서버·리모트 호출·공용 상태를 건드리지 않아요", function()
		for _, path in
			{
				"src/client/fx/VictoryCutsceneController.luau",
				"src/client/fx/VictoryCutsceneScreen.luau",
				"src/client/fx/VictoryProps.luau",
			}
		do
			local source = read(path)
			t.ok(string.find(source, "FireServer", 1, true) == nil, `{path} FireServer`)
			t.ok(string.find(source, "InvokeServer", 1, true) == nil, `{path} InvokeServer`)
			t.ok(string.find(source, "Remotes.fn", 1, true) == nil, `{path} Remotes.fn`)
		end
	end)

	t.test(
		"정적: 서버는 우승자가 있을 때만 Victory를 보내고 VictoryDuration만큼 기다려요",
		function()
			local source = read("src/server/MatchService.luau")
			t.ok(string.find(source, "if winnerUserId then", 1, true) ~= nil, "우승자 있을 때만")
			t.ok(
				string.find(source, "task.wait(Config.Match.VictoryDuration)", 1, true) ~= nil,
				"VictoryDuration 대기"
			)
		end
	)

	t.test(
		"정적: HUD는 우승자가 있으면 VictoryCutscene초 뒤에, 토큰·root.Visible을 확인하고 띄워요",
		function()
			local source = read("src/client/ui/HudScreen.luau")
			t.ok(string.find(source, "task.delay(Config.Match.VictoryCutscene", 1, true) ~= nil, "연출 뒤 지연")
			t.ok(string.find(source, "victoryToken == mine and root.Visible", 1, true) ~= nil, "토큰·표시 확인")
			local _, bumps = string.gsub(source, "victoryToken %+= 1", "")
			t.eq(bumps, 2, "setPhase·setVisible(false)에서 토큰 증가")
		end
	)
end
