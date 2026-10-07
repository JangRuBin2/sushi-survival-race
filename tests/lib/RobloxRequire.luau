--!strict
-- Lune에서 src/ 모듈을 Rojo 구조 그대로 불러오는 도우미.
-- 모듈 안의 `script`를 파일 경로를 따라가는 가짜 인스턴스로 바꾸고,
-- `require(script.Parent.Config)` 같은 인스턴스 require를 파일 require로 바꿔줘요.
-- Roblox API(game, Instance 등)를 쓰는 모듈은 불러올 수 없어요. 순수 로직만 테스트해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

type Node = { Name: string, Parent: Node?, __path: string }

-- Lune의 fs 호출은 yield라서 __index 안에서 부를 수 없어요. root()에서 폴더를 미리 다 읽어 둬요.
local folders: { [string]: boolean } = {} -- 경로 → 폴더 여부
local sources: { [string]: string } = {} -- 모듈 경로(확장자 없음, init.luau는 폴더 경로) → 소스
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
		elseif string.match(name, "^[^.]+%.luau$") then -- .server.luau / .client.luau는 require 대상이 아니에요
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
		assert(type(module) == "table" and module.__path, "tests only support require(script...) in src modules")
		return requireNode(module)
	end

	local chunk = luau.load(source, {
		debugName = path,
		environment = { script = target, require = robloxRequire },
	})
	local result = chunk()
	cache[path] = result
	return result
end

local RobloxRequire = {}

-- root: 저장소 기준 폴더 경로 (예: "src/shared"). 돌려준 노드에서 .Rules처럼 자식을 따라가요.
function RobloxRequire.root(root: string): any
	if not folders[root] then
		scan(root)
	end
	return node(root, nil)
end

function RobloxRequire.require(target: any): any
	return requireNode(target)
end

return RobloxRequire
