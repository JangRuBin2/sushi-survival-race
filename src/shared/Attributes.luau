--!strict
-- 여러 기능이 같이 쓰는 Instance 속성 이름 (상수만). 이름을 바꾸려면 여기만 바꿔요.

local Attributes = {
	-- 캐릭터 Model
	AppearanceId = "AppearanceId", -- string: 입은 스킨 id (AppearanceService.applyAppearance, m3-02)
	GrabbedBy = "GrabbedBy", -- number: 나를 잡은 사람의 userId (m3-07)
	GrabbingUserId = "GrabbingUserId", -- number: 내가 잡고 있는 사람의 userId (m3-07)
	-- boolean: 캐릭터 아래에 붙이는 보이는 파츠·Decal(또는 그 조상)에 true로 달면 외형 숨김에서 빠져요 (m3-09).
	-- AppearanceService는 SushiBody 밖의 BasePart·Decal을 전부 숨겨요 — 보여야 하는 걸 붙일 때 이걸 달아요.
	KeepVisible = "KeepVisible",

	-- GuiButton 또는 그 조상 GuiObject·ScreenGui (m3-09)
	NoClickSfx = "NoClickSfx", -- boolean: true면 누를 때 Sfx "ButtonClick"을 내지 않아요 (조작 버튼)

	-- 라운드 맵 Model (RoundService.prepareRound가 Workspace에 넣기 전에 달아요)
	RoomId = "RoomId", -- string: 이 맵을 쓰는 방
	RoundIndex = "RoundIndex", -- number: 몇 번째 라운드인지 (1부터)
	MapId = "MapId", -- string: 맵 모듈 id
}

return Attributes
