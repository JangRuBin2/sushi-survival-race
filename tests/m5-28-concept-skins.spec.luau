--!strict
-- m5-28 콘셉트 몸 실험 스킨 4종 (concept-tuna·shrimp·tamago·ikura): concept-salmon과 같은 밥·얼굴·팔다리·깜빡임 관절을
-- 쓰고 토핑만 달라요. 카탈로그·예외 범위, 저장 없이 모두가 가짐, 표정마다 파츠 ≤ 47·발바닥·겹침·떠 있음,
-- 진짜 Instance build, 공유 몸이 정말 같은지, 클라이언트 연결(표정 인형·팔 흔들기)이 이름으로 그대로 동작하는지.

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
local ProfileLogic = RobloxRequire.require(Shared.ProfileLogic)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local Anim = RobloxRequire.require(Shared.CharacterAnimLogic)
local Cutscene = RobloxRequire.require(Shared.EliminationCutsceneLogic)

-- id, 이름, 탈의실 순서, 토핑을 알아보는 파츠 (뒤 카메라에서 이 스킨이라고 읽히게 하는 것)
local NEW = {
	{ "concept-tuna", "콘셉트 참치초밥 (테스트)", 33, { "Ridge", "Marble1", "Marble4" } },
	{ "concept-shrimp", "콘셉트 새우초밥 (테스트)", 34, { "Ridge", "Band1", "TailMid" } },
	{ "concept-tamago", "콘셉트 계란초밥 (테스트)", 35, { "Topping", "NoriTop", "NoriBackStrip" } },
	{ "concept-ikura", "콘셉트 연어알 군함 (테스트)", 36, { "Wall", "RoeBed", "Roe1", "RoeTop1" } },
}
local SALMON = "concept-salmon"
local BUDGET = 47
local RICE_FRONT = -1.35 -- 콘셉트 밥 앞면 z

-- 표정·토핑과 무관하게 모든 콘셉트 스킨이 똑같아야 하는 파츠 (밥·받침·팔·다리)
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

local function byName(layout: { any }): { [string]: any }
	local map = {}
	for _, spec in layout do
		map[spec.name] = spec
	end
	return map
end

-- 얼굴 파츠 = 밥 앞면 앞(또는 그 근처 얇은 판)에 있는 표정 파츠. 토핑이 바뀌어도 이름·자리가 같아요
local FACE_PREFIXES = { "Eye", "Lid", "Shine", "Mouth", "Tongue", "Cheek", "Brow", "Sweat", "Bandage" }
local function isFace(name: string): boolean
	for _, prefix in FACE_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function sameSpec(t: Test.Test, a: any, b: any, label: string)
	t.eq(a.size, b.size, `{label} size`)
	t.eq(a.offset, b.offset, `{label} offset`)
	t.eq(a.rotation, b.rotation, `{label} rotation`)
	t.eq(a.color, b.color, `{label} color`)
	t.eq(a.material, b.material, `{label} material`)
	t.eq(a.shape, b.shape, `{label} shape`)
	t.eq(a.joint, b.joint, `{label} joint`)
	t.eq(a.attach, b.attach, `{label} attach`)
end

return function(t: Test.Test)
	---------------------------------------------------------------- 카탈로그·예외 범위
	t.test(
		"카탈로그: 새 4종 모두 무료 Basic 실험 스킨, 이름 '(테스트)', 순서 33~36, 대사 2줄",
		function()
			for _, row in NEW do
				local id = row[1]
				local skin = Skins.get(id)
				t.ok(skin ~= nil, `{id} in catalog`)
				t.eq(skin.displayName, row[2], `{id} name`)
				t.eq(skin.order, row[3], `{id} order`)
				t.eq(skin.tier, "Basic", `{id} tier`)
				t.eq(skin.experimental, true, `{id} experimental`)
				for _, field in { "robux", "coins", "tokens", "vipOnly", "season", "productId" } do
					t.eq((skin :: any)[field], nil, `{id} {field}`)
				end
				t.eq(#skin.speech, 2, `{id} speech`)
				t.eq(Cutscene.SKIN_LINES[id], skin.speech, `{id} elimination lines`)
				t.ok(string.find(skin.displayName, "(테스트)", 1, true) ~= nil, `{id} test suffix`)
			end
			-- 탈의실 "전체" 탭 맨 끝, concept-salmon 바로 다음
			local last = Skins.LIST[#Skins.LIST]
			t.eq(last.id, "concept-ikura")
			t.eq(Skins.get(SALMON).order, 32)
			local ok, problems = Skins.validate(Skins.LIST)
			t.ok(ok, table.concat(problems, "; "))
		end
	)

	t.test("예외 목록: Skins.EXPERIMENTAL_IDS = SushiBody.EXPERIMENTAL = 콘셉트 몸 SKIN_IDS (5종)", function()
		local expected = table.clone(Sample.SKIN_IDS)
		table.sort(expected)
		local function keys(map: { [string]: any }): { string }
			local list = {}
			for key in map do
				table.insert(list, key)
			end
			table.sort(list)
			return list
		end
		t.eq(#expected, 5)
		t.eq(keys(Skins.EXPERIMENTAL_IDS), expected)
		t.eq(keys(SushiBody.EXPERIMENTAL), expected)
		for _, id in Sample.SKIN_IDS do
			t.eq(SushiBody.EXPERIMENTAL[id].partBudget, BUDGET, id)
			t.eq(SushiBody.EXPERIMENTAL[id].expressions, Sample.EXPRESSIONS, id)
		end
	end)

	t.test(
		"validate: 새 실험 스킨에 가격·다른 등급을 붙이거나 SushiBody 예외가 없으면 잡아요",
		function()
			for _, row in NEW do
				local id = row[1]
				for _, change in { { "robux", 29 }, { "coins", 300 }, { "tier", "Common" }, { "vipOnly", true } } do
					local list = table.clone(Skins.LIST) :: { any }
					for i, skin in list do
						if skin.id == id then
							local copy = table.clone(skin)
							copy[change[1]] = change[2]
							list[i] = copy
						end
					end
					t.eq((Skins.validate(list)), false, `{id} {change[1]}`)
				end
			end
			-- 예외 목록에 없는 새 id에 experimental을 달면 잡아요 (범위가 명시적 목록뿐)
			local list = table.clone(Skins.LIST) :: { any }
			table.insert(list, {
				id = "concept-unagi",
				displayName = "x",
				tier = "Basic",
				experimental = true,
				speech = { "a" },
				order = 99,
			})
			local ok, problems = Skins.validate(list)
			t.eq(ok, false)
			t.ok(string.find(table.concat(problems, ";"), "experimental only for", 1, true) ~= nil, "id scope")
		end
	)

	---------------------------------------------------------------- 보유 (저장 없이)
	t.test(
		"보유: 새 프로필에서도 장착·'입기', 코인·로벅스로는 이미 가진 것, 저장에는 안 남아요",
		function()
			for _, row in NEW do
				local id = row[1]
				t.eq(Skins.isFree(id), true, id)
				t.eq(ShopLogic.canEquip(id, { tamago = true }), true, id)
				t.eq(select(2, ShopLogic.canEquip(id, { tamago = true }, true)), "Locked", id)
				local coin = ShopLogic.canBuyWithCoins(id, { coins = 9999, ownedSkins = { tamago = true } })
				t.eq(coin.reason, "AlreadyOwned", id)
				t.eq(
					select(2, ReceiptLogic.canRequest(id, { tamago = true }, { canSave = true, fake = true })),
					"AlreadyOwned"
				)
				local view = { coins = 0, equippedSkin = "tamago", ownedSkins = { "tamago" }, eventTokens = {} }
				local state = ShopLogic.cardState(Skins.get(id), view)
				t.eq(ShopLogic.cardButtonText(state), "입기", id)

				t.eq(ProfileSchema.new().ownedSkins[id], nil, `{id} not saved as owned`)
				local raw = ProfileSchema.new() :: any
				raw.equippedSkin = id
				local profile = ProfileLogic.migrate(raw)
				t.eq(profile.equippedSkin, id, `{id} equip kept`)
				t.eq(profile.ownedSkins[id], nil, `{id} still not owned in save`)
			end
		end
	)

	---------------------------------------------------------------- 몸
	t.test(
		"레이아웃: 표정마다 파츠 ≤ 47, 발바닥 = GROUND_OFFSET, 이름표 아래, 효과 0, 겹침·떠 있음 0",
		function()
			t.eq(Sample.GAME_GROUND_OFFSET, SushiBody.GROUND_OFFSET)
			for _, id in Sample.SKIN_IDS do
				t.ok(SushiBody.hasLayout(id), id)
				for _, expression in Sample.EXPRESSIONS do
					local layout = SushiBody.layout(id, expression)
					local label = `{id}/{expression}`
					t.eq(layout[1].name, "Body", label)
					t.ok(#layout <= BUDGET, `{label} parts {#layout}`)
					local b = SushiBody.bounds(layout)
					t.ok(math.abs(b.min[2] + SushiBody.GROUND_OFFSET) < 1e-9, `{label} sole {b.min[2]}`)
					t.ok(b.max[2] <= SushiBody.NAME_TAG_HEIGHT - 0.4, `{label} top {b.max[2]}`)
					t.eq(SushiBody.effectCount(layout), 0, `{label} effects`)
					t.eq(LayoutCheck.zFight(layout), {}, `{label} z-fighting`)
					t.eq(LayoutCheck.floating(layout), {}, `{label} floating`)
					local names = {}
					for _, spec in layout do
						t.ok(names[spec.name] == nil, `{label} duplicate {spec.name}`)
						names[spec.name] = true
						for axis = 1, 3 do
							t.ok(spec.size[axis] > 0, `{label} {spec.name} size`)
							t.ok(spec.color[axis] >= 0 and spec.color[axis] <= 255, `{label} {spec.name} color`)
						end
						if spec.shape == "Ball" then
							t.ok(
								spec.size[1] == spec.size[2] and spec.size[2] == spec.size[3],
								`{label} {spec.name} ball`
							)
						end
					end
					for _, spec in layout do
						if spec.attach then
							t.ok(names[spec.attach] ~= nil, `{label} attach {spec.attach}`)
						end
					end
				end
				-- 기본(표정 없음) = Default, 모르는 표정은 기본
				t.eq(SushiBody.layout(id), SushiBody.layout(id, "Default"), id)
				t.eq(SushiBody.layout(id, "Nope"), SushiBody.layout(id, "Default"), id)
			end
		end
	)

	t.test(
		"공유 몸: 밥·받침·팔·다리·얼굴(표정별)이 concept-salmon과 완전히 같고 토핑만 달라요",
		function()
			for _, row in NEW do
				local id = row[1]
				for _, expression in Sample.EXPRESSIONS do
					local mine = byName(SushiBody.layout(id, expression))
					local salmon = byName(SushiBody.layout(SALMON, expression))
					local label = `{id}/{expression}`
					for _, name in SHARED_BODY do
						t.ok(mine[name] ~= nil, `{label} has {name}`)
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
					for _, name in row[4] do
						t.ok(mine[name] ~= nil, `{label} topping {name}`)
					end
				end
			end
		end
	)

	-- 높이 y에서 파츠가 가장 앞으로 나온 z (모양 반영: 축 X 원기둥·공은 원 단면, 그 밖은 외곽 상자). 그 높이에 없으면 nil
	local function frontAt(spec: any, y: number): number?
		local lo, hi = LayoutCheck.box(spec)
		if y < lo[2] or y > hi[2] then
			return nil
		end
		local round = spec.rotation == nil and (spec.shape == "Ball" or spec.shape == "Cylinder")
		if not round then
			return lo[3]
		end
		local r = spec.size[2] / 2
		local dy = y - spec.offset[2]
		return spec.offset[3] - math.sqrt(math.max(0, r * r - dy * dy))
	end

	t.test(
		"토핑이 얼굴을 안 가려요: 얼굴 높이(입 -0.75 ~ 눈 위 0.3)에서 토핑 파츠는 밥 앞면보다 앞으로 안 나와요",
		function()
			for _, id in Sample.SKIN_IDS do
				for _, spec in SushiBody.layout(id) do
					if not isFace(spec.name) and table.find(SHARED_BODY, spec.name) == nil then
						for step = 0, 21 do
							local y = -0.75 + step * 0.05
							local z = frontAt(spec, y)
							t.ok(
								z == nil or z >= RICE_FRONT - 1e-6,
								`{id} {spec.name} in front of the face at y {y} (z {z})`
							)
						end
					end
				end
			end
		end
	)

	t.test(
		"관절: 눈 2·감은 눈 2·발 2·팔 2, 깜빡이면 눈이 숨고 감은 눈이 나와요 (m5-25 이름 그대로)",
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
				-- 감은 눈 표정(신남·아픔)은 깜빡임 관절이 없어요: 팔 2 + 발 2
				for _, expression in { "Happy", "Hurt" } do
					local count = 0
					for _, spec in SushiBody.layout(id, expression) do
						if spec.joint then
							count += 1
						end
					end
					t.eq(count, 4, `{id}/{expression} joints`)
				end
			end
		end
	)

	t.test(
		"build: 진짜 Instance — 파츠 수 = 레이아웃, Body만 고정, PartJoint Motor6D, 충돌·질량 없음",
		function()
			local Real = Shims.require(Shims.root("src/shared").SushiBody)
			for _, row in NEW do
				local id = row[1]
				for _, expression in { nil :: string?, "Happy", "Flustered", "Hurt" } do
					local label = `{id}/{tostring(expression)}`
					local model = Real.build(id, expression)
					local layout = SushiBody.layout(id, expression)
					local parts = model:GetChildren()
					t.eq(#parts, #layout, `{label} part count`)
					t.ok(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Body", `{label} PrimaryPart`)
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
					local expected = if expression == nil or expression == "Flustered" then 8 else 4
					t.eq(motors, expected, `{label} motors`)
				end
			end
		end
	)

	t.test(
		"견본 경로: SushiConceptSample.layout/build도 스킨 id를 받고, 모르는 id는 오류, 연어가 기본",
		function()
			t.eq(Sample.layout(), Sample.layout(nil, nil, SALMON))
			t.eq(Sample.gameLayout("Hurt"), Sample.gameLayout("Hurt", SALMON))
			for _, row in NEW do
				for _, pose in Sample.POSES do
					local layout = Sample.layout("Default", pose, row[1])
					t.eq(LayoutCheck.zFight(layout), {}, `{row[1]}/{pose} sample z-fighting`)
					t.eq(LayoutCheck.floating(layout), {}, `{row[1]}/{pose} sample floating`)
				end
			end
			t.ok(not pcall(Sample.gameLayout, "Default", "concept-nope"), "unknown concept skin errors")
			t.ok(not pcall(Sample.layout, "Default", "Stand", "tamago"), "regular skin is not a concept skin")
		end
	)

	t.test(
		"SushiBody: 여전히 SushiConceptSample 하나만 require하고, 콘셉트 id 목록은 그 모듈에서 와요",
		function()
			local source = fs.readFile("src/shared/SushiBody.luau")
			local _, count = string.gsub(source, "require%(", "")
			t.eq(count, 1)
			t.ok(string.find(source, "SushiConceptSample.SKIN_IDS", 1, true) ~= nil, "ids from the sample module")
			local sample = fs.readFile("src/shared/SushiConceptSample.luau")
			t.ok(string.find(sample, "require(", 1, true) == nil, "sample requires nothing")
		end
	)

	---------------------------------------------------------------- 클라이언트 연결
	t.test(
		"클라이언트: 인형 표정·팔 흔들기는 id가 아니라 이름(관절)으로 동작 — 새 스킨도 코드 변경 없이 같아요",
		function()
			local fx = fs.readFile("src/client/fx/CharacterFxController.luau")
			t.ok(string.find(fx, 'partJoint(model, "ArmLeft")', 1, true) ~= nil, "arm joints by name")
			t.ok(string.find(fx, '"concept-', 1, true) == nil, "no id check in the controller")
			for _, path in
				{
					"src/client/fx/EliminationCutsceneController.luau",
					"src/client/fx/VictoryCutsceneController.luau",
					"src/client/fx/LobbyFxController.luau",
				}
			do
				local source = fs.readFile(path)
				t.ok(string.find(source, '"concept-', 1, true) == nil, `{path} has no concept id check`)
			end
			t.ok(
				string.find(fs.readFile("src/client/fx/EliminationCutsceneController.luau"), '"Hurt"', 1, true) ~= nil,
				"elimination doll hurt"
			)
			t.ok(
				string.find(fs.readFile("src/client/fx/VictoryCutsceneController.luau"), '"Happy"', 1, true) ~= nil,
				"victory doll happy"
			)
			-- 서버도 id를 따로 보지 않아요 (외형은 AppearanceService 한 곳, SushiBody.build)
			local appearance = fs.readFile("src/server/AppearanceService.luau")
			t.ok(string.find(appearance, '"concept-', 1, true) == nil, "server has no concept id check")
		end
	)

	t.test("렌더 도구: --sample <콘셉트 스킨 id>로 그 토핑의 그림 묶음을 그려요", function()
		local tool = fs.readFile("tools/render-character.luau")
		t.ok(string.find(tool, "ConceptSample.SKIN_IDS", 1, true) ~= nil, "validates concept skin ids")
		t.ok(string.find(tool, "ConceptSample.build(expression, pose, skinId)", 1, true) ~= nil, "builds by skin")
	end)
end
