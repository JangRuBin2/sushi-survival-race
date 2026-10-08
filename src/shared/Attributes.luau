--!strict
-- 여러 기능이 같이 쓰는 Instance 속성 이름 (상수만). 이름을 바꾸려면 여기만 바꿔요.

local Attributes = {
	-- 캐릭터 Model
	AppearanceId = "AppearanceId", -- string: 입은 스킨 id (AppearanceService.applyAppearance, m3-02)
	GrabbedBy = "GrabbedBy", -- number: 나를 잡은 사람의 userId (m3-07)
	GrabbingUserId = "GrabbingUserId", -- number: 내가 잡고 있는 사람의 userId (m3-07)

	-- 라운드 맵 Model (RoundService.prepareRound가 Workspace에 넣기 전에 달아요)
	RoomId = "RoomId", -- string: 이 맵을 쓰는 방
	RoundIndex = "RoundIndex", -- number: 몇 번째 라운드인지 (1부터)
	MapId = "MapId", -- string: 맵 모듈 id
}

return Attributes
