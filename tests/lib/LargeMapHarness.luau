--!strict
-- 대형 맵(m6-03~07) 서버 start 하네스. 맵 모듈 소스를 가짜 Heartbeat·시계·서비스 + 진짜 CFrame·Vector3·Instance로 불러
-- start(ctx)를 돌려 봐요. tests/map-dish-sink.spec.luau의 하네스를 여러 맵이 같이 쓰게 뽑아낸 것.
--   LargeMapHarness.new(path, modules, model) -> Harness
--   LargeMapHarness.fakeRacer(origin, x, y, z) -> racer   (racer.root / racer.humanoid / racer.Character)
--   LargeMapHarness.newCtx(model, origin, racers, seed?) -> ctx   (ctx.passed / ctx.eliminated / ctx.active)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

local LargeMapHarness = {}

export type Harness = {
	map: any,
	fire: (dt: number) -> (),
	setClock: (t: number) -> (),
	marks: { { character: any, seconds: number? } },
	sounds: { string },
	delays: { number },
	bulk: number,
	created: { any },
}

function LargeMapHarness.new(path: string, modules: { [string]: any }, model: any): Harness
	local handlers: { any } = {}
	local clock = 0
	local h: Harness = {
		map = nil,
		fire = function(dt: number)
			for _, fn in table.clone(handlers) do
				fn(dt)
			end
		end,
		setClock = function(t: number)
			clock = t
		end,
		marks = {},
		sounds = {},
		delays = {},
		bulk = 0,
		created = {},
	}
	local heartbeat = {
		Connect = function(_, fn: any)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
	}
	local collection = {
		GetTagged = function(_, tag: string)
			local list = {}
			for _, d in model:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(list, d)
				end
			end
			return list
		end,
		AddTag = function(_, inst: any, tag: string)
			inst:AddTag(tag)
		end,
	}
	local all: { [string]: any } = table.clone(modules)
	all.MapKit = all.MapKit or {}
	all.MapSfx = all.MapSfx or {
		play = function(_part: any, cue: string)
			table.insert(h.sounds, cue)
		end,
	}
	all.MoveExempt = all.MoveExempt
		or {
			mark = function(character: any, seconds: number?)
				table.insert(h.marks, { character = character, seconds = seconds })
			end,
		}
	local parentParent = setmetatable({}, {
		__index = function(_, name: string)
			return { __module = name }
		end,
	})
	local parent = setmetatable({ Parent = parentParent }, {
		__index = function(_, name: string)
			return { __module = name }
		end,
	})
	local fakeInstance = {
		new = function(className: string)
			local inst: any = { ClassName = className }
			function inst:Destroy() end
			table.insert(h.created, inst)
			return inst
		end,
	}
	h.map = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local m = all[target.__module]
				assert(m ~= nil, `unexpected require {tostring(target.__module)}`)
				return m
			end,
			game = {
				GetService = function(_, name: string)
					if name == "RunService" then
						return { Heartbeat = heartbeat }
					elseif name == "CollectionService" then
						return collection
					end
					error(`unexpected service {name}`)
				end,
			},
			workspace = {
				BulkMoveTo = function(_, parts: { any }, frames: { any })
					h.bulk += 1
					for i, p in parts do
						p.CFrame = frames[i]
					end
				end,
			},
			task = {
				delay = function(seconds: number, _fn: any)
					table.insert(h.delays, seconds)
					return {}
				end,
			},
			os = {
				clock = function()
					return clock
				end,
			},
			CFrame = RCF,
			Vector3 = RV3,
			Color3 = roblox.Color3,
			Enum = roblox.Enum,
			Instance = fakeInstance,
			table = table,
			math = math,
			string = string,
			type = type,
			typeof = typeof,
			tostring = tostring,
			tonumber = tonumber,
			assert = assert,
			error = error,
			pairs = pairs,
			ipairs = ipairs,
			next = next,
		},
	})()
	return h
end

function LargeMapHarness.fakeRacer(origin: any, x: number, y: number, z: number): any
	local root: any = {
		Position = origin:PointToWorldSpace(RV3.new(x, y, z)),
		AssemblyLinearVelocity = RV3.new(0, 0, 0),
		IsA = function(_, cls: string)
			return cls == "BasePart"
		end,
		FindFirstChild = function(_, name: string)
			if name == "RootAttachment" then
				return { Name = "RootAttachment" }
			end
			return nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	local humanoid: any = { PlatformStand = false }
	local character: any = {}
	character.FindFirstChild = function(_, name: string)
		if name == "HumanoidRootPart" then
			return root
		end
		return nil
	end
	character.FindFirstChildOfClass = function(_, cls: string)
		if cls == "Humanoid" then
			return humanoid
		end
		return nil
	end
	humanoid.Parent = character
	return { Name = "Racer", Character = character, root = root, humanoid = humanoid }
end

function LargeMapHarness.newCtx(model: any, origin: any, racers: { any }, seed: number?): any
	local cleanup = { items = {} :: { any } }
	function cleanup:add(item: any)
		table.insert(self.items, item)
		return item
	end
	local state = seed or 1
	local rng = {
		NextNumber = function(_, lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + (hi - lo) * (state / 2147483648)
		end,
		NextInteger = function(_, lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + state % (hi - lo + 1)
		end,
	}
	local ctx: any = {
		model = model,
		origin = origin,
		cleanup = cleanup,
		rng = rng,
		targetCount = 1,
		passed = {},
		eliminated = {},
		active = true,
	}
	ctx.isActive = function()
		return ctx.active
	end
	ctx.getRacers = function()
		local list = {}
		for _, r in racers do
			if not ctx.passed[r] and not ctx.eliminated[r] then
				table.insert(list, r)
			end
		end
		return list
	end
	ctx.pass = function(p: any)
		ctx.passed[p] = true
	end
	ctx.eliminate = function(p: any)
		ctx.eliminated[p] = true
	end
	return ctx
end

-- 맵을 진짜로 지어서(Shims) 돌려줘요 — 태그·이름 확인용
function LargeMapHarness.build(id: string, origin: any): any
	local Shims = require("../../tools/render/Shims")
	local RShared = Shims.root("src/shared")
	local RMaps = Shims.require(RShared.maps)
	return RMaps.get(id).build(origin)
end

return LargeMapHarness
