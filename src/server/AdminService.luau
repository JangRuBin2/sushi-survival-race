--!strict
-- 테스트용 관리자: 스킨 무료 착용(미리보기) (m5-02). 비밀번호·키 입력은 없어요 — 서버가 UserId로만 판단해요.
--   접속할 때 한 번 Shared.AdminLogic.isAdmin(서버 전용 AdminConfig + Studio 여부 + game.CreatorType/CreatorId)으로
--   관리자 표(admins[userId])를 만들고, 관리자에게만 Player 속성 IsAdmin = true를 달아요 (클라이언트 UI 표시용).
--   리모트는 매번 이 표로 다시 확인해요. 클라이언트가 보낸 값이나 속성(IsAdmin)은 권한 판단에 쓰지 않아요.
--
-- 리모트 (RemoteFunction, 반환 ok: boolean, err: string?):
--   AdminPreviewSkin(skinId?)  관리자 표 → 요청 간격(Config.Shop.RequestCooldown) → AdminLogic.checkPreview
--                              (카탈로그·타입·ShopService.isLocked). 성공하면 ShopService.setPreview로 바로 다시 입혀요.
--                              nil·""는 미리보기 끄기. 프로필·코인·결제 기록·보상·DataStore에는 쓰지 않아요.
--
-- 서버 간 유지 (로비 ↔ 매치, m4-11): 실서버에서 미리보기가 바뀌면 MemoryStore HashMap AdminPreview_v1,
-- 키 u_<UserId>에 { skinId, at }(끄면 skinId = false)를 1시간 TTL로 써요. 관리자가 어느 서버에 접속하든
-- 그 서버에서 관리자를 다시 판단한 뒤에만 읽어서 복원해요. Studio는 서버 메모리만 써요.
--
--   AdminService.isAdmin(player) -> boolean     서버 관리자 표
--   AdminService.setStore(store?)               (테스트) MemoryStore 대체 { get(key), set(key, value, ttl) }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminLogic = require(ReplicatedStorage.Shared.AdminLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skins = require(ReplicatedStorage.Shared.Skins)

local AdminConfig = require(script.Parent.AdminConfig)
local ShopService = require(script.Parent.ShopService)

export type Store = {
	get: (key: string) -> any,
	set: (key: string, value: any, ttl: number) -> (),
}

local AdminService = {}

local admins: { [number]: boolean } = {}
local warned: { [number]: boolean } = {} -- 권한 없는 요청 warn은 플레이어당 한 번
local lastRequestAt: { [Player]: number } = {}
local store: Store? = nil

local function isKnownSkin(id: string): boolean
	return Skins.get(id) ~= nil
end

local function isStudio(): boolean
	return RunService:IsStudio()
end

local function computeAdmin(player: Player): boolean
	return AdminLogic.isAdmin({
		isStudio = isStudio(),
		userId = player.UserId,
		allowList = AdminConfig.UserIds,
		includeOwner = AdminConfig.IncludeOwner,
		creatorType = if game.CreatorType == Enum.CreatorType.Group then "Group" else "User",
		creatorId = game.CreatorId,
		studioAllAdmins = AdminConfig.StudioAllAdmins,
		liveEnabled = AdminConfig.LiveEnabled,
	})
end

-- 실서버에서만 MemoryStore (Studio 한 플레이스 모드는 서버 메모리만)
local function getStore(): Store?
	if store ~= nil then
		return store
	end
	if isStudio() then
		return nil
	end
	local ok, map = pcall(function()
		return game:GetService("MemoryStoreService"):GetHashMap(AdminLogic.STORE_NAME)
	end)
	if not ok then
		warn(`[Admin] MemoryStore unavailable: {map}`)
		return nil
	end
	local hashMap = map :: MemoryStoreHashMap
	local created: Store = {
		get = function(key: string): any
			return hashMap:GetAsync(key)
		end,
		set = function(key: string, value: any, ttl: number)
			hashMap:SetAsync(key, value, ttl)
		end,
	}
	store = created
	return created
end

function AdminService.setStore(replacement: Store?)
	store = replacement
end

function AdminService.isAdmin(player: Player): boolean
	return admins[player.UserId] == true
end

local function saveEntry(player: Player, skinId: string?)
	if not admins[player.UserId] then
		return
	end
	local target = getStore()
	if target == nil then
		return
	end
	local ok, err = pcall(
		target.set,
		AdminLogic.storeKey(player.UserId),
		AdminLogic.encodeEntry(skinId, os.time()),
		AdminLogic.STORE_TTL
	)
	if not ok then
		warn(`[Admin] could not save preview for {player.UserId}: {err}`)
	end
end

local function restoreEntry(player: Player)
	local target = getStore()
	if target == nil then
		return
	end
	local ok, value = pcall(target.get, AdminLogic.storeKey(player.UserId))
	if not ok then
		warn(`[Admin] could not read preview for {player.UserId}: {value}`)
		return
	end
	local skinId = AdminLogic.decodeEntry(value, isKnownSkin)
	-- 읽는 동안 나갔거나 관리자가 아니면 (표가 바뀌지 않지만 한 번 더) 그대로 둬요
	if skinId == nil or player.Parent == nil or not admins[player.UserId] then
		return
	end
	ShopService.setPreview(player, skinId, true)
	print(`[Admin] {player.Name}({player.UserId}) restored preview {skinId}`)
end

local function onPlayerAdded(player: Player)
	if not computeAdmin(player) then
		return -- 관리자가 아니면 속성도 달지 않고 MemoryStore도 읽지 않아요
	end
	admins[player.UserId] = true
	player:SetAttribute(Attributes.IsAdmin, true)
	task.spawn(restoreEntry, player)
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

local function onPreview(player: Player, skinId: unknown): (boolean, string?)
	local userId = player.UserId
	if not admins[userId] then
		if not warned[userId] then
			warned[userId] = true
			warn(`[Admin] {player.Name}({userId}) tried AdminPreviewSkin without permission`)
		end
		return false, AdminLogic.message("NotAdmin")
	end
	if not allowRequest(player) then
		return false, AdminLogic.message("TooFast")
	end
	local ok, reason, normalized = AdminLogic.checkPreview(true, skinId, isKnownSkin, ShopService.isLocked(player))
	if not ok then
		return false, AdminLogic.message(reason :: AdminLogic.Reason)
	end
	ShopService.setPreview(player, normalized)
	print(`[Admin] {player.Name}({userId}) preview {normalized or "off"}`)
	return true, nil
end

function AdminService.init()
	Remotes.fn("AdminPreviewSkin").OnServerInvoke = function(player: Player, skinId: unknown): (boolean, string?)
		local ok, success, err = pcall(onPreview, player, skinId)
		if not ok then
			warn(`[Admin] AdminPreviewSkin failed for {player.Name}: {success}`)
			return false, "다시 해 주세요"
		end
		return success, err
	end
	-- 미리보기가 바뀌면(관리자 요청·장착으로 꺼짐) 서버 간 유지 값을 고쳐요
	ShopService.setPreviewListener(saveEntry)
end

function AdminService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		admins[player.UserId] = nil
		warned[player.UserId] = nil
		lastRequestAt[player] = nil
	end)
end

return AdminService
