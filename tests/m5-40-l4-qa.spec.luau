--!strict
-- m5-40 L4 QA (docs/qa/m5-40-l4.md): Survival 5개의 실제 start()를 가짜 시계·가짜 task·가짜 Heartbeat로 75초까지 돌려
-- 60초 서든데스 경계가 매끄럽게 넘어가는지 봐요 (m5-33-qa·m5-36-qa 패턴).
--   hot-plate        59.5초에 밟은 타일은 1.5초(61.0초)에, 60.2초에 밟은 타일은 1.2초(61.4초)에 사라져요.
--                    이미 달아오르던 타일은 서든데스 값(1.2)으로 바뀌지 않아요(색·Neon도 1.5초 기준).
--   chef-board       60초 뒤 칼 경고가 61.5·64·66.5·69·71.5·74초, 60·70초에 도마가 기울고, 75초에 가운데 3×3 9칸이 남아요.
--   tempura-pot      23층 발은 63.4초 무사·63.7초 튀겨짐, 27·31층은 75초까지 무사, 기름 파츠 윗면이 25에서 멈춰요,
--                    60초 뒤 튀는 기름 간격 1.2초.
--   giant-jenga      75초에 가운데 3×3이 3단 그대로·평평·충돌 있음, 테두리 48칸이 75초 전에 다 사라진 뒤에도 오류 없음.
--   cat-cafe-shelves 공(장난감) 위치가 60초 경계에서 한 프레임에 튀지 않고, 60초 뒤 고양이 발 경고 간격 1.6초.
--   다섯 맵 모두 75초까지 스레드 오류 없음 (resume 실패면 테스트가 터져요).
--   L4-D1 (철판 바닥이 75초 전에 바닥남): RoundLogic Survival 일정 75초, 바닥이 바닥나 차례로 떨어지면 목표 인원에서
--     끝나고 남은 사람 통과, 한 묶음에 전원이 떨어져도 결승 진출 2명 구제. 바닥이 바닥나는 인원 경계(4명 OK·5명 약 70초·
--     6명은 60초 시절에도 바닥남).

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
local Maps = RobloxRequire.require(Shared.maps)
local Rules = RobloxRequire.require(Shared.Rules)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local HotLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local HotArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local ChefLogic = RobloxRequire.require(Shared.maps.ChefBoardLogic)
local TempuraLayout = RobloxRequire.require(Shared.maps.TempuraPotLayout)
local TempuraLogic = RobloxRequire.require(Shared.maps.TempuraPotLogic)
local JengaLayout = RobloxRequire.require(Shared.maps.GiantJengaLayout)
local CatLayout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)
local CatLogic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

pcall(roblox.implementMethod, "ParticleEmitter", "Emit", function(_self: any, _count: number) end)

local STEP = 1 / 32 -- 2의 거듭제곱이라 시각이 정확히 쌓여요
local ORIGIN = RCF.new(0, 300, 2000)

---------------------------------------------------------------- 가짜 환경

type Harness = {
	map: any,
	now: number,
	advance: (seconds: number) -> (),
	onTick: { (now: number) -> () },
	cues: { { cue: string, at: number } },
	marks: { any },
	roots: { any },
}

-- Shims와 같은 `<이름>.Position` 읽기 바꾸기 (Lune은 BasePart.Position을 못 읽어요)
local function rewritePositionReads(source: string): string
	return (
		string.gsub(source, "([%a_][%w_%.]*)%.Position(%s*)(=?)(=?)", function(target, space, eq1, eq2)
			if eq1 == "=" and eq2 ~= "=" then
				return nil
			end
			return `__pos({target}){space}{eq1}{eq2}`
		end)
	)
end

local function worldBounds(part: any): (any, any)
	local cf, half = part.CFrame, part.Size / 2
	local minV = RV3.new(math.huge, math.huge, math.huge)
	local maxV = RV3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = cf:PointToWorldSpace(RV3.new(sx * half.X, sy * half.Y, sz * half.Z))
				minV = minV:Min(w)
				maxV = maxV:Max(w)
			end
		end
	end
	return minV, maxV
end

-- 레이캐스트 대상(철판 타일·선반·발판)은 움직이지 않아요 — 상자를 한 번만 계산해요 (사라지면 CanQuery로 빠져요)
local boundsCache: { [any]: { any } } = setmetatable({}, { __mode = "k" }) :: any
local function cachedBounds(part: any): (any, any)
	local hit = boundsCache[part]
	if hit == nil then
		local minV, maxV = worldBounds(part)
		hit = { minV, maxV }
		boundsCache[part] = hit
	end
	return hit[1], hit[2]
end
local candidatesCache: { [any]: { any } } = setmetatable({}, { __mode = "k" }) :: any

local function newHarness(mapFile: string): Harness
	local harness: any = { now = 0, onTick = {}, cues = {}, marks = {}, roots = {} }
	local sleepers: { { at: number, started: number, tick: number, co: thread?, fn: any, args: { any }? } } = {}
	local tick = 0
	local handlers: { any } = {}

	local function resume(co: thread, ...: any)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(`thread failed at {harness.now}: {err}`, 0)
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
	function heartbeat:Wait(): number
		assert(coroutine.isyieldable(), "Heartbeat:Wait outside a thread")
		table.insert(sleepers, { at = harness.now, started = harness.now, tick = tick, co = coroutine.running() })
		return coroutine.yield()
	end

	local fakeTask = {
		spawn = function(fn: any, ...: any): any
			local co = if type(fn) == "thread" then fn else coroutine.create(fn)
			resume(co, ...)
			return co
		end,
		delay = function(seconds: number, fn: any, ...: any): any
			local entry = { at = harness.now + seconds, started = harness.now, tick = tick, fn = fn, args = { ... } }
			table.insert(sleepers, entry)
			return entry
		end,
		wait = function(seconds: number?): number
			assert(coroutine.isyieldable(), "task.wait outside a thread")
			table.insert(
				sleepers,
				{ at = harness.now + (seconds or 0), started = harness.now, tick = tick, co = coroutine.running() }
			)
			return coroutine.yield()
		end,
	}

	function harness.advance(seconds: number)
		local target = harness.now + seconds
		while harness.now < target - 1e-9 do
			harness.now = math.min(target, harness.now + STEP)
			tick += 1
			for _, fn in harness.onTick do
				fn(harness.now)
			end
			for _, h in table.clone(handlers) do
				if h.connected then
					h.fn(STEP)
				end
			end
			while true do
				local dueIndex: number? = nil
				for i, s in sleepers do
					local due = s.at <= harness.now + 1e-9 and s.tick < tick
					if due and (dueIndex == nil or s.at < sleepers[dueIndex].at) then
						dueIndex = i
					end
				end
				if dueIndex == nil then
					break
				end
				local s = table.remove(sleepers, dueIndex) :: any
				if s.co then
					if coroutine.status(s.co) == "suspended" then
						resume(s.co, harness.now - s.started)
					end
				else
					resume(coroutine.create(s.fn), table.unpack(s.args))
				end
			end
		end
	end

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

	-- 아래로 쏘는 레이캐스트만: FilterDescendantsInstances(Include) 중 XZ 상자 안이고 윗면이 레이 길이 안인 가장 높은 파츠
	local fakeWorkspace = {
		Raycast = function(_self: any, origin: any, direction: any, params: any): any
			local length = direction.Magnitude
			local best, bestTop = nil, -math.huge
			for _, inst in params.FilterDescendantsInstances or {} do
				local candidates = candidatesCache[inst]
				if candidates == nil then
					local list = {}
					for _, d in { inst, table.unpack(inst:GetDescendants()) } do
						if d:IsA("BasePart") then
							table.insert(list, d)
						end
					end
					candidates = list
					candidatesCache[inst] = list
				end
				for _, part in candidates :: { any } do
					if part.CanQuery ~= false then
						local minV, maxV = cachedBounds(part)
						if
							origin.X >= minV.X
							and origin.X <= maxV.X
							and origin.Z >= minV.Z
							and origin.Z <= maxV.Z
							and maxV.Y <= origin.Y + 1e-6
							and origin.Y - maxV.Y <= length
							and maxV.Y > bestTop
						then
							best, bestTop = part, maxV.Y
						end
					end
				end
			end
			if best == nil then
				return nil
			end
			return { Instance = best, Position = RV3.new(origin.X, bestTop, origin.Z), Normal = RV3.new(0, 1, 0) }
		end,
	}

	local fakeMoveExempt = {
		mark = function(character: any, seconds: number?)
			table.insert(harness.marks, { character = character, seconds = seconds or 0, at = harness.now })
		end,
	}
	local fakeSfx = {
		play = function(_part: any, cue: string)
			table.insert(harness.cues, { cue = cue, at = harness.now })
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
	env.workspace = fakeWorkspace
	env.os = {
		clock = function(): number
			return harness.now
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
	env.__pos = function(value: any): any
		if typeof(value) == "Instance" and value:IsA("BasePart") then
			return value.CFrame.Position
		end
		if type(value) == "table" and value.CFrame ~= nil then
			return value.CFrame.Position -- proxyRacer 루트
		end
		return value.Position
	end
	local source = rewritePositionReads(fs.readFile(`src/shared/maps/{mapFile}.luau`))
	harness.map = luau.load(source, { debugName = `{mapFile}(L4 QA)`, environment = env })()
	return harness :: Harness
end

local function newCtx(model: any, origin: any, racers: { any }, rng: any): any
	local ctx: any = {
		model = model,
		origin = origin,
		rng = rng,
		targetCount = 1,
		cleanup = { items = {} },
		active = true,
		eliminated = {} :: { { name: string, at: number } },
		racers = racers,
	}
	function ctx.cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return ctx.racers
	end
	ctx.pass = function() end
	return ctx
end

local function seededRng(seed: number): any
	local state = seed
	local function nextRaw(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_self: any, min: number?, max: number?): number
			local lo, hi = min or 0, max or 1
			return lo + nextRaw() * (hi - lo)
		end,
		NextInteger = function(_self: any, min: number, max: number): number
			return min + math.floor(nextRaw() * (max - min + 1))
		end,
	}
end

-- 진짜 Lune 인스턴스 캐릭터. 루트 = origin * (x, y, z) (로컬)
local function racer(name: string, x: number, y: number, z: number): any
	local character = RInstance.new("Model")
	character.Name = name
	local root = RInstance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = ORIGIN * RCF.new(x, y, z)
	root.Parent = character
	local attachment = RInstance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local humanoid = RInstance.new("Humanoid")
	humanoid.Parent = character
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

-- 도마처럼 루트의 AssemblyLinearVelocity를 읽는 맵용 (Lune 파츠는 그 값을 못 읽어요): 표로 만든 루트·캐릭터
local function proxyRacer(name: string, x: number, y: number, z: number): any
	local root: any = { Name = "HumanoidRootPart", CFrame = ORIGIN * RCF.new(x, y, z) }
	root.AssemblyLinearVelocity = RV3.new(0, 0, 0)
	function root:IsA(className: string): boolean
		return className == "BasePart" or className == "Part"
	end
	local holder = RInstance.new("Model")
	local humanoid = RInstance.new("Humanoid")
	humanoid.Parent = holder
	local character: any = { Name = name }
	function character:FindFirstChild(childName: string): any
		return if childName == "HumanoidRootPart" then root else nil
	end
	function character:FindFirstChildOfClass(className: string): any
		return if className == "Humanoid" then humanoid else nil
	end
	return { Name = name, Character = character, root = root, humanoid = humanoid }
end

local function moveTo(player: any, x: number, y: number, z: number)
	player.root.CFrame = ORIGIN * RCF.new(x, y, z)
end

local function startMap(h: Harness, id: string, racers: { any }, rng: any): (any, any)
	local model = RMaps.get(id).build(ORIGIN)
	table.insert(h.roots, model)
	local ctx = newCtx(model, ORIGIN, racers, rng)
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, { name = player.Name, at = h.now })
		local i = table.find(ctx.racers, player)
		if i then
			table.remove(ctx.racers, i)
		end
	end
	h.map.start(ctx)
	return model, ctx
end

local function cueTimes(h: Harness, cue: string, from: number?): { number }
	local out = {}
	for _, c in h.cues do
		if c.cue == cue and c.at >= (from or -math.huge) then
			table.insert(out, c.at)
		end
	end
	return out
end

local function gaps(times: { number }): { number }
	local out = {}
	for k = 2, #times do
		table.insert(out, times[k] - times[k - 1])
	end
	return out
end

local function local3(cf: any): any
	return ORIGIN:PointToObjectSpace(cf.Position)
end

return function(t: Test.Test)
	---------------------------------------------------------------- 뜨거운 철판
	t.test(
		"QA hot-plate: 59.5초에 밟은 타일은 1.5초(61.0) 유지, 60.2초에 밟은 타일은 1.2초(61.4)에 사라져요",
		function()
			local h = newHarness("HotPlate")
			-- 맨 위층 타일 두 개 (서로 떨어진 것)
			local topY = HotLogic.layerTopY(1)
			local offsets = HotLogic.tileOffsets()
			local a = racer("a", 500, topY + 3, 500) -- 처음엔 철판 밖 (발밑 타일 없음)
			local b = racer("b", 500, topY + 3, 500)
			local model, ctx = startMap(h, "hot-plate", { a, b }, seededRng(1))
			-- 맨 위층(높이가 가장 높은) HotTile 중 서로 다른 둘
			local tiles = {}
			for _, d in model:GetDescendants() do
				if d:HasTag("HotTile") then
					local _, maxV = worldBounds(d)
					if math.abs(maxV.Y - (ORIGIN.Position.Y + topY)) < 0.6 then
						table.insert(tiles, d)
					end
				end
			end
			t.eq(#tiles, HotLogic.GRID_SIZE * HotLogic.GRID_SIZE, `top layer tiles ({#offsets} offsets)`)
			local tileA, tileB = tiles[1], tiles[#tiles]
			local pa, pb = local3(tileA.CFrame), local3(tileB.CFrame)

			h.advance(59.5 - h.now)
			moveTo(a, pa.X, topY + 3, pa.Z)
			h.advance(STEP) -- 밟힘
			moveTo(a, 500, topY + 3, 500) -- 바로 내려옴 (그래도 달아오름은 계속)
			local steppedA = h.now
			t.ok(steppedA < 60, "A stepped before sudden death")

			h.advance(60.2 - h.now)
			moveTo(b, pb.X, topY + 3, pb.Z)
			h.advance(STEP)
			moveTo(b, 500, topY + 3, 500)
			local steppedB = h.now
			t.ok(steppedB >= 60, "B stepped in sudden death")

			-- A: 1.2초 기준이면 이미 빛났을 시각(steppedA + 1.2 × 0.6 + 0.1)에도 아직 Neon이 아니에요 (색이 튀지 않음)
			h.advance(steppedA + 1.2 * HotArt.GLOW_FROM + 0.1 - h.now)
			t.ok(tileA.Material ~= roblox.Enum.Material.Neon, "A keeps 1.5s colour curve (no early glow)")
			-- A: 1.2초 기준 사라질 시각을 넘겨도 그대로
			h.advance(steppedA + 1.2 + 0.1 - h.now)
			t.ok(tileA.CanCollide == true and tileA.Transparency < 1, "A not gone at +1.3 (old tile keeps 1.5)")
			h.advance(steppedA + 1.5 - 0.1 - h.now)
			t.ok(tileA.CanCollide == true, "A still there at +1.4")
			t.eq(tileA.Material, roblox.Enum.Material.Neon, "A glows before vanishing")
			h.advance(steppedA + 1.5 + 0.1 - h.now)
			t.eq(tileA.CanCollide, false, "A gone at +1.6")
			t.eq(tileA.Transparency, 1)

			-- B: 서든데스 타일은 1.2초
			h.advance(steppedB + 1.2 - 0.1 - h.now)
			t.ok(tileB.CanCollide == true, "B still there at +1.1")
			t.eq(tileB.Material, roblox.Enum.Material.Neon, "B glows before vanishing (1.2 × 0.6 = 0.72)")
			h.advance(steppedB + 1.2 + 0.1 - h.now)
			t.eq(tileB.CanCollide, false, "B gone at +1.3")
			t.eq(tileB.CanQuery, false, "B out of probes")

			-- 다른 타일은 그대로, 75초까지 오류 없이 돌아요
			local gone = 0
			for _, d in model:GetDescendants() do
				if d:HasTag("HotTile") and d.CanCollide == false then
					gone += 1
				end
			end
			t.eq(gone, 2, "only the two stepped tiles vanished")
			h.advance(75 - h.now)
			t.eq(ctx.eliminated, {}, "nobody below the elimination line")
		end
	)

	---------------------------------------------------------------- 셰프의 도마
	t.test(
		"QA chef-board: 실제 start 75초 — 서든데스 칼 6번(61.5~74), 60·70초 기울기, 가운데 3×3 9칸이 끝까지 남아요",
		function()
			for seed = 1, 3 do
				local h = newHarness("ChefBoard")
				local center = proxyRacer("center", 0, 3, 0)
				local model, ctx = startMap(h, "chef-board", { center }, seededRng(seed))
				local cellByKey: { [string]: any } = {}
				for _, d in model:GetDescendants() do
					if d:HasTag("ChefBoardCell") then
						cellByKey[`{d:GetAttribute("CellI")},{d:GetAttribute("CellJ")}`] = d
					end
				end
				local function centerCell(i: number, j: number): any
					local cell = cellByKey[`{i},{j}`]
					return if cell and cell.Parent ~= nil then cell else nil
				end
				local probe = centerCell(1, 1) -- 기울면 높이가 바뀌는 칸
				local flatY = local3(probe.CFrame).Y
				local tiltSeen: { [number]: boolean } = {}
				table.insert(h.onTick, function(now: number)
					local cell = centerCell(1, 1)
					if cell and math.abs(local3(cell.CFrame).Y - flatY) > 0.05 then
						tiltSeen[math.floor(now / 10) * 10] = true
					end
				end)

				h.advance(65)
				t.eq(tiltSeen[60], true, `seed {seed}: tilt at 60`)
				h.advance(10.5) -- 75.5초
				t.eq(tiltSeen[70], true, `seed {seed}: tilt at 70`)

				local warns = cueTimes(h, "ChefHandWarn", 60)
				t.eq(#warns, 6, `seed {seed}: 6 sudden-death strikes ({#warns})`)
				local expected = { 61.5, 64, 66.5, 69, 71.5, 74 }
				for k, at in warns do
					t.ok(math.abs(at - expected[k]) <= STEP + 1e-6, `seed {seed}: strike {k} at {at}`)
				end
				-- 칼은 74초 경고 뒤 내려치고(74.92) 다시 올라가요 — 다음 경고 전에 끝나서 밀리지 않아요
				local whoosh = cueTimes(h, "SkewerWhoosh", 60)
				t.eq(#whoosh, 6, `seed {seed}: 6 slams`)

				for i = -1, 1 do
					for j = -1, 1 do
						local cell = centerCell(i, j)
						t.ok(cell ~= nil and cell.CanCollide == true, `seed {seed}: center {i},{j} alive at 75`)
					end
				end
				t.eq(ctx.eliminated, {}, `seed {seed}: centre racer never judged as fallen`)
			end
		end
	)

	---------------------------------------------------------------- 튀김 냄비
	t.test(
		"QA tempura-pot: 실제 start — 23층 63.4초 무사·63.7초 튀겨짐, 27·31층 75초 무사, 기름 25에서 멈춤, 튀는 기름 1.2초",
		function()
			local h = newHarness("TempuraPot")
			local function raftOfTier(tier: number): any
				for _, raft in TempuraLayout.rafts() do
					if raft.tier == tier then
						return raft
					end
				end
				error(`no raft on tier {tier}`)
			end
			local r23, r27, r31 = raftOfTier(5), raftOfTier(6), raftOfTier(7)
			t.eq(r23.topY, 23)
			t.eq(r27.topY, 27)
			t.eq(r31.topY, 31)
			local foot = TempuraLayout.FOOT_OFFSET
			local p23 = racer("p23", r23.x, r23.topY + foot, r23.z)
			local p27 = racer("p27", r27.x, r27.topY + foot, r27.z)
			local p31 = racer("p31", r31.x, r31.topY + foot, r31.z)
			local model, ctx = startMap(h, "tempura-pot", { p23, p27, p31 }, seededRng(7))
			local oil = nil
			for _, d in model:GetDescendants() do
				if d:HasTag("HotOil") then
					oil = d
				end
			end
			t.ok(oil ~= nil, "oil part")

			-- 튀는 기름에 맞아도 이 테스트에는 물리가 없어 제자리예요 (판정 높이만 봐요)
			h.advance(63.4)
			t.eq(#ctx.eliminated, 0, "tier 23 still safe at 63.4")
			h.advance(0.3)
			t.eq(#ctx.eliminated, 1, "tier 23 fried by 63.7")
			t.eq(ctx.eliminated[1].name, "p23")
			t.ok(ctx.eliminated[1].at > 63.5 - 1e-6, `fried at {ctx.eliminated[1].at}`)

			h.advance(75 - h.now)
			t.eq(#ctx.eliminated, 1, "tiers 27 and 31 survive to 75")
			local _, oilMax = worldBounds(oil)
			local oilTop = oilMax.Y - ORIGIN.Position.Y
			t.ok(math.abs(oilTop - TempuraLogic.OIL_MAX_Y) < 0.6, `oil part top at 75 ≈ 25 ({oilTop})`)

			local splashes = cueTimes(h, "OilSplash", 61)
			t.ok(#splashes >= 10, `splashes after 61s ({#splashes})`)
			for _, gap in gaps(splashes) do
				t.ok(math.abs(gap - 1.2) <= 2 * STEP + 1e-6, `sudden-death splash gap {gap}`)
			end
		end
	)

	---------------------------------------------------------------- 와르르 나무 블록
	t.test(
		"QA giant-jenga: 실제 start 75초 — 가운데 3×3은 3단·평평·충돌 있음, 테두리가 다 빠진 뒤에도 오류 없음",
		function()
			for seed = 1, 3 do
				local h = newHarness("GiantJenga")
				local stander = proxyRacer("stander", 0, 3, 0)
				local model, ctx = startMap(h, "giant-jenga", { stander }, seededRng(seed))
				local columns = {}
				for _, d in model:GetDescendants() do
					if d:HasTag("GiantJengaColumn") then
						table.insert(columns, d)
					end
				end
				t.eq(#columns, 25, "25 columns")
				local startY: { [any]: number } = {}
				for _, c in columns do
					startY[c] = local3(c.CFrame).Y
				end
				local lastVanish = -1
				local vanished: { [any]: boolean } = {}
				table.insert(h.onTick, function(now: number)
					for _, c in columns do
						if not vanished[c] and c.CanCollide == false then
							vanished[c] = true
							lastVanish = now
						end
					end
				end)
				h.advance(75.5)
				local border, gone = 0, 0
				for _, c in columns do
					local i, j = c:GetAttribute("ColumnI"), c:GetAttribute("ColumnJ")
					if JengaLayout.isProtected(i, j) then
						t.eq(c.CanCollide, true, `seed {seed}: protected {i},{j} collides`)
						t.ok(c.Transparency < 1, `seed {seed}: protected {i},{j} visible`)
						local up = c.CFrame.UpVector
						t.ok(up.Y > 0.9999, `seed {seed}: protected {i},{j} flat ({up})`)
						t.ok(
							math.abs(local3(c.CFrame).Y - startY[c]) < 1e-4,
							`seed {seed}: protected {i},{j} did not sink`
						)
						local blocks = c:FindFirstChild("Blocks")
						if blocks then
							local pedestal = blocks:FindFirstChild("Pedestal")
							t.ok(
								pedestal ~= nil and pedestal.Transparency < 1,
								`seed {seed}: protected pedestal visible`
							)
						end
					else
						border += 1
						if c.CanCollide == false then
							gone += 1
						end
					end
				end
				t.eq(border, 16, "border columns")
				-- 테두리 16칸 × 3단 = 48블록. 실제 start는 흔들리는 중(busy)인 칸을 다시 고르면 그 뽑기를 버려서
				-- 순수 일정(약 69초)보다 늦을 수 있어요 — 75초 안에 다 사라지는지와 마지막 시각을 기록해요.
				t.eq(gone, 16, `seed {seed}: all border columns gone by 75 ({gone}, last at {lastVanish})`)
				t.ok(lastVanish < 75, `seed {seed}: last border vanish {lastVanish}`)
				t.eq(ctx.eliminated, {}, `seed {seed}: centre racer safe`)
			end
		end
	)

	---------------------------------------------------------------- 고양이 카페 캣타워
	t.test(
		"QA cat-cafe-shelves: 공이 60초 경계에서 한 프레임에 튀지 않고, 60초 뒤 고양이 발 경고가 1.6초 간격",
		function()
			local h = newHarness("CatCafeShelves")
			-- 꼭대기가 아닌 선반 둘에 한 명씩 (공에 맞지 않게 공 경로 밖 — 폭 방향 가장자리 근처)
			local picked = {}
			for _, shelf in CatLayout.shelves() do
				if shelf.side ~= "Top" and #picked < 2 then
					table.insert(picked, shelf)
				end
			end
			local players = {}
			for k, shelf in picked do
				local acrossOffset = shelf.width / 2 - 0.2
				local x = if shelf.axis == "X" then shelf.centerX else shelf.centerX + acrossOffset
				local z = if shelf.axis == "X" then shelf.centerZ + acrossOffset else shelf.centerZ
				table.insert(players, racer(`r{k}`, x, shelf.topY + 3, z))
			end
			local model, ctx = startMap(h, "cat-cafe-shelves", players, seededRng(3))
			local toys = model:FindFirstChild("CatToys"):GetChildren()
			t.ok(#toys > 0, "toys")
			local last: { [any]: any } = {}
			local maxJumpBefore, maxJumpAround = 0, 0
			table.insert(h.onTick, function(now: number)
				for _, toy in toys do
					local p = toy.CFrame.Position
					local prev = last[toy]
					if prev then
						local d = (p - prev).Magnitude
						if now > 50 and now < 59 then
							maxJumpBefore = math.max(maxJumpBefore, d)
						elseif now >= 59.5 and now <= 60.5 then
							maxJumpAround = math.max(maxJumpAround, d)
						end
					end
					last[toy] = p
				end
			end)
			h.advance(75)
			-- 서든데스 주기가 4.5 → 3.8이라 최고 속도는 4.5/3.8 ≈ 1.18배까지만 늘어요 — 순간 이동이면 훨씬 커요
			t.ok(maxJumpBefore > 0, "toys move")
			t.ok(
				maxJumpAround <= maxJumpBefore * (CatLogic.BALL_PERIOD / CatLogic.BALL_PERIOD_SUDDEN) + 1e-3,
				`no teleport at 60s ({maxJumpAround} vs {maxJumpBefore})`
			)
			local warns = cueTimes(h, "CatPawWarn", 61)
			t.ok(#warns >= 8, `paw warnings after 61s ({#warns})`)
			for _, gap in gaps(warns) do
				t.ok(math.abs(gap - CatLogic.PAW_INTERVAL_SUDDEN) <= 2 * STEP + 1e-6, `paw gap {gap}`)
			end
			-- 60초 전 마지막 단계는 2초 간격 (그대로)
			local before = {}
			for _, at in cueTimes(h, "CatPawWarn", 46) do
				if at < 59 then
					table.insert(before, at)
				end
			end
			for _, gap in gaps(before) do
				t.ok(math.abs(gap - 2) <= 2 * STEP + 1e-6, `pre-sudden paw gap {gap}`)
			end
			-- 물리가 없어 넉백돼도 제자리라 탈락은 없어요 (판정이 75초까지 깨지지 않는지만 봐요)
			t.eq(ctx.eliminated, {}, "no fall judgement errors")
		end
	)
	---------------------------------------------------------------- L4-D1 판정
	t.test("QA L4-D1: Survival 일정은 맵 timeLimit 75로 끝나요 (Config 60이 아니라)", function()
		for _, id in { "hot-plate", "chef-board", "tempura-pot", "giant-jenga", "cat-cafe-shelves" } do
			local map = Maps.get(id) :: any
			local schedule = RoundLogic.schedule("Survival", Maps.timeLimit(map), Config.Final)
			t.eq(schedule.hardCapAt, 75, id)
			t.eq(schedule.overtimeAt, nil, id)
			t.eq(RoundLogic.clockPhase(schedule, 74.99), "Normal", id)
			t.eq(RoundLogic.clockPhase(schedule, 75), "Expired", id)
		end
	end)

	t.test(
		"QA L4-D1: 철판 바닥 경계 — 4명은 75초에 31칸 남음, 5명은 약 70초에 바닥남(새로 생김), 6명은 60초 시절에도 바닥남",
		function()
			local function exhaustAt(players: number): number?
				for half = 1, 200 do
					if HotLogic.simulateFloor(players, half / 2) <= 0 then
						return half / 2
					end
				end
				return nil
			end
			t.eq(exhaustAt(4), 84) -- 75초 안에는 안 바닥남
			t.eq(exhaustAt(5), 70)
			t.eq(exhaustAt(6), 60)
			-- 60초 시절(1.5초만)에도 6명이면 60초에 남는 칸이 없었어요: 243 − 6 − 6 × 40 = −3
			t.ok(243 - 6 - 6 * 40 < 0, "6 careful players already ran out under the 60s rules")
			t.ok(243 - 5 - 5 * 40 > 0, "5 careful players did not run out under the 60s rules")
		end
	)

	t.test(
		"QA L4-D1: 바닥이 바닥나 차례로 떨어지면 목표 인원에서 끝나고 남은 사람 전원 통과 (5명·목표 3)",
		function()
			local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
			t.eq(Rules.qualifyCount(5, 3, 2), 3) -- 8명 판 2라운드: 5명 중 3명 통과
			RoundLogic.activate(round, 3)
			local function score(_id: number): number
				return 0
			end
			local out1 = RoundLogic.eliminate(round, { { userId = 1, score = -20 } }, score)
			t.eq(#out1, 1)
			t.eq(round.ended, false)
			local out2 = RoundLogic.eliminate(round, { { userId = 2, score = -20 } }, score)
			t.eq(round.ended, true, "ends at target")
			local passed = {}
			for _, o in out2 do
				if o.result == "Passed" then
					table.insert(passed, o.userId)
				end
			end
			table.sort(passed)
			t.eq(passed, { 3, 4, 5 }, "the three still standing pass")
		end
	)

	t.test(
		"QA L4-D1: 마지막 타일이 사라져 남은 5명이 한 묶음에 떨어져도 더 높이 있던 2명이 구제돼 결승에 가요",
		function()
			local round = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(round, 3)
			local out = RoundLogic.eliminate(round, {
				{ userId = 1, score = -30 },
				{ userId = 2, score = -21 },
				{ userId = 3, score = -25 },
				{ userId = 4, score = -22 },
				{ userId = 5, score = -40 },
			}, function()
				return 0
			end)
			t.eq(round.ended, true)
			local passed, eliminated = {}, {}
			for _, o in out do
				table.insert(if o.result == "Passed" then passed else eliminated, o.userId)
			end
			table.sort(passed)
			t.eq(passed, { 2, 4 }, "two highest rescued")
			t.eq(#eliminated, 3)
			-- 리셋은 구제 안 함: 낙하 1명 + 리셋 4명이면 낙하 1명만 구제
			local r2 = RoundLogic.newRound("Survival", { 1, 2, 3, 4, 5 })
			RoundLogic.activate(r2, 3)
			local out2 = RoundLogic.eliminate(r2, {
				{ userId = 1, score = -30, cause = "Reset" },
				{ userId = 2, score = -21 },
				{ userId = 3, score = -25, cause = "Reset" },
				{ userId = 4, score = -22, cause = "Reset" },
				{ userId = 5, score = -40, cause = "Reset" },
			}, function()
				return 0
			end)
			local passed2 = {}
			for _, o in out2 do
				if o.result == "Passed" then
					table.insert(passed2, o.userId)
				end
			end
			t.eq(passed2, { 2 }, "only the falling racer is rescued")
		end
	)
end
