--!strict
-- m3-05 우승 연출: 박자 타임라인, 효과음, 큰 글씨, 인형·카메라 위치 (VictoryCutsceneLogic)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Logic = RobloxRequire.require(Shared.VictoryCutsceneLogic)
local Config = RobloxRequire.require(Shared.Config)
local SfxCues = RobloxRequire.require(Shared.SfxCues)

local ORDER = { "DoorBurst", "Run", "Dive", "Clap" }

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return function(t: Test.Test)
	t.test("AC1: timeline(6) 순서, 경계가 이어지고 0에서 6까지", function()
		local timeline = Logic.timeline(6)
		t.eq(#timeline, 4)
		for i, beat in timeline do
			t.eq(beat.name, ORDER[i])
			t.ok(beat.finish > beat.start, `{beat.name} 길이 > 0`)
			if i < #timeline then
				t.ok(near(beat.finish, timeline[i + 1].start), `{beat.name} 끝 = 다음 시작`)
			end
		end
		t.ok(near(timeline[1].start, 0), "첫 시작 0")
		t.ok(near(timeline[4].finish, 6), "마지막 끝 6")
	end)

	t.test("AC1: 6초 기준 박자 시각이 스펙 표와 같아요", function()
		local timeline = Logic.timeline(6)
		local expected = { { 0, 0.8 }, { 0.8, 2.8 }, { 2.8, 3.8 }, { 3.8, 6 } }
		for i, beat in timeline do
			t.ok(near(beat.start, expected[i][1]) and near(beat.finish, expected[i][2]), beat.name)
		end
	end)

	t.test("AC2: timeline(3)은 같은 순서, 모든 시각이 절반", function()
		local full = Logic.timeline(6)
		local half = Logic.timeline(3)
		t.eq(#half, #full)
		for i, beat in half do
			t.eq(beat.name, full[i].name)
			t.ok(near(beat.start, full[i].start / 2), `{beat.name} start`)
			t.ok(near(beat.finish, full[i].finish / 2), `{beat.name} finish`)
		end
	end)

	t.test("AC3: beatAt", function()
		local timeline = Logic.timeline(6)
		t.eq(Logic.beatAt(timeline, 0), "DoorBurst")
		t.eq(Logic.beatAt(timeline, 0.8), "Run")
		t.eq(Logic.beatAt(timeline, 2), "Run")
		t.eq(Logic.beatAt(timeline, 3.0), "Dive")
		t.eq(Logic.beatAt(timeline, 5.99), "Clap")
		t.eq(Logic.beatAt(timeline, 6), "Clap")
		t.eq(Logic.beatAt(timeline, -0.1), nil)
		t.eq(Logic.beatAt(timeline, 6.1), nil)
	end)

	t.test("AC4: titleText", function()
		t.eq(Logic.titleText("민수", false), "민수 탈출 성공!")
		t.eq(Logic.titleText("민수", true), "탈출 성공! 🏆")
	end)

	t.test("AC4: winnerName은 standings 이름을 먼저 써요", function()
		local standings = { { userId = 1, name = "민수", place = 1 }, { userId = 2, name = "지아", place = 2 } }
		t.eq(Logic.winnerName(standings, 1, "#1"), "민수")
		t.eq(Logic.winnerName(standings, 3, "#3"), "#3")
		t.eq(Logic.winnerName(nil, 1, "민수2"), "민수2")
	end)

	t.test("AC5: 연출 길이 < 우승 단계 길이, 효과음 이름", function()
		t.ok(Config.Match.VictoryCutscene < Config.Match.VictoryDuration, "VictoryCutscene < VictoryDuration")
		for _, name in { "VictoryFanfare", "DoorBurst", "Splash", "FishClap" } do
			t.ok(SfxCues.isEffect(name), name)
		end
	end)

	t.test("cues: 모두 SfxCues 효과음이고, 시각 순서이며, 연출 안에 있어요", function()
		local duration = Config.Match.VictoryCutscene
		local cues = Logic.cues(duration)
		local timeline = Logic.timeline(duration)
		local last = -1
		for _, cue in cues do
			t.ok(SfxCues.isEffect(cue.name), cue.name)
			t.ok(cue.at >= last, `{cue.name} 순서`)
			t.ok(cue.at >= 0 and cue.at < duration, `{cue.name} 시각`)
			last = cue.at
		end
		local byName = {}
		for _, cue in cues do
			byName[cue.name] = cue.at
		end
		t.eq(Logic.beatAt(timeline, byName.Splash), "Dive")
		t.eq(Logic.beatAt(timeline, byName.FishClap), "Clap")
		t.eq(byName.VictoryFanfare, 0)
		t.eq(byName.DoorBurst, 0)
	end)

	t.test(
		"인형: 가게 안에서 출발해 부두를 지나 물속으로, 박수 때는 고개만 내밀어요",
		function()
			local layout = Logic.Layout
			local start = Logic.dollPose(0, 6)
			t.ok(start.position[3] > 0, "가게 안(문 뒤)에서 출발")
			local runEnd = Logic.dollPose(2.79, 6)
			t.ok(runEnd.position[3] < 0 and runEnd.position[3] > -layout.DockLength, "Run 끝은 부두 위")
			t.ok(runEnd.position[2] >= 0, "부두 위에서는 바닥 위")
			local splash = Logic.dollPose(Logic.splashTime(6), 6)
			t.ok(near(splash.position[2], layout.WaterY), "입수 순간 수면 높이")
			t.ok(near(splash.position[3], layout.DiveLandZ), "입수 위치")
			local clap = Logic.dollPose(5.5, 6)
			t.ok(
				clap.position[2] < layout.WaterY and clap.position[2] > layout.WaterY - 4,
				"박수 때 수면 바로 아래 발"
			)
			t.ok(near(clap.yaw, math.pi), "박수 때 가게(카메라) 쪽을 봐요")
			-- 범위 밖 시각도 안전
			t.ok(Logic.dollPose(-1, 6).position[3] > 0, "t < 0")
			t.ok(near(Logic.dollPose(10, 6).position[3], layout.DiveLandZ), "t > duration")
		end
	)

	t.test("인형 위치는 시간에 비례: dollPose(t, 3) = dollPose(2t, 6)", function()
		for _, base in { 0.3, 1.5, 3.1, 3.6, 5 } do
			local a = Logic.dollPose(base / 2, 3).position
			local b = Logic.dollPose(base, 6).position
			t.ok(near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3]), `t = {base}`)
		end
	end)

	t.test("문 열림 0 → 1, 물고기는 Clap 전에는 물속", function()
		t.eq(Logic.doorOpen(0, 6), 0)
		t.eq(Logic.doorOpen(1, 6), 1)
		local rise, clap = Logic.fishState(3, 6, 1)
		t.eq(rise, 0)
		t.eq(clap, 0)
		local riseLate = Logic.fishState(5.5, 6, 1)
		t.eq(riseLate, 1)
		local ring = Logic.fishRing(5, 6)
		t.eq(#ring, 5)
		for _, offset in ring do
			t.ok(near(math.sqrt(offset[1] ^ 2 + offset[2] ^ 2), 6), "반지름")
		end
	end)

	t.test("카메라: 눈과 대상이 겹치지 않고, 박수 때는 인형 앞(가게 쪽)에서 봐요", function()
		for step = 0, 60 do
			local pose = Logic.cameraPose(step / 10, 6)
			local dx = pose.eye[1] - pose.target[1]
			local dy = pose.eye[2] - pose.target[2]
			local dz = pose.eye[3] - pose.target[3]
			t.ok(math.sqrt(dx * dx + dy * dy + dz * dz) > 5, `t = {step / 10}`)
		end
		local clap = Logic.cameraPose(6, 6)
		t.ok(clap.eye[3] > Logic.Layout.DiveLandZ, "인형보다 가게 쪽")
		t.ok(clap.eye[2] > Logic.Layout.WaterY, "수면 위")
	end)

	t.test("장면 위치는 로비·아레나와 멀어요", function()
		local origin = Logic.SCENE_ORIGIN
		t.eq(#origin, 3)
		t.ok(origin[2] > Config.Arena.BaseHeight + 500, "아레나보다 훨씬 위")
		t.ok(math.abs(origin[3]) >= 2000, "로비에서 멀리")
	end)
end
