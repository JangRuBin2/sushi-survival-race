--!strict
-- 효과음·배경음 이름 목록 (상수만). Sfx.play / Sfx.setMusic에는 여기 있는 이름만 써요.
-- 실제 소리 id·볼륨은 m3-08의 SfxLibrary가 정해요.

local SfxCues = {}

-- 효과음 (Sfx.play)
SfxCues.Effects = {
	-- UI·흐름
	"ButtonClick",
	"IntroWhoosh",
	"Go",
	"Qualified",
	"Eliminated", -- "먹혔다!" 스탬프
	"VictoryFanfare",
	"Overtime", -- 결승 연장전 경적 (m5-01)
	"TokenGet", -- 이벤트 재화 받음 (m5-07)
	"CodeRedeemed", -- 코드 보상 성공 (m5-10)
	"DrawReveal", -- 🎫 뽑기 결과 공개 (접시 뚜껑 열림, m5-31)
	"DrawWin", -- 🎫 뽑기 특 스킨 당첨 (m5-31)
	-- 스킨 움직임 (m5-32 고등어 [신선]: 사용자 결정 2026-10-14 3차)
	"FishFlop", -- 팔딱 (큰 팔딱·착지 팔딱 순간)
	"FishSplash", -- 첨벙 (물방울이 튀는 순간)
	-- 연출 팩 (m5-09)
	"CatMeow", -- 고양이 손님 탈락 연출
	"Fireworks", -- 불꽃놀이 우승 연출
	-- 탈락 연출
	"ChopstickClack",
	"Struggle",
	"SoyDip",
	"Chomp",
	"SpeechPop",
	"ChefHand",
	"MouthFall",
	-- 우승 연출
	"DoorBurst",
	"Splash",
	"FishClap",
	-- 조작
	"Dive",
	"DiveLand",
	"GrabStart",
	"Grabbed",
	"Knockdown",
	-- 장애물 (m3-09가 맵에 붙여요)
	"ChopstickWarn",
	"WasabiBoing",
	"SoySlow",
	"HotTileSizzle",
	"TileVanish",
	"SkewerWhoosh",
	"ChefHandWarn",
	"IkuraPop", -- 연어알 폭탄 터짐 (m5-04)
	"OilSplash", -- 기름 튐 (m5-05)
	"FanGust", -- 냉장고 송풍구 (m5-06)
	"JellyBoing", -- 젤리 튕김 (m5-06)
	"BounceBoing", -- 방방 미로 바운스 (m5-14)
	"BlockCreak", -- 블록탑 기둥이 뽑히기 직전 삐걱임 (m5-16)
	"CatToyBounce", -- 장난감 공에 맞음 (m5-17)
	"CatPawWarn", -- 고양이 발 경고 시작 (m5-17)
	"CatPawSwipe", -- 고양이 발에 밀리는 순간 (m5-17)
	"ClawLift", -- 집게가 구역을 들어 올림 (m5-19)
	-- 맵 3차 배치 (m5-33): 맵 스펙 m5-34~39는 이 목록을 고치지 않아요 (새 cue가 필요하면 m5-33 담당이 main에서)
	"SpongeSquish", -- 수세미에 밀리는 순간 (m5-34 dish-sink)
	"RailSwitch", -- 레일 방향이 바뀌기 0.4초 전 경고 (m5-35 space-conveyor)
	"MeteorWarn", -- 운석 경고 원이 뜰 때 (m5-35)
	"MeteorImpact", -- 운석이 떨어진 순간 (m5-35)
	"RiceBubble", -- 밥알이 끓어 터지는 순간 (m5-36 rice-cooker)
	"SteamWhistle", -- 증기 분사 경고, 밸브 휘파람 (m5-36)
	"SteamBlast", -- 증기 분사 시작 (m5-36)
	"MarketFishWarn", -- 생선 낙하 경고 (m5-37 fish-market)
	"MarketFishSlam", -- 생선이 떨어진 순간·팔딱 (m5-37)
	"IceBlockSlide", -- 얼음 블록이 줄을 바꿔 출발 (m5-37)
	"TeaCupRoll", -- 찻잔이 단을 옮기기 경고 (m5-38 tea-garden)
	"TeaFieldCrumble", -- 차밭 단이 무너지는 순간 (m5-38)
	"ClawSlam", -- 인형뽑기가 "쿵" 내리찍는 순간 (m5-39 onsen-claw)
	"OnsenRise", -- 물이 한 칸 오르고 데크가 가라앉기 경고 (m5-39)
}

-- 배경음 (Sfx.setMusic)
SfxCues.Music = {
	"Lobby",
	"Round",
	"Final",
	"Victory",
}

local effectSet: { [string]: boolean } = {}
for _, name in SfxCues.Effects do
	effectSet[name] = true
end
local musicSet: { [string]: boolean } = {}
for _, name in SfxCues.Music do
	musicSet[name] = true
end

-- 효과음과 배경음 이름 전부 (효과음 먼저)
function SfxCues.all(): { string }
	local list = table.clone(SfxCues.Effects)
	table.move(SfxCues.Music, 1, #SfxCues.Music, #list + 1, list)
	return list
end

function SfxCues.isEffect(name: string): boolean
	return effectSet[name] == true
end

function SfxCues.isMusic(name: string): boolean
	return musicSet[name] == true
end

return SfxCues
