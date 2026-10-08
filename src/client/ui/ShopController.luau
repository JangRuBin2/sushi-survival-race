--!strict
-- 탈의실 (m4-13). ShopScreen에 내 프로필(ProfileStore)을 그리고 EquipSkin·BuyWithCoins를 서버에 요청해요.
-- 판정(보유·가격·코인·라운드 중 금지)은 서버 ShopService가 해요. 여기서는 보여 주기와 요청만.
--   "🍣 스킨" 버튼이 보이는 때: 로비·방 대기실, 매치 중이면 내가 달리지 않을 때(탈락해 관전 중, 통과해 대기석,
--   라운드 결과 사이). 시작 카운트다운·라운드 소개·달리는 중·우승 연출 동안은 숨기고 창도 닫아요.
--   매치 서버(m4-11)는 매치가 시작되기 전(연결 중 안내)에는 숨겨요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local ShopScreen = require(script.Parent.ShopScreen)
local UiScaleController = require(script.Parent.UiScaleController)

local ShopController = {}

function ShopController.start(_gui: Instance)
	local me = Players.LocalPlayer
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"

	local tier: Skins.Tier? = nil
	local selected = Skins.DEFAULT_ID
	local busy = false
	local view: Types.ProfileView? = ProfileStore.get()
	local screen: ShopScreen.ShopScreen

	-- 매치 상태 (버튼을 보일지)
	local room: Types.RoomSnapshot? = nil
	local phase: Types.MatchPhase? = nil
	local alive = true -- 이 매치에서 아직 탈락하지 않았는지
	local passed = false -- 이번 라운드를 통과해 대기석에 있는지

	local function render()
		local current = view
		if current == nil or screen == nil then
			return
		end
		screen:render(current, tier, selected)
	end

	local function canShow(): boolean
		local inMatch = room ~= nil and room.state == "InMatch"
		if not inMatch then
			return not isMatchServer
		end
		if phase == "Starting" or phase == "Victory" or phase == nil then
			return false
		end
		if not alive then
			return true -- 관전 중
		end
		if phase == "RoundResults" then
			return true -- 라운드 사이 대기석
		end
		return passed -- 라운드 소개·진행 중: 통과해서 대기석에 있을 때만
	end

	local function refreshVisibility()
		local visible = canShow() and view ~= nil
		screen:setButtonVisible(visible)
		if not visible and screen:isOpen() then
			screen:setOpen(false)
		end
	end

	local function request(name: string, skinId: string): (boolean, string?)
		local remote = Remotes.fn(name)
		local called, ok, err = pcall(remote.InvokeServer, remote, skinId)
		if not called then
			return false, "서버와 연결이 불안정해요"
		end
		return ok == true, if type(err) == "string" then err else nil
	end

	local function act(skinId: string)
		local current = view
		local skin = Skins.get(skinId)
		if busy or current == nil or skin == nil then
			return
		end
		local owned = table.find(current.ownedSkins, skinId) ~= nil or skinId == Skins.DEFAULT_ID
		if current.equippedSkin == skinId then
			return
		end
		local name = if owned then "EquipSkin" elseif skin.coins then "BuyWithCoins" else nil
		if name == nil then
			return -- 로벅스는 m4-14가 켜요 (버튼 비활성)
		end
		busy = true
		screen:setBusy(true)
		local ok, err = request(name, skinId)
		busy = false
		screen:setBusy(false)
		if ok then
			screen:showResult(if owned then `{skin.displayName} 입었어요!` else `{skin.displayName} 해금!`, false)
		else
			screen:showResult(err or "다시 해 주세요", true)
		end
	end

	screen = ShopScreen.new(me:WaitForChild("PlayerGui"), {
		open = function()
			if view == nil then
				return
			end
			selected = (view :: Types.ProfileView).equippedSkin
			render()
			screen:setOpen(true)
		end,
		close = function()
			screen:setOpen(false)
		end,
		select = function(skinId: string)
			selected = skinId
			render()
		end,
		act = act,
		tab = function(newTier: Skins.Tier?)
			tier = newTier
			render()
		end,
	})
	UiScaleController.attach(screen.gui)
	UiScaleController.onChanged(function(m)
		screen:setLayout(m)
	end)

	ProfileStore.changed(function(newView: Types.ProfileView)
		view = newView
		render()
		refreshVisibility()
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
		local wasInMatch = room ~= nil and room.state == "InMatch"
		room = snapshot
		local inMatch = snapshot ~= nil and snapshot.state == "InMatch"
		if not inMatch or not wasInMatch then
			-- 매치 밖이거나 새 매치: 매치 상태를 처음으로
			phase = nil
			alive = true
			passed = false
		end
		refreshVisibility()
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if type(info) ~= "table" then
			return
		end
		phase = info.phase
		if info.phase == "Starting" then
			alive = true
			passed = false
		elseif info.phase == "RoundIntro" then
			passed = false
		end
		local ids = info.aliveUserIds
		if ids then
			alive = table.find(ids, me.UserId) ~= nil
		end
		refreshVisibility()
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if type(result) ~= "table" or result.userId ~= me.UserId then
			return
		end
		if result.result == "Eliminated" then
			alive = false
		elseif result.result == "Passed" then
			passed = true
		end
		refreshVisibility()
	end)

	render()
	refreshVisibility()
end

return ShopController
