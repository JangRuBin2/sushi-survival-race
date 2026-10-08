--!strict
-- 로벅스 가격 캐시 (m5-03, 지역 가격 준비 — REFERENCE-roblox-monetization 8.4). 탈의실(m5-07)·상품 창(m5-08)이 써요.
--   PriceCache.product(productId, fallback) -> number   개발자 상품 가격 (GetProductInfoAsync, InfoType.Product).PriceInRobux
--   PriceCache.pass(passId, fallback) -> number         게임 패스 가격 (InfoType.GamePass)
--   PriceCache.changed:Connect(fn(kind, id, price)) -> 연결   값을 받아 오면 알림 (화면 다시 그리기). :Disconnect()로 해제
-- 처음 부르면 fallback(카탈로그 가격)을 돌려주고 백그라운드로 한 번만 받아 와서 캐시해요.
-- 실패하면 fallback을 그대로 쓰고 다시 시도하지 않아요. 가격은 표시용이에요 — 실제 결제 금액은 Roblox 결제 창이 정해요.

local MarketplaceService = game:GetService("MarketplaceService")

export type Kind = "Product" | "GamePass"
export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
type Listener = (kind: Kind, id: number, price: number) -> ()

local PriceCache = {}

local prices: { [string]: number } = {} -- "Product:123" → 받아 온 가격
local requested: { [string]: boolean } = {} -- 한 번 요청한 키 (성공·실패 상관없이 다시 안 함)
local listeners: { Listener } = {}

PriceCache.changed = {
	Connect = function(_self: any, fn: Listener): Connection
		table.insert(listeners, fn)
		local connection: Connection
		connection = {
			Connected = true,
			Disconnect = function(self: Connection)
				self.Connected = false
				local index = table.find(listeners, fn)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
		return connection
	end,
}

local function fire(kind: Kind, id: number, price: number)
	for _, fn in table.clone(listeners) do
		task.spawn(fn, kind, id, price)
	end
end

local function fetch(kind: Kind, id: number, key: string)
	local infoType = if kind == "Product" then Enum.InfoType.Product else Enum.InfoType.GamePass
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, infoType)
	end)
	local price = ok and type(info) == "table" and (info :: any).PriceInRobux
	if type(price) == "number" and price > 0 then
		prices[key] = price
		fire(kind, id, price)
	end
end

local function lookup(kind: Kind, id: number, fallback: number): number
	if type(id) ~= "number" or id <= 0 then
		return fallback
	end
	local key = `{kind}:{id}`
	local cached = prices[key]
	if cached then
		return cached
	end
	if not requested[key] then
		requested[key] = true
		task.spawn(fetch, kind, id, key)
	end
	return fallback
end

function PriceCache.product(productId: number, fallback: number): number
	return lookup("Product", productId, fallback)
end

function PriceCache.pass(passId: number, fallback: number): number
	return lookup("GamePass", passId, fallback)
end

return PriceCache
