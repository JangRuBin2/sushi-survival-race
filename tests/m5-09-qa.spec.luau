--!strict
-- m5-09 QA: 연출 팩(고양이 손님·불꽃놀이) 경계값 + 소품 한도·정리를 가짜 Roblox 환경(tools/render/Shims)에서 직접 확인
-- + 클라이언트 연출이 판정·서버에 영향을 주지 않는지 정적 확인.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local ElimLogic = RobloxRequire.require(Shared.EliminationCutsceneLogic)
local VicLogic = RobloxRequire.require(Shared.VictoryCutsceneLogic)
local FxCatalog = RobloxRequire.require(Shared.FxCatalog)
local Config = RobloxRequire.require(Shared.Config)
local SfxCues = RobloxRequire.require(Shared.SfxCues)

-- 클라이언트 소품을 Shims로 불러와요. VictoryProps는 ReplicatedStorage.Shared가 필요해서 game을 잠깐 감싸요.
local client = Shims.root("src/client")
local sharedShim = Shims.root("src/shared")
local Props = Shims.require(client.fx.CutsceneProps)
local realGame = Shims.globals.game
Shims.globals.game = {
	GetService = function(_self: any, name: string): any
		if name == "ReplicatedStorage" then
			return { Shared = sharedShim }
		end
		return realGame:GetService(name)
	end,
	Workspace = realGame.Workspace,
}
local VictoryProps = Shims.require(client.fx.VictoryProps)
Shims.globals.game = realGame

local CFrame = Shims.globals.CFrame
local Vector3 = Shims.globals.Vector3
local Color3 = Shims.globals.Color3

local function count(root: any, className: string): number
	local n = if root:IsA(className) then 1 else 0
	for _, d in root:GetDescendants() do
		if d:IsA(className) then
			n += 1
		end
	end
	return n
end

local function descendants(root: any): number
	return #root:GetDescendants()
end

local function stripComments(source: string): string
	local noBlock = string.gsub(source, "%-%-%[%[.-%]%]", "")
	return (string.gsub(noBlock, "%-%-[^\n]*", ""))
end

local CLIENT_FILES = {
	"src/client/fx/EliminationCutsceneController.luau",
	"src/client/fx/CutsceneProps.luau",
	"src/client/fx/VictoryCutsceneController.luau",
	"src/client/fx/VictoryProps.luau",
}

return function(t: Test.Test)
	-- ── 속성 값 → 연출 (모르는 값은 기본) ───────────────────────────────
	t.test("skinFor/extraFor: 이상한 속성 값은 모두 기본", function()
		for _, value in { "Cat", "CAT-CUSTOMER", " cat-customer", "cat-customer ", "Default", {}, 1, false, true } do
			t.eq(ElimLogic.skinFor(value), "Default", tostring(value))
			t.eq(VicLogic.extraFor(value), "None", tostring(value))
		end
		t.eq(VicLogic.extraFor("Fireworks"), "None", "대소문자 다름")
		t.eq(VicLogic.extraFor(""), "None")
	end)

	t.test("skinFor/extraFor: FxCatalog의 모든 연출이 자기 slot에서만 반응", function()
		for _, fx in FxCatalog.LIST do
			if fx.slot == "Elimination" then
				t.eq(VicLogic.extraFor(fx.id), "None", `{fx.id}는 우승 연출 아님`)
			else
				t.eq(ElimLogic.skinFor(fx.id), "Default", `{fx.id}는 탈락 연출 아님`)
			end
		end
		-- 카탈로그 id와 계약 (m5-08이 profile.equippedFx[slot] = FxCatalog id로 속성을 달아요)
		t.eq((FxCatalog.get("cat-customer") :: any).slot, "Elimination")
		t.eq((FxCatalog.get("fireworks") :: any).slot, "Victory")
	end)

	-- ── 옛 호출 모양 그대로 ─────────────────────────────────────────────
	t.test("옛 호출(인자 생략)은 기본과 같고 nil fxSkin도 기본", function()
		for _, variant in { "Chopsticks", "Mouth", "ChefHand" } do
			for _, duration in { 1.5, 3, 6 } do
				t.eq(ElimLogic.timeline(variant, duration, nil), ElimLogic.timeline(variant, duration), variant)
				t.eq(ElimLogic.timeline(variant, duration, "Default"), ElimLogic.timeline(variant, duration))
			end
			t.eq(ElimLogic.linesFor("tamago", variant, nil), ElimLogic.linesFor("tamago", variant))
			t.eq(ElimLogic.linesFor(nil, variant, nil), ElimLogic.linesFor(nil, variant))
		end
		t.eq(
			ElimLogic.timeline("Mouth", nil, "Cat")[1].at,
			ElimLogic.timeline("Mouth", 3, "Cat")[1].at,
			"길이 nil = 3초"
		)
	end)

	t.test("고양이 박자: 길이를 늘이고 줄여도 CatMeow는 한 번, 길이 안, cue는 SfxCues", function()
		for _, duration in { 0.5, 1, 2, 3, 4.5, 9 } do
			for _, variant in { "Chopsticks", "Mouth", "ChefHand" } do
				local beats = ElimLogic.timeline(variant, duration, "Cat")
				local meows = 0
				local last = -1
				for _, beat in beats do
					if beat.cue == "CatMeow" then
						meows += 1
					end
					t.ok(SfxCues.isEffect(beat.cue), `{beat.cue} cue`)
					t.ok(beat.at >= last and beat.at <= duration, `{variant}/{duration} 순서·길이`)
					last = beat.at
				end
				t.eq(meows, 1, `{variant}/{duration}`)
			end
		end
	end)

	-- ── 불꽃 박자 (설정 길이) ───────────────────────────────────────────
	t.test(
		"불꽃: 설정 길이에서 간격 ≥ 0.4, 이미터 재사용 전에 앞 불티가 다 사라짐",
		function()
			local duration = Config.Match.VictoryCutscene
			local list = VicLogic.fireworksTimeline(duration)
			t.eq(#list, VicLogic.FIREWORK_COUNT)
			t.eq(VicLogic.FIREWORK_COUNT, 6)
			for i = 2, #list do
				t.ok(list[i] - list[i - 1] >= 0.4, `간격 {list[i] - list[i - 1]}`)
			end
			-- VictoryProps: 이미터 3개를 돌려 써요. 같은 이미터의 다음 불꽃까지 불티 수명(최대 1.2초)보다 길어야
			-- 이미 날아간 불티의 색이 바뀌지 않아요.
			for i = 4, #list do
				t.ok(list[i] - list[i - 3] > 1.2, `#{i} 재사용 간격 {list[i] - list[i - 3]}`)
			end
			t.ok(list[1] >= VicLogic.splashTime(duration), "풍덩 뒤")
			t.ok(list[#list] + VicLogic.FLASH_TIME <= duration, "마지막 섬광이 연출 안에서 끝")
			-- 같은 cue 간격 제한(Sfx SAME_CUE_GAP)보다 길어서 매번 울려요
			local sfxSource = fs.readFile("src/client/Sfx.luau")
			local gap = tonumber(string.match(sfxSource, "SAME_CUE_GAP%s*=%s*([%d%.]+)"))
			t.ok(gap ~= nil and gap < 0.4, `SAME_CUE_GAP {gap}`)
		end
	)

	t.test("불꽃: fireworks()는 매번 새 표 (자리 표를 바꿔도 원본 그대로)", function()
		local a = VicLogic.fireworks(6)
		a[1].position[1] = 9999
		local b = VicLogic.fireworks(6)
		t.ok(b[1].position[1] ~= 9999)
	end)

	-- ── 고양이 소품 (Shims) ─────────────────────────────────────────────
	t.test(
		"고양이 소품: 파츠 수 = 기본 + 20 이하, 모두 Anchored·충돌·쿼리·터치 없음",
		function()
			local pairsToCheck = {
				{
					name = "Chopsticks",
					base = { Props.chopsticks(), Props.mouth() },
					cat = { Props.catChopsticks(), Props.catHead() },
				},
				{ name = "Mouth", base = { Props.mouth() }, cat = { Props.catHead() } },
				{ name = "ChefHand", base = { Props.chefHand() }, cat = { Props.catPaw() } },
			}
			for _, entry in pairsToCheck do
				local baseParts, catParts = 0, 0
				for _, m in entry.base do
					baseParts += count(m, "BasePart")
				end
				for _, m in entry.cat do
					catParts += count(m, "BasePart")
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							t.ok(
								d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch,
								`{entry.name} {d.Name}`
							)
						end
						t.ok(
							not d:IsA("ParticleEmitter") and not d:IsA("Light") and not d:IsA("Sound"),
							`{entry.name} {d.ClassName}`
						)
						t.ok(not d:IsA("Script") and not d:IsA("LocalScript"), `{entry.name} 스크립트 없음`)
					end
				end
				t.ok(catParts - baseParts <= 20, `{entry.name}: 기본 {baseParts} + {catParts - baseParts}`)
				t.ok(catParts > 0)
			end
		end
	)

	t.test(
		"고양이 소품: pose를 여러 프레임 돌려도 인스턴스가 늘지 않아요 (프레임마다 새로 안 만듦)",
		function()
			local sticks = Props.catChopsticks()
			local head = Props.catHead()
			local paw = Props.catPaw()
			local before = { descendants(sticks), descendants(head), descendants(paw) }
			for i = 0, 90 do
				local tt = i / 30
				local amount = (i % 11) / 10
				Props.poseCatChopsticks(sticks, Vector3.new(0, 6, 0), amount, tt)
				Props.poseCatHead(head, CFrame.lookAt(Vector3.new(-7, 7, 0), Vector3.new(-6, 7, 0)), amount, tt)
				Props.poseCatHead(head, CFrame.new(0, -10, 0) * CFrame.Angles(math.rad(90), 0, 0), amount, tt)
				Props.poseCatPaw(paw, CFrame.new(0, 20 - tt * 5, 0), amount, tt)
			end
			t.eq({ descendants(sticks), descendants(head), descendants(paw) }, before)
			-- open/grip 범위 밖 값도 에러 없이
			Props.poseCatHead(head, CFrame.new(), -0.5, 0)
			Props.poseCatHead(head, CFrame.new(), 1.5, 0)
			Props.poseCatPaw(paw, CFrame.new(), 2, 0)
			Props.poseCatChopsticks(sticks, Vector3.zero, -1, 0)
		end
	)

	-- ── 불꽃 소품 (Shims) ───────────────────────────────────────────────
	t.test(
		"불꽃 소품: 이미터 3·조명 2 이하, 장면 Model 밑, 파츠는 충돌 없음, 터뜨려도 인스턴스가 늘지 않아요",
		function()
			local props = VictoryProps.build(CFrame.new(0, 1000, 3000))
			local beforeScene = descendants(props.model)
			local fw = VictoryProps.buildFireworks(props)
			t.ok(fw.rig:IsDescendantOf(props.model), "장면 Model 밑 (장면째 지워져요)")
			local folder = props.model:FindFirstChild("Fireworks")
			t.ok(folder ~= nil)
			t.eq(count(props.model, "ParticleEmitter"), 3, "이미터 3개")
			t.eq(count(props.model, "Light"), 2, "조명 2개 (장면 기본 소품엔 조명 없음)")
			t.ok(count(folder, "BasePart") <= 4, "받침·로켓 2·섬광")
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") then
					t.ok(d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name)
				end
			end
			local added = descendants(props.model)
			t.ok(added > beforeScene)
			-- 6번 터뜨리고 로켓·섬광·빛을 프레임마다 놓아도 새 인스턴스 없음 (Emit은 Shims에 없을 수 있어 pcall)
			for i, firework in VicLogic.fireworks(6) do
				local color = Color3.fromRGB(table.unpack(VicLogic.fireworkColor(firework.color)))
				pcall(
					VictoryProps.burstFirework,
					fw,
					i,
					Vector3.new(0, 1000, 2940),
					color,
					firework.radius,
					firework.big
				)
				pcall(VictoryProps.poseRocket, fw, i, Vector3.new(0, 1000, 2950), color, true)
				VictoryProps.poseRocket(fw, i, nil, color, false)
				VictoryProps.poseFlash(fw, Vector3.new(0, 1000, 2940), color, firework.radius, 1, 1)
				VictoryProps.poseFlash(fw, Vector3.new(0, 1000, 2940), color, firework.radius, 0, 0)
				VictoryProps.poseGlow(fw, i, Vector3.new(0, 1000, 2950), color, 0.5)
				VictoryProps.poseGlow(fw, i, Vector3.new(0, 1000, 2950), color, 0)
			end
			t.eq(descendants(props.model), added, "터뜨린 뒤에도 같은 수")
			for _, light in fw.lights do
				t.eq(light.Enabled, false, "빛 0이면 꺼짐")
				t.eq(light.Shadows, false, "그림자 없음 (모바일)")
			end
			t.eq(fw.flash.Transparency, 1, "섬광 숨김")
			props.model:Destroy()
		end
	)

	-- ── 정적 확인: 판정·서버 영향 없음 ─────────────────────────────────
	t.test("연출 클라이언트 코드: 리모트 보내기·속성 쓰기·판정 모듈 없음", function()
		for _, path in CLIENT_FILES do
			local source = stripComments(fs.readFile(path))
			t.ok(not string.find(source, "FireServer", 1, true), `{path}: FireServer`)
			t.ok(not string.find(source, "InvokeServer", 1, true), `{path}: InvokeServer`)
			-- 연출 속성은 읽기만 (VictoryProps의 로컬 소품 eye:SetAttribute("Side")는 m3-05부터 있던 장면 내부 값)
			t.ok(not string.find(source, ":SetAttribute(Attributes.", 1, true), `{path}: Player 속성 쓰기`)
			t.ok(not string.find(source, "LocalPlayer:SetAttribute", 1, true), `{path}: LocalPlayer 속성 쓰기`)
			for _, forbidden in { "RoundLogic", "Rules", "RewardLogic", "ShopLogic", "DataService", "OfferService" } do
				t.ok(not string.find(source, `.{forbidden})`, 1, true), `{path}: {forbidden}`)
			end
		end
	end)

	t.test(
		"연출 속성은 탈락한 사람·우승자의 Player에서 읽어요 (내 속성·캐릭터 속성 아님)",
		function()
			local elim = stripComments(fs.readFile("src/client/fx/EliminationCutsceneController.luau"))
			t.ok(
				string.find(elim, "subject and subject:GetAttribute(Attributes.EliminationFx)", 1, true) ~= nil,
				"subject = GetPlayerByUserId(result.userId)"
			)
			t.ok(string.find(elim, "local subject = Players:GetPlayerByUserId(result.userId)", 1, true) ~= nil)
			local _, n = string.gsub(elim, "Attributes%.EliminationFx", "")
			t.eq(n, 1, "한 곳에서만")
			local vic = stripComments(fs.readFile("src/client/fx/VictoryCutsceneController.luau"))
			t.ok(string.find(vic, "Players:GetPlayerByUserId(winnerUserId)", 1, true) ~= nil)
			t.ok(string.find(vic, "winner and winner:GetAttribute(Attributes.VictoryFx)", 1, true) ~= nil)
			-- 서버 코드는 이 스펙에서 연출 속성을 읽지 않아요 (판정 영향 없음)
			for _, name in fs.readDir("src/server") do
				if string.match(name, "%.luau$") then
					local source = stripComments(fs.readFile(`src/server/{name}`))
					t.ok(not string.find(source, "EliminationCutsceneLogic", 1, true), name)
					t.ok(not string.find(source, "VictoryCutsceneLogic.extraFor", 1, true), name)
				end
			end
		end
	)

	t.test("연출 길이는 설정 그대로 (팩이 바꾸지 않음)", function()
		t.eq(Config.Match.EliminationCutscene, 3)
		t.eq(Config.Match.VictoryCutscene, 6)
		t.eq(Config.Match.VictoryDuration, 10)
		for _, path in
			{ "src/client/fx/EliminationCutsceneController.luau", "src/client/fx/VictoryCutsceneController.luau" }
		do
			local source = stripComments(fs.readFile(path))
			t.ok(not string.find(source, "if cat then duration", 1, true), path)
		end
	end)
end
