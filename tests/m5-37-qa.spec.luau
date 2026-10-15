--!strict
-- m5-37 QA (수산시장 fish-market): 개발 테스트(map-fish-market.spec)가 덜 보는 곳을 실제 소스로 확인해요.
--   1. Layout.crateAt — 격자 전체를 0.25 간격으로 훑어 "상자 윗면 정사각형 안"과 정확히 같은지 (개발이 고친 칸 계산)
--   2. 물 탈락선 로컬 y −6 (기울인 아레나 origin), 물길 위 공중은 탈락 아님, 끝난 라운드는 판정 없음
--   3. 넉백 수명: LinearVelocity는 0.12초 안에 사라지고, PlatformStand는 "마지막 넉백 + 0.8초"까지만 —
--      얼음·생선 넉백이 겹쳐도 앞 타이머가 뒤 넉백을 풀지 않아요. 탈락 고정(Anchored)은 안 건드리고,
--      라운드가 끝나면(cleanup) 넘어진 사람을 일으켜요. 리스폰·퇴장해도 에러 없이 새 캐릭터를 안 건드려요.
--   4. 여러 방: 같은 맵 두 개를 동시에 돌려도 서로의 상자·얼음·생선을 건드리지 않아요 (ctx.model 하위 태그만)
--   5. 모듈 수준 가변 상태 없음, 런타임에도 Ice 태그 없음, 태그 이름이 다른 맵과 안 겹침
--   6. Survival 시간 종료 75초 → 버틴 사람 전원 Passed
--   7. 소개 카메라(D14): 경유점이 판정 파츠 상자 + 40 안, 경로가 판정 파츠·장식을 뚫지 않음

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MapLightingLogic = RobloxRequire.require(Shared.maps.MapLightingLogic)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Layout = RobloxRequire.require(Shared.maps.FishMarketLayout)
local Logic = RobloxRequire.require(Shared.maps.FishMarketLogic)
local Art = RobloxRequire.require(Shared.maps.FishMarketArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local RCF: any = roblox.CFrame
local RV3: any = roblox.Vector3

local EPS = 1e-6

---------------------------------------------------------------- 시뮬레이터 (여러 방 지원)
type Mark = { character: any, at: number, seconds: number }
type Sim = {
	map: any,
	clock: number,
	heartbeat: { () -> () },
	delays: { { at: number, fn: () -> () } },
	models: { any },
	marks: { Mark },
	current: number, -- 지금 Heartbeat를 도는 방 번호 (start 순서)
	sfx: { { name: string, room: number, own: boolean } }, -- own = 소리 파츠가 그 방(models[room]) 안
}

local function newSim(): Sim
	local sim: Sim =
		{ map = nil, clock = 500, heartbeat = {}, delays = {}, models = {}, marks = {}, current = 0, sfx = {} }
	local fakeRun = {
		Heartbeat = {
			Connect = function(_, fn: () -> ())
				table.insert(sim.heartbeat, fn)
				local connection = {}
				function connection.Disconnect()
					local i = table.find(sim.heartbeat, fn)
					if i then
						table.remove(sim.heartbeat, i)
					end
				end
				return connection
			end,
		},
	}
	-- 진짜 CollectionService처럼 "모든 방"의 태그 파츠를 돌려줘요 (맵이 ctx.model로 걸러야 해요)
	local fakeCollection = {
		GetTagged = function(_, tag: string): { any }
			local list = {}
			for _, model in sim.models do
				for _, d in model:GetDescendants() do
					if d:HasTag(tag) then
						table.insert(list, d)
					end
				end
			end
			return list
		end,
		AddTag = function(_, inst: any, tag: string)
			inst:AddTag(tag)
		end,
	}
	local fakeTask = {
		delay = function(seconds: number, fn: () -> ()): any
			local entry = { at = sim.clock + seconds, fn = fn }
			table.insert(sim.delays, entry)
			return entry
		end,
		spawn = function(fn: any, ...: any): any
			fn(...)
			return {}
		end,
		wait = function(): number
			error("task.wait is not allowed in fish-market start")
		end,
	}
	local fakeMapSfx = {
		play = function(part: any, _cue: string)
			local model = sim.models[sim.current]
			table.insert(sim.sfx, {
				name = part:GetFullName(),
				room = sim.current,
				own = model ~= nil and part:IsDescendantOf(model),
			})
		end,
	}
	local fakeMoveExempt = {
		mark = function(character: any, seconds: number?)
			table.insert(sim.marks, { character = character, at = sim.clock, seconds = seconds or -1 })
		end,
	}
	local fakeMapKit = {
		makeEmitter = function(): any
			return { Enabled = true, Emit = function() end }
		end,
	}
	local env = table.clone(Shims.globals)
	env.game = {
		GetService = function(_, name: string): any
			if name == "RunService" then
				return fakeRun
			elseif name == "CollectionService" then
				return fakeCollection
			end
			error(`unexpected service {name}`)
		end,
	}
	env.task = fakeTask
	env.os = {
		clock = function(): number
			return sim.clock
		end,
	}
	env.script = RShared.maps.FishMarket
	env.require = function(target: any): any
		local name = target.Name
		if name == "MapSfx" then
			return fakeMapSfx
		elseif name == "MoveExempt" then
			return fakeMoveExempt
		elseif name == "MapKit" then
			return fakeMapKit
		end
		return Shims.require(target)
	end
	local source = string.gsub(fs.readFile("src/shared/maps/FishMarket.luau"), "root%.Position", "root.CFrame.Position")
	sim.map = luau.load(source, { debugName = "FishMarket(qa)", environment = env })()
	return sim
end

local function stepSim(sim: Sim, dt: number)
	sim.clock += dt
	local i = 1
	while i <= #sim.delays do
		local entry = sim.delays[i]
		if entry.at <= sim.clock then
			table.remove(sim.delays, i)
			entry.fn()
		else
			i += 1
		end
	end
	for i, fn in table.clone(sim.heartbeat) do
		sim.current = i
		fn()
	end
	sim.current = 0
end

type Room = {
	ctx: any,
	model: any,
	origin: any,
	racers: { any },
	eliminated: { [any]: boolean },
	cleanupItems: { any },
	active: boolean,
}

local function makeRacer(name: string, origin: any, x: number, y: number, z: number): (any, any, any)
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = origin * RCF.new(x, y, z)
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.PlatformStand = false -- lune 인스턴스는 기본값이 없어서 처음 값을 정해 둬요
	humanoid.Parent = character
	local player = { Name = name, Character = character }
	return player, root, humanoid
end

local function newRoom(sim: Sim, origin: any, seed: number): Room
	local model = RMaps.get("fish-market").build(origin)
	table.insert(sim.models, model)
	local room: Room = {
		ctx = nil,
		model = model,
		origin = origin,
		racers = {},
		eliminated = {},
		cleanupItems = {},
		active = true,
	}
	room.ctx = {
		model = model,
		origin = origin,
		rng = Shims.globals.Random.new(seed),
		targetCount = 1,
		cleanup = {
			add = function(_self: any, item: any)
				table.insert(room.cleanupItems, item)
				return item
			end,
		},
		isActive = function()
			return room.active
		end,
		getRacers = function()
			local list = {}
			for _, p in room.racers do
				if not room.eliminated[p] then
					table.insert(list, p)
				end
			end
			return list
		end,
		pass = function() end,
		eliminate = function(p: any)
			room.eliminated[p] = true
		end,
	}
	return room
end

local function runCleanupFunctions(room: Room)
	for _, item in room.cleanupItems do
		if type(item) == "function" then
			item()
		end
	end
end

local function localPos(origin: any, part: any): any
	return origin:PointToObjectSpace(part.CFrame.Position)
end

-- 지금 상자 격자 위를 움직이는(Move) 얼음 블록 Core 하나 (로컬 위치)
local function movingIce(room: Room): any?
	for _, block in room.model:FindFirstChild("IceBlocks"):GetChildren() do
		local p = localPos(room.origin, block:FindFirstChild("Core"))
		if math.abs(p.X) < Layout.SPAN / 2 - 6 and math.abs(p.Y - Logic.ICE_HEIGHT / 2) < 1e-3 then
			return p
		end
	end
	return nil
end

local function lastMark(sim: Sim, character: any): Mark?
	for i = #sim.marks, 1, -1 do
		if sim.marks[i].character == character then
			return sim.marks[i]
		end
	end
	return nil
end

---------------------------------------------------------------- 정적 소스 검사 도우미
local function topLevelLocals(path: string): { string }
	local out = {}
	for line in string.gmatch(fs.readFile(path), "[^\n]+") do
		if string.sub(line, 1, 6) == "local " and not string.find(line, "^local function") then
			table.insert(out, line)
		end
	end
	return out
end

return function(t: Test.Test)
	---------------------------------------------------------------- 1. crateAt
	t.test(
		"QA crateAt: 격자 전체(0.25 간격)에서 '상자 윗면 정사각형 안'과 정확히 같아요",
		function()
			local crates = Layout.crates()
			local mismatches = 0
			local x = -60
			while x <= 60 do
				local z = -112
				while z <= 12 do
					local expectRow, expectCol = nil, nil
					for _, c in crates do
						if
							math.abs(x - c.centerX) <= Layout.CRATE_SIZE / 2
							and math.abs(z - c.centerZ) <= Layout.CRATE_SIZE / 2
						then
							expectRow, expectCol = c.row, c.col
						end
					end
					local row, col = Layout.crateAt(x, z)
					if row ~= expectRow or col ~= expectCol then
						mismatches += 1
						if mismatches <= 5 then
							t.ok(false, `crateAt({x}, {z}) = {row},{col} expected {expectRow},{expectCol}`)
						end
					end
					z += 0.25
				end
				x += 0.25
			end
			t.eq(mismatches, 0)
			-- 경계 정확히: 가장자리 ±5는 상자, 물길 가운데(7.5)는 nil, 마지막 상자 바깥 가장자리 +5 / +5.01
			t.eq({ Layout.crateAt(Layout.colX(0) - 5, Layout.rowZ(0) + 5) }, { 0, 0 })
			t.eq({ Layout.crateAt(Layout.colX(5) + 5, Layout.rowZ(5) - 5) }, { 5, 5 })
			t.eq({ Layout.crateAt(Layout.colX(5) + 5.01, Layout.rowZ(5)) }, {})
			t.eq({ Layout.crateAt(Layout.colX(2) + 7.5, Layout.rowZ(2)) }, {})
			t.eq({ Layout.crateAt(Layout.colX(2), Layout.rowZ(2) - 7.5) }, {})
			-- Row 0은 출발 쪽(+Z), Row 5는 안쪽(−Z) — rowZ와 crateAt이 같은 방향
			t.ok(Layout.rowZ(0) > Layout.rowZ(5), "row 0 is the +Z side")
			for _, c in crates do
				t.eq({ Layout.crateAt(c.centerX, c.centerZ) }, { c.row, c.col }, c.key)
			end
		end
	)

	---------------------------------------------------------------- 2. 물 탈락선
	t.test(
		"QA 물 탈락: 기울인 아레나 origin에서 로컬 y −5.9 무사 / −6.1 탈락, 물길 위 공중 무사, 끝난 라운드 판정 없음",
		function()
			local sim = newSim()
			local origin = RCF.new(4000, 300, -2000) * RCF.Angles(0, math.rad(37), 0)
			local room = newRoom(sim, origin, 3)
			local ok1 = makeRacer("Ok1", origin, Layout.colX(2), -5.9, Layout.rowZ(2))
			local sink = makeRacer("Sink", origin, Layout.colX(3), -6.1, Layout.rowZ(3))
			local air = makeRacer("Air", origin, Layout.colX(2) + 7.5, 4, Layout.rowZ(2)) -- 물길 위를 뛰는 중
			local late = makeRacer("Late", origin, Layout.colX(1), -30, Layout.rowZ(1))
			room.racers = { ok1, sink, air }
			sim.map.start(room.ctx)
			stepSim(sim, 0.1)
			t.ok(room.eliminated[sink], "local y −6.1 eliminated")
			t.ok(not room.eliminated[ok1], "local y −5.9 safe")
			t.ok(not room.eliminated[air], "in the air above a water channel is safe")
			-- 라운드가 끝난 뒤에는 물에 있어도 판정하지 않아요
			room.active = false
			table.insert(room.racers, late)
			stepSim(sim, 0.1)
			t.ok(not room.eliminated[late], "no elimination after the round ended")
		end
	)

	---------------------------------------------------------------- 3. 넉백 수명
	t.test(
		"QA 넉백: LinearVelocity 0.12초 안에 사라짐, PlatformStand = 마지막 넉백 + 0.8초 (겹친 넉백에도 안 꼬임)",
		function()
			local sim = newSim()
			local origin = RCF.new(2000, 300, 0)
			local room = newRoom(sim, origin, 11)
			-- 자석: 경고 중인 생선 과녁 위, 없으면 움직이는 얼음 블록 위에 매 틱 서 있어요 → 얼음·생선 넉백이 계속 겹쳐요
			local magnet, magnetRoot, magnetHumanoid = makeRacer("Magnet", origin, Layout.colX(2), 3, Layout.rowZ(2))
			-- 구경꾼들: 생선이 사람이 많은 곳을 노리게 + 그대로 둠
			local others = {}
			for i, cell in { { 2, 2 }, { 2, 3 }, { 3, 2 }, { 3, 3 } } do
				local p, root, humanoid = makeRacer(`P{i}`, origin, Layout.colX(cell[2]), 3, Layout.rowZ(cell[1]))
				table.insert(others, { player = p, root = root, humanoid = humanoid })
			end
			room.racers = { magnet }
			for _, o in others do
				table.insert(room.racers, o.player)
			end
			sim.map.start(room.ctx)

			local DT = 0.02
			local firstSeen: { [any]: number } = {}
			local overlaps = 0
			local knocks = 0
			local prevMarkCount = 0
			local all = { { player = magnet, root = magnetRoot, humanoid = magnetHumanoid } }
			for _, o in others do
				table.insert(all, o)
			end
			local steps = math.floor(70 / DT)
			for _ = 1, steps do
				-- 자석 위치 잡기 (넉백으로 날아가도 다시 데려와요 — 탈락하지 않게 상자 높이로)
				local target: any = nil
				for _, d in room.model:FindFirstChild("Hazards"):GetChildren() do
					if d.Name == "FishWarn" then
						local any = d:FindFirstChildWhichIsA("BasePart")
						if any then
							target = localPos(origin, any)
						end
					end
				end
				if target == nil then
					target = movingIce(room)
				end
				if target then
					magnetRoot.CFrame = origin * RCF.new(target.X, 3, target.Z)
				else
					magnetRoot.CFrame = origin * RCF.new(Layout.colX(2), 3, Layout.rowZ(2))
				end
				for _, o in others do
					o.root.CFrame = origin * RCF.new(localPos(origin, o.root).X, 3, localPos(origin, o.root).Z)
					local lp = localPos(origin, o.root)
					if Layout.crateAt(lp.X, lp.Z) == nil then
						o.root.CFrame = origin * RCF.new(Layout.colX(2), 3, Layout.rowZ(2))
					end
				end

				stepSim(sim, DT)

				-- 새 넉백: 같은 캐릭터가 아직 넘어져 있는 동안 또 맞으면 "겹침"
				for m = prevMarkCount + 1, #sim.marks do
					knocks += 1
					local mark = sim.marks[m]
					for k = m - 1, 1, -1 do
						local prev = sim.marks[k]
						if prev.character == mark.character then
							if mark.at < prev.at + Logic.PLATFORM_STAND - EPS then
								overlaps += 1
							end
							break
						end
					end
				end
				prevMarkCount = #sim.marks

				for _, r in all do
					t.ok(not room.eliminated[r.player], `{r.player.Name} should not be eliminated in this test`)
					-- LinearVelocity 수명
					for _, child in r.root:GetChildren() do
						if child.Name == "FishMarketLaunch" then
							firstSeen[child] = firstSeen[child] or sim.clock
							t.ok(
								sim.clock - firstSeen[child] < Logic.KNOCK_HOLD + DT + EPS,
								`LinearVelocity lived {sim.clock - firstSeen[child]}s`
							)
						end
					end
					-- PlatformStand = 마지막 넉백 + 0.8초 안
					local mark = lastMark(sim, r.player.Character)
					local deadline = if mark then mark.at + Logic.PLATFORM_STAND else -math.huge
					if math.abs(sim.clock - deadline) > 1e-4 then
						local expected = sim.clock < deadline
						t.eq(
							r.humanoid.PlatformStand,
							expected,
							`{r.player.Name} PlatformStand at {sim.clock - 500} (last knock {if mark
								then mark.at - 500
								else -1})`
						)
					end
				end
			end
			t.ok(knocks >= 10, `knocks happened ({knocks})`)
			t.ok(overlaps >= 1, `overlapping knocks exercised ({overlaps})`)
			-- 남은 LinearVelocity 없음 (라운드를 멈추고 마지막 넉백 뒤 0.2초)
			room.active = false
			stepSim(sim, 0.2)
			for _, r in all do
				t.eq(r.root:FindFirstChild("FishMarketLaunch"), nil, `{r.player.Name} launch removed`)
			end
		end
	)

	t.test(
		"QA 넉백: 탈락 고정(Anchored)은 안 풀고, 라운드 종료 cleanup은 넘어진 사람을 일으켜요, 리스폰·퇴장 안전",
		function()
			local sim = newSim()
			local origin = RCF.new(2000, 300, 0)
			local room = newRoom(sim, origin, 5)
			local victim, victimRoot, victimHumanoid = makeRacer("Victim", origin, Layout.colX(2), 3, Layout.rowZ(2))
			local stander, standerRoot, standerHumanoid =
				makeRacer("Stander", origin, Layout.colX(3), 3, Layout.rowZ(3))
			local leaver, leaverRoot, leaverHumanoid = makeRacer("Leaver", origin, Layout.colX(1), 3, Layout.rowZ(1))
			local respawner, respawnerRoot, respawnerHumanoid =
				makeRacer("Respawner", origin, Layout.colX(4), 3, Layout.rowZ(4))
			room.racers = { victim, stander, leaver, respawner }
			local racers = {
				{ victim, victimRoot },
				{ stander, standerRoot },
				{ leaver, leaverRoot },
				{ respawner, respawnerRoot },
			}
			sim.map.start(room.ctx)
			-- 모두 얼음에 한 번씩 맞을 때까지 블록 위로 데려가요
			local hit: { [any]: boolean } = {}
			local guard = 0
			while guard < 4000 do
				guard += 1
				local ice = movingIce(room)
				local pending = 0
				for _, pr in racers do
					if not hit[pr[1]] then
						pending += 1
					end
				end
				if pending == 0 then
					break
				end
				for _, pr in racers do
					if not hit[pr[1]] and ice then
						pr[2].CFrame = origin * RCF.new(ice.X, 3, ice.Z)
						break
					end
				end
				stepSim(sim, 0.02)
				for _, pr in racers do
					if not hit[pr[1]] and lastMark(sim, pr[1].Character) then
						hit[pr[1]] = true
						-- 맞은 사람은 안전한 상자 가운데로 옮겨 두고 PlatformStand를 확인해요
						pr[2].CFrame = origin * RCF.new(Layout.colX(0), 3, Layout.rowZ(0))
					end
				end
			end
			-- 네 명 모두 맞힐 시간은 충분 (5초부터 블록이 다님) — 마지막 사람만 확실히 넘어진 상태로 맞춰요
			for _, pr in racers do
				t.ok(hit[pr[1]], `{pr[1].Name} was knocked`)
			end
			-- 다시 한꺼번에 넉백 상태로 만들려고, 네 명을 한 틱 안에 같은 블록 위에 세워요
			local ice = nil
			for _ = 1, 2000 do
				ice = movingIce(room)
				if ice then
					break
				end
				stepSim(sim, 0.02)
			end
			t.ok(ice ~= nil, "a moving ice block")
			stepSim(sim, 1.0) -- 쿨다운(0.8) 지나게
			ice = movingIce(room)
			for _ = 1, 2000 do
				if ice then
					break
				end
				stepSim(sim, 0.02)
				ice = movingIce(room)
			end
			for _, pr in racers do
				pr[2].CFrame = origin * RCF.new(ice.X, 3, ice.Z)
			end
			local before = #sim.marks
			stepSim(sim, 0.02)
			t.ok(#sim.marks - before >= 4, `all four knocked together ({#sim.marks - before})`)
			for _, pr in racers do
				pr[2].CFrame = origin * RCF.new(Layout.colX(0), 3, Layout.rowZ(0))
			end
			t.ok(victimHumanoid.PlatformStand and standerHumanoid.PlatformStand, "knocked down")

			-- Victim: 물에 빠진 것처럼 EliminationService가 고정 (Anchored + PlatformStand)
			room.eliminated[victim] = true
			victimRoot.Anchored = true
			victimHumanoid.PlatformStand = true
			-- Leaver: 퇴장 (RoundService가 Reset 탈락으로 레이서에서 빼고, 캐릭터가 사라져요)
			room.eliminated[leaver] = true
			local leftCharacter = leaver.Character
			leaver.Character = nil
			leftCharacter:Destroy()
			-- Respawner: 리셋으로 새 캐릭터 (새 Humanoid는 PlatformStand false)
			local _, _, freshHumanoid = makeRacer("Respawner2", origin, 0, 50, 0)
			respawner.Character = freshHumanoid.Parent
			-- (가) 라운드가 도는 중에 0.8초 타이머가 불려요: 탈락 고정은 그대로, 넘어진 사람은 일어나요
			local ok, err = pcall(function()
				stepSim(sim, Logic.PLATFORM_STAND + 0.1)
			end)
			t.ok(ok, `timers run safely after leave/respawn: {err}`)
			t.eq(victimHumanoid.PlatformStand, true, "timer keeps the anchored (eliminated) racer down")
			t.eq(standerHumanoid.PlatformStand, false, "timer stands the knocked racer up")
			t.eq(freshHumanoid.PlatformStand, false, "new character untouched")
			t.eq(victimRoot:FindFirstChild("FishMarketLaunch"), nil, "no leftover LinearVelocity")
			t.eq(standerRoot:FindFirstChild("FishMarketLaunch"), nil, "no leftover LinearVelocity")
			-- (나) Stander를 다시 맞히고 0.8초 전에 라운드가 끝나요 (RoundService cleanup — 남은 delay는 취소된 셈)
			stepSim(sim, 1.0)
			local knockedAgain = false
			for _ = 1, 3000 do
				local ice2 = movingIce(room)
				if ice2 then
					standerRoot.CFrame = origin * RCF.new(ice2.X, 3, ice2.Z)
				end
				local marksBefore = #sim.marks
				stepSim(sim, 0.02)
				if #sim.marks > marksBefore and lastMark(sim, stander.Character).at == sim.clock then
					knockedAgain = true
					break
				end
			end
			t.ok(knockedAgain, "stander knocked again")
			standerRoot.CFrame = origin * RCF.new(Layout.colX(0), 3, Layout.rowZ(0))
			t.eq(standerHumanoid.PlatformStand, true, "down again")
			stepSim(sim, 0.1)
			room.active = false
			runCleanupFunctions(room)
			t.eq(standerHumanoid.PlatformStand, false, "round-end cleanup stands the knocked racer up")
			t.eq(victimHumanoid.PlatformStand, true, "cleanup keeps the anchored racer")
			local ok2, err2 = pcall(function()
				stepSim(sim, 1.0)
			end)
			t.ok(ok2, `late delays run safely: {err2}`)
			t.eq(standerHumanoid.PlatformStand, false, "late timer does not knock anyone down again")
			t.eq(victimHumanoid.PlatformStand, true, "late timer keeps the anchored racer")
			t.eq(standerRoot:FindFirstChild("FishMarketLaunch"), nil, "no leftover LinearVelocity")
			local _ = leaverHumanoid
			local _ = respawnerHumanoid
			local _ = leaverRoot
			local _ = respawnerRoot
		end
	)

	---------------------------------------------------------------- 4. 여러 방
	t.test(
		"QA 여러 방: 같은 맵 두 개를 동시에 돌려도 상자·얼음·생선이 자기 방 안에만 있어요",
		function()
			local sim = newSim()
			local originA = RCF.new(2000, 300, 0)
			local originB = RCF.new(4000, 300, 0) * RCF.Angles(0, math.rad(90), 0)
			local roomA = newRoom(sim, originA, 21)
			local roomB = newRoom(sim, originB, 22)
			local pa = makeRacer("A1", originA, Layout.colX(2), 3, Layout.rowZ(2))
			local pb = makeRacer("B1", originB, Layout.colX(3), 3, Layout.rowZ(3))
			roomA.racers = { pa }
			roomB.racers = { pb }
			sim.map.start(roomA.ctx)
			sim.map.start(roomB.ctx)
			t.eq(#sim.heartbeat, 2, "one Heartbeat per room")
			local crateSnapshot: { [any]: any } = {}
			for _, room in { roomA, roomB } do
				for _, d in room.model:GetDescendants() do
					if d:IsA("BasePart") and d:HasTag("MarketCrate") then
						crateSnapshot[d] = d.CFrame
					end
				end
			end
			local sawFishA, sawFishB = false, false
			for _ = 1, 600 do
				stepSim(sim, 0.1)
				for _, room in { roomA, roomB } do
					for _, block in room.model:FindFirstChild("IceBlocks"):GetChildren() do
						local p = localPos(room.origin, block:FindFirstChild("Core"))
						t.ok(
							math.abs(p.X) <= 66
								and p.Z <= Layout.rowZ(0) + 10
								and p.Z >= Layout.rowZ(5) - 10
								and p.Y > -10
								and p.Y < 6,
							`ice {block.Name} stays in its own room ({p.X}, {p.Y}, {p.Z})`
						)
					end
					for _, d in room.model:FindFirstChild("Hazards"):GetDescendants() do
						if d:IsA("BasePart") then
							local p = localPos(room.origin, d)
							t.ok(
								math.abs(p.X) <= 60 and p.Z <= 20 and p.Z >= -120,
								`hazard {d.Name} in its own room ({p.X}, {p.Z})`
							)
							if d.Name == "Hitbox" then
								if room == roomA then
									sawFishA = true
								else
									sawFishB = true
								end
							end
						end
					end
				end
			end
			t.ok(sawFishA and sawFishB, "both rooms drop fish")
			-- 소리(경고 화살표·생선)도 자기 방 상자·생선에서 나요 (상자 표를 ctx.model로 걸러야 해요)
			-- (방 번호 = newRoom·start 순서 = Heartbeat 순서)
			t.ok(#sim.sfx >= 4, "sounds played")
			for _, entry in sim.sfx do
				t.ok(entry.own, `room {entry.room} sound from {entry.name}`)
			end
			for part, cf in crateSnapshot do
				t.ok(part.CFrame == cf and part.CanCollide, "crate untouched")
			end
			-- 한 방이 끝나도 다른 방은 계속 돌아요
			roomA.active = false
			local hazardsB = #roomB.model:FindFirstChild("Hazards"):GetDescendants()
			local changed = false
			for _ = 1, 100 do
				stepSim(sim, 0.1)
				if #roomB.model:FindFirstChild("Hazards"):GetDescendants() ~= hazardsB then
					changed = true
				end
			end
			t.ok(changed, "room B keeps running after room A ended")
		end
	)

	---------------------------------------------------------------- 5. 모듈 상태 · 태그
	t.test(
		"QA 모듈 수준 가변 상태 없음 (FishMarket·Logic·Layout·Art), 상수 표는 런타임에 안 바뀜",
		function()
			for _, path in
				{
					"src/shared/maps/FishMarket.luau",
					"src/shared/maps/FishMarketLogic.luau",
					"src/shared/maps/FishMarketLayout.luau",
					"src/shared/maps/FishMarketArt.luau",
				}
			do
				for _, line in topLevelLocals(path) do
					local isRequire = string.find(line, "= require%(") ~= nil
					local isConst = string.find(line, "^local [%w_]+ = [%-%d%.]+") ~= nil
						or string.find(line, '^local [%w_]+ = "') ~= nil
					local isModuleTable = string.find(line, "^local [%w_]+ = {}$") ~= nil
					local isTyped = string.find(line, "^local [%w_]+: ") ~= nil
					local isMapTable = string.find(line, "^local map: MapTypes.MapModule = {") ~= nil
					local isLimit = string.find(line, "^local MAX_LEGS = ") ~= nil
					t.ok(
						isRequire or isConst or isModuleTable or isMapTable or isLimit or not isTyped,
						`{path}: top-level local looks mutable: {line}`
					)
					-- 모듈 표 `= {}`는 모듈 자신(Logic/Layout/FishMarketArt)뿐
					if isModuleTable then
						t.ok(
							string.find(line, "^local Logic = {}") ~= nil
								or string.find(line, "^local Layout = {}") ~= nil
								or string.find(line, "^local FishMarketArt = {}") ~= nil,
							`{path}: unexpected module-level table {line}`
						)
					end
				end
			end
			-- 상수 표 스냅샷 → 시뮬레이션 75초 → 그대로
			local function snapshot(mod: any): { [string]: any }
				local s = {}
				for k, v in mod do
					if type(v) ~= "function" and type(v) ~= "table" then
						s[k] = v
					end
				end
				return s
			end
			local sim = newSim()
			local logicMod = sim.map -- 맵 표 자체도 확인
			local before = snapshot(logicMod)
			local room = newRoom(sim, RCF.new(2000, 300, 0), 9)
			room.racers = { (makeRacer("S", room.origin, Layout.colX(2), 3, Layout.rowZ(2))) }
			sim.map.start(room.ctx)
			for _ = 1, 750 do
				stepSim(sim, 0.1)
			end
			t.eq(snapshot(logicMod), before, "map table unchanged")
			t.eq(sim.map.timeLimit, 75)
		end
	)

	t.test(
		"QA 태그: 런타임(75초 뒤)에도 Ice 태그 없음, 태그 이름이 다른 맵 소스와 안 겹침",
		function()
			local sim = newSim()
			local room = newRoom(sim, RCF.new(2000, 300, 0), 13)
			room.racers = { (makeRacer("S", room.origin, Layout.colX(2), 3, Layout.rowZ(2))) }
			sim.map.start(room.ctx)
			local maxFishTags = 0
			for _ = 1, 750 do
				stepSim(sim, 0.1)
				local n = 0
				for _, d in room.model:GetDescendants() do
					for _, tag in d:GetTags() do
						t.ok(tag ~= "Ice", `{d:GetFullName()} has the Ice tag at runtime`)
						if tag == "MarketFish" then
							n += 1
						end
					end
				end
				maxFishTags = math.max(maxFishTags, n)
			end
			t.ok(maxFishTags >= 1, "runtime fish carry MarketFish")
			for _, entry in fs.readDir("src/shared/maps") do
				if string.sub(entry, 1, 10) ~= "FishMarket" and string.sub(entry, -5) == ".luau" then
					local source = fs.readFile(`src/shared/maps/{entry}`)
					for _, tag in { '"MarketCrate"', '"MarketIceBlock"', '"MarketFish"' } do
						t.ok(string.find(source, tag, 1, true) == nil, `{entry} also uses {tag}`)
					end
				end
			end
		end
	)

	---------------------------------------------------------------- 6. Survival 시간 종료
	t.test(
		"QA 시간 종료: Survival 75초 일정 → 74.9초 Wait, 75초 Expire → 남은 사람 전원 Passed",
		function()
			local map = Maps.get("fish-market")
			t.eq(Maps.timeLimit(map), 75)
			local mode = RoundLogic.modeFor(map.kind, false)
			t.eq(mode, "Survival")
			local schedule = RoundLogic.schedule(mode, Maps.timeLimit(map), Config.Final, nil, map.overtime ~= nil)
			t.eq(schedule.hardCapAt, 75)
			t.eq(schedule.overtimeAt, nil)
			t.eq(RoundLogic.loopAction(schedule, 74.9, false), "Wait")
			t.eq(RoundLogic.loopAction(schedule, 75, false), "Expire")
			-- 8명 시작, 목표 4명, 2명 탈락 → 75초에 남은 6명 전원 통과
			local ids = { 1, 2, 3, 4, 5, 6, 7, 8 }
			local round = RoundLogic.newRound(mode, ids)
			RoundLogic.activate(round, 4)
			local scoreOf = function(_id: number): number
				return 0
			end
			RoundLogic.eliminate(round, { { userId = 7, score = -10 }, { userId = 8, score = -10 } }, scoreOf)
			t.eq(round.ended, false, "still running with 6 > 4")
			local outcomes = RoundLogic.timeout(round, scoreOf)
			t.eq(#outcomes, 6)
			for _, o in outcomes do
				t.eq(o.result, "Passed", `user {o.userId}`)
			end
			-- 목표 인원만 남으면 그 자리에서 끝 (75초 전)
			local round2 = RoundLogic.newRound(mode, { 1, 2, 3, 4, 5 })
			RoundLogic.activate(round2, 3)
			local out2 = RoundLogic.eliminate(round2, { { userId = 4, score = 0 }, { userId = 5, score = 0 } }, scoreOf)
			t.eq(round2.ended, true)
			local passed = 0
			for _, o in out2 do
				if o.result == "Passed" then
					passed += 1
				end
			end
			t.eq(passed, 3)
			-- 맵에 overtime 훅 없음 (Survival)
			t.eq(map.overtime, nil)
		end
	)

	---------------------------------------------------------------- 7. 소개 카메라 (D14)
	t.test(
		"QA D14: 소개 경유점이 판정 파츠 상자 + 40 안 (IntroCamera 점을 빼고 잼), 경로가 판정 파츠·장식을 뚫지 않음",
		function()
			local origin = RCF.new(2000, 300, 0)
			local model = RMaps.get("fish-market").build(origin)
			-- MapLightingController.measure와 같은 방식, 단 IntroCamera 점은 빼요 (규칙: 판정 상자 + 40)
			local minV, maxV = nil, nil
			local solids = {}
			for _, d in model:GetDescendants() do
				if not d:IsA("BasePart") then
					continue
				end
				local parent = d.Parent
				local skip = false
				while parent and parent ~= model do
					if parent.Name == "Decor" or parent.Name == "IntroCamera" then
						skip = true
						break
					end
					parent = parent.Parent
				end
				if skip then
					continue
				end
				local half = d.Size.Magnitude / 2
				local p = d.CFrame.Position
				local lo = p - RV3.new(half, half, half)
				local hi = p + RV3.new(half, half, half)
				minV = if minV then minV:Min(lo) else lo
				maxV = if maxV then maxV:Max(hi) else hi
				if d.CanCollide or d.Transparency < 0.85 then
					local lp = origin:PointToObjectSpace(p)
					local s = d.Size
					table.insert(solids, {
						name = d:GetFullName(),
						b = {
							min = { x = lp.X - s.X / 2, y = lp.Y - s.Y / 2, z = lp.Z - s.Z / 2 },
							max = { x = lp.X + s.X / 2, y = lp.Y + s.Y / 2, z = lp.Z + s.Z / 2 },
						},
					})
				end
			end
			local center = (minV + maxV) / 2
			local size = maxV - minV
			local arena = {
				key = "fm",
				center = { x = center.X, y = center.Y, z = center.Z },
				size = { x = size.X, y = size.Y, z = size.Z },
			}
			local path = {}
			for i, point in Art.introCamera() do
				local w = origin:PointToWorldSpace(RV3.new(point.pos.x, point.pos.y, point.pos.z))
				local pos = { x = w.X, y = w.Y, z = w.Z }
				t.eq(
					MapLightingLogic.pickArena(pos, { arena }, nil),
					"fm",
					`intro point {i} inside the judgment box + 40`
				)
				table.insert(path, { position = point.pos, lookAt = point.lookAt })
			end
			-- 경로(경유점 사이 직선, 소개 카메라가 실제로 지나는 곳)가 판정 파츠·장식 상자를 지나가지 않아요
			local function inside(p: any, b: any): boolean
				return p.x > b.min.x
					and p.x < b.max.x
					and p.y > b.min.y
					and p.y < b.max.y
					and p.z > b.min.z
					and p.z < b.max.z
			end
			for _, s in Art.decor() do
				if (s.transparency or 0) < 0.85 then
					table.insert(solids, { name = s.name, b = MapKitLogic.bounds({ s }) })
				end
			end
			local hits: { [string]: boolean } = {}
			for step = 0, 2000 do
				local p = IntroCameraLogic.sample(path, step / 2000).position
				for _, entry in solids do
					if inside(p, entry.b) then
						hits[entry.name] = true
					end
				end
			end
			for name in hits do
				t.ok(false, `intro path passes through {name}`)
			end
		end
	)
end
