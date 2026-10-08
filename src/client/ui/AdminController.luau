--!strict
-- 테스트용 관리자 패널 (m5-02). 서버가 관리자에게만 Player 속성 IsAdmin = true를 달아요.
-- 그 속성이 있을 때만(늦게 달려도 기다려요) AdminPanel을 만들고, 아니면 ScreenGui를 아예 만들지 않아요.
-- 속성은 UI를 만들지 말지만 정해요 — 권한은 서버 AdminService가 매번 다시 확인해요.
--   스킨 버튼 → AdminPreviewSkin(skinId), "끄기" → AdminPreviewSkin(nil). 결과(서버 err)는 패널 한 줄.
--   미리보기 중인 스킨 강조는 서버가 단 Player 속성 AdminPreview를 따라가요 (탈의실에서 입기로 꺼지면 같이 꺼져요).
-- 매치 중 달리는 동안에도 버튼은 보이고, 요청은 서버가 잠금으로 거절해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminPanel = require(script.Parent.AdminPanel)
local UiScaleController = require(script.Parent.UiScaleController)

local AdminController = {}

local function currentPreview(player: Player): string?
	local value = player:GetAttribute(Attributes.AdminPreview)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function build(me: Player)
	local remote = Remotes.fn("AdminPreviewSkin")
	local busy = false
	local panel: AdminPanel.AdminPanel

	local function request(skinId: string?)
		if busy then
			return
		end
		busy = true
		panel:setBusy(true)
		local called, ok, err = pcall(remote.InvokeServer, remote, skinId)
		busy = false
		panel:setBusy(false)
		if not called then
			panel:showResult("다시 해 주세요", true)
		elseif ok then
			panel:showResult(
				if skinId then "입었어요 (저장 안 됨)" else "내 스킨으로 돌아왔어요",
				false
			)
		else
			panel:showResult(if type(err) == "string" then err else "다시 해 주세요", true)
		end
	end

	panel = AdminPanel.new(me:WaitForChild("PlayerGui"), {
		toggle = function()
			panel:setOpen(not panel:isOpen())
		end,
		preview = function(skinId: string?)
			task.spawn(request, skinId)
		end,
	})
	panel:setCurrent(currentPreview(me))
	me:GetAttributeChangedSignal(Attributes.AdminPreview):Connect(function()
		panel:setCurrent(currentPreview(me))
	end)
	UiScaleController.attach(panel.gui)
	UiScaleController.onChanged(function(m)
		panel:setLayout(m)
	end)
end

function AdminController.start(_gui: Instance)
	local me = Players.LocalPlayer
	if me:GetAttribute(Attributes.IsAdmin) == true then
		build(me)
		return
	end
	-- 서버가 접속 직후에 늦게 달 수 있어요
	local connection: RBXScriptConnection? = nil
	connection = me:GetAttributeChangedSignal(Attributes.IsAdmin):Connect(function()
		if me:GetAttribute(Attributes.IsAdmin) == true then
			if connection then
				connection:Disconnect()
			end
			build(me)
		end
	end)
end

return AdminController
