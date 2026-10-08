--!strict
-- m4-12 QA: 잡기 입력 무작위 시퀀스(서버 빈도 제한 흉내와 맞물림), 바뀐 장식이 판정에 닿지 않음,
-- 서버 종료 대기 상한, 디버그 강제 플랜 Studio 가드, 남은 P3 수정이 판정 모듈을 건드리지 않음.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local GrabInputLogic = RobloxRequire.require(Shared.GrabInputLogic)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local HotPlateArt = RobloxRequire.require(Shared.maps.HotPlateArt)
local HotPlateLogic = RobloxRequire.require(Shared.maps.HotPlateLogic)
local RotatingBeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)
local SoySwampArt = RobloxRequire.require(Shared.maps.SoySwampArt)
local SkewerArt = RobloxRequire.require(Shared.maps.SkewerShowdownArt)

local function read(path: string): string
	return fs.readFile(path)
end

local function has(path: string, text: string): boolean
	return string.find(read(path), text, 1, true) ~= nil
end

local function seededRng(seed: number)
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		number = step,
		int = function(a: number, b: number): number
			return a + math.floor(step() * (b - a + 1))
		end,
	}
end

-- GrabService.onInput의 빈도 제한을 그대로 흉내 내요 (src/server/GrabService.luau onInput).
type Server = { holding: boolean, lastPress: number?, dropped: number }
local function serverInput(server: Server, value: boolean, now: number)
	if value then
		local last = server.lastPress
		if last ~= nil and now - last < Config.Grab.InputMinInterval then
			server.dropped += 1
			return
		end
		server.lastPress = now
		server.holding = true
	else
		server.holding = false
	end
end

return function(t: Test.Test)
	----------------------------------------------------------------------------
	-- 잡기 입력 (G1·G4): 무작위 입력 시퀀스에서 서버가 누름을 버리지 않고, 스팸도 없고, 결국 맞춰져요

	t.test(
		"QA G1/G4: 무작위 입력 200개 시퀀스(총 3000번) — 서버가 버리는 누름 0, 보낸 값은 번갈아, 끝 상태 일치",
		function()
			local sources: { GrabInputLogic.Source } = { "mouse", "gamepad", "touch" }
			local gap = Config.Grab.InputMinInterval + GrabInputLogic.MARGIN
			local totalSends, totalDropped = 0, 0
			for seed = 1, 200 do
				local rng = seededRng(seed)
				local s = GrabInputLogic.new(Config.Grab.InputMinInterval)
				local server: Server = { holding = false, lastPress = nil, dropped = 0 }
				local physical: { [string]: boolean } = {}
				local scheduled: { number } = {}
				local lastValue: boolean? = nil
				local lastTrueAt = -math.huge
				local trues = 0
				local now = 0
				local function deliver(values: { boolean }, at: number)
					for _, v in values do
						t.ok(v ~= lastValue, `seed {seed}: no duplicate send ({v}) at {at}`)
						if v then
							t.ok(at - lastTrueAt >= gap - 1e-9, `seed {seed}: presses spaced {at - lastTrueAt}`)
							lastTrueAt = at
							trues += 1
						end
						lastValue = v
						serverInput(server, v, at)
						totalSends += 1
					end
				end
				local function runScheduled(upTo: number)
					table.sort(scheduled)
					while #scheduled > 0 and scheduled[1] <= upTo do
						local at = table.remove(scheduled, 1) :: number
						deliver(GrabInputLogic.flush(s, at), at)
					end
				end
				for _ = 1, 15 do
					now += 0.005 + rng.number() * (if rng.number() < 0.7 then 0.06 else 0.4)
					runScheduled(now)
					local roll = rng.number()
					if roll < 0.04 then
						deliver(GrabInputLogic.cancel(s), now)
					else
						local source = sources[rng.int(1, 3)]
						local down = not physical[source]
						physical[source] = down
						local values, at = GrabInputLogic.set(s, source, down, now)
						deliver(values, now)
						if at ~= nil then
							t.ok(at > now and at - now <= gap + 1e-9, `seed {seed}: schedule within gap ({at - now})`)
							table.insert(scheduled, at)
						end
					end
					t.eq(server.holding, s.sent, `seed {seed}: server follows client at {now}`)
				end
				runScheduled(math.huge)
				t.eq(s.sent, GrabInputLogic.isHolding(s), `seed {seed}: settled state matches the held buttons`)
				t.eq(server.holding, s.sent, `seed {seed}: server settled`)
				t.eq(server.dropped, 0, `seed {seed}: server dropped no press`)
				t.ok(trues <= math.floor(now / gap) + 1, `seed {seed}: press rate bounded ({trues})`)
				totalDropped += server.dropped
			end
			t.ok(totalSends > 1000, `enough sends exercised ({totalSends})`)
			t.eq(totalDropped, 0)
		end
	)

	t.test(
		"QA G1: 서버 제한 0.1초와 클라이언트 간격(0.1 + 여유)이 같은 설정값을 써요",
		function()
			t.ok(has("src/server/GrabService.luau", "now - last < Config.Grab.InputMinInterval"), "server limit")
			t.ok(
				has("src/client/input/GrabController.luau", "GrabInputLogic.new(Config.Grab.InputMinInterval)"),
				"client gap from the same config"
			)
			t.ok(GrabInputLogic.MARGIN > 0 and GrabInputLogic.MARGIN <= 0.05, "small positive margin")
		end
	)

	----------------------------------------------------------------------------
	-- 남은 P3 장식 수정이 판정·충돌에 닿지 않아요

	t.test(
		"QA P3 장식: 바뀐 노렌·문·종이 등·테두리는 Decor 목록에만 있고 장식 규칙(충돌 없음)으로 만들어져요",
		function()
			local function names(list: { MapKitLogic.DecorSpec }): { [string]: boolean }
				local out: { [string]: boolean } = {}
				for _, spec in list do
					out[spec.name] = true
				end
				return out
			end
			local belt = names(RotatingBeltArt.decor())
			for _, n in { "Noren", "NorenMark", "GateBeam", "GatePost" } do
				t.ok(belt[n], `rotating-belt decor has {n}`)
			end
			t.ok(names(SoySwampArt.decor()).Lantern, "soy-swamp decor has Lantern")
			t.ok(names(HotPlateArt.decor()).Frame, "hot-plate decor has Frame")
			t.ok(names(SkewerArt.sliceDecor(1)).RimLip, "skewer slice decor has RimLip")

			-- 모든 장식은 MapKit.buildDecor → applyDecorRules (Anchored, CanCollide/CanQuery/CanTouch false)
			local kit = read("src/shared/maps/MapKit.luau")
			local rulesAt = string.find(kit, "function MapKit.applyDecorRules", 1, true) :: number
			local rulesBody = string.sub(kit, rulesAt, string.find(kit, "\nend", rulesAt, true) :: number)
			for _, line in { "part.CanCollide = false", "part.CanQuery = false", "part.CanTouch = false" } do
				t.ok(string.find(rulesBody, line, 1, true) ~= nil, `decor rule: {line}`)
			end
			t.ok(has("src/shared/maps/RotatingBelt.luau", "MapKit.buildDecor(Art.decor()"), "belt decor via MapKit")
			t.ok(has("src/shared/maps/SoySwamp.luau", "MapKit.buildDecor(Art.decor()"), "swamp decor via MapKit")
			t.ok(has("src/shared/maps/HotPlate.luau", "MapKit.buildDecor(Art.decor()"), "hot-plate decor via MapKit")
			t.ok(
				has("src/shared/maps/SkewerShowdown.luau", "MapKit.buildDecor(Art.sliceDecor(index)"),
				"rim via MapKit"
			)
		end
	)

	t.test(
		"QA P3 철판: 테두리는 층 윗면과 같고 타일 영역 바깥(판정 탐침이 닿는 타일과 안 겹침)",
		function()
			local half = HotPlateLogic.LAYER_HALF or nil
			for _, spec in HotPlateArt.decor() do
				if spec.name == "Frame" then
					local b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds
					t.ok(b.max.y - b.min.y > 1.3, "frame keeps its 1.4 height")
					if half then
						local outside = b.min.x >= half - 1e-6 or b.max.x <= -half + 1e-6
						local cz = HotPlateLogic.centerZ()
						outside = outside or b.min.z >= cz + half - 1e-6 or b.max.z <= cz - half + 1e-6
						t.ok(outside, "frame outside the tile area")
					end
				end
			end
		end
	)

	----------------------------------------------------------------------------
	-- m4-07 D5: 종료 대기 상한

	t.test(
		"QA D5: BindToClose 대기는 25초 상한 안에서 저장·로드를 함께 기다리고, 로드가 closing이면 잠금을 풀어요",
		function()
			local path = "src/server/DataService.luau"
			local source = read(path)
			local timeout = tonumber(string.match(source, "local CLOSE_TIMEOUT = (%d+)"))
			t.ok(timeout ~= nil and (timeout :: number) <= 25, `CLOSE_TIMEOUT {timeout} <= 25 (Roblox limit 30)`)
			t.ok(has(path, "local deadline = os.clock() + CLOSE_TIMEOUT"), "deadline from CLOSE_TIMEOUT")
			t.ok(has(path, "and os.clock() < deadline do"), "loop bounded by deadline")
			-- 로드가 끝난 뒤 closing이면 저장(잠금 해제)을 시작하는데, loading을 지우는 것과 save 사이에 yield가 없어야
			-- onClose 루프가 그 틈에 빠져나가지 않아요.
			local clearAt = string.find(source, "loading[player] = nil", 1, true) :: number
			local closingAt = string.find(source, "if player.Parent == nil or closing then", clearAt, true) :: number
			local saveAt = string.find(source, "save(session, true)", closingAt, true) :: number
			t.ok(clearAt and closingAt and saveAt, "closing path found")
			local between = string.sub(source, clearAt, saveAt)
			t.ok(string.find(between, "task.wait", 1, true) == nil, "no yield between clearing loading and save")
			t.ok(has(path, "saving[session] = true"), "runSaves marks saving")
			t.ok(has(path, "task.spawn(runSaves, session)"), "runSaves starts synchronously (task.spawn)")
		end
	)

	----------------------------------------------------------------------------
	-- 디버그 가드

	t.test("QA DEBUG: forceMapPlans 회전은 Studio 가드 뒤, forceMapPlan이 우선, 둘 다 기본 nil", function()
		local match = read("src/server/MatchService.luau")
		local fnAt = string.find(match, "local function forcedPlan(", 1, true) :: number
		t.ok(fnAt ~= nil, "forcedPlan exists")
		local body = string.sub(match, fnAt, string.find(match, "\nend", fnAt, true) :: number)
		local guardAt = string.find(body, "if not RunService:IsStudio() then", 1, true)
		local plansAt = string.find(body, "Config.DEBUG.forceMapPlans", 1, true)
		t.ok(guardAt ~= nil and plansAt ~= nil and guardAt < plansAt, "Studio guard first")
		t.eq(Config.DEBUG.forceMapPlans, nil)
		t.eq(Config.DEBUG.forceMapPlan, nil)
		t.eq(Config.DEBUG.logArenaStats, false)
	end)

	t.test(
		"QA 타입 수정: ChefBoard 칼 조준 스레드의 easeIn 인자는 false(이전 nil과 같은 '감속 끝')",
		function()
			local path = "src/shared/maps/ChefBoard.luau"
			t.ok(has(path, "local eased = if easeIn then a * a else 1 - (1 - a) * (1 - a)"), "nil/false same branch")
			t.ok(has(path, "math.min(KNIFE_AIM_TIME, warnTime),\n\t\t\t\tfalse\n"), "aim passes false")
		end
	)
end
