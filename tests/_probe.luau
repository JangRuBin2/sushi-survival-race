local RobloxRequire = require("./lib/RobloxRequire")
local LayoutCheck = require("../tools/render/LayoutCheck")
local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)

local ok, problems = Skins.validate(Skins.LIST)
print("validate", ok, table.concat(problems, "\n"))
local function ext(b)
	return string.format(
		"x %.2f..%.2f (%.2f) y %.2f..%.2f z %.2f..%.2f (%.2f)",
		b.min[1],
		b.max[1],
		b.max[1] - b.min[1],
		b.min[2],
		b.max[2],
		b.min[3],
		b.max[3],
		b.max[3] - b.min[3]
	)
end
print("salmon", ext(SushiBody.bounds(SushiBody.layout("concept-salmon"))))
local base = SushiBody.layout("fresh-mackerel", "Flustered")
for _, item in Anim.fishTestPoses() do
	local l = SushiBody.posed(base, Anim.fishMotion(item.pose))
	local fishOnly = {}
	local minY = math.huge
	for _, s in l do
		if string.sub(s.name, 1, 4) == "Fish" or string.sub(s.name, 1, 6) == "Splash" then
			table.insert(fishOnly, s)
			local lo = LayoutCheck.box(s)
			if string.sub(s.name, 1, 4) == "Fish" and not string.find(s.name, "Nori") then
				if lo[2] < minY then minY = lo[2]; print("  min", s.name, lo[2]) end
			end
		end
	end
	local topName, topY = "", -math.huge
	for _, s in l do
		local _, hi = LayoutCheck.box(s)
		if hi[2] > topY then
			topY, topName = hi[2], s.name
		end
	end
	print(
		item.name,
		topName,
		ext(SushiBody.bounds(l)),
		string.format("fishMinY %.2f", minY),
		"fl",
		table.concat(LayoutCheck.floating(l), ";"),
		"zf",
		#LayoutCheck.zFight(l)
	)
end
