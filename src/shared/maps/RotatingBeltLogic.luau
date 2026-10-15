--!strict
-- 회전 벨트 길이·길 계산 (m5-40, Roblox API 없음 → lune 테스트).
--   RotatingBeltLogic.courseLength()        1번 줄 스폰 → 결승선 (studs)
--   RotatingBeltLogic.estimateClearTime()   빠른 사람 추정 (초): 걷기 16 + 뒤로 미는 벨트(순 6) + 구간 지연
--   RotatingBeltLogic.slalomBlocked(x, z, r) 접시 탑 슬라롬에서 반지름 r인 몸이 (x, z)에 설 수 없는지
--   RotatingBeltLogic.slalomPath(step, r)   슬라롬 앞 끝 → 뒤 끝으로 가는 길이 있는지 (격자 BFS)

local Art = require(script.Parent.RotatingBeltArt)
local Layout = require(script.Parent.RotatingBeltLayout)

local Logic = {}

function Logic.courseLength(): number
	return Art.spawnPositions()[1].z - Art.FINISH_LINE_Z
end

-- 뒤로 미는 벨트 구간(이름이 Belt로 시작) 길이 합
function Logic.backwardBeltDepth(): number
	local total = 0
	for _, section in Art.SECTIONS do
		if section.name == "BeltA" or section.name == "BeltB" or section.name == "BeltC" then
			total += section.front - section.back
		end
	end
	return total
end

function Logic.estimateClearTime(): number
	local walk = Layout.WALK_SPEED
	local net = walk - Layout.BELT_PUSH_SPEED
	local beltDepth = Logic.backwardBeltDepth()
	local beltExtra = beltDepth / net - beltDepth / walk
	local delay = 0
	for _, value in Layout.SECTION_DELAY do
		delay += value
	end
	return Logic.courseLength() / walk + beltExtra + delay
end

function Logic.slalomBlocked(x: number, z: number, r: number): boolean
	local section, front = Layout.sectionByName("Slalom")
	assert(section, "Slalom section missing")
	if math.abs(x) > section.half - r then
		return true
	end
	for _, tower in Layout.TOWERS do
		local tz = front - tower.z
		local dx, dz = x - tower.x, z - tz
		if math.sqrt(dx * dx + dz * dz) < tower.d / 2 + r then
			return true
		end
	end
	return false
end

function Logic.slalomPath(step: number, r: number): boolean
	local section, front = Layout.sectionByName("Slalom")
	assert(section, "Slalom section missing")
	local back = front - section.depth
	local half = section.half
	local cols = math.floor(2 * half / step)
	local rows = math.floor((front - back) / step)
	local function pos(c: number, row: number): (number, number)
		return -half + c * step, front - row * step
	end
	local seen: { [number]: boolean } = {}
	local queue: { { number } } = {}
	for c = 0, cols do
		local x, z = pos(c, 0)
		if not Logic.slalomBlocked(x, z, r) then
			table.insert(queue, { c, 0 })
			seen[c * 100000] = true
		end
	end
	local head = 1
	while head <= #queue do
		local c, row = queue[head][1], queue[head][2]
		head += 1
		if row == rows then
			return true
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nc, nr = c + d[1], row + d[2]
			local key = nc * 100000 + nr
			if nc >= 0 and nc <= cols and nr >= 0 and nr <= rows and not seen[key] then
				local x, z = pos(nc, nr)
				if not Logic.slalomBlocked(x, z, r) then
					seen[key] = true
					table.insert(queue, { nc, nr })
				end
			end
		end
	end
	return false
end

-- 슬라롬을 곧게(x 하나로) 지나갈 수 없는지: 모든 x에서 막힌 줄이 하나 이상 있어요 (S자로 돌아야 해요)
function Logic.slalomHasNoStraightLane(step: number, r: number): boolean
	local section, front = Layout.sectionByName("Slalom")
	assert(section, "Slalom section missing")
	local back = front - section.depth
	local x = -section.half
	while x <= section.half do
		local clear = true
		local z = front
		while z >= back do
			if Logic.slalomBlocked(x, z, r) then
				clear = false
				break
			end
			z -= step
		end
		if clear then
			return false
		end
		x += step
	end
	return true
end

return Logic
