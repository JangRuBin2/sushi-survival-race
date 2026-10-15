--!strict
-- m5-35 QA (docs/qa/m5-35-map-space-conveyor.md): "우주 회전초밥"(space-conveyor) 회귀 테스트.
--   이동 감시: 레일 앞 25(+다이브)·저중력 점프·운석 넉백이 MovementGuardLogic 상한 안 (D6, 연속 밀기라 MoveExempt 없음)
--   낙하선(D11): 밟을 수 있는 모든 면(발사대·레일·이음매 원판·소행성·들판·착륙장)을 촘촘히 훑어
--     그 z의 낙하선이 면보다 20 이상 아래(오탐 없음), 32 이하 아래(구멍·늦은 판정 없음)
--   D12: D 오르막 이음매 원판 가장자리 턱 높이 ≤ 0.7 (걸어 오르는 높이)
--   여러 방: 다른 방 모델의 레일·화살표·저중력 구역은 건드리지 않음 (정리 때도)
--   라운드가 통과로 끝난 틱에 구역 안에 남은 레이서의 저중력도 정리 때 지워짐
--   소스: MoveExempt.mark는 운석 충돌 한 곳뿐, GetTagged는 ctx.model 거르는 함수 한 곳뿐, 모듈 수준 상태 없음

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MovementGuardLogic = RobloxRequire.require(Shared.MovementGuardLogic)
local Layout = RobloxRequire.require(Shared.maps.SpaceConveyorLayout)
local Logic = RobloxRequire.require(Shared.maps.SpaceConveyorLogic)
local Art = RobloxRequire.require(Shared.maps.SpaceConveyorArt)

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local SOURCE_PATH = "src/shared/maps/SpaceConveyor.luau"

---------------------------------------------------------------- 가짜 환경 (방 두 개)
type Fake = { [string]: any }

local function fakeInstance(className: string, owner: any?): Fake
	local inst: Fake = { ClassName = className, Name = className, destroyed = false, attrs = {}, owner = owner }
	function inst:Destroy()
		self.destroyed = true
		self.Parent = nil
	end
	function inst:IsA(cls: string): boolean
		return self.ClassName == cls
			or (cls == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart"))
	end
	function inst:GetAttribute(name: string): any
		return self.attrs[name]
	end
	function inst:FindFirstChild(name: string): any
		return (self.children or {})[name]
	end
	function inst:FindFirstChildOfClass(cls: string): any
		for _, child in self.children or {} do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end
	return inst
end

local SENTINEL = RV3.new(1, 2, 3)

type Room = { origin: any, model: Fake, rails: { Fake }, arrows: { Fake }, zone: Fake }

local function buildRoom(origin: any, tagged: { [string]: { Fake } }): Room
	local model = fakeInstance("Model")
	model.children = {}
	function model:IsAncestorOf(inst: any): boolean
		return inst.owner == self
	end
	local room: Room = { origin = origin, model = model, rails = {}, arrows = {}, zone = nil :: any }
	for _, rail in Layout.rails() do
		local a = origin:PointToWorldSpace(RV3.new(rail.x0, rail.y0, rail.z0))
		local b = origin:PointToWorldSpace(RV3.new(rail.x1, rail.y1, rail.z1))
		local part = fakeInstance("Part", model)
		part.CFrame = Shims.lookAt((a + b) / 2, b, RV3.new(0, 1, 0))
		part.AssemblyLinearVelocity = SENTINEL
		part.attrs.RailIndex = rail.index
		table.insert(room.rails, part)
		table.insert(tagged.SpaceRail, part)
		for _, side in { -1, 1 } do
			local wedge = fakeInstance("WedgePart", model)
			wedge.CFrame = part.CFrame * RCF.new(side * 2, 1, 0) * RCF.Angles(0, 0, -side * math.pi / 2)
			wedge.attrs.RailIndex = rail.index
			wedge.attrs.ArrowSide = side
			wedge.Color = "untouched"
			table.insert(room.arrows, wedge)
			table.insert(tagged.SpaceRailArrow, wedge)
		end
	end
	local g = Layout.GRAVITY_ZONE
	local zone = fakeInstance("Part", model)
	zone.CFrame = origin * RCF.new((g.minX + g.maxX) / 2, (g.minY + g.maxY) / 2, (g.minZ + g.maxZ) / 2)
	zone.Size = RV3.new(g.maxX - g.minX, g.maxY - g.minY, g.maxZ - g.minZ)
	room.zone = zone
	table.insert(tagged.SpaceGravityZone, zone)
	return room
end

type Harness = {
	now: number,
	fire: () -> (),
	created: { Fake },
	ctx: any,
	racers: { any },
	roomA: Room,
	roomB: Room,
	runCleanup: () -> (),
}

local function harness(): Harness
	local handlers = {}
	local tagged: { [string]: { Fake } } = { SpaceRail = {}, SpaceRailArrow = {}, SpaceGravityZone = {} }
	-- 아레나 슬롯 두 개 (Config.Arena: 높이 300, 2000 간격) — 방 B가 먼저 등록돼 GetTagged 앞쪽에 와요
	local roomB = buildRoom(RCF.new(2000, 300, 0), tagged)
	local roomA = buildRoom(RCF.new(0, 300, 0), tagged)
	local h: Harness = {
		now = 0,
		fire = function()
			for _, fn in handlers do
				fn(1 / 60)
			end
		end,
		created = {},
		ctx = nil,
		racers = {},
		roomA = roomA,
		roomB = roomB,
		runCleanup = function() end,
	}
	local services = {
		RunService = {
			Heartbeat = {
				Connect = function(_self: any, fn: any)
					table.insert(handlers, fn)
					return { Disconnect = function() end }
				end,
			},
		},
		TweenService = {},
		CollectionService = {
			GetTagged = function(_self: any, tag: string)
				return tagged[tag] or {}
			end,
		},
	}
	local modules = {
		Art = Art,
		Layout = Layout,
		Logic = Logic,
		Config = Config,
		MapTypes = MapTypes,
		MoveExempt = { mark = function() end },
		MapSfx = { play = function() end },
		MapKit = {
			makeEmitter = function()
				return fakeInstance("ParticleEmitter")
			end,
		},
	}
	local env = {
		script = {
			Parent = {
				SpaceConveyorArt = "Art",
				SpaceConveyorLayout = "Layout",
				SpaceConveyorLogic = "Logic",
				MapKit = "MapKit",
				MapSfx = "MapSfx",
				MapTypes = "MapTypes",
				Parent = { Config = "Config", MoveExempt = "MoveExempt" },
			},
		},
		require = function(name: any): any
			return modules[name]
		end,
		game = {
			GetService = function(_self: any, name: string)
				return services[name]
			end,
		},
		workspace = { Gravity = 196.2 },
		task = {
			spawn = function(): any
				return { __thread = true }
			end,
			delay = function(): any
				return { __thread = true }
			end,
			wait = function(): number
				return 0
			end,
		},
		os = {
			clock = function(): number
				return h.now
			end,
		},
		Instance = {
			new = function(className: string): any
				local inst = fakeInstance(className)
				table.insert(h.created, inst)
				return inst
			end,
		},
		CFrame = RCF,
		Vector3 = RV3,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		PhysicalProperties = roblox.PhysicalProperties,
		TweenInfo = { new = function() end },
	}
	local map = luau.load(fs.readFile(SOURCE_PATH), { debugName = "SpaceConveyor", environment = env })()

	local ctx: any = {
		model = roomA.model,
		origin = roomA.origin,
		rng = {},
		cleanup = { items = {} },
		active = true,
		passed = {},
		eliminated = {},
	}
	function ctx.cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		return table.clone(h.racers)
	end
	local function drop(player: any)
		local i = table.find(h.racers, player)
		if i then
			table.remove(h.racers, i)
		end
	end
	ctx.pass = function(player: any)
		table.insert(ctx.passed, player.Name)
		drop(player)
	end
	ctx.eliminate = function(player: any)
		table.insert(ctx.eliminated, player.Name)
		drop(player)
	end
	h.ctx = ctx
	h.runCleanup = function()
		for i = #ctx.cleanup.items, 1, -1 do
			local item = ctx.cleanup.items[i]
			if type(item) == "function" then
				item()
			elseif type(item) == "table" and item.Destroy then
				item:Destroy()
			end
		end
	end
	map.start(ctx)
	return h
end

-- origin 로컬 (x, y, z)에 루트가 있는 레이서. world는 그 origin 기준.
local function racer(h: Harness, name: string, origin: any, x: number, y: number, z: number): any
	local root = fakeInstance("Part")
	root.AssemblyMass = 10
	root.children = { RootAttachment = fakeInstance("Attachment") }
	root.Position = origin:PointToWorldSpace(RV3.new(x, y, z))
	local character = fakeInstance("Model")
	character.children = { HumanoidRootPart = root, Humanoid = fakeInstance("Humanoid") }
	local player = { Name = name, Character = character, root = root }
	table.insert(h.racers, player)
	return player
end

local function liveForces(h: Harness): number
	local n = 0
	for _, inst in h.created do
		if inst.ClassName == "VectorForce" and not inst.destroyed then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- 밟을 수 있는 면 표본
-- { x, z, top } 점 목록 (origin 로컬). 레일은 윗면 기울기 그대로, 원판은 HUB_SINK 아래.
local function walkableSamples(): { { x: number, z: number, top: number, what: string } }
	local out = {}
	local function add(x: number, z: number, top: number, what: string)
		table.insert(out, { x = x, z = z, top = top, what = what })
	end
	local STEP = 0.5
	-- 발사대 A, 들판 E, 착륙장 G
	local function slab(id: string, width: number, top: number)
		local s = Layout.section(id)
		local z = s.front
		while z >= s.back do
			local x = -width / 2
			while x <= width / 2 do
				add(x, z, top, id)
				x += 2
			end
			z -= STEP
		end
	end
	slab("A", Layout.START_WIDTH, 0)
	slab("E", Layout.FIELD_WIDTH, Layout.TOP_Y)
	slab("G", Layout.FINISH_WIDTH, Layout.TOP_Y)
	-- 레일
	for _, rail in Layout.rails() do
		local f = Logic.railFrame(rail)
		local along = -f.half
		while along <= f.half do
			for _, lateral in { -f.halfWidth, 0, f.halfWidth } do
				local p = Logic.railPoint(rail, along, lateral)
				add(p.x, p.z, p.y, `rail{rail.index}`)
			end
			along += STEP
		end
	end
	-- 이음매 원판 (가장자리 포함)
	for i, hub in Layout.hubs() do
		for k = 0, 23 do
			local a = k / 24 * 2 * math.pi
			for _, r in { 0, hub.radius / 2, hub.radius } do
				add(hub.x + math.cos(a) * r, hub.z + math.sin(a) * r, hub.y - Layout.HUB_SINK, `hub{i}`)
			end
		end
	end
	-- 소행성
	for _, rock in Layout.ASTEROIDS do
		for k = 0, 23 do
			local a = k / 24 * 2 * math.pi
			for _, r in { 0, rock.radius / 2, rock.radius } do
				add(rock.x + math.cos(a) * r, rock.z + math.sin(a) * r, rock.top, `asteroid{rock.name}`)
			end
		end
	end
	return out
end

return function(t: Test.Test)
	---------------------------------------------------------------- 이동 감시 (D6)
	t.test(
		"QA D6: 레일 앞 25·다이브·저중력 점프가 이동 감시 상한 안 (면제 없이 ok)",
		function()
			local cfg = Config.MovementGuard
			local walk = Config.Character.WalkSpeed
			-- 레일 위 가장 빠른 수평 속도: 걷기 + 앞으로 실어 줌, 다이브 + 실어 줌
			t.ok(walk + Logic.PUSH_FORWARD <= cfg.MaxHorizontalSpeed, "walk + push")
			t.ok(Config.Dive.ForwardSpeed + Logic.PUSH_FORWARD <= cfg.MaxHorizontalSpeed, "dive + push")
			t.ok(
				Config.Dive.ForwardSpeed + walk + Logic.PUSH_FORWARD <= cfg.MaxHorizontalSpeed,
				"dive + walk + push (generous)"
			)
			-- 샘플 간격(0.2초)으로 5초 동안 앞 25(혹은 다이브 49)로 움직여도 "ok"만
			for _, speed in { walk + Logic.PUSH_FORWARD, Config.Dive.ForwardSpeed + Logic.PUSH_FORWARD } do
				local prev = { x = 0, y = 0, z = 0, t = 0 }
				for i = 1, 25 do
					local cur = { x = 0, y = 0, z = -speed * cfg.SampleInterval * i, t = cfg.SampleInterval * i }
					local verdict = MovementGuardLogic.check(prev, cur, nil, cfg)
					t.eq(verdict, "ok", `speed {speed} sample {i}`)
					prev = MovementGuardLogic.advance(prev, cur, verdict)
				end
			end
			-- 저중력 점프: 처음 위로 속도는 점프력 그대로 (50) — 0.2초에 10 오름 < 140 × 0.2 + 6
			local rise = Config.Character.JumpPower * cfg.SampleInterval
			t.ok(rise <= cfg.MaxRiseSpeed * cfg.SampleInterval + cfg.Slack, "low-gravity jump rise")
			-- 저중력 다이브: 체공이 길어도 수평 속도는 다이브 40 그대로
			t.ok(Config.Dive.ForwardSpeed <= cfg.MaxHorizontalSpeed, "low-gravity dive")
		end
	)

	t.test(
		"QA: 운석 넉백(수평 30 + 위 20)은 면제 상한 안, 레일 실어 줌과 합쳐도 면제 없는 상한 안",
		function()
			local cfg = Config.MovementGuard
			local push = Logic.knockback(1, 0, 0, 0)
			local horizontal = math.sqrt(push.x * push.x + push.z * push.z)
			t.ok(math.abs(horizontal - 30) < 1e-6 and push.y == 20, "knockback constants")
			t.ok(horizontal + Logic.PUSH_FORWARD <= MovementGuardLogic.ExemptMaxHorizontalSpeed, "exempt horizontal")
			t.ok(push.y <= MovementGuardLogic.ExemptMaxRiseSpeed, "exempt rise")
			-- 면제(1.5초)가 끝난 뒤에도 남은 속도가 상한을 넘지 않아요
			t.ok(horizontal + Logic.PUSH_FORWARD <= cfg.MaxHorizontalSpeed, "after exempt horizontal")
			t.ok(push.y <= cfg.MaxRiseSpeed, "after exempt rise")
			t.ok(Logic.EXEMPT_TIME >= Logic.KNOCKDOWN_TIME, "exempt covers the knockdown")
		end
	)

	---------------------------------------------------------------- 낙하선 (D11)
	t.test(
		"QA D11: 밟을 수 있는 모든 면에서 낙하선이 면보다 20~32 아래 (구멍·오탐 없음)",
		function()
			local worstLow, worstHigh = math.huge, -math.huge
			local lowWhat, highWhat = "", ""
			for _, s in walkableSamples() do
				local depth = s.top - Logic.fallLineAt(s.z)
				if depth < worstLow then
					worstLow, lowWhat = depth, `{s.what} z {s.z}`
				end
				if depth > worstHigh then
					worstHigh, highWhat = depth, `{s.what} z {s.z}`
				end
			end
			t.ok(worstLow >= 20, `shallowest {worstLow} at {lowWhat}`)
			t.ok(worstHigh <= 32, `deepest {worstHigh} at {highWhat}`)
		end
	)

	t.test(
		"QA D11: 낙하선은 z를 따라 끊기는 곳이 구간 경계(B/C·C/D, 2 이하)뿐이고 코스 밖도 정의돼요",
		function()
			local z = 20
			local prev = Logic.fallLineAt(z)
			while z > -490 do
				z -= 0.05
				local cur = Logic.fallLineAt(z)
				local jump = math.abs(cur - prev)
				if jump > 0.05 then
					t.ok(jump <= 2 + 1e-9, `jump {jump} at z {z}`)
				end
				t.ok(cur == cur and cur > -math.huge and cur < math.huge, `finite at {z}`)
				prev = cur
			end
			t.eq(Logic.fallLineAt(50), -25) -- 출발 뒤쪽 (A)
			t.eq(Logic.fallLineAt(-600), Layout.TOP_Y - 25) -- 결승 너머 (G)
		end
	)

	---------------------------------------------------------------- D12 턱
	t.test(
		"QA D12: D 오르막 이음매 원판 가장자리 턱 ≤ 0.7 (걸어 오르는 높이), B는 0.05",
		function()
			-- 드러난 턱만 재요:
			--   레일이 원판 아래로 들어가면(오르막에서 들어오는 레일) 원판 가장자리가 레일 위로 턱 — 가운데 줄에서 가장 높아요
			--   레일이 원판 위로 나오면(나가는 레일) 원판 위에 드러난 건 레일 옆 모서리 — 모서리가 원판 가장자리를 지나는 자리가 가장 높아요
			local maxLip = 0
			for _, rail in Layout.rails() do
				if rail.hubStart then
					local f = Logic.railFrame(rail)
					for _, hub in Layout.hubs() do
						local atStart = math.abs(hub.x - rail.x0) < 1e-6 and math.abs(hub.z - rail.z0) < 1e-6
						local atEnd = math.abs(hub.x - rail.x1) < 1e-6 and math.abs(hub.z - rail.z1) < 1e-6
						if atStart or atEnd then
							local discTop = hub.y - Layout.HUB_SINK
							local function topAtRim(lateral: number): number
								local reach = math.sqrt(math.max(hub.radius ^ 2 - lateral ^ 2, 0))
								local along = if atEnd then f.half - reach else -f.half + reach
								return Logic.railTopAt(rail, along)
							end
							local centre = topAtRim(0)
							local lip
							if centre < discTop then
								lip = discTop - centre -- 원판 가장자리가 레일 위로
							else
								lip = math.max(topAtRim(f.halfWidth) - discTop, 0) -- 레일 옆 모서리가 원판 위로
							end
							maxLip = math.max(maxLip, lip)
							if rail.group == "B" then
								t.ok(lip <= Layout.HUB_SINK + 1e-6, `B rail {rail.index} lip {lip}`)
							end
						end
					end
				end
			end
			t.ok(maxLip <= 0.7, `max lip {maxLip}`)
			t.ok(maxLip >= 0.5, `lip expected around 0.66 (D12), got {maxLip}`)
		end
	)

	---------------------------------------------------------------- 여러 방 (D6)
	t.test(
		"QA D6: 다른 방 모델의 레일 속도·화살표는 건드리지 않고, 정리도 이 방 레일만 0으로",
		function()
			local h = harness()
			h.now = 0.5
			h.fire()
			for i, part in h.roomA.rails do
				local rail = Layout.rails()[i]
				local _, push = Logic.railPhase(0.5, rail.offset)
				t.ok((part.AssemblyLinearVelocity - part.CFrame.LookVector * push).Magnitude < 1e-4, `A rail {i}`)
			end
			for i, part in h.roomB.rails do
				t.eq(part.AssemblyLinearVelocity, SENTINEL, `B rail {i} untouched`)
			end
			for _, wedge in h.roomB.arrows do
				t.eq(wedge.Color, "untouched")
			end
			h.now = 3.1
			h.fire()
			for _, wedge in h.roomB.arrows do
				t.eq(wedge.Color, "untouched")
			end
			h.ctx.active = false
			h.runCleanup()
			for i, part in h.roomA.rails do
				t.eq(part.AssemblyLinearVelocity, RV3.zero, `A rail {i} stopped`)
			end
			for i, part in h.roomB.rails do
				t.eq(part.AssemblyLinearVelocity, SENTINEL, `B rail {i} still untouched`)
			end
		end
	)

	t.test(
		"QA D6: 이 방 레이서가 다른 방의 저중력 구역 좌표에 있어도 저중력을 받지 않아요",
		function()
			local h = harness()
			h.now = 1
			-- 방 B 구역 한가운데(월드) = 방 A origin 기준으로는 x +2000 (방 A 구역 밖)
			local p = racer(h, "Stray", h.roomB.origin, 0, 3, -130)
			local local_ = h.roomA.origin:PointToObjectSpace(p.root.Position)
			t.ok(local_.X > 1000, "far from room A")
			h.fire()
			t.eq(liveForces(h), 0)
			-- 방 A 구역 안이면 받아요 (대조)
			racer(h, "Home", h.roomA.origin, 0, 3, -130)
			h.fire()
			t.eq(liveForces(h), 1)
		end
	)

	---------------------------------------------------------------- 저중력 정리
	t.test(
		"QA: 통과로 라운드가 끝난 틱에 구역 안에 남은 레이서의 저중력은 정리에서 지워져요",
		function()
			local h = harness()
			h.now = 1
			local inZone = racer(h, "Zone", h.roomA.origin, 0, 3, -130)
			h.fire()
			t.eq(liveForces(h), 1)
			-- 결승선에 먼저 들어온 사람이 목표 인원을 채워 라운드가 끝나요
			local winner = racer(h, "Winner", h.roomA.origin, 0, 13, -463)
			table.remove(h.racers, table.find(h.racers, winner) :: number)
			table.insert(h.racers, 1, winner)
			local pass = h.ctx.pass
			h.ctx.pass = function(player: any)
				pass(player)
				h.ctx.active = false
			end
			h.fire()
			t.eq(h.ctx.passed, { "Winner" })
			-- 끝난 뒤 Heartbeat는 아무것도 안 해요 (힘은 정리 전까지 남음)
			h.fire()
			t.eq(liveForces(h), 1)
			h.runCleanup()
			t.eq(liveForces(h), 0)
			local _ = inZone
		end
	)

	t.test(
		"QA: 라운드 정리 뒤 Heartbeat가 한 번 더 와도 저중력을 다시 붙이지 않아요",
		function()
			local h = harness()
			h.now = 1
			racer(h, "Zone", h.roomA.origin, 0, 3, -130)
			h.fire()
			h.ctx.active = false
			h.runCleanup()
			h.fire()
			t.eq(liveForces(h), 0)
		end
	)

	---------------------------------------------------------------- 소스 규칙
	t.test(
		"QA: MoveExempt는 운석 충돌 한 곳(넉백 직전)뿐, GetTagged는 ctx.model 거르는 함수 한 곳뿐",
		function()
			local source = fs.readFile(SOURCE_PATH)
			local marks = 0
			for _ in string.gmatch(source, "MoveExempt%.mark%(") do
				marks += 1
			end
			t.eq(marks, 1)
			local markAt = string.find(source, "MoveExempt.mark(player.Character, Logic.EXEMPT_TIME)", 1, true)
			local launchAt = string.find(source, "launch(racer.root", 1, true)
			t.ok(markAt ~= nil and launchAt ~= nil and markAt < launchAt, "exempt marked before launch")
			local getTagged = 0
			for _ in string.gmatch(source, ":GetTagged%(") do
				getTagged += 1
			end
			t.eq(getTagged, 1)
			t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil, "filters by ctx.model")
		end
	)

	t.test("QA: 맵 모듈 4개에 모듈 수준 상태(빈 표·카운터)가 없어요", function()
		for _, file in { "SpaceConveyor", "SpaceConveyorLayout", "SpaceConveyorLogic", "SpaceConveyorArt" } do
			local source = fs.readFile(`src/shared/maps/{file}.luau`)
			for line in string.gmatch(source, "[^\n]+") do
				local isTopLocal = string.match(line, "^local ") ~= nil
				if isTopLocal then
					t.ok(
						string.match(line, "=%s*{%s*}%s*$") == nil or string.match(line, "^local %u%w* = {}$") ~= nil,
						`{file}: {line}`
					)
					t.ok(string.match(line, "=%s*0%s*$") == nil, `{file}: counter {line}`)
				end
			end
		end
	end)
end
