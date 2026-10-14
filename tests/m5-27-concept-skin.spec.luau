--!strict
-- m5-27 실험 스킨 concept-salmon (콘셉트 견본 연어초밥을 게임에서 무료로 써 보기):
--   카탈로그·검사 예외가 이 id 하나에만, 모두가 처음부터 가짐(저장 없이), SushiBody.layout/build가 견본 게임 레이아웃,
--   발바닥 = GROUND_OFFSET, 깜빡임·발·팔 관절, 표정 인형, 팔 흔들기 로직.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Skins = RobloxRequire.require(Shared.Skins)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Sample = RobloxRequire.require(Shared.SushiConceptSample)
local ShopLogic = RobloxRequire.require(Shared.ShopLogic)
local ReceiptLogic = RobloxRequire.require(Shared.ReceiptLogic)
local OfferLogic = RobloxRequire.require(Shared.OfferLogic)
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)

local ID = "concept-salmon"
local RICE_FRONT = -1.35 -- 견본 밥 앞면 z (SushiConceptSample: -RICE_D / 2)

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

local function sortedKeys(map: { [string]: any }): { string }
	local list = {}
	for key in map do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

-- 파츠 앞끝(가장 -Z)이 밥 앞면보다 뒤(밥 속)인가. shiftZ = Body 축 앞뒤 이동 (+ = 뒤)
local function hiddenInRice(spec: any, shiftZ: number): boolean
	local lo = LayoutCheck.box(spec)
	return lo[3] + shiftZ >= RICE_FRONT - 1e-9
end

local function freshView(): any
	return { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
end

return function(t: Test.Test)
	---------------------------------------------------------------- 카탈로그·예외 범위
	t.test(
		"카탈로그: 무료 Basic 실험 스킨, 이름 '콘셉트 연어초밥 (테스트)', validate 통과",
		function()
			local skin = Skins.get(ID)
			t.ok(skin ~= nil, "in catalog")
			t.eq(skin.displayName, "콘셉트 연어초밥 (테스트)")
			t.eq(skin.tier, "Basic")
			t.eq(skin.experimental, true)
			for _, field in { "robux", "coins", "tokens", "vipOnly", "season", "productId" } do
				t.eq((skin :: any)[field], nil, field)
			end
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	-- m5-28·m5-29: 같은 콘셉트 몸의 실험 스킨이 늘어 예외 목록이 정확히 9개가 됐어요 (여전히 명시적 목록과 같아야 해요)
	local CONCEPT_IDS = {
		"concept-ikura",
		"concept-inari",
		"concept-salmon",
		"concept-shrimp",
		"concept-tako",
		"concept-tamago",
		"concept-tuna",
		"concept-unagi",
		"concept-uni",
	}
	t.test(
		"예외는 콘셉트 몸 9종뿐: LIST의 experimental·EXPERIMENTAL_IDS·SushiBody.EXPERIMENTAL이 같아요",
		function()
			local flagged = {}
			for _, skin in Skins.LIST do
				if skin.experimental ~= nil then
					flagged[skin.id] = true
				end
			end
			t.eq(sortedKeys(flagged), CONCEPT_IDS)
			t.eq(sortedKeys(Skins.EXPERIMENTAL_IDS), CONCEPT_IDS)
			t.eq(sortedKeys(SushiBody.EXPERIMENTAL), CONCEPT_IDS)
			t.ok(flagged[ID], "concept-salmon still experimental")
			t.ok(SushiBody.EXPERIMENTAL[ID].partBudget <= 70, "budget ≤ 70 (m5-30)")
		end
	)

	t.test(
		"validate: 다른 스킨에 experimental을 달거나 실험 스킨에 가격을 붙이면 잡아요",
		function()
			local list = table.clone(Skins.LIST) :: { any }
			for i, skin in list do
				if skin.id == "salmon" then
					local copy = table.clone(skin)
					copy.experimental = true
					list[i] = copy
				end
			end
			local ok, problems = Skins.validate(list)
			t.eq(ok, false)
			t.ok(string.find(table.concat(problems, ";"), "experimental only for", 1, true) ~= nil, "id scope")

			local priced = table.clone(Skins.LIST) :: { any }
			for i, skin in priced do
				if skin.id == ID then
					local copy = table.clone(skin)
					copy.robux = 29
					priced[i] = copy
				end
			end
			local ok2, problems2 = Skins.validate(priced)
			t.eq(ok2, false)
			t.ok(string.find(table.concat(problems2, ";"), "must be Basic and free", 1, true) ~= nil, "free")

			local tiered = table.clone(Skins.LIST) :: { any }
			for i, skin in tiered do
				if skin.id == ID then
					local copy = table.clone(skin)
					copy.tier = "Common"
					tiered[i] = copy
				end
			end
			t.eq((Skins.validate(tiered)), false)
		end
	)

	---------------------------------------------------------------- 보유 (저장 없이 모두가 가짐)
	t.test("보유: isFree, 장착 가능(잠금 중엔 Locked), 코인·로벅스로는 이미 가진 것", function()
		t.eq(Skins.isFree(ID), true)
		t.eq(Skins.isFree("tamago"), true)
		t.eq(Skins.isFree("salmon"), false)
		t.eq(Skins.isFree("no-such-skin"), false)
		t.eq(Skins.isFree(nil), false)

		t.eq(ShopLogic.canEquip(ID, { tamago = true }), true)
		t.eq(select(2, ShopLogic.canEquip(ID, { tamago = true }, true)), "Locked")
		t.eq(ShopLogic.canEquip("salmon", { tamago = true }), false)
		local coin = ShopLogic.canBuyWithCoins(ID, { coins = 9999, ownedSkins = { tamago = true } })
		t.eq(coin.ok, false)
		t.eq(coin.reason, "AlreadyOwned")
		t.eq(select(2, ReceiptLogic.canRequest(ID, { tamago = true }, { canSave = true, fake = true })), "AlreadyOwned")
	end)

	t.test("탈의실: 새 프로필에서도 카드가 '입기', 전체 탭에 보여요", function()
		local view = freshView()
		local state = ShopLogic.cardState(Skins.get(ID), view)
		t.eq(state.kind, "Equip")
		t.eq(state.enabled, true)
		t.eq(ShopLogic.cardButtonText(state), "입기")
		local shown = false
		for _, tab in ShopLogic.tabs() do
			if tab.id == "all" then
				for _, skin in ShopLogic.visibleSkins(view, tab) do
					shown = shown or skin.id == ID
				end
			end
		end
		t.ok(shown, "visible in the all tab")
		view.equippedSkin = ID
		t.eq(ShopLogic.cardState(Skins.get(ID), view).kind, "Equipped")
	end)

	t.test(
		"저장: 새 프로필 ownedSkins에는 안 넣고, 장착값 concept-salmon은 불러와도 유지돼요",
		function()
			local fresh = ProfileSchema.new()
			t.eq(fresh.ownedSkins[ID], nil)
			local raw = ProfileSchema.new() :: any
			raw.equippedSkin = ID
			local profile = ProfileLogic.migrate(raw)
			t.eq(profile.equippedSkin, ID)
			t.eq(profile.ownedSkins[ID], nil)
			-- 다른 미보유 스킨은 예전처럼 계란초밥으로
			local other = ProfileSchema.new() :: any
			other.equippedSkin = "salmon"
			t.eq(ProfileLogic.migrate(other).equippedSkin, "tamago")
		end
	)

	t.test("서버 코드: 장착 resolver가 무료 스킨을 보유로 봐요 (프로필은 복사본만)", function()
		local source = fs.readFile("src/server/ShopService.luau")
		t.ok(string.find(source, "Skins.isFree(equipped)", 1, true) ~= nil, "equippedOf uses isFree")
		t.ok(string.find(source, "owned = table.clone(owned)", 1, true) ~= nil, "copy, not profile")
		t.ok(OfferLogic ~= nil)
	end)

	---------------------------------------------------------------- 몸 (SushiBody 경로)
	t.test(
		"SushiBody.layout: 견본 게임 레이아웃, 발바닥 = GROUND_OFFSET, 파츠 ≤ 예외 상한, 겹침·떠 있음 0",
		function()
			t.ok(SushiBody.hasLayout(ID))
			t.eq(Sample.GAME_GROUND_OFFSET, SushiBody.GROUND_OFFSET)
			for _, expression in Sample.EXPRESSIONS do
				local layout = SushiBody.layout(ID, expression)
				local label = `{ID}/{expression}`
				t.eq(layout[1].name, "Body", label)
				t.eq(layout[1].rotation, nil, label)
				t.ok(#layout <= SushiBody.EXPERIMENTAL[ID].partBudget, `{label} parts {#layout}`)
				local b = SushiBody.bounds(layout)
				t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) < 1e-9, `{label} sole {b.min[2]}`)
				t.ok(b.max[2] <= SushiBody.NAME_TAG_HEIGHT - 0.4, `{label} below name tag {b.max[2]}`)
				t.eq(SushiBody.effectCount(layout), 0, `{label} no effects`)
				t.eq(LayoutCheck.zFight(layout), {}, `{label} z-fighting`)
				t.eq(LayoutCheck.floating(layout), {}, `{label} floating`)
				local names = {}
				for _, spec in layout do
					t.ok(names[spec.name] == nil, `{label} duplicate {spec.name}`)
					names[spec.name] = true
					if spec.attach then
						t.ok(
							names[spec.attach] ~= nil or byName(layout)[spec.attach] ~= nil,
							`{label} attach {spec.attach}`
						)
					end
				end
			end
			t.eq(#SushiBody.layout(ID), #SushiBody.layout(ID, "Default"))
			t.ok(#SushiBody.layout(ID) <= 44, "default trimmed (front stripes removed)")
		end
	)

	t.test(
		"표정: 실험 스킨만 바뀌고, 모르는 표정은 기본, 다른 스킨은 표정을 무시해요",
		function()
			local default = byName(SushiBody.layout(ID))
			local hurt = byName(SushiBody.layout(ID, "Hurt"))
			local happy = byName(SushiBody.layout(ID, "Happy"))
			t.ok(hurt.Bandage ~= nil and default.Bandage == nil, "hurt bandage")
			t.ok(happy.Shine == nil and happy.ShineLeft == nil, "happy ^ ^ eyes")
			t.eq(#SushiBody.layout(ID, "Nope"), #SushiBody.layout(ID))
			t.eq(SushiBody.layout("salmon", "Hurt"), SushiBody.layout("salmon"))
			t.eq(SushiBody.layout("tamago", "Happy"), SushiBody.layout("tamago"))
		end
	)

	t.test(
		"관절: 눈 2·감은 눈 2·발 2·팔 2 (m5-25 이름), 깜빡이면 눈이 숨고 감은 눈이 나와요",
		function()
			local layout = SushiBody.layout(ID)
			local joints = {}
			for _, spec in layout do
				if spec.joint then
					table.insert(joints, spec.name)
				end
			end
			table.sort(joints)
			t.eq(
				joints,
				{ "ArmLeft", "ArmRight", "EyeLeft", "EyeRight", "FootLeft", "FootRight", "LidLeft", "LidRight" }
			)
			local parts = byName(layout)
			for _, side in { "Left", "Right" } do
				t.eq(parts[`EyeLow{side}`].attach, `Eye{side}`)
				t.eq(parts[`Shine{side}`].attach, `Eye{side}`)
				for _, name in { `Eye{side}`, `EyeLow{side}`, `Shine{side}` } do
					t.ok(not hiddenInRice(parts[name], 0), `{name} visible at rest`)
					t.ok(hiddenInRice(parts[name], Anim.EYE_HIDE), `{name} hidden when blinking`)
				end
				t.ok(hiddenInRice(parts[`Lid{side}`], 0), `Lid{side} hidden at rest`)
				t.ok(not hiddenInRice(parts[`Lid{side}`], -Anim.LID_SHOW), `Lid{side} shows when blinking`)
			end
			-- 발 위끝은 밥 속 (몸에서 떨어져 보이지 않게): 걸음으로 FOOT_MIN만큼 내려가도 받침 아래끝(y -1.29) 위
			for _, side in { "Left", "Right" } do
				local lo, hi = LayoutCheck.box(parts[`Foot{side}`])
				t.ok(math.abs(lo[2] + SushiBody.GROUND_OFFSET) < 1e-9, `Foot{side} sole`)
				t.ok(hi[2] + Anim.FOOT_MIN >= -1.29 - 1e-9, `Foot{side} top {hi[2]}`)
			end
		end
	)

	t.test(
		"build: 진짜 Instance — Body만 고정, PartJoint Motor6D 8개, 나머지는 용접, 충돌·질량 없음",
		function()
			local Real = Shims.require(Shims.root("src/shared").SushiBody)
			for _, expression in { nil :: string?, "Hurt", "Happy" } do
				local model = Real.build(ID, expression)
				local layout = SushiBody.layout(ID, expression)
				local parts = model:GetChildren()
				t.eq(#parts, #layout, `{tostring(expression)} part count`)
				t.ok(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Body", "PrimaryPart")
				local motors = 0
				for _, part in parts do
					t.eq(part.Anchored, part.Name == "Body", `{part.Name} anchored`)
					t.eq(part.CanCollide, false, `{part.Name} collide`)
					t.eq(part.CanQuery, false, `{part.Name} query`)
					t.eq(part.CanTouch, false, `{part.Name} touch`)
					t.eq(part.Massless, true, `{part.Name} massless`)
					for _, child in part:GetChildren() do
						if child:IsA("Motor6D") then
							motors += 1
							t.eq(child.Name, SushiBody.PART_JOINT_NAME, `{part.Name} motor name`)
						end
					end
				end
				-- 감은 눈(^ ^, x x) 표정은 깜빡임 관절이 없어요: 발 2 + 팔 2
				local expected = if expression == nil then 8 else 4
				t.eq(motors, expected, `{tostring(expression)} motors`)
			end
		end
	)

	---------------------------------------------------------------- 움직임
	t.test("팔 흔들기: 서 있거나 넘어지면 0, 걸으면 왼발이 앞일 때 오른팔이 앞", function()
		local base = {
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
		t.eq(Anim.pose(base).armSwing, 0)
		local walking = table.clone(base)
		walking.walk = 1
		walking.idle = 0
		walking.phase = 0 -- cos = 1: 왼발 앞 (z < 0)
		local pose = Anim.pose(walking)
		t.ok(pose.footLeft.z < 0, "left foot forward")
		t.ok(pose.armSwing > 0, "right arm forward")
		t.ok(pose.armSwing <= Anim.ARM_SWING * 1.3 + 1e-9, "bounded")
		walking.knocked = true
		t.eq(Anim.pose(walking).armSwing, 0)
	end)

	t.test(
		"렌더 도구: 줄 세우기(lineup)가 Skins.LIST 전체를 SushiBody.build 경로로 그려요 (실험 스킨 포함)",
		function()
			local tool = fs.readFile("tools/render-character.luau")
			t.ok(string.find(tool, "for _, skin in Skins.LIST do", 1, true) ~= nil, "lineup iterates the catalog")
			t.ok(string.find(tool, "SushiBody.build(id)", 1, true) ~= nil, "same build as the game")
		end
	)

	t.test(
		"클라이언트: 팔 관절이 없는 스킨은 건너뛰고(nil 확인), 인형은 표정 이름을 넘겨요",
		function()
			local fx = fs.readFile("src/client/fx/CharacterFxController.luau")
			t.ok(string.find(fx, 'partJoint(model, "ArmLeft")', 1, true) ~= nil, "arm joints looked up")
			t.ok(string.find(fx, "if joint == nil then", 1, true) ~= nil, "nil-safe")
			local elim = fs.readFile("src/client/fx/EliminationCutsceneController.luau")
			t.ok(string.find(elim, 'SushiBody.build(appearanceId, "Hurt")', 1, true) ~= nil, "elimination doll hurt")
			local victory = fs.readFile("src/client/fx/VictoryCutsceneController.luau")
			t.ok(string.find(victory, 'pcall(SushiBody.build, appearanceId, "Happy")', 1, true) ~= nil, "victory happy")
		end
	)
end
