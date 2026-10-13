--!strict
-- 초밥 몸 레이아웃(SushiBody.layout의 PartSpec 목록) 점검 (m5-25 캐릭터 렌더러). 순수 함수라 테스트할 수 있어요.
--   LayoutCheck.zFight(layout) -> { string }    같은 쪽을 보는 면이 같은 평면에서 겹치는 파츠 쌍 ("A/B +Y")
--                                               — Roblox에서 깜빡이는(z-fighting) 자리. 회전 없는 Block끼리만 봐요.
--   LayoutCheck.floating(layout, gap?) -> { string }   다른 어떤 파츠와도 닿지 않는 파츠 이름 (gap 기본 0.02 studs,
--                                               회전은 감싸는 축 정렬 상자로)
--   LayoutCheck.box(spec) -> (min, max)          파츠 하나의 축 정렬 외곽 (회전 반영)
-- PartSpec은 { name, size {x,y,z}, offset {x,y,z}, rotation {x,y,z}?(도), shape?, transparency? } 모양이면 돼요.

local LayoutCheck = {}

type Spec = {
	name: string,
	size: { number },
	offset: { number },
	rotation: { number }?,
	shape: string?,
	transparency: number?,
}

local EPS = 0.005

-- CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz (SushiBody.bounds와 같은 식)
local function rotationMatrix(rotation: { number }?): { { number } }
	if rotation == nil then
		return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	end
	local a, b, c = math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3])
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	return {
		{ cb * cc, -cb * sc, sb },
		{ ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
		{ sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
	}
end

function LayoutCheck.box(spec: Spec): ({ number }, { number })
	local m = rotationMatrix(spec.rotation)
	local lo, hi = {}, {}
	for axis = 1, 3 do
		local row = m[axis]
		local half = (
			math.abs(row[1]) * spec.size[1]
			+ math.abs(row[2]) * spec.size[2]
			+ math.abs(row[3]) * spec.size[3]
		) / 2
		lo[axis] = spec.offset[axis] - half
		hi[axis] = spec.offset[axis] + half
	end
	return lo, hi
end

local function unrotated(spec: Spec): boolean
	local r = spec.rotation
	return r == nil or (r[1] % 360 == 0 and r[2] % 360 == 0 and r[3] % 360 == 0)
end

local function visible(spec: Spec): boolean
	return (spec.transparency or 0) < 0.99
end

local AXIS_NAMES = { "X", "Y", "Z" }

function LayoutCheck.zFight(layout: { Spec }): { string }
	local found = {}
	for i = 1, #layout do
		local a = layout[i]
		if (a.shape or "Block") ~= "Block" or not unrotated(a) or not visible(a) then
			continue
		end
		local alo, ahi = LayoutCheck.box(a)
		for j = i + 1, #layout do
			local b = layout[j]
			if (b.shape or "Block") ~= "Block" or not unrotated(b) or not visible(b) then
				continue
			end
			local blo, bhi = LayoutCheck.box(b)
			for axis = 1, 3 do
				local u, w = axis % 3 + 1, (axis + 1) % 3 + 1
				local overlapU = math.min(ahi[u], bhi[u]) - math.max(alo[u], blo[u])
				local overlapW = math.min(ahi[w], bhi[w]) - math.max(alo[w], blo[w])
				if overlapU <= EPS or overlapW <= EPS then
					continue
				end
				if math.abs(ahi[axis] - bhi[axis]) < EPS then
					table.insert(found, `{a.name}/{b.name} +{AXIS_NAMES[axis]}`)
				end
				if math.abs(alo[axis] - blo[axis]) < EPS then
					table.insert(found, `{a.name}/{b.name} -{AXIS_NAMES[axis]}`)
				end
			end
		end
	end
	return found
end

function LayoutCheck.floating(layout: { Spec }, gap: number?): { string }
	local g = gap or 0.02
	local boxes = {}
	for index, spec in layout do
		local lo, hi = LayoutCheck.box(spec)
		boxes[index] = { lo, hi }
	end
	local found = {}
	for i, a in boxes do
		local touching = false
		for j, b in boxes do
			if i ~= j then
				local ok = true
				for axis = 1, 3 do
					if a[1][axis] > b[2][axis] + g or b[1][axis] > a[2][axis] + g then
						ok = false
						break
					end
				end
				if ok then
					touching = true
					break
				end
			end
		end
		if not touching then
			table.insert(found, layout[i].name)
		end
	end
	return found
end

return LayoutCheck
