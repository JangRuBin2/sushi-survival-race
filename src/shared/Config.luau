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

Config.Character = {
	WalkSpeed = 16,
}

-- 혼자 테스트용 설정. 서버 코드는 RunService:IsStudio()일 때만 이 값을 적용해요.
Config.DEBUG = {
	minPlayersToStart = 1,
}

return Config
