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

export type MoveName = "Slap" | "Ram" | "Throw" | "Wasabi" | "Ikura"

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

FightConfig.Items = {
	GingerHeal = 30, -- 초생강 게이지 회복 (%)
	SoyPerSecond = 2, -- 간장 웅덩이 위 초당 게이지 +%
	ChopstickMinGauge = 100, -- 젓가락 소환 대상 최소 게이지
}

return FightConfig
