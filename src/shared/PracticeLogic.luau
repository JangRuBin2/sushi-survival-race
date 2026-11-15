--!strict
-- 1인 연습 모드 (m6-13) 순수 로직. Roblox API에 의존하지 않아요.
--   로비에서 맵을 골라 혼자 한 라운드를 뛰어요. 보상·승수·순위·단상·뽑기권은 없어요(MatchEvents를 보내지 않아요).
--   라운드 방식: Race 맵 = Race(낙하하면 출발점 부활, 결승선 통과로 끝), Survival·Final 맵 = 버티기(시간 끝까지 버티면 성공,
--   떨어지면 끝). 결승(Final 방식)이 아니라서 우승(Won)이 생기지 않아요.

local Rules = require(script.Parent.Rules)

local PracticeLogic = {}

export type Reason = "BadPracticeMap"

-- 맵 고르기 창 순서: Race → Survival → Final, 같은 종류 안에서는 맵 풀(Maps.ALL) 순서 그대로
PracticeLogic.KIND_ORDER = { "Race", "Survival", "Final" } :: { Rules.MapKind }

local MAX_ID_LENGTH = 64

-- 클라이언트가 보낸 맵 id를 연습 가능한 맵(랜덤 판 풀)으로 확인해요. 틀리면 (nil, 이유).
function PracticeLogic.resolveMap(raw: unknown, infos: { Rules.MapInfo }): (Rules.MapInfo?, Reason?)
	if type(raw) ~= "string" or #raw == 0 or #raw > MAX_ID_LENGTH then
		return nil, "BadPracticeMap"
	end
	for _, info in infos do
		if info.id == raw then
			return info, nil
		end
	end
	return nil, "BadPracticeMap"
end

-- 맵 고르기 창에 보여 줄 순서 (종류별로 묶고, 같은 종류는 받은 순서)
function PracticeLogic.orderedMaps(infos: { Rules.MapInfo }): { Rules.MapInfo }
	local out: { Rules.MapInfo } = {}
	for _, kind in PracticeLogic.KIND_ORDER do
		for _, info in infos do
			if info.kind == kind then
				table.insert(out, info)
			end
		end
	end
	return out
end

return PracticeLogic
