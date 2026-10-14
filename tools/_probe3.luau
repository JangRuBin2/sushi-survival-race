local Shims = require("./render/Shims")
local Shared = Shims.root("src/shared")
local SushiBody = Shims.require(Shared.SushiBody)
local m = SushiBody.build("fresh-mackerel")
for _, n in { "FishFinL", "FishDorsal", "FishTailTop", "FishRoot" } do
	local p = m:FindFirstChild(n)
	print(n, p and p.ClassName, p and p.CFrame, p and p.Size, p and p.Transparency)
end
