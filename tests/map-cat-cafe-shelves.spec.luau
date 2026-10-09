--!strict
-- m5-17 Survival 맵 "고양이 카페 캣타워": 캣타워 치수, 오르는 틈, 장난감 공 왕복·맞음,
-- 바깥쪽 방향, 고양이 발 일정·선반 고르기, 아트 예산 (순수 로직)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)
local Logic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)
local Art = RobloxRequire.require(Shared.maps.CatCafeShelvesArt)

-- ChefBoardLogic.pickLine 테스트와 같은 패턴의 가짜 결정론적 rng (NextInteger만 써요)
local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test("AC1: cat-cafe-shelves는 인터페이스를 지키는 Survival 맵", function()
		local map = Maps.get("cat-cafe-shelves")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Survival")
		t.eq(map.displayName, "고양이 카페 캣타워")
		t.eq(map.timeLimit, nil) -- Config.TimeLimit.Survival(60)을 써요
		t.ok(map.inPool ~= false, "inPool = false 줄이 지워졌어야 해요")
	end)

	---------------------------------------------------------------- AC2
	t.test("AC2: 선반 9개(1단 4 + 2단 4 + 3단 1)가 표와 정확히 일치", function()
		local shelves = Layout.shelves()
		t.eq(#shelves, 9)

		local tier1, tier2, top = 0, 0, 0
		for _, shelf in shelves do
			if shelf.tier == 1 then
				tier1 += 1
				t.ok(shelf.length == 44 or shelf.length == 36, `tier1 length {shelf.length}`)
				t.eq(shelf.width, 4)
				t.eq(shelf.topY, 4)
			elseif shelf.tier == 2 then
				tier2 += 1
				t.ok(shelf.length == 28 or shelf.length == 20, `tier2 length {shelf.length}`)
				t.eq(shelf.width, 4)
				t.eq(shelf.topY, 9)
			else
				top += 1
				t.eq(shelf.side, "Top")
				t.eq(shelf.length, 12)
				t.eq(shelf.width, 12)
				t.eq(shelf.topY, 14)
			end
		end
		t.eq(tier1, 4)
		t.eq(tier2, 4)
		t.eq(top, 1)

		-- 선반마다 key가 서로 달라요
		local seen: { [string]: boolean } = {}
		for _, shelf in shelves do
			t.ok(not seen[shelf.key], `duplicate key {shelf.key}`)
			seen[shelf.key] = true
		end
	end)

	t.test("AC2: 1단·2단 긴 선반 2개는 axis X, 짧은 선반 2개는 axis Z", function()
		for _, shelf in Layout.shelves() do
			if shelf.tier == 1 or shelf.tier == 2 then
				if shelf.side == "North" or shelf.side == "South" then
					t.eq(shelf.axis, "X")
				else
					t.eq(shelf.axis, "Z")
				end
			end
		end
	end)

	---------------------------------------------------------------- AC3
	t.test("AC3: 스폰 24개가 1단 선반 범위 안, 양 끝 4 이상, 서로 3 이상", function()
		local spawns = Layout.spawnOffsets()
		t.eq(#spawns, 24)

		local tier1Shelves = {}
		for _, shelf in Layout.shelves() do
			if shelf.tier == 1 then
				table.insert(tier1Shelves, shelf)
			end
		end

		for _, spawn in spawns do
			local onAny = false
			for _, shelf in tier1Shelves do
				local along, across
				if shelf.axis == "X" then
					along, across = spawn.x - shelf.centerX, spawn.z - shelf.centerZ
				else
					along, across = spawn.z - shelf.centerZ, spawn.x - shelf.centerX
				end
				if math.abs(across) < 1e-6 and math.abs(along) <= shelf.length / 2 - 2 + 1e-6 then
					onAny = true
					t.ok(shelf.length / 2 - math.abs(along) >= 4 - 1e-6, "spawn too close to shelf end")
				end
			end
			t.ok(onAny, `spawn ({spawn.x}, {spawn.z}) not on a tier-1 shelf`)
		end

		for a = 1, #spawns do
			for b = a + 1, #spawns do
				local dx = spawns[a].x - spawns[b].x
				local dz = spawns[a].z - spawns[b].z
				t.ok(math.sqrt(dx * dx + dz * dz) >= 3 - 1e-6, `spawn {a} and {b} too close`)
			end
		end
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: climbGap(1)·climbGap(2) 둘 다 4, 단 사이 높이 차 둘 다 5", function()
		t.eq(Logic.climbGap(1), 4)
		t.eq(Logic.climbGap(2), 4)
		t.eq(Layout.TIER2_TOP_Y - Layout.TIER1_TOP_Y, 5)
		t.eq(Layout.TIER3_TOP_Y - Layout.TIER2_TOP_Y, 5)
	end)

	---------------------------------------------------------------- AC5
	t.test("AC5: 공은 0~60초 내내 선반 밖으로 안 나가고, t=0 위상이 선반마다 달라요", function()
		local shelves = Layout.shelves()
		local t0Offsets = {}
		for _, shelf in shelves do
			local limit = shelf.length / 2 - Logic.BALL_DIAMETER / 2
			local time = 0
			while time <= 60 + 1e-9 do
				local offset = Logic.ballOffset(shelf, time)
				t.ok(math.abs(offset) <= limit + 1e-6, `{shelf.key} ball out of bounds at t={time}`)
				time += 0.25
			end
			t0Offsets[shelf.key] = Logic.ballOffset(shelf, 0)
		end
		local distinct: { [number]: boolean } = {}
		for _, offset in t0Offsets do
			distinct[math.floor(offset * 1e6 + 0.5)] = true
		end
		local count = 0
		for _ in distinct do
			count += 1
		end
		t.ok(count > 1, "all shelves should not share the same t=0 offset")
	end)

	---------------------------------------------------------------- AC6
	t.test("AC6: isHit(diff) 맞음 판정 (2.2 이하면 맞음)", function()
		t.eq(Logic.isHit(2.2), true)
		t.eq(Logic.isHit(2.21), false)
		t.eq(Logic.isHit(0), true)
	end)

	---------------------------------------------------------------- AC7
	t.test("AC7: outwardDirection은 중심 → 점 방향 단위 벡터, 중심이면 고정 기본값", function()
		local samples = {
			{ x = 10, z = 0 },
			{ x = -10, z = 0 },
			{ x = 0, z = 10 },
			{ x = 3, z = -4 },
		}
		for _, sample in samples do
			local dx, dz = Logic.outwardDirection(0, 0, sample.x, sample.z)
			local mag = math.sqrt(dx * dx + dz * dz)
			t.ok(math.abs(mag - 1) < 1e-6, `direction for ({sample.x},{sample.z}) not unit`)
			-- 중심에서 점 쪽으로: 내적(점 방향 벡터, 방향)이 양수
			t.ok(dx * sample.x + dz * sample.z > 0, "direction should point towards the sample")
		end

		local dx, dz = Logic.outwardDirection(5, -5, 5, -5)
		local mag = math.sqrt(dx * dx + dz * dz)
		t.ok(math.abs(mag - 1) < 1e-6, "centre case should still be a unit vector")
	end)

	---------------------------------------------------------------- AC8
	t.test("AC8: pawInterval 그레이스 8초, 5 → 3.2 → 2초", function()
		t.eq(Logic.pawInterval(7.9), nil)
		t.eq(Logic.pawInterval(8), 5)
		t.eq(Logic.pawInterval(24.9), 5)
		t.eq(Logic.pawInterval(25), 3.2)
		t.eq(Logic.pawInterval(44.9), 3.2)
		t.eq(Logic.pawInterval(45), 2)
		t.eq(Logic.pawInterval(60), 2)
	end)

	---------------------------------------------------------------- AC9
	t.test("AC9: pickShelf: occupant 0 안 고름, Top 안 고름, 연속 금지, 후보 없으면 nil", function()
		local occupancy = {
			Tier1North = 3,
			Tier1South = 0,
			Tier1East = 2,
			Tier1West = 0,
			Tier2North = 1,
			Tier2South = 0,
			Tier2East = 0,
			Tier2West = 0,
			Top = 5,
		}
		local seenEmpty: { [string]: boolean } = {}
		for _, key in { "Tier1South", "Tier1West", "Tier2South", "Tier2East", "Tier2West" } do
			seenEmpty[key] = true
		end

		for seed = 1, 40 do
			local picked = Logic.pickShelf(occupancy, nil, fakeRng(seed))
			t.ok(picked ~= nil, "candidates exist, should not be nil")
			t.ok(picked ~= "Top", "Top must never be picked")
			t.ok(not seenEmpty[picked :: string], `{picked} has 0 occupants`)
		end

		-- 연속 금지: previousKey가 후보 중 하나일 때, 다른 후보가 있으면 절대 같은 걸 다시 안 골라요
		for seed = 1, 40 do
			local picked = Logic.pickShelf(occupancy, "Tier1North", fakeRng(seed))
			t.ok(picked ~= "Tier1North", "must not repeat the previous shelf")
		end

		-- 후보가 previousKey 하나뿐이면 nil
		local onlyOne = { Tier1North = 4 }
		t.eq(Logic.pickShelf(onlyOne, "Tier1North", fakeRng(1)), nil)

		-- occupant가 전부 0이면 nil
		local allEmpty = { Tier1North = 0, Tier1South = 0 }
		t.eq(Logic.pickShelf(allEmpty, nil, fakeRng(1)), nil)
	end)

	---------------------------------------------------------------- AC10
	t.test("AC10: 장식이 MapKitLogic.validate 통과, 파츠·파티클·조명 예산 안", function()
		local decor = Art.decor()
		t.eq(MapKitLogic.validate(decor), nil)
		t.ok(MapKitLogic.count(decor) <= MapKitLogic.DECOR_PART_BUDGET, `decor {MapKitLogic.count(decor)} parts`)

		local lights, particles = 0, 0
		for _, spec in decor do
			if spec.name == Art.WINDOW_LIGHT then
				lights += 1
			elseif spec.name == Art.SUNBEAM then
				particles += 1
			end
		end
		t.ok(lights <= MapKitLogic.LIGHT_BUDGET, `{lights} lights over budget`)
		t.ok(particles <= MapKitLogic.PARTICLE_BUDGET, `{particles} particles over budget`)
	end)

	t.test("AC10: IntroCamera 4점", function()
		local points = Art.introCamera()
		t.eq(#points, 4)
	end)
end
