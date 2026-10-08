--!strict
-- m5-03 시즌 이벤트 카탈로그 (Shared.Seasons)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Seasons = RobloxRequire.require(Shared.Seasons)
local Skins = RobloxRequire.require(Shared.Skins)

local HALLOWEEN_START = 1792108800 -- 2026-10-16 00:00 UTC
local HALLOWEEN_END = 1793923200 -- 2026-11-06 00:00 UTC
local CHRISTMAS_START = 1796947200 -- 2026-12-11 00:00 UTC
local CHRISTMAS_END = 1799366400 -- 2027-01-08 00:00 UTC

return function(t: Test.Test)
	t.test("AC6: validate 통과, 이벤트 2개의 기간·재화가 스펙 표와 같아요", function()
		local ok, problems = Seasons.validate(Seasons.LIST)
		t.ok(ok, table.concat(problems, "; "))
		local halloween = Seasons.get("halloween-2026")
		t.ok(halloween ~= nil)
		t.eq(halloween.name, "할로윈 초밥 축제")
		t.eq(halloween.startsAt, HALLOWEEN_START)
		t.eq(halloween.endsAt, HALLOWEEN_END)
		t.eq(halloween.token, { name = "사탕", icon = "🍬" })
		local christmas = Seasons.get("christmas-2026")
		t.ok(christmas ~= nil)
		t.eq(christmas.name, "크리스마스 초밥 축제")
		t.eq(christmas.startsAt, CHRISTMAS_START)
		t.eq(christmas.endsAt, CHRISTMAS_END)
		t.eq(christmas.token, { name = "별", icon = "⭐" })
		t.eq(Seasons.get("no-such-event"), nil)
	end)

	t.test("AC6: 날짜 숫자가 UTC 자정이고 3주·4주예요", function()
		t.eq(HALLOWEEN_START % 86400, 0)
		t.eq((HALLOWEEN_END - HALLOWEEN_START) / 86400, 21)
		t.eq((CHRISTMAS_END - CHRISTMAS_START) / 86400, 28)
	end)

	t.test("AC6: current는 [startsAt, endsAt) 안에서만", function()
		t.eq(Seasons.current(HALLOWEEN_START - 1), nil)
		t.eq((Seasons.current(HALLOWEEN_START) :: any).id, "halloween-2026")
		t.eq((Seasons.current(HALLOWEEN_END - 1) :: any).id, "halloween-2026")
		t.eq(Seasons.current(HALLOWEEN_END), nil)
		t.eq((Seasons.current(CHRISTMAS_START) :: any).id, "christmas-2026")
		t.eq(Seasons.current(CHRISTMAS_END), nil)
		t.ok(Seasons.isActive("halloween-2026", HALLOWEEN_START))
		t.ok(not Seasons.isActive("halloween-2026", CHRISTMAS_START))
		t.ok(not Seasons.isActive("no-such-event", HALLOWEEN_START))
	end)

	t.test("current: 기간이 겹치면 startsAt이 늦은 이벤트", function()
		local saved = Seasons.LIST
		Seasons.LIST = {
			{ id = "a", name = "A", startsAt = 100, endsAt = 1000, token = { name = "a", icon = "a" } },
			{ id = "b", name = "B", startsAt = 500, endsAt = 800, token = { name = "b", icon = "b" } },
		}
		local ok, err = pcall(function()
			t.eq((Seasons.current(600) :: any).id, "b")
			t.eq((Seasons.current(900) :: any).id, "a")
		end)
		Seasons.LIST = saved
		assert(ok, err)
	end)

	t.test("AC6: skinOnSale — 시즌 스킨은 기간 안에서만, 시즌 없는 스킨은 언제나", function()
		local pumpkin = Skins.get("pumpkin-sushi")
		t.eq(Seasons.skinOnSale(pumpkin, HALLOWEEN_START - 1), false)
		t.eq(Seasons.skinOnSale(pumpkin, HALLOWEEN_START), true)
		t.eq(Seasons.skinOnSale(pumpkin, HALLOWEEN_END), false)
		t.eq(Seasons.skinOnSale(Skins.get("santa-shrimp"), CHRISTMAS_START), true)
		t.eq(Seasons.skinOnSale(Skins.get("santa-shrimp"), HALLOWEEN_START), false)
		for _, now in { 0, HALLOWEEN_START, CHRISTMAS_END + 1 } do
			t.eq(Seasons.skinOnSale(Skins.get("salmon"), now), true)
			t.eq(Seasons.skinOnSale(Skins.get("vip-gold-tamago"), now), true)
		end
	end)

	t.test("AC6: daysLeft는 올림, 진행 중일 때만", function()
		t.eq(Seasons.daysLeft("halloween-2026", HALLOWEEN_START), 21)
		t.eq(Seasons.daysLeft("halloween-2026", HALLOWEEN_START + 1), 21)
		t.eq(Seasons.daysLeft("halloween-2026", HALLOWEEN_END - 1), 1)
		t.eq(Seasons.daysLeft("halloween-2026", HALLOWEEN_END), nil)
		t.eq(Seasons.daysLeft("halloween-2026", HALLOWEEN_START - 1), nil)
		t.eq(Seasons.daysLeft("no-such-event", HALLOWEEN_START), nil)
	end)

	t.test("now: Studio이고 eventNow가 숫자일 때만 그 값", function()
		t.eq(Seasons.now(true, HALLOWEEN_START, 5), HALLOWEEN_START)
		t.eq(Seasons.now(false, HALLOWEEN_START, 5), 5)
		t.eq(Seasons.now(true, nil, 5), 5)
	end)

	t.test("validate: id 겹침, startsAt ≥ endsAt, 재화 이름·아이콘 없음을 잡아요", function()
		local token = { name = "사탕", icon = "🍬" }
		local cases = {
			{
				{ id = "x", name = "X", startsAt = 1, endsAt = 2, token = token },
				{ id = "x", name = "X2", startsAt = 3, endsAt = 4, token = token },
			},
			{ { id = "x", name = "X", startsAt = 2, endsAt = 2, token = token } },
			{ { id = "x", name = "X", startsAt = 1, endsAt = 2, token = { name = "", icon = "🍬" } } },
			{ { id = "x", name = "X", startsAt = 1, endsAt = 2, token = { name = "사탕" } } },
			{ { id = "", name = "X", startsAt = 1, endsAt = 2, token = token } },
		}
		for i, list in cases do
			local ok, problems = Seasons.validate(list)
			t.eq(ok, false, `case {i}`)
			t.ok(#problems >= 1, `case {i} problems`)
		end
	end)
end
