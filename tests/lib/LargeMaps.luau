--!strict
-- 대형 맵(m6-02~07, capacity 40) 구분 — 맵 개수·목록을 고정하던 예전 공용 테스트가 "기존 맵 21개"만 세게 해요.
-- 대형 맵은 각자 map-<id>.spec과 m6-02-large-foundation이 확인해요. 대형 맵이 하나씩 들어와도 예전 테스트를 다시
-- 고칠 일이 없게 capacity로 가려요(id 목록을 두지 않아요).
--   LargeMaps.isLarge(info) -> boolean          capacity가 있는 맵 (Config.Maps.LargeCapacity)
--   LargeMaps.standard(infos) -> { MapInfo }    대형 맵을 뺀 목록 (예전 21개)

local LargeMaps = {}

function LargeMaps.isLarge(info: any): boolean
	return info.capacity ~= nil
end

function LargeMaps.standard(infos: { any }): { any }
	local out = {}
	for _, info in infos do
		if not LargeMaps.isLarge(info) then
			table.insert(out, info)
		end
	end
	return out
end

return LargeMaps
