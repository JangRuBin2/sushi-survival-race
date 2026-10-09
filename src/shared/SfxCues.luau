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
