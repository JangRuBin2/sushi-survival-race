--!strict
-- Shared.maps: 맵 모듈 공통 인터페이스 검사와 맵 풀, Config 값의 일관성

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)

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
end
