--!strict
-- Race 부활 카운트다운 (m6-01, GDD 4): 정원이 차기 전에 떨어지거나 리셋하면 화면 가운데에
-- "다시 출발까지" + 큰 숫자(3 → 2 → 1) + "출발점에서 다시 달려요!"를 띄워요.
-- 서버 RoundService가 내 Player 속성 Attributes.RespawnAt(서버 시각)을 다는 동안만 보이고, 지우면 사라져요.
-- 화면 표시일 뿐 판정·권한에는 쓰지 않아요. 숫자는 순수 RespawnCountdownLogic.secondsLeft가 정해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local RespawnCountdownLogic = require(ReplicatedStorage.Shared.RespawnCountdownLogic)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Loc = require(script.Parent.Parent.Loc)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

local Color = Kit.Color

local RespawnCountdown = {}

RespawnCountdown.ROOT_NAME = "RespawnCountdown"

local REFRESH = 0.1 -- 숫자를 다시 계산하는 간격(초)
local POP_SCALE = 1.35 -- 숫자가 바뀔 때 잠깐 커졌다 돌아오는 크기
local POP_TIME = 0.25

function RespawnCountdown.start(parent: Instance)
	local player = Players.LocalPlayer

	local root = Kit.new("Frame", {
		Name = RespawnCountdown.ROOT_NAME,
		Parent = parent,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(360, 190),
		BackgroundColor3 = Color.Panel,
		BackgroundTransparency = 0.1,
		ZIndex = 20,
	}, { Kit.corner(18), Kit.padding(10), Kit.list(Enum.FillDirection.Vertical, 2) })
	local listLayout = root:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local title = Kit.label({
		Parent = root,
		LayoutOrder = 1,
		Text = "",
		TextSize = 22,
		TextColor3 = Color.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 21,
	})
	local number = Kit.label({
		Parent = root,
		LayoutOrder = 2,
		Text = "",
		TextSize = 96,
		TextColor3 = Color.Salmon,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 104),
		ZIndex = 21,
	})
	local numberScale = Kit.new("UIScale", { Parent = number, Scale = 1 })
	local subtitle = Kit.label({
		Parent = root,
		LayoutOrder = 3,
		Text = "",
		TextSize = 18,
		TextColor3 = Color.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 21,
	})

	-- 화면 크기 대응 (m4-09): 휴대폰에서도 글씨가 실제 14px 이상이 되게 해요
	local function applyLayout(m: UiLayout.Metrics)
		local titleSize = UiLayout.textSize(22, m)
		local numberSize = UiLayout.textSize(96, m)
		local subtitleSize = UiLayout.textSize(18, m)
		title.TextSize = titleSize
		title.Size = UDim2.new(1, 0, 0, titleSize + 6)
		number.TextSize = numberSize
		number.Size = UDim2.new(1, 0, 0, numberSize + 8)
		subtitle.TextSize = subtitleSize
		subtitle.Size = UDim2.new(1, 0, 0, subtitleSize + 6)
		root.Size =
			UDim2.fromOffset(math.max(360, subtitleSize * 18), titleSize + numberSize + subtitleSize + 20 + 20 + 4)
	end
	applyLayout(UiScaleController.metrics())
	UiScaleController.onChanged(applyLayout)

	local shown: number? = nil

	local function refresh()
		local seconds =
			RespawnCountdownLogic.secondsLeft(player:GetAttribute(Attributes.RespawnAt), workspace:GetServerTimeNow())
		if seconds == nil then
			if shown ~= nil then
				shown = nil
				root.Visible = false
			end
			return
		end
		if shown == nil then
			-- 처음 보일 때 언어에 맞는 문구를 채워요
			title.Text = Loc.t("hud.respawn.title")
			subtitle.Text = Loc.t("hud.respawn.sub")
			root.Visible = true
		end
		if seconds ~= shown then
			shown = seconds
			number.Text = tostring(seconds)
			numberScale.Scale = POP_SCALE
			TweenService:Create(
				numberScale,
				TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end

	player:GetAttributeChangedSignal(Attributes.RespawnAt):Connect(refresh)
	task.spawn(function()
		while root.Parent do
			if shown ~= nil or player:GetAttribute(Attributes.RespawnAt) ~= nil then
				refresh()
			end
			task.wait(REFRESH)
		end
	end)
	refresh()
end

return RespawnCountdown
