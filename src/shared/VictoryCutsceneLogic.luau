--!strict
-- 우승 연출 순수 로직 (m3-05, GDD 8): 박자 타임라인, 효과음 시각, 큰 글씨 문구, 인형·카메라 위치.
-- Roblox API를 쓰지 않아요 (lune 테스트). 좌표는 숫자 표 { x, y, z }이고 장면 로컬 좌표예요:
--   원점 = 가게 문 가운데 바닥, 앞 = -Z (문 → 부두 → 바다), 위 = +Y, 바닥(부두 윗면) y = 0.
-- 모든 시각은 6초 기준(BASE_DURATION)으로 정해 두고 duration에 비례해 늘리거나 줄여요.

local VictoryCutsceneLogic = {}

export type Vec = { number } -- { x, y, z }

export type Beat = {
	name: string,
	start: number,
	finish: number,
}

export type Cue = {
	name: string, -- Shared.SfxCues.Effects 이름
	at: number,
}

export type DollPose = {
	position: Vec, -- 인형 발바닥 위치 (장면 로컬)
	pitch: number, -- 앞으로 숙인 각도(라디안, + = 앞으로 엎어짐)
	yaw: number, -- 돌아선 각도(라디안, 0 = 앞(-Z)을 봄, pi = 가게 쪽을 봄)
}

export type CameraPose = {
	eye: Vec,
	target: Vec,
}

-- 장면을 짓는 곳 (월드 좌표). 로비(원점 근처)·아레나 슬롯(높이 300, x = 2000 간격)과 겹치지 않게 멀리.
VictoryCutsceneLogic.SCENE_ORIGIN = { 0, 1500, -4000 } :: Vec

VictoryCutsceneLogic.BASE_DURATION = 6

-- 박자 (6초 기준, 끝 = 다음 박자의 시작)
local BEATS: { Beat } = {
	{ name = "DoorBurst", start = 0, finish = 0.8 },
	{ name = "Run", start = 0.8, finish = 2.8 },
	{ name = "Dive", start = 2.8, finish = 3.8 },
	{ name = "Clap", start = 3.8, finish = 6 },
}

-- 장면 배치 (VictoryProps와 같이 써요)
VictoryCutsceneLogic.Layout = {
	DoorWidth = 7, -- 문 2짝 합친 폭
	DoorHeight = 9,
	DollStartZ = 4, -- 가게 안 (문 뒤)
	BurstEndZ = -4, -- 문을 박차고 나온 곳
	DockLength = 30, -- 문 앞(z = 0)부터 -Z로
	DockWidth = 8,
	WaterY = -5, -- 바다 수면 높이
	DiveLandZ = -40, -- 물에 빠지는 곳 (부두 끝에서 10 앞)
	FishCount = 5,
	FishRadius = 6, -- 인형 둘레 물고기 거리
}

local Layout = VictoryCutsceneLogic.Layout
local DOCK_END_Z = -Layout.DockLength
local RUN_END_Z = DOCK_END_Z + 1
local SPLASH_AT = 3.45 -- 입수 순간 (6초 기준)
local DIVE_PEAK = 4 -- 다이빙 점프 최고 높이 (바닥 위)
local HOP_HEIGHT = 1.2 -- 달릴 때 통통 튀는 높이
local HOP_COUNT = 5
local FLOAT_DEPTH = 2.6 -- 박수 때 인형 발바닥이 수면 아래 이만큼 (고개만 내밀기)

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function lerpVec(a: Vec, b: Vec, alpha: number): Vec
	return { lerp(a[1], b[1], alpha), lerp(a[2], b[2], alpha), lerp(a[3], b[3], alpha) }
end

local function addVec(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function easeOut(x: number): number
	return 1 - (1 - x) * (1 - x)
end

-- 박자 목록. 시간은 duration에 비례 (기본 6초 표의 duration/6 배).
function VictoryCutsceneLogic.timeline(duration: number): { Beat }
	local scale = duration / VictoryCutsceneLogic.BASE_DURATION
	local list: { Beat } = {}
	for _, beat in BEATS do
		table.insert(list, { name = beat.name, start = beat.start * scale, finish = beat.finish * scale })
	end
	return list
end

-- t초의 박자 이름. 범위 밖이면 nil. 박자 경계는 다음 박자, 마지막 끝 시각은 마지막 박자로 쳐요.
function VictoryCutsceneLogic.beatAt(timeline: { Beat }, t: number): string?
	for index, beat in timeline do
		local isLast = index == #timeline
		if t >= beat.start and (t < beat.finish or (isLast and t <= beat.finish)) then
			return beat.name
		end
	end
	return nil
end

-- 효과음과 울릴 시각 (시각 순서). 팡파르·문은 시작, 풍덩은 입수 순간, 박수는 Clap 시작.
function VictoryCutsceneLogic.cues(duration: number): { Cue }
	local scale = duration / VictoryCutsceneLogic.BASE_DURATION
	return {
		{ name = "VictoryFanfare", at = 0 },
		{ name = "DoorBurst", at = 0 },
		{ name = "Splash", at = SPLASH_AT * scale },
		{ name = "FishClap", at = BEATS[4].start * scale },
	}
end

function VictoryCutsceneLogic.splashTime(duration: number): number
	return SPLASH_AT * duration / VictoryCutsceneLogic.BASE_DURATION
end

-- 큰 글씨. 우승자 본인 화면은 "탈출 성공! 🏆", 다른 사람은 "{이름} 탈출 성공!"
function VictoryCutsceneLogic.titleText(winnerName: string, isMe: boolean): string
	if isMe then
		return "탈출 성공! 🏆"
	end
	return `{winnerName} 탈출 성공!`
end

-- 우승자 이름: standings에 저장된 이름을 먼저 (우승자가 나갔어도 나와요), 없으면 fallback.
function VictoryCutsceneLogic.winnerName(
	standings: { { userId: number, name: string } }?,
	winnerUserId: number,
	fallback: string
): string
	for _, standing in standings or {} do
		if standing.userId == winnerUserId then
			return standing.name
		end
	end
	return fallback
end

-- 문이 열린 정도 0~1 (DoorBurst 앞쪽 0.25초 만에 쾅 열리고 그대로).
function VictoryCutsceneLogic.doorOpen(t: number, duration: number): number
	local base = t * VictoryCutsceneLogic.BASE_DURATION / duration
	return easeOut(clamp01(base / 0.25))
end

-- t초의 인형 자세 (발바닥 위치는 장면 로컬)
function VictoryCutsceneLogic.dollPose(t: number, duration: number): DollPose
	local base = math.clamp(t * VictoryCutsceneLogic.BASE_DURATION / duration, 0, VictoryCutsceneLogic.BASE_DURATION)
	if base < BEATS[1].finish then
		-- 문을 박차고 튀어나와요 (작게 한 번 뜀)
		local alpha = base / BEATS[1].finish
		local z = lerp(Layout.DollStartZ, Layout.BurstEndZ, easeOut(alpha))
		return { position = { 0, math.sin(alpha * math.pi) * 1.5, z }, pitch = 0.25 * (1 - alpha), yaw = 0 }
	elseif base < BEATS[2].finish then
		-- 부두를 통통 튀며 달려요
		local alpha = (base - BEATS[2].start) / (BEATS[2].finish - BEATS[2].start)
		local z = lerp(Layout.BurstEndZ, RUN_END_Z, alpha)
		local hop = math.abs(math.sin(alpha * HOP_COUNT * math.pi)) * HOP_HEIGHT
		return { position = { 0, hop, z }, pitch = 0.15, yaw = 0 }
	elseif base < SPLASH_AT then
		-- 부두 끝에서 점프해 앞으로 몸을 날려요 (포물선, 머리부터)
		local alpha = (base - BEATS[3].start) / (SPLASH_AT - BEATS[3].start)
		local z = lerp(RUN_END_Z, Layout.DiveLandZ, alpha)
		-- y: 0에서 출발해 DIVE_PEAK까지 올랐다가 수면(WaterY)에 닿는 포물선
		local y = lerp(0, Layout.WaterY, alpha) + 4 * DIVE_PEAK * alpha * (1 - alpha)
		return { position = { 0, y, z }, pitch = lerp(0.2, math.rad(110), alpha), yaw = 0 }
	elseif base < BEATS[3].finish then
		-- 물속으로 쏙
		local alpha = (base - SPLASH_AT) / (BEATS[3].finish - SPLASH_AT)
		local y = lerp(Layout.WaterY, Layout.WaterY - 6, easeOut(alpha))
		return { position = { 0, y, Layout.DiveLandZ }, pitch = math.rad(110), yaw = 0 }
	end
	-- 물 위로 고개를 내밀고 가게 쪽(카메라)으로 돌아서 둥실둥실
	local alpha = (base - BEATS[4].start) / (BEATS[4].finish - BEATS[4].start)
	local rise = easeOut(clamp01(alpha / 0.2))
	local bob = math.sin(base * 2 * math.pi * 0.8) * 0.25
	local y = lerp(Layout.WaterY - 6, Layout.WaterY - FLOAT_DEPTH, rise) + bob * rise
	return {
		position = { 0, y, Layout.DiveLandZ },
		pitch = 0,
		yaw = math.pi * easeOut(clamp01(alpha / 0.25)),
	}
end

-- 물고기 n마리의 자리 (인형 둘레, 장면 로컬 { x, z } 오프셋). 첫 마리는 카메라 반대쪽을 피해 고르게.
function VictoryCutsceneLogic.fishRing(count: number, radius: number): { { number } }
	local ring = {}
	for i = 1, count do
		-- 카메라(+Z 쪽)를 가리지 않게 뒤쪽 반원 + 양옆에 펼쳐요 (-200도 ~ +20도)
		local angle = math.rad(-200 + (i - 1) * 220 / math.max(count - 1, 1))
		table.insert(ring, { math.cos(angle) * radius, math.sin(angle) * radius })
	end
	return ring
end

-- 물고기가 물 위로 올라온 정도 0~1과 박수 위상 (-1~1). Clap 전에는 (0, 0).
function VictoryCutsceneLogic.fishState(t: number, duration: number, index: number): (number, number)
	local base = t * VictoryCutsceneLogic.BASE_DURATION / duration
	local clapStart = BEATS[4].start
	if base < clapStart then
		return 0, 0
	end
	local since = base - clapStart - (index - 1) * 0.05
	local rise = easeOut(clamp01(since / 0.4))
	local clap = if since > 0.3 then math.sin((since - 0.3) * 2 * math.pi * 3) else 0
	return rise, clap
end

-- 카메라 (장면 로컬). DoorBurst = 문 앞 비스듬히, Run·Dive = 옆에서 따라감, Clap = 물 위 인형 정면.
function VictoryCutsceneLogic.cameraPose(t: number, duration: number): CameraPose
	local base = math.clamp(t * VictoryCutsceneLogic.BASE_DURATION / duration, 0, VictoryCutsceneLogic.BASE_DURATION)
	local doll = VictoryCutsceneLogic.dollPose(t, duration).position
	if base < BEATS[1].finish then
		return { eye = { 12, 6, -16 }, target = { 0, 3.5, -1 } }
	end
	local sideOffset: Vec = { 18, 6, 2 }
	if base < BEATS[3].finish then
		-- 인형 높이는 따라가지 않고(통통 튀어도 흔들리지 않게) z만 따라가요
		local target = { 0, 3, math.max(doll[3], Layout.DiveLandZ) }
		if base >= BEATS[3].start then
			-- 다이빙: 수면 쪽을 내려다봐요
			local alpha = clamp01((base - BEATS[3].start) / (BEATS[3].finish - BEATS[3].start))
			target[2] = lerp(3, Layout.WaterY + 1, alpha)
		end
		return { eye = addVec(target, sideOffset), target = target }
	end
	local alpha = easeOut(clamp01((base - BEATS[4].start) / 0.6))
	local target = { 0, Layout.WaterY + 1.5, Layout.DiveLandZ }
	local fromEye = addVec({ 0, Layout.WaterY + 1, Layout.DiveLandZ }, sideOffset)
	-- 부두 끝(DOCK_END_Z) 너머 물 위에서 봐요 (부두 위에 두면 판자 끝이 인형·물고기를 가려요, QA B1)
	local toEye = { 0, Layout.WaterY + 6, math.min(Layout.DiveLandZ + 9, DOCK_END_Z - 1) }
	return { eye = lerpVec(fromEye, toEye, alpha), target = target }
end

return VictoryCutsceneLogic
