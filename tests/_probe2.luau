local RobloxRequire = require("./lib/RobloxRequire")
local Shared = RobloxRequire.root("src/shared")
local PartMath = RobloxRequire.require(Shared.PartMath)
local function show(m)
	local rows = {}
	for i = 1, 3 do
		table.insert(rows, string.format("%.3f %.3f %.3f", m[i][1], m[i][2], m[i][3]))
	end
	return table.concat(rows, " | ")
end
local off, rot = PartMath.rotateAbout({ 0, 0, 0 }, { 180, 90, 0 }, { 0, 0, 0 }, { 0, -18, 0 })
print(table.concat(rot, ","))
local direct = PartMath.angles({ 0, -18, 0 })
local base = PartMath.angles({ 180, 90, 0 })
local f = PartMath.mul({ p = { 0, 0, 0 }, r = direct }, { p = { 0, 0, 0 }, r = base })
print("want", show(f.r))
print("got ", show(PartMath.angles(rot)))
