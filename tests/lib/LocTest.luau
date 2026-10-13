--!strict
-- 테스트용 현지화 도우미 (m5-26): Strings.csv를 읽어 LocText를 한국어·영어 글씨로 풀어요.
--   LocTest.ko(loc) / LocTest.en(loc)   카탈로그만으로 (번역기 없음) — 화면 문구를 예전처럼 문자열로 비교할 때
--   LocTest.catalog / LocTest.rows / LocTest.has(key)

local fs = require("@lune/fs")

local RobloxRequire = require("./RobloxRequire")

local Shared = RobloxRequire.root("src/shared")
local LocalizeLogic = RobloxRequire.require(Shared.LocalizeLogic)

local LocTest = {}

LocTest.PATH = "src/shared/Localization/Strings.csv"
LocTest.text = fs.readFile(LocTest.PATH)
local rows, problems = LocalizeLogic.parseCsv(LocTest.text)
LocTest.rows = rows
LocTest.parseProblems = problems
LocTest.catalog = LocalizeLogic.buildCatalog(LocalizeLogic.entriesFromRows(rows))

function LocTest.has(key: string): boolean
	return LocTest.catalog[key] ~= nil
end

function LocTest.ko(loc: any): string
	if loc == nil then
		return ""
	end
	if type(loc) == "string" then
		return loc -- 이미 글씨 (예: 데이터 표의 원문)
	end
	return LocalizeLogic.render(LocTest.catalog, "ko", loc)
end

function LocTest.en(loc: any): string
	if loc == nil then
		return ""
	end
	if type(loc) == "string" then
		return loc -- 이미 글씨 (예: 데이터 표의 원문)
	end
	return LocalizeLogic.render(LocTest.catalog, "en", loc)
end

return LocTest
