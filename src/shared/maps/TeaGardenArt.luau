--!strict
-- "찻잎 정원" 아트 데이터 껍데기 (m5-33). Roblox API를 쓰지 않아요 — lune 테스트에서 바로 불러요.
-- m5-33 껍데기 → m5-38가 이 파일을 덮어써요 (실제 장식·조명·소개 카메라).
-- 지금은 "모든 맵" 테스트(맵별 조명, 소개 카메라가 아레나 상자 + 40 안, 예산)를 통과하기 위한 최소 데이터만 있어요.
--   TeaGardenArt.decor() -> { DecorSpec }            빈 목록 (장식 없음)
--   TeaGardenArt.introCamera() -> { IntroPoint }     소개 카메라 경유점 2개 (origin 로컬)
--   TeaGardenArt.BUDGET / LIGHTING                   Extended 예산, 맵 조명 초안 ("해 질 녘 차밭", 로비와 ClockTime이 달라요)

local MapKitLogic = require(script.Parent.MapKitLogic)
local MapLighting = require(script.Parent.MapLighting)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type IntroPoint = { pos: Vec3, lookAt: Vec3 }

local TeaGardenArt = {}

TeaGardenArt.BUDGET = "Extended" :: MapKitLogic.BudgetTier

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- 맵 조명 초안: 해 질 녘 차밭
TeaGardenArt.LIGHTING = {
	ClockTime = 17.5,
	Brightness = 2,
	Ambient = c(150, 150, 120),
	OutdoorAmbient = c(160, 160, 130),
	Atmosphere = {
		Density = 0.3,
		Offset = 0.05,
		Color = c(220, 226, 190),
		Decay = c(150, 170, 120),
		Glare = 0,
		Haze = 1,
	},
} :: MapLighting.LightingPreset

function TeaGardenArt.decor(): { DecorSpec }
	return {}
end

-- ① 출발 자리 뒤 위에서 코스 쪽 → ② 출발 자리 가까이. 전부 판정 경계 + 40 안.
function TeaGardenArt.introCamera(): { IntroPoint }
	return {
		{ pos = v(0, 18, 6), lookAt = v(0, 0, -40) },
		{ pos = v(10, 6, -6), lookAt = v(0, 1, -36) },
	}
end

return TeaGardenArt
