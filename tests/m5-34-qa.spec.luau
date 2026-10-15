--!strict
-- m5-34 QA (dish-sink): 개발 테스트가 안 본 경계를 더 확인해요.
--   이동 감시 여유(연속 밀기 + 다이브가 상한 아래), 넉백 면제 길이, 수세미 맞음 상자(패드 포함)가 접시·칸막이 머리에
--   안 닿음, 패드까지 넣은 "실제로 안전한 시간", 오르막 쐐기 방향, 판정 파츠가 Layout 그대로, 모듈 수준 상태 없음.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.DishSinkLayout)
local Logic = RobloxRequire.require(Shared.maps.DishSinkLogic)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local RCF: any = roblox.CFrame

local function near(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

-- 접시 목표 수평 속도의 최댓값 (반지름을 촘촘히 훑어요)
local function maxPlateSpeed(kind: any): number
	local best = 0
	for i = 0, 1000 do
		local r = kind.radius * i / 1000
		local vx, vz = Logic.platePush(r, 0, 1, kind)
		if vx and vz then
			best = math.max(best, math.sqrt(vx * vx + vz * vz))
		end
	end
	return best
end

-- 수세미 i의 맞음 상자(패드 포함)에 x 자리 루트가 안 맞는 시간 (한 주기 8초 안, 발은 바닥)
local function safeTime(i: number, rootX: number): (number, number)
	local sponge = Layout.SPONGES[i]
	local dt = 0.005
	local total, longest, run = 0, 0, 0
	-- 두 주기를 돌려 주기 경계에 걸친 연속 구간도 셉니다
	for step = 0, math.floor(16 / dt) - 1 do
		local time = step * dt
		local hit = Logic.spongeHit(rootX - Logic.spongeX(i, time), 0, 0, sponge.sizeX, sponge.sizeZ)
		if not hit then
			if time < 8 then
				total += dt
			end
			run += dt
			longest = math.max(longest, run)
		else
			run = 0
		end
	end
	return total, longest
end

return function(t: Test.Test)
	t.test(
		"QA: 접시 밀기 + 다이브·걷기가 이동 감시 상한보다 작아요 (연속 밀기라 면제 없음)",
		function()
			local small = maxPlateSpeed(Layout.SMALL_PLATE)
			local big = maxPlateSpeed(Layout.BIG_PLATE)
			t.ok(near(small, math.sqrt(8 ^ 2 + 2.5 ^ 2), 0.01), `small plate max {small}`)
			t.ok(near(big, math.sqrt(10 ^ 2 + 2.5 ^ 2), 0.01), `big plate max {big}`)
			local guard = Config.MovementGuard.MaxHorizontalSpeed
			t.ok(big + Config.Dive.ForwardSpeed < guard, `dive + push {big + Config.Dive.ForwardSpeed} < {guard}`)
			t.ok(big + Config.Character.WalkSpeed < guard, "walk + push")
			-- 수세미 넉백도 면제 없이 상한 아래 (면제는 PlatformStand 착지 흔들림 대비)
			t.ok(Layout.SPONGE_KNOCK_SIDE + big < guard, "knock + push")
			t.ok(Layout.SPONGE_KNOCK_UP < Config.MovementGuard.MaxRiseSpeed, "knock up")
			t.ok(Layout.SPONGE_EXEMPT >= Config.MovementGuard.ExemptAfterServerMove, "exempt covers server move window")
			t.ok(Layout.SPONGE_EXEMPT >= Layout.SPONGE_KNOCKDOWN, "exempt covers knockdown")
			t.ok(Layout.SPONGE_COOLDOWN < Layout.SPONGE_EXEMPT, "cooldown shorter than exempt")
			-- 밀기 가속은 목표를 넘지 않아요 (이미 빠르면 더하지 않음)
			t.eq(Logic.pushDelta(50, 10, 24, 1 / 60), 0)
			t.eq(Logic.pushDelta(-50, -10, 24, 1 / 60), 0)
			t.ok(near(Logic.pushDelta(9.99, 10, 24, 1), 0.01, 1e-9), "clamped to the target")
		end
	)

	t.test(
		"QA: 수세미 맞음 상자(패드 포함, 어느 x든)가 접시·칸막이 머리·컵에 닿지 않아요",
		function()
			local headBack = Layout.PARTITION_HEAD.back
			for _, sponge in Layout.SPONGES do
				local hz = sponge.sizeZ / 2 + Layout.SPONGE_HIT_PAD_Z
				local zFront, zBack = sponge.z + hz, sponge.z - hz
				for _, plate in Layout.PLATES do
					-- 접시 원과 z 띠 사이 거리 (x는 왕복 전체를 덮는다고 봐요)
					local dz = math.max(plate.z - zFront, zBack - plate.z, 0)
					t.ok(dz > plate.kind.radius, `sponge {sponge.index} hit zone reaches plate {plate.index} (dz {dz})`)
				end
				for _, cup in Layout.CUP_LIST do
					local dz = math.max(cup.z - zFront, zBack - cup.z, 0)
					t.ok(dz > cup.radius, `sponge {sponge.index} vs cup {cup.index}`)
				end
				t.ok(zFront < headBack, `sponge {sponge.index} hit zone reaches the partition head`)
				-- 수세미가 놓인 길 위에 있어요
				t.eq(Logic.sectionAt(sponge.z), sponge.section)
			end
			-- E 수세미는 둘째 다리 위 (D6), 다리 z 범위를 넘지 않아요
			local bridge = Layout.BRIDGES[2]
			local s4 = Layout.SPONGES[4]
			t.ok(s4.z > bridge.minZ and s4.z < bridge.maxZ, "sponge 4 on bridge 2")
			t.eq(s4.floorY, bridge.top)
		end
	)

	t.test(
		"QA: 패드까지 넣어도 길 안쪽(가장자리 1 안) 어디서든 한 주기에 3초 안전, 가운데는 연속 0.8초 이상",
		function()
			for _, sponge in Layout.SPONGES do
				local half = Logic.pathHalfWidth(sponge)
				local worst = math.huge
				for k = 0, 20 do
					local x = -(half - 1) + (2 * (half - 1)) * k / 20
					local total = safeTime(sponge.index, x)
					worst = math.min(worst, total)
				end
				t.ok(worst >= 3 - 0.02, `sponge {sponge.index} worst safe time {worst}`)
				-- 가운데(x 0)로 맞음 상자 z 깊이(sizeZ + 2·패드)를 걷기 16으로 지나갈 시간보다 길게 빈다
				local _, longest = safeTime(sponge.index, 0)
				local need = (sponge.sizeZ + 2 * Layout.SPONGE_HIT_PAD_Z + 2) / Layout.WALK_SPEED
				t.ok(longest >= need + 0.2, `sponge {sponge.index} center window {longest} vs {need}`)
			end
		end
	)

	t.test(
		"QA: 서버 build — 오르막 쐐기 높은 쪽이 결승(-Z), 판정 바닥·컵·결승선이 Layout 그대로",
		function()
			local origin = RCF.new(0, 300, 2000)
			local model = RMaps.get("dish-sink").build(origin)
			local ramp = model:FindFirstChild("Ramp")
			t.ok(ramp ~= nil and ramp:IsA("WedgePart"), "ramp wedge")
			-- WedgePart의 낮은 쪽(경사면)은 로컬 -Z(LookVector). 결승이 -Z이므로 LookVector가 +Z(출발 쪽)여야 해요
			local look = origin:VectorToObjectSpace(ramp.CFrame.LookVector)
			t.ok(near(look.Z, 1, 1e-6), `ramp low side faces the start: {look}`)
			t.ok(near(ramp.Size.Y, Layout.FINISH_Y - Layout.HIGH_Y, 1e-6), "ramp height 6")
			t.ok(ramp.CanCollide, "ramp collides")
			for _, rect in Layout.floorRects() do
				local part = model:FindFirstChild(rect.name)
				t.ok(part ~= nil and part.CanCollide and part.Anchored, `{rect.name} judgment part`)
				local rel = origin:PointToObjectSpace(part.CFrame.Position)
				t.ok(near(part.Size.X, rect.maxX - rect.minX, 1e-6), `{rect.name} width`)
				t.ok(near(part.Size.Z, rect.maxZ - rect.minZ, 1e-6), `{rect.name} length`)
				t.ok(near(rel.Y + part.Size.Y / 2, rect.top, 1e-6), `{rect.name} top`)
				t.ok(near(rel.Z, (rect.minZ + rect.maxZ) / 2, 1e-6), `{rect.name} z`)
			end
			for _, cup in Layout.CUP_LIST do
				local part = model:FindFirstChild(`Cup{cup.index}`)
				t.ok(part ~= nil and part.CanCollide, `cup {cup.index}`)
				local rel = origin:PointToObjectSpace(part.CFrame.Position)
				t.ok(near(rel.Y + Layout.CUP_HEIGHT / 2, cup.top, 1e-6), `cup {cup.index} top`)
				t.ok(near(part.Size.Y, cup.radius * 2, 1e-6), `cup {cup.index} diameter`)
			end
			-- 결승선은 평지 건조대 위, 그 자리 낙하선은 바닥 아래
			t.ok(
				Layout.FINISH_LINE_Z < Layout.RAMP.back and Layout.FINISH_LINE_Z > Layout.FINISH.back,
				"finish on flat rack"
			)
			t.eq(Logic.fallLineAt(Layout.FINISH_LINE_Z), Layout.FINISH_Y - Layout.FALL_MARGIN)
			-- 장식 폴더 안 파츠는 모두 충돌·쿼리·터치 없음 (아트가 판정을 만들지 않아요)
			local decor = model:FindFirstChild("Decor")
			t.ok(decor ~= nil, "decor folder")
			local decorParts = 0
			for _, d in decor:GetDescendants() do
				if d:IsA("BasePart") then
					decorParts += 1
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, `decor {d.Name} must not collide`)
				end
			end
			t.ok(decorParts >= 700, `decor parts {decorParts}`)
			-- 판정 파츠(충돌 있음)는 정해진 이름뿐이에요
			local allowed: { [string]: boolean } = { RampBase = true, Ramp = true }
			for _, rect in Layout.floorRects() do
				allowed[rect.name] = true
			end
			for _, plate in Layout.PLATES do
				allowed[string.format("SinkPlate%02d", plate.index)] = true
			end
			for _, cup in Layout.CUP_LIST do
				allowed[`Cup{cup.index}`] = true
			end
			local collidable = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide then
					collidable += 1
					t.ok(allowed[d.Name] == true, `unexpected collidable part {d.Name}`)
				end
			end
			t.eq(collidable, #Layout.floorRects() + 2 + #Layout.PLATES + #Layout.CUP_LIST)
		end
	)

	t.test("QA: 서버 모듈에 모듈 수준 상태가 없고 태그는 ctx.model 하위만 써요", function()
		local source = fs.readFile("src/shared/maps/DishSink.luau")
		for line in string.gmatch(source, "[^\n]+") do
			-- 들여쓰기 없는 local 선언 중 표·숫자 상태가 있으면 안 돼요 (상수 문자열·require·함수만)
			if string.match(line, "^local ") and not string.match(line, "^local function") then
				local ok = string.match(line, "= require%(") ~= nil
					or string.match(line, '= "[^"]*"$') ~= nil
					or string.match(line, "Config%.Room%.MaxPlayerOptions") ~= nil
					or string.match(line, "= {$") ~= nil and string.match(line, "^local map") ~= nil
				t.ok(ok, `module-level state? {line}`)
			end
		end
		local _, tagged = string.gsub(source, ":GetTagged%(", "")
		t.eq(tagged, 1, "one GetTagged call (taggedParts)")
		t.ok(string.find(source, "ctx.model:IsAncestorOf(instance)", 1, true) ~= nil, "filtered by ctx.model")
		-- 판정은 ctx.pass / ctx.eliminate로만
		t.ok(string.find(source, "ctx.pass(player)", 1, true) ~= nil)
		t.ok(string.find(source, "ctx.eliminate(player)", 1, true) ~= nil)
		t.eq(string.find(source, "OnServerEvent", 1, true), nil, "no remotes")
	end)
end
