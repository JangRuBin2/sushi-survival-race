--!strict
-- m6-08 QA: 공격 경계값(반지름·면역·쿨다운), 기본값 고정, 서버 판정 원칙(인자 없음·간격·레이서만·넘어짐),
-- 스킨이 판정 코드(공격·넉백·다이너마이트)에 없음, 예전 터치 배치 호환 범위.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local AttackLogic = RobloxRequire.require(Shared.AttackLogic)
local AttackFxLogic = RobloxRequire.require(Shared.AttackFxLogic)
local Config = RobloxRequire.require(Shared.Config)
local TouchLayoutLogic = RobloxRequire.require(Shared.TouchLayoutLogic)
local UiLayout = RobloxRequire.require(Shared.UiLayout)

local cfg = Config.Attack

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local ATTACKER = { userId = 1, position = v(0, 3, 0), look = v(0, 0, -1) }

local function candidate(userId: number, x: number, y: number, z: number, extra: { [string]: any }?)
	local c: { [string]: any } = { userId = userId, position = v(x, y, z), alive = true, down = false }
	if extra then
		for k, value in extra do
			c[k] = value
		end
	end
	return c :: any
end

local SCREENS = { { 844, 390 }, { 667, 375 }, { 568, 320 }, { 1024, 768 }, { 1366, 1024 }, { 2400, 1080 } }

-- 주석·문자열 안이 아닌 코드만 보기 어렵기 때문에, 판정 파일 전체에 스킨 id가 아예 없는지 봐요
local JUDGMENT_FILES = {
	"src/shared/AttackLogic.luau",
	"src/server/AttackService.luau",
	"src/server/Knockback.luau",
	"src/shared/DynamiteLogic.luau",
	"src/server/DynamiteService.luau",
}

return function(t: Test.Test)
	t.test(
		"QA 기본값: 스펙 표 그대로 (반지름 10·튕김 30+14·0.12초·넘어짐 1·쿨다운 8·면역 2·연출 6/150)",
		function()
			t.eq(cfg.Radius, 10)
			t.eq(cfg.KnockHorizontal, 30)
			t.eq(cfg.KnockUp, 14)
			t.eq(cfg.KnockHold, 0.12)
			t.eq(cfg.Stun, 1.0)
			t.eq(cfg.Cooldown, 8)
			t.eq(cfg.Immunity, 2.0)
			t.eq(cfg.FxMaxConcurrent, 6)
			t.eq(cfg.FxMaxDistance, 150)
			-- 이동 감시 면제가 넘어짐보다 길어야 넘어진 채 미끄러지는 동안 되돌림이 없어요
			t.ok(cfg.MoveExempt >= cfg.Stun, "MoveExempt covers stun")
			t.ok(Config.Dynamite.MoveExempt >= Config.Dynamite.Stun, "dynamite MoveExempt covers stun")
			t.ok(cfg.InputMinInterval > 0 and cfg.InputMinInterval < cfg.Cooldown)
		end
	)

	t.test("QA 경계: 반지름 딱 10은 맞고 10.001은 안 맞음 — 위·아래도 같은 구", function()
		local list = {
			candidate(2, cfg.Radius, 3, 0), -- 옆 정확히 10
			candidate(3, 0, 3 + cfg.Radius, 0), -- 바로 위 10
			candidate(4, 0, 3 - cfg.Radius - 0.001, 0), -- 아래 10.001
			candidate(5, cfg.Radius + 0.001, 3, 0),
		}
		local hits = AttackLogic.pickTargets(ATTACKER, list, cfg)
		t.eq(hits, { 2, 3 })
	end)

	t.test("QA 경계: 빈 후보·나만 있음·모두 면역이면 빈 목록", function()
		t.eq(AttackLogic.pickTargets(ATTACKER, {}, cfg), {})
		t.eq(AttackLogic.pickTargets(ATTACKER, { candidate(1, 0, 3, 0) }, cfg), {})
		t.eq(AttackLogic.pickTargets(ATTACKER, { candidate(2, 1, 3, 0, { immune = true }) }, cfg), {})
	end)

	t.test("QA 튕김 세기는 거리와 무관 (가까워도 멀어도 수평 30, 위 14)", function()
		for _, d in { 0.01, 1, 5, 9.99 } do
			local k = AttackLogic.knockFor(ATTACKER, v(d * 0.6, 7, -d * 0.8), cfg)
			t.ok(math.abs(math.sqrt(k.x * k.x + k.z * k.z) - cfg.KnockHorizontal) < 1e-9, `horizontal at {d}`)
			t.eq(k.y, cfg.KnockUp)
		end
		-- 바라보는 방향에 y만 있으면(수직) -Z
		local up = AttackLogic.knockFor({ userId = 1, position = v(0, 0, 0), look = v(0, 1, 0) }, v(0, 5, 0), cfg)
		t.eq(up.x, 0)
		t.eq(up.z, -cfg.KnockHorizontal)
	end)

	t.test("QA 북: 쿨다운 중 record는 false이고 면역도 안 바꿔요, 경계 시각은 풀림", function()
		local book = AttackLogic.newBook()
		t.ok(AttackLogic.record(book, 1, { 2 }, 100, cfg))
		t.eq(AttackLogic.readyAt(book, 1), 100 + cfg.Cooldown)
		t.ok(not AttackLogic.record(book, 1, { 3 }, 101, cfg), "still cooling")
		t.ok(not AttackLogic.isImmune(book, 3, 101), "no immunity from a rejected attack")
		t.ok(AttackLogic.isImmune(book, 2, 100 + cfg.Immunity - 0.001))
		t.ok(not AttackLogic.isImmune(book, 2, 100 + cfg.Immunity), "immunity ends exactly")
		t.ok(AttackLogic.canAttack(book, 1, 100 + cfg.Cooldown), "cooldown ends exactly")
		-- 아무도 안 맞아도 쿨다운은 써요
		local empty = AttackLogic.newBook()
		t.ok(AttackLogic.record(empty, 9, {}, 0, cfg))
		t.ok(not AttackLogic.canAttack(empty, 9, cfg.Cooldown - 0.01))
		-- 맞은 사람은 쿨다운이 없어요 (바로 반격)
		t.ok(AttackLogic.canAttack(book, 2, 100))
	end)

	t.test(
		"QA 서버: AttackInput은 인자 없음·간격·레이서·넘어짐·쿨다운을 서버가 봐요",
		function()
			local src = fs.readFile("src/server/AttackService.luau")
			t.ok(string.find(src, 'select("#", ...) > 0', 1, true) ~= nil, "rejects any argument")
			t.ok(string.find(src, "Config.Attack.InputMinInterval", 1, true) ~= nil, "rate limit")
			t.ok(
				string.find(src, "RoundService.activeRoomOf(player)", 1, true) ~= nil,
				"attacker must be an active racer"
			)
			t.ok(
				string.find(src, "RoundService.activeRoomOf(other) ~= roomId", 1, true) ~= nil,
				"targets only in the same room"
			)
			t.ok(string.find(src, "AttackLogic.canAttack(book, player.UserId, now)", 1, true) ~= nil, "cooldown")
			t.ok(string.find(src, "isDown(body)", 1, true) ~= nil, "down attacker rejected")
			-- 나간 사람 기록 정리
			t.ok(string.find(src, "AttackLogic.removePlayer(book, player.UserId)", 1, true) ~= nil)
			t.ok(string.find(src, "lastPress[player] = nil", 1, true) ~= nil)
			-- 연출은 같은 방 사람에게만, 서버는 OnServerEvent를 AttackFx에 걸지 않아요
			t.ok(string.find(src, "RoomService.getPlayers(roomId)", 1, true) ~= nil)
			t.eq(string.find(src, "attackFxEvent.OnServerEvent", 1, true), nil)
			-- 넉백은 이동 감시 면제와 함께 (Knockback 한 곳)
			local knock = fs.readFile("src/server/Knockback.luau")
			local exempt = string.find(knock, "MoveExempt.mark(character", 1, true)
			local push = string.find(knock, 'Instance.new("LinearVelocity")', 1, true)
			t.ok(exempt ~= nil and push ~= nil and exempt < push, "exempt before the push")
			-- 탈락 고정(Anchored) 중이면 넘어짐을 풀지 않아요
			t.ok(string.find(knock, "not root.Anchored", 1, true) ~= nil)
		end
	)

	t.test(
		"QA 스킨은 겉모습만: 공격·넉백·다이너마이트 판정 파일에 스킨 id·AppearanceId·연출 표가 없어요",
		function()
			for _, path in JUDGMENT_FILES do
				local src = fs.readFile(path)
				for skinId in AttackFxLogic.STYLE_BY_SKIN do
					t.eq(string.find(src, skinId, 1, true), nil, `{path} has {skinId}`)
				end
				t.eq(string.find(src, "AppearanceId", 1, true), nil, `{path} reads AppearanceId`)
				t.eq(string.find(src, "Shared.AttackFxLogic", 1, true), nil, `{path} requires the fx table`)
				t.eq(string.find(src, "Shared.Skins", 1, true), nil, `{path} requires the skin catalog`)
			end
			-- 공격 수치는 Config.Attack 하나 (스킨별 표 없음)
			for key, value in cfg do
				t.ok(type(value) == "number", `Config.Attack.{key} is a single number`)
			end
		end
	)

	t.test(
		"QA 터치: 공격 버튼은 모든 화면에서 44px 이상이고 기본 배치 4개가 화면 안",
		function()
			for _, size in SCREENS do
				local d = UiLayout.touchButtons(size[1], size[2])
				t.ok(d.attack.size >= 44, `attack size {size[1]}x{size[2]}`)
				for _, name in TouchLayoutLogic.NAMES do
					local r = (d :: any)[name]
					t.ok(r.x >= 0 and r.y >= 0, `{name} on screen {size[1]}`)
					t.ok(r.x + r.size <= size[1] and r.y + r.size <= size[2], `{name} inside {size[1]}`)
				end
			end
		end
	)

	t.test("QA 터치: 예전(3버튼) 'large' 저장값은 그대로 쓰여요", function()
		for _, size in SCREENS do
			local s = TouchLayoutLogic.screen(size[1], size[2], nil, 58)
			local layout =
				TouchLayoutLogic.quantize(TouchLayoutLogic.fromScreen(TouchLayoutLogic.preset("large", s), s)) :: any
			layout.preset = "large"
			layout.attack = nil -- m6-08 전 저장값
			local again = TouchLayoutLogic.sanitizeLayout(layout)
			t.ok(again ~= nil, "accepted")
			local resolved = TouchLayoutLogic.resolve(again :: any, s)
			t.ok(resolved ~= nil, `old large layout kept {size[1]}x{size[2]}`)
		end
	end)

	t.test("QA 리모트 수: RemoteFunction 16 + RemoteEvent 14 = 30, 새 이벤트 3개", function()
		local src = fs.readFile("src/shared/Remotes.luau")
		local events = string.match(src, "local EVENTS = (%b{})") :: string
		local n = 0
		for _ in string.gmatch(events, '"[%w]+"') do
			n += 1
		end
		t.eq(n, 14)
		for _, name in { "AttackInput", "AttackFx", "DynamiteFx" } do
			t.ok(string.find(events, `"{name}"`, 1, true) ~= nil, name)
		end
	end)
end
