--!strict
-- 시즌 이벤트 카탈로그 (m5-03, GDD 9.2 시즌 한정). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/seasons.spec.luau).
-- 기간은 UTC unix 초, [startsAt, endsAt). "지금 시각"은 서버 os.time() — Studio에서는 Config.DEBUG.eventNow가 우선
-- (그 선택은 서버 코드가 해요. 여기 함수는 now를 인자로 받아요). 날짜를 바꾸려면 아래 LIST의 숫자만 고쳐요.
--   Seasons.get(id) -> Event?
--   Seasons.current(now) -> Event?          now에 진행 중인 이벤트 (겹치면 startsAt이 늦은 것)
--   Seasons.isActive(id, now) -> boolean
--   Seasons.skinOnSale(skin, now) -> boolean  season 없는 스킨은 true, 있으면 그 이벤트가 진행 중일 때만
--   Seasons.daysLeft(id, now) -> number?      끝까지 남은 날(올림), 진행 중일 때만
--   Seasons.now(isStudio, debugNow, osTime) -> number  서버가 쓸 "지금 시각" (Studio면 Config.DEBUG.eventNow 우선)
--   Seasons.validate(list) -> (ok, problems)

export type Token = { name: string, icon: string }
export type Event = {
	id: string,
	name: string,
	startsAt: number, -- UTC unix 초 (포함)
	endsAt: number, -- UTC unix 초 (제외)
	token: Token, -- 이벤트 재화
}

local SECONDS_PER_DAY = 86400

local Seasons = {}

Seasons.LIST = {
	{
		id = "halloween-2026",
		name = "할로윈 초밥 축제",
		startsAt = 1792108800, -- 2026-10-16 00:00 UTC
		endsAt = 1793923200, -- 2026-11-06 00:00 UTC
		token = { name = "사탕", icon = "🍬" },
	},
	{
		id = "christmas-2026",
		name = "크리스마스 초밥 축제",
		startsAt = 1796947200, -- 2026-12-11 00:00 UTC
		endsAt = 1799366400, -- 2027-01-08 00:00 UTC
		token = { name = "별", icon = "⭐" },
	},
} :: { Event }

function Seasons.get(id: string): Event?
	for _, event in Seasons.LIST do
		if event.id == id then
			return event
		end
	end
	return nil
end

-- 서버가 쓸 "지금 시각": Studio이고 debugNow(Config.DEBUG.eventNow)가 숫자면 그 값, 아니면 os.time()
function Seasons.now(isStudio: boolean, debugNow: number?, osTime: number): number
	if isStudio and type(debugNow) == "number" then
		return debugNow
	end
	return osTime
end

local function running(event: Event, now: number): boolean
	return now >= event.startsAt and now < event.endsAt
end

function Seasons.current(now: number): Event?
	local found: Event? = nil
	for _, event in Seasons.LIST do
		if running(event, now) and (found == nil or event.startsAt > found.startsAt) then
			found = event
		end
	end
	return found
end

function Seasons.isActive(id: string, now: number): boolean
	local event = Seasons.get(id)
	return event ~= nil and running(event, now)
end

-- skin은 Skins.Skin (순환 require를 피하려고 season 칸만 봐요)
function Seasons.skinOnSale(skin: { season: string? }, now: number): boolean
	if skin.season == nil then
		return true
	end
	return Seasons.isActive(skin.season, now)
end

function Seasons.daysLeft(id: string, now: number): number?
	local event = Seasons.get(id)
	if event == nil or not running(event, now) then
		return nil
	end
	return math.ceil((event.endsAt - now) / SECONDS_PER_DAY)
end

local function nonEmpty(value: any): boolean
	return type(value) == "string" and value ~= ""
end

function Seasons.validate(list: { any }): (boolean, { string })
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}
	for index, event in list do
		if type(event) ~= "table" then
			table.insert(problems, `#{index}: not a table`)
			continue
		end
		local id = event.id
		if not nonEmpty(id) then
			table.insert(problems, `#{index}: id must be a non-empty string`)
			continue
		end
		if seen[id] then
			table.insert(problems, `{id}: duplicate id`)
		end
		seen[id] = true
		if not nonEmpty(event.name) then
			table.insert(problems, `{id}: name must be a non-empty string`)
		end
		if type(event.startsAt) ~= "number" or type(event.endsAt) ~= "number" or event.startsAt >= event.endsAt then
			table.insert(problems, `{id}: startsAt must be a number before endsAt`)
		end
		local token = event.token
		if type(token) ~= "table" or not nonEmpty(token.name) or not nonEmpty(token.icon) then
			table.insert(problems, `{id}: token needs a name and an icon`)
		end
	end
	return #problems == 0, problems
end

return Seasons
