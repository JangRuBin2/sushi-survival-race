--!strict
-- m5-38 QA "찻잎 정원" 회귀 테스트 (docs/qa/m5-38-map-tea-garden.md).
-- 개발 테스트(map-tea-garden)는 delay를 시각 순서 없이 몰아서 돌리고 Heartbeat는 낙하만 봤어요.
-- 여기서는 가짜 시계(os.clock)로 실제 TeaGarden 소스를 시간 순서대로 돌려서 확인해요:
--   1) 0 → 112초 한 판 전체: 찻잔 수(0/1/2/3/0)·선속도(13/16/18)·무너진 단 위를 구르지 않음·연장전 끝 충돌 0·모든 delay/연결이 ctx.cleanup에
--   2) 찻잔 넉백: MoveExempt 1.5초·PlatformStand 0.8초·LinearVelocity(26/12/18)·쿨다운 1초·점프(발 ≥ 윗면 + 6)·옆 단은 안 맞음
--   3) 두 방이 같은 맵을 동시에: 한 방의 연장전이 다른 방 바닥·찻잔을 건드리지 않음 (roundStates[ctx] + ctx.model 태그만)
--   4) 3단 경고 중(43초)에 연장전이 시작돼도 20초 안에 설 곳 0, 찻잔이 무너진 단에 남지 않음

local luau = require("@lune/luau")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Attributes = RobloxRequire.require(Shared.Attributes)
local Layout = RobloxRequire.require(Shared.maps.TeaGardenLayout)
local Logic = RobloxRequire.require(Shared.maps.TeaGardenLogic)

local RShared = Shims.root("src/shared")
pcall(roblox.implementMethod, "ParticleEmitter", "Emit", function() end)
local serverNow = 1000
pcall(roblox.implementMethod, "Workspace", "GetServerTimeNow", function()
	return serverNow
end)

local RCF: any = roblox.CFrame
local RV3: any = roblox.Vector3
local Instance: any = roblox.Instance

local ORIGIN_A = RCF.new(0, 300, 2000)
local ORIGIN_B = RCF.new(0, 300, 4000)
local DT = 1 / 20

---------------------------------------------------------------- 가짜 시계 실행 환경

type Delay = { at: number, seq: number, fn: any, args: { any }, handle: any }
type Beat = { fn: any, connected: boolean, connection: any }
type Harness = {
	map: any,
	now: number,
	seq: number,
	delays: { Delay },
	beats: { Beat },
	handles: { any }, -- task.delay가 돌려준 것 (전부 ctx.cleanup에 있어야 해요)
	connections: { any },
	waits: number,
}

local function newHarness(): Harness
	local h: Harness =
		{ map = nil, now = 0, seq = 0, delays = {}, beats = {}, handles = {}, connections = {}, waits = 0 }
	local heartbeat = {}
	function heartbeat:Connect(fn: any)
		local beat: Beat = { fn = fn, connected = true, connection = nil }
		local connection = {}
		function connection:Disconnect()
			beat.connected = false
		end
		beat.connection = connection
		table.insert(h.beats, beat)
		table.insert(h.connections, connection)
		return connection
	end
	local fakeTask = {
		delay = function(seconds: number, fn: any, ...: any): any
			h.seq += 1
			local handle = { __thread = h.seq }
			table.insert(h.delays, { at = h.now + seconds, seq = h.seq, fn = fn, args = { ... }, handle = handle })
			table.insert(h.handles, handle)
			return handle
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return { __thread = true }
		end,
		wait = function(): number
			h.waits += 1
			error("task.wait is not allowed in tea-garden")
		end,
	}
	local runService = { Heartbeat = heartbeat }
	local env = table.clone(Shims.globals)
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return h.now
		end,
		time = os.time,
	}
	env.game = {
		GetService = function(_self: any, name: string): any
			if name == "RunService" then
				return runService
			end
			return Shims.game:GetService(name)
		end,
	}
	env.script = (RShared.maps :: any).TeaGarden
	env.require = function(target: any): any
		return Shims.require(target)
	end
	local source = fs.readFile("src/shared/maps/TeaGarden.luau")
	h.map = luau.load(source, { debugName = "TeaGarden", environment = env })()
	return h
end

-- to까지: 그 안에 올 delay를 시각 순서대로 (그 시각으로 시계를 맞춰) 돌린 뒤 Heartbeat 한 번
local function advance(h: Harness, to: number)
	while true do
		local best: number? = nil
		for i, d in h.delays do
			if d.at <= to + 1e-9 then
				local b = if best then h.delays[best] else nil
				if b == nil or d.at < b.at or (d.at == b.at and d.seq < b.seq) then
					best = i
				end
			end
		end
		if best == nil then
			break
		end
		local d = table.remove(h.delays, best) :: Delay
		h.now = math.max(h.now, d.at)
		serverNow = 1000 + h.now
		d.fn(table.unpack(d.args))
	end
	h.now = to
	serverNow = 1000 + h.now
	for _, beat in table.clone(h.beats) do
		if beat.connected then
			beat.fn(DT)
		end
	end
end

-- 실제 게임처럼 프레임(DT)마다 Heartbeat를 돌리며 to까지
local function stepTo(h: Harness, to: number)
	while h.now + DT < to - 1e-9 do
		advance(h, h.now + DT)
	end
	advance(h, to)
end

local function newCtx(model: any, origin: any, seed: number): any
	local state = seed
	local rng = {
		NextNumber = function(_self: any, min: number?, max: number?): number
			state = (state * 1103515245 + 12345) % 2147483648
			local lo, hi = min or 0, max or 1
			return lo + state / 2147483648 * (hi - lo)
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + math.floor(state / 2147483648 * (max - min + 1))
		end,
	}
	local ctx: any = { model = model, origin = origin, rng = rng, targetCount = 1, active = true, racers = {} }
	local items = {}
	ctx.cleanup = {
		items = items,
		add = function(_self: any, item: any)
			table.insert(items, item)
			return item
		end,
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return ctx.racers
	end
	ctx.pass = function() end
	ctx.eliminate = function() end
	return ctx
end

local function under(part: any, model: any, folder: string): boolean
	local p = part.Parent
	while p and p ~= model do
		if p.Name == folder then
			return true
		end
		p = p.Parent
	end
	return false
end

-- 서 있거나 매달릴 수 있는 것: Spawns·IntroCamera(원래 충돌 없음) 밖의 모든 CanCollide 파츠 (Decor 포함 — 장식도 셈)
local function colliders(model: any): number
	local n = 0
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.CanCollide
			and not under(d, model, "Spawns")
			and not under(d, model, "IntroCamera")
		then
			n += 1
		end
	end
	return n
end

local function ringSolid(model: any, ring: number): boolean
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Ring") == ring then
			local slab = d:FindFirstChild("Slab")
			return slab ~= nil and slab.CanCollide
		end
	end
	return false
end

type CupView = { name: string, r: number, angle: number, base: number, ring: number? }

-- 보이는 찻잔 (CupBody가 보임): origin 로컬 반지름·각도·바닥 높이, 단 가운데 원 위에 정확히 있으면 그 단
local function visibleCups(model: any, origin: any): { CupView }
	local out: { CupView } = {}
	for _, cup in model:GetChildren() do
		if cup:IsA("Model") and cup:HasTag("TeaRollingCup") then
			local body = cup:FindFirstChild("CupBody")
			if body and body.Transparency < 1 then
				local rel = origin:PointToObjectSpace(body.CFrame.Position)
				local r = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
				local base = rel.Y - Logic.CUP_DIAMETER / 2
				local onRing: number? = nil
				for ring = 1, Layout.RING_COUNT do
					if math.abs(r - Layout.ringMid(ring)) < 0.05 and math.abs(base - Layout.RINGS[ring].top) < 0.05 then
						onRing = ring
					end
				end
				table.insert(
					out,
					{ name = cup.Name, r = r, angle = math.atan2(rel.Z, rel.X), base = base, ring = onRing }
				)
			end
		end
	end
	return out
end

local function inCleanup(ctx: any, item: any): boolean
	return table.find(ctx.cleanup.items, item) ~= nil
end

-- 0 → endAt 시뮬레이션. overtimeAt에 연장전 훅. 프레임마다 찻잔이 무너진 단 위를 구르면 기록.
type RunReport = {
	countAt: { [number]: number },
	speedErr: { [string]: number },
	onGone: { string },
	collidersAt: { [number]: number },
}

local function simulate(
	h: Harness,
	ctx: any,
	overtimeAt: number,
	endAt: number,
	samples: { number },
	speedWindows: { { from: number, to: number, speed: number } }
): RunReport
	local report: RunReport = { countAt = {}, speedErr = {}, onGone = {}, collidersAt = {} }
	local prev: { [string]: CupView } = {}
	local overtimeDone = false
	local frame = 0
	while true do
		frame += 1
		local t = frame * DT
		if t > endAt + 1e-9 then
			break
		end
		if not overtimeDone and t >= overtimeAt - 1e-9 then
			advance(h, overtimeAt)
			h.map.overtime(ctx, { collapseDuration = 20 })
			overtimeDone = true
		end
		advance(h, t)
		local cups = visibleCups(ctx.model, ctx.origin)
		local now: { [string]: CupView } = {}
		for _, cup in cups do
			now[cup.name] = cup
			local ring = cup.ring
			if ring and not ringSolid(ctx.model, ring) then
				table.insert(report.onGone, string.format("%s on ring %d at %.2f", cup.name, ring, t))
			end
			local p = prev[cup.name]
			if p and ring and p.ring == ring then
				for _, w in speedWindows do
					if t - DT >= w.from and t <= w.to then
						local d = math.abs(cup.angle - p.angle)
						if d < 1 then -- 각도 넘김(±π) 프레임은 빼요
							local speed = d * Layout.ringMid(ring) / DT
							local key = string.format("%g-%g", w.from, w.to)
							report.speedErr[key] = math.max(report.speedErr[key] or 0, math.abs(speed - w.speed))
						end
					end
				end
			end
		end
		prev = now
		for _, s in samples do
			if math.abs(t - s) < DT / 2 then
				report.countAt[s] = #cups
				report.collidersAt[s] = colliders(ctx.model)
			end
		end
	end
	return report
end

local function makeRacer(name: string): (any, any, any)
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = RV3.new(2, 2, 1)
	root.Parent = character
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.PlatformStand = false
	humanoid.Parent = character
	return { Name = name, Character = character }, root, humanoid
end

-- 발바닥이 origin 로컬 (x, footY, z)에 오게 루트를 놓아요
local function placeFoot(root: any, humanoid: any, origin: any, x: number, footY: number, z: number)
	local cf = origin * RCF.new(x, footY + humanoid.HipHeight + root.Size.Y / 2, z)
	root.CFrame = cf
	root.Position = cf.Position
end

local function launches(root: any): number
	local n = 0
	for _, c in root:GetChildren() do
		if c.Name == "TeaCupLaunch" then
			n += 1
		end
	end
	return n
end

return function(t: Test.Test)
	t.test(
		"QA 1: 한 판 전체(0 → 112초, 연장전 90초) — 찻잔 수·속도·무너진 단·충돌 0·cleanup",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN_A)
			local ctx = newCtx(model, ORIGIN_A, 7)
			h.now = 0
			h.map.start(ctx)
			local report = simulate(h, ctx, 90, 112, { 1, 2.9, 10, 25, 40, 70, 89, 100.5, 108, 110.2, 112 }, {
				{ from = 4, to = 59.5, speed = 13 },
				{ from = 60.5, to = 89.5, speed = 16 },
				{ from = 90.5, to = 109.5, speed = 18 },
			})
			t.eq(h.waits, 0, "no task.wait")
			-- 찻잔 수 (스펙 표: 0~3초 0, 3~30초 1, 30~60초 2, 60초~ 3, 연장전 끝 0)
			t.eq(report.countAt[1], 0, "t=1 (preview cup hidden at start)")
			t.eq(report.countAt[2.9], 0, "t=2.9")
			t.eq(report.countAt[10], 1, "t=10")
			t.eq(report.countAt[25], 1, "t=25")
			t.eq(report.countAt[40], 2, "t=40")
			t.eq(report.countAt[70], 3, "t=70")
			t.eq(report.countAt[100.5], 3, "t=100.5 (overtime)")
			t.eq(report.countAt[110.2], 0, "after +20 cups are gone")
			-- 선속도 (단 가운데 원 위, 같은 단에 머문 프레임)
			for key, err in report.speedErr do
				t.ok(err < 0.2, `speed window {key} off by {err}`)
			end
			t.ok(report.speedErr["4-59.5"] ~= nil, "measured speed 13")
			t.ok(report.speedErr["60.5-89.5"] ~= nil, "measured speed 16")
			t.ok(report.speedErr["90.5-109.5"] ~= nil, "measured speed 18")
			-- 찻잔이 무너진 단 위를 구르지 않아요 (AC12 "무너진 단으로는 찻잔이 안 간다")
			t.eq(report.onGone, {}, "cups on collapsed rings")
			-- 설 곳: 89초 = 1·2단 24조각 + 심, +10.5초 = 1단 12 + 심, +20초 뒤 0 (장식 포함 전체)
			t.eq(report.collidersAt[89], 25, "rings 1·2 + core before overtime")
			t.eq(report.collidersAt[100.5], 13, "ring 1 + core after +10")
			t.eq(report.collidersAt[108], 13, "ring 1 + core at +18")
			t.eq(report.collidersAt[110.2], 0, "nothing to stand on after +20")
			t.eq(report.collidersAt[112], 0, "still nothing at +22")
			-- 모든 delay·Heartbeat 연결이 ctx.cleanup에 (라운드가 끝나면 정리)
			for _, handle in h.handles do
				t.ok(inCleanup(ctx, handle), "every task.delay is in ctx.cleanup")
			end
			for _, connection in h.connections do
				t.ok(inCleanup(ctx, connection), "every Heartbeat connection is in ctx.cleanup")
			end
			t.ok(#h.handles >= 6, "delays were scheduled")
		end
	)

	t.test(
		"QA 2: 찻잔 넉백 — MoveExempt 1.5·PlatformStand 0.8·LinearVelocity·쿨다운 1·점프·옆 단",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN_A)
			local ctx = newCtx(model, ORIGIN_A, 11)
			h.map.start(ctx)
			stepTo(h, 6)
			local cups = visibleCups(model, ORIGIN_A)
			t.eq(#cups, 1, "one cup at 6s")
			local cup = cups[1]
			t.eq(cup.ring, 1, "first cup rolls on ring 1")
			local cx, cz = Layout.polar(cup.r, cup.angle)
			local top = Layout.RINGS[1].top

			local hitP, hitRoot, hitHum = makeRacer("hit")
			local jumpP, jumpRoot, jumpHum = makeRacer("jump")
			local sideP, sideRoot, sideHum = makeRacer("side")
			placeFoot(hitRoot, hitHum, ORIGIN_A, cx, top, cz)
			placeFoot(jumpRoot, jumpHum, ORIGIN_A, cx, top + Logic.HIT_HEIGHT + 0.05, cz)
			local sx, sz = Layout.polar(Layout.RINGS[2].inner + 0.2, cup.angle) -- 2단 안쪽 끝, 같은 각도
			placeFoot(sideRoot, sideHum, ORIGIN_A, sx, Layout.RINGS[2].top, sz)
			ctx.racers = { hitP, jumpP, sideP }
			advance(h, 6) -- 같은 시각: 찻잔이 같은 자리

			local exempt = hitP.Character:GetAttribute(Attributes.MoveExemptUntil)
			t.ok(
				type(exempt) == "number" and math.abs(exempt - (serverNow + Logic.EXEMPT_TIME)) < 1e-6,
				"MoveExempt 1.5s"
			)
			t.eq(hitHum.PlatformStand, true, "knocked down")
			t.eq(launches(hitRoot), 1, "one LinearVelocity")
			local push = hitRoot:FindFirstChild("TeaCupLaunch")
			local v = push.VectorVelocity
			t.ok(math.abs(v.Y - Logic.KNOCK_UP) < 1e-4, "up 18")
			t.ok(
				math.abs(math.sqrt(v.X * v.X + v.Z * v.Z) - math.sqrt(26 * 26 + 12 * 12)) < 1e-3,
				"forward 26 + outward 12"
			)
			t.ok(inCleanup(ctx, push), "launch is in ctx.cleanup")
			-- 점프한 사람(발 ≥ 윗면 + 6)과 옆 단 사람은 안 맞아요
			t.eq(jumpP.Character:GetAttribute(Attributes.MoveExemptUntil), nil, "jumped over (foot >= top + 6)")
			t.eq(jumpHum.PlatformStand, false)
			t.eq(sideP.Character:GetAttribute(Attributes.MoveExemptUntil), nil, "neighbor ring is safe")

			-- 0.12초 뒤 LinearVelocity 사라짐, 0.8초 뒤 일어남
			ctx.racers = { hitP }
			stepTo(h, 6.5)
			t.eq(launches(hitRoot), 0, "launch removed after 0.12s")
			t.eq(hitHum.PlatformStand, true, "still down at +0.5")
			-- 쿨다운 1초: 0.7초 뒤 다시 찻잔 자리에 있어도 안 맞아요
			local again = visibleCups(model, ORIGIN_A)[1]
			local ax, az = Layout.polar(again.r, again.angle)
			placeFoot(hitRoot, hitHum, ORIGIN_A, ax, top, az)
			stepTo(h, 6.7)
			local cupNow = visibleCups(model, ORIGIN_A)[1]
			local bx, bz = Layout.polar(cupNow.r, cupNow.angle)
			placeFoot(hitRoot, hitHum, ORIGIN_A, bx, top, bz)
			advance(h, 6.7)
			t.eq(hitP.Character:GetAttribute(Attributes.MoveExemptUntil), exempt, "cooldown: no second hit within 1s")
			t.eq(launches(hitRoot), 0)
			stepTo(h, 6.85)
			t.eq(hitHum.PlatformStand, false, "gets up after 0.8s")
			-- 1초 뒤에는 다시 맞아요
			stepTo(h, 7.2)
			local c2 = visibleCups(model, ORIGIN_A)[1]
			local dx, dz = Layout.polar(c2.r, c2.angle)
			placeFoot(hitRoot, hitHum, ORIGIN_A, dx, Layout.RINGS[c2.ring or 1].top, dz)
			advance(h, 7.2)
			t.ok(hitP.Character:GetAttribute(Attributes.MoveExemptUntil) > exempt, "hit again after cooldown")
			t.eq(launches(hitRoot), 1)
			-- 넉백이 만든 delay(LinearVelocity 제거·일어나기)도 전부 ctx.cleanup에
			for _, handle in h.handles do
				t.ok(inCleanup(ctx, handle), "every task.delay (knockback too) is in ctx.cleanup")
			end
		end
	)

	t.test(
		"QA 3: 두 방이 같은 맵을 동시에 — 한 방의 연장전이 다른 방을 건드리지 않아요",
		function()
			local h = newHarness()
			local modelA = h.map.build(ORIGIN_A)
			local modelB = h.map.build(ORIGIN_B)
			local ctxA = newCtx(modelA, ORIGIN_A, 3)
			local ctxB = newCtx(modelB, ORIGIN_B, 5)
			h.map.start(ctxA)
			h.map.start(ctxB)
			local frame = 0
			while frame * DT < 111 do
				frame += 1
				local t0 = frame * DT
				if math.abs(t0 - 90) < DT / 2 then
					advance(h, 90)
					h.map.overtime(ctxA, { collapseDuration = 20 })
				end
				advance(h, t0)
			end
			t.eq(colliders(modelA), 0, "room A: nothing to stand on")
			t.eq(colliders(modelB), 25, "room B: rings 1·2 + core untouched")
			t.eq(#visibleCups(modelA, ORIGIN_A), 0, "room A cups gone")
			t.eq(#visibleCups(modelB, ORIGIN_B), 3, "room B cups still rolling")
			for _, cup in visibleCups(modelB, ORIGIN_B) do
				t.ok(cup.r < Layout.RADIUS, "room B cups stay in room B")
			end
		end
	)

	t.test(
		"QA 4: 3단 경고 중(43초) 연장전 — 3단은 45초, 남은 단은 20초 안, 찻잔이 무너진 단에 없음",
		function()
			local h = newHarness()
			local model = h.map.build(ORIGIN_A)
			local ctx = newCtx(model, ORIGIN_A, 23)
			h.map.start(ctx)
			local report = simulate(h, ctx, 43, 66, { 44, 45.2, 53.2, 62.9, 63.2, 66 }, {})
			t.eq(report.collidersAt[44], 37, "ring 3 still solid while warning (36 slabs + core)")
			t.eq(report.collidersAt[45.2], 25, "ring 3 gone at 45 (main schedule)")
			t.eq(report.collidersAt[53.2], 13, "ring 2 at +10")
			t.eq(report.collidersAt[62.9], 13, "ring 1 until +20")
			t.eq(report.collidersAt[63.2], 0, "nothing at +20")
			t.eq(report.collidersAt[66], 0)
			t.eq(report.onGone, {}, "cups on collapsed rings")
			t.eq(report.countAt[63.2], 0, "cups gone")
		end
	)
end
