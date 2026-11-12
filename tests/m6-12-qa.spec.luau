--!strict
-- m6-12 QA: DynamiteLogic 경계값(유니크 뽑기·떨어뜨리기·줍기·폭발 대상·자리), 기본값 고정, 서버 연결 정리(라운드 끝·나감).

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local DynamiteLogic = RobloxRequire.require(Shared.DynamiteLogic)
local Config = RobloxRequire.require(Shared.Config)

local cfg = Config.Dynamite

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local function racer(userId: number, x: number, y: number, z: number, extra: { [string]: any }?)
	local r: { [string]: any } =
		{ userId = userId, position = v(x, y, z), grounded = true, holding = false, down = false }
	if extra then
		for k, value in extra do
			r[k] = value
		end
	end
	return r :: any
end

return function(t: Test.Test)
	t.test("QA 기본값: 스펙 표 그대로", function()
		t.eq(cfg.Enabled, true)
		t.eq(cfg.UniqueChance, 0.10)
		t.eq(cfg.FirstDelay, 12)
		t.eq(cfg.Interval, 18)
		t.eq(cfg.MaxPerRoom, 2)
		t.eq(cfg.MinRacers, 2)
		t.eq(cfg.PickupRadius, 4.5)
		t.eq(cfg.Lifetime, 25)
		t.eq(cfg.DropMinDist, 6)
		t.eq(cfg.DropMaxDist, 12)
		t.eq(cfg.Fuse, 10)
		t.eq(cfg.Radius, 12)
		t.eq(cfg.KnockHorizontal, 60)
		t.eq(cfg.KnockUp, 35)
		t.eq(cfg.Stun, 1.5)
		-- 25초 안에 못 주우면 사라지고, 그 사이 다음 아이템(18초)은 상한 안에서만
		t.ok(cfg.Lifetime > cfg.Interval)
	end)

	t.test(
		"QA 유니크 뽑기 경계: roll == UniqueChance는 아님, 결승 Race·Survival·Final은 roll 0이어도 아님",
		function()
			t.ok(DynamiteLogic.rollUnique("Race", false, cfg.UniqueChance - 1e-9, cfg))
			t.ok(not DynamiteLogic.rollUnique("Race", false, cfg.UniqueChance, cfg))
			t.ok(not DynamiteLogic.rollUnique("Race", true, 0, cfg), "final race")
			t.ok(not DynamiteLogic.rollUnique("Survival", false, 0, cfg))
			t.ok(not DynamiteLogic.rollUnique("Final", false, 0, cfg))
			t.ok(not DynamiteLogic.rollUnique("Final", true, 0, cfg))
			-- 고른 roll 1000개 중 약 10% (0.0005 간격)
			local n = 0
			for i = 0, 1999 do
				if DynamiteLogic.rollUnique("Race", false, (i + 0.5) / 2000, cfg) then
					n += 1
				end
			end
			t.eq(n, 200)
		end
	)

	t.test("QA 떨어뜨리기 경계: 최소 인원 딱 2명이면 됨, 상한 하나 아래면 됨", function()
		local room = DynamiteLogic.newRoom(0)
		t.ok(DynamiteLogic.shouldSpawn(room, cfg.FirstDelay, 0, cfg.MinRacers, cfg))
		t.ok(DynamiteLogic.shouldSpawn(room, cfg.FirstDelay, cfg.MaxPerRoom - 1, cfg.MinRacers, cfg))
		t.ok(not DynamiteLogic.shouldSpawn(room, cfg.FirstDelay, cfg.MaxPerRoom, cfg.MinRacers, cfg))
		t.ok(not DynamiteLogic.shouldSpawn(room, cfg.FirstDelay, 0, 1, cfg), "one racer left")
		t.ok(not DynamiteLogic.shouldSpawn(room, cfg.FirstDelay, 0, 0, cfg), "nobody")
	end)

	t.test(
		"QA 자리: 공중·넘어진 사람 근처에는 안 떨어뜨리고, 난수 끝값(1.0)도 범위 안",
		function()
			local list = { racer(1, 0, 5, 0, { grounded = false }), racer(2, 50, 5, 50, { down = true }) }
			t.eq(
				DynamiteLogic.dropSpot(list, function()
					return 0.5
				end, cfg),
				nil
			)
			local only = { racer(3, 10, 5, -20), racer(4, 999, 5, 999, { grounded = false }) }
			for _, value in { 0, 0.25, 0.999999, 1 } do
				local spot = DynamiteLogic.dropSpot(only, function()
					return value
				end, cfg) :: any
				t.ok(spot ~= nil, `spot for {value}`)
				local d = math.sqrt((spot.x - 10) ^ 2 + (spot.z + 20) ^ 2)
				t.ok(d >= cfg.DropMinDist - 1e-9 and d <= cfg.DropMaxDist + 1e-9, `distance {d}`)
				t.eq(spot.y, 5)
			end
		end
	)

	t.test(
		"QA 줍기 경계: 반지름 딱 4.5는 주움, 같은 거리면 userId 작은 사람, 넘어진·들고 있는 사람 제외",
		function()
			local item = { position = v(0, 0, 0) }
			t.eq(DynamiteLogic.pickupBy(item, { racer(7, cfg.PickupRadius, 0, 0) }, cfg), 7)
			t.eq(DynamiteLogic.pickupBy(item, { racer(7, cfg.PickupRadius + 0.001, 0, 0) }, cfg), nil)
			t.eq(DynamiteLogic.pickupBy(item, { racer(9, 2, 0, 0), racer(8, 0, 0, 2) }, cfg), 8)
			t.eq(
				DynamiteLogic.pickupBy(
					item,
					{ racer(1, 0, 0, 0, { down = true }), racer(2, 0, 0, 1, { holding = true }) },
					cfg
				),
				nil
			)
			t.eq(DynamiteLogic.pickupBy(item, {}, cfg), nil)
		end
	)

	t.test(
		"QA 폭발 대상: 들고 있던 사람은 넘어져 있어도·반지름 밖이어도 포함, 레이서가 아니면 빠짐",
		function()
			local center = v(0, 0, 0)
			local list = {
				racer(1, 100, 0, 0, { down = true }), -- 들고 있던 사람: 멀고 넘어짐
				racer(2, cfg.Radius, 0, 0), -- 경계 딱
				racer(3, cfg.Radius + 0.01, 0, 0),
				racer(4, 1, 0, 0, { down = true }),
			}
			t.eq(DynamiteLogic.blastTargets(center, 1, list, cfg), { 1, 2 })
			-- 들고 있던 사람이 레이서 목록에 없으면(통과·부활 대기·나감) 넣지 않아요
			t.eq(DynamiteLogic.blastTargets(center, 99, list, cfg), { 2 })
			t.eq(DynamiteLogic.blastTargets(center, nil, list, cfg), { 2 })
		end
	)

	t.test("QA 넉백·심지: 한가운데는 -Z, 세기 일정, 심지는 0 아래로 안 내려가요", function()
		local k = DynamiteLogic.knockFor(v(0, 0, 0), v(0, 5, 0), cfg)
		t.eq(k.x, 0)
		t.eq(k.z, -cfg.KnockHorizontal)
		t.eq(k.y, cfg.KnockUp)
		local far = DynamiteLogic.knockFor(v(0, 0, 0), v(3, 0, 4), cfg)
		t.ok(math.abs(math.sqrt(far.x * far.x + far.z * far.z) - cfg.KnockHorizontal) < 1e-9)
		t.eq(DynamiteLogic.fuseLeft(100, 100, cfg), cfg.Fuse)
		t.eq(DynamiteLogic.fuseLeft(100, 100 + cfg.Fuse, cfg), 0)
		t.eq(DynamiteLogic.fuseLeft(100, 1e9, cfg), 0)
		t.eq(DynamiteLogic.effectFor(true), "Home")
		t.eq(DynamiteLogic.effectFor(false), "Knock")
	end)

	t.test(
		"QA 서버 정리: 라운드가 닫히면 훅·유니크 규칙을 지우고, 나간 사람 표를 비워요",
		function()
			local round = fs.readFile("src/server/RoundService.luau")
			t.ok(string.find(round, "sendHome[roomId] = nil", 1, true) ~= nil, "sendHome cleared on close")
			t.ok(string.find(round, "modifiers[roomId] = nil", 1, true) ~= nil, "modifier cleared")
			-- 출발점 보내기는 부활이 되는 레이서만 (통과·탈락·부활 대기 중이면 false)
			for _, needle in
				{
					"or respawning[userId]",
					"or not RoundLogic.isRacing(round, userId)",
					"or not RoundLogic.respawns(round, userId, respawnEnabled)",
				}
			do
				t.ok(string.find(round, needle, 1, true) ~= nil, needle)
			end
			local service = fs.readFile("src/server/DynamiteService.luau")
			t.ok(string.find(service, "Players.PlayerRemoving:Connect", 1, true) ~= nil)
			-- 점화는 들고 있는 방에서 아직 달리는 사람만
			t.ok(string.find(service, "RoundService.activeRoomOf(player) ~= roomId", 1, true) ~= nil)
			-- 서버는 DynamiteFx를 듣지 않아요 (서버 → 클라이언트 전용)
			t.eq(string.find(service, "OnServerEvent", 1, true), nil)
			-- 안내는 LocText + kind
			t.ok(string.find(service, 'LocalizeLogic.text("round.dynamite.notice"), "info"', 1, true) ~= nil)
		end
	)

	t.test(
		"P2-1 회귀: 불붙인 사람이 레이서가 아니게 되면 폭탄이 꺼져요 (보이지 않는 폭탄 없음)",
		function()
			local service = fs.readFile("src/server/DynamiteService.luau")
			t.ok(string.find(service, "local body = racers and racers[player]", 1, true) ~= nil)
			t.ok(string.find(service, "if racers == nil or body == nil then", 1, true) ~= nil)
			-- 폭발 중심은 들고 있던 사람의 지금 자리 (마지막 자리 폴백은 레이서일 때만 쓰임)
			t.ok(string.find(service, "explode(player, info, racers)", 1, true) ~= nil)
		end
	)
end
