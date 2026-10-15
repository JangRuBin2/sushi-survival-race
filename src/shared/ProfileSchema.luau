--!strict
-- 플레이어 프로필 모양과 기본값 (GDD 9.4, 9.5, 8). 순수 로직이라 Roblox API를 쓰지 않아요.
--   ProfileSchema.new()                    새 프로필 (부를 때마다 새 표)
--   ProfileSchema.titleFor(wins)           승수로 정해지는 칭호 (Config.Titles), 0승이면 nil
--   ProfileSchema.titleWinsFor(wins)       그 칭호의 기준 승수 1/10/100 (서버가 Attributes.Title로 다는 값, m5-26)
--   ProfileSchema.toView(profile, persistent, extra?)  클라이언트에 보낼 ProfileView (ProfileUpdated).
--       extra = 저장하지 않는 화면용 값 { vip = boolean, unlockAll = boolean? } (m5-03, DataService.setViewExtra).
--       없으면 vip = false. unlockAll = Studio 전부 입기 (m5-31) → view.studioUnlockAll
-- 저장(m4-07)은 이 모양 그대로 DataStore에 넣어요. 필드를 바꾸면 VERSION을 올리고 m4-07의 마이그레이션에 추가해요.

local Config = require(script.Parent.Config)
local TouchLayoutLogic = require(script.Parent.TouchLayoutLogic)
local Types = require(script.Parent.Types)

export type Profile = {
	version: number,
	coins: number,
	wins: number,
	matchesPlayed: number,
	lastDailyBonusDay: number?, -- UTC 날짜 번호 (os.time() // 86400)
	ownedSkins: { [string]: boolean },
	equippedSkin: string,
	settings: Types.Settings,
	-- 처리한 로벅스 결제 id (m4-14, 최근 Config.Shop.ReceiptHistoryMax개만). 같은 결제를 두 번 지급하지 않게
	receipts: { { id: string, at: number } },
	-- v2 (m5-03)
	redeemedCodes: { [string]: number }, -- 정규화한 코드 → 쓴 시각(os.time), 최근 MAX_REDEEMED_CODES개 (m5-10)
	eventTokens: { [string]: number }, -- 이벤트 id(Shared.Seasons) → 모은 이벤트 재화 (m5-07)
	ownedFx: { [string]: boolean }, -- 가진 연출 id (Shared.FxCatalog, m5-08)
	equippedFx: EquippedFx, -- 입은 연출 (가진 것만, 칸이 맞는 것만)
	boughtOffers: { [string]: number }, -- 한 번만 사는 상품 id → 산 시각 (m5-08)
	-- v3 (m5-31)
	drawTickets: number, -- 🎫 우승자 뽑기 티켓 (0 ~ Config.Draw.MaxTickets)
}

export type EquippedFx = { Elimination: string?, Victory: string? }

-- 저장하지 않는 화면용 값 (m5-03). VIP는 게임 패스라 Roblox가 소유를 기억해요
-- unlockAll (m5-31): Studio 전부 입기가 켜졌는가 (서버 설정이라 사람마다 같아요, DataService가 채워요)
export type ViewExtra = { vip: boolean, unlockAll: boolean? }

local ProfileSchema = {}

-- v2 (m5-03): redeemedCodes, eventTokens, ownedFx, equippedFx, boughtOffers / v3 (m5-31): drawTickets
ProfileSchema.VERSION = 3
ProfileSchema.MAX_REDEEMED_CODES = 200 -- 기억하는 쓴 코드 수 (오래된 것부터 지워요)

function ProfileSchema.new(): Profile
	local default = Config.Appearance.Default
	return {
		version = ProfileSchema.VERSION,
		coins = 0,
		wins = 0,
		matchesPlayed = 0,
		lastDailyBonusDay = nil,
		ownedSkins = { [default] = true },
		equippedSkin = default,
		settings = { muteLevel = 1 },
		receipts = {},
		redeemedCodes = {},
		eventTokens = {},
		ownedFx = {},
		equippedFx = {},
		boughtOffers = {},
		drawTickets = 0,
	}
end

-- wins 이하인 칭호 중 가장 높은 칭호의 기준 승수 (1/10/100), 0승이면 nil. 화면 글씨는 클라이언트가
-- 이 숫자로 Loc.titleName (m5-26 — 서버는 칭호 문장을 보내지 않아요).
function ProfileSchema.titleWinsFor(wins: number): number?
	local found: number? = nil
	for _, entry in Config.Titles do
		if wins >= entry.wins then
			found = entry.wins
		end
	end
	return found
end

-- wins 이하인 칭호 중 가장 높은 것 (한국어 이름, 데이터 원문). Config.Titles는 wins 오름차순이에요.
function ProfileSchema.titleFor(wins: number): string?
	local title: string? = nil
	for _, entry in Config.Titles do
		if wins >= entry.wins then
			title = entry.name
		end
	end
	return title
end

ProfileSchema.MUTE_LEVELS = 3 -- 1 소리 켬, 2 음악 끔, 3 모두 끔

local function validMuteLevel(level: unknown): boolean
	return type(level) == "number"
		and level == level
		and level % 1 == 0
		and level >= 1
		and level <= ProfileSchema.MUTE_LEVELS
end

-- 클라이언트가 보낸 SaveSettings 인자 검사 (m5-41부터 부분 저장). muteLevel·touchLayout 중 하나 이상,
-- 있는 칸은 각각 검증하고 하나라도 틀리면 nil(요청 전체 무시). 그 밖의 칸은 읽지 않고 버려요.
-- 통과한 배치 숫자는 소수 셋째 자리로 반올림돼요.
function ProfileSchema.sanitizeSettings(value: unknown): Types.SettingsPatch?
	if type(value) ~= "table" then
		return nil
	end
	local raw = value :: any
	local patch: Types.SettingsPatch = {}
	local any = false
	if raw.muteLevel ~= nil then
		if not validMuteLevel(raw.muteLevel) then
			return nil
		end
		patch.muteLevel = raw.muteLevel
		any = true
	end
	if raw.touchLayout ~= nil then
		local change = TouchLayoutLogic.sanitizeChange(raw.touchLayout)
		if change == nil then
			return nil
		end
		patch.touchLayout = change
		any = true
	end
	return if any then patch else nil
end

-- 요청 간격은 칸마다 (m5-41): 음소거를 누른 직후의 배치 저장이 버려지지 않게. 너무 빠른 칸은 빼고,
-- 받은 칸의 시각을 last에 적어요. 남는 칸이 없으면 nil
function ProfileSchema.acceptByInterval(
	patch: Types.SettingsPatch,
	last: { [string]: number },
	now: number,
	interval: number
): Types.SettingsPatch?
	local out: Types.SettingsPatch = {}
	local any = false
	local function allow(field: string): boolean
		local at = last[field]
		if at ~= nil and now - at < interval then
			return false
		end
		last[field] = now
		any = true
		return true
	end
	if patch.muteLevel ~= nil and allow("muteLevel") then
		out.muteLevel = patch.muteLevel
	end
	if patch.touchLayout ~= nil and allow("touchLayout") then
		out.touchLayout = patch.touchLayout
	end
	return if any then out else nil
end

-- 검증한 patch를 설정에 합쳐요 (DataService.update 안에서). 없는 칸은 그대로
function ProfileSchema.applySettings(settings: Types.Settings, patch: Types.SettingsPatch)
	if patch.muteLevel ~= nil then
		settings.muteLevel = patch.muteLevel
	end
	local change = patch.touchLayout
	if change ~= nil then
		local layouts: { [string]: Types.TouchLayout } = (settings.touchLayout or {}) :: any
		if change.reset == true then
			layouts[change.bucket] = nil
		else
			layouts[change.bucket] = change.layout
		end
		settings.touchLayout = if next(layouts) ~= nil then layouts :: any else nil
	end
end

-- 저장된 설정 (프로필 불러오기, ProfileLogic). muteLevel이 틀리면 nil(설정 전체 기본),
-- touchLayout만 틀리면 그 칸(묶음)만 버리고 두 번째 값 true (메모)
function ProfileSchema.sanitizeStoredSettings(value: unknown): (Types.Settings?, boolean)
	if type(value) ~= "table" then
		return nil, false
	end
	local raw = value :: any
	if not validMuteLevel(raw.muteLevel) then
		return nil, false
	end
	local layouts, dropped = TouchLayoutLogic.sanitizeStored(raw.touchLayout)
	return { muteLevel = raw.muteLevel, touchLayout = layouts }, dropped
end

local function copyTouchLayout(value: Types.TouchLayoutSettings?): Types.TouchLayoutSettings?
	if value == nil or next(value :: any) == nil then
		return nil
	end
	local out: { [string]: any } = {}
	for bucket, layout in value :: any do
		out[bucket] = {
			v = layout.v,
			preset = layout.preset,
			jump = table.clone(layout.jump),
			dive = table.clone(layout.dive),
			grab = table.clone(layout.grab),
		}
	end
	return out :: any
end

local function sortedKeys(map: { [string]: any }, keep: (value: any) -> boolean): { string }
	local list = {}
	for key, value in map do
		if keep(value) then
			table.insert(list, key)
		end
	end
	table.sort(list)
	return list
end

local function isTrue(value: any): boolean
	return value == true
end

local function always(_value: any): boolean
	return true
end

function ProfileSchema.toView(profile: Profile, persistent: boolean, extra: ViewExtra?): Types.ProfileView
	local owned = sortedKeys(profile.ownedSkins, isTrue)
	local tokens: { [string]: number } = table.clone(profile.eventTokens or {})
	local equippedFx: EquippedFx = profile.equippedFx or {} :: EquippedFx
	return {
		coins = profile.coins,
		wins = profile.wins,
		title = ProfileSchema.titleFor(profile.wins),
		equippedSkin = profile.equippedSkin,
		ownedSkins = owned,
		settings = {
			muteLevel = profile.settings.muteLevel,
			touchLayout = copyTouchLayout(profile.settings.touchLayout),
		},
		persistent = persistent,
		eventTokens = tokens,
		ownedFx = sortedKeys(profile.ownedFx or {}, isTrue),
		equippedFx = { Elimination = equippedFx.Elimination, Victory = equippedFx.Victory },
		boughtOffers = sortedKeys(profile.boughtOffers or {}, always),
		vip = extra ~= nil and extra.vip == true,
		drawTickets = profile.drawTickets or 0,
		studioUnlockAll = extra ~= nil and extra.unlockAll == true,
	}
end

return ProfileSchema
