--!strict
-- "간장 늪 & 와사비 산" 길이·길 계산 (m5-40, Roblox API 없음 → lune 테스트).
--   SoySwampLogic.sections()              출발 → 결승 구간 순서 (z가 단조 감소)
--   SoySwampLogic.courseLength()          1번 줄 스폰 → 결승선 (studs)
--   SoySwampLogic.estimateClearTime()     빠른 사람 추정 (걷기 16 + Layout.SECTION_DELAY 합, 초)
--   SoySwampLogic.boxGap(a, b)            두 상자(x·z) 사이 수평 틈 (겹치면 0)
--   SoySwampLogic.stoneHops()             앞 둑 → 발판 → 건너편 둑, 이웃끼리 틈 목록 (김 징검다리 길 약속)

local Layout = require(script.Parent.SoySwampLayout)

type Box = Layout.Box
type Span = Layout.Span

export type Section = { name: string, span: Span }

local Logic = {}

function Logic.sections(): { Section }
	return {
		{ name = "START", span = Layout.START },
		{ name = "SWAMP", span = Layout.SWAMP },
		{ name = "APPROACH", span = Layout.APPROACH },
		{ name = "MOUNTAIN", span = Layout.MOUNTAIN },
		{ name = "SLOPE", span = Layout.SLOPE },
		{ name = "LANDING", span = Layout.LANDING },
		{ name = "RIVER", span = Layout.RIVER },
		{ name = "APPROACH2", span = Layout.APPROACH2 },
		{ name = "MOUNTAIN2", span = Layout.MOUNTAIN2 },
		{ name = "SLOPE2", span = Layout.SLOPE2 },
		{ name = "FINISH", span = Layout.FINISH },
	}
end

function Logic.courseLength(): number
	local frontRow = Layout.spawnPositions()[1].z
	return frontRow - Layout.finishLineZ()
end

function Logic.estimateClearTime(): number
	local delay = 0
	for _, value in Layout.SECTION_DELAY do
		delay += value
	end
	return Logic.courseLength() / Layout.WALK_SPEED + delay
end

local function edges(box: Box): (number, number, number, number)
	return box.x - box.width / 2, box.x + box.width / 2, box.z - box.depth / 2, box.z + box.depth / 2
end

function Logic.boxGap(a: Box, b: Box): number
	local aMinX, aMaxX, aMinZ, aMaxZ = edges(a)
	local bMinX, bMaxX, bMinZ, bMaxZ = edges(b)
	local dx = math.max(0, math.max(aMinX, bMinX) - math.min(aMaxX, bMaxX))
	local dz = math.max(0, math.max(aMinZ, bMinZ) - math.min(aMaxZ, bMaxZ))
	return math.sqrt(dx * dx + dz * dz)
end

-- 앞 둑(쉼터 끝) → 발판 1 … n → 건너편 둑(산 2 앞 평지). 둑은 폭 전체 상자로 봐요.
function Logic.stoneHops(): { number }
	local nearBank: Box = { x = 0, z = Layout.LANDING.back + 2, width = Layout.WIDTH, depth = 4 }
	local farBank: Box = { x = 0, z = Layout.APPROACH2.front - 2, width = Layout.WIDTH, depth = 4 }
	local chain: { Box } = { nearBank }
	for _, stone in Layout.STONES do
		table.insert(chain, stone)
	end
	table.insert(chain, farBank)
	local gaps = {}
	for i = 2, #chain do
		table.insert(gaps, Logic.boxGap(chain[i - 1], chain[i]))
	end
	return gaps
end

return Logic
