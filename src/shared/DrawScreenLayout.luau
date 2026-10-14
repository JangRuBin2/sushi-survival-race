--!strict
-- 🎫 뽑기 화면 버튼 크기 (m5-31 QA B1). 순수 계산이라 Roblox API를 쓰지 않아요 (tests/m5-31-qa-fix.spec.luau).
-- 휴대폰(compact)에서도 누르는 칸이 실제 화면에서 Config.Ui.MinTouchSize(44px) 이상이 되게, 버튼 높이를
-- UIScale 안 좌표의 Offset으로 정해요 (UiLayout.touchSize). 가로는 화면이 정해요 (Scale).
--   heights(m) -> Heights      버튼별 높이 (UIScale 안 좌표)
--   realPx(units, m) -> number 그 높이가 실제 화면에서 몇 px인지 (UIScale = m.scale)

local UiLayout = require(script.Parent.UiLayout)

export type Heights = {
	start: number, -- "🎫 뽑기 시작하기"
	wear: number, -- 상세 "입기"
	expression: number, -- 표정 썸네일 (정사각형에 가깝게, 가로도 이 값 이상)
	info: number, -- ⓘ (정사각형)
	close: number, -- ✕ (창 닫기·ⓘ 창 닫기·상세 닫기, 정사각형)
	result: number, -- 결과 "확인"·"입기"
	tab: number, -- 휴대폰 탭
}

local DrawScreenLayout = {}

-- 기본 높이 (PC 큰 화면 기준)
DrawScreenLayout.BASE = {
	start = 52,
	wear = 44,
	expression = 52,
	info = 40,
	close = 44,
	result = 48,
	tab = 44,
} :: Heights

function DrawScreenLayout.heights(m: UiLayout.Metrics): Heights
	local base = DrawScreenLayout.BASE
	return {
		start = UiLayout.touchSize(base.start, m),
		wear = UiLayout.touchSize(base.wear, m),
		expression = UiLayout.touchSize(base.expression, m),
		info = UiLayout.touchSize(base.info, m),
		close = UiLayout.touchSize(base.close, m),
		result = UiLayout.touchSize(base.result, m),
		tab = UiLayout.touchSize(base.tab, m),
	}
end

function DrawScreenLayout.realPx(units: number, m: UiLayout.Metrics): number
	return units * m.scale
end

return DrawScreenLayout
