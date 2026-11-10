--!strict
-- m6-10 전설 스킨 2종 "천사 스시"·"악마 스시" (m6-08·m6-09 전설·고등어 [신선]과 같은 규칙):
--   카탈로그(전설 R$ 199 + 뽑기 전설, order 47~48, 대사 2줄, conceptBody)·현지화 행, 콘셉트 몸·뽑기 목록(17종),
--   규칙 표(천사 80·악마 70·외곽 ±25%·이름표 기본 3.6), 뽑기 전설 등급 8종 균등·중복 코인, 탈의실 카드·뽑기 안내,
--   모양 한도(표정 6종: 파츠·발바닥·꼭대기·효과 2개·겹침·떠 있음·외곽·얼굴 안 가림·공유 몸 그대로·관절 8개),
--   손에 든 홀·삼지창은 오른팔(ArmRight)에 붙음, 천사는 바이저·빨간 눈 없음 / 악마는 얼굴 위 바이저 + 빨간 눈 둘,
--   스킨 id 분기 없음, 일반적인 디자인(특정 작품 이름 없음).

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

type Row = {
	id: string,
	ko: string,
	en: string,
	speech: { string },
	speechEn: { string },
	order: number,
	budget: number,
	effects: { string },
	prefix: string,
	held: string, -- 손에 든 물건 파츠 이름 접두어 (오른팔에 붙어요)
}
local NEW: { Row } = {
	{
		id = "angel-sushi",
		ko = "천사 스시",
		en = "Angel Sushi",
		speech = { "날개가 있어도 젓가락은 못 피했어…!", "천사의 축복… 맛있게 먹어 줘~" },
		speechEn = { "Even with wings, I couldn't dodge the chopsticks…!", "An angel's blessing… enjoy your meal~" },
		order = 47,
		budget = 80,
		effects = { "Glow", "Sparkles" },
		prefix = "Angel",
		held = "AngelScepter",
	},
	{
		id = "devil-sushi",
		ko = "악마 스시",
		en = "Devil Sushi",
		speech = { "크크, 날 먹으면 배탈 날걸?", "악마도 간장엔 약하다고…!" },
		speechEn = { "Heh heh, eat me and you'll get a tummy ache!", "Even devils are weak to soy sauce…!" },
		order = 48,
		budget = 70,
		effects = { "Glow", "Smoke" },
		prefix = "Devil",
		held = "DevilTrident",
	},
}
local NEW_IDS = {}
for _, row in NEW do
	table.insert(NEW_IDS, row.id)
end
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

local SALMON_BOUNDS = SushiBody.bounds(SushiBody.layout(SALMON))
local MAX_X = (SALMON_BOUNDS.max[1] - SALMON_BOUNDS.min[1]) * 1.25
local MAX_Z = (SALMON_BOUNDS.max[3] - SALMON_BOUNDS.min[3]) * 1.25
local RICE_FRONT = -1.35

return function(t: Test.Test)
	---------------------------------------------------------------- 카탈로그·현지화
	t.test(
		"카탈로그: 2종 모두 전설 R$ 199 + 뽑기 전설, 코인·상품 id 없음, order 47~48(맨 끝), 대사 2줄, conceptBody",
		function()
			t.eq(#Skins.LIST, 48)
			t.eq(#Skins.byTier("Legendary"), 14)
			for index, row in NEW do
				local skin = Skins.get(row.id) :: any
				t.ok(skin ~= nil, row.id)
				t.eq(skin.displayName, row.ko, row.id)
				t.eq(skin.tier, "Legendary", row.id)
				t.eq(skin.robux, 199, row.id)
				t.eq(skin.robux, Skins.TIER_ROBUX.Legendary, row.id)
				for _, field in { "coins", "tokens", "season", "vipOnly", "productId" } do
					t.eq(skin[field], nil, `{row.id} {field}`)
				end
				t.eq(skin.order, row.order, row.id)
				t.eq(skin.speech, row.speech, row.id)
				t.eq(Cutscene.SKIN_LINES[row.id], skin.speech, `{row.id} elimination lines`)
				t.eq(skin.conceptBody, true, row.id)
				t.eq(skin.drawGrade, "Legendary", row.id)
				t.eq(Skins.isDraw(row.id), true, row.id)
				t.eq(Skins.isDrawOnly(row.id), false, row.id)
				t.eq(Skins.isFree(row.id), false, row.id)
				t.eq(Skins.LIST[46 + index].id, row.id, `{row.id} after magical-girl-sushi`)
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("현지화: 이름·대사 키의 Source = 카탈로그 한국어, en = 우리 영어", function()
		for _, row in NEW do
			t.ok(LocTest.catalog[`skin.{row.id}.name`] ~= nil, `{row.id} name key`)
			t.eq(LocTest.ko({ key = `skin.{row.id}.name` }), row.ko, row.id)
			t.eq(LocTest.en({ key = `skin.{row.id}.name` }), row.en, row.id)
			for n = 1, 2 do
				local key = `skin.{row.id}.speech.{n}`
				t.ok(LocTest.has(key), key)
				t.eq(LocTest.ko({ key = key }), row.speech[n], key)
				t.eq(LocTest.en({ key = key }), row.speechEn[n], key)
			end
		end
	end)

	---------------------------------------------------------------- 목록·규칙 표
	t.test(
		"목록: 콘셉트 몸·견본·뽑기 목록 17종(특 9 + 전설 8), 뽑기 전용은 특 9종 그대로",
		function()
			for _, list in { Skins.CONCEPT_BODY_IDS, SushiBody.CONCEPT_BODY, Skins.DRAW_IDS } do
				for _, id in NEW_IDS do
					t.ok((list :: any)[id] ~= nil, `{id} in table`)
				end
				t.eq(#keys(list :: any), 17)
			end
			for _, id in NEW_IDS do
				t.ok(table.find(Sample.SKIN_IDS, id) ~= nil, `{id} sample skin ids`)
			end
			t.eq(#Sample.SKIN_IDS, 17)
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

	t.test(
		"규칙 표: 천사 80(용·마법소녀와 같은 상한)·악마 70, 전설 ±25%, 이름표 기본 3.6",
		function()
			for _, row in NEW do
				local rule = SushiBody.CONCEPT_BODY[row.id]
				t.eq(rule.partBudget, row.budget, row.id)
				t.eq(rule.boundsTolerance, SushiBody.BOUNDS_TOLERANCE.Legendary, row.id)
				t.eq(rule.expressions, Sample.EXPRESSIONS, row.id)
				t.eq(rule.nameTagHeight, nil, row.id)
				t.eq(SushiBody.nameTagHeight(row.id), SushiBody.NAME_TAG_HEIGHT, row.id)
			end
			t.eq(SushiBody.NAME_TAG_HEIGHT, 3.6)
		end
	)

	---------------------------------------------------------------- 뽑기
	t.test(
		"뽑기: 전설 등급 8종(order 순), 확률 표 그대로 1/5/15/30/49, 스킨마다 0.125%(화면 0.13%), 균등·중복 🍚 300",
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
			t.ok(math.abs(byGrade.Legendary.chance / #byGrade.Legendary.skinIds - 0.00125) < 1e-12, "0.125% each")
			t.eq(DrawLogic.displayPercents(rows).Legendary, "1.0%")
			local perSkin = DrawLogic.perSkinPercent(rows)
			for _, id in LEGENDARY_DRAW do
				t.eq(perSkin[id], "0.13%", id)
			end
			t.eq(DrawLogic.totalSkins(), 17)
			for _, row in NEW do
				local index = table.find(LEGENDARY_DRAW, row.id) :: number
				local outcome = DrawLogic.roll({}, fakeRng(0.005, index)) :: any
				t.eq(outcome.grade, "Legendary", row.id)
				t.eq(outcome.skinId, row.id)
				t.eq(outcome.kind, "Skin", row.id)
				local dup = DrawLogic.roll({ [row.id] = true }, fakeRng(0.005, index)) :: any
				t.eq(dup.kind, "Duplicate", row.id)
				t.eq(dup.coins, Config.Draw.DuplicateCoins.Legendary, row.id)
				t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), row.id, 1, true), nil, row.id)
				t.eq(string.find(fs.readFile("src/shared/Config.luau"), row.id, 1, true), nil, row.id)
			end
		end
	)

	t.test(
		"뽑기 보유 = 구매 보유: 뽑은 뒤 로벅스 구매는 AlreadyOwned, 산 뒤 뽑기는 중복",
		function()
			for _, row in NEW do
				local index = table.find(LEGENDARY_DRAW, row.id) :: number
				local wallet: any = ProfileSchema.new()
				wallet.drawTickets = 1
				DrawLogic.apply(wallet, DrawLogic.roll(wallet.ownedSkins, fakeRng(0.001, index)) :: any)
				t.eq(wallet.ownedSkins[row.id], true, row.id)
				t.eq(wallet.equippedSkin, "tamago", `{row.id} equip unchanged`)
				local ok, reason = ReceiptLogic.canRequest(row.id, wallet.ownedSkins, { canSave = true, fake = true })
				t.eq(ok, false, row.id)
				t.eq(reason, "AlreadyOwned", row.id)
				t.eq((ShopLogic.canEquip(row.id, wallet.ownedSkins)), true, row.id)
				local bought: any = ProfileSchema.new()
				t.eq(ReceiptLogic.canRequest(row.id, bought.ownedSkins, { canSave = true, fake = true }), true, row.id)
				ShopLogic.grantSkin(bought, row.id, true)
				t.eq((DrawLogic.roll(bought.ownedSkins, fakeRng(0.001, index)) :: any).kind, "Duplicate", row.id)
			end
		end
	)

	---------------------------------------------------------------- 탈의실
	t.test(
		"탈의실: 전설 탭 맨 끝 2장(천사 → 악마), 다른 전설과 같은 로벅스 카드, 뽑기 안내, 🎫 특 탭엔 없음, 코인 불가",
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
			t.eq({ legendary[#legendary - 1].id, legendary[#legendary].id }, NEW_IDS)
			for _, skin in ShopLogic.visibleSkins(view :: any, tab("draw")) do
				t.ok(table.find(NEW_IDS, skin.id) == nil, `{skin.id} not in the special tab`)
			end
			for _, id in NEW_IDS do
				local skin = Skins.get(id) :: any
				local soon = ShopLogic.cardState(skin, view :: any, { fake = false })
				t.eq(soon.kind, "Robux", id)
				t.eq(soon.enabled, false, `{id} no product id yet`)
				t.eq(LocTest.ko(ShopLogic.cardButtonText(soon)), "R$ 199 — 곧 열려요", id)
				t.eq(
					LocTest.ko(ShopLogic.cardButtonText(ShopLogic.cardState(skin, view :: any, { fake = true }))),
					"R$ 199",
					id
				)
				t.eq(LocTest.ko(ShopLogic.drawHint(skin)), "🎫 뽑기 전설에서도 나와요", id)
				t.eq(
					ShopLogic.canBuyWithCoins(id, { coins = 99999, ownedSkins = { tamago = true } } :: any).reason,
					"NotForCoins",
					id
				)
			end
		end
	)

	---------------------------------------------------------------- 모양
	t.test(
		"모양: 표정 6종 모두 파츠 ≤ 상한, 발바닥 = GROUND_OFFSET, 꼭대기 ≤ 이름표 − 0.4, 효과 2개, 겹침·떠 있음 0, 외곽 ±25%",
		function()
			for _, row in NEW do
				t.eq(SushiBody.hasLayout(row.id), true, row.id)
				for _, expression in Sample.EXPRESSIONS do
					local layout = SushiBody.layout(row.id, expression)
					local label = `{row.id}/{expression}`
					t.ok(#layout <= row.budget, `{label} parts {#layout}`)
					local b = SushiBody.bounds(layout)
					t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) < 1e-9, `{label} sole {b.min[2]}`)
					t.ok(b.max[2] <= SushiBody.nameTagHeight(row.id) - 0.4, `{label} top {b.max[2]}`)
					t.ok(b.max[1] - b.min[1] <= MAX_X + 1e-9, `{label} width {b.max[1] - b.min[1]} > {MAX_X}`)
					t.ok(b.max[3] - b.min[3] <= MAX_Z + 1e-9, `{label} depth {b.max[3] - b.min[3]} > {MAX_Z}`)
					local effects = {}
					for _, spec in layout do
						if spec.effect then
							table.insert(effects, spec.effect)
						end
					end
					table.sort(effects)
					t.eq(effects, row.effects, label)
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
		end
	)

	t.test(
		"공유 몸: 밥·받침·팔·다리·얼굴(표정별)은 concept-salmon과 같고, 토핑 파츠 이름은 자기 접두어로만",
		function()
			for _, row in NEW do
				for _, expression in Sample.EXPRESSIONS do
					local mine = byName(SushiBody.layout(row.id, expression))
					local salmon = byName(SushiBody.layout(SALMON, expression))
					local label = `{row.id}/{expression}`
					for name, spec in salmon do
						if isFace(name) or isSharedBody(name) then
							t.eq(mine[name], spec, `{label} {name}`)
						end
					end
					for name in mine do
						if salmon[name] == nil or not (isFace(name) or isSharedBody(name)) then
							t.eq(string.sub(name, 1, #row.prefix), row.prefix, `{label} topping part {name}`)
						end
					end
				end
			end
		end
	)

	t.test(
		"얼굴 안 가림: 토핑은 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면(z −1.35)보다 앞으로 안 나와요",
		function()
			for _, row in NEW do
				for _, expression in Sample.EXPRESSIONS do
					for _, spec in SushiBody.layout(row.id, expression) do
						if not isFace(spec.name) and not isSharedBody(spec.name) then
							local lo, hi = LayoutCheck.box(spec)
							local inFace = hi[1] > -1.4 and lo[1] < 1.4 and hi[2] > -0.8 and lo[2] < 0.76
							t.ok(
								not inFace or lo[3] >= RICE_FRONT - 1e-6,
								`{row.id}/{expression} {spec.name} covers the face (z {lo[3]}, y {lo[2]}..{hi[2]})`
							)
						end
					end
				end
			end
		end
	)

	t.test(
		"천사는 보통 얼굴 그대로(바이저·빨간 눈 없음), 악마는 얼굴 위 검은 바이저 + 빨간 눈 둘(Neon), 바이저에 빨간 Glow",
		function()
			local angel = SushiBody.layout("angel-sushi")
			for _, spec in angel do
				local name = string.lower(spec.name)
				t.eq(string.find(name, "visor", 1, true), nil, spec.name)
				t.eq(
					string.find(spec.name, "Eye", 1, true) ~= nil and string.match(spec.name, "^Angel") ~= nil,
					false,
					spec.name
				)
				local c = spec.color
				local red = c[1] > 200 and c[2] < 90 and c[3] < 110
				t.ok(not red, `{spec.name} red part on the angel`)
			end
			local devil = byName(SushiBody.layout("devil-sushi"))
			local visor = devil.DevilVisor
			t.ok(visor ~= nil, "devil visor")
			t.eq(visor.effect, "Glow")
			local vlo = LayoutCheck.box(visor)
			t.ok(vlo[2] >= 0.76, `visor above the face ({vlo[2]})`)
			for _, name in { "DevilEyeL", "DevilEyeR" } do
				local eye = devil[name]
				t.ok(eye ~= nil, name)
				t.eq(eye.material, "Neon", name)
				t.ok(eye.color[1] > 200 and eye.color[2] < 90, `{name} red`)
				local lo = LayoutCheck.box(eye)
				t.ok(lo[2] >= 0.76, `{name} above the face ({lo[2]})`)
			end
			-- 천사 고리는 머리 위에 떠 있어요 (왕관 꼭대기보다 위)
			local angelMap = byName(angel)
			local crownTop = -math.huge
			for name, spec in angelMap do
				if string.match(name, "^AngelCrown") or string.match(name, "^AngelBand") then
					local _, hi = LayoutCheck.box(spec)
					crownTop = math.max(crownTop, hi[2])
				end
			end
			for k = 1, 8 do
				local lo = LayoutCheck.box(angelMap[`AngelHalo{k}`])
				t.ok(lo[2] > crownTop + 0.1, `halo {k} floats above the crown ({lo[2]} vs {crownTop})`)
			end
		end
	)

	t.test(
		"관절: 공유 몸 8개뿐 — 손에 든 물건은 오른팔(ArmRight)에, 나머지 토핑은 Body에 용접",
		function()
			for _, row in NEW do
				local joints = {}
				local held = 0
				local layout = SushiBody.layout(row.id)
				for _, spec in layout do
					if spec.joint then
						table.insert(joints, spec.name)
					end
					t.eq(spec.pivot, nil, `{row.id} {spec.name} pivot`)
					t.eq(spec.reach, nil, `{row.id} {spec.name} reach`)
					if string.sub(spec.name, 1, #row.held) == row.held then
						held += 1
						t.eq(spec.attach, "ArmRight", `{spec.name} follows the arm`)
					elseif string.sub(spec.name, 1, #row.prefix) == row.prefix then
						t.eq(spec.attach, nil, `{spec.name} welded to Body`)
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
				}, row.id)
				t.ok(held >= 8, `{row.id} held parts {held}`)
				local map = byName(layout)
				local handLo, handHi = LayoutCheck.box(map.ArmRight)
				local lo, hi = LayoutCheck.box(map[row.held])
				for axis = 1, 3 do
					t.ok(
						lo[axis] < handHi[axis] and hi[axis] > handLo[axis],
						`{row.id} shaft meets the hand on axis {axis}`
					)
				end
				t.ok(hi[2] > handHi[2] + 0.6, `{row.id} shaft rises above the hand`)
			end
		end
	)

	t.test(
		"validate가 잡아요: 새 스킨 파츠 상한을 낮추거나 외곽 허용치를 줄이면 거절",
		function()
			for _, id in NEW_IDS do
				local rule = SushiBody.CONCEPT_BODY[id]
				local savedBudget, savedTolerance = rule.partBudget, rule.boundsTolerance
				rule.partBudget = #SushiBody.layout(id) - 1
				local ok, problems = Skins.validate(Skins.LIST)
				rule.partBudget = savedBudget
				t.eq(ok, false, `{id} over budget`)
				t.ok(string.find(table.concat(problems, ";"), "concept body budget", 1, true) ~= nil, id)
				rule.boundsTolerance = 0
				ok, problems = Skins.validate(Skins.LIST)
				rule.boundsTolerance = savedTolerance
				t.eq(ok, false, `{id} bounds`)
				t.ok(string.find(table.concat(problems, ";"), "concept body bounds", 1, true) ~= nil, id)
			end
			t.eq((Skins.validate(Skins.LIST)), true, "restored")
		end
	)

	---------------------------------------------------------------- 코드 규칙
	t.test(
		"스킨 id 분기 없음: 클라이언트·서버 코드에 새 id가 없고, 공유 코드는 카탈로그·규칙 표·견본·공격 연출 표만",
		function()
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.match(name, "%.luau$") then
						local source = fs.readFile(path)
						for _, id in NEW_IDS do
							t.eq(string.find(source, `"{id}"`, 1, true), nil, `{path} mentions {id}`)
						end
					end
				end
			end
			scan("src/client")
			scan("src/server")
			for _, name in fs.readDir("src/shared") do
				local path = `src/shared/{name}`
				if fs.isFile(path) and string.match(name, "%.luau$") then
					local source = fs.readFile(path)
					for _, id in NEW_IDS do
						if string.find(source, `"{id}"`, 1, true) ~= nil then
							t.ok(
								name == "Skins.luau"
									or name == "SushiBody.luau"
									or name == "SushiConceptSample.luau"
									or name == "AttackFxLogic.luau",
								`{path} mentions {id}`
							)
						end
					end
				end
			end
		end
	)

	t.test(
		"일반 디자인: 토핑 모듈·카탈로그·문구에 특정 작품·캐릭터 이름이 없어요",
		function()
			local banned = { "lucifer", "diablo", "hellboy", "maleficent", "mephisto", "cupid", "kirby", "pokemon" }
			for _, path in
				{
					"src/shared/ConceptAngelDevil.luau",
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
