--!strict
-- m5-33 맵 3차 배치 기반 (docs/specs/m5-33-map-batch-3-foundation.md): 새 맵 6개 껍데기 등록, 강제 플랜,
-- 랜덤 풀에서 inPool = false 제외, 스폰·결승선, 소리 cue 14개(무음)·파티클 프리셋 3개, 풀 개수 "목록 기준" 계산.
-- 맵 스펙(m5-34~39)이 껍데기를 덮어쓰고 inPool = false 줄을 지워도 이 파일은 그대로 통과하게 썼어요
-- (껍데기 구조 이름 Floor·Plate에 기대지 않고, 풀 기대값은 tests/lib/Batch3로 계산).

local Batch3 = require("./lib/Batch3")
local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapFxPresets = RobloxRequire.require(Shared.maps.MapFxPresets)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Rules = RobloxRequire.require(Shared.Rules)
local SfxCues = RobloxRequire.require(Shared.SfxCues)
local SfxLibrary = RobloxRequire.require(Shared.SfxLibrary)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

-- 스펙 "범위 1" 표 (GDD §5.3과 같음) — 확정값
local TABLE = {
	{
		id = "dish-sink",
		kind = "Race",
		displayName = "깨끗하게! 설거지통",
		rule = "빙글빙글 접시와 움직이는 수세미를 피해 깨끗한 접시까지 달려요!",
	},
	{
		id = "space-conveyor",
		kind = "Race",
		displayName = "우주 회전초밥",
		rule = "방향이 바뀌는 우주 레일을 타고, 떨어지는 운석을 피해 결승까지!",
	},
	{
		id = "rice-cooker",
		kind = "Survival",
		displayName = "초대형 밥솥",
		rule = "끓어오르는 밥알과 뜨거운 증기를 피해 밥 위에서 버텨요!",
	},
	{
		id = "fish-market",
		kind = "Survival",
		displayName = "수산시장",
		rule = "떨어지는 생선과 밀려오는 얼음을 피해 상자 위에서 버텨요!",
	},
	{
		id = "tea-garden",
		kind = "Final",
		displayName = "찻잎 정원",
		rule = "굴러오는 찻잔을 피해 단을 옮기고, 무너지는 차밭에서 끝까지 버텨요!",
	},
	{
		id = "onsen-claw",
		kind = "Final",
		displayName = "온천탕 인형뽑기",
		rule = "인형뽑기가 쿵! 퍼지는 충격파는 점프로 넘고, 차오르는 온천물을 피해요!",
	},
}

local CUES: { { name: string, volume: number } } = {
	{ name = "SpongeSquish", volume = 0.7 },
	{ name = "RailSwitch", volume = 0.6 },
	{ name = "MeteorWarn", volume = 0.6 },
	{ name = "MeteorImpact", volume = 0.8 },
	{ name = "RiceBubble", volume = 0.7 },
	{ name = "SteamWhistle", volume = 0.6 },
	{ name = "SteamBlast", volume = 0.8 },
	{ name = "MarketFishWarn", volume = 0.6 },
	{ name = "MarketFishSlam", volume = 0.8 },
	{ name = "IceBlockSlide", volume = 0.6 },
	{ name = "TeaCupRoll", volume = 0.6 },
	{ name = "TeaFieldCrumble", volume = 0.8 },
	{ name = "ClawSlam", volume = 0.9 },
	{ name = "OnsenRise", volume = 0.6 },
}

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

-- 스폰 아래 판정 바닥: Decor·Spawns·IntroCamera 밖의 충돌 파츠 중 윗면이 스폰 바로 아래(0~6)이고
-- 그 파츠의 XZ 범위 안이면 "판정 바닥 위". 껍데기 파츠 이름(Floor·Plate)에 기대지 않아요.
local function supported(model: any, position: any): boolean
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or not d.CanCollide then
			continue
		end
		local skip = false
		local parent = d.Parent
		while parent and parent ~= model do
			if parent.Name == "Decor" or parent.Name == "Spawns" or parent.Name == "IntroCamera" then
				skip = true
				break
			end
			parent = parent.Parent
		end
		if skip then
			continue
		end
		local localPos = d.CFrame:PointToObjectSpace(position)
		local half = d.Size / 2
		local above = localPos.Y - half.Y
		if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z and above >= -0.5 and above <= 6 then
			return true
		end
	end
	return false
end

return function(t: Test.Test)
	---------------------------------------------------------------- AC1
	t.test(
		"AC1: 새 6개가 validate 통과, id·kind·displayName·rule이 스펙 표 그대로, Final은 overtime 함수",
		function()
			t.eq(#TABLE, #Batch3.IDS)
			for i, row in TABLE do
				t.eq(Batch3.IDS[i], row.id, "tests/lib/Batch3 order")
				t.eq(Batch3.KIND[row.id], row.kind, `{row.id} Batch3.KIND`)
				local map = Maps.get(row.id)
				t.eq(MapTypes.validate(map), nil, `{row.id} validate`)
				t.eq(map.id, row.id)
				t.eq(map.kind, row.kind, `{row.id} kind`)
				t.eq(map.displayName, row.displayName, `{row.id} displayName`)
				t.eq(map.rule, row.rule, `{row.id} rule`)
				if row.kind == "Final" then
					t.eq(type(map.overtime), "function", `{row.id} overtime`)
				end
			end
		end
	)

	---------------------------------------------------------------- AC2
	t.test(
		"AC2: allInfos 21개, infos는 15 + 풀에 든 배치 3, 껍데기는 infos에 없음, get으로 모두 조회",
		function()
			t.eq(#Maps.allInfos(), 21)
			t.eq(#Maps.infos(), Batch3.expectedPoolCount(Maps.get))
			local seen: { [string]: boolean } = {}
			for _, info in Maps.allInfos() do
				t.ok(not seen[info.id], `duplicate {info.id}`)
				seen[info.id] = true
			end
			local pooled: { [string]: boolean } = {}
			for _, info in Maps.infos() do
				pooled[info.id] = true
			end
			for _, id in Batch3.IDS do
				t.ok(seen[id], `{id} in allInfos`)
				t.eq(Maps.get(id).id, id)
				if Maps.get(id).inPool == false then
					t.ok(not pooled[id], `{id} shell must not be in the random pool`)
				else
					t.ok(pooled[id], `{id} joined the pool`)
				end
			end
		end
	)

	---------------------------------------------------------------- AC3
	t.test("AC3: 강제 플랜 두 개가 그 순서대로 풀려요 (allInfos)", function()
		for _, ids in
			{
				{ "dish-sink", "rice-cooker", "tea-garden" },
				{ "space-conveyor", "fish-market", "onsen-claw" },
			}
		do
			local plan, problem = Rules.resolveForcedPlan(ids, Maps.allInfos())
			t.eq(problem, nil)
			local expected = {}
			for _, id in ids do
				table.insert(expected, { id = id, kind = Batch3.KIND[id] })
			end
			t.eq(plan, expected)
		end
	end)

	---------------------------------------------------------------- AC4
	t.test("AC4: buildRoundPlan 1,000번 — inPool = false인 배치 3 맵은 안 나와요", function()
		local hidden: { [string]: boolean } = {}
		for _, id in Batch3.IDS do
			if Maps.get(id).inPool == false then
				hidden[id] = true
			end
		end
		for seed = 1, 1000 do
			local roundCount = if seed % 2 == 0 then 3 else 4
			local plan = Rules.buildRoundPlan(roundCount, Maps.infos(), fakeRng(seed))
			t.eq(#plan, roundCount)
			for _, info in plan do
				t.ok(not hidden[info.id], `seed {seed}: picked {info.id}`)
			end
		end
	end)

	---------------------------------------------------------------- AC5
	t.test(
		"AC5: build가 Spawns 24개(판정 바닥 위, 서로 3 이상), Race는 FinishLine이 스폰보다 −Z",
		function()
			for _, id in Batch3.IDS do
				local map = RMaps.get(id)
				local origin = roblox.CFrame.new()
				local model = map.build(origin)
				local spawns = model:FindFirstChild("Spawns")
				t.ok(spawns ~= nil, `{id} Spawns`)
				local list = {}
				for _, s in spawns:GetChildren() do
					if s:IsA("BasePart") then
						table.insert(list, s)
					end
				end
				t.eq(#list, 24, `{id} spawn count`)
				local maxSpawnZ = -math.huge
				local minSpawnZ = math.huge
				for i, s in list do
					local p = s.CFrame.Position
					t.ok(supported(model, p), `{id} {s.Name} not over a judgment floor`)
					t.eq(s.CanCollide, false, `{id} {s.Name} CanCollide`)
					maxSpawnZ = math.max(maxSpawnZ, p.Z)
					minSpawnZ = math.min(minSpawnZ, p.Z)
					for j = i + 1, #list do
						local d = (p - list[j].CFrame.Position).Magnitude
						t.ok(d >= 3, `{id} {s.Name}/{list[j].Name} too close ({d})`)
					end
				end
				if Batch3.KIND[id] == "Race" then
					local finish = model:FindFirstChild("FinishLine", true)
					t.ok(finish ~= nil, `{id} FinishLine`)
					if finish then
						t.ok(finish.CFrame.Position.Z < minSpawnZ, `{id} FinishLine ahead (−Z) of spawns`)
					end
				end
			end
		end
	)

	---------------------------------------------------------------- AC6
	t.test(
		"AC6: cue 14개가 효과음 + SfxLibrary 무음 항목(볼륨 스펙대로), 파티클 프리셋 3개 검사 통과",
		function()
			t.eq(#CUES, 14)
			for _, cue in CUES do
				t.ok(SfxCues.isEffect(cue.name), `{cue.name} is an effect`)
				local entry = SfxLibrary.Entries[cue.name]
				t.ok(entry ~= nil, `{cue.name} in SfxLibrary`)
				if entry then
					t.eq(entry.id, nil, `{cue.name} silent until the user picks a sound`)
					t.eq(entry.volume, cue.volume, `{cue.name} volume`)
					t.eq(entry.group, "Sfx", `{cue.name} group`)
				end
			end
			-- m5-32 고등어 FishFlop·FishSplash와 이름이 겹치지 않아요 (수산시장은 MarketFish*)
			t.ok(SfxCues.isEffect("FishFlop") and SfxCues.isEffect("FishSplash"), "m5-32 cues kept")
			for _, name in { "SoapFoam", "Stardust", "TeaLeaves" } do
				local preset = MapFxPresets.PRESETS[name]
				t.ok(preset ~= nil, `preset {name}`)
				t.eq(MapFxPresets.validate(preset), nil, name)
				t.ok(table.find(MapFxPresets.NAMES, name) ~= nil, `{name} in NAMES`)
				-- DecorSpec에서 이름으로 쓸 수 있어요
				local spec = {
					name = "P",
					shape = "Block",
					size = { x = 1, y = 1, z = 1 },
					color = { r = 200, g = 200, b = 200 },
					material = "SmoothPlastic",
					offset = { x = 0, y = 0, z = 0 },
					particle = name,
				}
				t.eq(MapKitLogic.validate({ spec } :: any), nil, `{name} accepted by MapKitLogic`)
			end
		end
	)

	---------------------------------------------------------------- AC7
	t.test(
		"AC7: 풀 기대값 계산은 배치 3 하나가 풀에 들어가면 15 + 1이 돼요 (가짜 목록)",
		function()
			local function fakeGet(pooledIds: { string }): Batch3.Getter
				local inPool: { [string]: boolean } = {}
				for _, id in pooledIds do
					inPool[id] = true
				end
				return function(id: string): any
					return { id = id, inPool = if inPool[id] then nil else false }
				end
			end
			t.eq(Batch3.expectedPoolCount(fakeGet({})), 15)
			t.eq(Batch3.expectedPoolCount(fakeGet({ "rice-cooker" })), 16)
			t.eq(Batch3.pooledOfKind(fakeGet({ "rice-cooker" }), "Survival"), { "rice-cooker" })
			t.eq(Batch3.pooledOfKind(fakeGet({ "rice-cooker" }), "Final"), {})
			t.eq(Batch3.expectedPoolCount(fakeGet(Batch3.IDS)), 21)
			t.eq(Batch3.pooledOfKind(fakeGet(Batch3.IDS), "Final"), { "tea-garden", "onsen-claw" })
			-- 실제 계산과 실제 풀이 맞아요 (지금은 껍데기 6개 모두 inPool = false → 15)
			t.eq(#Maps.infos(), Batch3.expectedPoolCount(Maps.get))
			t.ok(Batch3.isBatch3("tea-garden") and not Batch3.isBatch3("rotating-belt"))
		end
	)
end
