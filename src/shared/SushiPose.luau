--!strict
-- 관절 포즈를 레이아웃(SushiBody.layout의 파츠 목록)에 순수 계산으로 적용 (m5-32, Roblox API 없음).
-- 테스트(AC4 — 모든 테스트 포즈에서 모양 한도)와 렌더 도구(--pose, poses·flop-strip)가 써요. 클라이언트(FishRig·
-- DollAnimator)는 같은 규칙을 CFrame으로 해요. SushiBody는 이 모듈을 부르지 않아요(SushiBody의 require는 견본 하나).
--   SushiPose.posed(layout, motion) -> { PartSpec }

local PartMath = require(script.Parent.PartMath)

local SushiPose = {}

type PartSpec = {
	name: string,
	size: { number },
	color: { number },
	material: string,
	offset: { number },
	shape: string?,
	rotation: { number }?,
	effect: string?,
	effectColor: { number }?,
	transparency: number?,
	joint: boolean?,
	attach: string?,
	pivot: { number }?,
	reach: { number }?,
}

local function isZero(m: Motion): boolean
	local function zero(v: { number }?): boolean
		return v == nil or (v[1] == 0 and v[2] == 0 and v[3] == 0)
	end
	return zero(m.angles) and zero(m.move) and (m.reach or 0) == 0
end

local function copyList(value: { number }?): { number }?
	return if value then table.clone(value) else nil
end

local function copySpec(spec: PartSpec): PartSpec
	local copy = table.clone(spec)
	copy.size = table.clone(spec.size)
	copy.color = table.clone(spec.color)
	copy.offset = table.clone(spec.offset)
	copy.rotation = copyList(spec.rotation)
	copy.effectColor = copyList(spec.effectColor)
	copy.pivot = copyList(spec.pivot)
	copy.reach = copyList(spec.reach)
	return copy
end

-- 관절 하나의 움직임 (m5-32, CharacterAnimLogic.fishMotion이 만들어요). Body 축 기준, pivot(경첩)을 중심으로 돌고 옮겨요.
--   angles  라디안 {x, y, z} (CFrame.Angles 순서), move = 이동 {x, y, z}, reach = 파츠 reach(물방울)에 곱하는 0~1
export type Motion = { angles: { number }?, move: { number }?, reach: number? }

-- 관절 움직임을 레이아웃 좌표에 순수 계산으로 적용한 새 파츠 목록 (테스트 AC4·렌더 도구 --pose). 클라이언트의
-- Motor6D와 같은 규칙: 관절 파츠 = 부모의 움직임 · 자기 움직임 · 쉰 자리, 붙는 파츠 = 붙은 파츠를 그대로 따라가요.
-- 움직임이 없는 파츠는 원래 값 그대로(회전 nil 포함)예요.
function SushiPose.posed(layout: { any }, motion: { [string]: Motion }): { any }
	local byName: { [string]: PartSpec } = {}
	for _, spec in layout do
		byName[spec.name] = spec
	end
	local chain: { [string]: PartMath.Frame? } = {} -- 이름 → Body 축 누적 움직임 (nil이면 없음)
	local done: { [string]: boolean } = {}
	local function chainOf(name: string, depth: number): PartMath.Frame?
		if done[name] then
			return chain[name]
		end
		assert(depth < 32, "SushiPose.posed: attach loop")
		local spec = byName[name]
		local result: PartMath.Frame? = nil
		if spec and spec.name ~= "Body" then
			local parent = spec.attach
			local inherited = if parent and byName[parent] then chainOf(parent, depth + 1) else nil
			local own = if spec.joint then motion[name] else nil
			if own and isZero(own) then
				own = nil -- 움직임 0이면 레이아웃 그대로 (부동소수 회전을 남기지 않아요)
			end
			if own then
				local pivot = spec.pivot or spec.offset
				local move = own.move or { 0, 0, 0 }
				local reach = spec.reach
				local k = own.reach or 0
				local m = {
					move[1] + (if reach then reach[1] * k else 0),
					move[2] + (if reach then reach[2] * k else 0),
					move[3] + (if reach then reach[3] * k else 0),
				}
				local a = own.angles or { 0, 0, 0 }
				-- D = 이동(m) · 경첩으로 · 회전 · 경첩에서
				local d = PartMath.mul({
					p = { m[1] + pivot[1], m[2] + pivot[2], m[3] + pivot[3] },
					r = PartMath.anglesRad(a[1], a[2], a[3]),
				}, { p = { -pivot[1], -pivot[2], -pivot[3] }, r = PartMath.angles(nil) })
				result = if inherited then PartMath.mul(inherited, d) else d
			else
				result = inherited
			end
		end
		done[name] = true
		chain[name] = result
		return result
	end
	local out: { PartSpec } = {}
	for _, spec in layout do
		local copy = copySpec(spec)
		local m = chainOf(spec.name, 0)
		if m then
			local f = PartMath.mul(m, PartMath.frame(spec.offset, spec.rotation))
			copy.offset = f.p
			-- 공은 돌려도 모양이 같아요 (회전을 남기면 외곽 계산이 정육면체 모서리로 커져요)
			copy.rotation = if spec.shape == "Ball" then nil else PartMath.toDegrees(f.r)
		end
		table.insert(out, copy)
	end
	return out
end

return SushiPose
