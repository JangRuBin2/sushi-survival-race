--!strict
-- "깨끗하게! 설거지통" 아트 데이터 껍데기 (m5-33). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- m5-33 껍데기 → m5-34가 이 파일을 덮어써요 (실제 장식·조명·소개 카메라).
-- 지금은 "모든 맵" 테스트(맵별 조명, 소개 카메라가 아레나 상자 + 40 안, 예산)를 통과하기 위한 최소 데이터만 있어요.
--   DishSinkArt.decor() -> { DecorSpec }            빈 목록 (장식 없음)
--   DishSinkArt.introCamera() -> { IntroPoint }     소개 카메라 경유점 2개 (origin 로컬)
--   DishSinkArt.BUDGET / LIGHTING                   Extended 예산, 맵 조명 초안 ("밝은 주방 오전", 로비와 ClockTime이 달라요)

local MapKitLogic = require(script.Parent.MapKitLogic)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local DishSinkArt = {}

DishSinkArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 맵 조명 초안: 밝은 주방 오전
DishSinkArt.LIGHTING = {
	ClockTime = 10,
	Brightness = 2,
	Ambient = c(150, 170, 190),
	OutdoorAmbient = c(170, 190, 210),
	Atmosphere = {
		Density = 0.3,
		Offset = 0.05,
		Color = c(214, 232, 246),
		Decay = c(150, 180, 210),
		Glare = 0,
		Haze = 1,
	},
} :: MapLighting.LightingPreset

function DishSinkArt.decor(): { DecorSpec }
	return {}
end

-- ① 출발 자리 뒤 위에서 코스 쪽 → ② 출발 자리 가까이. 전부 판정 경계 + 40 안.
function DishSinkArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 16, 30), lookAt = v(0, 0, -60) },
		{ pos = v(8, 6, 22), lookAt = v(0, 1, 0) },
	}
end

return DishSinkArt
