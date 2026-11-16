--!strict
-- 터치 조작 버튼의 겉모습 계산 (m6-14 C2, 순수 — Roblox API 없음). 그리기는 클라이언트 input/TouchButtonFace.
--   face(image, fallbackText) -> Face          아이콘 id가 있으면 그림, 없으면 지금 글씨(폴백)
--   coverKeys(fraction, alpha) -> {Key}?       쿨다운 덮개(동그란 판 전체)의 세로 UIGradient 투명도 점.
--                                              아래에서 fraction만큼 alpha로 어둡고 위는 투명. 0이면 nil(덮개 숨김)
--   strokeThickness(size) -> number            나무 테두리 두께(px): 버튼 크기의 6%, 2~6
--   cooldownLabel(seconds) -> number?          덮개 위 숫자 (올림, 0 이하면 nil)

local TouchButtonFaceLogic = {}

TouchButtonFaceLogic.COVER_ALPHA = 0.4 -- 덮개 투명도 (0 = 검정, 1 = 안 보임)
TouchButtonFaceLogic.ICON_SCALE = 0.78 -- 아이콘 = 버튼 지름 × 이 값 (PNG에 여백이 있어요)
TouchButtonFaceLogic.TEXT_INSET = 0.16 -- 글씨 폴백 여백 (각 변, 버튼 크기 비율)
TouchButtonFaceLogic.STROKE_RATIO = 0.06
TouchButtonFaceLogic.STROKE_MIN = 2
TouchButtonFaceLogic.STROKE_MAX = 6

export type Face = {
	image: string?, -- ImageLabel.Image (nil이면 아이콘 숨김)
	text: string, -- 버튼 글씨 ("" = 그림만)
}

export type Key = { time: number, value: number }

function TouchButtonFaceLogic.face(image: string?, fallbackText: string): Face
	if image ~= nil and image ~= "" then
		return { image = image, text = "" }
	end
	return { image = nil, text = fallbackText }
end

local EDGE = 0.001

function TouchButtonFaceLogic.coverKeys(fraction: number, alpha: number?): { Key }?
	local a = alpha or TouchButtonFaceLogic.COVER_ALPHA
	local f = math.clamp(if fraction == fraction then fraction else 0, 0, 1)
	if f <= 0 then
		return nil
	end
	if f >= 1 - EDGE then
		return { { time = 0, value = a }, { time = 1, value = a } }
	end
	-- 세로 그라디언트(Rotation 90): time 0 = 위, 1 = 아래
	local boundary = 1 - f -- EDGE보다 커요 (위에서 f ≥ 1 − EDGE를 걸렀어요)
	return {
		{ time = 0, value = 1 },
		{ time = boundary - EDGE, value = 1 },
		{ time = boundary, value = a },
		{ time = 1, value = a },
	}
end

function TouchButtonFaceLogic.strokeThickness(size: number): number
	local px = math.floor(size * TouchButtonFaceLogic.STROKE_RATIO + 0.5)
	return math.clamp(px, TouchButtonFaceLogic.STROKE_MIN, TouchButtonFaceLogic.STROKE_MAX)
end

function TouchButtonFaceLogic.cooldownLabel(seconds: number?): number?
	if seconds == nil or seconds ~= seconds or seconds <= 0 then
		return nil
	end
	return math.ceil(seconds)
end

return TouchButtonFaceLogic
