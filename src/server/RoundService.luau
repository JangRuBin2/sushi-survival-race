--!strict
-- 라운드 하나: 맵 짓기 → 배치(고정) → 시작 → 통과/탈락 판정 → 결과 (GDD 5)
-- 맵 모듈은 Shared.maps의 공통 인터페이스(MapTypes.MapModule)를 따라요.
-- TODO(M1): RoundContext 만들기, 시간 제한, 통과 인원 집계와 RoundProgress 방송

local RoundService = {}

function RoundService.init() end

function RoundService.start() end

return RoundService
