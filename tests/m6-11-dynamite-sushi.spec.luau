--!strict
-- m6-11 전설 스킨 "다이너마이트 스시" (m6-08~m6-10 전설·고등어 [신선]과 같은 규칙):
--   카탈로그(전설 R$ 199 + 뽑기 전설, order 49 맨 끝, 대사 2줄, conceptBody)·현지화 행, 콘셉트 몸·뽑기 목록(18종),
--   규칙 표(상한 70·외곽 ±25%·이름표 기본 3.6), 뽑기 전설 등급 9종 균등(스킨마다 0.111%, 화면 0.11%)·중복 코인,
--   탈의실 카드·뽑기 안내, 모양 한도(표정 6종: 파츠·발바닥·꼭대기·효과 2개·겹침·떠 있음·외곽·얼굴 안 가림·공유 몸 그대로·
--   관절 8개), 모양 읽힘(빨간 막대 8개 이상이 밥 둘레·뒤, 위로 삐죽 / 숯빛 띠 두 줄이 얼굴 위·아래 / 밥 위 심지 끝 Neon
--   불꽃 + Sparkles, 그 옆 Smoke), 손에 든 물건 없음(모두 Body에 용접), 스킨 id 분기 없음, 일반 디자인(작품 이름 없음).

local fs = require("@lune/fs")

local LocTest = require("./lib/LocTest")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local LayoutCheck = require("../tools/render/LayoutCheck")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)

local ID = "dynamite-sushi"
local KO = "다이너마이트 스시"
local EN = "Dynamite Sushi"
local SPEECH = { "한 입 먹으면 맛이 펑! 터질걸?", "심지에 불도 안 붙었는데 먹혔어…!" }
local SPEECH_EN = { "One bite and the flavor goes BOOM!", "Eaten before my fuse even got lit…!" }
local PREFIX = "Dynamite"
local BUDGET = 70
local EFFECTS = { "Smoke", "Sparkles" }
local SALMON = "concept-salmon"
local LEGENDARY_DRAW = {
	"fresh-mackerel",
	"dragon-sushi",
	"sky-dragon-sushi",
	"jet-sushi",
	"shadow-jet-sushi",
	"magical-girl-sushi",
	"angel-sushi",
	"devil-sushi",
	ID,
}

local FACE_PREFIXES = { "Eye", "Lid", "Shine", "Mouth", "Tongue", "Cheek", "Brow", "Sweat", "Bandage", "Anger" }
local function isFace(name: string): boolean
	for _, prefix in FACE_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end
local function isSharedBody(name: string): boolean
	return string.match(name, "^Body") ~= nil or string.match(name, "^Arm") ~= nil or string.match(name, "^Foot") ~= nil
end

local function sorted(list: { string }): { string }
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end

local function keys(map: { [string]: any }): { string }
	local list = {}
	for key in map do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

local function fakeRng(number: number, integer: number?)
	return {
		NextNumber = function(_): number
			return number
		end,
		NextInteger = function(_, _min: number, _max: number): number
			return integer or 1
		end,
	}
end

local function isStick(name: string): boolean
	return string.match(name, "^DynamiteStick") ~= nil and string.match(name, "^DynamiteStickEnd") == nil
end

local SALMON_BOUNDS = SushiBody.bounds(SushiBody.layout(SALMON))
local MAX_X = (SALMON_BOUNDS.max[1] - SALMON_BOUNDS.min[1]) * 1.25
local MAX_Z = (SALMON_BOUNDS.max[3] - SALMON_BOUNDS.min[3]) * 1.25
local RICE_FRONT = -1.35
local RICE_TOP = 1.0

return function(t: Test.Test)
	---------------------------------------------------------------- 카탈로그·현지화
	t.test(
		"카탈로그: 전설 R$ 199 + 뽑기 전설, 코인·상품 id 없음, order 49(맨 끝, 악마 다음), 대사 2줄, conceptBody",
		function()
			t.eq(#Skins.LIST, 49)
			t.eq(#Skins.byTier("Legendary"), 15)
			local skin = Skins.get(ID) :: any
			t.ok(skin ~= nil, ID)
			t.eq(skin.displayName, KO)
			t.eq(skin.tier, "Legendary")
			t.eq(skin.robux, 199)
			t.eq(skin.robux, Skins.TIER_ROBUX.Legendary)
			for _, field in { "coins", "tokens", "season", "vipOnly", "productId" } do
				t.eq(skin[field], nil, field)
			end
			t.eq(skin.order, 49)
			t.eq(skin.speech, SPEECH)
			t.eq(Cutscene.SKIN_LINES[ID], skin.speech, "elimination lines")
			t.eq(skin.conceptBody, true)
			t.eq(skin.drawGrade, "Legendary")
			t.eq(Skins.isDraw(ID), true)
			t.eq(Skins.isDrawOnly(ID), false)
			t.eq(Skins.isFree(ID), false)
			t.eq(Skins.LIST[49].id, ID, "last in order")
			t.eq(Skins.LIST[#Skins.LIST].id, ID)
			t.eq(Skins.LIST[48].id, "devil-sushi", "after devil-sushi")
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("현지화: 이름·대사 키의 Source = 카탈로그 한국어, en = 우리 영어", function()
		t.ok(LocTest.catalog[`skin.{ID}.name`] ~= nil, "name key")
		t.eq(LocTest.ko({ key = `skin.{ID}.name` }), KO)
		t.eq(LocTest.en({ key = `skin.{ID}.name` }), EN)
		for n = 1, 2 do
			local key = `skin.{ID}.speech.{n}`
			t.ok(LocTest.has(key), key)
			t.eq(LocTest.ko({ key = key }), SPEECH[n], key)
			t.eq(LocTest.en({ key = key }), SPEECH_EN[n], key)
		end
	end)

	---------------------------------------------------------------- 목록·규칙 표
	t.test(
		"목록: 콘셉트 몸·견본·뽑기 목록 18종(특 9 + 전설 9), 뽑기 전용은 특 9종 그대로",
		function()
			for _, list in { Skins.CONCEPT_BODY_IDS, SushiBody.CONCEPT_BODY, Skins.DRAW_IDS } do
				t.ok((list :: any)[ID] ~= nil, "in table")
				t.eq(#keys(list :: any), 18)
			end
			t.ok(table.find(Sample.SKIN_IDS, ID) ~= nil, "sample skin ids")
			t.eq(#Sample.SKIN_IDS, 18)
			t.eq(keys(Skins.CONCEPT_BODY_IDS), sorted(Sample.SKIN_IDS))
			t.eq(keys(Skins.DRAW_IDS), keys(Skins.CONCEPT_BODY_IDS))
			local drawOnly = 0
			for _, skin in Skins.LIST do
				if Skins.isDrawOnly(skin.id) then
					drawOnly += 1
				end
			end
			t.eq(drawOnly, 9)
		end
	)

	t.test("규칙 표: 상한 70(제트기·악마와 같음), 전설 ±25%, 이름표 기본 3.6", function()
		local rule = SushiBody.CONCEPT_BODY[ID]
		t.eq(rule.partBudget, BUDGET)
		t.eq(rule.boundsTolerance, SushiBody.BOUNDS_TOLERANCE.Legendary)
		t.eq(rule.expressions, Sample.EXPRESSIONS)
		t.eq(rule.nameTagHeight, nil)
		t.eq(SushiBody.nameTagHeight(ID), SushiBody.NAME_TAG_HEIGHT)
		t.eq(SushiBody.NAME_TAG_HEIGHT, 3.6)
	end)

	---------------------------------------------------------------- 뽑기
	t.test(
		"뽑기: 전설 등급 9종(order 순), 확률 표 그대로 1/5/15/30/49, 스킨마다 0.111%(화면 0.11%), 균등·중복 🍚 300",
		function()
			local rows = DrawLogic.grades()
			local byGrade = {}
			for _, row in rows do
				byGrade[row.grade] = row
			end
			t.eq(byGrade.Legendary.skinIds, LEGENDARY_DRAW)
			t.ok(math.abs(byGrade.Legendary.chance - 0.01) < 1e-9, "legendary 1%")
			t.ok(math.abs(byGrade.Epic.chance - 0.05) < 1e-9, "epic 5%")
			t.ok(math.abs(byGrade.Rare.chance - 0.15) < 1e-9, "rare 15%")
			t.ok(math.abs(byGrade.Uncommon.chance - 0.30) < 1e-9, "uncommon 30%")
			t.ok(math.abs(byGrade.Common.chance - 0.49) < 1e-9, "common 49%")
			t.ok(math.abs(byGrade.Legendary.chance / #byGrade.Legendary.skinIds - 0.01 / 9) < 1e-12, "0.111% each")
			t.eq(DrawLogic.displayPercents(rows).Legendary, "1.0%")
			local perSkin = DrawLogic.perSkinPercent(rows)
			for _, id in LEGENDARY_DRAW do
				t.eq(perSkin[id], "0.11%", id)
			end
			t.eq(DrawLogic.totalSkins(), 18)
			local index = table.find(LEGENDARY_DRAW, ID) :: number
			t.eq(index, 9)
			local outcome = DrawLogic.roll({}, fakeRng(0.005, index)) :: any
			t.eq(outcome.grade, "Legendary")
			t.eq(outcome.skinId, ID)
			t.eq(outcome.kind, "Skin")
			local dup = DrawLogic.roll({ [ID] = true }, fakeRng(0.005, index)) :: any
			t.eq(dup.kind, "Duplicate")
			t.eq(dup.coins, Config.Draw.DuplicateCoins.Legendary)
			t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), ID, 1, true), nil, "DrawLogic has no id")
			t.eq(string.find(fs.readFile("src/shared/Config.luau"), ID, 1, true), nil, "Config has no id")
		end
	)

	t.test(
		"뽑기 보유 = 구매 보유: 뽑은 뒤 로벅스 구매는 AlreadyOwned, 산 뒤 뽑기는 중복",
		function()
			local index = table.find(LEGENDARY_DRAW, ID) :: number
			local wallet: any = ProfileSchema.new()
			wallet.drawTickets = 1
			DrawLogic.apply(wallet, DrawLogic.roll(wallet.ownedSkins, fakeRng(0.001, index)) :: any)
			t.eq(wallet.ownedSkins[ID], true)
			t.eq(wallet.equippedSkin, "tamago", "equip unchanged")
			local ok, reason = ReceiptLogic.canRequest(ID, wallet.ownedSkins, { canSave = true, fake = true })
			t.eq(ok, false)
			t.eq(reason, "AlreadyOwned")
			t.eq((ShopLogic.canEquip(ID, wallet.ownedSkins)), true)
			local bought: any = ProfileSchema.new()
			t.eq(ReceiptLogic.canRequest(ID, bought.ownedSkins, { canSave = true, fake = true }), true)
			ShopLogic.grantSkin(bought, ID, true)
			t.eq((DrawLogic.roll(bought.ownedSkins, fakeRng(0.001, index)) :: any).kind, "Duplicate")
		end
	)

	---------------------------------------------------------------- 탈의실
	t.test(
		"탈의실: 전설 탭 맨 끝(악마 다음), 다른 전설과 같은 로벅스 카드, 뽑기 안내, 🎫 특 탭엔 없음, 코인 불가",
		function()
			local view = { coins = 99999, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
			local function tab(id: string): any
				for _, item in ShopLogic.tabs() do
					if item.id == id then
						return item
					end
				end
				return nil
			end
			local legendary = ShopLogic.visibleSkins(view :: any, tab("Legendary"))
			t.eq(legendary[#legendary].id, ID)
			t.eq(legendary[#legendary - 1].id, "devil-sushi")
			for _, skin in ShopLogic.visibleSkins(view :: any, tab("draw")) do
				t.ok(skin.id ~= ID, "not in the special tab")
			end
			local skin = Skins.get(ID) :: any
			local soon = ShopLogic.cardState(skin, view :: any, { fake = false })
			t.eq(soon.kind, "Robux")
			t.eq(soon.enabled, false, "no product id yet")
			t.eq(LocTest.ko(ShopLogic.cardButtonText(soon)), "R$ 199 — 곧 열려요")
			t.eq(
				LocTest.ko(ShopLogic.cardButtonText(ShopLogic.cardState(skin, view :: any, { fake = true }))),
				"R$ 199"
			)
			t.eq(LocTest.ko(ShopLogic.drawHint(skin)), "🎫 뽑기 전설에서도 나와요")
			t.eq(
				ShopLogic.canBuyWithCoins(ID, { coins = 99999, ownedSkins = { tamago = true } } :: any).reason,
				"NotForCoins"
			)
		end
	)

	---------------------------------------------------------------- 모양 한도
	t.test(
		"모양: 표정 6종 모두 파츠 ≤ 70, 발바닥 = GROUND_OFFSET, 꼭대기 ≤ 이름표 − 0.4, 효과 2개, 겹침·떠 있음 0, 외곽 ±25%",
		function()
			t.eq(SushiBody.hasLayout(ID), true)
			for _, expression in Sample.EXPRESSIONS do
				local layout = SushiBody.layout(ID, expression)
				local label = `{ID}/{expression}`
				t.ok(#layout <= BUDGET, `{label} parts {#layout}`)
				local b = SushiBody.bounds(layout)
				t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) < 1e-9, `{label} sole {b.min[2]}`)
				t.ok(b.max[2] <= SushiBody.nameTagHeight(ID) - 0.4, `{label} top {b.max[2]}`)
				t.ok(b.max[1] - b.min[1] <= MAX_X + 1e-9, `{label} width {b.max[1] - b.min[1]} > {MAX_X}`)
				t.ok(b.max[3] - b.min[3] <= MAX_Z + 1e-9, `{label} depth {b.max[3] - b.min[3]} > {MAX_Z}`)
				local effects = {}
				for _, spec in layout do
					if spec.effect then
						table.insert(effects, spec.effect)
					end
				end
				table.sort(effects)
				t.eq(effects, EFFECTS, label)
				t.ok(#effects <= SushiBody.EFFECT_BUDGET.Legendary, `{label} effect budget`)
				t.eq(LayoutCheck.zFight(layout), {}, `{label} z-fighting`)
				t.eq(LayoutCheck.floating(layout), {}, `{label} floating`)
				local names = {}
				for _, spec in layout do
					t.ok(names[spec.name] == nil, `{label} duplicate {spec.name}`)
					names[spec.name] = true
					if spec.shape == "Ball" then
						t.ok(spec.size[1] == spec.size[2] and spec.size[2] == spec.size[3], `{label} {spec.name}`)
					end
					t.ok((spec.transparency or 0) < 0.5, `{label} {spec.name} visible`)
				end
			end
		end
	)

	t.test(
		"공유 몸: 밥·받침·팔·다리·얼굴(표정별)은 concept-salmon과 같고, 토핑 파츠 이름은 Dynamite로만",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local mine = byName(SushiBody.layout(ID, expression))
				local salmon = byName(SushiBody.layout(SALMON, expression))
				local label = `{ID}/{expression}`
				for name, spec in salmon do
					if isFace(name) or isSharedBody(name) then
						t.eq(mine[name], spec, `{label} {name}`)
					end
				end
				for name in mine do
					if salmon[name] == nil or not (isFace(name) or isSharedBody(name)) then
						t.eq(string.sub(name, 1, #PREFIX), PREFIX, `{label} topping part {name}`)
					end
				end
			end
		end
	)

	t.test(
		"얼굴 안 가림: 토핑은 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면(z −1.35)보다 앞으로 안 나와요",
		function()
			for _, expression in Sample.EXPRESSIONS do
				for _, spec in SushiBody.layout(ID, expression) do
					if not isFace(spec.name) and not isSharedBody(spec.name) then
						local lo, hi = LayoutCheck.box(spec)
						local inFace = hi[1] > -1.4 and lo[1] < 1.4 and hi[2] > -0.8 and lo[2] < 0.76
						t.ok(
							not inFace or lo[3] >= RICE_FRONT - 1e-6,
							`{expression} {spec.name} covers the face (z {lo[3]}, y {lo[2]}..{hi[2]})`
						)
					end
				end
			end
		end
	)

	t.test("관절: 공유 몸 8개뿐, 손에 든 물건 없음 — 토핑은 모두 Body에 용접", function()
		local joints = {}
		for _, spec in SushiBody.layout(ID) do
			if spec.joint then
				table.insert(joints, spec.name)
			end
			t.eq(spec.pivot, nil, `{spec.name} pivot`)
			t.eq(spec.reach, nil, `{spec.name} reach`)
			if string.sub(spec.name, 1, #PREFIX) == PREFIX then
				t.eq(spec.attach, nil, `{spec.name} welded to Body`)
				t.eq(spec.joint, nil, `{spec.name} no joint`)
			end
		end
		t.eq(sorted(joints), {
			"ArmLeft",
			"ArmRight",
			"EyeLeft",
			"EyeRight",
			"FootLeft",
			"FootRight",
			"LidLeft",
			"LidRight",
		})
	end)

	---------------------------------------------------------------- 모양 읽힘
	t.test(
		"막대: 빨간 세운 원기둥 8개 이상이 밥 둘레(뒤·옆)에 서고 위끝이 밥 위로 삐죽, 뒤는 막대가 거의 다 덮어요, 끝 마개 하나씩",
		function()
			local layout = SushiBody.layout(ID)
			local map = byName(layout)
			local count, back, sides = 0, 0, 0
			local backSpan = 0
			for _, spec in layout do
				if isStick(spec.name) then
					count += 1
					t.eq(spec.shape, "Cylinder", spec.name)
					t.eq(spec.rotation, { 0, 0, 90 }, `{spec.name} upright`)
					local c = spec.color
					t.ok(c[1] > 180 and c[2] < 80 and c[3] < 80, `{spec.name} red`)
					local lo, hi = LayoutCheck.box(spec)
					t.ok(hi[2] > RICE_TOP + 0.25, `{spec.name} peeks above the rice ({hi[2]})`)
					t.ok(lo[2] < -0.9, `{spec.name} runs down the side ({lo[2]})`)
					if spec.offset[3] > 1.2 then
						back += 1
						backSpan += hi[1] - lo[1]
					end
					if math.abs(spec.offset[1]) > 1.4 then
						sides += 1
					end
					local cap = map[`DynamiteStickEnd{string.sub(spec.name, #"DynamiteStick" + 1)}`]
					t.ok(cap ~= nil, `{spec.name} end cap`)
					t.ok(cap.size[2] < spec.size[2], `{spec.name} cap narrower (bevel)`)
					local _, capHi = LayoutCheck.box(cap)
					t.ok(capHi[2] > hi[2], `{spec.name} cap on top`)
				end
			end
			t.ok(count >= 8 and count <= 10, `about 8 sticks ({count})`)
			t.ok(back >= 4, `sticks across the back ({back})`)
			t.ok(sides >= 4, `sticks on the sides ({sides})`)
			-- 뒤 줄 막대 폭의 합이 밥 폭(3.6)의 90% 이상 — 뒤에서 울타리가 아니라 묶음으로 보여요
			t.ok(backSpan >= 3.6 * 0.9, `back is covered ({backSpan})`)
		end
	)

	t.test(
		"띠: 짙은 숯빛 띠 두 줄(위·아래)이 앞·뒤·양옆을 둘러요, 앞 띠는 얼굴 위·아래로만",
		function()
			local map = byName(SushiBody.layout(ID))
			for _, band in { "Upper", "Lower" } do
				for _, part in { "Front", "Back", "Left", "Right" } do
					local spec = map[`DynamiteStrap{band}{part}`]
					t.ok(spec ~= nil, `{band} {part}`)
					local c = spec.color
					t.ok(c[1] < 90 and c[2] < 90 and c[3] < 90, `{band} {part} charcoal`)
					t.ok(math.abs(c[1] - c[2]) < 20 and math.abs(c[2] - c[3]) < 20, `{band} {part} gray`)
				end
				local front = map[`DynamiteStrap{band}Front`]
				local lo, hi = LayoutCheck.box(front)
				t.ok(hi[1] - lo[1] > 3.0, `{band} front strap spans the face width`)
				if band == "Upper" then
					t.ok(lo[2] >= 0.76, `upper strap above the face ({lo[2]})`)
					t.ok(hi[2] - lo[2] >= 0.25, "thick upper strap")
				else
					t.ok(hi[2] <= -0.8, `lower strap below the face ({hi[2]})`)
					t.ok(hi[2] - lo[2] >= 0.2, "thick lower strap")
				end
				-- 뒤 띠는 뒤 막대 바깥 (막대가 띠 안에 묶여요)
				local back = map[`DynamiteStrap{band}Back`]
				local stickLo, stickHi = LayoutCheck.box(map.DynamiteStickBackMid)
				local backLo = LayoutCheck.box(back)
				t.ok(backLo[3] >= stickHi[3] - 0.02 and stickLo[3] < backLo[3], `{band} back strap wraps the sticks`)
			end
		end
	)

	t.test(
		"심지: 밥 위 갈색 받침 + 꼰 심지(두 색 번갈아)가 옆으로 휘고, 끝에 Neon 불꽃 + Sparkles, 그 옆 마디에 Smoke",
		function()
			local layout = SushiBody.layout(ID)
			local map = byName(layout)
			local cap = map.DynamiteFuseCap
			t.ok(cap ~= nil, "fuse cap")
			local capLo = LayoutCheck.box(cap)
			t.ok(capLo[2] < RICE_TOP, "cap sits on the rice")
			local segments = {}
			for i = 1, 8 do
				local spec = map[`DynamiteFuse{i}`]
				if spec then
					table.insert(segments, spec)
				end
			end
			t.ok(#segments >= 3, `segmented fuse ({#segments})`)
			t.ok(segments[1].color ~= segments[2].color, "braided: alternating colors")
			local spark = map.DynamiteSpark
			t.ok(spark ~= nil, "spark")
			t.eq(spark.material, "Neon")
			t.eq(spark.effect, "Sparkles")
			t.ok(spark.color[1] > 230 and spark.color[2] > 150 and spark.color[3] < 120, "yellow-orange spark")
			t.ok(math.abs(spark.offset[1]) > 0.5, "fuse curves to one side")
			local rays = 0
			for _, spec in layout do
				if string.match(spec.name, "^DynamiteSparkRay") then
					rays += 1
					t.eq(spec.material, "Neon", spec.name)
					t.ok(spec.size[1] > spark.size[1], `{spec.name} pokes out of the ball`)
				end
			end
			t.ok(rays >= 2, `star burst rays ({rays})`)
			local top = SushiBody.bounds(layout).max[2]
			local _, sparkHi = LayoutCheck.box(spark)
			t.ok(sparkHi[2] >= top - 0.5, "spark near the top")
			local smoke
			for _, spec in layout do
				if spec.effect == "Smoke" then
					smoke = spec
				end
			end
			t.ok(smoke ~= nil, "smoke part")
			local dx, dy, dz =
				smoke.offset[1] - spark.offset[1], smoke.offset[2] - spark.offset[2], smoke.offset[3] - spark.offset[3]
			t.ok(math.sqrt(dx * dx + dy * dy + dz * dz) < 0.6, "smoke right next to the tip")
			t.ok(smoke.effectColor[1] > 180 and smoke.effectColor[1] == smoke.effectColor[2], "light grey smoke")
		end
	)

	t.test("validate가 잡아요: 파츠 상한을 낮추거나 외곽 허용치를 줄이면 거절", function()
		local rule = SushiBody.CONCEPT_BODY[ID]
		local savedBudget, savedTolerance = rule.partBudget, rule.boundsTolerance
		rule.partBudget = #SushiBody.layout(ID) - 1
		local ok, problems = Skins.validate(Skins.LIST)
		rule.partBudget = savedBudget
		t.eq(ok, false, "over budget")
		t.ok(string.find(table.concat(problems, ";"), "concept body budget", 1, true) ~= nil)
		rule.boundsTolerance = 0
		ok, problems = Skins.validate(Skins.LIST)
		rule.boundsTolerance = savedTolerance
		t.eq(ok, false, "bounds")
		t.ok(string.find(table.concat(problems, ";"), "concept body bounds", 1, true) ~= nil)
		t.eq((Skins.validate(Skins.LIST)), true, "restored")
	end)

	---------------------------------------------------------------- 코드 규칙
	t.test(
		"스킨 id 분기 없음: 클라이언트·서버 코드에 id가 없고, 공유 코드는 카탈로그·규칙 표·견본·공격 연출 표만",
		function()
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.match(name, "%.luau$") then
						t.eq(string.find(fs.readFile(path), `"{ID}"`, 1, true), nil, `{path} mentions {ID}`)
					end
				end
			end
			scan("src/client")
			scan("src/server")
			for _, name in fs.readDir("src/shared") do
				local path = `src/shared/{name}`
				if fs.isFile(path) and string.match(name, "%.luau$") then
					if string.find(fs.readFile(path), `"{ID}"`, 1, true) ~= nil then
						t.ok(
							name == "Skins.luau"
								or name == "SushiBody.luau"
								or name == "SushiConceptSample.luau"
								or name == "AttackFxLogic.luau",
							`{path} mentions {ID}`
						)
					end
				end
			end
			-- 토핑 모듈은 순수 데이터: PartMath 하나만 require, Roblox API 없음
			local topping = fs.readFile("src/shared/ConceptDynamite.luau")
			local _, requires = string.gsub(topping, "require%(", "")
			t.eq(requires, 1)
			t.ok(string.find(topping, "require(script.Parent.PartMath)", 1, true) ~= nil)
			t.eq(string.find(topping, "Instance.new", 1, true), nil)
			t.eq(string.find(topping, "game:GetService", 1, true), nil)
		end
	)

	t.test(
		"일반 디자인: 토핑 모듈·카탈로그·문구에 특정 작품·캐릭터 이름이 없어요",
		function()
			local banned =
				{ "tnt", "acme", "bomberman", "minecraft", "creeper", "looney", "wile e", "fortnite", "bob-omb" }
			for _, path in
				{
					"src/shared/ConceptDynamite.luau",
					"src/shared/Skins.luau",
					"src/shared/Localization/Strings.csv",
				}
			do
				local source = string.lower(fs.readFile(path))
				for _, word in banned do
					t.eq(string.find(source, word, 1, true), nil, `{path} has {word}`)
				end
			end
		end
	)
end
