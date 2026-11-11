--!strict
-- 스시 파이트 수치 (f1-01). 전부 기본값, 플레이테스트 후 조정 — docs/fight/GDD.md 3~7절.
-- 스시런 공용 Config.luau는 건드리지 않으려고 파이트 수치는 여기에 따로 둬요.
-- F1-02 기반 스펙에서 Config.Fight로 옮길지 정해요.

export type Move = {
	gauge: number, -- 맞은 사람 게이지 +%
	base: number, -- 기본 넉백 속도 (studs/초)
	scale: number, -- 맞은 뒤 게이지 1%당 넉백 속도
	lift: number, -- 위로 띄우는 비율 0~1 (넉백 방향 벡터의 y 성분)
	cooldown: number, -- 같은 사람이 이 기술을 다시 쓰기까지 (초)
}

export type MoveName = "Slap" | "Ram" | "Throw" | "Wasabi" | "Ikura" | "Burst" | "DashHit" | "SpinTick"

local FightConfig = {}

FightConfig.Gauge = {
	Max = 300, -- 게이지 상한 (%)
	TintFull = 150, -- 이 게이지부터 간장 색이 가장 진함
}

FightConfig.Knockback = {
	MaxSpeed = 220, -- 넉백 속도 상한
	HitstunPerSpeed = 0.004, -- 경직 = 넉백 속도 × 이 값
	HitstunMin = 0.1,
	HitstunMax = 1.2,
	SameMoveLockout = 0.4, -- 같은 사람에게 같은 기술로 다시 맞지 않는 시간
}

FightConfig.Moves = {
	Slap = { gauge = 4, base = 10, scale = 0.12, lift = 0.25, cooldown = 0.35 } :: Move,
	Ram = { gauge = 12, base = 30, scale = 0.35, lift = 0.35, cooldown = 1.5 } :: Move,
	Throw = { gauge = 9, base = 25, scale = 0.30, lift = 0.45, cooldown = 1.5 } :: Move,
	Wasabi = { gauge = 15, base = 40, scale = 0.45, lift = 0.30, cooldown = 0 } :: Move,
	Ikura = { gauge = 14, base = 35, scale = 0.40, lift = 0.40, cooldown = 0 } :: Move,
	-- 특수 스킬 타격 (f1-02, 쿨다운은 스킬 게이지가 대신해서 0)
	Burst = { gauge = 10, base = 30, scale = 0.30, lift = 0.40, cooldown = 0 } :: Move, -- 와사비 폭발
	DashHit = { gauge = 8, base = 22, scale = 0.25, lift = 0.30, cooldown = 0 } :: Move, -- 간장 대시
	SpinTick = { gauge = 3, base = 14, scale = 0.15, lift = 0.20, cooldown = 0 } :: Move, -- 회전 초밥 한 틱
} :: { [string]: Move }

FightConfig.RingOut = {
	BelowFloor = 25, -- 아레나 바닥보다 이만큼 아래면 장외
	OutsideRadius = 60, -- 아레나 반지름 + 이만큼 수평으로 나가면 장외
}

FightConfig.Ko = {
	CreditWindow = 5, -- 장외 직전 이 시간 안에 마지막으로 때린 사람이 KO 점수
}

FightConfig.Respawn = {
	Delay = 2,
	Invincible = 2,
}

FightConfig.Match = {
	Stocks = 3,
	TimeLimit = 150,
	MinPlayers = 2,
	MaxPlayers = 8,
	SuddenDeathGauge = 150,
	SuddenDeathCollapse = 20,
	SuddenDeathCap = 30,
}

-- 특수 스킬 (f1-02, GDD 5.1). 스킬은 목숨마다 회전초밥 룰렛이 정하고(고르기 없음), 스킨은 연출만 바꿔요.
FightConfig.Skills = {
	Meter = {
		Max = 100,
		PerSecond = 2, -- 가만히 있어도 50초면 참
		DealtHit = 6, -- 내가 맞혔을 때
		TakenHit = 4, -- 내가 맞았을 때
		Ko = 20, -- KO 점수를 받았을 때
	},
	HoldToUse = 0.5, -- 게이지가 차 있을 때 때리기 버튼을 이만큼 누르고 있으면 발동
	-- 회전초밥 룰렛: 부활 대기(Respawn.Delay) 안에 끝나요. 접시가 Laps바퀴 + 남은 칸을 돌다 감속해서 멈춤
	Roulette = {
		Laps = 2,
		Spin = 1.6, -- 돌기 시작 → 멈출 때까지 (초)
		Reveal = 0.4, -- 멈춘 뒤 뚜껑 열림 · 이름 배너까지
		Ease = 3, -- 감속 곡선 지수 (위치 = 1 - (1 - t)^Ease)
	},
	WasabiBurst = { radius = 9 },
	NoriShield = { duration = 2.5, knockbackMul = 0.35, gaugeMul = 0.5 },
	SoyDash = { distance = 18, duration = 0.3, hitRadius = 3.5 }, -- 대시 중 무적
	RiceSticky = { speed = 80, range = 50, slowMul = 0.5, slowDuration = 2.5, gauge = 6 },
	SushiSpin = { duration = 1.5, radius = 5, tick = 0.3 },
	GingerCleanse = { heal = 25, invincible = 0.6 },
}

FightConfig.Items = {
	GingerHeal = 30, -- 초생강 게이지 회복 (%)
	SoyPerSecond = 2, -- 간장 웅덩이 위 초당 게이지 +%
	ChopstickMinGauge = 100, -- 젓가락 소환 대상 최소 게이지
}

return FightConfig
