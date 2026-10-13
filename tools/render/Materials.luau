--!strict
--!native
-- 재질 근사 (m5-23). Roblox 재질 텍스처를 그대로 그릴 수는 없어서, 밝기 배율·하이라이트·반사와
-- 월드 좌표 기반의 가벼운 무늬(나무 판자 줄, 벽돌, 타일, 얼룩)만 흉내 내요. 무늬는 약하게 — 실제 Roblox
-- 재질도 가까이서는 결이 보이지만 멀리서는 거의 단색이라서, 렌더가 실제보다 화려해 보이지 않게 했어요.
--   Materials.get(name) -> { albedo, spec, shine, env }
--   Materials.texture(name, x, y, z, nx, ny, nz) -> number   (색에 곱하는 배율, 1 근처)

export type Material = { albedo: number, spec: number, shine: number, env: number }

local Materials = {}

local DEFAULT: Material = { albedo = 1, spec = 0.12, shine = 24, env = 0 }

local TABLE: { [string]: Material } = {
	Plastic = { albedo = 1, spec = 0.12, shine = 24, env = 0 },
	SmoothPlastic = { albedo = 1, spec = 0.22, shine = 40, env = 0.02 },
	Neon = { albedo = 1, spec = 0, shine = 1, env = 0 },
	Wood = { albedo = 0.93, spec = 0.05, shine = 12, env = 0 },
	WoodPlanks = { albedo = 0.93, spec = 0.05, shine = 12, env = 0 },
	Marble = { albedo = 1, spec = 0.45, shine = 70, env = 0.06 },
	Slate = { albedo = 0.88, spec = 0.1, shine = 20, env = 0 },
	Concrete = { albedo = 0.94, spec = 0.03, shine = 10, env = 0 },
	Granite = { albedo = 0.94, spec = 0.12, shine = 30, env = 0.01 },
	Brick = { albedo = 0.9, spec = 0.04, shine = 10, env = 0 },
	Pebble = { albedo = 0.92, spec = 0.08, shine = 16, env = 0 },
	Cobblestone = { albedo = 0.88, spec = 0.06, shine = 14, env = 0 },
	Metal = { albedo = 0.86, spec = 0.55, shine = 48, env = 0.12 },
	DiamondPlate = { albedo = 0.9, spec = 0.5, shine = 40, env = 0.1 },
	CorrodedMetal = { albedo = 0.85, spec = 0.2, shine = 20, env = 0.03 },
	Foil = { albedo = 0.95, spec = 0.8, shine = 90, env = 0.25 },
	Fabric = { albedo = 0.95, spec = 0, shine = 1, env = 0 },
	Sand = { albedo = 0.98, spec = 0.02, shine = 8, env = 0 },
	Grass = { albedo = 0.9, spec = 0.04, shine = 8, env = 0 },
	Ice = { albedo = 1.04, spec = 0.7, shine = 90, env = 0.18 },
	Glass = { albedo = 1, spec = 0.9, shine = 120, env = 0.1 },
	ForceField = { albedo = 1.2, spec = 0, shine = 1, env = 0 },
	Sandstone = { albedo = 0.96, spec = 0.04, shine = 10, env = 0 },
	Limestone = { albedo = 0.98, spec = 0.05, shine = 10, env = 0 },
	Rock = { albedo = 0.88, spec = 0.08, shine = 16, env = 0 },
	Basalt = { albedo = 0.85, spec = 0.1, shine = 20, env = 0 },
	Asphalt = { albedo = 0.9, spec = 0.04, shine = 10, env = 0 },
	Pavement = { albedo = 0.92, spec = 0.05, shine = 10, env = 0 },
	Plaster = { albedo = 0.98, spec = 0.04, shine = 10, env = 0 },
	Leather = { albedo = 0.92, spec = 0.18, shine = 22, env = 0 },
	Cardboard = { albedo = 0.95, spec = 0.02, shine = 8, env = 0 },
	Rubber = { albedo = 0.95, spec = 0.12, shine = 18, env = 0 },
	Carpet = { albedo = 0.92, spec = 0, shine = 1, env = 0 },
	ClayRoofTiles = { albedo = 0.92, spec = 0.08, shine = 16, env = 0 },
	RoofShingles = { albedo = 0.9, spec = 0.05, shine = 12, env = 0 },
	CeramicTiles = { albedo = 1, spec = 0.4, shine = 60, env = 0.06 },
	Salt = { albedo = 1, spec = 0.1, shine = 20, env = 0 },
	Snow = { albedo = 1.04, spec = 0.08, shine = 16, env = 0 },
	Mud = { albedo = 0.88, spec = 0.25, shine = 30, env = 0.02 },
}

function Materials.get(name: string): Material
	return TABLE[name] or DEFAULT
end

local function hash(x: number, y: number): number
	local h = math.sin(x * 127.1 + y * 311.7) * 43758.5453
	return h - math.floor(h)
end

local function noise(x: number, y: number): number
	local ix, iy = math.floor(x), math.floor(y)
	local fx, fy = x - ix, y - iy
	local ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local a, b = hash(ix, iy), hash(ix + 1, iy)
	local c, d = hash(ix, iy + 1), hash(ix + 1, iy + 1)
	return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy
end

-- 면 방향에 맞춘 2D 좌표 (u, v)
local function planar(x: number, y: number, z: number, nx: number, ny: number, nz: number): (number, number)
	local ax, ay, az = math.abs(nx), math.abs(ny), math.abs(nz)
	if ay >= ax and ay >= az then
		return x, z
	elseif ax >= az then
		return z, y
	end
	return x, y
end

local function frac(x: number): number
	return x - math.floor(x)
end

function Materials.texture(name: string, x: number, y: number, z: number, nx: number, ny: number, nz: number): number
	if name == "SmoothPlastic" or name == "Neon" or name == "Glass" or name == "ForceField" then
		return 1
	end
	local u, v = planar(x, y, z, nx, ny, nz)
	if name == "WoodPlanks" then
		local plank = math.floor(v / 1.6)
		local seam = frac(v / 1.6)
		local m = 1 + (hash(plank, 3) - 0.5) * 0.14 + (noise(u * 0.25, v * 3) - 0.5) * 0.1
		if seam < 0.06 then
			m *= 0.78
		end
		local joint = frac((u + hash(plank, 9) * 8) / 8)
		if joint < 0.015 then
			m *= 0.85
		end
		return m
	elseif name == "Wood" then
		return 1 + (noise(u * 0.2, v * 2.5) - 0.5) * 0.16 + (noise(u * 2, v * 2) - 0.5) * 0.05
	elseif name == "Brick" then
		local row = math.floor(v / 1)
		local col = frac((u + (row % 2) * 1) / 2)
		if frac(v) < 0.08 or col < 0.04 then
			return 1.18
		end
		return 1 + (hash(math.floor((u + (row % 2)) / 2), row) - 0.5) * 0.12
	elseif name == "CeramicTiles" or name == "ClayRoofTiles" or name == "RoofShingles" then
		if frac(u / 2) < 0.03 or frac(v / 2) < 0.03 then
			return 0.84
		end
		return 1 + (hash(math.floor(u / 2), math.floor(v / 2)) - 0.5) * 0.06
	elseif name == "DiamondPlate" then
		local d = math.abs(frac(u * 1.5 + v * 1.5) - 0.5) + math.abs(frac(u * 1.5 - v * 1.5) - 0.5)
		return if d < 0.18 then 1.1 else 0.97
	elseif name == "Grass" then
		return 1 + (noise(u * 0.7, v * 0.7) - 0.5) * 0.18 + (hash(math.floor(u * 4), math.floor(v * 4)) - 0.5) * 0.08
	elseif name == "Marble" then
		local vein = math.abs(math.sin(u * 0.4 + v * 0.25 + noise(u * 0.3, v * 0.3) * 6))
		return 1 - (1 - vein) ^ 8 * 0.18 + (noise(u, v) - 0.5) * 0.04
	elseif name == "Cobblestone" or name == "Pebble" or name == "Rock" or name == "Basalt" then
		local cell = noise(u * 0.9, v * 0.9)
		return 0.92 + cell * 0.16 + (hash(math.floor(u * 3), math.floor(v * 3)) - 0.5) * 0.06
	elseif name == "Slate" or name == "Granite" or name == "CorrodedMetal" or name == "Mud" then
		return 1 + (noise(u * 0.4, v * 0.4) - 0.5) * 0.16 + (noise(u * 3, v * 3) - 0.5) * 0.06
	elseif name == "Fabric" or name == "Carpet" then
		return 1 + (hash(math.floor(u * 6), math.floor(v * 6)) - 0.5) * 0.05
	elseif name == "Metal" or name == "Foil" then
		return 1 + (noise(u * 0.1, v * 8) - 0.5) * 0.05
	elseif name == "Sand" or name == "Snow" or name == "Salt" or name == "Ice" then
		return 1 + (noise(u * 0.8, v * 0.8) - 0.5) * 0.06
	end
	return 1 + (noise(u * 0.6, v * 0.6) - 0.5) * 0.05
end

return Materials
