--!strict
-- 미리보기 렌더러용 가짜 Roblox 환경 (Shims) (m5-23). Lune의 @lune/roblox 인스턴스 위에서 src/shared 모듈을 Rojo 구조
-- 그대로 불러와 맵 build(origin)을 진짜로 돌려요. tests/lib/RobloxRequire.luau와 같은 방식이지만, 모듈 환경에
-- Instance·CFrame·Vector3·Enum 같은 Roblox 전역과 game/workspace/task 가짜를 넣어 줘요.
--   Env.root("src/shared") -> any     src/shared 루트 노드 (Env.require(node)로 불러요)
--   Env.require(node) -> any
--   Env.game                          GetService만 있는 가짜 DataModel
-- 빠진 것: 이벤트(.Touched/.Heartbeat)는 build 단계에서 쓰지 않아서 없어요. ServerStorage.MapArt는
-- assets/map-art/<id>.rbxm이 있으면 그 파일을 읽어서 채워요 (attachStudioArt가 장식을 붙일 수 있게).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

type Node = { Name: string, Parent: Node?, __path: string }

local Env = {}

-- ── 모자란 메서드 보충 ───────────────────────────────────────────────
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local function partsOf(model: any): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local pivots: { [any]: any } = {}

local function boundsCenter(model: any): any
	local parts = partsOf(model)
	if #parts == 0 then
		return CFrame.new()
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local pos = p.CFrame.Position
		minV = minV:Min(pos)
		maxV = maxV:Max(pos)
	end
	return CFrame.new((minV + maxV) / 2)
end

local function getPivot(self: any): any
	if self:IsA("BasePart") then
		return self.CFrame
	end
	if pivots[self] then
		return pivots[self]
	end
	local ok, primary = pcall(function()
		return self.PrimaryPart
	end)
	if ok and primary then
		return primary.CFrame
	end
	return boundsCenter(self)
end

pcall(roblox.implementMethod, "Model", "GetPivot", getPivot)
pcall(roblox.implementMethod, "BasePart", "GetPivot", getPivot)
pcall(roblox.implementMethod, "Model", "PivotTo", function(self: any, target: any)
	local current = getPivot(self)
	local delta = target * current:Inverse()
	for _, p in partsOf(self) do
		p.CFrame = delta * p.CFrame
	end
	pivots[self] = target
end)
pcall(roblox.implementMethod, "BasePart", "PivotTo", function(self: any, target: any)
	self.CFrame = target
end)
-- Lune은 BasePart.Position을 CFrame에서 못 꺼내요 (반사 DB가 우선이라 implementProperty도 안 먹어요).
-- 그래서 모듈 소스의 `<이름>.Position` 읽기를 __pos(<이름>)으로 바꿔 불러요 (쓰기 `.Position =`는 그대로).
local function readPosition(value: any): any
	if typeof(value) == "Instance" and value:IsA("BasePart") then
		return value.CFrame.Position
	end
	return value.Position
end

local function rewritePositionReads(source: string): string
	return (
		string.gsub(source, "([%a_][%w_%.]*)%.Position(%s*)(=?)(=?)", function(target, space, eq1, eq2)
			if eq1 == "=" and eq2 ~= "=" then
				return nil -- 대입은 그대로 둬요
			end
			return `__pos({target}){space}{eq1}{eq2}`
		end)
	)
end
pcall(roblox.implementMethod, "Model", "GetBoundingBox", function(self: any)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in partsOf(self) do
		local cf, half = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
					minV = minV:Min(w)
					maxV = maxV:Max(w)
				end
			end
		end
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end)

-- ── 가짜 서비스 ─────────────────────────────────────────────────────
local dataModel = roblox.Instance.new("DataModel")
local workspaceInst = dataModel:GetService("Workspace")

local fakeCollection = {
	AddTag = function(_self: any, inst: any, tag: string)
		inst:AddTag(tag)
	end,
	RemoveTag = function(_self: any, inst: any, tag: string)
		inst:RemoveTag(tag)
	end,
	HasTag = function(_self: any, inst: any, tag: string): boolean
		return inst:HasTag(tag)
	end,
	GetTags = function(_self: any, inst: any): { string }
		return inst:GetTags()
	end,
	GetTagged = function(_self: any, tag: string): { any }
		local list = {}
		for _, d in workspaceInst:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(list, d)
			end
		end
		return list
	end,
}

local fakeRunService = {
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
	IsRunning = function()
		return false
	end,
}

local mapArtFolder = roblox.Instance.new("Folder")
mapArtFolder.Name = "MapArt"
local serverStorage = roblox.Instance.new("Folder")
serverStorage.Name = "ServerStorage"
mapArtFolder.Parent = serverStorage

local fakeTweenService = {
	Create = function()
		return { Play = function() end, Cancel = function() end }
	end,
}

local services: { [string]: any } = {
	CollectionService = fakeCollection,
	RunService = fakeRunService,
	ServerStorage = serverStorage,
	TweenService = fakeTweenService,
	Workspace = workspaceInst,
}

Env.game = {
	GetService = function(_self: any, name: string): any
		local s = services[name]
		if s then
			return s
		end
		local ok, real = pcall(function()
			return dataModel:GetService(name)
		end)
		if ok then
			return real
		end
		error(`[render] service {name} is not available in the preview environment`)
	end,
	Workspace = workspaceInst,
}

-- Studio 장식 파일(assets/map-art/<id>.rbxm)을 ServerStorage.MapArt에 미리 넣어요. 없으면 아무것도 안 해요.
function Env.loadStudioArt(mapId: string): boolean
	local path = `assets/map-art/{mapId}.rbxm`
	if not fs.isFile(path) then
		return false
	end
	local ok, result = pcall(function()
		local roots = roblox.deserializeModel(fs.readFile(path))
		for _, root in roots do
			if root:IsA("Model") then
				root.Name = mapId
				root.Parent = mapArtFolder
				return true
			end
		end
		return false
	end)
	return ok and result == true
end

-- 간단한 Random 대체 (Lune에는 없어요). 씨앗이 같으면 같은 수열이에요.
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?): any
	local self = setmetatable({}, RandomShim)
	self._s = math.floor((seed or os.clock() * 1e6) % 2147483647)
	if self._s <= 0 then
		self._s = 12345
	end
	return self
end
function RandomShim:_next(): number
	self._s = (self._s * 16807) % 2147483647
	return self._s / 2147483647
end
function RandomShim:NextNumber(a: number?, b: number?): number
	local lo, hi = a or 0, b or 1
	return lo + (hi - lo) * self:_next()
end
function RandomShim:NextInteger(a: number, b: number): number
	return a + math.floor(self:_next() * (b - a + 1))
end

local globals: { [string]: any } = {
	game = Env.game,
	workspace = workspaceInst,
	task = task,
	Random = RandomShim,
	warn = function(...)
		print("[warn]", ...)
	end,
}
for _, key in
	{
		"Instance",
		"CFrame",
		"Vector3",
		"Vector2",
		"Color3",
		"Enum",
		"ColorSequence",
		"ColorSequenceKeypoint",
		"NumberSequence",
		"NumberSequenceKeypoint",
		"NumberRange",
		"PhysicalProperties",
		"UDim",
		"UDim2",
		"BrickColor",
		"Rect",
		"Ray",
		"Faces",
		"Axes",
		"Font",
		"Region3",
	}
do
	globals[key] = (roblox :: any)[key]
end
-- 판정용 API는 build에서 만들기만 해요 — 빈 테이블로 충분해요
globals.RaycastParams = {
	new = function()
		return {}
	end,
}
globals.OverlapParams = globals.RaycastParams
globals.TweenInfo = {
	new = function(...)
		return { ... }
	end,
}

Env.globals = globals

-- ── 모듈 로더 (RobloxRequire와 같은 방식) ─────────────────────────────
local folders: { [string]: boolean } = {}
local sources: { [string]: string } = {}
local nodes: { [string]: Node } = {}
local cache: { [string]: any } = {}

local function scan(dir: string)
	folders[dir] = true
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		elseif name == "init.luau" then
			sources[dir] = fs.readFile(path)
		elseif string.match(name, "^[^.]+%.luau$") then
			sources[string.sub(path, 1, -6)] = fs.readFile(path)
		end
	end
end

local function node(path: string, parent: Node?): Node
	local existing = nodes[path]
	if existing then
		return existing
	end
	local name = string.match(path, "([^/]+)$") :: string
	local self = setmetatable({ Name = name, Parent = parent, __path = path }, {
		__index = function(self: Node, childName: string): Node
			local childPath = path .. "/" .. childName
			if sources[childPath] == nil and not folders[childPath] then
				error(`{childName} is not a valid member of {path}`, 2)
			end
			return node(childPath, self)
		end,
	})
	nodes[path] = self
	return self :: any
end

local function requireNode(target: Node): any
	local path = target.__path
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = sources[path]
	assert(source, `{path} is not a module`)
	local function robloxRequire(module: any): any
		assert(type(module) == "table" and module.__path, "render env only supports require(script...)")
		return requireNode(module)
	end
	local env = table.clone(globals)
	env.script = target
	env.require = robloxRequire
	env.__pos = readPosition
	local chunk = luau.load(rewritePositionReads(source), { debugName = path, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

function Env.root(root: string): any
	if not folders[root] then
		scan(root)
	end
	return node(root, nil)
end

function Env.require(target: any): any
	return requireNode(target)
end

return Env
