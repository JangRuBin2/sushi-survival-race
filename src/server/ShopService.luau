--!strict
-- 탈의실 (m4-13): 스킨 장착과 밥알 코인 해금. 소유·장착·코인은 서버 프로필(DataService)에만 있어요.
-- 리모트 (RemoteFunction, 반환 ok: boolean, err: string?):
--   EquipSkin(skinId)     카탈로그에 있고 보유 중이어야 해요. 라운드 레이서(소개 포함)이거나 탈락·우승 연출 중이면 거절.
--                         로비·방 대기실·관전·대기석에서는 돼요. 성공하면 equippedSkin 저장 + 캐릭터에 바로 다시 입혀요.
--   BuyWithCoins(skinId)  일반·레어 스킨만, 미보유, 코인 ≥ 가격 → 한 번의 DataService.update 안에서 차감 + 보유 + 장착.
--                         라운드·연출 중이면 거절 (바로 입혀야 해서). 실제 서버에서 프로필 로드에 실패했으면
--                         (canPersist = false) 거절, Studio 메모리 모드는 허용.
--   두 요청은 Config.Shop.RequestCooldown 간격 제한을 같이 써요. 판단은 Shared.ShopLogic (순수).
-- 외형은 AppearanceService.applyAppearance 한 곳에서만 입혀요: 여기서는 장착 스킨을 고르는 함수(setResolver)를
-- 등록하고, 바뀌면 AppearanceService.refresh를 불러요. 프로필이 캐릭터보다 늦게 로드되면 로드된 뒤 다시 입혀요.
--
--   ShopService.isLocked(player) -> boolean      지금 장착을 바꿀 수 없는가 (라운드·연출 중)
--   ShopService.grantSkin(player, skinId, equip?) -> boolean
--       보유 목록에 넣어요 (m4-14 로벅스 결제가 저장 전에 불러요). 프로필이 없거나 모르는 스킨이면 false.
--       equip이면 장착하고(잠금 중이 아니면) 바로 입혀요. 임시 프로필에도 true라서 결제(RobuxShopService)는
--       이 결과가 아니라 canPersist + saveNow로 완료를 판단해요.
-- 로벅스 결제(RequestRobuxPurchase·ProcessReceipt, m4-14)는 RobuxShopService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Types = require(ReplicatedStorage.Shared.Types)

local AppearanceService = require(script.Parent.AppearanceService)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local RoundService = require(script.Parent.RoundService)

local ShopService = {}

local lastRequestAt: { [Player]: number } = {}
local lockedUntil: { [number]: number } = {} -- userId → os.clock() (탈락·우승 연출이 끝나는 시각)
-- 로벅스 결제 창이 열린 스킨이면 true (RobuxShopService가 등록, m4-14 QA R2). 그동안 같은 스킨 코인 해금을 거절해요
local coinBlocker: ((player: Player, skinId: string) -> boolean)? = nil

-- 우승 연출(VictoryDuration) 뒤 로비 단상이 외형을 읽을 때까지 조금 더 잠가요
local VICTORY_MARGIN = 1

function ShopService.isLocked(player: Player): boolean
	if RoundService.placedRoomOf(player) ~= nil then
		return true -- 이번 라운드 레이서 (소개 중 포함)
	end
	local untilAt = lockedUntil[player.UserId]
	return untilAt ~= nil and os.clock() < untilAt
end

-- 프로필의 장착 스킨 (카탈로그에 있고 보유 중일 때만). 없으면 nil → 기본 계란초밥.
local function equippedOf(player: Player): string?
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	local id = profile.equippedSkin
	if Skins.get(id) == nil or profile.ownedSkins[id] ~= true then
		return nil
	end
	return id
end

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local last = lastRequestAt[player]
	if last and now - last < Config.Shop.RequestCooldown then
		return false
	end
	lastRequestAt[player] = now
	return true
end

local function fail(reason: ShopLogic.Reason, missing: number?): (boolean, string?)
	return false, ShopLogic.message(reason, missing)
end

local function onEquip(player: Player, skinId: unknown): (boolean, string?)
	if not allowRequest(player) then
		return fail("TooFast")
	end
	if type(skinId) ~= "string" then
		return fail("UnknownSkin")
	end
	local profile = DataService.get(player)
	if profile == nil then
		return fail("NoProfile")
	end
	local ok, reason = ShopLogic.canEquip(skinId, profile.ownedSkins, ShopService.isLocked(player))
	if not ok then
		return fail(reason :: ShopLogic.Reason)
	end
	if profile.equippedSkin ~= skinId then
		DataService.update(player, function(p)
			p.equippedSkin = skinId
		end)
	end
	AppearanceService.refresh(player)
	return true, nil
end

local function onBuyWithCoins(player: Player, skinId: unknown): (boolean, string?)
	if not allowRequest(player) then
		return fail("TooFast")
	end
	if type(skinId) ~= "string" then
		return fail("UnknownSkin")
	end
	local profile = DataService.get(player)
	if profile == nil then
		return fail("NoProfile")
	end
	local canSave = DataService.canPersist(player) or RunService:IsStudio()
	local check = ShopLogic.canBuyWithCoins(skinId, profile, canSave)
	if not check.ok then
		return fail(check.reason :: ShopLogic.Reason, check.missing)
	end
	if ShopService.isLocked(player) then
		return fail("Locked")
	end
	local blocker = coinBlocker
	if blocker and blocker(player, skinId) then
		return fail("PurchasePending") -- 결제가 끝나면 로벅스만 빠지고 영수증은 RecordOnly가 돼요
	end
	-- 판단과 차감·지급·장착을 한 번의 update 안에서 (그 사이 다른 요청이 끼지 않아요)
	local decision: ShopLogic.Decision = { ok = false, reason = "NoProfile" }
	local updated = DataService.update(player, function(p)
		decision = ShopLogic.buyWithCoins(p, skinId, canSave)
	end)
	if not updated or not decision.ok then
		return fail(decision.reason :: ShopLogic.Reason, decision.missing)
	end
	print(`[ShopService] {player.Name} unlocked {skinId} for {decision.price} coins`)
	AppearanceService.refresh(player)
	if DataService.canPersist(player) then
		task.spawn(DataService.saveNow, player) -- 코인을 쓴 건 바로 저장해요
	end
	return true, nil
end

-- 로벅스 결제 대기 중인 스킨을 알려 주는 함수 (RobuxShopService.init). 코인 해금이 그 스킨이면 거절해요.
function ShopService.setCoinBlocker(fn: ((player: Player, skinId: string) -> boolean)?)
	coinBlocker = fn
end

function ShopService.grantSkin(player: Player, skinId: string, equip: boolean?): boolean
	if Skins.get(skinId) == nil then
		return false
	end
	local wear = equip == true and not ShopService.isLocked(player)
	local updated = DataService.update(player, function(p)
		ShopLogic.grantSkin(p, skinId, wear)
	end)
	if updated and wear then
		AppearanceService.refresh(player)
	end
	return updated
end

local function onResult(_roomId: string, result: Types.PlayerResult)
	local now = os.clock()
	if result.result == "Eliminated" and result.cause ~= "Left" then
		lockedUntil[result.userId] = now + Config.Match.EliminationCutscene
	elseif result.result == "Won" then
		lockedUntil[result.userId] = now + Config.Match.VictoryDuration + VICTORY_MARGIN
	end
end

local function bind(name: string, handler: (Player, unknown) -> (boolean, string?))
	Remotes.fn(name).OnServerInvoke = function(player: Player, skinId: unknown): (boolean, string?)
		local ok, success, err = pcall(handler, player, skinId)
		if not ok then
			warn(`[ShopService] {name} failed for {player.Name}: {success}`)
			return false, "다시 해 주세요"
		end
		return success, err
	end
end

function ShopService.init()
	local valid, problems = Skins.validate(Skins.LIST)
	if not valid then
		warn(`[ShopService] skin catalog problems: {table.concat(problems, "; ")}`)
	end
	AppearanceService.setResolver(equippedOf)
	bind("EquipSkin", onEquip)
	bind("BuyWithCoins", onBuyWithCoins)
end

function ShopService.start()
	-- 프로필이 캐릭터보다 늦게 로드되면 장착 스킨으로 다시 입혀요 (같은 스킨이면 그대로)
	DataService.onLoaded(function(player: Player)
		AppearanceService.refresh(player)
	end)
	MatchEvents.onResult(onResult)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequestAt[player] = nil
		lockedUntil[player.UserId] = nil
	end)
end

return ShopService
