--!strict
--!native
-- 소프트웨어 래스터라이저 (m5-23). 순수 Luau, Roblox API 없음.
--   Raster.perspective(pos, target, fovDeg, aspect) -> Camera
--   Raster.orthographic(center, forward, up, halfWidth, halfHeight) -> Camera
--   Raster.render(scene, camera, lighting, options) -> Image   (8비트 RGB 버퍼)
--
-- 순서: 해 그림자 지도 + 하늘 가림 지도 → 불투명 G-버퍼(깊이·법선·삼각형) → 픽셀마다 한 번 셰이딩
--       → 투명 삼각형(뒤에서 앞으로) → 파티클 점 → 다운샘플 → 블룸 → 노출·ACES 톤매핑 → sRGB → 색 보정.
-- 빛 계산은 선형 색 공간. 수치는 Roblox Future 조명과 "비슷해 보이게" 맞춘 근사예요 (같지는 않아요).

local Materials = require("./Materials")
local Scene = require("./Scene")

type Scene = Scene.Scene

export type Camera = {
	ortho: boolean,
	px: number,
	py: number,
	pz: number,
	rx: number,
	ry: number,
	rz: number,
	ux: number,
	uy: number,
	uz: number,
	fx: number,
	fy: number,
	fz: number,
	sx: number, -- 원근: tan(가로 반각), 직교: 반 너비
	sy: number, -- 원근: tan(세로 반각), 직교: 반 높이
	clipAboveY: number?, -- 이 높이보다 위에서 시작하는 파츠는 안 그려요 (위에서 본 배치도용, 그림자는 그대로)
}

export type Options = {
	width: number,
	height: number,
	supersample: number,
	shadowSize: number,
}

export type Image = { width: number, height: number, rgb: buffer, void: number } -- void: 수평선 아래 허공 픽셀 비율 (0~1)

type V3 = { x: number, y: number, z: number }

local Raster = {}

local NEAR = 0.3

local function norm3(x: number, y: number, z: number): (number, number, number)
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-12 then
		return 0, 0, 0
	end
	return x / l, y / l, z / l
end

local function cross(ax: number, ay: number, az: number, bx: number, by: number, bz: number): (number, number, number)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function basis(fx: number, fy: number, fz: number, upx: number, upy: number, upz: number)
	fx, fy, fz = norm3(fx, fy, fz)
	local rx, ry, rz = cross(fx, fy, fz, upx, upy, upz)
	if rx * rx + ry * ry + rz * rz < 1e-8 then
		rx, ry, rz = cross(fx, fy, fz, 0, 0, -1)
	end
	rx, ry, rz = norm3(rx, ry, rz)
	local ux, uy, uz = cross(rx, ry, rz, fx, fy, fz)
	return fx, fy, fz, rx, ry, rz, ux, uy, uz
end

function Raster.perspective(pos: V3, target: V3, fovDeg: number, aspect: number): Camera
	local fx, fy, fz, rx, ry, rz, ux, uy, uz = basis(target.x - pos.x, target.y - pos.y, target.z - pos.z, 0, 1, 0)
	local ty = math.tan(math.rad(fovDeg) / 2)
	return {
		ortho = false,
		px = pos.x,
		py = pos.y,
		pz = pos.z,
		rx = rx,
		ry = ry,
		rz = rz,
		ux = ux,
		uy = uy,
		uz = uz,
		fx = fx,
		fy = fy,
		fz = fz,
		sx = ty * aspect,
		sy = ty,
	}
end

function Raster.orthographic(center: V3, forward: V3, up: V3, halfWidth: number, halfHeight: number): Camera
	local fx, fy, fz, rx, ry, rz, ux, uy, uz = basis(forward.x, forward.y, forward.z, up.x, up.y, up.z)
	return {
		ortho = true,
		px = center.x,
		py = center.y,
		pz = center.z,
		rx = rx,
		ry = ry,
		rz = rz,
		ux = ux,
		uy = uy,
		uz = uz,
		fx = fx,
		fy = fy,
		fz = fz,
		sx = halfWidth,
		sy = halfHeight,
	}
end

-- ── 해 ───────────────────────────────────────────────────────────────
-- Roblox 하늘처럼: 동쪽 = +X, 남쪽 = +Z, 정오에 남쪽 하늘 (위도 GeographicLatitude)
function Raster.sunDirection(clockTime: number, latitude: number): (number, number, number)
	local h = (clockTime - 12) / 12 * math.pi
	local lat = math.rad(latitude)
	return norm3(-math.sin(h), math.cos(lat) * math.cos(h), math.sin(lat) * math.cos(h))
end

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local lin = Scene.toLinear
local function linColor(c: { r: number, g: number, b: number }): (number, number, number)
	return lin(c.r / 255), lin(c.g / 255), lin(c.b / 255)
end

-- ── 깊이 지도 (직교, 해 방향·하늘 방향) ────────────────────────────────
type DepthMap = {
	size: number,
	depth: buffer, -- f32, 클수록 빛 쪽에 가까워요
	ux: number,
	uy: number,
	uz: number,
	vx: number,
	vy: number,
	vz: number,
	dx: number,
	dy: number,
	dz: number,
	u0: number,
	v0: number,
	scale: number, -- 텍셀 / stud
	texel: number, -- stud / 텍셀
}

local function buildDepthMap(
	scene: Scene,
	dx: number,
	dy: number,
	dz: number,
	size: number,
	bounds: { number }
): DepthMap
	-- 빛 방향 d(빛 쪽을 향함)에 수직인 축 u, v
	local ax, ay, az = 0, 1, 0
	if math.abs(dy) > 0.9 then
		ax, ay, az = 0, 0, -1
	end
	local ux, uy, uz = norm3(cross(ax, ay, az, dx, dy, dz))
	local vx, vy, vz = cross(dx, dy, dz, ux, uy, uz)
	-- bounds 상자 꼭짓점 8개를 u, v로 투영
	local umin, umax, vmin, vmax = math.huge, -math.huge, math.huge, -math.huge
	for i = 0, 7 do
		local x = if i % 2 == 0 then bounds[1] else bounds[4]
		local y = if math.floor(i / 2) % 2 == 0 then bounds[2] else bounds[5]
		local z = if math.floor(i / 4) % 2 == 0 then bounds[3] else bounds[6]
		local u = x * ux + y * uy + z * uz
		local v = x * vx + y * vy + z * vz
		umin, umax = math.min(umin, u), math.max(umax, u)
		vmin, vmax = math.min(vmin, v), math.max(vmax, v)
	end
	local extent = math.max(umax - umin, vmax - vmin, 1)
	local scale = (size - 2) / extent
	local map: DepthMap = {
		size = size,
		depth = buffer.create(size * size * 4),
		ux = ux,
		uy = uy,
		uz = uz,
		vx = vx,
		vy = vy,
		vz = vz,
		dx = dx,
		dy = dy,
		dz = dz,
		u0 = umin - 1 / scale,
		v0 = vmin - 1 / scale,
		scale = scale,
		texel = 1 / scale,
	}
	local depth = map.depth
	for i = 0, size * size - 1 do
		buffer.writef32(depth, i * 4, -1e30)
	end
	local v, parts, pidx = scene.v, scene.parts, scene.p
	local u0, v0 = map.u0, map.v0
	for t = 1, #pidx do
		local part = parts[pidx[t]]
		if not part.castShadow or part.alpha < 0.5 then
			continue
		end
		local b = (t - 1) * 9
		local x0, y0, z0 = v[b + 1], v[b + 2], v[b + 3]
		local x1, y1, z1 = v[b + 4], v[b + 5], v[b + 6]
		local x2, y2, z2 = v[b + 7], v[b + 8], v[b + 9]
		local sx0 = (x0 * ux + y0 * uy + z0 * uz - u0) * scale
		local sy0 = (x0 * vx + y0 * vy + z0 * vz - v0) * scale
		local d0 = x0 * dx + y0 * dy + z0 * dz
		local sx1 = (x1 * ux + y1 * uy + z1 * uz - u0) * scale
		local sy1 = (x1 * vx + y1 * vy + z1 * vz - v0) * scale
		local d1 = x1 * dx + y1 * dy + z1 * dz
		local sx2 = (x2 * ux + y2 * uy + z2 * uz - u0) * scale
		local sy2 = (x2 * vx + y2 * vy + z2 * vz - v0) * scale
		local d2 = x2 * dx + y2 * dy + z2 * dz
		local area = (sx1 - sx0) * (sy2 - sy0) - (sy1 - sy0) * (sx2 - sx0)
		if math.abs(area) < 1e-9 then
			continue
		end
		local minx = math.max(0, math.floor(math.min(sx0, sx1, sx2)))
		local maxx = math.min(size - 1, math.ceil(math.max(sx0, sx1, sx2)))
		local miny = math.max(0, math.floor(math.min(sy0, sy1, sy2)))
		local maxy = math.min(size - 1, math.ceil(math.max(sy0, sy1, sy2)))
		local inv = 1 / area
		for py = miny, maxy do
			local cy = py + 0.5
			for px = minx, maxx do
				local cx = px + 0.5
				local w0 = ((sx2 - sx1) * (cy - sy1) - (sy2 - sy1) * (cx - sx1)) * inv
				local w1 = ((sx0 - sx2) * (cy - sy2) - (sy0 - sy2) * (cx - sx2)) * inv
				local w2 = 1 - w0 - w1
				-- 텍셀을 조금 넉넉히 덮어서 얇은 파츠의 그림자 틈을 막아요
				if w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02 then
					local d = w0 * d0 + w1 * d1 + w2 * d2
					local o = (py * size + px) * 4
					if d > buffer.readf32(depth, o) then
						buffer.writef32(depth, o, d)
					end
				end
			end
		end
	end
	return map
end

-- 점 (x, y, z)가 빛을 받는 비율 0~1 (radius 텍셀 반경 PCF)
local function sampleDepth(map: DepthMap, x: number, y: number, z: number, bias: number, radius: number): number
	local size = map.size
	local u = (x * map.ux + y * map.uy + z * map.uz - map.u0) * map.scale
	local v = (x * map.vx + y * map.vy + z * map.vz - map.v0) * map.scale
	local d = x * map.dx + y * map.dy + z * map.dz + bias
	local lit, total = 0, 0
	local depth = map.depth
	for oy = -1, 1 do
		for ox = -1, 1 do
			local tx = math.floor(u + ox * radius)
			local ty = math.floor(v + oy * radius)
			total += 1
			if tx < 0 or ty < 0 or tx >= size or ty >= size then
				lit += 1
			elseif d >= buffer.readf32(depth, (ty * size + tx) * 4) then
				lit += 1
			end
		end
	end
	return lit / total
end

-- ── 셰이딩 환경 ───────────────────────────────────────────────────────
type Env = {
	sunX: number,
	sunY: number,
	sunZ: number,
	sunR: number,
	sunG: number,
	sunB: number,
	ambR: number,
	ambG: number,
	ambB: number,
	outR: number,
	outG: number,
	outB: number,
	envDiffuse: number,
	envSpecular: number,
	fogR: number,
	fogG: number,
	fogB: number,
	fogDensity: number,
	glare: number,
	zenR: number,
	zenG: number,
	zenB: number,
	horR: number,
	horG: number,
	horB: number,
	shadow: DepthMap?,
	sky: DepthMap?,
	softness: number,
	lights: { Scene.Light },
	camX: number,
	camY: number,
	camZ: number,
	ortho: boolean,
	camFX: number,
	camFY: number,
	camFZ: number,
}

local function makeEnv(scene: Scene, lighting: any, cam: Camera, bounds: { number }, shadowSize: number): Env
	local lat = lighting.GeographicLatitude
	local sx, sy, sz = Raster.sunDirection(lighting.ClockTime, lat)
	local elevation = sy
	-- 낮에는 해, 밤에는 반대편의 달빛
	local dayFactor = smoothstep(-0.08, 0.12, elevation)
	local warm = math.clamp(1 - elevation * 1.8, 0, 1) ^ 1.6
	local sunR = 1.0 * (1 - warm) + 1.0 * warm
	local sunG = 0.96 * (1 - warm) + 0.6 * warm
	local sunB = 0.9 * (1 - warm) + 0.34 * warm
	local intensity = lighting.Brightness * 0.62 * dayFactor
	local lx, ly, lz = sx, sy, sz
	if dayFactor < 0.05 then
		lx, ly, lz = -sx, math.abs(sy) + 0.3, -sz
		lx, ly, lz = norm3(lx, ly, lz)
		sunR, sunG, sunB = 0.55, 0.65, 1.0
		intensity = lighting.Brightness * 0.12
	end
	local ambR, ambG, ambB = linColor(lighting.Ambient)
	local outR, outG, outB = linColor(lighting.OutdoorAmbient)
	local atm = lighting.Atmosphere
	local fogR, fogG, fogB = linColor(atm.Color)
	local decR, decG, decB = linColor(atm.Decay)
	-- 하늘: 낮 파랑 → 해질녘 주황 → 밤 남색, 지평선은 대기 색
	local zenR, zenG, zenB = 0.12, 0.3, 0.75
	local horR, horG, horB = fogR * 0.9 + 0.1, fogG * 0.9 + 0.12, fogB * 0.9 + 0.18
	local dusk = warm * dayFactor
	zenR = zenR * (1 - dusk) + 0.3 * dusk
	zenG = zenG * (1 - dusk) + 0.22 * dusk
	zenB = zenB * (1 - dusk) + 0.42 * dusk
	horR = horR * (1 - dusk) + (decR * 0.4 + 1.0 * 0.6) * dusk
	horG = horG * (1 - dusk) + (decG * 0.4 + 0.5 * 0.6) * dusk
	horB = horB * (1 - dusk) + (decB * 0.4 + 0.3 * 0.6) * dusk
	local night = 1 - dayFactor
	zenR, zenG, zenB =
		zenR * (1 - night) + 0.01 * night, zenG * (1 - night) + 0.015 * night, zenB * (1 - night) + 0.05 * night
	horR, horG, horB =
		horR * (1 - night) + 0.04 * night, horG * (1 - night) + 0.05 * night, horB * (1 - night) + 0.1 * night
	local skyGain = 0.35 + 0.65 * dayFactor
	-- 안개 색: 대기 색에 해 빛을 섞어요 (Decay는 해 반대편 쪽)
	fogR = (fogR * 0.8 + decR * 0.2) * skyGain
	fogG = (fogG * 0.8 + decG * 0.2) * skyGain
	fogB = (fogB * 0.8 + decB * 0.2) * skyGain
	local env: Env = {
		sunX = lx,
		sunY = ly,
		sunZ = lz,
		sunR = sunR * intensity,
		sunG = sunG * intensity,
		sunB = sunB * intensity,
		ambR = ambR,
		ambG = ambG,
		ambB = ambB,
		outR = outR,
		outG = outG,
		outB = outB,
		envDiffuse = lighting.EnvironmentDiffuseScale,
		envSpecular = lighting.EnvironmentSpecularScale,
		fogR = fogR,
		fogG = fogG,
		fogB = fogB,
		fogDensity = atm.Density * (1 + atm.Haze * 0.12),
		glare = atm.Glare,
		zenR = zenR * skyGain,
		zenG = zenG * skyGain,
		zenB = zenB * skyGain,
		horR = horR * skyGain,
		horG = horG * skyGain,
		horB = horB * skyGain,
		shadow = nil,
		sky = nil,
		softness = lighting.ShadowSoftness,
		lights = scene.lights,
		camX = cam.px,
		camY = cam.py,
		camZ = cam.pz,
		ortho = cam.ortho,
		camFX = cam.fx,
		camFY = cam.fy,
		camFZ = cam.fz,
	}
	if intensity > 0.01 then
		env.shadow = buildDepthMap(scene, lx, ly, lz, shadowSize, bounds)
	end
	env.sky = buildDepthMap(scene, 0, 1, 0, math.floor(shadowSize / 2), bounds)
	return env
end

-- 하늘 색 (방향 → 선형 색)
local function skyColor(env: Env, dx: number, dy: number, dz: number): (number, number, number)
	local t = math.clamp(dy, 0, 1) ^ 0.55
	local r = env.horR + (env.zenR - env.horR) * t
	local g = env.horG + (env.zenG - env.horG) * t
	local b = env.horB + (env.zenB - env.horB) * t
	if dy < 0 then
		-- 지평선 아래(아레나 밑 허공): 안개 색보다 어둡고 차갑게 — 맵 바닥 색과 헷갈리지 않게
		local k = math.clamp(-dy * 2.5, 0, 1)
		local grey = (env.fogR + env.fogG + env.fogB) / 3
		local vr, vg, vb = env.fogR * 0.5 + grey * 0.5, env.fogG * 0.5 + grey * 0.5, env.fogB * 0.5 + grey * 0.5
		r = r + (vr * 0.4 - r) * k
		g = g + (vg * 0.44 - g) * k
		b = b + (vb * 0.52 - b) * k
	end
	-- 짙은 대기는 지평선 근처 하늘도 뿌옇게
	local haze = math.clamp(env.fogDensity * 1.2, 0, 0.85) * (1 - math.clamp(dy, 0, 1)) ^ 3
	r = r + (env.fogR - r) * haze
	g = g + (env.fogG - g) * haze
	b = b + (env.fogB - b) * haze
	-- 해 원반과 번짐
	local sd = dx * env.sunX + dy * env.sunY + dz * env.sunZ
	if sd > 0 then
		local glow = sd ^ 64 * 1.2 + sd ^ 8 * (0.12 + env.glare * 0.1)
		r += env.sunR * glow * 0.6
		g += env.sunG * glow * 0.6
		b += env.sunB * glow * 0.6
		if sd > 0.9995 then
			r, g, b = r + 6, g + 5.5, b + 5
		end
	end
	return r, g, b
end
Raster.skyColor = skyColor

-- 표면 한 점의 색 (선형 HDR). neon이면 두 번째 값이 1.
local function shade(
	env: Env,
	scene: Scene,
	part: Scene.PartInfo,
	x: number,
	y: number,
	z: number,
	nx: number,
	ny: number,
	nz: number
): (number, number, number, number)
	local mat = Materials.get(part.material)
	local tex = Materials.texture(part.material, x, y, z, nx, ny, nz)
	local ar, ag, ab = part.r * tex * mat.albedo, part.g * tex * mat.albedo, part.b * tex * mat.albedo
	-- 보는 방향 (표면 → 카메라)
	local vx, vy, vz
	if env.ortho then
		vx, vy, vz = -env.camFX, -env.camFY, -env.camFZ
	else
		vx, vy, vz = norm3(env.camX - x, env.camY - y, env.camZ - z)
	end
	if nx * vx + ny * vy + nz * vz < 0 then
		-- 보간 법선이 뒤를 보면 뒤집어요 (얇은 면 안쪽)
		nx, ny, nz = -nx, -ny, -nz
	end
	local r, g, b
	local neon = 0
	if part.neon then
		r, g, b = ar * 2.6 + 0.04, ag * 2.6 + 0.04, ab * 2.6 + 0.04
		neon = 1
	else
		-- 해
		local ndl = nx * env.sunX + ny * env.sunY + nz * env.sunZ
		local sun = 0
		if ndl > 0 then
			sun = ndl
			local map = env.shadow
			if map then
				local off = map.texel * 1.2 + 0.05
				sun *= sampleDepth(
					map,
					x + nx * off,
					y + ny * off,
					z + nz * off,
					map.texel * 1.5 + 0.08,
					1 + env.softness * 2.5
				)
			end
		end
		-- 하늘 가림 (지붕·카운터 밑은 바깥 환경광이 줄어요)
		local skyVis = 1
		local skyMap = env.sky
		if skyMap then
			skyVis = sampleDepth(skyMap, x + nx * 0.6, y + ny * 0.6, z + nz * 0.6, 0.4, 3)
			skyVis = 0.3 + 0.7 * skyVis
		end
		local hemi = 0.6 + 0.4 * ny
		local envK = env.envDiffuse * 0.55 * (0.5 + 0.5 * ny) * skyVis
		local lr = env.sunR * sun + env.ambR * 0.85 + env.outR * hemi * skyVis + env.zenR * envK
		local lg = env.sunG * sun + env.ambG * 0.85 + env.outG * hemi * skyVis + env.zenG * envK
		local lb = env.sunB * sun + env.ambB * 0.85 + env.outB * hemi * skyVis + env.zenB * envK
		-- 점·스포트·면 조명
		local list = part.lights
		if list then
			local lights = env.lights
			for _, li in list do
				local light = lights[li]
				local tx, ty, tz = light.x - x, light.y - y, light.z - z
				local d2 = tx * tx + ty * ty + tz * tz
				local range = light.range
				if d2 < range * range then
					local d = math.sqrt(d2) + 1e-6
					tx, ty, tz = tx / d, ty / d, tz / d
					local ndl2 = nx * tx + ny * ty + nz * tz
					if ndl2 > 0 then
						local fall = 1 - d / range
						local k = fall * fall * light.brightness * ndl2 * 1.6
						if light.cosAngle > -1 then
							local c = -(tx * light.dx + ty * light.dy + tz * light.dz)
							k *= smoothstep(light.cosAngle, light.cosAngle + 0.08, c)
						end
						lr += light.r * k
						lg += light.g * k
						lb += light.b * k
					end
				end
			end
		end
		r, g, b = ar * lr, ag * lg, ab * lb
		-- 하이라이트 (해)
		if sun > 0 and mat.spec > 0 then
			local hx, hy, hz = norm3(env.sunX + vx, env.sunY + vy, env.sunZ + vz)
			local s = (math.max(0, nx * hx + ny * hy + nz * hz) ^ mat.shine) * mat.spec * sun
			r += env.sunR * s
			g += env.sunG * s
			b += env.sunB * s
		end
		-- 반사 (Reflectance + 재질 기본 반사 + 프레넬)
		local ndv = math.max(0, nx * vx + ny * vy + nz * vz)
		local fres = (1 - ndv) ^ 5
		local refl = math.clamp(part.reflectance + mat.env + fres * mat.spec * 0.5, 0, 1)
			* (0.4 + 0.6 * env.envSpecular)
		if refl > 0.002 then
			local dn = 2 * (nx * vx + ny * vy + nz * vz)
			local rx, ry, rz = nx * dn - vx, ny * dn - vy, nz * dn - vz
			local sr, sg, sb = skyColor(env, rx, ry, rz)
			sr, sg, sb = sr * skyVis, sg * skyVis, sb * skyVis
			r = r + (sr - r) * refl
			g = g + (sg - g) * refl
			b = b + (sb - b) * refl
		end
	end
	-- 안개
	local fx, fy, fz = x - env.camX, y - env.camY, z - env.camZ
	local dist = math.sqrt(fx * fx + fy * fy + fz * fz)
	local f = 1 - math.exp(-env.fogDensity * dist / 380)
	if f > 0.001 then
		r = r + (env.fogR - r) * f
		g = g + (env.fogG - g) * f
		b = b + (env.fogB - b) * f
	end
	return r, g, b, neon
end

-- ── 투영 ────────────────────────────────────────────────────────────
-- 화면 좌표 (sx, sy), q = 1/w, zq = z/w
local function project(
	cam: Camera,
	W: number,
	H: number,
	x: number,
	y: number,
	z: number
): (number, number, number, number)
	if cam.ortho then
		return (x / cam.sx * 0.5 + 0.5) * W, (0.5 - y / cam.sy * 0.5) * H, 1, z
	end
	return (x / (z * cam.sx) * 0.5 + 0.5) * W, (0.5 - y / (z * cam.sy) * 0.5) * H, 1 / z, 1
end

type ClipVert = { number } -- { vx, vy, vz, nx, ny, nz }

-- 가까운 평면(z = NEAR) 자르기
local function clipNear(poly: { ClipVert }): { ClipVert }
	local out = {}
	local n = #poly
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		local ain, bin = a[3] >= NEAR, b[3] >= NEAR
		if ain then
			table.insert(out, a)
		end
		if ain ~= bin then
			local t = (NEAR - a[3]) / (b[3] - a[3])
			local v = {}
			for k = 1, 6 do
				v[k] = a[k] + (b[k] - a[k]) * t
			end
			table.insert(out, v)
		end
	end
	return out
end

-- 삼각형 하나를 화면에 래스터화하면서 픽셀마다 fn(o, z, nx, ny, nz)
type PixelFn = (index: number, px: number, py: number, z: number, nx: number, ny: number, nz: number) -> ()

local function rasterTri(W: number, H: number, a: { number }, b: { number }, c: { number }, zb: buffer, fn: PixelFn)
	-- a, b, c = { sx, sy, q, zq, nx, ny, nz }
	local x0, y0, x1, y1, x2, y2 = a[1], a[2], b[1], b[2], c[1], c[2]
	local area = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
	if math.abs(area) < 1e-9 then
		return
	end
	local minx = math.max(0, math.floor(math.min(x0, x1, x2)))
	local maxx = math.min(W - 1, math.ceil(math.max(x0, x1, x2)))
	local miny = math.max(0, math.floor(math.min(y0, y1, y2)))
	local maxy = math.min(H - 1, math.ceil(math.max(y0, y1, y2)))
	if minx > maxx or miny > maxy then
		return
	end
	local inv = 1 / area
	local q0, q1, q2 = a[3], b[3], c[3]
	local z0, z1, z2 = a[4], b[4], c[4]
	-- 법선은 q를 곱해서 원근 보정
	local n0x, n0y, n0z = a[5] * q0, a[6] * q0, a[7] * q0
	local n1x, n1y, n1z = b[5] * q1, b[6] * q1, b[7] * q1
	local n2x, n2y, n2z = c[5] * q2, c[6] * q2, c[7] * q2
	-- 증분 엣지 함수: w0 = A0*x + B0*y + C0
	local A0, B0 = -(y2 - y1) * inv, (x2 - x1) * inv
	local A1, B1 = -(y0 - y2) * inv, (x0 - x2) * inv
	local C0 = -(A0 * x1 + B0 * y1)
	local C1 = -(A1 * x2 + B1 * y2)
	for py = miny, maxy do
		local cy = py + 0.5
		local cx0 = minx + 0.5
		local w0 = A0 * cx0 + B0 * cy + C0
		local w1 = A1 * cx0 + B1 * cy + C1
		local rowBase = py * W
		for px = minx, maxx do
			local w2 = 1 - w0 - w1
			if w0 >= -1e-5 and w1 >= -1e-5 and w2 >= -1e-5 then
				local q = w0 * q0 + w1 * q1 + w2 * q2
				local z = (w0 * z0 + w1 * z1 + w2 * z2) / q
				local idx = rowBase + px
				if z < buffer.readf32(zb, idx * 4) then
					local iq = 1 / q
					fn(
						idx,
						px,
						py,
						z,
						(w0 * n0x + w1 * n1x + w2 * n2x) * iq,
						(w0 * n0y + w1 * n1y + w2 * n2y) * iq,
						(w0 * n0z + w1 * n1z + w2 * n2z) * iq
					)
				end
			end
			w0 += A0
			w1 += A1
		end
	end
end

-- 삼각형 t를 카메라 공간으로 → 자르기 → 화면 꼭짓점 목록 (부채꼴 삼각형들)
local function screenTris(scene: Scene, cam: Camera, W: number, H: number, t: number): { { { number } } }?
	local v, n = scene.v, scene.n
	local b = (t - 1) * 9
	local poly: { ClipVert } = {}
	local anyFront = false
	for k = 0, 2 do
		local x, y, z = v[b + k * 3 + 1] - cam.px, v[b + k * 3 + 2] - cam.py, v[b + k * 3 + 3] - cam.pz
		local cx = x * cam.rx + y * cam.ry + z * cam.rz
		local cy = x * cam.ux + y * cam.uy + z * cam.uz
		local cz = x * cam.fx + y * cam.fy + z * cam.fz
		if cz >= NEAR then
			anyFront = true
		end
		poly[k + 1] = { cx, cy, cz, n[b + k * 3 + 1], n[b + k * 3 + 2], n[b + k * 3 + 3] }
	end
	if not anyFront then
		return nil
	end
	if poly[1][3] < NEAR or poly[2][3] < NEAR or poly[3][3] < NEAR then
		poly = clipNear(poly)
		if #poly < 3 then
			return nil
		end
	end
	local verts = {}
	for i, p in poly do
		local sx, sy, q, zq = project(cam, W, H, p[1], p[2], p[3])
		if cam.ortho then
			zq = p[3]
		end
		verts[i] = { sx, sy, q, zq, p[4], p[5], p[6] }
	end
	local out = {}
	for i = 2, #verts - 1 do
		table.insert(out, { verts[1], verts[i], verts[i + 1] })
	end
	return out
end

-- 화면 픽셀 → 월드 좌표 (깊이 z = 카메라 앞쪽 거리)
local function unproject(cam: Camera, W: number, H: number, px: number, py: number, z: number): (number, number, number)
	local ndx = (px + 0.5) / W * 2 - 1
	local ndy = 1 - (py + 0.5) / H * 2
	if cam.ortho then
		local ox, oy = ndx * cam.sx, ndy * cam.sy
		return cam.px + cam.rx * ox + cam.ux * oy + cam.fx * z,
			cam.py + cam.ry * ox + cam.uy * oy + cam.fy * z,
			cam.pz + cam.rz * ox + cam.uz * oy + cam.fz * z
	end
	local dx = cam.fx + cam.rx * ndx * cam.sx + cam.ux * ndy * cam.sy
	local dy = cam.fy + cam.ry * ndx * cam.sx + cam.uy * ndy * cam.sy
	local dz = cam.fz + cam.rz * ndx * cam.sx + cam.uz * ndy * cam.sy
	return cam.px + dx * z, cam.py + dy * z, cam.pz + dz * z
end

local function rayDir(cam: Camera, W: number, H: number, px: number, py: number): (number, number, number)
	if cam.ortho then
		return cam.fx, cam.fy, cam.fz
	end
	local ndx = (px + 0.5) / W * 2 - 1
	local ndy = 1 - (py + 0.5) / H * 2
	return norm3(
		cam.fx + cam.rx * ndx * cam.sx + cam.ux * ndy * cam.sy,
		cam.fy + cam.ry * ndx * cam.sx + cam.uy * ndy * cam.sy,
		cam.fz + cam.rz * ndx * cam.sx + cam.uz * ndy * cam.sy
	)
end

-- 파츠마다 영향을 주는 조명 목록
local function assignLights(scene: Scene)
	for _, part in scene.parts do
		local list = {}
		for i, light in scene.lights do
			local r = light.range
			if
				light.x + r >= part.minX
				and light.x - r <= part.maxX
				and light.y + r >= part.minY
				and light.y - r <= part.maxY
				and light.z + r >= part.minZ
				and light.z - r <= part.maxZ
			then
				table.insert(list, i)
			end
		end
		part.lights = if #list > 0 then list else nil
	end
end

local function sampleCurve(points: { { number } }, t: number, index: number): number
	local prev = points[1]
	if prev == nil then
		return 0
	end
	if t <= prev[1] then
		return prev[index]
	end
	for i = 2, #points do
		local cur = points[i]
		if t <= cur[1] then
			local span = cur[1] - prev[1]
			local k = if span > 0 then (t - prev[1]) / span else 0
			return prev[index] + (cur[index] - prev[index]) * k
		end
		prev = cur
	end
	return prev[index]
end

-- 결정적인 난수 (같은 장면이면 같은 그림)
local seed = 1
local function rand(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

-- ── 메인 ────────────────────────────────────────────────────────────
function Raster.render(scene: Scene, cam: Camera, lighting: any, bounds: { number }, options: Options): Image
	local ss = math.max(1, math.floor(options.supersample))
	local OW, OH = options.width, options.height
	local W, H = OW * ss, OH * ss
	local count = W * H
	assignLights(scene)
	local env = makeEnv(scene, lighting, cam, bounds, options.shadowSize)

	local zb = buffer.create(count * 4)
	local tid = buffer.create(count * 4)
	local nb = buffer.create(count * 12)
	for i = 0, count - 1 do
		buffer.writef32(zb, i * 4, 1e30)
	end

	-- 1) 불투명 G-버퍼
	local parts, pidx, v, n = scene.parts, scene.p, scene.v, scene.n
	local transparent: { number } = {}
	local currentTri = 0
	local function writeG(idx: number, _px: number, _py: number, z: number, nx: number, ny: number, nz: number)
		buffer.writef32(zb, idx * 4, z)
		buffer.writei32(tid, idx * 4, currentTri)
		buffer.writef32(nb, idx * 12, nx)
		buffer.writef32(nb, idx * 12 + 4, ny)
		buffer.writef32(nb, idx * 12 + 8, nz)
	end
	for t = 1, #pidx do
		local part = parts[pidx[t]]
		if cam.clipAboveY and part.minY > cam.clipAboveY then
			continue
		end
		if part.alpha < 0.999 then
			table.insert(transparent, t)
			continue
		end
		-- 뒷면 버리기 (꼭짓점 법선 평균이 카메라 반대쪽)
		local b = (t - 1) * 9
		local anx = n[b + 1] + n[b + 4] + n[b + 7]
		local any_ = n[b + 2] + n[b + 5] + n[b + 8]
		local anz = n[b + 3] + n[b + 6] + n[b + 9]
		local facing
		if cam.ortho then
			facing = anx * cam.fx + any_ * cam.fy + anz * cam.fz
		else
			facing = anx * (v[b + 1] - cam.px) + any_ * (v[b + 2] - cam.py) + anz * (v[b + 3] - cam.pz)
		end
		if facing > 1e-6 then
			continue
		end
		local tris = screenTris(scene, cam, W, H, t)
		if tris then
			currentTri = t
			for _, tr in tris do
				rasterTri(W, H, tr[1], tr[2], tr[3], zb, writeG)
			end
		end
	end

	-- 2) 셰이딩
	local voidCount = 0
	local hdr = buffer.create(count * 12)
	local neonMask = buffer.create(count * 4)
	for py = 0, H - 1 do
		for px = 0, W - 1 do
			local idx = py * W + px
			local t = buffer.readi32(tid, idx * 4)
			local r, g, b, neon
			if t == 0 then
				local dx, dy, dz = rayDir(cam, W, H, px, py)
				if dy < 0 then
					voidCount += 1 -- 수평선 아래인데 아무것도 없는 허공
				end
				r, g, b = skyColor(env, dx, dy, dz)
				neon = 0
			else
				local z = buffer.readf32(zb, idx * 4)
				local x, y, zz = unproject(cam, W, H, px, py, z)
				local nx, ny, nz = norm3(
					buffer.readf32(nb, idx * 12),
					buffer.readf32(nb, idx * 12 + 4),
					buffer.readf32(nb, idx * 12 + 8)
				)
				r, g, b, neon = shade(env, scene, parts[pidx[t]], x, y, zz, nx, ny, nz)
			end
			buffer.writef32(hdr, idx * 12, r)
			buffer.writef32(hdr, idx * 12 + 4, g)
			buffer.writef32(hdr, idx * 12 + 8, b)
			buffer.writef32(neonMask, idx * 4, neon)
		end
	end

	-- 3) 투명 삼각형: 먼 것부터
	local depthOf: { [number]: number } = {}
	for _, t in transparent do
		local b = (t - 1) * 9
		local cx = (v[b + 1] + v[b + 4] + v[b + 7]) / 3 - cam.px
		local cy = (v[b + 2] + v[b + 5] + v[b + 8]) / 3 - cam.py
		local cz = (v[b + 3] + v[b + 6] + v[b + 9]) / 3 - cam.pz
		depthOf[t] = cx * cam.fx + cy * cam.fy + cz * cam.fz
	end
	table.sort(transparent, function(a, b)
		return depthOf[a] > depthOf[b]
	end)
	local blendPart: Scene.PartInfo = parts[1]
	local function blend(idx: number, px: number, py: number, z: number, nx: number, ny: number, nz: number)
		local x, y, zz = unproject(cam, W, H, px, py, z)
		local lx, ly, lz = norm3(nx, ny, nz)
		local r, g, b, neon = shade(env, scene, blendPart, x, y, zz, lx, ly, lz)
		local a = blendPart.alpha
		local o = idx * 12
		if blendPart.material == "Glass" then
			a *= 0.6 -- Roblox 유리는 같은 투명도라도 더 맑게 보여요
		elseif blendPart.material == "ForceField" then
			a = math.min(1, a + 0.08)
		end
		buffer.writef32(hdr, o, buffer.readf32(hdr, o) * (1 - a) + r * a)
		buffer.writef32(hdr, o + 4, buffer.readf32(hdr, o + 4) * (1 - a) + g * a)
		buffer.writef32(hdr, o + 8, buffer.readf32(hdr, o + 8) * (1 - a) + b * a)
		if neon > 0 then
			buffer.writef32(neonMask, idx * 4, math.max(buffer.readf32(neonMask, idx * 4), a))
		end
	end
	for _, t in transparent do
		blendPart = parts[pidx[t]]
		local tris = screenTris(scene, cam, W, H, t)
		if tris then
			for _, tr in tris do
				rasterTri(W, H, tr[1], tr[2], tr[3], zb, blend)
			end
		end
	end

	-- 4) 파티클: 부드러운 점 (실제 움직임 대신 한 순간의 모습)
	seed = 7
	local sprites = {}
	for _, e in scene.emitters do
		local amount = math.clamp(math.floor(e.rate * e.lifetime + 0.5), 4, 48)
		for _ = 1, amount do
			local age = rand()
			local life = age * e.lifetime
			-- 방향을 퍼짐 각도 안에서 흔들어요
			local ox, oy, oz = (rand() * 2 - 1), (rand() * 2 - 1), (rand() * 2 - 1)
			local s = math.sin(e.spread) * rand()
			local dx, dy, dz = norm3(e.dx + ox * s, e.dy + oy * s, e.dz + oz * s)
			local dragK = if e.drag > 0 then (1 - math.exp(-e.drag * life)) / e.drag else life
			local x = e.x + (rand() * 2 - 1) * e.ex + dx * e.speed * dragK + 0.5 * e.ax * life * life
			local y = e.y + (rand() * 2 - 1) * e.ey + dy * e.speed * dragK + 0.5 * e.ay * life * life
			local z = e.z + (rand() * 2 - 1) * e.ez + dz * e.speed * dragK + 0.5 * e.az * life * life
			local size = sampleCurve(e.sizes, age, 2)
			local alpha = 1 - math.clamp(sampleCurve(e.alphas, age, 2), 0, 1)
			if alpha > 0.01 and size > 0.02 then
				table.insert(sprites, {
					x = x,
					y = y,
					z = z,
					size = size,
					alpha = alpha,
					r = sampleCurve(e.colors, age, 2),
					g = sampleCurve(e.colors, age, 3),
					b = sampleCurve(e.colors, age, 4),
					emission = e.lightEmission,
				})
			end
		end
	end
	local ambLR = env.ambR * 0.85 + env.outR * 0.8 + env.sunR * 0.5
	local ambLG = env.ambG * 0.85 + env.outG * 0.8 + env.sunG * 0.5
	local ambLB = env.ambB * 0.85 + env.outB * 0.8 + env.sunB * 0.5
	for _, sp in sprites do
		local x, y, z = sp.x - cam.px, sp.y - cam.py, sp.z - cam.pz
		sp.cz = x * cam.fx + y * cam.fy + z * cam.fz
	end
	table.sort(sprites, function(a, b)
		return a.cz > b.cz
	end)
	for _, sp in sprites do
		local x, y, z = sp.x - cam.px, sp.y - cam.py, sp.z - cam.pz
		local cx = x * cam.rx + y * cam.ry + z * cam.rz
		local cy = x * cam.ux + y * cam.uy + z * cam.uz
		local cz = sp.cz
		if cz < NEAR then
			continue
		end
		local sx, sy = project(cam, W, H, cx, cy, cz)
		local radius
		if cam.ortho then
			radius = sp.size * 0.5 / cam.sy * 0.5 * H
		else
			radius = sp.size * 0.5 / (cz * cam.sy) * 0.5 * H
		end
		if radius < 0.5 then
			radius = 0.5
		end
		local minx, maxx = math.max(0, math.floor(sx - radius)), math.min(W - 1, math.ceil(sx + radius))
		local miny, maxy = math.max(0, math.floor(sy - radius)), math.min(H - 1, math.ceil(sy + radius))
		local lit = 1 - sp.emission
		local cr = sp.r * (ambLR * lit + sp.emission * 1.8)
		local cg = sp.g * (ambLG * lit + sp.emission * 1.8)
		local cb = sp.b * (ambLB * lit + sp.emission * 1.8)
		for py = miny, maxy do
			for px = minx, maxx do
				local idx = py * W + px
				if cz < buffer.readf32(zb, idx * 4) then
					local ddx, ddy = (px + 0.5 - sx) / radius, (py + 0.5 - sy) / radius
					local d2 = ddx * ddx + ddy * ddy
					if d2 < 1 then
						local a = sp.alpha * (1 - d2) ^ 1.5 * 0.85
						local o = idx * 12
						if sp.emission > 0.5 then
							buffer.writef32(hdr, o, buffer.readf32(hdr, o) + cr * a)
							buffer.writef32(hdr, o + 4, buffer.readf32(hdr, o + 4) + cg * a)
							buffer.writef32(hdr, o + 8, buffer.readf32(hdr, o + 8) + cb * a)
						else
							buffer.writef32(hdr, o, buffer.readf32(hdr, o) * (1 - a) + cr * a)
							buffer.writef32(hdr, o + 4, buffer.readf32(hdr, o + 4) * (1 - a) + cg * a)
							buffer.writef32(hdr, o + 8, buffer.readf32(hdr, o + 8) * (1 - a) + cb * a)
						end
					end
				end
			end
		end
	end

	-- 5) 다운샘플 (ss × ss 평균)
	local ocount = OW * OH
	local img = buffer.create(ocount * 12)
	local omask = buffer.create(ocount * 4)
	local inv = 1 / (ss * ss)
	for oy = 0, OH - 1 do
		for ox = 0, OW - 1 do
			local r, g, b, m = 0, 0, 0, 0
			for sy = 0, ss - 1 do
				local row = (oy * ss + sy) * W
				for sx = 0, ss - 1 do
					local idx = row + ox * ss + sx
					r += buffer.readf32(hdr, idx * 12)
					g += buffer.readf32(hdr, idx * 12 + 4)
					b += buffer.readf32(hdr, idx * 12 + 8)
					m += buffer.readf32(neonMask, idx * 4)
				end
			end
			local o = (oy * OW + ox)
			buffer.writef32(img, o * 12, r * inv)
			buffer.writef32(img, o * 12 + 4, g * inv)
			buffer.writef32(img, o * 12 + 8, b * inv)
			buffer.writef32(omask, o * 4, m * inv)
		end
	end

	-- 6) 블룸: 밝은 부분 + 네온 → 1/4 해상도 흐림 → 더하기
	local bloom = lighting.Bloom
	local QW, QH = math.max(1, math.floor(OW / 4)), math.max(1, math.floor(OH / 4))
	local q = buffer.create(QW * QH * 12)
	local threshold = bloom.Threshold
	for qy = 0, QH - 1 do
		for qx = 0, QW - 1 do
			local r, g, b = 0, 0, 0
			for sy = 0, 3 do
				for sx = 0, 3 do
					local ox, oy = math.min(OW - 1, qx * 4 + sx), math.min(OH - 1, qy * 4 + sy)
					local o = oy * OW + ox
					local cr, cg, cb =
						buffer.readf32(img, o * 12), buffer.readf32(img, o * 12 + 4), buffer.readf32(img, o * 12 + 8)
					local lum = 0.2126 * cr + 0.7152 * cg + 0.0722 * cb
					local k = 0
					if lum > threshold * 0.6 then
						k = (lum - threshold * 0.6) / math.max(lum, 1e-4) * bloom.Intensity
					end
					k += buffer.readf32(omask, o * 4) * 0.45
					r += cr * k
					g += cg * k
					b += cb * k
				end
			end
			local o = qy * QW + qx
			buffer.writef32(q, o * 12, r / 16)
			buffer.writef32(q, o * 12 + 4, g / 16)
			buffer.writef32(q, o * 12 + 8, b / 16)
		end
	end
	local radius = math.max(1, math.floor(bloom.Size * OH / 1080 / 4 * 1.5 + 0.5))
	local tmp = buffer.create(QW * QH * 12)
	local function boxPass(src: buffer, dst: buffer, horizontal: boolean)
		local len = if horizontal then QW else QH
		local lines = if horizontal then QH else QW
		for line = 0, lines - 1 do
			for i = 0, len - 1 do
				local r, g, b, c = 0, 0, 0, 0
				for k = math.max(0, i - radius), math.min(len - 1, i + radius) do
					local o = if horizontal then line * QW + k else k * QW + line
					r += buffer.readf32(src, o * 12)
					g += buffer.readf32(src, o * 12 + 4)
					b += buffer.readf32(src, o * 12 + 8)
					c += 1
				end
				local o = if horizontal then line * QW + i else i * QW + line
				buffer.writef32(dst, o * 12, r / c)
				buffer.writef32(dst, o * 12 + 4, g / c)
				buffer.writef32(dst, o * 12 + 8, b / c)
			end
		end
	end
	for _ = 1, 2 do
		boxPass(q, tmp, true)
		boxPass(tmp, q, false)
	end

	-- 7) 톤매핑 + 색 보정 → 8비트
	local out = buffer.create(ocount * 3)
	local exposure = 2 ^ lighting.ExposureCompensation
	local cc = lighting.ColorCorrection
	local tintR, tintG, tintB = cc.TintColor.r / 255, cc.TintColor.g / 255, cc.TintColor.b / 255
	local function aces(x: number): number
		x *= 0.8
		return math.clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0, 1)
	end
	local function toSrgb(c: number): number
		if c <= 0.0031308 then
			return c * 12.92
		end
		return 1.055 * c ^ (1 / 2.4) - 0.055
	end
	for oy = 0, OH - 1 do
		for ox = 0, OW - 1 do
			local o = oy * OW + ox
			-- 1/4 블룸을 쌍선형으로 가져와요
			local fx = math.clamp((ox + 0.5) / 4 - 0.5, 0, QW - 1)
			local fy = math.clamp((oy + 0.5) / 4 - 0.5, 0, QH - 1)
			local ix, iy = math.floor(fx), math.floor(fy)
			local tx, ty = fx - ix, fy - iy
			local jx, jy = math.min(QW - 1, ix + 1), math.min(QH - 1, iy + 1)
			local function bq(k: number): number
				local a = buffer.readf32(q, (iy * QW + ix) * 12 + k)
				local b = buffer.readf32(q, (iy * QW + jx) * 12 + k)
				local c = buffer.readf32(q, (jy * QW + ix) * 12 + k)
				local d = buffer.readf32(q, (jy * QW + jx) * 12 + k)
				return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
			end
			local r = (buffer.readf32(img, o * 12) + bq(0)) * exposure
			local g = (buffer.readf32(img, o * 12 + 4) + bq(4)) * exposure
			local b = (buffer.readf32(img, o * 12 + 8) + bq(8)) * exposure
			r, g, b = toSrgb(aces(r)), toSrgb(aces(g)), toSrgb(aces(b))
			-- Roblox ColorCorrectionEffect 근사
			r, g, b = r + cc.Brightness, g + cc.Brightness, b + cc.Brightness
			local k = 1 + cc.Contrast
			r, g, b = (r - 0.5) * k + 0.5, (g - 0.5) * k + 0.5, (b - 0.5) * k + 0.5
			local lum = 0.299 * r + 0.587 * g + 0.114 * b
			local s = 1 + cc.Saturation
			r, g, b = lum + (r - lum) * s, lum + (g - lum) * s, lum + (b - lum) * s
			r, g, b = r * tintR, g * tintG, b * tintB
			buffer.writeu8(out, o * 3, math.clamp(math.floor(r * 255 + 0.5), 0, 255))
			buffer.writeu8(out, o * 3 + 1, math.clamp(math.floor(g * 255 + 0.5), 0, 255))
			buffer.writeu8(out, o * 3 + 2, math.clamp(math.floor(b * 255 + 0.5), 0, 255))
		end
	end
	return { width = OW, height = OH, rgb = out, void = voidCount / count }
end

-- 테스트용 (AC9): 삼각형 래스터화 그대로
Raster.rasterTri = rasterTri

return Raster
