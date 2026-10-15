--!strict
-- m5-33 QA (docs/qa/m5-33-map-batch-3-foundation.md): 껍데기 6개의 start·overtime을 가짜 Heartbeat·가짜 task로 돌려 봐요.
--   낙하선: origin 로컬 Y −25 경계(−24.9는 무사, −25.1은 탈락), 아레나 슬롯 origin(높이 300, 2000 떨어짐)에서도 로컬 기준
--   Race: 로컬 −Z가 결승선 거리 이상이면 통과, 바로 앞은 아님. 통과 뒤 라운드가 끝나면 그 틱의 나머지는 안 봄
--   라운드가 끝나면(isActive false) 판정 없음, Heartbeat 연결은 ctx.cleanup에 하나
--   Final 연장전: 훅이 바로 돌아옴(task.wait 없음), task.delay(collapseDuration) 하나가 ctx.cleanup에,
--     시간이 되면 판정 충돌 파츠 0개(매달릴 곳 없음), 라운드가 이미 끝났으면 손대지 않음, 다른 방 모델은 그대로
--   Race 결승선 자체도 판정 바닥 위(통과 순간 서 있을 바닥이 있음, D6)
-- 맵 스펙(m5-34~39)이 파일을 덮어쓰면 머리 주석의 "m5-33 껍데기"가 사라져서 그 맵은 이 검사에서 빠져요
-- (실제 맵은 각 맵 테스트가 봐요). 공용 테스트를 다시 고칠 일이 없게 했어요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Batch3 = require("./lib/Batch3")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local MODULE = {
	["dish-sink"] = "DishSink",
	["space-conveyor"] = "SpaceConveyor",
	["rice-cooker"] = "RiceCooker",
	["fish-market"] = "FishMarket",
	["tea-garden"] = "TeaGarden",
	["onsen-claw"] = "OnsenClaw",
}

local SHELL_MARK = "m5-33 껍데기"
local FALL_DEPTH = 25
local RACE_LENGTH = 160

local function sourceOf(id: string): string
	return fs.readFile(`src/shared/maps/{MODULE[id]}.luau`)
end

local function isShell(id: string): boolean
	return string.find(sourceOf(id), SHELL_MARK, 1, true) ~= nil
end

---------------------------------------------------------------- 가짜 환경

type Harness = {
	map: any,
	heartbeat: any,
	delays: { { seconds: number, fn: () -> () } },
	waits: number,
}

local function newHarness(id: string): Harness
	local handlers: { any } = {}
	local heartbeat = {}
	function heartbeat:Connect(fn: any)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
			__isConnection = true,
		}
	end
	function heartbeat:Fire(...)
		for _, h in table.clone(handlers) do
			if h.connected then
				h.fn(...)
			end
		end
	end
	local harness: Harness = { map = nil, heartbeat = heartbeat, delays = {}, waits = 0 }
	local fakeTask = {
		delay = function(seconds: number, fn: any): any
			table.insert(harness.delays, { seconds = seconds, fn = fn })
			return { __isThread = true }
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return { __isThread = true }
		end,
		wait = function(): number
			harness.waits += 1
			error("task.wait is not allowed in a map hook")
		end,
	}
	local parent = setmetatable({}, {
		__index = function(_, name: string)
			return { __stub = name }
		end,
	})
	harness.map = luau.load(sourceOf(id), {
		debugName = MODULE[id],
		environment = {
			script = { Parent = parent },
			require = function(_target: any): any
				return { LIGHTING = {} }
			end,
			task = fakeTask,
			game = {
				GetService = function(_, name: string)
					if name == "RunService" then
						return { Heartbeat = heartbeat }
					end
					error(`unexpected service {name}`)
				end,
			},
		},
	})()
	return harness
end

local function newCleanup(): any
	local cleanup = { items = {} :: { any } }
	function cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	return cleanup
end

local function fakePlayer(name: string, origin: any, x: number, y: number, z: number): any
	local root = {
		Position = origin:PointToWorldSpace(RV3.new(x, y, z)),
		IsA = function(_, cls: string)
			return cls == "BasePart"
		end,
	}
	local character = {
		FindFirstChild = function(_, childName: string)
			if childName == "HumanoidRootPart" then
				return root
			end
			return nil
		end,
	}
	return { Name = name, Character = character, root = root }
end

local function newCtx(model: any, origin: any, racers: { any }): any
	local ctx: any = {
		model = model,
		origin = origin,
		cleanup = newCleanup(),
		active = true,
		passed = {} :: { string },
		eliminated = {} :: { string },
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return racers
	end
	ctx.pass = function(player: any)
		table.insert(ctx.passed, player.Name)
	end
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, player.Name)
	end
	return ctx
end

-- 판정 충돌 파츠 (Decor·Spawns·IntroCamera 밖, CanCollide)
local function judgmentColliders(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local skip = false
			local p = d.Parent
			while p and p ~= model do
				if p.Name == "Decor" or p.Name == "Spawns" or p.Name == "IntroCamera" then
					skip = true
					break
				end
				p = p.Parent
			end
			if not skip then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function over(model: any, position: any): boolean
	for _, d in judgmentColliders(model) do
		local localPos = d.CFrame:PointToObjectSpace(position)
		local half = d.Size / 2
		local above = localPos.Y - half.Y
		if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z and above >= -0.5 and above <= 6 then
			return true
		end
	end
	return false
end

local ARENA_ORIGIN = RCF.new(0, 300, 2000) -- Config.Arena 슬롯과 같은 모양 (높이 300, 간격 2000)

return function(t: Test.Test)
	t.test("QA: 지금 6개 모두 m5-33 껍데기예요 (이 파일의 검사 대상)", function()
		for _, id in Batch3.IDS do
			-- 맵 스펙이 덮어쓰면 false가 돼도 되지만, m5-33 시점에는 6개 모두 껍데기
			if RMaps.get(id).inPool == false then
				t.ok(isShell(id), `{id} still a shell`)
			end
		end
	end)

	t.test(
		"QA 낙하선: origin 로컬 Y −25 경계, 아레나 슬롯 origin 기준, Heartbeat 연결은 cleanup에",
		function()
			for _, id in Batch3.IDS do
				if not isShell(id) then
					continue
				end
				local h = newHarness(id)
				local safe = fakePlayer("safe", ARENA_ORIGIN, 0, -(FALL_DEPTH - 0.1), -40)
				local fallen = fakePlayer("fallen", ARENA_ORIGIN, 0, -(FALL_DEPTH + 0.1), -40)
				-- 월드 Y는 275 근처라 월드 기준이었다면 둘 다 "안 떨어짐" — 로컬 기준인지 확인
				local ctx = newCtx(nil, ARENA_ORIGIN, { safe, fallen })
				h.map.start(ctx)
				t.eq(#ctx.cleanup.items, 1, `{id} one Heartbeat connection in cleanup`)
				t.eq(h.waits, 0, `{id} start does not wait`)
				h.heartbeat:Fire(1 / 60)
				t.eq(ctx.eliminated, { "fallen" }, `{id} only the fallen one`)
				t.eq(ctx.passed, {}, `{id} nobody passes`)

				-- 라운드가 끝나면 판정 없음
				local h2 = newHarness(id)
				local ctx2 = newCtx(nil, ARENA_ORIGIN, { fallen })
				h2.map.start(ctx2)
				ctx2.active = false
				h2.heartbeat:Fire(1 / 60)
				t.eq(ctx2.eliminated, {}, `{id} inactive round does not judge`)
			end
		end
	)

	t.test(
		"QA Race 결승: 로컬 −Z ≥ 160이면 통과, 159.9는 아님, 통과로 라운드가 끝나면 그 틱 멈춤",
		function()
			for _, id in Batch3.IDS do
				if Batch3.KIND[id] ~= "Race" or not isShell(id) then
					continue
				end
				local h = newHarness(id)
				local near = fakePlayer("near", ARENA_ORIGIN, 0, 1, -(RACE_LENGTH - 0.1))
				local at = fakePlayer("at", ARENA_ORIGIN, 0, 1, -RACE_LENGTH)
				local beyond = fakePlayer("beyond", ARENA_ORIGIN, 0, 1, -(RACE_LENGTH + 5))
				local ctx = newCtx(nil, ARENA_ORIGIN, { near, at, beyond })
				h.map.start(ctx)
				h.heartbeat:Fire(1 / 60)
				t.eq(ctx.passed, { "at", "beyond" }, `{id} pass boundary`)

				-- 첫 통과로 라운드가 끝나면(targetCount 도달) 같은 틱의 다음 사람은 안 봐요
				local h2 = newHarness(id)
				local ctx2 = newCtx(nil, ARENA_ORIGIN, { at, beyond })
				ctx2.pass = function(player: any)
					table.insert(ctx2.passed, player.Name)
					ctx2.active = false
				end
				h2.map.start(ctx2)
				h2.heartbeat:Fire(1 / 60)
				t.eq(ctx2.passed, { "at" }, `{id} stops after the round ends`)

				-- 결승선 자체도 판정 바닥 위 (D6: 바닥이 결승선 너머까지)
				local model = RMaps.get(id).build(RCF.new())
				local finish = model:FindFirstChild("FinishLine", true)
				t.ok(finish ~= nil and over(model, finish.CFrame.Position), `{id} FinishLine over the floor`)
				t.eq(finish and finish.CanCollide, false, `{id} FinishLine has no collision`)
			end
		end
	)

	t.test(
		"QA 연장전(Final 껍데기): 바로 돌아옴, delay 하나가 cleanup에, 시간이 되면 충돌 파츠 0개",
		function()
			for _, id in Batch3.IDS do
				if Batch3.KIND[id] ~= "Final" or not isShell(id) then
					continue
				end
				local model = RMaps.get(id).build(ARENA_ORIGIN)
				local other = RMaps.get(id).build(ARENA_ORIGIN * RCF.new(2000, 0, 0)) -- 같은 맵을 도는 다른 방
				t.ok(#judgmentColliders(model) > 0, `{id} has a floor before overtime`)

				local h = newHarness(id)
				local ctx = newCtx(model, ARENA_ORIGIN, {})
				local before = os.clock()
				h.map.overtime(ctx, { collapseDuration = 20 })
				t.ok(os.clock() - before < 0.05, `{id} overtime returns at once`)
				t.eq(h.waits, 0, `{id} no task.wait in overtime`)
				t.eq(#h.delays, 1, `{id} one scheduled collapse`)
				t.eq(h.delays[1] and h.delays[1].seconds, 20, `{id} collapse at collapseDuration`)
				t.eq(#ctx.cleanup.items, 1, `{id} the delay thread is in ctx.cleanup`)
				t.ok(#judgmentColliders(model) > 0, `{id} floor stays until the delay fires`)

				h.delays[1].fn()
				t.eq(#judgmentColliders(model), 0, `{id} nothing to stand or hang on after collapse`)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and d.Name == "Plate" then
						t.eq(d.Transparency, 1, `{id} plate hidden`)
					end
				end
				t.ok(#judgmentColliders(other) > 0, `{id} another room's model is untouched`)

				-- 라운드가 먼저 끝났으면 손대지 않아요
				local h2 = newHarness(id)
				local ctx2 = newCtx(other, ARENA_ORIGIN, {})
				h2.map.overtime(ctx2, { collapseDuration = 20 })
				ctx2.active = false
				h2.delays[1].fn()
				t.ok(#judgmentColliders(other) > 0, `{id} inactive round keeps the floor`)
			end
		end
	)

	t.test("QA: Race·Survival 껍데기에는 overtime이 없고, 모듈 수준 가변 상태가 없어요", function()
		for _, id in Batch3.IDS do
			local map = RMaps.get(id)
			if Batch3.KIND[id] ~= "Final" then
				t.eq(map.overtime, nil, `{id} no overtime`)
			end
			if isShell(id) then
				local src = sourceOf(id)
				-- 모듈 수준(들여쓰기 없는) local은 상수·함수·require뿐 — 테이블·카운터 상태 없음
				for line in string.gmatch(src, "[^\n]+") do
					local name, value = string.match(line, "^local ([%w_]+)%s*[:%w_%.]*%s*=%s*(.+)$")
					if name and value then
						local ok = string.find(value, "^require%(") ~= nil
							or string.find(value, "^%-?[%d%.]+") ~= nil
							or string.find(value, '^"') ~= nil
							or string.find(value, "^%d+%s*//") ~= nil
						if not ok and value ~= "{" then
							ok = string.find(value, "^[%u_]+%s*[%*/%+%-]") ~= nil
						end
						t.ok(ok or name == "map", `{id} module-level local {name} = {value}`)
					end
				end
			end
		end
	end)
end
