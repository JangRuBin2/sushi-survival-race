--!strict
-- m5-17 QA: "고양이 카페 캣타워"(cat-cafe-shelves) 경계값·불변식.
--   - 선반 기하: 같은 단 선반 4개가 겹치지 않고 테두리를 빈틈없이 이루고, 단끼리 수평으로 겹치지 않아요
--     (루트 아래 짧은 레이캐스트가 어느 선반인지 헷갈리지 않음 — 위 단이 아래 단의 천장이 되지 않음).
--   - 스폰 24개: 각자 정확히 1단 선반 하나 위, 서로 3 이상, 탈락 높이보다 위.
--   - 공: 0~300초 동안 공 전체(반지름 포함)가 선반 위, 9개 선반 위상이 서로 다름, 공이 닿지 않는
--     "공 안전 지대"가 선반 길이 축에 없음(꼭대기 포함, 스펙 D2 "꼭대기도 무해하진 않게").
--   - 바깥쪽 방향: 1·2단 선반 위 모든 점에서 넉백 방향이 그 선반의 바깥 가장자리 쪽 성분을 가짐(스펙 D3).
--   - 고양이 발: pickShelf 가중치(occupant 비례), 0명·Top·직전 선반 제외, pawInterval 단조·그레이스 뒤 nil 없음.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Layout = RobloxRequire.require(Shared.maps.CatCafeShelvesLayout)
local Logic = RobloxRequire.require(Shared.maps.CatCafeShelvesLogic)

local EPS = 1e-6

local function lcg(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			-- Park–Miller: 곱이 2^53 안이라 정확해요 (1103515245 LCG는 double 정밀도를 넘어 편향돼요)
			state = (state * 48271) % 2147483647
			return min + math.floor(state / 2147483647 * (max - min + 1))
		end,
	}
end

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local function rectOf(shelf: any): Rect
	local sx = if shelf.axis == "X" then shelf.length else shelf.width
	local sz = if shelf.axis == "X" then shelf.width else shelf.length
	return {
		minX = shelf.centerX - sx / 2,
		maxX = shelf.centerX + sx / 2,
		minZ = shelf.centerZ - sz / 2,
		maxZ = shelf.centerZ + sz / 2,
	}
end

local function rectsOverlap(a: Rect, b: Rect): boolean
	return a.minX < b.maxX - EPS and a.maxX > b.minX + EPS and a.minZ < b.maxZ - EPS and a.maxZ > b.minZ + EPS
end

local function inside(r: Rect, x: number, z: number): boolean
	return x >= r.minX - EPS and x <= r.maxX + EPS and z >= r.minZ - EPS and z <= r.maxZ + EPS
end

-- 선반의 바깥쪽 법선(타워 중심에서 멀어지는 쪽, 테두리 폭 방향)
local function outwardNormal(shelf: any): (number, number)
	if shelf.side == "North" then
		return 0, 1
	elseif shelf.side == "South" then
		return 0, -1
	elseif shelf.side == "East" then
		return 1, 0
	end
	return -1, 0
end

return function(t: Test.Test)
	t.test(
		"QA 기하: 같은 단 선반 4개는 서로 겹치지 않고, 넓이 합 = 바깥 정사각형 − 구멍",
		function()
			local byTier: { [number]: { any } } = {}
			for _, shelf in Layout.shelves() do
				byTier[shelf.tier] = byTier[shelf.tier] or {}
				table.insert(byTier[shelf.tier], shelf)
			end
			for tier = 1, 2 do
				local list = byTier[tier]
				t.eq(#list, 4, `tier {tier}`)
				local area = 0
				for i, a in list do
					area += a.length * a.width
					for j = i + 1, #list do
						t.ok(not rectsOverlap(rectOf(a), rectOf(list[j])), `{a.key} overlaps {list[j].key}`)
					end
				end
				local outer = Layout.outerSideOf(tier)
				local hole = outer - 2 * Layout.SHELF_WIDTH
				t.eq(area, outer * outer - hole * hole, `tier {tier} ring area`)
			end
		end
	)

	t.test(
		"QA 기하: 서로 다른 단의 선반은 수평으로 겹치지 않아요 (위 단이 아래 단의 천장이 아님)",
		function()
			local shelves = Layout.shelves()
			for i, a in shelves do
				for j = i + 1, #shelves do
					local b = shelves[j]
					if a.tier ~= b.tier then
						t.ok(
							not rectsOverlap(rectOf(a), rectOf(b)),
							`{a.key} (tier {a.tier}) over {b.key} (tier {b.tier})`
						)
					end
				end
			end
		end
	)

	t.test(
		"QA 기하: 오르는 틈 4 + 높이 5 — 점프 높이(약 6.4)보다 낮고, 탈락 높이는 1단보다 15 아래",
		function()
			t.eq(Layout.TIER2_TOP_Y - Layout.TIER1_TOP_Y, 5)
			t.eq(Layout.TIER3_TOP_Y - Layout.TIER2_TOP_Y, 5)
			t.ok(Layout.TIER2_TOP_Y - Layout.TIER1_TOP_Y < 6.4)
			t.eq(Layout.ELIMINATION_Y, -11)
			t.ok(
				Layout.ELIMINATION_Y < Layout.TIER1_TOP_Y - 3 - 10,
				"서 있는 루트(바닥 + 약 3)와 탈락선 사이 여유"
			)
		end
	)

	t.test(
		"QA 스폰: 24개 각각 정확히 1단 선반 하나 위, 2·3단 아래가 아님, 서로 3 이상",
		function()
			local spawns = Layout.spawnOffsets()
			t.eq(#spawns, 24)
			local shelves = Layout.shelves()
			for i, s in spawns do
				local hits = 0
				for _, shelf in shelves do
					if inside(rectOf(shelf), s.x, s.z) then
						t.eq(shelf.tier, 1, `spawn {i} is over/under {shelf.key}`)
						hits += 1
					end
				end
				t.eq(hits, 1, `spawn {i} ({s.x}, {s.z}) should be on exactly one shelf`)
				for j = i + 1, #spawns do
					local o = spawns[j]
					local d = math.sqrt((s.x - o.x) ^ 2 + (s.z - o.z) ^ 2)
					t.ok(d >= 3 - EPS, `spawn {i}-{j} distance {d}`)
				end
			end
		end
	)

	t.test(
		"QA 공: 0~300초(0.05초 간격) 공 전체가 선반 길이 안, 위상 9개 모두 서로 달라요",
		function()
			local shelves = Layout.shelves()
			for _, shelf in shelves do
				local step = 0
				while step <= 6000 do
					local offset = Logic.ballOffset(shelf, step * 0.05)
					t.ok(
						math.abs(offset) + Logic.BALL_DIAMETER / 2 <= shelf.length / 2 + EPS,
						`{shelf.key} ball leaves the shelf at t={step * 0.05}`
					)
					step += 1
				end
			end
			for i, a in shelves do
				for j = i + 1, #shelves do
					local b = shelves[j]
					-- 정규화(진폭으로 나눔)한 위치가 t=0과 t=1에서 둘 다 같으면 같은 위상
					local same = true
					for _, tt in { 0, 1, 2.3 } do
						local na = Logic.ballOffset(a, tt) / Logic.ballAmplitude(a)
						local nb = Logic.ballOffset(b, tt) / Logic.ballAmplitude(b)
						if math.abs(na - nb) > 1e-3 then
							same = false
						end
					end
					t.ok(not same, `{a.key} and {b.key} move in lockstep`)
				end
			end
		end
	)

	t.test(
		"QA 공: 선반 길이 축 어디에 서 있어도 한 주기 안에 공에 닿아요 (공 안전 지대 없음, 꼭대기 포함)",
		function()
			for _, shelf in Layout.shelves() do
				local half = shelf.length / 2
				local along = -half
				while along <= half + EPS do
					local hit = false
					local tt = 0
					while tt <= Logic.BALL_PERIOD + EPS do
						if Logic.isHit(math.abs(along - Logic.ballOffset(shelf, tt))) then
							hit = true
							break
						end
						tt += 0.01
					end
					t.ok(hit, `{shelf.key}: standing at along={along} is never hit`)
					along += 0.5
				end
			end
		end
	)

	t.test("QA isHit 경계: 2.2 맞음, 2.2+1e-6 안 맞음, 음수 거리 없음(호출 쪽이 abs)", function()
		t.eq(Logic.BALL_HIT_RANGE, 2.2)
		t.ok(Logic.isHit(2.2))
		t.ok(not Logic.isHit(2.2 + 1e-6))
		t.ok(Logic.isHit(0))
	end)

	t.test(
		"QA 넉백 방향: 1·2단 선반 위 모든 점에서 그 선반의 바깥 가장자리 쪽 성분이 0.55 이상",
		function()
			for _, shelf in Layout.shelves() do
				if shelf.side == "Top" then
					continue
				end
				local r = rectOf(shelf)
				local nx, nz = outwardNormal(shelf)
				local x = r.minX
				while x <= r.maxX + EPS do
					local z = r.minZ
					while z <= r.maxZ + EPS do
						local dx, dz = Logic.outwardDirection(Layout.TOWER_CENTER_X, Layout.TOWER_CENTER_Z, x, z)
						t.ok(math.abs(dx * dx + dz * dz - 1) < 1e-6, "unit vector")
						local dot = dx * nx + dz * nz
						t.ok(dot >= 0.55, `{shelf.key} at ({x}, {z}): outward component {dot}`)
						z += 0.5
					end
					x += 0.5
				end
			end
		end
	)

	t.test("QA pickShelf: occupant 수에 비례해 고르고(3:1 → 약 75%), Top만 있으면 nil", function()
		local rng = lcg(1709)
		local counts: { [string]: number } = {}
		local N = 8000
		for _ = 1, N do
			local key = Logic.pickShelf({ Tier1North = 3, Tier2East = 1, Top = 50 }, nil, rng)
			t.ok(key == "Tier1North" or key == "Tier2East", `picked {key}`)
			counts[key :: string] = (counts[key :: string] or 0) + 1
		end
		local share = (counts.Tier1North or 0) / N
		t.ok(math.abs(share - 0.75) < 0.03, `Tier1North share {share}`)
		t.eq(Logic.pickShelf({ Top = 10 }, nil, rng), nil)
		t.eq(Logic.pickShelf({}, nil, rng), nil)
		t.eq(Logic.pickShelf({ Tier1South = 0, Tier1West = -1 :: any }, nil, rng), nil)
		-- 모르는 키(오타)는 무시
		t.eq(Logic.pickShelf({ Nope = 5 }, nil, rng), nil)
	end)

	t.test(
		"QA pickShelf: 무작위 occupancy 2000번 — 결과는 항상 occupant > 0, Top 아님, 직전 선반 아님",
		function()
			local rng = lcg(42)
			local keys = {}
			for _, shelf in Layout.shelves() do
				table.insert(keys, shelf.key)
			end
			local previous: string? = nil
			for _ = 1, 2000 do
				local occupancy: { [string]: number } = {}
				for _, key in keys do
					if rng:NextInteger(1, 3) == 1 then
						occupancy[key] = rng:NextInteger(1, 6)
					end
				end
				local picked = Logic.pickShelf(occupancy, previous, rng)
				if picked ~= nil then
					t.ok((occupancy[picked] or 0) > 0, `picked empty {picked}`)
					t.ok(picked ~= "Top", "picked Top")
					t.ok(picked ~= previous, "picked previous")
				else
					-- nil이면 정말로 후보가 없어야 해요
					for key, n in occupancy do
						if n > 0 and key ~= "Top" then
							t.eq(key, previous, `nil although {key} had {n}`)
						end
					end
				end
				previous = picked or previous
			end
		end
	)

	t.test(
		"QA pawInterval: 그레이스 뒤 0~300초 nil 없음, 단조 감소(안 늘어남), 2 아래로 안 감",
		function()
			local last = math.huge
			local tt = Logic.PAW_GRACE
			while tt <= 300 do
				local interval = Logic.pawInterval(tt)
				t.ok(interval ~= nil, `nil at {tt}`)
				t.ok((interval :: number) <= last + EPS, `interval grows at {tt}`)
				t.ok((interval :: number) >= 2 - EPS, `interval below 2 at {tt}`)
				last = interval :: number
				tt += 0.1
			end
			t.eq(Logic.pawInterval(-1), nil)
			t.eq(Logic.pawInterval(0), nil)
		end
	)
end
