--!strict
-- m5-41 모바일 터치 버튼 위치·크기 편집: 배치 비율 변환, 클램프(금지 구역·크기·겹침), 프리셋, 저장 검증(부분 저장),
-- 병합·칸별 요청 간격, 프로필 불러오기, 관전 화살표, 편집 잠금, 편집 화면 크기, 리모트·소스 연결. (스펙 AC1~AC10)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local UiLayout = RobloxRequire.require(Shared.UiLayout)
local TouchLayoutLogic = RobloxRequire.require(Shared.TouchLayoutLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)

local NAMES = { "jump", "dive", "grab" }

local SIZES = { { 844, 390 }, { 667, 375 }, { 1024, 768 }, { 2400, 1080 } }

local function screen(w: number, h: number, safe: any?, topBar: number?): any
	return TouchLayoutLogic.screen(w, h, safe, topBar)
end

local function rect(x: number, y: number, size: number): any
	return { x = x, y = y, size = size }
end

local function centerOf(r: any): (number, number)
	return r.x + r.size / 2, r.y + r.size / 2
end

-- 규칙을 모두 지키는가 (스펙 2절)
local function checkRules(t: any, buttons: any, s: any, label: string)
	local b = TouchLayoutLogic.bounds(s)
	local short = math.min(s.width, s.height)
	for _, name in NAMES do
		local r = buttons[name]
		t.ok(UiLayout.inside(r, s.width, s.height), `{label} {name} inside`)
		t.ok(r.size >= Config.Ui.MinTouchSize, `{label} {name} >= 44 ({r.size})`)
		t.ok(r.size <= short * 0.35 + 1e-9, `{label} {name} <= 35% short side`)
		t.ok(r.x >= s.width * 0.4, `{label} {name} right of joystick zone`)
		t.ok(r.y >= b.top, `{label} {name} below top band`)
		t.ok(r.x + r.size <= s.width - s.safe.right - 8, `{label} {name} right margin`)
		t.ok(r.y + r.size <= s.height - s.safe.bottom - 8, `{label} {name} bottom margin`)
		t.ok(r.x >= s.safe.left + 8, `{label} {name} notch left`)
	end
	for i = 1, 3 do
		for j = i + 1, 3 do
			local gap = UiLayout.gapBetween(buttons[NAMES[i]], buttons[NAMES[j]])
			t.ok(gap >= UiLayout.MIN_TOUCH_GAP, `{label} gap {NAMES[i]}-{NAMES[j]} = {gap}`)
		end
	end
	t.ok(TouchLayoutLogic.isValid(buttons, s), `{label} isValid`)
end

local function goodLayout(): any
	return {
		v = 1,
		preset = "custom",
		jump = { x = 0.9, y = 0.8, s = 0.18 },
		dive = { x = 0.75, y = 0.82, s = 0.15 },
		grab = { x = 0.88, y = 0.5, s = 0.15 },
	}
end

return function(t: Test.Test)
	-- AC1 --------------------------------------------------------------------
	t.test("AC1: preset default = UiLayout.touchButtons(w, h), 화면 4종 픽셀까지", function()
		for _, size in SIZES do
			local w, h = size[1], size[2]
			local p = TouchLayoutLogic.preset("default", screen(w, h))
			local old = UiLayout.touchButtons(w, h)
			for _, name in NAMES do
				t.eq(p[name], old[name], `{w}x{h} {name}`)
			end
		end
	end)

	t.test("AC1: 기본 배치는 그 자체로 규칙을 지켜요 (편집 화면 시작 상태)", function()
		for _, size in SIZES do
			local s = screen(size[1], size[2])
			checkRules(t, TouchLayoutLogic.preset("default", s), s, `{size[1]}x{size[2]}`)
		end
	end)

	t.test("AC1: 묶음 phone/tablet = 짧은 변 500 기준", function()
		t.eq(TouchLayoutLogic.bucketFor(screen(844, 390)), "phone")
		t.eq(TouchLayoutLogic.bucketFor(screen(1000, 500)), "phone")
		t.eq(TouchLayoutLogic.bucketFor(screen(1000, 501)), "tablet")
		t.eq(TouchLayoutLogic.bucketFor(screen(1024, 768)), "tablet")
		t.eq(TouchLayoutLogic.bucketFor(screen(2400, 1080)), "tablet")
		t.eq(UiLayout.JUMP_SMALL_SHORT_SIDE, 500)
	end)

	t.test("AC1: 저장값 없음·preset default면 resolve = nil (지금과 같은 경로)", function()
		local s = screen(844, 390)
		t.eq(TouchLayoutLogic.resolve(nil, s), nil)
		local layout = goodLayout()
		layout.preset = "default"
		t.eq(TouchLayoutLogic.resolve(layout, s), nil)
		t.ok(TouchLayoutLogic.resolve(goodLayout(), s) ~= nil)
	end)

	-- AC2 --------------------------------------------------------------------
	t.test("AC2: toScreen(fromScreen(b)) 1px 안 (안전 영역 있음·없음, 화면 4종)", function()
		for _, size in SIZES do
			for _, safe in
				{ { left = 0, top = 0, right = 0, bottom = 0 }, { left = 44, top = 0, right = 30, bottom = 20 } }
			do
				local s = screen(size[1], size[2], safe, 58)
				for _, presetName in { "default", "large", "compact" } do
					local b = TouchLayoutLogic.preset(presetName, s)
					local back = TouchLayoutLogic.toScreen(TouchLayoutLogic.fromScreen(b, s), s)
					for _, name in NAMES do
						for _, key in { "x", "y", "size" } do
							t.ok(
								math.abs(back[name][key] - b[name][key]) <= 1,
								`{size[1]}x{size[2]} {presetName} {name}.{key} {b[name][key]} -> {back[name][key]}`
							)
						end
					end
				end
			end
		end
	end)

	t.test("AC2: 저장(소수 셋째 자리) 뒤에도 휴대폰에서 2px 안", function()
		for _, size in { { 844, 390 }, { 667, 375 }, { 932, 430 }, { 568, 320 } } do
			local s = screen(size[1], size[2])
			local b = TouchLayoutLogic.preset("compact", s)
			local stored = TouchLayoutLogic.quantize(TouchLayoutLogic.fromScreen(b, s))
			for _, name in NAMES do
				for _, key in { "x", "y", "s" } do
					local v = stored[name][key]
					t.eq(math.floor(v * 1000 + 0.5) / 1000, v, "3 decimals")
				end
			end
			local back = TouchLayoutLogic.toScreen(stored, s)
			for _, name in NAMES do
				for _, key in { "x", "y", "size" } do
					t.ok(math.abs(back[name][key] - b[name][key]) <= 2, `{size[1]} {name}.{key}`)
				end
			end
		end
	end)

	t.test(
		"AC2: 844×390에서 만든 배치를 932×430에 → 같은 비율 자리(±2px), 크기는 짧은 변 비율",
		function()
			local a = screen(844, 390)
			local b = screen(932, 430)
			local made = TouchLayoutLogic.move(TouchLayoutLogic.preset("default", a), "dive", 500, 250, a)
			local layout = TouchLayoutLogic.quantize(TouchLayoutLogic.fromScreen(made, a))
			local there = TouchLayoutLogic.toScreen(layout, b)
			for _, name in NAMES do
				local ax, ay = centerOf(made[name])
				local bx, by = centerOf(there[name])
				t.ok(math.abs(ax / 844 * 932 - bx) <= 2, `{name} x ratio {ax} -> {bx}`)
				t.ok(math.abs(ay / 390 * 430 - by) <= 2, `{name} y ratio {ay} -> {by}`)
				t.ok(math.abs(made[name].size / 390 * 430 - there[name].size) <= 1, `{name} size by short side`)
			end
			-- 다른 휴대폰에서도 규칙을 지켜서 그대로 쓰여요
			local resolved = TouchLayoutLogic.resolve(layout, b)
			t.ok(resolved ~= nil, "resolved")
			checkRules(t, resolved, b, "932x430")
		end
	)

	-- AC3 --------------------------------------------------------------------
	t.test("AC3: clamp 크기 — 20px → 44 이상, 짧은 변 × 0.5 → 0.35 이하, 기본 0.7~1.6배", function()
		local s = screen(844, 390)
		local base = TouchLayoutLogic.preset("default", s)
		local tiny = TouchLayoutLogic.clampOne(rect(700, 250, 20), "dive", s)
		t.ok(tiny.size >= 44, `tiny {tiny.size}`)
		t.ok(tiny.size >= math.ceil(base.dive.size * 0.7), "0.7 × base")
		local huge = TouchLayoutLogic.clampOne(rect(600, 150, 390 * 0.5), "jump", s)
		t.ok(huge.size <= math.floor(390 * 0.35), `huge {huge.size}`)
		t.ok(huge.size <= math.floor(base.jump.size * 1.6), "1.6 × base")
		-- 큰 화면에서 짧은 변 0.35가 1.6배보다 크면 1.6배가 상한
		local big = screen(2400, 1080)
		local lo, hi = TouchLayoutLogic.sizeRange("jump", big)
		t.eq(hi, math.floor(120 * 1.6))
		t.eq(lo, math.max(44, math.ceil(120 * 0.7)))
	end)

	t.test(
		"AC3: clamp 위치 — 화면 밖·왼쪽 40%·위쪽 띠·노치 → 안으로, 결과는 규칙을 지켜요",
		function()
			local cases: { { any } } = {
				{ screen(844, 390), rect(900, 500, 60), "off screen bottom-right" },
				{ screen(844, 390), rect(-50, -50, 60), "off screen top-left" },
				{ screen(844, 390), rect(100, 250, 60), "joystick zone" },
				{ screen(844, 390), rect(600, 10, 60), "top band" },
				{ screen(844, 390, { left = 44, top = 0, right = 0, bottom = 0 }), rect(0, 200, 60), "notch left 44" },
				{
					screen(844, 390, { left = 0, top = 0, right = 44, bottom = 21 }),
					rect(820, 360, 60),
					"notch right 44",
				},
				{ screen(844, 390, nil, 58), rect(600, 40, 60), "topbar 58" },
			}
			for _, case in cases do
				local s, r, label = case[1], case[2], case[3]
				-- 다른 두 버튼은 멀리 (겹침 없이) — 기본 배치에서 셋 중 하나만 옮겨요
				local b = TouchLayoutLogic.preset("default", s)
				b.grab = r
				local clamped, problem = TouchLayoutLogic.clamp(b, s, "grab")
				local g = clamped.grab
				t.ok(UiLayout.inside(g, s.width, s.height), `{label} inside`)
				t.ok(g.x >= s.width * 0.4, `{label} joystick`)
				t.ok(g.y >= math.max(s.height * 0.2, (s.topBar or 0) + 8), `{label} band`)
				t.ok(g.x >= s.safe.left + 8 and g.x + g.size <= s.width - s.safe.right - 8, `{label} notch`)
				t.ok(g.y + g.size <= s.height - s.safe.bottom - 8, `{label} bottom`)
				if problem == nil then
					checkRules(t, clamped, s, label)
				end
			end
		end
	)

	t.test("AC3: 아무렇게나 넣어도 clamp 결과는 늘 inside + (문제 없으면) 간격 8 이상", function()
		-- 고정 씨앗 LCG (lune에는 Roblox Random이 없어요)
		local seed = 41
		local function nextNumber(lo: number, hi: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return lo + (hi - lo) * seed / 2147483648
		end
		local rng = {
			NextNumber = function(_self: any, lo: number, hi: number): number
				return nextNumber(lo, hi)
			end,
			NextInteger = function(_self: any, lo: number, hi: number): number
				return math.min(hi, math.floor(nextNumber(lo, hi + 1)))
			end,
		}
		for _ = 1, 300 do
			local size = SIZES[rng:NextInteger(1, #SIZES)]
			local s = screen(size[1], size[2], {
				left = rng:NextInteger(0, 50),
				top = 0,
				right = rng:NextInteger(0, 50),
				bottom = rng:NextInteger(0, 25),
			}, rng:NextInteger(0, 60))
			local b: any = {}
			for _, name in NAMES do
				b[name] = rect(
					rng:NextNumber(-300, size[1] + 300),
					rng:NextNumber(-300, size[2] + 300),
					rng:NextNumber(5, 600)
				)
			end
			local clamped, problem = TouchLayoutLogic.clamp(b, s)
			for _, name in NAMES do
				t.ok(UiLayout.inside(clamped[name], s.width, s.height), "inside")
			end
			if problem == nil then
				checkRules(t, clamped, s, "random")
			else
				t.eq(problem.problem, "overlap")
			end
		end
	end)

	-- AC4 --------------------------------------------------------------------
	t.test("AC4: 겹치면 problem overlap (자동으로 밀지 않음), 겹침이 없어지면 nil", function()
		local s = screen(844, 390)
		local b = TouchLayoutLogic.preset("default", s)
		local moved = TouchLayoutLogic.move(b, "dive", b.jump.x + 5, b.jump.y, s)
		local clamped, problem = TouchLayoutLogic.clamp(moved, s, "dive")
		t.ok(problem ~= nil, "overlap")
		t.eq((problem :: any).problem, "overlap")
		t.eq((problem :: any).buttons.dive, true)
		t.eq((problem :: any).buttons.jump, true)
		-- 밀어내지 않았어요: 놓은 자리 그대로
		t.eq(clamped.dive, moved.dive)
		t.eq(clamped.jump, b.jump)
		-- 7px 간격은 겹침, 8px부터 괜찮아요
		local near = TouchLayoutLogic.move(b, "dive", b.jump.x - 7 - b.dive.size, b.dive.y, s)
		t.ok(select(2, TouchLayoutLogic.clamp(near, s)) ~= nil, "gap 7")
		local ok8 = TouchLayoutLogic.move(b, "dive", b.jump.x - 8 - b.dive.size, b.dive.y, s)
		t.eq(select(2, TouchLayoutLogic.clamp(ok8, s)), nil, "gap 8")
	end)

	t.test(
		"AC4: 작은 화면 568×320에 태블릿용 큰 배치 → 크기를 줄여 맞춤, 안 되면 default",
		function()
			local small = screen(568, 320)
			-- 가깝게 붙은 큰 버튼 (작은 화면에서는 겹침)
			local packed = {
				v = 1,
				preset = "custom",
				jump = { x = 0.9, y = 0.82, s = 0.3 },
				dive = { x = 0.74, y = 0.82, s = 0.3 },
				grab = { x = 0.9, y = 0.45, s = 0.3 },
			}
			local raw = TouchLayoutLogic.toScreen(packed, small)
			t.ok(select(2, TouchLayoutLogic.clamp(raw, small)) ~= nil, "raw overlaps")
			local fitted, kind = TouchLayoutLogic.fit(raw, small)
			t.eq(kind, "custom")
			checkRules(t, fitted, small, "fitted")
			t.ok(fitted.jump.size < TouchLayoutLogic.clampOne(raw.jump, "jump", small).size, "shrunk")
			-- 셋이 한 자리 → 어떻게 줄여도 겹침 → 기본
			local same = {
				v = 1,
				preset = "custom",
				jump = { x = 0.8, y = 0.8, s = 0.2 },
				dive = { x = 0.8, y = 0.8, s = 0.2 },
				grab = { x = 0.8, y = 0.8, s = 0.2 },
			}
			local fallback, kind2 = TouchLayoutLogic.fit(TouchLayoutLogic.toScreen(same, small), small)
			t.eq(kind2, "default")
			t.eq(fallback, TouchLayoutLogic.preset("default", small))
			t.eq(TouchLayoutLogic.resolve(same, small), nil, "resolve → 기본 경로")
		end
	)

	-- AC5 --------------------------------------------------------------------
	t.test(
		"AC5: preset large·compact는 화면 4종(+작은 화면·노치)에서 문제 없이 규칙을 지켜요",
		function()
			local list = table.clone(SIZES)
			table.insert(list, { 568, 320 })
			table.insert(list, { 932, 430 })
			for _, size in list do
				for _, safe in
					{ { left = 0, top = 0, right = 0, bottom = 0 }, { left = 0, top = 0, right = 44, bottom = 21 } }
				do
					local s = screen(size[1], size[2], safe, 58)
					for _, name in { "large", "compact" } do
						local p = TouchLayoutLogic.preset(name, s)
						local _, problem = TouchLayoutLogic.clamp(p, s)
						t.eq(problem, nil, `{name} {size[1]}x{size[2]}`)
						checkRules(t, p, s, `{name} {size[1]}x{size[2]}`)
					end
				end
			end
		end
	)

	t.test(
		"AC5: large는 기본보다 크고(×1.25 근처), compact는 기본 크기로 오른쪽 아래 모서리",
		function()
			for _, size in SIZES do
				local s = screen(size[1], size[2])
				local d = TouchLayoutLogic.preset("default", s)
				local l = TouchLayoutLogic.preset("large", s)
				local c = TouchLayoutLogic.preset("compact", s)
				local b = TouchLayoutLogic.bounds(s)
				for _, name in NAMES do
					t.ok(l[name].size > d[name].size, `large {name}`)
					t.ok(math.abs(l[name].size - d[name].size * 1.25) <= 1, `large ×1.25 {name}`)
					t.eq(c[name].size, d[name].size, `compact size {name}`)
				end
				t.eq(c.jump.x + c.jump.size, b.right, "jump at right edge")
				t.eq(c.jump.y + c.jump.size, b.bottom, "jump at bottom edge")
				t.ok(c.dive.x < c.jump.x, "dive left")
				t.ok(c.grab.y < c.jump.y and c.grab.x < c.jump.x, "grab up-left")
			end
		end
	)

	t.test("AC5: 크기 조절은 기본 크기 10%씩, 범위 안", function()
		local s = screen(844, 390)
		local b = TouchLayoutLogic.preset("default", s)
		local bigger = TouchLayoutLogic.resize(b, "dive", 1, s)
		t.eq(bigger.dive.size, math.floor(b.dive.size * 1.1 + 0.5))
		t.eq(bigger.jump, b.jump)
		local x = b
		for _ = 1, 20 do
			x = TouchLayoutLogic.resize(x, "dive", -1, s)
		end
		local lo, hi = TouchLayoutLogic.sizeRange("dive", s)
		t.eq(x.dive.size, lo)
		for _ = 1, 30 do
			x = TouchLayoutLogic.resize(x, "dive", 1, s)
		end
		t.eq(x.dive.size, hi)
		t.ok(lo >= 44)
	end)

	-- AC6 --------------------------------------------------------------------
	t.test("AC6: sanitizeSettings 통과 — muteLevel만, 배치만, reset, 둘 다", function()
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 2 }), { muteLevel = 2 })
		local good = goodLayout()
		t.eq(
			ProfileSchema.sanitizeSettings({ touchLayout = { bucket = "phone", layout = good } }),
			{ touchLayout = { bucket = "phone", layout = good } }
		)
		t.eq(
			ProfileSchema.sanitizeSettings({ touchLayout = { bucket = "tablet", reset = true } }),
			{ touchLayout = { bucket = "tablet", reset = true } }
		)
		t.eq(
			ProfileSchema.sanitizeSettings({ muteLevel = 3, touchLayout = { bucket = "phone", layout = good } }),
			{ muteLevel = 3, touchLayout = { bucket = "phone", layout = good } }
		)
		-- 맨 위의 모르는 칸은 예전처럼 읽지 않고 버려요 (m4-07 QA 고정)
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 2, coins = 999 }), { muteLevel = 2 })
	end)

	t.test("AC6: 통과한 숫자는 소수 셋째 자리, 원본 표를 그대로 쓰지 않아요", function()
		local layout = goodLayout()
		layout.jump = { x = 0.123456, y = 0.98765, s = 0.20049 }
		local patch = ProfileSchema.sanitizeSettings({ touchLayout = { bucket = "phone", layout = layout } }) :: any
		t.eq(patch.touchLayout.layout.jump, { x = 0.123, y = 0.988, s = 0.2 })
		t.ok(patch.touchLayout.layout ~= layout, "copied")
		t.ok(patch.touchLayout.layout.dive ~= layout.dive, "spot copied")
	end)

	t.test(
		"AC6: 거절 — 빈 표, pc, NaN·inf·음수·1 초과, s 0.9, 모르는 키, 긴 preset, 빠진 버튼, 큰 표, 혼합",
		function()
			local function with(edit: (any) -> ()): any
				local layout = goodLayout()
				edit(layout)
				return { touchLayout = { bucket = "phone", layout = layout } }
			end
			local huge: any = { bucket = "phone", layout = goodLayout() }
			for i = 1, 5000 do
				huge[`k{i}`] = i
			end
			local hugeSpot = goodLayout()
			for i = 1, 5000 do
				(hugeSpot.jump :: any)[i] = i
			end
			local bad: { any } = {
				{},
				{ touchLayout = {} },
				{ touchLayout = { bucket = "pc", layout = goodLayout() } },
				{ touchLayout = { bucket = 1, layout = goodLayout() } },
				{ touchLayout = { layout = goodLayout() } },
				{ touchLayout = { bucket = "phone" } },
				{ touchLayout = { bucket = "phone", reset = false } },
				{ touchLayout = { bucket = "phone", reset = "yes" } },
				{ touchLayout = { bucket = "phone", reset = true, layout = goodLayout() } },
				{ touchLayout = "phone" },
				with(function(l)
					l.jump.x = 0 / 0
				end),
				with(function(l)
					l.jump.y = math.huge
				end),
				with(function(l)
					l.dive.s = -math.huge
				end),
				with(function(l)
					l.dive.x = -0.01
				end),
				with(function(l)
					l.grab.y = 1.01
				end),
				with(function(l)
					l.grab.s = 0.9
				end),
				with(function(l)
					l.grab.s = 0.01
				end),
				with(function(l)
					l.jump.s = "0.2"
				end),
				with(function(l)
					l.extra = true
				end),
				with(function(l)
					l.jump.z = 0
				end),
				with(function(l)
					l.preset = string.rep("c", 17)
				end),
				with(function(l)
					l.preset = "huge"
				end),
				with(function(l)
					l.preset = 1
				end),
				with(function(l)
					l.v = 2
				end),
				with(function(l)
					l.v = nil
				end),
				with(function(l)
					l.grab = nil
				end),
				with(function(l)
					l.dive = "spot"
				end),
				{ touchLayout = huge },
				{ touchLayout = { bucket = "phone", layout = hugeSpot } },
				-- muteLevel 정상 + touchLayout 틀림 → 전체 무시
				{ muteLevel = 2, touchLayout = { bucket = "pc", layout = goodLayout() } },
				-- touchLayout 정상 + muteLevel 틀림 → 전체 무시
				{ muteLevel = 9, touchLayout = { bucket = "phone", layout = goodLayout() } },
			}
			for i, value in bad do
				t.eq(ProfileSchema.sanitizeSettings(value), nil, `case {i}`)
			end
		end
	)

	-- AC7 --------------------------------------------------------------------
	t.test(
		"AC7: 병합 — 음소거만은 배치를 안 지우고, 배치만은 음소거 그대로, reset은 그 묶음만",
		function()
			local settings: any = { muteLevel = 1 }
			local phone = goodLayout()
			local tablet = goodLayout()
			tablet.preset = "large"
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "phone", layout = phone } })
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "tablet", layout = tablet } })
			t.eq(settings.muteLevel, 1)
			t.eq(settings.touchLayout, { phone = phone, tablet = tablet })
			ProfileSchema.applySettings(settings, { muteLevel = 3 })
			t.eq(settings.muteLevel, 3)
			t.eq(settings.touchLayout, { phone = phone, tablet = tablet }, "mute keeps layouts")
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "phone", reset = true } })
			t.eq(settings.touchLayout, { tablet = tablet }, "reset phone only")
			ProfileSchema.applySettings(settings, { touchLayout = { bucket = "tablet", reset = true } })
			t.eq(settings.touchLayout, nil, "empty → nil")
			t.eq(settings.muteLevel, 3)
		end
	)

	t.test("AC7: 요청 간격은 칸마다 — 0.2초 안 같은 칸은 버리고 다른 칸은 받아요", function()
		local interval = Config.Data.SettingsMinInterval
		t.eq(interval, 0.5)
		local last = {}
		local layoutChange = { bucket = "phone", layout = goodLayout() }
		t.eq(ProfileSchema.acceptByInterval({ muteLevel = 2 }, last, 10, interval), { muteLevel = 2 })
		t.eq(ProfileSchema.acceptByInterval({ muteLevel = 3 }, last, 10.2, interval), nil, "same field too soon")
		t.eq(
			ProfileSchema.acceptByInterval({ touchLayout = layoutChange }, last, 10.2, interval),
			{ touchLayout = layoutChange },
			"other field ok"
		)
		-- 둘 다 오면 너무 빠른 칸만 빼요
		t.eq(
			ProfileSchema.acceptByInterval({ muteLevel = 1, touchLayout = layoutChange }, last, 10.6, interval),
			{ muteLevel = 1 }
		)
		t.eq(ProfileSchema.acceptByInterval({ touchLayout = layoutChange }, last, 10.75, interval), {
			touchLayout = layoutChange,
		})
	end)

	t.test("AC7: DataService가 칸별 간격·병합 함수를 써요 (소스)", function()
		local source = fs.readFile("src/server/DataService.luau")
		t.ok(string.find(source, "ProfileSchema.sanitizeSettings(value)", 1, true) ~= nil)
		t.ok(string.find(source, "ProfileSchema.acceptByInterval(", 1, true) ~= nil)
		t.ok(string.find(source, "ProfileSchema.applySettings(profile.settings, accepted)", 1, true) ~= nil)
		t.ok(string.find(source, "DataService.update(player", 1, true) ~= nil)
	end)

	-- AC8 --------------------------------------------------------------------
	t.test("AC8: 옛 프로필(muteLevel만)은 그대로, 버전 3", function()
		local profile, info = ProfileLogic.migrate({ version = 3, settings = { muteLevel = 2 } })
		t.eq(profile.version, 3)
		t.eq(ProfileSchema.VERSION, 3)
		t.eq(profile.settings, { muteLevel = 2 })
		t.eq(info.persistable, true)
	end)

	t.test("AC8: 망가진 touchLayout은 그것만 버리고(메모) 나머지·맞는 묶음은 지켜요", function()
		local good = goodLayout()
		local broken = goodLayout()
		broken.jump.x = 5
		local profile, info = ProfileLogic.migrate({
			version = 3,
			coins = 77,
			settings = { muteLevel = 3, touchLayout = { phone = good, tablet = broken } },
		})
		t.eq(profile.version, 3)
		t.eq(profile.coins, 77)
		t.eq(profile.settings.muteLevel, 3)
		t.eq(profile.settings.touchLayout, { phone = good })
		local noted = false
		for _, note in info.notes do
			if string.find(note, "touchLayout", 1, true) then
				noted = true
			end
		end
		t.ok(noted, "note")
		-- 표가 아님·모르는 묶음
		local p2 = ProfileLogic.migrate({ settings = { muteLevel = 2, touchLayout = "x" } })
		t.eq(p2.settings, { muteLevel = 2 })
		local p3 = ProfileLogic.migrate({ settings = { muteLevel = 2, touchLayout = { pc = good } } })
		t.eq(p3.settings, { muteLevel = 2 })
		-- muteLevel이 틀리면 예전처럼 설정 전체 기본
		local p4 = ProfileLogic.migrate({ settings = { muteLevel = 9, touchLayout = { phone = good } } })
		t.eq(p4.settings, { muteLevel = 1 })
	end)

	t.test("AC8: toView는 배치를 복사해 보내고, 없으면 예전 모양 { muteLevel }", function()
		local p = ProfileSchema.new()
		t.eq(ProfileSchema.toView(p, true).settings, { muteLevel = 1 })
		p.settings.touchLayout = { phone = goodLayout() }
		local view = ProfileSchema.toView(p, true)
		t.eq(view.settings.touchLayout, { phone = goodLayout() })
		t.ok(view.settings.touchLayout.phone ~= p.settings.touchLayout.phone, "copied")
	end)

	-- AC9 --------------------------------------------------------------------
	t.test("AC9: spectateArrows — 기본 배치에서 지금 결과와 같아요", function()
		for _, size in { { 844, 390 }, { 667, 375 }, { 568, 320 }, { 932, 430 } } do
			local w, h = size[1], size[2]
			local legacy = UiLayout.spectateArrows(w, h)
			t.eq(UiLayout.spectateArrows(w, h, UiLayout.touchButtons(w, h)), legacy, `{w}x{h}`)
			-- 예전 공식
			local grabY = UiLayout.touchButtons(w, h).grab.y
			t.eq(legacy.right.y, math.max(12, grabY - 12 - 52))
		end
	end)

	t.test("AC9: 버튼을 높이 올린 배치에서도 화살표가 버튼과 안 겹치고 화면 안", function()
		for _, size in { { 844, 390 }, { 667, 375 }, { 568, 320 }, { 1024, 768 } } do
			local s = screen(size[1], size[2])
			local b = TouchLayoutLogic.preset("default", s)
			local bounds = TouchLayoutLogic.bounds(s)
			-- 잡기를 맨 위 오른쪽 끝으로
			local high = TouchLayoutLogic.move(b, "grab", s.width, 0, s)
			t.eq(high.grab.y, bounds.top)
			for _, layout in { b, high, TouchLayoutLogic.preset("large", s), TouchLayoutLogic.preset("compact", s) } do
				local arrows = UiLayout.spectateArrows(s.width, s.height, layout)
				for _, arrow in { arrows.left, arrows.right } do
					t.ok(UiLayout.inside(arrow, s.width, s.height), `{size[1]} inside`)
					for _, name in NAMES do
						t.ok(UiLayout.gapBetween(arrow, layout[name]) >= 0, `{size[1]} arrow vs {name}`)
					end
				end
			end
		end
	end)

	-- 편집 잠금 · 편집 화면 ------------------------------------------------------
	t.test(
		"편집 잠금: 시작·소개·라운드 중 레이서만, 로비·통과·탈락·결과·우승 화면은 열림",
		function()
			local function locked(inMatch: boolean, phase: string?, alive: boolean, passed: boolean): boolean
				return TouchLayoutLogic.editLocked({ inMatch = inMatch, phase = phase, alive = alive, passed = passed })
			end
			t.eq(locked(false, nil, true, false), false, "lobby")
			t.eq(locked(true, nil, true, false), false, "room before phase")
			t.eq(locked(true, "Starting", true, false), true)
			t.eq(locked(true, "RoundIntro", true, false), true)
			t.eq(locked(true, "RoundActive", true, false), true)
			t.eq(locked(true, "RoundActive", true, true), false, "passed (bench)")
			t.eq(locked(true, "RoundActive", false, false), false, "eliminated (spectating)")
			t.eq(locked(true, "RoundResults", true, false), false)
			t.eq(locked(true, "Victory", true, false), false)
		end
	)

	t.test(
		"편집 화면 도구 칸: 왼쪽 조이스틱 자리 안, 버튼 실제 44px 이상, 높이가 화면에 들어가요",
		function()
			for _, size in { { 568, 320 }, { 667, 375 }, { 844, 390 }, { 1024, 768 }, { 2400, 1080 } } do
				local s = screen(size[1], size[2], nil, 58)
				local m = UiLayout.metrics(size[1], size[2])
				local panel = TouchLayoutLogic.editorPanel(s, m)
				t.ok(panel.rowHeight * m.scale >= Config.Ui.MinTouchSize - 1e-9, `{size[1]} row >= 44 real`)
				t.ok(panel.x + panel.width * m.scale <= size[1] * 0.4 + 1e-6, `{size[1]} panel in joystick zone`)
				t.ok(panel.y >= 58, `{size[1]} below topbar`)
				t.ok(panel.y + TouchLayoutLogic.panelHeight(panel) <= size[2], `{size[1]} fits height`)
				t.ok(panel.textSize * m.scale >= UiLayout.MIN_TEXT_PX - 1e-9 or not m.compact, `{size[1]} text`)
			end
		end
	)

	-- AC10 · 소스 연결 ----------------------------------------------------------
	t.test(
		"AC10: 리모트 수 그대로(RemoteFunction 16 + RemoteEvent 11), SaveSettings 설명이 새 모양",
		function()
			local src = fs.readFile("src/shared/Remotes.luau")
			local functions = string.match(src, "local FUNCTIONS = (%b{})") :: string
			local events = string.match(src, "local EVENTS = (%b{})") :: string
			local function count(block: string): number
				local n = 0
				for _ in string.gmatch(block, '"%w+"') do
					n += 1
				end
				return n
			end
			t.eq(count(functions), 16)
			t.eq(count(events), 11)
			t.ok(string.find(src, "SaveSettings(patch: SettingsPatch)", 1, true) ~= nil, "comment")
			t.ok(string.find(src, "touchLayout?", 1, true) ~= nil, "touchLayout in comment")
			local types = fs.readFile("src/shared/Types.luau")
			t.ok(string.find(types, "touchLayout: TouchLayoutSettings?", 1, true) ~= nil, "Types.Settings")
		end
	)

	t.test(
		"소스: 컨트롤러 등록, 다이브·잡기·관전이 배치를 따르고, 편집 중 숨김",
		function()
			local init = fs.readFile("src/client/init.client.luau")
			local touch = string.find(init, "input.TouchLayoutController", 1, true)
			local dive = string.find(init, "input.DiveController", 1, true)
			t.ok(touch ~= nil and dive ~= nil and touch < dive, "TouchLayoutController before DiveController")
			t.ok(string.find(init, "ui.SettingsButton", 1, true) ~= nil, "SettingsButton")
			for _, path in { "src/client/input/DiveButton.luau", "src/client/input/GrabButton.luau" } do
				local source = fs.readFile(path)
				t.ok(string.find(source, "TouchLayoutController.current()", 1, true) ~= nil, `{path} layout`)
				t.ok(string.find(source, "TouchLayoutController.isEditing()", 1, true) ~= nil, `{path} editing`)
				t.ok(string.find(source, "UiLayout.touchButtons", 1, true) ~= nil, `{path} default path kept`)
			end
			local spectate = fs.readFile("src/client/ui/SpectateScreen.luau")
			t.ok(
				string.find(
					spectate,
					"UiLayout.spectateArrows(m.width, m.height, TouchLayoutController.current())",
					1,
					true
				) ~= nil
			)
			local controller = fs.readFile("src/client/input/TouchLayoutController.luau")
			t.ok(string.find(controller, '"JumpButton"', 1, true) ~= nil)
			t.ok(string.find(controller, 'watch("Position"', 1, true) ~= nil, "reapply on Position")
			t.ok(string.find(controller, 'watch("Size"', 1, true) ~= nil, "reapply on Size")
			t.ok(string.find(controller, "GetPropertyChangedSignal(prop)", 1, true) ~= nil, "property signal")
			t.ok(string.find(controller, "queueJump()", 1, true) ~= nil, "deferred once per frame")
			t.ok(string.find(controller, "TouchLayoutLogic.editLocked", 1, true) ~= nil, "lock")
			local settings = fs.readFile("src/client/ui/SettingsButton.luau")
			t.ok(string.find(settings, "UserInputService.TouchEnabled", 1, true) ~= nil, "touch only")
			t.ok(string.find(settings, "TopbarSafeInsets", 1, true) ~= nil, "topbar")
			local editor = fs.readFile("src/client/ui/TouchLayoutEditor.luau")
			t.ok(string.find(editor, "TouchLayoutLogic.editorPanel", 1, true) ~= nil, "panel layout")
			t.ok(string.find(editor, "TouchLayoutLogic.move", 1, true) ~= nil, "drag clamp")
		end
	)
end
