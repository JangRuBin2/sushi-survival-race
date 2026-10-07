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
	VictoryDuration = 6,
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

-- 혼자 테스트용 설정. 서버 코드는 RunService:IsStudio()일 때만 이 값을 적용해요.
Config.DEBUG = {
	minPlayersToStart = 1,
	-- 맵 id 3~4개를 넣으면 라운드 구성을 그 순서 그대로 써요 (라운드 수 = 목록 길이).
	-- 이때는 2명 이하여도 결승으로 건너뛰지 않고, 혼자여도 모든 라운드를 끝까지 돌아요.
	-- 예: { "soy-swamp", "hot-plate", "rotating-belt", "skewer-showdown" }. 커밋할 때는 nil로.
	forceMapPlan = nil :: { string }?,
}

return Config
