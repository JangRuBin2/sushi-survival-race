--!strict
-- 효과음·배경음 표 (순수 데이터 + 함수, Roblox API 없음). 클라이언트 Sfx와 서버(m3-09 장애물)가 같이 읽어요.
-- 이름은 Shared.SfxCues와 1:1이에요 (tests/sfx-library.spec.luau가 확인).
--
-- 소리 출처: 에셋 업로드 없이 쓰려고 Roblox 클라이언트에 들어 있는 기본 소리(rbxasset://sounds/...)로 채웠어요.
-- 지금 클라이언트에 들어 있는 기본 소리는 11개뿐이라 pitch로 느낌을 바꿔 여러 cue에 나눠 썼어요.
-- id가 nil인 cue는 소리가 나지 않아요. 사용자가 Creator Store에서 고른 "rbxassetid://..."를 넣으면 바로 나와요.
-- 배경음 4개는 기본이 무음이에요 (사용자가 곡 id를 넣으면 동작).

export type Group = "Sfx" | "Music"

export type Entry = {
	id: string?, -- "rbxasset://sounds/..." 또는 "rbxassetid://..." (nil이면 소리 없음)
	group: Group,
	volume: number, -- 0~1
	pitch: number?, -- 기본 재생 속도 (없으면 1). 같은 기본 소리를 다른 cue에 쓸 때 느낌을 바꿔요
	pitchJitter: number?, -- 반복해도 덜 지루하게 ±비율 (예: 0.05)
	looped: boolean?, -- 배경음은 true
}

local SOUNDS = {
	falling = "rbxasset://sounds/action_falling.ogg",
	footsteps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	getUp = "rbxasset://sounds/action_get_up.mp3",
	jump = "rbxasset://sounds/action_jump.mp3",
	jumpLand = "rbxasset://sounds/action_jump_land.mp3",
	swim = "rbxasset://sounds/action_swim.mp3",
	explosion = "rbxasset://sounds/impact_explosion_03.mp3",
	water = "rbxasset://sounds/impact_water.mp3",
	oof = "rbxasset://sounds/oof.ogg",
	ouch = "rbxasset://sounds/ouch.ogg",
	click = "rbxasset://sounds/volume_slider.ogg",
}

local function sfx(id: string?, volume: number, pitch: number?, pitchJitter: number?): Entry
	return { id = id, group = "Sfx", volume = volume, pitch = pitch, pitchJitter = pitchJitter }
end

local function music(id: string?, volume: number): Entry
	return { id = id, group = "Music", volume = volume, looped = true }
end

local SfxLibrary = {}

SfxLibrary.Entries = {
	-- UI·흐름
	ButtonClick = sfx(SOUNDS.click, 0.6, 1.2, 0.05),
	IntroWhoosh = sfx(SOUNDS.falling, 0.5, 1.4),
	Go = sfx(SOUNDS.jump, 0.9, 1.3),
	Qualified = sfx(SOUNDS.getUp, 0.9, 1.4),
	Eliminated = sfx(SOUNDS.oof, 0.9),
	VictoryFanfare = sfx(nil, 0.9),
	Overtime = sfx(nil, 0.9), -- 결승 연장전 경적·징 (m5-01, id는 사용자가 고를 때까지 무음)
	-- m5-03: id는 사용자가 고를 때까지 무음 (USER-TODO A2)
	TokenGet = sfx(nil, 0.8), -- 이벤트 재화 받음 (m5-07)
	CodeRedeemed = sfx(nil, 0.8), -- 코드 보상 성공 (m5-10)
	-- 연출 팩 (m5-09)
	CatMeow = sfx(nil, 0.8),
	Fireworks = sfx(nil, 0.8),
	-- 탈락 연출
	ChopstickClack = sfx(SOUNDS.jumpLand, 0.8, 1.6, 0.05),
	Struggle = sfx(SOUNDS.ouch, 0.7, 1.1, 0.08),
	SoyDip = sfx(SOUNDS.water, 0.8, 1.1, 0.05),
	Chomp = sfx(SOUNDS.jumpLand, 1, 0.7, 0.05),
	SpeechPop = sfx(nil, 0.7),
	ChefHand = sfx(nil, 0.8),
	MouthFall = sfx(SOUNDS.falling, 0.6, 0.9),
	-- 우승 연출
	DoorBurst = sfx(SOUNDS.explosion, 0.6, 1.2),
	Splash = sfx(SOUNDS.water, 0.9, 0.9),
	FishClap = sfx(nil, 0.7),
	-- 조작
	Dive = sfx(SOUNDS.jump, 0.7, 0.85, 0.05),
	DiveLand = sfx(SOUNDS.jumpLand, 0.7, 1, 0.05),
	GrabStart = sfx(nil, 0.7),
	Grabbed = sfx(SOUNDS.ouch, 0.7, 1.3, 0.05),
	Knockdown = sfx(SOUNDS.jumpLand, 0.9, 0.6, 0.05),
	-- 장애물 (m3-09가 맵에 붙여요)
	ChopstickWarn = sfx(nil, 0.7),
	WasabiBoing = sfx(SOUNDS.jump, 0.8, 1.7, 0.05),
	SoySlow = sfx(SOUNDS.swim, 0.6, 0.8, 0.05),
	HotTileSizzle = sfx(nil, 0.6),
	TileVanish = sfx(SOUNDS.footsteps, 0.7, 0.7, 0.05),
	SkewerWhoosh = sfx(SOUNDS.falling, 0.6, 1.6, 0.05),
	ChefHandWarn = sfx(nil, 0.7),
	IkuraPop = sfx(nil, 0.8), -- 연어알 폭탄 (m5-04)
	OilSplash = sfx(nil, 0.7), -- 튀는 기름 (m5-05)
	FanGust = sfx(nil, 0.6), -- 송풍구 (m5-06)
	JellyBoing = sfx(nil, 0.8), -- 젤리 (m5-06)
	-- 배경음 (Sfx.setMusic) — 기본 무음
	Lobby = music(nil, 0.6),
	Round = music(nil, 0.6),
	Final = music(nil, 0.6),
	Victory = music(nil, 0.7),
} :: { [string]: Entry }

function SfxLibrary.get(name: string): Entry?
	return SfxLibrary.Entries[name]
end

-- 지금 상태에 맞는 배경음 이름.
-- 매치가 아니면(로비·방 대기실) Lobby, 매치 중 Victory면 Victory,
-- 그 밖의 단계는 Round (마지막 라운드면 Final).
function SfxLibrary.musicFor(inMatch: boolean, phase: string?, roundIndex: number?, roundCount: number?): string?
	if not inMatch then
		return "Lobby"
	end
	if phase == "Victory" then
		return "Victory"
	end
	if roundIndex ~= nil and roundCount ~= nil and roundIndex >= roundCount then
		return "Final"
	end
	return "Round"
end

return SfxLibrary
