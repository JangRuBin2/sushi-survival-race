--!strict
-- 관전 대상 고르기 순수 로직 (m2-06). Roblox API를 쓰지 않아서 tests/에서 그대로 불러와요.
--   후보: 이번 라운드에서 아직 달리는 사람 우선, 없으면 매치 생존자. 나는 빼요.
--   순서: userId 오름차순으로 고정 (서버가 보내는 순서가 바뀌어도 ◀/▶ 순서가 흔들리지 않게).

local SpectateLogic = {}

local function filtered(ids: { number }?, me: number, isAvailable: ((userId: number) -> boolean)?): { number }
	local result = {}
	for _, id in ids or {} do
		if id ~= me and not table.find(result, id) and (isAvailable == nil or isAvailable(id)) then
			table.insert(result, id)
		end
	end
	table.sort(result)
	return result
end

-- 관전 후보 목록. isAvailable이 있으면 false인 사람(게임을 떠났거나 캐릭터가 없는 사람)은 빼요.
function SpectateLogic.candidates(
	racers: { number }?,
	alive: { number }?,
	me: number,
	isAvailable: ((userId: number) -> boolean)?
): { number }
	local fromRacers = filtered(racers, me, isAvailable)
	if #fromRacers > 0 then
		return fromRacers
	end
	return filtered(alive, me, isAvailable)
end

-- 다음(direction = 1) / 이전(direction = -1) 대상. 끝에서 처음으로 순환해요.
-- 지금 대상이 목록에 없으면 다음은 첫 번째, 이전은 마지막. 목록이 비면 nil.
function SpectateLogic.step(list: { number }, current: number?, direction: number): number?
	local count = #list
	if count == 0 then
		return nil
	end
	local index = if current ~= nil then table.find(list, current) else nil
	if index == nil then
		return if direction < 0 then list[count] else list[1]
	end
	local nextIndex = ((index - 1 + (if direction < 0 then -1 else 1)) % count) + 1
	return list[nextIndex]
end

-- 후보 목록이 old에서 new로 바뀌었을 때 볼 대상.
--   지금 대상이 아직 있으면 그대로, 사라졌으면 old에서 그 사람 다음 자리부터 new에 남은 첫 사람,
--   그런 사람이 없으면 new의 첫 번째, new가 비면 nil.
function SpectateLogic.reconcile(old: { number }, new: { number }, current: number?): number?
	if #new == 0 then
		return nil
	end
	if current == nil then
		return new[1]
	end
	if table.find(new, current) then
		return current
	end
	local index = table.find(old, current)
	if index then
		local count = #old
		for offset = 1, count - 1 do
			local candidate = old[((index - 1 + offset) % count) + 1]
			if table.find(new, candidate) then
				return candidate
			end
		end
	end
	return new[1]
end

return SpectateLogic
