--!strict
-- 클라이언트 문구의 유일한 출입구 (m5-26, GDD 11.8).
-- 문구는 src/shared/Localization/Strings.csv (Rojo → ReplicatedStorage.Shared.Localization.Strings) 한 곳.
--   Loc.init()            init.client.luau가 맨 먼저 불러요. 카탈로그를 읽고 번역기(GetTranslatorForPlayerAsync)를
--                         최대 3초 기다려요. 못 받으면 배경에서 1·2·4초 간격으로 3번 더 (그동안은 카탈로그 폴백).
--   Loc.t(key, args?)     번역기 FormatByKey → LocalizeLogic.choose 폴백 사슬
--   Loc.text(value)       서버에서 온 LocText (그냥 문자열이면 그대로)
--   도우미: number, place, mapName, mapRule, skinName, skinSpeech, tierName, offerName, offerBlurb, offerPerk,
--          fxName, seasonName, tokenName, titleName, titleFromName, date, rewardReason, language
-- 언어를 게임 중에 바꾸는 경우는 다루지 않아요 (Roblox가 다시 접속시켜요).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local Types = require(ReplicatedStorage.Shared.Types)

type LocText = Types.LocText

local Loc = {}

local INITIAL_WAIT = 3
local RETRY_DELAYS = { 1, 2, 4 }

local catalog: LocalizeLogic.Catalog = {}
local translator: Translator? = nil
local language = LocalizeLogic.SOURCE_LANGUAGE
local warned: { [string]: boolean } = {}
local initialized = false

local function warnOnce(id: string, message: string)
	if warned[id] then
		return
	end
	warned[id] = true
	warn(`[Loc] {message}`)
end

local function loadCatalog()
	local ok, err = pcall(function()
		local shared = ReplicatedStorage:WaitForChild("Shared")
		local folder = shared:WaitForChild("Localization", 5)
		local tableInstance = folder and folder:WaitForChild("Strings", 5)
		if tableInstance and tableInstance:IsA("LocalizationTable") then
			catalog = LocalizeLogic.buildCatalog(tableInstance:GetEntries() :: any)
		else
			error("Shared.Localization.Strings not found")
		end
	end)
	if not ok then
		warnOnce("catalog", `string catalog missing: {err}`)
	end
end

local function tryTranslator(): boolean
	local player = Players.LocalPlayer
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if ok and result then
		translator = result
		language = LocalizeLogic.languageOf(result.LocaleId)
		return true
	end
	return false
end

function Loc.init()
	if initialized then
		return
	end
	initialized = true
	language = LocalizeLogic.languageOf(Players.LocalPlayer.LocaleId)
	loadCatalog()

	local done = false
	task.spawn(function()
		if tryTranslator() then
			done = true
			return
		end
		done = true
		for _, delay in RETRY_DELAYS do
			task.wait(delay)
			if tryTranslator() then
				return
			end
		end
		warnOnce("translator", `no translator, using the built-in catalog ({language})`)
	end)
	local deadline = os.clock() + INITIAL_WAIT
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
end

-- 지금 언어 ("ko", "en", "de" …)
function Loc.language(): string
	return language
end

local function translate(key: string, args: LocalizeLogic.Args?, depth: number): string
	if depth > LocalizeLogic.MAX_DEPTH then
		return ""
	end
	local entry = catalog[key]
	if entry == nil then
		warnOnce(`key:{key}`, `missing key {key}`)
		return key
	end
	local prepared = LocalizeLogic.prepareArgs(args, function(inner: LocText): string
		return translate(inner.key, inner.args, depth + 1)
	end)
	local translated: string? = nil
	local failed = true
	local current = translator
	if current and language ~= LocalizeLogic.SOURCE_LANGUAGE then
		local ok, result = pcall(function()
			return current:FormatByKey(key, prepared or {})
		end)
		if ok and type(result) == "string" then
			translated = result
			failed = false
		end
	end
	return LocalizeLogic.choose({
		language = language,
		key = key,
		entry = entry,
		args = prepared,
		translated = translated,
		translatorError = failed,
	})
end

function Loc.t(key: string, args: LocalizeLogic.Args?): string
	return translate(key, args, 0)
end

-- 서버에서 온 값. LocText면 풀고, 그냥 문자열이면 그대로 (플레이스 버전이 잠깐 어긋날 때), 그 밖은 빈 문자열
function Loc.text(value: any): string
	if type(value) == "string" then
		return value
	end
	if LocalizeLogic.isLocText(value) then
		return translate(value.key, value.args, 0)
	end
	if type(value) == "table" and type(value.key) == "string" then
		warnOnce(`bad:{value.key}`, `bad LocText {value.key}`)
	end
	return ""
end

function Loc.number(n: number): string
	return LocalizeLogic.formatNumber(n)
end

-- 등수: 영어 "5th", 그 밖 "5" (한국어는 문구가 "{place}등")
function Loc.place(n: number): string
	return LocalizeLogic.ordinal(n, if language == LocalizeLogic.SOURCE_LANGUAGE then "ko" else "en")
end

function Loc.mapName(mapId: string): string
	return Loc.t(LocalizeLogic.mapNameKey(mapId))
end
function Loc.mapRule(mapId: string): string
	return Loc.t(LocalizeLogic.mapRuleKey(mapId))
end
function Loc.skinName(skinId: string): string
	return Loc.t(LocalizeLogic.skinNameKey(skinId))
end
function Loc.skinSpeech(skinId: string, index: number): string
	return Loc.t(LocalizeLogic.skinSpeechKey(skinId, index))
end
function Loc.tierName(tier: string): string
	return Loc.t(LocalizeLogic.tierKey(tier))
end
function Loc.offerName(offerId: string): string
	return Loc.t(LocalizeLogic.offerNameKey(offerId))
end
function Loc.offerBlurb(offerId: string): string
	return Loc.t(LocalizeLogic.offerBlurbKey(offerId))
end
function Loc.offerPerk(offerId: string, index: number): string
	return Loc.t(LocalizeLogic.offerPerkKey(offerId, index))
end
function Loc.fxName(fxId: string): string
	return Loc.t(LocalizeLogic.fxNameKey(fxId))
end
function Loc.seasonName(eventId: string): string
	return Loc.t(LocalizeLogic.seasonNameKey(eventId))
end
function Loc.tokenName(eventId: string): string
	return Loc.t(LocalizeLogic.seasonTokenKey(eventId))
end
function Loc.rewardReason(reason: string): string
	return Loc.t(LocalizeLogic.rewardReasonKey(reason))
end

-- 칭호 (승수 기준 Config.Titles)
function Loc.titleName(wins: number): string
	return Loc.t(LocalizeLogic.titleKey(wins))
end

-- 속성에 든 한국어 칭호 이름 → 그 언어 칭호. 모르는 이름은 그대로
function Loc.titleFromName(koName: string): string
	for _, title in Config.Titles do
		if title.name == koName then
			return Loc.titleName(title.wins)
		end
	end
	return koName
end

-- 방 이름: 기본 이름(nameIsDefault)이면 "{name}의 초밥집" / "{name}'s Sushi Bar", 아니면 쓴 이름 그대로
function Loc.roomName(name: string, nameIsDefault: boolean?): string
	if nameIsDefault then
		return Loc.t("room.defaultName", { name = name })
	end
	return name
end

-- UTC 날짜 "11월 5일" / "Nov 5"
function Loc.date(timestamp: number): string
	local parts = os.date("!*t", math.floor(timestamp))
	return Loc.t("date.monthDay", {
		month = LocalizeLogic.text(LocalizeLogic.monthKey(parts.month)),
		day = parts.day,
	})
end

return Loc
