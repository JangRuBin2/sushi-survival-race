--!strict
-- Shared.maps: 맵 모듈 공통 인터페이스 검사와 맵 풀, Config 값의 일관성

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local RotatingBelt = RobloxRequire.require(Shared.maps.RotatingBelt)
local Rules = RobloxRequire.require(Shared.Rules)

local function validMap(): { [string]: any }
	return {
		id = "TestMap",
		kind = "Race",
		displayName = "테스트 맵",
		rule = "결승선까지 달려요",
		build = function() end,
		start = function() end,
	}
end

return function(t: Test.Test)
	t.test("MapTypes.validate: 올바른 맵은 통과", function()
		t.eq(MapTypes.validate(validMap()), nil)
		local withOptional = validMap()
		withOptional.timeLimit = 45
		withOptional.cleanup = function() end
		t.eq(MapTypes.validate(withOptional), nil)
	end)

	t.test("MapTypes.validate: 빠지거나 잘못된 필드를 잡아요", function()
		t.ok(MapTypes.validate(nil))
		local cases: { { any } } = {
			{ "id", "" },
			{ "kind", "Team" },
			{ "displayName", nil },
			{ "rule", 3 },
			{ "timeLimit", 0 },
			{ "build", nil },
			{ "start", "go" },
			{ "cleanup", true },
		}
		for _, case in cases do
			local map = validMap()
			map[case[1]] = case[2]
			t.ok(MapTypes.validate(map), `{case[1]} = {case[2]} should be rejected`)
		end
	end)

	t.test("맵 풀: 모든 맵이 인터페이스를 지키고 id가 겹치지 않아요", function()
		local seen = {}
		for _, info in Maps.infos() do
			local map = Maps.get(info.id)
			t.eq(MapTypes.validate(map), nil)
			t.ok(not seen[info.id], `duplicate {info.id}`)
			seen[info.id] = true
		end
	end)

	t.test("m5-01 AC7: Final 맵은 overtime 함수가 있어야 해요", function()
		local final = validMap()
		final.kind = "Final"
		local problem = MapTypes.validate(final)
		t.eq(problem, "TestMap: Final maps must have an overtime function")
		final.overtime = function() end
		t.eq(MapTypes.validate(final), nil)
		final.overtime = "later"
		t.ok(MapTypes.validate(final), "non-function overtime on a Final map")
		-- 다른 종류는 선택이지만, 있으면 함수여야 해요
		local race = validMap()
		race.overtime = function() end
		t.eq(MapTypes.validate(race), nil)
		race.overtime = 5
		t.eq(MapTypes.validate(race), "TestMap: overtime must be a function")
	end)

	t.test(
		"m5-01 AC7 (+ m5-17): 맵 풀이 모두 validate를 통과해요 (기존 6개 + cat-cafe-shelves)",
		function()
			local count = 0
			for _, info in Maps.infos() do
				t.eq(MapTypes.validate(Maps.get(info.id)), nil, info.id)
				count += 1
			end
			t.eq(count, 7)
		end
	)

	t.test("RotatingBelt: MapModule 인터페이스를 지키고 Race 맵이에요", function()
		t.eq(MapTypes.validate(RotatingBelt), nil)
		t.eq(RotatingBelt.kind, "Race")
		t.ok(RotatingBelt.id ~= "", "id should not be empty")
		t.ok(#RotatingBelt.rule > 0, "rule should describe the round")
		-- build/start는 Roblox API(Instance, game 등)를 써서 Lune에서 직접 호출할 수 없어요.
		-- 여기서는 맵 모듈의 "모양"만 검사하고, 실제 생성/동작은 Studio에서 확인해요 (docs/DEV-SETUP.md).
	end)

	t.test("Maps.timeLimit: 맵 값이 없으면 종류별 기본값", function()
		local map = validMap()
		t.eq(Maps.timeLimit(map :: any), Config.TimeLimit.Race)
		map.timeLimit = 30
		t.eq(Maps.timeLimit(map :: any), 30)
	end)

	t.test("Config: 방 인원 선택지와 통과 비율이 규칙과 맞아요", function()
		t.ok(table.find(Config.Room.MaxPlayerOptions, Config.Room.DefaultMaxPlayers), "default not in options")
		for _, option in Config.Room.MaxPlayerOptions do
			t.ok(option >= Config.Room.MinPlayersToStart and option <= 24, `option {option}`)
		end
		for roundCount, ratios in Config.Rules.PassRatios do
			t.eq(#ratios, roundCount - 1, `ratios for {roundCount} rounds`)
		end
	end)
	t.test("m2-01 AC6: 맵 풀에 Race 2개 이상, Survival·Final 1개 이상", function()
		local counts = {}
		for _, info in Maps.infos() do
			counts[info.kind] = (counts[info.kind] or 0) + 1
		end
		t.ok((counts.Race or 0) >= 2, "need 2+ Race maps")
		t.ok((counts.Survival or 0) >= 1, "need 1+ Survival map")
		t.ok((counts.Final or 0) >= 1, "need 1+ Final map")
	end)

	t.test(
		"m2-01 AC6: 새 맵 3개가 확정된 id·종류·이름·규칙으로 인터페이스를 지켜요",
		function()
			local expected = {
				{
					id = "soy-swamp",
					kind = "Race",
					displayName = "간장 늪 & 와사비 산",
					rule = "간장 웅덩이는 피하고, 와사비 패드로 튀어 올라 결승선까지!",
				},
				{
					id = "hot-plate",
					kind = "Survival",
					displayName = "뜨거운 철판",
					rule = "밟은 철판은 곧 사라져요. 계속 움직여서 끝까지 버티세요!",
				},
				{
					id = "skewer-showdown",
					kind = "Final",
					displayName = "회전 꼬치 쇼다운",
					rule = "돌아오는 꼬치를 뛰어넘고 끝까지 버티세요! 마지막 1명만 탈출해요",
				},
			}
			for _, want in expected do
				local map = Maps.get(want.id)
				t.eq(MapTypes.validate(map), nil, want.id)
				t.eq(map.kind, want.kind, `{want.id} kind`)
				t.eq(map.displayName, want.displayName, `{want.id} displayName`)
				t.eq(map.rule, want.rule, `{want.id} rule`)
			end
		end
	)

	t.test("m5-13 AC3: 신규 맵 6개 전부 Maps.get으로 조회돼요(에러 없이 MapModule)", function()
		for _, id in
			{
				"bouncy-castle-maze",
				"lantern-bridge",
				"giant-jenga",
				"cat-cafe-shelves",
				"tug-of-war-platform",
				"claw-machine-prize",
			}
		do
			local map = Maps.get(id)
			t.eq(map.id, id)
			t.eq(MapTypes.validate(map), nil, id)
		end
	end)

	t.test(
		"m5-13 AC4: resolveForcedPlan이 신규 맵도 그 순서대로 라운드 플랜으로 돌려줘요",
		function()
			local plan, problem =
				Rules.resolveForcedPlan({ "lantern-bridge", "giant-jenga", "claw-machine-prize" }, Maps.allInfos())
			t.eq(problem, nil)
			t.eq(plan, {
				{ id = "lantern-bridge", kind = "Race" },
				{ id = "giant-jenga", kind = "Survival" },
				{ id = "claw-machine-prize", kind = "Final" },
			})
		end
	)

	t.test("m2-01 Config: forceMapPlan은 기본 nil, 점프 복구 값이 있어요", function()
		t.eq(Config.DEBUG.forceMapPlan, nil)
		t.eq(Config.Character.JumpPower, 50)
	end)
end
