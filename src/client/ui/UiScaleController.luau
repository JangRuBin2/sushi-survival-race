--!strict
-- 화면 크기 배율 (m4-09). ScreenGui마다 UIScale을 붙여 휴대폰·작은 화면에서 UI 크기를 맞춰요.
--   UiScaleController.attach(screenGui)  배율을 붙일 ScreenGui를 등록해요. 새 화면(m4-08 CoinGui 등)도 만들 때 불러요.
-- m4-01 껍데기: attach는 아직 아무것도 하지 않아요. 동작은 m4-09 스펙이 이 파일에 채워요
-- (init.client.luau 등록은 m4-01이 끝냄).

local UiScaleController = {}

function UiScaleController.attach(_screenGui: ScreenGui) end

function UiScaleController.start(_gui: Instance) end

return UiScaleController
