--!strict
-- 로벅스 스킨 결제 판단 (m4-14, GDD 9.5·13). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/receipt-logic.spec.luau).
-- 원칙: 저장이 실제로 성공한 뒤에만 PurchaseGranted. 그 밖에는 전부 NotProcessedYet → Roblox가 나중에 다시 불러요.
--
--   ReceiptLogic.decide(state) -> Verdict
--       "NotProcessedYet"  플레이어가 이 서버에 없음 / 모르는 상품 / 프로필 준비 안 됨(로드 전·저장 불가·서버 종료 중)
--                          / 구매 기록을 읽지 못함
--       "AlreadyRecorded"  구매 기록(PurchaseLog)에 이 PurchaseId가 있음 → 프로필에 스킨만 확인하고 완료
--       "RecordOnly"       기록은 없는데 이미 보유 (다시 시도된 결제, 또는 다른 서버에서 같은 스킨을 또 산 경우)
--       "GrantAndRecord"   기록 없음 + 미보유 → 지급 + 장착 → 프로필 저장 → 구매 기록
--   ReceiptLogic.process(receipt, port) -> Outcome
--       판단 + 실행 순서. 저장·기록은 port가 해요 (서버 ShopService가 DataService·PurchaseLog로 만들어요,
--       테스트는 가짜 저장소). 어느 단계든 실패하면 NotProcessedYet, 그때까지 구매 기록은 쓰지 않아요.
--   ReceiptLogic.canRequest(skinId, ownedSkins?, opts) -> (ok, reason?)   RequestRobuxPurchase 검사
--   ReceiptLogic.message(reason) -> string                               거절 문구 (탈의실 결과 글씨)
--   ReceiptLogic.hasReceipt(history, purchaseId) / remember(history, purchaseId, at, max) / sanitizeHistory(raw, max)
--       프로필의 처리한 결제 id 목록 (오래된 것부터 max개만 남겨요). 같은 PurchaseId를 두 번 지급하지 않게
--       구매 기록과 함께 한 번 더 막아요.

local Skins = require(script.Parent.Skins)

export type Verdict = "NotProcessedYet" | "GrantAndRecord" | "AlreadyRecorded" | "RecordOnly"
export type Result = "PurchaseGranted" | "NotProcessedYet"

export type State = {
	playerPresent: boolean,
	skinId: string?, -- 상품 → 스킨 (nil이면 모르는 상품)
	profileReady: boolean, -- 프로필 로드됨 + 저장 가능(Studio 가짜 결제면 메모리 허용) + 서버 종료 중 아님
	recorded: boolean?, -- 구매 기록에 이 PurchaseId가 있는가 (nil이면 읽지 못함)
	owned: boolean?, -- 프로필에 그 스킨이 이미 있는가
}

-- MarketplaceService.ProcessReceipt가 넘기는 영수증에서 쓰는 칸
export type Receipt = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
}

-- 구매 기록 한 줄 (DataStore Purchases_v1, 키 = PurchaseId)
export type Record = {
	userId: number,
	productId: number,
	skinId: string,
	at: number, -- os.time()
}

export type HistoryEntry = { id: string, at: number }

export type Port = {
	hasPlayer: () -> boolean,
	skinFor: () -> string?, -- 이 영수증의 스킨 id (모르면 nil)
	profileReady: () -> boolean,
	owns: (skinId: string) -> boolean,
	hasReceipt: (purchaseId: string) -> boolean, -- 프로필의 처리한 결제 id 목록에 있는가
	lookupRecord: (purchaseId: string) -> boolean?, -- 구매 기록에 있는가 (nil = 읽기 실패)
	grant: (skinId: string, equip: boolean) -> boolean, -- 프로필에 스킨 추가 (+장착). 프로필이 없으면 false
	rememberReceipt: (purchaseId: string) -> boolean, -- 프로필의 처리한 결제 id 목록에 추가
	save: () -> boolean, -- 프로필을 지금 저장 (실제로 썼을 때만 true)
	writeRecord: (purchaseId: string, record: Record) -> boolean,
	now: () -> number,
}

export type Outcome = {
	result: Result,
	verdict: Verdict,
	skinId: string?,
	note: string, -- 로그용 한 줄 (영어)
	granted: boolean, -- 이번에 스킨을 새로 넣었는가 (화면 안내용)
}

export type RequestReason = "UnknownSkin" | "AlreadyOwned" | "NotForSale" | "CannotSave" | "NoProfile" | "TooFast"

export type RequestOptions = {
	canSave: boolean, -- DataService.canPersist
	fake: boolean, -- Studio 가짜 결제 (Config.DEBUG.fakeRobuxInStudio, Studio일 때만 true)
}

local ReceiptLogic = {}

function ReceiptLogic.decide(state: State): Verdict
	if not state.playerPresent then
		return "NotProcessedYet"
	end
	if state.skinId == nil then
		return "NotProcessedYet"
	end
	if not state.profileReady then
		return "NotProcessedYet"
	end
	if state.recorded == nil then
		return "NotProcessedYet"
	end
	if state.recorded then
		return "AlreadyRecorded"
	end
	if state.owned then
		return "RecordOnly"
	end
	return "GrantAndRecord"
end

local function outcome(result: Result, verdict: Verdict, skinId: string?, note: string, granted: boolean?): Outcome
	return { result = result, verdict = verdict, skinId = skinId, note = note, granted = granted == true }
end

local function notYet(verdict: Verdict, skinId: string?, note: string): Outcome
	return outcome("NotProcessedYet", verdict, skinId, note)
end

function ReceiptLogic.process(receipt: Receipt, port: Port): Outcome
	local purchaseId = receipt.PurchaseId
	if not port.hasPlayer() then
		return notYet("NotProcessedYet", nil, "player not in this server")
	end
	local skinId = port.skinFor()
	if skinId == nil then
		return notYet("NotProcessedYet", nil, `unknown product {receipt.ProductId}`)
	end
	if not port.profileReady() then
		return notYet("NotProcessedYet", skinId, "profile not ready (loading, cannot save, or server closing)")
	end
	local recorded = port.lookupRecord(purchaseId)
	-- 기록을 읽는 동안(yield) 나갔거나 저장할 수 없게 됐을 수 있어요
	local present = port.hasPlayer()
	local ready = present and port.profileReady()
	local verdict = ReceiptLogic.decide({
		playerPresent = present,
		skinId = skinId,
		profileReady = ready,
		recorded = recorded,
		owned = ready and port.owns(skinId),
	})

	if verdict == "NotProcessedYet" then
		local why = if recorded == nil then "purchase log read failed" else "player left or profile not ready"
		return notYet(verdict, skinId, why)
	end

	if verdict == "AlreadyRecorded" then
		-- 기록은 있는데 프로필에 없으면(프로필이 되돌려진 경우 등) 다시 넣어요. 메모리에만 들어간 상태일 수도 있어서
		-- (앞선 시도의 저장 실패) 있든 없든 저장이 돼야 완료예요.
		local restored = false
		if not port.owns(skinId) then
			if not port.grant(skinId, false) then
				return notYet(verdict, skinId, "already recorded, re-grant failed")
			end
			restored = true
		end
		if not port.hasReceipt(purchaseId) then
			port.rememberReceipt(purchaseId)
		end
		if not port.save() then
			return notYet(verdict, skinId, "already recorded, profile save failed")
		end
		local note = if restored then "already recorded, skin restored" else "already recorded"
		return outcome("PurchaseGranted", verdict, skinId, note, restored)
	end

	local granted = false
	if verdict == "GrantAndRecord" then
		if not port.grant(skinId, true) then
			return notYet(verdict, skinId, "grant failed (no profile)")
		end
		granted = true
	end
	local retried = port.hasReceipt(purchaseId)
	if not retried then
		port.rememberReceipt(purchaseId)
	end
	if not port.save() then
		return notYet(verdict, skinId, "profile save failed")
	end
	local record: Record = {
		userId = receipt.PlayerId,
		productId = receipt.ProductId,
		skinId = skinId,
		at = port.now(),
	}
	if not port.writeRecord(purchaseId, record) then
		return notYet(verdict, skinId, "purchase log write failed")
	end
	local note = if verdict == "GrantAndRecord"
		then "granted"
		elseif retried then "retry, skin already granted"
		else "skin was already owned (bought again, refund is an operator decision)"
	return outcome("PurchaseGranted", verdict, skinId, note, granted)
end

---------------------------------------------------------------- 구매 요청 검사

function ReceiptLogic.canRequest(
	skinId: unknown,
	ownedSkins: { [string]: boolean }?,
	opts: RequestOptions
): (boolean, RequestReason?)
	local skin = Skins.get(skinId)
	if skin == nil then
		return false, "UnknownSkin"
	end
	if skin.id == Skins.DEFAULT_ID or (ownedSkins ~= nil and ownedSkins[skin.id] == true) then
		return false, "AlreadyOwned"
	end
	if skin.robux == nil then
		return false, "UnknownSkin"
	end
	if ownedSkins == nil then
		return false, "NoProfile"
	end
	if opts.fake then
		return true, nil -- Studio 가짜 결제: 상품 id·저장 가능 여부와 상관없이 (메모리에 저장)
	end
	if skin.productId == nil then
		return false, "NotForSale"
	end
	if not opts.canSave then
		return false, "CannotSave"
	end
	return true, nil
end

local MESSAGES: { [RequestReason]: string } = {
	UnknownSkin = "없는 스킨이에요",
	AlreadyOwned = "이미 있어요",
	NotForSale = "준비 중이에요",
	CannotSave = "저장이 안 되는 상태라 지금은 살 수 없어요",
	NoProfile = "프로필을 불러오는 중이에요",
	TooFast = "잠시 뒤에 다시 해 주세요",
}

function ReceiptLogic.message(reason: RequestReason?): string
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

---------------------------------------------------------------- 프로필의 처리한 결제 id 목록

function ReceiptLogic.hasReceipt(history: { HistoryEntry }, purchaseId: string): boolean
	for _, entry in history do
		if entry.id == purchaseId then
			return true
		end
	end
	return false
end

-- 끝에 더하고, max개가 넘으면 오래된 것(앞)부터 지워요. 이미 있으면 그대로. 바꾼 목록을 돌려줘요 (같은 표).
function ReceiptLogic.remember(history: { HistoryEntry }, purchaseId: string, at: number, max: number): { HistoryEntry }
	if not ReceiptLogic.hasReceipt(history, purchaseId) then
		table.insert(history, { id = purchaseId, at = at })
	end
	local limit = math.max(1, math.floor(max))
	while #history > limit do
		table.remove(history, 1)
	end
	return history
end

-- 저장된 값 정리 (ProfileLogic.migrate): 모양이 맞는 항목만, 시각 순, 같은 id는 하나, 최근 max개.
function ReceiptLogic.sanitizeHistory(raw: unknown, max: number): { HistoryEntry }
	local out: { HistoryEntry } = {}
	if type(raw) ~= "table" then
		return out
	end
	local seen: { [string]: boolean } = {}
	for _, entry in raw :: { any } do
		if type(entry) ~= "table" then
			continue
		end
		local id, at = entry.id, entry.at
		if type(id) ~= "string" or id == "" or seen[id] then
			continue
		end
		if type(at) ~= "number" or at ~= at or at < 0 or at == math.huge then
			continue
		end
		seen[id] = true
		table.insert(out, { id = id, at = at })
	end
	table.sort(out, function(a: HistoryEntry, b: HistoryEntry): boolean
		return a.at < b.at
	end)
	local limit = math.max(1, math.floor(max))
	while #out > limit do
		table.remove(out, 1)
	end
	return out
end

return ReceiptLogic
