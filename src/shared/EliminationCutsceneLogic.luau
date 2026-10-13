--!strict
-- 탈락 연출 ("먹혔다!", m3-03) 순수 로직. Roblox API 없이 lune으로 테스트해요.
--   shouldPlay(cause)                     낙하·리셋·시간 종료(Timeout)면 연출, 퇴장·nil이면 연출 없음
--   isFinalRound(roundIndex, roundCount)  마지막 라운드(결승)인지 (값이 없으면 false)
--   variantFor(mapKind, isFinal, cause)   연출 종류: 결승 = ChefHand, Survival 낙하 = Mouth, 그 밖 = Chopsticks
--   skinFor(fxId)                         탈락 연출 팩(m5-09): 고양이 손님이면 "Cat", 그 밖은 "Default"
--   linesFor / pickLine                   말풍선 대사 (공통 + 스킨 전용 + 결승 전용, 고양이면 고양이 대사만)
--   lineTextsFor / pickLineText           같은 목록·같은 고르기를 화면용 키(LocText)로 (m5-26, 클라이언트는 이걸 써요)
--   canStartWorld(activeCount)            동시 월드 연출 한도(MAX_CONCURRENT) 확인. 본인 연출은 한도와 무관
--   timeline(variant, duration, fxSkin)   효과음·말풍선 박자 (초). 길이에 맞춰 늘이고 줄여요. 고양이면 CatMeow 하나 더
--   alpha(t, from, to)                    구간 진행도 0~1 (from 전 0, to 뒤 1)

local Config = require(script.Parent.Config)
local FxCatalog = require(script.Parent.FxCatalog)
local LocalizeLogic = require(script.Parent.LocalizeLogic)
local Skins = require(script.Parent.Skins)
local Types = require(script.Parent.Types)

local EliminationCutsceneLogic = {}

export type Variant = "Chopsticks" | "Mouth" | "ChefHand"

-- 먹는 쪽 모습 (m5-09 연출 팩). 흐름·박자·길이는 Variant가 정하고, 이건 겉모습만 바꿔요.
export type FxSkin = "Default" | "Cat"

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

-- 스킨 전용 대사 (appearanceId → 대사 목록). 스킨 카탈로그(Shared.Skins)의 speech에서 만들어요 (m4-13).
local skinLineTable: { [string]: { string } } = {}
for _, skin in Skins.LIST do
	skinLineTable[skin.id] = table.clone(skin.speech)
end
EliminationCutsceneLogic.SKIN_LINES = skinLineTable

-- 결승(ChefHand) 전용 대사
EliminationCutsceneLogic.FINAL_LINES = {
	"오늘의 마지막 접시!",
	"이건 내가 먹어야지~",
}

-- 고양이 손님 (m5-09) 대사. 먹는 쪽이 고양이라 스킨·결승 대사 대신 이것만 써요 (결정 D3).
EliminationCutsceneLogic.CAT_LINES = {
	"냥~ 신선하다냥!",
	"생선은 역시 최고냥",
	"한 접시 더 달라냥!",
}

-- 고양이 "냥!"은 이 박자(먹는 순간, 결승은 앞발이 나타나는 순간) 바로 뒤에 한 번
local CAT_MEOW_AFTER: { [Variant]: string } = {
	Chopsticks = "Chomp",
	Mouth = "Chomp",
	ChefHand = "ChefHand",
}
local CAT_MEOW_DELAY = 0.12 -- 3초 기준 초

-- FxCatalog 연출 id → 먹는 쪽 모습 (탈락 slot만)
local FX_SKINS: { [string]: FxSkin } = {
	["cat-customer"] = "Cat",
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

-- 탈락한 사람이 입은 연출(Player 속성 EliminationFx) → 모습. 카탈로그에 없거나 slot이 다르면 기본.
function EliminationCutsceneLogic.skinFor(fxId: any): FxSkin
	if type(fxId) ~= "string" then
		return "Default"
	end
	local fx = FxCatalog.get(fxId)
	if fx == nil or fx.slot ~= "Elimination" then
		return "Default"
	end
	return FX_SKINS[fxId] or "Default"
end

-- 이 스킨·연출에서 나올 수 있는 대사 전부 (공통 → 스킨 전용 → 결승 전용). 고양이면 고양이 대사만.
function EliminationCutsceneLogic.linesFor(appearanceId: string?, variant: Variant, fxSkin: FxSkin?): { string }
	if fxSkin == "Cat" then
		return table.clone(EliminationCutsceneLogic.CAT_LINES)
	end
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

function EliminationCutsceneLogic.pickLine(appearanceId: string?, variant: Variant, rng: Rng, fxSkin: FxSkin?): string
	local lines = EliminationCutsceneLogic.linesFor(appearanceId, variant, fxSkin)
	return lines[rng:NextInteger(1, #lines)]
end

-- linesFor와 같은 순서의 화면용 키 (m5-26): 공통 cutscene.line.common.<n> → 스킨 skin.<id>.speech.<n>
-- → 결승 cutscene.line.final.<n>, 고양이면 cutscene.line.cat.<n>만
function EliminationCutsceneLogic.lineTextsFor(
	appearanceId: string?,
	variant: Variant,
	fxSkin: FxSkin?
): { Types.LocText }
	local result: { Types.LocText } = {}
	local function addGroup(group: string, lines: { string })
		for index in lines do
			table.insert(result, LocalizeLogic.text(LocalizeLogic.cutsceneLineKey(group, index)))
		end
	end
	if fxSkin == "Cat" then
		addGroup("cat", EliminationCutsceneLogic.CAT_LINES)
		return result
	end
	addGroup("common", EliminationCutsceneLogic.COMMON_LINES)
	local skinLines = if appearanceId then EliminationCutsceneLogic.SKIN_LINES[appearanceId] else nil
	if skinLines and appearanceId then
		for index in skinLines do
			table.insert(result, LocalizeLogic.text(LocalizeLogic.skinSpeechKey(appearanceId, index)))
		end
	end
	if variant == "ChefHand" then
		addGroup("final", EliminationCutsceneLogic.FINAL_LINES)
	end
	return result
end

-- pickLine과 같은 고르기 (rng를 똑같이 한 번 써요)
function EliminationCutsceneLogic.pickLineText(
	appearanceId: string?,
	variant: Variant,
	rng: Rng,
	fxSkin: FxSkin?
): Types.LocText
	local lines = EliminationCutsceneLogic.lineTextsFor(appearanceId, variant, fxSkin)
	return lines[rng:NextInteger(1, #lines)]
end

function EliminationCutsceneLogic.canStartWorld(activeCount: number): boolean
	return activeCount < EliminationCutsceneLogic.MAX_CONCURRENT
end

-- 박자 목록 (at 오름차순). duration이 3초가 아니면 비율대로 늘이고 줄여요.
-- 고양이면 기본 박자는 그대로 두고, 먹는 박자 바로 뒤에 CatMeow 하나만 끼워 넣어요.
function EliminationCutsceneLogic.timeline(variant: Variant, duration: number?, fxSkin: FxSkin?): { Beat }
	local scale = (duration or BASE_DURATION) / BASE_DURATION
	local beats: { Beat } = {}
	local meowAt: number? = nil
	for _, beat in TIMELINES[variant] do
		table.insert(beats, { at = beat.at * scale, cue = beat.cue })
		if fxSkin == "Cat" and meowAt == nil and beat.cue == CAT_MEOW_AFTER[variant] then
			meowAt = (beat.at + CAT_MEOW_DELAY) * scale
		end
	end
	local at = meowAt
	if at then
		local index = #beats + 1
		for i, beat in beats do
			if beat.at > at then
				index = i
				break
			end
		end
		table.insert(beats, index, { at = at, cue = "CatMeow" })
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
