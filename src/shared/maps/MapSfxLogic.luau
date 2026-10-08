--!strict
-- 장애물 소리 간격 제한 순수 로직 (m3-09). Roblox API 없이 lune으로 테스트해요.
--   newLimiter()                          (파트 키, cue)별 마지막 재생 시각 기록
--   allow(limiter, key, cue, now, gap?)   gap(기본 MIN_INTERVAL)초 안에 같은 (key, cue)가 울렸으면 false
--   size(limiter)                         기록 개수 (오래된 항목은 PRUNE_EVERY초마다 지워져요)
--   marks(from, to, step)                 from부터 to까지 step 간격 시각 목록 (꼬치가 빨라지는 순간)
--   crossedMark(prev, now, marks)         (prev, now] 사이에 지나간 시각이 있나
-- 키는 무엇이든(파트 Instance, 테스트에서는 표·문자열) 돼요.

local Config = require(script.Parent.Parent.Config)

local MapSfxLogic = {}

-- 같은 파트·같은 cue가 다시 울리기까지 최소 간격(초)
MapSfxLogic.MIN_INTERVAL = Config.Fx.MapSfxMinInterval
-- 이 시간마다 오래된 기록을 지워요 (기록이 무한히 쌓이지 않게)
MapSfxLogic.PRUNE_EVERY = 1

-- 0.2초 같은 경계값이 부동소수점 오차로 어긋나지 않게
local EPSILON = 1e-6

export type Limiter = {
	last: { [any]: { [string]: number } },
	lastPrune: number,
	gap: number, -- 정리할 때 기준 간격 (가장 최근에 쓴 gap)
}

function MapSfxLogic.newLimiter(): Limiter
	return { last = {}, lastPrune = -math.huge, gap = MapSfxLogic.MIN_INTERVAL }
end

local function prune(limiter: Limiter, now: number)
	limiter.lastPrune = now
	for key, cues in limiter.last do
		for cue, at in cues do
			if now - at + EPSILON >= limiter.gap then
				cues[cue] = nil
			end
		end
		if next(cues) == nil then
			limiter.last[key] = nil
		end
	end
end

function MapSfxLogic.allow(limiter: Limiter, key: any, cue: string, now: number, gap: number?): boolean
	local interval = gap or MapSfxLogic.MIN_INTERVAL
	limiter.gap = math.max(limiter.gap, interval)
	if now - limiter.lastPrune >= MapSfxLogic.PRUNE_EVERY then
		prune(limiter, now)
	end
	local cues = limiter.last[key]
	local at = cues and cues[cue]
	if at ~= nil and now - at + EPSILON < interval then
		return false
	end
	if cues == nil then
		cues = {}
		limiter.last[key] = cues
	end
	(cues :: { [string]: number })[cue] = now
	return true
end

function MapSfxLogic.size(limiter: Limiter): number
	local n = 0
	for _, cues in limiter.last do
		for _ in cues do
			n += 1
		end
	end
	return n
end

function MapSfxLogic.marks(from: number, to: number, step: number): { number }
	local list = {}
	if step <= 0 then
		return list
	end
	local at = from
	while at <= to + EPSILON do
		table.insert(list, at)
		at += step
	end
	return list
end

function MapSfxLogic.crossedMark(prev: number, now: number, marks: { number }): boolean
	for _, mark in marks do
		if prev < mark and mark <= now then
			return true
		end
	end
	return false
end

return MapSfxLogic
