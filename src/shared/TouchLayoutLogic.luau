--!strict
-- 터치 버튼 배치 편집 (m5-41). Roblox API 없는 순수 계산이에요 (tests/touch-layout.spec.luau).
-- 좌표는 전부 "전체 화면 픽셀"(왼쪽 위 0,0, 위쪽 바·노치 포함)이고 버튼은 정사각형 UiLayout.Rect예요.
--   bucketFor(screen)                 "phone"(짧은 변 ≤ UiLayout.JUMP_SMALL_SHORT_SIDE) / "tablet"
--   toScreen(layout, screen)          저장된 배치(비율) → 화면 픽셀 버튼 셋
--   fromScreen(buttons, screen, preset?) → 배치(비율, 반올림 안 함). 저장 전에 quantize
--   quantize(layout)                  소수 셋째 자리로 반올림한 새 표
--   clamp(buttons, screen, only?)     크기·위치 규칙에 맞춘 새 버튼 셋 + 겹치면 { problem = "overlap", buttons }
--                                     (only = 끄는 중인 버튼 이름: 그 버튼만 맞추고 겹침은 자동으로 밀지 않아요)
--   fit(buttons, screen)              불러온 배치 맞추기: clamp → 크기 줄이기 → 그래도 안 되면 기본 ("default")
--   resolve(layout?, screen)          저장값 → 쓸 버튼 셋 (nil = 기본 배치, 지금과 같은 경로)
--   preset(name, screen)              "default"(UiLayout.touchButtons와 같음) / "large" / "compact"
--   sanitizeLayout(value) / sanitizeChange(value)   서버 검증 (키·범위·NaN·길이, 틀리면 nil)
--   editLocked(state)                 라운드에 배치된 동안 편집 잠금
--   editorPanel(screen, m)            편집 화면 도구 칸 크기 (UIScale 안 좌표, 실제 44px 이상)

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local UiLayout = require(script.Parent.UiLayout)

export type Rect = UiLayout.Rect
export type TouchButtons = UiLayout.TouchButtons
export type Insets = { left: number, top: number, right: number, bottom: number }
-- width·height = 전체 화면, safe = 노치 등 기기 안전 영역 여백, topBar = Roblox 위쪽 바 높이 (없으면 safe.top)
export type Screen = { width: number, height: number, safe: Insets, topBar: number? }
export type Problem = { problem: string, buttons: { [string]: boolean } }
export type Bounds = { left: number, top: number, right: number, bottom: number }
export type LockState = { inMatch: boolean, phase: string?, alive: boolean, passed: boolean }
export type Panel = {
	x: number, -- 실제 픽셀 (전체 화면 좌표)
	y: number,
	width: number, -- UIScale 안 좌표
	rowHeight: number, -- UIScale 안 좌표, 실제 Config.Ui.MinTouchSize 이상
	gap: number,
	textSize: number,
	scale: number,
}

local TouchLayoutLogic = {}

TouchLayoutLogic.VERSION = 1
TouchLayoutLogic.NAMES = { "jump", "dive", "grab" }
TouchLayoutLogic.PRESETS = { "default", "large", "compact" } -- 편집 화면 프리셋 단추 (custom은 손으로 바꾼 배치)
TouchLayoutLogic.BUCKETS = { "phone", "tablet" }
-- 금지 구역·크기 (기본값, 사용 뒤 조정 — 스펙 D6)
TouchLayoutLogic.LEFT_FORBIDDEN = 0.4 -- 화면 폭의 왼쪽 이만큼은 Roblox 이동 조이스틱 자리
TouchLayoutLogic.TOP_FORBIDDEN = UiLayout.TOUCH_TOP_FORBIDDEN -- 화면 높이의 위쪽 이만큼(또는 위쪽 바 + 여백)은 메뉴·채팅·HUD 자리
TouchLayoutLogic.EDGE_MARGIN = 8 -- 안전 영역·위쪽 바에서 띄우는 여백
TouchLayoutLogic.MAX_SIZE_RATIO = 0.35 -- 버튼 크기 ≤ 짧은 변 × 이 값
TouchLayoutLogic.MIN_SIZE_FACTOR = 0.7 -- 기본 크기의 이 배 ~
TouchLayoutLogic.MAX_SIZE_FACTOR = 1.6 -- ~ 이 배
TouchLayoutLogic.SIZE_STEP = 0.1 -- 편집 화면 "작게 −"/"크게 +" 한 번 (기본 크기의 10%)
TouchLayoutLogic.LARGE_FACTOR = 1.25
-- 저장 검증 범위
TouchLayoutLogic.STORE_MIN_S = 0.04
TouchLayoutLogic.STORE_MAX_S = 0.4
TouchLayoutLogic.MAX_PRESET_LENGTH = 16
TouchLayoutLogic.DECIMALS = 1000 -- 소수 셋째 자리

local NAMES = TouchLayoutLogic.NAMES
local VALID_PRESET: { [string]: boolean } = { default = true, large = true, compact = true, custom = true }
local VALID_BUCKET: { [string]: boolean } = { phone = true, tablet = true }
local LAYOUT_KEYS: { [string]: boolean } = { v = true, preset = true, jump = true, dive = true, grab = true }
local SPOT_KEYS: { [string]: boolean } = { x = true, y = true, s = true }
local CHANGE_KEYS: { [string]: boolean } = { bucket = true, layout = true, reset = true }
local LOCKED_PHASES: { [string]: boolean } = { Starting = true, RoundIntro = true, RoundActive = true }

local function round(v: number): number
	return math.floor(v + 0.5)
end

local function shortSide(screen: Screen): number
	return math.min(screen.width, screen.height)
end

local function safeRect(screen: Screen): (number, number, number, number)
	local s = screen.safe
	local w = math.max(1, screen.width - s.left - s.right)
	local h = math.max(1, screen.height - s.top - s.bottom)
	return s.left, s.top, w, h
end

local function copyRect(r: Rect): Rect
	return { x = r.x, y = r.y, size = r.size }
end

local function copyButtons(b: TouchButtons): TouchButtons
	return { jump = copyRect(b.jump), dive = copyRect(b.dive), grab = copyRect(b.grab) }
end

function TouchLayoutLogic.screen(width: number, height: number, safe: Insets?, topBar: number?): Screen
	return {
		width = width,
		height = height,
		safe = safe or { left = 0, top = 0, right = 0, bottom = 0 },
		topBar = topBar,
	}
end

function TouchLayoutLogic.bucketFor(screen: Screen): Types.TouchLayoutBucket
	return if shortSide(screen) <= UiLayout.JUMP_SMALL_SHORT_SIDE then "phone" else "tablet"
end

-- 버튼이 놓일 수 있는 칸 (정수 픽셀)
function TouchLayoutLogic.bounds(screen: Screen): Bounds
	local margin = TouchLayoutLogic.EDGE_MARGIN
	local safe = screen.safe
	local topBar = screen.topBar or safe.top
	return {
		left = math.ceil(math.max(safe.left + margin, screen.width * TouchLayoutLogic.LEFT_FORBIDDEN)),
		top = math.ceil(math.max(topBar + margin, safe.top + margin, screen.height * TouchLayoutLogic.TOP_FORBIDDEN)),
		right = math.floor(screen.width - safe.right - margin),
		bottom = math.floor(screen.height - safe.bottom - margin),
	}
end

-- 버튼별 기본 크기 (기본 배치와 같아요)
function TouchLayoutLogic.baseSizes(screen: Screen): { [string]: number }
	local b = UiLayout.touchButtons(screen.width, screen.height)
	return { jump = b.jump.size, dive = b.dive.size, grab = b.grab.size }
end

-- 버튼 크기 범위 (실제 픽셀): 44px 이상, 짧은 변 × 0.35 이하, 기본 크기 0.7~1.6배
function TouchLayoutLogic.sizeRange(name: string, screen: Screen): (number, number)
	local base = TouchLayoutLogic.baseSizes(screen)[name]
	local lo = math.max(Config.Ui.MinTouchSize, math.ceil(base * TouchLayoutLogic.MIN_SIZE_FACTOR))
	local hi = math.min(
		math.floor(shortSide(screen) * TouchLayoutLogic.MAX_SIZE_RATIO),
		math.floor(base * TouchLayoutLogic.MAX_SIZE_FACTOR)
	)
	return lo, math.max(lo, hi)
end

-- 버튼 하나를 크기 → 위치 순으로 규칙에 맞춰요 (가운데 유지)
function TouchLayoutLogic.clampOne(rect: Rect, name: string, screen: Screen): Rect
	local b = TouchLayoutLogic.bounds(screen)
	local lo, hi = TouchLayoutLogic.sizeRange(name, screen)
	local size = math.clamp(round(rect.size), lo, hi)
	-- 칸보다 크면 칸에 맞춰 줄여요 (아주 작은 화면)
	size = math.max(1, math.min(size, b.right - b.left, b.bottom - b.top))
	local cx = rect.x + rect.size / 2
	local cy = rect.y + rect.size / 2
	local x = math.clamp(round(cx - size / 2), b.left, math.max(b.left, b.right - size))
	local y = math.clamp(round(cy - size / 2), b.top, math.max(b.top, b.bottom - size))
	return { x = x, y = y, size = size }
end

-- 서로 MIN_TOUCH_GAP보다 가까운(겹치는) 버튼 이름
function TouchLayoutLogic.overlaps(buttons: TouchButtons): { [string]: boolean }
	local hit: { [string]: boolean } = {}
	local list = buttons :: any
	for i = 1, #NAMES do
		for j = i + 1, #NAMES do
			local a, b = NAMES[i], NAMES[j]
			if UiLayout.gapBetween(list[a], list[b]) < UiLayout.MIN_TOUCH_GAP then
				hit[a] = true
				hit[b] = true
			end
		end
	end
	return hit
end

function TouchLayoutLogic.clamp(buttons: TouchButtons, screen: Screen, only: string?): (TouchButtons, Problem?)
	local out = copyButtons(buttons)
	local list = out :: any
	for _, name in NAMES do
		if only == nil or only == name then
			list[name] = TouchLayoutLogic.clampOne(list[name], name, screen)
		end
	end
	local hit = TouchLayoutLogic.overlaps(out)
	if next(hit) ~= nil then
		return out, { problem = "overlap", buttons = hit }
	end
	return out, nil
end

-- 규칙을 다 지키는가 (크기·칸·겹침)
function TouchLayoutLogic.isValid(buttons: TouchButtons, screen: Screen): boolean
	local b = TouchLayoutLogic.bounds(screen)
	local list = buttons :: any
	for _, name in NAMES do
		local r: Rect = list[name]
		local lo, hi = TouchLayoutLogic.sizeRange(name, screen)
		if r.size < lo or r.size > hi then
			return false
		end
		if r.x < b.left or r.y < b.top or r.x + r.size > b.right or r.y + r.size > b.bottom then
			return false
		end
	end
	return next(TouchLayoutLogic.overlaps(buttons)) == nil
end

function TouchLayoutLogic.toScreen(layout: Types.TouchLayout, screen: Screen): TouchButtons
	local sx, sy, sw, sh = safeRect(screen)
	local short = shortSide(screen)
	local function one(spot: Types.TouchButtonSpot): Rect
		local size = round(spot.s * short)
		local cx = sx + spot.x * sw
		local cy = sy + spot.y * sh
		return { x = round(cx - size / 2), y = round(cy - size / 2), size = size }
	end
	return { jump = one(layout.jump), dive = one(layout.dive), grab = one(layout.grab) }
end

function TouchLayoutLogic.fromScreen(
	buttons: TouchButtons,
	screen: Screen,
	preset: Types.TouchLayoutPreset?
): Types.TouchLayout
	local sx, sy, sw, sh = safeRect(screen)
	local short = math.max(1, shortSide(screen))
	local function one(r: Rect): Types.TouchButtonSpot
		return {
			x = math.clamp((r.x + r.size / 2 - sx) / sw, 0, 1),
			y = math.clamp((r.y + r.size / 2 - sy) / sh, 0, 1),
			s = math.clamp(r.size / short, TouchLayoutLogic.STORE_MIN_S, TouchLayoutLogic.STORE_MAX_S),
		}
	end
	return {
		v = TouchLayoutLogic.VERSION,
		preset = preset or "custom",
		jump = one(buttons.jump),
		dive = one(buttons.dive),
		grab = one(buttons.grab),
	}
end

local function q(v: number): number
	local d = TouchLayoutLogic.DECIMALS
	return math.floor(v * d + 0.5) / d
end

function TouchLayoutLogic.quantize(layout: Types.TouchLayout): Types.TouchLayout
	local function one(spot: Types.TouchButtonSpot): Types.TouchButtonSpot
		return { x = q(spot.x), y = q(spot.y), s = q(spot.s) }
	end
	return {
		v = layout.v,
		preset = layout.preset,
		jump = one(layout.jump),
		dive = one(layout.dive),
		grab = one(layout.grab),
	}
end

-- 버튼 셋을 가운데 기준으로 factor배 (크기만, 위치는 각자 가운데 유지)
local function resizeEach(buttons: TouchButtons, factor: number): TouchButtons
	local out = copyButtons(buttons)
	for _, name in NAMES do
		local r: Rect = (out :: any)[name]
		local size = r.size * factor
		local cx, cy = r.x + r.size / 2, r.y + r.size / 2
		(out :: any)[name] = { x = cx - size / 2, y = cy - size / 2, size = size }
	end
	return out
end

-- 불러온 배치를 지금 화면에 맞춰요: 맞으면 "custom", 크기를 줄여도 안 되면 기본 배치 "default" (저장값은 그대로)
function TouchLayoutLogic.fit(buttons: TouchButtons, screen: Screen): (TouchButtons, "custom" | "default")
	local clamped, problem = TouchLayoutLogic.clamp(buttons, screen)
	if problem == nil then
		return clamped, "custom"
	end
	for step = 1, 6 do
		local tried, again = TouchLayoutLogic.clamp(resizeEach(clamped, 1 - TouchLayoutLogic.SIZE_STEP * step), screen)
		if again == nil then
			return tried, "custom"
		end
	end
	return TouchLayoutLogic.preset("default", screen), "default"
end

-- 저장값 → 이 화면에서 쓸 버튼 셋. nil이면 기본 배치(지금과 같은 경로: 점프 실제 위치 기준)
function TouchLayoutLogic.resolve(layout: Types.TouchLayout?, screen: Screen): TouchButtons?
	if layout == nil or layout.preset == "default" or screen.width <= 0 or screen.height <= 0 then
		return nil
	end
	local fitted, kind = TouchLayoutLogic.fit(TouchLayoutLogic.toScreen(layout, screen), screen)
	if kind == "default" then
		return nil
	end
	return fitted
end

-- 버튼 셋 전체를 칸 안으로 같이 옮겨요 (모양 유지)
local function shiftGroupInto(buttons: TouchButtons, screen: Screen): TouchButtons
	local b = TouchLayoutLogic.bounds(screen)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, name in NAMES do
		local r: Rect = (buttons :: any)[name]
		minX = math.min(minX, r.x)
		minY = math.min(minY, r.y)
		maxX = math.max(maxX, r.x + r.size)
		maxY = math.max(maxY, r.y + r.size)
	end
	local dx = math.min(0, b.right - maxX) + math.max(0, b.left - minX)
	local dy = math.min(0, b.bottom - maxY) + math.max(0, b.top - minY)
	local out = copyButtons(buttons)
	for _, name in NAMES do
		local r: Rect = (out :: any)[name]
		r.x = round(r.x + dx)
		r.y = round(r.y + dy)
		r.size = round(r.size)
	end
	return out
end

function TouchLayoutLogic.preset(name: string, screen: Screen): TouchButtons
	local base = UiLayout.touchButtons(screen.width, screen.height)
	if name == "large" then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, n in NAMES do
			local r: Rect = (base :: any)[n]
			minX = math.min(minX, r.x)
			minY = math.min(minY, r.y)
			maxX = math.max(maxX, r.x + r.size)
			maxY = math.max(maxY, r.y + r.size)
		end
		local gx, gy = (minX + maxX) / 2, (minY + maxY) / 2
		local f = TouchLayoutLogic.LARGE_FACTOR
		local scaled = copyButtons(base)
		for _, n in NAMES do
			local r: Rect = (scaled :: any)[n]
			local cx = gx + (r.x + r.size / 2 - gx) * f
			local cy = gy + (r.y + r.size / 2 - gy) * f
			local size = r.size * f
			r.x, r.y, r.size = cx - size / 2, cy - size / 2, size
		end
		return (TouchLayoutLogic.clamp(shiftGroupInto(scaled, screen), screen))
	elseif name == "compact" then
		local b = TouchLayoutLogic.bounds(screen)
		local js, ds, gs = base.jump.size, base.dive.size, base.grab.size
		local gap = math.max(UiLayout.MIN_TOUCH_GAP, math.ceil(js * UiLayout.TOUCH_GAP_RATIO))
		local jump = { x = b.right - js, y = b.bottom - js, size = js }
		local dive = { x = jump.x - gap - ds, y = jump.y + round((js - ds) / 2), size = ds }
		-- 잡기: 점프 왼쪽 위 대각선 (다이브와 점프 사이 틈 위)
		local grab = { x = round(jump.x - gap / 2 - gs / 2), y = jump.y - gap - gs, size = gs }
		return (TouchLayoutLogic.clamp({ jump = jump, dive = dive, grab = grab }, screen))
	end
	return base
end

-- 편집 화면 "작게 −"/"크게 +": 기본 크기의 SIZE_STEP만큼 (가운데 유지, 그 버튼만 클램프)
function TouchLayoutLogic.resize(buttons: TouchButtons, name: string, direction: number, screen: Screen): TouchButtons
	local out = copyButtons(buttons)
	local r: Rect = (out :: any)[name]
	local step = TouchLayoutLogic.baseSizes(screen)[name] * TouchLayoutLogic.SIZE_STEP
	local size = r.size + step * (if direction < 0 then -1 else 1)
	local cx, cy = r.x + r.size / 2, r.y + r.size / 2
	(out :: any)[name] = TouchLayoutLogic.clampOne({ x = cx - size / 2, y = cy - size / 2, size = size }, name, screen)
	return out
end

-- 끌기: 잡은 버튼 왼쪽 위를 (x, y)로 옮기고 그 버튼만 클램프
function TouchLayoutLogic.move(buttons: TouchButtons, name: string, x: number, y: number, screen: Screen): TouchButtons
	local out = copyButtons(buttons)
	local r: Rect = (out :: any)[name];
	(out :: any)[name] = TouchLayoutLogic.clampOne({ x = x, y = y, size = r.size }, name, screen)
	return out
end

-- 서버 검증 ----------------------------------------------------------------

local function isFiniteNumber(v: unknown): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- 표의 키가 allowed 안에만 있고 max개 이하인가 (큰 표는 max+1번째에서 멈춰요)
local function onlyKeys(value: { [any]: any }, allowed: { [string]: boolean }, max: number): boolean
	local count = 0
	for key in value do
		count += 1
		if count > max or type(key) ~= "string" or not allowed[key] then
			return false
		end
	end
	return true
end

local function sanitizeSpot(value: unknown): Types.TouchButtonSpot?
	if type(value) ~= "table" or not onlyKeys(value :: any, SPOT_KEYS, 3) then
		return nil
	end
	local t = value :: any
	local x, y, s = t.x, t.y, t.s
	if not (isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(s)) then
		return nil
	end
	if x < 0 or x > 1 or y < 0 or y > 1 then
		return nil
	end
	if s < TouchLayoutLogic.STORE_MIN_S or s > TouchLayoutLogic.STORE_MAX_S then
		return nil
	end
	return { x = q(x), y = q(y), s = q(s) }
end

function TouchLayoutLogic.sanitizeLayout(value: unknown): Types.TouchLayout?
	if type(value) ~= "table" or not onlyKeys(value :: any, LAYOUT_KEYS, 5) then
		return nil
	end
	local t = value :: any
	if t.v ~= TouchLayoutLogic.VERSION then
		return nil
	end
	local preset = t.preset
	if type(preset) ~= "string" or #preset > TouchLayoutLogic.MAX_PRESET_LENGTH or not VALID_PRESET[preset] then
		return nil
	end
	local jump, dive, grab = sanitizeSpot(t.jump), sanitizeSpot(t.dive), sanitizeSpot(t.grab)
	if jump == nil or dive == nil or grab == nil then
		return nil
	end
	return { v = TouchLayoutLogic.VERSION, preset = preset :: any, jump = jump, dive = dive, grab = grab }
end

-- SaveSettings의 touchLayout 칸: { bucket, layout } 또는 { bucket, reset = true } (둘 다·둘 다 없음은 거절)
function TouchLayoutLogic.sanitizeChange(value: unknown): Types.TouchLayoutChange?
	if type(value) ~= "table" or not onlyKeys(value :: any, CHANGE_KEYS, 2) then
		return nil
	end
	local t = value :: any
	local bucket = t.bucket
	if type(bucket) ~= "string" or not VALID_BUCKET[bucket] then
		return nil
	end
	if t.reset ~= nil then
		if t.reset ~= true or t.layout ~= nil then
			return nil
		end
		return { bucket = bucket :: any, reset = true }
	end
	local layout = TouchLayoutLogic.sanitizeLayout(t.layout)
	if layout == nil then
		return nil
	end
	return { bucket = bucket :: any, layout = layout }
end

-- 저장된 touchLayout 칸 (프로필 불러오기): 맞는 묶음만 남겨요. 버린 게 있으면 두 번째 값 true
function TouchLayoutLogic.sanitizeStored(value: unknown): (Types.TouchLayoutSettings?, boolean)
	if value == nil then
		return nil, false
	end
	if type(value) ~= "table" then
		return nil, true
	end
	local t = value :: any
	local out: Types.TouchLayoutSettings = {}
	local dropped = not onlyKeys(t, VALID_BUCKET, 2)
	local any = false
	for _, bucket in TouchLayoutLogic.BUCKETS do
		local raw = t[bucket]
		if raw ~= nil then
			local layout = TouchLayoutLogic.sanitizeLayout(raw)
			if layout then
				(out :: any)[bucket] = layout
				any = true
			else
				dropped = true
			end
		end
	end
	return if any then out else nil, dropped
end

-- 편집 잠금: 내가 이번 판에서 레이서로 배치돼 있는 동안 (시작·소개·라운드 중, 통과·탈락 전)
function TouchLayoutLogic.editLocked(state: LockState): boolean
	return state.inMatch
		and state.alive
		and not state.passed
		and state.phase ~= nil
		and LOCKED_PHASES[state.phase] == true
end

-- 편집 화면 도구 칸: 왼쪽 조이스틱 자리(버튼이 못 오는 곳)에 2열 4줄. 실제 픽셀 = 값 × scale
TouchLayoutLogic.PANEL_ROWS = 4
TouchLayoutLogic.PANEL_INFO_TEXT = 14 -- 안내 줄 글씨 기본 크기
function TouchLayoutLogic.editorPanel(screen: Screen, m: UiLayout.Metrics): Panel
	local margin = TouchLayoutLogic.EDGE_MARGIN
	local scale = math.max(m.scale, 1e-3)
	local topBar = screen.topBar or screen.safe.top
	local x = screen.safe.left + margin
	local y = math.max(topBar, screen.safe.top) + margin
	local realWidth = math.max(120, screen.width * TouchLayoutLogic.LEFT_FORBIDDEN - x - margin)
	return {
		x = x,
		y = y,
		width = realWidth / scale,
		rowHeight = UiLayout.touchSize(44, m),
		gap = math.max(4, UiLayout.px(4, scale)),
		textSize = UiLayout.textSize(TouchLayoutLogic.PANEL_INFO_TEXT, m),
		scale = scale,
	}
end

-- 도구 칸 전체 높이 (실제 픽셀): 안내 줄 + 4줄 + 간격 5 + 위아래 여백
function TouchLayoutLogic.panelHeight(panel: Panel): number
	local info = panel.textSize + 6
	return (info + panel.rowHeight * TouchLayoutLogic.PANEL_ROWS + panel.gap * (TouchLayoutLogic.PANEL_ROWS + 2))
		* panel.scale
end

return TouchLayoutLogic
