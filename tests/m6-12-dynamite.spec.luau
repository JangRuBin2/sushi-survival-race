--!strict
-- m6-12 다이너마이트 맵 아이템: DynamiteLogic(떨어뜨리기·줍기·폭발 대상·효과) + 연결(리모트·속성·서비스·공격 입력·문구·소리)

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

local function racer(userId: number, x: number, z: number, extra: { [string]: any }?)
	local r: { [string]: any } =
		{ userId = userId, position = v(x, 3, z), grounded = true, holding = false, down = false }
	if extra then
		for k, value in extra do
			r[k] = value
		end
	end
	return r :: any
end

return function(t: Test.Test)
	t.test("떨어뜨리기: 첫 지연·간격·방 상한·최소 인원", function()
		local room = DynamiteLogic.newRoom(100)
		t.ok(not DynamiteLogic.shouldSpawn(room, 100 + cfg.FirstDelay - 0.1, 0, 4, cfg), "before first delay")
		t.ok(DynamiteLogic.shouldSpawn(room, 100 + cfg.FirstDelay, 0, 4, cfg), "first")
		room.lastSpawnAt = 100 + cfg.FirstDelay
		t.ok(not DynamiteLogic.shouldSpawn(room, room.lastSpawnAt + cfg.Interval - 0.1, 1, 4, cfg), "interval")
		t.ok(DynamiteLogic.shouldSpawn(room, room.lastSpawnAt + cfg.Interval, 1, 4, cfg), "next")
		t.ok(not DynamiteLogic.shouldSpawn(room, 1e6, cfg.MaxPerRoom, 4, cfg), "room cap")
		t.ok(not DynamiteLogic.shouldSpawn(room, 1e6, 0, cfg.MinRacers - 1, cfg), "too few racers")
	end)

	t.test("떨어뜨릴 자리: 땅에 선 사람 둘레 Min~Max 거리, 같은 높이, 없으면 nil", function()
		local seq = { 0.0, 0.25, 0.5 }
		local i = 0
		local function pick(): number
			i += 1
			return seq[i] or 0.5
		end
		local spot = DynamiteLogic.dropSpot({ racer(1, 0, 0, { grounded = false }), racer(2, 10, 0) }, pick, cfg)
		t.ok(spot ~= nil, "spot")
		local s = spot :: any
		local d = math.sqrt((s.x - 10) ^ 2 + s.z ^ 2)
		t.ok(d >= cfg.DropMinDist - 1e-9 and d <= cfg.DropMaxDist + 1e-9, `distance {d}`)
		t.eq(s.y, 3)
		t.eq(DynamiteLogic.dropSpot({ racer(1, 0, 0, { grounded = false }) }, pick, cfg), nil)
		t.eq(DynamiteLogic.dropSpot({ racer(1, 0, 0, { down = true }) }, pick, cfg), nil)
	end)

	t.test(
		"줍기: 반지름 안 손 빈 사람 중 가장 가까운 사람, 들고 있거나 넘어진 사람은 못 주워요",
		function()
			local item = { position = v(0, 3, 0) }
			t.eq(DynamiteLogic.pickupBy(item, { racer(1, 3, 0), racer(2, 1, 0) }, cfg), 2)
			t.eq(DynamiteLogic.pickupBy(item, { racer(1, 1, 0, { holding = true }), racer(2, 3, 0) }, cfg), 2)
			t.eq(DynamiteLogic.pickupBy(item, { racer(1, 1, 0, { down = true }) }, cfg), nil)
			t.eq(DynamiteLogic.pickupBy(item, { racer(1, cfg.PickupRadius + 0.1, 0) }, cfg), nil)
			t.eq(DynamiteLogic.pickupBy(item, { racer(5, 2, 0), racer(3, -2, 0) }, cfg), 3, "tie → smaller userId")
		end
	)

	t.test("폭발 대상: 들고 있던 사람(맨 앞) + 반지름 안, 넘어진 사람 제외", function()
		local hits = DynamiteLogic.blastTargets(v(0, 3, 0), 1, {
			racer(1, 0, 0, { down = true }), -- 들고 있던 사람은 넘어져 있어도 포함
			racer(2, 8, 0),
			racer(3, 4, 0),
			racer(4, cfg.Radius + 0.5, 0),
			racer(5, 2, 0, { down = true }),
		}, cfg)
		t.eq(hits, { 1, 3, 2 })
		t.eq(DynamiteLogic.blastTargets(v(0, 3, 0), 9, { racer(2, 1, 0) }, cfg), { 2 }, "carrier gone")
	end)

	t.test("효과: Race(부활 라운드)는 출발점, 아니면 튕김. 튕김은 바깥 + 위", function()
		t.eq(DynamiteLogic.effectFor(true), "Home")
		t.eq(DynamiteLogic.effectFor(false), "Knock")
		local k = DynamiteLogic.knockFor(v(0, 0, 0), v(3, 0, 4), cfg)
		t.ok(math.abs(k.x - 0.6 * cfg.KnockHorizontal) < 1e-9 and math.abs(k.z - 0.8 * cfg.KnockHorizontal) < 1e-9)
		t.eq(k.y, cfg.KnockUp)
		local c = DynamiteLogic.knockFor(v(0, 0, 0), v(0, 5, 0), cfg)
		t.eq(c.z, -cfg.KnockHorizontal, "center")
		t.eq(DynamiteLogic.fuseLeft(10, 10 + cfg.Fuse - 3, cfg), 3)
		t.eq(DynamiteLogic.fuseLeft(10, 10 + cfg.Fuse + 1, cfg), 0)
	end)

	t.test("유니크 라운드: 결승 아닌 Race에서만 UniqueChance(10%) 확률", function()
		t.eq(cfg.UniqueChance, 0.10)
		t.ok(DynamiteLogic.rollUnique("Race", false, 0.05, cfg), "lucky race")
		t.ok(not DynamiteLogic.rollUnique("Race", false, 0.5, cfg), "normal race")
		t.ok(not DynamiteLogic.rollUnique("Race", true, 0, cfg), "never in final")
		t.ok(not DynamiteLogic.rollUnique("Survival", false, 0, cfg), "never in survival")
		local round = fs.readFile("src/server/RoundService.luau")
		t.ok(string.find(round, "DynamiteLogic.rollUnique(map.kind, isFinal", 1, true) ~= nil, "rolled per round")
		local service = fs.readFile("src/server/DynamiteService.luau")
		t.ok(
			string.find(service, 'RoundService.modifierOf(roomId) ~= "Dynamite"', 1, true) ~= nil,
			"only in dynamite rounds"
		)
		local csv = fs.readFile("src/shared/Localization/Strings.csv")
		t.ok(string.find(csv, "\nround.dynamite.notice,", 1, true) ~= nil, "notice text")
	end)

	t.test("기본값: 심지 10초(사용자 결정), 반지름·튕김은 공격보다 커요", function()
		t.eq(cfg.Fuse, 10)
		t.ok(cfg.Radius > Config.Attack.Radius and cfg.KnockHorizontal > Config.Attack.KnockHorizontal)
		t.ok(cfg.MaxPerRoom >= 1 and cfg.FirstDelay > 0 and cfg.Interval > 0)
	end)

	t.test(
		"연결: 리모트·속성·서비스 등록·공격 입력이 먼저 점화·출발점 훅·문구·소리",
		function()
			local remotes = fs.readFile("src/shared/Remotes.luau")
			t.ok(string.find(remotes, '"DynamiteFx"', 1, true) ~= nil)
			local attrs = fs.readFile("src/shared/Attributes.luau")
			t.ok(string.find(attrs, 'HeldItem = "HeldItem"', 1, true) ~= nil)
			t.ok(string.find(attrs, 'DynamiteFuseAt = "DynamiteFuseAt"', 1, true) ~= nil)
			local server = fs.readFile("src/server/init.server.luau")
			t.ok(string.find(server, "script.DynamiteService", 1, true) ~= nil)
			local client = fs.readFile("src/client/init.client.luau")
			t.ok(string.find(client, "fx.DynamiteFxController", 1, true) ~= nil)
			local attack = fs.readFile("src/server/AttackService.luau")
			local light = string.find(attack, "DynamiteService.tryLight(player)", 1, true)
			local normal = string.find(attack, "\tattack(player)", 1, true)
			t.ok(light ~= nil and normal ~= nil and light < normal, "light before normal attack")
			local round = fs.readFile("src/server/RoundService.luau")
			t.ok(string.find(round, "function RoundService.sendToStart(player: Player): boolean", 1, true) ~= nil)
			local service = fs.readFile("src/server/DynamiteService.luau")
			t.ok(string.find(service, "RoundService.sendToStart(player)", 1, true) ~= nil, "home in race")
			t.ok(string.find(service, "Knockback.apply", 1, true) ~= nil, "knock otherwise")
			t.ok(string.find(service, "dynamite-sushi", 1, true) == nil, "no skin ids in judgment")
			local csv = fs.readFile("src/shared/Localization/Strings.csv")
			t.ok(string.find(csv, "\ninput.dynamite.btn,", 1, true) ~= nil)
			local cues = fs.readFile("src/shared/SfxCues.luau")
			for _, cue in { "DynamitePickup", "DynamiteFuse", "DynamiteBoom" } do
				t.ok(string.find(cues, `"{cue}"`, 1, true) ~= nil, cue)
			end
		end
	)
end
