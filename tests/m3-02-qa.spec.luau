--!strict
-- m3-02 QA: SushiBody.build와 AppearanceService.applyAppearance를 가짜 Roblox 환경에서 실제로 돌려 봐요.
--   초밥 파츠가 판정에 끼지 않는지(Massless·충돌·쿼리·터치), 두 번 입혀도 한 벌인지,
--   원래 몸·얼굴·액세서리 숨김(늦게 붙는 것 포함), 발바닥 높이 맞춤, 외형 적용 지점이 한 곳인지.
-- 가짜 CFrame은 이동만 다뤄요 (회전 없음) — 위치·오프셋 검사에 충분해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Attributes = RobloxRequire.require(Shared.Attributes)
local Config = RobloxRequire.require(Shared.Config)
local RealSushiBody = RobloxRequire.require(Shared.SushiBody)

---------------------------------------------------------------- 가짜 자료형
local Vector3 = {}
function Vector3.new(x: number?, y: number?, z: number?): any
	return { X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }
end

local CFrameMT = {}
CFrameMT.__index = CFrameMT
CFrameMT.__mul = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, CFrameMT)
end
local CFrame = {}
function CFrame.new(x: any?, y: number?, z: number?): any
	if type(x) == "table" then
		return setmetatable({ X = x.X, Y = x.Y, Z = x.Z }, CFrameMT)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, CFrameMT)
end
CFrame.identity = CFrame.new()

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number): any
	return { R = r, G = g, B = b }
end

local Enum = {
	Material = setmetatable({}, {
		__index = function(_, name: string)
			return `Material.{name}`
		end,
	}),
	SurfaceType = { Smooth = "Smooth" },
	HumanoidRigType = { R15 = "R15", R6 = "R6" },
}

---------------------------------------------------------------- 가짜 Instance
local function newSignal(): any
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, h in table.clone(handlers) do
			if h.connected then
				h.fn(...)
			end
		end
	end
	return signal
end

local CLASSES: { [string]: { string } } = {
	Part = { "Part", "BasePart" },
	Model = { "Model", "PVInstance" },
	Decal = { "Decal" },
	Motor6D = { "Motor6D", "JointInstance" },
	WeldConstraint = { "WeldConstraint" },
	Humanoid = { "Humanoid" },
	Accessory = { "Accessory" },
}

local Methods = {}
local InstMT = {}

local function newInstance(className: string): any
	local inst = {
		ClassName = className,
		Name = className,
		_children = {},
		_parent = nil,
		_attrs = {},
		_destroyed = false,
		DescendantAdded = newSignal(),
	}
	if className == "Part" then
		inst.Transparency = 0
		inst.Anchored = false
		inst.CanCollide = true
		inst.CanQuery = true
		inst.CanTouch = true
		inst.Massless = false
		inst.CFrame = CFrame.new()
		inst.Size = Vector3.new(1, 1, 1)
	elseif className == "Decal" then
		inst.Transparency = 0
	elseif className == "Motor6D" then
		inst.C0 = CFrame.new()
		inst.C1 = CFrame.new()
	end
	return setmetatable(inst, InstMT)
end

InstMT.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	return Methods[key]
end

local function descendantsOf(inst: any, out: { any })
	for _, child in inst._children do
		table.insert(out, child)
		descendantsOf(child, out)
	end
	return out
end

InstMT.__newindex = function(self, key, value)
	if key ~= "Parent" then
		rawset(self, key, value)
		return
	end
	local old = rawget(self, "_parent")
	if old then
		local idx = table.find(old._children, self)
		if idx then
			table.remove(old._children, idx)
		end
	end
	rawset(self, "_parent", value)
	if value then
		table.insert(value._children, self)
		local added = { self }
		descendantsOf(self, added)
		local ancestor = value
		while ancestor do
			for _, d in added do
				ancestor.DescendantAdded:Fire(d)
			end
			ancestor = rawget(ancestor, "_parent")
		end
	end
end

function Methods.FindFirstChild(self, name: string)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function Methods.WaitForChild(self, name: string)
	return self:FindFirstChild(name)
end
function Methods.FindFirstChildOfClass(self, className: string)
	for _, c in self._children do
		if c.ClassName == className then
			return c
		end
	end
	return nil
end
function Methods.GetChildren(self)
	return table.clone(self._children)
end
function Methods.GetDescendants(self)
	return descendantsOf(self, {})
end
function Methods.IsA(self, className: string): boolean
	return table.find(CLASSES[self.ClassName] or { self.ClassName }, className) ~= nil
end
function Methods.IsDescendantOf(self, ancestor): boolean
	local p = rawget(self, "_parent")
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function Methods.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Methods.SetAttribute(self, name: string, value: any)
	self._attrs[name] = value
end
function Methods.GetAttribute(self, name: string)
	return self._attrs[name]
end
function Methods.PivotTo(self, cf)
	local pivot = self.PrimaryPart.CFrame
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame
			d.CFrame = CFrame.new(cf.X + p.X - pivot.X, cf.Y + p.Y - pivot.Y, cf.Z + p.Z - pivot.Z)
		end
	end
end

local Instance = { new = newInstance }

---------------------------------------------------------------- 모듈 불러오기
type Env = { warnings: { string }, starterPlayer: any }

local function baseEnv(env: Env, sharedModules: { [string]: any }): { [string]: any }
	local sharedFolder = setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
	local services = {
		Players = {
			PlayerAdded = newSignal(),
			PlayerRemoving = newSignal(),
			GetPlayers = function()
				return {}
			end,
		},
		ReplicatedStorage = { Shared = sharedFolder },
		StarterPlayer = env.starterPlayer,
	}
	return {
		game = {
			GetService = function(_self, name: string)
				return assert(services[name], `no fake service {name}`)
			end,
		},
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
		},
		warn = function(...)
			local parts = {}
			for _, v in { ... } do
				table.insert(parts, tostring(v))
			end
			table.insert(env.warnings, table.concat(parts, " "))
		end,
		require = function(target: any)
			return assert(sharedModules[target.__shared], `no fake shared module {target.__shared}`)
		end,
	}
end

local function load(path: string, environment: { [string]: any }): any
	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end

local function loadAll(): (any, any, Env)
	local env: Env = { warnings = {}, starterPlayer = { LoadCharacterAppearance = true } }
	local SushiBody = load("src/shared/SushiBody.luau", baseEnv(env, {}))
	local AppearanceService = load(
		"src/server/AppearanceService.luau",
		baseEnv(env, { Attributes = Attributes, Config = Config, SushiBody = SushiBody })
	)
	return SushiBody, AppearanceService, env
end

-- R15 기본 체형 캐릭터 (HRP 2×2×1, HipHeight 2) + 얼굴 decal + 액세서리
local function makeCharacter(rig: string?): any
	local character = newInstance("Model")
	character.Name = "Player1"
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new(10, 20, 30)
	root.Parent = character
	local head = newInstance("Part")
	head.Name = "Head"
	head.Parent = character
	local face = newInstance("Decal")
	face.Name = "face"
	face.Parent = head
	local torso = newInstance("Part")
	torso.Name = "UpperTorso"
	torso.Parent = character
	local shirtLogo = newInstance("Decal")
	shirtLogo.Name = "Logo"
	shirtLogo.Parent = torso
	local hat = newInstance("Accessory")
	hat.Name = "Hat"
	hat.Parent = character
	local handle = newInstance("Part")
	handle.Name = "Handle"
	handle.Parent = hat
	local humanoid = newInstance("Humanoid")
	humanoid.RigType = rig or "R15"
	humanoid.HipHeight = 2
	humanoid.Parent = character
	return character
end

local function sushiModels(character: any): { any }
	local list = {}
	for _, c in character:GetChildren() do
		if c.Name == "SushiBody" then
			table.insert(list, c)
		end
	end
	return list
end

return function(t: Test.Test)
	---------------------------------------------------------------- SushiBody.build
	t.test("build: layout 파츠 전부, PrimaryPart = Body(Anchored), 나머지는 Body에 용접", function()
		local SushiBody = loadAll()
		local model = SushiBody.build("tamago")
		local layout = RealSushiBody.layout("tamago")
		local parts = {}
		for _, c in model:GetChildren() do
			if c:IsA("BasePart") then
				parts[c.Name] = c
			end
		end
		for _, spec in layout do
			t.ok(parts[spec.name] ~= nil, `missing part {spec.name}`)
		end
		t.ok(model.PrimaryPart == parts.Body, "PrimaryPart")
		t.eq(parts.Body.Anchored, true)
		for name, part in parts do
			if name ~= "Body" then
				t.eq(part.Anchored, false, `{name} anchored`)
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				t.ok(weld ~= nil, `{name} weld`)
				t.ok(weld.Part0 == parts.Body, `{name} weld Part0`)
				t.ok(weld.Part1 == part, `{name} weld Part1`)
			end
		end
	end)

	t.test("build: 모든 초밥 파츠가 Massless·CanCollide/CanQuery/CanTouch false (판정에 안 낌)", function()
		local SushiBody = loadAll()
		local model = SushiBody.build("tamago")
		local count = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				t.eq(part.Massless, true, `{part.Name} Massless`)
				t.eq(part.CanCollide, false, `{part.Name} CanCollide`)
				t.eq(part.CanQuery, false, `{part.Name} CanQuery`)
				t.eq(part.CanTouch, false, `{part.Name} CanTouch`)
			end
		end
		t.eq(count, #RealSushiBody.layout("tamago"))
	end)

	t.test("build: 파츠 위치 = layout 오프셋 (원점 기준)", function()
		local SushiBody = loadAll()
		local model = SushiBody.build("tamago")
		for _, spec in RealSushiBody.layout("tamago") do
			local part = model:FindFirstChild(spec.name)
			t.eq(part.CFrame.X, spec.offset[1], `{spec.name} x`)
			t.eq(part.CFrame.Y, spec.offset[2], `{spec.name} y`)
			t.eq(part.CFrame.Z, spec.offset[3], `{spec.name} z`)
		end
	end)

	t.test("build: 모르는 id도 tamago 파츠로 만들어져요 (에러 없음)", function()
		local SushiBody = loadAll()
		local model = SushiBody.build("no-such-skin")
		t.ok(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Body", "Body")
		t.eq(#model:GetChildren(), #RealSushiBody.layout("tamago"))
	end)

	---------------------------------------------------------------- applyAppearance
	t.test("AC6: applyAppearance — AppearanceId = 기본(tamago), SushiBody 한 벌, SushiJoint로 HRP에", function()
		local _, AppearanceService, env = loadAll()
		local character = makeCharacter()
		AppearanceService.applyAppearance(character, nil)
		t.eq(character:GetAttribute(Attributes.AppearanceId), Config.Appearance.Default)
		t.eq(character:GetAttribute(Attributes.AppearanceId), "tamago")
		local models = sushiModels(character)
		t.eq(#models, 1)
		local body = models[1].PrimaryPart
		t.eq(body.Name, "Body")
		t.eq(body.Anchored, false)
		local joint = body:FindFirstChild("SushiJoint")
		t.ok(joint ~= nil and joint:IsA("Motor6D"), "SushiJoint Motor6D")
		t.ok(joint.Part0 == character:FindFirstChild("HumanoidRootPart"), "Part0 = HRP")
		t.ok(joint.Part1 == body, "Part1 = Body")
		t.eq(#env.warnings, 0)
	end)

	t.test("AC6: 두 번(리스폰 전 재적용) 불러도 SushiBody는 한 벌, 옛것은 지워져요", function()
		local _, AppearanceService = loadAll()
		local character = makeCharacter()
		AppearanceService.applyAppearance(character, nil)
		local first = sushiModels(character)[1]
		AppearanceService.applyAppearance(character, "tamago")
		AppearanceService.applyAppearance(character, nil)
		t.eq(#sushiModels(character), 1)
		t.eq(first._destroyed, true)
	end)

	t.test(
		"AC5: 원래 몸·액세서리·decal은 투명, 얼굴 decal은 제거, 초밥 파츠는 보여요",
		function()
			local _, AppearanceService = loadAll()
			local character = makeCharacter()
			AppearanceService.applyAppearance(character, nil)
			local head = character:FindFirstChild("Head")
			t.eq(head:FindFirstChild("face"), nil, "face removed")
			t.eq(head.Transparency, 1)
			t.eq(character:FindFirstChild("UpperTorso").Transparency, 1)
			t.eq(character:FindFirstChild("UpperTorso"):FindFirstChild("Logo").Transparency, 1)
			t.eq(character:FindFirstChild("Hat"):FindFirstChild("Handle").Transparency, 1)
			for _, part in sushiModels(character)[1]:GetDescendants() do
				if part:IsA("BasePart") then
					t.eq(part.Transparency, 0, `{part.Name} visible`)
				end
			end
		end
	)

	t.test(
		"AC5: 입힌 뒤 늦게 붙는 액세서리는 숨기고, 초밥 Model 안에 붙는 건 안 숨겨요",
		function()
			local _, AppearanceService = loadAll()
			local character = makeCharacter()
			AppearanceService.applyAppearance(character, nil)
			local late = newInstance("Accessory")
			local handle = newInstance("Part")
			handle.Name = "Handle"
			handle.Parent = late
			late.Parent = character
			t.eq(handle.Transparency, 1, "late accessory hidden")
			local extra = newInstance("Part")
			extra.Parent = sushiModels(character)[1]
			t.eq(extra.Transparency, 0, "sushi child stays visible")
			-- 다시 입혀도 숨김 연결이 두 개가 되지 않고 계속 동작해요
			AppearanceService.applyAppearance(character, nil)
			local late2 = newInstance("Part")
			late2.Parent = character
			t.eq(late2.Transparency, 1)
		end
	)

	t.test(
		"AC2: 초밥 발바닥이 휴머노이드 발바닥(R15: HRP중심 - HipHeight - HRP높이/2)과 같아요",
		function()
			local SushiBody, AppearanceService = loadAll()
			local character = makeCharacter("R15")
			AppearanceService.applyAppearance(character, nil)
			local root = character:FindFirstChild("HumanoidRootPart")
			local body = sushiModels(character)[1].PrimaryPart
			local joint = body:FindFirstChild("SushiJoint")
			local feet = root.CFrame.Y - 2 - 1
			t.ok(math.abs(body.CFrame.Y - SushiBody.GROUND_OFFSET - feet) < 1e-6, `body y {body.CFrame.Y}`)
			t.ok(math.abs(joint.C0.Y - (body.CFrame.Y - root.CFrame.Y)) < 1e-6, "C0 matches placed offset")
			t.eq(body.CFrame.X, root.CFrame.X)
			t.eq(body.CFrame.Z, root.CFrame.Z)
			-- 꼭대기는 휴머노이드 기본 키(약 5) 안
			local b = RealSushiBody.bounds(RealSushiBody.layout("tamago"))
			local top = body.CFrame.Y + b.max[2] - feet
			t.ok(top >= 4.5 and top <= 5.5, `top above feet {top}`)
		end
	)

	t.test("R6 캐릭터도 발바닥(HRP중심 - 3)에 맞춰 붙어요", function()
		local SushiBody, AppearanceService = loadAll()
		local character = makeCharacter("R6")
		AppearanceService.applyAppearance(character, nil)
		local root = character:FindFirstChild("HumanoidRootPart")
		local body = sushiModels(character)[1].PrimaryPart
		t.ok(math.abs(body.CFrame.Y - SushiBody.GROUND_OFFSET - (root.CFrame.Y - 3)) < 1e-6, "R6 feet")
	end)

	t.test("HumanoidRootPart가 없으면 경고만 하고 초밥을 붙이지 않아요 (에러 없음)", function()
		local _, AppearanceService, env = loadAll()
		local character = newInstance("Model")
		AppearanceService.applyAppearance(character, nil)
		t.eq(#sushiModels(character), 0)
		t.eq(#env.warnings, 1)
		t.eq(character:GetAttribute(Attributes.AppearanceId), "tamago")
	end)

	t.test("init(): StarterPlayer.LoadCharacterAppearance = false (프로젝트 설정과 같은 값)", function()
		local _, AppearanceService, env = loadAll()
		AppearanceService.init()
		t.eq(env.starterPlayer.LoadCharacterAppearance, false)
	end)

	---------------------------------------------------------------- 단일 지점 · 이름 일치
	t.test(
		"초밥 Model·관절 이름이 서버(AppearanceService)와 클라이언트(CharacterFxController)에서 같아요",
		function()
			-- m3-09: 이름 상수를 Shared.SushiBody.MODEL_NAME/JOINT_NAME 한 곳으로 옮겼어요 (QA B4).
			-- 서버 값이 공용 상수와 같고, 클라이언트가 공용 상수를 쓰는지 확인해요.
			local SushiBody, AppearanceService = loadAll()
			t.eq(AppearanceService.MODEL_NAME, RealSushiBody.MODEL_NAME)
			t.eq(AppearanceService.JOINT_NAME, RealSushiBody.JOINT_NAME)
			t.eq(SushiBody.MODEL_NAME, "SushiBody")
			t.eq(SushiBody.JOINT_NAME, "SushiJoint")
			local client = fs.readFile("src/client/fx/CharacterFxController.luau")
			t.ok(string.find(client, "local MODEL_NAME = SushiBody.MODEL_NAME", 1, true) ~= nil, "MODEL_NAME")
			t.ok(string.find(client, "local JOINT_NAME = SushiBody.JOINT_NAME", 1, true) ~= nil, "JOINT_NAME")
		end
	)

	t.test(
		"외형 적용 지점은 한 곳: 서버에서 SushiBody·AppearanceId 속성을 쓰는 곳은 AppearanceService뿐",
		function()
			for _, name in fs.readDir("src/server") do
				if string.match(name, "%.luau$") and name ~= "AppearanceService.luau" then
					local source = fs.readFile(`src/server/{name}`)
					t.ok(string.find(source, "SushiBody", 1, true) == nil, `{name} uses SushiBody`)
					t.ok(
						string.find(source, "SetAttribute(Attributes.AppearanceId", 1, true) == nil,
						`{name} sets AppearanceId`
					)
					t.ok(string.find(source, "CanLoadCharacterAppearance", 1, true) == nil, `{name} touches avatar`)
				end
			end
		end
	)
end
