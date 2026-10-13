--!strict
-- 로벅스 스킨 결제 (m4-14, GDD 9.1·9.5·13). 스킨(겉모습)만 팔아요 — 속도·판정에 영향 주는 상품·랜덤 상품 없음.
-- 탈의실(장착·코인 해금)은 ShopService, 여기는 개발자 상품 결제만. 지급은 ShopService.grantSkin.
--
-- 리모트 (RemoteFunction, 반환 ok: boolean, err: LocText?):
--   RequestRobuxPurchase(skinId)  ReceiptLogic.canRequest (카탈로그·미보유·상품 id·저장 가능) +
--                         Config.Shop.PurchaseRequestCooldown → MarketplaceService:PromptProductPurchase만 불러요.
-- MarketplaceService.ProcessReceipt (서버에 이것 하나): 판단·순서는 Shared.ReceiptLogic.process.
--   지급 + 장착 → DataService.saveNow가 true → PurchaseLog 기록이 true → PurchaseGranted.
--   그 밖(플레이어 없음·모르는 상품·로드 중·저장 불가(canPersist = false)·잠금 상실·서버 종료 중·저장/기록 실패)은
--   NotProcessedYet → Roblox가 나중에(다음 접속 등) 다시 불러요. grantSkin은 임시 프로필에도 true라서
--   (m4-13 QA N3) 그 결과가 아니라 canPersist + saveNow 결과로 판단해요.
--   같은 PurchaseId는 PurchaseLog + 프로필 receipts로 한 번만, 이 서버에서 처리 중인 같은 id는 NotProcessedYet.
--   결제마다 Output에 "[Shop] receipt ..." 한 줄.
-- Studio + Config.DEBUG.fakeRobuxInStudio: 결제 창 없이 가짜 영수증(PurchaseId "studio-<시각>-<n>")으로 같은 흐름
--   (메모리 프로필이면 메모리에 저장한 것으로 봐요). 같은 영수증을 다시 처리하는 디버그 함수:
--   ServerStorage.ShopDebug.ReplayReceipt (스펙 개발 메모 AC9). 실제 서버에서는 무시.
--
-- 특별 상품 (m5-08): 영수증의 대상은 스킨 하나 또는 상품(묶음·연출). 상품의 내용(무엇을 주는지·장착)은 OfferService가
--   RobuxShopService.setOfferPort(port)로 등록한 port가 알아요 (이 파일은 Offers·OfferService를 require하지 않아요).
--   처리 원칙은 스킨과 같아요: 지급 → saveNow 성공 → 구매 기록({ userId, productId, offerId, at }) 성공 → PurchaseGranted.
--   RobuxShopService.fakeOfferReceipt(player, offerId) -> Result   Studio 가짜 결제 (OfferService가 불러요)
--   ReplayReceipt:Invoke(이름, 스킨 id 또는 상품 id, purchaseId?) 도 상품을 받아요.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local ReceiptLogic = require(ReplicatedStorage.Shared.ReceiptLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)
local PurchaseLog = require(script.Parent.PurchaseLog)
local ShopService = require(script.Parent.ShopService)

local RobuxShopService = {}

local lastPurchaseAt: { [Player]: number } = {}
local inFlight: { [string]: boolean } = {} -- 이 서버에서 처리 중인 PurchaseId
local fakeReceipts: { [string]: { userId: number, target: ReceiptLogic.Target } } = {} -- Studio 가짜 영수증
local fakeCount = 0
local closing = false
-- 결제 창을 띄운 스킨 → 만료 시각(os.clock). 그동안 같은 스킨 코인 해금을 막아요 (m4-14 QA R2).
-- PromptProductPurchaseFinished(취소)·영수증 Granted·Config.Shop.PurchasePromptHold 초가 지나면 풀려요.
local prompted: { [Player]: { [string]: number } } = {}

-- 상품 영수증 처리 (m5-08, OfferService가 등록). offerId는 Shared.Offers의 id
export type OfferPort = {
	offerFor: (productId: number) -> string?, -- 개발자 상품 id → 상품 id (모르면 nil)
	productOf: (offerId: string) -> number?, -- 상품 id → 개발자 상품 id (상품 id가 아직 없으면 0, 모르는 상품이면 nil)
	owns: (player: Player, offerId: string) -> boolean, -- 이미 받은 상태 (묶음은 산 기록, 연출은 보유)
	ownedParts: (player: Player, offerId: string) -> { string }, -- 안의 것 중 이미 가진 것 (로그 note)
	grant: (player: Player, offerId: string, equip: boolean) -> boolean, -- 프로필에 지급 (프로필이 없으면 false)
	onGranted: ((player: Player, offerId: string) -> ())?, -- PurchaseGranted로 새로 지급한 뒤 (안내 문구)
}
local offerPort: OfferPort? = nil

-- persistDataInStudio와 같이 켜면 가짜 결제는 꺼져요 (ShopLogic.fakeRobuxActive, m4-14 QA R4)
local function fakeMode(): boolean
	return ShopLogic.fakeRobuxActive(
		RunService:IsStudio(),
		Config.DEBUG.fakeRobuxInStudio,
		Config.DEBUG.persistDataInStudio
	)
end

local function clearPrompt(player: Player, skinId: string)
	local open = prompted[player]
	if open == nil then
		return
	end
	open[skinId] = nil
	if next(open) == nil then
		prompted[player] = nil
	end
end

local function isPromptOpen(player: Player, skinId: string): boolean
	local open = prompted[player]
	local untilAt = open and open[skinId]
	if untilAt == nil then
		return false
	end
	if os.clock() >= untilAt then
		clearPrompt(player, skinId)
		return false
	end
	return true
end

local function makePort(player: Player?, receipt: ReceiptLogic.Receipt): ReceiptLogic.Port
	local purchaseId = receipt.PurchaseId
	local function present(): boolean
		return player ~= nil and player.Parent == Players
	end
	local function me(): Player
		return player :: Player
	end
	return {
		hasPlayer = present,
		targetFor = function(): ReceiptLogic.Target?
			local fake = fakeReceipts[purchaseId]
			if fake and fakeMode() and fake.userId == receipt.PlayerId then
				return fake.target
			end
			local skin = Skins.forProduct(receipt.ProductId)
			if skin then
				return { kind = "Skin", id = skin.id }
			end
			local port = offerPort
			local offerId = if port then port.offerFor(receipt.ProductId) else nil
			return if offerId then { kind = "Offer", id = offerId } else nil
		end,
		profileReady = function(): boolean
			if closing or not present() or DataService.get(me()) == nil then
				return false
			end
			return DataService.canPersist(me()) or fakeMode()
		end,
		owns = function(target: ReceiptLogic.Target): boolean
			if target.kind == "Offer" then
				local port = offerPort
				return port ~= nil and port.owns(me(), target.id)
			end
			local profile = DataService.get(me())
			return profile ~= nil and profile.ownedSkins[target.id] == true
		end,
		ownedParts = function(target: ReceiptLogic.Target): { string }
			local port = offerPort
			if target.kind == "Offer" and port ~= nil then
				return port.ownedParts(me(), target.id)
			end
			return {}
		end,
		hasReceipt = function(id: string): boolean
			local profile = DataService.get(me())
			return profile ~= nil and ReceiptLogic.hasReceipt(profile.receipts or {}, id)
		end,
		lookupRecord = PurchaseLog.lookup,
		grant = function(target: ReceiptLogic.Target, equip: boolean): boolean
			if target.kind == "Offer" then
				local port = offerPort
				return port ~= nil and port.grant(me(), target.id, equip)
			end
			return ShopService.grantSkin(me(), target.id, equip)
		end,
		rememberReceipt = function(id: string): boolean
			return DataService.update(me(), function(p)
				p.receipts = ReceiptLogic.remember(p.receipts or {}, id, os.time(), Config.Shop.ReceiptHistoryMax)
			end)
		end,
		save = function(): boolean
			if closing or not present() then
				return false
			end
			if DataService.canPersist(me()) then
				return DataService.saveNow(me()) -- 실제로 썼을 때만 true (잠금 상실·해제 뒤·에러면 false)
			end
			-- Studio 가짜 결제 + 메모리 프로필: 메모리에 있는 것으로 저장 끝
			return fakeMode() and DataService.get(me()) ~= nil
		end,
		writeRecord = PurchaseLog.record,
		now = function(): number
			return os.time()
		end,
	}
end

local function readReceipt(info: unknown): ReceiptLogic.Receipt?
	if type(info) ~= "table" then
		return nil
	end
	local raw = info :: any
	if type(raw.PlayerId) ~= "number" or type(raw.ProductId) ~= "number" then
		return nil
	end
	if type(raw.PurchaseId) ~= "string" or raw.PurchaseId == "" then
		return nil
	end
	return { PlayerId = raw.PlayerId, ProductId = raw.ProductId, PurchaseId = raw.PurchaseId }
end

local function handleReceipt(info: unknown): ReceiptLogic.Result
	local receipt = readReceipt(info)
	if receipt == nil then
		warn(`[Shop] receipt with unexpected shape, not processed`)
		return "NotProcessedYet"
	end
	local purchaseId = receipt.PurchaseId
	local head = `[Shop] receipt {purchaseId} user {receipt.PlayerId} product {receipt.ProductId}`
	if inFlight[purchaseId] then
		print(`{head} -> NotProcessedYet (already being processed on this server)`)
		return "NotProcessedYet"
	end
	inFlight[purchaseId] = true
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local ok, outcome = pcall(ReceiptLogic.process, receipt, makePort(player, receipt))
	inFlight[purchaseId] = nil
	if not ok then
		warn(`{head} -> NotProcessedYet (error: {outcome})`)
		return "NotProcessedYet"
	end
	local what = if outcome.offerId then `offer {outcome.offerId}` else `skin {outcome.skinId or "?"}`
	local line = `{head} {what} -> {outcome.result} ({outcome.verdict}: {outcome.note})`
	-- 모르는 상품, 이미 가진 것을 또 산 경우(RecordOnly), 묶음 일부를 이미 가진 경우(m5-08 D5)는 운영 확인용 warn
	if outcome.target == nil or outcome.note:find("already owned") ~= nil then
		warn(line)
	else
		print(line)
	end
	if outcome.result == "PurchaseGranted" and player ~= nil then
		if outcome.skinId ~= nil then
			clearPrompt(player, outcome.skinId)
		end
		local port = offerPort
		local offerId = outcome.offerId
		if offerId ~= nil and outcome.granted and port ~= nil and port.onGranted ~= nil then
			task.spawn(port.onGranted, player, offerId)
		end
	end
	return outcome.result
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local ok, result = pcall(handleReceipt, info)
	if ok and result == "PurchaseGranted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not ok then
		warn(`[Shop] receipt handler failed: {result}`)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Studio 가짜 결제: 결제 창 없이 같은 처리 흐름 (같은 purchaseId로 다시 부르면 중복 처리 확인)
local function runFakeReceipt(player: Player, target: ReceiptLogic.Target, purchaseId: string?): ReceiptLogic.Result
	local productId: number
	if target.kind == "Skin" then
		local skin = Skins.get(target.id)
		if skin == nil then
			return "NotProcessedYet"
		end
		productId = skin.productId or 0
	else
		local port = offerPort
		local offerProduct = if port then port.productOf(target.id) else nil
		if offerProduct == nil then
			return "NotProcessedYet"
		end
		productId = offerProduct
	end
	local id: string
	if purchaseId ~= nil then
		id = purchaseId
	else
		fakeCount += 1
		id = `studio-{os.time()}-{fakeCount}`
	end
	fakeReceipts[id] = { userId = player.UserId, target = target }
	return handleReceipt({ PlayerId = player.UserId, ProductId = productId, PurchaseId = id })
end

-- 상품 영수증 처리를 등록해요 (OfferService.init, m5-08)
function RobuxShopService.setOfferPort(port: OfferPort?)
	offerPort = port
end

-- Studio 가짜 결제로 상품을 처리해요 (OfferService가 fakeMode일 때만 불러요). 가짜 모드가 아니면 NotProcessedYet
function RobuxShopService.fakeOfferReceipt(player: Player, offerId: string): ReceiptLogic.Result
	if not fakeMode() then
		return "NotProcessedYet"
	end
	return runFakeReceipt(player, { kind = "Offer", id = offerId }, nil)
end

local function onRequestRobux(player: Player, skinId: unknown): (boolean, Types.LocText?)
	local now = os.clock()
	local last = lastPurchaseAt[player]
	if last and now - last < Config.Shop.PurchaseRequestCooldown then
		return false, ReceiptLogic.message("TooFast")
	end
	lastPurchaseAt[player] = now
	local profile = DataService.get(player)
	local fake = fakeMode()
	local ok, reason = ReceiptLogic.canRequest(skinId, profile and profile.ownedSkins, {
		canSave = DataService.canPersist(player),
		fake = fake,
		now = Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time()), -- 시즌 스킨 판매 기간 (m5-03)
	})
	if not ok then
		return false, ReceiptLogic.message(reason)
	end
	local skin = Skins.get(skinId) :: Skins.Skin
	if fake then
		task.spawn(runFakeReceipt, player, { kind = "Skin", id = skin.id } :: ReceiptLogic.Target, nil)
		return true, nil
	end
	local open = prompted[player] or {}
	open[skin.id] = os.clock() + Config.Shop.PurchasePromptHold
	prompted[player] = open
	MarketplaceService:PromptProductPurchase(player, skin.productId :: number)
	return true, nil
end

-- Studio 전용 디버그 (AC9): 명령줄(Server)에서
--   game.ServerStorage.ShopDebug.ReplayReceipt:Invoke("플레이어이름", "uni", "studio-test-1")
-- 같은 id로 두 번 부르면 두 번째는 AlreadyRecorded → 스킨은 하나. 스킨 id 대신 상품 id("starter-pack")도 돼요 (m5-08)
local function createDebugHook()
	if not fakeMode() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "ShopDebug"
	local replay = Instance.new("BindableFunction")
	replay.Name = "ReplayReceipt"
	replay.OnInvoke = function(name: unknown, skinId: unknown, purchaseId: unknown): string
		local player = if type(name) == "string" then Players:FindFirstChild(name) else nil
		if player == nil or not player:IsA("Player") or type(skinId) ~= "string" then
			return "usage: ReplayReceipt:Invoke(playerName, skinId or offerId, purchaseId?)"
		end
		local id = if type(purchaseId) == "string" and purchaseId ~= "" then purchaseId else nil
		local target: ReceiptLogic.Target = if Skins.get(skinId) ~= nil
			then { kind = "Skin", id = skinId }
			else { kind = "Offer", id = skinId }
		return runFakeReceipt(player, target, id)
	end
	replay.Parent = folder
	folder.Parent = ServerStorage
end

function RobuxShopService.init()
	Remotes.fn("RequestRobuxPurchase").OnServerInvoke = function(player: Player, skinId: unknown): (boolean, Types.LocText?)
		local ok, success, err = pcall(onRequestRobux, player, skinId)
		if not ok then
			warn(`[Shop] RequestRobuxPurchase failed for {player.Name}: {success}`)
			return false, LocalizeLogic.text("common.err.retry")
		end
		return success, err
	end
	if RunService:IsStudio() and Config.DEBUG.fakeRobuxInStudio and Config.DEBUG.persistDataInStudio then
		warn(
			"[Shop] fakeRobuxInStudio is ignored while persistDataInStudio is on (would write fake purchases to the real stores)"
		)
	end
	ShopService.setCoinBlocker(isPromptOpen)
	PurchaseLog.init()
	game:BindToClose(function()
		closing = true -- 종료 중에 온 영수증은 다음 접속에서 처리 (NotProcessedYet)
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	createDebugHook()
end

function RobuxShopService.start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, isPurchased: boolean)
			local player = Players:GetPlayerByUserId(userId)
			local skin = Skins.forProduct(productId)
			if player and skin and not isPurchased then
				clearPrompt(player, skin.id) -- 취소: 바로 코인 해금 가능 (산 경우는 영수증 Granted까지 유지)
			end
		end
	)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPurchaseAt[player] = nil
		prompted[player] = nil
		for id, fake in fakeReceipts do
			if fake.userId == player.UserId then
				fakeReceipts[id] = nil
			end
		end
	end)
end

return RobuxShopService
