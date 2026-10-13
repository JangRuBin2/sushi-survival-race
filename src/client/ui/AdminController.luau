--!strict
-- 테스트용 관리자 패널 (m5-02). 서버가 관리자에게만 Player 속성 IsAdmin = true를 달아요.
-- 그 속성이 있을 때만(늦게 달려도 기다려요) AdminPanel을 만들고, 아니면 ScreenGui를 아예 만들지 않아요.
-- 속성은 UI를 만들지 말지만 정해요 — 권한은 서버 AdminService가 매번 다시 확인해요.
--   스킨 버튼 → AdminPreviewSkin(skinId), "끄기" → AdminPreviewSkin(nil). 결과(서버 err)는 패널 한 줄.
--   미리보기 중인 스킨 강조는 서버가 단 Player 속성 AdminPreview를 따라가요 (탈의실에서 입기로 꺼지면 같이 꺼져요).
--   "🛠 명령" 탭 (m5-11) → AdminCommand(command, args). 결과 한 줄은 서버가 돌려준 문구 그대로예요.
--   등급(Studio 전용)은 클라이언트가 몰라요 — 실서버에서 Test 명령은 서버가 거절해요.
--   resetprofile 버튼만 RunService:IsStudio()일 때 만들어요. 맵 id 목록은 Shared.maps(allInfos)에서.
-- 매치 중 달리는 동안에도 버튼은 보이고, 요청은 서버가 잠금으로 거절해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminPanel = require(script.Parent.AdminPanel)
local UiScaleController = require(script.Parent.UiScaleController)

local AdminController = {}

local function currentPreview(player: Player): string?
	local value = player:GetAttribute(Attributes.AdminPreview)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function mapIds(): { string }
	-- 관리자 패널을 만들 때만 맵 모듈을 불러요 (일반 플레이어는 안 불러요)
	local Maps = require(ReplicatedStorage.Shared.maps)
	local ids = {}
	for _, info in Maps.allInfos() do
		table.insert(ids, info.id)
	end
	return ids
end

local function build(me: Player)
	local previewRemote = Remotes.fn("AdminPreviewSkin")
	local commandRemote = Remotes.fn("AdminCommand")
	local busy = false
	local panel: AdminPanel.AdminPanel

	-- 리모트 한 번 부르기 (요청 하나씩). 결과 (불렀나, ok, 서버 문구)
	local function call(remote: RemoteFunction, ...: any): (boolean, boolean, string?)
		if busy then
			return false, false, nil
		end
		busy = true
		panel:setBusy(true)
		local called, ok, err = pcall(remote.InvokeServer, remote, ...)
		busy = false
		panel:setBusy(false)
		if not called then
			return true, false, "다시 해 주세요"
		end
		return true, ok == true, if type(err) == "string" then err else nil
	end

	local function request(skinId: string?)
		local sent, ok, err = call(previewRemote, skinId)
		if not sent then
			return
		end
		if ok then
			panel:showResult(
				if skinId then "입었어요 (저장 안 됨)" else "내 스킨으로 돌아왔어요",
				false
			)
		else
			panel:showResult(err or "다시 해 주세요", true)
		end
	end

	local function command(name: string, args: any)
		local sent, ok, text = call(commandRemote, name, args)
		if not sent then
			return
		end
		panel:showResult(text or (if ok then "됐어요" else "다시 해 주세요"), not ok)
	end

	panel = AdminPanel.new(me:WaitForChild("PlayerGui"), {
		toggle = function()
			panel:setOpen(not panel:isOpen())
		end,
		preview = function(skinId: string?)
			task.spawn(request, skinId)
		end,
		command = function(name: string, args: any)
			task.spawn(command, name, args)
		end,
	}, {
		mapIds = mapIds(),
		showReset = RunService:IsStudio(),
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
