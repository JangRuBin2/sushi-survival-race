--!strict
-- 탈락 연출 ("먹혔다!", m3-03) 순수 로직. Roblox API 없이 lune으로 테스트해요.
--   shouldPlay(cause)                     낙하·리셋·시간 종료(Timeout)면 연출, 퇴장·nil이면 연출 없음
--   isFinalRound(roundIndex, roundCount)  마지막 라운드(결승)인지 (값이 없으면 false)
--   variantFor(mapKind, isFinal, cause)   연출 종류: 결승 = ChefHand, Survival 낙하 = Mouth, 그 밖 = Chopsticks
--   linesFor / pickLine                   말풍선 대사 (공통 + 스킨 전용 + 결승 전용)
--   canStartWorld(activeCount)            동시 월드 연출 한도(MAX_CONCURRENT) 확인. 본인 연출은 한도와 무관
--   timeline(variant, duration)           효과음·말풍선 박자 (초). 길이에 맞춰 늘이고 줄여요
--   alpha(t, from, to)                    구간 진행도 0~1 (from 전 0, to 뒤 1)

local Config = require(script.Parent.Config)

local EliminationCutsceneLogic = {}

export type Variant = "Chopsticks" | "Mouth" | "ChefHand"

export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
}

export type Beat = {
	at: number, -- 연출 시작부터 초
	cue: string, -- Shared.SfxCues 효과음 이름
}

-- 한 클라이언트에서 동시에 재생하는 월드 연출 최대 개수 (본인 연출은 세지 않아요)
EliminationCutsceneLogic.MAX_CONCURRENT = Config.Fx.EliminationMaxConcurrent

-- 박자는 3초 기준으로 적고, 실제 길이(Config.Match.EliminationCutscene)에 맞춰 늘이고 줄여요
local BASE_DURATION = 3

EliminationCutsceneLogic.COMMON_LINES = {
	"음~ 신선하네!",
	"와사비 좀 더 주세요",
	"한 접시 더!",
	"이 집 초밥 잘하네~",
	"냠냠, 꿀맛!",
}

-- 스킨 전용 대사 (appearanceId → 대사 목록)
EliminationCutsceneLogic.SKIN_LINES = {
	tamago = {
		"계란초밥은 역시 달달해",
		"폭신폭신 계란 최고!",
	},
} :: { [string]: { string } }

-- 결승(ChefHand) 전용 대사
EliminationCutsceneLogic.FINAL_LINES = {
	"오늘의 마지막 접시!",
	"이건 내가 먹어야지~",
}

-- 3초 기준 박자. 각 연출 흐름은 스펙 m3-03 범위 3 표 그대로예요.
local TIMELINES: { [Variant]: { Beat } } = {
	Chopsticks = {
		{ at = 0.3, cue = "ChopstickClack" }, -- 0~0.6 젓가락이 내려와 집음
		{ at = 0.6, cue = "Struggle" }, -- 0.6~1.2 들어 올려 버둥
		{ at = 1.5, cue = "SoyDip" }, -- 1.2~1.8 간장 종지에 퐁당
		{ at = 2.25, cue = "Chomp" }, -- 1.8~2.4 손님 입으로 냠!
		{ at = 2.4, cue = "SpeechPop" }, -- 2.4~ 말풍선
	},
	Mouth = {
		{ at = 0, cue = "MouthFall" }, -- 0~1.2 입 벌린 손님 입으로 떨어짐
		{ at = 1.35, cue = "Chomp" }, -- 1.2~1.5 입이 닫힘
		{ at = 1.8, cue = "SpeechPop" },
	},
	ChefHand = {
		{ at = 0, cue = "ChefHand" }, -- 0~0.8 셰프 손이 내려옴, 0.8~1.2 움켜쥠, 1.2~2.2 들고 사라짐
		{ at = 2.2, cue = "SpeechPop" },
	},
}

function EliminationCutsceneLogic.shouldPlay(cause: string?): boolean
	return cause == "Fall" or cause == "Reset" or cause == "Timeout"
end

function EliminationCutsceneLogic.isFinalRound(roundIndex: number?, roundCount: number?): boolean
	return roundIndex ~= nil and roundCount ~= nil and roundIndex >= roundCount
end

function EliminationCutsceneLogic.variantFor(mapKind: string?, isFinal: boolean, cause: string?): Variant
	if isFinal then
		return "ChefHand"
	end
	if mapKind == "Survival" and cause == "Fall" then
		return "Mouth"
	end
	return "Chopsticks"
end

-- 이 스킨·연출에서 나올 수 있는 대사 전부 (공통 → 스킨 전용 → 결승 전용)
function EliminationCutsceneLogic.linesFor(appearanceId: string?, variant: Variant): { string }
	local lines = table.clone(EliminationCutsceneLogic.COMMON_LINES)
	local skinLines = if appearanceId then EliminationCutsceneLogic.SKIN_LINES[appearanceId] else nil
	if skinLines then
		table.move(skinLines, 1, #skinLines, #lines + 1, lines)
	end
	if variant == "ChefHand" then
		local finalLines = EliminationCutsceneLogic.FINAL_LINES
		table.move(finalLines, 1, #finalLines, #lines + 1, lines)
	end
	return lines
end

function EliminationCutsceneLogic.pickLine(appearanceId: string?, variant: Variant, rng: Rng): string
	local lines = EliminationCutsceneLogic.linesFor(appearanceId, variant)
	return lines[rng:NextInteger(1, #lines)]
end

function EliminationCutsceneLogic.canStartWorld(activeCount: number): boolean
	return activeCount < EliminationCutsceneLogic.MAX_CONCURRENT
end

-- 박자 목록 (at 오름차순). duration이 3초가 아니면 비율대로 늘이고 줄여요.
function EliminationCutsceneLogic.timeline(variant: Variant, duration: number?): { Beat }
	local scale = (duration or BASE_DURATION) / BASE_DURATION
	local beats: { Beat } = {}
	for _, beat in TIMELINES[variant] do
		table.insert(beats, { at = beat.at * scale, cue = beat.cue })
	end
	return beats
end

-- 3초 기준 시각 t를 실제 길이에 맞춘 시각으로 (연출 코드가 구간 경계를 맞출 때 써요)
function EliminationCutsceneLogic.scaled(t: number, duration: number?): number
	return t * (duration or BASE_DURATION) / BASE_DURATION
end

-- 구간 [from, to]에서 t의 진행도 0~1
function EliminationCutsceneLogic.alpha(t: number, from: number, to: number): number
	if to <= from then
		return if t >= to then 1 else 0
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

-- 부드럽게 시작하고 끝나는 진행도 (smoothstep)
function EliminationCutsceneLogic.smooth(a: number): number
	local x = math.clamp(a, 0, 1)
	return x * x * (3 - 2 * x)
end

return EliminationCutsceneLogic
