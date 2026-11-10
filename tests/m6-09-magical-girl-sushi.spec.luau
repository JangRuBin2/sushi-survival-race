--!strict
-- m6-09 전설 스킨 "마법소녀 스시" (m6-08 전설 4종·고등어 [신선]과 같은 규칙):
--   카탈로그(전설 R$ 199 + 뽑기 전설, order 46, 대사 2줄, conceptBody)·현지화 행, 콘셉트 몸·뽑기 목록(15종),
--   규칙 표(파츠 80·외곽 ±25%·이름표 기본 3.6), 뽑기 전설 등급 6종 균등·중복 코인, 탈의실 카드·뽑기 안내,
--   모양 한도(표정 6종: 파츠·발바닥·꼭대기·효과 2개·겹침·떠 있음·외곽·얼굴 안 가림·공유 몸 그대로·관절 8개),
--   지팡이는 오른팔(ArmRight)에 붙어 팔 흔들기를 따라가요, 스킨 id 분기 없음, 독창 디자인(특정 작품 이름·표식 없음).

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

local ID = "magical-girl-sushi"
local KO = "마법소녀 스시"
local EN = "Magical Girl Sushi"
local SPEECH = { "변신 중엔 먹으면 반칙이야~!", "별빛 지팡이보다 젓가락이 빨랐어…!" }
local SPEECH_EN = { "No eating mid-transformation, that's cheating~!", "The chopsticks beat my starlight wand…!" }
local PREFIX = "Magic"
local BUDGET = 80
local SALMON = "concept-salmon"
local LEGENDARY_DRAW = {
	"fresh-mackerel",
	"dragon-sushi",
	"sky-dragon-sushi",
	"jet-sushi",
	"shadow-jet-sushi",
	ID,
	-- m6-10 천사·악마가 뒤에 붙었어요 (tests/m6-10-angel-devil-sushi)
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
		"카탈로그: 전설 R$ 199 + 뽑기 전설, 코인·상품 id 없음, order 46(섀도 제트 다음), 대사 2줄, conceptBody",
		function()
			t.eq(#Skins.LIST, 48) -- m6-10 천사·악마(47~48) 포함
			local skin = Skins.get(ID) :: any
			t.ok(skin ~= nil, ID)
			t.eq(skin.displayName, KO)
			t.eq(skin.tier, "Legendary")
			t.eq(skin.robux, 199)
			t.eq(skin.robux, Skins.TIER_ROBUX.Legendary)
			t.eq(skin.coins, nil)
			t.eq(skin.tokens, nil)
			t.eq(skin.season, nil)
			t.eq(skin.vipOnly, nil)
			t.eq(skin.productId, nil, "product id is set by the user later")
			t.eq(skin.order, 46)
			t.eq(skin.speech, SPEECH)
			t.eq(Cutscene.SKIN_LINES[ID], skin.speech, "elimination lines")
			t.eq(skin.conceptBody, true)
			t.eq(skin.drawGrade, "Legendary")
			t.eq(Skins.isDraw(ID), true)
			t.eq(Skins.isDrawOnly(ID), false)
			t.eq(Skins.isFree(ID), false)
			t.eq(Skins.LIST[46].id, ID, "after shadow-jet-sushi")
			t.eq(Skins.LIST[45].id, "shadow-jet-sushi")
			t.eq(#Skins.byTier("Legendary"), 14)
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
		"목록: 콘셉트 몸·견본·뽑기 목록에 들어가요 (m6-10 뒤 17종), 뽑기 전용은 특 9종 그대로",
		function()
			for _, list in { Skins.CONCEPT_BODY_IDS, SushiBody.CONCEPT_BODY, Skins.DRAW_IDS } do
				t.ok((list :: any)[ID] ~= nil, "in table")
				t.eq(#keys(list :: any), 17)
			end
			t.ok(table.find(Sample.SKIN_IDS, ID) ~= nil, "sample skin ids")
			t.eq(#Sample.SKIN_IDS, 17)
			t.eq(keys(Skins.CONCEPT_BODY_IDS), sorted(Sample.SKIN_IDS))
			local drawOnly = 0
			for _, skin in Skins.LIST do
				if Skins.isDrawOnly(skin.id) then
					drawOnly += 1
				end
			end
			t.eq(drawOnly, 9)
		end
	)

	t.test("규칙 표: 파츠 80(용 둘·고등어와 같은 상한), 전설 ±25%, 이름표 기본 3.6", function()
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
		"뽑기: 전설 등급 8종(order 순, m6-10 뒤), 확률 표 그대로 1%, 스킨마다 0.125%(화면 0.13%), 전설 안에서 균등·중복 🍚 300",
		function()
			local rows = DrawLogic.grades()
			local byGrade = {}
			for _, row in rows do
				byGrade[row.grade] = row
			end
			t.eq(byGrade.Legendary.skinIds, LEGENDARY_DRAW)
			t.ok(math.abs(byGrade.Legendary.chance - 0.01) < 1e-9, "legendary 1%")
			t.eq(DrawLogic.displayPercents(rows).Legendary, "1.0%")
			local perSkin = DrawLogic.perSkinPercent(rows)
			for _, id in LEGENDARY_DRAW do
				t.eq(perSkin[id], "0.13%", id)
			end
			t.eq(DrawLogic.totalSkins(), 17)
			local index = table.find(LEGENDARY_DRAW, ID) :: number
			local outcome = DrawLogic.roll({}, fakeRng(0.005, index)) :: any
			t.eq(outcome.grade, "Legendary")
			t.eq(outcome.skinId, ID)
			t.eq(outcome.kind, "Skin")
			local dup = DrawLogic.roll({ [ID] = true }, fakeRng(0.005, index)) :: any
			t.eq(dup.kind, "Duplicate")
			t.eq(dup.coins, Config.Draw.DuplicateCoins.Legendary)
			t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), ID, 1, true), nil)
			t.eq(string.find(fs.readFile("src/shared/Config.luau"), ID, 1, true), nil)
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
		"탈의실: 전설 탭 끝(m6-10 천사·악마 앞), 다른 전설과 같은 로벅스 카드, 뽑기 안내, 🎫 특 탭엔 없음, 코인 불가",
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
			t.eq(legendary[#legendary - 2].id, ID) -- 뒤에 m6-10 천사·악마
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

	---------------------------------------------------------------- 모양
	t.test(
		"모양: 표정 6종 모두 파츠 ≤ 80, 발바닥 = GROUND_OFFSET, 꼭대기 ≤ 이름표 − 0.4, Glow + Sparkles, 겹침·떠 있음 0, 외곽 ±25%",
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
				t.eq(effects, { "Glow", "Sparkles" }, label)
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
		"공유 몸: 밥·받침·팔·다리·얼굴(표정별)은 concept-salmon과 같고, 토핑 파츠 이름은 Magic으로만",
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
		"얼굴 안 가림: 머리·하트·지팡이는 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면(z −1.35)보다 앞으로 안 나와요",
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
			-- 하트 브로치는 얼굴 아래 (위끝 < −0.8), 가운데 앞
			local heart = byName(SushiBody.layout(ID)).MagicHeart
			local lo, hi = LayoutCheck.box(heart)
			t.ok(hi[2] < -0.8 and lo[3] < RICE_FRONT, `heart below the face, in front ({lo[2]}..{hi[2]})`)
		end
	)

	t.test(
		"관절: 공유 몸 8개뿐 — 지팡이 파츠는 오른팔(ArmRight)에, 나머지 토핑은 Body에 용접",
		function()
			local joints = {}
			local wand = 0
			for _, spec in SushiBody.layout(ID) do
				if spec.joint then
					table.insert(joints, spec.name)
				end
				t.eq(spec.pivot, nil, `{spec.name} pivot`)
				t.eq(spec.reach, nil, `{spec.name} reach`)
				if string.match(spec.name, "^MagicWand") then
					wand += 1
					t.eq(spec.attach, "ArmRight", `{spec.name} follows the arm`)
					t.eq(spec.joint, nil, spec.name)
				elseif string.match(spec.name, "^Magic") then
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
			})
			t.ok(wand >= 12, `wand parts {wand}`) -- 손잡이 + 별(원판 + 끝 10) + 날개 2
			-- 지팡이 손잡이가 오른손을 지나요 (손에 쥐어요)
			local layout = byName(SushiBody.layout(ID))
			local handLo, handHi = LayoutCheck.box(layout.ArmRight)
			local lo, hi = LayoutCheck.box(layout.MagicWandHandle)
			for axis = 1, 3 do
				t.ok(lo[axis] < handHi[axis] and hi[axis] > handLo[axis], `handle meets the hand on axis {axis}`)
			end
			t.ok(hi[2] > handHi[2] + 0.6, "handle rises above the hand")
		end
	)

	t.test("validate가 잡아요: 파츠 상한을 낮추거나 외곽 허용치를 줄이면 거절", function()
		local rule = SushiBody.CONCEPT_BODY[ID]
		local savedBudget, savedTolerance = rule.partBudget, rule.boundsTolerance
		rule.partBudget = #SushiBody.layout(ID) - 1
		local ok, problems = Skins.validate(Skins.LIST)
		rule.partBudget = savedBudget
		t.eq(ok, false, "over budget")
		t.ok(string.find(table.concat(problems, ";"), "concept body budget", 1, true) ~= nil, "budget problem")
		rule.boundsTolerance = 0
		ok, problems = Skins.validate(Skins.LIST)
		rule.boundsTolerance = savedTolerance
		t.eq(ok, false, "bounds")
		t.ok(string.find(table.concat(problems, ";"), "concept body bounds", 1, true) ~= nil, "bounds problem")
		t.eq((Skins.validate(Skins.LIST)), true, "restored")
	end)

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
		end
	)

	t.test(
		"독창 디자인: 토핑 모듈·카탈로그·문구·작업 기록에 특정 작품 이름이 없어요",
		function()
			local banned = {
				"sailor",
				"usagi",
				"tsukino",
				"moon prism",
				"moon stick",
				"moon tiara",
				"crescent",
				"odango",
				"세일러",
				"우사기",
				"문 프리즘",
				"초승달",
				"당고",
				"티아라",
			}
			for _, path in
				{
					"src/shared/ConceptMagicalGirl.luau",
					"src/shared/Skins.luau",
					"src/shared/Localization/Strings.csv",
				}
			do
				local source = string.lower(fs.readFile(path))
				for _, word in banned do
					t.eq(string.find(source, word, 1, true), nil, `{path} has {word}`)
				end
			end
			-- 모양 자체도: 이마 장식·달 모양 파츠가 없어요 (파츠 이름)
			for _, spec in SushiBody.layout(ID) do
				local name = string.lower(spec.name)
				for _, word in { "tiara", "moon", "crescent", "collar", "skirt", "bun" } do
					t.eq(string.find(name, word, 1, true), nil, `{spec.name} has {word}`)
				end
			end
		end
	)
end
