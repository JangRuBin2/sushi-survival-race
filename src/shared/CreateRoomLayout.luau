--!strict
-- 방 만들기 창 크기 계산 (m6-14, 순수). 화면 모듈 CreateRoomDialog가 applyLayout에서 불러요.
--   휴대폰 가로(compact)면 두 열: 왼쪽 = 최대 인원 칩 + 공개 여부, 오른쪽 = 방 이름 + 요약·설명 + "방 만들기".
--   그 밖(PC·태블릿)은 한 열(최대 폭 MAX_WIDTH_SINGLE). 머리줄(제목 + X)은 고정, 본문은 넘치면 스크롤.
--   좌표는 모두 UIScale 안의 가상 px (화면 px / scale). 터치 크기·글씨는 UiLayout 규칙(m4-09) 그대로.
--   CreateRoomLayout.compute(m, virtualWidth, virtualHeight, chipCount) -> Layout

local UiLayout = require(script.Parent.UiLayout)

local CreateRoomLayout = {}

CreateRoomLayout.MAX_WIDTH_SINGLE = 480
CreateRoomLayout.MAX_WIDTH_TWO = 760
CreateRoomLayout.MIN_TWO_COLUMN_WIDTH = 560 -- 이보다 좁으면 compact여도 한 열
CreateRoomLayout.WIDTH_RATIO = 0.94
CreateRoomLayout.HEIGHT_RATIO = 0.92 -- 창 높이 상한 (화면 높이 대비)
CreateRoomLayout.TOP_MARGIN = 6 -- compact: 화면 위에서 띄우는 거리
CreateRoomLayout.PADDING = 16
CreateRoomLayout.PADDING_COMPACT = 12
CreateRoomLayout.GAP = 8
CreateRoomLayout.GAP_COMPACT = 6
CreateRoomLayout.COLUMN_GAP = 16
CreateRoomLayout.CHIP_GAP = 6
CreateRoomLayout.CHIP_MIN_WIDTH = 64

export type Layout = {
	twoColumn: boolean,
	width: number, -- 창 폭
	height: number, -- 창 높이 (머리줄 + 본문 + 안쪽 여백)
	padding: number,
	gap: number,
	columnGap: number,
	columnWidth: number, -- 한 열의 폭 (한 열이면 본문 폭)
	touch: number, -- 버튼·칩·입력칸 높이
	header: number, -- 머리줄 높이 (X 버튼 = touch 정사각형)
	label: number, -- 칸 이름 줄 높이
	chipWidth: number,
	chipsPerRow: number,
	chipRows: number,
	chips: number, -- 칩 묶음 높이
	hint: number, -- 공개 여부 설명 (두 줄까지)
	summary: number, -- "8명 · 공개" 줄
	message: number, -- 오류 줄
	left: number, -- 왼쪽 열(또는 한 열의 앞부분) 내용 높이
	right: number, -- 오른쪽 열(또는 한 열의 뒷부분) 내용 높이
	body: number, -- 본문 내용 높이
	bodyVisible: number, -- 본문이 실제로 보이는 높이
	scrolls: boolean, -- 본문이 넘쳐서 스크롤해야 하는가
	scrollBar: number,
	text: { title: number, label: number, button: number, hint: number },
}

local function stack(heights: { number }, gap: number): number
	local total = 0
	for i, h in heights do
		total += h
		if i > 1 then
			total += gap
		end
	end
	return total
end

function CreateRoomLayout.compute(
	m: UiLayout.Metrics,
	virtualWidth: number,
	virtualHeight: number,
	chipCount: number
): Layout
	local touch = UiLayout.touchSize(44, m)
	local compact = m.compact
	local padding = if compact then CreateRoomLayout.PADDING_COMPACT else CreateRoomLayout.PADDING
	local gap = if compact then CreateRoomLayout.GAP_COMPACT else CreateRoomLayout.GAP
	local scrollBar = UiLayout.scrollBarThickness(m)

	local available = virtualWidth * CreateRoomLayout.WIDTH_RATIO
	local twoColumn = compact and available >= CreateRoomLayout.MIN_TWO_COLUMN_WIDTH
	local width =
		math.min(available, if twoColumn then CreateRoomLayout.MAX_WIDTH_TWO else CreateRoomLayout.MAX_WIDTH_SINGLE)
	local inner = width - padding * 2
	local columnWidth = if twoColumn then (inner - CreateRoomLayout.COLUMN_GAP) / 2 else inner - scrollBar

	local textHint = UiLayout.textSize(14, m)
	local label = UiLayout.lineHeight(24, m, 16)
	local header = math.max(touch, UiLayout.lineHeight(40, m, 22))
	local hint = textHint * 2 + 8
	local summary = UiLayout.lineHeight(24, m, 16)
	local message = UiLayout.lineHeight(22, m, 16)

	local chipMin = math.max(touch, CreateRoomLayout.CHIP_MIN_WIDTH)
	local perRow, rows = UiLayout.gridRows(chipCount, columnWidth, chipMin, CreateRoomLayout.CHIP_GAP)
	perRow = math.max(perRow, 1)
	local chipWidth = (columnWidth - CreateRoomLayout.CHIP_GAP * (perRow - 1)) / perRow
	local chips = rows * touch + math.max(rows - 1, 0) * CreateRoomLayout.CHIP_GAP

	-- 왼쪽 = 인원 이름·칩·공개 여부 이름·세그먼트 (+ 한 열이면 설명)
	-- 오른쪽 = 방 이름·입력칸 (+ 두 열이면 설명)·요약·방 만들기·오류 줄
	local leftParts = { label, chips, label, touch }
	local rightParts = { label, touch }
	if twoColumn then
		table.insert(rightParts, hint)
	else
		table.insert(leftParts, hint)
	end
	table.insert(rightParts, summary)
	table.insert(rightParts, touch)
	table.insert(rightParts, message)
	local left = stack(leftParts, gap)
	local right = stack(rightParts, gap)
	local body = if twoColumn then math.max(left, right) else left + gap + right

	local maxHeight = virtualHeight * CreateRoomLayout.HEIGHT_RATIO
		- (if compact then CreateRoomLayout.TOP_MARGIN else 0)
	local chrome = padding * 2 + header + gap
	local bodyVisible = math.max(math.min(body, maxHeight - chrome), touch)
	local scrolls = body > bodyVisible + 0.5

	return {
		twoColumn = twoColumn,
		width = width,
		height = chrome + bodyVisible,
		padding = padding,
		gap = gap,
		columnGap = CreateRoomLayout.COLUMN_GAP,
		columnWidth = columnWidth,
		touch = touch,
		header = header,
		label = label,
		chipWidth = chipWidth,
		chipsPerRow = perRow,
		chipRows = rows,
		chips = chips,
		hint = hint,
		summary = summary,
		message = message,
		left = left,
		right = right,
		body = body,
		bodyVisible = bodyVisible,
		scrolls = scrolls,
		scrollBar = scrollBar,
		text = {
			title = UiLayout.textSize(22, m),
			label = UiLayout.textSize(16, m),
			button = UiLayout.textSize(18, m),
			hint = textHint,
		},
	}
end

return CreateRoomLayout
