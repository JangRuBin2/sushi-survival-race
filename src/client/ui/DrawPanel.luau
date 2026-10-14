--!strict
-- 🎫 우승자 뽑기 패널 (m5-31, GDD 9.6·10). 탈의실 창(ShopScreen) 안을 덮는 화면이에요. 보여 주기만 하고 요청은 actions로.
--   위: 제목 · "◀ 탈의실" 버튼. 가운데: 접시 무대 (뚜껑 🛎️이 약 1.5초 들썩 → 열림 → 결과).
--     꽝/대체: "🍚 +20" 큰 글씨. 당첨: 새 스킨 3D 미리보기(SushiBody.build) + "🎉 ○○ (특) 획득!" + "입기" 버튼.
--   아래: 티켓 수 "🎫 N장", 확률 줄(DrawLogic.oddsText — 늘 보여요), "뽑기 (🎫 1장)" 버튼, 티켓 0이면 안내 한 줄.
--   연출 중에는 뽑기 버튼이 꺼져요 (서버도 Config.Draw.RequestCooldown으로 연타를 막아요).
-- 휴대폰(compact)에서는 본문이 스크롤돼요. 버튼은 UiLayout.touchSize(44) 이상.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DrawLogic = require(ReplicatedStorage.Shared.DrawLogic)
local Skins = require(ReplicatedStorage.Shared.Skins)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type Actions = {
	draw: () -> (),
	close: () -> (),
	wear: (skinId: string) -> (),
}

export type RenderState = {
	tickets: number,
	oddsLines: { string },
	canDraw: boolean, -- 티켓이 있고 연출 중이 아님 (판정은 서버)
}

export type DrawPanel = {
	frame: Frame,
	setOpen: (self: DrawPanel, open: boolean) -> (),
	isOpen: (self: DrawPanel) -> boolean,
	render: (self: DrawPanel, state: RenderState) -> (),
	shake: (self: DrawPanel) -> (), -- 뚜껑 들썩이기 시작 (결과를 기다리는 동안)
	reveal: (self: DrawPanel, result: Types.DrawResult) -> (), -- 뚜껑 열고 결과 보이기
	showMessage: (self: DrawPanel, text: string, isError: boolean) -> (),
	resetStage: (self: DrawPanel) -> (),
	setLayout: (self: DrawPanel, m: UiLayout.Metrics) -> (),
}

local DrawPanel = {}

DrawPanel.REVEAL_TIME = 1.5 -- 초: 뚜껑이 들썩이는 최소 시간 (결과가 빨리 와도 이만큼은 보여 줘요)

local SPECIAL = Color3.fromRGB(Skins.DRAW_INFO.color[1], Skins.DRAW_INFO.color[2], Skins.DRAW_INFO.color[3])
local GAP = 8
local STAGE_HEIGHT = 170
local SPIN_SPEED = 0.9

function DrawPanel.new(parent: Instance, actions: Actions): DrawPanel
	local frame = Kit.new("Frame", {
		Name = "DrawPanel",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Panel,
		Active = true,
		Visible = false,
		ZIndex = 5,
	}, { Kit.corner(12) }) :: Frame

	-- 머리줄: 제목 · 돌아가기
	local header = Kit.new("Frame", {
		Name = "Header",
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 5,
	})
	local title = Kit.label({
		Parent = header,
		Text = "🎫 우승자 뽑기",
		TextSize = 22,
		Size = UDim2.new(1, -130, 1, 0),
		ZIndex = 5,
	})
	local backButton = Kit.button("◀ 탈의실", Color.Nori, {
		Name = "Back",
		Parent = header,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 120, 1, 0),
		TextSize = 16,
		ZIndex = 5,
	})
	Kit.onClick(backButton, actions.close)

	-- 본문 (휴대폰에서 잘리지 않게 스크롤)
	local body = Kit.new("ScrollingFrame", {
		Name = "Body",
		Parent = frame,
		Position = UDim2.fromOffset(0, 44 + GAP),
		Size = UDim2.new(1, 0, 1, -(44 + GAP)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color.SubText,
		ZIndex = 5,
	}, {
		Kit.list(Enum.FillDirection.Vertical, GAP, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Kit.new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2) }),
	}) :: ScrollingFrame

	-- 접시 무대
	local stage = Kit.new("Frame", {
		Name = "Stage",
		Parent = body,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, STAGE_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(255, 236, 205),
		ClipsDescendants = true,
		ZIndex = 5,
	}, { Kit.corner(12), Kit.new("UIStroke", { Color = SPECIAL, Thickness = 3 }) }) :: Frame
	local viewport = Kit.new("ViewportFrame", {
		Name = "Prize",
		Parent = stage,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.6, 0.78),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		Visible = false,
		ZIndex = 6,
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -10), Vector3.new(0, 0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local prizeText = Kit.label({
		Name = "PrizeText",
		Parent = stage,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1, 0.4),
		Text = "",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 6,
	})
	local plate = Kit.label({
		Name = "Plate",
		Parent = stage,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(1, 0.3),
		Text = "🍽️",
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
	})
	local LID_HOME = UDim2.fromScale(0.5, 0.78)
	local lid = Kit.label({
		Name = "Lid",
		Parent = stage,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = LID_HOME,
		Size = UDim2.fromScale(1, 0.5),
		Text = "🛎️",
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
	})

	local resultLabel = Kit.label({
		Name = "Result",
		Parent = body,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})
	local wearButton = Kit.button("입기", Color.Salmon, {
		Name = "Wear",
		Parent = body,
		LayoutOrder = 3,
		Size = UDim2.new(0.6, 0, 0, 44),
		TextSize = 17,
		Visible = false,
		ZIndex = 5,
	})
	local ticketLabel = Kit.label({
		Name = "Tickets",
		Parent = body,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "🎫 0장",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})
	local oddsBox = Kit.new("Frame", {
		Name = "Odds",
		Parent = body,
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color.Row,
		ZIndex = 5,
	}, {
		Kit.corner(10),
		Kit.padding(8),
		Kit.list(Enum.FillDirection.Vertical, 2),
	})
	local oddsTitle = Kit.label({
		Parent = oddsBox,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "확률 (뽑을 때마다 같아요)",
		TextSize = 14,
		TextColor3 = Color.SubText,
		ZIndex = 5,
	})
	local oddsLabels: { TextLabel } = {}
	local drawButton = Kit.button("뽑기 (🎫 1장)", SPECIAL, {
		Name = "Draw",
		Parent = body,
		LayoutOrder = 6,
		Size = UDim2.new(0.8, 0, 0, 48),
		TextSize = 19,
		ZIndex = 5,
	})
	local hintLabel = Kit.label({
		Name = "Hint",
		Parent = body,
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Color.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})

	local metrics: UiLayout.Metrics? = nil
	local busy = false
	local lastState: RenderState? = nil
	local wonSkin: string? = nil
	local shakeConnection: RBXScriptConnection? = nil
	local spinConnection: RBXScriptConnection? = nil
	local prizeModel: Model? = nil
	local angle = 0
	local oddsText = 14

	local function text(base: number): number
		return if metrics then UiLayout.textSize(base, metrics) else base
	end

	local function stopShake()
		if shakeConnection then
			shakeConnection:Disconnect()
			shakeConnection = nil
		end
		lid.Rotation = 0
	end

	local function stopSpin()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end

	local function startSpin()
		if spinConnection or prizeModel == nil then
			return
		end
		spinConnection = RunService.RenderStepped:Connect(function(dt: number)
			angle = (angle + dt * SPIN_SPEED) % (math.pi * 2)
			local current = prizeModel
			if current then
				current:PivotTo(CFrame.Angles(0, angle, 0))
			end
		end)
	end

	local function clearPrize()
		stopSpin()
		if prizeModel then
			prizeModel:Destroy()
			prizeModel = nil
		end
		viewport.Visible = false
		prizeText.Visible = false
	end

	local function refreshButton()
		local state = lastState
		local can = state ~= nil and state.canDraw and not busy
		Kit.setEnabled(drawButton, can)
		if state and state.tickets <= 0 then
			hintLabel.Text = DrawLogic.message("NoTickets")
		elseif busy then
			hintLabel.Text = "두근두근…"
		else
			hintLabel.Text = "특 스킨은 뽑기로만 얻을 수 있어요"
		end
	end

	Kit.onClick(drawButton, function()
		if busy then
			return
		end
		actions.draw()
	end)
	Kit.onClick(wearButton, function()
		local skinId = wonSkin
		if skinId then
			actions.wear(skinId)
		end
	end)

	local panel = {} :: DrawPanel
	panel.frame = frame

	function panel.setOpen(_self: DrawPanel, open: boolean)
		frame.Visible = open
		if not open then
			stopSpin()
		else
			startSpin() -- 당첨 스킨을 보던 중에 다시 열면 회전을 이어가요
		end
	end

	function panel.isOpen(_self: DrawPanel): boolean
		return frame.Visible
	end

	function panel.render(_self: DrawPanel, state: RenderState)
		lastState = state
		ticketLabel.Text = DrawLogic.ticketText(state.tickets)
		for i, line in state.oddsLines do
			local label = oddsLabels[i]
			if label == nil then
				label = Kit.label({
					Parent = oddsBox,
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = oddsText,
					TextWrapped = true,
					ZIndex = 5,
				})
				oddsLabels[i] = label
			end
			label.Text = line
			label.Visible = true
		end
		for i = #state.oddsLines + 1, #oddsLabels do
			oddsLabels[i].Visible = false
		end
		refreshButton()
	end

	function panel.resetStage(_self: DrawPanel)
		stopShake()
		clearPrize()
		lid.Position = LID_HOME
		lid.TextTransparency = 0
		lid.Visible = true
		resultLabel.Text = ""
		wearButton.Visible = false
		wonSkin = nil
	end

	function panel.shake(_self: DrawPanel)
		panel:resetStage()
		busy = true
		refreshButton()
		local started = os.clock()
		shakeConnection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			-- 점점 세게 들썩여요
			local strength = math.min(1, t / DrawPanel.REVEAL_TIME)
			lid.Rotation = math.sin(t * 28) * (4 + 10 * strength)
			lid.Position = LID_HOME - UDim2.fromScale(0, math.abs(math.sin(t * 14)) * 0.05 * strength)
		end)
	end

	function panel.reveal(_self: DrawPanel, result: Types.DrawResult)
		stopShake()
		busy = false
		-- 뚜껑이 위로 날아가며 사라져요
		TweenService:Create(
			lid,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = LID_HOME - UDim2.fromScale(0, 0.6), TextTransparency = 1 }
		):Play()
		clearPrize()
		local skinId = result.skinId
		if result.kind == "Skin" and skinId ~= nil then
			wonSkin = skinId
			local ok, model = pcall(SushiBody.build, skinId, "Happy")
			if ok then
				prizeModel = model
				model:PivotTo(CFrame.Angles(0, angle, 0))
				model.Parent = viewport
				viewport.Visible = true
				startSpin()
			else
				warn(`[DrawPanel] preview failed: {model}`)
			end
			local skin = Skins.get(skinId)
			resultLabel.Text = DrawLogic.resultText(result, if skin then skin.displayName else nil)
			resultLabel.TextColor3 = SPECIAL
			wearButton.Text = "입기"
			wearButton.Visible = true
			Kit.setEnabled(wearButton, true)
		else
			prizeText.Text = `🍚 +{result.coins}`
			prizeText.Visible = true
			resultLabel.Text = DrawLogic.resultText(result)
			resultLabel.TextColor3 = if result.kind == "Duplicate" then SPECIAL else Color.Nori
			wearButton.Visible = false
		end
		refreshButton()
	end

	function panel.showMessage(_self: DrawPanel, message: string, isError: boolean)
		stopShake()
		busy = false
		lid.Rotation = 0
		lid.Position = LID_HOME
		resultLabel.Text = message
		resultLabel.TextColor3 = if isError then Color.Error else Color.Nori
		refreshButton()
	end

	function panel.setLayout(_self: DrawPanel, m: UiLayout.Metrics)
		metrics = m
		local buttonHeight = UiLayout.touchSize(44, m)
		header.Size = UDim2.new(1, 0, 0, buttonHeight)
		title.TextSize = text(22)
		title.Size = UDim2.new(1, -(UiLayout.touchSize(120, m) + GAP), 1, 0)
		backButton.Size = UDim2.new(0, UiLayout.touchSize(120, m), 1, 0)
		backButton.TextSize = text(16)
		body.Position = UDim2.fromOffset(0, buttonHeight + GAP)
		body.Size = UDim2.new(1, 0, 1, -(buttonHeight + GAP))
		body.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		stage.Size = UDim2.new(1, 0, 0, if m.compact then 140 else STAGE_HEIGHT)
		plate.TextSize = text(44)
		lid.TextSize = text(64)
		prizeText.TextSize = text(34)
		resultLabel.TextSize = text(20)
		resultLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(28, m, 20))
		wearButton.Size = UDim2.new(0.6, 0, 0, buttonHeight)
		wearButton.TextSize = text(17)
		ticketLabel.TextSize = text(24)
		ticketLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(30, m, 24))
		oddsTitle.TextSize = text(14)
		oddsTitle.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(20, m, 14))
		oddsText = text(15)
		for _, label in oddsLabels do
			label.TextSize = oddsText
		end
		drawButton.Size = UDim2.new(if m.compact then 1 else 0.8, 0, 0, UiLayout.touchSize(48, m))
		drawButton.TextSize = text(19)
		hintLabel.TextSize = text(14)
		hintLabel.Size = UDim2.new(1, 0, 0, UiLayout.lineHeight(22, m, 14))
	end

	return panel
end

return DrawPanel
