--!strict
-- 매치 HUD 화면 (GDD 10): 라운드 번호, 맵 이름/규칙, 남은 시간, 통과 인원/목표 인원,
-- 라운드 소개·결과·우승 배너, 내 개인 결과(통과/탈락/우승 + 순위) 안내, 우승 때 최종 순위표.
-- Survival·결승(생존형)에서는 왼쪽 위에 "통과 n/목표" 대신 "남은 인원 n"을 보여요.
-- LobbyScreen/RoomScreen과 같은 ScreenGui 위에 떠 있고, 매치 중(room.state == "InMatch")에만 보여요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Kit = require(script.Parent.RoomUiKit)

local Color = Kit.Color

export type HudScreen = {
	setVisible: (self: HudScreen, visible: boolean) -> (),
	setPhase: (self: HudScreen, phase: Types.MatchPhaseInfo) -> (),
	setProgress: (self: HudScreen, progress: Types.RoundProgress) -> (),
	showPersonalResult: (self: HudScreen, text: string) -> (),
}

local HudScreen = {}

local BANNER_POSITION = UDim2.fromScale(0.5, 0.42)
local VICTORY_BANNER_POSITION = UDim2.fromScale(0.5, 0.2)
local STANDING_ROW_HEIGHT = 28

-- 진행 표시 문구. 생존형 라운드(Survival, 결승)는 통과 목표가 의미 없어서 남은 인원만 보여요.
local function progressText(kind: Types.MapKind?, progress: Types.RoundProgress): string
	if kind == "Survival" or kind == "Final" then
		return `남은 인원 {progress.remaining}`
	end
	return `통과 {progress.passed}/{progress.target} · 남은 인원 {progress.remaining}`
end

function HudScreen.new(parent: Instance, nameOf: (userId: number) -> string, myUserId: number): HudScreen
	local root = Kit.new("Frame", {
		Name = "Hud",
		Parent = parent,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	-- 위 가운데: 라운드 번호 / 맵 이름 / 규칙
	local topBar = Kit.new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 84),
		BackgroundColor3 = Color.Panel,
		BackgroundTransparency = 0.05,
	}, { Kit.corner(14), Kit.padding(10), Kit.list(Enum.FillDirection.Vertical, 2) })

	local roundLabel = Kit.label({
		Parent = topBar,
		LayoutOrder = 1,
		TextSize = 16,
		TextColor3 = Color.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
	})
	local mapLabel = Kit.label({
		Parent = topBar,
		LayoutOrder = 2,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
	})
	local ruleLabel = Kit.label({
		Parent = topBar,
		LayoutOrder = 3,
		TextColor3 = Color.SubText,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
	})

	-- 오른쪽 위: 남은 시간
	local timerLabel = Kit.label({
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		TextSize = 26,
		TextColor3 = Color.Salmon,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(110, 36),
	})

	-- 왼쪽 위: 통과 인원 / 목표 / 남은 인원
	local progressLabel = Kit.label({
		Parent = root,
		Position = UDim2.fromOffset(16, 16),
		TextSize = 16,
		Size = UDim2.fromOffset(240, 36),
	})

	-- 가운데: 라운드 소개·결과·우승 배너
	local banner = Kit.new("Frame", {
		Parent = root,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = BANNER_POSITION,
		Size = UDim2.fromOffset(520, 140),
		BackgroundColor3 = Color.Backdrop,
		BackgroundTransparency = 0.2,
	}, {
		Kit.corner(18),
		Kit.padding(14),
		Kit.list(Enum.FillDirection.Vertical, 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local bannerTitle = Kit.label({
		Parent = banner,
		LayoutOrder = 1,
		TextSize = 30,
		TextColor3 = Color.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
	})
	local bannerSubtitle = Kit.label({
		Parent = banner,
		LayoutOrder = 2,
		TextSize = 18,
		TextColor3 = Color.White,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 48),
	})

	-- 아래 가운데: 내 개인 결과
	local personalLabel = Kit.label({
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
	})

	-- 우승 배너 아래: 최종 순위표 (최대 24줄, 넘치면 스크롤)
	local standingsPanel = Kit.new("Frame", {
		Parent = root,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 82),
		Size = UDim2.new(0, 380, 0.8, -170),
		BackgroundColor3 = Color.Panel,
		BackgroundTransparency = 0.05,
	}, { Kit.corner(14), Kit.padding(10) })
	local standingsList = Kit.new("ScrollingFrame", {
		Parent = standingsPanel,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color.SubText,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, { Kit.list(Enum.FillDirection.Vertical, 2) })

	local function clearStandings()
		standingsPanel.Visible = false
		for _, child in standingsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function showStandings(standings: { Types.Standing }?)
		clearStandings()
		if standings == nil or #standings == 0 then
			return
		end
		local sorted = table.clone(standings)
		table.sort(sorted, function(a, b)
			return a.place < b.place
		end)
		for index, standing in sorted do
			local mine = standing.userId == myUserId
			local row = Kit.new("Frame", {
				Parent = standingsList,
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, STANDING_ROW_HEIGHT),
				BackgroundColor3 = if mine then Color.Egg else Color.Row,
			}, { Kit.corner(6) })
			Kit.label({
				Parent = row,
				Text = `{standing.place}등`,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0, 56, 1, 0),
			})
			Kit.label({
				Parent = row,
				Text = if mine then `{standing.name} (나)` else standing.name,
				TextSize = 16,
				Position = UDim2.fromOffset(60, 0),
				Size = UDim2.new(1, -68, 1, 0),
			})
		end
		standingsPanel.Visible = true
	end

	local endsAt: number? = nil
	local mapKind: Types.MapKind? = nil

	local function refreshTimer()
		if endsAt == nil then
			timerLabel.Text = ""
			return
		end
		local left = math.max(0, math.ceil((endsAt :: number) - workspace:GetServerTimeNow()))
		timerLabel.Text = `⏱ {left}초`
	end

	-- RoomScreen의 카운트다운 표시와 같은 패턴: 매 프레임 다시 그리지 않고 짧은 간격으로만 갱신해요.
	task.spawn(function()
		while root.Parent do
			if root.Visible then
				refreshTimer()
			end
			task.wait(0.25)
		end
	end)

	local personalToken = 0

	local screen = {}

	function screen.setVisible(_self: HudScreen, visible: boolean)
		root.Visible = visible
		if not visible then
			banner.Visible = false
			banner.Position = BANNER_POSITION
			clearStandings()
			mapKind = nil
			personalLabel.Text = ""
			endsAt = nil
		end
	end

	function screen.setPhase(_self: HudScreen, info: Types.MatchPhaseInfo)
		endsAt = info.endsAt
		refreshTimer()
		if info.mapKind then
			mapKind = info.mapKind
		end
		if info.phase ~= "Victory" then
			banner.Position = BANNER_POSITION
			clearStandings()
		end

		if info.roundIndex and info.roundCount then
			roundLabel.Text = `라운드 {info.roundIndex} / {info.roundCount}`
		end

		if info.phase == "Starting" then
			topBar.Visible = false
			progressLabel.Text = ""
			banner.Visible = true
			bannerTitle.Text = "매치 시작!"
			bannerSubtitle.Text = "곧 첫 라운드가 시작돼요"
		elseif info.phase == "RoundIntro" then
			topBar.Visible = true
			mapLabel.Text = info.mapName or ""
			ruleLabel.Text = info.rule or ""
			progressLabel.Text = ""
			banner.Visible = true
			bannerTitle.Text = info.mapName or ""
			bannerSubtitle.Text = info.rule or ""
		elseif info.phase == "RoundActive" then
			banner.Visible = false
		elseif info.phase == "RoundResults" then
			banner.Visible = true
			bannerTitle.Text = "라운드 종료!"
			bannerSubtitle.Text = "다음 라운드를 준비하고 있어요"
		elseif info.phase == "Victory" then
			topBar.Visible = false
			progressLabel.Text = ""
			timerLabel.Text = ""
			banner.Visible = true
			bannerTitle.Text = "🏆 우승!"
			local winnerName = "?"
			if info.winnerUserId then
				winnerName = nameOf(info.winnerUserId)
				-- 우승자가 이미 나갔어도 순위표에 저장된 이름을 써요
				for _, standing in info.standings or {} do
					if standing.userId == info.winnerUserId then
						winnerName = standing.name
					end
				end
			end
			bannerSubtitle.Text = `{winnerName}님이 우승했어요!`
			banner.Position = VICTORY_BANNER_POSITION
			showStandings(info.standings)
		end
	end

	function screen.setProgress(_self: HudScreen, progress: Types.RoundProgress)
		progressLabel.Text = progressText(mapKind, progress)
	end

	function screen.showPersonalResult(_self: HudScreen, text: string)
		personalToken += 1
		local mine = personalToken
		personalLabel.Text = text
		task.delay(4, function()
			if personalToken == mine then
				personalLabel.Text = ""
			end
		end)
	end

	return (screen :: any) :: HudScreen
end

return HudScreen
