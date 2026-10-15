--!strict
-- 맵 3차 배치(m5-33~39) id 목록 — 이 한 곳에만 둬요.
-- 랜덤 풀 개수·목록을 고정하던 공용 테스트가 "기존 15개 + 배치 3 중 풀에 든 것"으로 계산하게 해서,
-- 맵 스펙(m5-34~39)이 자기 모듈의 `inPool = false` 줄을 지워도 공용 테스트를 다시 고칠 일이 없게 해요 (m5-33 D3).
--   Batch3.IDS / Batch3.KIND           배치 3 id와 종류
--   Batch3.BASE_POOL_COUNT             배치 3 전에 랜덤 풀에 있던 맵 수 (15)
--   Batch3.isBatch3(id) -> boolean
--   Batch3.pooledIds(get) -> { string }       배치 3 중 inPool ~= false인 id (IDS 순서)
--   Batch3.pooledOfKind(get, kind) -> { string }
--   Batch3.expectedPoolCount(get) -> number   15 + 풀에 든 배치 3 수
--   Batch3.POOL_COUNT / Batch3.POOL_BY_KIND   배치 3 졸업 뒤 고정 기대값 (21 · Race 8 · Survival 7 · Final 6)
-- 6개 모두 main에 병합(졸업)된 뒤로 실제 풀 검사는 pooledIds(Maps.get)가 아니라 이 고정값을 써요 (m5-33 QA P3-1) —
-- 배치 3 맵이 실수로 다시 inPool = false가 되면 테스트가 실패해요. pooledIds 등은 AC7 가짜 목록 검사용으로만 남겨요.
-- get은 Maps.get처럼 id → 맵 모듈(inPool 필드)을 돌려주는 함수예요 (AC7 테스트는 가짜 get을 넘겨요).

local Batch3 = {}

Batch3.IDS = {
	"dish-sink", -- m5-34
	"space-conveyor", -- m5-35
	"rice-cooker", -- m5-36
	"fish-market", -- m5-37
	"tea-garden", -- m5-38
	"onsen-claw", -- m5-39
}

Batch3.KIND = {
	["dish-sink"] = "Race",
	["space-conveyor"] = "Race",
	["rice-cooker"] = "Survival",
	["fish-market"] = "Survival",
	["tea-garden"] = "Final",
	["onsen-claw"] = "Final",
} :: { [string]: string }

Batch3.BASE_POOL_COUNT = 15

-- 배치 3 졸업 뒤 랜덤 풀 고정값 (m5-33 QA P3-1)
Batch3.POOL_COUNT = 21
Batch3.POOL_BY_KIND = { Race = 8, Survival = 7, Final = 6 } :: { [string]: number }

-- 배치 3 중 kind 종류 id (inPool과 무관, IDS 순서)
function Batch3.idsOfKind(kind: string): { string }
	local out = {}
	for _, id in Batch3.IDS do
		if Batch3.KIND[id] == kind then
			table.insert(out, id)
		end
	end
	return out
end

local set: { [string]: boolean } = {}
for _, id in Batch3.IDS do
	set[id] = true
end

export type Getter = (id: string) -> any

function Batch3.isBatch3(id: string): boolean
	return set[id] == true
end

function Batch3.pooledIds(get: Getter): { string }
	local out = {}
	for _, id in Batch3.IDS do
		if get(id).inPool ~= false then
			table.insert(out, id)
		end
	end
	return out
end

function Batch3.pooledOfKind(get: Getter, kind: string): { string }
	local out = {}
	for _, id in Batch3.pooledIds(get) do
		if Batch3.KIND[id] == kind then
			table.insert(out, id)
		end
	end
	return out
end

function Batch3.expectedPoolCount(get: Getter): number
	return Batch3.BASE_POOL_COUNT + #Batch3.pooledIds(get)
end

return Batch3
