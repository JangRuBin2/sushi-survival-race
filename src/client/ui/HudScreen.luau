--!strict
-- 매치 HUD 화면 (GDD 10): 라운드 번호, 맵 이름/규칙, 남은 시간, 통과 인원/목표 인원,
-- 라운드 소개·결과·우승 배너, 내 개인 결과(통과/탈락/우승 + 순위) 안내, 우승 때 최종 순위표.
-- Survival·결승(생존형)에서는 왼쪽 위에 "통과 n/목표" 대신 "남은 인원 n"을 보여요.
-- LobbyScreen/RoomScreen과 같은 ScreenGui 위에 떠 있고, 매치 중(room.state == "InMatch")에만 보여요.
-- compact(휴대폰 가로, m4-09): 위쪽 가운데 한 줄에 [인원] [라운드 · 맵 이름] [남은 시간], 내 결과는 그 아래
-- 오른쪽 (오른쪽 아래는 점프·다이브·잡기 버튼 자리). 글씨는 실제 14px 이상. PC 큰 화면은 예전 배치 그대로.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local Kit = require(script.Parent.RoomUiKit)
local UiScaleController = require(script.Parent.UiScaleController)

local Color = Kit.Color

export type HudScreen = {
	setVisible: (self: HudScreen, visible: boolean) -> (),
	setPhase: (self: HudScreen, phase: Types.MatchPhaseInfo) -> (),
	setProgress: (self: HudScreen, progress: Types.RoundProgress) -> (),
	-- keep = true면 4초 뒤 지우지 않고 clearPersonalResult·setVisible(false)까지 둬요 (우승 글씨, m3-09)
	showPersonalResult: (self: HudScreen, text: string, keep: boolean?) -> (),
	clearPersonalResult: (self: HudScreen) -> (),
}

local HudScreen = {}

HudScreen.ROOT_NAME = "Hud"
HudScreen.TOP_BANNER_NAME = "TopBanner"

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
		Name = HudScreen.ROOT_NAME,
		Parent = parent,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	-- 위 가운데: 라운드 번호 / 맵 이름 / 규칙
	-- 이름 "TopBanner"는 IntroScreen이 "출발!" 글씨를 이 아래에 두려고 찾아요 (Shared.IntroLayout)
	local topBarPadding = Kit.padding(10)
	local topBar = Kit.new("Frame", {
		Name = HudScreen.TOP_BANNER_NAME,
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 84),
		BackgroundColor3 = Color.Panel,
		BackgroundTransparency = 0.05,
	}, { Kit.corner(14), topBarPadding, Kit.list(Enum.FillDirection.Vertical, 2) })

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
	local standingsList = Kit.scrollList({
		Parent = standingsPanel,
		Size = UDim2.fromScale(1, 1),
	}, 2)

	local metrics = UiScaleController.metrics()
	local roundText = ""
	local mapName = ""

	-- compact에서는 라운드 번호를 맵 이름 줄에 붙여요 (한 줄 배치)
	local function refreshTitle()
		if metrics.compact and roundText ~= "" then
			mapLabel.Text = if mapName ~= "" then `{roundText} · {mapName}` else roundText
		else
			mapLabel.Text = mapName
		end
	end

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
		local rowText = UiLayout.textSize(16, metrics)
		local rowHeight = math.max(STANDING_ROW_HEIGHT, rowText + 8)
		for index, standing in sorted do
			local mine = standing.userId == myUserId
			local row = Kit.new("Frame", {
				Parent = standingsList,
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, rowHeight),
				BackgroundColor3 = if mine then Color.Egg else Color.Row,
			}, { Kit.corner(6) })
			Kit.label({
				Parent = row,
				Text = `{standing.place}등`,
				TextSize = rowText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(0, 56, 1, 0),
			})
			Kit.label({
				Parent = row,
				Text = if mine then `{standing.name} (나)` else standing.name,
				TextSize = rowText,
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

	-- 화면 크기 대응 (m4-09)
	local function applyLayout(m: UiLayout.Metrics)
		metrics = m
		local function text(base: number): number
			return UiLayout.textSize(base, m)
		end
		standingsList.ScrollBarThickness = UiLayout.scrollBarThickness(m)
		if m.compact then
			local mapText = text(22)
			local rowHeight = mapText + 12
			roundLabel.Visible = false
			ruleLabel.Visible = false
			mapLabel.TextSize = mapText
			mapLabel.Size = UDim2.fromScale(1, 1)
			topBar.Position = UDim2.new(0.5, 0, 0, 6)
			topBar.Size = UDim2.new(0.38, 0, 0, rowHeight + 8)
			topBarPadding.PaddingTop = UDim.new(0, 4)
			topBarPadding.PaddingBottom = UDim.new(0, 4)
			progressLabel.AnchorPoint = Vector2.new(1, 0)
			progressLabel.Position = UDim2.new(0.31, -8, 0, 6)
			progressLabel.Size = UDim2.new(0.3, 0, 0, rowHeight + 8)
			progressLabel.TextXAlignment = Enum.TextXAlignment.Right
			progressLabel.TextSize = text(16)
			timerLabel.AnchorPoint = Vector2.new(0, 0)
			timerLabel.Position = UDim2.new(0.69, 8, 0, 6)
			timerLabel.Size = UDim2.new(0.14, 0, 0, rowHeight + 8)
			timerLabel.TextXAlignment = Enum.TextXAlignment.Left
			timerLabel.TextSize = text(26)
			-- 내 결과: 위쪽 줄 오른쪽 (아래는 터치 버튼·관전 버튼 자리)
			personalLabel.AnchorPoint = Vector2.new(1, 0)
			personalLabel.Position = UDim2.new(1, -8, 0, rowHeight + 18)
			personalLabel.Size = UDim2.new(0.5, 0, 0, text(22) + 8)
			personalLabel.TextXAlignment = Enum.TextXAlignment.Right
			personalLabel.TextSize = text(22)
		else
			roundLabel.Visible = true
			ruleLabel.Visible = true
			mapLabel.TextSize = 22
			mapLabel.Size = UDim2.new(1, 0, 0, 26)
			topBar.Position = UDim2.new(0.5, 0, 0, 16)
			topBar.Size = UDim2.fromOffset(420, 84)
			topBarPadding.PaddingTop = UDim.new(0, 10)
			topBarPadding.PaddingBottom = UDim.new(0, 10)
			progressLabel.AnchorPoint = Vector2.new(0, 0)
			progressLabel.Position = UDim2.fromOffset(16, 16)
			progressLabel.Size = UDim2.fromOffset(240, 36)
			progressLabel.TextXAlignment = Enum.TextXAlignment.Left
			progressLabel.TextSize = 16
			timerLabel.AnchorPoint = Vector2.new(1, 0)
			timerLabel.Position = UDim2.new(1, -16, 0, 16)
			timerLabel.Size = UDim2.fromOffset(110, 36)
			timerLabel.TextXAlignment = Enum.TextXAlignment.Right
			timerLabel.TextSize = 26
			personalLabel.AnchorPoint = Vector2.new(0.5, 1)
			personalLabel.Position = UDim2.new(0.5, 0, 1, -24)
			personalLabel.Size = UDim2.new(1, 0, 0, 30)
			personalLabel.TextXAlignment = Enum.TextXAlignment.Center
			personalLabel.TextSize = 22
		end
		-- 가운데 배너: 부제목이 두 줄이어도 들어가게
		local subtitleText = text(18)
		local subtitleHeight = math.max(48, subtitleText * 2 + 8)
		bannerSubtitle.TextSize = subtitleText
		bannerSubtitle.Size = UDim2.new(1, 0, 0, subtitleHeight)
		banner.Size = UDim2.fromOffset(520, math.max(140, 28 + 40 + 6 + subtitleHeight))
		refreshTitle()
	end
	UiScaleController.onChanged(applyLayout)

	local personalToken = 0
	-- 우승 배너·순위표를 연출 뒤에 띄울 때, 그 사이 단계가 바뀌거나 HUD가 숨겨졌는지 확인용 (m3-05)
	local victoryToken = 0

	local screen = {}

	function screen.setVisible(_self: HudScreen, visible: boolean)
		root.Visible = visible
		if not visible then
			victoryToken += 1
			banner.Visible = false
			banner.Position = BANNER_POSITION
			clearStandings()
			mapKind = nil
			personalLabel.Text = ""
			endsAt = nil
		end
	end

	function screen.setPhase(_self: HudScreen, info: Types.MatchPhaseInfo)
		victoryToken += 1
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
			roundText = `라운드 {info.roundIndex}/{info.roundCount}`
			refreshTitle()
		end

		if info.phase == "Starting" then
			topBar.Visible = false
			progressLabel.Text = ""
			banner.Visible = true
			bannerTitle.Text = "매치 시작!"
			bannerSubtitle.Text = "곧 첫 라운드가 시작돼요"
		elseif info.phase == "RoundIntro" then
			topBar.Visible = true
			mapName = info.mapName or ""
			refreshTitle()
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
			local function showVictory()
				banner.Visible = true
				bannerTitle.Text = "🏆 우승!"
				bannerSubtitle.Text = `{winnerName}님이 우승했어요!`
				banner.Position = VICTORY_BANNER_POSITION
				showStandings(info.standings)
			end
			if info.winnerUserId then
				-- 우승 연출(VictoryCutsceneController)이 끝난 뒤에 띄워요. 그 사이 단계가 바뀌거나
				-- HUD가 숨겨지면(대기실로 돌아감) 띄우지 않아요.
				banner.Visible = false
				local mine = victoryToken
				task.delay(Config.Match.VictoryCutscene, function()
					if victoryToken == mine and root.Visible then
						showVictory()
					end
				end)
			else
				showVictory() -- 우승자가 없으면 연출도 없어서 바로
			end
		end
	end

	function screen.setProgress(_self: HudScreen, progress: Types.RoundProgress)
		progressLabel.Text = progressText(mapKind, progress)
	end

	function screen.showPersonalResult(_self: HudScreen, text: string, keep: boolean?)
		personalToken += 1
		local mine = personalToken
		personalLabel.Text = text
		if keep then
			return
		end
		task.delay(4, function()
			if personalToken == mine then
				personalLabel.Text = ""
			end
		end)
	end

	function screen.clearPersonalResult(_self: HudScreen)
		personalToken += 1
		personalLabel.Text = ""
	end

	return (screen :: any) :: HudScreen
end

return HudScreen
