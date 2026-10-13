--!strict
-- 클라이언트 부트스트랩. 클라이언트는 입력·UI·연출만 담당하고 판정은 하지 않아요.
-- 컨트롤러는 모두 start(gui)를 가져요. 카메라는 직접 바꾸지 않고 CameraDirector에 요청해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 서버가 리모트를 만들 때까지 기다려요
require(ReplicatedStorage.Shared.Remotes)

-- 맨 먼저: 화면 문구는 모두 Loc을 거쳐요 (m5-26). 번역기를 최대 3초 기다리고, 못 받으면 내장 카탈로그로
require(script.Loc).init()

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
	require(script.fx.WorldTextController), -- m5-26 서버가 키만 단 월드 글씨 (와사비 "매워!!")
	require(script.ui.ShopController), -- m4-13
	require(script.ui.AdminController), -- m5-02 (관리자에게만 패널을 만들어요)
	-- m5-03 껍데기 (각 스펙이 채워요)
	require(script.ui.OfferController), -- m5-08 "🎁 상점"
	require(script.ui.CodeController), -- m5-10 "🎟 코드"
	require(script.ui.ChatTagController), -- m5-08 [VIP] 채팅 태그
	require(script.input.IceController), -- m5-06 얼음 관성
	require(script.fx.MapDecorFxController), -- m5-20 맵 장식 로컬 애니메이션
	require(script.fx.MapLightingController), -- m5-23 맵 조명 분위기
}

for _, controller in CONTROLLERS do
	controller.start(gui)
end
