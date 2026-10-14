--!strict
-- m5-29 콘셉트 몸 실험 스킨 2차 4종 (concept-unagi·uni·tako·inari): m5-28과 같은 밥·얼굴·팔다리·깜빡임 관절에
-- 토핑만 달라요. 유부만 예외 — 공유 밥·받침 파츠의 색·재질이 유부(크기·위치는 같음), 입 덮개도 그 색을 따라가요.
-- 카탈로그·대사, 저장 없이 모두가 가짐, 공유 몸, 유부 예외, 외곽 폭, 관절·깜빡임, 진짜 Instance build, 견본 경로.
-- 표정마다 파츠 ≤ 70·발바닥·이름표·겹침·떠 있음과 "토핑이 얼굴을 안 가려요"는 m5-28 테스트가 SKIN_IDS 전체로 봐요.

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
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)

-- id, 이름, 순서, 대사, 토핑을 알아보는 파츠
local NEW = {
	{
		"concept-unagi",
		"장어초밥 (특)",
		37,
		{ "소스가 너무 미끄러웠어!", "지글지글 구운 장어~" },
		{ "Band", "Eel", "Glaze", "Grill1", "Sesame1", "NoriTop", "NoriFront", "NoriBack", "NoriBackLow" },
	},
	{
		"concept-uni",
		"성게 군함 (특)",
		38,
		{ "성게가 흘러내려…", "김 그릇 꽉 잡아!" },
		{ "Band", "UniBed", "Lobe1", "Lobe10Back", "Leaf1", "LeafMid" },
	},
	{
		"concept-tako",
		"문어초밥 (특)",
		39,
		{ "빨판으로 붙어 볼걸…", "쫄깃쫄깃 문어 출동!" },
		{ "Ridge", "SkinLeft", "Sucker1", "Sucker1In", "Cut1", "NoriRidge" },
	},
	{
		"concept-inari",
		"유부초밥 (특)",
		40,
		{ "주머니에서 밥이 샜어!", "달콤한 유부 속으로~" },
		{ "LipFront", "InariRice", "InariCrease1", "InariSeed1" },
	},
}
local INARI = "concept-inari"
local SALMON = "concept-salmon"
local RICE_FRONT = -1.35
local MAX_WIDTH = 4.76 -- 콘셉트 공통 외곽 폭 (팔 포함)

local SHARED_BODY = {
	"Body",
	"BodyWide",
	"BodyCorner1",
	"BodyCorner2",
	"BodyCorner3",
	"BodyCorner4",
	"BodyBase",
	"BodyBaseWide",
	"ArmLeft",
	"ArmRight",
	"FootLeft",
	"FootRight",
}
-- 유부가 색·재질만 바꾸는 공유 파츠 (밥 6 + 받침 2)와 그 색을 따라가는 입 덮개
local POUCH =
	{ "Body", "BodyWide", "BodyCorner1", "BodyCorner2", "BodyCorner3", "BodyCorner4", "BodyBase", "BodyBaseWide" }

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

local function sameShape(t: Test.Test, a: any, b: any, label: string)
	t.eq(a.size, b.size, `{label} size`)
	t.eq(a.offset, b.offset, `{label} offset`)
	t.eq(a.rotation, b.rotation, `{label} rotation`)
	t.eq(a.shape, b.shape, `{label} shape`)
	t.eq(a.joint, b.joint, `{label} joint`)
	t.eq(a.attach, b.attach, `{label} attach`)
end

local function sameSpec(t: Test.Test, a: any, b: any, label: string)
	sameShape(t, a, b, label)
	t.eq(a.color, b.color, `{label} color`)
	t.eq(a.material, b.material, `{label} material`)
end

return function(t: Test.Test)
	t.test(
		"카탈로그: 새 4종 Basic 뽑기 전용 특 스킨, 이름 '(특)', 순서 37~40(맨 끝), 대사 2줄 (AC1, m5-31 이름·draw)",
		function()
			for _, row in NEW do
				local id = row[1]
				local skin = Skins.get(id)
				t.ok(skin ~= nil, `{id} in catalog`)
				t.eq(skin.displayName, row[2], `{id} name`)
				t.eq(skin.order, row[3], `{id} order`)
				t.eq(skin.speech, row[4], `{id} speech`)
				t.eq(Cutscene.SKIN_LINES[id], row[4], `{id} elimination lines`)
				t.eq(skin.tier, "Basic", `{id} tier`)
				t.eq(skin.conceptBody, true, `{id} conceptBody`)
				t.ok(Skins.drawGradeOf(id) ~= nil, `{id} drawGrade`)
				for _, field in { "robux", "coins", "tokens", "vipOnly", "season", "productId" } do
					t.eq((skin :: any)[field], nil, `{id} {field}`)
				end
			end
			local tail = {}
			for i = #Skins.LIST - 3, #Skins.LIST do
				table.insert(tail, Skins.LIST[i].id)
			end
			t.eq(tail, { "concept-unagi", "concept-uni", "concept-tako", "concept-inari" })
			t.eq(Skins.LIST[#Skins.LIST - 4].id, "concept-ikura")
			t.eq(#Skins.LIST, 40)
			t.eq(#Skins.byTier("Basic"), 10)
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("validate: 새 스킨에 가격·다른 등급을 붙이면 잡아요 (AC2)", function()
		for _, row in NEW do
			for _, patch in { { robux = 29 }, { coins = 300 }, { tier = "Rare" } } do
				local list = table.clone(Skins.LIST)
				for i, skin in list do
					if skin.id == row[1] then
						local copy = table.clone(skin) :: any
						for key, value in patch do
							copy[key] = value
						end
						list[i] = copy
					end
				end
				t.eq((Skins.validate(list)), false, `{row[1]} with {next(patch)}`)
			end
		end
	end)

	t.test(
		"보유: 새 프로필은 미보유('🎫 뽑기로 얻기'·NotOwned), 살 수 없음, 뽑기로 보유하면 장착·'입기' (AC3, m5-31)",
		function()
			for _, row in NEW do
				local id = row[1]
				t.eq(Skins.isFree(id), false, id)
				t.eq(Skins.isDraw(id), true, id)
				t.eq(select(2, ShopLogic.canEquip(id, { tamago = true })), "NotOwned", id)
				t.eq(ShopLogic.canEquip(id, { tamago = true, [id] = true }), true, id)
				local coin = ShopLogic.canBuyWithCoins(id, { coins = 9999, ownedSkins = { tamago = true } } :: any)
				t.eq(coin.reason, "NotForCoins", id)
				t.eq(
					select(2, ReceiptLogic.canRequest(id, { tamago = true }, { canSave = true, fake = true })),
					"NotRobux",
					id
				)
				local view = { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
				t.eq(ShopLogic.cardButtonText(ShopLogic.cardState(Skins.get(id), view)), "🎫 뽑기로 얻기", id)
				local ownedView =
					{ coins = 0, equippedSkin = "tamago", ownedSkins = { id, "tamago" }, eventTokens = {} }
				t.eq(ShopLogic.cardButtonText(ShopLogic.cardState(Skins.get(id), ownedView)), "입기", id)
				t.eq(ProfileSchema.new().ownedSkins[id], nil, `{id} not owned in a new profile`)
				local raw = ProfileSchema.new() :: any
				raw.equippedSkin = id
				local profile = ProfileLogic.migrate(raw)
				t.eq(profile.equippedSkin, "tamago", `{id} unowned equip falls back`)
				raw.ownedSkins[id] = true
				t.eq(ProfileLogic.migrate(raw).equippedSkin, id, `{id} owned equip kept`)
			end
		end
	)

	t.test(
		"공유 몸: 장어·성게·문어는 밥·받침·팔·다리·얼굴이 concept-salmon과 완전히 같아요 (AC5)",
		function()
			for _, row in NEW do
				local id = row[1]
				if id == INARI then
					continue
				end
				for _, expression in Sample.EXPRESSIONS do
					local mine = byName(SushiBody.layout(id, expression))
					local salmon = byName(SushiBody.layout(SALMON, expression))
					local label = `{id}/{expression}`
					for _, name in SHARED_BODY do
						sameSpec(t, mine[name], salmon[name], `{label} {name}`)
					end
					for name, spec in salmon do
						if isFace(name) then
							t.ok(mine[name] ~= nil, `{label} face {name}`)
							sameSpec(t, mine[name], spec, `{label} face {name}`)
						end
					end
					for name in mine do
						if isFace(name) then
							t.ok(salmon[name] ~= nil, `{label} extra face part {name}`)
						end
					end
					for _, name in row[5] do
						t.ok(mine[name] ~= nil, `{label} topping {name}`)
					end
				end
			end
		end
	)

	t.test(
		"유부 예외: 밥·받침은 크기·위치가 같고 색·재질만 유부, 입 덮개도 그 색, 나머지 얼굴·팔·다리는 같아요 (AC5)",
		function()
			for _, expression in Sample.EXPRESSIONS do
				local mine = byName(SushiBody.layout(INARI, expression))
				local salmon = byName(SushiBody.layout(SALMON, expression))
				local label = `{INARI}/{expression}`
				local pouch = mine.Body
				t.ok(pouch.color[1] ~= salmon.Body.color[1] or pouch.color[3] ~= salmon.Body.color[3], "pouch color")
				for _, name in POUCH do
					sameShape(t, mine[name], salmon[name], `{label} {name}`)
					t.eq(mine[name].color, pouch.color, `{label} {name} pouch color`)
					t.eq(mine[name].material, pouch.material, `{label} {name} pouch material`)
				end
				for _, name in { "ArmLeft", "ArmRight", "FootLeft", "FootRight" } do
					sameSpec(t, mine[name], salmon[name], `{label} {name}`)
				end
				for name, spec in salmon do
					if isFace(name) then
						t.ok(mine[name] ~= nil, `{label} face {name}`)
						if name == "MouthCover" then
							-- 입 원판 윗변을 가리는 덮개는 밥 앞면 색이어야 해요 (흰 덮개가 유부 위에 네모로 보였어요)
							sameShape(t, mine[name], spec, `{label} {name}`)
							t.eq(mine[name].color, pouch.color, `{label} {name} color`)
						else
							sameSpec(t, mine[name], spec, `{label} face {name}`)
						end
					end
				end
				for _, name in NEW[4][5] do
					t.ok(mine[name] ~= nil, `{label} pouch part {name}`)
				end
			end
		end
	)

	t.test(
		"외곽 폭: 새 4종 모두 콘셉트 공통 폭 4.76 이하 (AC5 — 얼굴 가림은 m5-28 테스트가 단면 모양으로 9종 모두 봐요)",
		function()
			for _, row in NEW do
				for _, expression in Sample.EXPRESSIONS do
					local layout = SushiBody.layout(row[1], expression)
					local b = SushiBody.bounds(layout)
					t.ok(b.max[1] - b.min[1] <= MAX_WIDTH + 1e-9, `{row[1]}/{expression} width {b.max[1] - b.min[1]}`)
				end
			end
		end
	)

	t.test("구분: 성게는 둥근 알·오이가 없고, 장어 판은 윤기(Glass)예요 (AC12 보조)", function()
		local uni = byName(SushiBody.layout("concept-uni"))
		for name in uni do
			t.ok(string.sub(name, 1, 3) ~= "Roe" and name ~= "Cucumber", `uni {name}`)
		end
		local unagi = byName(SushiBody.layout("concept-unagi"))
		t.eq(unagi.Glaze.material, "Glass") -- m5-30: 구운 살 판 위 타레 소스 층
	end)

	t.test(
		"관절: 눈 2·감은 눈 2·발 2·팔 2, 깜빡이면 눈이 숨고 감은 눈이 나와요 (AC6)",
		function()
			for _, row in NEW do
				local id = row[1]
				local layout = SushiBody.layout(id)
				local joints = {}
				for _, spec in layout do
					if spec.joint then
						table.insert(joints, spec.name)
					end
				end
				table.sort(joints)
				t.eq(
					joints,
					{ "ArmLeft", "ArmRight", "EyeLeft", "EyeRight", "FootLeft", "FootRight", "LidLeft", "LidRight" },
					id
				)
				local parts = byName(layout)
				for _, side in { "Left", "Right" } do
					local eyeLo = LayoutCheck.box(parts[`Eye{side}`])
					t.ok(eyeLo[3] < RICE_FRONT, `{id} Eye{side} visible at rest`)
					t.ok(eyeLo[3] + Anim.EYE_HIDE >= RICE_FRONT - 1e-9, `{id} Eye{side} hidden when blinking`)
					local lidLo = LayoutCheck.box(parts[`Lid{side}`])
					t.ok(lidLo[3] >= RICE_FRONT - 1e-9, `{id} Lid{side} hidden at rest`)
					t.ok(lidLo[3] - Anim.LID_SHOW < RICE_FRONT, `{id} Lid{side} shows when blinking`)
					local lo, hi = LayoutCheck.box(parts[`Foot{side}`])
					t.ok(math.abs(lo[2] + SushiBody.GROUND_OFFSET) < 1e-9, `{id} Foot{side} sole`)
					t.ok(hi[2] + Anim.FOOT_MIN >= -1.29 - 1e-9, `{id} Foot{side} top`)
				end
			end
		end
	)

	t.test(
		"build: 진짜 Instance — Body만 고정, PartJoint Motor6D(기본·당황 8, 신남·아픔 4), 충돌·질량 없음 (AC6)",
		function()
			local Real = Shims.require(Shims.root("src/shared").SushiBody)
			for _, row in NEW do
				local id = row[1]
				for _, expression in { nil :: string?, "Happy", "Flustered", "Hurt" } do
					local label = `{id}/{tostring(expression)}`
					local model = Real.build(id, expression)
					local parts = model:GetChildren()
					t.eq(#parts, #SushiBody.layout(id, expression), `{label} part count`)
					local motors = 0
					for _, part in parts do
						t.eq(part.Anchored, part.Name == "Body", `{label} {part.Name} anchored`)
						t.eq(part.CanCollide, false, `{label} {part.Name} collide`)
						t.eq(part.CanQuery, false, `{label} {part.Name} query`)
						t.eq(part.CanTouch, false, `{label} {part.Name} touch`)
						t.eq(part.Massless, true, `{label} {part.Name} massless`)
						for _, child in part:GetChildren() do
							if child:IsA("Motor6D") then
								motors += 1
								t.eq(child.Name, SushiBody.PART_JOINT_NAME, `{label} {part.Name} motor`)
							end
						end
					end
					t.eq(motors, if expression == nil or expression == "Flustered" then 8 else 4, `{label} motors`)
				end
			end
		end
	)

	t.test("견본 경로: 새 4종 견본(서기·달리기)도 겹침·떠 있음 0", function()
		for _, row in NEW do
			for _, pose in Sample.POSES do
				local layout = Sample.layout("Default", pose, row[1])
				t.eq(LayoutCheck.zFight(layout), {}, `{row[1]}/{pose} sample z-fighting`)
				t.eq(LayoutCheck.floating(layout), {}, `{row[1]}/{pose} sample floating`)
			end
		end
	end)
end
