--!strict
-- 순수 로직 테스트 실행기. 저장소 루트에서 `lune run tests`
-- tests/*.spec.luau를 모두 돌리고, 하나라도 실패하면 종료 코드 1로 끝나요.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("@self/lib/Test")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

local totalPassed, totalFailed = 0, 0
for _, name in specs do
	local spec = require(`@self/{string.gsub(name, "%.luau$", "")}`)
	local passed, failed = Test.run(name, spec)
	print(`{if failed == 0 then "ok  " else "FAIL"} {name} ({passed} passed, {failed} failed)`)
	totalPassed += passed
	totalFailed += failed
end

print(`\n{totalPassed} passed, {totalFailed} failed`)
if totalFailed > 0 or #specs == 0 then
	process.exit(1)
end
