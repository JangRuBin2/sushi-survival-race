--!strict
-- m6-08 공격: AttackLogic(대상·튕김·쿨다운·면역), AttackFxLogic(스킨별 연출 표·미사일 경로),
-- 터치 버튼 4개(attack) 배치·예전 저장값 호환, 리모트·속성·문구·연결.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AttackLogic = RobloxRequire.require(Shared.AttackLogic)
local AttackFxLogic = RobloxRequire.require(Shared.AttackFxLogic)
local Config = RobloxRequire.require(Shared.Config)
local TouchLayoutLogic = RobloxRequire.require(Shared.TouchLayoutLogic)
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local Skins = RobloxRequire.require(Shared.Skins)

local cfg = Config.Attack

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local ATTACKER = { userId = 1, position = v(0, 3, 0), look = v(0, 0, -1) }

local function candidate(userId: number, x: number, z: number, extra: { [string]: any }?)
	local c: { [string]: any } = { userId = userId, position = v(x, 3, z), alive = true, down = false }
	if extra then
		for k, value in extra do
			c[k] = value
		end
	end
	return c :: any
end

local SCREENS = { { 844, 390 }, { 667, 375 }, { 568, 320 }, { 1024, 768 }, { 1366, 1024 }, { 2400, 1080 } }

return function(t: Test.Test)
	-------------------------------------------------------------- AC1 대상
	t.test("AC1: 반지름 안은 방향과 무관하게 모두, 가까운 순", function()
		local hits = AttackLogic.pickTargets(ATTACKER, {
			candidate(2, 0, 8), -- 뒤 8
			candidate(3, -3, 0), -- 옆 3
			candidate(4, 0, -cfg.Radius), -- 경계
			candidate(5, 0, -(cfg.Radius + 0.1)), -- 밖
		}, cfg)
		t.eq(hits, { 3, 2, 4 })
	end)

	t.test("AC1: 나·죽음·넘어짐·면역은 빼요", function()
		local hits = AttackLogic.pickTargets(ATTACKER, {
			candidate(1, 0, 2),
			candidate(2, 0, 2, { alive = false }),
			candidate(3, 0, 2, { down = true }),
			candidate(4, 0, 2, { immune = true }),
			candidate(5, 2, 0),
		}, cfg)
		t.eq(hits, { 5 })
	end)

	t.test("AC1: 같은 거리면 userId 순 (결과가 늘 같게)", function()
		t.eq(AttackLogic.pickTargets(ATTACKER, { candidate(9, 0, 3), candidate(7, 3, 0) }, cfg), { 7, 9 })
	end)

	-------------------------------------------------------------- AC2 튕김
	t.test("AC2: 바깥쪽 수평 + 위", function()
		local k = AttackLogic.knockFor(ATTACKER, v(3, 10, 4), cfg)
		t.ok(math.abs(k.x - 0.6 * cfg.KnockHorizontal) < 1e-9, "x")
		t.ok(math.abs(k.z - 0.8 * cfg.KnockHorizontal) < 1e-9, "z")
		t.eq(k.y, cfg.KnockUp)
	end)

	t.test("AC2: 바로 위·아래면 바라보는 방향, 그것도 없으면 -Z", function()
		local k = AttackLogic.knockFor(ATTACKER, v(0, 8, 0), cfg)
		t.eq(k.x, 0)
		t.eq(k.z, -cfg.KnockHorizontal)
		local noLook = { userId = 1, position = v(0, 3, 0), look = v(0, 1, 0) }
		local k2 = AttackLogic.knockFor(noLook, v(0, 0, 0), cfg)
		t.eq(k2.z, -cfg.KnockHorizontal)
	end)

	-------------------------------------------------------------- AC3 북
	t.test("AC3: 쿨다운 — 기록하면 Cooldown초 동안 못 하고 그 뒤 돼요", function()
		local book = AttackLogic.newBook()
		t.ok(AttackLogic.canAttack(book, 1, 0))
		t.eq(AttackLogic.readyAt(book, 1), nil)
		t.ok(AttackLogic.record(book, 1, {}, 10, cfg), "first")
		t.eq(AttackLogic.readyAt(book, 1), 10 + cfg.Cooldown)
		t.ok(not AttackLogic.canAttack(book, 1, 10 + cfg.Cooldown - 0.01))
		t.ok(not AttackLogic.record(book, 1, { 2 }, 11, cfg), "during cooldown")
		t.ok(not AttackLogic.isImmune(book, 2, 11), "rejected attack gives no immunity")
		t.ok(AttackLogic.canAttack(book, 1, 10 + cfg.Cooldown))
	end)

	t.test("AC3: 맞은 사람은 Immunity초 면역, 나간 사람 기록은 지워요", function()
		local book = AttackLogic.newBook()
		AttackLogic.record(book, 1, { 2, 3 }, 5, cfg)
		t.ok(AttackLogic.isImmune(book, 2, 5 + cfg.Immunity - 0.01))
		t.ok(not AttackLogic.isImmune(book, 2, 5 + cfg.Immunity))
		-- 맞은 사람은 쿨다운이 없어요 (바로 반격 가능)
		t.ok(AttackLogic.canAttack(book, 2, 5))
		AttackLogic.removePlayer(book, 1)
		AttackLogic.removePlayer(book, 3)
		t.ok(AttackLogic.canAttack(book, 1, 5))
		t.ok(not AttackLogic.isImmune(book, 3, 5))
	end)

	t.test("AC3: 기본값 범위 (면역 > 넘어짐, 쿨다운 > 면역)", function()
		t.ok(cfg.Radius > 0 and cfg.Radius <= 20, "radius")
		t.ok(cfg.Immunity > cfg.Stun, "immunity longer than stun")
		t.ok(cfg.Cooldown > cfg.Immunity, "cooldown longer than immunity")
		t.ok(cfg.InputMinInterval > 0 and cfg.InputMinInterval < cfg.Cooldown, "input interval")
	end)

	-------------------------------------------------------------- AC4 연출
	t.test("AC4: 스킨 → 연출 표, 모르는 id·nil·숫자는 RiceBurst", function()
		t.eq(AttackFxLogic.styleFor("dragon-sushi"), "Flame")
		t.eq(AttackFxLogic.styleFor("sky-dragon-sushi"), "Storm")
		t.eq(AttackFxLogic.styleFor("jet-sushi"), "Missile")
		t.eq(AttackFxLogic.styleFor("shadow-jet-sushi"), "ShadowMissile")
		t.eq(AttackFxLogic.styleFor("tamago"), "RiceBurst")
		t.eq(AttackFxLogic.styleFor(nil), "RiceBurst")
		t.eq(AttackFxLogic.styleFor(42), "RiceBurst")
		for style in AttackFxLogic.STYLES do
			local info = AttackFxLogic.info(style)
			t.ok(info.duration > 0 and info.duration <= 1.5, `{style} duration`)
		end
		for _, style in AttackFxLogic.STYLE_BY_SKIN do
			t.ok(AttackFxLogic.STYLES[style] ~= nil, `{style} defined`)
		end
	end)

	t.test("AC4: 연출 표의 스킨은 모두 카탈로그의 전설 스킨", function()
		for skinId in AttackFxLogic.STYLE_BY_SKIN do
			local skin = Skins.get(skinId)
			t.ok(skin ~= nil, `{skinId} in catalog`)
			t.eq(skin and skin.tier, "Legendary", `{skinId} tier`)
		end
	end)

	t.test("AC4: 연출 스킨은 판정 코드에 없어요 (스킨은 겉모습만, GDD 9.1)", function()
		for _, path in { "src/shared/AttackLogic.luau", "src/server/AttackService.luau" } do
			local src = fs.readFile(path)
			for skinId in AttackFxLogic.STYLE_BY_SKIN do
				t.ok(string.find(src, skinId, 1, true) == nil, `{path} has {skinId}`)
			end
			t.ok(string.find(src, "AppearanceId", 1, true) == nil, `{path} reads AppearanceId`)
		end
	end)

	t.test("AC4: 미사일 — 시작·끝을 지나고 가운데가 위로 휘어요", function()
		local from, to = v(0, 3, 0), v(8, 3, 0)
		local a = AttackFxLogic.missilePoint(from, to, 0, 6)
		local b = AttackFxLogic.missilePoint(from, to, 1, 6)
		local mid = AttackFxLogic.missilePoint(from, to, 0.5, 6)
		t.eq(a, from)
		t.eq(b, to)
		t.ok(mid.y > 3 + 2.9, "arcs up")
		t.ok(math.abs(mid.x - 4) < 1e-9, "midpoint x")
	end)

	t.test("AC4: 미사일 도착점 — 맞은 사람 최대 6, 없으면 바깥 4방향 반지름 거리", function()
		local hits = {}
		for i = 1, 9 do
			table.insert(hits, v(i, 3, 0))
		end
		t.eq(#AttackFxLogic.missileTargets(v(0, 3, 0), hits, 10), AttackFxLogic.MAX_MISSILES)
		local empty = AttackFxLogic.missileTargets(v(0, 3, 0), {}, 10)
		t.eq(#empty, AttackFxLogic.EMPTY_MISSILES)
		for _, p in empty do
			t.ok(math.abs(math.sqrt(p.x * p.x + p.z * p.z) - 10) < 1e-9, "radius")
		end
	end)

	t.test("AC4: 고리·투명도·띠 계산", function()
		t.eq(AttackFxLogic.ringRadius(0, 10), 0)
		t.eq(AttackFxLogic.ringRadius(1, 10), 10)
		t.ok(AttackFxLogic.ringRadius(0.5, 10) > 5, "ease out")
		t.eq(AttackFxLogic.fade(0.3), 0)
		t.eq(AttackFxLogic.fade(1), 1)
		local head = AttackFxLogic.helixPoint(v(0, 0, 0), 12, 12, 1, 5, 7, 1)
		local tail = AttackFxLogic.helixPoint(v(0, 0, 0), 1, 12, 1, 5, 7, 1)
		t.ok(head.y > tail.y, "head above tail")
		t.ok(math.abs(math.sqrt(head.x * head.x + head.z * head.z) - 5) < 1e-9, "radius at end")
	end)

	-------------------------------------------------------------- AC5 터치 버튼
	t.test("AC5: 기본·large·compact 모두 4버튼 겹침 없음·칸 안 (여러 화면)", function()
		for _, size in SCREENS do
			local s = TouchLayoutLogic.screen(size[1], size[2], nil, 58)
			local d = UiLayout.touchButtons(size[1], size[2])
			t.ok(d.attack ~= nil, "default attack")
			t.eq(next(TouchLayoutLogic.overlaps(d)), nil, `default overlap {size[1]}`)
			for _, preset in { "large", "compact" } do
				local b = TouchLayoutLogic.preset(preset, s)
				t.ok(TouchLayoutLogic.isValid(b, s), `{preset} valid {size[1]}x{size[2]}`)
			end
		end
	end)

	t.test("AC5: 기본 공격 자리 = 다이브 위·잡기 왼쪽", function()
		local d = UiLayout.touchButtons(844, 390)
		t.eq(d.attack.x, d.dive.x)
		t.eq(d.attack.y, d.grab.y)
		t.ok(d.attack.x + d.attack.size <= d.grab.x, "left of grab")
		t.ok(d.attack.y + d.attack.size <= d.dive.y, "above dive")
	end)

	t.test("AC5: 예전 3버튼 저장값도 읽히고, 공격은 다이브·잡기에서 정해요", function()
		local old = {
			v = 1,
			preset = "custom",
			jump = { x = 0.9, y = 0.8, s = 0.2 },
			dive = { x = 0.7, y = 0.85, s = 0.17 },
			grab = { x = 0.9, y = 0.5, s = 0.17 },
		}
		local layout = TouchLayoutLogic.sanitizeLayout(old)
		t.ok(layout ~= nil, "old layout accepted")
		t.eq((layout :: any).attack, nil)
		local s = TouchLayoutLogic.screen(844, 390, nil, 58)
		local b = TouchLayoutLogic.toScreen(layout :: any, s)
		t.eq(b.attack.x, b.dive.x)
		t.eq(b.attack.y, b.grab.y)
		-- resolve는 겹치면 줄이거나 기본 배치(nil)로 — 어느 쪽이든 오류 없이
		local resolved = TouchLayoutLogic.resolve(layout :: any, s)
		if resolved then
			t.ok(TouchLayoutLogic.isValid(resolved, s), "resolved valid")
		end
	end)

	t.test("AC5: attack 넣은 배치 왕복, 틀린 attack은 전체 거절", function()
		local s = TouchLayoutLogic.screen(844, 390, nil, 58)
		local b = TouchLayoutLogic.preset("compact", s)
		local layout = TouchLayoutLogic.quantize(TouchLayoutLogic.fromScreen(b, s))
		t.ok(layout.attack ~= nil, "attack saved")
		local again = TouchLayoutLogic.sanitizeLayout(layout)
		t.ok(again ~= nil and again.attack ~= nil, "round trip")
		local bad = table.clone(layout) :: any
		bad.attack = { x = 2, y = 0.5, s = 0.1 }
		t.eq(TouchLayoutLogic.sanitizeLayout(bad), nil)
		local extra = table.clone(layout) :: any
		extra.hack = true
		t.eq(TouchLayoutLogic.sanitizeLayout(extra), nil)
	end)

	-------------------------------------------------------------- AC6 연결·문구
	t.test("AC6: 리모트·속성·서비스·컨트롤러·소리·문구가 이어져 있어요", function()
		local remotes = fs.readFile("src/shared/Remotes.luau")
		t.ok(string.find(remotes, '"AttackInput"', 1, true) ~= nil, "AttackInput")
		t.ok(string.find(remotes, '"AttackFx"', 1, true) ~= nil, "AttackFx")
		local attrs = fs.readFile("src/shared/Attributes.luau")
		t.ok(string.find(attrs, 'AttackReadyAt = "AttackReadyAt"', 1, true) ~= nil, "attribute")
		local server = fs.readFile("src/server/init.server.luau")
		t.ok(string.find(server, "script.AttackService", 1, true) ~= nil, "service")
		local client = fs.readFile("src/client/init.client.luau")
		local touch = string.find(client, "input.TouchLayoutController", 1, true)
		local attack = string.find(client, "input.AttackController", 1, true)
		t.ok(touch ~= nil and attack ~= nil and touch < attack, "controller after touch layout")
		t.ok(string.find(client, "fx.AttackFxController", 1, true) ~= nil, "fx controller")
		local csv = fs.readFile("src/shared/Localization/Strings.csv")
		for _, key in { "input.attack.btn", "input.attack.cooldown" } do
			t.ok(string.find(csv, "\n" .. key .. ",", 1, true) ~= nil, key)
		end
		local cues = fs.readFile("src/shared/SfxCues.luau")
		t.ok(string.find(cues, '"Attack"', 1, true) ~= nil, "sfx cue")
		local service = fs.readFile("src/server/AttackService.luau")
		t.ok(string.find(service, "MoveExempt.mark", 1, true) ~= nil, "move exempt")
		t.ok(string.find(service, "RoundService.activeRoomOf", 1, true) ~= nil, "racers only")
	end)
end
