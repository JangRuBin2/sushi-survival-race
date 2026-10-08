--!strict
-- m3-07 QA: GrabService 서버 판정을 가짜 game(Players·RunService·RoundService·리모트)으로 불러와 확인해요.
--   인자 검증·빈도 제한, 같은 방 레이서만, 누른 채 연속 잡기 없음, 끝내기 조건, 나간 플레이어 정리,
--   서버가 WalkSpeed·JumpPower를 쓰지 않음. 그리고 GrabLogic 경계값 몇 개.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Attributes = RobloxRequire.require(Shared.Attributes)
local Config = RobloxRequire.require(Shared.Config)
local GrabLogic = RobloxRequire.require(Shared.GrabLogic)

local cfg = Config.Grab

---------------------------------------------------------------------- 가짜 Roblox 값

local Vec = {}
Vec.__index = function(self: any, key: string): any
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	return nil
end
Vec.__sub = function(a: any, b: any): any
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, Vec)
end
local function vec(x: number, y: number, z: number): any
	return setmetatable({ X = x, Y = y, Z = z }, Vec)
end

local function newSignal(): any
	local handlers = {}
	return {
		Connect = function(_self, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function() end,
			}
		end,
		fire = function(...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

type World = {
	service: any,
	now: number,
	players: { any },
	rooms: { [any]: string? }, -- activeRoomOf 결과
	writes: { string }, -- 서버가 Humanoid에 쓴 속성 이름
	input: (player: any, value: any) -> (),
	tick: () -> (),
	advance: (seconds: number) -> (),
	addPlayer: (userId: number, roomId: string?, x: number, z: number, lookZ: number?) -> any,
	remove: (player: any) -> (),
	move: (player: any, x: number, z: number) -> (),
	respawn: (player: any) -> (),
}

local function newWorld(): World
	local world: World = nil :: any
	local heartbeat = newSignal()
	local removing = newSignal()
	local onServerEvent = newSignal()
	local players: { any } = {}
	local rooms: { [any]: string? } = {}
	local writes: { string } = {}

	local function newCharacter(x: number, z: number, lookZ: number): any
		local attributes: { [string]: any } = {}
		local humanoidState = { Health = 100, PlatformStand = false, WalkSpeed = 16, JumpPower = 50 }
		local humanoid = setmetatable({}, {
			__index = humanoidState,
			__newindex = function(_, key: string, value: any)
				table.insert(writes, key)
				humanoidState[key] = value
			end,
		})
		local root = {
			Position = vec(x, 3, z),
			CFrame = { LookVector = vec(0, 0, lookZ) },
			Anchored = false,
			IsA = function(_self, className: string)
				return className == "BasePart"
			end,
		}
		local character = {
			Parent = "Workspace",
			humanoidState = humanoidState,
			root = root,
			attributes = attributes,
			FindFirstChildOfClass = function(_self, className: string)
				return if className == "Humanoid" then humanoid else nil
			end,
			FindFirstChild = function(_self, name: string)
				return if name == "HumanoidRootPart" then root else nil
			end,
			GetAttribute = function(_self, name: string)
				return attributes[name]
			end,
			SetAttribute = function(_self, name: string, value: any)
				attributes[name] = value
			end,
		}
		return character
	end

	local services = {
		Players = {
			PlayerRemoving = removing,
			GetPlayers = function(_self)
				return table.clone(players)
			end,
			GetPlayerByUserId = function(_self, userId: number)
				for _, p in players do
					if p.UserId == userId then
						return p
					end
				end
				return nil
			end,
		},
		ReplicatedStorage = {
			Shared = setmetatable({}, {
				__index = function(_, name: string)
					return { __shared = name }
				end,
			}),
		},
		RunService = { Heartbeat = heartbeat },
	}
	local sharedModules = {
		Attributes = Attributes,
		Config = Config,
		GrabLogic = GrabLogic,
		Remotes = {
			event = function(name: string)
				assert(name == "GrabInput", `unexpected remote {name}`)
				return { OnServerEvent = onServerEvent }
			end,
		},
	}
	local roundService = {
		activeRoomOf = function(player: any): string?
			return rooms[player]
		end,
	}

	local path = "src/server/GrabService.luau"
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			game = {
				GetService = function(_self, name: string)
					return assert((services :: any)[name], `no fake service {name}`)
				end,
			},
			script = { Parent = { RoundService = { __server = "RoundService" } } },
			os = {
				clock = function()
					return world.now
				end,
			},
			require = function(target: any)
				if target.__server == "RoundService" then
					return roundService
				end
				return assert((sharedModules :: any)[target.__shared], `no fake module {target.__shared}`)
			end,
		},
	})
	local service = chunk()
	service.init()
	service.start()

	world = {
		service = service,
		now = 100,
		players = players,
		rooms = rooms,
		writes = writes,
		input = function(player, value)
			onServerEvent.fire(player, value)
		end,
		tick = function()
			heartbeat.fire(0.1)
		end,
		advance = function(seconds: number)
			local steps = math.floor(seconds / 0.1 + 0.5)
			for _ = 1, steps do
				world.now += 0.1
				heartbeat.fire(0.1)
			end
		end,
		addPlayer = function(userId, roomId, x, z, lookZ)
			local player = { UserId = userId, Name = `P{userId}` }
			player.Character = newCharacter(x, z, lookZ or -1)
			table.insert(players, player)
			rooms[player] = roomId
			return player
		end,
		remove = function(player)
			removing.fire(player)
			local index = table.find(players, player)
			if index then
				table.remove(players, index)
			end
			rooms[player] = nil
		end,
		move = function(player, x, z)
			player.Character.root.Position = vec(x, 3, z)
		end,
		respawn = function(player)
			local old = player.Character
			old.Parent = nil
			local root = old.root
			player.Character = newCharacter(root.Position.X, root.Position.Z, root.CFrame.LookVector.Z)
		end,
	}
	return world
end

local function grabbingOf(player: any): any
	return player.Character.attributes[Attributes.GrabbingUserId]
end

local function grabbedByOf(player: any): any
	return player.Character.attributes[Attributes.GrabbedBy]
end

-- A(1)가 원점에서 -Z를 보고, B(2)가 3 studs 앞에 있는 같은 방 세계
local function pair(): (World, any, any)
	local world = newWorld()
	local a = world.addPlayer(1, "room1", 0, 0)
	local b = world.addPlayer(2, "room1", 0, -3)
	return world, a, b
end

return function(t: Test.Test)
	---------------------------------------------------------------- 성립
	t.test("GrabService: 같은 방 앞 3 studs 레이서를 누르면 잡고 두 속성을 달아요", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		t.eq(grabbingOf(a), 2, "A GrabbingUserId")
		t.eq(grabbedByOf(b), 1, "B GrabbedBy")
	end)

	t.test("GrabService: boolean이 아닌 인자는 무시해요", function()
		local world, a, b = pair()
		for _, bad in { 1, "true", { true }, 0 } :: { any } do
			world.input(a, bad)
			world.advance(0.2)
		end
		world.input(a, nil)
		world.advance(0.2)
		t.eq(grabbingOf(a), nil)
		t.eq(grabbedByOf(b), nil)
	end)

	t.test("GrabService: true가 0.1초보다 잦으면 무시하고, false는 항상 처리해요", function()
		local world, a, b = pair()
		world.input(a, true)
		world.input(a, false) -- 같은 순간 놓기는 처리
		world.now += 0.05
		world.input(a, true) -- 0.05초 뒤 누름은 무시
		world.advance(0.3)
		t.eq(grabbingOf(a), nil, "rate-limited press should not grab")
		world.input(a, true) -- 충분히 지난 뒤 누름
		world.advance(0.1)
		t.eq(grabbingOf(a), 2, "later press grabs")
		t.eq(grabbedByOf(b), 1)
		world.input(a, false)
		t.eq(grabbingOf(a), nil, "release ends immediately (no tick needed)")
		t.eq(grabbedByOf(b), nil)
	end)

	t.test("GrabService: 다른 방 레이서는 바로 앞에 있어도 못 잡아요 (AC12)", function()
		local world = newWorld()
		local a = world.addPlayer(1, "room1", 0, 0)
		local c = world.addPlayer(3, "room2", 0, -2)
		world.input(a, true)
		world.advance(0.5)
		t.eq(grabbingOf(a), nil)
		t.eq(grabbedByOf(c), nil)
	end)

	t.test(
		"GrabService: 레이서가 아니면(로비·대기석·소개·탈락) 잡지도, 잡히지도 않아요 (AC11)",
		function()
			local world = newWorld()
			local a = world.addPlayer(1, nil, 0, 0)
			local b = world.addPlayer(2, nil, 0, -3)
			world.input(a, true)
			world.advance(0.5)
			t.eq(grabbingOf(a), nil, "lobby grabber")
			world.rooms[a] = "room1" -- A만 레이서
			world.advance(0.5)
			t.eq(grabbedByOf(b), nil, "non-racer target")
		end
	)

	t.test("GrabService: 누른 채 다가가면 거리 안에 들어오는 순간 잡혀요 (AC9)", function()
		local world = newWorld()
		local a = world.addPlayer(1, "room1", 0, 0)
		local b = world.addPlayer(2, "room1", 0, -8)
		world.input(a, true)
		world.advance(0.5)
		t.eq(grabbingOf(a), nil, "8 studs away")
		world.move(a, 0, -4) -- B까지 4
		world.advance(0.1)
		t.eq(grabbingOf(a), 2, "within range")
		t.eq(grabbedByOf(b), 1)
	end)

	t.test("GrabService: 옆·뒤는 못 잡아요", function()
		local world = newWorld()
		local a = world.addPlayer(1, "room1", 0, 0)
		world.addPlayer(2, "room1", 3, 0) -- 옆
		world.addPlayer(3, "room1", 0, 3) -- 뒤
		world.input(a, true)
		world.advance(0.5)
		t.eq(grabbingOf(a), nil)
	end)

	---------------------------------------------------------------- 끝내기
	t.test(
		"GrabService: 2초가 지나면 저절로 풀리고, 누른 채로는 쿨다운 뒤에도 다시 안 잡아요",
		function()
			local world, a, b = pair()
			world.input(a, true)
			world.advance(0.1)
			t.eq(grabbingOf(a), 2)
			world.advance(1.8)
			t.eq(grabbingOf(a), 2, "still held before 2s")
			world.advance(0.3)
			t.eq(grabbingOf(a), nil, "released after 2s")
			t.eq(grabbedByOf(b), nil)
			world.advance(3)
			t.eq(grabbingOf(a), nil, "no regrab while holding")
			-- 중복 true(이미 누른 상태)는 다시 무장시키지 않아요
			world.input(a, true)
			world.advance(0.2)
			t.eq(grabbingOf(a), nil, "duplicate true does not re-arm")
			-- 뗐다가 다시 누르면 잡아요
			world.input(a, false)
			world.now += 0.2
			world.input(a, true)
			world.advance(0.1)
			t.eq(grabbingOf(a), 2, "re-press grabs")
		end
	)

	t.test("GrabService: 풀린 직후 잡던 사람은 1.5초 쿨다운이에요 (AC8)", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		t.eq(grabbingOf(a), 2)
		world.input(a, false) -- 풀림: A 쿨다운 1.5초, B 면역 1초
		world.now += 0.2
		world.input(a, true)
		world.advance(1.1) -- 풀린 뒤 1.3초
		t.eq(grabbingOf(a), nil, "A still on cooldown")
		world.advance(0.3) -- 풀린 뒤 1.6초
		t.eq(grabbingOf(a), 2, "after cooldown A grabs again")
		t.eq(grabbedByOf(b), 1)
	end)

	t.test("GrabService: 풀린 대상은 1초 동안 누구에게도 안 잡혀요 (AC8)", function()
		local world, a, b = pair()
		local c = world.addPlayer(3, "room1", 3, -3)
		c.Character.root.CFrame = { LookVector = vec(-1, 0, 0) } -- C는 -X(B 쪽)를 봐요
		world.input(a, true)
		world.advance(0.1)
		t.eq(grabbedByOf(b), 1)
		world.input(a, false)
		world.move(a, 0, 30) -- A는 C의 후보에서 빠지게 멀리
		world.input(c, true)
		world.advance(0.9)
		t.eq(grabbedByOf(b), nil, "B immune for 1s")
		world.advance(0.2)
		t.eq(grabbedByOf(b), 3, "C grabs B after immunity")
	end)

	t.test(
		"GrabService: 대상이 레이서가 아니게 되면(통과·탈락·라운드 끝) 다음 틱에 풀려요 (AC10)",
		function()
			local world, a, b = pair()
			world.input(a, true)
			world.advance(0.1)
			world.rooms[b] = nil
			world.advance(0.1)
			t.eq(grabbingOf(a), nil)
			t.eq(grabbedByOf(b), nil, "passed target not slowed in lobby")
		end
	)

	t.test("GrabService: 잡는 사람이 다른 방 값으로 바뀌어도 풀려요", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		world.rooms[a] = "room2"
		world.advance(0.1)
		t.eq(grabbingOf(a), nil)
		t.eq(grabbedByOf(b), nil)
	end)

	t.test("GrabService: 넘어짐·젓가락(WalkSpeed 0)·Anchored·사망이면 풀려요", function()
		local cases = {
			function(_a, b)
				b.Character.humanoidState.PlatformStand = true
			end,
			function(a, _b)
				a.Character.humanoidState.PlatformStand = true
			end,
			function(_a, b)
				b.Character.humanoidState.WalkSpeed = 0
			end,
			function(a, _b)
				a.Character.root.Anchored = true
			end,
			function(_a, b)
				b.Character.humanoidState.Health = 0
			end,
		}
		for i, apply in cases do
			local world, a, b = pair()
			world.input(a, true)
			world.advance(0.1)
			t.eq(grabbingOf(a), 2, `case {i} grabbed`)
			apply(a, b)
			world.advance(0.1)
			t.eq(grabbingOf(a), nil, `case {i} grabber attr`)
			t.eq(grabbedByOf(b), nil, `case {i} target attr`)
		end
	end)

	t.test("GrabService: 거리 9 초과(다이브로 빠져나감)면 풀리고, 9 이하는 유지돼요", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		world.move(b, 0, -9)
		world.advance(0.1)
		t.eq(grabbingOf(a), 2, "9 keeps")
		world.move(b, 0, -9.2)
		world.advance(0.1)
		t.eq(grabbingOf(a), nil, "9.2 breaks")
		t.eq(grabbedByOf(b), nil)
	end)

	t.test("GrabService: 캐릭터가 바뀌면 풀리고 새 캐릭터에 속성이 남지 않아요", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		local oldB = b.Character
		world.respawn(b)
		world.advance(0.1)
		t.eq(grabbingOf(a), nil)
		t.eq(oldB.attributes[Attributes.GrabbedBy], nil, "old character cleared")
		t.eq(grabbedByOf(b), nil, "new character clean")
	end)

	---------------------------------------------------------------- 동시성
	t.test("GrabService: 서로 보고 같은 틱에 누르면 한 잡기만 성립해요 (AC5)", function()
		local world = newWorld()
		local a = world.addPlayer(1, "room1", 0, 0, -1)
		local b = world.addPlayer(2, "room1", 0, -3, 1)
		world.input(a, true)
		world.input(b, true)
		world.advance(0.1)
		local aGrabs = grabbingOf(a) ~= nil
		local bGrabs = grabbingOf(b) ~= nil
		t.ok(aGrabs ~= bGrabs, "exactly one grab")
		if aGrabs then
			t.eq(grabbedByOf(b), 1)
			t.eq(grabbedByOf(a), nil)
		else
			t.eq(grabbedByOf(a), 2)
			t.eq(grabbedByOf(b), nil)
		end
	end)

	t.test("GrabService: 두 사람이 같은 대상을 노리면 먼저 성립한 잡기만 남아요", function()
		local world = newWorld()
		local a = world.addPlayer(1, "room1", 0, 0)
		local c = world.addPlayer(3, "room1", 1, 0)
		local b = world.addPlayer(2, "room1", 0, -3)
		world.input(a, true)
		world.input(c, true)
		world.advance(0.1)
		local holder = grabbedByOf(b)
		t.ok(holder == 1 or holder == 3, "someone holds B")
		local grabbers = 0
		for _, p in { a, c } do
			if grabbingOf(p) ~= nil then
				grabbers += 1
			end
		end
		t.eq(grabbers, 1, "only one grabber")
	end)

	---------------------------------------------------------------- 나간 플레이어
	t.test("GrabService: 잡힌 사람이 나가면 잡던 사람 속성이 바로 지워져요 (AC15)", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		world.remove(b)
		t.eq(grabbingOf(a), nil)
		world.advance(0.3) -- 에러 없이 틱이 돌아요
	end)

	t.test("GrabService: 잡던 사람이 나가면 잡힌 사람 속성이 바로 지워져요 (AC15)", function()
		local world, a, b = pair()
		world.input(a, true)
		world.advance(0.1)
		world.remove(a)
		t.eq(grabbedByOf(b), nil)
		world.advance(0.3)
	end)

	t.test(
		"GrabService: 나간 사람의 면역·누름 기록이 남지 않아요 (같은 userId로 다시 들어와도 바로 잡힘)",
		function()
			local world, a, b = pair()
			world.input(a, true)
			world.advance(0.1)
			world.input(a, false) -- B 면역 1초
			world.remove(b)
			local b2 = world.addPlayer(2, "room1", 0, -3)
			local c = world.addPlayer(3, "room1", 1, 0)
			world.input(c, true)
			world.advance(0.1)
			t.eq(grabbedByOf(b2), 3, "no stale immunity for rejoined userId")
			-- 나간 A의 누름 상태가 남아 있지 않아요
			world.remove(a)
			local a2 = world.addPlayer(1, "room1", -1, 0)
			world.advance(0.5)
			t.eq(grabbingOf(a2), nil, "no stale holding for rejoined userId")
		end
	)

	---------------------------------------------------------------- WalkSpeed
	t.test(
		"GrabService: 서버는 Humanoid 값(WalkSpeed·JumpPower 등)을 하나도 쓰지 않아요 (AC13)",
		function()
			local world, a, b = pair()
			world.input(a, true)
			world.advance(0.1)
			world.advance(2.5)
			world.input(a, false)
			world.input(a, true)
			world.advance(2)
			world.input(a, false)
			world.remove(b)
			t.eq(world.writes, {}, "no humanoid writes")
		end
	)

	t.test("정적: 서버·클라이언트 잡기 코드에 WalkSpeed/JumpPower 대입이 없어요", function()
		for _, path in
			{
				"src/server/GrabService.luau",
				"src/client/input/GrabController.luau",
				"src/client/input/GrabButton.luau",
			}
		do
			local source = fs.readFile(path)
			t.eq(string.find(source, "WalkSpeed%s*=[^=]"), nil, `{path} WalkSpeed write`)
			t.eq(string.find(source, "JumpPower%s*=[^=]"), nil, `{path} JumpPower write`)
			t.eq(string.find(source, "PlatformStand%s*=[^=]"), nil, `{path} PlatformStand write`)
		end
	end)

	t.test("정적: 감속은 Input+1 렌더 단계, 다이브 경직(Input+2)보다 먼저예요", function()
		local source = fs.readFile("src/client/input/GrabController.luau")
		t.ok(string.find(source, "Enum.RenderPriority.Input.Value + 1", 1, true), "Input+1")
		t.ok(string.find(source, "MouseButton1", 1, true), "mouse")
		t.ok(string.find(source, "ButtonR2", 1, true), "gamepad R2")
		t.ok(string.find(source, "gameProcessed", 1, true), "gameProcessed check")
		t.ok(string.find(source, "WindowFocusReleased", 1, true), "focus release")
	end)

	---------------------------------------------------------------- GrabLogic 경계
	t.test("GrabLogic: 바라보는 방향이 수직뿐이면 아무도 안 잡아요", function()
		local grabber = { userId = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 1, z = 0 } }
		local cand = { userId = 2, position = { x = 0, y = 0, z = -2 }, alive = true, down = false }
		t.eq(GrabLogic.pickTarget(grabber, { cand }, cfg), nil)
	end)

	t.test("GrabLogic: 내적이 0.5보다 조금 작으면 안 잡혀요", function()
		local grabber = { userId = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 0, z = -1 } }
		-- 각도 61도: cos(61°) ≈ 0.485
		local angle = math.rad(61)
		local cand = {
			userId = 2,
			position = { x = 3 * math.sin(angle), y = 0, z = -3 * math.cos(angle) },
			alive = true,
			down = false,
		}
		t.eq(GrabLogic.pickTarget(grabber, { cand }, cfg), nil)
		angle = math.rad(59)
		cand.position = { x = 3 * math.sin(angle), y = 0, z = -3 * math.cos(angle) }
		t.eq(GrabLogic.pickTarget(grabber, { cand }, cfg), 2)
	end)

	t.test("GrabLogic: 경계 — 2초 정확히 끝, 거리 9 정확히 유지", function()
		local base = {
			holding = true,
			elapsed = 0,
			distance = 0,
			grabberRacing = true,
			targetRacing = true,
			grabberDown = false,
			targetDown = false,
		}
		local s = table.clone(base)
		s.elapsed = cfg.MaxHold
		t.eq(GrabLogic.shouldEnd(s, cfg), true)
		s = table.clone(base)
		s.distance = cfg.BreakRange
		t.eq(GrabLogic.shouldEnd(s, cfg), false)
	end)

	t.test("GrabLogic: 면역 중인 대상은 begin도 거부해요 (pickTarget을 거치지 않아도)", function()
		local book = GrabLogic.newBook()
		GrabLogic.begin(book, 1, 2, 0)
		GrabLogic.finish(book, 1, 0, cfg)
		t.eq(GrabLogic.begin(book, 3, 2, 0.5), false, "immune")
		t.eq(GrabLogic.begin(book, 3, 2, 1), true, "after immunity")
	end)

	t.test("GrabLogic: 잡힌 사람이 나가면 잡던 사람에게 쿨다운이 걸려요", function()
		local book = GrabLogic.newBook()
		GrabLogic.begin(book, 1, 2, 0)
		GrabLogic.removePlayer(book, 2, 5, cfg)
		t.eq(GrabLogic.grabOf(book, 1), nil)
		t.eq(GrabLogic.canStart(book, 1, 6.49), false)
		t.eq(GrabLogic.canStart(book, 1, 6.5), true)
		t.eq(book.immuneUntil[2], nil, "leaver immunity removed")
	end)
end
