--!strict
-- 장식 모양 헬퍼 (m5-23). Roblox API 없는 순수 함수 — 전부 DecorSpec 목록을 돌려줘요.
-- 상자 하나 대신 둥근 모서리·깎은 모서리·테두리를 몇 파츠로 만들어 "로블록스 기본 블록" 느낌을 줄여요.
-- 각 헬퍼의 offset·rotation은 묶음 전체의 자리·회전이에요 (rotation은 도, CFrame.Angles 순서 X·Y·Z).
--   roundedBox(name, size, color, material, offset, opts?)   가운데 상자 + 모서리 원기둥 + 꼭짓점 공
--        opts.radius (기본 짧은 변의 0.2), opts.style "full"(23파츠) | "vertical"(세로 모서리만, 6파츠), opts.rotation
--   bevelBox(name, size, color, material, offset, bevel, rotation?)   윗 모서리를 쐐기로 깎은 상자 (6파츠)
--   rimDisc(name, diameter, height, color, material, offset, opts?)  접시: 원판 + 테두리 고리
--        opts.rimColor, opts.rimWidth(0.6), opts.rimHeight(height*0.8), opts.segments(16), opts.rotation
--   ring(name, radius, thickness, height, segments, color, material, offset, rotation?)  가로로 누운 고리
--   capsule(name, length, diameter, color, material, offset, rotation?)  원기둥 + 양 끝 공 (축 = 로컬 X)
--   lipTrim(name, footprint, thickness, height, color, material, offset, rotation?)  바닥 가장자리 띠 (4파츠)
--   scatter(seed, count, area, maker)   결정적 무리 배치: 무리 중심 2~4개 주위로 count개 → maker(i, pos, rng)가 만든 목록을 합쳐요
--   transform(specs, offset, rotation?)  로컬 목록을 회전·이동한 새 목록

local MapKitLogic = require(script.Parent.MapKitLogic)

type DecorSpec = MapKitLogic.DecorSpec
type Vec3 = MapKitLogic.Vec3
type RGB = MapKitLogic.RGB

export type Rng = { next: (self: Rng) -> number, range: (self: Rng, lo: number, hi: number) -> number }
export type RoundedOptions = { radius: number?, style: string?, rotation: Vec3? }
export type DiscOptions = { rimColor: RGB?, rimWidth: number?, rimHeight: number?, segments: number?, rotation: Vec3? }
export type Area = { center: Vec3, size: Vec3 } -- size.y는 무시(평면 위 배치)하고 center.y 높이에 놓아요

local MapKitShapes = {}

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function spec(
	name: string,
	shape: MapKitLogic.Shape,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): DecorSpec
	return {
		name = name,
		shape = shape,
		size = size,
		color = color,
		material = material,
		offset = offset,
		rotation = rotation,
	}
end

-- ── 회전 (CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz) ─────────────────────
type Mat = { number } -- 행 우선 3×3

local function matFromEuler(r: Vec3?): Mat
	if r == nil then
		return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	end
	local a, b, c = math.rad(r.x), math.rad(r.y), math.rad(r.z)
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	return {
		cb * cc,
		-cb * sc,
		sb,
		ca * sc + sa * sb * cc,
		ca * cc - sa * sb * sc,
		-sa * cb,
		sa * sc - ca * sb * cc,
		sa * cc + ca * sb * sc,
		ca * cb,
	}
end

local function matMul(m: Mat, n: Mat): Mat
	local out = {}
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = m[i * 3 + 1] * n[j + 1] + m[i * 3 + 2] * n[3 + j + 1] + m[i * 3 + 3] * n[6 + j + 1]
		end
	end
	return out
end

local function eulerFromMat(m: Mat): Vec3
	local sb = math.clamp(m[3], -1, 1)
	local b = math.asin(sb)
	local a, c
	if math.abs(sb) < 0.99999 then
		a = math.atan2(-m[6], m[9])
		c = math.atan2(-m[2], m[1])
	else
		a = math.atan2(m[8], m[5])
		c = 0
	end
	return v(math.deg(a), math.deg(b), math.deg(c))
end

local function apply(m: Mat, p: Vec3): Vec3
	return v(
		m[1] * p.x + m[2] * p.y + m[3] * p.z,
		m[4] * p.x + m[5] * p.y + m[6] * p.z,
		m[7] * p.x + m[8] * p.y + m[9] * p.z
	)
end

local function isIdentity(r: Vec3?): boolean
	return r == nil or (r.x == 0 and r.y == 0 and r.z == 0)
end

function MapKitShapes.transform(specs: { DecorSpec }, offset: Vec3, rotation: Vec3?): { DecorSpec }
	local out = {}
	local m = matFromEuler(rotation)
	for _, s in specs do
		local copy = table.clone(s)
		local p = if isIdentity(rotation) then s.offset else apply(m, s.offset)
		copy.offset = v(p.x + offset.x, p.y + offset.y, p.z + offset.z)
		if not isIdentity(rotation) then
			local combined = matMul(m, matFromEuler(s.rotation))
			local e = eulerFromMat(combined)
			-- 아주 작은 값은 0으로 (테스트·비교가 깔끔하게)
			local function clean(x: number): number
				return if math.abs(x) < 1e-9 then 0 else x
			end
			copy.rotation = v(clean(e.x), clean(e.y), clean(e.z))
		end
		table.insert(out, copy)
	end
	return out
end

local UPRIGHT = v(0, 0, 90) -- 원기둥 축(로컬 X)을 Y로
local ALONG_Z = v(0, 90, 0) -- 원기둥 축을 Z로

function MapKitShapes.roundedBox(
	name: string,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	opts: RoundedOptions?
): { DecorSpec }
	local o: RoundedOptions = opts or {} :: RoundedOptions
	local shortest = math.min(size.x, size.y, size.z)
	local r = math.min(o.radius or shortest * 0.2, shortest / 2 - 0.01)
	local d = 2 * r
	local hx, hy, hz = size.x / 2 - r, size.y / 2 - r, size.z / 2 - r
	local list: { DecorSpec } = {}
	if o.style == "vertical" then
		-- 세로 모서리만 둥글게 (기둥·카운터)
		table.insert(list, spec(name, "Block", v(size.x - d, size.y, size.z), color, material, v(0, 0, 0)))
		table.insert(list, spec(name, "Block", v(size.x, size.y, size.z - d), color, material, v(0, 0, 0)))
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(
					list,
					spec(name, "Cylinder", v(size.y, d, d), color, material, v(sx * hx, 0, sz * hz), UPRIGHT)
				)
			end
		end
	else
		table.insert(list, spec(name, "Block", v(size.x, size.y - d, size.z - d), color, material, v(0, 0, 0)))
		table.insert(list, spec(name, "Block", v(size.x - d, size.y, size.z - d), color, material, v(0, 0, 0)))
		table.insert(list, spec(name, "Block", v(size.x - d, size.y - d, size.z), color, material, v(0, 0, 0)))
		for _, a in { -1, 1 } do
			for _, b in { -1, 1 } do
				table.insert(list, spec(name, "Cylinder", v(size.x - d, d, d), color, material, v(0, a * hy, b * hz)))
				table.insert(
					list,
					spec(name, "Cylinder", v(size.y - d, d, d), color, material, v(a * hx, 0, b * hz), UPRIGHT)
				)
				table.insert(
					list,
					spec(name, "Cylinder", v(size.z - d, d, d), color, material, v(a * hx, b * hy, 0), ALONG_Z)
				)
			end
		end
		for _, a in { -1, 1 } do
			for _, b in { -1, 1 } do
				for _, c in { -1, 1 } do
					table.insert(list, spec(name, "Ball", v(d, d, d), color, material, v(a * hx, b * hy, c * hz)))
				end
			end
		end
	end
	return MapKitShapes.transform(list, offset, o.rotation)
end

-- { x 부호, z 부호, Y 회전(도) }: 꼭대기 (+X, -Z)를 Ry로 돌려 안쪽 (-x부호, -z부호)에 오게
local CORNER_YAW = { { -1, -1, -90 }, { 1, -1, 180 }, { 1, 1, 90 }, { -1, 1, 0 } }

function MapKitShapes.bevelBox(
	name: string,
	size: Vec3,
	color: RGB,
	material: string,
	offset: Vec3,
	bevel: number,
	rotation: Vec3?
): { DecorSpec }
	local b = math.clamp(bevel, 0.05, math.min(size.x, size.z) / 2 - 0.01)
	b = math.min(b, size.y - 0.01)
	local list: { DecorSpec } = {}
	local topY = size.y / 2 - b / 2
	-- 아래 몸통 + 윗면 가운데
	table.insert(list, spec(name, "Block", v(size.x, size.y - b, size.z), color, material, v(0, -b / 2, 0)))
	table.insert(list, spec(name, "Block", v(size.x - 2 * b, b, size.z - 2 * b), color, material, v(0, topY, 0)))
	-- 쐐기: 경사면이 로컬 -Z(바깥)·위를 봐요. 길이는 모서리 b씩 빼고(맞물림), 네 귀퉁이는 CornerWedge
	local ex, ez = size.x / 2 - b / 2, size.z / 2 - b / 2
	table.insert(list, spec(name, "Wedge", v(size.x - 2 * b, b, b), color, material, v(0, topY, -ez)))
	table.insert(list, spec(name, "Wedge", v(size.x - 2 * b, b, b), color, material, v(0, topY, ez), v(0, 180, 0)))
	table.insert(list, spec(name, "Wedge", v(size.z - 2 * b, b, b), color, material, v(-ex, topY, 0), v(0, 90, 0)))
	table.insert(list, spec(name, "Wedge", v(size.z - 2 * b, b, b), color, material, v(ex, topY, 0), v(0, -90, 0)))
	-- CornerWedge 꼭대기(로컬 +X·위·-Z 모서리)가 상자 안쪽 귀퉁이를 향하게 돌려요
	for _, corner in CORNER_YAW do
		table.insert(
			list,
			spec(
				name,
				"CornerWedge",
				v(b, b, b),
				color,
				material,
				v(corner[1] * ex, topY, corner[2] * ez),
				v(0, corner[3], 0)
			)
		)
	end
	return MapKitShapes.transform(list, offset, rotation)
end

function MapKitShapes.ring(
	name: string,
	radius: number,
	thickness: number,
	height: number,
	segments: number,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): { DecorSpec }
	local n = math.max(3, math.floor(segments))
	local chord = 2 * radius * math.sin(math.pi / n) * 1.04 + thickness * 0.3
	local list: { DecorSpec } = {}
	for i = 0, n - 1 do
		local theta = 2 * math.pi * i / n
		local angle = -math.deg(theta) - 90
		table.insert(
			list,
			spec(
				name,
				"Block",
				v(chord, height, thickness),
				color,
				material,
				v(radius * math.cos(theta), 0, radius * math.sin(theta)),
				v(0, angle, 0)
			)
		)
	end
	return MapKitShapes.transform(list, offset, rotation)
end

function MapKitShapes.rimDisc(
	name: string,
	diameter: number,
	height: number,
	color: RGB,
	material: string,
	offset: Vec3,
	opts: {
		rimColor: RGB?,
		rimWidth: number?,
		rimHeight: number?,
		segments: number?,
		rotation: Vec3?,
	}?
): { DecorSpec }
	local o: DiscOptions = opts or {} :: DiscOptions
	local rimWidth = o.rimWidth or 0.6
	local rimHeight = o.rimHeight or height * 0.8
	local list: { DecorSpec } = {
		spec(name, "Cylinder", v(height, diameter, diameter), color, material, v(0, 0, 0), UPRIGHT),
	}
	local ringParts = MapKitShapes.ring(
		name,
		diameter / 2 - rimWidth / 2,
		rimWidth,
		rimHeight,
		o.segments or 16,
		o.rimColor or color,
		material,
		v(0, height / 2 + rimHeight / 2, 0)
	)
	for _, p in ringParts do
		table.insert(list, p)
	end
	return MapKitShapes.transform(list, offset, o.rotation)
end

function MapKitShapes.capsule(
	name: string,
	length: number,
	diameter: number,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): { DecorSpec }
	local body = math.max(length - diameter, 0.05)
	local list: { DecorSpec } = {
		spec(name, "Cylinder", v(body, diameter, diameter), color, material, v(0, 0, 0)),
		spec(name, "Ball", v(diameter, diameter, diameter), color, material, v(-body / 2, 0, 0)),
		spec(name, "Ball", v(diameter, diameter, diameter), color, material, v(body / 2, 0, 0)),
	}
	return MapKitShapes.transform(list, offset, rotation)
end

-- footprint의 x·z 둘레 바닥에 띠를 둘러요 (footprint.y는 무시). 띠는 footprint 바깥으로 thickness만큼 나와요.
function MapKitShapes.lipTrim(
	name: string,
	footprint: Vec3,
	thickness: number,
	height: number,
	color: RGB,
	material: string,
	offset: Vec3,
	rotation: Vec3?
): { DecorSpec }
	local hx, hz = footprint.x / 2 + thickness / 2, footprint.z / 2 + thickness / 2
	local list: { DecorSpec } = {
		spec(name, "Block", v(footprint.x + 2 * thickness, height, thickness), color, material, v(0, 0, -hz)),
		spec(name, "Block", v(footprint.x + 2 * thickness, height, thickness), color, material, v(0, 0, hz)),
		spec(name, "Block", v(thickness, height, footprint.z), color, material, v(-hx, 0, 0)),
		spec(name, "Block", v(thickness, height, footprint.z), color, material, v(hx, 0, 0)),
	}
	return MapKitShapes.transform(list, offset, rotation)
end

-- 결정적 난수 (seed가 같으면 같은 수열)
function MapKitShapes.rng(seed: number): Rng
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	local self = {} :: any
	function self.next(_self: any): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function self.range(this: any, lo: number, hi: number): number
		return lo + (hi - lo) * this:next()
	end
	return self
end

-- 무리 배치: 고르게 흩뿌리지 않고 무리 중심 2~4개 주위로 모아요 (가이드 "덩어리와 빈 곳")
function MapKitShapes.scatter(
	seed: number,
	count: number,
	area: Area,
	maker: (i: number, pos: Vec3, rng: Rng) -> { DecorSpec }
): { DecorSpec }
	local rng = MapKitShapes.rng(seed)
	local hx, hz = area.size.x / 2, area.size.z / 2
	local clusters: { { x: number, z: number } } = {}
	local clusterCount = 2 + math.floor(rng:next() * 3)
	for _ = 1, clusterCount do
		table.insert(clusters, { x = rng:range(-hx * 0.7, hx * 0.7), z = rng:range(-hz * 0.7, hz * 0.7) })
	end
	local spread = math.max(hx, hz) / 3
	local out: { DecorSpec } = {}
	for i = 1, count do
		local c = clusters[1 + math.floor(rng:next() * #clusters) % #clusters]
		-- 가운데로 몰린 분포 (두 난수 평균)
		local ox = ((rng:next() + rng:next()) - 1) * spread
		local oz = ((rng:next() + rng:next()) - 1) * spread
		local pos = v(
			area.center.x + math.clamp(c.x + ox, -hx, hx),
			area.center.y,
			area.center.z + math.clamp(c.z + oz, -hz, hz)
		)
		for _, s in maker(i, pos, rng) do
			table.insert(out, s)
		end
	end
	return out
end

return MapKitShapes
