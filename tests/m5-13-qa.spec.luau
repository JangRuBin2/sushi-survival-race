--!strict
-- m5-13 QA(docs/qa/m5-13-map-expansion-foundation.md): 신규 맵 6개 등록이 지금 main에서도 계약을 지키는지.
-- 껍데기는 m5-14~m5-19가 덮어썼으니, 껍데기 고유 모양이 아니라 "등록·id·이름·Final 연장전 훅·풀 규칙"만 봐요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Rules = RobloxRequire.require(Shared.Rules)

-- 스펙 m5-13 표(= GDD §5.3 v0.6 확정값)
local NEW_MAPS = {
	{
		id = "bouncy-castle-maze",
		kind = "Race",
		displayName = "방방 미로",
		rule = "말랑한 바닥 위를 튕기며 미로를 빠져나가요.",
	},
	{
		id = "lantern-bridge",
		kind = "Race",
		displayName = "등불 다리 건너기",
		rule = "흔들리는 다리와 종이 등불 사이를 건너요.",
	},
	-- giant-jenga의 rule은 m5-16에서 결정 기록 없이 바뀌었어요(m5-16 QA B3). 여기서는 id·kind·displayName만 봐요.
	{ id = "giant-jenga", kind = "Survival", displayName = "와르르 나무 블록", rule = nil :: string? },
	{
		id = "cat-cafe-shelves",
		kind = "Survival",
		displayName = "고양이 카페 캣타워",
		rule = nil :: string?, -- m5-17 QA 범위
	},
	{ id = "tug-of-war-platform", kind = "Final", displayName = "줄다리기 발판", rule = nil :: string? },
	{ id = "claw-machine-prize", kind = "Final", displayName = "인형뽑기 기계 속", rule = nil :: string? },
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

return function(t: Test.Test)
	t.test(
		"m5-13 QA: 신규 6개 id·kind·displayName이 스펙 표 그대로, validate 통과, Final은 overtime 함수",
		function()
			for _, expected in NEW_MAPS do
				local map = Maps.get(expected.id)
				t.eq(map.id, expected.id)
				t.eq(map.kind, expected.kind, `{expected.id} kind`)
				t.eq(map.displayName, expected.displayName, `{expected.id} displayName`)
				if expected.rule then
					t.eq(map.rule, expected.rule, `{expected.id} rule`)
				end
				t.eq(MapTypes.validate(map), nil, `{expected.id} validate`)
				if expected.kind == "Final" then
					t.eq(type(map.overtime), "function", `{expected.id} overtime`)
				end
			end
		end
	)

	t.test(
		"m5-13 QA: allInfos는 맵 모듈과 1:1(21개 — m5-33 배치 3 껍데기 6개 포함, 중복 없음), infos는 inPool ~= false인 것만",
		function()
			local seen: { [string]: boolean } = {}
			for _, info in Maps.allInfos() do
				t.ok(not seen[info.id], `duplicate {info.id}`)
				seen[info.id] = true
				t.eq(Maps.get(info.id).kind, info.kind, `{info.id} kind matches module`)
			end
			t.eq(#Maps.allInfos(), 21) -- m5-33: 기존 15 + 맵 3차 배치 6 (배치 3 동안 안 바뀜)
			local pooled: { [string]: boolean } = {}
			for _, info in Maps.infos() do
				pooled[info.id] = true
				t.ok(Maps.get(info.id).inPool ~= false, `{info.id} in pool must not be inPool=false`)
			end
			for _, info in Maps.allInfos() do
				if Maps.get(info.id).inPool == false then
					t.ok(not pooled[info.id], `{info.id} is inPool=false but in random pool`)
				else
					t.ok(pooled[info.id], `{info.id} should be in random pool`)
				end
			end
		end
	)

	t.test(
		"m5-13 QA: 신규 6개는 어떤 조합으로도 강제 플랜이 그 순서대로 돼요 (3·4라운드)",
		function()
			local ids = {}
			for _, m in NEW_MAPS do
				table.insert(ids, m.id)
			end
			for a = 1, #ids do
				for b = 1, #ids do
					for c = 1, #ids do
						local plan, err = Rules.resolveForcedPlan({ ids[a], ids[b], ids[c] }, Maps.allInfos())
						t.ok(plan ~= nil, `plan {ids[a]},{ids[b]},{ids[c]}: {err}`)
						local p = plan :: { any }
						t.eq(p[1].id, ids[a])
						t.eq(p[2].id, ids[b])
						t.eq(p[3].id, ids[c])
					end
				end
			end
			local plan4 = Rules.resolveForcedPlan(
				{ "bouncy-castle-maze", "giant-jenga", "lantern-bridge", "claw-machine-prize" },
				Maps.allInfos()
			)
			t.ok(plan4 ~= nil and #plan4 == 4, "4-round forced plan")
		end
	)

	t.test(
		"m5-13 QA: 랜덤 판(2,000번)은 첫 판 Race·마지막 Final·중복 없음, inPool=false 맵은 안 나와요",
		function()
			for seed = 1, 2000 do
				local roundCount = if seed % 2 == 0 then 4 else 3
				local plan = Rules.buildRoundPlan(roundCount, Maps.infos(), fakeRng(seed))
				t.eq(#plan, roundCount)
				t.eq(plan[1].kind, "Race", `seed {seed} first`)
				t.eq(plan[roundCount].kind, "Final", `seed {seed} last`)
				local used: { [string]: boolean } = {}
				for _, info in plan do
					t.ok(not used[info.id], `seed {seed} duplicate {info.id}`)
					used[info.id] = true
					t.ok(Maps.get(info.id).inPool ~= false, `seed {seed} picked shell {info.id}`)
				end
			end
		end
	)
end
