--!strict
-- "출발!" 글씨 배치 (사용자 수정 지시, m3-09). Roblox API 없는 순수 계산이에요.
-- HUD 위 가운데 배너(맵 이름·규칙, HudScreen "TopBanner")의 실제 아래 가장자리 픽셀을 받아,
-- 글씨가 가장 크게 커졌을 때(MAX_SCALE배)도 그 아래에 오도록 가운데 높이와 글씨 크기를 정해요.
-- 큰 화면에서는 예전처럼 화면 40% 높이·120px. 휴대폰 가로처럼 낮은 화면에서는 아래로 내리고,
-- 그래도 모자라면 글씨를 줄여요(MIN_TEXT_SIZE까지). 그보다 작은 화면이면 배너를 피하는 쪽을 우선해요.
-- 좌표는 모두 글씨가 붙은 ScreenGui(LobbyGui) 기준 픽셀이에요.

local IntroLayout = {}

-- HudScreen 위 배너의 기본 아래 끝 (y 16 + 높이 84). 배너를 못 찾거나 크기를 모를 때 써요.
IntroLayout.DEFAULT_BANNER_BOTTOM = 100

IntroLayout.PREFERRED_CENTER_SCALE = 0.4 -- 큰 화면에서의 가운데 높이 (예전 위치)
IntroLayout.TEXT_SIZE = 120 -- 큰 화면에서의 글씨 크기 (예전 크기)
IntroLayout.MIN_TEXT_SIZE = 36
IntroLayout.MAX_SCALE = 1.4 -- IntroScreen이 키우는 최대 배율 (UIScale, 끝날 때)
IntroLayout.GAP = 6 -- 배너 아래 끝과 가장 커진 글씨 위 끝 사이 여백
IntroLayout.BOTTOM_MARGIN = 8 -- 화면 아래 끝 여백
IntroLayout.SIDE_MARGIN = 8 -- 화면 양옆 여백
IntroLayout.TEXT_WIDTH_RATIO = 2.6 -- "출발!" 글자 폭 ≈ 글씨 크기 × 이 값 (넉넉하게)
IntroLayout.BOX_WIDTH_RATIO = 5 -- TextLabel 상자 크기 (글자보다 넉넉하게, 예전 600×160 = 120 × 5 × 1.34)
IntroLayout.BOX_HEIGHT_RATIO = 4 / 3

export type Layout = {
	centerY: number, -- 글씨 가운데 높이 (위에서 픽셀)
	textSize: number,
	boxWidth: number,
	boxHeight: number,
}

-- 글씨가 scale배일 때 위·아래 끝 (글자 높이 ≈ 글씨 크기)
function IntroLayout.textTop(layout: Layout, scale: number): number
	return layout.centerY - layout.textSize * scale / 2
end

function IntroLayout.textBottom(layout: Layout, scale: number): number
	return layout.centerY + layout.textSize * scale / 2
end

function IntroLayout.textWidth(layout: Layout, scale: number): number
	return layout.textSize * IntroLayout.TEXT_WIDTH_RATIO * scale
end

-- 배너 아래 끝: AbsolutePosition.Y + AbsoluteSize.Y - 글씨 ScreenGui의 AbsolutePosition.Y.
-- 값이 없거나 이상하면(배너 없음, 0 크기) 기본값.
function IntroLayout.bannerBottom(bannerTop: number?, bannerHeight: number?, guiTop: number?): number
	if bannerTop == nil or bannerHeight == nil or bannerHeight <= 0 then
		return IntroLayout.DEFAULT_BANNER_BOTTOM
	end
	local bottom = bannerTop + bannerHeight - (guiTop or 0)
	if bottom ~= bottom or bottom <= 0 then -- NaN·화면 밖
		return IntroLayout.DEFAULT_BANNER_BOTTOM
	end
	return bottom
end

function IntroLayout.compute(screenWidth: number, screenHeight: number, bannerBottom: number?): Layout
	local scale = IntroLayout.MAX_SCALE
	local top = (bannerBottom or IntroLayout.DEFAULT_BANNER_BOTTOM) + IntroLayout.GAP
	local bottom = screenHeight - IntroLayout.BOTTOM_MARGIN

	local byHeight = (bottom - top) / scale
	local byWidth = (screenWidth - IntroLayout.SIDE_MARGIN * 2) / (IntroLayout.TEXT_WIDTH_RATIO * scale)
	local textSize = math.floor(math.min(byHeight, byWidth, IntroLayout.TEXT_SIZE))
	textSize = math.max(textSize, IntroLayout.MIN_TEXT_SIZE)

	local half = textSize * scale / 2
	local centerY = IntroLayout.PREFERRED_CENTER_SCALE * screenHeight
	centerY = math.min(centerY, bottom - half) -- 아래로 넘치지 않게
	centerY = math.max(centerY, top + half) -- 배너는 꼭 피해요 (아래보다 우선)

	return {
		centerY = centerY,
		textSize = textSize,
		boxWidth = textSize * IntroLayout.BOX_WIDTH_RATIO,
		boxHeight = math.ceil(textSize * IntroLayout.BOX_HEIGHT_RATIO),
	}
end

return IntroLayout
