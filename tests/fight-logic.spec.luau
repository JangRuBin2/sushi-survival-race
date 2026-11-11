--!strict
-- f1-01 스시 파이트 핵심 로직: FightLogic (게이지·넉백·장외·타격 장부·매치·아이템)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local FightLogic = RobloxRequire.require(Shared.fight.FightLogic)
local FightConfig = RobloxRequire.require(Shared.fight.FightConfig)

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local function near(t: Test.Test, actual: number, expected: number, message: string)
	t.ok(math.abs(actual - expected) < 1e-6, `{message}: expected {expected}, got {actual}`)
end

local ARENA = { center = v(0, 0, 0), floorY = 10, radius = 40 }

local function hitInput(overrides: { [string]: any }?)
	local input: { [string]: any } = {
		attacker = 1,
		target = 2,
		moveName = "Slap",
		attackerPos = v(0, 13, 0),
		targetPos = v(0, 13, -3),
		facing = v(0, 0, -1),
		gauge = 0,
		now = 100,
	}
	if overrides then
		for k, value in overrides do
			input[k] = value
		end
	end
	return input :: any
end

return function(t: Test.Test)
	t.test("AC1: 게이지는 0~300으로 잘리고 회복은 0 아래로 안 내려가요", function()
		t.eq(FightLogic.applyGauge(0, 12), 12, "add")
		t.eq(FightLogic.applyGauge(295, 12), FightConfig.Gauge.Max, "cap")
		t.eq(FightLogic.applyGauge(20, -FightConfig.Items.GingerHeal), 0, "ginger floor")
		t.eq(FightLogic.applyGauge(80, -FightConfig.Items.GingerHeal), 50, "ginger")
	end)

	t.test("AC2: 간장 색 진하기는 0%에서 0, 150% 이상에서 1", function()
		t.eq(FightLogic.soyTint(0), 0, "zero")
		near(t, FightLogic.soyTint(75), 0.5, "half")
		t.eq(FightLogic.soyTint(150), 1, "full")
		t.eq(FightLogic.soyTint(300), 1, "over")
	end)

	t.test("AC3: 넉백 속도 = 기본 + 게이지 × 배율, 상한 220", function()
		local ram = FightConfig.Moves.Ram
		near(t, FightLogic.knockbackSpeed(0, ram), 30, "ram 0%")
		near(t, FightLogic.knockbackSpeed(100, ram), 65, "ram 100%")
		near(t, FightLogic.knockbackSpeed(300, FightConfig.Moves.Wasabi), 175, "strongest move at max gauge")
		local huge = { gauge = 1, base = 200, scale = 1, lift = 0, cooldown = 0 }
		t.eq(FightLogic.knockbackSpeed(100, huge), FightConfig.Knockback.MaxSpeed, "cap")
		t.ok(FightLogic.knockbackSpeed(150, ram) > FightLogic.knockbackSpeed(50, ram), "more gauge flies farther")
	end)

	t.test("AC4: 넉백 방향은 때린 사람 → 맞은 사람, 크기는 넉백 속도", function()
		local ram = FightConfig.Moves.Ram
		local vel = FightLogic.knockbackVelocity(v(0, 0, 0), v(3, 0, 4), 100, ram)
		local speed = FightLogic.knockbackSpeed(100, ram)
		local length = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
		near(t, length, speed, "magnitude")
		near(t, vel.y, speed * ram.lift, "lift")
		near(t, vel.x / vel.z, 3 / 4, "horizontal direction")
		t.ok(vel.x > 0 and vel.z > 0, "away from attacker")
	end)

	t.test("AC4b: 둘이 겹치면 facing, facing도 없으면 -Z로 날아가요", function()
		local slap = FightConfig.Moves.Slap
		local faced = FightLogic.knockbackVelocity(v(1, 0, 1), v(1, 5, 1), 0, slap, v(1, 0, 0))
		t.ok(faced.x > 0 and math.abs(faced.z) < 1e-6, "uses facing")
		local fallback = FightLogic.knockbackVelocity(v(1, 0, 1), v(1, 5, 1), 0, slap)
		t.ok(fallback.z < 0 and math.abs(fallback.x) < 1e-6, "falls back to -Z")
	end)

	t.test("AC5: 경직은 넉백 속도에 비례하고 0.1~1.2초로 잘려요", function()
		near(t, FightLogic.hitstun(100), 0.4, "proportional")
		near(t, FightLogic.hitstun(5), FightConfig.Knockback.HitstunMin, "min")
		near(t, FightLogic.hitstun(1000), FightConfig.Knockback.HitstunMax, "max")
	end)

	t.test("AC6: 장외 = 바닥 25 아래 또는 반지름 + 60 밖, 경계는 아직 아님", function()
		t.eq(FightLogic.isRingOut(v(0, 12, 0), ARENA), false, "on floor")
		t.eq(FightLogic.isRingOut(v(0, -15, 0), ARENA), false, "exactly 25 below")
		t.eq(FightLogic.isRingOut(v(0, -15.5, 0), ARENA), true, "below")
		t.eq(FightLogic.isRingOut(v(100, 12, 0), ARENA), false, "exactly at radius + 60")
		t.eq(FightLogic.isRingOut(v(80, 12, 80), ARENA), true, "outside diagonally")
		t.eq(FightLogic.isRingOut(v(60, 12, 0), ARENA), false, "off the plate but not yet out")
	end)

	t.test("AC7: 맞으면 게이지·넉백·경직이 나오고 마지막 타격이 기록돼요", function()
		local book = FightLogic.newBook()
		local result = FightLogic.hit(book, hitInput({ moveName = "Ram", gauge = 88 }))
		t.eq(result.applied, true, "applied")
		t.eq(result.gauge, 100, "gauge +12")
		t.ok(result.velocity ~= nil and result.velocity.z < 0, "pushed forward (-Z)")
		near(t, result.hitstun, FightLogic.hitstun(65), "hitstun")
		t.eq(FightLogic.koCredit(book, 2, 102), 1, "credit")
	end)

	t.test("AC8: 자기 자신·무적·같은 기술 0.4초 안은 안 맞아요", function()
		local book = FightLogic.newBook()
		local selfHit = FightLogic.hit(book, hitInput({ target = 1 }))
		t.eq(selfHit.applied, false, "self")
		t.eq(selfHit.reason, "Self", "self reason")

		FightLogic.setInvincible(book, 2, 102)
		local inv = FightLogic.hit(book, hitInput({ gauge = 30, now = 101 }))
		t.eq(inv.reason, "Invincible", "invincible")
		t.eq(inv.gauge, 30, "gauge unchanged")
		t.eq(inv.hitstun, 0, "no hitstun")
		t.eq(FightLogic.hit(book, hitInput({ now = 102 })).applied, true, "invincible ends exactly")

		t.eq(FightLogic.hit(book, hitInput({ now = 102.3 })).reason, "Lockout", "same move lockout")
		t.eq(FightLogic.hit(book, hitInput({ moveName = "Ram", now = 102.3 })).applied, true, "other move ok")
		t.eq(FightLogic.hit(book, hitInput({ now = 102.4 })).applied, true, "lockout ends")
		t.eq(FightLogic.hit(book, hitInput({ attacker = 3, now = 102.45 })).applied, true, "other attacker ok")
	end)

	t.test("AC9: KO 점수는 5초 안에 마지막으로 때린 사람, 아니면 자폭", function()
		local book = FightLogic.newBook()
		FightLogic.hit(book, hitInput({ attacker = 1, now = 100 }))
		FightLogic.hit(book, hitInput({ attacker = 3, moveName = "Ram", now = 101 }))
		t.eq(FightLogic.koCredit(book, 2, 106), 3, "last hitter within 5s")
		t.eq(FightLogic.koCredit(book, 2, 106.5), nil, "too old")
		t.eq(FightLogic.koCredit(book, 4, 100), nil, "never hit")
		FightLogic.removeFromBook(book, 2)
		t.eq(FightLogic.koCredit(book, 2, 102), nil, "cleared after ring out")
	end)

	t.test("AC9b: 나간 사람은 때린 기록·잠금도 지워요", function()
		local book = FightLogic.newBook()
		FightLogic.hit(book, hitInput({ attacker = 12, target = 2, now = 100 }))
		FightLogic.hit(book, hitInput({ attacker = 123, target = 5, now = 100 }))
		FightLogic.removeFromBook(book, 12, true)
		t.eq(FightLogic.koCredit(book, 2, 101), nil, "credit removed")
		t.eq(FightLogic.koCredit(book, 5, 101), 123, "similar id kept")
		t.eq(book.lockUntil["12:2:Slap"], nil, "lock removed")
		t.ok(book.lockUntil["123:5:Slap"] ~= nil, "similar id lock kept")
	end)

	t.test("AC10: 장외면 목숨 -1·게이지 0·KO +1, 목숨 0이면 탈락 순서가 붙어요", function()
		local match = FightLogic.newMatch({ 1, 2, 3 })
		match.fighters[2].gauge = 140
		local r1 = FightLogic.ringOut(match, 2, 1)
		t.eq(r1, { counted = true, eliminated = false, stocksLeft = 2, creditedTo = 1 }, "first ring out")
		t.eq(match.fighters[2].gauge, 0, "gauge reset")
		t.eq(match.fighters[1].kos, 1, "ko")
		FightLogic.ringOut(match, 2, nil)
		local r3 = FightLogic.ringOut(match, 2, 3)
		t.eq(r3.eliminated, true, "eliminated")
		t.eq(match.fighters[2].outOrder, 1, "out order")
		t.eq(FightLogic.ringOut(match, 2, 1).counted, false, "already out")
		t.eq(FightLogic.ringOut(match, 99, 1).counted, false, "unknown")
		t.eq(FightLogic.ringOut(match, 3, 3).creditedTo, nil, "no self credit")
	end)

	t.test("AC11: 1명 남으면 우승, 나간 사람은 탈락으로 쳐요", function()
		local match = FightLogic.newMatch({ 1, 2, 3 }, 1)
		t.eq(FightLogic.winner(match), nil, "three alive")
		FightLogic.leave(match, 3)
		t.eq(FightLogic.aliveIds(match), { 1, 2 }, "alive")
		FightLogic.ringOut(match, 1, 3)
		t.eq(match.fighters[3].kos, 0, "left player gets no credit")
		t.eq(FightLogic.winner(match), 2, "winner")
		t.eq(FightLogic.standings(match), { 2, 1, 3 }, "later out ranks higher")
	end)

	t.test("AC12: 순위는 목숨 → 게이지 낮은 순 → KO → 참가 순", function()
		local match = FightLogic.newMatch({ 1, 2, 3, 4, 5 })
		local f = match.fighters
		f[1].stocks, f[1].gauge = 2, 40
		f[2].stocks, f[2].gauge = 3, 90
		f[3].stocks, f[3].gauge, f[3].kos = 2, 40, 2
		f[4].stocks, f[4].gauge = 2, 10
		f[5].stocks, f[5].gauge = 2, 40
		t.eq(FightLogic.standings(match), { 2, 4, 3, 1, 5 }, "standings")
	end)

	t.test("AC13: 시간 종료 — 목숨 1등이 1명이면 우승, 여럿이면 서든데스", function()
		local solo = FightLogic.newMatch({ 1, 2, 3 })
		solo.fighters[1].stocks = 1
		solo.fighters[3].stocks = 2
		t.eq(FightLogic.timeUpLeaders(solo), { 2 }, "single leader")

		local tied = FightLogic.newMatch({ 1, 2, 3, 4 })
		tied.fighters[1].stocks, tied.fighters[1].gauge = 2, 50
		tied.fighters[3].stocks, tied.fighters[3].gauge = 2, 10
		tied.fighters[2].stocks = 1
		FightLogic.leave(tied, 4)
		local leaders = FightLogic.timeUpLeaders(tied)
		t.eq(leaders, { 1, 3 }, "tied leaders")
		FightLogic.startSuddenDeath(tied, leaders)
		t.eq(tied.suddenDeath, true, "flag")
		t.eq(FightLogic.aliveIds(tied), { 1, 3 }, "only leaders alive")
		t.eq(tied.fighters[1].stocks, 1, "one stock")
		t.eq(tied.fighters[3].gauge, FightConfig.Match.SuddenDeathGauge, "sudden death gauge")
		FightLogic.ringOut(tied, 3, 1)
		t.eq(FightLogic.winner(tied), 1, "sudden death winner")
		t.eq(FightLogic.standings(tied), { 1, 3, 2, 4 }, "final standings keep time-up order")
	end)

	t.test("AC13b: 아무도 안 살아 있으면 시간 종료 1등도 없어요", function()
		local match = FightLogic.newMatch({ 1, 2 }, 1)
		FightLogic.leave(match, 1)
		FightLogic.leave(match, 2)
		t.eq(FightLogic.timeUpLeaders(match), {}, "empty")
		t.eq(FightLogic.winner(match), nil, "no winner")
	end)

	t.test("AC14: 젓가락 소환은 나를 뺀 게이지 최고(100% 이상) 살아 있는 사람", function()
		local match = FightLogic.newMatch({ 1, 2, 3, 4 })
		match.fighters[1].gauge = 200
		match.fighters[2].gauge = 120
		match.fighters[3].gauge = 120
		match.fighters[4].gauge = 99
		t.eq(FightLogic.pickChopstickTarget(match, 1), 2, "highest other, first on tie")
		t.eq(FightLogic.pickChopstickTarget(match, 2), 1, "includes highest")
		FightLogic.leave(match, 1)
		FightLogic.leave(match, 2)
		FightLogic.leave(match, 3)
		t.eq(FightLogic.pickChopstickTarget(match, 4), nil, "none above minimum")
	end)

	t.test("AC15: 같은 userId를 두 번 넣어도 한 명이고 기본 목숨은 3개", function()
		local match = FightLogic.newMatch({ 7, 7, 8 })
		t.eq(match.order, { 7, 8 }, "dedupe")
		t.eq(match.fighters[7].stocks, FightConfig.Match.Stocks, "default stocks")
	end)

	t.test("AC16: 모든 기술 수치가 유효해요", function()
		for name, move in FightConfig.Moves do
			t.ok(move.gauge > 0 and move.base > 0 and move.scale >= 0, `{name} positive`)
			t.ok(move.lift >= 0 and move.lift < 1, `{name} lift`)
			t.ok(move.cooldown >= 0, `{name} cooldown`)
		end
	end)
end
