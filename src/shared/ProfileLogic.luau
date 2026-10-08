--!strict
-- 프로필 저장 순수 로직 (m4-07). Roblox API를 쓰지 않아서 lune으로 테스트해요 (tests/profile-logic.spec.luau).
--   ProfileLogic.migrate(raw) -> (Profile, { persistable, notes })
--       DataStore에서 읽은 값을 지금 모양으로 정리해요. 없는 칸은 기본값, 잘못된 숫자는 0, tamago는 항상 보유,
--       보유하지 않은 장착 스킨은 tamago, 처리한 결제 id 목록은 정리(m4-14), 모르는 칸은 그대로 보존. version이 더 높으면(미래 데이터) persistable = false.
--       v2 칸(m5-03): redeemedCodes·eventTokens·boughtOffers는 문자열 키 → 0 이상 정수(내림), ownedFx는 true만,
--       equippedFx는 가진 연출이면서 FxCatalog에서 그 칸의 연출만. redeemedCodes는 시각이 큰 MAX_REDEEMED_CODES개만.
--       v1 → v2는 칸 추가뿐이에요 (기존 값 그대로, version = 2).
--   ProfileLogic.lockDecision(lock?, myJobId, now, expiry, mySession?) -> "take" | "wait" | "steal"
--   ProfileLogic.canWrite(lock?, myJobId, mySession?) -> boolean  내 잠금(같은 JobId + 같은 세션)일 때만 true
--   ProfileLogic.dayNumber(unixTime) -> number            UTC 날짜 번호 (1970-01-01 = 0)
--   ProfileLogic.claim(stored, myJobId, now, expiry, allowSteal) -> (Stored?, decision)
--   ProfileLogic.commit(stored, profile, myJobId, now, release) -> (Stored?, written)
--       DataService가 UpdateAsync 변환 함수 안에서 부르는 것. 돌려준 Stored가 nil이면 쓰지 않아요.
-- 저장 값 모양: { profile = Profile, lock = { jobId, at, session? }? } (키 u_<UserId>)

local Config = require(script.Parent.Config)
local FxCatalog = require(script.Parent.FxCatalog)
local ProfileSchema = require(script.Parent.ProfileSchema)
local ReceiptLogic = require(script.Parent.ReceiptLogic)

export type Profile = ProfileSchema.Profile
export type Lock = { jobId: string, at: number, session: string? }
export type Stored = { [string]: any }
export type MigrateInfo = { persistable: boolean, notes: { string } }
export type LockDecision = "take" | "wait" | "steal"

local ProfileLogic = {}

local SECONDS_PER_DAY = 86400

-- 이 칸들은 migrate가 직접 정리해요. 나머지 칸은 모르는 칸이라 그대로 남겨요.
local KNOWN_FIELDS = {
	version = true,
	coins = true,
	wins = true,
	matchesPlayed = true,
	lastDailyBonusDay = true,
	ownedSkins = true,
	equippedSkin = true,
	settings = true,
	receipts = true,
	redeemedCodes = true,
	eventTokens = true,
	ownedFx = true,
	equippedFx = true,
	boughtOffers = true,
}

local COUNTERS = { "coins", "wins", "matchesPlayed" }

local function isCount(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- 문자열 키 → 0 이상 유한 숫자(정수로 내림). 잘못된 항목은 버리고 notes에 한 줄 (m5-03)
local function countMap(value: unknown, field: string, notes: { string }): { [string]: number }
	local out: { [string]: number } = {}
	if value == nil then
		return out
	end
	if type(value) ~= "table" then
		table.insert(notes, `{field} was invalid, reset`)
		return out
	end
	local dropped = 0
	for key, amount in value :: { [any]: any } do
		if type(key) == "string" and isCount(amount) then
			out[key] = math.floor(amount)
		else
			dropped += 1
		end
	end
	if dropped > 0 then
		table.insert(notes, `{field}: dropped {dropped} invalid entries`)
	end
	return out
end

-- 시각이 큰 max개만 남겨요 (같은 시각이면 이름순으로 앞선 것)
local function keepNewest(
	map: { [string]: number },
	max: number,
	field: string,
	notes: { string }
): { [string]: number }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	if #keys <= max then
		return map
	end
	table.sort(keys, function(a, b)
		if map[a] ~= map[b] then
			return map[a] > map[b]
		end
		return a < b
	end)
	local out: { [string]: number } = {}
	for i = 1, max do
		out[keys[i]] = map[keys[i]]
	end
	table.insert(notes, `{field}: kept newest {max} of {#keys}`)
	return out
end

function ProfileLogic.migrate(raw: unknown): (Profile, MigrateInfo)
	local profile = ProfileSchema.new()
	local notes: { string } = {}
	local persistable = true

	if raw == nil then
		table.insert(notes, "new profile")
		return profile, { persistable = true, notes = notes }
	end
	if type(raw) ~= "table" then
		table.insert(notes, `profile was a {type(raw)}, reset to default`)
		return profile, { persistable = true, notes = notes }
	end
	local source = raw :: { [any]: any }
	local out = profile :: any

	-- 모르는 칸 보존 (나중 버전에서 생긴 칸을 지우지 않게)
	for key, value in source do
		if not KNOWN_FIELDS[key] then
			out[key] = value
		end
	end

	local version = source.version
	if isCount(version) and version > ProfileSchema.VERSION then
		persistable = false
		table.insert(notes, `future version {version} (this server knows {ProfileSchema.VERSION}), not saving`)
	end

	for _, field in COUNTERS do
		local value = source[field]
		if value == nil then
			continue
		end
		if isCount(value) then
			out[field] = math.floor(value)
		else
			table.insert(notes, `{field} was invalid ({tostring(value)}), set to 0`)
		end
	end

	local day = source.lastDailyBonusDay
	if isCount(day) then
		profile.lastDailyBonusDay = math.floor(day)
	elseif day ~= nil then
		table.insert(notes, "lastDailyBonusDay was invalid, cleared")
	end

	local default = Config.Appearance.Default
	local owned: { [string]: boolean } = { [default] = true }
	if type(source.ownedSkins) == "table" then
		for skinId, has in source.ownedSkins do
			if type(skinId) == "string" and has == true then
				owned[skinId] = true
			end
		end
	elseif source.ownedSkins ~= nil then
		table.insert(notes, "ownedSkins was invalid, reset")
	end
	profile.ownedSkins = owned

	local equipped = source.equippedSkin
	if type(equipped) == "string" and owned[equipped] then
		profile.equippedSkin = equipped
	elseif equipped ~= nil then
		table.insert(notes, `equippedSkin {tostring(equipped)} not owned, set to {default}`)
	end

	if source.settings ~= nil then
		local settings = ProfileSchema.sanitizeSettings(source.settings)
		if settings then
			profile.settings = settings
		else
			table.insert(notes, "settings were invalid, reset")
		end
	end

	if source.receipts ~= nil then
		profile.receipts = ReceiptLogic.sanitizeHistory(source.receipts, Config.Shop.ReceiptHistoryMax)
	end

	-- v2 칸 (m5-03). v1 프로필에는 없어서 빈 표가 돼요
	profile.redeemedCodes = keepNewest(
		countMap(source.redeemedCodes, "redeemedCodes", notes),
		ProfileSchema.MAX_REDEEMED_CODES,
		"redeemedCodes",
		notes
	)
	profile.eventTokens = countMap(source.eventTokens, "eventTokens", notes)
	profile.boughtOffers = countMap(source.boughtOffers, "boughtOffers", notes)

	local ownedFx: { [string]: boolean } = {}
	if type(source.ownedFx) == "table" then
		for fxId, has in source.ownedFx do
			if type(fxId) == "string" and has == true then
				ownedFx[fxId] = true
			else
				table.insert(notes, `ownedFx: dropped {tostring(fxId)}`)
			end
		end
	elseif source.ownedFx ~= nil then
		table.insert(notes, "ownedFx was invalid, reset")
	end
	profile.ownedFx = ownedFx

	local equippedFx: ProfileSchema.EquippedFx = {}
	if type(source.equippedFx) == "table" then
		for _, slot in FxCatalog.SLOTS do
			local fxId = source.equippedFx[slot]
			if fxId == nil then
				continue
			end
			local fx = if type(fxId) == "string" then FxCatalog.get(fxId) else nil
			if fx and fx.slot == slot and ownedFx[fx.id] then
				(equippedFx :: any)[slot] = fx.id
			else
				table.insert(notes, `equippedFx.{slot} {tostring(fxId)} not owned or wrong slot, cleared`)
			end
		end
	elseif source.equippedFx ~= nil then
		table.insert(notes, "equippedFx was invalid, reset")
	end
	profile.equippedFx = equippedFx

	return profile, { persistable = persistable, notes = notes }
end

-- 저장된 값에서 잠금을 꺼내요. 모양이 틀리면 잠금이 없는 것으로 봐요.
function ProfileLogic.readLock(stored: unknown): Lock?
	if type(stored) ~= "table" then
		return nil
	end
	local lock = (stored :: any).lock
	if type(lock) ~= "table" or type(lock.jobId) ~= "string" or type(lock.at) ~= "number" then
		return nil
	end
	return { jobId = lock.jobId, at = lock.at, session = if type(lock.session) == "string" then lock.session else nil }
end

-- 잠금 주인 = 서버(JobId) + 세션(접속마다 새 GUID). 세션이 없으면(nil) JobId만 비교하는 것과 같아요.
-- 같은 서버로 바로 다시 들어온 새 세션은 옛 세션의 잠금을 남의 것으로 봐요 (m4-07 QA D1).
local function owns(lock: Lock, myJobId: string, mySession: string?): boolean
	return lock.jobId == myJobId and lock.session == mySession
end

function ProfileLogic.lockDecision(
	lock: Lock?,
	myJobId: string,
	now: number,
	expiry: number,
	mySession: string?
): LockDecision
	if lock == nil or owns(lock, myJobId, mySession) then
		return "take"
	end
	if now - lock.at < expiry then
		return "wait"
	end
	return "steal"
end

function ProfileLogic.canWrite(lock: Lock?, myJobId: string, mySession: string?): boolean
	return lock ~= nil and owns(lock, myJobId, mySession)
end

function ProfileLogic.dayNumber(unixTime: number): number
	return math.floor(unixTime / SECONDS_PER_DAY)
end

local function cloneStored(stored: unknown): Stored
	if type(stored) == "table" then
		return table.clone(stored :: any)
	end
	return {}
end

-- 로드: 잠금을 건 새 저장 값과 결정을 돌려줘요. "wait"이고 allowSteal이 아니면 nil(쓰지 않음).
-- allowSteal이면 "wait"도 가져와요 (결정은 "steal"로 돌려줘요).
function ProfileLogic.claim(
	stored: unknown,
	myJobId: string,
	now: number,
	expiry: number,
	allowSteal: boolean,
	mySession: string?
): (Stored?, LockDecision)
	local decision = ProfileLogic.lockDecision(ProfileLogic.readLock(stored), myJobId, now, expiry, mySession)
	if decision == "wait" then
		if not allowSteal then
			return nil, "wait"
		end
		decision = "steal"
	end
	local new = cloneStored(stored)
	new.lock = { jobId = myJobId, at = now, session = mySession }
	return new, decision
end

-- 저장: 내 잠금일 때만 프로필을 써요. release면 잠금을 풀어요(나갈 때), 아니면 잠금 시간을 갱신해요.
function ProfileLogic.commit(
	stored: unknown,
	profile: Profile,
	myJobId: string,
	now: number,
	release: boolean,
	mySession: string?
): (Stored?, boolean)
	if not ProfileLogic.canWrite(ProfileLogic.readLock(stored), myJobId, mySession) then
		return nil, false
	end
	local new = cloneStored(stored)
	new.profile = profile
	new.lock = if release then nil else { jobId = myJobId, at = now, session = mySession }
	return new, true
end

-- 잠금만 풀어요 (저장하지 않는 프로필을 로드한 뒤). 내 잠금이 아니면 nil.
function ProfileLogic.release(stored: unknown, myJobId: string, mySession: string?): Stored?
	if not ProfileLogic.canWrite(ProfileLogic.readLock(stored), myJobId, mySession) then
		return nil
	end
	local new = cloneStored(stored)
	new.lock = nil
	return new
end

-- 저장할 사본 (저장 요청이 기다리는 동안 게임이 프로필을 바꿔도 섞이지 않게)
function ProfileLogic.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value :: any
	end
	local copy = {}
	for key, item in value :: any do
		copy[ProfileLogic.deepCopy(key)] = ProfileLogic.deepCopy(item)
	end
	return copy :: any
end

return ProfileLogic
