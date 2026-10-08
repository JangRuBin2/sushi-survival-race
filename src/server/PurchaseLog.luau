--!strict
-- 구매 기록 (m4-14, GDD 13 "구매 기록 별도 저장"). 결제 하나 = 한 줄, 프로필과 따로 저장해요.
-- 저장소 Config.Shop.PurchaseLogStore ("Purchases_v1"), 키 = PurchaseId, 값 = ReceiptLogic.Record
-- { userId, productId, skinId, at }. 메타데이터에 userId를 달아요 (개인정보 삭제 요청 때 찾기 쉽게).
--
--   PurchaseLog.init()
--   PurchaseLog.lookup(purchaseId) -> boolean?          있으면 true, 없으면 false, 읽지 못하면 nil (yield)
--   PurchaseLog.record(purchaseId, record) -> boolean   쓰고 성공 여부. 이미 있으면 덮어쓰지 않고 true (yield)
-- Studio: DataService와 같은 기준 — Config.DEBUG.persistDataInStudio가 false면 메모리만, true인데 요청이 실패하면
-- 경고 한 줄 + 메모리. 실제 서버에서는 실패를 그대로 돌려줘요 (ProcessReceipt가 NotProcessedYet → 나중에 다시).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ReceiptLogic = require(ReplicatedStorage.Shared.ReceiptLogic)

local PurchaseLog = {}

local MAX_ATTEMPTS = 3
local RETRY_DELAY = 1

local store: DataStore? = nil
local studio = false
local memory: { [string]: ReceiptLogic.Record } = {}

local function useMemory(reason: string)
	if store ~= nil then
		warn(`[PurchaseLog] DataStore unavailable in Studio, using memory only: {reason}`)
	end
	store = nil
end

-- 요청 하나를 몇 번까지 다시 해요. 성공하면 (true, 결과)
local function request<T>(what: string, fn: (DataStore) -> T): (boolean, T?)
	for attempt = 1, MAX_ATTEMPTS do
		local dataStore = store
		if dataStore == nil then
			return false, nil
		end
		local ok, result = pcall(fn, dataStore)
		if ok then
			return true, result
		end
		if studio then
			useMemory(tostring(result))
			return false, nil
		end
		warn(`[PurchaseLog] {what} failed (attempt {attempt}/{MAX_ATTEMPTS}): {result}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end
	return false, nil
end

function PurchaseLog.init()
	studio = RunService:IsStudio()
	if studio and not Config.DEBUG.persistDataInStudio then
		return -- Studio 기본: 메모리만
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Shop.PurchaseLogStore)
	end)
	if ok then
		store = result
	elseif studio then
		warn(`[PurchaseLog] DataStore unavailable in Studio, using memory only: {result}`)
	else
		warn(`[PurchaseLog] could not open DataStore, robux purchases will wait until it works: {result}`)
	end
end

local function isMemory(): boolean
	return store == nil and studio
end

function PurchaseLog.lookup(purchaseId: string): boolean?
	if isMemory() then
		return memory[purchaseId] ~= nil
	end
	local ok, value = request(`lookup {purchaseId}`, function(dataStore: DataStore): unknown
		return (dataStore:GetAsync(purchaseId))
	end)
	if not ok then
		if isMemory() then
			return memory[purchaseId] ~= nil -- 방금 Studio에서 메모리로 바뀜
		end
		return nil
	end
	return value ~= nil
end

function PurchaseLog.record(purchaseId: string, record: ReceiptLogic.Record): boolean
	if isMemory() then
		if memory[purchaseId] == nil then
			memory[purchaseId] = table.clone(record)
		end
		return true
	end
	local ok = request(`record {purchaseId}`, function(dataStore: DataStore): boolean
		dataStore:UpdateAsync(purchaseId, function(old: unknown)
			if old ~= nil then
				return nil -- 이미 기록됨: 그대로 둬요
			end
			return table.clone(record), { record.userId }
		end)
		return true
	end)
	if not ok and isMemory() then
		memory[purchaseId] = memory[purchaseId] or table.clone(record)
		return true
	end
	return ok
end

return PurchaseLog
