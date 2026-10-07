--!strict
-- 방 하나의 매치 상태 머신 (GDD 4, 11.4)
-- RoomWaiting → Starting → [RoundIntro → RoundActive → RoundResults] × 3~4 → Victory → RoomWaiting
-- 라운드 수/통과 인원/맵 구성은 Shared.Rules로 계산해요.
-- TODO(M1): 매치 생성, 단계 전환과 MatchPhase 방송, 라운드 사이 건너뛰기(Rules.nextRound)

local MatchService = {}

function MatchService.init() end

function MatchService.start() end

return MatchService
