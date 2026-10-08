--!strict
-- 튜닝 값 모음 (GDD 3, 4, 5). 밸런스 조정은 여기서만 해요.
-- Roblox API를 쓰지 않아서 tests/에서도 그대로 불러올 수 있어요.

local Config = {}

-- 방 (GDD 3.2)
Config.Room = {
	MaxPlayerOptions = { 4, 8, 12, 16, 24 },
	DefaultMaxPlayers = 12,
	MinPlayersToStart = 4,
	AutoStartDelay = 10, -- 정원이 다 차면 이 시간(초) 뒤 자동 시작
	CodeLength = 4, -- 비공개 방 코드 자릿수
	NameMaxLength = 24,
}

-- 라운드 수와 통과 비율 (GDD 3.3, 4.1)
Config.Rules = {
	FourRoundMinPlayers = 9, -- 시작 인원이 이 이상이면 4라운드, 미만이면 3라운드
	MinQualifiers = 2, -- 결승 전 라운드는 최소 이만큼 통과
	SkipToFinalAt = 2, -- 결승 전에 남은 인원이 이하이면 바로 결승
	-- 라운드 수 → 라운드별 통과 비율. 마지막(결승)은 1명 우승이라 비율이 없어요.
	PassRatios = {
		[3] = { 0.60, 0.50 },
		[4] = { 0.65, 0.55, 0.50 },
	} :: { [number]: { number } },
}

-- 매치 진행 시간(초) (GDD 4)
Config.Match = {
	StartCountdown = 3,
	IntroDuration = 3, -- 맵 플라이스루 + 이름/규칙
	ResultsDuration = 5,
	VictoryDuration = 10, -- 우승 연출(VictoryCutscene) + 순위표
	VictoryCutscene = 6, -- 우승 연출 길이 (VictoryDuration 안에서)
	EliminationCutscene = 3,
}

-- 맵 종류별 시간 제한(초) (GDD 5.2). 맵 모듈이 timeLimit을 따로 정하지 않으면 이 값을 써요.
Config.TimeLimit = {
	Race = 90,
	Survival = 60,
	Final = 90,
}

-- 매치 맵이 지어지는 위치. 로비(원점)와 겹치지 않게 띄우고,
-- 한 서버에서 여러 방이 동시에 돌 수 있게 방마다 슬롯을 나눠요.
Config.Arena = {
	BaseHeight = 300,
	SlotSpacing = 2000,
}

-- 캐릭터 이동 기본값. 서버가 이동 잠금(장애물, 출발 대기 등)을 풀 때 이 값으로 되돌려요.
Config.Character = {
	WalkSpeed = 16,
	JumpPower = 50,
}

-- 캐릭터 외형 (스킨은 가장 마지막에 개발). 외형은 AppearanceService.applyAppearance 한 곳에서만 입혀요.
Config.Appearance = {
	Default = "tamago", -- 기본 스킨 id (계란초밥)
}

-- 다이브 (GDD 6). 클라이언트 물리로 처리해요 (m3-06).
Config.Dive = {
	Cooldown = 1.5, -- 다이브 사이 최소 간격(초)
	LandingStun = 0.5, -- 착지 뒤 경직(초)
	ForwardSpeed = 40, -- 다이브 순간 수평 속도 (studs/s)
	UpSpeed = 16, -- 바닥에서 다이브할 때 위로 튀는 속도
	MaxFlightTime = 1.0, -- 이 시간 안에 착지하지 않아도 엎드린 자세를 끝내요
	ProneAngle = 80, -- 엎드린 자세 기울기 (도, 앞으로)
	-- 공중 다이브의 위쪽 속도는 이 값까지만 남겨요 (점프 직후 다이브 연타가 걷기보다 빠르지 않게, m3-06 QA B1).
	-- 꼭대기·내려가는 중 다이브(체공 늘리기)는 그대로예요.
	AirMaxUpSpeed = 16,
}

-- 잡기 (GDD 6). 서버가 판정하고, 감속은 클라이언트 입력 배수로 처리해요 (m3-07).
Config.Grab = {
	Range = 5, -- 잡을 수 있는 거리 (HumanoidRootPart 사이)
	FrontDot = 0.5, -- 앞쪽 판정 (바라보는 방향과 대상 방향의 내적, 약 60도 안)
	BreakRange = 9, -- 잡은 뒤 이보다 멀어지면 놓쳐요
	MaxHold = 2, -- 최대 잡는 시간(초)
	TargetSpeedMultiplier = 0.5, -- 잡힌 사람 이동 속도 배수
	GrabberSpeedMultiplier = 0.7, -- 잡는 사람도 느려져요
	Cooldown = 1.5, -- 잡기가 끝난 뒤 다시 잡을 수 있을 때까지(초)
	Immunity = 1.0, -- 풀려난 사람을 다시 잡을 수 없는 시간(초)
	InputMinInterval = 0.1, -- GrabInput 요청 간격 제한(초)
}

-- 연출·소리 튜닝 (m3-09). 친구 테스트 뒤 바꿀 만한 값을 여기 모아요.
Config.Fx = {
	EliminationMaxConcurrent = 6, -- 한 화면에서 동시에 재생하는 남의 탈락 연출 수 (본인 연출은 세지 않아요)
	-- 관전 중 탈락한 사람을 비추는 시간 = Match.EliminationCutscene - 이 값 (서버의 로비 이동보다 먼저 끝나게)
	SpectateHoldMargin = 0.3,
	SfxVolume = 0.7, -- 효과음 SoundGroup 볼륨
	MusicVolume = 0.3, -- 배경음 SoundGroup 볼륨
	SfxMaxDistance = 120, -- 3D 효과음이 들리는 최대 거리 (studs)
	SfxMaxActive = 16, -- 한 클라이언트에서 동시에 울리는 효과음 수 한도
	MapSfxMinInterval = 0.2, -- 같은 장애물 파트·같은 cue가 다시 울리기까지 최소 간격(초)
	NarrowScreenWidth = 900, -- 화면 폭(px)이 이보다 좁으면 음소거 버튼을 아이콘만으로 줄여요
}

-- 플레이스 분리 (m4-11). 사용자가 Match 플레이스를 만들고 id를 넣기 전까지 nil → 한 플레이스 모드(지금과 같음)
Config.Places = {
	LobbyPlaceId = nil :: number?,
	MatchPlaceId = nil :: number?,
}

Config.Teleport = {
	ArrivalTimeout = 20, -- 매치 서버가 멤버 도착을 기다리는 최대 시간(초)
	RestoreWindow = 30, -- 로비로 돌아온 멤버가 같은 방으로 다시 묶이는 시간(초)
	DirectoryRefresh = 5, -- 방 목록을 MemoryStore에 다시 올리는 간격(초)
	DirectoryTtl = 30, -- MemoryStore 방 항목 만료(초)
	MaxRetries = 3, -- 텔레포트 실패(TeleportInitFailed) 때 그 사람만 다시 보내는 횟수
	ManifestTtl = 600, -- MemoryStore 매치 매니페스트 만료(초)
	ResultTtl = 120, -- MemoryStore 매치 결과(로비 단상·복귀 방 정보) 만료(초)
	LaunchTimeout = 60, -- 로비에서 텔레포트를 시작한 뒤 이 시간이 지나도 남아 있는 멤버는 방에서 빼요(초)
	SaveBeforeTeleport = 5, -- 텔레포트 전에 프로필 저장을 기다리는 최대 시간(초)
	SimulateSettle = 5, -- Studio 흉내 모드: 이 시간 동안 새로 들어오는 사람이 없으면 매니페스트를 만들어요(초)
}

-- 저장 (GDD 9.5, m4-07)
Config.Data = {
	StoreName = "PlayerData_v1",
	AutosaveInterval = 60, -- 바뀐 프로필 자동 저장 간격(초)
	SessionLockExpiry = 1800, -- 다른 서버의 세션 잠금을 무시해도 되는 시간(초)
	LoadRetries = 5, -- 잠금이 걸려 있을 때 다시 읽는 횟수 (텔레포트 직후 대비)
	RetryDelay = 2,
	SettingsMinInterval = 0.5, -- SaveSettings 요청 간격 제한(초)
}

-- 밥알 코인 (GDD 9.4, m4-08)
Config.Rewards = {
	RoundPass = 10,
	FinalQualify = 30,
	Win = 100,
	DailyFirstMatch = 50,
}

-- 우승 칭호 (GDD 8). 승수 오름차순
Config.Titles = {
	{ wins = 1, name = "탈출 초밥" },
	{ wins = 10, name = "전설의 참치" },
	{ wins = 100, name = "바다의 왕" },
} :: { { wins: number, name: string } }

-- 화면 크기 대응 (m4-09)
Config.Ui = {
	BaseShortSide = 720, -- 이 짧은 변(px)에서 UIScale 1
	MinScale = 0.6,
	MaxScale = 1.25,
	CompactShortSide = 500, -- 짧은 변이 이하면 휴대폰 배치
	MinTouchSize = 44, -- 터치 버튼 최소 크기(px, 스케일 적용 뒤)
}

-- 스킨 탈의실 (m4-13). 가격·목록은 Shared.Skins
Config.Shop = {
	RequestCooldown = 0.3, -- EquipSkin·BuyWithCoins 요청 간격 제한(초, 두 요청이 같이 써요)
	PurchaseRequestCooldown = 1, -- RequestRobuxPurchase 요청 간격 제한(초, m4-14)
	PurchasePromptHold = 120, -- 결제 창을 띄운 스킨의 코인 해금을 막는 최대 시간(초). 취소·지급되면 바로 풀려요 (m4-14 QA R2)
	ReceiptHistoryMax = 50, -- 프로필에 기억하는 처리한 결제 id 수 (오래된 것부터 지워요, m4-14)
	PurchaseLogStore = "Purchases_v1", -- 구매 기록 DataStore (키 = PurchaseId, m4-14)
}

-- 서버 이동 감시 (m4-10)
Config.MovementGuard = {
	SampleInterval = 0.2,
	MaxHorizontalSpeed = 80, -- 다이브·와사비·벨트 밀기를 합친 여유 상한 (studs/s)
	MaxRiseSpeed = 140, -- 와사비 튕김 포함 위로 가는 속도 상한
	Slack = 6, -- 샘플마다 더 허용하는 거리 (studs)
	ExemptAfterServerMove = 1.0, -- 서버가 옮긴/튕긴 뒤 검사하지 않는 시간(초)
	PassBlockAfterViolation = 2, -- 위반 뒤 이 시간 동안 결승선 통과를 받지 않음(초)
	StrikesToLog = 3,
}

-- 혼자 테스트용 설정. 서버 코드는 RunService:IsStudio()일 때만 이 값을 적용해요.
Config.DEBUG = {
	minPlayersToStart = 1,
	-- 맵 id 3~4개를 넣으면 라운드 구성을 그 순서 그대로 써요 (라운드 수 = 목록 길이).
	-- 이때는 2명 이하여도 결승으로 건너뛰지 않고, 혼자여도 모든 라운드를 끝까지 돌아요.
	-- 예: { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }. 커밋할 때는 nil로.
	forceMapPlan = nil :: { string }?,
	-- forceMapPlan이 nil일 때 플랜(맵 id 3~4개) 목록을 넣으면, 한 서버에서 매치를 시작할 때마다 다음 플랜을 써요.
	-- 혼자 연속 5판으로 6개 맵을 다 돌려 볼 때 (m4-12 AC4). 커밋할 때는 nil로.
	forceMapPlans = nil :: { { string } }?,
	-- true면 Studio에서도 진짜 DataStore에 저장해요 (게임 설정에서 API 접근 허용 필요, m4-07).
	-- false면 Studio에서는 메모리 프로필만 써요 (나가면 사라짐).
	persistDataInStudio = false,
	-- true면 Studio를 매치 서버처럼 돌려요 (m4-11): 접속한 사람 전원을 매니페스트 멤버로 보고 대기실 없이 바로
	-- 매치를 시작하고, 끝나면 텔레포트 대신 로그 + 로비 스폰. 커밋할 때는 false로.
	simulateMatchServer = false,
	-- true면 매치가 끝날 때마다 서버 Output에 한 줄: Workspace 자식 수, 남은 아레나(맵) Model 수, 진행 중 매치 수,
	-- 정리 안 된 라운드 훅 수, 서버 메모리(MB). 연속 매치 안정성 확인용 (m4-12). 커밋할 때는 false로.
	logArenaStats = false,
	-- true면 Studio에서 로벅스 버튼이 상품 id 없이도 켜지고, 누르면 결제 창 없이 가짜 영수증으로 결제 처리 흐름을
	-- 그대로 타요 (m4-14). 저장이 메모리 모드면 메모리에. 실제 서버에서는 무시. 커밋할 때는 false로.
	-- persistDataInStudio와 같이 켜면 운영 저장소에 가짜 기록이 써지니 가짜 결제는 꺼지고 경고만 남겨요 (m4-14 QA R4).
	fakeRobuxInStudio = false,
}

return Config
