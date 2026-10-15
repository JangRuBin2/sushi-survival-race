--!strict
-- 게임패드(콘솔) UI 내비게이션의 순수 판단 (m5-12). Roblox API 없이 테스트해요 (tests/gamepad-nav.spec.luau).
--   isGamepadInput(name)              UserInputType 이름이 "Gamepad1"~"Gamepad8"인가
--   modeFor(current, name, typing)    마지막 입력으로 게임패드 모드를 정해요 (창 포커스·글자 입력 중은 그대로)
--   insetsFor(tenFoot, w, h)          10피트(TV) 화면이면 각 변 5% 안전 여백, 아니면 0
--   nextTab(tabs, current, dir)       LB(-1)/RB(+1)로 다음 탭 id. 끝에서 멈춰요(돌아가지 않음)
--   navAllowed(state)                 게임패드 내비게이션을 켜도 되는가 (라운드 소개·달리는 중·우승 연출이면 false)
--   reconcile(stack, open, order)     열린 창 목록을 열린 순서대로 맞춰요 → (새 스택, 새로 열린 id, 닫힌 id)
--   pickFirst(points)                 화면에서 맨 위·맨 왼쪽 점의 번호 (같은 줄은 ROW_TOLERANCE 안)
--   scrollToShow(...)                 선택한 칸이 스크롤 목록 안에 보이게 할 CanvasPosition.Y

local GamepadNavLogic = {}

-- TV 안전 여백: 화면 각 변 5% (Roblox 콘솔 가이드라인, 스펙 m5-12)
GamepadNavLogic.SAFE_FRACTION = 0.05
-- pickFirst: 위치 Y가 이만큼 안이면 같은 줄로 보고 X로 골라요 (픽셀)
GamepadNavLogic.ROW_TOLERANCE = 6
-- scrollToShow: 칸 위아래로 남길 여유 (픽셀)
GamepadNavLogic.SCROLL_MARGIN = 8

-- 모드를 바꾸지 않는 입력 종류 (창 포커스, 아직 모름, 화면 키보드 글자)
local NEUTRAL_INPUTS = {
	Focus = true,
	None = true,
	TextInput = true,
	InputMethod = true,
}

function GamepadNavLogic.isGamepadInput(inputTypeName: string): boolean
	local index = string.match(inputTypeName, "^Gamepad(%d)$")
	if index == nil then
		return false
	end
	local n = tonumber(index) :: number
	return n >= 1 and n <= 8
end

-- current: 지금 게임패드 모드인지. typing: 글자 칸에 포커스가 있는지 (콘솔 화면 키보드가 키보드 입력을 보내도 그대로)
function GamepadNavLogic.modeFor(current: boolean, inputTypeName: string, typing: boolean?): boolean
	if GamepadNavLogic.isGamepadInput(inputTypeName) then
		return true
	end
	if NEUTRAL_INPUTS[inputTypeName] then
		return current
	end
	if typing and current and inputTypeName == "Keyboard" then
		return current
	end
	return false
end

export type Insets = { x: number, y: number, fraction: number }

function GamepadNavLogic.insetsFor(tenFoot: boolean, width: number, height: number): Insets
	if not tenFoot then
		return { x = 0, y = 0, fraction = 0 }
	end
	local f = GamepadNavLogic.SAFE_FRACTION
	return { x = math.floor(width * f + 0.5), y = math.floor(height * f + 0.5), fraction = f }
end

function GamepadNavLogic.nextTab(tabs: { string }, current: string, dir: number): string
	if #tabs == 0 then
		return current
	end
	local index = table.find(tabs, current)
	if index == nil then
		return tabs[1]
	end
	local step = if dir > 0 then 1 elseif dir < 0 then -1 else 0
	local nextIndex = math.clamp(index + step, 1, #tabs)
	return tabs[nextIndex]
end

export type NavState = {
	inMatch: boolean,
	phase: string?, -- Types.MatchPhase
	alive: boolean, -- 이 매치에서 아직 탈락하지 않았는지
	passed: boolean, -- 이번 라운드를 통과해 대기석에 있는지
}

-- 라운드 소개·달리는 중(내가 레이서)·시작 카운트다운·우승 연출에는 꺼요 → A·B·X·R2는 게임 조작만.
-- 탈락해 관전 중, 통과해 대기석, 라운드 결과 사이에는 켜요 (탈의실을 열 수 있는 때와 같아요).
function GamepadNavLogic.navAllowed(state: NavState): boolean
	if not state.inMatch then
		return true
	end
	local phase = state.phase
	if phase == nil or phase == "Starting" or phase == "Victory" then
		return false
	end
	if not state.alive then
		return true
	end
	if phase == "RoundResults" then
		return true
	end
	return state.passed
end

-- stack: 지금까지 열린 창 id (열린 순서, 맨 뒤가 맨 위)
-- open: id → 지금 보이는지
-- order: 등록 순서(층 순서). 한 번에 여러 창이 열리면 이 순서대로 쌓아요
function GamepadNavLogic.reconcile(
	stack: { string },
	open: { [string]: boolean },
	order: { string }
): ({ string }, { string }, { string })
	local nextStack: { string } = {}
	local closed: { string } = {}
	local inStack: { [string]: boolean } = {}
	for _, id in stack do
		if open[id] then
			table.insert(nextStack, id)
			inStack[id] = true
		else
			table.insert(closed, id)
		end
	end
	local opened: { string } = {}
	for _, id in order do
		if open[id] and not inStack[id] then
			table.insert(nextStack, id)
			table.insert(opened, id)
			inStack[id] = true
		end
	end
	return nextStack, opened, closed
end

export type Point = { x: number, y: number }

function GamepadNavLogic.pickFirst(points: { Point }): number?
	local best: number? = nil
	for index, point in points do
		if best == nil then
			best = index
		else
			local current = points[best]
			local dy = point.y - current.y
			local higher = dy < -GamepadNavLogic.ROW_TOLERANCE
			local sameRowLeft = math.abs(dy) <= GamepadNavLogic.ROW_TOLERANCE and point.x < current.x
			if higher or sameRowLeft then
				best = index
			end
		end
	end
	return best
end

-- canvasY: 지금 CanvasPosition.Y, viewHeight: 보이는 높이,
-- itemTop: 칸 위쪽 (캔버스 맨 위 기준), itemHeight: 칸 높이, canvasHeight: 캔버스 전체 높이
function GamepadNavLogic.scrollToShow(
	canvasY: number,
	viewHeight: number,
	itemTop: number,
	itemHeight: number,
	canvasHeight: number
): number
	local margin = GamepadNavLogic.SCROLL_MARGIN
	local target = canvasY
	if itemTop - margin < canvasY then
		target = itemTop - margin
	elseif itemTop + itemHeight + margin > canvasY + viewHeight then
		target = itemTop + itemHeight + margin - viewHeight
	end
	local maxY = math.max(0, canvasHeight - viewHeight)
	return math.clamp(target, 0, maxY)
end

return GamepadNavLogic
