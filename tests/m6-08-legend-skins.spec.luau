--!strict
-- m6-08 전설 스킨 4종 "드래곤 스시"·"용 스시"·"제트기 스시"·"섀도 제트 스시" (고등어 [신선] m5-32와 같은 규칙):
--   카탈로그(전설 R$ 199 + 뽑기 전설, order 42~45, 대사 2줄, conceptBody)·현지화 행, 콘셉트 몸·뽑기 목록,
--   규칙 표(파츠 상한·외곽 ±25%·이름표), 뽑기 전설 등급 안 균등·중복 코인, 탈의실 카드·뽑기 안내,
--   모양 한도(표정 6종: 파츠·발바닥·꼭대기·효과 2개·겹침·떠 있음·외곽·얼굴 안 가림·공유 몸 그대로·관절 8개),
--   스킨 id 분기 없음(클라이언트·서버 코드에 id 없음), 독창 디자인(특정 작품 이름 없음).

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

local SALMON = "concept-salmon"
local MACKEREL = "fresh-mackerel"

-- id, 한국어 이름, 영어 이름, 대사, 영어 대사, order, 파츠 상한, 효과(정렬), 토핑 파츠 이름 접두어
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
}
local NEW: { Row } = {
	{
		id = "dragon-sushi",
		ko = "드래곤 스시",
		en = "Dragon Sushi",
		speech = { "앗 뜨거! 내 불꽃이 꺼졌어…", "전설의 드래곤도 한입이라니!" },
		speechEn = { "Ouch, hot! My flame went out…", "A legendary dragon in one bite?!" },
		order = 42,
		budget = 80,
		effects = { "Fire", "Glow" },
		prefix = "Dragon",
	},
	{
		id = "sky-dragon-sushi",
		ko = "용 스시",
		en = "Sky Dragon Sushi",
		speech = { "구름 타고 도망가려 했는데~", "하늘의 용도 맛있었구나!" },
		speechEn = { "I tried to float away on a cloud~", "So sky dragons are tasty too!" },
		order = 43,
		budget = 80,
		effects = { "Glow", "Sparkles" },
		prefix = "Sky",
	},
	{
		id = "jet-sushi",
		ko = "제트기 스시",
		en = "Jet Sushi",
		speech = { "비상 탈출 버튼 어디 있어?!", "음속보다 빨리 먹혔어!" },
		speechEn = { "Where's the eject button?!", "Eaten faster than the speed of sound!" },
		order = 44,
		budget = 70,
		effects = { "Glow", "Smoke" },
		prefix = "Jet",
	},
	{
		id = "shadow-jet-sushi",
		ko = "섀도 제트 스시",
		en = "Shadow Jet Sushi",
		speech = { "크윽… 내 계획이 들켰다니!", "다음엔 그림자처럼 사라질 거야~" },
		speechEn = { "Ugh… my plan was found out!", "Next time I'll vanish like a shadow~" },
		order = 45,
		budget = 70,
		effects = { "Glow", "Smoke" },
		prefix = "Jet",
	},
}
local NEW_IDS = {}
for _, row in NEW do
	table.insert(NEW_IDS, row.id)
end
local SPECIAL = {
	"concept-salmon",
	"concept-tuna",
	"concept-shrimp",
	"concept-tamago",
	"concept-ikura",
	"concept-unagi",
	"concept-uni",
	"concept-tako",
	"concept-inari",
}
-- 뽑기 전설 등급 (order 순): 고등어 + 이 4종 + m6-09 마법소녀 + m6-10 천사·악마
-- (tests/m6-09-magical-girl-sushi, tests/m6-10-angel-devil-sushi)
local LATER_LEGENDS = { "magical-girl-sushi", "angel-sushi", "devil-sushi" }
local LEGENDARY_DRAW = { MACKEREL, "dragon-sushi", "sky-dragon-sushi", "jet-sushi", "shadow-jet-sushi" }
for _, id in LATER_LEGENDS do
	table.insert(LEGENDARY_DRAW, id)
end

-- 얼굴·공유 몸 파츠 (콘셉트 연어와 같아야 해요)
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
		"카탈로그: 4종 모두 전설 R$ 199 + 뽑기 전설, 코인·상품 id 없음, order 42~45, 대사 2줄, conceptBody",
		function()
			t.eq(#Skins.LIST, 48) -- m6-09 마법소녀(order 46)·m6-10 천사·악마(47~48)가 뒤에 붙었어요
			for index, row in NEW do
				local skin = Skins.get(row.id) :: any
				t.ok(skin ~= nil, row.id)
				t.eq(skin.displayName, row.ko, row.id)
				t.eq(skin.tier, "Legendary", row.id)
				t.eq(skin.robux, 199, row.id)
				t.eq(skin.robux, Skins.TIER_ROBUX.Legendary, row.id)
				t.eq(skin.coins, nil, row.id)
				t.eq(skin.tokens, nil, row.id)
				t.eq(skin.season, nil, row.id)
				t.eq(skin.vipOnly, nil, row.id)
				t.eq(skin.productId, nil, `{row.id} product id is set by the user later`)
				t.eq(skin.order, row.order, row.id)
				t.eq(skin.speech, row.speech, row.id)
				t.eq(Cutscene.SKIN_LINES[row.id], skin.speech, `{row.id} elimination lines`)
				t.eq(skin.conceptBody, true, row.id)
				t.eq(skin.drawGrade, "Legendary", row.id)
				t.eq(Skins.isDraw(row.id), true, row.id)
				t.eq(Skins.isDrawOnly(row.id), false, row.id)
				t.eq(Skins.isFree(row.id), false, row.id)
				t.eq(Skins.LIST[41 + index].id, row.id, `{row.id} after fresh-mackerel in order`)
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("현지화: 이름·대사 키의 Source = 카탈로그 한국어, en = 우리 영어", function()
		for _, row in NEW do
			local name = LocTest.catalog[`skin.{row.id}.name`]
			t.ok(name ~= nil, `{row.id} name key`)
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
		"목록: 콘셉트 몸 17종 = 세 목록, 뽑기 17종(특 9 + 전설 8, m6-09 +1·m6-10 +2), 뽑기 전용은 특 9종 그대로",
		function()
			local concept = sorted({
				"concept-salmon",
				"concept-tuna",
				"concept-shrimp",
				"concept-tamago",
				"concept-ikura",
				"concept-unagi",
				"concept-uni",
				"concept-tako",
				"concept-inari",
				MACKEREL,
				"dragon-sushi",
				"sky-dragon-sushi",
				"jet-sushi",
				"shadow-jet-sushi",
				"magical-girl-sushi", -- m6-09
				"angel-sushi", -- m6-10
				"devil-sushi",
			})
			t.eq(keys(Skins.CONCEPT_BODY_IDS), concept)
			t.eq(keys(SushiBody.CONCEPT_BODY), concept)
			t.eq(sorted(Sample.SKIN_IDS), concept)
			t.eq(keys(Skins.DRAW_IDS), concept) -- 지금은 같은 목록이지만 뜻이 달라요 (명시 목록 비교)
			local drawOnly = {}
			for _, skin in Skins.LIST do
				if Skins.isDrawOnly(skin.id) then
					table.insert(drawOnly, skin.id)
				end
			end
			t.eq(sorted(drawOnly), sorted(SPECIAL))
		end
	)

	t.test(
		"규칙 표: 용 둘은 파츠 80(고등어와 같은 예외), 제트기 둘은 70, 모두 전설 ±25%·이름표 기본 3.6",
		function()
			for _, row in NEW do
				local rule = SushiBody.CONCEPT_BODY[row.id]
				t.eq(rule.partBudget, row.budget, row.id)
				t.eq(rule.boundsTolerance, SushiBody.BOUNDS_TOLERANCE.Legendary, row.id)
				t.eq(rule.expressions, Sample.EXPRESSIONS, row.id)
				t.eq(rule.nameTagHeight, nil, row.id)
				t.eq(SushiBody.nameTagHeight(row.id), SushiBody.NAME_TAG_HEIGHT, row.id)
				-- 이름표가 기본이라 build가 Body에 높이 속성을 달지 않아요
			end
			t.eq(SushiBody.NAME_TAG_HEIGHT, 3.6)
		end
	)

	---------------------------------------------------------------- 뽑기
	t.test(
		"뽑기: 전설 등급 = 고등어 + 새 4종 + 마법소녀·천사·악마(order 순), 확률 표는 그대로 1/5/15/30/49, 전설 안에서 균등",
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
			t.eq(DrawLogic.displayPercents(rows).Legendary, "1.0%")
			local perSkin = DrawLogic.perSkinPercent(rows)
			for _, id in LEGENDARY_DRAW do
				t.eq(perSkin[id], "0.13%", id) -- 전설 1% ÷ 8종 = 0.125% (m6-10 뒤, 화면은 반올림)
			end
			t.eq(DrawLogic.totalSkins(), 17)
			-- 전설 안에서 NextInteger(1, 8)가 고른 순서 그대로
			for index, id in LEGENDARY_DRAW do
				local outcome = DrawLogic.roll({}, fakeRng(0.005, index)) :: any
				t.eq(outcome.grade, "Legendary", id)
				t.eq(outcome.skinId, id)
				t.eq(outcome.kind, "Skin", id)
			end
			t.eq((DrawLogic.roll({}, fakeRng(0.01, 1)) :: any).grade, "Epic")
			-- 이미 가진 새 스킨이 나오면 🍚 300 (전설 중복)
			for _, row in NEW do
				local index = table.find(LEGENDARY_DRAW, row.id) :: number
				local dup = DrawLogic.roll({ [row.id] = true }, fakeRng(0.005, index)) :: any
				t.eq(dup.kind, "Duplicate", row.id)
				t.eq(dup.coins, Config.Draw.DuplicateCoins.Legendary, row.id)
			end
			t.eq(Config.Draw.DuplicateCoins.Legendary, 300)
			-- 대표(featured): 전설 첫 스킨부터 안 가진 것
			t.eq(DrawLogic.featured({}), MACKEREL)
			t.eq(DrawLogic.featured({ [MACKEREL] = true }), "dragon-sushi")
			-- DrawLogic·Config.Draw는 카탈로그만으로 바뀌어요 (코드에 새 id 없음)
			for _, id in NEW_IDS do
				t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), id, 1, true), nil, id)
				t.eq(string.find(fs.readFile("src/shared/Config.luau"), id, 1, true), nil, id)
			end
		end
	)

	t.test(
		"뽑기 보유 = 구매 보유: 뽑은 뒤 로벅스 구매는 AlreadyOwned, 산 뒤 뽑기는 중복",
		function()
			for index, id in LEGENDARY_DRAW do
				if id == MACKEREL then
					continue
				end
				local wallet: any = ProfileSchema.new()
				wallet.drawTickets = 1
				DrawLogic.apply(wallet, DrawLogic.roll(wallet.ownedSkins, fakeRng(0.001, index)) :: any)
				t.eq(wallet.ownedSkins[id], true, id)
				t.eq(wallet.equippedSkin, "tamago", `{id} equip unchanged`)
				local ok, reason = ReceiptLogic.canRequest(id, wallet.ownedSkins, { canSave = true, fake = true })
				t.eq(ok, false, id)
				t.eq(reason, "AlreadyOwned", id)
				t.eq((ShopLogic.canEquip(id, wallet.ownedSkins)), true, id)
				local bought: any = ProfileSchema.new()
				t.eq(ReceiptLogic.canRequest(id, bought.ownedSkins, { canSave = true, fake = true }), true, id)
				ShopLogic.grantSkin(bought, id, true)
				t.eq((DrawLogic.roll(bought.ownedSkins, fakeRng(0.001, index)) :: any).kind, "Duplicate", id)
			end
		end
	)

	---------------------------------------------------------------- 탈의실
	t.test(
		"탈의실: 전설 탭 끝 4장(고등어 뒤, m6-09·m6-10 전설 앞), 다른 전설과 같은 로벅스 카드, 뽑기 안내, 🎫 특 탭엔 없음, 코인 불가",
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
			local tail = {}
			for i = #legendary - 7, #legendary do
				table.insert(tail, legendary[i].id)
			end
			t.eq(tail, LEGENDARY_DRAW)
			for _, skin in ShopLogic.visibleSkins(view :: any, tab("draw")) do
				t.ok(table.find(NEW_IDS, skin.id) == nil, `{skin.id} not in the special tab`)
			end
			local golden = Skins.get("golden-otoro") :: any
			for _, id in NEW_IDS do
				local skin = Skins.get(id) :: any
				local soon = ShopLogic.cardState(skin, view :: any, { fake = false })
				t.eq(soon.kind, ShopLogic.cardState(golden, view :: any, { fake = false }).kind, id)
				t.eq(soon.kind, "Robux", id)
				t.eq(soon.enabled, false, `{id} no product id yet`)
				t.eq(LocTest.ko(ShopLogic.cardButtonText(soon)), "R$ 199 — 곧 열려요", id)
				t.eq(
					LocTest.ko(ShopLogic.cardButtonText(ShopLogic.cardState(skin, view :: any, { fake = true }))),
					"R$ 199"
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
		"관절: 공유 몸 8개(눈 2·감은 눈 2·팔 2·발 2)뿐 — 토핑은 모두 용접 (움직임 판정 무관)",
		function()
			for _, row in NEW do
				local joints = {}
				for _, spec in SushiBody.layout(row.id) do
					if spec.joint then
						table.insert(joints, spec.name)
					end
					t.eq(spec.pivot, nil, `{row.id} {spec.name} pivot`)
					t.eq(spec.reach, nil, `{row.id} {spec.name} reach`)
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
		"스킨 id 분기 없음: 클라이언트·서버 코드에 새 스킨 id가 없어요 (카탈로그·규칙 표·견본만)",
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
			-- 공유 코드에서 새 id를 쓰는 곳은 카탈로그·콘셉트 몸 표·견본 토핑 표, 그리고 공격 연출 표
			-- (AttackFxLogic.STYLE_BY_SKIN — m6-08 공격 연출의 유일한 스킨 → 연출 연결, docs/REFERENCE-attack-fx.md)
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

	t.test("독창 디자인: 토핑 모듈·카탈로그·문구에 특정 작품 이름이 없어요", function()
		local banned = { "megatron", "transformer", "decepticon", "autobot", "toothless", "shenron" }
		for _, path in
			{
				"src/shared/ConceptDragon.luau",
				"src/shared/ConceptJet.luau",
				"src/shared/Skins.luau",
				"src/shared/Localization/Strings.csv",
			}
		do
			local source = string.lower(fs.readFile(path))
			for _, word in banned do
				t.eq(string.find(source, word, 1, true), nil, `{path} has {word}`)
			end
		end
	end)
end
