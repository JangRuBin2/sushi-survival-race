--!strict
-- 잡기·공격 터치 버튼을 보일지 (m6-14 C1, 순수 — Roblox API 없음).
-- 서버는 출발한 라운드의 레이서(RoundService.activeRoomOf)에게서만 잡기·공격을 받아요. 그 밖의 때에 버튼이 떠 있으면
-- 눌러도 아무 일이 없어 고장처럼 보이니, 클라이언트가 받는 정보로 서버 기준을 근사해 숨겨요 (UI 편의, 권한 아님).
--
--   new() -> State                         로비 상태 (매치 밖)
--   onRoom(state, inMatch)                 RoomUpdated: 매치 밖이 되거나 새 매치에 들어가면 매치 상태를 처음으로
--   onPhase(state, phase, aliveUserIds?, myUserId)   MatchPhase: Starting = 새 매치, RoundIntro = 새 라운드(통과 지움)
--   onResult(state, result)                PlayerResult(내 것만): Passed·Won = 더 달리지 않음, Eliminated = 탈락
--   canUseRaceActions(state, live)         보일지. live = 매 프레임 보는 값(부활 대기 RespawnAt, 관전 카메라)
--
-- 보이는 때 = 방이 InMatch + phase RoundActive + 이 매치에서 탈락 안 함 + 이번 라운드 통과·우승 안 함
--            + 부활 대기 아님 + 관전 아님. 1인 연습(m6-13)도 RoundIntro → RoundActive를 지나서 같아요.
-- 다이너마이트(m6-12)는 달리는 중에만 주울 수 있어서 따로 보지 않아요 (공격 버튼이 🧨로 바뀔 뿐).
-- 다이브 버튼은 로비에서도 다이브가 되니 이 판단을 쓰지 않아요.

local RaceActionLogic = {}

export type Phase = "Starting" | "RoundIntro" | "RoundActive" | "RoundResults" | "Victory"

export type State = {
	inMatch: boolean,
	phase: Phase?,
	alive: boolean, -- 이 매치에서 아직 탈락하지 않았는가
	passed: boolean, -- 이번 라운드를 통과(또는 우승)해서 더 달리지 않는가
}

export type Live = {
	respawning: boolean, -- Player 속성 RespawnAt이 있음 (Race 부활 대기, m6-01)
	spectating: boolean, -- 카메라가 내 Humanoid를 보지 않음
}

export type ResultKind = "Passed" | "Eliminated" | "Won"

function RaceActionLogic.new(): State
	return { inMatch = false, phase = nil, alive = true, passed = false }
end

local function resetMatch(state: State)
	state.phase = nil
	state.alive = true
	state.passed = false
end

function RaceActionLogic.onRoom(state: State, inMatch: boolean)
	local wasInMatch = state.inMatch
	state.inMatch = inMatch
	if not inMatch or not wasInMatch then
		resetMatch(state) -- 매치 밖이거나 새 매치 (ShopController와 같은 기준)
	end
end

function RaceActionLogic.onPhase(state: State, phase: Phase, aliveUserIds: { number }?, myUserId: number)
	state.phase = phase
	if phase == "Starting" then
		state.alive = true
		state.passed = false
	elseif phase == "RoundIntro" then
		state.passed = false
	end
	if aliveUserIds then
		state.alive = table.find(aliveUserIds, myUserId) ~= nil
	end
end

function RaceActionLogic.onResult(state: State, result: ResultKind)
	if result == "Eliminated" then
		state.alive = false
	else
		state.passed = true -- Passed: 대기석, Won: 우승 연출로 넘어가요
	end
end

function RaceActionLogic.canUseRaceActions(state: State, live: Live): boolean
	return state.inMatch
		and state.phase == "RoundActive"
		and state.alive
		and not state.passed
		and not live.respawning
		and not live.spectating
end

-- 버튼 하나가 보일지: 자리를 잡을 수 있음(점프 버튼이 보이고 크기가 있음, 편집 중 아님) AND 달리는 중
function RaceActionLogic.buttonVisible(placementOk: boolean, canUse: boolean): boolean
	return placementOk and canUse
end

return RaceActionLogic
