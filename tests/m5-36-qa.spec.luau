--!strict
-- m5-36 QA (docs/qa/m5-36-map-rice-cooker.md): rice-cooker start()를 가짜 시계·가짜 task·가짜 Heartbeat로 돌려 봐요.
--   낙하선: origin 로컬 Y −20 경계(−19.9 무사, −20.1 탈락), 회전한 아레나 슬롯 origin에서도 로컬 기준
--   밥알 끓어오름: 5초 전에는 없음, 5초에 경고(RiceBurst 태그, 이 방 모델 안) → 1.5초 뒤 원 안(수평 ≤ 6)·발 < 윗면 + 5만
--     위 45 + 바깥 22, MoveExempt 1.5, PlatformStand 0.8초 뒤 풀림, cue RiceBubble
--   증기: 12초 경고(SteamWhistle, 점선, 그 밸브만 흔들림) → 14초 분사, 띠 안·발 < 윗면 + 8만 반대쪽으로 34 + 위 10,
--     분사마다 한 번(1.2초 동안 0.1초마다 봐도), MoveExempt 1.2, cue SteamBlast. 다른 방 모델의 밸브는 그대로
--   타이머: 방마다 자기 모델의 글자만, 시작 시각 기준
--   timeLimit 75: RoundLogic 일정이 75초에 Expire, 시간 종료면 남은 사람 전원 Passed. 끝난 라운드(isActive false)에서는
--     낙하·넉백·새 경고 없음
--   모듈 수준 가변 상태 없음 (소스 검사 + 두 방 동시 실행)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame
local RInstance: any = roblox.Instance

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Maps = RobloxRequire.require(Shared.maps)
local Layout = RobloxRequire.require(Shared.maps.RiceCookerLayout)
local Logic = RobloxRequire.require(Shared.maps.RiceCookerLogic)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

-- Lune 인스턴스에는 ParticleEmitter:Emit이 없어요 (start가 터짐에서 불러요)
pcall(roblox.implementMethod, "ParticleEmitter", "Emit", function(_self: any, _count: number) end)

local SOURCE_PATH = "src/shared/maps/RiceCooker.luau"
local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z
local STEP = 1 / 32 -- 2의 거듭제곱이라 시각이 정확히 쌓여요 (5초 = 160틱)

---------------------------------------------------------------- 가짜 환경

type Harness = {
	map: any,
	now: number,
	advance: (seconds: number) -> (),
	marks: { { character: any, seconds: number } },
	cues: { string },
	roots: { any },
	pushes: { { inst: any, velocity: any?, root: any? } },
}

local function newHarness(): Harness
	-- clockLag: 0보다 크면 os.clock()이 스케줄러 시계보다 그만큼 늦어요 (start 뒤) — task.wait가 "일찍" 깨는 경우 (B1)
	local harness: any = { now = 0, clockLag = 0, marks = {}, cues = {}, roots = {}, pushes = {} }
	-- 실제 task.wait·task.delay처럼 적어도 다음 틱에 깨어나요 (같은 틱 안에서 다시 돌지 않게)
	local sleepers: { { at: number, started: number, tick: number, co: thread?, fn: any } } = {}
	local tick = 0
	local handlers: { any } = {}

	local function resume(co: thread, ...: any)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(`thread failed: {err}`, 0)
		end
	end

	local heartbeat = {}
	function heartbeat:Connect(fn: any)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
		}
	end

	local fakeTask = {
		spawn = function(fn: any, ...: any): any
			local co = coroutine.create(fn)
			resume(co, ...)
			return co
		end,
		delay = function(seconds: number, fn: any): any
			local entry = { at = harness.now + seconds, started = harness.now, tick = tick, co = nil, fn = fn }
			table.insert(sleepers, entry)
			return entry
		end,
		wait = function(seconds: number?): number
			local co = coroutine.running()
			assert(coroutine.isyieldable(), "task.wait outside a thread")
			table.insert(
				sleepers,
				{ at = harness.now + (seconds or 0), started = harness.now, tick = tick, co = co, fn = nil }
			)
			return coroutine.yield()
		end,
	}

	function harness.advance(seconds: number)
		local target = harness.now + seconds
		while harness.now < target - 1e-9 do
			harness.now = math.min(target, harness.now + STEP)
			tick += 1
			for _, h in table.clone(handlers) do
				if h.connected then
					h.fn(STEP)
				end
			end
			-- 시간이 된 스레드·delay (그 안에서 새로 생긴 것도 같은 틱에)
			while true do
				local dueIndex: number? = nil
				for i, s in sleepers do
					local due = s.at <= harness.now and s.tick < tick
					if due and (dueIndex == nil or s.at < sleepers[dueIndex].at) then
						dueIndex = i
					end
				end
				if dueIndex == nil then
					break
				end
				local s = table.remove(sleepers, dueIndex) :: any
				if s.co then
					resume(s.co, harness.now - s.started)
				else
					resume(coroutine.create(s.fn))
				end
			end
			-- 이 틱에 생긴 넉백 LinearVelocity의 속도를 적어 둬요 (0.12초 뒤 Destroy되면 못 읽어요)
			for _, push in harness.pushes do
				if push.root == nil then
					pcall(function()
						push.velocity = push.inst.VectorVelocity
						push.root = push.inst.Parent
					end)
				end
			end
		end
	end

	-- 태그 찾기: 테스트가 등록한 모델(방)들 안에서
	harness.roots = {}
	local collection = {
		AddTag = function(_self: any, inst: any, tag: string)
			inst:AddTag(tag)
		end,
		GetTagged = function(_self: any, tag: string): { any }
			local list = {}
			for _, root in harness.roots do
				for _, d in root:GetDescendants() do
					if d:HasTag(tag) then
						table.insert(list, d)
					end
				end
			end
			return list
		end,
	}

	local fakeMoveExempt = {
		mark = function(character: any, seconds: number?)
			table.insert(harness.marks, { character = character, seconds = seconds or 0 })
		end,
	}
	local fakeSfx = {
		play = function(_part: any, cue: string)
			table.insert(harness.cues, cue)
		end,
	}
	local FAKE_MOVE = { __fake = "MoveExempt" }
	local FAKE_SFX = { __fake = "MapSfx" }
	local parent = setmetatable({}, {
		__index = function(_, name: string): any
			if name == "Parent" then
				return { MoveExempt = FAKE_MOVE }
			end
			if name == "MapSfx" then
				return FAKE_SFX
			end
			return (RShared.maps :: any)[name]
		end,
	})

	local env = table.clone(Shims.globals)
	env.Instance = setmetatable({
		new = function(className: string, ...: any): any
			local inst = RInstance.new(className, ...)
			if className == "LinearVelocity" then
				table.insert(harness.pushes, { inst = inst })
			end
			return inst
		end,
	}, { __index = RInstance })
	env.script = { Parent = parent }
	env.require = function(target: any): any
		if target == FAKE_MOVE then
			return fakeMoveExempt
		elseif target == FAKE_SFX then
			return fakeSfx
		end
		return Shims.require(target)
	end
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return if harness.now > 0 then harness.now - harness.clockLag else harness.now
		end,
	}
	env.game = {
		GetService = function(_self: any, name: string): any
			if name == "RunService" then
				return { Heartbeat = heartbeat }
			elseif name == "CollectionService" then
				return collection
			end
			error(`unexpected service {name}`)
		end,
	}
	-- Lune은 BasePart.Position을 못 읽어요 (Shims와 같은 우회)
	env.__pos = function(value: any): any
		return value.CFrame.Position
	end
	local source = fs.readFile(SOURCE_PATH)
	source = string.gsub(source, "root%.Position", "__pos(root)")
	harness.map = luau.load(source, { debugName = "RiceCooker(QA)", environment = env })()
	return harness :: Harness
end

local function newCleanup(): any
	local cleanup = { items = {} :: { any } }
	function cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	return cleanup
end

-- 늘 같은 값을 주는 rng (NextNumber = number, NextInteger = min)
local function constRng(number: number): any
	return {
		NextNumber = function(_self: any): number
			return number
		end,
		NextInteger = function(_self: any, min: number, _max: number): number
			return min
		end,
	}
end

-- 진짜 Lune 인스턴스 캐릭터 (루트·Humanoid·RootAttachment). 발 높이 = 그 자리 윗면 + footAbove
local function racer(name: string, origin: any, x: number, z: number, footAbove: number): any
	local character = RInstance.new("Model")
	character.Name = name
	local root = RInstance.new("Part")
	root.Name = "HumanoidRootPart"
	local top = Layout.surfaceAtXZ(x, z) or 0
	root.CFrame = origin * RCF.new(x, top + Layout.FOOT_OFFSET + footAbove, z)
	root.Parent = character
	local attachment = RInstance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = RInstance.new("Humanoid")
	humanoid.PlatformStand = false
	humanoid.Parent = character
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

local function placeAt(player: any, origin: any, x: number, y: number, z: number)
	player.root.CFrame = origin * RCF.new(x, y, z)
end

local function newCtx(model: any, origin: any, racers: { any }, rng: any): any
	local ctx: any = {
		model = model,
		origin = origin,
		rng = rng,
		targetCount = 1,
		cleanup = newCleanup(),
		active = true,
		passed = {} :: { string },
		eliminated = {} :: { string },
		racers = racers,
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return ctx.racers
	end
	ctx.pass = function(player: any)
		table.insert(ctx.passed, player.Name)
	end
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, player.Name)
		local i = table.find(ctx.racers, player)
		if i then
			table.remove(ctx.racers, i)
		end
	end
	return ctx
end

local function marksOf(h: Harness, player: any): { number }
	local out = {}
	for _, m in h.marks do
		if m.character == player.Character then
			table.insert(out, m.seconds)
		end
	end
	return out
end

local function countCue(h: Harness, cue: string): number
	local n = 0
	for _, c in h.cues do
		if c == cue then
			n += 1
		end
	end
	return n
end

local function tagged(model: any, tag: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:HasTag(tag) then
			n += 1
		end
	end
	return n
end

local function named(model: any, name: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

-- 그 레이서 루트에 걸린 마지막 넉백 속도 (origin 로컬)
local function localVelocity(h: Harness, origin: any, player: any): any
	local found = nil
	for _, push in h.pushes do
		if push.root == player.root then
			found = push.velocity
		end
	end
	return if found then origin:VectorToObjectSpace(found) else RV3.new(0, 0, 0)
end

local function close(a: number, b: number, tol: number?): boolean
	return math.abs(a - b) <= (tol or 1e-3)
end

-- 회전한 아레나 슬롯 (높이 300, 2000 떨어짐, 90° 돌림) — 로컬 축 변환을 확인해요
local ARENA = RCF.new(0, 300, 2000) * RCF.Angles(0, math.rad(90), 0)

local function startRoom(h: Harness, origin: any, racers: { any }, rng: any): (any, any)
	local model = RMaps.get("rice-cooker").build(origin)
	table.insert(h.roots, model)
	local ctx = newCtx(model, origin, racers, rng)
	h.map.start(ctx)
	return model, ctx
end

return function(t: Test.Test)
	t.test(
		"B1 회귀: task.wait가 os.clock보다 조금 일찍 깨도 첫 끓어오름이 나오고 판 내내 이어져요",
		function()
			local h = newHarness()
			h.clockLag = 0.001 -- 깬 순간 elapsed() = 4.999
			local a = racer("a", ARENA, CX + 16, CZ, 0)
			startRoom(h, ARENA, { a }, constRng(0))
			h.advance(5.1)
			t.ok(countCue(h, "RiceBubble") == 0, "still warning")
			h.advance(1.8) -- 6.9초: 첫 터짐
			t.eq(countCue(h, "RiceBubble"), 1, "first burst despite the early wake")
			h.advance(30)
			t.ok(countCue(h, "RiceBubble") >= 5, `bursts keep coming ({countCue(h, "RiceBubble")})`)
		end
	)

	t.test(
		"QA 낙하선: 루트 로컬 Y −19.9 무사 · −20.1 탈락 (회전한 아레나 origin 기준), 끝난 라운드는 판정 없음",
		function()
			local h = newHarness()
			local safe = racer("safe", ARENA, CX + 50, CZ, 0)
			local fallen = racer("fallen", ARENA, CX + 50, CZ, 0)
			placeAt(safe, ARENA, CX + 50, -19.9, CZ)
			placeAt(fallen, ARENA, CX + 50, -20.1, CZ)
			local _, ctx = startRoom(h, ARENA, { safe, fallen }, constRng(0.99))
			h.advance(0.2)
			t.eq(ctx.eliminated, { "fallen" }, "only the one below −20")

			local h2 = newHarness()
			local fallen2 = racer("fallen2", ARENA, CX + 50, CZ, 0)
			placeAt(fallen2, ARENA, CX + 50, -30, CZ)
			local _, ctx2 = startRoom(h2, ARENA, { fallen2 }, constRng(0.99))
			ctx2.active = false
			h2.advance(1)
			t.eq(ctx2.eliminated, {}, "inactive round does not judge falls")
		end
	)

	t.test(
		"QA 끓어오름: 5초 경고 → 1.5초 뒤 원 안·발 < 윗면 + 5만 위 45 + 바깥 22, MoveExempt 1.5, 0.8초 뒤 일어남",
		function()
			local h = newHarness()
			-- rng 0: 곳 = racers[1] 발밑 그대로(지터 0), 중심이면 각도 0 → 로컬 +X
			local a = racer("a", ARENA, CX + 16, CZ, 0) -- 2단, 원 중심
			local c = racer("c", ARENA, CX + 16, CZ + 5, 4.9) -- 수평 5, 발 윗면 + 4.9 → 맞음
			local b = racer("b", ARENA, CX + 16, CZ - 5, 5.1) -- 수평 5지만 발 윗면 + 5.1 (공중) → 안 맞음
			local d = racer("d", ARENA, CX + 16, CZ + 6.5, 0) -- 수평 6.5 (원 밖) → 안 맞음
			local model, ctx = startRoom(h, ARENA, { a, c, b, d }, constRng(0))

			h.advance(4.9)
			t.eq(tagged(model, "RiceBurst"), 0, "no burst warning before 5s")
			h.advance(0.2)
			t.ok(tagged(model, "RiceBurst") > 0, "burst warning parts appear at 5s inside this model")
			h.advance(1.2) -- 6.3초: 아직 경고
			t.eq(#h.marks, 0, "nobody knocked during the 1.5s warning")
			h.advance(0.5) -- 6.8초: 터짐
			t.eq(countCue(h, "RiceBubble"), 1, "RiceBubble cue once")
			t.eq(named(model, "BurstFill") + named(model, "BurstRing"), 0, "warning circle removed after the burst")

			t.eq(marksOf(h, a), { Logic.BURST_MOVE_EXEMPT }, "center racer exempt 1.5")
			t.eq(marksOf(h, c), { Logic.BURST_MOVE_EXEMPT }, "in-circle racer exempt 1.5")
			t.eq(marksOf(h, b), {}, "airborne racer (foot ≥ top + 5) not hit")
			t.eq(marksOf(h, d), {}, "racer outside radius 6 not hit")
			t.eq(Logic.BURST_MOVE_EXEMPT, 1.5)

			local va = localVelocity(h, ARENA, a)
			t.ok(close(va.X, 22) and close(va.Y, 45) and close(va.Z, 0), `center: random dir (rng 0 → +X) {va}`)
			local vc = localVelocity(h, ARENA, c)
			t.ok(close(vc.X, 0) and close(vc.Y, 45) and close(vc.Z, 22), `outward from center (+Z) {vc}`)
			t.ok(#h.pushes >= 2, "LinearVelocity created for each knocked racer")
			t.eq(a.humanoid.PlatformStand, true, "knocked down")
			t.eq(b.humanoid.PlatformStand, false, "not hit stays up")

			h.advance(1.0) -- 0.8초 넘김
			t.eq(a.humanoid.PlatformStand, false, "stands up after knockdown time")
			t.eq(a.root:FindFirstChild("RiceCookerLaunch"), nil, "LinearVelocity removed after hold")
			t.eq(ctx.eliminated, {}, "no falls")
		end
	)

	t.test(
		"QA 증기: 12초 경고(그 밸브만 흔들림, 다른 방 그대로) → 14초 분사, 띠 안·발 < 윗면 + 8만, 분사마다 한 번",
		function()
			local h = newHarness()
			-- rng: NextNumber 0.99 → 끓어오름 곳은 언덕 동쪽 끝(+35.7, −2.2) 근처 — 아래 레이서와 멀어요.
			-- NextInteger = min → 12초 띠 1(z −14), 밸브 side 1(+X) → −X로 밀어요
			local s = racer("s", ARENA, CX - 10, CZ - 14, 0) -- 띠 1 가운데
			local k = racer("k", ARENA, CX + 5, CZ - 9.1, 7.9) -- 띠 1 끝(|dz| 4.9), 발 윗면 + 7.9 → 맞음
			local j = racer("j", ARENA, CX - 20, CZ - 14, 8.1) -- 띠 1, 발 윗면 + 8.1 → 안 맞음
			local o = racer("o", ARENA, CX - 10, CZ - 8.9, 0) -- |dz| 5.1 (띠 밖)
			local m = racer("m", ARENA, CX - 10, CZ, 0) -- 띠 2
			local model, ctx = startRoom(h, ARENA, { s, k, j, o, m }, constRng(0.99))
			local otherOrigin = ARENA * RCF.new(2000, 0, 0)
			local other = RMaps.get("rice-cooker").build(otherOrigin) -- 같은 맵을 도는 다른 방 (start 안 함)
			table.insert(h.roots, other)

			local function ventCFrames(mdl: any): { [any]: any }
				local out = {}
				for _, d in mdl:GetDescendants() do
					if d:HasTag("RiceSteamVent") then
						out[d] = d.CFrame
					end
				end
				return out
			end
			local before = ventCFrames(model)
			local otherBefore = ventCFrames(other)

			h.advance(11.9)
			t.eq(countCue(h, "SteamWhistle"), 0, "no steam before 12s")
			h.advance(0.25) -- 12.15초: 경고
			t.eq(countCue(h, "SteamWhistle"), 1, "SteamWhistle at 12s (one jet)")
			t.ok(named(model, "SteamDash") > 0, "dash warning parts in this model")
			t.eq(named(other, "SteamDash"), 0, "no dashes in the other room")
			local movedSide: { [number]: boolean } = {}
			for part, cf in before do
				if (part.CFrame.Position - cf.Position).Magnitude > 1e-4 then
					movedSide[part:GetAttribute("VentSide")] = true
				end
			end
			t.eq(movedSide, { [1] = true }, "only the +X valve shakes")
			for part, cf in otherBefore do
				t.ok((part.CFrame.Position - cf.Position).Magnitude < 1e-6, "other room's valve untouched")
			end

			h.advance(1.7) -- 13.85초: 아직 경고
			t.eq(#h.marks, 0, "nobody pushed during the 2s warning")
			h.advance(1.5) -- 15.35초: 분사 1.2초 끝
			t.eq(countCue(h, "SteamBlast"), 1, "SteamBlast once")
			t.eq(marksOf(h, s), { Logic.STEAM_MOVE_EXEMPT }, "band racer hit exactly once over the 1.2s blast")
			t.eq(marksOf(h, k), { Logic.STEAM_MOVE_EXEMPT }, "band edge, foot top + 7.9 hit")
			t.eq(marksOf(h, j), {}, "foot top + 8.1 not hit")
			t.eq(marksOf(h, o), {}, "|dz| 5.1 outside the band")
			t.eq(marksOf(h, m), {}, "other band untouched")
			local vs = localVelocity(h, ARENA, s)
			t.ok(close(vs.X, -34) and close(vs.Y, 10) and close(vs.Z, 0), `pushed away from +X valve {vs}`)
			for part, cf in before do
				t.ok((part.CFrame.Position - cf.Position).Magnitude < 1e-6, "valve back in place after warning")
			end
			t.eq(named(model, "SteamDash"), 0, "dashes removed after warning")
			t.eq(ctx.eliminated, {}, "no falls")
		end
	)

	t.test("QA 타이머: 방마다 자기 모델 글자만, 그 방 시작 시각 기준으로 1초마다", function()
		local h = newHarness()
		local modelA = startRoom(h, ARENA, {}, constRng(0.99))
		h.advance(3)
		local originB = ARENA * RCF.new(2000, 0, 0)
		local modelB = startRoom(h, originB, {}, constRng(0.99))
		local function text(mdl: any): string
			return mdl:FindFirstChild("CookerTimer"):FindFirstChild("Time", true).Text
		end
		t.eq(text(modelA), "01:12", "A after 3s")
		t.eq(text(modelB), "01:15", "B just started")
		h.advance(7.5) -- A 10.5초, B 7.5초
		t.eq(text(modelA), "01:05", "A at 10.5s")
		t.eq(text(modelB), "01:08", "B at 7.5s")
	end)

	t.test(
		"QA timeLimit 75: 75초에 Survival 종료(남은 사람 전원 통과), 끝난 뒤에는 판정·넉백·새 경고 없음",
		function()
			local map = Maps.get("rice-cooker")
			t.eq(Maps.timeLimit(map), 75)
			t.eq(Config.TimeLimit.Survival, 60, "shared Survival default unchanged")
			local mode = RoundLogic.modeFor(map.kind, false)
			local schedule = RoundLogic.schedule(mode, Maps.timeLimit(map), Config.Final, nil, map.overtime ~= nil)
			t.eq(RoundLogic.loopAction(schedule, 74.9, false), "Wait")
			t.eq(RoundLogic.loopAction(schedule, 75, false), "Expire")
			t.eq(RoundLogic.loopAction(schedule, 60, false), "Wait", "no overtime in Survival")
			local round = RoundLogic.newRound(mode, { 1, 2, 3, 4, 5, 6 }, nil)
			RoundLogic.activate(round, 2)
			local out = RoundLogic.timeout(round, function()
				return 0
			end)
			t.eq(#out, 6, "everyone left gets an outcome")
			for _, o in out do
				t.eq(o.result, "Passed", "survivors pass on timeout")
			end
			-- 맵 일정이 75초 안에 있어요 (마지막 증기 경고 72)
			local times = Logic.steamTimes(Maps.timeLimit(map))
			t.eq(times[#times], 72)

			-- 75초까지 돌리고 라운드를 끝내면 그 뒤로는 아무것도 안 해요
			local h = newHarness()
			local stay = racer("stay", ARENA, CX - 10, CZ - 14, 0)
			local model, ctx = startRoom(h, ARENA, { stay }, constRng(0))
			h.advance(75)
			ctx.active = false
			local marks, cues = #h.marks, #h.cues
			local warnings = tagged(model, "RiceBurst")
			local inCleanup: { [any]: boolean } = {}
			for _, item in ctx.cleanup.items do
				inCleanup[item] = true
			end
			for _, d in model:GetDescendants() do
				if d:HasTag("RiceBurst") then
					t.ok(inCleanup[d], `leftover warning {d.Name} is in ctx.cleanup (RoundService destroys it)`)
				end
			end
			placeAt(stay, ARENA, CX, -40, CZ) -- 끝난 뒤 떨어져도
			h.advance(10)
			t.eq(ctx.eliminated, {}, "no fall judged after the round ended")
			t.eq(#h.marks, marks, "no knockback after the round ended")
			t.eq(#h.cues, cues, "no new cues after the round ended")
			t.ok(tagged(model, "RiceBurst") <= warnings, "no new burst warnings after the round ended")
			t.eq(named(model, "SteamDash"), 0, "no steam dashes after the round ended")
		end
	)

	t.test(
		"QA: 두 방 동시 — 쿨다운·띠·타이머가 섞이지 않고, 모듈 수준 가변 상태가 없어요",
		function()
			-- 소스: 모듈 최상위 local은 require·숫자·문자열·Layout 상수·math.rad뿐 (테이블·카운터 없음)
			local src = fs.readFile(SOURCE_PATH)
			for line in string.gmatch(src, "[^\n]+") do
				local names, value = string.match(line, "^local ([%w_, ]+)%s*[:%w_%.]*%s*=%s*(.+)$")
				if names and value and not string.find(line, "^local function") then
					local ok = string.find(value, "^require%(") ~= nil
						or string.find(value, "^%-?[%d%.]+") ~= nil
						or string.find(value, '^"') ~= nil
						or string.find(value, "^math%.rad%(") ~= nil
						or string.find(value, "^Layout%.[%u_]+, Layout%.[%u_]+$") ~= nil
					t.ok(ok or names == "map", `module-level local {names} = {value}`)
				end
			end
			t.ok(string.find(src, "\nlocal [%w_]+%s*:?[^=\n]*=%s*{%s*}") == nil, "no module-level empty table")

			-- 두 방이 같은 시각에: 각 방의 끓어오름은 자기 레이서만, 같은 넉백 수
			local h = newHarness()
			local a1 = racer("a1", ARENA, CX + 16, CZ, 0)
			local originB = ARENA * RCF.new(2000, 0, 0)
			local a2 = racer("a2", originB, CX + 16, CZ, 0)
			startRoom(h, ARENA, { a1 }, constRng(0))
			startRoom(h, originB, { a2 }, constRng(0))
			h.advance(7)
			t.eq(marksOf(h, a1), { Logic.BURST_MOVE_EXEMPT }, "room A burst hits its racer once")
			t.eq(marksOf(h, a2), { Logic.BURST_MOVE_EXEMPT }, "room B burst hits its racer once")
			local v2 = localVelocity(h, originB, a2)
			t.ok(close(v2.Y, 45) and close(v2.X, 22), `room B uses its own origin {v2}`)
		end
	)
end
