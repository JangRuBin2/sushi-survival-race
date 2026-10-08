--!strict
-- 방 대기실 화면 (GDD 3.2, 10): 참가자 목록, 방 코드, 인원 n/최대, 방장 시작 버튼, 나가기, 자동 시작 카운트다운.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

local Color = Kit.Color

export type Actions = {
	start: () -> (),
	leave: () -> (),
}

export type RoomScreen = {
	setVisible: (self: RoomScreen, visible: boolean) -> (),
	setRoom: (self: RoomScreen, room: Types.RoomSnapshot) -> (),
	setBusy: (self: RoomScreen, busy: boolean) -> (),
	showMessage: (self: RoomScreen, text: string, isError: boolean?) -> (),
}

local RoomScreen = {}

function RoomScreen.new(parent: Instance, localUserId: number, minPlayers: number, actions: Actions): RoomScreen
	local room: Types.RoomSnapshot? = nil
	local busy = false

	local root = Kit.new("Frame", {
		Name = "Room",
		Parent = parent,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local panel = Kit.new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		BackgroundColor3 = Color.Panel,
	}, {
		Kit.corner(16),
		Kit.padding(16),
		Kit.list(Enum.FillDirection.Vertical, 8),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 560) }),
	})

	local title = Kit.label({ Parent = panel, LayoutOrder = 1, TextSize = 24, Size = UDim2.new(1, 0, 0, 32) })
	local info = Kit.label({ Parent = panel, LayoutOrder = 2, TextColor3 = Color.SubText, TextSize = 16 })
	local codeLabel = Kit.label({
		Parent = panel,
		LayoutOrder = 3,
		TextSize = 22,
		TextColor3 = Color.Salmon,
		Size = UDim2.new(1, 0, 0, 30),
	})

	local list = Kit.scrollList({
		Parent = panel,
		LayoutOrder = 4,
		-- 고정 높이: 제목 32, 정보 24, 코드 30, 상태 24, 버튼 48, 문구 22, 간격 8 × 6 (applyLayout이 화면에 맞춰 다시 정해요)
		Size = UDim2.new(1, 0, 1, -(32 + 24 + 30 + 24 + 48 + 22 + 8 * 6)),
	}, 4)

	local status = Kit.label({
		Parent = panel,
		LayoutOrder = 5,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local buttonRow = Kit.new("Frame", {
		Parent = panel,
		LayoutOrder = 6,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	local leaveButton = Kit.button("나가기", Color.Neutral, {
		Parent = buttonRow,
		LayoutOrder = 1,
		Size = UDim2.new(0.35, -4, 1, 0),
		TextColor3 = Color.Text,
	})
	local startButton = Kit.button("시작!", Color.Salmon, {
		Parent = buttonRow,
		LayoutOrder = 2,
		Size = UDim2.new(0.65, -4, 1, 0),
		TextSize = 22,
	})

	local showMessage, messageLabel = Kit.messageLabel(panel, 7)
	local metrics = UiScaleController.metrics()

	Kit.onClick(leaveButton, actions.leave)
	Kit.onClick(startButton, actions.start)

	local function isHost(): boolean
		return room ~= nil and room.hostUserId == localUserId
	end

	local function refreshButtons()
		local current = room
		local enoughPlayers = current ~= nil and #current.members >= minPlayers
		startButton.Visible = isHost()
		Kit.setEnabled(startButton, not busy and enoughPlayers)
		Kit.setEnabled(leaveButton, not busy)
	end

	-- 상태 문구는 카운트다운 때문에 매 프레임 바뀔 수 있어요.
	local function statusText(current: Types.RoomSnapshot): string
		if current.autoStartAt then
			local left = math.max(0, math.ceil(current.autoStartAt - workspace:GetServerTimeNow()))
			return `정원이 다 찼어요! {left}초 뒤 자동 시작`
		end
		if #current.members < minPlayers then
			return `{minPlayers}명 이상 모이면 시작할 수 있어요`
		end
		if isHost() then
			return "준비되면 시작을 눌러 주세요"
		end
		return "방장이 시작하기를 기다리는 중…"
	end

	local function render()
		local current = room
		if current == nil then
			return
		end
		title.Text = current.name
		info.Text =
			`{if current.isPrivate then "비공개" else "공개"} 방 · {#current.members}/{current.maxPlayers}명`
		codeLabel.Visible = current.code ~= nil
		codeLabel.Text = if current.code then `방 코드: {current.code}` else ""

		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local rowText = UiLayout.textSize(18, metrics)
		for i, member in current.members do
			local isRoomHost = member.userId == current.hostUserId
			local isMe = member.userId == localUserId
			Kit.new("Frame", {
				Parent = list,
				LayoutOrder = i,
				BackgroundColor3 = if isMe then Color.Egg else Color.Row,
				Size = UDim2.new(1, -8, 0, math.max(40, rowText + 16)),
			}, {
				Kit.corner(8),
				Kit.padding(8),
				Kit.label({
					Text = `{if isRoomHost then "👑 " else "🍣 "}{member.name}{if isMe then " (나)" else ""}`,
					TextSize = rowText,
					Size = UDim2.fromScale(1, 1),
				}),
			})
		end
		status.Text = statusText(current)
		refreshButtons()
	end

	-- 화면 크기 대응 (m4-09): 버튼은 배율 적용 뒤 44px 이상, compact면 위쪽에 붙이고 글씨를 키워요
	local function applyLayout(m: UiLayout.Metrics)
		metrics = m
		local function text(base: number): number
			return UiLayout.textSize(base, m)
		end
		local function line(base: number, textBase: number): number
			return UiLayout.lineHeight(base, m, textBase)
		end
		if m.compact then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.fromScale(0.5, 0.03)
			panel.Size = UDim2.fromScale(0.94, 0.9)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
			panel.Size = UDim2.fromScale(0.92, 0.86)
		end
		local fixed = 0
		for _, item in
			{
				{ label = title, height = 32, text = 24 },
				{ label = info, height = 24, text = 16 },
				{ label = codeLabel, height = 30, text = 22 },
				{ label = status, height = 24, text = 17 },
				{ label = messageLabel, height = 22, text = 16 },
			}
		do
			local height = line(item.height, item.text)
			item.label.TextSize = text(item.text)
			item.label.Size = UDim2.new(1, 0, 0, height)
			fixed += height
		end
		local buttonHeight = UiLayout.touchSize(48, m)
		buttonRow.Size = UDim2.new(1, 0, 0, buttonHeight)
		leaveButton.TextSize = text(18)
		startButton.TextSize = text(22)
		list.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		list.Size = UDim2.new(1, 0, 1, -(fixed + buttonHeight + 8 * 6))
		render()
	end
	UiScaleController.onChanged(applyLayout)

	-- 카운트다운 표시
	task.spawn(function()
		while root.Parent do
			local current = room
			if root.Visible and current and current.autoStartAt then
				status.Text = statusText(current)
			end
			task.wait(0.25)
		end
	end)

	local screen = {}

	function screen.setVisible(_self: RoomScreen, visible: boolean)
		root.Visible = visible
	end

	function screen.setRoom(_self: RoomScreen, newRoom: Types.RoomSnapshot)
		room = newRoom
		render()
	end

	function screen.setBusy(_self: RoomScreen, value: boolean)
		busy = value
		refreshButtons()
	end

	function screen.showMessage(_self: RoomScreen, text: string, isError: boolean?)
		showMessage(text, isError)
	end

	return (screen :: any) :: RoomScreen
end

return RoomScreen
