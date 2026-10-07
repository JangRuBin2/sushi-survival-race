--!strict
-- 한 판의 규칙 계산 (GDD 3.3, 4.1, 5.1)
-- Roblox API에 의존하지 않는 순수 함수만 둬요. tests/rules.spec.luau에서 Lune으로 돌려요.

local Config = require(script.Parent.Config)

local Rules = {}

export type MapKind = "Race" | "Survival" | "Final"

-- 라운드 구성에 필요한 맵 정보 (맵 모듈 전체가 아니라 id와 종류만)
export type MapInfo = {
	id: string,
	kind: MapKind,
}

-- Random과 같은 모양. 테스트에서는 시드를 고정한 가짜 rng를 넘겨요.
export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
}

-- 시작 인원으로 라운드 수 결정 (4~8명: 3라운드, 9~24명: 4라운드)
function Rules.roundCount(startCount: number): number
	if startCount >= Config.Rules.FourRoundMinPlayers then
		return 4
	end
	return 3
end

-- roundIndex(1부터) 라운드의 통과 인원.
-- 통과 = clamp(round(남은 인원 × 비율), 2, 남은 인원 - 1). 마지막 라운드(결승)는 항상 1명.
function Rules.qualifyCount(aliveCount: number, roundCount: number, roundIndex: number): number
	if roundIndex >= roundCount then
		return 1
	end
	local ratios = Config.Rules.PassRatios[roundCount]
	assert(ratios and ratios[roundIndex], `no pass ratio for round {roundIndex} of {roundCount}`)
	local minimum = Config.Rules.MinQualifiers
	local target = math.round(aliveCount * ratios[roundIndex])
	return math.clamp(target, minimum, math.max(aliveCount - 1, minimum))
end

-- 결승 전에 남은 인원이 2명 이하면 남은 라운드를 건너뛰고 바로 결승으로 가요.
function Rules.shouldSkipToFinal(aliveCount: number): boolean
	return aliveCount <= Config.Rules.SkipToFinalAt
end

-- 방금 끝난 라운드 다음에 할 라운드 번호. 건너뛰기가 적용되면 결승 번호가 나와요.
-- 결승이 끝났으면 nil.
function Rules.nextRound(finishedIndex: number, roundCount: number, aliveCount: number): number?
	if finishedIndex >= roundCount then
		return nil
	end
	if Rules.shouldSkipToFinal(aliveCount) then
		return roundCount
	end
	return finishedIndex + 1
end

-- 이번에 실제로 돌릴 라운드 번호. 계획한 라운드가 결승 전인데 남은 인원이 2명 이하가 됐으면
-- (예: 라운드 소개 중에 누가 나감) 결승 번호를 돌려줘요. nextRound는 결과 단계 뒤에만 불리니까
-- 소개 직전·직후에 이걸로 한 번 더 확인해요 (GDD 4.1).
function Rules.roundToPlay(plannedIndex: number, roundCount: number, aliveCount: number): number
	if plannedIndex < roundCount and Rules.shouldSkipToFinal(aliveCount) then
		return roundCount
	end
	return plannedIndex
end

-- 이번 라운드에서 eliminatedCount번째로 탈락한 사람의 매치 등수.
-- 먼저 탈락할수록 나쁜(큰) 등수예요: 8명 중 첫 탈락 → 8등.
function Rules.eliminationPlace(totalRacers: number, eliminatedCount: number): number
	return totalRacers - eliminatedCount + 1
end

-- 라운드가 끝날 때 아직 결판이 안 난 사람들을 정리하는 순서.
-- progress가 클수록(멀리 갈수록) 앞이에요. 앞에서 openSlots명은 통과(잘 간 순),
-- 나머지는 탈락인데 **못 간 사람부터** 돌려줘요. 그 순서대로 eliminationPlace를 매기면
-- 탈락자 중 가장 멀리 간 사람이 가장 좋은 등수를 받아요. 진행도가 같으면 entries 순서를 따라요.
function Rules.settleLeftover<T>(entries: { T }, progressOf: (T) -> number, openSlots: number): ({ T }, { T })
	local ranked = {}
	for i, entry in entries do
		table.insert(ranked, { entry = entry, progress = progressOf(entry), index = i })
	end
	table.sort(ranked, function(a, b)
		if a.progress ~= b.progress then
			return a.progress > b.progress
		end
		return a.index < b.index
	end)

	local slots = math.max(openSlots, 0)
	local qualify: { T } = {}
	local eliminate: { T } = {}
	for i, item in ranked do
		if i <= slots then
			table.insert(qualify, item.entry)
		end
	end
	for i = #ranked, slots + 1, -1 do
		table.insert(eliminate, ranked[i].entry)
	end
	return qualify, eliminate
end

local function pick(rng: Rng, pool: { MapInfo }, kind: MapKind?, used: { [string]: boolean }): MapInfo?
	local candidates = {}
	for _, map in pool do
		if (kind == nil or map.kind == kind) and not used[map.id] then
			table.insert(candidates, map)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- 종류별 맵 개수 (buildRoundPlan이 풀에서 세어 roundKinds에 넘겨요)
export type KindCounts = { [MapKind]: number }

-- 맵 개수를 보지 않는 구성: 가운데는 반반 확률, 4라운드면 Survival을 최소 1번 넣어요.
-- 맵 풀이 GDD 구성을 채울 만큼 없을 때(개발 초기 fallback) 써요.
local function unboundedKinds(roundCount: number, rng: Rng): { MapKind }
	local kinds: { MapKind } = table.create(roundCount, "Race" :: MapKind)
	kinds[roundCount] = "Final"

	local hasSurvival = false
	for i = 2, roundCount - 1 do
		if rng:NextInteger(0, 1) == 1 then
			kinds[i] = "Survival"
			hasSurvival = true
		end
	end
	if roundCount >= 4 and not hasSurvival then
		kinds[rng:NextInteger(2, roundCount - 1)] = "Survival"
	end
	return kinds
end

-- 라운드별 맵 종류 (GDD 5.1)
-- 첫 라운드는 Race, 마지막은 Final, 가운데는 Race/Survival을 섞고 4라운드면 Survival이 최소 1번.
-- counts(종류별 맵 개수)를 주면 종류마다 맵 개수를 넘지 않게 골라서, 풀이 충분하면 같은 맵이
-- 두 번 나올 일이 없게 해요. 개수가 모자라 그렇게 못 하면 개수를 보지 않고 골라요.
function Rules.roundKinds(roundCount: number, rng: Rng, counts: KindCounts?): { MapKind }
	assert(roundCount >= 2, "need at least 2 rounds")
	if counts == nil then
		return unboundedKinds(roundCount, rng)
	end

	local middle = roundCount - 2
	local needSurvival = roundCount >= 4
	-- 가운데 라운드에 쓸 수 있는 남은 개수 (첫 라운드가 Race 하나를 써요)
	local cap: { [MapKind]: number } = {
		Race = math.max((counts.Race or 0) - 1, 0),
		Survival = counts.Survival or 0,
	}
	if cap.Race + cap.Survival < middle or (needSurvival and cap.Survival < 1) then
		return unboundedKinds(roundCount, rng)
	end

	local kinds: { MapKind } = table.create(roundCount, "Race" :: MapKind)
	kinds[roundCount] = "Final"
	local open: { number } = {}
	for i = 2, roundCount - 1 do
		table.insert(open, i)
	end
	if needSurvival then
		local slot = table.remove(open, rng:NextInteger(1, #open)) :: number
		kinds[slot] = "Survival"
		cap.Survival -= 1
	end
	-- 남은 칸은 자리가 남은 종류 중에서 고르게 골라요. 총 개수가 칸 수 이상이라 막히지 않아요.
	for _, slot in open do
		local choices: { MapKind } = {}
		for _, kind in { "Race", "Survival" } :: { MapKind } do
			if cap[kind] > 0 then
				table.insert(choices, kind)
			end
		end
		local kind = choices[rng:NextInteger(1, #choices)]
		kinds[slot] = kind
		cap[kind] -= 1
	end
	return kinds
end

-- 라운드별 맵 결정. 한 판 안에서 같은 맵은 안 나와요.
-- 개발 초기처럼 맵 풀이 모자라면 같은 종류에서 중복을 허용하고, 그 종류가 아예 없으면 아무 맵이나 써요.
function Rules.buildRoundPlan(roundCount: number, pool: { MapInfo }, rng: Rng): { MapInfo }
	assert(#pool > 0, "map pool is empty")
	local counts: KindCounts = {}
	for _, map in pool do
		counts[map.kind] = (counts[map.kind] or 0) + 1
	end
	local used: { [string]: boolean } = {}
	local plan = {}
	for i, kind in Rules.roundKinds(roundCount, rng, counts) do
		local map = pick(rng, pool, kind, used) or pick(rng, pool, kind, {}) or pick(rng, pool, nil, used)
		map = map or pick(rng, pool, nil, {})
		local chosen = map :: MapInfo
		used[chosen.id] = true
		plan[i] = chosen
	end
	return plan
end

-- 디버그 강제 플랜(Config.DEBUG.forceMapPlan) 검사. 맵 id 목록을 그 순서의 MapInfo로 바꿔요.
-- 길이는 3이나 4(라운드 수)여야 하고 모든 id가 풀에 있어야 해요. 종류 순서는 검사하지 않아요
-- (예: Survival을 1라운드로 두고 테스트할 수 있게). 문제가 있으면 nil과 이유를 돌려줘요.
function Rules.resolveForcedPlan(ids: any, pool: { MapInfo }): ({ MapInfo }?, string?)
	if type(ids) ~= "table" then
		return nil, "forceMapPlan must be a list of map ids"
	end
	local count = #ids
	if count ~= 3 and count ~= 4 then
		return nil, `forceMapPlan must have 3 or 4 map ids (got {count})`
	end
	local byId: { [string]: MapInfo } = {}
	for _, map in pool do
		byId[map.id] = map
	end
	local plan: { MapInfo } = {}
	for i = 1, count do
		local id = ids[i]
		local map = if type(id) == "string" then byId[id] else nil
		if map == nil then
			return nil, `forceMapPlan has an unknown map id: {tostring(id)}`
		end
		table.insert(plan, map)
	end
	return plan, nil
end

return Rules
