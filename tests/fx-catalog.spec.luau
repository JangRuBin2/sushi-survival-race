--!strict
-- m5-03 연출 카탈로그 (Shared.FxCatalog)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local FxCatalog = RobloxRequire.require(Shared.FxCatalog)

return function(t: Test.Test)
	t.test("AC7: validate 통과, 연출 2개가 스펙 표와 같아요", function()
		local ok, problems = FxCatalog.validate(FxCatalog.LIST)
		t.ok(ok, table.concat(problems, "; "))
		t.eq(#FxCatalog.LIST, 2)
		t.eq(
			FxCatalog.get("cat-customer"),
			{ id = "cat-customer", slot = "Elimination", displayName = "고양이 손님", order = 1 }
		)
		t.eq(
			FxCatalog.get("fireworks"),
			{ id = "fireworks", slot = "Victory", displayName = "불꽃놀이", order = 2 }
		)
		t.eq(FxCatalog.get("nope"), nil)
	end)

	t.test("AC7: bySlot", function()
		local elimination = FxCatalog.bySlot("Elimination")
		t.eq(#elimination, 1)
		t.eq(elimination[1].id, "cat-customer")
		local victory = FxCatalog.bySlot("Victory")
		t.eq(#victory, 1)
		t.eq(victory[1].id, "fireworks")
	end)

	t.test("isSlot", function()
		t.ok(FxCatalog.isSlot("Elimination"))
		t.ok(FxCatalog.isSlot("Victory"))
		t.ok(not FxCatalog.isSlot("Win"))
		t.ok(not FxCatalog.isSlot(nil))
	end)

	t.test("validate: id 겹침, 모르는 slot, 이름 없음, order 겹침을 잡아요", function()
		local cases = {
			{
				{ id = "a", slot = "Victory", displayName = "A", order = 1 },
				{ id = "a", slot = "Victory", displayName = "B", order = 2 },
			},
			{ { id = "a", slot = "Win", displayName = "A", order = 1 } },
			{ { id = "a", slot = "Victory", displayName = "", order = 1 } },
			{
				{ id = "a", slot = "Victory", displayName = "A", order = 1 },
				{ id = "b", slot = "Victory", displayName = "B", order = 1 },
			},
			{ { id = "a", slot = "Victory", displayName = "A", order = 1.5 } },
		}
		for i, list in cases do
			local ok = FxCatalog.validate(list)
			t.eq(ok, false, `case {i}`)
		end
	end)
end
