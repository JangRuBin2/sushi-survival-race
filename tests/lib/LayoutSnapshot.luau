--!strict
-- 스킨 레이아웃 스냅숏 (m5-32 AC5): 모든 스킨(콘셉트 몸은 표정 4종 각각)의 SushiBody.layout을 키 순서가 정해진
-- 문자열로 만들어요. 숫자는 %.17g라 바이트 단위로 같으면 레이아웃이 같아요. tests/fixtures/m5-32-layout-snapshot.txt와 비교.

local LayoutSnapshot = {}

local KEYS = {
	"name",
	"size",
	"color",
	"material",
	"offset",
	"shape",
	"rotation",
	"effect",
	"effectColor",
	"transparency",
	"joint",
	"attach",
}

local function value(v: any): string
	local kind = type(v)
	if kind == "number" then
		return string.format("%.17g", v)
	elseif kind == "string" then
		return string.format("%q", v)
	elseif kind == "boolean" then
		return tostring(v)
	elseif kind == "table" then
		local parts = {}
		for _, item in v do
			table.insert(parts, value(item))
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	return "null"
end

function LayoutSnapshot.spec(spec: any): string
	local parts = {}
	for _, key in KEYS do
		if spec[key] ~= nil then
			table.insert(parts, `{key}={value(spec[key])}`)
		end
	end
	return table.concat(parts, " ")
end

-- entries: { { label, layout } } → 한 줄에 파츠 하나
function LayoutSnapshot.encode(entries: { { any } }): string
	local lines = {}
	for _, entry in entries do
		table.insert(lines, `# {entry[1]} ({#entry[2]})`)
		for _, spec in entry[2] do
			table.insert(lines, LayoutSnapshot.spec(spec))
		end
	end
	return table.concat(lines, "\n") .. "\n"
end

return LayoutSnapshot
