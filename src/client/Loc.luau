--!strict
-- 클라이언트 문구의 유일한 출입구 (m5-26, GDD 11.8).
-- 문구는 src/shared/Localization/Strings.csv (Rojo → ReplicatedStorage.Shared.Localization.Strings) 한 곳.
--   Loc.init()            init.client.luau가 맨 먼저 불러요. 카탈로그를 읽고 번역기(GetTranslatorForPlayerAsync)를
--                         최대 3초 기다려요. 못 받으면 배경에서 1·2·4초 간격으로 3번 더 (그동안은 카탈로그 폴백).
--   Loc.t(key, args?)     번역기 FormatByKey → LocalizeLogic.choose 폴백 사슬
--   Loc.text(value)       서버에서 온 LocText (그냥 문자열이면 그대로)
--   Loc.tPlace(key, n)    등수가 든 문구 (영어만 서수 "5th", QA B3)
--   Loc.onChanged(fn)     번역기가 늦게 와서 글씨가 바뀔 때 (QA B4). 화면(PlayerGui) 글씨는 Loc이 직접 다시 써요
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
local initialWaitOver = false
-- 번역기가 오기 전에 폴백으로 그린 글씨 (ko·en 밖 언어만, QA B4). 번역기가 늦게 오면 이걸로 다시 써요.
local lateMap = LocalizeLogic.newLateMap()
local changedHandlers: { () -> () } = {}

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

local refreshLate: () -> ()

local function tryTranslator(): boolean
	local player = Players.LocalPlayer
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if ok and result then
		translator = result
		language = LocalizeLogic.languageOf(result.LocaleId)
		if initialWaitOver then
			refreshLate()
		end
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
	initialWaitOver = true
	if translator ~= nil then
		lateMap = LocalizeLogic.newLateMap() -- 이미 왔어요 (기다리는 동안 그린 글씨는 없어요)
	end
end

-- 언어 결과가 바뀌었을 때 (번역기가 늦게 옴, QA B4). 월드 글씨(단상·와사비)처럼 화면 밖 글씨를 만든 쪽이 구독해요.
function Loc.onChanged(handler: () -> ())
	table.insert(changedHandlers, handler)
end

-- 지금 언어 ("ko", "en", "de" …)
function Loc.language(): string
	return language
end

local function translate(
	key: string,
	args: LocalizeLogic.Args?,
	depth: number,
	englishArgs: { [string]: string }?
): string
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
		englishArgs = englishArgs,
	})
end

-- 맨 바깥 문구 하나: 번역기가 아직 없고 늦게 와서 바뀔 수 있는 언어면 다시 쓰기 목록에 적어요 (QA B4)
local function top(key: string, args: LocalizeLogic.Args?, englishArgs: { [string]: string }?): string
	local shown = translate(key, args, 0, englishArgs)
	if translator == nil and LocalizeLogic.needsLateRefresh(language) then
		LocalizeLogic.recordLate(lateMap, shown, { key = key, args = args, englishArgs = englishArgs })
	end
	return shown
end

function Loc.t(key: string, args: LocalizeLogic.Args?): string
	return top(key, args, nil)
end

-- 등수가 든 문구 (QA B3): 영어는 "5th", 한국어·그 밖 언어는 숫자만. 그 밖 언어가 카탈로그 영어로 폴백하면 다시 "5th".
--   Loc.tPlace("hud.result.out", 5)  → "🥢 탈락했어요… (5등)" / "🥢 You're out! (5th place)"
function Loc.tPlace(key: string, place: number, args: LocalizeLogic.Args?): string
	local all: LocalizeLogic.Args = {}
	if args then
		for name, value in args do
			all[name] = value
		end
	end
	all.place = LocalizeLogic.placeValue(place, language)
	local englishArgs: { [string]: string }? = nil
	if language ~= "en" and language ~= LocalizeLogic.SOURCE_LANGUAGE then
		local english: LocalizeLogic.Args = table.clone(all)
		english.place = LocalizeLogic.ordinal(place, "en")
		englishArgs = LocalizeLogic.prepareArgs(english, function(inner: LocText): string
			return translate(inner.key, inner.args, 1)
		end)
	end
	return top(key, all, englishArgs)
end

-- 늦게 온 번역기 (QA B4): 폴백으로 그린 화면 글씨를 그대로 찾아 다시 쓰고, 구독한 쪽(월드 글씨)에 알려요.
-- 이름처럼 사람이 쓴 글씨는 목록에 없어서 건드리지 않아요. 두 문구를 이어 붙인 글씨는 다음에 다시 그릴 때 바뀌어요.
refreshLate = function()
	local map = lateMap
	lateMap = LocalizeLogic.newLateMap()
	if not LocalizeLogic.needsLateRefresh(language) or map.count == 0 then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, item in playerGui:GetDescendants() do
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				local entry = LocalizeLogic.lateEntryFor(map, item.Text)
				if entry then
					item.Text = translate(entry.key, entry.args, 0, entry.englishArgs)
				end
			end
		end
	end
	for _, handler in changedHandlers do
		task.spawn(function()
			local ok, err = pcall(handler)
			if not ok then
				warn(`[Loc] changed handler failed: {err}`)
			end
		end)
	end
end

-- 서버에서 온 값. LocText면 풀고, 그냥 문자열이면 그대로 (플레이스 버전이 잠깐 어긋날 때), 그 밖은 빈 문자열
function Loc.text(value: any): string
	if type(value) == "string" then
		return value
	end
	if LocalizeLogic.isLocText(value) then
		return top(value.key, value.args, nil)
	end
	if type(value) == "table" and type(value.key) == "string" then
		warnOnce(`bad:{value.key}`, `bad LocText {value.key}`)
	end
	return ""
end

function Loc.number(n: number): string
	return LocalizeLogic.formatNumber(n)
end

-- 등수 값만: 영어 "5th", 그 밖 "5" (QA B3). 문구 안에 넣을 때는 Loc.tPlace (폴백 영어도 서수로).
function Loc.place(n: number): string
	return LocalizeLogic.placeValue(n, language)
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
function Loc.drawGradeName(grade: string): string
	return Loc.t(LocalizeLogic.drawGradeKey(grade))
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
