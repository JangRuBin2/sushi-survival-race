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
	Title = "Title", -- string: 머리 위 이름표에 붙는 우승 칭호 (서버가 달아요, m4-08)
	-- number (workspace:GetServerTimeNow() 기준): 서버가 캐릭터를 옮기거나 튕긴 뒤 이동 감시(m4-10)가
	-- 검사하지 않는 시각. MoveExempt.mark로만 달아요 (m4-01).
	MoveExemptUntil = "MoveExemptUntil",

	-- GuiButton 또는 그 조상 GuiObject·ScreenGui (m3-09)
	NoClickSfx = "NoClickSfx", -- boolean: true면 누를 때 Sfx "ButtonClick"을 내지 않아요 (조작 버튼)

	-- Workspace (서버가 PlaceService.init에서 달아요, m4-11)
	PlaceRole = "PlaceRole", -- string: "Single" | "Lobby" | "Match" — 클라이언트가 매치 서버에서 로비 UI를 숨겨요

	-- Player (서버만 달아요, m5-02 테스트용 관리자)
	-- boolean: 관리자면 true (아니면 없음). 클라이언트는 관리자 패널을 만들지만 정해요 — 권한은 서버 관리자 표로만 판단해요.
	IsAdmin = "IsAdmin",
	AdminPreview = "AdminPreview", -- string: 미리보기로 입은 스킨 id (끄면 없음). 관리자 패널 강조용 (ShopService.setPreview)

	-- 라운드 맵 Model (RoundService.prepareRound가 Workspace에 넣기 전에 달아요)
	RoomId = "RoomId", -- string: 이 맵을 쓰는 방
	RoundIndex = "RoundIndex", -- number: 몇 번째 라운드인지 (1부터)
	MapId = "MapId", -- string: 맵 모듈 id
}

return Attributes
