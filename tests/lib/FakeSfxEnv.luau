--!strict
-- 클라이언트 Sfx.luau를 Lune에서 불러 보려는 가짜 Roblox 환경 (m3-08 QA).
-- 인스턴스(Parent/Destroy/IsA/시그널), SoundService, TweenService, Players, Remotes, task.delay, os.clock을 흉내 내요.
-- 시간은 env.now로 직접 움직이고, task.delay로 미룬 함수는 env.runDelayed()로 실행해요.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RobloxRequire = require("./RobloxRequire")

-- Sfx.luau가 쓰는 순수 공용 모듈은 진짜를 넣어요 (m3-09: Config.Fx, Attributes.NoClickSfx)
local Shared = RobloxRequire.root("src/shared")
local RealConfig = RobloxRequire.require(Shared.Config)
local RealAttributes = RobloxRequire.require(Shared.Attributes)

local FakeSfxEnv = {}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> any,
	Once: (self: Signal, fn: (...any) -> ()) -> any,
	Fire: (self: Signal, ...any) -> (),
	count: (self: Signal) -> number,
}

local function newSignal(): Signal
	local handlers: { { fn: (...any) -> (), once: boolean, alive: boolean } } = {}
	local signal = {}
	function signal.Connect(_self, fn)
		local h = { fn = fn, once = false, alive = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.alive = false
			end,
		}
	end
	function signal.Once(_self, fn)
		local h = { fn = fn, once = true, alive = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.alive = false
			end,
		}
	end
	function signal.Fire(_self, ...)
		for _, h in table.clone(handlers) do
			if h.alive then
				if h.once then
					h.alive = false
				end
				h.fn(...)
			end
		end
	end
	function signal.count(_self)
		local n = 0
		for _, h in handlers do
			if h.alive then
				n += 1
			end
		end
		return n
	end
	return signal :: any
end
FakeSfxEnv.newSignal = newSignal

local SUPER: { [string]: { string } } = {
	TextButton = { "GuiButton", "GuiObject" },
	ImageButton = { "GuiButton", "GuiObject" },
	TextBox = { "GuiObject" },
	TextLabel = { "GuiObject" },
	Frame = { "GuiObject" },
	Part = { "BasePart" },
	MeshPart = { "BasePart" },
}

-- 가짜 인스턴스. 속성은 표에, Parent를 바꾸면 자식 목록과 DescendantAdded를 맞춰요.
local function newInstance(className: string): any
	local props: { [string]: any } = { Name = className }
	local children: { any } = {}
	local self: any = {}
	local methods: { [string]: any } = {
		__fakeInstance = true,
		ClassName = className,
		Destroyed = false,
		Ended = newSignal(),
		Destroying = newSignal(),
		Activated = newSignal(),
		DescendantAdded = newSignal(),
		Playing = false,
	}
	function methods.IsA(_s, name: string): boolean
		if name == className or name == "Instance" then
			return true
		end
		for _, super in SUPER[className] or {} do
			if super == name then
				return true
			end
		end
		return false
	end
	local attributes: { [string]: any } = {}
	function methods.GetAttribute(_s, name: string)
		return attributes[name]
	end
	function methods.SetAttribute(_s, name: string, value: any)
		attributes[name] = value
	end
	function methods.GetChildren(_s)
		return table.clone(children)
	end
	function methods.GetDescendants(_s)
		local list = {}
		local function walk(node)
			for _, child in node:GetChildren() do
				table.insert(list, child)
				walk(child)
			end
		end
		walk(self)
		return list
	end
	function methods.FindFirstChild(_s, name: string)
		for _, child in children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods.WaitForChild(s, name: string)
		return assert(s:FindFirstChild(name), `fake WaitForChild: no {name}`)
	end
	function methods.Play(_s)
		rawset(methods, "Playing", true)
	end
	function methods.Destroy(s)
		if methods.Destroyed then
			return
		end
		methods.Destroyed = true
		methods.Destroying:Fire()
		for _, child in table.clone(children) do
			child:Destroy()
		end
		s.Parent = nil
	end
	function methods._addChild(_s, child)
		table.insert(children, child)
	end
	function methods._removeChild(_s, child)
		local index = table.find(children, child)
		if index then
			table.remove(children, index)
		end
	end
	setmetatable(self, {
		__index = function(_, key)
			if props[key] ~= nil then
				return props[key]
			end
			return methods[key]
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = props.Parent
				if old == value then
					return
				end
				if old then
					old:_removeChild(self)
				end
				props.Parent = value
				if value then
					value:_addChild(self)
					-- 조상마다 DescendantAdded (자신 + 자손)
					local added = { self }
					for _, d in self:GetDescendants() do
						table.insert(added, d)
					end
					local ancestor = value
					while ancestor do
						for _, d in added do
							ancestor.DescendantAdded:Fire(d)
						end
						ancestor = ancestor.Parent
					end
				end
				return
			end
			props[key] = value
		end,
	})
	return self
end
FakeSfxEnv.newInstance = newInstance

export type Env = {
	module: any,
	now: number,
	warnings: { string },
	delayed: { { at: number, fn: () -> () } },
	tweens: { any },
	soundService: any,
	terrain: any,
	playerGui: any,
	events: { [string]: Signal },
	userId: number,
	runDelayed: (upTo: number?) -> (),
	sounds: () -> { any },
}

-- library: SfxLibrary 대신 넣을 모듈 (테스트에서 배경음 id를 채워 보려고)
function FakeSfxEnv.load(sfxCues: any, sfxLibrary: any): Env
	local env: any = {
		now = 100,
		warnings = {},
		delayed = {},
		tweens = {},
		events = {},
		userId = 1,
	}
	local soundService = newInstance("SoundService")
	local terrain = newInstance("Terrain")
	local playerGui = newInstance("PlayerGui")
	playerGui.Name = "PlayerGui"
	local player = newInstance("Player")
	player.UserId = env.userId
	playerGui.Parent = player
	env.soundService = soundService
	env.terrain = terrain
	env.playerGui = playerGui

	local tweenService = {
		Create = function(_self, object, info, goal)
			local tween = { object = object, info = info, goal = goal, played = false, Completed = newSignal() }
			function tween.Play(t)
				t.played = true
			end
			-- 테스트에서 끝까지 돌린 것처럼 만들어요
			function tween.finish(t)
				for k, v in t.goal do
					t.object[k] = v
				end
				t.Completed:Fire()
			end
			table.insert(env.tweens, tween)
			return tween
		end,
	}

	local remotes = {
		event = function(name: string)
			local signal = env.events[name]
			if signal == nil then
				signal = newSignal()
				env.events[name] = signal
			end
			return { OnClientEvent = signal }
		end,
	}
	local sharedModules = {
		SfxCues = sfxCues,
		SfxLibrary = sfxLibrary,
		Remotes = remotes,
		Types = {},
		Config = RealConfig,
		Attributes = RealAttributes,
	}
	local sharedFolder = setmetatable({}, {
		__index = function(_, name: string)
			return { __shared = name }
		end,
	})
	local services = {
		Players = { LocalPlayer = player },
		ReplicatedStorage = { Shared = sharedFolder },
		SoundService = soundService,
		TweenService = tweenService,
	}
	local function stub(kind: string)
		return function(...)
			return { __stub = kind, args = { ... } }
		end
	end
	local path = "src/client/Sfx.luau"
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			game = {
				GetService = function(_self, name: string)
					return assert(services[name], `no fake service {name}`)
				end,
			},
			workspace = { Terrain = terrain },
			Instance = { new = newInstance },
			TweenInfo = { new = stub("TweenInfo") },
			Enum = setmetatable({}, {
				__index = function(_, enumName)
					return setmetatable({}, {
						__index = function(_, item)
							return `Enum.{enumName}.{item}`
						end,
					})
				end,
			}),
			UDim2 = { new = stub("UDim2"), fromOffset = stub("UDim2"), fromScale = stub("UDim2") },
			UDim = { new = stub("UDim") },
			Vector2 = { new = stub("Vector2") },
			Color3 = { new = stub("Color3"), fromRGB = stub("Color3") },
			typeof = function(value: any): string
				if type(value) == "table" and value.__fakeInstance then
					return "Instance"
				end
				if type(value) == "table" and value.__vector3 then
					return "Vector3"
				end
				return type(value)
			end,
			os = {
				clock = function()
					return env.now
				end,
			},
			task = {
				delay = function(seconds: number, fn: (...any) -> (), ...)
					local args = { ... }
					table.insert(env.delayed, {
						at = env.now + seconds,
						fn = function()
							fn(table.unpack(args))
						end,
					})
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
				local name = target.__shared
				return assert(sharedModules[name], `no fake shared module {name}`)
			end,
		},
	})
	env.module = chunk()

	-- upTo 시각(없으면 전부)까지 미룬 함수를 실행해요
	function env.runDelayed(upTo: number?)
		local remaining = {}
		local due = {}
		for _, item in env.delayed do
			if upTo == nil or item.at <= upTo then
				table.insert(due, item)
			else
				table.insert(remaining, item)
			end
		end
		env.delayed = remaining
		for _, item in due do
			item.fn()
		end
	end

	-- 지금 살아 있는 Sound 전부 (SoundService, Terrain의 Attachment 아래, 그 밖은 직접 찾기)
	function env.sounds(): { any }
		local list = {}
		for _, root in { soundService, terrain } do
			for _, d in root:GetDescendants() do
				if d.ClassName == "Sound" and not d.Destroyed then
					table.insert(list, d)
				end
			end
		end
		return list
	end

	return env
end

function FakeSfxEnv.vector3(x: number, y: number, z: number): any
	return { __vector3 = true, X = x, Y = y, Z = z }
end

return FakeSfxEnv
