--!strict
-- 서버 부트스트랩. 서비스는 모두 init() → start() 순서로 불러요.
--   init():  서로 의존하지 않는 준비 (상태 만들기, 리모트 연결)
--   start(): 다른 서비스를 써도 되는 시작 단계
-- DataService가 맨 앞(접속한 사람의 프로필을 가장 먼저 로드), PlaceService 다음, 그 뒤 기존 서비스,
-- 마지막에 M4 서비스 (m4-01). 껍데기 서비스는 각 스펙이 채워요.

local SERVICES = {
	require(script.DataService),
	require(script.PlaceService),
	require(script.RoomService),
	require(script.MatchService),
	require(script.RoundService),
	require(script.EliminationService),
	require(script.AppearanceService),
	require(script.GrabService),
	require(script.LobbyService), -- m4-06
	require(script.RewardService), -- m4-08
	require(script.MovementGuardService), -- m4-10
	require(script.ShopService), -- m4-13
}

for _, service in SERVICES do
	service.init()
end
for _, service in SERVICES do
	service.start()
end
