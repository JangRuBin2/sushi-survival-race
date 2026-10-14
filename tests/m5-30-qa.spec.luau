--!strict
-- m5-30 QA 회귀 테스트: 콘셉트 스킨 2차 토핑 퀄리티 패스(장어·성게·문어·유부).
-- m5-29 QA B1(당황 눈썹이 김 띠에 가림)·B2(장어 등 세로 김이 밥에서 뜸) 고정, 파츠 상한 70이 콘셉트 9종에만 걸리고
-- 다른 스킨 검사를 약하게 만들지 않는지, 새 토핑 파츠 이름이 얼굴 접두어와 겹치지 않는지(성게 Tongue → Lobe),
-- 재질 예외(장어 Glass = 소스 층, 유부 Sand)가 그 스킨에만 있는지.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)

local NEW = { "concept-unagi", "concept-uni", "concept-tako", "concept-inari" }
local BANDED = { "concept-unagi", "concept-uni" } -- 몸 위쪽을 김 띠가 두르는 스킨
local SALMON = "concept-salmon"
local INARI = "concept-inari"
local UNAGI = "concept-unagi"
local RICE_BACK = 1.35 -- 콘셉트 밥 등면 z
local RICE_BOTTOM = -1.0

local FACE_PREFIXES = { "Eye", "Lid", "Shine", "Mouth", "Tongue", "Cheek", "Brow", "Sweat", "Bandage" }
local function isFace(name: string): boolean
	for _, prefix in FACE_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

-- 게임 레이아웃(nil·4표정)과 견본 레이아웃(4표정 × 2자세) 모두
local function allLayouts(id: string): { { label: string, layout: { any } } }
	local out = {}
	for _, expression in { nil :: string?, "Default", "Happy", "Flustered", "Hurt" } do
		table.insert(out, { label = `{id}/game/{tostring(expression)}`, layout = SushiBody.layout(id, expression) })
	end
	for _, expression in Sample.EXPRESSIONS do
		for _, pose in Sample.POSES do
			table.insert(
				out,
				{ label = `{id}/sample/{expression}/{pose}`, layout = Sample.layout(expression, pose, id) }
			)
		end
	end
	return out
end

local function sortedSet(names: { [string]: boolean }): { string }
	local list = {}
	for name in names do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return function(t: Test.Test)
	t.test(
		"QA B1: 장어·성게 — 모든 표정·자세에서 김 띠 아래끝이 눈썹 위끝보다 위이고, 땀방울은 띠보다 앞에 있어요",
		function()
			for _, id in BANDED do
				for _, entry in allLayouts(id) do
					local bandBottom, browTop = math.huge, -math.huge
					local bandFront = math.huge
					local sweatFront: number? = nil
					for _, spec in entry.layout do
						local lo, hi = LayoutCheck.box(spec)
						if string.sub(spec.name, 1, 4) == "Band" and not isFace(spec.name) then
							bandBottom = math.min(bandBottom, lo[2])
							bandFront = math.min(bandFront, lo[3])
						elseif string.sub(spec.name, 1, 4) == "Brow" then
							browTop = math.max(browTop, hi[2])
						elseif spec.name == "Sweat" then
							sweatFront = lo[3]
						end
					end
					t.ok(bandBottom < math.huge, `{entry.label} has a band`)
					t.ok(bandBottom >= browTop + 0.02, `{entry.label} band bottom {bandBottom} vs brow top {browTop}`)
					if sweatFront ~= nil then
						t.ok(sweatFront < bandFront, `{entry.label} sweat in front of the band`)
					end
				end
			end
		end
	)

	t.test(
		"QA B2: 장어 등 세로 김 — 띠 아래 조각은 밥 등면에 붙고, 띠 위 조각과 이어져 밥 아래끝 가까이까지 내려가요",
		function()
			for _, entry in allLayouts(UNAGI) do
				local parts = byName(entry.layout)
				local low, high = parts.NoriBackLow, parts.NoriBack
				t.ok(low ~= nil and high ~= nil, `{entry.label} back nori pieces`)
				if low == nil or high == nil then
					continue
				end
				local bandBottom = math.huge
				local bandBack = -math.huge
				for _, spec in entry.layout do
					if string.sub(spec.name, 1, 4) == "Band" and not isFace(spec.name) then
						local lo, hi = LayoutCheck.box(spec)
						bandBottom = math.min(bandBottom, lo[2])
						bandBack = math.max(bandBack, hi[3])
					end
				end
				local lowLo, lowHi = LayoutCheck.box(low)
				local highLo = LayoutCheck.box(high)
				-- 밥 등면(1.35)이 띠 아래 조각 두께 안에 있어요 (틈 0)
				t.ok(
					lowLo[3] <= RICE_BACK + 1e-6 and lowHi[3] >= RICE_BACK,
					`{entry.label} low piece touches rice back`
				)
				-- 두 조각이 띠 아래끝에서 이어져요
				t.ok(lowHi[2] >= bandBottom - 1e-6, `{entry.label} low piece reaches the band`)
				t.ok(highLo[2] <= bandBottom + 1e-6, `{entry.label} high piece reaches the band bottom`)
				t.ok(lowLo[2] <= RICE_BOTTOM + 0.1, `{entry.label} low piece runs down the back`)
				-- 띠 위 조각은 띠 등면에서 눈에 띄게 뜨지 않아요 (지금 0.06)
				t.ok(highLo[3] - bandBack <= 0.08, `{entry.label} high piece gap {highLo[3] - bandBack}`)
			end
		end
	)

	t.test(
		"QA: 파츠 상한 70은 콘셉트 9종에만 — 일반 스킨 상한 40 그대로, 상한을 넘으면 validate가 잡아요",
		function()
			t.eq(SushiBody.PART_BUDGET, 40)
			local ids = {}
			for id, rule in SushiBody.EXPERIMENTAL do
				table.insert(ids, id)
				t.eq(rule.partBudget, 70, id)
			end
			table.sort(ids)
			local expected = table.clone(Sample.SKIN_IDS)
			table.sort(expected)
			t.eq(ids, expected)
			-- 실험 스킨이 아닌 스킨은 여전히 40 이하 (표정 4종 모두)
			for _, skin in Skins.LIST do
				if skin.experimental ~= true and SushiBody.hasLayout(skin.id) then
					for _, expression in { nil :: string?, "Default", "Happy", "Flustered", "Hurt" } do
						local count = #SushiBody.layout(skin.id, expression)
						t.ok(count <= SushiBody.PART_BUDGET, `{skin.id}/{tostring(expression)} parts {count}`)
					end
				end
			end
			-- 상한 검사가 실제로 동작해요: 새 4종 상한을 기본 레이아웃보다 낮추면 validate가 거절
			for _, id in NEW do
				local rule = SushiBody.EXPERIMENTAL[id]
				local saved = rule.partBudget
				rule.partBudget = #SushiBody.layout(id) - 1
				local ok, problems = Skins.validate(Skins.LIST)
				rule.partBudget = saved
				t.eq(ok, false, `{id} over budget rejected`)
				t.ok(
					string.find(table.concat(problems, ";"), "experimental budget", 1, true) ~= nil,
					`{id} budget message`
				)
			end
			t.eq((Skins.validate(Skins.LIST)), true, "restored catalog valid")
		end
	)

	t.test(
		"QA: 새 4종의 얼굴 접두어 파츠는 콘셉트 연어와 똑같아요 (토핑 이름이 Tongue·Eye 등과 겹치지 않음)",
		function()
			for _, id in NEW do
				for _, expression in { nil :: string?, "Default", "Happy", "Flustered", "Hurt" } do
					local mine, salmon = {}, {}
					for _, spec in SushiBody.layout(id, expression) do
						if isFace(spec.name) then
							mine[spec.name] = true
						end
					end
					for _, spec in SushiBody.layout(SALMON, expression) do
						if isFace(spec.name) then
							salmon[spec.name] = true
						end
					end
					t.eq(sortedSet(mine), sortedSet(salmon), `{id}/{tostring(expression)} face parts`)
				end
			end
		end
	)

	t.test("QA: 재질 예외는 그 스킨에만 — 장어 Glass는 소스 층뿐, Sand는 유부뿐", function()
		local function glassNames(id: string): { [string]: boolean }
			local names = {}
			for _, spec in SushiBody.layout(id, "Flustered") do
				if spec.material == "Glass" then
					names[spec.name] = true
				end
			end
			return names
		end
		local salmonGlass = glassNames(SALMON) -- 얼굴(땀 등)의 Glass
		local unagiExtra = {}
		for name in glassNames(UNAGI) do
			if not salmonGlass[name] and not isFace(name) then
				-- 소스 층은 pillow라 Glaze·GlazeFront·GlazeCorner1 … 여러 조각이에요
				unagiExtra[if string.sub(name, 1, 5) == "Glaze" then "Glaze*" else name] = true
			end
		end
		t.eq(sortedSet(unagiExtra), { "Glaze*" }, "unagi glass topping = glaze only")
		local unagi = byName(SushiBody.layout(UNAGI))
		t.eq(unagi.Eel.material, "SmoothPlastic", "grilled flesh is not glass")
		for _, id in Sample.SKIN_IDS do
			local sand = 0
			for _, spec in SushiBody.layout(id) do
				if spec.material == "Sand" then
					sand += 1
				end
			end
			if id == INARI then
				t.ok(sand > 0, "inari uses Sand")
				t.eq(byName(SushiBody.layout(id)).Body.material, "Sand", "inari pouch material")
			else
				t.eq(sand, 0, `{id} has no Sand`)
			end
		end
	end)
end
