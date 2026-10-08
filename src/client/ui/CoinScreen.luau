--!strict
-- 밥알 코인 화면 (m4-08): 왼쪽 위 코인 배지, 그 아래 지급 토스트, 화면 아래 가운데 매치 정산 한 줄.
--   배지·토스트: 자기 ScreenGui `CoinGui` (ScreenInsets = TopbarSafeInsets) — Roblox 위쪽 바 줄의 왼쪽 끝,
--     음소거 버튼(SoundGui, 오른쪽 끝)의 반대편. 게임 화면(LobbyGui)은 위쪽 바 아래에만 그려져 겹치지 않아요.
--   정산 한 줄: 위쪽 바 칸 밖이라 두 번째 ScreenGui `CoinSummaryGui` (화면 아래 15% 안, 순위표 패널 아래 여백).
-- 판정·지급과 무관한 표시만 해요. 리모트 연결은 CoinController.

local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

local MARGIN = 4 -- 위쪽 바 안 위아래·왼쪽 여백 (음소거 버튼과 같아요)
local BADGE_MAX_HEIGHT = 36
local TOAST_HEIGHT = 30
local TOAST_GAP = 4
local TOAST_SHOW = 1.5 -- 토스트가 떠 있는 시간 (초)
local TOAST_FADE = 0.3
local SUMMARY_HEIGHT = 36
local SUMMARY_BOTTOM = 20 -- 화면 아래에서 띄우는 거리(px)

export type CoinScreen = {
	setCoins: (self: CoinScreen, coins: number, persistent: boolean) -> (),
	toast: (self: CoinScreen, text: string) -> (),
	showSummary: (self: CoinScreen, text: string) -> (),
	hideSummary: (self: CoinScreen) -> (),
	guis: { ScreenGui },
}

local CoinScreen = {}

function CoinScreen.new(playerGui: Instance): CoinScreen
	local gui = Kit.new("ScreenGui", {
		Name = "CoinGui",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
		Parent = playerGui,
	}) :: ScreenGui

	local badge = Kit.new("Frame", {
		Name = "CoinBadge",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.new(0, 0, 1, -MARGIN * 2),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.3,
	}, {
		Kit.corner(8),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, BADGE_MAX_HEIGHT) }),
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Kit.list(Enum.FillDirection.Horizontal, 6, { VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local coinLabel = Kit.label({
		Name = "Coins",
		Parent = badge,
		LayoutOrder = 1,
		Text = "🍚 0",
		TextSize = 18,
		TextColor3 = Color.White,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
	})
	local unsavedLabel = Kit.label({
		Name = "Unsaved",
		Parent = badge,
		LayoutOrder = 2,
		Visible = false,
		Text = "(저장 안 됨)",
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
	})

	-- 배지 아래 토스트 줄 (위쪽 바 칸 밖으로 내려와 그려져요)
	local toastList = Kit.new("Frame", {
		Name = "Toasts",
		Parent = gui,
		Position = UDim2.new(0, MARGIN, 1, TOAST_GAP),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { Kit.list(Enum.FillDirection.Vertical, TOAST_GAP) })

	local summaryGui = Kit.new("ScreenGui", {
		Name = "CoinSummaryGui",
		ResetOnSpawn = false,
		DisplayOrder = 60, -- 우승 연출(50) 위
		Enabled = false,
		Parent = playerGui,
	}) :: ScreenGui
	local summaryLabel = Kit.label({
		Name = "Summary",
		Parent = summaryGui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -SUMMARY_BOTTOM),
		Size = UDim2.fromOffset(0, SUMMARY_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color.Panel,
		TextSize = 20,
		TextColor3 = Color.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
	})
	Kit.corner(10).Parent = summaryLabel
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = summaryLabel,
	})

	local toastOrder = 0

	local screen = {} :: CoinScreen
	screen.guis = { gui, summaryGui }

	function screen.setCoins(_self: CoinScreen, coins: number, persistent: boolean)
		coinLabel.Text = `🍚 {coins}`
		unsavedLabel.Visible = not persistent
	end

	function screen.toast(_self: CoinScreen, text: string)
		toastOrder += 1
		local label = Kit.label({
			Name = "Toast",
			Parent = toastList,
			LayoutOrder = toastOrder,
			Text = text,
			TextSize = 17,
			TextColor3 = Color.Text,
			BackgroundColor3 = Color.Egg,
			BackgroundTransparency = 0.05,
			TextTruncate = Enum.TextTruncate.None,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, TOAST_HEIGHT),
		})
		Kit.corner(8).Parent = label
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = label })
		task.delay(TOAST_SHOW, function()
			if label.Parent == nil then
				return
			end
			-- 사라질 때: 글씨·배경이 흐려져요 (UIListLayout 안이라 위치는 줄 세움이 정해요)
			local start = os.clock()
			while label.Parent and os.clock() - start < TOAST_FADE do
				local alpha = (os.clock() - start) / TOAST_FADE
				label.TextTransparency = alpha
				label.BackgroundTransparency = 0.05 + 0.95 * alpha
				task.wait()
			end
			label:Destroy()
		end)
	end

	function screen.showSummary(_self: CoinScreen, text: string)
		summaryLabel.Text = text
		summaryGui.Enabled = true
	end

	function screen.hideSummary(_self: CoinScreen)
		summaryGui.Enabled = false
	end

	return screen
end

return CoinScreen
