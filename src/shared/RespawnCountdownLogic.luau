--!strict
-- Race 부활 카운트다운 표시 계산 (m6-01, GDD 4). Roblox API에 의존하지 않아요.
-- 서버 RoundService가 Player 속성 Attributes.RespawnAt(workspace:GetServerTimeNow() 기준 다시 출발하는 시각)을 달면
-- 클라이언트 RespawnCountdown이 이 함수로 화면 가운데 큰 숫자를 정해요. 판정에는 쓰지 않아요.

local RespawnCountdownLogic = {}

-- 화면에 보일 남은 초 (3, 2, 1). 속성이 없거나 숫자가 아니면 nil(숨김).
-- 시각이 지났는데 서버가 아직 속성을 안 지웠으면(다음 캐릭터를 기다리는 중) 1에 멈춰 둬요 — 0이나 음수는 안 보여요.
function RespawnCountdownLogic.secondsLeft(respawnAt: unknown, now: number): number?
	if type(respawnAt) ~= "number" or respawnAt ~= respawnAt then
		return nil
	end
	return math.max(1, math.ceil(respawnAt - now))
end

return RespawnCountdownLogic
