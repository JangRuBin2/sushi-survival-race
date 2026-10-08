--!strict
-- 잡기 입력 상태 순수 로직 (m4-12, m3-07 QA G1·G4). Roblox API 없이 Lune으로 테스트해요.
--   new(minGap)                         입력원별 누름 상태 + 서버에 마지막으로 보낸 값
--   set(state, source, down, now)       입력원 하나가 눌림/뗌 → 지금 보낼 값 목록과 다시 볼 시각(nil이면 없음)
--   flush(state, now)                   예약 시각이 지났으면 지금 보낼 값 (마지막 상태를 한 번 더)
--   cancel(state)                       모든 입력원을 뗀 것으로 (다이브·포커스 잃음·캐릭터 바뀜) → 보낼 값 목록
--   isHolding(state)                    하나라도 누르고 있나
-- 규칙:
--   - 입력원(마우스·게임패드·터치)마다 따로 누름을 기록하고, 하나라도 누르고 있으면 "잡기" (G4).
--   - 놓기(false)는 바로 보내요 (서버도 놓기는 간격 제한 없이 처리).
--   - 누름(true)은 서버 간격 제한(Config.Grab.InputMinInterval)에 걸리지 않게 마지막 누름에서 minGap이 지나야 보내요.
--     더 빨리 다시 누르면 보내지 않고 시각을 예약했다가, 그때도 누르고 있으면 한 번 보내요 (G1).

local GrabInputLogic = {}

-- 네트워크 지연으로 두 요청 간격이 줄어도 서버 제한에 걸리지 않게 더하는 여유(초)
GrabInputLogic.MARGIN = 0.03

export type Source = "mouse" | "gamepad" | "touch"

export type State = {
	sources: { [string]: boolean },
	sent: boolean, -- 서버에 마지막으로 보낸 값
	lastPressSent: number, -- 마지막으로 true를 보낸 시각
	pendingAt: number?, -- 다시 볼 시각
	minGap: number,
}

function GrabInputLogic.new(minInterval: number): State
	return {
		sources = {},
		sent = false,
		lastPressSent = -math.huge,
		pendingAt = nil,
		minGap = minInterval + GrabInputLogic.MARGIN,
	}
end

function GrabInputLogic.isHolding(state: State): boolean
	return next(state.sources) ~= nil
end

-- 지금 원하는 값(누르고 있나)과 보낸 값을 맞춰요. 누름이 너무 이르면 예약만 해요.
local function sync(state: State, now: number): { boolean }
	local want = GrabInputLogic.isHolding(state)
	if want == state.sent then
		if not want then
			state.pendingAt = nil
		end
		return {}
	end
	if not want then
		state.sent = false
		state.pendingAt = nil
		return { false }
	end
	local readyAt = state.lastPressSent + state.minGap
	if now + 1e-9 < readyAt then
		state.pendingAt = readyAt
		return {}
	end
	state.sent = true
	state.lastPressSent = now
	state.pendingAt = nil
	return { true }
end

function GrabInputLogic.set(state: State, source: Source, down: boolean, now: number): ({ boolean }, number?)
	state.sources[source] = if down then true else nil
	local sends = sync(state, now)
	return sends, state.pendingAt
end

function GrabInputLogic.flush(state: State, now: number): { boolean }
	local at = state.pendingAt
	if at == nil or now + 1e-9 < at then
		return {}
	end
	state.pendingAt = nil
	return sync(state, now)
end

function GrabInputLogic.cancel(state: State): { boolean }
	table.clear(state.sources)
	state.pendingAt = nil
	if state.sent then
		state.sent = false
		return { false }
	end
	return {}
end

return GrabInputLogic
