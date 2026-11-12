--!strict
-- m6-02 QA (docs/qa/m6-02-large-map-foundation.md): 대형 맵 기반 경계값 보강.
--   - 실제 맵 풀(Maps.infos)로 4~40명 모든 시작 인원 × 여러 시드 판 계획 불변식
--     (1R Race·마지막 Final·중복 없음·4라운드 Survival ≥ 1·스폰 ≥ 최대 인원·대형 맵은 예상 12명 이상·25명 이상 1R 대형 Race)
--   - 2라운드부터는 어떤 종류 조합이어도 최대 인원 ≤ 24 → 기존 맵(스폰 24)이 언제나 받을 수 있음
--   - 통과 인원 경계(24 ↔ 25 비율 전환, clamp 2 ~ 남은 인원 - 1)
--   - 방 인원 검증(RoomLogic.validateSettings·PlacePayload)과 40명 매니페스트
--   - 26개 맵을 실제로 지어(렌더러 가짜 Roblox 환경) Spawns 수 = capacity

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)
local RoomLogic = RobloxRequire.require(Shared.RoomLogic)
local PlacePayload = RobloxRequire.require(Shared.PlacePayload)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local LARGE = Config.Maps.LargeCapacity
local STANDARD = Config.Maps.StandardCapacity
local LARGE_MIN = Config.Maps.LargeMinPlayers

-- 1라운드는 Race, 마지막은 Final, 가운데는 Race/Survival의 모든 조합
local function allKinds(roundCount: number): { { string } }
	local out = {}
	local middle = roundCount - 2
	for mask = 0, 2 ^ middle - 1 do
		local kinds = { "Race" }
		for i = 1, middle do
			kinds[i + 1] = if bit32.band(mask, 2 ^ (i - 1)) ~= 0 then "Survival" else "Race"
		end
		kinds[roundCount] = "Final"
		table.insert(out, kinds)
	end
	return out
end

return function(t: Test.Test)
	t.test(
		"실제 풀: 대형 맵은 Race 3·Survival 2(capacity 40·minPlayers 12), 나머지는 비어 있음(24)",
		function()
			local large = { Race = 0, Survival = 0, Final = 0 }
			local total = 0
			for _, info in Maps.infos() do
				total += 1
				if info.capacity ~= nil then
					t.eq(info.capacity, LARGE, info.id)
					t.eq(info.minPlayers, LARGE_MIN, info.id)
					large[info.kind] += 1
				else
					t.eq(info.minPlayers, nil, info.id)
				end
			end
			t.eq(total, 26)
			t.eq(large, { Race = 3, Survival = 2, Final = 0 })
		end
	)

	t.test(
		"실제 풀 판 계획: 4~40명 × 시드 80개 — 종류 규칙·중복 없음·스폰 넉넉·대형 맵 인원 조건",
		function()
			local pool = Maps.infos()
			local largeSeen = 0
			for start = 4, 40 do
				local roundCount = Rules.roundCount(start)
				for seed = 1, 80 do
					local plan = Rules.buildRoundPlan(roundCount, pool, fakeRng(seed * 7919 + start), start)
					local tag = `start {start} seed {seed}`
					t.eq(#plan, roundCount, tag)
					t.eq(plan[1].kind, "Race", tag)
					t.eq(plan[roundCount].kind, "Final", tag)
					local kinds = {}
					local seen = {}
					local survival = 0
					for i, map in plan do
						kinds[i] = map.kind
						t.ok(not seen[map.id], `{tag}: duplicate {map.id}`)
						seen[map.id] = true
						if map.kind == "Survival" then
							survival += 1
						end
						if i > 1 and i < roundCount then
							t.ok(map.kind == "Race" or map.kind == "Survival", `{tag}: middle {map.kind}`)
						end
					end
					if roundCount == 4 then
						t.ok(survival >= 1, `{tag}: 4 rounds need a Survival`)
					end
					local expected, upper = Rules.roundCounts(start, kinds)
					for i, map in plan do
						t.ok(
							Rules.capacityOf(map) >= upper[i],
							`{tag} round {i}: {map.id} capacity {Rules.capacityOf(map)} < upper {upper[i]}`
						)
						if map.capacity == LARGE then
							largeSeen += 1
							t.ok(expected[i] >= LARGE_MIN, `{tag} round {i}: large {map.id} for {expected[i]}`)
						end
					end
					if start >= Config.Rules.LargeMinPlayers then
						t.eq(plan[1].capacity, LARGE, `{tag}: round 1 must be a large Race`)
					end
					if start < LARGE_MIN then
						for _, map in plan do
							t.eq(map.capacity, nil, `{tag}: no large map below {LARGE_MIN}`)
						end
					end
				end
			end
			t.ok(largeSeen > 0)
		end
	)

	t.test(
		"2라운드부터 최대 인원은 어떤 종류 조합이어도 24 이하 (기존 맵이 언제나 받음)",
		function()
			for start = 4, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions] do
				local roundCount = Rules.roundCount(start)
				for _, kinds in allKinds(roundCount) do
					local expected, upper = Rules.roundCounts(start, kinds)
					for i = 2, roundCount do
						t.ok(upper[i] <= STANDARD, `start {start} {table.concat(kinds, ",")} round {i}: {upper[i]}`)
						t.ok(expected[i] <= upper[i], `start {start} round {i}: expected > upper`)
						t.ok(expected[i] >= 2, `start {start} round {i}: expected {expected[i]} < 2`)
					end
				end
			end
		end
	)

	t.test("통과 인원 경계: 24명 판은 0.65·0.55·0.50, 25명 판부터 0.60·0.45·0.40", function()
		t.eq(Rules.qualifyCount(24, 4, 1, 24), 16) -- 15.6
		t.eq(Rules.qualifyCount(25, 4, 1, 25), 15)
		-- 비율은 "판을 시작한 인원"으로 고르고, 계산은 출발 때 살아 있는 인원으로 (이탈 반영)
		t.eq(Rules.qualifyCount(20, 4, 2, 40), 9) -- 20 × 0.45 = 9
		t.eq(Rules.qualifyCount(20, 4, 2, 24), 11) -- 20 × 0.55 = 11
		t.eq(Rules.roundCount(8), 3)
		t.eq(Rules.roundCount(9), 4)
		t.eq(Rules.roundCount(40), 4)
		for start = 25, 40 do
			for roundIndex = 1, 3 do
				for alive = 3, start do
					local q = Rules.qualifyCount(alive, 4, roundIndex, start)
					t.ok(q >= 2 and q <= alive - 1, `start {start} r{roundIndex} alive {alive}: {q}`)
				end
			end
			t.eq(Rules.qualifyCount(start, 4, 4, start), 1)
		end
	end)

	t.test(
		"방 인원 검증: 고를 수 있는 7개만, 그 밖(33·41·0·음수·소수·NaN·문자열·inf)은 거절",
		function()
			for _, n in Config.Room.MaxPlayerOptions do
				local ok = RoomLogic.validateSettings({ maxPlayers = n, isPrivate = false })
				t.ok(ok ~= nil, `accept {n}`)
				t.ok(
					PlacePayload.validateSettings({ maxPlayers = n, isPrivate = true, name = "room" }) ~= nil,
					`payload {n}`
				)
			end
			for _, bad in { 33, 41, 48, 50, 0, -40, 39.5, 0 / 0, math.huge, "40", true } :: { any } do
				local ok, err = RoomLogic.validateSettings({ maxPlayers = bad, isPrivate = false })
				t.eq(ok, nil, `reject {tostring(bad)}`)
				t.ok(err ~= nil)
				t.eq(PlacePayload.validateSettings({ maxPlayers = bad, isPrivate = false, name = "room" }), nil)
			end
		end
	)

	t.test("텔레포트 매니페스트: 40명 방 40명은 통과, 41명·방 인원 초과는 거절", function()
		local function ids(n: number): { number }
			local list = {}
			for i = 1, n do
				list[i] = 1000 + i
			end
			return list
		end
		local function manifest(maxPlayers: number, members: number): any
			return PlacePayload.manifest({
				roomKey = "room-key",
				settings = { maxPlayers = maxPlayers, isPrivate = false, name = "room" },
				hostUserId = 1001,
				memberUserIds = ids(members),
				lobbyJobId = "job",
				createdAt = 1,
			})
		end
		t.ok(PlacePayload.validateManifest(manifest(40, 40)) ~= nil, "40 / 40")
		t.ok(PlacePayload.validateManifest(manifest(32, 32)) ~= nil, "32 / 32")
		t.eq(PlacePayload.validateManifest(manifest(32, 33)), nil)
		t.eq(PlacePayload.validateMembers(ids(41)), nil)
		t.ok(PlacePayload.validateMembers(ids(40)) ~= nil)
	end)

	t.test("26개 맵을 실제로 지으면 Spawns 수 = capacity (기존 24, 대형 40)", function()
		local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
		for _, info in Maps.allInfos() do
			local model = RMaps.get(info.id).build(origin)
			local spawns = model:FindFirstChild("Spawns")
			t.ok(spawns ~= nil, `{info.id} Spawns`)
			local n = 0
			for _, s in spawns:GetChildren() do
				if s:IsA("BasePart") then
					n += 1
				end
			end
			t.eq(n, Rules.capacityOf(info), `{info.id} spawn count`)
		end
	end)
end
