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

-- 라운드별 맵 종류 (GDD 5.1)
-- 첫 라운드는 Race, 마지막은 Final, 가운데는 Race/Survival을 섞고 4라운드면 Survival이 최소 1번.
function Rules.roundKinds(roundCount: number, rng: Rng): { MapKind }
	assert(roundCount >= 2, "need at least 2 rounds")
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

-- 라운드별 맵 결정. 한 판 안에서 같은 맵은 안 나와요.
-- 개발 초기처럼 맵 풀이 모자라면 같은 종류에서 중복을 허용하고, 그 종류가 아예 없으면 아무 맵이나 써요.
function Rules.buildRoundPlan(roundCount: number, pool: { MapInfo }, rng: Rng): { MapInfo }
	assert(#pool > 0, "map pool is empty")
	local used: { [string]: boolean } = {}
	local plan = {}
	for i, kind in Rules.roundKinds(roundCount, rng) do
		local map = pick(rng, pool, kind, used) or pick(rng, pool, kind, {}) or pick(rng, pool, nil, used)
		map = map or pick(rng, pool, nil, {})
		local chosen = map :: MapInfo
		used[chosen.id] = true
		plan[i] = chosen
	end
	return plan
end

return Rules
