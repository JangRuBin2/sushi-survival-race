--!strict
-- m5-20 AC6: MapDecorTags는 Roblox API 없이 require만으로 동작하고, EyeBlink·Wobble 두 문자열 상수가
-- 서로 다르고 비어 있지 않아요 (lune에서 바로 테스트 가능).

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local MapDecorTags = RobloxRequire.require(Shared.maps.MapDecorTags)

return function(t: Test.Test)
	t.test("AC6: EyeBlink·Wobble은 비어 있지 않은 문자열이고 서로 달라요", function()
		t.eq(type(MapDecorTags.EyeBlink), "string")
		t.eq(type(MapDecorTags.Wobble), "string")
		t.ok(#MapDecorTags.EyeBlink > 0, "EyeBlink not empty")
		t.ok(#MapDecorTags.Wobble > 0, "Wobble not empty")
		t.ok(MapDecorTags.EyeBlink ~= MapDecorTags.Wobble, "tags must differ")
	end)
end
