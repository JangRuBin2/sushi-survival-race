--!strict
-- m5-32 QA 회귀 테스트: 개발 테스트(m5-32-fresh-mackerel)가 다루지 않는 경계값.
--   상태가 겹치는 자세(팔딱 중 점프, 착지 팔딱 중 다시 점프, 팔딱 중 달리기, 넘어지는 중 팔딱)에서도 모양 한도,
--   뒷몸(midYaw)·비틀림 진동수 ≤ 7 Hz, 소리 간격이 캐릭터마다 따로이고 경계(0.25초 정확히)에서 울림,
--   소리 id가 비어 있음(무음), 뽑기 확률 합 1·전설 1개, 카탈로그에서 고등어만 conceptBody + robux.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local fs = require("@lune/fs")
local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local SushiPose = RobloxRequire.require(Shared.SushiPose)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)

local ID = "fresh-mackerel"
local F = Anim.FISH
local DEG = math.pi / 180
local RICE_TOP = 1.0
local RICE_FRONT = -1.35
-- 이 스킨만 이름표가 높아요 (사용자 결정 2026-10-14 4차): 쉰 꼭대기 ≤ TAG − 0.4, 팔딱 꼭대기 ≤ TAG
local TAG = SushiBody.nameTagHeight(ID)

local SALMON_BOUNDS = SushiBody.bounds(SushiBody.layout("concept-salmon"))
local MAX_X = (SALMON_BOUNDS.max[1] - SALMON_BOUNDS.min[1]) * 1.25
local MAX_Z = (SALMON_BOUNDS.max[3] - SALMON_BOUNDS.min[3]) * 1.25

local function standing(time: number, overrides: { [string]: any }?): any
	local input: any = {
		time = time,
		walk = 0,
		phase = 0,
		riseSpeed = 0,
		airborne = false,
		landTime = nil,
		landStrength = 0,
		knocked = false,
		flopTime = nil,
		mode = "Character",
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function isFishPart(name: string): boolean
	return string.sub(name, 1, 4) == "Fish" or string.sub(name, 1, 6) == "Splash"
end

-- 클라이언트 상태 기계(CharacterFxController.updateFish)에서 실제로 생길 수 있는 겹침:
--   팔딱은 점프·달리기·넘어짐이 시작돼도 끝까지 이어져요(새로 시작만 막음), 착지 팔딱 중 다시 점프하면 landTime이 공중에서 이어져요.
local function comboPoses(): { { name: string, pose: any } }
	local list = {}
	local t = 0
	while t < 0.6 do
		for _, rise in { 10, 30, 60 } do
			table.insert(list, {
				name = `flop+jump {rise} {t}`,
				pose = Anim.fishPose(standing(t, { flopTime = t, airborne = true, riseSpeed = rise })),
			})
			table.insert(list, {
				name = `land+jump {rise} {t}`,
				pose = Anim.fishPose(
					standing(t, { landTime = t, landStrength = 1, airborne = true, riseSpeed = rise })
				),
			})
		end
		table.insert(list, {
			name = `flop+run {t}`,
			pose = Anim.fishPose(standing(t, { flopTime = t, walk = 1.3, phase = t * 15.5 })),
		})
		for _, k in { 0.25, 0.5, 0.75 } do
			table.insert(list, {
				name = `flop+knock {k} {t}`,
				pose = Anim.fishPose(standing(t, { flopTime = t, knocked = true, blend = { knock = k, air = 0 } })),
			})
		end
		for _, mode in { "Victory", "Preview", "Hurt", "Idle" } do
			table.insert(list, {
				name = `{mode} flop {t}`,
				pose = Anim.fishPose(
					standing(t, { flopTime = math.min(t, Anim.flopDuration(mode) - 0.001), mode = mode })
				),
			})
		end
		t += 1 / 60
	end
	return list
end

return function(t: Test.Test)
	t.test(
		"QA: 겹친 상태(팔딱+점프, 착지+재점프, 팔딱+달리기, 팔딱+넘어짐, 인형 모드)에서도 값 한도",
		function()
			local eps = 1e-6
			for _, item in comboPoses() do
				local p = item.pose
				t.ok(math.abs(p.tailYaw) <= F.MAX_TAIL + eps, `{item.name} tail {p.tailYaw / DEG}`)
				t.ok(math.abs(p.midYaw) <= F.MAX_MID + eps, `{item.name} mid`)
				t.ok(math.abs(p.rootArch) <= F.MAX_ARCH + eps, `{item.name} root arch`)
				t.ok(math.abs(p.midArch + p.tailArch) <= F.MAX_ARCH + eps, `{item.name} bend`)
				t.ok(p.rootLift >= 0 and p.rootLift <= F.MAX_LIFT + eps, `{item.name} lift`)
				t.ok(p.splash >= 0 and p.splash <= 1, `{item.name} splash`)
			end
		end
	)

	t.test(
		"QA: 겹친 상태 자세에서도 꼭대기 ≤ 이름표(4차 결정 4.8), 외곽 ×1.25, 발바닥, 얼굴 안 가림, 밥 윗면 − 0.2 위 (표정 6종)",
		function()
			local poses = comboPoses()
			for _, expression in Sample.EXPRESSIONS do
				local base = SushiBody.layout(ID, expression)
				for _, item in poses do
					local label = `{expression}/{item.name}`
					local layout = SushiPose.posed(base, Anim.fishMotion(item.pose))
					local b = SushiBody.bounds(layout)
					t.ok(b.max[2] <= TAG + 1e-9, `{label} top {b.max[2]}`)
					t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) <= 1e-9, `{label} sole`)
					t.ok(b.max[1] - b.min[1] <= MAX_X + 1e-9, `{label} x`)
					t.ok(b.max[3] - b.min[3] <= MAX_Z + 1e-9, `{label} z`)
					for _, spec in layout do
						if isFishPart(spec.name) then
							local lo = LayoutCheck.box(spec)
							t.ok(lo[2] >= RICE_TOP - 0.2 - 1e-6, `{label} {spec.name} low {lo[2]}`)
							if lo[2] < RICE_TOP then
								t.ok(lo[3] >= RICE_FRONT - 1e-6, `{label} {spec.name} covers face`)
							end
						end
					end
				end
			end
		end
	)

	t.test("QA: 뒷몸(midYaw)·꼬리 진동수 ≤ 7 Hz — 모든 모드, 착지+재점프 포함", function()
		local function maxHz(key: string, make: (number) -> any, duration: number): number
			local crossings = {}
			local prev = nil
			local time = 0
			while time <= duration do
				local v = (Anim.fishPose(make(time)) :: any)[key]
				if prev ~= nil and ((prev < 0 and v >= 0) or (prev > 0 and v <= 0)) then
					table.insert(crossings, time)
				end
				prev = v
				time += 1 / 600
			end
			local best = 0
			for i = 2, #crossings do
				local gap = crossings[i] - crossings[i - 1]
				if gap > 1e-6 then
					best = math.max(best, 1 / (2 * gap))
				end
			end
			return best
		end
		local cases = {
			{
				"knock",
				function(x)
					return standing(x, { knocked = true })
				end,
				2,
			},
			{
				"flop",
				function(x)
					return standing(x, { flopTime = x })
				end,
				F.FLOP_TIME,
			},
			{
				"land+jump",
				function(x)
					return standing(x, { landTime = x, landStrength = 1, airborne = true, riseSpeed = 30 })
				end,
				F.LAND_DELAY + F.LAND_TIME,
			},
			{
				"victory",
				function(x)
					return standing(x, { flopTime = x, mode = "Victory" })
				end,
				F.FLOP_TIME,
			},
			{
				"run",
				function(x)
					return standing(x, { walk = 1.3, phase = x * (9 + 5 * 1.3) })
				end,
				2,
			},
		}
		for _, case in cases do
			for _, key in { "midYaw", "tailYaw" } do
				local hz = maxHz(key, case[2] :: any, case[3] :: number)
				t.ok(hz <= F.MAX_HZ * 1.03, `{case[1]} {key} {hz} Hz`)
			end
		end
	end)

	t.test(
		"QA: 소리 간격은 캐릭터마다 따로, 0.25초 정확히는 울림, 살랑·경련·달리기에는 큐 없음",
		function()
			local a, b = {}, {}
			t.eq(Anim.fishSoundFilter(a, { "FishFlop", "FishSplash" }, 10), { "FishFlop", "FishSplash" })
			-- 다른 캐릭터(표 b)는 a와 상관없이 울려요
			t.eq(Anim.fishSoundFilter(b, { "FishFlop" }, 10.01), { "FishFlop" })
			t.eq(Anim.fishSoundFilter(a, { "FishFlop", "FishSplash" }, 10.249), {})
			t.eq(Anim.fishSoundFilter(a, { "FishFlop" }, 10 + F.SOUND_GAP), { "FishFlop" })
			-- 막힌 큐는 시각을 갱신하지 않아요 (계속 막히는 일 없음)
			t.eq(Anim.fishSoundFilter(a, { "FishSplash" }, 10.26), { "FishSplash" })
			t.eq(F.SOUND_GAP, 0.25)
			-- 큐는 팔딱 시작·착지에서만: Hurt는 없음
			t.eq(Anim.fishCues("Flop", "Hurt", nil, 0), {})
			t.eq(Anim.fishCues("Land", "Hurt", nil, 0.1), {})
			t.eq(Anim.fishCues("Flop", "Victory", nil, 0), { "FishFlop" })
			t.eq(Anim.fishCues("Land", "Character", 0.07, 0.09), { "FishFlop", "FishSplash" })
			t.eq(Anim.fishCues("Land", "Character", 0.09, 0.11), {})
			-- 한 팔딱(0.6초)을 1/60초로 돌려도 FishFlop·FishSplash가 한 번씩만
			local counts: { [string]: number } = {}
			local prev = nil
			local time = 0
			while time < F.FLOP_TIME do
				for _, cue in Anim.fishCues("Flop", "Character", prev, time) do
					counts[cue] = (counts[cue] or 0) + 1
				end
				prev = time
				time += 1 / 60
			end
			t.eq(counts.FishFlop, 1)
			t.eq(counts.FishSplash, 1)
		end
	)

	t.test("QA: FishFlop·FishSplash는 id 없음(무음으로 시작), 3D 60 studs", function()
		for _, cue in { "FishFlop", "FishSplash" } do
			local entry = SfxLibrary.Entries[cue]
			t.ok(entry ~= nil, cue)
			t.eq(entry.id, nil, `{cue} id`)
			t.eq(entry.maxDistance, Anim.DETAIL_DISTANCE, `{cue} maxDistance`)
			t.eq(entry.looped, nil, `{cue} not looped`)
		end
	end)

	t.test("QA: 뽑기 — 확률 합 1, 전설은 고등어 하나, 판매 + 뽑기는 고등어 하나뿐", function()
		local grades = DrawLogic.grades()
		local sum = 0
		for _, grade in grades do
			sum += grade.chance
			if grade.grade == "Legendary" then
				t.eq(grade.skinIds, { ID })
			end
		end
		t.ok(math.abs(sum - 1) <= 1e-9, `sum {sum}`)
		local both = {}
		for _, skin in Skins.LIST do
			if Skins.isDraw(skin.id) and skin.robux ~= nil then
				table.insert(both, skin.id)
			end
			if skin.conceptBody then
				t.ok(Skins.isDraw(skin.id), `{skin.id} conceptBody is a draw skin`)
			end
		end
		t.eq(both, { ID })
		local skin = Skins.get(ID)
		t.eq(skin and skin.coins, nil)
	end)

	---------------------------------------------------------------- 재QA (4차 결정: 이름표 4.8)
	t.test(
		"재QA: 무작위 입력 4000개(모드·팔딱·착지·공중·걸음·넘어짐·섞기)와 관절 한도 끝 조합에서 꼭대기 ≤ 이름표, 외곽·얼굴",
		function()
			local seed = 20261014
			local function nxt(): number
				seed = (seed * 1103515245 + 12345) % 2147483648
				return seed / 2147483648
			end
			local modes = { "Character", "Idle", "Hurt", "Victory", "Preview" }
			local bases = {}
			for _, e in Sample.EXPRESSIONS do
				bases[e] = SushiBody.layout(ID, e)
				t.ok(SushiBody.bounds(bases[e]).max[2] <= TAG - 0.4 + 1e-9, `{e} rest top`)
			end
			local function check(label: string, pose: any, expression: string)
				local layout = SushiPose.posed(bases[expression], Anim.fishMotion(pose))
				local b = SushiBody.bounds(layout)
				t.ok(b.max[2] <= TAG + 1e-9, `{label} top {b.max[2]}`)
				t.ok(b.max[1] - b.min[1] <= MAX_X + 1e-9, `{label} x`)
				t.ok(b.max[3] - b.min[3] <= MAX_Z + 1e-9, `{label} z`)
				for _, spec in layout do
					if isFishPart(spec.name) then
						local lo = LayoutCheck.box(spec)
						t.ok(lo[2] >= RICE_TOP - 0.2 - 1e-6, `{label} {spec.name} low`)
						if lo[2] < RICE_TOP then
							t.ok(lo[3] >= RICE_FRONT - 1e-6, `{label} {spec.name} face`)
						end
					end
				end
			end
			for i = 1, 4000 do
				local input: any = {
					time = nxt() * 20,
					walk = if nxt() < 0.5 then 0 else nxt() * 1.3,
					phase = nxt() * 2 * math.pi,
					riseSpeed = nxt() * 70,
					airborne = nxt() < 0.5,
					landTime = if nxt() < 0.6 then nxt() * 0.58 else nil,
					landStrength = nxt(),
					knocked = nxt() < 0.2,
					flopTime = if nxt() < 0.6 then nxt() * 0.6 else nil,
					mode = modes[1 + math.floor(nxt() * #modes)],
				}
				if nxt() < 0.5 then
					input.blend = { knock = nxt(), air = nxt() }
				end
				local pose = Anim.fishPose(input)
				t.ok(math.abs(pose.rootTwist) <= F.MAX_TWIST + 1e-9, `fuzz {i} twist`)
				check(`fuzz {i}`, pose, Sample.EXPRESSIONS[1 + (i % #Sample.EXPRESSIONS)])
			end
			-- 관절 한도 끝: 들썩·비틀림·꼬리·뒷몸 끝값 × 아치(머리 아치는 0 이상 — 숙이는 항이 없음,
			-- 휨은 Hurt 처짐 -10°에서 +20°까지)
			for _, lift in { 0, F.MAX_LIFT } do
				for _, arch in { 0, F.MAX_ARCH } do
					for _, bend in { F.HURT_MID_ARCH + F.HURT_TAIL_ARCH, F.MAX_ARCH } do
						for _, twist in { -F.MAX_TWIST, F.MAX_TWIST } do
							for _, tail in { -F.MAX_TAIL, 0, F.MAX_TAIL } do
								local pose = {
									rootLift = lift,
									rootArch = arch,
									rootTwist = twist,
									midYaw = if tail > 0 then F.MAX_MID elseif tail < 0 then -F.MAX_MID else 0,
									midArch = bend / 2,
									tailYaw = tail,
									tailArch = bend / 2,
									finFlap = F.FIN_FLOP,
									splash = 1,
								}
								-- 한도 끝 조합은 같이 못 나오는 값도 섞여 있어(작은 아치 + 큰 비틀림 등) 꼭대기·외곽만 봐요.
								-- 밥 윗면·얼굴 규칙은 실제 fishPose 출력(위 무작위 4000개)으로 봐요
								local label = `extreme {lift} {arch} {bend} {twist} {tail}`
								local b = SushiBody.bounds(SushiPose.posed(bases.Default, Anim.fishMotion(pose :: any)))
								t.ok(b.max[2] <= TAG + 1e-9, `{label} top {b.max[2]}`)
								t.ok(b.max[1] - b.min[1] <= MAX_X + 1e-9, `{label} x`)
								t.ok(b.max[3] - b.min[3] <= MAX_Z + 1e-9, `{label} z`)
							end
						end
					end
				end
			end
		end
	)

	t.test(
		"재QA: 이름표 높이 — 고등어만 4.8, 서버 코드는 NameTagHeight 속성·nameTagHeight를 읽지 않음",
		function()
			t.eq(TAG, 4.8)
			t.eq(SushiBody.NAME_TAG_HEIGHT, 3.6)
			for _, skin in Skins.LIST do
				if skin.id ~= ID then
					t.eq(SushiBody.nameTagHeight(skin.id), 3.6, skin.id)
				end
			end
			for _, name in fs.readDir("src/server") do
				local path = `src/server/{name}`
				if fs.isFile(path) then
					local source = fs.readFile(path)
					t.ok(string.find(source, "NameTagHeight", 1, true) == nil, `{path} NameTagHeight`)
					t.ok(string.find(source, "NAME_TAG_ATTRIBUTE", 1, true) == nil, `{path} NAME_TAG_ATTRIBUTE`)
					t.ok(string.find(source, "nameTagHeight", 1, true) == nil, `{path} nameTagHeight`)
				end
			end
		end
	)
end
