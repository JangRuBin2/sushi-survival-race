--!strict
-- spec 하나만 돌리기 (전체 `lune run tests`는 약 3분). 저장소 루트에서:
--   lune run tests/run-one m6-08-attack.spec
-- 이름은 tests/ 안의 파일 이름에서 .luau를 뺀 것. 커밋 전 최종 확인은 여전히 전체 실행이에요.
local process = require("@lune/process")
local Test = require("./lib/Test")

local name = process.args[1]
assert(type(name) == "string" and string.match(name, "%.spec$"), "usage: lune run tests/run-one <name>.spec")
local spec = require(`./{name}`) :: any
local passed, failed = Test.run(name, spec)
print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
