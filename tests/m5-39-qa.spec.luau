--!strict
-- m5-39 QA (docs/qa/m5-39-onsen-claw.md): 온천탕 인형뽑기 회귀 테스트.
--   · 코루틴 스케줄러 모의 실행 (task.spawn·task.wait·task.delay가 진짜처럼 양보해요 — map-onsen-claw.spec의
--     모의 실행은 task.spawn을 바로 끝까지 돌려서 "경고 중 연장전"(D13)을 볼 수 없어요)
--   · D13 경고 중 연장전: 정상 가라앉기 취소, 물 멈춤, +20초에 설 곳 0
--   · 90초 전에는 4단·몸체가 남음 (결승이 시간 전에 설 곳을 잃지 않음)
--   · 두 방 동시 실행: 한 방의 연장전이 다른 방 데크·물·몸체를 건드리지 않음 (roundStates[ctx])
--   · 연장전 뒤 모델 전체(Decor·IntroCamera 포함) 충돌 파츠 0, 훅은 기다리지 않음
--   · D11 waveHit 하한 경계, D10 연장전 쿵 일정

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.OnsenClawLayout)
local Logic = RobloxRequire.require(Shared.maps.OnsenClawLogic)

local RShared = Shims.root("src/shared")
local RCF: any = roblox.CFrame

type Item = { at: number, seq: number, co: thread }
type Sim = {
	now: number,
	seq: number,
	queue: { Item },
	heartbeat: { (dt: number) -> () },
	mainWaits: number,
}

local implemented = false
local function ensureServerTime()
	if implemented then
		return
	end
	implemented = true
	pcall(roblox.implementMethod, "Workspace", "GetServerTimeNow", function()
		return 0
	end)
end

local function schedule(sim: Sim, at: number, co: thread)
	sim.seq += 1
	table.insert(sim.queue, { at = at, seq = sim.seq, co = co })
end

local function resume(co: thread, ...: any)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(`sim thread failed: {err}`)
	end
end

-- OnsenClaw를 코루틴 스케줄러 task로 불러요
local function loadMap(sim: Sim): any
	ensureServerTime()
	local fakeTask = {
		spawn = function(fn: any, ...: any): any
			local co = coroutine.create(fn)
			resume(co, ...)
			return co
		end,
		delay = function(seconds: number, fn: any, ...: any): any
			local args = table.pack(...)
			local co = coroutine.create(function()
				fn(table.unpack(args, 1, args.n))
			end)
			schedule(sim, sim.now + (seconds or 0), co)
			return co
		end,
		wait = function(seconds: number?): number
			if not coroutine.isyieldable() then
				sim.mainWaits += 1
				error("task.wait on a non-yieldable (hook) thread")
			end
			local dt = math.max(seconds or 0, 1 / 60)
			schedule(sim, sim.now + dt, coroutine.running())
			coroutine.yield()
			return dt
		end,
	}
	local heartbeat = {
		Connect = function(_self: any, fn: any)
			table.insert(sim.heartbeat, fn)
			return { Disconnect = function() end }
		end,
	}
	local env = table.clone(Shims.globals)
	env.script = RShared.maps.OnsenClaw
	env.require = function(node: any): any
		if node.Name == "MapSfx" then
			return { play = function() end }
		end
		return Shims.require(node)
	end
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return sim.now
		end,
	}
	env.game = {
		GetService = function(_self: any, name: string): any
			if name == "RunService" then
				return { Heartbeat = heartbeat }
			end
			return Shims.game:GetService(name)
		end,
	}
	env.workspace = {
		Raycast = function(): any
			return nil
		end,
	}
	local source = fs.readFile("src/shared/maps/OnsenClaw.luau")
	return luau.load(source, { debugName = "OnsenClaw(qa-sim)", environment = env })()
end

-- sim.now를 dt씩 untilAt까지: 그 시각까지 깨어날 스레드를 돌리고 Heartbeat
local function advance(sim: Sim, untilAt: number, dt: number?)
	local step = dt or 0.05
	while sim.now < untilAt - 1e-9 do
		sim.now = math.min(sim.now + step, untilAt)
		while true do
			table.sort(sim.queue, function(a: Item, b: Item): boolean
				if a.at ~= b.at then
					return a.at < b.at
				end
				return a.seq < b.seq
			end)
			local item = sim.queue[1]
			if item == nil or item.at > sim.now + 1e-9 then
				break
			end
			table.remove(sim.queue, 1)
			if coroutine.status(item.co) == "suspended" then
				resume(item.co)
			end
		end
		for _, fn in sim.heartbeat do
			fn(step)
		end
	end
end

local function newCtx(model: any, origin: any, racers: { any }): any
	local ctx: any = {
		model = model,
		origin = origin,
		cleanup = { items = {} },
		active = true,
		eliminated = {} :: { string },
		targetCount = 1,
	}
	function ctx.cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		local out = {}
		for _, r in racers do
			if not table.find(ctx.eliminated, r.Name) then
				table.insert(out, r)
			end
		end
		return out
	end
	ctx.eliminate = function(player: any)
		if not table.find(ctx.eliminated, player.Name) then
			table.insert(ctx.eliminated, player.Name)
		end
	end
	ctx.pass = function() end
	return ctx
end

local function racer(name: string, origin: any, angle: number, dist: number, footY: number): any
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	local x, z = Layout.polar(angle, dist)
	root.CFrame = origin * RCF.new(x, footY + Layout.FOOT_OFFSET, z)
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Parent = character
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

local function decksOf(model: any): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:HasTag("OnsenDeck") then
			table.insert(list, d)
		end
	end
	return list
end

-- 그 단 데크 중 조각이 하나라도 충돌하는 데크 수
local function solidDecks(model: any, tier: number): number
	local n = 0
	for _, deck in decksOf(model) do
		if deck:GetAttribute("Tier") == tier then
			for _, p in deck:GetChildren() do
				if p:IsA("BasePart") and p.CanCollide then
					n += 1
					break
				end
			end
		end
	end
	return n
end

-- 모델 전체(장식·소개 카메라·고리 포함)의 충돌 파츠
local function allColliders(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(out, d)
		end
	end
	return out
end

local function waterY(model: any, origin: any): number
	local water = model:FindFirstChild("OnsenWater")
	local rel = origin:PointToObjectSpace(water.CFrame.Position)
	return rel.Y + water.Size.X / 2 -- 세운 원판: 두께가 로컬 X
end

local function newSim(): Sim
	return { now = 0, seq = 0, queue = {}, heartbeat = {}, mainWaits = 0 }
end

return function(t: Test.Test)
	t.test(
		"QA D13: 3단 경고 중 연장전 → 정상 가라앉기 취소, 물 멈춤, +20초에 설 곳 0",
		function()
			local sim = newSim()
			local map = loadMap(sim)
			local origin = RCF.new(0, 300, 0)
			local model = map.build(origin)
			model.Parent = Shims.globals.workspace
			-- 4단 위 가상의 사람: 발 3.4 (물 2면 안전, 물이 70초 4까지 오르면 3.4 < 3.5로 탈락)
			local probe = racer("Probe", origin, 90, 13, 3.4)
			local ctx = newCtx(model, origin, { probe })
			map.start(ctx)

			advance(sim, 58)
			t.eq(solidDecks(model, 1), 0, "tier 1 sunk at 20")
			t.eq(solidDecks(model, 2), 0, "tier 2 sunk at 40")
			t.eq(solidDecks(model, 3), 6, "tier 3 still solid (warning since 57)")
			t.eq(Logic.deckState(3, 58), "Warn")

			local hookAt = sim.now
			map.overtime(ctx, { collapseDuration = Config.Final.CollapseDuration })
			t.eq(sim.now, hookAt, "hook returns immediately")
			t.eq(sim.mainWaits, 0, "no task.wait in the hook")

			-- 정상 일정(60초에 3단 전체)은 취소: 연장전 순서(남은 10개, 2초 간격)로 첫 3단 데크만 60초에
			advance(sim, 59.9)
			t.eq(solidDecks(model, 3), 6, "normal 60s sink cancelled")
			advance(sim, 60.5)
			t.eq(solidDecks(model, 3), 5, "overtime order: one tier-3 deck at +2")
			t.eq(solidDecks(model, 4), 4)

			-- 물은 연장전 시각(58초 → 판정 2)에서 멈춰요
			advance(sim, 75)
			t.ok(table.find(ctx.eliminated, "Probe") == nil, "water stopped rising after overtime")
			t.ok(
				waterY(model, origin) <= Logic.waterVisual(58) + 1e-3,
				`visible water stopped ({waterY(model, origin)})`
			)

			advance(sim, hookAt + Config.Final.CollapseDuration + 0.5)
			t.eq(#allColliders(model), 0, "nothing collides anywhere after collapse (Decor included)")
			for _, deck in decksOf(model) do
				for _, p in deck:GetChildren() do
					if p:IsA("BasePart") then
						t.ok(not p.CanQuery and not p.CanTouch, `{deck.Name}/{p.Name} still queryable`)
					end
				end
			end
			model:Destroy()
		end
	)

	t.test(
		"QA: 연장전이 없으면 89.9초까지 4단 데크 4개와 몸체가 남아요 (시간 전에 설 곳이 바닥나지 않음)",
		function()
			local sim = newSim()
			local map = loadMap(sim)
			local origin = RCF.new(0, 300, 0)
			local model = map.build(origin)
			model.Parent = Shims.globals.workspace
			local top = racer("Top", origin, 0, 13.5, 6) -- 4단에 서 있음
			local ctx = newCtx(model, origin, { top })
			map.start(ctx)
			advance(sim, 89.9, 0.1)
			t.eq(solidDecks(model, 1), 0)
			t.eq(solidDecks(model, 2), 0)
			t.eq(solidDecks(model, 3), 0)
			t.eq(solidDecks(model, 4), 4, "tier 4 survives until overtime")
			t.eq(model:FindFirstChild("ClawBody").CanCollide, true)
			t.eq(#ctx.eliminated, 0, "standing on tier 4 is dry at water 4.5")
			model:Destroy()
		end
	)

	t.test(
		"QA: 두 방이 같은 맵을 동시에 — 한 방의 연장전이 다른 방을 건드리지 않아요",
		function()
			local sim = newSim()
			local map = loadMap(sim)
			local originA = RCF.new(0, 300, 0)
			local originB = RCF.new(2000, 300, 0)
			local modelA = map.build(originA)
			local modelB = map.build(originB)
			modelA.Parent = Shims.globals.workspace
			modelB.Parent = Shims.globals.workspace
			local ctxA = newCtx(modelA, originA, {})
			local ctxB = newCtx(modelB, originB, {})
			map.start(ctxA)
			map.start(ctxB)
			advance(sim, 30)
			map.overtime(ctxA, { collapseDuration = 20 })
			advance(sim, 51)
			t.eq(#allColliders(modelA), 0, "room A collapsed")
			t.eq(solidDecks(modelB, 2), 0, "room B tier 2 sank on its own schedule (40s)")
			t.eq(solidDecks(modelB, 3), 6, "room B tier 3 untouched")
			t.eq(solidDecks(modelB, 4), 4, "room B tier 4 untouched")
			t.eq(modelB:FindFirstChild("ClawBody").CanCollide, true, "room B body untouched")
			t.ok(
				waterY(modelB, originB) > waterY(modelA, originA) + 1,
				`room B water keeps rising (A {waterY(modelA, originA)}, B {waterY(modelB, originB)})`
			)
			modelA:Destroy()
			modelB:Destroy()
		end
	)

	t.test("QA D11: waveHit 경계 — 발 = 윗면 − 1.5는 맞고, 그보다 낮으면 안 맞아요", function()
		local top = 4
		t.ok(Logic.waveHit(20, 19.5, 20.2, top - 1.5, top), "foot exactly top - 1.5")
		t.ok(not Logic.waveHit(20, 19.5, 20.2, top - 1.51, top), "below the lower bound")
		-- 고리 앞면 경계: dist == radius면 맞음, dist == prevRadius면 이미 지나감
		t.ok(Logic.waveHit(20, 19.5, 20, top, top), "front exactly at dist")
		t.ok(not Logic.waveHit(20, 20, 20.4, top, top), "dist exactly prevRadius")
		-- 레이캐스트 길이(루트 → 발 3 + 1.5)가 하한과 같아요
		t.ok(Layout.FOOT_OFFSET + Logic.BELOW_TOLERANCE <= 4.5 + 1e-9, "probe reaches the lower bound")
	end)

	t.test(
		"QA D10: 90초 연장전 쿵 — 86 다음 93, 그 뒤 3초 간격·고리 2개, 넉백 면제 ≥ 붙잡기 + 넘어짐",
		function()
			local list = Logic.slamTimes(90, 110)
			local after: { number } = {}
			for _, slam in list do
				if slam.at > 86 then
					table.insert(after, slam.at)
					t.eq(slam.rings, 2)
				end
			end
			t.eq(after[1], 93)
			for i = 2, #after do
				t.eq(after[i] - after[i - 1], 3)
			end
			local plain = Logic.slamTimes(nil, 90)
			t.eq(plain[#plain].at, 86)
			t.ok(Logic.KNOCK_MOVE_EXEMPT >= Logic.KNOCK_HOLD + Logic.KNOCKDOWN_TIME, "exempt covers the knockback")
		end
	)
end
