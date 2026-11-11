--!strict
-- f1-02 스시 파이트 특수 스킬: FightSkills (카탈로그·시그니처·스킬 게이지·판정 도우미) + FightLogic guard

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local FightSkills = RobloxRequire.require(Shared.fight.FightSkills)
local FightLogic = RobloxRequire.require(Shared.fight.FightLogic)
local FightConfig = RobloxRequire.require(Shared.fight.FightConfig)
local Skins = RobloxRequire.require(Shared.Skins)

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local function near(t: Test.Test, actual: number, expected: number, message: string)
	t.ok(math.abs(actual - expected) < 1e-6, `{message}: expected {expected}, got {actual}`)
end

return function(t: Test.Test)
	t.test("AC1: 스킬은 6종이고 기본 스킬도 그중 하나", function()
		t.eq(#FightSkills.IDS, 6, "six skills")
		for _, id in FightSkills.IDS do
			t.ok(FightSkills.isSkill(id), id)
			t.ok(FightConfig.Skills[id] ~= nil, `{id} has numbers in FightConfig.Skills`)
		end
		t.ok(FightSkills.isSkill(FightSkills.DEFAULT), "default")
		t.eq(FightSkills.isSkill("Hadouken"), false, "unknown")
		t.eq(FightSkills.isSkill(3), false, "non-string")
	end)

	t.test("AC2: 시그니처는 에픽·전설 스킨 전부, 그리고 그것만", function()
		local expected: { [string]: boolean } = {}
		for _, skin in Skins.LIST do
			if skin.tier == "Epic" or skin.tier == "Legendary" then
				expected[skin.id] = true
				t.ok(FightSkills.SIGNATURES[skin.id] ~= nil, `{skin.id} ({skin.tier}) has a signature`)
			end
		end
		for skinId in FightSkills.SIGNATURES do
			t.ok(expected[skinId] == true, `{skinId} is Epic/Legendary`)
		end
	end)

	t.test("AC3: 시그니처는 겉모습 필드만 — 스킨이 스킬 수치를 바꾸지 못해요", function()
		local allowed = { skill = true, color = true, fx = true }
		local fxKinds = { Fire = true, Sparkles = true, Smoke = true, Glow = true }
		for skinId, sig in FightSkills.SIGNATURES do
			for key in sig :: any do
				t.ok(allowed[key] == true, `{skinId}.{key} is cosmetic`)
			end
			t.ok(FightSkills.isSkill(sig.skill), `{skinId} skill valid`)
			t.ok(fxKinds[sig.fx] == true, `{skinId} fx kind`)
			t.eq(#sig.color, 3, `{skinId} color RGB`)
			for _, c in sig.color do
				t.ok(c >= 0 and c <= 255 and c == math.floor(c), `{skinId} color range`)
			end
		end
	end)

	t.test("AC4: 스킬마다 시그니처 스킨이 2개 이상 (특정 스킬만 화려하지 않게)", function()
		local count: { [string]: number } = {}
		for _, sig in FightSkills.SIGNATURES do
			count[sig.skill] = (count[sig.skill] or 0) + 1
		end
		for _, id in FightSkills.IDS do
			t.ok((count[id] or 0) >= 2, `{id} has {count[id] or 0} signatures`)
		end
	end)

	t.test("AC5: 처음 고르는 스킬 = 시그니처, 없으면 기본. 선택 검증", function()
		t.eq(FightSkills.defaultSkillFor("dragon-roll"), "SoyDash", "signature")
		t.eq(FightSkills.defaultSkillFor("tamago"), FightSkills.DEFAULT, "basic skin")
		t.eq(FightSkills.defaultSkillFor(nil), FightSkills.DEFAULT, "nil skin")
		t.eq(FightSkills.resolveLoadout("NoriShield", "dragon-roll"), "NoriShield", "free choice")
		t.eq(FightSkills.resolveLoadout("SoyDash", "tamago"), "SoyDash", "basic skin may pick any")
		t.eq(FightSkills.resolveLoadout("Nope", "diamond-uni"), "NoriShield", "bad value falls back")
		t.eq(FightSkills.resolveLoadout({}, "tamago"), FightSkills.DEFAULT, "table falls back")
	end)

	t.test("AC6: 스킬 게이지 — 가만히 50초, 맞히기 +6, 맞기 +4, KO +20, 상한 100", function()
		local m = FightSkills.newMeter()
		FightSkills.tick(m, 25)
		t.eq(m.value, 50, "passive")
		FightSkills.charge(m, "DealtHit")
		FightSkills.charge(m, "TakenHit")
		FightSkills.charge(m, "Ko")
		t.eq(m.value, 80, "charges")
		t.eq(FightSkills.isReady(m), false, "not ready")
		t.eq(FightSkills.consume(m), false, "cannot use")
		t.eq(m.value, 80, "unchanged")
		FightSkills.tick(m, 100)
		t.eq(m.value, FightConfig.Skills.Meter.Max, "capped")
		t.eq(FightSkills.consume(m), true, "use")
		t.eq(m.value, 0, "reset")
		FightSkills.tick(m, -5)
		t.eq(m.value, 0, "negative dt ignored")
	end)

	t.test("AC7: 와사비 폭발 대상 = 나를 뺀 반경 9 안(경계 포함), 높이는 안 봄", function()
		local positions = {
			[1] = v(0, 0, 0),
			[2] = v(9, 0, 0),
			[3] = v(6, 20, 6),
			[4] = v(9.1, 0, 0),
		}
		t.eq(FightSkills.burstTargets(1, positions[1], positions), { 2, 3 }, "targets")
	end)

	t.test("AC8: 김 방패 — 켜진 동안 게이지 절반·넉백 35%", function()
		t.eq(FightSkills.shieldGuard(nil, 10), nil, "no shield")
		t.eq(FightSkills.shieldGuard(12.5, 12.5), nil, "expired exactly")
		local guard = FightSkills.shieldGuard(12.5, 11)
		t.ok(guard ~= nil, "active")

		local function ram(g)
			local book = FightLogic.newBook()
			return FightLogic.hit(
				book,
				{
					attacker = 1,
					target = 2,
					moveName = "Ram",
					attackerPos = v(0, 0, 0),
					targetPos = v(0, 0, -3),
					gauge = 88,
					now = 11,
					guard = g,
				} :: any
			)
		end
		local plain, shielded = ram(nil), ram(guard)
		t.eq(plain.gauge, 100, "plain +12")
		t.eq(shielded.gauge, 94, "shield +6")
		local speedPlain = math.sqrt(plain.velocity.x ^ 2 + plain.velocity.y ^ 2 + plain.velocity.z ^ 2)
		local speedShield = math.sqrt(shielded.velocity.x ^ 2 + shielded.velocity.y ^ 2 + shielded.velocity.z ^ 2)
		near(t, speedShield, FightLogic.knockbackSpeed(94, FightConfig.Moves.Ram) * 0.35, "shield knockback")
		t.ok(speedShield < speedPlain, "less knockback")
		t.ok(shielded.hitstun <= plain.hitstun, "less hitstun")
	end)

	t.test("AC9: 간장 대시는 보는 방향으로 18, 방향이 없으면 제자리", function()
		local e = FightSkills.dashEnd(v(1, 5, 1), v(0, 3, -2))
		near(t, e.x, 1, "x")
		near(t, e.y, 5, "y kept")
		near(t, e.z, 1 - 18, "z")
		t.eq(FightSkills.dashEnd(v(1, 5, 1), v(0, 1, 0)), v(1, 5, 1), "no horizontal facing")
	end)

	t.test("AC10: 밥알 끈끈이는 맞은 뒤 2.5초 동안 속도 절반", function()
		t.eq(FightSkills.stickySpeed(16, nil, 0), 16, "none")
		t.eq(FightSkills.stickySpeed(16, 12.5, 10), 8, "slowed")
		t.eq(FightSkills.stickySpeed(16, 12.5, 12.5), 16, "ends")
	end)

	t.test("AC11: 초생강 입가심은 게이지 -25, 0 아래로 안 내려감", function()
		t.eq(FightSkills.cleanse(80), 55, "heal")
		t.eq(FightSkills.cleanse(10), 0, "floor")
	end)

	t.test("AC12: 스킬 타격 기술은 FightLogic.hit으로 판정돼요", function()
		for _, name in { "Burst", "DashHit", "SpinTick" } do
			local result = FightLogic.hit(
				FightLogic.newBook(),
				{
					attacker = 1,
					target = 2,
					moveName = name,
					attackerPos = v(0, 0, 0),
					targetPos = v(2, 0, 0),
					gauge = 0,
					now = 0,
				} :: any
			)
			t.eq(result.applied, true, name)
			t.eq(result.gauge, FightConfig.Moves[name].gauge, `{name} gauge`)
		end
	end)
end
