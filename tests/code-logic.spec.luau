--!strict
-- m5-10 코드 보상 판단 (Shared.CodeLogic). 진짜 코드는 저장소에 없어서 (D4) 가짜 목록만 써요.

local RobloxRequire = require("./lib/RobloxRequire")
local LocTest = require("./lib/LocTest")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local CodeLogic = RobloxRequire.require(Shared.CodeLogic)
local Config = RobloxRequire.require(Shared.Config)

local HALLOWEEN_START = 1792108800 -- 2026-10-16 00:00 UTC
local HALLOWEEN_END = 1793923200 -- 2026-11-06 00:00 UTC
local NEW_YEAR = 1798761600 -- 2027-01-01 00:00 UTC

-- 스펙 "코드 목록"의 두 예시와 같은 모양 (이름만 가짜)
local function fakeCodes(): { any }
	return {
		{ code = "FAKE2026", coins = 200, startsAt = nil, expiresAt = NEW_YEAR },
		{
			code = "FAKESPOOKY",
			coins = 100,
			tokens = 10,
			eventId = "halloween-2026",
			startsAt = HALLOWEEN_START,
			expiresAt = HALLOWEEN_END,
		},
	}
end

local function problemsOf(entry: any): { string }
	local _, problems = CodeLogic.validateConfig({ entry })
	return problems
end

return function(t: Test.Test)
	t.test("Config.Codes 기본값 (스펙)", function()
		t.eq(Config.Codes.RequestCooldown, 2)
		t.eq(Config.Codes.MaxFailures, 8)
		t.eq(Config.Codes.FailureWindow, 600)
		t.eq(Config.Codes.MaxLength, 20)
	end)

	t.test("AC1: normalize — 앞뒤 공백·대소문자", function()
		t.eq(CodeLogic.normalize("  sushi2026 "), "SUSHI2026")
		t.eq(CodeLogic.normalize("SUSHI2026"), "SUSHI2026")
		t.eq(CodeLogic.normalize("\tAbc\n"), "ABC")
		t.eq(CodeLogic.normalize(string.rep("A", 20)), string.rep("A", 20))
	end)

	t.test("AC1: normalize — 형식 오류는 nil", function()
		t.eq(CodeLogic.normalize("ab"), nil)
		t.eq(CodeLogic.normalize("SUSHI 2026"), nil)
		t.eq(CodeLogic.normalize("코드"), nil)
		t.eq(CodeLogic.normalize("코드123"), nil)
		t.eq(CodeLogic.normalize(string.rep("A", 21)), nil)
		t.eq(CodeLogic.normalize(""), nil)
		t.eq(CodeLogic.normalize("   "), nil)
		t.eq(CodeLogic.normalize("SUSHI-2026"), nil)
		t.eq(CodeLogic.normalize(string.rep(" ", 500) .. "ABC"), nil)
		t.eq(CodeLogic.normalize(12345), nil)
		t.eq(CodeLogic.normalize(nil), nil)
		t.eq(CodeLogic.normalize({ "ABC" }), nil)
		t.eq(CodeLogic.normalize(true), nil)
	end)

	t.test("AC2: check — 순서와 Reason", function()
		local codes = CodeLogic.validateConfig(fakeCodes())
		local fake = codes[1]
		local spooky = codes[2]
		local now = HALLOWEEN_START + 100

		local ok, reason, counts = CodeLogic.check("NOPE123", nil, now, {}, {})
		t.eq({ ok, reason, counts }, { false, "Unknown", true })

		ok, reason, counts = CodeLogic.check(nil, nil, now, {}, {})
		t.eq({ ok, reason, counts }, { false, "Invalid", true })

		ok, reason, counts = CodeLogic.check("FAKESPOOKY", spooky, HALLOWEEN_START - 1, {}, {})
		t.eq({ ok, reason, counts }, { false, "NotStarted", false })

		ok, reason = CodeLogic.check("FAKESPOOKY", spooky, HALLOWEEN_START, {}, {})
		t.eq({ ok, reason }, { true, "Ok" }, "startsAt 그 순간부터 돼요")

		ok, reason, counts = CodeLogic.check("FAKE2026", fake, NEW_YEAR, {}, {})
		t.eq({ ok, reason, counts }, { false, "Expired", false })

		ok, reason, counts = CodeLogic.check("FAKE2026", fake, NEW_YEAR - 1, {}, {})
		t.eq({ ok, reason, counts }, { true, "Ok", false })

		ok, reason, counts = CodeLogic.check("FAKE2026", fake, now, { FAKE2026 = now - 50 }, {})
		t.eq({ ok, reason, counts }, { false, "AlreadyRedeemed", false })

		-- 만료가 이미 받음보다 먼저
		ok, reason = CodeLogic.check("FAKE2026", fake, NEW_YEAR, { FAKE2026 = now }, {})
		t.eq(reason, "Expired")

		-- entry가 다른 코드면 Unknown (잘못 찾은 경우 방어)
		ok, reason = CodeLogic.check("FAKE2026", spooky, now, {}, {})
		t.eq({ ok, reason }, { false, "Unknown" })
	end)

	t.test("AC2·AC3: 잠금이 다른 판단보다 먼저, 실패로 세지 않음", function()
		local codes = CodeLogic.validateConfig(fakeCodes())
		local now = 1000
		local failures = {}
		for i = 1, 8 do
			table.insert(failures, now - i)
		end
		local ok, reason, counts = CodeLogic.check("FAKE2026", codes[1], now, {}, failures)
		t.eq({ ok, reason, counts }, { false, "Locked", false })
		ok, reason = CodeLogic.check(nil, nil, now, {}, failures)
		t.eq(reason, "Locked")
		-- 실패 시각은 failNow로 따로 (코드 기간은 now)
		ok, reason = CodeLogic.check("FAKE2026", codes[1], NEW_YEAR - 10, {}, failures, now + 600)
		t.eq({ ok, reason }, { true, "Ok" })
	end)

	t.test("AC3: recordFailure·isLocked — 600초 창, 8번", function()
		local window, max = 600, 8
		local list: { number } = {}
		for i = 1, 7 do
			t.eq(CodeLogic.recordFailure(list, 1000 + i, window), i)
			t.eq(CodeLogic.isLocked(list, 1000 + i, window, max), false)
		end
		t.eq(CodeLogic.recordFailure(list, 1008, window), 8)
		t.ok(CodeLogic.isLocked(list, 1008, window, max))
		-- 첫 실패(1001)에서 600초 뒤면 창 밖
		t.ok(CodeLogic.isLocked(list, 1600, window, max), "1600 - 1001 = 599 < 600")
		t.eq(CodeLogic.isLocked(list, 1601, window, max), false)
		-- 601초 지난 실패는 세지 않고 지워져요
		local old: { number } = { 0, 0, 0, 0, 0, 0, 0 }
		t.eq(CodeLogic.recordFailure(old, 601, window), 1)
		t.eq(#old, 1)
		t.eq(CodeLogic.isLocked({ 0, 0, 0, 0, 0, 0, 0, 0 }, 601, window, max), false)
	end)

	t.test("AC3: countsAsFailure는 Invalid·Unknown만", function()
		local codes = CodeLogic.validateConfig(fakeCodes())
		local cases: { { any } } = {
			{ nil, nil, 1000, {}, true },
			{ "NOPE", nil, 1000, {}, true },
			{ "FAKESPOOKY", codes[2], HALLOWEEN_START - 1, {}, false },
			{ "FAKE2026", codes[1], NEW_YEAR, {}, false },
			{ "FAKE2026", codes[1], 1000, { FAKE2026 = 1 }, false },
			{ "FAKE2026", codes[1], 1000, {}, false },
		}
		for i, case in cases do
			local _, _, counts = CodeLogic.check(case[1], case[2], case[3], case[4], {})
			t.eq(counts, case[5], `case {i}`)
		end
	end)

	t.test("AC4: rewardFor — 이벤트 진행 중이면 재화도", function()
		local codes = CodeLogic.validateConfig(fakeCodes())
		local spooky = codes[2]
		t.eq(CodeLogic.rewardFor(spooky, HALLOWEEN_START), { coins = 100, tokens = 10, eventId = "halloween-2026" })
		t.eq(CodeLogic.rewardFor(spooky, HALLOWEEN_START - 1), { coins = 100 })
		t.eq(CodeLogic.rewardFor(spooky, HALLOWEEN_END), { coins = 100 })
		t.eq(CodeLogic.rewardFor(codes[1], HALLOWEEN_START), { coins = 200 })
		-- isActive를 바꿔 넣을 수 있어요
		t.eq(
			CodeLogic.rewardFor(spooky, 0, function()
				return true
			end),
			{ coins = 100, tokens = 10, eventId = "halloween-2026" }
		)
	end)

	t.test("AC5: validateConfig — 가짜 기본 목록은 통과", function()
		local valid, problems = CodeLogic.validateConfig(fakeCodes())
		t.eq(#problems, 0, table.concat(problems, "; "))
		t.eq(#valid, 2)
		t.eq(valid[1].code, "FAKE2026")
		t.eq(valid[2].eventId, "halloween-2026")
		-- 빈 목록 (CodeList.luau 없음)
		local none, noProblems = CodeLogic.validateConfig({})
		t.eq(#none, 0)
		t.eq(#noProblems, 0)
	end)

	t.test("AC5: validateConfig — 문제를 각각 잡아요", function()
		local base = { code = "GOOD123", coins = 100 }
		local function with(overrides: { [string]: any }): any
			local entry = table.clone(base) :: any
			for key, value in overrides do
				entry[key] = value
			end
			return entry
		end
		t.eq(#problemsOf(base), 0)
		t.eq(#problemsOf(with({ code = "good123" })), 1, "소문자")
		t.eq(#problemsOf(with({ code = "GOOD 123" })), 1, "공백")
		t.eq(#problemsOf(with({ code = "AB" })), 1, "짧음")
		t.eq(#problemsOf(with({ code = string.rep("A", 21) })), 1, "김")
		t.eq(#problemsOf(with({ code = 123 })), 1, "문자열 아님")
		t.eq(#problemsOf(with({ coins = 301 })), 1, "301")
		t.eq(#problemsOf(with({ coins = 300 })), 0, "300은 돼요")
		t.eq(#problemsOf(with({ coins = 0, tokens = 5, eventId = "halloween-2026" })), 0, "0 + 재화")
		t.eq(#problemsOf(with({ coins = -1 })), 1, "음수")
		t.eq(#problemsOf(with({ coins = 10.5 })), 1, "소수")
		t.eq(#problemsOf(with({ coins = "100" })), 1, "문자열 coins")
		t.eq(#problemsOf(with({ coins = 0 / 0 })), 1, "NaN")
		t.eq(#problemsOf(with({ tokens = 10 })), 1, "tokens인데 eventId 없음")
		t.eq(#problemsOf(with({ tokens = 31, eventId = "halloween-2026" })), 1, "tokens 31")
		t.eq(#problemsOf(with({ tokens = 0, eventId = "halloween-2026" })), 1, "tokens 0")
		t.eq(#problemsOf(with({ tokens = 10, eventId = "easter-2027" })), 1, "모르는 eventId")
		t.eq(#problemsOf(with({ startsAt = 100, expiresAt = 100 })), 1, "startsAt == expiresAt")
		t.eq(#problemsOf(with({ startsAt = 200, expiresAt = 100 })), 1, "startsAt > expiresAt")
		t.eq(#problemsOf(with({ startsAt = 100, expiresAt = 200 })), 0)
		t.eq(#problemsOf(with({ expiresAt = "soon" })), 1, "숫자 아닌 시각")
		t.eq(#problemsOf("GOOD123"), 1, "표 아님")
	end)

	t.test(
		"AC5: validateConfig — 중복(대소문자 무시)은 처음 것만, 나쁜 코드만 빠져요",
		function()
			local valid, problems = CodeLogic.validateConfig({
				{ code = "DUP123", coins = 100 },
				{ code = "dup123", coins = 200 },
				{ code = "DUP123", coins = 300 },
				{ code = "OTHER1", coins = 999 },
				{ code = "OTHER2", coins = 50 },
			})
			t.eq(#valid, 2)
			t.eq(valid[1].code, "DUP123")
			t.eq(valid[1].coins, 100)
			t.eq(valid[2].code, "OTHER2")
			t.eq(#problems, 3)
			local joined = table.concat(problems, "\n")
			t.ok(string.find(joined, "duplicate", 1, true) ~= nil)
		end
	)

	t.test("AC6: message — Reason마다 문구", function()
		t.eq(LocTest.ko(CodeLogic.message("Cooldown")), "잠시 뒤에 다시 해 주세요")
		t.eq(LocTest.ko(CodeLogic.message("Locked")), "잠시 뒤에 다시 해 주세요")
		t.eq(LocTest.ko(CodeLogic.message("Invalid")), "없는 코드예요")
		t.eq(LocTest.ko(CodeLogic.message("Unknown")), "없는 코드예요")
		t.eq(LocTest.ko(CodeLogic.message("NotStarted")), "아직 쓸 수 없는 코드예요")
		t.eq(LocTest.ko(CodeLogic.message("Expired")), "기간이 끝난 코드예요")
		t.eq(LocTest.ko(CodeLogic.message("AlreadyRedeemed")), "이미 받은 코드예요")
		t.eq(LocTest.ko(CodeLogic.message("NoProfile")), "프로필을 불러오는 중이에요")
		t.eq(LocTest.ko(CodeLogic.message("NotSaved")), "저장이 안 되는 상태라 지금은 쓸 수 없어요")
		t.eq(LocTest.ko(CodeLogic.message("Error")), "다시 해 주세요")
		t.eq(LocTest.ko(CodeLogic.message("Weird" :: any)), "다시 해 주세요")
	end)

	t.test("AC6: successMessage", function()
		t.eq(LocTest.ko(CodeLogic.successMessage({ coins = 200 })), "🍚 200 받았어요!")
		t.eq(
			LocTest.ko(CodeLogic.successMessage({ coins = 100, tokens = 10, eventId = "halloween-2026" })),
			"🍚 100 + 🍬 10 받았어요!"
		)
		t.eq(
			LocTest.ko(CodeLogic.successMessage({ coins = 50, tokens = 5, eventId = "christmas-2026" })),
			"🍚 50 + ⭐ 5 받았어요!"
		)
		t.eq(
			LocTest.ko(CodeLogic.successMessage({ coins = 0, tokens = 5, eventId = "halloween-2026" })),
			"🍬 5 받았어요!"
		)
	end)
end
