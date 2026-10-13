--!strict
-- 맵 키트의 순수 부분 (m4-01, REFERENCE-map-production §5·§7(A)). Roblox API를 쓰지 않아요.
-- 맵 아트(m4-02~05)와 로비(m4-06)는 장식을 DecorSpec 목록(순수 데이터)으로 쓰고, MapKit.buildDecor로 만들어요.
--   MapKitLogic.validate(specs) -> string?   문제가 있으면 이유, 괜찮으면 nil
--   MapKitLogic.count(specs) -> number       장식 파츠 수 (DECOR_PART_BUDGET과 비교)
--   MapKitLogic.bounds(specs) -> Bounds?     origin 기준 축 정렬 경계 상자 (회전 반영). 빈 목록이면 nil
--   MapKitLogic.PALETTE                      초밥 가게 색 모음 { r, g, b } (0~255)
--   MapKitLogic.MATERIALS                    쓸 수 있는 Enum.Material 이름
-- 맵 하나당 예산: 장식 파츠 600, ParticleEmitter 8, PointLight·SpotLight 12.
--
-- m5-23 확장 (선택 필드만 — 기존 목록은 그대로 동작):
--   shape = "CornerWedge", reflectance, castShadow, light, particle(+particleRate), anim
--   MapKitLogic.BUDGETS / budget(tier) / checkBudget(specs, tier) -> string?
--   countLights / countShadowedLights / countParticles / countAnimated
--   resolveCastShadow(spec) -> boolean      castShadow가 nil이면 가장 긴 변 < 3이면 false
--   shade(rgb, factor) / shades(rgb) -> { light, base, dark } / mix(a, b, t)

local MapDecorAnimLogic = require(script.Parent.MapDecorAnimLogic)
local MapFxPresets = require(script.Parent.MapFxPresets)

export type Vec3 = { x: number, y: number, z: number }
export type RGB = { r: number, g: number, b: number }
export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge" | "CornerWedge"

-- 파츠 자식으로 붙는 조명 (m5-23)
export type LightSpec = {
	kind: "Point" | "Spot" | "Surface",
	color: RGB,
	brightness: number, -- 0~10
	range: number, -- 0~60 studs
	angle: number?, -- Spot·Surface 원뿔 각도 0~180 (기본 90)
	face: string?, -- Spot·Surface가 비추는 면 (NormalId 이름, 기본 Front)
	shadows: boolean?, -- 기본 false (그림자 조명은 비싸요 — 맵당 Standard 1·Extended 2)
}

export type AnimSpec = MapDecorAnimLogic.AnimSpec

export type DecorSpec = {
	name: string,
	shape: Shape,
	size: Vec3,
	color: RGB,
	material: string, -- Enum.Material 이름 (MATERIALS 안)
	offset: Vec3, -- origin 기준 위치 (로컬, 코스는 -Z로 뻗어요)
	rotation: Vec3?, -- 도 (CFrame.Angles 순서: X, Y, Z)
	transparency: number?, -- 0~1
	-- m5-23 선택 필드
	reflectance: number?, -- 0~1 (금속·유약·젤리 광택)
	castShadow: boolean?, -- nil이면 resolveCastShadow (작은 소품은 그림자 끔)
	light: LightSpec?,
	particle: string?, -- MapFxPresets 이름
	particleRate: number?, -- 프리셋 Rate 덮어쓰기 0~50
	anim: AnimSpec?, -- 클라이언트 로컬 움직임 (움직이는 판정 파츠에 붙은 장식에는 쓰지 마세요)
}

export type Bounds = { min: Vec3, max: Vec3 }

local MapKitLogic = {}

MapKitLogic.DECOR_PART_BUDGET = 600
MapKitLogic.PARTICLE_BUDGET = 8
MapKitLogic.LIGHT_BUDGET = 12

export type BudgetTier = "Standard" | "Extended"
export type Budget = { parts: number, particles: number, lights: number, shadowedLights: number, anim: number }

-- 예산 단계 (m5-23). 기본은 Standard, 아트 패스를 한 맵은 Art 모듈에서 BUDGET = "Extended"를 내보내고
-- 맵 테스트가 checkBudget(Art.decor(), "Extended")로 확인해요. 런타임 경고는 Extended 기준.
MapKitLogic.BUDGETS = {
	Standard = { parts = 600, particles = 8, lights = 12, shadowedLights = 1, anim = 40 },
	Extended = { parts = 1500, particles = 16, lights = 24, shadowedLights = 2, anim = 80 },
} :: { [string]: Budget }

function MapKitLogic.budget(tier: BudgetTier?): Budget
	return MapKitLogic.BUDGETS[tier or "Standard"] or MapKitLogic.BUDGETS.Standard
end

MapKitLogic.SHAPES = { "Block", "Ball", "Cylinder", "Wedge", "CornerWedge" }
MapKitLogic.LIGHT_KINDS = { "Point", "Spot", "Surface" }
MapKitLogic.NORMAL_IDS = { "Top", "Bottom", "Front", "Back", "Left", "Right" }
MapKitLogic.SMALL_SHADOW_SIZE = 3 -- castShadow가 nil이면 가장 긴 변이 이보다 짧은 장식은 그림자를 안 만들어요
MapKitLogic.LIGHT_MAX_RANGE = 60 -- PointLight·SpotLight.Range 상한 (Roblox)
MapKitLogic.SURFACE_LIGHT_MAX_RANGE = 16 -- SurfaceLight.Range 상한 (Roblox가 16에서 잘라요)

MapKitLogic.MATERIALS = {
	"Plastic",
	"SmoothPlastic",
	"Neon",
	"Wood",
	"WoodPlanks",
	"Marble",
	"Slate",
	"Concrete",
	"Granite",
	"Brick",
	"Pebble",
	"Cobblestone",
	"Metal",
	"DiamondPlate",
	"CorrodedMetal",
	"Foil",
	"Fabric",
	"Sand",
	"Grass",
	"Ice",
	"Glass",
	"ForceField",
	"Sandstone",
	"Limestone",
	"Rock",
	"Basalt",
	"Asphalt",
	"Pavement",
	"Plaster",
	"Leather",
	"Cardboard",
	"Rubber",
	"Carpet",
	"ClayRoofTiles",
	"RoofShingles",
	"CeramicTiles",
	"Salt",
	"Snow",
	"Mud",
}

-- 초밥 가게 팔레트 (맵 전체 톤: 따뜻한 나무 + 흰 도자기 + 빨간 옻칠)
MapKitLogic.PALETTE = {
	Rice = { r = 248, g = 246, b = 238 }, -- 밥 흰색
	Nori = { r = 30, g = 36, b = 32 }, -- 김 검정
	Soy = { r = 92, g = 50, b = 28 }, -- 간장 갈색
	Wasabi = { r = 150, g = 196, b = 72 }, -- 와사비 연두
	Salmon = { r = 250, g = 128, b = 82 }, -- 연어 주황
	Tuna = { r = 196, g = 40, b = 52 }, -- 참치 빨강
	Egg = { r = 248, g = 208, b = 72 }, -- 계란 노랑
	Wood = { r = 186, g = 140, b = 92 }, -- 나무 결 갈색
	Porcelain = { r = 240, g = 242, b = 246 }, -- 도자기 흰색
	PorcelainRim = { r = 40, g = 60, b = 128 }, -- 도자기 남색 테두리
	Iron = { r = 120, g = 122, b = 126 }, -- 철판 회색
	Lacquer = { r = 170, g = 30, b = 36 }, -- 옻칠 빨강
	Noren = { r = 34, g = 48, b = 96 }, -- 노렌 남색
	-- m5-23: 단계 색 (큰 면을 한 색으로 칠하지 않게 — shades()로 더 만들 수도 있어요)
	RiceShade = { r = 228, g = 222, b = 206 },
	WoodLight = { r = 214, g = 172, b = 120 },
	WoodDark = { r = 120, g = 84, b = 54 },
	SoyLight = { r = 140, g = 84, b = 46 },
	SoyDark = { r = 54, g = 28, b = 16 },
	WasabiDark = { r = 98, g = 140, b = 44 },
	SalmonLight = { r = 255, g = 170, b = 128 },
	TunaDark = { r = 128, g = 22, b = 34 },
	EggDark = { r = 214, g = 160, b = 40 },
	LacquerDark = { r = 104, g = 16, b = 22 },
	NorenLight = { r = 64, g = 84, b = 150 },
	-- m5-23: 새 맵 테마 색
	Ikura = { r = 255, g = 96, b = 40 }, -- 연어알 주황
	TempuraGold = { r = 232, g = 176, b = 72 }, -- 튀김옷 금색
	Batter = { r = 246, g = 222, b = 160 }, -- 반죽 크림
	CastIron = { r = 52, g = 50, b = 50 }, -- 무쇠 냄비
	Steel = { r = 168, g = 174, b = 180 }, -- 스테인리스
	Frost = { r = 226, g = 240, b = 250 }, -- 서리 흰빛
	IceBlue = { r = 150, g = 206, b = 240 }, -- 얼음 하늘색
	Mint = { r = 160, g = 228, b = 200 },
	Strawberry = { r = 236, g = 70, b = 96 },
	Lime = { r = 170, g = 220, b = 70 },
	Cream = { r = 255, g = 244, b = 222 },
	Chocolate = { r = 92, g = 56, b = 40 },
	Caramel = { r = 206, g = 136, b = 60 },
	Matcha = { r = 128, g = 160, b = 72 },
	Shiso = { r = 70, g = 130, b = 60 }, -- 차조기 잎
	Sea = { r = 40, g = 110, b = 160 },
	Sunset = { r = 255, g = 140, b = 90 },
	Plum = { r = 120, g = 50, b = 100 },
	PastelPink = { r = 255, g = 200, b = 214 },
	PastelSky = { r = 190, g = 222, b = 255 },
	PastelYellow = { r = 255, g = 238, b = 170 },
	PastelLavender = { r = 214, g = 196, b = 250 },
} :: { [string]: RGB }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isVec(v: any): boolean
	return type(v) == "table" and isNumber(v.x) and isNumber(v.y) and isNumber(v.z)
end

-- 장식 목록 검사. 문제가 있으면 "<번호> <이름>: <이유>", 괜찮으면 nil.
function MapKitLogic.validate(specs: { DecorSpec }): string?
	if type(specs) ~= "table" then
		return "specs must be a list"
	end
	for i, spec: any in specs do
		local label = `#{i} {if type(spec) == "table" then tostring(spec.name) else "?"}`
		if type(spec) ~= "table" then
			return `{label}: spec must be a table`
		end
		if type(spec.name) ~= "string" or spec.name == "" then
			return `{label}: name must be a non-empty string`
		end
		if not table.find(MapKitLogic.SHAPES, spec.shape) then
			return `{label}: unknown shape {tostring(spec.shape)}`
		end
		if not isVec(spec.size) or spec.size.x <= 0 or spec.size.y <= 0 or spec.size.z <= 0 then
			return `{label}: size must be positive`
		end
		local c = spec.color
		if type(c) ~= "table" then
			return label .. ": color must be {r, g, b}"
		end
		for _, key in { "r", "g", "b" } do
			local v = c[key]
			if not isNumber(v) or v < 0 or v > 255 then
				return `{label}: color.{key} must be 0~255`
			end
		end
		if not table.find(MapKitLogic.MATERIALS, spec.material) then
			return `{label}: unknown material {tostring(spec.material)}`
		end
		if not isVec(spec.offset) then
			return label .. ": offset must be {x, y, z}"
		end
		if spec.rotation ~= nil and not isVec(spec.rotation) then
			return label .. ": rotation must be {x, y, z} degrees"
		end
		if
			spec.transparency ~= nil
			and (not isNumber(spec.transparency) or spec.transparency < 0 or spec.transparency > 1)
		then
			return `{label}: transparency must be 0~1`
		end
		local problem = MapKitLogic.validateExtras(spec)
		if problem then
			return `{label}: {problem}`
		end
	end
	return nil
end

local function colorProblem(c: any): string?
	if type(c) ~= "table" then
		return "must be {r, g, b}"
	end
	for _, key in { "r", "g", "b" } do
		local v = c[key]
		if not isNumber(v) or v < 0 or v > 255 then
			return `.{key} must be 0~255`
		end
	end
	return nil
end

-- m5-23 선택 필드 검사 (없으면 통과)
function MapKitLogic.validateExtras(spec: any): string?
	if spec.reflectance ~= nil and (not isNumber(spec.reflectance) or spec.reflectance < 0 or spec.reflectance > 1) then
		return "reflectance must be 0~1"
	end
	if spec.castShadow ~= nil and type(spec.castShadow) ~= "boolean" then
		return "castShadow must be a boolean"
	end
	local light = spec.light
	if light ~= nil then
		if type(light) ~= "table" then
			return "light must be a table"
		end
		if not table.find(MapKitLogic.LIGHT_KINDS, light.kind) then
			return `light.kind must be Point, Spot or Surface (got {tostring(light.kind)})`
		end
		local cp = colorProblem(light.color)
		if cp then
			return "light.color " .. cp
		end
		if not isNumber(light.brightness) or light.brightness < 0 or light.brightness > 10 then
			return "light.brightness must be 0~10"
		end
		local maxRange = if light.kind == "Surface"
			then MapKitLogic.SURFACE_LIGHT_MAX_RANGE
			else MapKitLogic.LIGHT_MAX_RANGE
		if not isNumber(light.range) or light.range < 0 or light.range > maxRange then
			return `light.range must be 0~{maxRange} for {light.kind} lights`
		end
		if light.angle ~= nil and (not isNumber(light.angle) or light.angle < 0 or light.angle > 180) then
			return "light.angle must be 0~180"
		end
		if light.face ~= nil and not table.find(MapKitLogic.NORMAL_IDS, light.face) then
			return "light.face must be a NormalId name (Top, Bottom, Front, Back, Left, Right)"
		end
		if light.shadows ~= nil and type(light.shadows) ~= "boolean" then
			return "light.shadows must be a boolean"
		end
	end
	if spec.particle ~= nil and (type(spec.particle) ~= "string" or MapFxPresets.PRESETS[spec.particle] == nil) then
		return `unknown particle preset {tostring(spec.particle)} ({table.concat(MapFxPresets.NAMES, ", ")})`
	end
	if spec.particleRate ~= nil then
		if spec.particle == nil then
			return "particleRate needs particle"
		end
		if not isNumber(spec.particleRate) or spec.particleRate < 0 or spec.particleRate > 50 then
			return "particleRate must be 0~50"
		end
	end
	if spec.anim ~= nil then
		local problem = MapDecorAnimLogic.validate(spec.anim)
		if problem then
			return problem
		end
	end
	return nil
end

function MapKitLogic.count(specs: { DecorSpec }): number
	return #specs
end

function MapKitLogic.countLights(specs: { DecorSpec }): number
	local n = 0
	for _, spec in specs do
		if spec.light then
			n += 1
		end
	end
	return n
end

function MapKitLogic.countShadowedLights(specs: { DecorSpec }): number
	local n = 0
	for _, spec in specs do
		if spec.light and spec.light.shadows == true then
			n += 1
		end
	end
	return n
end

function MapKitLogic.countParticles(specs: { DecorSpec }): number
	local n = 0
	for _, spec in specs do
		if spec.particle then
			n += 1
		end
	end
	return n
end

function MapKitLogic.countAnimated(specs: { DecorSpec }): number
	local n = 0
	for _, spec in specs do
		if spec.anim then
			n += 1
		end
	end
	return n
end

-- 예산 검사. extra = 맵 코드가 Instance.new로 따로 붙인 조명·파티클 수 (선택).
function MapKitLogic.checkBudget(
	specs: { DecorSpec },
	tier: BudgetTier?,
	extra: { lights: number?, particles: number?, parts: number?, shadowedLights: number? }?
): string?
	local budget = MapKitLogic.budget(tier)
	local name = tier or "Standard"
	type Extra = { lights: number?, particles: number?, parts: number?, shadowedLights: number? }
	local more: Extra = extra or {} :: Extra
	local parts = #specs + (more.parts or 0)
	if parts > budget.parts then
		return `{name}: {parts} decor parts > {budget.parts}`
	end
	local lights = MapKitLogic.countLights(specs) + (more.lights or 0)
	if lights > budget.lights then
		return `{name}: {lights} lights > {budget.lights}`
	end
	local shadowed = MapKitLogic.countShadowedLights(specs) + (more.shadowedLights or 0)
	if shadowed > budget.shadowedLights then
		return `{name}: {shadowed} shadowed lights > {budget.shadowedLights}`
	end
	local particles = MapKitLogic.countParticles(specs) + (more.particles or 0)
	if particles > budget.particles then
		return `{name}: {particles} particle emitters > {budget.particles}`
	end
	local animated = MapKitLogic.countAnimated(specs)
	if animated > budget.anim then
		return `{name}: {animated} animated decor > {budget.anim}`
	end
	return nil
end

function MapKitLogic.resolveCastShadow(spec: DecorSpec): boolean
	if spec.castShadow ~= nil then
		return spec.castShadow
	end
	local longest = math.max(spec.size.x, spec.size.y, spec.size.z)
	return longest >= MapKitLogic.SMALL_SHADOW_SIZE
end

-- ── 색 도우미 ───────────────────────────────────────────────────────
-- factor > 1이면 밝게(흰색 쪽으로), < 1이면 어둡게. 0~255로 자르고 정수로.
function MapKitLogic.shade(c: RGB, factor: number): RGB
	local function ch(v: number): number
		local out
		if factor >= 1 then
			out = v + (255 - v) * math.min(factor - 1, 1)
		else
			out = v * math.max(factor, 0)
		end
		return math.clamp(math.floor(out + 0.5), 0, 255)
	end
	return { r = ch(c.r), g = ch(c.g), b = ch(c.b) }
end

-- 가이드의 "재질마다 2~3 단계": 밝은 면(윗면·가장자리), 기본, 어두운 면(밑면·틈)
function MapKitLogic.shades(c: RGB): { light: RGB, base: RGB, dark: RGB }
	return {
		light = MapKitLogic.shade(c, 1.18),
		base = { r = c.r, g = c.g, b = c.b },
		dark = MapKitLogic.shade(c, 0.72),
	}
end

function MapKitLogic.mix(a: RGB, b: RGB, t: number): RGB
	local k = math.clamp(t, 0, 1)
	return {
		r = math.floor(a.r + (b.r - a.r) * k + 0.5),
		g = math.floor(a.g + (b.g - a.g) * k + 0.5),
		b = math.floor(a.b + (b.b - a.b) * k + 0.5),
	}
end

-- CFrame.Angles(rx, ry, rz)와 같은 회전 (R = Rx · Ry · Rz)
local function rotate(v: Vec3, rotation: Vec3?): Vec3
	if rotation == nil then
		return v
	end
	local x, y, z = v.x, v.y, v.z
	-- Rz
	local cz, sz = math.cos(math.rad(rotation.z)), math.sin(math.rad(rotation.z))
	x, y = x * cz - y * sz, x * sz + y * cz
	-- Ry
	local cy, sy = math.cos(math.rad(rotation.y)), math.sin(math.rad(rotation.y))
	x, z = x * cy + z * sy, -x * sy + z * cy
	-- Rx
	local cx, sx = math.cos(math.rad(rotation.x)), math.sin(math.rad(rotation.x))
	y, z = y * cx - z * sx, y * sx + z * cx
	return { x = x, y = y, z = z }
end

-- origin 기준 축 정렬 경계 상자. 각 장식의 상자 꼭짓점 8개를 회전해서 모아요 (공·원기둥도 상자로 봐요).
function MapKitLogic.bounds(specs: { DecorSpec }): Bounds?
	if #specs == 0 then
		return nil
	end
	local min = { x = math.huge, y = math.huge, z = math.huge }
	local max = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, spec in specs do
		local hx, hy, hz = spec.size.x / 2, spec.size.y / 2, spec.size.z / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = rotate({ x = sx * hx, y = sy * hy, z = sz * hz }, spec.rotation)
					local wx, wy, wz = p.x + spec.offset.x, p.y + spec.offset.y, p.z + spec.offset.z
					min.x, min.y, min.z = math.min(min.x, wx), math.min(min.y, wy), math.min(min.z, wz)
					max.x, max.y, max.z = math.max(max.x, wx), math.max(max.y, wy), math.max(max.z, wz)
				end
			end
		end
	end
	return { min = min, max = max }
end

return MapKitLogic
