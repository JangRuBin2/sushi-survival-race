--!strict
-- Shared.UiLayout: 화면 크기 배율, compact 판정, 터치 버튼 배치 (m4-09)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local Config = RobloxRequire.require(Shared.Config)

local EPS = 1e-9
-- iPhone SE·iPhone 14 Pro Max(가로, 포인트), iPad, iPad Pro 12.9 (픽셀)
local SCREENS = { { 667, 375 }, { 896, 414 }, { 1024, 768 }, { 2732, 2048 } }
local MORE_SCREENS = { { 568, 320 }, { 844, 390 }, { 932, 430 }, { 1366, 768 }, { 1920, 1080 }, { 1194, 834 } }

return function(t: Test.Test)
	t.test("AC1 배율: 짧은 변 720 기준, 0.6~1.25", function()
		t.eq(UiLayout.scaleFor(1920, 1080), 1.25)
		t.eq(UiLayout.scaleFor(1280, 720), 1)
		t.ok(math.abs(UiLayout.scaleFor(667, 375) - 0.6) < EPS, "667x375 → 하한 0.6")
		t.ok(math.abs(UiLayout.scaleFor(1366, 768) - 768 / 720) < EPS)
		t.eq(UiLayout.scaleFor(375, 667), UiLayout.scaleFor(667, 375)) -- 짧은 변 기준
		t.eq(UiLayout.scaleFor(0, 0), 1) -- 화면 크기를 아직 모를 때
	end)

	t.test("AC1 compact: 짧은 변 ≤ 500", function()
		t.eq(UiLayout.isCompact(667, 375), true)
		t.eq(UiLayout.isCompact(1280, 720), false)
		t.eq(UiLayout.isCompact(896, 414), true)
		t.eq(UiLayout.isCompact(1024, 768), false)
		t.eq(UiLayout.isCompact(900, 500), true)
		t.eq(UiLayout.isCompact(900, 501), false)
		local m = UiLayout.metrics(667, 375)
		t.eq(m.compact, true)
		t.ok(math.abs(m.scale - 0.6) < EPS)
		t.eq(UiLayout.metrics(0, 0).compact, false)
	end)

	t.test("터치 크기: 배율 적용 뒤 MinTouchSize 이상", function()
		for _, s in { { 667, 375 }, { 896, 414 }, { 1024, 768 }, { 1920, 1080 }, { 600, 560 } } do
			local m = UiLayout.metrics(s[1], s[2])
			local size = UiLayout.touchSize(44, m)
			t.ok(size * m.scale >= Config.Ui.MinTouchSize - EPS, `{s[1]}x{s[2]}: {size} × {m.scale}`)
			t.ok(size >= 44, "기본값보다 작아지지 않음")
		end
		t.eq(UiLayout.touchSize(48, UiLayout.metrics(1920, 1080)), 48) -- PC는 그대로
	end)

	t.test("글씨 크기: compact에서만 실제 14px 이상, PC는 그대로", function()
		local phone = UiLayout.metrics(667, 375)
		t.ok(UiLayout.textSize(14, phone) * phone.scale >= UiLayout.MIN_TEXT_PX - EPS)
		t.ok(UiLayout.textSize(16, phone) * phone.scale >= UiLayout.MIN_TEXT_PX - EPS)
		t.eq(UiLayout.textSize(30, phone), 30) -- 이미 큰 글씨는 그대로
		local pc = UiLayout.metrics(1920, 1080)
		t.eq(UiLayout.textSize(14, pc), 14)
		t.eq(UiLayout.textSize(16, UiLayout.metrics(1280, 720)), 16)
		t.ok(UiLayout.lineHeight(20, phone, 16) >= UiLayout.textSize(16, phone))
		local bar = UiLayout.scrollBarThickness(phone)
		t.ok(bar >= 8 and bar * phone.scale >= 8 - EPS, "스크롤바 두께 8 이상")
	end)

	t.test("인원 버튼 5개: 폭이 모자라면 두 줄", function()
		local perRow, rows = UiLayout.gridRows(5, 428, 74, 6)
		t.eq(perRow, 5)
		t.eq(rows, 1)
		perRow, rows = UiLayout.gridRows(5, 300, 74, 6)
		t.eq(perRow, 3)
		t.eq(rows, 2)
		perRow, rows = UiLayout.gridRows(5, 10, 74, 6)
		t.eq(perRow, 1)
		t.eq(rows, 5)
		t.eq(select(2, UiLayout.gridRows(0, 100, 10, 2)), 0)
	end)

	t.test("기본 점프 버튼: 짧은 변 ≤ 500이면 70 (95, 90), 그 밖 120 (180, 210)", function()
		t.eq(UiLayout.defaultJump(667, 375), { x = 667 - 95, y = 375 - 90, size = 70 })
		t.eq(UiLayout.defaultJump(1024, 768), { x = 1024 - 180, y = 768 - 210, size = 120 })
	end)

	t.test(
		"AC2 터치 버튼 3개: 화면 안, 서로 8px 이상, 다이브는 점프 왼쪽·잡기는 점프 위쪽",
		function()
			local all = table.clone(SCREENS)
			for _, s in MORE_SCREENS do
				table.insert(all, s)
			end
			for _, s in all do
				local w, h = s[1], s[2]
				local b = UiLayout.touchButtons(w, h)
				local label = `{w}x{h}`
				for name, r in b do
					t.ok(UiLayout.inside(r, w, h), `{label}: {name} 화면 안`)
				end
				t.ok(UiLayout.gapBetween(b.jump, b.dive) >= 8, `{label}: 점프-다이브 간격`)
				t.ok(UiLayout.gapBetween(b.jump, b.grab) >= 8, `{label}: 점프-잡기 간격`)
				t.ok(UiLayout.gapBetween(b.dive, b.grab) >= 8, `{label}: 다이브-잡기 간격`)
				t.ok(b.dive.x + b.dive.size <= b.jump.x - 8, `{label}: 다이브는 점프 왼쪽`)
				t.ok(b.grab.y + b.grab.size <= b.jump.y - 8, `{label}: 잡기는 점프 위쪽`)
				-- 같은 줄·같은 세로줄 (가운데 맞춤)
				t.ok(math.abs((b.dive.y + b.dive.size / 2) - (b.jump.y + b.jump.size / 2)) < 1e-6)
				t.ok(math.abs((b.grab.x + b.grab.size / 2) - (b.jump.x + b.jump.size / 2)) < 1e-6)
				t.eq(b.dive.size, math.floor(b.jump.size * 0.85 + 0.5))
				t.eq(b.grab.size, b.dive.size)
				-- 오른쪽 아래에 모여 있어요 (조이스틱은 왼쪽 아래)
				t.ok(b.dive.x > w / 2, `{label}: 오른쪽 절반`)
				t.ok(b.grab.y > h / 3, `{label}: 아래쪽`)
			end
		end
	)

	t.test("터치 버튼: 실제 점프 버튼 위치를 주면 그 기준", function()
		local b = UiLayout.touchButtons(800, 400, { x = 600, y = 250, size = 80 })
		t.eq(b.jump, { x = 600, y = 250, size = 80 })
		t.eq(b.dive.size, 68)
		t.eq(b.dive.x, 600 - 12 - 68)
		t.eq(b.grab.y, 250 - 12 - 68)
	end)

	t.test("compact 관전 ◀ ▶: 아래쪽 양 끝, 터치 버튼과 겹치지 않음", function()
		for _, s in { { 667, 375 }, { 568, 320 }, { 844, 390 }, { 896, 414 }, { 932, 430 } } do
			local w, h = s[1], s[2]
			local a = UiLayout.spectateArrows(w, h)
			local b = UiLayout.touchButtons(w, h)
			local label = `{w}x{h}`
			t.ok(UiLayout.inside(a.left, w, h) and UiLayout.inside(a.right, w, h), `{label}: 화면 안`)
			t.ok(a.left.x < w / 4 and a.right.x > w * 3 / 4, `{label}: 양 끝`)
			t.ok(a.left.y > h / 4, `{label}: 아래쪽`)
			for name, r in b do
				t.ok(UiLayout.gapBetween(a.right, r) >= 8, `{label}: ▶와 {name}`)
				t.ok(UiLayout.gapBetween(a.left, r) >= 8, `{label}: ◀와 {name}`)
			end
			t.ok(a.left.size * 1 >= Config.Ui.MinTouchSize, `{label}: 44px 이상`)
		end
	end)
end
