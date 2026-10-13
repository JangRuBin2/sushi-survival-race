--!strict
-- 맵별 조명 분위기 (m5-23). Roblox API를 쓰지 않는 순수 모듈이에요.
-- Lighting은 전역 하나라서 서버는 로비 조명만 두고, 클라이언트(MapLightingController)가 카메라가 들어가 있는
-- 아레나의 맵 조명으로 로컬에서 바꿨다가 나오면 로비 조명으로 되돌려요. 미리보기 렌더러(tools/render-map)도
-- 같은 프리셋으로 해·안개·색 보정을 맞춰요.
--
--   MapLighting.validate(preset) -> string?     맵 모듈의 lighting 필드 검사 (모르는 키·범위 밖 값이면 이유)
--   MapLighting.resolve(preset?) -> Resolved    빠진 값은 로비 조명(LobbyLayout.LIGHTING) + DEFAULTS로 채운 완전한 프리셋
--   MapLighting.LOBBY                           resolve(nil)
--   MapLighting.lerp(a, b, t) -> Resolved       두 프리셋 사이 (t: 0~1, 숫자·색 모두 선형)
--   MapLighting.PRESETS[mapId]                  기존 맵 6개의 분위기 (맵 모듈이 lighting = MapLighting.PRESETS["<id>"])
--
-- 키 이름은 Roblox 속성 이름과 같아요 (Lighting.ClockTime, Atmosphere.Density …). 색은 { r, g, b } 0~255.

local LobbyLayout = require(script.Parent.Parent.LobbyLayout)

export type RGB = { r: number, g: number, b: number }

export type AtmosphereSpec = {
	Density: number?,
	Offset: number?,
	Color: RGB?,
	Decay: RGB?,
	Glare: number?,
	Haze: number?,
}
export type ColorCorrectionSpec = {
	Brightness: number?,
	Contrast: number?,
	Saturation: number?,
	TintColor: RGB?,
}
export type BloomSpec = { Intensity: number?, Size: number?, Threshold: number? }
export type SunRaysSpec = { Intensity: number?, Spread: number? }

-- 맵 모듈의 lighting 필드 (모든 키 선택. 빠진 키는 로비 값)
export type LightingPreset = {
	ClockTime: number?,
	Brightness: number?,
	Ambient: RGB?,
	OutdoorAmbient: RGB?,
	EnvironmentDiffuseScale: number?,
	EnvironmentSpecularScale: number?,
	ShadowSoftness: number?,
	ExposureCompensation: number?,
	GeographicLatitude: number?,
	Atmosphere: AtmosphereSpec?,
	ColorCorrection: ColorCorrectionSpec?,
	Bloom: BloomSpec?,
	SunRays: SunRaysSpec?,
}
export type MapLighting = LightingPreset

export type Resolved = {
	ClockTime: number,
	Brightness: number,
	Ambient: RGB,
	OutdoorAmbient: RGB,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	ShadowSoftness: number,
	ExposureCompensation: number,
	GeographicLatitude: number,
	Atmosphere: { Density: number, Offset: number, Color: RGB, Decay: RGB, Glare: number, Haze: number },
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: RGB },
	Bloom: { Intensity: number, Size: number, Threshold: number },
	SunRays: { Intensity: number, Spread: number },
}

local MapLighting = {}

-- 로비 조명(LobbyLayout.LIGHTING)에 없는 값의 기본 (로비도 이 값으로 맞춰요)
MapLighting.DEFAULTS = {
	EnvironmentDiffuseScale = 0, -- 플레이스 파일 값과 같게 (접속 직후 로비 조명이 한 번 바뀌지 않게, QA B6)
	EnvironmentSpecularScale = 0,
	ShadowSoftness = 0.5,
	ExposureCompensation = 0,
	GeographicLatitude = 41.733,
	SunRays = { Intensity = 0.03, Spread = 0.6 },
}

-- 범위 (Roblox 속성 범위 안에서, 실수로 넣은 터무니없는 값을 막는 정도)
local NUMBER_RANGES: { [string]: { number } } = {
	ClockTime = { 0, 24 },
	Brightness = { 0, 10 },
	EnvironmentDiffuseScale = { 0, 1 },
	EnvironmentSpecularScale = { 0, 1 },
	ShadowSoftness = { 0, 1 },
	ExposureCompensation = { -3, 3 },
	GeographicLatitude = { -90, 90 },
}
local COLOR_KEYS = { Ambient = true, OutdoorAmbient = true }
local GROUPS: { [string]: { [string]: { number } | "color" } } = {
	Atmosphere = {
		Density = { 0, 1 },
		Offset = { 0, 1 },
		Color = "color",
		Decay = "color",
		Glare = { 0, 10 },
		Haze = { 0, 10 },
	},
	ColorCorrection = {
		Brightness = { -1, 1 },
		Contrast = { -1, 1 },
		Saturation = { -1, 1 },
		TintColor = "color",
	},
	Bloom = {
		Intensity = { 0, 2 },
		Size = { 0, 56 },
		Threshold = { 0, 4 },
	},
	SunRays = {
		Intensity = { 0, 1 },
		Spread = { 0, 1 },
	},
}

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function colorProblem(v: any): string?
	if type(v) ~= "table" then
		return "must be {r, g, b}"
	end
	for _, key in { "r", "g", "b" } do
		local c = v[key]
		if not isNumber(c) or c < 0 or c > 255 then
			return `.{key} must be 0~255`
		end
	end
	return nil
end

local function rangeProblem(v: any, range: { number }): string?
	if not isNumber(v) then
		return "must be a number"
	end
	if v < range[1] or v > range[2] then
		return `must be {range[1]}~{range[2]}`
	end
	return nil
end

function MapLighting.validate(preset: any): string?
	if type(preset) ~= "table" then
		return "lighting must be a table"
	end
	for key, value in preset do
		if type(key) ~= "string" then
			return "lighting keys must be strings"
		end
		local range = NUMBER_RANGES[key]
		local problem: string? = nil
		if range then
			problem = rangeProblem(value, range)
		elseif COLOR_KEYS[key] then
			problem = colorProblem(value)
		elseif GROUPS[key] then
			if type(value) ~= "table" then
				problem = "must be a table"
			else
				for subKey, subValue in value do
					local rule = GROUPS[key][subKey]
					if rule == nil then
						return `lighting.{key}.{tostring(subKey)}: unknown key`
					end
					local subProblem = if rule == "color"
						then colorProblem(subValue)
						else rangeProblem(subValue, rule :: { number })
					if subProblem then
						return `lighting.{key}.{subKey} {subProblem}`
					end
				end
			end
		else
			return `lighting.{key}: unknown key`
		end
		if problem then
			return `lighting.{key} {problem}`
		end
	end
	return nil
end

local function copyColor(c: RGB): RGB
	return { r = c.r, g = c.g, b = c.b }
end

local function base(): Resolved
	local lobby = LobbyLayout.LIGHTING :: any
	local d = MapLighting.DEFAULTS
	return {
		ClockTime = lobby.ClockTime,
		Brightness = lobby.Brightness,
		Ambient = copyColor(lobby.Ambient),
		OutdoorAmbient = copyColor(lobby.OutdoorAmbient),
		EnvironmentDiffuseScale = lobby.EnvironmentDiffuseScale or d.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = lobby.EnvironmentSpecularScale or d.EnvironmentSpecularScale,
		ShadowSoftness = lobby.ShadowSoftness or d.ShadowSoftness,
		ExposureCompensation = lobby.ExposureCompensation or d.ExposureCompensation,
		GeographicLatitude = lobby.GeographicLatitude or d.GeographicLatitude,
		Atmosphere = {
			Density = lobby.Atmosphere.Density,
			Offset = lobby.Atmosphere.Offset,
			Color = copyColor(lobby.Atmosphere.Color),
			Decay = copyColor(lobby.Atmosphere.Decay),
			Glare = lobby.Atmosphere.Glare,
			Haze = lobby.Atmosphere.Haze,
		},
		ColorCorrection = {
			Brightness = lobby.ColorCorrection.Brightness,
			Contrast = lobby.ColorCorrection.Contrast,
			Saturation = lobby.ColorCorrection.Saturation,
			TintColor = copyColor(lobby.ColorCorrection.TintColor),
		},
		Bloom = {
			Intensity = lobby.Bloom.Intensity,
			Size = lobby.Bloom.Size,
			Threshold = lobby.Bloom.Threshold,
		},
		SunRays = {
			Intensity = (lobby.SunRays and lobby.SunRays.Intensity) or d.SunRays.Intensity,
			Spread = (lobby.SunRays and lobby.SunRays.Spread) or d.SunRays.Spread,
		},
	}
end

-- 빠진 값은 로비 값으로 채워요. preset이 nil이면 로비 조명 그대로.
function MapLighting.resolve(preset: LightingPreset?): Resolved
	local out = base() :: any
	if preset == nil then
		return out
	end
	for key, value in preset :: any do
		if type(value) == "table" and GROUPS[key] then
			for subKey, subValue in value do
				out[key][subKey] = if type(subValue) == "table" then copyColor(subValue) else subValue
			end
		elseif type(value) == "table" then
			out[key] = copyColor(value)
		else
			out[key] = value
		end
	end
	return out
end

MapLighting.LOBBY = MapLighting.resolve(nil)

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: RGB, b: RGB, t: number): RGB
	return { r = lerpNumber(a.r, b.r, t), g = lerpNumber(a.g, b.g, t), b = lerpNumber(a.b, b.b, t) }
end

-- 시계는 짧은 쪽으로 돌아요 (23시 → 1시는 24를 넘어서)
local function lerpClock(a: number, b: number, t: number): number
	local diff = (b - a) % 24
	if diff > 12 then
		diff -= 24
	end
	return (a + diff * t) % 24
end

local function lerpAny(a: any, b: any, t: number): any
	if type(a) == "number" then
		return lerpNumber(a, b, t)
	end
	if type(a) == "table" and a.r ~= nil then
		return lerpColor(a, b, t)
	end
	local out = {}
	for key, value in a do
		out[key] = lerpAny(value, b[key], t)
	end
	return out
end

function MapLighting.lerp(a: Resolved, b: Resolved, t: number): Resolved
	local alpha = math.clamp(t, 0, 1)
	local out = lerpAny(a, b, alpha)
	out.ClockTime = lerpClock(a.ClockTime, b.ClockTime, alpha)
	return out
end

local function c(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

-- 기존 맵 6개 분위기 초안 (m5-23 스펙 표, 렌더러로 맞춤 — m5-24에서 Studio로 다듬어요)
MapLighting.PRESETS = {
	-- 저녁 손님 몰리는 가게, 따뜻한 등빛
	["rotating-belt"] = {
		ClockTime = 17.5,
		Brightness = 2,
		Ambient = c(120, 92, 70),
		OutdoorAmbient = c(160, 120, 92),
		Atmosphere = {
			Density = 0.28,
			Offset = 0.15,
			Color = c(255, 206, 170),
			Decay = c(150, 96, 80),
			Glare = 0.2,
			Haze = 0.8,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.08, Saturation = 0.1, TintColor = c(255, 240, 222) },
		Bloom = { Intensity = 0.45, Size = 24, Threshold = 1.2 },
		SunRays = { Intensity = 0.05, Spread = 0.6 },
	},
	-- 흐린 오후 간장 늪 안개
	["soy-swamp"] = {
		ClockTime = 15,
		Brightness = 1.7,
		Ambient = c(98, 92, 70),
		OutdoorAmbient = c(132, 124, 96),
		Atmosphere = {
			Density = 0.38,
			Offset = 0.2,
			Color = c(196, 182, 140),
			Decay = c(104, 84, 54),
			Glare = 0,
			Haze = 1.6,
		},
		ColorCorrection = { Brightness = 0, Contrast = 0.06, Saturation = -0.05, TintColor = c(246, 244, 226) },
		Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.3 },
		SunRays = { Intensity = 0.02, Spread = 0.5 },
	},
	-- 김 자욱한 한낮
	["ramen-rapids"] = {
		ClockTime = 12.5,
		Brightness = 2.4,
		Ambient = c(118, 104, 84),
		OutdoorAmbient = c(160, 146, 120),
		Atmosphere = {
			Density = 0.32,
			Offset = 0.15,
			Color = c(255, 236, 196),
			Decay = c(170, 136, 96),
			Glare = 0.1,
			Haze = 2,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.05, Saturation = 0.06, TintColor = c(255, 248, 232) },
		Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.3 },
		SunRays = { Intensity = 0.05, Spread = 0.7 },
	},
	-- 밤의 철판 — 열기
	["hot-plate"] = {
		ClockTime = 20.5,
		Brightness = 1.4,
		Ambient = c(108, 92, 112),
		OutdoorAmbient = c(112, 104, 150),
		Atmosphere = {
			Density = 0.3,
			Offset = 0.1,
			Color = c(150, 110, 100),
			Decay = c(70, 50, 80),
			Glare = 0,
			Haze = 0.8,
		},
		ColorCorrection = { Brightness = 0.03, Contrast = 0.12, Saturation = 0.12, TintColor = c(255, 236, 214) },
		Bloom = { Intensity = 0.7, Size = 28, Threshold = 1 },
		SunRays = { Intensity = 0, Spread = 0.5 },
	},
	-- 아침 손질 시간, 차갑고 깨끗한 주방
	["chef-board"] = {
		ClockTime = 9,
		Brightness = 2.4,
		Ambient = c(100, 108, 120),
		OutdoorAmbient = c(140, 150, 166),
		Atmosphere = {
			Density = 0.2,
			Offset = 0.1,
			Color = c(214, 226, 240),
			Decay = c(120, 132, 150),
			Glare = 0.1,
			Haze = 0.6,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0, TintColor = c(242, 248, 255) },
		Bloom = { Intensity = 0.3, Size = 22, Threshold = 1.5 },
		SunRays = { Intensity = 0.04, Spread = 0.6 },
	},
	-- 축제 해질녘
	["skewer-showdown"] = {
		ClockTime = 18.2,
		Brightness = 1.6,
		Ambient = c(84, 68, 100),
		OutdoorAmbient = c(120, 94, 128),
		Atmosphere = {
			Density = 0.3,
			Offset = 0.2,
			Color = c(255, 176, 140),
			Decay = c(110, 66, 120),
			Glare = 0.4,
			Haze = 1.2,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.12, TintColor = c(255, 236, 226) },
		Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.1 },
		SunRays = { Intensity = 0.08, Spread = 0.7 },
	},
} :: { [string]: LightingPreset }

return MapLighting
