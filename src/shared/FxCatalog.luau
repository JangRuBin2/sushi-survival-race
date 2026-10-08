--!strict
-- 연출 카탈로그 (m5-03). 탈락·우승 연출 id와 이름만 둬요 — 가격·상품 id는 Shared.Offers(m5-08), 모습은 m5-09.
-- 순수 로직이라 Roblox API를 쓰지 않아요 (tests/fx-catalog.spec.luau).
--   FxCatalog.get(id) -> Fx?
--   FxCatalog.bySlot(slot) -> { Fx }   order 순
--   FxCatalog.validate(list) -> (ok, problems)

export type Slot = "Elimination" | "Victory"
export type Fx = { id: string, slot: Slot, displayName: string, order: number }

local FxCatalog = {}

FxCatalog.SLOTS = { "Elimination", "Victory" } :: { Slot }

FxCatalog.LIST = {
	{ id = "cat-customer", slot = "Elimination", displayName = "고양이 손님", order = 1 },
	{ id = "fireworks", slot = "Victory", displayName = "불꽃놀이", order = 2 },
} :: { Fx }

function FxCatalog.get(id: string): Fx?
	for _, fx in FxCatalog.LIST do
		if fx.id == id then
			return fx
		end
	end
	return nil
end

function FxCatalog.isSlot(value: any): boolean
	return value == "Elimination" or value == "Victory"
end

function FxCatalog.bySlot(slot: Slot): { Fx }
	local list: { Fx } = {}
	for _, fx in FxCatalog.LIST do
		if fx.slot == slot then
			table.insert(list, fx)
		end
	end
	table.sort(list, function(a: Fx, b: Fx): boolean
		return a.order < b.order
	end)
	return list
end

function FxCatalog.validate(list: { any }): (boolean, { string })
	local problems: { string } = {}
	local ids: { [string]: boolean } = {}
	local orders: { [number]: boolean } = {}
	for index, fx in list do
		if type(fx) ~= "table" or type(fx.id) ~= "string" or fx.id == "" then
			table.insert(problems, `#{index}: id must be a non-empty string`)
			continue
		end
		local id = fx.id
		if ids[id] then
			table.insert(problems, `{id}: duplicate id`)
		end
		ids[id] = true
		if not FxCatalog.isSlot(fx.slot) then
			table.insert(problems, `{id}: slot must be Elimination or Victory`)
		end
		if type(fx.displayName) ~= "string" or fx.displayName == "" then
			table.insert(problems, `{id}: displayName must be a non-empty string`)
		end
		if type(fx.order) ~= "number" or fx.order % 1 ~= 0 then
			table.insert(problems, `{id}: order must be an integer`)
		elseif orders[fx.order] then
			table.insert(problems, `{id}: duplicate order {fx.order}`)
		else
			orders[fx.order] = true
		end
	end
	return #problems == 0, problems
end

return FxCatalog
