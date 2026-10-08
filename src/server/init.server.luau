--!strict
-- 서버 부트스트랩. 서비스는 모두 init() → start() 순서로 불러요.
--   init():  서로 의존하지 않는 준비 (상태 만들기, 리모트 연결)
--   start(): 다른 서비스를 써도 되는 시작 단계

local SERVICES = {
	require(script.RoomService),
	require(script.MatchService),
	require(script.RoundService),
	require(script.EliminationService),
	require(script.AppearanceService),
	require(script.GrabService),
}

for _, service in SERVICES do
	service.init()
end
for _, service in SERVICES do
	service.start()
end
