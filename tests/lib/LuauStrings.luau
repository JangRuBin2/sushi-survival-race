--!strict
-- Luau 소스에서 문자열 리터럴을 줄 번호와 함께 뽑는 작은 토크나이저 (m5-26 테스트용).
-- 주석(--, --[[ ]])은 건너뛰고, "…" '…' `…` [[…]] [=[…]=]를 리터럴로 돌려줘요.
-- 보간 문자열(`a {x} b`)은 {…} 안의 코드는 빼고 글자 부분만 하나의 리터럴로 모아요.

export type Literal = { line: number, text: string, quote: string }

local LuauStrings = {}

local function longBracketLevel(source: string, i: number): number?
	-- source[i] == "[" 일 때 [==[ 형태면 = 개수, 아니면 nil
	local eq = string.match(source, "^%[(=*)%[", i)
	if eq == nil then
		return nil
	end
	return #eq
end

function LuauStrings.literals(source: string): { Literal }
	local result: { Literal } = {}
	local i = 1
	local n = #source
	local line = 1
	local function countLines(from: number, to: number)
		for _ in string.gmatch(string.sub(source, from, to), "\n") do
			line += 1
		end
	end
	while i <= n do
		local c = string.sub(source, i, i)
		if c == "\n" then
			line += 1
			i += 1
		elseif c == "-" and string.sub(source, i + 1, i + 1) == "-" then
			-- 주석
			local level = if string.sub(source, i + 2, i + 2) == "[" then longBracketLevel(source, i + 2) else nil
			if level ~= nil then
				local close = "]" .. string.rep("=", level) .. "]"
				local _, e = string.find(source, close, i + 4, true)
				local stop = e or n
				countLines(i, stop)
				i = stop + 1
			else
				local e = string.find(source, "\n", i, true)
				i = e or (n + 1)
			end
		elseif c == "[" and longBracketLevel(source, i) ~= nil then
			local level = longBracketLevel(source, i) :: number
			local open = 2 + level
			local close = "]" .. string.rep("=", level) .. "]"
			local s, e = string.find(source, close, i + open, true)
			local stop = e or n
			local startLine = line
			table.insert(result, {
				line = startLine,
				text = string.sub(source, i + open, (s or n + 1) - 1),
				quote = "[[",
			})
			countLines(i, stop)
			i = stop + 1
		elseif c == '"' or c == "'" then
			local startLine = line
			local j = i + 1
			local parts = {}
			while j <= n do
				local d = string.sub(source, j, j)
				if d == "\\" then
					table.insert(parts, string.sub(source, j, j + 1))
					if string.sub(source, j + 1, j + 1) == "\n" then
						line += 1
					end
					j += 2
				elseif d == c or d == "\n" then
					break
				else
					table.insert(parts, d)
					j += 1
				end
			end
			table.insert(result, { line = startLine, text = table.concat(parts), quote = c })
			i = j + 1
		elseif c == "`" then
			local startLine = line
			local j = i + 1
			local parts = {}
			while j <= n do
				local d = string.sub(source, j, j)
				if d == "\\" then
					table.insert(parts, string.sub(source, j, j + 1))
					j += 2
				elseif d == "`" then
					break
				elseif d == "{" then
					-- 보간 식: 짝 맞는 } 까지 건너뛰어요 (식 안 문자열은 단순 처리)
					local depth = 1
					j += 1
					while j <= n and depth > 0 do
						local e = string.sub(source, j, j)
						if e == "{" then
							depth += 1
						elseif e == "}" then
							depth -= 1
						elseif e == "\n" then
							line += 1
						end
						j += 1
					end
					table.insert(parts, "{}")
				else
					if d == "\n" then
						line += 1
					end
					table.insert(parts, d)
					j += 1
				end
			end
			table.insert(result, { line = startLine, text = table.concat(parts), quote = "`" })
			i = j + 1
		else
			i += 1
		end
	end
	return result
end

-- 한글 음절·자모가 들어 있는지 (UTF-8: 가~힣 EA B0 80 ~ ED 9E A3, 자모 E3 84 B1 ~ E3 85 A3)
function LuauStrings.hasHangul(text: string): boolean
	for _, code in utf8.codes(text) do
		if
			(code >= 0xAC00 and code <= 0xD7A3)
			or (code >= 0x3131 and code <= 0x318E)
			or (code >= 0x1100 and code <= 0x11FF)
		then
			return true
		end
	end
	return false
end

-- 줄 번호 → 그 줄 소스
function LuauStrings.lines(source: string): { string }
	local result = {}
	for lineText in string.gmatch(source .. "\n", "([^\n]*)\n") do
		table.insert(result, lineText)
	end
	return result
end

return LuauStrings
