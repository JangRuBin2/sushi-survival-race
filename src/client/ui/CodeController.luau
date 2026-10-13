--!strict
-- "🎟 코드" 창 (m5-10). CodeScreen을 띄우고 RedeemCode를 서버에 요청해요. 판단·지급은 서버 CodeService가 해요.
--   버튼이 보이는 때: 로비·방 대기실만 (방이 매치 중이거나 매치 서버면 숨기고 창도 닫아요).
--   성공하면 효과음 CodeRedeemed. 코인 토스트·배지는 기존 RewardGranted 흐름(CoinController)이 보여 줘요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Loc = require(script.Parent.Parent.Loc)
local Sfx = require(script.Parent.Parent.Sfx)
local CodeScreen = require(script.Parent.CodeScreen)
local UiScaleController = require(script.Parent.UiScaleController)

local CodeController = {}

function CodeController.start(_gui: Instance)
	local me = Players.LocalPlayer
	local isMatchServer = workspace:GetAttribute(Attributes.PlaceRole) == "Match"
	local room: Types.RoomSnapshot? = nil
	local busy = false
	local screen: CodeScreen.CodeScreen

	local function canShow(): boolean
		if isMatchServer then
			return false
		end
		return room == nil or room.state ~= "InMatch"
	end

	local function refreshVisibility()
		local visible = canShow()
		screen:setButtonVisible(visible)
		if not visible and screen:isOpen() then
			screen:setOpen(false)
		end
	end

	local function submit(text: string)
		if busy then
			return
		end
		local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
		if trimmed == "" then
			screen:showResult(Loc.t("code.enterCode"), true)
			return
		end
		busy = true
		screen:setBusy(true)
		local remote = Remotes.fn("RedeemCode")
		local called, ok, message = pcall(remote.InvokeServer, remote, text)
		busy = false
		screen:setBusy(false)
		if not called then
			screen:showResult(Loc.t("common.err.connection"), true)
			return
		end
		local reply = Loc.text(message)
		if reply == "" then
			reply = Loc.t("common.err.retry")
		end
		if ok == true then
			screen:clearInput()
			screen:showResult(reply, false)
			Sfx.play("CodeRedeemed")
		else
			screen:showResult(reply, true)
		end
	end

	screen = CodeScreen.new(me:WaitForChild("PlayerGui"), {
		open = function()
			if canShow() then
				screen:setOpen(true)
			end
		end,
		close = function()
			screen:setOpen(false)
		end,
		submit = submit,
	})
	UiScaleController.attach(screen.gui)
	UiScaleController.onChanged(function(m)
		screen:setLayout(m)
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(snapshot: Types.RoomSnapshot?)
		room = snapshot
		refreshVisibility()
	end)

	refreshVisibility()
end

return CodeController
