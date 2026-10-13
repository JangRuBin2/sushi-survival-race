--!strict
-- 맵 장식 파티클 프리셋 (m5-23). Roblox API 없는 순수 데이터 — MapKit.makeEmitter가 ParticleEmitter로 만들어요.
-- DecorSpec의 particle = "<이름>"(+ particleRate)으로 쓰거나, 맵 코드에서 MapKit.makeEmitter(이름, rate?)로 써요.
-- 텍스처는 Roblox에 들어 있는 rbxasset://textures/particles/* 만 써요 (업로드·에셋 id 필요 없음).
--   MapFxPresets.PRESETS[name] -> Preset
--   MapFxPresets.NAMES                     이름 목록 (정렬)
--   MapFxPresets.validate(preset) -> string?

export type RGB = { r: number, g: number, b: number }
export type Key = { t: number, v: number } -- 시간 0~1, 값
export type ColorKey = { t: number, c: RGB }

export type Preset = {
	Texture: string,
	Rate: number, -- 초당 개수
	Lifetime: { number }, -- { 최소, 최대 } 초
	Speed: { number }, -- { 최소, 최대 } studs/s
	SpreadAngle: { number }, -- { x, y } 도
	Size: { Key }, -- studs
	Transparency: { Key },
	Color: { ColorKey },
	LightEmission: number, -- 0~1 (1이면 더하기 섞기, 빛나 보임)
	LightInfluence: number, -- 0~1
	Acceleration: { number }, -- { x, y, z } studs/s²
	Drag: number,
	Rotation: { number }, -- { 최소, 최대 } 도
	RotSpeed: { number }, -- { 최소, 최대 } 도/s
	EmissionDirection: string, -- NormalId 이름 (Top이면 파츠 위쪽으로)
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function k(t: number, v: number): Key
	return { t = t, v = v }
end

local function solid(c: RGB): { ColorKey }
	return { { t = 0, c = c }, { t = 1, c = c } }
end

local MapFxPresets = {}

MapFxPresets.PRESETS = {
	-- 냄비·국물 위로 천천히 오르는 옅은 김
	Steam = {
		Texture = SMOKE,
		Rate = 3,
		Lifetime = { 2, 3 },
		Speed = { 3, 5 },
		SpreadAngle = { 15, 15 },
		Size = { k(0, 1.5), k(1, 6) },
		Transparency = { k(0, 0.6), k(1, 1) },
		Color = solid(rgb(235, 235, 235)),
		LightEmission = 0,
		LightInfluence = 1,
		Acceleration = { 0, 0.5, 0 },
		Drag = 0.4,
		Rotation = { 0, 360 },
		RotSpeed = { -20, 20 },
		EmissionDirection = "Top",
	},
	-- 끓는 냄비·튀김 기름 위 짙은 김
	SteamThick = {
		Texture = SMOKE,
		Rate = 6,
		Lifetime = { 2.5, 4 },
		Speed = { 4, 7 },
		SpreadAngle = { 25, 25 },
		Size = { k(0, 3), k(1, 10) },
		Transparency = { k(0, 0.45), k(0.6, 0.75), k(1, 1) },
		Color = solid(rgb(245, 242, 236)),
		LightEmission = 0.05,
		LightInfluence = 1,
		Acceleration = { 0, 1, 0 },
		Drag = 0.5,
		Rotation = { 0, 360 },
		RotSpeed = { -25, 25 },
		EmissionDirection = "Top",
	},
	-- 간장·국물 표면의 작은 거품 (금방 터짐)
	Bubbles = {
		Texture = SPARKLE,
		Rate = 4,
		Lifetime = { 0.6, 1.1 },
		Speed = { 0.5, 1.5 },
		SpreadAngle = { 40, 40 },
		Size = { k(0, 0.3), k(0.8, 0.7), k(1, 0) },
		Transparency = { k(0, 0.3), k(1, 0.8) },
		Color = solid(rgb(250, 240, 220)),
		LightEmission = 0.1,
		LightInfluence = 1,
		Acceleration = { 0, 0, 0 },
		Drag = 1,
		Rotation = { 0, 0 },
		RotSpeed = { 0, 0 },
		EmissionDirection = "Top",
	},
	-- 튀김 기름의 금빛 기포·튐
	OilBubbles = {
		Texture = SPARKLE,
		Rate = 8,
		Lifetime = { 0.4, 0.9 },
		Speed = { 2, 5 },
		SpreadAngle = { 50, 50 },
		Size = { k(0, 0.4), k(1, 0.1) },
		Transparency = { k(0, 0.1), k(1, 0.9) },
		Color = { { t = 0, c = rgb(255, 226, 140) }, { t = 1, c = rgb(232, 160, 60) } },
		LightEmission = 0.5,
		LightInfluence = 0.6,
		Acceleration = { 0, -15, 0 },
		Drag = 0,
		Rotation = { 0, 0 },
		RotSpeed = { 0, 0 },
		EmissionDirection = "Top",
	},
	-- 반짝임 (보석·설탕·유약)
	Sparkle = {
		Texture = SPARKLE,
		Rate = 2,
		Lifetime = { 0.8, 1.4 },
		Speed = { 0.2, 0.6 },
		SpreadAngle = { 180, 180 },
		Size = { k(0, 0), k(0.4, 0.6), k(1, 0) },
		Transparency = { k(0, 0.2), k(1, 0.6) },
		Color = solid(rgb(255, 250, 220)),
		LightEmission = 1,
		LightInfluence = 0,
		Acceleration = { 0, 0, 0 },
		Drag = 0,
		Rotation = { 0, 360 },
		RotSpeed = { -90, 90 },
		EmissionDirection = "Top",
	},
	-- 얼음 결정 (천천히 떨어지는 하얀 점)
	Frost = {
		Texture = SPARKLE,
		Rate = 5,
		Lifetime = { 2, 3.5 },
		Speed = { 0.5, 1.5 },
		SpreadAngle = { 60, 60 },
		Size = { k(0, 0.25), k(1, 0.15) },
		Transparency = { k(0, 0.2), k(1, 0.9) },
		Color = solid(rgb(230, 246, 255)),
		LightEmission = 0.6,
		LightInfluence = 0.4,
		Acceleration = { 0, -1.5, 0 },
		Drag = 0.3,
		Rotation = { 0, 360 },
		RotSpeed = { -40, 40 },
		EmissionDirection = "Top",
	},
	-- 냉장고 바닥에 깔리는 찬 안개 (옆으로 퍼지고 아래로 가라앉음)
	ColdMist = {
		Texture = SMOKE,
		Rate = 3,
		Lifetime = { 3, 5 },
		Speed = { 1, 2 },
		SpreadAngle = { 80, 10 },
		Size = { k(0, 4), k(1, 12) },
		Transparency = { k(0, 0.7), k(0.5, 0.8), k(1, 1) },
		Color = solid(rgb(214, 236, 250)),
		LightEmission = 0.1,
		LightInfluence = 1,
		Acceleration = { 0, -0.6, 0 },
		Drag = 0.6,
		Rotation = { 0, 360 },
		RotSpeed = { -10, 10 },
		EmissionDirection = "Top",
	},
	-- 철판·화로의 불티 (위로 올라가며 꺼짐)
	Embers = {
		Texture = FIRE,
		Rate = 6,
		Lifetime = { 1, 2 },
		Speed = { 2, 5 },
		SpreadAngle = { 30, 30 },
		Size = { k(0, 0.35), k(1, 0) },
		Transparency = { k(0, 0), k(1, 0.6) },
		Color = { { t = 0, c = rgb(255, 210, 120) }, { t = 1, c = rgb(255, 90, 30) } },
		LightEmission = 1,
		LightInfluence = 0,
		Acceleration = { 0, 2, 0 },
		Drag = 0.5,
		Rotation = { 0, 360 },
		RotSpeed = { -120, 120 },
		EmissionDirection = "Top",
	},
	-- 물보라 (바다·급류 가장자리)
	SeaSpray = {
		Texture = SMOKE,
		Rate = 6,
		Lifetime = { 0.6, 1.2 },
		Speed = { 4, 8 },
		SpreadAngle = { 35, 35 },
		Size = { k(0, 0.8), k(1, 3) },
		Transparency = { k(0, 0.35), k(1, 1) },
		Color = solid(rgb(236, 248, 255)),
		LightEmission = 0.1,
		LightInfluence = 1,
		Acceleration = { 0, -20, 0 },
		Drag = 0.4,
		Rotation = { 0, 360 },
		RotSpeed = { -60, 60 },
		EmissionDirection = "Top",
	},
	-- 공중에 떠도는 먼지·밀가루 (빛줄기 속에서 보이게)
	Dust = {
		Texture = SPARKLE,
		Rate = 2,
		Lifetime = { 4, 7 },
		Speed = { 0.1, 0.4 },
		SpreadAngle = { 180, 180 },
		Size = { k(0, 0.15), k(1, 0.15) },
		Transparency = { k(0, 0.5), k(0.5, 0.3), k(1, 1) },
		Color = solid(rgb(255, 244, 220)),
		LightEmission = 0.3,
		LightInfluence = 1,
		Acceleration = { 0, 0, 0 },
		Drag = 0.2,
		Rotation = { 0, 360 },
		RotSpeed = { -15, 15 },
		EmissionDirection = "Top",
	},
	-- 흩날리는 꽃잎 (벚꽃 분홍)
	Petals = {
		Texture = SPARKLE,
		Rate = 2,
		Lifetime = { 5, 8 },
		Speed = { 0.5, 1.5 },
		SpreadAngle = { 70, 70 },
		Size = { k(0, 0.5), k(1, 0.4) },
		Transparency = { k(0, 0.1), k(0.85, 0.2), k(1, 1) },
		Color = solid(rgb(255, 196, 214)),
		LightEmission = 0,
		LightInfluence = 1,
		Acceleration = { 0.6, -1.2, 0 },
		Drag = 0.4,
		Rotation = { 0, 360 },
		RotSpeed = { -90, 90 },
		EmissionDirection = "Top",
	},
	-- 색종이 (축제·결승)
	Confetti = {
		Texture = SPARKLE,
		Rate = 4,
		Lifetime = { 3, 5 },
		Speed = { 3, 6 },
		SpreadAngle = { 50, 50 },
		Size = { k(0, 0.5), k(1, 0.5) },
		Transparency = { k(0, 0), k(0.9, 0.1), k(1, 1) },
		Color = {
			{ t = 0, c = rgb(255, 90, 110) },
			{ t = 0.33, c = rgb(255, 210, 70) },
			{ t = 0.66, c = rgb(90, 200, 255) },
			{ t = 1, c = rgb(150, 230, 110) },
		},
		LightEmission = 0.2,
		LightInfluence = 0.8,
		Acceleration = { 0, -4, 0 },
		Drag = 0.8,
		Rotation = { 0, 360 },
		RotSpeed = { -200, 200 },
		EmissionDirection = "Top",
	},
} :: { [string]: Preset }

local names = {}
for name in MapFxPresets.PRESETS do
	table.insert(names, name)
end
table.sort(names)
MapFxPresets.NAMES = names :: { string }

local NORMAL_IDS = { Top = true, Bottom = true, Front = true, Back = true, Left = true, Right = true }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function pairOk(v: any, n: number): boolean
	if type(v) ~= "table" or #v ~= n then
		return false
	end
	for i = 1, n do
		if not isNumber(v[i]) then
			return false
		end
	end
	return true
end

local function keysOk(list: any, isColor: boolean): boolean
	if type(list) ~= "table" or #list < 1 or #list > 8 then
		return false
	end
	local last = -1
	for _, key in list do
		if type(key) ~= "table" or not isNumber(key.t) or key.t < 0 or key.t > 1 or key.t < last then
			return false
		end
		last = key.t
		if isColor then
			local c = key.c
			if type(c) ~= "table" or not isNumber(c.r) or not isNumber(c.g) or not isNumber(c.b) then
				return false
			end
		elseif not isNumber(key.v) then
			return false
		end
	end
	return true
end

-- 프리셋 하나 검사 (필수 키·범위). 문제가 있으면 이유.
function MapFxPresets.validate(preset: any): string?
	if type(preset) ~= "table" then
		return "preset must be a table"
	end
	if type(preset.Texture) ~= "string" or string.sub(preset.Texture, 1, 10) ~= "rbxasset:/" then
		return "Texture must be a built-in rbxasset:// path"
	end
	if not isNumber(preset.Rate) or preset.Rate < 0 or preset.Rate > 50 then
		return "Rate must be 0~50"
	end
	for _, key in { "Lifetime", "Speed", "SpreadAngle", "Rotation", "RotSpeed" } do
		if not pairOk(preset[key], 2) then
			return `{key} must be {"{"}min, max{"}"}`
		end
	end
	if not pairOk(preset.Acceleration, 3) then
		return "Acceleration must be {x, y, z}"
	end
	if not keysOk(preset.Size, false) then
		return "Size must be 1~8 keys {t, v}"
	end
	if not keysOk(preset.Transparency, false) then
		return "Transparency must be 1~8 keys {t, v}"
	end
	if not keysOk(preset.Color, true) then
		return "Color must be 1~8 keys {t, c}"
	end
	for _, key in { "LightEmission", "LightInfluence" } do
		if not isNumber(preset[key]) or preset[key] < 0 or preset[key] > 1 then
			return `{key} must be 0~1`
		end
	end
	if not isNumber(preset.Drag) or preset.Drag < 0 then
		return "Drag must be >= 0"
	end
	if not NORMAL_IDS[preset.EmissionDirection] then
		return "EmissionDirection must be a NormalId name"
	end
	return nil
end

return MapFxPresets
