--!strict
-- m5-32 전설 스킨 "고등어 초밥 [신선]" (docs/specs/m5-32-fresh-mackerel.md AC1~AC9):
--   카탈로그·뽑기 전설(1%)·구매 보유 = 뽑기 보유, 콘셉트 몸 예외 이름(conceptBody), validate가 잡는 것(가짜 레이아웃),
--   모양 한도(표정 6종 × 대표 자세 + 촘촘한 움직임 표본), 공유 부분·다른 스킨 레이아웃 스냅숏(바이트 단위),
--   관절 사슬(진짜 Instance build), 팔딱 움직임 값·진동수·연속성, 팔딱 간격, 스킨 id 분기 없음(DollAnimator 가짜 Roblox),
--   3차 결정(파츠 80·화남/슬픔 표정·FishFlop/FishSplash 소리).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local LayoutSnapshot = require("./lib/LayoutSnapshot")
local LayoutCheck = require("../tools/render/LayoutCheck")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local SushiPose = RobloxRequire.require(Shared.SushiPose)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)
local DrawLogic = RobloxRequire.require(Shared.DrawLogic)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)

local ID = "fresh-mackerel"
local SALMON = "concept-salmon"
local F = Anim.FISH
local DEG = math.pi / 180
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

local function near(t: Test.Test, a: number, b: number, eps: number, message: string)
	t.ok(math.abs(a - b) <= eps, `{message}: {a} vs {b}`)
end

local function isFishPart(name: string): boolean
	return string.sub(name, 1, 4) == "Fish" or string.sub(name, 1, 6) == "Splash"
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

-- 1/60초 간격으로 입력을 바꿔 가며 fishPose를 부르는 시뮬레이션 (섞기 포함, 클라이언트와 같은 순서)
local function simulate(frames: { any }): ({ any }, { any })
	local blend = nil
	local out, blends = {}, {}
	for _, input in frames do
		blend = Anim.fishBlend(blend, input, 1 / 60)
		local copy = table.clone(input)
		copy.blend = blend
		table.insert(out, Anim.fishPose(copy))
		table.insert(blends, blend)
	end
	return out, blends
end

local function standing(time: number, overrides: { [string]: any }?): any
	local input: any = {
		time = time,
		walk = 0,
		phase = 0,
		riseSpeed = 0,
		airborne = false,
		landTime = nil,
		landStrength = 0,
		knocked = false,
		flopTime = nil,
		mode = "Character",
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

-- 대표 자세 + 촘촘한 표본 (팔딱·착지·점프·넘어짐·달리기·Hurt 경련)
local function sampledPoses(): { { name: string, pose: any } }
	local list = {}
	for _, item in Anim.fishTestPoses() do
		table.insert(list, item)
	end
	local step = 1 / 30
	local t = 0
	while t < 0.6 do
		table.insert(list, { name = `flop {t}`, pose = Anim.fishPose(standing(t, { flopTime = t })) })
		table.insert(list, { name = `land {t}`, pose = Anim.fishPose(standing(t, { landTime = t, landStrength = 1 })) })
		table.insert(list, { name = `knock {t}`, pose = Anim.fishPose(standing(t, { knocked = true })) })
		table.insert(list, {
			name = `hurt {t}`,
			pose = Anim.fishPose(standing(t, { flopTime = math.min(t, 0.29), mode = "Hurt" })),
		})
		table.insert(list, {
			name = `run {t}`,
			pose = Anim.fishPose(standing(t, { walk = 1.3, phase = t * 15.5 })),
		})
		t += step
	end
	for _, rise in { 5, 15, 30, 60 } do
		table.insert(
			list,
			{ name = `jump {rise}`, pose = Anim.fishPose(standing(0, { airborne = true, riseSpeed = rise })) }
		)
	end
	return list
end

local function posedLayouts(expression: string): { { name: string, layout: { any }, pose: any } }
	local base = SushiBody.layout(ID, expression)
	local out = {}
	for _, item in sampledPoses() do
		table.insert(
			out,
			{ name = item.name, layout = SushiPose.posed(base, Anim.fishMotion(item.pose)), pose = item.pose }
		)
	end
	return out
end

local function partsWithout(layout: { any }, prefix: string): { any }
	local list = {}
	for _, spec in layout do
		if string.sub(spec.name, 1, #prefix) ~= prefix then
			table.insert(list, spec)
		end
	end
	return list
end

-- 자세마다 고등어 파츠가 지켜야 하는 것 (AC4)
local SALMON_BOUNDS = SushiBody.bounds(SushiBody.layout(SALMON))
local MAX_X = (SALMON_BOUNDS.max[1] - SALMON_BOUNDS.min[1]) * 1.25
local MAX_Z = (SALMON_BOUNDS.max[3] - SALMON_BOUNDS.min[3]) * 1.25
local RICE_TOP = 1.0
local RICE_FRONT = -1.35

return function(t: Test.Test)
	---------------------------------------------------------------- AC1 카탈로그
	t.test(
		"AC1: 카탈로그 — 고등어 초밥 [신선], 전설 R$ 199, 코인 없음, order 41, 대사 2줄, conceptBody, 뽑기 전설",
		function()
			local skin = Skins.get(ID) :: any
			t.ok(skin ~= nil, "in catalog")
			t.eq(skin.displayName, "고등어 초밥 [신선]")
			t.eq(skin.tier, "Legendary")
			t.eq(skin.robux, 199)
			t.eq(skin.coins, nil)
			t.eq(skin.productId, nil) -- 사용자가 상품을 만든 뒤 (USER-TODO C3)
			t.eq(skin.order, 41)
			t.eq(skin.speech, { "아직 팔딱팔딱 살아 있다고!", "오늘 아침에 잡힌 몸이야~" })
			t.eq(Cutscene.SKIN_LINES[ID], skin.speech, "elimination lines")
			t.eq(skin.conceptBody, true)
			t.eq(skin.drawGrade, "Legendary")
			t.eq(#Skins.LIST, 41)
			t.eq(Skins.LIST[#Skins.LIST].id, ID, "last in the catalog")
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
			t.eq(Skins.isDraw(ID), true)
			t.eq(Skins.isDrawOnly(ID), false)
			t.eq(Skins.isFree(ID), false)
			t.eq(SushiBody.EFFECT_BUDGET.Legendary, 2)
			t.eq(SushiBody.effectCount(SushiBody.layout(ID)), 1, "one effect (tail Sparkles)")
		end
	)

	t.test(
		"AC1: 탈의실 — 전설 탭 맨 끝(다른 전설과 같은 카드), 🎫 특 탭에는 없음, 코인 해금 거절, 뽑기 안내",
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
			t.eq(legendary[#legendary].id, ID, "legendary tab last")
			for _, skin in ShopLogic.visibleSkins(view :: any, tab("draw")) do
				t.ok(skin.id ~= ID, "not in the special tab")
			end
			local skin = Skins.get(ID) :: any
			local golden = Skins.get("golden-otoro") :: any
			local soon = ShopLogic.cardState(skin, view :: any, { fake = false })
			t.eq(
				soon.kind,
				ShopLogic.cardState(golden, view :: any, { fake = false }).kind,
				"same card as other legendary"
			)
			t.eq(soon.kind, "Robux")
			t.eq(soon.enabled, false, "no product id yet")
			t.eq(ShopLogic.cardButtonText(soon), "R$ 199 — 곧 열려요")
			local fake = ShopLogic.cardState(skin, view :: any, { fake = true })
			t.eq(fake.kind, "Robux")
			t.eq(ShopLogic.cardButtonText(fake), "R$ 199")
			t.eq(
				ShopLogic.canBuyWithCoins(ID, { coins = 99999, ownedSkins = { tamago = true } } :: any).reason,
				"NotForCoins"
			)
			t.eq(ShopLogic.drawHint(skin), "🎫 뽑기 전설에서도 나와요")
			t.eq(ShopLogic.drawHint(golden), nil)
			t.eq(ShopLogic.drawHint(Skins.get("concept-salmon") :: any), nil, "draw-only skins have no hint")
			t.ok(string.find(fs.readFile("src/client/ui/ShopScreen.luau"), "ShopLogic.drawHint(skin)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- AC2 예외 이름
	t.test(
		"AC2: experimental 식별자가 남지 않고, 콘셉트 몸 10종 = 세 목록, 뽑기 10종 / 뽑기 전용 9종 (명시 목록)",
		function()
			local function scan(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if fs.isDir(path) then
						scan(path)
					elseif string.match(name, "%.luau$") and name ~= "m5-32-fresh-mackerel.spec.luau" then
						local source = string.lower(fs.readFile(path))
						t.ok(string.find(source, "experimental", 1, true) == nil, `{path} has 'experimental'`)
					end
				end
			end
			for _, dir in { "src", "tests", "tools" } do
				scan(dir)
			end
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
				ID,
			})
			t.eq(keys(Skins.CONCEPT_BODY_IDS), concept)
			t.eq(keys(SushiBody.CONCEPT_BODY), concept)
			t.eq(sorted(Sample.SKIN_IDS), concept)
			local draw = sorted({
				"concept-salmon",
				"concept-tuna",
				"concept-shrimp",
				"concept-tamago",
				"concept-ikura",
				"concept-unagi",
				"concept-uni",
				"concept-tako",
				"concept-inari",
				ID,
			})
			t.eq(keys(Skins.DRAW_IDS), draw)
			local drawOnly = {}
			for _, skin in Skins.LIST do
				if Skins.isDrawOnly(skin.id) then
					table.insert(drawOnly, skin.id)
				end
			end
			t.eq(sorted(drawOnly), sorted(SPECIAL))
			-- 규칙 표: 특 9종 70·외곽 비교 없음, 고등어 80·전설 ±25% (concept-salmon 기준)
			for _, id in SPECIAL do
				t.eq(SushiBody.CONCEPT_BODY[id].partBudget, 70, id)
				t.eq(SushiBody.CONCEPT_BODY[id].boundsTolerance, nil, id)
			end
			t.eq(SushiBody.CONCEPT_BODY[ID].partBudget, 80)
			t.eq(SushiBody.CONCEPT_BODY[ID].boundsTolerance, SushiBody.BOUNDS_TOLERANCE.Legendary)
			t.eq(SushiBody.CONCEPT_BOUNDS_BASE, SALMON)
		end
	)

	---------------------------------------------------------------- AC2-1 뽑기 전설
	t.test(
		"AC2-1: DrawLogic — 전설 = 고등어 1%, 영웅 5·희귀 15·고급 30·일반 49, 표시 1.0~49.0, 경계·중복·대표",
		function()
			local rows = DrawLogic.grades()
			local byGrade = {}
			for _, row in rows do
				byGrade[row.grade] = row
			end
			t.eq(byGrade.Legendary.skinIds, { ID })
			near(t, byGrade.Legendary.chance, 0.01, 1e-9, "Legendary")
			near(t, byGrade.Epic.chance, 0.05, 1e-9, "Epic")
			near(t, byGrade.Rare.chance, 0.15, 1e-9, "Rare")
			near(t, byGrade.Uncommon.chance, 0.30, 1e-9, "Uncommon")
			near(t, byGrade.Common.chance, 0.49, 1e-9, "Common")
			t.eq(DrawLogic.displayPercents(rows), {
				Legendary = "1.0%",
				Epic = "5.0%",
				Rare = "15.0%",
				Uncommon = "30.0%",
				Common = "49.0%",
			})
			t.eq(DrawLogic.perSkinPercent(rows)[ID], "1.00%")
			t.eq((DrawLogic.roll({}, fakeRng(0.0099)) :: any).skinId, ID)
			t.eq((DrawLogic.roll({}, fakeRng(0.0099)) :: any).grade, "Legendary")
			t.eq((DrawLogic.roll({}, fakeRng(0.01)) :: any).grade, "Epic")
			local fresh = DrawLogic.roll({}, fakeRng(0.005)) :: any
			t.eq(fresh.kind, "Skin")
			local dup = DrawLogic.roll({ [ID] = true }, fakeRng(0.005)) :: any
			t.eq(dup.kind, "Duplicate")
			t.eq(dup.coins, 300)
			t.eq(Config.Draw.DuplicateCoins.Legendary, 300)
			t.eq(DrawLogic.featured({}), ID)
			t.eq(DrawLogic.totalSkins(), 10)
			-- 안 가진 사람: ownedSkins에 넣고 장착은 그대로
			local wallet: any = ProfileSchema.new()
			wallet.drawTickets = 2
			local result = DrawLogic.apply(wallet, fresh)
			t.eq(result.kind, "Skin")
			t.eq(wallet.ownedSkins[ID], true)
			t.eq(wallet.equippedSkin, "tamago")
			-- DrawLogic·Config.Draw는 카탈로그만으로 바뀌어요 (코드에 고등어 id 없음)
			t.eq(string.find(fs.readFile("src/shared/DrawLogic.luau"), ID, 1, true), nil)
			t.eq(string.find(fs.readFile("src/shared/Config.luau"), ID, 1, true), nil)
		end
	)

	t.test(
		"AC2-2: 뽑기 보유 = 구매 보유 — 같은 ownedSkins 키, 구매는 AlreadyOwned, 장착 가능, 산 뒤 뽑기는 중복 300",
		function()
			local wallet: any = ProfileSchema.new()
			wallet.drawTickets = 1
			DrawLogic.apply(wallet, DrawLogic.roll(wallet.ownedSkins, fakeRng(0.001)) :: any)
			t.eq(wallet.ownedSkins[ID], true)
			local ok, reason = ReceiptLogic.canRequest(ID, wallet.ownedSkins, { canSave = true, fake = true })
			t.eq(ok, false)
			t.eq(reason, "AlreadyOwned")
			t.eq((ShopLogic.canEquip(ID, wallet.ownedSkins)), true)
			-- 반대로: 로벅스로 산 프로필(ShopLogic.grantSkin)에서 뽑기 전설 → 중복
			local bought: any = ProfileSchema.new()
			t.eq(ReceiptLogic.canRequest(ID, bought.ownedSkins, { canSave = true, fake = true }), true)
			ShopLogic.grantSkin(bought, ID, true)
			t.eq(bought.ownedSkins[ID], true)
			local outcome = DrawLogic.roll(bought.ownedSkins, fakeRng(0.001)) :: any
			t.eq(outcome.kind, "Duplicate")
			t.eq(outcome.coins, 300)
			local before = bought.coins
			bought.drawTickets = 1
			DrawLogic.apply(bought, outcome)
			t.eq(bought.coins, before + 300)
		end
	)

	---------------------------------------------------------------- AC3 validate (가짜 레이아웃 주입)
	t.test(
		"AC3: validate가 잡음 — 목록 밖 conceptBody, 고등어 효과 3개, 외곽 +25% 초과, 파츠 81개",
		function()
			local function loadShared(name: string, deps: { [string]: any }): any
				local path = `src/shared/{name}.luau`
				local parent = setmetatable({}, {
					__index = function(_, k)
						return { __dep = k }
					end,
				})
				return luau.load(fs.readFile(path), {
					debugName = path,
					environment = {
						script = { Parent = parent },
						require = function(target: any)
							return assert(deps[target.__dep], `missing dep {target.__dep}`)
						end,
					},
				})()
			end
			local function skinsWith(layout: { any }): any
				local fakeBody = setmetatable({
					layout = function(id: string, expression: string?)
						return if id == ID then layout else SushiBody.layout(id, expression)
					end,
				}, { __index = SushiBody })
				return loadShared(
					"Skins",
					{ Config = Config, Seasons = loadShared("Seasons", {}), SushiBody = fakeBody }
				)
			end
			local function problems(layout: { any }): string
				local skins = skinsWith(layout)
				local _, list = skins.validate(skins.LIST)
				return table.concat(list, ";")
			end
			local base = SushiBody.layout(ID)
			t.eq(problems(base), "", "real layout passes")
			-- 효과 3개
			local fx = table.clone(base)
			for i = 1, 2 do
				table.insert(fx, {
					name = `QaFx{i}`,
					size = { 0.1, 0.1, 0.1 },
					color = { 1, 1, 1 },
					material = "SmoothPlastic",
					offset = { 0, 2, 0 },
					effect = "Glow",
				})
			end
			t.ok(string.find(problems(fx), "effect budget exceeded", 1, true) ~= nil, "3 effects")
			-- 외곽 X +25% 초과 (concept-salmon 기준)
			local wide = table.clone(base)
			table.insert(wide, {
				name = "QaWide",
				size = { 0.1, 0.1, 0.1 },
				color = { 1, 1, 1 },
				material = "SmoothPlastic",
				offset = { SALMON_BOUNDS.min[1] + MAX_X + 0.2, 2, 0 },
			})
			t.ok(string.find(problems(wide), "concept body bounds axis 1", 1, true) ~= nil, "too wide")
			local deep = table.clone(base)
			table.insert(deep, {
				name = "QaDeep",
				size = { 0.1, 0.1, 0.1 },
				color = { 1, 1, 1 },
				material = "SmoothPlastic",
				offset = { 0, 2, SALMON_BOUNDS.min[3] + MAX_Z + 0.2 },
			})
			t.ok(string.find(problems(deep), "concept body bounds axis 3", 1, true) ~= nil, "too deep")
			-- 파츠 81개 (상한 80 — 사용자 결정 3차. 스펙 AC3의 "71개"는 3차 결정 전 값)
			local many = table.clone(base)
			while #many < 81 do
				table.insert(many, {
					name = `QaPart{#many}`,
					size = { 0.1, 0.1, 0.1 },
					color = { 1, 1, 1 },
					material = "SmoothPlastic",
					offset = { 0, 1.9, 0 },
				})
			end
			t.ok(string.find(problems(many), "concept body budget 80", 1, true) ~= nil, "81 parts")
			-- 목록 밖 id에 conceptBody
			local list = table.clone(Skins.LIST) :: { any }
			for i, skin in list do
				if skin.id == "golden-otoro" then
					local copy = table.clone(skin)
					copy.conceptBody = true
					list[i] = copy
				end
			end
			local ok, found = Skins.validate(list)
			t.eq(ok, false)
			t.ok(string.find(table.concat(found, ";"), "conceptBody only for", 1, true) ~= nil, "id scope")
		end
	)

	---------------------------------------------------------------- AC4 모양 한도
	t.test(
		"AC4: 표정 6종 × 대표 자세·표본 — 파츠 ≤ 80, 발바닥, 꼭대기(쉰 3.2·움직임 3.6), 외곽 ×1.25, 밥 위",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local rest = SushiBody.layout(ID, expression)
				t.ok(#rest <= 80, `{expression} parts {#rest}`)
				local b = SushiBody.bounds(rest)
				near(t, b.min[2], -SushiBody.GROUND_OFFSET, 1e-9, `{expression} sole`)
				t.ok(b.max[2] <= SushiBody.NAME_TAG_HEIGHT - 0.4, `{expression} rest top {b.max[2]}`)
				for _, item in posedLayouts(expression) do
					local label = `{expression}/{item.name}`
					local pb = SushiBody.bounds(item.layout)
					t.ok(pb.max[2] <= SushiBody.NAME_TAG_HEIGHT, `{label} top {pb.max[2]}`)
					near(t, pb.min[2], -SushiBody.GROUND_OFFSET, 1e-9, `{label} sole`)
					t.ok(pb.max[1] - pb.min[1] <= MAX_X + 1e-9, `{label} x {pb.max[1] - pb.min[1]}`)
					t.ok(pb.max[3] - pb.min[3] <= MAX_Z + 1e-9, `{label} z {pb.max[3] - pb.min[3]}`)
					t.eq(SushiBody.effectCount(item.layout), 1, label)
					for _, spec in item.layout do
						if isFishPart(spec.name) then
							t.eq(
								spec.transparency ~= nil and spec.transparency >= 1,
								false,
								`{label} {spec.name} visible`
							)
							local lo, hi = LayoutCheck.box(spec)
							-- 머리·꼬리·몸통은 밥 윗면 - 0.2 아래로 안 내려와요 (김 자락은 밥 윗면 위에서 끝나요)
							t.ok(lo[2] >= RICE_TOP - 0.2 - 1e-6, `{label} {spec.name} low {lo[2]}`)
							-- 얼굴 높이(밥 윗면 아래)에서 밥 앞면보다 앞으로 안 나와요
							if lo[2] < RICE_TOP then
								t.ok(lo[3] >= RICE_FRONT - 1e-6, `{label} {spec.name} covers the face`)
							end
							t.ok(hi[2] <= SushiBody.NAME_TAG_HEIGHT, `{label} {spec.name} top`)
						end
					end
				end
			end
		end
	)

	t.test(
		"AC4: 겹침(z-fighting) 0·떠 있음 0 (튀어나온 물방울만 공중), 쉰 자세 물방울은 고등어 상자 안, 이름 중복 0",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local rest = SushiBody.layout(ID, expression)
				local seen = {}
				for _, spec in rest do
					t.ok(seen[spec.name] == nil, `{expression} duplicate {spec.name}`)
					seen[spec.name] = true
				end
				t.eq(LayoutCheck.zFight(rest), {}, `{expression} z-fighting`)
				t.eq(LayoutCheck.floating(rest), {}, `{expression} floating`)
			end
			local rest = SushiBody.layout(ID)
			local fish = {}
			for _, spec in rest do
				if string.sub(spec.name, 1, 4) == "Fish" then
					table.insert(fish, spec)
				end
			end
			local fb = SushiBody.bounds(fish)
			for _, spec in rest do
				if string.sub(spec.name, 1, 6) == "Splash" then
					local lo, hi = LayoutCheck.box(spec)
					for axis = 1, 3 do
						t.ok(lo[axis] >= fb.min[axis] and hi[axis] <= fb.max[axis], `{spec.name} hidden axis {axis}`)
					end
				end
			end
			for _, item in Anim.fishTestPoses() do
				local layout = SushiPose.posed(rest, Anim.fishMotion(item.pose))
				t.eq(LayoutCheck.zFight(layout), {}, `{item.name} z-fighting`)
				local float = LayoutCheck.floating(partsWithout(layout, "Splash"))
				t.eq(float, {}, `{item.name} floating`)
			end
		end
	)

	t.test(
		"AC4: 밥을 감는 김(NoriWrap) — Body에 붙어 안 움직이고, 얼굴보다 위·밥 앞면 평평한 곳에, 고등어 띠 자락이 그 위에",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local layout = SushiBody.layout(ID, expression)
				local wrap, faceTop = nil, -math.huge
				local drapes = {}
				for _, spec in layout do
					if spec.name == "NoriWrap" then
						wrap = spec
					elseif spec.name == "FishNoriFront" or spec.name == "FishNoriBack" then
						table.insert(drapes, spec)
					else
						local lo, hi = LayoutCheck.box(spec)
						-- 밥 앞면에 붙은 얼굴 파츠 (눈·입·볼·땀·눈물·💢)
						if lo[3] < RICE_FRONT + 0.1 and hi[2] < RICE_TOP and lo[2] > -1 then
							faceTop = math.max(faceTop, hi[2])
						end
					end
				end
				t.ok(wrap ~= nil, `{expression} NoriWrap`)
				local w = wrap :: any
				t.eq(w.joint, nil, `{expression} wrap is not a joint`)
				t.eq(w.attach, nil, `{expression} wrap welds to Body`)
				local lo, hi = LayoutCheck.box(w)
				t.ok(lo[2] >= faceTop + 0.1, `{expression} wrap bottom {lo[2]} above face top {faceTop}`)
				t.ok(
					lo[1] >= -1.35 - 1e-6 and hi[1] <= 1.35 + 1e-6,
					`{expression} wrap on the flat front x {lo[1]}..{hi[1]}`
				)
				t.ok(lo[3] >= RICE_FRONT - 0.06, `{expression} wrap hugs the rice front {lo[3]}`)
				t.ok(hi[2] <= RICE_TOP + 0.05, `{expression} wrap top {hi[2]}`)
				-- 고등어 띠 자락 아래끝이 김 윗면에 닿거나 살짝 들어가요 (쉰 자세에서 틈이 없게, 밥 윗면 - 0.2 위)
				t.eq(#drapes, 2, `{expression} drapes`)
				for _, drape in drapes do
					local dlo = LayoutCheck.box(drape)
					t.ok(
						dlo[2] <= hi[2] + 0.02 and dlo[2] >= RICE_TOP - 0.2,
						`{expression} {drape.name} lands on the wrap {dlo[2]} vs {hi[2]}`
					)
				end
			end
			-- 다른 콘셉트 스킨에는 없어요
			for _, spec in SushiBody.layout(SALMON) do
				t.ok(spec.name ~= "NoriWrap", "salmon has no NoriWrap")
			end
		end
	)

	---------------------------------------------------------------- AC5 공유 부분·스냅숏
	t.test(
		"AC5: 다른 40종(콘셉트 9종 × 표정 4종 포함) 레이아웃이 main(8f700a4)과 바이트 단위로 같아요",
		function()
			local entries = {}
			for _, skin in Skins.LIST do
				if skin.id == ID then
					continue
				end
				table.insert(entries, { skin.id, SushiBody.layout(skin.id) })
				if table.find(Sample.SKIN_IDS, skin.id) then
					for _, e in { "Default", "Happy", "Flustered", "Hurt" } do
						table.insert(entries, { `{skin.id}:{e}`, SushiBody.layout(skin.id, e) })
					end
				end
			end
			local now = LayoutSnapshot.encode(entries)
			local before = fs.readFile("tests/fixtures/m5-32-layout-snapshot.txt")
			t.ok(now == before, "layout snapshot changed")
		end
	)

	t.test(
		"AC5: 고등어의 밥·받침·팔·다리·얼굴(표정 6종)·관절 8개가 concept-salmon과 크기·위치·색·재질까지 같아요",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local mine = {}
				for _, spec in SushiBody.layout(ID, expression) do
					-- 고등어 파츠와 밥을 감는 김(NoriWrap)만 빼면 연어와 같아요 (연어도 Nori를 빼고 비교)
					if not isFishPart(spec.name) and string.sub(spec.name, 1, 4) ~= "Nori" then
						table.insert(mine, LayoutSnapshot.spec(spec))
					end
				end
				local salmon = {}
				for _, spec in SushiBody.layout(SALMON, expression) do
					local name = spec.name
					local topping = string.sub(name, 1, 7) == "Topping"
						or string.sub(name, 1, 5) == "Ridge"
						or string.sub(name, 1, 6) == "Stripe"
						or string.sub(name, 1, 4) == "Nori"
					if not topping then
						table.insert(salmon, LayoutSnapshot.spec(spec))
					end
				end
				t.eq(mine, salmon, expression)
			end
		end
	)

	---------------------------------------------------------------- AC6 관절 사슬 (진짜 Instance)
	t.test(
		"AC6: build — Body만 Anchored, FishRoot→Body·FishMid→FishRoot·FishTail→FishMid, C0은 부모 기준, 관절 17개",
		function()
			local Real = Shims.root("src/shared")
			local RealBody = Shims.require(Real.SushiBody)
			local model = RealBody.build(ID)
			local parts: { [string]: any } = {}
			for _, item in model:GetChildren() do
				parts[item.Name] = item
			end
			local motors = 0
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					t.eq(item.Anchored, item.Name == "Body", `{item.Name} anchored`)
					t.eq(item.Massless, true)
					t.eq(item.CanCollide or item.CanQuery or item.CanTouch, false, `{item.Name} no collision`)
				elseif item:IsA("Motor6D") then
					motors += 1
					t.eq(item.Name, SushiBody.PART_JOINT_NAME)
					-- Transform = identity일 때 Part1 = Part0 · C0 (레이아웃 자리)
					local expected = item.Part0.CFrame * item.C0
					local diff = (expected.Position - item.Part1.CFrame.Position).Magnitude
					t.ok(diff < 0.001, `{item.Part1.Name} C0 position {diff}`)
					local r1 = { expected:GetComponents() }
					local r2 = { item.Part1.CFrame:GetComponents() }
					for i = 4, 12 do
						t.ok(math.abs(r1[i] - r2[i]) < 0.001, `{item.Part1.Name} C0 rotation {i}`)
					end
				end
			end
			t.eq(motors, 17)
			local function part0(name: string): string
				return parts[name]:FindFirstChild(SushiBody.PART_JOINT_NAME).Part0.Name
			end
			t.eq(part0("FishRoot"), "Body")
			t.eq(part0("FishMid"), "FishRoot")
			t.eq(part0("FishTail"), "FishMid")
			t.eq(part0("FishFinL"), "FishRoot")
			t.eq(part0("FishFinR"), "FishRoot")
			for i = 1, 4 do
				local motor = parts[`Splash{i}`]:FindFirstChild(SushiBody.PART_JOINT_NAME)
				t.eq(motor.Part0.Name, "Body")
				t.eq(typeof(motor:GetAttribute("Reach")), "Vector3", `Splash{i} reach`)
			end
			for _, name in { "FishRoot", "FishMid", "FishTail", "FishFinL", "FishFinR" } do
				local motor = parts[name]:FindFirstChild(SushiBody.PART_JOINT_NAME)
				t.eq(typeof(motor:GetAttribute("Pivot")), "Vector3", `{name} pivot`)
			end
			-- 붙는 파츠는 자기 관절 파츠에 용접 (김 띠 → FishMid, 꼬리지느러미 → FishTail, 눈 → FishRoot)
			local function weldTo(name: string): string
				local weld = parts[name]:FindFirstChildOfClass("WeldConstraint")
				return weld.Part0.Name
			end
			t.eq(weldTo("FishNori"), "FishMid")
			t.eq(weldTo("FishNoriFront"), "FishMid")
			t.eq(weldTo("FishTailTop"), "FishTail")
			t.eq(weldTo("FishEyeF"), "FishRoot")
			t.eq(weldTo("FishRearBelly"), "FishMid")
			-- 사슬 없는 다른 스킨은 그대로 (모든 관절이 Body)
			for _, id in { "tamago", "golden-otoro", SALMON } do
				for _, item in RealBody.build(id):GetDescendants() do
					if item:IsA("Motor6D") then
						t.eq(item.Part0.Name, "Body", `{id} {item.Part1.Name}`)
					end
				end
			end
		end
	)

	t.test(
		"AC6: posed — 부모를 돌리면 붙는 파츠도 같이 돌고(김 띠·꼬리), 움직임 0이면 레이아웃 그대로",
		function()
			local base = SushiBody.layout(ID)
			local zero = SushiPose.posed(base, Anim.fishMotion(Anim.fishTestPoses()[1].pose))
			t.eq(LayoutSnapshot.encode({ { "rest", zero } }), LayoutSnapshot.encode({ { "rest", base } }))
			local yaw = SushiPose.posed(base, { FishMid = { angles = { 0, 30 * DEG, 0 } } })
			local function at(layout: { any }, name: string): { number }
				for _, spec in layout do
					if spec.name == name then
						return spec.offset
					end
				end
				error(name)
			end
			local pivot = (base[1] :: any) and { 0.15, 0, 0 }
			for _, name in { "FishMid", "FishNori", "FishTail", "FishTailTop" } do
				local a, b = at(base, name), at(yaw, name)
				-- Y축으로 30° 돌면 경첩에서 거리는 같고(XZ), 높이는 그대로
				local ra = math.sqrt((a[1] - pivot[1]) ^ 2 + a[3] ^ 2)
				local rb = math.sqrt((b[1] - pivot[1]) ^ 2 + b[3] ^ 2)
				near(t, ra, rb, 1e-6, `{name} radius`)
				near(t, a[2], b[2], 1e-6, `{name} height`)
				if ra > 0.1 then
					t.ok(math.abs(b[3] - a[3]) > 0.05, `{name} moved`)
				end
			end
			local head = at(yaw, "FishEyeF")
			t.eq(head, at(base, "FishEyeF"), "root parts stay")
		end
	)

	---------------------------------------------------------------- AC7 움직임 값
	t.test(
		"AC7: 상태별 값 범위 — 살랑 ≤ 8°, 팔딱 ≤ 35°, 달리기 ≤ 22°×walk, 착지 ≤ 40°, 넘어짐 ≤ 30°, 아치 ≤ 20°, 들썩 ≤ 0.45",
		function()
			local function maxOver(make: (number) -> any, duration: number, key: string): number
				local best = 0
				local time = 0
				while time <= duration do
					local pose = Anim.fishPose(make(time)) :: any
					best = math.max(best, math.abs(pose[key]))
					time += 1 / 240
				end
				return best
			end
			local eps = 1e-6
			t.ok(maxOver(function(x)
				return standing(x)
			end, 3, "tailYaw") <= 8 * DEG + eps, "sway tail")
			t.ok(maxOver(function(x)
				return standing(x)
			end, 3, "midYaw") <= 3 * DEG + eps, "sway mid")
			t.eq(
				maxOver(function(x)
					return standing(x)
				end, 3, "splash"),
				0,
				"rest splash 0"
			)
			local flopTail = maxOver(function(x)
				return standing(x, { flopTime = x })
			end, F.FLOP_TIME, "tailYaw")
			t.ok(flopTail <= 35 * DEG + eps and flopTail >= 25 * DEG, `flop tail {flopTail / DEG}`)
			-- walk 0.3 이상이면 살랑이 완전히 꺼져서 22°×walk 그대로 (0.2~0.3은 살랑이 섞이며 줄어요)
			for _, walk in { 0.3, 0.6, 1.0, 1.3 } do
				local run = maxOver(function(x)
					return standing(x, { walk = walk, phase = x * (9 + 5 * walk) })
				end, 2, "tailYaw")
				t.ok(run <= 22 * DEG * walk + eps, `run {walk} tail {run / DEG}`)
			end
			local land = maxOver(function(x)
				return standing(x, { landTime = x, landStrength = 1 })
			end, F.LAND_DELAY + F.LAND_TIME, "tailYaw")
			t.ok(land <= 40 * DEG + eps and land >= 30 * DEG, `land tail {land / DEG}`)
			t.ok(maxOver(function(x)
				return standing(x, { knocked = true })
			end, 2, "tailYaw") <= 30 * DEG + eps, "knock tail")
			t.eq(
				maxOver(function(x)
					return standing(x, { knocked = true })
				end, 2, "rootLift"),
				0,
				"knock lift 0"
			)
			for _, item in sampledPoses() do
				local pose = item.pose
				t.ok(math.abs(pose.rootArch) <= 20 * DEG + eps, `{item.name} root arch`)
				t.ok(math.abs(pose.midArch + pose.tailArch) <= 20 * DEG + eps, `{item.name} tail arch`)
				t.ok(pose.rootLift >= 0 and pose.rootLift <= 0.45, `{item.name} lift`)
				t.ok(pose.splash >= 0 and pose.splash <= 1, `{item.name} splash`)
				t.ok(math.abs(pose.tailYaw) <= 40 * DEG + eps, `{item.name} tail`)
			end
			local jump = Anim.fishPose(standing(0, { airborne = true, riseSpeed = 60 }))
			t.ok(jump.midArch + jump.tailArch > 15 * DEG, "jump C arch visible")
			t.ok(jump.rootArch > 0, "jump head up")
			local hurt = Anim.fishPose(standing(0, { mode = "Hurt" }))
			near(t, hurt.midArch + hurt.tailArch, -10 * DEG, 1e-9, "hurt droop")
			local splash = 0
			local time = 0
			while time < F.FLOP_TIME do
				splash = math.max(splash, Anim.fishPose(standing(time, { flopTime = time })).splash)
				time += 1 / 120
			end
			near(t, splash, 1, 0.01, "flop splash 0 → 1 → 0")
		end
	)

	t.test("AC7: 진동수 ≤ 7 Hz (꼬리 각 0 교차 간격, 모든 상태)", function()
		local function maxHz(make: (number) -> any, duration: number): number
			local crossings = {}
			local prev = nil
			local time = 0
			while time <= duration do
				local v = Anim.fishPose(make(time)).tailYaw
				if prev ~= nil and ((prev < 0 and v >= 0) or (prev > 0 and v <= 0)) then
					table.insert(crossings, time)
				end
				prev = v
				time += 1 / 600
			end
			local best = 0
			for i = 2, #crossings do
				local gap = crossings[i] - crossings[i - 1]
				if gap > 1e-6 then
					best = math.max(best, 1 / (2 * gap))
				end
			end
			return best
		end
		local cases = {
			{
				"sway",
				function(x)
					return standing(x)
				end,
				3,
			},
			{
				"flop",
				function(x)
					return standing(x, { flopTime = x })
				end,
				F.FLOP_TIME,
			},
			{
				"land",
				function(x)
					return standing(x, { landTime = x, landStrength = 1 })
				end,
				F.LAND_DELAY + F.LAND_TIME,
			},
			{
				"knock",
				function(x)
					return standing(x, { knocked = true })
				end,
				2,
			},
			{
				"run",
				function(x)
					return standing(x, { walk = 1.3, phase = x * (9 + 5 * 1.3) })
				end,
				2,
			},
			{
				"hurt",
				function(x)
					return standing(x, { flopTime = x, mode = "Hurt" })
				end,
				F.TWITCH_TIME,
			},
		}
		for _, case in cases do
			local hz = maxHz(case[2] :: any, case[3] :: number)
			t.ok(hz <= F.MAX_HZ * 1.03, `{case[1]} {hz} Hz`) -- 표본 간격(1/600초) 오차만큼 여유
		end
		t.eq(F.MAX_HZ, 7)
	end)

	t.test(
		"AC7: 1/60초 연속성 — 상태가 바뀌는 순간 꼬리 각 변화 ≤ 0.12 rad, 어느 프레임도 진동 최대 속도 + 0.12 이하",
		function()
			-- 각 상태의 진동 최대 속도 (진폭 × 2πf / 60) 중 가장 큰 값 — 6~7 Hz·35~40° 진동 자체가 한 프레임에 0.38 rad쯤
			-- 움직여서 모든 프레임을 0.12로 묶을 수는 없어요 (개발 결정 기록). 상태 전환 순간은 0.12로 묶어요
			local natural = math.max(
				F.FLOP_TAIL * 2 * math.pi * F.FLOP_HZ,
				F.LAND_TAIL * 2 * math.pi * F.LAND_HZ,
				F.KNOCK_TAIL * 2 * math.pi * F.KNOCK_HZ,
				F.RUN_TAIL * 1.3 * 2 * 15.5
			) / 60
			local frames = {}
			local switches = {}
			-- 클라이언트처럼: walk는 목표로 부드럽게(속도 10), 걷기 위상은 walk에 맞춰 계속 돌아요
			local time, walk, phase = 0, 0, 0
			local function add(target: number, overrides: { [string]: any }?, switching: boolean?)
				time += 1 / 60
				walk += (target - walk) * math.min(1, 10 / 60)
				if walk < 0.01 then
					walk, phase = 0, 0
				else
					phase = (phase + (9 + 5 * walk) / 60) % (2 * math.pi)
				end
				local input = standing(time, overrides)
				input.walk = walk
				input.phase = phase
				table.insert(frames, input)
				if switching then
					switches[#frames] = true
				end
			end
			for _ = 1, 60 do
				add(0)
			end
			-- 서 있다가 팔딱 시작
			for i = 0, 40 do
				add(0, { flopTime = i / 60 }, i == 0)
			end
			-- 걷기 시작
			for i = 1, 60 do
				add(1.2, nil, i == 1)
			end
			-- 점프 (올라감, 공중이라 walk 목표 0) → 착지 팔딱
			for i = 1, 20 do
				add(0, { airborne = true, riseSpeed = 40 - i * 2 }, i == 1)
			end
			for i = 0, 40 do
				add(0, { landTime = i / 60, landStrength = 1 }, i == 0)
			end
			-- 넘어짐 → 일어남
			for i = 1, 40 do
				add(0, { knocked = true }, i == 1)
			end
			for i = 1, 30 do
				add(0, nil, i == 1)
			end
			local poses, blends = simulate(frames)
			for i = 2, #poses do
				local change = math.abs(poses[i].tailYaw - poses[i - 1].tailYaw)
				t.ok(change <= natural + 0.12, `frame {i} change {change}`)
				if switches[i] then
					-- 상태가 바뀐 프레임: "안 바뀌었으면 됐을 값"(앞 상태를 그대로 한 프레임 더)과의 차이 ≤ 0.12 rad
					local before = table.clone(frames[i - 1])
					before.time = frames[i].time
					before.walk = frames[i].walk
					before.phase = frames[i].phase
					if before.flopTime then
						before.flopTime += 1 / 60
					end
					if before.landTime then
						before.landTime += 1 / 60
					end
					before.blend = blends[i - 1]
					local stay = Anim.fishPose(before)
					local jump = math.abs(poses[i].tailYaw - stay.tailYaw)
					t.ok(jump <= 0.12, `switch frame {i} jump {jump}`)
				end
			end
		end
	)

	---------------------------------------------------------------- AC8 간격
	t.test(
		"AC8: nextFlopDelay — 모드별 끝값·단조, 달리는 중·공중·넘어짐에는 새 팔딱 안 함",
		function()
			local ranges = {
				Character = { 2.5, 6 },
				Victory = { 1.0, 1.6 },
				Preview = { 1.5, 3 },
				Hurt = { 1.5, 2.5 },
			}
			for mode, range in ranges do
				near(t, Anim.nextFlopDelay(0, mode), range[1], 1e-9, `{mode} 0`)
				near(t, Anim.nextFlopDelay(1, mode), range[2], 1e-9, `{mode} 1`)
				local prev = -math.huge
				for i = 0, 20 do
					local v = Anim.nextFlopDelay(i / 20, mode)
					t.ok(v >= prev, `{mode} monotonic`)
					prev = v
				end
			end
			t.eq(Anim.canStartFlop(0, false, false), true)
			t.eq(Anim.canStartFlop(0.2, false, false), true)
			t.eq(Anim.canStartFlop(0.21, false, false), false)
			t.eq(Anim.canStartFlop(0, true, false), false)
			t.eq(Anim.canStartFlop(0, false, true), false)
			t.eq(Anim.flopDuration("Character"), 0.6)
			t.eq(Anim.flopDuration("Hurt"), 0.3)
			-- 클라이언트도 같은 함수로 막아요
			local fx = fs.readFile("src/client/fx/CharacterFxController.luau")
			t.ok(string.find(fx, "CharacterAnimLogic.canStartFlop(state.walk, inAir, knocked)", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- 3차 결정: 소리
	t.test(
		"3차 결정: FishFlop·FishSplash 큐 (무음으로 시작, 3D 60 studs), 캐릭터당 0.25초, 살랑·경련엔 소리 없음",
		function()
			for _, cue in { "FishFlop", "FishSplash" } do
				t.ok(SfxCues.isEffect(cue), cue)
				local entry = SfxLibrary.get(cue) :: any
				t.eq(entry.id, nil, `{cue} silent until the user picks`)
				t.eq(entry.maxDistance, 60, cue)
			end
			t.eq(F.SOUND_GAP, 0.25)
			t.eq(Anim.fishSoundAllowed(nil, 5), true)
			t.eq(Anim.fishSoundAllowed(5, 5.2), false)
			t.eq(Anim.fishSoundAllowed(5, 5.25), true)
			t.eq(Anim.fishCues("Flop", "Character", nil, 0), { "FishFlop" })
			t.eq(Anim.fishCues("Flop", "Victory", 0.05, 0.07), { "FishSplash" })
			t.eq(Anim.fishCues("Flop", "Character", 0.1, 0.12), {})
			t.eq(Anim.fishCues("Land", "Character", 0.07, 0.09), { "FishFlop", "FishSplash" })
			t.eq(Anim.fishCues("Flop", "Hurt", nil, 0), {})
			local sfx = fs.readFile("src/client/Sfx.luau")
			t.ok(string.find(sfx, "entry.maxDistance or ROLLOFF_MAX_DISTANCE", 1, true) ~= nil, "3D distance per cue")
		end
	)

	---------------------------------------------------------------- 3차 결정: 표정
	t.test(
		"3차 결정: 표정 6종(화남·슬픔) — 콘셉트 몸 모두, 깜빡임 관절, 얼굴은 밥 앞면에",
		function()
			t.eq(Sample.EXPRESSIONS, { "Default", "Happy", "Flustered", "Hurt", "Angry", "Sad" })
			for _, id in Sample.SKIN_IDS do
				t.eq(SushiBody.CONCEPT_BODY[id].expressions, Sample.EXPRESSIONS, id)
				for _, expression in { "Angry", "Sad" } do
					local layout = SushiBody.layout(id, expression)
					t.ok(#layout <= SushiBody.CONCEPT_BODY[id].partBudget, `{id}/{expression} parts {#layout}`)
					local names = {}
					for _, spec in layout do
						names[spec.name] = spec
					end
					-- 눈을 뜬 표정이라 깜빡임 관절(눈·감은 눈)이 있어요
					for _, name in { "EyeLeft", "EyeRight", "LidLeft", "LidRight" } do
						t.eq(names[name] and names[name].joint, true, `{id}/{expression} {name} joint`)
					end
					t.ok(names.BrowLeft ~= nil and names.BrowRight ~= nil, `{id}/{expression} brows`)
					t.eq(LayoutCheck.zFight(layout), {}, `{id}/{expression} z-fighting`)
					t.eq(LayoutCheck.floating(layout), {}, `{id}/{expression} floating`)
				end
				t.ok(SushiBody.layout(id, "Angry")[1] ~= nil)
			end
			local angry = {}
			for _, spec in SushiBody.layout(SALMON, "Angry") do
				angry[spec.name] = true
			end
			for i = 1, 4 do
				t.ok(angry[`BrowVein{i}`], `💢 stroke {i}`)
			end
			local sad = {}
			for _, spec in SushiBody.layout(SALMON, "Sad") do
				sad[spec.name] = true
			end
			t.ok(sad.EyeTear and sad.EyeTearTip, "tear")
			-- 탈의실·뽑기 상세 썸네일이 6칸
			t.ok(string.find(fs.readFile("src/client/ui/DrawScreen.luau"), "EXPRESSION_SLOTS = 6", 1, true) ~= nil)
		end
	)

	---------------------------------------------------------------- AC9 id 분기 없음 + DollAnimator 가짜 Roblox
	t.test("AC9: 움직임 코드에 스킨 id 문자열이 없어요 (관절 이름으로만)", function()
		for _, path in
			{
				"src/client/fx/CharacterFxController.luau",
				"src/client/fx/DollAnimator.luau",
				"src/client/fx/FishRig.luau",
				"src/shared/CharacterAnimLogic.luau",
			}
		do
			local source = string.lower(fs.readFile(path))
			t.eq(string.find(source, "fresh-mackerel", 1, true), nil, path)
			t.eq(string.find(source, "mackerel", 1, true), nil, path)
		end
	end)

	t.test(
		"AC9·AC17: DollAnimator — 고등어 관절 없는 인형은 아무것도 안 하고, 고등어 인형은 팔딱 + 소리, 지우면 연결 끊음",
		function()
			local Real = Shims.root("src/shared")
			local RealBody = Shims.require(Real.SushiBody)
			local RealAnim = Shims.require(Real.CharacterAnimLogic)
			local connections = 0
			local disconnected = 0
			local frameFn: ((number) -> ())? = nil
			local runService = {
				RenderStepped = {
					Connect = function(_, fn)
						connections += 1
						frameFn = fn
						return {
							Disconnect = function()
								disconnected += 1
							end,
						}
					end,
				},
			}
			local dataModel = roblox.Instance.new("DataModel")
			local workspace = dataModel:GetService("Workspace")
			local played: { string } = {}
			local fakeSfx = {
				play = function(cue: string)
					table.insert(played, cue)
				end,
			}
			local replicated = { Shared = { CharacterAnimLogic = "CharacterAnimLogic", SushiBody = "SushiBody" } }
			local modules: { [string]: any } = { CharacterAnimLogic = RealAnim, SushiBody = RealBody, Sfx = fakeSfx }
			local fakeGame = {
				GetService = function(_, name: string): any
					if name == "RunService" then
						return runService
					elseif name == "ReplicatedStorage" then
						return replicated
					end
					return dataModel:GetService(name)
				end,
			}
			local function load(path: string, scriptNode: any): any
				return luau.load(fs.readFile(path), {
					debugName = path,
					environment = {
						game = fakeGame,
						script = scriptNode,
						require = function(target: any): any
							return assert(modules[target], `unexpected require {tostring(target)}`)
						end,
						CFrame = roblox.CFrame,
						Vector3 = roblox.Vector3,
						typeof = roblox.typeof or typeof,
					},
				})()
			end
			modules.FishRig = load("src/client/fx/FishRig.luau", {})
			local DollAnimator =
				load("src/client/fx/DollAnimator.luau", { Parent = { Parent = { Sfx = "Sfx" }, FishRig = "FishRig" } })
			-- 고등어 관절이 없는 인형: 빈 함수, 연결 없음
			local plain = RealBody.build("golden-otoro")
			plain.Parent = workspace
			local stopPlain = DollAnimator.attach(plain, "Victory", { sound = "World" })
			t.eq(type(stopPlain), "function")
			stopPlain()
			t.eq(connections, 0, "no frame hook for skins without fish joints")
			-- 고등어 인형
			local fish = RealBody.build(ID)
			fish.Parent = workspace
			local tail = fish:FindFirstChild("FishTail")
			local splash = fish:FindFirstChild("Splash1")
			local body = fish:FindFirstChild("Body")
			local tailRest = tail.CFrame
			local splashRest = splash.CFrame.Position
			local bodyRest = body.CFrame
			DollAnimator.attach(fish, "Victory", { sound = "World" })
			t.eq(connections, 1)
			local maxTail, maxSplash = 0, 0
			for _ = 1, 150 do
				(frameFn :: any)(1 / 30)
				maxTail = math.max(maxTail, (tail.CFrame.Position - tailRest.Position).Magnitude)
				maxSplash = math.max(maxSplash, (splash.CFrame.Position - splashRest).Magnitude)
			end
			t.ok(maxTail > 0.2, `tail moved {maxTail}`)
			t.ok(maxSplash > 0.8, `splash flew {maxSplash}`)
			t.ok((body.CFrame.Position - bodyRest.Position).Magnitude < 1e-6, "body stays")
			t.ok(table.find(played, "FishFlop") ~= nil, "flop sound")
			t.ok(table.find(played, "FishSplash") ~= nil, "splash sound")
			-- 인형을 지우면 다음 프레임에 빠지고 연결도 끊어요
			fish:Destroy();
			(frameFn :: any)(1 / 30)
			t.eq(disconnected, 1, "disconnected when no dolls")
		end
	)
end
