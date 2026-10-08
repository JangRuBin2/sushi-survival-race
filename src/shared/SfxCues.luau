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
