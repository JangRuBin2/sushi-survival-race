--!strict
-- 클라이언트 부트스트랩. 클라이언트는 입력·UI·연출만 담당하고 판정은 하지 않아요.
-- 컨트롤러는 모두 start(gui)를 가져요. 카메라는 직접 바꾸지 않고 CameraDirector에 요청해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 서버가 리모트를 만들 때까지 기다려요
require(ReplicatedStorage.Shared.Remotes)

local gui = require(script.ui.LobbyController).start()

local CONTROLLERS = {
	require(script.ProfileStore), -- 맨 먼저: 다른 컨트롤러가 ProfileStore.get/changed를 읽어요 (m4-01)
	require(script.Sfx), -- 그다음: 다른 컨트롤러가 Sfx.play를 불러요
	require(script.ui.HudController),
	require(script.ui.SpectateController),
	require(script.fx.CharacterFxController),
	require(script.fx.EliminationCutsceneController),
	require(script.fx.IntroController),
	require(script.fx.VictoryCutsceneController),
	require(script.input.DiveController),
	require(script.input.GrabController),
	require(script.ui.UiScaleController), -- m4-09
	require(script.ui.CoinController), -- m4-08
	require(script.fx.LobbyFxController), -- m4-06
	require(script.ui.ShopController), -- m4-13
}

for _, controller in CONTROLLERS do
	controller.start(gui)
end
