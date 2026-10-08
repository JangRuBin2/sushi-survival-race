--!strict
-- 서버 이동 감시: 순간이동·속도 위반 되돌리기, 결승선 통과 막기 (m4-10). RoundService.setPassValidator·MoveExempt를 써요.
-- m4-01 껍데기: 아직 아무것도 하지 않아요. 동작은 m4-10 스펙이 이 파일에 채워요 (init.server.luau 등록은 m4-01이 끝냄).

local MovementGuardService = {}

function MovementGuardService.init() end

function MovementGuardService.start() end

return MovementGuardService
