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

-- 혼자 테스트용 설정. 서버 코드는 RunService:IsStudio()일 때만 이 값을 적용해요.
Config.DEBUG = {
	minPlayersToStart = 1,
	-- 맵 id 3~4개를 넣으면 라운드 구성을 그 순서 그대로 써요 (라운드 수 = 목록 길이).
	-- 이때는 2명 이하여도 결승으로 건너뛰지 않고, 혼자여도 모든 라운드를 끝까지 돌아요.
	-- 예: { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }. 커밋할 때는 nil로.
	forceMapPlan = nil :: { string }?,
}

return Config
