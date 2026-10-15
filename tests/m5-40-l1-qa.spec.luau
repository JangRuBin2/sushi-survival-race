--!strict
-- m5-40 L1 QA (docs/qa/m5-40-l1.md): rotating-belt · soy-swamp 길이 늘리기를 렌더러 가짜 Roblox 환경
-- (tools/render/Shims — 진짜 @lune/roblox 인스턴스)으로 실제로 지어서 확인해요.
--   옛 구간 판정 지문: 새 구간 앞(belt z ≥ -106, soy z ≥ -160)에 완전히 들어가는 판정 파츠의 지문이
--       c121dda(m5-40 전)에서 같은 계산으로 잰 값과 같아요. m5-24-qa의 맵 전체 지문은 이번에 새로 고정돼서
--       옛 구간 회귀를 못 잡으니, 이 테스트가 옛 구간만 따로 지켜요.
--   옆 벨트: build의 PushSide 구역과 칸막이가 짝이고, 칸막이 틈이 start가 미는 방향(RightVector × sign)의 반대쪽.
--   젓가락: 옛 스테이션(벨트 B)은 대기 시간 속성이 없어서 옛 범위 그대로, 벨트 C만 속성이 있고 범위 안.
--   간장 늪: 발판·둑·경사로 높이가 맞물리고, 간장 강 판이 강 전체를 덮어요. 날치알 공 생성 자리가 내리막 위·벽 안.
--   점프·다이브 최고 높이로 칸막이·결승 단 벽을 못 넘어요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local BeltLayout = RobloxRequire.require(Shared.maps.RotatingBeltLayout)
local SoyLayout = RobloxRequire.require(Shared.maps.SoySwampLayout)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local GRAVITY = 196.2

type Fingerprint = { n: number, size: number, x: number, y: number, z: number, collide: number, tags: number }

-- c121dda(m5-40 전 main)에서 같은 계산(아래 fingerprintFront)으로 잰 값.
local OLD_FRONT: { [string]: { limit: number, fp: Fingerprint } } = {
	["rotating-belt"] = {
		limit = -106,
		fp = { n = 52, size = 850.40, x = 219.00, y = 80.62, z = -1921.00, collide = 18, tags = 4 },
	},
	["soy-swamp"] = {
		limit = -160,
		fp = { n = 33, size = 553.76, x = 149.60, y = 50.66, z = -791.85, collide = 6, tags = 4 },
	},
}

local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)

local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = RMaps.get(id).build(origin)
	end
	return built[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function isJudgment(d: any, model: any): boolean
	return d:IsA("BasePart")
		and not under(d, model, "Decor")
		and not under(d, model, "IntroCamera")
		and (d.CanCollide or d.CanTouch or d.CanQuery or under(d, model, "Spawns"))
end

-- 파츠의 origin 기준 로컬 상자 (모서리 8개)
local function localBox(d: any): (any, any)
	local lo = { x = math.huge, y = math.huge, z = math.huge }
	local hi = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = d.CFrame * roblox.Vector3.new(sx * d.Size.X / 2, sy * d.Size.Y / 2, sz * d.Size.Z / 2)
				local p = origin:PointToObjectSpace(w)
				lo.x, lo.y, lo.z = math.min(lo.x, p.X), math.min(lo.y, p.Y), math.min(lo.z, p.Z)
				hi.x, hi.y, hi.z = math.max(hi.x, p.X), math.max(hi.y, p.Y), math.max(hi.z, p.Z)
			end
		end
	end
	return lo, hi
end

local function fingerprintFront(model: any, limit: number): Fingerprint
	local fp: Fingerprint = { n = 0, size = 0, x = 0, y = 0, z = 0, collide = 0, tags = 0 }
	for _, d in model:GetDescendants() do
		if isJudgment(d, model) then
			local lo = localBox(d)
			if lo.z >= limit - 0.01 then
				fp.n += 1
				fp.size += d.Size.X + d.Size.Y + d.Size.Z
				local p = origin:PointToObjectSpace(d.CFrame.Position)
				fp.x += math.abs(p.X)
				fp.y += p.Y
				fp.z += p.Z
				if d.CanCollide then
					fp.collide += 1
				end
				fp.tags += #d:GetTags()
			end
		end
	end
	return fp
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 0.02)
end

local function named(model: any, name: string): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(list, d)
		end
	end
	return list
end

return function(t: Test.Test)
	t.test("QA AC2: 옛 구간(새 구간 앞)의 판정 지문이 c121dda와 같아요", function()
		for id, want in OLD_FRONT do
			local got = fingerprintFront(build(id), want.limit)
			t.eq(got.n, want.fp.n, `{id}: count`)
			t.eq(got.collide, want.fp.collide, `{id}: collide`)
			t.eq(got.tags, want.fp.tags, `{id}: tags`)
			for _, key in { "size", "x", "y", "z" } do
				local g, w = (got :: any)[key], (want.fp :: any)[key]
				t.ok(near(g, w), `{id}: {key} {g} ~= old {w}`)
			end
		end
	end)

	t.test("QA AC2: 스폰 24개는 출발 구간 안, 결승선은 코스의 가장 -Z 쪽", function()
		for _, id in { "rotating-belt", "soy-swamp" } do
			local model = build(id)
			local spawns = model:FindFirstChild("Spawns")
			t.ok(spawns ~= nil, `{id} Spawns`)
			local n = 0
			for _, s in spawns:GetChildren() do
				if s:IsA("BasePart") then
					n += 1
					local p = origin:PointToObjectSpace(s.CFrame.Position)
					t.ok(p.Z <= 0 and p.Z >= -16, `{id} spawn {s.Name} z {p.Z} in the start area`)
				end
			end
			t.eq(n, 24, `{id} spawn count`)
			local lines = named(model, "FinishLine")
			t.eq(#lines, 1, `{id} one finish line`)
			local fz = origin:PointToObjectSpace(lines[1].CFrame.Position).Z
			for _, d in model:GetDescendants() do
				if isJudgment(d, model) and d.CanCollide and d.Name ~= "EndWall" then
					local lo = localBox(d)
					t.ok(lo.z >= fz - 6, `{id} {d.Name} lies before the finish (min z {lo.z})`)
				end
			end
		end
	end)

	t.test(
		"QA AC1: 옆 벨트 칸막이 틈은 start가 미는 방향(RightVector × PushSide)의 반대쪽",
		function()
			local model = build("rotating-belt")
			local zones = {}
			for _, d in named(model, "ConveyorZone") do
				local side = d:GetAttribute("PushSide")
				if side ~= nil then
					table.insert(zones, d)
				end
			end
			t.eq(#zones, #BeltLayout.SIDE_BELTS, "one PushSide zone per side belt")
			local partitions = named(model, "Partition")
			t.eq(#partitions, #BeltLayout.SIDE_BELTS, "one partition per side belt")
			local half = (BeltLayout.sectionByName("SideBelts") :: any).half
			for _, zone in zones do
				local zlo, zhi = localBox(zone)
				local side = zone:GetAttribute("PushSide") :: number
				local found = nil
				for _, part in partitions do
					local plo, phi = localBox(part)
					if plo.z >= zlo.z - 0.01 and phi.z <= zlo.z + 1.01 then
						found = { lo = plo, hi = phi }
					end
				end
				t.ok(found ~= nil, `partition at the back end of zone z {zlo.z}`)
				if found then
					-- origin.RightVector × side = 로컬 +x × side. 막힌 쪽이 미는 쪽 벽에 붙고, 틈은 반대쪽 벽에 붙어요.
					if side > 0 then
						t.ok(near(found.hi.x, half), "solid reaches the +x wall (push side)")
						t.ok(found.lo.x - -half >= BeltLayout.GATE_WIDTH - 0.01, "gap on the -x side")
					else
						t.ok(near(found.lo.x, -half), "solid reaches the -x wall (push side)")
						t.ok(half - found.hi.x >= BeltLayout.GATE_WIDTH - 0.01, "gap on the +x side")
					end
					t.ok(found.hi.y >= BeltLayout.PARTITION_HEIGHT - 0.01, "partition height")
					t.ok(zhi.x - zlo.x >= 2 * half - 0.01, "zone covers the belt width")
				end
			end
			-- 점프 최고점 + 땅 다이브 위 속도까지 더해도 칸막이(8)를 못 넘어요 (공중 다이브는 위 속도를 줄이기만 해요)
			local jump = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
			local dive = Config.Dive.UpSpeed ^ 2 / (2 * GRAVITY)
			t.ok(jump + dive < BeltLayout.PARTITION_HEIGHT, `reach {jump + dive}`)
		end
	)

	t.test(
		"QA AC2: 젓가락 — 옛 벨트 B 스테이션은 속성 없음(옛 범위), 벨트 C 3개만 2.5~3.5",
		function()
			local model = build("rotating-belt")
			local _, beltCFront = BeltLayout.sectionByName("BeltC")
			local old, new = 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("Model") and d.Name == "ChopstickStation" then
					local zone = d:FindFirstChild("Zone")
					local z = origin:PointToObjectSpace(zone.CFrame.Position).Z
					if z > BeltLayout.NEW_FRONT then
						old += 1
						t.eq(d:GetAttribute("CooldownMin"), nil, "old station keeps the default range")
						t.eq(d:GetAttribute("CooldownMax"), nil, "old station keeps the default range")
					else
						new += 1
						t.ok(z <= beltCFront, "new station on belt C")
						t.eq(d:GetAttribute("CooldownMin"), BeltLayout.BELT_C_CHOPSTICKS.cooldownMin)
						t.eq(d:GetAttribute("CooldownMax"), BeltLayout.BELT_C_CHOPSTICKS.cooldownMax)
					end
				end
			end
			t.eq(old, 2, "belt B stations")
			t.eq(new, 3, "belt C stations")
		end
	)

	t.test(
		"QA AC1: 간장 늪 — 발판·둑·경사로 높이가 맞물리고 간장 강이 강 전체를 덮어요",
		function()
			local model = build("soy-swamp")
			local function top(name: string): number
				local list = named(model, name)
				t.eq(#list, 1, name)
				local _, hi = localBox(list[1])
				return hi.y
			end
			t.ok(near(top("LandingBase"), SoyLayout.SLOPE_HIGH), "landing 20")
			t.ok(near(top("Approach2Base"), SoyLayout.SLOPE_HIGH), "far bank 20")
			t.ok(near(top("RiverBase"), SoyLayout.RIVER_BED_Y), "river bed 16")
			for i = 1, #SoyLayout.STONES do
				t.ok(near(top(`StoneRice{i}`), SoyLayout.SLOPE_HIGH), `stone {i} top 20`)
			end
			-- 강 간장 판: 강 전체(z·x)
			local river = named(model, "SoyRiver")[1]
			t.ok(river and river:HasTag("SoySauce"), "river is SoySauce")
			local rlo, rhi = localBox(river)
			t.ok(near(rhi.z, SoyLayout.RIVER.front) and near(rlo.z, SoyLayout.RIVER.back), "river spans the section")
			t.ok(near(rhi.x - rlo.x, SoyLayout.WIDTH), "river spans the width")
			-- 나오는 경사로: 아래 끝은 강바닥, 위 끝은 건너편 둑 높이·자리
			local ramp = named(model, "RiverRamp")[1]
			local up = ramp.CFrame.UpVector
			local function surfaceAt(endSign: number): (number, number)
				local p = ramp.CFrame * roblox.Vector3.new(0, ramp.Size.Y / 2, endSign * ramp.Size.Z / 2)
				local lp = origin:PointToObjectSpace(p)
				return lp.Y, lp.Z
			end
			t.ok(up.Y > 0.9, "ramp faces up")
			local y1, z1 = surfaceAt(-1)
			local y2, z2 = surfaceAt(1)
			local lowY, lowZ, highY, highZ = y1, z1, y2, z2
			if y1 > y2 then
				lowY, lowZ, highY, highZ = y2, z2, y1, z1
			end
			t.ok(near(lowY, SoyLayout.RIVER_BED_Y, 0.05), `ramp low end y {lowY}`)
			t.ok(near(highY, SoyLayout.SLOPE_HIGH, 0.05), `ramp high end y {highY}`)
			t.ok(near(highZ, SoyLayout.RIVER.back, 0.05), `ramp meets the far bank at z {highZ}`)
			t.ok(lowZ > highZ, "ramp climbs toward the finish")
			-- 산 2 느린 길 경사로 위 끝 = 몸통 꼭대기
			local ramp2 = named(model, "Ramp2")[1]
			local _, r2hi = localBox(ramp2)
			t.ok(near(top("MountainBody2"), SoyLayout.MOUNTAIN2_BASE + SoyLayout.MOUNTAIN2_HEIGHT), "body 2 top 32")
			t.ok(r2hi.y >= SoyLayout.MOUNTAIN2_BASE + SoyLayout.MOUNTAIN2_HEIGHT - 0.05, "ramp 2 reaches the top")
			t.ok(near(top("FinishBase"), SoyLayout.SLOPE2_HIGH), "finish 40")
			-- 와사비 패드 2는 Wasabi 태그 (옛 와사비 스테퍼가 그대로 처리 → MoveExempt 포함)
			local pads = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("Wasabi") then
					pads += 1
				end
			end
			t.eq(pads, #SoyLayout.WASABI_PADS + #SoyLayout.WASABI_PADS_2, "all pads tagged")
			-- 결승 단(40)·패드 2(20) 최고점이 벽(48) 아래 (점프 + 땅 다이브, 와사비 + 다이브)
			local jump = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
			local dive = Config.Dive.UpSpeed ^ 2 / (2 * GRAVITY)
			t.ok(SoyLayout.SLOPE2_HIGH + jump + dive < SoyLayout.WALL_HEIGHT, "finish floor")
			local wasabi = SoyLayout.WASABI_UP * SoyLayout.WASABI_HOLD + SoyLayout.WASABI_UP ^ 2 / (2 * GRAVITY)
			t.ok(
				SoyLayout.MOUNTAIN2_BASE + SoyLayout.PAD_THICKNESS + wasabi + dive < SoyLayout.WALL_HEIGHT,
				"pad 2 launch"
			)
			local _, whi = localBox(named(model, "Wall")[1])
			t.ok(near(whi.y, SoyLayout.WALL_HEIGHT), "walls 48")
		end
	)

	t.test(
		"QA AC2: 날치알 내리막 2 공 생성 자리가 내리막 위·벽 안이고 내리막 2 길이만 굴러요",
		function()
			local r = SoyLayout.BALL_DIAMETER / 2
			local z = SoyLayout.BALL_SPAWN_Z_2
			t.ok(z - r > SoyLayout.SLOPE2.back and z + r < SoyLayout.SLOPE2.front, "spawn inside slope 2")
			for _, lane in SoyLayout.BALL_LANES_2 do
				t.ok(
					lane.minX - r >= -SoyLayout.WIDTH / 2 and lane.maxX + r <= SoyLayout.WIDTH / 2,
					"lane inside walls"
				)
			end
			-- 내리막 1 공 생성은 그대로 (옛 상수)
			t.eq(SoyLayout.BALL_SPAWN_Z, -157)
			t.eq(SoyLayout.BALL_SPAWN_HALF_WIDTH, 9)
			-- 내리막 2 공은 내리막 2 앞 끝(산 2 뒤)을 넘으면 사라져요
			t.ok(
				SoyLayout.ballExpired(0, SoyLayout.SLOPE2.front + 1, 32, SoyLayout.SLOPE2),
				"slope 2 ball ends at foot"
			)
		end
	)
end
