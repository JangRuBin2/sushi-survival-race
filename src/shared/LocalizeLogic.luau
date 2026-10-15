--!strict
-- 현지화 순수 로직 (m5-26). Roblox API 없이 lune으로 테스트해요.
-- 문구는 src/shared/Localization/Strings.csv 한 곳 (열 Key,Source,Context,Example,en). Source = 한국어 원문.
--   isValidKey(key)                 키 형식 (점으로 나눈 영어 id)
--   placeholders(text)              {이름} 자리표시자 목록 (이름순, 중복 없음)
--   checkRow(row)                   CSV 행 문제 목록 (빈 Source·en, 자리표시자 불일치, 괄호 짝, Example)
--   parseCsv(text)                  CSV → 행 목록 + 문제 목록 (테스트·도구 전용, 실행 중에는 GetEntries)
--   entriesFromRows(rows)           parseCsv 행 → GetEntries 모양
--   buildCatalog(entries)           LocalizationTable:GetEntries() 모양 → 키 → { ko, en }
--   languageOf(localeId)            "en-us" → "en", 빈 값 → "ko"
--   format(template, args, resolve) {이름}을 바꿔요 (없는 인자는 빈 문자열 + false)
--   render(catalog, language, loc)  번역기 없이 카탈로그만으로 (서버 Kick, 중첩 인자, 폴백)
--   prepareArgs(args, resolve)      FormatByKey에 넘길 문자열 인자 (숫자 1,234, 중첩 LocText 풀기)
--   choose(input)                   번역기 결과와 카탈로그 중 보여 줄 글씨 (폴백 사슬, 스펙 3절 표)
--   formatNumber(n) / ordinal(n, language) / placeValue(n, language) (영어만 서수)
--   needsLateRefresh(language) / newLateMap / recordLate / lateEntryFor   늦게 온 번역기로 다시 쓰기 (QA B4)
--   isLocText(value) / text(key, args)
--   동적 키: mapNameKey, mapRuleKey, skinNameKey, skinSpeechKey, tierKey, offerNameKey, offerBlurbKey,
--            offerPerkKey, fxNameKey, seasonNameKey, seasonTokenKey, titleKey, rewardReasonKey, monthKey, cutsceneLineKey

local Types = require(script.Parent.Types)

export type LocText = Types.LocText
export type LocArg = string | number | LocText
export type Args = { [string]: LocArg }

-- CSV 한 행 (머리줄 이름 → 칸)
export type Row = { [string]: string }

-- LocalizationTable:GetEntries() 한 항목
export type Entry = {
	Key: string,
	Source: string,
	Context: string?,
	Example: string?,
	Values: { [string]: string }?,
}

export type CatalogEntry = { ko: string, en: string? }
export type Catalog = { [string]: CatalogEntry }

export type ChooseInput = {
	language: string,
	key: string,
	entry: CatalogEntry?, -- 카탈로그 행 (없으면 키 그대로)
	args: { [string]: string }?, -- prepareArgs 결과
	translated: string?, -- 번역기 FormatByKey 결과
	translatorError: boolean?, -- 번역기가 없거나 FormatByKey가 오류
	englishArgs: { [string]: string }?, -- 카탈로그 en으로 폴백할 때 쓸 인자 (영어 서수 "5th" 등, 없으면 args)
}

local LocalizeLogic = {}

LocalizeLogic.HEADER = { "Key", "Source", "Context", "Example", "en" }
LocalizeLogic.SOURCE_LANGUAGE = "ko"
LocalizeLogic.MAX_ARGS = 20
LocalizeLogic.MAX_ARG_LENGTH = 200
LocalizeLogic.MAX_DEPTH = 2 -- 인자 안의 LocText는 2단계까지 풀어요

LocalizeLogic.AREAS = {
	"common",
	"lobby",
	"room",
	"hud",
	"spectate",
	"shop",
	"offer",
	"receipt",
	"code",
	"coin",
	"reward",
	"notice",
	"place",
	"intro",
	"cutscene",
	"input",
	"sfx",
	"date",
	"map",
	"skin",
	"tier",
	"fx",
	"season",
	"title",
}

local PLACEHOLDER = "{([A-Za-z][A-Za-z0-9]*)}"

function LocalizeLogic.isValidKey(key: any): boolean
	if type(key) ~= "string" or #key > 100 then
		return false
	end
	local area, rest = string.match(key, "^([a-z][a-z0-9]*)(%..+)$")
	if area == nil or rest == nil then
		return false
	end
	-- (\.[A-Za-z0-9][A-Za-z0-9_-]*)+
	local pos = 1
	while pos <= #rest do
		local s, e = string.find(rest, "^%.[A-Za-z0-9][A-Za-z0-9_%-]*", pos)
		if s == nil or e == nil then
			return false
		end
		pos = e + 1
	end
	return true
end

function LocalizeLogic.placeholders(text: string): { string }
	local seen: { [string]: boolean } = {}
	local result = {}
	for name in string.gmatch(text, PLACEHOLDER) do
		if not seen[name] then
			seen[name] = true
			table.insert(result, name)
		end
	end
	table.sort(result)
	return result
end

-- 올바른 자리표시자를 빼고도 { 나 }가 남으면 짝이 안 맞아요
local function bracesBalanced(text: string): boolean
	local stripped = string.gsub(text, PLACEHOLDER, "")
	return string.find(stripped, "[{}]") == nil
end

local function hasPlaceholder(text: string): boolean
	return string.find(text, PLACEHOLDER) ~= nil
end

function LocalizeLogic.checkRow(row: Row): { string }
	local problems = {}
	local key = row.Key or ""
	local function add(message: string)
		table.insert(problems, `{key}: {message}`)
	end
	if not LocalizeLogic.isValidKey(key) then
		add("bad key")
	end
	local source = row.Source or ""
	local en = row.en or ""
	if source == "" then
		add("empty Source")
	end
	if en == "" then
		add("empty en")
	end
	if not bracesBalanced(source) then
		add("unbalanced braces in Source")
	end
	if not bracesBalanced(en) then
		add("unbalanced braces in en")
	end
	local a = table.concat(LocalizeLogic.placeholders(source), ",")
	local b = table.concat(LocalizeLogic.placeholders(en), ",")
	if a ~= b then
		add(`placeholders differ (Source {a} / en {b})`)
	end
	if a ~= "" and (row.Example or "") == "" then
		add("placeholders need Example")
	end
	return problems
end

-- CSV (RFC 4180: 따옴표 칸 안의 쉼표·줄바꿈·"" 처리). 첫 줄은 머리줄.
function LocalizeLogic.parseCsv(text: string): ({ Row }, { string })
	local problems = {}
	if string.sub(text, 1, 3) == "\239\187\191" then
		text = string.sub(text, 4)
	end
	local records: { { string } } = {}
	local record: { string } = {}
	local field: { string } = {}
	local i = 1
	local n = #text
	local inQuotes = false
	local fieldQuoted = false
	local function endField()
		table.insert(record, table.concat(field))
		field = {}
		fieldQuoted = false
	end
	local function endRecord()
		endField()
		table.insert(records, record)
		record = {}
	end
	while i <= n do
		local c = string.sub(text, i, i)
		if inQuotes then
			if c == '"' then
				if string.sub(text, i + 1, i + 1) == '"' then
					table.insert(field, '"')
					i += 1
				else
					inQuotes = false
				end
			else
				table.insert(field, c)
			end
		elseif c == '"' then
			if #field > 0 or fieldQuoted then
				table.insert(problems, `stray quote in record {#records + 1}`)
			end
			inQuotes = true
			fieldQuoted = true
		elseif c == "," then
			endField()
		elseif c == "\r" then
			if string.sub(text, i + 1, i + 1) == "\n" then
				i += 1
			end
			endRecord()
		elseif c == "\n" then
			endRecord()
		else
			table.insert(field, c)
		end
		i += 1
	end
	if inQuotes then
		table.insert(problems, "unterminated quote")
	end
	if #field > 0 or #record > 0 or fieldQuoted then
		endRecord()
	end

	local rows: { Row } = {}
	local header = records[1]
	if header == nil then
		table.insert(problems, "empty file")
		return rows, problems
	end
	for index = 2, #records do
		local values = records[index]
		if #values == 1 and values[1] == "" then
			continue -- 빈 줄
		end
		if #values ~= #header then
			table.insert(problems, `record {index}: {#values} fields, expected {#header}`)
		end
		local row: Row = {}
		for column, name in header do
			row[name] = values[column] or ""
		end
		table.insert(rows, row)
	end
	return rows, problems
end

function LocalizeLogic.headerOf(text: string): string
	if string.sub(text, 1, 3) == "\239\187\191" then
		text = string.sub(text, 4)
	end
	return (string.match(text, "^([^\r\n]*)")) or ""
end

function LocalizeLogic.entriesFromRows(rows: { Row }): { Entry }
	local entries = {}
	for _, row in rows do
		local values: { [string]: string } = {}
		for name, value in row do
			if name ~= "Key" and name ~= "Source" and name ~= "Context" and name ~= "Example" and value ~= "" then
				values[name] = value
			end
		end
		table.insert(entries, {
			Key = row.Key,
			Source = row.Source,
			Context = row.Context,
			Example = row.Example,
			Values = values,
		})
	end
	return entries
end

function LocalizeLogic.buildCatalog(entries: { Entry }): Catalog
	local catalog: Catalog = {}
	for _, entry in entries do
		if type(entry.Key) == "string" and entry.Key ~= "" and type(entry.Source) == "string" then
			local values: { [string]: string } = entry.Values or {}
			local en: string? = values["en"] or values["en-us"]
			catalog[entry.Key] = { ko = entry.Source, en = if en ~= nil and en ~= "" then en else nil }
		end
	end
	return catalog
end

function LocalizeLogic.languageOf(localeId: string?): string
	if type(localeId) ~= "string" or localeId == "" then
		return LocalizeLogic.SOURCE_LANGUAGE
	end
	local language = string.match(string.lower(localeId), "^([a-z]+)")
	return language or LocalizeLogic.SOURCE_LANGUAGE
end

function LocalizeLogic.formatNumber(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local negative = n < 0
	local whole = math.floor(math.abs(n) + 0.5)
	local digits = string.format("%d", whole)
	local parts = {}
	local head = #digits % 3
	if head > 0 then
		table.insert(parts, string.sub(digits, 1, head))
	end
	for i = head + 1, #digits, 3 do
		table.insert(parts, string.sub(digits, i, i + 2))
	end
	local text = table.concat(parts, ",")
	if negative and whole ~= 0 then
		return "-" .. text
	end
	return text
end

function LocalizeLogic.ordinal(n: number, language: string): string
	local whole = math.floor(n + 0.5)
	local text = tostring(whole)
	if language ~= "en" then
		return text
	end
	local lastTwo = whole % 100
	local last = whole % 10
	local suffix = "th"
	if lastTwo < 11 or lastTwo > 13 then
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return text .. suffix
end

local function isArgsTable(args: any, depth: number): boolean
	if args == nil then
		return true
	end
	if type(args) ~= "table" or getmetatable(args) ~= nil then
		return false
	end
	local count = 0
	for name, value in args do
		count += 1
		if count > LocalizeLogic.MAX_ARGS then
			return false
		end
		if type(name) ~= "string" or not string.match(name, "^[A-Za-z][A-Za-z0-9]*$") then
			return false
		end
		local kind = type(value)
		if kind == "string" then
			if #value > LocalizeLogic.MAX_ARG_LENGTH then
				return false
			end
		elseif kind == "number" then
			if value ~= value or value == math.huge or value == -math.huge then
				return false
			end
		elseif kind == "table" then
			if depth >= LocalizeLogic.MAX_DEPTH then
				return false
			end
			if not LocalizeLogic.isLocText(value, depth + 1) then
				return false
			end
		else
			return false
		end
	end
	return true
end

-- 서버에서 온 값 검사. depth는 내부용(중첩 깊이).
function LocalizeLogic.isLocText(value: any, depth: number?): boolean
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		return false
	end
	for name in value do
		if name ~= "key" and name ~= "args" then
			return false
		end
	end
	if not LocalizeLogic.isValidKey(value.key) then
		return false
	end
	return isArgsTable(value.args, depth or 0)
end

function LocalizeLogic.text(key: string, args: Args?): LocText
	return { key = key, args = args }
end

-- {이름}을 바꿔요. 없는 인자는 빈 문자열이고 둘째 값이 false. 숫자는 formatNumber,
-- LocText 인자는 resolve로 풀어요(없으면 빈 문자열).
function LocalizeLogic.format(template: string, args: Args?, resolve: ((LocText) -> string)?): (string, boolean)
	local complete = true
	local result = string.gsub(template, PLACEHOLDER, function(name: string): string
		local value = if args then args[name] else nil
		if value == nil then
			complete = false
			return ""
		elseif type(value) == "number" then
			return LocalizeLogic.formatNumber(value)
		elseif type(value) == "string" then
			return value
		elseif type(value) == "table" then
			return if resolve then resolve(value :: LocText) else ""
		end
		complete = false
		return ""
	end)
	return result, complete
end

-- 번역기 없이 카탈로그만으로 문구를 만들어요. ko는 Source, 그 밖은 en(없으면 Source).
-- 카탈로그에 없는 키는 키 그대로. depth가 MAX_DEPTH를 넘으면 빈 문자열.
function LocalizeLogic.render(catalog: Catalog, language: string, loc: LocText, depth: number?): string
	local level = depth or 0
	if level > LocalizeLogic.MAX_DEPTH then
		return ""
	end
	local entry = catalog[loc.key]
	if entry == nil then
		return loc.key
	end
	local template = if language == LocalizeLogic.SOURCE_LANGUAGE then entry.ko else (entry.en or entry.ko)
	local text = LocalizeLogic.format(template, loc.args, function(inner: LocText): string
		return LocalizeLogic.render(catalog, language, inner, level + 1)
	end)
	return text
end

-- FormatByKey에 넘길 인자: 숫자는 1,234, LocText는 resolve(depth)로 풀어 문자열만 남겨요.
function LocalizeLogic.prepareArgs(args: Args?, resolve: (LocText) -> string): { [string]: string }?
	if args == nil then
		return nil
	end
	local result: { [string]: string } = {}
	for name, value in args do
		if type(value) == "number" then
			result[name] = LocalizeLogic.formatNumber(value)
		elseif type(value) == "string" then
			result[name] = value
		elseif type(value) == "table" then
			result[name] = resolve(value :: LocText)
		end
	end
	return result
end

local function usable(translated: string?, translatorError: boolean?): boolean
	return not translatorError
		and type(translated) == "string"
		and translated ~= ""
		and not hasPlaceholder(translated)
		and bracesBalanced(translated)
end

-- 보여 줄 글씨 (스펙 3절 폴백 사슬).
--   ko → 카탈로그 Source
--   en → 번역기 결과 (오류·없음·{…} 남음·한국어 원문과 같으면 카탈로그 en → Source)
--   그 밖 → 번역기 결과가 한국어 원문과 다를 때만 (자동 번역), 아니면 카탈로그 en → Source
--   카탈로그에 없는 키 → 키 그대로 (경고는 호출한 쪽이 한 번)
function LocalizeLogic.choose(input: ChooseInput): string
	local entry = input.entry
	if entry == nil then
		return input.key
	end
	local args = input.args :: Args?
	local korean = LocalizeLogic.format(entry.ko, args)
	if input.language == LocalizeLogic.SOURCE_LANGUAGE then
		return korean
	end
	if usable(input.translated, input.translatorError) and input.translated ~= korean then
		return input.translated :: string
	end
	if entry.en then
		return (LocalizeLogic.format(entry.en, (input.englishArgs or args) :: Args?))
	end
	return korean
end

-- 등수 인자 (QA B3): 영어만 서수("5th"), 한국어·그 밖 언어는 숫자만("5" — 문구가 "{place}등"·자동 번역).
function LocalizeLogic.placeValue(n: number, language: string): string
	return LocalizeLogic.ordinal(n, language)
end

-- 번역기가 늦게 왔을 때 이미 그린 글씨를 다시 써야 하는 언어인지 (QA B4).
-- ko는 번역기를 안 쓰고, en은 카탈로그 en = 클라우드 en이라 바뀌지 않아요. 그 밖 언어만.
function LocalizeLogic.needsLateRefresh(language: string): boolean
	return language ~= LocalizeLogic.SOURCE_LANGUAGE and language ~= "en"
end

-- 늦은 번역기용 다시 쓰기 목록 (QA B4, 순수). 번역기가 오기 전에 폴백으로 만든 글씨 → 그 키·인자.
-- 같은 글씨가 다른 키에서 나오면 처음 것을 둬요(다시 써도 같은 뜻). 최대 limit개.
export type LateEntry = { key: string, args: Args?, englishArgs: { [string]: string }? }
export type LateMap = { entries: { [string]: LateEntry }, count: number, limit: number }

function LocalizeLogic.newLateMap(limit: number?): LateMap
	return { entries = {}, count = 0, limit = limit or 2000 }
end

function LocalizeLogic.recordLate(map: LateMap, shown: string, entry: LateEntry)
	if shown == "" or map.entries[shown] ~= nil or map.count >= map.limit then
		return
	end
	map.entries[shown] = entry
	map.count += 1
end

-- 지금 보이는 글씨가 폴백으로 만든 글씨면 그 키·인자, 아니면 nil (플레이어가 쓴 이름 등은 기록에 없어요)
function LocalizeLogic.lateEntryFor(map: LateMap, shown: string): LateEntry?
	return map.entries[shown]
end

-- 동적 키 (스펙 2절). 코드에서 동적 키는 이 함수들로만 만들어요.
function LocalizeLogic.mapNameKey(mapId: string): string
	return `map.{mapId}.name`
end
function LocalizeLogic.mapRuleKey(mapId: string): string
	return `map.{mapId}.rule`
end
function LocalizeLogic.skinNameKey(skinId: string): string
	return `skin.{skinId}.name`
end
function LocalizeLogic.skinSpeechKey(skinId: string, index: number): string
	return `skin.{skinId}.speech.{index}`
end
function LocalizeLogic.tierKey(tier: string): string
	return `tier.{tier}`
end
-- 🎫 뽑기 등급 이름 (m5-31 Skins.DRAW_GRADE_INFO — 상점 등급 tier.*와 다른 말이에요)
function LocalizeLogic.drawGradeKey(grade: string): string
	return `shop.drawGrade.{grade}`
end
function LocalizeLogic.offerNameKey(offerId: string): string
	return `offer.{offerId}.name`
end
function LocalizeLogic.offerBlurbKey(offerId: string): string
	return `offer.{offerId}.blurb`
end
function LocalizeLogic.offerPerkKey(offerId: string, index: number): string
	return `offer.{offerId}.perk.{index}`
end
function LocalizeLogic.fxNameKey(fxId: string): string
	return `fx.{fxId}.name`
end
function LocalizeLogic.seasonNameKey(eventId: string): string
	return `season.{eventId}.name`
end
function LocalizeLogic.seasonTokenKey(eventId: string): string
	return `season.{eventId}.token`
end
function LocalizeLogic.titleKey(wins: number): string
	return `title.w{wins}`
end
function LocalizeLogic.rewardReasonKey(reason: string): string
	return `reward.reason.{reason}`
end
function LocalizeLogic.monthKey(month: number): string
	return `date.month.{month}`
end
function LocalizeLogic.cutsceneLineKey(group: string, index: number): string
	return `cutscene.line.{group}.{index}`
end

-- 동적 키 모양 (AC4: CSV 키가 코드에 없으면 이 모양 중 하나여야 해요)
LocalizeLogic.DYNAMIC_KEY_PATTERNS = {
	"^map%.[%w%-]+%.name$",
	"^map%.[%w%-]+%.rule$",
	"^skin%.[%w%-]+%.name$",
	"^skin%.[%w%-]+%.speech%.%d+$",
	"^tier%.%w+$",
	"^shop%.drawGrade%.%w+$",
	"^offer%.[%w%-]+%.name$",
	"^offer%.[%w%-]+%.blurb$",
	"^offer%.[%w%-]+%.perk%.%d+$",
	"^fx%.[%w%-]+%.name$",
	"^season%.[%w%-]+%.name$",
	"^season%.[%w%-]+%.token$",
	"^title%.w%d+$",
	"^reward%.reason%.%w+$",
	"^date%.month%.%d+$",
	"^cutscene%.line%.%w+%.%d+$",
}

function LocalizeLogic.isDynamicKey(key: string): boolean
	for _, pattern in LocalizeLogic.DYNAMIC_KEY_PATTERNS do
		if string.match(key, pattern) then
			return true
		end
	end
	return false
end

return LocalizeLogic
