--!strict
-- 파츠 자리 계산 (m5-32, 순수 — Roblox API 없음). CFrame 대신 숫자 표로 회전·이동을 합쳐요.
-- SushiConceptSample(고등어 김 띠를 비스듬히 돌리기)·SushiBody.posed(관절 포즈를 레이아웃에 적용 — 테스트·렌더 도구)가 써요.
--   Frame = { p = {x, y, z}, r = 3×3 회전 행렬(행 우선) }  (CFrame과 같은 뜻: 점 = p + r · local)
--   PartMath.angles(deg)          CFrame.Angles(rx, ry, rz)와 같은 회전 (도 단위 {x, y, z}, Rx·Ry·Rz)
--   PartMath.anglesRad(x, y, z)   같은 회전, 라디안
--   PartMath.toDegrees(r)         회전 행렬 → CFrame.Angles 순서의 도 {x, y, z}
--   PartMath.frame(offset, rotationDeg?)  파츠 자리 → Frame
--   PartMath.mul(a, b)            a * b (CFrame 곱과 같아요)
--   PartMath.inverse(a)
--   PartMath.point(a, v)          a * v (점)
--   PartMath.rotateAbout(offset, rotationDeg?, pivot, rotDeg)  파츠를 pivot을 중심으로 rotDeg만큼 더 돌린 자리 (offset, rotation)

local PartMath = {}

export type Matrix = { { number } }
export type Frame = { p: { number }, r: Matrix }

function PartMath.anglesRad(a: number, b: number, c: number): Matrix
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	return {
		{ cb * cc, -cb * sc, sb },
		{ ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
		{ sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
	}
end

function PartMath.angles(deg: { number }?): Matrix
	if deg == nil then
		return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	end
	return PartMath.anglesRad(math.rad(deg[1]), math.rad(deg[2]), math.rad(deg[3]))
end

-- r = Rx(a)·Ry(b)·Rz(c) → {a, b, c} 도 (r[1][3] = sin b)
function PartMath.toDegrees(r: Matrix): { number }
	local sb = math.clamp(r[1][3], -1, 1)
	local b = math.asin(sb)
	local a, c
	if math.abs(sb) < 0.999999 then
		a = math.atan2(-r[2][3], r[3][3])
		c = math.atan2(-r[1][2], r[1][1])
	else
		-- 짐벌 잠금: c = 0으로 두고 a에 몰아요
		a = math.atan2(r[3][2], r[2][2])
		c = 0
	end
	return { math.deg(a), math.deg(b), math.deg(c) }
end

local function mulMatrix(a: Matrix, b: Matrix): Matrix
	local out = {}
	for i = 1, 3 do
		out[i] = {}
		for j = 1, 3 do
			out[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return out
end

local function apply(r: Matrix, v: { number }): { number }
	return {
		r[1][1] * v[1] + r[1][2] * v[2] + r[1][3] * v[3],
		r[2][1] * v[1] + r[2][2] * v[2] + r[2][3] * v[3],
		r[3][1] * v[1] + r[3][2] * v[2] + r[3][3] * v[3],
	}
end

local function transpose(r: Matrix): Matrix
	return {
		{ r[1][1], r[2][1], r[3][1] },
		{ r[1][2], r[2][2], r[3][2] },
		{ r[1][3], r[2][3], r[3][3] },
	}
end

function PartMath.frame(offset: { number }, rotationDeg: { number }?): Frame
	return { p = { offset[1], offset[2], offset[3] }, r = PartMath.angles(rotationDeg) }
end

function PartMath.mul(a: Frame, b: Frame): Frame
	local v = apply(a.r, b.p)
	return { p = { a.p[1] + v[1], a.p[2] + v[2], a.p[3] + v[3] }, r = mulMatrix(a.r, b.r) }
end

function PartMath.inverse(a: Frame): Frame
	local rt = transpose(a.r)
	local v = apply(rt, a.p)
	return { p = { -v[1], -v[2], -v[3] }, r = rt }
end

function PartMath.point(a: Frame, v: { number }): { number }
	local w = apply(a.r, v)
	return { a.p[1] + w[1], a.p[2] + w[2], a.p[3] + w[3] }
end

-- 축을 도는 회전 (pivot 기준, Body 축). 돌려주는 offset·rotation은 PartSpec에 그대로 넣어요
function PartMath.rotateAbout(
	offset: { number },
	rotationDeg: { number }?,
	pivot: { number },
	rotDeg: { number }
): ({ number }, { number })
	local spin = PartMath.angles(rotDeg)
	local rel = { offset[1] - pivot[1], offset[2] - pivot[2], offset[3] - pivot[3] }
	local moved = apply(spin, rel)
	local r = mulMatrix(spin, PartMath.angles(rotationDeg))
	return { pivot[1] + moved[1], pivot[2] + moved[2], pivot[3] + moved[3] }, PartMath.toDegrees(r)
end

return PartMath
