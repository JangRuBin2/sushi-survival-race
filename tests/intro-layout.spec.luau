--!strict
-- Shared.IntroLayout: "출발!" 글씨가 HUD 위 배너(맵 이름·규칙)를 덮지 않는지 (사용자 수정 지시, m3-09)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.IntroLayout)

-- ScreenGui(IgnoreGuiInset 꺼짐) 높이: 휴대폰 가로(390·375에서 위쪽 바 36~58을 뺀 값 포함), 태블릿, PC
local HEIGHTS = { 300, 317, 332, 339, 354, 360, 375, 390, 414, 480, 536, 600, 720, 768, 900, 1080, 1440 }
local WIDTHS = { 568, 667, 844, 932, 1024, 1920 }
local EPS = 1e-9

return function(t: Test.Test)
	t.test("배너 아래 끝: AbsolutePosition + AbsoluteSize - ScreenGui 위치, 없으면 기본값 100", function()
		t.eq(Layout.bannerBottom(16, 84, 0), 100)
		t.eq(Layout.bannerBottom(52, 84, 36), 100) -- 다른 GUI 좌표계에서 읽어도 같은 값
		t.eq(Layout.bannerBottom(16, 120), 136) -- 규칙이 길어 배너가 커져도 따라가요
		t.eq(Layout.bannerBottom(nil, nil), Layout.DEFAULT_BANNER_BOTTOM)
		t.eq(Layout.bannerBottom(16, 0, 0), Layout.DEFAULT_BANNER_BOTTOM)
		t.eq(Layout.DEFAULT_BANNER_BOTTOM, 100) -- HudScreen 위 배너 y 16 + 84
	end)

	t.test("모든 화면에서 가장 커진 글씨도 배너 아래 (여백 GAP)", function()
		for _, w in WIDTHS do
			for _, h in HEIGHTS do
				for _, bottom in { 100, 136 } do
					local placed = Layout.compute(w, h, bottom)
					t.ok(
						Layout.textTop(placed, Layout.MAX_SCALE) >= bottom + Layout.GAP - EPS,
						`겹침 {w}x{h} b={bottom}`
					)
				end
			end
		end
	end)

	t.test("최소 크기를 지킬 수 있는 화면에서는 아래·옆으로 넘치지 않음", function()
		for _, w in WIDTHS do
			for _, h in HEIGHTS do
				local placed = Layout.compute(w, h, 100)
				t.ok(placed.textSize >= Layout.MIN_TEXT_SIZE and placed.textSize <= Layout.TEXT_SIZE, `크기 {w}x{h}`)
				t.ok(
					Layout.textBottom(placed, Layout.MAX_SCALE) <= h - Layout.BOTTOM_MARGIN + EPS,
					`아래 넘침 {w}x{h}`
				)
				t.ok(
					Layout.textWidth(placed, Layout.MAX_SCALE) <= w - Layout.SIDE_MARGIN * 2 + EPS,
					`옆 넘침 {w}x{h}`
				)
			end
		end
	end)

	t.test(
		"휴대폰 가로(높이 약 390, 위쪽 바 빼면 332~354): 배너 아래로 내려가고 읽을 만한 크기",
		function()
			for _, h in { 332, 354 } do
				local placed = Layout.compute(844, h, 100)
				t.ok(placed.centerY > Layout.PREFERRED_CENTER_SCALE * h, `40%보다 아래 H={h}`)
				t.ok(placed.textSize >= 80, `크기 H={h}`)
			end
			-- 예전 고정 배치(40%, 120px, 1.4배)는 이 화면에서 배너를 덮었어요
			local old = { centerY = 0.4 * 332, textSize = 120, boxWidth = 600, boxHeight = 160 }
			t.ok(Layout.textTop(old, Layout.MAX_SCALE) < 100, "예전 배치 재현")
		end
	)

	t.test("아주 낮은 화면은 글씨를 줄여요, 큰 화면은 예전 그대로 40%·120px", function()
		t.ok(Layout.compute(667, 250, 100).textSize < Layout.TEXT_SIZE, "250")
		for _, h in { 720, 900, 1080, 1440 } do
			local placed = Layout.compute(1920, h, 100)
			t.ok(math.abs(placed.centerY - 0.4 * h) < EPS, `위치 H={h}`)
			t.eq(placed.textSize, 120, `크기 H={h}`)
			t.eq(placed.boxWidth, 600)
			t.eq(placed.boxHeight, 160)
		end
	end)

	t.test("화면이 낮아질수록 글씨가 커지지 않음", function()
		local previous = math.huge
		for i = #HEIGHTS, 1, -1 do
			local size = Layout.compute(1024, HEIGHTS[i], 100).textSize
			t.ok(size <= previous, `단조 H={HEIGHTS[i]}`)
			previous = size
		end
	end)

	t.test("너무 작은 화면: 최소 크기, 배너는 그래도 피함", function()
		local placed = Layout.compute(400, 150, 100)
		t.eq(placed.textSize, Layout.MIN_TEXT_SIZE)
		t.ok(Layout.textTop(placed, Layout.MAX_SCALE) >= 100 + Layout.GAP - EPS)
		local missing = Layout.compute(1024, 768)
		t.ok(Layout.textTop(missing, Layout.MAX_SCALE) >= Layout.DEFAULT_BANNER_BOTTOM + Layout.GAP - EPS, "기본값")
	end)
end
