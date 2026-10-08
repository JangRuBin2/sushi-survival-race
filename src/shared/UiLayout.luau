--!strict
-- 화면 크기 대응 (m4-09). Roblox API 없는 순수 계산이에요.
--   scaleFor(w, h)       ScreenGui UIScale 배율: 짧은 변 / Config.Ui.BaseShortSide, MinScale~MaxScale
--   isCompact(w, h)      짧은 변 ≤ Config.Ui.CompactShortSide (휴대폰 가로) → 화면들이 compact 배치를 써요
--   metrics(w, h)        위 둘을 한 번에 (UiScaleController가 화면들에 나눠 줘요)
--   px / touchSize / textSize   "배율 적용 뒤 실제 픽셀이 최소 몇"을 UIScale 안 좌표(가상 픽셀)로 바꿔요
--   gridRows             버튼 n개를 폭에 맞춰 몇 줄로 놓을지 (방 만들기 인원 버튼)
--   touchButtons(w, h)   점프·다이브·잡기 버튼 자리 (화면 픽셀, UIScale 없음)
--   spectateArrows(w, h) compact 관전 ◀ ▶ 자리 (화면 픽셀, 터치 버튼 위쪽)
-- UIScale이 붙은 ScreenGui 안에서 Offset 값 v는 실제로 v × scale 픽셀로 그려져요.

local Config = require(script.Parent.Config)

local UiLayout = {}

UiLayout.MIN_TEXT_PX = 14 -- compact에서 글씨 최소 크기 (실제 픽셀)
UiLayout.MIN_SCROLLBAR_PX = 8 -- 스크롤바 최소 두께 (실제 픽셀)
UiLayout.TOUCH_BUTTON_RATIO = 0.85 -- 다이브·잡기 버튼 크기 = 점프 버튼 × 이 값
UiLayout.TOUCH_GAP_RATIO = 0.15 -- 버튼 사이 간격 = 점프 버튼 × 이 값 (최소 MIN_TOUCH_GAP)
UiLayout.MIN_TOUCH_GAP = 8
UiLayout.ARROW_SIZE = 52 -- compact 관전 ◀ ▶ 크기 (실제 픽셀)
UiLayout.ARROW_MARGIN = 12

-- Roblox 기본 점프 버튼 (PlayerModule TouchJump): 짧은 변 ≤ 500이면 작은 버튼
UiLayout.JUMP_SMALL = { size = 70, right = 95, bottom = 90 }
UiLayout.JUMP_LARGE = { size = 120, right = 170, bottom = 210 } -- 1.5 × 120 - 10 (m4-09 QA B3)
UiLayout.JUMP_SMALL_SHORT_SIDE = 500

export type Metrics = {
	width: number,
	height: number,
	scale: number,
	compact: boolean,
}

export type Rect = { x: number, y: number, size: number }

export type TouchButtons = { jump: Rect, dive: Rect, grab: Rect }

export type Arrows = { left: Rect, right: Rect }

local function shortSide(width: number, height: number): number
	return math.min(width, height)
end

function UiLayout.scaleFor(width: number, height: number): number
	local ui = Config.Ui
	if width <= 0 or height <= 0 then
		return 1
	end
	return math.clamp(shortSide(width, height) / ui.BaseShortSide, ui.MinScale, ui.MaxScale)
end

function UiLayout.isCompact(width: number, height: number): boolean
	return shortSide(width, height) <= Config.Ui.CompactShortSide
end

function UiLayout.metrics(width: number, height: number): Metrics
	return {
		width = width,
		height = height,
		scale = UiLayout.scaleFor(width, height),
		compact = width > 0 and height > 0 and UiLayout.isCompact(width, height),
	}
end

-- 실제 픽셀 real을 UIScale 안 좌표로 (올림)
function UiLayout.px(real: number, scale: number): number
	return math.ceil(real / math.max(scale, 1e-3) - 1e-9)
end

-- 버튼 높이·크기: 기본값 base, 배율 적용 뒤 Config.Ui.MinTouchSize 이상
function UiLayout.touchSize(base: number, m: Metrics): number
	return math.max(base, UiLayout.px(Config.Ui.MinTouchSize, m.scale))
end

-- 글씨 크기: compact에서만 배율 적용 뒤 MIN_TEXT_PX 이상 (PC 큰 화면은 그대로)
function UiLayout.textSize(base: number, m: Metrics): number
	if not m.compact then
		return base
	end
	return math.max(base, UiLayout.px(UiLayout.MIN_TEXT_PX, m.scale))
end

-- 한 줄 높이: 글씨 크기에 맞춰 늘어나요 (기본 높이 base)
function UiLayout.lineHeight(base: number, m: Metrics, textBase: number): number
	return math.max(base, UiLayout.textSize(textBase, m) + 6)
end

function UiLayout.scrollBarThickness(m: Metrics): number
	return math.max(UiLayout.MIN_SCROLLBAR_PX, UiLayout.px(UiLayout.MIN_SCROLLBAR_PX, m.scale))
end

-- 폭 available에 최소 폭 minCell 버튼 count개를 gap 간격으로: (한 줄 개수, 줄 수)
function UiLayout.gridRows(count: number, available: number, minCell: number, gap: number): (number, number)
	if count <= 0 then
		return 0, 0
	end
	local perRow = math.floor((available + gap) / (minCell + gap))
	perRow = math.clamp(perRow, 1, count)
	return perRow, math.ceil(count / perRow)
end

-- 기본 점프 버튼 자리 (화면 픽셀, 왼쪽 위 기준)
function UiLayout.defaultJump(width: number, height: number): Rect
	local spec = if shortSide(width, height) <= UiLayout.JUMP_SMALL_SHORT_SIDE
		then UiLayout.JUMP_SMALL
		else UiLayout.JUMP_LARGE
	return { x = width - spec.right, y = height - spec.bottom, size = spec.size }
end

-- 점프 버튼(실제 위치를 알면 jump, 모르면 기본 위치) 기준 다이브(왼쪽)·잡기(위쪽).
-- 둘 다 점프의 85% 크기, 점프와 가운데 줄을 맞추고 간격은 점프 × 0.15(최소 8px).
function UiLayout.touchButtons(width: number, height: number, jump: Rect?): TouchButtons
	local j = jump or UiLayout.defaultJump(width, height)
	local size = math.floor(j.size * UiLayout.TOUCH_BUTTON_RATIO + 0.5)
	local gap = math.max(UiLayout.MIN_TOUCH_GAP, math.ceil(j.size * UiLayout.TOUCH_GAP_RATIO))
	local inset = (j.size - size) / 2
	local dive = { x = math.max(0, j.x - gap - size), y = j.y + inset, size = size }
	local grab = { x = j.x + inset, y = math.max(0, j.y - gap - size), size = size }
	return { jump = j, dive = dive, grab = grab }
end

-- compact 관전 ◀ ▶: 아래쪽 양 끝, 오른쪽 터치 버튼 묶음(잡기 버튼) 바로 위 높이 (화면 픽셀)
function UiLayout.spectateArrows(width: number, height: number): Arrows
	local buttons = UiLayout.touchButtons(width, height)
	local size = UiLayout.ARROW_SIZE
	local margin = UiLayout.ARROW_MARGIN
	local y = math.max(margin, buttons.grab.y - margin - size)
	return {
		left = { x = margin, y = y, size = size },
		right = { x = width - margin - size, y = y, size = size },
	}
end

-- 두 정사각형 사이 거리 (겹치면 음수)
function UiLayout.gapBetween(a: Rect, b: Rect): number
	local dx = math.max(b.x - (a.x + a.size), a.x - (b.x + b.size))
	local dy = math.max(b.y - (a.y + a.size), a.y - (b.y + b.size))
	return math.max(dx, dy)
end

function UiLayout.inside(r: Rect, width: number, height: number): boolean
	return r.x >= 0 and r.y >= 0 and r.x + r.size <= width and r.y + r.size <= height
end

return UiLayout
