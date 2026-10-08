--!strict
-- 맵 키트의 순수 부분 (m4-01, REFERENCE-map-production §5·§7(A)). Roblox API를 쓰지 않아요.
-- 맵 아트(m4-02~05)와 로비(m4-06)는 장식을 DecorSpec 목록(순수 데이터)으로 쓰고, MapKit.buildDecor로 만들어요.
--   MapKitLogic.validate(specs) -> string?   문제가 있으면 이유, 괜찮으면 nil
--   MapKitLogic.count(specs) -> number       장식 파츠 수 (DECOR_PART_BUDGET과 비교)
--   MapKitLogic.bounds(specs) -> Bounds?     origin 기준 축 정렬 경계 상자 (회전 반영). 빈 목록이면 nil
--   MapKitLogic.PALETTE                      초밥 가게 색 모음 { r, g, b } (0~255)
--   MapKitLogic.MATERIALS                    쓸 수 있는 Enum.Material 이름
-- 맵 하나당 예산: 장식 파츠 600, ParticleEmitter 8, PointLight·SpotLight 12.

export type Vec3 = { x: number, y: number, z: number }
export type RGB = { r: number, g: number, b: number }
export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"

export type DecorSpec = {
	name: string,
	shape: Shape,
	size: Vec3,
	color: RGB,
	material: string, -- Enum.Material 이름 (MATERIALS 안)
	offset: Vec3, -- origin 기준 위치 (로컬, 코스는 -Z로 뻗어요)
	rotation: Vec3?, -- 도 (CFrame.Angles 순서: X, Y, Z)
	transparency: number?, -- 0~1
}

export type Bounds = { min: Vec3, max: Vec3 }

local MapKitLogic = {}

MapKitLogic.DECOR_PART_BUDGET = 600
MapKitLogic.PARTICLE_BUDGET = 8
MapKitLogic.LIGHT_BUDGET = 12

MapKitLogic.SHAPES = { "Block", "Ball", "Cylinder", "Wedge" }

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
	end
	return nil
end

function MapKitLogic.count(specs: { DecorSpec }): number
	return #specs
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
