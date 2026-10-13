--!strict
-- m5-25 캐릭터 퀄리티 2단계 (docs/specs/m5-25-character-quality.md): 새 기준 몸·얼굴·31종 재배치 규칙·작은 움직임 로직

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Skins = RobloxRequire.require(Shared.Skins)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

local function extents(layout: { any }): { number }
	local b = SushiBody.bounds(layout)
	return { b.max[1] - b.min[1], b.max[2] - b.min[2], b.max[3] - b.min[3] }
end

local function isBase(name: string): boolean
	return table.find(SushiBody.BASE_NAMES, name) ~= nil
end

local function colorKey(c: { number }): string
	return `{c[1]},{c[2]},{c[3]}`
end

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- 밥 앞면 z (알약: 가운데 |x| ≤ 0.6은 평평, 바깥은 반지름 1.2 원기둥)
local function riceFrontZ(x: number): number
	local body = byName(SushiBody.layout("tamago"))
	local flat = body.Body.size[1] / 2
	local r = body.Body.size[3] / 2
	local dx = math.abs(x) - flat
	if dx <= 0 then
		return -r
	end
	if dx >= r then
		return 0
	end
	return -math.sqrt(r * r - dx * dx)
end

-- 파츠 상자가 밥 속에 숨어 있는지 (앞면 기준, zShift만큼 옮긴 뒤). 가장 바깥 x에서 밥 앞면이 가장 얕아요.
local function hiddenInRice(spec: any, zShift: number): boolean
	local b = SushiBody.bounds({ spec })
	local worstX = math.max(math.abs(b.min[1]), math.abs(b.max[1]))
	return b.min[3] + zShift > riceFrontZ(worstX)
end

local TOP_SURFACE = (function()
	local parts = byName(SushiBody.layout("tamago"))
	return parts.Topping.offset[2] + parts.Topping.size[2] / 2
end)()

-- 기본 꼭대기보다 0.15 넘게 솟은 장식 = 실루엣 파츠
local function silhouette(layout: { any }): { [string]: boolean }
	local set = {}
	for _, spec in layout do
		if not isBase(spec.name) then
			local b = SushiBody.bounds({ spec })
			if b.max[2] > TOP_SURFACE + 0.15 then
				set[spec.name] = true
			end
		end
	end
	return set
end

-- 뒤에서 보이는 색 집합: 뒷면(z ≥ 1.2)에 닿는 기준 밖 파츠 + 실루엣 파츠
local function backColors(layout: { any }): { [string]: boolean }
	local set = {}
	local sil = silhouette(layout)
	for _, spec in layout do
		if not isBase(spec.name) then
			local b = SushiBody.bounds({ spec })
			if b.max[3] >= 1.2 or sil[spec.name] then
				set[colorKey(spec.color)] = true
			end
		end
	end
	return set
end

local function setKey(set: { [string]: boolean }): string
	local list = {}
	for k in set do
		table.insert(list, k)
	end
	table.sort(list)
	return table.concat(list, "|")
end

local function volume(spec: any): number
	return spec.size[1] * spec.size[2] * spec.size[3]
end

-- 대표색: 기준 밖에서 부피가 가장 큰 파츠 색 (토핑·김 벽·소스 자락 등)
local function mainColor(layout: { any }): { number }
	local best, bestVolume = nil, -1
	for _, spec in layout do
		if not isBase(spec.name) and (spec.transparency or 0) < 0.5 and volume(spec) > bestVolume then
			best, bestVolume = spec, volume(spec)
		end
	end
	return (best :: any).color
end

local function beltColor(layout: { any }): string
	local parts = byName(layout)
	local list = {}
	for _, name in { "Nori", "Strap" } do
		if parts[name] then
			table.insert(list, `{name}:{colorKey(parts[name].color)}`)
		end
	end
	return table.concat(list, ",")
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 실루엣
	t.test(
		"AC1: 밥 몸은 알약(Block 1 + 세운 Cylinder 2), 토핑은 밥보다 0.25 넘게 넓지 않아요 (모자 챙 없음)",
		function()
			for _, skin in Skins.LIST do
				if skin.experimental then
					continue -- 실험 스킨(m5-27 concept-salmon)은 자기 몸 모양이라 기준 몸 검사에서 빼요 (SushiBody.EXPERIMENTAL)
				end
				local parts = byName(SushiBody.layout(skin.id))
				t.eq(parts.Body.shape, nil, `{skin.id} Body block`)
				for _, name in { "BodyL", "BodyR" } do
					t.eq(parts[name].shape, "Cylinder", `{skin.id} {name}`)
					t.eq(parts[name].rotation, { 0, 0, 90 }, `{skin.id} {name} upright`)
				end
				local rice = extents({ parts.Body, parts.BodyL, parts.BodyR })
				if parts.Topping and parts.ToppingL then
					local topping = extents({ parts.Topping, parts.ToppingL, parts.ToppingR })
					t.ok(topping[1] - rice[1] <= 0.25 + 1e-6, `{skin.id} topping {topping[1]} vs rice {rice[1]}`)
				end
			end
			local e = extents(SushiBody.layout("tamago"))
			t.ok(e[1] / e[2] >= 0.8, `tamago width/height {e[1] / e[2]}`)
		end
	)

	---------------------------------------------------------------- AC2 얼굴
	t.test(
		"AC2: 눈은 테두리·흰자·눈동자·하이라이트 4겹, 안쪽 파츠는 테두리에 붙어 같이 움직여요",
		function()
			local parts = byName(SushiBody.layout("tamago"))
			for _, side in { "Left", "Right" } do
				local rim, white, pupil, shine =
					parts[`Eye{side}`], parts[`EyeWhite{side}`], parts[`Pupil{side}`], parts[`Shine{side}`]
				t.ok(rim and white and pupil and shine, side)
				t.ok(rim.size[2] >= 0.9, `{side} rim diameter {rim.size[2]}`)
				t.ok(white.size[2] < rim.size[2] and pupil.size[2] < white.size[2], `{side} layers shrink`)
				t.eq(shine.shape, "Ball")
				t.eq(rim.joint, true)
				for _, inner in { white, pupil, shine } do
					t.eq(inner.attach, `Eye{side}`, `{inner.name} attach`)
					t.ok(inner.offset[3] < rim.offset[3], `{inner.name} in front of rim`)
				end
			end
			t.ok(parts.EyeLeft.offset[1] < 0 and parts.EyeRight.offset[1] > 0, "left/right")
		end
	)

	t.test("AC2: 입은 0.2 이상 보이고, 얼굴 장식이 앞면의 20% 이상", function()
		local parts = byName(SushiBody.layout("tamago"))
		local mouth = SushiBody.bounds({ parts.Mouth })
		local cover = SushiBody.bounds({ parts.MouthCover })
		local visible = cover.min[2] - mouth.min[2]
		t.ok(visible >= 0.2, `mouth visible {visible}`)
		local face = 0
		for _, name in { "EyeLeft", "EyeRight", "CheekLeft", "CheekRight" } do
			face += parts[name].size[2] * parts[name].size[3]
		end
		face += parts.Mouth.size[2] * visible
		local rice = extents({ parts.Body, parts.BodyL, parts.BodyR })
		local ratio = face / (rice[1] * rice[2])
		t.ok(ratio >= 0.2, `face ratio {ratio}`)
	end)

	---------------------------------------------------------------- AC3 등·뒷면
	t.test(
		"AC3: 모든 스킨에 밥 색이 아닌 등 파츠가 있고, 뒤에서 보이는 색 집합이 31종 모두 달라요",
		function()
			local rice = byName(SushiBody.layout("tamago")).Body.color
			local seen: { [string]: string } = {}
			for _, skin in Skins.LIST do
				if skin.experimental then
					continue -- 실험 스킨(m5-27 concept-salmon)은 자기 몸 모양이라 기준 몸 검사에서 빼요 (SushiBody.EXPERIMENTAL)
				end
				local layout = SushiBody.layout(skin.id)
				local parts = byName(layout)
				local backPart = parts.ToppingBack or parts.Wall
				t.ok(backPart ~= nil, `{skin.id} back part`)
				if backPart then
					t.ok(colorKey(backPart.color) ~= colorKey(rice), `{skin.id} back is not rice colored`)
				end
				local key = setKey(backColors(layout))
				t.ok(seen[key] == nil, `{skin.id} back looks like {seen[key]}`)
				seen[key] = skin.id
			end
		end
	)

	---------------------------------------------------------------- AC5 관절
	t.test(
		"AC5: 움직이는 파츠 6개(눈 테두리 2·감은 눈 2·발 2)만 joint, 감은 눈은 평소 숨고 깜빡이면 보여요",
		function()
			for _, skin in Skins.LIST do
				if skin.experimental then
					continue -- 실험 스킨(m5-27 concept-salmon)은 자기 몸 모양이라 기준 몸 검사에서 빼요 (SushiBody.EXPERIMENTAL) (관절은 m5-27 테스트가 따로 봐요)
				end
				local joints = {}
				for _, spec in SushiBody.layout(skin.id) do
					if spec.joint then
						table.insert(joints, spec.name)
					end
				end
				table.sort(joints)
				t.eq(joints, { "EyeLeft", "EyeRight", "FootLeft", "FootRight", "LidLeft", "LidRight" }, skin.id)
			end
			local parts = byName(SushiBody.layout("tamago"))
			for _, side in { "Left", "Right" } do
				local lid = parts[`Lid{side}`]
				t.ok(hiddenInRice(lid, 0), `Lid{side} hidden at rest`)
				t.ok(not hiddenInRice(lid, -Anim.LID_SHOW), `Lid{side} shows when blinking`)
				for _, name in { `Eye{side}`, `EyeWhite{side}`, `Pupil{side}`, `Shine{side}` } do
					t.ok(not hiddenInRice(parts[name], 0), `{name} visible at rest`)
					t.ok(hiddenInRice(parts[name], Anim.EYE_HIDE), `{name} hidden when blinking`)
				end
			end
		end
	)

	---------------------------------------------------------------- AC6 색 겹침
	t.test(
		"AC6: 토핑 대표색이 비슷한(RGB 거리 < 60) 스킨 쌍은 구별 신호가 2개 이상 달라요",
		function()
			local rows = {}
			for _, skin in Skins.LIST do
				if skin.experimental then
					continue -- 실험 스킨(m5-27 concept-salmon)은 자기 몸 모양이라 기준 몸 검사에서 빼요 (SushiBody.EXPERIMENTAL)
				end
				local layout = SushiBody.layout(skin.id)
				local parts = byName(layout)
				table.insert(rows, {
					id = skin.id,
					main = mainColor(layout),
					silhouette = setKey(silhouette(layout)),
					foot = colorKey(parts.FootLeft.color) .. parts.FootLeft.material,
					back = setKey(backColors(layout)),
					belt = beltColor(layout),
				})
			end
			local pairsChecked = 0
			for i = 1, #rows do
				for j = i + 1, #rows do
					local a, b = rows[i], rows[j]
					if dist(a.main, b.main) < 60 then
						pairsChecked += 1
						local signals = 0
						for _, key in { "silhouette", "foot", "back", "belt" } do
							if (a :: any)[key] ~= (b :: any)[key] then
								signals += 1
							end
						end
						t.ok(signals >= 2, `{a.id} vs {b.id}: {signals} signal(s)`)
					end
				end
			end
			t.ok(pairsChecked > 0, "some similar-colored pairs exist")
		end
	)

	---------------------------------------------------------------- AC7 디테일·결함
	t.test(
		"AC7: 31종 z-fighting 0·떠 있는 파츠 0, 장식 두께 ≥ 0.06, 귀·가시·뿔·갈기 쐐기 두께 ≥ 0.2",
		function()
			for _, skin in Skins.LIST do
				local layout = SushiBody.layout(skin.id)
				t.eq(LayoutCheck.zFight(layout), {}, `{skin.id} z-fighting`)
				t.eq(LayoutCheck.floating(layout), {}, `{skin.id} floating`)
				-- 실험 스킨(m5-27)은 z-fighting·떠 있는 파츠만 봐요 (입 덮개·혀 0.03은 콘셉트 견본 그대로)
				for _, spec in (if skin.experimental then {} else layout) do
					if not isBase(spec.name) then
						local thin = math.min(spec.size[1], spec.size[2], spec.size[3])
						t.ok(thin >= 0.06 - 1e-9, `{skin.id} {spec.name} thickness {thin}`)
						local name = spec.name
						local structural = (string.find(name, "^Ear") and not string.find(name, "Inner"))
							or string.find(name, "Spike")
							or string.find(name, "^Horn")
							or string.find(name, "^Mane")
						if spec.shape == "Wedge" and structural then
							t.ok(thin >= 0.2 - 1e-9, `{skin.id} {name} wedge thickness {thin}`)
						end
					end
				end
			end
		end
	)

	t.test("AC7: Glow는 범위 4·밝기 1.2 이하 (바닥을 덜 물들여요)", function()
		t.ok(SushiBody.GLOW_RANGE <= 4, "range")
		t.ok(SushiBody.GLOW_BRIGHTNESS <= 1.2, "brightness")
	end)

	---------------------------------------------------------------- AC9 성능
	t.test(
		"AC9: 파츠 수 — 스킨 하나 ≤ 40, 31종 평균 ≤ 36 (실험 스킨은 SushiBody.EXPERIMENTAL 상한)",
		function()
			t.eq(SushiBody.PART_BUDGET, 40)
			local total, counted = 0, 0
			for _, skin in Skins.LIST do
				local count = #SushiBody.layout(skin.id)
				local exception = SushiBody.EXPERIMENTAL[skin.id]
				if skin.experimental and exception then
					t.ok(count <= exception.partBudget, `{skin.id} parts {count} (experimental)`)
					continue
				end
				t.ok(count <= SushiBody.PART_BUDGET, `{skin.id} parts {count}`)
				total += count
				counted += 1
			end
			local average = total / counted
			t.ok(average <= 36, `average {average}`)
		end
	)

	---------------------------------------------------------------- AC4 움직임 로직
	t.test("AC4: 깜빡임 간격 2.2~5.0초, 0.13초 동안만 감아요", function()
		t.eq(Anim.nextBlinkDelay(0), 2.2)
		t.eq(Anim.nextBlinkDelay(1), 5.0)
		t.eq(Anim.nextBlinkDelay(-3), 2.2)
		t.eq(Anim.nextBlinkDelay(9), 5.0)
		t.ok(Anim.blinkClosed(0), "closed at start")
		t.ok(Anim.blinkClosed(0.12), "closed")
		t.ok(not Anim.blinkClosed(0.13), "open after duration")
		t.ok(not Anim.blinkClosed(-0.01), "not before")
	end)

	local function input(overrides: { [string]: any }?): any
		local base: { [string]: any } = {
			time = 0,
			idle = 1,
			walk = 0,
			phase = 0,
			bounce = 0,
			blinking = false,
			knocked = false,
			riseSpeed = 0,
			landTime = nil,
			landStrength = 0,
		}
		for k, v in overrides or {} do
			base[k] = v
		end
		return base
	end

	t.test("AC4: 깜빡이거나 넘어지면 눈을 넣고 감은 눈 선을 꺼내요", function()
		local open = Anim.pose(input())
		t.eq(open.eyesBack, 0)
		t.eq(open.lidForward, 0)
		for _, case in { { blinking = true }, { knocked = true } } do
			local p = Anim.pose(input(case))
			t.eq(p.eyesBack, Anim.EYE_HIDE)
			t.eq(p.lidForward, Anim.LID_SHOW)
		end
	end)

	t.test("AC4: 숨쉬기는 서 있을 때만, 발은 땅에 그대로 (몸 높이만큼 반대로)", function()
		local quarter = math.pi / 2 / Anim.BREATH_RATE
		local standing = Anim.pose(input({ time = quarter, idle = 1 }))
		t.ok(math.abs(standing.bodyY - Anim.BREATH_HEIGHT) < 1e-9, `breath {standing.bodyY}`)
		t.ok(math.abs(standing.footLeft.y + standing.bodyY) < 1e-9, "left foot planted")
		t.ok(math.abs(standing.footRight.y + standing.bodyY) < 1e-9, "right foot planted")
		local walking = Anim.pose(input({ time = quarter, idle = 0, walk = 1 }))
		t.eq(walking.bodyY, 0)
		t.eq(Anim.pose(input({ time = quarter, knocked = true })).bodyY, 0)
	end)

	t.test("AC4: 착지 찌그러짐 — 느린 착지는 0, 0.22초 안에 0으로, 최대 0.32", function()
		t.eq(Anim.landStrength(5), 0)
		t.ok(Anim.landStrength(8) > 0, "8 squashes")
		t.eq(Anim.landStrength(100), 1)
		local peak = 0
		for i = 0, 100 do
			local tt = i / 100 * Anim.SQUASH_TIME
			peak = math.max(peak, Anim.squash(tt, 1))
		end
		t.ok(peak <= Anim.SQUASH_DEPTH + 1e-9 and peak > Anim.SQUASH_DEPTH * 0.9, `peak {peak}`)
		t.eq(Anim.squash(Anim.SQUASH_TIME, 1), 0)
		t.eq(Anim.squash(0, 1), 0)
		t.eq(Anim.squash(0.05, 0), 0)
		-- 찌그러지는 동안 몸은 내려가고 발은 몸 속으로 (땅에 그대로)
		local p = Anim.pose(input({ landTime = Anim.SQUASH_TIME * 0.3, landStrength = 1, idle = 0 }))
		t.ok(p.bodyY < -0.2, `body drops {p.bodyY}`)
		t.ok(p.footLeft.y > 0.2, `foot rises relative to body {p.footLeft.y}`)
	end)

	t.test("AC4: 점프로 올라갈 때 몸은 위로, 발은 아래로 (늘어남)", function()
		local p = Anim.pose(input({ riseSpeed = 30, idle = 0 }))
		t.ok(math.abs(p.bodyY - Anim.STRETCH_RISE) < 1e-9, `body {p.bodyY}`)
		t.ok(p.footLeft.y < 0 and p.footRight.y < 0, "feet dangle")
		t.ok(p.footLeft.y >= Anim.FOOT_MIN, "within limit")
		t.eq(Anim.stretch(0), 0)
		t.eq(Anim.stretch(300), 1)
	end)

	t.test(
		"AC4: 걸을 때 두 발이 번갈아 들리고(같은 순간 한 발만), 오프셋은 한계 안",
		function()
			local leftUp, rightUp = 0, 0
			for i = 0, 63 do
				local phase = i / 64 * 2 * math.pi
				local bounce = math.abs(math.sin(phase)) * 0.3
				local p = Anim.pose(input({ walk = 1, idle = 0, phase = phase, bounce = bounce }))
				local l = p.footLeft.y + bounce -- 땅 기준 발 높이
				local r = p.footRight.y + bounce
				t.ok(not (l > 0.05 and r > 0.05), `both feet up at phase {phase}`)
				if l > 0.05 then
					leftUp += 1
				end
				if r > 0.05 then
					rightUp += 1
				end
				for _, foot in { p.footLeft, p.footRight } do
					t.ok(foot.y >= Anim.FOOT_MIN and foot.y <= Anim.FOOT_MAX, `foot y {foot.y}`)
					t.ok(math.abs(foot.z) <= Anim.STEP_STRIDE + 1e-9, `foot z {foot.z}`)
				end
			end
			t.ok(leftUp > 10 and rightUp > 10, `steps {leftUp}/{rightUp}`)
		end
	)
end
