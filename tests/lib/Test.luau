--!strict
-- 아주 작은 테스트 도구. spec 파일은 function(t: Test) 를 돌려주고 t.test로 케이스를 등록해요.

export type Test = {
	test: (name: string, fn: () -> ()) -> (),
	eq: (actual: any, expected: any, message: string?) -> (),
	ok: (condition: any, message: string?) -> (),
	throws: (fn: () -> (), message: string?) -> (),
}

local function show(value: any): string
	if type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, `{k}={show(v)}`)
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local Test = {}

-- spec 하나를 돌리고 (통과 수, 실패 수)를 돌려줘요.
function Test.run(specName: string, spec: (t: Test) -> ()): (number, number)
	local cases: { { name: string, fn: () -> () } } = {}
	local t: Test = {
		test = function(name, fn)
			table.insert(cases, { name = name, fn = fn })
		end,
		eq = function(actual, expected, message)
			if not deepEqual(actual, expected) then
				error(`{message or "values differ"}: expected {show(expected)}, got {show(actual)}`, 2)
			end
		end,
		ok = function(condition, message)
			if not condition then
				error(message or "expected truthy value", 2)
			end
		end,
		throws = function(fn, message)
			if pcall(fn) then
				error(message or "expected an error", 2)
			end
		end,
	}
	spec(t)

	local passed, failed = 0, 0
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
		else
			failed += 1
			print(`  FAIL {specName} > {case.name}\n       {err}`)
		end
	end
	return passed, failed
end

return Test
