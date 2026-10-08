--!strict
-- 서버가 캐릭터를 옮기거나 튕긴 직후를 이동 감시(m4-10 MovementGuardService)에서 빼 주는 표시 (m4-01).
--   MoveExempt.mark(character, seconds?)  캐릭터 Model에 Attributes.MoveExemptUntil = now + seconds를 달아요.
--                                         seconds가 없으면 Config.MovementGuard.ExemptAfterServerMove.
--                                         이미 더 늦은 값이 있으면 줄이지 않아요.
--   MoveExempt.untilTime(current, now, seconds)  위 계산의 순수 함수 (lune 테스트용)
-- 시각은 workspace:GetServerTimeNow() 기준이에요. 서버에서만 의미가 있어요 (클라이언트가 달아도 복제되지 않음).
-- 맵 모듈(shared)도 부를 수 있어요: 와사비 튕김, 꼬치·칼 넉백, 벨트·급류 밀기, 젓가락 들어 올리기 등.

local Attributes = require(script.Parent.Attributes)
local Config = require(script.Parent.Config)

local MoveExempt = {}

-- 지금 값(current)과 새 표시(now + seconds) 중 더 늦은 시각.
function MoveExempt.untilTime(current: number?, now: number, seconds: number?): number
	local value = now + (seconds or Config.MovementGuard.ExemptAfterServerMove)
	if type(current) == "number" and current > value then
		return current
	end
	return value
end

function MoveExempt.mark(character: Model?, seconds: number?)
	if character == nil then
		return
	end
	local current = character:GetAttribute(Attributes.MoveExemptUntil)
	local value =
		MoveExempt.untilTime(if type(current) == "number" then current else nil, workspace:GetServerTimeNow(), seconds)
	character:SetAttribute(Attributes.MoveExemptUntil, value)
end

return MoveExempt
