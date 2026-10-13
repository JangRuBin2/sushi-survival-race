--!strict
--!native
-- 맵 Model → 렌더용 장면 (m5-23). 파츠마다 삼각형(월드 좌표·꼭짓점 법선)을 만들고, 조명·파티클·빔을 모아요.
--   Scene.new() -> Scene
--   Scene.addModel(scene, model)         Model 아래 BasePart·PointLight·SpotLight·SurfaceLight·ParticleEmitter·Beam
--   Scene.addBox(scene, cf, size, rgb, material, opts?)   장면에 상자 하나 더 (크기 비교용 초밥 인형 등)
-- 모양: Block / Ball(가장 짧은 변 지름) / Cylinder(로컬 X축) / Wedge / CornerWedge. 나머지 BasePart는 상자로 봐요.

local roblox = require("@lune/roblox")

export type PartInfo = {
	name: string,
	r: number, -- 선형 색 (0~1)
	g: number,
	b: number,
	material: string,
	alpha: number, -- 1 - Transparency
	reflectance: number,
	castShadow: boolean,
	neon: boolean,
	decor: boolean,
	lights: { number }?, -- 영향을 주는 조명 번호 (Raster가 채워요)
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

export type Light = {
	kind: string, -- "Point" | "Spot" | "Surface"
	x: number,
	y: number,
	z: number,
	dx: number, -- 방향 (Spot/Surface)
	dy: number,
	dz: number,
	r: number,
	g: number,
	b: number,
	brightness: number,
	range: number,
	cosAngle: number, -- Spot/Surface 원뿔 반각 코사인 (Point는 -1)
}

export type Emitter = {
	x: number,
	y: number,
	z: number,
	ex: number, -- 방출 영역 반 크기 (월드 축 근사)
	ey: number,
	ez: number,
	dx: number,
	dy: number,
	dz: number,
	ax: number,
	ay: number,
	az: number,
	speed: number,
	spread: number, -- 라디안
	lifetime: number,
	rate: number,
	drag: number,
	sizes: { { number } }, -- { 시간, 값 }
	alphas: { { number } }, -- { 시간, 투명도 }
	colors: { { number } }, -- { 시간, r, g, b } 선형
	lightEmission: number,
}

export type Beam = {
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	width0: number,
	width1: number,
	r: number,
	g: number,
	b: number,
	alpha: number,
	lightEmission: number,
}

export type Scene = {
	parts: { PartInfo },
	-- 삼각형마다: 꼭짓점 9개 숫자 (v), 꼭짓점 법선 9개 (n), 파츠 번호 (p)
	v: { number },
	n: { number },
	p: { number },
	lights: { Light },
	emitters: { Emitter },
	beams: { Beam },
	stats: {
		parts: number,
		judgment: number,
		decor: number,
		hidden: number,
		lights: number,
		particles: number,
		beams: number,
		triangles: number,
	},
}

local Scene = {}

local SPHERE_SEGMENTS = 16
local SPHERE_RINGS = 10
local CYLINDER_SEGMENTS = 16

function Scene.toLinear(c: number): number
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local toLinear = Scene.toLinear

function Scene.new(): Scene
	return {
		parts = {},
		v = {},
		n = {},
		p = {},
		lights = {},
		emitters = {},
		beams = {},
		stats = {
			parts = 0,
			judgment = 0,
			decor = 0,
			hidden = 0,
			lights = 0,
			particles = 0,
			beams = 0,
			triangles = 0,
		},
	}
end

type Xf = { number } -- { px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }

local function xfOf(cf: any): Xf
	local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- 삼각형 하나 (로컬 좌표·로컬 법선 → 월드)
local function tri(
	scene: Scene,
	xf: Xf,
	partIndex: number,
	part: PartInfo,
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	cx: number,
	cy: number,
	cz: number,
	na: { number },
	nb: { number },
	nc: { number }
)
	local v, n = scene.v, scene.n
	local px, py, pz = xf[1], xf[2], xf[3]
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = xf[4], xf[5], xf[6], xf[7], xf[8], xf[9], xf[10], xf[11], xf[12]
	local i = #v
	local function put(x: number, y: number, z: number, k: number)
		local wx = px + r00 * x + r01 * y + r02 * z
		local wy = py + r10 * x + r11 * y + r12 * z
		local wz = pz + r20 * x + r21 * y + r22 * z
		v[i + k + 1], v[i + k + 2], v[i + k + 3] = wx, wy, wz
		if wx < part.minX then
			part.minX = wx
		end
		if wy < part.minY then
			part.minY = wy
		end
		if wz < part.minZ then
			part.minZ = wz
		end
		if wx > part.maxX then
			part.maxX = wx
		end
		if wy > part.maxY then
			part.maxY = wy
		end
		if wz > part.maxZ then
			part.maxZ = wz
		end
	end
	local function putN(nn: { number }, k: number)
		local x, y, z = nn[1], nn[2], nn[3]
		n[i + k + 1] = r00 * x + r01 * y + r02 * z
		n[i + k + 2] = r10 * x + r11 * y + r12 * z
		n[i + k + 3] = r20 * x + r21 * y + r22 * z
	end
	put(ax, ay, az, 0)
	put(bx, by, bz, 3)
	put(cx, cy, cz, 6)
	putN(na, 0)
	putN(nb, 3)
	putN(nc, 6)
	table.insert(scene.p, partIndex)
end

local function normalize(x: number, y: number, z: number): { number }
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-9 then
		return { 0, 1, 0 }
	end
	return { x / l, y / l, z / l }
end

-- 평평한 사각형 (a, b, c, d 순서로 둘레)
local function quad(scene: Scene, xf: Xf, pi: number, part: PartInfo, q: { { number } }, nn: { number })
	local a, b, c, d = q[1], q[2], q[3], q[4]
	tri(scene, xf, pi, part, a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], nn, nn, nn)
	tri(scene, xf, pi, part, a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], nn, nn, nn)
end

-- 법선 방향을 고를 때 쓰는 모양 안쪽 점 (모양마다 꼭짓점 평균으로 정해요 — 원점은 경사면 위에 걸릴 수 있어요)
local insideX, insideY, insideZ = 0, 0, 0

local function flatTri(scene: Scene, xf: Xf, pi: number, part: PartInfo, a: { number }, b: { number }, c: { number })
	-- 법선은 모양 중심에서 바깥쪽이 되게 골라요
	local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
	local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
	local mx, my, mz = (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3
	if nx * (mx - insideX) + ny * (my - insideY) + nz * (mz - insideZ) < 0 then
		nx, ny, nz = -nx, -ny, -nz
	end
	local nn = normalize(nx, ny, nz)
	tri(scene, xf, pi, part, a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], nn, nn, nn)
end

local function flatQuad(scene: Scene, xf: Xf, pi: number, part: PartInfo, q: { { number } })
	flatTri(scene, xf, pi, part, q[1], q[2], q[3])
	flatTri(scene, xf, pi, part, q[1], q[3], q[4])
end

local function block(scene: Scene, xf: Xf, pi: number, part: PartInfo, hx: number, hy: number, hz: number)
	quad(scene, xf, pi, part, { { hx, -hy, -hz }, { hx, hy, -hz }, { hx, hy, hz }, { hx, -hy, hz } }, { 1, 0, 0 })
	quad(scene, xf, pi, part, { { -hx, -hy, hz }, { -hx, hy, hz }, { -hx, hy, -hz }, { -hx, -hy, -hz } }, { -1, 0, 0 })
	quad(scene, xf, pi, part, { { -hx, hy, -hz }, { -hx, hy, hz }, { hx, hy, hz }, { hx, hy, -hz } }, { 0, 1, 0 })
	quad(scene, xf, pi, part, { { -hx, -hy, hz }, { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz } }, { 0, -1, 0 })
	quad(scene, xf, pi, part, { { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, hz }, { -hx, hy, hz } }, { 0, 0, 1 })
	quad(scene, xf, pi, part, { { hx, -hy, -hz }, { -hx, -hy, -hz }, { -hx, hy, -hz }, { hx, hy, -hz } }, { 0, 0, -1 })
end

-- WedgePart: 경사면이 앞(-Z)·위를 보고, 높은 수직면이 뒤(+Z)예요
local function wedge(scene: Scene, xf: Xf, pi: number, part: PartInfo, hx: number, hy: number, hz: number)
	local b1, b2, b3, b4 = { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz }
	local t3, t4 = { hx, hy, hz }, { -hx, hy, hz }
	insideX, insideY, insideZ = 0, -hy / 3, hz / 3
	flatQuad(scene, xf, pi, part, { b1, b2, b3, b4 }) -- 바닥
	flatQuad(scene, xf, pi, part, { b4, b3, t3, t4 }) -- 뒤
	flatQuad(scene, xf, pi, part, { b1, b2, t3, t4 }) -- 경사
	flatTri(scene, xf, pi, part, b2, b3, t3) -- +X 옆
	flatTri(scene, xf, pi, part, b1, b4, t4) -- -X 옆
end

-- CornerWedgePart: 꼭대기 점이 (+X, 위, -Z) 모서리 위에 있어요
local function cornerWedge(scene: Scene, xf: Xf, pi: number, part: PartInfo, hx: number, hy: number, hz: number)
	local b1, b2, b3, b4 = { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz }
	local apex = { hx, hy, -hz }
	insideX, insideY, insideZ = hx / 5, -3 * hy / 5, -hz / 5
	flatQuad(scene, xf, pi, part, { b1, b2, b3, b4 })
	flatTri(scene, xf, pi, part, b2, b3, apex) -- +X 면
	flatTri(scene, xf, pi, part, b1, b2, apex) -- -Z 면
	flatTri(scene, xf, pi, part, b3, b4, apex) -- 경사 1
	flatTri(scene, xf, pi, part, b4, b1, apex) -- 경사 2
end

local function ball(scene: Scene, xf: Xf, pi: number, part: PartInfo, radius: number)
	local rings, segs = SPHERE_RINGS, SPHERE_SEGMENTS
	local function at(ring: number, seg: number): { number }
		local theta = math.pi * ring / rings
		local phi = 2 * math.pi * seg / segs
		return { math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi) }
	end
	for ring = 0, rings - 1 do
		for seg = 0, segs - 1 do
			local a, b, c, d = at(ring, seg), at(ring + 1, seg), at(ring + 1, seg + 1), at(ring, seg + 1)
			local r = radius
			if ring > 0 then
				tri(
					scene,
					xf,
					pi,
					part,
					a[1] * r,
					a[2] * r,
					a[3] * r,
					b[1] * r,
					b[2] * r,
					b[3] * r,
					d[1] * r,
					d[2] * r,
					d[3] * r,
					a,
					b,
					d
				)
			end
			if ring < rings - 1 then
				tri(
					scene,
					xf,
					pi,
					part,
					b[1] * r,
					b[2] * r,
					b[3] * r,
					c[1] * r,
					c[2] * r,
					c[3] * r,
					d[1] * r,
					d[2] * r,
					d[3] * r,
					b,
					c,
					d
				)
			end
		end
	end
end

-- Cylinder: 축이 로컬 X, 길이 = Size.X, 지름 = min(Size.Y, Size.Z)
local function cylinder(scene: Scene, xf: Xf, pi: number, part: PartInfo, hx: number, radius: number)
	local segs = CYLINDER_SEGMENTS
	local px, nx = { 1, 0, 0 }, { -1, 0, 0 }
	for s = 0, segs - 1 do
		local a0 = 2 * math.pi * s / segs
		local a1 = 2 * math.pi * (s + 1) / segs
		local y0, z0 = math.cos(a0), math.sin(a0)
		local y1, z1 = math.cos(a1), math.sin(a1)
		local n0, n1 = { 0, y0, z0 }, { 0, y1, z1 }
		local r = radius
		tri(scene, xf, pi, part, -hx, y0 * r, z0 * r, hx, y0 * r, z0 * r, hx, y1 * r, z1 * r, n0, n0, n1)
		tri(scene, xf, pi, part, -hx, y0 * r, z0 * r, hx, y1 * r, z1 * r, -hx, y1 * r, z1 * r, n0, n1, n1)
		tri(scene, xf, pi, part, hx, 0, 0, hx, y0 * r, z0 * r, hx, y1 * r, z1 * r, px, px, px)
		tri(scene, xf, pi, part, -hx, 0, 0, -hx, y1 * r, z1 * r, -hx, y0 * r, z0 * r, nx, nx, nx)
	end
end

local function underFolder(inst: any, root: any, folderName: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == folderName then
			return true
		end
		node = node.Parent
	end
	return false
end

local function safe(get: () -> any, fallback: any): any
	local ok, value = pcall(get)
	if ok and value ~= nil then
		return value
	end
	return fallback
end

export type BoxOptions = {
	transparency: number?,
	reflectance: number?,
	castShadow: boolean?,
	decor: boolean?,
	shape: string?,
	name: string?,
}

local function addShape(
	scene: Scene,
	cf: any,
	size: any,
	color: { number },
	material: string,
	shape: string,
	opts: BoxOptions
): number
	local alpha = 1 - (opts.transparency or 0)
	local part: PartInfo = {
		name = opts.name or "Part",
		r = toLinear(color[1]),
		g = toLinear(color[2]),
		b = toLinear(color[3]),
		material = material,
		alpha = alpha,
		reflectance = opts.reflectance or 0,
		castShadow = if opts.castShadow == nil then true else opts.castShadow,
		neon = material == "Neon",
		decor = opts.decor == true,
		minX = math.huge,
		minY = math.huge,
		minZ = math.huge,
		maxX = -math.huge,
		maxY = -math.huge,
		maxZ = -math.huge,
	}
	table.insert(scene.parts, part)
	local pi = #scene.parts
	local xf = xfOf(cf)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	if shape == "Ball" then
		ball(scene, xf, pi, part, math.min(hx, hy, hz))
	elseif shape == "Cylinder" then
		cylinder(scene, xf, pi, part, hx, math.min(hy, hz))
	elseif shape == "Wedge" then
		wedge(scene, xf, pi, part, hx, hy, hz)
	elseif shape == "CornerWedge" then
		cornerWedge(scene, xf, pi, part, hx, hy, hz)
	else
		block(scene, xf, pi, part, hx, hy, hz)
	end
	return pi
end

function Scene.addBox(scene: Scene, cf: any, size: any, color: { number }, material: string, opts: BoxOptions?): number
	local o = opts or {}
	return addShape(scene, cf, size, color, material, o.shape or "Block", o)
end

local function faceVector(cf: any, face: string): (number, number, number)
	local look = cf.LookVector
	local up = cf.UpVector
	local right = cf.RightVector
	if face == "Top" then
		return up.X, up.Y, up.Z
	elseif face == "Bottom" then
		return -up.X, -up.Y, -up.Z
	elseif face == "Right" then
		return right.X, right.Y, right.Z
	elseif face == "Left" then
		return -right.X, -right.Y, -right.Z
	elseif face == "Back" then
		return -look.X, -look.Y, -look.Z
	end
	return look.X, look.Y, look.Z
end

local function color3(c: any): { number }
	return { c.R, c.G, c.B }
end

local function sequenceNumbers(seq: any): { { number } }
	local out = {}
	for _, k in seq.Keypoints do
		table.insert(out, { k.Time, k.Value })
	end
	return out
end

local function hostCFrame(inst: any): any?
	local parent = inst.Parent
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") then
		return parent.CFrame
	end
	if parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
		return parent.Parent.CFrame * safe(function()
			return parent.CFrame
		end, roblox.CFrame.new())
	end
	return nil
end

local function hostSize(inst: any): any
	local parent = inst.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Size
	end
	return roblox.Vector3.new(0, 0, 0)
end

local function shapeOf(part: any): string
	local class = part.ClassName
	if class == "WedgePart" then
		return "Wedge"
	elseif class == "CornerWedgePart" then
		return "CornerWedge"
	elseif class == "Part" then
		local shape = safe(function()
			return part.Shape.Name
		end, "Block")
		if shape == "Ball" or shape == "Cylinder" then
			return shape
		end
	end
	return "Block"
end

function Scene.addModel(scene: Scene, model: any)
	local stats = scene.stats
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			if underFolder(inst, model, "IntroCamera") then
				continue
			end
			stats.parts += 1
			local decor = underFolder(inst, model, "Decor")
			if decor then
				stats.decor += 1
			else
				stats.judgment += 1
			end
			local transparency = safe(function()
				return inst.Transparency
			end, 0)
			if transparency >= 0.99 then
				stats.hidden += 1
				continue
			end
			local material = safe(function()
				return inst.Material.Name
			end, "Plastic")
			addShape(scene, inst.CFrame, inst.Size, color3(inst.Color), material, shapeOf(inst), {
				transparency = transparency,
				reflectance = safe(function()
					return inst.Reflectance
				end, 0),
				castShadow = safe(function()
					return inst.CastShadow
				end, true),
				decor = decor,
				name = inst.Name,
			})
		elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
			stats.lights += 1
			local cf = hostCFrame(inst)
			local enabled = safe(function()
				return inst.Enabled
			end, true)
			if cf == nil or not enabled then
				continue
			end
			local kind = if inst:IsA("PointLight") then "Point" elseif inst:IsA("SpotLight") then "Spot" else "Surface"
			local dx, dy, dz = 0, 0, 0
			local cosAngle = -1
			local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
			if kind ~= "Point" then
				local face = safe(function()
					return inst.Face.Name
				end, "Front")
				dx, dy, dz = faceVector(cf, face)
				local angle = safe(function()
					return inst.Angle
				end, 90)
				cosAngle = math.cos(math.rad(math.clamp(angle, 0, 180) / 2))
				if kind == "Surface" then
					-- 면 가운데에서 나와요
					local size = hostSize(inst)
					local half = math.abs(dx) * size.X / 2 + math.abs(dy) * size.Y / 2 + math.abs(dz) * size.Z / 2
					x, y, z = x + dx * half, y + dy * half, z + dz * half
				end
			end
			local c = color3(safe(function()
				return inst.Color
			end, roblox.Color3.new(1, 1, 1)))
			table.insert(scene.lights, {
				kind = kind,
				x = x,
				y = y,
				z = z,
				dx = dx,
				dy = dy,
				dz = dz,
				r = toLinear(c[1]),
				g = toLinear(c[2]),
				b = toLinear(c[3]),
				brightness = safe(function()
					return inst.Brightness
				end, 1),
				-- Roblox처럼 Surface는 16, Point·Spot은 60에서 잘라요 (m5-23 QA B1)
				range = math.min(
					safe(function()
						return inst.Range
					end, 8),
					if kind == "Surface" then 16 else 60
				),
				cosAngle = cosAngle,
			})
		elseif inst:IsA("ParticleEmitter") then
			stats.particles += 1
			local cf = hostCFrame(inst)
			local enabled = safe(function()
				return inst.Enabled
			end, true)
			if cf == nil or not enabled then
				continue
			end
			local face = safe(function()
				return inst.EmissionDirection.Name
			end, "Top")
			local dx, dy, dz = faceVector(cf, face)
			local size = hostSize(inst)
			local lifetime = safe(function()
				return inst.Lifetime
			end, roblox.NumberRange.new(1, 1))
			local speed = safe(function()
				return inst.Speed
			end, roblox.NumberRange.new(5, 5))
			local spread = safe(function()
				return inst.SpreadAngle
			end, roblox.Vector2.new(0, 0))
			local accel = safe(function()
				return inst.Acceleration
			end, roblox.Vector3.new(0, 0, 0))
			local colors = {}
			local colorSeq = safe(function()
				return inst.Color
			end, nil)
			if colorSeq then
				for _, k in colorSeq.Keypoints do
					table.insert(colors, { k.Time, toLinear(k.Value.R), toLinear(k.Value.G), toLinear(k.Value.B) })
				end
			else
				colors = { { 0, 1, 1, 1 }, { 1, 1, 1, 1 } }
			end
			table.insert(scene.emitters, {
				x = cf.Position.X,
				y = cf.Position.Y,
				z = cf.Position.Z,
				ex = size.X / 2,
				ey = size.Y / 2,
				ez = size.Z / 2,
				dx = dx,
				dy = dy,
				dz = dz,
				ax = accel.X,
				ay = accel.Y,
				az = accel.Z,
				speed = (speed.Min + speed.Max) / 2,
				spread = math.rad(math.max(spread.X, spread.Y)),
				lifetime = (lifetime.Min + lifetime.Max) / 2,
				rate = safe(function()
					return inst.Rate
				end, 5),
				drag = safe(function()
					return inst.Drag
				end, 0),
				sizes = sequenceNumbers(safe(function()
					return inst.Size
				end, roblox.NumberSequence.new(1))),
				alphas = sequenceNumbers(safe(function()
					return inst.Transparency
				end, roblox.NumberSequence.new(0))),
				colors = colors,
				lightEmission = safe(function()
					return inst.LightEmission
				end, 0),
			})
		elseif inst:IsA("Beam") then
			stats.beams += 1
			local a0 = safe(function()
				return inst.Attachment0
			end, nil)
			local a1 = safe(function()
				return inst.Attachment1
			end, nil)
			local p0 = a0 and hostCFrame({ Parent = a0 } :: any)
			local p1 = a1 and hostCFrame({ Parent = a1 } :: any)
			if p0 and p1 then
				local colorSeq = safe(function()
					return inst.Color
				end, nil)
				local c = if colorSeq then colorSeq.Keypoints[1].Value else roblox.Color3.new(1, 1, 1)
				local tSeq = safe(function()
					return inst.Transparency
				end, nil)
				local t = if tSeq then tSeq.Keypoints[1].Value else 0.5
				table.insert(scene.beams, {
					ax = p0.Position.X,
					ay = p0.Position.Y,
					az = p0.Position.Z,
					bx = p1.Position.X,
					by = p1.Position.Y,
					bz = p1.Position.Z,
					width0 = safe(function()
						return inst.Width0
					end, 1),
					width1 = safe(function()
						return inst.Width1
					end, 1),
					r = toLinear(c.R),
					g = toLinear(c.G),
					b = toLinear(c.B),
					alpha = 1 - t,
					lightEmission = safe(function()
						return inst.LightEmission
					end, 0),
				})
			end
		end
	end
	stats.triangles = #scene.p
end

return Scene
